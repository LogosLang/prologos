#lang racket/base

;;; Unit tests for the Racket-on-propagators EigenTrust implementation
;;; (benchmarks/comparative/eigentrust-propagators.rkt).
;;;
;;; Verifies that the propagator-based implementation produces the
;;; SAME results as the four Prologos surface variants (List+Rat,
;;; List+Posit32, PVec+Rat, PVec+Posit32) on the same fixtures. The
;;; column-stochastic invariant check, ring-4 slow-settling
;;; trajectory, and uniform fixed-point are all asserted with exact
;;; rational equality (the Racket version uses Racket's exact
;;; rationals, equivalent to the Prologos List+Rat variant).

(require rackunit
         "../benchmarks/comparative/eigentrust-propagators.rkt")

;; ============================================================
;; Column-stochastic invariant
;; ============================================================

(test-case "col-stochastic? on uniform 4x4"
  (check-true (col-stochastic? m-uniform-4)))

(test-case "col-stochastic? on symmetric 3x3"
  (check-true (col-stochastic? m-others-3)))

(test-case "col-stochastic? on ring 4"
  (check-true (col-stochastic? m-ring-4)))

(test-case "col-stochastic? rejects bad matrix"
  (define m-bad (vector (vector 1/2 1/2)
                        (vector 1/2  0)))   ;; col 1 sums to 1/2
  (check-false (col-stochastic? m-bad)))

;; ============================================================
;; Off-network kernel: eigentrust-step
;; ============================================================

(test-case "eigentrust-step on uniform 4x4 is fixed point"
  (define t (vector 1/4 1/4 1/4 1/4))
  (check-equal? (eigentrust-step m-uniform-4 p-uniform-4 1/10 t) t))

(test-case "eigentrust-step on symmetric 3x3 with uniform"
  (define t (vector 1/3 1/3 1/3))
  (check-equal? (eigentrust-step m-others-3 p-uniform-3 1/10 t) t))

(test-case "eigentrust-step on ring with concentrated pre-trust"
  ;; t0 = p = [1, 0, 0, 0], M*t0 = [0, 1, 0, 0]
  ;; step = 7/10 * [0, 1, 0, 0] + 3/10 * [1, 0, 0, 0]
  ;;      = [3/10, 7/10, 0, 0]
  (check-equal? (eigentrust-step m-ring-4 p-seed-0 3/10 p-seed-0)
                (vector 3/10 7/10 0 0)))

;; ============================================================
;; End-to-end via the propagator network
;; ============================================================

(test-case "run-eigentrust-propagators: uniform converges to itself (k=2)"
  (define result (run-eigentrust-propagators m-uniform-4 p-uniform-4 1/10 2))
  (check-equal? result p-uniform-4))

(test-case "run-eigentrust-propagators: symmetric converges to uniform (k=2)"
  (define result (run-eigentrust-propagators m-others-3 p-uniform-3 1/10 2))
  (check-equal? result p-uniform-3))

(test-case "run-eigentrust-propagators: ring slow settling (k=4 = W3 fixture)"
  ;; This is the W3 benchmark workload, identical to the four Prologos
  ;; surface variants' W3 result.
  ;; Hand calc:
  ;;   t0 = [1, 0, 0, 0]
  ;;   step-1 = [3/10, 7/10, 0, 0]
  ;;   step-2 = [3/10, 21/100, 49/100, 0]
  ;;   step-3 = [3/10, 21/100, 147/1000, 343/1000]
  ;;   step-4 = [5401/10000, 21/100, 147/1000, 1029/10000]
  (define result (run-eigentrust-propagators m-ring-4 p-seed-0 3/10 4))
  (check-equal? result
                (vector 5401/10000 21/100 147/1000 1029/10000)))

(test-case "run-eigentrust-propagators: panics on non-column-stochastic"
  (define m-bad (vector (vector 1/2 1/2)
                        (vector 1/2  0)))
  (check-exn exn:fail? (lambda ()
                         (run-eigentrust-propagators m-bad
                                                    (vector 1/2 1/2)
                                                    1/10
                                                    1))))

;; ============================================================
;; Mass preservation across iterations (the result must remain a
;; probability distribution: sum = 1).
;; ============================================================

(test-case "ring-4 mass preservation across k=4"
  (define result (run-eigentrust-propagators m-ring-4 p-seed-0 3/10 4))
  (define total (for/sum ([x (in-vector result)]) x))
  (check-equal? total 1))

(test-case "symmetric-3 mass preservation across k=10"
  (define result (run-eigentrust-propagators m-others-3 p-uniform-3 1/10 10))
  (define total (for/sum ([x (in-vector result)]) x))
  (check-equal? total 1))
