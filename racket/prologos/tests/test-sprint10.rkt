#lang racket/base

;;;
;;; Tests for Sprint 10: Ergonomic Surface Syntax Polish
;;;
;;; Tests wildcard `_` in match patterns, 3-arg `if`, type-inferred `def`,
;;; and `defn` with untyped (bare) parameters.
;;;

(require rackunit
         racket/string
         racket/list
         racket/path
         "test-support.rkt"
         "../errors.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../metavar-store.rkt")

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry])
    (install-module-loader!)
    (process-string s)))

;; Helper: run code and return the last result line
(define (run-last s)
  (last (run-ns s)))

;; Helper: simple run without namespace
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string s)))

(define (run-first s)
  (car (run s)))

;; ========================================
;; Phase 1: Wildcard `_` in match patterns
;; ========================================

(test-case "wildcard/single-in-nat-match"
  ;; match (suc zero) | zero -> false | suc _ -> true  →  true : Bool
  (check-equal?
   (run-last "(ns w1)\n(eval (the Bool (match (suc zero) (zero -> false) (suc _ -> true))))")
   "true : Bool"))

(test-case "wildcard/named-binding-still-works"
  ;; match (suc zero) | zero -> zero | suc k -> k  →  zero : Nat
  ;; Regression: named bindings still work after wildcard change
  (check-equal?
   (run-last "(ns w2)\n(eval (the Nat (match (suc zero) (zero -> zero) (suc k -> k))))")
   "0N : Nat"))

(test-case "wildcard/in-zero-arm"
  ;; match zero | zero -> true | suc _ -> false  →  true : Bool
  (check-equal?
   (run-last "(ns w3)\n(eval (the Bool (match zero (zero -> true) (suc _ -> false))))")
   "true : Bool"))

(test-case "wildcard/in-bool-match"
  ;; match true | true -> zero | false -> (suc zero)  →  zero : Nat
  ;; Using _ in bool match (though bool has no constructor args)
  (check-equal?
   (run-last "(ns w4)\n(eval (the Nat (match true (true -> zero) (false -> (suc zero)))))")
   "0N : Nat"))

(test-case "wildcard/defn-with-wildcard-in-body"
  ;; defn using match with wildcard in the body
  (check-equal?
   (run-last "(ns w5)\n(defn is-zero [n <Nat>] <Bool> (match n (zero -> true) (suc _ -> false)))\n(eval (is-zero (suc (suc zero))))")
   "false : Bool"))

;; ========================================
;; Phase 2: 3-arg `if` (no return type)
;; ========================================

(test-case "if-3arg/in-checking-context-nat"
  ;; (def x <Nat> (if true (suc zero) zero)) — 3-arg if in checking context
  (check-equal?
   (run-first "(def x <Nat> (if true (suc zero) zero))")
   "x : Nat defined."))

(test-case "if-3arg/in-checking-context-bool"
  ;; (def y <Bool> (if true true false)) — 3-arg if with Bool result
  (check-equal?
   (run-first "(def y <Bool> (if true true false))")
   "y : Bool defined."))

(test-case "if-3arg/backward-compat-4arg"
  ;; 4-arg form still works: (eval (if Nat true (suc zero) zero))
  (check-equal?
   (run-first "(eval (if Nat true (suc zero) zero))")
   "1N : Nat"))

(test-case "if-3arg/in-check-command"
  ;; (check (if true (suc zero) zero) <Nat>)
  (check-equal?
   (run-first "(check (if true (suc zero) zero) <Nat>)")
   "OK"))

(test-case "if-3arg/nested"
  ;; Nested 3-arg ifs in checking context
  (check-equal?
   (run-first "(def z <Nat> (if true (if false (suc zero) (suc (suc zero))) zero))")
   "z : Nat defined."))

;; ========================================
;; Phase 3: `def` without type annotation
;; ========================================

(test-case "def-inferred/nat"
  ;; (def one (suc zero)) — type inferred as Nat
  (check-equal?
   (run-first "(def one (suc zero))")
   "one : Nat defined."))

