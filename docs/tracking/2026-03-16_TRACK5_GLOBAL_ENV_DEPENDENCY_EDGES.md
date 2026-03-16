# Track 5: Global-Env Cell-Primary + Dependency Edges — Stage 2/3 Design

**Created**: 2026-03-16
**Status**: DESIGN (Stage 2/3)
**Depends on**: Track 3 ✅ (Cell-Primary Registries), Track 4 ✅ (ATMS Speculation)
**Enables**: Track 6 (Driver Simplification + Cleanup), Track 9 (GDE)
**Master roadmap**: `2026-03-13_PROPAGATOR_MIGRATION_MASTER.md` Track 5
**Prior art**: Track 3 PIR (elaboration guard pattern), Track 4 PIR (dual-write coherence)

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| D.1 | Stage 2/3 design document | 🔄 | This document |
| D.2 | External critique + response | ⬜ | |
| D.3 | Self-critique (principle alignment) | ⬜ | |
| 0 | Performance baseline + acceptance file | ⬜ | |
| 1 | Consolidate global-env writes in driver.rkt | ⬜ | |
| 2 | Definition removal → cell-aware cleanup | ⬜ | |
| 3 | Per-module network scaffolding | ⬜ | |
| 4 | Module loading → cell-primary path | ⬜ | |
| 5 | Dependency edge wiring as propagator edges | ⬜ | |
| 6 | Performance validation + PIR | ⬜ | |

---

## 1. Problem Statement

The global environment is the backbone of the Prologos compilation pipeline — every definition lookup, every module import, every name resolution flows through it. After four tracks of propagator migration, global-env is the last major subsystem with significant legacy parameter traffic.

Currently:
- **269 files** reference `(current-global-env)` (the Layer 2 parameter)
- **36+ references** in `driver.rkt` alone use the env-threading pattern `(current-global-env (global-env-add (current-global-env) ...))`
- **12 `hash-remove` calls** in `driver.rkt` clean up pre-registered definitions on elaboration failure
- **Module loading** runs with `current-global-env-prop-net-box = #f` — no network, parameter-only
- **Definition dependencies** are recorded informationally (`current-definition-dependencies`) but not wired as propagator edges

The two-layer architecture (Migration Sprint Phase 3a–3d) was the right de-risking step: Layer 1 (per-file cells) handles elaboration-time definitions, Layer 2 (parameter) handles prelude/module definitions. But the two-context split means 28 cell-primary readers from Track 3 need elaboration guards, and module loading cannot benefit from any cell infrastructure.

### What Track 5 achieves

1. **Consolidates the env-threading write pattern** — replace 36+ `(current-global-env (global-env-add ...))` calls in driver.rkt with direct `global-env-add` (which already handles the two-layer dispatch internally)
2. **Makes definition failure cleanup cell-aware** — the 12 `hash-remove` sites become `global-env-remove!` operating on both layers
3. **Creates per-module networks** — module loading runs with a lightweight network, writing definitions to cells instead of (only) parameters. This eliminates the two-context architecture
4. **Wires definition dependency tracking as propagator edges** — `current-definition-dependencies` becomes live propagator wiring, enabling incremental re-elaboration

The "biggest payoff" from the Pipeline Audit: incremental module re-elaboration. Combined with Track 4's ATMS, the LSP can retract a definition assumption and let propagation settle rather than re-elaborating an entire file.

---

## 2. Infrastructure Gap Analysis

### What we have (from Tracks 1–4)

| Infrastructure | Status | Location |
|----------------|--------|----------|
| Per-definition cells in prop-network | ✅ | `global-env.rkt` Phase 3a — `definition-cell-write!`, `register-global-env-cells!` |
| Two-layer lookup (`global-env-lookup-type`/`value`) | ✅ | `global-env.rkt` — Layer 1 first, Layer 2 fallback |
| Definition dependency recording | ✅ | `global-env.rkt` Phase 3b — `record-definition-dependency!`, informational edges |
| Elaboration guard pattern | ✅ | Track 3 — `current-macros-in-elaboration?`, `current-narrow-in-elaboration?` |
| TMS cells for speculation | ✅ | Track 4 — `tms-cell-value`, depth-0 fast path |
| Error descriptor cell | ✅ | Track 2 Phase 7 — `current-error-descriptor-cell-id`, `read-error-descriptors` |
| Cell-primary readers for all registries | ✅ | Track 3 — 28 readers across macros.rkt, warnings.rkt, global-constraints.rkt |
| merge-replace for definition cells | ✅ | `infra-cell.rkt` — last-write-wins for non-monotonic definitions |

