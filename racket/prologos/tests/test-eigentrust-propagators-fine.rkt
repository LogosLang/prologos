#lang racket/base

;;; Tests for the fine-grained per-peer variant of EigenTrust
;;; (benchmarks/comparative/eigentrust-propagators-fine.rkt).
;;;
;;; The fine variant returns the SAME exact-rational result as the
;;; coarse variant; we check exact equality.

(require rackunit
         "../benchmarks/comparative/eigentrust-propagators-fine.rkt"
         "../benchmarks/comparative/eigentrust-propagators.rkt")

;; End-to-end golden equality with the coarse variant.
(test-case "fine ring-4 k=4 matches coarse golden"
  (define result (run-eigentrust-propagators-fine m-ring-4 p-seed-0 3/10 4))
  (check-equal? result
                (vector 5401/10000 21/100 147/1000 1029/10000)))

(test-case "fine uniform-4 k=2 stays uniform"
  (define result (run-eigentrust-propagators-fine m-uniform-4 p-uniform-4 1/10 2))
  (check-equal? result p-uniform-4))

(test-case "fine symmetric-3 k=2 stays uniform"
  (define result (run-eigentrust-propagators-fine m-others-3 p-uniform-3 1/10 2))
  (check-equal? result p-uniform-3))

;; The fine and coarse variants must agree on every fixture.
(test-case "fine == coarse on ring k=1..6"
  (for ([k (in-range 1 7)])
    (define coarse (run-eigentrust-propagators m-ring-4 p-seed-0 3/10 k))
    (define fine   (run-eigentrust-propagators-fine m-ring-4 p-seed-0 3/10 k))
    (check-equal? fine coarse
                  (format "k=~a: fine and coarse should match" k))))

;; Mass preservation.
(test-case "fine ring-4 mass preservation"
  (define result (run-eigentrust-propagators-fine m-ring-4 p-seed-0 3/10 4))
  (define total (for/sum ([x (in-vector result)]) x))
  (check-equal? total 1))

(test-case "fine panics on non-column-stochastic"
  (define m-bad (vector (vector 1/2 1/2) (vector 1/2 0)))
  (check-exn exn:fail?
             (lambda ()
               (run-eigentrust-propagators-fine m-bad (vector 1/2 1/2) 1/10 1))))
