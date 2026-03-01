# Standard Library Consolidation: Collapsed Namespaces for Source-Level Discovery

## Status: DESIGN (not yet approved for implementation)

## Problem Statement

The Prologos standard library has **126 standalone `.prologos` files** (104 in `core/`,
22 in `data/`) — these are the files the compiler loads and that jump-to-definition
lands on. They are shattered into fragments too small to support discovery.

### Fragmentation by the numbers

| Category | Files | Median size | Example |
|----------|-------|-------------|---------|
| Trait definitions | 31 | 15 lines | `has-top-trait.prologos` (10 lines) |
| Trait instances | 52 | 14 lines | `foldable-list.prologos` (13 lines) |
| Operation modules | 8 | 62 lines | `set-ops.prologos` (33 lines) |
| Data types | 22 | 79 lines | `list.prologos` (537 lines) |

52 core files are under 20 lines. The arithmetic family alone spans 13 files
(`add-trait`, `add-instances`, `sub-trait`, `sub-instances`, ... `abs-instances`)
that together total 427 lines — a single readable scroll.

### The discovery experience today

A developer does jump-to-definition on `add`:

```
→ Lands in add-trait.prologos (26 lines)
→ Sees: trait definition, one doc comment
→ Doesn't see: which types implement Add, what instances look like,
  how Add relates to Sub/Mul/Div, the algebraic laws
→ Must manually open: add-instances.prologos, sub-trait.prologos, ...
```

Compare what we *want*:

```
→ Lands in arithmetic.prologos (~430 lines)
→ Sees: Add trait + 7 instances, Sub trait + 6 instances, Mul, Div, Neg, Abs
→ Scrolling up/down reveals the entire arithmetic story
→ Discovery by proximity, not by file navigation
```

### Why fragmentation happened

Modules were split into tiny files because of dependency ordering constraints in
the original single-pass compiler. With the **3-phase parser** (Phases 5a-5c: free
ordering), forms within a module can reference each other freely — forward references
are resolved across all three passes. The original pressure to fragment is gone.

### The `clojure.core` lesson

`clojure.core` is ~8000 lines in one file. You can scroll through it. `map` lives
near `filter` lives near `reduce`. `assoc` lives near `dissoc` lives near `get`.
Discovery happens by proximity, not by file navigation.

We don't need one giant file. But we need files organized around *topics*, not
around *compiler compilation units*.

## Design: Consolidated Standalone Files with Collapsed Namespaces

### Architecture

```
core/eq.prologos                   (consolidated source, authored)
  ns prologos::core::eq
  - Eq trait definition
  - eq-derived helpers (neq, eq-fold, etc.)
  - Eq instances: Nat, Bool, Int, Rat, Posit8-64, Char, String

core/list.prologos                 (consolidated source, authored)
  ns prologos::core::list
  - Seqable List instance
  - Buildable List instance
  - Foldable List instance
  - Reducible List instance
  - Indexed List instance
  - Functor List instance
  - Seq List instance

book/equality.prologos             (separate narrative, references core/eq)
book/lists.prologos                (separate narrative, references core/list + data/list)
```

**The standalone files are the source of truth for compilation.** The book keeps
its own identity as narrative documentation — it tells the *story* of each topic,
while the standalone files are the *code* that the compiler loads and that
jump-to-definition points at.

### Two design dimensions

**Collection instances → group by TYPE.** When a developer asks "what can I do with
a PVec?", the answer should be one file. All trait instances for PVec (Seqable,
Buildable, Foldable, Reducible, Indexed, Functor) plus PVec-specific operations
live in `prologos::core::pvec`.

**Numeric/equality/ordering instances → group by TRAIT.** When a developer asks
"what types support Eq?", the answer should be one file. The Eq trait definition
plus all instances (Nat, Bool, Int, Rat, Posit, Char, String) live in
`prologos::core::eq`.

This follows the principle: *group by the axis that a developer is most likely to
explore*. For collections, you explore "what can this collection do?". For traits
like Eq/Ord/Add, you explore "what types have this capability?".

