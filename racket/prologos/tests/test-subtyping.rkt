#lang racket/base

;;;
;;; Tests for Phase 3e: Within-Family Subtyping
;;; Exact:  Nat <: Int <: Rat
;;; Posit:  Posit8 <: Posit16 <: Posit32 <: Posit64
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
;; A. subtype? predicate unit tests
;; ========================================

(test-case "subtype?/nat-to-int"
  (check-true (tc:subtype? (expr-Nat) (expr-Int))))

(test-case "subtype?/nat-to-rat"
  (check-true (tc:subtype? (expr-Nat) (expr-Rat))))

(test-case "subtype?/int-to-rat"
  (check-true (tc:subtype? (expr-Int) (expr-Rat))))

(test-case "subtype?/posit8-to-posit16"
  (check-true (tc:subtype? (expr-Posit8) (expr-Posit16))))

(test-case "subtype?/posit8-to-posit32"
  (check-true (tc:subtype? (expr-Posit8) (expr-Posit32))))

(test-case "subtype?/posit8-to-posit64"
  (check-true (tc:subtype? (expr-Posit8) (expr-Posit64))))

(test-case "subtype?/posit16-to-posit32"
  (check-true (tc:subtype? (expr-Posit16) (expr-Posit32))))

(test-case "subtype?/posit16-to-posit64"
  (check-true (tc:subtype? (expr-Posit16) (expr-Posit64))))

(test-case "subtype?/posit32-to-posit64"
  (check-true (tc:subtype? (expr-Posit32) (expr-Posit64))))

(test-case "subtype?/cross-family-rejected"
  (check-false (tc:subtype? (expr-Nat) (expr-Posit8)))
  (check-false (tc:subtype? (expr-Int) (expr-Posit32)))
  (check-false (tc:subtype? (expr-Posit8) (expr-Nat))))

(test-case "subtype?/narrowing-rejected"
  (check-false (tc:subtype? (expr-Int) (expr-Nat)))
  (check-false (tc:subtype? (expr-Rat) (expr-Int)))
  (check-false (tc:subtype? (expr-Posit64) (expr-Posit8))))

(test-case "subtype?/reflexive-is-false"
  ;; Reflexive case is handled by unify, not subtype?
  (check-false (tc:subtype? (expr-Int) (expr-Int)))
  (check-false (tc:subtype? (expr-Posit32) (expr-Posit32))))

;; ========================================
;; B. Core check acceptance (AST-level)
;; ========================================

