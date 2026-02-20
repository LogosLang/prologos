# Persistent Benchmarking Infrastructure — Design Document

**Created**: 2026-02-19
**Status**: ✅ Complete
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

### 2026-02-19: Initial Implementation

**Created**: `tools/benchmark-tests.rkt` (~230 lines)

**Features implemented**:
- Per-file benchmarking via `subprocess` with `current-inexact-milliseconds` timing
- Configurable per-test timeout (default 600s, `--timeout` flag)
- JSONL recording to `data/benchmarks/timings.jsonl` (append-only)
- `--report`: Print summary of last benchmark run (slowest N)
- `--compare REF`: Compare last run vs a previous commit (delta %, regression/improvement flags)
- `--slowest N`: Print top N slowest tests from last run
- `--files FILE`: Benchmark specific files (multiple allowed)
- Captures git commit, branch, machine info, timestamp per run

**Technical notes**:
- Uses polling loop with `subprocess-status` for timeout (not `subprocess-status-evt` which is unavailable in `racket/base`)
- Uses `racket/date` for ISO timestamp formatting
- Custom `pad-str` helper for column-aligned output (avoids `~a` naming conflict)
- Test count extracted from `raco test` stdout via regex `([0-9]+) tests? passed`

**Verification**:
- `--files test-pipe-compose.rkt`: 45 tests, 3.5s, valid JSONL output ✅
- `--report`: Reads and summarizes last run ✅
- `--files` with multiple files: Correct per-file + total timing ✅
- JSONL format: Valid JSON objects, append-only, self-describing ✅

### 2026-02-19: Parallel Execution + Auto-Regression + Trend Reporting

**Architecture change**: Thread pool with async channels for parallel subprocess execution.

```
Main thread ──→ [async-channel] ──→ N worker threads ──→ subprocesses
                                                              ↓
Main thread ←── [async-channel] ←── per-file timing results
```

**Key primitives** (all in `racket/base` or standard libs):
- `racket/async-channel`: Unbounded buffered channels for work queue / result collection
- `sync/timeout`: Event-based subprocess wait (replaces 0.5s polling loop)
- `current-inexact-monotonic-milliseconds`: Clock-drift-immune timing
- `racket/future` → `processor-count`: Auto-detect available cores

**New features**:
- **`--jobs N`**: Parallel worker count (default: `(processor-count)` = 10 on dev machine)
- **Auto-regression detection**: After every run, compares against previous run in JSONL. Flags regressions >threshold%. Exit code 1 if regressions found.
- **`--regression-threshold N`**: Percentage threshold for flagging (default: 10)
- **`--trend FILE`**: Shows timing history for one test file over last N runs
- **`--depth N`**: Number of runs for `--trend` (default: 10)
- **JSONL `jobs` field**: Records parallelism level per run for fair cross-run comparisons

**Verification**:
- 6 files parallel (`--jobs 10`): 14.6s wall (sequential sum: 39.5s) → **2.7x speedup** ✅
- Sequential (`--jobs 1`): 5.9s = sum of individual times (correct) ✅
- Two stable runs: no false regressions detected ✅
- `--report`: Shows jobs count correctly ✅
- `--trend test-quote.rkt`: Shows history with timestamps ✅
- Timeout (`--timeout 2 --files test-pipe-compose-e2e.rkt`): Clean 2.0s timeout ✅
- JSONL schema: `jobs` field present, backward-compatible ✅

**Why `async-channel` not `channel`**: Synchronous `channel-put` blocks if no reader is ready. With M tasks and N workers (M > N), the main thread would deadlock after enqueueing N items. `async-channel` has an unbounded buffer — main thread enqueues all items immediately.

**Why `sync/timeout` not polling**: Eliminates 0.5s polling granularity and wasted CPU. `sync/timeout secs proc` blocks efficiently until process exits or timeout elapses.

**Timing accuracy in parallel mode**: Per-file wall-clock times are captured independently per worker thread using `current-inexact-monotonic-milliseconds`. On multi-core machines, each subprocess gets its own core(s). Timing variance is comparable to sequential mode because we measure wallclock per-subprocess, not shared CPU time. The `jobs` field ensures fair comparisons (only compare runs with same parallelism level).

### 2026-02-19: DearPyGui Visualization Dashboard

**Created**: `tools/benchmark-dashboard.py` (~586 lines)

**Architecture**: Self-contained desktop GUI using DearPyGui (GPU-accelerated, ImGui-based). Reads `data/benchmarks/timings.jsonl` directly. No web server, no external deps beyond `pip install dearpygui`.

**Features**:
- **Tab 1 — Suite Overview**: Line + scatter plot of total wall time per run. Green dots = all pass, red = failures. Red annotations on regression runs showing worst `+N%`. "Show last N runs" slider. X-axis ticks show commit hashes.
- **Tab 2 — Per-File Trend**: Left panel with searchable file listbox (filter input), right panel with line plot of selected file's timing across runs. Orange threshold line at `mean * 1.1`. Red scatter marks on regressions.
- **Tab 3 — Latest Run Breakdown**: Horizontal bar chart sorted by duration. Color-coded: green=pass, red=fail, orange=timeout. Scales to 82+ files.
- **Reload**: Manual button + auto-reload checkbox (polls file mtime every ~1s)
- **`--generate-sample`**: Writes 20 synthetic runs for testing without real data

**CLI**:
```bash
python tools/benchmark-dashboard.py                      # open with real data
python tools/benchmark-dashboard.py --generate-sample    # synthetic data
python tools/benchmark-dashboard.py --threshold 15       # regression %
python tools/benchmark-dashboard.py --file path.jsonl    # explicit file
```

**Dependencies**: `pip install dearpygui` (only external; rest is Python stdlib)

**Verification**:
- `--generate-sample`: 20 runs × 15 files, valid JSONL ✅
- Data layer: regression detection, file trends, file list derivation all correct ✅
- GUI launch: No errors, renders 3 tabs with interactive plots ✅
- Real data: 2 benchmark runs recorded, dashboard displays both ✅
