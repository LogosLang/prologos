#lang racket/base

;; ========================================================================
;; Flat Subtype Predicate
;; ========================================================================
;;
;; Extracted from typing-core.rkt to break circular dependency:
;; typing-core.rkt → unify.rkt (for unification)
;; unify.rkt needs subtype? for SRE subtype-lattice-merge
;;
;; This module depends only on syntax.rkt (struct predicates) and
;; macros.rkt (subtype-pair? registry). No dependency on unify.rkt
;; or typing-core.rkt.
;;
;; SRE Track 1: enables subtype-merge as a proper lattice function
;; on sre-domain, keeping subtyping fully on-network.

(require racket/match
         "syntax.rkt"
         "macros.rkt"          ;; subtype-pair?
         "type-lattice.rkt")   ;; type-top

(provide subtype?
         type-key
         subtype-lattice-merge)

;; Extract a canonical symbol key from a type expression.
;; Built-in types → short name; user-defined types → qualified fvar name.
(define (type-key t)
  (match t
    [(expr-Nat) 'Nat] [(expr-Int) 'Int] [(expr-Rat) 'Rat]
    [(expr-Posit8) 'Posit8] [(expr-Posit16) 'Posit16]
    [(expr-Posit32) 'Posit32] [(expr-Posit64) 'Posit64]
    [(expr-fvar name) name]
    [_ #f]))

;; Within-family subtype predicate (Phase 3e + Phase E)
;; Automatic widening within two type families:
;;   Exact:  Nat <: Int <: Rat
;;   Posit:  Posit8 <: Posit16 <: Posit32 <: Posit64
;; Hardcoded 9 edges for built-in types, then registry fallback for
;; library-defined subtypes (PosInt <: Int, NegRat <: Rat, etc.).
(define (subtype? t1 t2)
  (match* (t1 t2)
    ;; Exact: Nat <: Int <: Rat
    [((expr-Nat) (expr-Int)) #t]
    [((expr-Nat) (expr-Rat)) #t]
    [((expr-Int) (expr-Rat)) #t]
    ;; Posit: 8 <: 16 <: 32 <: 64
    [((expr-Posit8)  (expr-Posit16)) #t]
    [((expr-Posit8)  (expr-Posit32)) #t]
    [((expr-Posit8)  (expr-Posit64)) #t]
    [((expr-Posit16) (expr-Posit32)) #t]
    [((expr-Posit16) (expr-Posit64)) #t]
    [((expr-Posit32) (expr-Posit64)) #t]
    ;; Registry fallback for library-defined subtypes (Phase E)
    [(_ _)
     (let ([k1 (type-key t1)] [k2 (type-key t2)])
       (and k1 k2 (subtype-pair? k1 k2)))]))

;; SRE Track 1: Subtype-ordering lattice merge.
;; Returns the join in the subtype ordering:
;;   subtype-merge(a, b) = b if a <: b
;;   subtype-merge(a, b) = a if b <: a
;;   subtype-merge(a, b) = a if a = b
;;   subtype-merge(a, b) = type-top if incomparable
;; This is a proper lattice merge (monotone, commutative, associative,
;; idempotent). Used by the SRE subtype propagator to keep subtyping
;; fully on-network — no off-network flat-subtype? escape hatch.
(define (subtype-lattice-merge a b)
  (cond
    [(equal? a b) a]
    [(subtype? a b) b]
    [(subtype? b a) a]
    [else type-top]))
