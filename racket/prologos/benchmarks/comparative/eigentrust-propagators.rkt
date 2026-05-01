#lang racket/base

;;; eigentrust-propagators.rkt — direct Racket-on-propagators eigentrust.
;;;
;;; Fifth variant for the EigenTrust comparison (vs the four Prologos
;;; surface variants in this directory: list-rat, list-posit, pvec-rat,
;;; pvec-posit). This file bypasses the Prologos surface language and
;;; uses the propagator network primitives (make-prop-network,
;;; net-new-cell, net-add-propagator, run-to-quiescence-bsp) directly
;;; from Racket. It isolates "how fast is the propagator infrastructure
;;; on this workload" from "how fast is Prologos elaboration + reduction
;;; on this workload" — the surface variants pay both.
;;;
;;; Architecture: chain-of-cells (one cell per iteration, holding the
;;; entire trust vector). K propagators (one per step) flow trust from
;;; t_{k-1} to t_k. Constants (matrix M, pre-trust p, alpha) live in
;;; their own cells with last-write-wins merge. See
;;; docs/tracking/2026-04-29_0650_eigentrust-on-propagators.md.
;;;
;;; The matrix-vector multiply inside each step's fire function is
;;; off-network Racket compute. The on-network flow is the trust-vector
;;; cell sequence; the per-step kernel is opaque to the network. A
;;; finer-grained variant (one cell per peer per iteration) would be
;;; more on-network at higher constant cost — out of scope for this
;;; comparison.

(require "../../propagator.rkt")

(provide
 ;; Vector-of-rationals helpers
 vec-zeros
 col-stochastic?
 ;; The eigentrust kernel (off-network, for reuse in tests + bench)
 eigentrust-step
 ;; The propagator-net assembly + run
 build-eigentrust-network
 run-eigentrust-propagators
 ;; Pre-built fixtures (match the Prologos benchmarks)
 m-ring-4
 p-seed-0
 m-uniform-4
 p-uniform-4
 m-others-3
 p-uniform-3)

;; ============================================================
;; Vector-of-rationals primitives (Racket exact rationals)
;; ============================================================

(define (vec-zeros n)
  (make-vector n 0))

(define (vec-add a b)
  (for/vector #:length (vector-length a) ([x (in-vector a)] [y (in-vector b)])
    (+ x y)))

(define (vec-scale s v)
  (for/vector #:length (vector-length v) ([x (in-vector v)])
    (* s x)))

;; Standard matrix-vector multiply: (M*t)[i] = dot(M[i], t).
;; M is a vector-of-vectors (row-major).
(define (mat-vec-mul m t)
  (for/vector #:length (vector-length m) ([row (in-vector m)])
    (for/sum ([x (in-vector row)] [y (in-vector t)])
      (* x y))))

;; Column-stochastic invariant: every column sums to 1.
(define (col-stochastic? m)
  (define n (vector-length m))
  (define n-cols (vector-length (vector-ref m 0)))
  (for/and ([j (in-range n-cols)])
    (= 1 (for/sum ([row (in-vector m)]) (vector-ref row j)))))

;; ============================================================
;; The EigenTrust kernel — off-network
;; ============================================================

;; t_new = (1 - alpha) * M * t + alpha * p
(define (eigentrust-step m p alpha t)
  (vec-add (vec-scale (- 1 alpha) (mat-vec-mul m t))
           (vec-scale alpha p)))


;; ============================================================
;; The propagator-net assembly: build + run
;; ============================================================

;; last-write-wins merge — used for cells that get exactly one write.
;; Treats #f as "no value yet"; first non-#f wins, second non-#f
;; replaces (we use it under fire-once so this never happens in
;; practice). Combined with PROP-FIRE-ONCE on the producer, the cell
;; sees exactly one write.
(define (lww old new) new)

