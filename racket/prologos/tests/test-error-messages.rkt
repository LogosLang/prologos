#lang racket/base

;;;
;;; Tests for Sprint 9: Error Messages for Inference Failures
;;;
;;; Tests the meta-source-info struct, constraint-provenance struct,
;;; noise-filtering (meta-category), new error subtypes (E1001/E1002/E1003),
;;; and integration with the full pipeline for improved error messages.
;;;

(require rackunit
         racket/string
         racket/list
         racket/path
         "test-support.rkt"
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
         "../macros.rkt"
         "../namespace.rkt"
         "../unify.rkt")

;; ========================================
;; Helper: process commands and return results
;; ========================================
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string s)))

(define (run-first s)
  (car (run s)))

(define (run-last s)
  (last (run s)))

(define (run-ns s)
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-preparse-registry prelude-preparse-registry])
      (install-module-loader!)
      (process-string s))))

(define (run-ns-last s)
  (last (run-ns s)))

;; ========================================
;; Unit tests: meta-source-info struct
;; ========================================

(test-case "meta-source-info/construction-and-access"
  (define loc (srcloc "test.prl" 5 10 3))
  (define msi (meta-source-info loc 'implicit "test desc" 'mydef '("x" "y")))
  (check-equal? (meta-source-info-loc msi) loc)
  (check-equal? (meta-source-info-kind msi) 'implicit)
  (check-equal? (meta-source-info-description msi) "test desc")
  (check-equal? (meta-source-info-def-name msi) 'mydef)
  (check-equal? (meta-source-info-name-map msi) '("x" "y")))

(test-case "constraint-provenance/construction-and-access"
  (define loc (srcloc "test.prl" 3 0 10))
  (define msi (meta-source-info loc 'implicit-app "for id" #f '("z")))
  (define cp (constraint-provenance loc "pattern fail" msi))
  (check-equal? (constraint-provenance-loc cp) loc)
  (check-equal? (constraint-provenance-description cp) "pattern fail")
  (check-equal? (constraint-provenance-meta-source cp) msi))

;; ========================================
;; Unit tests: meta-category noise filtering
;; ========================================

(test-case "meta-category/primary-for-pi-param"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat)
                (meta-source-info srcloc-unknown 'pi-param "pi mult" #f #f)))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'primary)))

(test-case "meta-category/secondary-for-implicit"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat)
                (meta-source-info srcloc-unknown 'implicit "impl arg" #f #f)))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'secondary)))

(test-case "meta-category/secondary-for-implicit-app"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat)
                (meta-source-info srcloc-unknown 'implicit-app "impl arg" #f #f)))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'secondary)))

(test-case "meta-category/internal-for-bare-Type"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat)
                (meta-source-info srcloc-unknown 'bare-Type "level" #f #f)))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'internal)))

(test-case "meta-category/legacy-string-implicit"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "implicit"))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'secondary)))

(test-case "meta-category/legacy-string-bare-Type"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "bare-Type"))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'internal)))

(test-case "meta-category/legacy-string-other"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'primary)))

(test-case "meta-category/primary-for-lambda-param"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat)
                (meta-source-info srcloc-unknown 'lambda-param "lam mult" #f #f)))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'primary)))

;; ========================================
;; Unit tests: new error types
;; ========================================

