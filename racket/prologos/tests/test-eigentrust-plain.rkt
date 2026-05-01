#lang racket/base

;;; Tests for the plain (non-propagator) Racket EigenTrust
;;; implementations (`benchmarks/comparative/eigentrust-plain.rkt`).
;;; They use the same off-network kernel as the propagator variants;
;;; we just verify the plain orchestration produces the same result.

(require rackunit
         racket/flonum
         "../benchmarks/comparative/eigentrust-plain.rkt"
         "../benchmarks/comparative/eigentrust-propagators.rkt"
         "../benchmarks/comparative/eigentrust-propagators-float.rkt")

(define TOL 1e-9)

(define (flv-close? a b [tol TOL])
  (and (= (flvector-length a) (flvector-length b))
       (for/and ([x (in-flvector a)] [y (in-flvector b)])
         (< (abs (- x y)) tol))))

;; ============================================================
;; Plain rational
;; ============================================================

(test-case "plain rat ring-4 k=4 matches golden"
  (define result (run-eigentrust-plain m-ring-4 p-seed-0 3/10 4))
  (check-equal? result
                (vector 5401/10000 21/100 147/1000 1029/10000)))

(test-case "plain rat uniform-4 stays uniform"
  (check-equal? (run-eigentrust-plain m-uniform-4 p-uniform-4 1/10 2)
                p-uniform-4))

(test-case "plain rat symmetric-3 stays uniform"
  (check-equal? (run-eigentrust-plain m-others-3 p-uniform-3 1/10 2)
                p-uniform-3))

;; Plain and propagator variants must agree exactly on rats.
(test-case "plain rat == propagator rat-coarse on ring k=1..6"
  (for ([k (in-range 1 7)])
    (check-equal? (run-eigentrust-plain m-ring-4 p-seed-0 3/10 k)
                  (run-eigentrust-propagators m-ring-4 p-seed-0 3/10 k)
                  (format "k=~a" k))))

(test-case "plain rat panics on non-column-stochastic"
  (define m-bad (vector (vector 1/2 1/2) (vector 1/2 0)))
  (check-exn exn:fail?
             (lambda ()
               (run-eigentrust-plain m-bad (vector 1/2 1/2) 1/10 1))))

;; ============================================================
;; Plain float
;; ============================================================

(test-case "plain float ring-4 k=4 matches golden within tol"
  (define result (run-eigentrust-plain-fl m-ring-4-fl p-seed-0-fl 0.3 4))
  (define expected (flvector 0.5401 0.21 0.147 0.1029))
  (check-true (flv-close? result expected)))

(test-case "plain float uniform-4 stays uniform"
  (check-true (flv-close?
               (run-eigentrust-plain-fl m-uniform-4-fl p-uniform-4-fl 0.1 2)
               p-uniform-4-fl)))

(test-case "plain float symmetric-3 stays uniform"
  (check-true (flv-close?
               (run-eigentrust-plain-fl m-others-3-fl p-uniform-3-fl 0.1 2)
               p-uniform-3-fl)))

(test-case "plain float == propagator float on ring k=1..6 (within tol)"
  (for ([k (in-range 1 7)])
    (check-true (flv-close?
                 (run-eigentrust-plain-fl m-ring-4-fl p-seed-0-fl 0.3 k)
                 (run-eigentrust-propagators-fl m-ring-4-fl p-seed-0-fl 0.3 k))
                (format "k=~a" k))))
