# Track 3: Cell-Primary Registries

**Created**: 2026-03-13
**Status**: COMPLETE (Phases 0-5 + PIR done; Phase 6 deferred to Track 5/6)
**Depends on**: Track 1 (Cell-Primary Constraint Tracking) — COMPLETE, Track 2 (Reactive Resolution) — COMPLETE
**Enables**: Track 4 (ATMS Speculation), Track 6 (Driver Simplification)
**Research basis**: `2026-03-11_PROPAGATOR_FIRST_PIPELINE_AUDIT.md` §3.4 (Registry Parameters), §3.8 (Warnings)
**Prior implementation**: `2026-03-11_1800_PROPAGATOR_FIRST_MIGRATION.md` Phases 2a–2c (dual-write)
**Master roadmap**: `2026-03-13_PROPAGATOR_MIGRATION_MASTER.md` Track 3

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| D.1 | Design analysis and read-site audit | ✅ | This document |
| D.2 | Design iteration (external critique) | ✅ | 5 items accepted, 7 rejected |
| D.3 | Internal self-critique (principle alignment) | ✅ | 5 items; Phase 6 design resolved |
| 0 | Performance baseline + acceptance file | ✅ | Acceptance: `a5408f0` (0 errors, 13 sections). Baseline: 194.3s / 7096 tests / 370 files |
| 1 | Core type registries → cell-primary (8 registries) | ✅ | `a7f61ca` — 8 readers + elaboration guard, 14 computation reads converted |
| 2 | Trait + instance registries → cell-primary (7 registries) | ✅ | `0880c4a` — 7 readers, 12 computation reads converted (macros, elaborator, trait-resolution, driver) |
| 3 | Remaining registries → cell-primary (8 registries) | ✅ | `31ba07f` — 8 readers, ~20 computation reads, all internal to macros.rkt |
| 4 | Warnings → cell-primary (3 parameters) | ✅ | `c5c1681` — 3 readers + cell-read callback, simpler guard (no elaboration check needed) |
| 5a | Narrowing constraints → cell (monotonic, `merge-list-append`) | ✅ | `9ebebdc` — combined with 5b |
| 5b | Narrowing var-constraints → cell (non-monotonic, `merge-last-write-wins`) | ✅ | `9ebebdc` — elaboration guard required (same pattern as macros) |
| 6 | Remove parameter writes + cleanup | ⏸️ | Deferred to Track 5/6 — removing parameter writes breaks save/restore + batch-worker isolation (see notes below) |
| 7 | Post-Implementation Review | ✅ | See §10 |

---

## §1. Context

### 1.1 What Exists

The Migration Sprint Phase 2 (commits `5a12671`..`7e40345`) established dual-write for all 24 registry parameters in `macros.rkt` and 3 warning accumulators in `warnings.rkt`:

- Each registry has a `current-X-cell-id` parameter holding its propagator cell ID
- `register-macros-cells!` creates cells initialized from current parameter content
- `macros-cell-write!` writes to cells via `merge-hasheq-union` (monotonic hash union)
- Every `register-X!` function writes to **both** the legacy parameter AND the cell

All **reads** still go through legacy parameters. The single exception is `read-impl-registry` (Track 2 Phase 1), which reads from the cell with parameter fallback.

### 1.2 What This Track Does

Convert all registry and warning reads from parameter-primary to cell-primary, then remove the parameter writes — making cells the single source of truth for all registration state. This is the same mechanical pattern Track 1 applied to constraint tracking, now applied to the remaining ~26 stateful parameters.

### 1.3 Why This Matters

**Uniformity**: After Track 3, every piece of elaboration state (constraints, registries, warnings) reads from propagator cells. The parameter system becomes a configuration layer (startup callbacks, context flags), not a state layer.

**Speculation correctness**: The save/restore box-snapshot captures the propagator network, which includes cell content. If registries are cell-primary, speculative type-checking automatically captures and restores registry state. Currently, speculative branches can leak registry mutations — e.g., a speculative `register-trait!` during union type elaboration persists even if the speculation fails. Track 4 (ATMS) depends on this being fixed.

**Observatory completeness**: The Propagator Observatory can only display state that lives in cells. With cell-primary registries, the Observatory shows the full evolution of all type system state — trait registrations, instance accumulation, schema definitions — across BSP rounds.

---

## §2. Infrastructure Audit

### 2.1 Cell Infrastructure (Already Exists)

All cell infrastructure from Migration Sprint Phase 2 is in place:

