#lang racket/base

;; benchmark-tests.rkt — Per-file test timing with persistent recording
;;
;; Usage:
;;   racket tools/benchmark-tests.rkt                     # benchmark all tests
;;   racket tools/benchmark-tests.rkt --files test-a.rkt test-b.rkt  # specific files
;;   racket tools/benchmark-tests.rkt --report            # summarize last run
;;   racket tools/benchmark-tests.rkt --compare HEAD~1    # compare vs previous commit
;;   racket tools/benchmark-tests.rkt --slowest 10        # top N slowest from last run
;;   racket tools/benchmark-tests.rkt --timeout 300       # per-test timeout in seconds (default: 600)
;;
;; Results are appended to data/benchmarks/timings.jsonl (one JSON object per run).
;; See docs/tracking/2026-02-19_BENCHMARKING_INFRASTRUCTURE.md

(require racket/cmdline
         racket/list
         racket/path
         racket/port
         racket/string
         racket/system
         json
         racket/date
         "dep-graph.rkt")

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
(define timings-file (build-path project-root "data" "benchmarks" "timings.jsonl"))

;; ============================================================
;; Git metadata
;; ============================================================

(define (git-output . args)
  (define cmd (string-join (cons "git" args) " "))
  (string-trim (with-output-to-string (λ () (system cmd)))))

(define (current-commit) (git-output "rev-parse" "--short" "HEAD"))
(define (current-branch) (git-output "rev-parse" "--abbrev-ref" "HEAD"))

;; ============================================================
;; Benchmark one test file
;; ============================================================

