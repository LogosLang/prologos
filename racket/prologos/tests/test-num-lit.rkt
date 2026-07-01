#lang racket/base

;;;
;;; Tests for N4: context-typed polymorphic numeric literals (expr-num-lit).
;;;
;;; A bare decimal / fraction / non-integral exponent is a POLYMORPHIC literal
;;; (surf-num-lit -> expr-num-lit) that carries its exact value, resolves its
;;; type FROM CONTEXT (check-mode), and defaults, unconstrained, to Rat (Int if
;;; integral). Markers (~/f/N) and explicit rationals stay concrete.
;;;

(require racket/string
         rackunit
         "test-support.rkt"
         "../syntax.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../driver.rkt")

(define (run s) (process-string s))

;; ========================================
;; surf-num-lit surface node (bare decimals/fractions)
;; ========================================

(test-case "num-lit/parse-decimal-is-surf-num-lit"
  (define r (parse-datum (datum->syntax #f '($decimal-literal 157/50))))
  (check-true (surf-num-lit? r) "bare decimal parses to surf-num-lit")
  (check-equal? (surf-num-lit-val r) 157/50)
  (check-false (surf-num-lit-integral? r) "3.14 is not integral"))

(test-case "num-lit/parse-integral-decimal-flag"
  (define r (parse-datum (datum->syntax #f '($decimal-literal 3))))
  (check-true (surf-num-lit? r))
  (check-true (surf-num-lit-integral? r) "3.0 is integral"))

;; ========================================
;; Context-typing via `check` (the key N4 feature)
;; ========================================

(test-case "num-lit/context-typed-check-ok"
  (check-equal? (run "(check 3.14 <Float64>)") '("OK") "3.14 checks as Float64")
  (check-equal? (run "(check 3.14 <Posit32>)") '("OK") "3.14 checks as Posit32")
  (check-equal? (run "(check 3.14 <Rat>)")     '("OK") "3.14 checks as Rat")
  (check-equal? (run "(check 3.0 <Int>)")      '("OK") "3.0 (integral) checks as Int")
  (check-equal? (run "(check 3.0 <Nat>)")      '("OK") "3.0 (integral, nonneg) checks as Nat"))

(test-case "num-lit/representability-errors"
  ;; 3.14 is not integral -> NOT representable as Int / Nat
  (check-false (equal? (run "(check 3.14 <Int>)") '("OK")) "3.14 not representable as Int")
  (check-false (equal? (run "(check 3.14 <Nat>)") '("OK")) "3.14 not representable as Nat"))

;; ========================================
;; Context-typed eval collapses to the target concrete node
;; ========================================

(test-case "num-lit/eval-ascribed-collapses"
  (check-equal? (run "(eval (the Float64 3.14))") '("3.14f : Float64"))
  (check-equal? (run "(eval (the Posit32 1.0))")  '("~1 : Posit32"))
  (check-equal? (run "(eval (the Int 3.0))")      '("3 : Int")))

;; ========================================
;; Unconstrained -> Rat (Int if integral); WS mode = clean display
;; ========================================

(test-case "num-lit/unconstrained-defaults"
  (check-equal? (run-ns-ws-last "3.14") "3.14 : Rat" "bare decimal -> Rat")
  (check-true (string-contains? (run-ns-ws-last "3.0") "Int") "integral decimal -> Int")
  (check-true (string-contains? (run-ns-ws-last "3/7") "Rat") "bare fraction -> Rat")
  (check-true (string-contains? (run-ns-ws-last "1.5e-3") "Rat") "non-integral exponent -> Rat"))

;; ========================================
;; Generic arithmetic over polymorphic literals
;; ========================================

(test-case "num-lit/generic-arith"
  (check-true (string-contains? (run-ns-ws-last "[+ 1/2 3/7]") "Rat") "[+ 1/2 3/7] -> Rat"))

;; ========================================
;; Option B: ascribed literals feed a width-specific op
;; ========================================

(test-case "num-lit/ascribed-width-op"
  (check-equal? (run "(eval (p32+ (the Posit32 1.0) (the Posit32 2.0)))") '("~3 : Posit32"))
  (check-equal? (run "(eval (f64+ (the Float64 1.0) (the Float64 2.0)))") '("3.0f : Float64")))

;; ========================================
;; Markers stay concrete (unchanged by N4)
;; ========================================

(test-case "num-lit/markers-unchanged"
  (check-true (string-contains? (run-ns-ws-last "~3.14") "Posit32") "~3.14 stays Posit32")
  (check-true (string-contains? (run-ns-ws-last "3.14f64") "Float64") "3.14f64 stays Float64"))

;; ========================================
;; N1 integral exponent stays Int (non-regression)
;; ========================================

(test-case "num-lit/integral-exp-nonregression"
  (check-equal? (run-ns-ws-last "1e10") "10000000000 : Int" "1e10 (integral exp) -> Int"))
