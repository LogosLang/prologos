# Propagator Migration Master Roadmap

**Created**: 2026-03-13
**Status**: ACTIVE — living document
**Vision**: Full-system observability via propagator-first architecture. Every piece of mutable state that participates in type-checking flows through one unified propagator network, making the compiler a transparent proof object — queryable, verifiable, incremental, and the foundation for self-hosting.
**Principle**: Data Orientation, Propagator-First Infrastructure, Correct by Construction

---

## Origin Documents

| Document | Location | Role |
|----------|----------|------|
| Pipeline Audit | `docs/research/2026-03-11_PROPAGATOR_FIRST_PIPELINE_AUDIT.md` | Whole-system inventory: ~80 state sites classified, ~42 propagator-natural |
| Whole-System Migration Thesis | `docs/research/2026-03-11_WHOLE_SYSTEM_PROPAGATOR_MIGRATION.md` | Architectural thesis: compiler as transparent proof object |
| GDE Roadmap | `docs/tracking/2026-03-04_PROPAGATOR_MIGRATION_GDE.md` | Earlier roadmap: P1-E3, P3, P5, P1-G, GDE dependency graph |
| Migration Sprint | `docs/tracking/2026-03-11_1800_PROPAGATOR_FIRST_MIGRATION.md` | Phase 0–5 implementation plan (the foundation layer) |
| Track 1 Design | `docs/tracking/2026-03-12_TRACK1_CONSTRAINT_CELL_PRIMARY.md` | Cell-primary reads for constraint tracking |
| Track 1 PIR | `docs/tracking/2026-03-12_TRACK1_CELL_PRIMARY_PIR.md` | Post-implementation review |
| Track 2 Design | `docs/tracking/2026-03-13_TRACK2_REACTIVE_RESOLUTION_DESIGN.md` | Reactive resolution via stratified quiescence |
| Track 3 Design | `docs/tracking/2026-03-13_TRACK3_CELL_PRIMARY_REGISTRIES.md` | Cell-primary registries design + progress |
| Track 3 PIR | `docs/tracking/2026-03-16_TRACK3_CELL_PRIMARY_REGISTRIES_PIR.md` | Post-implementation review |
| Propagator Research | `docs/tracking/2026-02-23_LATTICE_PROPAGATOR_RESEARCH.md` | Lattice-theoretic foundations |
| BSP Parallel | `docs/tracking/2026-02-24_BSP_PARALLEL_PROPAGATOR.md` | Parallel propagation via Bulk Synchronous Parallel |
| Effectful Propagators | `docs/tracking/2026-03-06_EFFECTFUL_PROPAGATORS_RESEARCH.md` | Side effects in propagator networks |
| Propagators as Model Checkers | `docs/research/2026-03-07_PROPAGATORS_AS_MODEL_CHECKERS.org` | Verification via propagator infrastructure |

---

## Completed Work

### Foundation: Propagator-First Migration Sprint (Phases 0–4)

Created the unified cell abstraction and migrated all 42 propagator-natural state sites to dual-write cells. Commits span `140c023`..`9f85f0f`.

| Phase | Description | Status | Key Commits |
|-------|-------------|--------|-------------|
| 0a | Merge function library + cell factory (`infra-cell.rkt`) | ✅ | `140c023` |
| 0b | ATMS assumption infrastructure | ✅ | `8e9d018` |
| 0c | Network construction via registration protocol | ✅ | `5d4d6f9` |
| 0d | Parallel propagation verification | ✅ | `e408151` |
| 0e | Integration smoke test (6803 tests) | ✅ | |
| 1a–1e | Constraint store + wakeup + trait/hasmethod/capability cells | ✅ | `411e96b`..`c98d95f` |
| 2a–2c | All 24 registry cells + 3 warning cells | ✅ | `5a12671`..`7e40345` |
| 3a–3d | Per-definition global-env cells, module registry, ns-context | ✅ | `dae48b7`..`9f85f0f` |
| 3e | Reduction cache cells | ⬜ | Deferred (LSP-specific) |
| 4a–4e | Speculation audit, constraint store leak fix, ATMS mandatory | ✅ | `c46d8c2`..`ce48638` |
| 5a–5b | Driver simplification | ⬜ | Not started |

**Result**: All ~42 propagator-natural state sites have cells. Dual-write pattern: every mutation writes to both legacy parameter AND propagator cell. Network has ~38+ infrastructure cells per command.

### Track 1: Cell-Primary Constraint Tracking

Flipped constraint tracking reads from parameter-primary to cell-primary, making cells the single source of truth. 8 phases.

