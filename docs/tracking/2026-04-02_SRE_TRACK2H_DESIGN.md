# SRE Track 2H: Type Lattice Redesign — Stage 3 Design (D.1)

**Date**: 2026-04-02
**Series**: [SRE (Structural Reasoning Engine)](2026-03-22_SRE_MASTER.md)
**Prerequisites**: [SRE Track 2G ✅](2026-03-30_SRE_TRACK2G_DESIGN.md) (Algebraic Domain Awareness — property inference, meet, ring action), [SRE Track 2F 🔄](2026-03-28_SRE_TRACK2F_DESIGN.md) (Algebraic Foundation — variance table, merge registry)
**Audit**: [SRE Track 2H Stage 2 Audit](2026-04-02_SRE_TRACK2H_STAGE2_AUDIT.md)
**Principle**: Propagator Design Mindspace ([DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) § Propagator Design Mindspace)

**Research**:
- [Algebraic Embeddings on Lattices](../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) — §2.4 Heyting algebra for error reporting, §2.5 Residuated lattice for backward propagation
- [Module Theory on Lattices](../research/2026-03-28_MODULE_THEORY_LATTICES.md) — endomorphism ring, variance as ring action
- [Lattice Foundations for PPN](../research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md) — reduced product, chaotic iteration

**Cross-series consumers**:
- [PPN Track 4](2026-03-26_PPN_MASTER.md) — elaboration on network requires well-structured type lattice (PREREQUISITE)
- [SRE Track 3](2026-03-22_SRE_MASTER.md) — trait resolution strategy informed by Heyting properties
- BSP-LE — ATMS worldview management benefits from type lattice algebraic structure

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Pre-0 benchmarks + property checks | ⬜ | Benchmark subtype-lattice-merge, verify distributivity, validate tensor distributes over join |
| 1 | Extract union type helpers to standalone module | ⬜ | Eliminates duplication between type-lattice.rkt and unify.rkt |
| 2 | Subtype-aware join: union types for incomparable types | ⬜ | Core change: subtype-lattice-merge → union types instead of type-top |
| 3 | Subtype absorption in union normalization | ⬜ | `Nat | Int` simplifies to `Int` (Nat <: Int → absorbed) |
| 4 | Extend try-intersect-pure to all registered constructors | ⬜ | Generic descriptor-driven meet via ctor-registry (mirrors try-unify-pure pattern) |
| 5 | Tensor (⊗): type-level function application as lattice operation | ⬜ | `type-tensor : Type × Type → Type` — applies Pi, distributes over unions |
| 6 | Tensor-aware elaboration: infer/check for union types | ⬜ | `expr-app` distributes across union function types and union argument types |
| 7 | Per-relation property declarations on sre-domain | ⬜ | Pocket Universe: one property set per domain×relation pair |
| 8 | Validate algebraic properties: Heyting + quantale | ⬜ | Property inference: distributive, pseudo-complement, Heyting; tensor axioms (associative, distributes over ⊕) |
| 9 | Pseudo-complement computation for error reporting | ⬜ | First consumer of Heyting structure: informative type errors |
| 10 | Verification + acceptance file + PIR | ⬜ | Full suite green, A/B benchmark, acceptance file, PIR |

---

## §1 Objectives

**End state**: The type lattice under the subtype ordering is a **quantale** — a Heyting algebra equipped with a tensor (function application) that distributes over the join. The join of incomparable types is a union type (`Int | String`), not type-top. The meet is a subtype-aware GLB using the ring action from Track 2G. The tensor applies Pi types to argument types, distributing over unions on both sides. Per-relation property declarations let the subtype ordering declare its full algebraic structure independently of the equality ordering. The elaborator handles union types in function application via the tensor's distributive law. Pseudo-complement error reporting is the first Heyting consumer.

