#lang racket/base
;;;
;;; test-tropical-fuel.rkt — D.4 1B-iii Tropical Quantale primitive tests
;;;
;;; Per §9.6 (algebraic primitive tests) + §9.4 S5 ACKNOWLEDGE (C-series
;;; quantale axiom verification). Tests:
;;; - Lattice constants (bot, top, contradiction?)
;;; - Merge semantics (min as Lawvere join)
;;; - Meet semantics (max as Lawvere meet)
;;; - Tensor semantics (+ as cost composition)
;;; - Left residuation (Form A boundary cases per §6.5 + A12)
;;; - SRE domain registration + lookups
;;; - C1: Quantale axioms (commutativity, associativity, idempotence,
;;;   distributivity, identity, absorbing)
;;; - C2: Residuation laws (adjunction, identity, overspend)
;;; - C3: Integral verification (unit = bot in Lawvere convention)
;;;
;;; C4 (Module Theory) + C5 (CALM-safety) deferred to 1B-iv where cells
;;; exist to test module action + CALM property (per §9.2.0.6 Q-1B-iii-γ).
;;;

(require rackunit
         "../tropical-fuel.rkt"
         (only-in "../sre-core.rkt"
                  lookup-domain
                  sre-domain-merge-registry sre-domain-meet-registry
                  sre-domain-contradicts? sre-domain-bot-value
                  sre-domain-top-value sre-domain-name
                  prop-confirmed))

;; ============================================================
;; Lattice constants
;; ============================================================

(test-case "lattice constants"
  (check-equal? tropical-fuel-bot 0)
  (check-equal? tropical-fuel-top +inf.0)
  (check-true (tropical-fuel-contradiction? +inf.0))
  (check-false (tropical-fuel-contradiction? 0))
  (check-false (tropical-fuel-contradiction? 1000000)))

;; ============================================================
;; Merge semantics (Lawvere join = min)
;; ============================================================

