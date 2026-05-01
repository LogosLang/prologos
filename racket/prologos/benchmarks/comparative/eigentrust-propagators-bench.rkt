#lang racket/base

;;; eigentrust-propagators-bench.rkt — timing harness for the
;;; Racket-direct propagator EigenTrust variants.
;;;
;;; Three propagator variants compared head-to-head, plus their
;;; relationship to the Prologos surface benchmarks:
;;;   - rat (coarse) : one cell per iteration, exact rationals
;;;   - rat (fine)   : one cell per (iteration, peer) — K·n cells
;;;   - float        : one cell per iteration, hardware flonum
;;;
;;; Reports wall_ms, reduce_ms (algorithm time, comparable to
;;; PHASE-TIMINGS reduce_ms in the Prologos benchmarks), and the
;;; sub-breakdowns build_ms (network construction) and bsp_ms (run
;;; to quiescence).
;;;
;;; Run via:
;;;   racket benchmarks/comparative/eigentrust-propagators-bench.rkt

(require "../../propagator.rkt"
         "eigentrust-propagators.rkt"
         "eigentrust-propagators-fine.rkt"
         "eigentrust-propagators-float.rkt"
         racket/list
         racket/flonum)

(define NUM-RUNS 5)
(define WARMUP-RUNS 1)

;; ============================================================
;; Per-run timing — variant-agnostic.
;;
;; `build-fn` is a thunk-like procedure: (build-fn m p alpha k) →
;; (values net result-cid-or-vector). For coarse/float variants,
;; result-cid is a single cell-id; for fine, it's a vector of
;; cell-ids.
;; `read-fn` is (read-fn net result-cid-or-vector) → result.
;; ============================================================

(define (time-one-run build-fn read-fn m p alpha k)
  (define t0 (current-inexact-monotonic-milliseconds))
  (define-values (net result-handle) (build-fn m p alpha k))
  (define t1 (current-inexact-monotonic-milliseconds))
  (define net* (run-to-quiescence-bsp net))
  (define t2 (current-inexact-monotonic-milliseconds))
  (define result (read-fn net* result-handle))
  (define t3 (current-inexact-monotonic-milliseconds))
  (values (- t1 t0) (- t2 t1) (- t3 t2) (- t3 t0) result))

;; Coarse variants: result-handle is a single cell-id, read once.
(define (read-single net cid) (net-cell-read net cid))

;; Fine variant: result-handle is a vector of cell-ids; read each.
(define (read-many net cids)
  (define n (vector-length cids))
  (for/vector #:length n ([j (in-range n)])
    (net-cell-read net (vector-ref cids j))))


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

(define (round-2 x)
  (/ (round (* 100 x)) 100))

(define (run-bench label build-fn read-fn m p alpha k)
  ;; Warmup
  (for ([_ (in-range WARMUP-RUNS)])
    (time-one-run build-fn read-fn m p alpha k))
  ;; Measured runs
  (define samples
    (for/list ([_ (in-range NUM-RUNS)])
      (collect-garbage 'major)
      (define-values (b r d t result) (time-one-run build-fn read-fn m p alpha k))
      (list b r d t result)))
  (define builds (map car samples))
  (define bsps   (map cadr samples))
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
  (printf "  reduce_ms     : median ~a (min ~a, max ~a, n=~a)~n"
          (round-2 (median totals))
          (round-2 (apply min totals))
          (round-2 (apply max totals))
          NUM-RUNS)
  (newline))


;; ============================================================
;; Workloads
;; ============================================================

(module+ main
  (define wall-t0 (current-inexact-monotonic-milliseconds))

  (printf "═══ EigenTrust on Propagators — 3 variants × workloads ═══~n")
  (printf "Runs per workload: ~a (+ ~a warmup)~n~n" NUM-RUNS WARMUP-RUNS)

  ;; ============================================================
  ;; W3 — the canonical workload: ring-4, α=3/10, k=4.
  ;; All three variants must produce the same answer (within tol
  ;; for float).
  ;; ============================================================
  (run-bench "rat-coarse  W3 ring-4 / α=3/10 / k=4"
             build-eigentrust-network read-single
             m-ring-4 p-seed-0 3/10 4)
  (run-bench "rat-fine    W3 ring-4 / α=3/10 / k=4"
             build-eigentrust-network-fine read-many
             m-ring-4 p-seed-0 3/10 4)
  (run-bench "float       W3 ring-4 / α=0.3 / k=4"
             build-eigentrust-network-fl read-single
             m-ring-4-fl p-seed-0-fl 0.3 4)

  ;; ============================================================
  ;; W3-deep — ring with k=10, exercises chain depth.
  ;; The Prologos surface variants O(k²) blow up here; propagator
  ;; variants stay linear in K.
  ;; ============================================================
  (run-bench "rat-coarse  W3-deep ring-4 / α=3/10 / k=10"
             build-eigentrust-network read-single
             m-ring-4 p-seed-0 3/10 10)
  (run-bench "rat-fine    W3-deep ring-4 / α=3/10 / k=10"
             build-eigentrust-network-fine read-many
             m-ring-4 p-seed-0 3/10 10)
  (run-bench "float       W3-deep ring-4 / α=0.3 / k=10"
             build-eigentrust-network-fl read-single
             m-ring-4-fl p-seed-0-fl 0.3 10)

  ;; ============================================================
  ;; W1 — uniform fixed point.
  ;; ============================================================
  (run-bench "rat-coarse  W1 uniform-4 / α=1/10 / k=2"
             build-eigentrust-network read-single
             m-uniform-4 p-uniform-4 1/10 2)
  (run-bench "rat-fine    W1 uniform-4 / α=1/10 / k=2"
             build-eigentrust-network-fine read-many
             m-uniform-4 p-uniform-4 1/10 2)
  (run-bench "float       W1 uniform-4 / α=0.1 / k=2"
             build-eigentrust-network-fl read-single
             m-uniform-4-fl p-uniform-4-fl 0.1 2)

  (define wall-t1 (current-inexact-monotonic-milliseconds))
  (printf "Total benchmark wall: ~a ms~n" (round-2 (- wall-t1 wall-t0))))
