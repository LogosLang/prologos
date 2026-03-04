#lang racket/base

;;;
;;; mult-lattice.rkt — Multiplicity lattice for QTT propagator cells
;;;
;;; Defines the merge function (lattice join) for multiplicity-valued cells.
;;; This is a 5-element lattice:
;;;
;;;   mult-bot  (⊥, no information — fresh mult-meta)
;;;       ↓
;;;   m0 / m1 / mw  (concrete multiplicities, incomparable)
;;;       ↓
;;;   mult-top  (⊤, contradiction — incompatible mults)
;;;
;;; The merge function: bot ⊔ x = x, x ⊔ x = x, x ⊔ y = top (x ≠ y).
;;; This is the standard flat lattice over {m0, m1, mw}.
;;;
;;; CRITICAL: This module is a PURE LEAF — requires only racket/base.
;;; No project dependencies. Used by elaborator-network.rkt and metavar-store.rkt.
;;;

(provide mult-bot mult-top mult-bot? mult-top?
         mult-lattice-merge
         mult-lattice-contradicts?)

;; ========================================
;; Sentinel values
;; ========================================

(define mult-bot 'mult-bot)
(define mult-top 'mult-top)

(define (mult-bot? v) (eq? v 'mult-bot))
(define (mult-top? v) (eq? v 'mult-top))

;; ========================================
;; Concrete multiplicities (re-exported for convenience)
;; ========================================
;; These are the same symbols used throughout the QTT system:
;;   'm0 — erased (compile-time only, zero runtime uses)
;;   'm1 — linear (exactly one runtime use)
;;   'mw — unrestricted (any number of runtime uses)

;; ========================================
;; Merge (lattice join)
;; ========================================

;; Flat lattice merge: bot ⊔ x = x, x ⊔ x = x, x ⊔ y = top when x ≠ y.
(define (mult-lattice-merge old new)
  (cond
    [(mult-bot? old) new]
    [(mult-bot? new) old]
    [(mult-top? old) mult-top]
    [(mult-top? new) mult-top]
    [(eq? old new) old]
    [else mult-top]))

;; ========================================
;; Contradiction check
;; ========================================

(define (mult-lattice-contradicts? v) (mult-top? v))
