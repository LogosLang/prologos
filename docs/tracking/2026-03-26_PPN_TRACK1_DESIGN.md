# PPN Track 1: Lexer + Structure as Propagators

**Stage**: 3 (Design)
**Date**: 2026-03-26
**Series**: PPN (Propagator-Parsing-Network)
**Status**: D.2 — constraint-based tree building (Completeness revision).
D.1 used imperative sweep; D.2 uses constraint propagation for O(1)
incremental editing from day one.

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
| Pre-0 | Microbenchmarks: reader.rkt per-function costs | ✅ | `b076359` — 370ns/token, 55% structure, chain 3μs/200 lines, 1.7× incremental. No design changes. |
| 0 | Golden baseline: tree topology + bracket groups + datums + srcloc | ⬜ | 4-level capture for 110 .prologos files |
| 1a | Token producers: flat patterns → token cells | ⬜ | Context-free, possibly stateful (strings, #p). 60% of tokenizer. |
| 1b | Indent structurer: constraint chain → tree topology | ⬜ | Content lines only (blank/comment skipped). Central design. |
| 1c | Bracket matcher: bracket depth chain → nesting | ⬜ | Bracket depth pre-computed per-token, fed to context chain. |
| 1d | **Integration gate**: golden comparison on simple files | ⬜ | Must pass before Phases 2-5 proceed. |
| 2 | Context-sensitive: 11 decisions → bridge γ + priority + lookahead | ⬜ | +postfix adjacency (decision 11). Mixfix: 0 files, tracked gap. |
| 3 | Reader macros: #p, ', `, #=, dot-access, broadcast | ⬜ | #p needs bracket-counting recognizer (stateful). |
| 4a | Read API (5 tree-walking functions) | ⬜ | `read-to-tree`, `tree-children`, `tree-parent`, etc. |
| 4b | Write API (4 tree mutation functions) | ⬜ | `tree-replace-children`, `tree-splice`, etc. For Track 2. |
| 4c | Compatibility wrappers (7 datum functions) | ⬜ | Same signatures as reader.rkt. |
| 5 | Golden comparison: 4 levels (topology + brackets + datums + srcloc) | ⬜ | ZERO differences = ready for retirement. |
| 6 | reader.rkt retirement + 50 consumers updated | ⬜ | |
| 7 | A/B benchmarks (integrated system, not components) | ⬜ | Pre-0 is feasibility; Phase 7 is validation. |
| 8 | Suite verify + dailies + tracker | ⬜ | |
| 9 | PIR + dailies + tracker | ⬜ | |

### Per-Phase Completion Protocol

Every phase completes with these 4 steps IN ORDER:

1. **Commit**: `git add` + `git commit` with descriptive message
2. **Tracker**: Update the progress tracker table above (⬜ → ✅ + commit hash + key result)
3. **Dailies**: Append to current dailies with: what was done, design choices, lessons/surprises
4. **Proceed**: Move to next phase only after steps 1-3 are done

A phase is NOT complete until all 4 steps are done. This prevents the
pattern of batching dailies updates at session end (loses context).

---

## 0. Pre-0 Benchmark Results (`b076359`)

### Tokenizer performance

| Input | Tokens | Time | Per-token | Scaling |
|-------|--------|------|-----------|---------|
| Representative (6 forms) | 46 | 17.6 μs | 382 ns/token | baseline |
| Large (50× repeat) | 2,251 | 847 μs | 376 ns/token | 1.04× (linear) |
| 100 identifiers | 100 | 70 μs | 700 ns/token | identifier-heavy |
| 10-deep nested brackets | ~20 | 4.4 μs | ~220 ns/token | bracket-light |

**Tokenization is 370-400 ns/token with near-linear scaling.** Our token
cell set-once write is 3 ns (from Track 0) — 100× headroom.

### Structure building

| Metric | Value |
|--------|-------|
| Structure fraction of total reader time | 55% |
| Deeply indented (10 levels) | 23.6 μs |
| Bracket-heavy (nested applications) | 84.8 μs |

### Constraint chain (indent resolution)

| Scale | Time | Per-line | Notes |
|-------|------|----------|-------|
| 200 lines | 3.1 μs | 15.6 ns/line | 7× faster than current structure |
| 2,000 lines | 32.9 μs | 16.4 ns/line | Linear scaling confirmed |
| Incremental (edit at line 100, 200 lines) | 1.7 μs | — | 1.7× faster than full |
| Max stack depth | 3 | — | Context cells are tiny |

### E2E reader costs (real files)

| File | Lines | Tokens | Reader time |
|------|-------|--------|------------|
| core.prologos | 60 | 233 | 0.23 ms |
| nat.prologos | 130 | 491 | 0.46 ms |
| list.prologos | 584 | 3,540 | 3.25 ms |

### Content-addressed hashing

| Operation | Time |
|-----------|------|
| `equal-hash-code` on `token-cell-value` | 83 ns/hash |
| Hash table lookup (1000 entries) | 174 ns/lookup |

### Golden baseline

| Metric | Value |
|--------|-------|
| Total .prologos files | 110 (72 lib + 38 examples) |
| Largest file | numerics-tutorial-demo.prologos (1,164 lines) |

### Design implications

1. **No design changes needed.** All measurements within budget.
2. **Constraint chain is 7× faster** than current structure pass.
3. **Performance target is generous**: current reader is 370 ns/token +
   55% structure. New reader with constraint chain should be within 2×.
4. **Incremental editing is 1.7× from day one.** Content-only edits: O(1).
5. **Content hashing is affordable**: 83 ns/hash, ~100-500 cells/file = 8-40 μs.
6. **110 files for golden comparison.** Largest: 1,164 lines.

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

## 4. Structure Builder (Subsystem B) — Constraint-Based Tree Construction

### 4.1 The architectural principle (D.2 revision)

**D.1 used an imperative sweep** (left-to-right scan with mutable indent
stack). D.2 replaces this with CONSTRAINT-BASED PROPAGATION:

- Each line's indent level is a CELL VALUE (measured from characters)
- Parent-child relationships are CONSTRAINTS (resolved by propagation)
- The tree topology EMERGES from constraint satisfaction at fixpoint
- Incremental editing = re-fire affected constraints only = O(affected lines)

The Completeness principle says: build the foundation that makes Tracks
2-8 easier. The constraint-based approach gives O(1) incremental editing
from day one (Track 8 benefit), parallel-ready construction (Track 3
benefit), and propagator-native representation (every track's benefit).

### 4.2 Content lines vs source lines (D.4)

**"Line" in the cell topology means CONTENT LINE** — a source line that
contains non-whitespace, non-comment content. Blank lines and comment-
only lines do NOT create cells. They are filtered during character
measurement (before the constraint chain fires).

reader.rkt handles this at lines 160-185: `count-leading-spaces!`
returns `#f` for blank/comment lines, and the outer loop retries. Our
design replicates this: the character measurement phase (embarrassingly
parallel) classifies each source line as CONTENT or SKIP. Only content
lines create cells. The constraint chain operates on content lines only.

**Implications for incremental editing**: Inserting or removing a blank
line is O(0) — no cells affected, no propagators fire. Inserting a
content line creates new cells and re-fires the chain from that point.

**EOF handling (D.4)**: The constraint chain terminates when the last
content line's context cell is written. The tree is "complete" when the
propagator network reaches quiescence (no more propagators to fire).
The API functions (read-to-tree, compatibility wrappers) extract results
after quiescence.

**Error handling (D.4)**: Malformed input (unmatched brackets, tab
characters, invalid tokens) writes `token-top` (error) to the
affected cell. Error cells have no children — the tree TRUNCATES at the
error point. The tree invariant holds but the tree is INCOMPLETE.
Error propagation through the chain: if a line produces an error,
subsequent lines may have incorrect context (bracket depth or indent
stack corrupted). Track 6 (error recovery) adds ATMS-based repair.
Track 1 provides correct trees for correct input and truncated trees
for erroneous input.

### 4.3 Per-content-line cells

Each content line creates 3 cells:

```racket
;; Line i has:
;; 1. indent-cell: measured indent level (set-once from characters)
;; 2. parent-cell: resolved parent line-id (computed by propagation)
;; 3. context-cell: indent context passed forward (the distributed stack)

(struct line-info
  (line-number     ;; exact-nonneg-integer
   indent-cell-id  ;; cell-id: holds indent level (set-once)
   parent-cell-id  ;; cell-id: holds parent line-id | 'root (resolved)
   context-cell-id ;; cell-id: holds indent context for next line
   content-cells   ;; list of cell-id: token cells on this line
   )
  #:transparent)
```

The indent-cell is set ONCE from character measurement (embarrassingly
parallel — each line independently measures its leading whitespace).

The parent-cell and context-cell are resolved by the indent resolver
propagator (§4.3).

### 4.3 The indent resolver propagator

A CHAIN of propagators, one per line. Each reads the previous line's
context and its own indent level, then computes its parent and the
updated context for the next line.

```racket
;; The indent context is the distributed stack:
;; A list of (indent-level . line-id) pairs, outermost first.
;; Example: ((0 . 0) (2 . 1) (4 . 2)) means:
;;   line 0 at indent 0, line 1 at indent 2, line 2 at indent 4

(define (make-indent-resolver prev-context-cell my-indent-cell
                              my-parent-cell my-context-cell my-line-id)
  ;; Propagator: fires when prev-context AND my-indent are non-bot.
  ;;
  ;; Algorithm:
  ;; 1. Read prev-context (the indent stack as a list)
  ;; 2. Read my-indent
  ;; 3. Pop stack entries with indent >= my-indent
  ;; 4. Top of remaining stack = my parent (or 'root if empty)
  ;; 5. Push (my-indent . my-line-id) onto stack
  ;; 6. Write parent to my-parent-cell
  ;; 7. Write updated stack to my-context-cell
  ...)
```

**Performance**: chain propagation at 500ns/step (from Pre-0 D5).
200-line file = 100μs. 2000-line file = 1ms. Negligible.

**Incrementality**: editing line i's indent → indent-cell changes →
resolver propagator for line i re-fires → context-cell changes →
line i+1's resolver re-fires → ... → chain stabilizes when indent
change's effect is fully propagated. Lines BEFORE line i are unaffected.
Content-only edits (no indent change) = 0 propagator firings.

### 4.4 Constraint formulation (the WHAT, not the HOW)

The parent-child relationship IS a constraint:

```
parent(line_i) = max { line_j | j < i AND indent(line_j) < indent(line_i) }
                 or 'root if no such line_j exists
```

This constraint is DETERMINISTIC given the indent levels. The chain
propagator (§4.3) SOLVES this constraint efficiently (O(n) for n lines).
But the constraint formulation is the INTERFACE — downstream consumers
see "line 5's parent is line 3," not "the sweep computed this."

A future implementation could solve the same constraint differently
(parallel scan, GPU-accelerated, etc.) without changing the interface.

### 4.5 Structure cells

A structure cell represents a nested block (indent or bracket):

```racket
(struct structure-cell-value
  (indent-level    ;; int: column of this block's indentation
   parent-id       ;; cell-id | 'root: parent structure cell
   children        ;; list of cell-id: child token/structure cells (in order)
   form-type       ;; symbol: 'top-level, 'indented-block, 'bracket-group, 'line
   line-id         ;; line-info | #f: which line this structure starts at
   )
  #:transparent)
```

The TREE TOPOLOGY is encoded in `parent-id` and `children`. Walking
the tree = following cell-id references. This is the structure that
macros operate on and DPO rewriting preserves.

### 4.6 Bracket groups and the bracket-indent interaction

Brackets create INLINE structure (not indent-based):

- `[f x y]` → structure cell with children `f`, `x`, `y`
- `(match ...)` → structure cell with children `match`, ...
- `{:key val}` → structure cell (map literal)
- `<Int | String>` → structure cell (type annotation)

Bracket groups are NESTED within indent blocks. A bracket group's
parent is the enclosing indent block or bracket group.

**Critical interaction (D.3 self-critique, confirmed by code audit)**:
Bracket groups SUPPRESS indent tracking. reader.rkt lines 235 and 274
check `(= 0 (tokenizer-bracket-depth tok))` — indentation processing
is SKIPPED when bracket depth > 0. Newlines inside brackets are treated
as whitespace (no indent/dedent tokens). A multi-line bracket group:

```
[map [fn [x : Int]
         [int+ x 1]]
     xs]
```

Line 2 is at indent 9, but it's a CONTINUATION of the bracket on line
1, not a new indent child. The indent resolver must know: "am I inside
an open bracket?" If yes, indent changes don't create new parent-child
relationships — the line is part of the enclosing bracket group.

**Resolution**: Token producers determine BRACKET DEPTH per line
(count open - close brackets from left). The indent resolver reads
bracket depth as an ADDITIONAL INPUT. If bracket depth > 0, the line
is a continuation → parent = the line that opened the bracket group.
If bracket depth = 0, normal indent resolution applies.

The bracket depth propagation is ALSO a chain (line-by-line, since
a bracket opened on line 3 affects lines 4+). This chain can be
MERGED with the indent context chain — each line's context includes
BOTH the indent stack AND the bracket depth. One chain, two concerns.

**Bracket depth at LINE START determines behavior** (confirmed by
reader.rkt code audit, lines 235/274): if bracket-depth > 0 at line
start, the ENTIRE line is a continuation (no indent processing).
Bracket depth changes WITHIN a line (opens/closes) affect the NEXT
line's bracket-depth-at-start, not the current line's classification.

### 4.9 Architectural difference from reader.rkt (D.3 code audit)

reader.rkt builds the tree INCREMENTALLY: consume INDENT token →
call `parse-indented-block` → loop reading children → consume DEDENT
token → return children list. The tree is built BY TOKEN CONSUMPTION.

Our design builds the tree BY CONSTRAINT RESOLUTION: indent levels →
parent-child assignments → tree topology. The tree exists BEFORE any
"parser" consumes it. There are NO INDENT/DEDENT tokens — the parent-
child relationships ARE the indent structure.

This means: Track 2 (normalization) and Track 3 (parser) don't need
indent/dedent tokens. They operate on the PRE-BUILT cell tree. The
current pipeline's "consume indent tokens to build tree" step is
ELIMINATED — the tree is a GIVEN, not a computation.

This is a fundamental simplification. reader.rkt's `parse-indented-block`
(lines 1716-1732) and `parse-top-level-form`'s indent check (line 1743)
have NO ANALOGS in the new reader. The constraint chain REPLACES them.

### 4.7 The tree invariant

**Invariant**: Every token cell has exactly ONE parent structure cell.
Every structure cell has exactly ONE parent (except root, which has
`'root`). The cell topology forms a TREE.

This invariant is STRUCTURAL — enforced by the constraint resolution:
- The parent constraint (§4.4) assigns exactly one parent per line
- Bracket matching assigns exactly one parent per bracket group
- Token cells are children of their line's structure cell

No orphans. No multi-parents. The tree is correct by construction.

### 4.8 Content-addressed cells for structural sharing

Structure cell equality is CONTENT-BASED (`gen:equal+hash` on content,
not on cell-id). Two identical sub-trees in different modules have
equal structure cells. The CHAMP provides implicit storage-level sharing
for equal cells.

This doesn't introduce explicit cross-tree sharing (that's PReductions
scope with e-graphs). But it ENABLES future sharing: content-addressed
cells can be deduplicated without changing the tree topology.

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

## 6. API: Primary (Tree) + Compatibility (Datum)

### 6.1 Two API layers

The tree is the PRIMARY output. Datums are a COMPATIBILITY layer.

**Primary API (new — for Track 2, 3, 4+ consumers):**

**Read operations:**

| Function | Signature | Returns |
|----------|-----------|---------|
| `read-to-tree` | `string → parse-tree` | The cell tree (structure cells + token cells) |
| `read-file-to-tree` | `path → parse-tree` | Same, from file |
| `tree-top-level-forms` | `parse-tree → (listof structure-cell)` | Top-level form sub-trees |
| `tree-children` | `structure-cell → (listof cell-id)` | A form's children in order |
| `tree-parent` | `cell-id → cell-id \| 'root` | A cell's parent |

**Write operations (D.4 — pulled in for Track 2 Completeness):**

| Function | Signature | Purpose |
|----------|-----------|---------|
| `tree-replace-children` | `cell-id (listof cell-id) → void` | Replace a structure cell's children (defmacro expansion) |
| `tree-insert-child` | `cell-id cell-id position → void` | Add a child at a specific position |
| `tree-remove-child` | `cell-id cell-id → void` | Remove a child from a structure cell |
| `tree-splice` | `cell-id cell-id (listof cell-id) → void` | Replace one child with multiple (macro expansion producing multiple forms) |

**Why these are in Track 1, not Track 7 (D.4 Completeness revision):**
Track 2 (surface normalization) REWRITES trees — defmacro expansion,
let/cond desugaring, implicit map rewriting. If Track 2 operates on
datums (extracting from the tree and working on S-expressions), the
tree architecture is dead infrastructure until Track 8. If Track 2
operates on the tree directly, every subsequent track benefits.

The write operations are SIMPLE CELL UPDATES — update parent-id,
update children list. No DPO framework needed. The tree invariant is
maintained by each operation (old children orphaned → GC, new children
get parent). Full DPO with interface preservation guarantees is
Track 3.5/7 scope. Mechanical tree mutation is Track 1 scope.

Track 2 (normalization) operates on the cell tree directly — it walks
tree children, matches patterns, replaces sub-trees via `tree-splice`.
The tree flows from Track 1 to Track 2 to Track 3 as cells on the
same network. No datum extraction roundtrip.

**Compatibility API (maintained — for 50 existing consumers):**

| Function | Signature | Implementation |
|----------|-----------|---------------|
| `prologos-read` | `port → datum` | Build tree, extract first datum |
| `prologos-read-syntax` | `source port → syntax` | Build tree, extract + wrap |
| `prologos-read-syntax-all` | `source port → (listof syntax)` | Build tree, extract all top-level |
| `tokenize-string` | `string → (listof token)` | Run token producers, return flat |
| `read-all-forms-string` | `string → (listof datum)` | Build tree, extract datums |
| `token-type` | accessor | Unchanged |
| `token-value` | accessor | Unchanged |

The compatibility functions are THIN WRAPPERS: they call `read-to-tree`
internally, then extract datums/syntax from the tree. All 50 consumers
unchanged initially. Track 2+ consumers migrate to the primary API.

### 6.2 Golden test strategy (D.2 revision)

**Two levels of golden comparison:**

**Level 1 (primary — tree structure):**
Phase 0 captures the tree's parent-child map for representative files:

```racket
;; For each .prologos file:
;; Record: (line-number → (indent-level . parent-line-number))
;; This captures the tree TOPOLOGY, not the datums
(define old-tree-map (capture-tree-structure path))
(write old-tree-map (open-output-file tree-golden-path))
```

Phase 7 compares NEW tree structure against golden:
```racket
(define new-tree-map (capture-new-tree-structure path))
(check-equal? new-tree-map old-tree-map)
```

Level 1 catches: wrong parent-child assignments, indent mishandling,
bracket matching errors — things that datum comparison MISSES because
two different trees can produce the same datums.

**Level 2 (compatibility — datum output):**
Phase 0 ALSO captures `read-all-forms-string` datum output:

```racket
(define old-datums (read-all-forms-string (file->string path)))
(write old-datums (open-output-file datum-golden-path))
```

Phase 7 compares new datum output:
```racket
(define new-datums (new-read-all-forms-string (file->string path)))
(check-equal? new-datums old-datums)
```

Level 2 catches: API wrapper extraction errors — the tree is right but
the datum conversion is wrong.

**Both levels must pass for retirement.** Zero differences at both
levels = ready to delete reader.rkt.

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

**Propagator-First** (D.3 challenge): The token-pattern-registry (§3.2)
is a Racket hash map, not a cell. Same pattern Track 8 criticized for
trait/impl registries. Resolution: token patterns ARE static for a given
grammar — they don't change during parsing. A Racket hash is correct for
Track 1. If Track 7 (dynamic grammar extensions) needs dynamic patterns,
the registry migrates to a cell then. This is the same pragmatic call
we made for SRE Track 0 (form registry as Racket hash, not cell).

**Data Orientation** (D.3 challenge): Structure cells hold `children:
list of cell-id` — references, not embedded data. Parse trees are
NETWORK TOPOLOGY, not self-contained values. This means parse trees
can't be serialized by writing the root cell alone (unlike expression
trees). For Track 1: fine (trees are ephemeral). For Track 8
(incremental): trees persist across edits, serialization matters. Note
for future, don't address now.

**Completeness** (D.2): The constraint-based approach does the HARD
thing (propagator-native tree construction with O(1) incremental) so
that everything downstream is EASIER (Track 2 normalization operates
on live cells, Track 3 parser fires into the same network, Track 8
gets incremental editing for free). D.1's sweep was the convenient
choice; D.2's constraints are the complete choice.

**Challenge**: The indent context chain IS sequential (line i depends
on line i-1). This means the tree can't be built fully in parallel —
the chain propagates left-to-right. But the MEASUREMENT of indent
levels IS parallel (each line independently). And the CONSUMPTION of
the tree IS parallel (Track 2/3/4 can start on completed sub-trees
before the full chain propagates). The sequential part (chain
propagation at 500ns/step) is fast enough that the parallelism
concern is theoretical, not practical.

**Challenge**: Content-addressed cells (§4.8) mean equal sub-trees
are `equal?` across modules. Is this correct for source-located code?
Two `def x := 42` in different files are structurally equal but have
different source locations. Resolution: source location is a SEPARATE
cell field (srcloc), not part of the content hash. Content equality
ignores location; srcloc provides location when needed for errors.

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