**What is delivered**:
1. `union-types.rkt` — extracted union type helpers (eliminates duplication + drift risk)
2. Redesigned `subtype-lattice-merge` that produces union types for incomparable types
3. Subtype absorption in ACI union normalization (`Nat | Int → Int`)
4. Complete `try-intersect-pure` coverage via ctor-registry descriptors (not just Pi/Sigma)
5. `type-tensor` — reified function application as a lattice operation, distributing over unions
6. Tensor-aware elaboration: `infer`/`check` for `expr-app` handle union function types and union argument types via distribution
7. Per-relation property declaration infrastructure on `sre-domain`
8. Property inference validation: subtype ordering is Heyting AND quantale
9. Pseudo-complement computation: `pseudo-complement(A, B)` = largest X such that `X ⊓ A ≤ B`
10. Informative type error messages using pseudo-complement

**What this track is NOT**:
- It does NOT change the equality merge (`type-lattice-merge` remains flat — `Nat ⊔_eq String = ⊤` is correct for equality). Equality and subtype are different orderings on the same carrier. This is the L3 lesson from Track 2G.
- It does NOT put elaboration on-network as propagators — the tensor is a reified FUNCTION, not yet a propagator. PPN Track 4 makes it a propagator. Track 2H delivers the algebraic operation that Track 4 will wire into the network.
- It does NOT implement backward type propagation via residuation — deferred to the residuated lattice track (requires full bidirectional propagator infrastructure).
- It does NOT make `sre-domain` use keyword arguments — that debt (Track 2G L4) is out of scope here unless we touch the struct definition.

---

## §2 Mathematical Grounding

### The Two Orderings

The type carrier set admits two orderings:

1. **Equality ordering**: `a ≤_eq b` iff `a = b`. This is a discrete (flat) lattice. Join of distinct atoms is top. This is CORRECT — equality unification SHOULD produce a contradiction when `Nat ≠ String`. The equality merge is the unification merge.

2. **Subtype ordering**: `a ≤_sub b` iff `a <: b`. This is a partial order with chains (Nat <: Int <: Rat) and incomparable pairs (Int ≁ String). Currently, the join of incomparable types is type-top. The CORRECT join is the union type.

Track 2H redesigns the subtype ordering's lattice operations. The equality ordering is unchanged.

### Target: Heyting Algebra under Subtype Ordering

A **Heyting algebra** is a bounded lattice where for every pair (a, b), the pseudo-complement `a → b = max{x | x ∧ a ≤ b}` exists. Requirements:

1. **Distributive**: `a ⊓ (b ⊔ c) = (a ⊓ b) ⊔ (a ⊓ c)` where ⊔ is union-join, ⊓ is GLB-meet.
2. **Bounded**: type-bot (⊥) and type-top (⊤) exist. ✅ Already have these.
3. **Pseudo-complement exists**: For every a, b, the set `{x | x ⊓ a ≤ ⊥}` has a maximum.

Every finite distributive lattice is automatically Heyting (Birkhoff). Our type lattice is not finite (polymorphic types, dependent types), but for GROUND types (no metas, no binders) the working sublattice at any point in elaboration IS finite and distributive under union-join + GLB-meet.

### Worked Examples

**Join (union-join)**:
- `Int ⊔ String = Int | String` (incomparable → union)
- `Nat ⊔ Int = Int` (Nat <: Int → absorbed, subtype absorption)
- `(Int | String) ⊔ Nat = Int | String` (Nat <: Int → absorbed into Int component)
- `⊥ ⊔ A = A`, `A ⊔ ⊤ = ⊤`

**Meet (GLB-meet)**:
- `Int ⊓ Nat = Nat` (Nat <: Int → GLB is Nat)
- `Int ⊓ String = ⊥` (incomparable, no common subtype)
- `(Int | String) ⊓ Int = Int` (distribute: `(Int ⊓ Int) | (String ⊓ Int) = Int | ⊥ = Int`)
- `⊤ ⊓ A = A`, `⊥ ⊓ A = ⊥`

**Pseudo-complement**:
- `¬_Int(String) = max{X | X ⊓ String ≤ ⊥}` = everything NOT String = the complement of String in the working sublattice
- For ground type errors: `¬_context(conflicting_type)` gives the maximal type compatible with the context that excludes the conflicting type

