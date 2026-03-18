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
| Track 4 Design | `docs/tracking/2026-03-16_TRACK4_ATMS_SPECULATION.md` | ATMS speculation design + phase plan |
| Track 4 PIR | `docs/tracking/2026-03-16_TRACK4_ATMS_SPECULATION_PIR.md` | Post-implementation review |
| Track 5 Design | `docs/tracking/2026-03-16_TRACK5_GLOBAL_ENV_DEPENDENCY_EDGES.md` | Global-env consolidation + dependency edges design |
| Track 5 PIR | `docs/tracking/2026-03-16_TRACK5_GLOBAL_ENV_DEPENDENCY_EDGES_PIR.md` | Post-implementation review |
| Track 6 Design | `docs/tracking/2026-03-16_TRACK6_DRIVER_SIMPLIFICATION.md` | Driver simplification + cleanup design |
| Track 6 PIR | `docs/tracking/2026-03-17_TRACK6_DRIVER_SIMPLIFICATION_PIR.md` | Post-implementation review |
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

### Track 4: ATMS Speculation

Integrated TMS (Truth Maintenance System) cells into the propagator network for speculation-aware type inference. All four meta types (type, level, mult, session) now have per-meta TMS cells. Learned-clause pruning skips branches known to be inconsistent.

| Phase | Description | Status | Key Commits |
|-------|-------------|--------|-------------|
| D.1–D.5 | Design analysis, iteration, self-critique, lattice-theoretic rework | ✅ | `cf4001b`..`ae82836` |
| 0 | Performance baseline + acceptance file | ✅ | `50b00d8` |
| 1 | TMS cell infrastructure (struct, read/write/commit/merge) | ✅ | `ecde661` |
| 2 | TMS-transparent read/write + domain-aware merge | ✅ | `10ecb0c` |
| 3 | Level/mult/session metas → per-meta TMS cells; save/restore 6→3 boxes | ✅ | `addaf46` |
| 4 | Meta-info CHAMP → write-once registry; save/restore → 1 box | ⏸️ | Deferred to Track 6 (see §Deferrals) |
| 5 | Learned-clause pruning via `atms-consistent?` | ✅ | `f0f72da` |
| 6–7 | Performance validation + PIR | ✅ | `62ecb3f` |

**Result**: Per-meta TMS cells for all 4 meta types (type, level, mult, session). `save-meta-state` reduced from 6 boxes to 3 (network + id-map + meta-info). Depth-0 fast path makes TMS cells zero-overhead for the common case. Learned-clause pruning infrastructure operational. Belt-and-suspenders: network-box restore handles rollback during Phases 2–5; speculation stack push and TMS retraction deferred to Track 6. PIR: `2026-03-16_TRACK4_ATMS_SPECULATION_PIR.md`. 7124 tests, 187.1s (2.4% faster than baseline).

### Track 5: Global-Env Consolidation + Dependency Edges

Converted `current-global-env` from parameter-primary to a two-layer cell architecture with persistent per-module networks and cross-module dependency edges. Infrastructure for LSP incremental re-elaboration.

| Phase | Description | Status | Key Commits |
|-------|-------------|--------|-------------|
| D.1–D.3 | Design: persistent module networks, lifecycle lattice, shadow-cell prototype, principle alignment | ✅ | `339fedb`..`9febbb5` |
| 0 | Performance baseline + acceptance file (294 expressions, 12 BUGs) | ✅ | `157f7aa` |
| 1 | Module-network-ref infrastructure + shadow-cell prototype (15 tests) | ✅ | `7ad5b88` |
| 2 | `global-env-remove!` + failure cleanup consolidation (6 sites → 1) | ✅ | `085b77d` |
| 3 | Per-module network activation + dual-path validation (0 mismatches across 200+ modules) | ✅ | `011fe3f` |
| 4 | Cross-module dependency edge recording (same-file + module provenance) | ✅ | `b70331a` |
| 5 | Write consolidation: `global-env-add` self-updates, 22 env-threading wrappers eliminated, dual-path validation removed | ✅ | `1fb01ea` |
| 6 | Performance validation (213.3s, +14% within 25% threshold) | ✅ | — |

