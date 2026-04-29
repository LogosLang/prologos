#lang racket/base

;;; eigentrust-propagators-bench.rkt — timing harness for the 5th
;;; comparison variant.
;;;
;;; Reports wall_ms, reduce_ms (algorithm time only, comparable to
;;; the Prologos benchmarks' PHASE-TIMINGS reduce_ms), and the
;;; sub-breakdowns build_ms (network construction) and bsp_ms (run
;;; to quiescence).
;;;
;;; Run via:
;;;   racket benchmarks/comparative/eigentrust-propagators-bench.rkt
;;;
;;; Output format mirrors `tools/bench-phases.rkt`'s per-variant
;;; section so the numbers can be eyeballed against the four
;;; Prologos surface variants directly.

(require "../../propagator.rkt"
         "eigentrust-propagators.rkt"
         racket/list)

(define NUM-RUNS 5)
(define WARMUP-RUNS 1)

;; ============================================================
;; Per-run timing
;; ============================================================

;; Returns (values build-ms bsp-ms read-ms total-reduce-ms result).
;; build-ms: time to construct the network with K propagators.
;; bsp-ms: time to run BSP to quiescence.
;; read-ms: time to read the final cell.
;; total-reduce-ms: build + bsp + read (comparable to Prologos reduce_ms).
(define (time-one-run m p alpha k)
  (define t0 (current-inexact-monotonic-milliseconds))
  (define-values (net t-final-cid) (build-eigentrust-network m p alpha k))
  (define t1 (current-inexact-monotonic-milliseconds))
  (define net* (run-to-quiescence-bsp net))
  (define t2 (current-inexact-monotonic-milliseconds))
  (define result (net-cell-read net* t-final-cid))
  (define t3 (current-inexact-monotonic-milliseconds))
  (values (- t1 t0) (- t2 t1) (- t3 t2) (- t3 t0) result))


;; ============================================================
;; Aggregation
;; ============================================================

(define (median xs)
  (define sorted (sort xs <))
  (define n (length sorted))
  (cond [(zero? n) 0]
        [(odd? n)  (list-ref sorted (quotient n 2))]
        [else      (/ (+ (list-ref sorted (sub1 (quotient n 2)))
                         (list-ref sorted (quotient n 2)))
                      2)]))

(define (run-bench label m p alpha k)
  ;; Warmup
  (for ([_ (in-range WARMUP-RUNS)])
    (time-one-run m p alpha k))
  ;; Measured runs
  (define samples
    (for/list ([_ (in-range NUM-RUNS)])
      (collect-garbage 'major)
      (define-values (b r d t result) (time-one-run m p alpha k))
      (list b r d t result)))
  (define builds (map car samples))
  (define bsps   (map cadr samples))
  (define reads  (map caddr samples))
  (define totals (map cadddr samples))
  (define result (last (last samples)))
  (printf "── ~a ──~n" label)
  (printf "  result        : ~s~n" result)
  (printf "  build_ms      : median ~a (min ~a, max ~a)~n"
          (round-2 (median builds))
          (round-2 (apply min builds))
          (round-2 (apply max builds)))
  (printf "  bsp_ms        : median ~a (min ~a, max ~a)~n"
          (round-2 (median bsps))
          (round-2 (apply min bsps))
          (round-2 (apply max bsps)))
  (printf "  read_ms       : median ~a~n" (round-2 (median reads)))
  (printf "  reduce_ms     : median ~a (min ~a, max ~a, n=~a)~n"
          (round-2 (median totals))
          (round-2 (apply min totals))
          (round-2 (apply max totals))
          NUM-RUNS)
  (newline))

(define (round-2 x)
  (/ (round (* 100 x)) 100))


;; ============================================================
;; Workloads — match the Prologos benchmarks where possible.
;; The dominant workload is W3: ring-4, k=4, α=3/10. Others are
;; smaller checks.
;; ============================================================

(module+ main
  (define wall-t0 (current-inexact-monotonic-milliseconds))

  (printf "═══ EigenTrust on Propagators (Racket-direct) ═══~n")
  (printf "Runs per workload: ~a (+ ~a warmup)~n~n" NUM-RUNS WARMUP-RUNS)

  ;; W3 — the dominant workload that drives the Prologos reduce_ms.
  ;; Ring 4-peer, concentrated pre-trust, α=3/10, 4 step calls (matches
  ;; Prologos `eigentrust ... 3/10 0/1 3` which does max-iter + 1 = 4).
  (run-bench "W3 ring-4 / α=3/10 / k=4"
             m-ring-4 p-seed-0 3/10 4)

  ;; W1 — uniform fixed-point. Converges in 1 step in the Prologos
  ;; version (eps triggers exit); here we run k=2 to match the structure
  ;; (1 actual computation step + 1 budget tail).
  (run-bench "W1 uniform-4 / α=1/10 / k=2"
             m-uniform-4 p-uniform-4 1/10 2)

  ;; W2 — symmetric 3x3 fixed point.
  (run-bench "W2 others-3 / α=1/10 / k=2"
             m-others-3 p-uniform-3 1/10 2)

  ;; W3-deep — same ring fixture but 10 steps to show how the propagator
  ;; chain scales with iteration depth.
  (run-bench "W3-deep ring-4 / α=3/10 / k=10"
             m-ring-4 p-seed-0 3/10 10)

  (define wall-t1 (current-inexact-monotonic-milliseconds))
  (printf "Total benchmark wall: ~a ms~n" (round-2 (- wall-t1 wall-t0))))
