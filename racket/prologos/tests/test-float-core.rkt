#lang racket/base

;;;
;;; Tests for Float (IEEE-754) CORE AST — Numerics N3a.
;;; Scope: the Float32/Float64 TYPE + VALUE only. Arithmetic ops, `f` literals,
;;; numeric-join, conversions, and FFI are later N3 sub-phases. The value `val`
;;; is a Racket flonum (incl. +nan.0/+inf.0/-inf.0); no range check.
;;;

(require racket/string
         rackunit
         "test-support.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../substitution.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../pretty-print.rkt"
         "../driver.rkt"
         "../global-env.rkt")

;; ========================================
;; Type formation: Float32/Float64 : Type 0
;; ========================================

(test-case "Float type formation"
  (check-equal? (tc:infer ctx-empty (expr-Float32)) (expr-Type (lzero)) "Float32 : Type 0")
  (check-equal? (tc:infer ctx-empty (expr-Float64)) (expr-Type (lzero)) "Float64 : Type 0")
  (check-equal? (tc:infer-level ctx-empty (expr-Float32)) (tc:just-level (lzero)) "Float32 at level 0")
  (check-true (tc:is-type ctx-empty (expr-Float32)) "Float32 is a type")
  (check-true (tc:is-type ctx-empty (expr-Float64)) "Float64 is a type"))

;; ========================================
;; Value typing (val = Racket flonum)
;; ========================================

(test-case "float value typing"
  (check-equal? (tc:infer ctx-empty (expr-float32 3.14)) (expr-Float32) "float32(3.14) : Float32")
  (check-equal? (tc:infer ctx-empty (expr-float64 3.14)) (expr-Float64) "float64(3.14) : Float64")
  (check-true (tc:check ctx-empty (expr-float32 1.0) (expr-Float32)) "check float32(1.0) : Float32")
  ;; IEEE special values are valid flonums
  (check-equal? (tc:infer ctx-empty (expr-float64 +inf.0)) (expr-Float64) "+inf.0 : Float64")
  (check-equal? (tc:infer ctx-empty (expr-float64 -inf.0)) (expr-Float64) "-inf.0 : Float64")
  (check-equal? (tc:infer ctx-empty (expr-float64 +nan.0)) (expr-Float64) "+nan.0 : Float64")
  ;; A non-flonum (exact) value is ill-typed
  (check-equal? (tc:infer ctx-empty (expr-float32 3)) (expr-error) "exact int is not a Float32 value"))

;; ========================================
;; Pretty-print
;; ========================================

(test-case "float pretty-print"
  (check-equal? (pp-expr (expr-Float32) '()) "Float32")
  (check-equal? (pp-expr (expr-Float64) '()) "Float64")
  (check-equal? (pp-expr (expr-float32 3.14) '()) "3.14f32")
  (check-equal? (pp-expr (expr-float64 3.14) '()) "3.14f"))

;; ========================================
;; Substitution — leaf (identity, no binders)
;; ========================================

(test-case "float substitution identity"
  (check-equal? (shift 1 0 (expr-Float32)) (expr-Float32))
  (check-equal? (shift 1 0 (expr-float64 3.14)) (expr-float64 3.14)))

;; ========================================
;; End-to-end (WS L3): the Float type symbols parse + type-check
;; ========================================

(test-case "Float types at WS L3"
  (check-equal? (run-ns-ws-last "Float32") "Float32 : [Type 0]")
  (check-equal? (run-ns-ws-last "Float64") "Float64 : [Type 0]"))
