#lang racket/base

;;; test-preduce-hybrid-phase8b.rkt
;;;
;;; Phase 8b — extended differential gate over preduce-hybrid's
;;; expanded scope: lambda + app (static + dynamic β), pairs +
;;; projection, boolrec, fvar inlining. Three-way differential
;;; (nf ≡ preduce ≡ preduce-hybrid) on every supported term.

(require rackunit
         "../syntax.rkt"
         "../preduce.rkt"
         "../preduce-hybrid.rkt"
         "../runtime-bridge.rkt"
         (only-in "../reduction.rkt" nf))

(unless (hybrid-runtime-available?)
  (printf "[skip] test-preduce-hybrid-phase8b.rkt: \
libprologos-runtime-hybrid.so not built; \
skipping Phase 8b extended tests.~n")
  (exit 0))

(define (check-three-way e expected)
  (define got-preduce (preduce e))
  (define got-nf (nf e))
  (define got-hybrid (preduce-hybrid e))
  (check-equal? got-preduce expected)
  (check-equal? got-nf expected)
  (check-equal? got-hybrid expected
                (format "preduce-hybrid returned ~v, expected ~v" got-hybrid expected))
  (check-equal? got-nf got-hybrid
                (format "DIFFERENTIAL: nf=~v hybrid=~v" got-nf got-hybrid)))

;; ====================================================================
;; Static β
;; ====================================================================

(define add5 (expr-lam 'mw (expr-Int) (expr-int-add (expr-bvar 0) (expr-int 5))))
(define double (expr-lam 'mw (expr-Int) (expr-int-mul (expr-bvar 0) (expr-int 2))))

(test-case "static β: identity lambda"
  (check-three-way (expr-app (expr-lam 'mw (expr-Int) (expr-bvar 0)) (expr-int 42))
                   (expr-int 42)))

(test-case "static β: add-five"
  (check-three-way (expr-app add5 (expr-int 10)) (expr-int 15))
  (check-three-way (expr-app add5 (expr-int -3)) (expr-int 2)))

(test-case "static β: double over arithmetic arg"
  (check-three-way (expr-app double (expr-int-add (expr-int 3) (expr-int 4)))
                   (expr-int 14)))

(test-case "nested static β: (λy. (λx. x+y) 3) 10 = 13"
  (define inner (expr-lam 'mw (expr-Int)
                          (expr-int-add (expr-bvar 0) (expr-bvar 1))))
  (define outer (expr-lam 'mw (expr-Int)
                          (expr-app inner (expr-int 3))))
  (check-three-way (expr-app outer (expr-int 10)) (expr-int 13)))

;; ====================================================================
;; Dynamic β (function position is bvar)
;; ====================================================================

(test-case "dynamic β: (λf. f 10) (λx. x+5) = 15"
  (define apply10 (expr-lam 'mw (expr-Pi 'mw (expr-Int) (expr-Int))
                            (expr-app (expr-bvar 0) (expr-int 10))))
  (check-three-way (expr-app apply10 add5) (expr-int 15)))

(test-case "dynamic β: twice — (λf. f (f 3)) (λx. x+5) = 13"
  (define twice (expr-lam 'mw (expr-Pi 'mw (expr-Int) (expr-Int))
                          (expr-app (expr-bvar 0)
                                    (expr-app (expr-bvar 0) (expr-int 3)))))
  (check-three-way (expr-app twice add5) (expr-int 13)))

;; ====================================================================
;; Pairs
;; ====================================================================

(test-case "pair construction + fst/snd projection"
  (check-three-way (expr-fst (expr-pair (expr-int 100) (expr-int 200)))
                   (expr-int 100))
  (check-three-way (expr-snd (expr-pair (expr-int 100) (expr-int 200)))
                   (expr-int 200)))

(test-case "nested pair fst-of-fst"
  (check-three-way
   (expr-fst (expr-fst (expr-pair (expr-pair (expr-int 1) (expr-int 2)) (expr-int 3))))
   (expr-int 1)))

(test-case "pair component computed via arithmetic"
  ;; fst (pair (1+2) (3*4)) = 3
  (check-three-way
   (expr-fst (expr-pair (expr-int-add (expr-int 1) (expr-int 2))
                        (expr-int-mul (expr-int 3) (expr-int 4))))
   (expr-int 3)))

;; ====================================================================
;; boolrec
;; ====================================================================

(test-case "boolrec on literal true / false"
  (check-three-way
   (expr-boolrec (expr-Int) (expr-int 1) (expr-int 2) (expr-true))
   (expr-int 1))
  (check-three-way
   (expr-boolrec (expr-Int) (expr-int 1) (expr-int 2) (expr-false))
   (expr-int 2)))

(test-case "boolrec target via int comparison"
  (check-three-way
   (expr-boolrec (expr-Int) (expr-int 100) (expr-int 200)
                 (expr-int-lt (expr-int 3) (expr-int 5)))
   (expr-int 100))
  (check-three-way
   (expr-boolrec (expr-Int) (expr-int 100) (expr-int 200)
                 (expr-int-lt (expr-int 5) (expr-int 3)))
   (expr-int 200)))

;; ====================================================================
;; Profile inspection — Phase 10 prep
;; ====================================================================

(test-case "Phase 10 prep — multiple Racket-callback fire-fns observable in profile"
  (prologos_set_profile_per_tag 1)
  ;; Run a program that exercises multiple fire-fn types
  (define pgm (expr-app
               (expr-lam 'mw (expr-Int)
                         (expr-boolrec (expr-Int)
                                       (expr-int-mul (expr-bvar 0) (expr-int 2))
                                       (expr-int 0)
                                       (expr-int-lt (expr-int 0) (expr-bvar 0))))
               (expr-int 7)))
  (define _ (preduce-hybrid pgm))
  ;; After: at least one Racket-callback fire-fn (boolrec or app-bridge)
  ;; should have callback_count > 0
  (define total-callbacks
    (for/sum ([t (in-range 256)])
      (prologos_get_stat (stat-callbacks-by-tag t))))
  (check-true (> total-callbacks 0)
              "expected at least one Racket-callback fire-fn to be tracked in profile"))
