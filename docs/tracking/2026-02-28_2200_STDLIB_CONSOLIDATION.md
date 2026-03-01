# Standard Library Consolidation: Book Chapters as Source of Truth

## Status: DESIGN (not yet approved for implementation)

## Problem Statement

The Prologos standard library has **126 standalone `.prologos` files** (104 in `core/`, 22 in `data/`) that the tangler extracts from **22 book chapters**. The book reads well as narrative, but the standalone files that developers actually browse are shattered into fragments too small to support discovery or contextual reading.

### Fragmentation by the numbers

| Category | Files | Median size | Example |
|----------|-------|-------------|---------|
| Trait definitions | 31 | 15 lines | `has-top-trait.prologos` (10 lines) |
| Trait instances | 52 | 14 lines | `foldable-list.prologos` (13 lines) |
| Operation modules | 8 | 62 lines | `set-ops.prologos` (33 lines) |
| Data types | 22 | 79 lines | `list.prologos` (330 lines) |

52 files are under 20 lines. The arithmetic chapter alone spans 13 files (`add-trait`, `add-instances`, `sub-trait`, `sub-instances`, ... `abs-instances`) that together total 415 lines -- a single readable scroll.

### What's lost

**Proximity-driven discovery.** When a developer opens `add-trait.prologos` they see a 26-line trait definition and nothing else. They don't see which types implement it, what the instances look like, or how it relates to `Sub`/`Mul`/`Div`. In `clojure.core`, you find `map` near `filter` near `reduce` near `into` -- you discover by scrolling. In our stdlib, finding "how does this collection work?" means opening a dozen files.

**Contextual reading.** The book chapter `lists.prologos` (689 lines, 8 modules) tells a complete story: data type definition, basic operations, folds, trait instances. You can read it top to bottom and understand lists. The standalone files scatter that story across 8 disconnected fragments.

### Why fragmentation happened

Modules were split into tiny files because of dependency ordering constraints in the original single-pass compiler. With the 3-phase parser (Phases 5a-5c: free ordering), forms within a module can reference each other freely. The original pressure to fragment is gone.

## The Insight: The Book Already IS the Right Organization

The 22 book chapters are already the consolidation we want:

| Chapter | Lines | Modules | Content |
|---------|-------|---------|---------|
| `lists.prologos` | 689 | 8 | Data type + 60 operations + all trait instances |
| `lattices.prologos` | 661 | 13 | All lattice/widening/Galois traits + instances |
| `characters-and-strings.prologos` | 427 | 3 | Char/String ops + all trait instances |
| `arithmetic-traits.prologos` | 365 | 13 | Add/Sub/Mul/Div/Neg/Abs traits + all instances |
| `pairs-and-options.prologos` | 370 | 5 | Pair, Option, Either, Result, Never |
| `refined-numerics.prologos` | 345 | 6 | PosInt/NegInt/Zero/PosRat/NegRat + instances |
| `ordering.prologos` | 312 | 7 | Ord/PartialOrd traits + instances |
| `type-conversions.prologos` | 304 | 9 | From/TryFrom/Into/FromInt/FromRat + instances |
| `equality.prologos` | 270 | 7 | Eq trait + propositional equality + instances |
| `collection-functions.prologos` | 257 | 3 | Generic map/filter/reduce/etc. |
| `lazy-sequences.prologos` | 251 | 7 | LSeq + ops + all trait instances |
| `datum-and-homoiconicity.prologos` | 247 | 2 | Datum type + Transducers |
| `sets.prologos` | 226 | 7 | Set trait instances + ops |
| `persistent-vectors.prologos` | 206 | 7 | PVec trait instances + ops |
| `maps.prologos` | 193 | 3 | Map (keyed-map + map-ops + map-entry) |
| `seqable-buildable.prologos` | 169 | 7 | Seqable/Buildable/Seq/Indexed/Keyed/Setlike/Collection |
| `natural-numbers.prologos` | 162 | 1 | Nat arithmetic |
| `identity-and-algebra.prologos` | 160 | 5 | Identity traits + Num/Fractional bundles |
| `generic-operations.prologos` | 261 | 5 | generic-ops/arith/numeric-ops/seq-functions |
| `hashable.prologos` | 121 | 4 | Hashable trait + instances |
| `booleans.prologos` | 90 | 1 | Bool operations |
| `foldable.prologos` | 82 | 3 | Foldable/Reducible/Functor traits |

