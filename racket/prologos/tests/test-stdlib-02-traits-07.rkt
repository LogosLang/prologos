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
               [mi (module-info ns-sym exports (current-global-env) #f (hasheq) (hasheq) (hasheq))])
          (register-module! ns-sym mi))))
    ;; Reset for second module
    (current-global-env (hasheq))
    (current-ns-context #f)
    (process-string s2)))


(test-case "native-ctor/compose-length-filter"
  ;; length (filter zero? [0,1,2,0,3]) = 2
  (check-equal?
   (last (run-ns "(ns nc7)\n(require [prologos::data::list :refer [List nil cons length filter]])\n(require [prologos::data::nat :refer [zero?]])\n(eval (length Nat (filter Nat zero? (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat zero (cons Nat (suc (suc (suc zero))) (nil Nat)))))))))"))
   "2N : Nat"))


(test-case "native-ctor/compose-sort-sum"
  ;; sum (sort le [3,1,2]) = 6 — sort + sum compose correctly
  (check-equal?
   (last (run-ns "(ns nc8)\n(require [prologos::data::list :refer [List nil cons sum sort]])\n(require [prologos::data::nat :refer [le?]])\n(eval (sum (sort Nat le? (cons Nat (suc (suc (suc zero))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))))"))
   "6N : Nat"))


(test-case "native-ctor/nested-match"
  ;; Match on Option returning List, then match on the List
  (check-equal?
   (last (run-ns "(ns nc9)\n(require [prologos::data::list :refer [List nil cons sum]])\n(require [prologos::data::option :refer [Option some none]])\n(def my-opt : (Option (List Nat)) (some (List Nat) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))\n(eval (the Nat (match my-opt (none -> zero) (some xs -> (sum xs)))))"))
   "3N : Nat"))


;; ========================================
;; Implicit Argument Inference Tests
;; ========================================

;; cons with implicit type arg (1 implicit, 2 explicit → unambiguous)
(test-case "implicit/cons-zero-nil"
  (check-equal?
   (last (run-ns "(ns imp1)\n(require [prologos::data::list :refer [List nil cons length]])\n(eval (length Nat (cons zero (nil Nat))))"))
   "1N : Nat"))


;; bare nil auto-applies (all-implicit type)
(test-case "implicit/bare-nil"
  (check-equal?
   (last (run-ns "(ns imp2)\n(require [prologos::data::list :refer [List nil length]])\n(eval (length Nat nil))"))
   "0N : Nat"))


;; cons zero nil — both cons and nil with implicit insertion
(test-case "implicit/cons-zero-bare-nil"
  (check-equal?
   (last (run-ns "(ns imp3)\n(require [prologos::data::list :refer [List nil cons length]])\n(eval (length Nat (cons zero nil)))"))
   "1N : Nat"))


;; singleton with implicit insertion (1 implicit, 1 explicit)
(test-case "implicit/singleton-zero"
  (check-equal?
   (last (run-ns "(ns imp4)\n(require [prologos::data::list :refer [List singleton length]])\n(eval (length Nat (singleton zero)))"))
   "1N : Nat"))


;; backward compat: explicit type args still work
(test-case "implicit/backward-compat-cons"
  (check-equal?
   (last (run-ns "(ns imp5)\n(require [prologos::data::list :refer [List nil cons length]])\n(eval (length Nat (cons Nat zero (nil Nat))))"))
   "1N : Nat"))


;; backward compat: explicit type args to nil still work
(test-case "implicit/backward-compat-nil"
  (check-equal?
   (last (run-ns "(ns imp6)\n(require [prologos::data::list :refer [List nil length]])\n(eval (length Nat (nil Nat)))"))
   "0N : Nat"))


;; some with implicit insertion
(test-case "implicit/some-zero"
  (check-equal?
   (last (run-ns "(ns imp7)\n(require [prologos::data::option :refer [Option some unwrap-or]])\n(eval (unwrap-or Nat (suc zero) (some Nat zero)))"))
   "0N : Nat"))


;; bare none auto-applies
(test-case "implicit/bare-none"
  (check-equal?
   (last (run-ns "(ns imp8)\n(require [prologos::data::option :refer [Option none unwrap-or]])\n(eval (unwrap-or Nat (suc zero) none))"))
   "1N : Nat"))


;; underscore _ in app args now desugars to placeholder (partial application).
;; Use explicit type argument Nat instead of _ hole.
(test-case "implicit/explicit-type-arg"
  (check-equal?
   (last (run-ns "(ns imp9)\n(require [prologos::data::list :refer [List nil cons length]])\n(eval (length Nat (cons Nat zero nil)))"))
   "1N : Nat"))


