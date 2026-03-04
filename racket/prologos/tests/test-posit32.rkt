#lang racket/base

;;;
;;; Tests for Posit32 integration — core AST + surface syntax end-to-end
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

;; Posit32 constants:
;; one    = 0x40000000 = 1073741824
;; two    = 0x48000000 = 1207959552
;; NaR    = 0x80000000 = 2147483648
;; neg-one= 0xC0000000 = 3221225472
;; max    = 0xFFFFFFFF = 4294967295

;; ========================================
;; Core AST: Type formation
;; ========================================

(test-case "Posit32 type formation"
  (check-equal? (tc:infer ctx-empty (expr-Posit32))
                (expr-Type (lzero))
                "Posit32 : Type 0")
  (check-equal? (tc:infer-level ctx-empty (expr-Posit32))
                (tc:just-level (lzero))
                "Posit32 at level 0")
  (check-true (tc:is-type ctx-empty (expr-Posit32))
              "Posit32 is a type"))

;; ========================================
;; Core AST: Literal typing
;; ========================================

(test-case "posit32 literal typing"
  (check-equal? (tc:infer ctx-empty (expr-posit32 0))
                (expr-Posit32)
                "posit32(0) : Posit32")
  (check-equal? (tc:infer ctx-empty (expr-posit32 1073741824))
                (expr-Posit32)
                "posit32(one) : Posit32")
  (check-equal? (tc:infer ctx-empty (expr-posit32 2147483648))
                (expr-Posit32)
                "posit32(NaR) : Posit32")
  (check-equal? (tc:infer ctx-empty (expr-posit32 4294967295))
                (expr-Posit32)
                "posit32(max) : Posit32")
  ;; Check mode
  (check-true (tc:check ctx-empty (expr-posit32 1073741824) (expr-Posit32))
              "check posit32(one) : Posit32")
  ;; Invalid literal
  (check-equal? (tc:infer ctx-empty (expr-posit32 4294967296))
                (expr-error)
                "posit32(4294967296) is out of range"))

;; ========================================
;; Core AST: Arithmetic reduction
;; ========================================

(test-case "posit32 arithmetic reduction"
  ;; 1 + 1 = 2
  (check-equal? (whnf (expr-p32-add (expr-posit32 1073741824) (expr-posit32 1073741824)))
                (expr-posit32 1207959552)
                "p32+(1,1) = 2")
  ;; 1 * 2 = 2
  (check-equal? (whnf (expr-p32-mul (expr-posit32 1073741824) (expr-posit32 1207959552)))
                (expr-posit32 1207959552)
                "p32*(1,2) = 2")
  ;; 2 - 1 = 1
  (check-equal? (whnf (expr-p32-sub (expr-posit32 1207959552) (expr-posit32 1073741824)))
                (expr-posit32 1073741824)
                "p32-(2,1) = 1")
  ;; 2 / 1 = 2
  (check-equal? (whnf (expr-p32-div (expr-posit32 1207959552) (expr-posit32 1073741824)))
                (expr-posit32 1207959552)
                "p32/(2,1) = 2")
  ;; NaR propagation
  (check-equal? (whnf (expr-p32-add (expr-posit32 2147483648) (expr-posit32 1073741824)))
                (expr-posit32 2147483648)
                "NaR + 1 = NaR")
  ;; 0/0 = NaR
  (check-equal? (whnf (expr-p32-div (expr-posit32 0) (expr-posit32 0)))
                (expr-posit32 2147483648)
                "0/0 = NaR"))

(test-case "posit32 unary reduction"
  ;; neg(1) = -1
  (check-equal? (whnf (expr-p32-neg (expr-posit32 1073741824)))
                (expr-posit32 3221225472)
                "neg(1) = -1")
  ;; abs(-1) = 1
  (check-equal? (whnf (expr-p32-abs (expr-posit32 3221225472)))
                (expr-posit32 1073741824)
                "abs(-1) = 1")
  ;; neg(NaR) = NaR
  (check-equal? (whnf (expr-p32-neg (expr-posit32 2147483648)))
                (expr-posit32 2147483648)
                "neg(NaR) = NaR"))

;; ========================================
;; Core AST: Comparison reduction
;; ========================================

(test-case "posit32 comparison reduction"
  (check-equal? (whnf (expr-p32-lt (expr-posit32 1073741824) (expr-posit32 1207959552)))
                (expr-true)
                "1 < 2")
  (check-equal? (whnf (expr-p32-lt (expr-posit32 1207959552) (expr-posit32 1073741824)))
                (expr-false)
                "not 2 < 1")
  (check-equal? (whnf (expr-p32-le (expr-posit32 1073741824) (expr-posit32 1073741824)))
                (expr-true)
                "1 <= 1")
  (check-equal? (whnf (expr-p32-lt (expr-posit32 2147483648) (expr-posit32 1073741824)))
                (expr-false)
                "NaR not < 1"))

;; ========================================
;; Core AST: Conversion
;; ========================================

(test-case "posit32 from-nat conversion"
  (check-equal? (whnf (expr-p32-from-nat (expr-zero)))
                (expr-posit32 0)
                "from-nat(0) = posit32(0)")
  (check-equal? (whnf (expr-p32-from-nat (expr-suc (expr-zero))))
                (expr-posit32 1073741824)
                "from-nat(1) = posit32(one)")
  (check-equal? (whnf (expr-p32-from-nat (expr-suc (expr-suc (expr-zero)))))
                (expr-posit32 1207959552)
                "from-nat(2) = posit32(two)"))

;; ========================================
;; Core AST: p32-if-nar eliminator
;; ========================================