Total: ~6,168 lines across 22 files. Average ~280 lines per file. Largest is 689. Every one is readable in a single sitting.

## The `clojure.core` Lesson

`clojure.core` is ~8000 lines in one file. You can scroll through it. `map` lives near `filter` lives near `reduce`. `assoc` lives near `dissoc` lives near `get`. Discovery happens by proximity, not by file navigation.

We don't need one giant file. But we need files organized around *topics*, not around *compiler compilation units*. The 22 book chapters achieve this: `lists.prologos` is where you learn about lists. `arithmetic-traits.prologos` is where you learn about arithmetic. Period.

## Design: Book Chapters as Primary Source

### Architecture

```
book/lists.prologos          (authored, primary source)
       |
       | tangler (build step)
       v
.generated/core/seqable-list.prologos    (build artifact)
.generated/core/foldable-list.prologos   (build artifact)
.generated/core/buildable-list.prologos  (build artifact)
.generated/data/list.prologos            (build artifact)
...
       |
       | module loader resolves require paths
       v
compiler loads individual modules as before
```

### What changes

1. **Book chapters become the primary source.** Developers read and edit files in `book/`.

2. **Standalone files become generated artifacts.** The tangler output moves from `core/` and `data/` to `.generated/core/` and `.generated/data/`. These are build artifacts, gitignored (or committed as a convenience cache -- TBD).

3. **The module loader resolves through generated files.** `(require [prologos::core::foldable-list ...])` still works, resolving to `.generated/core/foldable-list.prologos`. No import path changes. No PRELUDE changes. No breaking changes to user code.

4. **The tangler runs as a build step.** Before compilation or testing, `tangle-stdlib.rkt` extracts modules from book chapters into `.generated/`. This already works today -- 126 modules from 22 chapters, verified clean.

5. **`core/` and `data/` become empty (or thin redirects).** During transition, we can keep them as symlinks or generated copies. Eventually they go away.

### What stays the same

- All import paths (`prologos::core::foldable-list`, `prologos::data::list`)
- The PRELUDE manifest and namespace.rkt
- The dep-graph and test infrastructure
- The module loader resolution logic
- All 4664 tests

### Developer workflow

**Before (current):**
- "Where is the Foldable List instance?" -> open `core/foldable-list.prologos` (13 lines, no context)
- "What traits does List implement?" -> grep across `core/*-list.prologos` (8 files)
- "How does arithmetic work?" -> open 13 files in `core/`

**After:**
- "Where is the Foldable List instance?" -> open `book/lists.prologos`, search "Foldable" (full context)
- "What traits does List implement?" -> scroll `book/lists.prologos` (all instances, one file)
- "How does arithmetic work?" -> open `book/arithmetic-traits.prologos` (365 lines, complete story)

## Evolution Path: Multi-Module Files in the Compiler

The design above (Approach B) requires no compiler changes. But it sets up a natural evolution:

**Future Approach A:** Teach the module loader that `prologos::core::foldable-list` lives inside `book/lists.prologos` at a specific `module` boundary. The tangler becomes unnecessary -- the compiler loads book chapters directly, seeking to the right `module` block.

This requires:
- A module index mapping module names to `(file, offset)` pairs
- The module loader reading a specific section of a multi-module file
- Caching per-module within a file (not per-file)

This is the end state. It eliminates the build step entirely. But it's not needed for the consolidation to deliver value.

## What "The Prologos Way" Looks Like

### From DESIGN_PRINCIPLES -- Progressive Disclosure

