#lang racket/base

;;;
;;; Tests for Posit16 integration — core AST + surface syntax end-to-end
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

(test-case "Posit16 type formation"
  (check-equal? (tc:infer ctx-empty (expr-Posit16))
                (expr-Type (lzero))
                "Posit16 : Type 0")
  (check-equal? (tc:infer-level ctx-empty (expr-Posit16))
                (tc:just-level (lzero))
                "Posit16 at level 0")
  (check-true (tc:is-type ctx-empty (expr-Posit16))
              "Posit16 is a type"))

;; ========================================
;; Core AST: Literal typing
;; ========================================

(test-case "posit16 literal typing"
  (check-equal? (tc:infer ctx-empty (expr-posit16 0))
                (expr-Posit16)
                "posit16(0) : Posit16")
  (check-equal? (tc:infer ctx-empty (expr-posit16 16384))
                (expr-Posit16)
                "posit16(16384) [one] : Posit16")
  (check-equal? (tc:infer ctx-empty (expr-posit16 32768))
                (expr-Posit16)
                "posit16(32768) [NaR] : Posit16")
  (check-equal? (tc:infer ctx-empty (expr-posit16 65535))
                (expr-Posit16)
                "posit16(65535) : Posit16")
  ;; Check mode
  (check-true (tc:check ctx-empty (expr-posit16 16384) (expr-Posit16))
              "check posit16(16384) : Posit16")
  ;; Invalid literal
  (check-equal? (tc:infer ctx-empty (expr-posit16 65536))
                (expr-error)
                "posit16(65536) is out of range"))

;; ========================================
;; Core AST: Arithmetic reduction
;; ========================================

(test-case "posit16 arithmetic reduction"
  ;; 1 + 1 = 2 (16384 + 16384 = 18432)
  (check-equal? (whnf (expr-p16-add (expr-posit16 16384) (expr-posit16 16384)))
                (expr-posit16 18432)
                "p16+(1,1) = 2")
  ;; 1 * 2 = 2
  (check-equal? (whnf (expr-p16-mul (expr-posit16 16384) (expr-posit16 18432)))
                (expr-posit16 18432)
                "p16*(1,2) = 2")
  ;; 2 - 1 = 1
  (check-equal? (whnf (expr-p16-sub (expr-posit16 18432) (expr-posit16 16384)))
                (expr-posit16 16384)
                "p16-(2,1) = 1")
  ;; 2 / 1 = 2
  (check-equal? (whnf (expr-p16-div (expr-posit16 18432) (expr-posit16 16384)))
                (expr-posit16 18432)
                "p16/(2,1) = 2")
  ;; NaR propagation
  (check-equal? (whnf (expr-p16-add (expr-posit16 32768) (expr-posit16 16384)))
                (expr-posit16 32768)
                "NaR + 1 = NaR")
  ;; 0/0 = NaR
  (check-equal? (whnf (expr-p16-div (expr-posit16 0) (expr-posit16 0)))
                (expr-posit16 32768)
                "0/0 = NaR"))

(test-case "posit16 unary reduction"
  ;; neg(1) = -1
  (check-equal? (whnf (expr-p16-neg (expr-posit16 16384)))
                (expr-posit16 49152)
                "neg(1) = -1")
  ;; abs(-1) = 1
  (check-equal? (whnf (expr-p16-abs (expr-posit16 49152)))
                (expr-posit16 16384)
                "abs(-1) = 1")
  ;; neg(NaR) = NaR
  (check-equal? (whnf (expr-p16-neg (expr-posit16 32768)))
                (expr-posit16 32768)
                "neg(NaR) = NaR"))

;; ========================================
;; Core AST: Comparison reduction
;; ========================================

(test-case "posit16 comparison reduction"
  (check-equal? (whnf (expr-p16-lt (expr-posit16 16384) (expr-posit16 18432)))
                (expr-true)
                "1 < 2")
  (check-equal? (whnf (expr-p16-lt (expr-posit16 18432) (expr-posit16 16384)))
                (expr-false)
                "not 2 < 1")
  (check-equal? (whnf (expr-p16-le (expr-posit16 16384) (expr-posit16 16384)))
                (expr-true)
                "1 <= 1")
  (check-equal? (whnf (expr-p16-lt (expr-posit16 32768) (expr-posit16 16384)))
                (expr-false)
                "NaR not < 1"))

;; ========================================
;; Core AST: Conversion
;; ========================================

(test-case "posit16 from-nat conversion"
  (check-equal? (whnf (expr-p16-from-nat (expr-zero)))
                (expr-posit16 0)
                "from-nat(0) = posit16(0)")
  (check-equal? (whnf (expr-p16-from-nat (expr-suc (expr-zero))))
                (expr-posit16 16384)
                "from-nat(1) = posit16(16384)")
  (check-equal? (whnf (expr-p16-from-nat (expr-suc (expr-suc (expr-zero)))))
                (expr-posit16 18432)
                "from-nat(2) = posit16(18432)"))

;; ========================================
;; Core AST: p16-if-nar eliminator
;; ========================================

