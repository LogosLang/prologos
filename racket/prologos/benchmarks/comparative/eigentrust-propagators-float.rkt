#lang racket/base

;;; eigentrust-propagators-float.rkt — float (flonum) variant of the
;;; Racket-direct EigenTrust on propagators.
;;;
;;; Same chain-of-cells architecture as eigentrust-propagators.rkt
;;; (one cell per iteration, K plain propagators) but uses Racket
;;; flonums instead of exact rationals. Lets us measure the cost
;;; of exact-Rat arithmetic vs hardware float on the same propagator
;;; topology.

(require "../../propagator.rkt"
         racket/flonum)

(provide
 vec-zeros-fl
 col-stochastic-fl?
 eigentrust-step-fl
 build-eigentrust-network-fl
 run-eigentrust-propagators-fl
 ;; Fixtures
 m-ring-4-fl
 p-seed-0-fl
 m-uniform-4-fl
 p-uniform-4-fl
 m-others-3-fl
 p-uniform-3-fl)

;; ============================================================
;; Vector-of-flonum primitives
;; ============================================================

(define (vec-zeros-fl n)
  (make-flvector n 0.0))

(define (vec-add-fl a b)
  (define n (flvector-length a))
  (define out (make-flvector n))
  (for ([i (in-range n)])
    (flvector-set! out i (fl+ (flvector-ref a i) (flvector-ref b i))))
  out)

(define (vec-scale-fl s v)
  (define n (flvector-length v))
  (define out (make-flvector n))
  (for ([i (in-range n)])
    (flvector-set! out i (fl* s (flvector-ref v i))))
  out)

;; (M*t)[i] = dot(M[i], t).
;; M is a vector of flvectors (rows), t is an flvector.
(define (mat-vec-mul-fl m t)
  (define n (vector-length m))
  (define out (make-flvector n))
  (for ([i (in-range n)])
    (define row (vector-ref m i))
    (define dim (flvector-length row))
    ;; Seed at 0.0 to keep the accumulator a flonum (per pitfall #4).
    (flvector-set! out i
      (for/fold ([acc 0.0]) ([j (in-range dim)])
        (fl+ acc (fl* (flvector-ref row j) (flvector-ref t j))))))
  out)

;; Column-stochastic check (with a small tolerance for float round-off).
(define COL-SUM-TOLERANCE 1e-9)

(define (col-stochastic-fl? m)
  (define n (vector-length m))
  (define n-cols (flvector-length (vector-ref m 0)))
  (for/and ([j (in-range n-cols)])
    (define s (for/fold ([acc 0.0]) ([row (in-vector m)])
                (fl+ acc (flvector-ref row j))))
    (< (abs (- s 1.0)) COL-SUM-TOLERANCE)))

;; ============================================================
;; Off-network kernel
;; ============================================================

(define (eigentrust-step-fl m p alpha t)
  (vec-add-fl (vec-scale-fl (fl- 1.0 alpha) (mat-vec-mul-fl m t))
              (vec-scale-fl alpha p)))

;; ============================================================
;; Propagator-net assembly
;; ============================================================

(define (lww old new) new)

(define (build-eigentrust-network-fl m p alpha k)
  (unless (col-stochastic-fl? m)
    (error 'build-eigentrust-network-fl
           "M must be column-stochastic (within tolerance)"))
  (define net0 (make-prop-network))
  (define-values (net1 m-cid)     (net-new-cell net0     m     lww))
  (define-values (net2 p-cid)     (net-new-cell net1     p     lww))
  (define-values (net3 alpha-cid) (net-new-cell net2     alpha lww))
  (define-values (net4 t0-cid)    (net-new-cell net3     p     lww))
  (let loop ([net net4] [prev-cid t0-cid] [step 1])
    (if (> step k)
        (values net prev-cid)
        (let-values ([(net* next-cid)
                      (net-new-cell net (vec-zeros-fl (flvector-length p)) lww)])
          (define (fire net-param)
            (define t-prev    (net-cell-read net-param prev-cid))
            (define m-val     (net-cell-read net-param m-cid))
            (define p-val     (net-cell-read net-param p-cid))
            (define alpha-val (net-cell-read net-param alpha-cid))
            (net-cell-write net-param next-cid
                            (eigentrust-step-fl m-val p-val alpha-val t-prev)))
          (define-values (net** _pid)
            (net-add-propagator
             net*
             (list prev-cid m-cid p-cid alpha-cid)
             (list next-cid)
             fire))
          (loop net** next-cid (add1 step))))))

(define (run-eigentrust-propagators-fl m p alpha k)
  (define-values (net t-final-cid) (build-eigentrust-network-fl m p alpha k))
  (define net* (run-to-quiescence-bsp net))
  (net-cell-read net* t-final-cid))

;; ============================================================
;; Fixtures (flonum equivalents)
;; ============================================================

(define m-ring-4-fl
  (vector
   (flvector 0.0 0.0 0.0 1.0)
   (flvector 1.0 0.0 0.0 0.0)
   (flvector 0.0 1.0 0.0 0.0)
   (flvector 0.0 0.0 1.0 0.0)))

(define p-seed-0-fl (flvector 1.0 0.0 0.0 0.0))

(define m-uniform-4-fl
  (let ([row (flvector 0.25 0.25 0.25 0.25)])
    (vector row row row row)))

(define p-uniform-4-fl (flvector 0.25 0.25 0.25 0.25))

(define m-others-3-fl
  (vector
   (flvector 0.0 0.5 0.5)
   (flvector 0.5 0.0 0.5)
   (flvector 0.5 0.5 0.0)))

(define p-uniform-3-fl (flvector (/ 1.0 3.0) (/ 1.0 3.0) (/ 1.0 3.0)))

;; ============================================================
;; Module main: smoke
;; ============================================================

(module+ main
  (define result (run-eigentrust-propagators-fl m-ring-4-fl p-seed-0-fl 0.3 4))
  (printf "ring-4 / α=0.3 / k=4 (flonum):~n  ~s~n" result)
  ;; Expected (rat) ~ #(0.5401 0.21 0.147 0.1029).
  (define expected (flvector 0.5401 0.21 0.147 0.1029))
  (define tol 1e-9)
  (define ok?
    (for/and ([i (in-range 4)])
      (< (abs (- (flvector-ref result i) (flvector-ref expected i))) tol)))
  (unless ok?
    (error 'main "result not within ~e of expected~n  expected: ~s~n  got: ~s"
           tol expected result))
  (printf "result matches rational version within ~e ✓~n" tol))
