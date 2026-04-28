#lang racket/base

;;;
;;; PROPAGATOR-BASED EIGENTRUST — minimal Racket FFI shim.
;;;
;;; This module is the irreducible Racket-side plumbing. Prologos plans
;;; first-class propagator support, but the type checker isn't yet wired
;;; through the surface forms in the grammar; until then, the four
;;; propagator-network primitives below are exposed via `foreign racket
;;; "..."`. Everything else — the EigenTrust-specific algorithm, INCLUDING
;;; the per-step affine kernel — lives in the .prologos source.
;;;
;;; -----------------------------------------------------------------
;;; What MUST stay in Racket (the irreducible core):
;;;
;;;   1. The cell-value carrier (gen-tagged immutable Posit32 vector) and
;;;      its monotone merge — both Racket data structures.
;;;   2. The persistent prop-network struct, handle/cell registries.
;;;   3. FFI marshalling: list walking on cons/nil chains, posit
;;;      bit-pattern extraction, IR list construction.
;;;
;;; What MOVED out, into the .prologos source:
;;;
;;;   1. Matrix transpose
;;;   2. Decay scaling   (1 − α) · C
;;;   3. Bias computation  α · pretrust
;;;   4. Initial-zero vector for new-layer cells
;;;   5. The iteration driver
;;;   6. **The per-step affine kernel itself.**  net-add-prop now takes
;;;      a Prologos lambda  step : List Posit32 → List Posit32  via FFI
;;;      callback (per docs/tracking/2026-04-28_FFI_LAMBDA_PASSING.md);
;;;      the propagator's fire-fn just plumbs the cell value through it.
;;;
;;; -----------------------------------------------------------------
;;; Mantra alignment (per .claude/rules/on-network.md)
;;;
;;;     "All-at-once, all in parallel, structurally emergent
;;;      information flow ON-NETWORK."
;;;
;;;   * All-at-once   — each iteration is ONE compound cell holding the
;;;                     full score vector for all peers.
;;;   * All in parallel — the cell DAG iter-0 → iter-1 → ... → iter-K is
;;;                     fired by the BSP scheduler. Per-component
;;;                     parallelism within a layer is a Prologos-side
;;;                     concern (the kernel's reduction order); the
;;;                     architectural shape preserves the option.
;;;   * Structurally emergent — the cell DAG drives firing order via
;;;                     dataflow; we never tell the scheduler what fires
;;;                     when.
;;;   * ON-NETWORK    — every score lives in a cell.
;;;
;;; -----------------------------------------------------------------
;;; FFI surface (consumed from .prologos via `foreign racket "..."`):
;;;
;;;   net-new       : Posit32 -> Posit32
;;;       Allocate a propagator network with the given fuel budget; return
;;;       a Posit32 handle id.
;;;
;;;   net-new-cell  : Posit32 -> Posit32 -> List Posit32 -> Posit32
;;;       Allocate ONE compound cell holding the given Posit32 vector.
;;;       The second arg is a freshness tag (any Posit32) — used only to
;;;       disambiguate the call AST so Prologos's per-command whnf-cache
;;;       doesn't collapse multiple distinct allocations onto the same
;;;       cell ref (see ETPROP_PITFALLS § "FFI-call AST caching"
;;;       complementing pitfall #1). Returns a Posit32 cell-ref.
;;;
;;;   net-add-prop  : Posit32 -> Posit32 -> Posit32
;;;                 -> [List [List Posit32]] -> [List Posit32]
;;;                 -> [[List Posit32] [List Posit32] Posit32 -> Posit32]
;;;                 -> Posit32
;;;       Install ONE broadcast propagator. Args:
;;;          handle, input-cell, output-cell, weights, biases, kernel
;;;       The kernel is a Prologos lambda invoked once per peer per fire,
;;;       computing
;;;          out[j]  :=  kernel(prev_vec, weights[j], biases[j])
;;;       Domain-AGNOSTIC: the .prologos caller supplies the kernel as a
;;;       Prologos lambda; the EigenTrust-specific math (affine kernel,
;;;       matrix transpose, decay weighting) lives in Prologos. Returns
;;;       output-cell so layers can be chained.
;;;
;;;   net-run-read  : Posit32 -> Posit32 -> List Posit32
;;;       Run the network to quiescence, then read the cell as a Posit32
;;;       list. Combined so call-by-name reduction is forced to evaluate
;;;       the full layer chain before the quiescence pass.
;;;
;;; All "side-effecting" calls return a meaningful Posit32 (handle, cell
;;; ref, or score list) instead of Unit. Prologos's reduction is
;;; call-by-name — an unused result expression would never be evaluated
;;; and the side effect would be silently dropped. Threading a Posit32
;;; through every call forces strict evaluation order.
;;;

(require racket/match
         racket/list
         racket/vector
         (rename-in "../../propagator.rkt"
                    [net-new-cell                 raw-net-new-cell]
                    [net-add-broadcast-propagator raw-net-add-broadcast]
                    [net-cell-read                raw-net-cell-read]
                    [net-cell-write               raw-net-cell-write])
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
;; tag-bits        : Posit32 freshness tag — ignored functionally.
;;                   Required to disambiguate the call AST so Prologos's
;;                   per-command whnf-cache doesn't collapse multiple
;;                   distinct net-new-cell calls onto the same cell ref
;;                   (see ETPROP_PITFALLS § "def is reference-transparent
;;                   — side effects re-fire on every use" and the
;;                   complementary "FFI calls with identical args hit the
;;                   whnf-cache and side-effects collapse"). Pass any
;;                   varying Posit32 — typically the previous iter's
;;                   cell-ref (which IS Posit32 and IS unique per layer).
;; init-bits-list  : Prologos List Posit32 — initial score vector.
;; Returns         : Posit32 bit pattern encoding the cell-ref id.

(define (net-new-cell hbits tag-bits init-bits-list)
  (define handle (lookup-handle hbits))
  (define _ tag-bits)  ;; consumed for AST disambiguation; otherwise unused.
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
;; net-add-prop — install ONE broadcast propagator whose per-component
;; computation is a Prologos lambda passed across the FFI.
;; ========================================
;;
;; Per `.claude/rules/propagator-design.md` § Broadcast Propagators:
;; "any for/fold or for/list that processes independent items is a
;;  candidate for broadcast." Each row j of the next-iter cell is
;; computed independently from the previous-iter cell — exactly the
;; broadcast pattern. The Racket side enumerates the items and assembles
;; the result; the per-component arithmetic IS in the Prologos kernel.
;;
;;   for each item j  in 0..N-1:
;;       out[j]  :=  kernel(prev_vec, weights[j], biases[j])
;;
;; Everything domain-specific is in the .prologos source:
;;   * weights, biases — passed as DATA (List Posit32 / List (List Posit32)).
;;     Pre-reduced by the FFI marshaller's nf pass on entry.
;;   * kernel — passed as a Prologos LAMBDA (FFI callback bridge).
;;
;; This keeps the closure footprint minimal: the kernel doesn't capture
;; weights / biases (they're handed in by row from the broadcast loop),
;; so each kernel invocation reduces a tiny applied form rather than
;; re-reducing the whole transpose+scale precomputation. Mantra-aligned:
;; the broadcast profile makes the per-item work parallel-decomposable
;; across OS threads at fire time (BSP-LE Track 2 Phase 1B).
;;
;; Returns output-cref so the caller can chain net-add-prop calls.

(define (net-add-prop hbits input-cref output-cref weights-list biases-list kernel)
  (define handle    (lookup-handle hbits))
  (define input-cid (lookup-cell input-cref))
  (define out-cid   (lookup-cell output-cref))
  (define W-rows    (matrix->vec-of-vecs weights-list))
  (define b-bits    (list-of-posit32->bits-vec biases-list))
  (define n         (vector-length b-bits))
  (unless (= n (vector-length W-rows))
    (error 'net-add-prop "weights outer length ~a != biases length ~a"
           (vector-length W-rows) n))
  (for ([row (in-vector W-rows)] [j (in-naturals)])
    (unless (= n (vector-length row))
      (error 'net-add-prop "weights row ~a has ~a entries, expected ~a"
             j (vector-length row) n)))
  (unless (procedure? kernel)
    (error 'net-add-prop "kernel must be a procedure (Prologos lambda), got: ~v" kernel))
  ;; Pre-build per-row IR Lists — this is constant work per propagator
  ;; install (NOT per fire). Each fire reuses the same row Lists.
  (define W-rows-as-ir
    (for/vector ([row (in-vector W-rows)])
      (bits-vec->prologos-list row)))
  ;; Items: peer indices. The Prologos kernel handles the actual math.
  (define items (build-list n values))
  (define (item-fn j input-vals)
    (define prev-cell-val (car input-vals))
    (define prev-vec      (current-vec prev-cell-val))
    (define input-gen     (current-gen prev-cell-val))
    (define prev-list-ir  (bits-vec->prologos-list prev-vec))
    (define wts-list-ir   (vector-ref W-rows-as-ir j))
    (define bias-bits     (vector-ref b-bits j))
    ;; >>>>> Cross the FFI: invoke the Prologos per-row kernel.
    ;;       kernel : prev × wts × bias-bits  ->  result-bits
    (define result-bits (kernel prev-list-ir wts-list-ir bias-bits))
    ;; <<<<< Back from Prologos.
    (list input-gen j result-bits))
  ;; result-merge: accumulate per-component results into a gen-vec carrier
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
  (define final-vec (current-vec (raw-net-cell-read net* cid)))
  (bits-vec->prologos-list final-vec))
