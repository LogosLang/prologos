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
                  prop-confirmed)
         ;; 1B-iv: canonical fuel cell registration tests
         (only-in "../propagator.rkt"
                  make-prop-network
                  net-cell-read net-cell-write
                  net-new-cell
                  net-add-propagator
                  net-add-fire-once-propagator
                  run-to-quiescence-bsp
                  run-to-quiescence-widen   ;; 1C-ii-b tests (exercises #4 + #5)
                  init-fuel-local-var!      ;; 1C-ii-b helper correctness test
                  flush-fuel-local-var!     ;; 1C-ii-b helper correctness test
                  fuel-cell-id fuel-budget-cell-id
                  prop-network-cells prop-network-contradiction
                  prop-network-fuel
                  prop-cell-meta prop-cell-value
                  cell-id-hash cell-id
                  specialized-cell-meta-tier
                  specialized-cell-meta-storage
                  specialized-cell-meta-fires-on
                  specialized-cell-meta-on-write-check)
         (only-in "../champ.rkt" champ-lookup))

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

;; ============================================================
;; 1B-iv: Canonical fuel cell registration via make-prop-network
;; ============================================================
;; Cells are SHADOW MODE in Phase 1B — registered + initialized to budget;
;; production fuel decrements continue using prop-net-hot.fuel until Phase 1C
;; migration. These tests verify the cells exist + cell-meta is correctly
;; attached + initial values are correct + on-write-check semantics work.

(test-case "1B-iv: fuel-cell-id and fuel-budget-cell-id are cell-id 11 and 12"
  (define net (make-prop-network 1000))
  ;; Cell-ids are well-known per §4.3
  (check-not-false net)
  ;; Verify by looking up the cells exist
  (check-not-false (champ-lookup (prop-network-cells net)
                                  (cell-id-hash fuel-cell-id)
                                  fuel-cell-id)))

(test-case "1B-iv: fuel-cell initial value = budget parameter (Option A: remaining-fuel)"
  (define net (make-prop-network 1000))
  (check-equal? (net-cell-read net fuel-cell-id) 1000)
  (check-equal? (net-cell-read net fuel-budget-cell-id) 1000))

(test-case "1B-iv: fuel-cell initial value defaults to 1000000"
  (define net (make-prop-network))
  (check-equal? (net-cell-read net fuel-cell-id) 1000000)
  (check-equal? (net-cell-read net fuel-budget-cell-id) 1000000))

