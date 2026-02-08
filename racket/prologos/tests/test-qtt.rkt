#lang racket/base

;;;
;;; Tests for qtt.rkt — Port of test-0f.maude
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         "../qtt.rkt")

;; ========================================
;; Usage context operations
;; ========================================

(test-case "zero-usage of length 3"
  (check-equal? (zero-usage 3) '(m0 m0 m0)))

(test-case "single-usage(1, 3) — m1 at position 1"
  (check-equal? (single-usage 1 3) '(m0 m1 m0)))

(test-case "add-usage"
  (check-equal? (add-usage '(m0 m1) '(m1 m0)) '(m1 m1)))

(test-case "scale-usage with m0 (erased)"
  (check-equal? (scale-usage 'm0 '(m1 mw)) '(m0 m0)))

(test-case "scale-usage with mw"
  (check-equal? (scale-usage 'mw '(m1 m0)) '(mw m0)))

;; ========================================
;; check-all-usages
;; ========================================

(test-case "check-all-usages: omega allows zero usage"
  (check-true (check-all-usages (ctx-extend ctx-empty (expr-Nat) 'mw) '(m0))))

(test-case "check-all-usages: linear used once"
  (check-true (check-all-usages (ctx-extend ctx-empty (expr-Nat) 'm1) '(m1))))

(test-case "check-all-usages: linear used zero — incompatible"
  (check-false (check-all-usages (ctx-extend ctx-empty (expr-Nat) 'm1) '(m0))))

(test-case "check-all-usages: erased used once — incompatible"
  (check-false (check-all-usages (ctx-extend ctx-empty (expr-Nat) 'm0) '(m1))))

;; ========================================
;; inferQ basic tests
;; ========================================

(test-case "inferQ: zero has type Nat, zero usage"
  (check-equal? (inferQ ctx-empty (expr-zero)) (tu (expr-Nat) '())))

(test-case "inferQ: bvar(0) in context [Nat:mw] — uses position 0 once"
  (check-equal? (inferQ (ctx-extend ctx-empty (expr-Nat) 'mw) (expr-bvar 0))
                (tu (expr-Nat) '(m1))))

;; ========================================
;; QTT: Unrestricted identity
;; ========================================

(test-case "checkQ: unrestricted identity lam(mw, Nat, bvar(0)) : Pi(mw, Nat, Nat)"
  (check-equal? (checkQ ctx-empty
                        (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                        (expr-Pi 'mw (expr-Nat) (expr-Nat)))
                (bu #t '())))

(test-case "checkQ-top: unrestricted identity"
  (check-true (checkQ-top ctx-empty
                          (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                          (expr-Pi 'mw (expr-Nat) (expr-Nat)))))

;; ========================================
;; QTT: Linear identity
;; ========================================

(test-case "checkQ: linear identity lam(m1, Nat, bvar(0)) : Pi(m1, Nat, Nat)"
  (check-equal? (checkQ ctx-empty
                        (expr-lam 'm1 (expr-Nat) (expr-bvar 0))
                        (expr-Pi 'm1 (expr-Nat) (expr-Nat)))
                (bu #t '())))

(test-case "checkQ-top: linear identity"
  (check-true (checkQ-top ctx-empty
                          (expr-lam 'm1 (expr-Nat) (expr-bvar 0))
                          (expr-Pi 'm1 (expr-Nat) (expr-Nat)))))

;; ========================================
;; QTT: Erased constant
;; ========================================

(test-case "checkQ: erased constant lam(m0, Nat, zero) : Pi(m0, Nat, Nat)"
  (check-equal? (checkQ ctx-empty
                        (expr-lam 'm0 (expr-Nat) (expr-zero))
                        (expr-Pi 'm0 (expr-Nat) (expr-Nat)))
                (bu #t '())))

(test-case "checkQ-top: erased constant"
  (check-true (checkQ-top ctx-empty
                          (expr-lam 'm0 (expr-Nat) (expr-zero))
                          (expr-Pi 'm0 (expr-Nat) (expr-Nat)))))

;; ========================================
;; NEGATIVE: Erased variable used at runtime
;; ========================================

(test-case "checkQ: erased variable used — fails"
  (let ([r (checkQ ctx-empty
                   (expr-lam 'm0 (expr-Nat) (expr-bvar 0))
                   (expr-Pi 'm0 (expr-Nat) (expr-Nat)))])
    (check-false (bu-ok? r))))

(test-case "checkQ-top: erased variable used — fails"
  (check-false (checkQ-top ctx-empty
                           (expr-lam 'm0 (expr-Nat) (expr-bvar 0))
                           (expr-Pi 'm0 (expr-Nat) (expr-Nat)))))

;; ========================================
;; NEGATIVE: Linear variable not used
;; ========================================

(test-case "checkQ: linear variable not used — fails"
  (let ([r (checkQ ctx-empty
                   (expr-lam 'm1 (expr-Nat) (expr-zero))
                   (expr-Pi 'm1 (expr-Nat) (expr-Nat)))])
    (check-false (bu-ok? r))))

(test-case "checkQ-top: linear variable not used — fails"
  (check-false (checkQ-top ctx-empty
                           (expr-lam 'm1 (expr-Nat) (expr-zero))
                           (expr-Pi 'm1 (expr-Nat) (expr-Nat)))))

;; ========================================
;; QTT: Application — usage combination
;; ========================================

(test-case "inferQ: app(ann(id, Pi), zero) — zero total usage"
  (check-equal? (inferQ ctx-empty
                        (expr-app (expr-ann (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                                            (expr-Pi 'mw (expr-Nat) (expr-Nat)))
                                  (expr-zero)))
                (tu (expr-Nat) '())))

(test-case "inferQ: app(id, bvar(0)) in [Nat:mw] — usage mw"
  (check-equal? (inferQ (ctx-extend ctx-empty (expr-Nat) 'mw)
                        (expr-app (expr-ann (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                                            (expr-Pi 'mw (expr-Nat) (expr-Nat)))
                                  (expr-bvar 0)))
                (tu (expr-Nat) '(mw))))

(test-case "inferQ: app(linear-id, bvar(0)) in [Nat:m1] — usage m1"
  (check-equal? (inferQ (ctx-extend ctx-empty (expr-Nat) 'm1)
                        (expr-app (expr-ann (expr-lam 'm1 (expr-Nat) (expr-bvar 0))
                                            (expr-Pi 'm1 (expr-Nat) (expr-Nat)))
                                  (expr-bvar 0)))
                (tu (expr-Nat) '(m1))))

(test-case "checkQ-top: linear app in [Nat:m1] — linear used once"
  (check-true (checkQ-top (ctx-extend ctx-empty (expr-Nat) 'm1)
                          (expr-app (expr-ann (expr-lam 'm1 (expr-Nat) (expr-bvar 0))
                                              (expr-Pi 'm1 (expr-Nat) (expr-Nat)))
                                    (expr-bvar 0))
                          (expr-Nat))))

;; ========================================
;; NEGATIVE: Linear variable duplicated
;; ========================================

(test-case "checkQ-top: linear var duplicated in pair — fails"
  (check-false (checkQ-top (ctx-extend ctx-empty (expr-Nat) 'm1)
                           (expr-pair (expr-bvar 0) (expr-bvar 0))
                           (expr-Sigma (expr-Nat) (expr-Nat)))))

;; ========================================
;; Pair with proper linear split
;; ========================================

(test-case "checkQ-top: two linear vars used once each in pair"
  (check-true (checkQ-top (ctx-extend (ctx-extend ctx-empty (expr-Nat) 'm1) (expr-Nat) 'm1)
                          (expr-pair (expr-bvar 1) (expr-bvar 0))
                          (expr-Sigma (expr-Nat) (expr-Nat)))))
