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
