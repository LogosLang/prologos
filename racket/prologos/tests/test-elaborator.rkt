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
         "../global-env.rkt"
         "../metavar-store.rkt"
         "../driver.rkt")

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
  (check-equal? (elab "zero") (expr-nat-val 0)))

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

(test-case "elab: 0 -> int 0"
  (check-equal? (elab "0") (expr-int 0)))

(test-case "elab: 3 -> int 3"
  (check-equal? (elab "3") (expr-int 3)))

(test-case "elab: (suc zero)"
  (check-equal? (elab "(suc zero)") (expr-nat-val 1)))

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

(test-case "elab: (fn (x : Nat) x) — identity"
  ;; x is bound at depth 0, used at depth 1, so index = 1 - 0 - 1 = 0
  ;; Sprint 7: omitted mult → mult-meta (not 'mw)
  (with-fresh-meta-env
    (let ([r (elab "(fn (x : Nat) x)")])
      (check-true (expr-lam? r))
      (check-true (mult-meta? (expr-lam-mult r)))
      (check-equal? (expr-lam-type r) (expr-Nat))
      (check-equal? (expr-lam-body r) (expr-bvar 0)))))

(test-case "elab: (fn (x : Nat) (suc x))"
  ;; Sprint 7: omitted mult → mult-meta
  (with-fresh-meta-env
    (let ([r (elab "(fn (x : Nat) (suc x))")])
      (check-true (expr-lam? r))
      (check-true (mult-meta? (expr-lam-mult r)))
      (check-equal? (expr-lam-type r) (expr-Nat))
      (check-equal? (expr-lam-body r) (expr-suc (expr-bvar 0))))))

(test-case "elab: (fn (x : Nat) (fn (y : Nat) x)) — outer variable"
  ;; x bound at depth 0, y bound at depth 1
  ;; x used at depth 2: index = 2 - 0 - 1 = 1
  ;; Sprint 7: omitted mult → mult-meta
  (with-fresh-meta-env
    (let ([r (elab "(fn (x : Nat) (fn (y : Nat) x))")])
      (check-true (expr-lam? r))
      (check-true (mult-meta? (expr-lam-mult r)))
      (let ([inner (expr-lam-body r)])
        (check-true (expr-lam? inner))
        (check-true (mult-meta? (expr-lam-mult inner)))
        (check-equal? (expr-lam-body inner) (expr-bvar 1))))))

(test-case "elab: (fn (x : Nat) (fn (y : Nat) y)) — inner variable"
  ;; y bound at depth 1, used at depth 2: index = 2 - 1 - 1 = 0
  ;; Sprint 7: omitted mult → mult-meta
  (with-fresh-meta-env
    (let ([r (elab "(fn (x : Nat) (fn (y : Nat) y))")])
      (check-true (expr-lam? r))
      (check-true (mult-meta? (expr-lam-mult r)))
      (let ([inner (expr-lam-body r)])
        (check-true (expr-lam? inner))
        (check-true (mult-meta? (expr-lam-mult inner)))
        (check-equal? (expr-lam-body inner) (expr-bvar 0))))))

(test-case "elab: linear lambda"
  (check-equal? (elab "(fn (x :1 Nat) x)")
                (expr-lam 'm1 (expr-Nat) (expr-bvar 0))))

(test-case "elab: erased lambda"
  (check-equal? (elab "(fn (x :0 Nat) zero)")
                (expr-lam 'm0 (expr-Nat) (expr-nat-val 0))))

;; ========================================
;; Pi — de Bruijn indices
;; ========================================

(test-case "elab: (Pi (x : Nat) Nat) — dependent Pi"
  ;; Sprint 7: omitted mult → mult-meta
  (with-fresh-meta-env
    (let ([r (elab "(Pi (x : Nat) Nat)")])
      (check-true (expr-Pi? r))
      (check-true (mult-meta? (expr-Pi-mult r)))
      (check-equal? (expr-Pi-domain r) (expr-Nat))
      (check-equal? (expr-Pi-codomain r) (expr-Nat)))))

(test-case "elab: (Pi (n : Nat) (Vec Nat n)) — dependent with use"
  ;; n bound at depth 0, used at depth 1: index 0
  ;; Sprint 7: omitted mult → mult-meta
  (with-fresh-meta-env
    (let ([r (elab "(Pi (n : Nat) (Vec Nat n))")])
      (check-true (expr-Pi? r))
      (check-true (mult-meta? (expr-Pi-mult r)))
      (check-equal? (expr-Pi-domain r) (expr-Nat))
      (check-equal? (expr-Pi-codomain r) (expr-Vec (expr-Nat) (expr-bvar 0))))))

(test-case "elab: (Pi (A :0 (Type 0)) (-> A A)) — polymorphic identity type"
  (check-equal? (elab "(Pi (A :0 (Type 0)) (-> A A))")
                (expr-Pi 'm0 (expr-Type (lzero))
                         (expr-Pi 'mw (expr-bvar 0) (expr-bvar 1)))))

;; ========================================
;; Sigma
;; ========================================

(test-case "elab: (Sigma (x : Nat) (Eq Nat x zero))"
  (check-equal? (elab "(Sigma (x : Nat) (Eq Nat x zero))")
                (expr-Sigma (expr-Nat) (expr-Eq (expr-Nat) (expr-bvar 0) (expr-nat-val 0)))))

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
  (check-equal? (elab "(pair zero refl)") (expr-pair (expr-nat-val 0) (expr-refl))))

(test-case "elab: (fst (pair zero refl))"
  (check-equal? (elab "(fst (pair zero refl))") (expr-fst (expr-pair (expr-nat-val 0) (expr-refl)))))

(test-case "elab: (snd (pair zero refl))"
  (check-equal? (elab "(snd (pair zero refl))") (expr-snd (expr-pair (expr-nat-val 0) (expr-refl)))))

;; ========================================
;; Annotation
;; ========================================

(test-case "elab: (the Nat zero)"
  (check-equal? (elab "(the Nat zero)") (expr-ann (expr-nat-val 0) (expr-Nat))))

;; ========================================
;; Eq
;; ========================================

(test-case "elab: (Eq Nat zero zero)"
  (check-equal? (elab "(Eq Nat zero zero)") (expr-Eq (expr-Nat) (expr-nat-val 0) (expr-nat-val 0))))

;; ========================================
;; Vec/Fin
;; ========================================

(test-case "elab: (Vec Nat (suc zero))"
  (check-equal? (elab "(Vec Nat (suc zero))") (expr-Vec (expr-Nat) (expr-nat-val 1))))

(test-case "elab: (vnil Nat)"
  (check-equal? (elab "(vnil Nat)") (expr-vnil (expr-Nat))))

(test-case "elab: (Fin (suc zero))"
  (check-equal? (elab "(Fin (suc zero))") (expr-Fin (expr-nat-val 1))))

;; ========================================
;; Shadowing
;; ========================================

(test-case "elab: shadowing — (fn (x : Nat) (fn (x : Bool) x)) refers to inner x"
  ;; Inner x at depth 1, used at depth 2: index = 0
  ;; Sprint 7: omitted mult → mult-meta
  (with-fresh-meta-env
    (let ([r (elab "(fn (x : Nat) (fn (x : Bool) x))")])
      (check-true (expr-lam? r))
      (check-true (mult-meta? (expr-lam-mult r)))
      (check-equal? (expr-lam-type r) (expr-Nat))
      (let ([inner (expr-lam-body r)])
        (check-true (expr-lam? inner))
        (check-true (mult-meta? (expr-lam-mult inner)))
        (check-equal? (expr-lam-type inner) (expr-Bool))
        (check-equal? (expr-lam-body inner) (expr-bvar 0))))))

;; ========================================
;; Error cases
;; ========================================

(test-case "elab: unbound variable"
  (check-true (prologos-error? (elab "undefined_var"))))

(test-case "elab: unbound in body"
  (with-fresh-meta-env
    (check-true (prologos-error? (elab "(fn (x : Nat) y)")))))

;; ========================================
;; Top-level elaboration
;; ========================================

(test-case "elab-top: def"
  (with-fresh-meta-env
    (let ([result (elaborate-top-level
                   (parse-string "(def myid : (-> Nat Nat) (fn (x : Nat) x))"))])
      (check-false (prologos-error? result))
      (check-equal? (car result) 'def)
      (check-equal? (cadr result) 'myid)
      ;; Arrow desugars with 'mw (not mult-meta), so Pi mult is concrete
      (check-equal? (caddr result) (expr-Pi 'mw (expr-Nat) (expr-Nat)))
      ;; Sprint 7: lambda's omitted mult → mult-meta
      (let ([body (cadddr result)])
        (check-true (expr-lam? body))
        (check-true (mult-meta? (expr-lam-mult body)))
        (check-equal? (expr-lam-type body) (expr-Nat))
        (check-equal? (expr-lam-body body) (expr-bvar 0))))))

(test-case "elab-top: check"
  (let ([result (elaborate-top-level
                 (parse-string "(check zero : Nat)"))])
    (check-false (prologos-error? result))
    (check-equal? (car result) 'check)
    (check-equal? (cadr result) (expr-nat-val 0))
    (check-equal? (caddr result) (expr-Nat))))

(test-case "elab-top: eval"
  (let ([result (elaborate-top-level
                 (parse-string "(eval (suc zero))"))])
    (check-false (prologos-error? result))
    (check-equal? (car result) 'eval)
    (check-equal? (cadr result) (expr-nat-val 1))))

(test-case "elab-top: infer"
  (let ([result (elaborate-top-level
                 (parse-string "(infer zero)"))])
    (check-false (prologos-error? result))
    (check-equal? (car result) 'infer)
    (check-equal? (cadr result) (expr-nat-val 0))))