### The namespace map

#### Core: 104 files → 18 consolidated files

**Equality & Ordering (3 files)**

| New namespace | Merges from | Lines |
|---|---|---|
| `prologos::core::eq` | eq-trait (36), eq-instances (35), eq-numeric-instances (51), eq-char-instance (12), eq-string-instance (12), eq-derived (36) | ~182 |
| `prologos::core::ord` | ord-trait (103), partialord-trait (15), ord-instances (14), ord-numeric-instances (61), ord-char-instance (17), ord-string-instance (17) | ~227 |
| `prologos::core::hashable` | hashable-trait (26), hashable-instances (59), hashable-char-instance (14), hashable-string-instance (14) | ~113 |

**Arithmetic (2 files)**

| New namespace | Merges from | Lines |
|---|---|---|
| `prologos::core::arithmetic` | add-trait (26), add-instances (51), add-string-instance (12), sub-trait (18), sub-instances (51), mul-trait (24), mul-instances (51), div-trait (16), div-instances (45), neg-trait (20), neg-instances (45), abs-trait (23), abs-instances (45) | ~427 |
| `prologos::core::algebra` | numeric-bundles (36), additive-identity-trait (10), multiplicative-identity-trait (10), identity-instances (50), generic-numeric-ops (42), generic-arith (45), algebraic-laws (44) | ~237 |

**Collection traits & ops (3 files)**

| New namespace | Merges from | Lines |
|---|---|---|
| `prologos::core::collection-traits` | seqable-trait (16), buildable-trait (22), foldable-trait (13), reducible-trait (14), functor-trait (20), seq-trait (33), indexed-trait (18), keyed-trait (18), setlike-trait (15), collection-bundle (18), type-functors (20) | ~207 |
| `prologos::core::collections` | collection-fns (141), collection-ops (44), collection-conversions (61) | ~246 |
| `prologos::core::generic-ops` | generic-ops (66), seq-functions (62) | ~128 |

**Collection instances — by type (4 files)**

| New namespace | Merges from | Lines |
|---|---|---|
| `prologos::core::list` | seqable-list (14), buildable-list (31), foldable-list (13), reducible-list (18), indexed-list (42), functor-list (13), seq-list (34) | ~165 |
| `prologos::core::pvec` | seqable-pvec (16), buildable-pvec (24), foldable-pvec (18), reducible-pvec (18), indexed-pvec (32), functor-pvec (14), pvec-ops (31) | ~153 |
| `prologos::core::set` | seqable-set (16), buildable-set (27), foldable-set (16), reducible-set (18), setlike-set (27), set-ops (39) | ~143 |
| `prologos::core::lseq` | seqable-lseq (13), buildable-lseq (21), foldable-lseq (18), reducible-lseq (24), seq-lseq (33) | ~109 |

**Type conversions (1 file)**

| New namespace | Merges from | Lines |
|---|---|---|
| `prologos::core::conversions` | from-trait (12), tryfrom-trait (14), into-trait (19), fromint-trait (21), fromrat-trait (16), from-instances (88), tryfrom-instances (55), fromint-posit-instances (25), fromrat-posit-instances (25) | ~275 |

**Lattices & abstract domains (2 files)**

| New namespace | Merges from | Lines |
|---|---|---|
| `prologos::core::lattice` | lattice-trait (24), lattice-instances (163), has-top-trait (10), has-top-instances (23), bounded-lattice (13), widenable-trait (18), widenable-instances (53), galois-trait (25), galois-instances (36) | ~365 |
| `prologos::core::abstract-domains` | sign-lattice (74), sign-galois (50), parity-lattice (53), refined-int-instances (62), refined-rat-instances (46) | ~285 |

**Already-consolidated (3 files, no change)**

| Namespace | Lines | Notes |
|---|---|---|
| `prologos::core::string-ops` | 340 | Already one file |
| `prologos::core::propagator` | 66 | Self-contained |
| `prologos::core::map` ← keyed-map (30) + map-ops (77) | ~107 | Only 2 files to merge |