### What we need

| Gap | Required for | Complexity |
|-----|-------------|-----------|
| `global-env-remove!` helper | Failure cleanup consolidation (Phase 2) | Low — mirror `global-env-add` for removal |
| Per-module network creation | Module loading cell path (Phases 3–4) | Medium — parameterize + teardown |
| Per-module cell registration | Module loading cell path (Phase 4) | Medium — variant of `register-global-env-cells!` |
| Propagator edge factory for definition deps | Incremental re-elab (Phase 5) | Medium — new propagator type in driver.rkt |
| Module env snapshot from cells | Module loading returns cell state (Phase 4) | Medium — cell-based `global-env-snapshot` variant |

---

## 3. Audit: `(current-global-env)` References in driver.rkt

### Category A: Writes via `global-env-add` / `global-env-add-type-only` (~23 sites)

Pattern:
```racket
(current-global-env
 (global-env-add (current-global-env) name zonked-type zonked-body))
```

These are **already routed through the two-layer dispatch**. `global-env-add` checks `current-global-env-prop-net-box`:
- When network present (elaboration): writes to Layer 1 cells, returns env UNCHANGED
- When no network (module loading): writes to Layer 2 parameter, returns updated hasheq

The `(current-global-env ...)` wrapper updates Layer 2, but during elaboration it's a no-op (the return value equals the input). During module loading it correctly updates the parameter.

**Conversion**: These sites need no behavioral change — `global-env-add` already does the right thing. The consolidation is cosmetic: remove the redundant `(current-global-env ...)` wrapper in elaboration context since it's a no-op.

### Category B: Failure cleanup via `hash-remove` (~12 sites)

Pattern:
```racket
(current-definition-cells-content (hash-remove (current-definition-cells-content) name))
(current-global-env (hash-remove (current-global-env) name))
```

These remove pre-registered definitions when elaboration, type-checking, or constraint resolution fails. They operate on both layers. There is no `global-env-remove!` helper — the removal is inline.

**Conversion**: Extract a `global-env-remove!` helper that removes from both layers (Layer 1 cells-content + Layer 2 parameter), mirroring `global-env-add`. This consolidates 12 × 2 = 24 inline removes into 12 single calls.

### Category C: Module loading setup (~5 sites)

Pattern:
```racket
(parameterize ([current-global-env (hasheq)] ...)
  ...)
;; and later:
(current-global-env (hash-set (current-global-env) k v))
```

Module loading creates a fresh Layer 2 env, processes module commands, then snapshots the result. `process-command` is called inside module loading, which already sets up a network (via `reset-meta-store!`), but `current-global-env-prop-net-box` is parameterized to `#f`, forcing the legacy path.

**Key insight**: Module loading already calls `process-command`, which already creates a per-command network. The two-context split exists because the outer `parameterize` sets `current-global-env-prop-net-box = #f` before entering the module's command loop. Removing this override is the core of Phase 3.

### Category D: Foreign function registration (~2 sites)

Pattern:
```racket
(current-global-env
 (global-env-add (current-global-env) prologos-name full-type val))
```

Same as Category A — `global-env-add` already dispatches. Foreign registration happens inside `process-command` scope, so it goes through cells when network is present.

---

## 4. Design: Phased Implementation

### Phase 0: Performance Baseline + Acceptance File

**Goal**: Establish baseline and create acceptance file.

- Run full test suite, record timing and test count
- Create `examples/2026-03-16-track5-acceptance.prologos` exercising:
  - Definitions that reference prior definitions (dependency edges)
  - Module imports with re-exported definitions
  - Definition failure cases (type error in body → cleanup visible)
  - All prelude features (regression net)
- Record acceptance file baseline (L3 via `process-file`)

### Phase 1: Consolidate Global-Env Writes

**Goal**: Replace env-threading pattern with direct calls. Behavioral no-op.

**Files**: `driver.rkt`

The 23 Category A sites use `(current-global-env (global-env-add (current-global-env) ...))`. Since `global-env-add` already handles the two-layer dispatch, the outer `(current-global-env ...)` is redundant during elaboration (returns unchanged env). During module loading, it correctly updates Layer 2.

