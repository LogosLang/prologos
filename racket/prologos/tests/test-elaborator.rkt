#lang racket/base

;;;
;;; Tests for elaborator.rkt
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../errors.rkt"
         "../global-env.rkt")

;; Helper: parse and elaborate from string
(define (elab s)
  (let ([surf (parse-string s)])
    (if (prologos-error? surf)
        surf
        (elaborate surf))))

;; ========================================
;; Constants
;; ========================================

(test-case "elab: zero"
  (check-equal? (elab "zero") (expr-zero)))

(test-case "elab: Nat"
  (check-equal? (elab "Nat") (expr-Nat)))

(test-case "elab: Bool"
  (check-equal? (elab "Bool") (expr-Bool)))

(test-case "elab: true"
  (check-equal? (elab "true") (expr-true)))

(test-case "elab: false"
  (check-equal? (elab "false") (expr-false)))

(test-case "elab: refl"
  (check-equal? (elab "refl") (expr-refl)))

(test-case "elab: (Type 0)"
  (check-equal? (elab "(Type 0)") (expr-Type (lzero))))

(test-case "elab: (Type 1)"
  (check-equal? (elab "(Type 1)") (expr-Type (lsuc (lzero)))))

;; ========================================
;; Numeric literals
;; ========================================

(test-case "elab: 0 -> zero"
  (check-equal? (elab "0") (expr-zero)))

(test-case "elab: 3 -> suc(suc(suc(zero)))"
  (check-equal? (elab "3") (nat->expr 3)))

(test-case "elab: (suc zero)"
  (check-equal? (elab "(suc zero)") (expr-suc (expr-zero))))

;; ========================================
;; Arrow (non-dependent)
;; ========================================