| Phase | Description | Status | Key Commits |
|-------|-------------|--------|-------------|
| 0b | Cell metrics instrumentation | ✅ | `ffc5d26` |
| 1a–1d | Constraint store reads → cell | ✅ | `b11cce8` |
| 2pre–2c | Trait/hasmethod/capability reads → cell | ✅ | `6720408` |
| 3a–3c | Wakeup registry reads → cell | ✅ | `7fe5d5a` |
| 4a | Speculation alignment for cell-primary writes | ✅ | `3f1c69b` |
| 5a | Cell-primary writes with parameter fallback | ✅ | `2c6e237` |
| 6 | Network-everywhere: eliminate ALL parameter fallback | ✅ | `35fa4ae` |
| 7a–7b | Close cell coverage gaps (hasmethod wakeup, trait-cell-map) | ✅ | `b64321e` |

**Result**: Constraint tracking is fully cell-primary. No parameter fallback in any cell reader. PIR written (`c3dd49e`).

### Track 2: Reactive Constraint Resolution

Replaced imperative retry loops and batch post-passes with propagator-driven reactive resolution via stratified quiescence.

| Phase | Description | Status | Key Commits |
|-------|-------------|--------|-------------|
| D.1–D.6 | Design, iteration, review, baseline | ✅ | `061455e`..`91cf99d` |
| 1 | Instance registry cell reader | ✅ | `d8045b1` |
| 2 | Constraint status cells (monotone: resolved wins) | ✅ | `b4cdb1e` |
| 3 | Stratified quiescence architecture (S0→S1→S2) | ✅ | `4c0c927` |
| 4 | Action descriptors (free monad pattern) | ✅ | `e6aeafc` |
| 5–6 | Trait/hasmethod resolution propagators | ✅ | `4a91b24` |
| 7 | Error descriptor cell + grouped error reporting | ✅ | `510b77f` |
| 8 | Post-pass elimination (all `resolve-hasmethod-constraints!` removed) | ✅ | `8ff9cbe` |
| 9 | Confluence verification + HKT-7 ambiguity detection | ✅ | `5afbee8` |

**Result**: Resolution is fully reactive. No batch post-passes. Stratified quiescence loop with fuel=100. 6907 tests, 197.6s.

### Track 3: Cell-Primary Registries

Converted all 28 registry/accumulator computation reads from parameter-primary to cell-primary. Two-context architecture: elaboration reads cells, module loading reads parameters.

| Phase | Description | Status | Key Commits |
|-------|-------------|--------|-------------|
| 0 | Performance baseline + acceptance file | ✅ | `a5408f0`, `4ba09f4` |
| 1 | 8 core type registries + elaboration guard | ✅ | `a7f61ca` |
| 2 | 7 trait/instance registries | ✅ | `0880c4a` |
| 3 | 8 remaining registries (preparse, spec, strategy, etc.) | ✅ | `31ba07f` |
| 4 | 3 warning accumulators | ✅ | `c5c1681` |
| 5 | 2 narrowing constraints (new cells + elaboration guard) | ✅ | `9ebebdc` |
| 6 | Remove parameter writes + cleanup | ⏸️ | Deferred to Track 5/6 (see §Deferrals) |

**Result**: All computation reads are cell-primary. 28 readers, ~80 call sites converted. Two elaboration guard parameters (`current-macros-in-elaboration?`, `current-narrow-in-elaboration?`). Dual-write continues — parameter writes preserved for save/restore, batch-worker, and module loading. PIR: `2026-03-16_TRACK3_CELL_PRIMARY_REGISTRIES_PIR.md`. 7096 tests, 197.6s.

---

## Current Infrastructure

### Network Cells

11 infrastructure cells in `reset-meta-store!` (enet0–enet11):

| Cell | Content | Merge | Purpose |
|------|---------|-------|---------|
| enet1 | Constraint store (list) | `merge-list-append` | All constraints |
| enet2 | Trait constraints (hasheq) | `merge-hasheq-union` | Trait constraint map |
| enet3 | Trait cell map (hasheq) | `merge-hasheq-union` | Meta→cell mapping for traits |
| enet4 | HasMethod constraints (hasheq) | `merge-hasheq-union` | HasMethod constraint map |
| enet5 | Capability constraints (hasheq) | `merge-hasheq-union` | Capability constraint map |
| enet6 | Wakeup registry (hasheq→list) | `merge-hasheq-list-append` | Cell→constraint wakeup edges |
| enet7 | Trait wakeup map (hasheq→list) | `merge-hasheq-list-append` | Meta→callback wakeup edges |
| enet8 | HasMethod wakeup map (hasheq→list) | `merge-hasheq-list-append` | HasMethod wakeup edges |
| enet9 | Constraint status map (hasheq) | `merge-constraint-status-map` | Monotone: resolved wins |
| enet10 | HasMethod cell map (hasheq) | `merge-hasheq-union` | HasMethod meta→cell mapping |
| enet11 | Error descriptors (hasheq) | `merge-error-descriptor-map` | Last-write-wins per meta |

