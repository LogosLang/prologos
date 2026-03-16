# Track 4: ATMS Speculation

**Created**: 2026-03-16
**Status**: DESIGN (Stage 2/3)
**Depends on**: Track 3 (Cell-Primary Registries) — ✅ COMPLETE
**Enables**: Track 5 (Global-Env + Dependency Edges), Track 9 (GDE)
**Research basis**: `2026-03-11_WHOLE_SYSTEM_PROPAGATOR_MIGRATION.md` §2.3 (Dependency-Directed Backjumping), `2026-02-24_LOGIC_ENGINE_DESIGN.md` §5 (ATMS Integration)
**Prior implementation**: Migration Sprint Phase 0b (ATMS infrastructure), Phase 4a–4e (speculation audit + ATMS mandatory)
**Master roadmap**: `2026-03-13_PROPAGATOR_MIGRATION_MASTER.md` Track 4

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| D.1 | Design analysis and speculation audit | ✅ | This document |
| D.2 | Design iteration (external critique) | ⬜ | |
| D.3 | Internal self-critique (principle alignment) | ⬜ | |
| 0 | Performance baseline + acceptance file | ⬜ | |
| 1 | Meta-info CHAMP → network cell | ⬜ | |
| 2 | Level/mult/session CHAMPs → network cells | ⬜ | |
| 3 | Replace save/restore with network-only snapshot | ⬜ | |
| 4 | ATMS assumption-tagged speculation | ⬜ | |
| 5 | Learned-clause integration (nogood reuse) | ⬜ | |
| 6 | Performance validation + cleanup | ⬜ | |
| 7 | Post-Implementation Review | ⬜ | |

---

## §1. Context

### 1.1 What Exists

Two parallel speculation mechanisms exist in the codebase:

**Mechanism A: Imperative bridge** (`elab-speculation-bridge.rkt`)
- `with-speculative-rollback` wraps a thunk in save/restore
- `save-meta-state` snapshots 6 immutable CHAMP references (network, id-map, meta-info, level-meta, mult-meta, sess-meta) — O(1) via structural sharing
- `restore-meta-state!` swaps box references back — O(1)
- Phase D added ATMS hypothesis creation per speculation, but only for error tracking (nogoods recorded on failure)
- **This is the active mechanism**: 6 call sites (4 `typing-core.rkt`, 1 `qtt.rkt`, 1 `typing-errors.rkt`)

**Mechanism B: Network-level speculation** (`elab-speculation.rkt`)
- `speculation-begin` forks the elab-network per alternative, creates ATMS `amb` group
- `speculation-try-branch` applies elaboration on a forked network, detects contradiction
- `speculation-commit` picks the first successful branch
- Full ATMS integration (assumptions, nogoods, mutual exclusion)
- **Not used by the type checker** — available infrastructure from Migration Sprint Phase 4

**The gap**: Mechanism A uses ATMS only for error tracking, not for state management. The 6-box snapshot is the actual rollback mechanism. Mechanism B has full ATMS-backed state management, but operates on `elab-network`, not on the metavar store.

### 1.2 What This Track Does

Unify Mechanisms A and B: make the propagator network the single snapshot target for speculation, and make ATMS assumptions the structural mechanism for rollback instead of imperative save/restore.

Concretely:
1. Move meta-info, level-meta, mult-meta, and sess-meta from standalone CHAMP boxes into propagator network cells
2. Reduce `save-meta-state` from 6 boxes to 1 (network only)
3. Make ATMS assumption retraction the rollback mechanism (retract assumption → cell values revert to pre-assumption state)

### 1.3 Why This Matters

**Fragility elimination**: The 6-box snapshot pattern requires updating `save-meta-state`/`restore-meta-state!` whenever new mutable state is added. Track 1 Phase B added level/mult/session CHAMPs after discovering speculation leaks. Every new kind of state risks the same bug. Moving all state into network cells makes the network snapshot the single point of truth.

