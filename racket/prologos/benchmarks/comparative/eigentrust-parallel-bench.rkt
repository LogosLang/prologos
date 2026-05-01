#lang racket/base

;;; eigentrust-parallel-bench.rkt — does parallel BSP help EigenTrust?
;;;
;;; Compares 5 implementations at sizes large enough for parallel
;;; dispatch to kick in (n ≥ 64 — comfortably above min-parallel=8):
;;;
;;;   1. math (plain-fl)               — direct Racket flvector,    1 core
;;;   2. coarse net (sequential)       — 1 propagator per BSP round, 1 core
;;;   3. fine net (sequential)         — n propagators per BSP round, 1 core
;;;   4. fine net (parallel-thread)    — n propagators / round, K cores via Racket-9 threads
;;;   5. fine net (worker-pool)        — n propagators / round, K cores via persistent pool
;;;
;;; The thesis under test: at large n, fine-grained network with
;;; parallel BSP CAN beat single-threaded math because the n
;;; per-iteration peer propagators fire across cores. Sequential
;;; fine cannot win (more bookkeeping than coarse for the same
;;; total work). Parallel fine MIGHT win once n ≫ ncores ·
;;; (per-fire constant cost).
;;;
;;; This is the "where parallelism could live" experiment named in
;;; docs/tracking/2026-04-23_eigentrust_comparison.md § Trend /
;;; breakeven analysis.

(require "../../propagator.rkt"
         "eigentrust-propagators-float.rkt"
         "eigentrust-propagators-fine-float.rkt"
         "eigentrust-plain.rkt"
         racket/flonum
         racket/list
         racket/future)

(define K 4)
(define NUM-RUNS 3)
(define WARMUP-RUNS 1)
(define TIMEOUT-MS 60000)

;; n=4 is below min-parallel=8 (sequential fallback even with parallel exec).
;; Real signal starts at n ≥ 16; we sample up through n=1024 to keep wall
;; time tractable on the fine variant (K·n propagator installs + reads).
(define SIZES '(16 32 64 128 256 512 1024))


;; ============================================================
;; Fixture generation (cache-friendly: row-major, no scatter).
;; ============================================================

(define (gen-fl-col-stochastic n)
  (define rows (for/vector #:length n ([i (in-range n)]) (make-flvector n)))
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


;; ============================================================
;; Timing harness
;; ============================================================

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


;; ============================================================
;; Variants — each closed over the fixture; takes no args.
;; ============================================================

(define (run-math m p) (run-eigentrust-plain-fl m p 0.3 K))
(define (run-coarse m p) (run-eigentrust-propagators-fl m p 0.3 K))
(define (run-fine m p) (run-eigentrust-propagators-fine-fl m p 0.3 K))

(define (run-fine-with-executor m p executor)
  (parameterize ([current-parallel-executor executor])
    (run-eigentrust-propagators-fine-fl m p 0.3 K)))


;; ============================================================
;; Per-row sweep
;; ============================================================

(define (bench-row n parallel-thread-exec pool-exec)
  (printf "n=~a — generating fixture..." n) (flush-output)
  (define m (gen-fl-col-stochastic n))
  (define p (uniform-fl n))
  (printf " done.~n") (flush-output)

  (define (variant label fn)
    (printf "  ~a : " label) (flush-output)
    (define s (sample-with-timeout fn))
    (cond
      [(eq? s 'timeout) (printf "TIMEOUT~n") 'timeout]
      [else (define r (round-2 (median s))) (printf "~a ms~n" r) r]))

  (define math-r       (variant "math (plain-fl)             "
                                (lambda () (run-math m p))))
  (define coarse-r     (variant "coarse net (seq)            "
                                (lambda () (run-coarse m p))))
  (define fine-seq-r   (variant "fine net (seq)              "
                                (lambda () (run-fine m p))))
  (define fine-thread-r
    (variant "fine net (parallel-thread)  "
             (lambda () (run-fine-with-executor m p parallel-thread-exec))))
  (define fine-pool-r
    (variant "fine net (worker-pool)      "
             (lambda () (run-fine-with-executor m p pool-exec))))

  ;; Overheads / speedups vs math
  (define (ratio r)
    (cond [(eq? r 'timeout) "TIMEOUT"]
          [(eq? math-r 'timeout) "n/a"]
          [else (format "~ax" (round-2 (/ r math-r)))]))
  (printf "  vs math: coarse=~a fine-seq=~a fine-thread=~a fine-pool=~a~n~n"
          (ratio coarse-r) (ratio fine-seq-r)
          (ratio fine-thread-r) (ratio fine-pool-r)))


;; ============================================================
;; Main
;; ============================================================

(module+ main
  (define ncores (processor-count))
  (printf "═══ EigenTrust parallel bench (cores=~a) ═══~n" ncores)
  (printf "K=~a, ~a measured runs/cell (median), ~a warmup, ~a ms timeout~n"
          K NUM-RUNS WARMUP-RUNS TIMEOUT-MS)
  (printf "Variants:~n")
  (printf "  - math        : plain Racket flvector, single-threaded~n")
  (printf "  - coarse net  : 1 propagator per BSP round (chain), single-threaded~n")
  (printf "  - fine net    : n propagators per BSP round (per-peer)~n")
  (printf "                  (seq / parallel-thread / worker-pool)~n~n")
  (random-seed 42)

  ;; Build pool + thread executors once; both reused across all rows.
  (define pool (make-worker-pool ncores))
  (define pool-exec (make-pool-executor pool 8))
  (define thread-exec (make-parallel-thread-fire-all 8))

  (for ([n (in-list SIZES)])
    (bench-row n thread-exec pool-exec))

  ;; Cleanup
  (worker-pool-shutdown! pool))