**Result**: Each loaded module has a persistent `module-network-ref` (one cell per definition, lifecycle status cell, materialized snapshot, dep-edges map). `global-env-add` is self-updating — callers never need env-threading wrappers. Cross-module dependency edges record source provenance (`'same-file` vs `'module`). Dual-path validation confirmed 0 cell/hash mismatches across ~1.4M checks before removal. 24 new unit tests. PIR: `2026-03-16_TRACK5_GLOBAL_ENV_DEPENDENCY_EDGES_PIR.md`. 7148 tests, 213.3s.

**Key residual**: TMS-ready `definition-dep-wire!` with propagator wiring (Phase 4c) and staleness propagation (Phase 4d) deferred to LSP scope.

### Track 6: Driver Simplification + Cleanup

Absorbed deferred work from Tracks 3, 4, and 5. Eliminated transitional scaffolding, completed the architectural cutover from parameter-primary to propagator-primary infrastructure, and achieved the first clean test suite (0 failures).

Two workstreams: **WS-A** (Data Orientation + TMS Retraction, high-risk) executed first, **WS-B** (Cleanup + Lookup Cutover) followed.

| Phase | Description | Status | Key Commits |
|-------|-------------|--------|-------------|
| D.1+–D.3 | Design, external critique, self-critique | ✅ | `60f7b77`..`1c63210` |
| 0 | Acceptance file (278 evals, 0 errors) | ✅ | `7cd1ad6` |
| 1a | id-map → elab-network field (3→2 box) | ✅ | `9677970` |
| 1b | meta-info `#:mutable` removal (vestigial) | ✅ | `39421e6` |
| 1c | Constraint status → functional CHAMP updates | ✅ | `e88c2b2` |
| 1d | all-unsolved-metas → infrastructure cell | ✅ | `a82e4d2` |
| 2+3 | Speculation stack push + commit-on-success | ✅ | `4a08db6` |
| 4 | TMS retraction + nested speculation support | ✅ | `acc76e4` |
| 5a | meta-info CHAMP → elab-network field (2→1 box) | ✅ | `9358b67` |
| 5b | Belt-and-suspenders retirement gate | ⏸️ | Deferred to Track 7 (TMS-aware infra cells needed) |
| 6 | batch-worker → snapshot-based state | ✅ | `25d7b20` |
| 7a | test-support.rkt network isolation + shadow validation | ✅ | `92a27b0` |
| 7b-c | Macros/warnings dual-write: assessed as natural persistence+propagation pattern (Track 5 model) | ✅ | `70063b9` (revert of erroneous elimination) |
| 7d | Module-network-ref lookup cutover (`current-module-definitions-content` as primary) | ✅ | `cd54a9f`, `78bba78` |
| 8a-c | Elaboration guard removal + net-box scoping | ✅ | `6fa6240` |
| 8d | Callback cleanup: immediate paths removed, dead functions/params removed | ✅ | `6793ce5` |
| 9 | Rename `current-global-env` → `current-prelude-env` (994 occurrences, 271 files) | ✅ | `36588ee` |
| 10 | Parameterize simplification (30→13 bindings) | ✅ | — (assessed: all remaining bindings necessary) |
| BUG | ATMS lazy init: first clean suite (0 failures) | ✅ | `ebc781e` |
| 11 | Performance validation + PIR | ✅ | `e43bc9c` |

**Result**: 52 commits, +7540/−1414 lines, 294 files. Save/restore reduced from 3→1 box. Per-command parameterize from ~30→13 bindings. Elaboration guards eliminated. Definition lookups go through `current-module-definitions-content` (sourced from Track 5 module-network-ref cells). Dead code and vestigial callbacks cleaned up. **7154 tests, 0 failures, 235.2s** — first clean suite.

