#lang racket/base

;;;
;;; decision-cell.rkt — Decision domain lattice for ATMS solver
;;;
;;; BSP-LE Track 2 Phase 1: Pure lattice operations for decision cells.
;;; Follows constraint-cell.rkt convention (Critical 1.1):
;;;   bot = unconstrained (all alternatives viable)
;;;   top = contradicted (no alternatives left)
;;;   merge = set-intersection (narrowing)
;;;
;;; A decision cell tracks which alternatives survive at a choice point.
;;; Each `atms-amb` call creates one group-level decision cell on the
;;; outer network. Alternatives = constructors (SRE structural lattice).
;;; Nogoods narrow decision cells by eliminating alternatives.
;;;
;;; Lattice structure:
;;;
;;;   decision-bot               (⊥, all alternatives viable — unconstrained)
;;;        ↓
;;;   decision-set S             (partially narrowed — S ⊆ alternatives)
;;;        ↓
;;;   decision-one h             (fully committed — single alternative)
;;;        ↓
;;;   decision-top               (⊤, contradiction — no alternatives left)
;;;
;;; Merge (= narrowing) = set intersection:
;;;   bot ⊔ S = S
;;;   S1 ⊔ S2 = S1 ∩ S2
;;;   {h} = one h (singleton optimization)
;;;   {} = top (empty = contradiction)
;;;
;;; Also provides: nogood lattice (set of sets, union merge),
;;; assumptions accumulator (set, union merge), counter (nat, max merge).
;;;
;;; PURE LEAF — requires only racket/base. No project dependencies.
;;; Cell creation happens in the consumer (solver infrastructure),
;;; not here. This module defines lattice VALUES and OPERATIONS only.
;;;
;;; Design reference:
;;;   docs/tracking/2026-04-07_BSP_LE_TRACK2_DESIGN.md §2.5a, §2.6
;;;   constraint-cell.rkt (convention model)
;;;

(provide
 ;; === Decision Domain Lattice ===
 ;; Sentinels
 decision-bot decision-top
 decision-bot? decision-top?
 ;; Structs
 (struct-out decision-set)
 (struct-out decision-one)
 ;; Merge & contradiction
 decision-domain-merge
 decision-domain-contradicts?
 ;; Constructors
 decision-from-alternatives
 ;; Queries
 decision-committed?
 decision-committed-assumption
 decision-alternatives
 decision-domain-narrow
 ;; Debug
 decision->datum

 ;; === Nogood Lattice ===
 nogood-empty
 nogood-merge
 nogood-add
 nogood-member?

 ;; === Assumptions Accumulator ===
 assumptions-empty
 assumptions-merge
 assumptions-add

 ;; === Counter (Monotone Nat) ===
 counter-merge)


;; ============================================================
;; Decision Domain Lattice
;; ============================================================

