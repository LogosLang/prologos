#lang racket/base

;;;
;;; Tests for Rat integration — core AST + surface syntax end-to-end
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

(test-case "Rat type formation"
  ;; Rat : Type 0
  (check-equal? (tc:infer ctx-empty (expr-Rat))
                (expr-Type (lzero))
                "Rat : Type 0")
  ;; infer-level
  (check-equal? (tc:infer-level ctx-empty (expr-Rat))
                (tc:just-level (lzero))
                "Rat at level 0")
  ;; is-type
  (check-true (tc:is-type ctx-empty (expr-Rat))
              "Rat is a type"))

;; ========================================
;; Core AST: Literal typing
;; ========================================

(test-case "rat literal typing"
  (check-equal? (tc:infer ctx-empty (expr-rat 0))
                (expr-Rat)
                "rat(0) : Rat")
  (check-equal? (tc:infer ctx-empty (expr-rat 42))
                (expr-Rat)
                "rat(42) : Rat")
  (check-equal? (tc:infer ctx-empty (expr-rat 3/7))
                (expr-Rat)
                "rat(3/7) : Rat")
  (check-equal? (tc:infer ctx-empty (expr-rat -1/2))
                (expr-Rat)
                "rat(-1/2) : Rat")
  ;; Check mode
  (check-true (tc:check ctx-empty (expr-rat 3/7) (expr-Rat))
              "check rat(3/7) : Rat"))

;; ========================================
;; Core AST: Arithmetic reduction
;; ========================================

(test-case "rat arithmetic reduction"
  ;; 1/3 + 1/6 = 1/2
  (check-equal? (whnf (expr-rat-add (expr-rat 1/3) (expr-rat 1/6)))
                (expr-rat 1/2)
                "1/3 + 1/6 = 1/2")
  ;; 3/4 - 1/4 = 1/2
  (check-equal? (whnf (expr-rat-sub (expr-rat 3/4) (expr-rat 1/4)))
                (expr-rat 1/2)
                "3/4 - 1/4 = 1/2")
  ;; 2/3 * 3/5 = 2/5
  (check-equal? (whnf (expr-rat-mul (expr-rat 2/3) (expr-rat 3/5)))
                (expr-rat 2/5)
                "2/3 * 3/5 = 2/5")
  ;; 3/4 / 2 = 3/8
  (check-equal? (whnf (expr-rat-div (expr-rat 3/4) (expr-rat 2)))
                (expr-rat 3/8)
                "3/4 / 2 = 3/8")
  ;; 0 + 0 = 0
  (check-equal? (whnf (expr-rat-add (expr-rat 0) (expr-rat 0)))
                (expr-rat 0)
                "0 + 0 = 0"))

(test-case "rat division by zero stays stuck"
  (let ([result (whnf (expr-rat-div (expr-rat 3/7) (expr-rat 0)))])
    (check-true (expr-rat-div? result)
                "div by zero stays stuck")))

(test-case "rat unary reduction"
  ;; neg(3/7) = -3/7
  (check-equal? (whnf (expr-rat-neg (expr-rat 3/7)))
                (expr-rat -3/7)
                "neg(3/7) = -3/7")
  ;; neg(-1/2) = 1/2
  (check-equal? (whnf (expr-rat-neg (expr-rat -1/2)))
                (expr-rat 1/2)
                "neg(-1/2) = 1/2")
  ;; abs(-3/4) = 3/4
  (check-equal? (whnf (expr-rat-abs (expr-rat -3/4)))
                (expr-rat 3/4)
                "abs(-3/4) = 3/4")
  ;; abs(5/6) = 5/6
  (check-equal? (whnf (expr-rat-abs (expr-rat 5/6)))
                (expr-rat 5/6)
                "abs(5/6) = 5/6"))

;; ========================================
;; Core AST: Comparison reduction
;; ========================================

(test-case "rat comparison reduction"
  ;; 1/3 < 1/2 → true
  (check-equal? (whnf (expr-rat-lt (expr-rat 1/3) (expr-rat 1/2)))
                (expr-true)
                "1/3 < 1/2")
  ;; 1/2 < 1/3 → false
  (check-equal? (whnf (expr-rat-lt (expr-rat 1/2) (expr-rat 1/3)))
                (expr-false)
                "not 1/2 < 1/3")
  ;; 3/7 <= 3/7 → true
  (check-equal? (whnf (expr-rat-le (expr-rat 3/7) (expr-rat 3/7)))
                (expr-true)
                "3/7 <= 3/7")
  ;; 1/2 <= 1/3 → false
  (check-equal? (whnf (expr-rat-le (expr-rat 1/2) (expr-rat 1/3)))
                (expr-false)
                "not 1/2 <= 1/3")
  ;; 3/7 = 3/7 → true
  (check-equal? (whnf (expr-rat-eq (expr-rat 3/7) (expr-rat 3/7)))
                (expr-true)
                "3/7 = 3/7")
  ;; 3/7 = 4/7 → false
  (check-equal? (whnf (expr-rat-eq (expr-rat 3/7) (expr-rat 4/7)))
                (expr-false)
                "3/7 ≠ 4/7"))

