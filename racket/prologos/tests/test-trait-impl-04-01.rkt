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
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble
  (string-append
   "(ns test)\n"
   "(imports [prologos::core::list :refer [list-functor list-foldable list-seq]])\n"
   "(imports [prologos::core::collection-traits :refer [Functor]])\n"
   "(imports [prologos::core::collection-traits :refer [Seq seq-first seq-rest seq-empty?]])\n"
   "(imports [prologos::data::list :refer [List nil cons]])\n"
   "(imports [prologos::data::nat :refer [double zero? add]])\n"
   ))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-preparse-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-preparse-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry))))

(define (run s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry shared-preparse-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg])
    (process-string s)))

(define (run-last s) (last (run s)))


;; ========================================
;; Phase C.1: Functor and Foldable Traits
;; ========================================

(test-case "c1/functor-list-double"
  ;; list-functor double [1, 2, 3] = [2, 4, 6]
  (define result
    (run-last
     "(eval (list-functor Nat Nat double (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
  (check-equal? result "'[2N 4N 6N] : [prologos::data::list::List Nat]"))


(test-case "c1/functor-list-empty"
  ;; list-functor double [] = []
  (define result
    (run-last
     "(eval (list-functor Nat Nat double (nil Nat)))"))
  (check-equal? result "[prologos::data::list::nil Nat] : [prologos::data::list::List Nat]"))


(test-case "c1/functor-list-type-change"
  ;; list-functor zero? [0, 1, 2] = [true, false, false]
  (define result
    (run-last
     "(eval (list-functor Nat Bool zero? (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
  (check-equal? result "'[true false false] : [prologos::data::list::List Bool]"))


(test-case "c1/foldable-list-sum"
  ;; list-foldable add 0 [1, 2, 3] = 6
  (define result
    (run-last
     "(eval (list-foldable Nat Nat add zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
  (check-equal? result "6N : Nat"))


(test-case "c1/foldable-list-empty"
  ;; list-foldable add 0 [] = 0
  (define result
    (run-last
     "(eval (list-foldable Nat Nat add zero (nil Nat)))"))
  (check-equal? result "0N : Nat"))


(test-case "c1/foldable-list-count"
  ;; Count elements: foldr (\_ n -> suc n) 0 [a, b, c] = 3
  (define result
    (run-last
     "(eval (list-foldable Nat Nat (fn (_ : Nat) (fn (n : Nat) (suc n))) zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
  (check-equal? result "3N : Nat"))


(test-case "c1/functor-type-check"
  ;; list-functor : Functor List
  (define result
    (run-last
     "(check list-functor : (Functor List))"))
  (check-equal? result "OK"))


;; ========================================
;; Phase C.2: Seq Trait and List Instance
;; ========================================

(test-case "c2/seq-trait-loads"
  ;; Just loading seq-trait should succeed
  (define result
    (run-last
     "(infer seq-first)"))
  ;; Should be a Pi type
  (check-true (string-contains? result "Pi")))


(test-case "c2/seq-list-loads"
  ;; Loading seq-list should succeed and list-seq has a Sigma type
  (define result
    (run-last
     "(infer list-seq)"))
  ;; list-seq should have a Sigma type (the Seq dictionary)
  (check-true (string-contains? result "Sigma")))


(test-case "c2/seq-first-list"
  ;; seq-first on a non-empty list gives some
  (define result
    (run-last
     "(eval (seq-first list-seq (cons Nat (suc zero) (cons Nat zero (nil Nat)))))"))
  (check-equal? result "[prologos::data::option::some Nat 1N] : [prologos::data::option::Option Nat]"))


(test-case "c2/seq-first-empty"
  ;; seq-first on empty list gives none
  (define result
    (run-last
     "(eval (seq-first list-seq (nil Nat)))"))
  (check-equal? result "[prologos::data::option::none Nat] : [prologos::data::option::Option Nat]"))


(test-case "c2/seq-rest-list"
  ;; seq-rest on [1, 0] gives [0]
  (define result
    (run-last
     "(eval (seq-rest list-seq (cons Nat (suc zero) (cons Nat zero (nil Nat)))))"))
  (check-equal? result "'[0N] : [prologos::data::list::List Nat]"))


(test-case "c2/seq-empty-false"
  ;; seq-empty? on non-empty list gives false
  (define result
    (run-last
     "(eval (seq-empty? list-seq (cons Nat zero (nil Nat))))"))
  (check-equal? result "false : Bool"))


(test-case "c2/seq-empty-true"
  ;; seq-empty? on empty list gives true
  (define result
    (run-last
     "(eval (seq-empty? list-seq (nil Nat)))"))
  (check-equal? result "true : Bool"))


;; --- Generic seq-functions ---
