# Prologos Core Data Structures — Roadmap & Work Log

**Created**: 2026-02-19
**Implementation guide**: `IMPLEMENTATION_GUIDE_CORE_DS_PROLOGOS.md` (1768 lines)
**Memory roadmap**: `memory/core-ds-roadmap.md`
**Purpose**: Track implementation progress for the core data structures. Cross-referenced against commit history, implementation guide, and test counts.

---

## Status Legend

- ✅ **Done** — implemented, tested, merged
- 🔧 **In Progress** — actively being worked on
- ⬜ **Not Started** — planned but no work yet
- ⏭️ **Deferred** — consciously postponed with rationale

---

## Architecture Overview

The Prologos data structure system follows a **Seq-centric** architecture:

1. **4-layer abstraction**: User-facing types → Smart defaults → Explicit variants → Backend implementations
2. **Persistence + structural sharing** — All collections are immutable; updates share structure (O(log n) additional space)
3. **Seq as universal abstraction** — Every collection implements `Seqable` (to-seq) and `Buildable` (from-seq), enabling type-preserving generic operations: `Vec → Seq → transform → Vec`
4. **QTT multiplicities** — Linear types track resource usage; transients (Phase 2d) will use scoped mutation with linear safety
5. **Lattice compatibility** — Collections designed for future integration with LVars and propagator networks

**Key backends:**
- **RRB-Tree** (Relaxed Radix Balanced Tree) — `rrb.rkt` (18 KB) — O(log n) access/update/append for `PVec`
- **CHAMP** (Compressed Hash Array Mapped Prefix-tree) — `champ.rkt` (19 KB) — Efficient persistent hashing for `Map` and `Set`
- **Thunked cons** — `LSeq` lazy sequences via thunk-based cons cells for potentially-infinite sequences

**Literal syntax:**

| Syntax | Type | Example |
|--------|------|---------|
| `'[1 2 3]` | `List Nat` | List literal (cons/nil) |
| `@[1 2 3]` | `PVec Nat` | Persistent vector literal |
| `{:name "Alice" :age 30}` | `Map Keyword Nat` | Hash map literal |
| `#{1 2 3}` | `Set Nat` | Hash set literal |
| `~[1 2 3]` | `LSeq Nat` | Lazy sequence literal |

---

## Phase 0: Trait + Seq Foundation ✅ COMPLETE

**Goal**: Build the trait hierarchy and lazy sequence infrastructure that all collections depend on.
**Commits**: `260afc5` (LSeq), `96f3a4c` (Hashable), `10dd0d4` (Collection traits), `171de29` (Generic ops), `b12010e` (Eq/Ord extended)
**Guide reference**: Section 3 (Prerequisites), Section 7 (Seq)

### LSeq (Lazy Sequences)

**Commit `260afc5`**: "Add LSeq lazy sequence data type with 9 core operations"

- `lseq.prologos` — `lseq-nil`, `lseq-cell` (thunk-based lazy cons)
- `lseq-ops.prologos` — `list-to-lseq`, `lseq-to-list`, `lseq-map`, `lseq-filter`, `lseq-take`, `lseq-drop`, `lseq-append`, `lseq-fold`, `lseq-length`
- Uses `(fn [_ : Unit] body)` thunks for laziness — forces on demand
- 28 tests in `test-lseq.rkt`

### Hashable Trait

**Commit `96f3a4c`**: "Add Hashable trait with hash-combine and instances for Nat/Bool/Ordering"

- `hashable-trait.prologos` — `Hashable {A}` with `hash : A -> Nat` method
- `hash-combine` utility for composite hashing
- `hashable-instances.prologos` — Nat, Bool, Ordering instances + `hash-option`, `hash-list` utilities
- Tests in `test-hashable.rkt`

### Collection Trait Hierarchy

**Commit `10dd0d4`**: "Add collection trait hierarchy and List instances for Seqable/Buildable/Indexed"

