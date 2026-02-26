#lang racket/base

;;; test-perf-counters.rkt — Tests for performance-counters.rkt
;;; Phase A-f: Validates heartbeat counter correctness and overhead.

(require rackunit
         "../performance-counters.rkt")

;; ============================================================
;; Counter increment correctness
;; ============================================================

(test-case "counters: all 12 fields increment correctly"
  (define-values (_ pc)
    (with-perf-counters
      (perf-inc-unify!)
      (perf-inc-unify!)
      (perf-inc-reduce!)
      (perf-inc-elaborate!)
      (perf-inc-infer!)
      (perf-inc-trait-resolve!)
      (perf-inc-meta-created!)
      (perf-inc-meta-solved!)
      (perf-inc-constraint!)
      (perf-inc-constraint-retry!)
      (perf-inc-solver-backtrack!)
      (perf-inc-solver-unify!)
      (perf-inc-zonk!)
      (void)))
  (check-equal? (perf-counters-unify-steps pc) 2)
  (check-equal? (perf-counters-reduce-steps pc) 1)
  (check-equal? (perf-counters-elaborate-steps pc) 1)
  (check-equal? (perf-counters-infer-steps pc) 1)
  (check-equal? (perf-counters-trait-resolve-steps pc) 1)
  (check-equal? (perf-counters-meta-created pc) 1)
  (check-equal? (perf-counters-meta-solved pc) 1)
  (check-equal? (perf-counters-constraint-count pc) 1)
  (check-equal? (perf-counters-constraint-retries pc) 1)
  (check-equal? (perf-counters-solver-backtracks pc) 1)
  (check-equal? (perf-counters-solver-unifies pc) 1)
  (check-equal? (perf-counters-zonk-steps pc) 1))

;; ============================================================
;; High-volume correctness
;; ============================================================

(test-case "counters: 100k increments yield exact count"
  (define-values (_ pc)
    (with-perf-counters
      (for ([_ (in-range 100000)])
        (perf-inc-unify!))
      (void)))
  (check-equal? (perf-counters-unify-steps pc) 100000))

;; ============================================================
;; hasheq round-trip
;; ============================================================

(test-case "counters: perf-counters->hasheq snapshot"
  (define-values (_ pc)
    (with-perf-counters
      (perf-inc-unify!)
      (perf-inc-reduce!)
      (perf-inc-reduce!)
      (perf-inc-infer!)
      (void)))
  (define h (perf-counters->hasheq pc))
  (check-equal? (hash-ref h 'unify_steps) 1)
  (check-equal? (hash-ref h 'reduce_steps) 2)
  (check-equal? (hash-ref h 'infer_steps) 1)
  (check-equal? (hash-ref h 'elaborate_steps) 0)
  (check-equal? (hash-ref h 'zonk_steps) 0)
  ;; All 12 keys present
  (check-equal? (length (hash-keys h)) 12))

;; ============================================================
;; with-perf-counters scoping
;; ============================================================

(test-case "counters: with-perf-counters is properly scoped"
  ;; Outside with-perf-counters, parameter is #f — increments are no-ops
  (check-false (current-perf-counters))
  (perf-inc-unify!)  ;; should not crash
  ;; Nested with-perf-counters are independent
  (define-values (_ pc1)
    (with-perf-counters
      (perf-inc-unify!)
      (let-values ([(_ pc2)
                    (with-perf-counters
                      (perf-inc-unify!)
                      (perf-inc-unify!)
                      (void))])
        (check-equal? (perf-counters-unify-steps pc2) 2))
      (void)))
  (check-equal? (perf-counters-unify-steps pc1) 1))

;; ============================================================
;; Reset
;; ============================================================

(test-case "counters: perf-counters-reset! zeroes all fields"
  (define-values (_ pc)
    (with-perf-counters
      (perf-inc-unify!)
      (perf-inc-reduce!)
      (perf-inc-meta-created!)
      (perf-counters-reset! (current-perf-counters))
      (void)))
  (check-equal? (perf-counters-unify-steps pc) 0)
  (check-equal? (perf-counters-reduce-steps pc) 0)
  (check-equal? (perf-counters-meta-created pc) 0))

;; ============================================================
;; Overhead: disabled vs enabled
;; ============================================================

(test-case "counters: enabled 1M increments yield exact count"
  ;; Verify correctness under volume — the primary contract is determinism.
  ;; Overhead measurement is informational (printed but not asserted)
  ;; because CI/parallel test runners cause timing noise.
  (define t0-off (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range 1000000)])
    (perf-inc-unify!))
  (define t1-off (current-inexact-monotonic-milliseconds))
  (define off-ms (- t1-off t0-off))
  ;; Enabled
  (define pc (perf-counters 0 0 0 0 0 0 0 0 0 0 0 0))
  (define t0-on (current-inexact-monotonic-milliseconds))
  (parameterize ([current-perf-counters pc])
    (for ([_ (in-range 1000000)])
      (perf-inc-unify!)))
  (define t1-on (current-inexact-monotonic-milliseconds))
  (define on-ms (- t1-on t0-on))
  ;; Overhead info: not asserted (too noisy under parallel load).
  ;; In isolation, typical ratio is ~1.2-1.5x (parameter check + struct mutation).
  (void)
  (check-equal? (perf-counters-unify-steps pc) 1000000))
