# Benchmarking Framework & Performance Observatory — Design Document

**Date**: 2026-02-25
**Status**: DESIGN (pre-implementation)
**Scope**: Comprehensive benchmarking suite, regression detection, dashboard, and performance observatory for Prologos

---

## 1. Executive Summary

This document designs a **three-tier benchmarking framework** for Prologos:

1. **Micro-benchmarks** — Individual operations (unification, reduction, trait resolution) measured in isolation with statistical rigor
2. **Integration benchmarks** — Full pipeline measurements (parse → elaborate → type-check → reduce) on realistic programs
3. **Comparative benchmarks** — Side-by-side measurement of analogous systems (current type inference vs logic-engine-based type inference, DFS solver vs propagator-based solver)

The framework builds on the existing infrastructure (`bench-lib.rkt`, `benchmark-tests.rkt`, `timings.jsonl`, `benchmark-dashboard.py`) and adds:

- **Deterministic cost counters** ("heartbeats") for hardware-independent regression detection
- **Phase-level timing breakdown** (parse, elaborate, type-check, QTT, reduce, zonk)
- **Memory profiling** (peak RSS, GC count, allocation pressure)
- **Statistical rigor** (multi-run median, bootstrap CIs, effect size gating)
- **Property-based testing integration** (rackcheck for soundness + performance properties)
- **Static HTML dashboard** (Vega-Lite, CI-compatible, in addition to DearPyGui)

---

## 2. Current State Assessment

### What Exists (✅ Strong Foundation)

| Component | File | Capability |
|-----------|------|------------|
| Per-file wall-clock timing | `bench-lib.rkt` | Subprocess isolation, monotonic clock |
| Parallel benchmark execution | `benchmark-tests.rkt` | Thread pool, configurable jobs |
| JSONL recording | `data/benchmarks/timings.jsonl` | Append-only, git metadata, 91 runs |
| Regression detection | `benchmark-tests.rkt` | Configurable threshold (default 10%) |
| Interactive dashboard | `benchmark-dashboard.py` | DearPyGui, 3-tab layout, trend analysis |
| Affected test selection | `run-affected-tests.rkt` | DAG-based, git-diff driven |
| Whale file splitting | `split-whales.rkt` | Auto-split >20 tests per file |
| Reduction fuel limiting | `reduction.rkt` | 1M step limit, box parameter |
| Bytecode pre-compilation | `bench-lib.rkt` | `raco make driver.rkt` before runs |

### What's Missing (❌ Key Gaps)

| Gap | Impact | Priority |
|-----|--------|----------|
| No deterministic cost counters | Can't distinguish algorithmic regression from hardware noise | **P0** |
| No phase-level timing | Can't identify which pipeline stage regressed | **P0** |
| No memory profiling | Can't detect memory regressions or GC pressure | **P1** |
| Single-run comparison | Noisy — one slow run triggers false regression | **P1** |
| No micro-benchmark harness | Can't measure individual operations | **P1** |
| No property-based testing | Missing soundness guarantees and perf-property coverage | **P2** |
| No static HTML export | Dashboard requires DearPyGui desktop app | **P2** |
| No CI integration | No automated regression gates on PRs | **P2** |

---

## 3. Architecture: The Performance Observatory

### 3.1 Heartbeat Counters (Deterministic Cost Model)

**Inspiration**: Lean4's heartbeat system. Hardware-independent, deterministic, reproducible.

**Design**: Instrument core loops with global counters accessible via Racket parameters.

```
Module              Counter Name              Incremented On
─────────────────────────────────────────────────────────────
unify.rkt           unify-steps               Each unify() call
reduction.rkt       reduce-steps              Each whnf() step (existing fuel)
elaborator.rkt      elaborate-steps           Each elaborate() call
typing-core.rkt     infer-steps               Each infer()/check() call
trait-resolution.rkt trait-resolve-steps       Each resolve attempt
metavar-store.rkt   meta-created-count        Each fresh-meta call
metavar-store.rkt   meta-solved-count         Each solve-meta! call
metavar-store.rkt   constraint-count          Each add-constraint! call
metavar-store.rkt   constraint-retry-count    Each retry-constraints-for-meta!
relations.rkt       solver-backtrack-steps    Each choice point explored
relations.rkt       solver-unify-steps        Each DFS unification
zonk.rkt            zonk-steps                Each zonk() recursive call
```

