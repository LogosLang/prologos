#lang racket/base

;;; test-preduce-phase4.rkt
;;;
;;; Phase 4: dynamic β — applications where the function position is
;;; not statically a lambda (it's a bvar carrying a lambda value, the
;;; result of another application, or a self-recursive fvar).
;;;
;;; Recursion via Phase 4 alone (no eliminator) is non-terminating and
;;; not tested here; recursion + termination via Phase 5 eliminators
;;; lands together in test-preduce-phase5.rkt + factorial in the
;;; acceptance tests.

(require rackunit
         "../syntax.rkt"
         "../preduce.rkt"
         (only-in "../reduction.rkt" nf))

(define (check-preduce/nf e expected)
  (define got-preduce (preduce e))
  (define got-nf (nf e))
  (check-equal? got-preduce expected
                (format "preduce returned ~v, expected ~v" got-preduce expected))
  (check-equal? got-nf expected
                (format "nf returned ~v, expected ~v" got-nf expected))
  (check-equal? got-preduce got-nf
                (format "DIFFERENTIAL: preduce=~v nf=~v" got-preduce got-nf)))

(define add5
  (expr-lam 'mw (expr-Int) (expr-int-add (expr-bvar 0) (expr-int 5))))

(define double
  (expr-lam 'mw (expr-Int) (expr-int-mul (expr-bvar 0) (expr-int 2))))

;; ====================================================================
;; Higher-order: lambda receives lambda
;; ====================================================================

(test-case "(λf. f 10) (λx. x+5) = 15"
  (define apply10
    (expr-lam 'mw (expr-Pi 'mw (expr-Int) (expr-Int))
              (expr-app (expr-bvar 0) (expr-int 10))))
  (check-preduce/nf (expr-app apply10 add5) (expr-int 15)))

(test-case "(λf. f (f 3)) (λx. x+5) = 13"
  ;; apply f twice: f (f 3) = (3+5)+5 = 13
  (define twice
    (expr-lam 'mw (expr-Pi 'mw (expr-Int) (expr-Int))
              (expr-app (expr-bvar 0) (expr-app (expr-bvar 0) (expr-int 3)))))
  (check-preduce/nf (expr-app twice add5) (expr-int 13)))

(test-case "compose: (λf. λg. λx. f (g x)) double add5 7 = 24"
  ;; compose f g x = f (g x); double (add5 7) = double 12 = 24
  (define compose
    (expr-lam 'mw (expr-Pi 'mw (expr-Int) (expr-Int))
              (expr-lam 'mw (expr-Pi 'mw (expr-Int) (expr-Int))
                        (expr-lam 'mw (expr-Int)
                                  (expr-app (expr-bvar 2)
                                            (expr-app (expr-bvar 1) (expr-bvar 0)))))))
  (check-preduce/nf
   (expr-app (expr-app (expr-app compose double) add5) (expr-int 7))
   (expr-int 24)))

;; ====================================================================
;; Lambda returned from a lambda (curried application via dynamic β)
;; ====================================================================

(test-case "curried: ((λx. λy. x+y) 3) 4 = 7"
  ;; Outer apply is static (function pos is literal lam) → static β
  ;; produces a lambda value (because body is lam). Inner apply is
  ;; static again. Both static — handled in Phase 3 already, but we
  ;; assert here it still works.
  (define add
    (expr-lam 'mw (expr-Int)
              (expr-lam 'mw (expr-Int)
                        (expr-int-add (expr-bvar 1) (expr-bvar 0)))))
  (check-preduce/nf
   (expr-app (expr-app add (expr-int 3)) (expr-int 4))
   (expr-int 7)))

(test-case "dynamic curried: bvar holding partial app"
  ;; (λadd-fn. add-fn 4) ((λx. λy. x+y) 3) — the inner ((λx. λy. x+y) 3)
  ;; static-βs to a lambda value bound to bvar 0 in the outer.
  ;; Then bvar 0 applied to 4 — function position is bvar → dynamic β.
  (define add
    (expr-lam 'mw (expr-Int)
              (expr-lam 'mw (expr-Int)
                        (expr-int-add (expr-bvar 1) (expr-bvar 0)))))
  (define apply-to-4
    (expr-lam 'mw (expr-Pi 'mw (expr-Int) (expr-Int))
              (expr-app (expr-bvar 0) (expr-int 4))))
  (check-preduce/nf
   (expr-app apply-to-4 (expr-app add (expr-int 3)))
   (expr-int 7)))

;; ====================================================================
;; Captured env: lambda body references outer bvar through closure
;; ====================================================================

(test-case "(λx. (λy. x+y) 5) 10 = 15 — captured env propagates"
  ;; Outer x = 10. Inner closure captures x = bvar 1 (after entering
  ;; inner). Inner applied to 5 → bvar 0 = 5. Sum = 15.
  (define inner
    (expr-lam 'mw (expr-Int)
              (expr-int-add (expr-bvar 1) (expr-bvar 0))))
  (define outer
    (expr-lam 'mw (expr-Int)
              (expr-app inner (expr-int 5))))
  (check-preduce/nf (expr-app outer (expr-int 10)) (expr-int 15)))
