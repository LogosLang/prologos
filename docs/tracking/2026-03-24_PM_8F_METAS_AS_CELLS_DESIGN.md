# PM Track 8F: Metas as Cells — Stage 2/3 Design

**Stage**: 2 (Audit) + 3 (Design), combined
**Date**: 2026-03-24
**Series**: PM (Propagator Migration) + SRE (Structural Reasoning Engine)
**Status**: D.3 — revised with external critique
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
| Pre-0 | Micro-benchmark + adversarial testing | ✅ | Key findings: id-map is bottleneck (82ns), meta-solution ALREADY cell-primary, bvar risk confirmed |
| 0 | **bvar closure invariant** (correctness prerequisite) | ⬜ | Assertion in solve-meta! — bvar-containing solutions are written today |
| 1 | **Embed cell-id in expr-meta** (skip id-map lookup) | ⬜ | 82ns → ~4ns per meta-solution. The meta IS the cell. |
| 2 | Eliminate defensive zonk calls (cell reads sufficient) | ⬜ | ~225+ sites, classify necessary vs defensive |
| 3 | Eliminate zonk-at-depth (after bvar closure guaranteed) | ⬜ | Highest risk — binder correctness. Depends on Phase 0. |
| 4 | Freeze at command boundaries: single-pass cell read | ⬜ | Replaces zonk-final (~200 lines) |
| 5 | Defaults at solve-time (eliminate default-metas) | ⬜ | Level→lzero, mult→mw at cell write |
| 6 | ground-expr? unification: cell-level check | ⬜ | Two incompatible definitions → one |
| 7 | CHAMP fallback removal: cell-only path | ⬜ | Removes dual storage + id-map |
| 8 | Verification + benchmarks + PIR | ⬜ | |

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

### 2.7 Pre-0 Benchmark Findings (D.2 Revision)

The Pre-0 micro-benchmarks revealed 5 findings that fundamentally change
the design priorities:

**Finding 1: Id-map lookup is the real bottleneck (82ns).**

`meta-solution` costs ~150ns total: id-map CHAMP lookup (82ns) + cell
CHAMP read (52ns) + overhead (16ns). The CHAMP solution field isn't even
in the read path — `meta-solution` already reads from cells (line 1958).
The D.1 design's Phase 0 ("cell-primary meta-solution") is a NO-OP — it
describes the CURRENT architecture.

**Design adjustment**: The highest-leverage change isn't "remove CHAMP
solution field" — it's "embed cell-id directly in `expr-meta`." If
`expr-meta` carried `(id cell-id)` instead of just `(id)`, we skip the
82ns id-map lookup entirely. `meta-solution` becomes: extract cell-id
from struct (4ns) + `elab-cell-read` (52ns) = ~56ns. That's 2.7× faster
per read, across 128+ call sites.

This changes the `expr-meta` struct definition — touching the entire AST
pipeline (syntax.rkt → all 14 pipeline files). But it's the RIGHT change:
the meta IS the cell. The id-map is an indirection layer that exists
because `expr-meta` was designed before cells existed.

**Finding 2: Defensive zonk on ground expressions is pure waste (778ns).**

`zonk` on a ground `Pi(Int, Bool)` costs 778ns — walking the entire tree,
checking each node for metas, finding none. With ~225 elaboration-time
zonk calls, many on ground expressions, this waste is substantial.

**Design adjustment**: Phase 2 should classify zonk calls as "necessary"
(expression contains metas) vs "defensive" (zonk just in case). Defensive
calls should be removed outright, not replaced with cell reads.

**Finding 3: zonk-at-depth anomaly (283μs vs 778ns).**

`zonk-at-depth` (depth=3) on `Pi^10` costs 283μs — 360× more than
`zonk` on `Pi(Int, Bool)`. This is primarily expression size (10 levels
of nesting), but the depth-tracking overhead may contribute. The
benchmark ran after 5000 solve-meta! calls, so CHAMP size may also
be a factor.

**Design adjustment**: Phase 3 (eliminate zonk-at-depth) is higher
leverage than initially estimated. Even moderate expressions under
binders pay significant depth-tracking overhead.

**Finding 4: bvar risk CONFIRMED.**

The adversarial probe shows `solve-meta!` writes `(expr-bvar 0)` directly
to the cell. This is NOT a hypothetical — it happens today. Any design
that assumes cell values are closed is wrong.

