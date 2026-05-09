#lang racket/base

;;; test-preduce-phase5.rkt
;;;
;;; Phase 5: eliminators (boolrec, natrec, J refl-only iota).
;;; This is the phase where recursive computation becomes terminating
;;; (eliminators dispatch on constructors → base case fires → recursion
;;; halts). Factorial / sum-to-N / fibonacci all become runnable.

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

;; ====================================================================
;; boolrec
;; ====================================================================

(test-case "boolrec on literal true / false"
  (check-preduce/nf (expr-boolrec (expr-Int) (expr-int 1) (expr-int 2) (expr-true))
                    (expr-int 1))
  (check-preduce/nf (expr-boolrec (expr-Int) (expr-int 1) (expr-int 2) (expr-false))
                    (expr-int 2)))

(test-case "boolrec target via int comparison"
  (check-preduce/nf
   (expr-boolrec (expr-Int) (expr-int 100) (expr-int 200)
                 (expr-int-lt (expr-int 3) (expr-int 5)))
   (expr-int 100))
  (check-preduce/nf
   (expr-boolrec (expr-Int) (expr-int 100) (expr-int 200)
                 (expr-int-lt (expr-int 5) (expr-int 3)))
   (expr-int 200)))

(test-case "boolrec arms compute"
  ;; if (3+4 == 7) then (10*10) else (-1)
  (check-preduce/nf
   (expr-boolrec (expr-Int)
                 (expr-int-mul (expr-int 10) (expr-int 10))
                 (expr-int -1)
                 (expr-int-eq (expr-int-add (expr-int 3) (expr-int 4))
                              (expr-int 7)))
   (expr-int 100)))

;; ====================================================================
;; natrec — base case
;; ====================================================================

(test-case "natrec base case (zero / nat-val 0)"
  (define dummy-step
    (expr-lam 'mw (expr-Nat)
              (expr-lam 'mw (expr-Nat) (expr-bvar 0))))
  (check-preduce/nf
   (expr-natrec (expr-Nat) (expr-nat-val 42) dummy-step (expr-nat-val 0))
   (expr-nat-val 42))
  (check-preduce/nf
   (expr-natrec (expr-Nat) (expr-nat-val 42) dummy-step (expr-zero))
   (expr-nat-val 42)))

;; ====================================================================
;; natrec — recursive (sum-to-N pattern)
;; ====================================================================

(test-case "natrec sum 5: 1+2+3+4+5 = 15"
  ;; sum 0 = 0; sum (suc k) = (suc k) + sum k = (k+1) + sum k
  ;; step is (λk. λrec. (k+1) + rec)
  (define step
    (expr-lam 'mw (expr-Nat)
              (expr-lam 'mw (expr-Nat)
                        (expr-int-add (expr-suc (expr-bvar 1)) (expr-bvar 0)))))
  (check-preduce/nf
   (expr-natrec (expr-Nat) (expr-nat-val 0) step (expr-nat-val 5))
   (expr-int 15)))

(test-case "natrec factorial 5 = 120"
  ;; fact 0 = 1; fact (suc k) = (suc k) * fact k = (k+1) * rec
  (define step
    (expr-lam 'mw (expr-Nat)
              (expr-lam 'mw (expr-Nat)
                        (expr-int-mul (expr-suc (expr-bvar 1)) (expr-bvar 0)))))
  (check-preduce/nf
   (expr-natrec (expr-Nat) (expr-nat-val 1) step (expr-nat-val 5))
   (expr-int 120)))

(test-case "natrec factorial 6 = 720"
  (define step
    (expr-lam 'mw (expr-Nat)
              (expr-lam 'mw (expr-Nat)
                        (expr-int-mul (expr-suc (expr-bvar 1)) (expr-bvar 0)))))
  (check-preduce/nf
   (expr-natrec (expr-Nat) (expr-nat-val 1) step (expr-nat-val 6))
   (expr-int 720)))

;; ====================================================================
;; J (refl-only iota)
;; ====================================================================

(test-case "J on refl applies base to left"
  ;; J motive (λx. x+1) 5 5 refl  =  ((λx. x+1) 5) = 6
  (define base (expr-lam 'mw (expr-Int)
                         (expr-int-add (expr-bvar 0) (expr-int 1))))
  (check-preduce/nf
   (expr-J (expr-Type 0) base (expr-int 5) (expr-int 5) (expr-refl))
   (expr-int 6)))
