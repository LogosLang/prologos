#lang racket/base

;;;
;;; Tests for Vec/Fin typing — Port of test-0e.maude
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt"))

;; ========================================
;; Vec type formation
;; ========================================

(test-case "isType: Vec(Nat, zero)"
  (check-true (tc:is-type ctx-empty (expr-Vec (expr-Nat) (expr-zero)))))

(test-case "isType: Vec(Nat, suc(zero))"
  (check-true (tc:is-type ctx-empty (expr-Vec (expr-Nat) (expr-suc (expr-zero))))))

(test-case "isType: Vec(Bool, suc(suc(zero)))"
  (check-true (tc:is-type ctx-empty (expr-Vec (expr-Bool) (expr-suc (expr-suc (expr-zero)))))))

;; ========================================
;; Fin type formation
;; ========================================

(test-case "isType: Fin(suc(zero))"
  (check-true (tc:is-type ctx-empty (expr-Fin (expr-suc (expr-zero))))))

(test-case "isType: Fin(suc(suc(suc(zero))))"
  (check-true (tc:is-type ctx-empty (expr-Fin (expr-suc (expr-suc (expr-suc (expr-zero))))))))

;; ========================================
;; Vec constructor typing
;; ========================================

(test-case "check: vnil(Nat) : Vec(Nat, zero)"
  (check-true (tc:check ctx-empty (expr-vnil (expr-Nat)) (expr-Vec (expr-Nat) (expr-zero)))))

(test-case "check: single-element vector [0] : Vec(Nat, suc(zero))"
  (check-true (tc:check ctx-empty
                     (expr-vcons (expr-Nat) (expr-zero) (expr-zero) (expr-vnil (expr-Nat)))
                     (expr-Vec (expr-Nat) (expr-suc (expr-zero))))))

(test-case "check: two-element vector [1, 0] : Vec(Nat, suc(suc(zero)))"
  (check-true (tc:check ctx-empty
                     (expr-vcons (expr-Nat) (expr-suc (expr-zero)) (expr-suc (expr-zero))
                                 (expr-vcons (expr-Nat) (expr-zero) (expr-zero) (expr-vnil (expr-Nat))))
                     (expr-Vec (expr-Nat) (expr-suc (expr-suc (expr-zero)))))))

(test-case "check: three-element vector [0, 1, 2] : Vec(Nat, 3)"
  (check-true (tc:check ctx-empty
                     (expr-vcons (expr-Nat) (expr-suc (expr-suc (expr-zero))) (expr-zero)
                       (expr-vcons (expr-Nat) (expr-suc (expr-zero)) (expr-suc (expr-zero))
                         (expr-vcons (expr-Nat) (expr-zero) (expr-suc (expr-suc (expr-zero))) (expr-vnil (expr-Nat)))))
                     (expr-Vec (expr-Nat) (expr-suc (expr-suc (expr-suc (expr-zero))))))))

(test-case "NEGATIVE: vnil(Nat) : Vec(Nat, suc(zero)) — wrong length"
  (check-false (tc:check ctx-empty (expr-vnil (expr-Nat)) (expr-Vec (expr-Nat) (expr-suc (expr-zero))))))

;; ========================================
;; Fin constructor typing
;; ========================================

(test-case "check: fzero(zero) : Fin(suc(zero))"
  (check-true (tc:check ctx-empty (expr-fzero (expr-zero)) (expr-Fin (expr-suc (expr-zero))))))

(test-case "check: fzero(suc(suc(zero))) : Fin(suc(suc(suc(zero))))"
  (check-true (tc:check ctx-empty
                     (expr-fzero (expr-suc (expr-suc (expr-zero))))
                     (expr-Fin (expr-suc (expr-suc (expr-suc (expr-zero))))))))

(test-case "check: fsuc(suc(suc(zero)), fzero(suc(zero))) : Fin(suc(suc(suc(zero))))"
  ;; i.e. 1 : Fin(3)  (fsuc wrapping fzero(1) : Fin(2))
  (check-true (tc:check ctx-empty
                     (expr-fsuc (expr-suc (expr-suc (expr-zero)))
                                (expr-fzero (expr-suc (expr-zero))))
                     (expr-Fin (expr-suc (expr-suc (expr-suc (expr-zero))))))))

(test-case "NEGATIVE: fzero(zero) : Fin(zero) — no Fin(0)"
  (check-false (tc:check ctx-empty (expr-fzero (expr-zero)) (expr-Fin (expr-zero)))))

;; ========================================
;; Safe indexing
;; ========================================

(test-case "infer: vindex into annotated single-element vector -> Nat"
  ;; vindex(Nat, suc(zero), fzero(zero), ann(vcons(Nat,zero,suc(suc(zero)),vnil(Nat)), Vec(Nat,suc(zero))))
  (check-equal? (tc:infer ctx-empty
                       (expr-vindex (expr-Nat) (expr-suc (expr-zero))
                                    (expr-fzero (expr-zero))
                                    (expr-ann (expr-vcons (expr-Nat) (expr-zero)
                                                          (expr-suc (expr-suc (expr-zero)))
                                                          (expr-vnil (expr-Nat)))
                                              (expr-Vec (expr-Nat) (expr-suc (expr-zero))))))
                (expr-Nat)))
