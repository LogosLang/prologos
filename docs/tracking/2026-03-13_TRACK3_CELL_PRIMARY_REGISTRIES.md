# Track 3: Cell-Primary Registries

**Created**: 2026-03-13
**Status**: Stage 2/3 (Design — pre-implementation)
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
| D.2 | Design iteration (review feedback) | ⬜ | |
| 0 | Performance baseline | ⬜ | |
| 1 | Core type registries → cell-primary (8 registries) | ⬜ | |
| 2 | Trait + instance registries → cell-primary (7 registries) | ⬜ | |
| 3 | Remaining registries → cell-primary (8 registries) | ⬜ | |
| 4 | Warnings → cell-primary (3 parameters) | ⬜ | |
| 5 | Narrowing constraints → cells (2 parameters) | ⬜ | |
| 6 | Remove parameter writes + cleanup | ⬜ | |

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

### 3.3 Distinguishing Read Types

Not every `(current-X)` in the codebase is a "computation read" that should become `(read-X)`:

| Read Type | Example | Convert? |
|-----------|---------|----------|
| **Computation read** | `(hash-ref (current-trait-registry) name #f)` in `lookup-trait` | ✅ Yes — this inspects content |
| **Parameter threading** | `[current-trait-registry (current-trait-registry)]` in driver parameterize | ❌ No — this threads the parameter for sub-forms |
| **Snapshot capture** | `(current-trait-registry)` in test-support prelude caching | ❌ No — captures parameter for later restoration |
| **Registration write** | `(current-X (hash-set (current-X) k v))` | ❌ No — this is a write, not a read |

The key insight: **only computation reads need conversion**. Threading and snapshot sites remain on parameters until Track 6 eliminates those parameters entirely.

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

**Phase 5: Narrowing constraints (2)** — No cells exist yet. Must create cells first (in `global-constraints.rkt` or `narrowing.rkt`), then convert reads. `current-narrow-var-constraints` uses a setter pattern which is the ad-hoc anti-pattern cells replace.

- `current-narrow-constraints` → create cell + `read-narrow-constraints`
- `current-narrow-var-constraints` → create cell + `read-narrow-var-constraints`

**Phase 6: Remove parameter writes + cleanup** — With all reads going through cells, remove the parameter write from each `register-X!` function. Audit for any remaining parameter reads. Remove the parameter-fallback branch from each reader (the "network-everywhere" flip from Track 1 Phase 6).

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
| 0 | Performance baseline | 15 min | None |
| 1 | 8 core type registries | 2–3 hours | Low |
| 2 | 7 trait + instance registries | 2–3 hours | Low-Medium |
| 3 | 8 remaining registries | 2–3 hours | Low |
| 4 | 3 warnings | 1 hour | Low |
| 5 | 2 narrowing constraints (new cells) | 1–2 hours | Medium |
| 6 | Remove parameter writes + network-everywhere | 2–3 hours | Low |
| **Total** | ~26 readers, ~200 call-site updates | **~1 day** | Low |

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