**Learned clauses**: Currently, when speculation fails, the failure is recorded but the type checker can re-explore the same dead branch in a different context. With ATMS nogoods as permanent learned clauses, the same assumption combination is never re-tried — pruning the speculation tree.

**GDE foundation**: Track 9 (General Diagnostic Engine) requires multi-hypothesis conflict analysis via ATMS. This requires speculation state to be ATMS-managed, not imperatively managed. Track 4 is the prerequisite.

---

## §2. Speculation Audit

### 2.1 Call Sites

| # | File | Line | Label | Thunk | Success? | Context |
|---|------|------|-------|-------|----------|---------|
| 1 | `typing-core.rkt` | 1198 | `"map-value-widening"` | `(check ctx v vt)` | `values` | Map value fits existing type? |
| 2 | `typing-core.rkt` | 1284 | `"union-map-get-component"` | `(check ctx k ...)` | `values` | Key matches union map component? |
| 3 | `typing-core.rkt` | 1318 | `"union-nil-safe-get-component"` | `(check ctx k ...)` | `values` | Key matches nil-safe map component? |
| 4 | `typing-core.rkt` | 2432 | `"union-check-left"` | `(check ctx e l)` | `values` | Expression checks against union left? |
| 5 | `qtt.rkt` | 2348 | `"union-checkQ-left"` | `(checkQ ctx e l)` | Custom `bu-ok?` | QTT check against union left? |
| 6 | `typing-errors.rkt` | 78 | `"union-branch-N"` | `(check ctx e br)` | `values` | Per-branch error enrichment |

**Pattern**: All 6 sites use the same structure: `(with-speculative-rollback thunk success? label)`. The thunk runs `check`/`checkQ`/`infer` which mutate meta-state imperatively. On failure, state is restored. On success, mutations persist.

**Call site #6** (`typing-errors.rkt`) is special: it's error enrichment, not type-checking logic. It speculatively checks each union branch to produce per-branch mismatch details. This is read-only from a type-checking perspective — the overall check has already failed.

### 2.2 State Captured by save-meta-state

| # | Parameter | CHAMP Box | Content | Purpose |
|---|-----------|-----------|---------|---------|
| 1 | `current-prop-net-box` | network | `prop-network` | All propagator cells (constraints, registries, wakeups, etc.) |
| 2 | `current-prop-id-map-box` | id-map | `hasheq(meta-id → cell-id)` | Maps meta-ids to constraint cell-ids |
| 3 | `current-prop-meta-info-box` | meta-info | `CHAMP(meta-id → meta-info)` | Primary metavar store: type, status, solution |
| 4 | `current-level-meta-champ-box` | level-meta | `CHAMP(id → solution)` | Universe level metavariables |
| 5 | `current-mult-meta-champ-box` | mult-meta | `CHAMP(id → solution)` | Multiplicity metavariables |
| 6 | `current-sess-meta-champ-box` | sess-meta | `CHAMP(id → solution)` | Session type metavariables |

**Observation**: Box #1 (the network) already captures all constraint and registry state thanks to Tracks 1–3. Boxes #3–6 are the metavar stores — the remaining state that lives outside the network. Box #2 is a lookup index.

### 2.3 Existing ATMS Infrastructure

From Migration Sprint Phase 0b (`atms.rkt`, `infra-cell.rkt`):

| Component | Status | Notes |
|-----------|--------|-------|
| `atms` struct (assumptions, nogoods, believed, amb-groups) | ✅ Ready | Pure value semantics |
| `atms-assume` / `atms-retract` | ✅ Ready | Assumption lifecycle |
| `atms-add-nogood` / `atms-consistent?` | ✅ Ready | Consistency checking |
| `atms-amb` (mutual exclusion) | ✅ Ready | Choice point groups |
| `atms-with-worldview` | ✅ Ready | Worldview switching |
| `atms-read-cell` / `atms-write-cell` (TMS cells) | ✅ Ready | Assumption-tagged I/O |
| `infra-assume` / `infra-retract` / `infra-commit` | ✅ Ready | Bridge API |
| `infra-write-assumed` / `infra-read-believed` | ✅ Ready | TMS cell I/O through infra-state |
| `speculation-begin` / `speculation-try-branch` / `speculation-commit` | ✅ Ready | Network-level speculation |

