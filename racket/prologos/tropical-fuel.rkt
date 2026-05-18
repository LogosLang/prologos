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

(require "tropical-fuel-primitives.rkt"  ;; D.4 1V-6 F14 retirement (§11.X.5):
                                          ;; algebraic primitives extracted to leaf
                                          ;; module to break propagator.rkt cycle
         "sre-core.rkt"
         "merge-fn-registry.rkt")

(provide
 ;; Lattice constants (re-exported from tropical-fuel-primitives.rkt for backward compat)
 tropical-fuel-bot           ;; = 0 (Lawvere bot in natural-order naming)
 tropical-fuel-top           ;; = +inf.0 (Lawvere top; algebraic contradiction)
 tropical-fuel-contradiction?  ;; = (= v +inf.0)
 ;; Algebraic primitives (re-exported)
 tropical-fuel-merge         ;; = min (Lawvere join)
 tropical-fuel-meet          ;; = max (Lawvere meet)
 tropical-fuel-tensor        ;; = + (cost composition)
 tropical-left-residual      ;; (a b) -> (if (>= b a) (- b a) 0)
 ;; SRE domain (referenced by registrations + downstream consumers)
 tropical-fuel-sre-domain)

;; ============================================================
;; Algebraic primitives + lattice constants — MOVED to tropical-fuel-primitives.rkt
;; D.4 1V-6 F14 retirement (§11.X.5): extracted to leaf module to break the
;; propagator.rkt → tropical-fuel.rkt → sre-core.rkt → propagator.rkt cycle.
;; This file re-exports them (above) for backward compat with existing
;; consumers. The two-layer separation matches this file's original stated
;; intent (preamble lines 28-31): primitives = pure algebra; this file =
;; SRE-integration. See tropical-fuel-primitives.rkt for the primitive
;; definitions + their algebraic properties documentation.
;; ============================================================

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
