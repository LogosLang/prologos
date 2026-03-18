#lang racket/base

;;;
;;; Tests for Phase 2d: ATMS multi-candidate search for constraint cells
;;; Verifies: candidate->func-name, resolve-generic-narrowing-candidates,
;;; multi-dispatch narrowing end-to-end.
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
         "../constraint-cell.rkt"
         "../constraint-propagators.rkt")

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
    (process-string "(ns test-constraint-amb)")
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
;; A. Unit tests: resolve-generic-narrowing-candidates
;; ========================================

(test-case "candidates: Add with no type info → multiple candidates"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-prelude-env shared-global-env])
    (define cands
      (resolve-generic-narrowing-candidates 'Add (list (expr-fvar '?x) (expr-fvar '?y))))
    (check-true (list? cands))
    (check-true (>= (length cands) 3)
                (format "Expected ≥3 Add candidates, got ~a" (length cands)))))

(test-case "candidates: Add with Nat type tag → single candidate"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-prelude-env shared-global-env])
    (define cands
      (resolve-generic-narrowing-candidates 'Add (list (expr-nat-val 1) (expr-fvar '?y))))
    (check-equal? (length cands) 1
                  (format "Expected 1 Nat Add candidate, got ~a" (length cands)))))

(test-case "candidates: nonexistent trait → empty"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-prelude-env shared-global-env])
    (define cands
      (resolve-generic-narrowing-candidates 'Nonexistent (list (expr-fvar '?x))))
    (check-equal? cands '())))

;; ========================================
;; B. Unit tests: candidate->func-name
;; ========================================

(test-case "candidate->func-name: Add Nat → FQN symbol"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-prelude-env shared-global-env])
    (define cand (constraint-candidate 'Add '(Nat) 'prologos::data::nat::add))
    (define fname (candidate->func-name 'Add cand))
    (check-true (symbol? fname)
                (format "Expected symbol, got ~a" fname))
    (check-true (string-contains? (symbol->string fname) "Nat--Add--add")
                (format "Expected Nat--Add--add in FQN, got ~a" fname))))

(test-case "candidate->func-name: nonexistent trait → #f"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-prelude-env shared-global-env])
    (define cand (constraint-candidate 'Nonexistent '(Nat) 'fake))
    (define fname (candidate->func-name 'Nonexistent cand))
    (check-false fname)))

;; ========================================
;; C. Regression: single-candidate dispatch still works
;; ========================================

(test-case "regression: (+ ?x ?y) = 5 → 6 solutions (existing behavior)"
  (define result (run-last "(= (+ ?x ?y) 5)"))
  (check-true (string? result)
              (format "Expected string, got ~a" result))
  (check-equal? (count-answers result) 6))

(test-case "regression: (+ ?x ?y) = 3 → 4 solutions"
  (define result (run-last "(= (+ ?x ?y) 3)"))
  (check-true (string? result))
  (check-equal? (count-answers result) 4))

;; ========================================
;; D. Multi-candidate narrowing end-to-end
;; ========================================

;; Static dispatch works when args or target provide Nat type info.
;; These tests verify that the refactored dispatch path (candidate->func-name)
;; produces the same results as before.

(test-case "dispatch: (+ 2 ?y) = 5 → 1 solution (arg provides Nat tag)"
  (define result (run-last "(= (+ 2 ?y) 5)"))
  (check-true (string? result))
  (check-equal? (count-answers result) 1))

;; ========================================
;; E. Refactored resolve-generic-narrowing uses candidate->func-name
;; ========================================

(test-case "resolve-generic-narrowing: still resolves Add with Nat args"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-prelude-env shared-global-env])
    (define result (resolve-generic-narrowing 'Add (list (expr-nat-val 1) (expr-fvar '?y))
                                              (expr-nat-val 3)))
    (check-true (symbol? result)
                (format "Expected symbol, got ~a" result))
    (check-true (string-contains? (symbol->string result) "Nat--Add--add")
                (format "Expected Nat--Add--add in FQN, got ~a" result))))

(test-case "resolve-generic-narrowing: unground → #f (multi-candidate takes over)"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-prelude-env shared-global-env])
    (define result (resolve-generic-narrowing 'Add (list (expr-fvar '?x) (expr-fvar '?y))))
    (check-false result)))