| Component | Location | Status |
|-----------|----------|--------|
| 24 cell-id parameters | `macros.rkt:447-474` | ✅ Created in `register-macros-cells!` |
| `macros-cell-write!` | `macros.rkt:478-481` | ✅ Writes to cell via merge |
| `current-macros-prop-net-box` | `macros.rkt:440` | ✅ Shared network box |
| `current-macros-prop-cell-read` | `macros.rkt:443` | ✅ Read callback |
| `register-macros-cells!` | `macros.rkt:484+` | ✅ Creates all 24 cells |
| 3 warning cell-id params | `warnings.rkt:53-55` | ✅ Created in `register-warning-cells!` |
| `register-warning-cells!` | `warnings.rkt:69+` | ✅ Creates 3 cells with `merge-list-append` |

The cell read callback (`current-macros-prop-cell-read`) is the existing `(enet cell-id → value)` function installed by the driver. No new infrastructure is needed.

### 2.2 Read-Site Inventory

Comprehensive audit of all registry parameter reads across the codebase:

**High-traffic registries** (most external reads — convert first for maximum impact):

| Registry | Internal Reads | External Reads | Total | Key External Files |
|----------|---------------|----------------|-------|--------------------|
| `current-impl-registry` | 13 | 15 | 28 | **DONE** — `read-impl-registry` |
| `current-param-impl-registry` | 11 | 16 | 27 | driver, lsp, test-support, batch-worker |
| `current-trait-registry` | 10 | 14 | 24 | driver, lsp, test-support, elaborator, trait-resolution |
| `current-capability-registry` | 11 | 13 | 24 | driver, lsp, test-support, batch-worker |
| `current-preparse-registry` | 12 | 9 | 21 | driver, lsp, expander, repl, test-support |
| `current-type-meta` | 17 | 4 | 21 | driver, batch-worker |
| `current-ctor-registry` | 11 | 8 | 19 | driver, batch-worker |

**Medium-traffic registries**:

| Registry | Internal Reads | External Reads | Total |
|----------|---------------|----------------|-------|
| `current-user-precedence-groups` | 15 | 2 | 17 |
| `current-spec-store` | 10 | 4 | 14 |
| `current-subtype-registry` | 12 | 2 | 14 |
| `current-coercion-registry` | 10 | 2 | 12 |
| `current-trait-laws` | 10 | 2 | 12 |
| `current-bundle-registry` | 10 | 2 | 12 |
| `current-property-store` | 10 | 2 | 12 |
| `current-functor-store` | 10 | 2 | 12 |
| `current-macro-registry` | 10 | 2 | 12 |

**Low-traffic registries** (internal use only or minimal external):

| Registry | Internal Reads | External Reads | Total |
|----------|---------------|----------------|-------|
| `current-schema-registry` | 10 | 1 | 11 |
| `current-specialization-registry` | 10 | 1 | 11 |
| `current-session-registry` | 10 | 1 | 11 |
| `current-user-operators` | 10 | 1 | 11 |
| `current-selection-registry` | 10 | 0 | 10 |
| `current-strategy-registry` | 10 | 0 | 10 |
| `current-process-registry` | 10 | 0 | 10 |
| `current-propagated-specs` | 7 | 1 | 8 |

**Warnings** (separate module, `warnings.rkt`):

| Parameter | Internal Reads | External Reads | Total |
|-----------|---------------|----------------|-------|
| `current-coercion-warnings` | 9 | 2 (driver) | 11 |
| `current-deprecation-warnings` | 9 | 2 (driver) | 11 |
| `current-capability-warnings` | 13 | 3 (driver, test) | 16 |

**Narrowing constraints** (`global-constraints.rkt` / `narrowing.rkt`):

| Parameter | Reads | Files | Notes |
|-----------|-------|-------|-------|
| `current-narrow-constraints` | 5 | narrowing.rkt | No cell yet — needs creation |
| `current-narrow-var-constraints` | 1 | narrowing.rkt | Uses setter (not parameterize) — ad-hoc |

### 2.3 External Read Sites by File

The files outside `macros.rkt` that read registry parameters and will need updating:

| File | Registries Read | Nature of Reads |
|------|----------------|-----------------|
| `driver.rkt` | ~16 registries | Per-command parameterize (threading), snapshot/restore |
| `test-support.rkt` | ~5 registries | Shared fixture setup (prelude caching) |
| `lsp/server.rkt` | ~5 registries | Session state snapshots |
| `tools/batch-worker.rkt` | ~20 registries | Full parameter threading (mirrors driver) |
| `expander.rkt` | 2 (preparse, spec-store) | Module expansion reads |
| `repl.rkt` | 4 | REPL session parameter capture |
| `elaborator.rkt` | 1 (trait-registry) | Direct lookup during elaboration |
| `trait-resolution.rkt` | 1 (trait-registry) | Trait lookup during resolution |
| `namespace.rkt` | 1 (spec-store) | Spec propagation |