- `seqable-trait.prologos` — `to-seq : C A -> Seq A`
- `buildable-trait.prologos` — `from-seq : Seq A -> C A` + `empty : C A`
- `indexed-trait.prologos` — `nth`, `length`, `update` for indexed collections
- `keyed-trait.prologos` — `get`, `assoc`, `dissoc` for key-value maps
- `setlike-trait.prologos` — `member?`, `insert`, `remove`
- `foldable-trait.prologos` — `fold` operation
- `functor-trait.prologos` — `map` operation
- List instances: `seqable-list.prologos`, `buildable-list.prologos`, `indexed-list.prologos`, `functor-list.prologos`, `foldable-list.prologos`
- 26 tests in `test-collection-traits.rkt`

### Generic Collection Operations

**Commit `171de29`**: "Add generic collection operations using Seq-centric architecture"

- `collection-ops.prologos` — `coll-map`, `coll-filter`, `coll-length`, `coll-to-list`
- Demonstrates Seq-centric pattern: `to-seq → transform → from-seq`
- ~18 tests in `test-generic-ops.rkt`

### Additional Foundation

**Commit `b12010e`**: "Extend Eq/Ord instances to Bool/Ordering and add PartialOrd trait"

- `partialord-trait.prologos` — partial ordering for types without total order
- `eq-derived.prologos` — derived equality utilities
- Extended Eq/Ord instances for Bool, Ordering

---

## Phase 1: User-Facing Collection Types ✅ ALL COMPLETE

### Phase 1a: Persistent Vector / RRB-Tree + `@[...]` ✅ COMPLETE

**Goal**: Indexed persistent vector backed by RRB-Tree.
**Commit**: `7515b56` — "Phase 1a: Persistent Vector (RRB-Tree) + PVec type + @[...] literal syntax"
**Guide reference**: Section 4.1, Section 5.2

#### What was built

- `rrb.rkt` — Pure Racket RRB-Tree implementation (18 KB)
  - O(log32 n) access, update, and append
  - Structural sharing for persistence
  - Relaxed radix balance for efficient concatenation
- AST nodes: `expr-PVec`, `expr-pvec`, `expr-pvec-empty`, `expr-pvec-get`, `expr-pvec-set`, `expr-pvec-push`, `expr-pvec-pop`, `expr-pvec-length`, `expr-pvec-to-list`
- Full 14-file pipeline integration
- `@[...]` literal syntax in both WS reader (`at-lbracket` token) and sexp readtable
- `$vec-literal` preparse macro → nested `pvec-push` from `pvec-empty`
- Seqable + Buildable + Indexed trait instances

#### Tests

- Tests in `test-pvec.rkt` (type formation, literals, operations, trait instances)

---

### Phase 1b: Persistent Hash Map / CHAMP + `{...}` ✅ COMPLETE

**Goal**: Key-value persistent hash map backed by CHAMP.
**Commit**: `f299f6f` — "Phase 1b: Persistent Hash Map (CHAMP) + Keyword type + {…} literal syntax"
**Guide reference**: Section 4.2, Section 5.1

#### What was built

