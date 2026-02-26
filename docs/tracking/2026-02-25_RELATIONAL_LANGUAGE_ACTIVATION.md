# Phase 7 Activation: Relational Language End-to-End

**Date**: 2026-02-25
**Status**: COMPLETE (Sub-phases A-G)

## Summary

Made the Phase 7 relational language fully executable end-to-end. Prior to this work, the scaffolding was in place (26 AST nodes, 18 surface syntax structs, runtime modules) but no data flowed through the pipeline. Writing idiomatic `.prologos` relational code now works:

```
defr parent [?x ?y]
  || "alice" "bob"
  || "bob" "carol"
  || "carol" "dave"

defr ancestor [?x ?y]
  &> (parent x y)
  &> (parent x z) (ancestor z y)

solve (ancestor "alice" y)
;; => [{:y "bob"} {:y "carol"} {:y "dave"}]
```

## Sub-phases Completed

### A: Parser Goal Context Dispatch
- Added `current-parsing-relational-goal?` Racket parameter
- Inside `&>` clause bodies and solve/explain goals, `(name args...)` -> `surf-goal-app` (not `surf-app`)
- Special cases: `(= x y)` -> `surf-unify`, `(is var [expr])` -> `surf-is`, `(not goal)` -> `surf-not`
- Added `surf-not` struct to surface-syntax.rkt

### B: Preparse Nat Literals in defr Bodies
- Fixed `($nat-literal N)` partition in `parse-defr-body` -- term sentinels now classified as flat terms

### C: Elaborator Relational Scoping
- Added `current-relational-env` parameter for defr param bindings
- Added `current-relational-fallback?` for solve/explain query vars AND defr clause bodies
- Intermediate variables (e.g. `z` in ancestor) auto-become `expr-logic-var` via fallback

### D: Driver Relation Store + AST->Runtime Conversion
- `expand-top-level` now passes `surf-defr` through (was wrapping in `surf-eval`)
- `expr-defr->relation-info` converts zonked AST to runtime structs
- Fixed param pair handling: `(name . mode)` pairs from parser now correctly extracted

### E: Reduction Solve/Explain to Runtime
- Replaced self-value rules with actual iota rules
- `run-solve-goal`/`run-explain-goal` extract goal args, call solver, convert answers to Prologos lists

### F: Runtime Rule Execution (DFS Solver)
- Full DFS search with backtracking in `solve-goals`/`solve-single-goal`/`solve-app-goal`
- Unification: `walk`, `walk*`, `unify-terms` using symbol-based substitutions
- `normalize-term`: converts `expr-logic-var` to plain symbols at the `expr->goal-desc` boundary
- `collect-clause-vars`: ensures ALL variables (not just params) get freshened per clause invocation
- Goal kinds: app (recursive relation call), unify, is (stub), not (negation-as-failure), cut, guard
- Depth limit: 100 (configurable via solver-config)

### G: Integration Tests
- Created `test-relational-e2e.rkt` with 15 end-to-end tests
- Fixed `substitution.rkt` and `zonk.rkt` for `expr-goal-app` name field (symbol, not expression)

## Key Bugs Found & Fixed

1. **expand-top-level missing surf-defr case**: defr was wrapped in surf-eval, bypassing the driver's defr handler
2. **Param pair extraction**: params are `(name . mode)` pairs, not expr-logic-var or symbols
3. **Variable freshening incomplete**: only params were freshened per clause; intermediate vars like `z` were shared across invocations
4. **Logic var normalization**: clause goals stored `expr-logic-var` structs but solver expected plain symbols
5. **Mechanical traversal crash**: zonk/substitution recursed into `expr-goal-app` name (a symbol)

## Test Results

- 4171 tests across 190 files, all pass
- 15 new e2e tests + 7 new parser tests + updates to existing tests
- No whale files (slowest: 17.5s)

## Files Modified

| File | Changes |
|------|---------|
| parser.rkt | +60: relational goal context, keyword handlers |
| macros.rkt | +3: surf-defr passthrough in expand-top-level |
| elaborator.rkt | +50: relational env, fallback, surf-not handler |
| surface-syntax.rkt | +5: surf-not struct |
| driver.rkt | +10: relation store wiring |
| relations.rkt | +190: DFS solver, normalize-term, collect-clause-vars |
| reduction.rkt | +80: solve/explain iota rules |
| substitution.rkt | +2: expr-goal-app name fix |
| zonk.rkt | +3: expr-goal-app name fix |
| tools/dep-graph.rkt | +2: new test entry |
| tests/test-parser-relational.rkt | +30: new tests |
| tests/test-relational-types.rkt | +5: test updates |
| tests/test-relational-e2e.rkt | NEW +120: 15 e2e tests |
