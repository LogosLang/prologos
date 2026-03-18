# Track 6: Driver Simplification + Cleanup — Post-Implementation Review

**Date**: 2026-03-17
**Duration**: ~18 hours across 4 sessions (2 prior intervals + 2 today), with multiple context breaks due to server outages
**Commits**: 52 (from `60f7b77` through `1dd70ac`), including 2 reverts and 1 revert-of-revert
**Test delta**: +6 tests (7148 → 7154)
**Code delta**: +7540 lines, −1414 lines across 294 files
**Suite health**: 7154 tests, 372 files, 235.2s — **all pass, 0 failures** (first clean suite in project history)
**Design doc**: `docs/tracking/2026-03-16_TRACK6_DRIVER_SIMPLIFICATION.md`
**Acceptance file**: `examples/2026-03-16-track6-acceptance.prologos`
**Prior PIRs**: Track 3 PIR (elaboration guard discovery), Track 4 PIR (dual-write coherence, TMS cell architecture), Track 5 PIR (belt-and-suspenders retirement, persistent module networks)
**Master roadmap**: `docs/tracking/2026-03-13_PROPAGATOR_MIGRATION_MASTER.md`

---

## 1. What Was Built

Track 6 was the cleanup and simplification track — absorbing deferred items from Tracks 3, 4, and 5, eliminating transitional scaffolding, and completing the architectural cutover from parameter-primary to propagator-primary infrastructure.

**Before Track 6**: The system carried significant transitional debt from five prior migration tracks: dual-write overhead (all 28+ registries writing to both parameters and cells), 3-box save/restore for speculation, elaboration guards gating cell reads, vestigial callback parameters for pre-Track-2 resolution, and a 266-reference `current-global-env` name that no longer reflected the parameter's semantics.

**After Track 6**:
- **TMS retraction** replaces network-box restore for speculation rollback (save/restore reduced from 3 boxes to 1)
- **Data-oriented constraint status** — functional CHAMP updates replace in-place mutation
- **Module-network-ref as authoritative lookup source** — definition lookups go through `current-module-definitions-content` sourced from Track 5's persistent module network cells, not the legacy hasheq parameter
- **No elaboration guards** — cell reads are unconditional; net-box parameters scoped to command parameterize for structural isolation
- **Clean driver** — per-command parameterize reduced from ~30 to 13 bindings; `current-prelude-env` is the canonical name
- **Dead code removed** — 3 dead functions, 2 dead guard parameters, immediate resolution paths that duplicated the stratified loop
- **First clean test suite** — 7154 tests, 0 failures (ATMS initialization bug fixed)

Two workstreams: **WS-A** (Data Orientation + TMS Retraction, high-risk architectural changes) and **WS-B** (Dual-Write Elimination + Cleanup, mechanical). WS-A executed first per the "hard thing first" principle.

---

## 2. Timeline and Phases

### Session 1: Design + WS-A (prior interval)

| Phase | Commit | Tests | Suite (s) | Description |
|-------|--------|-------|-----------|-------------|
| D.1+ | `60f7b77` | — | — | Design with open question discussion |
| D.2 | `e017fe7` | — | — | External critique: 10 items addressed |
| D.3 | `1c63210` | — | — | Self-critique principle alignment |
| 0 | `7cd1ad6` | 7148 | — | Acceptance file (278 evals, 0 errors, 6 BUGs) |
| 1a | `9677970` | 7148 | 224.3 | id-map → elab-network field (3→2 box) |
| 1b | `39421e6` | 7148 | — | meta-info `#:mutable` removal (vestigial) |
| 1c | `e88c2b2` | 7148 | 210.8 | Constraint status → functional CHAMP updates |
| 1d | `a82e4d2` | 7148 | 207.4 | all-unsolved-metas → infrastructure cell |
| 2+3 | `4a08db6` | 7148 | 199.6 | Speculation stack push + commit-on-success |
| 4 | `acc76e4` | 7154 | 207.9 | TMS retraction + nested speculation |
| 5a | `9358b67` | 7148 | 210.5 | meta-info CHAMP → elab-network field (2→1 box) |
| 5b | — | — | — | **BLOCKED**: TMS retraction insufficient for infra cells |

