# SRE Track 2H — Stage 2 Audit: Type Lattice Redesign

**Date**: 2026-04-02
**Scope**: Type lattice merge/meet/join under equality and subtype orderings; union type infrastructure; SRE domain registration and algebraic properties.

**Motivation**: Track 2G's property inference found the type lattice is NOT distributive under equality merge (flat lattice with >2 incomparable atoms → distributive = prop-contradicted). The subtype-lattice-merge produces type-top for incomparable types instead of union types. This means the type lattice is NOT Heyting, NOT Boolean — foreclosing pseudo-complement error reporting and backward propagation.

---

## §1. type-lattice.rkt Internals

**File**: `racket/prologos/type-lattice.rkt` (448 lines)

### Sentinel values
- `type-bot` = `'type-bot` — no information (⊥)
- `type-top` = `'type-top` — contradiction (⊤)

### type-lattice-merge (join under equality)

```
type-lattice-merge(v1, v2):
  bot? v1 → v2   (identity)
  bot? v2 → v1
  top? v1 → top  (absorbing)
  top? v2 → top
  eq/equal → v1  (idempotent)
  else → try-unify-pure(v1, v2)
    success → result
    has-unsolved-meta → keep concrete side
    else → type-top  ← THE PROBLEM
```

**Critical observation**: When `Nat` and `String` are written to the same cell, merge returns `type-top`. This is the **flat lattice** behavior — incomparable elements go directly to top. There is no intermediate join (union type) between atoms.

**Algebraic properties declared (in unify.rkt type-sre-domain)**:
- `commutative-join`: prop-confirmed ✅
- `associative-join`: prop-confirmed ✅
- `idempotent-join`: prop-confirmed ✅
- `has-meet`: prop-confirmed ✅
- `distributive`: **NOT declared** — inference refutes it

### type-lattice-meet (GLB under equality)

```
type-lattice-meet(v1, v2):
  top? → other  (identity for meet)
  bot? → bot    (annihilator)
  eq/equal → v1
  has-unsolved-meta → bot (conservative)
  else → try-intersect-pure(v1, v2) or bot
```

**Structural coverage in try-intersect-pure**: Pi (with ring action: mult=invariant, domain=contravariant, codomain=covariant), Sigma (both covariant). **Missing**: app, Eq, Vec, Fin, Map, Set, PVec, suc, pair, union, tycon — all return `#f` → `type-bot`.

### try-unify-pure (pure structural unification)

Pure (no side effects). 448 lines including union helpers. Handles:
- Meta following via `current-lattice-meta-solution-fn` (read-only callback)
- Pi/Sigma with binder opening (gensym fresh fvar)
- Generic descriptor-driven merge via ctor-registry (PUnify Phase 1) for non-binder constructors
- Union-vs-union pairwise component unification

**Duplication**: `flatten-union-pure`, `union-sort-key-pure`, `dedup-union-components-pure` duplicate corresponding functions in unify.rkt. The duplication exists because type-lattice.rkt cannot import unify.rkt (which depends on metavar-store.rkt).

---

## §2. subtype-predicate.rkt

**File**: `racket/prologos/subtype-predicate.rkt` (226 lines)

### subtype? — the flat subtype check

Three-tier dispatch:
1. `equal?` — trivially subtype
2. `flat-subtype?` — 9 hardcoded edges + registry lookup
   - Nat <: Int <: Rat (3 edges)
   - Posit8 <: Posit16 <: Posit32 <: Posit64 (6 edges)
   - Library-defined via `subtype-pair?` registry
3. `sre-structural-subtype-check` — for compound types (both must be compound)
   - Uses `structural-subtype-ground?` — direct recursive check with variance awareness
   - Zero allocation, O(structure depth)

### subtype-lattice-merge — join under subtype ordering

```
subtype-lattice-merge(a, b):
  equal? → a
  subtype?(a, b) → b   (a ≤ b → join = b)
  subtype?(b, a) → a
  else → type-top  ← ALSO THE PROBLEM
```

**Critical observation**: When `Int` and `String` are written (incomparable under subtyping), the result is `type-top`, not `Int | String`. The subtype ordering has a well-defined join for chains (Nat ⊔ Int = Int) but no join for incomparable types. A lattice requires joins for ALL pairs — this is not a lattice but a forest of chains under a common top.

### type-sre-domain-for-subtype

A separate sre-domain used by the structural subtype checker. Has its own merge-registry but delegates to the same merge functions. Has `(hasheq)` for both property-cell-ids and declared-properties — no algebraic properties declared for this domain instance.

---

## §3. Union Type Infrastructure (existing)

### AST: `expr-union` (syntax.rkt:970)
```racket
(struct expr-union (left right) #:transparent)
```
Right-associated binary tree. No constraints on components (can nest).

### build-union-type (unify.rkt:843)
Flatten → sort by `union-sort-key` → dedup → right-fold to `expr-union` chain. ACI normalization (associative, commutative, idempotent) — canonical form.

### flatten-union (unify.rkt:766)
Recursive flatten: `(union (union A B) C) → (A B C)`.

