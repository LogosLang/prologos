#lang racket/base

;;; eigentrust-scaling-large.rkt — extended scaling math vs network.
;;;
;;; Companion to eigentrust-propagators-scaling.rkt. Pushes math
;;; (plain-fl) + network (float) past n=4096 to look for a
;;; breakeven / breakaway point. K=4 (matches the W3 reference
;;; workload). Per-sample timeout 180s — enough that math's O(n²)
;;; can reach n=32768 (~30 s/run).

(require "../../propagator.rkt"
         "eigentrust-propagators-float.rkt"
         "eigentrust-plain.rkt"
         racket/list
         racket/flonum)

(define K 4)
(define NUM-RUNS 2)
(define TIMEOUT-MS 180000)

;; n=32768 needs ~8 GB for the matrix alone; on a 16 GB host this OOMs
;; once Racket's previous-iteration heap is still rooted. Stop at 16384.
;; If you have a 32+ GB host, append 32768 here.
(define SIZES '(4096 8192 16384))


;; Build column-stochastic n×n matrix as a vector of flvectors (rows).
;; Uses only flvector ops — O(n²) flonum operations, no list allocation.
;; Layout: result[i] is row i, an flvector of length n; result[i][j] = M_{ij}.
;; Build column-by-column: draw n positives, sum, divide by sum, scatter into rows.
(define (gen-fl-col-stochastic n)
  (define rows
    (for/vector #:length n ([i (in-range n)])
      (make-flvector n)))
  (define col (make-flvector n))
  (for ([j (in-range n)])
    (define s 0.0)
    (for ([i (in-range n)])
      (define v (+ 1.0 (random)))
      (flvector-set! col i v)
      (set! s (+ s v)))
    (for ([i (in-range n)])
      (flvector-set! (vector-ref rows i) j
                     (/ (flvector-ref col i) s))))
  rows)

(define (uniform-fl n)
  (define v (make-flvector n))
  (for ([i (in-range n)]) (flvector-set! v i (/ 1.0 n)))
  v)

(define (timed-thunk-or-timeout thunk timeout-ms)
  (define result-box (box #f))
  (define t0 (current-inexact-monotonic-milliseconds))
  (define t (thread (lambda ()
                      (thunk)
                      (set-box! result-box
                                (- (current-inexact-monotonic-milliseconds) t0)))))
  (define done? (sync/timeout (/ timeout-ms 1000.0) t))
  (cond [done? (unbox result-box)]
        [else (kill-thread t) 'timeout]))

(define (sample-with-timeout fn)
  (collect-garbage 'major)
  (define first (timed-thunk-or-timeout fn TIMEOUT-MS))
  (cond
    [(eq? first 'timeout) 'timeout]
    [else
     (let loop ([acc '()] [remaining NUM-RUNS])
       (cond [(zero? remaining) (reverse acc)]
             [else
              (collect-garbage 'major)
              (define s (timed-thunk-or-timeout fn TIMEOUT-MS))
              (cond [(eq? s 'timeout) 'timeout]
                    [else (loop (cons s acc) (sub1 remaining))])]))]))

(define (median xs)
  (define s (sort xs <))
  (define n (length s))
  (cond [(zero? n) 0]
        [(odd? n) (list-ref s (quotient n 2))]
        [else (/ (+ (list-ref s (sub1 (quotient n 2)))
                    (list-ref s (quotient n 2))) 2)]))

(define (round-2 x) (/ (round (* 100 x)) 100))

(module+ main
  (printf "═══ Extended scaling: math vs network at large n ═══~n")
  (printf "K=~a, ~a runs/cell, TIMEOUT ~a ms~n~n" K NUM-RUNS TIMEOUT-MS)
  (random-seed 42)
  (for ([n (in-list SIZES)])
    (printf "n=~a — generating fixture..." n)
    (flush-output)
    (define m (gen-fl-col-stochastic n))
    (define p (uniform-fl n))
    (printf " done.~n")
    (printf "  math (plain-fl) : ")
    (flush-output)
    (define plain-samples
      (sample-with-timeout
       (lambda () (run-eigentrust-plain-fl m p 0.3 K))))
    (define plain-r
      (cond [(eq? plain-samples 'timeout) 'timeout]
            [else (round-2 (median plain-samples))]))
    (printf "~a ms~n" plain-r)
    (printf "  network (float) : ")
    (flush-output)
    (define net-samples
      (sample-with-timeout
       (lambda () (run-eigentrust-propagators-fl m p 0.3 K))))
    (define net-r
      (cond [(eq? net-samples 'timeout) 'timeout]
            [else (round-2 (median net-samples))]))
    (printf "~a ms~n" net-r)
    (when (and (number? plain-r) (number? net-r))
      (define ovh (round-2 (* 100.0 (/ (- net-r plain-r) plain-r))))
      (printf "  overhead        : +~a%%~n" ovh))
    (newline)))