### Session 2: WS-B start (prior interval, context breaks)

| Phase | Commit | Tests | Suite (s) | Description |
|-------|--------|-------|-----------|-------------|
| 6 | `25d7b20` | 7154 | 208.9 | batch-worker → snapshot-based state |
| 7a (first) | `520c2f8` | — | — | ❌ Skipped design: jumped to dual-write elimination |
| — | `de5cd3b` | — | — | **REVERT**: user caught design deviation |
| 7a (correct) | `92a27b0` | 7154 | 203.5 | test-support.rkt network isolation + shadow validation |
| 7b | `e10f5f3` | 7154 | 211.9 | ❌ sync-back pattern (later reverted) |
| 7c | `b618c78` | 7154 | 214.9 | ❌ sync-back pattern (later reverted) |

### Session 3-4: Architectural correction + completion (today)

| Phase | Commit | Tests | Suite (s) | Description |
|-------|--------|-------|-----------|-------------|
| — | `70063b9` | 7154 | — | **REVERT 7b/7c**: restore natural dual-write |
| 7d | `cd54a9f` | 7154 | — | Belt-and-suspenders: module-definitions-content population |
| 7d | `78bba78` | 7154 | — | Lookup cutover (250 test files updated) |
| 8a-c | `6fa6240` | 7154 | — | Guard removal + net-box scoping |
| 8d | `6793ce5` | 7154 | — | Dead code + immediate path removal |
| 9 | `36588ee` | 7154 | — | Rename: 994 occurrences, 271 files |
| 10 | — | — | — | Assessed: 13 bindings, all necessary |
| BUG | `ebc781e` | 7154 | 235.2 | ATMS lazy init — **0 failures** |
| — | `f66809e` | — | — | Principles: stratified prop-net insight |
| — | `ff8690c` | — | — | Master roadmap: Track 7 scope expanded |

**Design-to-implementation ratio**: Design (D.1+, D.2, D.3) took ~4 hours. Implementation (Phases 0-10 + BUG fix) took ~14 hours. Ratio ≈ 1:3.5. This is the highest implementation ratio of any propagator migration track, reflecting: (1) two workstreams with different risk profiles, (2) two reverts requiring re-implementation, (3) the module-network-ref lookup cutover touching 250+ files.

---

## 3. Test Coverage

### New tests
+6 tests from TMS retraction (Phase 4): nested speculation, tms-read fix, tms-commit flatten.

### Acceptance file
`2026-03-16-track6-acceptance.prologos`: 278 evaluations, 0 errors, 6 pre-existing BUGs annotated. Run before and after WS-A phases; not re-run after WS-B (which is infrastructure-only, no user-facing changes).

### Suite health milestone
**First clean test suite**: 7154 tests, 0 failures. The 2-3 pre-existing ATMS failures (`with-speculative-rollback: ATMS not initialized`) that persisted through Tracks 3-5 were fixed by lazy ATMS initialization (commit `ebc781e`).

---

## 4. Bugs Found and Fixed

### 4.1 Phase 7b-c: sync-back pattern diverged from Track 5 architecture
**Root cause**: Context loss during server outages. The implementation introduced `sync-macros-cells-to-params!` — an imperative reconciliation that copies cell values back to parameters after each command. This kept parameters as the persistence layer and added 24 lines of imperative sync code.

**Why the wrong path seemed right**: The previous session's context was lost, and the phase was framed as "dual-write elimination" — remove the parameter write, keep only the cell write. Without the context of Track 5's `global-env-add` pattern (which writes to BOTH `current-definition-cells-content` and cell as a coherent persistence + propagation operation), the parameter write looked redundant.

**Fix**: Reverted 4 commits (`70063b9`). The natural dual-write IS the Track 5 architecture — parameter = persistent data store, cell = propagation. No transformation needed for 7b-c.