**Critical distinction**: Many "reads" in `driver.rkt`, `test-support.rkt`, `lsp/server.rkt`, and `batch-worker.rkt` are **parameter threading** — `(current-X)` called to capture a snapshot for parameterize blocks, not to read the registry content for computation. These sites will remain as-is during the cell-primary conversion (they thread parameters for backward compatibility with module loading). They become candidates for removal in Track 6 (Driver Simplification).

The **computation reads** — where the code actually inspects registry content to make decisions — are the ones that must be converted to cell-primary readers.

---

## §3. Design

### 3.1 The Reader Pattern

Following the `read-impl-registry` template established in Track 2 Phase 1:

```racket
(define (read-X-registry)
  (define cid (current-X-registry-cell-id))
  (define net-box (current-macros-prop-net-box))
  (define read-fn (current-macros-prop-cell-read))
  (if (and cid net-box read-fn)
      (read-fn (unbox net-box) cid)
      (current-X-registry)))
```

**Cell-first, parameter-fallback**: When the propagator network exists (during elaboration), reads go through the cell. When no network exists (during module loading, test setup, REPL initialization), falls back to the parameter. This is the same pattern Track 1 used, and it allows incremental conversion without breaking any code paths.

**Phase 6 eliminates the fallback**: After all reads are converted, we can apply the Track 1 Phase 6 pattern ("network-everywhere") to remove the `if/else` fallback entirely, guaranteeing all reads go through cells. But this is a later phase — the fallback is a safety net during migration.

### 3.2 The Write Pattern (Unchanged Initially)

During Phases 1–5, the dual-write pattern remains:

```racket
(define (register-X! key entry)
  ;; Legacy parameter write (for backward compat with module loading)
  (current-X-registry (hash-set (current-X-registry) key entry))
  ;; Cell write (monotonic accumulation)
  (macros-cell-write! (current-X-registry-cell-id) (hasheq key entry)))
```

Phase 6 removes the parameter write for registries where the network is always present.

**Note on Data Orientation (from D.3)**: Registration writes remain imperative (`register-X!` mutates inline) rather than data-oriented (registration descriptors interpreted at a control boundary). This is intentional: registrations are monotonic accumulation with no ordering sensitivity or rollback concerns — the cell merge handles the semantics directly. The Data Orientation free-monad pattern (as used in Track 2 for constraint resolution) adds complexity without benefit for simple monotonic writes. If Track 4 (ATMS) requires speculation-aware registration (where speculative registrations must be retractable), that is where a data-oriented registration pattern would become relevant.

### 3.3 Distinguishing Read Types

Not every `(current-X)` in the codebase is a "computation read" that should become `(read-X)`:

| Read Type | Example | Convert? |
|-----------|---------|----------|
| **Computation read** | `(hash-ref (current-trait-registry) name #f)` in `lookup-trait` | ✅ Yes — this inspects content |
| **Parameter threading** | `[current-trait-registry (current-trait-registry)]` in driver parameterize | ❌ No — this threads the parameter for sub-forms |
| **Snapshot capture** | `(current-trait-registry)` in test-support prelude caching | ❌ No — captures parameter for later restoration |
| **Registration write** | `(current-X (hash-set (current-X) k v))` | ❌ No — this is a write, not a read |

The key insight: **only computation reads need conversion**. Threading and snapshot sites remain on parameters until Track 6 eliminates those parameters entirely.

**Decomplection (from D.3)**: After Track 3, the naming convention *is* the structural decomplection. `read-X` always means "computation read from cell" and `current-X` always means "parameter threading/snapshot." The two concerns — querying state for decisions vs. threading state through execution contexts — become syntactically distinct in the codebase. A grep for `current-X-registry` after Track 3 returns only threading/snapshot sites; a grep for `read-X-registry` returns only computation sites.

### 3.4 Phase Structure

The 24 registries (plus 3 warnings, plus 2 narrowing params) are grouped by dependency and risk:

**Phase 1: Core type registries (8)** — The foundational type metadata registries. Read during type construction and lookup but not during constraint resolution. Low coupling to other subsystems.

