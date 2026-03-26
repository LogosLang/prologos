# PPN Track 1: Lexer + Structure as Propagators

**Stage**: 3 (Design)
**Date**: 2026-03-26
**Series**: PPN (Propagator-Parsing-Network)
**Status**: D.1 — initial design from audit

**Prerequisite**: PPN Track 0 ✅ (lattice structs, bridge specs, integration test)
**Enables**: PPN Track 2 (surface normalization), Track 3 (parser)
**Replaces**: `reader.rkt` (1898 lines, 54 functions)
**Retirement**: reader.rkt deleted upon Track 1 completion

**Source Documents**:
- [Stage 2 Audit](2026-03-26_PPN_TRACK1_STAGE2_AUDIT.md) — 663 lines, 9 sections
- [PPN Track 0 Design](2026-03-26_PPN_TRACK0_LATTICE_DESIGN.md) — lattice infrastructure
- [Grammar Vision](../research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md) — DPO structural preservation
- [PPN Master](2026-03-26_PPN_MASTER.md) — series tracking

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| Pre-0 | Microbenchmarks: reader.rkt per-function costs | ⬜ | Tokenizer vs parser breakdown |
| 0 | Golden test: capture reader.rkt output for all .prologos files | ⬜ | Baseline for comparison |
| 1 | Token producers: flat patterns → token cells | ⬜ | 60% of tokenizer (audit §2) |
| 2 | Indent structurer: indent stack → tree topology cells | ⬜ | Tree IS indentation. Central design. |
| 3 | Bracket matcher: bracket depth → nesting cells | ⬜ | [], (), <>, {} |
| 4 | Context-sensitive: 10 decisions → bridge γ calls | ⬜ | Audit §4. Angle-bracket, mixfix. |
| 5 | Reader macros: #p, ', `, #=, dot-access, broadcast | ⬜ | Audit §6 |
| 6 | API wrapper: maintain 7-function interface | ⬜ | Audit §1 exports |
| 7 | Golden test comparison: old vs new output | ⬜ | Phase 0 baseline vs Phase 6 output |
| 8 | reader.rkt retirement + callers updated | ⬜ | 50 consumers updated |
| 9 | A/B benchmarks | ⬜ | Compare against Pre-0 |
| 10 | Suite verify + dailies + tracker | ⬜ | |
| 11 | PIR + dailies + tracker | ⬜ | |

---

## 1. Architectural Center: Trees, Not Tokens

The central design principle: **the cell topology IS the tree structure.**
Indentation doesn't produce INDENT/DEDENT tokens in a flat stream (the
Python model). Indentation creates PARENT-CHILD relationships between
cells on the propagator network (the Prologos model).

```
Source:                   Cell topology:
  def x := 42            root
    where                   └── def-form
      [Eq x]                    ├── "def" (token cell)
                                ├── "x" (token cell)
                                ├── ":=" (token cell)
                                ├── "42" (token cell)
                                └── where-block (structure cell)
                                    └── "[Eq x]" (child form)
```

Each indented block creates a STRUCTURE CELL whose children are the
indented token/form cells. The structure cell knows its indent level
and its parent. The tree is the network topology.

**Why this matters for macros**: A `defmacro` rewrite operates on a
SUB-TREE of this topology. The DPO rewriting framework preserves the
interface (parent-child boundary). Indentation IS the tree → indentation
is preserved BY CONSTRUCTION, not by careful macro implementation.

**Why this matters for the module forest**: Each `.prologos` file
produces a tree. Module imports connect trees into a FOREST. The forest
is the module dependency graph — already on the propagator network
(Track 10 delivered persistent module networks). PPN Track 1's trees
plug into Track 10's forest naturally.

---

## 2. Design Overview

### 2.1 Three subsystems (from audit)

The audit identified two subsystems in reader.rkt (tokenizer 48%, parser
52%). We split into THREE for cleaner architecture:

**Subsystem A: Token Producers** (flat pattern matching)
- Character sequences → token cells
- No state, no context — pure pattern recognition
- ~60% of current tokenizer (audit §2)
- Maps to: token lattice set-once cells from Track 0

**Subsystem B: Structure Builder** (indent-aware tree construction)
- Indentation → parent-child cell relationships
- Bracket matching → nesting cell relationships
- Multi-line continuation → tree assembly
- ~40% of current tokenizer + 100% of current parser
- Maps to: cell topology on the propagator network

