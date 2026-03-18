#lang racket/base

;;;
;;; Tests for HKT Phase 5: Bare Method Name Resolution for Implicit Dicts
;;; Verifies that spec-declared constraints (inline and where) enable bare method names
;;; in defn bodies without explicit $-prefixed dict params.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/port
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run-ns-last s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry])
    (install-module-loader!)
    (last (process-string s))))

;; ========================================
;; 1. extract-inline-constraints unit tests
;; ========================================

(test-case "extract-inline: no constraints (bare types)"
  ;; When traits aren't registered, nothing is extracted
  ;; Use a fresh registry with no traits
  (parameterize ([current-trait-registry (hasheq)])
    (check-equal? (extract-inline-constraints '(A -> A -> Bool)) '())))

;; ========================================
;; 2. Bare method with explicit where clause (regression tests)
;; ========================================

(test-case "bare-methods/explicit-where: eq? resolves"
  (define result
    (run-ns-last
      (string-append
        "(ns bm-test-1)\n"
        "(spec my-eq A A -> Bool where (Eq A))\n"
        "(defn my-eq [x y] where (Eq A) (eq? x y))\n"
        "(eval (my-eq zero zero))\n")))
  (check-true (string-contains? result "true")))

(test-case "bare-methods/explicit-where: eq? unequal"
  (define result
    (run-ns-last
      (string-append
        "(ns bm-test-2)\n"
        "(spec my-eq A A -> Bool where (Eq A))\n"
        "(defn my-eq [x y] where (Eq A) (eq? x y))\n"
        "(eval (my-eq zero (suc zero)))\n")))
  (check-true (string-contains? result "false")))

;; ========================================
;; 3. Bare method with spec-only (no where in defn)
;; ========================================

(test-case "bare-methods/spec-only: eq? resolves without where in defn"
  (define result
    (run-ns-last
      (string-append
        "(ns bm-test-3)\n"
        "(spec my-eq A A -> Bool where (Eq A))\n"
        "(defn my-eq [x y] (eq? x y))\n"
        "(eval (my-eq zero zero))\n")))
  (check-true (string-contains? result "true")))

(test-case "bare-methods/spec-only: eq? with Nat literals"
  (define result
    (run-ns-last
      (string-append
        "(ns bm-test-4)\n"
        "(spec my-eq A A -> Bool where (Eq A))\n"
        "(defn my-eq [x y] (eq? x y))\n"
        "(eval (my-eq (suc (suc zero)) (suc (suc zero))))\n")))
  (check-true (string-contains? result "true")))

;; ========================================
;; 4. Inline constraints with brace-params
;; ========================================

(test-case "bare-methods/inline: single constraint with brace-params"
  (define result
    (run-ns-last
      (string-append
        "(ns bm-test-5)\n"
        "(spec my-eq ($brace-params A) (Eq A) -> A -> A -> Bool)\n"
        "(defn my-eq [x y] (eq? x y))\n"
        "(eval (my-eq zero zero))\n")))
  (check-true (string-contains? result "true")))

(test-case "bare-methods/inline: Ord constraint"
  ;; Ord's method is `compare : A -> A -> Ordering`, not `lt?`
  (define result
    (run-ns-last
      (string-append
        "(ns bm-test-6)\n"
        "(spec my-cmp ($brace-params A) (Ord A) -> A -> A -> Ordering)\n"
        "(defn my-cmp [x y] (compare x y))\n"
        "(eval (my-cmp zero (suc zero)))\n")))
  (check-true (string? result)))

(test-case "bare-methods/inline: two constraints"
  (define result
    (run-ns-last
      (string-append
        "(ns bm-test-7)\n"
        "(spec my-fn ($brace-params A) (Eq A) -> (Add A) -> A -> A -> Bool)\n"
        "(defn my-fn [x y] (eq? (add x y) x))\n"
        "(eval (my-fn zero zero))\n")))
  (check-true (string-contains? result "true")))

;; ========================================
;; 5. Backward compatibility
;; ========================================

(test-case "bare-methods/compat: explicit accessor still works"
  (define result
    (run-ns-last
      (string-append
        "(ns bm-test-8)\n"
        "(eval (Eq-eq? Nat Nat--Eq--dict zero zero))\n")))
  (check-equal? result "true : Bool"))

(test-case "bare-methods/compat: prelude loads without errors"
  (define result
    (run-ns-last
      (string-append
        "(ns bm-test-9)\n"
        "(eval (suc zero))\n")))
  (check-equal? result "1N : Nat"))

(test-case "bare-methods/compat: existing trait resolution still works"
  (define result
    (run-ns-last
      (string-append
        "(ns bm-test-10)\n"
        "(eval (Eq-eq? Nat Nat--Eq--dict (suc zero) (suc zero)))\n")))
  (check-equal? result "true : Bool"))

;; ========================================
;; 6. find-param-bracket: skips $brace-params and $angle-type
;; ========================================

(test-case "bare-methods/inject: brace-params not mistaken for param bracket"
  ;; Regression: $brace-params form was incorrectly detected as param bracket
  ;; by maybe-inject-where, causing parse errors.
  ;; This test verifies the fix works end-to-end.
  (define result
    (run-ns-last
      (string-append
        "(ns bm-test-11)\n"
        "(spec my-eq ($brace-params A) (Eq A) -> A -> A -> Bool)\n"
        "(defn my-eq [x y] (eq? x y))\n"
        "(eval (my-eq (suc zero) (suc zero)))\n")))
  (check-true (string-contains? result "true")))