(test-case "elab: (-> Nat Nat)"
  (check-equal? (elab "(-> Nat Nat)") (expr-Pi 'mw (expr-Nat) (expr-Nat))))

(test-case "elab: (-> Nat Bool)"
  (check-equal? (elab "(-> Nat Bool)") (expr-Pi 'mw (expr-Nat) (expr-Bool))))

;; ========================================
;; Lambda — de Bruijn indices
;; ========================================

(test-case "elab: (lam (x : Nat) x) — identity"
  ;; x is bound at depth 0, used at depth 1, so index = 1 - 0 - 1 = 0
  (check-equal? (elab "(lam (x : Nat) x)")
                (expr-lam 'mw (expr-Nat) (expr-bvar 0))))

(test-case "elab: (lam (x : Nat) (suc x))"
  (check-equal? (elab "(lam (x : Nat) (suc x))")
                (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0)))))

(test-case "elab: (lam (x : Nat) (lam (y : Nat) x)) — outer variable"
  ;; x bound at depth 0, y bound at depth 1
  ;; x used at depth 2: index = 2 - 0 - 1 = 1
  (check-equal? (elab "(lam (x : Nat) (lam (y : Nat) x))")
                (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-bvar 1)))))

(test-case "elab: (lam (x : Nat) (lam (y : Nat) y)) — inner variable"
  ;; y bound at depth 1, used at depth 2: index = 2 - 1 - 1 = 0
  (check-equal? (elab "(lam (x : Nat) (lam (y : Nat) y))")
                (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-bvar 0)))))

(test-case "elab: linear lambda"
  (check-equal? (elab "(lam (x :1 Nat) x)")
                (expr-lam 'm1 (expr-Nat) (expr-bvar 0))))

(test-case "elab: erased lambda"
  (check-equal? (elab "(lam (x :0 Nat) zero)")
                (expr-lam 'm0 (expr-Nat) (expr-zero))))

;; ========================================
;; Pi — de Bruijn indices
;; ========================================

(test-case "elab: (Pi (x : Nat) Nat) — dependent Pi"
  (check-equal? (elab "(Pi (x : Nat) Nat)")
                (expr-Pi 'mw (expr-Nat) (expr-Nat))))

(test-case "elab: (Pi (n : Nat) (Vec Nat n)) — dependent with use"
  ;; n bound at depth 0, used at depth 1: index 0
  (check-equal? (elab "(Pi (n : Nat) (Vec Nat n))")
                (expr-Pi 'mw (expr-Nat) (expr-Vec (expr-Nat) (expr-bvar 0)))))

(test-case "elab: (Pi (A :0 (Type 0)) (-> A A)) — polymorphic identity type"
  (check-equal? (elab "(Pi (A :0 (Type 0)) (-> A A))")
                (expr-Pi 'm0 (expr-Type (lzero))
                         (expr-Pi 'mw (expr-bvar 0) (expr-bvar 1)))))

;; ========================================
;; Sigma
;; ========================================

(test-case "elab: (Sigma (x : Nat) (Eq Nat x zero))"
  (check-equal? (elab "(Sigma (x : Nat) (Eq Nat x zero))")
                (expr-Sigma (expr-Nat) (expr-Eq (expr-Nat) (expr-bvar 0) (expr-zero)))))

;; ========================================
;; Application
;; ========================================

(test-case "elab: (f x) — single arg with globals"
  (parameterize ([current-global-env
                  (global-env-add (global-env-add (hasheq)
                                   'f (expr-Pi 'mw (expr-Nat) (expr-Nat)) (expr-lam 'mw (expr-Nat) (expr-bvar 0)))
                                   'x (expr-Nat) (expr-zero))])
    (check-equal? (elab "(f x)")
                  (expr-app (expr-fvar 'f) (expr-fvar 'x)))))

(test-case "elab: multi-arg app (f a b) -> app(app(fvar f, fvar a), fvar b)"
  (parameterize ([current-global-env
                  (global-env-add
                   (global-env-add
                    (global-env-add (hasheq)
                                    'f (expr-Nat) (expr-zero))
                    'a (expr-Nat) (expr-zero))
                   'b (expr-Nat) (expr-zero))])
    (check-equal? (elab "(f a b)")
                  (expr-app (expr-app (expr-fvar 'f) (expr-fvar 'a)) (expr-fvar 'b)))))

;; ========================================
;; Pair, fst, snd
;; ========================================

(test-case "elab: (pair zero refl)"
  (check-equal? (elab "(pair zero refl)") (expr-pair (expr-zero) (expr-refl))))

(test-case "elab: (fst (pair zero refl))"
  (check-equal? (elab "(fst (pair zero refl))") (expr-fst (expr-pair (expr-zero) (expr-refl)))))

(test-case "elab: (snd (pair zero refl))"
  (check-equal? (elab "(snd (pair zero refl))") (expr-snd (expr-pair (expr-zero) (expr-refl)))))

;; ========================================
;; Annotation
;; ========================================

(test-case "elab: (the Nat zero)"
  (check-equal? (elab "(the Nat zero)") (expr-ann (expr-zero) (expr-Nat))))

;; ========================================
;; Eq
;; ========================================

(test-case "elab: (Eq Nat zero zero)"
  (check-equal? (elab "(Eq Nat zero zero)") (expr-Eq (expr-Nat) (expr-zero) (expr-zero))))

;; ========================================
;; Vec/Fin
;; ========================================

(test-case "elab: (Vec Nat (suc zero))"
  (check-equal? (elab "(Vec Nat (suc zero))") (expr-Vec (expr-Nat) (expr-suc (expr-zero)))))

(test-case "elab: (vnil Nat)"
  (check-equal? (elab "(vnil Nat)") (expr-vnil (expr-Nat))))

(test-case "elab: (Fin (suc zero))"
  (check-equal? (elab "(Fin (suc zero))") (expr-Fin (expr-suc (expr-zero)))))

;; ========================================
;; Shadowing
;; ========================================

(test-case "elab: shadowing — (lam (x : Nat) (lam (x : Bool) x)) refers to inner x"
  ;; Inner x at depth 1, used at depth 2: index = 0
  (check-equal? (elab "(lam (x : Nat) (lam (x : Bool) x))")
                (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Bool) (expr-bvar 0)))))

;; ========================================
;; Error cases
;; ========================================

(test-case "elab: unbound variable"
  (check-true (prologos-error? (elab "undefined_var"))))

(test-case "elab: unbound in body"
  (check-true (prologos-error? (elab "(lam (x : Nat) y)"))))

;; ========================================
;; Top-level elaboration
;; ========================================

(test-case "elab-top: def"
  (let ([result (elaborate-top-level
                 (parse-string "(def myid : (-> Nat Nat) (lam (x : Nat) x))"))])
    (check-false (prologos-error? result))
    (check-equal? (car result) 'def)
    (check-equal? (cadr result) 'myid)
    (check-equal? (caddr result) (expr-Pi 'mw (expr-Nat) (expr-Nat)))
    (check-equal? (cadddr result) (expr-lam 'mw (expr-Nat) (expr-bvar 0)))))

(test-case "elab-top: check"
  (let ([result (elaborate-top-level
                 (parse-string "(check zero : Nat)"))])
    (check-false (prologos-error? result))
    (check-equal? (car result) 'check)
    (check-equal? (cadr result) (expr-zero))
    (check-equal? (caddr result) (expr-Nat))))

(test-case "elab-top: eval"
  (let ([result (elaborate-top-level
                 (parse-string "(eval (suc zero))"))])
    (check-false (prologos-error? result))
    (check-equal? (car result) 'eval)
    (check-equal? (cadr result) (expr-suc (expr-zero)))))

(test-case "elab-top: infer"
  (let ([result (elaborate-top-level
                 (parse-string "(infer zero)"))])
    (check-false (prologos-error? result))
    (check-equal? (car result) 'infer)
    (check-equal? (cadr result) (expr-zero))))
