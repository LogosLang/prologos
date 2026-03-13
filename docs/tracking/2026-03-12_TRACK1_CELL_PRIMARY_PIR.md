# Track 1: Constraint Cell-Primary — Post-Implementation Review

**Date**: 2026-03-12 / 2026-03-13
**Commits**: `ffc5d26` through `35fa4ae` (8 commits)
**Test Count**: 6889 (358 files) — unchanged from baseline
**Design Document**: `docs/tracking/2026-03-12_TRACK1_CONSTRAINT_CELL_PRIMARY.md`
**Baseline Tag**: `benchmark-baseline-track-1`

---

## 1. Objectives and Scope

### 1.1 Original Goal

Migrate all constraint tracking reads from legacy Racket parameters to propagator cells, making cells the single source of truth (cell-primary). This was identified as the Pipeline Audit's highest-priority migration target because the parameter-based constraint infrastructure — wakeup registries, dirty flags, retry loops — is a hand-rolled propagator network that duplicates what the actual propagator network already does.

### 1.2 Planned Scope

6 phases across 3 stages:

| Stage | Phases | Description |
|-------|--------|-------------|
| Read flips | 1-3 | Flip all constraint reads from parameters to cells |
| Write removal | 4-5 | Remove parameter writes, align speculation |
| Cleanup | 6 | Remove parameter definitions, dirty flags |

12 distinct constraint read sites across 3 files (`metavar-store.rkt`, `unify.rkt`, `trait-resolution.rkt`), plus 6 write sites and 1 speculation save/restore site.

### 1.3 Actual Scope

**Phases 0-6 completed.**

The core goal was achieved: all constraint reads go through cell-primary accessors, and all writes are cell-only (no parameter fallback). Phase 6 ("network-everywhere") eliminated the `if/else` fallback pattern that Phases 0-5 introduced by making `with-fresh-meta-env` always create a propagator network via `reset-meta-store!`. This required adding `driver.rkt` to 10 test files and 2 benchmarks that lacked propagator callbacks, but the result is a single write path — cell-only — with no branch at every write site. Read functions have guards returning empty defaults when called pre-initialization (semantically correct: no constraints exist before the network is created).

---

## 2. What Was Delivered

### 2.1 Quantitative Summary

| Metric | Value |
|--------|-------|
| New read accessors | 5 (`read-trait-constraints`, `read-hasmethod-constraints`, `read-capability-constraints`, `read-wakeup-registry`, `read-trait-wakeup-map`) |
| Read sites flipped | 12 (across metavar-store.rkt, unify.rkt, trait-resolution.rkt) |
| Write sites converted | 6 (cell-primary with parameter fallback) |
| Speculation alignment | 1 (conditional save/restore in elab-speculation-bridge.rkt) |
| Cell metrics infrastructure | 3 files (performance-counters.rkt, driver.rkt, batch-worker.rkt) |
| Tests modified | 1 (test-infra-cell-constraint-01.rkt — updated for cell-primary assertions) |
| Implementation commits | 7 |
| Total LOC changed | ~160 insertions, ~100 deletions |
| Benchmark delta | +1.2% (189.2s → 191.4s, within noise) |

### 2.2 Architectural Components Delivered

1. **Cell-primary read accessors** (5 new functions): Each follows the same pattern — check for cell ID + network + read function; if all present, read from cell; otherwise fall back to parameter. This is a clean abstraction that encapsulates the cell-vs-parameter decision.

2. **Cell-only write paths** (Phase 6): All 6 constraint write functions use cell-only writes — no `if/else` fallback. The network is always present (network-everywhere via `with-fresh-meta-env` calling `reset-meta-store!`). Writes without a network crash loud (fail-by-construction), preventing silent data loss.

3. **Cell metrics emission**: `CELL-METRICS` JSON lines emitted to stderr alongside existing `PERF-COUNTERS`/`PHASE-TIMINGS`/`MEMORY-STATS`, extracted by batch-worker. Provides cells/propagators counts per test file.

4. **Unconditional speculation rollback** (Phase 6d): `with-speculative-rollback` relies entirely on `save-meta-state`/`restore-meta-state!` — no conditional constraint parameter save/restore needed since the network is always present.

---

## 3. What Went Well

### 3.1 The Read Accessor Pattern Generalized Perfectly

The existing `read-constraint-store` function (created during the prior sprint) established the cell-primary-with-fallback pattern. All 5 new read accessors followed this template exactly — no design variation was needed. This is a sign that the original pattern was well-designed: it anticipated the generalization.

### 3.2 Zero Test Regressions in Production Paths

