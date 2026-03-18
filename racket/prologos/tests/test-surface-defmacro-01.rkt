#lang racket/base

;;;
;;; Tests for surface-level defmacro: WS-mode macros, cross-module import,
;;; pattern language features, private macros, error cases.
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
  (parameterize ([current-prelude-env (hasheq)]
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
;; 2a. Core macro smoke tests
;; ========================================

(test-case "core-macro/twice-suc"
  ;; twice suc zero → suc(suc(zero)) = 2
  (check-equal?
   (run-last "(ns dm1)\n(eval (the Nat (twice suc zero)))")
   "2N : Nat"))


(test-case "core-macro/pipe2"
  ;; pipe2 zero suc suc → suc(suc(zero)) = 2
  (check-equal?
   (run-last "(ns dm2)\n(eval (the Nat (pipe2 zero suc suc)))")
   "2N : Nat"))


(test-case "core-macro/pipe3"
  ;; pipe3 zero suc suc suc → suc(suc(suc(zero))) = 3
  (check-equal?
   (run-last "(ns dm3)\n(eval (the Nat (pipe3 zero suc suc suc)))")
   "3N : Nat"))


(test-case "core-macro/when-true"
  ;; when true unit → if true unit unit → unit
  (check-equal?
   (run-last "(ns dm4)\n(eval (the Unit (when true unit)))")
   "unit : Unit"))


(test-case "core-macro/unless-false"
  ;; unless false unit → if false unit unit → unit
  (check-equal?
   (run-last "(ns dm5)\n(eval (the Unit (unless false unit)))")
   "unit : Unit"))


;; ========================================
;; 2b. Inline defmacro in WS mode
;; ========================================

(test-case "inline-macro/inc2"
  ;; defmacro inc2 — increment twice
  (check-equal?
   (run-last "(ns dm6)\n(defmacro inc2 ($x) (suc (suc $x)))\n(eval (the Nat (inc2 zero)))")
   "2N : Nat"))


(test-case "inline-macro/constant"
  ;; defmacro with no pattern vars — constant replacement
  (check-equal?
   (run-last "(ns dm7)\n(defmacro my-zero () zero)\n(eval (the Nat (my-zero)))")
   "0N : Nat"))


(test-case "inline-macro/chain"
  ;; macro calling macro: inc2 then inc4
  (check-equal?
   (run-last (string-append "(ns dm8)\n"
                            "(defmacro inc2 ($x) (suc (suc $x)))\n"
                            "(defmacro inc4 ($x) (inc2 (inc2 $x)))\n"
                            "(eval (the Nat (inc4 zero)))"))
   "4N : Nat"))


(test-case "inline-macro/multi-arg"
  ;; defmacro with multiple arguments
  (check-equal?
   (run-last (string-append "(ns dm9)\n"
                            "(imports (prologos::data::nat :refer (add)))\n"
                            "(defmacro add3 ($a $b $c) (add $a (add $b $c)))\n"
                            "(eval (add3 (the Nat (suc zero)) (the Nat (suc zero)) (the Nat (suc zero))))"))
   "3N : Nat"))


(test-case "inline-macro/apply2"
  ;; macro that applies a function to two arguments
  (check-equal?
   (run-last (string-append "(ns dm10)\n"
                            "(imports (prologos::data::nat :refer (add)))\n"
                            "(defmacro apply2 ($f $x $y) ($f $x $y))\n"
                            "(eval (apply2 add (the Nat (suc zero)) (the Nat (suc zero))))"))
   "2N : Nat"))


(test-case "inline-macro/nested-body"
  ;; macro with nested expression in body
  (check-equal?
   (run-last (string-append "(ns dm11)\n"
                            "(defmacro suc3 ($x) (suc (suc (suc $x))))\n"
                            "(eval (the Nat (suc3 zero)))"))
   "3N : Nat"))


;; ========================================
;; 2c. Cross-module macro import
;; ========================================

(test-case "cross-module/twice-auto-import"
  ;; core macros are auto-imported via prologos::core
  ;; twice should be available without explicit require
  (check-equal?
   (run-last "(ns dm12)\n(eval (the Nat (twice suc zero)))")
   "2N : Nat"))


(test-case "cross-module/pipe2-auto-import"
  ;; pipe2 should be available via auto-imported core
  (check-equal?
   (run-last "(ns dm13)\n(eval (the Nat (pipe2 zero suc suc)))")
   "2N : Nat"))


(test-case "cross-module/when-auto-import"
  ;; when should be available via auto-imported core
  (check-equal?
   (run-last "(ns dm14)\n(eval (the Unit (when true unit)))")
   "unit : Unit"))