(define (benchmark-one-test test-path timeout-secs)
  (define t0 (current-inexact-milliseconds))
  (define raco-path (find-executable-path "raco"))
  (define-values (proc stdout-port stdin-port stderr-port)
    (subprocess #f #f #f raco-path "test" test-path))
  (close-output-port stdin-port)
  ;; Wait with timeout via polling
  (define deadline (+ t0 (* timeout-secs 1000.0)))
  (let loop ()
    (define status (subprocess-status proc))
    (cond
      [(not (eq? status 'running))
       ;; Process finished
       (define output (port->string stdout-port))
       (close-input-port stdout-port)
       (close-input-port stderr-port)
       (define t1 (current-inexact-milliseconds))
       (define wall-ms (inexact->exact (round (- t1 t0))))
       (define ok? (zero? status))
       (define test-count (extract-test-count output))
       (hasheq 'file (path->string (file-name-from-path (string->path test-path)))
               'wall_ms wall-ms
               'status (if ok? "pass" "fail")
               'tests test-count)]
      [(> (current-inexact-milliseconds) deadline)
       ;; Timeout — kill the process
       (subprocess-kill proc #t)
       (close-input-port stdout-port)
       (close-input-port stderr-port)
       (define t1 (current-inexact-milliseconds))
       (define wall-ms (inexact->exact (round (- t1 t0))))
       (hasheq 'file (path->string (file-name-from-path (string->path test-path)))
               'wall_ms wall-ms
               'status "timeout"
               'tests 0)]
      [else
       (sleep 0.5)
       (loop)])))

;; Extract "N tests passed" from raco test output
(define (extract-test-count output)
  (define lines (string-split output "\n"))
  (for/fold ([count 0]) ([line (in-list lines)])
    (cond
      [(regexp-match #rx"([0-9]+) tests? passed" line)
       => (λ (m) (string->number (cadr m)))]
      [else count])))

;; ============================================================
;; Run benchmark suite
;; ============================================================

(define (run-benchmark test-names timeout-secs)
  (define total (length test-names))
  (printf "Benchmarking ~a test files (timeout: ~as per test)...\n\n" total timeout-secs)
  (define t0-total (current-inexact-milliseconds))
  (define results
    (for/list ([name (in-list test-names)]
               [i (in-naturals 1)])
      (define test-path (path->string (build-path tests-dir (symbol->string name))))
      (printf "[~a/~a] ~a ... " i total name)
      (flush-output)
      (define result (benchmark-one-test test-path timeout-secs))
      (define ms (hash-ref result 'wall_ms))
      (define status (hash-ref result 'status))
      (printf "~a (~as)\n"
              (cond [(string=? status "pass") "PASS"]
                    [(string=? status "fail") "FAIL"]
                    [else "TIMEOUT"])
              (real->decimal-string (/ ms 1000.0) 1))
      (flush-output)
      result))
  (define t1-total (current-inexact-milliseconds))
  (define total-wall-ms (inexact->exact (round (- t1-total t0-total))))
  (define total-tests (apply + (map (λ (r) (hash-ref r 'tests)) results)))
  (define all-pass? (andmap (λ (r) (string=? (hash-ref r 'status) "pass")) results))

  ;; Build run record
  (define record
    (hasheq 'timestamp (current-iso-timestamp)
            'commit (current-commit)
            'branch (current-branch)
            'machine (string-append (symbol->string (system-type 'os)) "-" (symbol->string (system-type 'arch)))
            'total_wall_ms total-wall-ms
            'total_tests total-tests
            'file_count total
            'all_pass all-pass?
            'results results))

  ;; Append to JSONL file
  (call-with-output-file timings-file #:exists 'append
    (λ (out)
      (write-json record out)
      (newline out)))

  ;; Print summary
  (printf "\n--- Summary ---\n")
  (printf "Total: ~as (~a files, ~a tests, ~a)\n"
          (real->decimal-string (/ total-wall-ms 1000.0) 1)
          total
          total-tests
          (if all-pass? "all pass" "SOME FAILURES"))
  (printf "Results appended to ~a\n" (path->string timings-file))

  ;; Return success status
  all-pass?)

;; ============================================================
;; Reporting
;; ============================================================

(define (read-all-runs)
  (if (file-exists? timings-file)
      (call-with-input-file timings-file
        (λ (in)
          (for/list ([line (in-lines in)]
                     #:when (not (string=? (string-trim line) "")))
            (with-input-from-string line read-json))))
      '()))

(define (report-last)
  (define runs (read-all-runs))
  (when (null? runs)
    (printf "No benchmark data found in ~a\n" (path->string timings-file))
    (exit 0))
  (define last-run (last runs))
  (printf "Last run (~a, ~a ~a):\n"
          (hash-ref last-run 'commit)
          (hash-ref last-run 'branch)
          (hash-ref last-run 'timestamp))
  (printf "  Total: ~as (~a files, ~a tests, ~a)\n\n"
          (real->decimal-string (/ (hash-ref last-run 'total_wall_ms) 1000.0) 1)
          (hash-ref last-run 'file_count)
          (hash-ref last-run 'total_tests)
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
  (define runs (read-all-runs))
  (when (null? runs)
    (printf "No benchmark data found.\n")
    (exit 0))
  (define last-run (last runs))
  (printf "Slowest ~a from last run (~a):\n\n" n (hash-ref last-run 'commit))
  (print-slowest-n (hash-ref last-run 'results) n))

(define (report-compare ref)
  (define target-commit (string-trim (git-output "rev-parse" "--short" ref)))
  (define runs (read-all-runs))
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
;; Helpers
;; ============================================================

(define (current-iso-timestamp)
  (define now (current-seconds))
  (define d (seconds->date now #t))  ; UTC
  (format "~a-~a-~aT~a:~a:~aZ"
          (date-year d)
          (pad-num (date-month d) 2)
          (pad-num (date-day d) 2)
          (pad-num (date-hour d) 2)
          (pad-num (date-minute d) 2)
          (pad-num (date-second d) 2)))

(define (pad-num n width)
  (define s (number->string n))
  (define padding (max 0 (- width (string-length s))))
  (string-append (make-string padding #\0) s))

(define (pad-str val min-width [align 'left] [pad-char #\space])
  (define s (format "~a" val))
  (define padding (max 0 (- min-width (string-length s))))
  (cond
    [(zero? padding) s]
    [(eq? align 'right) (string-append (make-string padding pad-char) s)]
    [else (string-append s (make-string padding pad-char))]))

;; ============================================================
;; CLI
;; ============================================================

(define mode (make-parameter 'run))
(define file-list (make-parameter '()))
(define slowest-n (make-parameter 10))
(define compare-ref (make-parameter #f))
(define timeout-secs (make-parameter 600))

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
   #:once-each
   ["--timeout" secs "Per-test timeout in seconds (default: 600)"
    (timeout-secs (string->number secs))]
   #:multi
   ["--files" file "Benchmark specific test file(s)"
    (file-list (cons (string->symbol file) (file-list)))])

  (case (mode)
    [(report) (report-last)]
    [(compare) (report-compare (compare-ref))]
    [(slowest) (report-slowest (slowest-n))]
    [(run)
     (define test-names
       (if (null? (file-list))
           (sort (all-test-files) symbol<?)
           (reverse (file-list))))
     (define ok? (run-benchmark test-names (timeout-secs)))
     (unless ok? (exit 1))]))

(main)
