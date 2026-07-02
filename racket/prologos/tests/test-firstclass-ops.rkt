#lang racket/base

;;;
;;; Tests for first-class ops — Numerics N6e (D-N6.6).
;;;
;;; E1 (M1): full implicit instantiation on bare reference — a bare
;;; where-constrained name (derived trait methods, to-X, user where-fns)
;;; referenced in argument position now auto-inserts its m0 type holes AND
;;; mw dict holes (elaborator maybe-auto-apply-implicits), so HOF use works.
;;; Previously these elaborated as raw fvars whose erased type binders
;;; consumed the HOF's arguments — silent typed garbage (miscompilation).
;;; Pure-m0-mixed names WITHOUT where-constraints (cons) stay un-applied
;;; (long-standing decision, unchanged).
;;;
;;; Grows with E2 (ops as trait values), E3 (sections), E4 (eta extension).
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

(define (ws-all . lines)
  (run-ns-ws-all (string-join (cons "ns t" lines) "\n")))

;; ========================================
;; E1 — bare where-constrained names as HOF arguments (was silent garbage)
;; ========================================

(define results-e1
  (ws-all
   ;; derived trait methods (N6d-i) bare under map
   "eval [map abs '[1 -2 3]]"
   "eval [map neg '[1 2 3]]"
   ;; to-X (N6d-ii) bare under map
   "eval [map to-float64 '[1 2 3]]"
   "eval [map to-rat '[1 2]]"
   ;; a where-constrained delegating DEFN (not a derived method) bare under map
   ;; (to-float: spec {A} A -> Float64 where (ToFloat64 A) — the user-fn shape;
   ;; an in-string spec+where doesn't parse at L2, so we use the stdlib's own.
   ;; The user-defined case is L3-verified in the e1 probe.)
   "eval [to-float 21]"
   "eval [map to-float '[1 2 3]]"
   ;; non-regression: application syntax + eta prims + all-m0 auto-apply
   "eval [abs -5]"
   "eval [to-float64 7]"
   "eval [reduce int+ 0 '[1 2 3]]"))

(define (r i) (format "~a" (list-ref results-e1 i)))

(test-case "e1/derived-methods-bare-under-map"
  (check-equal? (r 0) "'[1 2 3] : [prologos::data::list::List Int]")
  (check-equal? (r 1) "'[-1 -2 -3] : [prologos::data::list::List Int]"))

(test-case "e1/to-X-bare-under-map"
  (check-equal? (r 2) "'[1.0f 2.0f 3.0f] : [prologos::data::list::List Float64]")
  (check-equal? (r 3) "'[1 2] : [prologos::data::list::List Rat]"))

(test-case "e1/where-constrained-defn-bare-under-map"
  (check-equal? (r 4) "21.0f : Float64")
  (check-equal? (r 5) "'[1.0f 2.0f 3.0f] : [prologos::data::list::List Float64]"))

(test-case "e1/non-regressions"
  (check-equal? (r 6) "5 : Int")
  (check-equal? (r 7) "7.0f : Float64")
  (check-equal? (r 8) "6 : Int"))

;; ========================================
;; E2 — operator values (+ - * / negate as where-constrained trait fns)
;; ========================================
;; Q1 pin: head-position [+ a b] stays the auto-widening keyword;
;; value-position + is the same-type Add function (algebra.prologos).

(define results-e2
  (ws-all
   ;; value position: the headline requirement
   "eval [reduce + 0 '[1 2 3]]"
   "eval [reduce * 1 '[1 2 3 4]]"
   "eval [map negate '[1 2]]"
   ;; homogeneous posit list through the value (dict = Add Posit32)
   "eval [reduce + 0.0 '[1.5 2.5]]"
   ;; head position: keyword still wins at arity 2 (auto-widening join)
   "eval [+ 1 2]"
   "eval [+ 1 1.5]"
   "eval [- 10 4]"
   ;; D-N6E.1: under-application is an ERROR, never an implicit partial
   "eval [+ 7]"))

(define (r2 i) (format "~a" (list-ref results-e2 i)))

(test-case "e2/op-values-under-hofs"
  (check-equal? (r2 0) "6 : Int")
  (check-equal? (r2 1) "24 : Int")
  (check-equal? (r2 2) "'[-1 -2] : [prologos::data::list::List Int]")
  (check-equal? (r2 3) "4.0 : Posit32"))

(test-case "e2/head-position-keyword-preserved"
  (check-equal? (r2 4) "3 : Int")
  (check-equal? (r2 5) "2.5 : Posit32")
  (check-equal? (r2 6) "6 : Int"))

(test-case "e2/under-application-is-error-not-partial"
  ;; uncurried defn applied to 1 arg — must not yield a silent partial
  (check-false (string-contains? (r2 7) "fn ["))
  (check-true (or (string-contains? (r2 7) "rror")
                  (string-contains? (r2 7) "mismatch")
                  (string-contains? (r2 7) "Pi"))))