**Implementation**: A single `performance-counters` module providing:

```racket
;; performance-counters.rkt
(provide current-perf-counters
         perf-counter-inc!
         perf-counter-snapshot
         perf-counter-reset!
         with-perf-counters)

(struct perf-counters
  (unify-steps reduce-steps elaborate-steps infer-steps
   trait-resolve-steps meta-created meta-solved
   constraint-count constraint-retries
   solver-backtracks solver-unifies zonk-steps)
  #:mutable #:transparent)

(define current-perf-counters (make-parameter #f))

(define-syntax-rule (perf-counter-inc! field)
  (let ([pc (current-perf-counters)])
    (when pc
      (set-perf-counters-field! pc (add1 (perf-counters-field pc))))))
```

**Zero-cost when disabled**: When `current-perf-counters` is `#f` (the default), the `when` check is a single pointer comparison — negligible overhead. Benchmarks explicitly opt in via `with-perf-counters`.

### 3.2 Phase-Level Timing Breakdown

**Design**: Wrap each pipeline stage in `driver.rkt` with timing instrumentation.

```racket
;; In driver.rkt, process-command:
(define-values (parsed parse-ms) (time-phase 'parse (lambda () (parse datum))))
(define-values (elaborated elab-ms) (time-phase 'elaborate (lambda () (elaborate parsed env depth))))
(define-values (typed type-ms) (time-phase 'type-check (lambda () (infer ctx elaborated))))
(define-values (trait-ok trait-ms) (time-phase 'trait-resolve (lambda () (resolve-trait-constraints!))))
(define-values (qtt-ok qtt-ms) (time-phase 'qtt-check (lambda () (checkQ ...))))
(define-values (zonked zonk-ms) (time-phase 'zonk (lambda () (zonk-final ...))))
```

**Recording**: Phase timings stored per-command, aggregated per-file in the JSONL record:

```json
{
  "file": "test-quote.rkt",
  "wall_ms": 14200,
  "phases": {
    "parse_ms": 120,
    "elaborate_ms": 3200,
    "type_check_ms": 8100,
    "trait_resolve_ms": 1800,
    "qtt_ms": 400,
    "zonk_ms": 580
  },
  "heartbeats": {
    "unify_steps": 48200,
    "reduce_steps": 12300,
    "elaborate_steps": 890,
    "meta_created": 156,
    "meta_solved": 148,
    "constraints_total": 42,
    "constraints_retried": 18
  }
}
```

### 3.3 Micro-Benchmark Harness

**File**: `tools/bench-micro.rkt`

**Design**: Criterion-style statistical benchmarking for individual Racket operations.

```racket
;; Usage:
(bench "unify-simple-types"
  #:warmup 5 #:samples 30
  (lambda ()
    (parameterize ([current-meta-store (make-hasheq)])
      (unify empty-ctx (expr-nat) (expr-nat)))))
```

**Statistical output per benchmark:**
- Mean, median, min, max
- Standard deviation, IQR
- 95% CI (bootstrap or t-distribution)
- Outlier count and classification
- Coefficient of variation (flag if >5%)

**Benchmark categories:**

```
benchmarks/
  micro/
    bench-unify.rkt         -- unification: same types, metas, occurs check, deep terms
    bench-reduce.rkt        -- reduction: nat arithmetic, list ops, Church numerals
    bench-elaborate.rkt     -- elaboration: implicit resolution, let-generalization
    bench-trait-resolve.rkt -- trait resolution: monomorphic, parametric, chain depth
    bench-champ.rkt         -- CHAMP operations: insert, lookup, fold at various sizes
    bench-propagator.rkt    -- propagator: network creation, quiescence, BSP vs sequential
    bench-solver.rkt        -- logic solver: fact queries, recursive rules, backtracking
    bench-zonk.rkt          -- zonking: shallow terms, deep nesting, many metas
  integration/
    bench-stdlib.rkt        -- full stdlib compilation
    bench-programs.rkt      -- representative user programs
    bench-relational.rkt    -- relational demos (parent/ancestor, course-data)
  stress/
    bench-deep-nesting.rkt  -- deeply nested Pi/Sigma types
    bench-many-metas.rkt    -- programs generating 100+ metavariables
    bench-large-facts.rkt   -- relations with 1000+ facts
    bench-recursive-rules.rkt -- deep recursive rule chains
```

