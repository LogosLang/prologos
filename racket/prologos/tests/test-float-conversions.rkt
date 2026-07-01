#lang racket/base

;;;
;;; Tests for Float conversions — Numerics N3e-core (the DEMO-P1 unblock).
;;; Rat/Int -> Float via the generic `from-rational`/`from-integer` dispatch
;;; (Path B): typing-core `from-{rat,int}-target-type?` accept Float32/64 +
;;; reduction `generic-from-{rat,int}` Float arms. The JSON parser converts a
;;; parsed-decimal exact Rat -> JFloat via `from-rational Float64 r`.
;;;
;;; NaN/±Inf never arise here (a finite Rat/Int -> Float rounds or overflows to
;;; ±Inf, benign); the reverse Float->Rat (TryFrom->None on NaN/Inf) is N3e-rest.
;;;

(require rackunit
         racket/string
         "test-support.rkt"
         "../syntax.rkt"
         "../reduction.rkt"
         "../driver.rkt")

;; value+type, dropping any trailing warning line (explicit conversions don't warn,
;; but keep the helper uniform with the other float test files)
(define (ws-val s) (car (string-split (run-ns-ws-last s) "\nwarning:")))

;; ========================================
;; L1 — nf on the generic-from reduction arms (Path B)
;; ========================================

(test-case "Rat -> Float (nf)"
  (check-equal? (nf (expr-generic-from-rat (expr-Float64) (expr-rat 1/2)))    (expr-float64 0.5))
  (check-equal? (nf (expr-generic-from-rat (expr-Float32) (expr-rat 1/4)))    (expr-float32 0.25))
  (check-equal? (nf (expr-generic-from-rat (expr-Float64) (expr-rat 157/50))) (expr-float64 3.14))
  ;; big Rat overflows to +inf.0 — benign, no crash (unlike the reverse Float->Rat)
  (check-equal? (nf (expr-generic-from-rat (expr-Float64) (expr-rat (expt 10 400)))) (expr-float64 +inf.0)))

(test-case "Int -> Float (nf)"
  (check-equal? (nf (expr-generic-from-int (expr-Float64) (expr-int 3)))  (expr-float64 3.0))
  (check-equal? (nf (expr-generic-from-int (expr-Float32) (expr-int 7)))  (expr-float32 7.0))
  (check-equal? (nf (expr-generic-from-int (expr-Float64) (expr-int -2))) (expr-float64 -2.0)))

;; ========================================
;; L2 — WS surface: from-rational / from-integer (the DEMO-P1 path)
;; ========================================

(test-case "from-rational / from-integer Float at WS level"
  (check-equal? (ws-val "[from-integer Float64 3]") "[float64 3.0] : Float64")
  (check-equal? (ws-val "[from-integer Float32 5]") "[float32 5.0] : Float32")
  (check-equal? (ws-val "[from-rational Float64 [from-int 7]]") "[float64 7.0] : Float64")
  (check-equal? (ws-val "[from-rational Float32 [from-int 2]]") "[float32 2.0] : Float32")
  ;; composes with Float arithmetic (result is Float64 + Float64)
  (check-equal? (ws-val "[+ 1.0f64 [from-integer Float64 2]]") "[float64 3.0] : Float64"))
