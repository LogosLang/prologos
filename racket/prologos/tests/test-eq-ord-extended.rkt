#lang racket/base

;;;
;;; Tests for Phase 3: Eq/Ord Instance Expansion + PartialOrd
;;; Tests eq-instances, ord-instances, eq-derived, partialord-trait.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
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

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s)
  (last (run-ns s)))

(define preamble
  "(ns test)
(require (prologos.core.eq-trait :refer (Eq Eq-eq? eq-neq)))
(require (prologos.core.ord-trait :refer (Ord Ord-compare ord-lt ord-le ord-gt ord-ge ord-eq ord-min ord-max)))
(require (prologos.core.eq-instances :refer ()))
(require (prologos.core.ord-instances :refer ()))
(require (prologos.core.eq-derived :refer (option-eq list-eq)))
(require (prologos.core.partialord-trait :refer (PartialOrd PartialOrd-partial-compare)))
(require (prologos.data.option :refer (Option some none)))
(require (prologos.data.list :refer (List nil cons)))
(require (prologos.data.ordering :refer (Ordering lt-ord eq-ord gt-ord)))
")

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Eq Bool
;; ========================================

(test-case "eq-ext/bool-true-true"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Eq--eq? true true))"))
   "true : Bool"))

(test-case "eq-ext/bool-true-false"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Eq--eq? true false))"))
   "false : Bool"))

(test-case "eq-ext/bool-false-false"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Eq--eq? false false))"))
   "true : Bool"))

(test-case "eq-ext/bool-false-true"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Eq--eq? false true))"))
   "false : Bool"))

;; ========================================
;; Eq Ordering
;; ========================================

(test-case "eq-ext/ordering-lt-lt"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Ordering--Eq--eq? lt-ord lt-ord))"))
   "true : Bool"))

(test-case "eq-ext/ordering-lt-gt"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Ordering--Eq--eq? lt-ord gt-ord))"))
   "false : Bool"))

(test-case "eq-ext/ordering-eq-eq"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Ordering--Eq--eq? eq-ord eq-ord))"))
   "true : Bool"))

(test-case "eq-ext/ordering-gt-gt"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Ordering--Eq--eq? gt-ord gt-ord))"))
   "true : Bool"))

;; ========================================
;; Ord Bool — false < true
;; ========================================

(test-case "ord-ext/bool-false-true"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Ord--compare false true))"))
   "lt-ord"))

(test-case "ord-ext/bool-true-true"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Ord--compare true true))"))
   "eq-ord"))

(test-case "ord-ext/bool-true-false"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Ord--compare true false))"))
   "gt-ord"))

(test-case "ord-ext/bool-false-false"
  (check-contains
   (run-ns-last (string-append preamble "(eval (Bool--Ord--compare false false))"))
   "eq-ord"))

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