**Subsystem C: Context Resolver** (10 context-sensitive decisions)
- Angle-bracket depth (> disambiguation)
- Mixfix form override (parser manipulates tokenizer state)
- Keyword vs identifier in context
- Maps to: SurfaceToToken bridge γ from Track 0

### 2.2 The coupling that must break

The audit found: the current parser reaches INTO the tokenizer's mutable
state (bracket-depth, angle-depth) in the mixfix form handler. This
coupling is WHY context-sensitive decisions are ad-hoc — the "context"
is imperative state mutation, not information flow.

In the propagator model: context flows through CELLS, not mutable state.
The parser writes to a "parse context" cell. The tokenizer reads the
context cell via the SurfaceToToken bridge γ. No direct state coupling.

---

## 3. Token Producers (Subsystem A)

### 3.1 Pattern inventory (from audit §2)

Each pattern becomes a TOKEN PRODUCER propagator that reads character
positions and writes token cells:

| Category | Patterns | Count | Token type | Propagator complexity |
|----------|----------|-------|------------|----------------------|
| Identifiers | letter followed by ident-chars | ~30 keywords + open | `'identifier` / `'keyword` | Simple: scan chars, classify |
| Numbers | digits, optional N suffix, rationals | 4 formats | `'number` / `'nat` / `'rat` | Medium: disambiguate Int/Nat/Rat |
| Strings | `"..."` with escapes | 1 pattern | `'string` | Medium: escape sequences |
| Characters | `'X'` | 1 pattern | `'char` | Simple |
| Operators | `+`, `-`, `*`, `/`, `=`, `<`, `>`, etc. | ~15 | `'operator` | Simple |
| Delimiters | `[`, `]`, `(`, `)`, `{`, `}`, `<`, `>`, `:`, `:=` | ~12 | `'delimiter` | Simple except `>` |
| Comments | `;` to end of line | 1 pattern | skipped | Simple |
| Whitespace | spaces, tabs | 1 pattern | indent tracking | Connects to Subsystem B |
| Newlines | `\n`, `\r\n` | 1 pattern | indent tracking | Connects to Subsystem B |

### 3.2 Implementation: registered pattern functions

Each pattern is a REGISTERED FUNCTION (like SRE ctor-desc):

```racket
(struct token-pattern
  (name           ;; symbol: pattern identifier
   recognizer     ;; (chars pos) → match-length | #f
   classifier     ;; (chars pos len) → token-type symbol
   priority       ;; int: higher priority wins for ambiguous positions
   )
  #:transparent)

(define token-pattern-registry (make-hash))
(define (register-token-pattern! pattern) ...)
```