Plus additional cells via `register-*-cells!`:
- ~24 registry cells (`register-macros-cells!`) — schema, ctor, type-meta, subtype, coercion, capability, trait, trait-laws, impl, param-impl, bundle, specialization, selection, session, preparse, spec-store, propagated-specs, strategy, process, macro, property, functor, user-precedence-groups, user-operators
- 3 warning cells (`register-warning-cells!`) — coercion, deprecation, capability warnings
- 2 narrowing cells (`register-narrow-cells!`, Track 3) — narrow-constraints (`merge-list-append`), narrow-var-constraints (`merge-last-write-wins`)
- Per-definition global-env cells, module registry cells, ns-context cells
- Per-metavariable cells from elaboration

### Cell Read Paths

| Subsystem | Read Path | Status |
|-----------|-----------|--------|
| Constraint store | Cell-primary | ✅ Track 1 |
| Trait/hasmethod/capability constraints | Cell-primary | ✅ Track 1 |
| Wakeup registries | Cell-primary | ✅ Track 1 |
| Instance registry (`read-impl-registry`) | Cell-primary | ✅ Track 2 Phase 1 |
| 23 macros.rkt registries (schema, ctor, trait, impl, etc.) | Cell-primary (elaboration), parameter (module loading) | ✅ Track 3 Phases 1–3 |
| Warnings (coercion, deprecation, capability) | Cell-primary | ✅ Track 3 Phase 4 |
| Narrowing constraints | Cell-primary (elaboration), parameter (direct tests) | ✅ Track 3 Phase 5 |
| Global environment | Two-layer (cell Layer 1, param Layer 2) | 🔄 Partial — Track 5 |

**Note**: "Cell-primary" for Track 3 registries means cell reads during elaboration (guarded by `current-macros-in-elaboration?` or `current-narrow-in-elaboration?`), with parameter fallback during module loading. Dual-write continues — parameter writes are NOT removed (blocked by save/restore and batch-worker dependencies; deferred to Track 5/6). See §Deferrals.

### Speculation

`with-speculative-rollback` → `save-meta-state`/`restore-meta-state!` (box-snapshot pattern). 4 call sites in `typing-core.rkt`. ATMS infrastructure exists but is not used for speculation.

### Dirty Flags

`current-retry-trait-resolve` and `current-retry-unify` still present (14 references in `metavar-store.rkt`). Functionally superseded by stratified quiescence but not yet removed.

---

## Remaining Tracks

### Track 3: Cell-Primary Registries — ✅ COMPLETE

Moved to §Completed Work above. See Track 3 PIR for full review.

**Key residual**: Phase 6 (parameter write removal) deferred to Tracks 5/6. Dual-write continues because `save-meta-state`/`restore-meta-state!` and `batch-worker.rkt` still read parameters. See §Deferrals.

### Track 4: ATMS Speculation

**Goal**: Replace `save-meta-state`/`restore-meta-state!` box-snapshot pattern with ATMS assumption creation/retraction. Speculative type-checking (Church folds, union types, bare params) creates named assumptions; failure retracts them.

**Scope**: 4 call sites of `with-speculative-rollback` in `typing-core.rkt`. The ATMS infrastructure (`atms.rkt`, `infra-cell.rkt` assumption API) already exists from Migration Sprint Phase 0b.

**Risk**: Medium — speculation is the most delicate part of the type checker, but the call sites are well-tested and few.

**Composition synergy**: Eliminates the fragile 6-box snapshot pattern that must be updated whenever new state is added. ATMS nogoods from failed speculations become permanent learned clauses. Enables the "dependency-directed backjumping" described in the Whole-System Migration Thesis §2.3.

**Depends on**: Track 3 ✅ (registries are cell-primary; ATMS retraction covers them). Track 4 is unblocked.

**Files**: `elab-speculation-bridge.rkt`, `typing-core.rkt`, `metavar-store.rkt`.

**Design document**: TBD — create before implementation.

### Track 5: Global-Env Cell-Primary + Dependency Edges