(test-case "posit32 if-nar eliminator"
  (check-equal? (whnf (expr-p32-if-nar (expr-Nat) (expr-zero) (expr-suc (expr-zero)) (expr-posit32 2147483648)))
                (expr-zero)
                "if-nar on NaR -> nar-case")
  (check-equal? (whnf (expr-p32-if-nar (expr-Nat) (expr-zero) (expr-suc (expr-zero)) (expr-posit32 1073741824)))
                (expr-nat-val 1)
                "if-nar on non-NaR -> normal-case"))

;; ========================================
;; Core AST: Type checking
;; ========================================

(test-case "posit32 operation typing"
  (check-equal? (tc:infer ctx-empty (expr-p32-add (expr-posit32 1073741824) (expr-posit32 1073741824)))
                (expr-Posit32)
                "p32-add infers Posit32")
  (check-equal? (tc:infer ctx-empty (expr-p32-lt (expr-posit32 1073741824) (expr-posit32 1207959552)))
                (expr-Bool)
                "p32-lt infers Bool")
  (check-equal? (tc:infer ctx-empty (expr-p32-from-nat (expr-zero)))
                (expr-Posit32)
                "p32-from-nat infers Posit32")
  (check-equal? (tc:infer ctx-empty (expr-p32-add (expr-true) (expr-posit32 1073741824)))
                (expr-error)
                "p32-add rejects non-Posit32 args"))

;; ========================================
;; Core AST: Substitution
;; ========================================

(test-case "posit32 substitution"
  (check-equal? (shift 1 0 (expr-p32-add (expr-bvar 0) (expr-posit32 1073741824)))
                (expr-p32-add (expr-bvar 1) (expr-posit32 1073741824))
                "shift increases bvar in p32-add")
  (check-equal? (subst 0 (expr-posit32 1073741824) (expr-p32-add (expr-bvar 0) (expr-posit32 1207959552)))
                (expr-p32-add (expr-posit32 1073741824) (expr-posit32 1207959552))
                "subst replaces bvar in p32-add")
  (check-equal? (shift 1 0 (expr-Posit32)) (expr-Posit32) "Posit32 type is stable under shift")
  (check-equal? (shift 1 0 (expr-posit32 42)) (expr-posit32 42) "posit32 literal is stable under shift"))

;; ========================================
;; Core AST: Pretty-printing
;; ========================================

(test-case "posit32 pretty-printing"
  (check-equal? (pp-expr (expr-Posit32) '()) "Posit32" "pp Posit32")
  (check-equal? (pp-expr (expr-posit32 1073741824) '()) "[posit32 1073741824]" "pp posit32(one)")
  (check-equal? (pp-expr (expr-p32-add (expr-posit32 1073741824) (expr-posit32 1207959552)) '())
                "[p32+ [posit32 1073741824] [posit32 1207959552]]" "pp p32+"))

;; ========================================
;; Surface syntax: End-to-end via process-string
;; ========================================

(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(test-case "posit32 surface: eval literal"
  (check-equal? (run "(eval (posit32 1073741824))")
                '("[posit32 1073741824] : Posit32")))

(test-case "posit32 surface: arithmetic 1+1=2"
  (check-equal? (run "(eval (p32+ (posit32 1073741824) (posit32 1073741824)))")
                '("[posit32 1207959552] : Posit32")))

(test-case "posit32 surface: check type"
  (check-equal? (run "(check (posit32 1073741824) <Posit32>)")
                '("OK")))

(test-case "posit32 surface: Posit32 type formation"
  (check-equal? (run "(check Posit32 <(Type 0)>)")
                '("OK")))

(test-case "posit32 surface: def + eval"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(def one <Posit32> (posit32 1073741824))\n(eval one)")])
      (check-equal? (length result) 2)
      (check-true (string-contains? (car result) "one : Posit32 defined"))
      (check-equal? (cadr result) "[posit32 1073741824] : Posit32"))))

(test-case "posit32 surface: negation"
  (check-equal? (run "(eval (p32-neg (posit32 1073741824)))")
                '("[posit32 3221225472] : Posit32")))

(test-case "posit32 surface: comparison"
  (check-equal? (run "(eval (p32-lt (posit32 1073741824) (posit32 1207959552)))")
                '("true : Bool")))

(test-case "posit32 surface: from-nat"
  (check-equal? (run "(eval (p32-from-nat (suc (suc zero))))")
                '("[posit32 1207959552] : Posit32")))

(test-case "posit32 surface: if-nar on NaR"
  (check-equal? (run "(eval (p32-if-nar Nat zero (suc zero) (posit32 2147483648)))")
                '("0N : Nat")))

(test-case "posit32 surface: if-nar on non-NaR"
  (check-equal? (run "(eval (p32-if-nar Nat zero (suc zero) (posit32 1073741824)))")
                '("1N : Nat")))

(test-case "posit32 surface: NaR propagation"
  (check-equal? (run "(eval (p32+ (posit32 2147483648) (posit32 1073741824)))")
                '("[posit32 2147483648] : Posit32")))

(test-case "posit32 surface: division by zero -> NaR"
  (check-equal? (run "(eval (p32/ (posit32 1073741824) (posit32 0)))")
                '("[posit32 2147483648] : Posit32")))

(test-case "posit32 surface: defn with Posit32"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(defn p32-double [x <Posit32>] <Posit32>\n  (p32+ x x))\n(eval (p32-double (posit32 1073741824)))")])
      (check-equal? (length result) 2)
      (check-equal? (cadr result) "[posit32 1207959552] : Posit32"))))
