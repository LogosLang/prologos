#lang racket/base

;;;
;;; PROLOGOS REDEX — REDUCTION TESTS
;;; Ports the kernel's reduction tests to the PLT Redex formalization.
;;;
;;; Tests cover: whnf, natrec, J eliminator, full NF, conversion, Vec eliminators.
;;;

(require redex/reduction-semantics
         "../lang.rkt"
         "../subst.rkt"
         "../reduce.rkt")

;; ========================================
;; WHNF tests
;; ========================================

;; Beta reduction: app(lam(mw, Nat, bvar(0)), zero) --> zero
(test-equal (term (whnf (app (lam mw Nat (bvar 0)) zero)))
            (term zero))

;; Beta with suc in body: app(lam(mw, Nat, suc(bvar(0))), zero) --> suc(zero)
(test-equal (term (whnf (app (lam mw Nat (suc (bvar 0))) zero)))
            (term (suc zero)))

;; Nested lambda: app(lam(mw, Nat, lam(mw, Nat, bvar(1))), zero) --> lam(mw, Nat, zero)
(test-equal (term (whnf (app (lam mw Nat (lam mw Nat (bvar 1))) zero)))
            (term (lam mw Nat zero)))

;; fst(pair(zero, suc(zero))) --> zero
(test-equal (term (whnf (fst (pair zero (suc zero)))))
            (term zero))

;; snd(pair(zero, suc(zero))) --> suc(zero)
(test-equal (term (whnf (snd (pair zero (suc zero)))))
            (term (suc zero)))

;; ann(zero, Nat) --> zero
(test-equal (term (whnf (ann zero Nat)))
            (term zero))

;; bvar(0) is already in WHNF
(test-equal (term (whnf (bvar 0)))
            (term (bvar 0)))

;; Pi(mw, Nat, Nat) is already in WHNF
(test-equal (term (whnf (Pi mw Nat Nat)))
            (term (Pi mw Nat Nat)))

;; ========================================
;; Natrec tests
;; ========================================

;; Shared definitions for natrec tests:
;;   test-motive = lam(mw, Nat, Nat)
;;   test-step   = lam(mw, Nat, lam(mw, Nat, suc(bvar(0))))

;; natrec(motive, zero, step, zero) --> zero
(test-equal (term (whnf (natrec (lam mw Nat Nat)
                                zero
                                (lam mw Nat (lam mw Nat (suc (bvar 0))))
                                zero)))
            (term zero))

;; natrec(motive, zero, step, suc(zero)) -->whnf suc(natrec(motive, zero, step, zero))
(test-equal (term (whnf (natrec (lam mw Nat Nat)
                                zero
                                (lam mw Nat (lam mw Nat (suc (bvar 0))))
                                (suc zero))))
            (term (suc (natrec (lam mw Nat Nat)
                               zero
                               (lam mw Nat (lam mw Nat (suc (bvar 0))))
                               zero))))

;; nf(natrec(motive, zero, step, suc(zero))) = suc(zero)
(test-equal (term (nf (natrec (lam mw Nat Nat)
                              zero
                              (lam mw Nat (lam mw Nat (suc (bvar 0))))
                              (suc zero))))
            (term (suc zero)))

;; nf(natrec(motive, zero, step, suc(suc(zero)))) = suc(suc(zero))
(test-equal (term (nf (natrec (lam mw Nat Nat)
                              zero
                              (lam mw Nat (lam mw Nat (suc (bvar 0))))
                              (suc (suc zero)))))
            (term (suc (suc zero))))

;; ========================================
;; J eliminator test
;; ========================================

;; J(motive, base, zero, zero, refl) --> refl
;;   motive = lam(mw, Nat, lam(mw, Nat, lam(mw, Eq(Nat, bvar(1), bvar(0)), Nat)))
;;   base   = lam(mw, Nat, refl)
;; J-refl fires: app(base, left) = app(lam(mw, Nat, refl), zero) --> refl
(test-equal (term (whnf (J (lam mw Nat
                             (lam mw Nat
                               (lam mw (Eq Nat (bvar 1) (bvar 0)) Nat)))
                           (lam mw Nat refl)
                           zero
                           zero
                           refl)))
            (term refl))

;; ========================================
;; Full NF tests
;; ========================================

;; nf(lam(mw, Nat, app(lam(mw, Nat, bvar(0)), bvar(0)))) = lam(mw, Nat, bvar(0))
(test-equal (term (nf (lam mw Nat (app (lam mw Nat (bvar 0)) (bvar 0)))))
            (term (lam mw Nat (bvar 0))))

;; nf(Pi(mw, Nat, app(lam(mw, Nat, bvar(0)), Nat))) = Pi(mw, Nat, Nat)
(test-equal (term (nf (Pi mw Nat (app (lam mw Nat (bvar 0)) Nat))))
            (term (Pi mw Nat Nat)))

;; ========================================
;; Conversion tests
;; ========================================

;; conv(zero, zero) = #t
(test-equal (term (conv zero zero)) #t)

;; conv(zero, suc(zero)) = #f
(test-equal (term (conv zero (suc zero))) #f)

;; conv(app(lam(mw, Nat, bvar(0)), zero), zero) = #t
(test-equal (term (conv (app (lam mw Nat (bvar 0)) zero) zero)) #t)

;; conv(app(lam(mw, Nat, suc(bvar(0))), zero), suc(zero)) = #t
(test-equal (term (conv (app (lam mw Nat (suc (bvar 0))) zero) (suc zero))) #t)

;; conv(Pi(mw, Nat, app(lam(mw, Nat, bvar(0)), Nat)), Pi(mw, Nat, Nat)) = #t
(test-equal (term (conv (Pi mw Nat (app (lam mw Nat (bvar 0)) Nat))
                        (Pi mw Nat Nat)))
            #t)

;; ========================================
;; Vec reduction tests
;; ========================================

;; whnf(vhead(Nat, zero, vcons(Nat, zero, suc(zero), vnil(Nat)))) = suc(zero)
(test-equal (term (whnf (vhead Nat zero (vcons Nat zero (suc zero) (vnil Nat)))))
            (term (suc zero)))

;; whnf(vtail(Nat, zero, vcons(Nat, zero, suc(zero), vnil(Nat)))) = vnil(Nat)
(test-equal (term (whnf (vtail Nat zero (vcons Nat zero (suc zero) (vnil Nat)))))
            (term (vnil Nat)))

;; ========================================
;; Summary
;; ========================================
(test-results)
