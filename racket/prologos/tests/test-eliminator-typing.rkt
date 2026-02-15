#lang racket/base

;;;
;;; Tests for eliminator typing soundness — Phase A of code audit
;;;
;;; Covers: natrec step type checking, boolrec argument validation,
;;;         J eliminator base type checking.
;;;
;;; Both positive (well-typed) and negative (ill-typed) tests.
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../qtt.rkt")

;; ========================================
;; Shared definitions
;; ========================================

;; Constant motive for natrec: (fn [_ : Nat] Nat) : Nat -> Type(0)
(define nat-motive
  (expr-ann (expr-lam 'mw (expr-Nat) (expr-Nat))
            (expr-Pi 'mw (expr-Nat) (expr-Type (lzero)))))

;; Correct step function: (fn [k : Nat] (fn [r : Nat] (suc r)))
;; Type: Pi(Nat, Pi(Nat, Nat)) = Pi(n:Nat). motive(n) -> motive(suc(n))
(define nat-step-correct
  (expr-ann (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0))))
            (expr-Pi 'mw (expr-Nat) (expr-Pi 'mw (expr-Nat) (expr-Nat)))))

;; Constant motive for boolrec: (fn [_ : Bool] Nat) : Bool -> Type(0)
(define bool-motive
  (expr-ann (expr-lam 'mw (expr-Bool) (expr-Nat))
            (expr-Pi 'mw (expr-Bool) (expr-Type (lzero)))))

;; J motive: (fn [a : Nat] (fn [b : Nat] (fn [_ : Eq(Nat, a, b)] Nat)))
;; Type: Pi(Nat, Pi(Nat, Pi(Eq(Nat, bvar(1), bvar(0)), Type(0))))
(define j-motive
  (expr-ann
   (expr-lam 'mw (expr-Nat)
     (expr-lam 'mw (expr-Nat)
       (expr-lam 'mw (expr-Eq (expr-Nat) (expr-bvar 1) (expr-bvar 0))
         (expr-Nat))))
   (expr-Pi 'mw (expr-Nat)
     (expr-Pi 'mw (expr-Nat)
       (expr-Pi 'mw (expr-Eq (expr-Nat) (expr-bvar 1) (expr-bvar 0))
         (expr-Type (lzero)))))))

;; Correct J base: (fn [a : Nat] zero) — Π(a:Nat). motive(a, a, refl) = Π(a:Nat). Nat
(define j-base-correct
  (expr-ann
   (expr-lam 'mw (expr-Nat) (expr-zero))
   (expr-Pi 'mw (expr-Nat)
     (expr-app (expr-app (expr-app
       j-motive (expr-bvar 0)) (expr-bvar 0)) (expr-refl)))))

;; Annotated refl proof: refl : Eq(Nat, zero, zero)
;; Bare refl can't synthesize a type, so J needs an annotated proof.
(define refl-zero
  (expr-ann (expr-refl) (expr-Eq (expr-Nat) (expr-zero) (expr-zero))))

;; ========================================
;; NATREC — Positive tests
;; ========================================

(test-case "natrec/positive: well-typed natrec infers correctly"
  ;; natrec(motive, zero, step, suc(zero)) should have type app(motive, suc(zero)) ≡ Nat
  (define result
    (tc:infer ctx-empty
      (expr-natrec nat-motive (expr-zero) nat-step-correct (expr-suc (expr-zero)))))
  (check-true (conv result (expr-Nat))))

(test-case "natrec/positive: well-typed natrec checks against Nat"
  (check-true
   (tc:check ctx-empty
     (expr-natrec nat-motive (expr-zero) nat-step-correct (expr-suc (expr-zero)))
     (expr-Nat))))

;; ========================================
;; NATREC — Negative tests (ill-typed step)
;; ========================================

(test-case "natrec/negative: step returns Bool instead of Nat — rejected"
  ;; Step: (fn [k : Nat] (fn [r : Nat] true))
  ;; This step returns Bool, but motive says Nat. Must be rejected.
  (define bad-step
    (expr-ann (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-true)))
              (expr-Pi 'mw (expr-Nat) (expr-Pi 'mw (expr-Nat) (expr-Bool)))))
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-natrec nat-motive (expr-zero) bad-step (expr-suc (expr-zero)))))))

