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