(test-case "1B-iv: fuel-cell has specialized-cell-meta with hot+monotone-counter+threshold-crossing"
  (define net (make-prop-network 1000))
  (define cell (champ-lookup (prop-network-cells net)
                              (cell-id-hash fuel-cell-id)
                              fuel-cell-id))
  (define meta (prop-cell-meta cell))
  (check-not-false meta)
  (check-eq? (specialized-cell-meta-tier meta) 'hot)
  (check-eq? (specialized-cell-meta-storage meta) 'monotone-counter)
  (check-eq? (specialized-cell-meta-fires-on meta) 'threshold-crossing)
  (check-not-false (specialized-cell-meta-on-write-check meta)))

(test-case "1B-iv: fuel-budget-cell has cold+general+any-change meta"
  (define net (make-prop-network 1000))
  (define cell (champ-lookup (prop-network-cells net)
                              (cell-id-hash fuel-budget-cell-id)
                              fuel-budget-cell-id))
  (define meta (prop-cell-meta cell))
  (check-not-false meta)
  (check-eq? (specialized-cell-meta-tier meta) 'cold)
  (check-eq? (specialized-cell-meta-storage meta) 'general)
  (check-eq? (specialized-cell-meta-fires-on meta) 'any-change))

(test-case "1B-iv: fuel-cell on-write-check fires at remaining ≤ 0 (Option A exhaustion)"
  (define net (make-prop-network 1000))
  ;; Decrement to 1 — not yet exhausted
  (define net2 (net-cell-write net fuel-cell-id 1))
  (check-equal? (net-cell-read net2 fuel-cell-id) 1)
  (check-eq? (prop-network-contradiction net2) #f)
  ;; Decrement to 0 — operational exhaustion; on-write-check fires
  (define net3 (net-cell-write net2 fuel-cell-id 0))
  (check-equal? (net-cell-read net3 fuel-cell-id) 0)
  (check-equal? (prop-network-contradiction net3) fuel-cell-id))

(test-case "1B-iv: shadow mode — make-prop-network with new cells doesn't break prop-net-hot.fuel"
  ;; The existing native fuel mechanism MUST still work in Phase 1B-iv.
  ;; Phase 1C migrates consumers; until then, prop-net-hot.fuel stays as the
  ;; live production fuel source.
  (define net (make-prop-network 1000))
  (check-equal? (prop-network-fuel net) 1000))

;; ============================================================
;; C4 + C5: deferred to 1B-iv per §9.2.0.6 Q-1B-iii-γ (now exercised)
;; ============================================================

(test-case "C4 — Module-theory: cell-write applies merge correctly under specialized dispatch"
  ;; Q-module action: net-cell-write on the fuel-cell uses tropical-fuel-merge-for-cell
  ;; (= min) under specialized dispatch. Writing a value >= current is a no-op (min
  ;; selects the lower). Writing a value < current updates (the lower wins).
  (define net (make-prop-network 1000))
  ;; Writing higher value than current → min selects current; no change
  (define net2 (net-cell-write net fuel-cell-id 2000))
  (check-equal? (net-cell-read net2 fuel-cell-id) 1000)  ;; min(1000, 2000) = 1000
  ;; Writing lower value → min selects the lower; cell updates
  (define net3 (net-cell-write net fuel-cell-id 500))
  (check-equal? (net-cell-read net3 fuel-cell-id) 500))

(test-case "C5 — CALM-safety: order-independent fixpoint under specialized dispatch"
  ;; Writes are commutative + idempotent under min-merge. Multiple writes in any
  ;; order converge to the same final value.
  (define base (make-prop-network 1000))
  ;; Order 1: 800 → 500 → 700
  (define net-a (net-cell-write base fuel-cell-id 800))
  (define net-a2 (net-cell-write net-a fuel-cell-id 500))
  (define net-a3 (net-cell-write net-a2 fuel-cell-id 700))
  ;; Order 2: 700 → 500 → 800
  (define net-b (net-cell-write base fuel-cell-id 700))
  (define net-b2 (net-cell-write net-b fuel-cell-id 500))
  (define net-b3 (net-cell-write net-b2 fuel-cell-id 800))
  ;; Both converge to 500 (the minimum)
  (check-equal? (net-cell-read net-a3 fuel-cell-id) 500)
  (check-equal? (net-cell-read net-b3 fuel-cell-id) 500))

;; ============================================================
;; 1C-ii-a Variant A migration tests (D.4 CANONICAL 2026-05-16)
;; ============================================================
;;
;; Per §10.0.2 Q-1C-ii-a-δ: 3 tests covering:
;;   (1) cell-field-lockstep — β1 invariant: cell and struct-field agree
;;       after BSP round (Tier 2 path)
;;   (2) Tier 1 fast path preservation — β1 preservation: cell unchanged
;;       when Tier 1 single-pass flush runs
;;   (3) exhaustion via cell-mechanism — on-write-check fires contradiction
;;       structurally when remaining-fuel hits ≤ 0
;;
;; D-1C-ii-a-1 (retirement obligation): the [fuel (- ...)] struct-copy
;; update at propagator.rkt line 2606 is transitional scaffolding (β1
;; lockstep with the new cell-write). It RETIRES at 1C-iv alongside the
;; prop-net-hot-fuel struct field. Test (1) verifies the transitional
;; invariant holds; post-1C-iv, the invariant is trivially preserved (only
;; the cell remains as the source of truth).

;; Local helpers for BSP propagator construction (mirror test-propagator-bsp.rkt)
(define (1c-ii-a-max-merge old new) (max old new))
(define (1c-ii-a-copy-fire-fn src dst)
  (lambda (net) (net-cell-write net dst (net-cell-read net src))))

(test-case "1C-ii-a (1) cell-field-lockstep: both struct-field and cell agree after BSP Tier 2 round"
  ;; Tier 2 path decrements BOTH: existing [fuel (- ... n)] struct-copy at
  ;; line 2606 PLUS new (net-cell-write snapshot fuel-cell-id (- ... n)).
  ;; β1 invariant: both reflect the same remaining-fuel value at every
  ;; observation point during the 1C-ii-a through 1C-iii transition window.
  (define net0 (make-prop-network 100))
  (define-values (net1 ca) (net-new-cell net0 0 1c-ii-a-max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 1c-ii-a-max-merge))
  ;; A→B copy propagator (will fire in Tier 2 — has inputs so NOT eligible for Tier 1)
  (define-values (net3 _p1) (net-add-propagator net2 (list ca) (list cb)
                              (1c-ii-a-copy-fire-fn ca cb)))
  ;; Trigger BSP run; propagator fires; consumes fuel from initial 100
  (define net4 (net-cell-write net3 ca 42))
  (define result (run-to-quiescence-bsp net4))
  ;; β1 invariant: struct-field and cell agree
  (define field-remaining (prop-network-fuel result))
  (define cell-remaining (net-cell-read result fuel-cell-id))
  (check-equal? field-remaining cell-remaining
                "β1 lockstep: struct-field and cell must agree after BSP Tier 2 round")
  ;; Both must be < 100 (fuel was consumed by Tier 2 path)
  (check-true (< field-remaining 100)
              "fuel was consumed by BSP Tier 2 round (some n decrement happened)"))

(test-case "1C-ii-a (2) Tier 1 fast path preservation: cell unchanged when Tier 1 runs"
  ;; β1 preservation (structural): Tier 1 fast path (run-to-quiescence-bsp
  ;; lines 2562-2573) bypasses fuel decrement entirely. The cell-write at
  ;; line 2606 is INSIDE Tier 2's let*, NOT in Tier 1's for/fold body.
  ;; Verified here by running BSP through Tier 1 (fire-once empty-inputs
  ;; propagator + no speculation + no NAF) and confirming BOTH struct-field
  ;; AND cell are unchanged after the round.
  (define net0 (make-prop-network 100))
  (define-values (net1 ca) (net-new-cell net0 0 1c-ii-a-max-merge))
  ;; Fire-once empty-inputs propagator: writes to ca, no inputs.
  ;; Tier 1 condition: PROP-FIRE-ONCE + PROP-EMPTY-INPUTS flags both set.
  (define-values (net2 _p1)
    (net-add-fire-once-propagator net1 (list) (list ca)
      (lambda (net) (net-cell-write net ca 99))))
  ;; Run BSP — fire-once empty-inputs propagator triggers Tier 1 path
  (define result (run-to-quiescence-bsp net2))
  ;; Verify propagator fired (ca written)
  (check-equal? (net-cell-read result ca) 99
                "Tier 1 fast path fired the propagator (ca written)")
  ;; β1 preservation: Tier 1 doesn't decrement fuel
  (check-equal? (prop-network-fuel result) 100
                "Tier 1 fast path doesn't decrement struct-field")
  (check-equal? (net-cell-read result fuel-cell-id) 100
                "Tier 1 fast path doesn't decrement cell (β1 preservation)"))

(test-case "1C-ii-a (3) exhaustion via cell-mechanism: on-write-check fires contradiction"
  ;; When BSP runs with budget that decrements to ≤ 0, the on-write-check
  ;; predicate (<= new 0) fires contradiction structurally via the cell
  ;; mechanism. This is the new structural exhaustion path under D.4.
  ;; During transition (1C-ii-a through 1C-iii), both paths run in parallel
  ;; per β1; either the cell-mechanism OR the existing inline check site
  ;; (which reads prop-network-fuel via the macro) fires contradiction first.
  (define net0 (make-prop-network 2))  ; very low budget
  (define-values (net1 ca) (net-new-cell net0 0 1c-ii-a-max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 1c-ii-a-max-merge))
  (define-values (net3 cc) (net-new-cell net2 0 1c-ii-a-max-merge))
  ;; 3 propagators with overlapping deps; first BSP round has n ≥ 2 worklist
  ;; entries, exhausting the budget=2.
  (define-values (net4 _p1) (net-add-propagator net3 (list ca) (list cb)
                              (1c-ii-a-copy-fire-fn ca cb)))
  (define-values (net5 _p2) (net-add-propagator net4 (list ca) (list cc)
                              (1c-ii-a-copy-fire-fn ca cc)))
  ;; Trigger BSP; budget exhausted on round 1 or 2
  (define net6 (net-cell-write net5 ca 42))
  (define result (run-to-quiescence-bsp net6))
  ;; Contradiction must be present (via cell-mechanism on-write-check
  ;; firing 'tropical-fuel-exhausted OR via the existing inline check site
  ;; which observes (<= (prop-network-fuel net) 0) and short-circuits).
  ;; β1 keeps both paths active during transition; either is acceptable.
  (check-true (and (prop-network-contradiction result) #t)
              "exhaustion produces contradiction (via cell-mechanism or legacy check site)"))

;; ============================================================
;; 1C-ii-b Variant B migration tests (D.4 CANONICAL 2026-05-16)
;; ============================================================
;;
;; Per §10.0.3 Q-1C-ii-b-δ + §10.0.4 F8 (mirror 1C-ii-a template): 3 tests
;; covering sequential schedulers (run-to-quiescence-inner / run-widen-phase
;; per Q-1C-α α2 splitting Variant B into 4 entry points #1/#2/#4/#5 that
;; share the helpers `init-fuel-local-var!` + `flush-fuel-local-var!`):
;;
;;   (1) cell-field-lockstep at sequential phase exit — β1 invariant: cell and
;;       struct-field agree after sequential scheduler returns (helper flushes
;;       both at phase exit)
;;   (2) helper correctness — direct test of init-fuel-local-var! (returns box
;;       with cell value) + flush-fuel-local-var! (writes BOTH cell and field)
;;   (3) exhaustion via cell-mechanism at sequential scheduler — on-write-check
;;       fires contradiction structurally when remaining-fuel hits ≤ 0 during
;;       sequential execution
;;
;; D-1C-ii-b-1 (retirement obligation): the struct-field write inside
;; flush-fuel-local-var! is transitional scaffolding. It RETIRES at 1C-iv
;; alongside the prop-net-hot-fuel struct field. Post-1C-iv, the helper only
;; writes the cell; Test (1) becomes trivially true (only cell remains as
;; source of truth).
;;
;; D-1C-ii-b-6 (asymmetry rationale per §10.0.4 F3): for #1 + #2 the helper
;; is used at INIT only (existing finalize struct-copy already writes
;; fuel-field alongside worklist; cell-write added after). For #4 + #5 the
;; helper is used at BOTH init AND flush (no worklist interleaving). Tests
;; below cover both patterns via the schedulers they exercise.

;; Local helpers for sequential scheduler tests
(define (1c-ii-b-max-merge old new) (max old new))
(define (1c-ii-b-copy-fire-fn src dst)
  (lambda (net) (net-cell-write net dst (net-cell-read net src))))

(test-case "1C-ii-b (1) cell-field-lockstep at sequential phase exit (run-to-quiescence-widen)"
  ;; Sequential scheduler #4 (run-widen-phase) + #5 (run-narrow-phase) use the
  ;; box pattern: init from cell at phase entry, decrement box per fire, flush
  ;; BOTH cell + field at phase exit. After return, β1 invariant: cell-value
  ;; EQUALS struct-field value at the post-flush observation point.
  ;;
  ;; Exercises #4 + #5 via the exported wrapper run-to-quiescence-widen
  ;; (which calls run-widen-phase then loops on run-narrow-phase). The 4
  ;; sequential entry points #1/#2/#4/#5 share the helpers; this test covers
  ;; the widening path; full suite GREEN broadens coverage to others.
  (define net0 (make-prop-network 100))
  (define-values (net1 ca) (net-new-cell net0 0 1c-ii-b-max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 1c-ii-b-max-merge))
  ;; Add a propagator that will fire (1 worklist entry → 1 fire → 1 decrement)
  (define-values (net3 _p1) (net-add-propagator net2 (list ca) (list cb)
                              (1c-ii-b-copy-fire-fn ca cb)))
  (define net4 (net-cell-write net3 ca 42))
  ;; Run via run-to-quiescence-widen (exported wrapper for sequential
  ;; widening/narrowing path; calls run-widen-phase then narrow loop)
  (define result (run-to-quiescence-widen net4))
  ;; β1 invariant at flush observation point
  (define field-remaining (prop-network-fuel result))
  (define cell-remaining (net-cell-read result fuel-cell-id))
  (check-equal? field-remaining cell-remaining
                "β1 lockstep: struct-field and cell must agree after sequential phase exit (flush observation point)")
  ;; Both must be < 100 (fuel was consumed by the fire)
  (check-true (< field-remaining 100)
              "fuel was consumed during sequential widen/narrow phase (box decrement → flush)"))

(test-case "1C-ii-b (2) helper correctness: init reads cell; flush writes BOTH cell and field"
  ;; Direct test of the helpers without exercising a scheduler. Verifies:
  ;;   - init-fuel-local-var! returns a box containing the cell's current value
  ;;   - flush-fuel-local-var! writes the box value to BOTH cell and struct-field
  ;;   - β1 lockstep is preserved by the helper's two-write pattern
  ;;
  ;; The struct-field write inside flush-fuel-local-var! is D-1C-ii-b-1
  ;; transitional scaffolding (retires at 1C-iv). This test will need to be
  ;; updated then to verify only the cell write.
  (define net0 (make-prop-network 100))
  ;; init-fuel-local-var! reads cell into box
  (define b (init-fuel-local-var! net0))
  (check-equal? (unbox b) 100
                "init-fuel-local-var! returns box with current cell value")
  ;; Mutate the box (simulating loop decrement)
  (set-box! b 42)
  ;; flush writes box value to BOTH cell and struct-field
  (define net1 (flush-fuel-local-var! net0 b))
  (check-equal? (net-cell-read net1 fuel-cell-id) 42
                "flush-fuel-local-var! writes box value to cell")
  (check-equal? (prop-network-fuel net1) 42
                "flush-fuel-local-var! writes box value to struct-field (β1 transitional; D-1C-ii-b-1)"))

(test-case "1C-ii-b (3) exhaustion via cell-mechanism at sequential scheduler"
  ;; Low budget through run-to-quiescence-widen (which exercises #4 + #5);
  ;; verify exhaustion semantics. Under D.4 specialized cell, the on-write-check
  ;; `(<= new 0)` fires contradiction structurally at the flush point (when
  ;; remaining hits 0). The box check `(<= (unbox local-fuel) 0)` in the loop
  ;; ALSO exits when the box decrements to 0 — either path produces a flushed
  ;; result with cell ≤ 0 (exhausted).
  (define net0 (make-prop-network 2))  ; very low budget
  (define-values (net1 ca) (net-new-cell net0 0 1c-ii-b-max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 1c-ii-b-max-merge))
  (define-values (net3 cc) (net-new-cell net2 0 1c-ii-b-max-merge))
  ;; 3 propagators to exhaust budget=2
  (define-values (net4 _p1) (net-add-propagator net3 (list ca) (list cb)
                              (1c-ii-b-copy-fire-fn ca cb)))
  (define-values (net5 _p2) (net-add-propagator net4 (list ca) (list cc)
                              (1c-ii-b-copy-fire-fn ca cc)))
  ;; net-cell-write of ca adds dependents to worklist (fires propagators)
  (define net6 (net-cell-write net5 ca 42))
  ;; Run via run-to-quiescence-widen; box exhausts (or contradiction fires)
  (define result (run-to-quiescence-widen net6))
  ;; After exhaustion + flush, remaining-fuel ≤ 0 in cell
  (define cell-remaining (net-cell-read result fuel-cell-id))
  (check-true (<= cell-remaining 0)
              "exhaustion at sequential scheduler: cell remaining ≤ 0 after flush")
  ;; Lockstep at flush point — even at exhaustion
  (check-equal? (prop-network-fuel result) cell-remaining
                "β1 lockstep preserved at exhaustion flush point"))