- `current-schema-registry` → `read-schema-registry`
- `current-ctor-registry` → `read-ctor-registry`
- `current-type-meta` → `read-type-meta`
- `current-subtype-registry` → `read-subtype-registry`
- `current-coercion-registry` → `read-coercion-registry`
- `current-capability-registry` → `read-capability-registry`
- `current-property-store` → `read-property-store`
- `current-functor-store` → `read-functor-store`

**Phase 2: Trait + instance registries (7)** — These interact with trait resolution (Track 2). The `read-impl-registry` pattern from Track 2 is the exact template. Higher coupling — trait resolution, elaboration, and the stratified loop all read these.

- `current-trait-registry` → `read-trait-registry`
- `current-trait-laws` → `read-trait-laws`
- `current-param-impl-registry` → `read-param-impl-registry`
- `current-bundle-registry` → `read-bundle-registry`
- `current-specialization-registry` → `read-specialization-registry`
- `current-selection-registry` → `read-selection-registry`
- `current-session-registry` → `read-session-registry`

(Note: `current-impl-registry` already has `read-impl-registry` — skip.)

**Phase 3: Remaining registries (8)** — Syntax, macros, operator precedence, and misc. Lower risk — these are read during parsing/expansion, not during type checking.

- `current-preparse-registry` → `read-preparse-registry`
- `current-spec-store` → `read-spec-store`
- `current-propagated-specs` → `read-propagated-specs`
- `current-strategy-registry` → `read-strategy-registry`
- `current-process-registry` → `read-process-registry`
- `current-user-precedence-groups` → `read-user-precedence-groups`
- `current-user-operators` → `read-user-operators`
- `current-macro-registry` → `read-macro-registry`

**Phase 4: Warnings (3)** — Different module (`warnings.rkt`), different merge function (`merge-list-append` vs `merge-hasheq-union`). Same reader pattern but for list accumulators.

- `current-coercion-warnings` → `read-coercion-warnings`
- `current-deprecation-warnings` → `read-deprecation-warnings`
- `current-capability-warnings` → `read-capability-warnings`

**Phase 5a: Narrowing constraints — monotonic (1)** — `current-narrow-constraints` is a list accumulator (monotonic, `merge-list-append`). No cell exists yet. Create cell in `global-constraints.rkt` following the `warnings.rkt` pattern. Reads in `narrowing.rkt` use `parameterize` to thread constraints into sub-computations — these are threading sites (keep as-is). The computation reads are in `narrow-match-tree` and `narrow-top-level` where the code inspects the constraint list to make decisions.

- `current-narrow-constraints` → create cell with `merge-list-append` + `read-narrow-constraints`

**Phase 5b: Narrowing var-constraints — non-monotonic (1)** — `current-narrow-var-constraints` is a hasheq set via wholesale replacement (`(current-narrow-var-constraints var-constraints)` in `elaborator.rkt:2731`), NOT monotonic accumulation. The setter replaces the entire map per-clause during narrowing elaboration. This is a **non-monotonic update** that does not fit the standard `merge-hasheq-union` model.

