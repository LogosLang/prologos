# PM Track 10C Stage 2 Audit: Places for Per-Test Parallelism

**Date**: 2026-03-28
**Purpose**: Audit the test runner architecture for converting per-file batch workers to per-test granularity with Racket Places.

---

## 1. Current Architecture

### 1.1 Test Runner (`run-affected-tests.rkt`)

**Dispatch model**: Round-robin file distribution across N batch workers.
- Line 502-510: Files distributed to `(min (num-jobs) file-count)` batches via `modulo i jobs`
- Default jobs: `(processor-count)` = 10 on current hardware
- Each batch is a **subprocess** spawning `racket batch-worker.rkt <file1> <file2> ...`
- Communication: JSON lines on stdout (one per completed file), async-channel reader threads

**Subprocess model**: Each batch worker is a separate Racket **process** (not Place, not thread).
- Line 527-528: `(subprocess #f #f #f racket-path batch-worker-path batch)`
- Each process loads the full Racket runtime + Prologos modules
- Prelude loaded once per worker process (~11s saved vs per-file loading)

### 1.2 Batch Worker (`batch-worker.rkt`)

**Lifecycle**:
1. Load infrastructure: `macros.rkt`, `namespace.rkt`, `global-env.rkt`, `metavar-store.rkt`, `driver.rkt`
2. Load prelude via `test-support.rkt` (warms module cache)
3. Save post-prelude state: 19 macros params (snapshot vector) + 7 namespace params + global-env + persistent registry network
4. For each test file: restore state → `dynamic-require` the file → capture results → output JSON

**State management per file** (lines 186-216):
- `restore-macros-registry-snapshot!` — restores 19 macros parameters from saved vector
- `parameterize` with 16 parameters for namespace, global-env, meta-store
- Fresh `(make-hasheq)` for `current-mult-meta-store`
- Fresh box for `current-persistent-registry-net-box` (prevents cross-file leakage)

**Per-file isolation**: Good but not perfect. `dynamic-require` uses Racket's module cache — once a test file's module is loaded, it stays cached. This means the FIRST worker to load `test-foo.rkt` runs its body; subsequent requires (if the same file were in another batch) would get the cached instance.

### 1.3 Tail Problem

**Observed**: 380 files, 10 workers. Round-robin distribution means each worker gets ~38 files. But file execution times vary 100x (0.2s to 21.9s). The slowest worker determines wall time.

**Slowest files** (from `benchmark-tests.rkt --slowest 15`):

| File | Wall Time | Tests | Time/Test |
|------|-----------|-------|-----------|
| test-reducible.rkt | 21.9s | 26 | 0.84s |
| test-pipe-compose-e2e-02.rkt | 19.8s | 15 | 1.32s |
| test-functor-ws.rkt | 17.3s | 11 | 1.57s |
| test-io-csv-02.rkt | 17.2s | 8 | 2.15s |
| test-surface-integration.rkt | 14.2s | 77 | 0.18s |
| test-hashable-02.rkt | 13.2s | 7 | 1.89s |

**Key observation**: The slowest files have FEW tests (7-26) that are individually expensive (0.84-2.15s each). Per-test granularity would split these across workers, eliminating the tail.

**Theoretical improvement**: If the slowest file (21.9s, 26 tests) were split across 10 workers, each gets ~3 tests = ~2.5s instead of 21.9s. Total suite would be bounded by max(per-test time) × ceil(tests-per-worker) rather than max(per-file time).

---

## 2. What Places Would Change

### 2.1 Places vs Subprocesses

Current: Each batch worker is a separate OS process via `subprocess`. Full Racket VM startup per worker.

Places: Separate Racket VM instances within one OS process. Shared code pages but separate heaps, separate GCs.

**Advantages of Places**:
- Lower startup overhead (shared code, no exec)
- Structured communication via Place channels (typed, no JSON serialization)
- Can share read-only data via `shared-bytes` or `shared-flvectors`

