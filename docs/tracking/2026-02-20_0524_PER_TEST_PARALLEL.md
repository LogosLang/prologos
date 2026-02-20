# Per-Test Parallel Execution for CPU Saturation

**Date**: 2026-02-20
**Status**: Complete

## Problem

With 10 workers and 83 test files, once the 80 fast files finish (~25s), 7 workers sit idle while 3 "whale" files grind sequentially:
- `test-lang.rkt`: 20 tests, ~313s
- `test-lang-errors.rkt`: 17 tests, ~269s
- `test-stdlib.rkt`: 285 tests, ~132s

## Approach

Dynamic test splitting: read s-expressions from whale files, separate preamble from `(test-case ...)` forms, generate temp files (one per test-case) in the same directory so `define-runtime-path` resolves correctly.

## Key Design Decision: Dual-Threshold Splitting

Splitting has ~22s preamble overhead per subprocess. Only files where per-test time >> overhead benefit:
- `test-lang.rkt` (15.7s/test) → SPLIT ✅
- `test-lang-errors.rkt` (15.8s/test) → SPLIT ✅
- `test-stdlib.rkt` (0.45s/test) → NOT SPLIT (overhead would be 50x the test)
- `test-list-extended.rkt` (1.4s/test) → NOT SPLIT (overhead would be 16x the test)

Two thresholds: `split-threshold-ms` (60s file total) and `split-min-per-test-ms` (10s per test).

## Files

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `tools/test-splitter.rkt` | S-expression extraction, temp file generation, cleanup |
| MODIFY | `tools/bench-lib.rkt` | work-item struct, prepare-work-items, aggregate-split-results |
| MODIFY | `tools/run-affected-tests.rkt` | Use work items in thread pool, --split-threshold flag |
| MODIFY | `tools/benchmark-tests.rkt` | Same work-item integration |

## Results

- 83 files → 118 work items (37 split from 2 whale files)
- All 2717 tests pass
- `test-lang.rkt`: 313s → ~49s peak (6.4x speedup per file)
- `test-lang-errors.rkt`: 269s → ~30s peak (9x speedup per file)
- Per-test benchmark data stored in `test_details` JSONL field for future analysis
- `--split-threshold 0` disables splitting entirely

## Done

- [x] test-splitter.rkt
- [x] bench-lib.rkt modifications
- [x] run-affected-tests.rkt integration
- [x] benchmark-tests.rkt integration
- [x] End-to-end verification (2717 tests, all pass)