(test-case "def-inferred/bool"
  ;; (def mybool true) — type inferred as Bool
  (check-equal?
   (run-first "(def mybool true)")
   "mybool : Bool defined."))

(test-case "def-inferred/function"
  ;; Bare lambdas can't synthesize types, so use `the` for annotation.
  ;; (def identity (the (-> Nat Nat) (fn [x <Nat>] x)))
  (check-equal?
   (run-first "(def identity (the (-> Nat Nat) (fn [x <Nat>] x)))")
   "identity : Nat -> Nat defined."))

(test-case "def-inferred/using-previous-def"
  ;; Use a previous type-inferred def
  (check-equal?
   (run-last "(def one (suc zero))\n(def two (suc one))")
   "two : Nat defined."))

(test-case "def-inferred/type-annotated-backward-compat"
  ;; (def x <Nat> (suc zero)) — annotated def still works
  (check-equal?
   (run-first "(def x <Nat> (suc zero))")
   "x : Nat defined."))

(test-case "def-inferred/recursive-without-type-errors"
  ;; Recursive def without type annotation should fail (unbound variable).
  ;; Self-reference → "unbound variable" error.
  (check-true
   (prologos-error? (run-first "(def bad (suc bad))"))))

(test-case "def-inferred/type-level"
  ;; Type-level def: (def MyType (Type 0))
  (check-equal?
   (run-first "(def MyType (Type 0))")
   "MyType : [Type 1] defined."))

(test-case "def-inferred/eval-after-inferred-def"
  ;; Eval an expression using a type-inferred def
  (check-equal?
   (run-last "(def one (suc zero))\n(eval (suc one))")
   "2N : Nat"))

;; ========================================
;; Phase 4: `defn` with untyped parameters
;; ========================================

(test-case "defn-bare/single-param"
  ;; (defn succ [n] <Nat> (suc n)) — single bare param
  (check-equal?
   (run-last "(ns bp1)\n(defn succ [n] <Nat> (suc n))\n(eval (succ (suc zero)))")
   "2N : Nat"))

(test-case "defn-bare/two-params"
  ;; (defn const-nat [x y] <Nat> x) — two bare params
  (check-equal?
   (run-last "(ns bp2)\n(defn const-nat [x y] <Nat> x)\n(eval (const-nat (suc zero) zero))")
   "1N : Nat"))

(test-case "defn-bare/with-implicit-type-param-typed"
  ;; Implicit type params + bare params: bare param type can't be inferred
  ;; from context alone (chicken-and-egg with implicit arg).
  ;; Use typed params when combining with implicits.
  (check-equal?
   (run-last "(ns bp3)\n(defn poly-id {A} [x <A>] <A> x)\n(eval (poly-id (suc zero)))")
   "1N : Nat"))

(test-case "defn-bare/typed-params-backward-compat"
  ;; (defn f [x <Nat>] <Nat> (suc x)) — typed params still work
  (check-equal?
   (run-last "(ns bp4)\n(defn f [x <Nat>] <Nat> (suc x))\n(eval (f zero))")
   "1N : Nat"))

(test-case "defn-bare/with-simple-body"
  ;; defn with bare params and simple body (param type constrained by body usage)
  (check-equal?
   (run-last "(ns bp5)\n(defn f [n] <Nat> (suc n))\n(eval (f (suc zero)))")
   "2N : Nat"))

(test-case "defn-bare/colon-return-type"
  ;; (defn succ2 [n] : Nat (suc n)) — bare params with colon return type
  (check-equal?
   (run-last "(ns bp6)\n(defn succ2 [n] : Nat (suc n))\n(eval (succ2 (suc zero)))")
   "2N : Nat"))

;; ========================================
;; Regression: stdlib still works
;; ========================================

(test-case "regression/stdlib-add"
  ;; Existing stdlib definitions should still work
  (check-equal?
   (run-last "(ns reg1)\n(imports [prologos::data::nat :refer [add]])\n(eval (add (suc zero) (suc (suc zero))))")
   "3N : Nat"))

