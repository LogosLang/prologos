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

## Post-Activation Fixes (Demo File Hardening)

### Parser: Arity-Based Fact Row Splitting
- **Problem**: `|| "1" "2" "3"` on one line in a 1-arity relation created ONE row of 3 values instead of THREE rows of 1 value. Multi-column relations with multi-value continuation lines had the same issue.
- **Root cause**: `parse-defr-body` put all flat terms (same-line) and all continuation terms (indented lines) into single rows without considering the relation's arity.
- **Fix**: Added `#:arity` parameter to `parse-defr-body`. Flat terms and continuation rows are now chunked into groups of `arity` values. All 3 call sites (single-arity, multi-arity, anonymous rel) pass the param count.

### Elaborator: Relational Fallback Priority over Global Env
- **Problem**: `(solve (course-data code title "CS"))` with the full prelude returned nil because `code` resolved to the prelude's `char->integer` function (from `prologos::data::char`) instead of becoming a free query variable.
- **Root cause**: In `elaborate-var`, the relational fallback (step 9) ran AFTER global env lookup (step 6). When `current-relational-fallback?` was true, names found in the global env were resolved as functions/constants instead of logic variables.
- **Fix**: Moved relational fallback check to run immediately after the relational env check — BEFORE global env resolution. In relational context `(...)`, bare symbols are logic variables by default. To reference a global value, use `[...]` (functional expression) or `is`.
- **Design principle**: This aligns with Prologos's delimiter convention: `[...]` computes values (functional), `(...)` constrains search spaces (relational).

### Demo Files Updated
- `examples/relational-demo.prologos`: Updated STATUS, uncommented `ancestor` defr (recursive rules), uncommented `needs` defr (transitive prereqs), added 10 executable `eval (solve ...)` calls with live output
- `examples/sudoku-solver-demo.prologos`: Updated STATUS, added `eval (solve (digit d))` and `eval (solve (digit4 d))` queries

## Test Results

- 4171 tests across 190 files, all pass
- 15 new e2e tests + 7 new parser tests + updates to existing tests
- No whale files (slowest: ~21s)

## Files Modified

| File | Changes |
|------|---------|
| parser.rkt | +80: relational goal context, keyword handlers, arity-based fact splitting |
| macros.rkt | +3: surf-defr passthrough in expand-top-level |
| elaborator.rkt | +50: relational env, fallback priority, surf-not handler |
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
| examples/relational-demo.prologos | Updated: live solve queries, uncommented working relations |
| examples/sudoku-solver-demo.prologos | Updated: live solve queries for digit/digit4 |
