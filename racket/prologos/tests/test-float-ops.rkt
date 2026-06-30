#lang racket/base

;;;
;;; Tests for Float (IEEE-754) ARITHMETIC + COMPARISON ops — Numerics N3b.
;;; Scope: the 10 ops (add/sub/mul/div + neg/abs/sqrt + lt/le/eq) for Float32
;;; and Float64. Compute delegates to native Racket flonums (float-impl.rkt);
;;; Float32 results are rounded to single precision via flsingle.
;;; Conversions, `f` literals, and numeric-join are later N3 sub-phases — so
;;; Float values here are built directly (no surface literal yet, mirroring
;;; test-float-core), and the WS L3 checks use Float-ascribed lambda params.
;;;

(require rackunit
         racket/string
         racket/math
         "test-support.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../pretty-print.rkt"
         "../driver.rkt"
         "../global-env.rkt")

;; ========================================
;; Float64 arithmetic compute (nf on literals)
;; ========================================

(test-case "Float64 arithmetic"
  (check-equal? (nf (expr-f64-add (expr-float64 1.5) (expr-float64 2.5))) (expr-float64 4.0))
  (check-equal? (nf (expr-f64-sub (expr-float64 5.0) (expr-float64 1.5))) (expr-float64 3.5))
  (check-equal? (nf (expr-f64-mul (expr-float64 2.0) (expr-float64 3.0))) (expr-float64 6.0))
  (check-equal? (nf (expr-f64-div (expr-float64 9.0) (expr-float64 3.0))) (expr-float64 3.0))
  (check-equal? (nf (expr-f64-neg (expr-float64 1.5))) (expr-float64 -1.5))
  (check-equal? (nf (expr-f64-abs (expr-float64 -2.5))) (expr-float64 2.5))
  (check-equal? (nf (expr-f64-sqrt (expr-float64 9.0))) (expr-float64 3.0)))

;; ========================================
;; Float32 arithmetic + single-precision rounding
;; ========================================

(test-case "Float32 arithmetic + flsingle rounding"
  ;; exact-representable cases unaffected by rounding
  (check-equal? (nf (expr-f32-add (expr-float32 1.0) (expr-float32 2.0))) (expr-float32 3.0))
  (check-equal? (nf (expr-f32-mul (expr-float32 2.0) (expr-float32 4.0))) (expr-float32 8.0))
  (check-equal? (nf (expr-f32-sqrt (expr-float32 16.0))) (expr-float32 4.0))
  ;; 0.1 + 0.2 rounds to the nearest single-precision value (≠ the Float64 result)
  (check-equal? (nf (expr-f32-add (expr-float32 0.1) (expr-float32 0.2)))
                (expr-float32 0.30000001192092896)
                "f32 result is single-precision rounded"))

;; ========================================
;; IEEE-754 special values
;; ========================================

(test-case "IEEE specials"
  (check-equal? (nf (expr-f64-div (expr-float64 1.0) (expr-float64 0.0))) (expr-float64 +inf.0))
  (check-equal? (nf (expr-f64-div (expr-float64 -1.0) (expr-float64 0.0))) (expr-float64 -inf.0))
  (check-true (nan? (expr-float64-val (nf (expr-f64-div (expr-float64 0.0) (expr-float64 0.0)))))
              "0.0/0.0 = NaN")
  (check-true (nan? (expr-float64-val (nf (expr-f64-sqrt (expr-float64 -1.0)))))
              "sqrt(neg) = NaN"))

;; ========================================
;; Comparisons → Bool (incl. IEEE NaN/-0.0 semantics)
;; ========================================

