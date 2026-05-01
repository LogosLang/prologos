#lang racket/base

;;; Tests for the float (flonum) propagator variant of EigenTrust
;;; (benchmarks/comparative/eigentrust-propagators-float.rkt).
;;;
;;; Floats are inexact; tests check approximate equality against the
;;; exact-rational answer rather than `equal?` (see pitfalls doc §3).

(require rackunit
         racket/flonum
         "../benchmarks/comparative/eigentrust-propagators-float.rkt"
         "../benchmarks/comparative/eigentrust-propagators.rkt")

(define TOL 1e-9)

(define (flv-close? a b [tol TOL])
  (and (= (flvector-length a) (flvector-length b))
       (for/and ([x (in-flvector a)] [y (in-flvector b)])
         (< (abs (- x y)) tol))))

(define (rat-vec->flvector v)
  (define n (vector-length v))
  (define out (make-flvector n))
  (for ([i (in-range n)])
    (flvector-set! out i (exact->inexact (vector-ref v i))))
  out)

;; ============================================================
;; Column-stochastic check
;; ============================================================

(test-case "float col-stochastic? on uniform"
  (check-true (col-stochastic-fl? m-uniform-4-fl)))

(test-case "float col-stochastic? on ring"
  (check-true (col-stochastic-fl? m-ring-4-fl)))

(test-case "float col-stochastic? rejects bad matrix"
  (define m-bad
    (vector (flvector 0.5 0.5)
            (flvector 0.5 0.0)))
  (check-false (col-stochastic-fl? m-bad)))

;; ============================================================
;; Off-network kernel matches the rational version (within tolerance)
;; ============================================================

(test-case "float kernel matches rational ring step from p-seed-0"
  (define rat-result (eigentrust-step m-ring-4 p-seed-0 3/10 p-seed-0))
  (define fl-result  (eigentrust-step-fl m-ring-4-fl p-seed-0-fl 0.3 p-seed-0-fl))
  (check-true (flv-close? fl-result (rat-vec->flvector rat-result))))

;; ============================================================
;; End-to-end matches the rational version
;; ============================================================

(test-case "float ring-4 k=4 matches rational golden"
  (define result (run-eigentrust-propagators-fl m-ring-4-fl p-seed-0-fl 0.3 4))
  (define expected
    (rat-vec->flvector
     (vector 5401/10000 21/100 147/1000 1029/10000)))
  (check-true (flv-close? result expected)))

(test-case "float uniform converges to itself"
  (define result (run-eigentrust-propagators-fl m-uniform-4-fl p-uniform-4-fl 0.1 2))
  (check-true (flv-close? result p-uniform-4-fl)))

(test-case "float symmetric converges to uniform"
  (define result (run-eigentrust-propagators-fl m-others-3-fl p-uniform-3-fl 0.1 2))
  (check-true (flv-close? result p-uniform-3-fl)))

;; Mass preservation: result should sum to ~1 (probability distribution).
(test-case "float ring-4 mass preservation"
  (define result (run-eigentrust-propagators-fl m-ring-4-fl p-seed-0-fl 0.3 4))
  (define total (for/fold ([acc 0.0]) ([x (in-flvector result)]) (fl+ acc x)))
  (check-true (< (abs (- total 1.0)) 1e-12)))

(test-case "float panics on non-column-stochastic"
  (define m-bad
    (vector (flvector 0.5 0.5)
            (flvector 0.5 0.0)))
  (check-exn exn:fail?
             (lambda ()
               (run-eigentrust-propagators-fl m-bad
                                              (flvector 0.5 0.5)
                                              0.1 1))))
