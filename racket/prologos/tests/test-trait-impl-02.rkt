#lang racket/base

;;;
;;; Tests for trait/impl system (macros.rkt layer 1)
;;; Phase A.1: trait declarations
;;; Phase A.2: impl declarations
;;;

(require rackunit
         racket/list
         racket/path
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
         "../namespace.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string s)))

(define (run-first s) (car (run s)))

(define (run-ns s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s) (last (run-ns s)))


;; ========================================
;; Phase A.1: Trait Registration Smoke Tests
;; ========================================

(test-case "trait/method-type-parsing-arrow"
  ;; Verify that A -> A -> Bool becomes (-> A (-> A Bool))
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)])
    (define m (parse-trait-method '(== : A -> A -> Bool) 'Eq))
    (check-equal? (trait-method-name m) '==)
    (check-equal? (trait-method-type-datum m) '(-> A (-> A Bool)))))


(test-case "trait/method-type-parsing-no-arrow"
  ;; Bare type: (count : Nat)
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)])
    (define m (parse-trait-method '(count : Nat) 'Counter))
    (check-equal? (trait-method-type-datum m) 'Nat)))


(test-case "trait/method-type-parsing-applied"
  ;; Applied type in return: (first : S A -> A)
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry (hasheq)])
    (define m (parse-trait-method '(toList : A -> (List A)) 'ToList))
    (check-equal? (trait-method-type-datum m) '(-> A (List A)))))


;; ========================================
;; Phase B.1: New Data Types — Either, Never
;; ========================================

(test-case "b1/either-left-right"
  ;; Either with left and right constructors
  (define result
    (run-ns-last
     (string-append
      "(ns either-t1)\n"
      "(imports [prologos::data::either :refer [Either left right left? right?]])\n"
      "(eval (left? (left Nat Bool (suc zero))))")))
  (check-equal? result "true : Bool"))


(test-case "b1/either-map"
  ;; map over Either right value — implicit type params inferred
  (define result
    (run-ns-last
     (string-append
      "(ns either-t2)\n"
      "(imports [prologos::data::either :refer [Either left right map]])\n"
      "(eval (map (fn [x <Nat>] (suc x)) (right Bool Nat zero)))")))
  ;; Output has qualified names: [prologos::data::either::right Bool Nat 1]
  (check-true (string-contains? result "right"))
  (check-true (string-contains? result "Either")))


(test-case "b1/either-to-option"
  ;; Convert Either to Option
  (define result
    (run-ns-last
     (string-append
      "(ns either-t3)\n"
      "(imports [prologos::data::either :refer [Either left right to-option]])\n"
      "(imports [prologos::data::option :refer [Option none some]])\n"
      "(eval (to-option Nat Nat (right Nat Nat (suc zero))))")))
  (check-true (string-contains? result "some"))
  (check-true (string-contains? result "1")))


(test-case "b1/never-type-exists"
  ;; Never type can be defined (zero constructors)
  (define result
    (run-ns-last
     (string-append
      "(ns never-t1)\n"
      "(imports [prologos::data::never :refer [Never]])\n"
      "(check Never : (Type 0))")))
  (check-equal? result "OK"))


(test-case "b1/zero-ctor-data"
  ;; Zero-constructor data produces just the type def
  (parameterize ([current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (define defs (process-data '(data Void)))
    (check-equal? (length defs) 1)
    (check-equal? (cadr (car defs)) 'Void)))


;; ========================================
;; Phase D.1: Extended Option/Result/Pair Combinators
;; ========================================

(test-case "d1/option-some?"
  (define result
    (run-ns-last
     (string-append
      "(ns opt-t1)\n"
      "(imports [prologos::data::option :refer [some none some?]])\n"
      "(eval (some? (some Nat zero)))")))
  (check-equal? result "true : Bool"))


(test-case "d1/option-none?"
  (define result
    (run-ns-last
     (string-append
      "(ns opt-t2)\n"
      "(imports [prologos::data::option :refer [some none none?]])\n"
      "(eval (none? (none Nat)))")))
  (check-equal? result "true : Bool"))


(test-case "d1/option-flatten"
  (define result
    (run-ns-last
     (string-append
      "(ns opt-t3)\n"
      "(imports [prologos::data::option :refer [Option some none flatten]])\n"
      "(eval (flatten (some (Option Nat) (some Nat zero))))")))
  (check-true (string-contains? result "some"))
  (check-true (string-contains? result "0N")))


(test-case "d1/result-ok?"
  (define result
    (run-ns-last
     (string-append
      "(ns res-t1)\n"
      "(imports [prologos::data::result :refer [ok err ok?]])\n"
      "(eval (ok? (ok Nat Bool zero)))")))
  (check-equal? result "true : Bool"))


(test-case "d1/result-err?"
  (define result
    (run-ns-last
     (string-append
      "(ns res-t2)\n"
      "(imports [prologos::data::result :refer [ok err err?]])\n"
      "(eval (err? (err Nat Bool true)))")))
  (check-equal? result "true : Bool"))


(test-case "d1/result-to-option"
  (define result
    (run-ns-last
     (string-append
      "(ns res-t3)\n"
      "(imports [prologos::data::result :refer [ok err to-option]])\n"
      "(eval (to-option (ok Nat Bool (suc zero))))")))
  (check-true (string-contains? result "some")))


(test-case "d1/pair-dup"
  (define result
    (run-ns-last
     (string-append
      "(ns pair-t1)\n"
      "(imports [prologos::data::pair :refer [dup]])\n"
      "(eval (fst (dup Nat zero)))")))
  (check-equal? result "0N : Nat"))


(test-case "d1/pair-uncurry"
  (define result
    (run-ns-last
     (string-append
      "(ns pair-t2)\n"
      "(imports [prologos::data::nat :refer [add]])\n"
      "(imports [prologos::data::pair :refer [uncurry]])\n"
      "(eval (uncurry add (pair (suc zero) (suc (suc zero)))))")))
  (check-equal? result "3N : Nat"))
