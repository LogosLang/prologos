# The Prologos Book — Literate Standard Library System

## Overview

A literate programming system for the Prologos standard library. Each chapter
is a `.prologos` file containing rich prose commentary interleaved with working
code. Two tools process these files:

- **Tangler** (`tools/tangle-stdlib.rkt`): extracts compilation units to `.tangled/`
- **Weaver** (`tools/weave-stdlib.rkt`): renders HTML documentation to `docs/stdlib-book/`

The book lives in `lib/prologos/book/`. The OUTLINE manifest controls chapter ordering.

## Phase Status

| Phase | Description | Status | Commit |
|---|---|---|---|
| Phase 1 | Tangler + first chapter (equality) | Complete | `86fcec6` |
| Phase 2 | Weaver prototype (HTML renderer) | Complete | `eb52f71` (in dailies) |
| Phase 3 | Foundation chapters (12 chapters, 56 modules) | Complete | `396bfe5`, `c208357` |
| Phase 4 | Complete stdlib (22 chapters, 121 modules) | Complete | `0051176` |
| Phase 5 | Spec pre-scan for free ordering | Complete | `49be0b8` |
| Phase 6 | Prelude generation from book | Not started | — |
| Phase 7 | Extended weaver (syntax highlighting, search) | Not started | — |
| Phase 8 | CI integration (tangle, weave, diff-check) | Not started | — |

## Phase Details

### Phase 1: Tangler + First Chapter (Complete)

Built `tools/tangle-stdlib.rkt` (~200 LOC) that reads the OUTLINE manifest and
splits chapter files at `module` directives into individual compilation units.
Wrote the first chapter (`equality.prologos`) covering the Eq trait and instances.

**Key design decisions:**
- `module prologos::foo::bar` directives mark compilation unit boundaries
- Tangler emits `ns` + code (stripping `:no-prelude` per module)
- Comments pass through verbatim (richer prose replaces terse headers)
- OUTLINE file controls chapter ordering and part groupings

### Phase 2: Weaver Prototype (Complete)

Built `tools/weave-stdlib.rkt` (~425 LOC) — the dual of the tangler. Renders
chapters as human-readable HTML with book-like typography.

**Features:**
- State machine parser recognizing 6 structural patterns (fences, headers, modules, prose, code)
- Inline formatting (bold, code spans)
- Module badges (pills showing which compilation unit)
- Prev/TOC/Next navigation
- Book-like CSS: Georgia serif, 740px max-width, left-border code blocks

### Phase 3: Foundation Chapters (Complete)

Migrated 11 additional chapters (12 total), covering 56 modules across 3 parts.

**Chapters:** equality, ordering, booleans, natural-numbers, lazy-sequences,
foldable, seqable-buildable, collection-functions, lists, persistent-vectors,
maps, sets.

### Phase 4: Complete Standard Library (Complete)

Migrated remaining 65 modules into 10 new chapters (Parts IV-IX).
The entire standard library is now in the literate book system.

**Book structure: 22 chapters, 121 modules**

| Part | Chapters | Modules |
|---|---|---|
| Part I — Foundations | equality, ordering, booleans, natural-numbers | 16 |
| Part II — Core Abstractions | lazy-sequences, foldable, seqable-buildable, collection-functions | 18 |
| Part III — Data Structures | lists, persistent-vectors, maps, sets | 22 |
| Part IV — Pairs, Options, and Errors | pairs-and-options | 5 |
| Part V — Text | characters-and-strings | 3 |
| Part VI — Arithmetic and Algebra | arithmetic-traits, identity-and-algebra, generic-operations | 23 |
| Part VII — Type System Extensions | type-conversions, hashable, refined-numerics | 19 |
| Part VIII — Homoiconicity | datum-and-homoiconicity | 2 |
| Part IX — Lattices and Abstract Interpretation | lattices | 13 |

### Phase 5: Spec Pre-Scan for Free Ordering (Complete)

Added a pre-scan loop in `preparse-expand-all` (macros.rkt) that registers all
`spec` annotations before the main expansion pass. This enables defn-before-spec
ordering within a module — essential for natural prose flow in literate chapters.

**Implementation:** ~20 LOC in macros.rkt, 10 test cases in test-spec-ordering.rkt.
Safe because `process-spec` is idempotent (hash-set) and `auto-export-name!`
has a memq guard.

**What this does NOT address:**
- Data forward references (defn referencing constructor from later `data`)
- Trait forward references (similar issue with `process-trait`)
- Cross-module forward references (handled by `require` ordering)

### Phase 6: Prelude Generation from Book (Not Started)

Generate the prelude requires list directly from the book's module definitions,
replacing the hand-maintained list in `namespace.rkt`. This ensures the prelude
stays in sync with the standard library as modules are added or renamed.

### Phase 7: Extended Weaver (Not Started)

Enhance the weaver with:
- Syntax highlighting for Prologos code blocks
- Cross-reference links between chapters
- Full-text search in the generated HTML
- Dark mode toggle
- PDF generation (via Pandoc or custom LaTeX backend)

### Phase 8: CI Integration (Not Started)

Add CI checks that:
- Run tangler and verify tangled output matches source modules (no drift)
- Run weaver and verify HTML generation succeeds
- Check that OUTLINE is complete (all `.prologos` files listed)
- Verify no module is missing from the book

## Architecture

### Chapter Format

```
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; Chapter: Title Here
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

;; ════════════════════════════════════════════
;; Part I — Section Title
;; ════════════════════════════════════════════

module prologos::data::foo

;; ── Subsection Title ─────────────────────

;; Prose paragraphs as semicolon-prefixed comments.
;; **Bold** and `code` formatting supported.

spec bar Nat -> Nat
defn bar [x] (suc x)
```

### File Layout

```
lib/prologos/book/
  OUTLINE                    — manifest (chapter ordering + part groupings)
  equality.prologos          — Chapter 1
  ordering.prologos          — Chapter 2
  ...
  lattices.prologos          — Chapter 22

lib/prologos/book/.tangled/  — tangler output (gitignored)
docs/stdlib-book/            — weaver output (gitignored)
```

### Tools

| Tool | Purpose | LOC |
|---|---|---|
| `tools/tangle-stdlib.rkt` | Extract compilation units from chapters | ~200 |
| `tools/weave-stdlib.rkt` | Render HTML documentation | ~425 |
