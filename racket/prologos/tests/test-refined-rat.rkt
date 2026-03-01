#lang racket/base

;;;
;;; Tests for refined rational types: PosRat, NegRat
;;; Phase D.2 + D.3: data types, smart constructors, Eq/Ord instances
;;;

(require rackunit
         racket/string
         "test-support.rkt"
         "../driver.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (check-contains actual substr [msg #f])
  (define actual-str (if (string? actual) actual (format "~a" actual)))
  (check-true (string-contains? actual-str substr)
              (or msg (format "Expected ~s to contain ~s" actual-str substr))))

;; :no-prelude with explicit imports
(define refined-rat-preamble
  (string-append
   "(ns rr :no-prelude)\n"
   "(require [prologos::data::option :refer [Option some none]])\n"
   "(require [prologos::data::refined-rat :refer [PosRat pos-rat NegRat neg-rat to-pos-rat to-neg-rat is-zero-rat? unsafe-pos-rat unsafe-neg-rat pos-rat-val neg-rat-val]])\n"
   "(require [prologos::core::refined-rat-instances :refer [PosRat--Eq--dict NegRat--Eq--dict PosRat--Ord--dict NegRat--Ord--dict]])\n"
   "(require [prologos::core::eq :refer [Eq Eq-eq?]])\n"
   "(require [prologos::core::ord-trait :refer [Ord Ord-compare]])\n"
   "(require [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n"))

(define (rr-ns name)
  (string-replace refined-rat-preamble "(ns rr :no-prelude)"
                  (format "(ns ~a :no-prelude)" name)))

;; ========================================
;; 1. Smart Constructors
;; ========================================

(test-case "refined-rat: to-pos-rat positive → some"
  (check-contains
   (run-ns-last
    (string-append (rr-ns 'rr-sc1)
     "(eval (the (Option PosRat) (to-pos-rat 3/7)))\n"))
   "some"))

(test-case "refined-rat: to-pos-rat negative → none"
  (check-contains
   (run-ns-last
    (string-append (rr-ns 'rr-sc2)
     "(eval (the (Option PosRat) (to-pos-rat -3/7)))\n"))
   "none"))

(test-case "refined-rat: to-pos-rat zero → none"
  (check-contains
   (run-ns-last
    (string-append (rr-ns 'rr-sc3)
     "(eval (the (Option PosRat) (to-pos-rat 0/1)))\n"))
   "none"))

(test-case "refined-rat: to-neg-rat negative → some"
  (check-contains
   (run-ns-last
    (string-append (rr-ns 'rr-sc4)
     "(eval (the (Option NegRat) (to-neg-rat -5/3)))\n"))
   "some"))

(test-case "refined-rat: to-neg-rat positive → none"
  (check-contains
   (run-ns-last
    (string-append (rr-ns 'rr-sc5)
     "(eval (the (Option NegRat) (to-neg-rat 1/2)))\n"))
   "none"))

(test-case "refined-rat: is-zero-rat? on 0/1"
  (check-equal?
   (run-ns-last
    (string-append (rr-ns 'rr-sc6)
     "(eval (is-zero-rat? 0/1))\n"))
   "true : Bool"))

(test-case "refined-rat: is-zero-rat? on 3/7"
  (check-equal?
   (run-ns-last
    (string-append (rr-ns 'rr-sc7)
     "(eval (is-zero-rat? 3/7))\n"))
   "false : Bool"))

;; ========================================
;; 2. Unsafe Constructors + Extractors
;; ========================================

(test-case "refined-rat: unsafe-pos-rat + extract"
  (check-contains
   (run-ns-last
    (string-append (rr-ns 'rr-uc1)
     "(eval (pos-rat-val (unsafe-pos-rat 7/3)))\n"))
   "7/3"))

(test-case "refined-rat: unsafe-neg-rat + extract"
  (check-contains
   (run-ns-last
    (string-append (rr-ns 'rr-uc2)
     "(eval (neg-rat-val (unsafe-neg-rat -2/5)))\n"))
   "-2/5"))

;; ========================================
;; 3. Eq Instances (explicit dict-passing)
;; ========================================

(test-case "refined-rat: Eq PosRat equal"
  (check-equal?
   (run-ns-last
    (string-append (rr-ns 'rr-eq1)
     "(eval (Eq-eq? PosRat PosRat--Eq--dict (pos-rat 3/7) (pos-rat 3/7)))\n"))
   "true : Bool"))

(test-case "refined-rat: Eq PosRat not equal"
  (check-equal?
   (run-ns-last
    (string-append (rr-ns 'rr-eq2)
     "(eval (Eq-eq? PosRat PosRat--Eq--dict (pos-rat 1/2) (pos-rat 3/4)))\n"))
   "false : Bool"))

(test-case "refined-rat: Eq NegRat equal"
  (check-equal?
   (run-ns-last
    (string-append (rr-ns 'rr-eq3)
     "(eval (Eq-eq? NegRat NegRat--Eq--dict (neg-rat -5/3) (neg-rat -5/3)))\n"))
   "true : Bool"))

(test-case "refined-rat: Eq NegRat not equal"
  (check-equal?
   (run-ns-last
    (string-append (rr-ns 'rr-eq4)
     "(eval (Eq-eq? NegRat NegRat--Eq--dict (neg-rat -1/2) (neg-rat -3/4)))\n"))
   "false : Bool"))

;; ========================================
;; 4. Ord Instances (explicit dict-passing)
;; ========================================

(test-case "refined-rat: Ord PosRat less"
  (check-contains
   (run-ns-last
    (string-append (rr-ns 'rr-ord1)
     "(eval (Ord-compare PosRat PosRat--Ord--dict (pos-rat 1/4) (pos-rat 3/4)))\n"))
   "lt-ord"))

(test-case "refined-rat: Ord PosRat equal"
  (check-contains
   (run-ns-last
    (string-append (rr-ns 'rr-ord2)
     "(eval (Ord-compare PosRat PosRat--Ord--dict (pos-rat 1/2) (pos-rat 1/2)))\n"))
   "eq-ord"))

(test-case "refined-rat: Ord PosRat greater"
  (check-contains
   (run-ns-last
    (string-append (rr-ns 'rr-ord3)
     "(eval (Ord-compare PosRat PosRat--Ord--dict (pos-rat 3/4) (pos-rat 1/4)))\n"))
   "gt-ord"))

(test-case "refined-rat: Ord NegRat less"
  (check-contains
   (run-ns-last
    (string-append (rr-ns 'rr-ord4)
     "(eval (Ord-compare NegRat NegRat--Ord--dict (neg-rat -3/4) (neg-rat -1/4)))\n"))
   "lt-ord"))

(test-case "refined-rat: Ord NegRat greater"
  (check-contains
   (run-ns-last
    (string-append (rr-ns 'rr-ord5)
     "(eval (Ord-compare NegRat NegRat--Ord--dict (neg-rat -1/5) (neg-rat -4/5)))\n"))
   "gt-ord"))
