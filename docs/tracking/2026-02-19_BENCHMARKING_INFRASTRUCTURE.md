# Persistent Benchmarking Infrastructure — Design Document

**Created**: 2026-02-19
**Status**: ⬚ Not Started
**Purpose**: Design a persistent, per-file test timing system to track performance over time and catch regressions.

---

## Motivation

The one-off benchmarks (2026-02-19) revealed:
- Single test: **14s** | 2 tests: **27s** | Full suite (81 files): **429s**
- `test-pipe-compose.rkt`: **>60 min** (severe outlier)
- No way to track whether test times are regressing over time
- No per-file timing breakdown (raco test only reports pass/fail counts)

We need automated, repeatable timing that records per-file data across commits.

---

## Architecture

### New Tool: `tools/benchmark-tests.rkt` (~200 lines)

Standalone tool (does not modify `run-affected-tests.rkt`):
1. Runs each test file **individually** via Racket `subprocess`
2. Wraps each run with `current-inexact-milliseconds` timing
3. Records per-file wall-clock time, status, test count
4. Appends results to JSONL file
5. Captures commit SHA, branch, timestamp, machine info automatically

### Data Format: JSON Lines (`.jsonl`)

One JSON object per benchmark run:

```json
{
  "timestamp": "2026-02-19T14:37:00Z",
  "commit": "6eaad3a",
  "branch": "main",
  "machine": "darwin-arm64",
  "racket": "9.0",
  "jobs": 10,
  "total_wall_ms": 429000,
  "results": [
    {"file": "test-quote.rkt", "wall_ms": 14200, "status": "pass", "tests": 42},
    {"file": "test-parser.rkt", "wall_ms": 8100, "status": "pass", "tests": 6}
  ]
}
```

**Why JSONL**: Append-only (no corruption risk), human-readable, self-describing schema, no external deps (Racket's `json` is built-in). One line per run.

### Storage

```
data/benchmarks/
  timings.jsonl     # Append-only log
  .gitkeep          # Ensure directory exists in git
```

### CLI

```bash
racket tools/benchmark-tests.rkt                        # all tests
racket tools/benchmark-tests.rkt --affected             # only affected (git diff)
racket tools/benchmark-tests.rkt --files test-quote.rkt # specific files
racket tools/benchmark-tests.rkt --report               # summarize last run
racket tools/benchmark-tests.rkt --compare HEAD~1       # compare vs previous commit
racket tools/benchmark-tests.rkt --slowest 10           # top N slowest from last run
```

---

## Design Decisions

### Why per-file subprocess (not `raco test -j N`)?

`raco test -j N` batches files across N workers — no per-file timing is available. Running each test in its own subprocess via Racket's `subprocess` gives precise per-file wall-clock times. The trade-off is slower total time (sequential, not parallel), but benchmarks are run explicitly, not on every change.

### Why JSONL over CSV?

- JSONL supports nested `results` array (all files in one record per run)
- Self-describing schema (field names inline)
- CSV would require either one file per run or flattening (losing run-level metadata)
- SQLite is overkill for ~82 records per run with infrequent writes

### Why not modify `run-affected-tests.rkt`?

Separation of concerns. The test runner's job is fast execution; benchmarking is slower (sequential) and generates data files. A `--benchmark` flag would couple two different use cases.

---

## Reporting Features

### `--report` (last run summary)

```
Last run (6eaad3a, 2026-02-19 14:37):
  Total: 429.2s (81 files, 2717 tests, all pass)

  Slowest 5:
    test-stdlib.rkt         45.2s (189 tests)
    test-lang.rkt           38.1s (243 tests)
    test-trait-impl.rkt     31.4s (67 tests)
    test-quote.rkt          14.2s (42 tests)
    test-introspection.rkt  12.8s (34 tests)
```

### `--compare` (cross-commit delta)

```
Comparing 6eaad3a vs d2ea461:
  test-stdlib.rkt:  45.2s -> 52.3s (+16%) REGRESSION
  test-quote.rkt:   14.2s -> 14.5s (+2%)
  test-parser.rkt:   8.1s ->  8.0s (-1%)
```

Flag regressions >10% as warnings.

---

## Key Files

| Action | File | Notes |
|--------|------|-------|
| CREATE | `tools/benchmark-tests.rkt` | ~200 lines, uses `subprocess`, `json`, `racket/cmdline` |
| CREATE | `data/benchmarks/.gitkeep` | Ensure directory tracked |
| UPDATE | `docs/tracking/2026-02-19_BENCHMARKING_INFRASTRUCTURE.md` | This file — update with implementation results |

---

## Verification Plan

1. `racket tools/benchmark-tests.rkt --files tests/test-quote.rkt` produces valid JSONL line
2. `racket tools/benchmark-tests.rkt --report` reads and prints summary
3. Two successive runs show stable timings (< 10% variance)
4. `--compare` correctly identifies regressions vs stable tests

---

## Implementation Log

*(To be filled during implementation)*
