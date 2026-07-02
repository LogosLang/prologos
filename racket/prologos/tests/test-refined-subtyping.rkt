#lang racket/base

;;;
;;; Tests for refined numeric subtyping (Numerics N5de)
;;; PosInt <: Int <: Rat, NegInt <: Int <: Rat, Zero <: Int <: Rat
;;; PosRat <: Rat, NegRat <: Rat
;;; Refined types are BUILTIN nominal-erased (a PosInt IS an Int); constructors are unsafe-*/`the`.
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

;; Preamble importing the erased refined-int + refined-rat surface (functions).
;; PosInt/NegInt/Zero/PosRat/NegRat are builtin type names (no import needed).
(define refined-preamble
  (string-append
   "(ns rs :no-prelude)\n"
   "(imports [prologos::data::option :refer [Option some none]])\n"
   "(imports [prologos::data::refined-int :refer [to-pos-int to-neg-int is-zero? unsafe-pos-int unsafe-neg-int pos-int-val neg-int-val zero-to-int mk-zero]])\n"
   "(imports [prologos::data::refined-rat :refer [to-pos-rat to-neg-rat pos-rat-val neg-rat-val unsafe-pos-rat unsafe-neg-rat]])\n"))

(define (rs-ns name)
  (string-replace refined-preamble "(ns rs :no-prelude)"
                  (format "(ns ~a :no-prelude)" name)))

;; ========================================
;; A. Type checker acceptance: refined where base expected
;; ========================================

(test-case "refined-sub/posint-as-int"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-a1)
     "(def x : Int (unsafe-pos-int 5))\n"
     "(eval x)\n"))
   "Int"))

(test-case "refined-sub/negint-as-int"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-a2)
     "(def x : Int (unsafe-neg-int -3))\n"
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
     "(def x : Rat (unsafe-pos-int 7))\n"
     "(eval x)\n"))
   "Rat"))

(test-case "refined-sub/posrat-as-rat"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-a5)
     "(def x : Rat (unsafe-pos-rat 3/7))\n"
     "(eval x)\n"))
   "Rat"))

(test-case "refined-sub/negrat-as-rat"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-a6)
     "(def x : Rat (unsafe-neg-rat -5/3))\n"
     "(eval x)\n"))
   "Rat"))

;; ========================================
;; B. Runtime coercion: primitive arithmetic with refined types (erased → base)
;; ========================================

(test-case "refined-sub/posint-in-int-add"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-b1)
     "(eval (int+ (unsafe-pos-int 5) 3))\n"))
   "8 : Int"))

(test-case "refined-sub/negint-in-int-add"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-b2)
     "(eval (int+ (unsafe-neg-int -3) 10))\n"))
   "7 : Int"))

(test-case "refined-sub/zero-in-int-add"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-b3)
     "(eval (int+ mk-zero 7))\n"))
   "7 : Int"))

(test-case "refined-sub/posrat-in-rat-add"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-b4)
     "(eval (rat+ (unsafe-pos-rat 1/2) 3/4))\n"))
   "5/4 : Rat"))

(test-case "refined-sub/negrat-in-rat-mul"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-b5)
     "(eval (rat* (unsafe-neg-rat -2/3) 3))\n"))
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
     "(eval (f (unsafe-pos-int 42)))\n"))
   "42"))

(test-case "refined-sub/negint-to-int-param"
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-c2)
     "(defn g [x : Int] <Int> x)\n"
     "(eval (g (unsafe-neg-int -7)))\n"))
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

(test-case "refined-sub/extractors-still-work"
  ;; pos-int-val is the erased identity → base Int
  (check-equal?
   (run-ns-last
    (string-append (rs-ns 'rs-e3)
     "(eval (pos-int-val (unsafe-pos-int 42)))\n"))
   "42 : Int"))

(test-case "refined-sub/smart-constructors-still-work"
  ;; to-pos-int still validates
  (check-contains
   (run-ns-last
    (string-append (rs-ns 'rs-e4)
     "(eval (the (Option PosInt) (to-pos-int 5)))\n"))
   "some"))
