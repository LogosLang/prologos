#lang racket/base

;;;
;;; constraint-cell.rkt — Finite-domain constraint lattice for trait dispatch
;;;
;;; Defines lattice values and merge function for constraint cells in the
;;; propagator network. A constraint cell tracks a set of candidate trait
;;; implementations that satisfy a constraint (e.g., "which impl of Add
;;; is applicable here?"). As type information flows in, candidates are
;;; eliminated (set intersection), monotonically narrowing toward a single
;;; impl or contradiction.
;;;
;;; Lattice structure:
;;;
;;;   constraint-bot           (⊥, unconstrained — all candidates possible)
;;;        ↓
;;;   constraint-set S         (partially constrained — S ⊆ candidates)
;;;        ↓
;;;   constraint-one e         (fully resolved — single candidate)
;;;        ↓
;;;   constraint-top           (⊤, contradiction — no candidates satisfy)
;;;
;;; Merge (join) = set intersection:
;;;   bot ⊔ S = S
;;;   S1 ⊔ S2 = S1 ∩ S2
;;;   {e} = one e (singleton optimization)
;;;   {} = top (empty = contradiction)
;;;
;;; CRITICAL: This module is a PURE LEAF — requires only racket/base and
;;; racket/set. No project dependencies. Used by constraint-propagators.rkt
;;; (Phase 2c) and elaborator-network.rkt.
;;;
;;; Design note: The cell is parameterized by a trait-ref (abstract trait
;;; identifier) rather than raw symbols, to support Level 3 extension
;;; where traits become computed type-level values.
;;;

(require racket/set)

(provide
 ;; Sentinels
 constraint-bot constraint-top
 constraint-bot? constraint-top?
 ;; Structs
 (struct-out constraint-set)
 (struct-out constraint-one)
 (struct-out constraint-candidate)
 (struct-out trait-ref)
 ;; Merge & contradiction
 constraint-merge
 constraint-contradicts?
 ;; Constructors
 constraint-from-candidates
 ;; Queries
 constraint-resolved?
 constraint-resolved-candidate
 constraint-candidates
 ;; Debug
 constraint->datum)

;; ========================================
;; Trait reference (abstract trait identifier)
;; ========================================
;; Currently just a wrapper around (name, arity), but designed to be
;; extended in Level 3 to support computed trait references.

(struct trait-ref (name arity) #:transparent)

;; ========================================
;; Constraint candidate
;; ========================================
;; A single candidate in the constraint set: a concrete impl that could
;; satisfy the constraint. Stores the trait name, type args, and dict name.

(struct constraint-candidate (trait-name type-args dict-name) #:transparent)

;; ========================================
;; Sentinel values
;; ========================================

(define constraint-bot 'constraint-bot)
(define constraint-top 'constraint-top)

(define (constraint-bot? v) (eq? v 'constraint-bot))
(define (constraint-top? v) (eq? v 'constraint-top))

;; ========================================
;; Lattice values
;; ========================================

;; Multiple candidates remain (partially constrained).
;; candidates is a (setof constraint-candidate).
;; Invariant: (set-count candidates) >= 2.
(struct constraint-set (candidates) #:transparent)

;; Single candidate (fully resolved).
(struct constraint-one (candidate) #:transparent)

;; ========================================
;; Constructor: from a list of candidates
;; ========================================
;; Normalizes to the appropriate lattice value:
;;   0 candidates → constraint-top
;;   1 candidate  → constraint-one
;;   N candidates → constraint-set
(define (constraint-from-candidates cands)
  (cond
    [(null? cands) constraint-top]
    [(null? (cdr cands)) (constraint-one (car cands))]
    [else (constraint-set (list->set cands))]))

;; ========================================
;; Merge (lattice join = set intersection)
;; ========================================

(define (constraint-merge old new)
  (cond
    ;; Identity: bot ⊔ x = x
    [(constraint-bot? old) new]
    [(constraint-bot? new) old]
    ;; Absorbing: top ⊔ x = top
    [(constraint-top? old) constraint-top]
    [(constraint-top? new) constraint-top]
    ;; Both resolved to same → idempotent
    [(and (constraint-one? old) (constraint-one? new))
     (if (equal? (constraint-one-candidate old)
                 (constraint-one-candidate new))
         old
         constraint-top)]
    ;; One resolved, one set → check membership
    [(and (constraint-one? old) (constraint-set? new))
     (if (set-member? (constraint-set-candidates new)
                      (constraint-one-candidate old))
         old
         constraint-top)]
    [(and (constraint-set? old) (constraint-one? new))
     (if (set-member? (constraint-set-candidates old)
                      (constraint-one-candidate new))
         new
         constraint-top)]
    ;; Both sets → intersection
    [(and (constraint-set? old) (constraint-set? new))
     (define inter (set-intersect (constraint-set-candidates old)
                                  (constraint-set-candidates new)))
     (define n (set-count inter))
     (cond
       [(= n 0) constraint-top]
       [(= n 1) (constraint-one (set-first inter))]
       [else (constraint-set inter)])]
    ;; Fallback (should not happen with well-typed cells)
    [else constraint-top]))

;; ========================================
;; Contradiction check
;; ========================================

(define (constraint-contradicts? v) (constraint-top? v))

;; ========================================
;; Queries
;; ========================================

;; Is the constraint fully resolved to a single candidate?
(define (constraint-resolved? v) (constraint-one? v))

;; Extract the resolved candidate, or #f.
(define (constraint-resolved-candidate v)
  (if (constraint-one? v)
      (constraint-one-candidate v)
      #f))

;; Return the set of remaining candidates (as a list), or #f for bot/top.
(define (constraint-candidates v)
  (cond
    [(constraint-set? v) (set->list (constraint-set-candidates v))]
    [(constraint-one? v) (list (constraint-one-candidate v))]
    [else #f]))

;; ========================================
;; Debug representation
;; ========================================

(define (constraint->datum v)
  (cond
    [(constraint-bot? v) '⊥]
    [(constraint-top? v) '⊤]
    [(constraint-one? v)
     (define c (constraint-one-candidate v))
     `(one ,(constraint-candidate-trait-name c)
           ,(constraint-candidate-type-args c))]
    [(constraint-set? v)
     `(set ,@(for/list ([c (in-set (constraint-set-candidates v))])
               `(,(constraint-candidate-trait-name c)
                 ,(constraint-candidate-type-args c))))]
    [else `(unknown ,v)]))
