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
;;   racket tools/run-affected-tests.rkt --no-wait       # exit 75 if the suite lock is busy
;;
;; Runs QUEUE machine-wide (suite-lock.rkt): a full suite takes the suite lock
;; exclusively, a targeted run shares it; a later run waits for an earlier one.
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
         "bench-lib.rkt"
         "suite-plan.rkt"
         "suite-lock.rkt"
         (only-in racket/os getpid))

;; ============================================================
;; Compile-limit adoption (Rel T1 SUB.2, owner-blessed 2026-07-24)
;; ============================================================
;; Raise the Racket CS machine-code compile limit for every build this runner
;; triggers. The compiler's giant match functions (shift/subst ~340 arms each,
;; whnf/nf ~990) exceed the default limit (10000) and fall back to the CS
;; INTERPRETER. Measured in-tree: shift 1.27 s → 1.52 ms per 11k-node walk
;; (~830×); full suite 211 → 173 s (−18%, all pass); compile cost +17% on the
;; hot core. Subprocesses (raco make precompile, batch workers) inherit the
;; env, so setting it here covers the whole pipeline. An explicit user
;; override is respected. Manual `raco make` outside the runners needs the
;; var in the shell (see CLAUDE.local.md + .claude/rules/testing.md).
;; Evidence: docs/tracking/2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md §4.2.
(void (unless (getenv "PLT_CS_COMPILE_LIMIT")
        (putenv "PLT_CS_COMPILE_LIMIT" "1000000")))  ; `void`: a module-level #t prints

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
;; Per-file timeout, now genuinely threaded to batch-worker.rkt (see the spawn
;; site). 300 rather than the old nominal 600: the value is REAL now, so it is
;; also how long a hung file blocks the suite. 300 is 2.5x the largest honest
;; file (test-path-selection.rkt at 112-117s) and still 2x faster than 600 at
;; catching a hang. ⚠ It is strictly MORE headroom than shipped before in BOTH
;; modes — the effective limit was the worker's hardcoded 120s, not this number.
(define timeout-secs (make-parameter 300))
;; Whale sharding (suite-plan.rkt § WHALE SHARDING): a file whose historical
;; median exceeds this many seconds runs as ⌈median/target⌉ shards (capped at
;; --jobs) on distinct workers. 30 s: the suite's work/worker bound is ~49 s at
;; 18 workers, so no single unit should approach it. 0 disables.
(define shard-target-secs (make-parameter 30))
(define do-precompile? (make-parameter #t))
(define do-pnet-cache? (make-parameter #t))
(define show-failures? (make-parameter #f))
(define failures-run (make-parameter #f))
(define bail-timeout-threshold (make-parameter 3))
(define force-rerun? (make-parameter #f))
(define force-stale-zo? (make-parameter #f))
;; --no-wait: when the machine-wide suite lock (suite-lock.rkt) is busy, exit
;; SUITE-LOCK-BUSY-EXIT (75) at once instead of queueing behind the holder.
(define no-wait? (make-parameter #f))
;; PPN 4C Phase 3c process improvement (2026-04-20): --tests FILE...
;; Targeted test mode. Takes explicit file paths, skips dep-graph inference,
;; runs precompile-modules! (so test .zo linklets are fresh w.r.t. any
;; export changes in production), then runs just the listed files. Use this
;; after ANY production edit — `raco test FILE` directly uses cached .zo and
;; will hit linklet-mismatch ("reference to a variable that is not exported")
;; when imported-module exports change.
(define targeted-tests (make-parameter '()))

;; Internal: suppress the global stale-.zo scan when targeted mode has done
;; its own scoped precompile. Distinct from --force-stale-zo?, which is a
;; user-facing "accept stale files" override that emits a warning.
(define suppress-stale-scan? (make-parameter #f))

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
   ["--shard-target" secs "Shard files whose median exceeds SECS into ceil(median/SECS) units on distinct workers (default: 30, 0=off)"
    (shard-target-secs (string->number secs))]
   ["--no-precompile" "Skip bytecode pre-compilation step"
    (do-precompile? #f)]
   ["--no-pnet-cache" "Disable .pnet module network caching (default: enabled)"
    (do-pnet-cache? #f)]
   ["--failures" "Show failure logs from last run (no tests executed)"
    (show-failures? #t)]
   ["--failures-run" id "Show the archived failure logs of run ID (or 'latest'), from data/benchmarks/failures/runs/"
    (show-failures? #t) (failures-run id)]
   ["--bail-timeouts" n "Abort after N per-file timeouts (default: 3, 0=disable)"
    (bail-timeout-threshold (string->number n))]
   ["--no-bail" "Disable early-bail on timeouts"
    (bail-timeout-threshold 0)]
   ["--force-rerun" "Override rerun guard (force full suite even if no changes)"
    (force-rerun? #t)]
   ["--force-stale-zo" "Run despite stale .zo files (reproduce old behavior intentionally)"
    (force-stale-zo? #t)]
   ["--no-wait" "If another run holds the machine-wide suite lock, exit 75 instead of waiting"
    (no-wait? #t)]
   #:multi
   ["--skip" file "Skip an additional test file (additive with .skip-tests)"
    (extra-skips (cons (string->symbol file) (extra-skips)))]
   ["--tests" file "Run specific test file(s); precompile ensures linklet freshness. Additive — can appear multiple times."
    (targeted-tests (cons file (targeted-tests)))])

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

  ;; --failures: show failure logs from last run, then exit.
  ;; --failures-run ID: the archived logs of one run (DEFERRED 160 support).
  (when (show-failures?)
    (define fail-root (build-path project-root "data" "benchmarks" "failures"))
    (define runs-root (build-path fail-root "runs"))
    (define fail-dir
      (cond [(failures-run) (build-path (if (equal? (failures-run) "latest") fail-root runs-root)
                                        (failures-run))]
            [else fail-root]))
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
          (printf "~a failure log(s) ~a:\n\n" (length log-files)
                  (if (failures-run)
                      (format "from run ~a" (failures-run))
                      "— the latest per file"))
          (for ([log-path (in-list log-files)])
            (printf "~a\n" (make-string 60 #\─))
            (display (file->string log-path))
            (newline))])])
    (define archived
      (if (directory-exists? runs-root)
          (sort (for/list ([p (in-list (directory-list runs-root))]) (path->string p)) string>?)
          '()))
    (unless (null? archived)
      (printf "Archive (data/benchmarks/failures/runs/, newest ~a kept): ~a run(s); newest ~a. Show one: --failures-run ID|latest\n"
              FAILURE-RUNS-KEPT (length archived) (car archived)))
    (exit 0))

  ;; Guard: block redundant full-suite re-runs (correct-by-construction, not discipline).
  ;; If --all and timings.jsonl was written <5min ago and no .rkt files changed since,
  ;; print a warning and exit. Use --force-rerun to override.
  ;; Checked before queueing for the suite lock AND again after a wait: a run
  ;; that queued behind another full suite of this checkout may find, once it
  ;; holds the lock, that the run it waited for has just made it redundant.
  (define (rerun-guard!)
    (when (and (run-all?) (not (force-rerun?)))
      (define timings-path (build-path project-root "data" "benchmarks" "timings.jsonl"))
      (when (file-exists? timings-path)
        (define last-mod (file-or-directory-modify-seconds timings-path))
        (define now (current-seconds))
        (define elapsed (- now last-mod))
        (when (< elapsed 300)  ;; less than 5 minutes
          (define src-dir (build-path project-root))
          (define any-changed?
            (for/or ([f (in-directory src-dir)]
                     #:when (regexp-match? #rx"\\.rkt$" (path->string f)))
              (> (file-or-directory-modify-seconds f) last-mod)))
          (unless any-changed?
            (printf "\n~a\n" (make-string 60 #\═))
            (printf "GUARD: No .rkt files changed since last suite run (~as ago).\n" elapsed)
            (printf "Read failure logs:  racket tools/run-affected-tests.rkt --failures\n")
            (printf "Run one test:       raco test tests/test-NAME.rkt\n")
            (printf "Force full re-run:  add --force-rerun flag\n")
            (printf "Exit status ~a: NOTHING WAS RUN (not a pass).\n" EXIT-GUARD-REFUSED)
            (printf "~a\n\n" (make-string 60 #\═))
            ;; DEFERRED 164 open(2): was (exit 0), which read as green.
            (exit EXIT-GUARD-REFUSED))))))
  (rerun-guard!)

  ;; Machine-wide suite QUEUE (suite-lock.rkt). A run takes the lock before it
  ;; compiles or starts a worker and holds it to the end: 'exclusive for a
  ;; full or suite-sized run (one worker per core), 'shared for a targeted
  ;; run. A second run WAITS, printing who holds the lock, instead of
  ;; contending for the cores; `--no-wait` exits 75 instead. The OS releases
  ;; the lock if this process dies, and every `(exit n)` below releases it first.
  (define (with-suite-lock mode thunk)
    (define lock-path (suite-lock-path))
    (define report (make-wait-reporter mode lock-path))
    (define waited? #f)
    (define t-wait (current-inexact-milliseconds))
    (call-with-suite-lock
     mode
     (lambda ()
       (when waited?
         (printf "Suite lock acquired (~a) after waiting ~as.\n" mode
                 (real->decimal-string (/ (- (current-inexact-milliseconds) t-wait) 1000.0) 1))
         (rerun-guard!))
       (thunk))
     #:path lock-path
     #:wait? (not (no-wait?))
     #:checkout project-root
     #:command (string-join (cons "run-affected-tests"
                                  (vector->list (current-command-line-arguments)))
                            " ")
     #:on-wait (lambda (holders secs) (set! waited? #t) (report holders secs))
     #:on-busy (lambda (holders)
                 (printf "\n~a\n" (make-string 60 #\═))
                 (printf "SUITE LOCK BUSY (--no-wait): exit ~a, nothing was run.\n"
                         SUITE-LOCK-BUSY-EXIT)
                 (printf "  wanted: ~a access to ~a\n" mode (path->string lock-path))
                 (if (null? holders)
                     (printf "  holder: unknown (no info file: it predates suite-lock.rkt, or is starting)\n")
                     (for ([h (in-list holders)])
                       (printf "  ~a\n" (format-holder h))))
                 (printf "Drop --no-wait to queue behind it.\n")
                 (printf "~a\n\n" (make-string 60 #\═))
                 (exit SUITE-LOCK-BUSY-EXIT))))

  (cond
    ;; --tests FILE...: run specific files with precompile discipline.
    ;; Use after ANY production edit (especially export changes) to avoid
    ;; stale-.zo linklet-mismatch errors from bare `raco test`. Precompile
    ;; is SCOPED to driver.rkt + the listed test files (not the full test
    ;; directory) to keep targeted iteration fast.
    [(pair? (targeted-tests))
     (define files (reverse (targeted-tests)))
     ;; Normalize each file path against the project root (tolerate relative
     ;; input like "tests/test-X.rkt" or absolute paths equally).
     (define normalized-files
       (for/list ([f (in-list files)])
         (cond
           [(absolute-path? f) f]
           [else (path->string (simplify-path (build-path project-root f)))])))
     ;; Validate existence — fail fast rather than submit a nonexistent path
     ;; to the batch worker, which would produce confusing errors.
     (define missing
       (filter (lambda (p) (not (file-exists? p))) normalized-files))
     (cond
       [(pair? missing)
        (for ([p (in-list missing)])
          (eprintf "Error: test file not found: ~a\n" p))
        (exit 1)]
       [else
        (printf "Running ~a targeted test file(s) with scoped precompile...\n"
                (length normalized-files))
        (when (dry-run?)
          (for ([p (in-list normalized-files)])
            (printf "  ~a\n" p)))
        (unless (dry-run?)
         (with-suite-lock
          (suite-lock-mode #:all? #f #:file-count (length normalized-files))
          (lambda ()
          ;; Scoped precompile: driver.rkt + just the targeted tests. This is
          ;; the linklet-safety guarantee for targeted runs. Fast path ~3-5s
          ;; typical (vs ~30s full-directory precompile). Skip run-tests's
          ;; global precompile since we've done the scoped one here.
          (define driver-path
            (path->string (simplify-path (build-path project-root "driver.rkt"))))
          (define compile-paths (cons driver-path normalized-files))
          (cond
            [(do-precompile?)
             (printf "Pre-compiling driver + ~a test file(s)...\n"
                     (length normalized-files))
             (define t0 (current-inexact-monotonic-milliseconds))
             ;; STAGED + parallel via bench-lib's `raco-make-staged!`: production
             ;; paths to completion FIRST, then the test paths. The split is what
             ;; keeps the stale-.zo heuristic below honest under -j (a test that
             ;; does not require driver.rkt can otherwise finish before
             ;; driver_rkt.zo and look stale forever after). It also drains
             ;; raco's pipes, which the previous code did not — see raco-make!.
             (define-values (prod-paths tst-paths)
               (partition (lambda (p) (not (regexp-match? #rx"/tests/" p))) compile-paths))
             (define-values (ok output) (raco-make-staged! prod-paths tst-paths))
             (define ms (- (current-inexact-monotonic-milliseconds) t0))
             (printf "Pre-compiled in ~as\n"
                     (real->decimal-string (/ ms 1000.0) 1))
             (unless ok
               (eprintf "Error: raco make failed for targeted precompile.\n")
               ;; the old code discarded this, so a failure named no module
               (eprintf "~a" output)
               (exit 1))
             ;; run-tests still invokes precompile-modules! via its own
             ;; do-precompile? path — temporarily disable to avoid re-running
             ;; the full-directory precompile we just replaced. Also suppress
             ;; the stale-.zo scan over the full tests/ directory since we
             ;; only care about linklet-safety for the targeted files (already
             ;; fresh post scoped precompile). Global stale detection would
             ;; recompile ~120 files we won't run.
             (parameterize ([do-precompile? #f]
                            [suppress-stale-scan? #t])
               (run-tests normalized-files project-root))]
            [else
             (run-tests normalized-files project-root)]))))])]

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
     ;; PM Track 10C: filter to files that actually exist (dep-graph may have stale entries)
     ;; DEFERRED 161: test-support.rkt & co. are not test units (suite-plan.rkt
     ;; NON-TEST-MODULES) — dispatching the worker's own fixture ran 0 tests.
     (define all-tests
       (sort (drop-non-test-modules
              (filter (lambda (sym)
                        (file-exists? (build-path tests-dir (symbol->string sym))))
                      (remove-duplicates (append known-tests disk-tests))))
             symbol<?))
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
          (with-suite-lock 'exclusive (lambda () (run-tests test-paths project-root))))])]

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
        (define all-tests (drop-non-test-modules (all-test-files)))
        (define-values (to-run skipped) (apply-skip-filter all-tests tests-dir))
        (printf "Running ~a of ~a test files~a...\n"
                (length to-run) (length all-tests)
                (if (null? skipped) "" (format " (~a skipped)" (length skipped))))
        (unless (dry-run?)
          (define test-paths
            (for/list ([t (in-list to-run)])
              (path->string (build-path tests-dir (symbol->string t)))))
          (with-suite-lock 'exclusive (lambda () (run-tests test-paths project-root))))]

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
        (define affected
          (drop-non-test-modules (compute-affected-tests changes #:project-root project-root)))

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
             (with-suite-lock (suite-lock-mode #:all? #f #:file-count (length test-paths))
                              (lambda () (run-tests test-paths project-root))))])])]))

;; ============================================================
;; Per-worker bookkeeping
;; ============================================================
;; One per batch worker: what it was sent, in order, and everything it wrote
;; to its REAL stderr (DEFERRED 164 open 4 — outside batch-worker.rkt's
;; per-file capture). Lists are newest-first while the run is live.
(struct worker-state (index proc [dispatched #:mutable] [stderr #:mutable]
                            [stderr-dropped #:mutable] [drain #:mutable]))
(define WORKER-STDERR-MAX-LINES 20000)  ; per worker; the rest is counted, not kept

(define (worker-stderr-lines w) (map cdr (reverse (worker-state-stderr w))))
;; The same, minus the prelude's metric lines (suite-plan.rkt metric-line?).
(define (worker-evidence-lines w) (filter (lambda (l) (not (metric-line? l))) (worker-stderr-lines w)))

;; Print a digest of the workers' stderr and, when it shows a linklet
;; mismatch, the stale module and the rebuild that fixes it — the dead-worker
;; banner used to advise `raco make driver.rkt`, which cannot fix a stale
;; module that driver.rkt does not depend on (item (h): tests/test-support.rkt).
(define (print-worker-stderr-digest workers #:lines [n 12])
  (for ([w (in-list workers)]) (sync/timeout 2 (worker-state-drain w)))
  (define any? #f)
  (for ([w (in-list workers)])
    (define ls (worker-evidence-lines w))
    (unless (null? ls)
      (unless any? (printf "\nWorker stderr (first ~a lines each; full text in this run's worker-N.stderr.log):\n" n))
      (set! any? #t)
      (printf "  worker ~a (pid ~a):\n" (worker-state-index w) (subprocess-pid (worker-state-proc w)))
      (for ([l (in-list (take ls (min n (length ls))))]) (printf "    ~a\n" l))))
  (unless any? (printf "\nThe workers wrote nothing to stderr (beyond the prelude's metric lines).\n"))
  (define diag (for/or ([w (in-list workers)]) (diagnose-worker-stderr (worker-stderr-lines w))))
  (when diag
    (printf "\n⚠ STALE COMPILED MODULE: ~a\n" (cadr diag))
    (printf "  (the importing side of a linklet mismatch: its .zo predates a dependency's rebuild)\n")
    (printf "  Rebuild it: PLT_CS_COMPILE_LIMIT=1000000 raco make -j 4 ~a\n" (cadr diag)))
  (flush-output))

;; ============================================================
;; Failure-log views (DEFERRED 160 support)
;; ============================================================
;; refresh-failure-views! : fail-root run-dir file-results -> kept?
;; (1) the per-file LATEST view at fail-root/<file>.log: for each file this run
;;     reported, replace its logs there with this run's; (2) the archive: keep
;;     run-dir when the run left evidence (#:keep-run?), else remove it; prune
;;     to the newest FAILURE-RUNS-KEPT; point fail-root/latest at the newest.
(define (refresh-failure-views! fail-root run-dir file-results #:keep-run? keep-run?
                                #:also-files [also-files '()])
  (define (names dir)
    (if (directory-exists? dir)
        (for/list ([p (in-list (directory-list dir))]
                   #:when (file-exists? (build-path dir p)))
          (path->string p))
        '()))
  (define run-logs (names run-dir))
  (define top-logs (names fail-root))
  (for ([f (in-list (remove-duplicates
                     (append (map (lambda (r) (hash-ref r 'file)) file-results) also-files)))])
    (for ([n (in-list (file-log-names f top-logs))])
      (with-handlers ([exn:fail? void]) (delete-file (build-path fail-root n))))
    (for ([n (in-list (file-log-names f run-logs))])
      (with-handlers ([exn:fail? void])
        (copy-file (build-path run-dir n) (build-path fail-root n) #t))))
  (define runs-root (build-path fail-root "runs"))
  (define kept? (and keep-run? (pair? run-logs)))
  (unless kept?
    (with-handlers ([exn:fail? void]) (delete-directory/files run-dir)))
  (define run-names
    (if (directory-exists? runs-root)
        (for/list ([p (in-list (directory-list runs-root))]
                   #:when (directory-exists? (build-path runs-root p)))
          (path->string p))
        '()))
  (for ([n (in-list (runs-to-prune run-names))])
    (with-handlers ([exn:fail? void]) (delete-directory/files (build-path runs-root n))))
  (define newest (let ([left (sort (remove* (runs-to-prune run-names) run-names) string>?)])
                   (and (pair? left) (car left))))
  (when newest
    (define link (build-path fail-root "latest"))
    (define tmp (build-path fail-root (format ".latest-~a" (getpid))))
    (with-handlers ([exn:fail? void])
      (when (link-exists? tmp) (delete-file tmp))
      (make-file-or-directory-link (build-path "runs" newest) tmp)
      (rename-file-or-directory tmp link #t)))
  kept?)

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

  ;; Step 0: Kill ORPHANED batch workers left by a previous, killed run of THIS
  ;; checkout's runner.
  ;;
  ;; ⚠⚠ THIS WAS `pkill -f batch-worker.rkt` — MACHINE-WIDE — AND IT KILLED LIVE
  ;; RUNS. Every runner start terminated every batch worker on the machine,
  ;; including the workers of a suite running concurrently in another session or
  ;; worktree. Observed twice on 2026-10-13: a full suite lost all 18 workers
  ;; mid-run (63 and 22 of 493 units reported) within seconds of a targeted run
  ;; starting in .claude/worktrees/deferred-sweep-146-149; the live check found
  ;; ZERO workers alive while the runner waited out its timeout — and before
  ;; the INCOMPLETE fix below, the victim then printed "all pass".
  ;;
  ;; An orphan is precisely a worker whose runner died: it is reparented to
  ;; launchd/init (PPID 1). A live run's workers are children of a live runner.
  ;; So: PPID 1 AND this checkout's absolute batch-worker path — never another
  ;; run's workers, never another worktree's.
  (let ([kill-result (with-handlers ([exn? (lambda (e) "")])
                       (let-values ([(proc out in err)
                                     (subprocess #f #f #f "/usr/bin/pkill"
                                                 "-P" "1"
                                                 "-f" (path->string
                                                       (build-path project-root "tools"
                                                                   "batch-worker.rkt")))])
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

  ;; Track 10B + Phase T: Stale .zo detection + auto-repair when --no-precompile is used.
  ;; Phase T lesson (BSP-LE Track 2B PIR §11.5): `raco make driver.rkt`
  ;; recompiles production code but NOT test files (they're not in driver.rkt's
  ;; dependency graph). The batch worker uses dynamic-require which trusts
  ;; cached .zo — stale test .zo produces wrong results SILENTLY (not linklet
  ;; errors, just old behavior). Multiple cycles of "passes individually, fails
  ;; in batch" during Track 2B Phase T-a tracked to this exact gap.
  ;;
  ;; I1 (Track 2B process, revised): AUTO-RECOMPILE stale files rather than
  ;; block. The existing `precompile-modules!` compiles driver + all test
  ;; files in a single `raco make` call. When staleness is detected under
  ;; --no-precompile, invoke it on the stale subset. Fast (already-fresh
  ;; files are no-ops). Preserves --no-precompile's purpose (skip full
  ;; recompile) while auto-fixing the silent-corruption trap.
  ;;
  ;; PPN 4C Phase 3c-close: --tests mode suppresses this via
  ;; suppress-stale-scan? — scoped precompile already handled the targeted
  ;; files; scanning other stale .zo wastes time on tests we won't run.
  ;; Override via --force-stale-zo for intentional reproduction of old behavior.
  (unless (or (do-precompile?) (suppress-stale-scan?))
    (define stale-files '())
    (let* ([driver-src (build-path project-root "driver.rkt")]
           [driver-zo  (build-path project-root "compiled" "driver_rkt.zo")])
      (when (and (file-exists? driver-src) (file-exists? driver-zo))
        (when (> (file-or-directory-modify-seconds driver-src)
                 (file-or-directory-modify-seconds driver-zo))
          (set! stale-files (cons (path->string driver-src) stale-files)))))
    ;; Test files against production .zo.
    (let* ([driver-zo (build-path project-root "compiled" "driver_rkt.zo")]
           [driver-ts (and (file-exists? driver-zo)
                           (file-or-directory-modify-seconds driver-zo))]
           [tests-dir (build-path project-root "tests")])
      (when (and driver-ts (directory-exists? tests-dir))
        (for ([f (in-directory tests-dir)]
              #:when (regexp-match? #rx"\\.rkt$" (path->string f)))
          (define test-zo
            (let* ([fname (file-name-from-path f)]
                   [zo-name (string-append (regexp-replace #rx"\\.rkt$" (path->string fname) "_rkt") ".zo")])
              (build-path (path-only f) "compiled" zo-name)))
          (when (and (file-exists? test-zo)
                     (< (file-or-directory-modify-seconds test-zo) driver-ts))
            (set! stale-files (cons (path->string f) stale-files))))))
    (when (pair? stale-files)
      (cond
        [(force-stale-zo?)
         (eprintf "⚠ --force-stale-zo: proceeding with ~a stale .zo file(s) (results may reflect OLD code)\n"
                  (length stale-files))]
        [else
         (printf "Detected ~a stale .zo file(s); auto-recompiling...\n" (length stale-files))
         (define repair-t0 (current-inexact-monotonic-milliseconds))
         ;; Staged for the same reason as the precompile above: if driver.rkt is
         ;; among the stale set it must finish before any test .zo is written,
         ;; or the next run's scan re-flags the tests we just repaired.
         (define-values (stale-prod stale-tests)
           (partition (lambda (p) (not (regexp-match? #rx"/tests/" p)))
                      (reverse stale-files)))
         (define-values (ok output) (raco-make-staged! stale-prod stale-tests))
         (unless ok
           (eprintf "✗ Auto-recompile failed. Run `raco make` manually.\n")
           (eprintf "~a" output)
           (exit 2))
         (define repair-ms (- (current-inexact-monotonic-milliseconds) repair-t0))
         (printf "Repaired in ~as\n" (real->decimal-string (/ repair-ms 1000.0) 1))])))

  ;; .pnet cache: set env var for batch workers, check/generate cache
  ;;
  ;; Readiness heuristic (hardened 2026-07-14; incident in commit c6c3ef3a
  ;; "Test infra fix"): the old check counted TOP-LEVEL *.pnet files, but the
  ;; real prelude caches live under the prologos/ SUBDIRECTORY — one stray
  ;; top-level .pnet (a test artifact) made the runner skip regeneration
  ;; forever while the caches drifted from the compiler, until the read-only
  ;; batch workers each re-elaborated the full prelude and starved at the
  ;; 30s startup watchdog. "Ready" now means ALL of:
  ;;   (a) prelude module caches exist: data/cache/pnet/prologos/**/*.pnet
  ;;       (recursive — strays elsewhere neither satisfy nor poison this)
  ;;   (b) the generation stamp (.pnet-stamp) exists — pnet-compile.rkt
  ;;       writes it only AFTER a complete generation, so an interrupted
  ;;       generation cannot present as ready
  ;;   (c) the stamp is not older than driver_rkt.zo — mirrors
  ;;       pnet-serialize.rkt's infrastructure-stale?, so the runner skips
  ;;       exactly when workers will actually load from cache
  (cond
    [(do-pnet-cache?)
     (putenv "PROLOGOS_PNET_CACHE" "1")
     (let* ([pnet-dir (build-path project-root "data" "cache" "pnet")]
            [prelude-cache-dir (build-path pnet-dir "prologos")]
            [stamp-path (build-path pnet-dir ".pnet-stamp")]
            [driver-zo (build-path project-root "compiled" "driver_rkt.zo")]
            [count-prelude-pnets
             (lambda ()
               (if (directory-exists? prelude-cache-dir)
                   (for/sum ([f (in-directory prelude-cache-dir)]
                             #:when (regexp-match? #rx"\\.pnet$" (path->string f)))
                     1)
                   0))]
            [prelude-pnet-count (count-prelude-pnets)]
            [cache-ready?
             (and (> prelude-pnet-count 0)
                  (file-exists? stamp-path)
                  (or (not (file-exists? driver-zo))
                      (>= (file-or-directory-modify-seconds stamp-path)
                          (file-or-directory-modify-seconds driver-zo))))])
       (if cache-ready?
           (printf ".pnet cache: ~a prelude module caches ready\n" prelude-pnet-count)
           (let ([pnet-t0 (current-inexact-monotonic-milliseconds)])
             (printf "Generating .pnet cache~a ...\n"
                     (cond
                       [(zero? prelude-pnet-count) " (no prelude caches)"]
                       [(not (file-exists? stamp-path)) " (no generation stamp)"]
                       [else " (stale vs driver_rkt.zo)"]))
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
               (printf ".pnet cache: ~a prelude module caches generated in ~as\n"
                       (count-prelude-pnets)
                       (real->decimal-string (/ pnet-ms 1000.0) 1)))
             (unless (file-exists? stamp-path)
               (eprintf "⚠ .pnet generation left no stamp (generation may have failed); workers will re-elaborate the prelude from source\n")))))]
    [else
     (putenv "PROLOGOS_PNET_CACHE" "0")])

  ;; PM Track 10C: Work-stealing dispatch with LPT scheduling.
  ;; Sort files by historical wall time (heaviest first) for optimal
  ;; load balance. Workers pull files from a shared queue via stdin.
  ;; (`jobs` is now derived from the planned UNITS below — a sharded whale run
  ;; alone, `--tests test-path-selection.rkt`, needs one worker per shard.)

  ;; Read historical timings for LPT sort.
  ;;
  ;; ⚠ This used to read ONLY THE LAST LINE of timings.jsonl, which is a trap: every
  ;; TARGETED run (`--tests foo.rkt`) also appends a record, and 77% of all records are
  ;; targeted (1162/1503 as of 2026-07-27). Our own workflow prescribes targeted runs
  ;; during development and the full suite as the final gate — precisely the sequence
  ;; that leaves a 1-6 file record last. Every other file then fell to the +inf.0
  ;; default, all keys compared equal, and the "LPT" sort silently degenerated to
  ;; stable (alphabetical) order.
  ;;
  ;; ⚠ A "measured impact NIL" claim stood here (median effective parallelism 8.97
  ;; "poisoned" vs 8.96 "clean" over 282 runs). It is REFUTED — DEFERRED 162: both
  ;; legs ran the INERT sort (the hasheq lookup below never hit), so it compared
  ;; alphabetical order with alphabetical order and says nothing about LPT. With
  ;; the sort working (389b3413) the suite went 127.6 -> 110.5 s (one run each, on
  ;; 159's interpreted build: the ratio holds, the absolute seconds do not).
  ;;
  ;; Now: take the per-file MEDIAN over the most recent full-suite runs. Median rather
  ;; than latest because per-file wall varies 5-10% run to run; full-suite runs only
  ;; because a file timed alone is not under 10-way contention and reads systematically
  ;; low, which would distort the ordering it is meant to inform.
  (define timings-path (build-path project-root "data" "benchmarks" "timings.jsonl"))
  (define LPT-HISTORY-RUNS 5)      ;; how many recent full runs to draw on
  (define LPT-MIN-FILE-COUNT 100)  ;; below this a record is a targeted run, not a suite
  ;; ⚠ equal?-keyed (suite-plan.rkt). This was a `for/hasheq` over file-name
  ;; STRINGS, looked up below with a freshly built string: `eq?` never matched
  ;; (0 of 489 hits, measured 2026-10-13), so every key was +inf.0 and dispatch
  ;; was ALPHABETICAL — including on both legs of the refuted measurement above.
  (define historical-times
    (if (file-exists? timings-path)
        (with-handlers ([exn? (lambda (e) (hash))])
          (historical-medians (file->lines timings-path)
                              #:runs LPT-HISTORY-RUNS
                              #:min-file-count LPT-MIN-FILE-COUNT))
        (hash)))

  ;; Plan work units: heaviest first (LPT); a whale becomes K shards
  ;; (suite-plan.rkt plan-units). Unknown files get +inf.0 (conservative: first).
  (define units
    (plan-units test-paths
                (lambda (p)
                  (hash-ref historical-times
                            (path->string (file-name-from-path (string->path p)))
                            #f))
                #:target-ms (* 1000 (shard-target-secs))
                #:max-k (num-jobs)))
  (define unit-count (length units))
  (define sharded-files
    (remove-duplicates (for/list ([u (in-list units)] #:when (work-unit-shard u))
                         (work-unit-path u))))
  (define jobs (min (num-jobs) unit-count))

  ;; Resolve batch worker path
  (define batch-worker-path
    (path->string (build-path project-root "tools" "batch-worker.rkt")))

  (printf "\n--- Running ~a files~a (~a batch workers, work-stealing, timeout: ~as) ---\n"
          file-count
          (if (null? sharded-files)
              ""
              (format " as ~a units — ~a sharded: ~a" unit-count (length sharded-files)
                      (string-join
                       (for/list ([f (in-list sharded-files)])
                         (format "~a×~a" (path->string (file-name-from-path (string->path f)))
                                 (for/sum ([u (in-list units)]) (if (equal? (work-unit-path u) f) 1 0))))
                       ", ")))
          jobs (timeout-secs))

  ;; Pending units + what each worker has already run. Dispatch gives a worker
  ;; the first pending unit for a file it has NOT run (pick-eligible): two shards
  ;; of one module in one worker would make the second a cached no-op. A worker
  ;; with nothing eligible is retired (stdin closed). Liveness argument and its
  ;; simulation: suite-plan.rkt pick-eligible / tests/test-suite-plan.rkt.
  (define pending units)
  (define worker-ran (make-hasheq))          ;; worker stdin port -> (hash path #t)
  (define worker-of (make-hasheq))           ;; worker stdin port -> worker-state
  (define t-dispatch0 (current-inexact-monotonic-milliseconds))
  (define (now-ms) (- (current-inexact-monotonic-milliseconds) t-dispatch0))
  (define (dispatch-next! stdin)
    (define ran (hash-ref! worker-ran stdin make-hash))
    (define-values (u rest) (pick-eligible pending (lambda (p) (hash-ref ran p #f))))
    (cond
      [u (set! pending rest)
         (hash-set! ran (work-unit-path u) #t)
         (let ([w (hash-ref worker-of stdin #f)])
           (when w
             (set-worker-state-dispatched! w (cons (cons (now-ms) u) (worker-state-dispatched w)))))
         (displayln (work-unit->line u) stdin)
         (flush-output stdin)]
      [else
       (with-handlers ([exn? void])
         (close-output-port stdin))]))

  ;; Spawn all batch workers in --stdin mode
  (define result-ch (make-async-channel))
  (define t0 (current-inexact-monotonic-milliseconds))
  (define all-procs '())
  (define all-stdins '())
  (define all-workers '())                   ;; worker-state, by index

  ;; ⚠⚠ THE `--timeout` FLAG DID NOT REACH THE WORKER, AND THE RUNNER PRINTED IT
  ;; ANYWAY. This spawned `batch-worker.rkt --stdin` with no `--file-timeout`, so
  ;; the per-file kill was ALWAYS the worker's own default (120s) no matter what
  ;; `--timeout` said — while the banner three lines below announced "timeout:
  ;; 600s". A file at 117s was therefore 97% of a budget nobody could see and the
  ;; documented knob could not raise. Passing it makes the printed number true and
  ;; gives ONE place to set the limit.
  (define file-timeout-arg (number->string (timeout-secs)))
  ;; DEFERRED 160 support: this run's failure logs go to their OWN directory,
  ;; which nothing edits afterwards (suite-plan.rkt § FAILURE-LOG ARCHIVE).
  (define fail-root (build-path project-root "data" "benchmarks" "failures"))
  (define run-id (make-run-id (current-seconds) (getpid)))
  (define run-dir (build-path fail-root "runs" run-id))
  (make-directory* run-dir)
  (for ([i (in-range jobs)])
    (define-values (proc stdout stdin stderr)
      (subprocess #f #f #f racket-path batch-worker-path "--stdin"
                  "--file-timeout" file-timeout-arg
                  "--failure-dir" (path->string run-dir)))
    (set! all-procs (cons proc all-procs))
    (set! all-stdins (cons stdin all-stdins))
    (define w (worker-state i proc '() '() 0 #f))
    (hash-set! worker-of stdin w)
    (set! all-workers (append all-workers (list w)))
    ;; Stderr DRAIN (DEFERRED 164 open 4): this pipe used to be opened and
    ;; never read — anything the worker wrote outside the per-file capture was
    ;; lost, and past the ~64 KB pipe buffer the worker would block on it.
    (set-worker-state-drain!
     w
     (thread
      (λ ()
        (let loop ([kept 0])
          (define line (read-line stderr 'any))
          (unless (eof-object? line)
            (cond
              [(< kept WORKER-STDERR-MAX-LINES)
               (set-worker-state-stderr! w (cons (cons (now-ms) line) (worker-state-stderr w)))
               (loop (add1 kept))]
              [else
               (set-worker-state-stderr-dropped! w (add1 (worker-state-stderr-dropped w)))
               (loop kept)])))
        (close-input-port stderr))))
    ;; Send the first unit to each worker to get them started
    (dispatch-next! stdin)
    ;; Reader thread: parse JSONL from worker stdout → result channel
    (thread
     (λ ()
       (let loop ()
         (define line (read-line stdout 'any))
         (cond
           [(eof-object? line)
            (close-input-port stdout)]
           [else
            (define trimmed (string-trim line))
            (unless (string=? trimmed "")
              (with-handlers ([exn:fail? void])
                (define r (with-input-from-string trimmed read-json))
                (when (hash? r)
                  ;; PM Track 10C: tag result with worker stdin for work-stealing dispatch
                  (async-channel-put result-ch (cons stdin r)))))
            (loop)])))))

  ;; Collect results with progress output
  (define collected '())
  (define timeout-count 0)
  (define bailed? #f)
  (let loop ([remaining unit-count] [count 0] [first-waited 0])
    (when (> remaining 0)
      ;; Track 10B: Use short timeout (30s) for the FIRST result.
      ;; If no result arrives in 30s, workers likely crashed silently.
      ;; Subsequent results use the normal per-file timeout.
      ;;
      ;; ⚠⚠ 30s IS A LIVENESS PROBE, NOT A DEADLINE — and treating it as a
      ;; deadline made the runner UNUSABLE for its own slowest file. With
      ;; `--tests test-path-selection.rkt` that file IS the first result, and it
      ;; honestly takes ~112s, so the runner declared "⛔ DEAD WORKERS" at 30s and
      ;; advised recompiling — a diagnosis that is simply wrong, on a clean tree,
      ;; for a file that was running fine. (That is the documented "the targeted
      ;; runner ABORTS test-path-selection.rkt" wart; it was never about that
      ;; file.) The probe now RE-ARMS while the workers are actually alive, and
      ;; only reports dead workers when they are dead or the real timeout is
      ;; reached — so the banner means what it says.
      (define first-result-timeout 30)
      (define effective-timeout
        (if (= count 0) first-result-timeout (timeout-secs)))
      (define raw (sync/timeout (* effective-timeout 1.0) result-ch))
      (cond
        [raw
         ;; PM Track 10C: unpack (cons worker-stdin result-hash)
         (define worker-stdin (car raw))
         (define r (cdr raw))
         ;; Dispatch this worker's next eligible unit (or retire it)
         (dispatch-next! worker-stdin)
         (define ms (hash-ref r 'wall_ms))
         (define status (hash-ref r 'status))
         ;; A unit that says pass but ran 0 tests is labelled EMPTY: it is a
         ;; no-result for the gate below (DEFERRED 161), not a pass.
         (define-values (_m empty-here _f _s) (gate-verdict 1 (list r)))
         (printf "[~a/~a] ~a~a ~a (~as)\n"
                 (add1 count) unit-count
                 (hash-ref r 'file)
                 (if (hash-ref r 'shard #f) (format " [shard ~a]" (hash-ref r 'shard)) "")
                 (if (pair? empty-here) "EMPTY — 0 tests" (status-label status))
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
           (printf "║  ACTION: read the worker stderr below.                 ║\n")
           (printf "║  Common cause: a stale .zo (named below if so).        ║\n")
           (printf "╚══════════════════════════════════════════════════════════╝\n")
           (print-worker-stderr-digest all-workers))

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
            (loop (sub1 remaining) (add1 count) first-waited)])]
        [else
         ;; Timeout — check if this is dead-worker (first result never arrived)
         ;; vs per-file timeout (individual test took too long)
         (cond
           [(and (= count 0)
                 (< (+ first-waited first-result-timeout) (timeout-secs))
                 (ormap (λ (p) (eq? (subprocess-status p) 'running)) all-procs))
            ;; The workers are ALIVE — the first file is merely slow. Re-arm the
            ;; probe instead of misreporting a crash. The worker's own per-file
            ;; timeout is what bounds a genuine hang, and it produces a result,
            ;; so this cannot spin forever; the `first-waited` guard bounds it
            ;; regardless if a worker ever wedges without exiting.
            (loop remaining count (+ first-waited first-result-timeout))]
           [(= count 0)
            ;; No results AT ALL, and the workers are gone (or we have waited out
            ;; the full per-file budget) — this is the real crash case.
            (printf "\n")
            (printf "╔══════════════════════════════════════════════════════════╗\n")
            (printf "║  ⛔ DEAD WORKERS — no results after ~as               ║\n"
                    (+ first-waited first-result-timeout))
            (printf "║                                                        ║\n")
            (printf "║  All batch workers crashed before producing output.    ║\n")
            (printf "║  ACTION: read the worker stderr below.                 ║\n")
            (printf "║  Common cause: a stale .zo (named below if so).        ║\n")
            (printf "╚══════════════════════════════════════════════════════════╝\n")
            (print-worker-stderr-digest all-workers)
            (set! bailed? #t)]
           [else
            ;; Normal per-file timeout
            (eprintf "\nTIMEOUT: No result received for ~as. Killing ~a remaining.\n"
                     (timeout-secs) remaining)])
         (for ([p (in-list all-procs)])
           (with-handlers ([exn:fail? void])
             (subprocess-kill p #t)))])))

  ;; One result per UNIT as it arrived; folded to one result per FILE for the
  ;; summary counts and the timings record (suite-plan.rkt merge-shard-results).
  (define unit-results (reverse collected))
  (define file-results (merge-shard-results unit-results))

  ;; Wait for all worker processes to finish
  (for ([p (in-list all-procs)])
    (with-handlers ([exn:fail? void])
      (subprocess-wait p)))

  ;; Worker stderr into the run's logs (DEFERRED 164 open 4). The workers have
  ;; exited, so each drain reaches EOF; then: (1) worker-N.stderr.log holds a
  ;; worker's whole stderr, with a marker at each dispatch; (2) a FAILED unit's
  ;; log gains the stderr that arrived while it was current; (3) a dispatched
  ;; unit that never REPORTED gets a NO RESULT log carrying that stderr — the
  ;; only trace a worker that died mid-unit leaves.
  (for ([w (in-list all-workers)]) (sync/timeout 10 (worker-state-drain w)))
  (define reported-labels (for/hash ([r (in-list unit-results)]) (values (result-label r) #t)))
  (define no-result-files '())
  (for ([w (in-list all-workers)])
    (define dispatched (reverse (worker-state-dispatched w)))
    (define lines (reverse (worker-state-stderr w)))
    (define by-unit (attribute-stderr dispatched lines))
    (define pid (subprocess-pid (worker-state-proc w)))
    (define status (subprocess-status (worker-state-proc w)))
    (unless (null? lines)
      (with-output-to-file (build-path run-dir (format "worker-~a.stderr.log" (worker-state-index w)))
        #:exists 'replace
        (lambda ()
          (printf "=== worker ~a (pid ~a, exit ~a): stderr outside the per-file capture ===\n"
                  (worker-state-index w) pid status)
          (define events
            (sort (append (for/list ([d (in-list dispatched)])
                            (list (car d) 0 (format "--- [+~as] dispatched: ~a ---"
                                                    (real->decimal-string (/ (car d) 1000.0) 1)
                                                    (work-unit-label (cdr d)))))
                          (for/list ([l (in-list lines)]) (list (car l) 1 (cdr l))))
                  (lambda (a b) (or (< (car a) (car b))
                                    (and (= (car a) (car b)) (< (cadr a) (cadr b)))))))
          (for ([e (in-list events)]) (displayln (caddr e)))
          (when (> (worker-state-stderr-dropped w) 0)
            (printf "... ~a further lines dropped\n" (worker-state-stderr-dropped w))))))
    (for ([d (in-list dispatched)])
      (define u (cdr d))
      (define label (work-unit-label u))
      (define file (path->string (file-name-from-path (string->path (work-unit-path u)))))
      (define slabel (and (work-unit-shard u) (shard-label (work-unit-shard u) (work-unit-k u))))
      (define log (build-path run-dir (unit-log-name file slabel)))
      (define (evidence ls) (filter (lambda (l) (not (metric-line? l))) ls))
      (define err-lines (evidence (hash-ref by-unit label '())))
      (define startup (if (eq? d (car dispatched)) (evidence (hash-ref by-unit #f '())) '()))
      (cond
        [(not (hash-ref reported-labels label #f))
         (set! no-result-files (cons file no-result-files))
         (with-output-to-file log #:exists 'replace
           (lambda ()
             (printf "=== ~a — NO RESULT ===\n" label)
             (printf "run: ~a\n" run-id)
             (printf "Dispatched to worker ~a (pid ~a, exit status ~a); it never reported this unit.\n\n"
                     (worker-state-index w) pid status)
             (printf "--- Worker stderr while this unit was current ---\n")
             (for ([l (in-list (append startup err-lines))]) (displayln l))
             (when (null? (append startup err-lines)) (printf "(none)\n"))))]
        [(and (pair? err-lines) (file-exists? log))
         (with-output-to-file log #:exists 'append
           (lambda ()
             (printf "--- Worker stderr while this unit was current (outside the per-file capture) ---\n")
             (for ([l (in-list err-lines)]) (displayln l))))])))

  (define t1 (current-inexact-monotonic-milliseconds))
  (define total-wall-ms (inexact->exact (round (- t1 t0))))
  (define total-tests (apply + (map (λ (r) (hash-ref r 'tests)) file-results)))
  ;; ⚠ INCOMPLETE ≠ PASS. Every unit dispatched must report. The no-result
  ;; TIMEOUT path below kills the workers but used to fall through to here with
  ;; `bailed?` unset, so `andmap` over the results that DID arrive printed
  ;; "all pass" and recorded the partial run to timings.jsonl — observed
  ;; 2026-10-13: "1629 tests in 343.6s (490 files, …, all pass)" after 63 of 493
  ;; units, with a 63-result record written as a full run. A missing result is
  ;; now a failed, unrecorded run, whatever path produced it.
  ;; ⚠ AND every unit that reported pass must have RUN a test (DEFERRED 161):
  ;; a unit reporting pass with 0 tests is a no-result, exactly like a missing
  ;; one — unless its file is declared test-free (suite-plan.rkt
  ;; TEST-FREE-FILES). The gate is suite-plan.rkt's gate-verdict, unit-tested.
  (define-values (missing-count empty-units _failed-units stale-test-free)
    (gate-verdict unit-count unit-results))
  (define incomplete? (gate-incomplete? unit-count unit-results))
  (define all-pass? (gate-all-pass? unit-count unit-results))

  ;; Print summary
  (define failed-files
    (filter (λ (r) (not (string=? (hash-ref r 'status) "pass"))) file-results))
  ;; Failures are LISTED per unit, so a failing shard is named as such.
  (define failed-units
    (filter (λ (r) (not (string=? (hash-ref r 'status) "pass"))) unit-results))
  (define (unit-name r)
    (if (hash-ref r 'shard #f)
        (format "~a [shard ~a]" (hash-ref r 'file) (hash-ref r 'shard))
        (hash-ref r 'file)))
  (define incomplete-reason
    (string-join
     (append
      (if (> missing-count 0)
          (list (format "~a of ~a units reported" (length unit-results) unit-count))
          '())
      (if (pair? empty-units)
          (list (format "~a reported PASS with 0 tests: ~a" (length empty-units)
                        (string-join (map unit-name empty-units) ", ")))
          '()))
     "; "))
  ;; The failure-log views (DEFERRED 160 support). The ARCHIVE — run-dir — is
  ;; never edited. The top-level per-file view is refreshed for every file
  ;; this run reported: its old logs (whole-file and shard) are replaced by
  ;; this run's, so a passing file shows none — and its earlier evidence
  ;; survives in runs/<earlier-id>/.
  ;; Which worker ran which units, in order (DEFERRED 160 support ii).
  (define worker-seqs
    (worker-sequences project-root
                      (for/list ([w (in-list all-workers)])
                        (list (worker-state-index w)
                              (subprocess-pid (worker-state-proc w))
                              (map cdr (reverse (worker-state-dispatched w)))))))
  (define kept-run-dir?
    (refresh-failure-views! fail-root run-dir file-results
                            ;; kept when it holds evidence: a failure / no-result,
                            ;; or worker stderr beyond the prelude's metric lines
                            #:keep-run? (or (not all-pass?)
                                            (ormap (lambda (w) (pair? (worker-evidence-lines w)))
                                                   all-workers))
                            #:also-files no-result-files))
  (when kept-run-dir?
    (with-handlers ([exn:fail? void])
      (call-with-output-file (build-path run-dir "run.json") #:exists 'replace
        (lambda (out)
          (write-json (hasheq 'run_id run-id
                              'checkout project-root
                              'command (string-join (vector->list (current-command-line-arguments)) " ")
                              'verdict (cond [bailed? "aborted"] [incomplete? "incomplete"]
                                             [all-pass? "pass"] [else "fail"])
                              'unit_count unit-count
                              'units_reported (length unit-results)
                              'workers worker-seqs)
                      out)
          (newline out)))))
  (define completed-count (length file-results))
  (printf "\n~a tests in ~as (~a~a files, ~a batch workers, ~a)\n"
          total-tests
          (real->decimal-string (/ total-wall-ms 1000.0) 1)
          (if (or bailed? incomplete?) (format "~a of " completed-count) "")
          file-count
          jobs
          (cond [bailed? (format "ABORTED — ~a timeouts" timeout-count)]
                [incomplete? (format "INCOMPLETE — ~a" incomplete-reason)]
                [all-pass? "all pass"]
                [else (format "~a FAILURES" (length failed-files))]))
  (for ([r (in-list stale-test-free)])
    (printf "NOTE: ~a is declared test-free (suite-plan.rkt TEST-FREE-FILES) but ran ~a tests — remove the declaration.\n"
            (unit-name r) (hash-ref r 'tests 0)))
  (unless all-pass?
    (for ([r (in-list empty-units)])
      (printf "\n~a\n" (make-string 60 #\─))
      (printf "EMPTY: ~a — reported PASS but ran 0 tests: counted as NO RESULT (DEFERRED 161).\n"
              (unit-name r))
      (printf "    A file that genuinely holds no tests goes in suite-plan.rkt TEST-FREE-FILES.\n"))
    (for ([r (in-list failed-units)])
      (printf "\n~a\n" (make-string 60 #\─))
      (printf "FAILED: ~a\n" (unit-name r))
      (when (hash-has-key? r 'error_output)
        (define msg (hash-ref r 'error_output))
        ;; Print full diagnostic content inline — no need to open log files
        (for ([line (in-list (string-split msg "\n"))])
          (printf "    ~a\n" line)))
      (newline))
    (printf "~a\n" (make-string 60 #\─))
    (printf "Failure logs: data/benchmarks/failures/*.log (latest per file); this run: ~a\n"
            (if kept-run-dir? (format "data/benchmarks/failures/runs/~a/" run-id) "(none written)"))
    ;; I2 (Track 2B process): diagnostic protocol reminder when 3+ failures.
    ;; Longitudinal pattern 3 (diagnostic discipline regression, 4+ PIRs): under
    ;; implementation pressure, the protocol of "audit domain → hypothesize →
    ;; test narrowly" gets skipped in favor of full-suite re-runs. Reminder
    ;; nudges toward the protocol without blocking.
    (when (>= (length failed-files) 3)
      (printf "\n~a\n" (make-string 60 #\═))
      (printf "DIAGNOSTIC PROTOCOL REMINDER (~a failures):\n" (length failed-files))
      (printf "  1. AUDIT: read ALL failure logs (data/benchmarks/failures/*.log)\n")
      (printf "  2. HYPOTHESIZE: categorize failures by symptom + root-cause class\n")
      (printf "  3. TEST NARROWLY: raco test tests/test-NAME.rkt per hypothesis\n")
      (printf "  4. CHALLENGE BY PRINCIPLES: are we working around a deeper issue?\n")
      (printf "  Do NOT re-run the full suite to diagnose. See .claude/rules/workflow.md\n")
      (printf "~a\n" (make-string 60 #\═))))

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
                      [incomplete? (format ", INCOMPLETE — ~a" incomplete-reason)]
                      [all-pass? ", all pass"]
                      [else (format ", ~a FAILURES" (length failed-files))]))
        (unless all-pass?
          (printf "\nFailed files:\n")
          (for ([r (in-list failed-units)])
            (printf "  ~a\n" (unit-name r))
            (when (hash-has-key? r 'error_output)
              (define lines (string-split (hash-ref r 'error_output) "\n"))
              (for ([line (in-list (take lines (min 5 (length lines))))])
                (printf "    ~a\n" line))))))))

  ;; Record to JSONL (unless --no-record or early bail)
  (when (and (record-timings?) (not bailed?) (not incomplete?))
    (define timings-file (make-timings-path project-root))
    (define record
      (hasheq 'schema_version TIMINGS-SCHEMA-VERSION
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
              'unit_count unit-count
              'all_pass all-pass?
              'source "affected"
              'workers worker-seqs         ; DEFERRED 160 support ii
              'results file-results))
    (append-run-record timings-file record)
    (printf "Timings recorded to ~a\n" (path->string timings-file)))

  (when (or bailed? incomplete?) (exit EXIT-INCOMPLETE))
  (unless all-pass? (exit EXIT-FAILURES)))

(main)
