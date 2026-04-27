#lang racket/base

;;;
;;; PROPAGATOR-BASED EIGENTRUST — Racket FFI shim for Prologos.
;;;
;;; The user-facing pitch: Prologos plans to make Propagators a first-class
;;; language construct (not just compiler infrastructure). That work hasn't
;;; landed yet, so this module exposes the underlying propagator network
;;; primitives via Racket FFI so that algorithms like EigenTrust can be
;;; written in `.prologos` files using `foreign racket "..."` imports.
;;;
;;; The functions exported here wrap the persistent (immutable) prop-network
;;; in a small mutable handle (`et-net`) so Prologos sees a stateful API:
;;;
;;;   et-new        : Nat -> Nat                                  ; returns a fresh handle id
;;;   et-cell       : Nat -> Posit32 -> Nat                       ; allocates a cell, returns id
;;;   et-cell-get   : Nat -> Nat -> Posit32                       ; read score
;;;   et-cell-set   : Nat -> Nat -> Posit32 -> Nat                ; returns cell-id (chains)
;;;   et-sum-prop   : Nat -> List Nat -> List Posit32 -> Posit32 -> Nat -> Nat
;;;                   ; installs target := bias + Σ (weight_i * src_i); returns handle (chains)
;;;   et-run        : Nat -> Nat                                  ; runs to quiescence; returns handle
;;;   et-snapshot   : Nat -> List Nat -> List Posit32             ; read many cells
;;;
;;; Note that the "side-effecting" calls (cell-set, sum-prop, run) return a
;;; meaningful Nat — typically the handle or a relevant cell-id — instead of
;;; Unit. Prologos's reduction is call-by-name; an unused result expression
;;; would never be evaluated and the side effect would be silently dropped.
;;; Threading a Nat through every call forces strict evaluation order.
;;;
;;; The first argument of every operation (other than et-new) is a handle id
;;; — a non-negative integer returned by et-new. The Racket side keeps a
;;; private registry of network boxes keyed by id, so Prologos sees normal
;;; Nat values throughout and the propagator network mutates under the hood.
;;;
;;; The cell merge function is monotone-by-generation: each cell holds a
;;; (gen . posit-bits) pair and the merge keeps the entry with the higher
;;; generation. Iteration k+1 cells are generation k+1; this lets EigenTrust's
;;; non-monotone power iteration cooperate with the CALM-monotone propagator
;;; network — every cell is written at most once per round, ordered by
;;; data-dependency rather than imperative control flow.
;;;
;;; For Prologos, all numeric scoring happens in Posit32 (32-bit posits, 2022
;;; standard, es=2). The bit pattern is the FFI carrier; this module converts
;;; to/from exact rationals internally for the dot-product math.
;;;

(require racket/match
         "../../propagator.rkt"
         "../../syntax.rkt"
         "../../posit-impl.rkt")

(provide
 et-new
 et-cell
 et-cell-get
 et-cell-set
 et-sum-prop
 et-run
 et-snapshot
 et-run-and-snapshot
 ;; Higher-level operation that Prologos can compose recursively to drive
 ;; the EigenTrust power iteration: given the previous iteration's cells,
 ;; allocate a fresh layer of cells and install one sum-propagator per peer
 ;; that computes t_{k+1}[j] = α·p[j] + (1-α) · Σ_i C[i][j]·t_k[i].
 et-add-iter
 ;; Convenience for Prologos: encode/decode Posit32 ↔ Rat so that user code
 ;; can construct posit constants without going through literal sugar.
 et-rat->posit32
 et-posit32->rat)

;; ========================================
;; Handle: integer id into a Racket-side registry of mutable network boxes.
;; ========================================
;;
;; Prologos's foreign FFI marshals user-defined types as Passthrough — the IR
;; value is the Racket value. That works for primitives but breaks reduction
;; (whnf/nf) when a non-IR Racket struct flows through arbitrary Prologos
;; expressions. Returning a `Nat` handle keeps every foreign value an honest
;; IR Nat, and the registry side-table lookups happen entirely on the Racket
;; side.

