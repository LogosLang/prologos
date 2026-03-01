#lang racket/base

;;;
;;; Tests for Phase 3: Eq/Ord Instance Expansion + PartialOrd
;;; Tests eq-instances, ord-instances, eq-derived, partialord-trait.
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
         "../namespace.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s)
  (last (run-ns s)))

(define preamble
  "(ns test)
(require (prologos::core::eq :refer (Eq Eq-eq? eq-neq)))
(require (prologos::core::ord :refer (Ord Ord-compare ord-lt ord-le ord-gt ord-ge ord-eq ord-min ord-max)))
(require (prologos::core::eq :refer ()))
(require (prologos::core::ord :refer ()))
(require (prologos::core::eq :refer (option-eq)))
(require (prologos::core::eq-derived :refer (list-eq)))
(require (prologos::core::ord :refer (PartialOrd PartialOrd-partial-compare)))
(require (prologos::data::option :refer (Option some none)))
(require (prologos::data::list :refer (List nil cons)))
(require (prologos::data::ordering :refer (Ordering lt-ord eq-ord gt-ord)))
")

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))


;; Derived ord operations on Bool
(test-case "ord-ext/bool-lt"
  (check-contains
   (run-ns-last (string-append preamble "(eval (ord-lt Bool--Ord--dict false true))"))
   "true : Bool"))


(test-case "ord-ext/bool-le"
  (check-contains
   (run-ns-last (string-append preamble "(eval (ord-le Bool--Ord--dict false true))"))
   "true : Bool"))


;; ========================================
;; Derived option-eq
;; ========================================

(test-case "eq-derived/option-some-eq"
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (option-eq Nat--Eq--dict (some Nat (suc (suc (suc zero)))) (some Nat (suc (suc (suc zero))))))"))
   "true : Bool"))


(test-case "eq-derived/option-some-neq"
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (option-eq Nat--Eq--dict (some Nat (suc zero)) (some Nat (suc (suc zero)))))"))
   "false : Bool"))


(test-case "eq-derived/option-none-none"
  (check-contains
   (run-ns-last (string-append preamble "(eval (option-eq Nat--Eq--dict (none Nat) (none Nat)))"))
   "true : Bool"))


(test-case "eq-derived/option-some-none"
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (option-eq Nat--Eq--dict (some Nat zero) (none Nat)))"))
   "false : Bool"))


;; ========================================
;; Derived list-eq
;; ========================================

(test-case "eq-derived/list-eq-equal"
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (list-eq Nat--Eq--dict (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))"))
   "true : Bool"))


(test-case "eq-derived/list-eq-diff-elem"
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (list-eq Nat--Eq--dict (cons Nat (suc zero) (nil Nat)) (cons Nat (suc (suc zero)) (nil Nat))))"))
   "false : Bool"))


(test-case "eq-derived/list-eq-nil-nil"
  (check-contains
   (run-ns-last (string-append preamble "(eval (list-eq Nat--Eq--dict (nil Nat) (nil Nat)))"))
   "true : Bool"))


(test-case "eq-derived/list-eq-diff-length"
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (list-eq Nat--Eq--dict (cons Nat zero (nil Nat)) (nil Nat)))"))
   "false : Bool"))


;; ========================================
;; PartialOrd trait
;; ========================================

(test-case "partialord/loads"
  ;; PartialOrd-partial-compare should have a function type
  (define result (run-ns-last (string-append preamble "(infer PartialOrd-partial-compare)")))
  (check-contains result "->")
  (check-contains result "Option")
  (check-contains result "Ordering"))


;; ========================================
;; Module loading
;; ========================================

(test-case "eq-ext/module-load"
  (define results (run-ns (string-append preamble
    "(infer Bool--Eq--dict)
     (infer Ordering--Eq--dict)
     (infer Bool--Ord--dict)
     (infer option-eq)
     (infer list-eq)")))
  (define type-results (filter string? results))
  (check-true (>= (length type-results) 5)
              "Expected at least 5 type-string results"))