#### Summary

| Metric | Current | After |
|--------|---------|-------|
| Core source files | 104 | **18** |
| Core files under 20 lines | 52 | **0** |
| Core median file size | ~25 lines | **~200 lines** |
| Core largest file | 340 (string-ops) | **~430 (arithmetic)** |
| Unique `prologos::core::*` namespaces | 104 | **18** |

#### Data files: minimal changes

The 22 data files are already reasonable — most define data types, which are natural
units. Two optional merges:

| Potential merge | From | Lines | Rationale |
|---|---|---|---|
| `prologos::data::lseq` | lseq (38) + lseq-ops (79) | ~117 | Ops belong with the type |
| `prologos::data::refined` | refined-int (95) + refined-rat (80) | ~175 | Same concept, same story |

Remaining data files (never, ordering, parity, sign, char, string, map-entry, set,
pair, bool, either, result, transducer, option, datum, nat, list, eq) stay as they are.

### What the developer experiences after consolidation

**Jump-to-definition on `eq?`:**
→ Lands in `core/eq.prologos` (~182 lines)
→ Sees: Eq trait definition, derived helpers (`neq`, `eq-fold`), and ALL instances
  (Nat, Bool, Int, Rat, Posit8-64, Char, String)
→ Scrolling reveals the full equality story in one file

**Jump-to-definition on `reduce`:**
→ Lands in `core/collections.prologos` (~246 lines)
→ Sees: `reduce` near `map` near `filter` near `length` near `any?` near `all?`
→ The entire generic collection API in one scroll

**Jump-to-definition on `Seqable`:**
→ Lands in `core/collection-traits.prologos` (~207 lines)
→ Sees: all 10 collection trait definitions + the Collection bundle
→ Understanding "what abstractions exist" is a single file read

**Jump-to-definition on PVec's `Foldable` instance:**
→ Lands in `core/pvec.prologos` (~153 lines)
→ Sees: ALL trait instances for PVec + PVec-specific ops
→ "What can PVec do?" answered by one file

### Relationship to the book

The book keeps its own identity:

- **Book chapters** are narrative — they tell the *story* of a topic with prose
  commentary, pedagogical ordering, cross-references, and progressive disclosure.
  They serve readers who want to *learn*.

- **Standalone files** are the compilable source — organized for *working with* the
  code. Jump-to-definition, grep, and editor browsing all point here. They serve
  developers who want to *use* or *modify*.

The tangler relationship is preserved but may evolve:
- Currently: book chapters → tangle → 126 standalone files
- After: book chapters → tangle → 18 consolidated files (if the book module
  boundaries are updated to match), or book and standalone files are maintained
  independently (the book references the consolidated namespaces)

The book's OUTLINE and chapter structure can remain as is — chapters map to *topics*
which may span multiple consolidated namespaces. For example, the "Lists" chapter
covers both `prologos::data::list` (data type) and `prologos::core::list` (instances).

## Technical Implementation

### How namespace resolution changes

Current: `prologos::core::eq-trait` → `resolve-ns-path` → `core/eq-trait.prologos`
After: `prologos::core::eq` → `resolve-ns-path` → `core/eq.prologos`

The `resolve-ns-path` function in `namespace.rkt` splits on `::`, builds a file path.
**No change to the resolution mechanism.** Only the namespace names and file names change.

### What changes in each consolidated file

Each consolidated file has ONE `ns` declaration and merges all content:

```prologos
ns prologos::core::eq

require [prologos::data::nat :refer [nat-eq?]]
require [prologos::data::bool :refer [bool-eq?]]

;; ========================================
;; Eq Trait — equality comparison
;; ========================================

trait Eq {A}
  eq? : A A -> Bool
  :doc "Equality comparison for type A"
  :laws
    - :name "reflexive" ...
    - :name "symmetric" ...
    - :name "transitive" ...

;; ========================================
;; Eq Derived — derived equality operations
;; ========================================

spec neq : {A : Type} where (Eq A) A A -> Bool
defn neq [$dict x y]
  not [eq? x y]

;; ... more derived ops ...

;; ========================================
;; Instances
;; ========================================

impl Eq Nat
  defn eq? [x y] <Bool>
    nat-eq? x y

impl Eq Bool
  defn eq? [x y] <Bool>
    bool-eq? x y

impl Eq Int
  defn eq? [x : Int  y : Int] <Bool>
    int= x y

;; ... all other Eq instances ...
```

