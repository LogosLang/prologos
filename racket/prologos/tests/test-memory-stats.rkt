#lang racket/base

;;; test-memory-stats.rkt — DEFERRED 152: the per-call MEMORY-STATS measurement
;;; (`measure-memory-before` / `-after`, performance-counters.rkt) forces two
;;; MAJOR collections. It must run only when a MEMORY-STATS consumer opted in —
;;; `current-memory-stats?` or the PROLOGOS_MEMORY_STATS environment variable —
;;; never as a side effect of a library call (process-string / process-string-ws
;;; / process-file, i.e. every test `run`, every LSP re-elaboration, every
;;; `racket driver.rkt FILE`).
;;;
;;; When not measuring, MEMORY-STATS is OMITTED (no line), not printed with
;;; unforced numbers: without the forced GC the fields mean something else
;;; (retained bytes include garbage), and a consumer that stores the last line
;;; (batch-worker's `memory` field) would mix the two meanings in one history.
;;; All three consumers already treat a missing line as "no memory record".
;;;
;;; Every pin runs in a COPY of the environment with the variable set or
;;; removed, so the file is green whether or not a runner opted the suite in.

(require rackunit
         racket/port
         racket/string
         racket/file
         json
         "../performance-counters.rkt"
         "../driver.rkt")

;; Run thunk with PROLOGOS_MEMORY_STATS set to val (#f = unset) in a private
;; copy of the environment.
(define (call-with-memory-env val thunk)
  (define env (environment-variables-copy (current-environment-variables)))
  (environment-variables-set! env #"PROLOGOS_MEMORY_STATS"
                              (and val (string->bytes/utf-8 val)))
  (parameterize ([current-environment-variables env])
    (thunk)))

;; Count MAJOR collections during thunk (GC log topic, gc-info mode field).
;; Returns (values stderr-text majors).
(define (stderr+majors thunk)
  (define r (make-log-receiver (current-logger) 'debug 'GC))
  (define err (open-output-string))
  (parameterize ([current-error-port err])
    (thunk))
  (define majors
    (let loop ([n 0])
      (define v (sync/timeout 0 r))
      (cond
        [(not v) n]
        [else
         (define d (vector-ref v 2))
         (loop (if (and (struct? d)
                        (eq? (vector-ref (struct->vector d) 1) 'major))
                   (add1 n)
                   n))])))
  (values (get-output-string err) majors))

(define (memory-lines s)
  (filter (λ (l) (string-prefix? l "MEMORY-STATS:")) (string-split s "\n")))

(define (memory-json line)
  (with-input-from-string (substring line (string-length "MEMORY-STATS:")) read-json))

(define N 5)
(define (five-calls) (for ([i N]) (process-string "(def x : Nat 0N)")))

;; ============================================================
;; Unit level: the measurement pair
;; ============================================================

(test-case "memory-stats: off by default — before/after return #f, report prints nothing"
  (call-with-memory-env #f
    (λ ()
      (check-false (current-memory-stats?))
      (check-false (memory-stats-enabled?))
      (define-values (err majors)
        (stderr+majors
         (λ () (print-memory-report! (measure-memory-after (measure-memory-before))))))
      (check-false (measure-memory-before))
      (check-false (measure-memory-after #f))
      (check-equal? err "")
      (check-equal? majors 0 "a disabled measurement must not collect"))))

(test-case "memory-stats: parameter opt-in measures with forced majors and the old record shape"
  (call-with-memory-env #f
    (λ ()
      (parameterize ([current-memory-stats? #t])
        (check-true (memory-stats-enabled?))
        (define-values (err majors)
          (stderr+majors
           (λ () (print-memory-report! (measure-memory-after (measure-memory-before))))))
        (check-equal? majors 2 "before + after each force one major GC")
        (define ls (memory-lines err))
        (check-equal? (length ls) 1)
        (define h (memory-json (car ls)))
        (check-equal? (sort (map symbol->string (hash-keys h)) string<?)
                      '("gc_ms" "mem_after_bytes" "mem_before_bytes" "mem_retained_bytes"))))))

(test-case "memory-stats: env var opt-in (PROLOGOS_MEMORY_STATS), \"0\" and \"\" mean off"
  (call-with-memory-env "1" (λ () (check-true (memory-stats-enabled?))))
  (call-with-memory-env "yes" (λ () (check-true (memory-stats-enabled?))))
  (call-with-memory-env "0" (λ () (check-false (memory-stats-enabled?))))
  (call-with-memory-env "" (λ () (check-false (memory-stats-enabled?)))))

;; ============================================================
;; Driver level: the library calls that used to force the GCs
;; ============================================================

(test-case "memory-stats: process-string ×5 without opt-in — no MEMORY-STATS, no forced majors"
  (call-with-memory-env #f
    (λ ()
      (define-values (err majors) (stderr+majors five-calls))
      (check-equal? (memory-lines err) '())
      ;; Before the fix: exactly 2 forced majors per call (10). A tiny call
      ;; allocates far less than a major-GC trigger, so natural majors stay
      ;; well under N.
      (check-true (< majors N) (format "~a major GCs in ~a tiny calls" majors N))
      ;; the other per-call reports are unaffected
      (check-true (string-contains? err "PHASE-TIMINGS:")))))

(test-case "memory-stats: process-string ×5 with env opt-in — one record per call, 2 majors each"
  (call-with-memory-env "1"
    (λ ()
      (define-values (err majors) (stderr+majors five-calls))
      (check-equal? (length (memory-lines err)) N)
      (check-true (>= majors (* 2 N)) (format "~a major GCs" majors)))))

(test-case "memory-stats: process-string-ws and process-file honour the gate (Level 3)"
  (define tmp (make-temporary-file "mem152-~a.rkt"))
  (with-output-to-file tmp #:exists 'truncate (λ () (display "(def x : Nat 0N)\n")))
  (define (both) (process-string-ws "def x : Nat := 0N") (process-file tmp))
  (call-with-memory-env #f
    (λ ()
      (define-values (err majors) (stderr+majors both))
      (check-equal? (memory-lines err) '())
      (check-true (< majors 2) (format "~a major GCs" majors))))
  (call-with-memory-env #f
    (λ ()
      (parameterize ([current-memory-stats? #t])
        (define-values (err majors) (stderr+majors both))
        (check-equal? (length (memory-lines err)) 2)
        (check-true (>= majors 4) (format "~a major GCs" majors)))))
  (delete-file tmp))
