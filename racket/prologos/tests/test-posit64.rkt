#lang racket/base

;;;
;;; Tests for Posit64 integration — core AST + surface syntax end-to-end
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

;; Posit64 constants:
;; one     = 0x4000000000000000 = 4611686018427387904
;; two     = 0x4800000000000000 = 5188146770730811392
;; NaR     = 0x8000000000000000 = 9223372036854775808
;; neg-one = 0xC000000000000000 = 13835058055282163712
;; max     = 0xFFFFFFFFFFFFFFFF = 18446744073709551615

;; ========================================
;; Core AST: Type formation
;; ========================================

(test-case "Posit64 type formation"
  (check-equal? (tc:infer ctx-empty (expr-Posit64))
                (expr-Type (lzero))
                "Posit64 : Type 0")
  (check-equal? (tc:infer-level ctx-empty (expr-Posit64))
                (tc:just-level (lzero))
                "Posit64 at level 0")
  (check-true (tc:is-type ctx-empty (expr-Posit64))
              "Posit64 is a type"))

;; ========================================
;; Core AST: Literal typing
;; ========================================

(test-case "posit64 literal typing"
  (check-equal? (tc:infer ctx-empty (expr-posit64 0))
                (expr-Posit64)
                "posit64(0) : Posit64")
  (check-equal? (tc:infer ctx-empty (expr-posit64 4611686018427387904))
                (expr-Posit64)
                "posit64(one) : Posit64")
  (check-equal? (tc:infer ctx-empty (expr-posit64 9223372036854775808))
                (expr-Posit64)
                "posit64(NaR) : Posit64")
  (check-equal? (tc:infer ctx-empty (expr-posit64 18446744073709551615))
                (expr-Posit64)
                "posit64(max) : Posit64")
  ;; Check mode
  (check-true (tc:check ctx-empty (expr-posit64 4611686018427387904) (expr-Posit64))
              "check posit64(one) : Posit64")
  ;; Invalid literal
  (check-equal? (tc:infer ctx-empty (expr-posit64 18446744073709551616))
                (expr-error)
                "posit64(2^64) is out of range"))

;; ========================================
;; Core AST: Arithmetic reduction
;; ========================================

(test-case "posit64 arithmetic reduction"
  ;; 1 + 1 = 2
  (check-equal? (whnf (expr-p64-add (expr-posit64 4611686018427387904) (expr-posit64 4611686018427387904)))
                (expr-posit64 5188146770730811392)
                "p64+(1,1) = 2")
  ;; 1 * 2 = 2
  (check-equal? (whnf (expr-p64-mul (expr-posit64 4611686018427387904) (expr-posit64 5188146770730811392)))
                (expr-posit64 5188146770730811392)
                "p64*(1,2) = 2")
  ;; 2 - 1 = 1
  (check-equal? (whnf (expr-p64-sub (expr-posit64 5188146770730811392) (expr-posit64 4611686018427387904)))
                (expr-posit64 4611686018427387904)
                "p64-(2,1) = 1")
  ;; 2 / 1 = 2
  (check-equal? (whnf (expr-p64-div (expr-posit64 5188146770730811392) (expr-posit64 4611686018427387904)))
                (expr-posit64 5188146770730811392)
                "p64/(2,1) = 2")
  ;; NaR propagation
  (check-equal? (whnf (expr-p64-add (expr-posit64 9223372036854775808) (expr-posit64 4611686018427387904)))
                (expr-posit64 9223372036854775808)
                "NaR + 1 = NaR")
  ;; 0/0 = NaR
  (check-equal? (whnf (expr-p64-div (expr-posit64 0) (expr-posit64 0)))
                (expr-posit64 9223372036854775808)
                "0/0 = NaR"))

