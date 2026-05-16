#lang racket/base
;;;
;;; tropical-fuel.rkt — D.4 1B-iii Tropical Quantale primitive
;;;
;;; Per docs/tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md
;;; §9 + §9.2.0.6 (1B-iii mini-design resolutions).
;;;
;;; Ships:
;;; - Lattice constants (bot, top, contradiction?)
;;; - Algebraic primitives: merge (= min, the Lawvere join),
;;;   meet (= max, the Lawvere meet), tensor (= +, cost composition),
;;;   left-residual (= b - a when b ≥ a else 0)
;;; - SRE domain registration with full quantale property declarations
;;;   (commutative-quantale + integral-quantale + residuated + ...)
;;;
;;; Algebraic structure: T_min = ([0, +∞], ≤_rev, +, 0) per Stage 1 research
;;; §9 (Lawvere convention; smaller cost = higher in lattice).
;;;
;;; Operational semantic (for fuel-cost-cell registration at 1B-iv):
;;; - Cells using this domain store REMAINING FUEL (per Q-1B-iii-α Option A)
;;; - Cell initial value = budget (e.g., 1M)
;;; - Writes decrement: (net-cell-write net cid (- current n))
;;; - Operational exhaustion at (<= remaining 0) — registered as the cell's
;;;   on-write-check (NOT the SRE domain's contradicts?)
;;; - SRE domain's contradicts?=(= v +inf.0) captures algebraic top
;;;   (unreachable via normal decrement; serves as safety net)
;;; - The cost framing remains as a derived concept: cost = budget - remaining
;;;
;;; The two-layer separation (abstract algebra in SRE domain; operational
;;; semantics in cell on-write-check) is architecturally clean — SRE captures
;;; what the lattice IS; cell captures HOW a specific instance is used.

(require "sre-core.rkt"
         "merge-fn-registry.rkt")

(provide
 ;; Lattice constants
 tropical-fuel-bot           ;; = 0 (Lawvere bot in natural-order naming)
 tropical-fuel-top           ;; = +inf.0 (Lawvere top; algebraic contradiction)
 tropical-fuel-contradiction?  ;; = (= v +inf.0)
 ;; Algebraic primitives
 tropical-fuel-merge         ;; = min (Lawvere join)
 tropical-fuel-meet          ;; = max (Lawvere meet)
 tropical-fuel-tensor        ;; = + (cost composition)
 tropical-left-residual      ;; (a b) -> (if (>= b a) (- b a) 0)
 ;; SRE domain (referenced by registrations + downstream consumers)
 tropical-fuel-sre-domain)

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

;; ============================================================
;; merge-registry (function: relation-name → merge-fn or #f)
;; ============================================================
;; For SRE domain integration. The domain supports the 'equality relation
;; with tropical-fuel-merge. Other relations return #f (unsupported).
;; Future tracks may extend (e.g., 'subtyping for cost-bounded ordering).
(define (tropical-fuel-merge-registry relation-name)
  (case relation-name
    [(equality) tropical-fuel-merge]
    [else #f]))

;; meet-registry (Track 2I-style): supports 'equality relation with
;; tropical-fuel-meet for downstream meet-based dispatch.
(define (tropical-fuel-meet-registry relation-name)
  (case relation-name
    [(equality) tropical-fuel-meet]
    [else #f]))

;; ============================================================
;; SRE domain registration with full quantale property declarations
;; ============================================================
;; Per §9.4. Properties declared at registration time; verified via SRE
;; Track 2I property-sweep infrastructure post-registration (see 1B-iii
;; post-impl consideration: §9.2.0.6 Q-1B-iii-β user note).

(define tropical-fuel-sre-domain
  (make-sre-domain
   #:name 'tropical-fuel
   #:merge-registry tropical-fuel-merge-registry
   #:meet-registry  tropical-fuel-meet-registry
   #:contradicts?   tropical-fuel-contradiction?
   #:bot?           (lambda (v) (= v tropical-fuel-bot))
   #:bot-value      tropical-fuel-bot
   #:top-value      tropical-fuel-top
   #:classification 'value  ;; atomic extended-real (per D.1 §9.4)
   #:declared-properties
   (hasheq 'equality
           (hasheq
            ;; Core lattice properties
            'commutative-join     prop-confirmed
            'associative-join     prop-confirmed
            'idempotent-join      prop-confirmed
            'has-meet             prop-confirmed
            'distributive         prop-confirmed
            ;; Quantale properties (§9.3 + research §3)
            'quantale             prop-confirmed
            'commutative-quantale prop-confirmed
            'unital-quantale      prop-confirmed
            'integral-quantale    prop-confirmed
            'residuated           prop-confirmed
            'has-pseudo-complement prop-confirmed))
   #:operations
   (hasheq 'tensor   (hasheq 'fn tropical-fuel-tensor
                             'properties '(distributes-over-join
                                           associative
                                           has-identity
                                           commutative))
           'residual (hasheq 'fn tropical-left-residual
                             'properties '(adjoint-to-tensor)))))

(register-domain! tropical-fuel-sre-domain)
(register-merge-fn!/lattice tropical-fuel-merge #:for-domain 'tropical-fuel)
