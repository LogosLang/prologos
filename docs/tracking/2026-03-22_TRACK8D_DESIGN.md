# PM Track 8D: Principled Resolution Infrastructure — Stage 3 Design

**Date**: 2026-03-22
**Series**: Propagator Migration
**Depends on**: Track 8 (Parts A-C)
**Blocks**: CIU Track 3 (trait-dispatched access)
**Source**: Track 8 PIR §12 Principles Audit (6 findings, 1 root cause)

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Acceptance file baseline | ⬜ | |
| 1 | Registry cells | ⬜ | impl, trait, param-impl as cells |
| 3 | Pure α/γ bridges | ⬜ | C1-C3 rewrite — read cells directly, no zonk |
| 4 | Callback retirement | ⬜ | 6 symptomatic callbacks |
| 7 | Verification + benchmarks | ⬜ | |
| — | *Deferred: Phase 2 (zonk-from-net)* | — | Incremental improvement, not foundation |
| — | *Deferred: Phase 5 (action descriptors)* | — | Cold-path cleanup |
| — | *Deferred: Phase 6 (speculation threading)* | — | Depends on Phase 5 |

---

## 1. Problem Statement

Track 8 Parts A-C delivered assumption-tagged state, worldview-aware reads, callback elimination, HKT parsing/resolution, and bridge propagators for S0 resolution. But a post-completion principles audit (§12) found that the elaboration network is accessed imperatively via a mutable box (`current-prop-net-box`), creating 6 downstream violations of Propagator-First, Data Orientation, Correct-by-Construction, Completeness, and Composition.

The central symptom: Part C was titled "The Phase Boundary Dissolves" but the boundary was relocated from S2 timing to S0 mutable-box access. Bridge propagators fire in S0 (correct timing) but side-effect through `enet-box` (incorrect mechanism).

**Root cause**: `current-prop-net-box` is the gravitational center of all elaboration state access — 197 `set-box!/unbox` calls across 12 files. Every state operation orbits this mutable box.

---

## 2. Principles Alignment (Challenge, Not Catalogue)

Each design choice in this document must answer: **does this move us toward or away from each principle?**

### Group A: Infrastructure Principles

| Principle | Current Violation | Track 8D Resolution |
|-----------|------------------|---------------------|
| **Propagator-First** | Registries are parameters, not cells. State is in a box, not on the network. | Registries become cells. Read functions accept network. |
| **Data Orientation** | `solve-meta!` is re-entrant side effects. `with-enet-reads` creates boxes. | Action descriptors replace imperative chains. Box-free reads. |
| **Correct-by-Construction** | Box write-back requires discipline. Missing write-back loses state silently. | Value threading makes lost state structurally impossible. |
| **First-Class by Default** | Resolution actions are imperative calls, not inspectable data. | Action descriptors are first-class values — loggable, testable, replayable. |
| **Decomplection** | Read functions braid pure computation with box access. | Reads decoupled from access mechanism. |

### Group B: Design Quality Principles

| Principle | How 8D Serves It |
|-----------|-----------------|
| **Completeness** | Fix the incomplete foundation before building on it. |
| **Composition** | Registry cells compose with bridge propagators: registration triggers re-resolution via propagation. |
| **Progressive Disclosure** | No user-facing change. Internal infrastructure only. |
| **Ergonomics** | CIU Track 3 builds on correct foundation — no workarounds needed. |
| **Most General Interface** | α/γ bridges are the most general pattern — any domain pair, any Galois connection. |

### Red-Flag Phrases Check

- "Temporary bridge" → **Not applicable** — we are building the permanent architecture.
- "Belt-and-suspenders" → Readiness propagators alongside bridges are LEGITIMATE dual mechanisms (both correct). The enet-box pattern alongside pure functions was ILLEGITIMATE (§6.6 in PIR).
- "Keeping the old path as fallback" → Module-load-time parameter writes (B2e) remain as genuine fallback for contexts without networks. Acceptable.

---

## 3. Architecture

### 3.1 Current State

