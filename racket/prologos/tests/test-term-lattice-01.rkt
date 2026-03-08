#lang racket/base

;;;
;;; Tests for Phase 1b: Term Lattice
;;; Tests term-lattice.rkt — lattice elements, merge function, contradiction
;;; detection, variable walking, ground check, and datum conversion.
;;;
;;; This is a pure unit test file — no prelude, driver, or elaborator needed.
;;; The term lattice is a leaf module with no project dependencies.
;;;

(require rackunit
         racket/match
         "../term-lattice.rkt")

;; ========================================
;; A. Sentinel values and predicates
;; ========================================

(test-case "term/bot-sentinel"
  (check-true (term-bot? term-bot))
  (check-false (term-bot? term-top))
  (check-false (term-bot? (term-var 0)))
  (check-false (term-bot? (term-ctor 'zero '()))))

(test-case "term/top-sentinel"
  (check-true (term-top? term-top))
  (check-false (term-top? term-bot))
  (check-false (term-top? (term-var 0)))
  (check-false (term-top? (term-ctor 'suc '(1)))))

(test-case "term/value-predicate"
  (check-false (term-value? term-bot))
  (check-false (term-value? term-top))
  (check-true (term-value? (term-var 0)))
  (check-true (term-value? (term-ctor 'zero '()))))

;; ========================================
;; B. Merge — bot identity
;; ========================================

(test-case "term/merge-bot-bot"
  (check-equal? (term-merge term-bot term-bot) term-bot))

(test-case "term/merge-bot-var"
  (define v (term-var 42))
  (check-equal? (term-merge term-bot v) v))

(test-case "term/merge-var-bot"
  (define v (term-var 42))
  (check-equal? (term-merge v term-bot) v))

(test-case "term/merge-bot-ctor"
  (define c (term-ctor 'zero '()))
  (check-equal? (term-merge term-bot c) c))

(test-case "term/merge-ctor-bot"
  (define c (term-ctor 'suc '(1)))
  (check-equal? (term-merge c term-bot) c))

;; ========================================
;; C. Merge — top absorption
;; ========================================

(test-case "term/merge-top-anything"
  (check-equal? (term-merge term-top term-bot) term-top)
  (check-equal? (term-merge term-top (term-var 0)) term-top)
  (check-equal? (term-merge term-top (term-ctor 'zero '())) term-top)
  (check-equal? (term-merge term-top term-top) term-top))

(test-case "term/merge-anything-top"
  (check-equal? (term-merge term-bot term-top) term-top)
  (check-equal? (term-merge (term-var 0) term-top) term-top)
  (check-equal? (term-merge (term-ctor 'zero '()) term-top) term-top))

;; ========================================
;; D. Merge — Var ⊔ Var (union-find link)
;; ========================================

(test-case "term/merge-var-var"
  ;; Var ⊔ Var returns the new var (union-find: old points to new)
  (define v1 (term-var 1))
  (define v2 (term-var 2))
  (check-equal? (term-merge v1 v2) v2))

(test-case "term/merge-var-var-same"
  ;; Same var: returns new (same id), no change semantically
  (define v (term-var 5))
  (check-equal? (term-merge v (term-var 5)) (term-var 5)))

;; ========================================
;; E. Merge — Var ⊔ Ctor / Ctor ⊔ Var (binding)
;; ========================================

(test-case "term/merge-var-ctor"
  ;; Var ⊔ Ctor = Ctor (bind the variable)
  (define v (term-var 1))
  (define c (term-ctor 'suc '(2)))
  (check-equal? (term-merge v c) c))

(test-case "term/merge-ctor-var"
  ;; Ctor ⊔ Var = Ctor (bind the variable, commutative)
  (define v (term-var 1))
  (define c (term-ctor 'zero '()))
  (check-equal? (term-merge c v) c))

;; ========================================
;; F. Merge — Ctor ⊔ Ctor
;; ========================================

(test-case "term/merge-ctor-same-tag-nullary"
  ;; zero ⊔ zero = zero (same constructor, no args)
  (define c (term-ctor 'zero '()))
  (check-equal? (term-merge c c) c))

(test-case "term/merge-ctor-same-tag-unary"
  ;; suc(cell1) ⊔ suc(cell2) = suc(cell1) (keep old, sub-cells merged separately)
  (define c1 (term-ctor 'suc '(10)))
  (define c2 (term-ctor 'suc '(20)))
  (check-equal? (term-merge c1 c2) c1))

(test-case "term/merge-ctor-same-tag-binary"
  ;; cons(cell1, cell2) ⊔ cons(cell3, cell4) = cons(cell1, cell2)
  (define c1 (term-ctor 'cons '(10 11)))
  (define c2 (term-ctor 'cons '(20 21)))
  (check-equal? (term-merge c1 c2) c1))

