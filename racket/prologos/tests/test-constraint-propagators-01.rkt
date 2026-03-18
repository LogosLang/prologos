#lang racket/base

;;;
;;; Tests for constraint-propagators.rkt — Phase 2c
;;; Verifies: registry query, type-tag inference, constraint refinement,
;;; resolve-generic-narrowing dispatch, and P1-P4 propagator constructors.
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         racket/port
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../reduction.rkt"
         "../narrowing.rkt"
         "../namespace.rkt"
         "../constraint-cell.rkt"
         "../constraint-propagators.rkt"
         "../propagator.rkt")

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
    (process-string "(ns test-constraint-propagators)")
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

;; Count solution maps in pretty-printed output
(define (count-answers result-str)
  (length (regexp-match* #rx"\\{:" result-str)))

;; ========================================
;; A. build-trait-constraint
;; ========================================

(test-case "build-trait-constraint: Add has multiple candidates"
  (parameterize ([current-impl-registry shared-impl-reg])
    (define cv (build-trait-constraint 'Add))
    ;; Add has impls for Nat, Int, Rat at minimum
    (check-false (constraint-bot? cv))
    (check-false (constraint-top? cv))
    (define cs (constraint-candidates cv))
    (check-true (list? cs))
    (check-true (>= (length cs) 3)
                (format "Expected ≥3 Add impls, got ~a" (length cs)))))

(test-case "build-trait-constraint: Eq has multiple candidates"
  (parameterize ([current-impl-registry shared-impl-reg])
    (define cv (build-trait-constraint 'Eq))
    (check-false (constraint-bot? cv))
    (check-false (constraint-top? cv))
    (define cs (constraint-candidates cv))
    (check-true (list? cs))
    (check-true (>= (length cs) 2)
                (format "Expected ≥2 Eq impls, got ~a" (length cs)))))

(test-case "build-trait-constraint: nonexistent trait → top"
  (parameterize ([current-impl-registry shared-impl-reg])
    (define cv (build-trait-constraint 'Nonexistent))
    (check-true (constraint-top? cv))))

;; ========================================
;; B. infer-narrowing-type-tag
;; ========================================

(test-case "infer-narrowing-type-tag: Nat literals → 'Nat"
  (check-equal? (infer-narrowing-type-tag (list (expr-zero))) 'Nat)
  (check-equal? (infer-narrowing-type-tag (list (expr-suc (expr-zero)))) 'Nat)
  (check-equal? (infer-narrowing-type-tag (list (expr-nat-val 5))) 'Nat))

(test-case "infer-narrowing-type-tag: non-negative Int → 'Nat"
  (check-equal? (infer-narrowing-type-tag (list (expr-int 3))) 'Nat)
  (check-equal? (infer-narrowing-type-tag (list (expr-int 0))) 'Nat))

(test-case "infer-narrowing-type-tag: negative Int → 'Int"
  (check-equal? (infer-narrowing-type-tag (list (expr-int -5))) 'Int))

(test-case "infer-narrowing-type-tag: Rat → 'Rat"
  (check-equal? (infer-narrowing-type-tag (list (expr-rat 3/4))) 'Rat))

(test-case "infer-narrowing-type-tag: String → 'String"
  (check-equal? (infer-narrowing-type-tag (list (expr-string "hello"))) 'String))

(test-case "infer-narrowing-type-tag: unground → #f"
  (check-false (infer-narrowing-type-tag (list (expr-fvar '?x)))))

;; ========================================
;; C. refine-constraint-by-type-tag
;; ========================================

(test-case "refine/type-tag: Add refined by Nat → single candidate"
  (parameterize ([current-impl-registry shared-impl-reg])
    (define cv0 (build-trait-constraint 'Add))
    (define cv1 (refine-constraint-by-type-tag cv0 'Nat))
    (check-true (constraint-one? cv1))
    (define cand (constraint-one-candidate cv1))
    (check-equal? (constraint-candidate-trait-name cand) 'Add)
    (check-true (type-args-match-tag?
                 (constraint-candidate-type-args cand) 'Nat))))

(test-case "refine/type-tag: Add refined by Int → single candidate"
  (parameterize ([current-impl-registry shared-impl-reg])
    (define cv0 (build-trait-constraint 'Add))
    (define cv1 (refine-constraint-by-type-tag cv0 'Int))
    (check-true (constraint-one? cv1))
    (define cand (constraint-one-candidate cv1))
    (check-true (type-args-match-tag?
                 (constraint-candidate-type-args cand) 'Int))))

(test-case "refine/type-tag: bot unchanged by refinement"
  (define cv (refine-constraint-by-type-tag constraint-bot 'Nat))
  (check-true (constraint-bot? cv)))

;; ========================================
;; D. resolve-generic-narrowing (end-to-end dispatch)
;; ========================================

(test-case "resolve-generic-narrowing: Add with Nat args → FQN"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-prelude-env shared-global-env])
    (define result (resolve-generic-narrowing 'Add (list (expr-nat-val 1) (expr-fvar '?y))
                                              (expr-nat-val 3)))
    (check-true (symbol? result)
                (format "Expected symbol, got ~a" result))
    ;; Should resolve to the Nat add method helper
    (check-true (string-contains? (symbol->string result) "Nat--Add--add")
                (format "Expected Nat--Add--add in FQN, got ~a" result))))

(test-case "resolve-generic-narrowing: Sub with Nat args → FQN"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-prelude-env shared-global-env])
    (define result (resolve-generic-narrowing 'Sub (list (expr-nat-val 5) (expr-fvar '?y))
                                              (expr-nat-val 2)))
    (check-true (symbol? result)
                (format "Expected symbol, got ~a" result))))

(test-case "resolve-generic-narrowing: Mul with Nat args → FQN"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-prelude-env shared-global-env])
    (define result (resolve-generic-narrowing 'Mul (list (expr-nat-val 2) (expr-fvar '?y))
                                              (expr-nat-val 6)))
    (check-true (symbol? result)
                (format "Expected symbol, got ~a" result))))

(test-case "resolve-generic-narrowing: unground args + Nat target → FQN via target"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-prelude-env shared-global-env])
    (define result (resolve-generic-narrowing 'Add (list (expr-fvar '?x) (expr-fvar '?y))
                                              (expr-nat-val 5)))
    (check-true (symbol? result)
                (format "Expected symbol from target inference, got ~a" result))))

(test-case "resolve-generic-narrowing: nonexistent trait → #f"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-prelude-env shared-global-env])
    (check-false (resolve-generic-narrowing 'Nonexistent
                                             (list (expr-nat-val 1))
                                             (expr-nat-val 2)))))

;; ========================================
;; E. Propagator network integration (P1)
;; ========================================

(test-case "P1: type→constraint propagator narrows on type tag"
  (parameterize ([current-impl-registry shared-impl-reg])
    (define cv0 (build-trait-constraint 'Add))
    ;; Create a prop-network with type cell + constraint cell
    (define net0 (make-prop-network))
    (define-values (net1 type-cell) (net-new-cell net0 'unknown
                                                   (lambda (old new) new)))
    (define-values (net2 constraint-cell) (net-new-cell net1 cv0
                                                         constraint-merge
                                                         constraint-contradicts?))
    ;; Install P1: type cell → constraint cell
    (define-values (net3 _p1-id) (install-type->constraint-propagator
                                   net2 type-cell constraint-cell
                                   (lambda (v) (if (symbol? v) v #f))))
    ;; Write 'Nat to type cell → should narrow constraint to single candidate
    (define net4 (net-cell-write net3 type-cell 'Nat))
    (define net5 (run-to-quiescence net4))
    (define result-cv (net-cell-read net5 constraint-cell))
    (check-true (constraint-one? result-cv)
                (format "Expected constraint-one after type='Nat, got ~a"
                        (constraint->datum result-cv)))))

;; ========================================
;; F. Regression: narrowing dispatch still works end-to-end
;; ========================================

(test-case "regression: (+ 1 ?y) = 3 → 1 solution"
  (define result (run-last "(= (+ 1 ?y) 3)"))
  (check-equal? (count-answers result) 1)
  (check-true (string-contains? result ":y")))

(test-case "regression: (+ ?x ?y) = 5 → 6 solutions"
  (define result (run-last "(= (+ ?x ?y) 5)"))
  (check-equal? (count-answers result) 6))

(test-case "regression: (add ?x ?y) = 3 → 4 solutions (direct name)"
  (define result (run-last "(= (add ?x ?y) 3)"))
  (check-equal? (count-answers result) 4))
