#lang racket/base

;;;
;;; Tests for substitution.rkt — Port of test-0b.maude
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../substitution.rkt")

;; ========================================
;; Shift tests
;; ========================================

(test-case "shift: bvar(0) by 1 at cutoff 0 -> bvar(1)"
  (check-equal? (shift 1 0 (expr-bvar 0)) (expr-bvar 1)))

(test-case "shift: bvar(0) by 1 at cutoff 1 -> bvar(0) (below cutoff)"
  (check-equal? (shift 1 1 (expr-bvar 0)) (expr-bvar 0)))

(test-case "shift: bvar(2) by 1 at cutoff 0 -> bvar(3)"
  (check-equal? (shift 1 0 (expr-bvar 2)) (expr-bvar 3)))

(test-case "shift: free variable unchanged"
  (check-equal? (shift 1 0 (expr-fvar 'x)) (expr-fvar 'x)))

(test-case "shift: under lambda, bvar(0) in body (lambda's own binding) unchanged"
  (check-equal? (shift 1 0 (expr-lam 'mw (expr-Nat) (expr-bvar 0)))
                (expr-lam 'mw (expr-Nat) (expr-bvar 0))))

(test-case "shift: under lambda, bvar(1) in body (refers outside) shifted to bvar(2)"
  (check-equal? (shift 1 0 (expr-lam 'mw (expr-Nat) (expr-bvar 1)))
                (expr-lam 'mw (expr-Nat) (expr-bvar 2))))

(test-case "shift: constant zero unchanged"
  (check-equal? (shift 1 0 (expr-zero)) (expr-zero)))

(test-case "shift: app(bvar(0), bvar(1)) -> app(bvar(1), bvar(2))"
  (check-equal? (shift 1 0 (expr-app (expr-bvar 0) (expr-bvar 1)))
                (expr-app (expr-bvar 1) (expr-bvar 2))))

;; Additional shift tests
(test-case "shift: under Pi, cutoff increases"
  (check-equal? (shift 1 0 (expr-Pi 'mw (expr-Nat) (expr-bvar 1)))
                (expr-Pi 'mw (expr-Nat) (expr-bvar 2))))

(test-case "shift: under Sigma, cutoff increases"
  (check-equal? (shift 1 0 (expr-Sigma (expr-Nat) (expr-bvar 1)))
                (expr-Sigma (expr-Nat) (expr-bvar 2))))

(test-case "shift: Nat type unchanged"
  (check-equal? (shift 1 0 (expr-Nat)) (expr-Nat)))

(test-case "shift: Bool type unchanged"
  (check-equal? (shift 1 0 (expr-Bool)) (expr-Bool)))

(test-case "shift: refl unchanged"
  (check-equal? (shift 1 0 (expr-refl)) (expr-refl)))

(test-case "shift: Type(lzero) unchanged"
  (check-equal? (shift 1 0 (expr-Type (lzero))) (expr-Type (lzero))))

(test-case "shift: suc(bvar(0)) -> suc(bvar(1))"
  (check-equal? (shift 1 0 (expr-suc (expr-bvar 0)))
                (expr-suc (expr-bvar 1))))

(test-case "shift: Vec non-binding"
  (check-equal? (shift 1 0 (expr-Vec (expr-bvar 0) (expr-bvar 1)))
                (expr-Vec (expr-bvar 1) (expr-bvar 2))))

(test-case "shift: Fin non-binding"
  (check-equal? (shift 1 0 (expr-Fin (expr-bvar 0)))
                (expr-Fin (expr-bvar 1))))

;; ========================================
;; Substitution tests
;; ========================================

(test-case "subst: matching bvar(0) replaced"
  (check-equal? (subst 0 (expr-zero) (expr-bvar 0)) (expr-zero)))

(test-case "subst: bvar(1) above target decrements to bvar(0)"
  (check-equal? (subst 0 (expr-zero) (expr-bvar 1)) (expr-bvar 0)))

(test-case "subst: free variable unchanged"
  (check-equal? (subst 0 (expr-zero) (expr-fvar 'x)) (expr-fvar 'x)))

(test-case "subst: into application (bvar above target decrements)"
  (check-equal? (subst 0 (expr-zero) (expr-app (expr-bvar 0) (expr-bvar 1)))
                (expr-app (expr-zero) (expr-bvar 0))))

(test-case "subst: under lambda, external ref replaced"
  ;; lam(mw, Nat, app(bvar(1), bvar(0))) with subst(0, zero, ...)
  ;; Under binder: K=1, S=shift(1,0,zero)=zero
  ;; subst(1, zero, app(bvar(1), bvar(0))) = app(zero, bvar(0))
  (check-equal? (subst 0 (expr-zero) (expr-lam 'mw (expr-Nat) (expr-app (expr-bvar 1) (expr-bvar 0))))
                (expr-lam 'mw (expr-Nat) (expr-app (expr-zero) (expr-bvar 0)))))

(test-case "subst: under Pi type"
  (check-equal? (subst 0 (expr-zero) (expr-Pi 'mw (expr-Nat) (expr-bvar 1)))
                (expr-Pi 'mw (expr-Nat) (expr-zero))))

(test-case "subst: suc(bvar(0))"
  (check-equal? (subst 0 (expr-zero) (expr-suc (expr-bvar 0)))
                (expr-suc (expr-zero))))

;; ========================================
;; Open tests
;; ========================================

(test-case "open: bvar(0) -> zero"
  (check-equal? (open-expr (expr-bvar 0) (expr-zero)) (expr-zero)))

(test-case "open: bvar(1) decrements to bvar(0)"
  (check-equal? (open-expr (expr-bvar 1) (expr-zero)) (expr-bvar 0)))

(test-case "open: app(bvar(0), bvar(1)) with fvar('x) — bvar(1) decrements"
  (check-equal? (open-expr (expr-app (expr-bvar 0) (expr-bvar 1)) (expr-fvar 'x))
                (expr-app (expr-fvar 'x) (expr-bvar 0))))

;; ========================================
;; Combined / beta-reduction examples
;; ========================================

(test-case "beta: identity applied to zero"
  ;; open(bvar(0), zero) = zero
  (check-equal? (open-expr (expr-bvar 0) (expr-zero)) (expr-zero)))

(test-case "beta: (lam x:Nat. suc x) applied to zero"
  ;; open(suc(bvar(0)), zero) = suc(zero)
  (check-equal? (open-expr (expr-suc (expr-bvar 0)) (expr-zero))
                (expr-suc (expr-zero))))

(test-case "beta: nested (lam x:Nat. lam y:Nat. x) applied to zero"
  ;; Body = lam(mw, Nat, bvar(1)), bvar(1) refers to outer x
  ;; open(lam(mw, Nat, bvar(1)), zero) = lam(mw, Nat, zero)
  (check-equal? (open-expr (expr-lam 'mw (expr-Nat) (expr-bvar 1)) (expr-zero))
                (expr-lam 'mw (expr-Nat) (expr-zero))))

(test-case "subst: expression containing bound vars"
  ;; subst(0, suc(bvar(0)), bvar(0)) = suc(bvar(0))
  (check-equal? (subst 0 (expr-suc (expr-bvar 0)) (expr-bvar 0))
                (expr-suc (expr-bvar 0))))

(test-case "subst: shifting replacement under lambda"
  ;; subst(0, bvar(0), lam(mw, Nat, bvar(1)))
  ;; Inside: K=1, S=shift(1,0,bvar(0))=bvar(1)
  ;; subst(1, bvar(1), bvar(1)) = bvar(1)
  ;; Result: lam(mw, Nat, bvar(1))
  (check-equal? (subst 0 (expr-bvar 0) (expr-lam 'mw (expr-Nat) (expr-bvar 1)))
                (expr-lam 'mw (expr-Nat) (expr-bvar 1))))

;; ========================================
;; Vec/Fin substitution tests
;; ========================================

(test-case "subst: Vec type"
  (check-equal? (subst 0 (expr-Nat) (expr-Vec (expr-bvar 0) (expr-zero)))
                (expr-Vec (expr-Nat) (expr-zero))))

(test-case "subst: vcons"
  (check-equal? (subst 0 (expr-zero) (expr-vcons (expr-Nat) (expr-zero) (expr-bvar 0) (expr-vnil (expr-Nat))))
                (expr-vcons (expr-Nat) (expr-zero) (expr-zero) (expr-vnil (expr-Nat)))))

(test-case "shift: vhead"
  (check-equal? (shift 1 0 (expr-vhead (expr-Nat) (expr-bvar 0) (expr-bvar 1)))
                (expr-vhead (expr-Nat) (expr-bvar 1) (expr-bvar 2))))

;; ========================================
;; Boolrec substitution tests
;; ========================================

(test-case "shift: boolrec shifts all subexpressions"
  (check-equal? (shift 1 0 (expr-boolrec (expr-bvar 0) (expr-bvar 1) (expr-bvar 2) (expr-bvar 3)))
                (expr-boolrec (expr-bvar 1) (expr-bvar 2) (expr-bvar 3) (expr-bvar 4))))

(test-case "subst: boolrec substitutes in all subexpressions"
  (check-equal? (subst 0 (expr-true) (expr-boolrec (expr-bvar 0) (expr-zero) (expr-suc (expr-zero)) (expr-bvar 0)))
                (expr-boolrec (expr-true) (expr-zero) (expr-suc (expr-zero)) (expr-true))))

(test-case "shift: boolrec with constants unchanged"
  (check-equal? (shift 1 0 (expr-boolrec (expr-lam 'mw (expr-Bool) (expr-Nat)) (expr-zero) (expr-suc (expr-zero)) (expr-true)))
                (expr-boolrec (expr-lam 'mw (expr-Bool) (expr-Nat)) (expr-zero) (expr-suc (expr-zero)) (expr-true))))
