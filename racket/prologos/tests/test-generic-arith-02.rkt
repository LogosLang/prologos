#lang racket/base

;;;
;;; Tests for first-class generic arithmetic wrappers:
;;; plus, minus, times, divide, negate-fn, abs-fn
;;; These are proper first-class values passable to higher-order functions.
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

(define (run-ns-last s) (last (run-ns s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? (format "~a" actual) substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; Preamble: load trait defs + instances + generic-arith
(define preamble
  "(ns test)
(require (prologos::core::add-trait      :refer (Add Add-add)))
(require (prologos::core::sub-trait      :refer (Sub Sub-sub)))
(require (prologos::core::mul-trait      :refer (Mul Mul-mul)))
(require (prologos::core::div-trait      :refer (Div Div-div)))
(require (prologos::core::neg-trait      :refer (Neg Neg-neg)))
(require (prologos::core::abs-trait      :refer (Abs Abs-abs)))
(require (prologos::core::add-instances  :refer ()))
(require (prologos::core::sub-instances  :refer ()))
(require (prologos::core::mul-instances  :refer ()))
(require (prologos::core::div-instances  :refer ()))
(require (prologos::core::neg-instances  :refer ()))
(require (prologos::core::abs-instances  :refer ()))
(require (prologos::core::generic-arith  :refer (plus minus times divide negate-fn abs-fn)))
")

;; ========================================
;; Module loading
;; ========================================

(test-case "generic-arith-fc/module-loads"
  (check-not-exn
    (lambda ()
      (run-ns (string-append preamble "(infer plus)")))))

;; ========================================
;; Direct dict-passing tests (Int)
;; ========================================

(test-case "generic-arith-fc/plus-int"
  (define r (run-ns-last (string-append preamble
    "(eval (plus Int--Add--dict 10 20))")))
  (check-equal? (format "~a" r) "30 : Int"))

(test-case "generic-arith-fc/minus-int"
  (define r (run-ns-last (string-append preamble
    "(eval (minus Int--Sub--dict 10 3))")))
  (check-equal? (format "~a" r) "7 : Int"))

(test-case "generic-arith-fc/times-int"
  (define r (run-ns-last (string-append preamble
    "(eval (times Int--Mul--dict 3 4))")))
  (check-equal? (format "~a" r) "12 : Int"))

(test-case "generic-arith-fc/divide-int"
  (define r (run-ns-last (string-append preamble
    "(eval (divide Int--Div--dict 7 2))")))
  (check-equal? (format "~a" r) "3 : Int"))

(test-case "generic-arith-fc/negate-fn-int"
  (define r (run-ns-last (string-append preamble
    "(eval (negate-fn Int--Neg--dict 5))")))
  (check-equal? (format "~a" r) "-5 : Int"))

(test-case "generic-arith-fc/abs-fn-int"
  (define r (run-ns-last (string-append preamble
    "(eval (abs-fn Int--Abs--dict (negate 7)))")))
  (check-equal? (format "~a" r) "7 : Int"))

;; ========================================
;; Direct dict-passing tests (Nat)
;; ========================================

(test-case "generic-arith-fc/plus-nat"
  (define r (run-ns-last (string-append preamble
    "(eval (plus Nat--Add--dict 1N 2N))")))
  (check-contains r "3"))

(test-case "generic-arith-fc/times-nat"
  (define r (run-ns-last (string-append preamble
    "(eval (times Nat--Mul--dict 3N 4N))")))
  (check-contains r "12"))

;; ========================================
;; Type inference — should show trait constraint
;; ========================================

(test-case "generic-arith-fc/infer-plus"
  ;; Type is Pi over A, then dict : A->A->A, then A->A->A
  ;; The constraint (Add A) becomes inline: dict param has type (A A -> A)
  (define r (run-ns-last (string-append preamble "(infer plus)")))
  ;; Should be a Pi type with arrow structure
  (check-contains r "Pi"))

(test-case "generic-arith-fc/infer-negate-fn"
  (define r (run-ns-last (string-append preamble "(infer negate-fn)")))
  (check-contains r "Pi"))