The 3-phase parser handles forward references, so ordering within the file is free.
Trait definitions, derived ops, and instances can appear in any order.

### Internal requires update

Within consolidated files, `require` statements between old fine-grained modules
become unnecessary (they're now in the same file). Cross-module requires update to
reference new namespaces:

```
;; Old: in add-instances.prologos
require [prologos::core::add-trait :refer [Add Add-add]]

;; After: in arithmetic.prologos — no require needed, Add is in the same file

;; Old: in collection-fns.prologos
require [prologos::core::seqable-trait :refer [Seqable]]

;; After: in collections.prologos
require [prologos::core::collection-traits :refer [Seqable]]
```

### PRELUDE update

The PRELUDE's 92+ require entries collapse to ~18 consolidated entries:

```
;; Old (abbreviated):
(require [prologos::core::eq-trait       :refer [Eq eq-neq nat-eq]])
(require [prologos::core::eq-instances   :refer []])
(require [prologos::core::eq-numeric-instances :refer []])
(require [prologos::core::eq-char-instance     :refer [Char--Eq--dict]])
(require [prologos::core::eq-string-instance   :refer [String--Eq--dict]])

;; New:
(require [prologos::core::eq :refer [Eq eq-neq nat-eq Char--Eq--dict String--Eq--dict]])
```

### Side-effect registration

Trait instances register via side effects when their module is loaded (`:refer []`).
After consolidation, loading `prologos::core::eq` registers ALL Eq instances at once.
The PRELUDE only needs one require per consolidated module instead of many `:refer []`
entries. Instance registration still happens at module load time — it just all happens
in one module now.

### dep-graph.rkt update

Module dependency entries consolidate. Instead of 104 `prologos-lib-deps` entries,
there will be ~18. Test mappings update to reference new module names.

### Test file updates

Tests that `require` specific old modules need updating:
- `require [prologos::core::eq-trait :refer ...]` → `require [prologos::core::eq :refer ...]`
- Tests using `load-module 'prologos::core::eq-trait` → `load-module 'prologos::core::eq`

The test *logic* doesn't change — only import paths.

## What "The Prologos Way" Looks Like

### From DESIGN_PRINCIPLES — Progressive Disclosure

A newcomer does jump-to-definition on `eq?` and lands in `eq.prologos`. They see
the trait definition (what equality means), derived ops (what you can do with it),
and instances (which types support it). Everything about equality in one scroll.
They don't need to understand the trait system deeply — the instances read as
"here's how equality works for Nat, for Int, for String."

### From PATTERNS_AND_CONVENTIONS — Clojure.core inspiration

The 18 consolidated core files are Prologos's answer to `clojure.core`. Not one
giant file, but 18 thematic source files you can read and explore:

- `eq.prologos` — everything about equality
- `arithmetic.prologos` — everything about Add/Sub/Mul/Div/Neg/Abs
- `collections.prologos` — generic collection operations
- `list.prologos` — everything about List's trait capabilities

### From DEVELOPMENT_LESSONS — Completeness Over Deferral

Everything about a topic lives together. You never read `add-trait.prologos` and
then hunt for `add-instances.prologos` to see what types support addition. They're
in the same file, a scroll away.

### From ERGONOMICS — Disappearing Features

The internal structure within each consolidated file uses clear section headers
(`;; ========================================`) that read as documentation, not as
namespace boundaries. A developer reading `eq.prologos` sees "Instances" as a
section heading, not as a module boundary.

## Implementation Phases

### Phase 0: Preparation

- Create `docs/tracking/YYYY-MM-DD_STDLIB_CONSOLIDATION.md` (this document)
- Verify all 4664 tests pass (baseline)
- Create a branch: `stdlib-consolidation`

### Phase 1: Consolidate core files (the big merge)

Work through the 18 target files one at a time. For each:

1. Create the consolidated file with merged content and single `ns` declaration
2. Update internal `require` statements (remove intra-file requires, update cross-file)
3. Update PRELUDE entries for this file's exports
4. Update namespace.rkt (regenerate via gen-prelude.rkt)
5. Update dep-graph.rkt
6. Run targeted tests → verify pass
7. Delete the old fragmented files
8. Commit

Suggested order (by dependency depth):
1. `collection-traits` — trait definitions only, no instances (many things depend on these)
2. `eq`, `ord`, `hashable` — foundational traits + instances
3. `arithmetic`, `algebra` — numeric traits + instances
4. `conversions` — type conversion traits + instances
5. `list`, `pvec`, `set`, `lseq`, `map` — collection instances
6. `collections`, `generic-ops` — generic collection operations
7. `lattice`, `abstract-domains` — lattice hierarchy
8. `string-ops`, `propagator` — already consolidated, just verify

### Phase 2: Update tests and infrastructure

- Update all test files that reference old module names
- Full regression: `racket tools/run-affected-tests.rkt --all`
- Verify dep-graph completeness: `racket tools/update-deps.rkt --check`

### Phase 3: Update the book

Two options (to be decided):

**Option A: Book tangles to consolidated files.** Update book `module` directives
to match new consolidated namespaces. Each chapter may contain 1-3 `module` blocks
instead of 3-13. The tangler produces the 18 consolidated files.

**Option B: Book and source maintained independently.** Book keeps its current
fine-grained `module` structure for narrative purposes. The tangler output is a
*separate view* not used for compilation. The 18 consolidated standalone files are
the compiler's source; the book is the learner's narrative.

Recommendation: **Option A** long-term (book and source stay in sync), but **Option B**
is acceptable as an interim step.

### Phase 4: Optional data file merges

- Merge `lseq` + `lseq-ops` → `prologos::data::lseq`
- Merge `refined-int` + `refined-rat` → `prologos::data::refined`

## Risks

1. **Namespace rename scope.** Renaming 104 namespaces to 18 touches PRELUDE,
   namespace.rkt, dep-graph.rkt, ~127 test files, all cross-module `require`
   statements in .prologos files, and the book. Mitigation: do it module-by-module
   with targeted tests after each merge. Never leave the tree broken.

2. **Side-effect ordering.** Trait instance registration depends on module load order.
   Consolidating instances into fewer modules changes when side effects happen.
   Mitigation: the PRELUDE already controls load order; ensure the new requires
   list loads in the right order.

3. **Book tangler sync.** If the book's `module` directives don't match the new
   consolidated namespaces, the tangler produces stale files. Mitigation: Phase 3
   explicitly addresses this.

4. **Git blame disruption.** The merge commit will attribute all lines in consolidated
   files to one commit. Mitigation: use `git blame --ignore-rev` for the consolidation
   commit; the semantic history in per-file git log is preserved.

5. **File size growth.** The largest consolidated file (~430 lines for arithmetic) is
   still well within comfortable reading range. For reference, `data/list.prologos`
   is already 537 lines and reads well.

## Metrics

| Metric | Current | After |
|--------|---------|-------|
| Core source files | 104 | **18** |
| Data source files | 22 | **20** (optional merges) |
| Total source files | 126 | **38** |
| Files under 20 lines | 52 | **0** |
| Median core file size | ~25 lines | **~200 lines** |
| Largest core file | 340 lines | **~430 lines** |
| Unique namespaces | 126 | **~38** |
| PRELUDE require entries | 92+ | **~25** |
| Import paths | change (one-time migration) | stable after |
| Tests | 4664 | 4664 (logic unchanged) |
| Book chapters | 22 | 22 (unchanged) |
| Jump-to-definition context | 15-25 lines average | **100-250 lines average** |
