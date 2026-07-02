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

;; ========================================
;; E3 — explicit-hole sections over keyword heads (D-N6E.1)
;; ========================================
;; [int* _ 2] / [+ 1.5 _] desugar AT PARSE to hole-domain lambdas WRAPPING
;; the keyword, so sections inherit head-position semantics (auto-widening
;; numeric-join for generics). Pins: hole count = arity, left-to-right,
;; immediately-enclosing bracket group only. Faithful mirror of surf-app
;; _-sections (parity-probed at E3 close): generic ops under unsolved metas
;; ([map [+ _ 1] xs]) fail inference IDENTICALLY to the explicit lambda
;; [map [fn [x] [+ x 1]] xs] — a pre-existing limitation, not E3's.

(define results-e3
  (ws-all
   ;; THE documented idiom (prologos-syntax.md § Application style)
   "eval [map [int* _ 2] '[1 2 3]]"
   ;; auto-widening join through a generic-keyword section (Q1 pin)
   "eval [[+ 1.5 _] 1]"
   ;; prim-family sections: float, posit
   "eval [map [f64* _ 2.0f64] '[1.0f64 2.0f64]]"
   "eval [map [p32* _ 2.0] '[1.0 3.0]]"
   ;; unary prim section
   "eval [map [int-neg _] '[1 2]]"
   ;; concrete comparison section under filter
   "eval [filter [int-lt _ 3] '[1 2 3 4]]"
   ;; surf-app single-hole section (pre-existing route — parity control)
   "defn sub2i [x y] [int- x y]"
   "eval [[sub2i _ 3] 10]"
   ;; nested group: the hole belongs to the INNER group only → + gets a
   ;; lambda operand → LOUD error (the immediately-enclosing pin)
   "eval [+ 7 [int* _ 2]]"
   ;; def-RHS (infer position): LOUD error, not the pre-E3 silent `: Int`
   "def bad-section := [int* _ 2]"))

(define (r3 i) (format "~a" (list-ref results-e3 i)))

(test-case "e3/documented-idiom-int*-section"
  (check-equal? (r3 0) "'[2 4 6] : [prologos::data::list::List Int]"))

(test-case "e3/section-inherits-auto-widening-join"
  ;; 1.5 is Posit32; the Int arg widens via the keyword's numeric-join
  ;; (value coercion may append a warning line — assert the prefix)
  (check-true (string-prefix? (r3 1) "2.5 : Posit32")))

(test-case "e3/prim-family-and-unary-sections"
  (check-equal? (r3 2) "'[2.0f 4.0f] : [prologos::data::list::List Float64]")
  (check-equal? (r3 3) "'[2.0 6.0] : [prologos::data::list::List Posit32]")
  (check-equal? (r3 4) "'[-1 -2] : [prologos::data::list::List Int]")
  (check-equal? (r3 5) "'[1 2] : [prologos::data::list::List Int]"))

(test-case "e3/surf-app-section-parity-control"
  (check-equal? (r3 7) "7 : Int"))

(test-case "e3/nested-group-hole-is-inner-only"
  (check-true (string-contains? (r3 8) "Could not infer")))

(test-case "e3/def-rhs-section-fails-loudly"
  ;; pre-E3 this silently defined bad-section : Int
  (check-false (string-contains? (r3 9) "defined"))
  (check-true (string-contains? (r3 9) "Could not infer")))

;; ========================================
;; Issue #71 — saturated multi-hole sections applied in infer position
;; ========================================
;; [[- _ _] 10 3] desugars to a CURRIED 2-hole lambda applied to 2 args; the
;; app rule can't unwrap it (the inner λ lands in bare infer position → error).
;; Fix (reduction.rkt saturated-hole-section-app? + whnf-then-infer pre-case in
;; typing-core infer + qtt inferQ): a saturated >=2-hole section whnf-reduces to
;; a lambda-free concrete form, which the ordinary rules type. On-network install
;; has no twin — a saturated section leaves ⊥ there and driver.rkt:585 falls back
;; to the fixed imperative infer (sound: ⊥ = "don't know", not a wrong type).

(define results-i71
  (ws-all
   ;; keyword route, 2-hole, saturated → the reported failure, now types
   "eval [[- _ _] 10 3]"
   "eval [[+ _ _] 1 2]"
   ;; the reduced concrete keyword app re-enters the auto-widening head rule
   "eval [[+ _ _] 1 1.5]"
   ;; surf-app route (macros.rkt placeholder desugar) — parity with keyword route
   "defn sub2j [x y] [int- x y]"
   "eval [[sub2j _ _] 10 3]"
   ;; --- E3 contract non-regressions (must all still hold) ---
   "eval [[+ 1.5 _] 1]"          ;; single-hole saturated section (auto-widen)
   "eval [+ 7 [int* _ 2]]"       ;; nested-group → inner section is a λ operand → LOUD
   "def bad71 := [int* _ 2]"     ;; def-RHS unsaturated section → LOUD (not silent : Int)
   "eval [map [int* _ 2] '[1 2 3]]"))  ;; the documented idiom (E3)

(define (ri i) (format "~a" (list-ref results-i71 i)))

(test-case "i71/saturated-multihole-keyword-section-types"
  (check-equal? (ri 0) "7 : Int")
  (check-equal? (ri 1) "3 : Int"))

(test-case "i71/multihole-section-inherits-auto-widening"
  (check-true (string-prefix? (ri 2) "2.5 : Posit32")))

(test-case "i71/surf-app-multihole-parity"
  (check-equal? (ri 4) "7 : Int")
  (check-equal? (ri 4) (ri 0)))   ;; keyword + surf-app routes agree

(test-case "i71/e3-contract-preserved"
  (check-true (string-prefix? (ri 5) "2.5 : Posit32"))   ;; single-hole still works
  (check-true (string-contains? (ri 6) "Could not infer")) ;; nested-group loud
  (check-false (string-contains? (ri 7) "defined"))        ;; def-RHS loud
  (check-true (string-contains? (ri 7) "Could not infer"))
  (check-equal? (ri 8) "'[2 4 6] : [prologos::data::list::List Int]"))
