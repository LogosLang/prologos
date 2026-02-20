#lang racket/base

;; bench-lib.rkt — Shared benchmarking utilities
;;
;; Used by both benchmark-tests.rkt and run-affected-tests.rkt to avoid
;; duplication of per-file subprocess timing, JSONL recording, and helpers.

(require racket/port
         racket/string
         racket/system
         racket/path
         json
         racket/date)

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
         append-run-record)

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
