#lang racket/base

;;;
;;; Tests for numeric coercion in generic operators (Phase 3b)
;;;
;;; When generic operators receive operands of different numeric types,
;;; the narrower operand is coerced to the join type:
;;; - Within exact family: Nat < Int < Rat (wider wins)
;;; - Within posit family: P8 < P16 < P32 < P64 (wider wins)
;;; - Cross-family: posit dominates exact, minimum P32
;;;

(require racket/string
         racket/list
         rackunit
         "../syntax.rkt"
         "../prelude.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../posit-impl.rkt")

;; Helper: run through process-string (sexp mode)
(define (run s)
  (process-string s))

;; ========================================
;; Within exact family: Nat + Int → Int
;; ========================================

(test-case "coercion/nat+int"
  ;; 3N + 4 → 7 : Int  (Nat coerced to Int)
  (check-equal? (run "(eval (+ 3N 4))")
                '("7 : Int")))

(test-case "coercion/int+nat"
  ;; Commutative
  (check-equal? (run "(eval (+ 4 3N))")
                '("7 : Int")))

(test-case "coercion/nat*int"
  (check-equal? (run "(eval (* 2N 5))")
                '("10 : Int")))

;; ========================================
;; Within exact family: Int + Rat → Rat
;; ========================================

(test-case "coercion/int+rat"
  ;; 3 + 1/2 → 3.5 : Rat
  (check-equal? (run "(eval (+ 3 1/2))")
                '("7/2 : Rat")))

(test-case "coercion/rat+int"
  (check-equal? (run "(eval (+ 1/2 3))")
                '("7/2 : Rat")))

(test-case "coercion/nat+rat"
  ;; 2N + 1/3 → 7/3 : Rat
  (check-equal? (run "(eval (+ 2N 1/3))")
                '("7/3 : Rat")))

;; ========================================
;; Within exact: Nat - Int → Int
;; ========================================

(test-case "coercion/nat-sub-int"
  ;; 5N - 3 → 2 : Int
  (check-equal? (run "(eval (- 5N 3))")
                '("2 : Int")))

;; ========================================
;; Within exact: comparison across types
;; ========================================

(test-case "coercion/nat-lt-int"
  ;; 3N < 4 → true (Nat coerced to Int)
  (check-equal? (run "(eval (lt 3N 4))")
                '("true : Bool")))

(test-case "coercion/int-eq-rat"
  ;; 3 = 3/1 → true (Int coerced to Rat)
  (check-equal? (run "(eval (eq 3 3/1))")
                '("true : Bool")))

;; ========================================
;; Cross-family: exact + Posit32 → Posit32
;; ========================================

;; N6a values-only policy: literal operands no longer warn — the exact result
;; strings drop their warning line; the value-operand twin locks the full
;; normalized warning text.

(test-case "coercion/int+p32"
  ;; 42 + 1.0 → Posit32; literal operand → silent (N6a)
  (define result (run "(eval (+ 42 1.0))"))
  (check-equal? result
                '("43.0 : Posit32")))

(test-case "coercion/int-value+p32"
  ;; VALUE operand: warns, with the canonical normalized text (exact-side → join)
  (define result (run "(def n : Int 42)(eval (+ n 1.0))"))
  (check-equal? (last result)
                "43.0 : Posit32\nwarning: implicit coercion from Int to Posit32 (loss of exactness)"))

(test-case "coercion/rat+p32"
  ;; 1/2 + 0.5 → Posit32; literal operand → silent (N6a)
  (define result (run "(eval (+ 1/2 0.5))"))
  (check-equal? result
                '("1.0 : Posit32")))

(test-case "coercion/nat+p32"
  ;; 3N + 1.0 → Posit32; literal operand → silent (N6a)
  (define result (run "(eval (+ 3N 1.0))"))
  (check-equal? result
                '("4.0 : Posit32")))

;; ========================================
;; Cross-family: exact + Posit64 → Posit64
;; ========================================

(test-case "coercion/int+p64"
  ;; 10 + p64-value → Posit64; the exact-side operand (10) is a literal → silent (N6a)
  (define result (run "(eval (+ 10 (from-integer <Posit64> 5)))"))
  (check-equal? result
                '("15p : Posit64")))

;; ========================================
;; Within posit family: P8 + P32 → P32
;; ========================================

(test-case "coercion/p8+p32"
  ;; from-integer Posit8 2 + 3.0 → Posit32
  (define result (run "(eval (+ (from-integer <Posit8> 2) 3.0))"))
  (check-equal? result
                '("5.0 : Posit32")))

;; ========================================
;; Type inference checks
;; ========================================

(test-case "coercion/infer-nat+int"
  (define result (car (run "(infer (+ 3N 4))")))
  (check-true (string-contains? result "Int") "Nat+Int should infer as Int"))

(test-case "coercion/infer-int+rat"
  (define result (car (run "(infer (+ 3 1/2))")))
  (check-true (string-contains? result "Rat") "Int+Rat should infer as Rat"))

(test-case "coercion/infer-int+p32"
  (define result (car (run "(infer (+ 42 1.0))")))
  (check-true (string-contains? result "Posit32") "Int+Posit32 should infer as Posit32"))

;; ========================================
;; Multiplication with coercion
;; ========================================

(test-case "coercion/int*rat"
  (check-equal? (run "(eval (* 3 1/2))")
                '("3/2 : Rat")))

(test-case "coercion/nat*p32"
  ;; literal operand → silent (N6a)
  (define result (run "(eval (* 2N 3.0))"))
  (check-equal? result
                '("6.0 : Posit32")))

;; ========================================
;; Division with coercion
;; ========================================

(test-case "coercion/int-div-rat"
  ;; 6 / 1/2 → 12 : Rat (both coerced to Rat, since Nat/Int don't have div)
  (check-equal? (run "(eval (/ 6 1/2))")
                '("12 : Rat")))

;; ========================================
;; Same-type still works (no regression)
;; ========================================

(test-case "coercion/same-int-add"
  (check-equal? (run "(eval (+ 3 4))")
                '("7 : Int")))

(test-case "coercion/same-rat-add"
  (check-equal? (run "(eval (+ 1/2 3/7))")
                '("13/14 : Rat")))

(test-case "coercion/same-p32-add"
  (check-equal? (run "(eval (+ 1.0 2.0))")
                '("3.0 : Posit32")))
