#lang racket/base

;;;
;;; Tests for refined integer types: PosInt, NegInt, Zero
;;; Numerics N5de (Q6 erasure): refined types are BUILTIN nominal-erased types
;;; (a PosInt IS an Int at runtime — no wrapper). Constructors are unsafe-*/`the`;
;;; the `data` ctors (pos-int/neg-int) and refined Eq/Ord dicts are gone (a refined
;;; value uses its base Eq/Ord). Type names are builtin → not imported.
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

;; :no-prelude preamble — only the erased refined-int surface (functions).
;; PosInt/NegInt/Zero are builtin type names (available without import).
(define refined-int-preamble
  (string-append
   "(ns ri :no-prelude)\n"
   "(imports [prologos::data::option :refer [Option some none]])\n"
   "(imports [prologos::data::refined-int :refer [to-pos-int to-neg-int is-zero? unsafe-pos-int unsafe-neg-int pos-int-val neg-int-val zero-to-int mk-zero]])\n"))

(define (ri-ns name)
  (string-replace refined-int-preamble "(ns ri :no-prelude)"
                  (format "(ns ~a :no-prelude)" name)))

;; :no-prelude preamble for sign-preserving arithmetic. The sign-transfer (N5de STEP 4)
;; lives on the keyword→numeric-join path (typing-core generic-arith); under the prelude
;; the Add/Neg/Abs *trait dicts* (A→A) intercept +/negate/abs and bypass it. :no-prelude
;; keeps +/negate/abs as bare parser keywords → the transfer fires. PosInt/NegInt builtin.
(define (ri-arith-ns name)
  (string-append
   (format "(ns ~a :no-prelude)\n" name)
   "(imports [prologos::data::refined-int :refer [unsafe-pos-int unsafe-neg-int]])\n"))

;; ========================================
;; 1. Type Formation (erased constructors)
;; ========================================

(test-case "refined-int: PosInt type exists"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-tf1)
     "(def x : PosInt (unsafe-pos-int 5))\n"
     "(eval 0N)\n"))
   "0"))

(test-case "refined-int: NegInt type exists"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-tf2)
     "(def x : NegInt (unsafe-neg-int -3))\n"
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
;; 3. Unsafe Constructors (display: <v> : PosInt)
;; ========================================

(test-case "refined-int: unsafe-pos-int"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-uc1)
     "(eval (the PosInt (unsafe-pos-int 42)))\n"))
   "42 : PosInt"))

(test-case "refined-int: unsafe-neg-int"
  (check-contains
   (run-ns-last
    (string-append (ri-ns 'ri-uc2)
     "(eval (the NegInt (unsafe-neg-int -10)))\n"))
   "-10 : NegInt"))

;; ========================================
;; 4. Extractors (erased identity → base Int)
;; ========================================

(test-case "refined-int: pos-int-val extracts"
  (check-equal?
   (run-ns-last
    (string-append (ri-ns 'ri-ex1)
     "(eval (pos-int-val (unsafe-pos-int 5)))\n"))
   "5 : Int"))

(test-case "refined-int: neg-int-val extracts"
  (check-equal?
   (run-ns-last
    (string-append (ri-ns 'ri-ex2)
     "(eval (neg-int-val (unsafe-neg-int -8)))\n"))
   "-8 : Int"))

(test-case "refined-int: zero-to-int"
  (check-equal?
   (run-ns-last
    (string-append (ri-ns 'ri-ex3)
     "(eval (zero-to-int mk-zero))\n"))
   "0 : Int"))

;; ========================================
;; 5. Subsumption (PosInt <: Int; value erased to base)
;; ========================================

(test-case "refined-int: PosInt subsumes to Int"
  (check-equal?
   (run-ns-last
    (string-append (ri-ns 'ri-sub1)
     "(def i : Int (unsafe-pos-int 5))\n"
     "(eval i)\n"))
   "5 : Int"))

;; ========================================
;; 6. Sign-preserving arithmetic (N5de transfer; prelude ns)
;; ========================================

(test-case "refined-int: PosInt + PosInt = PosInt"
  (check-contains
   (run-ns-last
    (string-append (ri-arith-ns 'ri-ar1)
     "(eval (+ (unsafe-pos-int 3) (unsafe-pos-int 4)))\n"))
   "7 : PosInt"))

(test-case "refined-int: negate PosInt = NegInt"
  (check-contains
   (run-ns-last
    (string-append (ri-arith-ns 'ri-ar2)
     "(eval (negate (unsafe-pos-int 5)))\n"))
   "NegInt"))

(test-case "refined-int: abs NegInt = PosInt"
  (check-contains
   (run-ns-last
    (string-append (ri-arith-ns 'ri-ar3)
     "(eval (abs (unsafe-neg-int -3)))\n"))
   "PosInt"))
