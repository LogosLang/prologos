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
         racket/list
         "syntax.rkt"
         "macros.rkt"          ;; subtype-pair?
         "type-lattice.rkt"    ;; type-top, type-bot, type-lattice-merge, etc.
         "propagator.rkt"      ;; SRE Track 1 Phase 4: mini-network for compound checks
         "sre-core.rkt"        ;; SRE Track 1 Phase 4: structural subtype check
         (only-in "ctor-registry.rkt"
                  ctor-tag-for-value
                  lookup-ctor-desc
                  ctor-desc-extract-fn
                  ctor-desc-component-variances
                  ctor-desc-arity))

(provide subtype?
         type-key
         subtype-lattice-merge
         ;; SRE Track 1 Phase 4: frequency counter for monitoring
         current-subtype-check-count
         ;; Track 1B Phase 1: global counters + reporter
         report-subtype-frequency!)

;; Extract a canonical symbol key from a type expression.
;; Built-in types → short name; user-defined types → qualified fvar name.
(define (type-key t)
  (match t
    [(expr-Nat) 'Nat] [(expr-Int) 'Int] [(expr-Rat) 'Rat]
    [(expr-Posit8) 'Posit8] [(expr-Posit16) 'Posit16]
    [(expr-Posit32) 'Posit32] [(expr-Posit64) 'Posit64]
    [(expr-fvar name) name]
    [_ #f]))

;; SRE Track 1 Phase 4: Frequency counter for monitoring subtype? usage.
;; Tracks total calls and compound calls (which create mini-networks).
;; Use: (current-subtype-check-count) → (cons total compound)
;; Default #f = disabled (avoids cons allocation per subtype? call).
;; Set to (cons 0 0) in benchmark/debug contexts to enable counting.
(define current-subtype-check-count (make-parameter #f))

;; Track 1B Phase 1: Global counters survive across parameterize blocks.
;; For suite-wide measurement without per-command reset.
(define global-subtype-total (box 0))
(define global-subtype-compound (box 0))

;; PM 8F cleanup: gate behind #f default to avoid cons allocation on every subtype? call.
;; Set to (cons 0 0) in benchmark contexts to enable counting.
(define (bump-subtype-count! #:compound? [compound? #f])
  (define counts (current-subtype-check-count))
  (when (pair? counts)  ;; only count when enabled (default #f = disabled)
    (current-subtype-check-count
     (cons (add1 (car counts))
           (if compound? (add1 (cdr counts)) (cdr counts))))
    ;; Also bump globals
    (set-box! global-subtype-total (add1 (unbox global-subtype-total)))
    (when compound?
      (set-box! global-subtype-compound (add1 (unbox global-subtype-compound))))))

(define (report-subtype-frequency!)
  (fprintf (current-error-port)
           "SUBTYPE-FREQUENCY: total=~a compound=~a ratio=~a%\n"
           (unbox global-subtype-total)
           (unbox global-subtype-compound)
           (if (zero? (unbox global-subtype-total))
               0
               (exact->inexact (* 100 (/ (unbox global-subtype-compound)
                                          (unbox global-subtype-total)))))))

;; Within-family subtype predicate (Phase 3e + Phase E)
;; Automatic widening within two type families:
;;   Exact:  Nat <: Int <: Rat
;;   Posit:  Posit8 <: Posit16 <: Posit32 <: Posit64
;; Hardcoded 9 edges for built-in types, then registry fallback for
;; library-defined subtypes (PosInt <: Int, NegRat <: Rat, etc.).
;;
;; SRE Track 1 Phase 4: compound types delegate to SRE structural check.
;; Both sides must have the same constructor tag for structural subtyping.
;; e.g., PVec Nat <: PVec Int (covariant element type).
;; Track 1B Phase 2c: quick compound-type check.
;; Avoids 1.85μs overhead of sre-constructor-tag call on atoms.
;; Struct predicate checks are ~0.01μs — effectively free.
(define (compound-type? v)
  (or (expr-Pi? v) (expr-Sigma? v) (expr-app? v)
      (expr-PVec? v) (expr-Set? v) (expr-Map? v)
      (expr-Vec? v) (expr-Eq? v)
      (expr-pair? v) (expr-lam? v)
      (expr-Fin? v) (expr-suc? v)))

(define (subtype? t1 t2)
  (bump-subtype-count!)
  (cond
    ;; Equal types: trivially a subtype
    [(equal? t1 t2) #t]
    ;; Flat fast path: 9 hardcoded edges + registry
    [(flat-subtype? t1 t2) #t]
    ;; SRE structural path: only if BOTH are compound types.
    ;; Atoms (expr-Nat, expr-Int, expr-Bool, etc.) skip the structural
    ;; path entirely — eliminates 1.85μs overhead from sre-constructor-tag.
    [(and (compound-type? t1) (compound-type? t2)
          (sre-structural-subtype-check t1 t2)) #t]
    ;; Not a subtype
    [else #f]))

;; Flat subtype check: the original 9 edges + registry (fast path, no cells)
(define (flat-subtype? t1 t2)
  (match* (t1 t2)
    [((expr-Nat) (expr-Int)) #t]
    [((expr-Nat) (expr-Rat)) #t]
    [((expr-Int) (expr-Rat)) #t]
    [((expr-Posit8)  (expr-Posit16)) #t]
    [((expr-Posit8)  (expr-Posit32)) #t]
    [((expr-Posit8)  (expr-Posit64)) #t]
    [((expr-Posit16) (expr-Posit32)) #t]
    [((expr-Posit16) (expr-Posit64)) #t]
    [((expr-Posit32) (expr-Posit64)) #t]
    [(_ _)
     (let ([k1 (type-key t1)] [k2 (type-key t2)])
       (and k1 k2 (subtype-pair? k1 k2)))]))

;; SRE Track 1B Phase 2d: Direct recursive structural subtype check.
;; Replaces the mini-network query pattern for GROUND types (both values
;; fully known, no metas). Zero allocations, O(structure depth).
;;
;; Uses the SRE's data structures (ctor-desc, variance, merge-registry)
;; but not the propagator machinery. Ground-type subtyping is a pure
;; function — propagation adds no information.
;;
;; The mini-network path is preserved in sre-structural-subtype-check/network
;; for Track 2 (partial information with metas).
;;
;; NOTE: type-sre-domain-for-subtype is defined AFTER subtype-lattice-merge
;; (below) because it references it.

(define (sre-structural-subtype-check t1 t2)
  (bump-subtype-count! #:compound? #t)
  (structural-subtype-ground? type-sre-domain-for-subtype t1 t2))

;; Direct recursive ground-type structural subtype check.
;; Walks the type structure, checks variance at each level, verifies
;; leaves via the domain's subtype merge.
(define (structural-subtype-ground? domain t1 t2)
  (cond
    [(equal? t1 t2) #t]
    [else
     (define tag1 (sre-constructor-tag domain t1))
     (define tag2 (sre-constructor-tag domain t2))
     (cond
       ;; Both compound, same tag → check components with variance
       [(and tag1 tag2 (eq? tag1 tag2))
        (define desc (lookup-ctor-desc tag1 #:domain (sre-domain-name domain)))
        (and desc
             (let ([comps1 ((ctor-desc-extract-fn desc) t1)]
                   [comps2 ((ctor-desc-extract-fn desc) t2)]
                   [variances (or (ctor-desc-component-variances desc)
                                  (make-list (ctor-desc-arity desc) '=))])
               (for/and ([c1 (in-list comps1)]
                         [c2 (in-list comps2)]
                         [v (in-list variances)])
                 (case v
                   [(+) (structural-subtype-ground? domain c1 c2)]
                   [(-) (structural-subtype-ground? domain c2 c1)]
                   [(=) (equal? c1 c2)]
                   [(ø) #t]))))]
       ;; Different compound tags → not subtypes
       [(and tag1 tag2) #f]
       ;; At least one atomic → use subtype merge from domain registry
       [else
        (define merge (sre-domain-merge domain sre-subtype))
        (define merged (merge t1 t2))
        (and (not ((sre-domain-contradicts? domain) merged))
             (equal? merged t2))])]))

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

;; Domain spec for structural subtype queries (used by sre-structural-subtype-check above).
;; Defined after subtype-lattice-merge since it references it.
;; Track 2F Phase 6: merge registry as data (hash).
(define subtype-query-merge-table
  (hasheq 'equality type-lattice-merge
          'subtype  subtype-lattice-merge
          'subtype-reverse subtype-lattice-merge))
(define (subtype-query-merge-registry rel-name)
  (hash-ref subtype-query-merge-table rel-name
            (λ () (error 'subtype-query-merge "no merge for: ~a" rel-name))))

(define type-sre-domain-for-subtype
  (sre-domain 'type
              subtype-query-merge-registry  ;; merge-registry
              type-lattice-contradicts?
              type-bot?
              type-bot
              type-top   ;; top-value
              #f #f      ;; no meta-recognizer/resolver (ground types only)
              #f         ;; no dual-pairs
              (hasheq))) ;; Track 2G: property-cell-ids