;; Sentinel values
(define decision-bot 'decision-bot)
(define decision-top 'decision-top)

(define (decision-bot? v) (eq? v 'decision-bot))
(define (decision-top? v) (eq? v 'decision-top))

;; Multiple alternatives remain (partially narrowed).
;; alternatives: hasheq assumption-id → #t
;; Invariant: (hash-count alternatives) >= 2
(struct decision-set (alternatives) #:transparent)

;; Single alternative (fully committed — singleton).
;; assumption: the surviving assumption-id
(struct decision-one (assumption) #:transparent)

;; ============================================================
;; Constructor: from a list of assumption-ids
;; ============================================================
;; Normalizes to the appropriate lattice value:
;;   0 alternatives → decision-top
;;   1 alternative  → decision-one
;;   N alternatives → decision-set
(define (decision-from-alternatives aids)
  (cond
    [(null? aids) decision-top]
    [(null? (cdr aids)) (decision-one (car aids))]
    [else (decision-set (for/hasheq ([a (in-list aids)])
                          (values a #t)))]))

;; ============================================================
;; Merge (= constraint-cell convention: set intersection = narrowing)
;; ============================================================
;; Following constraint-cell.rkt pattern exactly:
;;   bot ⊔ x = x  (unconstrained meets anything = that thing)
;;   x ⊔ bot = x
;;   top ⊔ x = top (contradiction absorbs)
;;   x ⊔ top = top
;;   one(a) ⊔ one(a) = one(a)  (same = keep)
;;   one(a) ⊔ one(b) = top     (different singletons = contradiction)
;;   set(S) ⊔ set(T) = normalize(S ∩ T)
;;   set(S) ⊔ one(a) = one(a) if a ∈ S, else top
;;   one(a) ⊔ set(S) = one(a) if a ∈ S, else top
(define (decision-domain-merge old new)
  (cond
    ;; Identity: bot ⊔ x = x
    [(decision-bot? old) new]
    [(decision-bot? new) old]
    ;; Absorbing: top ⊔ x = top
    [(decision-top? old) decision-top]
    [(decision-top? new) decision-top]
    ;; one ⊔ one
    [(and (decision-one? old) (decision-one? new))
     (if (equal? (decision-one-assumption old) (decision-one-assumption new))
         old  ;; same singleton
         decision-top)]  ;; different singletons = contradiction
    ;; set ⊔ set
    [(and (decision-set? old) (decision-set? new))
     (define s1 (decision-set-alternatives old))
     (define s2 (decision-set-alternatives new))
     ;; Intersection: keep only keys present in both
     (define intersection
       (for/hasheq ([(k _) (in-hash s1)]
                    #:when (hash-has-key? s2 k))
         (values k #t)))
     (normalize-decision intersection)]
    ;; set ⊔ one: keep the one if it's in the set
    [(and (decision-set? old) (decision-one? new))
     (if (hash-has-key? (decision-set-alternatives old) (decision-one-assumption new))
         new
         decision-top)]
    ;; one ⊔ set: keep the one if it's in the set
    [(and (decision-one? old) (decision-set? new))
     (if (hash-has-key? (decision-set-alternatives new) (decision-one-assumption old))
         old
         decision-top)]
    ;; Fallback (shouldn't reach here)
    [else decision-top]))

;; Normalize a hasheq set to the appropriate lattice value
(define (normalize-decision alternatives)
  (define count (hash-count alternatives))
  (cond
    [(= count 0) decision-top]
    [(= count 1)
     (define pos (hash-iterate-first alternatives))
     (decision-one (hash-iterate-key alternatives pos))]
    [else (decision-set alternatives)]))

;; Contradiction predicate (for net-new-cell contradicts? parameter)
(define (decision-domain-contradicts? v)
  (decision-top? v))

;; ============================================================
;; Queries
;; ============================================================

;; Is this decision committed (singleton)?
(define (decision-committed? v)
  (decision-one? v))

;; Extract the committed assumption-id (or #f)
(define (decision-committed-assumption v)
  (if (decision-one? v)
      (decision-one-assumption v)
      #f))

;; Extract the current set of viable alternatives as a list
(define (decision-alternatives v)
  (cond
    [(decision-bot? v) '()]  ;; bot = we don't know the alternatives yet
    [(decision-top? v) '()]  ;; top = no alternatives
    [(decision-one? v) (list (decision-one-assumption v))]
    [(decision-set? v) (hash-keys (decision-set-alternatives v))]
    [else '()]))

;; Narrow: remove a specific alternative from the domain
;; Returns the new decision value.
(define (decision-domain-narrow v excluded-aid)
  (cond
    [(decision-bot? v) v]  ;; can't narrow bot (don't know alternatives)
    [(decision-top? v) v]  ;; already contradicted
    [(decision-one? v)
     (if (equal? (decision-one-assumption v) excluded-aid)
         decision-top  ;; removing the only alternative = contradiction
         v)]           ;; removing something not present = no-op
    [(decision-set? v)
     (define remaining (hash-remove (decision-set-alternatives v) excluded-aid))
     (normalize-decision remaining)]
    [else v]))

;; Debug: convert to a datum for display
(define (decision->datum v)
  (cond
    [(decision-bot? v) 'decision-bot]
    [(decision-top? v) 'decision-top]
    [(decision-one? v) `(decision-one ,(decision-one-assumption v))]
    [(decision-set? v) `(decision-set ,(hash-keys (decision-set-alternatives v)))]
    [else v]))


;; ============================================================
;; Nogood Lattice
;; ============================================================
;; A nogood set is a set of nogoods, where each nogood is a hasheq
;; of assumption-ids. The lattice is P(P(AssumptionId)) under set-union.
;; Monotone: nogoods only accumulate.

;; Empty nogood set
(define nogood-empty '())

;; Merge: append (functionally equivalent to set-union for unique nogoods)
;; Uses list representation for simplicity — nogoods are typically small (< 100).
(define (nogood-merge old new)
  (cond
    [(null? old) new]
    [(null? new) old]
    [else (append old new)]))

;; Add a single nogood
(define (nogood-add ngs nogood-set)
  (cons nogood-set ngs))

;; Check if a specific assumption set contains any nogood as a subset
(define (nogood-member? ngs assumption-set)
  (for/or ([ng (in-list ngs)])
    (for/and ([(k _) (in-hash ng)])
      (hash-has-key? assumption-set k))))


;; ============================================================
;; Assumptions Accumulator
;; ============================================================
;; P(Assumption) under set-union. Monotone: assumptions only added.
;; Uses hasheq: assumption-id → assumption struct.

(define assumptions-empty (hasheq))

;; Merge: hash-union (keeps both sides, newer wins on collision — shouldn't happen)
(define (assumptions-merge old new)
  (cond
    [(eq? old assumptions-empty) new]
    [(eq? new assumptions-empty) old]
    [else
     (for/fold ([acc old]) ([(k v) (in-hash new)])
       (hash-set acc k v))]))

;; Add a single assumption
(define (assumptions-add store aid assumption)
  (hash-set store aid assumption))


;; ============================================================
;; Counter (Monotone Nat)
;; ============================================================
;; Merge = max. Written ONLY at topology stratum (sequential) to
;; prevent concurrent ID collision (2.3 from external critique).

(define (counter-merge old new)
  (max old new))
