#lang racket/base

;; run-affected-tests.rkt — CLI entry point for targeted test running
;;
;; Usage:
;;   racket tools/run-affected-tests.rkt              # diff against HEAD, run affected
;;   racket tools/run-affected-tests.rkt --dry-run    # just print affected list
;;   racket tools/run-affected-tests.rkt --against main  # diff against main branch
;;   racket tools/run-affected-tests.rkt --all        # run everything
;;   racket tools/run-affected-tests.rkt --jobs 4     # override parallelism (default 10)
;;   racket tools/run-affected-tests.rkt --no-skip   # ignore .skip-tests, run everything
;;   racket tools/run-affected-tests.rkt --skip-only # run ONLY the normally-skipped tests
;;   racket tools/run-affected-tests.rkt --no-record # skip JSONL timing recording
;;   racket tools/run-affected-tests.rkt --timeout 300  # per-test timeout (default: 600)
;;   racket tools/run-affected-tests.rkt --no-precompile  # skip bytecode pre-compilation
;;   racket tools/run-affected-tests.rkt --no-pnet-cache # disable .pnet module network cache
;;   racket tools/run-affected-tests.rkt --failures      # show failure logs from last run
;;
;; Automatically records per-file timing data to data/benchmarks/timings.jsonl.
;; Use benchmark-tests.rkt for reporting (--report, --trend, --compare, --slowest).

(require racket/cmdline
         racket/file
         racket/list
         racket/path
         racket/port
         racket/set
         racket/string
         racket/system
         racket/async-channel
         (only-in racket/future processor-count)
         json
         "dep-graph.rkt"
         "bench-lib.rkt")

;; ============================================================
;; Skip list support
;; ============================================================