**Design adjustment**: Phase 0 is now "bvar closure invariant" — a
correctness prerequisite that must come BEFORE any zonk elimination.
Add an assertion in `solve-meta!` that verifies solutions are closed
(debug mode). Add a closing step for paths that produce bvar solutions.

**Finding 5: `meta-solution` already reads from cells.**

The D.1 audit found that `meta-solution` (line 1958) already does
cell-primary reading with CHAMP fallback. Phase 0 as originally
designed ("cell-primary meta-solution") is the current architecture.

**Design adjustment**: Remove original Phase 0. The real Phase 0 is
bvar closure (Finding 4). The real Phase 1 is embed cell-id in
expr-meta (Finding 1). The original Phase 0 is already done.

### 2.8 Revised Performance Targets (Post-Benchmark)

| Operation | Current (measured) | Target | Improvement |
|-----------|-------------------|--------|-------------|
| `meta-solution` | 150ns (82ns id-map + 52ns cell + 16ns overhead) | 56ns (4ns struct + 52ns cell) | 2.7× |
| `fresh-meta` | 2,087ns (cell + CHAMP + id-map) | ~1,500ns (cell + CHAMP metadata-only) | 1.4× |
| `solve-meta!` (without resolution) | 1,756ns (cell + CHAMP + id-map) | ~800ns (cell-only + metadata update) | 2.2× |
| `solve-meta!` (with resolution) | 15,600ns (cascading resolution) | Same (resolution cost dominates) | ~1× |
| `zonk` on ground Pi(Int,Bool) | 778ns | 0ns (call eliminated) | ∞ |
| `zonk-at-depth` on Pi^10 | 283,000ns | 0ns (call eliminated) | ∞ |
| Suite wall time | ~244s baseline | ≤ 235s | ~4% improvement |

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

### Phase 0: bvar Closure Invariant (Correctness Prerequisite)

**The benchmark confirmed**: `solve-meta!` writes `(expr-bvar 0)` directly
to cells today. This is a latent correctness bug — any reader at a
different binder depth gets the wrong value. This MUST be fixed before
any zonk elimination, because zonk-at-depth is the only thing currently
compensating for bvar-in-cell values.

**Strategy**: Add an assertion + closing step in `solve-meta!`.

```racket
(define (solve-meta-core! id solution)
  ;; Ensure solution is closed (no bvars) before cell write
  (define closed-solution (close-expr solution))
  (when (current-sre-debug?)
    (assert (bvar-free? closed-solution)
            "solve-meta!: solution must be closed"))
  ;; ... existing solve logic with closed-solution ...
  )
```

**`close-expr` specification** (D.3 refinement): `close-expr` walks the
expression and for each `expr-bvar` encountered, creates a fresh fvar
and records the substitution. This is identical to what `open-expr`
already does in elaborator-network.rkt — we reuse the same bvar→fvar
replacement pattern. `close-expr` = `open-expr` applied to the solution.

In practice, PUnify already opens binders with fvars before solving
(decompose-pi calls `open-expr`). The closing step is a SAFETY NET for
non-PUnify solve paths (flex-rigid in unify.rkt, direct solutions in
trait resolution).

**Frequency measurement** (D.3 addition): Add a counter to measure how
many solutions actually contain bvars. If PUnify always opens first, the
count may be 0 — making `close-expr` a dead path. This data informs
whether Phase 0 is a correctness fix (bvar solutions exist) or a
preventive assertion (they don't, but could if a future solve path is
added without proper opening).

**Deliverables**:
1. Audit ALL `solve-meta!` call paths for bvar-containing solutions
2. Add `bvar-free?` check function
3. Add `close-expr` function (reuse `open-expr` bvar→fvar pattern)
4. Debug-mode assertion in `solve-meta-core!`
5. Add `current-bvar-solution-count` counter to measure frequency
6. Add closing step for any solve path that produces unclosed solutions
7. Targeted tests: solve under binders, verify cell contains fvars not bvars
8. Full test suite passes

### Phase 1: Embed cell-id in expr-meta (Skip id-map Lookup)

**The benchmark revealed**: id-map CHAMP lookup is 82ns — 55% of
meta-solution's total 150ns cost. The id-map exists because `expr-meta`
was designed before cells existed. The meta IS the cell; the id-map is
an unnecessary indirection.

