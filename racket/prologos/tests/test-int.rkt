#lang racket/base

;;;
;;; Tests for Int integration — core AST + surface syntax end-to-end
;;;

(require racket/string
         rackunit
         "../syntax.rkt"
         "../prelude.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../pretty-print.rkt"
         "../driver.rkt"
         "../global-env.rkt")

;; ========================================
;; Core AST: Type formation
;; ========================================

(test-case "Int type formation"
  ;; Int : Type 0
  (check-equal? (tc:infer ctx-empty (expr-Int))
                (expr-Type (lzero))
                "Int : Type 0")
  ;; infer-level
  (check-equal? (tc:infer-level ctx-empty (expr-Int))
                (tc:just-level (lzero))
                "Int at level 0")
  ;; is-type
  (check-true (tc:is-type ctx-empty (expr-Int))
              "Int is a type"))

;; ========================================
;; Core AST: Literal typing
;; ========================================

(test-case "int literal typing"
  (check-equal? (tc:infer ctx-empty (expr-int 0))
                (expr-Int)
                "int(0) : Int")
  (check-equal? (tc:infer ctx-empty (expr-int 42))
                (expr-Int)
                "int(42) : Int")
  (check-equal? (tc:infer ctx-empty (expr-int -7))
                (expr-Int)
                "int(-7) : Int")
  (check-equal? (tc:infer ctx-empty (expr-int 999999999999))
                (expr-Int)
                "int(big) : Int")
  ;; Check mode
  (check-true (tc:check ctx-empty (expr-int 42) (expr-Int))
              "check int(42) : Int"))

;; ========================================
;; Core AST: Arithmetic reduction
;; ========================================

(test-case "int arithmetic reduction"
  ;; 3 + 4 = 7
  (check-equal? (whnf (expr-int-add (expr-int 3) (expr-int 4)))
                (expr-int 7)
                "3 + 4 = 7")
  ;; 10 - 3 = 7
  (check-equal? (whnf (expr-int-sub (expr-int 10) (expr-int 3)))
                (expr-int 7)
                "10 - 3 = 7")
  ;; 5 - 8 = -3 (negative result)
  (check-equal? (whnf (expr-int-sub (expr-int 5) (expr-int 8)))
                (expr-int -3)
                "5 - 8 = -3")
  ;; 6 * 7 = 42
  (check-equal? (whnf (expr-int-mul (expr-int 6) (expr-int 7)))
                (expr-int 42)
                "6 * 7 = 42")
  ;; 17 / 5 = 3 (truncating)
  (check-equal? (whnf (expr-int-div (expr-int 17) (expr-int 5)))
                (expr-int 3)
                "17 / 5 = 3")
  ;; -17 / 5 = -3 (truncating toward zero)
  (check-equal? (whnf (expr-int-div (expr-int -17) (expr-int 5)))
                (expr-int -3)
                "-17 / 5 = -3")
  ;; 17 mod 5 = 2
  (check-equal? (whnf (expr-int-mod (expr-int 17) (expr-int 5)))
                (expr-int 2)
                "17 mod 5 = 2")
  ;; 0 + 0 = 0
  (check-equal? (whnf (expr-int-add (expr-int 0) (expr-int 0)))
                (expr-int 0)
                "0 + 0 = 0"))

(test-case "int division by zero stays stuck"
  ;; Division by zero should remain as stuck term (not crash)
  (let ([result (whnf (expr-int-div (expr-int 42) (expr-int 0)))])
    (check-true (expr-int-div? result)
                "div by zero stays stuck")))

(test-case "int unary reduction"
  ;; neg(5) = -5
  (check-equal? (whnf (expr-int-neg (expr-int 5)))
                (expr-int -5)
                "neg(5) = -5")
  ;; neg(-3) = 3
  (check-equal? (whnf (expr-int-neg (expr-int -3)))
                (expr-int 3)
                "neg(-3) = 3")
  ;; abs(-7) = 7
  (check-equal? (whnf (expr-int-abs (expr-int -7)))
                (expr-int 7)
                "abs(-7) = 7")
  ;; abs(5) = 5
  (check-equal? (whnf (expr-int-abs (expr-int 5)))
                (expr-int 5)
                "abs(5) = 5"))

;; ========================================
;; Core AST: Comparison reduction
;; ========================================

