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
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt")

;; Compute the lib directory path
(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
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
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
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
               [mi (module-info ns-sym exports (current-global-env) #f (hasheq) (hasheq))])
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
   (run-ns "(ns mo1)\n(require [prologos.data.option :refer [Option none some]])\n(eval (the Nat (match (some Nat zero) (none -> (suc zero)) (some x -> x))))")
   '("0N : Nat")))

(test-case "match/option-none"
  ;; Match on none: use default
  (check-equal?
   (run-ns "(ns mo2)\n(require [prologos.data.option :refer [Option none some]])\n(eval (the Nat (match (none Nat) (none -> (suc zero)) (some x -> x))))")
   '("1N : Nat")))

(test-case "match/option-some-transform"
  ;; Match on some: transform the value
  (check-equal?
   (run-ns "(ns mo3)\n(require [prologos.data.option :refer [Option none some]])\n(eval (the Nat (match (some Nat (suc (suc zero))) (none -> zero) (some x -> (suc x)))))")
   '("3N : Nat")))

;; --- match on Result ---

(test-case "match/result-ok"
  ;; Match on ok: extract value
  (check-equal?
   (run-ns "(ns mr1)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (the Nat (match (ok Nat Bool zero) (ok x -> x) (err _ -> (suc zero)))))")
   '("0N : Nat")))

(test-case "match/result-err"
  ;; Match on err: use error branch
  (check-equal?
   (run-ns "(ns mr2)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (the Nat (match (err Nat Bool true) (ok x -> (suc zero)) (err _ -> (suc zero)))))")
   '("1N : Nat")))

(test-case "match/result-err-use-value"
  ;; Match on err: use the error value
  ;; Convert Bool to Nat using boolrec
  (check-equal?
   (run-ns "(ns mr3)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (the Nat (match (err Nat Bool true) (ok x -> x) (err e -> (boolrec Nat (suc (suc zero)) zero e)))))")
   '("2N : Nat")))

;; --- match on Ordering ---

(test-case "match/ordering-lt"
  (check-equal?
   (run-ns "(ns mord1)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (lt-ord) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))")
   '("0N : Nat")))

(test-case "match/ordering-eq"
  (check-equal?
   (run-ns "(ns mord2)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (eq-ord) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))")
   '("1N : Nat")))

(test-case "match/ordering-gt"
  (check-equal?
   (run-ns "(ns mord3)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (gt-ord) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))")
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
   (last (run-ns "(ns md1)\n(require [prologos.data.option :refer [Option none some]])\n(def unwrap : (Pi (A :0 (Type 0)) (-> A (-> (Option A) A)))\n  (fn (A :0 (Type 0)) (fn (default : A) (fn (opt : (Option A))\n    (the A (match opt (none -> default) (some x -> x)))))))\n(eval (unwrap Nat (suc (suc zero)) (some Nat zero)))"))
   "0N : Nat")
  (check-equal?
   (last (run-ns "(ns md2)\n(require [prologos.data.option :refer [Option none some]])\n(def unwrap : (Pi (A :0 (Type 0)) (-> A (-> (Option A) A)))\n  (fn (A :0 (Type 0)) (fn (default : A) (fn (opt : (Option A))\n    (the A (match opt (none -> default) (some x -> x)))))))\n(eval (unwrap Nat (suc (suc zero)) (none Nat)))"))
   "2N : Nat"))

;; --- match with library's match-based functions ---

(test-case "match/library-unwrap-or"
  ;; unwrap-or is now implemented with match
  (check-equal?
   (run-ns "(ns mlu1)\n(require [prologos.data.option :refer [Option none some unwrap-or]])\n(eval (unwrap-or Nat (suc (suc zero)) (some Nat zero)))")
   '("0N : Nat"))
  (check-equal?
   (run-ns "(ns mlu2)\n(require [prologos.data.option :refer [Option none some unwrap-or]])\n(eval (unwrap-or Nat (suc (suc zero)) (none Nat)))")
   '("2N : Nat")))

(test-case "match/library-unwrap-or"
  ;; unwrap-or is now implemented with match
  (check-equal?
   (run-ns "(ns mlu3)\n(require [prologos.data.result :refer [Result ok err unwrap-or]])\n(eval (unwrap-or Nat Bool (suc (suc zero)) (ok Nat Bool zero)))")
   '("0N : Nat"))
  (check-equal?
   (run-ns "(ns mlu4)\n(require [prologos.data.result :refer [Result ok err unwrap-or]])\n(eval (unwrap-or Nat Bool (suc (suc zero)) (err Nat Bool true)))")
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
   (last (run-ns "(ns ooe1)\n(require [prologos.data.option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat (suc (suc zero)) (or-else Nat (some Nat zero) (some Nat (suc zero)))))"))
   "0N : Nat"))

(test-case "or-else/some-none"
  ;; some takes priority, alt is none
  (check-equal?
   (last (run-ns "(ns ooe2)\n(require [prologos.data.option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat (suc (suc zero)) (or-else Nat (some Nat (suc zero)) (none Nat))))"))
   "1N : Nat"))

(test-case "or-else/none-some"
  ;; opt is none, falls back to alt
  (check-equal?
   (last (run-ns "(ns ooe3)\n(require [prologos.data.option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat zero (or-else Nat (none Nat) (some Nat (suc (suc zero))))))"))
   "2N : Nat"))

(test-case "or-else/none-none"
  ;; both none — returns default from unwrap-or
  (check-equal?
   (last (run-ns "(ns ooe4)\n(require [prologos.data.option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat (suc (suc (suc zero))) (or-else Nat (none Nat) (none Nat))))"))
   "3N : Nat"))

;; --- filter ---

(test-case "filter/pred-true"
  ;; some with pred returning true → keeps value — use unwrap-or
  (check-equal?
   (last (run-ns "(ns of1)\n(require [prologos.data.option :refer [Option none some filter unwrap-or]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (unwrap-or Nat (suc zero) (filter Nat zero? (some Nat zero))))"))
   "0N : Nat"))

(test-case "filter/pred-false"
  ;; some with pred returning false → none → gets default
  (check-equal?
   (last (run-ns "(ns of2)\n(require [prologos.data.option :refer [Option none some filter unwrap-or]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (unwrap-or Nat (suc (suc zero)) (filter Nat zero? (some Nat (suc zero)))))"))
   "2N : Nat"))

(test-case "filter/none"
  ;; none stays none → gets default
  (check-equal?
   (last (run-ns "(ns of3)\n(require [prologos.data.option :refer [Option none some filter unwrap-or]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (unwrap-or Nat (suc (suc (suc zero))) (filter Nat zero? (none Nat))))"))
   "3N : Nat"))

;; --- zip-with ---

(test-case "zip-with/both-some"
  ;; zip two somes with add — use unwrap-or to extract result
  (check-equal?
   (last (run-ns "(ns ozw1)\n(require [prologos.data.option :refer [Option none some zip-with unwrap-or]])\n(require [prologos.data.nat :refer [add]])\n(eval (unwrap-or Nat zero (zip-with Nat Nat Nat add (some Nat (suc (suc zero))) (some Nat (suc (suc (suc zero)))))))"))
   "5N : Nat"))

(test-case "zip-with/first-none"
  (check-equal?
   (last (run-ns "(ns ozw2)\n(require [prologos.data.option :refer [Option none some zip-with unwrap-or]])\n(require [prologos.data.nat :refer [add]])\n(eval (unwrap-or Nat (suc (suc (suc zero))) (zip-with Nat Nat Nat add (none Nat) (some Nat (suc zero)))))"))
   "3N : Nat"))

(test-case "zip-with/second-none"
  (check-equal?
   (last (run-ns "(ns ozw3)\n(require [prologos.data.option :refer [Option none some zip-with unwrap-or]])\n(require [prologos.data.nat :refer [add]])\n(eval (unwrap-or Nat (suc (suc (suc zero))) (zip-with Nat Nat Nat add (some Nat (suc zero)) (none Nat))))"))
   "3N : Nat"))

(test-case "zip-with/both-none"
  (check-equal?
   (last (run-ns "(ns ozw4)\n(require [prologos.data.option :refer [Option none some zip-with unwrap-or]])\n(require [prologos.data.nat :refer [add]])\n(eval (unwrap-or Nat (suc (suc (suc zero))) (zip-with Nat Nat Nat add (none Nat) (none Nat))))"))
   "3N : Nat"))

;; --- zip ---

(test-case "zip/both-some"
  ;; zip into a pair, then extract via match
  (check-equal?
   (last (run-ns "(ns oz1)\n(require [prologos.data.option :refer [Option none some zip]])\n(eval (the Nat (match (zip Nat Nat (some Nat (suc zero)) (some Nat (suc (suc zero)))) (none -> zero) (some p -> (first p)))))"))
   "1N : Nat"))

(test-case "zip/one-none"
  (check-equal?
   (last (run-ns "(ns oz2)\n(require [prologos.data.option :refer [Option none some zip]])\n(eval (the Nat (match (zip Nat Nat (none Nat) (some Nat (suc (suc zero)))) (none -> (suc (suc (suc zero)))) (some p -> (first p)))))"))
   "3N : Nat"))

;; --- Type checking for Option combinators ---

(test-case "or-else/type-check"
  (check-equal?
   (last (run-ns "(ns ooetc)\n(require [prologos.data.option :refer [Option or-else]])\n(check or-else : (Pi (A :0 (Type 0)) (-> (Option A) (-> (Option A) (Option A)))))"))
   "OK"))

(test-case "filter/type-check"
  (check-equal?
   (last (run-ns "(ns oftc)\n(require [prologos.data.option :refer [Option filter]])\n(check filter : (Pi (A :0 (Type 0)) (-> (-> A Bool) (-> (Option A) (Option A)))))"))
   "OK"))

;; ========================================
;; Sprint 0.3 Combinators — Result
;; ========================================

;; --- and-then ---
;; Auto-implicit order: A B E (first-occurrence in spec [A -> Result B E] [Result A E] -> Result B E)

(test-case "and-then/ok-to-ok"
  ;; ok value → apply f → ok result — use unwrap-or to extract
  (check-equal?
   (last (run-ns "(ns rat1)\n(require [prologos.data.result :refer [Result ok err and-then unwrap-or]])\n(require [prologos.data.nat :refer [add]])\n(eval (unwrap-or Nat Bool zero (and-then Nat Nat Bool (fn (x : Nat) (ok Nat Bool (add x (suc zero)))) (ok Nat Bool (suc (suc zero))))))"))
   "3N : Nat"))

(test-case "and-then/ok-to-err"
  ;; ok value → apply f → err result — match to extract
  (check-equal?
   (last (run-ns "(ns rat2)\n(require [prologos.data.result :refer [Result ok err and-then]])\n(eval (the Nat (match (and-then Nat Nat Bool (fn (x : Nat) (err Nat Bool true)) (ok Nat Bool (suc zero))) (ok x -> x) (err e -> (match e (true -> (suc (suc (suc (suc (suc zero)))))) (false -> zero))))))"))
   "5N : Nat"))

(test-case "and-then/err-passthrough"
  ;; err → f not called, err passes through
  (check-equal?
   (last (run-ns "(ns rat3)\n(require [prologos.data.result :refer [Result ok err and-then]])\n(eval (the Nat (match (and-then Nat Nat Bool (fn (x : Nat) (ok Nat Bool (suc x))) (err Nat Bool true)) (ok x -> x) (err e -> (match e (true -> (suc (suc (suc (suc (suc (suc (suc zero)))))))) (false -> zero))))))"))
   "7N : Nat"))

;; --- or-else ---
;; Auto-implicit order: E A F (first-occurrence in spec [E -> Result A F] [Result A E] -> Result A F)

(test-case "or-else/ok-passthrough"
  ;; ok → f not called, ok passes through — use unwrap-or
  (check-equal?
   (last (run-ns "(ns roe1)\n(require [prologos.data.result :refer [Result ok err or-else unwrap-or]])\n(eval (unwrap-or Nat Nat zero (or-else Bool Nat Nat (fn (e : Bool) (ok Nat Nat zero)) (ok Nat Bool (suc (suc zero))))))"))
   "2N : Nat"))

(test-case "or-else/err-to-ok"
  ;; err → apply f → recovers to ok — use unwrap-or
  (check-equal?
   (last (run-ns "(ns roe2)\n(require [prologos.data.result :refer [Result ok err or-else unwrap-or]])\n(eval (unwrap-or Nat Nat zero (or-else Bool Nat Nat (fn (e : Bool) (ok Nat Nat (match e (true -> (suc zero)) (false -> zero)))) (err Nat Bool true))))"))
   "1N : Nat"))

(test-case "or-else/err-to-err"
  ;; err → apply f → still err (with new error type) — match to extract
  (check-equal?
   (last (run-ns "(ns roe3)\n(require [prologos.data.result :refer [Result ok err or-else]])\n(eval (the Nat (match (or-else Bool Nat Nat (fn (e : Bool) (err Nat Nat (the Nat (match e (true -> (suc (suc (suc zero)))) (false -> zero))))) (err Nat Bool true)) (ok x -> x) (err e -> e))))"))
   "3N : Nat"))

;; --- Type checking for Result combinators ---

(test-case "and-then/type-check"
  ;; Auto-implicit order: A B E (first-occurrence in spec)
  (check-equal?
   (last (run-ns "(ns rattc)\n(require [prologos.data.result :refer [Result and-then]])\n(check and-then : (Pi (A :0 (Type 0)) (Pi (B :0 (Type 0)) (Pi (E :0 (Type 0)) (-> (-> A (Result B E)) (-> (Result A E) (Result B E)))))))"))
   "OK"))

(test-case "or-else/type-check"
  ;; Auto-implicit order: E A F (first-occurrence in spec)
  (check-equal?
   (last (run-ns "(ns roetc)\n(require [prologos.data.result :refer [Result or-else]])\n(check or-else : (Pi (E :0 (Type 0)) (Pi (A :0 (Type 0)) (Pi (F :0 (Type 0)) (-> (-> E (Result A F)) (-> (Result A E) (Result A F)))))))"))
   "OK"))

;; ========================================
;; Recursive Types — Inline data definition
;; ========================================

(test-case "data/recursive-natlist"
  ;; Monomorphic recursive type
  (check-equal?
   (last (run-ns "(ns rd1)\n(data (NatList) (nil) (cons Nat NatList))\n(check nil : NatList)"))
   "OK")
  (check-equal?
   (last (run-ns "(ns rd2)\n(data (NatList) (nil) (cons Nat NatList))\n(check (cons zero nil) : NatList)"))
   "OK"))

(test-case "data/recursive-parameterized"
  ;; Parameterized recursive type
  (check-equal?
   (last (run-ns "(ns rd3)\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(check (nil Nat) : (List Nat))"))
   "OK")
  (check-equal?
   (last (run-ns "(ns rd4)\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(check (cons Nat zero (nil Nat)) : (List Nat))"))
   "OK"))

(test-case "data/recursive-nested-cons"
  ;; Build a 3-element list
  (check-equal?
   (last (run-ns "(ns rd5)\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(check (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))) : (List Nat))"))
   "OK"))

(test-case "data/recursive-fold-sum"
  ;; Sum [1, 2, 3] → 6 via recursive match
  (check-equal?
   (last (run-ns "(ns rd6)\n(require [prologos.data.nat :refer [add]])\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(def my-sum : (-> (List Nat) Nat) (fn (xs : (List Nat)) (match xs (nil -> zero) (cons a rest -> (add a (my-sum rest))))))\n(eval (my-sum (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "6N : Nat"))

(test-case "data/recursive-match-sum"
  ;; Match on recursive type — structural (not fold): need explicit recursion
  (check-equal?
   (last (run-ns "(ns rd7)\n(require [prologos.data.nat :refer [add]])\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(def my-sum : (-> (List Nat) Nat) (fn (xs : (List Nat)) (match xs (nil -> zero) (cons x rest -> (add x (my-sum rest))))))\n(def my-list : (List Nat) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))\n(eval (my-sum my-list))"))
   "6N : Nat"))

(test-case "data/recursive-match-empty"
  ;; Match on empty list — structural match, nil branch returns 3
  (check-equal?
   (last (run-ns "(ns rd8)\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(eval (the Nat (match (nil Nat) (nil -> (suc (suc (suc zero)))) (cons x rest -> zero))))"))
   "3N : Nat"))

;; ========================================
;; List module — prologos.data.list
;; ========================================

(test-case "list/type-check"
  ;; List type and constructor types
  (check-equal?
   (last (run-ns "(ns lst1)\n(require [prologos.data.list :refer [List nil cons]])\n(check (nil Nat) : (List Nat))"))
   "OK")
  (check-equal?
   (last (run-ns "(ns lst2)\n(require [prologos.data.list :refer [List nil cons]])\n(check (cons Nat zero (nil Nat)) : (List Nat))"))
   "OK"))

(test-case "list/foldr-sum"
  ;; foldr add zero [1,2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst3)\n(require [prologos.data.list :refer [List nil cons foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "6N : Nat"))

(test-case "list/foldr-product"
  ;; foldr mult 1 [2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst4)\n(require [prologos.data.list :refer [List nil cons foldr]])\n(require [prologos.data.nat :refer [mult]])\n(eval (foldr Nat Nat mult (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))"))
   "6N : Nat"))

(test-case "list/foldr-empty"
  ;; foldr f z [] = z
  (check-equal?
   (last (run-ns "(ns lst5)\n(require [prologos.data.list :refer [List nil cons foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add (suc (suc (suc (suc (suc zero))))) (nil Nat)))"))
   "5N : Nat"))

(test-case "list/length-empty"
  (check-equal?
   (last (run-ns "(ns lst6)\n(require [prologos.data.list :refer [List nil length]])\n(eval (length Nat (nil Nat)))"))
   "0N : Nat"))

(test-case "list/length-three"
  (check-equal?
   (last (run-ns "(ns lst7)\n(require [prologos.data.list :refer [List nil cons length]])\n(eval (length Nat (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "3N : Nat"))

(test-case "list/map-suc"
  ;; map (fn x . suc x) [0, 1] then sum = 1 + 2 = 3
  (check-equal?
   (last (run-ns "(ns lst8)\n(require [prologos.data.list :refer [List nil cons map foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add zero (map Nat Nat (fn (x : Nat) (suc x)) (cons Nat zero (cons Nat (suc zero) (nil Nat))))))"))
   "3N : Nat"))

(test-case "list/map-empty"
  ;; map f [] = [], length = 0
  (check-equal?
   (last (run-ns "(ns lst9)\n(require [prologos.data.list :refer [List nil map length]])\n(eval (length Nat (map Nat Nat (fn (x : Nat) (suc x)) (nil Nat))))"))
   "0N : Nat"))

(test-case "list/filter-keep-zeros"
  ;; filter zero? [0, 1, 0] → length 2
  (check-equal?
   (last (run-ns "(ns lst10)\n(require [prologos.data.list :refer [List nil cons filter length]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (filter Nat zero? (cons Nat zero (cons Nat (suc zero) (cons Nat zero (nil Nat)))))))"))
   "2N : Nat"))

(test-case "list/filter-drop-all"
  ;; filter zero? [1, 2] → length 0
  (check-equal?
   (last (run-ns "(ns lst11)\n(require [prologos.data.list :refer [List nil cons filter length]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (filter Nat zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "0N : Nat"))

(test-case "list/append"
  ;; [1,2] ++ [3] → sum = 6
  (check-equal?
   (last (run-ns "(ns lst12)\n(require [prologos.data.list :refer [List nil cons append foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add zero (append Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))) (cons Nat (suc (suc (suc zero))) (nil Nat)))))"))
   "6N : Nat"))

(test-case "list/append-empty-left"
  ;; [] ++ [1] → sum = 1
  (check-equal?
   (last (run-ns "(ns lst13)\n(require [prologos.data.list :refer [List nil cons append foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add zero (append Nat (nil Nat) (cons Nat (suc zero) (nil Nat)))))"))
   "1N : Nat"))

(test-case "list/append-empty-right"
  ;; [1] ++ [] → sum = 1
  (check-equal?
   (last (run-ns "(ns lst14)\n(require [prologos.data.list :refer [List nil cons append foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add zero (append Nat (cons Nat (suc zero) (nil Nat)) (nil Nat))))"))
   "1N : Nat"))

(test-case "list/head-nonempty"
  (check-equal?
   (last (run-ns "(ns lst15)\n(require [prologos.data.list :refer [List nil cons head]])\n(eval (head Nat (suc (suc (suc zero))) (cons Nat (suc zero) (nil Nat))))"))
   "1N : Nat"))

(test-case "list/head-empty"
  ;; head returns default for empty list
  (check-equal?
   (last (run-ns "(ns lst16)\n(require [prologos.data.list :refer [List nil head]])\n(eval (head Nat (suc (suc (suc zero))) (nil Nat)))"))
   "3N : Nat"))

(test-case "list/singleton"
  (check-equal?
   (last (run-ns "(ns lst17)\n(require [prologos.data.list :refer [List singleton length]])\n(eval (length Nat (singleton Nat zero)))"))
   "1N : Nat"))

(test-case "list/singleton-head"
  (check-equal?
   (last (run-ns "(ns lst18)\n(require [prologos.data.list :refer [List singleton head]])\n(eval (head Nat (suc (suc (suc zero))) (singleton Nat (suc (suc zero)))))"))
   "2N : Nat"))

;; ========================================
;; prologos.core.eq-trait — Eq dictionary-passing
;; ========================================

(test-case "eq/nat-eq-same"
  ;; nat-eq 0 0 = true
  (check-equal?
   (last (run-ns "(ns eq1)\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (nat-eq zero zero))"))
   "true : Bool"))

(test-case "eq/nat-eq-same-nonzero"
  ;; nat-eq 3 3 = true
  (check-equal?
   (last (run-ns "(ns eq2)\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (nat-eq (suc (suc (suc zero))) (suc (suc (suc zero)))))"))
   "true : Bool"))

(test-case "eq/nat-eq-different"
  ;; nat-eq 2 3 = false
  (check-equal?
   (last (run-ns "(ns eq3)\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (nat-eq (suc (suc zero)) (suc (suc (suc zero)))))"))
   "false : Bool"))

(test-case "eq/nat-eq-zero-nonzero"
  ;; nat-eq 0 1 = false
  (check-equal?
   (last (run-ns "(ns eq4)\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (nat-eq zero (suc zero)))"))
   "false : Bool"))

(test-case "eq/nat-eq-type-check"
  ;; nat-eq : Nat -> Nat -> Bool (which is Eq Nat after deftype expansion)
  (check-equal?
   (last (run-ns "(ns eq5)\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(check nat-eq : (-> Nat (-> Nat Bool)))"))
   "OK"))

(test-case "eq/eq-neq-same"
  ;; eq-neq nat-eq 3 3 = false (not equal → false)
  (check-equal?
   (last (run-ns "(ns eq6)\n(require [prologos.core.eq-trait :refer [nat-eq eq-neq]])\n(eval (eq-neq Nat nat-eq (suc (suc (suc zero))) (suc (suc (suc zero)))))"))
   "false : Bool"))

(test-case "eq/eq-neq-different"
  ;; eq-neq nat-eq 2 5 = true (not equal → true)
  (check-equal?
   (last (run-ns "(ns eq7)\n(require [prologos.core.eq-trait :refer [nat-eq eq-neq]])\n(eval (eq-neq Nat nat-eq (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "true : Bool"))

(test-case "eq/eq-neq-type-check"
  ;; eq-neq : Pi(A :0 Type 0). (Eq A) -> A -> A -> Bool
  ;; After deftype expansion: (-> A (-> A Bool)) is Eq A
  (check-equal?
   (last (run-ns "(ns eq8)\n(require [prologos.core.eq-trait :refer [eq-neq]])\n(check eq-neq : (Pi (A :0 (Type 0)) (-> (-> A (-> A Bool)) (-> A (-> A Bool)))))"))
   "OK"))

;; ========================================
;; prologos.core.ord-trait — Ord dictionary-passing
;; ========================================

(test-case "ord/nat-ord-lt"
  ;; nat-ord 2 5 → lt-ord → match to extract
  (check-equal?
   (last (run-ns "(ns ord1)\n(require [prologos.core.ord-trait :refer [nat-ord]])\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))"))
   "0N : Nat"))

(test-case "ord/nat-ord-eq"
  ;; nat-ord 3 3 → eq-ord → match to extract
  (check-equal?
   (last (run-ns "(ns ord2)\n(require [prologos.core.ord-trait :refer [nat-ord]])\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (nat-ord (suc (suc (suc zero))) (suc (suc (suc zero)))) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))"))
   "1N : Nat"))

(test-case "ord/nat-ord-gt"
  ;; nat-ord 5 2 → gt-ord → match to extract
  (check-equal?
   (last (run-ns "(ns ord3)\n(require [prologos.core.ord-trait :refer [nat-ord]])\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (nat-ord (suc (suc (suc (suc (suc zero))))) (suc (suc zero))) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))"))
   "2N : Nat"))

(test-case "ord/nat-ord-type-check"
  ;; nat-ord : Nat -> Nat -> Ordering (which is Ord Nat after deftype expansion)
  (check-equal?
   (last (run-ns "(ns ord4)\n(require [prologos.core.ord-trait :refer [nat-ord]])\n(require [prologos.data.ordering :refer [Ordering]])\n(check nat-ord : (-> Nat (-> Nat Ordering)))"))
   "OK"))

;; --- Ord derived operations ---

(test-case "ord/ord-lt-true"
  ;; ord-lt nat-ord 2 5 = true
  (check-equal?
   (last (run-ns "(ns ol1)\n(require [prologos.core.ord-trait :refer [nat-ord ord-lt]])\n(eval (ord-lt Nat nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "true : Bool"))

(test-case "ord/ord-lt-false"
  ;; ord-lt nat-ord 5 2 = false
  (check-equal?
   (last (run-ns "(ns ol2)\n(require [prologos.core.ord-trait :refer [nat-ord ord-lt]])\n(eval (ord-lt Nat nat-ord (suc (suc (suc (suc (suc zero))))) (suc (suc zero))))"))
   "false : Bool"))

(test-case "ord/ord-le-eq"
  ;; ord-le nat-ord 3 3 = true
  (check-equal?
   (last (run-ns "(ns ol3)\n(require [prologos.core.ord-trait :refer [nat-ord ord-le]])\n(eval (ord-le Nat nat-ord (suc (suc (suc zero))) (suc (suc (suc zero)))))"))
   "true : Bool"))

(test-case "ord/ord-le-lt"
  ;; ord-le nat-ord 2 5 = true
  (check-equal?
   (last (run-ns "(ns ol4)\n(require [prologos.core.ord-trait :refer [nat-ord ord-le]])\n(eval (ord-le Nat nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "true : Bool"))

(test-case "ord/ord-le-gt"
  ;; ord-le nat-ord 5 2 = false
  (check-equal?
   (last (run-ns "(ns ol5)\n(require [prologos.core.ord-trait :refer [nat-ord ord-le]])\n(eval (ord-le Nat nat-ord (suc (suc (suc (suc (suc zero))))) (suc (suc zero))))"))
   "false : Bool"))

(test-case "ord/ord-gt-true"
  ;; ord-gt nat-ord 5 2 = true
  (check-equal?
   (last (run-ns "(ns og1)\n(require [prologos.core.ord-trait :refer [nat-ord ord-gt]])\n(eval (ord-gt Nat nat-ord (suc (suc (suc (suc (suc zero))))) (suc (suc zero))))"))
   "true : Bool"))

(test-case "ord/ord-gt-false"
  ;; ord-gt nat-ord 2 5 = false
  (check-equal?
   (last (run-ns "(ns og2)\n(require [prologos.core.ord-trait :refer [nat-ord ord-gt]])\n(eval (ord-gt Nat nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "false : Bool"))

(test-case "ord/ord-ge-eq"
  ;; ord-ge nat-ord 3 3 = true
  (check-equal?
   (last (run-ns "(ns oge1)\n(require [prologos.core.ord-trait :refer [nat-ord ord-ge]])\n(eval (ord-ge Nat nat-ord (suc (suc (suc zero))) (suc (suc (suc zero)))))"))
   "true : Bool"))

(test-case "ord/ord-ge-gt"
  ;; ord-ge nat-ord 5 2 = true
  (check-equal?
   (last (run-ns "(ns oge2)\n(require [prologos.core.ord-trait :refer [nat-ord ord-ge]])\n(eval (ord-ge Nat nat-ord (suc (suc (suc (suc (suc zero))))) (suc (suc zero))))"))
   "true : Bool"))

(test-case "ord/ord-ge-lt"
  ;; ord-ge nat-ord 2 5 = false
  (check-equal?
   (last (run-ns "(ns oge3)\n(require [prologos.core.ord-trait :refer [nat-ord ord-ge]])\n(eval (ord-ge Nat nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "false : Bool"))

(test-case "ord/ord-eq-same"
  ;; ord-eq nat-ord 3 3 = true
  (check-equal?
   (last (run-ns "(ns oeq1)\n(require [prologos.core.ord-trait :refer [nat-ord ord-eq]])\n(eval (ord-eq Nat nat-ord (suc (suc (suc zero))) (suc (suc (suc zero)))))"))
   "true : Bool"))

(test-case "ord/ord-eq-different"
  ;; ord-eq nat-ord 2 5 = false
  (check-equal?
   (last (run-ns "(ns oeq2)\n(require [prologos.core.ord-trait :refer [nat-ord ord-eq]])\n(eval (ord-eq Nat nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "false : Bool"))

(test-case "ord/ord-min"
  ;; ord-min nat-ord 2 5 = 2
  (check-equal?
   (last (run-ns "(ns om1)\n(require [prologos.core.ord-trait :refer [nat-ord ord-min]])\n(eval (ord-min Nat nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "2N : Nat")
  ;; ord-min nat-ord 5 2 = 2
  (check-equal?
   (last (run-ns "(ns om2)\n(require [prologos.core.ord-trait :refer [nat-ord ord-min]])\n(eval (ord-min Nat nat-ord (suc (suc (suc (suc (suc zero))))) (suc (suc zero))))"))
   "2N : Nat")
  ;; ord-min nat-ord 3 3 = 3
  (check-equal?
   (last (run-ns "(ns om3)\n(require [prologos.core.ord-trait :refer [nat-ord ord-min]])\n(eval (ord-min Nat nat-ord (suc (suc (suc zero))) (suc (suc (suc zero)))))"))
   "3N : Nat"))

(test-case "ord/ord-max"
  ;; ord-max nat-ord 2 5 = 5
  (check-equal?
   (last (run-ns "(ns omx1)\n(require [prologos.core.ord-trait :refer [nat-ord ord-max]])\n(eval (ord-max Nat nat-ord (suc (suc zero)) (suc (suc (suc (suc (suc zero)))))))"))
   "5N : Nat")
  ;; ord-max nat-ord 5 2 = 5
  (check-equal?
   (last (run-ns "(ns omx2)\n(require [prologos.core.ord-trait :refer [nat-ord ord-max]])\n(eval (ord-max Nat nat-ord (suc (suc (suc (suc (suc zero))))) (suc (suc zero))))"))
   "5N : Nat")
  ;; ord-max nat-ord 3 3 = 3
  (check-equal?
   (last (run-ns "(ns omx3)\n(require [prologos.core.ord-trait :refer [nat-ord ord-max]])\n(eval (ord-max Nat nat-ord (suc (suc (suc zero))) (suc (suc (suc zero)))))"))
   "3N : Nat"))

;; ========================================
;; Integration: List + Eq (elem)
;; ========================================

(test-case "elem/found"
  ;; 2 is in [1, 2, 3]
  (check-equal?
   (last (run-ns "(ns le1)\n(require [prologos.data.list :refer [List nil cons elem]])\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (elem Nat nat-eq (suc (suc zero)) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "true : Bool"))

(test-case "elem/not-found"
  ;; 5 is not in [1, 2, 3]
  (check-equal?
   (last (run-ns "(ns le2)\n(require [prologos.data.list :refer [List nil cons elem]])\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (elem Nat nat-eq (suc (suc (suc (suc (suc zero))))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "false : Bool"))

(test-case "elem/empty-list"
  ;; Any element not in []
  (check-equal?
   (last (run-ns "(ns le3)\n(require [prologos.data.list :refer [List nil elem]])\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (elem Nat nat-eq zero (nil Nat)))"))
   "false : Bool"))

(test-case "elem/first-element"
  ;; 0 is first in [0, 1, 2]
  (check-equal?
   (last (run-ns "(ns le4)\n(require [prologos.data.list :refer [List nil cons elem]])\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (elem Nat nat-eq zero (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "true : Bool"))

(test-case "elem/last-element"
  ;; 3 is last in [1, 2, 3]
  (check-equal?
   (last (run-ns "(ns le5)\n(require [prologos.data.list :refer [List nil cons elem]])\n(require [prologos.core.eq-trait :refer [nat-eq]])\n(eval (elem Nat nat-eq (suc (suc (suc zero))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "true : Bool"))

;; ========================================
;; match — Structural pattern matching (sexp mode)
;; ========================================

;; match on Option — some case (sexp mode)
(test-case "match/option-some"
  (check-equal?
   (last (run-ns "(ns ro1)\n(require [prologos.data.option :refer [Option none some]])\n(eval (the Nat (match (some Nat zero) (none -> (suc zero)) (some x -> x))))"))
   "0N : Nat"))

;; match on Option — none case
(test-case "match/option-none"
  (check-equal?
   (last (run-ns "(ns ro2)\n(require [prologos.data.option :refer [Option none some]])\n(eval (the Nat (match (none Nat) (none -> (suc zero)) (some x -> x))))"))
   "1N : Nat"))

;; match on Ordering — nullary constructors
(test-case "match/ordering-lt"
  (check-equal?
   (last (run-ns "(ns ro3)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (lt-ord) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))"))
   "0N : Nat"))

(test-case "match/ordering-gt"
  (check-equal?
   (last (run-ns "(ns ro4)\n(require [prologos.data.ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (gt-ord) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))"))
   "2N : Nat"))

;; match on Result — ok case
(test-case "match/result-ok"
  (check-equal?
   (last (run-ns "(ns ro5)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (the Nat (match (ok Nat Bool zero) (ok x -> x) (err _ -> (suc zero)))))"))
   "0N : Nat"))

;; match on Result — err case
(test-case "match/result-err"
  (check-equal?
   (last (run-ns "(ns ro6)\n(require [prologos.data.result :refer [Result ok err]])\n(eval (the Nat (match (err Nat Bool true) (ok x -> (suc zero)) (err _ -> zero))))"))
   "0N : Nat"))

;; match on List — nil case (structural PM)
(test-case "match/list-nil"
  ;; Match on nil list returns nil-branch value
  (check-equal?
   (last (run-ns "(ns ro7)\n(require [prologos.data.list :refer [List nil cons]])\n(eval (the Nat (match (nil Nat) (nil -> zero) (cons _ rest -> zero))))"))
   "0N : Nat"))

;; match on List — structural PM: cons gives raw tail, need explicit recursion for length
(test-case "match/length-via-match"
  (check-equal?
   (last (run-ns "(ns ro8)\n(require [prologos.data.list :refer [List nil cons length]])\n(eval (length Nat (cons Nat zero (cons Nat (suc zero) (nil Nat)))))"))
   "2N : Nat"))

;; ========================================
;; Recursive defn — self-referential function definitions
;; ========================================

;; Simple recursion: count-down n = natrec on n, calling self on predecessor
(test-case "recursive-defn/count-down"
  ;; count-down just recurses to zero (using natrec, calling itself on k)
  (check-equal?
   (last (run-ns "(ns rec1)\n(def count-down : (-> Nat Nat)\n  (fn (n : Nat) (natrec Nat zero (fn (k : Nat) (fn (_ : Nat) (count-down k))) n)))\n(eval (count-down (suc (suc (suc zero)))))"))
   "0N : Nat"))

;; Recursive defn: factorial using natrec + self-reference
;; fact 0 = 1, fact (suc k) = (suc k) * fact(k)
(test-case "recursive-defn/factorial"
  (check-equal?
   (last (run-ns "(ns rec2)\n(require [prologos.data.nat :refer [mult]])\n(def fact : (-> Nat Nat)\n  (fn (n : Nat) (natrec Nat (suc zero) (fn (k : Nat) (fn (_ : Nat) (mult (suc k) (fact k)))) n)))\n(eval (fact (suc (suc (suc zero)))))"))
   "6N : Nat")
  ;; fact(4) = 24
  (check-equal?
   (last (run-ns "(ns rec2b)\n(require [prologos.data.nat :refer [mult]])\n(def fact : (-> Nat Nat)\n  (fn (n : Nat) (natrec Nat (suc zero) (fn (k : Nat) (fn (_ : Nat) (mult (suc k) (fact k)))) n)))\n(eval (fact (suc (suc (suc (suc zero))))))"))
   "24N : Nat"))

;; Recursive defn with defn syntax
(test-case "recursive-defn/defn-syntax"
  ;; defn double-it [n : Nat] : Nat uses natrec and calls itself
  (check-equal?
   (last (run-ns "(ns rec3)\n(defn my-double [n : Nat] : Nat\n  (natrec Nat zero (fn (k : Nat) (fn (_ : Nat) (suc (suc (my-double k)))) ) n))\n(eval (my-double (suc (suc (suc zero)))))"))
   "6N : Nat"))

;; Recursive defn with match (the key use case!)
;; Sum a list of Nats using match + recursion
(test-case "recursive-defn/list-sum-with-match"
  ;; Structural match: cons gives raw tail, need explicit recursion
  (check-equal?
   (last (run-ns "(ns rec4)\n(require [prologos.data.list :refer [List nil cons]])\n(require [prologos.data.nat :refer [add]])\n(defn my-sum [xs : List Nat] : Nat\n  (match xs (nil -> zero) (cons a rest -> (add a (my-sum rest)))))\n(eval (my-sum (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "6N : Nat"))

;; Non-recursive def still works (regression check)
(test-case "recursive-defn/non-recursive-still-works"
  (check-equal?
   (last (run-ns "(ns rec5)\n(def id-nat : (-> Nat Nat) (fn (n : Nat) n))\n(eval (id-nat (suc (suc zero))))"))
   "2N : Nat"))

;; ========================================
;; Native Constructor Verification Tests
;; Tests that validate the unfold-guarded constructor architecture:
;; - User-defined types at Type 0 (not Type 1)
;; - Nested types like Option (List Nat) well-typed
;; - Composed functions work correctly
;; ========================================

(test-case "native-ctor/list-type-0"
  ;; List Nat : Type 0 (not Type 1 from Church encoding)
  (check-equal?
   (last (run-ns "(ns nc1)\n(require [prologos.data.list :refer [List]])\n(check (List Nat) : (Type 0))"))
   "OK"))

(test-case "native-ctor/option-type-0"
  ;; Option Nat : Type 0
  (check-equal?
   (last (run-ns "(ns nc2)\n(require [prologos.data.option :refer [Option]])\n(check (Option Nat) : (Type 0))"))
   "OK"))

(test-case "native-ctor/option-list-nat"
  ;; Option (List Nat) is well-typed — was ill-typed before due to universe inflation
  (check-equal?
   (last (run-ns "(ns nc3)\n(require [prologos.data.list :refer [List nil cons]])\n(require [prologos.data.option :refer [Option some none]])\n(check (some (List Nat) (cons Nat zero (nil Nat))) : (Option (List Nat)))"))
   "OK"))

(test-case "native-ctor/list-list-nat"
  ;; List (List Nat) is well-typed — was ill-typed before due to universe inflation
  (check-equal?
   (last (run-ns "(ns nc4)\n(require [prologos.data.list :refer [List nil cons]])\n(check (cons (List Nat) (cons Nat zero (nil Nat)) (nil (List Nat))) : (List (List Nat)))"))
   "OK"))

(test-case "native-ctor/compose-sum-reverse"
  ;; sum (reverse [1,2,3]) = 6 — composition works without reification
  (check-equal?
   (last (run-ns "(ns nc5)\n(require [prologos.data.list :refer [List nil cons sum reverse]])\n(eval (sum (reverse Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "6N : Nat"))

(test-case "native-ctor/compose-sum-map"
  ;; sum (map suc [1,2,3]) = 9 — composition works without reification
  (check-equal?
   (last (run-ns "(ns nc6)\n(require [prologos.data.list :refer [List nil cons sum map]])\n(require [prologos.data.nat :refer [add]])\n(def my-suc : (-> Nat Nat) (fn (n : Nat) (suc n)))\n(eval (sum (map Nat Nat my-suc (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "9N : Nat"))

(test-case "native-ctor/compose-length-filter"
  ;; length (filter zero? [0,1,2,0,3]) = 2
  (check-equal?
   (last (run-ns "(ns nc7)\n(require [prologos.data.list :refer [List nil cons length filter]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (filter Nat zero? (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat zero (cons Nat (suc (suc (suc zero))) (nil Nat)))))))))"))
   "2N : Nat"))

(test-case "native-ctor/compose-sort-sum"
  ;; sum (sort le [3,1,2]) = 6 — sort + sum compose correctly
  (check-equal?
   (last (run-ns "(ns nc8)\n(require [prologos.data.list :refer [List nil cons sum sort]])\n(require [prologos.data.nat :refer [le?]])\n(eval (sum (sort Nat le? (cons Nat (suc (suc (suc zero))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))))"))
   "6N : Nat"))

(test-case "native-ctor/nested-match"
  ;; Match on Option returning List, then match on the List
  (check-equal?
   (last (run-ns "(ns nc9)\n(require [prologos.data.list :refer [List nil cons sum]])\n(require [prologos.data.option :refer [Option some none]])\n(def my-opt : (Option (List Nat)) (some (List Nat) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))\n(eval (the Nat (match my-opt (none -> zero) (some xs -> (sum xs)))))"))
   "3N : Nat"))

;; ========================================
;; Implicit Argument Inference Tests
;; ========================================

;; cons with implicit type arg (1 implicit, 2 explicit → unambiguous)
(test-case "implicit/cons-zero-nil"
  (check-equal?
   (last (run-ns "(ns imp1)\n(require [prologos.data.list :refer [List nil cons length]])\n(eval (length Nat (cons zero (nil Nat))))"))
   "1N : Nat"))

;; bare nil auto-applies (all-implicit type)
(test-case "implicit/bare-nil"
  (check-equal?
   (last (run-ns "(ns imp2)\n(require [prologos.data.list :refer [List nil length]])\n(eval (length Nat nil))"))
   "0N : Nat"))

;; cons zero nil — both cons and nil with implicit insertion
(test-case "implicit/cons-zero-bare-nil"
  (check-equal?
   (last (run-ns "(ns imp3)\n(require [prologos.data.list :refer [List nil cons length]])\n(eval (length Nat (cons zero nil)))"))
   "1N : Nat"))

;; singleton with implicit insertion (1 implicit, 1 explicit)
(test-case "implicit/singleton-zero"
  (check-equal?
   (last (run-ns "(ns imp4)\n(require [prologos.data.list :refer [List singleton length]])\n(eval (length Nat (singleton zero)))"))
   "1N : Nat"))

;; backward compat: explicit type args still work
(test-case "implicit/backward-compat-cons"
  (check-equal?
   (last (run-ns "(ns imp5)\n(require [prologos.data.list :refer [List nil cons length]])\n(eval (length Nat (cons Nat zero (nil Nat))))"))
   "1N : Nat"))

;; backward compat: explicit type args to nil still work
(test-case "implicit/backward-compat-nil"
  (check-equal?
   (last (run-ns "(ns imp6)\n(require [prologos.data.list :refer [List nil length]])\n(eval (length Nat (nil Nat)))"))
   "0N : Nat"))

;; some with implicit insertion
(test-case "implicit/some-zero"
  (check-equal?
   (last (run-ns "(ns imp7)\n(require [prologos.data.option :refer [Option some unwrap-or]])\n(eval (unwrap-or Nat (suc zero) (some Nat zero)))"))
   "0N : Nat"))

;; bare none auto-applies
(test-case "implicit/bare-none"
  (check-equal?
   (last (run-ns "(ns imp8)\n(require [prologos.data.option :refer [Option none unwrap-or]])\n(eval (unwrap-or Nat (suc zero) none))"))
   "1N : Nat"))

;; underscore _ in app args now desugars to placeholder (partial application).
;; Use explicit type argument Nat instead of _ hole.
(test-case "implicit/explicit-type-arg"
  (check-equal?
   (last (run-ns "(ns imp9)\n(require [prologos.data.list :refer [List nil cons length]])\n(eval (length Nat (cons Nat zero nil)))"))
   "1N : Nat"))

;; ========================================
;; Structural Pattern Matching (match returning ADTs)
;; ========================================
;; These tests verify that match can return higher-kinded types
;; (List, Option, Result) which live at Type 0 with native constructors.

;; map with match returns List B (Type 1)
(test-case "structural-pm/map-returns-list"
  (check-equal?
   (last (run-ns "(ns spm1)\n(require [prologos.data.list :refer [List nil cons map foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add zero (map Nat Nat (fn (x : Nat) (suc x)) (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))))"))
   "6N : Nat"))

;; map empty list
(test-case "structural-pm/map-empty"
  (check-equal?
   (last (run-ns "(ns spm2)\n(require [prologos.data.list :refer [List nil map length]])\n(eval (length Nat (map Nat Nat (fn (x : Nat) (suc x)) (nil Nat))))"))
   "0N : Nat"))

;; append with match returns List A (Type 1)
(test-case "structural-pm/append-returns-list"
  (check-equal?
   (last (run-ns "(ns spm3)\n(require [prologos.data.list :refer [List nil cons append foldr]])\n(require [prologos.data.nat :refer [add]])\n(eval (foldr Nat Nat add zero (append Nat (cons Nat (suc zero) (nil Nat)) (cons Nat (suc (suc zero)) (nil Nat)))))"))
   "3N : Nat"))

;; option/map with match returns Option B (Type 1)
(test-case "structural-pm/option-map"
  (check-equal?
   (last (run-ns "(ns spm4)\n(require [prologos.data.option :refer [Option none some map unwrap-or]])\n(eval (unwrap-or Nat zero (map Nat Nat (fn (x : Nat) (suc x)) (some Nat (suc (suc zero))))))"))
   "3N : Nat"))

;; option/flat-map with match returns Option B (Type 1)
(test-case "structural-pm/option-flat-map"
  (check-equal?
   (last (run-ns "(ns spm5)\n(require [prologos.data.option :refer [Option none some flat-map unwrap-or]])\n(eval (unwrap-or Nat zero (flat-map Nat Nat (fn (x : Nat) (some Nat (suc x))) (some Nat (suc zero)))))"))
   "2N : Nat"))

;; option/or-else with match returns Option A (Type 1)
(test-case "structural-pm/option-or-else"
  (check-equal?
   (last (run-ns "(ns spm6)\n(require [prologos.data.option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat zero (or-else Nat (none Nat) (some Nat (suc (suc (suc zero)))))))"))
   "3N : Nat"))

;; option/zip-with with nested match returns Option C (Type 1)
(test-case "structural-pm/option-zip-with"
  (check-equal?
   (last (run-ns "(ns spm7)\n(require [prologos.data.option :refer [Option none some zip-with unwrap-or]])\n(require [prologos.data.nat :refer [add]])\n(eval (unwrap-or Nat zero (zip-with Nat Nat Nat add (some Nat (suc zero)) (some Nat (suc (suc zero))))))"))
   "3N : Nat"))

;; result/map with match returns Result B E (Type 1)
(test-case "structural-pm/result-map"
  (check-equal?
   (last (run-ns "(ns spm8)\n(require [prologos.data.result :refer [Result ok err map unwrap-or]])\n(eval (unwrap-or Nat Nat zero (map Nat Nat Nat (fn (x : Nat) (suc x)) (ok Nat Nat (suc (suc zero))))))"))
   "3N : Nat"))

;; result/and-then with match returns Result B E (Type 1)
(test-case "structural-pm/result-and-then"
  (check-equal?
   (last (run-ns "(ns spm9)\n(require [prologos.data.result :refer [Result ok err and-then unwrap-or]])\n(eval (unwrap-or Nat Nat zero (and-then Nat Nat Nat (fn (x : Nat) (ok Nat Nat (suc x))) (ok Nat Nat (suc zero)))))"))
   "2N : Nat"))

;; result/or-else with match returns Result A F (Type 1)
(test-case "structural-pm/result-or-else"
  (check-equal?
   (last (run-ns "(ns spm10)\n(require [prologos.data.result :refer [Result ok err or-else unwrap-or]])\n(eval (unwrap-or Nat Nat zero (or-else Nat Nat Nat (fn (e : Nat) (ok Nat Nat (suc e))) (err Nat Nat (suc (suc zero))))))"))
   "3N : Nat"))
