#lang racket/base

;;;
;;; Tests for typing-core.rkt — Port of test-0d.maude
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt"))

;; ========================================
;; Universe typing
;; ========================================

(test-case "infer: Type(0) : Type(1)"
  (check-equal? (tc:infer ctx-empty (expr-Type (lzero)))
                (expr-Type (lsuc (lzero)))))

(test-case "infer: Type(1) : Type(2)"
  (check-equal? (tc:infer ctx-empty (expr-Type (lsuc (lzero))))
                (expr-Type (lsuc (lsuc (lzero))))))

;; ========================================
;; Nat typing
;; ========================================

(test-case "infer: Nat : Type(0)"
  (check-equal? (tc:infer ctx-empty (expr-Nat)) (expr-Type (lzero))))

(test-case "infer: zero : Nat"
  (check-equal? (tc:infer ctx-empty (expr-zero)) (expr-Nat)))

(test-case "infer: suc(zero) : Nat"
  (check-equal? (tc:infer ctx-empty (expr-suc (expr-zero))) (expr-Nat)))

(test-case "infer: suc(suc(zero)) : Nat"
  (check-equal? (tc:infer ctx-empty (expr-suc (expr-suc (expr-zero)))) (expr-Nat)))

(test-case "check: suc(zero) : Nat"
  (check-true (tc:check ctx-empty (expr-suc (expr-zero)) (expr-Nat))))

;; ========================================
;; Bool typing
;; ========================================

(test-case "infer: Bool : Type(0)"
  (check-equal? (tc:infer ctx-empty (expr-Bool)) (expr-Type (lzero))))

(test-case "infer: true : Bool"
  (check-equal? (tc:infer ctx-empty (expr-true)) (expr-Bool)))

;; ========================================
;; Pi type formation
;; ========================================