(test-case "int comparison reduction"
  ;; 3 < 5 → true
  (check-equal? (whnf (expr-int-lt (expr-int 3) (expr-int 5)))
                (expr-true)
                "3 < 5")
  ;; 5 < 3 → false
  (check-equal? (whnf (expr-int-lt (expr-int 5) (expr-int 3)))
                (expr-false)
                "not 5 < 3")
  ;; 3 <= 3 → true
  (check-equal? (whnf (expr-int-le (expr-int 3) (expr-int 3)))
                (expr-true)
                "3 <= 3")
  ;; 4 <= 3 → false
  (check-equal? (whnf (expr-int-le (expr-int 4) (expr-int 3)))
                (expr-false)
                "not 4 <= 3")
  ;; 7 = 7 → true
  (check-equal? (whnf (expr-int-eq (expr-int 7) (expr-int 7)))
                (expr-true)
                "7 = 7")
  ;; 7 = 8 → false
  (check-equal? (whnf (expr-int-eq (expr-int 7) (expr-int 8)))
                (expr-false)
                "7 ≠ 8")
  ;; -1 < 0 → true
  (check-equal? (whnf (expr-int-lt (expr-int -1) (expr-int 0)))
                (expr-true)
                "-1 < 0"))

;; ========================================
;; Core AST: Conversion
;; ========================================

(test-case "int from-nat conversion"
  ;; from-nat(0) = int(0)
  (check-equal? (whnf (expr-from-nat (expr-zero)))
                (expr-int 0)
                "from-nat(0) = int(0)")
  ;; from-nat(1) = int(1)
  (check-equal? (whnf (expr-from-nat (expr-suc (expr-zero))))
                (expr-int 1)
                "from-nat(1) = int(1)")
  ;; from-nat(5) = int(5)
  (check-equal? (whnf (expr-from-nat (expr-suc (expr-suc (expr-suc (expr-suc (expr-suc (expr-zero))))))))
                (expr-int 5)
                "from-nat(5) = int(5)"))

;; ========================================
;; Core AST: Type checking
;; ========================================

(test-case "int operation typing"
  ;; Binary ops type correctly
  (check-equal? (tc:infer ctx-empty (expr-int-add (expr-int 1) (expr-int 2)))
                (expr-Int)
                "int-add infers Int")
  (check-equal? (tc:infer ctx-empty (expr-int-sub (expr-int 5) (expr-int 3)))
                (expr-Int)
                "int-sub infers Int")
  (check-equal? (tc:infer ctx-empty (expr-int-mul (expr-int 2) (expr-int 3)))
                (expr-Int)
                "int-mul infers Int")
  (check-equal? (tc:infer ctx-empty (expr-int-div (expr-int 10) (expr-int 3)))
                (expr-Int)
                "int-div infers Int")
  (check-equal? (tc:infer ctx-empty (expr-int-mod (expr-int 10) (expr-int 3)))
                (expr-Int)
                "int-mod infers Int")
  ;; Unary ops type correctly
  (check-equal? (tc:infer ctx-empty (expr-int-neg (expr-int 5)))
                (expr-Int)
                "int-neg infers Int")
  (check-equal? (tc:infer ctx-empty (expr-int-abs (expr-int -5)))
                (expr-Int)
                "int-abs infers Int")
  ;; Comparisons return Bool
  (check-equal? (tc:infer ctx-empty (expr-int-lt (expr-int 1) (expr-int 2)))
                (expr-Bool)
                "int-lt infers Bool")
  (check-equal? (tc:infer ctx-empty (expr-int-le (expr-int 1) (expr-int 2)))
                (expr-Bool)
                "int-le infers Bool")
  (check-equal? (tc:infer ctx-empty (expr-int-eq (expr-int 1) (expr-int 2)))
                (expr-Bool)
                "int-eq infers Bool")
  ;; from-nat takes Nat, returns Int
  (check-equal? (tc:infer ctx-empty (expr-from-nat (expr-zero)))
                (expr-Int)
                "from-nat infers Int")
  ;; Type error: adding bool and int
  (check-equal? (tc:infer ctx-empty (expr-int-add (expr-true) (expr-int 1)))
                (expr-error)
                "int-add rejects non-Int args"))

;; ========================================
;; Core AST: Substitution
;; ========================================

