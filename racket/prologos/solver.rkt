#lang racket/base

;;;
;;; solver.rkt — Solver Configuration
;;;
;;; A solver configuration is a persistent, Map-backed value that controls
;;; how relational queries are executed. Solver configs are created by the
;;; `solver` top-level form and consumed by `solve`/`explain` at runtime.
;;;
;;; Key concepts:
;;;   - Config is a hasheq of keyword symbols to values
;;;   - Shallow map merge for {override} support
;;;   - Known keys: execution, threshold, strategy, tabling, provenance, timeout
;;;   - All operations are pure (no mutation)
;;;
;;; Design reference: docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org §7.6
;;;

(provide
 ;; Core struct
 (struct-out solver-config)
 ;; Construction
 make-solver-config
 default-solver-config
 ;; Accessors
 solver-config-get
 solver-config-execution
 solver-config-threshold
 solver-config-strategy
 solver-config-tabling
 solver-config-provenance
 solver-config-timeout
 ;; Narrowing search heuristics (Phase 3b)
 solver-config-narrow-value-order
 solver-config-narrow-search
 solver-config-narrow-iterative
 ;; Narrowing constraints (Phase 3c)
 solver-config-narrow-constraints
 solver-config-narrow-minimize
 ;; CFA scope (Phase 3a)
 solver-config-cfa-scope
 ;; Well-founded semantics (WFLE Phase 4a)
 solver-config-semantics
 ;; Derivation depth limit (D4 provenance)
 solver-config-max-derivation-depth
 ;; Merge
 solver-config-merge
 ;; Validation
 valid-solver-key?
 valid-solver-keys)

;; ========================================
;; Core struct
;; ========================================

;; Solver configuration — backed by hasheq (symbol → value)
;; options: hasheq mapping keyword symbols to values
(struct solver-config (options) #:transparent)

;; ========================================
;; Known keys and defaults
;; ========================================

(define valid-solver-keys
  '(execution threshold strategy tabling provenance timeout
    narrow-value-order narrow-search narrow-iterative
    narrow-constraints narrow-minimize cfa-scope
    semantics max-derivation-depth))

(define (valid-solver-key? k)
  (memq k valid-solver-keys))

;; Default values for each key
(define solver-defaults
  (hasheq 'execution  'parallel
          'threshold  4
          'strategy   'auto
          'tabling    'by-default
          'provenance 'none
          'timeout    #f
          'narrow-value-order 'source-order
          'narrow-search      'all
          'narrow-iterative   #f
          'narrow-constraints '()
          'narrow-minimize    #f
          'cfa-scope          'module
          'semantics          'stratified
          'max-derivation-depth 50))

;; ========================================
;; Construction
;; ========================================

;; Create a solver-config from a hasheq of options.
;; Missing keys get defaults from solver-defaults.
(define (make-solver-config [options (hasheq)])
  (solver-config
   (for/fold ([cfg solver-defaults])
             ([(k v) (in-hash options)])
     (hash-set cfg k v))))

;; The built-in default solver configuration.
(define default-solver-config
  (make-solver-config))

;; ========================================
;; Accessors
;; ========================================

;; Get a config value by key, with fallback to default.
(define (solver-config-get cfg key [default #f])
  (hash-ref (solver-config-options cfg) key default))

(define (solver-config-execution cfg)
  (solver-config-get cfg 'execution 'parallel))

(define (solver-config-threshold cfg)
  (solver-config-get cfg 'threshold 4))

(define (solver-config-strategy cfg)
  (solver-config-get cfg 'strategy 'auto))

(define (solver-config-tabling cfg)
  (solver-config-get cfg 'tabling 'by-default))

(define (solver-config-provenance cfg)
  (solver-config-get cfg 'provenance 'none))

(define (solver-config-timeout cfg)
  (solver-config-get cfg 'timeout #f))

;; Narrowing search heuristics (Phase 3b)
(define (solver-config-narrow-value-order cfg)
  (solver-config-get cfg 'narrow-value-order 'source-order))

(define (solver-config-narrow-search cfg)
  (solver-config-get cfg 'narrow-search 'all))

(define (solver-config-narrow-iterative cfg)
  (solver-config-get cfg 'narrow-iterative #f))

;; Narrowing constraints (Phase 3c)
(define (solver-config-narrow-constraints cfg)
  (solver-config-get cfg 'narrow-constraints '()))

(define (solver-config-narrow-minimize cfg)
  (solver-config-get cfg 'narrow-minimize #f))

;; CFA scope (Phase 3a)
(define (solver-config-cfa-scope cfg)
  (solver-config-get cfg 'cfa-scope 'module))

;; Well-founded semantics (WFLE Phase 4a)
(define (solver-config-semantics cfg)
  (solver-config-get cfg 'semantics 'stratified))

(define (solver-config-max-derivation-depth cfg)
  (solver-config-get cfg 'max-derivation-depth 50))

;; ========================================
;; Merge
;; ========================================

;; Shallow merge: each key in overrides replaces the same key in base.
;; overrides: hasheq (same format as solver-config options)
;; Returns a new solver-config.
(define (solver-config-merge base overrides)
  (solver-config
   (for/fold ([cfg (solver-config-options base)])
             ([(k v) (in-hash overrides)])
     (hash-set cfg k v))))