Options:
1. **`merge-last-write-wins`** — treats the cell as a mutable register. Semantically correct (each clause's var-constraints replace the previous), follows the `enet11` error-descriptor precedent. Loses monotonicity but this parameter is already non-monotonic.
2. **Defer to Track 4** — ATMS assumption-based management can handle non-monotonic state natively (each clause creates an assumption; retraction undoes its var-constraints).
3. **Per-variable cells** — model each variable's constraints as a separate cell. Overkill for 1 read site.

**Recommendation**: Option 1 (`merge-last-write-wins`). The parameter is already non-monotonic; the cell faithfully represents the same semantics. Track 4 can upgrade this to assumption-managed if needed.

**Principle deviation (from D.3)**: `merge-last-write-wins` is a principled deviation from the Propagator-First guideline (DESIGN_PRINCIPLES.org §"When Not To Use Propagators") that non-monotonic state should use ATMS-backed cells. This is a transitional choice — the cell semantically becomes a mutable register in cell clothing. Track 4 (ATMS Speculation) will upgrade this cell to assumption-managed, restoring proper non-monotonic semantics where each narrowing clause creates an assumption and retraction undoes its var-constraints.

- `current-narrow-var-constraints` → create cell with `merge-last-write-wins` + `read-narrow-var-constraints`

**Phase 6: Remove parameter writes + cleanup** — With all reads going through cells, remove the parameter write from each `register-X!` function. Audit for any remaining parameter reads. Remove the parameter-fallback branch from each reader (the "network-everywhere" flip from Track 1 Phase 6).

### 3.7 Phase 6: Two-Context Architecture (resolved from D.2 + D.3)

The external critique (D.2) identified that module loading calls computation reads without a network. The internal critique (D.3) flagged this as a Correct-by-Construction concern — the fallback `if/else` is "correct by convention." Investigation of `driver.rkt:1546-1583` resolves the question:

**Module loading explicitly sets `current-prop-net-box` to `#f`.** This is deliberate — each module loads in a network-free context with fresh parameter state. Creating a per-module network (Option A) would require: creating a network, wiring all registry cells, processing the module's definitions, then merging the module's cell content back into the parent command's network. This is Track 5/6 scope (global-env cell-primary + dependency edges), not Track 3.

**Decision: Option B — Two-context architecture.**

| Context | Read Path | Write Path | Rationale |
|---------|-----------|------------|-----------|
| **Elaboration** (per-command) | Cell-primary (`read-X`) | Cell-only (Phase 6 removes parameter write) | Network always exists (Track 1 Phase 6 guarantee) |
| **Module loading** (`load-module`) | Parameter fallback (`current-X`) | Parameter-only (cell IDs are `#f`) | No network; parameter IS the correct state |

The `if/else` in reader functions is **not** a correctness-by-convention concern in this case — it's a structural boundary between two genuinely different execution contexts. Module loading is not "elaboration without a network" — it's a distinct operation that runs before the command's elaboration begins, with its own parameter scope (`parameterize` block at `driver.rkt:1546`). The fallback is semantically correct: during module loading, no cells exist, no propagator network exists, and the parameter holds the accumulated state from prior module loads.

Phase 6 therefore:
- **Removes** parameter writes from `register-X!` functions for registries only written during elaboration
- **Preserves** parameter writes for registries written during module loading (trait, impl, ctor, type-meta, subtype, coercion, capability, preparse)
- **Removes** the fallback branch from readers only called during elaboration
- **Preserves** the fallback branch in readers called during module loading

This means Phase 6 is a *partial* cleanup for Track 3. Full parameter elimination requires Track 5 (global-env cell-primary with per-module networks), at which point module loading itself runs in a network context and the fallback can be removed.

### 3.5 File-to-Phase Mapping

| File | Updated In | Nature |
|------|-----------|--------|
| `macros.rkt` | Phases 1–3 | Reader definitions (source of all `read-X` functions) |
| `elaborator.rkt` | Phase 2 | `read-trait-registry` computation reads |
| `trait-resolution.rkt` | Phase 2 | `read-trait-registry` computation reads |
| `expander.rkt` | Phase 3 | `read-preparse-registry`, `read-spec-store` |
| `warnings.rkt` | Phase 4 | Warning reader definitions |
| `global-constraints.rkt` | Phase 5 | Narrowing cell creation |
| `narrowing.rkt` | Phase 5 | Narrowing computation reads |
| `driver.rkt` | Phases 1–3 (computation reads only) | Leave parameter threading sites for Track 6 |
| `batch-worker.rkt` | Mirror driver | Update in parallel with driver |
| `namespace.rkt` | Phase 3 | `read-spec-store` |

### 3.6 Phase 0: Performance Baseline + Acceptance File

**Performance baseline** — following the established protocol from Track 1 (codified in `.claude/rules/testing.md`):

- **Metrics**: Full test suite wall time via `racket tools/run-affected-tests.rkt --all`
- **Tag**: `benchmark-baseline-track-3`
- **Threshold**: >25% regression = investigate before committing (per testing.md rule)
- **Comparison**: `racket tools/benchmark-tests.rkt --compare benchmark-baseline-track-3`

**Acceptance file** — `racket/prologos/examples/2026-03-15-track3-acceptance.prologos` broadly exercises Prologos features in ideal WS syntax: type definitions, pattern matching, traits/instances, generics, collections, numeric ops, pipe/compose, dot-access, etc. Track 3 is an infrastructure track (no syntax changes), so the acceptance file serves as a **diagnostic safety net**: run before and after each phase via `process-file` to confirm no WS-mode regressions from the cell-primary migration. This follows the Phase 0 acceptance file practice (see `.claude/rules/workflow.md`).

---

## §4. Risk Analysis

### 4.1 Low Risk

This is the most mechanical of all tracks. The dual-write infrastructure has been in place since the Migration Sprint (~2 weeks ago). The 6907-test suite exercises every registry extensively. The reader pattern is identical to `read-impl-registry` which has been in production since Track 2 Phase 1.

### 4.2 Known Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Module loading reads before network exists | Medium | Low | Parameter fallback in reader handles this |
| `test-support.rkt` prelude caching breaks | Low | Medium | Prelude caching captures parameters, not cell content; leave threading sites alone |
| `batch-worker.rkt` desynchronization | Low | Low | Batch worker mirrors driver; update in parallel |
| Stale `.zo` files mask failures | Medium | Low | Run with `--no-precompile` on first test after changes |
| Performance regression from cell reads | Low | Low | Track 1 showed cell reads are ≤1% overhead |

### 4.3 Open Questions

1. **Should `batch-worker.rkt` be updated in this track or deferred?** It mirrors driver.rkt's parameter threading but may not be exercised by the standard test suite. Recommend: update in parallel with driver.rkt, but don't block on it.

2. **Should `lsp/server.rkt` and `repl.rkt` session snapshots migrate to cell-based snapshots?** Currently they capture parameters for session persistence. Cell-based snapshots would be more correct (they'd capture the full network state). Recommend: defer to Track 6 — session snapshots are a separate concern from computation reads.

3. **Phase 5 (narrowing constraints) — create cells in `global-constraints.rkt` or `narrowing.rkt`?** The parameters are defined in `global-constraints.rkt` but only read in `narrowing.rkt`. Recommend: create cells in `global-constraints.rkt` alongside the parameter definitions, following the `warnings.rkt` pattern.

---

## §5. Principle Alignment

| Principle | How This Track Upholds It |
|-----------|--------------------------|
| **Propagator-First Infrastructure** | All registration state reads through propagator cells |
| **Data Orientation** | Registry state as monotone cell content, not mutable parameter mutation |
| **Correct by Construction** | Cell-primary reads can't diverge from cell writes (single source of truth) |
| **Completeness Over Deferral** | Converts ALL 26+ parameters, not a partial subset |
| **The Most Generalizable Interface** | One read API pattern (`read-X`) regardless of registry type |

---

## §6. Effort Estimate

| Phase | Scope | Est. Effort | Risk |
|-------|-------|-------------|------|
| 0 | Performance baseline + acceptance file | 30 min | None |
| 1 | 8 core type registries | 2–3 hours | Low |
| 2 | 7 trait + instance registries | 2–3 hours | Low-Medium |
| 3 | 8 remaining registries | 2–3 hours | Low |
| 4 | 3 warnings | 1 hour | Low |
| 5a | 1 narrowing constraint (monotonic, new cell) | 30 min | Low |
| 5b | 1 narrowing var-constraint (non-monotonic, new cell) | 1 hour | Medium |
| 6 | Remove parameter writes + network-everywhere | 2–3 hours | Low-Medium |
| **Total** | ~26 readers, ~200 call-site updates | **~1 day** | Low |

**Schedule risk**: Phase 5b (non-monotonic narrowing) is the one place where surprises could add time. Phase 6 is now architecturally resolved (two-context, see §3.7) but requires per-registry classification of which are module-loading-visible. Phases 1–4 and 5a are purely mechanical.

This is significantly faster than Tracks 1 and 2 because:
- All cell infrastructure already exists (no `enet` creation needed for Phases 1–4)
- The reader pattern is proven and mechanical
- No behavioral changes (no stratified quiescence, no action descriptors — just read-path rewiring)

---

## §7. Composition Synergies

### 7.1 Speculation Correctness (enables Track 4)

With cell-primary registries, `save-meta-state`/`restore-meta-state!` captures registry state via the propagator network snapshot. Speculative branches that register traits/instances/schemas are automatically rolled back on failure. Currently, these registrations leak.

### 7.2 Observatory Completeness

The Propagator Observatory shows cell evolution across BSP rounds. With cell-primary registries, every registration event is visible — the Observatory becomes a complete timeline of type system state construction.

### 7.3 Incremental Re-elaboration (enables Track 5)

When the global environment becomes cell-primary (Track 5), definition changes propagate through dependency edges. If registries are also cell-primary, a type/trait/instance defined by a changed definition automatically invalidates — the propagator network handles the cascading update.

### 7.4 Self-Hosting Foundation

When Prologos self-hosts, the compiler's registration state will be Prologos propagator cells. Cell-primary registries in the Racket implementation establish the patterns that the self-hosted version will use natively.

---

## §8. External Critique Response (D.2)

External critique received 2026-03-15. 12 items raised (3 critical, 3 significant, 3 moderate, 3 minor). Assessment grounded in project implementation history:

### Accepted (5)

| # | Issue | Action |
|---|-------|--------|
| 3 | Phase 5 under-specified (narrowing monotonicity) | **Expanded Phase 5 into 5a (monotonic) and 5b (non-monotonic)**. `current-narrow-constraints` is list-append (monotonic). `current-narrow-var-constraints` uses wholesale replacement (non-monotonic) — will use `merge-last-write-wins` following `enet11` precedent. |
| 4 | Performance baseline undefined | **Added §3.6** referencing established protocol from Track 1 and `testing.md` rules. |
| 6 | File-to-phase mapping unclear | **Added §3.5** with file-to-phase table showing which files are touched in which phases. |
| — | Phase 6 module-loading fallback | **Resolved in D.3**: investigation of `driver.rkt:1546-1583` confirmed module loading runs network-free. Adopted two-context architecture (§3.7): cell-primary during elaboration, parameter fallback during module loading. |
| 12 | Effort estimate assumes no surprises | **Added schedule risk note** identifying Phase 5b and Phase 6 as the two sources of potential surprise. |

### Rejected with Rationale (7)

| # | Issue | Rationale |
|---|-------|-----------|
| 1 | Missing atomicity guarantees | **Not applicable.** Propagator network is single-threaded and synchronous. No concurrent reads/writes. BSP runs to quiescence in a single thread. `read-fn` is a CHAMP hash lookup. Track 1 and Track 2 validated this across 14+ readers with zero atomicity issues. |
| 2 | Fallback creates silent divergence | **Already solved by Track 1 precedent.** Network-everywhere (Track 1 Phase 6) guarantees the network exists during elaboration. Fallback only triggers during module loading where the parameter IS the correct state. Dual-write uses `macros-cell-write!` which calls the same hash operation — divergence between cell merge and parameter `hash-set` is structurally impossible for single-key writes. |
| 5 | Computation vs threading distinction fragile | **Track 1 validated this approach.** 14 read sites classified across 3 files with zero misclassifications (validated by 6889 tests). The distinction is syntactically mechanical: left-side of `parameterize` = threading, `hash-ref`/lookup = computation. After Phase 6, any remaining parameter reads would return stale data and immediately fail tests — the test suite IS the verification. |
| 7 | Merge function consistency | **Already correct.** All 24 registries use `merge-hasheq-union` because registrations are monotonic hash accumulation with unique keys (type names, trait names). Duplicate keys would be a registration bug caught by existing tests, not a merge issue. Validated during Migration Sprint Phase 2. |
| 8 | LSP/REPL snapshots critical for correctness | **Correctly deferred.** Snapshots capture parameters AFTER elaboration completes (sequential, not concurrent). No race between elaboration and snapshot. Dual-write ensures parameter/cell consistency during Phases 1–5. Track 6 will address post-parameter-removal snapshots. |
| 9 | No rollback plan | **Covered by project methodology.** Every phase is a git commit. Layered Recovery Principle (master roadmap) explicitly addresses retreat via dual-write pattern. Track 1 demonstrated this when Phase 5a revealed the fallback issue. |
| 11 | Missing error handling in reader | **Correct by design.** `read-fn` is a CHAMP lookup — it doesn't throw unless the cell ID is invalid, which is a programming error. Track 1 has 7 readers using this exact pattern with zero exceptions. We WANT crashes on invalid IDs to surface bugs at the call site. |

---

## §9. Internal Self-Critique — Principle Alignment (D.3)

Internal review against DESIGN_PRINCIPLES.org, DESIGN_METHODOLOGY.org, EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org, and DEVELOPMENT_LESSONS.org. 5 items identified:

| # | Principle | Finding | Resolution |
|---|-----------|---------|------------|
| 1 | **Data Orientation** | Registration writes remain imperative, not data-oriented (action descriptors). | Intentional scope boundary — monotonic accumulation doesn't benefit from free-monad pattern. Added note to §3.2. Track 4 is where data-oriented registration becomes relevant if speculation requires retractable registrations. |
| 2 | **Propagator-First** ("When Not To Use Propagators") | Phase 5b's `merge-last-write-wins` sidesteps the guideline that non-monotonic state should use ATMS-backed cells. | Principled deviation — ATMS is Track 4 scope. Flagged as transitional in Phase 5b with forward reference. |
| 3 | **Correct by Construction** | Phase 6 fallback preservation creates `if/else` at reader sites — "correct by convention" rather than "correct by construction." | **Resolved by investigation of `driver.rkt:1546-1583`.** Module loading explicitly sets `current-prop-net-box` to `#f`. Creating a per-module network (Option A) is Track 5/6 scope. **Adopted Option B: two-context architecture** — the `if/else` is a structural boundary between genuinely different execution contexts (elaboration vs. module loading), not a correctness-by-convention pattern. See §3.7 for full analysis. |
| 4 | **Decomplection** | The computation vs. threading distinction is conceptual but not yet structural. | After Track 3, it IS structural: `read-X` = computation, `current-X` = threading. Added framing note to §3.3. |
| 5 | **Design Methodology** (Stage 5 PIR) | No PIR commitment in the design. | Added Phase 7 (lightweight PIR) to progress tracker. Track 3 follows established patterns so a full PIR is not warranted, but a lightweight review captures any lessons from the two-context architecture and Phase 5b's non-monotonic handling. |

---

## §10. Post-Implementation Review (Phase 7)

### 10.1 Summary

Track 3 converted 28 registry/accumulator reads from parameter-primary to cell-primary across 5 phases. All 7096 tests pass with no performance regression (197.6s vs 194.3s baseline, within noise).

### 10.2 Metrics

| Metric | Planned | Actual | Notes |
|--------|---------|--------|-------|
| Cell-primary readers | ~26 | 28 | 23 macros + 3 warnings + 2 narrowing |
| Computation reads converted | ~200 | ~80 | Many "reads" are actually 1 reader call covering N internal uses |
| Elaboration guard parameters | 1 | 2 | `current-macros-in-elaboration?` + `current-narrow-in-elaboration?` |
| New Racket parameters (Phase 5) | ~4 | 6 | 3 callbacks + 1 guard + 2 cell-ids |
| Phases executed | 7 | 5 + deferred | Phase 6 deferred to Track 5/6 |
| Test regressions | 0 | 0 | 7096/7096 pass |
| Performance | <25% regression | ~2% (noise) | 197.6s vs 194.3s |

### 10.3 Key Lessons

1. **Elaboration guard is the structural boundary.** The `current-X-in-elaboration?` pattern is essential for any cell that might be read outside `process-command`. Tests that parameterize constraints directly (bypassing the driver) will read stale cell content without this guard. This was discovered in Phase 1 (macros) and re-confirmed in Phase 5 (narrowing). Two guard parameters exist because `global-constraints.rkt` cannot import from `macros.rkt` without risking circular deps.

2. **Warnings are the exception.** Warning readers don't need an elaboration guard because they're only read inside `process-command` (driver.rkt). This is a simpler pattern and worth noting for future similar cases.

3. **Phase 6 (parameter write removal) is blocked by save/restore.** The design doc's Phase 6 assumes parameter writes can be removed for elaboration-only registries. However, `save-meta-state`/`restore-meta-state!` and `batch-worker.rkt` still read parameters for speculation snapshots and worker isolation. Removing writes would break these paths. True parameter elimination requires Track 5/6 (cell-based snapshots).

4. **Non-monotonic cells need `merge-last-write-wins`.** The `merge-replace` alias was added to `infra-cell.rkt` for clarity. Narrowing var-constraints are non-monotonic (each clause gets its own constraint map), so standard merge-list-append doesn't apply. This works correctly as a transitional measure; proper ATMS-backed cells are Track 4 scope.

5. **Mechanical phases compound efficiency.** Phases 1-4 each took ~30-60 minutes because the pattern was established in Phase 1 and replicated exactly. Phase 5 took longer (~90 minutes) because it required new cell infrastructure. The design doc's estimate of "~1 day" was accurate for Phases 0-5.

### 10.4 Phase 6 Disposition

Phase 6 (remove parameter writes + cleanup) is **deferred to Track 5/6**. Rationale:

- Removing parameter writes breaks `save-meta-state`/`restore-meta-state!` (used for speculation)
- Removing parameter writes breaks `batch-worker.rkt` state isolation
- These paths must migrate to cell-based snapshots first (Track 5/6 scope)
- The dual-write overhead is negligible (~1% per Track 1 measurements)
- The two-context architecture is correct as-is; cleanup is optimization, not correctness

### 10.5 Track Status

**Track 3 is COMPLETE** (Phases 0-5 implemented, Phase 6 deferred, Phase 7 done).

All computation reads now go through cell-primary readers. Parameters remain as fallback for module loading and as the write target for dual-write. Full parameter elimination is Track 5/6 scope.