(test-case "posit64 unary reduction"
  ;; neg(1) = -1
  (check-equal? (whnf (expr-p64-neg (expr-posit64 4611686018427387904)))
                (expr-posit64 13835058055282163712)
                "neg(1) = -1")
  ;; abs(-1) = 1
  (check-equal? (whnf (expr-p64-abs (expr-posit64 13835058055282163712)))
                (expr-posit64 4611686018427387904)
                "abs(-1) = 1")
  ;; neg(NaR) = NaR
  (check-equal? (whnf (expr-p64-neg (expr-posit64 9223372036854775808)))
                (expr-posit64 9223372036854775808)
                "neg(NaR) = NaR"))

;; ========================================
;; Core AST: Comparison reduction
;; ========================================

(test-case "posit64 comparison reduction"
  (check-equal? (whnf (expr-p64-lt (expr-posit64 4611686018427387904) (expr-posit64 5188146770730811392)))
                (expr-true)
                "1 < 2")
  (check-equal? (whnf (expr-p64-lt (expr-posit64 5188146770730811392) (expr-posit64 4611686018427387904)))
                (expr-false)
                "not 2 < 1")
  (check-equal? (whnf (expr-p64-le (expr-posit64 4611686018427387904) (expr-posit64 4611686018427387904)))
                (expr-true)
                "1 <= 1")
  (check-equal? (whnf (expr-p64-lt (expr-posit64 9223372036854775808) (expr-posit64 4611686018427387904)))
                (expr-false)
                "NaR not < 1"))

;; ========================================
;; Core AST: Conversion
;; ========================================

(test-case "posit64 from-nat conversion"
  (check-equal? (whnf (expr-p64-from-nat (expr-zero)))
                (expr-posit64 0)
                "from-nat(0) = posit64(0)")
  (check-equal? (whnf (expr-p64-from-nat (expr-suc (expr-zero))))
                (expr-posit64 4611686018427387904)
                "from-nat(1) = posit64(one)")
  (check-equal? (whnf (expr-p64-from-nat (expr-suc (expr-suc (expr-zero)))))
                (expr-posit64 5188146770730811392)
                "from-nat(2) = posit64(two)"))

;; ========================================
;; Core AST: p64-if-nar eliminator
;; ========================================

(test-case "posit64 if-nar eliminator"
  (check-equal? (whnf (expr-p64-if-nar (expr-Nat) (expr-zero) (expr-suc (expr-zero)) (expr-posit64 9223372036854775808)))
                (expr-zero)
                "if-nar on NaR -> nar-case")
  (check-equal? (whnf (expr-p64-if-nar (expr-Nat) (expr-zero) (expr-suc (expr-zero)) (expr-posit64 4611686018427387904)))
                (expr-suc (expr-zero))
                "if-nar on non-NaR -> normal-case"))

;; ========================================
;; Core AST: Type checking
;; ========================================

(test-case "posit64 operation typing"
  (check-equal? (tc:infer ctx-empty (expr-p64-add (expr-posit64 4611686018427387904) (expr-posit64 4611686018427387904)))
                (expr-Posit64)
                "p64-add infers Posit64")
  (check-equal? (tc:infer ctx-empty (expr-p64-lt (expr-posit64 4611686018427387904) (expr-posit64 5188146770730811392)))
                (expr-Bool)
                "p64-lt infers Bool")
  (check-equal? (tc:infer ctx-empty (expr-p64-from-nat (expr-zero)))
                (expr-Posit64)
                "p64-from-nat infers Posit64")
  (check-equal? (tc:infer ctx-empty (expr-p64-add (expr-true) (expr-posit64 4611686018427387904)))
                (expr-error)
                "p64-add rejects non-Posit64 args"))

;; ========================================
;; Core AST: Substitution
;; ========================================

