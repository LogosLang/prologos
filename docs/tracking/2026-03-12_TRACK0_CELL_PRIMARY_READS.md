# Track 0: Cell-Primary Reads — Infrastructure Foundation

**Created**: 2026-03-12
**Status**: Stage 2 (Design)
**Depends on**: Propagator-First Migration Sprint Phases 0-4 (COMPLETE)
**Enables**: Track 1 (Constraint Tracking), Track 2 (Registries), Track 3 (Global Env), Track 4 (ATMS Speculation)
**Research basis**: `2026-03-11_PROPAGATOR_FIRST_PIPELINE_AUDIT.md`, `2026-03-11_WHOLE_SYSTEM_PROPAGATOR_MIGRATION.md`
**Prior implementation**: `2026-03-11_1800_PROPAGATOR_FIRST_MIGRATION.md` (Phases 0-4)

---

## 1. Context and Motivation

The Propagator-First Migration Sprint (Phases 0-4) established a **dual-write architecture**: every state mutation writes to both the legacy Racket parameter AND a propagator cell. This proved that cells can mirror the entire pipeline without regressions (6889 tests pass). But all **reads** still go through legacy parameters — cells are write-only shadows.

This track establishes the shared infrastructure that Tracks 1-4 need to flip individual read sites from parameter to cell. It does NOT flip any reads itself — it provides the foundation so each subsequent track can flip reads mechanically.

### 1.1 What Exists

| Component | File | Status |
|-----------|------|--------|
| Pure persistent prop-network | `propagator.rkt` | Complete — CHAMP-backed, BSP scheduler, parallel executor |
| Merge functions (hasheq union, list append, set union, replace) | `infra-cell.rkt` | Complete — 5 merge functions |
| Cell factories (registry, list, set, replace, general) | `infra-cell.rkt` | Complete — general factory + 4 convenience |
| Named cell registry | `infra-cell.rkt` | Complete — registration protocol with name→cell-id lookup |
| ATMS assumption bridge | `infra-cell.rkt` | Complete — infra-state struct, assume/retract/commit, assumed writes, believed reads |
| Dual-write: 7 constraint cells | `metavar-store.rkt` | Complete — Phase 1a-1c, all writes shadowed |
| Dual-write: 24 registry cells | `macros.rkt` | Complete — Phase 2a-2c, all writes shadowed |
| Dual-write: per-definition cells | `global-env.rkt` | Complete — Phase 3a-3d, definition cells created |
| Dual-write: 3 warning cells | `warnings.rkt` | Complete — Phase 2c, list cells |
| Dual-write: 3 namespace cells | `namespace.rkt` | Complete — Phase 3c, module-registry + ns-context + defn-param-names |
| Per-command cell initialization | `metavar-store.rkt:reset-meta-store!` | Complete — 7 constraint cells created per command |
| Callback-based cell access | `metavar-store.rkt` | Complete — 11 `current-prop-*` callbacks break circular deps |

### 1.2 What's Missing for Cell-Primary Reads

The dual-write infrastructure was designed for **write correctness verification**. Flipping reads requires:

1. **Read-path accessor functions** — Each domain (constraints, registries, global-env) needs a function that reads from the cell instead of the parameter. Some exist in embryonic form (e.g., `read-constraint-store` with cell fallback) but most don't.

2. **Parameter→cell equivalence assertions** — During transition, we need runtime assertions that cell content matches parameter content. This catches any drift between the two paths. Once reads are proven correct, the assertions and the parameter writes are removed.

3. **Benchmarking protocol** — Before/after performance measurement for each track. The existing `tools/benchmark-tests.rkt` captures wall time; we also need cell/propagator count metrics and peak memory.

4. **Cell-read callback infrastructure** — The existing callback pattern (`current-prop-cell-read`, etc.) exists for metavar cells. Registry and constraint cells need similar read accessors that don't require importing `elaborator-network.rkt` directly (to avoid circular dependencies).

---

## 2. Design

### 2.1 Equivalence Assertion Layer

A thin assertion layer that can be enabled during development/testing and disabled in production:

```racket
;; infra-cell-assertions.rkt (new file)
(provide
  assert-cell-parameter-equiv!   ;; (cell-value param-value name → void)
  current-infra-assertions-on?)  ;; parameter, default #t in tests, #f in production

(define current-infra-assertions-on? (make-parameter #f))

(define (assert-cell-parameter-equiv! cell-val param-val name)
  (when (current-infra-assertions-on?)
    (unless (equal? cell-val param-val)
      (error 'infra-cell-assert
             "cell/parameter drift for ~a: cell=~e param=~e"
             name cell-val param-val))))
```

This is used during the transition period. Each track adds assertions at its read sites, validates they never fire across the full test suite, then removes both the assertion and the parameter read — leaving only the cell read.

### 2.2 Cell-Read Accessor Protocol

Extend the existing callback infrastructure so that any module can read infrastructure cells without importing `elaborator-network.rkt`:

```racket
;; In metavar-store.rkt — extend existing callback pattern
(define current-infra-cell-read (make-parameter #f))
;; Signature: (cell-id → value)
;; Installed by driver.rkt alongside existing callbacks
```

Individual tracks then define domain-specific read functions:

```racket
;; Example: constraint domain (Track 1)
(define (read-constraints-from-cell)
  (define cid (current-constraint-cell-id))
  (define read-fn (current-infra-cell-read))
  (if (and cid read-fn)
      (read-fn cid)
      (current-constraint-store)))  ;; fallback during transition
```

The fallback ensures the system works even when cells aren't available (e.g., in test fixtures that don't set up the full network).

### 2.3 Benchmarking Protocol

#### 2.3.1 Baseline Capture

Before starting any track, capture:

```bash
# Wall-time baseline
racket tools/benchmark-tests.rkt --report > data/benchmarks/baseline-track-N.txt
# Tag the commit
git tag benchmark-baseline-track-N
```

#### 2.3.2 Phase Checkpoint

After each phase within a track:

```bash
# Compare against baseline
racket tools/benchmark-tests.rkt --compare benchmark-baseline-track-N
```

Include delta in the track's progress table. Flag any regression >5% wall time.

#### 2.3.3 Cell Metrics (New)

Add a `--cell-metrics` mode to the benchmark tooling that reports after elaboration:

| Metric | Source |
|--------|--------|
| Total cells in network | `prop-network-next-cell-id` |
| Total propagators | `prop-network-next-prop-id` |
| Cells with non-bot content | Count of `net-cell-read != bot` |
| Peak memory (RSS) | `(current-memory-use)` |
| Network construction time | Timer around `reset-meta-store!` |

This is lightweight instrumentation added to `run-affected-tests.rkt`. Data appended to `data/benchmarks/timings.jsonl` alongside existing per-file timing.

#### 2.3.4 Workflow Integration

**Rule**: Each track's progress table includes a "Bench" column. A phase is not complete until its benchmark checkpoint is recorded. Format: `Δ+1.2%` or `Δ-0.3%` (wall time relative to baseline).

---

## 3. Scope and Deliverables

### 3.1 Files to Create

| File | Purpose |
|------|---------|
| `racket/prologos/infra-cell-assertions.rkt` | Equivalence assertion layer (transition aid) |

### 3.2 Files to Modify

| File | Change |
|------|--------|
| `racket/prologos/metavar-store.rkt` | Add `current-infra-cell-read` callback parameter |
| `racket/prologos/driver.rkt` | Install `current-infra-cell-read` callback alongside existing callbacks |
| `tools/run-affected-tests.rkt` | Add `--cell-metrics` flag for network size reporting |
| `tools/benchmark-tests.rkt` | Support cell-metric aggregation in `--report` output |

### 3.3 Files to Test

| Test File | Coverage |
|-----------|----------|
| `tests/test-infra-cell-assertions-01.rkt` | Assertion layer: fires on drift, silent on match, respects enable flag |
| Existing `tests/test-infra-cell-*.rkt` (5 files) | Regression: existing cell infrastructure unaffected |

---

## 4. Progress Tracker

| Phase | Description | Status | Bench | Notes |
|-------|-------------|--------|-------|-------|
| 0a | Equivalence assertion layer | ⬜ | | |
| 0b | Cell-read accessor callback | ⬜ | | |
| 0c | Benchmarking protocol + tooling | ⬜ | | |
| 0d | Integration smoke test | ⬜ | | |

---

## 5. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Assertion layer adds overhead to hot paths | Low | Low | Disabled by default; enabled only in test mode |
| Cell-read callback introduces another indirection layer | Low | Low | Single parameter lookup; same pattern as existing 11 callbacks |
| Benchmarking tooling changes slow down test runner | Low | Medium | `--cell-metrics` flag opt-in; no overhead when not requested |
| This track is too thin to be its own track | Medium | Low | It IS thin by design — it's a prerequisite, not a feature. 1-2 day scope. |

---

## 6. Relationship to Subsequent Tracks

This track provides three things each subsequent track uses:

1. **Assertion layer**: Each track wraps its read-flip in `assert-cell-parameter-equiv!`, validates across 6889 tests, then removes both assertion and parameter write.

2. **Cell-read accessor**: Each track defines domain-specific read functions using `current-infra-cell-read`, with parameter fallback during transition.

3. **Benchmarking baseline**: Each track captures a baseline before starting and checkpoints after each phase.

The dependency graph:

```
Track 0 (this)
  ├── Track 1: Constraint Tracking → Cell-Primary Reads
  ├── Track 2: Registry Parameters → Cell-Primary Reads
  ├── Track 3: Global Environment → Cell-Primary Reads
  └── Track 4: ATMS Speculation (depends on Track 1 + Track 3)
```

Tracks 1-3 are independent of each other. Track 4 depends on Track 1 (constraint cells must be primary for ATMS-backed speculation) and Track 3 (global-env cells must be primary for per-definition assumptions).

---

## 7. Open Questions

1. **Should the assertion layer be a separate file or embedded in `infra-cell.rkt`?** Separate file avoids adding test-only code to production infrastructure. Embedded avoids a new require.

2. **Should `current-infra-cell-read` be a new callback or should we extend `current-prop-cell-read`?** The existing `current-prop-cell-read` takes `(enet cell-id)` (requires the network). For infrastructure cells where the cell-id is known, a `(cell-id → value)` signature that auto-reads from `current-prop-net-box` would be more ergonomic.

3. **What wall-time regression budget should we set per track?** 5% is conservative; the dual-write Phases 0-4 showed <1% overhead. Tighter budget (2%) would catch regressions faster but risk false positives from system noise.
