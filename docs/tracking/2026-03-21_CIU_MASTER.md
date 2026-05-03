# Collection Interface Unification (CIU) Series

**Created**: 2026-03-21
**Status**: Track 0 ✅ (Trait Hierarchy Audit). Tracks 1-2 ⬜ pre-Track-8. Tracks 3-5 ⬜ post-Track-8 (now unblocked by Track 8 completion + BSP-LE Track 2/2B).
**Thesis**: All collection access — indexing, iteration, broadcast, mapping, path navigation — dispatches through traits resolved on the propagator network. Syntactic sugar generates trait constraints, not constructor-specific AST nodes. User-defined collections participate in all syntax automatically.

---

## Series Thesis

> Collection abstractions are decoupled from their concrete backends. Users program against traits; implementations are swappable with zero code changes. Syntactic sugar (`xs[0]`, `xs.*field`, `m.field`, `get-in`) generates trait constraints that resolve through the same propagator-based mechanism as explicit trait dispatch. Every collection type that implements `Indexed` gets `[0]` syntax; every type that implements `Seq` gets broadcast and iteration. The phase separation between compile-time traits and runtime constructor dispatch is dissolved.

This thesis addresses 5 principle violations identified in the Collection Interface Audit (`e632dce`), aligning the compiler's dispatch mechanisms with the library's trait abstractions — which are already correctly designed.

## Principles at Stake

| Principle | Source | Current Status |
|-----------|--------|---------------|
| Collections decoupled from backends | DESIGN_PRINCIPLES.org §Collections and Backends | **VIOLATED** — `expr-get` pattern-matches constructors |
| Most Generalizable Interface | DESIGN_PRINCIPLES.org §Most Generalizable Interface | **VIOLATED** — sugar bypasses traits |
| Traits over concrete types | DESIGN_PRINCIPLES.org §Most Generalizable Interface | **VIOLATED** — `Foldable` works, `Indexed` doesn't |
| Open extension, closed verification | DESIGN_PRINCIPLES.org §Collections and Backends | **VIOLATED** — new collections require modifying `reduction.rkt` |
| Propagator-first infrastructure | DESIGN_PRINCIPLES.org §Propagators as Universal Computational Substrate | **PARTIAL** — traits use propagators, sugar does not |
| Seq with efficient dispatch | DESIGN_PRINCIPLES.org §Most Generalizable Interface | **PARTIAL** — `Foldable` is efficient, `gmap` uses LSeq intermediary |

**Note**: DESIGN_PRINCIPLES.org §Most Generalizable Interface (line 205-206) currently says "LSeq as a hub type." This is superseded by the Seq-with-efficient-dispatch vision — Track 1 of this Series should update the principle to reflect the corrected design.

## Origin Documents

| Document | Role |
|----------|------|
| `2026-03-20_COLLECTION_INTERFACE_AUDIT.md` (`e632dce`) | Stage 2 audit: 10 findings, 5 principle violations |
| `2026-03-20_COLLECTION_INTERFACE_UNIFICATION_DESIGN.md` (`e7227f2`) | Stage 2/3 design: propagator-resolved trait dispatch, Seq protocol, pre/post Track 8 split |
| `2026-03-18_TRACK8_PROPAGATOR_INFRASTRUCTURE_AUDIT.md` | Track 8 audit: what collection dispatch needs from propagator migration |
| `lib/prologos/core/collection-traits.prologos` | Existing trait definitions (the library layer that IS correctly designed) |
| `lib/prologos/core/generic-ops.prologos` | Existing generic operations (gmap, gfold, etc.) |
| `DESIGN_PRINCIPLES.org` | The principles being violated |
| `ERGONOMICS.org` | Selective disclosure, ergonomic access patterns |

---

## Progress Tracker

