#lang racket/base

;;;
;;; Tests for refined integer types: PosInt, NegInt, Zero
;;; Phase D.1 + D.3: data types, smart constructors, Eq/Ord instances
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

;; :no-prelude with explicit imports of data types, instances, and trait accessors
(define refined-int-preamble
  (string-append
   "(ns ri :no-prelude)\n"
   "(require [prologos::data::option :refer [Option some none]])\n"
   "(require [prologos::data::refined-int :refer [PosInt pos-int NegInt neg-int Zero mk-zero to-pos-int to-neg-int is-zero? unsafe-pos-int unsafe-neg-int pos-int-val neg-int-val zero-to-int]])\n"
   "(require [prologos::core::refined-int-instances :refer [PosInt--Eq--dict NegInt--Eq--dict Zero--Eq--dict PosInt--Ord--dict NegInt--Ord--dict Zero--Ord--dict]])\n"
   "(require [prologos::core::eq :refer [Eq Eq-eq?]])\n"
   "(require [prologos::core::ord :refer [Ord Ord-compare]])\n"
   "(require [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n"))

(define (ri-ns name)
  (string-replace refined-int-preamble "(ns ri :no-prelude)"
                  (format "(ns ~a :no-prelude)" name)))

;; ========================================
;; 1. Type Formation
;; ========================================

(test-case "refined-int: PosInt type exists"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-tf1)
     "(def x : PosInt (pos-int 5))\n"
     "(eval 0N)\n"))
   "0"))

(test-case "refined-int: NegInt type exists"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-tf2)
     "(def x : NegInt (neg-int -3))\n"
     "(eval 0N)\n"))
   "0"))

(test-case "refined-int: Zero type exists"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-tf3)
     "(def x : Zero mk-zero)\n"
     "(eval 0N)\n"))
   "0"))

;; ========================================
;; 2. Smart Constructors
;; ========================================

(test-case "refined-int: to-pos-int positive → some"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-sc1)
     "(eval (the (Option PosInt) (to-pos-int 5)))\n"))
   "some"))

(test-case "refined-int: to-pos-int negative → none"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-sc2)
     "(eval (the (Option PosInt) (to-pos-int -3)))\n"))
   "none"))

(test-case "refined-int: to-pos-int zero → none"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-sc3)
     "(eval (the (Option PosInt) (to-pos-int 0)))\n"))
   "none"))

(test-case "refined-int: to-neg-int negative → some"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-sc4)
     "(eval (the (Option NegInt) (to-neg-int -7)))\n"))
   "some"))

(test-case "refined-int: to-neg-int positive → none"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-sc5)
     "(eval (the (Option NegInt) (to-neg-int 3)))\n"))
   "none"))

(test-case "refined-int: is-zero? on 0"
  (check-equal?
   (run-ns-last
    (string-append (ri-ns 'ri-sc6)
     "(eval (is-zero? 0))\n"))
   "true : Bool"))

(test-case "refined-int: is-zero? on 5"
  (check-equal?
   (run-ns-last
    (string-append (ri-ns 'ri-sc7)
     "(eval (is-zero? 5))\n"))
   "false : Bool"))

;; ========================================
;; 3. Unsafe Constructors
;; ========================================

(test-case "refined-int: unsafe-pos-int"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-uc1)
     "(eval (the PosInt (unsafe-pos-int 42)))\n"))
   "pos-int"))

(test-case "refined-int: unsafe-neg-int"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-uc2)
     "(eval (the NegInt (unsafe-neg-int -10)))\n"))
   "neg-int"))

;; ========================================
;; 4. Extractors
;; ========================================

(test-case "refined-int: pos-int-val extracts"
  (check-equal?
   (run-ns-last
    (string-append (ri-ns 'ri-ex1)
     "(eval (pos-int-val (pos-int 5)))\n"))
   "5 : Int"))

(test-case "refined-int: neg-int-val extracts"
  (check-equal?
   (run-ns-last
    (string-append (ri-ns 'ri-ex2)
     "(eval (neg-int-val (neg-int -8)))\n"))
   "-8 : Int"))

(test-case "refined-int: zero-to-int"
  (check-equal?
   (run-ns-last
    (string-append (ri-ns 'ri-ex3)
     "(eval (zero-to-int mk-zero))\n"))
   "0 : Int"))

;; ========================================
;; 5. Eq Instances (explicit dict-passing)
;; ========================================

(test-case "refined-int: Eq PosInt equal"
  (check-equal?
   (run-ns-last
    (string-append (ri-ns 'ri-eq1)
     "(eval (Eq-eq? PosInt PosInt--Eq--dict (pos-int 5) (pos-int 5)))\n"))
   "true : Bool"))

(test-case "refined-int: Eq PosInt not equal"
  (check-equal?
   (run-ns-last
    (string-append (ri-ns 'ri-eq2)
     "(eval (Eq-eq? PosInt PosInt--Eq--dict (pos-int 5) (pos-int 7)))\n"))
   "false : Bool"))

(test-case "refined-int: Eq NegInt equal"
  (check-equal?
   (run-ns-last
    (string-append (ri-ns 'ri-eq3)
     "(eval (Eq-eq? NegInt NegInt--Eq--dict (neg-int -3) (neg-int -3)))\n"))
   "true : Bool"))

(test-case "refined-int: Eq NegInt not equal"
  (check-equal?
   (run-ns-last
    (string-append (ri-ns 'ri-eq3b)
     "(eval (Eq-eq? NegInt NegInt--Eq--dict (neg-int -3) (neg-int -7)))\n"))
   "false : Bool"))

(test-case "refined-int: Eq Zero"
  (check-equal?
   (run-ns-last
    (string-append (ri-ns 'ri-eq4)
     "(eval (Eq-eq? Zero Zero--Eq--dict mk-zero mk-zero))\n"))
   "true : Bool"))

;; ========================================
;; 6. Ord Instances (explicit dict-passing)
;; ========================================

(test-case "refined-int: Ord PosInt less"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-ord1)
     "(eval (Ord-compare PosInt PosInt--Ord--dict (pos-int 3) (pos-int 7)))\n"))
   "lt-ord"))

(test-case "refined-int: Ord PosInt equal"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-ord2)
     "(eval (Ord-compare PosInt PosInt--Ord--dict (pos-int 5) (pos-int 5)))\n"))
   "eq-ord"))

(test-case "refined-int: Ord PosInt greater"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-ord3)
     "(eval (Ord-compare PosInt PosInt--Ord--dict (pos-int 10) (pos-int 2)))\n"))
   "gt-ord"))

(test-case "refined-int: Ord NegInt less"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-ord4)
     "(eval (Ord-compare NegInt NegInt--Ord--dict (neg-int -7) (neg-int -3)))\n"))
   "lt-ord"))

(test-case "refined-int: Ord NegInt greater"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-ord5)
     "(eval (Ord-compare NegInt NegInt--Ord--dict (neg-int -1) (neg-int -5)))\n"))
   "gt-ord"))

(test-case "refined-int: Ord Zero always eq"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-ord6)
     "(eval (Ord-compare Zero Zero--Ord--dict mk-zero mk-zero))\n"))
   "eq-ord"))
