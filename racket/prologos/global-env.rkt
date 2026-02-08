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
         global-env-names)

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

;; List all definition names
(define (global-env-names)
  (hash-keys (current-global-env)))
