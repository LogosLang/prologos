#lang racket/base

;;;
;;; Tests for Phase 3f: Cross-Family Conversions
;;; From/TryFrom/Into traits, p{N}-to-rat, p{N}-from-rat, p{N}-from-int primitives
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
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../posit-impl.rkt")

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
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s) (last (run-ns s)))

(define (run-ns-strings s)
  (filter string? (run-ns s)))


;; ========================================
;; D. TryFrom trait instances (4 tests)
;; ========================================

(test-case "tryfrom/rat-to-posit8"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::tryfrom-trait :refer [TryFrom TryFrom-try-from]])"
    "(require [prologos::data::option :refer [Option some none]])"
    "(require [prologos::core::tryfrom-instances :refer []])"
    "(eval (TryFrom-try-from Rat Posit8 Rat-Posit8--TryFrom--dict (rat 1/2)))")))
  (check-true (string-contains? (last r) "some")))


(test-case "tryfrom/rat-to-posit32"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::tryfrom-trait :refer [TryFrom TryFrom-try-from]])"
    "(require [prologos::data::option :refer [Option some none]])"
    "(require [prologos::core::tryfrom-instances :refer []])"
    "(eval (TryFrom-try-from Rat Posit32 Rat-Posit32--TryFrom--dict (rat 3/7)))")))
  (check-true (string-contains? (last r) "some")))


(test-case "tryfrom/int-to-posit16"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::tryfrom-trait :refer [TryFrom TryFrom-try-from]])"
    "(require [prologos::data::option :refer [Option some none]])"
    "(require [prologos::core::tryfrom-instances :refer []])"
    "(eval (TryFrom-try-from Int Posit16 Int-Posit16--TryFrom--dict (int 42)))")))
  (check-true (string-contains? (last r) "some")))


(test-case "tryfrom/int-to-posit64"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::tryfrom-trait :refer [TryFrom TryFrom-try-from]])"
    "(require [prologos::data::option :refer [Option some none]])"
    "(require [prologos::core::tryfrom-instances :refer []])"
    "(eval (TryFrom-try-from Int Posit64 Int-Posit64--TryFrom--dict (int 100)))")))
  (check-true (string-contains? (last r) "some")))


;; ========================================
;; E. Into trait derivation (2 tests)
;; ========================================

(test-case "into/trait-definition-loads"
  ;; Into trait definition + parametric impl registers correctly via WS loading
  (define r (run-ns-strings (string-append
    "(ns t)"
    "(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::into-trait :refer [Into Into-into]])"
    "(infer Into-into)")))
  (check-true (not (null? r)))
  (check-true (string-contains? (last r) "Pi")))


(test-case "into/parametric-resolution-via-from"
  ;; Define From Nat Int, then resolve Into Nat Int parametrically
  (define r (run-ns (string-append
    "(ns t)"
    "(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::into-trait :refer [Into Into-into]])"
    "(require [prologos::core::from-instances :refer []])"
    ;; Into-into with explicit dict: should typecheck
    "(check (Into-into Nat Int Nat-Int--From--dict zero) : Int)")))
  (define strs (filter string? r))
  ;; The check should pass (OK)
  (check-true (ormap (lambda (s) (or (string-contains? s "OK") (string-contains? s "✓"))) strs)))


;; ========================================
;; F. FromInt/FromRat posit instances (4 tests)
;; ========================================

(test-case "fromint/posit32"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::fromint-trait :refer [FromInt FromInt-from-integer]])"
    "(require [prologos::core::fromint-posit-instances :refer []])"
    "(eval (FromInt-from-integer Posit32 Posit32--FromInt--dict (int 42)))")))
  (check-true (string-contains? (last r) "Posit32")))


(test-case "fromint/posit8"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::fromint-trait :refer [FromInt FromInt-from-integer]])"
    "(require [prologos::core::fromint-posit-instances :refer []])"
    "(eval (FromInt-from-integer Posit8 Posit8--FromInt--dict (int 1)))")))
  (check-true (string-contains? (last r) "Posit8")))


(test-case "fromrat/posit32"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::fromrat-trait :refer [FromRat FromRat-from-rational]])"
    "(require [prologos::core::fromrat-posit-instances :refer []])"
    "(eval (FromRat-from-rational Posit32 Posit32--FromRat--dict (rat 3/7)))")))
  (check-true (string-contains? (last r) "Posit32")))


(test-case "fromrat/posit64"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::fromrat-trait :refer [FromRat FromRat-from-rational]])"
    "(require [prologos::core::fromrat-posit-instances :refer []])"
    "(eval (FromRat-from-rational Posit64 Posit64--FromRat--dict (rat 1/3)))")))
  (check-true (string-contains? (last r) "Posit64")))


;; ========================================
;; G. Edge cases (4 tests)
;; ========================================

(test-case "edge/p8-to-rat-nar-returns-error"
  ;; NaR (0x80 = 128 for posit8) should reduce to expr-error
  (check-true (expr-error? (whnf (expr-p8-to-rat (expr-posit8 128))))))


(test-case "edge/p16-to-rat-nar-returns-error"
  ;; NaR (0x8000 = 32768 for posit16)
  (check-true (expr-error? (whnf (expr-p16-to-rat (expr-posit16 32768))))))


(test-case "edge/p32-from-rat-zero"
  (check-equal? (whnf (expr-p32-from-rat (expr-rat 0))) (expr-posit32 0)))


(test-case "edge/p64-from-int-zero"
  (check-equal? (whnf (expr-p64-from-int (expr-int 0))) (expr-posit64 0)))


;; ========================================
;; H. Backward compatibility (3 tests)
;; ========================================

(test-case "compat/from-nat-still-works"
  (define r (run-ns-strings "(ns t)(eval (from-nat zero))"))
  (check-true (string-contains? (last r) "0 : Int")))


(test-case "compat/from-int-still-works"
  (define r (run-ns-strings "(ns t)(eval (from-int (int 42)))"))
  (check-true (string-contains? (last r) "42 : Rat")))


(test-case "compat/p8-from-nat-still-works"
  (define r (run-ns-strings "(ns t)(eval (p8-from-nat (suc zero)))"))
  (check-true (string-contains? (last r) "Posit8")))
