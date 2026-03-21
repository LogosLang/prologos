# Collection Interface Unification — Stage 2/3 Design Document

**Date**: 2026-03-20
**Status**: Draft — design discussion in progress
**Scope**: Principled collection dispatch via Seq with efficient trait resolution on propagator network
**Prerequisite**: Collection traits exist and are instanced; Track 7 propagator infrastructure complete; Track 8 audit complete
**Depends on**: Track 8 (propagator migration) for full implementation
**Audit**: `docs/tracking/2026-03-20_COLLECTION_INTERFACE_AUDIT.md` (commit `e632dce`)
**Track 8 Audit**: `docs/tracking/2026-03-18_TRACK8_PROPAGATOR_INFRASTRUCTURE_AUDIT.md`
**Supersedes**: None (extends collection-traits + generic-ops infrastructure)

---

## Progress Tracker

| # | Phase | Description | Status | Commit | Notes |
|---|-------|-------------|--------|--------|-------|
| 0 | Acceptance file | Baseline canary + aspirational tests | ⬜ | | Extend existing first-class-paths acceptance |
| 1 | `ground-expr?` union fix | Add explicit `expr-union` case | ⬜ | | Immediate completeness fix (pre-Track 8) |
| 4 | Dot-brace path expansion | `.{field1 field2}` reader syntax | ⬜ | | Reader + preparse; independent of dispatch redesign |
| — | Track 8 dependency | Propagator-resolved trait dispatch infrastructure | ⬜ | | See §6: Track 8 Requirements |
| T1 | Trait-dispatched indexing | `xs[0]` generates Indexed/Keyed constraint; propagator resolves dict | ⬜ | | Post-Track 8 |
| T2 | Trait-dispatched broadcast | `xs.*field` iterates via Seq; propagator resolves dict | ⬜ | | Post-Track 8 |
| T3 | Union-aware trait dispatch | Trait methods resolve on union types | ⬜ | | Post-Track 8 |
| T4 | Efficient Seq dispatch | `gmap`/`gfilter` dispatch to native collection ops, not LSeq intermediary | ⬜ | | Post-Track 8 |
| D1 | Open-map value typing | Design decision on unschema'd map access return type | ⬜ | | Design discussion |

---

## 1. Problem Statement

### Two Tiers of Collection Dispatch

The collection trait system in Prologos has the right abstractions at the library level: `Seqable`, `Buildable`, `Foldable`, `Reducible`, `Indexed`, `Keyed`, `Setlike`, and `Seq` exist with instances for `List`, `PVec`, `Set`, and `Map`.

But there are **two tiers** of dispatch that don't talk to each other:

**Tier 1 — Library generic operations** (`gmap`, `gfilter`, `gfold`, etc.): Use trait-dispatched dicts. `gfold` calls `$foldable A B f z xs` — the dict IS the native implementation. `Foldable List` dispatches to List's `foldr`; `Foldable PVec` dispatches to RRB-tree traversal. No intermediaries for fold/reduce. However, `gmap` and `gfilter` still go through the `Seqable → LSeq → Buildable` pipeline — converting to a lazy sequence, transforming, converting back. This works but introduces an intermediary form where efficient dispatch should suffice.

**Tier 2 — Syntactic sugar** (`xs[0]`, `m.field`, `xs.*field`, `get-in`): Bypasses traits entirely. `surf-get` elaborates to `expr-get`, which pattern-matches on concrete constructors (`expr-champ`, `expr-rrb`, cons-chain) in reduction.rkt. `expr-broadcast-get` walks only cons/nil list structure. A user-defined type implementing `Indexed` gets `gfold` for free but NOT `xs[0]`.

### The Vision: Seq with Efficient Dispatch

