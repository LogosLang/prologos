#lang racket/base

;;;
;;; Tests for prologos.core prelude — module loading + end-to-end usage
;;;

(require rackunit
         racket/path
         racket/string
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt")

;; Compute the lib directory path
(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; ========================================
;; Helper: run prologos code with namespace system active
;; ========================================
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)])
    (install-module-loader!)
    (process-string s)))

;; ========================================
;; Test: prologos.core loads successfully
;; ========================================

(test-case "load prologos.core directly"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos.core #f))
    (check-not-false (module-info? mod) "load-module returns module-info")
    (check-equal? (module-info-namespace mod) 'prologos.core)
    ;; Should export id, const, compose, apply, flip
    (define exports (module-info-exports mod))
    (check-not-false (member 'id exports) "exports id")
    (check-not-false (member 'const exports) "exports const")
    (check-not-false (member 'compose exports) "exports compose")
    (check-not-false (member 'apply exports) "exports apply")
    (check-not-false (member 'flip exports) "exports flip")))

;; ========================================
;; Test: ns auto-imports prologos.core
;; ========================================

(test-case "ns auto-imports prologos.core"
  ;; Any file with (ns ...) should automatically get prologos.core
  (define result
    (run-ns "(ns test.auto-import)\n(eval (id Nat zero))"))
  ;; Should have one result: zero : Nat
  (check-equal? (length result) 1)
  (check-equal? (car result) "zero : Nat"))

;; ========================================
;; Test: id function
;; ========================================

(test-case "prologos.core/id polymorphic identity"
  ;; id Nat zero -> zero
  (check-equal?
   (run-ns "(ns test.id)\n(eval (id Nat zero))")
   '("zero : Nat"))
  ;; id Bool true -> true
  (check-equal?
   (run-ns "(ns test.id2)\n(eval (id Bool true))")
   '("true : Bool"))
  ;; id Nat 2 -> 2
  (check-equal?
   (run-ns "(ns test.id3)\n(eval (id Nat (inc (inc zero))))")
   '("2 : Nat")))

;; ========================================
;; Test: const function
;; ========================================

(test-case "prologos.core/const constant function"
  ;; const Nat Bool zero true -> zero
  (check-equal?
   (run-ns "(ns test.const)\n(eval (const Nat Bool zero true))")
   '("zero : Nat"))
  ;; const Bool Nat true zero -> true
  (check-equal?
   (run-ns "(ns test.const2)\n(eval (const Bool Nat true zero))")
   '("true : Bool")))

;; ========================================
;; Test: compose function
;; ========================================

(test-case "prologos.core/compose function composition"
  ;; compose Nat Nat Nat suc suc zero -> 2
  ;; Note: inc/suc is syntax, not first-class. We wrap it in a lambda.
  (check-equal?
   (run-ns "(ns test.compose)\n(def suc-fn <(-> Nat Nat)> (fn [n <Nat>] (inc n)))\n(eval (compose Nat Nat Nat suc-fn suc-fn zero))")
   '("suc-fn : [-> Nat Nat] defined." "2 : Nat"))
  ;; compose Nat Nat Nat suc-fn suc-fn 1 -> 3
  (check-equal?
   (run-ns "(ns test.compose2)\n(def suc-fn <(-> Nat Nat)> (fn [n <Nat>] (inc n)))\n(eval (compose Nat Nat Nat suc-fn suc-fn (inc zero)))")
   '("suc-fn : [-> Nat Nat] defined." "3 : Nat")))

;; ========================================
;; Test: apply function
;; ========================================

(test-case "prologos.core/apply function application"
  ;; apply Nat Nat suc-fn zero -> 1
  (check-equal?
   (run-ns "(ns test.apply)\n(def suc-fn <(-> Nat Nat)> (fn [n <Nat>] (inc n)))\n(eval (apply Nat Nat suc-fn zero))")
   '("suc-fn : [-> Nat Nat] defined." "1 : Nat")))

;; ========================================
;; Test: flip function
;; ========================================

(test-case "prologos.core/flip argument flipping"
  ;; flip Nat Bool Nat (const Nat Bool) true zero -> zero
  ;; const Nat Bool zero true -> zero, so flip should give same result
  (check-equal?
   (run-ns "(ns test.flip)\n(eval (flip Nat Bool Nat (fn (a : Nat) (fn (b : Bool) a)) true zero))")
   '("zero : Nat")))

;; ========================================
;; Test: explicit require of prologos.core
;; ========================================

(test-case "explicit require prologos.core with :as alias"
  (check-equal?
   (run-ns "(ns test.alias)\n(require [prologos.core :as core])\n(eval (core/id Nat zero))")
   '("zero : Nat")))

(test-case "explicit require prologos.core with :refer"
  (check-equal?
   (run-ns "(ns test.refer)\n(require [prologos.core :refer [compose]])\n(def suc-fn <(-> Nat Nat)> (fn [n <Nat>] (inc n)))\n(eval (compose Nat Nat Nat suc-fn suc-fn zero))")
   '("suc-fn : [-> Nat Nat] defined." "2 : Nat")))

;; ========================================
;; Test: type checking of core definitions
;; ========================================

(test-case "core definitions type-check"
  ;; id zero : Nat (implicit type inference for A = Nat)
  (check-equal?
   (run-ns "(ns test.check-id)\n(check (id zero) <Nat>)")
   '("OK"))
  ;; const zero true : Nat (implicit type inference for A = Nat, B = Bool)
  (check-equal?
   (run-ns "(ns test.check-const)\n(check (const zero true) <Nat>)")
   '("OK")))

;; ========================================
;; Regression: non-namespaced code still works
;; ========================================

(test-case "regression: non-namespaced code unaffected"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    ;; Plain code without (ns ...) should work fine
    (define result (process-string "(eval (inc zero))"))
    (check-equal? result '("1 : Nat"))))
