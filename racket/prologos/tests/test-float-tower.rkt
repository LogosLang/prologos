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
;;; 'approximate, like Posit). `ws-val` strips the trailing warning so value+type
;;; assertions are clean; `ws-full` keeps it for the warning-emitted / no-leak
;;; assertions. The warning-cell leak (accumulation across run-ns-ws-last calls)
;;; is FIXED via reset-warning-cells! (per-command, warnings.rkt/driver.rkt).
;;;

(require rackunit
         racket/string
         "test-support.rkt"
         "../syntax.rkt"
         "../reduction.rkt"
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
  (check-equal? (ws-val "[+ 3.0f64 2.0f64]") "5.0f : Float64")
  (check-equal? (ws-val "[- 5.0f64 1.5f64]") "3.5f : Float64")
  (check-equal? (ws-val "[* 2.0f32 4.0f32]") "8f32 : Float32")
  (check-equal? (ws-val "[/ 9.0f64 3.0f64]") "3.0f : Float64")
  (check-equal? (ws-val "[negate 2.5f64]")   "-2.5f : Float64")
  (check-equal? (ws-val "[abs -2.5f64]")     "2.5f : Float64"))

;; ========================================
;; numeric-join: exact+Float preserves width; both-float widens
;; ========================================

(test-case "both-float widens (Float32 + Float64 → Float64)"
  ;; both approximate → no coercion warning
  (check-equal? (ws-val "[+ 2.0f32 3.0f64]") "5.0f : Float64"))

;; The exact+Float width rules are now assertable at WS level (L2): the warning-cell
;; LEAK is FIXED (reset-warning-cells! runs per-command in process-command), so
;; warnings no longer accumulate across run-ns-ws-last calls / test files.

;; full output INCLUDING the trailing coercion-warning line(s)
(define (ws-full s) (run-ns-ws-last s))

(test-case "exact+Float width rules at WS level (leak fixed)"
  ;; Int+Float32 PRESERVES Float32 width (not a clamp); value+type via ws-val
  (check-equal? (ws-val "[+ 1 2.0f32]") "3f32 : Float32" "Int+Float32 preserves width")
  (check-equal? (ws-val "[+ 1 2.0f64]") "3.0f : Float64" "Int+Float64 widens to Float64")
  ;; exact→Float emits a loss-of-exactness warning (symmetry with exact→Posit)
  (check-true (string-contains? (ws-full "[+ 1 2.0f32]") "loss of exactness")
              "Int+Float32 warns (exact→approximate)")
  ;; isolation: a pure-Float op after an exact+Float op must NOT carry a leaked warning
  (check-false (string-contains? (ws-full "[+ 1.0f32 2.0f32]") "loss of exactness")
               "Float+Float emits no warning; no leak from the prior command"))

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
  (check-equal? (ws-val "3.14") "3.14 : Rat")  ;; N4: bare decimal → polymorphic Rat
  (check-true (string-contains? (ws-val "[lt 1 2]") "true") "generic lt over Int still works")
  (check-equal? (ws-val "[+ 2 3]") "5 : Int" "generic + over Int still works"))

;; ========================================
;; Regression (P0 fix): NaN/±Inf survive cross-family/cross-width generic
;; arithmetic. Before the fix, the different-tag coercion branch round-tripped
;; each operand through inexact->exact, which CRASHES on +inf.0/+nan.0 (no
;; exact rational representation). Same-width direct ops were always safe
;; (native float-impl), which is why test-float-ops' NaN/Inf coverage missed it.
;; ========================================

(test-case "NaN/Inf in cross-family generic arithmetic — no crash, correct result"
  ;; Int + Float64(+inf.0) → Float64(+inf.0)  (minimal repro)
  (check-equal? (nf (expr-generic-add (expr-int 3) (expr-float64 +inf.0)))
                (expr-float64 +inf.0))
  ;; Int + (1.0f64 / 0.0f64) → +inf.0  (well-typed surface-level repro)
  (check-equal? (nf (expr-generic-add (expr-int 3)
                                      (expr-f64-div (expr-float64 1.0) (expr-float64 0.0))))
                (expr-float64 +inf.0))
  ;; Int * Float64(-inf.0) → -inf.0
  (check-equal? (nf (expr-generic-mul (expr-int 2) (expr-float64 -inf.0)))
                (expr-float64 -inf.0))
  ;; cross-width: Float32 + Float64(NaN) → Float64(NaN); NaN≠NaN ⇒ self-inequality
  (let ([r (nf (expr-generic-add (expr-float32 2.0) (expr-float64 +nan.0)))])
    (check-true (expr-float64? r) "join widens to Float64")
    (let ([v (expr-float64-val r)]) (check-false (= v v) "NaN preserved through coercion"))))