The recognizer scans characters from a position and returns how many
characters match (or #f for no match). The classifier determines the
token type from the matched characters. Priority resolves ambiguity
(`:=` has higher priority than `:` alone).

Token producers fire in a sweep across the input: for each position,
try each registered pattern, select the highest-priority match, write
the token cell.

---

## 4. Structure Builder (Subsystem B)

### 4.1 The indent tree

The core algorithm: maintain an INDENT STACK (list of indent levels).
When a new line starts:

- If indent > top of stack → PUSH: new child level. Create structure
  cell, set parent to current context.
- If indent = top of stack → SIBLING: same level. Continue in current
  context.
- If indent < top of stack → POP: dedent. Pop stack until indent
  matches or exceeds. Return to parent context.

In the propagator model: the indent stack is a CELL whose value is the
current stack state. The stack cell is a value lattice (the stack only
GROWS or POPS — it's not arbitrary mutation). Each push/pop produces a
new stack value.

### 4.2 Structure cells

A structure cell represents a nested block:

```racket
(struct structure-cell-value
  (indent-level    ;; int: column of this block's indentation
   parent-id       ;; cell-id | #f: parent structure cell
   children        ;; list of cell-id: child token/structure cells (in order)
   form-type       ;; symbol: 'top-level, 'indented-block, 'bracket-group, 'line
   )
  #:transparent)
```

The TREE TOPOLOGY is encoded in `parent-id` and `children`. Walking
the tree = following cell-id references. This is the structure that
macros operate on and DPO rewriting preserves.

### 4.3 Bracket groups

Brackets create INLINE structure (not indent-based):

- `[f x y]` → structure cell with children `f`, `x`, `y`
- `(match ...)` → structure cell with children `match`, ...
- `{:key val}` → structure cell (map literal)
- `<Int | String>` → structure cell (type annotation)

Bracket groups are NESTED within indent blocks. A bracket group's
parent is the enclosing indent block or bracket group.

### 4.4 The tree invariant

**Invariant**: Every token cell has exactly ONE parent structure cell.
Every structure cell has exactly ONE parent (except the root, which
has `#f`). The cell topology forms a TREE, not a DAG or arbitrary graph.

This invariant is STRUCTURAL — enforced by the cell creation pattern:
- Token producer creates token cell → immediately assigns to current
  structure context
- Structure builder creates structure cell → assigns parent from
  indent stack or bracket context

No "orphan" cells. No "multi-parent" cells. The tree is correct by
construction.

---

## 5. Context Resolver (Subsystem C)

### 5.1 The 10 context-sensitive decisions (from audit §4)

| # | Decision | Current mechanism | Propagator mechanism |
|---|----------|-------------------|---------------------|
| 1 | `>` as operator vs delimiter | `angle-depth` counter | Bridge γ: parse context cell reads bracket nesting |
| 2 | Mixfix form override | Parser mutates tokenizer state | Bridge γ: parse form type → token reclassification |
| 3 | Keyword vs identifier | Reserved word list | Token pattern priority (keywords > identifiers) |
| 4 | `:=` vs `:` + `=` | Longest match | Token pattern priority (`:=` priority > `:`) |
| 5 | Negative number vs minus operator | Context-dependent | Bridge γ: expression context → classify as negative literal or operator |
| 6 | `::` (module path) vs `:` (annotation) | Longest match | Token pattern priority |
| 7 | Dot access vs decimal point | Lookahead | Token pattern with lookahead: digit after dot = decimal |
| 8 | Quote `'` (list literal) vs char literal `'X'` | Lookahead (2 chars) | Token pattern with 2-char lookahead |
| 9 | Hash `#` dispatch (#p, #{, #=, #:) | Next char | Token pattern with 1-char lookahead |
| 10 | String interpolation boundaries | Nesting counter | Structure cell: string-interpolation context |

Decisions 1, 2, 5 need BRIDGE-mediated context (parse state informs
token classification). Decisions 3, 4, 6 are resolved by pattern
priority (no context needed). Decisions 7, 8, 9 are resolved by
lookahead in the pattern recognizer. Decision 10 is structural (like
bracket matching).

### 5.2 Bridge integration

The SurfaceToToken bridge γ from Track 0 handles decisions 1, 2, 5:

```racket
;; Context function: given parse context + token type, return
;; reclassified type or #f (no change)
(define (ws-context-disambiguate parse-context token-type lexeme)
  (cond
    ;; Decision 1: > inside angle brackets → delimiter
    [(and (eq? token-type 'operator)
          (string=? lexeme ">")
          (angle-bracket-context? parse-context))
     'delimiter]
    ;; Decision 5: - after operator/delimiter/newline → negative prefix
    [(and (eq? token-type 'operator)
          (string=? lexeme "-")
          (prefix-context? parse-context))
     'negative-prefix]
    ;; Decision 2: mixfix forms — defer to Track 2 (normalization)
    [else #f]))
```

---

## 6. API Compatibility

### 6.1 Maintain the 7-function interface

The 50 consumers call these 7 functions. The new reader MUST export the
same 7 names with the same signatures:

| Function | Signature | New implementation |
|----------|-----------|-------------------|
| `prologos-read` | `port → datum` | Build tree, extract first datum |
| `prologos-read-syntax` | `source port → syntax` | Build tree, wrap as syntax |
| `prologos-read-syntax-all` | `source port → (listof syntax)` | Build full tree, extract all top-level forms |
| `tokenize-string` | `string → (listof token)` | Run token producers, return flat list |
| `read-all-forms-string` | `string → (listof datum)` | Build tree, extract datums |
| `token-type` | accessor | Unchanged (from token struct) |
| `token-value` | accessor | Unchanged (from token struct) |

The NEW reader builds the propagator-based tree internally. The API
functions are WRAPPERS that extract the caller's expected format from
the tree. This means: all callers get the same output, but the internal
representation is a cell tree, not an imperative parse state.

### 6.2 Golden test strategy

Phase 0 captures reader.rkt's output for EVERY `.prologos` file:

```racket
;; For each .prologos file:
(define old-output (read-all-forms-string (file->string path)))
;; Serialize to a golden file
(write old-output (open-output-file golden-path))
```

Phase 7 compares new reader output against golden files:

```racket
(define new-output (new-read-all-forms-string (file->string path)))
(check-equal? new-output old-output)
```

Any difference = a bug in the new reader. Zero differences = ready
for retirement.

---

## 7. The Tree-to-Forest Connection

Each `.prologos` file produces a TREE (the cell topology from §4).
Module imports connect trees: when module A imports module B, A's tree
references B's exported definitions.

Track 10 delivered persistent module networks (`.pnet` cache). PPN
Track 1's trees are the PARSE REPRESENTATION of modules. The connection:

1. Track 1 builds the PARSE TREE (character → token → structure cells)
2. Track 2 NORMALIZES the tree (defmacro expansion on the cell tree)
3. Track 3 PARSES the tree (grammar productions on the normalized tree)
4. Track 10's `.pnet` SERIALIZES the elaborated tree to disk

The forest is the composition: each module's tree, connected by import
edges, persisted as `.pnet` files. When a module changes, only its tree
is rebuilt — the forest's other trees are loaded from cache.

---

## 8. NTT Speculative Syntax

```prologos
;; Token producer as a registered pattern
propagator ident-producer
  :reads  [Cell CharStream]
  :writes [Cell TokenValue]
  :pattern [letter ident-char*]
  :classifier keyword-or-identifier

;; Structure builder as indent-aware tree constructor
propagator indent-structurer
  :reads  [Cell TokenValue] [Cell IndentStack]
  :writes [Cell StructureValue]
  ;; Push/pop/sibling based on indent comparison

;; Context resolver via bridge
bridge TokenToSurface
  :from TokenValue
  :to   ParseValue
  :alpha token-to-parse-scan
  :gamma ws-context-disambiguate
```

---

## 9. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Golden test differences | HIGH | Phase 0 captures exact baseline. Every difference investigated. |
| Indent stack as cell value | MEDIUM | Stack transitions are monotone (push/pop only). Validate with integration test. |
| 50 consumers to update | HIGH | API wrappers (§6.1) mean ZERO consumer changes initially. Retirement phase updates callers. |
| Performance regression | LOW | Reader is 0.003% of pipeline. 10× slowdown still negligible. |
| Angle-bracket context via bridge | MEDIUM | Bridge γ validated in Track 0 integration test (test-parse-integration.rkt test 6). |
| Tree invariant violation | HIGH | Structural enforcement (§4.4): no orphan cells, no multi-parent. Assert on every cell creation. |

---

## 10. Principles Alignment

**Propagator-First**: ALL reader state is cells. No mutable tokenizer
struct, no mutable parser struct. Indent stack = cell. Bracket depth =
cell. Token classification = cell. Context = cell via bridge.

**Data Orientation**: Token patterns are REGISTERED DATA (token-pattern
structs), not imperative character dispatch. Structure is CELL TOPOLOGY
(data), not mutable tree-building state.

**Correct-by-Construction**: The tree invariant (§4.4) is structural —
every cell gets a parent at creation time. No orphans possible.
Indentation preservation under macro rewriting is BY DPO THEOREM, not
by careful implementation.

**Completeness**: Track 1 replaces the ENTIRE reader, not a subset.
reader.rkt is DELETED upon completion. No dual-path.

**Composition**: Trees compose into forests via module imports. The tree
structure (cell topology) composes with Track 2 (normalization), Track 3
(parsing), and Track 10 (serialization).

**Challenge**: Is the indent stack REALLY a lattice value? Push/pop
doesn't have a natural join. The stack is SEQUENCE state, not lattice
state. Resolution: the indent stack is a cell with a CHAIN lattice
(successive stack states form a total order within one parse). The
lattice is the parse PROGRESS — earlier states ≤ later states. This
is monotone (parse only moves forward).

---

## 11. Completion Criteria

1. Golden test: ZERO differences between old and new reader output on
   ALL `.prologos` files in the repo.
2. All 7 API functions produce identical output to reader.rkt.
3. Tree invariant holds: every cell has exactly one parent (asserted).
4. 10 context-sensitive decisions handled (bridge + priority + lookahead).
5. reader.rkt DELETED and all 50 consumers updated.
6. Suite green (no regressions).
7. A/B benchmarks: new reader ≤ 10× current reader time (generous, reader is 0.003% of pipeline).
8. PIR written per methodology.
9. Dailies + tracker updated per-phase.
