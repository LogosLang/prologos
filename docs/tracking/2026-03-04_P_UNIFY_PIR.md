# P-Unify: Propagator-Driven Unification — Post-Implementation Review

**Date**: 2026-03-04
**Commits**: `b34e716` through `f944d2c` (7 commits)
**Test Count**: 5234 (258 files) — up from 5186 (256 files)
**New Tests**: 48 (35 in test-unify-structural.rkt, 13 in test-unify-cell-driven.rkt)

## Summary

Migrated the unification engine from a post-hoc observer pattern (where the
propagator network was checked only after unification completed) to a hybrid
cell-driven architecture where:

1. Structural decomposition remains recursive (well-tested, clear match dispatch)
2. Meta solving uses cell writes with inline contradiction detection
3. Quiescence flushes between structural sub-goals enable transitive propagation
4. The type lattice merge resolves unsolved metas through monotone join

## Phases Completed

### Phase 1a: Pure Classifier (`b34e716`)
- Extracted `classify-whnf-problem`: pure function returning tagged classifications
- Extracted `dispatch-unify-whnf`: side-effecting dispatcher
- `unify-whnf` becomes thin wrapper: classify → dispatch

### Phase 1b: Level/Mult Classifiers (`b9ceceb`)
- Extracted `classify-level-problem` and `classify-mult-problem`
- Pure meta-following (reads only), returns tagged results
- Dispatchers handle solve side effects

### Phase 2a: Cell-Driven Contradiction Checks (`caf3328`)
- `solve-flex-rigid`: after `solve-meta!`, checks `current-prop-has-contradiction?`
- `solve-flex-app`: same check + `'postponed` → `#t` upgrade when quiescence resolves
- Key improvement: catches transitive contradictions inside recursive decomposition

### Phase 2b: Cell-Write Consistency Validation (`0e19085`)
- Post-write read-back verification in `solve-meta!`
- `cell_write_mismatches` counter in provenance stats
- Full suite: zero mismatches observed

### Phase 3c: Quiescence in Structural Decomposition (`73d5fd5`)
- `maybe-flush-network!` between sub-goals in Pi, Sigma/lam, and multi-goal decomposition
- No-op when worklist is empty (common case post-solve-meta!)
- Enables transitive propagation across nested type components

### Phase 4b: Meta-Aware try-unify-pure (`f944d2c`)
- `try-unify-pure(unsolved_meta, concrete) = concrete` (was `#f`)
- Enables propagator lattice merge to resolve meta-bearing unifications
- Monotone: bot ⊔ v = v

## Phases Deferred

### Phase 4a: Remove CHAMP Fallback
- Cell-read is already primary; CHAMP fallback needed for test contexts without network
- Defer until `with-fresh-meta-env` is upgraded to always create a network

### Phase 4c: Structural Decomposition Propagators
- Lazy child cell creation during quiescence for Pi/Sigma sub-components
- High risk: novel pattern with unclear interaction with speculation/rollback
- Defer: current improvements already provide most of the benefit

### Phase 5a: Remove Dual Storage
- CHAMP meta-info still stores status/solution alongside cells
- Removing requires ensuring all read paths go through cells exclusively
- Defer: requires Phase 4a first

## Performance Assessment

**Overall**: ~3-5% overhead vs pre-P-Unify baseline, well within 15% budget.

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Total wall time | ~133s | ~132-140s | +0-5% |
| Test count | 5186 | 5234 | +48 |
| File count | 256 | 258 | +2 |
| Cell-write mismatches | N/A | 0 | — |

The overhead comes primarily from `maybe-flush-network!` calls, which are
no-ops in the common case (worklist empty after solve-meta!'s quiescence).

## Architecture After P-Unify

```
unify(ctx, t1, t2)                       [top-level, propagator-aware]
  ├─ unify-core(ctx, t1, t2)             [pre-WHNF spine shortcut]
  │    ├─ classify-whnf-problem(a, b)    [PURE: returns tagged list]
  │    └─ dispatch-unify-whnf(ctx,a,b,c) [EFFECTS: side-effecting dispatcher]
  │         ├─ solve-flex-rigid()         [cell write + contradiction check]
  │         ├─ solve-flex-app()           [pattern inversion + cell write]
  │         ├─ maybe-flush-network!()     [between sub-goals]
  │         └─ unify-core() (recursive)
  └─ post-check: contradiction? / upgrade 'postponed?
```

**Key reusable infrastructure**:
- `classify-whnf-problem` — pure, testable, reusable by future alternative engines
- `classify-level-problem`, `classify-mult-problem` — same pattern
- `maybe-flush-network!` — lightweight quiescence trigger
- `perf-inc-cell-write-mismatch!` — consistency monitoring

## Lessons Learned

1. **The hybrid approach was correct**: Full propagator-driven unification would
   require rewriting the recursive structural decomposition as a DAG of
   propagators, which is unnecessary complexity. The recursive match dispatch
   is clear, well-tested, and works.

2. **Cell-write consistency is already perfect**: Zero mismatches across 5234
   tests confirms that `solve-meta!`'s dual write (CHAMP + cell) is consistent.

3. **Quiescence is mostly free**: `maybe-flush-network!` is a no-op when the
   worklist is empty, which is the common case after `solve-meta!` already
   ran quiescence. The 3-5% overhead is from function call overhead, not
   actual propagator computation.

4. **Meta-aware lattice merge is a clean extension**: Changing `try-unify-pure`
   to return the concrete side for unsolved metas is monotone and idempotent,
   preserving the lattice invariants.
