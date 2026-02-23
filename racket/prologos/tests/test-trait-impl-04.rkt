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
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(define (run-first s) (car (run s)))

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
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
;; Phase C.1: Functor and Foldable Traits
;; ========================================

(test-case "c1/functor-list-double"
  ;; list-functor double [1, 2, 3] = [2, 4, 6]
  (define result
    (run-ns-last
     (string-append
      "(ns c1t1)\n"
      "(require [prologos::core::functor-list :refer [list-functor]])\n"
      "(require [prologos::data::list :refer [List nil cons]])\n"
      "(require [prologos::data::nat :refer [double]])\n"
      "(eval (list-functor Nat Nat double (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))")))
  (check-equal? result "'[2N 4N 6N] : [prologos::data::list::List Nat]"))


(test-case "c1/functor-list-empty"
  ;; list-functor double [] = []
  (define result
    (run-ns-last
     (string-append
      "(ns c1t2)\n"
      "(require [prologos::core::functor-list :refer [list-functor]])\n"
      "(require [prologos::data::list :refer [List nil]])\n"
      "(require [prologos::data::nat :refer [double]])\n"
      "(eval (list-functor Nat Nat double (nil Nat)))")))
  (check-equal? result "[prologos::data::list::nil Nat] : [prologos::data::list::List Nat]"))


(test-case "c1/functor-list-type-change"
  ;; list-functor zero? [0, 1, 2] = [true, false, false]
  (define result
    (run-ns-last
     (string-append
      "(ns c1t3)\n"
      "(require [prologos::core::functor-list :refer [list-functor]])\n"
      "(require [prologos::data::list :refer [List nil cons]])\n"
      "(require [prologos::data::nat :refer [zero?]])\n"
      "(eval (list-functor Nat Bool zero? (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))")))
  (check-equal? result "'[true false false] : [prologos::data::list::List Bool]"))


(test-case "c1/foldable-list-sum"
  ;; list-foldable add 0 [1, 2, 3] = 6
  (define result
    (run-ns-last
     (string-append
      "(ns c1t4)\n"
      "(require [prologos::core::foldable-list :refer [list-foldable]])\n"
      "(require [prologos::data::list :refer [List nil cons]])\n"
      "(require [prologos::data::nat :refer [add]])\n"
      "(eval (list-foldable Nat Nat add zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))")))
  (check-equal? result "6N : Nat"))


(test-case "c1/foldable-list-empty"
  ;; list-foldable add 0 [] = 0
  (define result
    (run-ns-last
     (string-append
      "(ns c1t5)\n"
      "(require [prologos::core::foldable-list :refer [list-foldable]])\n"
      "(require [prologos::data::list :refer [List nil]])\n"
      "(require [prologos::data::nat :refer [add]])\n"
      "(eval (list-foldable Nat Nat add zero (nil Nat)))")))
  (check-equal? result "0N : Nat"))


(test-case "c1/foldable-list-count"
  ;; Count elements: foldr (\_ n -> suc n) 0 [a, b, c] = 3
  (define result
    (run-ns-last
     (string-append
      "(ns c1t6)\n"
      "(require [prologos::core::foldable-list :refer [list-foldable]])\n"
      "(require [prologos::data::list :refer [List nil cons]])\n"
      "(eval (list-foldable Nat Nat (fn (_ : Nat) (fn (n : Nat) (suc n))) zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))")))
  (check-equal? result "3N : Nat"))


(test-case "c1/functor-type-check"
  ;; list-functor : Functor List
  (define result
    (run-ns-last
     (string-append
      "(ns c1t7)\n"
      "(require [prologos::core::functor-list :refer [list-functor]])\n"
      "(require [prologos::core::functor-trait :refer [Functor]])\n"
      "(require [prologos::data::list :refer [List]])\n"
      "(check list-functor : (Functor List))")))
  (check-equal? result "OK"))


;; ========================================
;; Phase C.2: Seq Trait and List Instance
;; ========================================

(test-case "c2/seq-trait-loads"
  ;; Just loading seq-trait should succeed
  (define result
    (run-ns-last
     (string-append
      "(ns c2t1)\n"
      "(require [prologos::core::seq-trait :refer [Seq seq-first seq-rest seq-empty?]])\n"
      "(infer seq-first)")))
  ;; Should be a Pi type
  (check-true (string-contains? result "Pi")))


(test-case "c2/seq-list-loads"
  ;; Loading seq-list should succeed and list-seq has a Sigma type
  (define result
    (run-ns-last
     (string-append
      "(ns c2t2)\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(infer list-seq)")))
  ;; list-seq should have a Sigma type (the Seq dictionary)
  (check-true (string-contains? result "Sigma")))


(test-case "c2/seq-first-list"
  ;; seq-first on a non-empty list gives some
  (define result
    (run-ns-last
     (string-append
      "(ns c2t3)\n"
      "(require [prologos::core::seq-trait :refer [seq-first]])\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(require [prologos::data::list :refer [cons nil]])\n"
      "(eval (seq-first list-seq (cons Nat (suc zero) (cons Nat zero (nil Nat)))))")))
  (check-equal? result "[prologos::data::option::some Nat 1N] : [prologos::data::option::Option Nat]"))