;; Read skip list from tests/.skip-tests.
;; Returns list of (symbol . reason-or-#f) pairs.
;; Missing file → empty list (no error).
(define (read-skip-list tests-dir)
  (define skip-file (build-path tests-dir ".skip-tests"))
  (if (file-exists? skip-file)
      (let ([lines (call-with-input-file skip-file
                     (lambda (in)
                       (for/list ([line (in-lines in)]) line)))])
        (filter-map
         (lambda (line)
           (define trimmed (string-trim line))
           (cond
             [(string=? trimmed "") #f]
             [(string-prefix? trimmed "#") #f]
             [else
              (define parts (string-split trimmed "#" #:trim? #f))
              (define filename (string-trim (car parts)))
              (define reason (and (> (length parts) 1)
                                  (string-trim (string-join (cdr parts) "#"))))
              (cons (string->symbol filename) reason)]))
         lines))
      '()))

;; Apply skip filter to a test list.
;; Returns two values: (tests-to-run . tests-skipped)
(define (apply-skip-filter test-list tests-dir)
  (cond
    [(no-skip?) (values test-list '())]
    [else
     (define skip-entries (append (read-skip-list tests-dir)
                                  (map (λ (s) (cons s #f)) (extra-skips))))
     (define skip-names (map car skip-entries))
     (define filtered (filter (λ (t) (not (member t skip-names))) test-list))
     (define actually-skipped (filter (λ (t) (member t skip-names)) test-list))
     ;; Report skipped tests to stderr
     (unless (null? actually-skipped)
       (eprintf "Skipping ~a known pathological test(s):\n" (length actually-skipped))
       (for ([t (in-list actually-skipped)])
         (define entry (assq t skip-entries))
         (define reason (and entry (cdr entry)))
         (eprintf "  ~a~a\n" t (if reason (format "  (~a)" reason) "")))
       (eprintf "\n"))
     (if (skip-only?)
         (values actually-skipped filtered)  ; invert: run skipped, skip non-skipped
         (values filtered actually-skipped))]))

;; ============================================================
;; Path classification
;; ============================================================

;; The project root is racket/prologos/ — git paths are relative to repo root
(define prologos-prefix "racket/prologos/")

;; Classify a git-relative path into a changed-* struct, or #f if irrelevant
(define (classify-path path)
  (cond
    ;; Must be under racket/prologos/
    [(not (string-prefix? path prologos-prefix)) #f]
    [else
     (define rel (substring path (string-length prologos-prefix)))
     (cond
       ;; tools/ — meta-tooling, ignore
       [(string-prefix? rel "tools/") #f]
       ;; tests/examples/*.rkt — example files
       [(string-prefix? rel "tests/examples/")
        (define fname (last (string-split rel "/")))
        (changed-example (string->symbol fname))]
       ;; tests/*.rkt — test files
       [(string-prefix? rel "tests/")
        (define fname (last (string-split rel "/")))
        (changed-test (string->symbol fname))]
       ;; lib/prologos/**/*.prologos — library modules
       [(and (string-prefix? rel "lib/prologos/")
             (string-suffix? rel ".prologos"))
        ;; Convert path to module name:
        ;; lib/prologos/data/nat.prologos → prologos::data::nat
        (define without-prefix (substring rel (string-length "lib/")))
        (define without-ext (substring without-prefix 0
                              (- (string-length without-prefix)
                                 (string-length ".prologos"))))
        (define mod-name (string-replace without-ext "/" "::"))
        (changed-prologos (string->symbol mod-name))]
       ;; lib/examples/**/*.prologos — example .prologos files
       ;; Track 10 Phase 5: #lang prologos tests removed. Example files are
       ;; validated via .prologos acceptance files, not #lang tests.
       [(and (string-prefix? rel "lib/examples/")
             (string-suffix? rel ".prologos"))
        'skip]  ;; no longer mapped to a specific test
       ;; info.rkt — package metadata, run all tests
       [(equal? rel "info.rkt") 'run-all]
       ;; *.rkt source files (not in tests/ or tools/)
       [(and (string-suffix? rel ".rkt")
             (not (string-contains? rel "/")))
        (changed-source (string->symbol rel))]
       ;; docs/ and other non-code — ignore
       [else #f])]))

;; ============================================================
;; Git diff integration
;; ============================================================

(define (run-git-command . args)
  (define cmd (string-join (cons "git" args) " "))
  (define output (with-output-to-string
                   (λ () (system cmd))))
  (if (string=? output "")
      '()
      (string-split (string-trim output) "\n")))

(define (get-changed-files against)
  (define diff-files
    (if against
        (run-git-command "diff" "--name-only" against)
        ;; Default: both staged and unstaged changes against HEAD
        (remove-duplicates
         (append (run-git-command "diff" "--name-only" "HEAD")
                 (run-git-command "diff" "--name-only" "--staged")))))
  (define untracked
    (run-git-command "ls-files" "--others" "--exclude-standard"))
  (remove-duplicates (append diff-files untracked)))

;; ============================================================
;; Main
;; ============================================================

(define dry-run? (make-parameter #f))
(define against-target (make-parameter #f))
(define run-all? (make-parameter #f))
;; Track 10B: default to machine's CPU count, not hardcoded 10.
(define num-jobs (make-parameter (processor-count)))
(define no-skip? (make-parameter #f))
(define skip-only? (make-parameter #f))
(define extra-skips (make-parameter '()))
(define record-timings? (make-parameter #t))
(define timeout-secs (make-parameter 600))
(define do-precompile? (make-parameter #t))
(define do-pnet-cache? (make-parameter #t))
(define show-failures? (make-parameter #f))
(define bail-timeout-threshold (make-parameter 3))

(define (main)
  (command-line
   #:program "run-affected-tests"
   #:once-each
   ["--dry-run" "Only print affected tests, don't run them"
    (dry-run? #t)]
   ["--against" target "Diff against this ref (default: HEAD)"
    (against-target target)]
   ["--all" "Run all tests regardless of changes"
    (run-all? #t)]
   ["--jobs" n "Number of parallel jobs (default: CPU count)"
    (num-jobs (string->number n))]
   ["--no-skip" "Ignore .skip-tests, run all affected tests"
    (no-skip? #t)]
   ["--skip-only" "Run ONLY the normally-skipped tests"
    (skip-only? #t)]
   ["--no-record" "Skip JSONL timing recording"
    (record-timings? #f)]
   ["--timeout" secs "Per-test timeout in seconds (default: 600)"
    (timeout-secs (string->number secs))]
   ["--no-precompile" "Skip bytecode pre-compilation step"
    (do-precompile? #f)]
   ["--no-pnet-cache" "Disable .pnet module network caching (default: enabled)"
    (do-pnet-cache? #f)]
   ["--failures" "Show failure logs from last run (no tests executed)"
    (show-failures? #t)]
   ["--bail-timeouts" n "Abort after N per-file timeouts (default: 3, 0=disable)"
    (bail-timeout-threshold (string->number n))]
   ["--no-bail" "Disable early-bail on timeouts"
    (bail-timeout-threshold 0)]
   #:multi
   ["--skip" file "Skip an additional test file (additive with .skip-tests)"
    (extra-skips (cons (string->symbol file) (extra-skips)))])

  ;; Anchor from script's own location: tools/ → prologos/
  (define tools-dir
    (let ([src (resolved-module-path-name
                (variable-reference->resolved-module-path
                 (#%variable-reference)))])
      (simplify-path (path-only src))))
  (define project-root
    (path->string (simplify-path (build-path tools-dir ".."))))

  ;; Track 10B: set CWD to project-root so subprocesses (batch workers,
  ;; raco make) inherit the correct working directory regardless of
  ;; where the runner was invoked from.
  (current-directory project-root)

  (define tests-dir
    (build-path project-root "tests"))

  ;; --failures: show failure logs from last run, then exit
  (when (show-failures?)
    (define fail-dir (build-path project-root "data" "benchmarks" "failures"))
    (cond
      [(not (directory-exists? fail-dir))
       (printf "No failure logs found (directory does not exist: ~a)\n" fail-dir)]
      [else
       (define logs (sort (map path->string (directory-list fail-dir #:build? #t))
                          string<?))
       (define log-files (filter (lambda (p) (string-suffix? p ".log")) logs))
       (cond
         [(null? log-files)
          (printf "No failure logs found — all tests passed last run.\n")]
         [else
          (printf "~a failure log(s) from last run:\n\n" (length log-files))
          (for ([log-path (in-list log-files)])
            (printf "~a\n" (make-string 60 #\─))
            (display (file->string log-path))
            (newline))])])
    (exit 0))

  (cond
    ;; --all: run everything (subject to skip filter)
    [(run-all?)
     ;; Merge dep-graph entries with any test files on disk not yet in dep-graph
     (define known-tests (all-test-files))
     (define disk-tests
       (if (directory-exists? tests-dir)
           (for/list ([p (in-list (directory-list tests-dir))]
                      #:when (let ([s (path->string p)])
                               (and (string-prefix? s "test-")
                                    (string-suffix? s ".rkt"))))
             (string->symbol (path->string p)))
           '()))
     (define all-tests (sort (remove-duplicates (append known-tests disk-tests)) symbol<?))
     (define-values (to-run skipped) (apply-skip-filter all-tests tests-dir))
     (cond
       [(null? to-run)
        (printf "No tests to run (all ~a tests are skipped).\n" (length all-tests))]
       [else
        (printf "Running ~a of ~a test files~a...\n"
                (length to-run) (length all-tests)
                (if (null? skipped) "" (format " (~a skipped)" (length skipped))))
        (when (dry-run?)
          (for ([t (in-list to-run)])
            (printf "  ~a\n" t)))
        (unless (dry-run?)
          (define test-paths
            (for/list ([t (in-list to-run)])
              (path->string (build-path tests-dir (symbol->string t)))))
          (run-tests test-paths project-root))])]

    ;; Normal mode: compute affected tests from git diff
    [else
     (define raw-paths (get-changed-files (against-target)))
     (when (null? raw-paths)
       (printf "No changed files detected. Nothing to test.\n")
       (exit 0))

     ;; Classify paths
     (define classified
       (filter-map classify-path raw-paths))

     ;; Check for run-all trigger (e.g., info.rkt changed)
     (define force-all?
       (member 'run-all classified))

     (cond
       [force-all?
        (printf "info.rkt changed — running ALL tests.\n")
        (define all-tests (all-test-files))
        (define-values (to-run skipped) (apply-skip-filter all-tests tests-dir))
        (printf "Running ~a of ~a test files~a...\n"
                (length to-run) (length all-tests)
                (if (null? skipped) "" (format " (~a skipped)" (length skipped))))
        (unless (dry-run?)
          (define test-paths
            (for/list ([t (in-list to-run)])
              (path->string (build-path tests-dir (symbol->string t)))))
          (run-tests test-paths project-root))]

       [else
        ;; Filter out 'run-all from classified list (shouldn't be there but safety)
        (define changes (filter (λ (x) (not (eq? x 'run-all))) classified))

        (when (null? changes)
          (printf "Changed files are outside the prologos source tree. Nothing to test.\n")
          (exit 0))

        ;; Print summary of detected changes
        (printf "Detected changes:\n")
        (for ([c (in-list changes)])
          (cond
            [(changed-source? c)
             (printf "  source: ~a\n" (changed-source-name c))]
            [(changed-test? c)
             (printf "  test:   ~a\n" (changed-test-name c))]
            [(changed-prologos? c)
             (printf "  lib:    ~a\n" (changed-prologos-name c))]
            [(changed-example? c)
             (printf "  example: ~a\n" (changed-example-name c))]))

        ;; Compute affected tests (pass project-root for auto-scan of new files)
        (define affected (compute-affected-tests changes #:project-root project-root))

        ;; Apply skip filter
        (define-values (to-run skipped) (apply-skip-filter affected tests-dir))

        (cond
          [(null? to-run)
           (if (null? affected)
               (printf "\nNo tests affected by these changes.\n")
               (printf "\nNo tests to run (~a affected, all skipped).\n"
                       (length affected)))]
          [else
           (printf "\nAffected tests (~a of ~a~a):\n"
                   (length to-run)
                   (length (all-test-files))
                   (if (null? skipped) ""
                       (format ", ~a skipped" (length skipped))))
           (for ([t (in-list to-run)])
             (printf "  ~a\n" t))
           (unless (dry-run?)
             (define test-paths
               (for/list ([t (in-list to-run)])
                 (path->string (build-path tests-dir (symbol->string t)))))
             (run-tests test-paths project-root))])])]))

;; ============================================================
;; Prelude drift check
;; ============================================================
;;
;; Runs `gen-prelude.rkt --validate` to ensure the PRELUDE manifest
;; matches namespace.rkt. Prints a warning if they're out of sync.

(define (check-prelude-drift! project-root)
  (define gen-prelude-path
    (path->string (build-path project-root "tools" "gen-prelude.rkt")))
  (define manifest-path
    (build-path project-root "lib" "prologos" "book" "PRELUDE"))
  ;; Only check if the PRELUDE manifest exists (graceful skip otherwise)
  (when (file-exists? manifest-path)
    (define-values (proc out in err)
      (subprocess #f #f #f racket-path gen-prelude-path "--validate"))
    (close-output-port in)
    (subprocess-wait proc)
    (define stdout-text (port->string out))
    (define stderr-text (port->string err))
    (close-input-port out)
    (close-input-port err)
    (cond
      [(zero? (subprocess-status proc))
       (void)]  ;; all good, silent
      [else
       (printf "\n⚠  PRELUDE DRIFT DETECTED\n")
       (printf "   PRELUDE manifest and namespace.rkt are out of sync.\n")
       (printf "   Run: racket tools/gen-prelude.rkt --write\n")
       (printf "   to regenerate namespace.rkt from the manifest.\n\n")])))

;; ============================================================
;; Batch test execution with shared prelude
;; ============================================================
;;
;; Instead of spawning one `raco test` subprocess per file (each loading
;; the prelude from scratch, ~11s), we group files into N batch workers.
;; Each worker loads the prelude ONCE, then runs ~N/jobs files in sequence
;; via dynamic-require. Results stream back as JSONL, one line per file.
;;
;; For 225 files with 10 jobs:
;;   Old: 225 × ~13s prelude loads = ~400-500s total
;;   New: 10 × ~11s prelude loads + 225 × ~2s per file = ~60-80s total

(define (run-tests test-paths project-root)
  (define file-count (length test-paths))

  ;; Step 0: Kill stale batch workers from previous runs.
  ;; A killed test run leaves batch-worker.rkt processes alive, consuming
  ;; resources and potentially holding file locks. Clean them up.
  (let ([kill-result (with-handlers ([exn? (lambda (e) "")])
                       (let-values ([(proc out in err)
                                     (subprocess #f #f #f "/usr/bin/pkill"
                                                 "-f" "batch-worker.rkt")])
                         (subprocess-wait proc)
                         (close-input-port out)
                         (close-input-port err)
                         "done"))])
    (void))

  ;; Pre-compile modules to bytecode (reduces per-subprocess overhead)
  (when (do-precompile?)
    (printf "Pre-compiling modules...\n")
    (define precomp-t0 (current-inexact-monotonic-milliseconds))
    (precompile-modules! project-root)
    (define precomp-ms (- (current-inexact-monotonic-milliseconds) precomp-t0))
    (printf "Pre-compiled in ~as\n"
            (real->decimal-string (/ precomp-ms 1000.0) 1)))

  ;; Track 10B: Stale .zo detection when --no-precompile is used.
  ;; Checks if driver.rkt's .zo is older than driver.rkt source.
  ;; If stale, warn (don't fail — the user explicitly said --no-precompile).
  (unless (do-precompile?)
    (let* ([driver-src (build-path project-root "driver.rkt")]
           [driver-zo  (build-path project-root "compiled" "driver_rkt.zo")])
      (when (and (file-exists? driver-src) (file-exists? driver-zo))
        (when (> (file-or-directory-modify-seconds driver-src)
                 (file-or-directory-modify-seconds driver-zo))
          (printf "⚠ WARNING: driver.rkt is newer than compiled/driver_rkt.zo\n")
          (printf "  Run `raco make driver.rkt` or remove --no-precompile\n")))))

  ;; .pnet cache: set env var for batch workers, check/generate cache
  (cond
    [(do-pnet-cache?)
     (putenv "PROLOGOS_PNET_CACHE" "1")
     ;; Check if .pnet files already exist (skip expensive generation)
     (let* ([pnet-dir (build-path project-root "data" "cache" "pnet")]
            [pnet-count
             (if (directory-exists? pnet-dir)
                 (length (filter (lambda (p) (regexp-match? #rx"\\.pnet$" (path->string p)))
                                 (directory-list pnet-dir)))
                 0)])
       (if (> pnet-count 0)
           (printf ".pnet cache: ~a files ready\n" pnet-count)
           (let ([pnet-t0 (current-inexact-monotonic-milliseconds)])
             (printf "Generating .pnet cache (first run) ...\n")
             (let ([dev-null-out (open-output-file "/dev/null" #:exists 'append)]
                   [dev-null-err (open-output-file "/dev/null" #:exists 'append)])
               (let-values ([(gen-proc _out _in _err)
                             (subprocess dev-null-out #f dev-null-err
                                         racket-path
                                         (path->string (build-path project-root "tools" "pnet-compile.rkt")))])
                 (subprocess-wait gen-proc)
                 (close-output-port dev-null-out)
                 (close-output-port dev-null-err)))
             (let ([pnet-ms (- (current-inexact-monotonic-milliseconds) pnet-t0)])
               (printf ".pnet cache generated in ~as\n"
                       (real->decimal-string (/ pnet-ms 1000.0) 1))))))]
    [else
     (putenv "PROLOGOS_PNET_CACHE" "0")])

  ;; Check PRELUDE manifest against namespace.rkt (catch drift early)
  (check-prelude-drift! project-root)

  ;; Distribute files across batches (round-robin for load balance)
  (define jobs (min (num-jobs) file-count))
  (define batches (make-vector jobs '()))
  (for ([path (in-list test-paths)]
        [i (in-naturals)])
    (define slot (modulo i jobs))
    (vector-set! batches slot (cons path (vector-ref batches slot))))
  ;; Reverse each batch to restore original order
  (for ([i (in-range jobs)])
    (vector-set! batches i (reverse (vector-ref batches i))))

  ;; Resolve batch worker path
  (define batch-worker-path
    (path->string (build-path project-root "tools" "batch-worker.rkt")))

  (printf "\n--- Running ~a files (~a batch workers, timeout: ~as) ---\n"
          file-count jobs (timeout-secs))

  ;; Spawn all batch workers and reader threads
  (define result-ch (make-async-channel))
  (define t0 (current-inexact-monotonic-milliseconds))
  (define all-procs '())

  (for ([i (in-range jobs)]
        #:when (pair? (vector-ref batches i)))
    (define batch (vector-ref batches i))
    (define-values (proc stdout stdin stderr)
      (apply subprocess #f #f #f racket-path batch-worker-path batch))
    (close-output-port stdin)
    (set! all-procs (cons proc all-procs))
    ;; Reader thread: parse JSONL from worker stdout → result channel
    (thread
     (λ ()
       (let loop ()
         (define line (read-line stdout 'any))
         (cond
           [(eof-object? line)
            (close-input-port stdout)
            (close-input-port stderr)]
           [else
            (define trimmed (string-trim line))
            (unless (string=? trimmed "")
              (with-handlers ([exn:fail? void])
                (define r (with-input-from-string trimmed read-json))
                (when (hash? r)
                  (async-channel-put result-ch r))))
            (loop)])))))

  ;; Collect results with progress output
  (define collected '())
  (define timeout-count 0)
  (define bailed? #f)
  (let loop ([remaining file-count] [count 0])
    (when (> remaining 0)
      ;; Track 10B: Use short timeout (30s) for the FIRST result.
      ;; If no result arrives in 30s, workers likely crashed silently.
      ;; Subsequent results use the normal per-file timeout.
      (define first-result-timeout 30)
      (define effective-timeout
        (if (= count 0) first-result-timeout (timeout-secs)))
      (define r (sync/timeout (* effective-timeout 1.0) result-ch))
      (cond
        [r
         (define ms (hash-ref r 'wall_ms))
         (define status (hash-ref r 'status))
         (printf "[~a/~a] ~a ~a (~as)\n"
                 (add1 count) file-count
                 (hash-ref r 'file)
                 (status-label status)
                 (real->decimal-string (/ ms 1000.0) 1))
         (flush-output)
         (set! collected (cons r collected))
         ;; Track 10B: Dead-worker detection.
         ;; If first batch completes with 0 total tests, workers crashed silently.
         ;; Common cause: stale .zo after struct field changes.
         (define running-test-total
           (apply + (map (λ (r) (hash-ref r 'tests 0)) collected)))
         (when (and (>= count jobs)    ;; first batch done
                    (<= count (+ jobs 2))  ;; check once
                    (= running-test-total 0))
           (set! bailed? #t)
           (printf "\n")
           (printf "╔══════════════════════════════════════════════════════════╗\n")
           (printf "║  ⛔ DEAD WORKERS — 0 tests after ~a files              ║\n" count)
           (printf "║                                                        ║\n")
           (printf "║  All batch workers crashed silently.                   ║\n")
           (printf "║  ACTION: Run `raco make driver.rkt` to recompile.     ║\n")
           (printf "║  Common cause: stale .zo after struct field changes.   ║\n")
           (printf "╚══════════════════════════════════════════════════════════╝\n"))

         ;; Early-bail: abort if too many per-file timeouts
         (when (string=? status "timeout")
           (set! timeout-count (add1 timeout-count)))
         (define bail-threshold (bail-timeout-threshold))
         (cond
           [(and (> bail-threshold 0)
                 (>= timeout-count bail-threshold))
            (set! bailed? #t)
            (printf "\n")
            (printf "╔══════════════════════════════════════════════════════════╗\n")
            (printf "║  ⛔ SYSTEMIC REGRESSION DETECTED                       ║\n")
            (printf "║  ~a file(s) timed out in the first ~a files.~a║\n"
                    timeout-count (+ count 1)
                    (make-string (max 0 (- 26 (string-length (format "~a" timeout-count))
                                            (string-length (format "~a" (+ count 1))))) #\space))
            (printf "║                                                        ║\n")
            (printf "║  ACTION: REVERT your last change and investigate.      ║\n")
            (printf "║  This is NOT flaky tests — it's a code regression.     ║\n")
            (printf "║  Common causes: infinite loop, missing guard, stale .zo ║\n")
            (printf "╚══════════════════════════════════════════════════════════╝\n")
            (printf "\n   Killing ~a remaining files.\n\n" (sub1 remaining))
            (flush-output)
            (for ([p (in-list all-procs)])
              (with-handlers ([exn:fail? void])
                (subprocess-kill p #t)))]
           [else
            (loop (sub1 remaining) (add1 count))])]
        [else
         ;; Timeout — check if this is dead-worker (first result never arrived)
         ;; vs per-file timeout (individual test took too long)
         (cond
           [(= count 0)
            ;; No results AT ALL — workers crashed silently.
            (printf "\n")
            (printf "╔══════════════════════════════════════════════════════════╗\n")
            (printf "║  ⛔ DEAD WORKERS — no results after ~as               ║\n" first-result-timeout)
            (printf "║                                                        ║\n")
            (printf "║  All batch workers crashed before producing output.    ║\n")
            (printf "║  ACTION: Run `raco make driver.rkt` to recompile.     ║\n")
            (printf "║  Common cause: stale .zo after struct field changes.   ║\n")
            (printf "╚══════════════════════════════════════════════════════════╝\n")
            (set! bailed? #t)]
           [else
            ;; Normal per-file timeout
            (eprintf "\nTIMEOUT: No result received for ~as. Killing ~a remaining.\n"
                     (timeout-secs) remaining)])
         (for ([p (in-list all-procs)])
           (with-handlers ([exn:fail? void])
             (subprocess-kill p #t)))])))

  (define file-results (reverse collected))

  ;; Wait for all worker processes to finish
  (for ([p (in-list all-procs)])
    (with-handlers ([exn:fail? void])
      (subprocess-wait p)))

  (define t1 (current-inexact-monotonic-milliseconds))
  (define total-wall-ms (inexact->exact (round (- t1 t0))))
  (define total-tests (apply + (map (λ (r) (hash-ref r 'tests)) file-results)))
  (define all-pass? (andmap (λ (r) (string=? (hash-ref r 'status) "pass")) file-results))

  ;; Print summary
  (define failed-files
    (filter (λ (r) (not (string=? (hash-ref r 'status) "pass"))) file-results))
  (define completed-count (length file-results))
  (printf "\n~a tests in ~as (~a~a files, ~a batch workers, ~a)\n"
          total-tests
          (real->decimal-string (/ total-wall-ms 1000.0) 1)
          (if bailed? (format "~a of " completed-count) "")
          file-count
          jobs
          (cond [bailed? (format "ABORTED — ~a timeouts" timeout-count)]
                [all-pass? "all pass"]
                [else (format "~a FAILURES" (length failed-files))]))
  (unless all-pass?
    (for ([r (in-list failed-files)])
      (printf "\n~a\n" (make-string 60 #\─))
      (printf "FAILED: ~a\n" (hash-ref r 'file))
      (when (hash-has-key? r 'error_output)
        (define msg (hash-ref r 'error_output))
        ;; Print full diagnostic content inline — no need to open log files
        (for ([line (in-list (string-split msg "\n"))])
          (printf "    ~a\n" line)))
      (newline))
    (printf "~a\n" (make-string 60 #\─))
    (printf "Failure logs: data/benchmarks/failures/*.log\n"))

  ;; Track 10B: Write summary file for easy inspection without re-running.
  ;; Read with: cat data/benchmarks/last-run-summary.txt
  (let ([summary-path (build-path project-root "data" "benchmarks" "last-run-summary.txt")])
    (with-output-to-file summary-path #:exists 'replace
      (lambda ()
        (printf "~a tests in ~as (~a files, ~a workers~a)\n"
                total-tests
                (real->decimal-string (/ total-wall-ms 1000.0) 1)
                file-count jobs
                (cond [bailed? (format ", ABORTED — ~a timeouts" timeout-count)]
                      [all-pass? ", all pass"]
                      [else (format ", ~a FAILURES" (length failed-files))]))
        (unless all-pass?
          (printf "\nFailed files:\n")
          (for ([r (in-list failed-files)])
            (printf "  ~a\n" (hash-ref r 'file))
            (when (hash-has-key? r 'error_output)
              (define lines (string-split (hash-ref r 'error_output) "\n"))
              (for ([line (in-list (take lines (min 5 (length lines))))])
                (printf "    ~a\n" line))))))))

  ;; Record to JSONL (unless --no-record or early bail)
  (when (and (record-timings?) (not bailed?))
    (define timings-file (make-timings-path project-root))
    (define record
      (hasheq 'schema_version 3
              'timestamp (current-iso-timestamp)
              'commit (current-commit)
              'branch (current-branch)
              'machine (string-append (symbol->string (system-type 'os))
                                      "-"
                                      (symbol->string (system-type 'arch)))
              'jobs jobs
              'total_wall_ms total-wall-ms
              'total_tests total-tests
              'file_count file-count
              'all_pass all-pass?
              'source "affected"
              'results file-results))
    (append-run-record timings-file record)
    (printf "Timings recorded to ~a\n" (path->string timings-file)))

  (when bailed? (exit 2))
  (unless all-pass? (exit 1)))

(main)
