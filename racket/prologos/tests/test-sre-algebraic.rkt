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

(test-case "inference: distributive REFUTED for type domain"
  (define td (lookup-domain 'type))
  (define result (test-distributive td type-samples type-lattice-meet))
  (check-true (axiom-refuted? result))
  ;; Witness should be a list of 3 values
  (check-equal? (length (axiom-refuted-witness result)) 3))

(test-case "inference: full inference pipeline"
  (define td (lookup-domain 'type))
  (define props (infer-domain-properties td type-samples #:meet-fn type-lattice-meet))
  (check-eq? (hash-ref props 'commutative-join) prop-confirmed)
  (check-eq? (hash-ref props 'associative-join) prop-confirmed)
  ;; distributive: declared as unknown (not in type domain declarations) → inference refutes
  (check-eq? (hash-ref props 'distributive) prop-refuted))

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
  ;; Refuted: distributive (inference found counterexample)
  (check-eq? (hash-ref final 'distributive) prop-refuted)
  ;; Derived: heyting and boolean refuted (distributive is refuted)
  (check-eq? (hash-ref final 'heyting) prop-refuted)
  (check-eq? (hash-ref final 'boolean) prop-refuted))

(test-case "resolve-and-report: produces report string"
  (define td (lookup-domain 'type))
  (define-values (props report)
    (resolve-and-report-properties td type-samples #:meet-fn type-lattice-meet))
  (check-true (string? report))
  (check-true (string-contains? report "type"))
  (check-true (string-contains? report "prop-confirmed"))
  (check-true (string-contains? report "prop-refuted")))

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