**Change**: No behavioral change in Phase 1. This phase just *identifies* all sites and verifies the env-threading pattern is semantically equivalent to calling `global-env-add` alone. The actual removal of the redundant wrapper happens in Phase 4 (after per-module networks make it unnecessary in module loading too).

**Why not remove now**: In module loading context (no network), `global-env-add` returns the updated hasheq, and the caller must set `(current-global-env ...)` to make it visible. Removing the wrapper now would break module loading. Phase 3/4 eliminates this need by giving module loading a network.

**Deliverable**: Annotated audit of all 36+ sites with category labels. Add a comment block in driver.rkt documenting the categorization.

### Phase 2: Definition Removal → Cell-Aware Cleanup

**Goal**: Extract `global-env-remove!` helper; consolidate 12 failure cleanup sites.

**Files**: `global-env.rkt`, `driver.rkt`

New helper in `global-env.rkt`:

```racket
(define (global-env-remove! name)
  ;; Layer 1: remove from per-file definitions
  (current-definition-cells-content
   (hash-remove (current-definition-cells-content) name))
  ;; Layer 1: remove cell (write bot/empty sentinel)
  ;; (Don't actually delete the cell — write a removal marker or bot)
  (definition-cell-remove! name)
  ;; Layer 2: remove from prelude env
  (current-global-env
   (hash-remove (current-global-env) name)))
```

The cell removal is important: without it, a cell-primary read after a failed `def` would still see the pre-registered type. `definition-cell-remove!` writes a sentinel value (e.g., `#f` or a `(cons #f #f)`) to the cell, which `global-env-lookup-type`/`value` already handles (they check for `#f` and return `#f`).

Convert all 12 failure cleanup sites in driver.rkt from:
```racket
(current-definition-cells-content (hash-remove (current-definition-cells-content) name))
(current-global-env (hash-remove (current-global-env) name))
;; × 2 (short name + FQN)
```
to:
```racket
(global-env-remove! name)
(when fqn (global-env-remove! fqn))
```

This halves the failure-cleanup code and ensures cells and parameters stay synchronized.

### Phase 3: Per-Module Network Scaffolding

**Goal**: Enable module loading to run with a lightweight network.

**Files**: `driver.rkt`

Currently, `load-module` (driver.rkt ~1550) sets up a parameterize block with `current-prop-net-box = #f` and `current-global-env-prop-net-box = #f`. Inside this, `process-command` is called for each module form, which calls `reset-meta-store!` creating a fresh per-command network. But the `#f` overrides prevent the global-env from using it.

**Change**: Remove the `#f` overrides. Let `process-command`'s per-command network handle module loading definitions the same way it handles file-level definitions:

```racket
;; BEFORE (current):
[current-prop-net-box #f]
[current-global-env-prop-net-box #f]

;; AFTER (Track 5):
;; Remove these overrides. process-command will create networks
;; and set up global-env-prop-net-box via its own parameterize.
```

**Subtlety**: Module loading currently accumulates definitions in `(current-global-env)` across commands (the parameter persists between commands). With cell-primary writes, definitions go to Layer 1 (`current-definition-cells-content`), which also persists across commands within a file. So the accumulation behavior is preserved — but now through cells.

**Module env snapshot**: At the end of module loading, `global-env-snapshot` merges both layers. This already works — it reads `current-definition-cells-content` (Layer 1) and merges with `current-global-env` (Layer 2). The snapshot becomes the cached module env.

**Risk**: Medium. Module loading is exercised by every test that uses `(ns test-X)`. If the network introduction changes behavior, it will surface immediately across hundreds of tests.

**Belt-and-suspenders**: During Phase 3, keep the Layer 2 writes (dual-write continues). Module loading writes to both cells and parameters. The snapshot reads from both. This means we can verify cell writes match parameter writes before removing the parameter path in Track 6.

### Phase 4: Module Loading → Cell-Primary Definitions

**Goal**: With per-module networks active, verify module loading produces identical results through cells.

**Files**: `driver.rkt`, `global-env.rkt`, `namespace.rkt`

Phase 3 removed the `#f` overrides. Phase 4 validates that:

1. Module definitions written via `global-env-add` during loading now go to cells (Layer 1)
2. `global-env-snapshot` at the end of loading captures all definitions from both layers
3. The cached module env is identical to what the parameter-only path produced

**Validation**: Run full test suite. Compare module snapshots (if any regression, the delta shows which definitions differ).