(test-case "check/nat-as-int"
  (check-true
   (parameterize ([current-global-env (hasheq)]
                  [current-mult-meta-store (make-hasheq)])
     (reset-meta-store!)
     (tc:check '() (expr-suc (expr-zero)) (expr-Int)))))

(test-case "check/int-as-rat"
  (check-true
   (parameterize ([current-global-env (hasheq)]
                  [current-mult-meta-store (make-hasheq)])
     (reset-meta-store!)
     (tc:check '() (expr-int 42) (expr-Rat)))))

(test-case "check/nat-as-rat-transitive"
  (check-true
   (parameterize ([current-global-env (hasheq)]
                  [current-mult-meta-store (make-hasheq)])
     (reset-meta-store!)
     (tc:check '() (expr-suc (expr-zero)) (expr-Rat)))))

(test-case "check/posit8-as-posit16"
  (check-true
   (parameterize ([current-global-env (hasheq)]
                  [current-mult-meta-store (make-hasheq)])
     (reset-meta-store!)
     (tc:check '() (expr-posit8 64) (expr-Posit16)))))

(test-case "check/posit8-as-posit32"
  (check-true
   (parameterize ([current-global-env (hasheq)]
                  [current-mult-meta-store (make-hasheq)])
     (reset-meta-store!)
     (tc:check '() (expr-posit8 64) (expr-Posit32)))))

(test-case "check/cross-family-rejected"
  (check-false
   (parameterize ([current-global-env (hasheq)]
                  [current-mult-meta-store (make-hasheq)])
     (reset-meta-store!)
     (tc:check '() (expr-suc (expr-zero)) (expr-Posit8)))))

;; ========================================
;; C. Runtime reduction (whnf coercion)
;; ========================================

(test-case "whnf/nat-in-int-add"
  ;; (int+ (suc zero) (int 3)) → (int 4)
  (define result (whnf (expr-int-add (expr-suc (expr-zero)) (expr-int 3))))
  (check-true (expr-int? result))
  (check-equal? (expr-int-val result) 4))

(test-case "whnf/nat-in-int-neg"
  ;; (int-neg (suc (suc zero))) → (int -2)
  (define result (whnf (expr-int-neg (expr-suc (expr-suc (expr-zero))))))
  (check-true (expr-int? result))
  (check-equal? (expr-int-val result) -2))

(test-case "whnf/int-in-rat-add"
  ;; (rat+ (int 1) (rat 1/2)) → (rat 3/2)
  (define result (whnf (expr-rat-add (expr-int 1) (expr-rat 1/2))))
  (check-true (expr-rat? result))
  (check-equal? (expr-rat-val result) 3/2))

(test-case "whnf/nat-in-rat-mul-transitive"
  ;; (rat* (suc zero) (rat 3/7)) → (rat 3/7)  — Nat→Rat transitive
  (define result (whnf (expr-rat-mul (expr-suc (expr-zero)) (expr-rat 3/7))))
  (check-true (expr-rat? result))
  (check-equal? (expr-rat-val result) 3/7))

(test-case "whnf/nat-in-int-lt-comparison"
  ;; (int-lt (suc zero) (int 5)) → true
  (define result (whnf (expr-int-lt (expr-suc (expr-zero)) (expr-int 5))))
  (check-true (expr-true? result)))

(test-case "whnf/int-in-rat-eq-comparison"
  ;; (rat-eq (int 3) (rat 3)) → true
  (define result (whnf (expr-rat-eq (expr-int 3) (expr-rat 3))))
  (check-true (expr-true? result)))

(test-case "whnf/posit8-in-posit16-add"
  ;; (p16+ (posit8 p8-one) (posit16 p16-one)) → posit16(2.0)
  (define result (whnf (expr-p16-add (expr-posit8 posit8-one) (expr-posit16 posit16-one))))
  (check-true (expr-posit16? result))
  ;; p16(1.0) + p16(1.0) = p16(2.0)
  (check-equal? (expr-posit16-val result) (posit16-add posit16-one posit16-one)))

(test-case "whnf/posit8-in-posit32-mul"
  ;; (p32* (posit8 p8-one) (posit32 p32-one)) → posit32(1.0)
  (define result (whnf (expr-p32-mul (expr-posit8 posit8-one) (expr-posit32 posit32-one))))
  (check-true (expr-posit32? result))
  (check-equal? (expr-posit32-val result) posit32-one))

(test-case "whnf/posit16-in-posit64-add"
  ;; (p64+ (posit16 p16-one) (posit64 p64-one)) → posit64(2.0)
  (define result (whnf (expr-p64-add (expr-posit16 posit16-one) (expr-posit64 posit64-one))))
  (check-true (expr-posit64? result))
  (check-equal? (expr-posit64-val result) (posit64-add posit64-one posit64-one)))

;; ========================================
;; D. Surface syntax E2E tests
;; ========================================

(test-case "e2e/nat-def-as-int"
  ;; (def x <Int> (suc zero)) — Nat accepted where Int expected
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(def x <Int> (suc zero))\n"
    "(eval x)\n")))
  (check-not-false (findf (lambda (s) (string-contains? s "1N : Int")) results)))

(test-case "e2e/nat-in-int-add-surface"
  ;; (eval (int+ (suc zero) (int 3))) → 4 : Int
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(eval (int+ (suc zero) (int 3)))\n")))
  (check-not-false (findf (lambda (s) (string-contains? s "4 : Int")) results)))

(test-case "e2e/int-def-as-rat"
  ;; (def y <Rat> (int 42)) — Int accepted where Rat expected
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(def y <Rat> (int 42))\n"
    "(eval y)\n")))
  (check-not-false (findf (lambda (s) (string-contains? s "42 : Rat")) results)))

(test-case "e2e/nat-def-as-rat-transitive"
  ;; (def z <Rat> (suc zero)) — Nat→Rat transitive
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(def z <Rat> (suc zero))\n"
    "(eval z)\n")))
  (check-not-false (findf (lambda (s) (string-contains? s "1N : Rat")) results)))

(test-case "e2e/check-nat-as-int"
  ;; (check (suc zero) <Int>) → succeeds (outputs "OK")
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(check (suc zero) <Int>)\n")))
  (check-not-false (findf (lambda (s) (or (string-contains? s "✓") (string-contains? s "OK"))) results)))

(test-case "e2e/defn-accepts-nat-for-int-param"
  ;; defn expecting Int arg, called with Nat — use def to bind the nat,
  ;; then pass it to an Int-accepting function via from-nat identity
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "require [prologos::data::nat :refer [add]]\n"
    "(defn nat-to-int [x : Int] <Int>\n"
    "  x)\n"
    "(eval (nat-to-int (suc (suc zero))))\n")))
  (check-not-false (findf (lambda (s) (string-contains? s "2N : Int")) results)))

(test-case "e2e/check-posit8-as-posit16"
  ;; (check (posit8 64) <Posit16>) → succeeds (outputs "OK")
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(check (posit8 64) <Posit16>)\n")))
  (check-not-false (findf (lambda (s) (or (string-contains? s "✓") (string-contains? s "OK"))) results)))

(test-case "e2e/cross-family-rejected"
  ;; (check (suc zero) <Posit8>) → type error
  (define results (run-ns (string-append
    "(ns t)\n"
    "(check (suc zero) <Posit8>)\n")))
  ;; Should NOT have ✓ or OK
  (check-false (findf (lambda (s) (and (string? s) (or (string-contains? s "✓") (string-contains? s "OK")))) results)))

;; ========================================
;; E. Backward compatibility
;; ========================================

(test-case "backward-compat/from-nat-still-works"
  ;; Explicit from-nat converts Nat → Int (unchanged by subtyping)
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(eval (from-nat (suc (suc zero))))\n")))
  (check-not-false (findf (lambda (s) (string-contains? s "2 : Int")) results)))

(test-case "backward-compat/from-int-still-works"
  ;; Explicit from-int converts Int → Rat (unchanged)
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(eval (from-int (int 42)))\n")))
  (check-not-false (findf (lambda (s) (string-contains? s "42 : Rat")) results)))

(test-case "backward-compat/int-add-same-type"
  ;; Same-type operations still work (no regression)
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(eval (int+ (int 3) (int 4)))\n")))
  (check-not-false (findf (lambda (s) (string-contains? s "7 : Int")) results)))

;; ========================================
;; F. posit-widen unit tests
;; ========================================

(test-case "posit-widen/p8-to-p16"
  (check-equal? (posit-widen 8 16 posit8-one) posit16-one))

(test-case "posit-widen/p8-to-p32"
  (check-equal? (posit-widen 8 32 posit8-one) posit32-one))

(test-case "posit-widen/p8-to-p64"
  (check-equal? (posit-widen 8 64 posit8-one) posit64-one))

(test-case "posit-widen/p16-to-p32"
  (check-equal? (posit-widen 16 32 posit16-one) posit32-one))

(test-case "posit-widen/p16-to-p64"
  (check-equal? (posit-widen 16 64 posit16-one) posit64-one))

(test-case "posit-widen/p32-to-p64"
  (check-equal? (posit-widen 32 64 posit32-one) posit64-one))
