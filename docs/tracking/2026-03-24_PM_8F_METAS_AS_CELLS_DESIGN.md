# PM Track 8F: Metas as Cells — Stage 2/3 Design

**Stage**: 2 (Audit) + 3 (Design), combined
**Date**: 2026-03-24
**Series**: PM (Propagator Migration) + SRE (Structural Reasoning Engine)
**Status**: D.1 — awaiting critique
**Depends on**: [SRE Track 2](2026-03-23_SRE_TRACK2_ELABORATOR_ON_SRE_DESIGN.md) ✅ (SRE dispatch stable), [PM Track 8D](2026-03-22_TRACK8D_DESIGN.md) ✅ (pure bridge fire functions)
**Enables**: Zonk elimination (~1100 lines), SRE Track 3 (trait resolution), SRE Track 6 (reduction), PM Track 10 (convergence)
**Source Documents**:
- [SRE Master](2026-03-22_SRE_MASTER.md) — series tracking
- [NTT Case Study: Type Checker](../research/2026-03-22_NTT_CASE_STUDY_TYPE_CHECKER.md) — `expr-meta` as deepest impedance mismatch
- [Unified Infrastructure Roadmap](2026-03-22_PM_UNIFIED_INFRASTRUCTURE_ROADMAP.md) — on/off-network boundary analysis
- [PM Track 8 PIR](2026-03-22_TRACK8_PIR.md) — infrastructure migration lessons
- [SRE Track 2 PIR](2026-03-23_SRE_TRACK2_PIR.md) — store-agnostic elaborator finding

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| Pre-0 | Micro-benchmark: meta-solution, zonk, fresh-meta call costs | ⬜ | Benchmark before building |
| 0 | Cell-primary meta-solution: read from cell, CHAMP as fallback | ⬜ | The incremental bridge |
| 1 | Eliminate elaboration-time zonk: cell reads replace solution chasing | ⬜ | ~650 call sites, biggest elimination |
| 2 | Eliminate zonk-at-depth: no bvar shifting when cells are ground | ⬜ | Highest risk — binder correctness |
| 3 | Freeze at command boundaries: single-pass cell read | ⬜ | Replaces zonk-final (~200 lines) |
| 4 | Eliminate default-metas: defaults at solve time, not boundary time | ⬜ | Level→lzero, mult→mw at cell write |
| 5 | ground-expr? unification: cell-level check (is value non-bot?) | ⬜ | Two incompatible definitions → one |
| 6 | CHAMP fallback removal: cell-only path | ⬜ | Removes dual storage |
| 7 | Verification + benchmarks + PIR | ⬜ | |

---

## 1. Vision and Goals

**High-level goal**: Make meta-variables ONLY cells on the propagator network.
Currently, metas have DUAL storage: a cell on the propagator network (for
propagation) AND an entry in the meta-info CHAMP (for lookup). Every
`fresh-meta` writes to both. Every `solve-meta!` writes to both. Every
`meta-solution` reads from the CHAMP (not the cell). This duality is the
root cause of zonk's existence: `meta-solution` returns a value from the
CHAMP, and expressions contain `expr-meta id` nodes that must be WALKED
to substitute solutions. If `meta-solution` read from the cell (which is
always current via propagation), zonk during elaboration would be unnecessary.

**What we're solving for**:
1. **Eliminate zonk during elaboration**: ~650 call sites across typing-core,
   elaborator, unify, resolution. Replace with cell reads (always current).
2. **Reduce zonk.rkt from ~1300 lines to ~200 lines** ("freeze.rkt"):
   a single-pass cell read at command boundaries. No solution chasing, no
   depth tracking, no defaulting.
3. **Unify ground-expr?**: Two incompatible definitions → one cell-level
   check (is the cell value non-bot?).
4. **Simplify solve-meta!**: Cell write triggers dependent propagators
   naturally. The re-entrant chain (`solve-meta!` → resolution → `solve-meta!`)
   simplifies because propagators handle the cascading.
5. **Remove dual storage**: CHAMP entries become metadata-only (type, source
   location, constraint info). The SOLUTION lives only in the cell.

**What "done" looks like**:
- Zero calls to `zonk` or `zonk-at-depth` during elaboration
- `zonk-final` replaced by `freeze` (~200 lines)
- `meta-solution` reads from cell via `net-cell-read`
- `ground-expr?` is one function checking cell values
- `default-metas` eliminated (defaults at solve-time)
- All 7401+ tests pass
- Suite time ≤ baseline (potential improvement from eliminated zonk walks)
- PIR written per methodology

