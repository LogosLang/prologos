# CIU Track 0: Collection Trait Hierarchy Audit

**Date**: 2026-03-21
**Scope**: Collection trait definitions, instances, sugar dispatch, generic operations
**Lens**: DESIGN_PRINCIPLES.org (Decomplection, Most Generalizable Interface, No Trait Hierarchies), ERGONOMICS.org, RELATIONAL_LANGUAGE_VISION.org
**Prior art**: [Collection Interface Audit](2026-03-20_COLLECTION_INTERFACE_AUDIT.md) (commit `e632dce`), [Collection Interface Unification Design](2026-03-20_COLLECTION_INTERFACE_UNIFICATION_DESIGN.md) (commit `e7227f2`)
**Purpose**: Deep Stage 2 audit of the trait hierarchy design space, to inform PM Track 8 and subsequent CIU Tracks 1-5. This is a *pre-Track 8* audit — findings may be revised after Track 8 changes the infrastructure landscape.

---

## 1. Inventory: What Exists

### 1.1 Trait Definitions

8 traits + 1 deftype + 1 bundle, defined in `lib/prologos/core/collection-traits.prologos`:

| Name | Kind | Arity | Methods | Purpose |
|------|------|-------|---------|---------|
| `Seqable` | trait | `{C : Type -> Type}` | `to-seq` | Convert to LSeq |
| `Buildable` | trait | `{C : Type -> Type}` | `from-seq`, `empty-coll`, `conj` | Construct from LSeq |
| `Foldable` | trait | `{C : Type -> Type}` | `fold` | Right fold |
| `Reducible` | trait | `{C : Type -> Type}` | `reduce` | Left fold |
| `Functor` | trait | `{F : Type -> Type}` | `fmap` | Structure-preserving map |
| `Indexed` | trait | `{C : Type -> Type}` | `idx-nth`, `idx-length`, `idx-update` | Positional access |
| `Keyed` | trait | `{C : Type -> Type -> Type}` | `kv-get`, `kv-assoc`, `kv-dissoc` | Key-value access |
| `Setlike` | trait | `{C : Type -> Type}` | `set-member?`, `set-insert`, `set-remove` | Set membership |
| `Seq` | **deftype** | `{S : Type -> Type}` | `first`, `rest`, `empty?` (as Sigma projections) | Universal iteration |
| `Collection` | bundle | — | — | `(Seqable, Buildable, Foldable, Reducible)` |

### 1.2 Instances by Collection Type

| Collection | Seqable | Buildable | Foldable | Reducible | Functor | Indexed | Keyed | Setlike | Seq (deftype) |
|------------|---------|-----------|----------|-----------|---------|---------|-------|---------|---------------|
| **List** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | — | ✅ |
| **PVec** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | — | ❌ |
| **LSeq** | ✅ | ✅ | ✅ | ✅ | — | — | — | — | ✅ |
| **Set** | ✅ | ✅ | ✅ | ✅ | — | — | — | ✅ | ❌ |
| **Map** | — | — | — | — | — | — | ✅ | — | ❌ |

### 1.3 Instance Mechanism

**Finding I-1: No HKT trait uses `impl` syntax.** All 8 collection traits use manual `def C--Trait--dict` construction. The `impl` keyword works for non-HKT traits (Eq, Ord, Hashable, etc.) but not for HKT traits like `Seqable {C : Type -> Type}`. This means:
- Collection trait instances are not registered in the trait resolution system
- The elaborator cannot auto-resolve `Seqable PVec` — the dict must be passed explicitly
- The `--dict` naming convention is an ad-hoc protocol, not enforced by the compiler

### 1.4 Sugar Dispatch Sites