**Distributivity verification** (the critical law):
- `Nat ⊓ (Int | String) = (Nat ⊓ Int) | (Nat ⊓ String) = Nat | ⊥ = Nat` ✅
- `(Int | Bool) ⊓ (Int | String) = Int | (Bool ⊓ String) = Int | ⊥ = Int` ✅ (by distributing both sides)

### Subtype Absorption

When building a union type, any component that is a subtype of another component is absorbed:
- `Nat | Int → Int` (Nat <: Int)
- `Nat | Rat → Rat` (Nat <: Rat by transitivity)
- `Posit8 | Posit32 | Posit64 → Posit64` (Posit8 <: Posit32 <: Posit64)
- `Int | String → Int | String` (incomparable, both retained)

This is ACI normalization PLUS subtype absorption. The existing `build-union-type` does ACI (associative, commutative, idempotent via sort+dedup). Track 2H adds the absorption step.

---

## §3 Design

### §3.1 Phase 1: Extract union-types.rkt

**Problem**: `flatten-union`, `union-sort-key`, `dedup-union-components`, and `build-union-type` are duplicated between type-lattice.rkt and unify.rkt with active drift (unify.rkt has more sort key entries). type-lattice.rkt can't import unify.rkt (circular via metavar-store.rkt).

**Solution**: Extract pure union type helpers into `union-types.rkt`:
- `flatten-union : Expr → (Listof Expr)`
- `union-sort-key : Expr → String`
- `dedup-union-components : (Listof Expr) → (Listof Expr)`
- `build-union-type : (Listof Expr) → Expr`

Both type-lattice.rkt and unify.rkt import from union-types.rkt. The new module depends only on syntax.rkt (struct definitions). Delete the duplicate `*-pure` versions from type-lattice.rkt and the originals from unify.rkt.

**Principle served**: Decomplection (5). Separable concerns separated. One canonical union normalization.

### §3.2 Phase 2: Subtype-aware join (the core change)

**Current** (`subtype-predicate.rkt:198`):
```racket
(define (subtype-lattice-merge a b)
  (cond
    [(equal? a b) a]
    [(subtype? a b) b]
    [(subtype? b a) a]
    [else type-top]))  ;; ← THIS becomes union type
```

**Redesigned**:
```racket
(define (subtype-lattice-merge a b)
  (cond
    [(type-bot? a) b]           ;; identity
    [(type-bot? b) a]
    [(type-top? a) type-top]    ;; absorbing
    [(type-top? b) type-top]
    [(equal? a b) a]            ;; idempotent
    [(subtype? a b) b]          ;; a ≤ b → join = b
    [(subtype? b a) a]          ;; b ≤ a → join = a
    ;; Meta handling: if either has unsolved metas, keep concrete side
    ;; (same conservative treatment as type-lattice-merge)
    [(or (has-unsolved-meta? a) (has-unsolved-meta? b))
     (if (has-unsolved-meta? a) b a)]
    [else
     ;; Incomparable under subtyping → build union type with absorption
     (build-union-type-with-absorption (list a b))]))
```

**`build-union-type-with-absorption`**: Like `build-union-type` but after flatten+sort+dedup, applies subtype absorption: if any component is a subtype of another, remove the subtype.

**Monotonicity argument**: Union-join is monotone because adding information (refining a component from `?A` to `Nat`) can only shrink the union (via absorption) or leave it the same. It cannot grow the union. ⊥ ⊔ x = x (identity). ⊤ ⊔ x = ⊤ (absorbing). Commutativity: `build-union-type` sorts canonically. Associativity: flatten + sort + dedup + absorb. Idempotent: dedup.

**Where subtype-lattice-merge is called**: Via the merge-registry in type-sre-domain and type-sre-domain-for-subtype. Called when cells with subtype relation are merged. Also called directly from structural subtype checking.

### §3.3 Phase 3: Subtype absorption

**Algorithm**: Given a list of union components (already flattened, sorted, deduped):

```
absorb(components):
  for each pair (a, b) in components:
    if subtype?(a, b): remove a
    if subtype?(b, a): remove b
  return remaining
```

This is O(n^2) in the number of components. For typical union types (2-5 components), this is negligible. For pathological cases (100+ components), the n^2 may matter — but such unions indicate a design problem, not a performance problem.