(test-case "c2/seq-first-empty"
  ;; seq-first on empty list gives none
  (define result
    (run-ns-last
     (string-append
      "(ns c2t4)\n"
      "(require [prologos::core::seq-trait :refer [seq-first]])\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(require [prologos::data::list :refer [nil]])\n"
      "(eval (seq-first list-seq (nil Nat)))")))
  (check-equal? result "[prologos::data::option::none Nat] : [prologos::data::option::Option Nat]"))


(test-case "c2/seq-rest-list"
  ;; seq-rest on [1, 0] gives [0]
  (define result
    (run-ns-last
     (string-append
      "(ns c2t5)\n"
      "(require [prologos::core::seq-trait :refer [seq-rest]])\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(require [prologos::data::list :refer [cons nil]])\n"
      "(eval (seq-rest list-seq (cons Nat (suc zero) (cons Nat zero (nil Nat)))))")))
  (check-equal? result "'[0N] : [prologos::data::list::List Nat]"))


(test-case "c2/seq-empty-false"
  ;; seq-empty? on non-empty list gives false
  (define result
    (run-ns-last
     (string-append
      "(ns c2t6)\n"
      "(require [prologos::core::seq-trait :refer [seq-empty?]])\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(require [prologos::data::list :refer [cons nil]])\n"
      "(eval (seq-empty? list-seq (cons Nat zero (nil Nat))))")))
  (check-equal? result "false : Bool"))


(test-case "c2/seq-empty-true"
  ;; seq-empty? on empty list gives true
  (define result
    (run-ns-last
     (string-append
      "(ns c2t7)\n"
      "(require [prologos::core::seq-trait :refer [seq-empty?]])\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(require [prologos::data::list :refer [nil]])\n"
      "(eval (seq-empty? list-seq (nil Nat)))")))
  (check-equal? result "true : Bool"))


;; --- Generic seq-functions ---

(test-case "c2/seq-length"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t8)\n"
      "(require [prologos::core::seq-functions :refer [seq-length]])\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(require [prologos::data::list :refer [cons nil]])\n"
      "(eval (seq-length list-seq (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))")))
  (check-equal? result "3N : Nat"))


(test-case "c2/seq-length-empty"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t9)\n"
      "(require [prologos::core::seq-functions :refer [seq-length]])\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(require [prologos::data::list :refer [nil]])\n"
      "(eval (seq-length list-seq (nil Nat)))")))
  (check-equal? result "0N : Nat"))


(test-case "c2/seq-drop"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t10)\n"
      "(require [prologos::core::seq-functions :refer [seq-drop]])\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(require [prologos::data::list :refer [cons nil]])\n"
      "(eval (seq-drop list-seq (suc zero) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))")))
  (check-equal? result "'[2N 3N] : [prologos::data::list::List Nat]"))


(test-case "c2/seq-any-true"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t11)\n"
      "(require [prologos::core::seq-functions :refer [seq-any?]])\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(require [prologos::data::list :refer [cons nil]])\n"
      "(require [prologos::data::nat :refer [zero?]])\n"
      "(eval (seq-any? list-seq zero? (cons Nat (suc zero) (cons Nat zero (nil Nat)))))")))
  (check-equal? result "true : Bool"))


(test-case "c2/seq-any-false"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t12)\n"
      "(require [prologos::core::seq-functions :refer [seq-any?]])\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(require [prologos::data::list :refer [cons nil]])\n"
      "(require [prologos::data::nat :refer [zero?]])\n"
      "(eval (seq-any? list-seq zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))")))
  (check-equal? result "false : Bool"))


(test-case "c2/seq-all-true"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t13)\n"
      "(require [prologos::core::seq-functions :refer [seq-all?]])\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(require [prologos::data::list :refer [cons nil]])\n"
      "(require [prologos::data::nat :refer [zero?]])\n"
      "(eval (seq-all? list-seq zero? (cons Nat zero (cons Nat zero (nil Nat)))))")))
  (check-equal? result "true : Bool"))


(test-case "c2/seq-all-false"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t14)\n"
      "(require [prologos::core::seq-functions :refer [seq-all?]])\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(require [prologos::data::list :refer [cons nil]])\n"
      "(require [prologos::data::nat :refer [zero?]])\n"
      "(eval (seq-all? list-seq zero? (cons Nat zero (cons Nat (suc zero) (nil Nat)))))")))
  (check-equal? result "false : Bool"))


(test-case "c2/seq-find-found"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t15)\n"
      "(require [prologos::core::seq-functions :refer [seq-find]])\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(require [prologos::data::list :refer [cons nil]])\n"
      "(require [prologos::data::nat :refer [zero?]])\n"
      "(eval (seq-find list-seq zero? (cons Nat (suc zero) (cons Nat zero (nil Nat)))))")))
  (check-equal? result "[prologos::data::option::some Nat 0N] : [prologos::data::option::Option Nat]"))


(test-case "c2/seq-find-not-found"
  (define result
    (run-ns-last
     (string-append
      "(ns c2t16)\n"
      "(require [prologos::core::seq-functions :refer [seq-find]])\n"
      "(require [prologos::core::seq-list :refer [list-seq]])\n"
      "(require [prologos::data::list :refer [cons nil]])\n"
      "(require [prologos::data::nat :refer [zero?]])\n"
      "(eval (seq-find list-seq zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))")))
  (check-equal? result "[prologos::data::option::none Nat] : [prologos::data::option::Option Nat]"))