### 3.4 Memory Profiling

**Approach**: Use `current-memory-use` before/after each test file, record delta.

```racket
(define mem-before (current-memory-use))
(collect-garbage) (collect-garbage)
;; ... run test ...
(collect-garbage) (collect-garbage)
(define mem-after (current-memory-use))
(define mem-delta (- mem-after mem-before))
```

**Additional GC metrics**: Racket provides `current-gc-milliseconds` for total GC time. Record pre/post delta.

**JSONL extension:**
```json
{
  "file": "test-stdlib.rkt",
  "wall_ms": 132361,
  "mem_bytes": 48000000,
  "gc_ms": 2300
}
```

### 3.5 Multi-Run Statistical Baseline

**Current**: Compare against single previous run (noisy).

**Improved**: Maintain a rolling baseline of the last N runs (default N=5).

```racket
(define (detect-regression file-name current-ms baseline-runs threshold)
  (define baseline-times
    (filter-map (lambda (run) (file-time-in-run run file-name)) baseline-runs))
  (when (>= (length baseline-times) 3)
    (define baseline-median (median baseline-times))
    (define delta-pct (/ (- current-ms baseline-median) baseline-median))
    (define abs-delta (- current-ms baseline-median))
    ;; Require BOTH percentage AND absolute threshold
    (and (> delta-pct (/ threshold 100.0))
         (> abs-delta 500)  ;; minimum 500ms absolute change
         (regression-report file-name baseline-median current-ms delta-pct))))
```

**Effect size gating**: Small absolute changes (<500ms) are never flagged as regressions, even if the percentage is large (e.g., 100ms → 112ms = 12% but not meaningful).

---

## 4. Property-Based Testing Integration

### 4.1 Framework Choice: rackcheck

The Racket `rackcheck` library provides QuickCheck-style property testing with shrinking. It integrates with `rackunit`.

### 4.2 Soundness Properties

```racket
;; Subject reduction: if e : T and e ⇝ e', then e' : T
(check-property
  ([prog (gen-well-typed-program max-depth)])
  (define type (infer-type prog))
  (define reduced (reduce-one-step prog))
  (when reduced
    (check-equal? (infer-type reduced) type)))

;; Unification soundness: if unify(a,b) succeeds, then subst(a) = subst(b)
(check-property
  ([t1 (gen-type max-depth)]
   [t2 (gen-type max-depth)])
  (parameterize ([current-meta-store (make-hasheq)])
    (when (unify-ok? (unify empty-ctx t1 t2))
      (check-equal? (zonk t1) (zonk t2)))))

;; Round-trip parsing
(check-property
  ([prog (gen-surface-program)])
  (check-equal? (parse (pretty-print (parse prog))) (parse prog)))
```

### 4.3 Performance Properties

```racket
;; No exponential blowup: type checking completes within heartbeat budget
(check-property
  ([prog (gen-program max-depth)])
  (with-perf-counters
    (parameterize ([current-reduction-fuel (box 100000)])
      (check-not-exn (lambda () (process-command prog))))))

;; Unification step count is bounded by term size
(check-property
  ([t1 (gen-type max-depth)]
   [t2 (gen-type max-depth)])
  (with-perf-counters
    (unify empty-ctx t1 t2)
    (define steps (perf-counters-unify-steps (current-perf-counters)))
    (define size (+ (term-size t1) (term-size t2)))
    (check-true (< steps (* 10 size size)))))  ;; quadratic bound
```

### 4.4 Generative Test Corpus

Build a **stored corpus** of randomly-generated programs:

1. Generate 1000 programs using `gen-well-typed-program`
2. Store in `data/benchmarks/corpus.jsonl`
3. On each CI run, measure all corpus programs
4. Compare against stored baseline
5. Shrink any newly-slow programs to find minimal regression cases

---

## 5. Dashboard & Visualization

### 5.1 Existing: DearPyGui Desktop Dashboard

Keep as-is for local development. Already provides:
- Suite overview (total wall time trend)
- Per-file trend analysis
- Latest run breakdown (bar chart)

### 5.2 New: Static HTML Report

**Tool**: `tools/benchmark-report.rkt` → generates `data/benchmarks/report.html`

