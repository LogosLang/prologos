# Benchmarking Framework & Performance Observatory — Design Document

**Date**: 2026-02-25 (revised 2026-02-26 after external critique)
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

**Zero-cost when disabled**: When `current-perf-counters` is `#f` (the default), the `when` check is a Racket parameter lookup (~5ns, same cost as the existing `current-reduction-fuel` box check in `reduction.rkt`). Benchmarks explicitly opt in via `with-perf-counters`.

**Self-validation**: Phase A must include a self-benchmark measuring counter overhead:

```racket
;; Validate counter overhead is <5% on tight loops
(bench "counter-overhead"
  #:warmup 5 #:samples 20
  (lambda ()
    (with-perf-counters
      (for ([i (in-range 1000000)])
        (perf-counter-inc! unify-steps)))))

(bench "counter-baseline"
  #:warmup 5 #:samples 20
  (lambda ()
    (for ([i (in-range 1000000)])
      (void))))
```

If overhead exceeds 5%, revisit with compile-time elimination. (We expect it won't, given that the analogous `current-reduction-fuel` box-check pattern has been running in every reduction step since day one without measurable impact.)

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

**Recording**: Phase timings stored per-command, aggregated per-file in the JSONL record.

**Schema versioning**: All new records include `"schema_version"` for forward compatibility. Existing records (91 runs) are implicitly v1. Readers must handle both versioned and unversioned records gracefully.

```json
{
  "schema_version": 2,
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
(collect-garbage 'major)  ;; force major GC, not just minor
;; ... run test ...
(collect-garbage 'major)
(define mem-after (current-memory-use))
(define mem-delta (- mem-after mem-before))
```

**Limitation**: `current-memory-use` measures **retained heap**, not allocation pressure. A program that allocates 1GB but retains only 1MB shows the same as one retaining 1MB throughout. Racket does not expose a direct allocation counter without prohibitive overhead (`errortrace`/`memory-trace` incur 10-100x slowdown). We use `current-gc-milliseconds` delta as a proxy for allocation pressure — high GC time correlates with high allocation rate.

**Additional GC metrics**: Racket provides `current-gc-milliseconds` for total GC time. Record pre/post delta.

**JSONL extension:**
```json
{
  "file": "test-stdlib.rkt",
  "wall_ms": 132361,
  "mem_retained_bytes": 48000000,
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

**Variance flagging**: Supplement threshold detection with coefficient of variation (CV) checks to identify unstable benchmarks:

```racket
(define (flag-high-variance file-name baseline-times)
  (when (>= (length baseline-times) 5)
    (define mu (mean baseline-times))
    (define cv (/ (stddev baseline-times) mu))
    (when (> cv 0.15)
      (warn "High variance in ~a: CV=~a% — consider splitting or stabilizing"
             file-name (* 100 cv)))))
```

**Design note**: The rolling window is deliberately short (5 runs) to detect *recent* regressions. Long-term drift analysis belongs to the dashboard trend visualization (Phase F), which plots full historical data and makes gradual trends visually obvious.

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

### 4.2.1 Generator Self-Validation

A buggy `gen-well-typed-program` makes all soundness properties vacuously true. The generators themselves must be validated:

```racket
;; The generator must actually produce well-typed programs
(check-property
  ([prog (gen-well-typed-program 5)])
  (check-not-exn (lambda () (infer-type prog))))

;; Coverage: generated programs should exercise diverse AST shapes
(define (validate-generator-coverage n)
  (define coverage (make-hash))
  (for ([_ (in-range n)])
    (define prog (gen-well-typed-program 5))
    (define shape (classify-ast-shape prog))  ;; top-level AST constructor
    (hash-update! coverage shape add1 0))
  ;; Should see reasonable distribution across shapes
  (for ([(shape count) (in-hash coverage)])
    (printf "  ~a: ~a (~a%)\n" shape count (round (* 100 (/ count n))))))
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
        with:
          fetch-depth: 0  # full history for baseline access
      - name: Install Racket
        uses: Bogdanp/setup-racket@v1
      - name: Pre-compile
        run: raco make racket/prologos/driver.rkt
      - name: Fetch baseline from main
        run: |
          git show main:data/benchmarks/timings.jsonl > /tmp/baseline-timings.jsonl 2>/dev/null || true
      - name: Run benchmarks
        run: racket tools/benchmark-tests.rkt --regression-threshold 15 --baseline /tmp/baseline-timings.jsonl
      - name: Generate report
        run: racket tools/benchmark-report.rkt --last 5
      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: benchmark-report
          path: data/benchmarks/report.html
```

**Baseline sourcing**: On PR branches, the baseline is fetched from `main`'s `timings.jsonl` rather than relying on the branch having historical data. The `--baseline` flag allows explicit baseline specification.

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
;; Each system is run N times for statistical validity.
(define (bench-ab program #:runs [N 15])
  ;; Multi-run collection
  (define a-runs
    (for/list ([_ (in-range N)])
      (with-perf-counters
        (time-phase 'system-a
          (lambda () (process-file-system-a program))))))
  (define b-runs
    (for/list ([_ (in-range N)])
      (with-perf-counters
        (time-phase 'system-b
          (lambda () (process-file-system-b program))))))

  ;; Verify correctness (same results on first run)
  (check-equal? (result-types (first a-runs)) (result-types (first b-runs)))

  ;; Statistical comparison (non-parametric, no normality assumption)
  (define a-times (map extract-wall-ms a-runs))
  (define b-times (map extract-wall-ms b-runs))
  (define p-value (mann-whitney-u a-times b-times))
  (define speedup (/ (median b-times) (median a-times)))

  (hasheq 'program program
          'system-a (summarize-runs a-runs)
          'system-b (summarize-runs b-runs)
          'p-value p-value
          'speedup speedup
          'significant? (< p-value 0.05)))
```

**Statistical rigor**: Single-run comparison between A and B is meaningless due to noise. The harness runs each system N times (default 15) and compares distributions via Mann-Whitney U test (non-parametric, no normality assumption). Only differences with p < 0.05 are reported as significant.

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

## 8. Operational Practices

### 8.1 Benchmark Selection Criteria

Benchmarks admitted to the suite must satisfy:

1. **Representative**: Covers common use cases, not just pathological edge cases
2. **Stable**: CV < 10% across 10+ runs (validated via stability check)
3. **Meaningful**: Takes >100ms for integration benchmarks (micro-benchmarks excepted)
4. **Diverse**: Exercises different pipeline stages and code paths
5. **Owned**: Clear purpose documented; updated when semantics change

### 8.2 Benchmark Stability Validation

Before a benchmark is accepted into the suite, validate its stability:

```racket
(define (validate-benchmark-stability name thunk #:runs [n 10])
  (define times (for/list ([_ (in-range n)]) (measure thunk)))
  (define cv (/ (stddev times) (mean times)))
  (cond
    [(> cv 0.10) (error "Benchmark ~a is unstable: CV=~a%" name (* 100 cv))]
    [(> cv 0.05) (warn "Benchmark ~a has moderate variance: CV=~a%" name (* 100 cv))]
    [else (printf "Benchmark ~a is stable: CV=~a%\n" name (* 100 cv))]))
```

Unstable benchmarks (CV > 10%) are rejected or investigated for environmental sensitivity. Moderately unstable benchmarks (5-10%) are flagged for review.

### 8.3 Benchmark Deprecation

Benchmarks that become unstable (CV > 15% over 10 runs) or obsolete (testing removed features) are moved to `benchmarks/archived/` with a dated comment explaining why. No formal policy needed at our scale — just keep the suite clean.

### 8.4 Text Summary Output

In addition to JSONL recording and HTML reports, every benchmark run prints a structured text summary to stdout, usable in CI logs and terminal workflows:

```
════════════════════════════════════════════════════════════════
BENCHMARK SUMMARY — 2026-02-25 14:32:00 (commit abc1234)
════════════════════════════════════════════════════════════════
Overall: 132.4s total (↑ 3.2% from baseline)
Regressions (2):
  test-stdlib.rkt      45.2s → 52.1s  (+15.3%)  ← type_check phase
  test-trait-chain.rkt 12.1s → 14.8s  (+22.3%)  ← trait_resolve phase
Improvements (1):
  test-simple.rkt       2.1s →  1.8s  (-14.3%)
Stable: 42 files within ±5% of baseline
Heartbeat Totals:
  unify_steps:  482,000 (↑ 8%)   reduce_steps: 123,000 (stable)
  meta_created:   1,560 (↑ 12%)  meta_solved:    1,488 (↑ 10%)
```

### 8.5 Regression Investigation Workflow

When a regression is detected:

1. **Check heartbeat breakdown**: Which counter spiked? (algorithmic change vs. infrastructure change)
2. **Check phase breakdown**: Which pipeline stage? (narrows from "everything" to "type_check" or "trait_resolve")
3. **Profile deeply**: `raco profile` or `racket/trace` on the specific test file
4. **Bisect**: `git bisect run racket tools/bench-single.rkt <test-file>` to find the exact commit
5. **Compare heartbeats**: If heartbeats changed but wall time didn't, the change is algorithmic but not yet performance-visible (early warning). If wall time changed but heartbeats didn't, it's environmental noise.

### 8.6 Performance Budgets (Future — Phase F+)

Performance budgets will be established after 3 months of data collection. Premature budgets that are either too loose (useless) or too tight (constant false alerts) are worse than no budgets. Once we have sufficient baseline data, we will set per-file heartbeat budgets and wall-time expectations.

---

## 9. Implementation Plan

### Phase A: Heartbeat Counters (~80 lines)

**Files**: New `performance-counters.rkt`, modifications to `unify.rkt`, `reduction.rkt`, `elaborator.rkt`, `typing-core.rkt`, `trait-resolution.rkt`, `metavar-store.rkt`, `zonk.rkt`, `relations.rkt`

1. Create `performance-counters.rkt` with counter struct and parameter
2. Add `perf-counter-inc!` calls to each instrumentation point
3. Wire into `bench-lib.rkt` for recording alongside wall time
4. Update JSONL schema with `schema_version: 2` and heartbeat fields
5. Self-benchmark: validate counter overhead is <5% on tight loops (see §3.1)

### Phase B: Phase-Level Timing (~60 lines)

**Files**: `driver.rkt`, `bench-lib.rkt`

1. Add `time-phase` helper to `bench-lib.rkt`
2. Instrument `driver.rkt` `process-command` with phase wrappers
3. Aggregate per-file, record in JSONL
4. Structured text summary output to stdout after each run (see §8.4)

### Phase C: Micro-Benchmark Harness (~150 lines)

**Files**: New `tools/bench-micro.rkt`, new `benchmarks/micro/*.rkt`

1. Statistical benchmarking library (warmup, sampling, CI computation, CV)
2. Benchmark stability validation gate (CV < 10% required, see §8.2)
3. Initial micro-benchmarks for unification, reduction, CHAMP
4. JSON output format compatible with existing JSONL

### Phase D: Multi-Run Baseline + Memory (~60 lines)

**Files**: `benchmark-tests.rkt`, `bench-lib.rkt`

1. Rolling baseline (median of last 5 runs)
2. Effect size gating (absolute + percentage threshold)
3. Variance flagging (CV > 15% warning, see §3.5)
4. Memory delta recording via `current-memory-use` with `'major` GC

### Phase E: Property-Based Testing (~200 lines)

**Files**: New `tests/test-properties.rkt`, generators in `tests/test-generators.rkt`

1. Install rackcheck dependency
2. Term/type generators for Prologos AST
3. **Generator self-validation**: verify generators produce well-typed programs, measure AST coverage (see §4.2.1)
4. Soundness properties (subject reduction, unification, round-trip)
5. Performance properties (bounded heartbeats)

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

## 10. Success Criteria

1. **Heartbeat regression detection** catches algorithmic regressions that wall-clock misses
2. **Phase breakdown** identifies which pipeline stage is responsible for slowdowns
3. **Property-based testing** catches at least one bug that unit tests miss (historically true for QuickCheck)
4. **Static HTML report** is viewable without DearPyGui installation
5. **A/B framework** produces meaningful comparison data for the type-inference-on-logic-engine experiment
6. **Zero false positives** — no regression alerts on unchanged code across 10 consecutive runs

---

## 11. References

- Kalibera & Jones, "Rigorous Benchmarking in Reasonable Time" (ICPE 2013)
- Lean4 heartbeat system: `set_option maxHeartbeats N`
- Haskell criterion library: bootstrap CIs, outlier detection
- Bencher.dev: open-source continuous benchmarking
- rackcheck: Racket QuickCheck implementation
- Vega-Lite: declarative visualization grammar
- GHC performance dashboard methodology