(test-case "posit16 if-nar eliminator"
  (check-equal? (whnf (expr-p16-if-nar (expr-Nat) (expr-zero) (expr-suc (expr-zero)) (expr-posit16 32768)))
                (expr-zero)
                "if-nar on NaR -> nar-case")
  (check-equal? (whnf (expr-p16-if-nar (expr-Nat) (expr-zero) (expr-suc (expr-zero)) (expr-posit16 16384)))
                (expr-nat-val 1)
                "if-nar on non-NaR -> normal-case"))

;; ========================================
;; Core AST: Type checking
;; ========================================

(test-case "posit16 operation typing"
  (check-equal? (tc:infer ctx-empty (expr-p16-add (expr-posit16 16384) (expr-posit16 16384)))
                (expr-Posit16)
                "p16-add infers Posit16")
  (check-equal? (tc:infer ctx-empty (expr-p16-lt (expr-posit16 16384) (expr-posit16 18432)))
                (expr-Bool)
                "p16-lt infers Bool")
  (check-equal? (tc:infer ctx-empty (expr-p16-from-nat (expr-zero)))
                (expr-Posit16)
                "p16-from-nat infers Posit16")
  (check-equal? (tc:infer ctx-empty (expr-p16-add (expr-true) (expr-posit16 16384)))
                (expr-error)
                "p16-add rejects non-Posit16 args"))

;; ========================================
;; Core AST: Substitution
;; ========================================

(test-case "posit16 substitution"
  (check-equal? (shift 1 0 (expr-p16-add (expr-bvar 0) (expr-posit16 16384)))
                (expr-p16-add (expr-bvar 1) (expr-posit16 16384))
                "shift increases bvar in p16-add")
  (check-equal? (subst 0 (expr-posit16 16384) (expr-p16-add (expr-bvar 0) (expr-posit16 18432)))
                (expr-p16-add (expr-posit16 16384) (expr-posit16 18432))
                "subst replaces bvar in p16-add")
  (check-equal? (shift 1 0 (expr-Posit16)) (expr-Posit16) "Posit16 type is stable under shift")
  (check-equal? (shift 1 0 (expr-posit16 42)) (expr-posit16 42) "posit16 literal is stable under shift"))

;; ========================================
;; Core AST: Pretty-printing
;; ========================================

(test-case "posit16 pretty-printing"
  (check-equal? (pp-expr (expr-Posit16) '()) "Posit16" "pp Posit16")
  (check-equal? (pp-expr (expr-posit16 16384) '()) "[posit16 16384]" "pp posit16(16384)")
  (check-equal? (pp-expr (expr-p16-add (expr-posit16 16384) (expr-posit16 18432)) '())
                "[p16+ [posit16 16384] [posit16 18432]]" "pp p16+"))

;; ========================================
;; Surface syntax: End-to-end via process-string
;; ========================================

(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string s)))

(test-case "posit16 surface: eval literal"
  (check-equal? (run "(eval (posit16 16384))")
                '("[posit16 16384] : Posit16")))

(test-case "posit16 surface: arithmetic 1+1=2"
  (check-equal? (run "(eval (p16+ (posit16 16384) (posit16 16384)))")
                '("[posit16 18432] : Posit16")))

(test-case "posit16 surface: check type"
  (check-equal? (run "(check (posit16 16384) <Posit16>)")
                '("OK")))

(test-case "posit16 surface: Posit16 type formation"
  (check-equal? (run "(check Posit16 <(Type 0)>)")
                '("OK")))

(test-case "posit16 surface: def + eval"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (let ([result (process-string "(def one <Posit16> (posit16 16384))\n(eval one)")])
      (check-equal? (length result) 2)
      (check-true (string-contains? (car result) "one : Posit16 defined"))
      (check-equal? (cadr result) "[posit16 16384] : Posit16"))))

(test-case "posit16 surface: negation"
  (check-equal? (run "(eval (p16-neg (posit16 16384)))")
                '("[posit16 49152] : Posit16")))

(test-case "posit16 surface: comparison"
  (check-equal? (run "(eval (p16-lt (posit16 16384) (posit16 18432)))")
                '("true : Bool")))

(test-case "posit16 surface: from-nat"
  (check-equal? (run "(eval (p16-from-nat (suc (suc zero))))")
                '("[posit16 18432] : Posit16")))

(test-case "posit16 surface: if-nar on NaR"
  (check-equal? (run "(eval (p16-if-nar Nat zero (suc zero) (posit16 32768)))")
                '("0N : Nat")))

(test-case "posit16 surface: if-nar on non-NaR"
  (check-equal? (run "(eval (p16-if-nar Nat zero (suc zero) (posit16 16384)))")
                '("1N : Nat")))

(test-case "posit16 surface: NaR propagation"
  (check-equal? (run "(eval (p16+ (posit16 32768) (posit16 16384)))")
                '("[posit16 32768] : Posit16")))

(test-case "posit16 surface: division by zero -> NaR"
  (check-equal? (run "(eval (p16/ (posit16 16384) (posit16 0)))")
                '("[posit16 32768] : Posit16")))

(test-case "posit16 surface: defn with Posit16"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (let ([result (process-string "(defn p16-double [x <Posit16>] <Posit16>\n  (p16+ x x))\n(eval (p16-double (posit16 16384)))")])
      (check-equal? (length result) 2)
      (check-equal? (cadr result) "[posit16 18432] : Posit16"))))