| Sugar | Elaboration | Typing | Reduction |
|-------|-------------|--------|-----------|
| `xs[0]` (postfix index) | `surf-get` → `expr-get` (no trait constraint) | Hardcodes PVec, Map, List, Schema, Selection | Pattern-matches `expr-champ`, `expr-rrb`, cons-chain |
| `m.field` (dot-access) | `surf-get` → `expr-get` (no trait constraint) | Hardcodes Map, Schema, Selection | Delegates to `expr-map-get` |
| `xs.*field` (broadcast) | `surf-broadcast-get` → `expr-broadcast-get` (no trait constraint) | Returns fresh meta (deferred) | Walks cons/nil only — PVec/Set produce stuck terms |
| `get-in` (path access) | Static: inlined `expr-map-get` chain; Dynamic: `expr-get-in` | Map-only | Hardcoded `expr-map-get` per segment |

### 1.5 Generic Operations Pipeline

| Operation | Dispatch Mechanism | Intermediary |
|-----------|--------------------|-------------|
| `gmap` | Seqable → LSeq → Buildable | LSeq (mandatory intermediary) |
| `gfilter` | Seqable → LSeq → Buildable | LSeq (mandatory intermediary) |
| `gfold` | Foldable (direct dispatch) | **None** — dict IS the fold |
| `gconcat` | Seqable → LSeq → Buildable | LSeq |
| `glength` | Seqable → LSeq | LSeq |
| `gany?` / `gall?` | Foldable (direct dispatch) | **None** |
| `gto-list` | Seqable → LSeq | LSeq |

---

## 2. Findings Against Principles

### F-1: Seqable/Buildable Are LSeq-Coupled (Violates Decomplection)

**Principle**: "Collection abstractions are decoupled from their concrete backends" (DESIGN_PRINCIPLES §Decomplection).

**Violation**: `Seqable.to-seq` returns `LSeq A`. `Buildable.from-seq` takes `LSeq A`. The universal iteration protocol is hardwired to a specific lazy sequence implementation. Any collection that wants to participate in `gmap`/`gfilter`/`gconcat`/`glength` must convert to and from LSeq.

This makes LSeq the mandatory intermediary — the exact anti-pattern that the Seq-with-efficient-dispatch principle was designed to eliminate.

**Impact**: PVec → LSeq → PVec roundtrip for `gmap`. PVec has native `pvec-map` (via `Functor pvec-functor`), but `gmap` doesn't use it. The Functor instance exists but the generic operation doesn't dispatch through it.

### F-2: Seq Is a deftype, Not a Trait (Limits Composability)

**Principle**: "Traits over concrete types" (DESIGN_PRINCIPLES §Most Generalizable Interface).

**Observation**: `Seq` is defined as `deftype [Seq $S] [Sigma ...]` — a type alias for a Sigma (product) of three functions. It is not a trait. This means:
- No `impl Seq PVec` is possible — you construct a `Seq` dict manually
- The trait resolution system cannot auto-resolve Seq instances
- Seq dicts must be passed explicitly at every call site

This is not necessarily wrong — Sigma-encoded dicts are a valid representation. But it means `Seq` operates outside the trait dispatch system entirely. If the goal is for sugar to generate `Seq` constraints that resolve on the propagator network, `Seq` needs to be resolvable *as a trait*.

