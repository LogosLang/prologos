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
| D.2 | Design iteration (external critique) | ✅ | 8 accepted, 2 accepted-with-modification, 5 rejected-with-rationale |
| D.3 | Internal self-critique (principle alignment) | ✅ | 5 items resolved |
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

Two-tier goal:

1. **Core goal (Phases 1–3): Network consolidation** — move all metavar CHAMPs into propagator network cells, reducing `save-meta-state` from 6 boxes to 1. This is network-consolidated imperative rollback: the snapshot mechanism is unchanged (save/restore), but the surface area is reduced to a single box and future state additions are automatically captured.

2. **Stretch goal (Phases 4–5): Structural ATMS speculation** — convert metavar cells to ATMS TMS cells, enabling assumption-tagged writes where retraction structurally hides speculative state. This replaces imperative save/restore with ATMS-backed rollback. Conditional on Phase 1–3 stability and downstream requirements from Track 5/9.

Concretely:
- Move meta-info, level-meta, mult-meta, and sess-meta from standalone CHAMP boxes into propagator network cells
- Reduce `save-meta-state` from 6 boxes to 1 (network only)
- Optionally (Phase 4): make ATMS assumption retraction the rollback mechanism

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

**Call site #6** (`typing-errors.rkt`) is special: it's error enrichment, not type-checking logic. It speculatively checks each union branch to produce per-branch mismatch details. The overall check has already failed; the speculation collects per-branch diagnostics. Note: despite being "diagnostic," each speculative `(check ctx e br)` does create metas and solve constraints — `fresh-meta!` and `solve-meta!` fire during the thunk. The rollback in `with-speculative-rollback` correctly discards these mutations. The speculation is therefore not "read-only" at the meta-state level, but its results are used only for error message construction.

**Nested speculation**: Call sites #4 and #5 (union check) can nest arbitrarily. If the left branch `l` of a union `(union l r)` is itself a union `(union l2 r2)`, the `check` call inside the outer speculation triggers an inner speculation. This creates a stack of save/restore frames. The current implementation handles this correctly: each `with-speculative-rollback` independently saves/restores the network box, and inner failures are extracted as `sub-failures` of the outer failure (Phase D2). After Track 4, nested speculation continues to work because each nesting level saves/restores the same single network box.

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

### 2.3.1 ATMS State Location and Speculation Semantics

The per-command ATMS lives in `current-command-atms` — a boxed parameter in `elab-speculation-bridge.rkt`, **NOT** in the propagator network. This is intentional: the ATMS accumulates hypotheses and nogoods across all speculation branches within a command, surviving rollback to build a complete failure tree for error messages.

**Two-level rollback semantics** (current architecture):
1. **Logic-level rollback**: Meta-state (metas, constraints, network) rolls back via `restore-meta-state!`
2. **Error-tracking persistence**: ATMS hypotheses and nogoods accumulate across all branches, NOT rolled back

This separation is correct and must be preserved in Track 4. When Phases 1–3 consolidate meta-state into the network, the ATMS box remains outside the network — it's an error-tracking accumulator, not type-checking state. When/if Phase 4 introduces TMS cells, the ATMS would gate cell *reads* (worldview filtering) but the ATMS struct itself would still live outside the network and persist across rollbacks.

**Nested speculation worldview semantics**: When speculation nests (e.g., union-of-unions), each level creates its own ATMS hypothesis. Inner failures record nogoods referencing their hypothesis. The outer speculation's hypothesis remains believed throughout — inner retraction doesn't affect outer state. This is correct because the ATMS hypothesis graph is append-only during a command; only the network box is rolled back.

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

**Option D: Lazy Snapshot (Copy-on-Write CHAMPs)**

Keep CHAMPs as standalone boxes. On speculation start, mark them as "speculative." On first write to a speculative CHAMP, fork (copy-on-write). On commit, clear the flag. On rollback, discard the forked version.

- Pro: No read-path overhead (no cell indirection on hot path)
- Pro: Write cost only paid when speculation actually writes
- Con: Requires tracking which CHAMPs are in speculative mode — a new mechanism orthogonal to both cells and ATMS
- Con: Doesn't move state into the network (violates propagator-first principle)
- Con: Copy-on-write is exactly what CHAMP structural sharing already provides for free — the current save/restore is effectively O(1) CoW. Option D re-implements what already exists with more complexity.

**Rejected**: Option D provides no benefit over the current save/restore mechanism, which is already O(1) via CHAMP structural sharing. The current mechanism's problem is fragility (6 boxes to maintain), not performance. Option D doesn't reduce the box count.

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

