#lang racket/base

;;;
;;; type-lattice.rkt — Type lattice for propagator-based type inference
;;;
;;; Defines the merge function (lattice join) for type-valued propagator cells.
;;; This is the FlatLattice over Prologos type expressions:
;;;
;;;   type-bot  (⊥, no information — fresh metavariable)
;;;       ↓
;;;   T         (concrete type expression)
;;;       ↓
;;;   type-top  (⊤, contradiction — incompatible types)
;;;
;;; The merge function attempts pure structural unification: if two non-equal
;;; types are written to the same cell, unification determines whether they
;;; are compatible (e.g., Pi Nat Bool = Pi Nat Bool) or contradictory
;;; (e.g., Nat ≠ Bool → ⊤).
;;;
;;; CRITICAL: This module does NOT depend on metavar-store.rkt. The merge
;;; function is pure — no solve-meta!, no add-constraint!, no side effects.
;;; This is required because propagator networks are persistent/immutable.
;;;
;;; Design reference: docs/tracking/2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md §3.2, §5.1
;;;

(require racket/match
         racket/list
         "prelude.rkt"         ;; mult-meta?, mult-meta-id (Phase E1)
         "syntax.rkt"
         "reduction.rkt"       ;; whnf (read-only)
         "zonk.rkt"            ;; zonk-at-depth (read-only)
         "substitution.rkt"    ;; open-expr (read-only)
         "ctor-registry.rkt"   ;; PUnify Phase 1: descriptor-driven structural merge
         "union-types.rkt")    ;; SRE Track 2H: canonical union construction (extracted)

(provide type-bot type-top type-bot? type-top?
         type-lattice-merge
         type-unify-or-top           ;; PPN 4C Path T-3 Commit A: Role B equality-enforce helper
         type-lattice-meet           ;; Track 2G: lattice meet (greatest lower bound)
         type-lattice-contradicts?
         try-unify-pure
         ;; Phase E1: Meta-solution callback for propagator-aware merge
         current-lattice-meta-solution-fn
         install-lattice-meta-solution-fn!
         has-unsolved-meta?
         ;; SRE Track 2H: subtype callback for meet
         current-lattice-subtype-fn
         install-lattice-subtype-fn!)

;; ========================================
;; Sentinel values
;; ========================================

