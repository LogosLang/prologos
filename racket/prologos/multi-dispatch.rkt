#lang racket/base

;;;
;;; PROLOGOS MULTI-DISPATCH REGISTRY
;;; Maps base function names to their arity-dispatched internal definitions.
;;; Used by the elaborator to resolve multi-body defn calls at compile time.
;;;

(provide
 (struct-out multi-defn-info)
 current-multi-defn-registry
 register-multi-defn!
 lookup-multi-defn
 resolve-multi-defn)

;; Multi-body function metadata
;; name: base symbol (e.g., 'clamp)
;; arities: sorted list of valid arity counts (e.g., '(2 3))
;; arity-map: hasheq from arity (int) -> internal symbol (e.g., {2 -> 'clamp/2})
;; docstring: (or/c string? #f)
(struct multi-defn-info (name arities arity-map docstring) #:transparent)

;; Thread-local registry: symbol -> multi-defn-info
(define current-multi-defn-registry (make-parameter (hasheq)))

;; Register a multi-body function in the registry.
(define (register-multi-defn! name arities arity-map docstring)
  (current-multi-defn-registry
   (hash-set (current-multi-defn-registry)
             name
             (multi-defn-info name (sort arities <) arity-map docstring))))

;; Look up a multi-body function by base name.
;; Returns multi-defn-info or #f.
(define (lookup-multi-defn name)
  (hash-ref (current-multi-defn-registry) name #f))

;; Resolve a multi-body function call to the internal clause name.
;; Returns the internal symbol (e.g., 'clamp/2) or #f if no clause matches.
(define (resolve-multi-defn name n-args)
  (define info (lookup-multi-defn name))
  (and info
       (hash-ref (multi-defn-info-arity-map info) n-args #f)))