**Strategy**: Add `cell-id` field to `expr-meta` struct with custom
equality that ignores `cell-id`.

```racket
;; Before:
(struct expr-meta (id) ...)  ;; id → id-map → cell-id → cell read

;; After:
(struct expr-meta (id cell-id)
  #:methods gen:equal+hash
  [(define (equal-proc a b _) (= (expr-meta-id a) (expr-meta-id b)))
   (define (hash-proc a _) (expr-meta-id a))
   (define (hash2-proc a _) (expr-meta-id a))])
```

**Critical D.3 refinement**: `cell-id` is METADATA, not IDENTITY. Two
`expr-meta` nodes with the same `id` but different `cell-id` values
(e.g., one from module-loading with #f, one from elaboration with a cell)
must compare as `equal?`. Without custom equality, code that uses
`expr-meta` as hash keys or in `equal?` comparisons (pattern matcher,
occurs check, expression comparison) would break. The custom `equal?`
compares only `id`; `hash` uses only `id`. Cell-id is carried for fast
lookup but invisible to identity operations.

**This touches syntax.rkt** — the central AST struct definition file. All
14 pipeline files that pattern-match on `expr-meta` need updating. This
is high-blast-radius but the right change: the meta carries its own cell
identity, eliminating the indirection.

`fresh-meta` sets `cell-id` at creation time (when the cell is allocated).
`meta-solution` reads it directly:

```racket
(define (meta-solution meta-expr)
  ;; cell-id is RIGHT THERE in the struct — no id-map lookup
  (define cell-id (expr-meta-cell-id meta-expr))
  (cond
    [(and cell-id (current-prop-net-box))
     (define net (unbox (current-prop-net-box)))
     (define val (net-cell-read (elab-network-prop-net net) cell-id))
     (and (not (type-bot? val)) val)]
    ;; Fallback: id-map path (module-loading, tests without cells)
    [else (meta-solution-by-id (expr-meta-id meta-expr))]))
```

**Module-loading context** (D.3 confirmation): During module loading,
`(current-prop-net-box)` = #f, so all metas get cell-id=#f. This is
CORRECT — module metas are solved via the CHAMP path, and their solutions
are ground before they're imported by other contexts. The cell-id=#f
fallback to id-map handles this cleanly. No retroactive cell-id setting
needed — module metas are fully solved in their own context.

**Deliverables**:
1. Add `cell-id` field to `expr-meta` in syntax.rkt (default `#f`)
2. Add custom `gen:equal+hash` that compares/hashes only `id`
3. Update `fresh-meta` to set `cell-id` at creation time
4. Update `meta-solution` to read `cell-id` directly, fallback to id-map
5. Update all 14 pipeline files for the new struct field
6. `raco make driver.rkt` to recompile ALL dependents
7. Test: verify `(equal? (expr-meta 5 100) (expr-meta 5 #f))` → #t
8. Full test suite passes
9. Micro-benchmark: meta-solution cost before vs after (target: 56ns)

### Phase 2: Eliminate Elaboration-Time zonk

With cell-primary `meta-solution` and cell-id in expr-meta, `zonk`
already reads from cells. But `zonk` is still called explicitly at ~225+
sites during elaboration. Many of these calls are unnecessary.

**Strategy**: Classify and remove in 4 priority tiers (D.3 refinement):

| Tier | Sites | Frequency | Description |
|------|-------|-----------|-------------|
| 1 (hot-loop) | ~10 | Highest | `unify-core` — zonk before comparing types. Called recursively. |
| 2 (resolution) | ~10 | Medium | `resolve-trait-constraints!` — zonk before key extraction. Stratified loop. |
| 3 (elaboration) | ~100 | One-shot | `elaborate-*` functions — zonk after elaborating sub-expression. |
| 4 (error-only) | ~50+ | Cold | `format-type-error` etc. — zonk for display only. |

Tackle in tier order: Tier 1 delivers the most performance improvement
per site removed. Tier 4 can retain `zonk` calls (cold path, correctness
matters more than speed for error messages).

**Deliverables**:
1. Classify all ~225 zonk sites into 4 tiers
2. Tier 1: remove/replace hot-loop zonk in unify-core (~10 sites)
3. Tier 2: remove/replace resolution zonk (~10 sites)
4. Tier 3: remove/replace elaboration zonk (~100 sites)
5. Tier 4: audit error-path zonk — retain where zonk provides better
   error messages, remove where unnecessary
6. Full test suite after each tier.

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

### Phase 3: Eliminate zonk-at-depth

The hardest phase. `zonk-at-depth` handles bvar shifting when solutions
are read under binders. **Depends on Phase 0** (bvar closure invariant).

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

### Phase 4: Freeze at Command Boundaries

Replace `zonk-final` with `freeze`: a single-pass walk that reads cell
values for each `expr-meta`, producing a ground expression for storage
in the global environment.

**Expressions are trees, not graphs** (D.3 clarification): The occurs
check in unification prevents cyclic solutions. `freeze` walks a tree,
not a graph — no visited-set needed. However, solution chains (meta→meta→
...→ground) are bounded by elaboration depth. Add a depth-bound assertion
in debug mode (depth > 100 → error) as a safety net against pathological
chains.

**Deliverables**:
1. `freeze` function (~200 lines): walks expression tree, replaces
   `expr-meta id` with cell value via `cell-id`. No recursion on
   solutions (cell values are already ground from propagation). No
   depth tracking (expressions at boundaries are already closed).
2. Debug-mode depth-bound assertion (max 100 chain hops)
3. Replace all ~21 `zonk-final` calls with `freeze` calls.
4. Delete `zonk-final` and `default-metas`.
5. Full test suite passes.

### Phase 5: Defaults at Solve-Time

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

### Phase 6: Unify ground-expr?

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

### Phase 7: CHAMP Fallback Removal

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

### Phase 8: Verification + Benchmarks + PIR

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

| Metric | Baseline (measured Pre-0) | Target | Rationale |
|--------|--------------------------|--------|-----------|
| Suite wall time | ~244s | ≤ 235s (~4% improvement) | Eliminated ~650 zonk calls + faster meta-solution |
| `meta-solution` | 150ns (82ns id-map + 52ns cell + 16ns) | 56ns (4ns struct + 52ns cell) | 2.7× — cell-id in expr-meta skips id-map |
| `fresh-meta` | 2,087ns | ~1,500ns | Cell + metadata-only CHAMP (no solution field) |
| `solve-meta!` (no resolution) | 1,756ns | ~800ns | Cell-only + metadata update |
| `zonk` on ground expr | 778ns | 0ns (call eliminated) | Defensive calls removed entirely |
| `zonk-at-depth` | 283μs (10-level Pi) | 0ns (eliminated) | bvar closure makes depth tracking unnecessary |
| zonk calls during elaboration | ~225+ per command | 0 | Cell reads replace solution chasing |
| zonk.rkt lines | 1317 | ~200 (freeze.rkt) | ~1100 lines eliminated |
| ground-expr? definitions | 2 (incompatible) | 1 (cell-level) | Unified |
| default-metas | 393 lines | 0 (defaults at solve-time) | ~20-line apply-defaults! |
| Memory | Baseline | Slight reduction | CHAMP entries shrink, id-map eventually eliminated |

---

## 6. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| bvar-containing solutions in cells | **CRITICAL** | **Phase 0** (new): assertion + closing step in solve-meta!. Pre-0 benchmark CONFIRMED this is real — not hypothetical. |
| expr-meta struct change (14 pipeline files) | **HIGH** | Phase 1: `raco make driver.rkt` recompiles all. Grep for all pattern matches on expr-meta. Same pattern as Track 0 struct changes. |
| Module-loading context (no cells → cell-id is #f) | HIGH | cell-id defaults to #f. meta-solution falls back to id-map when cell-id is #f. Phase 7 addresses after cells available everywhere. |
| Ordering: solve-meta! + immediate cell read | MEDIUM | Verified: elab-cell-write is synchronous. Cell value available immediately. |
| zonk removal breaks subtle ordering | MEDIUM | Phase 2: incremental removal with full suite after each batch. Classify necessary vs defensive first. |
| ~225 zonk call sites to review | MEDIUM | Phase 2: remove defensive calls in bulk. Necessary calls retain as cell-read equivalents. |
| with-fresh-meta-env (306 call sites) | MEDIUM | Phase 7 scope. Most are tests — change once, verify all. |
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