| # | Track | Description | Status | Design Doc | Pre/Post Track 8 |
|---|-------|-------------|--------|------------|-------------------|
| 0 | Trait Hierarchy Design | Deep Stage 2: Seq as trait, Functor vs Seq+Buildable, Keyed semantics, mixed paths, selective disclosure | ✅ | [Audit](2026-03-21_CIU_TRACK0_TRAIT_HIERARCHY_AUDIT.md) | Pre (design only) |
| 1 | Seq Protocol | Seq-as-trait migration, native instances, LSeq demotion, gmap/gfilter rerouting | ⬜ | Pending | Pre |
| 2 | Syntactic Sugar Normalization | dot-brace `.{...}`, ground-expr? fix, comprehensive sugar audit | ⬜ | Pending | Pre |
| 3 | Trait-Dispatched Access | `surf-get` generates Indexed/Keyed constraints; propagator resolves; `expr-get` vestigial | ⬜ | Pending | Post Track 8 |
| 4 | Trait-Dispatched Iteration | Broadcast via Seq dict; gmap/gfilter via Functor or Seq+Buildable | ⬜ | Pending | Post Track 8 |
| 5 | Union-Aware Dispatch | Trait resolution on union types; runtime dispatch generation | ⬜ | Pending | Post Track 8 |

---

## Dependency Graph

```
Track 0 (Trait Hierarchy Design)
    │
    ├──→ Track 1 (Seq Protocol)
    │        │
    │        └──→ Track 4 (Trait-Dispatched Iteration) ──[Post Track 8]
    │
    ├──→ Track 2 (Syntactic Sugar Normalization)
    │
    └──→ Track 3 (Trait-Dispatched Access) ──[Post Track 8]
                 │
                 └──→ Track 5 (Union-Aware Dispatch) ──[Post Track 8]

    [Track 8 of Propagator Migration Series]
         │
         └──→ Tracks 3, 4, 5 (unblocked by callback elimination + module restructuring)
```

**Parallelism**: Tracks 1 and 2 can proceed in parallel after Track 0 establishes the design. Track 1 (Seq Protocol) is library-level work; Track 2 (Syntactic Sugar) is reader/preparse work. Independent codepaths.

**Track 8 gate**: Tracks 3-5 require propagator-resolved trait dispatch infrastructure from Track 8. Track 0 captures exactly what's needed (§6 of the origin design doc) to inform Track 8's priorities.

---

## Track Scope Summaries

### Track 0: Trait Hierarchy Design (Deep Stage 2)

**Purpose**: Investigate the principled design space before committing to implementation. The origin design document (`e7227f2`) is excellent on the dispatch *mechanism* (propagator-resolved constraints) but needs deeper treatment of the *trait hierarchy* and *protocol semantics* that the mechanism serves.

**Design questions to resolve**:

1. **Seq: trait or deftype?**
   - Current: `Seq` is a `deftype` (sigma of `first`/`rest`/`empty?`)
   - Trait: enables auto-dispatch via trait resolver; instances declared with `impl Seq MyCollection`
   - Deftype: values are explicit dict records; must be passed manually
   - DEFERRED.md already flags this: "Requires careful refactoring of deftype/trait boundary"
   - Decision drives the entire iteration story

2. **Functor vs Seq + Buildable for mapping**
   - `Functor`: structure-preserving (`fmap : (A → B) → F A → F B`), guaranteed same container type
   - `Seq + Buildable`: generic iteration + reconstruction, allows cross-type transformation
   - Both traits exist. Which does `gmap` use? Can they coexist cleanly? What's the user-facing distinction?
   - Clojure chose transducers (decoupled transform from collection); Haskell chose Functor; Scala chose implicit conversions. What does Prologos choose?

3. **Keyed semantics for syntactic sugar**
   - `kv-get : K → Map K V → Option V` (explicit, safe)
   - `m.field` returns `V` directly (sugar, convenient, relies on schema narrowing)
   - For user-extensible `Keyed`: what does `m[key]` return? `Option V` (safe) or `V` (ergonomic)?
   - The `kv-get!` variant (unwrap-or-error) as a sugar-specific path?
   - Schema narrowing's role: does it apply to user types implementing `Keyed`?