(struct et-net (box) #:transparent)

(define handle-registry (make-hasheqv))     ;; integer -> et-net
(define next-handle-id (box 0))

(define (lookup-handle id)
  (define h (hash-ref handle-registry id #f))
  (unless h (error 'eigentrust-prop "no such EigenTrust handle: ~a" id))
  h)

(define (et-new fuel)
  (define h (et-net (box (make-prop-network (max fuel 1)))))
  (define id (unbox next-handle-id))
  (set-box! next-handle-id (+ id 1))
  (hash-set! handle-registry id h)
  id)

;; ========================================
;; List helpers — walk the Prologos cons/nil chain in WHNF form.
;; ========================================
;;
;; Foreign args have been reduced before marshalling, so List values arrive
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

;; Drill through optional type-arg applications: `(cons A) head tail` and
;; `((cons A) head) tail` both denote a cons cell with payload `head`.
(define (try-cons-decomp e)
  (and (expr-app? e)
       (let ([func (expr-app-func e)]
             [tail (expr-app-arg e)])
         (and (expr-app? func)
              (let ([head (expr-app-arg func)]
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
       => (lambda (hd-tl)
            (loop (cdr hd-tl) (cons (car hd-tl) acc)))]
      [else (error 'eigentrust-prop
                   "list walk got a non-list / non-WHNF value: ~v" cur)])))

;; Walk a List Nat — extract Racket integers from expr-nat-val nodes.
(define (list-of-nat->ints lst-expr)
  (for/list ([e (in-list (prologos-list->list lst-expr))])
    (match e
      [(expr-nat-val n) n]
      [(expr-zero) 0]
      [(expr-suc _) (let walk ([x e] [k 0])
                      (match x
                        [(expr-zero) k]
                        [(expr-nat-val m) (+ k m)]
                        [(expr-suc inner) (walk inner (+ k 1))]
                        [_ (error 'eigentrust-prop "expected Nat, got ~v" e)]))]
      [_ (error 'eigentrust-prop "expected Nat in list, got ~v" e)])))

;; Walk a List Posit32 — extract bit-pattern integers from expr-posit32 nodes.
(define (list-of-posit32->bits lst-expr)
  (for/list ([e (in-list (prologos-list->list lst-expr))])
    (match e
      [(expr-posit32 bits) bits]
      [_ (error 'eigentrust-prop "expected Posit32 in list, got ~v" e)])))

;; Build a Prologos List Posit32 from a Racket list of bit-pattern integers.
(define (bits->prologos-list-posit32 bits-list)
  (foldr (lambda (bits acc)
           (expr-app (expr-app (expr-fvar 'cons) (expr-posit32 bits)) acc))
         (expr-nil)
         bits-list))

;; ========================================
;; Cell merge: monotone "max-by-generation" lattice.
;; ========================================
;;
;; Cell value = (cons gen bits). Iteration k writes (k . new-bits); merge
;; keeps the higher-gen entry. The first write per round is the only write
;; (propagator fires once per round when its gen-(k-1) inputs are ready), so
;; ties shouldn't arise in correct use; on a tie we keep the existing.

(struct gen-val (gen bits) #:transparent)

(define (gen-merge old new)
  (cond
    [(not (gen-val? old)) new]
    [(not (gen-val? new)) old]
    [(> (gen-val-gen new) (gen-val-gen old)) new]
    [else old]))

;; Initial bot value for any cell.
(define gen-bot (gen-val -1 0))  ;; gen=-1 => any real write strictly dominates

;; Track the per-cell generation in a side table so we know which gen to
;; assign on the next write. The simplest convention: a cell allocated by
;; `et-cell` starts at gen 0 with the user-supplied initial bits.
(define (current-gen cell-val)
  (if (gen-val? cell-val) (gen-val-gen cell-val) -1))

(define (current-bits cell-val)
  (if (gen-val? cell-val) (gen-val-bits cell-val) 0))

;; ========================================
;; Public FFI surface.
;; ========================================

;; Allocate a cell with the given Posit32 initial value (bit pattern).
;; Returns the cell-id as a non-negative integer (Nat in Prologos).
(define (et-cell hid init-bits)
  (define handle (lookup-handle hid))
  (define net (unbox (et-net-box handle)))
  (define-values (net* cid) (net-new-cell net (gen-val 0 init-bits) gen-merge))
  (set-box! (et-net-box handle) net*)
  (cell-id-n cid))

;; Read the current Posit32 bits stored in a cell.
(define (et-cell-get hid cid-int)
  (define handle (lookup-handle hid))
  (define net (unbox (et-net-box handle)))
  (define cid (cell-id cid-int))
  (current-bits (net-cell-read net cid)))

;; Imperatively overwrite a cell with a higher generation. Returns the cell-id
;; so calls can be chained (Prologos uses CBN; an unused result wouldn't fire).
(define (et-cell-set hid cid-int bits)
  (define handle (lookup-handle hid))
  (define net (unbox (et-net-box handle)))
  (define cid (cell-id cid-int))
  (define old (net-cell-read net cid))
  (define next-gen (+ 1 (current-gen old)))
  (define net* (net-cell-write net cid (gen-val next-gen bits)))
  (set-box! (et-net-box handle) net*)
  cid-int)

;; Install a propagator: target_cell := bias + Σ_i weight_i * src_i.
;;   srcs    : Prologos List Nat        — input cell-ids
;;   weights : Prologos List Posit32    — same length as srcs
;;   bias    : Posit32 bit-pattern      — additive constant
;;   target  : Nat                      — output cell-id
;; Returns the handle.
;;
;; The fire function reads sources, decodes to rationals, computes the
;; weighted sum (in exact rational arithmetic, using a quire-style exact
;; accumulator), encodes back to Posit32, and writes a generation
;; max(gen(srcs)) + 1 entry into the target cell.
(define (et-sum-prop hid srcs-list weights-list bias-bits target-int)
  (define handle (lookup-handle hid))
  (define net (unbox (et-net-box handle)))
  (define src-ints (list-of-nat->ints srcs-list))
  (define wt-bits (list-of-posit32->bits weights-list))
  (unless (= (length src-ints) (length wt-bits))
    (error 'et-sum-prop "srcs and weights must have equal length: ~a vs ~a"
           (length src-ints) (length wt-bits)))
  (define src-cids (map cell-id src-ints))
  (define target-cid (cell-id target-int))
  (define wt-rats (map posit32-to-rational wt-bits))
  (define bias-rat (posit32-to-rational bias-bits))
  (define fire-fn
    (lambda (n)
      ;; Read each source, decode to rational, multiply by weight, sum.
      ;; Track the max generation among inputs so the output gets a strictly
      ;; higher generation (gen-merge keeps higher gens).
      (define max-gen
        (for/fold ([g -1]) ([cid (in-list src-cids)])
          (max g (current-gen (net-cell-read n cid)))))
      (define sum
        (for/fold ([acc bias-rat])
                  ([cid (in-list src-cids)]
                   [w   (in-list wt-rats)])
          (define src-bits (current-bits (net-cell-read n cid)))
          (define src-rat (posit32-to-rational src-bits))
          (cond
            [(or (eq? src-rat 'nar) (eq? acc 'nar)) 'nar]
            [else (+ acc (* w src-rat))])))
      (define out-bits (cond
                         [(eq? sum 'nar) (posit32-encode 'nar)]
                         [else (posit32-encode sum)]))
      (net-cell-write n target-cid (gen-val (+ 1 max-gen) out-bits))))
  (define-values (net* _pid)
    (net-add-propagator net src-cids (list target-cid) fire-fn))
  (set-box! (et-net-box handle) net*)
  hid)

;; Run the network to quiescence (fixpoint of all installed propagators).
;; Returns the handle id so it can be chained (forces evaluation in CBN).
(define (et-run hid)
  (define handle (lookup-handle hid))
  (define net (unbox (et-net-box handle)))
  (define net* (run-to-quiescence net))
  (set-box! (et-net-box handle) net*)
  hid)

;; ========================================
;; et-add-iter: build one EigenTrust iteration on the propagator network.
;; ========================================
;;
;; prev-cells : Prologos List Nat       — cell-ids holding t_k (current scores)
;; matrix     : Prologos List (List Posit32)
;;              — row-major C, i.e., matrix[i][j] = how much peer i trusts peer j
;; pretrust   : Prologos List Posit32   — p, the prior trust vector
;; decay-bits : Posit32 bit pattern     — α (decay constant, typically 0.1–0.2)
;;
;; Allocates one fresh cell per peer (gen=k+1), installs a sum-propagator per
;; peer reading prev-cells, writing the new cell. The propagator computes
;;
;;   t_{k+1}[j] = α · p[j]  +  (1 − α) · Σ_i C[i][j] · t_k[i]
;;
;; Returns the list of new cell-ids as a Prologos List Nat (so the recursive
;; Prologos driver can pass them as the next iteration's `prev-cells`).
(define (et-add-iter hid prev-cells-list matrix-list pretrust-list decay-bits)
  (define handle (lookup-handle hid))
  (define prev-ints (list-of-nat->ints prev-cells-list))
  (define n (length prev-ints))
  (define matrix-bits (for/list ([row (in-list (prologos-list->list matrix-list))])
                        (list-of-posit32->bits row)))
  (define pretrust-bits (list-of-posit32->bits pretrust-list))
  (unless (= n (length matrix-bits))
    (error 'et-add-iter "matrix outer length ~a != peer count ~a"
           (length matrix-bits) n))
  (unless (= n (length pretrust-bits))
    (error 'et-add-iter "pretrust length ~a != peer count ~a"
           (length pretrust-bits) n))
  (define decay-rat (posit32-to-rational decay-bits))
  (define one-minus-decay (- 1 decay-rat))
  ;; Per-peer column j of C (transpose row), weighted by (1-α).
  (define weights-by-target
    (for/list ([j (in-range n)])
      (for/list ([i (in-range n)])
        (* one-minus-decay
           (posit32-to-rational (list-ref (list-ref matrix-bits i) j))))))
  ;; Per-peer bias = α * p[j].
  (define biases
    (for/list ([j (in-range n)])
      (* decay-rat (posit32-to-rational (list-ref pretrust-bits j)))))
  ;; Allocate the new layer first (so propagator installation can refer to it).
  (define new-cells
    (for/list ([_ (in-range n)])
      (et-cell hid (posit32-encode 0))))
  ;; Install one sum-propagator per peer.
  (for ([j (in-range n)])
    (define new-cid (list-ref new-cells j))
    (define wts (list-ref weights-by-target j))
    (define bias (list-ref biases j))
    (et-sum-prop hid
                 (foldr (lambda (cid acc)
                          (expr-app (expr-app (expr-fvar 'cons) (expr-nat-val cid)) acc))
                        (expr-nil)
                        prev-ints)
                 (foldr (lambda (w acc)
                          (expr-app (expr-app (expr-fvar 'cons)
                                              (expr-posit32 (posit32-encode w))) acc))
                        (expr-nil)
                        wts)
                 (posit32-encode bias)
                 new-cid))
  ;; Return the new cell-ids as a Prologos List Nat.
  (foldr (lambda (i acc)
           (expr-app (expr-app (expr-fvar 'cons) (expr-nat-val i)) acc))
         (expr-nil)
         new-cells))

;; Read a list of cells and return their current Posit32 bits as a Prologos List.
(define (et-snapshot hid cids-list)
  (define handle (lookup-handle hid))
  (define net (unbox (et-net-box handle)))
  (define ints (list-of-nat->ints cids-list))
  (define bits-list
    (for/list ([i (in-list ints)])
      (current-bits (net-cell-read net (cell-id i)))))
  (bits->prologos-list-posit32 bits-list))

;; Combined "run + snapshot" — flushes the propagator worklist and reads the
;; given cells out as Posit32 values in one call. Useful as the final step
;; of an algorithm so Prologos's call-by-name reduction strictly evaluates
;; the cell list (and hence the propagator-install side effects) before the
;; quiescence run happens.
(define (et-run-and-snapshot hid cids-list)
  (define handle (lookup-handle hid))
  (define ints (list-of-nat->ints cids-list))     ;; forces cids-list's eval
  (define net0 (unbox (et-net-box handle)))
  (define net* (run-to-quiescence net0))
  (set-box! (et-net-box handle) net*)
  (define bits-list
    (for/list ([i (in-list ints)])
      (current-bits (net-cell-read net* (cell-id i)))))
  (bits->prologos-list-posit32 bits-list))

;; ========================================
;; Posit32 ↔ exact rational bridges (passthrough types).
;; ========================================
;;
;; For Prologos, Posit32 marshals to its raw bit-pattern integer; calling
;; `posit32-to-rational` directly via FFI works, but these wrappers give
;; the user a clean idiom in the `.prologos` source.

(define (et-rat->posit32 r)
  (posit32-encode r))

(define (et-posit32->rat bits)
  (posit32-to-rational bits))
