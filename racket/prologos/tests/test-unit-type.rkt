#lang racket/base

;;;
;;; Tests for Unit type: type formation, constructor, pattern matching
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
;; Unit type formation
;; ========================================

(test-case "unit-type/formation"
  ;; Unit : Type 0
  (check-equal?
   (run-last "(ns ut1)\n(eval (the (Type 0) Unit))")
   "Unit : [Type 0]"))

(test-case "unit-type/constructor"
  ;; unit : Unit
  (check-equal?
   (run-last "(ns ut2)\n(eval (the Unit unit))")
   "unit : Unit"))

;; ========================================
;; Pattern matching on Unit
;; ========================================

(test-case "match-unit/to-zero"
  ;; match unit | unit -> zero  →  zero : Nat
  (check-equal?
   (run-last "(ns ut3)\n(eval (the Nat (match unit (unit -> zero))))")
   "0N : Nat"))

(test-case "match-unit/to-true"
  ;; match unit | unit -> true  →  true : Bool
  (check-equal?
   (run-last "(ns ut4)\n(eval (the Bool (match unit (unit -> true))))")
   "true : Bool"))

;; ========================================
;; Unit in function types
;; ========================================

(test-case "unit-type/function-taking-unit"
  ;; defn discard [x : Unit] <Nat> zero
  (check-equal?
   (run-last "(ns ut5)\n(defn discard (x : Unit) <Nat> zero)\n(eval (discard unit))")
   "0N : Nat"))

(test-case "unit-type/function-returning-unit"
  ;; defn make-unit [x : Nat] <Unit> unit
  (check-equal?
   (run-last "(ns ut6)\n(defn make-unit (x : Nat) <Unit> unit)\n(eval (make-unit zero))")
   "unit : Unit"))

;; ========================================
;; Unit in data structures
;; ========================================

(test-case "unit-type/in-list"
  ;; List Unit containing one element
  (check-equal?
   (run-last "(ns ut7)\n(imports (prologos::data::list :refer (List nil cons)))\n(eval (the (List Unit) (cons unit nil)))")
   "'[unit] : [prologos::data::list::List Unit]"))

;; ========================================
;; Unit inference
;; ========================================

(test-case "unit-type/infer-unit"
  ;; unit infers to Unit
  (check-equal?
   (run-last "(ns ut8)\n(eval unit)")
   "unit : Unit"))

(test-case "unit-type/infer-Unit"
  ;; Unit infers to Type 0
  (check-equal?
   (run-last "(ns ut9)\n(eval Unit)")
   "Unit : [Type 0]"))
