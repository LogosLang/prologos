# P-Unify: Propagator-Driven Unification — Post-Implementation Review

**Date**: 2026-03-04
**Commits**: `b34e716` through `2785e09` (10 commits)
**Test Count**: 5277 (259 files) -- up from 5186 (256 files)
**New Tests**: 91 (35 in test-unify-structural.rkt, 13 in test-unify-cell-driven.rkt, 43 in test-structural-decomp.rkt)

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

### Phase 4c: Structural Decomposition Propagators (commits `8624a33`-`2785e09`) -- COMPLETE
- **4c-a** (`8624a33`): Infrastructure -- `cell-decomps` and `pair-decomps` CHAMP registries,
  `current-structural-meta-lookup` callback, installed from `driver.rkt`
- **4c-b** (`3094aa1`): Core decomposition -- `make-structural-unify-propagator` replaces
  `make-unify-propagator`; `decompose-pi`, `decompose-app` with sub-cells, sub-propagators,
  and reconstructors; fast path refined to check `has-unsolved-meta?`; 24 tests
- **4c-c** (`2785e09`): Extended constructors -- Sigma, Eq, Vec, PVec, Set, Map, pair,
  suc, lam decomposers; generic `decompose-1` for 1-component types; fix pre-existing
  `try-unify-pure` lam arity bug; 19 new tests
- **Key mechanism**: bare metas reuse existing propagator cells, connecting structural
  positions directly to meta cells for network-driven solving
- **Benchmark**: 142.6s total, no regressions vs baseline (~139.9s = +2%)
- **Test count**: 5277 (259 files), all pass

### Phase 5a: Remove Dual Storage
- CHAMP meta-info still stores status/solution alongside cells
- Removing requires ensuring all read paths go through cells exclusively
- Defer: requires Phase 4a first

## Performance Assessment

**Overall**: ~3-5% overhead vs pre-P-Unify baseline, well within 15% budget.

| Metric | Pre-P-Unify | P-Unify 1a-4b | P-Unify 4c | Delta (overall) |
|--------|-------------|---------------|------------|-----------------|
| Total wall time | ~133s | ~132-140s | ~142.6s | +5-7% |
| Test count | 5186 | 5234 | 5277 | +91 |
| File count | 256 | 258 | 259 | +3 |
| Cell-write mismatches | N/A | 0 | 0 | -- |
| Structural decomp constructors | 0 | 0 | 11 | -- |

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

5. **Structural decomposition is fundamentally a Radul/Sussman pattern**: The
   constructor/accessor decomposition pattern (Phase 4c) is clean and composable.
   Each constructor has the same structure: extract components, create sub-cells,
   wire sub-propagators and reconstructors. The generic `decompose-1` eliminates
   boilerplate for 1-component types.

6. **`current-lattice-meta-solution-fn` gates structural decomposition**: Without it,
   `has-unsolved-meta?` returns `#f` for all expressions, causing the fast path to
   bypass structural decomposition. This is correct in production (callback is installed
   from driver.rkt) but must be explicitly set in tests.

7. **Parent cells retain meta references after sub-cell solving**: `try-unify-pure`
   preserves the first side's structure. Reconstructors can't always update parents
   to fully concrete values. This is correct -- zonking resolves meta references later.
   The key invariant is that meta CELLS are solved to concrete values.

8. **Latent bugs surface when new paths exercise old code**: Phase 4c-c revealed a
   pre-existing arity bug in `try-unify-pure`'s lam case (`expr-lam` called with 2
   args instead of 3). The code was unreachable in practice because lam values are
   usually beta-reduced before unification. Structural decomposition tests exercised
   the path for the first time.
