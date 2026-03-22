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
| 1 | Registry cells (P0) | ⬜ | impl, trait, param-impl |
| 2 | Value-threaded reads (P1a) | ⬜ | zonk, meta-solved?, ground-expr? |
| 3 | Pure α/γ bridges (P1b) | ⬜ | C1-C3 rewrite |
| 4 | Callback retirement (P2) | ⬜ | 6 symptomatic callbacks |
| 5 | Action descriptors (P3) | ⬜ | solve-meta! returns data |
| 6 | Speculation value-threading (P4) | ⬜ | commit/retract without box |
| 7 | Verification + benchmarks | ⬜ | |

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

### 3.3 The Key Insight: Read Functions Accept Network

The technical linchpin is **Finding 2**: read functions (`zonk`, `meta-solved?`, `ground-expr?`) are coupled to the box via `current-prop-net-box`. This prevents pure fire functions.

The fix: each read function gains an optional network argument. When provided, reads from the argument. When absent, falls back to box (backward compat during migration).

```racket
;; Before:
(define (meta-solved? id)
  (define mi (unwrap-meta-info id))  ;; reads from box
  (and mi (meta-info-solution mi)))

;; After:
(define (meta-solved? id [net #f])
  (define mi (if net
                 (meta-info-from-net net id)  ;; reads from network value
                 (unwrap-meta-info id)))      ;; fallback: reads from box
  (and mi (meta-info-solution mi)))
```

Once all callers in bridge fire functions pass the network, the fallback path becomes dead code for bridges. The bridge fire function is now pure:

```racket
(lambda (net dep-cids result-cid)
  (define type-args (map (lambda (e) (zonk-from-net net e)) ...))
  (when (andmap (lambda (e) (ground-expr? e net)) type-args)
    (define impl-reg (net-cell-read net impl-registry-cid))
    (define result (lookup-impl-from impl-reg ...))
    (net-cell-write net result-cid result)))
```

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

### Phase 2: Value-Threaded Reads (P1a)

**What**: Add optional `net` parameter to core read functions: `zonk`, `zonk-at-depth`, `meta-solved?`, `meta-solution`, `ground-expr?`, `normalize-for-resolution`.

**Files**: `zonk.rkt`, `metavar-store.rkt`, `reduction.rkt` (for normalize).

**Strategy**: Optional parameter with `#f` default. When `#f`, uses existing box path (backward compat). When provided, reads from network value. This enables incremental migration — callers switch one at a time.

**The `zonk` challenge**: `zonk` is recursive and calls `meta-solution`, which reads from the box. The network argument must be threaded through the recursion. This is the bulk of Phase 2 work.

**Test**: Write a test that calls `zonk` with an explicit network argument (no box in scope) and verifies correct results.

**Principles check**:
- Data Orientation: ✓ reads decoupled from box
- Decomplection: ✓ computation separated from access mechanism
- Completeness: ✓ foundational — enables all subsequent phases

### Phase 3: Pure α/γ Bridges (P1b)

**What**: Rewrite C1-C3 bridge fire functions to use `net-add-cross-domain-propagator` with pure α/γ functions. No `enet-box`. No `set-box!`.

**Depends on**: Phase 1 (registry cells) + Phase 2 (value-threaded reads).

**Files**: `resolution.rkt` (new bridge factories), `metavar-store.rkt` (bridge installation).

**α function** (dependency cells → resolution result):
1. Read dependency cells (type-arg metas) from network
2. `zonk` with network argument (Phase 2)
3. `ground-expr?` with network argument (Phase 2)
4. Read impl-registry cell (Phase 1)
5. Lookup matching impl → return resolved dict expression

**γ function** (resolution result → dict-meta cell):
1. Read resolution result cell
2. If resolved: write dict expression to dict-meta cell

**Test**: The existing `test-trait-resolution-bridge.rkt` tests should pass with the rewritten bridges. Add tests that verify no `enet-box` is in scope during bridge firing.

**Principles check**:
- Propagator-First: ✓ bridges are pure network operations
- Correct-by-Construction: ✓ no box write-back discipline needed
- Completeness: ✓ Part C's promise finally delivered

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

### Phase 5: Action Descriptors (P3)

**What**: `solve-meta!` returns action descriptors instead of executing side effects. The quiescence loop interprets descriptors.

**This is the most architecturally significant phase.** It transforms the re-entrant `solve-meta! → resolve → solve-meta! → ...` chain into a data-oriented worklist.

**Descriptor types**:
```racket
(struct action-solve-meta (meta-id value) #:transparent)
(struct action-resolve-trait (dict-meta-id tc-info) #:transparent)
(struct action-resolve-hasmethod (meta-id hm-info) #:transparent)
(struct action-retry-constraint (constraint) #:transparent)
```

**Interpretation loop**: After quiescence, collect descriptors from action cells. Apply each. If new descriptors generated, iterate. Fixpoint when no new descriptors.

**Benefits**:
- Inspectable: descriptors can be logged, counted, visualized
- Testable: resolution logic unit-tested with mock descriptors
- No re-entrancy: interpretation loop controls ordering
- Totality: fuel limits on interpretation loop (not per-call)

**Principles check**:
- Data Orientation: ✓ effects as descriptions at boundaries
- First-Class by Default: ✓ actions are data
- Correct-by-Construction: ✓ re-entrancy impossible

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

### High Risk: Phase 2 (zonk threading)

`zonk` is one of the most-called functions in the codebase. Adding a network argument that threads through recursion touches many call sites. Strategy: optional parameter with fallback ensures backward compat — no big-bang migration.

### Medium Risk: Phase 5 (action descriptors)

Replacing `solve-meta!` with descriptors is a significant architectural change. The re-entrant chain (`solve-meta! → resolve → solve-meta!`) is deeply embedded. The descriptor approach requires the interpretation loop to handle the same re-entrancy patterns that `solve-meta!` handles implicitly.

**Mitigation**: The "pure" variants (`solve-meta-core-pure`) already exist from Track 7. The descriptor approach builds on these — instead of `solve-meta-core-pure` writing to an enet, it returns a descriptor. The interpretation loop applies descriptors sequentially.

### Low Risk: Phases 1, 3, 4, 6, 7

Registry cells are straightforward (accumulative merge, existing cell infrastructure). α/γ bridges are well-understood (session-type-bridge template). Callback retirement falls out of earlier phases. Speculation threading is mechanical once the box is no longer needed.

---

## 7. Dependency Graph

```
Phase 0 ──→ Phase 1 (registry cells)
              ↓
             Phase 2 (value-threaded reads)
              ↓
             Phase 3 (pure α/γ bridges) ←── requires P1 + P2
              ↓
             Phase 4 (callback retirement) ←── requires P3
              ↓
             Phase 5 (action descriptors) ←── can run parallel to P4
              ↓
             Phase 6 (speculation threading) ←── requires P5
              ↓
             Phase 7 (verification)
```

Phase 5 is the most independent — it can be designed and prototyped in parallel with Phases 3-4, since it changes a different part of the pipeline (the `solve-meta!` chain vs. the bridge fire functions).

---

## 8. Success Criteria

1. Zero `enet-box` access in bridge fire functions (C1-C3 rewritten as pure α/γ)
2. Registry cells exist and bridge propagators watch them
3. `zonk`, `meta-solved?`, `ground-expr?` callable with explicit network argument (no box required)
4. `solve-meta!` returns action descriptors (no re-entrant side effects)
5. 6 symptomatic callbacks eliminated
6. All 7343+ tests pass
7. Suite time within 10% of baseline (228.2s)
8. Acceptance file passes at Level 3
