#lang racket/base

;;;
;;; term-lattice.rkt — Term lattice for FL narrowing propagator cells
;;;
;;; Defines the merge function (lattice join) for term-valued cells used
;;; in narrowing.  This is a 4-element lattice:
;;;
;;;   term-bot                  (⊥, no information — fresh variable)
;;;       ↓
;;;   term-var(id)             (logic variable, may be unified later)
;;;   term-ctor(tag, sub-cells) (constructor with subcell ids)
;;;       ↓
;;;   term-top                  (⊤, contradiction — incompatible ctors)
;;;
;;; The merge function:
;;;   bot ⊔ x              = x
;;;   x ⊔ bot              = x
;;;   Var(a) ⊔ Var(b)      = Var(b)  (caller unifies via cell write)
;;;   Var(a) ⊔ Ctor(t, cs) = Ctor(t, cs)  (bind variable)
;;;   Ctor(t, cs) ⊔ Var(a) = Ctor(t, cs)  (bind variable)
;;;   Ctor(t1, cs1) ⊔ Ctor(t2, cs2) =
;;;     if t1 = t2 ∧ |cs1| = |cs2|: Ctor(t1, [merge(c1i, c2i) ...])
;;;     else: term-top  (contradiction)
;;;   anything ⊔ top       = top
;;;   top ⊔ anything       = top
;;;
;;; Variable unification is handled by the propagator network: when two
;;; variables unify, one cell is written with a reference to the other.
;;; term-walk resolves these chains by reading cell values from the network.
;;;
;;; CRITICAL: This module is a PURE LEAF — requires only racket/base + racket/match.
;;; No project dependencies.  Used by narrowing.rkt (Phase 1c).
;;;

(require racket/match)

(provide
 ;; Sentinels
 term-bot  term-top
 term-bot? term-top?
 ;; Structs
 (struct-out term-var)
 (struct-out term-ctor)
 ;; Predicates
 term-value?
 ;; Merge
 term-merge
 ;; Contradiction check
 term-contradiction?
 ;; Variable resolution
 term-walk
 ;; Utilities
 term-ground?
 term->datum)

;; ========================================
;; Sentinel values
;; ========================================