(test-case "natrec/negative: step takes Bool input instead of Nat — rejected"
  ;; Step: (fn [k : Bool] (fn [r : Nat] (suc r)))
  ;; First arg should be Nat, not Bool.
  (define bad-step
    (expr-ann (expr-lam 'mw (expr-Bool) (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0))))
              (expr-Pi 'mw (expr-Bool) (expr-Pi 'mw (expr-Nat) (expr-Nat)))))
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-natrec nat-motive (expr-zero) bad-step (expr-suc (expr-zero)))))))

(test-case "natrec/negative: step is just a Nat constant, not a function — rejected"
  ;; Step: zero (not a function at all)
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-natrec nat-motive (expr-zero) (expr-zero) (expr-suc (expr-zero)))))))

(test-case "natrec/negative: step takes wrong number of args (1-arg instead of 2) — rejected"
  ;; Step: (fn [k : Nat] (suc k)) — only 1 arg, should be 2
  (define bad-step
    (expr-ann (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0)))
              (expr-Pi 'mw (expr-Nat) (expr-Nat))))
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-natrec nat-motive (expr-zero) bad-step (expr-suc (expr-zero)))))))

(test-case "natrec/negative: wrong base type (Bool instead of motive(zero) = Nat)"
  ;; base should be Nat (= motive(zero)), but we pass true : Bool
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-natrec nat-motive (expr-true) nat-step-correct (expr-suc (expr-zero)))))))

(test-case "natrec/negative: wrong target type (Bool instead of Nat)"
  ;; target should be Nat, but we pass true : Bool
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-natrec nat-motive (expr-zero) nat-step-correct (expr-true))))))

;; ========================================
;; BOOLREC — Positive tests
;; ========================================

(test-case "boolrec/positive: well-typed boolrec infers correctly"
  (define result
    (tc:infer ctx-empty
      (expr-boolrec bool-motive (expr-zero) (expr-suc (expr-zero)) (expr-true))))
  (check-true (conv result (expr-Nat))))

(test-case "boolrec/positive: well-typed boolrec checks against Nat"
  (check-true
   (tc:check ctx-empty
     (expr-boolrec bool-motive (expr-zero) (expr-suc (expr-zero)) (expr-true))
     (expr-Nat))))

;; ========================================
;; BOOLREC — Negative tests
;; ========================================

(test-case "boolrec/negative: true-case has wrong type (Bool instead of Nat)"
  ;; motive says result is Nat, but true-case is true : Bool
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-boolrec bool-motive (expr-true) (expr-suc (expr-zero)) (expr-true))))))

(test-case "boolrec/negative: false-case has wrong type (Bool instead of Nat)"
  ;; motive says result is Nat, but false-case is false : Bool
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-boolrec bool-motive (expr-zero) (expr-false) (expr-true))))))

(test-case "boolrec/negative: target is Nat instead of Bool"
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-boolrec bool-motive (expr-zero) (expr-suc (expr-zero)) (expr-zero))))))

(test-case "boolrec/negative: motive domain is Nat instead of Bool"
  ;; Motive: (fn [_ : Nat] Nat) — domain should be Bool, not Nat
  (define bad-motive
    (expr-ann (expr-lam 'mw (expr-Nat) (expr-Nat))
              (expr-Pi 'mw (expr-Nat) (expr-Type (lzero)))))
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-boolrec bad-motive (expr-zero) (expr-suc (expr-zero)) (expr-true))))))

(test-case "boolrec/negative: motive is not a function"
  ;; Motive: Nat (not a function at all)
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-boolrec (expr-Nat) (expr-zero) (expr-suc (expr-zero)) (expr-true))))))

;; ========================================
;; J ELIMINATOR — Positive tests
;; ========================================