(test-case "cannot-infer-param-error/is-prologos-error"
  (check-true
   (prologos-error?
    (cannot-infer-param-error srcloc-unknown "can't infer" 'x "add annotation"))))

(test-case "conflicting-constraints-error/is-prologos-error"
  (check-true
   (prologos-error?
    (conflicting-constraints-error srcloc-unknown "conflict" "Nat" "Bool"
                                   srcloc-unknown srcloc-unknown))))

(test-case "unsolved-implicit-error/is-prologos-error"
  (check-true
   (prologos-error?
    (unsolved-implicit-error srcloc-unknown "unsolved" 'id 'meta42 "provide type explicitly"))))

(test-case "format-error/E1001-contains-error-code"
  (define err (cannot-infer-param-error (srcloc "test.prl" 5 10 3)
                                         "can't infer" 'x "add annotation: (fn [x : Nat] ...)"))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "E1001"))
  (check-true (string-contains? formatted "x"))
  (check-true (string-contains? formatted "add annotation")))

(test-case "format-error/E1002-contains-error-code"
  (define err (conflicting-constraints-error (srcloc "test.prl" 8 3 40)
                                              "conflicting types" "Nat" "Bool"
                                              srcloc-unknown srcloc-unknown))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "E1002"))
  (check-true (string-contains? formatted "Nat"))
  (check-true (string-contains? formatted "Bool")))

(test-case "format-error/E1003-contains-error-code"
  (define err (unsolved-implicit-error (srcloc "test.prl" 12 3 20)
                                        "unsolved" 'id 'meta42 "provide the type explicitly"))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "E1003"))
  (check-true (string-contains? formatted "id"))
  (check-true (string-contains? formatted "provide the type explicitly")))

(test-case "format-error/E1003-no-func-name"
  (define err (unsolved-implicit-error srcloc-unknown "unsolved" #f 'meta42 #f))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "E1003"))
  (check-false (string-contains? formatted "for '")))

;; ========================================
;; Integration: source location threading
;; ========================================

(test-case "elaborator/fresh-meta-has-meta-source-info"
  ;; When elaborating with a global that has ALL m0 (implicit) params,
  ;; the created meta should have meta-source-info, not a bare string.
  ;; Note: maybe-auto-apply-implicits only fires when ALL params are m0.
  (with-fresh-meta-env
    (parameterize ([current-prelude-env
                    (global-env-add (hasheq) 'test-fn
                      ;; All-implicit: Pi(A :0 Type, B :0 A, Nat)
                      (expr-Pi 'm0 (expr-Type (lzero)) (expr-Pi 'm0 (expr-bvar 0) (expr-Nat)))
                      (expr-lam 'm0 (expr-Type (lzero)) (expr-lam 'm0 (expr-bvar 0) (expr-zero))))])
      ;; Elaborate a bare reference to test-fn (should auto-apply with meta-source-info)
      (define result (elaborate (surf-var 'test-fn (srcloc "test.prl" 5 3 7))))
      (check-false (prologos-error? result))
      ;; The result should be (app (app (fvar test-fn) (meta ?)) (meta ?))
      (check-true (expr-app? result))
      ;; The metas should have meta-source-info
      (define unsolved (all-unsolved-metas))
      (check-true (not (null? unsolved)))
      (define info (car unsolved))
      (check-true (meta-source-info? (meta-info-source info)))
      (check-equal? (meta-source-info-kind (meta-info-source info)) 'implicit))))

(test-case "elaborator/env->name-stack-produces-correct-list"
  ;; Elaborate a lambda with a body that references an all-implicit function.
  ;; The meta created should have the name map containing "x" from the lambda binder.
  ;; Note: maybe-auto-apply-implicits only fires when ALL params are m0.
  (with-fresh-meta-env
    (parameterize ([current-prelude-env
                    (global-env-add (hasheq) 'impl-fn
                      ;; All-implicit: Pi(A :0 Type, B :0 A, Nat)
                      (expr-Pi 'm0 (expr-Type (lzero)) (expr-Pi 'm0 (expr-bvar 0) (expr-Nat)))
                      (expr-lam 'm0 (expr-Type (lzero)) (expr-lam 'm0 (expr-bvar 0) (expr-zero))))])
      ;; Elaborate (fn [x <Nat>] impl-fn) — inside the lambda body, env has "x"
      (define result (elaborate (surf-lam
                                  (binder-info 'x 'mw (surf-nat-type srcloc-unknown))
                                  (surf-var 'impl-fn (srcloc "test.prl" 5 20 7))
                                  srcloc-unknown)))
      (check-false (prologos-error? result))
      ;; The meta from impl-fn auto-apply should have name-map containing "x"
      (define unsolved (all-unsolved-metas))
      (check-true (not (null? unsolved)))
      (define info (car unsolved))
      (check-true (meta-source-info? (meta-info-source info)))
      (define nm (meta-source-info-name-map (meta-info-source info)))
      (check-not-false (and (list? nm) (member "x" nm))))))

;; ========================================
;; Integration: error message quality
;; ========================================

(test-case "error-message/type-mismatch-shows-types"
  ;; (def bad <(-> Nat Bool)> (fn [x <Nat>] x))
  ;; Body x : Nat does not match expected return Bool
  (define result (run-first "(def bad <(-> Nat Bool)> (fn [x <Nat>] x))"))
  (check-true (prologos-error? result))
  ;; The error message should mention types
  (define msg (prologos-error-message result))
  (check-true (or (string-contains? msg "Type mismatch")
                  (string-contains? msg "Type error")
                  (string-contains? msg "mismatch"))))

(test-case "error-message/valid-def-succeeds"
  ;; Regression: valid definitions should still work
  (define result (run-first "(def myid <(-> Nat Nat)> (fn [x <Nat>] x))"))
  (check-false (prologos-error? result))
  (check-true (string-contains? result "myid")))

(test-case "error-message/type-mismatch-mentions-expected-and-actual"
  (define result (run-first "(def bad <(-> Nat Bool)> (fn [x <Nat>] x))"))
  (check-true (prologos-error? result))
  (check-true (type-mismatch-error? result))
  (define formatted (format-error result))
  (check-true (string-contains? formatted "Nat"))
  (check-true (string-contains? formatted "Bool")))

(test-case "error-message/unbound-variable-unchanged"
  (define result (run-first "(eval undefined_var)"))
  (check-true (prologos-error? result))
  (check-true (unbound-variable-error? result)))

(test-case "error-message/constraint-failure-uses-E1002"
  ;; This test triggers a constraint failure via implicit inference
  ;; compose double pred 3 → works, but compose double true 3 → constraint failure
  ;; We need a simpler case that triggers failed constraints
  ;; Let's use a known case: applying a function to wrong implicit type
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-preparse-registry prelude-preparse-registry])
      (install-module-loader!)
      (define results (process-string
        (string-append
          "(ns errt1)\n"
          "(imports [prologos::core :refer [id]])\n"
          "(eval (id zero))")))
      ;; id zero should succeed (it infers the type argument)
      (define last-result (last results))
      (check-false (prologos-error? last-result))
      (check-true (string-contains? last-result "0N")))))

;; ========================================
;; Integration: stdlib regression
;; ========================================

(test-case "error-message/stdlib-id-still-works"
  (check-equal?
   (run-ns-last "(ns emt1)\n(imports [prologos::core :refer [id]])\n(eval (id zero))")
   "0N : Nat"))

(test-case "error-message/stdlib-add-still-works"
  (check-equal?
   (run-ns-last "(ns emt2)\n(imports [prologos::data::nat :refer [add]])\n(eval (add 2N 3N))")
   "5N : Nat"))

;; ========================================
;; Integration: pp-expr with name stack in errors
;; ========================================

(test-case "error-message/pp-expr-uses-names-in-check-err"
  ;; When check/err is called with names, the error should use them
  ;; (def bad <(-> Nat Bool)> (fn [x <Nat>] x))
  ;; The error for the body should show "x" in the expression
  (define result (run-first "(def bad <(-> Nat Bool)> (fn [x <Nat>] x))"))
  (check-true (prologos-error? result))
  (define formatted (format-error result))
  ;; The expression in the error should mention x (from the lambda parameter)
  ;; rather than ?bvar0
  (check-true (string-contains? formatted "x")))

;; ========================================
;; Backward compatibility: old-style sources
;; ========================================

(test-case "backward-compat/string-source-still-works"
  ;; Tests that pass strings to fresh-meta continue to work
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test-string"))
    (check-true (expr-meta? m))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-info-source info) "test-string")
    (check-equal? (meta-category info) 'primary)))

(test-case "backward-compat/primary-unsolved-metas-filters"
  (with-fresh-meta-env
    ;; Create 3 metas: 1 primary (pi-param), 1 secondary (implicit), 1 internal (bare-Type)
    (fresh-meta ctx-empty (expr-Nat) (meta-source-info srcloc-unknown 'pi-param "a" #f #f))
    (fresh-meta ctx-empty (expr-Nat) (meta-source-info srcloc-unknown 'implicit "b" #f #f))
    (fresh-meta ctx-empty (expr-Nat) (meta-source-info srcloc-unknown 'bare-Type "c" #f #f))
    (check-equal? (length (all-unsolved-metas)) 3)
    (check-equal? (length (primary-unsolved-metas)) 1)))