(define term-bot 'term-bot)
(define term-top 'term-top)

(define (term-bot? v) (eq? v 'term-bot))
(define (term-top? v) (eq? v 'term-top))

;; ========================================
;; Term lattice structs
;; ========================================

;; A logic variable — `id` is a cell-id in the propagator network.
;; When a Var cell is merged with a Ctor, the cell value becomes the Ctor
;; (the variable is "bound").  When two Vars merge, one cell gets the
;; other's value via net-cell-write (union-find through the network).
(struct term-var (id) #:transparent)

;; A constructor application — `tag` is a symbol (e.g., 'zero, 'suc, 'cons),
;; `sub-cells` is a list of cell-ids (one per constructor argument) in the
;; propagator network.  Each sub-cell is itself a term cell.
(struct term-ctor (tag sub-cells) #:transparent)

;; ========================================
;; Predicates
;; ========================================

;; Is this a "real" term value (not bot or top)?
(define (term-value? v)
  (or (term-var? v) (term-ctor? v)))

;; ========================================
;; Merge (lattice join)
;; ========================================

;; term-merge : TermValue × TermValue → TermValue
;;
;; The merge function for term-valued propagator cells.  This is the
;; function passed to net-new-cell as the merge-fn parameter.
;;
;; Note on Var ⊔ Var: Returns the new value (Var(b)).  The caller
;; (narrowing propagator) is responsible for propagating the binding
;; to the old variable's cell via net-cell-write.  Within the propagator
;; network, this is handled by the standard cell-write mechanism —
;; the old cell gets overwritten with a reference to the new var's cell.
;;
;; Note on Ctor ⊔ Ctor with same tag: This performs a SHALLOW merge
;; of sub-cell ids.  If both constructors have sub-cells, we take the
;; new ones (the propagator network handles the actual sub-cell
;; unification by writing to the sub-cells separately).  Deep recursive
;; merge of sub-cell VALUES is done by the narrowing propagator, not here.
(define (term-merge old new)
  (cond
    ;; Bot is identity
    [(term-bot? old) new]
    [(term-bot? new) old]
    ;; Top is absorbing
    [(term-top? old) term-top]
    [(term-top? new) term-top]
    ;; Var ⊔ anything concrete = bind the variable
    [(term-var? old)
     (cond
       [(term-var? new)
        ;; Var ⊔ Var: adopt the new variable (union-find link)
        ;; The narrowing propagator will propagate to the other var's cell
        new]
       [(term-ctor? new)
        ;; Var ⊔ Ctor: bind the variable to the constructor
        new]
       [else term-top])]
    ;; Ctor ⊔ Var = bind the variable (commutative)
    [(and (term-ctor? old) (term-var? new))
     old]
    ;; Ctor ⊔ Ctor
    [(and (term-ctor? old) (term-ctor? new))
     (if (and (eq? (term-ctor-tag old) (term-ctor-tag new))
              (= (length (term-ctor-sub-cells old))
                 (length (term-ctor-sub-cells new))))
         ;; Same constructor, same arity: keep it (sub-cell unification
         ;; is handled by the propagator network writing to sub-cells)
         ;; We keep the old value since it's already established in the
         ;; network; the narrowing propagator unifies sub-cells separately.
         old
         ;; Different constructors or different arities: contradiction
         term-top)]
    ;; Anything else: contradiction
    [else term-top]))

;; ========================================
;; Contradiction check
;; ========================================

;; term-contradiction? : TermValue → Boolean
;;
;; Returns #t if the term value represents a contradiction.
;; Passed to net-new-cell as the contradicts? parameter.
(define (term-contradiction? v) (term-top? v))

;; ========================================
;; Variable resolution (walk)
;; ========================================

;; term-walk : TermValue × (cell-id → TermValue) → TermValue
;;
;; Resolve variable chains.  If `v` is a Var(id), look up the cell
;; value for `id` using `read-cell-fn`.  If that value is also a Var,
;; keep walking.  Returns the ultimate non-Var value (which may be
;; bot, a Ctor, or top).
;;
;; The read-cell-fn should be a closure over the propagator network,
;; e.g., (lambda (cid) (net-cell-read net cid)).
;;
;; Cycle detection: we track visited cell-ids.  If we revisit a cell,
;; we return term-bot (unresolved cycle = no information yet).
(define (term-walk v read-cell-fn)
  (let loop ([v v] [seen '()])
    (match v
      [(term-var id)
       (if (memv id seen)
           ;; Cycle detected — return bot (unresolved)
           term-bot
           (let ([cell-val (read-cell-fn id)])
             (loop cell-val (cons id seen))))]
      [_ v])))

;; ========================================
;; Utilities
;; ========================================

;; term-ground? : TermValue × (cell-id → TermValue) → Boolean
;;
;; Returns #t if the term is fully ground (no unresolved variables).
;; Requires a read-cell function to resolve sub-cells and variables.
(define (term-ground? v read-cell-fn)
  (let loop ([v (term-walk v read-cell-fn)])
    (match v
      [(? term-bot?) #f]
      [(? term-top?) #f]
      [(term-var _)  #f]  ; shouldn't happen after walk, but defensive
      [(term-ctor _ sub-cells)
       (for/and ([cid (in-list sub-cells)])
         (loop (term-walk (read-cell-fn cid) read-cell-fn)))]
      [_ #f])))

;; term->datum : TermValue × (cell-id → TermValue) → sexp
;;
;; Convert a term value to a readable s-expression, for debugging
;; and test output.  Resolves variables through the read-cell function.
;; Examples:
;;   term-bot            → 'bot
;;   term-top            → 'top
;;   (term-var 3)        → walks and converts the resolved value
;;   (term-ctor 'zero ()) → 'zero
;;   (term-ctor 'suc (c)) → '(suc <sub-datum>)
(define (term->datum v read-cell-fn)
  (let loop ([v (term-walk v read-cell-fn)])
    (match v
      [(? term-bot?) 'bot]
      [(? term-top?) 'top]
      [(term-var id)
       ;; Unresolved variable after walk (shouldn't happen normally)
       (string->symbol (format "?~a" id))]
      [(term-ctor tag '())
       tag]
      [(term-ctor tag sub-cells)
       (cons tag
             (for/list ([cid (in-list sub-cells)])
               (loop (term-walk (read-cell-fn cid) read-cell-fn))))])))
