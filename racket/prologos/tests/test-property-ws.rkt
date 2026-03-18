#lang racket/base

;;;
;;; Tests for property keyword:
;;;   - WS-mode integration (reader → preparse → process-property)
;;;   - Standard library algebraic-laws.prologos
;;;   - flatten-property on real stdlib files
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         "../macros.rkt"
         "../syntax.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../errors.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../reader.rkt"
         "../source-location.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Process WS-mode string through the full pipeline
(define (process-string-ws s)
  (define port (open-input-string s))
  (port-count-lines! port)
  (define raw-stxs (prologos-read-syntax-all "<ws-test>" port))
  (define expanded-stxs (preparse-expand-all raw-stxs))
  (define surfs (map parse-datum expanded-stxs))
  (for/list ([surf (in-list surfs)])
    (if (prologos-error? surf)
        surf
        (process-command surf))))

;; Process WS-mode and return property from store
(define (property-for-ws name s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string-ws s)
    (lookup-property name)))

;; ========================================
;; 1. WS-mode property declarations
;; ========================================

(test-case "ws property: basic with dash clauses"
  (define pe
    (property-for-ws 'my-laws
      (string-append
        "property my-laws {A : Type}\n"
        "  :where (Eq A)\n"
        "  - :name \"refl\"\n"
        "    :holds [eq? x x]\n"
        "  - :name \"symm\"\n"
        "    :holds [eq? y x]\n")))
  (check-true (property-entry? pe))
  (check-equal? (property-entry-name pe) 'my-laws)
  (define clauses (property-entry-clauses pe))
  (check-equal? (length clauses) 2)
  (check-equal? (property-clause-name (car clauses)) "refl")
  (check-equal? (property-clause-name (cadr clauses)) "symm"))

(test-case "ws property: with :forall binders"
  (define pe
    (property-for-ws 'my-laws2
      (string-append
        "property my-laws2 {A : Type}\n"
        "  :where (Eq A)\n"
        "  - :name \"refl\"\n"
        "    :forall {x : A}\n"
        "    :holds [eq? x x]\n")))
  (check-true (property-entry? pe))
  (define c (car (property-entry-clauses pe)))
  (check-true (pair? (property-clause-forall-binders c))))

(test-case "ws property: with :includes"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string-ws
      (string-append
        "property base-laws {A : Type}\n"
        "  - :name \"b1\"\n"
        "    :holds [p x]\n"
        "\n"
        "property ext-laws {A : Type}\n"
        "  :includes (base-laws A)\n"
        "  - :name \"e1\"\n"
        "    :holds [q x]\n"))
    (define pe (lookup-property 'ext-laws))
    (check-true (property-entry? pe))
    (check-equal? (length (property-entry-includes pe)) 1)
    ;; Flatten
    (define clauses (flatten-property 'ext-laws))
    (check-equal? (length clauses) 2)
    (check-equal? (property-clause-name (car clauses)) 'base-laws/b1)
    (check-equal? (property-clause-name (cadr clauses)) 'ext-laws/e1)))

(test-case "ws property: empty property (only includes)"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string-ws
      (string-append
        "property leaf-p {A : Type}\n"
        "  - :name \"l1\"\n"
        "    :holds [p x]\n"
        "\n"
        "property wrap-p {A : Type}\n"
        "  :includes (leaf-p A)\n"))
    (define pe (lookup-property 'wrap-p))
    (check-true (property-entry? pe))
    (check-equal? (length (property-entry-clauses pe)) 0)
    (define clauses (flatten-property 'wrap-p))
    (check-equal? (length clauses) 1)))

;; spec/trait with :properties/:laws — using sexp mode (WS-mode spec/trait
;; constraint parsing has pre-existing issues with the implicit map rewriter
;; that are out of scope for this property hardening work)

(test-case "sexp spec: :properties reference stored"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string
      "(spec sort {A : (Type 0)} (List A) -> (List A) ($brace-params :where (Ord A) :properties (sortable-laws A)))")
    (define props (spec-properties 'sort))
    (check-true (pair? props))
    (check-equal? (car props) '(sortable-laws A))))

(test-case "sexp trait: :laws reference stored"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string
      (string-append
        "(trait (Eq (A : (Type 0)))"
        "  (eq? : A -> A -> Bool)"
        "  ($brace-params :laws (eq-laws A)))"))
    (define laws (lookup-trait-laws 'Eq))
    (check-true (pair? laws))
    (check-equal? (car laws) '(eq-laws A))))

;; ========================================
;; 2. Standard library: algebraic-laws.prologos
;; ========================================

(test-case "algebraic-laws: file parses and registers all properties"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (define here (path->string (path-only (syntax-source #'here))))
    (define file-path (simplify-path (build-path here ".." "lib" "prologos" "core" "algebra.prologos")))
    (process-file file-path)
    ;; All 4 properties should be registered
    (check-true (property-entry? (lookup-property 'semigroup-laws)))
    (check-true (property-entry? (lookup-property 'monoid-laws)))
    (check-true (property-entry? (lookup-property 'functor-laws)))
    (check-true (property-entry? (lookup-property 'commutative-add-laws)))))

(test-case "algebraic-laws: semigroup-laws has 1 clause"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (define here (path->string (path-only (syntax-source #'here))))
    (define file-path (simplify-path (build-path here ".." "lib" "prologos" "core" "algebra.prologos")))
    (process-file file-path)
    (define pe (lookup-property 'semigroup-laws))
    (check-equal? (length (property-entry-clauses pe)) 1)
    (check-equal? (property-clause-name (car (property-entry-clauses pe))) "associativity")))

(test-case "algebraic-laws: monoid-laws includes semigroup-laws"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (define here (path->string (path-only (syntax-source #'here))))
    (define file-path (simplify-path (build-path here ".." "lib" "prologos" "core" "algebra.prologos")))
    (process-file file-path)
    (define pe (lookup-property 'monoid-laws))
    ;; Should have 1 include (semigroup-laws A)
    (check-equal? (length (property-entry-includes pe)) 1)))

(test-case "algebraic-laws: monoid-laws flatten yields 3 clauses"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (define here (path->string (path-only (syntax-source #'here))))
    (define file-path (simplify-path (build-path here ".." "lib" "prologos" "core" "algebra.prologos")))
    (process-file file-path)
    (define clauses (flatten-property 'monoid-laws))
    ;; semigroup-laws/associativity + monoid-laws/left-identity + monoid-laws/right-identity
    (check-equal? (length clauses) 3)
    (check-equal? (property-clause-name (first clauses)) 'semigroup-laws/associativity)
    (check-equal? (property-clause-name (second clauses)) 'monoid-laws/left-identity)
    (check-equal? (property-clause-name (third clauses)) 'monoid-laws/right-identity)))

(test-case "algebraic-laws: functor-laws has 2 clauses"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (define here (path->string (path-only (syntax-source #'here))))
    (define file-path (simplify-path (build-path here ".." "lib" "prologos" "core" "algebra.prologos")))
    (process-file file-path)
    (define pe (lookup-property 'functor-laws))
    (check-equal? (length (property-entry-clauses pe)) 2)
    (check-equal? (property-clause-name (first (property-entry-clauses pe))) "identity")
    (check-equal? (property-clause-name (second (property-entry-clauses pe))) "composition")))

(test-case "algebraic-laws: commutative-add-laws has 1 clause"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (define here (path->string (path-only (syntax-source #'here))))
    (define file-path (simplify-path (build-path here ".." "lib" "prologos" "core" "algebra.prologos")))
    (process-file file-path)
    (define pe (lookup-property 'commutative-add-laws))
    (check-equal? (length (property-entry-clauses pe)) 1)
    (check-equal? (property-clause-name (car (property-entry-clauses pe))) "commutativity")))