**Merge correctness under save/restore (Phases 1–3)**: The merge function is only invoked during cell writes. Save/restore operates at the network-box level, not the cell level. When `restore-meta-state!` swaps the network box reference, the cell's merge function is irrelevant — the entire cell (including its accumulated value) reverts to the saved snapshot. Merge correctness matters for normal (non-speculative) writes; speculation correctness depends on box-level save/restore. This constraint is inherent to the Phase 1–3 approach and is identical to how constraint cells already work today.

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

### 3.4.1 Two-Layer Speculation Model

The network contains two kinds of cells with fundamentally different speculation semantics:

**Layer 1: Monotonic cells** (constraints, registries, wakeups, and after this track: meta-info, level/mult/session, id-map)
- Standard merge functions (hasheq union, list append, last-write-wins)
- Rollback via network-box save/restore: save an immutable CHAMP reference, restore it on failure
- This is the only mechanism in Phases 1–3

**Layer 2: TMS cells** (if Phase 4 proceeds)
- Assumption-tagged values: each write carries an assumption-id
- Reads filter by believed assumptions (the current worldview)
- Retraction makes writes invisible without explicit restore
- The ATMS struct (which tracks beliefs/nogoods) lives OUTSIDE the network in `current-command-atms` and is NOT rolled back

**Can a network have both?** Yes. The `prop-network` struct's cell store is a CHAMP of `cell-id → prop-cell`. TMS cells would be a different cell type (`tms-cell`) stored in the ATMS's `tms-cells` map, not in the prop-network's cells. Monotonic and TMS cells coexist without interference.

**How does save/restore interact with TMS?** Network-box save/restore captures monotonic cells. TMS cells live in the ATMS, which is NOT restored. This means:
- Monotonic cells (constraints, registries): rolled back by network restore
- TMS cells (if added): not rolled back by network restore — rollback is via assumption retraction
- The two mechanisms are independent and composable

**Phase 1–3 implication**: All new metavar cells are monotonic. Network-box save/restore captures them. The same single-box snapshot mechanism that works today (for the network) extends to cover meta-info, level/mult/session, and id-map.

### 3.4.2 Cell Type Decision

✓ DESIGN DECISION (Phases 1–3): **Monotonic cells** for all metavar state. TMS conversion is deferred to Phase 4, pending performance validation and GDE requirements analysis.

Rationale: The primary goal is to eliminate the 6-box fragility and bring metavar state into the network. Full TMS cells for meta-info would change every metavar read path (adding worldview filtering on every `meta-solved?` / `meta-solution` call — the hottest operations in the type checker). The network-cell approach achieves the consolidation goal. TMS assumption-tagging can be layered on later when Track 9 (GDE) clarifies requirements.

**Decision point for Phase 4**: Track 5 design (D.1) will be completed before Track 4 Phase 3 ends. If Track 5 requires TMS cells for non-monotonic definition retraction, proceed with Phase 4. Otherwise, mark Phase 4 as "deferred to Track 9."

### 3.4.3 Worked Example: Union Type Speculation

Concrete illustration of how speculation changes across Track 4 phases.

**Scenario**: `check expr against (union (Map String Int) (Map String String))`

**Before Track 4 (current):**
1. `save-meta-state` → snapshot 6 boxes (network, id-map, meta-info, level, mult, sess)
2. `check expr (Map String Int)` → `fresh-meta` M1, writes to meta-info CHAMP box + network cell; `solve-meta` M1; type fails
3. `restore-meta-state!` → restores all 6 boxes (M1 gone from meta-info; network constraints rolled back)
4. `check expr (Map String String)` → `fresh-meta` M2, succeeds
5. Commit — M2 persists

**After Track 4 Phase 3 (network consolidation):**
1. `save-meta-state` → snapshot 1 box (network only — meta-info, level, mult, sess, id-map are all cells inside the network)
2. `check expr (Map String Int)` → `fresh-meta` M1, writes to meta-info cell in network; fails
3. `restore-meta-state!` → restores 1 box (entire network including meta-info cell reverts; M1 gone)
4. `check expr (Map String String)` → `fresh-meta` M2, succeeds
5. Commit — M2 persists

**After Track 4 Phase 4 (TMS cells, if implemented):**
1. `atms-assume` A1 → create assumption for "try (Map String Int)"
2. `check expr (Map String Int)` → `fresh-meta` M1, writes to meta-info TMS cell with A1 tag; fails
3. `atms-retract` A1 → A1's writes become invisible (no box save/restore needed for TMS state)
4. `atms-assume` A2 → create assumption for "try (Map String String)"
5. `check expr (Map String String)` → writes with A2 tag, succeeds
6. Commit — A2 stays believed, writes visible; A1's nogood recorded for GDE