**Key architectural insights**:
- **Dual-write is persistence + propagation, not redundancy** — parameter writes for macros/warnings registries serve the same role as Track 5's `current-definition-cells-content`. Both writes are needed until cells themselves become persistent.
- **Stratified propagator networks** — each resolution stratum as a propagator layer with inter-stratum Galois connections. Readiness becomes a cell value, resolution becomes a propagator fire function. Captured in DESIGN_PRINCIPLES.org and DEVELOPMENT_LESSONS.org.
- **Callbacks are a propagator-first anti-pattern** — resolution logic should be IN the network, not injected via imperative callback parameters.
- **Lazy initialization > mandatory initialization for correct-by-construction** — the ATMS bug persisted across 5 tracks because `with-speculative-rollback` required explicit init.

**Key residuals**: Phase 5b (belt-and-suspenders retirement gate) → Track 7. Callback inlining (module restructuring) → Track 7. Layer 2 write elimination → low-priority follow-up. PIR: `2026-03-17_TRACK6_DRIVER_SIMPLIFICATION_PIR.md`.

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
- Per-module `module-network-ref` cells (Track 5): one definition cell per exported name + `mod-status` lifecycle cell per module
- Per-metavariable cells from elaboration

### Cell Read Paths

| Subsystem | Read Path | Status |
|-----------|-----------|--------|
| Constraint store | Cell-primary | ✅ Track 1 |
| Trait/hasmethod/capability constraints | Cell-primary | ✅ Track 1 |
| Wakeup registries | Cell-primary | ✅ Track 1 |
| Instance registry (`read-impl-registry`) | Cell-primary | ✅ Track 2 Phase 1 |
| 23 macros.rkt registries (schema, ctor, trait, impl, etc.) | Cell-primary (unconditional — no guards), parameter (module loading) | ✅ Track 3 + Track 6 Phase 8 |
| Warnings (coercion, deprecation, capability) | Cell-primary (unconditional) | ✅ Track 3 + Track 6 Phase 8 |
| Narrowing constraints | Cell-primary (unconditional) | ✅ Track 3 + Track 6 Phase 8 |
| Definition lookups | Three-layer: Layer 1 cells (per-file), `current-module-definitions-content` (from module-network-ref), `current-prelude-env` (belt-and-suspenders fallback) | ✅ Track 5 + Track 6 Phase 7d |
| Module networks | Persistent `module-network-ref` per loaded module; dep-edges with provenance; authoritative source for definition lookups via module-definitions-content | ✅ Track 5 + Track 6 Phase 7d |

