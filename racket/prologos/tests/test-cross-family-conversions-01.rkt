#lang racket/base

;;;
;;; Tests for Phase 3f: Cross-Family Conversions
;;; From/TryFrom/Into traits, p{N}-to-rat, p{N}-from-rat, p{N}-from-int primitives
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
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../posit-impl.rkt")

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
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s) (last (run-ns s)))

(define (run-ns-strings s)
  (filter string? (run-ns s)))


;; ========================================
;; A. Primitive unit tests (12 tests)
;; ========================================

;; p{N}-to-rat
(test-case "prim/p8-to-rat-converts-1.0"
  (check-equal? (whnf (expr-p8-to-rat (expr-posit8 64))) (expr-rat 1)))

(test-case "prim/p16-to-rat-converts-1.0"
  (check-equal? (whnf (expr-p16-to-rat (expr-posit16 16384))) (expr-rat 1)))

(test-case "prim/p32-to-rat-converts-1.0"
  (check-equal? (whnf (expr-p32-to-rat (expr-posit32 1073741824))) (expr-rat 1)))

(test-case "prim/p64-to-rat-converts-1.0"
  (check-equal? (whnf (expr-p64-to-rat (expr-posit64 4611686018427387904))) (expr-rat 1)))


;; p{N}-from-rat: use posit-encode to compute expected values
(test-case "prim/p8-from-rat-converts-half"
  (check-equal? (whnf (expr-p8-from-rat (expr-rat 1/2))) (expr-posit8 (posit8-encode 1/2))))

(test-case "prim/p16-from-rat-converts-half"
  (check-equal? (whnf (expr-p16-from-rat (expr-rat 1/2))) (expr-posit16 (posit16-encode 1/2))))

(test-case "prim/p32-from-rat-converts-half"
  (check-equal? (whnf (expr-p32-from-rat (expr-rat 1/2))) (expr-posit32 (posit32-encode 1/2))))

(test-case "prim/p64-from-rat-converts-half"
  (check-equal? (whnf (expr-p64-from-rat (expr-rat 1/2))) (expr-posit64 (posit64-encode 1/2))))


;; p{N}-from-int
(test-case "prim/p8-from-int-converts-42"
  (check-equal? (whnf (expr-p8-from-int (expr-int 42))) (expr-posit8 (posit8-encode 42))))

(test-case "prim/p16-from-int-converts-42"
  (check-equal? (whnf (expr-p16-from-int (expr-int 42))) (expr-posit16 (posit16-encode 42))))

(test-case "prim/p32-from-int-converts-42"
  (check-equal? (whnf (expr-p32-from-int (expr-int 42))) (expr-posit32 (posit32-encode 42))))

(test-case "prim/p64-from-int-converts-42"
  (check-equal? (whnf (expr-p64-from-int (expr-int 42))) (expr-posit64 (posit64-encode 42))))


;; ========================================
;; B. Surface E2E primitives (6 tests)
;; ========================================

(test-case "surface/p8-to-rat"
  (define r (run-ns-strings "(ns t)(eval (p8-to-rat (posit8 64)))"))
  (check-true (string-contains? (last r) "1 : Rat")))


(test-case "surface/p32-from-rat"
  (define r (run-ns-strings "(ns t)(eval (p32-from-rat (rat 3/7)))"))
  (check-true (string-contains? (last r) "Posit32")))


(test-case "surface/p16-from-int"
  (define r (run-ns-strings "(ns t)(eval (p16-from-int (int 42)))"))
  (check-true (string-contains? (last r) "Posit16")))


(test-case "surface/p64-to-rat"
  (define r (run-ns-strings "(ns t)(eval (p64-to-rat (posit64 4611686018427387904)))"))
  (check-true (string-contains? (last r) "1 : Rat")))
