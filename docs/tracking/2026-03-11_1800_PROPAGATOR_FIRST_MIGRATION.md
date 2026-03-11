# Propagator-First Pipeline Migration Sprint

**Created**: 2026-03-11
**Status**: IN PROGRESS
**Design Document**: `docs/research/2026-03-11_PROPAGATOR_FIRST_PIPELINE_AUDIT.md`
**Depends on**: None (Phase 0 is prerequisite for all later phases)
**Related**: `docs/research/2026-03-11_LSP_VSCODE_STAGE2_REFINEMENT.md` (LSP architecture), `docs/tracking/principles/DESIGN_PRINCIPLES.org` § "Propagator-First Infrastructure"
**Principles**: Propagator-First Infrastructure, Correct by Construction, First-Class by Default, The Most Generalizable Interface

---

## Objectives and Scope

Migrate the Prologos compilation pipeline from ad-hoc mutable state (Racket parameters with mutable hasheqs, dirty flags, manual retry loops) to a unified propagator-cell infrastructure. The audit identified ~42 propagator-natural state sites (52% of all mutable state). This sprint migrates them in dependency order, unlocking 5 composition synergies and building the foundation for LSP incremental re-elaboration.

**Non-goals**: Reader, parser, zonking, elaborator context parameters — these remain as-is (see audit §7).

### Progress Tracker

| Phase | Sub | Description | Status | Notes |
|-------|-----|-------------|--------|-------|
| 0 | 0a | Merge function library + cell factory | ✅ | `140c023` — 37 tests, ~160 LOC |
| 0 | 0b | ATMS assumption infrastructure | ✅ | `8e9d018` — 21 tests, infra-state + ATMS bridge |
| 0 | 0c | Network construction via registration protocol | ✅ | `5d4d6f9` — 6 tests, elab-network coexistence verified |
| 0 | 0d | Parallel propagation verification + benchmarks | ✅ | `e408151` — 6 tests, seq=BSP=par verified, <1ms overhead |
| 0 | 0e | Integration smoke test | ✅ | Full suite: 6803 tests, 353 files, 0 failures, 208.6s. Canary OK. |
| 1 | 1a | Constraint store cell (storage only) | ✅ | `411e96b` — 10 tests, dual-write to cell + legacy parameter |
| 1 | 1b | Trait constraint cells (storage only) | ✅ | `ec36685` — 6 tests, 4 registry cells (trait/hasmethod/cap), dual-write |
| 1 | 1c | Wakeup registry cell (storage only) | ✅ | `7419752` — 4 tests, wakeup+trait-wakeup cells, merge-hasheq-list-append |
| 1 | 1d | Reactive resolution wiring (behavior change) | ⬜ | |
| 1 | 1e | Remove retry infrastructure | ⬜ | |
| 2 | 2a | Core type registries (8 registries) | ⬜ | |
| 2 | 2b | Trait + instance registries (8 registries) | ⬜ | |
| 2 | 2c | Remaining registries + warnings (11 registries) | ⬜ | |
| 3 | 3a | Per-definition cell infrastructure | ⬜ | |
| 3 | 3b | Wire definition dependencies | ⬜ | |
| 3 | 3c | Module registry cells | ⬜ | |
| 3 | 3d | Retire `current-global-env` | ⬜ | |
| 3 | 3e | Reduction cache cells + invalidation | ⬜ | |
| 4 | 4a | Speculation side-effect audit | ⬜ | |
| 4 | 4b | Replace save/restore with assumptions | ⬜ | |
| 4 | 4c | Remove legacy snapshot infrastructure | ⬜ | |
| 5 | 5a | Simplify per-command parameterize | ⬜ | |
| 5 | 5b | Documentation and cleanup | ⬜ | |

---

## Phase Overview

| Phase | Description | Sub-phases | Est. Effort | Risk | Status |
|-------|-------------|------------|-------------|------|--------|
| 0 | Unified cell abstraction + ATMS | 0a–0e | 3–4 days | Low | ✅ DONE |
| 1 | Constraint tracking → cells | 1a–1e | 3–5 days | Medium | IN PROGRESS (1a–1c ✅) |
| 2 | Registry parameters → cells | 2a–2c | 2–3 days | Low | NOT STARTED |
| 3 | Global environment → cells + cache invalidation | 3a–3e | 6–9 days | High | NOT STARTED |
| 4 | Speculation → ATMS assumptions | 4a–4c | 3–5 days | Medium | NOT STARTED |
| 5 | Driver simplification | 5a–5b | 2–3 days | Low | NOT STARTED |

**Total**: 19–29 days across 6 phases, 23 sub-phases

---

## Phase 0: Unified Cell Abstraction + ATMS (Prerequisite)

**Goal**: Extend the existing pure `prop-network` (`propagator.rkt`) with domain-specific merge functions for infrastructure cells, so that metavariable cells, registry cells, constraint cells, and global-env cells all live in **one** network — scheduled by **one** scheduler — with parallel propagation as an inherent structural property. Include ATMS assumption infrastructure upfront, since Phase 3 (global-env) needs non-monotonic definition replacement and Phase 4 (speculation) needs assumption retraction.