**Consequence for Track 3 readers**: With module loading running through networks, the elaboration guard parameters (`current-macros-in-elaboration?`, `current-narrow-in-elaboration?`) become unnecessary — elaboration and module loading now both have networks. However, removing the guards is Track 6 scope (cleanup). Track 5 leaves them in place.

**Consequence for Category A writes**: With module loading also using networks, the `(current-global-env (global-env-add ...))` wrapper becomes truly redundant everywhere (not just during elaboration). Phase 4 can safely simplify these to just `(global-env-add ...)` calls. But to keep Phase 4 focused on validation, the simplification is deferred.

### Phase 5: Dependency Edge Wiring as Propagator Edges

**Goal**: Convert informational dependency recording into live propagator edges.

**Files**: `global-env.rkt`, `driver.rkt`, `elaborator-network.rkt`

Currently, `record-definition-dependency!` (global-env.rkt:138) records a dependency in a hasheq: `name → (seteq dep-name)`. This is informational — nothing happens when a dependency's definition changes.

**Change**: When elaboration references a prior definition via `global-env-lookup-*`, wire a propagator edge from the looked-up definition's cell to the current definition's elaboration context. If the source definition's cell value changes (e.g., in LSP), the propagator fires, marking the dependent definition as stale.

```racket
;; In global-env-lookup-type, after recording dependency:
(when (and elab-name (current-global-env-prop-net-box))
  (define dep-cell-id (hash-ref (current-definition-cell-ids) name #f))
  (define elab-cell-id (hash-ref (current-definition-cell-ids) elab-name #f))
  (when (and dep-cell-id elab-cell-id)
    ;; Wire: when dep-cell changes, mark elab-cell as stale
    (definition-dep-wire! dep-cell-id elab-cell-id name elab-name)))
```

The `definition-dep-wire!` function adds a propagator to the network that monitors the source cell. The propagator's action (on fire) is informational in batch mode: it records the staleness but doesn't trigger re-elaboration (batch processes files once, sequentially). In LSP mode (future), the propagator triggers selective re-elaboration.

**Phase 5 scope**: Wire the edges. Don't implement re-elaboration triggers (that's LSP scope). The edges are the infrastructure; the re-elaboration policy is separate.

**What the edges provide immediately**:
- Observable dependency graph via cell inspection (tooling, debugging)
- Foundation for incremental re-elaboration (LSP, future)
- Validation that dependency recording matches cell wiring (any missed edge = a bug)

### Phase 6: Performance Validation + PIR

- Run full suite, compare against Phase 0 baseline
- Run acceptance file at L3
- Per-module network creation adds ~1 network per module load. With prelude loading ~15 modules, this is 15 additional lightweight networks per command. Measure impact.
- Write PIR following methodology

---

## 5. Risk Analysis

### High risk: Module loading behavior change (Phase 3)

Module loading touches every test (via `ns` declarations). The change from "no network" to "network present" affects:
- `global-env-add` dispatch (writes to cells vs parameter)
- Registry cell readers (guards check for elaboration context)
- `reset-meta-store!` behavior (creates per-command networks)

**Mitigation**: Belt-and-suspenders — dual-write continues. Module loading writes to BOTH cells and parameters. If cell reads produce wrong results, parameter reads are still available as fallback. This is exactly the Track 3 pattern (proven safe).

### Medium risk: Definition removal correctness (Phase 2)

Failed definitions must be completely invisible after cleanup. Currently, `hash-remove` on both layers achieves this. Cell-aware removal must also clear the cell value, or a subsequent cell-primary read would see stale data.

**Mitigation**: Write sentinel value to cell on removal. `global-env-lookup-type`/`value` already handle `#f` entries (return `#f`). Verify with the existing error test suite (`test-error-messages.rkt`, `test-trait-resolution.rkt`, etc.).

### Low risk: Dependency edge wiring performance (Phase 5)

Adding propagators for definition edges increases network size per-command. But edges are only wired when a definition references a prior definition — not for every lookup (prelude lookups don't wire edges since prelude definitions don't have cells in the current command's network).

**Mitigation**: Profile. If propagator count per command increases significantly, consider lazy edge wiring (only wire for same-file definitions, not cross-module).

---

## 6. Learnings from Prior Tracks Applied Here

### From Track 3 PIR: Elaboration guard is the structural boundary

Track 3 discovered that any cell readable outside `process-command` needs an elaboration guard. Track 5 Phase 3 potentially eliminates this need by giving module loading a network — but we keep the guards in place (Track 6 cleanup) to avoid compounding risk.

### From Track 4 PIR: Dual-write coherence breaks under branching

Track 4 discovered that the dual-write pattern (CHAMP + cell) creates coherence requirements that TMS branching violates. Track 5 doesn't involve TMS branching for global-env (definitions aren't speculative), so this risk doesn't apply. However: if Track 5 creates per-module networks, and Track 4's TMS cells exist in those networks, we need to verify that TMS depth-0 fast path works correctly in module-loading context.