(test-case "posit64 substitution"
  (check-equal? (shift 1 0 (expr-p64-add (expr-bvar 0) (expr-posit64 4611686018427387904)))
                (expr-p64-add (expr-bvar 1) (expr-posit64 4611686018427387904))
                "shift increases bvar in p64-add")
  (check-equal? (subst 0 (expr-posit64 4611686018427387904) (expr-p64-add (expr-bvar 0) (expr-posit64 5188146770730811392)))
                (expr-p64-add (expr-posit64 4611686018427387904) (expr-posit64 5188146770730811392))
                "subst replaces bvar in p64-add")
  (check-equal? (shift 1 0 (expr-Posit64)) (expr-Posit64) "Posit64 type is stable under shift")
  (check-equal? (shift 1 0 (expr-posit64 42)) (expr-posit64 42) "posit64 literal is stable under shift"))

;; ========================================
;; Core AST: Pretty-printing
;; ========================================

(test-case "posit64 pretty-printing"
  (check-equal? (pp-expr (expr-Posit64) '()) "Posit64" "pp Posit64")
  (check-equal? (pp-expr (expr-posit64 4611686018427387904) '()) "[posit64 4611686018427387904]" "pp posit64(one)")
  (check-equal? (pp-expr (expr-p64-add (expr-posit64 4611686018427387904) (expr-posit64 5188146770730811392)) '())
                "[p64+ [posit64 4611686018427387904] [posit64 5188146770730811392]]" "pp p64+"))

;; ========================================
;; Surface syntax: End-to-end via process-string
;; ========================================

(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(test-case "posit64 surface: eval literal"
  (check-equal? (run "(eval (posit64 4611686018427387904))")
                '("[posit64 4611686018427387904] : Posit64")))

(test-case "posit64 surface: arithmetic 1+1=2"
  (check-equal? (run "(eval (p64+ (posit64 4611686018427387904) (posit64 4611686018427387904)))")
                '("[posit64 5188146770730811392] : Posit64")))

(test-case "posit64 surface: check type"
  (check-equal? (run "(check (posit64 4611686018427387904) <Posit64>)")
                '("OK")))

(test-case "posit64 surface: Posit64 type formation"
  (check-equal? (run "(check Posit64 <(Type 0)>)")
                '("OK")))

(test-case "posit64 surface: def + eval"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(def one <Posit64> (posit64 4611686018427387904))\n(eval one)")])
      (check-equal? (length result) 2)
      (check-true (string-contains? (car result) "one : Posit64 defined"))
      (check-equal? (cadr result) "[posit64 4611686018427387904] : Posit64"))))

(test-case "posit64 surface: negation"
  (check-equal? (run "(eval (p64-neg (posit64 4611686018427387904)))")
                '("[posit64 13835058055282163712] : Posit64")))

(test-case "posit64 surface: comparison"
  (check-equal? (run "(eval (p64-lt (posit64 4611686018427387904) (posit64 5188146770730811392)))")
                '("true : Bool")))

(test-case "posit64 surface: from-nat"
  (check-equal? (run "(eval (p64-from-nat (inc (inc zero))))")
                '("[posit64 5188146770730811392] : Posit64")))

(test-case "posit64 surface: if-nar on NaR"
  (check-equal? (run "(eval (p64-if-nar Nat zero (inc zero) (posit64 9223372036854775808)))")
                '("zero : Nat")))

(test-case "posit64 surface: if-nar on non-NaR"
  (check-equal? (run "(eval (p64-if-nar Nat zero (inc zero) (posit64 4611686018427387904)))")
                '("1 : Nat")))

(test-case "posit64 surface: NaR propagation"
  (check-equal? (run "(eval (p64+ (posit64 9223372036854775808) (posit64 4611686018427387904)))")
                '("[posit64 9223372036854775808] : Posit64")))

(test-case "posit64 surface: division by zero -> NaR"
  (check-equal? (run "(eval (p64/ (posit64 4611686018427387904) (posit64 0)))")
                '("[posit64 9223372036854775808] : Posit64")))

(test-case "posit64 surface: defn with Posit64"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(defn p64-double [x <Posit64>] <Posit64>\n  (p64+ x x))\n(eval (p64-double (posit64 4611686018427387904)))")])
      (check-equal? (length result) 2)
      (check-equal? (cadr result) "[posit64 5188146770730811392] : Posit64"))))