**Contributing factors**: (1) Server outages broke context continuity, (2) The plan file was written without re-reading Track 5's PIR or design doc, (3) The "dual-write elimination" framing suggested the parameter write was redundant when it's actually persistence.

### 4.2 Phase 7d: erroneously deferred
**Root cause**: The deferral note said "not a redundant dual-write; requires lookup→cell migration first." This treated the lookup migration as out-of-scope future work when it was actually the planned Track 5 → Track 6 cutover.

**Why the wrong path seemed right**: After the 7b-c implementation, 7d's two-layer architecture looked fundamentally different from the 7b-c pattern. Without the context of Track 5's module-network-ref design (which was explicitly intended to replace Layer 2 lookups), 7d seemed like a separate, larger project.

**Fix**: User identified the deferral as erroneous. Re-read Track 5 design doc, master roadmap, and standup notes. Implemented the lookup cutover using `current-module-definitions-content` sourced from module-network-ref cells.

### 4.3 Phase 8b-c: stale net-box caused spec leakage
**Root cause**: Removing the elaboration guards exposed stale net-box parameters between commands. `register-macros-cells!` set `current-macros-prop-net-box` via direct mutation (not parameterize), so the net-box persisted after the command ended. Without the guard, subsequent cell reads succeeded against stale cells.

**Fix**: Scoped net-box parameters (`current-macros-prop-net-box`, `current-narrow-prop-net-box`, `current-warnings-prop-net-box`) to the process-command parameterize block. They auto-revert to `#f` when the command finishes, preventing stale reads.

### 4.4 ATMS initialization in test speculation paths
**Root cause**: Tests using `with-fresh-meta-env` call the type checker directly (not through `process-command`), so `init-speculation-tracking!` is never called. When union type elaboration triggers `with-speculative-rollback`, `current-command-atms` is `#f`.

**Why it persisted**: The error appeared as "pre-existing" (predating Track 6) and was tracked as a separate BUG rather than investigated. The 2-3 failures were masked by the larger test suite passing. Each track's PIR noted "same 3 ATMS failures" without investigating.

**Fix**: Lazy ATMS initialization in `with-speculative-rollback` — if `current-command-atms` is `#f`, create a fresh ATMS box on demand. Correct-by-construction: speculation works regardless of entry path.

---

## 5. Design Decisions and Rationale

### 5.1 Two workstreams, hard thing first
WS-A (TMS retraction, data orientation) before WS-B (dual-write elimination, cleanup). This follows the pattern established in Tracks 3-5: the architectural decision-heavy phase comes first, mechanical cleanup follows naturally. WS-A's completion gave structural confidence that cell paths were correct, making WS-B's changes trivially justified.

**Principle**: "Do the hard thing first" (DEVELOPMENT_LESSONS.org)

### 5.2 Natural dual-write as persistence + propagation
The existing register functions writing to both parameter and cell is NOT redundant — it's the same pattern as Track 5's `global-env-add`. The parameter is the persistent data store (survives across commands, seeds cells on next command via `register-macros-cells!`). The cell is for propagation (reactive reads during elaboration). Both are needed.

**Principle**: Data Orientation — the two writes serve different purposes in a single coherent operation.

### 5.3 Module-definitions-content as materialized cache
Lookups use a persistent hasheq (`current-module-definitions-content`) rather than direct module-network-ref cell reads in the hot path. The hasheq preserves O(1) lookup performance. The module network is the authoritative source — the hasheq is populated from cell reads during module import.

**Principle**: Propagator-First — the module network IS the source of truth; the hasheq is a read cache, not a separate store.

### 5.4 Net-box scoping replaces elaboration guards
Rather than a boolean guard parameter checked on every cell read, the net-box parameters themselves are scoped to the command parameterize. When the command ends, net-boxes revert to `#f`, making cell reads structurally return `'not-found` (falling back to parameter). This is correct-by-construction — no guard check needed.

**Principle**: Correct by Construction — structural scoping prevents stale reads without discipline.

### 5.5 Lazy ATMS initialization
`with-speculative-rollback` creates the ATMS on demand rather than requiring explicit initialization. This makes speculation work regardless of entry path (process-command, direct type-checker calls, test fixtures).

