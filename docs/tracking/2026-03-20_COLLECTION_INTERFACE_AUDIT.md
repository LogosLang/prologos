# Collection Interface Audit & Design — 2026-03-20

## Motivation

User testing of the first-class paths acceptance file (§U) revealed multiple issues where the implementation diverges from the design principles stated in DESIGN_PRINCIPLES.org. These are not isolated bugs — they reflect a systemic gap between the **trait abstractions defined in the library** and the **concrete dispatch used in the reduction engine**.

This document audits the current state, maps violations to principles, and proposes a phased design to close the gaps.

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Audit (this document) | ✅ | commit TBD |
| 1 | `expr-get` trait dispatch | ⬜ | Indexed/Keyed in reduction |
| 2 | Broadcast generalization | ⬜ | Seqable-based broadcast |
| 3 | Dot-brace path expansion | ⬜ | `.{field1 field2}` reader syntax |
| 4 | Union-aware trait dispatch | ⬜ | Trait resolution on union types |
| 5 | Open-map value typing | ⬜ | Revisit map-get return type |

---

## Audit Findings

### 1. Collection Trait Definitions: COMPLIANT

All collection traits exist in `lib/prologos/core/collection-traits.prologos`:

| Trait | Methods | Instances |
|-------|---------|-----------|
| Seqable | `to-seq` | List, PVec, Set, Map (via MapEntry) |
| Buildable | `from-seq`, `empty-coll`, `conj` | List, PVec, Set |
| Foldable | `fold` | List, PVec, Set |
| Reducible | `reduce` | List, PVec, Set |
| Indexed | `idx-nth`, `idx-length`, `idx-update` | List, PVec |
| Keyed | `kv-get`, `kv-assoc`, `kv-dissoc` | Map |
| Setlike | `set-member?`, `set-insert`, `set-remove` | Set |
| Functor | `fmap` | List |

Generic operations (`map`, `filter`, `reduce`, `concat`, `length`, `any?`, `all?`, `find`) in `collections.prologos` use traits via the Seqable→transform→Buildable pattern. **These are compliant.**

### 2. Postfix Indexing (`xs[0]`): PRINCIPLE VIOLATION

**Principle**: "Collection abstractions are decoupled from their concrete backends. Users program against traits; implementations are swappable with zero code changes." (DESIGN_PRINCIPLES.org §Collections and Backends)

**Actual**: `expr-get` in `reduction.rkt` pattern-matches on concrete constructors:

```
expr-get coll key →
  match coll:
    expr-champ → map-get (CHAMP/Map)
    expr-rrb   → rrb-get (RRB/PVec)
    cons-chain → list-ref (List)
    else       → stuck
```

Does NOT dispatch through `Indexed` or `Keyed` traits. Adding a new indexable collection requires modifying `reduction.rkt`.

### 3. Map-Get / Dot-Access: PARTIAL VIOLATION

`map-get` in reduction dispatches on `expr-champ` constructor directly, not through `Keyed` trait. However, `map-get` on **schema-typed** values correctly narrows to the declared field type (typing-core.rkt lines 1284-1296).

Dot-access (`user.name` → `[map-get user :name]`) is hardcoded to maps — does not abstract over `Keyed`.

### 4. Broadcast (`.*field`): PRINCIPLE VIOLATION

`expr-broadcast-get` in reduction.rkt walks **only cons/nil list structure**. Does not handle PVec, Set, or any Seqable collection. The `list-cons?`/`list-nil?` helpers match bare, qualified, and typed constructors — but only for the List type.

**Impact**: `@[{:x 1} {:x 2}].*x` (PVec of maps) produces a stuck term.

### 5. Get-In / Update-In: PARTIAL COMPLIANCE

Hardcoded to `expr-map-get` for navigation. Works correctly for nested maps but does not generalize to `Keyed` or `Indexed` for mixed-collection paths.

### 6. Trait Resolution on Union Types: NOT SUPPORTED