The target architecture is that **every collection type implements `Seq`** (analogous to Clojure's `ISeq`) and dispatches to type-specific implementations. The `Seq` dict bundles `first`/`rest`/`empty?` — three operations that any sequential type can provide natively. When `gmap` operates on a PVec, it should dispatch through PVec's native Seq implementation, not convert to LSeq and back.

This means:
- `Seq` is the universal iteration protocol — the "hub" that all collection operations go through
- Each collection provides its own `Seq` instance with efficient, native implementations
- `LSeq` becomes a specific lazy sequence type that also implements `Seq`, but it is NOT a mandatory intermediary
- Syntactic sugar (`xs[0]`, `xs.*field`) dispatches through `Indexed`/`Keyed`/`Seq` traits, not constructor pattern-matching

### Root Cause: Phase Separation

Why doesn't this work today? The trait system operates at **compile time** — the elaborator resolves `Indexed PVec` to a concrete dict and threads it as a lambda parameter. But `surf-get` elaborates to `expr-get`, an AST node with no dict that relies on constructor pattern-matching at runtime. The trait system is structurally disconnected from the syntactic sugar pipeline.

This phase separation is the same architectural boundary that Tracks 1–7 of the propagator migration have been systematically dissolving. Trait resolution is already a propagator event — readiness propagators watch type cells, and when a type becomes ground, resolution propagators fire and write dict solutions. The collection dispatch problem is another instance of the same gap.

### What We Want

```prologos
;; Any type implementing Indexed gets postfix indexing
def xs := @[10 20 30]     ;; PVec
xs[0]                      ;; => 10 (via Indexed dispatch, not hardcoded expr-rrb)

;; Any Seqable gets broadcast, dispatching through Seq
def scores := @[{:x 1} {:x 2} {:x 3}]   ;; PVec of Maps
scores.*x                  ;; => @[1 2 3] (via Seq iteration, not cons/nil walking)

;; Branching dot-access
def user := {:name "Alice" :age 30 :email "a@b.com"}
user.{name email}          ;; => {:name "Alice" :email "a@b.com"}

;; gmap dispatches through native Seq, not LSeq intermediary
[gmap [int+ _ 1] @[10 20 30]]   ;; PVec's native Seq, not to-seq/from-seq

;; User-defined collection types participate in all syntax
;; (after implementing Indexed or Seq)
impl Indexed MyVec
  idx-nth := ...
;; Then: my-vec[0] works automatically
```

---

## 2. Gap Analysis

### What We Have

| Component | Status | Notes |
|-----------|--------|-------|
| Trait definitions (Indexed, Keyed, Seq, Seqable, etc.) | Complete | `lib/prologos/core/collection-traits.prologos` |
| Trait instances for built-in collections | Complete | List, PVec, Set, Map |
| `Seq` dict type + accessors (`seq-first`, `seq-rest`, `seq-empty?`) | Complete | Universal sequence interface |
| `Foldable`/`Reducible` with efficient dispatch | Complete | Dict IS the native fold; no intermediary |
| `gmap`/`gfilter` via LSeq intermediary | Working but not ideal | `Seqable → LSeq → Buildable` pipeline |
| Trait resolution as propagator events | Complete (Track 7) | Readiness → resolution propagators fire when types ground |
| Reactive constraint resolution | Complete (Track 7) | Stratified quiescence, ready-queue, threshold-cells |
| Cell-tree unification infrastructure | In progress (PUnify) | Cell-tree decomposition for compound types |
| `expr-get` (postfix indexing) | Hardcoded constructor dispatch | `reduction.rkt` lines 2093–2122 |
| `expr-broadcast-get` | List-only cons/nil walking | `reduction.rkt` lines 3403–3449 |
| `get-in`/`update-in` | Map-only `expr-map-get` chains | `elaborator.rkt`, `reduction.rkt` |
| Schema narrowing for `map-get` | Complete | `typing-core.rkt` lines 1284–1296 |
| `ground-expr?` union case | Missing (fragile default) | `trait-resolution.rkt` line 82 |
| Dot-brace `.{...}` reader token | Missing entirely | `reader.rkt` |
| Union-aware trait resolution | Not implemented | `trait-resolution.rkt` |

### What's Missing

1. **Trait constraint generation for syntactic sugar**: `xs[0]` should generate an `Indexed` constraint, not elaborate to a dict-free `expr-get`
2. **Propagator-resolved dict flow to dispatch sites**: The resolved dict needs to reach the point where indexing/broadcast actually executes
3. **Seq-based iteration for broadcast and gmap/gfilter**: Replace cons/nil walking and LSeq intermediary with Seq dispatch
4. **`.{...}` tokenization**: Reader does not recognize dot-brace (independent of dispatch redesign)
5. **Union-aware trait dispatch**: `trait-resolution.rkt` has no `expr-union` handling
6. **Open-map typing policy**: Whether unschema'd maps return `_` or full union

---

## 3. Target Architecture: Propagator-Resolved Trait Dispatch

### The Key Insight

Trait resolution is already a propagator event in the current architecture. When the elaborator encounters `[gfold $foldable f z xs]`, it generates a trait constraint `Foldable C` where `C` is the collection type constructor. A readiness propagator watches the type cell for `C`. When `C` becomes ground (e.g., solved to `List`), the readiness propagator fires, the resolution propagator looks up `impl Foldable List`, and writes the dict to the dict meta cell. The elaborated code receives the resolved dict through normal meta solution.

**The same mechanism should drive all collection dispatch.** When `xs[0]` is elaborated:

1. The elaborator generates a trait constraint: `Indexed C` (where `C` is the type constructor of `xs`)
2. A readiness propagator watches the type cell for `xs`
3. When the type is solved (e.g., `PVec Int`), the propagator fires and resolves `Indexed PVec`
4. The dict is written to a meta cell
5. The elaborated code becomes `[idx-nth $dict xs key]` — a normal trait method call
6. Reduction applies the dict to the arguments — no constructor pattern-matching needed

This is not a new mechanism. It's the *existing* trait resolution mechanism applied to a new site. The only change is that `surf-get` generates a trait constraint instead of elaborating to a dict-free `expr-get`.

### Seq as the Universal Iteration Protocol

For broadcast (`xs.*field`) and generic mapping/filtering, the `Seq` dict provides the universal iteration interface:

```prologos
;; Seq S bundles three operations:
;;   first  : S A → Option A
;;   rest   : S A → S A
;;   empty? : S A → Bool
```

Every collection type implements `Seq` with native, efficient operations:
- `Seq List`: `first` = head, `rest` = tail, `empty?` = nil check
- `Seq PVec`: `first` = rrb-get 0, `rest` = rrb-drop 1, `empty?` = rrb-count = 0
- `Seq Set`: `first`/`rest`/`empty?` on the underlying hash iteration

When broadcast encounters `xs.*field`:
1. The elaborator generates a `Seqable C` constraint (or resolves a `Seq` dict directly)
2. The resolved dict provides `first`/`rest`/`empty?` for the actual collection type
3. Broadcast iterates via these operations — efficient, type-specific, no cons/nil assumption
4. Result collection type is determined by a `Buildable` constraint (preserves PVec → PVec, etc.)

### Eliminating the LSeq Intermediary

The current `gmap` pipeline: `to-seq → lseq-map → from-seq`. This converts to LSeq (thunk-based lazy cells), maps over the lazy sequence, then converts back.

The target: `gmap` dispatches through `Seq` directly. Each collection's `Seq` instance provides native iteration. No conversion to/from LSeq unless the user explicitly wants laziness.

```prologos
;; Current (LSeq intermediary):
spec gmap {A B} {C : Type -> Type} [Seqable C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]
defn gmap [$seq $build f xs]
  Buildable-from-seq $build B [lseq-map A B f [$seq A xs]]

;; Target (Seq-based efficient dispatch):
spec gmap {A B} {C : Type -> Type} [Seq C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]
defn gmap [$seq-dict $build f xs]
  ;; iterate via seq-first/seq-rest/seq-empty?, build via from-seq
  ;; OR: each collection provides a native fmap via Functor
  ...
```

The exact formulation depends on whether `Functor` (which gives native `fmap`) or `Seq + Buildable` (which gives generic iteration + reconstruction) is the right abstraction for map. Both are already defined as traits. The principled choice: **`Functor` for structure-preserving map** (PVec → PVec), **`Seq + Buildable` for cross-type transformation** (PVec → List).

### How This Relates to Track 8

Track 8 is about bringing the remaining elaboration state onto the propagator network. The collection interface needs Track 8 for one critical reason:

**When the type cell for a collection is solved, the trait constraint must fire and resolve the dict.** This already works for explicit trait constraints (e.g., `where (Foldable C)`). But for *implicit* constraints generated by syntactic sugar, the elaborator currently doesn't generate constraints at all — it produces a dict-free `expr-get`. Making `surf-get` generate trait constraints that flow through the propagator network is the architectural change.

Specifically, this design needs:

1. **Constraint generation at `surf-get`/`surf-broadcast-get` sites** — the elaborator emits `Indexed C` or `Seq C` constraints
2. **Dict meta cells for the resolved dicts** — the resolution propagator writes here
3. **The elaborated code references the dict meta** — just like any other trait method call
4. **Reduction applies the dict** — standard function application, no constructor dispatch

Items 1–3 use the *existing* readiness/resolution propagator infrastructure from Track 7. Item 4 is already how trait method calls work. The gap is that `surf-get` currently short-circuits this mechanism.

Track 8's contributions that enable this:
- **Callback elimination + module restructuring** (§5.2): Makes trait resolution directly callable from elaboration sites without indirection
- **Cell-tree unification** (§5.3): May improve type solving speed, making types ground sooner and trait constraints resolvable earlier
- **`id-map` accessibility** (§5.1): Enables cross-domain propagation that may be needed for Indexed/Keyed dict cells

---

## 4. Immediate Work (Pre-Track 8)

These phases are independent of the propagator-resolved dispatch redesign and can land now.

### Phase 0: Acceptance File Extension

Extend `examples/2026-03-20-first-class-paths.prologos` with a new section `§I — Collection Interface Unification`:

```prologos
;; §I — COLLECTION INTERFACE UNIFICATION

;; I1: PVec indexing (works today via expr-get, should use Indexed post-Track 8)
def pv := @[10 20 30]
pv[0]               ;; => 10
pv[2]               ;; => 30

;; I2: Broadcast on PVec (currently stuck — target for post-Track 8)
;; def pv-maps := @[{:x 1} {:x 2} {:x 3}]
;; pv-maps.*x       ;; => @[1 2 3]

;; I3: Dot-brace expansion (Phase 4 — independent of dispatch redesign)
;; def u := {:name "Alice" :age 30 :email "a@b.com"}
;; u.{name email}   ;; => {:name "Alice" :email "a@b.com"}

;; I4: gmap without LSeq intermediary (target for post-Track 8)
;; [gmap [int+ _ 1] @[10 20 30]]   ;; => @[11 21 31] via native PVec Seq
```

### Phase 1: `ground-expr?` Union Fix

**File**: `trait-resolution.rkt` line 82

Add explicit `expr-union` case before the conservative default:

```racket
[(expr-union l r) (and (ground-expr? l) (ground-expr? r))]
```

Currently falls to `[_ #t]` — happens to be correct but fragile. The explicit case makes the function self-documenting and prepares for union-aware trait dispatch.

### Phase 4: Dot-Brace Path Expansion

**Goal**: `m.{name age}` as syntactic sugar for branching `get-in`.

This is pure reader/preparse work — no dispatch changes, no trait involvement. It desugars entirely to existing `get-in` + keyword path syntax.

#### WS Impact

1. **Reader** (`reader.rkt`): New token type `dot-lbrace` for `.{` (no space between dot and brace). Distinguishes from map literals by requiring no space after `.` — same convention as `.*` (broadcast).

2. **Preparse** (`macros.rkt`): `$dot-lbrace` sentinel rewrites to `(get-in target :field1 :field2 ...)`. Key renaming (`^`) inside braces works naturally because `validate-selection-paths` already handles `^`.

3. **No new AST node**: Desugars at preparse level. No parser/elaborator/typing changes.

#### Reader Changes

```racket
(define (read-dot-token ...)
  (cond
    [(char=? next #\{)
     ;; .{ — branching dot-access
     ;; Read field names until }
     ;; Emit: $dot-lbrace sentinel with fields
     ...]
    [(char=? next #\*)
     ;; .* — broadcast access (existing)
     ...]
    [else
     ;; .ident — simple dot-access (existing)
     ...]))
```

#### Preparse Rewriting

```
$dot-lbrace target field1 field2 ...
→ (get-in target :field1 :field2 ...)
```

**With renaming**: `m.{name^n age^a}` → `(get-in m :name^n :age^a)`.

---

## 5. Post-Track 8 Work: Propagator-Resolved Collection Dispatch

These phases require Track 8 infrastructure and represent the principled solution.

### Phase T1: Trait-Dispatched Indexing

**Prerequisite**: Track 8 callback elimination + module restructuring

**Change**: `surf-get` generates a trait constraint instead of elaborating to `expr-get`.

```
surf-get coll key
  → infer type of coll
  → if type implements Indexed: generate Indexed constraint, elaborate to [idx-nth $dict coll key]
  → if type implements Keyed: generate Keyed constraint, elaborate to [kv-get $dict coll key]
  → if Schema/Selection: preserve expr-map-get (schema narrowing)
  → if type is unsolved meta: generate deferred constraint (propagator will resolve when type arrives)
  → fallback: expr-get (backward compat during migration)
```

The "unsolved meta" case is the critical one. Today it falls to `expr-get` with constructor dispatch. With propagator infrastructure, it generates a constraint that fires when the meta is solved. The readiness propagator watches the type cell; when ground, the resolution propagator resolves `Indexed` or `Keyed` and writes the dict. The elaborated code is already wired to read from the dict meta cell.

**`expr-get` becomes vestigial.** Once all dispatch goes through trait constraints, `expr-get` serves only as a backward-compatibility fallback. It can be deprecated and eventually removed.

**Design tension — `kv-get` returns `Option V`**: The current `expr-map-get` returns `V` directly. `Keyed.kv-get` returns `Option V`. For syntactic sugar (`m.field`, `m[key]`), we should preserve the current `V` semantics. Options:
- Keep `expr-map-get` for Map dot-access (schema narrowing depends on it)
- Or: `kv-get!` variant that unwraps or errors (sugar-specific)
- This is a separate design decision; Phase T1 can preserve current Map behavior while converting List/PVec to trait dispatch

### Phase T2: Trait-Dispatched Broadcast

**Prerequisite**: Track 8 + Phase T1 pattern established

**Change**: `surf-broadcast-get` generates a `Seq` (or `Seqable`) constraint on the target collection.

```
surf-broadcast-get target fields
  → generate Seq constraint on target's type constructor
  → elaborate to: iterate via seq-first/seq-rest/seq-empty?, apply map-get chain per element
  → result collection: generate Buildable constraint for output reconstruction
```

With the Seq dict resolved by propagator, broadcast iterates any collection type using the native `first`/`rest`/`empty?` operations. No cons/nil pattern-matching. No hardcoded PVec/Set recognition.

**Result type preservation**: With a `Buildable` constraint on the output, broadcast over a PVec produces a PVec (not a List). The `Buildable` dict provides `from-seq`/`empty-coll`/`conj` for the target type.

### Phase T3: Union-Aware Trait Dispatch

**Prerequisite**: Track 8 infrastructure

When `resolve-trait-constraints!` encounters a constraint like `Indexed <PVec | List>`:

1. Decompose the union into its members
2. Check if ALL members have an impl for the trait
3. If yes, generate a runtime dispatch wrapper using the per-member dicts
4. If any member lacks an impl, the constraint fails

This addresses the `movie.genres[0]` issue: when `map-get` on a heterogeneous map returns a union type, postfix indexing should still work if all union members support `Indexed`.

**Design concern**: This generates runtime dispatch code from compile-time type information. The trait system is currently pure compile-time. Introducing runtime dispatch for union types is a qualitative change that needs careful design review.

### Phase T4: Efficient Seq Dispatch for gmap/gfilter

**Prerequisite**: Phases T1–T2 establishing the pattern

Replace the `Seqable → LSeq → Buildable` pipeline in `gmap`/`gfilter` with direct `Seq`-based dispatch:

```prologos
;; Target: Seq-based dispatch
spec gmap {A B} {C : Type -> Type} [Seq C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]
defn gmap [$seq-dict $build f xs]
  ;; Iterate via seq-first/seq-rest/seq-empty? using native collection ops
  ;; Build result via Buildable (preserves collection type)
  ...
```

Or, for structure-preserving map, use `Functor` directly:

```prologos
spec gmap {A B} {F : Type -> Type} [Functor F] -> [A -> B] -> [F A] -> [F B]
defn gmap [$functor f xs]
  fmap $functor f xs   ;; native fmap for each collection type
```

The choice between `Seq + Buildable` and `Functor` depends on whether we want `gmap` to always preserve collection type (`Functor`) or allow cross-type transformation (`Seq + Buildable`). Both can coexist:
- `fmap` (Functor): structure-preserving, type-preserving
- `gmap` (Seq + Buildable): generic, may change collection type
- `LSeq` operations: explicit laziness when the user wants it

**LSeq's role**: LSeq becomes a specific collection type that implements `Seq` (with lazy evaluation semantics), not a mandatory intermediary in the pipeline. Users choose LSeq when they want laziness; the default path uses efficient direct dispatch.

---

## 6. Track 8 Requirements

This section captures what the collection interface design needs from Track 8, to inform Track 8's priorities.

| Requirement | Track 8 Component | Why |
|-------------|-------------------|-----|
| Trait constraints from `surf-get` must resolve via propagator | Existing readiness/resolution propagators (Track 7) | The mechanism exists; `surf-get` just needs to generate the right constraints |
| Dict meta cells accessible at dispatch sites | `id-map` accessibility (§5.1) | Dict metas need to be readable from the elaboration site that consumes them |
| Trait resolution callable from elaborator without callback indirection | Callback elimination (§5.2) | `surf-get` needs to emit constraints that go through the resolution pipeline directly |
| Type cells solved before dispatch-site elaboration completes | Cell-tree unification (§5.3) | Faster type solving means trait constraints resolve sooner, reducing deferred-dispatch cases |
| Module restructuring enables direct trait lookups | Module graph restructuring (§5.2.3 Option 1) | `elaborator.rkt` needs to call trait resolution functions without circular dependency |

**Key observation**: Most of this is already built. Track 7 established readiness propagators, resolution propagators, and the stratified quiescence loop. The collection dispatch problem doesn't need *new* propagator infrastructure — it needs the *existing* infrastructure to be reachable from `surf-get` elaboration sites, which is exactly what Track 8's callback elimination and module restructuring deliver.

---

## 7. Design Decisions

| # | Decision | Resolution | Rationale |
|---|----------|------------|-----------|
| D1 | Collection dispatch mechanism | Propagator-resolved trait constraints | Dissolves phase separation; uses existing Track 7 infrastructure; user-extensible |
| D2 | Iteration protocol | Seq (ISeq-style) with efficient per-type dispatch | Every collection implements Seq natively; LSeq is a specific lazy type, not a mandatory hub |
| D3 | `m.field` returns `V` or `Option V` | `V` (direct) for sugar; `Option V` for explicit `kv-get` | Backward compatibility; schema narrowing depends on direct `V` |
| D4 | Broadcast result type | Preserve input collection type via Buildable | PVec broadcast → PVec; List broadcast → List |
| D5 | Dot-brace implementation level | Reader + preparse (no new AST) | Desugars to existing `get-in`; independent of dispatch redesign |
| D6 | Union trait dispatch | Runtime dispatch wrapper when all union members impl trait | Qualitative change; needs design review; scoped narrowly at first |
| D7 | Open-map value type | Schema-first — see §8 | Union is correct for unschema'd; schema provides per-field narrowing |
| D8 | LSeq's role | Specific lazy collection type, not mandatory intermediary | `gmap`/`gfilter` go through Seq or Functor; LSeq for explicit laziness |
| D9 | Implementation timing | Pre-Track 8: Phases 0, 1, 4. Post-Track 8: Phases T1–T4 | Full solution requires propagator infrastructure Track 8 delivers |

---

## 8. Open-Map Value Typing (Design Discussion)

**Question**: What should `map-get` return on an open-world (unschema'd) heterogeneous map?

**Option A — Status quo (union)**: `{:a 1 :b "hello"}` has type `Map Keyword <Int | String>`. Accessing `:a` returns `<Int | String>`. Precise but requires narrowing/match to use.

**Option B — Dynamic (`_`)**: `{:a 1 :b "hello"}` has type `Map Keyword _`. Accessing any key returns `_`. More usable but loses type safety.

**Option C — Schema-first**: Keep union typing for unschema'd maps. Schema'd maps return precise per-field types (already implemented). The usability gap nudges users toward `schema` for structured data.

**Recommendation**: Option C. The union type is correct — it reflects reality. The `schema` system provides the ergonomic path. Open-world maps are for dynamic/exploratory code; schemas are for typed data.

This is a design philosophy decision, not a code change.

---

## 9. Relationship to Principles

| Principle | Current Status | After Pre-Track 8 | After Post-Track 8 |
|-----------|---------------|--------------------|--------------------|
| Collections decoupled from backends | **VIOLATED** | No change | **Compliant** — dispatch through traits |
| Most Generalizable Interface | **VIOLATED** | No change | **Compliant** — Seq/Indexed/Keyed are the interfaces |
| Seq with efficient dispatch | Partial (Foldable yes, gmap no) | No change | **Compliant** — all ops through native Seq |
| Traits over concrete types | **VIOLATED** | No change | **Compliant** — no constructor pattern-matching |
| Open extension, closed verification | Partial | No change | **Compliant** — user types get `[n]` and `.*` |
| Propagator-first infrastructure | Partial (traits yes, sugar no) | No change | **Compliant** — sugar generates constraints on network |

---

## 10. Key Files

| File | Pre-Track 8 | Post-Track 8 |
|------|-------------|--------------|
| `trait-resolution.rkt` | Phase 1: `ground-expr?` union case | T3: union-aware dispatch |
| `reader.rkt` | Phase 4: `dot-lbrace` token | — |
| `macros.rkt` | Phase 4: `$dot-lbrace` → `get-in` | — |
| `elaborator.rkt` | — | T1: `surf-get` generates trait constraints |
| `typing-core.rkt` | — | T1: `expr-get` fallback narrows; union indexing |
| `reduction.rkt` | — | T1: `expr-get` becomes vestigial; T2: broadcast via Seq dict |
| `generic-ops.prologos` | — | T4: `gmap`/`gfilter` via Seq, not LSeq |
| `collection-traits.prologos` | — | T4: possibly extend Seq instances |
| `examples/2026-03-20-first-class-paths.prologos` | Phase 0: §I section | T1–T4: uncomment aspirational tests |

---

## 11. Test Strategy

### Pre-Track 8

| Phase | Level 1 | Level 2 | Level 3 |
|-------|---------|---------|---------|
| 1 | Full suite (no behavioral change) | N/A | N/A |
| 4 | N/A (preparse only) | `m.{name age}` | Acceptance file §I |

### Post-Track 8

| Phase | Level 1 | Level 2 | Level 3 |
|-------|---------|---------|---------|
| T1 | `expr-get` via Indexed/Keyed | `xs[0]` on PVec | Acceptance §I, §U |
| T2 | PVec/Set broadcast | `@[{:x 1}].*x` | Acceptance §I, §U |
| T3 | Union trait resolution | `movie.genres[0]` | Acceptance §U |
| T4 | gmap without LSeq | `[gmap f @[...]]` | Benchmark comparison |

Benchmark comparison required after T1 and T4 — these change hot paths.

---

## 12. Deferred / Out of Scope

- **Lens/Optics layer**: Composable get/set pairs as a library on top of paths and traits. Orthogonal.
- **`get-in` on mixed-collection paths**: `m.users[0].name` navigating Maps and PVecs. Builds on T1 (Indexed + Keyed at each path segment).
- **Transducer fusion**: `gmap f >> gfilter p` as a single pass. Builds on T4 (Seq-based ops).
- **Parallel collection operations**: BSP-style parallel map/fold. Depends on propagator parallelism (Track 8 §4.5).