**Goal**: Complete the cell-primary conversion for global environment reads. Wire per-definition dependency tracking as propagator edges, enabling incremental re-elaboration (the "biggest payoff" from the Pipeline Audit).

**Scope**:
- Convert remaining `(current-global-env)` reads to `global-env-lookup-*` (36 references in `driver.rkt`)
- Wire `current-definition-dependencies` as propagator edges between definition cells
- Incremental invalidation: when a definition cell changes, downstream definitions re-elaborate
- **Per-module network context for module loading** — enables module loading to run with a network, eliminating the two-context architecture's parameter fallback (absorbs part of Track 3's deferred Phase 6)

**Risk**: High — `current-global-env` is the backbone of the pipeline. The two-layer architecture (Migration Sprint Phase 3a–3d) de-risked the structural change, but full cell-primary conversion touches the hottest code paths.

**Composition synergy**: This is the "incremental module re-elaboration" synergy from Pipeline Audit §5.2. Combined with ATMS (Track 4), enables the LSP to retract a definition assumption and let propagation settle rather than re-elaborating the entire file.

**Absorbed from Track 3 Phase 6**: Per-module networks would eliminate the module-loading parameter fallback in all 28 cell-primary readers, collapsing the two-context architecture to a single cell-primary context.

**Depends on**: Track 4 (ATMS for non-monotonic definition replacement).

**Files**: `global-env.rkt`, `driver.rkt`, `elaborator.rkt`, `namespace.rkt`.

**Design document**: TBD — create before implementation.

### Track 6: Driver Simplification + Cleanup

**Goal**: With Tracks 3–5 complete, simplify the driver's per-command `parameterize` block, remove dirty flags, and clean up vestigial infrastructure.

**Scope**:
- Simplify per-command parameterize (Migration Sprint Phase 5a–5b)
- Remove `current-retry-trait-resolve` and `current-retry-unify` dirty flags
- Remove narrowing constraint parameter workarounds (cells now exist from Track 3 Phase 5)
- `reset-meta-store!` becomes assumption management rather than wholesale state wipe
- **Remove dual-write parameter writes** — with Track 5's per-module networks and Track 4's ATMS-based snapshots, `save-meta-state`/`restore-meta-state!` and `batch-worker.rkt` can capture cell content instead of parameters. This is the completion of Track 3's deferred Phase 6.
- **Remove elaboration guard parameters** — once all contexts (including module loading) have networks, `current-macros-in-elaboration?` and `current-narrow-in-elaboration?` become unnecessary

**Risk**: Low (by this point, all the hard structural work is done).

**Depends on**: Tracks 3 ✅, 4, 5.

**Absorbed from Track 3 Phase 6**: Parameter write removal for all 28+ registries, plus guard parameter cleanup. This is the final step in the dual-write → cell-only migration path.

**Files**: `driver.rkt`, `metavar-store.rkt`, `global-constraints.rkt`, `macros.rkt`, `warnings.rkt`, `batch-worker.rkt`.

**Design document**: TBD — likely lightweight, mostly cleanup tasks.

### Track 7: QTT Multiplicity Cells (P5)

**Goal**: Bring QTT multiplicity operations into the elaboration network with cross-domain bridges (type ↔ multiplicity). Architectural unification — the mult lattice (m0 < m1 < mw) is tiny but connecting it to the propagator network enables cross-domain reasoning.

**Scope**: New `mult-lattice.rkt` module, multiplicity cells in elaboration network, cross-domain bridge propagators.

**Risk**: Low — tiny lattice, well-understood semantics.

**Composition synergy**: Cross-domain bridge enables session type ↔ multiplicity propagation. Foundation for the Galois connection architecture described in the Whole-System Migration Thesis.

**Depends on**: Track 6 (clean driver baseline).

**Design reference**: `docs/tracking/2026-03-04_PROPAGATOR_MIGRATION_GDE.md` § Track 3 (P5).

**Design document**: TBD.

### Track 8: Unification as Propagators (P1-G)

**Goal**: Replace imperative `unify` with a `unify*` wrapper that runs quiescence after each unification, enabling transitive propagation. 123 call sites across 11 files.

**Risk**: Very high — unification is the core of the type checker.

**Approach**: Thin wrapper, NOT algorithm rewrite. Design complete in GDE roadmap.

**Composition synergy**: Completes the picture: every type-checking operation flows through propagators. Enables the GDE (General Diagnostic Engine) for multi-hypothesis conflict analysis.

**Depends on**: Track 7 (mult cells provide the cross-domain bridge unification needs).

