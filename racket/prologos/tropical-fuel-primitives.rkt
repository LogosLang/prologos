#lang racket/base
;;;
;;; tropical-fuel-primitives.rkt — D.4 1V-6 F14 retirement (§11.X.5)
;;;
;;; Per docs/tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md
;;; §11.X.5 (1V Commit 6 mini-design): pure algebraic primitives extracted
;;; from tropical-fuel.rkt to a leaf module to break the import cycle:
;;;
;;;   propagator.rkt → (hypothetical) tropical-fuel.rkt
;;;                  → sre-core.rkt
;;;                  → propagator.rkt
;;;
;;; By isolating the algebraic primitives to a leaf module (zero non-Racket
;;; deps), propagator.rkt can require the primitives directly without
;;; triggering the cycle. The remaining SRE/merge-fn-registry integration
;;; lives in tropical-fuel.rkt and re-exports these primitives for backward
;;; compatibility with existing consumers.
;;;
;;; Two-layer separation (matches tropical-fuel.rkt:28-31 stated intent):
;;; - This file: PURE ALGEBRA (lattice + quantale primitives)
;;; - tropical-fuel.rkt: SRE-integration (domain registration, merge-registry)
;;;
;;; The split is a precedent for future tracks (PReduce, OE) that may face
;;; similar cycles between the network layer and SRE-integration modules.

(provide
 ;; Lattice constants
 tropical-fuel-bot           ;; = 0 (Lawvere bot in natural-order naming)
 tropical-fuel-top           ;; = +inf.0 (Lawvere top; algebraic contradiction)
 tropical-fuel-contradiction?  ;; = (= v +inf.0)
 ;; Algebraic primitives
 tropical-fuel-merge         ;; = min (Lawvere join)
 tropical-fuel-meet          ;; = max (Lawvere meet)
 tropical-fuel-tensor        ;; = + (cost composition)
 tropical-left-residual)     ;; (a b) -> (if (>= b a) (- b a) 0)

;; ============================================================
;; Lattice constants
;; ============================================================

;; Bot in natural-order naming (the smallest natural value).
;; In Lawvere convention this is the lattice TOP (highest in reversed order;
;; least committed; "zero cost" / "infinite remaining" abstract limit).
;; For fuel-cost cells: initial value when no budget is set (rare/abstract case).
(define tropical-fuel-bot 0)

;; Top in natural-order naming (the largest extended-real).
;; In Lawvere convention this is the lattice BOT (lowest in reversed order;
;; most committed; algebraic contradiction).
(define tropical-fuel-top +inf.0)

;; Contradiction predicate — value reached the algebraic top.
;; Note: for remaining-fuel cells, operational exhaustion at (<= v 0) is
;; the cell's on-write-check concern, NOT this predicate. This predicate
;; serves as algebraic safety net for the rare/abstract case where a cell
;; reaches +inf.0 directly.
(define (tropical-fuel-contradiction? v)
  (= v +inf.0))

;; ============================================================
;; Algebraic primitives
;; ============================================================

;; Merge function (Lawvere join, ⊕): min.
;; - Idempotent: (min a a) = a
;; - Commutative: (min a b) = (min b a)
;; - Associative: (min a (min b c)) = (min (min a b) c)
;; - Identity (for ⊕): +inf.0 (top in Lawvere; (min +inf.0 a) = a)
;;
;; For fuel-cost cells (remaining-fuel semantic): writes lower the remaining;
;; min correctly takes the lower (more-committed) value. Under speculation
;; with tagged-cell-value reconciliation across worldviews, min picks the
;; cheapest (most-remaining-fuel) worldview — the "best case" cost estimate.
(define (tropical-fuel-merge a b)
  (min a b))

;; Meet function (Lawvere meet, ⋀): max.
;; - Idempotent, commutative, associative
;; - Identity (for ⋀): 0 (bot in natural-order naming; (max 0 a) = a for a ≥ 0)
;;
;; Registered via meet-registry for downstream consumers (e.g., Phase 3C
;; UC2 cost-bounded elaboration's worst-case analysis).
(define (tropical-fuel-meet a b)
  (max a b))

;; Tensor (⊗, cost composition): +.
;; - Commutative, associative
;; - Unit (for ⊗): 0 ((+ 0 a) = a) — zero-cost operation
;; - Absorbing element (top of ⊕): +inf.0 ((+ +inf.0 a) = +inf.0 per IEEE 754)
;; - Distributes over ⊕ (the join): (+ a (min b c)) = (min (+ a b) (+ a c))
;;
;; For fuel-cost cells: caller uses tensor to compute remaining after multiple
;; steps: (- current (tropical-fuel-tensor cost-step-1 cost-step-2 ...)).
(define (tropical-fuel-tensor a b)
  (+ a b))

;; Left residuation (a \ b): (if (>= b a) (- b a) 0).
;; - The unique f such that (a ⊗ f) ≤_rev b — i.e., the "remaining budget
;;   after committing a from b" (b's overshoot of a; 0 if a > b means overspend)
;; - Adjunction law: (a ⊗ x) ≤_rev b ⟺ x ≤_rev (a \ b)
;;   — i.e., (>= (+ a x) b) ⟺ (>= x (tropical-left-residual a b))
;;
;; Read-time pure function (per Q-1B-4 lean). Phase 3C consumers wrap in
;; propagator if needed for backward error explanation use cases.
(define (tropical-left-residual a b)
  (if (>= b a) (- b a) 0))
