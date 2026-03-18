#lang racket/base

;;;
;;; E2E Tests for Phase 2c: Pipe (|>) and Compose (>>) Operators
;;;
;;; Split from test-pipe-compose.rkt for performance:
;;; - test-pipe-compose.rkt: 46 fast unit/preparse tests (<10s)
;;; - THIS FILE: 24 E2E tests with shared fixture (~30-60s)
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
         "../reader.rkt")

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
                 [current-mult-meta-store (make-hasheq)]
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
                 [current-mult-meta-store (make-hasheq)]   ; Fresh per test
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-bundle-registry shared-bundle-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; Run WS code via temp file using shared environment
(define (run-ws s)
  (define tmp (make-temporary-file "prologos-test-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-prelude-env shared-global-env]
                   [current-ns-context shared-ns-context]
                   [current-module-registry shared-module-reg]
                   [current-lib-paths (list lib-dir)]
                   [current-mult-meta-store (make-hasheq)]   ; Fresh per test
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry shared-trait-reg]
                   [current-impl-registry shared-impl-reg]
                   [current-param-impl-registry shared-param-impl-reg]
                   [current-bundle-registry shared-bundle-reg])
      (process-file tmp)))
  (delete-file tmp)
  result)

(define (run-ws-last s) (last (run-ws s)))

(test-case "ws/pipe-basic: zero |> suc"
  (check-equal? (run-ws-last "eval [zero |> suc]") "1N : Nat"))

(test-case "ws/pipe-chain: zero |> suc |> suc"
  (check-equal? (run-ws-last "eval [zero |> suc |> suc]") "2N : Nat"))

(test-case "ws/compose-basic: [suc >> suc] zero"
  (check-equal? (run-ws-last "eval [[suc >> suc] zero]") "2N : Nat"))

(test-case "ws/compose-chain: [suc >> suc >> suc] zero"
  (check-equal? (run-ws-last "eval [[suc >> suc >> suc] zero]") "3N : Nat"))

(test-case "ws/pipe-compose: zero |> [suc >> suc]"
  (check-equal? (run-ws-last "eval [zero |> [suc >> suc]]") "2N : Nat"))

(test-case "ws/pipe-compose-chain: zero |> [suc >> suc >> suc]"
  (check-equal? (run-ws-last "eval [zero |> [suc >> suc >> suc]]") "3N : Nat"))

;; ========================================
;; G. Edge Case — E2E (1 test)
;; ========================================

(test-case "e2e/pipe-with-compose: apply composed fn via pipe"
  (check-equal? (run-last "(eval (($compose suc suc) zero))") "2N : Nat"))

;; ========================================
;; J. Block-Form Pipe: E2E Tests (Sexp Mode)
;; ========================================
;; These tests run full pipelines through the type checker and evaluator.
;; They require the transducer module (pre-loaded via shared fixture).

(test-case "e2e/block-pipe-map-reduce: map + reduce → transduce"
  ;; ($pipe-gt nums3 (map suc-fn) (reduce sum-rf zero))
  ;; [1,2,3] → map suc → [2,3,4] → reduce + 0 → 9
  (define result
    (run-last "(eval ($pipe-gt nums3 (map suc-fn) (reduce sum-rf zero)))"))
  (check-equal? result "9N : Nat"))

(test-case "e2e/block-pipe-filter-reduce: filter + reduce → transduce"
  ;; ($pipe-gt nums5 (filter positive?) (reduce sum-rf zero))
  ;; [0,1,2,3,4] → filter positive? → [1,2,3,4] → sum → 10
  (define result
    (run-last "(eval ($pipe-gt nums5 (filter positive?) (reduce sum-rf zero)))"))
  (check-equal? result "10N : Nat"))

(test-case "e2e/block-pipe-fuse-three: map + filter + map materialized"
  ;; ($pipe-gt nums5 (map suc-fn) (filter positive?) (map suc-fn))
  ;; [0,1,2,3,4] → map suc → [1,2,3,4,5] → filter positive? → [1,2,3,4,5] → map suc → [2,3,4,5,6]
  (define result
    (run-last "(eval ($pipe-gt nums5 (map suc-fn) (filter positive?) (map suc-fn)))"))
  (define r result)
  (check-true (string? r))
  (check-true (string-contains? r "'[2N 3N 4N 5N 6N]")))

(test-case "e2e/block-pipe-no-steps: ($pipe-gt zero) → zero"
  (define result
    (run-last "(eval ($pipe-gt zero))"))
  (check-equal? result "0N : Nat"))

(test-case "e2e/block-pipe-plain-step: ($pipe-gt zero suc suc) → 2"
  ;; Non-fusible bare function steps
  (define result
    (run-last "(eval ($pipe-gt zero suc suc))"))
  (check-equal? result "2N : Nat"))

;; ========================================
;; K. Block-Form Pipe: E2E Tests (WS Mode)
;; ========================================

(define (pipe-preamble-ws)
  (string-append
   "ns test-pipe-ws\n"
   "require [prologos::data::list :refer [List nil cons map filter reduce sum length reverse]]\n"
   "        [prologos::data::nat :refer [add]]\n"
   "        [prologos::data::transducer :refer [map-xf filter-xf remove-xf xf-compose transduce xf-into-list-rev xf-into-list list-conj]]\n"
   "\n"))

(define (pipe-helpers-ws)
  (string-append
   "(def suc-fn : [-> Nat Nat] (fn (x : Nat) (suc x)))\n"
   "(def positive? : [-> Nat Bool] (fn (x : Nat) (match x (zero -> false) (suc _ -> true))))\n"
   "(def sum-rf : [-> Nat [-> Nat Nat]] (fn (acc : Nat) (fn (x : Nat) (add acc x))))\n"
   "(def nums3 : [List Nat] (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))\n"
   "\n"))

(test-case "ws/block-pipe-basic: block form with indented steps"
  (define result
    (run-ws-last
     (string-append
      (pipe-preamble-ws) (pipe-helpers-ws)
      ;; Block form: |> as first token, indented body
      "|> nums3\n"
      "  map suc-fn\n"
      "  reduce sum-rf zero\n")))
  (check-equal? result "9N : Nat"))

(test-case "ws/block-pipe-fuse-materialize: block form materializes"
  (define result
    (run-ws-last
     (string-append
      (pipe-preamble-ws) (pipe-helpers-ws)
      "|> nums3\n"
      "  map suc-fn\n"
      "  filter positive?\n")))
  ;; [1,2,3] → map suc → [2,3,4] → filter positive? → [2,3,4]
  (define r result)
  (check-true (string? r))
  (check-true (string-contains? r "'[2N 3N 4N]")))

(test-case "ws/block-pipe-inline-compat: inline |> still works in WS"
  (define result
    (run-ws-last
     (string-append
      (pipe-preamble-ws)
      "eval [zero |> suc |> suc]\n")))
  (check-equal? result "2N : Nat"))
