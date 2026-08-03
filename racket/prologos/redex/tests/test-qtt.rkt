#lang racket/base

;;;
;;; Tests for qtt.rkt — QTT unit tests
;;; Port of ../../tests/test-qtt.rkt (kernel QTT tests)
;;;

(require racket/match
         redex/reduction-semantics
         "../lang.rkt"
         "../subst.rkt"
         "../reduce.rkt"
         "../typing.rkt"
         "../qtt.rkt")

;; ========================================
;; Usage context operations
;; ========================================

(test-equal (zero-usage 3) '(m0 m0 m0))
(test-equal (single-usage 1 3) '(m0 m1 m0))
(test-equal (add-usage '(m0 m1) '(m1 m0)) '(m1 m1))
(test-equal (scale-usage 'm0 '(m1 mw)) '(m0 m0))
(test-equal (scale-usage 'mw '(m1 m0)) '(mw m0))

;; ========================================
;; check-all-usages
;; ========================================

;; omega allows zero usage
(test-equal (check-all-usages '((Nat mw) ()) '(m0)) #t)

;; linear used once — OK
(test-equal (check-all-usages '((Nat m1) ()) '(m1)) #t)

;; linear used zero — incompatible
(test-equal (check-all-usages '((Nat m1) ()) '(m0)) #f)

;; erased used once — incompatible
(test-equal (check-all-usages '((Nat m0) ()) '(m1)) #f)

;; ========================================
;; inferQ basic tests
;; ========================================

;; zero has type Nat, zero usage
(test-equal (term (inferQ () zero))
            (list 'tu (term Nat) '()))

;; bvar(0) in context [Nat:mw] — uses position 0 once
(test-equal (term (inferQ ((Nat mw) ()) (bvar 0)))
            (list 'tu (term Nat) '(m1)))

;; ========================================
;; checkQ: unrestricted identity
;; ========================================

(test-equal (term (checkQ () (lam mw Nat (bvar 0)) (Pi mw Nat Nat)))
            (list 'bu #t '()))

(test-equal (checkQ-top '()
                        (term (lam mw Nat (bvar 0)))
                        (term (Pi mw Nat Nat)))
            #t)

;; ========================================
;; checkQ: linear identity
;; ========================================

(test-equal (term (checkQ () (lam m1 Nat (bvar 0)) (Pi m1 Nat Nat)))
            (list 'bu #t '()))

(test-equal (checkQ-top '()
                        (term (lam m1 Nat (bvar 0)))
                        (term (Pi m1 Nat Nat)))
            #t)

;; ========================================
;; checkQ: erased constant
;; ========================================

(test-equal (term (checkQ () (lam m0 Nat zero) (Pi m0 Nat Nat)))
            (list 'bu #t '()))

(test-equal (checkQ-top '()
                        (term (lam m0 Nat zero))
                        (term (Pi m0 Nat Nat)))
            #t)

;; ========================================
;; NEGATIVE: erased variable used at runtime
;; ========================================

;; checkQ returns (bu #f ...) because erased var is used
(test-equal (match (term (checkQ () (lam m0 Nat (bvar 0)) (Pi m0 Nat Nat)))
              [`(bu ,ok? ,_) ok?])
            #f)

(test-equal (checkQ-top '()
                        (term (lam m0 Nat (bvar 0)))
                        (term (Pi m0 Nat Nat)))
            #f)

;; ========================================
;; NEGATIVE: linear variable not used
;; ========================================

(test-equal (match (term (checkQ () (lam m1 Nat zero) (Pi m1 Nat Nat)))
              [`(bu ,ok? ,_) ok?])
            #f)

(test-equal (checkQ-top '()
                        (term (lam m1 Nat zero))
                        (term (Pi m1 Nat Nat)))
            #f)

;; ========================================
;; Application — usage combination
;; ========================================

;; app(ann(id, Pi), zero) — zero total usage
(test-equal (term (inferQ () (app (ann (lam mw Nat (bvar 0))
                                       (Pi mw Nat Nat))
                                  zero)))
            (list 'tu (term Nat) '()))

;; app(id, bvar(0)) in [Nat:mw] — usage mw (= m0_func + mw * m1_arg = mw)
(test-equal (term (inferQ ((Nat mw) ()) (app (ann (lam mw Nat (bvar 0))
                                                   (Pi mw Nat Nat))
                                              (bvar 0))))
            (list 'tu (term Nat) '(mw)))

;; app(linear-id, bvar(0)) in [Nat:m1] — usage m1
(test-equal (term (inferQ ((Nat m1) ()) (app (ann (lam m1 Nat (bvar 0))
                                                   (Pi m1 Nat Nat))
                                              (bvar 0))))
            (list 'tu (term Nat) '(m1)))

;; checkQ-top: linear app in [Nat:m1] — linear used once
(test-equal (checkQ-top '((Nat m1) ())
                        (term (app (ann (lam m1 Nat (bvar 0))
                                        (Pi m1 Nat Nat))
                                   (bvar 0)))
                        (term Nat))
            #t)

;; ========================================
;; NEGATIVE: linear variable duplicated
;; ========================================

(test-equal (checkQ-top '((Nat m1) ())
                        (term (pair (bvar 0) (bvar 0)))
                        (term (Sigma Nat Nat)))
            #f)

;; ========================================
;; Pair with proper linear split
;; ========================================

;; Two linear vars used once each in pair — OK
(test-equal (checkQ-top '((Nat m1) ((Nat m1) ()))
                        (term (pair (bvar 1) (bvar 0)))
                        (term (Sigma Nat Nat)))
            #t)

;; ========================================
;; Vec / Fin usage rules (QTT P5 residual 3)
;; ========================================
;;
;; P5 armed seven usage rules in the kernel and the model had NONE, so they
;; shipped spec-unbacked. The soundness property stayed vacuously true —
;; nothing broke — which is exactly why the gap would have drifted silently.
;;
;; The vectors below are one-element and two-element Vec Nats. `vnil`/`fzero`
;; carry only type-level payload, so their usage is zero; `vcons`/`fsuc`
;; carry runtime payload, so theirs is not.

;; --- constructors: type-level indices contribute NOTHING ---

;; vnil(Nat) : Vec(Nat, zero) in a LINEAR context uses the variable zero times,
;; so a linear binder is left unconsumed and the top-level check must FAIL.
;; This is the assertion that distinguishes "zero usage" from "no rule at all":
;; without the arm the conversion fallback also fails, but for the wrong reason.
(test-equal (term (checkQ ((Nat m1) ()) (vnil Nat) (Vec Nat zero)))
            '(bu #t (m0)))

(test-equal (term (checkQ ((Nat m1) ()) (fzero zero) (Fin (suc zero))))
            '(bu #t (m0)))

;; --- vcons: head and tail are ADDED, not joined ---

;; A linear variable in the head position is consumed exactly once.
(test-equal (term (checkQ ((Nat m1) ())
                          (vcons Nat zero (bvar 0) (vnil Nat))
                          (Vec Nat (suc zero))))
            '(bu #t (m1)))

;; …and the SAME linear variable in head AND tail is consumed twice, which
;; `mult-add` reports as mw. This is the sequential-composition claim: a
;; join would have said m1 and silently permitted the duplication.
(test-equal (term (checkQ ((Nat m1) ())
                          (vcons Nat (suc zero) (bvar 0)
                                 (vcons Nat zero (bvar 0) (vnil Nat)))
                          (Vec Nat (suc (suc zero)))))
            '(bu #t (mw)))

;; …so the top-level check REJECTS it: a linear resource used twice.
(test-equal (checkQ-top '((Nat m1) ())
                        (term (vcons Nat (suc zero) (bvar 0)
                                     (vcons Nat zero (bvar 0) (vnil Nat))))
                        (term (Vec Nat (suc (suc zero)))))
            #f)

;; …while using it once is accepted.
(test-equal (checkQ-top '((Nat m1) ())
                        (term (vcons Nat zero (bvar 0) (vnil Nat)))
                        (term (Vec Nat (suc zero))))
            #t)

;; --- fsuc: the predecessor is a RUNTIME value and is counted ---

(test-equal (term (checkQ (((Fin zero) m1) ())
                          (fsuc zero (bvar 0))
                          (Fin (suc zero))))
            '(bu #t (m1)))

;; --- eliminators: usage passes through the subject ---

;; vhead of a vector whose head is a linear variable consumes it once.
(test-equal (term (inferQ ((Nat m1) ())
                          (vhead Nat zero
                                 (ann (vcons Nat zero (bvar 0) (vnil Nat))
                                      (Vec Nat (suc zero))))))
            (list 'tu (term Nat) '(m1)))

;; vtail, same subject, same usage — the DISCARDED head is weakening, which is
;; invisible to variable-level accounting exactly as `fst` discarding a pair's
;; second component is.
(test-equal (term (inferQ ((Nat m1) ())
                          (vtail Nat zero
                                 (ann (vcons Nat zero (bvar 0) (vnil Nat))
                                      (Vec Nat (suc zero))))))
            (list 'tu (term (Vec Nat zero)) '(m1)))

;; vindex ADDS the index's usage to the vector's — both are read, so both
;; happen. Here the index is closed, so the sum is the vector's alone.
(test-equal (term (inferQ ((Nat m1) ())
                          (vindex Nat (suc zero) (fzero zero)
                                  (ann (vcons Nat zero (bvar 0) (vnil Nat))
                                       (Vec Nat (suc zero))))))
            (list 'tu (term Nat) '(m1)))

;; ========================================
;; Vec / Fin reduction (QTT P5 residual 1 — the kernel's vindex iota rules)
;; ========================================

(test-equal (term (whnf (vindex Nat (suc zero) (fzero zero)
                                (vcons Nat zero (suc zero) (vnil Nat)))))
            (term (suc zero)))

;; The recursive rule, which must fire before the base one can apply. An
;; implementation handling only `fzero` passes the case above and fails here.
(test-equal (term (whnf (vindex Nat (suc (suc zero))
                                (fsuc (suc zero) (fzero zero))
                                (vcons Nat (suc zero) zero
                                       (vcons Nat zero (suc zero) (vnil Nat))))))
            (term (suc zero)))

;; ========================================
;; Summary
;; ========================================
(test-results)
