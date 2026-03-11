# Propagator-First Pipeline Migration Sprint

**Created**: 2026-03-11
**Status**: NOT STARTED
**Design Document**: `docs/research/2026-03-11_PROPAGATOR_FIRST_PIPELINE_AUDIT.md`
**Depends on**: None (Phase 0 is prerequisite for all later phases)
**Related**: `docs/research/2026-03-11_LSP_VSCODE_STAGE2_REFINEMENT.md` (LSP architecture), `docs/tracking/principles/DESIGN_PRINCIPLES.org` § "Propagator-First Infrastructure"
**Principles**: Propagator-First Infrastructure, Correct by Construction

---

## Objectives and Scope

Migrate the Prologos compilation pipeline from ad-hoc mutable state (Racket parameters with mutable hasheqs, dirty flags, manual retry loops) to a unified propagator-cell infrastructure. The audit identified ~42 propagator-natural state sites (52% of all mutable state). This sprint migrates them in dependency order, unlocking 5 composition synergies and building the foundation for LSP incremental re-elaboration.

**Non-goals**: Reader, parser, zonking, reduction caches, elaborator context parameters — these remain as-is (see audit §7).

---

## Phase Overview

| Phase | Description | Sub-phases | Est. Effort | Risk | Status |
|-------|-------------|------------|-------------|------|--------|
| 0 | Unified cell abstraction | 0a–0d | 2–3 days | Low | NOT STARTED |
| 1 | Constraint tracking → cells | 1a–1d | 3–5 days | Medium | NOT STARTED |
| 2 | Registry parameters → cells | 2a–2c | 2–3 days | Low | NOT STARTED |
| 3 | Global environment → cells | 3a–3d | 5–8 days | High | NOT STARTED |
| 4 | ATMS speculation | 4a–4c | 3–5 days | Medium | NOT STARTED |
| 5 | Driver simplification | 5a–5b | 2–3 days | Low | NOT STARTED |

**Total**: 17–27 days across 6 phases, 19 sub-phases

---

## Phase 0: Unified Cell Abstraction (Prerequisite)

**Goal**: Extend the existing pure `prop-network` (`propagator.rkt`) with domain-specific merge functions for infrastructure cells, so that metavariable cells, registry cells, constraint cells, and global-env cells all live in **one** network — scheduled by **one** scheduler — with parallel propagation as an inherent structural property.

**Key design decisions**:
1. **Pure, not mutable** — all operations return new network values (structural sharing via CHAMP). The driver holds the network in a box (like `current-prop-net-box` today). Parallelism is safe because BSP rounds read old state and write to new state. No locks, no races — correctness is structural (Correct by Construction).
2. **Single network, not layered** — one `prop-network` instance holds all cells. ATMS-scoped assumptions distinguish per-command state from persistent state. The audit's recommendation (§6 Phase 0, §8).
3. **Parallel propagation is inherent** — the existing BSP/Jacobi scheduler (`run-to-quiescence-bsp`) and parallel executor (`make-parallel-fire-all`) apply to all cells uniformly. Independent propagators (e.g., elaborating 10 definitions, resolving 5 trait constraints) fire in parallel automatically. This is not a feature we add later; it is a property of the network structure.

### 0a: Merge Function Library + Cell Factory

