#lang racket/base

;; benchmark-tests.rkt — Parallel per-file test timing with persistent recording
;;
;; Usage:
;;   racket tools/benchmark-tests.rkt                     # benchmark all tests (parallel)
;;   racket tools/benchmark-tests.rkt --jobs 1            # sequential mode
;;   racket tools/benchmark-tests.rkt --files test-a.rkt test-b.rkt  # specific files
;;   racket tools/benchmark-tests.rkt --report            # summarize last run
;;   racket tools/benchmark-tests.rkt --compare HEAD~1    # compare vs previous commit
;;   racket tools/benchmark-tests.rkt --slowest 10        # top N slowest from last run
;;   racket tools/benchmark-tests.rkt --trend test-a.rkt  # timing history for one file
;;   racket tools/benchmark-tests.rkt --timeout 300       # per-test timeout in seconds (default: 600)
;;   racket tools/benchmark-tests.rkt --regression-threshold 15  # flag >15% regressions (default: 10)
;;   racket tools/benchmark-tests.rkt --no-precompile           # skip bytecode pre-compilation
;;
;; Results are appended to data/benchmarks/timings.jsonl (one JSON object per run).
;; After each run, automatically compares against previous run and flags regressions.
;; See docs/tracking/2026-02-19_BENCHMARKING_INFRASTRUCTURE.md

(require racket/cmdline
         racket/list
         racket/path
         racket/string
         racket/system
         racket/async-channel
         racket/future  ;; for processor-count
         json
         "dep-graph.rkt"
         "bench-lib.rkt")

