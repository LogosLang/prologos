#lang racket/base

;;;
;;; Tests for Posit8 integration — core AST + surface syntax end-to-end
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

(test-case "Posit8 type formation"
  ;; Posit8 : Type 0
  (check-equal? (tc:infer ctx-empty (expr-Posit8))
                (expr-Type (lzero))
                "Posit8 : Type 0")
  ;; infer-level
  (check-equal? (tc:infer-level ctx-empty (expr-Posit8))
                (tc:just-level (lzero))
                "Posit8 at level 0")
  ;; is-type
  (check-true (tc:is-type ctx-empty (expr-Posit8))
              "Posit8 is a type"))

;; ========================================
;; Core AST: Literal typing
;; ========================================

(test-case "posit8 literal typing"
  (check-equal? (tc:infer ctx-empty (expr-posit8 0))
                (expr-Posit8)
                "posit8(0) : Posit8")
  (check-equal? (tc:infer ctx-empty (expr-posit8 64))
                (expr-Posit8)
                "posit8(64) : Posit8")
  (check-equal? (tc:infer ctx-empty (expr-posit8 128))
                (expr-Posit8)
                "posit8(128) [NaR] : Posit8")
  (check-equal? (tc:infer ctx-empty (expr-posit8 255))
                (expr-Posit8)
                "posit8(255) : Posit8")
  ;; Check mode
  (check-true (tc:check ctx-empty (expr-posit8 64) (expr-Posit8))
              "check posit8(64) : Posit8")
  ;; Invalid literal
  (check-equal? (tc:infer ctx-empty (expr-posit8 256))
                (expr-error)
                "posit8(256) is out of range"))

;; ========================================
;; Core AST: Arithmetic reduction
;; ========================================

(test-case "posit8 arithmetic reduction"
  ;; 1 + 1 = 2 (0x40 + 0x40 = 0x48)
  (check-equal? (whnf (expr-p8-add (expr-posit8 64) (expr-posit8 64)))
                (expr-posit8 72)
                "p8+(1,1) = 2")
  ;; 1 * 2 = 2
  (check-equal? (whnf (expr-p8-mul (expr-posit8 64) (expr-posit8 72)))
                (expr-posit8 72)
                "p8*(1,2) = 2")
  ;; 2 - 1 = 1
  (check-equal? (whnf (expr-p8-sub (expr-posit8 72) (expr-posit8 64)))
                (expr-posit8 64)
                "p8-(2,1) = 1")
  ;; 2 / 1 = 2
  (check-equal? (whnf (expr-p8-div (expr-posit8 72) (expr-posit8 64)))
                (expr-posit8 72)
                "p8/(2,1) = 2")
  ;; NaR propagation
  (check-equal? (whnf (expr-p8-add (expr-posit8 128) (expr-posit8 64)))
                (expr-posit8 128)
                "NaR + 1 = NaR")
  ;; 0/0 = NaR
  (check-equal? (whnf (expr-p8-div (expr-posit8 0) (expr-posit8 0)))
                (expr-posit8 128)
                "0/0 = NaR"))

(test-case "posit8 unary reduction"
  ;; neg(1) = -1
  (check-equal? (whnf (expr-p8-neg (expr-posit8 64)))
                (expr-posit8 192)
                "neg(1) = -1")
  ;; abs(-1) = 1
  (check-equal? (whnf (expr-p8-abs (expr-posit8 192)))
                (expr-posit8 64)
                "abs(-1) = 1")
  ;; neg(NaR) = NaR
  (check-equal? (whnf (expr-p8-neg (expr-posit8 128)))
                (expr-posit8 128)
                "neg(NaR) = NaR"))

;; ========================================
;; Core AST: Comparison reduction
;; ========================================

(test-case "posit8 comparison reduction"
  ;; 1 < 2 → true
  (check-equal? (whnf (expr-p8-lt (expr-posit8 64) (expr-posit8 72)))
                (expr-true)
                "1 < 2")
  ;; 2 < 1 → false
  (check-equal? (whnf (expr-p8-lt (expr-posit8 72) (expr-posit8 64)))
                (expr-false)
                "not 2 < 1")
  ;; 1 <= 1 → true
  (check-equal? (whnf (expr-p8-le (expr-posit8 64) (expr-posit8 64)))
                (expr-true)
                "1 <= 1")
  ;; NaR < anything → false
  (check-equal? (whnf (expr-p8-lt (expr-posit8 128) (expr-posit8 64)))
                (expr-false)
                "NaR not < 1"))

;; ========================================
;; Core AST: Conversion
;; ========================================

(test-case "posit8 from-nat conversion"
  ;; from-nat(0) = posit8(0) [zero]
  (check-equal? (whnf (expr-p8-from-nat (expr-zero)))
                (expr-posit8 0)
                "from-nat(0) = posit8(0)")
  ;; from-nat(1) = posit8(64) [one]
  (check-equal? (whnf (expr-p8-from-nat (expr-suc (expr-zero))))
                (expr-posit8 64)
                "from-nat(1) = posit8(64)")
  ;; from-nat(2) = posit8(72) [two]
  (check-equal? (whnf (expr-p8-from-nat (expr-suc (expr-suc (expr-zero)))))
                (expr-posit8 72)
                "from-nat(2) = posit8(72)"))

;; ========================================
;; Core AST: p8-if-nar eliminator
;; ========================================

