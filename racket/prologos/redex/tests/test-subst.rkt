#lang racket/base

;;;
;;; PROLOGOS REDEX -- SUBSTITUTION TESTS
;;; Ports the kernel substitution tests to the PLT Redex formalization.
;;; Uses test-equal from redex/reduction-semantics.
;;;

(require redex/reduction-semantics
         "../lang.rkt"
         "../subst.rkt")

;; ========================================
;; Shift tests
;; ========================================

;; bvar at or above cutoff gets shifted
(test-equal (term (shift 1 0 (bvar 0))) (term (bvar 1)))

;; bvar below cutoff is unchanged
(test-equal (term (shift 1 1 (bvar 0))) (term (bvar 0)))

;; larger index
(test-equal (term (shift 1 0 (bvar 2))) (term (bvar 3)))

;; free variables are unaffected
(test-equal (term (shift 1 0 (fvar x))) (term (fvar x)))

;; lam: body's bvar 0 is bound (below cutoff+1), stays
(test-equal (term (shift 1 0 (lam mw Nat (bvar 0))))
            (term (lam mw Nat (bvar 0))))

;; lam: body's bvar 1 is free (>= cutoff+1), gets shifted
(test-equal (term (shift 1 0 (lam mw Nat (bvar 1))))
            (term (lam mw Nat (bvar 2))))

;; constants pass through
(test-equal (term (shift 1 0 zero)) (term zero))

;; shift distributes into app
(test-equal (term (shift 1 0 (app (bvar 0) (bvar 1))))
            (term (app (bvar 1) (bvar 2))))

;; Pi: codomain is a binder
(test-equal (term (shift 1 0 (Pi mw Nat (bvar 1))))
            (term (Pi mw Nat (bvar 2))))

;; Sigma: second component is a binder
(test-equal (term (shift 1 0 (Sigma Nat (bvar 1))))
            (term (Sigma Nat (bvar 2))))

;; type constants are unaffected
(test-equal (term (shift 1 0 Nat)) (term Nat))
(test-equal (term (shift 1 0 Bool)) (term Bool))
(test-equal (term (shift 1 0 refl)) (term refl))
(test-equal (term (shift 1 0 (Type lzero))) (term (Type lzero)))

;; suc distributes
(test-equal (term (shift 1 0 (suc (bvar 0))))
            (term (suc (bvar 1))))

;; Vec distributes
(test-equal (term (shift 1 0 (Vec (bvar 0) (bvar 1))))
            (term (Vec (bvar 1) (bvar 2))))

;; Fin distributes
(test-equal (term (shift 1 0 (Fin (bvar 0))))
            (term (Fin (bvar 1))))

;; ========================================
;; Substitution tests
;; ========================================

;; substitute into the target variable
(test-equal (term (subst 0 zero (bvar 0))) (term zero))

;; non-matching bvar is unchanged
(test-equal (term (subst 0 zero (bvar 1))) (term (bvar 1)))

;; free variable is unchanged
(test-equal (term (subst 0 zero (fvar x))) (term (fvar x)))

;; distributes into app
(test-equal (term (subst 0 zero (app (bvar 0) (bvar 1))))
            (term (app zero (bvar 1))))

;; under lam binder: k increments, s shifts
(test-equal (term (subst 0 zero (lam mw Nat (app (bvar 1) (bvar 0)))))
            (term (lam mw Nat (app zero (bvar 0)))))

;; under Pi binder
(test-equal (term (subst 0 zero (Pi mw Nat (bvar 1))))
            (term (Pi mw Nat zero)))

;; suc distributes
(test-equal (term (subst 0 zero (suc (bvar 0))))
            (term (suc zero)))

;; ========================================
;; Open tests
;; ========================================

;; open replaces bvar 0 with the argument
(test-equal (term (open-expr (bvar 0) zero)) (term zero))

;; bvar 1 is not bvar 0, stays
(test-equal (term (open-expr (bvar 1) zero)) (term (bvar 1)))

;; distributes into app, replaces bvar 0 only
(test-equal (term (open-expr (app (bvar 0) (bvar 1)) (fvar x)))
            (term (app (fvar x) (bvar 1))))

;; ========================================
;; Beta reduction examples
;; ========================================

;; identity body: bvar 0 -> zero
(test-equal (term (open-expr (bvar 0) zero)) (term zero))

;; suc body: suc(bvar 0) -> suc(zero)
(test-equal (term (open-expr (suc (bvar 0)) zero))
            (term (suc zero)))

;; under lam: bvar 1 in inner body refers to outer binder
(test-equal (term (open-expr (lam mw Nat (bvar 1)) zero))
            (term (lam mw Nat zero)))

;; substituting a non-closed term
(test-equal (term (subst 0 (suc (bvar 0)) (bvar 0)))
            (term (suc (bvar 0))))

;; bvar 0 substituted under lam: s shifts to bvar 1, matches bvar 1 in body
(test-equal (term (subst 0 (bvar 0) (lam mw Nat (bvar 1))))
            (term (lam mw Nat (bvar 1))))

;; ========================================
;; Vec/Fin tests
;; ========================================

;; subst into Vec
(test-equal (term (subst 0 Nat (Vec (bvar 0) zero)))
            (term (Vec Nat zero)))

;; subst into vcons
(test-equal (term (subst 0 zero (vcons Nat zero (bvar 0) (vnil Nat))))
            (term (vcons Nat zero zero (vnil Nat))))

;; shift into vhead
(test-equal (term (shift 1 0 (vhead Nat (bvar 0) (bvar 1))))
            (term (vhead Nat (bvar 1) (bvar 2))))

;; ========================================
;; Summary
;; ========================================
(test-results)