```
┌─────────────────────────────────────────────┐
│ current-prop-net-box (mutable box)          │
│ ┌─────────────────────────────────────────┐ │
│ │ elab-network                            │ │
│ │ ├── prop-net: prop-network (cells, etc) │ │
│ │ ├── meta-info: CHAMP (assumption-tagged)│ │
│ │ ├── id-map: CHAMP (assumption-tagged)   │ │
│ │ └── ...9 more fields                    │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
         ↑ unbox / set-box! (197 sites)
         │
    metavar-store.rkt, resolution.rkt,
    elab-speculation-bridge.rkt, driver.rkt, ...
```

Bridge fire functions:
```
(lambda (pnet ...)
  (define net-box (current-prop-net-box))  ;; SIDE EFFECT: read box
  (define enet (elab-network-rewrap (unbox net-box) pnet))
  (define enet* (resolve-...-pure enet ...))  ;; SIDE EFFECT: with-enet-reads
  (set-box! net-box enet*)                    ;; SIDE EFFECT: write box
  (elab-network-prop-net enet*))
```

### 3.2 Target State

```
┌──────────────────────────────────────────────┐
│ prop-network (value, threaded through)       │
│ ├── cells CHAMP                              │
│ │   ├── meta cells (type values, TMS)        │
│ │   ├── infra cells (constraints, registries)│
│ │   ├── impl-registry-cell  ← NEW           │
│ │   ├── trait-registry-cell ← NEW           │
│ │   └── param-impl-registry-cell ← NEW     │
│ ├── propagators list                         │
│ │   ├── type propagators                     │
│ │   ├── bridge propagators (pure α/γ)        │
│ │   └── registry-watch propagators ← NEW    │
│ └── ...                                      │
└──────────────────────────────────────────────┘
```

Bridge fire functions (target):
```
(lambda (net dep-cell-id result-cell-id)
  (define dep-val (net-cell-read net dep-cell-id))
  (define result (alpha-resolve dep-val))  ;; PURE: value → value
  (net-cell-write net result-cell-id result))
```

### 3.3 The Key Insight: Metas Already Have Cells — `zonk` Should Read Them Directly

The initial design proposed adding optional `net` parameters to `zonk`/`meta-solved?` so they read from a network value instead of the box. But a deeper analysis reveals a better path:

**Each meta already has its own cell on the prop-network.** That's how type inference works — `solve-meta!` writes the solution to the meta's cell via `net-cell-write`. The meta-info CHAMP is the *registration record* (cell ID, type, constraints). The *solution* is the cell value.

This means `zonk` in a bridge fire function context doesn't need meta-info at all for solution lookup. It needs:
1. **id-map**: meta-id → cell-id (to find the cell)
2. **net-cell-read**: cell-id → value (to read the solution)

Both are already available on the `prop-network` that the fire function receives. The id-map is on `elab-network` (struct field), but it could be a cell. Or — simpler — the bridge propagator is installed with the cell IDs of its dependencies at registration time. It doesn't need to look up cell IDs dynamically because it already knows them.

**This eliminates the `zonk` threading problem entirely.** The bridge α function doesn't call `zonk`. It reads dependency cells directly:

```racket
;; Bridge α function for trait resolution:
;; dep-cells are the type-arg meta cells (known at registration time)
;; impl-reg-cell is the impl registry cell (Phase 1)
;; result-cell is the dict-meta cell
(lambda (net)
  (define type-arg-vals (map (lambda (cid) (net-cell-read net cid)) dep-cell-ids))
  ;; Check: all ground? (no expr-meta in values)
  (when (andmap ground-expr-value? type-arg-vals)
    (define impl-reg (net-cell-read net impl-registry-cell-id))
    (define result (lookup-impl-from-hash impl-reg trait-name type-arg-vals))
    (if result
        (net-cell-write net dict-meta-cell-id result)
        net)))
```

No `zonk`. No `meta-solved?`. No box. No `with-enet-reads`. The fire function reads cells and writes cells — pure `net → net`.

**What `zonk` threading is still needed for**: The S2 fallback path and direct elaboration calls still use `zonk` through the box. Phase 2 adds a `zonk-from-net` variant for those callers that want to migrate incrementally. But bridges bypass `zonk` entirely.

### 3.4 `ground-expr-value?` vs `ground-expr?`

