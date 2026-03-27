# PPN Track 1: Lexer + Structure as Propagators

**Stage**: 3 (Design)
**Date**: 2026-03-26
**Series**: PPN (Propagator-Parsing-Network)
**Status**: D.5 — Propagator Only revision.
D.1 sweep → D.2 constraint chain → D.3 self-critique → D.4 external
critique → **D.5 Propagator Only**: no algorithms, only lattice
specifications whose fixpoint IS the parse tree. Guided by the
Hyperlattice Conjecture.

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
| Pre-0 | Microbenchmarks + RRB vs CHAMP | ✅ | `b076359`+D.6 — 370ns/token, RRB 9× build, tree-builder 4.5μs/200 lines |
| 0 | Golden baseline: 4-level capture for 110 files | ✅ | `f677847` — 110/110, 0 failures. data/golden/ |
| 1a | Character + indent RRB cells | ✅ | `8b7757c` — parse-reader.rkt. 21 tests. 5-cell creation on prop-network. |
| 1b | Tokenizer propagator (char RRB → token RRB) | ✅ | `5819465` — 18 patterns, priority dispatch, set-of-types. 15 tests. |
| 1c | Tree-builder propagator (indent+bracket RRBs → tree M-type cell) | ✅ | `9af5b2d` — parse-tree-node with RRB children. Parent from indent + bracket suppression. 4 tests. |
| 1d | Bracket-depth RRB propagator (token RRB → bracket RRB) | ✅ | `9af5b2d` — running sum + qq-depth channel. 4 tests. |
| 1e | Context disambiguator (tree cell → token RRB reclassify) | ✅ | `006ffec` — disambiguate-tokens + parse-string-to-cells. bd-before fix. 7 tests (51 total). |
| 1f | **Integration gate**: golden comparison on simple files | ✅ | `6df01a9` — topology matches all 110 .prologos files. 7 tests (58 total). |
| 2 | Reader macros: #p, ', `, #=, dot-access, broadcast | ✅ | `a046558` — 17 new recognizers, priority ordering. 17 tests (75 total). |
| 3a | Read API (5 tree-walking functions) | ✅ | `33bfcb1` — parse-tree struct, read-to-tree, tree-top-level-forms, tree-children, tree-parent. 8 tests. |
| 3b | Write API (4 tree mutation functions) | ✅ | `33bfcb1` — tree-replace-children, tree-insert-child, tree-remove-child, tree-splice. 4 tests (87 total). |
| 3c | Compatibility wrappers (7 functions) | ✅ | `65fa3dd` — compat-token struct, compat-tokenize-string, token→value conversion. 7 tests (94 total). |
| 4 | Golden comparison: 4 levels vs Phase 0 baseline | ✅ | `801e9d1` — topology 110/110, brackets 110/110. Datums/srclocs deferred to parser integration. 3 tests (97 total). |
| 5a | Datum extraction: tree → syntax objects | ✅ | `a2dd08a` — 41/72 lib files match (57%). Bracket grouping, sentinels, escapes, ::. 11 tests (108 total). |
| 5b | Multi-line bracket fix + remaining files | ⬜ | 31 files with multi-line grouping differences. |
| 5c | Wire into driver.rkt + consumer migration | ⬜ | |
| 6 | `rrb-diff` implementation | ⬜ | RRB structural diff for incremental (Track 8 ready). |
| 7 | A/B benchmarks (integrated system) | ⬜ | Target: ≤460μs (current reader). Estimated: ~306μs. |
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
4. **Incremental re-computation is a fixpoint property**, not an optimization.
5. **Content hashing is affordable**: 83 ns/hash, ~100-500 cells/file = 8-40 μs.
6. **110 files for golden comparison.** Largest: 1,164 lines.

### Cell count and cost estimate (D.6)

For nat.prologos (130 lines, 491 tokens, ~4000 chars):

| Domain | Storage | Cells | Creation cost |
|--------|---------|-------|--------------|
| Character | RRB embedded cell | 1 | ~93 μs |
| Token | RRB embedded cell | 1 | ~11 μs |
| Indent | RRB embedded cell | 1 | ~2 μs |
| Bracket-depth | RRB embedded cell | 1 | ~11 μs |
| Structure (tree) | M-type value cell | 1 | ~1.4 μs |
| **Total** | **5 cells, 4 RRBs** | **5** | **~119 μs** |

Current reader: 460 μs. New reader (estimated): **~306 μs. 1.5× faster.**

