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
  (check-equal? (ws-val "[from-integer Float64 3]") "3.0f : Float64")
  (check-equal? (ws-val "[from-integer Float32 5]") "5f32 : Float32")
  (check-equal? (ws-val "[from-rational Float64 [from-int 7]]") "7.0f : Float64")
  (check-equal? (ws-val "[from-rational Float32 [from-int 2]]") "2f32 : Float32")
  ;; composes with Float arithmetic (result is Float64 + Float64)
  (check-equal? (ws-val "[+ 1.0f64 [from-integer Float64 2]]") "3.0f : Float64"))

;; ========================================
;; N3e-rest — L1: reverse Float -> {Rat, Int, Bool, Float32} conversion arms
;; ========================================

(test-case "float-to-rat (nf) — finite, both widths"
  (check-equal? (nf (expr-float-to-rat (expr-float64 0.5)))  (expr-rat 1/2))
  (check-equal? (nf (expr-float-to-rat (expr-float32 0.25))) (expr-rat 1/4)))

(test-case "float-finite? (nf) — NaN/±Inf → false, finite → true"
  (check-equal? (nf (expr-float-finite (expr-float64 +nan.0))) (expr-false))
  (check-equal? (nf (expr-float-finite (expr-float64 +inf.0))) (expr-false))
  (check-equal? (nf (expr-float-finite (expr-float64 -inf.0))) (expr-false))
  (check-equal? (nf (expr-float-finite (expr-float64 3.0)))    (expr-true))
  (check-equal? (nf (expr-float-finite (expr-float32 3.0)))    (expr-true)))

(test-case "float-to-rat (nf) — NaN/±Inf must NOT crash (gets stuck)"
  ;; The #:when (rational? v) guard prevents the P0-class inexact->exact crash.
  ;; NaN/±Inf: value arm does not fire → stuck-reduce → unreduced term (no exn).
  (check-not-exn (lambda () (nf (expr-float-to-rat (expr-float64 +inf.0)))))
  (check-not-exn (lambda () (nf (expr-float-to-rat (expr-float64 -inf.0)))))
  (check-not-exn (lambda () (nf (expr-float-to-rat (expr-float64 +nan.0)))))
  ;; stuck term is returned unreduced
  (check-equal? (nf (expr-float-to-rat (expr-float64 +inf.0)))
                (expr-float-to-rat (expr-float64 +inf.0)))
  ;; float-to-int likewise does not crash on NaN/±Inf
  (check-not-exn (lambda () (nf (expr-float-to-int (expr-float64 +inf.0)))))
  (check-not-exn (lambda () (nf (expr-float-to-int (expr-float64 +nan.0))))))

(test-case "float-to-int (nf) — truncate toward zero, both widths"
  (check-equal? (nf (expr-float-to-int (expr-float64 3.7)))  (expr-int 3))
  (check-equal? (nf (expr-float-to-int (expr-float64 -2.9))) (expr-int -2))
  (check-equal? (nf (expr-float-to-int (expr-float32 3.7)))  (expr-int 3)))

(test-case "float-to-float32 (nf) — narrowing + identity"
  (check-equal? (nf (expr-float-to-float32 (expr-float64 1.5))) (expr-float32 1.5))
  ;; identity on Float32 input
  (check-equal? (nf (expr-float-to-float32 (expr-float32 2.5))) (expr-float32 2.5)))

;; ========================================
;; N3e-rest — L2: WS surface for the reverse conversions
;; ========================================

(test-case "reverse Float conversions at WS level"
  (check-equal? (ws-val "[float-to-rat 0.5f64]")     "1/2 : Rat")
  (check-equal? (ws-val "[float-to-rat 0.25f32]")    "1/4 : Rat")
  (check-equal? (ws-val "[float-finite? 3.0f64]")    "true : Bool")
  (check-equal? (ws-val "[float-finite? [f64/ 1.0f64 0.0f64]]") "false : Bool")
  (check-equal? (ws-val "[float-to-int 3.7f64]")     "3 : Int")
  (check-equal? (ws-val "[float-to-int -2.9f64]")    "-2 : Int")
  (check-equal? (ws-val "[float-to-float32 2.5f64]") "2.5f32 : Float32"))