**Performance expectations** (to check against in PIR):
- Elimination of ~650 zonk calls should improve elaboration speed
- `meta-solution` via cell read: ~4ns (struct field access) vs current CHAMP
  lookup + worldview filtering (~50-100ns). 10-25× faster per call, 128 call sites.
- `freeze` at boundaries: single-pass, O(expression size). Same as current
  zonk-final but without recursive solution chasing (each meta is read once).
- Memory: neutral or slight reduction (CHAMP entries shrink — no solution field)

---

## 2. Stage 2 Audit

### 2.1 Critical Finding: Metas Are ALREADY on Cells

`fresh-meta` (metavar-store.rkt:1603) already creates a propagator cell
via `elab-fresh-meta` (elaborator-network.rkt:108). `solve-meta!` already
writes to the cell via `elab-cell-write`. The cell IS the canonical
solution location for propagation purposes.

But `meta-solution` (metavar-store.rkt:1958) reads from the meta-info
CHAMP, not the cell. And `zonk` calls `meta-solution`. So zonk reads
from the CHAMP, not the cell.

**The fix is conceptually simple**: make `meta-solution` read from the
cell instead of the CHAMP. Then zonk — which calls `meta-solution` — sees
the cell value. If the cell is solved (non-bot), the solution is there.
If unsolved (bot), `meta-solution` returns `#f` (same as current behavior
for unsolved metas).

### 2.2 Dual Storage: Cell + CHAMP

Currently, a meta-variable has:

| Storage | What it holds | Written by | Read by |
|---------|-------------|-----------|---------|
| Cell (prop-network) | Solution value (or bot if unsolved) | `solve-meta!` via `elab-cell-write` | Bridge fire functions, `punify-dispatch-*` |
| meta-info CHAMP | Status (solved/unsolved), solution, type, source, constraints | `solve-meta!` via `elab-network-meta-info-set` | `meta-solution`, `meta-solved?`, `zonk`, resolution |
| id-map CHAMP | Meta ID → cell ID mapping | `fresh-meta` | `prop-meta-id->cell-id` |

After Track 8F:

| Storage | What it holds | Written by | Read by |
|---------|-------------|-----------|---------|
| Cell (prop-network) | Solution value (or bot if unsolved) | `solve-meta!` via `elab-cell-write` | **Everything** |
| meta-info CHAMP | Metadata only: type, source, constraints. **No solution.** | `fresh-meta` (initial), constraint registration | Error reporting, source locations |
| id-map CHAMP | Meta ID → cell ID mapping | `fresh-meta` | `prop-meta-id->cell-id` (retained) |

The solution MOVES from the CHAMP to the cell. The CHAMP retains only
metadata (type, source, constraints) that doesn't change during elaboration.

### 2.3 Zonk Architecture: What Gets Eliminated

| Function | Lines | Track 8F Fate | Rationale |
|----------|-------|---------------|-----------|
| `zonk` | ~421 | **Eliminated** during elaboration; `freeze` at boundaries | Cell reads are always current |
| `zonk-at-depth` | ~437 | **Eliminated entirely** | No bvar shifting needed — cell values are already at correct depth |
| `zonk-final` | ~2 | **Replaced** by `freeze` | Single-pass, no solution chasing |
| `default-metas` | ~393 | **Eliminated** | Defaults applied at solve-time, not boundary |
| `zonk-level` | ~8 | **Eliminated** | Level cells store ground values |
| `zonk-level-default` | ~8 | **Eliminated** | Level defaults at solve-time |
| `zonk-mult` | ~5 | **Eliminated** | Mult cells store ground values |
| `zonk-mult-default` | ~8 | **Eliminated** | Mult defaults at solve-time |
| **Total eliminated** | **~1282** | | |
| **New: `freeze`** | **~200** | Single-pass cell read at boundary | |
| **Net reduction** | **~1082 lines** | | |

### 2.4 Call Site Classification

**DURING ELABORATION (eliminated — cell reads replace):**