### Pipeline coverage
- **reduction.rkt**: `expr-union` → identity (line 3082), nf → recursive (line 3627)
- **zonk.rkt**: all 3 zonk functions handle recursively (lines 456, 909, 1329)
- **substitution.rkt**: traverses both sides
- **pretty-print.rkt**: renders as `A | B`
- **typing-core.rkt**:
  - Union formation: `A | B : Type(max(level(A), level(B)))` (line 459)
  - Union checking: speculative rollback — `check(G, e, A | B)` succeeds if `e : A` or `e : B` (line 2424)
  - Map value widening: `build-union-type` used for mixed-type map values (line 1203)
  - Map get on union: extracts Map components from union, returns union of value types (line 1269)

### Current usage
Union types are **only created by map value widening** (`typing-core.rkt` lines 1196-1203, 1286, 1299-1319). They are NOT produced by the type lattice merge — that produces `type-top`. This is the gap Track 2H must close.

---

## §4. SRE Integration Points

### type-sre-domain (unify.rkt:77)
The primary type domain registered with `register-domain!`:
```racket
(sre-domain 'type
  type-merge-registry       ; 'equality → type-lattice-merge, 'subtype → subtype-lattice-merge
  type-lattice-contradicts?
  type-bot?
  type-bot
  type-top
  expr-meta?
  (lambda (expr) ...)       ; meta-resolver via current-structural-meta-lookup
  #f                        ; no dual-pairs
  (hasheq)                  ; property-cell-ids (empty)
  (hasheq 'commutative-join prop-confirmed
          'associative-join prop-confirmed
          'idempotent-join  prop-confirmed
          'has-meet         prop-confirmed))
```

### SRE relations available
5 relations defined in sre-core.rkt:
1. `sre-equality` — identity endomorphism
2. `sre-subtype` — monotone (order-preserving)
3. `sre-subtype-reverse` — flipped monotone
4. `sre-duality` — antitone involution
5. `sre-phantom` — zero endomorphism (erased)

The merge-registry maps relation-name → merge-fn. Currently:
- `'equality` → `type-lattice-merge` (flat merge → top for incomparable)
- `'subtype` → `subtype-lattice-merge` (chain merge → top for incomparable)
- `'subtype-reverse` → `subtype-lattice-merge`

### ctor-registry variance declarations
13 type constructors registered with component variances:
- Pi: `(= - +)` (mult=invariant, domain=contravariant, codomain=covariant)
- Sigma: `(+ +)`
- app: `(= +)` (but app is covariant in arg, invariant in func — this needs audit)
- Eq: `(= = =)`
- Vec: `(= +)`
- Fin: `(=)`
- Map: `(= +)` (key=invariant, value=covariant — correct for immutable maps)
- PVec: `(+)`
- Set: `(+)`
- pair: `(+ +)`
- suc: `(=)`
- lam: `(= - +)` (binder-depth 1, handled specially)

### Track 2G property inference
`infer-domain-properties` in sre-core.rkt tests: commutativity, associativity, idempotence, distributivity. For the type domain under equality:
- **Distributive**: REFUTED (flat lattice with >2 atoms)
- **Heyting**: REFUTED (implication: distributive ∧ has-pseudo-complement → Heyting; distributive is refuted)
- **Boolean**: REFUTED (implication: Heyting ∧ has-complement → Boolean; Heyting is refuted)

---

## §5. Per-Relation Properties (the key design gap)

**Current state**: Properties are declared per-domain, not per-relation. The type domain has ONE set of declared properties that apply to the equality merge.

**The problem**: Under the **subtype ordering**, the lattice has more structure. `Nat ⊔_subtype Int = Int` (not top). The subtype lattice IS a join-semilattice for comparable types — but NOT for incomparable types under the current implementation.

**What Track 2H must deliver for subtype ordering**:
- **Join(incomparable types) = union type**: `Int ⊔_subtype String = Int | String`
- **Meet(comparable types) = GLB**: `Int ⊓_subtype Nat = Nat`
- **Meet(incomparable types)** = type-bot (correct, no common lower bound for `Int` and `String`)
- **Per-relation property declarations**: So the subtype ordering can declare `distributive = prop-confirmed` independently of the equality ordering

**Algebraic target for subtype ordering**:
- Commutative: ✅ (ACI union normalization guarantees)
- Associative: ✅ (right-fold union construction)
- Idempotent: ✅ (dedup in build-union-type)
- Distributive: **TARGET** — must be validated. Union types + subtype-aware meet SHOULD be distributive: `a ⊓ (b ⊔ c) = (a ⊓ b) ⊔ (a ⊓ c)` where ⊔ is union-join and ⊓ is GLB-meet.
- Has-pseudo-complement: **TARGET** — if distributive, pseudo-complement a→b exists in Heyting algebra
- Heyting: **TARGET** — if distributive + has-pseudo-complement

---

## §6. Duplication Inventory