- `champ.rkt` — Pure Racket CHAMP implementation (19 KB)
  - Bitmap-compressed nodes (datamap + nodemap bitmaps)
  - 32-way branching with hash fragment extraction
  - Canonical form (structure uniquely determined by contents)
  - Supports both Map (key→value) and Set (key→#t sentinel)
- AST nodes: `expr-Map`, `expr-hmap`, `expr-map-empty`, `expr-map-get`, `expr-map-set`, `expr-map-delete`, `expr-map-has-key`, `expr-map-size`, `expr-map-keys`, `expr-map-vals`, `expr-map-to-list`
- `Keyword` primitive type added (for map keys): `expr-Keyword`, `expr-keyword`
- `{k: v ...}` literal syntax in both readers
- Keyed + Seqable + Buildable trait instances

#### Tests

- Tests in `test-map.rkt` (type formation, literals, operations, keyword type, trait instances)

---

### Phase 1c: `~[...]` Seq Literal Syntax ✅ COMPLETE

**Goal**: Ergonomic syntax for lazy sequence construction.
**Commit**: `7a68889` — "Phase 1c: ~[...] Seq literal syntax for LSeq lazy sequences"
**Guide reference**: Section 4.5

#### What was built

- `~[` tokenization in WS reader (`tilde-lbracket` token) + sexp readtable (`#\~` terminating macro with `[` lookahead)
- `$lseq-literal` preparse macro → nested `lseq-cell`/`lseq-nil` with thunk wrapping
- `try-as-lseq` pretty-print detection — recognizes `lseq-cell`/`lseq-nil` patterns and renders as `~[...]`

#### Tests

- 25 tests in `test-lseq-literal.rkt`

---

## Phase 2: Optimized Backends ✅ PARTIALLY COMPLETE (2a–2c done, 2d not started)

### Phase 2a: Persistent Set + `#{...}` ✅ COMPLETE

**Goal**: Persistent hash set backed by CHAMP (reusing Map infrastructure).
**Commit**: `0981d9c` — "Phase 2a: Persistent Set (Set A) with #{...} literal syntax"
**Guide reference**: Section 4.3

#### What was built

- `Set A` type — reuses `champ.rkt` CHAMP trie with `#t` sentinel values (**zero changes to champ.rkt**)
- 11 AST nodes: `expr-Set`, `expr-hset`, `expr-set-empty`, `expr-set-insert`, `expr-set-member`, `expr-set-delete`, `expr-set-size`, `expr-set-union`, `expr-set-intersect`, `expr-set-diff`, `expr-set-to-list`
- Full 14-file pipeline: syntax, substitution, zonk, pretty-print, typing-core, qtt, reduction, unify, surface-syntax, parser, elaborator, macros
- `#{...}` literal syntax: WS reader (`hash-lbrace` token) + sexp readtable (`#` terminating-macro with `{` lookahead)
- `prologos.data.set` stdlib: `set-singleton`, `set-from-list`, `set-symmetric-diff`

#### Tests

- 45 tests in `test-set.rkt`
- **Test count after phase**: 2198 total passing

---

### Phase 2b: Extended List Standard Library ✅ COMPLETE

**Goal**: Rich stdlib for the cons-list type.
**Commit**: `fadbec5` — "Phase 2b: Extended List standard library with 15 new functions"
**Guide reference**: Section 4.4

#### What was built

- 15 new stdlib functions in `list.prologos`:
  - `reduce1`, `foldr1` — folds without explicit initial value
  - `init` — all elements except the last
  - `scanl` — running fold results
  - `iterate-n` — generate list by repeated application
  - `span`, `break` — split list at predicate boundary
  - `intercalate` — interleave separator element
  - `dedup` — remove consecutive duplicates
  - `is-prefix-of`, `is-suffix-of` — list prefix/suffix checks
  - `delete` — remove first occurrence
  - `find-index` — index of first match
  - `count` — count elements matching predicate
  - `sort-on` — sort by key extraction function
- No AST pipeline changes — purely stdlib enrichment
- `'[...]` literal syntax already worked end-to-end

#### Tests

- 49 tests in `test-list-extended.rkt`
- **Test count after phase**: 2247 total passing

---

### Phase 2c: Pipe / Compose / Transducers ✅ COMPLETE

**Goal**: Ergonomic data pipeline operators and single-pass fusion.
**Commit**: `fbaf666` — "feat: block-form |> pipe macro with automatic loop fusion"
**Guide reference**: Section 12.2

#### What was built

**Pipe operator (`|>`):**
- `|>` → `$pipe-gt` sentinel symbol (avoids Racket `|` quoting issues)
- Infix: `x |> f |> g` canonicalized to `($pipe-gt x (f) (g))` by `canonicalize-infix-pipe`
- Block form: multi-line pipe with automatic loop fusion

```
|> xs
  map f
  filter p
  reduce rf z
```

→ Fused single-pass `(reduce <composed-fn> z xs)` via inline reducer composition

**Compose operator (`>>`):**
- `>>` → `$compose` sentinel symbol
- `f >> g >> h` → left-to-right function composition

**Loop fusion:**
- **Step classification**: fusible (map/filter/remove), terminal (reduce/sum/length/count), barrier (sort/reverse), plain (everything else)
- **Terminal fusion achieves O(n)**: `build-fused-reducer` composes map/filter/remove into one inline reducer function — no intermediate lists
- **Materialization**: Without a terminal, fusible steps emit `(filter p (map f xs))` — multi-pass but correct

**Transducers:**
- `transducer.prologos` stdlib: `map-xf`, `filter-xf`, `remove-xf`, `xf-compose`, `transduce`, `into-list-rev`, `into-list`, `list-conj`
- R-polymorphic: `forall R. (R -> B -> R) -> (R -> A -> R)` — standard `>>` compose doesn't work because it doesn't thread R; use `xf-compose` instead

#### Key Lessons

- Separate `angle-depth` counter needed (not `bracket-depth`) so `>>` works inside `[...]`
- `_` in pipe is top-level only — `_` inside sublists preserved for closure holes
- Preparse layer (datum→datum) handles all pipe/compose rewriting — no new AST nodes
- Higher-rank type inference limitation: `transduce`/`into-list`/`xf-compose` with `{A B : Type}` implicit binders fail implicit inference — forced inline reducer approach

#### Tests

- 69 tests in `test-pipe-compose.rkt`

---

### Phase 2d: Mutable Transient Builders ⬜ NOT STARTED

**Goal**: Scoped mutation for efficient batch construction.
**Guide reference**: Section 5.6

- Transient versions of Vec, Map, Set for O(1) amortized mutation during construction
- QTT linear safety: transient handle must be used exactly once (then converted back to persistent)
- Dependencies: Phase 1a (Vec), Phase 1b (Map)

---

## Phase 3: Specialized Structures ⬜ NOT STARTED

| Sub-phase | Structure | Backend | Guide | Notes |
|-----------|-----------|---------|-------|-------|
| 3a | SortedMap + SortedSet | B+ Tree | Section 6.1 | Ordered key-value / ordered set |
| 3b | Deque | Finger Tree | Section 6.2 | Double-ended queue |
| 3c | PriorityQueue | Pairing Heap | Section 6.3 | Min/max extraction |
| 3d | LVars + Logical Variables | — | Section 8.1 | Monotonic lattice variables |
| 3e | LVar-Map + LVar-Set | — | Section 8.2, 8.3 | Lattice-compatible collections |
| 3f | Propagator Network | — | Section 8.4 | Constraint propagation cells |
| 3g | Length-Indexed Vec | — | Section 9.1 | Dependent types over collections |

---

## Phase 4: Integration + Advanced ⬜ NOT STARTED

| Sub-phase | Feature | Guide | Notes |
|-----------|---------|-------|-------|
| 4a | QTT Proof Erasure | Section 9.4 | Erase type-level proofs at runtime |
| 4b | CRDT Collections | Section 8.5 | Conflict-free replicated data types |
| 4c | Actor/Place Integration | Section 11.4 | Cross-actor persistent collections |
| 4d | ConcurrentMap (Ctrie) | Section 6.4 | Lock-free concurrent hash map |
| 4e | SymbolTable (ART) | Section 6.5 | Adaptive Radix Tree for string keys |
| 4f | UnionFind (Persistent) | Section 6.6 | Persistent union-find |

---

## AST Node Inventory

| Type | Nodes | Description |
|------|-------|-------------|
| PVec | 9 | Type, literal, empty, get, set, push, pop, length, to-list |
| Map | 11 | Type, literal, empty, get, set, delete, has-key?, size, keys, vals, to-list |
| Set | 11 | Type, literal, empty, insert, member?, delete, size, union, intersect, diff, to-list |
| Keyword | 2 | Type, literal |
| LSeq | — | Defined via `data` declaration (lseq-nil, lseq-cell) — no AST nodes |

**Total data structure AST nodes: ~33** (plus ~20 from collection trait infrastructure)

---

## Dependency Graph

```
Phase 0 (Trait + Seq) ✅
  |---> Phase 1a (Vec/RRB)    ✅  [independent]
  |---> Phase 1b (Map/CHAMP)  ✅  [independent]
  '---> Phase 1c (~[] syntax) ✅  [independent]
        |---> Phase 2a (Set)  ✅    [needs 1b CHAMP]
        |---> Phase 2b (List stdlib)  ✅ [needs Phase 0 only]
        |---> Phase 2c (Pipe/Compose) ✅ [needs Phase 0 only]
        '---> Phase 2d (Transients)            [needs 1a, 1b]
              |---> Phase 3a-c (Sorted, Deque, PQ)
              |---> Phase 3d-f (LVars, Propagators)
              |     '---> Phase 3g (Dependent Vec)
              |           '---> Phase 4a (QTT Erasure)
              '---> Phase 4b-f (CRDT, Actors, Ctrie, ART, UnionFind)
```

---

## Test Summary

| Test File | Count | Phase | Purpose |
|-----------|-------|-------|---------|
| `test-lseq.rkt` | 28 | 0 | LSeq lazy sequences |
| `test-hashable.rkt` | ~15 | 0 | Hashable trait + instances |
| `test-collection-traits.rkt` | 26 | 0 | Collection trait hierarchy |
| `test-generic-ops.rkt` | ~18 | 0 | Generic coll-map/filter/length |
| `test-pvec.rkt` | ~30 | 1a | Persistent vector (RRB-Tree) |
| `test-map.rkt` | ~30 | 1b | Hash map (CHAMP) + Keyword |
| `test-lseq-literal.rkt` | 25 | 1c | `~[...]` literal syntax |
| `test-set.rkt` | 45 | 2a | Hash set (CHAMP-backed) |
| `test-list-extended.rkt` | 49 | 2b | Extended list stdlib |
| `test-list-literals.rkt` | ~15 | — | `'[...]` list literal syntax |
| `test-pipe-compose.rkt` | 69 | 2c | Pipe, compose, transducers |
| `test-transducer.rkt` | ~10 | 2c | Transducer operations |

**Total data-structure-specific tests: ~360**

---

## Stdlib File Inventory

### Data Types (`lib/prologos/data/`)

| File | Type | Key Exports |
|------|------|-------------|
| `list.prologos` | `List A` | `nil`, `cons`, `head`, `tail`, `length`, `map`, `filter`, `reduce`, `reverse`, `append`, `zip`, `take`, `drop`, + 15 extended functions |
| `lseq.prologos` | `LSeq A` | `lseq-nil`, `lseq-cell` |
| `lseq-ops.prologos` | — | `list-to-lseq`, `lseq-to-list`, `lseq-map`, `lseq-filter`, `lseq-take`, `lseq-drop`, `lseq-append`, `lseq-fold`, `lseq-length` |
| `set.prologos` | `Set A` | `set-singleton`, `set-from-list`, `set-symmetric-diff` |
| `transducer.prologos` | — | `map-xf`, `filter-xf`, `remove-xf`, `xf-compose`, `transduce`, `into-list-rev`, `into-list`, `list-conj` |
| `nat.prologos` | `Nat` | `add`, `mult`, `pred`, `sub`, etc. (Peano type-level) |
| `option.prologos` | `Option A` | `some`, `none`, `map-option`, `flat-map-option` |
| `ordering.prologos` | `Ordering` | `lt-ord`, `eq-ord`, `gt-ord` |
| `either.prologos` | `Either A B` | `left`, `right`, `map`, `flat-map`, `to-option` |
| `datum.prologos` | `Datum` | `datum-sym`, `datum-kw`, `datum-nat`, `datum-int`, `datum-rat`, `datum-bool`, `datum-nil`, `datum-cons` |

### Collection Traits (`lib/prologos/core/`)

| File | Trait | Method | Purpose |
|------|-------|--------|---------|
| `seqable-trait.prologos` | Seqable | `to-seq` | Convert to lazy sequence |
| `buildable-trait.prologos` | Buildable | `from-seq`, `empty` | Construct from sequence |
| `indexed-trait.prologos` | Indexed | `nth`, `length`, `update` | Positional access |
| `keyed-trait.prologos` | Keyed | `get`, `assoc`, `dissoc` | Key-value lookup |
| `setlike-trait.prologos` | Setlike | `member?`, `insert`, `remove` | Set membership |
| `foldable-trait.prologos` | Foldable | `fold` | Structural fold |
| `functor-trait.prologos` | Functor | `map` | Structure-preserving map |
| `hashable-trait.prologos` | Hashable | `hash` | Hashing for maps/sets |
| `seq-trait.prologos` | Seq | `first`, `rest`, `empty?` | Sequence protocol |
| `collection-ops.prologos` | — | `coll-map`, `coll-filter`, `coll-length`, `coll-to-list` | Generic operations |

### List Instances (`lib/prologos/core/`)

| File | Trait Implemented |
|------|-------------------|
| `seqable-list.prologos` | Seqable for List |
| `buildable-list.prologos` | Buildable for List |
| `indexed-list.prologos` | Indexed for List |
| `functor-list.prologos` | Functor for List |
| `foldable-list.prologos` | Foldable for List |

---

## Key Implementation Files

| File | Size | Purpose |
|------|------|---------|
| `rrb.rkt` | 18 KB | RRB-Tree implementation for PVec |
| `champ.rkt` | 19 KB | CHAMP trie implementation for Map/Set |
| `syntax.rkt` | — | All collection AST node definitions |
| `reduction.rkt` | — | Collection operation reduction rules |
| `typing-core.rkt` | — | Type rules for collection operations |
| `macros.rkt` | — | `$vec-literal`, `$set-literal`, `$lseq-literal`, `$pipe-gt`, `$compose` preparse macros |
| `reader.rkt` | — | `@[`, `~[`, `#{`, `{` token handlers |
| `sexp-readtable.rkt` | — | `@`, `~`, `#`, `{` readtable handlers |

---

## Cross-References

| Document | Contents |
|----------|----------|
| `IMPLEMENTATION_GUIDE_CORE_DS_PROLOGOS.md` | Full specification — 14 sections, 1768 lines |
| `memory/core-ds-roadmap.md` | Concise phase status + dependency graph |
| `MEMORY.md` | Living project state — test counts, architectural patterns |
| `docs/tracking/2026-02-19_NUMERICS_TOWER_ROADMAP.md` | Companion tracking doc for numerics |
| `docs/tracking/2026-02-19_HOMOICONICITY_ROADMAP.md` | Homoiconicity roadmap (related: literal syntax sentinels) |
| `memory/sprint1.1-lessons.md` | Sprint 1.1 extended list stdlib lessons |

---

## Session Log

### Phase 0: Trait + Seq Foundation
- **Commit `260afc5`**: "Add LSeq lazy sequence data type with 9 core operations" — 28 tests
- **Commit `96f3a4c`**: "Add Hashable trait with hash-combine and instances for Nat/Bool/Ordering"
- **Commit `10dd0d4`**: "Add collection trait hierarchy and List instances for Seqable/Buildable/Indexed" — 26 tests
- **Commit `171de29`**: "Add generic collection operations using Seq-centric architecture" — ~18 tests
- **Commit `b12010e`**: "Extend Eq/Ord instances to Bool/Ordering and add PartialOrd trait"

### Phase 1a: Persistent Vector
- **Commit `7515b56`**: "Phase 1a: Persistent Vector (RRB-Tree) + PVec type + @[...] literal syntax"
- RRB-Tree implementation (18 KB), 9 AST nodes, `@[...]` syntax

### Phase 1b: Persistent Hash Map
- **Commit `f299f6f`**: "Phase 1b: Persistent Hash Map (CHAMP) + Keyword type + {…} literal syntax"
- CHAMP implementation (19 KB), 11 AST nodes, `{k: v}` syntax, new Keyword type

### Phase 1c: LSeq Literal Syntax
- **Commit `7a68889`**: "Phase 1c: ~[...] Seq literal syntax for LSeq lazy sequences"
- `~[...]` tokenization + `$lseq-literal` preparse macro — 25 tests

### Phase 2a: Persistent Set
- **Commit `0981d9c`**: "Phase 2a: Persistent Set (Set A) with #{...} literal syntax"
- 11 AST nodes, reuses CHAMP with #t sentinel, `#{...}` syntax — 45 tests
- **Test count after phase**: 2198 total passing

### Phase 2b: Extended List Stdlib
- **Commit `fadbec5`**: "Phase 2b: Extended List standard library with 15 new functions"
- Pure stdlib enrichment, no pipeline changes — 49 tests
- **Test count after phase**: 2247 total passing

### Phase 2c: Pipe / Compose / Transducers
- **Commit `fbaf666`**: "feat: block-form |> pipe macro with automatic loop fusion"
- `|>` block-form with loop fusion, `>>` compose, transducer stdlib — 69 tests
- Step classification: fusible/terminal/barrier/plain
- Terminal fusion achieves O(n) single-pass