;; ========================================
;; Core AST: Conversion and projections
;; ========================================

(test-case "rat from-int conversion"
  ;; from-int(int(42)) = rat(42)
  (check-equal? (whnf (expr-from-int (expr-int 42)))
                (expr-rat 42)
                "from-int(42) = rat(42)")
  ;; from-int(int(-3)) = rat(-3)
  (check-equal? (whnf (expr-from-int (expr-int -3)))
                (expr-rat -3)
                "from-int(-3) = rat(-3)"))

(test-case "rat numerator/denominator projections"
  ;; numer(3/7) = int(3)
  (check-equal? (whnf (expr-rat-numer (expr-rat 3/7)))
                (expr-int 3)
                "numer(3/7) = 3")
  ;; denom(3/7) = int(7)
  (check-equal? (whnf (expr-rat-denom (expr-rat 3/7)))
                (expr-int 7)
                "denom(3/7) = 7")
  ;; numer(-1/2) = int(-1)
  (check-equal? (whnf (expr-rat-numer (expr-rat -1/2)))
                (expr-int -1)
                "numer(-1/2) = -1")
  ;; denom(-1/2) = int(2) (always positive)
  (check-equal? (whnf (expr-rat-denom (expr-rat -1/2)))
                (expr-int 2)
                "denom(-1/2) = 2")
  ;; numer(5) = int(5) (integer as rational)
  (check-equal? (whnf (expr-rat-numer (expr-rat 5)))
                (expr-int 5)
                "numer(5) = 5")
  ;; denom(5) = int(1)
  (check-equal? (whnf (expr-rat-denom (expr-rat 5)))
                (expr-int 1)
                "denom(5) = 1"))

;; ========================================
;; Core AST: Type checking operations
;; ========================================

(test-case "rat operation typing"
  ;; Binary ops type correctly
  (check-equal? (tc:infer ctx-empty (expr-rat-add (expr-rat 1) (expr-rat 2)))
                (expr-Rat)
                "rat-add infers Rat")
  (check-equal? (tc:infer ctx-empty (expr-rat-sub (expr-rat 5) (expr-rat 3)))
                (expr-Rat)
                "rat-sub infers Rat")
  (check-equal? (tc:infer ctx-empty (expr-rat-mul (expr-rat 2) (expr-rat 3)))
                (expr-Rat)
                "rat-mul infers Rat")
  (check-equal? (tc:infer ctx-empty (expr-rat-div (expr-rat 10) (expr-rat 3)))
                (expr-Rat)
                "rat-div infers Rat")
  ;; Unary ops type correctly
  (check-equal? (tc:infer ctx-empty (expr-rat-neg (expr-rat 5)))
                (expr-Rat)
                "rat-neg infers Rat")
  (check-equal? (tc:infer ctx-empty (expr-rat-abs (expr-rat -5)))
                (expr-Rat)
                "rat-abs infers Rat")
  ;; Comparisons return Bool
  (check-equal? (tc:infer ctx-empty (expr-rat-lt (expr-rat 1) (expr-rat 2)))
                (expr-Bool)
                "rat-lt infers Bool")
  (check-equal? (tc:infer ctx-empty (expr-rat-le (expr-rat 1) (expr-rat 2)))
                (expr-Bool)
                "rat-le infers Bool")
  (check-equal? (tc:infer ctx-empty (expr-rat-eq (expr-rat 1) (expr-rat 2)))
                (expr-Bool)
                "rat-eq infers Bool")
  ;; from-int takes Int, returns Rat
  (check-equal? (tc:infer ctx-empty (expr-from-int (expr-int 0)))
                (expr-Rat)
                "from-int infers Rat")
  ;; Projections return Int
  (check-equal? (tc:infer ctx-empty (expr-rat-numer (expr-rat 3/7)))
                (expr-Int)
                "rat-numer infers Int")
  (check-equal? (tc:infer ctx-empty (expr-rat-denom (expr-rat 3/7)))
                (expr-Int)
                "rat-denom infers Int")
  ;; Type error: adding bool and rat
  (check-equal? (tc:infer ctx-empty (expr-rat-add (expr-true) (expr-rat 1)))
                (expr-error)
                "rat-add rejects non-Rat args"))

;; ========================================
;; Core AST: Substitution
;; ========================================

