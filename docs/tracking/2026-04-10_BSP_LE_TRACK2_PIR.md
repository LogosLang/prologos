# BSP-LE Track 2: ATMS Solver + Cell-Based TMS — Post-Implementation Review

**Date**: 2026-04-10
**Duration**: ~20h across 2 sessions (Apr 9-10)
**Commits**: 46 (from `bc14289f` through `1ccff0b9`)
**Test delta**: 7660 → 7745 (+85 tests, 17 new propagator solver tests, 25 architecture tests, 19 solver-context tests, others)
**Suite health**: 397/397 files, 7745 tests, ~126s, all pass
**Design docs**: `docs/tracking/2026-04-07_BSP_LE_TRACK2_DESIGN.md` (D.13, ~2000 lines)

---

## 1. What Was Built

A propagator-native logic solver that replaces the DFS backtracking solver with concurrent, order-independent clause execution on a propagator network. The solver uses BSP (Bulk Synchronous Parallel) scheduling to fire all clause propagators concurrently, with per-propagator worldview bitmasks providing branch isolation via tagged-cell-values.

Key deliverables across 12 phases (0-11):
- **Tagged-cell-value**: bitmask-tagged speculative writes with O(1) commit (worldview cache persistence) and O(1) retract (bit clear). Replaces TMS tree entirely.
- **Compound cells**: decisions-state (merge-maintained bitmask), commitments-state, scope-cell (one per variable scope). Reduces cell allocation dramatically.
- **Solver-context**: replaces ATMS struct. Phone book of cell-ids — no second source of truth.
- **Propagator-native solver**: install-goal-propagator (5 types), install-conjunction, install-clause-propagators, concurrent multi-clause via per-propagator worldview bitmask.
- **On-network tabling**: table registry as a cell, producer/consumer propagators, one-true-tabling, completion emergent from BSP fixpoint.
- **Unified speculation**: `current-speculation-stack` RETIRED. Single mechanism (tagged-cell-value + worldview cache). O(1) commit/retract vs O(cells) TMS fold.

## 2. Timeline and Phases

| Phase | Description | Commits | Key Decision |
|---|---|---|---|
| 4 | Bitmask-tagged cell values | 3 | Tagged-cell-value replaces TMS tree |
| 5 | ATMS dissolution + compound cells | 19 | Compound decisions cell — merge IS the fan-in |
| 6+7 | Propagator-native solver | ~15 | Merged phases (mutual recursion). Concurrent multi-clause via per-propagator worldview |
| 8 | On-network tabling | 4 | Scope cells, registry cell, one-true-tabling |
| 9 | Strategy dispatch + parameter migration | 5 | :atms routes to propagator. TMS removal reverted (9b-4) |
| 10 | Solver config wiring | 1 | :execution, :tabling, :timeout knobs |
| 11 | Unified speculation | 4 | Root cause found: TMS nesting. Tagged-only. O(1) commit/retract |

Design-to-implementation ratio: ~30% design conversation, ~70% implementation. Design conversations preceded Phases 5, 6+7, 8, and 11.

## 3. Test Coverage

- `test-tagged-cell-value.rkt`: 36 tests (Phase 4)
- `test-solver-context.rkt`: 25 tests (Phase 5)
- `test-propagator-solver.rkt`: 17 tests (Phase 6+7+8)
- `test-branch-pu.rkt`: 9 tests (Phase 6a additions)
- Migrated: test-atms-types (37), test-elab-speculation (18), test-infra-cell-atms-01 (21), test-capability-05b (24)

Gaps: no dedicated test for same-specificity merge in tagged-cell-read (tested indirectly via union types). No parity test running DFS vs propagator on same inputs.

## 4. Bugs Found and Fixed

1. **next-cell-id not bumped** (Phase 4b): worldview cache cell pre-allocated at cell-id 1, but next-cell-id stayed at 1. Branch PU test collided. Fix: bump to 2.

2. **BSP fire-and-collect-writes used net-cell-read** (Phase 6+7): worldview-filtered reads made tagged entries invisible to the snapshot/result diff. Writes silently dropped. Fix: use net-cell-read-raw.

3. **promote-cell-to-tagged didn't update merge function** (Phase 6+7): original merge (e.g., logic-var-merge) destroyed tagged entries during merge. Fix: wrap with make-tagged-merge.

4. **Tagged-cell-value entry ordering** (Phase 5.9): old entries before new → wrong value returned at same specificity. Fix: prepend new entries.

5. **TMS nesting hid tagged path** (Phase 11): promote-cell-to-tms AFTER promote-cell-to-tagged created `(tms-cell-value (tagged-cell-value ...))`. net-cell-read dispatched on outer type. Root cause of Phase 9b-4 regression.

6. **Worldview cache replacement vs OR** (Phase 11): right branch's write replaced left's bit. Fix: write combined bitmask (OR of both).

7. **Same-specificity entries not merged** (Phase 11): tagged-cell-read returned first match. Union types need merge of co-committed branches. Fix: collect all matches at max popcount, merge via domain-merge.

## 5. Design Decisions and Rationale

