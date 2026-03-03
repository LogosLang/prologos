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
   "(imports [prologos::core::generic-ops :refer [seq-length seq-drop seq-any? seq-all? seq-find]])\n"
   "(imports [prologos::core::list :refer [list-seq]])\n"
   "(imports [prologos::data::list :refer [cons nil]])\n"
   "(imports [prologos::data::nat :refer [zero?]])\n"
   ))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-preparse-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg)
  (parameterize ([current-global-env (hasheq)]
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

;; --- Generic seq-functions ---

(test-case "c2/seq-length"
  (define result
    (run-last
     "(eval (seq-length list-seq (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
  (check-equal? result "3N : Nat"))


(test-case "c2/seq-length-empty"
  (define result
    (run-last
     "(eval (seq-length list-seq (nil Nat)))"))
  (check-equal? result "0N : Nat"))


(test-case "c2/seq-drop"
  (define result
    (run-last
     "(eval (seq-drop list-seq (suc zero) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
  (check-equal? result "'[2N 3N] : [prologos::data::list::List Nat]"))


(test-case "c2/seq-any-true"
  (define result
    (run-last
     "(eval (seq-any? list-seq zero? (cons Nat (suc zero) (cons Nat zero (nil Nat)))))"))
  (check-equal? result "true : Bool"))


(test-case "c2/seq-any-false"
  (define result
    (run-last
     "(eval (seq-any? list-seq zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))"))
  (check-equal? result "false : Bool"))


(test-case "c2/seq-all-true"
  (define result
    (run-last
     "(eval (seq-all? list-seq zero? (cons Nat zero (cons Nat zero (nil Nat)))))"))
  (check-equal? result "true : Bool"))


(test-case "c2/seq-all-false"
  (define result
    (run-last
     "(eval (seq-all? list-seq zero? (cons Nat zero (cons Nat (suc zero) (nil Nat)))))"))
  (check-equal? result "false : Bool"))


(test-case "c2/seq-find-found"
  (define result
    (run-last
     "(eval (seq-find list-seq zero? (cons Nat (suc zero) (cons Nat zero (nil Nat)))))"))
  (check-equal? result "[prologos::data::option::some Nat 0N] : [prologos::data::option::Option Nat]"))


(test-case "c2/seq-find-not-found"
  (define result
    (run-last
     "(eval (seq-find list-seq zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))"))
  (check-equal? result "[prologos::data::option::none Nat] : [prologos::data::option::Option Nat]"))