The current `ground-expr?` checks whether an expression contains `expr-meta` nodes. In a bridge context, we're reading cell values — if a meta is solved, the cell value IS the solution (not an `expr-meta`). If unsolved, the cell value is `'nothing` or the bottom lattice element.

So the bridge doesn't need `ground-expr?` — it checks whether cell values are solutions (not bottom). This is a cell-level check, not an expression-level check. The bridge naturally avoids firing until all dependencies have solutions, because `net-cell-read` returns bottom for unsolved cells, and the α function checks for non-bottom before proceeding.

Even better: the bridge propagator is registered with dependency cell IDs. The propagator network only fires it when a dependency cell changes. So the bridge won't even be invoked until at least one dependency has a new value.

### 3.5 Phase 5 Reframing: Hot Path vs Cold Path

The original Phase 5 proposed transforming `solve-meta!` into action descriptors. But with bridges reading cells directly (§3.3), the bridge path IS the hot path and it's already data-oriented — pure `net → net`, no `solve-meta!` at all.

`solve-meta!` remains on the cold path:
- S2 fallback (safety net, rarely fires now)
- Direct elaboration calls (type checker solving ground metas)
- Module-load-time registration (no network)

Transforming the cold path to descriptors is valuable (inspectability, testability, no re-entrancy) but not load-bearing for the Completeness correction. **Phase 5 is reclassified from P3 to deferred** — it's cleanup, not foundation. The foundation is Phases 1-3.

### 3.6 Revised Priority Stack

| Priority | Phase | Architectural Impact |
|----------|-------|---------------------|
| **Foundation** | Phase 1 (registry cells) | Registries on network; bridges can watch |
| **Foundation** | Phase 3 (pure α/γ bridges) | Correctness of resolution infrastructure |
| **Cleanup** | Phase 4 (callback retirement) | Falls out of Phase 3 |
| **Improvement** | Phase 2 (zonk-from-net) | Incremental migration for non-bridge callers |
| **Deferred** | Phase 5 (action descriptors) | Cold-path improvement |
| **Deferred** | Phase 6 (speculation threading) | Depends on Phase 5 |

---

## 4. Phased Implementation

### Phase 0: Acceptance File Baseline

Extend the existing Track 8 acceptance file or create `examples/2026-03-22-track8d-acceptance.prologos`. Run via `process-file` to establish baseline.

### Phase 1: Registry Cells (P0)

**What**: Create cells for `impl-registry`, `trait-registry`, and `param-impl-registry` on the elaboration network.

**Files**: `elab-network-types.rkt` (new cell IDs), `macros.rkt` (cell writes alongside parameter writes — temporarily dual-write), `infra-cell.rkt` (merge functions for registry cells).

**Merge semantics**: Registry cells are accumulative (new entries merge via `hash-union`). Registration is monotone — impls are never removed.

**Key decision**: The cell holds a hash (same structure as the current parameter). Merge is `hash-union` with conflict detection (duplicate impl key → contradiction).

**Test**: Verify that after elaborating `impl Eq Int`, the impl-registry cell contains the entry. Verify that bridge propagators can read from the cell.

**Principles check**:
- Propagator-First: ✓ registries move from parameters to cells
- Composition: ✓ bridge propagators can now watch registry cells
- Completeness: ✓ registration-triggered re-resolution becomes possible

### Phase 2: Value-Threaded Reads (P1a) — RECLASSIFIED: Improvement, not foundation

**Revised scope**: Per §3.3, bridge fire functions don't need `zonk` — they read cells directly. Phase 2 is now an *incremental improvement* for non-bridge callers (S2 fallback, direct elaboration), not a foundation phase.

**What**: Add `zonk-from-net` as a separate function (not optional parameter — cleaner API) that reads meta solutions from cell values via `net-cell-read` instead of from the box.

**Files**: `zonk.rkt` (new `zonk-from-net`), `metavar-store.rkt` (new `meta-solved-from-net?`).

**When**: After Phase 3 proves bridges work without `zonk`. Can be deferred if S2 fallback path is acceptable as-is.

**Test**: Call `zonk-from-net` with a prop-network containing solved metas. Verify correct results with no box in scope.

**Principles check**:
- Data Orientation: ✓ reads decoupled from box for callers that opt in
- Decomplection: ✓ clean separation between cell-reading and box-reading paths

### Phase 3: Pure α/γ Bridges (P1b) — FOUNDATION

**What**: Rewrite C1-C3 bridge fire functions as pure `net → net` propagators that read dependency cells directly (no `zonk`, no `meta-solved?`, no box). Uses `net-add-cross-domain-propagator` pattern or equivalent single-propagator with multiple input cells.

**Depends on**: Phase 1 (registry cells).

**Does NOT depend on**: Phase 2 (zonk threading) — per §3.3, bridges read cells directly.

**Files**: `resolution.rkt` (new bridge factories), `metavar-store.rkt` (bridge installation), possibly `constraint-propagators.rkt` (if registration logic moves).

**Bridge fire function pattern** (§3.3):
```racket
(lambda (net)
  ;; Read dependency cells (type-arg metas — cell IDs known at registration)
  (define type-arg-vals (map (lambda (cid) (net-cell-read net cid)) dep-cell-ids))
  ;; All solved? (cell values are solutions, not expr-meta)
  (when (andmap resolved-cell-value? type-arg-vals)
    ;; Read impl registry cell (Phase 1)
    (define impl-reg (net-cell-read net impl-registry-cell-id))
    ;; Pure hash lookup — no parameter, no box
    (define result (lookup-impl-from-hash impl-reg trait-name type-arg-vals))
    (if result
        (net-cell-write net dict-meta-cell-id result)
        net)))
