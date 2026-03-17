#lang racket/base

;; batch-worker.rkt — Run multiple test files in a single process.
;;
;; Loads the prelude ONCE at startup (~11s) via test-support.rkt,
;; then dynamic-requires each test file in sequence. All test files
;; share the cached Racket module instances (macros.rkt, driver.rkt, etc.)
;; while getting clean Prologos state (registries, env, etc.) per file.
;;
;; Outputs one JSON line per file to stdout:
;;   {"file":"test-foo.rkt","wall_ms":1234,"status":"pass","tests":15}
;;
;; Usage: racket tools/batch-worker.rkt <file1> <file2> ...

(require racket/port
         racket/string
         racket/path
         racket/list
         racket/set
         racket/file
         racket/cmdline
         json
         rackunit/log)

;; Enable test logging for counting tests and detecting failures
(test-log-enabled? #t)

;; ============================================================
;; Phase 1: Load infrastructure + prelude, save post-prelude state
;; ============================================================
;; We save parameter state AFTER the prelude loads. Rationale:
;;
;; Racket caches module instances — once a module is loaded via
;; `dynamic-require`, subsequent requires return the cached instance
;; WITHOUT re-executing its body. The prelude registers constructors,
;; specs, impls, etc. as side effects during module body execution.
;; If we reset to pre-prelude state, these side effects don't re-fire
;; when test files re-require prelude modules (they're cached), so
;; tests see empty registries and things like `reduce` don't evaluate.
;;
;; By saving post-prelude state, each test starts with all prelude
;; registrations already in place — matching what `raco test` does
;; (where each process loads the prelude fresh).
;;
;; Tests that don't use the prelude (e.g., test-spec.rkt) have their
;; own `parameterize` in their helpers that resets what they need.
;;
;; IMPORTANT: We use `require` for infrastructure and `dynamic-require`
;; for test-support.rkt because Racket hoists all `require` forms —
;; they all instantiate before any `define` in the module body runs.
;; Using `dynamic-require` ensures test-support.rkt loads at runtime,
;; BEFORE the state-saving defines below.

(require "../macros.rkt"
         "../namespace.rkt"
         "../global-env.rkt"
         "../metavar-store.rkt"
         "../errors.rkt")

;; Load prelude via test-support.rkt (warms Racket module cache).
;; Must use dynamic-require (not require) to control execution order.
(define test-support-path
  (simplify-path (build-path (path-only (syntax-source #'here))
                             ".." "tests" "test-support.rkt")))
(dynamic-require test-support-path #f)

;; Save post-prelude state. Two categories:
;;
;; (1) Cell-based registries (19 macros params): saved as a single vector via
;;     save-macros-registry-snapshot. These are the registry contents that
;;     register-macros-cells! uses to initialize cells each command.
;;
;; (2) Runtime config (7 namespace params + 1 global-env): saved individually
;;     because these are configuration, not reactive elaboration state.
;;
;; Track 6 Phase 6: Consolidated 19 individual macros param saves → 1 vector.
(define ready-macros-snapshot         (save-macros-registry-snapshot))
;; namespace.rkt parameters (runtime config — NOT cell-based)
(define ready-module-registry         (current-module-registry))
(define ready-ns-context              (current-ns-context))
(define ready-lib-paths               (current-lib-paths))
(define ready-loading-set             (current-loading-set))
(define ready-module-loader           (current-module-loader))
(define ready-spec-propagation-handler (current-spec-propagation-handler))
(define ready-foreign-handler         (current-foreign-handler))
;; global-env.rkt
(define ready-global-env              (current-global-env))

;; ============================================================
;; Phase 2: Run test files with ready state per file
;; ============================================================

;; ============================================================
;; Failure log directory
;; ============================================================
;; Write per-file failure logs to data/benchmarks/failures/
;; for easy post-mortem inspection of batch test failures.
(define failure-log-dir
  (simplify-path (build-path (path-only (syntax-source #'here))
                             ".." "data" "benchmarks" "failures")))

;; Per-file timeout (seconds). Kills a test file that exceeds this limit.
;; Default 120s is generous (slowest normal tests ~17s; pathological ~50s).
;; Set to 0 to disable.
(define per-file-timeout-secs (make-parameter 120))

(define files
  (command-line
   #:program "batch-worker"
   #:once-each
   ["--file-timeout" secs "Per-file timeout in seconds (default: 120, 0=disable)"
    (per-file-timeout-secs (string->number secs))]
   #:args files
   files))

;; Extract ERROR-DIAGNOSTIC:BEGIN...END blocks from captured stderr.
;; Returns (values diagnostics remaining-lines)
;;   diagnostics: list of strings (content between BEGIN and END markers)
;;   remaining-lines: list of strings (all other non-metric lines)
(define (extract-error-diagnostics stderr-str)
  (define lines (string-split stderr-str "\n"))
  (define diagnostics '())
  (define remaining '())
  (define in-diag? #f)
  (define current-diag '())
  (for ([line (in-list lines)])
    (cond
      [(string=? line "ERROR-DIAGNOSTIC:BEGIN")
       (set! in-diag? #t)
       (set! current-diag '())]
      [(string=? line "ERROR-DIAGNOSTIC:END")
       (set! in-diag? #f)
       (set! diagnostics (cons (string-join (reverse current-diag) "\n") diagnostics))]
      [in-diag?
       (set! current-diag (cons line current-diag))]
      [else
       (set! remaining (cons line remaining))]))
  (values (reverse diagnostics) (reverse remaining)))

;; Save the real stdout for JSON output
(define real-stdout (current-output-port))

(for ([file (in-list files)])
  ;; Snapshot test-log counters: (failures . total)
  (define pre-log (test-log))
  (define pre-fail (car pre-log))
  (define pre-total (cdr pre-log))

  (define t0 (current-inexact-monotonic-milliseconds))
  (define ok? #t)
  (define error-msg "")

  ;; Capture stderr from the test file
  (define stderr-capture (open-output-string))

  ;; Resolve file path to absolute BEFORE parameterize
  ;; (so current-load-relative-directory doesn't interfere)
  (define abs-file (path->complete-path (simplify-path (string->path file))))
  (define file-dir (path-only abs-file))

  (with-handlers ([exn:fail?
                   (λ (e)
                     (set! ok? #f)
                     (set! error-msg (exn-message e)))])
    ;; Restore ALL parameters to post-prelude ready state.
    ;; This gives each test file a state with all prelude registrations
    ;; present — constructors, specs, impls, etc. — matching what each
    ;; file would see if run in its own process via `raco test`.
    ;; Track 6 Phase 6: macros params restored from snapshot vector.
    ;; Fresh meta-store per file (mutable, can't share).
    (restore-macros-registry-snapshot! ready-macros-snapshot)
    (parameterize
        (;; namespace.rkt
         [current-module-registry         ready-module-registry]
         [current-ns-context              ready-ns-context]
         [current-lib-paths               ready-lib-paths]
         [current-loading-set             ready-loading-set]
         [current-module-loader           ready-module-loader]
         [current-spec-propagation-handler ready-spec-propagation-handler]
         [current-foreign-handler         ready-foreign-handler]
         ;; global-env.rkt
         [current-global-env              ready-global-env]
         [current-definition-cells-content (hasheq)]   ;; Phase 3a: fresh per-file
         [current-definition-cell-ids      (hasheq)]   ;; Phase 3a: fresh per-file
         [current-definition-dependencies  (hasheq)]   ;; Phase 3b: fresh per-file
         [current-cross-module-deps        '()]         ;; Track 5 Phase 4: fresh per-file
         [current-global-env-prop-net-box  #f]          ;; Phase 3a: no stale cell writes
         [current-ns-prop-net-box          #f]          ;; Phase 3c: no stale ns cell writes
         [current-module-registry-cell-id  #f]          ;; Phase 3c: fresh per-file
         [current-ns-context-cell-id       #f]          ;; Phase 3c: fresh per-file
         [current-defn-param-names-cell-id #f]          ;; Phase 3c: fresh per-file
         ;; metavar-store.rkt — fresh mutable hash per file
         [current-mult-meta-store         (make-hasheq)]
         ;; errors.rkt — emit formatted errors to stderr for failure logs
         [current-emit-error-diagnostics  #t]
         ;; Set load-relative-directory so dynamic-require with relative
         ;; paths inside test files resolves correctly (e.g., test-quote.rkt's
         ;; (dynamic-require "../sexp-readtable.rkt" ...) needs to resolve
         ;; relative to tests/, not to prologos/).
         [current-load-relative-directory file-dir]
         ;; Capture I/O (don't let test output pollute JSON stream)
         [current-output-port             (open-output-string)]
         [current-error-port              stderr-capture])
      ;; Per-file timeout: run dynamic-require in a thread, kill on timeout.
      ;; Thread inherits parameterization, so all param bindings are active.
      (define timeout (per-file-timeout-secs))
      (if (and timeout (> timeout 0))
          (let ()
            (define done-ch (make-channel))
            (define worker
              (thread (λ ()
                (with-handlers ([exn:fail? (λ (e) (channel-put done-ch (cons 'error e)))])
                  (dynamic-require abs-file #f)
                  (channel-put done-ch 'ok)))))
            (define result (sync/timeout timeout done-ch))
            (cond
              [(not result)
               ;; Timeout — kill the thread and report
               (kill-thread worker)
               (set! ok? #f)
               (set! error-msg
                     (format "TIMEOUT: file exceeded ~as per-file limit" timeout))]
              [(and (pair? result) (eq? (car result) 'error))
               ;; Exception from within the thread
               (set! ok? #f)
               (set! error-msg (exn-message (cdr result)))]))
          ;; No timeout — run directly
          (dynamic-require abs-file #f))))

  (define t1 (current-inexact-monotonic-milliseconds))
  (define wall-ms (inexact->exact (round (- t1 t0))))

  ;; Compute per-file test count and failure count from test-log diff
  (define post-log (test-log))
  (define post-fail (car post-log))
  (define post-total (cdr post-log))
  (define file-tests (- post-total pre-total))
  (define file-failures (- post-fail pre-fail))

  ;; Mark as fail if rackunit logged any failures
  (when (and ok? (> file-failures 0))
    (set! ok? #f))

  ;; Extract PERF-COUNTERS, PHASE-TIMINGS, MEMORY-STATS from captured stderr
  (define captured-err (get-output-string stderr-capture))
  (define (extract-json-lines prefix str)
    (define prefix-len (string-length prefix))
    (define results
      (for/list ([line (in-list (string-split str "\n"))]
                 #:when (and (>= (string-length line) prefix-len)
                             (string=? (substring line 0 prefix-len) prefix)))
        (with-handlers ([exn:fail? (λ (_) #f)])
          (with-input-from-string (substring line prefix-len) read-json))))
    (filter hash? results))

  (define heartbeat-entries (extract-json-lines "PERF-COUNTERS:" captured-err))
  (define phase-entries (extract-json-lines "PHASE-TIMINGS:" captured-err))
  (define memory-entries (extract-json-lines "MEMORY-STATS:" captured-err))
  (define cell-metrics-entries (extract-json-lines "CELL-METRICS:" captured-err))

  ;; Merge multiple PERF-COUNTERS / PHASE-TIMINGS by summing
  (define (merge-sum entries)
    (cond
      [(null? entries) #f]
      [(= (length entries) 1) (car entries)]
      [else
       (for/fold ([acc (car entries)]) ([h (in-list (cdr entries))])
         (for/fold ([a acc]) ([(k v) (in-hash h)])
           (hash-set a k (+ (hash-ref a k 0) v))))]))

  (define heartbeats (merge-sum heartbeat-entries))
  (define phases (merge-sum phase-entries))
  (define memory (and (not (null? memory-entries)) (last memory-entries)))
  ;; Cell metrics: take last entry (final network state after all commands)
  (define cell-metrics (and (not (null? cell-metrics-entries)) (last cell-metrics-entries)))

  ;; Build result hash
  (define result
    (hasheq 'file (path->string (file-name-from-path (string->path file)))
            'wall_ms wall-ms
            'status (if ok? "pass" "fail")
            'tests file-tests))

  ;; Attach optional fields
  (define result+hb  (if heartbeats (hash-set result 'heartbeats heartbeats) result))
  (define result+ph  (if phases (hash-set result+hb 'phases phases) result+hb))
  (define result+mem (if memory (hash-set result+ph 'memory memory) result+ph))
  (define result+cm  (if cell-metrics (hash-set result+mem 'cell_metrics cell-metrics) result+mem))

  ;; Extract error diagnostics from captured stderr
  (define-values (error-diagnostics remaining-stderr-lines)
    (extract-error-diagnostics captured-err))

  ;; Extract PROVENANCE-STATS lines for dedicated section
  (define provenance-stats-lines
    (filter (lambda (l) (string-prefix? l "PROVENANCE-STATS:")) remaining-stderr-lines))
  ;; Remaining stderr without metrics or diagnostics
  (define clean-stderr-lines
    (filter (lambda (l)
              (and (not (string-prefix? l "PERF-COUNTERS"))
                   (not (string-prefix? l "PHASE-TIMINGS"))
                   (not (string-prefix? l "MEMORY-STATS"))
                   (not (string-prefix? l "PROVENANCE-STATS"))
                   (not (string-prefix? l "CELL-METRICS"))))
            remaining-stderr-lines))

  ;; Attach error output on failure — ALL diagnostics, not just the first
  (define error-output
    (cond
      [(pair? error-diagnostics)
       (string-join error-diagnostics "\n\n")]
      [(not (string=? error-msg "")) error-msg]
      [else #f]))
  (define result-final
    (if (and (not ok?) error-output)
        (hash-set result+cm 'error_output error-output)
        result+cm))

  ;; Write failure log if test failed
  (define file-name (path->string (file-name-from-path (string->path file))))
  (define log-path (build-path failure-log-dir (string-append file-name ".log")))
  (cond
    [(not ok?)
     ;; Ensure directory exists
     (make-directory* failure-log-dir)
     (call-with-output-file log-path #:exists 'replace
       (λ (out)
         (fprintf out "=== ~a FAILED ===\n" file-name)
         (fprintf out "wall_ms: ~a\n" wall-ms)
         (fprintf out "tests: ~a (~a failures)\n\n" file-tests file-failures)
         ;; Error Diagnostics — formatted prologos errors with provenance chains
         (when (pair? error-diagnostics)
           (fprintf out "--- Error Diagnostics ---\n")
           (for ([diag (in-list error-diagnostics)])
             (fprintf out "~a\n\n" diag)))
         ;; Exception — rackunit or Racket-level exception
         (when (not (string=? error-msg ""))
           (fprintf out "--- Exception ---\n~a\n\n" error-msg))
         ;; RackUnit stderr — test failure details (minus metrics/diagnostics)
         (define non-empty-stderr
           (filter (lambda (l) (not (string=? l ""))) clean-stderr-lines))
         (when (pair? non-empty-stderr)
           (fprintf out "--- RackUnit stderr ---\n")
           (for ([line (in-list non-empty-stderr)])
             (fprintf out "~a\n" line))
           (fprintf out "\n"))
         ;; Provenance Stats — ATMS and speculation counters
         (when (pair? provenance-stats-lines)
           (fprintf out "--- Provenance Stats ---\n")
           (for ([line (in-list provenance-stats-lines)])
             (fprintf out "~a\n" line))
           (fprintf out "\n"))))]
    ;; Clean up old failure log on pass (from previous failing run)
    [(file-exists? log-path)
     (delete-file log-path)])

  ;; Write JSON line to real stdout
  (write-json result-final real-stdout)
  (newline real-stdout)
  (flush-output real-stdout))