**Key design decisions**:
1. **Pure, not mutable** — all operations return new network values (structural sharing via CHAMP). The driver holds the network in a box (like `current-prop-net-box` today). Parallelism is safe because BSP rounds read old state and write to new state. No locks, no races — correctness is structural (Correct by Construction).
2. **Single network, not layered** — one `prop-network` instance holds all cells. ATMS-scoped assumptions distinguish per-command state from persistent state. The audit's recommendation (§6 Phase 0, §8).
3. **Parallel propagation is inherent** — the existing BSP/Jacobi scheduler (`run-to-quiescence-bsp`) and parallel executor (`make-parallel-fire-all`) apply to all cells uniformly. Independent propagators (e.g., elaborating 10 definitions, resolving 5 trait constraints) fire in parallel automatically. This is not a feature we add later; it is a property of the network structure.
4. **ATMS assumptions from day one** — assumption create/retract/commit is part of the cell abstraction, not bolted on in Phase 4. Phase 3 needs it for definition replacement; Phase 4 needs it for speculation. Building it into Phase 0 ensures the abstraction is designed for non-monotonic recovery from the start.

**Self-hosting design note**: The `infra-cell` abstraction should be designed so that its cells are representable as Prologos `PropCell` values. The self-hosted compiler (LLVM target) will use Prologos propagator cells for its own infrastructure — the same cells the user programs with. This doesn't require full self-hosting now, but the cell API should not introduce Racket-specific patterns that would be difficult to express in Prologos. Prefer: struct-based cells with pure functional operations. Avoid: Racket parameters, continuations, or inspector-dependent behavior in the cell abstraction itself.

### 0a: Merge Function Library + Cell Factory