**Key property**: All ATMS operations are pure (return new ATMS, never mutate). This is the structural foundation for eliminating imperative save/restore.

### 2.4 What's NOT in the Network

The following state participates in speculation but lives outside the propagator network:

1. **Meta-info CHAMP** — the primary metavar store. `infer`/`check` call `fresh-meta!` (creates metas) and `solve-meta!` (solves metas) which mutate this CHAMP via box writes. This is the most-mutated state during type-checking.

2. **Level/mult/session CHAMPs** — auxiliary metavar stores for universe levels, multiplicities, and session types. Lower traffic than meta-info but must be included in speculation.

3. **ID-map CHAMP** — maps meta-ids to cell-ids. Grows monotonically as metas are created. Less critical for speculation correctness (monotonic → no rollback needed).

---

## §3. Design

### 3.1 Architectural Options

**Option A: Move CHAMPs into network cells**

Move meta-info, level-meta, mult-meta, and sess-meta into propagator cells with appropriate merge functions. All metavar operations (`fresh-meta!`, `solve-meta!`, etc.) write through the cell API.

- Pro: Network snapshot captures everything — save/restore becomes `(unbox net-box)` / `(set-box! net-box saved-net)`
- Pro: ATMS assumption-tagging comes naturally (TMS cells)
- Con: Every metavar read/write pays cell lookup overhead
- Con: Merge function for meta-info is complex (solve-meta writes to a specific key in a CHAMP — not a standard lattice merge)
- Risk: Meta-info writes are the highest-frequency operation in the type checker

**Option B: Keep CHAMPs, make save/restore assumption-aware**

Keep meta-info, level-meta, mult-meta, sess-meta as standalone CHAMPs. Make ATMS track which CHAMP "version" is associated with each assumption. Retraction restores the CHAMP to its pre-assumption state.

- Pro: No change to hot-path metavar operations
- Pro: CHAMP structural sharing already gives O(1) snapshots
- Con: Still requires explicit save/restore for CHAMPs (just associated with assumptions instead of managed manually)
- Con: Doesn't reduce the save/restore surface area

**Option C: Hybrid — network cells for monotonic state, CHAMPs for non-monotonic**

Move id-map (monotonic) into the network. Keep meta-info, level, mult, sess as CHAMPs (non-monotonic — solving a meta overwrites its entry). Reduce save/restore from 6 boxes to 5 (network + 4 CHAMPs), but structurally tag the CHAMP snapshots with ATMS assumptions.

- Pro: Monotonic state gets full propagator treatment
- Con: Still has 5-box save/restore
- Con: Doesn't achieve the "single snapshot target" goal

### 3.2 Recommended Approach: Option A (Network Cells)

✓ DESIGN DECISION

Option A is the correct long-term architecture, despite the short-term cost. Rationale:

1. **Propagator-first principle**: "Every piece of mutable state that participates in type-checking flows through one unified propagator network" (Master Roadmap vision statement). Options B and C leave the most-important state (meta-info) outside the network.

2. **Fragility elimination**: Option A reduces save/restore to 1 box (network). Options B and C reduce to 5. The "whenever new state is added" failure mode persists with B and C.

3. **ATMS-backed speculation becomes structural**: With meta-info in cells, TMS-cell writes automatically associate values with assumptions. Retraction is built into the cell read mechanism — no imperative restore needed.

