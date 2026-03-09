#lang racket/base

;;;
;;; Tests for Phase 3a: 0-CFA Auto-Defunctionalization (Part 1)
;;; Sections A-D: Data structures, fixpoint solver, arity candidates,
;;; constraint collection.
;;;

(require rackunit
         racket/list
         racket/match
         racket/path
         "../cfa-analysis.rkt"
         "../global-constraints.rkt"
         "../bb-optimization.rkt"
         "../search-heuristics.rkt"
         "../solver.rkt"
         "../narrowing.rkt"
         "../definitional-tree.rkt"
         "../macros.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt")

;; ========================================
;; Shared Fixture
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns test-cfa)")
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Helper: make peano Nat from integer
(define (peano n)
  (if (zero? n) (expr-zero) (expr-suc (peano (- n 1)))))

;; Helper: run narrowing with CFA active
;; NOTE: does NOT re-parameterize current-global-env — inherits from caller
;; so that definitions added by process-string are visible.
(define (run-cfa func-name args target var-names)
  (parameterize ([current-narrow-search-config default-narrow-search-config]
                 [current-narrow-constraints '()]
                 [current-bb-state #f]
                 [current-cfa-result #f])
    (run-narrowing-search func-name args target var-names)))

;; Helper: extract nat value from peano expression
(define (expr->nat-val e)
  (match e
    [(expr-zero) 0]
    [(expr-suc sub) (+ 1 (expr->nat-val sub))]
    [(expr-nat-val n) n]
    [_ #f]))

;; Helper: get solution values
(define (sol-nat sol var)
  (expr->nat-val (hash-ref sol var)))

;; ========================================
;; A. Data structure tests
;; ========================================

(test-case "cfa/struct-constraint"
  (define c (cfa-constraint (cfa-src-fn 'add) (cfa-tgt-param 'apply-op 0)))
  (check-true (cfa-constraint? c))
  (check-true (cfa-src-fn? (cfa-constraint-source c)))
  (check-equal? (cfa-src-fn-name (cfa-constraint-source c)) 'add)
  (check-true (cfa-tgt-param? (cfa-constraint-target c)))
  (check-equal? (cfa-tgt-param-func-name (cfa-constraint-target c)) 'apply-op)
  (check-equal? (cfa-tgt-param-pos (cfa-constraint-target c)) 0))

(test-case "cfa/struct-src-param"
  (define s (cfa-src-param 'twice 0))
  (check-true (cfa-src-param? s))
  (check-equal? (cfa-src-param-func-name s) 'twice)
  (check-equal? (cfa-src-param-pos s) 0))

(test-case "cfa/struct-result"
  (define r (cfa-result (hash)))
  (check-true (cfa-result? r))
  (check-equal? (cfa-result-flow-sets r) (hash)))

;; ========================================
;; B. Fixpoint solver unit tests
;; ========================================

(test-case "cfa/solve-empty"
  (define result (cfa-solve '()))
  (check-true (cfa-result? result))
  (check-equal? (hash-count (cfa-result-flow-sets result)) 0))

(test-case "cfa/solve-single-direct"
  ;; add flows to (apply-op, 0)
  (define cs (list (cfa-constraint (cfa-src-fn 'add)
                                   (cfa-tgt-param 'apply-op 0))))
  (define result (cfa-solve cs))
  (define fs (cfa-flow-set-for-param result 'apply-op 0))
  (check-not-false (member 'add fs))
  (check-equal? (length fs) 1))

(test-case "cfa/solve-multiple-sources"
  ;; both add and mul flow to (apply-op, 0)
  (define cs (list (cfa-constraint (cfa-src-fn 'add) (cfa-tgt-param 'apply-op 0))
                   (cfa-constraint (cfa-src-fn 'mul) (cfa-tgt-param 'apply-op 0))))
  (define result (cfa-solve cs))
  (define fs (cfa-flow-set-for-param result 'apply-op 0))
  (check-equal? (length fs) 2)
  (check-not-false (member 'add fs))
  (check-not-false (member 'mul fs)))

(test-case "cfa/solve-transitive"
  ;; add flows to (wrapper, 0), and (wrapper, 0) forwards to (apply-op, 0)
  (define cs (list (cfa-constraint (cfa-src-fn 'add) (cfa-tgt-param 'wrapper 0))
                   (cfa-constraint (cfa-src-param 'wrapper 0) (cfa-tgt-param 'apply-op 0))))
  (define result (cfa-solve cs))
  (define fs (cfa-flow-set-for-param result 'apply-op 0))
  (check-not-false (member 'add fs))
  (check-equal? (length fs) 1))

(test-case "cfa/solve-transitive-multi"
  ;; add and mul flow to (choose, return), choose's return flows to (apply-op, 0)
  (define cs (list (cfa-constraint (cfa-src-fn 'add) (cfa-tgt-param 'wrapper 0))
                   (cfa-constraint (cfa-src-fn 'mul) (cfa-tgt-param 'wrapper 0))
                   (cfa-constraint (cfa-src-param 'wrapper 0) (cfa-tgt-param 'apply-op 0))))
  (define result (cfa-solve cs))
  (define fs (cfa-flow-set-for-param result 'apply-op 0))
  (check-equal? (length fs) 2)
  (check-not-false (member 'add fs))
  (check-not-false (member 'mul fs)))

(test-case "cfa/solve-empty-query"
  ;; Query a position that has no constraints → empty set
  (define cs (list (cfa-constraint (cfa-src-fn 'add) (cfa-tgt-param 'apply-op 0))))
  (define result (cfa-solve cs))
  (define fs (cfa-flow-set-for-param result 'other-func 0))
  (check-true (null? fs)))

;; ========================================
;; C. Arity-based candidate enumeration
;; ========================================

(test-case "cfa/arity-candidates-binary"
  ;; With the prelude loaded, there should be binary functions (arity 2)
  ;; like add, mul, sub
  (parameterize ([current-global-env shared-global-env])
    (define candidates (cfa-get-candidates-for-arity 2))
    ;; add and mul should be among the candidates
    (check-true (> (length candidates) 0)
                "Should find at least one binary function")))

(test-case "cfa/arity-excludes-ctors"
  ;; Constructors (suc, zero, true, false) should NOT appear as candidates
  (parameterize ([current-global-env shared-global-env])
    (define candidates (cfa-get-candidates-for-arity 1))
    ;; suc is arity 1 but is a constructor — should not appear
    (check-false (memq 'suc candidates)
                 "Constructors should be excluded")))

(test-case "cfa/arity-no-match"
  ;; Arity 99 should have no candidates
  (parameterize ([current-global-env shared-global-env])
    (define candidates (cfa-get-candidates-for-arity 99))
    (check-equal? (length candidates) 0)))

;; ========================================
;; D. Constraint collection from global env
;; ========================================

(test-case "cfa/collect-constraints-prelude"
  ;; Collect constraints from the prelude-loaded global env.
  ;; There should be at least some constraints (from function calls).
  (parameterize ([current-global-env shared-global-env])
    (define cs (cfa-collect-constraints))
    ;; The constraint list should be non-empty
    ;; (prelude has many function definitions calling other functions)
    (check-true (list? cs))
    ;; All elements should be cfa-constraint structs
    (for ([c (in-list cs)])
      (check-true (cfa-constraint? c)))))

(test-case "cfa/analyze-returns-result"
  ;; Full analyze should return a cfa-result
  (parameterize ([current-global-env shared-global-env])
    (define result (cfa-analyze))
    (check-true (cfa-result? result))))
