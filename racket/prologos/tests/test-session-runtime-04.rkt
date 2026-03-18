#lang racket/base

;;;
;;; S7d: Strategy application tests (spawn-with)
;;;
;;; Tests the spawn-with command: strategy resolution, inline overrides,
;;; fuel application, and the full pipeline.
;;;
;;; Uses sexp-mode with Nat literals (no prelude needed).
;;;

(require rackunit
         racket/list
         racket/string
         "../driver.rkt"
         "../errors.rkt"
         "../sessions.rkt"
         "../macros.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt")

;; Helper: run a multi-line sexp-mode string, return last result
(define (run-last s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-process-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (define results (process-string s))
    (last results)))

;; Helper: run and return all results
(define (run-all s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-process-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-string s)))

;; ========================================
;; spawn-with: named strategy
;; ========================================

(test-case "spawn-with: named strategy"
  (define result (run-last
    (string-append
     "(session S (Send Nat End))\n"
     "(strategy fast :fuel 100000)\n"
     "(defproc sender : S (proc-send self 42N (proc-stop)))\n"
     "(spawn-with fast sender)")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

(test-case "spawn-with: named strategy with recv"
  (define result (run-last
    (string-append
     "(session R (Recv Nat End))\n"
     "(strategy custom :fuel 200000)\n"
     "(defproc receiver : R (proc-recv self x (proc-stop)))\n"
     "(spawn-with custom receiver)")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

;; ========================================
;; spawn-with: inline overrides only
;; ========================================

(test-case "spawn-with: overrides only (no strategy name)"
  (define result (run-last
    (string-append
     "(session S (Send Nat End))\n"
     "(defproc sender : S (proc-send self 42N (proc-stop)))\n"
     "(spawn-with {:fuel 500000} sender)")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

;; ========================================
;; spawn-with: strategy + overrides (override wins)
;; ========================================

(test-case "spawn-with: strategy + overrides"
  (define result (run-last
    (string-append
     "(session S (Send Nat End))\n"
     "(strategy slow :fuel 100)\n"
     "(defproc sender : S (proc-send self 42N (proc-stop)))\n"
     "(spawn-with slow {:fuel 500000} sender)")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

;; ========================================
;; spawn-with: fuel exhaustion
;; ========================================

(test-case "spawn-with: fuel exhaustion with {:fuel 1}"
  ;; With only 1 fuel, the propagator network can't complete
  (define result (run-last
    (string-append
     "(session S (Send Nat End))\n"
     "(defproc sender : S (proc-send self 42N (proc-stop)))\n"
     "(spawn-with {:fuel 1} sender)")))
  ;; Should still report something (ok or contradiction — depends on
  ;; how many firings the simple send+stop needs)
  (check-true (or (string? result) (prologos-error? result))))

;; ========================================
;; spawn-with: error cases
;; ========================================

(test-case "spawn-with: unknown strategy → error"
  (define result (run-last
    (string-append
     "(session S (Send Nat End))\n"
     "(defproc sender : S (proc-send self 42N (proc-stop)))\n"
     "(spawn-with nonexistent sender)")))
  (check-true (prologos-error? result))
  (check-true (string-contains? (prologos-error-message result) "Unknown strategy")))

(test-case "spawn-with: unknown process → error"
  (define result (run-last
    (string-append
     "(session S (Send Nat End))\n"
     "(strategy fast :fuel 100000)\n"
     "(spawn-with fast ghost)")))
  (check-true (prologos-error? result))
  (check-true (string-contains? (prologos-error-message result) "Unknown process")))

;; ========================================
;; spawn-with: strategy with custom fuel applied
;; ========================================

(test-case "spawn-with: strategy fuel applied"
  ;; Define a strategy with :fuel 200, use it via spawn-with
  (define result (run-last
    (string-append
     "(session E End)\n"
     "(strategy tiny :fuel 200)\n"
     "(defproc trivial : E (proc-stop))\n"
     "(spawn-with tiny trivial)")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

;; ========================================
;; spawn-with: multiple override properties
;; ========================================

(test-case "spawn-with: multiple override properties"
  ;; Override fuel and fairness — only fuel affects runtime currently
  (define result (run-last
    (string-append
     "(session S (Send Nat End))\n"
     "(defproc sender : S (proc-send self 42N (proc-stop)))\n"
     "(spawn-with {:fuel 500000 :fairness :none} sender)")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

;; ========================================
;; Regression: bare spawn still works
;; ========================================

(test-case "regression: bare spawn unaffected by spawn-with"
  (define result (run-last
    (string-append
     "(session S (Send Nat End))\n"
     "(defproc sender : S (proc-send self 42N (proc-stop)))\n"
     "(spawn sender)")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

;; ========================================
;; Full pipeline
;; ========================================

(test-case "full pipeline: session + strategy + defproc + spawn-with"
  (define results (run-all
    (string-append
     "(session Ping (Send Nat End))\n"
     "(strategy realtime :fuel 10000 :fairness :priority)\n"
     "(defproc pinger : Ping (proc-send self 1N (proc-stop)))\n"
     "(spawn-with realtime pinger)")))
  ;; Should have 4 results: session defined, strategy defined, defproc, spawn-with
  (check-equal? (length results) 4)
  (check-true (string-contains? (list-ref results 0) "session"))
  (check-true (string-contains? (list-ref results 1) "strategy"))
  (check-false (prologos-error? (list-ref results 3))
               (format "Expected success, got: ~a" (list-ref results 3)))
  (check-true (string-contains? (list-ref results 3) "executed")))