**Principle**: Correct by Construction — the system works structurally, not by requiring callers to follow a protocol.

### 5.6 Stratified propagator networks as architectural pattern
The deep audit of callback parameters revealed that the stratified resolution loop IS the load-bearing resolution mechanism. Callbacks are vestigial indirection from pre-Track-2 architecture. The architectural insight: each resolution stratum should BE a propagator layer, with readiness as a cell value and resolution as a propagator fire function.

**Principle**: Propagator-First — resolution logic belongs IN the network, not outside it via callbacks.

---

## 6. Lessons Learned

### 6.1 Context loss is an architectural risk
Server outages during Phases 7b-c led to implementation that diverged from Track 5's established patterns. The sync-back approach was the architectural opposite of what the propagator-first principles called for. **When resuming after context loss, re-read the prior track's design doc and PIR before implementing.** The plan file alone is insufficient — it captures WHAT to do, not WHY (the architectural reasoning that guides HOW).

**Action**: Added to memory as a workflow consideration. Future context restorations should explicitly re-read the master roadmap and latest PIR.

### 6.2 "Dual-write elimination" was the wrong framing
Calling the parameter + cell writes "dual-write" implied redundancy. But persistence and propagation are different concerns served by different mechanisms in a single operation. Track 5's `global-env-add` does the same thing. The correct framing: "parameter writes are the persistent data store; cell writes are for propagation. Both are needed."

**Action**: This reframing informed the 7b-c revert and should guide future migration tracks. When evaluating a "dual-write," ask: do the two writes serve different purposes?

### 6.3 Surface audits can miss vestigiality
Phase 8d was initially assessed as "skip — callbacks still active." A deep audit (examining call sites, the stratified loop architecture, dead callers, and the immediate path duplication) revealed all 3 callbacks are vestigial. The surface audit found active call sites; the deep audit found those call sites are invoked FROM the replacement architecture, not alongside it.

**Action**: For "skip" assessments, ask: "are these call sites load-bearing, or are they invoked from within the replacement mechanism?"

### 6.4 Callbacks are a propagator-first anti-pattern
When resolution logic lives outside the propagator network and is injected via callback parameters, it's a sign the logic should be a propagator. The callback can be `#f` (every call site must guard), is an opaque function (not inspectable), and fires imperatively (not through cell state). The alternative: make the trigger a cell and the response a propagator.

**Action**: Captured in DESIGN_PRINCIPLES.org § "Stratified Propagator Networks" and DEVELOPMENT_LESSONS.org § "Callbacks Are a Propagator-First Anti-Pattern". Applied to Track 7 scope expansion.

### 6.5 Lazy initialization > mandatory initialization for correct-by-construction
The ATMS bug persisted across 5 tracks because `with-speculative-rollback` required explicit initialization. Any entry path that skipped `init-speculation-tracking!` would fail. Lazy initialization makes the system work regardless of how it's entered. This is the correct-by-construction principle applied to infrastructure: the system should be structurally correct, not protocol-dependent.

**Action**: Applied. Future infrastructure should default to lazy initialization when the initialization is cheap and the protocol dependency is fragile.

### 6.6 Belt-and-suspenders validation works — but needs a defined retirement point
The belt-and-suspenders pattern (running both old and new paths, comparing results) successfully validated every migration step in this track. But Phase 5b shows the risk of not having a concrete retirement gate: the belt-and-suspenders for TMS retraction remains permanently active because infrastructure cells aren't TMS-managed. Without a defined retirement point, belt-and-suspenders becomes permanent dead code.

**Action**: This is a recurring theme from Track 5 PIR. Phase 5b deferred to Track 7 with explicit scope (TMS-aware infrastructure cells). The master roadmap now includes this as a WS-B in Track 7.

---

## 7. What Went Well

