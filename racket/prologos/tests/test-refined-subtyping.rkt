#lang racket/base

;;;
;;; Tests for refined numeric subtyping (Phase E)
;;; PosInt <: Int <: Rat, NegInt <: Int <: Rat, Zero <: Int <: Rat
;;; PosRat <: Rat, NegRat <: Rat
;;;

(require rackunit
         racket/list
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

;; Preamble that imports refined-int + refined-rat
(define refined-preamble
  (string-append
   "(ns rs :no-prelude)\n"
   "(require [prologos::data::option :refer [Option some none]])\n"
   "(require [prologos::data::refined-int :refer [PosInt pos-int NegInt neg-int Zero mk-zero to-pos-int to-neg-int is-zero? unsafe-pos-int unsafe-neg-int pos-int-val neg-int-val zero-to-int]])\n"
   "(require [prologos::data::refined-rat :refer [PosRat pos-rat NegRat neg-rat to-pos-rat to-neg-rat pos-rat-val neg-rat-val unsafe-pos-rat unsafe-neg-rat]])\n"))

(define (rs-ns name)
  (string-replace refined-preamble "(ns rs :no-prelude)"
                  (format "(ns ~a :no-prelude)" name)))

;; ========================================
;; A. Type checker acceptance: PosInt where Int expected
;; ========================================

(test-case "refined-sub/posint-as-int"
  ;; (def x : Int (pos-int 5)) should type-check
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-a1)
     "(def x : Int (pos-int 5))\n"
     "(eval x)\n"))
   "Int"))

(test-case "refined-sub/negint-as-int"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-a2)
     "(def x : Int (neg-int -3))\n"
     "(eval x)\n"))
   "Int"))

(test-case "refined-sub/zero-as-int"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-a3)
     "(def x : Int mk-zero)\n"
     "(eval x)\n"))
   "Int"))

(test-case "refined-sub/posint-as-rat-transitive"
  ;; PosInt <: Int <: Rat → PosInt <: Rat (transitive)
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-a4)
     "(def x : Rat (pos-int 7))\n"
     "(eval x)\n"))
   "Rat"))

(test-case "refined-sub/posrat-as-rat"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-a5)
     "(def x : Rat (pos-rat 3/7))\n"
     "(eval x)\n"))
   "Rat"))

(test-case "refined-sub/negrat-as-rat"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-a6)
     "(def x : Rat (neg-rat -5/3))\n"
     "(eval x)\n"))
   "Rat"))

;; ========================================
;; B. Runtime coercion: arithmetic with refined types
;; ========================================

(test-case "refined-sub/posint-in-int-add"
  ;; (int+ (pos-int 5) 3) → 8 : Int
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-b1)
     "(eval (int+ (pos-int 5) 3))\n"))
   "8 : Int"))

(test-case "refined-sub/negint-in-int-add"
  ;; (int+ (neg-int -3) 10) → 7 : Int
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-b2)
     "(eval (int+ (neg-int -3) 10))\n"))
   "7 : Int"))

(test-case "refined-sub/zero-in-int-add"
  ;; (int+ mk-zero 7) → 7 : Int
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-b3)
     "(eval (int+ mk-zero 7))\n"))
   "7 : Int"))

(test-case "refined-sub/posrat-in-rat-add"
  ;; (rat+ (pos-rat 1/2) 3/4) → 5/4 : Rat
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-b4)
     "(eval (rat+ (pos-rat 1/2) 3/4))\n"))
   "5/4 : Rat"))

(test-case "refined-sub/negrat-in-rat-mul"
  ;; (rat* (neg-rat -2/3) 3) → -2 : Rat
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-b5)
     "(eval (rat* (neg-rat -2/3) 3))\n"))
   "-2 : Rat"))

;; ========================================
;; C. Function parameter subtyping
;; ========================================

(test-case "refined-sub/posint-to-int-param"
  ;; Function expecting Int should accept PosInt
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-c1)
     "(defn f [x : Int] <Int> x)\n"
     "(eval (f (pos-int 42)))\n"))
   "42"))

(test-case "refined-sub/negint-to-int-param"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-c2)
     "(defn g [x : Int] <Int> x)\n"
     "(eval (g (neg-int -7)))\n"))
   "-7"))

;; ========================================
;; D. Rejection tests (narrowing NOT allowed)
;; ========================================

(test-case "refined-sub/int-not-subtype-of-posint"
  ;; Int is NOT a subtype of PosInt — should fail
  (define result
    (run-ns-last
     (string-append (rs-ns 'rs-d1)
      "(check (the Int 5) : PosInt)\n")))
  ;; Should not contain OK/✓
  (check-false (and (string? result)
                    (or (string-contains? result "✓")
                        (string-contains? result "OK")))))

;; ========================================
;; E. Backward compatibility
;; ========================================

(test-case "refined-sub/nat-still-subtype-of-int"
  ;; Existing Nat <: Int subtyping should still work
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-e1)
     "(def x : Int (suc zero))\n"
     "(eval x)\n"))
   "Int"))

(test-case "refined-sub/existing-refined-ops-work"
  ;; Existing refined type Eq/Ord operations still work
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-e2)
     "(require [prologos::core::refined-int-instances :refer [PosInt--Eq--dict]])\n"
     "(require [prologos::core::eq-trait :refer [Eq Eq-eq?]])\n"
     "(eval (Eq-eq? PosInt PosInt--Eq--dict (pos-int 5) (pos-int 5)))\n"))
   "true"))

(test-case "refined-sub/extractors-still-work"
  ;; pos-int-val, neg-int-val still work normally
  (check-equal?
   (run-ns-last
    (string-append (rs-ns 'rs-e3)
     "(eval (pos-int-val (pos-int 42)))\n"))
   "42 : Int"))

(test-case "refined-sub/smart-constructors-still-work"
  ;; to-pos-int still validates
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-e4)
     "(eval (the (Option PosInt) (to-pos-int 5)))\n"))
   "some"))