(test-case "isType: Nat -> Nat"
  (check-true (tc:is-type ctx-empty (expr-Pi 'mw (expr-Nat) (expr-Nat)))))

(test-case "isType: Pi(m0, Type(0), bvar(0)) — polymorphic identity type"
  (check-true (tc:is-type ctx-empty (expr-Pi 'm0 (expr-Type (lzero)) (expr-bvar 0)))))

;; ========================================
;; Lambda typing (check mode)
;; ========================================

(test-case "check: identity lam(mw, Nat, bvar(0)) : Nat -> Nat"
  (check-true (tc:check ctx-empty
                     (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                     (expr-Pi 'mw (expr-Nat) (expr-Nat)))))

(test-case "check: successor lam(mw, Nat, suc(bvar(0))) : Nat -> Nat"
  (check-true (tc:check ctx-empty
                     (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0)))
                     (expr-Pi 'mw (expr-Nat) (expr-Nat)))))

(test-case "check: constant lam(mw, Nat, zero) : Nat -> Nat"
  (check-true (tc:check ctx-empty
                     (expr-lam 'mw (expr-Nat) (expr-zero))
                     (expr-Pi 'mw (expr-Nat) (expr-Nat)))))

(test-case "NEGATIVE: lam(mw, Nat, bvar(0)) NOT : Nat -> Bool"
  (check-false (tc:check ctx-empty
                      (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                      (expr-Pi 'mw (expr-Nat) (expr-Bool)))))

;; ========================================
;; Application typing (synthesis)
;; ========================================

(test-case "infer: annotated (lam suc) applied to zero : Nat"
  (check-equal? (tc:infer ctx-empty
                       (expr-app (expr-ann (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0)))
                                           (expr-Pi 'mw (expr-Nat) (expr-Nat)))
                                 (expr-zero)))
                (expr-Nat)))

(test-case "infer: in context x:Nat, app of annotated identity to x"
  (check-equal? (tc:infer (ctx-extend ctx-empty (expr-Nat) 'mw)
                       (expr-app (expr-ann (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                                           (expr-Pi 'mw (expr-Nat) (expr-Nat)))
                                 (expr-bvar 0)))
                (expr-Nat)))

;; ========================================
;; Annotated terms
;; ========================================

(test-case "infer: ann(zero, Nat) -> Nat"
  (check-equal? (tc:infer ctx-empty (expr-ann (expr-zero) (expr-Nat))) (expr-Nat)))

(test-case "infer: ann(lam id, Pi(Nat,Nat)) -> Pi(Nat,Nat)"
  (check-equal? (tc:infer ctx-empty
                       (expr-ann (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                                 (expr-Pi 'mw (expr-Nat) (expr-Nat))))
                (expr-Pi 'mw (expr-Nat) (expr-Nat))))

;; ========================================
;; Sigma types
;; ========================================

(test-case "isType: Sigma(Nat, Nat)"
  (check-true (tc:is-type ctx-empty (expr-Sigma (expr-Nat) (expr-Nat)))))

(test-case "check: pair(zero, suc(zero)) : Sigma(Nat, Nat)"
  (check-true (tc:check ctx-empty
                     (expr-pair (expr-zero) (expr-suc (expr-zero)))
                     (expr-Sigma (expr-Nat) (expr-Nat)))))

(test-case "infer: fst of annotated pair -> Nat"
  (check-equal? (tc:infer ctx-empty
                       (expr-fst (expr-ann (expr-pair (expr-zero) (expr-suc (expr-zero)))
                                           (expr-Sigma (expr-Nat) (expr-Nat)))))
                (expr-Nat)))

(test-case "infer: snd of annotated pair -> Nat"
  (check-equal? (tc:infer ctx-empty
                       (expr-snd (expr-ann (expr-pair (expr-zero) (expr-suc (expr-zero)))
                                           (expr-Sigma (expr-Nat) (expr-Nat)))))
                (expr-Nat)))

;; ========================================
;; Dependent pair: (zero, refl) : Sigma(x:Nat, Eq(Nat, x, zero))
;; ========================================

(test-case "check: dependent pair (zero, refl) : Sigma(Nat, Eq(Nat, bvar(0), zero))"
  (check-true (tc:check ctx-empty
                     (expr-pair (expr-zero) (expr-refl))
                     (expr-Sigma (expr-Nat) (expr-Eq (expr-Nat) (expr-bvar 0) (expr-zero))))))

(test-case "NEGATIVE: pair(suc(zero), refl) : Sigma(Nat, Eq(Nat, bvar(0), zero))"
  (check-false (tc:check ctx-empty
                      (expr-pair (expr-suc (expr-zero)) (expr-refl))
                      (expr-Sigma (expr-Nat) (expr-Eq (expr-Nat) (expr-bvar 0) (expr-zero))))))

;; ========================================
;; Equality types
;; ========================================

(test-case "isType: Eq(Nat, zero, zero)"
  (check-true (tc:is-type ctx-empty (expr-Eq (expr-Nat) (expr-zero) (expr-zero)))))

(test-case "check: refl : Eq(Nat, zero, zero)"
  (check-true (tc:check ctx-empty (expr-refl) (expr-Eq (expr-Nat) (expr-zero) (expr-zero)))))

(test-case "NEGATIVE: refl : Eq(Nat, zero, suc(zero))"
  (check-false (tc:check ctx-empty (expr-refl) (expr-Eq (expr-Nat) (expr-zero) (expr-suc (expr-zero))))))

;; ========================================
;; Polymorphic identity function
;; ========================================

(test-case "check: polymorphic identity"
  ;; Type: Pi(m0, Type(0), Pi(mw, bvar(0), bvar(1)))
  ;; Term: lam(m0, Type(0), lam(mw, bvar(0), bvar(0)))
  (check-true (tc:check ctx-empty
                     (expr-lam 'm0 (expr-Type (lzero))
                               (expr-lam 'mw (expr-bvar 0) (expr-bvar 0)))
                     (expr-Pi 'm0 (expr-Type (lzero))
                              (expr-Pi 'mw (expr-bvar 0) (expr-bvar 1))))))

;; ========================================
;; Dependent application of polymorphic identity
;; ========================================

(define poly-id
  (expr-ann (expr-lam 'm0 (expr-Type (lzero))
                      (expr-lam 'mw (expr-bvar 0) (expr-bvar 0)))
            (expr-Pi 'm0 (expr-Type (lzero))
                     (expr-Pi 'mw (expr-bvar 0) (expr-bvar 1)))))

(test-case "infer: app(id, Nat) : Pi(mw, Nat, Nat)"
  (check-equal? (tc:infer ctx-empty (expr-app poly-id (expr-Nat)))
                (expr-Pi 'mw (expr-Nat) (expr-Nat))))

(test-case "infer: app(app(id, Nat), zero) : Nat"
  (check-equal? (tc:infer ctx-empty (expr-app (expr-app poly-id (expr-Nat)) (expr-zero)))
                (expr-Nat)))

;; ========================================
;; NEGATIVE tests
;; ========================================

(test-case "NEGATIVE: bare lambda cannot synthesize"
  (check-equal? (tc:infer ctx-empty (expr-lam 'mw (expr-Nat) (expr-bvar 0)))
                (expr-error)))

(test-case "NEGATIVE: zero is not a Bool"
  (check-false (tc:check ctx-empty (expr-zero) (expr-Bool))))

;; ========================================
;; Boolrec typing
;; ========================================

;; Motive: (fn (b : Bool) Nat) — constant motive
(define boolrec-motive
  (expr-ann
   (expr-lam 'mw (expr-Bool) (expr-Nat))
   (expr-Pi 'mw (expr-Bool) (expr-Type (lzero)))))

(test-case "infer: boolrec(motive, zero, (inc zero), true) : Nat"
  (define result
    (tc:infer ctx-empty
      (expr-boolrec boolrec-motive (expr-zero) (expr-suc (expr-zero)) (expr-true))))
  ;; Result is app(motive, true) which normalizes to Nat
  (check-true (conv result (expr-Nat))))

(test-case "infer: boolrec(motive, zero, (inc zero), false) : Nat"
  (define result
    (tc:infer ctx-empty
      (expr-boolrec boolrec-motive (expr-zero) (expr-suc (expr-zero)) (expr-false))))
  (check-true (conv result (expr-Nat))))

(test-case "check: boolrec(motive, zero, (inc zero), true) : Nat"
  (check-true
   (tc:check ctx-empty
     (expr-boolrec boolrec-motive (expr-zero) (expr-suc (expr-zero)) (expr-true))
     (expr-Nat))))

(test-case "NEGATIVE: boolrec with wrong true-case type"
  ;; true-case should be Nat (= motive(true)), but we provide true : Bool
  (check-false
   (tc:check ctx-empty
     (expr-boolrec boolrec-motive (expr-true) (expr-suc (expr-zero)) (expr-true))
     (expr-Nat))))