**Note**: Track 6 removed elaboration guards (`current-macros-in-elaboration?`, `current-narrow-in-elaboration?`). Cell reads are now unconditional — net-box parameters scoped to command parameterize provide structural isolation (auto-revert to `#f` after command). Dual-write continues for macros/warnings registries — parameter writes are persistence, cell writes are propagation (same pattern as Track 5's `global-env-add`). See Track 6 PIR §5.2.

### Speculation

`with-speculative-rollback` → `save-meta-state`/`restore-meta-state!` (1-box snapshot: network only — Track 6 reduced from 3). 4 call sites in `typing-core.rkt`. ATMS hypothesis creation per speculation for error tracking (nogoods recorded on failure). Per-meta TMS cells support assumption-tagged branching with depth-0 fast path (zero overhead at speculation depth 0). Learned-clause pruning via `atms-consistent?` skips branches subsumed by known nogoods. TMS retraction (Track 6 Phases 2+3, 4) replaces network-box restore for value-level branching. Belt-and-suspenders: network-box restore still active for infrastructure cells (Phase 5b blocker → Track 7). Lazy ATMS initialization (Track 6 BUG fix): `with-speculative-rollback` creates ATMS on demand — correct-by-construction regardless of entry path.

### Dirty Flags / Callbacks

`current-retry-trait-resolve`, `current-retry-hasmethod-resolve`, and `current-retry-unify` — callback parameters present but vestigial. Immediate resolution paths at registration time removed (Track 6 Phase 8d). The stratified quiescence loop (Track 2) is the sole load-bearing resolution mechanism. The callbacks are invoked FROM the loop, not alongside it. Dead functions removed. Callback inlining (replacing indirection with direct calls via module restructuring) scoped to Track 7 as stepping stone toward stratified propagator network architecture.

---

## Remaining Tracks

### Track 3: Cell-Primary Registries — ✅ COMPLETE

Moved to §Completed Work above. See Track 3 PIR for full review.

**Key residual**: Phase 6 (parameter write removal) deferred to Tracks 5/6. Dual-write continues because `save-meta-state`/`restore-meta-state!` and `batch-worker.rkt` still read parameters. See §Deferrals.

### Track 4: ATMS Speculation — ✅ COMPLETE

Moved to §Completed Work above. See Track 4 PIR for full review.

**Key residual**: Phase 4 (meta-info CHAMP → write-once registry; save/restore → 1 box) deferred to Track 6. See §Deferrals.

### Track 5: Global-Env Consolidation + Dependency Edges — ✅ COMPLETE

Moved to §Completed Work above. See Track 5 PIR for full review.

**Key residuals**: TMS-ready `definition-dep-wire!` (Phase 4c) and staleness propagation (Phase 4d) deferred to LSP scope. `current-global-env` → `current-prelude-env` rename deferred to Track 6. Dual-write parameter elimination deferred to Track 6. See §Deferrals.

### Track 6: Driver Simplification + Cleanup — ✅ COMPLETE

Moved to §Completed Work above. See Track 6 PIR for full review.

**Key residuals**: Phase 5b (belt-and-suspenders retirement gate) → Track 7. Callback inlining → Track 7. Layer 2 write elimination → low-priority follow-up. See §Deferrals.

**Track 5 D.3 forward notes** (carried forward):
- **TMS-aware parameterized modules** — module definition cells as TMS cells for multi-context sharing (same module, different assumptions e.g. different parameter contexts in LSP). Track 5 designed API compatibility (`#:tms?` flag on `make-module-network`). Scope: Track 7 or Track 10.
- **Correct-by-construction cross-network consistency** — Track 5's shadow-cell + callback pattern can diverge in multi-invocation contexts (LSP). Track 10 scope.

### Track 7: QTT Multiplicity Cells + TMS Architecture (P5)

**Goal**: Two workstreams:
1. **QTT Multiplicity Cells**: Bring QTT multiplicity operations into the elaboration network with cross-domain bridges (type ↔ multiplicity). The mult lattice (m0 < m1 < mw) is tiny but connecting it to the propagator network enables cross-domain reasoning.
2. **TMS-Aware Infrastructure + Stratified Prop-Net Architecture**: Extend TMS to support set-like accumulation with per-assumption retraction, enabling belt-and-suspenders retirement (Track 6 Phase 5b blocker). Also: inline callback resolution logic into the stratified loop, replacing imperative callbacks with propagator-driven resolution — stepping stone to stratified propagator networks (see DESIGN_PRINCIPLES.org § "Stratified Propagator Networks").

**Scope**:
- WS-A (QTT): New `mult-lattice.rkt` module, multiplicity cells in elaboration network, cross-domain bridge propagators.
- WS-B (TMS Architecture): Infrastructure cells (constraint store, unsolved-metas) → TMS-aware accumulation with retraction. Structural fields (meta-info, id-map, next-meta-id) → TMS-managed or separate rollback. Callback inlining: move resolution logic from driver.rkt callbacks into `execute-resolution-actions!` directly, breaking circular deps via module restructuring. Belt-and-suspenders retirement gate (Track 6 Phase 5b) as validation.

**Risk**: WS-A low (tiny lattice). WS-B medium (TMS accumulation with retraction is new architecture — no existing TMS supports set-like retraction natively).

**Composition synergy**: Cross-domain bridge enables session type ↔ multiplicity propagation. TMS-aware infrastructure enables full incremental rollback — prerequisite for Track 8 (unification as propagators) where speculation correctness is load-bearing. Stratified prop-net architecture is the foundation for correct-by-construction resolution without defensive scanning.

**Depends on**: Track 6 (clean driver baseline).

**Design reference**: `docs/tracking/2026-03-04_PROPAGATOR_MIGRATION_GDE.md` § Track 3 (P5). Track 6 Phase 5b blocker analysis. Track 6 Phase 8d audit (callback vestigiality). DESIGN_PRINCIPLES.org § "Stratified Propagator Networks" + DEVELOPMENT_LESSONS.org § "Callbacks Are a Propagator-First Anti-Pattern".

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

### Track 10: LSP Integration

**Goal**: Integrate the full propagator infrastructure into a Language Server Protocol implementation. Incremental re-elaboration, live diagnostics, and enhanced error reporting — the user-facing payoff of Tracks 1–9.

**Scope**:
- **Incremental re-elaboration** — use Track 5's dep-edges and persistent module networks to identify and re-check only the definitions affected by a source change, rather than re-elaborating entire files
- **Shadow-cell materialization** — create shadow cells in importing modules for cross-module references, enabling change propagation across module boundaries (Track 5 prototype → production)
- **Module staleness propagation** — wire `mod-stale` status changes through the dep-edge graph to downstream module networks (Track 5 Phases 4c–4d, deferred to this track)
- **TMS-aware parameterized modules** — module definition cells as TMS cells for multi-context sharing (same module, different parameter contexts in LSP); Track 5 designed API compatibility, Track 6 implements TMS retraction, this track consumes both
- **GDE-powered diagnostics** — surface Track 9's minimal diagnoses through LSP diagnostic messages; explain *why* errors occur, not just *where*
- **Data-oriented invalidation** — invalidation *descriptors* (e.g., `(stale-module bar '(map filter fold))`) interpreted at explicit control boundaries, enabling logging, batching, and deduplication per the Data Orientation principle
- **Correct-by-construction cross-network consistency** — replace Track 5's shadow-cell + callback sketch with structural guarantees for keeping shadow cells consistent with source module cells in multi-invocation contexts

**Risk**: Moderate — new capability, but built entirely on proven infrastructure from Tracks 1–9. The risk is in the *composition* (making all the pieces work together in a long-running server process) rather than in any individual component.

**Composition synergy**: This is the culmination of the propagator migration's user-facing value. Every preceding track contributes:
- Track 1–3: Cell-primary reads (stable observation substrate)
- Track 4: TMS cells + learned-clause pruning (speculation-aware incremental checking)
- Track 5: Persistent module networks + dep-edges (incremental invalidation graph)
- Track 6: Clean single-write-path architecture (no dual-write complexity in server)
- Track 7: Cross-domain bridges (multiplicity-aware diagnostics)
- Track 8: Propagator-driven unification (reactive type error updates)
- Track 9: GDE minimal diagnoses (root-cause error explanations)

**Depends on**: Track 9 (GDE), Track 5 ✅ (dep-edges, module networks).

**Design document**: TBD — full design required. Should address: server lifecycle, file watcher integration, incremental vs full re-elaboration heuristics, diagnostic batching/debouncing, and the composition of all Track 1–9 infrastructure.

**Forward design notes** (from Track 5 D.3 principle alignment review):
- **First-class module network data** — module networks should be treated as first-class pure data, enabling reuse and composition. The CHAMP-based `prop-network` is already immutable/persistent, supporting this. Design for module networks as composable data structures, not just caching artifacts.
- **Data-oriented invalidation** — use invalidation descriptors interpreted at explicit control boundaries rather than imperative "iterate and write" patterns.

---

## Track Dependency Graph

```
Track 3 (Cell-Primary Registries) ✅
  │
  ├──→ Track 4 (ATMS Speculation) ✅
  │      │
  │      └──→ Track 5 (Global-Env + Per-Module Networks) ✅
  │             │
  │             └──→ Track 6 (Driver Simplification + Cleanup) ✅
  │                    │
  │                    └──→ Track 7 (QTT Mult Cells + TMS Architecture)    ← next
  │                           │
  │                           └──→ Track 8 (Unification as Propagators)
  │                                  │
  │                                  └──→ Track 9 (GDE)
  │                                         │
  │                                         └──→ Track 10 (LSP Integration)
  │                                                ↑
  │                                                │
  Track 5 (dep-edges, module networks) ✅ ─ ─ ─ ─ ┘
  │
  ├─ ─ ─ Track 6 Phase 5b ─ ─ ─ ─ ─ ─→ Track 7 (TMS-aware infra cells,
  │                                       belt-and-suspenders retirement)
  │
  ├─ ─ ─ Track 6 Phase 8d ─ ─ ─ ─ ─ ─→ Track 7 (callback inlining →
  │                                       stratified prop-net stepping stone)
  │
  └─ ─ ─ Track 5 deferrals ─ ─ ─ ─ ─ ─→ Track 10 (dep-wire!, staleness propagation)
```

Track 7 is now unblocked (Tracks 3–6 complete). Track 10 depends on Track 9 (GDE) and Track 5 (already complete). Dashed lines show deferred phases flowing into future tracks.

---

## Deferrals

Active deferrals that affect future track scope:

### ~~Track 3 Phase 6 → Track 6: Dual-Write Parameter Elimination~~ — RESOLVED

**Resolution**: Track 6 Phase 8b-c removed elaboration guards. Phase 9 completed the rename. Track 6 PIR §5.2 determined that parameter writes for macros/warnings registries are NOT redundant dual-writes — they are the persistent data store (same pattern as Track 5's `global-env-add`). Dual-write continues by design until cells themselves become persistent across commands.

### ~~Track 4 Phase 4 → Track 6: Meta-Info Simplification + Full TMS Retraction~~ — RESOLVED

**Resolution**: Track 6 delivered the full chain:
- Phase 1a: id-map → elab-network field (3→2 box)
- Phase 1c-d: Constraint status → functional CHAMP; all-unsolved-metas → infrastructure cell
- Phase 2+3: Speculation stack push + commit-on-success
- Phase 4: TMS retraction + nested speculation
- Phase 5a: meta-info CHAMP → elab-network field (2→1 box)
- **Result**: save/restore reduced from 3→1 box (network only)
- **Remaining**: Phase 5b blocked — TMS retraction insufficient for infrastructure cells (set-like accumulation). Carried to Track 7.

### Track 5 Phases 4c–4d → Track 10: TMS-Ready Wiring + Staleness Propagation

**What**: `definition-dep-wire!` with real propagator wiring (Phase 4c) and staleness propagation to `mod-status` cells (Phase 4d). Currently dep-edges are recorded as data but not wired as active propagators.

**Why deferred**: Batch mode doesn't need active wiring — modules never become stale during a single batch compilation. The wiring and staleness propagation are LSP concerns (detecting when a source file changes and propagating invalidation through the dep-edge graph).

**Current state**: Track 5 records dep-edges with source provenance (`'same-file` vs `'module`) in each `module-network-ref`. The data is complete; the active consumption is Track 10 (LSP) scope.

**Impact on Track 10**: Track 10 consumes Track 5's dep-edges directly. No intermediate track work needed.

### ~~Track 5 → Track 6: Rename + Dual-Write Removal~~ — RESOLVED

**Resolution**: Track 6 Phase 9 completed the rename (994 occurrences, 271 files). Track 6 Phase 7d completed the lookup cutover to `current-module-definitions-content` (sourced from module-network-ref). Layer 2 (`current-prelude-env`) retained as belt-and-suspenders fallback — low-priority removal.

### Track 6 Phase 5b → Track 7: Belt-and-Suspenders Retirement Gate

**What**: Removing the belt-and-suspenders network-box restore that coexists with TMS retraction. Currently both mechanisms are active — TMS retraction handles value-level rollback, network-box restore handles infrastructure cells.

**Why deferred**: TMS retraction works for value-level cells but fails for infrastructure cells (constraint store, wakeup registries) that use set-like accumulation. These cells need TMS-aware accumulation with per-assumption retraction — a new TMS capability.

**Impact on Track 7**: Track 7 WS-B explicitly scopes TMS-aware infrastructure cells as the solution.

### Track 6 Phase 8d → Track 7: Callback Inlining + Stratified Prop-Net Architecture

**What**: Replace the 3 callback parameters (`current-retry-trait-resolve`, `current-retry-hasmethod-resolve`, `current-retry-unify`) with direct function calls by restructuring module dependencies. Stepping stone to the full stratified propagator network architecture.

**Why deferred**: The immediate paths are removed and the callbacks are identified as vestigial (Track 6 Phase 8d deep audit). But inlining requires module restructuring to break the circular dep between driver.rkt and metavar-store.rkt. The architectural target (stratified prop-nets) is Track 7+ scope.

**Design reference**: DESIGN_PRINCIPLES.org § "Stratified Propagator Networks", DEVELOPMENT_LESSONS.org § "Callbacks Are a Propagator-First Anti-Pattern", Track 6 PIR §5.6 and §6.4.

### Migration Sprint Phases 3e, 5a–5b: Deferred from Foundation

| Phase | Description | Why Deferred | Absorbs Into |
|-------|-------------|-------------|--------------|
| 3e | Reduction cache cells | LSP-specific, not needed for batch mode | Track 5 or standalone |
| 5a–5b | Driver simplification | Requires cell-primary reads first | Track 6 |

---

## Performance Baseline

| Milestone | Tests | Files | Time | Failures |
|-----------|-------|-------|------|----------|
| Pre-migration (2026-03-11) | 6803 | 353 | 208.6s | 0 |
| Post-Migration Sprint Phase 4 | 6826 | 354 | ~200s | 0 |
| Post-Track 1 | 6888 | 358 | 191.4s | 0 |
| Post-Track 2 Phase 9 | 6907 | 359 | 197.6s | 0 |
| Post-Track 3 | 7096 | 370 | 197.6s | 2-3 (ATMS) |
| Post-Track 4 | 7124 | 371 | 187.1s | 2-3 (ATMS) |
| Post-Track 5 | 7148 | 372 | 213.3s | 2-3 (ATMS) |
| **Post-Track 6 (current)** | **7154** | **372** | **235.2s** | **0** |

Migration has been performance-neutral through Track 4. Track 5 added +14% overhead (187.1s→213.3s) from module-network-ref construction per module load. Track 6 added an additional +10% (213.3s→235.2s) from the module-definitions-content population at import time. Cumulative from pre-migration: 208.6s→235.2s (+13%). Still within the 25% threshold. The test count increase (6907→7096) between Track 2 and Track 3 is from non-propagator work (WFLE, D4 Provenance, etc.) in the intervening interval. Track 4 achieved a 2.4% speedup (191.6s→187.1s) from reducing save/restore from 6 to 3 boxes.

**Suite health milestone**: Track 6 achieved the **first clean test suite** — 0 failures. The 2-3 ATMS initialization failures that persisted from Track 3 through Track 5 were fixed by lazy ATMS initialization (3-line fix, commit `ebc781e`). See Track 6 PIR §4.4.

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
