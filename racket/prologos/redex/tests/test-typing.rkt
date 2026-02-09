#lang racket/base

;;;
;;; PROLOGOS REDEX — BIDIRECTIONAL TYPE CHECKER TESTS
;;; Ports the kernel's typing tests to the PLT Redex formalization.
;;;
;;; Tests cover: universe typing, Nat/Bool typing, Pi/Sigma formation,
;;; lambda checking, application inference, annotations, equality types,
;;; polymorphic identity, Vec/Fin type formation, Vec/Fin constructor typing,
;;; Vec safe indexing, and negative tests.
;;;

(require redex/reduction-semantics
         "../lang.rkt"
         "../subst.rkt"
         "../reduce.rkt"
         "../typing.rkt")

;; ========================================
;; Universe typing
;; ========================================

;; infer(empty, Type(lzero)) = Type(lsuc(lzero))
(test-equal (term (infer () (Type lzero)))
            (term (Type (lsuc lzero))))

;; infer(empty, Type(lsuc(lzero))) = Type(lsuc(lsuc(lzero)))
(test-equal (term (infer () (Type (lsuc lzero))))
            (term (Type (lsuc (lsuc lzero)))))

;; ========================================
;; Nat typing
;; ========================================

;; infer(empty, Nat) = Type(lzero)
(test-equal (term (infer () Nat))
            (term (Type lzero)))

;; infer(empty, zero) = Nat
(test-equal (term (infer () zero))
            (term Nat))

;; infer(empty, suc(zero)) = Nat
(test-equal (term (infer () (suc zero)))
            (term Nat))

;; infer(empty, suc(suc(zero))) = Nat
(test-equal (term (infer () (suc (suc zero))))
            (term Nat))