After Phase 5a (write removal), the only failures were in tests that explicitly checked dual-write behavior (`test-infra-cell-constraint-01.rkt`) and tests that ran without a propagator network (constraint postponement, speculation bridge). The fix was mechanical: update infra tests to expect cell-primary behavior, add parameter fallback for no-network case. No production-path tests failed, which validates that the dual-write was already consistent.

### 3.3 Benchmarking Protocol Was Lightweight and Sufficient

The cell metrics infrastructure (Phase 0b) took one commit and provided useful data (37-81 cells per file, scaling with complexity). The baseline tag + `--report` comparison workflow was effective. The ~1% delta across all phases confirmed that cell reads are not measurably slower than parameter reads — validating the Pipeline Audit's prediction.

### 3.4 Phase Reordering Was the Right Call

The original plan had Phase 4 (speculation) before Phase 5 (write removal). During implementation, it became clear that Phase 4 required Phase 5 first: you can't remove explicit constraint save/restore until you've confirmed that writes go to cells (which are captured by `save-meta-state`). Reordering to 5-then-4 was correct and avoided a false start.

---

## 4. What Was Challenging

### 4.1 The Parameter Fallback Surprise

The original design assumed full parameter removal in Phase 6. The discovery that `with-fresh-meta-env` sets all cell IDs to `#f` (no propagator network) meant that pure write removal broke 5 test files. The fix — `if/else` with parameter fallback instead of pure `when` cell write — was the right architectural response, but it changes the endgame: parameters can't be fully removed until all test fixtures create propagator networks.

**Resolution** (Phase 6): Rather than creating a separate `with-fresh-meta-env/network` variant, Phase 6 made `with-fresh-meta-env` itself call `reset-meta-store!`, which creates the network when callbacks are installed. This required adding `driver.rkt` to 10 test files and 2 benchmarks that lacked callbacks. The result: all `with-fresh-meta-env` contexts have a network, all writes are cell-only, no parameter fallback needed. The `if/else` at every write site was removed entirely (`commit 35fa4ae`).

### 4.2 merge-list-append Ordering vs. cons Ordering

Cell writes use `merge-list-append` (newest at tail), while the parameter used `cons` (newest at head). This caused a subtle bug in `unify.rkt` where `(car post-store)` needed to become `(last post-store)` to find the newest constraint. Caught by test failure in Phase 1d, fixed immediately.

**Lesson**: When migrating from one data structure to another, the *ordering invariant* deserves explicit documentation. The merge function's behavior (append-to-tail) is documented, but the consumer's assumption (newest-first) was implicit.

### 4.3 Hasmethod Wakeup Has No Cell

Of all the constraint wakeup maps, `current-hasmethod-wakeup-map` is the only one without a corresponding cell ID. This was an oversight in the prior sprint's dual-write implementation (Phases 1a-1e). The parameter write for hasmethod wakeup must stay. Documented as future work.

---

## 5. How Results Compared to Expectations

### 5.1 Timeline

**Expected**: 3-4 days. **Actual**: ~1 session (~4 hours implementation).

The design document had been thoroughly critiqued (external review incorporated), and the prior sprint's dual-write infrastructure meant the cell-side plumbing was already in place. The work was mostly mechanical: create accessor, flip callers, verify tests. The only non-trivial debugging was the parameter fallback discovery (Phase 5a).

### 5.2 Scope

**Expected**: Phases 0-6 complete. **Actual**: Phases 0-6 complete.

Phase 6 was redesigned from "parameter removal" to "network-everywhere" — making `with-fresh-meta-env` always create a propagator network. This eliminated the parameter fallback entirely, achieving the original intent (single write path) through a different mechanism than originally planned (inject network everywhere vs. remove parameters).

### 5.3 Performance

**Expected**: No regression (Pipeline Audit predicted O(1) cell reads). **Actual**: +1.2% (within noise).

Confirmed: cell reads via CHAMP lookup are not measurably slower than parameter reads. This is the green light for all subsequent migration tracks — the read-flip pattern is cost-free.

---

## 6. Architectural Validation

### 6.1 What We Actually Achieved (Honest Assessment)

The constraint cells are **passive storage**, not **reactive nodes**. They have merge functions for monotonic accumulation, but zero propagator edges wired to them. Nothing watches the constraint cells. No cross-domain bridge reads from them. No propagator fires when a constraint is added.