A newcomer opens `lists.prologos` and reads: data type, basic operations, folds, trait instances. Everything about lists in one scroll. They don't need to understand Seqable or Foldable to use lists -- those instances are later in the same file, clearly marked with headers and prose.

### From PATTERNS_AND_CONVENTIONS -- Clojure.core inspiration

The 22 chapter files are Prologos's `clojure.core`. Not one giant file, but 22 thematic files you can read Part I through Part IX. `equality.prologos` is where you learn about equality. `lists.prologos` is where you learn about lists. Period.

### From DESIGN_METHODOLOGY -- Completeness Over Deferral

Everything about a topic lives together. You never read `add-trait.prologos` and then hunt for `add-instances.prologos` to see what types support addition. They're in the same chapter, in the same narrative flow.

### From ERGONOMICS -- Disappearing Features

The `module` directives inside book chapters are visible in the source for the compiler, but they read as section headers, not as file boundaries. The reader sees "Foldable Instance for List" as a heading within a chapter about lists.

### Naming: Not "book" anymore

If book chapters are the primary source, the directory name `book/` may be misleading -- it suggests documentation, not code. Possible names:

- `lib/prologos/src/` -- "source", straightforward
- `lib/prologos/stdlib/` -- "standard library"
- `lib/prologos/chapters/` -- keeps the book metaphor
- Keep `book/` -- the book metaphor IS the point

Recommendation: keep `book/`. The literate programming metaphor is intentional and distinctive. The book IS the source. That's the Prologos Way.

## Implementation Phases

### Phase 1: Move generated output (low risk)

- Change tangler output directory from `core/`+`data/` to `.generated/core/`+`.generated/data/`
- Update module loader's lib-path to include `.generated/`
- Copy current `core/`+`data/` to `.generated/` as starting point
- Verify: all 4664 tests pass, tangler output matches
- Commit. At this point, `core/` and `data/` still exist but are redundant.

### Phase 2: Remove standalone originals (medium risk)

- Delete `core/*.prologos` and `data/*.prologos` (originals)
- Tangler generates to `.generated/` on every build
- Update `run-affected-tests.rkt` to run tangler before tests
- Verify: all tests pass
- The tangler is now a required build step (it was optional before)

### Phase 3: Gitignore generated files (cleanup)

- Add `.generated/` to `.gitignore`
- Ensure build/test scripts run tangler automatically
- Only `book/` files are in version control
- Only `book/` files appear in diffs, PRs, blame

### Phase 4 (future): Compiler multi-module support

- Module index: build or derive `(module-name -> chapter-file)` mapping
- Module loader: seek to `module` boundary within chapter file
- Tangler becomes optional optimization (pre-extracted cache)

## Risks

1. **Build step dependency.** Tangler must run before compilation/testing. If forgotten, stale `.generated/` files cause confusing errors. Mitigation: `run-affected-tests.rkt` already has prelude drift check; add tangler freshness check.

2. **Editor tooling.** Jump-to-definition may point at `.generated/` files instead of book chapters. Mitigation: editor config to prefer `book/` paths; or Phase 4 eliminates `.generated/` entirely.

3. **Git blame on generated files.** If `.generated/` is committed, blame shows tangler runs, not actual edits. If gitignored, blame isn't available for generated files. Mitigation: blame the book chapters instead -- they're the source of truth.

4. **Book chapter size.** Largest chapter is 689 lines (lists). As the library grows, chapters could become unwieldy. Mitigation: split chapters when they exceed ~800-1000 lines (same principle as test file splitting).

## Metrics (current state for baseline)

| Metric | Current | After consolidation |
|--------|---------|-------------------|
| Source files developers read | 126 (core+data) | 22 (book) |
| Files under 20 lines | 52 | 0 |
| Median file size | ~25 lines | ~250 lines |
| Directories to navigate | 3 (core, data, book) | 1 (book) |
| Module count (for compiler) | 126 | 126 (unchanged) |
| Import paths | unchanged | unchanged |
| Tests | 4664 | 4664 (unchanged) |
