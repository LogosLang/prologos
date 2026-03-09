#lang racket/base

;;;
;;; Tests for Int Literal Patterns
;;;
;;; Verifies:
;;; - Bare integer literals (0, 1, -1, 42) compile to equality dispatch
;;; - Int patterns in match expressions
;;; - Int patterns in defn pattern clauses
;;; - Mixed Int literal + variable/wildcard arms
;;; - Negative Int literals
;;; - Nat patterns (0N, 1N) still work (regression)
;;; - WS-mode integration
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

;; ========================================
;; A. Int literal patterns in match
;; ========================================

(test-case "int-pat/match-zero"
  ;; Bare 0 in match arm → Int equality dispatch
  (check-equal?
   (run-ns-ws-last
    "(ns t1)\ndef n : Int := 0\neval\n  match n\n    | 0 -> true\n    | _ -> false")
   "true : Bool"))

(test-case "int-pat/match-nonzero"
  ;; Non-matching Int literal
  (check-equal?
   (run-ns-ws-last
    "(ns t2)\ndef n : Int := 5\neval\n  match n\n    | 0 -> true\n    | _ -> false")
   "false : Bool"))

(test-case "int-pat/match-multi-lit"
  ;; Multiple Int literals in match
  (check-equal?
   (run-ns-ws-last
    "(ns t3)\ndef n : Int := 1\neval\n  match n\n    | 0 -> 10\n    | 1 -> 20\n    | _ -> 30")
   "20 : Int"))

(test-case "int-pat/match-negative"
  ;; Negative Int literal
  (check-equal?
   (run-ns-ws-last
    "(ns t4)\ndef n : Int := -1\neval\n  match n\n    | -1 -> true\n    | _ -> false")
   "true : Bool"))

(test-case "int-pat/match-variable-default"
  ;; Variable in default arm binds the scrutinee (wrapped in defn for type context)
  (check-equal?
   (run-ns-ws-last
    "(ns t5)\ndefn id-int [n : Int] : Int\n  match n\n    | 0 -> 0\n    | x -> x\neval [id-int 42]")
   "42 : Int"))

;; ========================================
;; B. Int literal patterns in defn
;; ========================================

(test-case "int-pat/defn-fib"
  ;; Fibonacci with Int literal patterns (inline type annotation auto-registers spec)
  (check-equal?
   (run-ns-ws-last
    "(ns t6)\ndefn fib [n : Int] : Int\n  | 0 -> 0\n  | 1 -> 1\n  | n -> [int+ [fib [int- n 1]] [fib [int- n 2]]]\neval [fib 10]")
   "55 : Int"))

(test-case "int-pat/defn-factorial"
  ;; Factorial with Int literal base case
  (check-equal?
   (run-ns-ws-last
    "(ns t7)\ndefn fact [n : Int] : Int\n  | 0 -> 1\n  | n -> [int* n [fact [int- n 1]]]\neval [fact 5]")
   "120 : Int"))

;; ========================================
;; C. Nat patterns still work (regression)
;; ========================================

(test-case "int-pat/nat-regression-zero"
  ;; 0N still matches as Nat constructor (zero)
  (check-equal?
   (run-ns-ws-last
    "(ns t8)\ndefn iz [n : Nat] : Bool\n  match n\n    | 0N -> true\n    | _ -> false\neval [iz zero]")
   "true : Bool"))

(test-case "int-pat/nat-regression-suc"
  ;; Nat constructor patterns still work
  (check-equal?
   (run-ns-ws-last
    "(ns t9)\ndefn iz2 [n : Nat] : Bool\n  match n\n    | zero -> true\n    | suc _ -> false\neval [iz2 1N]")
   "false : Bool"))

(displayln "All int-pattern tests passed!")
