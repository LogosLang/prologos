# PM Track 9: Reduction as Propagators — Stage 1 Research Note

**Date**: 2026-03-21
**Status**: Stage 1 (research / vision capture)
**Parent**: Propagator Migration Series ([Master Roadmap](2026-03-13_PROPAGATOR_MIGRATION_MASTER.md))
**Prerequisite**: Track 8 Part C (propagator-driven constraint resolution)
**Motivated by**: Track 8 Part C design discussion — memo cache staleness under interleaved resolution
**Prior art**: Track 8 audit §5.7 ("Reduction as Propagators — deferred, research territory")

---

## 1. The Problem

Prologos's reduction engine (`reduction.rkt`, ~4000 lines) is a pure function `reduce : expr → expr`. Three memo caches accelerate it:

| Cache | Key | Value | Scope |
|-------|-----|-------|-------|
| `current-whnf-cache` | expr | expr (WHNF) | per-command |
| `current-nf-cache` | expr | expr (NF) | per-command |
| `current-nat-value-cache` | expr | nat | per-command |

These caches assume **referential transparency**: same expression → same result. But reduction is NOT referentially transparent with respect to meta solutions. The WHNF of `[idx-nth $dict xs 0]` depends on what `$dict` resolves to. Before trait resolution, `$dict` is an unsolved meta and reduction is stuck. After resolution, `$dict` is a concrete dict and reduction produces a value.

**Current safety**: The caches are per-command (fresh `make-hasheq` each command). Within a command, elaboration → type-check → resolve → zonk happen sequentially. Reduction during elaboration sees pre-resolution state; reduction during zonk sees post-resolution state. The cache is consistent within each phase because metas don't change mid-phase.

**Track 8 Part C changes this**: With propagator-driven resolution (C1-C3), resolution happens *during* S0 propagation — interleaved with type solving and reduction. A cache entry computed before a trait constraint resolved could be returned after the constraint resolved. The entry would be stale. The symptom: a stuck term where a reduced value should be, masquerading as a resolution ordering issue rather than a cache bug.

**Track 8 Part C's stopgap**: Option D — disable caching during S0 propagation, enable only during zonk (when all metas are solved and the context is final). This is correct-within-scope but not correct-by-construction.

---

## 2. The Vision: Reduction Results as Cells

Every reduction result becomes a cell in the propagator network. When a sub-expression's value changes (because a meta it depends on was solved), the cell is updated and dependent reduction cells recompute.

```
Expression: [idx-nth $dict xs 0]
               ↓
Cell: whnf([idx-nth $dict xs 0])
  depends on: cell($dict), cell(xs), cell(0)
               ↓ (when $dict solved to PVec--Indexed--dict)
Cell updates: whnf([idx-nth PVec--Indexed--dict xs 0]) → [rrb-get xs 0]
```

This is **demand-driven incremental reduction**: reduction results are computed once and automatically invalidated when their dependencies change. No memo cache needed — the propagator network IS the cache, with dependency-tracked invalidation.

---

## 3. What This Requires

### 3.1 Dependency Tracking in Reduction

Reduction must produce a dependency set alongside its result:

```
reduce : expr → (values expr (setof cell-id))
```

Every reduction case that reads a cell (meta lookup, cell-read for type information) adds that cell to the dependency set. Cases that call sub-reductions merge dependency sets.

**Scope**: ~50 reduction cases in `reduction.rkt`. Each case that encounters a meta or reads a cell adds to the dependency set. Cases that are pure (arithmetic, constructor matching) produce empty sets.

### 3.2 Reduction Cache as Cell Creation

When an expression is reduced for the first time:
1. Compute `(values result deps)` via the dependency-tracking reducer
2. Create a cell for the result
3. Create propagators watching each dependency cell
4. When any dependency changes, the propagator fires and re-reduces

Subsequent reductions of the same expression read the cell (O(1)) instead of re-reducing.

### 3.3 Incremental Re-Reduction

When a dependency cell changes, the reduction propagator fires. It re-reduces the expression in the new context. If the result is the same (eq? — Phase 3 value-only fast path), the cell doesn't change and no further propagation occurs. If the result is different, the cell updates and dependents fire.

This is the propagator network's standard no-change guard applied to reduction — only genuinely changed results propagate.

---

## 4. What This Enables

### For Track 8 Part C
Memo cache staleness is eliminated by construction. No Option D stopgap needed.

### For CIU Series
Trait-dispatched reduction (e.g., `[idx-nth $dict xs 0]` reducing to `[rrb-get xs 0]` when the dict is resolved) happens automatically through propagation. The CIU vision of "syntactic sugar generates trait constraints → resolution propagator fires → reduction updates" becomes a single propagator chain with no manual wiring.

### For LSP (Track 10)
Incremental re-elaboration becomes tractable. When the user edits a definition, only the reduction cells that depend on the changed definition's type need to recompute. The dependency graph is already in the propagator network — no need to re-elaborate the entire file.

### For BSP-LE
Solver-level reduction (evaluating `is` goals, computing guard predicates) becomes incremental. When a solver variable is bound, reduction cells that depended on that variable automatically update.

---

## 5. Scope and Risk Assessment

**Scope**: This is a significant architectural change:
- `reduction.rkt` (~4000 lines, ~50 cases) gains dependency tracking
- Every call site of `whnf`/`nf` (~30 sites across 6 files) adapts to the new return type
- Cell creation per reduction adds allocation pressure (mitigated by CHAMP Performance's owner-ID transients)
- The propagator network grows significantly — each reduced expression adds cells and propagator edges

**Risk**: Performance regression from cell creation overhead. Each first-reduction creates a cell (CHAMP insert) and 1-N propagator edges (one per dependency). For expressions reduced only once (the majority), this is pure overhead — the cache is never consulted. The benefit appears only for expressions reduced multiple times with changed dependencies.

**Mitigation**: Lazy cell creation — only create a reduction cell when the expression is reduced a second time (first reduction returns the result directly; second reduction triggers cell creation with the first result as initial value). This amortizes the cell creation cost to expressions that actually benefit from caching.

---

## 6. Relationship to Track 8

Track 8 Part C provides the foundation:
- **Layered scheduler (C0)**: Reduction propagators fire at S0, alongside type propagation
- **Propagator-driven resolution (C1-C3)**: Dict solutions trigger reduction cell updates through normal propagation
- **S2 scope reduction (C4)**: The simplified loop handles reduction cells naturally

Track 9 builds on this: where Part C makes *constraint resolution* propagator-driven, Track 9 makes *reduction* propagator-driven. Together they complete the vision: the entire type checker (inference + resolution + reduction) is a single propagator network.

---

## 7. Open Questions

1. **Granularity**: Should every sub-expression have a cell (fine-grained, maximum incrementality) or only top-level `whnf`/`nf` calls (coarse-grained, lower overhead)?
2. **Dependency set representation**: `(setof cell-id)` vs `(listof cell-id)` vs bit-vector? The set operations (union at each sub-reduction) must be cheap.
3. **Interaction with speculative reduction**: During ATMS speculation, reduction cells are branch-tagged. Do reduction dependency sets interact with TMS assumptions?
4. **Scope boundary**: Should Track 9 also cover `zonk.rkt` (which calls reduction extensively) or only `reduction.rkt`?

These are Stage 2 questions — they need investigation against the codebase once Track 8 Part C is complete and the propagator-driven constraint infrastructure is in place.
