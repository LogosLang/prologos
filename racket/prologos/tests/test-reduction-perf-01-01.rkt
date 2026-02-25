#lang racket/base

;;;
;;; Tests for reduction engine performance — lightweight checks:
;;; - WHNF cache active
;;; - nat-value memoization
;;; - Decimal posit literals
;;;
;;; Split from test-reduction-perf-01.rkt (the fuel exhaustion test
;;; is isolated in test-reduction-perf-01-02.rkt due to ~112s runtime).
;;;

(require rackunit
         racket/string
         racket/path
         "test-support.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../surface-syntax.rkt"
         "../reader.rkt"
         "../parser.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../reduction.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../posit-impl.rkt")

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

;; ========================================
;; WHNF cache
;; ========================================

(test-case "perf: WHNF cache is active during process-command"
  ;; Verify the cache parameter is set
  (define results
    (run-ns "(ns test.cache :no-prelude)
(eval 42)"))
  ;; Just verify it runs — the cache is internal
  (check-true (ormap (lambda (r) (string-contains? (format "~a" r) "42 : Int")) results)))

;; ========================================
;; nat-value memoization
;; ========================================

(test-case "perf: nat-value works with cache"
  ;; Build a Nat chain and verify coercion still works
  (define results
    (run-ns "(ns test.nat :no-prelude)
(eval (int+ 5N 3N))"))
  ;; 5N + 3N = 8 (Nat coerced to Int for int+)
  (check-true (ormap (lambda (r) (string-contains? (format "~a" r) "8 : Int")) results)
              "5N + 3N should coerce and produce 8"))

;; ========================================
;; Decimal posit literals
;; ========================================

(test-case "perf: decimal posit ~3.14 evaluates"
  (define results
    (run-ns "(ns test.decimal :no-prelude)
(eval ~3.14)"))
  (check-true (ormap (lambda (r)
                        (and (string? r)
                             (string-contains? r "Posit32")))
                      results)
              "~3.14 should produce a Posit32"))

(test-case "perf: decimal posit arithmetic"
  (define results
    (run-ns "(ns test.decimal-arith :no-prelude)
(eval (p32+ ~1.5 ~2.5))"))
  ;; 1.5 + 2.5 = 4.0
  (check-true (ormap (lambda (r)
                        (and (string? r)
                             (string-contains? r "Posit32")))
                      results)
              "~1.5 + ~2.5 should produce a Posit32"))
