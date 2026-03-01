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
         "../metavar-store.rkt")

;; Load prelude via test-support.rkt (warms Racket module cache).
;; Must use dynamic-require (not require) to control execution order.
(define test-support-path
  (simplify-path (build-path (path-only (syntax-source #'here))
                             ".." "tests" "test-support.rkt")))
(dynamic-require test-support-path #f)

;; Save ALL Prologos parameters (post-prelude = ready state).
;; Individual defines because parameterize is a macro — can't use apply.
;; macros.rkt parameters
(define ready-preparse-registry       (current-preparse-registry))
(define ready-spec-store              (current-spec-store))
(define ready-propagated-specs        (current-propagated-specs))
(define ready-ctor-registry           (current-ctor-registry))
(define ready-type-meta               (current-type-meta))
(define ready-subtype-registry        (current-subtype-registry))
(define ready-coercion-registry       (current-coercion-registry))
(define ready-trait-registry          (current-trait-registry))
(define ready-trait-laws              (current-trait-laws))
(define ready-impl-registry           (current-impl-registry))
(define ready-param-impl-registry     (current-param-impl-registry))
(define ready-bundle-registry         (current-bundle-registry))
(define ready-specialization-registry (current-specialization-registry))
(define ready-property-store          (current-property-store))
(define ready-functor-store           (current-functor-store))
(define ready-user-precedence-groups  (current-user-precedence-groups))
(define ready-user-operators          (current-user-operators))
(define ready-macro-registry          (current-macro-registry))
;; namespace.rkt parameters
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

(define files
  (command-line
   #:program "batch-worker"
   #:args files
   files))

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
    ;; Fresh meta-store per file (mutable, can't share).
    (parameterize
        (;; macros.rkt
         [current-preparse-registry       ready-preparse-registry]
         [current-spec-store              ready-spec-store]
         [current-propagated-specs        ready-propagated-specs]
         [current-ctor-registry           ready-ctor-registry]
         [current-type-meta               ready-type-meta]
         [current-subtype-registry        ready-subtype-registry]
         [current-coercion-registry       ready-coercion-registry]
         [current-trait-registry          ready-trait-registry]
         [current-trait-laws              ready-trait-laws]
         [current-impl-registry           ready-impl-registry]
         [current-param-impl-registry     ready-param-impl-registry]
         [current-bundle-registry         ready-bundle-registry]
         [current-specialization-registry ready-specialization-registry]
         [current-property-store          ready-property-store]
         [current-functor-store           ready-functor-store]
         [current-user-precedence-groups  ready-user-precedence-groups]
         [current-user-operators          ready-user-operators]
         [current-macro-registry          ready-macro-registry]
         ;; namespace.rkt
         [current-module-registry         ready-module-registry]
         [current-ns-context              ready-ns-context]
         [current-lib-paths               ready-lib-paths]
         [current-loading-set             ready-loading-set]
         [current-module-loader           ready-module-loader]
         [current-spec-propagation-handler ready-spec-propagation-handler]
         [current-foreign-handler         ready-foreign-handler]
         ;; global-env.rkt
         [current-global-env              ready-global-env]
         ;; metavar-store.rkt — fresh mutable hash per file
         [current-mult-meta-store         (make-hasheq)]
         ;; Set load-relative-directory so dynamic-require with relative
         ;; paths inside test files resolves correctly (e.g., test-quote.rkt's
         ;; (dynamic-require "../sexp-readtable.rkt" ...) needs to resolve
         ;; relative to tests/, not to prologos/).
         [current-load-relative-directory file-dir]
         ;; Capture I/O (don't let test output pollute JSON stream)
         [current-output-port             (open-output-string)]
         [current-error-port              stderr-capture])
      (dynamic-require abs-file #f)))

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

  ;; Attach error output on failure
  (define result-final
    (if (and (not ok?) (not (string=? error-msg "")))
        (hash-set result+mem 'error_output error-msg)
        result+mem))

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
         (when (not (string=? error-msg ""))
           (fprintf out "--- Exception ---\n~a\n\n" error-msg))
         (when (not (string=? captured-err ""))
           ;; Filter out PERF-COUNTERS/PHASE-TIMINGS/MEMORY-STATS noise
           (fprintf out "--- Captured stderr ---\n")
           (for ([line (in-list (string-split captured-err "\n"))]
                 #:when (not (string-prefix? line "PERF-COUNTERS"))
                 #:when (not (string-prefix? line "PHASE-TIMINGS"))
                 #:when (not (string-prefix? line "MEMORY-STATS")))
             (fprintf out "~a\n" line)))))]
    ;; Clean up old failure log on pass (from previous failing run)
    [(file-exists? log-path)
     (delete-file log-path)])

  ;; Write JSON line to real stdout
  (write-json result-final real-stdout)
  (newline real-stdout)
  (flush-output real-stdout))
