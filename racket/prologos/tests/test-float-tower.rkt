#lang racket/base

;;;
;;; Tests for Float numeric-tower integration — Numerics N3d.
;;; Float is a 3rd rank family in numeric-join + the Float32<:Float64 subtype
;;; edge, so generic `+ - * / negate abs` + comparisons work over floats.
;;; Owner-locked rules: exact+Float PRESERVES the Float operand width
;;; (Int+Float32→Float32, NOT a clamp); Float32+Float64→Float64 (widen);
;;; Posit↔Float = NO join → type error (explicit conversion only).
;;;
;;; NOTE: exact→Float coercion emits a "loss of exactness" warning (Float is
;;; 'approximate, like Posit) which the on-network path appends to output AND
;;; leaks across run-ns-ws-last calls (shared buffer — fixture artifact). `ws-val`
;;; strips the trailing warning so we assert on the value+type only.
;;;

(require rackunit
         racket/string
         "test-support.rkt"
         "../syntax.rkt"
         (prefix-in tc: "../typing-core.rkt")
         (prefix-in sub: "../subtype-predicate.rkt")
         "../driver.rkt")

;; value+type, dropping any trailing coercion-warning lines
(define (ws-val s)
  (car (string-split (run-ns-ws-last s) "\nwarning:")))

;; ========================================
;; Generic arithmetic over same-type floats (WS L3)
;; ========================================

(test-case "generic arith over same-type floats"
  (check-equal? (ws-val "[+ 3.0f64 2.0f64]") "[float64 5.0] : Float64")
  (check-equal? (ws-val "[- 5.0f64 1.5f64]") "[float64 3.5] : Float64")
  (check-equal? (ws-val "[* 2.0f32 4.0f32]") "[float32 8.0] : Float32")
  (check-equal? (ws-val "[/ 9.0f64 3.0f64]") "[float64 3.0] : Float64")
  (check-equal? (ws-val "[negate 2.5f64]")   "[float64 -2.5] : Float64")
  (check-equal? (ws-val "[abs -2.5f64]")     "[float64 2.5] : Float64"))

;; ========================================
;; numeric-join: exact+Float preserves width; both-float widens
;; ========================================

(test-case "both-float widens (Float32 + Float64 → Float64)"
  ;; both approximate → no coercion warning
  (check-equal? (ws-val "[+ 2.0f32 3.0f64]") "[float64 5.0] : Float64"))

;; NOTE: the exact+Float width rules (Int+Float32→Float32 PRESERVE, Int+Float64→Float64)
;; are asserted at the numeric-join UNIT level below — NOT via run-ns-ws-last — because
;; exact→Float emits a "loss of exactness" coercion warning that the warning CELL
;; accumulates and LEAKS across run-ns-ws-last calls / test files (pre-existing
;; warnings-cell-not-reset-per-command issue, surfaced by N3d; filed in dailies).

;; ========================================
;; Generic comparisons over floats (word keywords; `<` is type-grouping in WS)
;; ========================================

(test-case "generic comparisons over floats"
  (check-true (string-contains? (ws-val "[lt 1.0f64 2.0f64]") "true"))
  (check-true (string-contains? (ws-val "[le 1.0f64 1.0f64]") "true"))
  (check-true (string-contains? (ws-val "[eq 1.0f64 1.0f64]") "true"))
  (check-true (string-contains? (ws-val "[lt 2.0f32 1.0f32]") "false")))

;; ========================================
;; numeric-join unit: Float rank family + Posit↔Float = #f
;; ========================================

(test-case "numeric-join Float rules (unit)"
  (check-equal? (tc:numeric-join (expr-Int) (expr-Float32)) (expr-Float32) "Int+Float32 preserve width")
  (check-equal? (tc:numeric-join (expr-Int) (expr-Float64)) (expr-Float64))
  (check-equal? (tc:numeric-join (expr-Float32) (expr-Float64)) (expr-Float64) "widen to Float64")
  (check-equal? (tc:numeric-join (expr-Float32) (expr-Float32)) (expr-Float32))
  ;; Posit↔Float = NO join (explicit conversion only)
  (check-false (tc:numeric-join (expr-Posit32) (expr-Float64)) "Posit+Float has no join")
  (check-false (tc:numeric-join (expr-Float64) (expr-Posit32))))

;; ========================================
;; Subtype edge: Float32 <: Float64 (and NOT Posit↔Float)
;; ========================================

(test-case "Float32 <: Float64 subtype edge"
  (check-true  (sub:subtype? (expr-Float32) (expr-Float64)) "Float32 <: Float64")
  (check-false (sub:subtype? (expr-Float64) (expr-Float32)) "not Float64 <: Float32")
  (check-false (sub:subtype? (expr-Posit32) (expr-Float64)) "no Posit <: Float")
  (check-false (sub:subtype? (expr-Float32) (expr-Posit64)) "no Float <: Posit"))

;; ========================================
;; Regression: exact/posit arithmetic unchanged
;; (Posit↔Float = no join is covered by the numeric-join unit check-false above.)
;; ========================================

(test-case "regression: exact/posit arithmetic unchanged"
  (check-equal? (ws-val "3.14") "[posit32 1284463657] : Posit32")
  (check-true (string-contains? (ws-val "[lt 1 2]") "true") "generic lt over Int still works")
  (check-equal? (ws-val "[+ 2 3]") "5 : Int" "generic + over Int still works"))