| Module | zonk calls | zonk-at-depth calls | Notes |
|--------|-----------|-------------------|----|
| unify.rkt | ~10 | ~10 | Codomain/binder opening |
| resolution.rkt | ~5 | ~5 | Constraint groundness checking |
| trait-resolution.rkt | ~10 | ~5 | Type arg normalization for lookup |
| typing-core.rkt | ~100+ | ~10 | Various intermediate checks |
| elaborator.rkt | ~50+ | ~5 | Intermediate type computations |
| type-lattice.rkt | ~10 | ~5 | Merge operations |
| **Total** | **~185+** | **~40** | **~225+ sites eliminated** |

**AT BOUNDARY (become `freeze`):**

| Module | zonk-final calls | Notes |
|--------|-----------------|-------|
| driver.rkt | ~15 | Global env storage, error reporting |
| expander.rkt | ~6 | Macro expansion results |
| **Total** | **~21** | **Become freeze calls** |

### 2.5 The zonk-at-depth Problem

`zonk-at-depth` exists because solutions may contain bvars (bound
variables) with de Bruijn indices relative to the SOLVE SITE. If the
meta appears under additional binders, the solution must be SHIFTED by
the depth difference.

Example: meta `?X` solved at depth 0 with solution `(expr-bvar 0)`.
If `?X` appears inside a lambda (depth 1), the solution must be shifted:
`(shift 1 0 (expr-bvar 0))` = `(expr-bvar 1)`.

**With cells, this problem disappears.** Why: the cell value is written
at solve-time at the correct depth. Readers at different depths read the
SAME cell value — but they're reading a GROUND VALUE (no bvars), because
the solution was fully elaborated before being written. A ground value
doesn't need shifting because it contains no bvars.

**But wait — can solutions contain bvars?** Yes, currently. A meta `?X`
in the codomain of `Pi(A, ?X)` can be solved to `(expr-bvar 0)` (the
bound variable introduced by Pi). With cells, this solution would be
written to the cell as `(expr-bvar 0)`. Readers at different depths would
see the same `(expr-bvar 0)` — WRONG if they're at a different depth.

**Resolution**: The solution written to the cell must be CLOSED — all bvars
replaced by fvars (free variables). This is already how PUnify works:
`decompose-pi` opens the codomain with a fresh fvar before creating the
sub-cell. The sub-cell's value is expressed in terms of fvars, not bvars.
So the cell value IS already closed for PUnify-decomposed metas.

The question: are there solve paths where solutions contain bvars?
`solve-meta!` in unify.rkt can solve a meta to any expression, including
ones with bvars. The `occurs?` check prevents cyclic solutions but not
bvar-containing solutions.

**This is the highest-risk area.** If any solve path writes a
bvar-containing solution to a cell, readers at different depths will get
wrong values. Need to verify: (a) all PUnify decomposition paths open
binders before creating sub-cells (producing fvar-containing solutions),
(b) all flex-rigid solve paths produce closed solutions, (c) document
any path that doesn't and add closing logic.

### 2.6 Two Incompatible ground-expr? Definitions

| Definition | Location | What it checks | Used by |
|------------|----------|---------------|---------|
| global-constraints.rkt:154 | "No `expr-meta` nodes" | Structural walk, no solution following | global-constraints.rkt (constraint triggering) |
| trait-resolution.rkt:50 | "No unsolved metas" (follows solutions) | Calls `meta-solved?` recursively | trait-resolution.rkt, resolution.rkt, narrowing.rkt |

With cells: both collapse to "all meta cells have non-bot values." A cell
is ground when its value is not bot. No structural walk needed — query the
cells directly.

---

## 3. NTT Speculative Syntax

```prologos
;; Before: expr-meta is a placeholder in the expression tree.
;; Zonk walks the tree, substituting solutions from the CHAMP.
;; This has no NTT analog — it's an artifact of dual storage.

;; After: metas ARE cells. The expression tree references cells.
;; Cell values are always current (propagation). "Reading" a meta
;; is reading the cell. No substitution walk.

data TypeExpr
  := ...
   | expr-meta [cell : Cell TypeLattice]   ;; a meta IS a cell reference
   | ...
  :lattice :structural
  :bot type-bot
  :top type-top

;; "zonk" becomes: read cell values (always current during elaboration)
;; "freeze" becomes: at command boundary, walk tree once, replace
;;   cell references with ground values for storage in global env
```

---

## 4. Phased Implementation

### Phase Pre-0: Micro-Benchmark Baseline

**Rationale**: Benchmark before building (3rd confirmed instance of this
pattern). Measure current costs to set targets and identify bottlenecks.

