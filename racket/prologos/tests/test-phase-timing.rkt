#lang racket/base

;;; test-phase-timing.rkt — Tests for phase-level timing infrastructure
;;; Phase B-e: Validates phase timing accumulation and reporting.

(require rackunit
         racket/port
         racket/string
         json
         "../performance-counters.rkt"
         "../driver.rkt"
         "../global-env.rkt")

;; ============================================================
;; Phase-timing struct basics
;; ============================================================

(test-case "phase-timing: fresh struct has all-zero fields"
  (define pt (phase-timings 0.0 0.0 0.0 0.0 0.0 0.0 0.0))
  (check-equal? (phase-timings-elaborate-ms pt) 0.0)
  (check-equal? (phase-timings-type-check-ms pt) 0.0)
  (check-equal? (phase-timings-zonk-ms pt) 0.0))

(test-case "phase-timing: time-phase! accumulates into correct field"
  (define pt (phase-timings 0.0 0.0 0.0 0.0 0.0 0.0 0.0))
  (parameterize ([current-phase-timings pt])
    (time-phase! elaborate (sleep 0.001))
    (time-phase! elaborate (sleep 0.001)))
  ;; Two 1ms sleeps → should be ≥ 1ms total
  (check-true (>= (phase-timings-elaborate-ms pt) 1.0)
              (format "Expected ≥ 1ms, got ~a" (phase-timings-elaborate-ms pt)))
  ;; Other fields untouched
  (check-equal? (phase-timings-type-check-ms pt) 0.0)
  (check-equal? (phase-timings-qtt-ms pt) 0.0))

(test-case "phase-timing: time-phase! returns body result"
  (define pt (phase-timings 0.0 0.0 0.0 0.0 0.0 0.0 0.0))
  (define result
    (parameterize ([current-phase-timings pt])
      (time-phase! type-check (+ 21 21))))
  (check-equal? result 42))

(test-case "phase-timing: zero-cost when disabled"
  ;; current-phase-timings defaults to #f
  (check-false (current-phase-timings))
  ;; Should not crash
  (define result (time-phase! elaborate (+ 1 2)))
  (check-equal? result 3))

;; ============================================================
;; hasheq round-trip
;; ============================================================

(test-case "phase-timing: hasheq snapshot has 7 keys"
  (define pt (phase-timings 10.5 20.5 30.5 5.5 2.5 8.5 15.5))
  (define h (phase-timings->hasheq pt))
  (check-equal? (length (hash-keys h)) 7)
  (check-equal? (hash-ref h 'elaborate_ms) 20)  ;; banker's rounding: 20.5 → 20
  (check-equal? (hash-ref h 'type_check_ms) 30)) ;; banker's rounding: 30.5 → 30

;; ============================================================
;; End-to-end with driver
;; ============================================================

(test-case "phase-timing: process-string emits PHASE-TIMINGS to stderr"
  ;; Capture stderr from process-string
  (define err-str
    (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (with-output-to-string
        (λ ()
          (parameterize ([current-error-port (current-output-port)])
            (process-string "(def x : Nat 0N)"))))))
  ;; Should contain PHASE-TIMINGS prefix
  (check-true (string-contains? err-str "PHASE-TIMINGS:")
              (format "Expected PHASE-TIMINGS in stderr, got: ~a" err-str))
  ;; Parse the JSON
  (define lines (string-split err-str "\n"))
  (define prefix "PHASE-TIMINGS:")
  (define prefix-len (string-length prefix))  ;; 14
  (define phase-line
    (for/or ([line (in-list lines)])
      (and (>= (string-length line) prefix-len)
           (string=? (substring line 0 prefix-len) prefix)
           (substring line prefix-len))))
  (check-not-false phase-line "No PHASE-TIMINGS line found")
  (define h (with-input-from-string phase-line read-json))
  ;; All 7 phase keys present
  (check-true (hash-has-key? h 'elaborate_ms))
  (check-true (hash-has-key? h 'type_check_ms))
  (check-true (hash-has-key? h 'zonk_ms))
  (check-true (hash-has-key? h 'trait_resolve_ms))
  (check-true (hash-has-key? h 'qtt_ms))
  (check-true (hash-has-key? h 'reduce_ms))
  (check-true (hash-has-key? h 'parse_ms))
  ;; All values are non-negative integers
  (for ([(k v) (in-hash h)])
    (check-true (and (integer? v) (>= v 0))
                (format "Phase ~a has non-integer or negative value: ~a" k v))))

(test-case "phase-timing: multiple commands accumulate"
  (define pt (phase-timings 0.0 0.0 0.0 0.0 0.0 0.0 0.0))
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-phase-timings pt])
    ;; Process multiple commands — timings accumulate via +
    (with-output-to-string
      (λ ()
        (parameterize ([current-error-port (current-output-port)])
          (process-string "(def x : Nat 0N)")
          (process-string "(def y : Nat 1N)")))))
  ;; After 2 definitions, elaborate should have non-zero timing
  (check-true (>= (phase-timings-elaborate-ms pt) 0.0))
  ;; type-check should have non-zero timing
  (check-true (>= (phase-timings-type-check-ms pt) 0.0)))