- [ ] Create `racket/prologos/infra-cell.rkt` — thin layer on top of `propagator.rkt`, no dependency on elaborator-network or metavar-store
- [ ] Define the **general** cell factory: `net-new-cell-with-merge` — creates a cell given any merge function and initial content (The Most Generalizable Interface)
- [ ] Define domain-specific merge functions (each is a `(content × content → content)` suitable for `net-cell-write`'s lattice join):
  - `merge-hasheq-union` — monotonic hash union (for registries): conflicts use right-hand-side (latest registration wins)
  - `merge-list-append` — monotonic list accumulation (for warnings, constraints)
  - `merge-set-union` — monotonic set union (for propagated-specs)
  - `merge-type-join` — re-export of `type-join` from `type-lattice.rkt` (for metavariable cells)
- [ ] Define convenience cell factory wrappers (delegate to `net-new-cell-with-merge`):
  - `net-new-registry-cell` — creates cell with `merge-hasheq-union`, initial content `(hasheq)`
  - `net-new-list-cell` — creates cell with `merge-list-append`, initial content `'()`
  - `net-new-set-cell` — creates cell with `merge-set-union`, initial content `(seteq)`
  - `net-new-definition-cell` — creates cell for a single definition (type + value pair)
- [ ] Property tests for each merge function: commutativity, associativity, idempotency (where applicable)
- [ ] Tests: `tests/test-infra-cell-01.rkt` — unit tests for cell create/read/write/merge via both general and convenience factory functions

**Files**: New `infra-cell.rkt` (~120–160 LOC), new test file (~30 tests)
**Key constraint**: `infra-cell.rkt` depends only on `propagator.rkt` and `champ.rkt` — no circular dependency risk

### 0b: ATMS Assumption Infrastructure

- [ ] Add to `infra-cell.rkt`: `make-assumption`, `with-assumption`, `retract-assumption!`, `commit-assumption!`
- [ ] `make-assumption` → creates a named assumption token
- [ ] `with-assumption` → all cell writes within the dynamic extent are tagged with the assumption
- [ ] `retract-assumption!` → all cell content tagged with the assumption is removed; dependent propagators re-fire
- [ ] `commit-assumption!` → assumption tag is removed from cell content (content becomes unconditional)
- [ ] `merge-replace-with-assumption` merge function — non-monotonic replacement that uses ATMS assumption tagging; content under the active assumption replaces prior content (for global-env definitions that can change across LSP edits)
- [ ] Design note: This is the "pocket universe" pattern from the ATMS. The existing `elab-network` already has ATMS integration via `propagator.rkt` — this extends it to infra-cells. Needed by Phase 3 (definition cells) and Phase 4 (speculation).
- [ ] Tests: 15 new tests — create assumption, write under assumption, retract and verify content reverts, commit and verify content persists, `merge-replace-with-assumption` semantics, nested assumptions

**Files**: Extend `infra-cell.rkt` (+120 LOC), extend test file (+15 tests)

### 0c: Network Construction via Registration Protocol

- [ ] Define `network-register-cell!` — each module registers its own cells at startup (not a central manifest). The unified network starts empty; the driver's startup sequence calls registration functions from each module.
- [ ] `network-cell-ref` — look up a named infrastructure cell by symbol (e.g., `'impl-registry`, `'coercion-warnings`)
- [ ] Each module provides its own registration function:
  - `macros.rkt` → `register-macros-cells!` (24 registry cells)
  - `warnings.rkt` → `register-warning-cells!` (3 list cells)
  - `metavar-store.rkt` → `register-constraint-cells!` (constraint store + wakeup)
  - `namespace.rkt` → `register-namespace-cells!` (module registry + ns-context)
  - `global-env.rkt` → `register-global-env-cells!` (definition cells created dynamically)
- [ ] The unified network coexists with the existing `elab-network` by **becoming** the underlying `prop-network` that `elab-network` wraps — `elab-network` adds type-inference-specific metadata (`elab-cell-info`, `contradiction-info`) on top of the same network
- [ ] Design note: During Phase 0, the existing `elab-network` continues to create its own cells for metavariables. The infrastructure cells are additional cells in the same network. Phases 1–3 progressively wire propagators between them.

**Files**: Extend `infra-cell.rkt` (+60–80 LOC), extend test file (+10 tests)

### 0d: Parallel Propagation Verification + Benchmarks

- [ ] Verify that infrastructure cells work with all three schedulers:
  - `run-to-quiescence` (sequential) — deterministic baseline
  - `run-to-quiescence-bsp` (BSP) — parallel-ready, verify same results as sequential
  - With `make-parallel-fire-all` (multi-core futures) — verify same results as sequential
- [ ] Create test: network with 10 independent registry cells, 10 propagators writing to them, run BSP — verify all cells have correct content and order-independence holds
- [ ] Create test: network with dependent propagator chain (A → B → C), verify BSP converges in correct number of rounds
- [ ] Benchmark: compare sequential vs BSP vs parallel on a synthetic network of 100 cells with 50 propagators — establish baseline for overhead characterization
- [ ] **Parallel speedup target**: on networks with ≥10 independent propagators, BSP scheduling should demonstrate measurable speedup over sequential. Record speedup ratios for 2-core, 4-core, 8-core configurations.
- [ ] Tests: `tests/test-infra-cell-parallel-01.rkt` — parallel correctness + performance characterization

**Files**: New test file (~20 tests)

### 0e: Integration Smoke Test

- [ ] Create `tests/test-infra-cell-integration-01.rkt` using shared fixture pattern
- [ ] Smoke test: create a unified network via registration protocol, add infrastructure cells + elaboration cells, add propagators between them, verify propagation flows across both cell types
- [ ] Integration test: run `process-string` with the unified network backing both `current-prop-net-box` and infrastructure cells — verify elaboration works as before, and infrastructure cells accumulate correct content
- [ ] Run full test suite — 0 regressions
- [ ] Run `examples/` canary files via `process-file` — Level 3 WS validation

**Files**: New test file (~15 tests)
**Commit gate**: Full test suite passes, new tests pass, parallel scheduler produces identical results to sequential, Level 3 WS canary files pass

---

## Phase 1: Constraint Tracking → Cells (Highest Synergy)

**Goal**: Migrate the 8 constraint-related parameters (audit §3.2) to infra-cells. This phase is split into two conceptual layers: storage migration (1a–1c, low risk) and resolution wiring (1d, medium risk), keeping the concerns decomplected.

**Synergy unlocked**: §5.1 — Trait Resolution Becomes Reactive

### 1a: Constraint Store Cell (Storage Only)

- [ ] Thread the unified network through the driver — `current-prop-net-box` now holds the unified network (not a separate `elab-network`)
- [ ] Replace `current-constraint-store` (list accumulator) with the constraint list cell from the unified network
- [ ] `add-constraint!` → `net-cell-write` to constraint cell (pure — returns new network, driver updates box)
- [ ] `all-postponed-constraints` / `all-failed-constraints` → `net-cell-read` on the constraint cell
- [ ] **Storage only**: the existing retry loop still reads from the cell; wakeup propagators are wired in 1d
- [ ] Tests: Existing constraint tests must pass unchanged; add 3 new tests verifying cell-based storage

**Files touched**: `metavar-store.rkt` (~40 LOC changed), `driver.rkt` (~10 LOC)
**Risk**: Low — constraint store is append-only; pure data-layer migration

### 1b: Trait Constraint Cells (Storage Only)

- [ ] Replace `current-trait-constraint-map` with per-trait-constraint infra-cells
- [ ] Replace `current-trait-cell-map` with direct cell-id references (already close to this)
- [ ] Replace `current-hasmethod-constraint-map` with infra-cells (same pattern)
- [ ] Replace `current-capability-constraint-map` with infra-cells
- [ ] **Storage only**: the existing `resolve-trait-constraints!` loop still runs; it reads from cells instead of hasheqs
- [ ] Tests: All trait/hasmethod/capability resolution tests must pass; add 5 new tests verifying cell-based storage

**Files touched**: `metavar-store.rkt` (~80 LOC), `macros.rkt` (~60 LOC — reads now go through cells)
**Risk**: Low — same data, different container

### 1c: Wakeup Registry Cell (Storage Only)

- [ ] Replace `current-wakeup-registry` with cell-based tracking
- [ ] Replace `current-trait-wakeup-map` with cell-based tracking
- [ ] **Storage only**: wakeup registries store dependency info; actual propagator wiring happens in 1d
- [ ] Tests: Existing tests pass; add 3 new tests

**Files touched**: `metavar-store.rkt` (~30 LOC)
**Risk**: Low

### 1d: Reactive Resolution Wiring (Behavior Change)

- [ ] Wire propagators: meta cell → trait constraint cell → impl registry cell
- [ ] When a meta cell's content changes (solved), fire the trait constraint propagator; if the impl registry cell has a matching instance, resolve the trait dict
- [ ] Wire propagators: meta cell → hasmethod cell → trait registry cell → resolution
- [ ] Eliminate `current-retry-trait-resolve` dirty flag — propagation handles retries automatically
- [ ] Eliminate `current-retry-unify` dirty flag
- [ ] Tests: All trait resolution tests must pass; add 5 new tests verifying reactive trait resolution without explicit `resolve-trait-constraints!` call

**Files touched**: `metavar-store.rkt` (~40 LOC), `macros.rkt` (trait resolution, ~100 LOC), `constraint-propagators.rkt` (~30 LOC)
**Risk**: Medium — trait resolution wiring is intricate; the existing P1–P4 propagators must compose with the new infra-cell propagators

### 1e: Remove Retry Infrastructure

- [ ] Remove `current-retry-trait-resolve` parameter entirely
- [ ] Remove `current-retry-unify` parameter entirely
- [ ] Remove `retry-traits-via-cells!` function (propagation replaces it)
- [ ] Remove the retry loop in `resolve-trait-constraints!` or reduce it to a single propagation pass
- [ ] Audit driver.rkt for any remaining references to removed parameters
- [ ] Run full test suite — 0 regressions
- [ ] Run `examples/` canary files — Level 3 WS validation
- [ ] Check for whale files (>30s) introduced by propagator overhead

**Files touched**: `metavar-store.rkt` (~30 LOC removed), `macros.rkt` (~40 LOC removed), `driver.rkt` (~10 LOC removed)
**Commit gate**: Full test suite passes, no whale files, retry infrastructure eliminated, canary files pass

---

## Phase 2: Registry Parameters → Cells (Uniform Model)

**Goal**: Migrate the 24 registry parameters in `macros.rkt` (audit §3.4) to infra-cells with `merge-hasheq-union`. This is the most mechanical phase — all registries share an identical pattern. Each module registers its own cells (registration protocol from Phase 0c).

### 2a: Core Type Registries (8 registries)

- [ ] Migrate to infra-cells: `current-schema-registry`, `current-ctor-registry`, `current-type-meta`, `current-subtype-registry`, `current-coercion-registry`, `current-capability-registry`, `current-property-store`, `current-functor-store`
- [ ] Each registry: replace `(hash-set (current-X) key val)` → `net-cell-write` to the registry cell (pure — returns new network)
- [ ] Each registry read: replace `(hash-ref (current-X) key #f)` → `(hash-ref (net-cell-read network X-cell) key #f)`
- [ ] Registration via `register-macros-cells!` called by driver at startup
- [ ] Tests: Module loading + type definition tests cover these registries; run full suite

**Files touched**: `macros.rkt` (~120 LOC changed — bulk rename of access patterns)
**Risk**: Low — registries are write-once-read-many; changes are mechanical

### 2b: Trait + Instance Registries (8 registries)

- [ ] Migrate to infra-cells: `current-trait-registry`, `current-trait-laws`, `current-impl-registry`, `current-param-impl-registry`, `current-bundle-registry`, `current-specialization-registry`, `current-selection-registry`, `current-session-registry`
- [ ] **Critical**: Wire propagator from `current-impl-registry` cell to trait constraint cells (from Phase 1d) — when a new instance is registered, pending trait constraints re-fire
- [ ] This is the composition synergy: Phase 1 + Phase 2 together enable fully reactive trait resolution
- [ ] Tests: All trait + instance tests pass; prelude loading tests pass; add 3 new tests verifying that instance registration triggers constraint resolution

**Files touched**: `macros.rkt` (~120 LOC changed)
**Risk**: Low-Medium — impl registry wiring to trait constraints requires care

### 2c: Remaining Registries + Warnings (11 registries)

- [ ] Migrate to infra-cells: `current-preparse-registry`, `current-spec-store`, `current-propagated-specs`, `current-strategy-registry`, `current-process-registry`, `current-user-precedence-groups`, `current-user-operators`, `current-macro-registry`
- [ ] Migrate warnings to infra-cells: `current-coercion-warnings`, `current-deprecation-warnings`, `current-capability-warnings` (using `merge-list-append`)
- [ ] Migrate narrowing constraints: `current-narrow-constraints`, `current-narrow-var-constraints`
- [ ] Run full test suite — 0 regressions
- [ ] Run `examples/` canary files — Level 3 WS validation
- [ ] Check for whale files

**Files touched**: `macros.rkt` (~80 LOC), `warnings.rkt` (~30 LOC), `global-constraints.rkt` (~20 LOC)
**Commit gate**: Full test suite passes, all 24 registries + 3 warnings + 2 narrowing params migrated, canary files pass

---

## Phase 3: Global Environment → Cells (Incremental Foundation)

**Goal**: Convert `current-global-env` from a monolithic threaded hasheq to per-definition infra-cells. This is the highest-risk, highest-reward phase — it enables incremental re-elaboration and is the foundation for LSP Tier 4 (interactive eval).

**Synergy unlocked**: §5.2 — Incremental Module Re-elaboration, §5.3 — Cross-Module Dependency Propagation

### 3a: Per-Definition Cell Infrastructure (Read-Only Legacy Adapter)

- [ ] Create `definition-cell` struct extending infra-cell: `(name type-cell value-cell param-names srcloc)`
- [ ] Add `current-definition-cells` parameter: `hasheq: symbol → definition-cell`
- [ ] `global-env-add` → creates a new definition-cell, registers it in the network, stores in `current-definition-cells`. **Writes ONLY to cells** — the legacy hasheq is NOT updated.
- [ ] `global-env-lookup` → reads from definition-cell; **falls back to a frozen read-only snapshot** of the pre-migration `current-global-env` for definitions that existed before the cell layer was initialized (e.g., prelude definitions loaded before the per-file network is created)
- [ ] **Read-only legacy adapter** (Correct by Construction): the legacy hasheq is populated once at startup from prelude/module loading, then frozen. `global-env-add` writes only to cells. The two representations **cannot diverge** because the hasheq never changes after initialization — it is structurally read-only. This replaces the dual-write pattern (which required discipline to keep in sync).
- [ ] Definition cells use ATMS assumptions (from Phase 0b) — each definition is tagged with a per-form assumption. In batch mode, assumptions are committed immediately. In LSP mode (future), assumptions are retracted on re-edit, enabling incremental re-elaboration.
- [ ] Tests: 10 new tests for definition-cell create/read/fallback; full suite passes

**Files touched**: `global-env.rkt` (~80 LOC), `driver.rkt` (~15 LOC)
**Risk**: Medium — read-only adapter is simpler than dual-write but must handle prelude bootstrapping correctly

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

### 3d: Retire `current-global-env`

- [ ] Remove the read-only legacy hasheq fallback — all definitions now live in cells (including prelude, which is loaded into cells at startup)
- [ ] All `global-env-lookup` calls read exclusively from definition-cells
- [ ] Retire `current-global-env` parameter (or reduce it to a thin wrapper that reads from cells)
- [ ] Update driver's per-command `parameterize` block — `current-global-env` no longer needs reset
- [ ] Run full test suite — 0 regressions
- [ ] Run `.prologos` acceptance files — Level 3 WS validation
- [ ] Run `examples/` canary files
- [ ] Check for whale files

**Files touched**: `global-env.rkt` (~40 LOC removed), `driver.rkt` (~20 LOC), `elaborator.rkt` (~10 LOC), `namespace.rkt` (~10 LOC)
**Commit gate**: Full test suite passes, Level 3 WS validation passes, canary files pass, `current-global-env` retired or reduced to thin wrapper

### 3e: Reduction Cache Cells + Dependency-Driven Invalidation

- [ ] Convert `current-whnf-cache`, `current-nf-cache`, `current-nat-value-cache` from mutable hash parameters to infra-cells
- [ ] Design **write-through cache** pattern: batch mode writes to both fast local hash (for hot-path performance) and cell (for dependency tracking). Reads come from the local hash. The cell is only consulted for invalidation in LSP mode.
- [ ] Record per-reduction dependencies: when `whnf` traverses a definition (via `global-env-lookup` inside reduction), tag the cache entry with the definition-cell it depends on
- [ ] Wire invalidation propagator: when a definition-cell changes (via ATMS retraction in LSP, or re-elaboration), fire a propagator that removes all cache entries whose reduction touched that definition
- [ ] ATMS tagging for speculative reductions: cache entries written during `with-assumption` are tagged with the speculation assumption — retraction clears them automatically (composes with Phase 4b)
- [ ] **Batch mode optimization**: In batch compilation where definitions are write-once, the invalidation propagators never fire — zero overhead. The dependency recording can be gated behind a `(current-track-reduction-deps?)` parameter, defaulting to `#f` for batch and `#t` for LSP.
- [ ] Tests: 10 new tests — cache cell create/read/write, dependency recording during reduction, invalidation on definition change, ATMS-tagged cache retraction, batch-mode fast path (no dependency tracking overhead)

**Files touched**: `reduction.rkt` (~60 LOC — dependency tracking in `whnf`/`nf`), `infra-cell.rkt` (~30 LOC — cache cell factory + invalidation propagator), `driver.rkt` (~5 LOC — cache cell registration)
**Risk**: Medium — reduction is the hottest path; dependency recording must be zero-cost in batch mode. The write-through pattern keeps the fast hash for reads; the cell layer is write-only metadata.
**Key insight**: With definition-cells (3a) + dependency wiring (3b) + cache cells (3e), the network *knows* which cached results are stale. This makes incremental re-elaboration correct by construction — stale cache entries are structurally impossible.

**Commit gate**: Full test suite passes, no performance regression in batch mode (cache dependency tracking off), reduction cache invalidation works when definitions change, canary files pass

---

## Phase 4: Speculation → ATMS Assumptions (Correct by Construction)

**Goal**: Replace the fragile `save-meta-state`/`restore-meta-state!` box-snapshot pattern with ATMS assumption creation/retraction (infrastructure built in Phase 0b). Speculative type-checking (Church folds, union types, bare params) creates named assumptions that can be committed or retracted structurally.

**Synergy unlocked**: §5.5 — Speculative Type-Checking Becomes ATMS Assumptions

### 4a: Speculation Side-Effect Audit

- [ ] For each speculation call site, audit **exactly** which state is modified during speculation:
  - Church fold attempts (`try-elaborate-church-fold`): metas created, constraints added, trait lookups attempted
  - Union type checking (`try-union-type-check`): metas created, unifications attempted
  - Bare param inference (`try-bare-param`): metas created, type checked
  - `elab-speculation-bridge.rkt`: bridge pattern
- [ ] Identify any side-effects that fall **outside** the ATMS assumption scope — i.e., writes to cells that existed before the speculation started and would not be tagged by `with-assumption`
- [ ] **Key semantic difference**: the current snapshot is *total* (restores ALL state). ATMS retraction is *selective* (only retracts content tagged with the assumption). If speculation modifies pre-existing cells, those modifications must also be tagged. Design solution: `with-assumption` must tag ALL cell writes during its dynamic extent, including writes to pre-existing cells — not just writes to cells created during the extent.
- [ ] Document findings per speculation site

**Files touched**: None (audit only)
**Risk**: None — this is analysis that de-risks 4b

### 4b: Replace save/restore with Assumptions

- [ ] Replace each speculation site: `save-meta-state` → `make-assumption` + `with-assumption`; failed path → `retract-assumption!`; success path → `commit-assumption!`
- [ ] Known call sites:
  - Church fold attempts (elaborator.rkt — `try-elaborate-church-fold`)
  - Union type checking (elaborator.rkt — `try-union-type-check`)
  - Bare param inference (elaborator.rkt — `try-bare-param`)
  - `elab-speculation-bridge.rkt` — bridge for speculative elaboration
- [ ] Tests: Church fold tests, union type tests, bare param tests — all must pass
- [ ] Verify: no more `save-meta-state` calls remain in codebase
- [ ] Run `examples/` canary files — Level 3 WS validation

**Files touched**: `elaborator.rkt` (~50 LOC changed), `elab-speculation-bridge.rkt` (~30 LOC changed), `metavar-store.rkt` (~20 LOC — deprecate save/restore)
**Risk**: Medium — each speculation site has subtly different semantics; must verify one-by-one

### 4c: Remove Legacy Snapshot Infrastructure

- [ ] Remove `save-meta-state` and `restore-meta-state!` from `metavar-store.rkt`
- [ ] Remove the 6-box snapshot pattern
- [ ] Audit for any remaining references
- [ ] Run full test suite — 0 regressions
- [ ] Run `examples/` canary files — Level 3 WS validation
- [ ] Check for whale files (ATMS overhead)

**Files touched**: `metavar-store.rkt` (~60 LOC removed)
**Commit gate**: Full test suite passes, canary files pass, box-snapshot pattern fully retired

---

## Phase 5: Driver Simplification (Payoff)

**Goal**: With Phases 1–4 complete, the driver's per-command orchestration simplifies dramatically. The explicit pipeline stages (elaborate → resolve-traits → check-unresolved → zonk) collapse into "add form to network, run to quiescence, read results."

### 5a: Simplify Per-Command Parameterize

- [ ] Remove parameters from the per-command `parameterize` block that are now infra-cells:
  - All 24 registry parameters
  - 3 warning parameters
  - 2 narrowing constraint parameters
  - Constraint store, wakeup registry, trait/hasmethod/capability constraint maps
  - Retry flags (already removed in Phase 1e)
- [ ] Replace `reset-meta-store!` with network assumption management (retract per-command assumption, create new one)
- [ ] Reduce the `process-command` pipeline from 5 explicit phases to:
  1. Create per-form assumption
  2. Elaborate (writes to cells)
  3. Run network to quiescence (replaces explicit resolve-traits + retry loops)
  4. Read results from cells (replaces explicit zonking of constraint-dependent state)
  5. Zonk final expression (still needed — reads from cells but is a pure traversal)
- [ ] Tests: Full suite; `.prologos` acceptance files; `examples/` canary files

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
| `infra-cell.rkt` (NEW) | 0a–0c | New module: merge functions, cell factories, ATMS assumptions, registration protocol |
| `metavar-store.rkt` (1125 LOC) | 1a–1e, 4b–4c, 5b | Constraint cells, remove retry infra, remove snapshot |
| `macros.rkt` (8968 LOC) | 1b, 1d, 2a–2c | Trait resolution wiring, registry cells |
| `global-env.rkt` (81 LOC) | 3a, 3d | Per-definition cells, retire current-global-env |
| `driver.rkt` (1968 LOC) | 1a, 3a, 5a | Network init, per-command simplification |
| `elaborator.rkt` (3924 LOC) | 3b, 4b | Dependency recording, speculation replacement |
| `namespace.rkt` (652 LOC) | 3c | Module registry cells |
| `reduction.rkt` (~2000 LOC) | 3e | Cache cells, dependency tracking in whnf/nf |
| `constraint-propagators.rkt` (292 LOC) | 1d | Compose with infra-cell propagators |
| `elab-speculation-bridge.rkt` (216 LOC) | 4b | Replace save/restore with assumptions |
| `warnings.rkt` | 2c | Warning cells |
| `global-constraints.rkt` | 2c | Narrowing constraint cells |

---

## Test Strategy

### Commit Gates

| Gate | When | Criteria |
|------|------|----------|
| Phase 0 commit | After 0e | All new tests pass, full suite 0 regressions, parallel ≡ sequential, canary files pass |
| Phase 1 commit | After 1e | Full suite passes, retry infra removed, no whale files, canary files pass |
| Phase 2 commit | After 2c | Full suite passes, all 24+3+2 params migrated, canary files pass |
| Phase 3 commit | After 3d | Full suite passes, Level 3 WS validation, global-env retired, canary files pass |
| Phase 4 commit | After 4c | Full suite passes, snapshot infra removed, canary files pass |
| Phase 5 commit | After 5b | Full suite passes, no perf regression, docs updated |

### Baseline Metrics (Captured Before Sprint)

| Metric | Value |
|--------|-------|
| Tests | 6733 → 6803 (after Phase 0) |
| Test files | 349 → 353 (4 new infra-cell test files) |
| Failures | 0 |
| Wall time | ~190s → ~209s (includes new test files) |

### Performance Targets

**Regression budget**: Total wall time increase ≤ 10% (~19s). Propagator cell overhead should be negligible — the existing elaboration network adds <5s to the suite. If any phase pushes wall time beyond budget, profile and optimize before proceeding.

**Parallel speedup target**: On files with ≥10 independent definitions, BSP scheduling should demonstrate measurable speedup over sequential. This is an aspiration, not a hard gate — but it establishes that parallel propagation should produce observable benefit, not just theoretical safety.

### Test Isolation with Unified Networks

The shared fixture pattern (`define-values` at module level, per-test `parameterize`) must be adapted for unified networks. Three-tier approach:

1. **Shared infrastructure cells**: Prelude definitions, module registry, trait/instance registries — loaded once at module level (same as today's shared fixture). These cells persist across tests.
2. **Per-test elaboration cells**: Each test creates a fresh per-test assumption via `with-assumption`. Metavariables, constraints, and per-test definitions are tagged with this assumption. After each test, the assumption can be retracted — or simply discarded (the test reads results before the assumption is needed again).
3. **Fresh `current-mult-meta-store` per test**: Preserved from current pattern — each test gets `(make-hasheq)` for multiplicity isolation.

This preserves the shared fixture's performance benefit (prelude loaded once, ~2s saved per test file) while providing per-test isolation through ATMS assumptions rather than full network reconstruction. The ATMS retraction cost is O(tagged-writes) per test, not O(prelude-size).

### Fallback: Hybrid ATMS + Parameterize Isolation

If ATMS retraction proves too expensive for high-write-count tests (e.g., tests that create hundreds of metavariables and constraints), the fallback is a **hybrid** approach:

- **ATMS assumptions** for infrastructure cells (registries, global-env, module registry) — these have low write counts and high benefit from structural isolation
- **`parameterize` with fresh hasheqs** for per-test meta isolation (`current-mult-meta-store`, metavariable cells) — the current pattern, which is already fast and well-tested

This hybrid approach preserves the architectural benefit of unified cells (composition synergies, reactive propagation) while using the faster mechanism where write-heavy transient state dominates. The choice between full-ATMS and hybrid should be made empirically in Phase 0e based on benchmark results comparing:
- ATMS retraction cost for a typical test (~50–200 meta writes)
- `parameterize` cost for the same test (baseline, already measured)

If ATMS retraction adds <5ms per test (compared to ~2ms for `parameterize`), use full ATMS. If >20ms, use hybrid. Between 5–20ms, evaluate based on composition benefits (do propagators between meta-cells and constraint-cells add value that justifies the overhead?).

---

## Dependency Graph

```
Phase 0 (cell abstraction + ATMS)
    │
    ├──→ Phase 1 (constraints → cells)
    │        │
    │        └──→ [composes with Phase 2 for reactive trait resolution]
    │
    ├──→ Phase 2 (registries → cells)
    │
    ├──→ Phase 3 (global-env → cells) ← uses ATMS from Phase 0b
    │
    ├──→ Phase 4 (speculation → ATMS) ← uses ATMS from Phase 0b
    │
    └──→ Phase 5 (driver simplification) ← needs Phases 1–4
```

Phases 1, 2, 3, and 4 can proceed in parallel after Phase 0. Phase 5 requires all prior phases.

**Recommended execution order** (serial): 0 → 1 → 2 → 3 → 4 → 5
**Aggressive execution order** (parallel where possible): 0 → {1, 2, 3, 4} → 5

---

## Open Questions

| # | Question | Resolution Target |
|---|----------|-------------------|
| 1 | Single network vs layered networks? | **Resolved**: Single network (Phase 0 design decision) |
| 2 | CHAMP box migration path — wrap or replace? | Phase 1a implementation choice |
| 3 | Circular dependency breaking — does unified cell module help? | Phase 5b — evaluate after all migrations |
| 4 | Performance overhead of cells vs raw hash-set! | Phase 0d + each phase gate — measure empirically |
| 5 | Test isolation with unified networks — how does shared fixture interact with single network? | **Resolved**: Three-tier approach — shared infrastructure cells, per-test ATMS assumptions, fresh mult-meta-store (see Test Strategy) |
| 6 | Self-hosting path — should `infra-cell` produce values typeable as Prologos `PropCell`? | Phase 0a design consideration — avoid Racket-specific patterns; evaluate during self-hosting planning |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Trait resolution semantics change subtly during Phase 1 | Medium | High | Exhaustive trait tests (300+ existing); Phase 1 decomplects storage (1a–1c) from wiring (1d) for isolated debugging |
| Global-env cell migration breaks elaboration ordering | Medium | High | Phase 3a read-only legacy adapter is structurally safe (hasheq is frozen); can abort 3d if issues arise |
| Propagator overhead exceeds performance budget | Low | Medium | Profile after Phase 0d; cell operations should be O(1) lookup |
| ATMS retraction is selective where snapshot was total — speculation side-effects escape assumption scope | Medium | High | Phase 4a audits each speculation site before code changes; `with-assumption` must tag ALL writes during dynamic extent |
| `macros.rkt` changes in Phase 2 interact badly with prelude loading | Low | High | Prelude loading tests are comprehensive; run affected-tests after each sub-phase |
| Circular dependency worsens with unified cell module | Low | Medium | Phase 5b evaluates; worst case keeps callback pattern (status quo) |
| Test suite slows down due to per-test ATMS assumption overhead | Low | Medium | Three-tier test isolation (shared infra + per-test assumptions) is O(tagged-writes), not O(prelude-size); benchmark in Phase 0e |

---

## Deferred Work (Known)

- **LSP network integration**: The unified network from this sprint becomes the LSP state management network. Integration work is in the LSP roadmap (`2026-03-11_LSP_VSCODE_STAGE2_REFINEMENT.md`), not this sprint.
- **Reduction cache invalidation via cells**: ~~Deferred~~ → Included as Phase 3e. Combinatorial composition with definition cells (3a), dependency wiring (3b), and ATMS speculation (Phase 4) makes structural cache invalidation too valuable to defer.
- **Self-hosting compiler using Prologos propagator cells**: Open Question 6 — the `infra-cell` API should be designed to avoid foreclosing the self-hosting path. Full evaluation deferred to self-hosting planning.

Note: Parallel propagation is **not deferred** — it is inherent in Phase 0's design. The unified network uses `propagator.rkt`'s existing schedulers (sequential, BSP, parallel). Independent propagators fire in parallel automatically via the BSP scheduler. Phase 0d verifies parallel correctness and benchmarks speedup.

---

## Design Critique Log

Findings from principle-alignment review (2026-03-11), incorporated into this revision:

1. **Correct by Construction** — Phase 3a dual-write replaced with read-only legacy adapter (frozen hasheq → structural impossibility of divergence)
2. **First-Class by Default** — Self-hosting design note added to Phase 0; Open Question 6 tracks `PropCell` alignment
3. **Completeness Over Deferral** — ATMS assumptions pulled into Phase 0b (needed by Phase 3 and Phase 4); `merge-replace-with-assumption` included
4. **The Most Generalizable Interface** — Phase 0a now defines general `net-new-cell-with-merge` as primary API; domain-specific factories are convenience wrappers
5. **Simplicity of Foundation** — Phase 0b replaced central manifest (`make-unified-network`) with registration protocol (`network-register-cell!`); each module self-contained
6. **Decomplection** — Phase 1 split into storage migration (1a–1c, low risk) and resolution wiring (1d, medium risk)
7. **Speculation audit** — Phase 4a added: audit each speculation site's side-effects before code changes; documents total-vs-selective retraction semantic gap
8. **WS-Mode Validation** — Level 3 canary file validation added to every phase commit gate
9. **Parallel speedup target** — Phase 0d now benchmarks speedup ratios, not just correctness
10. **Test isolation** — Three-tier approach documented: shared infra cells, per-test ATMS assumptions, fresh mult-meta-store
