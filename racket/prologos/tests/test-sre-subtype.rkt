#lang racket/base

;; ========================================================================
;; SRE Track 1: Structural Subtyping Tests
;; ========================================================================
;;
;; Tests the subtype relation on the SRE: variance-driven structural
;; decomposition, flat subtype fast path preservation, and the query
;; pattern for compound type checking.

(require rackunit
         "../propagator.rkt"
         "../sre-core.rkt"
         "../ctor-registry.rkt"
         "../syntax.rkt"
         "../subtype-predicate.rkt"  ;; subtype?, subtype-lattice-merge
         "../type-lattice.rkt")

;; ========================================================================
;; A. Variance annotation verification
;; ========================================================================

;; Verify that built-in type constructors have expected variances
(test-case "Pi has variance (= - +)"
  (define desc (lookup-ctor-desc 'Pi #:domain 'type))
  (check-not-false desc)
  (check-equal? (ctor-desc-component-variances desc) '(= - +)))

(test-case "App has variance (= +)"
  (define desc (lookup-ctor-desc 'app #:domain 'type))
  (check-not-false desc)
  (check-equal? (ctor-desc-component-variances desc) '(= +)))

(test-case "PVec has variance (+)"
  (define desc (lookup-ctor-desc 'PVec #:domain 'type))
  (check-not-false desc)
  (check-equal? (ctor-desc-component-variances desc) '(+)))

(test-case "Map has variance (= +)"
  (define desc (lookup-ctor-desc 'Map #:domain 'type))
  (check-not-false desc)
  (check-equal? (ctor-desc-component-variances desc) '(= +)))

(test-case "Eq has variance (= = =)"
  (define desc (lookup-ctor-desc 'Eq #:domain 'type))
  (check-not-false desc)
  (check-equal? (ctor-desc-component-variances desc) '(= = =)))

;; ========================================================================
;; B. Relation struct basics
;; ========================================================================

(test-case "sre-equality has name 'equality"
  (check-eq? (sre-relation-name sre-equality) 'equality))

(test-case "sre-subtype has name 'subtype"
  (check-eq? (sre-relation-name sre-subtype) 'subtype))

(test-case "sre-subtype-reverse has name 'subtype-reverse"
  (check-eq? (sre-relation-name sre-subtype-reverse) 'subtype-reverse))

(test-case "sre-duality has name 'duality"
  (check-eq? (sre-relation-name sre-duality) 'duality))

(test-case "sre-phantom has name 'phantom"
  (check-eq? (sre-relation-name sre-phantom) 'phantom))

;; ========================================================================
;; C. Sub-relation derivation for subtyping
;; ========================================================================

(test-case "Subtype sub-relation: covariant → subtype"
  (define pi-desc (lookup-ctor-desc 'Pi #:domain 'type))
  (define sub-fn (sre-relation-sub-relation-fn sre-subtype))
  ;; Pi component 2 (codomain) is covariant (+)
  (check-eq? (sre-relation-name (sub-fn sre-subtype pi-desc 2 'type)) 'subtype))

(test-case "Subtype sub-relation: contravariant → subtype-reverse"
  (define pi-desc (lookup-ctor-desc 'Pi #:domain 'type))
  (define sub-fn (sre-relation-sub-relation-fn sre-subtype))
  ;; Pi component 1 (domain) is contravariant (-)
  (check-eq? (sre-relation-name (sub-fn sre-subtype pi-desc 1 'type)) 'subtype-reverse))

(test-case "Subtype sub-relation: invariant → equality"
  (define pi-desc (lookup-ctor-desc 'Pi #:domain 'type))
  (define sub-fn (sre-relation-sub-relation-fn sre-subtype))
  ;; Pi component 0 (mult) is invariant (=)
  (check-eq? (sre-relation-name (sub-fn sre-subtype pi-desc 0 'type)) 'equality))

;; ========================================================================
;; D. Polarity inference utilities
;; ========================================================================

(test-case "variance-join: ø is identity"
  (check-eq? (variance-join 'ø '+) '+)
  (check-eq? (variance-join '+ 'ø) '+)
  (check-eq? (variance-join 'ø 'ø) 'ø))

(test-case "variance-join: + and - → ="
  (check-eq? (variance-join '+ '-) '=)
  (check-eq? (variance-join '- '+) '=))

(test-case "variance-join: same → same"
  (check-eq? (variance-join '+ '+) '+)
  (check-eq? (variance-join '- '-) '-))

(test-case "variance-flip"
  (check-eq? (variance-flip '+) '-)
  (check-eq? (variance-flip '-) '+)
  (check-eq? (variance-flip '=) '=)
  (check-eq? (variance-flip 'ø) 'ø))

;; ========================================================================
;; E. Flat subtype? preservation
;; ========================================================================

(test-case "Flat subtype: Nat <: Int"
  (check-true (subtype? (expr-Nat) (expr-Int))))

(test-case "Flat subtype: Nat <: Rat"
  (check-true (subtype? (expr-Nat) (expr-Rat))))

(test-case "Flat subtype: Int NOT <: Nat"
  (check-false (subtype? (expr-Int) (expr-Nat))))

;; ========================================================================
;; F. Structural subtype propagator (direct SRE test)
;; ========================================================================

;; Helper: create a mini-network, install subtype-relate, quiesce, check result
(define (test-type-merge-registry rel-name)
  (case rel-name
    [(equality) type-lattice-merge]
    [(subtype subtype-reverse) subtype-lattice-merge]
    [else (error 'test-type-merge-registry "no merge for: ~a" rel-name)]))

(define type-domain
  (sre-domain 'type
              test-type-merge-registry  ;; merge-registry
              type-lattice-contradicts?
              type-bot?
              type-bot
              type-top  ;; top-value
              #f #f     ;; no meta-recognizer/resolver
              #f))      ;; no dual-pairs

(define (sre-subtype-check t1 t2)
  "Create mini-network, install subtype-relate, quiesce, return #t if no contradiction."
  (define net0 (make-prop-network))
  (define-values (net1 cell-a)
    (net-new-cell net0 t1 type-lattice-merge type-lattice-contradicts?))
  (define-values (net2 cell-b)
    (net-new-cell net1 t2 type-lattice-merge type-lattice-contradicts?))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list cell-a cell-b) (list cell-a cell-b)
      (sre-make-structural-relate-propagator type-domain cell-a cell-b
        #:relation sre-subtype)))
  (define net4 (run-to-quiescence net3))
  ;; No contradiction = subtype holds
  (not (or (net-contradiction? net4)
           (type-lattice-contradicts? (net-cell-read net4 cell-a))
           (type-lattice-contradicts? (net-cell-read net4 cell-b)))))

(test-case "SRE subtype: PVec Nat <: PVec Int (covariant)"
  ;; PVec is covariant in its element type
  ;; Nat <: Int → PVec Nat <: PVec Int
  (check-true (sre-subtype-check
               (expr-PVec (expr-Nat))
               (expr-PVec (expr-Int)))))

(test-case "SRE subtype: PVec Int NOT <: PVec Nat"
  ;; Int is NOT <: Nat → PVec Int NOT <: PVec Nat
  (check-false (sre-subtype-check
                (expr-PVec (expr-Int))
                (expr-PVec (expr-Nat)))))

(test-case "SRE subtype: Set Nat <: Set Int (covariant)"
  (check-true (sre-subtype-check
               (expr-Set (expr-Nat))
               (expr-Set (expr-Int)))))

(test-case "SRE subtype: Map String Nat <: Map String Int (value covariant)"
  (check-true (sre-subtype-check
               (expr-Map (expr-tycon 'String) (expr-Nat))
               (expr-Map (expr-tycon 'String) (expr-Int)))))

(test-case "SRE subtype: Map String Nat NOT <: Map Int Nat (key invariant)"
  ;; Map key is invariant — String ≠ Int → fails
  (check-false (sre-subtype-check
                (expr-Map (expr-tycon 'String) (expr-Nat))
                (expr-Map (expr-tycon 'Int) (expr-Nat)))))

(test-case "SRE subtype: equal types satisfy subtyping"
  (check-true (sre-subtype-check
               (expr-PVec (expr-Int))
               (expr-PVec (expr-Int)))))
