#lang racket/base

;;;
;;; Tests for Generic Arithmetic Operators (Phase 2a)
;;; Verifies: parser keywords +/-/*/lt/le/eq/negate/abs, type checking,
;;;           reduction for Int, Rat, Nat, Posit32.
;;;

(require rackunit
         racket/string
         "../syntax.rkt"
         "../prelude.rkt"
         "../surface-syntax.rkt"
         "../posit-impl.rkt"
         "../parser.rkt"
         "../driver.rkt"
         "../global-env.rkt")

;; Helper: run through process-string (sexp mode)
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (car (process-string s))))

;; ========================================
;; Int arithmetic
;; ========================================

(test-case "generic-arith/int-add"
  (check-equal? (run "(eval (+ 3 4))") "7 : Int"))

(test-case "generic-arith/int-sub"
  (check-equal? (run "(eval (- 10 3))") "7 : Int"))

(test-case "generic-arith/int-mul"
  (check-equal? (run "(eval (* 3 4))") "12 : Int"))

(test-case "generic-arith/int-div"
  (check-equal? (run "(eval (/ 7 2))") "3 : Int"))

(test-case "generic-arith/int-negate"
  (check-equal? (run "(eval (negate 5))") "-5 : Int"))

(test-case "generic-arith/int-abs"
  ;; Use (negate 7) since -7 isn't a valid sexp literal
  (check-equal? (run "(eval (abs (negate 7)))") "7 : Int"))

;; ========================================
;; Int comparison (lt, le, eq — not < <= = due to angle-bracket conflict)
;; ========================================

(test-case "generic-arith/int-lt-true"
  (check-true (string-contains? (run "(eval (lt 3 4))") "true")))

(test-case "generic-arith/int-lt-false"
  (check-true (string-contains? (run "(eval (lt 4 3))") "false")))

(test-case "generic-arith/int-le-true"
  (check-true (string-contains? (run "(eval (le 3 3))") "true")))

(test-case "generic-arith/int-le-false"
  (check-true (string-contains? (run "(eval (le 4 3))") "false")))

(test-case "generic-arith/int-eq-true"
  (check-true (string-contains? (run "(eval (eq 42 42))") "true")))

(test-case "generic-arith/int-eq-false"
  (check-true (string-contains? (run "(eval (eq 42 43))") "false")))

;; ========================================
;; Rat arithmetic
;; ========================================

(test-case "generic-arith/rat-add"
  (check-equal? (run "(eval (+ 1/2 3/7))") "13/14 : Rat"))

(test-case "generic-arith/rat-sub"
  (check-equal? (run "(eval (- 3/4 1/4))") "1/2 : Rat"))

(test-case "generic-arith/rat-mul"
  (check-equal? (run "(eval (* 2/3 3/5))") "2/5 : Rat"))

(test-case "generic-arith/rat-div"
  (check-equal? (run "(eval (/ 1/2 1/4))") "2 : Rat"))

(test-case "generic-arith/rat-lt"
  (check-true (string-contains? (run "(eval (lt 1/3 1/2))") "true")))

(test-case "generic-arith/rat-eq"
  (check-true (string-contains? (run "(eval (eq 1/2 2/4))") "true")))

;; ========================================
;; Posit32 arithmetic
;; ========================================

(test-case "generic-arith/p32-add"
  (define result (run "(eval (+ ~1 ~2))"))
  (check-true (string-contains? result "posit32")
              (format "expected posit32, got: ~a" result))
  (check-true (string-contains? result (number->string (posit32-encode 3)))
              (format "expected encoding of 3, got: ~a" result)))

(test-case "generic-arith/p32-mul"
  (define result (run "(eval (* ~3 ~4))"))
  (check-true (string-contains? result "posit32"))
  (check-true (string-contains? result (number->string (posit32-encode 12)))))

(test-case "generic-arith/p32-negate"
  (define result (run "(eval (negate ~5))"))
  (check-true (string-contains? result "posit32")))

(test-case "generic-arith/p32-lt"
  (check-true (string-contains? (run "(eval (lt ~1 ~2))") "true")))

;; ========================================
;; Type inference
;; ========================================

(test-case "generic-arith/infer-int-add"
  (check-true (string-contains? (run "(infer (+ 3 4))") "Int")))

(test-case "generic-arith/infer-rat-add"
  (check-true (string-contains? (run "(infer (+ 1/2 1/3))") "Rat")))

(test-case "generic-arith/infer-p32-add"
  (check-true (string-contains? (run "(infer (+ ~1 ~2))") "Posit32")))

(test-case "generic-arith/infer-int-lt"
  (check-true (string-contains? (run "(infer (lt 3 4))") "Bool")))

(test-case "generic-arith/infer-negate"
  (check-true (string-contains? (run "(infer (negate 5))") "Int")))

(test-case "generic-arith/infer-abs"
  (check-true (string-contains? (run "(infer (abs 7))") "Int")))

;; ========================================
;; Nat arithmetic
;; ========================================

(test-case "generic-arith/nat-add"
  ;; 2 + 3 = 5
  (check-equal? (run "(eval (+ (suc (suc zero)) (suc (suc (suc zero)))))")
                "5N : Nat"))

(test-case "generic-arith/nat-mul"
  ;; 2 * 3 = 6
  (check-equal? (run "(eval (* (suc (suc zero)) (suc (suc (suc zero)))))")
                "6N : Nat"))

(test-case "generic-arith/nat-sub-truncated"
  ;; 2 - 3 = 0 (truncated subtraction for Nat)
  (check-equal? (run "(eval (- (suc (suc zero)) (suc (suc (suc zero)))))")
                "0N : Nat"))

(test-case "generic-arith/nat-lt"
  (check-true (string-contains? (run "(eval (lt (suc zero) (suc (suc zero))))") "true")))

(test-case "generic-arith/nat-eq"
  (check-true (string-contains? (run "(eval (eq (suc zero) (suc zero)))") "true")))
