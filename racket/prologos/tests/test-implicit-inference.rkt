#lang racket/base

;;;
;;; Tests for Sprint 3: Implicit Argument Inference via Metavariables
;;;
;;; Tests that m0-multiplicity (erased) type parameters are automatically
;;; inferred by unification when the user omits them.
;;;

(require rackunit
         racket/path
         racket/string
         racket/list
         "test-support.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../metavar-store.rkt")

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry])
    (install-module-loader!)
    (process-string s)))

;; Helper: run code and return the last result line
(define (run-last s)
  (last (run-ns s)))

;; ========================================
;; Basic identity function: implicit type arg
;; ========================================

(test-case "implicit/id-nat"
  ;; (id zero) infers A = Nat
  (check-equal?
   (run-last "(ns imp1)\n(imports [prologos::core :refer [id]])\n(eval (id zero))")
   "0N : Nat"))

(test-case "implicit/id-bool"
  ;; (id true) infers A = Bool
  (check-equal?
   (run-last "(ns imp2)\n(imports [prologos::core :refer [id]])\n(eval (id true))")
   "true : Bool"))

(test-case "implicit/id-suc"
  ;; (id (suc zero)) infers A = Nat
  (check-equal?
   (run-last "(ns imp3)\n(imports [prologos::core :refer [id]])\n(eval (id (suc zero)))")
   "1N : Nat"))

;; ========================================
;; Const function: two implicit type args
;; ========================================

(test-case "implicit/const-nat-bool"
  ;; (const zero true) infers A = Nat, B = Bool
  (check-equal?
   (run-last "(ns imp4)\n(imports [prologos::core :refer [const]])\n(eval (const zero true))")
   "0N : Nat"))

;; ========================================
;; List operations with implicit inference
;; ========================================

(test-case "implicit/singleton"
  ;; (singleton zero) infers A = Nat, produces a 1-element list
  (check-equal?
   (run-last "(ns imp5)\n(imports [prologos::data::list :refer [singleton length]])\n(eval (length Nat (singleton Nat zero)))")
   "1N : Nat"))

(test-case "implicit/map-suc"
  ;; map suc [0, 1] then foldr add → 3
  (check-equal?
   (run-last "(ns imp6)\n(imports [prologos::data::list :refer [List nil cons map foldr]])\n(imports [prologos::data::nat :refer [add]])\n(eval (foldr Nat Nat add zero (map Nat Nat (fn (x : Nat) (suc x)) (cons Nat zero (cons Nat (suc zero) (nil Nat))))))")
   "3N : Nat"))

(test-case "implicit/append"
  ;; append [1] [2] then length → 2
  (check-equal?
   (run-last "(ns imp7)\n(imports [prologos::data::list :refer [List nil cons append length]])\n(eval (length Nat (append Nat (cons Nat (suc zero) (nil Nat)) (cons Nat (suc (suc zero)) (nil Nat)))))")
   "2N : Nat"))

(test-case "implicit/head"
  ;; head with default
  (check-equal?
   (run-last "(ns imp8)\n(imports [prologos::data::list :refer [List nil cons head]])\n(eval (head Nat zero (cons Nat (suc (suc zero)) (nil Nat))))")
   "2N : Nat"))

;; ========================================
;; Option with implicit inference
;; ========================================

(test-case "implicit/option-some"
  (check-equal?
   (run-last "(ns imp9)\n(imports [prologos::data::option :refer [some unwrap-or]])\n(eval (unwrap-or Nat zero (some Nat (suc zero))))")
   "1N : Nat"))

;; ========================================
;; Explicit args still work (backward compat)
;; ========================================

(test-case "implicit/explicit-still-works"
  ;; Providing ALL args (including type) should still work
  ;; id with 2 args = explicit type + value — no implicit insertion needed
  (check-equal?
   (run-last "(ns imp10)\n(def id <(Pi [A :0 <(Type 0)>] (-> A A))>\n  (fn [A :0 <(Type 0)>] (fn [x <A>] x)))\n(eval (id Nat zero))")
   "0N : Nat"))

;; ========================================
;; Zonked output: no ?meta in results
;; ========================================

(test-case "implicit/no-unsolved-metas-in-output"
  ;; The output should never contain ?meta
  (let ([output (run-ns "(ns imp11)\n(imports [prologos::core :refer [id]])\n(eval (id zero))\n(infer (id zero))")])
    (for ([line output])
      (check-false (string-contains? line "?meta")
                   (format "Unexpected meta in output: ~a" line)))))

;; ========================================
;; Local definition with implicit params
;; ========================================

(test-case "implicit/local-def-with-implicits"
  ;; Define a polymorphic function locally and use with inference
  (check-equal?
   (run-last "(ns imp12)\n(def myid <(Pi [A :0 <(Type 0)>] (-> A A))>\n  (fn [A :0 <(Type 0)>] (fn [x <A>] x)))\n(eval (myid (suc (suc zero))))")
   "2N : Nat"))
