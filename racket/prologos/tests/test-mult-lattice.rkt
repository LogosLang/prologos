#lang racket/base

;;;
;;; Tests for P5a: Multiplicity Lattice
;;;
;;; Verifies the 5-element flat lattice for QTT multiplicities:
;;; mult-bot < {m0, m1, mw} < mult-top
;;;

(require rackunit
         "../mult-lattice.rkt")

;; ========================================
;; Sentinel identity
;; ========================================

(test-case "mult-bot/identity"
  (check-true (mult-bot? mult-bot))
  (check-false (mult-bot? 'm0))
  (check-false (mult-bot? mult-top)))

(test-case "mult-top/identity"
  (check-true (mult-top? mult-top))
  (check-false (mult-top? 'mw))
  (check-false (mult-top? mult-bot)))

;; ========================================
;; Merge: bot is identity
;; ========================================

(test-case "merge/bot-left"
  (check-eq? (mult-lattice-merge mult-bot 'm0) 'm0)
  (check-eq? (mult-lattice-merge mult-bot 'm1) 'm1)
  (check-eq? (mult-lattice-merge mult-bot 'mw) 'mw))

(test-case "merge/bot-right"
  (check-eq? (mult-lattice-merge 'm0 mult-bot) 'm0)
  (check-eq? (mult-lattice-merge 'm1 mult-bot) 'm1)
  (check-eq? (mult-lattice-merge 'mw mult-bot) 'mw))

(test-case "merge/bot-bot"
  (check-eq? (mult-lattice-merge mult-bot mult-bot) mult-bot))

;; ========================================
;; Merge: same value = idempotent
;; ========================================

(test-case "merge/same-value"
  (check-eq? (mult-lattice-merge 'm0 'm0) 'm0)
  (check-eq? (mult-lattice-merge 'm1 'm1) 'm1)
  (check-eq? (mult-lattice-merge 'mw 'mw) 'mw))

;; ========================================
;; Merge: different values = top (contradiction)
;; ========================================

(test-case "merge/different-values"
  (check-eq? (mult-lattice-merge 'm0 'm1) mult-top)
  (check-eq? (mult-lattice-merge 'm0 'mw) mult-top)
  (check-eq? (mult-lattice-merge 'm1 'mw) mult-top)
  (check-eq? (mult-lattice-merge 'm1 'm0) mult-top)
  (check-eq? (mult-lattice-merge 'mw 'm0) mult-top)
  (check-eq? (mult-lattice-merge 'mw 'm1) mult-top))

;; ========================================
;; Merge: top absorbs everything
;; ========================================

(test-case "merge/top-absorbs"
  (check-eq? (mult-lattice-merge mult-top 'm0) mult-top)
  (check-eq? (mult-lattice-merge mult-top 'm1) mult-top)
  (check-eq? (mult-lattice-merge mult-top 'mw) mult-top)
  (check-eq? (mult-lattice-merge 'm0 mult-top) mult-top)
  (check-eq? (mult-lattice-merge mult-top mult-bot) mult-top)
  (check-eq? (mult-lattice-merge mult-bot mult-top) mult-top)
  (check-eq? (mult-lattice-merge mult-top mult-top) mult-top))

;; ========================================
;; Contradicts
;; ========================================

(test-case "contradicts/top-only"
  (check-true (mult-lattice-contradicts? mult-top))
  (check-false (mult-lattice-contradicts? mult-bot))
  (check-false (mult-lattice-contradicts? 'm0))
  (check-false (mult-lattice-contradicts? 'm1))
  (check-false (mult-lattice-contradicts? 'mw)))
