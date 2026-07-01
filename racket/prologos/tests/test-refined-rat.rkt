#lang racket/base

;;;
;;; Tests for refined rational types: PosRat, NegRat
;;; Numerics N5de (Q6 erasure): refined types are BUILTIN nominal-erased (a PosRat IS a Rat).
;;; Constructors are unsafe-*/`the`; the `data` ctors and refined Eq/Ord dicts are gone.
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

;; :no-prelude preamble — erased refined-rat surface (functions). PosRat/NegRat builtin.
(define refined-rat-preamble
  (string-append
   "(ns rr :no-prelude)\n"
   "(imports [prologos::data::option :refer [Option some none]])\n"
   "(imports [prologos::data::refined-rat :refer [to-pos-rat to-neg-rat is-zero-rat? unsafe-pos-rat unsafe-neg-rat pos-rat-val neg-rat-val]])\n"))

(define (rr-ns name)
  (string-replace refined-rat-preamble "(ns rr :no-prelude)"
                  (format "(ns ~a :no-prelude)" name)))

;; Prelude-free preamble for sign arithmetic (bare +/negate keywords; see test-refined-int).
(define (rr-arith-ns name)
  (string-append
   (format "(ns ~a :no-prelude)\n" name)
   "(imports [prologos::data::refined-rat :refer [unsafe-pos-rat unsafe-neg-rat]])\n"))

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
;; 2. Unsafe Constructors + Extractors (erased identity → base Rat)
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
   "-0.4"))

(test-case "refined-rat: unsafe-pos-rat display : PosRat"
  (check-contains
   (run-ns-last
    (string-append (rr-ns 'rr-uc3)
     "(eval (the PosRat (unsafe-pos-rat 7/3)))\n"))
   "PosRat"))

;; ========================================
;; 3. Subsumption (PosRat <: Rat; value erased to base)
;; ========================================

(test-case "refined-rat: PosRat subsumes to Rat"
  (check-contains
   (run-ns-last
    (string-append (rr-ns 'rr-sub1)
     "(def r : Rat (unsafe-pos-rat 3/7))\n"
     "(eval r)\n"))
   "Rat"))

;; ========================================
;; 4. Sign-preserving arithmetic (N5de transfer; bare keywords)
;; ========================================

(test-case "refined-rat: PosRat + PosRat = PosRat"
  (check-contains
   (run-ns-last
    (string-append (rr-arith-ns 'rr-ar1)
     "(eval (+ (unsafe-pos-rat 1/2) (unsafe-pos-rat 1/4)))\n"))
   "PosRat"))

(test-case "refined-rat: negate PosRat = NegRat"
  (check-contains
   (run-ns-last
    (string-append (rr-arith-ns 'rr-ar2)
     "(eval (negate (unsafe-pos-rat 1/2)))\n"))
   "NegRat"))

(test-case "refined-rat: PosRat * NegRat = NegRat"
  (check-contains
   (run-ns-last
    (string-append (rr-arith-ns 'rr-ar3)
     "(eval (* (unsafe-pos-rat 2/3) (unsafe-neg-rat -3/5)))\n"))
   "NegRat"))
