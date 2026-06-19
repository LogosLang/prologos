#lang racket/base

;;; eigentrust-propagators-fine.rkt — fine-grained per-peer variant.
;;;
;;; Whereas the coarse variant (eigentrust-propagators.rkt) holds an
;;; entire trust vector in one cell per iteration, the fine-grained
;;; variant holds ONE cell PER PEER PER ITERATION. For W3 (n=4 peers,
;;; K=4 steps) that's 16 trust cells + 4 constant cells = 20 cells,
;;; and 16 propagators (one per (k, i) pair). Each peer-i propagator
;;; at step k reads (M[i,:], p[i], alpha, t_{k-1, 0..n-1}) — n+3
;;; inputs — and writes one peer-trust value `t_{k, i}`.
;;;
;;; This is "more on-network": each peer's evolving trust value is
;;; its own cell with its own propagator. Within a single iteration
;;; round, the n peer propagators are independent and can be fired
;;; in parallel by the BSP scheduler.
;;;
;;; Trade-off vs coarse: more cell allocations and propagator-fire
;;; bookkeeping; smaller per-fire work. For small n the coarse
;;; variant wins on constants; for larger n (or with parallel BSP
;;; execution) the fine variant should pull ahead.

(require "../../propagator.rkt"
         "eigentrust-propagators.rkt"
         (only-in racket/list last))

(provide
 build-eigentrust-network-fine
 run-eigentrust-propagators-fine)

;; ============================================================
;; Per-peer kernel: t_{k, i} = (1-α) · sum_j M[i,j] · t_{k-1, j} + α · p[i]
;; ============================================================

;; Compute t_{k, i} given the previous full trust vector,
;; the matrix row M[i,:], pre-trust scalar p[i], and alpha.
;; This is the off-network kernel each per-peer propagator runs.
(define (peer-step-kernel m-row p-i alpha t-prev)
  (define n (vector-length m-row))
  (define dot
    (for/fold ([acc 0]) ([j (in-range n)])
      (+ acc (* (vector-ref m-row j) (vector-ref t-prev j)))))
  (+ (* (- 1 alpha) dot)
     (* alpha p-i)))

;; ============================================================
;; Network construction
;;
;; Layout:
;;   t-cids: vector of (vector cell-id) of shape K+1 × n
;;     t-cids[0][i] = cell holding t_{0, i} = p[i]
;;     t-cids[k][i] = cell holding t_{k, i} (computed by step-(k,i))
;;   m-cid, p-cid, alpha-cid: constant cells (lww merge).
;;
;; Each step-(k,i) propagator reads:
;;   - t-cids[k-1][0..n-1] (n inputs)
;;   - m-cid, p-cid, alpha-cid (3 inputs)
;; And writes:
;;   - t-cids[k][i] (1 output)
;; ============================================================

(define (lww old new) new)