**Note**: In Phase 3, the behavior is identical to the current mechanism — just with 1 box instead of 6. In Phase 4, the monotonic cells (constraints, registries) still use network-box save/restore; only TMS cells get assumption-based retraction.

### 3.5 Phase Structure

#### Phase 0: Performance Baseline + Profiling

- Acceptance file: `examples/2026-03-16-track4-acceptance.prologos` covering speculation-exercising patterns (union types, map widening, Church folds)
- Baseline: full suite timing, cell count metrics
- **Profiling**: Instrument `meta-info` read frequency during full suite. Measure: (a) total `meta-solved?` / `meta-solution` calls, (b) breakdown by caller (which functions read meta-info most?). This quantifies the "hot path" risk and sets the regression threshold.
- Pre-flight: verify all 6 call sites with grep, confirm no new ones since Track 3
- **Verify two-context assumption**: Instrument `read-meta-info` (once added) with a context check — confirm meta-info is only read during elaboration, not during module loading

#### Phase 1: Meta-Info CHAMP → Network Cell

**Scope**: Move `current-prop-meta-info-box` into the propagator network as a cell.

**Files**: `metavar-store.rkt`, `infra-cell.rkt`

1. Add `merge-meta-info-champ` merge function to `infra-cell.rkt`
2. Add `current-meta-info-cell-id` parameter to `metavar-store.rkt`
3. Create meta-info cell in `reset-meta-store!` (or `register-meta-cells!`)
4. Add cell-primary reader: `read-meta-info` — reads from cell during elaboration, parameter fallback otherwise (same pattern as Track 3's elaboration guard)
5. Add cell writer: metavar operations (`fresh-meta!`, `solve-meta!`, `unsolve-meta!`, etc.) write to both cell and CHAMP box (dual-write, as in Track 3's transitional pattern)
6. Update `save-meta-state` to exclude meta-info from the explicit snapshot (it's now in the network, captured by the network box snapshot)

**Risk**: This is the highest-risk phase. Meta-info reads are the most frequent operation in the type checker (`meta-solved?` and `meta-solution` are called on every unification, constraint posting, and type-checking decision). Instrument before/after to detect performance regression.

**Verification**: Full suite must pass with 0 regressions. Performance within 10% of baseline.

**Contingency**: If Phase 1 shows >15% performance regression after investigation:
1. Profile to identify whether the overhead is in reads (cell lookup) or writes (cell merge)
2. If reads: investigate caching the meta-info cell-id to avoid repeated lookups
3. If still unacceptable: fall back to Option B (assumption-associated CHAMPs) — keep CHAMPs standalone, associate snapshots with ATMS assumptions. This preserves the consolidation benefit for the other 4 CHAMPs (level/mult/session/id-map) while keeping meta-info on its current fast path.

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

### 3.5.1 Parallelism Interaction

Speculation is **single-threaded** within the current architecture. Each `with-speculative-rollback` call is sequential: try left, if fail restore, try right. There is no parallel speculation (e.g., forking two workers to try left and right simultaneously).

BSP parallel propagation (`run-to-quiescence-bsp`) applies to propagators within a single speculation context, not across speculation branches. During a speculative thunk, propagators may fire in parallel (BSP supersteps), but the speculation boundary is a sequential decision point.

**After Track 4**: This doesn't change. Phases 1–3 don't introduce parallelism. Phase 4 (TMS cells) would theoretically enable parallel speculation (each branch uses its own assumption, reads are filtered by worldview), but this is far-future scope. For Track 4, speculation remains serial.

**Merge safety**: Multiple propagators writing to the meta-info cell during BSP cannot cause corruption because (a) each propagator writes to a different meta-id (propagators are scoped to specific metas), and (b) the per-key last-write-wins merge is commutative at the key level. No two propagators write to the same meta-id key.

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
| Meta-info cell read overhead on hot path | Medium | Medium | Profile before/after Phase 1; abort if >15% regression. Contingency: fall back to Option B for meta-info only |
| Merge function complexity (CHAMP-in-cell) | Low | Medium | Use simple per-key last-write-wins; test with existing suite |
| `fresh-meta!` write overhead (creates new meta + writes to cell) | Medium | Low | `fresh-meta!` creates one entry; cell write is O(1) merge |
| Elaboration guard needed for meta-info | Low | Low | Meta-info is only read during elaboration; verify in Phase 0 by instrumenting reads |
| Phase 4 TMS conversion changes read API | High (if attempted) | High | Phase 4 is conditional; defer unless clear GDE requirement |
| Interaction with batch-worker isolation | Low | Medium | batch-worker saves/restores parameters; after Phase 3, it needs to save/restore the network instead |
| Speculation with cascading propagation | Low | Low | If speculative `fresh-meta!`/`solve-meta!` triggers propagators that cascade widely, the network diverges from the saved snapshot. But rollback is still O(1) — it's a single box reference swap, regardless of how much propagation occurred. The cost is in wasted propagation work, not in rollback itself. |
| ATMS state synchronization | Low | Low | ATMS lives in `current-command-atms` (boxed parameter), intentionally NOT captured by network save/restore. ATMS accumulates hypotheses/nogoods across all branches for error reporting. No synchronization needed — the two-level rollback semantics are correct by design (see §2.3.1). |

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
| **Debuggability** | Network consolidation means all speculation state is inspectable via cell reads. ATMS hypothesis IDs tag which speculation created which state. Phase 4 would add worldview inspection (which values are believed under which assumptions). |

**Honest tension**: Phases 1–3 achieve *consolidation* but not *structural ATMS*. The propagator-first principle is fully satisfied only if Phase 4 proceeds. However, Phases 1–3 are a strict improvement over the status quo (6 boxes → 1 box), and the Phase 4 decision is explicit, not accidental.

---

## §6. Effort Estimate

| Phase | Scope | Est. Effort | Risk |
|-------|-------|-------------|------|
| 0 | Baseline + profiling + acceptance | 1 hour | Low |
| 1 | Meta-info → cell | 3–5 hours | Medium |
| 2 | Level/mult/sess → cells | 1–2 hours | Low |
| 3 | ID-map → cell + save/restore simplification | 1–2 hours | Low |
| 4 | ATMS assumption-tagged speculation | 3–5 hours (if not deferred) | High |
| 5 | Learned-clause integration | 2–3 hours (if not deferred) | Medium |
| 6 | Performance validation + cleanup | 1 hour | Low |
| 7 | PIR | 1 hour | Low |

**Total**: Phases 0–3 + 6–7: ~9–13 hours (core track, certain value).
Phases 4–5: +5–8 hours (conditional, higher risk, deferrable).

Phase 1 estimate is higher than Track 3's per-phase time because meta-info is higher-frequency and requires more verification/profiling. Phases 2–3 are mechanical.

### 6.1 Success Metrics

| Metric | Phase 3 Target | Phase 4 Target (if attempted) |
|--------|----------------|-------------------------------|
| save/restore box count | 1 (was 6) | 1 (monotonic) + 0 (TMS — automatic retraction) |
| Performance delta | <10% regression | <15% regression |
| Test regressions | 0 | 0 |
| Speculation bugs introduced | 0 | 0 |
| Nogood reuse rate | N/A | >0 (pruning observed in speculation-heavy tests) |

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

### Accepted (8 items)

| # | Critique | Action Taken |
|---|----------|--------------|
| 1 | §1.2 understatement — reframe to distinguish consolidation (core) vs structural ATMS (stretch) | Rewrote §1.2 with explicit two-tier framing: "Core goal (Phases 1–3): Network consolidation" vs "Stretch goal (Phases 4–5): Structural ATMS speculation" |
| 2 | Missing Option D (lazy copy-on-write CHAMPs) | Added Option D to §3.1 with explicit rejection rationale: CHAMP structural sharing already provides O(1) CoW; the problem is fragility (6 boxes), not performance |
| 3 | Add worked example | Added §3.4.3 with concrete before/after for union speculation across all three Track 4 phases |
| 4 | Verify call site #6 is truly read-only | Updated §2.1 to clarify: call site #6 does create metas and solve constraints during the thunk (not read-only at meta-state level), but rollback correctly discards all mutations. Results used only for error message construction. |
| 5 | Add nested speculation semantics | Added explanation to §2.1 (nested call site analysis) and §2.3.1 (two-level rollback semantics, worldview composition). Nesting works because each level independently saves/restores the same network box, and inner ATMS hypotheses don't affect outer worldview. |
| 6 | Add ATMS state synchronization risk | Added §2.3.1 clarifying ATMS location (boxed parameter, intentionally outside network), two-level rollback semantics, and new risk table entry confirming no synchronization issue. |
| 7 | Profile before Phase 1 + contingency plan | Updated Phase 0 to include meta-info read frequency profiling. Added contingency plan to Phase 1: if >15% regression, investigate; fall back to Option B for meta-info only while keeping other CHAMPs as cells. |
| 8 | Add success metrics | Added §6.1 with explicit targets for save/restore box count, performance delta, test regressions, and nogood reuse rate. |

### Accepted with modification (2 items)

| # | Critique | Disposition |
|---|----------|-------------|
| 9 | "OPEN" framing for TMS cell decision is confusing — either remove or keep undecided | Reframed: removed "OPEN" label, created §3.4.2 "Cell Type Decision" with clear decision statement and explicit decision point: "Track 5 D.1 will be completed before Track 4 Phase 3 ends" to break the dependency loop. |
| 10 | Phase 1 estimate too low (2–3 hours) | Increased to 3–5 hours. Added rationale: meta-info is higher-frequency than any Track 3 registry; extra time for profiling and verification. |

### Rejected with rationale (5 items)

| # | Critique | Rationale for Rejection |
|---|----------|------------------------|
| 11 | Add §3.4.1 "Two-Layer Speculation Model" | **Accepted in spirit, different structure**: Added as §3.4.1 but integrated with §3.4.2 (cell type decision) rather than as a standalone section in the pseudocode area. The two-layer model (monotonic vs TMS) is now explained with explicit answers to "can a network have both?" and "how does save/restore interact with TMS?" |
| 12 | Quantify meta-info read frequency ("how many reads per expression?") | Deferred to Phase 0 profiling rather than design-time estimation. The read count depends on expression complexity and is not meaningfully estimable in advance. Phase 0 will instrument and measure across the full suite, providing actual numbers. Speculative estimation would be unreliable. |
| 13 | Verify module loading doesn't read meta-info | **Accepted as Phase 0 verification step**, not as a design-doc analysis. Added to Phase 0: "Verify two-context assumption: instrument `read-meta-info` with context check." This is a runtime verification, not something resolvable by code inspection. However, strong structural evidence: `fresh-meta!` is called only inside `infer`/`check` (type-checking), which only runs inside `process-command`. Module loading calls `process-string`/`process-file` which goes through `process-command`. Meta reads outside elaboration would be a bug in the existing architecture, not a Track 4 issue. |
| 14 | Add "Parallelism Interaction" section — can speculations run in parallel? | Added §3.5.1 but the answer is simple: **no**. Speculation is single-threaded. BSP parallelism applies within a speculation context (propagators fire in parallel), not across speculation branches. This doesn't change in Track 4. |
| 15 | Missing principle: "Debuggability" | Added to §5. However, debuggability is a quality attribute, not one of the project's formal design principles from `DESIGN_PRINCIPLES.org`. Included as an observation rather than a formal principle alignment. |

---

## §9. Internal Self-Critique — Principle Alignment (D.3)

1. **Data Orientation: Is a CHAMP-in-a-cell still "data oriented"?** The meta-info cell contains a CHAMP (a persistent hash array mapped trie). This is data — an immutable value with structural sharing. The cell doesn't contain procedures, closures, or mutable references. The merge function is a pure function on data. Resolved: yes, this upholds data orientation.

2. **Propagator-First: Does Phase 3 truly achieve "all state in network"?** The ATMS struct in `current-command-atms` lives outside the network. However, the ATMS is not type-checking state — it's error-tracking infrastructure. Its hypotheses and nogoods are metadata *about* the computation, not inputs *to* the computation. The propagator-first principle applies to state that participates in type-checking (metas, constraints, registries). ATMS is a diagnostic overlay. Resolved: principle is satisfied for type-checking state; ATMS is correctly excluded.

3. **Correct by Construction: Is 1-box save/restore actually safer than 6-box?** Yes. The failure mode of 6-box save/restore is: "new state added, save/restore not updated, speculation leaks." This happened with level/mult/session CHAMPs (Track 1 Phase B). With 1-box save/restore, any new cell added to the network is automatically captured — there is no update to forget. The correctness is structural: "network snapshot captures everything in the network."

4. **Completeness over Deferral: Is deferring Phase 4 justified?** Phase 4 (TMS cells) changes every metavar read path. The risk is disproportionate to the value gained at this point — learned-clause pruning and GDE integration are Track 9 concerns, not Track 4 urgency. Phases 1–3 deliver concrete value (fragility elimination). Phase 4 should wait for Track 5 design to clarify whether TMS is actually needed. This is genuine dependency, not scope avoidance. Resolved: deferral justified.

5. **PIR process: What should the PIR focus on for this track?** If only Phases 0–3 are implemented, the PIR should compare: (a) actual meta-info read overhead vs. pre-Phase-0 profiling estimate, (b) whether the 1-box consolidation held (no new state leaked outside the network), (c) any bugs analogous to Track 3's elaboration guard discovery. If Phase 4 is implemented, add: (d) TMS read overhead, (e) nogood reuse observations.

---

## §10. Post-Implementation Review

*Reference to standalone PIR document (to be created after implementation).*