`trait-resolution.rkt` has no mechanism to resolve traits when the type argument is a union. If `x : <Int | String>` and both implement `Show`, `[show x]` cannot resolve. The `ground-expr?` function is also missing an explicit `expr-union` case (falls to conservative `#t` default — happens to be correct but fragile).

### 7. Open-Map Value Typing: DESIGN TENSION

When a map has heterogeneous values, type widening produces `(Map Keyword <String | Int | ...>)`. Accessing any key returns the full union. This is technically correct but works against usability — the user knows `:name` is a String, but the type system doesn't without a schema.

**Schema narrowing IS implemented**: `map-get` on schema-typed values returns the declared field type. The gap is for unschema'd maps where inference produces overly-wide unions.

### 8. Dot-Brace Path Expansion (`.{field1 field2}`): NOT IMPLEMENTED

The reader has NO `dot-lbrace` token type. The `.{` syntax for branching dot-access is not tokenized at all. This was marked as deferred in Phase 7c but the design doc progress tracker should reflect this accurately.

### 9. Nested Collection Inference: PARTIAL

- Nested homogeneous collections work (list of lists, etc.)
- Nested heterogeneous collections hit the QTT union gap (now fixed: `08fa7d1`)
- Nested list literals `'[1 '[20 '[300]]]` reportedly hit "Could not infer type" — likely a parser issue with nested quote

### 10. Preparse Dash-List Handling: WORKING (with caveats)

The preparse correctly handles multi-line dash items when indentation is consistent:

```
:items
  - :name "Alice"
    :role :super
```

Produces: `$vec-literal ($brace-params :name "Alice" :role :super)`.

The earlier "flattening bug" report was based on inline-dash with different indent structure. The `-` alone on its own line with children at uniform indent works correctly (as shown by `app-config` in the acceptance file working).

---

## Principle Violations Summary

| Principle | Section | Status |
|-----------|---------|--------|
| Collections decoupled from backends | §Decomplection | **VIOLATED** — indexing, broadcast, get-in hardcoded to constructors |
| Most Generalizable Interface | §Most Generalizable Interface | **VIOLATED** — `get`/`set` not trait-dispatched |
| Seq as Universal Hub | §Patterns (Collection Conventions) | **PARTIALLY COMPLIANT** — generic ops use Seq; indexing/broadcast do not |
| Traits over concrete types | §Most Generalizable Interface | **VIOLATED** — reduction engine bypasses traits |
| Open extension, closed verification | §Open Extension | **PARTIALLY VIOLATED** — new collection types can't participate in `[n]` or `.*` syntax |

---

## Root Cause: Phase Separation

The gap originates from a phase separation between the type system and the reduction engine:

1. **Trait system** (elaboration/typing): Resolves trait constraints, threads dictionary parameters — operates at **compile time**
2. **Reduction engine** (reduction.rkt): Evaluates terms by pattern-matching on constructors — operates at **runtime**

The `Indexed` and `Keyed` traits are compile-time constraints that generate dictionary parameters. But the postfix indexing syntax (`xs[0]`) elaborates directly to `expr-get`, which bypasses the trait system entirely and dispatches via constructor matching in reduction.

**To close this gap**: Either (a) `expr-get` must elaborate to trait-dispatched calls that thread dicts, or (b) the reduction engine must be able to dynamically dispatch through reified trait dictionaries.

---

## Design: Phased Approach

### Phase 1: `expr-get` via Indexed/Keyed Trait Dispatch

**Goal**: `xs[0]` works uniformly for any type implementing `Indexed`.

**Approach**: At elaboration time, when `surf-get` is encountered:
1. Infer the collection type
2. If it implements `Indexed`, elaborate to `[idx-nth $indexed-dict coll key]`
3. If it implements `Keyed`, elaborate to `[kv-get $keyed-dict coll key]`
4. Fall back to current `expr-get` for backward compatibility

**Key files**: `elaborator.rkt` (surf-get elaboration), `typing-core.rkt` (constraint generation)

