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


(test-case "surface/p8-from-rat-roundtrip"
  ;; Encode 1/2 to posit8 then decode back to rat
  (define r (run-ns-strings "(ns t)(eval (p8-to-rat (p8-from-rat (rat 1/2))))"))
  (check-true (string-contains? (last r) "1/2 : Rat")))


(test-case "surface/p32-from-int-then-to-rat"
  (define r (run-ns-strings "(ns t)(eval (p32-to-rat (p32-from-int (int 100))))"))
  (check-true (string-contains? (last r) "100 : Rat")))


;; ========================================
;; C. From trait instances (13 tests)
;; ========================================

;; Within-family exact
(test-case "from/nat-to-int"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::from-instances :refer []])"
    "(eval (From-from Nat Int Nat-Int--From--dict zero))")))
  (check-true (string-contains? (last r) "0 : Int")))


(test-case "from/int-to-rat"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::from-instances :refer []])"
    "(eval (From-from Int Rat Int-Rat--From--dict (int 42)))")))
  (check-true (string-contains? (last r) "42 : Rat")))


(test-case "from/nat-to-rat"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::from-instances :refer []])"
    "(eval (From-from Nat Rat Nat-Rat--From--dict zero))")))
  (check-true (string-contains? (last r) "0 : Rat")))


;; Posit widening (6 tests)
(test-case "from/posit8-to-posit16"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::from-instances :refer []])"
    "(eval (From-from Posit8 Posit16 Posit8-Posit16--From--dict (posit8 64)))")))
  (check-true (string-contains? (last r) "Posit16")))


(test-case "from/posit8-to-posit32"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::from-instances :refer []])"
    "(eval (From-from Posit8 Posit32 Posit8-Posit32--From--dict (posit8 64)))")))
  (check-true (string-contains? (last r) "Posit32")))


(test-case "from/posit8-to-posit64"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::from-instances :refer []])"
    "(eval (From-from Posit8 Posit64 Posit8-Posit64--From--dict (posit8 64)))")))
  (check-true (string-contains? (last r) "Posit64")))


(test-case "from/posit16-to-posit32"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::from-instances :refer []])"
    "(eval (From-from Posit16 Posit32 Posit16-Posit32--From--dict (posit16 16384)))")))
  (check-true (string-contains? (last r) "Posit32")))


(test-case "from/posit16-to-posit64"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::from-instances :refer []])"
    "(eval (From-from Posit16 Posit64 Posit16-Posit64--From--dict (posit16 16384)))")))
  (check-true (string-contains? (last r) "Posit64")))


(test-case "from/posit32-to-posit64"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::from-instances :refer []])"
    "(eval (From-from Posit32 Posit64 Posit32-Posit64--From--dict (posit32 1073741824)))")))
  (check-true (string-contains? (last r) "Posit64")))


;; Cross-family posit->rat (4 tests)
(test-case "from/posit8-to-rat"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::from-instances :refer []])"
    "(eval (From-from Posit8 Rat Posit8-Rat--From--dict (posit8 64)))")))
  (check-true (string-contains? (last r) "1 : Rat")))


(test-case "from/posit16-to-rat"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::from-instances :refer []])"
    "(eval (From-from Posit16 Rat Posit16-Rat--From--dict (posit16 16384)))")))
  (check-true (string-contains? (last r) "1 : Rat")))


(test-case "from/posit32-to-rat"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::from-instances :refer []])"
    "(eval (From-from Posit32 Rat Posit32-Rat--From--dict (posit32 1073741824)))")))
  (check-true (string-contains? (last r) "1 : Rat")))


(test-case "from/posit64-to-rat"
  (define r (run-ns-strings (string-append
    "(ns t)(require [prologos::core::from-trait :refer [From From-from]])"
    "(require [prologos::core::from-instances :refer []])"
    "(eval (From-from Posit64 Rat Posit64-Rat--From--dict (posit64 4611686018427387904)))")))
  (check-true (string-contains? (last r) "1 : Rat")))
