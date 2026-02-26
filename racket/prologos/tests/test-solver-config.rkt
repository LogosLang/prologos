#lang racket/base

;;;
;;; Tests for solver.rkt — Solver Configuration
;;; Phase 7a: construction, accessors, merge, validation
;;;

(require rackunit
         "../solver.rkt")

;; ========================================
;; Construction
;; ========================================

(test-case "make-solver-config: creates config with defaults"
  (define cfg (make-solver-config))
  (check-true (solver-config? cfg))
  (check-equal? (solver-config-execution cfg) 'parallel)
  (check-equal? (solver-config-threshold cfg) 4)
  (check-equal? (solver-config-strategy cfg) 'auto)
  (check-equal? (solver-config-tabling cfg) 'by-default)
  (check-equal? (solver-config-provenance cfg) 'none)
  (check-equal? (solver-config-timeout cfg) #f))

(test-case "make-solver-config: custom options override defaults"
  (define cfg (make-solver-config
               (hasheq 'execution 'sequential
                       'timeout 5000)))
  (check-equal? (solver-config-execution cfg) 'sequential)
  (check-equal? (solver-config-timeout cfg) 5000)
  ;; Non-overridden keys retain defaults
  (check-equal? (solver-config-threshold cfg) 4)
  (check-equal? (solver-config-strategy cfg) 'auto))

(test-case "default-solver-config: is valid"
  (check-true (solver-config? default-solver-config))
  (check-equal? (solver-config-execution default-solver-config) 'parallel))

;; ========================================
;; Accessors
;; ========================================

(test-case "solver-config-get: returns value for known key"
  (define cfg (make-solver-config (hasheq 'provenance 'full)))
  (check-equal? (solver-config-get cfg 'provenance) 'full))

(test-case "solver-config-get: returns default for missing key"
  (define cfg (make-solver-config))
  (check-equal? (solver-config-get cfg 'unknown 'fallback) 'fallback))

(test-case "solver-config-provenance: all valid values"
  (for ([prov '(none summary full atms)])
    (define cfg (make-solver-config (hasheq 'provenance prov)))
    (check-equal? (solver-config-provenance cfg) prov)))

(test-case "solver-config-strategy: all valid values"
  (for ([strat '(auto depth-first atms)])
    (define cfg (make-solver-config (hasheq 'strategy strat)))
    (check-equal? (solver-config-strategy cfg) strat)))

;; ========================================
;; Merge
;; ========================================

(test-case "solver-config-merge: shallow merge overrides keys"
  (define base (make-solver-config))
  (define merged (solver-config-merge base (hasheq 'timeout 5000
                                                    'execution 'sequential)))
  (check-equal? (solver-config-timeout merged) 5000)
  (check-equal? (solver-config-execution merged) 'sequential)
  ;; Non-overridden keys retained
  (check-equal? (solver-config-strategy merged) 'auto)
  (check-equal? (solver-config-threshold merged) 4))

(test-case "solver-config-merge: empty overrides = identity"
  (define base (make-solver-config (hasheq 'timeout 1000)))
  (define merged (solver-config-merge base (hasheq)))
  (check-equal? (solver-config-timeout merged) 1000))

(test-case "solver-config-merge: does not mutate base"
  (define base (make-solver-config))
  (define _merged (solver-config-merge base (hasheq 'timeout 5000)))
  ;; Base is unchanged (persistent)
  (check-equal? (solver-config-timeout base) #f))

(test-case "solver-config-merge: multiple keys overridden"
  (define base (make-solver-config))
  (define merged (solver-config-merge base
                   (hasheq 'execution 'sequential
                           'strategy 'depth-first
                           'provenance 'full
                           'timeout 10000)))
  (check-equal? (solver-config-execution merged) 'sequential)
  (check-equal? (solver-config-strategy merged) 'depth-first)
  (check-equal? (solver-config-provenance merged) 'full)
  (check-equal? (solver-config-timeout merged) 10000))

;; ========================================
;; Validation
;; ========================================

(test-case "valid-solver-key?: recognizes all valid keys"
  (for ([k valid-solver-keys])
    (check-not-false (valid-solver-key? k))))

(test-case "valid-solver-key?: rejects unknown keys"
  (check-false (valid-solver-key? 'foo))
  (check-false (valid-solver-key? 'bar))
  (check-false (valid-solver-key? 'execute)))  ;; close but not exact