Uses Vega-Lite JSON specs embedded in a single HTML file (no external dependencies):

**Visualizations:**
1. **Suite trend**: Line chart of total wall time across last N commits
2. **Phase breakdown**: Stacked bar chart showing parse/elaborate/type-check/etc. per file
3. **Heartbeat trends**: Line charts for unify-steps, reduce-steps, meta-created over time
4. **Regression table**: Sortable table of files with delta% vs baseline
5. **Memory trend**: Line chart of peak memory usage over time
6. **Comparison mode**: Side-by-side charts for A/B comparisons (e.g., DFS solver vs propagator solver)

**Generation:**
```bash
racket tools/benchmark-report.rkt                    # from timings.jsonl
racket tools/benchmark-report.rkt --last 20          # last 20 runs
racket tools/benchmark-report.rkt --compare REF      # comparison mode
racket tools/benchmark-report.rkt --output report.html
```

### 5.3 CI Integration

**GitHub Actions workflow** (`.github/workflows/benchmark.yml`):

```yaml
name: Performance Regression Check
on: [pull_request]

jobs:
  benchmark:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Racket
        uses: Bogdanp/setup-racket@v1
      - name: Pre-compile
        run: raco make racket/prologos/driver.rkt
      - name: Run benchmarks
        run: racket tools/benchmark-tests.rkt --regression-threshold 15
      - name: Generate report
        run: racket tools/benchmark-report.rkt --last 5
      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: benchmark-report
          path: data/benchmarks/report.html
```

---

## 6. Comparative Benchmarking: Type Inference A/B Testing

### 6.1 The Core Comparison

The primary comparative benchmark is:

**System A**: Current ad-hoc metavar system (metavar-store.rkt + unify.rkt + typing-core.rkt)
**System B**: Logic-engine-based type inference (propagator cells + lattice merge + ATMS worldviews)

Both systems solve the same problem (type inference for Prologos programs) using different architectures. The benchmark suite measures them on identical inputs.

### 6.2 Metrics for Comparison

| Metric | System A Source | System B Source |
|--------|----------------|-----------------|
| Total wall time | `time-phase 'type-check` | `time-phase 'propagator-solve` |
| Unification count | `unify-steps` counter | `cell-merge-count` counter |
| Meta/cell creation | `meta-created` counter | `cell-created` counter |
| Constraint solving | `constraint-retries` counter | `propagator-firings` counter |
| Memory usage | `current-memory-use` delta | `current-memory-use` delta |
| Deterministic cost | Sum of all heartbeats | Sum of all heartbeats |
| Error quality | Manual assessment | Manual assessment |

### 6.3 Benchmark Programs for Comparison

Programs that stress type inference in different ways:

```
Category                 What It Stresses
───────────────────────────────────────────────────────
simple-typed.prologos    Basic inference, no metas
implicit-args.prologos   Implicit argument resolution (many metas)
trait-chain.prologos     Deep trait resolution chains
speculative.prologos     Programs requiring speculative type-checking
union-types.prologos     Union type inference with ACI normalization
dependent.prologos       Dependent types with complex unification
church-folds.prologos    Church fold detection (save/restore meta state)
large-prelude.prologos   Full prelude load + large program
recursive-types.prologos Recursive type definitions
session-types.prologos   Session type inference
```

### 6.4 A/B Test Harness

```racket
;; bench-ab.rkt — A/B comparison between type inference backends
(define (bench-ab program)
  ;; System A: current implementation
  (define a-result
    (with-perf-counters
      (time-phase 'system-a
        (lambda () (process-file-system-a program)))))

  ;; System B: logic-engine implementation
  (define b-result
    (with-perf-counters
      (time-phase 'system-b
        (lambda () (process-file-system-b program)))))

  ;; Verify same results
  (check-equal? (result-types a-result) (result-types b-result))

  ;; Return comparison data
  (hasheq 'program program
          'system-a (extract-metrics a-result)
          'system-b (extract-metrics b-result)))
```

---

## 7. Solver Backend Comparison

### 7.1 DFS Solver vs Propagator-Based Solver

The relational engine currently uses a simple DFS solver with backtracking. A future propagator-based solver would use the PropNetwork infrastructure.

**Benchmarks:**