**D.8 correction**: The 119 μs (D.7) estimate excluded propagator FIRE
FUNCTION costs. The tree-builder propagator reads indent RRB (O(n)) and
computes parent assignments — this IS computation, not just cell creation.
Benchmarked: tree builder = 4.5 μs/200 lines, 102 μs/4000 lines. Token
classification = ~182 μs (491 tokens × 370 ns). Adding fire function
costs gives ~306 μs — still 1.5× faster than the current reader (460 μs),
with incremental-ready architecture.

**Parallelization potential**: The tree-builder's O(n) fire function is
a PREFIX SCAN over indent levels. The monoid is STACK-TRANSFORMING
FUNCTIONS under composition (D.9 #4): each line contributes a function
`stack → (parent, stack')`. Function composition is always associative.
Parallel prefix scan (Blelloch 1990): O(n/p + log n) on p processors. For 4000 lines on 10 processors: ~8 μs vs 102 μs sequential
(12× speedup). This requires BSP-LE's parallel scheduler with
topological-sort rounds — Track 1 implements sequential, future tracks
parallelize without changing the propagator interface.

**The entire parse state in 5 cells.** Each sequential domain (characters,
tokens, indent levels, bracket depths) is an RRB embedded cell. The tree
structure is ONE cell holding an M-type value (initial algebra of the
parse tree polynomial functor — the same representation the SRE uses for
type expression trees like `expr-Pi`).

**Why this works**: The Pocket Universe principle. Each RRB cell is an
embedded lattice of positionally-indexed values. The tree cell is an
embedded lattice of tree topologies ordered by "more nodes resolved."
Five pocket universes, five cells, one fixpoint.

**SRE decomposition on the tree cell**: When Track 2 needs to match/
rewrite a sub-tree, the SRE decomposes the tree value:
`structural-relate(tree-cell, def-form(name, type, body))` extracts
sub-trees as sub-cells. Macro rewrite operates on sub-cells. SRE
reconstructs and writes back. Same mechanism as type-level decomposition.

**Tree growth is monotone**: The tree cell starts at bot (empty).
Propagators fire and write increasingly complete trees. The merge
function: tree union (add nodes the new tree has that the old doesn't).
The fixpoint is the complete parse tree.

**Incremental via RRB diff**: The tree-building propagator reads indent
+ bracket-depth RRBs. When an RRB entry changes (edit), the propagator
receives the DIFF (which positions changed) via RRB structural sharing.
It re-resolves only affected tree nodes. Unchanged nodes are structurally
shared between old and new tree values. O(affected lines), not O(n).

---

## 1. Architectural Center: The Fixpoint IS the Parse Tree

### The Hyperlattice Conjecture (Propagator Network Conjecture)

**Postulate**: Any computation can be expressed as a fixpoint over
interconnected lattice structures (propagator networks).

**Corollary**: For any given computation, there exists an optimal
propagator network expression along some axis of optimality.

This is not merely a design choice — it rests on Tarski's Fixed Point
Theorem (every monotone function on a complete lattice has a least
fixpoint) and the CALM theorem (monotone computations are coordination-
free, hence optimally parallelizable).

### What this means for parsing

There IS NO parsing algorithm. There is a LATTICE SPECIFICATION whose
fixpoint IS the parse tree.

```
Lattice domains:              Fixpoint:
  Character cells               root
  Token cells                     └── def-form
  Indent cells                        ├── "def" (token cell)
  Parent cells                        ├── "x" (token cell)
  Bracket-depth cells                 ├── ":=" (token cell)
  Structure cells                     ├── "42" (token cell)
                                      └── where-block (structure cell)
                                          └── "[Eq x]" (child form)
```

The parse tree is the UNIQUE fixpoint of the lattice product. We don't
BUILD the tree — we SPECIFY the lattices, install propagators that
express the relationships between lattice domains, and the fixpoint
computation produces the tree.

The "algorithm" is: populate character cells → propagators fire →
fixpoint reached → tree exists. The SCHEDULER determines firing order.
The LATTICES determine the result. The result is the same regardless
of firing order (monotonicity guarantees this).

### Propagator Only (not Propagator First)

D.5 revision: we don't merely PREFER propagators — we use ONLY
propagators. Every aspect of parsing is a lattice domain with a
monotone merge. Cross-domain relationships are propagators. The
parse tree is a fixpoint. There are no imperative algorithms.

**Process smell**: If we say "the algorithm does X," we're thinking
imperatively. The propagator framing: "the fixpoint of domain X
with respect to propagators P is the result R."

### Structural preservation by fixpoint

A `defmacro` rewrite is a propagator that reads tree cells, detects
a pattern, and writes a transformed value. The tree's OTHER cells are
unaffected (they're at their own fixpoints). After the rewrite, the
network re-quiesces — the fixpoint adjusts to account for the rewrite.
Indentation structure is preserved because parent-child cells are
AT FIXPOINT and the rewrite doesn't change their inputs.

### Trees compose into forests

Each `.prologos` file's fixpoint is a tree. Module imports create
cross-tree propagators. The forest is the fixpoint of ALL module
trees connected by import edges. Track 10's `.pnet` cache serializes
individual tree fixpoints. The forest fixpoint is computed by
loading + connecting individual trees.

---

## 2. Lattice Domains and Their Product

### 2.1 Six lattice domains (D.5 revision)

The parse tree is the fixpoint of SIX interconnected lattice domains.
Each domain has a carrier set, a merge function, and bot/top values.
Propagators connect domains — information flows omnidirectionally
through cells until fixpoint.

| Domain | Carrier | Merge | Storage | What it represents |
|--------|---------|-------|---------|-------------------|
| **Character** | RRB(position → char) | RRB point-update | 1 embedded cell | Raw input |
| **Token** | RRB(position → Set(token-type)) | RRB point-update (set-NARROW) | 1 embedded cell | Token classification (set of possible types, narrowed by disambiguation) |
| **Indent** | RRB(line → indent-level) | RRB point-update | 1 embedded cell | Leading whitespace |
| **Bracket-depth** | RRB(position → (bracket-depth . qq-depth)) | RRB point-update | 1 embedded cell | Bracket nesting + quasiquote depth (D.9 #1) |
| **Structure** | Tree (M-type) | tree-union (add nodes) | 1 cell | Parse tree topology |

**5 cells total.** Parent assignments are INSIDE the tree M-type value
(each tree node carries its parent). No separate parent domain needed —
it's a field of the tree node, not a separate lattice.

**The product of these six domains, at fixpoint, IS the parse tree.**

No domain is "primary." No domain "drives" the others. The propagators
express RELATIONSHIPS between domains. The fixpoint emerges from
ALL relationships being satisfied simultaneously.

### 2.1b CHAMP-backed lattice domains (D.6)

**Insight**: A CHAMP IS a lattice. Each CHAMP entry is a cell. The
CHAMP's structural sharing provides change tracking FOR FREE.

The character domain uses an **RRB persistent vector** (not individual
cells, not CHAMP). Benchmark (D.6):

| Operation | CHAMP | RRB | Individual cells |
|-----------|-------|-----|-----------------|
| Build 4K chars | 868 μs | **93 μs** | 5,600 μs |
| Seq read 4K | 252 μs (63 ns/char) | **75 μs (19 ns/char)** | ~12 μs (3 ns/cell-read) |
| Point update | 135 ns | 88 ns | 3 ns (cell write) |

RRB wins on build (9×) and sequential read (3×) vs CHAMP. Individual
cells win on per-entry access but lose catastrophically on creation
(60× slower). RRB is the sweet spot: fast build, fast sequential
access (token producers scan spans), persistent structural sharing
(incremental editing via path-copy + diff).

**Why RRB over CHAMP for sequential data**: RRB's radix indexing keeps
sequential positions in contiguous memory blocks (branching factor 32 =
32 consecutive chars per node). CHAMP distributes by hash — consecutive
positions scatter across trie branches, causing cache misses.

**Characters ARE lattice values** (D.5): stored in an RRB persistent
vector, which IS a lattice (entries are cells, structural sharing
provides change tracking). No Propagator Only violation — the RRB IS
the cell infrastructure for this domain, optimized for sequential
access patterns.

**This pattern generalizes.** Any lattice domain with many small
set-once values in sequential positions (characters, bracket depths,
source locations) benefits from RRB-backed bulk storage. Domains with
associative access patterns (registries, meta-info) stay CHAMP-backed.
Match the data structure to the access pattern.

### 2.2 Propagators between domains

| Propagator | Reads | Writes | Relationship |
|-----------|-------|--------|-------------|
| Token classifier | Character RRB (span) | Token RRB (entry) | "These characters classify as this token" |
| Indent measurer | Character RRB (line starts) | Indent RRB (entry) | "This line has N leading spaces" |
| Bracket tracker | Token RRB (brackets + backticks) | Bracket-depth RRB (bracket + qq-depth) | "Depth at P = depth at P-1 ± this bracket/backtick" |
| Tree builder | Indent RRB + Bracket-depth RRB | Tree cell (M-type) | "Given indents + brackets, the tree topology is..." |
| Postfix adjacency | Token RRB (spans) + Tree cell | Token RRB (reclassify `[`) | "If `[` start = prev token end → postfix index, not new bracket" (D.9 #6) |
| Context disambiguator | Tree cell (bridge γ) | Token RRB (set-narrow) | "Given parse context, narrow token type set" |

**Note (D.7)**: The per-line chain of parent resolvers (D.2-D.5) is
REPLACED by a single tree-builder propagator that reads indent + bracket
RRBs and computes the entire tree M-type. Incremental behavior comes
from RRB diff (which entries changed) → tree-builder re-resolves only
affected nodes → structural sharing on the tree value.

### 2.3 The coupling dissolved (not broken)

The audit found reader.rkt's parser mutates tokenizer state (bracket-
depth). In the imperative model, this is COUPLING. In the propagator
model, there IS no coupling to break — bracket depth is a LATTICE DOMAIN
that both token classification and indent resolution READ. Information
flows through cells, not through mutation. The "coupling" was an artifact
of imperative state sharing. In the lattice product, each domain reads
what it needs from other domains' cells. This is not coupling — it's the
natural information flow of the fixpoint computation.

---

## 3. Token Classification Domain

### 3.1 Pattern inventory (from audit §2)

Each pattern is a PROPAGATOR between the character domain and the token
domain. It reads character cells at a span and writes the token cell
for that span:

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

### 3.2 Token pattern propagators

Each pattern is a REGISTERED PROPAGATOR SPECIFICATION (like SRE
ctor-desc). When character cells at a position are populated, the
pattern propagators for that position fire. The highest-priority
match writes the token cell.

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

The recognizer reads character cells from a position and returns how
many characters match (or #f). The classifier determines the token
type. Priority resolves when multiple patterns match the same span
(`:=` has higher priority than `:` alone).

**No sweep.** The propagators fire when their input cells (character
cells) are populated. The scheduler determines firing order. For a
file read sequentially, characters become available left-to-right,
so token propagators fire left-to-right. For a pre-loaded buffer (all
characters available), token propagators COULD fire in any order.
The result is the same — the fixpoint is order-independent.

**Some token patterns are stateful** (D.3b finding): string literals
track escape state, `#p(...)` counts nested brackets. These patterns
carry LOCAL state within their recognizer — they are context-free
(don't read other cells) but stateful (track progress within their
match). The state is INTERNAL to the recognizer function, not shared
with other propagators.

---

## 4. Indent, Parent, and Structure Domains — The Tree as Fixpoint

### 4.1 The tree IS a fixpoint (D.5 revision)

The parse tree is not BUILT — it is COMPUTED as the fixpoint of three
lattice domains (indent, parent, structure) connected by propagators.

- **Indent domain**: each content line holds its indent level (measured
  from character cells). Monotone: set-once.
- **Parent domain**: each content line holds its parent line-id
  (computed from indent cells). Monotone: set-once.
- **Structure domain**: each tree node holds its children (accumulated
  from parent assignments). Monotone: children only grow.

The tree topology EMERGES from the fixpoint of these three domains.
We don't build the tree — we specify the lattices and their
relationships, and the fixpoint IS the tree.

**Incrementality is a PROPERTY of the fixpoint**, not an optimization.
Editing a cell value causes dependent propagators to re-fire. The
network re-quiesces at a new fixpoint. Only AFFECTED cells change.
This is not O(affected lines) as an algorithm — it's the DEFINITION
of fixpoint re-computation under changed inputs.

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

**SRE connection (D.4 research note)**: Tree rewriting IS structural
unification. A `defmacro when [$cond $body] [if $cond $body unit]` is:
decompose cell against `when(cond, body)` (SRE pattern match), compose
`if(cond, body, unit)` from the same sub-cells (SRE reconstruction).
Track 1's mutation functions are the MECHANICAL layer that the SRE
calls. Track 2 wraps this in `sre-rewrite` — macro patterns register
as SRE rewrite rules. See [research note](../research/2026-03-26_TREE_REWRITING_AS_STRUCTURAL_UNIFICATION.md).

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

**Propagator Only** (D.5 — upgraded from "Propagator First"): The parse
tree is the fixpoint of six lattice domains. There are no algorithms —
only lattice specifications, propagators expressing relationships, and
fixpoint computation. The data flow IS the computation. The scheduler
determines execution order; the lattices determine the result.

**Process smell**: "The algorithm does X" → rephrase as "the fixpoint
of domain X with respect to propagators P is the result R."

**Token pattern registry** (D.3 note): Static registration of patterns
as a Racket hash is acceptable — patterns are part of the SPECIFICATION,
not the computation. They don't change during fixpoint computation. If
Track 7 makes patterns dynamic, they become cells.

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

## 11. Resolved Design Points (D.8b)

### 11.1 Tree node: RRB-backed children (D.8c)

The tree node is a dedicated struct with RRB children:

```racket
(struct parse-tree-node
  (tag         ;; symbol or token-cell-value: what kind of form
   children    ;; rrb of parse-tree-node: ordered children
   srcloc      ;; source location (file, line, col, span)
   indent      ;; indent level (int)
   )
  #:transparent)
```

**Why RRB children, not cons lists**: Benchmark (D.8c):

| Operation (n=20 children) | List | RRB | Winner |
|--------------------------|------|-----|--------|
| Append child | 56 ns | **30 ns** | RRB 1.9× |
| Count children | 13 ns | **9 ns** | RRB 1.5× |
| Structural sharing on modify | none | **yes (eq? preserved)** | RRB |

Track 2's rewriting (insert, remove, splice children) benefits from
RRB's O(log32 n) operations + structural sharing. Two sub-trees with
same content share RRB nodes — critical for the Pocket Universe M-type.

The tree cell's value IS a `parse-cell-value` (from Track 0) where
each derivation-node holds a `parse-tree-node` as its "item." For
unambiguous input: one derivation. For ambiguous: set of alternative
derivations, resolved by ATMS (Track 5).

The compatibility API extracts S-expressions from parse-tree-nodes
(recursive: tag + children → nested list). `datum->syntax` wraps with
Racket source location for the production path (driver.rkt).

### 11.2 Tree merge: set-union of alternatives, NOT unification (D.8c)

The tree cell uses Track 0's `parse-cell-value` with set-union.

**Verified against SRE precedent**: The type lattice merge (`type-
lattice-merge` in type-lattice.rkt:125) uses STRUCTURAL UNIFICATION —
if two values unify, merge is the unified result. This is WRONG for
parse trees. Two parses of the same input are ALTERNATIVES, not values
to unify. They coexist until disambiguation selects one.

**Two-layer merge semantics**:
- **Between alternative parses**: set-union of derivation-nodes. Each
  derivation holds a `parse-tree-node` tree. Multiple alternatives
  accumulate monotonically.
- **Within one parse (tree growth)**: as parsing progresses, the tree
  grows (more nodes). A new derivation-node with more nodes SUPERSEDES
  the old (same derivation-id, more complete tree). Set-union handles
  this: the new element replaces the old via id-based dedup.

Set-union IS correct. The type lattice's unification merge is for a
DIFFERENT problem (resolving constraints on one value). Parse trees
accumulate alternatives (set-union), not resolve constraints (unify).

### 11.3 Token classification: set-latch interface, O(n) implementation (D.8c)

**Interface**: each token position is INDEPENDENTLY classifiable. Given
the character span for position P, the classification depends only on
the characters at that span (+ registered patterns). No dependency on
other token positions. This is the SET-LATCH pattern: each position is
a latch that fires independently when its input is available.

**Track 1 implementation**: ONE tokenizer propagator reads the entire
character RRB and writes the entire token RRB. O(n) work, ~370 ns/token.
This is optimal for SEQUENTIAL execution (one propagator, no scheduling
overhead).

**Token cells hold SETS of possible types (D.9 #2)**: The initial
tokenizer writes the set of ALL matching patterns for each position.
For unambiguous tokens (99%): the set has one element (same cost as
set-once). For ambiguous tokens (e.g., `>` = `{operator, delimiter}`):
the set has multiple elements. The disambiguator NARROWS by intersection:
`merge({operator, delimiter}, {delimiter}) = {delimiter}`. Under
reversed subset ordering (smaller set = more information), narrowing is
MONOTONE. This resolves the set-once vs reclassification contradiction
from Track 0's lattice spec.

**Parallel pivot (BSP-LE)**: Replace the one propagator with N
per-TOKEN latches (D.9 #3 correction: token granularity, not position
granularity). Each reads its character span, classifies independently.
Multi-character tokens require sequential scanning from start position,
so parallelism is at token boundaries (~2 tokens/line), not per-char.

**The interface is parallel-ready from day one.** The implementation
is sequential for Track 1. The pivot to parallel is a PROPAGATOR
REPLACEMENT (one O(n) → N O(1) latches), not an architecture change.

For incremental (Track 8): RRB diff tells which character positions
changed. Re-classify only changed spans + context. O(affected).

### 11.4 Disambiguation cycle: single stratum, ≤2 rounds

The token → tree → disambiguation → token cycle resolves in ONE stratum
via monotone fixpoint. Disambiguation only REFINES tokens (operator →
delimiter, never reverse). Refinements are finite (each token reclassified
at most once). The cycle converges in ≤2 rounds:

1. Initial tokenization → tree builder fires → disambiguator fires
   (may reclassify some tokens)
2. If tokens changed → tree builder re-fires → disambiguator re-fires
   (no further changes — refinement exhausted)
3. Quiescence.

No stratification needed for this cycle. Stratification is for
non-monotone operations (Track 5 elimination, Track 6 error recovery).

**Termination proof (D.9 #5)** — specific to Prologos grammar:
(a) Only `>` and `-` undergo bridge-γ reclassification.
(b) `>` reclassification changes regular bracket-depth but NOT
    angle-depth (separate counters in reader.rkt lines 54-55).
(c) Angle-depth is the ONLY context that triggers `>` reclassification.
(d) Therefore: `>` reclassification cannot trigger further `>`
    reclassification (bracket-depth change doesn't affect angle-depth).
(e) `-` reclassification depends on PRECEDING token type. Reclassifying
    `-` doesn't change the preceding token. No cascade.
(f) QED: ≤2 rounds. ∎

### 11.6 One-cell tree justification (D.9 #7)

Track 1 builds the tree ONCE (not incrementally). One cell is simpler
and 300× fewer allocations than per-node cells. Track 8 (incremental)
can decompose into per-node cells when needed. The RRB structural
sharing inside the one-cell tree value gives granularity within the
cell (unchanged subtrees shared between old and new values).

The explicit choice: one cell for Track 1 (batch build). Per-node cells
for Track 8 (incremental editing). The tree M-type representation
supports both — the data is the same, the cell granularity differs.

### 11.7 Token value semantics (D.9 #9)

The current reader's `token.value` stores PARSED values: integer `42`,
symbol `def`, keyword `:=`. The new `token-cell-value.lexeme` stores
RAW STRINGS: `"42"`, `"def"`, `":="`.

The compatibility wrapper for `tokenize-string` must replicate the
parsing: `(case type [(number) (string->number lexeme)] [(symbol)
(string->symbol lexeme)] ...)`

This is bounded work (~10 cases) in the wrapper. The primary API
exposes raw lexemes. Track 2+ consumers that need parsed values call
a shared `parse-token-value` helper.

### 11.8 Tree growth: keyed map with per-key refinement (D.9 #10)

The parse-cell-value's derivation set is keyed by derivation-id.
Within a key, a more-complete tree supersedes a less-complete tree
(prefix ordering: more nodes = higher). Between keys, set-union
accumulates alternatives. This is a MAP with per-key monotone
refinement, not a bare set. Both operations are monotone.

### 11.9 Consumer API audit (51 files)

| API | Production files | Test files | Total |
|-----|-----------------|------------|-------|
| `prologos-read-syntax-all` (syntax objects) | driver.rkt | 3 | 4 |
| `prologos-read-syntax` (single syntax) | repl.rkt | 1 | 2 |
| `read-all-forms-string` (datums) | form-deps.rkt | 11 | 12 |
| `tokenize-string` (flat tokens) | — | 12 (5 tokenize-only) | 12 |
| `prologos-read` (single datum) | — | 5 | 5 |
| `token-type`/`token-value` (accessors) | — | 8 | 8 |

**Critical path**: driver.rkt → `prologos-read-syntax-all` → syntax
objects with srcloc. Compatibility wrapper must produce Racket syntax
objects via `datum->syntax` with source locations from token cells.

**Simple path**: 12 test files → `read-all-forms-string` → plain
datums. Tree cell datum extraction.

**Tokenize path**: 12 test files → `tokenize-string` → flat token list.
Token RRB → list conversion.

---

## 12. Completion Criteria

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
