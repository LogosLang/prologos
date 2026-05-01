#lang racket/base

;;;
;;; Tests for SRE Track 2G: Algebraic Domain Awareness
;;;
;;; Covers: property lattice, domain registry, type/session meet,
;;; property inference, implication rules, diagnostic reporting,
;;; and property-gated behavior.
;;;

(require rackunit
         racket/list
         racket/string
         "../driver.rkt"          ;; loads both domains via register-domain!
         "../sre-core.rkt"
         "../type-lattice.rkt"
         "../session-lattice.rkt"
         "../syntax.rkt"
         "../surface-syntax.rkt")

;; ========================================
;; 1. Property Value Lattice (4-valued)
;; ========================================

(test-case "property-join: ⊥ ⊔ x = x"
  (check-eq? (property-value-join prop-unknown prop-confirmed) prop-confirmed)
  (check-eq? (property-value-join prop-unknown prop-refuted) prop-refuted)
  (check-eq? (property-value-join prop-unknown prop-unknown) prop-unknown))

(test-case "property-join: confirmed ⊔ refuted = contradicted (⊤)"
  (check-eq? (property-value-join prop-confirmed prop-refuted) prop-contradicted)
  (check-eq? (property-value-join prop-refuted prop-confirmed) prop-contradicted))

(test-case "property-join: idempotent"
  (check-eq? (property-value-join prop-confirmed prop-confirmed) prop-confirmed)
  (check-eq? (property-value-join prop-refuted prop-refuted) prop-refuted))

(test-case "property-join: ⊤ absorbs"
  (check-eq? (property-value-join prop-contradicted prop-confirmed) prop-contradicted)
  (check-eq? (property-value-join prop-confirmed prop-contradicted) prop-contradicted))

;; ========================================
;; 2. Domain Registry
;; ========================================