What the cells provide today:
- **Transactional state**: The network snapshot captures all cell contents, so speculation rollback "just works" for constraints. This is genuinely useful — it's the property that made Phase 4a possible.
- **Unified read interface**: A single `read-constraint-store` accessor instead of direct parameter access. This is an API improvement, not a behavioral one.
- **Metric visibility**: Cell counts per elaboration, emitted as `CELL-METRICS`.

What the cells do NOT provide (yet):
- **Reactive constraint resolution**: A propagator from the trait-constraint cell to the resolution engine that fires when constraints appear — replacing the explicit `resolve-trait-constraints!` call in the driver
- **Automatic wakeup**: A propagator from the wakeup-registry cell to the constraint retry logic — replacing `retry-constraints-for-meta!`
- **Cross-domain constraint propagation**: Bridges from constraint cells to type/multiplicity/session domains

The hand-rolled machinery (explicit retry loops in `retry-constraints-for-meta!`, batch resolution in `resolve-trait-constraints!`) still does the actual work. Track 1 moved the *data* to cells but left the *control flow* unchanged.

### 6.2 Network-Everywhere Eliminates Write-Side Duality

Phase 6 resolved the parameter fallback concern from the original PIR. By making `with-fresh-meta-env` call `reset-meta-store!` (which creates the propagator network when callbacks are installed), every context that writes constraints has a network. The `if/else` at every write site is gone — replaced by a single cell write path. Writes without a network crash loud (`unbox` on `#f`), which is correct-by-construction: it surfaces programming errors immediately rather than silently falling back to a parameter that no reader checks.

Read functions retain guards that return empty defaults (`'()`, `(hasheq)`) when no cell exists. This handles the brief window during initialization and `reset-constraint-store!` transitions. This is semantically correct (no constraints exist pre-initialization), not a "fallback."

### 6.3 save-meta-state Captures Everything (Almost)

The prop-network box captured by `save-meta-state` includes all cell contents, making explicit per-parameter save/restore redundant — but only when the network is active. This validates the design of the speculation system: it was built to capture the network as a whole, not individual cells.

The "almost" is the parameter fallback: when no network exists, `save-meta-state` captures the box as `#f`, and restoring it to `#f` doesn't restore parameter state. The conditional save/restore in the speculation bridge handles this.

### 6.4 "Dirty Flags" Don't Exist

The design document's Phase 6b identified `current-retry-unify` and `current-retry-trait-resolve` as dirty flags to remove. They're not dirty flags — they're **dependency-injection callbacks** that break circular module dependencies (`metavar-store.rkt` → `unify.rkt`). They're a legitimate architectural pattern and will never be removed. The PIR initially conflated these with the retry machinery; this correction is important for future planning.

---

## 7. Forward Enablement

### 7.1 What Track 1 Actually Enables

Track 1 is a **prerequisite**, not a **deliverable**. It moved constraint data to cells, but the cells are inert. The value is that subsequent tracks can now wire propagator edges to these cells without touching the write sites.

Concretely, the constraint cells are now addressable by cell ID and live in the propagator network. A future track can call `net-add-propagator` with a constraint cell ID as input and some resolution logic as the propagator body. Before Track 1, this was impossible — constraint state lived in parameters, which are invisible to the propagator network.

### 7.2 Track 2: Reactive Constraint Resolution (The Real Prize)

The six existing cross-domain bridges use `net-add-cross-domain-propagator` to wire Galois connections between domains (type↔multiplicity, type↔session, etc.). Track 2 would add analogous bridges where constraint cells are inputs:

1. **Trait constraint cell → resolution propagator**: When a new trait constraint is written to the cell, a propagator attempts resolution. This replaces the explicit `resolve-trait-constraints!` call in the post-elaboration phase of the driver.
2. **Wakeup registry cell → retry propagator**: When a wakeup entry is added, a propagator checks if the referenced constraint can be retried. This replaces `retry-constraints-for-meta!` called explicitly from `solve-meta!`.
3. **Constraint store cell → constraint-status propagator**: When a constraint is added, a propagator checks if quiescence has already resolved it. This replaces the snapshot comparison in `unify.rkt`.

These would eliminate the manual retry loops and batch resolution passes, replacing them with propagator-driven incremental resolution. The constraint cells would become truly reactive rather than passive storage.

### 7.3 Track 4: ATMS Speculation (Medium-Term)

Cell-primary constraint tracking means speculation rollback is handled by the network snapshot. This is a prerequisite for ATMS-based multi-world speculation, where different constraint assumptions coexist in parallel worlds. With parameters, each world would need its own parameter save/restore; with cells, the ATMS dependency management handles this natively.

### 7.4 Test Fixture Modernization (COMPLETE — Phase 6)

