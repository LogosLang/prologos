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
         "type-lattice.rkt"    ;; type-top, type-bot, type-lattice-merge, etc.
         "propagator.rkt"      ;; SRE Track 1 Phase 4: mini-network for compound checks
         "sre-core.rkt"        ;; SRE Track 1 Phase 4: structural subtype check
         (only-in "ctor-registry.rkt"
                  ctor-tag-for-value))

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
(define current-subtype-check-count (make-parameter (cons 0 0)))

;; Track 1B Phase 1: Global counters survive across parameterize blocks.
;; For suite-wide measurement without per-command reset.
(define global-subtype-total (box 0))
(define global-subtype-compound (box 0))

(define (bump-subtype-count! #:compound? [compound? #f])
  (define counts (current-subtype-check-count))
  (current-subtype-check-count
   (cons (add1 (car counts))
         (if compound? (add1 (cdr counts)) (cdr counts))))
  ;; Also bump globals
  (set-box! global-subtype-total (add1 (unbox global-subtype-total)))
  (when compound?
    (set-box! global-subtype-compound (add1 (unbox global-subtype-compound)))))

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

;; SRE structural subtype check: query pattern (design §Phase 4).
;; Creates a mini-network, installs subtype-relate propagator, quiesces,
;; checks for contradiction. Only activates for compound types with
;; matching constructor tags.
;;
;; NOTE: type-sre-domain-for-subtype is defined AFTER subtype-lattice-merge
;; (below) because it references it. Racket evaluates top-level defines
;; in order; forward references fail at module-load time.

(define (sre-structural-subtype-check t1 t2)
  ;; Only try structural check if both are compound with same tag
  (define tag1 (sre-constructor-tag type-sre-domain-for-subtype t1))
  (define tag2 (sre-constructor-tag type-sre-domain-for-subtype t2))
  (cond
    [(not (and tag1 tag2 (eq? tag1 tag2))) #f]  ;; different tags or atomic → not structural
    [else
     (bump-subtype-count! #:compound? #t)
     ;; Create mini-network
     (define net0 (make-prop-network))
     (define-values (net1 cell-a)
       (net-new-cell net0 t1 type-lattice-merge type-lattice-contradicts?))
     (define-values (net2 cell-b)
       (net-new-cell net1 t2 type-lattice-merge type-lattice-contradicts?))
     ;; Install subtype-relate propagator
     (define-values (net3 _pid)
       (net-add-propagator net2 (list cell-a cell-b) (list cell-a cell-b)
         (sre-make-structural-relate-propagator
          type-sre-domain-for-subtype cell-a cell-b
          #:relation sre-subtype)))
     ;; Run to quiescence
     (define net4 (run-to-quiescence net3))
     ;; No contradiction = subtype holds
     (not (or (net-contradiction? net4)
              (type-lattice-contradicts? (net-cell-read net4 cell-a))
              (type-lattice-contradicts? (net-cell-read net4 cell-b))))]))

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
(define (subtype-query-merge-registry rel-name)
  (case rel-name
    [(equality) type-lattice-merge]
    [(subtype subtype-reverse) subtype-lattice-merge]
    [else (error 'subtype-query-merge "no merge for: ~a" rel-name)]))

(define type-sre-domain-for-subtype
  (sre-domain 'type
              subtype-query-merge-registry  ;; merge-registry
              type-lattice-contradicts?
              type-bot?
              type-bot
              type-top   ;; top-value
              #f #f      ;; no meta-recognizer/resolver (ground types only)
              #f))       ;; no dual-pairs