**Deliverables**:
1. `meta-solution` call cost (CHAMP lookup + worldview filtering)
2. `zonk` call cost for representative expressions (shallow, deep, ground)
3. `fresh-meta` call cost (cell allocation + CHAMP write)
4. `solve-meta!` call cost (cell write + CHAMP write + resolution trigger)
5. Frequency: how many `meta-solution` / `zonk` calls per command in the
   full test suite?
6. Cell read cost (`net-cell-read`) for comparison target

### Phase 0: Cell-Primary meta-solution

**The incremental bridge.** Change `meta-solution` to read from the cell
FIRST, falling back to the CHAMP only if no cell exists (module-loading
context where cells aren't available).

```racket
(define (meta-solution id)
  (define cell-id (prop-meta-id->cell-id id))
  (cond
    ;; Cell-primary path: read from propagator cell
    [(and cell-id (current-prop-net-box))
     (define net (unbox (current-prop-net-box)))
     (define val (net-cell-read (elab-network-prop-net net) cell-id))
     (and (not (type-bot? val)) val)]
    ;; Fallback: CHAMP path (module-loading, tests without network)
    [else
     (define info (unwrap-meta-info id))
     (and info (meta-info-solution info))]))
```

**This is behavior-preserving**: the cell and CHAMP always hold the same
solution (both are written by `solve-meta!`). The cell path is faster
(struct field access vs CHAMP lookup + worldview filtering).

**Deliverables**:
1. `meta-solution` updated to cell-primary with CHAMP fallback
2. Same for `level-meta-solution`, `mult-meta-solution`, `sess-meta-solution`
3. Full test suite passes (behavioral identity)
4. Micro-benchmark: `meta-solution` call cost before vs after

### Phase 1: Eliminate Elaboration-Time zonk

With cell-primary `meta-solution`, `zonk` already reads from cells.
But `zonk` is still called explicitly at ~225+ sites during elaboration.
Many of these calls are unnecessary: the expression is already ground
(all metas solved), or the caller immediately uses the result for a
comparison that could read cells directly.

**Strategy**: Replace `(zonk expr)` calls with `expr` directly. Where
the caller needs a ground expression, use a new `ensure-ground` that
checks (via cell reads) whether all metas in the expression are solved.

**Deliverables**:
1. Identify which zonk calls are NECESSARY (the expression contains
   metas whose solutions matter for the next step) vs DEFENSIVE
   (zonk "just in case" before comparison/storage).
2. Remove defensive zonk calls (expected: majority of ~225 sites).
3. For necessary calls: replace with `ensure-ground` or leave as
   `zonk` (which now reads from cells — still works, just unnecessary
   if solutions propagated).
4. Full test suite after each batch of removals.

**Risk**: Some zonk calls may have subtle ordering dependencies (zonk
must run AFTER a solve-meta! to see the solution). With cells, this
is handled by propagation — but if a zonk call happens in the SAME
synchronous block as a solve, the cell may not yet reflect the solution
(the cell write happens during quiescence, not immediately). Need to
verify: does `solve-meta!` write to the cell synchronously or via
queued propagation?

**Answer from audit**: `solve-meta!` calls `elab-cell-write` which calls
`net-cell-write` — this is a synchronous cell write (CHAMP update), not
a queued propagator. So the cell IS updated before `solve-meta!` returns.
Reading the cell immediately after `solve-meta!` sees the solution. No
ordering concern.

### Phase 2: Eliminate zonk-at-depth

The hardest phase. `zonk-at-depth` handles bvar shifting when solutions
are read under binders.

**Prerequisite**: Verify that all cell solutions are CLOSED (no bvars).

**Deliverables**:
1. **Audit**: grep for all `solve-meta!` calls. For each, verify that
   the solution expression is closed (contains fvars, not bvars). The
   PUnify path decomposes binders with `open-expr` before solving —
   solutions should be fvar-based. The flex-rigid path in unify.rkt
   may solve with bvar-containing expressions — need to check.
2. If any solve path produces bvar-containing solutions: add a closing
   step (replace bvars with fvars) before cell write. This is a
   correctness requirement, not an optimization.
3. Once all solutions are guaranteed closed: replace `zonk-at-depth`
   calls with plain cell reads. The depth parameter becomes irrelevant.
4. Delete `zonk-at-depth` function.

### Phase 3: Freeze at Command Boundaries

Replace `zonk-final` with `freeze`: a single-pass walk that reads cell
values for each `expr-meta`, producing a ground expression for storage
in the global environment.

**Deliverables**:
1. `freeze` function (~200 lines): walks expression tree, replaces
   `expr-meta id` with `(net-cell-read net cell-id)`. No recursion on
   solutions (cell values are already ground from propagation). No
   depth tracking (expressions at boundaries are already closed).
2. Replace all ~21 `zonk-final` calls with `freeze` calls.
3. Delete `zonk-final` and `default-metas`.
4. Full test suite passes.

### Phase 4: Defaults at Solve-Time

Currently, `default-metas` (called by `zonk-final`) replaces unsolved
level-metas with `lzero` and unsolved mult-metas with `'mw` at command
boundary. With cells, defaults should be applied at the END of elaboration
(after the stratified resolution loop completes and before freeze), by
writing default values to unsolved level/mult cells.

**Deliverables**:
1. `apply-defaults!`: Walk the unsolved-metas tracking cell. For each
   unsolved meta: if it's a level-meta, write `lzero` to its cell. If
   mult-meta, write `'mw`. If type-meta, leave as-is (will become a
   hole in the frozen expression).
2. Call `apply-defaults!` in driver.rkt after `resolve-trait-constraints!`
   and before `freeze`.
3. Delete `default-metas`, `zonk-level-default`, `zonk-mult-default`.

### Phase 5: Unify ground-expr?

Replace two incompatible `ground-expr?` definitions with one cell-level
check.

**Deliverables**:
1. `ground-expr?` becomes: walk expression, for each `expr-meta id`,
   check if its cell value is non-bot. If all meta cells are non-bot,
   the expression is ground.
2. Or simpler: `ground-meta? id` = `(not (type-bot? (net-cell-read net cell-id)))`.
   Then `ground-expr?` walks the tree checking `ground-meta?` for each
   `expr-meta`.
3. Delete the two separate definitions. Single definition in a shared
   module.
4. All call sites updated (58 total across 4 modules).

### Phase 6: CHAMP Fallback Removal

Once all meta access goes through cells, the CHAMP solution field is
unused. Remove it.

**Deliverables**:
1. `meta-info` struct: remove `solution` field. Retain: type, source,
   constraints, status.
2. `solve-meta-core!` / `solve-meta-core-pure`: remove CHAMP solution
   write. Cell write is the only solution storage.
3. `meta-solution`: remove CHAMP fallback. Cell-only path.
4. `with-fresh-meta-env`: simplify — no CHAMP solution initialization.
5. Full suite passes. No behavioral change.

### Phase 7: Verification + Benchmarks + PIR

**Deliverables**:
1. Full test suite: all pass
2. Micro-benchmark: meta-solution, fresh-meta, solve-meta! costs vs Pre-0
3. Suite wall time vs baseline
4. Code delta: lines removed from zonk.rkt, metavar-store.rkt
5. PIR per methodology (19 sections)
6. Update SRE Master, Master Roadmap, dailies

**Completion criteria**:
1. Zero calls to `zonk` or `zonk-at-depth` during elaboration
2. `zonk-final` replaced by `freeze` (~200 lines)
3. `meta-solution` reads from cell (no CHAMP fallback in production path)
4. `ground-expr?` is one function checking cell values
5. All 7401+ tests pass
6. Suite wall time ≤ baseline

---

## 5. Performance Expectations

| Metric | Baseline | Target | Rationale |
|--------|----------|--------|-----------|
| Suite wall time | ~238s | ≤ 230s (potential 3% improvement) | Eliminated ~650 zonk calls |
| meta-solution | ~50-100ns (CHAMP + worldview) | ~4ns (cell read) | 10-25× faster, 128 call sites |
| zonk calls during elaboration | ~225+ per command | 0 | Cell reads replace solution chasing |
| zonk.rkt lines | 1317 | ~200 (freeze.rkt) | ~1100 lines eliminated |
| ground-expr? definitions | 2 (incompatible) | 1 (cell-level) | Unified |
| default-metas | 393 lines | 0 (defaults at solve-time) | ~20-line apply-defaults! |
| Memory | Baseline | Slight reduction | CHAMP entries shrink (no solution field) |

---

## 6. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| bvar-containing solutions in cells | **CRITICAL** | Phase 2 audit: verify all solve paths produce closed solutions. Add closing step if not. |
| Ordering: solve-meta! + immediate cell read | HIGH | Verified: elab-cell-write is synchronous. Cell value available immediately. |
| Module-loading context (no cells) | HIGH | Phase 0 CHAMP fallback retained. Phase 6 addresses after cells available everywhere. |
| zonk removal breaks subtle ordering | MEDIUM | Incremental removal with full suite after each batch. Rollback individual removals. |
| ~225 zonk call sites to review | MEDIUM | Classify as necessary vs defensive first. Remove defensive calls in bulk. |
| with-fresh-meta-env (306 call sites) | MEDIUM | Phase 6 scope. Most are tests — change once, verify all. |
| default-metas timing (must happen after resolution) | LOW | apply-defaults! called explicitly in driver.rkt after resolution. Clear ordering. |

---

## 7. Principles Alignment (Challenge, Not Catalogue)

### Propagator-First
**Challenge**: Is `freeze` at boundaries "off-network"?
**Answer**: `freeze` reads FROM the network (cell values). It doesn't
compute anything — it serializes network state into a persistent
expression for the global env. This is the network→storage boundary,
analogous to writing a database to disk. The computation (elaboration,
inference, resolution) is fully on-network. Freeze is I/O, not computation.

### Data Orientation
**Challenge**: Is removing the CHAMP solution field a data orientation
improvement?
**Answer**: Yes. Currently, the solution exists in TWO places (cell and
CHAMP) — violating single-source-of-truth. After Track 8F, the cell IS
the solution. The CHAMP retains only metadata (type, source, constraints)
that is genuinely separate from the solution value. No duplication.

### Completeness
**Challenge**: Are we deferring anything?
**Answer**: Module-loading context (no cells available) retains the CHAMP
fallback through Phase 5. Phase 6 removes it. This is a genuine
dependency — cells require the propagator network, which isn't available
during module loading. PM Track 10 (module loading on-network) resolves
this. The deferral is justified.

### Correct-by-Construction
**Challenge**: The bvar-in-cell risk (§2.5) — can we make it
structurally impossible for bvar-containing solutions to be written
to cells?
**Answer**: Phase 2 should add an ASSERTION in `solve-meta!`: verify
the solution is closed (no bvars) before cell write. This is a
debug-mode check that catches any solve path that produces unclosed
solutions. The assertion makes the invariant explicit and testable.

### Composition
**Challenge**: Does cell-primary meta-solution compose with the
existing speculation/TMS infrastructure?
**Answer**: Yes. TMS-tagged cells already handle speculation. When a
meta is solved speculatively, the solution is tagged with an assumption
ID. Cell reads through `worldview-visible?` filter correctly. The
cell-primary path inherits this filtering — it reads from the cell,
which is TMS-aware.

---

## 8. What This Opens Up

- **SRE Track 3 (Trait Resolution)**: Resolution can check cell values
  directly instead of calling `zonk` → `meta-solution` → CHAMP lookup.
- **SRE Track 6 (Reduction)**: Reduction reads cell values for
  normalization. No zonk needed — cells are always current.
- **PM Track 10 (Convergence)**: When module loading is on-network,
  the CHAMP fallback is eliminated. Cell-only path everywhere.
- **Incremental re-elaboration**: Cell values are always current. When a
  definition changes, the cells that depend on it get re-propagated.
  The freeze at the boundary produces updated results. No full re-elaboration
  needed — just the affected cells. (Long-term: LSP-grade re-checking.)
- **Self-hosting trajectory**: The elaborator operating on cells is the
  step that makes it expressible in Prologos itself (cell reads = the
  language's own propagator semantics).

---

## 9. Relationship to Prior Work

| Track | What it delivered | How 8F builds on it |
|-------|------------------|-------------------|
| PM 8A | TMS-tagged meta-info CHAMP | TMS filtering preserved in cell reads |
| PM 8B | Worldview-aware reads | Cell reads inherit worldview filtering |
| PM 8D | Pure bridge fire functions | Bridges already read from cells — 8F makes this universal |
| SRE Track 0 | Form registry | ctor-descs unchanged by meta storage change |
| SRE Track 1 | Relation engine | Subtype/duality use cell values — benefit from faster reads |
| SRE Track 2 | Classifier → SRE dispatch | Classifier is stable; meta handling isolated to flex cases |