**Disadvantages**:
- Cannot share mutable state (separate heaps)
- Module loading still happens per-Place (each Place loads its own modules)
- More complex error handling (Place crashes don't produce stderr easily)

### 2.2 Per-Test vs Per-File Granularity

**Current**: Dispatch unit = test file. Worker runs all tests in the file sequentially.

**Proposed**: Dispatch unit = individual test case. Workers pull test cases from a shared queue.

**Challenge**: Test cases within a file share setup state (`define-values` at module level). The shared fixture pattern loads prelude modules once and caches the environment. Individual test cases depend on this shared state.

**Options**:

| Approach | Description | Overhead | Isolation |
|----------|-------------|----------|-----------|
| A. File-level Places | Same as current but Places instead of subprocess | Low | Same as current |
| B. Work-stealing file queue | Workers pull files from shared queue (not round-robin) | Low | Same as current |
| C. Per-test dispatch | Extract individual test cases, dispatch independently | High (state setup per test) | Full |
| D. Hybrid: file split + work stealing | Split slow files into chunks, work-steal across workers | Medium | Partial |

### 2.3 State That Must Be Per-Worker

From batch-worker.rkt lines 86-103:

| State | Type | Size | Shareable? |
|-------|------|------|-----------|
| Macros registry snapshot | Vector of 19 params | ~1KB | Read-only after prelude → shareable |
| Module registry | Hash | ~5KB | Read-only after prelude → shareable |
| NS context | Symbol | Tiny | Shareable |
| Lib paths | List | Tiny | Shareable |
| Global env (prelude) | Hash | ~50KB | Read-only after prelude → shareable |
| Persistent registry network | prop-network | ~10KB | Must be fresh box per test |
| Mult-meta-store | Mutable hash | ~1KB | Must be fresh per test |
| Definition cells | Hash | ~1KB | Must be fresh per test |

**Key insight**: Most state is read-only after prelude loading. Only 3-4 parameters need fresh mutable state per test. This is favorable for Places — the read-only state can be loaded once per Place at startup.

---

## 3. Specific Call Sites and Data Flow

### 3.1 File Distribution (run-affected-tests.rkt)

**Current**: Lines 501-510. Round-robin `(modulo i jobs)`.
- **Problem**: Static allocation. No rebalancing if one batch is heavier than others.
- **Fix (Option B)**: Replace with work-stealing queue. Workers pull next file when idle.

### 3.2 Subprocess Spawn (run-affected-tests.rkt)

**Current**: Lines 524-529. `(subprocess #f #f #f racket-path batch-worker-path batch)`.
- Each subprocess loads `racket`, loads `batch-worker.rkt`, loads all infrastructure modules.
- Startup cost: ~2s per subprocess (module loading).
- With 10 workers: 10 × 2s = 20s startup (but overlapped with execution).

**With Places**: `(dynamic-place batch-worker-place-path 'main)`. Place startup is faster (no exec, shared code). But module loading still happens per-Place.

### 3.3 Result Communication

**Current**: JSON lines on subprocess stdout → async-channel → main thread.
- Lines 531-547: Reader thread parses JSON, puts on async-channel.
- Lines 553-620: Main thread collects from channel, tracks progress.

**With Places**: Place channels replace stdout/JSON. Native Racket values, no serialization overhead. `(place-channel-get ch)` / `(place-channel-put ch result)`.

### 3.4 Per-File State Restore (batch-worker.rkt)

**Current**: Lines 186-216. Restore macros snapshot + parameterize 16 params.
- Cost: ~0.1ms per file (negligible).
- **For per-test granularity**: Same cost, but multiplied by test count (~7500 instead of ~380).
  Still only ~0.75s total — acceptable.

---

## 4. The Work-Stealing Approach (Option B + D)

The simplest high-impact change: replace round-robin with work-stealing.

### 4.1 Architecture

```
Main thread:
  1. Sort files by estimated time (descending — heaviest first)
  2. Create shared work queue (async-channel)
  3. Spawn N workers (subprocess or Place)
  4. Workers pull files from queue until empty
  5. Collect results

Worker:
  1. Load prelude, save state (same as current)
  2. Loop: pull file from queue → restore state → run → report result
  3. Exit when queue empty
```

### 4.2 Why Heaviest-First

Scheduling theory (LPT — Longest Processing Time first): schedule heaviest jobs first, lightest last. This minimizes makespan by ensuring the tail contains only light jobs that finish quickly.

We have per-file timing data in `timings.jsonl` from previous runs. Sort by historical wall time, heaviest first. New files (no history) go to the front (conservative — assume heavy).

### 4.3 Expected Improvement

**Current**: 10 workers, round-robin. Slowest worker has test-reducible.rkt (21.9s) + ~30s of other files = ~52s batch. Other workers finish in ~30s. Tail waste: ~20s.

**Work-stealing**: test-reducible.rkt (21.9s) is pulled first by worker 1. While worker 1 runs it, workers 2-10 process other files. When worker 1 finishes, it pulls the next file from the queue. No idle time until the queue is nearly empty.

**For per-test splitting** (Option D): For the top 5 slowest files, split into individual test cases. Each test case is a work unit. Workers pull test cases from the queue. The 21.9s file becomes 26 × 0.84s work units — spread across workers.

### 4.4 Implementation Complexity

| Change | Lines | Risk |
|--------|-------|------|
| Work-stealing queue (Option B) | ~30 lines in run-affected-tests.rkt | Low — same subprocess model, different dispatch |
| Historical sort | ~20 lines (read timings.jsonl, sort by median) | Low |
| Places migration (Option A) | ~50 lines per worker + Place channel protocol | Medium |
| Per-test splitting (Option D) | ~100 lines (test extraction + dispatch) | High — shared fixture state |

---

## 5. Measurements Needed (Pre-0)

1. **Tail analysis**: For the last full run, what's the wall time of each batch worker? How much idle time is there in the fastest worker vs the slowest?

2. **Per-test timing**: For the top 10 slowest files, what's the wall time of each individual test case? This tells us whether splitting would help (if one test is 15s and the others are 1s, splitting helps less than if all tests are ~2s).

3. **Worker startup overhead**: Time from subprocess spawn to first test result. This is the fixed cost of each worker that work-stealing doesn't eliminate.

4. **Place startup overhead**: Same measurement but with Racket Places instead of subprocess. Compare: is Place startup meaningfully faster?

5. **Queue overhead**: How much does work-stealing add per file pull (async-channel latency)? Should be <1ms — negligible.

---

## 6. Recommendation

**Phase 1** (immediate, low risk): Work-stealing queue + historical sort. Replace round-robin dispatch with a shared async-channel work queue. Sort files by historical wall time (heaviest first). Expected improvement: ~15-20% wall time reduction by eliminating tail idle time. ~30 lines changed.

**Phase 2** (medium risk): Per-test splitting for top-10 slowest files. Requires understanding the shared fixture pattern and either (a) extracting individual test cases as work units with shared state handles, or (b) splitting slow files into multiple smaller files.

**Phase 3** (if needed): Places migration. Replace subprocess with Places for lower startup overhead and structured communication. This is a larger change with less certain benefit — measure Phase 1+2 first.

---

## 7. Files To Modify

| File | Changes |
|------|---------|
| `tools/run-affected-tests.rkt` | Work-stealing dispatch, historical sort, per-test splitting |
| `tools/batch-worker.rkt` | Per-test protocol (if Phase 2), Place protocol (if Phase 3) |
| `tools/benchmark-tests.rkt` | Historical timing data access for sort |
| `data/benchmarks/timings.jsonl` | Read by sort algorithm |
