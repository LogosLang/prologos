#lang racket/base

;;; test-preduce-phase3.rkt
;;;
;;; Phase 3: lambda as value, static β, fvar inlining (non-recursive).
;;; Differential against nf where applicable.
;;;
;;; Lambda VALUES are not differentially tested — preduce wraps them
;;; in preduce-lam structs while nf returns expr-lam ASTs. Applications
;;; that fully reduce to base values ARE differentially tested.

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
                (format "nf returned ~v, expected ~v (test setup error?)" got-nf expected))
  (check-equal? got-preduce got-nf
                (format "DIFFERENTIAL MISMATCH: preduce=~v nf=~v" got-preduce got-nf)))

;; Identity lambda: (λx. x)
(define id-lam (expr-lam 'mw (expr-Int) (expr-bvar 0)))

;; Add-five: (λx. x+5)
(define add5-lam
  (expr-lam 'mw (expr-Int)
            (expr-int-add (expr-bvar 0) (expr-int 5))))

;; Pair-sum: (λp. fst p + snd p)
(define pair-sum-lam
  (expr-lam 'mw (expr-Sigma (expr-Int) (expr-Int))
            (expr-int-add (expr-fst (expr-bvar 0))
                          (expr-snd (expr-bvar 0)))))

;; ====================================================================
;; Static β
;; ====================================================================

(test-case "identity lambda applied to int"
  (check-preduce/nf (expr-app id-lam (expr-int 42)) (expr-int 42)))

(test-case "(λx. x+5) 10 = 15"
  (check-preduce/nf (expr-app add5-lam (expr-int 10)) (expr-int 15))
  (check-preduce/nf (expr-app add5-lam (expr-int 0))  (expr-int 5))
  (check-preduce/nf (expr-app add5-lam (expr-int -3)) (expr-int 2)))

(test-case "pair-sum lambda applied to literal pair"
  (check-preduce/nf
   (expr-app pair-sum-lam (expr-pair (expr-int 3) (expr-int 4)))
   (expr-int 7)))

(test-case "static β with arg containing arithmetic"
  ;; (λx. x*2) (3+4) = 14
  (define double-lam (expr-lam 'mw (expr-Int)
                               (expr-int-mul (expr-bvar 0) (expr-int 2))))
  (check-preduce/nf
   (expr-app double-lam (expr-int-add (expr-int 3) (expr-int 4)))
   (expr-int 14)))

(test-case "ann-wrapped lambda applies via static β"
  (define annotated (expr-ann add5-lam (expr-Pi 'mw (expr-Int) (expr-Int))))
  (check-preduce/nf (expr-app annotated (expr-int 7)) (expr-int 12)))

;; ====================================================================
;; Higher-order: lambda body uses bvar, preserved correctly
;; ====================================================================

(test-case "nested static β: (λy. (λx. x+y) 3) 10 = 13"
  ;; outer: λy.body  body = (λx. x+y) 3
  ;; inner: λx. x+y  — but bvar 0 = x (innermost), bvar 1 = y (outer)
  (define inner-lam (expr-lam 'mw (expr-Int)
                              (expr-int-add (expr-bvar 0) (expr-bvar 1))))
  (define outer-lam (expr-lam 'mw (expr-Int)
                              (expr-app inner-lam (expr-int 3))))
  (check-preduce/nf (expr-app outer-lam (expr-int 10)) (expr-int 13)))

;; ====================================================================
;; Out-of-scope: dynamic β raises (Phase 4 feature)
;; ====================================================================

(test-case "non-static function position raises preduce-unsupported"
  ;; (λf. f 10) (λx. x+5) — the function position is bvar 0, not statically a lam
  (define apply-lam
    (expr-lam 'mw (expr-Pi 'mw (expr-Int) (expr-Int))
              (expr-app (expr-bvar 0) (expr-int 10))))
  (check-exn preduce-unsupported-node-error?
             (lambda ()
               (preduce (expr-app apply-lam add5-lam)))))

;; ====================================================================
;; Phase 3+ acceptance files (when loaded through global-env)
;; ====================================================================
;;
;; The fvar inlining path is tested via the acceptance files in a
;; separate end-to-end test (test-preduce-acceptance.rkt) that invokes
;; process-file and compares the result. This unit test file focuses
;; on hand-crafted ASTs.
