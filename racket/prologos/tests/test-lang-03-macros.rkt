#lang racket/base

;;;
;;; PROLOGOS #lang TESTS — Macros, defn, let, spec
;;; Tests for defn, macros, let-arrow, and spec forms in both modes.
;;;

(require rackunit
         racket/port
         racket/runtime-path
         racket/string)

(define-runtime-path examples-dir "examples")

;; Helper: run a #lang prologos file and capture stdout.
(define (run-prologos-file filename)
  (define path (build-path examples-dir filename))
  (define ns (make-base-empty-namespace))
  (define out-port (open-output-string))
  (parameterize ([current-output-port out-port]
                 [current-namespace ns])
    (namespace-require path))
  (get-output-string out-port))

;; ========================================
;; defn and implicit eval tests
;; ========================================

(test-case "defn.rkt: sexp defn macro"
  (define output (run-prologos-file "defn.rkt"))
  (check-true (string-contains? output "increment") "should define increment")
  (check-true (string-contains? output "1N : Nat") "increment zero = 1")
  (check-true (string-contains? output "2N : Nat") "increment (suc zero) = 2")
  (check-true (string-contains? output "id") "should define id")
  (check-true (string-contains? output "0N : Nat") "id Nat zero")
  (check-true (string-contains? output "true : Bool") "id Bool true"))

(test-case "defn-ws.rkt: whitespace defn macro"
  (define output (run-prologos-file "defn-ws.rkt"))
  (check-true (string-contains? output "increment") "should define increment")
  (check-true (string-contains? output "1N : Nat") "increment zero = 1")
  (check-true (string-contains? output "2N : Nat") "increment (suc zero) = 2")
  (check-true (string-contains? output "id") "should define id")
  (check-true (string-contains? output "0N : Nat") "id Nat zero")
  (check-true (string-contains? output "true : Bool") "id Bool true"))

;; ========================================
;; Macro tests (defmacro, let, if, deftype)
;; ========================================

(test-case "macros.rkt: defmacro, deftype, let, if"
  (define output (run-prologos-file "macros.rkt"))
  (check-true (string-contains? output "double : Nat -> Nat defined.")
              "should define double")
  (check-true (string-contains? output "4N : Nat")
              "double 2 = 4")
  (check-true (string-contains? output "false : Bool")
              "not true = false")
  (check-true (string-contains? output "true : Bool")
              "not false = true")
  (check-true (string-contains? output "3N : Nat")
              "let result = 3")
  (check-true (string-contains? output "1N : Nat")
              "if true = 1")
  (check-true (string-contains? output "0N : Nat")
              "if false = zero")
  (check-true (string-contains? output "OK")
              "Pair type alias check"))

(test-case "macros-ws.rkt: if, boolrec, let in whitespace mode"
  (define output (run-prologos-file "macros-ws.rkt"))
  (check-true (string-contains? output "double : Nat -> Nat defined.")
              "should define double")
  (check-true (string-contains? output "4N : Nat")
              "double 2 = 4")
  (check-true (string-contains? output "1N : Nat")
              "if true = 1")
  (check-true (string-contains? output "0N : Nat")
              "if false / boolrec true = zero")
  (check-true (string-contains? output "3N : Nat")
              "let result = 3"))

;; ========================================
;; Let :=, sibling lets, uncurried arrows (WS mode)
;; ========================================

(test-case "let-arrow-ws.rkt: let :=, sibling lets, uncurried arrows"
  (define output (run-prologos-file "let-arrow-ws.rkt"))
  (check-true (string-contains? output "one : Nat defined.")
              "should define one")
  (check-true (string-contains? output "1N : Nat")
              "one = 1")
  (check-true (string-contains? output "three : Nat defined.")
              "should define three")
  (check-true (string-contains? output "3N : Nat")
              "three = 3 via sibling lets")
  (check-true (string-contains? output "add : Nat Nat -> Nat defined.")
              "add should have uncurried arrow type")
  (check-true (string-contains? output "apply-fn")
              "should define apply-fn")
  (check-true (string-contains? output "inc2")
              "should define inc2"))

(test-case "spec-ws.rkt: spec form with WS mode"
  (define output (run-prologos-file "spec-ws.rkt"))
  (check-true (string-contains? output "add : Nat Nat -> Nat defined.")
              "spec'd add should have uncurried arrow type")
  (check-true (string-contains? output "3N : Nat")
              "add 1 2 = 3")
  (check-true (string-contains? output "inc2 : Nat -> Nat defined.")
              "spec'd inc2 should have Nat -> Nat type")
  (check-true (string-contains? output "apply-fn : [Nat -> Nat] Nat -> Nat defined.")
              "spec'd apply-fn should wrap HOF domain in brackets")
  (check-true (string-contains? output "2N : Nat")
              "apply-fn inc2 zero = 2"))