**Integration**: This runs inside `build-union-type-with-absorption`, AFTER flatten+sort+dedup and BEFORE the final fold to expr-union.

**Correctness**: Absorption is the lattice-theoretic consequence of `a ≤ b → a ⊔ b = b`. In a union `a | b` where `a <: b`, the union is equivalent to `b` alone. This is semantically correct: the set of values inhabiting `Nat | Int` is the same as the set inhabiting `Int` (since every Nat is an Int).

### §3.4 Phase 4: Complete try-intersect-pure

**Current coverage**: Pi (with ring action), Sigma (both covariant). Everything else → `#f` → `type-bot`.

**Target**: All registered type-domain constructors with binder-depth 0.

**Approach**: Mirror the pattern from `try-unify-pure`'s else branch (type-lattice.rkt:367-377), which already uses generic descriptor-driven merge for join. Do the same for meet:

```racket
;; In try-intersect-pure, after Pi and Sigma cases:
[else
 (define desc-a (ctor-tag-for-value a))
 (cond
   [(and desc-a
         (eq? (ctor-desc-domain desc-a) 'type)
         (= (ctor-desc-binder-depth desc-a) 0)
         ((ctor-desc-recognizer-fn desc-a) b))
    ;; Same constructor, no binders — component-wise meet with ring action
    (generic-meet a b #:type-meet type-lattice-meet
                      #:type-join type-lattice-merge
                      #:domain 'type)]
   [else #f])]
```