;; check(empty, suc(zero), Nat) = #t
(test-equal (term (check () (suc zero) Nat)) #t)

;; ========================================
;; Bool typing
;; ========================================

;; infer(empty, Bool) = Type(lzero)
(test-equal (term (infer () Bool))
            (term (Type lzero)))

;; infer(empty, true) = Bool
(test-equal (term (infer () true))
            (term Bool))

;; ========================================
;; Pi type formation
;; ========================================

;; is-type(empty, Pi(mw, Nat, Nat)) = #t
(test-equal (term (is-type () (Pi mw Nat Nat))) #t)

;; is-type(empty, Pi(m0, Type(lzero), bvar(0))) = #t
(test-equal (term (is-type () (Pi m0 (Type lzero) (bvar 0)))) #t)

;; ========================================
;; Lambda typing
;; ========================================

;; check(empty, lam(mw, Nat, bvar(0)), Pi(mw, Nat, Nat)) = #t  (identity)
(test-equal (term (check () (lam mw Nat (bvar 0)) (Pi mw Nat Nat))) #t)

;; check(empty, lam(mw, Nat, suc(bvar(0))), Pi(mw, Nat, Nat)) = #t  (successor)
(test-equal (term (check () (lam mw Nat (suc (bvar 0))) (Pi mw Nat Nat))) #t)

;; check(empty, lam(mw, Nat, zero), Pi(mw, Nat, Nat)) = #t  (constant zero)
(test-equal (term (check () (lam mw Nat zero) (Pi mw Nat Nat))) #t)

;; NEGATIVE: check(empty, lam(mw, Nat, bvar(0)), Pi(mw, Nat, Bool)) = #f  (type mismatch)
(test-equal (term (check () (lam mw Nat (bvar 0)) (Pi mw Nat Bool))) #f)

;; ========================================
;; Application typing
;; ========================================

;; infer(empty, app(ann(lam(mw, Nat, suc(bvar(0))), Pi(mw, Nat, Nat)), zero)) = Nat
(test-equal (term (infer () (app (ann (lam mw Nat (suc (bvar 0))) (Pi mw Nat Nat)) zero)))
            (term Nat))

;; infer(((Nat mw) ()), app(ann(lam(mw, Nat, bvar(0)), Pi(mw, Nat, Nat)), bvar(0))) = Nat
(test-equal (term (infer ((Nat mw) ()) (app (ann (lam mw Nat (bvar 0)) (Pi mw Nat Nat)) (bvar 0))))
            (term Nat))

;; ========================================
;; Annotated terms
;; ========================================

;; infer(empty, ann(zero, Nat)) = Nat
(test-equal (term (infer () (ann zero Nat)))
            (term Nat))

;; infer(empty, ann(lam(mw, Nat, bvar(0)), Pi(mw, Nat, Nat))) = Pi(mw, Nat, Nat)
(test-equal (term (infer () (ann (lam mw Nat (bvar 0)) (Pi mw Nat Nat))))
            (term (Pi mw Nat Nat)))

;; ========================================
;; Sigma types
;; ========================================

;; is-type(empty, Sigma(Nat, Nat)) = #t
(test-equal (term (is-type () (Sigma Nat Nat))) #t)

;; check(empty, pair(zero, suc(zero)), Sigma(Nat, Nat)) = #t
(test-equal (term (check () (pair zero (suc zero)) (Sigma Nat Nat))) #t)

;; infer(empty, fst(ann(pair(zero, suc(zero)), Sigma(Nat, Nat)))) = Nat
(test-equal (term (infer () (fst (ann (pair zero (suc zero)) (Sigma Nat Nat)))))
            (term Nat))

;; infer(empty, snd(ann(pair(zero, suc(zero)), Sigma(Nat, Nat)))) = Nat
(test-equal (term (infer () (snd (ann (pair zero (suc zero)) (Sigma Nat Nat)))))
            (term Nat))

;; ========================================
;; Dependent pair
;; ========================================

;; check(empty, pair(zero, refl), Sigma(Nat, Eq(Nat, bvar(0), zero))) = #t
(test-equal (term (check () (pair zero refl) (Sigma Nat (Eq Nat (bvar 0) zero)))) #t)

;; NEGATIVE: check(empty, pair(suc(zero), refl), Sigma(Nat, Eq(Nat, bvar(0), zero))) = #f
(test-equal (term (check () (pair (suc zero) refl) (Sigma Nat (Eq Nat (bvar 0) zero)))) #f)

;; ========================================
;; Equality types
;; ========================================

;; is-type(empty, Eq(Nat, zero, zero)) = #t
(test-equal (term (is-type () (Eq Nat zero zero))) #t)

;; check(empty, refl, Eq(Nat, zero, zero)) = #t
(test-equal (term (check () refl (Eq Nat zero zero))) #t)

;; NEGATIVE: check(empty, refl, Eq(Nat, zero, suc(zero))) = #f
(test-equal (term (check () refl (Eq Nat zero (suc zero)))) #f)

;; ========================================
;; Polymorphic identity
;; ========================================

;; check(empty, lam(m0, Type(lzero), lam(mw, bvar(0), bvar(0))),
;;              Pi(m0, Type(lzero), Pi(mw, bvar(0), bvar(1)))) = #t
(test-equal (term (check ()
                         (lam m0 (Type lzero) (lam mw (bvar 0) (bvar 0)))
                         (Pi m0 (Type lzero) (Pi mw (bvar 0) (bvar 1)))))
            #t)

;; ========================================
;; Dependent application of polymorphic identity
;; ========================================

;; poly-id = ann(lam(m0, Type(lzero), lam(mw, bvar(0), bvar(0))),
;;               Pi(m0, Type(lzero), Pi(mw, bvar(0), bvar(1))))
;; infer(empty, app(poly-id, Nat)) = Pi(mw, Nat, Nat)
(test-equal (term (infer () (app (ann (lam m0 (Type lzero) (lam mw (bvar 0) (bvar 0)))
                                      (Pi m0 (Type lzero) (Pi mw (bvar 0) (bvar 1))))
                                 Nat)))
            (term (Pi mw Nat Nat)))

;; infer(empty, app(app(poly-id, Nat), zero)) = Nat
(test-equal (term (infer () (app (app (ann (lam m0 (Type lzero) (lam mw (bvar 0) (bvar 0)))
                                           (Pi m0 (Type lzero) (Pi mw (bvar 0) (bvar 1))))
                                      Nat)
                                 zero)))
            (term Nat))

;; ========================================
;; Negative tests
;; ========================================

;; infer(empty, lam(mw, Nat, bvar(0))) = err  (bare lambda cannot synthesize)
(test-equal (term (infer () (lam mw Nat (bvar 0))))
            (term err))

;; check(empty, zero, Bool) = #f  (zero is not Bool)
(test-equal (term (check () zero Bool)) #f)

;; ========================================
;; Vec type formation
;; ========================================

;; is-type(empty, Vec(Nat, zero)) = #t
(test-equal (term (is-type () (Vec Nat zero))) #t)

;; is-type(empty, Vec(Nat, suc(zero))) = #t
(test-equal (term (is-type () (Vec Nat (suc zero)))) #t)

;; is-type(empty, Vec(Bool, suc(suc(zero)))) = #t
(test-equal (term (is-type () (Vec Bool (suc (suc zero))))) #t)

;; ========================================
;; Fin type formation
;; ========================================

;; is-type(empty, Fin(suc(zero))) = #t
(test-equal (term (is-type () (Fin (suc zero)))) #t)

;; is-type(empty, Fin(suc(suc(suc(zero))))) = #t
(test-equal (term (is-type () (Fin (suc (suc (suc zero)))))) #t)

;; ========================================
;; Vec constructor typing
;; ========================================

;; check(empty, vnil(Nat), Vec(Nat, zero)) = #t
(test-equal (term (check () (vnil Nat) (Vec Nat zero))) #t)

;; check(empty, vcons(Nat, zero, zero, vnil(Nat)), Vec(Nat, suc(zero))) = #t
(test-equal (term (check () (vcons Nat zero zero (vnil Nat)) (Vec Nat (suc zero)))) #t)

;; check(empty, vcons(Nat, suc(zero), suc(zero), vcons(Nat, zero, zero, vnil(Nat))),
;;              Vec(Nat, suc(suc(zero)))) = #t
(test-equal (term (check ()
                         (vcons Nat (suc zero) (suc zero) (vcons Nat zero zero (vnil Nat)))
                         (Vec Nat (suc (suc zero)))))
            #t)

;; NEGATIVE: check(empty, vnil(Nat), Vec(Nat, suc(zero))) = #f
(test-equal (term (check () (vnil Nat) (Vec Nat (suc zero)))) #f)

;; ========================================
;; Fin constructor typing
;; ========================================

;; check(empty, fzero(zero), Fin(suc(zero))) = #t
(test-equal (term (check () (fzero zero) (Fin (suc zero)))) #t)

;; check(empty, fzero(suc(suc(zero))), Fin(suc(suc(suc(zero))))) = #t
(test-equal (term (check () (fzero (suc (suc zero))) (Fin (suc (suc (suc zero)))))) #t)

;; check(empty, fsuc(suc(suc(zero)), fzero(suc(zero))), Fin(suc(suc(suc(zero))))) = #t
(test-equal (term (check () (fsuc (suc (suc zero)) (fzero (suc zero))) (Fin (suc (suc (suc zero)))))) #t)

;; NEGATIVE: check(empty, fzero(zero), Fin(zero)) = #f
(test-equal (term (check () (fzero zero) (Fin zero))) #f)

;; ========================================
;; Vec safe indexing
;; ========================================

;; infer(empty, vindex(Nat, suc(zero), fzero(zero),
;;       ann(vcons(Nat, zero, suc(suc(zero)), vnil(Nat)), Vec(Nat, suc(zero))))) = Nat
(test-equal (term (infer () (vindex Nat (suc zero) (fzero zero)
                                    (ann (vcons Nat zero (suc (suc zero)) (vnil Nat))
                                         (Vec Nat (suc zero))))))
            (term Nat))

;; ========================================
;; Summary
;; ========================================
(test-results)
