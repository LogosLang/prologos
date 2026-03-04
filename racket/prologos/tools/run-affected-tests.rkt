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
;;
;; Automatically records per-file timing data to data/benchmarks/timings.jsonl.
;; Use benchmark-tests.rkt for reporting (--report, --trend, --compare, --slowest).

(require racket/cmdline
         racket/list
         racket/path
         racket/port
         racket/set
         racket/string
         racket/system
         racket/async-channel
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
       ;; These are tested via the test-lang-*.rkt files (they load through the driver)
       [(and (string-prefix? rel "lib/examples/")
             (string-suffix? rel ".prologos"))
        (changed-test (string->symbol "test-lang-01-sexp.rkt"))]
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
(define num-jobs (make-parameter 10))
(define no-skip? (make-parameter #f))
(define skip-only? (make-parameter #f))
(define extra-skips (make-parameter '()))
(define record-timings? (make-parameter #t))
(define timeout-secs (make-parameter 600))
(define do-precompile? (make-parameter #t))

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
   ["--jobs" n "Number of parallel jobs (default: 10)"
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

  (define tests-dir
    (build-path project-root "tests"))

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

  ;; Pre-compile modules to bytecode (reduces per-subprocess overhead)
  (when (do-precompile?)
    (printf "Pre-compiling modules...\n")
    (define precomp-t0 (current-inexact-monotonic-milliseconds))
    (precompile-modules! project-root)
    (define precomp-ms (- (current-inexact-monotonic-milliseconds) precomp-t0))
    (printf "Pre-compiled in ~as\n"
            (real->decimal-string (/ precomp-ms 1000.0) 1)))

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
  (let loop ([remaining file-count] [count 0])
    (when (> remaining 0)
      (define r (sync/timeout (* (timeout-secs) 1.0) result-ch))
      (cond
        [r
         (define ms (hash-ref r 'wall_ms))
         (printf "[~a/~a] ~a ~a (~as)\n"
                 (add1 count) file-count
                 (hash-ref r 'file)
                 (status-label (hash-ref r 'status))
                 (real->decimal-string (/ ms 1000.0) 1))
         (flush-output)
         (set! collected (cons r collected))
         (loop (sub1 remaining) (add1 count))]
        [else
         ;; Timeout — kill all workers, report remaining as timeout
         (eprintf "\nTIMEOUT: No result received for ~as. Killing ~a remaining.\n"
                  (timeout-secs) remaining)
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
  (printf "\n~a tests in ~as (~a files, ~a batch workers, ~a)\n"
          total-tests
          (real->decimal-string (/ total-wall-ms 1000.0) 1)
          file-count
          jobs
          (if all-pass? "all pass"
              (format "~a FAILURES" (length failed-files))))
  (unless all-pass?
    (printf "\nFailed files:\n")
    (for ([r (in-list failed-files)])
      (printf "  ~a" (hash-ref r 'file))
      (when (hash-has-key? r 'error_output)
        (define msg (hash-ref r 'error_output))
        ;; Show first line of error diagnostic (or first 80 chars of exception)
        (define first-line (car (string-split msg "\n")))
        (define short (if (> (string-length first-line) 80)
                         (string-append (substring first-line 0 80) "...")
                         first-line))
        (printf "\n    ~a" short))
      (newline))
    (printf "\nSee failure logs: data/benchmarks/failures/*.log\n"))

  ;; Record to JSONL (unless --no-record)
  (when (record-timings?)
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

  (unless all-pass? (exit 1)))

(main)