(define type-bot 'type-bot)
(define type-top 'type-top)

(define (type-bot? v) (eq? v 'type-bot))
(define (type-top? v) (eq? v 'type-top))

;; ========================================
;; Phase E1: Meta-solution callback
;; ========================================
;; Read-only callback for following solved metavariable solutions in pure merge.
;; Signature: (meta-id → expr | #f) — returns solution or #f if unsolved.
;; Installed by driver.rkt; default #f (pure structural only).
;; CRITICAL: This is READ-ONLY. No side effects (no solve-meta!, no cell writes).
(define current-lattice-meta-solution-fn (make-parameter #f))

(define (install-lattice-meta-solution-fn! fn)
  (current-lattice-meta-solution-fn fn))

;; SRE Track 2H: Subtype callback for meet.
;; Signature: (type1 type2 → bool) — returns #t if type1 <: type2.
;; Installed by driver.rkt; default #f (structural meet only).
;; When installed, type-lattice-meet can compute GLB for subtype-related atoms:
;; meet(Nat, Int) = Nat when Nat <: Int, instead of type-bot.
(define current-lattice-subtype-fn (make-parameter #f))

(define (install-lattice-subtype-fn! fn)
  (current-lattice-subtype-fn fn))

;; Phase E1: Check if an expression contains unsolved metavariables.
;; Uses the meta-solution callback to distinguish solved from unsolved.
(define (has-unsolved-meta? e)
  (define sol-fn (current-lattice-meta-solution-fn))
  (cond
    [(not sol-fn) #f]    ;; No callback → can't check, assume no metas
    [(type-bot? e) #f]
    [(type-top? e) #f]
    [(expr-meta? e)
     (not (sol-fn (expr-meta-id e)))]
    [(expr-Pi? e)
     (or (and (mult-meta? (expr-Pi-mult e))
              (not (sol-fn (mult-meta-id (expr-Pi-mult e)))))
         (has-unsolved-meta? (expr-Pi-domain e))
         (has-unsolved-meta? (expr-Pi-codomain e)))]
    [(expr-app? e)
     (or (has-unsolved-meta? (expr-app-func e))
         (has-unsolved-meta? (expr-app-arg e)))]
    [(expr-Eq? e)
     (or (has-unsolved-meta? (expr-Eq-type e))
         (has-unsolved-meta? (expr-Eq-lhs e))
         (has-unsolved-meta? (expr-Eq-rhs e)))]
    [(expr-Vec? e)
     (or (has-unsolved-meta? (expr-Vec-elem-type e))
         (has-unsolved-meta? (expr-Vec-length e)))]
    [(expr-Sigma? e)
     (or (has-unsolved-meta? (expr-Sigma-fst-type e))
         (has-unsolved-meta? (expr-Sigma-snd-type e)))]
    [(expr-PVec? e) (has-unsolved-meta? (expr-PVec-elem-type e))]
    [(expr-Set? e) (has-unsolved-meta? (expr-Set-elem-type e))]
    [(expr-Map? e)
     (or (has-unsolved-meta? (expr-Map-k-type e))
         (has-unsolved-meta? (expr-Map-v-type e)))]
    [(expr-union? e)
     (or (has-unsolved-meta? (expr-union-left e))
         (has-unsolved-meta? (expr-union-right e)))]
    [(expr-lam? e)
     (or (has-unsolved-meta? (expr-lam-type e))
         (has-unsolved-meta? (expr-lam-body e)))]
    [(expr-pair? e)
     (or (has-unsolved-meta? (expr-pair-fst e))
         (has-unsolved-meta? (expr-pair-snd e)))]
    [(expr-suc? e) (has-unsolved-meta? (expr-suc-pred e))]
    [(expr-nat-val? e) #f]
    [(expr-Fin? e) (has-unsolved-meta? (expr-Fin-bound e))]
    [else #f]))

;; ========================================
;; Lattice merge (join)
;; ========================================
;;
;; Satisfies: commutative, associative, idempotent, with type-bot as identity.
;; - merge(⊥, x)  = x           (identity)
;; - merge(x, ⊥)  = x           (commutativity of identity)
;; - merge(⊤, x)  = ⊤           (absorbing element)
;; - merge(x, x)  = x           (idempotent)
;; - merge(T1, T2) = unify(T1,T2) if structurally compatible, else UNION
;;
;; PPN 4C Path T-3 Commit B (2026-04-22): set-union semantics for Role A
;; (accumulate). Structurally-incompatible concrete types produce the union
;; `T1 | T2` via `build-union-type`, NOT `type-top`. Rationale: a join over
;; a type domain that includes unions should produce the union for
;; structurally-incompatible atoms — not a contradiction. `type-top` is
;; reserved for REAL contradictions (explicit annotation violations via
;; check, Role B equality-enforcement via `type-unify-or-top`), not the
;; absence of structural unification. Mirrors SRE Track 2H's
;; `subtype-lattice-merge` which applied the same pattern to the subtype
;; relation. Role B callers (equality enforcement) use `type-unify-or-top`
;; explicitly (see typing-propagators.rkt:type-map-write-unified).
(define (type-lattice-merge v1 v2)
  (cond
    [(type-bot? v1) v2]
    [(type-bot? v2) v1]
    [(type-top? v1) type-top]
    [(type-top? v2) type-top]
    [(eq? v1 v2) v1]            ;; Phase 7b: pointer-equal fast path (interned atoms, sentinels)
    [(equal? v1 v2) v1]
    [else
     (define result (try-unify-pure v1 v2))
     (cond
       [result result]
       ;; Phase E1: If either side has unsolved metas, we can't declare
       ;; contradiction yet — keep the more concrete value. When the meta
       ;; is solved, solve-meta! writes to its cell, the unify propagator
       ;; fires again, and merge re-runs with the resolved type.
       [(or (has-unsolved-meta? v1) (has-unsolved-meta? v2))
        (if (has-unsolved-meta? v1) v2 v1)]
       ;; Role A set-union: structurally-incompatible concrete types → union.
       ;; PPN 4C T-3 Commit B: resolve top-level solved metas (via Phase E1
       ;; callback) before building the union, so the resulting value is
       ;; self-contained (no raw meta references when the meta is already
       ;; solved via callback).
       [else
        (define sol-fn (current-lattice-meta-solution-fn))
        (define (resolve-top v)
          (if (and sol-fn (expr-meta? v))
              (or (sol-fn (expr-meta-id v)) v)
              v))
        (build-union-type (list (resolve-top v1) (resolve-top v2)))])]))

;; ========================================
;; PPN 4C Path T-3 Commit A (2026-04-22) — equality-enforcement helper
;; ========================================
;; type-unify-or-top: encodes the CURRENT type-lattice-merge semantics
;; (returns type-top for structurally-incompatible concrete types).
;;
;; Used by Role B callers (unify propagators, equality-enforcement
;; constraints) that require contradiction signaling on structural
;; mismatch. Post-T-3 Commit B, type-lattice-merge gains set-union
;; semantics (Role A / accumulate); Role B callers preserve equality
;; enforcement via this function.
;;
;; Semantic: identical to current type-lattice-merge. This function
;; exists to decouple Role B (equality-enforce) from Role A (accumulate)
;; at the API level — per D.3 §7.6.4. Commit B's merge change does not
;; affect this function.
(define (type-unify-or-top v1 v2)
  (cond
    [(type-bot? v1) v2]
    [(type-bot? v2) v1]
    [(type-top? v1) type-top]
    [(type-top? v2) type-top]
    [(eq? v1 v2) v1]
    [(equal? v1 v2) v1]
    [else
     (define result (try-unify-pure v1 v2))
     (cond
       [result result]
       ;; Conservative meta handling (same as type-lattice-merge):
       ;; if either side has unsolved metas, keep concrete side
       [(or (has-unsolved-meta? v1) (has-unsolved-meta? v2))
        (if (has-unsolved-meta? v1) v2 v1)]
       [else type-top])]))

;; ========================================
;; SRE Track 2G: Type lattice meet (greatest lower bound)
;; ========================================
;;
;; Dual of type-lattice-merge (join). Meet computes the greatest lower bound:
;;   ⊤ ⊓ x = x  (top is identity for meet)
;;   x ⊓ ⊥ = ⊥  (bot is annihilator for meet)
;;   equal → identity
;;   metavariable → ⊥ (conservative: can't compute GLB with unknown, D.3 F4)
;;   structurally compatible constructors → component-wise meet with ring action
;;   incompatible → ⊥
;;
;; Ring action for meet at constructor components:
;;   Covariant (+):     meet (monotone preserves operation)
;;   Contravariant (-): join (antitone flips operation)
;;   Invariant (=):     equality-meet (mismatch → ⊥, D.3 F6)
;;   Phantom (ø):       phantom (erased)

(define (type-lattice-meet v1 v2)
  (cond
    ;; Identity: ⊤ ⊓ x = x (dual of ⊥ ⊔ x = x)
    [(type-top? v1) v2]
    [(type-top? v2) v1]
    ;; Annihilator: x ⊓ ⊥ = ⊥ (dual of x ⊔ ⊤ = ⊤)
    [(type-bot? v1) type-bot]
    [(type-bot? v2) type-bot]
    ;; Equal: a ⊓ a = a
    [(eq? v1 v2) v1]
    [(equal? v1 v2) v1]
    ;; Metavariable: conservative → ⊥ (D.3 F4)
    [(or (has-unsolved-meta? v1) (has-unsolved-meta? v2)) type-bot]
    ;; SRE Track 2H: meet distributes over union-join.
    ;; meet(a, b | c) = meet(a, b) | meet(a, c)
    ;; This IS the distributivity law — implementing it here makes the
    ;; lattice distributive by construction.
    [(expr-union? v1)
     (define components (flatten-union v1))
     (define met (filter (lambda (r) (not (type-bot? r)))
                         (map (lambda (c) (type-lattice-meet c v2)) components)))
     (if (null? met) type-bot (build-union-type met))]
    [(expr-union? v2)
     (define components (flatten-union v2))
     (define met (filter (lambda (r) (not (type-bot? r)))
                         (map (lambda (c) (type-lattice-meet v1 c)) components)))
     (if (null? met) type-bot (build-union-type met))]
    [else
     ;; Structural intersection: same constructor tag → component-wise meet
     (define result (try-intersect-pure v1 v2))
     (cond
       [result result]
       ;; SRE Track 2H: subtype-aware meet for atoms.
       ;; When subtype callback is installed: meet(a, b) = a if a <: b,
       ;; meet(a, b) = b if b <: a. The GLB of comparable types is the lesser.
       [else
        (define sub-fn (current-lattice-subtype-fn))
        (cond
          [(and sub-fn (sub-fn v1 v2)) v1]   ;; v1 <: v2 → GLB = v1
          [(and sub-fn (sub-fn v2 v1)) v2]   ;; v2 <: v1 → GLB = v2
          [else type-bot])])]))

;; Pure structural intersection: computes greatest lower bound.
;; Returns #f if types are structurally incompatible (different constructor tags).
;; Uses ring action: covariant → meet, contravariant → join, invariant → equality.
;;
;; Phase 2 scope: base types + Pi + Sigma. Ground types (no metas, no binder opening).
;; Full constructor coverage follows the same pattern via SRE decomposition.
(define (try-intersect-pure t1 t2)
  (let ([a (whnf t1)]
        [b (whnf t2)])
    (cond
      [(equal? a b) a]
      ;; Metas → #f (conservative, D.3 F4: caller returns ⊥)
      [(or (expr-meta? a) (expr-meta? b)) #f]
      ;; Holes → #f
      [(or (expr-hole? a) (expr-hole? b)) #f]
      [(or (expr-typed-hole? a) (expr-typed-hole? b)) #f]
      ;; Pi ⊓ Pi: component-wise with ring action
      ;; mult = invariant (equality-meet: mismatch → #f)
      ;; domain = contravariant (antitone flips: use JOIN)
      ;; codomain = covariant (monotone preserves: use MEET)
      [(and (expr-Pi? a) (expr-Pi? b))
       (let ([m1 (expr-Pi-mult a)] [m2 (expr-Pi-mult b)])
         (cond
           [(not (equal? m1 m2)) #f]  ;; invariant: mismatch → ⊥
           [else
            (define dom-result (type-lattice-merge (expr-Pi-domain a) (expr-Pi-domain b)))
            (define cod-result (type-lattice-meet (expr-Pi-codomain a) (expr-Pi-codomain b)))
            (cond
              [(type-top? dom-result) #f]
              [(type-bot? cod-result) #f]
              ;; Reconstruct Pi preserving original binder structure
              [else (struct-copy expr-Pi a
                                [domain dom-result]
                                [codomain cod-result])])]))]
      ;; Sigma ⊓ Sigma: both covariant positions → meet both
      [(and (expr-Sigma? a) (expr-Sigma? b))
       (let ([fst-result (type-lattice-meet (expr-Sigma-fst-type a) (expr-Sigma-fst-type b))]
             [snd-result (type-lattice-meet (expr-Sigma-snd-type a) (expr-Sigma-snd-type b))])
         (cond
           [(or (type-bot? fst-result) (type-bot? snd-result)) #f]
           [else (struct-copy expr-Sigma a
                              [fst-type fst-result]
                              [snd-type snd-result])]))]
      ;; --- Generic descriptor-driven structural meet (SRE Track 2H Phase 3) ---
      ;; Handles all registered type constructors with binder-depth 0:
      ;; app, Eq, Vec, Fin, pair, suc, PVec, Set, Map.
      ;; Mirrors the generic-merge pattern from try-unify-pure but applies
      ;; the ring action: covariant → meet, contravariant → join, invariant → equality.
      ;; Pi and Sigma are handled above (binder + mult complications).
      [else
       (define desc-a (ctor-tag-for-value a))
       (cond
         [(and desc-a
               (eq? (ctor-desc-domain desc-a) 'type)
               (= (ctor-desc-binder-depth desc-a) 0)
               ((ctor-desc-recognizer-fn desc-a) b))
          ;; Same constructor, no binders — component-wise meet with ring action
          (define arity (ctor-desc-arity desc-a))
          (cond
            [(= arity 0) a]  ;; same atom → identity
            [else
             (define cs1 ((ctor-desc-extract-fn desc-a) a))
             (define cs2 ((ctor-desc-extract-fn desc-a) b))
             (define variances (or (ctor-desc-component-variances desc-a)
                                   (make-list arity '=)))  ;; default invariant
             (define met
               (for/list ([c1 (in-list cs1)]
                          [c2 (in-list cs2)]
                          [v (in-list variances)])
                 (case v
                   [(+) (type-lattice-meet c1 c2)]                  ;; covariant → meet
                   [(-) (type-lattice-merge c1 c2)]                 ;; contravariant → join (antitone)
                   [(=) (if (equal? c1 c2) c1 #f)]                  ;; invariant → equality or fail
                   [(ø) c1]                                          ;; phantom → erased
                   [else (if (equal? c1 c2) c1 #f)])))              ;; unknown → equality
             ;; Any #f or bot component → intersection fails
             (if (or (memq #f met)
                     (ormap type-bot? met))
                 #f
                 ((ctor-desc-reconstruct-fn desc-a) met))])]
         ;; Different constructor tags → no intersection
         [else #f])])))


;; ========================================
;; Contradiction predicate
;; ========================================

(define (type-lattice-contradicts? v)
  (type-top? v))

;; ========================================
;; Pure structural unification
;; ========================================
;;
;; try-unify-pure : Expr Expr → Expr | #f
;;
;; Attempts to unify two type expressions structurally, returning the unified
;; result or #f if incompatible. Has NO side effects — no meta solving, no
;; constraint creation. When metas are encountered, returns #f (can't solve
;; in pure mode).
;;
;; Unlike the full `unify` in unify.rkt (which returns #t/#f/'postponed and
;; performs side effects), this function RECONSTRUCTS the result type.
;;
;; Based on the structural decomposition in unify-whnf (unify.rkt lines 182-322),
;; but stripped of all side-effecting branches.

(define (try-unify-pure t1 t2)
  ;; First reduce both to WHNF
  (let ([a (whnf t1)]
        [b (whnf t2)])
    (cond
      ;; Fast path: structurally identical
      [(equal? a b) a]

      ;; Metas: follow solved metas via callback (Phase E1).
      ;; P-U4b: When meta is unsolved, return the concrete other side.
      ;; This enables the propagator lattice to resolve meta-bearing
      ;; unifications transitively: merge(unsolved, Nat) = Nat.
      ;; Monotonicity: bot ⊔ v = v for any v.
      [(expr-meta? a)
       (define sol-fn (current-lattice-meta-solution-fn))
       (define sol (and sol-fn (sol-fn (expr-meta-id a))))
       (if sol (try-unify-pure sol b) b)]  ;; unsolved → return concrete side
      [(expr-meta? b)
       (define sol-fn (current-lattice-meta-solution-fn))
       (define sol (and sol-fn (sol-fn (expr-meta-id b))))
       (if sol (try-unify-pure a sol) a)]  ;; unsolved → return concrete side

      ;; Holes: can't handle in pure mode
      [(expr-hole? a) #f]
      [(expr-hole? b) #f]
      [(expr-typed-hole? a) #f]
      [(expr-typed-hole? b) #f]

      ;; --- Structural decomposition ---

      ;; Pi vs Pi: unify multiplicities, domains, codomains
      [(and (expr-Pi? a) (expr-Pi? b))
       (let ([m1 (expr-Pi-mult a)] [m2 (expr-Pi-mult b)])
         (cond
           ;; Multiplicities must match; Phase E1: follow solved mult-metas
           [(not (equal? m1 m2))
            (define sol-fn (current-lattice-meta-solution-fn))
            (define m1* (if (and sol-fn (mult-meta? m1))
                            (or (sol-fn (mult-meta-id m1)) m1)
                            m1))
            (define m2* (if (and sol-fn (mult-meta? m2))
                            (or (sol-fn (mult-meta-id m2)) m2)
                            m2))
            (if (equal? m1* m2*)
                ;; Resolved mults match — continue with domain/codomain
                (let ()
                  (define dom (try-unify-pure (expr-Pi-domain a) (expr-Pi-domain b)))
                  (and dom
                       (let ([x (expr-fvar (gensym 'pure-unify))])
                         (define cod-a (open-expr (zonk-at-depth 1 (expr-Pi-codomain a)) x))
                         (define cod-b (open-expr (zonk-at-depth 1 (expr-Pi-codomain b)) x))
                         (define cod (try-unify-pure cod-a cod-b))
                         (and cod (expr-Pi m1* dom (expr-Pi-codomain a))))))
                #f)]
           [else
            (define dom (try-unify-pure (expr-Pi-domain a) (expr-Pi-domain b)))
            (and dom
                 (let ([x (expr-fvar (gensym 'pure-unify))])
                   (define cod-a (open-expr (zonk-at-depth 1 (expr-Pi-codomain a)) x))
                   (define cod-b (open-expr (zonk-at-depth 1 (expr-Pi-codomain b)) x))
                   (define cod (try-unify-pure cod-a cod-b))
                   ;; We return a reconstructed Pi with the original codomain structure.
                   ;; Since both sides were equal (unified successfully), either original is fine.
                   ;; Use the first side's codomain as-is (they're structurally equal after unification).
                   (and cod (expr-Pi m1 dom (expr-Pi-codomain a)))))]))]

      ;; Sigma vs Sigma: unify fst-types, snd-types
      [(and (expr-Sigma? a) (expr-Sigma? b))
       (define fst (try-unify-pure (expr-Sigma-fst-type a) (expr-Sigma-fst-type b)))
       (and fst
            (let ([x (expr-fvar (gensym 'pure-unify))])
              (define snd-a (open-expr (zonk-at-depth 1 (expr-Sigma-snd-type a)) x))
              (define snd-b (open-expr (zonk-at-depth 1 (expr-Sigma-snd-type b)) x))
              (define snd (try-unify-pure snd-a snd-b))
              (and snd (expr-Sigma fst (expr-Sigma-snd-type a)))))]

      ;; nat-val vs nat-val
      [(and (expr-nat-val? a) (expr-nat-val? b))
       (and (= (expr-nat-val-n a) (expr-nat-val-n b)) a)]
      ;; Cross-repr: nat-val(0) vs zero
      [(and (expr-nat-val? a) (expr-zero? b)) (and (= (expr-nat-val-n a) 0) a)]
      [(and (expr-zero? a) (expr-nat-val? b)) (and (= (expr-nat-val-n b) 0) b)]

      ;; tycon vs tycon: same name
      [(and (expr-tycon? a) (expr-tycon? b))
       (and (eq? (expr-tycon-name a) (expr-tycon-name b)) a)]

      ;; lam vs lam: kept for binder + mult handling (genericized in later phase)
      [(and (expr-lam? a) (expr-lam? b))
       (define ty (try-unify-pure (expr-lam-type a) (expr-lam-type b)))
       (and ty
            (let ([x (expr-fvar (gensym 'pure-unify))])
              (define body-a (open-expr (zonk-at-depth 1 (expr-lam-body a)) x))
              (define body-b (open-expr (zonk-at-depth 1 (expr-lam-body b)) x))
              (define body (try-unify-pure body-a body-b))
              (and body (expr-lam (expr-lam-mult a) ty (expr-lam-body a)))))]

      ;; Type vs Type: level equality (structural, no level-meta solving)
      [(and (expr-Type? a) (expr-Type? b))
       (and (equal? (expr-Type-level a) (expr-Type-level b)) a)]

      ;; Union vs Union: flatten, sort, dedup, pairwise unify
      [(and (expr-union? a) (expr-union? b))
       (try-unify-pure-unions a b)]

      ;; ann: strip (should not survive WHNF, but handle defensively)
      [(expr-ann? a) (try-unify-pure (expr-ann-term a) b)]
      [(expr-ann? b) (try-unify-pure a (expr-ann-term b))]

      ;; --- Generic descriptor-driven structural merge (PUnify Phase 1) ---
      ;; Handles all registered type constructors with binder-depth 0:
      ;; suc, app, Eq, Vec, Fin, pair, PVec, Set, Map.
      ;; Replaces 9 per-tag hardcoded cases with a single descriptor-driven dispatch.
      ;; Pi and Sigma are handled above (binder + mult-meta complications).
      ;; Lam is handled above (binder + mult handling).
      [else
       (define desc-a (ctor-tag-for-value a))
       (cond
         [(and desc-a
               (eq? (ctor-desc-domain desc-a) 'type)
               (= (ctor-desc-binder-depth desc-a) 0)
               ((ctor-desc-recognizer-fn desc-a) b))
          ;; Same constructor, no binders — generic component-wise merge
          (generic-merge a b #:type-merge try-unify-pure #:domain 'type)]
         [else #f])])))

;; ========================================
;; Union type pure unification
;; ========================================
;;
;; SRE Track 2H Phase 1: flatten-union, union-sort-key, dedup-union-components
;; are now imported from union-types.rkt (eliminates duplication with unify.rkt).

(define (try-unify-pure-unions a b)
  (define cs-a (dedup-union-components
                 (sort (flatten-union a) string<? #:key union-sort-key)))
  (define cs-b (dedup-union-components
                 (sort (flatten-union b) string<? #:key union-sort-key)))
  (cond
    [(not (= (length cs-a) (length cs-b))) #f]
    [else
     ;; Pairwise unify components
     (define unified
       (for/list ([ca (in-list cs-a)]
                  [cb (in-list cs-b)])
         (try-unify-pure ca cb)))
     (cond
       [(ormap not unified) #f]
       ;; Reconstruct union from unified components
       [(= (length unified) 1) (car unified)]
       [else (foldr expr-union (last unified) (drop-right unified 1))])]))
