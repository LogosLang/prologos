#lang racket/base

;;; eigentrust-propagators-scaling.rkt — scaling benchmark across n.
;;;
;;; Generates random column-stochastic matrices at various sizes and
;;; times all three propagator variants. Each (variant, n) sample
;;; gets a wall-clock timeout (TIMEOUT-MS); samples that exceed it
;;; are killed and reported as TIMEOUT. Once a variant times out at
;;; some n, larger n are skipped (also TIMEOUT) — exact-rat scaling
;;; is monotone in n so this is safe and avoids wasting hours on
;;; intractable cells.
;;;
;;; Fixed K=4 (matches the W3 reference workload).

(require "../../propagator.rkt"
         "eigentrust-propagators.rkt"
         "eigentrust-propagators-fine.rkt"
         "eigentrust-propagators-float.rkt"
         racket/list
         racket/flonum)

(define K 4)
(define NUM-RUNS 3)
(define WARMUP-RUNS 1)
(define TIMEOUT-MS 30000)  ;; per-sample timeout — anything slower is "intractable"

(define SIZES '(8 16 32 64 128 256 512 1024 2048 4096))


;; ============================================================
;; Random column-stochastic matrix generation
;; ============================================================

(define (random-positive)
  (+ 1 (/ (random 1 1000000) 1000000)))

(define (gen-rat-col-stochastic n)
  (define cols
    (for/list ([j (in-range n)])
      (define raw (for/list ([i (in-range n)]) (random-positive)))
      (define s (apply + raw))
      (map (lambda (x) (/ x s)) raw)))
  (for/vector #:length n ([i (in-range n)])
    (for/vector #:length n ([j (in-range n)])
      (list-ref (list-ref cols j) i))))

(define (gen-fl-col-stochastic n)
  (define cols
    (for/list ([j (in-range n)])
      (define raw (for/list ([i (in-range n)]) (+ 1.0 (random))))
      (define s (apply + raw))
      (map (lambda (x) (/ x s)) raw)))
  (for/vector #:length n ([i (in-range n)])
    (define out (make-flvector n))
    (for ([j (in-range n)])
      (flvector-set! out j (list-ref (list-ref cols j) i)))
    out))

(define (uniform-rat n)
  (for/vector #:length n ([i (in-range n)]) (/ 1 n)))

(define (uniform-fl n)
  (define v (make-flvector n))
  (for ([i (in-range n)]) (flvector-set! v i (/ 1.0 n)))
  v)


;; ============================================================
;; Per-sample timeout
;;
;; Run thunk in a thread; if it doesn't finish within TIMEOUT-MS,
;; kill the thread and return 'timeout. Otherwise return the elapsed
;; ms (the thunk's value is discarded — we just want the timing).
;; ============================================================

(define (timed-thunk-or-timeout thunk timeout-ms)
  (define result-box (box #f))
  (define t0 (current-inexact-monotonic-milliseconds))
  (define t (thread (lambda ()
                      (thunk)
                      (set-box! result-box
                                (- (current-inexact-monotonic-milliseconds) t0)))))
  (define done? (sync/timeout (/ timeout-ms 1000.0) t))
  (cond
    [done? (unbox result-box)]
    [else (kill-thread t) 'timeout]))

(define (sample-with-timeout fn)
  ;; Returns either a list of timing samples (length NUM-RUNS) or 'timeout.
  ;; Bails on the first timeout.
  ;; Skip warmup if first measured run already times out.
  (collect-garbage 'major)
  (define first (timed-thunk-or-timeout fn TIMEOUT-MS))
  (cond
    [(eq? first 'timeout) 'timeout]
    [else
     ;; First sample succeeded; do warmup ALREADY happened (the
     ;; first call) → use it as warmup, take NUM-RUNS more.
     (let loop ([acc '()] [remaining NUM-RUNS])
       (cond
         [(zero? remaining) (reverse acc)]
         [else
          (collect-garbage 'major)
          (define s (timed-thunk-or-timeout fn TIMEOUT-MS))
          (cond
            [(eq? s 'timeout) 'timeout]
            [else (loop (cons s acc) (sub1 remaining))])]))]))


;; ============================================================
;; Aggregation
;; ============================================================

(define (median xs)
  (define s (sort xs <))
  (define n (length s))
  (cond [(zero? n) 0]
        [(odd? n) (list-ref s (quotient n 2))]
        [else (/ (+ (list-ref s (sub1 (quotient n 2)))
                    (list-ref s (quotient n 2))) 2)]))

(define (round-2 x) (/ (round (* 100 x)) 100))

(define (~a v [w 5])
  (define s (format "~a" v))
  (define pad (max 0 (- w (string-length s))))
  (string-append s (make-string pad #\space)))

(define (~r v [w 11])
  (define s (cond [(eq? v 'timeout) "TIMEOUT"]
                  [(eq? v 'skipped) "(skip)"]
                  [else (format "~a ms" v)]))
  (define pad (max 0 (- w (string-length s))))
  (string-append (make-string pad #\space) s))


;; ============================================================
;; Per-size benchmark — accepts a "skip" flag per variant
;; ============================================================

(define (run-or-skip skip? thunk)
  (cond [skip? 'skipped]
        [else (define samples (sample-with-timeout thunk))
              (cond [(eq? samples 'timeout) 'timeout]
                    [else (round-2 (median samples))])]))

(define (bench-row n skip-rat-coarse? skip-rat-fine? skip-float?)
  (define m-rat (if (or skip-rat-coarse? skip-rat-fine?) #f (gen-rat-col-stochastic n)))
  (define p-rat (if (or skip-rat-coarse? skip-rat-fine?) #f (uniform-rat n)))
  (define m-fl  (if skip-float? #f (gen-fl-col-stochastic n)))
  (define p-fl  (if skip-float? #f (uniform-fl n)))
  (define rat-coarse-r
    (run-or-skip skip-rat-coarse?
                 (lambda () (run-eigentrust-propagators m-rat p-rat 3/10 K))))
  (define rat-fine-r
    (run-or-skip skip-rat-fine?
                 (lambda () (run-eigentrust-propagators-fine m-rat p-rat 3/10 K))))
  (define float-r
    (run-or-skip skip-float?
                 (lambda () (run-eigentrust-propagators-fl m-fl p-fl 0.3 K))))
  (printf "  n=~a  rat-coarse=~a  rat-fine=~a  float=~a~n"
          (~a n) (~r rat-coarse-r) (~r rat-fine-r) (~r float-r))
  (values
   (or skip-rat-coarse? (eq? rat-coarse-r 'timeout))
   (or skip-rat-fine?   (eq? rat-fine-r   'timeout))
   (or skip-float?      (eq? float-r      'timeout))))


;; ============================================================
;; Main: sweep
;; ============================================================

(module+ main
  (printf "═══ Scaling: 3 propagator variants × matrix size n ═══~n")
  (printf "Fixed K=~a (W3 reference). ~a measured runs per cell, median.~n"
          K NUM-RUNS)
  (printf "Per-sample timeout: ~a ms. Once a variant times out at n,~n" TIMEOUT-MS)
  (printf "larger n are skipped (TIMEOUT propagates monotonically in n).~n~n")
  (random-seed 42)
  (let loop ([sizes SIZES]
             [skip-rat-coarse? #f]
             [skip-rat-fine? #f]
             [skip-float? #f])
    (cond
      [(null? sizes) (void)]
      [else
       (define-values (skc skf sf)
         (bench-row (car sizes) skip-rat-coarse? skip-rat-fine? skip-float?))
       (loop (cdr sizes) skc skf sf)])))