- **WS-A execution was clean**: Phases 1a-1d, 2+3, 4, 5a completed without any regressions or wrong turns. The "hard thing first" pattern worked — TMS retraction was the most architecturally complex phase and it went smoothly because the design was thorough.
- **Belt-and-suspenders validation** at every step: 0 divergences across module-definitions-content population, lookup cutover, guard removal, net-box scoping.
- **User-driven architectural correction**: The user caught the Phase 7d deferral error and the 7b-c sync-back divergence. The collaborative design discussion recovered the correct architecture.
- **Principles as design compass**: The propagator-first, data-oriented, correct-by-construction principles directly guided the 7b-c revert, the 7d lookup cutover approach, the guard removal strategy, and the ATMS fix.
- **First clean suite**: 5 tracks of migration, and Track 6 is where the suite finally goes to 0 failures. This is a milestone.

## 8. What Went Wrong

- **Context loss caused a full revert cycle**: Phases 7b-c were implemented, committed, tracked, and documented — then reverted. This wasted ~2 hours of implementation time and created 8 commits (4 original + 4 revert) that clutter the history.
- **Phase 7d was erroneously deferred**: The deferral was based on a surface-level analysis ("not a dual-write") that missed the Track 5 design intent. This delayed the most architecturally significant phase.
- **Phase 8d initial assessment was wrong**: "Still active, skip" was based on finding active call sites without analyzing whether they were load-bearing. The deep audit took significantly longer but revealed the correct answer.
- **ATMS bug persisted across 5 tracks**: Every PIR from Track 3 onward noted "same 2-3 ATMS failures." Nobody investigated until Track 6. The fix was 3 lines. Normalizing failures is dangerous.

## 9. Where We Got Lucky

- **The sync-back pattern didn't cause data corruption**: The 7b-c sync-back approach, while architecturally wrong, didn't actually break any tests. If it had caused subtle data corruption (e.g., stale cell values overwriting correct parameter values), the revert would have been harder to justify and the damage harder to find.
- **The test-prelude-system-02.rkt failure caught the parameterize gap**: When switching lookups to `current-module-definitions-content`, the `:no-prelude` tests immediately failed because the custom `run-ns` helper didn't reset the new parameter. This caught a class of bug (missing resets in custom test helpers) that could have been much harder to find in production.

## 10. What Surprised Us

- **The natural dual-write is the correct architecture**: We expected Phase 7b-c to eliminate parameter writes. Instead we learned the parameter writes ARE the persistence layer — the same pattern Track 5 uses. The "elimination" framing was wrong.
- **Callbacks are vestigial inside their own replacement**: The stratified resolution loop invokes the callbacks from within its Stratum 2. The callbacks aren't an alternative path — they're indirection WITHIN the correct path. Removing the indirection is the next step, not removing the resolution logic.
- **Stratified propagator networks as a design pattern**: The discussion about what replaces callbacks led to the insight that each resolution stratum should be a propagator layer with inter-stratum Galois connections. This is a genuinely new architectural pattern that applies beyond constraint resolution.

## 11. Architecture Assessment

Track 6's architecture changes hold up well. The key validations:

- **Module-definitions-content cutover**: Lookups now go through a hasheq sourced from module-network-ref cells. This is the correct layering: module network is authoritative, hasheq is a read cache. The belt-and-suspenders fallback to `current-prelude-env` provides safety during transition.
- **Net-box scoping**: Replacing elaboration guards with structural scoping (parameterize auto-revert) is cleaner and more correct-by-construction. The Phase 8b-c regression (stale net-box) validated that the approach catches real bugs.
- **TMS retraction**: Phases 2+3 (speculation stack push + commit-on-success) work for value-level branching. The Phase 5b blocker (infrastructure cells not TMS-managed) is a genuine architectural gap, correctly deferred to Track 7.

**Friction points**: The callback parameters remain as indirection — resolution logic in driver.rkt, invocation in metavar-store.rkt. Module restructuring to inline this is Track 7 scope.

---

## 12. Assumptions That Were Wrong

