#lang racket/base

;;;
;;; Tests for prologos trait and pattern matching features:
;;;   match, Eq trait, Ord trait, elem, recursive-defn,
;;;   native constructors, implicit arguments, structural PM.
;;;
;;; Split from test-stdlib.rkt (part 2 of 3)
;;;

(require rackunit
         racket/path
         racket/string
         racket/list
         "test-support.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt")

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

;; Helper: run two prologos module strings sequentially,
;; sharing the module registry so the second can require the first.
;; Returns the results from the second module.
(define (run-ns-pair s1 s2)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    ;; Process the first module (sets up ns-context, registers module)
    (process-string s1)
    ;; Capture the module info from the first module's namespace
    (let ([ctx (current-ns-context)])
      (when ctx
        (let* ([ns-sym (ns-context-current-ns ctx)]
               [exports (cond
                          [(not (null? (ns-context-exports ctx)))
                           (ns-context-exports ctx)]
                          [(not (null? (ns-context-auto-exports ctx)))
                           (reverse (ns-context-auto-exports ctx))]
                          [else '()])]
               [mi (module-info ns-sym exports (current-global-env) #f (hasheq) (hasheq) (hasheq))])
          (register-module! ns-sym mi))))
    ;; Reset for second module
    (current-global-env (hasheq))
    (current-ns-context #f)
    (process-string s2)))


;; ========================================
;; match keyword — Structural pattern matching on ADTs
;; (using the | ctor args -> body syntax)
;; ========================================

;; --- match on Option ---

(test-case "match/option-some"
  ;; Match on some: extract the value
  (check-equal?
   (run-ns "(ns mo1)\n(imports [prologos::data::option :refer [Option none some]])\n(eval (the Nat (match (some Nat zero) (none -> (suc zero)) (some x -> x))))")
   '("0N : Nat")))


(test-case "match/option-none"
  ;; Match on none: use default
  (check-equal?
   (run-ns "(ns mo2)\n(imports [prologos::data::option :refer [Option none some]])\n(eval (the Nat (match (none Nat) (none -> (suc zero)) (some x -> x))))")
   '("1N : Nat")))


(test-case "match/option-some-transform"
  ;; Match on some: transform the value
  (check-equal?
   (run-ns "(ns mo3)\n(imports [prologos::data::option :refer [Option none some]])\n(eval (the Nat (match (some Nat (suc (suc zero))) (none -> zero) (some x -> (suc x)))))")
   '("3N : Nat")))


;; --- match on Result ---

(test-case "match/result-ok"
  ;; Match on ok: extract value
  (check-equal?
   (run-ns "(ns mr1)\n(imports [prologos::data::result :refer [Result ok err]])\n(eval (the Nat (match (ok Nat Bool zero) (ok x -> x) (err _ -> (suc zero)))))")
   '("0N : Nat")))


(test-case "match/result-err"
  ;; Match on err: use error branch
  (check-equal?
   (run-ns "(ns mr2)\n(imports [prologos::data::result :refer [Result ok err]])\n(eval (the Nat (match (err Nat Bool true) (ok x -> (suc zero)) (err _ -> (suc zero)))))")
   '("1N : Nat")))


(test-case "match/result-err-use-value"
  ;; Match on err: use the error value
  ;; Convert Bool to Nat using boolrec
  (check-equal?
   (run-ns "(ns mr3)\n(imports [prologos::data::result :refer [Result ok err]])\n(eval (the Nat (match (err Nat Bool true) (ok x -> x) (err e -> (boolrec Nat (suc (suc zero)) zero e)))))")
   '("2N : Nat")))


;; --- match on Ordering ---

(test-case "match/ordering-lt"
  (check-equal?
   (run-ns "(ns mord1)\n(imports [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (lt-ord) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))")
   '("0N : Nat")))


(test-case "match/ordering-eq"
  (check-equal?
   (run-ns "(ns mord2)\n(imports [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (eq-ord) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))")
   '("1N : Nat")))


(test-case "match/ordering-gt"
  (check-equal?
   (run-ns "(ns mord3)\n(imports [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (gt-ord) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))")
   '("2N : Nat")))


;; --- match on inline ADTs ---

(test-case "match/inline-enum"
  ;; Define and match on an inline enum
  (check-equal?
   (last (run-ns "(ns mi1)\n(data (Color) (red) (green) (blue))\n(eval (the Nat (match (red) (red -> zero) (green -> (suc zero)) (blue -> (suc (suc zero))))))"))
   "0N : Nat")
  (check-equal?
   (last (run-ns "(ns mi2)\n(data (Color) (red) (green) (blue))\n(eval (the Nat (match (blue) (red -> zero) (green -> (suc zero)) (blue -> (suc (suc zero))))))"))
   "2N : Nat"))


(test-case "match/inline-parameterized"
  ;; Define and match on a parameterized ADT
  (check-equal?
   (last (run-ns "(ns mi3)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(eval (the Nat (match (just Nat (suc (suc zero))) (nothing -> zero) (just x -> x))))"))
   "2N : Nat")
  (check-equal?
   (last (run-ns "(ns mi4)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(eval (the Nat (match (nothing Nat) (nothing -> zero) (just x -> x))))"))
   "0N : Nat"))


;; --- match inside def ---

(test-case "match/inside-def"
  ;; Use match inside a function definition
  (check-equal?
   (last (run-ns "(ns md1)\n(imports [prologos::data::option :refer [Option none some]])\n(def unwrap : (Pi (A :0 (Type 0)) (-> A (-> (Option A) A)))\n  (fn (A :0 (Type 0)) (fn (default : A) (fn (opt : (Option A))\n    (the A (match opt (none -> default) (some x -> x)))))))\n(eval (unwrap Nat (suc (suc zero)) (some Nat zero)))"))
   "0N : Nat")
  (check-equal?
   (last (run-ns "(ns md2)\n(imports [prologos::data::option :refer [Option none some]])\n(def unwrap : (Pi (A :0 (Type 0)) (-> A (-> (Option A) A)))\n  (fn (A :0 (Type 0)) (fn (default : A) (fn (opt : (Option A))\n    (the A (match opt (none -> default) (some x -> x)))))))\n(eval (unwrap Nat (suc (suc zero)) (none Nat)))"))
   "2N : Nat"))


;; --- match with library's match-based functions ---

(test-case "match/library-unwrap-or"
  ;; unwrap-or is now implemented with match
  (check-equal?
   (run-ns "(ns mlu1)\n(imports [prologos::data::option :refer [Option none some unwrap-or]])\n(eval (unwrap-or Nat (suc (suc zero)) (some Nat zero)))")
   '("0N : Nat"))
  (check-equal?
   (run-ns "(ns mlu2)\n(imports [prologos::data::option :refer [Option none some unwrap-or]])\n(eval (unwrap-or Nat (suc (suc zero)) (none Nat)))")
   '("2N : Nat")))


(test-case "match/library-unwrap-or"
  ;; unwrap-or is now implemented with match
  (check-equal?
   (run-ns "(ns mlu3)\n(imports [prologos::data::result :refer [Result ok err unwrap-or]])\n(eval (unwrap-or Nat Bool (suc (suc zero)) (ok Nat Bool zero)))")
   '("0N : Nat"))
  (check-equal?
   (run-ns "(ns mlu4)\n(imports [prologos::data::result :refer [Result ok err unwrap-or]])\n(eval (unwrap-or Nat Bool (suc (suc zero)) (err Nat Bool true)))")
   '("2N : Nat")))


;; --- match on Bool (boolrec replacement) ---

(test-case "match/bool-as-adt"
  ;; Define Bool-like ADT and match on it
  (check-equal?
   (last (run-ns "(ns mb1)\n(data (MyBool) (my-true) (my-false))\n(eval (the Nat (match (my-true) (my-true -> (suc zero)) (my-false -> zero))))"))
   "1N : Nat")
  (check-equal?
   (last (run-ns "(ns mb2)\n(data (MyBool) (my-true) (my-false))\n(eval (the Nat (match (my-false) (my-true -> (suc zero)) (my-false -> zero))))"))
   "0N : Nat"))


;; ========================================
;; Sprint 0.3 Combinators — Option
;; ========================================

;; --- or-else ---

(test-case "or-else/some-some"
  ;; some takes priority over alt — use unwrap-or to extract value
  (check-equal?
   (last (run-ns "(ns ooe1)\n(imports [prologos::data::option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat (suc (suc zero)) (or-else Nat (some Nat zero) (some Nat (suc zero)))))"))
   "0N : Nat"))


(test-case "or-else/some-none"
  ;; some takes priority, alt is none
  (check-equal?
   (last (run-ns "(ns ooe2)\n(imports [prologos::data::option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat (suc (suc zero)) (or-else Nat (some Nat (suc zero)) (none Nat))))"))
   "1N : Nat"))


(test-case "or-else/none-some"
  ;; opt is none, falls back to alt
  (check-equal?
   (last (run-ns "(ns ooe3)\n(imports [prologos::data::option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat zero (or-else Nat (none Nat) (some Nat (suc (suc zero))))))"))
   "2N : Nat"))


(test-case "or-else/none-none"
  ;; both none — returns default from unwrap-or
  (check-equal?
   (last (run-ns "(ns ooe4)\n(imports [prologos::data::option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat (suc (suc (suc zero))) (or-else Nat (none Nat) (none Nat))))"))
   "3N : Nat"))