| Function | type-lattice.rkt | unify.rkt |
|----------|-----------------|-----------|
| `flatten-union` | `flatten-union-pure` (line 387) | `flatten-union` (line 766) |
| `union-sort-key` | `union-sort-key-pure` (line 396) | `union-sort-key` (line 774) |
| `dedup-union-components` | `dedup-union-components-pure` (line 421) | `dedup-union-components` (line 829) |

The duplication exists because type-lattice.rkt cannot depend on unify.rkt (which requires metavar-store.rkt). Track 2H should either:
1. Extract union helpers into a standalone module (e.g., `union-types.rkt`)
2. Or accept the duplication with a cross-reference

**Drift risk**: The unify.rkt version has more sort key entries (Posit types, logic engine types, etc.) than the type-lattice.rkt version. They WILL drift further.

---

## §7. Test Coverage

| Test File | Lines | Covers |
|-----------|-------|--------|
| test-type-lattice.rkt | 291 | Merge (join), contradiction, pure unification, propagator integration |
| test-sre-algebraic.rkt | 240 | Property inference, distributive refutation, implication rules, gating |
| test-sre-subtype.rkt | 192 | Structural subtype check, variance-aware decomposition |
| test-union-types.rkt | 264 | Union formation, flatten, speculative checking |
| test-mixed-map.rkt | 276 | build-union-type, map value widening |

**Coverage gaps for Track 2H**:
- No tests for subtype-ordering join producing union types (doesn't exist yet)
- No tests for subtype-aware meet (only equality meet tested, and only for Pi/Sigma)
- No tests for distributivity under subtype ordering
- No tests for per-relation property declarations
- No tests for pseudo-complement computation

---

## §8. Performance Profile

From PPN Track 3 Pre-0 benchmarks:
- Type-checking (infer/check): ~18% of pipeline wall time
- Unification: ~12% of pipeline wall time
- Merge (type-lattice-merge): called on every cell write — must remain O(1) for atoms

**Concern for Track 2H**: If subtype-lattice-merge produces union types instead of type-top for incomparable types, it creates `expr-union` nodes. These are more expensive to compare (`equal?` on union trees) and to merge (flatten + sort + dedup + fold). However:
1. Incomparable types are RARE in well-typed programs (type errors are the exception)
2. The existing `build-union-type` ACI normalization is already battle-tested on map value widening
3. Most merges will hit the fast paths (bot, equal, compatible)

---

## §9. Algebraic Verification Targets

Track 2H must validate with property inference:

### Under equality ordering (existing, no change expected)
- Commutative: prop-confirmed ✅
- Associative: prop-confirmed ✅
- Idempotent: prop-confirmed ✅
- Distributive: prop-contradicted (remains flat for equality)

### Under subtype ordering (NEW — the deliverable)
- Commutative: TARGET prop-confirmed (union ACI normalization)
- Associative: TARGET prop-confirmed
- Idempotent: TARGET prop-confirmed (dedup)
- Distributive: TARGET prop-confirmed (the key algebraic property)
- Has-pseudo-complement: TARGET prop-confirmed (Heyting)
- Heyting: TARGET prop-confirmed (distributive + pseudo-complement)

### Potential complications
1. **Subtype transitivity with union**: Does `Nat ⊔_subtype (Int | String) = Int | String`? (Yes — Nat <: Int, so Nat absorbed into Int component)
2. **Meet distributes over union-join**: `Nat ⊓ (Int | String) = (Nat ⊓ Int) | (Nat ⊓ String) = Nat | ⊥ = Nat`. Is this correct? Yes — Nat <: Int so GLB = Nat; Nat and String incomparable so GLB = ⊥.
3. **Meta variables in unions**: How does `?A | Int` merge with `Nat | String`? Conservative treatment (like current has-unsolved-meta handling) may be needed.

---

## §10. Key Files for Track 2H

| File | Lines | Role | Expected Changes |
|------|-------|------|-----------------|
| type-lattice.rkt | 448 | Merge (join), meet, pure unification | subtype-aware join → union types; extend try-intersect-pure coverage |
| subtype-predicate.rkt | 226 | subtype?, subtype-lattice-merge | Rewrite subtype-lattice-merge to produce union types |
| unify.rkt | ~900 | Full unification, type-sre-domain | Per-relation property declarations; possibly extract union helpers |
| sre-core.rkt | 1249 | Domain/relation infrastructure | Per-relation property cell support (Pocket Universe?) |
| typing-core.rkt | ~2800 | Type inference | Union type handling may need adjustment for inference |
| ctor-registry.rkt | ~700 | Constructor descriptors | No changes expected |

---

## §11. Cross-References

- **Track 2G PIR**: Found type lattice NOT distributive → motivated this track
- **PPN Track 4**: Needs well-structured type lattice (prerequisite)
- **SRE Track 3** (Trait Resolution): Benefits from Heyting properties for resolution strategy
- **Research**: [Algebraic Embeddings on Lattices](../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) — Heyting algebra enables pseudo-complement error reporting
- **Research**: [Module Theory on Lattices](../research/2026-03-28_MODULE_THEORY_LATTICES.md) — per-relation properties as sub-rings
- **Research**: [Lattice Foundations for PPN](../research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md) — lattice theory foundations
