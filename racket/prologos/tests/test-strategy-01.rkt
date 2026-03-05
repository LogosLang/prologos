#lang racket/base

;;;
;;; Tests for strategy parsing + registration (Phase S6)
;;; Validates: sexp-mode parsing, property validation, registry,
;;; default properties, and E2E pipeline via process-string.
;;;

(require rackunit
         racket/list
         racket/string
         "../driver.rkt"
         "../errors.rkt"
         "../macros.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt")

;; Helper: run through pipeline, return last result
(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (define results (process-string s))
    (if (list? results)
        (last results)
        results)))

;; Helper: run and return the strategy-entry from the registry
(define (run-get-strategy s name)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-string s)
    (lookup-strategy name)))

;; ========================================
;; Property parsing (unit tests)
;; ========================================

(test-case "parse-strategy-properties: empty → defaults"
  (define-values (props err) (parse-strategy-properties '()))
  (check-false err)
  (check-equal? (hash-ref props ':fairness) ':round-robin)
  (check-equal? (hash-ref props ':fuel) 50000)
  (check-equal? (hash-ref props ':scheduler-io) ':nonblocking)
  (check-equal? (hash-ref props ':parallelism) ':single-thread))

(test-case "parse-strategy-properties: override fairness"
  (define-values (props err) (parse-strategy-properties '(:fairness :priority)))
  (check-false err)
  (check-equal? (hash-ref props ':fairness) ':priority)
  ;; Others retain defaults
  (check-equal? (hash-ref props ':fuel) 50000))

(test-case "parse-strategy-properties: override fuel"
  (define-values (props err) (parse-strategy-properties '(:fuel 10000)))
  (check-false err)
  (check-equal? (hash-ref props ':fuel) 10000))

(test-case "parse-strategy-properties: multiple overrides"
  (define-values (props err)
    (parse-strategy-properties '(:fairness :priority :fuel 10000 :scheduler-io :blocking-ok)))
  (check-false err)
  (check-equal? (hash-ref props ':fairness) ':priority)
  (check-equal? (hash-ref props ':fuel) 10000)
  (check-equal? (hash-ref props ':scheduler-io) ':blocking-ok))

(test-case "parse-strategy-properties: invalid key"
  (define-values (props err)
    (parse-strategy-properties '(:bogus :value)))
  (check-true (string? err))
  (check-true (string-contains? err "unknown property")))

(test-case "parse-strategy-properties: invalid fairness value"
  (define-values (props err)
    (parse-strategy-properties '(:fairness :bogus)))
  (check-true (string? err))
  (check-true (string-contains? err "must be one of")))

(test-case "parse-strategy-properties: fuel must be positive integer"
  (define-values (props err)
    (parse-strategy-properties '(:fuel -1)))
  (check-true (string? err))
  (check-true (string-contains? err "positive integer")))

(test-case "parse-strategy-properties: missing value"
  (define-values (props err)
    (parse-strategy-properties '(:fairness)))
  (check-true (string? err))
  (check-true (string-contains? err "requires a value")))

;; ========================================
;; E2E: strategy through pipeline
;; ========================================

(test-case "e2e: strategy with defaults defines"
  (check-equal? (run "(strategy default)")
                "strategy default defined."))

(test-case "e2e: strategy with properties defines"
  (check-equal? (run "(strategy realtime :fairness :priority :fuel 10000)")
                "strategy realtime defined."))

(test-case "e2e: strategy with all properties"
  (check-equal? (run "(strategy batch :fairness :round-robin :fuel 1000000 :scheduler-io :blocking-ok :parallelism :work-stealing)")
                "strategy batch defined."))

(test-case "e2e: strategy registers in registry"
  (define entry (run-get-strategy "(strategy myplan :fuel 5000)" 'myplan))
  (check-true (strategy-entry? entry))
  (check-equal? (strategy-entry-name entry) 'myplan)
  (define props (strategy-entry-properties entry))
  (check-equal? (hash-ref props ':fuel) 5000)
  ;; Defaults preserved for unset properties
  (check-equal? (hash-ref props ':fairness) ':round-robin))

(test-case "e2e: strategy with invalid property is an error"
  (define result (run "(strategy bad :bogus :value)"))
  (check-true (prologos-error? result)))

(test-case "e2e: strategy with invalid value is an error"
  (define result (run "(strategy bad :fairness :bogus)"))
  (check-true (prologos-error? result)))
