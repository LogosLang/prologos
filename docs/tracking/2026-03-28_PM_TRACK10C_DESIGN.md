# PM Track 10C: Work-Stealing Test Parallelism

**Date**: 2026-03-28
**Series**: PM (Propagator Migration)
**Stage**: 3 (Design Iteration D.1)
**Prerequisites**: [Stage 2 Audit](2026-03-28_PM_TRACK10C_STAGE2_AUDIT.md)

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Pre-0 benchmarks: tail analysis + per-test timing | ⬜ | Design input — feeds D.2 |
| 1 | Work-stealing queue + historical sort | ⬜ | ~30 lines |
| 2 | Per-test splitting for slow files | ⬜ | Scope depends on Phase 0 data |
| 3 | A/B benchmark: work-stealing vs round-robin | ⬜ | |
| 4 | PIR + tracker + dailies | ⬜ | |

**Phase completion protocol**: After each phase: commit → update tracker → update dailies → proceed.

---

## §1 Goal

Reduce full test suite wall time by eliminating tail idle time. Current: ~150s with 10 workers. The slowest batch worker determines wall time while other workers sit idle for the last ~20s.

### Deliverables

1. **Work-stealing dispatch**: Workers pull files from a shared queue instead of round-robin assignment
2. **Historical sort**: Files sorted by previous run time (heaviest first) for optimal scheduling
3. **Measurable wall time improvement**: Target ~15-20% reduction (~120-128s)
4. **Zero behavior change**: Same test results, same failure logs, same timing recording

### Non-Deliverables (deferred)

