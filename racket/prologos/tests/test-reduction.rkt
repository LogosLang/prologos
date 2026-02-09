#lang racket/base

;;;
;;; Tests for reduction.rkt — Port of test-0c.maude
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../substitution.rkt"
         "../reduction.rkt")

;; ========================================
;; WHNF tests
;; ========================================

(test-case "whnf: beta reduction (lam x:Nat. x) zero -> zero"
  (check-equal? (whnf (expr-app (expr-lam 'mw (expr-Nat) (expr-bvar 0)) (expr-zero)))
                (expr-zero)))

(test-case "whnf: beta (lam x:Nat. suc x) zero -> suc(zero)"
  (check-equal? (whnf (expr-app (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0))) (expr-zero)))
                (expr-suc (expr-zero))))

(test-case "whnf: nested beta (lam x. lam y. x) zero -> lam(mw, Nat, zero)"
  (check-equal? (whnf (expr-app (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-bvar 1))) (expr-zero)))
                (expr-lam 'mw (expr-Nat) (expr-zero))))

(test-case "whnf: fst(pair(zero, suc(zero))) -> zero"
  (check-equal? (whnf (expr-fst (expr-pair (expr-zero) (expr-suc (expr-zero)))))
                (expr-zero)))

(test-case "whnf: snd(pair(zero, suc(zero))) -> suc(zero)"
  (check-equal? (whnf (expr-snd (expr-pair (expr-zero) (expr-suc (expr-zero)))))
                (expr-suc (expr-zero))))

(test-case "whnf: annotation erasure ann(zero, Nat) -> zero"
  (check-equal? (whnf (expr-ann (expr-zero) (expr-Nat)))
                (expr-zero)))

(test-case "whnf: non-reducible bvar(0)"
  (check-equal? (whnf (expr-bvar 0)) (expr-bvar 0)))

(test-case "whnf: non-reducible Pi(mw, Nat, Nat)"
  (check-equal? (whnf (expr-Pi 'mw (expr-Nat) (expr-Nat)))
                (expr-Pi 'mw (expr-Nat) (expr-Nat))))

;; ========================================
;; Natrec tests
;; ========================================

;; Motive: lam(mw, Nat, Nat) — for each n, the result type is Nat
;; Step: lam(mw, Nat, lam(mw, Nat, suc(bvar(0)))) — step(n, acc) = suc(acc)
(define test-motive (expr-lam 'mw (expr-Nat) (expr-Nat)))
(define test-step (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0)))))

(test-case "whnf: natrec with zero -> base"
  (check-equal? (whnf (expr-natrec test-motive (expr-zero) test-step (expr-zero)))
                (expr-zero)))

(test-case "whnf: natrec with suc(zero) -> suc(natrec(..., zero))"
  ;; whnf only reduces the outermost step; the inner natrec(M, zero, step, zero)
  ;; stays unreduced because whnf stops at constructors (suc is a constructor).
  ;; Verified against Maude: result is suc(natrec(M, zero, step, zero))
  (check-equal? (whnf (expr-natrec test-motive (expr-zero) test-step (expr-suc (expr-zero))))
                (expr-suc (expr-natrec test-motive (expr-zero) test-step (expr-zero)))))

(test-case "nf: natrec with suc(zero) -> suc(zero)"
  ;; Full normalization reduces the inner natrec too
  (check-equal? (nf (expr-natrec test-motive (expr-zero) test-step (expr-suc (expr-zero))))
                (expr-suc (expr-zero))))

(test-case "nf: natrec with suc(suc(zero)) -> suc(suc(zero))"
  (check-equal? (nf (expr-natrec test-motive (expr-zero) test-step (expr-suc (expr-suc (expr-zero)))))
                (expr-suc (expr-suc (expr-zero)))))

;; ========================================
;; J eliminator test
;; ========================================

(test-case "whnf: J(motive, base, zero, zero, refl) -> refl"
  ;; J(motive, lam(mw, Nat, refl), zero, zero, refl) -> app(lam(mw,Nat,refl), zero) -> refl
  (check-equal? (whnf (expr-J (expr-lam 'mw (expr-Nat)
                                (expr-lam 'mw (expr-Nat)
                                  (expr-lam 'mw (expr-Eq (expr-Nat) (expr-bvar 1) (expr-bvar 0)) (expr-Nat))))
                               (expr-lam 'mw (expr-Nat) (expr-refl))
                               (expr-zero) (expr-zero) (expr-refl)))
                (expr-refl)))

;; ========================================
;; Full normalization tests
;; ========================================

(test-case "nf: beta redex nested inside lambda"
  ;; lam(mw, Nat, app(lam(mw, Nat, bvar(0)), bvar(0))) -> lam(mw, Nat, bvar(0))
  (check-equal? (nf (expr-lam 'mw (expr-Nat) (expr-app (expr-lam 'mw (expr-Nat) (expr-bvar 0)) (expr-bvar 0))))
                (expr-lam 'mw (expr-Nat) (expr-bvar 0))))

(test-case "nf: normalize type Pi(mw, Nat, app(id, Nat)) -> Pi(mw, Nat, Nat)"
  ;; Pi(mw, Nat, app(lam(mw, Nat, bvar(0)), Nat)) -> Pi(mw, Nat, Nat)
  (check-equal? (nf (expr-Pi 'mw (expr-Nat) (expr-app (expr-lam 'mw (expr-Nat) (expr-bvar 0)) (expr-Nat))))
                (expr-Pi 'mw (expr-Nat) (expr-Nat))))

;; ========================================
;; Conversion tests
;; ========================================

(test-case "conv: same term"
  (check-true (conv (expr-zero) (expr-zero))))

(test-case "conv: different terms"
  (check-false (conv (expr-zero) (expr-suc (expr-zero)))))

(test-case "conv: beta-equal terms"
  ;; (lam x. x) zero === zero
  (check-true (conv (expr-app (expr-lam 'mw (expr-Nat) (expr-bvar 0)) (expr-zero))
                    (expr-zero))))

(test-case "conv: both reduce to suc(zero)"
  (check-true (conv (expr-app (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0))) (expr-zero))
                    (expr-suc (expr-zero)))))

(test-case "conv: type Pi(mw, Nat, app(id, Nat)) === Pi(mw, Nat, Nat)"
  (check-true (conv (expr-Pi 'mw (expr-Nat) (expr-app (expr-lam 'mw (expr-Nat) (expr-bvar 0)) (expr-Nat)))
                    (expr-Pi 'mw (expr-Nat) (expr-Nat)))))

;; ========================================
;; Vec reduction tests
;; ========================================

(test-case "whnf: vhead of vcons"
  ;; vhead(Nat, zero, vcons(Nat, zero, suc(zero), vnil(Nat))) -> suc(zero)
  (check-equal? (whnf (expr-vhead (expr-Nat) (expr-zero)
                        (expr-vcons (expr-Nat) (expr-zero) (expr-suc (expr-zero)) (expr-vnil (expr-Nat)))))
                (expr-suc (expr-zero))))

(test-case "whnf: vtail of vcons"
  ;; vtail(Nat, zero, vcons(Nat, zero, suc(zero), vnil(Nat))) -> vnil(Nat)
  (check-equal? (whnf (expr-vtail (expr-Nat) (expr-zero)
                        (expr-vcons (expr-Nat) (expr-zero) (expr-suc (expr-zero)) (expr-vnil (expr-Nat)))))
                (expr-vnil (expr-Nat))))

;; ========================================
;; Boolrec tests
;; ========================================

(define boolrec-motive (expr-lam 'mw (expr-Bool) (expr-Nat)))

(test-case "whnf: boolrec true -> true-case"
  (check-equal? (whnf (expr-boolrec boolrec-motive (expr-zero) (expr-suc (expr-zero)) (expr-true)))
                (expr-zero)))

(test-case "whnf: boolrec false -> false-case"
  (check-equal? (whnf (expr-boolrec boolrec-motive (expr-zero) (expr-suc (expr-zero)) (expr-false)))
                (expr-suc (expr-zero))))

(test-case "whnf: boolrec stuck on bvar"
  ;; When target is not a value, boolrec should not reduce
  (define result (whnf (expr-boolrec boolrec-motive (expr-zero) (expr-suc (expr-zero)) (expr-bvar 0))))
  (check-true (expr-boolrec? result)))

(test-case "nf: boolrec true normalizes all subexpressions"
  (check-equal? (nf (expr-boolrec boolrec-motive (expr-zero) (expr-suc (expr-zero)) (expr-true)))
                (expr-zero)))

(test-case "conv: boolrec true === true-case"
  (check-true (conv (expr-boolrec boolrec-motive (expr-zero) (expr-suc (expr-zero)) (expr-true))
                    (expr-zero))))
