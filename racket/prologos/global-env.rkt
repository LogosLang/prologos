#lang racket/base

;;;
;;; PROLOGOS GLOBAL ENVIRONMENT
;;; Thread-local parameter holding top-level definitions.
;;; Used by the type checker and reducer to resolve expr-fvar references.
;;;
;;; Each entry maps a symbol name to (cons type value).
;;;

(provide current-global-env
         global-env-lookup-type
         global-env-lookup-value
         global-env-add
         global-env-add-type-only
         global-env-names
         global-env-import-module
         global-env-snapshot
         ;; Defn param-name registry (user-facing names for bound-arg display)
         current-defn-param-names
         register-defn-param-names!
         lookup-defn-param-names)

;; The global environment: name -> (cons type value)
(define current-global-env (make-parameter (hasheq)))

;; Lookup the type of a global definition
(define (global-env-lookup-type name)
  (let ([entry (hash-ref (current-global-env) name #f)])
    (and entry (car entry))))

;; Lookup the value of a global definition
(define (global-env-lookup-value name)
  (let ([entry (hash-ref (current-global-env) name #f)])
    (and entry (cdr entry))))

;; Add a definition to the global environment (returns new env)
(define (global-env-add env name type value)
  (hash-set env name (cons type value)))

;; Pre-register only the type (value = #f) for recursive definitions.
;; whnf treats #f as stuck (no unfolding), so self-references are opaque
;; during type checking. After checking, call global-env-add with real value.
(define (global-env-add-type-only env name type)
  (hash-set env name (cons type #f)))

;; List all definition names
(define (global-env-names)
  (hash-keys (current-global-env)))

;; Import a module's exported definitions into a global env.
;; Takes a qualify-fn that maps (short-name, namespace-sym) → fqn-symbol.
;; The module-exports is a list of short-name symbols.
;; The module-env is a hasheq of fqn → (cons type value).
(define (global-env-import-module env module-exports module-env qualify-fn module-ns)
  (for/fold ([e env])
            ([short-name (in-list module-exports)])
    (define fqn (qualify-fn short-name module-ns))
    (define entry (hash-ref module-env fqn #f))
    (if entry (hash-set e fqn entry) e)))

;; Snapshot the current global env (returns the raw hasheq)
(define (global-env-snapshot)
  (current-global-env))

;; ========================================
;; Defn param-name registry
;; ========================================
;; Maps function name (symbol) to user-facing parameter names (listof symbol).
;; Populated during defn processing in macros.rkt.
;; Used by compute-bound-args in reduction.rkt to produce readable
;; bound-variable output (e.g., :y_ 3N) instead of internal lambda names.

(define current-defn-param-names (make-parameter (hasheq)))

(define (register-defn-param-names! name param-names)
  (current-defn-param-names
   (hash-set (current-defn-param-names) name param-names)))

(define (lookup-defn-param-names name)
  (hash-ref (current-defn-param-names) name #f))
