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
         racket/date)

(provide benchmark-one-test
         extract-test-count
         extract-perf-counters
         extract-phase-timings
         extract-memory-stats
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
         precompile-modules!)

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
     (define err-output (port->string stderr-port))
     (close-input-port stdout-port)
     (close-input-port stderr-port)
     (define ok? (zero? (subprocess-status proc)))
     (define test-count (extract-test-count output))
     (define heartbeats (extract-perf-counters err-output))
     (define phases (extract-phase-timings err-output))
     (define mem (extract-memory-stats err-output))
     (define result
       (hasheq 'file (filename-from-path test-path)
               'wall_ms wall-ms
               'status (if ok? "pass" "fail")
               'tests test-count))
     ;; Attach heartbeats, phase timings, and memory stats when available
     (define result+hb
       (if heartbeats (hash-set result 'heartbeats heartbeats) result))
     (define result+ph
       (if phases (hash-set result+hb 'phases phases) result+hb))
     (define result+mem
       (if mem (hash-set result+ph 'memory mem) result+ph))
     ;; Attach error output only on failure (saves space in JSONL)
     (if (and (not ok?) (not (string=? err-output "")))
         (hash-set result+mem 'error_output err-output)
         result+mem)]
    [else
     ;; Timeout — kill the process
     (define err-output
       (with-handlers ([exn:fail? (λ (_) "")])
         (port->string stderr-port)))
     (subprocess-kill proc #t)
     (close-input-port stdout-port)
     (close-input-port stderr-port)
     (define result
       (hasheq 'file (filename-from-path test-path)
               'wall_ms wall-ms
               'status "timeout"
               'tests 0))
     (if (not (string=? err-output ""))
         (hash-set result 'error_output err-output)
         result)]))

;; Extract PERF-COUNTERS:{json} from stderr output.
;; Returns a hasheq of counter values, or #f if no heartbeat line found.
;; Multiple PERF-COUNTERS lines are merged (summed) — handles multi-ns files.
(define (extract-perf-counters err-output)
  (define lines (string-split err-output "\n"))
  (define prefix "PERF-COUNTERS:")
  (define prefix-len (string-length prefix))
  (define results
    (for/list ([line (in-list lines)]
               #:when (and (>= (string-length line) prefix-len)
                           (string=? (substring line 0 prefix-len) prefix)))
      (with-handlers ([exn:fail? (λ (_) #f)])
        (with-input-from-string (substring line prefix-len) read-json))))
  (define valid (filter hash? results))
  (cond
    [(null? valid) #f]
    [(= (length valid) 1) (car valid)]
    [else
     ;; Sum all counter hashes (multi-ns files emit multiple reports)
     (for/fold ([acc (car valid)])
               ([h (in-list (cdr valid))])
       (for/fold ([a acc])
                 ([(k v) (in-hash h)])
         (hash-set a k (+ (hash-ref a k 0) v))))]))

;; Extract PHASE-TIMINGS:{json} from stderr output.
;; Same extraction pattern as perf-counters, with additive merge for multi-ns.
(define (extract-phase-timings err-output)
  (define lines (string-split err-output "\n"))
  (define prefix "PHASE-TIMINGS:")
  (define prefix-len (string-length prefix))
  (define results
    (for/list ([line (in-list lines)]
               #:when (and (>= (string-length line) prefix-len)
                           (string=? (substring line 0 prefix-len) prefix)))
      (with-handlers ([exn:fail? (λ (_) #f)])
        (with-input-from-string (substring line prefix-len) read-json))))
  (define valid (filter hash? results))
  (cond
    [(null? valid) #f]
    [(= (length valid) 1) (car valid)]
    [else
     ;; Sum all timing hashes (multi-ns files emit multiple reports)
     (for/fold ([acc (car valid)])
               ([h (in-list (cdr valid))])
       (for/fold ([a acc])
                 ([(k v) (in-hash h)])
         (hash-set a k (+ (hash-ref a k 0) v))))]))

;; Extract MEMORY-STATS:{json} from stderr output.
;; Returns a hasheq of memory stats, or #f if not found.
;; For multi-ns files, takes the last (final) report.
(define (extract-memory-stats err-output)
  (define lines (string-split err-output "\n"))
  (define prefix "MEMORY-STATS:")
  (define prefix-len (string-length prefix))
  (define results
    (for/list ([line (in-list lines)]
               #:when (and (>= (string-length line) prefix-len)
                           (string=? (substring line 0 prefix-len) prefix)))
      (with-handlers ([exn:fail? (λ (_) #f)])
        (with-input-from-string (substring line prefix-len) read-json))))
  (define valid (filter hash? results))
  (if (null? valid) #f (last valid)))  ;; take last report (cumulative)

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
;; Bytecode pre-compilation
;; ============================================================

;; Pre-compile all Prologos modules to .zo bytecode via `raco make`.
;; This reduces per-subprocess preamble overhead from ~22s to ~1s.
;; Returns #t on success.
(define (precompile-modules! project-root)
  (define driver-path (path->string (build-path project-root "driver.rkt")))
  (define raco-path (find-executable-path "raco"))
  (define-values (proc out in err)
    (subprocess #f #f #f raco-path "make" driver-path))
  (close-output-port in)
  (subprocess-wait proc)
  (close-input-port out)
  (close-input-port err)
  (zero? (subprocess-status proc)))

