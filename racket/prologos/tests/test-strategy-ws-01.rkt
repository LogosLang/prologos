#lang racket/base

;;;
;;; WS-4: Strategy WS integration tests
;;; Validates the full path: WS reader → preparse → parser → elaborator
;;; for strategy declarations written in .prologos WS syntax.
;;;

(require rackunit
         racket/list
         "../driver.rkt"
         "../errors.rkt"
         "../macros.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt")

;; Helper: run WS-mode string through the full pipeline, return last result
(define (run-ws s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (define results (process-string-ws s))
    (if (list? results)
        (last results)
        results)))

;; Helper: run and return the strategy-entry from the registry
(define (run-ws-get-strategy s name)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-string-ws s)
    (lookup-strategy name)))

;; ========================================
;; WS-4a: Basic strategy declarations
;; ========================================

(test-case "ws-strategy: bare default"
  (check-equal? (run-ws "strategy default\n")
                "strategy default defined."))

(test-case "ws-strategy: with properties"
  (check-equal? (run-ws "strategy realtime\n  :fairness :priority\n  :fuel 10000\n")
                "strategy realtime defined."))

(test-case "ws-strategy: all properties"
  (check-equal? (run-ws
    "strategy batch\n  :fairness :round-robin\n  :fuel 1000000\n  :scheduler-io :blocking-ok\n  :parallelism :work-stealing\n")
    "strategy batch defined."))

;; ========================================
;; WS-4b: Registry verification
;; ========================================

(test-case "ws-strategy: default registers with correct defaults"
  (define entry (run-ws-get-strategy "strategy defstrat\n" 'defstrat))
  (check-true (strategy-entry? entry))
  (check-equal? (strategy-entry-name entry) 'defstrat)
  (define props (strategy-entry-properties entry))
  (check-equal? (hash-ref props ':fairness) ':round-robin)
  (check-equal? (hash-ref props ':fuel) 50000)
  (check-equal? (hash-ref props ':scheduler-io) ':nonblocking)
  (check-equal? (hash-ref props ':parallelism) ':single-thread))

(test-case "ws-strategy: overrides preserved in registry"
  (define entry (run-ws-get-strategy
    "strategy myplan\n  :fairness :priority\n  :fuel 5000\n"
    'myplan))
  (check-true (strategy-entry? entry))
  (define props (strategy-entry-properties entry))
  (check-equal? (hash-ref props ':fairness) ':priority)
  (check-equal? (hash-ref props ':fuel) 5000)
  ;; Defaults for unset properties
  (check-equal? (hash-ref props ':scheduler-io) ':nonblocking))

;; ========================================
;; WS-4c: Error cases
;; ========================================

(test-case "ws-strategy: invalid property key is error"
  (define result (run-ws "strategy bad\n  :bogus :value\n"))
  (check-true (prologos-error? result)))

(test-case "ws-strategy: invalid property value is error"
  (define result (run-ws "strategy bad\n  :fairness :bogus\n"))
  (check-true (prologos-error? result)))