Where `generic-meet` mirrors `generic-merge` but applies the ring action:
- Covariant (+): meet (monotone preserves)
- Contravariant (-): join (antitone flips)
- Invariant (=): equality (mismatch → #f)
- Phantom (ø): phantom (erased)

**Constructors gained**: app, Eq, Vec, Fin, pair, suc, PVec, Set, Map — 9 constructors, bringing total meet coverage from 2 to 11.

**Principle served**: Completeness (6). The meet was incomplete (only Pi/Sigma). Generic descriptor-driven meet makes it complete for all registered types.

### §3.5 Phase 5: Tensor (⊗) — type-level function application

**The operation**: The tensor takes a function type and an argument type and produces the result type. This is Pi elimination at the type level:

```
type-tensor : Type × Type → Type

type-tensor((A → B), C) =
  | C <: A     → B[C/binder]           ;; argument fits domain
  | C = ⊥      → ⊥                     ;; annihilation
  | C = union  → ⊔{type-tensor(f, ci)} ;; distribute over argument union
  | otherwise  → type-top               ;; type error (argument incompatible)

type-tensor((F₁ | F₂), C) =            ;; distribute over function union
  ⊔{type-tensor(fi, C)}                ;; each fi must be Pi; non-Pi → type-top component
```

**Key algebraic properties**:
1. **Distributes over join (⊕)**: `f ⊗ (a ⊕ b) = (f ⊗ a) ⊕ (f ⊗ b)` — this IS the semiring axiom
2. **Left-distributes over join**: `(f ⊕ g) ⊗ a = (f ⊗ a) ⊕ (g ⊗ a)` — union of function types
3. **Annihilation**: `f ⊗ ⊥ = ⊥`, `⊥ ⊗ a = ⊥`
4. **Absorbing element**: `f ⊗ ⊤ = ⊤` (applying to contradiction preserves contradiction)
5. **Identity**: `(A → A) ⊗ A = A` (identity function)
6. **Associativity**: `(A → B → C) ⊗ A ⊗ B = C` (curried application)

**Implementation site**: New function in `type-lattice.rkt` (pure, no side effects). Uses `subtype?` for domain checking, `build-union-type-with-absorption` for result normalization, `subst` for binder instantiation.

```racket
(define (type-tensor func-type arg-type)
  (cond
    [(type-bot? func-type) type-bot]
    [(type-bot? arg-type) type-bot]
    [(type-top? func-type) type-top]
    [(type-top? arg-type) type-top]
    ;; Union function type: distribute
    [(expr-union? func-type)
     (let ([components (flatten-union func-type)])
       (build-union-type-with-absorption
         (map (lambda (f) (type-tensor f arg-type)) components)))]
    ;; Union argument type: distribute
    [(expr-union? arg-type)
     (let ([components (flatten-union arg-type)])
       (build-union-type-with-absorption
         (map (lambda (a) (type-tensor func-type a)) components)))]
    ;; Pi type: apply
    [(expr-Pi? func-type)
     (let ([domain (expr-Pi-domain func-type)]
           [codomain (expr-Pi-codomain func-type)])
       (cond
         [(subtype? arg-type domain) (subst 0 arg-type codomain)]
         ;; Try equality merge (handles metas)
         [(try-unify-pure arg-type domain) (subst 0 arg-type codomain)]
         [else type-top]))]
    ;; Non-Pi, non-union: can't apply
    [else type-top]))
```

**Dependency**: Phases 2-3 (union-join + absorption) must be complete. `type-tensor` uses `build-union-type-with-absorption` and `flatten-union`.

**Principle served**: Completeness (6) — delivering the full quantale, not half a semiring. First-Class by Default (4) — the tensor is a reified value-level operation, composable with join/meet. Data Orientation (2) — the tensor is a pure function on type data, not embedded in elaborator control flow.

### §3.6 Phase 6: Tensor-aware elaboration

**Current state** (`typing-core.rkt:548-555`):
```racket
;; General case: infer function type, check argument
[_
 (let ([t1 (whnf (infer ctx e1))])
   (match t1
     [(expr-Pi m a b)
      (if (check ctx e2 a)
          (subst 0 e2 b)
          (expr-error))]
     [_ (expr-error)]))]  ;; ← union types hit this branch
```

**Problem**: If `t1` is an `expr-union` of Pi types (e.g., from overloading or subtype merge), it falls to `[_ (expr-error)]`. The elaborator cannot handle union-typed functions or union-typed arguments.

**Redesigned**:
```racket
[_
 (let ([t1 (whnf (infer ctx e1))])
   (cond
     ;; Direct Pi: existing fast path
     [(expr-Pi? t1)
      (if (check ctx e2 (expr-Pi-domain t1))
          (subst 0 e2 (expr-Pi-codomain t1))
          (expr-error))]
     ;; Union type: distribute via tensor
     [(expr-union? t1)
      (let ([result (type-tensor t1 (infer ctx e2))])
        (if (type-top? result)
            (expr-error)
            result))]
     [_ (expr-error)]))]
```

**Also needed**: The `check` path for unions (`typing-core.rkt:2424`). Currently `check(G, e, A | B)` speculatively checks `e : A` or `e : B`. This is correct and doesn't need changes — it already handles union types in the CHECK direction. The tensor phase handles unions in the INFER direction (function/argument types).

**Scope boundary**: This phase wires `type-tensor` into the existing imperative elaborator. It does NOT put the tensor on-network as a propagator — that's PPN Track 4. Track 2H makes the elaborator WORK with union types; Track 4 makes it work ON-NETWORK.

### §3.7 Phase 7: Per-relation property declarations

**Current state**: `sre-domain.declared-properties` is a single `(hasheq property-name → property-value)`. Properties apply to the domain's equality merge.

**Problem**: The subtype ordering has DIFFERENT algebraic properties than the equality ordering. We need per-relation declarations.

**Design**: Change `declared-properties` from a flat hash to a nested hash:

```racket
;; Current (Track 2G):
declared-properties : (hasheq property-name → property-value)

;; Redesigned (Track 2H):
declared-properties : (hasheq relation-name → (hasheq property-name → property-value))
```

Example for type domain:
```racket
(hasheq
  'equality (hasheq 'commutative-join prop-confirmed
                    'associative-join prop-confirmed
                    'idempotent-join  prop-confirmed
                    'has-meet         prop-confirmed)
  'subtype  (hasheq 'commutative-join prop-confirmed
                    'associative-join prop-confirmed
                    'idempotent-join  prop-confirmed
                    'has-meet         prop-confirmed
                    'distributive     prop-confirmed  ;; NEW — validated by inference
                    'has-pseudo-complement prop-confirmed
                    'heyting          prop-confirmed))
```

**API changes**:
- `sre-domain-has-property?` gains optional `#:relation` keyword (defaults to `'equality` for backward compat)
- `with-domain-property` and `select-by-property` gain `#:relation` keyword
- `infer-domain-properties` runs PER-RELATION (samples same domain, uses relation's merge)
- `resolve-and-report-properties` reports per-relation

**Migration**: All existing callers use the default (`'equality`) — zero breakage. New code specifies `#:relation 'subtype` when needed.

**Principle served**: Data Orientation (2). Properties are data indexed by (domain, relation) — not embedded in control flow.

### §3.6 Phase 6: Algebraic validation

Run property inference on the redesigned subtype-lattice-merge:
- **Samples**: `(expr-Nat) (expr-Int) (expr-Rat) (expr-String) (expr-Bool) (expr-Unit) (expr-Char) (expr-Keyword)` — same base types used in Track 2G, plus a few compound types for structural coverage
- **Tests**: commutativity, associativity, idempotence, distributivity (using meet = GLB)
- **Expected results**: ALL four confirmed under subtype ordering (the union-join + GLB-meet combination is distributive for ground types)
- **Implication derivation**: distributive + has-pseudo-complement → Heyting = prop-confirmed

This is the "Pre-0 property check" lesson from Track 2G — validate mathematical properties DURING design, not after implementation.

### §3.7 Phase 7: Pseudo-complement error reporting

**Pseudo-complement**: `¬a = a → ⊥ = max{x | x ⊓ a ≤ ⊥}`

For ground types under the subtype ordering with union-join + GLB-meet:
- `¬Int` in context `{Int, String, Bool}` = `String | Bool` (everything incompatible with Int)
- `¬(Int | String)` in same context = `Bool`
- `¬⊤` = `⊥`, `¬⊥` = `⊤`

**Implementation**: The pseudo-complement is computable for GROUND types with a finite working set (the types currently in scope). For the general case (with metas, with polymorphism), the pseudo-complement may not be computable — fall back to the current error format.

```racket
(define (type-pseudo-complement type context-types)
  ;; context-types: list of types currently in the working set
  ;; Returns the union of all context types incompatible with `type`
  (define incompatible
    (filter (lambda (t) (eq? type-bot (type-lattice-meet t type)))
            context-types))
  (if (null? incompatible)
      type-top
      (build-union-type-with-absorption incompatible)))
```

**Consumer**: In `typing-errors.rkt` or at the error reporting site, when a type contradiction is found (cell reaches type-top), compute the pseudo-complement of the conflicting constraint against the other constraints. This produces:
- WHICH types conflict (the two constraints that produced top)
- WHAT alternatives remain (the pseudo-complement)
- WHY they conflict (the meet that produced ⊥)

**Principle served**: Progressive Disclosure (8). Simple errors show simple messages. The pseudo-complement is available for advanced diagnostics without cluttering basic output.

---

## §4 NTT Model

The NTT (speculative syntax) model for key constructs:

```
-- Union type as subtype join
lattice TypeLattice
  :carrier Type
  :bot     type-bot
  :top     type-top

  -- Equality relation (unchanged)
  relation equality
    :merge [a b -> (try-unify-pure a b) | type-top]
    :properties {commutative associative idempotent has-meet}

  -- Subtype relation (REDESIGNED)
  relation subtype
    :merge [a b ->
      | a = b        -> a
      | a <: b       -> b
      | b <: a       -> a
      | has-meta? a  -> b
      | has-meta? b  -> a
      | otherwise    -> (union-join a b)]  -- NOT type-top
    :meet [a b ->
      | a = b        -> a
      | a <: b       -> a     -- GLB of comparable = lesser
      | b <: a       -> b
      | same-ctor?   -> (component-wise-meet a b)  -- ring action
      | otherwise    -> type-bot]
    :properties {commutative associative idempotent distributive
                 has-meet has-pseudo-complement heyting}

-- Union join with subtype absorption
def union-join [a b : Type] -> Type
  := |> [a b]
        flatten-union
        sort-canonical
        dedup
        absorb-subtypes     -- NEW: remove components that are subtypes of others
        fold-right expr-union

-- Meet via ring action (generic, descriptor-driven)
def generic-meet [a b : Type] -> Type
  := match (ctor-tag a) (ctor-tag b)
     | same-tag -> component-wise with ring-action:
                    covariant    -> meet
                    contravariant -> join
                    invariant    -> equality-or-bot
                    phantom      -> erased
     | diff-tag -> type-bot

-- Tensor (⊗): function application as quantale multiplication
def type-tensor [f : Type, a : Type] -> Type
  := match f a
     | (Pi dom cod) a  -> if a <: dom then cod[a] else type-top
     | (union fs)   a  -> union-join (map [fi -> type-tensor fi a] fs)  -- left-distribute
     | f  (union as)   -> union-join (map [ai -> type-tensor f ai] as)  -- right-distribute
     | bot _           -> bot                                            -- annihilation
     | _ bot           -> bot

-- Pseudo-complement (Heyting implication to ⊥)
def pseudo-complement [a : Type, ctx : (List Type)] -> Type
  := union-join (filter [t -> meet(t, a) = bot] ctx)
```

### NTT Correspondence Table

| NTT Construct | Racket Implementation | File |
|---------------|----------------------|------|
| `relation subtype :merge` | `subtype-lattice-merge` | subtype-predicate.rkt |
| `relation subtype :meet` | `type-lattice-meet` (extended) | type-lattice.rkt |
| `union-join` | `build-union-type-with-absorption` | union-types.rkt (NEW) |
| `flatten-union` | `flatten-union` | union-types.rkt (extracted) |
| `absorb-subtypes` | `absorb-subtype-components` | union-types.rkt (NEW) |
| `generic-meet` | `generic-meet` (NEW, mirrors generic-merge) | type-lattice.rkt |
| `type-tensor` | `type-tensor` (NEW) | type-lattice.rkt |
| `infer expr-app union` | `expr-app` case with union dispatch | typing-core.rkt |
| `pseudo-complement` | `type-pseudo-complement` | type-lattice.rkt or typing-errors.rkt |
| `relation.properties` | `declared-properties` nested hash | sre-core.rkt |
| `has-property? :relation` | `sre-domain-has-property?` with #:relation | sre-core.rkt |

---

## §5 Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Union type proliferation (cells accumulate large union types) | Medium | Subtype absorption limits growth. Monitor union component count in Pre-0 benchmarks. |
| Subtype absorption cost (O(n^2) per union build) | Low | Typical unions have 2-5 components. Pathological unions indicate design problems. |
| Meta variables in unions (`?A | Int`) | Medium | Conservative: treat unsolved metas as in type-lattice-merge. Don't build unions containing metas. |
| Per-relation property change breaks existing callers | Low | Default `#:relation 'equality` preserves all existing behavior. |
| Pseudo-complement computation on non-ground types | Medium | Fall back to standard error format when metas/binders present. |
| `union-types.rkt` extraction breaks compilation order | Low | Module depends only on syntax.rkt. Add to dep-graph.rkt immediately. |

---

## §6 Dependencies

**Depends on (all met)**:
- Track 2G ✅: property inference, declared-properties field, has-property? API, meet operations, ring action
- Track 2F 🔄: merge-registry, relation-level properties, variance table
- Track 1/1B ✅: subtype?, structural subtype check, subtype-lattice-merge
- ctor-registry ✅: generic-merge pattern, ctor-desc with component-variances

**Depended on by**:
- PPN Track 4: elaboration on network (BLOCKED on Track 2H — needs well-structured type lattice)
- SRE Track 3: trait resolution (benefits from Heyting properties, not blocked)

---

## §7 Test Strategy

**Phase 0**: Pre-0 benchmarks + property checks
- Benchmark `subtype-lattice-merge` on incomparable types (current: produces type-top, fast)
- Benchmark `build-union-type` ACI normalization (existing, measure baseline)
- Property check: manually verify distributivity on sample triples BEFORE implementation
- **Semiring validation**: verify tensor (function application) distributes over union-join on sample types — `f(A | B) = f(A) | f(B)` for concrete f, A, B. This validates the quantale structure that PPN Track 4 depends on (§10).

**Per-phase**: Targeted tests for each phase's deliverable. Shared fixture pattern for new test file.

**Phase 8**: Full suite GREEN + A/B benchmark comparing:
- Pre-Track-2H baseline (from timings.jsonl)
- Post-Track-2H performance
- Focus: any regression in subtype checking or union type paths

**Acceptance file**: `examples/2026-04-02-sre-track2h.prologos` exercising:
- Union type formation in type annotations
- Mixed-type maps (existing, regression check)
- Pattern matching on union types (existing, regression check)
- Subtype absorption visible in inferred types

---

## §8 WS Impact

Track 2H does NOT add or modify user-facing syntax. Union types (`<Int | String>`) already exist in the WS surface. The change is internal: the type lattice produces union types where it previously produced type-top. Users will see BETTER type inference (union types instead of errors for incomparable constraint merges) and BETTER error messages (pseudo-complement information).

No preparse changes. No reader changes. No parser changes.

---

## §10 Semiring Structure: Scope Boundary and Forward Reference

### The Type Lattice as Quantale

The [Lattice Foundations research](../research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md) §2.4 establishes that the type lattice is a **quantale** — a complete lattice that is simultaneously a semiring:

- **Addition (⊕)**: union-join — `Int ⊕ String = Int | String`. Track 2H delivers this.
- **Multiplication (⊗)**: function type application — `(A → B) ⊗ A = B`. This is PPN Track 4 scope.

The key semiring axiom is **distributivity of tensor over join**:

```
a ⊗ (b ⊕ c) = (a ⊗ b) ⊕ (a ⊗ c)
```

In type terms: applying a function to a union distributes across components:

```
(A → B) applied to (C | D) = ((A → B) applied to C) | ((A → B) applied to D)
```

This is the theoretical basis for "type inference as parsing" — elaboration IS parsing in the type-lattice semiring (§2.4: "The resulting 'parse' doesn't produce trees — it produces types"). When elaboration goes on-network (PPN Track 4), the tensor becomes a propagator: given cells for f's type and arg's type, write result's type. The propagator IS the tensor.

### What Track 2H delivers

Track 2H delivers BOTH halves of the quantale:
- **⊕ (union-join)**: Phases 2-3. Subtype-aware join producing union types with absorption.
- **⊗ (tensor)**: Phases 5-6. Reified function application as a pure lattice operation (`type-tensor`), wired into the elaborator for union-typed functions and arguments.

Track 2H's tensor is a **pure function** — it takes types as data, returns types as data. It is not yet a propagator on the network. This is the correct intermediate step: the algebraic operation must exist and be validated before it can be wired as a propagator.

### What PPN Track 4 picks up

Track 4 takes the reified `type-tensor` and makes it a **propagator**: given cells for f's type and arg's type, a function-application propagator writes result's type. The propagator IS the tensor wired into the network.

Track 4's design should:
1. Wire `type-tensor` as a propagator fire function (cell reads → type-tensor → cell write)
2. Connect to the 6-domain reduced product architecture from the Lattice Foundations research
3. Design the parse-to-type and type-to-parse Galois bridges that make "type inference as parsing" concrete
4. The semiring axioms are already validated by Track 2H — Track 4 inherits them

---

## §11 Cross-References

- **Track 2G PIR §14** (L3): "Algebraic properties are per-ordering, not per-carrier." — This is the core motivation for per-relation property declarations.
- **Track 2G PIR §12**: "Pre-0 property check for algebraic tracks." — Phase 0 includes property checks.
- **Track 2G PIR §15**: "The RIGHT primary ordering is subtyping." — Track 2H implements this.
- **Algebraic Embeddings §2.4**: Heyting algebra → pseudo-complement error reporting.
- **Algebraic Embeddings §7.1**: "Is our type lattice a Heyting algebra?" — Track 2H answers this question.
- **SRE Master Track 2H row**: Scope description matches this design.
