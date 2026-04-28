#lang racket/base

;;;
;;; PROPAGATOR-BASED EIGENTRUST — Racket FFI shim for Prologos.
;;;
;;; The user-facing pitch: Prologos plans first-class propagator support,
;;; but the type checker isn't yet wired through the surface forms in the
;;; grammar. This shim exposes the underlying primitives (`net-new`,
;;; `net-new-cell`, `net-add-prop`) directly via Racket FFI so a `.prologos`
;;; file can build and run a propagator network today.
;;;
;;; -----------------------------------------------------------------
;;; Mantra alignment (per .claude/rules/on-network.md)
;;;
;;;     "All-at-once, all in parallel, structurally emergent
;;;      information flow ON-NETWORK."
;;;
;;; This shim takes the mantra at face value:
;;;
;;;   * All-at-once   — each iteration is ONE compound cell holding the
;;;                     full score vector for all peers, allocated atomically
;;;                     (`net-new-cells-batch`, internally). The matrix /
;;;                     pretrust / decay configuration arrives as a single
;;;                     declarative payload.
;;;   * All in parallel — `net-add-prop` installs ONE broadcast propagator
;;;                     (per `.claude/rules/propagator-design.md` § Broadcast
;;;                     Propagators) covering all N peer-update items. The
;;;                     scheduler can decompose the broadcast across OS
;;;                     threads at fire time. NO N-propagator step-think,
;;;                     NO `for/fold` walking the peer list.
;;;   * Structurally emergent — the cell DAG is iter-0 → iter-1 → ... →
;;;                     iter-K. The BSP scheduler fires layers in
;;;                     topological order; we never tell it what fires when.
;;;   * ON-NETWORK    — every score lives in a cell. The compound carrier
;;;                     holds the full peer vector; merge keeps the higher
;;;                     generation so each layer's broadcast write strictly
;;;                     dominates the previous initial value.
;;;
;;; -----------------------------------------------------------------
;;; FFI surface (consumed from .prologos via `foreign racket "..."`):
;;;
;;;   net-new       : Posit32 -> Posit32
;;;       Allocate a fresh propagator network with the given fuel budget;
;;;       return a Posit32 handle id.
;;;
;;;   net-new-cell  : Posit32 -> List Posit32 -> Posit32
;;;       Allocate one compound cell holding a vector of Posit32 scores.
;;;       Return a Posit32 cell-ref.
;;;
;;;   net-add-prop  : Posit32 -> Posit32 -> Posit32
;;;                 -> List (List Posit32) -> List Posit32 -> Posit32
;;;                 -> Posit32
;;;       Install ONE broadcast propagator on the network whose fire-fn
;;;       implements one EigenTrust round:
;;;
;;;         t_{k+1}[j] = α · pretrust[j]
;;;                    + (1 − α) · Σ_i  C[i][j] · t_k[i]
;;;
;;;       Args: handle, input-cell, output-cell, matrix-rows (C in
;;;       row-major form), pretrust vector, decay α. Returns the
;;;       output-cell so callers can chain layers.
;;;
;;;   net-run-read  : Posit32 -> Posit32 -> List Posit32
;;;       Run the network to quiescence, then read the final layer's
;;;       compound cell as a Posit32 list. Combined into one call so the
;;;       Prologos call-by-name reduction has to evaluate the full layer
;;;       chain (forces every net-add-prop side effect) before the
;;;       quiescence pass starts.
;;;
;;; All "side-effecting" calls return a meaningful Posit32 (handle, cell
;;; ref, or score list) instead of Unit. Prologos's reduction is
;;; call-by-name — an unused result expression would never be evaluated and
;;; the side effect would be silently dropped. Threading a Posit32 through
;;; every call forces strict evaluation order.
;;;

(require racket/match
         racket/list
         racket/vector
         (rename-in "../../propagator.rkt"
                    [net-new-cell      raw-net-new-cell]
                    [net-add-broadcast-propagator raw-net-add-broadcast])
         "../../syntax.rkt"
         "../../posit-impl.rkt")

