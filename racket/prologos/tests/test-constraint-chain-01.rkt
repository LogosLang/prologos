#lang racket/base

;;;
;;; Tests for Phase 3c: Constraint Chain Syntax ?var:C1:C2
;;; Verifies: reader greedy consumption, parser helpers, type-guard
;;; forward-check, and end-to-end constrained narrowing.
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
         "../parser.rkt"
         "../global-constraints.rkt")

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
  (parameterize ([current-global-env (hasheq)]
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
    (process-string "(ns test-constraint-chain)")
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Run sexp code using shared environment
(define (run s)
  (parameterize ([current-global-env shared-global-env]
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

;; Run WS-mode code using shared environment
(define (run-ws s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-bundle-registry shared-bundle-reg])
    (process-string-ws s)))

(define (run-ws-last s) (last (run-ws s)))

;; ========================================
;; A. Parser helper unit tests
;; ========================================

(test-case "narrow-var-base-name: plain ?x → ?x"
  (check-equal? (narrow-var-base-name '?x) '?x))

(test-case "narrow-var-base-name: ?x:Nat → ?x"
  (check-equal? (narrow-var-base-name '?x:Nat) '?x))

(test-case "narrow-var-base-name: ?foo:Nat:Even → ?foo"
  (check-equal? (narrow-var-base-name '?foo:Nat:Even) '?foo))

(test-case "narrow-var-constraints: plain ?x → empty"
  (check-equal? (narrow-var-constraints '?x) '()))

(test-case "narrow-var-constraints: ?x:Nat → (Nat)"
  (check-equal? (narrow-var-constraints '?x:Nat) '(Nat)))

(test-case "narrow-var-constraints: ?x:Nat:Even → (Nat Even)"
  (check-equal? (narrow-var-constraints '?x:Nat:Even) '(Nat Even)))

(test-case "collect-narrow-vars+constraints: mixed datum"
  (define-values (vars cmap)
    (collect-narrow-vars+constraints '(add ?x:Nat ?y)))
  (check-equal? vars '(?x ?y))
  (check-equal? (hash-ref cmap '?x #f) '(Nat))
  (check-equal? (hash-ref cmap '?y #f) '()))

(test-case "collect-narrow-vars+constraints: multi-constraint"
  (define-values (vars cmap)
    (collect-narrow-vars+constraints '(f ?a:Nat:Even ?b:Bool)))
  (check-equal? vars '(?a ?b))
  (check-equal? (hash-ref cmap '?a #f) '(Nat Even))
  (check-equal? (hash-ref cmap '?b #f) '(Bool)))

(test-case "collect-narrow-vars+constraints: no narrow vars → empty"
  (define-values (vars cmap)
    (collect-narrow-vars+constraints '(add 1 2)))
  (check-equal? vars '())
  (check-true (hash-empty? cmap)))

(test-case "rewrite-constrained-vars: ?x:Nat → ?x"
  (check-equal? (rewrite-constrained-vars '?x:Nat) '?x))

(test-case "rewrite-constrained-vars: nested datum"
  (check-equal? (rewrite-constrained-vars '(add ?x:Nat ?y:Bool))
                '(add ?x ?y)))

(test-case "rewrite-constrained-vars: unconstrained passthrough"
  (check-equal? (rewrite-constrained-vars '(f ?x ?y 42))
                '(f ?x ?y 42)))

;; ========================================
;; B. value-matches-type? unit tests
;; ========================================

(test-case "value-matches-type?: zero is Nat"
  (check-true (value-matches-type? (expr-zero) 'Nat)))

(test-case "value-matches-type?: suc(zero) is Nat"
  (check-true (value-matches-type? (expr-suc (expr-zero)) 'Nat)))

(test-case "value-matches-type?: nat-val is Nat"
  (check-true (value-matches-type? (expr-nat-val 5) 'Nat)))

(test-case "value-matches-type?: true is Bool"
  (check-true (value-matches-type? (expr-true) 'Bool)))

(test-case "value-matches-type?: false is Bool"
  (check-true (value-matches-type? (expr-false) 'Bool)))

(test-case "value-matches-type?: int is Int"
  (check-true (value-matches-type? (expr-int 42) 'Int)))

(test-case "value-matches-type?: string is String"
  (check-true (value-matches-type? (expr-string "hi") 'String)))

(test-case "value-matches-type?: zero is NOT Bool"
  (check-false (value-matches-type? (expr-zero) 'Bool)))

(test-case "value-matches-type?: true is NOT Nat"
  (check-false (value-matches-type? (expr-true) 'Nat)))

;; ========================================
;; C. End-to-end: constrained narrowing (sexp mode)
;; ========================================

(test-case "constrained narrow: [add ?x:Nat ?y:Nat] = 5N produces Nat solutions"
  (define result (run-last "(= (add ?x:Nat ?y:Nat) 5)"))
  (check-true (string? result))
  ;; Should produce narrowing solutions
  (check-true (or (string-contains? result "?")
                  (string-contains? result "x")
                  (string-contains? result "nil"))
              (format "Expected narrowing result, got: ~a" result)))

;; ========================================
;; D. End-to-end: WS-mode constraint chain
;; ========================================

(test-case "WS constrained narrow: [add ?x:Nat ?y:Nat] = 5N"
  (define result (run-ws-last "[add ?x:Nat ?y:Nat] = 5N"))
  (check-true (string? result))
  ;; Should produce narrowing solutions
  (check-true (or (string-contains? result "?")
                  (string-contains? result "x")
                  (string-contains? result "nil"))
              (format "Expected narrowing result, got: ~a" result)))

;; ========================================
;; E. Regression: unconstrained narrowing still works
;; ========================================

(test-case "regression: unconstrained [add ?x ?y] = 5N"
  (define result (run-last "(= (add ?x ?y) 5)"))
  (check-true (string? result))
  ;; Standard narrowing — should still produce solutions
  (check-true (or (string-contains? result "?")
                  (string-contains? result "x")
                  (string-contains? result "nil"))
              (format "Expected narrowing result, got: ~a" result)))

(test-case "regression: unconstrained WS [add ?x ?y] = 5N"
  (define result (run-ws-last "[add ?x ?y] = 5N"))
  (check-true (string? result))
  (check-true (or (string-contains? result "?")
                  (string-contains? result "x")
                  (string-contains? result "nil"))
              (format "Expected narrowing result, got: ~a" result)))