4. **Mixed-collection path navigation**
   - `m.users[0].name` navigates Map → (Indexed) PVec → Map
   - Each segment needs a different trait: Keyed at segment 1, Indexed at segment 2, Keyed at segment 3
   - `get-in`/`update-in` currently hardcoded to `expr-map-get` chains
   - Design: path segments as a heterogeneous sequence of trait constraints?
   - First-class paths (`#p(users[0].name)`) as the unifying abstraction?

5. **Selective disclosure**
   - A user writing `xs[0]` should not need to know about `Indexed`, `Keyed`, propagator-resolved dispatch, or trait constraints
   - A user implementing `Indexed` for their own type should get `[0]` syntax automatically — no additional registration
   - A user extending the collection system with a new trait should find a clear, documented extension protocol
   - Three levels of engagement: *use* (sugar just works), *extend* (implement traits, get syntax), *design* (add new collection protocols)

6. **Principles document update**
   - DESIGN_PRINCIPLES.org line 205-206: "LSeq as a hub type" → "Seq with efficient dispatch"
   - Should this Track also formalize the "traits over constructors" principle for sugar specifically?

**Artifacts**: Stage 2 research document with design space evaluation, trade-off analysis, and recommended decisions. Feeds into Tracks 1-5 design documents.

### Track 1: Seq Protocol

**Source**: Track 0 decisions on Seq-as-trait, Functor vs Seq+Buildable

**Scope**:
- Migrate `Seq` from deftype to trait (if Track 0 decides this)
- Implement native `Seq` instances for List, PVec, Set, Map with efficient dispatch
  - `Seq PVec`: `first` = rrb-get 0, `rest` = rrb-drop 1, `empty?` = rrb-count = 0
  - `Seq Set`: iteration over underlying CHAMP structure
  - `Seq Map`: iteration over CHAMP entries as MapEntry pairs
- Reroute `gmap`/`gfilter` from `Seqable → LSeq → Buildable` to `Seq + Buildable` (or `Functor` for structure-preserving)
- Demote `LSeq` to a specific lazy collection type that implements `Seq`, not a mandatory intermediary
- Extend `Functor` instances beyond List (PVec, Map, Option, Result)
- Update DESIGN_PRINCIPLES.org §Most Generalizable Interface