**Design space**: Either (a) make `Seq` a trait (3-method, like `Indexed`), or (b) create a `Seqable2` trait whose method returns a `Seq` dict (analogous to Clojure's `ISeq` returning a seq view). Option (a) is simpler; option (b) preserves the Sigma encoding.

### F-3: PVec, Set, Map Lack Seq Instances (Gaps in Universal Protocol)

**Principle**: "Every collection type implements Seq with native, efficient operations" (DESIGN_PRINCIPLES §Most Generalizable Interface).

**Violation**: Only List and LSeq have Seq dicts. PVec, Set, and Map do not. This means:
- `seq-length`, `seq-drop`, `seq-any?`, `seq-find` (which dispatch through Seq) cannot operate on PVec, Set, or Map
- The "universal iteration protocol" is universal for List/LSeq only

**Mitigation difficulty**: PVec could implement `Seq` straightforwardly (first = rrb-get 0, rest = rrb-drop 1, empty? = rrb-count = 0). Set iteration requires choosing an enumeration order. Map iteration requires choosing between keys, values, or entries (MapEntry).

### F-4: Indexed/Keyed Exist But Sugar Doesn't Use Them (Dead Abstraction)

**Principle**: "Adding a new backend requires only implementing the trait interface" (DESIGN_PRINCIPLES §Decomplection).

**Violation**: A user-defined collection type that implements `Indexed` gets `idx-nth` for free in library code — but `xs[0]` sugar still fails, because `expr-get` pattern-matches on `expr-rrb` (PVec) and cons-chain (List), not on `Indexed` dispatch. The trait exists but the language's primary access syntax doesn't use it.

This is the core finding from the earlier Collection Interface Audit (2026-03-20), restated here against the specific trait.

### F-5: Map Is an Island (Trait Coverage Gap)

**Observation**: Map has only `Keyed` — it lacks Seqable, Buildable, Foldable, Reducible, Functor, and Seq. This means:
- `gmap` cannot operate on Map
- `gfold` cannot fold over Map entries
- Map cannot participate in any generic collection operation

Map has Racket-side operations (`map-fold`, `map-map-values`, `map-filter`) that could back trait instances, but no Prologos-level trait instances exist. The `map-seq`/`map-from-seq` bridge functions exist but aren't wired into Seqable/Buildable.

This is likely because Map is `Type -> Type -> Type` (two type parameters), while Seqable/Buildable/Foldable are all `{C : Type -> Type}`. The HKT partial application needed (`Map K` as a `Type -> Type` constructor for a given `K`) isn't supported.

### F-6: `impl` Doesn't Work for HKT Traits (Infrastructure Gap)

**Observation**: The `impl` keyword syntax works for non-HKT traits (`impl Eq Nat`, `impl Hashable String`) but not for HKT traits like `Seqable {C : Type -> Type}`. All HKT instances are manual `def` dict constructions with a naming convention (`C--Trait--dict`).

**Impact**: HKT trait instances cannot be resolved by the trait resolution system. The elaborator's `resolve-trait-constraints!` can find `impl Eq Nat` but not `Seqable List`. This is why generic ops require explicit dict parameters (`$seq`, `$build`, `$foldable`) instead of implicit resolution.

**This is the fundamental infrastructure gap.** Until `impl` works for HKT traits, or an equivalent registration mechanism exists, collection trait dispatch cannot be automatic.

### F-7: Broadcast Only Works on List (Violates Decomplection)

**Principle**: "Collection abstractions are decoupled from their concrete backends" (DESIGN_PRINCIPLES §Decomplection).

**Violation**: `expr-broadcast-get` in reduction.rkt walks only cons/nil structure (checking fvar names "nil", "cons"). PVec and Set produce stuck terms. The broadcast sugar `xs.*field` is hardcoded to List's concrete representation.

### F-8: Collection Bundle Is LSeq-Centric

**Observation**: `bundle Collection := (Seqable, Buildable, Foldable, Reducible)`. This bundle includes Seqable and Buildable, which are LSeq-coupled (F-1). A type satisfying `Collection` must convert to/from LSeq. If Seqable/Buildable are redesigned around Seq (F-1/F-2), the bundle definition changes accordingly.

---

## 3. Trait Hierarchy Design Space

### 3.1 The Core Question

The current hierarchy has two iteration paths:
- **Seq path**: `first`/`rest`/`empty?` — element-at-a-time, universal, currently a deftype
- **LSeq path**: `to-seq`/`from-seq` — lazy conversion, currently the trait-based path

The design question is: **which path should be primary?**

### 3.2 Option A: Seq Becomes the Primary Trait

Replace `Seqable` with `Seq` as a trait:

```
trait Seq {S : Type -> Type}
  first  : S A -> Option A
  rest   : S A -> S A
  empty? : S A -> Bool
```

Every collection implements `Seq` natively. `gmap`/`gfilter` dispatch through `Seq` + `Buildable` (without LSeq intermediary). `Seqable` is deprecated or becomes a compatibility shim.

**Pros**: Clean, direct, no intermediary. Every collection has efficient native iteration.
**Cons**: Seq is inherently sequential (first/rest). Collections with better-than-linear iteration (PVec's O(1) random access, Set's hash iteration) are forced through a sequential interface. `gfold` with `Foldable` is already more efficient than Seq iteration for fold-like operations.

### 3.3 Option B: Functor as Primary Map, Seq as Fallback

```
gmap dispatches through:
  1. Functor (if available) — native structure-preserving map
  2. Seq + Buildable (fallback) — iterate/reconstruct
```

**Pros**: PVec gets native `pvec-map` via Functor; List gets native `map`. No unnecessary Seq iteration for structure-preserving operations.
**Cons**: Two dispatch paths. Type must implement Functor OR (Seq + Buildable) for gmap to work. Adds complexity to the dispatch logic.

### 3.4 Option C: Redesign Seqable Around Seq (Not LSeq)

Keep Seqable as a trait but change its return type:

```
trait Seqable {C : Type -> Type}
  to-seq : C A -> ??? A    -- what is the return type?
```

The problem: if `to-seq` returns `Seq C` (the dict), it's not a conversion — it's a dict accessor. If it returns some concrete sequence type, we're back to an intermediary. The value of Seqable is "convert this opaque collection to something iterable." With Seq-as-trait, the collection IS iterable — no conversion needed.

**Assessment**: Option C collapses into Option A. If every collection implements Seq directly, Seqable adds no value.

### 3.5 Recommended Direction

**Option A (Seq as primary trait) + Functor for structure-preserving map**, with the following hierarchy:

| Trait | Purpose | Used By |
|-------|---------|---------|
| `Seq` | Universal iteration (first/rest/empty?) | broadcast, seq-* ops, gmap fallback |
| `Functor` | Structure-preserving map (A→B, F A → F B) | gmap (primary path) |
| `Foldable` | Right fold (already works well) | gfold, gany?, gall? |
| `Reducible` | Left fold | reduce operations |
| `Indexed` | Positional access | `xs[0]` sugar |
| `Keyed` | Key-value access | `m.field`, `m[key]` sugar |
| `Setlike` | Membership/insert/remove | set operations |
| `Buildable` | Construction from iteration | gmap result, gfilter result, gconcat |

**Changes from current**:
- `Seqable` deprecated → replaced by `Seq` trait
- `Seq` promoted from deftype to trait (with `impl` support)
- `Buildable.from-seq` takes `Seq` iteration, not `LSeq`
- `LSeq` implements `Seq` (and remains a collection type, just not the hub)
- `Collection` bundle redefined: `(Seq, Buildable, Foldable, Reducible)`

---

## 4. What Track 8 Needs to Provide

### 4.1 HKT `impl` Support (Critical)

The `impl` keyword must work for HKT traits — `impl Seq List`, `impl Indexed PVec`, `impl Keyed Map`. Without this, collection trait instances remain manual `def` constructions outside the resolution system. This is the single most important infrastructure gap.

**What this requires from Track 8**:
- Trait resolution must handle type constructor arguments (not just concrete types)
- Dict meta cells must be created and resolved for HKT constraints
- The readiness propagator infrastructure (Track 7) already handles ground-type resolution; it needs to handle constructor-type resolution

### 4.2 Constraint Generation from Sugar Sites

`surf-get` must be able to generate `Indexed C` or `Keyed C K V` constraints that enter the propagator network. This requires:
- The elaborator can emit trait constraints at `surf-get` elaboration time
- The constraint flows through the existing readiness/resolution propagator pipeline
- The resolved dict reaches the dispatch site (either as a meta solution or as a direct parameter)

**What this requires from Track 8**:
- Callback elimination (§5.2 of Track 8 audit): `surf-get` needs to call trait resolution directly, not through callback indirection
- Module restructuring (§5.2.3): `elaborator.rkt` needs to reference `trait-resolution.rkt` functions without circular imports

### 4.3 Map Partial Application (Nice to Have)

For Map to implement `Foldable`, `Seq`, etc., the type system needs `Map K` as a `Type -> Type` constructor (fixing K, varying V). This is HKT partial application — a known gap (listed in DEFERRED.md under "HKT Partial Application for Map Trait Instances").

This is not strictly required for Track 8 — Map can be handled specially in the short term. But it's the principled solution.

---

## 5. Questions for Post-Track 8 Revisit

These questions cannot be fully answered until Track 8 delivers:

1. **Does HKT `impl` resolution work through the propagator network?** If yes, CIU Track 1 can define `impl Seq PVec` and have it resolve automatically. If no, manual dict construction persists.

2. **Can `surf-get` generate deferred trait constraints?** When the collection type is an unsolved meta, can a constraint be generated that waits for the type to become ground? Track 7's readiness propagators handle this for type-level constraints — does it extend to sugar-generated constraints?

3. **How does Buildable interact with Seq-based iteration?** `Buildable.from-seq` currently takes `LSeq A`. If `Seq` becomes a trait, `from-seq` needs to take a `Seq S => S A` (a Seq-implementing collection). The type signature becomes `from-seq : {S : Type -> Type} -> [Seq S] -> S A -> C A`, which is a rank-2 constraint. Can the trait system handle this?

4. **What is the performance profile of trait-dispatched vs. hardcoded dispatch?** The current hardcoded `expr-get` pattern-matching is O(1) — it checks the constructor tag. Trait dispatch adds dict resolution overhead. Is this measurable? The allocation efficiency work (BSP-LE Track 0) may need to account for this.

---

## 6. Summary of Findings

| # | Finding | Severity | Principle Violated | CIU Track |
|---|---------|----------|--------------------|-----------|
| F-1 | Seqable/Buildable hardwired to LSeq | High | Decomplection | Track 1 |
| F-2 | Seq is deftype not trait (no auto-resolution) | High | Most Generalizable Interface | Track 1 |
| F-3 | PVec/Set/Map lack Seq instances | Medium | Most Generalizable Interface | Track 1 |
| F-4 | Indexed/Keyed exist but sugar ignores them | High | Decomplection | Track 3 (post-T8) |
| F-5 | Map is an island (no Seqable/Foldable/Seq) | Medium | Most Generalizable Interface | Track 1 + HKT partial app |
| F-6 | `impl` doesn't work for HKT traits | **Critical** | Infrastructure | Track 8 prerequisite |
| F-7 | Broadcast hardcoded to cons/nil | High | Decomplection | Track 4 (post-T8) |
| F-8 | Collection bundle is LSeq-centric | Low | Follows from F-1 | Track 1 |

### Critical Path

F-6 (HKT `impl`) is the linchpin. Without it, Seq-as-trait (F-2) can't resolve automatically, Indexed/Keyed sugar dispatch (F-4) can't generate resolvable constraints, and the entire CIU vision depends on manual dict threading. This is what Track 8 must deliver.

---

## 7. Recommendations for Track 8

Based on this audit, Track 8 should prioritize:

1. **HKT `impl` and trait resolution** — this is the critical enabler for CIU Tracks 1-5
2. **Callback elimination** — so `surf-get` can generate trait constraints directly
3. **Module restructuring** — so `elaborator.rkt` can call `trait-resolution.rkt` without circular imports

These align with the Track 8 audit's own P1 priorities (§5.1-5.2). The CIU audit adds specificity: it's not just "callback elimination in general" — it's specifically "the `surf-get` elaboration site needs to emit Indexed/Keyed constraints that resolve through the readiness/resolution propagator pipeline."