| Decision | Rationale | Principle |
|---|---|---|
| Compound decisions cell (merge-maintained bitmask) | The merge IS the fan-in — no micro-propagators, no centralized aggregator | Propagator-First, Data Orientation |
| One-true-tabling | Cost negligible (one cell per relation). Completion emergent from BSP. | Completeness |
| Per-propagator worldview bitmask | Enables concurrent clause execution on same network. BSP fires all. | All-at-once, Decomplection |
| Worldview cache persistence IS commit | O(1) vs O(cells). Information flow, not imperative fold. | Correct-by-Construction |
| current-speculation-stack RETIRED | One mechanism. Improvements benefit everything. | Completeness, Decomplection |
| Scope cells (one per scope, not per variable) | Table entries ARE scope cells. Reduces M×K to M cells. | Cell Allocation Efficiency |

## 6. Lessons Learned

1. **The nesting order matters**: `promote-cell-to-tms(promote-cell-to-tagged(x))` hides the tagged path. The outer struct type determines net-cell-read dispatch. Always promote to the NEWER mechanism LAST — or don't dual-promote at all.

2. **Worldview cache replacement merge requires combined writes**: sequential writes with replacement merge lose earlier bits. When multiple branches are both active, the write must OR all active bits.

3. **Same-specificity entries need merging, not picking**: in the solver, entries at same specificity are alternatives (pick one). In elaboration, they can be co-committed truths (merge all). The domain-merge from the cell's merge-fn handles this.

4. **fire-and-collect-writes must use raw reads**: worldview filtering in reads makes tagged entries invisible to the BSP diff. This is a correctness-critical invariant for concurrent tagged-cell-value execution.

5. **Full suite is NOT a diagnostic tool**: 5+ instances of re-running the full suite for diagnostics. Each costs ~130s. Read failure logs. Run individual tests. Added to rules.

6. **check-parens.sh before raco make**: eliminates bracket-balancing trial-and-error. Instant (~100ms). Added to rules.

## 7. Metrics

| Metric | Value |
|---|---|
| Total commits | 46 |
| Files modified | ~15 source + ~10 test |
| New test files | 3 (test-tagged-cell-value, test-solver-context, test-propagator-solver) |
| Test delta | +85 |
| Suite time | ~126s (was ~130s baseline) |
| A/B regression | 13/15 programs: no significant change. 2 flagged (church-folds -10.9%, pattern-matching -8.3%) but with high CV (17.7%, 29.2%), likely measurement noise. Adversarial benchmarks: 0% change. |
| Acceptance criterion | <15% regression: MET |

## 8. What's Next

**Immediate**:
- `:auto` → propagator switch once DFS↔propagator parity validated
- TMS dead code removal (definitions, ~200 lines in propagator.rkt)
- Inert-dependent data review

**Medium-term**:
- PPN Track 4C: elab-network dissolution (meta-info, constraint store, id-map → cells). Eliminates snapshot/restore scaffolding.
- BSP-LE Track 3: left-recursive tabling (SLG completion frames)

**Long-term**:
- All compiler registries (module, relation, trait) as cells. Self-hosting path.
- `:auto` = parallel propagator solver as default for all queries

## 9. Key Files

| File | Role |
|---|---|
| `decision-cell.rkt` | tagged-cell-value, decisions-state, commitments-state, scope-cell |
| `propagator.rkt` | worldview cache, fire-once, broadcast, promote-cell-to-tagged, current-worldview-bitmask |
| `atms.rkt` | solver-context, solver-state, table operations |
| `relations.rkt` | Propagator-native solver (install-goal-propagator, install-clause-propagators, scope cells, tabling) |
| `elab-speculation-bridge.rkt` | Unified speculation (worldview cache commit/retract) |
| `typing-propagators.rkt` | Union branching (tagged-only, no TMS) |
| `stratified-eval.rkt` | :strategy dispatch |

## 10. Lessons Distilled

| Lesson | Distilled To | Status |
|---|---|---|
| Fire-once for single-output propagators | `.claude/rules/propagator-design.md` | Done |
| Broadcast for independent items | `.claude/rules/propagator-design.md` | Done |
| Component-indexing mandatory for compound cells | `.claude/rules/propagator-design.md` | Done |
| Per-propagator worldview bitmask pattern | `.claude/rules/propagator-design.md` | Done |
| SRE lattice lens (6 questions) | `.claude/rules/structural-thinking.md` | Done |
| Hasse diagram optimality argument | `.claude/rules/structural-thinking.md` | Done |
| On-network self-hosting mandate | `.claude/rules/on-network.md` | Done |
| Diagnostic protocol (trigger-level intervention) | `.claude/rules/testing.md` | Done |
| check-parens.sh after .rkt edits | `.claude/rules/testing.md` | Done |
| fire-and-collect-writes must use raw reads | `.claude/rules/propagator-design.md` | Pending — add as CRITICAL note |
| Same-specificity merge in tagged-cell-read | Design doc §11.1 | Captured in D.13 |
| Worldview cache combined bitmask for co-committed branches | Design doc §11.1 | Captured in D.13 |