**Design reference**: `docs/tracking/2026-03-04_PROPAGATOR_MIGRATION_GDE.md` § Track 4 (P1-G).

**Design document**: TBD — full design required given risk level.

### Track 9: General Diagnostic Engine (GDE)

**Goal**: Multi-hypothesis conflict analysis using ATMS nogoods. Minimal diagnoses for type errors. The culmination of the propagator migration — the compiler doesn't just report errors, it explains the minimal set of assumptions that caused them.

**Risk**: High — new capability, not a migration.

**Depends on**: Track 8 (P1-G), Track 4 (ATMS speculation).

**Design reference**: `docs/tracking/2026-03-04_PROPAGATOR_MIGRATION_GDE.md` § GDE.

**Design document**: TBD.

---

## Track Dependency Graph

```
Track 3 (Cell-Primary Registries) ✅
  │
  ├──→ Track 4 (ATMS Speculation)          ← unblocked
  │      │
  │      └──→ Track 5 (Global-Env + Per-Module Networks)
  │             │
  │             └──→ Track 6 (Driver Simplification + Dual-Write Removal)
  │                    │
  │                    └──→ Track 7 (QTT Multiplicity Cells)
  │                           │
  │                           └──→ Track 8 (Unification as Propagators)
  │                                  │
  │                                  └──→ Track 9 (GDE)
  │
  └─ ─ ─ Phase 6 deferred ─ ─ ─→ Track 5 (per-module networks)
                                   Track 6 (parameter write removal)
```

Track 4 is now unblocked (Track 3 complete). The dashed line shows Track 3's deferred Phase 6 flowing into Tracks 5 and 6.

---

## Deferrals

Active deferrals that affect future track scope:

### Track 3 Phase 6 → Tracks 5/6: Dual-Write Parameter Elimination

**What**: Removing parameter writes from `register-X!` functions and removing the elaboration guard parameters. Currently all 28+ registries write to both cells and parameters.

**Why deferred**: Three consumers still depend on parameter reads:
1. **`save-meta-state`/`restore-meta-state!`** — captures parameters for speculation rollback. Must migrate to cell-based snapshots (Track 4/5).
2. **`batch-worker.rkt`** — captures parameters for worker state isolation. Must migrate to cell-based capture (Track 6).
3. **Module loading** — runs without a network; parameter IS the correct state. Must gain per-module networks (Track 5).

**Impact on Tracks 5/6**: Track 5 should include per-module network creation as a goal (not just global-env reads). Track 6 should include dual-write removal and guard parameter cleanup as explicit scope items.

**Risk if never addressed**: Ongoing conceptual overhead (maintainers must understand dual-write). Every new registry must follow the dual-write pattern. Performance impact is negligible (~1%).

### Migration Sprint Phases 3e, 5a–5b: Deferred from Foundation

| Phase | Description | Why Deferred | Absorbs Into |
|-------|-------------|-------------|--------------|
| 3e | Reduction cache cells | LSP-specific, not needed for batch mode | Track 5 or standalone |
| 5a–5b | Driver simplification | Requires cell-primary reads first | Track 6 |

---

## Performance Baseline

| Milestone | Tests | Files | Time |
|-----------|-------|-------|------|
| Pre-migration (2026-03-11) | 6803 | 353 | 208.6s |
| Post-Migration Sprint Phase 4 | 6826 | 354 | ~200s |
| Post-Track 1 | 6888 | 358 | 191.4s |
| Post-Track 2 Phase 9 | 6907 | 359 | 197.6s |
| Post-Track 3 (current) | 7096 | 370 | 197.6s |

Migration has been performance-neutral to slightly positive despite adding cell infrastructure. Each track should maintain this invariant. The test count increase (6907→7096) between Track 2 and Track 3 is from non-propagator work (WFLE, D4 Provenance, etc.) in the intervening interval.

---

## Design Methodology

Each track follows the established pattern:

1. **Design document** — analysis, formal grounding, open questions, phase breakdown with progress tracker
2. **External review integration** — critique points accepted/rejected with rationale
3. **Performance baseline** — capture before Phase 1
4. **Implementation** — sub-phases with immediate commits per workflow rules
5. **Post-Implementation Review** — honest assessment, lessons learned
6. **Dailies/standup updates** — track progress in living documents

The Layered Recovery Principle (demonstrated in Tracks 1 and 2): if a phase reveals unexpected complexity, the dual-write/shadow pattern allows safe retreat. Each phase must leave the system in a working state with all tests passing.
