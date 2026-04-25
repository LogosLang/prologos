#lang racket/base

;;;
;;; Tests for eigentrust pitfalls doc #1:
;;;   Primitive operators (int+, rat+, int-abs, rat-abs, ...) used as
;;;   first-class values — passed to higher-order combinators (map,
;;;   zip-with, foldr), bound to a variable, stored in a list.
;;;
;;; `elaborate-var` eta-expands bare primitive-op identifiers into concrete
;;; lambdas (mirrors the pre-existing `suc` eta-expansion). The parser
;;; keyword fast-path for direct application is preserved.
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble
  "(ns test)
(imports (prologos::data::list :refer (List nil cons map foldr head)))
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? (format "~a" actual) substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Regression: direct application unchanged
;; ========================================
;; The parser keyword fast-path must still consume primitive operators in
;; head position. The eta-expansion fallback only fires when the operator
;; appears as a bare surf-var, never as the head of a surf-app whose parser
;; rule has already produced a surf-int-add / surf-rat-add / etc.

(test-case "prim-op-firstclass/regression: [int+ 3 4] = 7"
  (check-contains (run-last "(eval [int+ 3 4])") "7 : Int"))

(test-case "prim-op-firstclass/regression: [rat+ 1/2 1/3] = 5/6"
  (check-contains (run-last "(eval [rat+ (rat 1/2) (rat 1/3)])") "5/6 : Rat"))

(test-case "prim-op-firstclass/regression: [int* 6 7] = 42"
  (check-contains (run-last "(eval [int* 6 7])") "42 : Int"))

(test-case "prim-op-firstclass/regression: [int-abs -5] = 5"
  (check-contains (run-last "(eval [int-abs -5])") "5 : Int"))

(test-case "prim-op-firstclass/regression: [rat-abs (rat -1/3)] = 1/3"
  (check-contains (run-last "(eval [rat-abs (rat -1/3)])") "1/3 : Rat"))

;; ========================================
;; The eigentrust pitfalls doc reproducers (the reason this fix exists)
;; ========================================

(test-case "prim-op-firstclass/pitfall: [map rat-abs ...]"
  ;; The eigentrust pitfalls doc example: rat-abs passed to map.
  ;; Pre-fix: "Unbound variable rat-abs" (or "Multiplicity violation").
  (check-contains
   (run-last "(eval [map rat-abs '[(rat 1/2) (rat -1/3) (rat -1/6)]])")
   "1/2"))

(test-case "prim-op-firstclass/pitfall: foldr int+ over an Int list"
  ;; The eigentrust pitfalls doc example: int+ passed to foldr.
  ;; Pre-fix: this also failed (despite the eigentrust pitfalls doc's
  ;; earlier note that it worked — confirmed broken on main as of
  ;; 2026-04-25).
  (check-contains
   (run-last "(eval [foldr int+ 0 '[1 2 3 4 5]])")
   "15 : Int"))

;; ========================================
;; Coverage across primitive families
;; ========================================
;; Exercise multiple primitive families to confirm the eta-expansion table
;; is complete for the operators users actually reach for.

(test-case "prim-op-firstclass/family: foldr int* 1 = product"
  (check-contains (run-last "(eval [foldr int* 1 '[1 2 3 4]])") "24 : Int"))

(test-case "prim-op-firstclass/family: foldr rat+ over Rat list"
  (check-contains
   (run-last "(eval [foldr rat+ (rat 0/1) '[(rat 1/2) (rat 1/3) (rat 1/6)]])")
   "1 : Rat"))

(test-case "prim-op-firstclass/family: foldr rat* over Rat list"
  ;; 1/2 * 1/3 * 1 = 1/6.  Final accumulator is (rat 1).
  (check-contains
   (run-last "(eval [foldr rat* (rat 1/1) '[(rat 1/2) (rat 1/3)]])")
   "1/6 : Rat"))

(test-case "prim-op-firstclass/family: map int-neg negates"
  (check-contains (run-last "(eval [map int-neg '[1 2 3]])")
                  "-1"))

(test-case "prim-op-firstclass/family: map rat-neg negates rats"
  (check-contains
   (run-last "(eval [map rat-neg '[(rat 1/2) (rat 1/3)]])")
   "-1/2"))

;; ========================================
;; Variable binding: def f := int+ — DOCUMENTED BEHAVIOR
;; ========================================
;; Open question from the eigentrust pitfalls doc: should `def f := int+` work?
;; Answer: YES. The eta-expansion produces a bona-fide lambda which is
;; an ordinary first-class value; binding it to a name is just a regular
;; def. `f` then has type `Int -> Int -> Int` (curried lambda). The
;; binding's spec must use the curried form (Int -> Int -> Int), not
;; the uncurried tuple form, because eta-expansion produces nested lambdas.

(test-case "prim-op-firstclass/edge: def + use as binary fn (int+)"
  ;; Bind, then apply. Exercises both `def x := <prim-op>` and
  ;; subsequent application of the bound name.
  (check-contains
   (run-last "(def my-add := int+) (eval [my-add 10 20])")
   "30 : Int"))

(test-case "prim-op-firstclass/edge: def + use as unary fn (int-abs)"
  (check-contains
   (run-last "(def my-abs := int-abs) (eval [my-abs -42])")
   "42 : Int"))

(test-case "prim-op-firstclass/edge: def + use as Rat binary fn"
  (check-contains
   (run-last "(def my-radd := rat+) (eval [my-radd (rat 1/4) (rat 3/4)])")
   "1 : Rat"))

;; ========================================
;; Storing in a list: '[int+ int*] — DOCUMENTED BEHAVIOR
;; ========================================
;; Open question from the eigentrust pitfalls doc: should `'[int+ int*]` work?
;; Answer: PARTIAL. The eta-expansion makes each operator a first-class
;; lambda, so a list literal '[int+ int*] is well-formed in principle.
;; In practice, list-element-type inference for a list of function values
;; is an *orthogonal* limitation: the elaborator currently cannot infer
;; the element type of a list whose entries are bare function values
;; without an explicit annotation. With an annotation the list works:

(test-case "prim-op-firstclass/edge: typed list of ops"
  ;; With the explicit type annotation `[List [Int -> Int -> Int]]`
  ;; the list literal elaborates and each entry retains its lambda
  ;; identity. (Without the annotation the elaborator currently
  ;; reports an inference-failed-error — orthogonal limitation tracked
  ;; separately.)
  (check-contains
   (run-last
    "(def ops : [prologos::data::list::List <Int -> Int -> Int>] := '[int+ int*]) (infer ops)")
   "List"))

;; ========================================
;; Comparisons (Int -> Int -> Bool) — eta-expanded predicates
;; ========================================

(test-case "prim-op-firstclass/edge: bind int-lt as predicate"
  (check-contains
   (run-last "(def lt := int-lt) (eval [lt 2 5])")
   "true : Bool"))

(test-case "prim-op-firstclass/edge: bind rat-eq as predicate"
  (check-contains
   (run-last "(def req := rat-eq) (eval [req (rat 1/2) (rat 1/2)])")
   "true : Bool"))