;; Build a propagator network for K iterations of EigenTrust on
;; matrix M, pre-trust p, alpha. Pre-loads t_0 with p (matches the
;; Prologos `eigentrust` entry: t0 = p convention). Returns
;; (values network t-final-cid) — t-final-cid is the cell holding
;; t_K after BSP quiescence.
(define (build-eigentrust-network m p alpha k)
  ;; Enforce the invariant up front, mirroring the Prologos
  ;; `eigentrust` entry.
  (unless (col-stochastic? m)
    (error 'build-eigentrust-network
           "M must be column-stochastic"))
  ;; Constant cells: last-write-wins, pre-loaded.
  (define net0 (make-prop-network))
  (define-values (net1 m-cid)     (net-new-cell net0     m     lww))
  (define-values (net2 p-cid)     (net-new-cell net1     p     lww))
  (define-values (net3 alpha-cid) (net-new-cell net2     alpha lww))
  ;; Iteration cells. Pre-load t_0 with p.
  (define-values (net4 t0-cid)    (net-new-cell net3     p     lww))
  ;; Build the chain: t_0 → t_1 → ... → t_K.
  ;; Each step is a fire-once propagator.
  (let loop ([net net4] [prev-cid t0-cid] [step 1])
    (if (> step k)
        (values net prev-cid)
        (let-values ([(net* next-cid) (net-new-cell net (vec-zeros (vector-length p)) lww)])
          ;; Fire function: read prev, M, p, alpha; write next.
          ;; CRITICAL (per propagator-design rule): use the lambda's
          ;; net parameter, never close over the outer net.
          (define (fire net-param)
            (define t-prev (net-cell-read net-param prev-cid))
            (define m-val  (net-cell-read net-param m-cid))
            (define p-val  (net-cell-read net-param p-cid))
            (define alpha-val (net-cell-read net-param alpha-cid))
            (define t-new (eigentrust-step m-val p-val alpha-val t-prev))
            (net-cell-write net-param next-cid t-new))
          ;; Plain propagator (NOT fire-once). All K propagators are
          ;; scheduled at install time; in BSP round 1 they all fire on
          ;; the initial cell snapshot, but only step-1's read sees its
          ;; pre-loaded input (t_0 = p). The other steps see [0,0,0,0]
          ;; for their input and write α·p. In round 2, step-2 sees its
          ;; correct (round-1) t_1 input and re-fires; but step-3,
          ;; step-4 still see stale (round-1) inputs. After K rounds
          ;; the chain has converged. Plain propagators (no fire-once)
          ;; re-fire on input changes — that's what makes the chain
          ;; settle. (Fire-once would fail at round 1.)
          (define-values (net** _pid)
            (net-add-propagator
             net*
             (list prev-cid m-cid p-cid alpha-cid)  ;; inputs
             (list next-cid)                        ;; outputs
             fire))
          (loop net** next-cid (add1 step))))))

;; End-to-end: build the network, run BSP to quiescence, return the
;; final trust vector. K = number of forced iterations.
(define (run-eigentrust-propagators m p alpha k)
  (define-values (net t-final-cid) (build-eigentrust-network m p alpha k))
  (define net* (run-to-quiescence-bsp net))
  (net-cell-read net* t-final-cid))


;; ============================================================
;; Fixtures — exact same matrices and vectors as the Prologos
;; benchmarks (rationals = Prologos Rat).
;; ============================================================

;; 4-peer ring: column j has a single 1 in row (j+1) mod 4.
;; Column-stochastic; sparse. The W3 fixture in the Prologos
;; benchmarks.
(define m-ring-4
  (vector
   (vector 0 0 0 1)
   (vector 1 0 0 0)
   (vector 0 1 0 0)
   (vector 0 0 1 0)))

;; All trust on peer 0.
(define p-seed-0 (vector 1 0 0 0))

;; 4-peer uniform — every entry 1/4. Doubly stochastic; uniform is
;; a fixed point.
(define m-uniform-4
  (let ([row (vector 1/4 1/4 1/4 1/4)])
    (vector row row row row)))

(define p-uniform-4 (vector 1/4 1/4 1/4 1/4))

;; 3-peer symmetric "uniform-on-others".
(define m-others-3
  (vector
   (vector  0  1/2 1/2)
   (vector 1/2  0  1/2)
   (vector 1/2 1/2  0)))

(define p-uniform-3 (vector 1/3 1/3 1/3))


;; ============================================================
;; Semantic note on iteration counts:
;;
;; The Prologos top-level `eigentrust` PRE-COMPUTES step 1 in its
;; entry expression and then runs `eigentrust-iterate` for max-iter
;; more steps. So `eigentrust m p α 0/1 3` performs 4 total step
;; calls. To match the W3 ring-4 fixture's expected result
;; [5401/10000, 21/100, 147/1000, 1029/10000], call this Racket
;; version with k = max-iter + 1 = 4.
;;
;; (We could embed this convention in the entry, but the K-step
;; semantics is what matters for benchmarking parity with the
;; Prologos `reduce_ms` measurements; documenting the offset is
;; less surprising than building it in.)
;; ============================================================

(module+ main
  ;; Smoke test on the ring-4 W3 workload.
  ;; Run via `racket benchmarks/comparative/eigentrust-propagators.rkt`.
  ;; k = max-iter + 1 = 4 to match the Prologos benchmark fixture.
  (define result (run-eigentrust-propagators m-ring-4 p-seed-0 3/10 4))
  (printf "ring-4 / α=3/10 / k=4 (max-iter+1):~n  ~s~n" result)
  ;; Sanity check — should equal the Prologos answer.
  (define expected
    (vector 5401/10000 21/100 147/1000 1029/10000))
  (unless (equal? result expected)
    (error 'main
           "result mismatch~n  expected: ~s~n  got: ~s"
           expected result))
  (printf "result matches Prologos surface variants ✓~n"))