1. **"Dual-write is redundancy."** It's persistence + propagation — two distinct concerns.
2. **"Phase 7d is just another dual-write elimination."** It's the Track 5 → Track 6 lookup cutover — the most architecturally significant phase.
3. **"Callbacks are still active."** They're invoked from within their replacement, not independently.
4. **"The ATMS failures are pre-existing and unrelated."** They were a 3-line fix away from resolution.
5. **"Context can be recovered from a plan file."** Plan files capture WHAT, not WHY. Recovering the architectural reasoning requires re-reading design docs and PIRs.

## 13. What This Enables

- **Track 7 (QTT Multiplicity Cells + TMS Architecture)**: Clean driver baseline, no elaboration guards, single canonical parameter name. TMS-aware infrastructure cells can now be designed without navigating transitional scaffolding.
- **Track 8 (Unification as Propagators)**: Net-box scoping pattern provides the template for scoping new propagator infrastructure to commands. The stratified prop-net insight informs how unification propagators should interact with the resolution strata.
- **Track 10 (LSP Integration)**: Module-network-ref is now the authoritative definition source for lookups. The LSP can invalidate by writing to module network cells, and staleness will propagate through the existing dependency edge infrastructure.
- **Stratified prop-net architecture**: The callback audit and principles annotation provide the design foundation for replacing the hand-written stratified loop with actual propagator layers.

## 14. Technical Debt Accepted

| Item | Rationale | Tracking |
|------|-----------|----------|
| Layer 2 writes retained | Belt-and-suspenders fallback; module-definitions-content validated but Layer 2 not yet removed | Natural follow-up, low priority |
| Callback parameters retained | Inlining requires module restructuring; stepping stone to stratified prop-nets | Track 7 WS-B, DEFERRED.md |
| Phase 5b (retirement gate) | TMS retraction insufficient for infra cells + structural state | Track 7 WS-B |
| `current-prelude-env-prop-net-box` name | Should be `current-definition-prop-net-box` (it's about Layer 1 cells, not prelude env) | Low priority rename |

## 15. What Would We Do Differently

1. **Re-read the prior track's PIR before starting implementation after a context break.** The sync-back divergence would have been caught immediately.
2. **Frame Phase 7 as "lookup cutover" not "dual-write elimination."** The framing guided implementation down the wrong path. The correct framing follows from Track 5's design intent.
3. **Investigate "pre-existing" failures rather than normalizing them.** The ATMS bug was a 3-line fix that persisted across 5 tracks because nobody looked.
4. **Deep audit before "skip" assessments.** Phase 8d's surface audit gave the wrong answer.

## 16. Cross-References to Prior PIRs

| Pattern | Track 3 PIR | Track 4 PIR | Track 5 PIR | Track 6 PIR (this) |
|---------|-------------|-------------|-------------|-------------------|
| Elaboration guard | Discovered | — | — | Removed |
| Dual-write coherence | — | Analyzed | — | Reframed as persistence + propagation |
| Belt-and-suspenders | — | Used | Retirement methodology | Retirement gate blocked → Track 7 |
| Context loss risk | — | — | Noted (context break between phases) | Full revert cycle caused by context loss |
| "Same ATMS failures" | Noted | Noted | Noted | Fixed |
| Callbacks as indirection | — | — | — | Identified as anti-pattern; architectural alternative designed |

## 17. Key Files

| File | Role |
|------|------|
| `global-env.rkt` | Module-definitions-content, lookup cutover, prelude-env rename |
| `driver.rkt` | Module import from network-ref, net-box scoping, command parameterize |
| `macros.rkt` | Guard removal, dead code cleanup |
| `metavar-store.rkt` | Dead function removal, immediate path removal, data-oriented constraints |
| `elab-speculation-bridge.rkt` | TMS retraction, lazy ATMS init |
| `warnings.rkt` | Guard removal |
| `global-constraints.rkt` | Guard removal |
| `test-support.rkt` | Network isolation, module-definitions-content reset |
| `batch-worker.rkt` | Snapshot-based state, module-definitions-content save/restore |
| `repl.rkt` | Direct parameter reads for outside-elaboration contexts |
| `DESIGN_PRINCIPLES.org` | Stratified Propagator Networks subsection |
| `DEVELOPMENT_LESSONS.org` | Callbacks anti-pattern lesson |