;; ========================================
;; Structural Pattern Matching (match returning ADTs)
;; ========================================
;; These tests verify that match can return higher-kinded types
;; (List, Option, Result) which live at Type 0 with native constructors.

;; map with match returns List B (Type 1)
(test-case "structural-pm/map-returns-list"
  (check-equal?
   (last (run-ns "(ns spm1)\n(require [prologos::data::list :refer [List nil cons map foldr]])\n(require [prologos::data::nat :refer [add]])\n(eval (foldr Nat Nat add zero (map Nat Nat (fn (x : Nat) (suc x)) (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))))"))
   "6N : Nat"))


;; map empty list
(test-case "structural-pm/map-empty"
  (check-equal?
   (last (run-ns "(ns spm2)\n(require [prologos::data::list :refer [List nil map length]])\n(eval (length Nat (map Nat Nat (fn (x : Nat) (suc x)) (nil Nat))))"))
   "0N : Nat"))


;; append with match returns List A (Type 1)
(test-case "structural-pm/append-returns-list"
  (check-equal?
   (last (run-ns "(ns spm3)\n(require [prologos::data::list :refer [List nil cons append foldr]])\n(require [prologos::data::nat :refer [add]])\n(eval (foldr Nat Nat add zero (append Nat (cons Nat (suc zero) (nil Nat)) (cons Nat (suc (suc zero)) (nil Nat)))))"))
   "3N : Nat"))


;; option/map with match returns Option B (Type 1)
(test-case "structural-pm/option-map"
  (check-equal?
   (last (run-ns "(ns spm4)\n(require [prologos::data::option :refer [Option none some map unwrap-or]])\n(eval (unwrap-or Nat zero (map Nat Nat (fn (x : Nat) (suc x)) (some Nat (suc (suc zero))))))"))
   "3N : Nat"))


;; option/flat-map with match returns Option B (Type 1)
(test-case "structural-pm/option-flat-map"
  (check-equal?
   (last (run-ns "(ns spm5)\n(require [prologos::data::option :refer [Option none some flat-map unwrap-or]])\n(eval (unwrap-or Nat zero (flat-map Nat Nat (fn (x : Nat) (some Nat (suc x))) (some Nat (suc zero)))))"))
   "2N : Nat"))


;; option/or-else with match returns Option A (Type 1)
(test-case "structural-pm/option-or-else"
  (check-equal?
   (last (run-ns "(ns spm6)\n(require [prologos::data::option :refer [Option none some or-else unwrap-or]])\n(eval (unwrap-or Nat zero (or-else Nat (none Nat) (some Nat (suc (suc (suc zero)))))))"))
   "3N : Nat"))


;; option/zip-with with nested match returns Option C (Type 1)
(test-case "structural-pm/option-zip-with"
  (check-equal?
   (last (run-ns "(ns spm7)\n(require [prologos::data::option :refer [Option none some zip-with unwrap-or]])\n(require [prologos::data::nat :refer [add]])\n(eval (unwrap-or Nat zero (zip-with Nat Nat Nat add (some Nat (suc zero)) (some Nat (suc (suc zero))))))"))
   "3N : Nat"))


;; result/map with match returns Result B E (Type 1)
(test-case "structural-pm/result-map"
  (check-equal?
   (last (run-ns "(ns spm8)\n(require [prologos::data::result :refer [Result ok err map unwrap-or]])\n(eval (unwrap-or Nat Nat zero (map Nat Nat Nat (fn (x : Nat) (suc x)) (ok Nat Nat (suc (suc zero))))))"))
   "3N : Nat"))


;; result/and-then with match returns Result B E (Type 1)
(test-case "structural-pm/result-and-then"
  (check-equal?
   (last (run-ns "(ns spm9)\n(require [prologos::data::result :refer [Result ok err and-then unwrap-or]])\n(eval (unwrap-or Nat Nat zero (and-then Nat Nat Nat (fn (x : Nat) (ok Nat Nat (suc x))) (ok Nat Nat (suc zero)))))"))
   "2N : Nat"))


;; result/or-else with match returns Result A F (Type 1)
(test-case "structural-pm/result-or-else"
  (check-equal?
   (last (run-ns "(ns spm10)\n(require [prologos::data::result :refer [Result ok err or-else unwrap-or]])\n(eval (unwrap-or Nat Nat zero (or-else Nat Nat Nat (fn (e : Nat) (ok Nat Nat (suc e))) (err Nat Nat (suc (suc zero))))))"))
   "3N : Nat"))
