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
| Phase 5a | Three-pass pre-registration | Complete | `53223ca` |
| Phase 5b | Declaration-first output ordering | Complete | `53223ca` |
| Phase 5c | Form-level dependency analysis | Complete | `b17555c` |
| Phase 6 | Prelude generation from book | Complete | — |
| Phase 7a | Module container cards | Complete | — |
| Phase 7b | Regex-based syntax highlighting | Complete | — |
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
- Book-like CSS: Georgia serif, left-border code blocks, light/dark themes

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

### Phase 5 Extension: Free Ordering of Declarations (Complete)

Extended Phase 5 into a full free-ordering system so that only genuinely cyclic
dependencies produce compiler errors. Detailed tracking in
`docs/tracking/2026-02-28_1800_FREE_ORDERING.md`.

**Phase 5a: Three-Pass Pre-Registration** (commit `53223ca`)

Replaced the single spec pre-scan with a three-pass architecture:
- **Pass 0**: No-dependency declarations (data, trait, deftype, defmacro, bundle,
  property, functor) — 7 forms that only write to registries.
- **Pass 1**: Declarations depending on Pass 0 outputs — spec (reads bundle +
  trait registries) and impl (reads trait registry).
- **Pass 2**: Main processing loop (unchanged).

Added idempotency guard to `register-param-impl!` to prevent double-registration
when `process-impl` runs in both Pass 1 and Pass 2.

**Phase 5b: Declaration-First Output Ordering** (commit `53223ca`)

After the main processing loop, a stable partition hoists data/trait-generated
defs before user forms. This ensures constructor types and trait accessor types
enter `global-env` before any user `defn`/`def` is type-checked.

Key design choice: impl-generated defs are NOT hoisted — impl method helpers
can reference user-defined functions from the same module.

**Phase 5c: Form-Level Dependency Analysis** (commit `b17555c`)

Built `tools/form-deps.rkt` (~300 LOC) — reads all 22 book chapters via the WS
reader, splits at module boundaries, and extracts defines/references per form.
Computes module-level SCCs via `tarjan-scc` from `stratify.rkt`.

Result: 121 modules, 907 forms, zero module-level cycles. The stdlib book's
module DAG is clean. Added `--analyze` flag to `tangle-stdlib.rkt`.

**What the Phase 5 Extension enables:**
- `defn` using constructors from a `data` declared later in the module
- `spec` referencing `bundle` or `trait` declared later
- `impl` referencing `trait` declared later
- Pattern matching against constructors from later `data` declarations
- Verification that the stdlib has no spurious cross-module cycles

10 test cases in `test-free-ordering.rkt`. Full suite: 4638 tests, zero regressions.

### Phase 6: Prelude Generation from Book (Complete)

The `PRELUDE` manifest (`lib/prologos/book/PRELUDE`) is now the single source of
truth for the prelude auto-imports. The `tools/gen-prelude.rkt` tool generates the
`prelude-requires` definition in `namespace.rkt` from this manifest.

**PRELUDE manifest**: 87 require entries extracted from `namespace.rkt`, organized
with section comments matching the book structure. Ordering matters — generic
`collection-fns` names must come last to shadow List-specific versions.

**gen-prelude.rkt** (~200 LOC) supports four modes:
- Default: print generated `prelude-requires` to stdout
- `--validate`: compare generated entries against current `namespace.rkt` (87/87 match)
- `--write`: update `namespace.rkt` in place between `BEGIN/END GENERATED PRELUDE` markers
- `--check-exports`: verify all 87 referenced modules exist as `.prologos` files

**namespace.rkt**: `prelude-requires` block is now delimited by marker comments.
The tool replaces content between markers, preserving the rest of the file.

Full suite: 4638 tests, zero regressions.

**Automated drift check**: `run-affected-tests.rkt` now calls `check-prelude-drift!`
before launching batch workers. This runs `gen-prelude.rkt --validate` as a subprocess
(~0.2s). Silent when in sync; prints a warning with remediation command on drift.

### Phase 7a: Module Container Cards (Complete)

Each module's content (prose, code blocks, section headers) is now wrapped in a
`<section class="module-container">` with a card-style border. The module badge
serves as the card header.

**Renderer changes:** `render-chapter-page` tracks `module-open?` state. On new
module, closes the previous `</section>` and opens a new one. Part headers and
chapter end close the current container.

**CSS:** 1px border, 6px border-radius, 0.8rem/1.2rem padding, 1.5rem margin.

### Phase 7b: Syntax Highlighting (Complete)

Regex-based syntax highlighting for code blocks, using a placeholder approach
to prevent false positives (e.g., keywords inside strings).

**Token categories (8):**
| Category | CSS class | Examples |
|---|---|---|
| Keyword | `hl-kw` | `defn`, `spec`, `trait`, `impl`, `match`, `fn`, ... |
| Type | `hl-ty` | `Nat`, `Bool`, `List` (uppercase identifiers) |
| String | `hl-str` | `"hello"` |
| Number | `hl-num` | `42N`, `3/4`, `~3.14` |
| Comment | `hl-cmt` | `; ...` |
| Keyword literal | `hl-kwlit` | `:name`, `:refer`, `:doc` |
| Operator | `hl-op` | `->`, `>>`, `:=` |

**Approach:** Three-phase pipeline per code line:
1. **Phase A** — Extract comments and strings into null-byte placeholders
2. **Phase B** — Apply keyword/type/number/operator regex highlighting
3. **Phase C** — Restore placeholders (comments/strings get their spans back)

This prevents keywords like `the`, `if`, `do` inside string literals from being
highlighted. Uses `#px` (Perl-compatible) regexes for lookahead/lookbehind.

**Bug fixes applied:**
- `::` module separator: `:` in `prologos::core::eq-trait` no longer matches as keyword literal
- HTML entity `;`: `&lt;` / `&gt;` semicolons no longer trigger comment highlighting
- Double-backtick inline code: `` `` `(f ,x y) `` `` in prose now renders correctly

**Additional CSS changes:**
- Body max-width: 880px (wider layout for less horizontal scrolling)
- `pre` blocks: negative margins (-1.5rem) to extend beyond container
- Code font-size: 0.8rem (slightly smaller for more content per line)
- Light/dark theme variants for all 7 highlight classes

**Performance:** All 22 chapters generate in <30s. Earlier character-level scanner
approach hung (O(n*m) per line); regex approach uses Racket's C-implemented engine.

### Phase 7 — Remaining Ideas (Not Started)

- Cross-reference links between chapters
- Full-text search in the generated HTML
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
  PRELUDE                    — prelude specification (require entries)
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
| `tools/tangle-stdlib.rkt` | Extract compilation units from chapters (+ `--analyze`) | ~200 |
| `tools/weave-stdlib.rkt` | Render HTML documentation (containers, syntax highlighting) | ~790 |
| `tools/form-deps.rkt` | Form-level dependency analysis across book chapters | ~300 |
| `tools/gen-prelude.rkt` | Generate/validate prelude from PRELUDE manifest | ~200 |