(test-case "term/merge-ctor-different-tags"
  ;; zero ⊔ suc(...) = top (contradiction)
  (define c1 (term-ctor 'zero '()))
  (define c2 (term-ctor 'suc '(1)))
  (check-equal? (term-merge c1 c2) term-top))

(test-case "term/merge-ctor-different-tags-same-arity"
  ;; true ⊔ false = top (contradiction, same arity but different tags)
  (define c1 (term-ctor 'true '()))
  (define c2 (term-ctor 'false '()))
  (check-equal? (term-merge c1 c2) term-top))

(test-case "term/merge-ctor-same-tag-different-arity"
  ;; Shouldn't happen in well-typed code, but handle gracefully
  (define c1 (term-ctor 'pair '(1 2)))
  (define c2 (term-ctor 'pair '(3 4 5)))
  (check-equal? (term-merge c1 c2) term-top))

;; ========================================
;; G. Contradiction check
;; ========================================

(test-case "term/contradiction-top"
  (check-true (term-contradiction? term-top)))

(test-case "term/contradiction-not-top"
  (check-false (term-contradiction? term-bot))
  (check-false (term-contradiction? (term-var 0)))
  (check-false (term-contradiction? (term-ctor 'zero '()))))

;; ========================================
;; H. Variable walking (term-walk)
;; ========================================

