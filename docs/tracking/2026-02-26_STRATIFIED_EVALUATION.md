# Stratified Evaluation for the Logic Engine

**Date**: 2026-02-26
**Status**: COMPLETE
**Test count**: 4319 (199 files, 2 skipped)

## Overview

Orchestration layer bridging `stratify.rkt` (SCC + stratification), `tabling.rkt`
(memoized answer tables), and `relations.rkt` (DFS solver). Ensures programs with
negation-as-failure evaluate correctly: lower strata complete before upper strata begin.

## Architecture

```
reduction.rkt (run-solve-goal / run-solve-one-goal)
    |
    | stratified-solve-goal
    v
stratified-eval.rkt (orchestration)
    |
    | 1. Extract dep-infos from relation store
    | 2. Compute strata (lazy, cached by version)
    | 3. If no negation or single stratum -> delegate directly (zero overhead)
    | 4. If multi-stratum -> evaluate bottom-up with stratum ordering
    v
 stratify.rkt    relations.rkt    tabling.rkt
 (dep-info)      (solve-goal)     (tables)
```

**Key invariant**: Programs without `not` pay zero overhead -- `stratified-solve-goal`
detects the absence of negation and delegates directly to `solve-goal`.

## Phases Completed

### Phase S1: Dependency Extraction (~40 lines)
- `relation-info->dep-info`: walks clause bodies to identify positive/negative deps
- `collect-goal-deps`: helper dispatching on goal-desc kind (app/not/guard)
- `extract-all-dep-infos`: maps over relation store

### Phase S2: Cached Stratification (~30 lines)
- `current-relation-store-version` parameter (bumped on `defr` registration in driver.rkt)
- `current-strata-cache` parameter: `(cons version strata) | #f`
- `get-or-compute-strata`: check cache version, recompute if stale

### Phase S3: Stratified Solver (~80 lines)
- `store-has-negation?`: quick scan for `not` goals (fast path gate)
- `stratified-solve-goal`: main entry point; fast path for no-negation / single-stratum
- `stratified-solve-multi`: multi-stratum bottom-up evaluation
  - Walks strata low-to-high, force-evaluating each predicate
  - DFS solver handles recursion internally; stratum ordering ensures negation soundness
  - Final goal solved after all lower strata complete

### Phase S4: Wiring (~10 lines)
- `reduction.rkt`: replaced `solve-goal` -> `stratified-solve-goal` at two call sites
- `driver.rkt`: added `bump-relation-store-version!` after `defr` registration

### Phase S5: Variable-Carrying Negation Fix (~60 lines)
- `rename-ast-vars`: deep-walks AST exprs (expr-goal-app, expr-unify-goal, etc.) to rename logic variables
- `collect-ast-vars`: deep-walks AST exprs to collect variable names
- Fixed `collect-goal-vars` `(not)` case: was `(void)`, now calls `collect-ast-vars`
- Fixed `rename-goal-vars` `(not)` case: was pass-through, now calls `rename-ast-vars`
- Fixed `solve-single-goal` `(not)` case: applies substitution via `apply-subst-to-goal` before evaluation

## Bugs Found and Fixed

### Semi-Naive Iteration Non-Convergence
The original `stratified-solve-multi` used a semi-naive iteration loop that repeatedly
called `solve-goal` until no new answers appeared. This failed because:
1. Each `solve-goal` call produces answers with fresh variable names
2. `table-lookup` uses structural equality, so fresh vars never match
3. The loop never converges -> "Fixed point not reached after 100 iterations"

**Fix**: Removed the semi-naive iteration. The DFS solver already handles recursion
internally through backtracking and depth-limiting. The stratum ordering only needs to
ensure negation targets are fully evaluated before upper strata consult them -- a single
pass per stratum suffices.

### `for/fold` + `when` Dropping Accumulator
Early version used `(when ri ...)` inside `for/fold`, which returns `void` when the
condition is false, dropping the fold accumulator. Fixed with `(if (not ri) ts-acc ...)`.

### `for/hasheq` Syntax
Initial test code used `for/hash` which doesn't exist; Racket requires `for/hasheq`.

### Ground Constants as Logic Variables
The DFS solver treats ALL symbols as logic variables. Unit tests using symbol constants
like `'alice` were unified instead of compared. Fixed by using strings for ground data
in unit tests (the E2E pipeline uses `expr-string` AST structs which avoid this).

## Files Changed

| File | Change |
|------|--------|
| `stratified-eval.rkt` | NEW (~200 lines) -- orchestration module |
| `relations.rkt` | +60 lines -- variable-carrying negation fix |
| `reduction.rkt` | +2 lines -- import + call site swap |
| `driver.rkt` | +2 lines -- import + version bump |
| `tests/test-stratified-eval.rkt` | NEW (~200 lines) -- 17 tests |

## Test Coverage

- **Unit tests** (13): dep extraction, cached stratification, negation helpers
- **E2E tests** (4): facts-only, recursive ancestor, negation-as-failure, version bumping
- **Pre-existing**: `test-relational-e2e.rkt` negation tests now pass through stratified path

## Future Work

- Lattice aggregation between strata (count, min, max, sum)
- Tabled semi-naive iteration with answer normalization (for mutual recursion within strata)
- Stratified explain (currently delegates to `explain-goal` directly)