(provide
 net-new
 net-new-cell
 net-add-prop
 net-run-read)

;; ========================================
;; Handle registry — Posit32 carrier.
;; ========================================
;;
;; Posit32 represents small integers exactly within its range, so we use
;; the *bit pattern* of the encoded posit as the on-the-wire handle. The
;; Prologos surface sees Posit32 values; the registry side-table on the
;; Racket side maps decoded integer ids to mutable boxes holding the
;; persistent prop-network.

(struct et-net (box) #:transparent)

(define handle-registry (make-hasheqv))   ;; integer -> et-net
(define cell-registry   (make-hasheqv))   ;; integer -> cell-id (the prop-network's cell)
(define next-handle-id  (box 1))           ;; reserve 0 in case
(define next-cell-id    (box 1))

(define (id->posit32 i)         (posit32-encode i))
(define (posit32->id bits)      (inexact->exact (posit32-to-rational bits)))

;; ========================================
;; List helpers: walk WHNF cons/nil chains.
;; ========================================
;;
;; Foreign args are reduced to nf before marshalling, so List values arrive
;; as nested expr-app of expr-fvar 'cons (or qualified ::cons) terminating
;; in expr-nil / expr-fvar 'nil.

(define (cons-name? sym)
  (let ([s (symbol->string sym)])
    (or (string=? s "cons")
        (let ([n (string-length s)])
          (and (>= n 6) (string=? (substring s (- n 6)) "::cons"))))))

(define (nil-name? sym)
  (let ([s (symbol->string sym)])
    (or (string=? s "nil")
        (let ([n (string-length s)])
          (and (>= n 5) (string=? (substring s (- n 5)) "::nil"))))))

(define (try-cons-decomp e)
  (and (expr-app? e)
       (let ([func (expr-app-func e)]
             [tail (expr-app-arg e)])
         (and (expr-app? func)
              (let ([head  (expr-app-arg func)]
                    [inner (expr-app-func func)])
                (cond
                  [(and (expr-fvar? inner) (cons-name? (expr-fvar-name inner)))
                   (cons head tail)]
                  [(and (expr-app? inner)
                        (expr-fvar? (expr-app-func inner))
                        (cons-name? (expr-fvar-name (expr-app-func inner))))
                   (cons head tail)]
                  [else #f]))))))

(define (is-nil? e)
  (or (expr-nil? e)
      (and (expr-fvar? e) (nil-name? (expr-fvar-name e)))
      (and (expr-app? e)
           (let ([f (expr-app-func e)])
             (and (expr-fvar? f) (nil-name? (expr-fvar-name f)))))))

(define (prologos-list->list e)
  (let loop ([cur e] [acc '()])
    (cond
      [(is-nil? cur) (reverse acc)]
      [(try-cons-decomp cur)
       => (lambda (hd-tl) (loop (cdr hd-tl) (cons (car hd-tl) acc)))]
      [else (error 'eigentrust-prop
                   "list walk: not a list / not in WHNF: ~v" cur)])))

(define (list-of-posit32->bits-vec e)
  (define lst (prologos-list->list e))
  (for/vector #:length (length lst)
              ([x (in-list lst)])
    (match x
      [(expr-posit32 b) b]
      [_ (error 'eigentrust-prop "expected Posit32 in list, got ~v" x)])))

(define (matrix->vec-of-vecs e)
  (define rows (prologos-list->list e))
  (for/vector #:length (length rows)
              ([row (in-list rows)])
    (list-of-posit32->bits-vec row)))

(define (bits-vec->prologos-list bits-vec)
  (foldr (lambda (b acc)
           (expr-app (expr-app (expr-fvar 'cons) (expr-posit32 b)) acc))
         (expr-nil)
         (vector->list bits-vec)))

;; ========================================
;; Cell value: generation-tagged immutable vector of Posit32 bit patterns.
;;
;; The merge function keeps the entry with the higher generation. This is
;; CALM-monotone (joins commute / are associative / are idempotent) under
;; the usual correctness contract: each generation is written exactly
;; once, by exactly one propagator, in topological order.
;; ========================================

(struct gen-vec (gen vec) #:transparent)

(define (gen-merge old new)
  (cond
    [(not (gen-vec? old)) new]
    [(not (gen-vec? new)) old]
    [(> (gen-vec-gen new) (gen-vec-gen old)) new]
    [else old]))

(define (current-gen v)  (if (gen-vec? v) (gen-vec-gen v) -1))
(define (current-vec v)  (if (gen-vec? v) (gen-vec-vec v) #()))

;; ========================================
;; net-new — allocate a propagator network.
;; ========================================
;;
;; fuel-bits : Posit32 bit pattern for a small integer fuel budget.
;; Returns:    Posit32 bit pattern for the handle id.

(define (net-new fuel-bits)
  (define fuel-int
    (let ([r (posit32-to-rational fuel-bits)])
      (cond
        [(exact-integer? r) r]
        [(rational? r)      (inexact->exact (round r))]
        [else 1000000])))
  (define h (et-net (box (make-prop-network (max 1 fuel-int)))))
  (define id (unbox next-handle-id))
  (set-box! next-handle-id (+ id 1))
  (hash-set! handle-registry id h)
  (id->posit32 id))

(define (lookup-handle hbits)
  (define id (posit32->id hbits))
  (or (hash-ref handle-registry id #f)
      (error 'eigentrust-prop "no such network handle: ~a" id)))

;; ========================================
;; net-new-cell — allocate a compound cell.
;; ========================================
;;
;; Each cell holds a vector of Posit32 bit-patterns — the score for every
;; peer at one iteration, all bundled into one cell so the broadcast
;; propagator writes them atomically (mantra: all-at-once, on-network).
;;
;; init-bits-list : Prologos List Posit32 — initial score vector.
;; Returns         : Posit32 bit pattern encoding the cell-ref id.

(define (net-new-cell hbits init-bits-list)
  (define handle (lookup-handle hbits))
  (define init-vec (vector->immutable-vector (list-of-posit32->bits-vec init-bits-list)))
  (define net (unbox (et-net-box handle)))
  (define-values (net* cid)
    (raw-net-new-cell net (gen-vec 0 init-vec) gen-merge))
  (set-box! (et-net-box handle) net*)
  (define cref (unbox next-cell-id))
  (set-box! next-cell-id (+ cref 1))
  (hash-set! cell-registry cref cid)
  (id->posit32 cref))

(define (lookup-cell crefbits)
  (define cref (posit32->id crefbits))
  (or (hash-ref cell-registry cref #f)
      (error 'eigentrust-prop "no such cell-ref: ~a" cref)))

;; ========================================
;; net-add-prop — install ONE broadcast propagator for an EigenTrust round.
;; ========================================
;;
;; Per `.claude/rules/propagator-design.md` § Broadcast Propagators:
;; "any for/fold or for/list that processes independent items is a
;;  candidate for broadcast." This is exactly that — N peer updates that
;;  read the same prev-iter cell. The broadcast-profile metadata makes
;;  the propagator decomposable across OS threads (BSP-LE Track 2 Phase
;;  1B) when the scheduler chooses.
;;
;; input-cref  : prev iteration cell (compound, gen-vec carrier)
;; output-cref : next iteration cell (compound, gen-vec carrier)
;; matrix      : Prologos List (List Posit32) — row-major C
;; pretrust    : Prologos List Posit32        — p
;; decay-bits  : Posit32 bit pattern          — α
;; Returns     : output-cref (chains).

(define (net-add-prop hbits input-cref output-cref matrix pretrust decay-bits)
  (define handle    (lookup-handle hbits))
  (define input-cid (lookup-cell input-cref))
  (define out-cid   (lookup-cell output-cref))
  (define C-rows    (matrix->vec-of-vecs matrix))
  (define p-bits    (list-of-posit32->bits-vec pretrust))
  (define n         (vector-length p-bits))
  (unless (= n (vector-length C-rows))
    (error 'net-add-prop "matrix outer length ~a != peer count ~a"
           (vector-length C-rows) n))
  (for ([row (in-vector C-rows)] [i (in-naturals)])
    (unless (= n (vector-length row))
      (error 'net-add-prop "matrix row ~a has ~a entries, expected ~a"
             i (vector-length row) n)))
  (define decay-rat   (posit32-to-rational decay-bits))
  (define one-m-decay (- 1 decay-rat))
  (define p-rats      (for/vector ([b (in-vector p-bits)]) (posit32-to-rational b)))
  ;; Pre-compute, in exact rationals, the per-target weights and bias.
  ;;   weights[j][i] = (1 - α) · C[i][j]
  ;;   bias[j]       = α · p[j]
  (define weights
    (for/vector ([j (in-range n)])
      (for/vector ([i (in-range n)])
        (* one-m-decay
           (posit32-to-rational (vector-ref (vector-ref C-rows i) j))))))
  (define biases
    (for/vector ([j (in-range n)]) (* decay-rat (vector-ref p-rats j))))
  ;; --- Broadcast propagator: ONE install, N items, parallel-decomposable.
  ;; items: peer indices 0..N-1.
  (define items (build-list n values))
  ;; item-fn: per-peer update. Reads the (single) prev-iter compound cell,
  ;; computes t_{k+1}[j], returns (input-gen, j, bits). The input-gen
  ;; tag lets the next-layer's gen exceed it so re-fires (after the input
  ;; cell evolves) strictly dominate stale fires.
  (define (item-fn j input-vals)
    (define prev-cell-val (car input-vals))
    (define prev          (current-vec prev-cell-val))
    (define input-gen     (current-gen prev-cell-val))
    (define wts  (vector-ref weights j))
    (define bias (vector-ref biases j))
    (define sum
      (for/fold ([acc bias]) ([w (in-vector wts)] [b (in-vector prev)])
        (+ acc (* w (posit32-to-rational b)))))
    (list input-gen j (posit32-encode sum)))
  ;; result-merge: accumulate per-peer results into a gen-vec carrier
  ;; whose gen is input-gen + 1. Gen-merge then keeps the latest fire when
  ;; the input cell evolves across BSP rounds.
  (define (final-merge acc r)
    (define input-gen (car r))
    (define j         (cadr r))
    (define bits      (caddr r))
    (define base
      (cond
        [(gen-vec? acc) (vector-copy (gen-vec-vec acc))]
        [else           (make-vector n 0)]))
    (vector-set! base j bits)
    (gen-vec (+ 1 input-gen) (vector->immutable-vector base)))
  (define net0 (unbox (et-net-box handle)))
  (define-values (net* _pid)
    (raw-net-add-broadcast net0 (list input-cid) out-cid
                           items item-fn final-merge))
  (set-box! (et-net-box handle) net*)
  output-cref)

;; ========================================
;; net-run-read — flush the network and snapshot a cell's vector.
;; ========================================
;;
;; The single FFI call forces strict evaluation of `output-cref` before
;; running, so the entire chain of net-add-prop side effects has fired
;; by the time run-to-quiescence runs.

(define (net-run-read hbits cref)
  (define handle (lookup-handle hbits))
  (define cid    (lookup-cell cref))
  (define net0 (unbox (et-net-box handle)))
  (define net* (run-to-quiescence net0))
  (set-box! (et-net-box handle) net*)
  (define final-vec (current-vec (net-cell-read net* cid)))
  (bits-vec->prologos-list final-vec))
