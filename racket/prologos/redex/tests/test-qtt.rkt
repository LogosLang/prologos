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
;; Summary
;; ========================================
(test-results)