```
Benchmark                    What It Measures
──────────────────────────────────────────────────────
fact-lookup-N.prologos       Pure fact retrieval at N=100,1K,10K facts
recursive-rules.prologos     Recursive rule evaluation (ancestor, transitive closure)
negation.prologos            Negation-as-failure (not)
multi-arity.prologos         Multi-arity dispatch
backtracking.prologos        Deep search trees requiring backtracking
tabling.prologos             Tabling (memoization) efficiency
constraint-propagation.prologos  Numeric/interval constraint propagation
```

### 7.2 Data Structure Comparison

Compare CHAMP-backed structures against alternatives:

```
Structure     Operation   Benchmark
────────────────────────────────────────
CHAMP Map     insert      N=100,1K,10K,100K keys
CHAMP Map     lookup      random access pattern
CHAMP Map     fold        full iteration
PVec          push        N=100,1K,10K elements
PVec          random-get  random access
UnionFind     union       N components, varying connectivity
UnionFind     find        with path splitting vs without
```

---

## 8. Implementation Plan

### Phase A: Heartbeat Counters (~80 lines)

**Files**: New `performance-counters.rkt`, modifications to `unify.rkt`, `reduction.rkt`, `elaborator.rkt`, `typing-core.rkt`, `trait-resolution.rkt`, `metavar-store.rkt`, `zonk.rkt`, `relations.rkt`

1. Create `performance-counters.rkt` with counter struct and parameter
2. Add `perf-counter-inc!` calls to each instrumentation point
3. Wire into `bench-lib.rkt` for recording alongside wall time
4. Update JSONL schema with heartbeat fields

### Phase B: Phase-Level Timing (~40 lines)

**Files**: `driver.rkt`, `bench-lib.rkt`

1. Add `time-phase` helper to `bench-lib.rkt`
2. Instrument `driver.rkt` `process-command` with phase wrappers
3. Aggregate per-file, record in JSONL

### Phase C: Micro-Benchmark Harness (~150 lines)

**Files**: New `tools/bench-micro.rkt`, new `benchmarks/micro/*.rkt`

1. Statistical benchmarking library (warmup, sampling, CI computation)
2. Initial micro-benchmarks for unification, reduction, CHAMP
3. JSON output format compatible with existing JSONL

### Phase D: Multi-Run Baseline + Memory (~60 lines)

**Files**: `benchmark-tests.rkt`, `bench-lib.rkt`

1. Rolling baseline (median of last 5 runs)
2. Effect size gating (absolute + percentage threshold)
3. Memory delta recording via `current-memory-use`

### Phase E: Property-Based Testing (~200 lines)

**Files**: New `tests/test-properties.rkt`, generators in `tests/test-generators.rkt`

1. Install rackcheck dependency
2. Term/type generators for Prologos AST
3. Soundness properties (subject reduction, unification, round-trip)
4. Performance properties (bounded heartbeats)

### Phase F: Static HTML Report (~300 lines)

**Files**: New `tools/benchmark-report.rkt`

1. Read `timings.jsonl`, compute statistics
2. Generate Vega-Lite specs for each visualization
3. Emit self-contained HTML file

### Phase G: Comparative Benchmark Framework (~200 lines)

**Files**: New `tools/bench-ab.rkt`, new `benchmarks/comparative/*.prologos`

1. A/B test harness for type inference backends
2. Solver comparison framework
3. Data structure comparison benchmarks
4. Comparison-mode output in JSONL and HTML report

---

## 9. Success Criteria

1. **Heartbeat regression detection** catches algorithmic regressions that wall-clock misses
2. **Phase breakdown** identifies which pipeline stage is responsible for slowdowns
3. **Property-based testing** catches at least one bug that unit tests miss (historically true for QuickCheck)
4. **Static HTML report** is viewable without DearPyGui installation
5. **A/B framework** produces meaningful comparison data for the type-inference-on-logic-engine experiment
6. **Zero false positives** — no regression alerts on unchanged code across 10 consecutive runs

---

## 10. References

- Kalibera & Jones, "Rigorous Benchmarking in Reasonable Time" (ICPE 2013)
- Lean4 heartbeat system: `set_option maxHeartbeats N`
- Haskell criterion library: bootstrap CIs, outlier detection
- Bencher.dev: open-source continuous benchmarking
- rackcheck: Racket QuickCheck implementation
- Vega-Lite: declarative visualization grammar
- GHC performance dashboard methodology
