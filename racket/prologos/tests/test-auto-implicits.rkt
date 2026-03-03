#lang racket/base

;;;
;;; Tests for Auto-Implicit Type Parameters
;;;
;;; Tests that free type variables in defn signatures are automatically
;;; inferred as implicit m0 parameters of type Type when {A B} is omitted.
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
  (parameterize ([current-global-env (hasheq)]
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
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(define (run-first s)
  (car (run s)))


;; ========================================
;; Basic auto-implicit: single type variable
;; ========================================

(test-case "auto-implicit/identity"
  ;; defn id [x <A>] <A> x  — A should be inferred as implicit
  (check-equal?
   (run-last "(ns ai1)\n(defn id [x <A>] <A> x)\n(eval (id zero))")
   "0N : Nat"))

(test-case "auto-implicit/identity-bool"
  ;; Same identity, applied to Bool
  (check-equal?
   (run-last "(ns ai2)\n(defn id [x <A>] <A> x)\n(eval (id true))")
   "true : Bool"))

;; ========================================
;; Two type variables
;; ========================================

(test-case "auto-implicit/const-two-vars"
  ;; defn const [x <A> _ <B>] <A> x  — A and B auto-implicit
  (check-equal?
   (run-last "(ns ai3)\n(defn const [x <A> _ <B>] <A> x)\n(eval (const zero true))")
   "0N : Nat"))

;; ========================================
;; Three type variables with order preservation
;; ========================================

(test-case "auto-implicit/compose-three-vars"
  ;; defn compose [g <(-> B C)> f <(-> A B)> x <A>] <C> (g (f x))
  ;; Free vars in order of first appearance: B, C, A
  (check-equal?
   (run-last (string-append
     "(ns ai4)\n"
     "(defn my-suc [n <Nat>] <Nat> (suc n))\n"
     "(defn compose [g <(-> B C)> f <(-> A B)> x <A>] <C> (g (f x)))\n"
     "(eval (compose my-suc my-suc zero))"))
   "2N : Nat"))

;; ========================================
;; Backwards compatibility: explicit {A B} still works
;; ========================================

(test-case "auto-implicit/explicit-braces-still-work"
  ;; defn id {A} [x <A>] <A> x  — explicit {A} syntax unchanged
  (check-equal?
   (run-last "(ns ai5)\n(defn id {A} [x <A>] <A> x)\n(eval (id true))")
   "true : Bool"))

(test-case "auto-implicit/explicit-braces-two-vars"
  ;; defn const {A B} [x <A> _ <B>] <A> x
  (check-equal?
   (run-last "(ns ai6)\n(defn const {A B} [x <A> _ <B>] <A> x)\n(eval (const (suc zero) true))")
   "1N : Nat"))

;; ========================================
;; Known names should NOT become auto-implicits
;; ========================================

(test-case "auto-implicit/no-implicit-for-nat"
  ;; defn to-nat [x <Nat>] <Nat> x  — Nat is built-in, not an implicit
  (check-equal?
   (run-last "(ns ai7)\n(defn to-nat [x <Nat>] <Nat> x)\n(eval (to-nat (suc zero)))")
   "1N : Nat"))

(test-case "auto-implicit/no-implicit-for-bool"
  ;; defn not [x <Bool>] <Bool> (match x (true -> false) (false -> true))
  (check-equal?
   (run-last "(ns ai8)\n(defn my-not [x <Bool>] <Bool> (match x (true -> false) (false -> true)))\n(eval (my-not true))")
   "false : Bool"))

(test-case "auto-implicit/no-free-vars"
  ;; defn add [x <Nat> y <Nat>] <Nat> ...  — no free vars, no implicits
  (check-equal?
   (run-last "(ns ai9)\n(defn add [x <Nat> y <Nat>] <Nat> (match y (zero -> x) (suc k -> (suc (add x k)))))\n(eval (add (suc zero) (suc (suc zero))))")
   "3N : Nat"))

;; ========================================
;; Previously defined name excluded
;; ========================================

(test-case "auto-implicit/prev-def-excluded"
  ;; def MyType, then defn use [x <MyType>] <MyType> x — MyType is known
  (check-equal?
   (run-last "(ns ai10)\n(def MyType : (Type 0) Nat)\n(defn use-my-type [x <MyType>] <MyType> x)\n(eval (use-my-type (suc zero)))")
   "1N : Nat"))

;; ========================================
;; With data type: constructor names excluded
;; ========================================

(test-case "auto-implicit/data-type-name-excluded"
  ;; Import List from stdlib — then defn using List A with auto-implicit A
  ;; List should NOT become an auto-implicit (it's a known data type)
  ;; Only A should become auto-implicit
  (check-equal?
   (run-last (string-append
     "(ns ai11)\n"
     "(imports [prologos::data::list :refer [List nil cons head]])\n"
     "(defn my-head [default <A> xs <(List A)>] <A>\n"
     "  (head default xs))\n"
     "(eval (my-head zero (cons (suc zero) nil)))"))
   "1N : Nat"))

;; ========================================
;; Explicit param named like type var
;; ========================================

(test-case "auto-implicit/param-name-not-implicit"
  ;; defn foo [A <(Type 0)> x <A>] <A> x  — A is a param name, not auto-implicit
  (check-equal?
   (run-last "(ns ai12)\n(defn foo [A <(Type 0)> x <A>] <A> x)\n(eval (foo Nat (suc zero)))")
   "1N : Nat"))

;; ========================================
;; Colon-style syntax
;; ========================================

(test-case "auto-implicit/colon-style-identity"
  ;; defn id [x : A] : A x  — colon-style with auto-implicit
  (check-equal?
   (run-last "(ns ai13)\n(defn id [x : A] : A x)\n(eval (id zero))")
   "0N : Nat"))

(test-case "auto-implicit/colon-style-const"
  ;; defn const [x : A, _ : B] : A x  — colon-style with two auto-implicits
  (check-equal?
   (run-last "(ns ai14)\n(defn const [x : A, _ : B] : A x)\n(eval (const (suc zero) true))")
   "1N : Nat"))

;; ========================================
;; Multiple defns in sequence (tests global env updates)
;; ========================================

(test-case "auto-implicit/sequential-defns"
  ;; Define id first, then use it — both with auto-implicits
  (check-equal?
   (run-last (string-append
     "(ns ai15)\n"
     "(defn id [x <A>] <A> x)\n"
     "(defn apply-id [x <A>] <A> (id x))\n"
     "(eval (apply-id (suc (suc zero))))"))
   "2N : Nat"))
