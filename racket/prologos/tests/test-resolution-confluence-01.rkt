#lang racket/base

;;;
;;; Tests for Track 2 Phase 9: Confluence Verification
;;;
;;; 9a: HKT-7 ambiguity detection (same-specificity parametric ties)
;;; 9b: Resolution confluence (deterministic results across expressions)
;;; 9c: Non-overlapping invariant (monomorphic + parametric coexistence)
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../zonk.rkt")

;; ========================================
;; Shared Fixture (prelude loaded once)
;; ========================================

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-preparse-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns test-resolution-confluence)\n")
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-preparse-registry))))

(define (run code)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-preparse-registry shared-preparse-reg]
                 [current-lib-paths (list prelude-lib-dir)])
    (install-module-loader!)
    (process-string code)))

(define (run-last code)
  (define results (run code))
  (if (null? results) #f (last results)))

;; ========================================
;; 9a: Ambiguity detection (HKT-7)
;; ========================================

(test-case "ambiguity/no-ambiguity-for-Eq-Nat"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-trait-registry shared-trait-reg])
    (check-false (detect-parametric-ambiguity 'Eq (list (expr-Nat))))))

(test-case "ambiguity/no-ambiguity-for-Eq-Bool"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-trait-registry shared-trait-reg])
    (check-false (detect-parametric-ambiguity 'Eq (list (expr-Bool))))))

(test-case "ambiguity/no-ambiguity-for-Add-Nat"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-trait-registry shared-trait-reg])
    (check-false (detect-parametric-ambiguity 'Add (list (expr-Nat))))))

(test-case "ambiguity/no-ambiguity-for-nonexistent-trait"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-trait-registry shared-trait-reg])
    (check-false (detect-parametric-ambiguity 'NonExistentTrait (list (expr-Nat))))))

(test-case "non-overlap/try-parametric-returns-false-for-monomorphic-types"
  (parameterize ([current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-trait-registry shared-trait-reg])
    (check-false (try-parametric-resolve 'Eq (list (expr-Nat))))))

;; ========================================
;; 9b: Confluence — deterministic resolution
;; ========================================

;; Uses `eval [...]` form; only prelude names in global-env are used.

(test-case "confluence/add-resolves"
  (define result (run-last "eval [add 1N 2N]\n"))
  (check-false (and result (prologos-error? result)))
  (check-true (string? result))
  (check-true (string-contains? result "3")))

(test-case "confluence/sub-resolves"
  (define result (run-last "eval [sub 5N 3N]\n"))
  (check-false (and result (prologos-error? result)))
  (check-true (string-contains? result "2")))

(test-case "confluence/lt-resolves"
  (define result (run-last "eval [lt? 1N 2N]\n"))
  (check-false (and result (prologos-error? result)))
  (check-true (string-contains? result "true")))

(test-case "confluence/gt-resolves"
  (define result (run-last "eval [gt? 3N 1N]\n"))
  (check-false (and result (prologos-error? result)))
  (check-true (string-contains? result "true")))

(test-case "confluence/le-resolves"
  (define result (run-last "eval [le? 2N 2N]\n"))
  (check-false (and result (prologos-error? result)))
  (check-true (string-contains? result "true")))

(test-case "confluence/nested-add-sub"
  ;; Nested: [add [sub 5N 3N] 1N] — two independent trait constraints
  (define result (run-last "eval [add [sub 5N 3N] 1N]\n"))
  (check-false (and result (prologos-error? result)))
  (check-true (string-contains? result "3")))

(test-case "confluence/nested-add-add"
  ;; [add [add 1N 2N] [add 3N 4N]] — 3 Add constraints
  (define result (run-last "eval [add [add 1N 2N] [add 3N 4N]]\n"))
  (check-false (and result (prologos-error? result)))
  (check-true (string-contains? result "10")))

(test-case "confluence/repeated-same-expression-deterministic"
  ;; Running the same expression multiple times should produce identical results
  (define r1 (run-last "eval [add 10N 20N]\n"))
  (define r2 (run-last "eval [add 10N 20N]\n"))
  (define r3 (run-last "eval [add 10N 20N]\n"))
  (check-equal? r1 r2)
  (check-equal? r2 r3))

(test-case "confluence/multiple-traits-in-sequence"
  ;; Multiple eval forms that each trigger different trait resolution
  (define results (run "eval [add 1N 2N]\neval [sub 5N 3N]\neval [lt? 1N 2N]\n"))
  ;; Filter out non-error results (eval produces extra unbound-variable-error for 'eval' keyword)
  (define good-results (filter (lambda (r) (and r (string? r))) results))
  (check-true (>= (length good-results) 3))
  ;; Each string result should be a valid value
  (check-true (string-contains? (list-ref good-results 0) "3"))
  (check-true (string-contains? (list-ref good-results 1) "2"))
  (check-true (string-contains? (list-ref good-results 2) "true")))

;; ========================================
;; 9c: Non-overlapping invariant
;; ========================================

(test-case "non-overlap/monomorphic-Add-Nat"
  (define result (run-last "eval [add 1N 1N]\n"))
  (check-false (and result (prologos-error? result)))
  (check-true (string-contains? result "2")))

(test-case "non-overlap/monomorphic-Sub-Nat"
  (define result (run-last "eval [sub 10N 3N]\n"))
  (check-false (and result (prologos-error? result)))
  (check-true (string-contains? result "7")))

(test-case "non-overlap/monomorphic-Ord-Nat"
  (define result (run-last "eval [lt? 5N 10N]\n"))
  (check-false (and result (prologos-error? result)))
  (check-true (string-contains? result "true")))

;; ========================================
;; Determinism: same fixpoint from S0→S1→S2 loop
;; ========================================

(test-case "determinism/complex-nested-stable"
  ;; [add [add 2N 3N] [sub 10N 4N]] = 5 + 6 = 11
  (define r1 (run-last "eval [add [add 2N 3N] [sub 10N 4N]]\n"))
  (define r2 (run-last "eval [add [add 2N 3N] [sub 10N 4N]]\n"))
  (check-false (and r1 (prologos-error? r1)))
  (check-equal? r1 r2)
  (check-true (string-contains? r1 "11")))

(test-case "determinism/deeply-nested-stable"
  ;; [add [add [add 1N 2N] 3N] 4N] = 10
  (define r1 (run-last "eval [add [add [add 1N 2N] 3N] 4N]\n"))
  (define r2 (run-last "eval [add [add [add 1N 2N] 3N] 4N]\n"))
  (check-false (and r1 (prologos-error? r1)))
  (check-equal? r1 r2)
  (check-true (string-contains? r1 "10")))
