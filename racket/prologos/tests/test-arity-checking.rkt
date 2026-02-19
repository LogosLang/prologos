#lang racket/base

;;;
;;; Tests for Surface-Level Arity Checking
;;;
;;; Verifies that the elaborator detects over-application for known
;;; global functions and constructors, producing clear arity-error messages.
;;; The curried core is unchanged — this is purely surface-level validation.
;;;

(require rackunit
         racket/string
         racket/list
         racket/path
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
         "../namespace.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(define (run-first s) (car (run s)))

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s) (last (run-ns s)))
(define (run-ns-first s) (car (run-ns s)))

;; ========================================
;; Over-application: too many args → arity error
;; ========================================

(test-case "arity/too-many-args-builtin"
  ;; suc takes 1 arg, giving 2 should error
  (define result (run-first "(eval (suc zero zero))"))
  (check-true (prologos-error? result))
  (check-true (arity-error? result))
  (check-equal? (arity-error-expected result) 1)
  (check-equal? (arity-error-got result) 2))

(test-case "arity/too-many-args-user-defn"
  ;; Define a 2-arg function, call with 3
  (define results (run "(def double <(-> Nat Nat)> (fn [x <Nat>] (suc (suc x))))\n(eval (double zero zero))"))
  (define last-result (last results))
  (check-true (prologos-error? last-result))
  (check-true (arity-error? last-result))
  (check-equal? (arity-error-expected last-result) 1)
  (check-equal? (arity-error-got last-result) 2))

(test-case "arity/too-many-args-multi-param"
  ;; Define add-like function, call with 3 args
  (define results
    (run "(def myadd <(-> Nat (-> Nat Nat))> (fn [x <Nat>] (fn [y <Nat>] x)))\n(eval (myadd zero zero zero))"))
  (define last-result (last results))
  (check-true (prologos-error? last-result))
  (check-true (arity-error? last-result))
  (check-equal? (arity-error-expected last-result) 2)
  (check-equal? (arity-error-got last-result) 3))

;; ========================================
;; Correct arity: should succeed
;; ========================================

(test-case "arity/correct-args-builtin"
  ;; suc zero should work fine
  (define result (run-first "(eval (suc zero))"))
  (check-false (prologos-error? result))
  (check-true (string-contains? result "1N : Nat")))

(test-case "arity/correct-args-multi-param"
  ;; natrec with correct arity should work
  (define result (run-first "(eval (natrec Nat zero (fn [k <Nat>] (fn [r <Nat>] (suc r))) (suc zero)))"))
  (check-false (prologos-error? result)))

;; ========================================
;; Implicit arguments: insertion still works
;; ========================================

(test-case "arity/implicits-auto-inserted"
  ;; cons has type Pi(A :0 Type, A -> List A -> List A)
  ;; User provides 2 explicit args (A inferred): cons zero (nil Nat)
  (define result
    (run-ns-last "(ns ar1)\n(require [prologos.data.list :refer [List nil cons]])\n(check (cons zero (nil Nat)) : (List Nat))"))
  (check-equal? result "OK"))

(test-case "arity/implicits-explicit-backward-compat"
  ;; User provides ALL args including implicit: cons Nat zero (nil Nat)
  (define result
    (run-ns-last "(ns ar2)\n(require [prologos.data.list :refer [List nil cons]])\n(check (cons Nat zero (nil Nat)) : (List Nat))"))
  (check-equal? result "OK"))

(test-case "arity/implicits-too-many"
  ;; cons has 1 implicit + 2 explicit = 3 total. Giving 4 should error.
  (define result
    (run-ns-last "(ns ar3)\n(require [prologos.data.list :refer [List nil cons]])\n(eval (cons Nat zero (nil Nat) zero))"))
  (check-true (prologos-error? result))
  (check-true (arity-error? result)))

;; ========================================
;; Local variables: no arity check (defer to type checker)
;; ========================================

(test-case "arity/local-var-no-check"
  ;; Applying a local variable with any number of args should NOT trigger arity error
  ;; (the type checker will handle type mismatches)
  (define result
    (run-first "(def apply-it <(-> (-> Nat Nat) (-> Nat Nat))> (fn [f <(-> Nat Nat)>] (fn [x <Nat>] (f x))))"))
  (check-false (prologos-error? result)))

;; ========================================
;; Error message quality
;; ========================================

(test-case "arity/error-message-shows-function-name"
  (define result (run-first "(eval (suc zero zero))"))
  (check-true (arity-error? result))
  (define formatted (format-error result))
  (check-true (string-contains? formatted "suc"))
  (check-true (string-contains? formatted "1"))  ;; expected 1
  (check-true (string-contains? formatted "2"))) ;; got 2

(test-case "arity/error-message-shows-type-signature"
  ;; Use a user-defined function so the elaborator (not parser) catches the arity error
  ;; and includes the type signature in the error message
  (define results (run "(def double <(-> Nat Nat)> (fn [x <Nat>] (suc (suc x))))\n(eval (double zero zero))"))
  (define last-result (last results))
  (check-true (arity-error? last-result))
  (define formatted (format-error last-result))
  ;; Should show the type signature in the error
  (check-true (string-contains? formatted "Nat"))
  (check-true (string-contains? formatted "Signature:")))

;; ========================================
;; Stdlib: existing functions with correct arity still work
;; ========================================

(test-case "arity/stdlib-add-correct"
  (define result
    (run-ns-last "(ns ar4)\n(require [prologos.data.nat :refer [add]])\n(eval (add (suc zero) (suc (suc zero))))"))
  (check-equal? result "3N : Nat"))

(test-case "arity/stdlib-map-correct"
  (define result
    (run-ns-last "(ns ar5)\n(require [prologos.data.list :refer [List nil cons map]])\n(eval (map Nat Nat (fn [x <Nat>] (suc x)) (cons Nat zero (nil Nat))))"))
  (check-false (prologos-error? result)))

;; ========================================
;; pp-function-signature tests
;; ========================================

(test-case "pp-sig/simple-arrow"
  ;; Nat -> Nat
  (define sig (pp-function-signature (arrow (expr-Nat) (expr-Nat))))
  (check-true (string-contains? sig "Nat")))

(test-case "pp-sig/multi-param"
  ;; Nat -> Nat -> Bool
  (define sig (pp-function-signature (arrow (expr-Nat) (arrow (expr-Nat) (expr-Bool)))))
  (check-true (string-contains? sig "Nat"))
  (check-true (string-contains? sig "Bool")))

(test-case "pp-sig/with-implicit"
  ;; Pi(A :0 Type). A -> A
  (define sig (pp-function-signature
               (expr-Pi 'm0 (expr-Type (lzero))
                 (expr-Pi 'mw (expr-bvar 0) (expr-bvar 1)))))
  (check-true (string-contains? sig "Type")))