### From Track 3 PIR: Mechanical migrations benefit from first-one-is-the-hardest

Phase 1 (audit + categorization) will take the most time. Phases 2-4 apply the patterns mechanically. Budget accordingly.

### From Track 4 PIR: Belt-and-suspenders is standard practice

Keep both paths (cell + parameter) operational during Phases 1-4. Remove the parameter path in Track 6, not here.

### From master roadmap: DEFERRED.md triage at track start

Items to triage from DEFERRED.md:
- **Track 3 Phase 6** (dual-write parameter elimination) — now partially addressed by Track 5's per-module networks. Full elimination remains Track 6 scope.
- **Phase 3e** (reduction cache cells) — LSP-specific, remains deferred.
- **Phase 5a-5b** (driver simplification) — remains Track 6 scope.
- **`current-global-env` → `current-prelude-env` rename** — Phase 3d alias already exists. Bulk rename (266 files) still deferred. Not blocking Track 5.

---

## 7. Files Modified

| File | Changes |
|------|---------|
| `racket/prologos/global-env.rkt` | `global-env-remove!`, `definition-cell-remove!` helpers; dependency edge wiring in lookups |
| `racket/prologos/driver.rkt` | Phase 1 audit annotations; Phase 2 consolidated failure cleanup; Phase 3 remove `#f` overrides in module loading; Phase 4 validation |
| `racket/prologos/namespace.rkt` | Phase 3-4: module loading network awareness (if needed) |
| `racket/prologos/elaborator-network.rkt` | Phase 5: definition dependency propagator factory |

---

## 8. Verification

1. **Per-phase**: `racket tools/run-affected-tests.rkt --all 2>&1 | tail -30` — 0 failures after each phase
2. **Acceptance file**: Run via `process-file` at L3 after each phase
3. **Module loading**: Every test using `(ns test-X)` exercises module loading — 200+ test files provide integration coverage
4. **Failure cleanup**: `test-error-messages.rkt`, `test-trait-resolution.rkt`, `test-trait-impl-*.rkt` exercise definition failure → error paths
5. **Dependency edges**: `definition-dependencies-snapshot` already provides inspection — verify edge count matches cell wiring count
6. **Performance**: Compare total wall time against 187.1s baseline; investigate if >25% regression

---

## 9. Open Questions

### Q1: Should per-module networks persist across commands within a module?

Currently, `process-command` creates a fresh network per command (via `reset-meta-store!`). Module loading calls `process-command` for each form. This means each module form gets a fresh network. Definition cells are recreated each command via `register-global-env-cells!`, which reads `current-definition-cells-content` (persistent) and creates cells for all known definitions.

This is correct but potentially wasteful for large modules (e.g., prelude with ~100 definitions): each command recreates cells for all prior definitions. An alternative is a single persistent network for the entire module load. But this changes `reset-meta-store!` semantics.

**Recommendation**: Keep per-command networks (simpler, proven pattern). The per-command network recreation is cheap — `register-global-env-cells!` is O(n) in definition count but the constant is tiny (one `new-cell-fn` call per definition). Profile in Phase 4; optimize only if measurable.

### Q2: Should dependency edges be TMS-aware?

If a definition was created during speculation and then retracted, should its dependency edges also retract? In batch mode this doesn't matter (speculation doesn't create new definitions). In LSP mode it might matter (hypothetical definitions during completion).

**Recommendation**: Not TMS-aware in Track 5. Dependency edges are wired from the cell-IDs of committed definitions only. Track 6/9 can add TMS awareness if needed.

### Q3: Scope of "remaining (current-global-env) reads"

The master roadmap says "36 references in driver.rkt." The actual count is 36+ but they're overwhelmingly *writes* (Category A), not reads. The reads already go through `global-env-lookup-*`. The Track 5 scope should be framed as "consolidate global-env interaction patterns" rather than "convert reads to cell-primary" — the reads are already cell-primary (Track 3a-d).

**Recommendation**: Reframe Track 5 scope in the master roadmap after this design is approved.
