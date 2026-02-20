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
  (define total (length test-names))
  (printf "Benchmarking ~a test files (~a parallel, timeout: ~as per test)...\n\n"
          total num-jobs timeout-secs)

  (define work-ch (make-async-channel))
  (define result-ch (make-async-channel))

  ;; Spawn worker threads
  (define workers
    (for/list ([_ (in-range num-jobs)])
      (thread
       (λ ()
         (let loop ()
           (define item (async-channel-get work-ch))
           (unless (eq? item 'done)
             (define test-path (cdr item))
             (define result (benchmark-one-test test-path timeout-secs))
             (async-channel-put result-ch result)
             (loop)))))))

  ;; Enqueue all work items
  (define t0-total (current-inexact-monotonic-milliseconds))
  (for ([name (in-list test-names)])
    (async-channel-put work-ch
      (cons name (path->string (build-path tests-dir (symbol->string name))))))

  ;; Signal workers to stop (after all work is enqueued)
  (for ([_ (in-range num-jobs)])
    (async-channel-put work-ch 'done))

  ;; Collect results, print progress as they arrive
  (define results
    (for/list ([i (in-range total)])
      (define result (async-channel-get result-ch))
      (define ms (hash-ref result 'wall_ms))
      (define status (hash-ref result 'status))
      (printf "[~a/~a] ~a ~a (~as)\n"
              (add1 i) total
              (hash-ref result 'file)
              (status-label status)
              (real->decimal-string (/ ms 1000.0) 1))
      (flush-output)
      result))

  ;; Wait for all worker threads to finish
  (for ([w (in-list workers)])
    (thread-wait w))

  (define t1-total (current-inexact-monotonic-milliseconds))
  (define total-wall-ms (inexact->exact (round (- t1-total t0-total))))
  (define total-tests (apply + (map (λ (r) (hash-ref r 'tests)) results)))
  (define all-pass? (andmap (λ (r) (string=? (hash-ref r 'status) "pass")) results))

  ;; Build run record
  (define record
    (hasheq 'timestamp (current-iso-timestamp)
            'commit (current-commit)
            'branch (current-branch)
            'machine (string-append (symbol->string (system-type 'os))
                                    "-"
                                    (symbol->string (system-type 'arch)))
            'jobs num-jobs
            'total_wall_ms total-wall-ms
            'total_tests total-tests
            'file_count total
            'all_pass all-pass?
            'source "benchmark"
            'results results))

  ;; Append to JSONL file
  (append-run-record timings-file record)

  ;; Print summary
  (printf "\n--- Summary ---\n")
  (printf "Total: ~as (~a files, ~a tests, ~a jobs, ~a)\n"
          (real->decimal-string (/ total-wall-ms 1000.0) 1)
          total
          total-tests
          num-jobs
          (if all-pass? "all pass" "SOME FAILURES"))
  (printf "Results appended to ~a\n" (path->string timings-file))

  ;; Auto-detect regressions against previous run
  (define has-regressions? #f)
  (define runs (read-all-runs timings-file))
  (when (>= (length runs) 2)
    (define prev-run (list-ref runs (- (length runs) 2)))
    (define regressions (detect-regressions record prev-run reg-threshold))
    (unless (null? regressions)
      (set! has-regressions? #t)
      (printf "\nRegressions detected (>~a% vs ~a):\n"
              reg-threshold (hash-ref prev-run 'commit))
      (for ([reg (in-list regressions)])
        (printf "  ~a  ~as -> ~as (+~a%)\n"
                (pad-str (hash-ref reg 'file) 35)
                (pad-str (real->decimal-string (/ (hash-ref reg 'prev_ms) 1000.0) 1) 7 'right)
                (pad-str (real->decimal-string (/ (hash-ref reg 'curr_ms) 1000.0) 1) 7 'right)
                (real->decimal-string (hash-ref reg 'delta_pct) 0)))))

  ;; Return success status (pass + no regressions)
  (and all-pass? (not has-regressions?)))

;; ============================================================
;; Regression detection
;; ============================================================

(define (detect-regressions current-run prev-run threshold-pct)
  (define prev-by-file
    (for/hasheq ([r (in-list (hash-ref prev-run 'results))])
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
    (for/hasheq ([r (in-list (hash-ref target-run 'results))])
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