(test-case "registry: lookup registered domain"
  (define td (lookup-domain 'type))
  (check-not-false td)
  (check-eq? (sre-domain-name td) 'type))

(test-case "registry: lookup unregistered returns #f"
  (check-false (lookup-domain 'nonexistent)))

(test-case "registry: all-registered-domains includes type"
  (define domains (all-registered-domains))
  (check-true (ormap (lambda (d) (eq? (sre-domain-name d) 'type)) domains)))

;; ========================================
;; 3. Type Lattice Meet
;; ========================================

(test-case "type-meet: equal types"
  (check-equal? (type-lattice-meet (expr-Int) (expr-Int)) (expr-Int)))

(test-case "type-meet: incompatible base types → ⊥"
  (check-true (type-bot? (type-lattice-meet (expr-Int) (expr-String)))))

(test-case "type-meet: ⊤ ⊓ x = x (identity)"
  (check-equal? (type-lattice-meet type-top (expr-Nat)) (expr-Nat))
  (check-equal? (type-lattice-meet (expr-Int) type-top) (expr-Int)))

(test-case "type-meet: x ⊓ ⊥ = ⊥ (annihilator)"
  (check-true (type-bot? (type-lattice-meet (expr-Int) type-bot)))
  (check-true (type-bot? (type-lattice-meet type-bot (expr-String)))))

(test-case "type-meet: commutative for base types"
  (check-equal? (type-lattice-meet (expr-Int) (expr-Nat))
                (type-lattice-meet (expr-Nat) (expr-Int))))

;; ========================================
;; 4. Session Lattice Meet
;; ========================================

(test-case "session-meet: ⊤ ⊓ x = x"
  (check-eq? (session-lattice-meet sess-top sess-bot) sess-bot))

(test-case "session-meet: x ⊓ ⊥ = ⊥"
  (check-true (sess-bot? (session-lattice-meet sess-bot sess-top))))

(test-case "session-meet: equal → identity"
  (check-eq? (session-lattice-meet sess-bot sess-bot) sess-bot))

;; ========================================
;; 5. Property Declaration + Query
;; ========================================

(test-case "has-property?: declared property returns #t"
  (define td (lookup-domain 'type))
  (check-true (sre-domain-has-property? td 'commutative-join))
  (check-true (sre-domain-has-property? td 'has-meet)))

(test-case "has-property?: undeclared property returns #f"
  (define td (lookup-domain 'type))
  (check-false (sre-domain-has-property? td 'has-complement))
  (check-false (sre-domain-has-property? td 'heyting)))

;; ========================================
;; 6. Property Inference
;; ========================================

(define type-samples
  (list type-bot type-top (expr-Int) (expr-Nat) (expr-String) (expr-Bool)))

(test-case "inference: commutative-join confirmed for type domain"
  (define td (lookup-domain 'type))
  (define result (test-commutative-join td type-samples))
  (check-true (axiom-confirmed? result))
  (check-true (> (axiom-confirmed-count result) 0)))

(test-case "inference: associative-join confirmed for type domain"
  (define td (lookup-domain 'type))
  (define result (test-associative-join td type-samples))
  (check-true (axiom-confirmed? result)))

(test-case "inference: idempotent-join confirmed for type domain"
  (define td (lookup-domain 'type))
  (define result (test-idempotent-join td type-samples))
  (check-true (axiom-confirmed? result)))

(test-case "inference: distributive CONFIRMED for type domain (post-Phase-3c)"
  ;; HISTORY: Pre-Phase-3c (Track 2I, 2026-04-30) this test asserted REFUTED.
  ;; That finding was an artifact of `current-lattice-subtype-fn` being installed
  ;; at driver init — meet was always subtype-aware regardless of which join
  ;; (equality/subtype) was being tested. Mixed semantics broke distributivity.
  ;;
  ;; Phase 3c retired the callback in favor of per-relation meet-registry.
  ;; With principled per-relation dispatch:
  ;;   - equality merge + flat meet (no subtype-fn) → distributive on these samples
  ;;   - subtype merge + subtype-aware meet → also distributive (Heyting by Track 2H)
  ;; Track 2G's "type lattice not distributive under equality merge" finding
  ;; was correct AT THE TIME (pre-Track-2H, distinct atoms went to type-top giving
  ;; M3 sublattice). Track 2H (PPN 4C T-3 Commit B) made equality merge produce
  ;; unions; the always-installed callback hid that this restored distributivity.
  ;; Phase 3c's principled refactor surfaces the post-Track-2H truth.
  (define td (lookup-domain 'type))
  (define result (test-distributive td type-samples type-lattice-meet))
  (check-true (axiom-confirmed? result))
  ;; All 6³ = 216 triples confirm distributivity on type-samples.
  (check-eq? (axiom-confirmed-count result) 216))

(test-case "inference: full inference pipeline"
  (define td (lookup-domain 'type))
  (define props (infer-domain-properties td type-samples #:meet-fn type-lattice-meet))
  (check-eq? (hash-ref props 'commutative-join) prop-confirmed)
  (check-eq? (hash-ref props 'associative-join) prop-confirmed)
  ;; Phase 3c finding: equality lattice IS distributive when using its own flat
  ;; meet (not the subtype-aware meet that the retired callback was implicitly
  ;; providing). Was prop-refuted pre-3c.
  (check-eq? (hash-ref props 'distributive) prop-confirmed))

;; ========================================
;; 7. Implication Rules
;; ========================================

(test-case "implications: distributive + has-pseudo-complement → heyting"
  (define props (hasheq 'distributive prop-confirmed
                        'has-pseudo-complement prop-confirmed))
  (define derived (derive-composite-properties props))
  (check-eq? (hash-ref derived 'heyting) prop-confirmed))

(test-case "implications: distributive refuted → heyting refuted"
  (define props (hasheq 'distributive prop-refuted
                        'has-pseudo-complement prop-confirmed))
  (define derived (derive-composite-properties props))
  (check-eq? (hash-ref derived 'heyting) prop-refuted))

(test-case "implications: heyting + has-complement → boolean"
  (define props (hasheq 'distributive prop-confirmed
                        'has-pseudo-complement prop-confirmed
                        'has-complement prop-confirmed))
  (define derived (derive-composite-properties props))
  (check-eq? (hash-ref derived 'heyting) prop-confirmed)
  (check-eq? (hash-ref derived 'boolean) prop-confirmed))

(test-case "implications: heyting refuted → boolean refuted"
  (define props (hasheq 'distributive prop-refuted
                        'has-pseudo-complement prop-confirmed
                        'has-complement prop-confirmed))
  (define derived (derive-composite-properties props))
  (check-eq? (hash-ref derived 'heyting) prop-refuted)
  (check-eq? (hash-ref derived 'boolean) prop-refuted))

;; ========================================
;; 8. Full Resolution Pipeline
;; ========================================

(test-case "resolve: type domain full pipeline"
  (define td (lookup-domain 'type))
  (define final (resolve-domain-properties td type-samples #:meet-fn type-lattice-meet))
  ;; Confirmed atomic properties
  (check-eq? (hash-ref final 'commutative-join) prop-confirmed)
  (check-eq? (hash-ref final 'associative-join) prop-confirmed)
  (check-eq? (hash-ref final 'idempotent-join) prop-confirmed)
  (check-eq? (hash-ref final 'has-meet) prop-confirmed)
  ;; Phase 3c finding: distributive is now confirmed (was refuted pre-3c).
  (check-eq? (hash-ref final 'distributive) prop-confirmed)
  ;; Derived: distributive ⇒ sd-vee + sd-wedge fire (Phase 1 implication rules).
  (check-eq? (hash-ref final 'sd-vee) prop-confirmed)
  (check-eq? (hash-ref final 'sd-wedge) prop-confirmed)
  ;; heyting requires has-pseudo-complement (not declared/inferred for equality
  ;; relation here) → sources-incomplete → derived-value = unknown.
  ;; boolean requires heyting → also unknown.
  (check-eq? (hash-ref final 'heyting) prop-unknown)
  (check-eq? (hash-ref final 'boolean) prop-unknown))

(test-case "resolve-and-report: produces report string"
  (define td (lookup-domain 'type))
  (define-values (props report)
    (resolve-and-report-properties td type-samples #:meet-fn type-lattice-meet))
  (check-true (string? report))
  (check-true (string-contains? report "type"))
  (check-true (string-contains? report "prop-confirmed"))
  ;; Phase 3c: equality lattice is distributive (no refutations on these samples).
  ;; Heyting/boolean derived-unknown (sources incomplete). Report contains
  ;; prop-unknown for the underived composite properties.
  (check-true (string-contains? report "prop-unknown")))

;; ========================================
;; 9. Property-Gated Behavior
;; ========================================

(test-case "with-domain-property: gates on confirmed property"
  (define td (lookup-domain 'type))
  (define result
    (with-domain-property td 'has-meet
      (lambda () "meet available")
      (lambda () "no meet")))
  (check-equal? result "meet available"))

(test-case "with-domain-property: falls back on absent property"
  (define td (lookup-domain 'type))
  (define result
    (with-domain-property td 'heyting
      (lambda () "heyting available")
      (lambda () "no heyting")))
  (check-equal? result "no heyting"))

(test-case "select-by-property: selects first matching"
  (define td (lookup-domain 'type))
  (define result
    (select-by-property td
      (list (cons 'heyting (lambda () "heyting path"))
            (cons 'has-meet (lambda () "meet path")))
      (lambda () "fallback")))
  (check-equal? result "meet path"))

(test-case "select-by-property: falls back when none match"
  (define td (lookup-domain 'type))
  (define result
    (select-by-property td
      (list (cons 'heyting (lambda () "heyting"))
            (cons 'boolean (lambda () "boolean")))
      (lambda () "fallback")))
  (check-equal? result "fallback"))

;; ========================================
;; 11. SRE Track 2I: SD∨ / SD∧ Algebraic-Property Checks
;; ========================================

(test-case "test-sd-vee: returns axiom-untested when no meet-fn supplied"
  (define td (lookup-domain 'type))
  (check-eq? (test-sd-vee td type-samples #f) axiom-untested))

(test-case "test-sd-wedge: returns axiom-untested when no meet-fn supplied"
  (define td (lookup-domain 'type))
  (check-eq? (test-sd-wedge td type-samples #f) axiom-untested))

(test-case "test-sd-vee: passes on type domain (with meet)"
  (define td (lookup-domain 'type))
  (define result (test-sd-vee td type-samples type-lattice-meet))
  ;; Should be axiom-confirmed or axiom-refuted (not untested) since meet-fn provided.
  ;; The empirical answer for type-equality on these samples is recorded in Phase 3.
  ;; For Phase 1, we just assert the function returns one of the structured outcomes.
  (check-true (or (axiom-confirmed? result) (axiom-refuted? result))))

(test-case "test-sd-wedge: passes on type domain (with meet)"
  (define td (lookup-domain 'type))
  (define result (test-sd-wedge td type-samples type-lattice-meet))
  (check-true (or (axiom-confirmed? result) (axiom-refuted? result))))

(test-case "implication rule: distributive ⇒ sd-vee fires"
  (define props
    (hasheq 'distributive prop-confirmed))
  (define derived (derive-composite-properties props))
  (check-eq? (hash-ref derived 'sd-vee prop-unknown) prop-confirmed))

(test-case "implication rule: distributive ⇒ sd-wedge fires"
  (define props
    (hasheq 'distributive prop-confirmed))
  (define derived (derive-composite-properties props))
  (check-eq? (hash-ref derived 'sd-wedge prop-unknown) prop-confirmed))

(test-case "implication rule: distributive refuted ⇒ SD inferred refuted (forward implication)"
  ;; Note: this tests the propagation of refutation through the implication graph.
  ;; The mathematical fact (non-distributive lattices CAN still be SD, e.g., free lattices)
  ;; means our implication-based derivation under-approximates SD when distributivity refutes —
  ;; we must rely on the empirical check (test-sd-vee / test-sd-wedge) for the truth.
  ;; This test confirms the implementation behavior, not the mathematical claim.
  (define props
    (hasheq 'distributive prop-refuted))
  (define derived (derive-composite-properties props))
  (check-eq? (hash-ref derived 'sd-vee prop-unknown) prop-refuted))

(test-case "implication rule: distributive unknown leaves SD unknown"
  (define props (hasheq))
  (define derived (derive-composite-properties props))
  (check-eq? (hash-ref derived 'sd-vee prop-unknown) prop-unknown)
  (check-eq? (hash-ref derived 'sd-wedge prop-unknown) prop-unknown))

(test-case "infer-domain-properties: produces sd-vee + sd-wedge entries when meet-fn provided"
  (define td (lookup-domain 'type))
  (define props (infer-domain-properties td type-samples
                                         #:meet-fn type-lattice-meet
                                         #:relation 'equality))
  ;; Both SD properties must be in the result hash (whether confirmed or refuted).
  (check-true (hash-has-key? props 'sd-vee))
  (check-true (hash-has-key? props 'sd-wedge)))

(test-case "infer-domain-properties: omits SD entries when meet-fn absent"
  ;; Without meet-fn, distributivity is also untested. SD entries should not appear.
  (define td (lookup-domain 'type))
  (define props (infer-domain-properties td type-samples
                                         #:relation 'equality))
  (check-false (hash-has-key? props 'sd-vee))
  (check-false (hash-has-key? props 'sd-wedge)))

;; ========================================
;; 12. SRE Track 2I Phase 2: Detailed SD Evidence + Sample Generator
;; ========================================

(require "../sre-sample-generator.rkt")

(test-case "sd-evidence: untested when no meet-fn"
  (define td (lookup-domain 'type))
  (define ev (test-sd-vee/detailed td type-samples #f))
  (check-eq? (sd-evidence-status ev) 'untested)
  (check-eq? (sd-evidence-total-checked ev) 0)
  (check-eq? (sd-evidence-hypothesis-fired ev) 0)
  (check-eq? (sd-evidence-conclusion-held ev) 0)
  (check-eq? (sd-evidence-witness ev) #f))

(test-case "sd-evidence: confirmed populates counts"
  (define td (lookup-domain 'type))
  (define ev (test-sd-vee/detailed td type-samples type-lattice-meet))
  ;; Status either 'confirmed or 'refuted (not 'untested) since meet-fn provided.
  (check-true (or (eq? (sd-evidence-status ev) 'confirmed)
                  (eq? (sd-evidence-status ev) 'refuted)))
  ;; total-checked must equal |samples|³ for confirmed, ≤ that for refuted.
  (check-true (> (sd-evidence-total-checked ev) 0))
  ;; hypothesis-fired ≤ total-checked
  (check-true (<= (sd-evidence-hypothesis-fired ev)
                  (sd-evidence-total-checked ev)))
  ;; conclusion-held ≤ hypothesis-fired
  (check-true (<= (sd-evidence-conclusion-held ev)
                  (sd-evidence-hypothesis-fired ev))))

(test-case "sd-evidence: backward-compat wrappers translate correctly"
  (define td (lookup-domain 'type))
  (define ev-vee (test-sd-vee/detailed td type-samples type-lattice-meet))
  (define wrap-vee (test-sd-vee td type-samples type-lattice-meet))
  ;; If detailed = confirmed, wrapper = axiom-confirmed
  (case (sd-evidence-status ev-vee)
    [(confirmed) (check-true (axiom-confirmed? wrap-vee))]
    [(refuted)   (check-true (axiom-refuted? wrap-vee))]
    [(untested)  (check-eq? wrap-vee axiom-untested)]))

(test-case "sd-evidence: total-checked = |samples|³ on confirmed (full sweep)"
  (define td (lookup-domain 'type))
  (define ev (test-sd-vee/detailed td type-samples type-lattice-meet))
  ;; Either confirmed (full sweep, total = n³) or refuted (short-circuit, total < n³)
  (define n (length type-samples))
  (case (sd-evidence-status ev)
    [(confirmed) (check-eq? (sd-evidence-total-checked ev) (* n n n))]
    [(refuted)   (check-true (<= (sd-evidence-total-checked ev) (* n n n)))]))

(test-case "generate-domain-samples: returns non-empty for type domain"
  (define td (lookup-domain 'type))
  (define samples (generate-domain-samples td #:max-depth 1 #:per-ctor-count 2))
  (check-true (> (length samples) 0)))

(test-case "generate-domain-samples: includes bot/top by default"
  (define td (lookup-domain 'type))
  (define samples (generate-domain-samples td #:max-depth 0 #:per-ctor-count 1))
  ;; type-bot and type-top must appear in depth-0 samples
  (define bot-val (sre-domain-bot-value td))
  (define top-val (sre-domain-top-value td))
  (check-not-false (member bot-val samples))
  (check-not-false (member top-val samples)))

(test-case "generate-domain-samples: omits bot/top when #:include-bot-top #f"
  (define td (lookup-domain 'type))
  (define samples (generate-domain-samples td
                                           #:max-depth 0
                                           #:per-ctor-count 1
                                           #:include-bot-top #f))
  (define bot-val (sre-domain-bot-value td))
  (define top-val (sre-domain-top-value td))
  (check-false (member bot-val samples))
  (check-false (member top-val samples)))

(test-case "generate-domain-samples: respects base-values"
  (define td (lookup-domain 'type))
  (define samples (generate-domain-samples td
                                           #:max-depth 0
                                           #:per-ctor-count 1
                                           #:include-bot-top #f
                                           #:base-values (list (expr-Int) (expr-Bool))))
  (check-not-false (member (expr-Int) samples))
  (check-not-false (member (expr-Bool) samples)))

(test-case "generate-domain-samples: increasing max-depth produces ≥ samples"
  (define td (lookup-domain 'type))
  (define samples-d0 (generate-domain-samples td #:max-depth 0 #:per-ctor-count 2))
  (define samples-d1 (generate-domain-samples td #:max-depth 1 #:per-ctor-count 2))
  (define samples-d2 (generate-domain-samples td #:max-depth 2 #:per-ctor-count 2))
  ;; Each depth level only adds samples (monotone over depth via dedup)
  (check-true (<= (length samples-d0) (length samples-d1)))
  (check-true (<= (length samples-d1) (length samples-d2))))

(test-case "generate-domain-samples: deduplicates"
  (define td (lookup-domain 'type))
  (define samples (generate-domain-samples td
                                           #:max-depth 1
                                           #:per-ctor-count 2
                                           #:base-values (list (expr-Int) (expr-Int) (expr-Int))))
  ;; Three duplicate base values should collapse to one
  (define int-count (length (filter (lambda (s) (equal? s (expr-Int))) samples)))
  (check-eq? int-count 1))

(test-case "sd-evidence with generated samples: produces structured outcome"
  (define td (lookup-domain 'type))
  (define gen-samples (generate-domain-samples td #:max-depth 1 #:per-ctor-count 2))
  (define ev (test-sd-vee/detailed td gen-samples type-lattice-meet))
  (check-true (or (eq? (sd-evidence-status ev) 'confirmed)
                  (eq? (sd-evidence-status ev) 'refuted)))
  ;; Total checked equals |samples|³ on confirmed; less or equal on refuted
  (define n (length gen-samples))
  (check-true (<= (sd-evidence-total-checked ev) (* n n n))))

;; ========================================
;; 13. SRE Track 2I Phase 2a: Per-Component-Spec Generation + Binder Inclusion
;; ========================================
;;
;; Phase 2a refactor (Option C): drop with-handlers, drive per-ctor generation
;; from ctor-desc-component-lattices, include binder ctors with closed bodies.
;; These tests verify the principled refactor.

(require "../syntax.rkt")  ;; for expr-Pi?, expr-Sigma?, etc.

;; Phase 2a key insight: type domain has no nullary ctors registered, so
;; without base-values the non-sentinel component pool is empty and no
;; compounds can be generated. Tests that exercise compound generation
;; must supply realistic base-values (the well-known atomic types).
;; Phase 3 sweep will do the same. This is correct-by-construction:
;; sentinels (bot/top) are valid lattice elements but not valid components
;; (Phase 2 silently produced malformed compounds via with-handlers; 2a
;; surfaces this and requires the generator be given a real component pool).

(define realistic-type-atoms
  (list (expr-Int) (expr-Bool) (expr-Nat) (expr-String)))

(test-case "Phase 2a: generator includes binder ctors (Pi/Sigma/lam) at depth ≥ 1"
  (define td (lookup-domain 'type))
  (define samples (generate-domain-samples td
                                           #:max-depth 1
                                           #:per-ctor-count 2
                                           #:base-values realistic-type-atoms))
  ;; At least one Pi inhabitant should be present.
  (define has-pi? (ormap expr-Pi? samples))
  (check-true has-pi?))

(test-case "Phase 2a: generated Pi inhabitants have valid mult components"
  (define td (lookup-domain 'type))
  (define samples (generate-domain-samples td
                                           #:max-depth 1
                                           #:per-ctor-count 3
                                           #:base-values realistic-type-atoms))
  (define pis (filter expr-Pi? samples))
  ;; Some Pi values should exist
  (check-true (> (length pis) 0))
  ;; All mult fields should be from {m0, m1, mw} — drawn from mult-pool
  (define valid-mults '(m0 m1 mw))
  (for ([pi (in-list pis)])
    (check-not-false (memq (expr-Pi-mult pi) valid-mults))))

(test-case "Phase 2a: generator produces compound samples with realistic base-values"
  ;; With realistic base-values, compound generation works:
  ;; depth 0: 4 atoms (Int, Bool, Nat, String) + bot + top = 6
  ;; depth 1: per-ctor-count=2 → 2 atoms used per slot, so e.g. Pi has
  ;;   2*2*2=8 inhabitants, plus app/Eq/Vec/Fin/pair/PVec/Sigma/lam variants.
  ;; Conservative bound: ≥ 30 total samples after dedup.
  (define td (lookup-domain 'type))
  (define samples (generate-domain-samples td
                                           #:max-depth 1
                                           #:per-ctor-count 2
                                           #:base-values realistic-type-atoms))
  (check-true (>= (length samples) 30)))

(test-case "Phase 2a: sentinels (bot/top) excluded from component pools"
  ;; Sanity: no generated compound should have bot or top as a component.
  ;; Test by structurally inspecting Pi inhabitants — domain/codomain
  ;; should never be the bot/top sentinels.
  (define td (lookup-domain 'type))
  (define samples (generate-domain-samples td
                                           #:max-depth 1
                                           #:per-ctor-count 2
                                           #:base-values realistic-type-atoms))
  (define pis (filter expr-Pi? samples))
  (define bot (sre-domain-bot-value td))
  (define top (sre-domain-top-value td))
  (for ([pi (in-list pis)])
    (check-false (equal? (expr-Pi-domain pi) bot))
    (check-false (equal? (expr-Pi-domain pi) top))
    (check-false (equal? (expr-Pi-codomain pi) bot))
    (check-false (equal? (expr-Pi-codomain pi) top))))

(test-case "Phase 2a: nullary ctor reconstruction never returns #f (no silent skip)"
  ;; Type domain has no arity-0 ctors registered, but the function should
  ;; return '() cleanly without ever hitting an `(if v ...)` guard.
  ;; This is a structural test that nullary-ctor-inhabitants doesn't
  ;; rely on a #f-fallback semantics.
  (define td (lookup-domain 'type))
  (define samples (generate-domain-samples td
                                           #:max-depth 0
                                           #:per-ctor-count 1
                                           #:include-bot-top #f))
  ;; No bot/top, no base-values, no nullary type ctors → empty samples.
  (check-equal? samples '())
  ;; Critically: this should not raise any errors.
  )

;; ========================================
;; 14. SRE Track 2I Phase 3c: Per-relation meet-registry on sre-domain
;; ========================================

(test-case "Phase 3c: type domain has meet-registry registered"
  (define td (lookup-domain 'type))
  (check-not-false (sre-domain-meet-registry td)))

(test-case "Phase 3c: sre-domain-meet returns flat meet for 'equality relation"
  ;; Equality relation's meet has no subtype-fn → distinct atoms meet to type-bot.
  (define td (lookup-domain 'type))
  (define meet (sre-domain-meet td 'equality))
  (check-not-false meet)
  (check-equal? (meet (expr-Nat) (expr-Bool)) type-bot))

(test-case "Phase 3c: sre-domain-meet returns subtype-aware meet for 'subtype relation"
  ;; Subtype relation's meet uses subtype? to compute GLB for comparable atoms.
  ;; Nat <: Int → meet(Int, Nat) = Nat (the GLB).
  (define td (lookup-domain 'type))
  (define meet (sre-domain-meet td 'subtype))
  (check-not-false meet)
  (check-equal? (meet (expr-Int) (expr-Nat)) (expr-Nat))
  (check-equal? (meet (expr-Nat) (expr-Int)) (expr-Nat)))

(test-case "Phase 3c: meet-registry equality vs subtype distinguishes flat/GLB behavior"
  ;; The principled per-relation distinction. Pre-3c the callback was always
  ;; installed → flat path was unreachable. Post-3c they're properly separated.
  (define td (lookup-domain 'type))
  (define meet-eq (sre-domain-meet td 'equality))
  (define meet-sub (sre-domain-meet td 'subtype))
  (check-equal? (meet-eq (expr-Int) (expr-Nat)) type-bot)
  (check-equal? (meet-sub (expr-Int) (expr-Nat)) (expr-Nat)))

(test-case "Phase 3c: registry-driven meet matches accessor"
  ;; Verify the registry path returns the same result whether called via
  ;; sre-domain-meet or via the registered closure directly.
  (define td (lookup-domain 'type))
  (define registry (sre-domain-meet-registry td))
  (define from-registry ((registry 'subtype) (expr-Int) (expr-Nat)))
  (define from-accessor ((sre-domain-meet td 'subtype) (expr-Int) (expr-Nat)))
  (check-equal? from-registry from-accessor)
  (check-equal? from-accessor (expr-Nat)))

;; SRE Track 2I Phase 3 sweep tests live in tests/test-sre-sd-properties.rkt
;; (separate file due to O(N³) sweep cost — keeps this file fast for the
;; thread-pool worker dispatch).