- [ ] Create `racket/prologos/infra-cell.rkt` — thin layer on top of `propagator.rkt`, no dependency on elaborator-network or metavar-store
- [ ] Define domain-specific merge functions (each is a `(content × content → content)` suitable for `net-cell-write`'s lattice join):
  - `merge-hasheq-union` — monotonic hash union (for registries): conflicts use right-hand-side (latest registration wins)
  - `merge-list-append` — monotonic list accumulation (for warnings, constraints)
  - `merge-set-union` — monotonic set union (for propagated-specs)
  - `merge-type-join` — re-export of `type-join` from `type-lattice.rkt` (for metavariable cells)
- [ ] Define cell factory functions that pair a `net-new-cell` call with the appropriate merge function:
  - `net-new-registry-cell` — creates cell with `merge-hasheq-union`, initial content `(hasheq)`
  - `net-new-list-cell` — creates cell with `merge-list-append`, initial content `'()`
  - `net-new-set-cell` — creates cell with `merge-set-union`, initial content `(seteq)`
  - `net-new-definition-cell` — creates cell for a single definition (type + value pair)
- [ ] Property tests for each merge function: commutativity, associativity, idempotency (where applicable)
- [ ] Tests: `tests/test-infra-cell-01.rkt` — unit tests for cell create/read/write/merge via factory functions on a `prop-network`

**Files**: New `infra-cell.rkt` (~120–160 LOC), new test file (~30 tests)
**Key constraint**: `infra-cell.rkt` depends only on `propagator.rkt` and `champ.rkt` — no circular dependency risk

### 0b: Unified Network Constructor

- [ ] Create `make-unified-network` — a `prop-network` pre-populated with infrastructure cells:
  - One registry cell per registry parameter (24 cells, one per `current-*-registry`)
  - One list cell per warning accumulator (3 cells)
  - One list cell for constraint store
  - Module registry cell, ns-context cell
  - Returns `(values network cell-id-map)` where `cell-id-map` is a `hasheq: symbol → cell-id` for named lookup
- [ ] `network-cell-ref` — look up a named infrastructure cell by symbol (e.g., `'impl-registry`, `'coercion-warnings`)
- [ ] The unified network coexists with the existing `elab-network` by **becoming** the underlying `prop-network` that `elab-network` wraps — `elab-network` adds type-inference-specific metadata (`elab-cell-info`, `contradiction-info`) on top of the same network
- [ ] Design note: During Phase 0, the existing `elab-network` continues to create its own cells for metavariables. The infrastructure cells are additional cells in the same network. Phases 1–3 progressively wire propagators between them.

**Files**: Extend `infra-cell.rkt` (+80–100 LOC), extend test file (+15 tests)

### 0c: Parallel Propagation Verification

- [ ] Verify that infrastructure cells work with all three schedulers:
  - `run-to-quiescence` (sequential) — deterministic baseline
  - `run-to-quiescence-bsp` (BSP) — parallel-ready, verify same results as sequential
  - With `make-parallel-fire-all` (multi-core futures) — verify same results as sequential
- [ ] Create test: network with 10 independent registry cells, 10 propagators writing to them, run BSP — verify all cells have correct content and order-independence holds
- [ ] Create test: network with dependent propagator chain (A → B → C), verify BSP converges in correct number of rounds
- [ ] Benchmark: compare sequential vs BSP vs parallel on a synthetic network of 100 cells with 50 propagators — establish baseline for overhead characterization
- [ ] Tests: `tests/test-infra-cell-parallel-01.rkt` — parallel correctness + performance characterization

**Files**: New test file (~20 tests)

### 0d: Integration Smoke Test

- [ ] Create `tests/test-infra-cell-integration-01.rkt` using shared fixture pattern
- [ ] Smoke test: create a unified network, add infrastructure cells + elaboration cells, add propagators between them, verify propagation flows across both cell types
- [ ] Integration test: run `process-string` with the unified network backing both `current-prop-net-box` and infrastructure cells — verify elaboration works as before, and infrastructure cells accumulate correct content
- [ ] Run full test suite — 0 regressions

**Files**: New test file (~15 tests)
**Commit gate**: Full test suite passes, new tests pass, parallel scheduler produces identical results to sequential

---

## Phase 1: Constraint Tracking → Cells (Highest Synergy)

**Goal**: Migrate the 8 constraint-related parameters (audit §3.2) to infra-cells. Wire trait resolution as propagators that fire when meta cells are solved, eliminating the dirty-flag retry loops.

**Synergy unlocked**: §5.1 — Trait Resolution Becomes Reactive

### 1a: Constraint Store Cell

- [ ] Thread the unified network through the driver — `current-prop-net-box` now holds the unified network (not a separate `elab-network`)
- [ ] Replace `current-constraint-store` (list accumulator) with the constraint list cell from the unified network
- [ ] `add-constraint!` → `net-cell-write` to constraint cell (pure — returns new network, driver updates box)
- [ ] `all-postponed-constraints` / `all-failed-constraints` → `net-cell-read` on the constraint cell
- [ ] Adapt `current-wakeup-registry` to wire propagators: when a meta cell is written, fire the wakeup propagator that retries relevant constraints
- [ ] Tests: Existing constraint tests must pass unchanged; add 5 new tests verifying propagator-based wakeup

**Files touched**: `metavar-store.rkt` (~60 LOC changed), `driver.rkt` (~10 LOC — add `current-infra-network` to parameterize block)
**Risk**: Low — constraint store is append-only; the migration is mechanical

### 1b: Trait Constraint Cells

- [ ] Replace `current-trait-constraint-map` with per-trait-constraint infra-cells
- [ ] Replace `current-trait-wakeup-map` with propagator wiring: meta cell → trait constraint cell → impl registry cell
- [ ] Replace `current-trait-cell-map` with direct cell-id references (already close to this)
- [ ] Wire: when a meta cell's content changes (solved), fire the trait constraint propagator; if the impl registry cell has a matching instance, resolve the trait dict
- [ ] Eliminate `current-retry-trait-resolve` dirty flag — propagation handles retries automatically
- [ ] Tests: All trait resolution tests must pass; add 5 new tests verifying reactive trait resolution without explicit `resolve-trait-constraints!` call

**Files touched**: `metavar-store.rkt` (~80 LOC), `macros.rkt` (trait resolution, ~100 LOC), `driver.rkt` (~5 LOC)
**Risk**: Medium — trait resolution wiring is intricate; the existing P1–P4 propagators must compose with the new infra-cell propagators

### 1c: HasMethod + Capability Constraint Cells

- [ ] Replace `current-hasmethod-constraint-map` with infra-cells (same pattern as 1b)
- [ ] Replace `current-capability-constraint-map` with infra-cells
- [ ] Wire propagators: meta cell → hasmethod cell → trait registry cell → resolution
- [ ] Eliminate `current-retry-unify` dirty flag
- [ ] Tests: Existing hasmethod and capability tests pass; 5 new tests

**Files touched**: `metavar-store.rkt` (~40 LOC), `macros.rkt` (~60 LOC)
**Risk**: Low — hasmethod/capability constraints follow the same pattern as trait constraints

### 1d: Remove Retry Infrastructure

- [ ] Remove `current-retry-trait-resolve` parameter entirely
- [ ] Remove `current-retry-unify` parameter entirely
- [ ] Remove `retry-traits-via-cells!` function (propagation replaces it)
- [ ] Remove the retry loop in `resolve-trait-constraints!` or reduce it to a single propagation pass
- [ ] Audit driver.rkt for any remaining references to removed parameters
- [ ] Run full test suite — 0 regressions
- [ ] Check for whale files (>30s) introduced by propagator overhead

**Files touched**: `metavar-store.rkt` (~30 LOC removed), `macros.rkt` (~40 LOC removed), `driver.rkt` (~10 LOC removed)
**Commit gate**: Full test suite passes, no whale files, retry infrastructure eliminated

---

## Phase 2: Registry Parameters → Cells (Uniform Model)

**Goal**: Migrate the 24 registry parameters in `macros.rkt` (audit §3.4) to infra-cells with `merge-hasheq-union`. This is the most mechanical phase — all registries share an identical pattern.

### 2a: Core Type Registries (8 registries)

- [ ] Migrate to infra-cells: `current-schema-registry`, `current-ctor-registry`, `current-type-meta`, `current-subtype-registry`, `current-coercion-registry`, `current-capability-registry`, `current-property-store`, `current-functor-store`
- [ ] Each registry: replace `(hash-set (current-X) key val)` → `(cell-merge! X-cell (hasheq key val))`
- [ ] Each registry read: replace `(hash-ref (current-X) key #f)` → `(hash-ref (cell-read X-cell) key #f)`
- [ ] Add `register-type-registry-cells!` function called by driver at startup to create all cells
- [ ] Tests: Module loading + type definition tests cover these registries; run full suite

**Files touched**: `macros.rkt` (~120 LOC changed — bulk rename of access patterns)
**Risk**: Low — registries are write-once-read-many; changes are mechanical

### 2b: Trait + Instance Registries (8 registries)

- [ ] Migrate to infra-cells: `current-trait-registry`, `current-trait-laws`, `current-impl-registry`, `current-param-impl-registry`, `current-bundle-registry`, `current-specialization-registry`, `current-selection-registry`, `current-session-registry`
- [ ] **Critical**: Wire propagator from `current-impl-registry` cell to trait constraint cells (from Phase 1b) — when a new instance is registered, pending trait constraints re-fire
- [ ] This is the composition synergy: Phase 1 + Phase 2 together enable fully reactive trait resolution
- [ ] Tests: All trait + instance tests pass; prelude loading tests pass; add 3 new tests verifying that instance registration triggers constraint resolution

**Files touched**: `macros.rkt` (~120 LOC changed)
**Risk**: Low-Medium — impl registry wiring to trait constraints requires care

### 2c: Remaining Registries + Warnings (11 registries)

- [ ] Migrate to infra-cells: `current-preparse-registry`, `current-spec-store`, `current-propagated-specs`, `current-strategy-registry`, `current-process-registry`, `current-user-precedence-groups`, `current-user-operators`, `current-macro-registry`
- [ ] Migrate warnings to infra-cells: `current-coercion-warnings`, `current-deprecation-warnings`, `current-capability-warnings` (using `merge-list-append`)
- [ ] Migrate narrowing constraints: `current-narrow-constraints`, `current-narrow-var-constraints`
- [ ] Run full test suite — 0 regressions
- [ ] Check for whale files

**Files touched**: `macros.rkt` (~80 LOC), `warnings.rkt` (~30 LOC), `global-constraints.rkt` (~20 LOC)
**Commit gate**: Full test suite passes, all 24 registries + 3 warnings + 2 narrowing params migrated

---

## Phase 3: Global Environment → Cells (Incremental Foundation)

**Goal**: Convert `current-global-env` from a monolithic threaded hasheq to per-definition infra-cells. This is the highest-risk, highest-reward phase — it enables incremental re-elaboration and is the foundation for LSP Tier 4 (interactive eval).

**Synergy unlocked**: §5.2 — Incremental Module Re-elaboration, §5.3 — Cross-Module Dependency Propagation

### 3a: Per-Definition Cell Infrastructure

- [ ] Create `definition-cell` struct extending infra-cell: `(name type-cell value-cell param-names srcloc)`
- [ ] Add `current-definition-cells` parameter: `hasheq: symbol → definition-cell`
- [ ] `global-env-add` → creates a new definition-cell, registers it in the network, stores in `current-definition-cells`
- [ ] `global-env-lookup` → reads from definition-cell (falls back to `current-global-env` during transition)
- [ ] **Backward compatibility**: During Phase 3a, BOTH `current-global-env` and `current-definition-cells` are maintained in parallel. `global-env-add` writes to both. `global-env-lookup` reads from cells if available, global-env otherwise.
- [ ] Tests: 10 new tests for definition-cell create/read; full suite passes (backward compat ensures no regressions)

**Files touched**: `global-env.rkt` (~80 LOC), `driver.rkt` (~15 LOC)
**Risk**: Medium — dual-write during transition adds complexity but ensures safety

### 3b: Wire Definition Dependencies

- [ ] When elaboration references a prior definition (via `global-env-lookup`), record a dependency edge: the referencing form's elaboration result depends on the referenced definition-cell
- [ ] Add `network-add-dependency!` function: creates a propagator from source definition-cell to dependent form's result cell
- [ ] For batch mode: dependencies are informational (no re-firing needed — forms are processed sequentially)
- [ ] For LSP mode (future): dependencies enable selective re-elaboration
- [ ] Tests: 5 new tests verifying dependency edges are recorded; full suite passes

**Files touched**: `global-env.rkt` (~30 LOC), `elaborator.rkt` (~20 LOC — add dependency recording at definition reference sites)
**Risk**: Medium — identifying all definition-reference sites in the elaborator

### 3c: Module Registry Cells

- [ ] Convert `current-module-registry` to infra-cells: each module gets a cell whose content is `module-info`
- [ ] Convert `current-ns-context` to an infra-cell
- [ ] Wire: module import → dependency on source module's export cells
- [ ] `current-defn-param-names` → infra-cell with `merge-hasheq-union`
- [ ] Tests: Module loading tests pass; cross-module import tests pass; 5 new tests

**Files touched**: `namespace.rkt` (~60 LOC), `driver.rkt` (~10 LOC)
**Risk**: Medium — module loading is complex; must preserve cycle detection behavior

### 3d: Remove Dual-Write, Retire `current-global-env`

- [ ] Remove backward-compat dual-write from 3a
- [ ] All `global-env-lookup` calls read exclusively from definition-cells
- [ ] Retire `current-global-env` parameter (or reduce it to a thin wrapper that reads from cells)
- [ ] Update driver's per-command `parameterize` block — `current-global-env` no longer needs reset
- [ ] Run full test suite — 0 regressions
- [ ] Run `.prologos` acceptance files — Level 3 WS validation
- [ ] Check for whale files

**Files touched**: `global-env.rkt` (~40 LOC removed), `driver.rkt` (~20 LOC), `elaborator.rkt` (~10 LOC), `namespace.rkt` (~10 LOC)
**Commit gate**: Full test suite passes, Level 3 WS validation passes, `current-global-env` retired or reduced to thin wrapper

---

## Phase 4: ATMS Speculation (Correct by Construction)

**Goal**: Replace the fragile `save-meta-state`/`restore-meta-state!` box-snapshot pattern with ATMS assumption creation/retraction. Speculative type-checking (Church folds, union types, bare params) creates named assumptions that can be committed or retracted structurally.

**Synergy unlocked**: §5.5 — Speculative Type-Checking Becomes ATMS Assumptions

### 4a: ATMS Assumption API for Infra-Network

- [ ] Add to `infra-cell.rkt`: `make-assumption`, `with-assumption`, `retract-assumption!`, `commit-assumption!`
- [ ] `make-assumption` → creates a named assumption token
- [ ] `with-assumption` → all cell writes within the dynamic extent are tagged with the assumption
- [ ] `retract-assumption!` → all cell content tagged with the assumption is removed; dependent propagators re-fire
- [ ] `commit-assumption!` → assumption tag is removed from cell content (content becomes unconditional)
- [ ] Design note: This is the "pocket universe" pattern from the ATMS. The existing `elab-network` already has ATMS integration via `propagator.rkt` — this extends it to infra-cells.
- [ ] Tests: 10 new tests — create assumption, write under assumption, retract and verify content reverts, commit and verify content persists

**Files touched**: `infra-cell.rkt` (~120 LOC), new section in test file (~10 tests)
**Risk**: Medium — ATMS integration requires careful handling of assumption sets

### 4b: Replace save/restore with Assumptions

- [ ] Identify all `save-meta-state`/`restore-meta-state!` call sites in `elaborator.rkt` and `elab-speculation-bridge.rkt`
- [ ] Replace each site: `save-meta-state` → `make-assumption`; failed path → `retract-assumption!`; success path → `commit-assumption!`
- [ ] Known call sites:
  - Church fold attempts (elaborator.rkt — `try-elaborate-church-fold`)
  - Union type checking (elaborator.rkt — `try-union-type-check`)
  - Bare param inference (elaborator.rkt — `try-bare-param`)
  - `elab-speculation-bridge.rkt` — bridge for speculative elaboration
- [ ] Tests: Church fold tests, union type tests, bare param tests — all must pass
- [ ] Verify: no more `save-meta-state` calls remain in codebase

**Files touched**: `elaborator.rkt` (~50 LOC changed), `elab-speculation-bridge.rkt` (~30 LOC changed), `metavar-store.rkt` (~20 LOC — deprecate save/restore)
**Risk**: Medium — each speculation site has subtly different semantics; must verify one-by-one

### 4c: Remove Legacy Snapshot Infrastructure

- [ ] Remove `save-meta-state` and `restore-meta-state!` from `metavar-store.rkt`
- [ ] Remove the 6-box snapshot pattern
- [ ] Audit for any remaining references
- [ ] Run full test suite — 0 regressions
- [ ] Check for whale files (ATMS overhead)

**Files touched**: `metavar-store.rkt` (~60 LOC removed)
**Commit gate**: Full test suite passes, box-snapshot pattern fully retired

---

## Phase 5: Driver Simplification (Payoff)

**Goal**: With Phases 1–4 complete, the driver's per-command orchestration simplifies dramatically. The explicit pipeline stages (elaborate → resolve-traits → check-unresolved → zonk) collapse into "add form to network, run to quiescence, read results."

### 5a: Simplify Per-Command Parameterize

- [ ] Remove parameters from the per-command `parameterize` block that are now infra-cells:
  - All 24 registry parameters
  - 3 warning parameters
  - 2 narrowing constraint parameters
  - Constraint store, wakeup registry, trait/hasmethod/capability constraint maps
  - Retry flags (already removed in Phase 1d)
- [ ] Replace `reset-meta-store!` with network assumption management (retract per-command assumption, create new one)
- [ ] Reduce the `process-command` pipeline from 5 explicit phases to:
  1. Create per-form assumption
  2. Elaborate (writes to cells)
  3. Run network to quiescence (replaces explicit resolve-traits + retry loops)
  4. Read results from cells (replaces explicit zonking of constraint-dependent state)
  5. Zonk final expression (still needed — reads from cells but is a pure traversal)
- [ ] Tests: Full suite; `.prologos` acceptance files

**Files touched**: `driver.rkt` (~100 LOC changed/removed)
**Risk**: Low — by this point, all the underlying state has been migrated; the driver changes are removing orchestration, not adding it

### 5b: Documentation and Cleanup

- [ ] Update `CLAUDE.md` § "Type Checking Pipeline" to reflect new architecture
- [ ] Update `CLAUDE.md` § "Key Patterns" — replace "Two-phase zonking" and "Speculative type-checking" descriptions with propagator-cell descriptions
- [ ] Remove callback parameters from `metavar-store.rkt` if the unified cell module resolves the circular dependency:
  - `current-prop-make-network`, `current-prop-fresh-meta`, `current-prop-cell-write`, `current-prop-cell-read`
  - `current-prop-add-unify-constraint`, `current-prop-fresh-mult-cell`, `current-prop-mult-cell-write`
  - `current-prop-has-contradiction?`, `current-prop-run-quiescence`, `current-prop-unwrap-net`, `current-prop-rewrap-net`
- [ ] If circular deps prevent removing callbacks: document why, add to DEFERRED.md
- [ ] Run full test suite — 0 regressions
- [ ] Run `racket tools/benchmark-tests.rkt --slowest 10` — verify no performance regression (compare against pre-sprint baseline)

**Files touched**: `CLAUDE.md` (~20 LOC), `metavar-store.rkt` (~50 LOC removed if callbacks resolved), `driver.rkt` (~10 LOC)
**Commit gate**: Full test suite passes, no whale files, documentation updated

---

## Key Files Summary

| File | Phase(s) | Type of Change |
|------|----------|----------------|
| `infra-cell.rkt` (NEW) | 0a–0b, 4a | New module: merge functions, cell factories, unified network constructor, ATMS assumptions |
| `metavar-store.rkt` (1125 LOC) | 1a–1d, 4b–4c, 5b | Constraint cells, remove retry infra, remove snapshot |
| `macros.rkt` (8968 LOC) | 1b–1c, 2a–2c | Trait resolution wiring, registry cells |
| `global-env.rkt` (81 LOC) | 3a, 3d | Per-definition cells, retire current-global-env |
| `driver.rkt` (1968 LOC) | 1a, 3a, 5a | Network init, per-command simplification |
| `elaborator.rkt` (3924 LOC) | 3b, 4b | Dependency recording, speculation replacement |
| `namespace.rkt` (652 LOC) | 3c | Module registry cells |
| `constraint-propagators.rkt` (292 LOC) | 1b | Compose with infra-cell propagators |
| `elab-speculation-bridge.rkt` (216 LOC) | 4b | Replace save/restore with assumptions |
| `warnings.rkt` | 2c | Warning cells |
| `global-constraints.rkt` | 2c | Narrowing constraint cells |

---

## Test Strategy

| Gate | When | Criteria |
|------|------|----------|
| Phase 0 commit | After 0d | All new tests pass, full suite 0 regressions |
| Phase 1 commit | After 1d | Full suite passes, retry infra removed, no whale files |
| Phase 2 commit | After 2c | Full suite passes, all 24+3+2 params migrated |
| Phase 3 commit | After 3d | Full suite passes, Level 3 WS validation, global-env retired |
| Phase 4 commit | After 4c | Full suite passes, snapshot infra removed |
| Phase 5 commit | After 5b | Full suite passes, no perf regression, docs updated |

**Baseline metrics** (captured before sprint):

| Metric | Value |
|--------|-------|
| Tests | 6733 |
| Test files | 349 |
| Failures | 0 |
| Wall time | ~190s |

**Performance budget**: Total wall time increase ≤ 10% (~19s). Propagator cell overhead should be negligible — the existing elaboration network adds <5s to the suite. If any phase pushes wall time beyond budget, profile and optimize before proceeding.

---

## Dependency Graph

```
Phase 0 (cell abstraction)
    │
    ├──→ Phase 1 (constraints → cells)
    │        │
    │        └──→ Phase 4 (ATMS speculation) ← also needs Phase 3
    │
    ├──→ Phase 2 (registries → cells)
    │        │
    │        └──→ [composes with Phase 1 for reactive trait resolution]
    │
    └──→ Phase 3 (global-env → cells)
             │
             └──→ Phase 5 (driver simplification) ← needs Phases 1–4
```

Phases 1, 2, and 3 can proceed in parallel after Phase 0. Phase 4 requires Phases 1 and 3. Phase 5 requires all prior phases.

**Recommended execution order** (serial): 0 → 1 → 2 → 3 → 4 → 5
**Aggressive execution order** (parallel where possible): 0 → {1, 2, 3} → 4 → 5

---

## Open Questions (from Audit §11)

| # | Question | Resolution Target |
|---|----------|-------------------|
| 1 | Single network vs layered networks? | Phase 0a design decision |
| 2 | CHAMP box migration path — wrap or replace? | Phase 1a implementation choice |
| 3 | Circular dependency breaking — does unified cell module help? | Phase 5b — evaluate after all migrations |
| 4 | Performance overhead of cells vs raw hash-set! | Phase 0d + each phase gate — measure empirically |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Trait resolution semantics change subtly during Phase 1 | Medium | High | Exhaustive trait tests (300+ existing); per-test golden output comparison |
| Global-env cell migration breaks elaboration ordering | Medium | High | Phase 3a dual-write provides fallback; can abort 3d if issues arise |
| Propagator overhead exceeds performance budget | Low | Medium | Profile after Phase 0d; cell operations should be O(1) lookup |
| ATMS assumption retraction doesn't match snapshot semantics exactly | Medium | Medium | Phase 4b tests each speculation site individually; can keep snapshot as fallback |
| `macros.rkt` changes in Phase 2 interact badly with prelude loading | Low | High | Prelude loading tests are comprehensive; run affected-tests after each sub-phase |
| Circular dependency worsens with unified cell module | Low | Medium | Phase 5b evaluates; worst case keeps callback pattern (status quo) |

---

## Deferred Work (Known)

- **LSP network integration**: The unified network from this sprint becomes the LSP state management network. Integration work is in the LSP roadmap (`2026-03-11_LSP_VSCODE_STAGE2_REFINEMENT.md`), not this sprint.
- **Reduction cache invalidation via cells**: Audit §3.7 notes that WHNF/NF caches could be cells for LSP invalidation. Not needed for batch pipeline. Track in DEFERRED.md if useful later.

Note: Parallel propagation is **not deferred** — it is inherent in Phase 0's design. The unified network uses `propagator.rkt`'s existing schedulers (sequential, BSP, parallel). Independent propagators fire in parallel automatically via the BSP scheduler. Phase 0c verifies parallel correctness.