Phase 6 made `with-fresh-meta-env` always create a propagator network by calling `reset-meta-store!`. All 10 test files and 2 benchmarks that lacked `driver.rkt` were updated. Unit tests now exercise the same cell-primary write path as production code — no behavioral divergence between test and production contexts.

---

## 8. Lessons Learned

### 8.1 Technical Lessons

1. **Ordering invariants need explicit documentation**: The `merge-list-append` → newest-at-tail vs `cons` → newest-at-head difference caused a bug. When migrating data structures, document the ordering contract at the write site AND the read site.

2. **`if/else` > `when` for migration writes**: Using `when (cell available)` for writes silently drops data when no cell exists. Using `if/else` with a fallback ensures writes always land somewhere. This is the same lesson as "fail loudly, not silently."

3. **Test fixtures are architecture too**: `with-fresh-meta-env` is infrastructure that 26 test files depend on. Changing its implicit contract (from "parameters are the only state" to "cells are primary") has ripple effects. Treating test fixtures as architectural decisions — not throwaway scaffolding — would have surfaced the fallback need earlier.

4. **Phase dependency analysis matters**: The original plan's phase ordering (4 before 5) was wrong. Quick dependency analysis (asking "what does Phase 4's removal assume?") during implementation caught this before wasted work. Design documents should include explicit dependency arrows, not just sequential numbering.

### 8.2 Process Lessons

1. **External critique paid off**: The design document incorporated critique from an outside review (added benchmarking protocol, dirty-flag removal guidance, mental-model questions). This led to the benchmarking infrastructure being in place before implementation started.

2. **The fallback pattern emerged from implementation, not design**: No amount of design review would have surfaced the `with-fresh-meta-env` issue — it required running the tests after write removal. This validates the staged implementation approach (flip reads → verify → remove writes → verify) over a big-bang migration.

3. **Mechanical migrations are fast when the pattern is established**: All 5 read accessors followed the same template. All 6 write conversions followed the same `if/else` pattern. Once the first one was done and tested, the rest were copy-paste with find-replace. Total implementation time: ~4 hours including all debugging.

---

## 9. Comparison with Prior PIRs

### vs. P-Unify PIR (2026-03-04)

P-Unify migrated unification from post-hoc observation to cell-driven. Track 1 migrates constraint *tracking* from parameters to cells. Both follow the same pattern: create a cell-primary read path, verify equivalence via dual-write, then remove the legacy path. P-Unify had the additional complexity of quiescence flushes; Track 1's complexity was in the fallback pattern for test fixtures.

### vs. First-Class Traits PIR (2026-03-09)

First-Class Traits was a *feature* track (new AST nodes, new syntax, new semantics). Track 1 is a *migration* track (same semantics, different implementation). Migration tracks are inherently lower-risk but require more careful attention to behavioral equivalence. The 0 production-test regressions confirm this.

### Recurring theme across PIRs

The propagator network continues to validate as a data substrate. But Track 1 reveals a distinction previous PIRs glossed over: **data on cells ≠ reactive propagation**. Session types, unification, and narrowing all landed on cells AND wired propagator edges for reactive behavior. Track 1 landed constraint data on cells but left the control flow (retry loops, batch resolution) unchanged. The cells are passive storage, not reactive participants.

This is the honest state: we're building the foundation, not the building.

---

## 10. Conclusion

Track 1 is infrastructure, not capability. It moved constraint data from parameters to cells, which is a necessary precondition for reactive constraint resolution (Track 2) and ATMS multi-world speculation (Track 4). But the cells are inert — nothing watches them, no propagator fires when they change. The manual retry loops and batch resolution passes remain the actual resolution machinery.

What we gained concretely:
1. **Unified read API** — 6 accessors that abstract over cell-vs-parameter
2. **Transactional rollback for free** — speculation captures constraint state via the network snapshot
3. **Addressable constraint state** — cells have IDs, live in the network, can have propagators wired to them in future tracks
4. **Performance validation** — cell reads are cost-free (+1.2% = noise), green-lighting future migration tracks

What we did not gain:
1. **Reactive resolution** — constraints are still resolved by explicit call chains, not by propagator firing
2. **Cross-domain composition** — no new bridges exist; the constraint cells are isolated from type/session/multiplicity domains
3. **Observability** — the Observatory can see meta cells, but constraint cells aren't visualized or traced

The key lesson: **moving data to cells is table stakes, not the endgame**. The value comes from wiring propagator edges to those cells — which is Track 2's job. Track 1 laid the pipe; Track 2 turns on the water.
