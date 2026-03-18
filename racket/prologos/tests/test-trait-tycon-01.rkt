#lang racket/base

;;;
;;; Tests for Phase 1: Trait Names as First-Class Type Constructors
;;; Tests dynamic tycon-arity extension, normalize-for-resolution for trait names,
;;; kind inference for trait-as-tycon, HKT unification, and regression for trait dispatch.
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../unify.rkt"
         "../trait-resolution.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt"
         (prefix-in tc: "../typing-core.rkt"))

;; ========================================
;; 1. tycon-arity: unified lookup
;; ========================================

(test-case "tycon-arity: builtin constructors"
  (check-equal? (tycon-arity 'PVec) 1)
  (check-equal? (tycon-arity 'Map) 2)
  (check-equal? (tycon-arity 'Set) 1))

(test-case "tycon-arity: unknown name returns #f"
  (check-false (tycon-arity 'UnknownXyz)))

(test-case "tycon-arity: extension table"
  (parameterize ([current-tycon-arity-extension (hasheq 'Eq 1 'From 2)])
    (check-equal? (tycon-arity 'Eq) 1)
    (check-equal? (tycon-arity 'From) 2)
    ;; builtin still accessible
    (check-equal? (tycon-arity 'PVec) 1)
    ;; unknown still #f
    (check-false (tycon-arity 'Nope))))

;; ========================================
;; 2. normalize-for-resolution: trait fvars
;; ========================================

(test-case "normalize-for-resolution: fvar Eq → tycon Eq (via extension)"
  (with-fresh-meta-env
    (parameterize ([current-tycon-arity-extension (hasheq 'Eq 1)])
      (define result (normalize-for-resolution (expr-fvar 'Eq)))
      (check-true (expr-tycon? result))
      (check-equal? (expr-tycon-name result) 'Eq))))

(test-case "normalize-for-resolution: fvar From → tycon From (2-param trait)"
  (with-fresh-meta-env
    (parameterize ([current-tycon-arity-extension (hasheq 'From 2)])
      (define result (normalize-for-resolution (expr-fvar 'From)))
      (check-true (expr-tycon? result))
      (check-equal? (expr-tycon-name result) 'From))))

(test-case "normalize-for-resolution: app (fvar Eq) Nat → (app (tycon Eq) Nat)"
  (with-fresh-meta-env
    (parameterize ([current-tycon-arity-extension (hasheq 'Eq 1)])
      (define result (normalize-for-resolution (expr-app (expr-fvar 'Eq) (expr-Nat))))
      (check-true (expr-app? result))
      (check-true (expr-tycon? (expr-app-func result)))
      (check-equal? (expr-tycon-name (expr-app-func result)) 'Eq)
      (check-equal? (expr-app-arg result) (expr-Nat)))))

;; ========================================
;; 3. Kind inference: trait-as-tycon
;; ========================================

(test-case "typing: expr-tycon Eq has kind Type -> Type (via extension)"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-tycon-arity-extension (hasheq 'Eq 1)])
      (define kind (tc:infer '() (expr-tycon 'Eq)))
      (check-true (expr-Pi? kind))
      (check-equal? (expr-Pi-mult kind) 'm0)
      (check-true (expr-Type? (expr-Pi-domain kind)))
      (check-true (expr-Type? (expr-Pi-codomain kind))))))

(test-case "typing: expr-tycon From has kind Type -> Type -> Type (via extension)"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-tycon-arity-extension (hasheq 'From 2)])
      (define kind (tc:infer '() (expr-tycon 'From)))
      (check-true (expr-Pi? kind))
      (define inner (expr-Pi-codomain kind))
      (check-true (expr-Pi? inner))
      (check-true (expr-Type? (expr-Pi-codomain inner))))))

;; ========================================
;; 4. HKT unification with trait tycons
;; ========================================

(test-case "unify: (app ?F Nat) vs (app (tycon Eq) Nat) → ?F = Eq"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-tycon-arity-extension (hasheq 'Eq 1)])
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "F"))
      (check-true (unify ctx-empty
                         (expr-app m (expr-Nat))
                         (expr-app (expr-tycon 'Eq) (expr-Nat))))
      (check-true (meta-solved? (expr-meta-id m)))
      (check-equal? (meta-solution (expr-meta-id m)) (expr-tycon 'Eq)))))

;; ========================================
;; 5. Surface-level: prelude trait integration
;; ========================================
;; Uses shared fixture pattern for reliable prelude access.

(define shared-preamble "(ns test)\n")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-tycon-ext)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)]
                 [current-tycon-arity-extension (current-tycon-arity-extension)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-tycon-arity-extension))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-tycon-arity-extension shared-tycon-ext])
    (process-string s)))

(define (run-last s) (last (run s)))

(test-case "regression: where (Eq A) still resolves"
  (define result
    (run-last
      "(spec id-eq {A : Type} A -> A where (Eq A))
       (defn id-eq [x] x)
       [id-eq 42N]"))
  (check-true (string? result))
  (check-true (string-contains? result "42N")))

(test-case "regression: trait dispatch unaffected"
  (define result (run-last "[add 1N 2N]"))
  (check-true (string? result))
  (check-true (string-contains? result "3N")))

(test-case "trait tycon-arity populated by prelude"
  ;; After loading prelude, Eq should be in the extension table
  (parameterize ([current-tycon-arity-extension shared-tycon-ext])
    (check-equal? (tycon-arity 'Eq) 1)
    (check-equal? (tycon-arity 'Add) 1)
    (check-equal? (tycon-arity 'Ord) 1)))