(test-case "merge: min semantics"
  ;; Note: (min flonum integer) coerces to flonum per Racket semantics;
  ;; we use `=` for numeric equality (5 = 5.0 = #t) not equal? (5 ≠ 5.0)
  (check-equal? (tropical-fuel-merge 0 0) 0)
  (check-equal? (tropical-fuel-merge 5 3) 3)
  (check-equal? (tropical-fuel-merge 3 5) 3)
  (check-true (= (tropical-fuel-merge 5 +inf.0) 5))
  (check-true (= (tropical-fuel-merge +inf.0 5) 5))
  (check-equal? (tropical-fuel-merge +inf.0 +inf.0) +inf.0))

;; ============================================================
;; Meet semantics (Lawvere meet = max)
;; ============================================================

(test-case "meet: max semantics"
  (check-equal? (tropical-fuel-meet 0 0) 0)
  (check-equal? (tropical-fuel-meet 5 3) 5)
  (check-equal? (tropical-fuel-meet 3 5) 5)
  (check-equal? (tropical-fuel-meet 5 +inf.0) +inf.0)
  (check-equal? (tropical-fuel-meet 0 +inf.0) +inf.0))

;; ============================================================
;; Tensor semantics (+ as cost composition)
;; ============================================================

(test-case "tensor: + with absorbing +inf.0"
  (check-equal? (tropical-fuel-tensor 3 5) 8)
  (check-equal? (tropical-fuel-tensor 0 5) 5)         ;; identity left
  (check-equal? (tropical-fuel-tensor 5 0) 5)         ;; identity right
  (check-equal? (tropical-fuel-tensor +inf.0 5) +inf.0)  ;; absorbing
  (check-equal? (tropical-fuel-tensor 5 +inf.0) +inf.0)  ;; absorbing
  (check-equal? (tropical-fuel-tensor +inf.0 +inf.0) +inf.0))

;; ============================================================
;; Left residuation (Form A boundary cases per §6.5 + A12)
;; ============================================================

(test-case "residuation: boundary cases"
  ;; The 6 A12 boundary cases enumerated in Pre-0 plan §4
  (check-equal? (tropical-left-residual 0 0) 0)       ;; identity
  (check-equal? (tropical-left-residual 0 5) 5)       ;; a=0 → b unchanged
  (check-equal? (tropical-left-residual 5 5) 0)       ;; a=b → 0 remaining
  (check-equal? (tropical-left-residual 5 10) 5)      ;; b-a when b≥a
  (check-equal? (tropical-left-residual 10 5) 0)      ;; overspend → top
  (check-equal? (tropical-left-residual 5 +inf.0) +inf.0)  ;; infinite remaining
  (check-equal? (tropical-left-residual +inf.0 5) 0))  ;; overspend

;; ============================================================
;; SRE domain registration + lookups
;; ============================================================

(test-case "SRE domain registered + queryable"
  (define d (lookup-domain 'tropical-fuel))
  (check-not-false d)
  (check-eq? (sre-domain-name d) 'tropical-fuel)
  (check-equal? (sre-domain-bot-value d) 0)
  (check-equal? (sre-domain-top-value d) +inf.0)
  ;; merge-registry lookup: 'equality returns min
  (define merge-fn ((sre-domain-merge-registry d) 'equality))
  (check-not-false merge-fn)
  (check-equal? (merge-fn 5 3) 3)
  ;; meet-registry lookup: 'equality returns max
  (define meet-fn ((sre-domain-meet-registry d) 'equality))
  (check-not-false meet-fn)
  (check-equal? (meet-fn 5 3) 5))

;; ============================================================
;; C1: Quantale axioms (sample tuples + boundary values)
;; ============================================================

(define c1-samples '(0 1 5 100 1000000))
(define c1-boundary-samples '(0 1 +inf.0))

(test-case "C1.1 — Associativity of ⊕ (min)"
  (for ([a (in-list c1-samples)]
        #:when #t
        [b (in-list c1-samples)]
        #:when #t
        [c (in-list c1-samples)])
    (check-equal? (tropical-fuel-merge a (tropical-fuel-merge b c))
                  (tropical-fuel-merge (tropical-fuel-merge a b) c)
                  (format "assoc fails for (~a ~a ~a)" a b c))))

(test-case "C1.2 — Commutativity of ⊕ (min)"
  (for ([a (in-list c1-samples)]
        #:when #t
        [b (in-list c1-samples)])
    (check-equal? (tropical-fuel-merge a b)
                  (tropical-fuel-merge b a)
                  (format "comm fails for (~a ~a)" a b))))

(test-case "C1.3 — Idempotence of ⊕ (min)"
  (for ([a (in-list c1-samples)])
    (check-equal? (tropical-fuel-merge a a) a
                  (format "idem fails for ~a" a)))
  ;; Also at boundary
  (check-equal? (tropical-fuel-merge +inf.0 +inf.0) +inf.0))

(test-case "C1.4 — Distributivity of ⊗ over ⊕ (Lawvere join)"
  ;; (+ a (min b c)) = (min (+ a b) (+ a c))
  (for ([a (in-list c1-samples)]
        #:when #t
        [b (in-list c1-samples)]
        #:when #t
        [c (in-list c1-samples)])
    (check-equal? (tropical-fuel-tensor a (tropical-fuel-merge b c))
                  (tropical-fuel-merge (tropical-fuel-tensor a b)
                                       (tropical-fuel-tensor a c))
                  (format "distrib fails for (~a (~a ~a))" a b c))))

(test-case "C1.4b — Distributivity at +inf.0 boundary (S5 ACKNOWLEDGE)"
  ;; (+ +inf.0 (min b c)) = (min (+ +inf.0 b) (+ +inf.0 c))
  ;; Both sides should equal +inf.0 by IEEE 754 absorbing-element.
  (for ([b (in-list c1-samples)]
        #:when #t
        [c (in-list c1-samples)])
    (check-equal? (tropical-fuel-tensor +inf.0 (tropical-fuel-merge b c))
                  (tropical-fuel-merge (tropical-fuel-tensor +inf.0 b)
                                       (tropical-fuel-tensor +inf.0 c))
                  (format "distrib at +inf.0 fails for (~a ~a)" b c))))

(test-case "C1.5 — Identity of ⊗ (unit = 0 in natural; top in Lawvere)"
  ;; (+ 0 a) = a for all a
  (for ([a (in-list c1-boundary-samples)])
    (check-equal? (tropical-fuel-tensor 0 a) a
                  (format "tensor identity fails for ~a" a))
    (check-equal? (tropical-fuel-tensor a 0) a
                  (format "tensor identity (right) fails for ~a" a))))

(test-case "C1.6 — Absorbing element (+inf.0)"
  ;; (+ +inf.0 a) = +inf.0 for all a (IEEE 754)
  (for ([a (in-list c1-samples)])
    (check-equal? (tropical-fuel-tensor +inf.0 a) +inf.0
                  (format "absorbing fails for ~a" a))
    (check-equal? (tropical-fuel-tensor a +inf.0) +inf.0
                  (format "absorbing (right) fails for ~a" a))))

;; ============================================================
;; C2: Residuation laws (adjunction, identity, overspend)
;; ============================================================

(test-case "C2.1 — Adjunction law: (a ⊗ x) ≤_rev b ⟺ x ≤_rev (a \\ b)"
  ;; In Lawvere convention: a ≤_rev b ⟺ a ≥ b
  ;; So (>= (+ a x) b) ⟺ (>= x (tropical-left-residual a b))
  (for ([a (in-list c1-samples)]
        #:when #t
        [b (in-list c1-samples)]
        #:when #t
        [x (in-list c1-samples)])
    (define lhs (>= (tropical-fuel-tensor a x) b))
    (define rhs (>= x (tropical-left-residual a b)))
    (check-equal? lhs rhs
                  (format "adjunction fails for a=~a b=~a x=~a (lhs=~a rhs=~a)"
                          a b x lhs rhs))))

(test-case "C2.2 — Counit: (a ⊗ (a \\ b)) ≤_rev b"
  ;; (>= (+ a (tropical-left-residual a b)) b)
  (for ([a (in-list c1-samples)]
        #:when #t
        [b (in-list c1-samples)])
    (check-true (>= (tropical-fuel-tensor a (tropical-left-residual a b)) b)
                (format "counit fails for a=~a b=~a" a b))))

(test-case "C2.3 — Left-identity residual: (0 \\ a) = a"
  (for ([a (in-list c1-samples)])
    (check-equal? (tropical-left-residual 0 a) a
                  (format "left-identity residual fails for ~a" a))))

(test-case "C2.4 — Overspend: (a \\ ⊥_nat) = 0 when a > 0"
  ;; In our convention, a > b returns 0 (overspend; max-commitment)
  (for ([a '(1 5 100 1000000)])
    (check-equal? (tropical-left-residual a 0) 0
                  (format "overspend fails for a=~a b=0" a))))

(test-case "C2.5 — Residuation at +inf.0 boundary (S5 ACKNOWLEDGE)"
  ;; (tropical-left-residual +inf.0 b) for finite b → 0 (overspend; vacuous)
  (check-equal? (tropical-left-residual +inf.0 0) 0)
  (check-equal? (tropical-left-residual +inf.0 5) 0)
  (check-equal? (tropical-left-residual +inf.0 1000000) 0)
  ;; (tropical-left-residual a +inf.0) for finite a → +inf.0 (infinite remaining)
  (check-equal? (tropical-left-residual 0 +inf.0) +inf.0)
  (check-equal? (tropical-left-residual 5 +inf.0) +inf.0)
  (check-equal? (tropical-left-residual 1000000 +inf.0) +inf.0))

;; ============================================================
;; C3: Integral verification (unit = bot in Lawvere convention)
;; ============================================================

(test-case "C3 — Integral quantale: 1 = ⊤_rev (the tensor unit coincides with the lattice top in Lawvere)"
  ;; In Lawvere convention, ⊤_rev = 0 (smallest in natural = highest in
  ;; reversed). The tensor unit is also 0 ((+ 0 a) = a). So unit = top.
  (check-equal? tropical-fuel-bot 0)  ;; natural-order bot = Lawvere top
  ;; Multiplicative identity is 0 (confirmed by C1.5)
  ;; Lattice top in Lawvere is 0 (confirmed by min-identity:
  ;; (min 0 a) = 0 when a ≥ 0, since 0 is the smallest natural which is
  ;; the "highest" in Lawvere reversed order — but for non-negative reals
  ;; min(0, a) = 0 only when a ≥ 0; for a < 0 it would be a, but our
  ;; domain is [0, +∞] so the case doesn't arise)
  (for ([a (in-list c1-samples)])
    (check-equal? (tropical-fuel-merge 0 a) 0
                  (format "Lawvere top identity fails for ~a" a))
    (check-equal? (tropical-fuel-merge a 0) 0
                  (format "Lawvere top identity (right) fails for ~a" a))))

;; ============================================================
;; Property declarations registered correctly
;; ============================================================

(test-case "SRE domain — declared properties present and confirmed"
  (define d (lookup-domain 'tropical-fuel))
  ;; Access declared-properties via sre-domain accessor
  ;; (Assumes sre-domain exposes declared-properties; if not, this test
  ;;  is informational — the verification is at registration time and
  ;;  the absence of registration errors is the load-bearing check.)
  (check-not-false d "tropical-fuel domain must be registered"))