(test-case "int substitution"
  ;; Shift through operations
  (check-equal? (shift 1 0 (expr-int-add (expr-bvar 0) (expr-int 5)))
                (expr-int-add (expr-bvar 1) (expr-int 5))
                "shift increases bvar in int-add")
  ;; Subst in operations
  (check-equal? (subst 0 (expr-int 10) (expr-int-add (expr-bvar 0) (expr-int 5)))
                (expr-int-add (expr-int 10) (expr-int 5))
                "subst replaces bvar in int-add")
  ;; Leaves unchanged for Int type and literals
  (check-equal? (shift 1 0 (expr-Int)) (expr-Int) "Int type stable under shift")
  (check-equal? (shift 1 0 (expr-int 42)) (expr-int 42) "int literal stable under shift")
  ;; Unary
  (check-equal? (shift 1 0 (expr-int-neg (expr-bvar 0)))
                (expr-int-neg (expr-bvar 1))
                "shift through int-neg")
  ;; from-nat
  (check-equal? (subst 0 (expr-zero) (expr-from-nat (expr-bvar 0)))
                (expr-from-nat (expr-zero))
                "subst through from-nat"))

;; ========================================
;; Core AST: Pretty-printing
;; ========================================

(test-case "int pretty-printing"
  (check-equal? (pp-expr (expr-Int) '()) "Int" "pp Int")
  (check-equal? (pp-expr (expr-int 42) '()) "42" "pp int(42)")
  (check-equal? (pp-expr (expr-int -7) '()) "-7" "pp int(-7)")
  (check-equal? (pp-expr (expr-int-add (expr-int 3) (expr-int 4)) '())
                "[int+ 3 4]" "pp int+"))

;; ========================================
;; Surface syntax: End-to-end via process-string
;; ========================================

;; Helper to run with clean global env
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(test-case "int surface: eval literal"
  (check-equal? (run "(eval (int 42))")
                '("42 : Int")))

(test-case "int surface: eval negative literal"
  (check-equal? (run "(eval (int -7))")
                '("-7 : Int")))

(test-case "int surface: addition"
  (check-equal? (run "(eval (int+ (int 3) (int 4)))")
                '("7 : Int")))

(test-case "int surface: subtraction"
  (check-equal? (run "(eval (int- (int 10) (int 3)))")
                '("7 : Int")))

(test-case "int surface: multiplication"
  (check-equal? (run "(eval (int* (int 6) (int 7)))")
                '("42 : Int")))

(test-case "int surface: division"
  (check-equal? (run "(eval (int/ (int 17) (int 5)))")
                '("3 : Int")))

(test-case "int surface: modulo"
  (check-equal? (run "(eval (int-mod (int 17) (int 5)))")
                '("2 : Int")))

(test-case "int surface: negation"
  (check-equal? (run "(eval (int-neg (int 5)))")
                '("-5 : Int")))

(test-case "int surface: abs"
  (check-equal? (run "(eval (int-abs (int -7)))")
                '("7 : Int")))

(test-case "int surface: comparison lt"
  (check-equal? (run "(eval (int-lt (int 3) (int 5)))")
                '("true : Bool")))

(test-case "int surface: comparison le"
  (check-equal? (run "(eval (int-le (int 3) (int 3)))")
                '("true : Bool")))

(test-case "int surface: comparison eq"
  (check-equal? (run "(eval (int-eq(int 7) (int 7)))")
                '("true : Bool")))

(test-case "int surface: from-nat"
  (check-equal? (run "(eval (from-nat (inc (inc zero))))")
                '("2 : Int")))

(test-case "int surface: check type"
  (check-equal? (run "(check (int 42) <Int>)")
                '("OK")))

(test-case "int surface: Int type formation"
  (check-equal? (run "(check Int <(Type 0)>)")
                '("OK")))

(test-case "int surface: def + eval"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(def x <Int> (int 42))\n(eval x)")])
      (check-equal? (length result) 2)
      (check-true (string-contains? (car result) "x : Int defined"))
      (check-equal? (cadr result) "42 : Int"))))

(test-case "int surface: nested arithmetic"
  (check-equal? (run "(eval (int+ (int* (int 3) (int 4)) (int 5)))")
                '("17 : Int")))

(test-case "int surface: zero literal"
  (check-equal? (run "(eval (int 0))")
                '("0 : Int")))

(test-case "int surface: large number"
  (check-equal? (run "(eval (int* (int 1000000) (int 1000000)))")
                '("1000000000000 : Int")))
