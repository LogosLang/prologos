# Track 1: Constraint Cell-Primary — Post-Implementation Review

**Date**: 2026-03-12 / 2026-03-13
**Commits**: `ffc5d26` through `2c95a9d` (7 commits)
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

**Phases 0-5 completed. Phase 6 partially deferred.**

The core goal was achieved: all constraint reads go through cell-primary accessors, and all writes are cell-primary when a propagator network is active. The key deviation from the original plan was the emergence of a **parameter fallback** pattern — unit tests that use `with-fresh-meta-env` don't create a propagator network, so both reads and writes must fall back to parameters when no network exists.

This means Phase 6 (parameter removal) can't proceed as originally designed. The parameters stay as lightweight fallback storage for the test harness. This is the correct architecture, not a compromise — it mirrors how the read accessors were already designed (`read-constraint-store` always had a parameter fallback).

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

2. **Cell-primary write paths**: All 6 constraint write functions (`add-constraint!`, `register-trait-constraint!`, `register-hasmethod-constraint!`, `register-capability-constraint!`, plus wakeup registry writes) now use `if/else` instead of `when` — cell path when network is active, parameter fallback when not.

3. **Cell metrics emission**: `CELL-METRICS` JSON lines emitted to stderr alongside existing `PERF-COUNTERS`/`PHASE-TIMINGS`/`MEMORY-STATS`, extracted by batch-worker. Provides cells/propagators counts per test file.

4. **Conditional speculation save/restore**: `with-speculative-rollback` only saves/restores the constraint parameter when no propagator network is active. When the network IS active, `save-meta-state`/`restore-meta-state!` handles rollback via the network box.

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

**Impact**: Phase 6a-6c deferred. The parameters remain as fallback storage, adding ~15 lines of dead-ish code in the production path.

**Root cause**: The `with-fresh-meta-env` macro was designed before the propagator infrastructure existed. It creates a clean slate for meta variables but doesn't create a network. This is correct for unit tests that test meta variable mechanics in isolation, but it means constraint writes have no cell to target.

**Resolution path**: A future track could add a `with-fresh-meta-env/network` variant that creates both clean meta state AND a minimal propagator network. This would let unit tests exercise the cell-primary path and enable full parameter removal.

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

**Expected**: Phases 0-6 complete. **Actual**: Phases 0-5 complete, Phase 6 partially deferred.

The 85% completion is appropriate. The deferred work (full parameter removal) is blocked on test fixture migration, which is a different kind of work than the core migration. Forcing it would have created churn in ~26 test files without improving correctness or performance.

### 5.3 Performance

**Expected**: No regression (Pipeline Audit predicted O(1) cell reads). **Actual**: +1.2% (within noise).

Confirmed: cell reads via CHAMP lookup are not measurably slower than parameter reads. This is the green light for all subsequent migration tracks — the read-flip pattern is cost-free.

---

## 6. Architectural Validation

### 6.1 Cell-Primary-with-Fallback Is the Right Pattern

The original plan assumed a binary transition: parameters → cells, then delete parameters. Reality revealed a third state: **cell-primary with parameter fallback**. This is more robust because:

1. It's backwards-compatible with test harnesses that don't create networks
2. It fails gracefully (parameter fallback) rather than silently (returning `'()` when no cell exists)
3. It makes the migration incremental — each read/write site can be flipped independently

This pattern should be the template for all future migration tracks.

### 6.2 save-meta-state Captures Everything (Almost)

The prop-network box captured by `save-meta-state` includes all cell contents, making explicit per-parameter save/restore redundant — but only when the network is active. This validates the design of the speculation system: it was built to capture the network as a whole, not individual cells.

The "almost" is the parameter fallback: when no network exists, `save-meta-state` captures the box as `#f`, and restoring it to `#f` doesn't restore parameter state. The conditional save/restore in the speculation bridge handles this correctly.

### 6.3 Propagator Network as Universal State Substrate

Track 1 adds evidence to the recurring theme: the propagator network can subsume parameter-based state management. The wakeup registries, constraint stores, and trait/hasmethod/capability maps were all hand-rolled dependency tracking. With cells as the primary store, the network's built-in dependency tracking (propagator edges, quiescence-driven updates) can replace the manual machinery.

The remaining manual machinery — dirty flags, explicit retry loops — are candidates for Track 2+ once the cross-domain propagator wiring is in place.

---

## 7. Forward Enablement

### 7.1 Track 2: Cross-Domain Propagator Wiring (Immediate)

With constraint state on cells, the six existing cross-domain bridges (type↔multiplicity, type↔session, etc.) can be extended to include constraint domains. A trait constraint cell changing value can trigger propagation in the type domain — enabling automatic constraint resolution without the polling retry loop.

### 7.2 Track 4: ATMS Speculation (Medium-Term)

Cell-primary constraint tracking means speculation rollback is handled by the network snapshot. This is a prerequisite for ATMS-based multi-world speculation, where different constraint assumptions coexist in parallel worlds. With parameters, each world would need its own parameter save/restore; with cells, the ATMS dependency management handles this natively.

### 7.3 Test Fixture Modernization (Future)

Creating a `with-fresh-meta-env/network` macro that includes a minimal propagator network would:
- Enable full parameter removal (Phase 6a-6c)
- Let unit tests validate cell-primary paths directly
- Align test behavior with production behavior (reducing "works in tests, broken in driver" gaps)

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

The propagator network continues to validate as a universal substrate. Each migration track adds evidence: session types (3/4), unification (3/4), narrowing (3/8), constraint tracking (3/12) all landed on cells as the single source of truth. The remaining parameter-based state is shrinking.

---

## 10. Conclusion

Track 1 achieved its primary goal: constraint state is now cell-primary. The deviation from full parameter removal is architecturally sound — the fallback pattern is more robust than the original all-or-nothing design. Performance is unchanged, correctness is maintained across all 6889 tests, and the work enables Tracks 2-4 of the propagator migration roadmap.

The key takeaway: **migration tracks should plan for coexistence, not replacement**. The cell-primary-with-fallback pattern is the right intermediate state, and it may be the right *final* state — the fallback adds negligible complexity while providing resilience for contexts (test fixtures, REPL, future tooling) that don't warrant a full propagator network.