**Not in scope**: Changing how syntactic sugar dispatches (that's Tracks 3-4). This Track is library-level: make the trait hierarchy correct and efficient, so Tracks 3-4 have the right traits to dispatch through.

### Track 2: Syntactic Sugar Normalization

**Source**: Origin design Phases 1 and 4 + broader sugar audit

**Scope**:
- **`ground-expr?` union fix**: Add explicit `expr-union` case in `trait-resolution.rkt` (immediate completeness fix)
- **Dot-brace `.{field1 field2}`**: Reader tokenization (`dot-lbrace`), preparse rewriting to `get-in`; no new AST node
- **Comprehensive sugar audit**: Inventory all syntactic sugar that produces constructor-specific AST nodes. Document which ones need trait dispatch (Tracks 3-4) vs which can stay as-is (e.g., map literals)
- **Key renaming in dot-brace**: `m.{name^alias}` composing with the `^` renaming syntax from Phase 7c

**Not in scope**: Changing dispatch (Tracks 3-5). This Track normalizes the sugar surface and documents the full scope of what Tracks 3-5 need to address.

### Track 3: Trait-Dispatched Access

**Prerequisite**: Track 8 Part C (COMPLETE) — bridge propagators resolve traits in S0

**Source**: Origin design phases T1 + Track 0 decisions on Keyed semantics + Track 8 B5 (transferred)

**Infrastructure delivered by Track 8**:
- B3/B4: HKT `impl` registration and resolution WORKS (`impl Indexed List` → key `List--Indexed` → resolved via readiness propagators or bridge propagators)
- C1-C3: Resolution bridge propagators fire during S0 quiescence — traits, hasmethods, and constraint retries resolve within the same pass that solves types
- Cell-ops + worldview-aware reads provide direct CHAMP access from elaboration sites
- Module restructuring (elab-network-types.rkt) enables direct trait lookups without callback indirection

**Track 3 Scope** (absorbs Track 8 B5):

**Phase 0: Convert manual dicts to `impl` syntax**
- Convert `def List--Indexed--dict` to `impl Indexed List` in `lib/prologos/core/list.prologos`
- Convert `def PVec--Indexed--dict` to `impl Indexed PVec` in `lib/prologos/core/pvec.prologos`
- Convert manual Keyed dicts for Map similarly
- Verify registration via existing HKT resolution machinery (B3/B4)

**Phase 1: `surf-get` constraint generation**
- `surf-get` checks if the collection type's constructor has an `Indexed` impl (registry cell read during elaboration)
- If found: generate `Indexed C` trait constraint + elaborate to `[idx-nth $dict coll key]`
- If Keyed: generate `Keyed C` trait constraint + elaborate to `[kv-get $dict coll key]`
- If Schema/Selection: preserve `expr-map-get` (schema narrowing)
- If unsolved meta: generate deferred constraint (bridge propagator fires when type arrives)
- Fallback: `expr-get` (backward compat during migration)

**Phase 2: `get-in` + path dispatch**
- Mixed-collection `get-in` paths: each segment generates its own trait constraint
- `m.users[0].name` → Keyed at segment 1, Indexed at segment 2, Keyed at segment 3
- Path segments as heterogeneous constraint sequences

**Phase 3: Verification + `expr-get` deprecation**
- All `xs[0]` tests pass via trait dispatch
- `expr-get` constructor matching in `reduction.rkt` becomes vestigial
- Performance benchmark: trait dispatch overhead vs constructor pattern-matching

**Key architectural change**: The elaborator *generates constraints* rather than *producing dispatch nodes*. The propagator network resolves them. Reduction applies resolved dicts via normal function application. Constructor pattern-matching in `reduction.rkt` becomes vestigial.

**Design tension**: `kv-get` returns `Option V`, but `m.field` returns `V`. Resolution from Track 0 determines approach: sugar-specific `kv-get!`, or keep `expr-map-get` for schema-narrowed Map access.

### Track 4: Trait-Dispatched Iteration

**Prerequisite**: Track 8 + Tracks 1 and 3

**Source**: Origin design phases T2 + T4

**Scope**:
- **Broadcast via Seq**: `surf-broadcast-get` generates `Seq C` constraint on the target collection. Broadcast iterates via resolved `seq-first`/`seq-rest`/`seq-empty?` — any collection, not just cons/nil lists.
- **Result type preservation**: `Buildable` constraint on output. PVec broadcast → PVec; List broadcast → List.
- **`gmap`/`gfilter` efficient dispatch**: Route through `Functor` (structure-preserving) or `Seq + Buildable` (cross-type), per Track 0's decision. Eliminate LSeq intermediary.
- **User extension**: Any type implementing `Seq` automatically gets broadcast and gmap participation.

### Track 5: Union-Aware Dispatch

**Prerequisite**: Track 8 + Track 3

**Source**: Origin design phase T3

**Scope**:
- When `resolve-trait-constraints!` encounters `Indexed <PVec | List>`, decompose the union, verify all members have the trait, generate a runtime dispatch wrapper
- Addresses the `movie.genres[0]` issue: `map-get` returns union → postfix indexing should still work if all union members support `Indexed`
- **Qualitative change**: Introduces runtime dispatch from compile-time type information. The trait system is currently pure compile-time. This is the most design-sensitive Track.

**Design concerns**:
- Runtime dispatch code generation from type information crosses a phase boundary
- Performance: runtime type-case dispatch vs compile-time monomorphization
- Scope: which traits support union dispatch? All? Only `Indexed`/`Keyed`/`Seq`?
- Error messages: when a union member lacks a trait, what does the user see?

---

## Cross-Series Dependencies

### Propagator Migration Series (Track 8) — DELIVERED

CIU Tracks 3-5 required Track 8 infrastructure. **All requirements are now met.**

| CIU Requirement | Track 8 Delivery | Status |
|-----------------|-------------------|--------|
| Trait constraints resolve via propagator | C1-C3: Bridge propagators in S0 (`e6d8901`, `467d318`) | ✅ |
| HKT `impl` registration + resolution | B3/B4: Parser fixes + readiness propagator resolution (`ac25508`, `a08fd1c`) | ✅ |
| Dict meta cells accessible at dispatch sites | A2 (Track 6): `id-map` accessible from prop-net layer | ✅ |
| Trait resolution without callback indirection | B2: 14/23 callbacks eliminated; cell-ops direct access (`58b2f5c`) | ✅ |
| Module restructuring for direct trait lookups | B2a: elab-network-types.rkt extraction (`340c2bc`) | ✅ |
| Worldview-aware reads for speculation-safe dispatch | B1: cell-ops.rkt with worldview-visible? (`fa76f00`) | ✅ |

**CIU Tracks 3-5 are now UNBLOCKED by Track 8.**

### BSP-LE Series

CIU is independent of BSP-LE. The two Series address different subsystems:
- BSP-LE: the logic engine (solver, search, tabling)
- CIU: the collection dispatch layer (traits, sugar, iteration)

They share Track 8 as a common dependency. No direct inter-Series dependencies.

### DEFERRED.md Items Absorbed

| DEFERRED Item | Absorbed Into |
|---------------|---------------|
| `Seq` as Proper Trait (deftype → trait migration) | Track 0 (design) + Track 1 (implementation) |
| HKT Partial Application for Map Trait Instances | Track 0 (design question — needed for `Map K` as `Type → Type`) |
| Clause-Style Constraint Matching | Out of scope (separate from collection dispatch) |
| Transducer Runners for Non-List | Track 4 (subsumed by Seq-based iteration) |

---

## Success Criteria (Series-Level)

1. **`xs[0]` works for any type implementing `Indexed`** — PVec, List, user-defined
2. **`xs.*field` works for any type implementing `Seq`** — PVec, Set, List, user-defined
3. **`gmap`/`gfilter` dispatch through native Seq/Functor** — no LSeq intermediary
4. **User-defined collections get all syntax automatically** — implement `Indexed` → get `[0]`; implement `Seq` → get `.*field` and `gmap`
5. **`movie.genres[0]` works** — union-aware trait dispatch on `<PVec | List>`
6. **No constructor pattern-matching in `reduction.rkt` for collection dispatch** — `expr-get` vestigial or removed
7. **DESIGN_PRINCIPLES.org §Most Generalizable Interface updated** — "Seq with efficient dispatch" replaces "LSeq as hub"

---

## Open Questions

1. **Track 0 scope discipline**: How deep does the design space investigation go before committing? The risk is analysis paralysis. Recommendation: time-box Track 0 to one design cycle (D.1 → critique → D.2), targeting decisions on the 6 questions listed above.

2. **Seq-as-trait migration risk**: If `Seq` becomes a trait, all existing code using `Seq` dict values directly (passing `seq-first`/`seq-rest`/`seq-empty?` as explicit dict arguments) needs to change. Impact assessment needed in Track 0.

3. **Backward compatibility during migration**: Tracks 3-4 must preserve existing behavior while transitioning dispatch. The `expr-get` fallback (retain constructor matching as backward compat) provides a migration path, but how long does it persist?

4. **Performance benchmarking**: Trait-dispatched access adds a dict lookup where constructor matching is currently zero-cost. Benchmark comparison required after Tracks 3-4. The expectation: trait dispatch is one indirection, vs constructor matching which is pattern-match depth. Should be comparable, but needs measurement.

---

## Research: Module Theory

[Module Theory on Lattices](../research/2026-03-28_MODULE_THEORY_LATTICES.md): Collection traits are module morphisms. Seq protocol = homomorphism from container to abstract sequential module.