(test-case "J/positive: well-typed J infers correctly"
  ;; J(motive, base, zero, zero, refl) : motive(zero, zero, refl) ≡ Nat
  (define result
    (tc:infer ctx-empty
      (expr-J j-motive j-base-correct (expr-zero) (expr-zero) refl-zero)))
  (check-true (conv result (expr-Nat))))

(test-case "J/positive: well-typed J checks against Nat"
  (check-true
   (tc:check ctx-empty
     (expr-J j-motive j-base-correct (expr-zero) (expr-zero) refl-zero)
     (expr-Nat))))

;; ========================================
;; J ELIMINATOR — Negative tests
;; ========================================

(test-case "J/negative: proof is not an Eq type — rejected"
  ;; proof = zero : Nat, not an Eq type
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-J j-motive j-base-correct (expr-zero) (expr-zero) (expr-zero))))))

(test-case "J/negative: left doesn't match proof's LHS — rejected"
  ;; proof = refl : Eq(Nat, zero, zero), but left = suc(zero)
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-J j-motive j-base-correct (expr-suc (expr-zero)) (expr-zero) refl-zero)))))

(test-case "J/negative: base has wrong type — rejected"
  ;; base should be Π(a:Nat). motive(a, a, refl) = Π(a:Nat). Nat
  ;; but we give a function returning Bool
  (define bad-base
    (expr-ann (expr-lam 'mw (expr-Nat) (expr-true))
              (expr-Pi 'mw (expr-Nat) (expr-Bool))))
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-J j-motive bad-base (expr-zero) (expr-zero) refl-zero)))))

(test-case "J/negative: base takes wrong input type — rejected"
  ;; base: (fn [x : Bool] zero) — should take Nat (the type from proof's Eq), not Bool
  (define bad-base
    (expr-ann (expr-lam 'mw (expr-Bool) (expr-zero))
              (expr-Pi 'mw (expr-Bool) (expr-Nat))))
  (check-true
   (expr-error?
    (tc:infer ctx-empty
      (expr-J j-motive bad-base (expr-zero) (expr-zero) refl-zero)))))

;; ========================================
;; QTT — natrec step type checking
;; ========================================

(test-case "QTT/natrec/positive: well-typed natrec succeeds with correct usage"
  (define result
    (inferQ ctx-empty
      (expr-natrec nat-motive (expr-zero) nat-step-correct (expr-suc (expr-zero)))))
  (check-true (tu? result))
  (check-true (conv (tu-type result) (expr-Nat))))

(test-case "QTT/natrec/negative: ill-typed step rejected"
  ;; Step returns Bool, not Nat
  (define bad-step
    (expr-ann (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-true)))
              (expr-Pi 'mw (expr-Nat) (expr-Pi 'mw (expr-Nat) (expr-Bool)))))
  (check-true
   (tu-error?
    (inferQ ctx-empty
      (expr-natrec nat-motive (expr-zero) bad-step (expr-suc (expr-zero)))))))

(test-case "QTT/natrec/negative: step is constant, not function"
  (check-true
   (tu-error?
    (inferQ ctx-empty
      (expr-natrec nat-motive (expr-zero) (expr-zero) (expr-suc (expr-zero)))))))

;; ========================================
;; QTT — J base type checking
;; ========================================

(test-case "QTT/J/positive: well-typed J succeeds"
  (define result
    (inferQ ctx-empty
      (expr-J j-motive j-base-correct (expr-zero) (expr-zero) refl-zero)))
  (check-true (tu? result))
  (check-true (conv (tu-type result) (expr-Nat))))

(test-case "QTT/J/negative: base has wrong type — rejected"
  (define bad-base
    (expr-ann (expr-lam 'mw (expr-Nat) (expr-true))
              (expr-Pi 'mw (expr-Nat) (expr-Bool))))
  (check-true
   (tu-error?
    (inferQ ctx-empty
      (expr-J j-motive bad-base (expr-zero) (expr-zero) refl-zero)))))
