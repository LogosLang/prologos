#lang racket/base

;;; eigentrust-propagators-scaling.rkt — scaling benchmark across n.
;;;
;;; Generates random column-stochastic matrices at various sizes
;;; (n = 8, 16, 32, 64, 128, 256, 512, 1024) and times all three
;;; propagator variants. Fixed k=4 (matches W3) so the only variable
;;; is matrix size n.
;;;
;;; What we want to know:
;;; - Does the coarse-vs-fine trade-off flip as n grows?
;;; - Does float pull further ahead of rat as n grows (denominator
;;;   blowup matters more)?
;;; - At what n does the build_ms (cell allocation) become significant?

(require "../../propagator.rkt"
         "eigentrust-propagators.rkt"
         "eigentrust-propagators-fine.rkt"
         "eigentrust-propagators-float.rkt"
         racket/list
         racket/flonum)

(define K 4)
(define NUM-RUNS 3)
(define WARMUP-RUNS 1)
;; Sizes for the rat variants. Exact-rat denominators compound across
;; iterations; n=128 already takes ~140 s/run, so we cap the rat sweep
;; here. Float runs separately at much larger n (see SIZES-FLOAT-ONLY
;; below).
(define SIZES-RAT '(8 16 32 64 128))
;; Float-only sweep — denominator growth doesn't apply.
(define SIZES-FLOAT-ONLY '(256 512 1024 2048 4096))

;; ============================================================
;; Random column-stochastic matrix generation.
;;
;; For each column j, draw n exponential random reals and normalise
;; so the column sums to exactly 1. Use exact rationals to avoid
;; round-off issues in the col-stochastic? check.
;; ============================================================

(define (random-positive)
  ;; Return an exact-rational positive number ~ uniform(0, 1].
  ;; Use random's integer mode and divide.
  (+ 1 (/ (random 1 1000000) 1000000)))

(define (gen-rat-col-stochastic n)
  ;; Build n×n where each column is normalized.
  (define cols
    (for/list ([j (in-range n)])
      (define raw (for/list ([i (in-range n)]) (random-positive)))
      (define s (apply + raw))
      (map (lambda (x) (/ x s)) raw)))
  ;; Transpose (cols→rows) and convert to vector-of-vectors.
  (for/vector #:length n ([i (in-range n)])
    (for/vector #:length n ([j (in-range n)])
      (list-ref (list-ref cols j) i))))

(define (rat-mat->fl-mat m)
  (define n (vector-length m))
  (for/vector #:length n ([i (in-range n)])
    (define row (vector-ref m i))
    (define dim (vector-length row))
    (define out (make-flvector dim))
    (for ([j (in-range dim)])
      (flvector-set! out j (exact->inexact (vector-ref row j))))
    out))

(define (rat-vec->fl-vec v)
  (define n (vector-length v))
  (define out (make-flvector n))
  (for ([i (in-range n)])
    (flvector-set! out i (exact->inexact (vector-ref v i))))
  out)

(define (uniform-rat n)
  (for/vector #:length n ([i (in-range n)]) (/ 1 n)))

;; ============================================================
;; Timing
;; ============================================================

(define (time-fn fn)
  (collect-garbage 'major)
  (define t0 (current-inexact-monotonic-milliseconds))
  (fn)
  (define t1 (current-inexact-monotonic-milliseconds))
  (- t1 t0))

(define (median xs)
  (define s (sort xs <))
  (define n (length s))
  (cond [(zero? n) 0]
        [(odd? n) (list-ref s (quotient n 2))]
        [else (/ (+ (list-ref s (sub1 (quotient n 2)))
                    (list-ref s (quotient n 2))) 2)]))

(define (round-2 x) (/ (round (* 100 x)) 100))

;; Run a thunk N times (after warmup), return list of timings.
(define (sample fn)
  (for ([_ (in-range WARMUP-RUNS)]) (fn))
  (for/list ([_ (in-range NUM-RUNS)]) (time-fn fn)))


;; ============================================================
;; Per-size benchmark
;; ============================================================

(define (bench-size-all n)
  (define m-rat (gen-rat-col-stochastic n))
  (define p-rat (uniform-rat n))
  (define m-fl  (rat-mat->fl-mat m-rat))
  (define p-fl  (rat-vec->fl-vec p-rat))

  (define rat-coarse-ms
    (median (sample (lambda () (run-eigentrust-propagators m-rat p-rat 3/10 K)))))
  (define rat-fine-ms
    (median (sample (lambda () (run-eigentrust-propagators-fine m-rat p-rat 3/10 K)))))
  (define float-ms
    (median (sample (lambda () (run-eigentrust-propagators-fl m-fl p-fl 0.3 K)))))

  (printf "  n=~a  rat-coarse=~ams  rat-fine=~ams  float=~ams  fine/coarse=~ax  rat/float=~ax~n"
          (~a n)
          (~r (round-2 rat-coarse-ms))
          (~r (round-2 rat-fine-ms))
          (~r (round-2 float-ms))
          (round-2 (/ rat-fine-ms rat-coarse-ms))
          (round-2 (/ rat-coarse-ms float-ms))))

(define (bench-size-float-only n)
  ;; Build the matrix in float directly to avoid intractable rat
  ;; generation at large n.
  (define m-fl
    (let ()
      (define cols
        (for/list ([j (in-range n)])
          (define raw (for/list ([i (in-range n)]) (+ 1.0 (random))))
          (define s (apply + raw))
          (map (lambda (x) (/ x s)) raw)))
      ;; Transpose cols → rows
      (for/vector #:length n ([i (in-range n)])
        (define out (make-flvector n))
        (for ([j (in-range n)])
          (flvector-set! out j (list-ref (list-ref cols j) i)))
        out)))
  (define p-fl
    (let ([v (make-flvector n)])
      (for ([i (in-range n)]) (flvector-set! v i (/ 1.0 n)))
      v))
  (define float-ms
    (median (sample (lambda () (run-eigentrust-propagators-fl m-fl p-fl 0.3 K)))))
  (printf "  n=~a  float=~ams~n"
          (~a n)
          (~r (round-2 float-ms))))

(define (~a v [w 5])
  (define s (format "~a" v))
  (define pad (max 0 (- w (string-length s))))
  (string-append s (make-string pad #\space)))

(define (~r v [w 9])
  (define s (format "~a" v))
  (define pad (max 0 (- w (string-length s))))
  (string-append (make-string pad #\space) s))


(module+ main
  (printf "═══ Scaling: 3 propagator variants × matrix size n ═══~n")
  (printf "Fixed K=~a (W3 reference). ~a runs per (variant, n), median.~n~n"
          K NUM-RUNS)
  (random-seed 42)  ;; reproducible matrix draws
  (printf "All variants:~n")
  (for ([n (in-list SIZES-RAT)])
    (bench-size-all n))
  (newline)
  (printf "Float only (rat denominator growth makes rat intractable above n=128):~n")
  (for ([n (in-list SIZES-FLOAT-ONLY)])
    (bench-size-float-only n)))
