#lang racket/base

;;;
;;; PROPAGATOR-BASED EIGENTRUST — minimal Racket FFI shim.
;;;
;;; Following the FFI marshalling extension (List/Posit/Int) and the
;;; lambda-passing track, this module is now ~3× smaller than its
;;; pre-refactor form. The marshaller in foreign.rkt centrally handles:
;;;
;;;   * `[List Posit32]`        ↔  Racket list of exact rationals
;;;   * `[List [List Posit32]]` ↔  Racket list of lists of exact rationals
;;;   * Posit32                 ↔  exact rational
;;;   * `[A -> B]` arg position ↔  Racket procedure that bridges back
;;;                                 into the Prologos reducer (FFI lambda
;;;                                 passing track).
;;;
;;; …so this shim no longer hand-walks cons/nil chains, no longer
;;; constructs IR list nodes, and no longer extracts Posit32 bit
;;; patterns. The FFI carries semantic values (rationals, lists)
;;; directly across the boundary.
;;;
;;; -----------------------------------------------------------------
;;; What MUST stay in Racket (the irreducible plumbing):
;;;
;;;   1. The cell-value carrier (gen-tagged immutable rational vector)
;;;      and its monotone merge — the propagator network's API requires
;;;      a Racket procedure as the merge-fn (called on every cell
;;;      write, in the network's hot path).
;;;   2. The persistent prop-network struct, handle/cell registries.
;;;   3. The propagator's fire-fn — a Racket closure invoked by the BSP
;;;      scheduler that reads the input cell, calls the Prologos kernel
;;;      via the FFI bridge, and writes the output cell. Pure plumbing,
;;;      no algorithmic content.
;;;
;;; What lives in Prologos (the entire algorithm):
;;;
;;;   * Matrix transpose, decay scaling, bias computation
;;;   * The per-row affine kernel itself (passed across the FFI as a
;;;     Prologos lambda on each net-add-prop install)
;;;   * Initial-zero vector, iteration driver
;;;
;;; -----------------------------------------------------------------
;;; Mantra alignment (per .claude/rules/on-network.md)
;;;
;;;     "All-at-once, all in parallel, structurally emergent
;;;      information flow ON-NETWORK."
;;;
;;;   * All-at-once   — each iteration is ONE compound cell holding the
;;;                     full score vector for all peers.
;;;   * All in parallel — `net-add-prop` installs ONE broadcast
;;;                     propagator (per .claude/rules/propagator-design.md
;;;                     § Broadcast Propagators) covering all N peer
;;;                     updates as items.
;;;   * Structurally emergent — the cell DAG iter-0 → iter-1 → … →
;;;                     iter-K drives firing order via dataflow.
;;;   * ON-NETWORK    — every score lives in a cell.
;;;
;;; -----------------------------------------------------------------
;;; FFI surface (consumed from .prologos via `foreign racket "..."`):
;;;
;;;   net-new       : Posit32 -> Posit32
;;;       Allocate a propagator network with the given fuel budget;
;;;       return a Posit32 handle id.
;;;
;;;   net-new-cell  : Posit32 -> Posit32 -> [List Posit32] -> Posit32
;;;       Allocate ONE compound cell holding the given Posit32 vector.
;;;       The second arg is a freshness tag — any varying Posit32, used
;;;       only to disambiguate the call AST so Prologos's per-command
;;;       whnf-cache doesn't collapse multiple distinct allocations
;;;       onto the same cell ref. Returns a Posit32 cell-ref.
;;;
;;;   net-add-prop  : Posit32 -> Posit32 -> Posit32
;;;                 -> [List [List Posit32]] -> [List Posit32]
;;;                 -> [[List Posit32] [List Posit32] Posit32 -> Posit32]
;;;                 -> Posit32
;;;       Install ONE broadcast propagator. Args:
;;;          handle, input-cell, output-cell, weights, biases, kernel
;;;       The kernel is a Prologos lambda invoked once per peer per
;;;       fire, computing
;;;          out[j]  :=  kernel(prev_vec, weights[j], biases[j])
;;;       Returns output-cell so layers can be chained.
;;;
;;;   net-run-read  : Posit32 -> Posit32 -> [List Posit32]
;;;       Run the network to quiescence, then read the cell as a list
;;;       of Posit32. Combined so call-by-name reduction is forced to
;;;       evaluate the full layer chain before the quiescence pass.
;;;

(require racket/list
         racket/vector
         (rename-in "../../propagator.rkt"
                    [net-new-cell                 raw-net-new-cell]
                    [net-add-broadcast-propagator raw-net-add-broadcast]
                    [net-cell-read                raw-net-cell-read]
                    [net-cell-write               raw-net-cell-write]))

(provide net-new
         net-new-cell
         net-add-prop
         net-run-read)

;; ========================================
;; Handle / cell registries.
;; ========================================
;;
;; FFI marshalling exposes Posit32 args/returns as exact rationals. Small
;; non-negative integers (handle ids, cell-refs) are exactly representable
;; in Posit32, so we use them directly as registry keys after rounding to
;; defend against any rounding noise on roundtrip.

(struct et-net (box) #:transparent)

(define handle-registry (make-hasheqv))
(define cell-registry   (make-hasheqv))
(define next-handle-id  (box 1))
(define next-cell-id    (box 1))

(define (rat->id r) (inexact->exact (round r)))

(define (lookup-handle hid)
  (or (hash-ref handle-registry (rat->id hid) #f)
      (error 'eigentrust-prop "no such network handle: ~a" hid)))

(define (lookup-cell cid)
  (or (hash-ref cell-registry (rat->id cid) #f)
      (error 'eigentrust-prop "no such cell-ref: ~a" cid)))

;; ========================================
;; Cell value carrier — gen-tagged immutable rational vector.
;;
;; gen-merge keeps the entry with the higher generation. CALM-monotone
;; under the usual contract: each generation is written exactly once,
;; in topological order driven by the cell DAG. The gen tag rises as
;; data propagates layer-to-layer, so re-fires after the input cell
;; evolves strictly dominate stale fires.
;; ========================================

(struct gen-vec (gen vec) #:transparent)

(define (gen-merge old new)
  (cond
    [(not (gen-vec? old)) new]
    [(not (gen-vec? new)) old]
    [(> (gen-vec-gen new) (gen-vec-gen old)) new]
    [else old]))

(define (current-gen v) (if (gen-vec? v) (gen-vec-gen v) -1))
(define (current-vec v) (if (gen-vec? v) (gen-vec-vec v) #()))

;; ========================================
;; Public FFI surface.
;; ========================================

(define (net-new fuel-rat)
  (define fuel-int (max 1 (rat->id fuel-rat)))
  (define h (et-net (box (make-prop-network fuel-int))))
  (define id (unbox next-handle-id))
  (set-box! next-handle-id (+ id 1))
  (hash-set! handle-registry id h)
  id)

;; The FFI marshaller delivers init-list as a Racket list of exact
;; rationals (one per Posit32 element of the Prologos List). The
;; freshness tag (Posit32) is ignored functionally; it's there only to
;; disambiguate the call AST so the per-command whnf-cache doesn't
;; collapse multiple distinct allocations onto the same cell ref. See
;; ETPROP_PITFALLS § "FFI-call AST caching".
(define (net-new-cell hid _tag init-list)
  (define handle (lookup-handle hid))
  (define init-vec (vector->immutable-vector (list->vector init-list)))
  (define net (unbox (et-net-box handle)))
  (define-values (net* cid)
    (raw-net-new-cell net (gen-vec 0 init-vec) gen-merge))
  (set-box! (et-net-box handle) net*)
  (define cref (unbox next-cell-id))
  (set-box! next-cell-id (+ cref 1))
  (hash-set! cell-registry cref cid)
  cref)

;; The fire-fn here is the irreducible Racket plumbing: it reads the
;; input compound cell's gen-tagged rational vector, dispatches to the
;; broadcast item-fn for each peer, and the broadcast machinery merges
;; per-peer results into a fresh gen-vec written to the output cell.
;; The per-peer arithmetic (the affine combination) is in the Prologos
;; kernel passed across the FFI; the wrapper marshals our Racket-side
;; (List Posit32 / Posit32) args back into Prologos IR, runs `nf`, and
;; returns the resulting rational.
(define (net-add-prop hid input-cref output-cref weights biases kernel)
  (define handle    (lookup-handle hid))
  (define input-cid (lookup-cell input-cref))
  (define out-cid   (lookup-cell output-cref))
  ;; weights / biases arrive as Racket lists of exact rationals (the
  ;; marshaller did all the cons/nil walking + Posit32 decoding for us).
  (define W (list->vector (map list->vector weights)))
  (define b (list->vector biases))
  (define n (vector-length b))
  (unless (= n (vector-length W))
    (error 'net-add-prop "weights outer length ~a != biases length ~a"
           (vector-length W) n))
  (for ([row (in-vector W)] [j (in-naturals)])
    (unless (= n (vector-length row))
      (error 'net-add-prop "weights row ~a has ~a entries, expected ~a"
             j (vector-length row) n)))
  (unless (procedure? kernel)
    (error 'net-add-prop "kernel must be a procedure (Prologos lambda), got: ~v" kernel))
  ;; --- Broadcast propagator: ONE install, N items, parallel-decomposable.
  (define items (build-list n values))
  (define (item-fn j input-vals)
    (define prev-cell-val (car input-vals))
    (define prev          (current-vec prev-cell-val))
    (define input-gen     (current-gen prev-cell-val))
    ;; >>>>> Cross the FFI: invoke the Prologos per-row kernel.
    ;;       kernel : prev-list × wts-list × bias  ->  result-rat
    (define result-rat
      (kernel (vector->list prev)
              (vector->list (vector-ref W j))
              (vector-ref b j)))
    ;; <<<<< Back from Prologos.
    (list input-gen j result-rat))
  ;; result-merge: accumulate per-component results into a gen-vec
  ;; carrier whose gen is input-gen + 1.
  (define (final-merge acc r)
    (define input-gen (car r))
    (define j         (cadr r))
    (define rat       (caddr r))
    (define base
      (cond
        [(gen-vec? acc) (vector-copy (gen-vec-vec acc))]
        [else           (make-vector n 0)]))
    (vector-set! base j rat)
    (gen-vec (+ 1 input-gen) (vector->immutable-vector base)))
  (define net0 (unbox (et-net-box handle)))
  (define-values (net* _pid)
    (raw-net-add-broadcast net0 (list input-cid) out-cid
                           items item-fn final-merge))
  (set-box! (et-net-box handle) net*)
  output-cref)

;; The FFI marshaller will turn our returned Racket list of rationals
;; into a Prologos List Posit32 (encoding each rational as a Posit32 bit
;; pattern) — see foreign.rkt's `[(List _) ...]` and `[(Posit32) ...]`
;; output-marshal cases.
(define (net-run-read hid cref)
  (define handle (lookup-handle hid))
  (define cid    (lookup-cell cref))
  (define net0 (unbox (et-net-box handle)))
  (define net* (run-to-quiescence net0))
  (set-box! (et-net-box handle) net*)
  (vector->list (current-vec (raw-net-cell-read net* cid))))