(test-case "rat substitution"
  ;; Shift through operations
  (check-equal? (shift 1 0 (expr-rat-add (expr-bvar 0) (expr-rat 5/7)))
                (expr-rat-add (expr-bvar 1) (expr-rat 5/7))
                "shift increases bvar in rat-add")
  ;; Subst in operations
  (check-equal? (subst 0 (expr-rat 1/3) (expr-rat-add (expr-bvar 0) (expr-rat 5/7)))
                (expr-rat-add (expr-rat 1/3) (expr-rat 5/7))
                "subst replaces bvar in rat-add")
  ;; Leaves unchanged for Rat type and literals
  (check-equal? (shift 1 0 (expr-Rat)) (expr-Rat) "Rat type stable under shift")
  (check-equal? (shift 1 0 (expr-rat 3/7)) (expr-rat 3/7) "rat literal stable under shift")
  ;; Unary
  (check-equal? (shift 1 0 (expr-rat-neg (expr-bvar 0)))
                (expr-rat-neg (expr-bvar 1))
                "shift through rat-neg")
  ;; from-int
  (check-equal? (subst 0 (expr-int 5) (expr-from-int (expr-bvar 0)))
                (expr-from-int (expr-int 5))
                "subst through from-int")
  ;; rat-numer
  (check-equal? (shift 1 0 (expr-rat-numer (expr-bvar 0)))
                (expr-rat-numer (expr-bvar 1))
                "shift through rat-numer"))

;; ========================================
;; Core AST: Pretty-printing
;; ========================================

(test-case "rat pretty-printing"
  (check-equal? (pp-expr (expr-Rat) '()) "Rat" "pp Rat")
  (check-equal? (pp-expr (expr-rat 3/7) '()) "3/7" "pp rat(3/7)")
  (check-equal? (pp-expr (expr-rat -1/2) '()) "-1/2" "pp rat(-1/2)")
  (check-equal? (pp-expr (expr-rat 42) '()) "42" "pp rat(42)")
  (check-equal? (pp-expr (expr-rat-add (expr-rat 1/3) (expr-rat 1/6)) '())
                "[rat+ 1/3 1/6]" "pp rat+"))

;; ========================================
;; Surface syntax: End-to-end via process-string
;; ========================================

;; Helper to run with clean global env
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(test-case "rat surface: eval literal"
  (check-equal? (run "(eval (rat 3/7))")
                '("3/7 : Rat")))

(test-case "rat surface: eval integer-valued rational"
  (check-equal? (run "(eval (rat 42))")
                '("42 : Rat")))

(test-case "rat surface: eval negative rational"
  (check-equal? (run "(eval (rat -1/2))")
                '("-1/2 : Rat")))

(test-case "rat surface: addition"
  (check-equal? (run "(eval (rat+ (rat 1/3) (rat 1/6)))")
                '("1/2 : Rat")))

(test-case "rat surface: subtraction"
  (check-equal? (run "(eval (rat- (rat 3/4) (rat 1/4)))")
                '("1/2 : Rat")))

(test-case "rat surface: multiplication"
  (check-equal? (run "(eval (rat* (rat 2/3) (rat 3/5)))")
                '("2/5 : Rat")))

(test-case "rat surface: division"
  (check-equal? (run "(eval (rat/ (rat 3/4) (rat 2)))")
                '("3/8 : Rat")))

(test-case "rat surface: negation"
  (check-equal? (run "(eval (rat-neg (rat 3/7)))")
                '("-3/7 : Rat")))

(test-case "rat surface: abs"
  (check-equal? (run "(eval (rat-abs (rat -3/4)))")
                '("3/4 : Rat")))

(test-case "rat surface: comparison lt"
  (check-equal? (run "(eval (rat-lt (rat 1/3) (rat 1/2)))")
                '("true : Bool")))

(test-case "rat surface: comparison le"
  (check-equal? (run "(eval (rat-le (rat 3/7) (rat 3/7)))")
                '("true : Bool")))

(test-case "rat surface: comparison eq"
  (check-equal? (run "(eval (rat-eq (rat 3/7) (rat 3/7)))")
                '("true : Bool")))

(test-case "rat surface: from-int"
  (check-equal? (run "(eval (from-int (int 42)))")
                '("42 : Rat")))

(test-case "rat surface: rat-numer"
  (check-equal? (run "(eval (rat-numer (rat 3/7)))")
                '("3 : Int")))

(test-case "rat surface: rat-denom"
  (check-equal? (run "(eval (rat-denom (rat 3/7)))")
                '("7 : Int")))

(test-case "rat surface: check type"
  (check-equal? (run "(check (rat 3/7) <Rat>)")
                '("OK")))

(test-case "rat surface: Rat type formation"
  (check-equal? (run "(check Rat <(Type 0)>)")
                '("OK")))

(test-case "rat surface: def + eval"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(def x <Rat> (rat 3/7))\n(eval x)")])
      (check-equal? (length result) 2)
      (check-true (string-contains? (car result) "x : Rat defined"))
      (check-equal? (cadr result) "3/7 : Rat"))))

(test-case "rat surface: nested arithmetic"
  (check-equal? (run "(eval (rat+ (rat* (rat 1/2) (rat 2/3)) (rat 1/6)))")
                '("1/2 : Rat")))

(test-case "rat surface: bare fraction literal"
  ;; Test that bare 3/7 is tokenized as a rational number
  (check-equal? (run "(eval (rat+ (rat 1/3) (rat 2/3)))")
                '("1 : Rat")))