(test-case "posit8 if-nar eliminator"
  ;; NaR branch: p8-if-nar(Nat, zero, (suc zero), posit8(128)) → zero
  (check-equal? (whnf (expr-p8-if-nar (expr-Nat) (expr-zero) (expr-suc (expr-zero)) (expr-posit8 128)))
                (expr-zero)
                "if-nar on NaR → nar-case")
  ;; Normal branch: p8-if-nar(Nat, zero, (suc zero), posit8(64)) → (suc zero)
  (check-equal? (whnf (expr-p8-if-nar (expr-Nat) (expr-zero) (expr-suc (expr-zero)) (expr-posit8 64)))
                (expr-nat-val 1)
                "if-nar on non-NaR → normal-case"))

;; ========================================
;; Core AST: Type checking
;; ========================================

(test-case "posit8 operation typing"
  ;; Binary ops type correctly
  (check-equal? (tc:infer ctx-empty (expr-p8-add (expr-posit8 64) (expr-posit8 64)))
                (expr-Posit8)
                "p8-add infers Posit8")
  ;; Comparison returns Bool
  (check-equal? (tc:infer ctx-empty (expr-p8-lt (expr-posit8 64) (expr-posit8 72)))
                (expr-Bool)
                "p8-lt infers Bool")
  ;; from-nat takes Nat, returns Posit8
  (check-equal? (tc:infer ctx-empty (expr-p8-from-nat (expr-zero)))
                (expr-Posit8)
                "p8-from-nat infers Posit8")
  ;; Type error: adding bool and posit
  (check-equal? (tc:infer ctx-empty (expr-p8-add (expr-true) (expr-posit8 64)))
                (expr-error)
                "p8-add rejects non-Posit8 args"))

;; ========================================
;; Core AST: Substitution
;; ========================================

(test-case "posit8 substitution"
  ;; Shift through operations
  (check-equal? (shift 1 0 (expr-p8-add (expr-bvar 0) (expr-posit8 64)))
                (expr-p8-add (expr-bvar 1) (expr-posit8 64))
                "shift increases bvar in p8-add")
  ;; Subst in operations
  (check-equal? (subst 0 (expr-posit8 64) (expr-p8-add (expr-bvar 0) (expr-posit8 72)))
                (expr-p8-add (expr-posit8 64) (expr-posit8 72))
                "subst replaces bvar in p8-add")
  ;; Leaves unchanged for Posit8 type and literals
  (check-equal? (shift 1 0 (expr-Posit8)) (expr-Posit8) "Posit8 type is stable under shift")
  (check-equal? (shift 1 0 (expr-posit8 42)) (expr-posit8 42) "posit8 literal is stable under shift"))

;; ========================================
;; Core AST: Pretty-printing
;; ========================================

(test-case "posit8 pretty-printing"
  (check-equal? (pp-expr (expr-Posit8) '()) "Posit8" "pp Posit8")
  (check-equal? (pp-expr (expr-posit8 64) '()) "[posit8 64]" "pp posit8(64)")
  (check-equal? (pp-expr (expr-p8-add (expr-posit8 64) (expr-posit8 72)) '())
                "[p8+ [posit8 64] [posit8 72]]" "pp p8+"))

;; ========================================
;; Surface syntax: End-to-end via process-string
;; ========================================

;; Helper to run with clean global env
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(test-case "posit8 surface: eval literal"
  (check-equal? (run "(eval (posit8 64))")
                '("[posit8 64] : Posit8")))

(test-case "posit8 surface: arithmetic 1+1=2"
  (check-equal? (run "(eval (p8+ (posit8 64) (posit8 64)))")
                '("[posit8 72] : Posit8")))

(test-case "posit8 surface: check type"
  (check-equal? (run "(check (posit8 64) <Posit8>)")
                '("OK")))

(test-case "posit8 surface: Posit8 type formation"
  (check-equal? (run "(check Posit8 <(Type 0)>)")
                '("OK")))

(test-case "posit8 surface: def + eval"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(def one <Posit8> (posit8 64))\n(eval one)")])
      (check-equal? (length result) 2)
      (check-true (string-contains? (car result) "one : Posit8 defined"))
      (check-equal? (cadr result) "[posit8 64] : Posit8"))))

(test-case "posit8 surface: negation"
  (check-equal? (run "(eval (p8-neg (posit8 64)))")
                '("[posit8 192] : Posit8")))

(test-case "posit8 surface: comparison"
  (check-equal? (run "(eval (p8-lt (posit8 64) (posit8 72)))")
                '("true : Bool")))

(test-case "posit8 surface: from-nat"
  (check-equal? (run "(eval (p8-from-nat (suc (suc zero))))")
                '("[posit8 72] : Posit8")))

(test-case "posit8 surface: if-nar on NaR"
  (check-equal? (run "(eval (p8-if-nar Nat zero (suc zero) (posit8 128)))")
                '("0N : Nat")))

(test-case "posit8 surface: if-nar on non-NaR"
  (check-equal? (run "(eval (p8-if-nar Nat zero (suc zero) (posit8 64)))")
                '("1N : Nat")))

(test-case "posit8 surface: NaR propagation"
  (check-equal? (run "(eval (p8+ (posit8 128) (posit8 64)))")
                '("[posit8 128] : Posit8")))

(test-case "posit8 surface: division by zero → NaR"
  (check-equal? (run "(eval (p8/ (posit8 64) (posit8 0)))")
                '("[posit8 128] : Posit8")))

(test-case "posit8 surface: defn with Posit8"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(defn p8-double [x <Posit8>] <Posit8>\n  (p8+ x x))\n(eval (p8-double (posit8 64)))")])
      (check-equal? (length result) 2)
      (check-equal? (cadr result) "[posit8 72] : Posit8"))))