;; Helper: create a simple cell store (hash from cell-id → value)
(define (make-cell-store . pairs)
  (define h (make-hasheqv))
  (let loop ([ps pairs])
    (match ps
      ['() (void)]
      [(list* k v rest)
       (hash-set! h k v)
       (loop rest)]))
  (lambda (cid) (hash-ref h cid term-bot)))

(test-case "term/walk-non-var"
  ;; Walking a non-var returns it unchanged
  (define read (make-cell-store))
  (check-equal? (term-walk term-bot read) term-bot)
  (check-equal? (term-walk term-top read) term-top)
  (check-equal? (term-walk (term-ctor 'zero '()) read) (term-ctor 'zero '())))

(test-case "term/walk-var-to-ctor"
  ;; Var(0) → cell 0 holds Ctor('zero) → returns Ctor
  (define read (make-cell-store 0 (term-ctor 'zero '())))
  (check-equal? (term-walk (term-var 0) read) (term-ctor 'zero '())))

(test-case "term/walk-var-chain"
  ;; Var(0) → cell 0 holds Var(1) → cell 1 holds Ctor('suc, (2))
  (define read (make-cell-store
                0 (term-var 1)
                1 (term-ctor 'suc '(2))))
  (check-equal? (term-walk (term-var 0) read) (term-ctor 'suc '(2))))

(test-case "term/walk-var-to-bot"
  ;; Var(0) → cell 0 holds bot (unresolved variable)
  (define read (make-cell-store 0 term-bot))
  (check-equal? (term-walk (term-var 0) read) term-bot))

(test-case "term/walk-var-long-chain"
  ;; Var(0) → Var(1) → Var(2) → Ctor('zero)
  (define read (make-cell-store
                0 (term-var 1)
                1 (term-var 2)
                2 (term-ctor 'zero '())))
  (check-equal? (term-walk (term-var 0) read) (term-ctor 'zero '())))

(test-case "term/walk-var-cycle"
  ;; Var(0) → Var(1) → Var(0) → cycle!  Returns bot
  (define read (make-cell-store
                0 (term-var 1)
                1 (term-var 0)))
  (check-equal? (term-walk (term-var 0) read) term-bot))

;; ========================================
;; I. Ground check
;; ========================================

(test-case "term/ground-nullary-ctor"
  ;; zero is ground (no sub-cells)
  (define read (make-cell-store))
  (check-true (term-ground? (term-ctor 'zero '()) read)))

(test-case "term/ground-nested-ctor"
  ;; suc(cell0) where cell0 = zero → ground
  (define read (make-cell-store 0 (term-ctor 'zero '())))
  (check-true (term-ground? (term-ctor 'suc '(0)) read)))

(test-case "term/ground-deep-nested"
  ;; suc(cell0) where cell0 = suc(cell1) where cell1 = zero → ground
  (define read (make-cell-store
                0 (term-ctor 'suc '(1))
                1 (term-ctor 'zero '())))
  (check-true (term-ground? (term-ctor 'suc '(0)) read)))

(test-case "term/ground-with-var-resolved"
  ;; suc(cell0) where cell0 = Var(1) where cell1 = zero → ground
  (define read (make-cell-store
                0 (term-var 1)
                1 (term-ctor 'zero '())))
  (check-true (term-ground? (term-ctor 'suc '(0)) read)))

(test-case "term/ground-bot-not-ground"
  ;; bot is not ground
  (define read (make-cell-store))
  (check-false (term-ground? term-bot read)))

(test-case "term/ground-top-not-ground"
  ;; top is not ground
  (define read (make-cell-store))
  (check-false (term-ground? term-top read)))

(test-case "term/ground-unresolved-var"
  ;; suc(cell0) where cell0 = bot → not ground
  (define read (make-cell-store 0 term-bot))
  (check-false (term-ground? (term-ctor 'suc '(0)) read)))

(test-case "term/ground-partial-ctor"
  ;; cons(cell0, cell1) where cell0 = zero, cell1 = bot → not ground
  (define read (make-cell-store
                0 (term-ctor 'zero '())
                1 term-bot))
  (check-false (term-ground? (term-ctor 'cons '(0 1)) read)))

;; ========================================
;; J. Datum conversion (term->datum)
;; ========================================

(test-case "term/datum-bot"
  (define read (make-cell-store))
  (check-equal? (term->datum term-bot read) 'bot))

(test-case "term/datum-top"
  (define read (make-cell-store))
  (check-equal? (term->datum term-top read) 'top))

(test-case "term/datum-nullary-ctor"
  (define read (make-cell-store))
  (check-equal? (term->datum (term-ctor 'zero '()) read) 'zero))

(test-case "term/datum-unary-ctor"
  (define read (make-cell-store 0 (term-ctor 'zero '())))
  (check-equal? (term->datum (term-ctor 'suc '(0)) read) '(suc zero)))

(test-case "term/datum-nested-ctor"
  ;; suc(suc(zero)) = (suc (suc zero))
  (define read (make-cell-store
                0 (term-ctor 'suc '(1))
                1 (term-ctor 'zero '())))
  (check-equal? (term->datum (term-ctor 'suc '(0)) read) '(suc (suc zero))))

(test-case "term/datum-binary-ctor"
  ;; cons(zero, nil) = (cons zero nil)
  (define read (make-cell-store
                0 (term-ctor 'zero '())
                1 (term-ctor 'nil '())))
  (check-equal? (term->datum (term-ctor 'cons '(0 1)) read) '(cons zero nil)))

(test-case "term/datum-var-resolved"
  ;; Var(0) → cell 0 = zero → datum is 'zero
  (define read (make-cell-store 0 (term-ctor 'zero '())))
  (check-equal? (term->datum (term-var 0) read) 'zero))

(test-case "term/datum-var-unresolved"
  ;; Var(0) → cell 0 = bot → walks to bot → 'bot
  (define read (make-cell-store 0 term-bot))
  (check-equal? (term->datum (term-var 0) read) 'bot))

;; ========================================
;; K. Integration: merge sequences (simulating propagator writes)
;; ========================================

(test-case "term/merge-sequence-bot-var-ctor"
  ;; Simulate: cell starts at bot, gets Var, then gets Ctor
  (define v0 term-bot)
  (define v1 (term-merge v0 (term-var 1)))
  (check-true (term-var? v1))
  (define v2 (term-merge v1 (term-ctor 'zero '())))
  (check-true (term-ctor? v2))
  (check-equal? (term-ctor-tag v2) 'zero))

(test-case "term/merge-sequence-var-ctor-ctor-contradiction"
  ;; Cell gets Var, then bound to zero, then someone writes suc → contradiction
  (define v0 (term-var 1))
  (define v1 (term-merge v0 (term-ctor 'zero '())))
  (check-true (term-ctor? v1))
  (define v2 (term-merge v1 (term-ctor 'suc '(2))))
  (check-true (term-top? v2)))

(test-case "term/merge-sequence-ctor-ctor-compatible"
  ;; Cell gets suc(cell1), then another suc(cell2) — compatible
  (define v0 (term-ctor 'suc '(1)))
  (define v1 (term-merge v0 (term-ctor 'suc '(2))))
  ;; Should keep old (sub-cell unification handled separately)
  (check-true (term-ctor? v1))
  (check-equal? (term-ctor-tag v1) 'suc)
  (check-equal? (term-ctor-sub-cells v1) '(1)))

(test-case "term/merge-idempotent"
  ;; Merging same value is idempotent
  (define c (term-ctor 'zero '()))
  (check-equal? (term-merge c c) c)
  (define v (term-var 5))
  (check-equal? (term-merge v v) v))

(test-case "term/merge-top-is-absorbing-after-contradiction"
  ;; Once top, always top
  (define v0 term-top)
  (check-equal? (term-merge v0 (term-var 1)) term-top)
  (check-equal? (term-merge v0 (term-ctor 'zero '())) term-top)
  (check-equal? (term-merge v0 term-bot) term-top))