**Implication**: Postfix `[n]` becomes sugar for trait method call. Any user-defined type implementing `Indexed` gets postfix indexing for free.

### Phase 2: Broadcast Generalization

**Goal**: `xs.*field` works for any Seqable collection, not just List.

**Approach**: In reduction, instead of walking cons/nil:
1. Convert target to sequence via `Seqable.to-seq`
2. Map the field extraction over the sequence
3. Collect results via `Buildable.from-seq`

Or simpler: convert PVec/Set to List first, then use existing cons/nil walking.

**Key files**: `reduction.rkt` (expr-broadcast-get case)

### Phase 3: Dot-Brace Path Expansion

**Goal**: `m.{name age}` works as branching dot-access.

**Approach**: Add `dot-lbrace` token to reader for `.{` (no space). Preparse rewrites to `(get-in m :name :age)` branching path form.

**Key files**: `reader.rkt` (tokenization), `macros.rkt` (sentinel rewriting)

### Phase 4: Union-Aware Trait Dispatch

**Goal**: Trait methods resolve on union types when all union members implement the trait.

**Approach**: In trait resolution, when the type argument is `expr-union`:
1. Try resolving the trait for each union member
2. If all members resolve, generate a runtime dispatch wrapper
3. This is a significant architectural addition — may be deferred

**Key files**: `trait-resolution.rkt`, `elaborator.rkt`

### Phase 5: Open-Map Value Typing Revisit

**Goal**: Determine whether `map-get` on unschema'd heterogeneous maps should return `_`/`Any` instead of the full union.

**Approach**: Design discussion needed. Options:
- Status quo (union): Precise but unusable without narrowing
- Dynamic (`_`): Permissive but loses type safety
- Schema-first: Encourage schema usage, keep union for untyped maps

This is a design philosophy question, not an implementation question.

---

## Immediate Fixes (Pre-Phase)

These are small completeness fixes that should land before the phased work:

1. **`ground-expr?` in trait-resolution.rkt**: Add explicit `expr-union` case:
   ```racket
   [(expr-union l r) (and (ground-expr? l) (ground-expr? r))]
   ```

2. **Design doc progress tracker**: Update Phase 7c status to clarify that dot-brace expansion is NOT done. Only `get-in` with `:key^alias` works.

3. **Acceptance file annotations**: Document known limitations in §U section (already done in `08fa7d1`).

---

## Key Files

| File | Role |
|------|------|
| `lib/prologos/core/collection-traits.prologos` | Trait definitions |
| `lib/prologos/core/collections.prologos` | Generic operations |
| `racket/prologos/reduction.rkt` | Runtime dispatch (lines 2086-2122, 3377-3449) |
| `racket/prologos/elaborator.rkt` | Elaboration of surf-get |
| `racket/prologos/typing-core.rkt` | Map type inference, schema narrowing |
| `racket/prologos/trait-resolution.rkt` | Trait dispatch, ground-expr? |
| `racket/prologos/reader.rkt` | Tokenization (missing dot-lbrace) |
| `racket/prologos/macros.rkt` | Preparse rewriting |
| `racket/prologos/qtt.rkt` | QTT expr-union case (fixed: `08fa7d1`) |

---

## Relationship to Principles

This audit confirms that the **library layer** is well-designed and principled — collection traits exist, instances are implemented, generic operations use Seq as the hub. The gap is in the **compiler layer** where the reduction engine and elaborator bypass the trait system for syntactic sugar operations (indexing, dot-access, broadcast, path traversal).

The phased design above proposes closing this gap by making syntactic sugar elaborate through traits rather than directly to constructor-specific AST nodes. This aligns with:

- **Decomplection** (§Collections and Backends): backends become truly swappable
- **Most Generalizable Interface**: `get` dispatches through the widest applicable trait
- **Open Extension, Closed Verification**: new types participate in syntax without compiler changes
- **First-Class by Default**: traits are first-class dispatch mechanisms, not just constraints
