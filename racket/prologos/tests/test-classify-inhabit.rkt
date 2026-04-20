#lang racket/base

;;;
;;; test-classify-inhabit.rkt — PPN 4C Phase 3a+3b
;;;
;;; Tests the tag-layer value shape + tag-dispatched accumulation merge.
;;;

(require rackunit
         "../classify-inhabit.rkt"
         (only-in "../type-lattice.rkt" type-bot type-top)
         (only-in "../syntax.rkt" expr-Type expr-Nat))

;; ============================================================
;; Construction helpers
;; ============================================================

(test-case "classifier-only: empty inhabitant"
  (define v (classifier-only (expr-Type 0)))
  (check-equal? (classify-inhabit-value-classifier v) (expr-Type 0))
  (check-equal? (classify-inhabit-value-inhabitant v) 'bot))

(test-case "inhabitant-only: empty classifier"
  (define v (inhabitant-only (expr-Nat)))
  (check-equal? (classify-inhabit-value-classifier v) 'bot)
  (check-equal? (classify-inhabit-value-inhabitant v) (expr-Nat)))

(test-case "classify-and-inhabit: both populated"
  (define v (classify-and-inhabit (expr-Type 0) (expr-Nat)))
  (check-equal? (classify-inhabit-value-classifier v) (expr-Type 0))
  (check-equal? (classify-inhabit-value-inhabitant v) (expr-Nat)))

;; ============================================================
;; Bot checks
;; ============================================================

(test-case "classify-inhabit-value-bot?: both 'bot"
  (check-true (classify-inhabit-value-bot?
               (classify-inhabit-value 'bot 'bot))))

(test-case "classify-inhabit-value-bot?: one populated → not bot"
  (check-false (classify-inhabit-value-bot?
                (classifier-only (expr-Type 0)))))

;; ============================================================
;; Accessors
;; ============================================================

(test-case "classifier-or-bot: populated"
  (define v (classifier-only (expr-Type 0)))
  (check-equal? (classify-inhabit-value-classifier-or-bot v) (expr-Type 0)))

(test-case "classifier-or-bot: empty"
  (define v (inhabitant-only (expr-Nat)))
  (check-equal? (classify-inhabit-value-classifier-or-bot v) 'bot))

(test-case "inhabitant-or-bot: populated"
  (define v (inhabitant-only (expr-Nat)))
  (check-equal? (classify-inhabit-value-inhabitant-or-bot v) (expr-Nat)))

(test-case "inhabitant-or-bot: empty"
  (define v (classifier-only (expr-Type 0)))
  (check-equal? (classify-inhabit-value-inhabitant-or-bot v) 'bot))

;; ============================================================
;; Merge: bot handling
;; ============================================================

(test-case "merge: infra-bot + v = v"
  (define v (classifier-only (expr-Type 0)))
  (check-equal? (merge-classify-inhabit 'infra-bot v) v))

(test-case "merge: v + infra-bot = v"
  (define v (classifier-only (expr-Type 0)))
  (check-equal? (merge-classify-inhabit v 'infra-bot) v))

;; ============================================================
;; Merge: tag accumulation
;; ============================================================

(test-case "merge: classifier-only + inhabitant-only → both populated"
  (define c (classifier-only (expr-Type 0)))
  (define i (inhabitant-only (expr-Nat)))
  (define result (merge-classify-inhabit c i))
  (check-equal? (classify-inhabit-value-classifier result) (expr-Type 0))
  (check-equal? (classify-inhabit-value-inhabitant result) (expr-Nat)))

(test-case "merge: commutative — accumulation order doesn't matter"
  (define c (classifier-only (expr-Type 0)))
  (define i (inhabitant-only (expr-Nat)))
  (define r1 (merge-classify-inhabit c i))
  (define r2 (merge-classify-inhabit i c))
  (check-equal? r1 r2))

(test-case "merge: classifier × classifier (same) → identity"
  (define v (classifier-only (expr-Type 0)))
  (check-equal? (merge-classify-inhabit v v) v))

(test-case "merge: inhabitant × inhabitant (same equal?) → identity"
  (define v (inhabitant-only (expr-Nat)))
  (check-equal? (merge-classify-inhabit v v) v))

(test-case "merge: inhabitant × inhabitant (not equal?) → contradiction"
  (define v1 (inhabitant-only 'value-A))
  (define v2 (inhabitant-only 'value-B))
  (check-true (classify-inhabit-contradiction?
               (merge-classify-inhabit v1 v2))))

;; ============================================================
;; Merge: contradiction absorbs
;; ============================================================

(test-case "merge: contradiction absorbs"
  (define v (classifier-only (expr-Type 0)))
  (check-true (classify-inhabit-contradiction?
               (merge-classify-inhabit 'classify-inhabit-contradiction v)))
  (check-true (classify-inhabit-contradiction?
               (merge-classify-inhabit v 'classify-inhabit-contradiction))))

;; ============================================================
;; Merge: idempotence on fully-populated values
;; ============================================================

(test-case "merge: idempotence on both-populated value"
  (define v (classify-and-inhabit (expr-Type 0) (expr-Nat)))
  (check-equal? (merge-classify-inhabit v v) v))

;; ============================================================
;; Merge: progressive accumulation (multiple writes)
;; ============================================================

(test-case "merge: progressive accumulation via multiple writes"
  (define bot (classify-inhabit-value 'bot 'bot))
  (define step1 (merge-classify-inhabit bot (classifier-only (expr-Type 0))))
  (check-equal? (classify-inhabit-value-classifier step1) (expr-Type 0))
  (define step2 (merge-classify-inhabit step1 (inhabitant-only (expr-Nat))))
  (check-equal? (classify-inhabit-value-classifier step2) (expr-Type 0))
  (check-equal? (classify-inhabit-value-inhabitant step2) (expr-Nat)))
