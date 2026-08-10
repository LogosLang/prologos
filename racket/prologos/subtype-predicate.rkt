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
         (only-in "prelude.rkt" compatible)
         "macros.rkt"          ;; subtype-pair?
         "type-lattice.rkt"    ;; type-top, type-bot, type-lattice-merge, has-unsolved-meta?, try-unify-pure
         "union-types.rkt"     ;; SRE Track 2H: flatten-union, build-union-type
         "substitution.rkt"    ;; SRE Track 2H Phase 4: subst for tensor binder instantiation
         "propagator.rkt"      ;; SRE Track 1 Phase 4: mini-network for compound checks
         "sre-core.rkt"        ;; SRE Track 1 Phase 4: structural subtype check
         (only-in "ctor-registry.rkt"
                  ctor-tag-for-value
                  lookup-ctor-desc
                  ctor-desc-extract-fn
                  ctor-desc-component-variances
                  ctor-desc-arity))

(provide subtype?
         record-subtypes-map?   ;; CIU T6 F1: record → Map α (also used by unify's classifier)
         record-subtypes-pvec?  ;; CIU T6 F1a-col: tuple → PVec α (pure; unify + walks)
         type-key
         subtype-lattice-merge
         build-union-type-with-absorption  ;; SRE Track 2H Phase 2
         ;; SRE Track 2H Phase 4: Tensor (quantale multiplication)
         type-tensor-core                  ;; propagator fire function: single Pi × single arg
         type-tensor-distribute            ;; scaffolding: imperative union distribution
         ;; SRE Track 2H Phase 8: Pseudo-complement (SCAFFOLDING)
         type-pseudo-complement            ;; Heyting pseudo-complement for error reporting
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
    ;; CIU T6 F1 (s2): the structural-record → Map Galois α, reachable from NESTED
    ;; positions (e.g. (List Record) <: (List Map) via the covariant List walk).
    ;; This is the record→Map bridge, NOT a record<:record judgment (D11 preserved);
    ;; in subtype context V is always concrete, so no meta-solving is needed.
    [(and (expr-Record? t1) (expr-Map? t2)) (record-subtypes-map? t1 t2)]
    ;; CIU T6 F1a-col: the tuple→PVec α (same bridge, positional domain).
    [(and (expr-Record? t1) (expr-PVec? t2)) (record-subtypes-pvec? t1 t2)]
    ;; Pi multiplicity is an UPPER BOUND on how the function uses its argument,
    ;; so a Pi that uses it LESS fits where one that may use it more is wanted.
    ;; That relation is already written down — it is exactly `compatible`, the
    ;; same predicate every binder check uses (`compatible 'mw 'm0` = #t). This
    ;; arm applies it structurally instead of demanding the mults be identical.
    ;;
    ;; The case that forced it: a type constructor's kind is `Pi m0 Type Type`
    ;; (its type argument IS erased), while a spec's `{C : Type -> Type}` writes
    ;; an unannotated arrow, which defaults to `mw`. So `length '[1 2 3]` on a
    ;; `def` RHS failed with "Multiplicity violation" — the lying-diagnostic
    ;; shape from `pipeline.md`, naming QTT for a kind mismatch. It survived
    ;; because typing-core sees `C` as an unsolved META and meta-solving never
    ;; compares multiplicities; only the post-freeze QTT pass meets the concrete
    ;; `List` and the two spellings collide.
    ;;
    ;; Normalize-then-delegate rather than re-deriving Pi's variance here: swap
    ;; in t2's multiplicity and recur, so domain/codomain go through the one
    ;; existing structural path. Terminates — the mults are equal on the recur.
    [(and (expr-Pi? t1) (expr-Pi? t2)
          (not (eq? (expr-Pi-mult t1) (expr-Pi-mult t2)))
          (compatible (expr-Pi-mult t2) (expr-Pi-mult t1)))
     (subtype? (expr-Pi (expr-Pi-mult t2)
                        (expr-Pi-domain t1)
                        (expr-Pi-codomain t1))
               t2)]
    ;; SRE structural path: only if BOTH are compound types.
    ;; Atoms (expr-Nat, expr-Int, expr-Bool, etc.) skip the structural
    ;; path entirely — eliminates 1.85μs overhead from sre-constructor-tag.
    [(and (compound-type? t1) (compound-type? t2)
          (sre-structural-subtype-check t1 t2)) #t]
    ;; Not a subtype
    [else #f]))

;; Pure structural record→Map: every label fits K, every field type <: V.
;; Empty record satisfies any (Map K V) (Q6). Keyword-domain labels need a Keyword key type.
;; CIU T6 F1a.2 p1a (D16): the knowns-only check IS the C_ConsL absorption for
;; 'dyn-tailed rows — the unknown remainder is absorbed under the S–I consistency
;; posture, so tail-blindness here is DELIBERATE dyn semantics, not an oversight
;; (§12.4). The meta-solving sibling record-<:-map? in typing-core, by contrast,
;; REFUSES to solve a meta V from a dyn row (⋃knowns would over-commit).
(define (record-subtypes-map? rec mp)
  (define kt (expr-Map-k-type mp))
  (define vt (expr-Map-v-type mp))
  ;; CIU T6 F1a-col key-gate fix (audit must-fix): the key type must match the
  ;; row's key DOMAIN — previously non-keyword domains skipped the gate, letting
  ;; a 'nat tuple "satisfy" (Map String V).
  (and (case (expr-Record-key-domain rec)
         [(keyword) (expr-Keyword? kt)]
         [(nat) (or (expr-Nat? kt) (expr-Int? kt))]
         [else #f])
       (andmap (lambda (f) (subtype? (record-field-type (cdr f)) vt))
               (expr-Record-fields rec))))

;; CIU T6 F1a-col: pure structural tuple→PVec α — 'nat rows only; every position
;; type <: the element type. (The meta-aware sibling record-<:-pvec? lives in
;; typing-core; this one serves subtype?/structural walks/unify's classifier.)
(define (record-subtypes-pvec? rec pv)
  (and (eq? (expr-Record-key-domain rec) 'nat)
       (let ([at (expr-PVec-elem-type pv)])
         (andmap (lambda (f) (subtype? (record-field-type (cdr f)) at))
                 (expr-Record-fields rec)))))

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
    ;; Float family (Numerics N3d): within-Float widening (NO Posit↔Float edge)
    [((expr-Float32) (expr-Float64)) #t]
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
    ;; CIU T6 F1 (s2): record→Map α inside a covariant component (e.g. the element of
    ;; (List Record) <: (List Map)), reached via this component recursion — NOT subtype?.
    [(and (expr-Record? t1) (expr-Map? t2)) (record-subtypes-map? t1 t2)]
    ;; CIU T6 F1a-col: tuple→PVec α inside covariant components.
    [(and (expr-Record? t1) (expr-PVec? t2)) (record-subtypes-pvec? t1 t2)]
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

;; ========================================
;; SRE Track 2H Phase 2: Subtype absorption (SCAFFOLDING)
;; ========================================
;; In the permanent network architecture, absorption is emergent from
;; pairwise cell merges as writes arrive. This explicit algorithm is
;; scaffolding — the imperative simulation of what the network does.

;; Remove any component that is a subtype of another.
;; O(n^2) in the number of components — acceptable for typical 2-5 component unions.
;; Returns a filtered list (may be shorter than input).
(define (absorb-subtype-components components)
  (filter
    (lambda (c)
      ;; Keep c unless some OTHER component is a strict supertype
      (not (for/or ([other (in-list components)])
             (and (not (equal? c other))
                  (subtype? c other)))))
    components))

;; Build a canonical union type with subtype absorption.
;; flatten → sort → dedup → absorb → fold.
;; Single type → identity. Empty → expr-error.
(define (build-union-type-with-absorption types)
  (define flat (append-map flatten-union types))
  (define sorted (sort flat string<? #:key union-sort-key))
  (define deduped (dedup-union-components sorted))
  (define absorbed (absorb-subtype-components deduped))
  (cond
    [(null? absorbed) (expr-error)]
    [(= (length absorbed) 1) (car absorbed)]
    [else (foldr expr-union (last absorbed) (drop-right absorbed 1))]))

;; ========================================
;; SRE Track 2H Phase 4: Tensor (⊗) — quantale multiplication
;; ========================================
;; The tensor takes a SINGLE function type and a SINGLE argument type
;; and produces the result type. This is Pi elimination at the type level.
;;
;; Returns type-bot for inapplicable types (F1: not type-top).
;; In a propagator network, "can't apply" = propagator doesn't write
;; = output cell stays at bot (no information). type-top means
;; CONTRADICTION (two conflicting pieces of information).
;;
;; type-tensor-core is the operation PPN Track 4 wires as a propagator.
;; type-tensor-distribute is scaffolding: the imperative simulation of
;; what the network does when multiple components write to the same cell.
;; Distribution is EMERGENT network behavior (M3), not explicit computation.

(define (type-tensor-core func-type arg-type)
  (cond
    [(type-bot? func-type) type-bot]    ;; no info → no output
    [(type-bot? arg-type) type-bot]
    [(type-top? func-type) type-top]    ;; genuine contradiction propagates
    [(type-top? arg-type) type-top]
    [(expr-Pi? func-type)
     (let ([domain (expr-Pi-domain func-type)]
           [codomain (expr-Pi-codomain func-type)])
       (cond
         [(subtype? arg-type domain) (subst 0 arg-type codomain)]
         [(try-unify-pure arg-type domain) (subst 0 arg-type codomain)]
         [else type-bot]))]             ;; inapplicable → no info
    [else type-bot]))                   ;; non-Pi → no info

;; Scaffolding: imperative distribution for pre-network elaborator.
;; In PPN Track 4's propagator network, this is unnecessary — the network
;; fires type-tensor-core per component, the output cell's merge produces
;; the union. Distribution is emergent from multiple writes.
(define (type-tensor-distribute func-type arg-type)
  (cond
    [(and (expr-union? func-type) (expr-union? arg-type))
     ;; Both unions: distribute both sides (cross product)
     (define results
       (for*/list ([f (in-list (flatten-union func-type))]
                   [a (in-list (flatten-union arg-type))])
         (type-tensor-core f a)))
     ;; Filter out bot (inapplicable components)
     (define valid (filter (lambda (r) (not (type-bot? r))) results))
     (if (null? valid) type-bot
         (build-union-type-with-absorption valid))]
    [(expr-union? func-type)
     (define results
       (for/list ([f (in-list (flatten-union func-type))])
         (type-tensor-core f arg-type)))
     (define valid (filter (lambda (r) (not (type-bot? r))) results))
     (if (null? valid) type-bot
         (build-union-type-with-absorption valid))]
    [(expr-union? arg-type)
     (define results
       (for/list ([a (in-list (flatten-union arg-type))])
         (type-tensor-core func-type a)))
     (define valid (filter (lambda (r) (not (type-bot? r))) results))
     (if (null? valid) type-bot
         (build-union-type-with-absorption valid))]
    [else (type-tensor-core func-type arg-type)]))

;; ========================================
;; SRE Track 2H Phase 8: Pseudo-complement (SCAFFOLDING)
;; ========================================
;; Heyting pseudo-complement: ¬a = max{x | x ⊓ a ≤ ⊥}
;; For ground types: the union of all context types incompatible with `type`.
;;
;; DISAMBIGUATION (SRE Track 2I Phase 5, 2026-04-30): this function computes
;; the **context-relative absolute pseudo-complement** (¬a) — 1-arg over a
;; supplied context list — for error-reporting use. Distinct from the
;; **lattice-theoretic relative pseudo-complement** (a → b, the Heyting →
;; operator) tested empirically by `test-pseudo-complement-rel` in sre-core.rkt.
;; In a Heyting algebra, the relative form generalizes (a → ⊥ = ¬a). For our
;; finite-context error-reporting purposes the 1-arg form is sufficient and
;; cheaper. See sre-core.rkt for the empirical lattice-theoretic check used
;; in the SRE algebraic-property registry.
;;
;; SCAFFOLDING (M2, F6): This is a function over a list of context types.
;; The permanent solution is ATMS-derived: when a cell reaches type-top,
;; the ATMS nogood records the conflicting assumption set. Retracting the
;; conflicting assumption gives the maximal consistent subset — the
;; pseudo-complement falls out of the dependency structure.
;; RETIRE WHEN: PPN Track 4 delivers ATMS-managed type cells.
;;
;; Context source (F6): Takes a list of types. Callers should derive this
;; from the cell registry where available (structural identity), not ad-hoc
;; collection (positional identity).

(define (type-pseudo-complement type context-types)
  ;; SRE Track 2I Phase 3c (2026-04-30): pseudo-complement is a SUBTYPE-relation
  ;; concept (compatibility under the subtype order). Use subtype-aware meet
  ;; explicitly (was implicit via the always-installed callback pre-3c).
  (define incompatible
    (filter (lambda (t)
              (let ([m (type-lattice-meet t type #:subtype-fn subtype?)])
                (type-bot? m)))
            context-types))
  (cond
    [(null? incompatible) type-top]  ;; nothing incompatible → ⊤ (everything is compatible)
    [else (build-union-type-with-absorption incompatible)]))

;; ========================================
;; SRE Track 2H Phase 2: Redesigned subtype-lattice-merge
;; ========================================
;; Returns the join in the subtype ordering:
;;   merge(⊥, x) = x             (identity — fixes V1d)
;;   merge(x, ⊥) = x
;;   merge(⊤, x) = ⊤             (absorbing)
;;   merge(a, b) = a if a = b     (idempotent)
;;   merge(a, b) = b if a <: b    (absorption for comparable)
;;   merge(a, b) = a if b <: a
;;   merge(a, b) = union(a, b)    (incomparable → union type, NOT type-top)
;;
;; Meta handling: keep concrete side. KNOWN UNSOUNDNESS (F2):
;; not monotone in the merge function itself — compensated by
;; solve-meta! + constraint-retry pipeline. Pre-existing pattern
;; inherited from type-lattice-merge. Retirement: PPN Track 4
;; ATMS-conditional cell values.
;;
;; Monotone, commutative, associative, idempotent. Used by the SRE
;; subtype propagator to keep subtyping fully on-network.
(define (subtype-lattice-merge a b)
  (cond
    [(type-bot? a) b]             ;; identity (fixes V1d)
    [(type-bot? b) a]
    [(type-top? a) type-top]      ;; absorbing
    [(type-top? b) type-top]
    [(equal? a b) a]              ;; idempotent
    [(subtype? a b) b]            ;; a ≤ b → join = b
    [(subtype? b a) a]            ;; b ≤ a → join = a
    ;; Meta handling (F2): keep concrete side — compensated by solve-meta! pipeline
    [(or (has-unsolved-meta? a) (has-unsolved-meta? b))
     (if (has-unsolved-meta? a) b a)]
    [else
     ;; Incomparable under subtyping → canonical union with absorption
     (build-union-type-with-absorption (list a b))]))

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
  (make-sre-domain
    #:name 'type
    #:merge-registry subtype-query-merge-registry
    #:contradicts? type-lattice-contradicts?
    #:bot? type-bot?
    #:bot-value type-bot
    #:top-value type-top))
