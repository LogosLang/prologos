#lang racket/base

;; bench-lib.rkt — Shared benchmarking utilities
;;
;; Used by both benchmark-tests.rkt and run-affected-tests.rkt to avoid
;; duplication of per-file subprocess timing, JSONL recording, and helpers.

(require racket/port
         racket/string
         racket/system
         racket/path
         racket/list
         json
         racket/date
         "test-splitter.rkt")

(provide benchmark-one-test
         extract-test-count
         filename-from-path
         status-label
         current-iso-timestamp
         pad-num
         pad-str
         git-output
         current-commit
         current-branch
         make-timings-path
         read-all-runs
         append-run-record
         ;; Per-test splitting
         (struct-out work-item)
         split-threshold-ms
         split-min-per-test-ms
         split-min-test-count
         prepare-work-items
         aggregate-split-results)

;; ============================================================
;; Benchmark one test file via subprocess
;; ============================================================

(define (benchmark-one-test test-path timeout-secs)
  (define t0 (current-inexact-monotonic-milliseconds))
  (define raco-path (find-executable-path "raco"))
  (define-values (proc stdout-port stdin-port stderr-port)
    (subprocess #f #f #f raco-path "test" test-path))
  (close-output-port stdin-port)
  ;; Wait with event-based timeout (no polling)
  (define completed? (sync/timeout timeout-secs proc))
  (define t1 (current-inexact-monotonic-milliseconds))
  (define wall-ms (inexact->exact (round (- t1 t0))))
  (cond
    [completed?
     ;; Process finished
     (define output (port->string stdout-port))
     (close-input-port stdout-port)
     (close-input-port stderr-port)
     (define ok? (zero? (subprocess-status proc)))
     (define test-count (extract-test-count output))
     (hasheq 'file (filename-from-path test-path)
             'wall_ms wall-ms
             'status (if ok? "pass" "fail")
             'tests test-count)]
    [else
     ;; Timeout — kill the process
     (subprocess-kill proc #t)
     (close-input-port stdout-port)
     (close-input-port stderr-port)
     (hasheq 'file (filename-from-path test-path)
             'wall_ms wall-ms
             'status "timeout"
             'tests 0)]))

;; Extract "N tests passed" from raco test output
(define (extract-test-count output)
  (define lines (string-split output "\n"))
  (for/fold ([count 0]) ([line (in-list lines)])
    (cond
      [(regexp-match #rx"([0-9]+) tests? passed" line)
       => (λ (m) (string->number (cadr m)))]
      [else count])))

(define (filename-from-path test-path)
  (path->string (file-name-from-path (string->path test-path))))

(define (status-label s)
  (cond [(string=? s "pass") "PASS"]
        [(string=? s "fail") "FAIL"]
        [else "TIMEOUT"]))

;; ============================================================
;; Git metadata
;; ============================================================

(define (git-output . args)
  (define cmd (string-join (cons "git" args) " "))
  (string-trim (with-output-to-string (λ () (system cmd)))))

(define (current-commit) (git-output "rev-parse" "--short" "HEAD"))
(define (current-branch) (git-output "rev-parse" "--abbrev-ref" "HEAD"))

;; ============================================================
;; Timings file path + JSONL I/O
;; ============================================================

;; Build path to timings.jsonl from a project root directory
(define (make-timings-path project-root)
  (build-path project-root "data" "benchmarks" "timings.jsonl"))

;; Read all JSON run records from a timings file
(define (read-all-runs timings-file)
  (if (file-exists? timings-file)
      (call-with-input-file timings-file
        (λ (in)
          (for/list ([line (in-lines in)]
                     #:when (not (string=? (string-trim line) "")))
            (with-input-from-string line read-json))))
      '()))

;; Append one run record to a timings file
(define (append-run-record timings-file record)
  (call-with-output-file timings-file #:exists 'append
    (λ (out)
      (write-json record out)
      (newline out))))

;; ============================================================
;; Formatting helpers
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
;; Per-test splitting for CPU saturation
;; ============================================================

;; A work-item represents one unit of work for the thread pool.
;; kind: 'whole (run entire file) or 'split (run single test-case temp file)
;; path: the file to run (original for whole, temp file for split)
;; original-file: original test filename (same as filename-from-path for whole)
;; test-name: #f for whole, string for split
(struct work-item (path original-file test-name kind) #:transparent)

;; Default threshold: only split files historically slower than 60s
(define split-threshold-ms (make-parameter 60000))

;; Minimum per-test time (ms) to justify splitting.
;; If a file's per-test time (wall_ms / tests) is below this, the subprocess
;; preamble overhead dominates and splitting would be counterproductive.
;; Set to ~20s based on observed preamble compilation time.
(define split-min-per-test-ms (make-parameter 10000))

;; Minimum number of test-cases in a file to consider splitting.
;; Files with fewer tests are run monolithically even if they exceed the time
;; thresholds. Prevents splitting files where the small number of tests cannot
;; overcome preamble overhead through parallelism.
(define split-min-test-count (make-parameter 10))

;; prepare-work-items : (listof string) string -> (values (listof work-item) (-> void))
;; Takes test paths and project root, returns a flat list of work items
;; plus a cleanup thunk that removes any generated temp files.
;;
;; Splitting criteria: a file is split when ALL of:
;;   1. split-threshold-ms > 0 (splitting not disabled)
;;   2. Historical wall_ms > split-threshold-ms (file is slow overall)
;;   3. Historical per-test time > split-min-per-test-ms (each test is slow enough
;;      that subprocess preamble overhead doesn't dominate)
;;   4. Historical test count >= split-min-test-count (enough tests for
;;      parallelism to overcome per-subprocess preamble overhead)
(define (prepare-work-items test-paths project-root)
  (define threshold (split-threshold-ms))
  (define min-per-test (split-min-per-test-ms))
  (define min-tests (split-min-test-count))
  (define historical (load-historical-times project-root))
  (define all-split-infos '())

  (define items
    (apply append
      (for/list ([tp (in-list test-paths)])
        (define fname (filename-from-path tp))
        (define hist (hash-ref historical fname #f))
        (define hist-ms (and hist (car hist)))
        (define hist-tests (and hist (cdr hist)))
        (define per-test-ms
          (and hist-ms hist-tests (> hist-tests 0)
               (/ hist-ms hist-tests)))
        (cond
          ;; Split if file is slow overall AND each test is slow enough
          ;; AND the file has enough tests for parallelism to help
          [(and (> threshold 0)
                hist-ms (> hist-ms threshold)
                per-test-ms (> per-test-ms min-per-test)
                hist-tests (>= hist-tests min-tests))
           (define infos (split-test-file tp))
           (set! all-split-infos (append all-split-infos infos))
           (for/list ([info (in-list infos)])
             (work-item (split-info-temp-path info)
                        fname
                        (split-info-test-name info)
                        'split))]
          ;; No split: run as whole file
          [else
           (list (work-item tp fname #f 'whole))]))))

  (define (cleanup!)
    (cleanup-split-files all-split-infos))

  (values items cleanup!))

;; Load per-file timings from the most recent full-suite run in timings.jsonl.
;; Uses the run with the highest file_count to avoid being misled by partial runs.
;; Returns hash: filename -> (cons wall_ms test-count)
(define (load-historical-times project-root)
  (define timings-file (make-timings-path project-root))
  (define runs (read-all-runs timings-file))
  (cond
    [(null? runs) (hash)]
    [else
     ;; Find the max file_count across all runs
     (define max-fc
       (apply max (map (λ (r) (hash-ref r 'file_count 0)) runs)))
     ;; Pick the most recent run with that file count
     (define full-runs
       (filter (λ (r) (= (hash-ref r 'file_count 0) max-fc)) runs))
     (define best-run (last full-runs))
     (define results (hash-ref best-run 'results '()))
     (for/hash ([r (in-list results)])
       (values (hash-ref r 'file)
               (cons (hash-ref r 'wall_ms)
                     (hash-ref r 'tests 0))))]))

;; aggregate-split-results : (listof hasheq) (listof work-item) -> (listof hasheq)
;; Groups raw benchmark results back to per-file records.
;; Whole-file results pass through unchanged.
;; Split results are aggregated into a single file-level record with test_details.
(define (aggregate-split-results raw-results work-items)
  ;; Build a map from temp-file path to work-item for quick lookup
  (define wi-by-path
    (for/hash ([wi (in-list work-items)])
      (values (work-item-path wi) wi)))

  ;; Tag each raw result with its work-item info
  (define tagged
    (for/list ([r (in-list raw-results)])
      ;; Find the work-item by matching the file field back to the work-item
      ;; The 'file field from benchmark-one-test is the temp filename for splits
      (define result-file (hash-ref r 'file))
      ;; Search work-items for one whose path ends with this filename
      (define wi
        (for/first ([w (in-list work-items)]
                    #:when (string=? (filename-from-path (work-item-path w))
                                     result-file))
          w))
      (cons (or wi (work-item "" result-file #f 'whole)) r)))

  ;; Group by original-file
  (define groups (make-hash))
  (for ([pair (in-list tagged)])
    (define wi (car pair))
    (define r (cdr pair))
    (define key (work-item-original-file wi))
    (hash-update! groups key (λ (acc) (cons (cons wi r) acc)) '()))

  ;; Build aggregated results
  (for/list ([(orig-file entries) (in-hash groups)])
    (define kind (work-item-kind (car (car entries))))
    (cond
      [(eq? kind 'whole)
       ;; Single whole-file result — pass through
       (cdr (car entries))]
      [else
       ;; Split results — aggregate
       (define total-ms
         (apply + (map (λ (e) (hash-ref (cdr e) 'wall_ms)) entries)))
       (define total-tests
         (apply + (map (λ (e) (hash-ref (cdr e) 'tests)) entries)))
       (define statuses (map (λ (e) (hash-ref (cdr e) 'status)) entries))
       (define agg-status
         (cond
           [(member "timeout" statuses) "timeout"]
           [(member "fail" statuses) "fail"]
           [else "pass"]))
       (define test-details
         (for/list ([e (in-list entries)])
           (define wi (car e))
           (define r (cdr e))
           (hasheq 'name (or (work-item-test-name wi) "unknown")
                   'wall_ms (hash-ref r 'wall_ms)
                   'status (hash-ref r 'status))))
       (hasheq 'file orig-file
               'wall_ms total-ms
               'status agg-status
               'tests total-tests
               'split #t
               'test_details test-details)])))

