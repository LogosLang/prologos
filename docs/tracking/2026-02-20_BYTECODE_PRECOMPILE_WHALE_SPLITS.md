# Bytecode Pre-compilation, Splitting Removal, & Whale File Splits

**Date**: 2026-02-20
**Status**: COMPLETE

## Summary

Four-part improvement to the test infrastructure:

1. **Bytecode pre-compilation** — `raco make driver.rkt` before test runs reduces per-subprocess module-load overhead from ~22s to ~1s
2. **Dynamic splitting removal** — Removed `test-splitter.rkt` and all work-item indirection from both test runners
3. **Whale file manual splits** — Split 4 large test files into 11 smaller ones for permanent parallelism
4. **Error log view** — Dashboard captures stderr from failed tests and shows collapsible error tree

## Performance

| Metric | Before | After |
|--------|--------|-------|
| Test files | 83 | 90 |
| Total tests | 2717 | 2717 |
| Wall time (10 jobs) | ~400s | ~104s |
| Preamble per subprocess | ~22s | ~1s |
| Pre-compilation step | N/A | ~0.6s (cached) / ~13s (cold) |

## File Splits

### test-lang.rkt (20 tests) → 4 files
- `test-lang-01-sexp.rkt` — 5 tests (sexp basics: hello, identity, vectors, pairs, forward refs)
- `test-lang-02-ws.rkt` — 5 tests (WS basics: hello-ws, identity-ws, vectors-ws, pairs-ws, forward refs)
- `test-lang-03-macros.rkt` — 6 tests (defn, macros, let-arrow, spec — sexp + WS)
- `test-lang-04-repl.rkt` — 4 tests (REPL eval, infer, check, implicit eval)

### test-lang-errors.rkt (17 tests) → 2 files
- `test-lang-errors-01-sexp.rkt` — 9 tests (sexp error tests)
- `test-lang-errors-02-ws.rkt` — 8 tests (WS error tests)

### test-stdlib.rkt (285 tests) → 3 files
- `test-stdlib-01-data.rkt` — 65 tests (Nat, Bool, Pair, Option, Result, Ordering, data keyword)
- `test-stdlib-02-traits.rkt` — 133 tests (Match, Eq, Ord, Elem, Recursive-defn, Native-ctor, Implicit, Structural-pm)
- `test-stdlib-03-list.rkt` — 87 tests (List operations, auto-export)

### test-list-extended.rkt (49 tests) → 2 files
- `test-list-extended-01.rkt` — 24 tests (reduce1, foldr1, init, scanl, iterate-n, span, break, intercalate)
- `test-list-extended-02.rkt` — 25 tests (dedup, prefix/suffix-of?, delete, find-index, count, sort-on)

## Files Modified/Created/Deleted

| Action | File |
|--------|------|
| MODIFY | `tools/bench-lib.rkt` — add `precompile-modules!`, capture stderr, remove splitting |
| MODIFY | `tools/run-affected-tests.rkt` — add precompile, remove split flags, simplify |
| MODIFY | `tools/benchmark-tests.rkt` — same, fix `for/hasheq` → `for/hash` bug |
| MODIFY | `tools/benchmark-dashboard.py` — error log view, update demo data |
| MODIFY | `tools/dep-graph.rkt` — update all test file references |
| MODIFY | `tests/examples/info.rkt` — update comment |
| DELETE | `tools/test-splitter.rkt` |
| DELETE | `tests/test-lang.rkt` |
| DELETE | `tests/test-lang-errors.rkt` |
| DELETE | `tests/test-stdlib.rkt` |
| DELETE | `tests/test-list-extended.rkt` |
| CREATE | 11 new split test files (see above) |

## Bug Fix

Found and fixed `for/hasheq` → `for/hash` bug in `benchmark-tests.rkt` (both `detect-regressions` and `report-compare`). `hasheq` uses `eq?` comparison but file names are strings needing `equal?`.

## Guideline

Keep test files under ~20 test-cases / ~30s wall time to maintain good parallelism with the thread pool.