(define (build-eigentrust-network-fine m p alpha k)
  (unless (col-stochastic? m)
    (error 'build-eigentrust-network-fine "M must be column-stochastic"))
  (define n (vector-length p))
  ;; Constant cells
  (define net0 (make-prop-network))
  (define-values (net1 m-cid)     (net-new-cell net0     m     lww))
  (define-values (net2 p-cid)     (net-new-cell net1     p     lww))
  (define-values (net3 alpha-cid) (net-new-cell net2     alpha lww))
  ;; Allocate (K+1) × n trust cells.
  ;; Row 0: pre-loaded with p[i].
  ;; Rows 1..K: pre-loaded with 0; written by their step propagator.
  (define t-cids (make-vector (add1 k) #f))
  (let-values ([(net4 row0)
                (let alloc ([net net3] [i 0] [acc '()])
                  (if (>= i n)
                      (values net (list->vector (reverse acc)))
                      (let-values ([(net* cid) (net-new-cell net (vector-ref p i) lww)])
                        (alloc net* (add1 i) (cons cid acc)))))])
    (vector-set! t-cids 0 row0)
    ;; Allocate t-cids[1..K]
    (let row-alloc ([net net4] [step 1])
      (if (> step k)
          (build-prop-chain net t-cids m-cid p-cid alpha-cid k n)
          (let-values ([(net* row)
                        (let alloc ([net net] [i 0] [acc '()])
                          (if (>= i n)
                              (values net (list->vector (reverse acc)))
                              (let-values ([(net* cid) (net-new-cell net 0 lww)])
                                (alloc net* (add1 i) (cons cid acc)))))])
            (vector-set! t-cids step row)
            (row-alloc net* (add1 step)))))))

;; Install the K·n peer-step propagators. Returns (values net last-row-cids).
(define (build-prop-chain net t-cids m-cid p-cid alpha-cid k n)
  (let step-loop ([net net] [step 1])
    (if (> step k)
        (values net (vector-ref t-cids k))
        (let ([prev-row (vector-ref t-cids (sub1 step))]
              [next-row (vector-ref t-cids step)])
          ;; For each peer i, install propagator step-(k=step, i).
          (let peer-loop ([net net] [i 0])
            (if (>= i n)
                (step-loop net (add1 step))
                (let ()
                  ;; Fire function reads M (full matrix) once and indexes
                  ;; row i; reads p[i]; reads alpha; reads each t_{step-1, j}.
                  ;; CRITICAL: capture i (and prev-row, next-row) by value
                  ;; via the let binding here, NOT by reference to step-loop's
                  ;; mutable index.
                  (define peer-idx i)
                  (define prev-cids prev-row)
                  (define next-cid (vector-ref next-row peer-idx))
                  (define (fire net-param)
                    (define m-val (net-cell-read net-param m-cid))
                    (define p-val (net-cell-read net-param p-cid))
                    (define alpha-val (net-cell-read net-param alpha-cid))
                    ;; Build the previous trust vector by reading each
                    ;; per-peer cell (n cell reads).
                    (define t-prev
                      (for/vector #:length n ([j (in-range n)])
                        (net-cell-read net-param (vector-ref prev-cids j))))
                    (define m-row (vector-ref m-val peer-idx))
                    (define p-i (vector-ref p-val peer-idx))
                    (define t-i (peer-step-kernel m-row p-i alpha-val t-prev))
                    (net-cell-write net-param next-cid t-i))
                  ;; Inputs: ALL n cells of the previous row + 3 constants.
                  (define inputs
                    (cons m-cid (cons p-cid (cons alpha-cid
                      (for/list ([j (in-range n)])
                        (vector-ref prev-cids j))))))
                  (define-values (net** _pid)
                    (net-add-propagator
                     net inputs (list next-cid) fire))
                  (peer-loop net** (add1 i)))))))))


;; End-to-end: build, run BSP, gather final per-peer cells into a
;; vector. Result has shape (vector Rat₀ Rat₁ ... Ratₙ₋₁) — same
;; shape as the coarse variant for direct comparison.
(define (run-eigentrust-propagators-fine m p alpha k)
  (define-values (net last-row-cids) (build-eigentrust-network-fine m p alpha k))
  (define net* (run-to-quiescence-bsp net))
  (define n (vector-length p))
  (for/vector #:length n ([j (in-range n)])
    (net-cell-read net* (vector-ref last-row-cids j))))


;; ============================================================
;; Module main: smoke test against the coarse variant's golden output
;; ============================================================

(module+ main
  (define result (run-eigentrust-propagators-fine m-ring-4 p-seed-0 3/10 4))
  (printf "fine ring-4 / α=3/10 / k=4:~n  ~s~n" result)
  (define expected (vector 5401/10000 21/100 147/1000 1029/10000))
  (unless (equal? result expected)
    (error 'main "fine variant mismatch~n  expected: ~s~n  got: ~s"
           expected result))
  (printf "fine result matches coarse + Prologos surface variants ✓~n"))