4. **Performance mitigation**: The cell lookup overhead is mitigatable. Meta-info reads are hot, but cell reads are O(1) CHAMP lookups (the network's cell store is a CHAMP). The additional indirection is: `(unbox net-box)` → `champ-ref cells cell-id` → `prop-cell-value` instead of `(unbox meta-info-box)` → `champ-ref`. One extra CHAMP hop. Profile before/after to quantify.

5. **Precedent**: Track 1 moved constraint state into cells (also high-frequency reads). Performance impact was within noise (194.3s → 197.6s for all of Track 3). Meta-info operations are higher frequency but the same O(1) CHAMP access pattern applies.

### 3.3 Cell Design for Metavar State

#### 3.3.1 Meta-Info Cell

**Content**: CHAMP mapping `meta-id → meta-info`.

**Merge function**: `merge-meta-info-champ` — per-key last-write-wins with a constraint: once a meta is solved, it stays solved (monotonic for `status: unsolved → solved`, non-monotonic for the CHAMP itself since new metas are added).

```
(define (merge-meta-info-champ old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [else
     ;; Per-key merge: new overwrites old for each key in new
     (for/fold ([acc old]) ([(k v) (in-champ new)])
       (champ-set acc k v))]))
```

**Why per-key last-write-wins**: `solve-meta!` writes a single key (`meta-id → updated-meta-info`). The cell merge must apply this to the full CHAMP. This is equivalent to `merge-hasheq-union` but for CHAMPs, with overwrite semantics instead of union.

**Important**: During speculation, the thunk may create new metas (`fresh-meta!`) and solve existing metas (`solve-meta!`). On failure, both operations must be rolled back. With ATMS assumption-tagged writes, the new metas and solutions are associated with the speculation's assumption. On retraction, they become invisible.

#### 3.3.2 Level/Mult/Session Cells

**Content**: CHAMP mapping `id → 'unsolved | solution`.

**Merge function**: Same `merge-champ-last-write-wins` pattern — each solve writes one key.

These three cells are structurally identical, differing only in which CHAMP they wrap.

#### 3.3.3 ID-Map Cell

**Content**: CHAMP mapping `meta-id → cell-id`.

**Merge function**: `merge-champ-union` — monotonic (IDs are only added, never removed).

This cell is simpler because it's monotonic — no overwrite needed.

### 3.4 Speculation Rewrite

The new `with-speculative-rollback` would:

```
;; Pseudocode — design sketch, not final implementation
(define (with-speculative-rollback thunk success? label)
  (perf-inc-speculation!)
  ;; 1. Create ATMS assumption (as today)
  (define-values (_a* hyp-id) (atms-assume ...))
  ;; 2. Set current-infra-assumption for the duration of the thunk
  ;;    All cell writes during thunk are tagged with this assumption
  (define saved-net (unbox (current-prop-net-box)))
  (define result
    (parameterize ([current-infra-assumption hyp-id])
      (thunk)))
  (cond
    [(success? result)
     ;; Commit: assumption stays believed, writes are permanent
     result]
    [else
     ;; Retract: assumption removed from believed
     ;; Restore network to pre-speculation state
     (set-box! (current-prop-net-box) saved-net)
     ;; Record failure (as today)
     (record-speculation-failure! label hyp-id ...)
     #f]))
```

**Critical point**: Even with ATMS assumption-tagged writes, we still save/restore the network box. This is because the propagator network's monotonic cells (constraints, registries) don't use TMS — they use direct merge. The ATMS TMS cells are a separate layer.

**Design question — OPEN**: Should we convert the meta-info cell to a TMS cell (ATMS-aware, with assumption-tagged values) or a monotonic cell (standard merge, with box-level save/restore)?

- **TMS cell**: Full ATMS retraction. But TMS cells store `(listof supported-value)` — a list of values tagged with assumption sets. Reading requires filtering by believed assumptions. This changes the read path for EVERY metavar lookup.
- **Monotonic cell**: Standard merge, no assumption tags. Save/restore still needed for the network, but it's just 1 box. Simpler, but doesn't get full ATMS retraction benefits.

✓ DESIGN DECISION: **Monotonic cell** for Phase 1–3. TMS conversion is Phase 4+ and may be deferred to Track 5.

Rationale: The primary goal of Track 4 is to eliminate the 6-box fragility and bring metavar state into the network. Full TMS cells for meta-info would change every metavar read path — a much higher risk change. The network-cell approach achieves the consolidation goal. TMS assumption-tagging can be layered on later when the GDE track (Track 9) has clearer requirements.

### 3.5 Phase Structure

#### Phase 0: Performance Baseline + Acceptance File

- Acceptance file: `examples/2026-03-16-track4-acceptance.prologos` covering speculation-exercising patterns (union types, map widening, Church folds)
- Baseline: full suite timing, cell count metrics
- Pre-flight: verify all 6 call sites with grep, confirm no new ones since Track 3

#### Phase 1: Meta-Info CHAMP → Network Cell

**Scope**: Move `current-prop-meta-info-box` into the propagator network as a cell.

**Files**: `metavar-store.rkt`, `infra-cell.rkt`

1. Add `merge-meta-info-champ` merge function to `infra-cell.rkt`
2. Add `current-meta-info-cell-id` parameter to `metavar-store.rkt`
3. Create meta-info cell in `reset-meta-store!` (or `register-meta-cells!`)
4. Add cell-primary reader: `read-meta-info` — reads from cell during elaboration, parameter fallback otherwise (same pattern as Track 3's elaboration guard)
5. Add cell writer: metavar operations (`fresh-meta!`, `solve-meta!`, `unsolve-meta!`, etc.) write to both cell and CHAMP box (dual-write, as in Track 3's transitional pattern)
6. Update `save-meta-state` to exclude meta-info from the explicit snapshot (it's now in the network, captured by the network box snapshot)

**Risk**: This is the highest-risk phase. Meta-info reads are the most frequent operation in the type checker. Instrument before/after to detect performance regression.

**Verification**: Full suite must pass with 0 regressions. Performance within 10% of baseline.

#### Phase 2: Level/Mult/Session CHAMPs → Network Cells

**Scope**: Move `current-level-meta-champ-box`, `current-mult-meta-champ-box`, `current-sess-meta-champ-box` into the propagator network.

**Files**: `metavar-store.rkt`, `infra-cell.rkt`

Same pattern as Phase 1, applied three times. These are lower-traffic than meta-info, so performance risk is lower.

**After Phase 2**: `save-meta-state` captures only 2 boxes: network + id-map. Down from 6.

#### Phase 3: ID-Map → Network Cell + Simplify save/restore

**Scope**: Move `current-prop-id-map-box` into the network. Simplify `save-meta-state` / `restore-meta-state!` to single-box operations.

**Files**: `metavar-store.rkt`, `elab-speculation-bridge.rkt`

After this phase:
- `save-meta-state` = `(unbox (current-prop-net-box))` — a single reference copy
- `restore-meta-state!` = `(set-box! (current-prop-net-box) saved)` — a single reference swap
- The 6-box fragility is eliminated

#### Phase 4: ATMS Assumption-Tagged Speculation (Design Decision Point)

**Scope**: Make speculation writes go through ATMS TMS cells instead of monotonic cells. On failure, assumption retraction automatically hides the speculative writes.

**THIS PHASE IS CONDITIONAL**: Only proceed if Phases 1–3 demonstrate that the cell-based meta-info path is performant and stable. If not, Phases 1–3 alone still deliver significant value (6-box → 1-box consolidation).

**Design sketch**: Convert meta-info cell from monotonic to TMS. All `fresh-meta!` and `solve-meta!` calls write through `infra-write-assumed` with the current speculation's assumption-id. `read-meta-info` uses `infra-read-believed` to see only values under the current worldview.

**If deferred**: The 1-box save/restore from Phase 3 is already a major improvement. ATMS-tagged speculation can wait for Track 9 (GDE) to clarify requirements.

#### Phase 5: Learned-Clause Integration

**Scope**: When speculation fails and a nogood is recorded, reuse the nogood to prune future speculations. Currently, nogoods are recorded but only used for error messages.

**THIS PHASE IS CONDITIONAL on Phase 4**: Without TMS-backed meta-info, nogoods can't structurally prevent re-exploration. With TMS cells, a retracted assumption makes its writes invisible, and the ATMS consistency check prevents re-believing the same assumption combination.

**If deferred**: The existing nogood recording for error messages is sufficient.

#### Phase 6: Performance Validation + Cleanup

- Full suite timing comparison against baseline
- Remove any vestigial dual-write paths
- Update PIR process doc references
- Clean up temporary instrumentation

#### Phase 7: Post-Implementation Review

Standalone PIR document following the established template.

### 3.6 Two-Context Architecture Impact

Track 3 established the two-context architecture: elaboration reads cells, module loading reads parameters. This applies to Track 4:

- **Meta-info reads during elaboration**: Go through the cell (network cell read)
- **Meta-info reads during module loading**: Fall back to the CHAMP box (parameter)

The elaboration guard pattern (`current-macros-in-elaboration?`) is NOT needed for meta-info because meta-info is always read during elaboration (type-checking happens inside `process-command`). Module loading doesn't read meta-info — it creates definitions, not metavariables.

**Exception**: `all-unsolved-metas` (used by post-fixpoint error reporting) reads meta-info outside the type-checking core. This runs inside `process-command` but after fixpoint, so the elaboration context is still active. No guard needed.

### 3.7 Dual-Write Transition

Following the established pattern (Migration Sprint → Track 1 → Track 3):

1. **Phase 1–3**: Dual-write. Metavar operations write to both the network cell and the standalone CHAMP box. Reads switch to cell-primary during elaboration, parameter fallback otherwise.
2. **Phase 6 cleanup**: Remove standalone CHAMP writes once all consumers read from cells.

This is the same gradual migration path that worked for constraints (Track 1) and registries (Track 3). The dual-write overhead is minimal (one extra CHAMP write per metavar operation).

### 3.8 File-to-Phase Mapping

| File | Phase | Nature |
|------|-------|--------|
| `infra-cell.rkt` | 1 | New merge function for meta-info CHAMPs |
| `metavar-store.rkt` | 1, 2, 3 | Cell-id parameters, cell creation, readers/writers, save/restore simplification |
| `elab-speculation-bridge.rkt` | 3, 4 | save/restore simplification, ATMS assumption integration |
| `driver.rkt` | 1 | Cell registration in process-command, elaboration guard if needed |
| `typing-core.rkt` | 4 (if not deferred) | No changes unless TMS-cell reads change `check`/`infer` API |

---

## §4. Risk Analysis

### 4.1 Medium Risk (Overall)

Track 4 touches the metavar store, which is the most-written state in the type checker. However:
- The mutation pattern (CHAMP writes) is identical in cell form
- The read path adds one indirection (cell lookup) — measurable but likely within noise
- Phases 1–3 are structurally identical to Track 1 and Track 3 (proven pattern)
- Phase 4 (TMS cells) is the high-risk phase, and it's conditional/deferrable

### 4.2 Known Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Meta-info cell read overhead on hot path | Medium | Medium | Profile before/after Phase 1; abort if >15% regression |
| Merge function complexity (CHAMP-in-cell) | Low | Medium | Use simple per-key last-write-wins; test with existing suite |
| `fresh-meta!` write overhead (creates new meta + writes to cell) | Medium | Low | `fresh-meta!` creates one entry; cell write is O(1) merge |
| Elaboration guard needed for meta-info | Low | Low | Meta-info is only read during elaboration; no guard expected (but verify) |
| Phase 4 TMS conversion changes read API | High (if attempted) | High | Phase 4 is conditional; defer unless clear GDE requirement |
| Interaction with batch-worker isolation | Low | Medium | batch-worker saves/restores parameters; after Phase 3, it needs to save/restore the network instead |

### 4.3 Open Questions

1. **Is Phase 4 (TMS cells) needed for Track 5?** Track 5 depends on Track 4 for "ATMS for non-monotonic definition replacement." Does Track 5 require TMS-backed meta-info, or can it work with the Phase 3 single-box snapshot? **Recommendation**: Design Track 5 before deciding. Phase 3 alone may be sufficient for Track 5.

2. **What happens to `batch-worker.rkt`?** Batch worker currently saves/restores parameters for worker isolation. After Track 4 Phase 3, it needs to save/restore the network box. **Recommendation**: Update batch-worker in Phase 3 alongside save/restore simplification. This is mechanical.

3. **Should `merge-meta-info-champ` handle concurrent writes?** In BSP parallel propagation, multiple propagators could write to the meta-info cell simultaneously. The per-key last-write-wins merge handles this correctly (each propagator writes to a different meta-id). **Recommendation**: No special handling needed.

---

## §5. Principle Alignment

| Principle | How This Track Upholds It |
|-----------|--------------------------|
| **Data Orientation** | Metavar state becomes a cell value — data in the network, not a procedure parameter |
| **Propagator-First Infrastructure** | All type-checking state flows through the propagator network after Phases 1–3 |
| **Correct by Construction** | Save/restore is structurally correct when it's just "save network" — no way to miss a box |
| **Decomplection** | Eliminates the 6-box coupling in save/restore; each concern lives in its own cell |
| **Compositionality** | ATMS assumptions compose — speculation within speculation works via nested assumptions |

---

## §6. Effort Estimate

| Phase | Scope | Est. Effort | Risk |
|-------|-------|-------------|------|
| 0 | Baseline + acceptance | 30 min | Low |
| 1 | Meta-info → cell | 2–3 hours | Medium |
| 2 | Level/mult/sess → cells | 1–2 hours | Low |
| 3 | ID-map → cell + save/restore simplification | 1–2 hours | Low |
| 4 | ATMS assumption-tagged speculation | 3–5 hours (if not deferred) | High |
| 5 | Learned-clause integration | 2–3 hours (if not deferred) | Medium |
| 6 | Performance validation + cleanup | 1 hour | Low |
| 7 | PIR | 1 hour | Low |

**Total**: Phases 0–3 + 6–7: ~7–10 hours (core track, certain value).
Phases 4–5: +5–8 hours (conditional, higher risk, deferrable).

**Comparison**: Track 3 was ~2 hours implementation after ~3 hours design (mechanical). Track 4 Phases 0–3 are similarly mechanical (same cell-primary pattern). Phases 4–5 are architectural and may require more iteration.

---

## §7. Composition Synergies

### 7.1 GDE Foundation (Track 9)

Track 4's ATMS-backed speculation is the prerequisite for the General Diagnostic Engine. Without assumptions tagging which type-checking steps belong to which speculation, the GDE cannot compute minimal diagnoses for type errors.

**Phase 3 alone** provides: all state in network → single snapshot target → cleaner speculation infrastructure.
**Phase 4** provides: ATMS assumptions tag speculative writes → retraction is structural → nogoods are reusable → GDE can compute minimal diagnoses.

### 7.2 Incremental Re-elaboration (Track 5)

Track 5 needs to retract a definition assumption and let propagation settle. With Track 4's all-state-in-network approach, "retract a definition" means retracting one assumption — the network shows the pre-definition state.

### 7.3 Driver Simplification (Track 6)

Track 6 removes dual-write and elaboration guards. Track 4's network consolidation brings metavar state into the same "single source of truth" framework, making Track 6's cleanup scope clearer.

### 7.4 Dependency-Directed Backjumping

From the Whole-System Migration Thesis §2.3: when speculation fails, the ATMS nogood identifies the minimal set of assumptions responsible. Future speculation can skip any combination that subsumes a known nogood. This pruning is automatic once Phase 4–5 are complete.

---

## §8. External Critique Response (D.2)

*To be completed during design review.*

---

## §9. Internal Self-Critique — Principle Alignment (D.3)

*To be completed during design review.*

---

## §10. Post-Implementation Review

*Reference to standalone PIR document (to be created after implementation).*