(define do-precompile? (make-parameter #t))

;; ============================================================
;; Path anchoring
;; ============================================================

(define tools-dir
  (let ([src (resolved-module-path-name
              (variable-reference->resolved-module-path
               (#%variable-reference)))])
    (simplify-path (path-only src))))

(define project-root
  (path->string (simplify-path (build-path tools-dir ".."))))

(define tests-dir (build-path project-root "tests"))
(define timings-file (make-timings-path project-root))

;; ============================================================
;; Parallel benchmark suite
;; ============================================================

(define (run-benchmark test-names timeout-secs num-jobs reg-threshold)
  (define file-count (length test-names))
  (define test-paths
    (for/list ([name (in-list test-names)])
      (path->string (build-path tests-dir (symbol->string name)))))

  ;; Pre-compile modules to bytecode (reduces per-subprocess overhead from ~22s to ~1s)
  (when (do-precompile?)
    (printf "Pre-compiling modules...\n")
    (define precomp-t0 (current-inexact-monotonic-milliseconds))
    (precompile-modules! project-root)
    (define precomp-ms (- (current-inexact-monotonic-milliseconds) precomp-t0))
    (printf "Pre-compiled in ~as\n\n"
            (real->decimal-string (/ precomp-ms 1000.0) 1)))

  (printf "Benchmarking ~a files (~a parallel, timeout: ~as per test)...\n\n"
          file-count num-jobs timeout-secs)

  (define work-ch (make-async-channel))
  (define result-ch (make-async-channel))

  ;; Spawn worker threads
  (define workers
    (for/list ([_ (in-range num-jobs)])
      (thread
       (λ ()
         (let loop ()
           (define path (async-channel-get work-ch))
           (unless (eq? path 'done)
             (define result (benchmark-one-test path timeout-secs))
             (async-channel-put result-ch result)
             (loop)))))))

  ;; Enqueue all test paths
  (define t0-total (current-inexact-monotonic-milliseconds))
  (for ([p (in-list test-paths)])
    (async-channel-put work-ch p))

  ;; Signal workers to stop (after all work is enqueued)
  (for ([_ (in-range num-jobs)])
    (async-channel-put work-ch 'done))

  ;; Collect results, print progress as they arrive
  (define file-results
    (for/list ([i (in-range file-count)])
      (define r (async-channel-get result-ch))
      (define ms (hash-ref r 'wall_ms))
      (define status (hash-ref r 'status))
      (printf "[~a/~a] ~a ~a (~as)\n"
              (add1 i) file-count
              (hash-ref r 'file)
              (status-label status)
              (real->decimal-string (/ ms 1000.0) 1))
      (flush-output)
      r))

  ;; Wait for all worker threads to finish
  (for ([w (in-list workers)])
    (thread-wait w))

  (define t1-total (current-inexact-monotonic-milliseconds))
  (define total-wall-ms (inexact->exact (round (- t1-total t0-total))))
  (define total-tests (apply + (map (λ (r) (hash-ref r 'tests)) file-results)))
  (define all-pass? (andmap (λ (r) (string=? (hash-ref r 'status) "pass")) file-results))

  ;; Build run record
  (define record
    (hasheq 'schema_version 3
            'timestamp (current-iso-timestamp)
            'commit (current-commit)
            'branch (current-branch)
            'machine (string-append (symbol->string (system-type 'os))
                                    "-"
                                    (symbol->string (system-type 'arch)))
            'jobs num-jobs
            'total_wall_ms total-wall-ms
            'total_tests total-tests
            'file_count file-count
            'all_pass all-pass?
            'source "benchmark"
            'results file-results))

  ;; Append to JSONL file
  (append-run-record timings-file record)

  ;; Print summary
  (printf "\n--- Summary ---\n")
  (printf "Total: ~as (~a files, ~a tests, ~a jobs, ~a)\n"
          (real->decimal-string (/ total-wall-ms 1000.0) 1)
          file-count
          total-tests
          num-jobs
          (if all-pass? "all pass" "SOME FAILURES"))
  (printf "Results appended to ~a\n" (path->string timings-file))

  ;; Auto-detect regressions against multi-run median baseline
  (define has-regressions? #f)
  (define runs (read-all-runs timings-file))
  (when (>= (length runs) 2)
    (define regressions (detect-regressions-v2 record runs reg-threshold))
    (unless (null? regressions)
      (set! has-regressions? #t)
      (printf "\nRegressions detected (>~a% AND >500ms vs median baseline):\n"
              reg-threshold)
      (for ([reg (in-list regressions)])
        (printf "  ~a  baseline ~as -> ~as (+~a%, +~ams, n=~a)\n"
                (pad-str (hash-ref reg 'file) 35)
                (pad-str (real->decimal-string (/ (hash-ref reg 'baseline_ms) 1000.0) 1) 7 'right)
                (pad-str (real->decimal-string (/ (hash-ref reg 'curr_ms) 1000.0) 1) 7 'right)
                (real->decimal-string (hash-ref reg 'delta_pct) 0)
                (hash-ref reg 'delta_ms)
                (hash-ref reg 'baseline_n)))))

  ;; Flag high-variance files across recent runs
  (when (>= (length runs) 3)
    (define hv (flag-high-variance runs))
    (unless (null? hv)
      (printf "\nHigh-variance files (CV > 15%% across recent runs):\n")
      (for ([f (in-list (sort hv > #:key (λ (h) (hash-ref h 'cv_pct))))])
        (printf "  ~a  CV=~a%  (n=~a)\n"
                (pad-str (hash-ref f 'file) 35)
                (real->decimal-string (hash-ref f 'cv_pct) 1)
                (hash-ref f 'sample_count)))))

  ;; Structured summary: phase breakdown + heartbeat totals
  (print-structured-summary file-results)

  ;; Return success status (pass + no regressions)
  (and all-pass? (not has-regressions?)))

;; ============================================================
;; Regression detection (v2: multi-run median baseline)
;; ============================================================

;; detect-regressions-v2: use median of last N runs as baseline.
;; Requires BOTH percentage AND absolute threshold to flag a regression.
;; This prevents flagging 100ms → 120ms (+20%) as a regression when
;; the absolute delta (20ms) is within normal noise.
(define (detect-regressions-v2 current-run all-runs threshold-pct
                               #:baseline-count [baseline-count 5]
                               #:min-absolute-ms [min-absolute-ms 500])
  ;; Collect up to baseline-count previous runs (excluding current)
  (define prev-runs
    (let ([all-but-last (if (>= (length all-runs) 2)
                            (take all-runs (sub1 (length all-runs)))
                            '())])
      (take-right all-but-last (min baseline-count (length all-but-last)))))

  (when (null? prev-runs) (list))  ;; no baseline available

  ;; Build per-file median baseline from previous runs
  (define file-baselines (make-hasheq))  ;; file -> (listof ms)
  (for ([run (in-list prev-runs)])
    (for ([r (in-list (hash-ref run 'results '()))])
      (define file (hash-ref r 'file))
      (define ms (hash-ref r 'wall_ms))
      (hash-set! file-baselines file
                 (cons ms (hash-ref file-baselines file '())))))

  (define (list-median xs)
    (define sorted (sort xs <))
    (define n (length sorted))
    (cond
      [(zero? n) 0]
      [(odd? n) (list-ref sorted (quotient n 2))]
      [else (/ (+ (list-ref sorted (sub1 (quotient n 2)))
                  (list-ref sorted (quotient n 2))) 2)]))

  (filter-map
   (λ (r)
     (define file (hash-ref r 'file))
     (define baseline-samples (hash-ref file-baselines file '()))
     (and (not (null? baseline-samples))
          (let* ([cur-ms (hash-ref r 'wall_ms)]
                 [baseline-ms (list-median baseline-samples)]
                 [delta-ms (- cur-ms baseline-ms)]
                 [pct (if (zero? baseline-ms) 0
                          (* 100.0 (/ delta-ms baseline-ms)))])
            ;; Both % AND absolute threshold must be exceeded
            (and (> pct threshold-pct)
                 (> delta-ms min-absolute-ms)
                 (hasheq 'file file
                         'baseline_ms baseline-ms
                         'baseline_n (length baseline-samples)
                         'curr_ms cur-ms
                         'delta_ms (inexact->exact (round delta-ms))
                         'delta_pct pct)))))
   (hash-ref current-run 'results)))

;; Legacy single-run regression detection (kept for --compare mode)
(define (detect-regressions current-run prev-run threshold-pct)
  (define prev-by-file
    (for/hash ([r (in-list (hash-ref prev-run 'results))])
      (values (hash-ref r 'file) r)))
  (filter-map
   (λ (r)
     (define file (hash-ref r 'file))
     (define prev (hash-ref prev-by-file file #f))
     (and prev
          (let* ([cur-ms (hash-ref r 'wall_ms)]
                 [prev-ms (hash-ref prev 'wall_ms)]
                 [pct (if (zero? prev-ms) 0 (* 100.0 (/ (- cur-ms prev-ms) prev-ms)))])
            (and (> pct threshold-pct)
                 (hasheq 'file file
                         'prev_ms prev-ms
                         'curr_ms cur-ms
                         'delta_pct pct)))))
   (hash-ref current-run 'results)))

;; flag-high-variance: identify files with CV > threshold across recent runs.
;; Returns list of hasheq with file, cv_pct, sample_count.
(define (flag-high-variance all-runs
                            #:baseline-count [baseline-count 5]
                            #:max-cv [max-cv 15.0])
  (define prev-runs (take-right all-runs (min baseline-count (length all-runs))))
  (when (< (length prev-runs) 3) (list))  ;; need ≥3 runs for meaningful CV

  ;; Collect per-file timing samples
  (define file-samples (make-hasheq))
  (for ([run (in-list prev-runs)])
    (for ([r (in-list (hash-ref run 'results '()))])
      (define file (hash-ref r 'file))
      (define ms (hash-ref r 'wall_ms))
      (hash-set! file-samples file
                 (cons ms (hash-ref file-samples file '())))))

  (filter-map
   (λ (kv)
     (define file (car kv))
     (define samples (cdr kv))
     (and (>= (length samples) 3)
          (let* ([m (/ (apply + samples) (length samples))]
                 [sq-diffs (map (λ (x) (expt (- x m) 2)) samples)]
                 [sd (sqrt (/ (apply + sq-diffs) (sub1 (length samples))))]
                 [cv-pct (if (zero? m) 0.0 (* 100.0 (/ sd (abs m))))])
            (and (> cv-pct max-cv)
                 (hasheq 'file file
                         'cv_pct (exact->inexact cv-pct)
                         'sample_count (length samples))))))
   (hash->list file-samples)))

;; ============================================================
;; Structured summary with phase attribution
;; ============================================================

(define (print-structured-summary results)
  ;; Aggregate heartbeats, phases, and memory across all files
  (define total-hb (make-hasheq))
  (define total-phases (make-hasheq))
  (define total-mem-retained 0)
  (define total-gc-ms 0)
  (define files-with-hb 0)
  (define files-with-phases 0)
  (define files-with-mem 0)
  (for ([r (in-list results)])
    (define hb (hash-ref r 'heartbeats #f))
    (when hb
      (set! files-with-hb (add1 files-with-hb))
      (for ([(k v) (in-hash hb)])
        (hash-set! total-hb k (+ (hash-ref total-hb k 0) v))))
    (define ph (hash-ref r 'phases #f))
    (when ph
      (set! files-with-phases (add1 files-with-phases))
      (for ([(k v) (in-hash ph)])
        (hash-set! total-phases k (+ (hash-ref total-phases k 0) v))))
    (define mem (hash-ref r 'memory #f))
    (when mem
      (set! files-with-mem (add1 files-with-mem))
      (set! total-mem-retained (+ total-mem-retained
                                  (hash-ref mem 'mem_retained_bytes 0)))
      (set! total-gc-ms (+ total-gc-ms (hash-ref mem 'gc_ms 0)))))

  ;; Print heartbeat totals
  (when (> files-with-hb 0)
    (printf "\n--- Heartbeat Totals (~a files) ---\n" files-with-hb)
    (define sorted-hb (sort (hash->list total-hb) > #:key cdr))
    (for ([kv (in-list sorted-hb)]
          #:when (> (cdr kv) 0))
      (printf "  ~a  ~a\n"
              (pad-str (symbol->string (car kv)) 22)
              (pad-str (number->string (cdr kv)) 10 'right))))

  ;; Print phase timing breakdown
  (when (> files-with-phases 0)
    (printf "\n--- Phase Timing Totals (~a files) ---\n" files-with-phases)
    (define sorted-ph (sort (hash->list total-phases) > #:key cdr))
    (define total-phase-ms
      (apply + (map cdr (hash->list total-phases))))
    (for ([kv (in-list sorted-ph)]
          #:when (> (cdr kv) 0))
      (define ms (cdr kv))
      (define pct (if (zero? total-phase-ms) 0 (* 100.0 (/ ms total-phase-ms))))
      (printf "  ~a  ~as  (~a%)\n"
              (pad-str (symbol->string (car kv)) 18)
              (pad-str (real->decimal-string (/ ms 1000.0) 1) 8 'right)
              (real->decimal-string pct 0))))

  ;; Print memory summary
  (when (> files-with-mem 0)
    (printf "\n--- Memory Summary (~a files) ---\n" files-with-mem)
    (define mb (/ total-mem-retained 1048576.0))
    (printf "  Total retained: ~aMB  GC time: ~as\n"
            (real->decimal-string mb 1)
            (real->decimal-string (/ total-gc-ms 1000.0) 1))))

;; ============================================================
;; Reporting
;; ============================================================

(define (report-last)
  (define runs (read-all-runs timings-file))
  (when (null? runs)
    (printf "No benchmark data found in ~a\n" (path->string timings-file))
    (exit 0))
  (define last-run (last runs))
  (printf "Last run (~a, ~a ~a):\n"
          (hash-ref last-run 'commit)
          (hash-ref last-run 'branch)
          (hash-ref last-run 'timestamp))
  (define jobs (hash-ref last-run 'jobs 1))
  (printf "  Total: ~as (~a files, ~a tests, ~a jobs, ~a)\n\n"
          (real->decimal-string (/ (hash-ref last-run 'total_wall_ms) 1000.0) 1)
          (hash-ref last-run 'file_count)
          (hash-ref last-run 'total_tests)
          jobs
          (if (hash-ref last-run 'all_pass) "all pass" "SOME FAILURES"))
  (print-slowest-n (hash-ref last-run 'results) 10))

(define (print-slowest-n results n)
  (define sorted (sort results > #:key (λ (r) (hash-ref r 'wall_ms))))
  (define top (take sorted (min n (length sorted))))
  (printf "  Slowest ~a:\n" (min n (length sorted)))
  (for ([r (in-list top)])
    (printf "    ~a  ~as  (~a tests, ~a)\n"
            (pad-str (hash-ref r 'file) 35)
            (pad-str (real->decimal-string (/ (hash-ref r 'wall_ms) 1000.0) 1) 7 'right)
            (hash-ref r 'tests)
            (hash-ref r 'status))))

(define (report-slowest n)
  (define runs (read-all-runs timings-file))
  (when (null? runs)
    (printf "No benchmark data found.\n")
    (exit 0))
  (define last-run (last runs))
  (printf "Slowest ~a from last run (~a):\n\n" n (hash-ref last-run 'commit))
  (print-slowest-n (hash-ref last-run 'results) n))

(define (report-compare ref)
  (define target-commit (string-trim (git-output "rev-parse" "--short" ref)))
  (define runs (read-all-runs timings-file))
  (define current-run (and (not (null? runs)) (last runs)))
  (define target-run
    (for/first ([r (in-list (reverse runs))]
                #:when (string=? (hash-ref r 'commit) target-commit))
      r))
  (unless current-run
    (printf "No benchmark data found.\n")
    (exit 0))
  (unless target-run
    (printf "No benchmark data found for commit ~a.\n" target-commit)
    (printf "Available commits: ~a\n"
            (string-join (remove-duplicates (map (λ (r) (hash-ref r 'commit)) runs)) ", "))
    (exit 0))
  (printf "Comparing ~a vs ~a:\n\n"
          (hash-ref current-run 'commit)
          (hash-ref target-run 'commit))
  ;; Build lookup for target results
  (define target-by-file
    (for/hash ([r (in-list (hash-ref target-run 'results))])
      (values (hash-ref r 'file) r)))
  ;; Compare each file in current run
  (for ([r (in-list (sort (hash-ref current-run 'results) > #:key (λ (r) (hash-ref r 'wall_ms))))])
    (define file (hash-ref r 'file))
    (define cur-ms (hash-ref r 'wall_ms))
    (define prev (hash-ref target-by-file file #f))
    (cond
      [prev
       (define prev-ms (hash-ref prev 'wall_ms))
       (define pct (if (zero? prev-ms) 0 (* 100.0 (/ (- cur-ms prev-ms) prev-ms))))
       (define flag (cond [(> pct 10) " REGRESSION"] [(< pct -10) " IMPROVEMENT"] [else ""]))
       (printf "  ~a  ~as -> ~as (~a%)~a\n"
               (pad-str file 35)
               (pad-str (real->decimal-string (/ prev-ms 1000.0) 1) 7 'right)
               (pad-str (real->decimal-string (/ cur-ms 1000.0) 1) 7 'right)
               (if (>= pct 0)
                   (string-append "+" (real->decimal-string pct 0))
                   (real->decimal-string pct 0))
               flag)]
      [else
       (printf "  ~a  ~as (NEW)\n"
               (pad-str file 35)
               (pad-str (real->decimal-string (/ cur-ms 1000.0) 1) 7 'right))])))

;; ============================================================
;; Trend reporting
;; ============================================================

(define (report-trend test-file depth)
  (define runs (read-all-runs timings-file))
  (when (null? runs)
    (printf "No benchmark data found.\n")
    (exit 0))
  (define recent (take-right runs (min depth (length runs))))
  ;; Find entries for this file across recent runs
  (define entries
    (filter-map
     (λ (run)
       (define result
         (for/first ([r (in-list (hash-ref run 'results))]
                     #:when (string=? (hash-ref r 'file) test-file))
           r))
       (and result (list run result)))
     recent))
  (when (null? entries)
    (printf "No data found for ~a in last ~a runs.\n" test-file depth)
    (printf "Available files: ~a\n"
            (string-join
             (sort (remove-duplicates
                    (apply append
                           (map (λ (run) (map (λ (r) (hash-ref r 'file))
                                              (hash-ref run 'results)))
                                (take-right runs (min 3 (length runs))))))
                   string<?)
             ", "))
    (exit 0))
  (printf "Trend for ~a (last ~a runs):\n\n" test-file (length entries))
  ;; Print entries with delta vs next (chronologically)
  (for ([entry (in-list entries)]
        [i (in-naturals)])
    (define run (first entry))
    (define result (second entry))
    (define ms (hash-ref result 'wall_ms))
    (define ts (hash-ref run 'timestamp))
    (define commit (hash-ref run 'commit))
    (define tests (hash-ref result 'tests))
    (define status (hash-ref result 'status))
    ;; Compare vs next entry (if exists)
    (define delta-str
      (cond
        [(< (add1 i) (length entries))
         (define next-ms (hash-ref (second (list-ref entries (add1 i))) 'wall_ms))
         (define pct (if (zero? next-ms) 0 (* 100.0 (/ (- ms next-ms) next-ms))))
         (cond [(> pct 10)
                (format "  +~a% vs next" (real->decimal-string pct 0))]
               [(< pct -10)
                (format "  ~a% vs next" (real->decimal-string pct 0))]
               [else ""])]
        [else ""]))
    (printf "  ~a  ~a  ~as  (~a tests, ~a)~a\n"
            (pad-str ts 20)
            (pad-str commit 8)
            (pad-str (real->decimal-string (/ ms 1000.0) 1) 7 'right)
            tests
            status
            delta-str)))

;; ============================================================
;; CLI
;; ============================================================

(define mode (make-parameter 'run))
(define file-list (make-parameter '()))
(define slowest-n (make-parameter 10))
(define compare-ref (make-parameter #f))
(define timeout-secs (make-parameter 600))
(define num-jobs (make-parameter (processor-count)))
(define regression-threshold (make-parameter 10))
(define trend-file (make-parameter #f))
(define trend-depth (make-parameter 10))

(define (main)
  (command-line
   #:program "benchmark-tests"
   #:once-any
   ["--report" "Print summary of last benchmark run"
    (mode 'report)]
   ["--compare" ref "Compare last run vs a previous commit"
    (mode 'compare) (compare-ref ref)]
   ["--slowest" n "Print top N slowest tests from last run"
    (mode 'slowest) (slowest-n (string->number n))]
   ["--trend" file "Show timing history for a test file"
    (mode 'trend) (trend-file file)]
   #:once-each
   ["--timeout" secs "Per-test timeout in seconds (default: 600)"
    (timeout-secs (string->number secs))]
   ["--jobs" n "Number of parallel workers (default: processor-count)"
    (num-jobs (string->number n))]
   ["--regression-threshold" pct "Flag regressions above this % (default: 10)"
    (regression-threshold (string->number pct))]
   ["--depth" n "Number of runs for --trend (default: 10)"
    (trend-depth (string->number n))]
   ["--no-precompile" "Skip bytecode pre-compilation step"
    (do-precompile? #f)]
   #:multi
   ["--files" file "Benchmark specific test file(s)"
    (file-list (cons (string->symbol file) (file-list)))])

  (case (mode)
    [(report) (report-last)]
    [(compare) (report-compare (compare-ref))]
    [(slowest) (report-slowest (slowest-n))]
    [(trend) (report-trend (trend-file) (trend-depth))]
    [(run)
     (define test-names
       (if (null? (file-list))
           (sort (all-test-files) symbol<?)
           (reverse (file-list))))
     (define ok? (run-benchmark test-names (timeout-secs) (num-jobs) (regression-threshold)))
     (unless ok? (exit 1))]))

(main)