```

**Key design decisions**:
1. **Cell IDs captured at registration time**: When a trait constraint is registered, we know the dependency meta cell IDs and the dict-meta cell ID. These are closed over in the bridge propagator. No dynamic id-map lookup needed.
2. **`resolved-cell-value?` replaces `ground-expr?`**: Cell values are either solutions (ground expressions) or bottom (unsolved). No need for expression-level groundness check — just check for non-bottom.
3. **`lookup-impl-from-hash` is pure**: Takes the registry hash (read from cell), trait name, type arg values. Returns dict expression or `#f`. No parameter access, no box.
4. **No `zonk`**: Cell values ARE the zonked solutions. The propagator network maintains zonked values in cells — `solve-meta!` writes the solution directly. Recursive zonking (meta → solution → meta → solution) is handled by the propagator network's cascading write semantics.

**Cascading resolution**: When bridge A resolves dict-meta-1, that cell write may wake bridge B whose dependency includes dict-meta-1. Bridge B fires, reads the now-solved cell, resolves dict-meta-2. This is transitive resolution via propagation — no `solve-meta!` chain, no re-entrancy.

**Hasmethod bridge**: Same pattern but with an additional step — first resolve which trait contains the method (read from trait-registry cell), then resolve the dict via impl-registry cell, then project the method. Three cell reads, one cell write.

**Constraint retry bridge**: Read constraint cell, read dependency cells, if all ground → re-attempt unification as pure `net → net` (structural unify already works on `prop-network`).

**Test**:
1. Existing `test-trait-resolution-bridge.rkt` tests pass
2. New test: bridge fires with no `current-prop-net-box` in scope (parameter is `#f`) — proves no box dependency
3. Cascading resolution: constraint A depends on meta that depends on constraint B. B resolves first → A resolves via propagation cascade.

**Principles check**:
- Propagator-First: ✓ bridges are pure network operations — read cells, write cells
- Data Orientation: ✓ fire function is pure `net → net`
- Correct-by-Construction: ✓ no box write-back, no discipline required
- Composition: ✓ bridges compose with registry cells — new impl triggers re-resolution
- Completeness: ✓ the phase boundary genuinely dissolves

### Phase 4: Callback Retirement (P2)

**What**: Remove 6 symptomatic callbacks identified in §12 Finding 5.

**Depends on**: Phase 3 (bridges no longer need box access).

**Callbacks to remove**:
1. `current-prop-run-quiescence` → direct function call (if cycle allows) or keep as legitimate injection
2. `current-prop-unwrap-net` → eliminated if bridges don't need enet wrapping
3. `current-prop-rewrap-net` → same
4. `current-trait-resolution-bridge-fn` → bridges installed directly
5. `current-hasmethod-resolution-bridge-fn` → same
6. `current-constraint-retry-bridge-fn` → same

**Note**: `run-quiescence`, `unwrap-net`, and `rewrap-net` may need to remain if `solve-meta!` still uses the box path for non-bridge callers. Evaluate after Phase 3.

### Phase 5: Action Descriptors (P3) — DEFERRED