- Places migration (Phase 3 in audit — measure first)
- Per-test splitting (Phase 2 — depends on Phase 0 data showing it's needed)
- Test suite restructuring (splitting large test files — manual work, different track)

---

## §2 Stage 2 Audit Summary

Source: [PM Track 10C Stage 2 Audit](2026-03-28_PM_TRACK10C_STAGE2_AUDIT.md)

### Current Architecture

- **10 subprocess batch workers**, each a full Racket process
- **Round-robin dispatch**: files assigned `(modulo i 10)` — static, no rebalancing
- **Prelude loaded once per worker**: ~11s startup cost amortized across ~38 files per worker
- **JSON stdout communication**: one line per completed file

### The Tail Problem

| Worker | Files | Total Time | Idle After |
|--------|-------|------------|------------|
| Slowest | ~38 (includes test-reducible 21.9s) | ~52s | — |
| Fastest | ~38 (all light files) | ~30s | 22s idle |

The last ~30% of wall time has declining CPU utilization as workers finish at different times.

### Top 6 Slowest Files

| File | Wall Time | Tests |
|------|-----------|-------|
| test-reducible.rkt | 21.9s | 26 |
| test-pipe-compose-e2e-02.rkt | 19.8s | 15 |
| test-functor-ws.rkt | 17.3s | 11 |
| test-io-csv-02.rkt | 17.2s | 8 |
| test-surface-integration.rkt | 14.2s | 77 |
| test-hashable-02.rkt | 13.2s | 7 |

Combined: ~104s of work across 6 files. Under round-robin, 2-3 of these can land in the same batch, creating a ~40s batch while others finish in ~25s.

---

## §3 Architecture: Work-Stealing with Historical Sort

### Current (Round-Robin)

```
Files: [A B C D E F G H I J K L ...]
       ↓ modulo 3
Worker 1: [A D G J ...]
Worker 2: [B E H K ...]
Worker 3: [C F I L ...]
→ Worker with heaviest file determines wall time
```

### Proposed (Work-Stealing)

```
Files sorted by historical time (heaviest first):
Queue: [test-reducible test-pipe-compose test-functor ... test-tiny-01 test-tiny-02]

Worker 1: pulls test-reducible (21.9s)
Worker 2: pulls test-pipe-compose (19.8s)
Worker 3: pulls test-functor (17.3s)
...
Worker 1 finishes first heavy file, pulls next from queue
→ All workers stay busy until queue is nearly empty
```

### Why Heaviest-First (LPT Scheduling)

LPT (Longest Processing Time) is the optimal greedy algorithm for minimizing makespan on parallel machines. By scheduling the heaviest jobs first:

- Heavy jobs start immediately on all workers
- As workers finish heavy jobs, they pull lighter jobs
- The tail contains only light jobs (~0.5-2s) that finish quickly
- Maximum idle time = max(single light file time) ≈ 2s

### Implementation

**Work queue**: Replace the `batches` vector (line 503) with an `async-channel`. The main thread fills it with sorted file paths. Workers pull from the channel.

**Historical sort**: Read `timings.jsonl` for the last run's per-file wall times. Sort descending. Files not in history (new files) go to the front (conservative — assume heavy).

**Worker protocol change**: Currently workers receive all their files as command-line arguments at spawn time. With work-stealing, workers receive files one at a time via stdin (or a Place channel). The worker loop: `read file path → run → write result → repeat until EOF`.

### Communication Protocol

```
Main → Worker (stdin): file path (one per line)
Worker → Main (stdout): JSON result (one per line, same as current)
Main → Worker: EOF (no more files)
Worker: exits
```

This is a minimal change to the current subprocess model. No Places needed for Phase 1.

---

## §4 Concrete Walkthrough

### Before (Round-Robin, 150s)

```
t=0:   Workers 1-10 start. Each has ~38 files assigned.
t=30:  Workers 3,5,7 finish (light batches). Workers 1,2,4 still running heavy files.
t=45:  Workers 2,4 finish. Worker 1 still on test-reducible batch.
t=52:  Worker 1 finishes. Suite complete.
       Wall time: 52s per worker × overhead = ~150s total with startup.
       Workers 3,5,7 idle for 22s. Workers 2,4 idle for 7s.
```

### After (Work-Stealing, ~128s estimated)

```
t=0:   Workers 1-10 pull heaviest 10 files from queue.
       Worker 1: test-reducible (21.9s)
       Worker 2: test-pipe-compose (19.8s)
       ...
t=14:  Worker 10 finishes (lightest of initial 10), pulls next file.
t=18:  Workers 3-9 finish their initial files, pull more.
t=22:  Worker 1 finishes test-reducible, pulls a light file (~2s).
t=24:  Worker 1 finishes light file, pulls another.
...
t=38:  All 380 files processed. Last file was ~1s.
       Wall time: max(heaviest file) + remaining/workers ≈ 22 + (128-22)/10 ≈ 33s
       With startup overhead: ~128s total.
       Maximum worker idle time: ~2s (time of last file).
```

**Estimated improvement**: ~150s → ~128s = **~15% reduction**. Better scheduling → better CPU saturation.

---

## §5 Implementation Phases

### Phase 0: Pre-0 Benchmarks — Tail Analysis

**What**: Measure the actual tail waste in the current round-robin system.

**Measurements**:
1. Per-worker wall time: how long does each of the 10 workers run?
2. Tail idle time: `max(worker time) - min(worker time)` = total tail waste
3. CPU utilization timeline: at t=X, how many workers are still active?
4. Per-test timing for top 10 slowest files: are individual tests heavy or is it file setup?
5. Worker startup overhead: time from spawn to first test result

**How**: Add per-worker timing to `run-affected-tests.rkt`. Record `(worker-id, file, start-ms, end-ms)` for each file. Post-process to compute idle time.

**Success criteria**: Quantify the tail waste. If <5% of wall time, work-stealing won't help much. If >15%, it's worth the change.

**Lines changed**: ~20 (timing instrumentation only)

**Completion**: commit → tracker → dailies → proceed.

### Phase 1: Work-Stealing Queue + Historical Sort

**What**: Replace round-robin with work-stealing dispatch.
**Where**: `run-affected-tests.rkt` (dispatch logic) + `batch-worker.rkt` (stdin protocol)

**run-affected-tests.rkt changes** (~30 lines):
- Read `timings.jsonl` for historical per-file wall times
- Sort file list by historical time (descending, unknown files first)
- Replace `batches` vector + round-robin with `async-channel` work queue
- Fill queue with sorted file paths
- Workers spawn with no initial files (empty command-line)
- Main thread feeds files via worker stdin, one at a time
- Worker signals "ready for next" by writing JSON result for current file

**batch-worker.rkt changes** (~15 lines):
- Change from command-line args to stdin loop
- Read file path from stdin → run → write JSON to stdout → repeat
- Exit on EOF

**Historical sort** (~15 lines):
- Read last entry per file from `timings.jsonl`
- Sort by `wall_ms` descending
- Unknown files: assign `+inf.0` (sort to front)

**Test**: Run full suite twice. Compare wall times. Work-stealing should be faster.

**Completion**: commit → tracker → dailies → proceed.

### Phase 2: Per-Test Splitting (conditional)

**What**: For the top N slowest files, split into individual test cases.
**Condition**: Only if Phase 0 shows that slow files have multiple heavy tests (not one heavy test + many light ones). If one test dominates (e.g., 18s out of 21.9s), splitting doesn't help — the single test is the bottleneck.

**Approach**: Use RackUnit's test log to enumerate test cases. Run individual test cases as work units with shared module state.

**Challenge**: The shared fixture pattern (`define-values` at module level) means test cases share setup. Either:
- a. Load the module once per worker, run individual tests from the loaded module (requires test-case extraction API)
- b. Split slow test files into multiple files (manual, but simple)

**Lines**: ~100 (if approach a) or ~0 code + manual file splitting (approach b)

**Completion**: commit → tracker → dailies → proceed.

### Phase 3: A/B Benchmark

**What**: Compare work-stealing vs round-robin on 5 consecutive full suite runs.
**Metrics**: Wall time, per-worker utilization, tail idle time.
**Success criteria**: ≥10% wall time improvement, zero test result changes.

**Completion**: commit → tracker → dailies → proceed.

### Phase 4: PIR + Tracker + Dailies

---

## §6 Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Worker stdin/stdout protocol change breaks result parsing | Low | Medium | Same JSON format, just different delivery mechanism |
| Historical sort data stale (file renamed/deleted) | Low | Low | Unknown files sorted to front (conservative) |
| Work-stealing overhead (channel contention) | Very Low | Low | async-channel is lock-free for single producer |
| Phase 2 per-test splitting complex | Medium | Medium | Defer to manual file splitting (approach b) if too complex |
| Improvement < 10% | Low | Low | Still correct, just not as impactful. Data informs whether Places (bigger change) is needed. |

## §7 NTT Speculative Syntax

Not applicable — this is tooling infrastructure, not language/network design.

---

## §8 Success Criteria

1. **Wall time**: ≥10% reduction on full suite (150s → ≤135s)
2. **Correctness**: 380/380 GREEN, identical test results
3. **Tail waste**: Maximum worker idle time ≤5s (down from ~20s)
4. **CPU utilization**: >90% utilization in last quartile of suite run (up from ~60%)
