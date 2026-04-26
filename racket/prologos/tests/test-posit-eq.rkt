#lang racket/base

;;;
;;; Tests for Posit Equality Primitives (p8-eq, p16-eq, p32-eq, p64-eq)
;;; Verifies: parser keywords, type checking, reduction, NaR semantics,
;;;           and updated Eq trait instances using primitives.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         "test-support.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../posit-impl.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../macros.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt"
         "../reduction.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (last (process-string s))))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; AST-level reduction tests (Posit32)
;; ========================================

(test-case "posit-eq/p32-eq-true"
  ;; 1.0 == 1.0 → true
  (define result (whnf (expr-p32-eq (expr-posit32 posit32-one) (expr-posit32 posit32-one))))
  (check-true (expr-true? result)))

(test-case "posit-eq/p32-eq-false"
  ;; 1.0 == 0 → false
  (define result (whnf (expr-p32-eq (expr-posit32 posit32-one) (expr-posit32 posit32-zero))))
  (check-true (expr-false? result)))

(test-case "posit-eq/p32-eq-nar-not-equal"
  ;; NaR != NaR (IEEE-style: NaN ≠ NaN)
  (define result (whnf (expr-p32-eq (expr-posit32 posit32-nar) (expr-posit32 posit32-nar))))
  (check-true (expr-false? result)))

;; ========================================
;; AST-level reduction tests (Posit8)
;; ========================================

(test-case "posit-eq/p8-eq-true"
  (define result (whnf (expr-p8-eq (expr-posit8 posit8-one) (expr-posit8 posit8-one))))
  (check-true (expr-true? result)))

(test-case "posit-eq/p8-eq-false"
  (define result (whnf (expr-p8-eq (expr-posit8 posit8-one) (expr-posit8 posit8-zero))))
  (check-true (expr-false? result)))

(test-case "posit-eq/p8-eq-nar"
  (define result (whnf (expr-p8-eq (expr-posit8 posit8-nar) (expr-posit8 posit8-nar))))
  (check-true (expr-false? result)))

;; ========================================
;; AST-level reduction tests (Posit16, Posit64)
;; ========================================

(test-case "posit-eq/p16-eq-true"
  (define result (whnf (expr-p16-eq (expr-posit16 posit16-one) (expr-posit16 posit16-one))))
  (check-true (expr-true? result)))

(test-case "posit-eq/p64-eq-true"
  (define result (whnf (expr-p64-eq (expr-posit64 posit64-one) (expr-posit64 posit64-one))))
  (check-true (expr-true? result)))

;; ========================================
;; Surface syntax (sexp mode)
;; ========================================

(test-case "posit-eq/surface-p32-eq-true"
  (define result (run "(eval (p32-eq (posit32 1073741824) (posit32 1073741824)))"))
  (check-contains result "true"))

(test-case "posit-eq/surface-p32-eq-false"
  (define result (run "(eval (p32-eq (posit32 1073741824) (posit32 0)))"))
  (check-contains result "false"))

(test-case "posit-eq/surface-p8-eq"
  (define result (run "(eval (p8-eq (posit8 64) (posit8 64)))"))
  (check-contains result "true"))

(test-case "posit-eq/surface-p16-eq"
  (define result (run "(eval (p16-eq (posit16 16384) (posit16 0)))"))
  (check-contains result "false"))

(test-case "posit-eq/surface-p64-eq"
  (define result (run "(eval (p64-eq (posit64 4611686018427387904) (posit64 4611686018427387904)))"))
  (check-contains result "true"))

;; ========================================
;; Type inference
;; ========================================

(test-case "posit-eq/type-infer-p32-eq"
  (define result (run "(infer (p32-eq (posit32 0) (posit32 0)))"))
  (check-contains result "Bool"))

;; ========================================
;; Trait-based eq? using new primitives
;; ========================================

(define preamble
  "(ns test)
(imports (prologos::core::eq :refer (Eq Eq-eq?)))
(imports (prologos::core::eq :refer ()))
")

(test-case "posit-eq/trait-eq-posit32"
  (define result (run (string-append preamble
    "(eval (Eq-eq? Posit32 Posit32--Eq--dict ~1 ~1))")))
  (check-contains result "true"))

(test-case "posit-eq/trait-eq-posit32-false"
  (define result (run (string-append preamble
    "(eval (Eq-eq? Posit32 Posit32--Eq--dict ~1 ~2))")))
  (check-contains result "false"))