(test-case "Float comparisons"
  (check-equal? (nf (expr-f64-lt (expr-float64 1.0) (expr-float64 2.0))) (expr-true))
  (check-equal? (nf (expr-f64-lt (expr-float64 2.0) (expr-float64 1.0))) (expr-false))
  (check-equal? (nf (expr-f64-le (expr-float64 1.0) (expr-float64 1.0))) (expr-true))
  (check-equal? (nf (expr-f64-eq (expr-float64 1.0) (expr-float64 1.0))) (expr-true))
  ;; IEEE: NaN ≠ NaN
  (check-equal? (nf (expr-f64-eq (expr-float64 +nan.0) (expr-float64 +nan.0))) (expr-false)
                "NaN = NaN is false")
  ;; IEEE: -0.0 == +0.0
  (check-equal? (nf (expr-f64-eq (expr-float64 -0.0) (expr-float64 0.0))) (expr-true)
                "-0.0 = +0.0 is true")
  (check-equal? (nf (expr-f32-lt (expr-float32 1.0) (expr-float32 2.0))) (expr-true)))

;; ========================================
;; Stuck reduction (non-literal operand) — identity recursion holds
;; ========================================

(test-case "Float op stuck reduction"
  ;; an unbound var operand: the op stays as itself (no crash), operand nf'd
  (check-equal? (nf (expr-f64-add (expr-float64 1.0) (expr-float64 2.0))) (expr-float64 3.0))
  ;; substitution recurses into operands
  (check-equal? (shift 1 0 (expr-f64-add (expr-float64 1.0) (expr-float64 2.0)))
                (expr-f64-add (expr-float64 1.0) (expr-float64 2.0))))

;; ========================================
;; Typing: arith FloatN -> FloatN -> FloatN ; compare -> Bool
;; ========================================

(test-case "Float op typing"
  (check-equal? (tc:infer ctx-empty (expr-f64-add (expr-float64 1.0) (expr-float64 2.0))) (expr-Float64))
  (check-equal? (tc:infer ctx-empty (expr-f32-add (expr-float32 1.0) (expr-float32 2.0))) (expr-Float32))
  (check-equal? (tc:infer ctx-empty (expr-f64-neg (expr-float64 1.0))) (expr-Float64))
  (check-equal? (tc:infer ctx-empty (expr-f64-sqrt (expr-float64 4.0))) (expr-Float64))
  (check-equal? (tc:infer ctx-empty (expr-f64-lt (expr-float64 1.0) (expr-float64 2.0))) (expr-Bool))
  (check-equal? (tc:infer ctx-empty (expr-f32-eq (expr-float32 1.0) (expr-float32 2.0))) (expr-Bool))
  ;; N3d: Float32<:Float64 — a Float32 operand WIDENS to Float64 (type-checks + reduces)
  (check-equal? (tc:infer ctx-empty (expr-f64-add (expr-float32 1.0) (expr-float64 2.0))) (expr-Float64)
                "f64-add widens a Float32 operand (Float32<:Float64)")
  (check-equal? (nf (expr-f64-add (expr-float32 1.0) (expr-float64 2.0))) (expr-float64 3.0)
                "and reduces (Float32 coerced to Float64)")
  ;; posit operand to a float op is still ill-typed (Posit↮Float — no subtype, no join)
  (check-equal? (tc:infer ctx-empty (expr-f64-add (expr-posit32 0) (expr-float64 2.0))) (expr-error)
                "posit operand to a float op is ill-typed"))

;; ========================================
;; WS Level 3: surface ops parse, elaborate, type-check
;; (no float literal yet → use Float-ascribed lambda params)
;; ========================================

(test-case "Float ops at WS L3"
  (let ([r1 (run-ns-ws-last "[fn [x : Float64] [f64+ x x]]")])
    (check-true (string-contains? r1 "Float64") (format "f64+ over Float64 param type-checks: ~a" r1)))
  (let ([r2 (run-ns-ws-last "[fn [x : Float32] [f32-lt x x]]")])
    (check-true (string-contains? r2 "Bool") (format "f32-lt yields Bool: ~a" r2)))
  (let ([r3 (run-ns-ws-last "[fn [x : Float64] [f64-sqrt x]]")])
    (check-true (string-contains? r3 "Float64") (format "f64-sqrt over Float64: ~a" r3))))
