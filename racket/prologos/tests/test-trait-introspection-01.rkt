#lang racket/base

;;;
;;; Tests for Phase 3b: Trait Introspection
;;; Verifies: instances-of, methods-of, satisfies? surface commands +
;;; REPL :instances, :methods, :satisfies commands.
;;;

(require rackunit
         racket/list
         racket/string
         racket/port
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt")

;; ========================================
;; Shared Fixture (prelude loaded once)
;; ========================================

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns test-trait-introspection)")
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Run sexp code using shared environment
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
                 [current-bundle-registry shared-bundle-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; ========================================
;; A. instances-of — sexp command
;; ========================================

(test-case "instances-of: Eq trait has Nat instance"
  (define result (run-last "(instances-of Eq)"))
  (check-true (string? result))
  (check-true (string-contains? result "Instances of Eq"))
  (check-true (string-contains? result "Nat")))

(test-case "instances-of: Add trait has Nat instance"
  (define result (run-last "(instances-of Add)"))
  (check-true (string? result))
  (check-true (string-contains? result "Instances of Add"))
  (check-true (string-contains? result "Nat")))

(test-case "instances-of: nonexistent trait → no instances"
  (define result (run-last "(instances-of Nonexistent)"))
  (check-true (string? result))
  (check-true (string-contains? result "No instances")))

(test-case "instances-of: Eq has Bool instance"
  (define result (run-last "(instances-of Eq)"))
  (check-true (string-contains? result "Bool")))

;; ========================================
;; B. methods-of — sexp command
;; ========================================

(test-case "methods-of: Eq trait has eq? method"
  (define result (run-last "(methods-of Eq)"))
  (check-true (string? result))
  (check-true (string-contains? result "Methods of Eq"))
  (check-true (string-contains? result "eq?")))

(test-case "methods-of: Add trait has add method"
  (define result (run-last "(methods-of Add)"))
  (check-true (string? result))
  (check-true (string-contains? result "Methods of Add"))
  (check-true (string-contains? result "add")))

(test-case "methods-of: nonexistent trait → no trait found"
  (define result (run-last "(methods-of Nonexistent)"))
  (check-true (string? result))
  (check-true (string-contains? result "No trait found")))

;; ========================================
;; C. satisfies? — sexp command
;; ========================================

(test-case "satisfies?: Nat satisfies Eq → true"
  (define result (run-last "(satisfies? Nat Eq)"))
  (check-true (string? result))
  (check-true (string-contains? result "true")))

(test-case "satisfies?: Nat satisfies Add → true"
  (define result (run-last "(satisfies? Nat Add)"))
  (check-true (string? result))
  (check-true (string-contains? result "true")))

(test-case "satisfies?: Bool satisfies Eq → true"
  (define result (run-last "(satisfies? Bool Eq)"))
  (check-true (string? result))
  (check-true (string-contains? result "true")))

(test-case "satisfies?: Nat satisfies Nonexistent → false"
  (define result (run-last "(satisfies? Nat Nonexistent)"))
  (check-true (string? result))
  (check-true (string-contains? result "false")))

;; ========================================
;; D. Unit tests: direct registry queries
;; ========================================

(test-case "unit: trait registry has Eq"
  (parameterize ([current-trait-registry shared-trait-reg])
    (define tm (lookup-trait 'Eq))
    (check-not-false tm)
    (check-equal? (trait-meta-name tm) 'Eq)))

(test-case "unit: trait registry has Add"
  (parameterize ([current-trait-registry shared-trait-reg])
    (define tm (lookup-trait 'Add))
    (check-not-false tm)
    (check-equal? (trait-meta-name tm) 'Add)))

(test-case "unit: impl registry has Nat--Eq key"
  (parameterize ([current-impl-registry shared-impl-reg])
    (define entry (lookup-impl 'Nat--Eq))
    (check-not-false entry)
    (check-equal? (impl-entry-trait-name entry) 'Eq)))

(test-case "unit: Eq methods list is non-empty"
  (parameterize ([current-trait-registry shared-trait-reg])
    (define tm (lookup-trait 'Eq))
    (check-not-false tm)
    (define methods (trait-meta-methods tm))
    (check-true (pair? methods))
    (check-equal? (trait-method-name (car methods)) 'eq?)))

;; ========================================
;; E. Multiple instances — Eq has many
;; ========================================

(test-case "instances-of: Eq has multiple instances (Int, String, etc.)"
  (define result (run-last "(instances-of Eq)"))
  ;; At minimum: Nat, Bool, Int should be present
  (check-true (string-contains? result "Nat"))
  (check-true (string-contains? result "Bool"))
  (check-true (string-contains? result "Int")))

;; ========================================
;; F. Parametric instances
;; ========================================

(test-case "instances-of: Lattice has parametric instances"
  (define result (run-last "(instances-of Lattice)"))
  (check-true (string? result))
  (check-true (string-contains? result "parametric")
              (format "Expected parametric in output, got:\n~a" result)))
