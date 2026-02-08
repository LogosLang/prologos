#lang racket/base

;;;
;;; Tests for sessions.rkt — Port of test-0g.maude (session subset)
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../substitution.rkt"
         "../sessions.rkt")

;; ========================================
;; Duality tests
;; ========================================

(test-case "dual: send -> recv"
  (check-equal? (dual (sess-send (expr-Nat) (sess-end)))
                (sess-recv (expr-Nat) (sess-end))))

(test-case "dual: recv -> send"
  (check-equal? (dual (sess-recv (expr-Nat) (sess-end)))
                (sess-send (expr-Nat) (sess-end))))

(test-case "dual: send-then-recv"
  (check-equal? (dual (sess-send (expr-Nat) (sess-recv (expr-Bool) (sess-end))))
                (sess-recv (expr-Nat) (sess-send (expr-Bool) (sess-end)))))

(test-case "dual: choice -> offer"
  (check-equal? (dual (sess-choice (list (cons 'left (sess-send (expr-Nat) (sess-end)))
                                         (cons 'right (sess-end)))))
                (sess-offer (list (cons 'left (sess-recv (expr-Nat) (sess-end)))
                                  (cons 'right (sess-end))))))

(test-case "dual: dependent send -> dependent recv"
  (check-equal? (dual (sess-dsend (expr-Nat) (sess-send (expr-Vec (expr-Nat) (expr-bvar 0)) (sess-end))))
                (sess-drecv (expr-Nat) (sess-recv (expr-Vec (expr-Nat) (expr-bvar 0)) (sess-end)))))

(test-case "dual: involution"
  (let ([s (sess-send (expr-Nat) (sess-recv (expr-Bool) (sess-end)))])
    (check-equal? (dual (dual s)) s)))

(test-case "dual: endS"
  (check-equal? (dual (sess-end)) (sess-end)))

(test-case "dual: mu"
  (check-equal? (dual (sess-mu (sess-send (expr-Nat) (sess-svar 0))))
                (sess-mu (sess-recv (expr-Nat) (sess-svar 0)))))

;; ========================================
;; Session substitution tests
;; ========================================

(test-case "substS: dependent session after sending value"
  ;; After dsend(Nat, send(Vec(Nat, bvar(0)), endS)),
  ;; sending suc(suc(zero)) makes continuation send(Vec(Nat, suc(suc(zero))), endS)
  (check-equal? (substS (sess-send (expr-Vec (expr-Nat) (expr-bvar 0)) (sess-end))
                        0 (expr-suc (expr-suc (expr-zero))))
                (sess-send (expr-Vec (expr-Nat) (expr-suc (expr-suc (expr-zero)))) (sess-end))))

;; ========================================
;; Session unfolding tests
;; ========================================

(test-case "unfold: mu(send(Nat, svar(0))) -> send(Nat, mu(send(Nat, svar(0))))"
  (check-equal? (unfold-session (sess-mu (sess-send (expr-Nat) (sess-svar 0))))
                (sess-send (expr-Nat) (sess-mu (sess-send (expr-Nat) (sess-svar 0))))))

;; ========================================
;; Branch lookup tests
;; ========================================

(define test-branches
  (list (cons 'left (sess-send (expr-Nat) (sess-end)))
        (cons 'right (sess-end))))

(test-case "lookup-branch: left"
  (check-equal? (lookup-branch 'left test-branches)
                (sess-send (expr-Nat) (sess-end))))

(test-case "lookup-branch: right"
  (check-equal? (lookup-branch 'right test-branches)
                (sess-end)))

(test-case "lookup-branch: not found"
  (check-true (sess-branch-error? (lookup-branch 'missing test-branches))))
