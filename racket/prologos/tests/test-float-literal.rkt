#lang racket/base

;;;
;;; Tests for Float (IEEE-754) surface LITERALS — Numerics N3c.
;;; `3.14f` = Float64 (default), `3.14f32` = Float32, `3.14f64` = Float64;
;;; exponent composes (`1.5e-3f`); negative (`-2.5f`); integer (`3f`).
;;; f32 literals round to single precision at construction (flsingle).
;;; All exercised at WS Level 3 (run-ns-ws-last → "value : type"), which now
;;; also enables full end-to-end Float COMPUTE with literal operands.
;;; Bare `3.14` stays Posit32 (N3c is additive — N4 reconciles).
;;;

(require rackunit
         racket/string
         "test-support.rkt"
         "../driver.rkt")

;; ========================================
;; Literal forms → value + type (WS L3)
;; ========================================

(test-case "Float literal forms"
  (check-equal? (run-ns-ws-last "3.14f")   "3.14f : Float64"   "3.14f = Float64 default")
  (check-equal? (run-ns-ws-last "3.14f64") "3.14f : Float64"   "explicit f64")
  (check-equal? (run-ns-ws-last "3.14f32") "3.14f32 : Float32" "f32 single-rounded at construction")
  (check-equal? (run-ns-ws-last "3f")      "3.0f : Float64"    "integer + f")
  (check-equal? (run-ns-ws-last "0.0f")    "0.0f : Float64"    "zero literal")
  (check-equal? (run-ns-ws-last "-2.5f")   "-2.5f : Float64"   "negative float literal"))

;; ========================================
;; Exponent + f compose (Numerics N1 × N3c)
;; ========================================

(test-case "Float exponent literals"
  (check-equal? (run-ns-ws-last "1.5e-3f")  "0.0015f : Float64" "exp + f → Float64")
  (let ([r (run-ns-ws-last "1.5e-3f32")])
    (check-true (and (string-suffix? (car (regexp-split #px" : " r)) "f32")
                     (string-contains? r ": Float32"))
                (format "exp + f32 → Float32: ~a" r))))

;; ========================================
;; Full end-to-end Float COMPUTE at L3 (literals → ops, N3b × N3c)
;; ========================================

(test-case "Float compute with literal operands"
  (check-equal? (run-ns-ws-last "[f64+ 3.0f64 2.0f64]") "5.0f : Float64")
  (check-equal? (run-ns-ws-last "[f64- 5.0f64 1.5f64]") "3.5f : Float64")
  (check-equal? (run-ns-ws-last "[f64* 2.0f64 3.0f64]") "6.0f : Float64")
  (check-equal? (run-ns-ws-last "[f64-sqrt 9.0f64]")    "3.0f : Float64")
  (check-equal? (run-ns-ws-last "[f32+ 0.1f32 0.2f32]") "0.3f32 : Float32"
                "f32 op result single-rounded")
  (check-true (string-contains? (run-ns-ws-last "[f64-lt 1.0f64 2.0f64]") "true") "f64-lt → true")
  (check-true (string-contains? (run-ns-ws-last "[f64-eq 1.0f64 1.0f64]") "true") "f64-eq → true"))

;; ========================================
;; Regression: bare decimals/numbers are UNTOUCHED (N3c is additive)
;; ========================================

(test-case "non-float literals unchanged"
  (check-equal? (run-ns-ws-last "3.14") "~3.14 : Posit32" "bare 3.14 stays Posit32")
  (check-equal? (run-ns-ws-last "1e10") "10000000000 : Int" "N1 exponent literal still exact Int")
  (check-equal? (run-ns-ws-last "42") "42 : Int" "bare int unchanged")
  (let ([r (run-ns-ws-last "1/2")])
    (check-true (string-contains? r "Rat") (format "1/2 is a Rat: ~a" r))))