(test-case "regression/stdlib-zero?"
  ;; Existing match-based stdlib functions work
  (check-equal?
   (run-last "(ns reg2)\n(imports [prologos::data::nat :refer [zero?]])\n(eval (zero? zero))")
   "true : Bool"))

;; ========================================
;; Phase 5: fn with return type annotation
;; ========================================

(test-case "fn-rettype/simple-identity"
  ;; (fn (x : Nat) <Nat> x) should type-check as (-> Nat Nat)
  (check-equal?
   (run-last "(ns frt1)\n(eval (the (-> Nat Nat) (fn (x : Nat) <Nat> x)))")
   "[fn [x <Nat>] x] : Nat -> Nat"))

(test-case "fn-rettype/applied"
  ;; fn with return type, applied to argument
  (check-equal?
   (run-last "(ns frt2)\n(eval ((fn (x : Nat) <Nat> (suc x)) (suc zero)))")
   "2N : Nat"))

(test-case "fn-rettype/bracket-binder"
  ;; [x <Nat>] <Nat> syntax
  (check-equal?
   (run-last "(ns frt3)\n(eval ((fn [x <Nat>] <Nat> (suc x)) zero))")
   "1N : Nat"))

(test-case "fn-rettype/multi-param"
  ;; Multi-parameter: fn [x <Nat> y <Nat>] <Nat> body
  (check-equal?
   (run-last "(ns frt4)\n(eval ((fn [x <Nat> y <Nat>] <Nat> x) (suc zero) zero))")
   "1N : Nat"))

(test-case "fn-rettype/as-defn-body"
  ;; fn with return type used as body of a defn
  ;; def add1 : (-> Nat Nat) (fn (x : Nat) <Nat> (suc x))
  (check-equal?
   (run-last "(ns frt5)\n(def add1 : (-> Nat Nat) (fn (x : Nat) <Nat> (suc x)))\n(eval (add1 (suc (suc zero))))")
   "3N : Nat"))

(test-case "fn-rettype/defn-returns-function"
  ;; defn with function-returning return type + inner fn with return type
  ;; This is the clamp pattern: defn f [a, b] <Nat -> Nat> fn [x] <Nat> body
  (check-equal?
   (run-last "(ns frt6)\n(imports [prologos::data::nat :refer [min max]])\n(defn clamp [low <Nat> high <Nat>] <(-> Nat Nat)> (fn [x <Nat>] <Nat> (max low (min x high))))\n(eval (clamp (suc (suc zero)) (suc (suc (suc (suc zero)))) (suc (suc (suc (suc (suc (suc zero))))))))")
   "4N : Nat"))

(test-case "fn-rettype/defn-returns-function-simple"
  ;; Simpler: defn that returns a function
  (check-equal?
   (run-last "(ns frt7)\n(defn add-n [n <Nat>] <(-> Nat Nat)> (fn [x <Nat>] <Nat> (the Nat n)))\n(eval (add-n (suc (suc zero)) zero))")
   "2N : Nat"))

(test-case "fn-rettype/colon-style"
  ;; fn (x : Nat) : Nat body — colon-style return type
  (check-equal?
   (run-last "(ns frt8)\n(eval ((fn (x : Nat) : Nat (suc x)) zero))")
   "1N : Nat"))

(test-case "fn-rettype/colon-style-arrow"
  ;; fn (x : Nat) : Nat -> Nat body — colon-style with arrow return type
  (check-equal?
   (run-last "(ns frt9)\n(def f : (-> Nat (-> Nat Nat)) (fn (x : Nat) : Nat -> Nat (fn (y : Nat) : Nat x)))\n(eval (f (suc (suc zero)) zero))")
   "2N : Nat"))

;; Note: bare params (fn x <Nat> body) with return type annotation
;; create holes in both Pi and lam that can't be resolved through
;; the double-annotation pattern. Use typed params instead:
;; fn [x <Nat>] <Nat> body
