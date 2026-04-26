#lang racket/base

;;;
;;; E2E Tests for Phase 2c: Pipe (|>) Operator — Sexp Mode
;;;
;;; Split from original test-pipe-compose-e2e-01.rkt:
;;; - THIS FILE: Pipe E2E tests (sexp mode) — 5 tests
;;; - test-pipe-compose-e2e-02.rkt: WS mode E2E tests (separate)
;;; - test-pipe-compose-e2e-03.rkt: Compose E2E tests (sexp mode)
;;;
;;; The shared fixture loads modules once at file level, avoiding
;;; the quadratic module reloading that caused >60 min runtimes.
;;; See docs/tracking/2026-02-19_PIPE_COMPOSE_AUDIT.md
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/port
         racket/file
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
         "../parse-reader.rkt")

;; ========================================
;; Shared Fixture: Load modules ONCE
;; ========================================
;;
;; Instead of each E2E test creating a fresh environment and reloading
;; all modules from scratch, we load them once here and reuse.

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Preamble strings for module loading
(define (pipe-preamble-sexp)
  (string-append
   "(ns test-pipe-e2e)\n"
   "(imports [prologos::data::list :refer [List nil cons map filter reduce sum length reverse]])\n"
   "(imports [prologos::data::nat :refer [add]])\n"
   "(imports [prologos::data::transducer :refer [map-xf filter-xf remove-xf xf-compose transduce xf-into-list-rev xf-into-list list-conj]])\n"))

(define (pipe-helpers-sexp)
  (string-append
   "(def suc-fn : [-> Nat Nat] (fn (x : Nat) (suc x)))\n"
   "(def positive? : [-> Nat Bool] (fn (x : Nat) (match x (zero -> false) (suc _ -> true))))\n"
   "(def sum-rf : [-> Nat [-> Nat Nat]] (fn (acc : Nat) (fn (x : Nat) (add acc x))))\n"
   ;; NOTE: Must use explicit suc chains, NOT Racket numeric literals.
   ;; Numeric literals (1, 2, 3) are not valid Nat values in sexp mode —
   ;; they cause silent type-check failures leaving value=#f in global env.
   "(def nums3 : [List Nat] (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))\n"
   "(def nums5 : [List Nat] (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat)))))))\n"))

;; Load modules and helpers once, capture all registries
(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string (pipe-preamble-sexp))
    ;; Check for silent failures in helper definitions
    (let ([results (process-string (pipe-helpers-sexp))])
      (for ([r (in-list results)])
        (when (prologos-error? r)
          (error 'fixture "Helper definition failed: ~a" (prologos-error-message r)))))
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Run sexp code using shared environment (no module reload)
(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-bundle-registry shared-bundle-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; ========================================
;; C. Pipe E2E — Sexp Mode (5 tests)
;; ========================================

(test-case "e2e/pipe-basic: zero |> suc → 1"
  (check-equal? (run-last "(eval ($pipe-gt zero suc))") "1N : Nat"))

(test-case "e2e/pipe-chain: zero |> suc |> suc → 2"
  (check-equal? (run-last "(eval ($pipe-gt zero suc suc))") "2N : Nat"))

(test-case "e2e/pipe-chain-3: zero |> suc |> suc |> suc → 3"
  (check-equal? (run-last "(eval ($pipe-gt zero suc suc suc))") "3N : Nat"))

(test-case "e2e/pipe-4-deep: zero |> suc |> suc |> suc |> suc → 4"
  (check-equal? (run-last "(eval ($pipe-gt zero suc suc suc suc))") "4N : Nat"))

(test-case "e2e/pipe-preserves-type: zero |> suc preserves types"
  (check-equal? (run-last "(eval ($pipe-gt zero suc))") "1N : Nat"))
