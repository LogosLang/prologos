#lang racket/base

;;;
;;; Tests for constraint-cell.rkt — Finite-domain constraint lattice
;;; Verifies lattice properties: identity, commutativity, associativity,
;;; idempotency, monotonicity, contradiction detection.
;;;

(require rackunit
         racket/set
         "../constraint-cell.rkt")

;; ========================================
;; Test candidates (fixtures)
;; ========================================

(define c-add-nat  (constraint-candidate 'Add '(Nat) 'prologos::data::nat::add))
(define c-add-int  (constraint-candidate 'Add '(Int) 'prologos::core::int::int-add))
(define c-add-rat  (constraint-candidate 'Add '(Rat) 'prologos::core::rat::rat-add))
(define c-eq-nat   (constraint-candidate 'Eq  '(Nat) 'prologos::data::nat::nat-eq))
(define c-eq-int   (constraint-candidate 'Eq  '(Int) 'prologos::core::int::int-eq))

(define set-add-all (list c-add-nat c-add-int c-add-rat))
(define set-add-ni  (list c-add-nat c-add-int))
(define set-eq-all  (list c-eq-nat c-eq-int))

;; ========================================
;; A. Sentinel predicates
;; ========================================

(test-case "constraint/bot: predicate"
  (check-true (constraint-bot? constraint-bot))
  (check-false (constraint-bot? constraint-top))
  (check-false (constraint-bot? (constraint-one c-add-nat))))

(test-case "constraint/top: predicate"
  (check-true (constraint-top? constraint-top))
  (check-false (constraint-top? constraint-bot))
  (check-false (constraint-top? (constraint-set (list->set set-add-all)))))

;; ========================================
;; B. Constructor: constraint-from-candidates
;; ========================================

(test-case "constraint/from-candidates: empty → top"
  (check-equal? (constraint-from-candidates '()) constraint-top))

(test-case "constraint/from-candidates: singleton → one"
  (define v (constraint-from-candidates (list c-add-nat)))
  (check-true (constraint-one? v))
  (check-equal? (constraint-one-candidate v) c-add-nat))

(test-case "constraint/from-candidates: multiple → set"
  (define v (constraint-from-candidates set-add-all))
  (check-true (constraint-set? v))
  (check-equal? (set-count (constraint-set-candidates v)) 3))

;; ========================================
;; C. Merge: identity (bot)
;; ========================================

(test-case "constraint/merge: bot ⊔ bot = bot"
  (check-equal? (constraint-merge constraint-bot constraint-bot) constraint-bot))

(test-case "constraint/merge: bot ⊔ set = set"
  (define s (constraint-from-candidates set-add-all))
  (check-equal? (constraint-merge constraint-bot s) s))

(test-case "constraint/merge: set ⊔ bot = set"
  (define s (constraint-from-candidates set-add-all))
  (check-equal? (constraint-merge s constraint-bot) s))

(test-case "constraint/merge: bot ⊔ one = one"
  (define o (constraint-one c-add-nat))
  (check-equal? (constraint-merge constraint-bot o) o))

(test-case "constraint/merge: one ⊔ bot = one"
  (define o (constraint-one c-add-nat))
  (check-equal? (constraint-merge o constraint-bot) o))

;; ========================================
;; D. Merge: absorbing (top)
;; ========================================

(test-case "constraint/merge: top ⊔ anything = top"
  (check-equal? (constraint-merge constraint-top constraint-bot) constraint-top)
  (check-equal? (constraint-merge constraint-top (constraint-one c-add-nat)) constraint-top)
  (check-equal? (constraint-merge constraint-top (constraint-from-candidates set-add-all))
                constraint-top))

(test-case "constraint/merge: anything ⊔ top = top"
  (check-equal? (constraint-merge constraint-bot constraint-top) constraint-top)
  (check-equal? (constraint-merge (constraint-one c-add-nat) constraint-top) constraint-top))

;; ========================================
;; E. Merge: idempotent
;; ========================================

(test-case "constraint/merge: one ⊔ one (same) = one"
  (define o (constraint-one c-add-nat))
  (check-equal? (constraint-merge o o) o))

(test-case "constraint/merge: set ⊔ set (same) = set"
  (define s (constraint-from-candidates set-add-all))
  (define result (constraint-merge s s))
  (check-true (constraint-set? result))
  (check-equal? (set-count (constraint-set-candidates result)) 3))

;; ========================================
;; F. Merge: set intersection
;; ========================================

(test-case "constraint/merge: set ⊔ set → intersection (2 elements)"
  (define s1 (constraint-from-candidates set-add-all))   ;; {nat, int, rat}
  (define s2 (constraint-from-candidates set-add-ni))    ;; {nat, int}
  (define result (constraint-merge s1 s2))
  (check-true (constraint-set? result))
  (check-equal? (set-count (constraint-set-candidates result)) 2)
  (check-true (set-member? (constraint-set-candidates result) c-add-nat))
  (check-true (set-member? (constraint-set-candidates result) c-add-int)))

(test-case "constraint/merge: set ⊔ set → singleton promotion"
  (define s1 (constraint-from-candidates set-add-ni))    ;; {nat, int}
  (define s2 (constraint-from-candidates (list c-add-nat c-add-rat)))  ;; {nat, rat}
  (define result (constraint-merge s1 s2))
  ;; Intersection = {nat} → promoted to constraint-one
  (check-true (constraint-one? result))
  (check-equal? (constraint-one-candidate result) c-add-nat))

(test-case "constraint/merge: set ⊔ set → empty = top"
  (define s1 (constraint-from-candidates (list c-add-nat)))  ;; one wrapper, but let's use sets
  (define s1* (constraint-from-candidates (list c-add-int c-add-rat)))  ;; {int, rat}
  (define s2 (constraint-from-candidates (list c-add-nat)))
  ;; s1* has {int, rat}, s2 singleton promoted to one
  ;; Use sets directly:
  (define sa (constraint-set (list->set (list c-add-int c-add-rat))))
  (define sb (constraint-set (list->set (list c-add-nat))))
  (define result (constraint-merge sa sb))
  (check-equal? result constraint-top))

;; ========================================
;; G. Merge: one ⊔ set (membership check)
;; ========================================

(test-case "constraint/merge: one ⊔ set (member) = one"
  (define o (constraint-one c-add-nat))
  (define s (constraint-from-candidates set-add-all))
  (define result (constraint-merge o s))
  (check-true (constraint-one? result))
  (check-equal? (constraint-one-candidate result) c-add-nat))

(test-case "constraint/merge: one ⊔ set (non-member) = top"
  (define o (constraint-one c-eq-nat))
  (define s (constraint-from-candidates set-add-all))
  (check-equal? (constraint-merge o s) constraint-top))

(test-case "constraint/merge: set ⊔ one (member) = one"
  (define s (constraint-from-candidates set-add-all))
  (define o (constraint-one c-add-int))
  (define result (constraint-merge s o))
  (check-true (constraint-one? result))
  (check-equal? (constraint-one-candidate result) c-add-int))

(test-case "constraint/merge: set ⊔ one (non-member) = top"
  (define s (constraint-from-candidates set-add-all))
  (define o (constraint-one c-eq-int))
  (check-equal? (constraint-merge s o) constraint-top))

;; ========================================
;; H. Merge: one ⊔ one (different) = top
;; ========================================

(test-case "constraint/merge: one ⊔ one (different) = top"
  (check-equal? (constraint-merge (constraint-one c-add-nat)
                                   (constraint-one c-add-int))
                constraint-top))

;; ========================================
;; I. Commutativity
;; ========================================

(test-case "constraint/merge: commutativity"
  (define s1 (constraint-from-candidates set-add-all))
  (define s2 (constraint-from-candidates set-add-ni))
  (define r1 (constraint-merge s1 s2))
  (define r2 (constraint-merge s2 s1))
  ;; Both should be constraint-set with {nat, int}
  (check-true (constraint-set? r1))
  (check-true (constraint-set? r2))
  (check-equal? (constraint-set-candidates r1)
                (constraint-set-candidates r2)))

;; ========================================
;; J. Monotonicity (merge only shrinks candidate sets)
;; ========================================

(test-case "constraint/merge: monotone (set size never increases)"
  (define s3 (constraint-from-candidates set-add-all))       ;; 3 elements
  (define s2 (constraint-from-candidates set-add-ni))        ;; 2 elements
  (define result (constraint-merge s3 s2))
  ;; Result has ≤ min(3, 2) = 2 elements
  (check-true (constraint-set? result))
  (check-true (<= (set-count (constraint-set-candidates result)) 2)))

;; ========================================
;; K. Contradiction detection
;; ========================================

(test-case "constraint/contradicts?: top = contradiction"
  (check-true (constraint-contradicts? constraint-top)))

(test-case "constraint/contradicts?: bot = no contradiction"
  (check-false (constraint-contradicts? constraint-bot)))

(test-case "constraint/contradicts?: set = no contradiction"
  (check-false (constraint-contradicts? (constraint-from-candidates set-add-all))))

(test-case "constraint/contradicts?: one = no contradiction"
  (check-false (constraint-contradicts? (constraint-one c-add-nat))))

;; ========================================
;; L. Queries
;; ========================================

(test-case "constraint/resolved?: true for one, false otherwise"
  (check-true (constraint-resolved? (constraint-one c-add-nat)))
  (check-false (constraint-resolved? constraint-bot))
  (check-false (constraint-resolved? constraint-top))
  (check-false (constraint-resolved? (constraint-from-candidates set-add-all))))

(test-case "constraint/resolved-candidate: extracts candidate or #f"
  (check-equal? (constraint-resolved-candidate (constraint-one c-add-nat)) c-add-nat)
  (check-false (constraint-resolved-candidate constraint-bot))
  (check-false (constraint-resolved-candidate constraint-top)))

(test-case "constraint/candidates: returns list or #f"
  (define s (constraint-from-candidates set-add-all))
  (define cs (constraint-candidates s))
  (check-equal? (length cs) 3)
  (check-equal? (constraint-candidates (constraint-one c-add-nat)) (list c-add-nat))
  (check-false (constraint-candidates constraint-bot))
  (check-false (constraint-candidates constraint-top)))

;; ========================================
;; M. trait-ref struct
;; ========================================

(test-case "trait-ref: construction and accessors"
  (define tr (trait-ref 'Add 1))
  (check-equal? (trait-ref-name tr) 'Add)
  (check-equal? (trait-ref-arity tr) 1)
  (check-true (trait-ref? tr)))

;; ========================================
;; N. Debug representation
;; ========================================

(test-case "constraint->datum: readable output"
  (check-equal? (constraint->datum constraint-bot) '⊥)
  (check-equal? (constraint->datum constraint-top) '⊤)
  (check-equal? (constraint->datum (constraint-one c-add-nat))
                '(one Add (Nat)))
  (define s (constraint-from-candidates (list c-add-nat c-add-int)))
  (define d (constraint->datum s))
  (check-equal? (car d) 'set)
  (check-equal? (length (cdr d)) 2))