**Revised assessment**: Per §3.5, bridges (Phase 3) handle the hot path as pure α/γ — no `solve-meta!` involved. Phase 5 transforms the *cold path* (S2 fallback, direct elaboration calls) into descriptors. Valuable for inspectability and testability, but not load-bearing for the Completeness correction.

**Deferred until**: After CIU Track 3, when the cold path's behavior under new trait dispatch reveals whether descriptor transformation is needed for correctness or only for observability.

### Phase 6: Speculation Value-Threading (P4)

**What**: Speculation bridge (`with-speculative-rollback`) receives and returns the network value instead of extracting from box.

**Depends on**: Phase 5 (the main consumer of box access during speculation is `solve-meta!`).

**Approach**: `with-speculative-rollback` takes a `net` argument, passes it to the thunk, receives updated `net*` on success. Commit/retract operate on the returned value.

**Note**: This is the final phase before full box retirement. After Phase 6, the box is only needed for: (a) non-bridge callers that haven't migrated, (b) module-load-time context.

### Phase 7: Verification + Benchmarks

- Full test suite
- A/B benchmarks (bench-ab.rkt) comparing before/after
- Per-command verbose output on acceptance file
- Verify bridge convergence properties preserved

---

## 5. WS Impact

None — Track 8D is purely infrastructure. No user-facing syntax changes.

---

## 6. Risk Analysis

### Medium Risk: Phase 3 (pure α/γ bridges)

The §3.3 insight eliminates `zonk` from bridges, dramatically reducing risk. The remaining risk is in the registration-time capture of dependency cell IDs and the `lookup-impl-from-hash` pure function. Both are well-constrained.

**Specific risk**: Cell values for solved metas may not always be fully zonked — if meta A's solution contains `expr-meta B`, and B is later solved, A's cell value may be stale. The propagator network handles this via cascading writes, but bridge fire functions reading A's cell see the pre-cascade value. **Mitigation**: The existing readiness propagator pattern checks that ALL dependency cells are ground before firing. Bridges should do the same — only fire when all dependency cell values contain no `expr-meta` nodes.

### Low Risk: Phase 1 (registry cells)

Accumulative merge, existing cell infrastructure. The only subtlety is merge conflict detection (duplicate impl keys).

### Low Risk: Phase 4 (callback retirement)

Mechanical — falls out of Phase 3.

### Deferred Risk: Phase 2 (zonk-from-net), Phase 5 (descriptors), Phase 6 (speculation)

These phases no longer gate the Completeness correction. Risk is bounded by deferral.

---

## 7. Dependency Graph (Revised)

```
Phase 0 ──→ Phase 1 (registry cells)
              ↓
             Phase 3 (pure α/γ bridges) ←── requires P1 only
              ↓
             Phase 4 (callback retirement) ←── falls out of P3
              ↓
             Phase 7 (verification)

             [Deferred]
             Phase 2 (zonk-from-net) ←── independent, incremental improvement
             Phase 5 (action descriptors) ←── cold-path cleanup
             Phase 6 (speculation threading) ←── requires P5
```

**Core path**: 0 → 1 → 3 → 4 → 7. Four foundation phases. The §3.3 insight (bridges read cells directly, no zonk) removed Phase 2 from the critical path.

---

## 8. Success Criteria

### Foundation (must deliver)
1. Zero `enet-box` access in bridge fire functions — C1-C3 rewritten as pure `net → net`
2. Impl/trait/param-impl registry cells exist on the propagator network
3. Bridge propagators read registry and dependency cells directly — no `zonk`, no `meta-solved?`, no box
4. Cascading resolution works: constraint A → meta → constraint B chain resolves via propagation
5. Bridge fire functions callable with `current-prop-net-box` = `#f` (proves no box dependency)
6. All 7343+ tests pass
7. Suite time within 10% of baseline (228.2s)
8. Acceptance file passes at Level 3

### Cleanup (should deliver)
9. 6 symptomatic callbacks reduced (3 bridge-fn callbacks eliminated; unwrap/rewrap/quiescence evaluated)

### Deferred (not in this track)
10. `zonk-from-net` for non-bridge callers (Phase 2)
11. Action descriptors for `solve-meta!` cold path (Phase 5)
12. Speculation value-threading (Phase 6)
