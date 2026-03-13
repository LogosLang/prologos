# Propagator Network Visualization — Design Document

**Date**: 2026-03-12
**Status**: Stage 2-3 (Gap Analysis + Phased Design)
**Builds on**: Propagator-First Migration (`2026-03-11_1800_PROPAGATOR_FIRST_MIGRATION.md`), LSP Tiers 1-5

## Executive Summary

Make the propagator network — the invisible infrastructure underlying type inference,
trait resolution, multiplicity checking, and (eventually) formal verification — visible
and interactive in VS Code. A "Propagator View" panel renders the cell/propagator
topology as a live graph, with step-through replay of propagation, contradiction
diagnosis, and source-location linking.

The visualization is both a practical debugging tool ("why did this type resolve to X?")
and a conceptual revelation ("type checking, trait resolution, and verification are
literally the same network"). The tool IS the documentation of the paradigm.

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| **0** | **First-class trace data** | | |
| 0a | Core data types (cell-diff, bsp-round, prop-trace) | ✅ | `817a958` |
| 0b | ATMS event hierarchy (assume/retract/nogood) | ✅ | `817a958` |
| 0c | Unit tests (11 cases) | ✅ | `817a958` |
| **1** | **BSP-round trace capture** | | |
| 1a | Observer parameter + accumulator | ✅ | `35c1a03` |
| 1b | BSP loop integration (cell-diff correlation) | ✅ | `35c1a03` |
| 1c | Integration tests (5 cases) | ✅ | `35c1a03` |
| **2** | **Network serialization** | | |
| 2a | Lattice value display | ✅ | `779c6e9` |
| 2b | Struct→JSON (cell-diff, atms-event, bsp-round) | ✅ | `779c6e9` |
| 2c | Network topology extraction | ✅ | `779c6e9` |
| 2d | trace→json-string round-trip | ✅ | `779c6e9` |
| 2e | Unit + integration tests (19 cases) | ✅ | `779c6e9` |
| **3** | **LSP endpoint** | | |
| 3a | `$/prologos/propagatorSnapshot` handler | ✅ | `2998a4c` |
| 3b | Trace capture in elaborate-and-publish-diagnostics! | ✅ | `2998a4c` |
| 3c | Per-URI trace storage in lsp-state | ✅ | `2998a4c` |
| **4** | **VS Code graph panel** | | |
| 4a | WebviewPanel skeleton + tabular data rendering | ✅ | `2fe92c9` |
| 4b | Canvas graph rendering (layout + d3-zoom + tooltips) | ✅ | `a2286fb`, `3049305` |
| 4b' | Sequential scheduler observer + round numbering | ✅ | `af43e4e`, `1232fda` |
| 4c | Subsystem-categorized cells (color-coded by origin) | ✅ | `04cb546` — type-inference/infrastructure/multiplicity |
| 4c' | Source-location linking (cell → editor position) | ⬜ | |
| 4d | Auto-refresh on file save | ⬜ | |
| **5** | **BSP-round replay** | | |
| 5a | Timeline slider UI | ⬜ | |
| 5b | Round step-through (prev/next) | ⬜ | |
| 5c | Animated cell-diff highlighting | ⬜ | |
| 5d | Cell value history popup | ⬜ | |
| **6** | **Polish and integration** | | |
| 6a | Performance tuning (large networks) | ⬜ | |
| 6b | SVG/PNG export | ⬜ | |
| 6c | Contradiction diagnosis view (ATMS nogoods) | ⬜ | |
| 6d | Documentation + user guide | ⬜ | |

## Subsystem Cell Categorization (Phase 4c)

All subsystems share ONE `prop-network` inside the `elab-network`. Cells are categorized
by their origin:

| Subsystem | Color | Cell Source | Has cell-info? |
|-----------|-------|-------------|----------------|
| **Type inference** | Green | `elab-fresh-meta` (meta cells) | ✅ ctx, type, source |
| **Infrastructure** | Gray | `elab-new-infra-cell` (registries, stores) | ❌ |
| **Multiplicity** | Purple | `elab-fresh-mult-cell` (QTT mult cells) | ✅ type=#f |
| **Unknown** | Blue | Fallback | — |

### Propagator Edge Sources

Real `net-add-propagator` edges exist in these subsystems:

| Subsystem | File | Edge Count | Active in Elaboration? |
|-----------|------|------------|----------------------|
| Unification | `elaborator-network.rkt` | Bidirectional per constraint | ✅ via `metavar-store.rkt:564` |
| Structural decomp | `elaborator-network.rkt` | ~30 decomposition variants | ✅ when types are concrete |
| Type↔Mult bridge | `elaborator-network.rkt` | Per Pi type | ✅ via `elab-add-type-mult-bridge` |
| Session types | `session-propagators.rkt` | 9 variants | ✅ for session-typed code |
| Effect ordering | `effect-ordering.rkt` | 1 | ✅ for effectful code |
| Effect bridge | `effect-bridge.rkt` | 1 | ✅ session→effect bridge |
| Capability | `capability-inference.rkt` | 1 | ✅ for cap-annotated code |
| Cap↔Type bridge | `cap-type-bridge.rkt` | 1 | ✅ |
| Constraint P1-P4 | `constraint-propagators.rkt` | 4 variants | ❌ tests only (deferred) |

### Current Edge Production (Investigated 2026-03-12, commit `786b6e0`)

**Finding: the current production pipeline produces 0 propagator edges for all tested expressions.**

Root causes:

1. **Type inference constraints are always one-sided.** The elaborator resolves constraints
   eagerly: when posting `?A = Int`, `extract-shallow-meta-ids` finds `?A` on the LHS but
   nothing on the RHS. The cross product in `metavar-store.rkt:556-559` is empty, so
   `elab-add-unify-constraint` is never called. Meta-meta constraints (metas on BOTH sides)
   would create edges, but they don't occur in practice because the elaborator grounds one
   side before the constraint is posted.

2. **Session type checking uses direct pattern matching.** Production `defproc` processing
   calls `type-proc` from `typing-sessions.rkt` (direct `sess-send`/`sess-recv` matching),
   NOT `check-session-via-propagators` from `session-propagators.rkt`. The propagator-based
   session checker exists but is only used in tests.

3. **Capability/effect propagators not exercised.** The `net-add-propagator` calls in
   `capability-inference.rkt`, `effect-ordering.rkt`, etc. exist but the current demo
   expressions don't trigger those subsystems.

**Consequence**: The visualizer currently shows **cells with subsystem coloring** (type-inference
green, infrastructure gray) but **no edges**. Edges will appear when either:
- The propagator-first elaboration migration wires constraint solving through the network
- Session type checking is switched to the propagator-based implementation
- Expressions are crafted that exercise capability/effect subsystems

**Note**: `process-file` calls `reset-meta-store!` per top-level form, creating a fresh
network each time. The final network snapshot is from the LAST top-level form only.

### Future: Propagator-First Elaboration Migration

A dedicated track will move the remaining imperative constraint-solving path (trait
resolution, hasmethod dispatch, session type checking) into the propagator network.
See `DEFERRED.md`.

---

## Infrastructure Gap Analysis

| Component | Status | What Exists | What's Needed |
|-----------|--------|-------------|---------------|
| Cell/propagator core | DONE | `propagator.rkt`: `prop-network`, `prop-cell`, `propagator` structs; pure persistent ops via CHAMP | — |
| Elaboration network | DONE | `elaborator-network.rkt`: `elab-network` wrapping `prop-network` with `elab-cell-info` (ctx, type, source) | — |
| ATMS | DONE | `atms.rkt`: assumptions, nogoods, `atms-explain` for GDE-2 minimal diagnosis | — |
| Constraint propagators | DONE | `constraint-propagators.rkt`: trait→type, type→constraint, result→constraint propagators | — |
| Infrastructure cells | DONE | `infra-cell.rkt`: registry, list, set, replace cells with merge functions | — |
| Named cell registry | DONE | Phase 0c: `net-register-named-cell` / `net-named-cell-ref/opt` | — |
| Deterministic IDs | DONE | `cell-id(n)`, `prop-id(n)` are Nat wrappers — serializable, stable | — |
| Network topology queries | DONE | `champ-keys`/`champ-fold` over cells, propagators; `prop-cell-dependents`; `propagator-inputs/outputs` | — |
| Cell state queries | DONE | `elab-all-cells`, `elab-unsolved-cells`, `elab-contradicted-cells`, `elab-cell-read`, `elab-cell-info-ref` | — |
| Perf counters | DONE | `cell_write_mismatches`, `speculation_count`, ATMS counters | — |
| **Trace/event capture** | **MISSING** | No recording of individual cell writes or propagator firings over time | **Phase 1** |
| **Network serialization** | **MISSING** | No JSON export of cell states, topology, or traces | **Phase 2** |
| **LSP network endpoint** | **MISSING** | LSP re-elaborates from scratch (Tier 2); no network access post-elaboration | **Phase 3** |
| **VS Code graph panel** | **MISSING** | InfoView webview exists as template; no graph rendering | **Phase 4** |
| **Step-through replay** | **MISSING** | Network is persistent (snapshots are free) but no replay infrastructure | **Phase 5** |
| **Source linking** | **PARTIAL** | `elab-cell-info-source` has debug strings/srclocs; not yet wired to LSP locations | **Phase 3** |

**Key architectural advantage**: The network is already pure/persistent (CHAMP structural sharing).
Every intermediate `prop-network` value after a cell write is a complete, valid snapshot held
by a single pointer to a CHAMP root. Old and new networks share all unchanged structure.
This gives us Clojure-style "time-travel for free" — the question is just which snapshots to keep.

## Trace Strategy: BSP-Round Snapshots

### Design Decision: Why BSP Rounds, Not Per-Propagator Firings

We evaluated four approaches to capturing propagator execution history. The key insight
is that the BSP (Bulk-Synchronous Parallel) scheduler already computes per-cell diffs
each round via `fire-and-collect-writes` — it just discards them. Capturing at BSP-round
boundaries is both honest to the execution model and nearly free.

#### Approaches Considered

**Option A — Keep every intermediate network (Clojure-style full history)**

`run-to-quiescence` is a pure recursive function `net → net → ... → net`. Each
intermediate `net*` after a propagator fires is a complete snapshot. Just cons them
onto an accumulator.

| Metric | Typical (200 steps, ~100 cells) | Worst case (4230 steps) |
|--------|--------------------------------|------------------------|
| Snapshots kept | 200 | 4,230 |
| Marginal memory per step | ~160B (2 changed cells × ~80B CHAMP path) | ~160B |
| Total marginal memory | ~32KB | ~680KB |
| Performance overhead | O(1) cons per step | O(1) cons per step |
| Replay quality | Perfect — every firing is a full queryable network | Same |

Risk: pathological cases (fuel exhaustion at 1M steps) could retain ~160MB. Mitigated
by the parameter being off by default and skip-listed tests.

**Option B — Callback observer parameter**

A `current-step-observer` parameter called with `(prop-id, net-before, net-after)` at
each firing. Observer decides what to keep.

- Flexible but more API surface.
- Observer must be careful not to retain too much.
- Moderate code change.

**Option C — Minimal diff log (step, prop-id, cell-id, old-value, new-value)**

Record only the changes, not full snapshots. Reconstruct any intermediate state by
replaying forward from the initial network.

| Metric | Typical | Worst case |
|--------|---------|------------|
| Memory per step | ~100B (symbols + small values) | ~100B |
| Total memory | ~20KB | ~420KB |
| Replay to step N | O(N) reconstruction | O(N) |
| Random access | O(N) without checkpoints | Add periodic snapshots for O(√N) |

The BSP scheduler's `fire-and-collect-writes` already computes these diffs — capturing
them is literally one `cons` in existing code.

**Option D — BSP-round snapshots + diffs (CHOSEN)**

Keep a network reference at each BSP *round* boundary, not at each individual firing.
For 200 steps with ~10 propagators per round, that's ~20 round snapshots instead of
200 per-firing snapshots. Combined with the per-cell diffs BSP already computes:

| Metric | Typical (~20 rounds) | Worst case (~400 rounds) |
|--------|---------------------|-------------------------|
| Snapshots kept | ~20 | ~400 |
| Marginal memory | ~3.2KB | ~64KB |
| Diffs per round | Free (already computed) | Free |
| Round-level replay | Instant (direct snapshot) | Instant |
| Per-firing replay | Reconstruct within round | Reconstruct within round |
| Performance overhead | Near-zero | Near-zero |

**Why this is the right granularity:**
- BSP rounds ARE the natural unit of propagation — all propagators in a round fire
  against the same snapshot, then writes are merged. This is the semantic step.
- Per-firing detail within a round is an implementation artifact of the scheduler,
  not a meaningful unit of information flow.
- If per-firing visualization is wanted later (e.g., for custom user-defined
  propagator networks), it can be added as a separate concern using Option A
  on a targeted subnetwork.

### Memory Budget

Based on actual elaboration metrics from the test suite:

| Metric | Typical | Peak | Source |
|--------|---------|------|--------|
| Elaborate steps | 0–200 | 4,230 | `timings.jsonl` |
| Metavars created | 0–25 | 103 | `timings.jsonl` |
| BSP rounds (est.) | 5–20 | ~400 | steps / avg propagators per round |
| Retained memory | 0–260KB | 260KB | `MEMORY-STATS` |
| Heap baseline | ~120MB | ~120MB | `MEMORY-STATS` |

The BSP-round trace adds <0.1% to heap in all measured cases. No special memory
management needed. The parameter is off by default — zero overhead in normal operation,
test suite, and CI. Only the LSP visualization path enables it.

### Zero-Cost-When-Off Guarantee

When `current-bsp-observer` is `#f` (the default), the trace infrastructure imposes
**no measurable cost** on the propagator network:

- **No new allocation**: The intermediate `merged` network and `all-writes` diff list
  are already computed by the BSP scheduler as part of its normal operation. When tracing
  is off, they are used and GC'd exactly as today. No new data structures are created.
- **No new computation**: `fire-and-collect-writes` already diffs output cells to know
  what to merge. We are not adding diffing — we are optionally retaining diffs that are
  already computed and currently discarded.
- **Minimal branch cost**: One `(when observer ...)` check per BSP round, where `observer`
  is a let-bound local from `(current-bsp-observer)` read once at loop entry. Evaluates to
  `#f`, skips the body. This is the same pattern used by `current-perf-counters` throughout
  the codebase.
- **No struct instantiation**: The `bsp-round`, `cell-diff`, and `prop-trace` struct
  definitions exist in the module but are never instantiated when tracing is off.
- **No GC pressure**: No references are retained, no snapshot lifetimes are extended.
  The GC profile is identical to the current codebase.

This guarantee means the visualization feature can be merged into the main codebase
without any performance regression for users who never open the Propagator View panel.

## Critical Path

```
Phase 0 (First-Class Trace Data Type)
    ↓
Phase 1 (BSP Round Capture)
    ↓
Phase 2 (Serialization)      ← thin adapter over Phase 0 data
    ↓
Phase 3 (LSP Endpoint)       ← depends on Phase 1 + 2
    ↓
Phase 4 (VS Code Panel)      ← depends on Phase 3
    ↓
Phase 5 (Round Replay)       ← depends on Phase 4 + round data from Phase 1
    ↓
Phase 6 (Polish)             ← depends on Phase 4 + 5
```

Phase 0 defines the data representation first — all subsequent phases are views over it.
Phases 1 and 2 can be developed/tested independently of the VS Code extension.
Phase 4 can start with static snapshot rendering while Phase 5 adds replay.

## Phase 0: First-Class Trace Data Representation

**Goal**: Define the trace data as a first-class Prologos-side type before any capture
or serialization code exists. The trace is *data* — pure, inspectable, serializable,
reusable — not an implementation artifact of the visualization pipeline.

**Principle**: First-Class by Default. The BSP round trace should be representable as
a Prologos `data` type (or at minimum a well-defined Racket struct hierarchy that
corresponds 1:1 to a future Prologos type). JSON serialization becomes a thin adapter
over this data, not the canonical form. Other consumers (REPL inspection, programmatic
analysis, test assertions, future Prologos-side tooling) work with the same data.

### 0a: Core Data Types

```racket
;; A single BSP round's record — pure data, no side effects
(struct bsp-round
  (round-number        ;; Nat — 0-indexed
   network-snapshot    ;; prop-network — immutable CHAMP snapshot at round end
   cell-diffs          ;; (listof cell-diff) — what changed this round
   propagators-fired   ;; (listof prop-id) — which propagators fired
   contradiction       ;; #f | cell-id — contradiction detected this round
   atms-events)        ;; (listof atms-event) — assumption/retraction/nogood events
  #:transparent)

(struct cell-diff
  (cell-id             ;; cell-id
   old-value           ;; any — cell value before round
   new-value           ;; any — cell value after round
   source-propagator)  ;; prop-id — which propagator wrote this change
  #:transparent)

;; ATMS events that occur during a BSP round
(struct atms-event () #:transparent)
(struct atms-event:assume atms-event (cell-id assumption-label) #:transparent)
(struct atms-event:retract atms-event (cell-id assumption-label reason) #:transparent)
(struct atms-event:nogood atms-event (nogood-set explanation) #:transparent)

;; The complete trace of an elaboration run
(struct prop-trace
  (initial-network     ;; prop-network — state before first round
   rounds              ;; (listof bsp-round) — chronological order
   final-network       ;; prop-network — quiescent state
   metadata)           ;; hasheq — elaboration context (file, timestamp, fuel-used, etc.)
  #:transparent)
```

### 0b: Data-Oriented Design Rationale

The trace types are **pure data** with no behavior attached:
- `#:transparent` — inspectable, printable, testable via `equal?`
- No mutable fields — a `prop-trace` value is a complete, immutable record
- No methods or protocols — operations are external functions over the data
- Composable — two traces can be concatenated, filtered, or diffed
- The `metadata` hasheq is an open extension point (timestamps, file paths,
  elaboration options) without requiring struct changes

This follows the project's **Decomplection** principle: the data representation is
decoupled from how it's captured (Phase 1), how it's serialized (Phase 2), and how
it's rendered (Phase 4). Any of these can change independently.

### 0c: ATMS Event Representation

Non-monotonic events (assumption introduction, retraction, nogood discovery) are
first-class in the round record via `atms-events`. This is critical because:
- ATMS operations happen *during* BSP rounds, interleaved with cell writes
- A nogood discovered mid-round changes the interpretation of subsequent propagator firings
- The diagnosis view (Phase 6c) needs to correlate nogoods with the round in which
  they were discovered
- Without explicit ATMS events, the trace would be incomplete for any elaboration
  involving speculative type-checking (Church folds, union dispatch)

### 0d: Future Prologos-Side Type

The Racket structs are designed to map directly to a future Prologos `data` declaration:

```
data CellDiff := cell-diff [cell-id : CellId] [old : Value] [new : Value] [source : PropId]

data AtmsEvent
  | assume [cell : CellId] [label : Symbol]
  | retract [cell : CellId] [label : Symbol] [reason : Symbol]
  | nogood [nogood-set : List Assumption] [explanation : List CellId]

data BspRound := bsp-round
  [round : Nat] [snapshot : PropNetwork] [diffs : List CellDiff]
  [fired : List PropId] [contradiction : Option CellId]
  [atms-events : List AtmsEvent]

data PropTrace := prop-trace
  [initial : PropNetwork] [rounds : List BspRound]
  [final : PropNetwork] [metadata : Map Symbol Value]
```

When Prologos gains FFI or reflection capabilities, these types become the bridge
between the Racket runtime and Prologos-side analysis tools.

**Files**: New structs in `racket/prologos/propagator.rkt` (co-located with network types)
**Exports**: `bsp-round`, `cell-diff`, `atms-event`, `atms-event:assume/retract/nogood`, `prop-trace`
**Tests**: ~5 (struct construction, transparency, equality)
**Dependencies**: None

---

## Phase 1: BSP-Round Trace Capture

**Goal**: Capture a network snapshot and cell-diff summary at each BSP round boundary.
Leverage the persistent network and BSP's existing diff mechanism — no new instrumentation
of individual cell writes or propagator internals.

### 1a: Data Types

Phase 0 defines the data types (`bsp-round`, `cell-diff`, `atms-event`, `prop-trace`).
Phase 1 uses them — no new struct definitions needed here.

### 1b: Observer Parameter (Decoupled)

The capture mechanism uses a **callback parameter**, not a mutable box. This follows
the **Decomplection** principle: the scheduler emits round records; what happens to
them is the caller's concern.

```racket
;; Observer callback: (bsp-round → void). #f = no observer = zero cost.
(define current-bsp-observer (make-parameter #f))

;; Inside run-to-quiescence-bsp, at end of each round:
(define observer (current-bsp-observer))
(when observer
  (observer (bsp-round round-number merged cell-diffs fired-pids contradiction atms-evts)))
```

**Why a callback, not a box-of-list?** A `box` couples the scheduler to a specific
accumulation strategy (prepend-then-reverse). A callback lets callers:
- Accumulate into a list (the common case for visualization)
- Stream to a file (for large traces)
- Filter on the fly (keep only rounds with contradictions)
- Forward to an LSP notification channel (live updates)

The standard accumulator is a one-liner convenience:

```racket
;; Convenience: create an accumulating observer
(define (make-trace-accumulator)
  (define rounds (box '()))
  (values
    (lambda (round) (set-box! rounds (cons round (unbox rounds))))
    (lambda () (reverse (unbox rounds)))))  ;; → (listof bsp-round)
```

### 1c: Modified BSP Scheduler

`run-to-quiescence-bsp` already has the round loop structure and computes diffs.
The change is minimal — call the observer when present:

The round's `merged` network is already computed — we just keep a reference to it.
The `cell-diffs` are already computed by `fire-and-collect-writes` — we just don't
discard them. Zero new computation.

### 1d: Initial + Final Network Capture

The caller captures the network before and after `run-to-quiescence-bsp` to construct
the full `prop-trace`. This keeps the scheduler free of trace-assembly concerns:

```racket
(define (elaborate-with-trace ...)
  (define-values (observe get-rounds) (make-trace-accumulator))
  (define initial-net (current-prop-network))
  (parameterize ([current-bsp-observer observe])
    (run-to-quiescence-bsp ...))
  (define final-net (current-prop-network))
  (prop-trace initial-net (get-rounds) final-net
              (hasheq 'file uri 'timestamp (current-seconds))))
```

### 1e: Gauss-Seidel Fallback

The standard `run-to-quiescence` (Gauss-Seidel scheduler) fires one propagator at a
time. For visualization, treat each firing as a degenerate "round" of one propagator.
Use Option A (accumulate per-firing snapshots) since GS is only used when BSP isn't
available. The per-firing snapshots in GS are equivalent to per-round snapshots in BSP
from the user's perspective.

**Files**: Modified `propagator.rkt` (observer param, observer call in BSP loop)
**New exports**: `current-bsp-observer`, `make-trace-accumulator`
**Tests**: ~8 (trace capture on small networks, verify round ordering and diffs)
**Dependencies**: Phase 0 (data types)

## Phase 2: Network Serialization

**Goal**: Serialize a network snapshot + trace log to JSON for consumption by LSP/VS Code.
This is a **thin adapter** over the Phase 0 data types — the canonical representation is
the Racket-side `prop-trace` / `bsp-round` structs, not the JSON. Any consumer that can
work with the Racket data directly (REPL, tests, future Prologos-side tools) should prefer
the structs over JSON.

### 2a: Cell Serialization

```racket
(define (serialize-cell net cell-id elab-net)
  (hasheq 'id (cell-id-n cell-id)
          'value (serialize-lattice-value (net-cell-read net cell-id))
          'state (cond [(elab-cell-solved? elab-net cell-id) "solved"]
                       [(elab-cell-contradicted? elab-net cell-id) "contradicted"]
                       [else "unsolved"])
          'dependents (map prop-id-n (champ-keys (prop-cell-dependents ...)))
          'info (let ([info (elab-cell-info-ref elab-net cell-id)])
                  (and info
                       (hasheq 'source (format "~a" (elab-cell-info-source info))
                               'expected-type (pp-expr (elab-cell-info-type info)))))))
```

### 2b: Propagator Serialization

```racket
(define (serialize-propagator net prop-id)
  (define p (champ-ref (prop-network-propagators net) prop-id #f))
  (hasheq 'id (prop-id-n prop-id)
          'inputs (map cell-id-n (propagator-inputs p))
          'outputs (map cell-id-n (propagator-outputs p))
          'kind (propagator-kind-string p)))  ;; "unify", "trait-constraint", etc.
```

### 2c: Full Snapshot Serialization

```racket
(define (serialize-network-snapshot elab-net)
  (hasheq 'cells (serialize-all-cells ...)
          'propagators (serialize-all-propagators ...)
          'topology (serialize-adjacency ...)    ;; for graph layout
          'stats (hasheq 'total-cells N
                         'solved N
                         'unsolved N
                         'contradicted N
                         'total-propagators N)))
```

### 2d: Lattice Value Serialization

The tricky part — cell values are arbitrary Racket expressions (types, multiplicities,
session types). Need a `serialize-lattice-value` that handles:
- `type-bot` / `type-top` → `"⊥"` / `"⊤"`
- Concrete types → `pp-expr` output
- Multiplicity values → `"0"`, `"1"`, `"ω"`
- Registry hasheqs → summary string (`"3 entries"`)

**Files**: New `racket/prologos/trace-serialize.rkt`
**Tests**: ~15 (round-trip serialization on various cell types)
**Dependencies**: Phase 1 (trace structs)

## Phase 3: LSP Endpoint

**Goal**: Expose network snapshots and trace data via a custom LSP request.

### 3a: Network Capture During Elaboration

Extend `elaborate-and-publish-diagnostics!` to optionally capture the trace using
the decoupled observer from Phase 1:

```racket
;; In elaborate-and-publish-diagnostics!:
(define-values (observe get-rounds) (make-trace-accumulator))
(define initial-net #f)

(parameterize ([current-bsp-observer (if trace-enabled? observe #f)]
               ...)
  (set! initial-net (current-prop-network))
  (process-file tmp-path)
  (when trace-enabled?
    (set! captured-trace
      (prop-trace initial-net (get-rounds) (current-prop-network)
                  (hasheq 'file uri 'timestamp (current-seconds))))))
```

Store in lsp-state:
```racket
(struct lsp-state
  (...
   elab-networks     ;; hash: uri → elab-network (snapshot after elaboration)
   prop-traces       ;; hash: uri → prop-trace (when visualization active)
   ...))
```

### 3b: Custom LSP Request

Register `prologos/propagatorSnapshot` as a custom request:

```json
{
  "method": "prologos/propagatorSnapshot",
  "params": { "uri": "file:///..." },
  "result": {
    "cells": [...],
    "propagators": [...],
    "topology": {...},
    "stats": {...},
    "trace": [...]    // ordered event log
  }
}
```

### 3c: Source Location Linking

Map cell-ids back to source locations via `elab-cell-info-source`. When the VS Code
panel highlights a cell, it can jump to the corresponding source location.

**Files**: Modified `lsp/server.rkt`
**Tests**: ~5 (custom request round-trip)
**Dependencies**: Phase 1 + 2

## Phase 4: VS Code Graph Panel

**Goal**: Render the propagator network as an interactive graph in a VS Code webview panel.

### 4a: Panel Registration

Add a "Propagator View" webview panel, opened via:
- A button in the InfoView sidebar ("View Network")
- A command: `prologos.showPropagatorView`

Register in `package.json` as a secondary panel (editor column 2, beside the code).

### 4b: Graph Library Decision — D3 + d3-dag

**Chosen: D3 + d3-dag for layout, Canvas rendering for performance.**

#### Why Not Cytoscape.js

Cytoscape is batteries-included for generic graph visualization, but propagator networks
are not generic graphs. They are **bipartite DAGs** — cells and propagators form two
disjoint node sets, with directed edges always crossing between sets (cell → propagator
→ cell). This topology has a natural layered/dataflow structure.

Cytoscape's limitations for this use case:
- **Force-directed is the wrong default** — it produces "hairball" layouts that obscure
  information flow direction. Propagator networks need layered/Sugiyama layout to show
  how information flows from inputs through propagators to outputs.
- **Opaque rendering** — when BSP-round replay needs to animate cell value transitions,
  flash propagator firings, and highlight ATMS assumption changes, we're fighting
  Cytoscape's rendering pipeline rather than drawing what we want.
- **Scale ceiling** — performance degrades around 2000+ nodes with force layout. While
  current elaboration networks peak at ~500 nodes, user-defined propagator networks and
  whole-module visualization could exceed this.

#### Why D3 + d3-dag

D3 separates layout computation from rendering — we control both independently:

- **d3-dag** provides Sugiyama/layered layout algorithms purpose-built for DAGs. This is
  the correct layout for dataflow: information flows top-to-bottom (or left-to-right),
  edges cross minimally, and the bipartite structure (cells vs propagators) is visually
  obvious.
- **Canvas rendering** for the graph gives smooth 60fps animation at 5000+ nodes. SVG
  is available as a fallback for static export (Phase 6d).
- **Full rendering control** — BSP-round replay (Phase 5) needs frame-by-frame updates:
  cell labels change, edges flash, nodes change color/state. With D3+Canvas, this is
  direct draw calls, not DOM manipulation through an abstraction layer.
- **The "boilerplate" is domain code** — what Cytoscape hides (node rendering, event
  handling, layout wiring) is exactly what we need to customize. Our rendering code
  expresses propagator network semantics, not generic graph boilerplate.

#### Measured Network Sizes (Grounding the Decision)

From the test suite benchmark data:

| File | Cells (est.) | Propagators (est.) | Total Nodes |
|------|-------------|-------------------|-------------|
| test-reducible.rkt | ~206 | ~316 | ~522 |
| test-list-extended-01-02.rkt | ~194 | ~260 | ~454 |
| test-collection-fns-02.rkt | ~182 | ~153 | ~335 |
| test-functor-ws.rkt (peak steps) | ~200+ | ~1100+ | ~1300+ |
| Typical single expression | ~20-40 | ~20-60 | ~40-100 |

Estimates: cells ≈ 2×meta_created (type + multiplicity per meta) + constraint_count;
propagators ≈ unify_steps + trait_resolve_steps (rough proxy for total propagators).

Current peak is ~500 nodes for the most complex test files. Single-expression elaboration
(the common visualization case) is 40-100 nodes. But user-defined propagator networks and
whole-module visualization could reach 1000-5000 nodes — Canvas handles this comfortably;
SVG and Cytoscape would struggle.

#### Layout Strategy

The propagator network is a bipartite DAG. d3-dag's Sugiyama layout with:
- **Layer assignment**: cells and propagators alternate in layers, reflecting the
  cell → propagator → cell dataflow
- **Crossing minimization**: edges are routed to minimize visual clutter
- **Flow direction**: top-to-bottom by default; user can toggle to left-to-right
- **Compound nodes** (future): group cells by elaboration context (e.g., all metas
  from a single function definition form a subgraph)

For very small networks (<20 nodes), a simpler force-directed layout may be more
readable. Provide a layout toggle: Sugiyama (default) / force-directed / manual.

### 4c: Visual Encoding

| Element | Shape | Default Color | State Encoding |
|---------|-------|---------------|----------------|
| Cell (unsolved) | Circle | Gray | Dashed stroke, "?" label |
| Cell (solved) | Circle | Green | Solid stroke, value label (truncated) |
| Cell (contradicted) | Circle | Red | Solid stroke, "⊤" label, pulse animation |
| Cell (meta-type) | Circle | Blue-gray | Distinguishes type metas from mult metas |
| Cell (meta-mult) | Circle | Purple-gray | QTT multiplicity cells |
| Cell (registry) | Rounded rect | Slate | Infrastructure cells, collapsible |
| Propagator | Diamond | Blue | Label: kind ("unify", "trait", "session") |
| Edge (input) | Arrow → propagator | Light gray | Thin line, arrow at propagator end |
| Edge (output) | Arrow → cell | Dark gray | Thicker line, arrow at cell end |
| Active firing | Edge | Orange flash | Brief pulse during replay (Phase 5) |
| ATMS assumption | Triangle | Yellow | Assumption label; retracted = strikethrough |
| ATMS nogood | Hexagon | Red-orange | Connected to contradicted cells |

Color scheme uses VS Code CSS variables (`--vscode-editor-foreground`, etc.) as base,
with domain-specific semantic colors overlaid. Dark/light theme compatibility via
alpha-blended overlays on the VS Code background color.

Cell value labels are truncated to ~20 chars with full value shown on hover tooltip.
Type expressions use the same pretty-printer as the InfoView panel.

### 4d: Hover Tooltips

Canvas has no DOM elements — no `title` attributes or CSS `:hover` states. Hover
requires tracking `mousemove`, hit-testing against the quadtree, and rendering a
tooltip ourselves. Three approaches were considered:

#### Approaches Considered

**Option A — HTML overlay tooltip (CHOSEN)**

An absolutely-positioned `<div>` floats over the Canvas, positioned at the
hovered node's screen coordinates. Standard pattern for D3+Canvas visualizations.

- Rich HTML content: monospace type signatures, colored state badges, clickable links
- Styled with VS Code CSS variables (matches InfoView, detail panel, toolbar)
- Multi-line content without fighting Canvas text measurement/wrapping
- Slight visual layer mismatch (HTML over Canvas), but this is universal practice

**Option B — Canvas-drawn tooltip**

Render the tooltip directly on Canvas as part of the draw loop.

- Visually integrated — no DOM layer boundary
- But: Canvas text rendering is painful (no word wrap, no rich formatting, manual
  line height, no clickable links). Every tooltip change requires a full Canvas
  repaint or a dedicated overlay canvas.
- Not worth the complexity for a tooltip that needs rich formatting.

**Option C — Canvas highlight only, defer to click**

On hover, highlight the node (glow ring) but show no tooltip. Full information
on click only.

- Lightest implementation — no tooltip rendering at all
- But: breaks the "glanceable" experience. Users expect hover to preview
  information before committing to a click. A graph with no hover feedback
  feels unresponsive.

#### Chosen: A + C hybrid (HTML tooltip + Canvas highlight)

On `mousemove` → quadtree hit test → if node found:
1. **Canvas**: draw a highlight ring around the hovered node (glow or thicker stroke)
2. **HTML**: position a tooltip `<div>` near the node with key information

The tooltip `<div>` is a single reusable element, repositioned and re-populated on
each hover target change. Hidden when the mouse leaves all nodes. Debounced at 16ms
(one frame) to avoid flicker during fast mouse movement.

#### Tooltip Content by Node Type

| Node Type | Tooltip Content |
|-----------|----------------|
| Cell (type meta) | `#42 : ?T₃`  state badge (solved/unsolved/contradicted)  value if solved (full, not truncated)  source location (file:line) |
| Cell (mult meta) | `#17 : ?m₂`  multiplicity value (0/1/ω)  state badge |
| Cell (registry) | Name  entry count  kind (list-registry, set-registry, etc.) |
| Propagator | Kind label ("unify", "trait-resolve", "session-step")  `inputs: #3, #7 → outputs: #12`  times fired (total across all rounds) |
| Edge | Source → target  last-active round number |
| ATMS assumption | Label  status (active/retracted)  dependent cell count |
| ATMS nogood | Nogood set members  round discovered |

Type signatures in tooltips use the same pretty-printer as the InfoView panel —
monospace font, consistent formatting. The tooltip width is capped at 300px; values
exceeding this are truncated with `...` and shown in full in the detail panel on click.

#### Implementation

```typescript
// Single reusable tooltip element
const tooltip = document.createElement('div');
tooltip.className = 'prop-tooltip';
tooltip.style.position = 'absolute';
tooltip.style.pointerEvents = 'none';  // don't interfere with Canvas events
container.appendChild(tooltip);

canvas.addEventListener('mousemove', (e) => {
  const [gx, gy] = screenToGraph(e.offsetX, e.offsetY);  // inverse zoom transform
  const node = quadtree.find(gx, gy, hitRadius);
  if (node && node !== lastHovered) {
    tooltip.innerHTML = renderTooltip(node);
    tooltip.style.left = `${e.offsetX + 12}px`;
    tooltip.style.top = `${e.offsetY - 8}px`;
    tooltip.style.display = 'block';
    lastHovered = node;
    requestRedraw();  // draw highlight ring
  } else if (!node) {
    tooltip.style.display = 'none';
    lastHovered = null;
    requestRedraw();  // clear highlight ring
  }
});
```

### 4e: Interaction

**Click behavior:**
- **Click cell** → detail panel below graph (value, typing context, source location,
  dependent propagators) + highlight source line in editor via `vscode.commands`
- **Click propagator** → detail panel (inputs/outputs, kind, firing count per round,
  source expression that created it)
- **Double-click cell** → focus view: zoom to this cell's N-hop neighborhood

**Source linking (bidirectional):**
- Click cell → highlight source location in editor
- Click source expression in editor → highlight corresponding cell(s) in graph
  (requires `prologos.revealCell` command wired to `onDidChangeTextEditorSelection`)

**Node dragging:**
- Click-drag a node to manually reposition it (d3-drag, ~5KB additional dependency)
- Dragged position is sticky — survives replay steps and zoom changes
- "Reset layout" button recomputes Sugiyama positions, clearing all manual overrides
- Useful when the automatic layout places related cells far apart

**Filtering:**
- Toggle by cell domain: type metas / multiplicity metas / session metas / registries
- Toggle by propagator kind: unify / trait-resolve / constraint / session
- Hide solved cells (show only unsolved + contradicted — useful for debugging)
- Collapse infrastructure (registry cells, list/set cells) to reduce noise

**Layout controls:**
- Switch between Sugiyama (default) and force-directed
- Flow direction: top-to-bottom / left-to-right
- Zoom/pan via mouse wheel + drag (d3-zoom)
- Fit-to-view button
- Zoom-to-selection: double-click a node to smoothly zoom and center on its neighborhood
- Minimap for large networks (>100 nodes)

**Animated transitions:**
- When stepping between BSP rounds (Phase 5), nodes that move due to layout changes
  animate smoothly to their new positions rather than jumping
- New nodes fade in; removed nodes fade out
- Cell value label changes cross-fade

### 4f: Rendering Architecture

```
┌─────────────────────────────────────┐
│  VS Code Webview                    │
│                                     │
│  ┌───────────────────────────────┐  │
│  │  <canvas> (primary render)    │  │  ← d3-zoom transforms, node/edge drawing
│  │  d3-dag layout → positions    │  │  ← Sugiyama computes (x,y) per node
│  │  requestAnimationFrame loop   │  │  ← 60fps during replay animation
│  └───────────────────────────────┘  │
│                                     │
│  ┌───────────────────────────────┐  │
│  │  Detail panel (HTML)          │  │  ← Cell/propagator details on click
│  └───────────────────────────────┘  │
│                                     │
│  ┌───────────────────────────────┐  │
│  │  Timeline bar (HTML/CSS)      │  │  ← Phase 5: round scrubber
│  └───────────────────────────────┘  │
│                                     │
│  ┌───────────────────────────────┐  │
│  │  Toolbar (HTML)               │  │  ← Layout, filter, zoom controls
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

The Canvas renders the graph; HTML elements overlay it for UI controls and detail panels.
This avoids DOM-heavy rendering for the graph itself while keeping interactive controls
in standard HTML (consistent with VS Code's webview patterns and the existing InfoView).

Hit testing for click/hover on Canvas nodes uses a quadtree spatial index (d3-quadtree)
for O(log n) lookup — no need to maintain a parallel DOM structure.

### 4g: Bundled Dependencies

| Dependency | Size (minified) | Purpose |
|------------|----------------|---------|
| d3-dag | ~30KB | Sugiyama layout for DAGs |
| d3-zoom | ~15KB | Pan/zoom behavior |
| d3-quadtree | ~5KB | Spatial index for hit testing |
| d3-drag | ~5KB | Node dragging |
| d3-force (optional) | ~15KB | Force-directed layout fallback |
| Total | ~70KB | vs ~400KB for Cytoscape.js |

Bundled into `editors/vscode-prologos/lib/` as minified ESM modules, loaded in the
webview via local URIs. No build tooling required — the modules are pre-built.

Note: we deliberately avoid pulling in all of D3 (~250KB). Only the specific D3
subpackages needed are bundled. D3's modular architecture supports this naturally.

### 4h: SVG Export Path

For static diagrams (documentation, papers, wiki articles — Phase 6d), the same d3-dag
layout positions can drive an SVG renderer instead of Canvas. This is a thin alternative
render pass over the same layout data — no duplicate layout computation.

```typescript
function renderToSVG(layout: LayoutResult): string {
  // Same node positions as Canvas, rendered as SVG elements
  // Returns a self-contained SVG string for export
}
```

**Files**: New `editors/vscode-prologos/src/propagator-view.ts`,
  `editors/vscode-prologos/src/graph-renderer.ts` (Canvas + SVG render),
  `editors/vscode-prologos/src/graph-layout.ts` (d3-dag layout wrapper)
**Modified**: `package.json` (command, panel), `extension.ts` (registration)
**Dependencies**: Phase 3 (LSP endpoint for data), d3-dag + d3-zoom + d3-quadtree + d3-drag (bundled)
**Tests**: Manual visual testing + snapshot tests for serialization + layout determinism tests

## Phase 5: BSP-Round Replay

**Goal**: Replay the elaboration trace round-by-round, showing cells narrowing over time.
Each BSP round is a natural frame — all propagators in the round fire against the same
snapshot, then writes merge. This IS how propagation works; the visualization is honest
to the execution model.

### 5a: Timeline Control

Add a timeline control bar below the graph:
- Play/pause button
- Step forward/backward (one BSP round per step)
- Speed control
- Round counter: "Round 7 / 18"
- Jump to contradiction (if any)

### 5b: Differential Rendering

Each `bsp-round` already contains the `cell-diffs` (which cells changed) and
`propagators-fired` (which propagators ran). No diffing needed — it's pre-computed:
- Cells in `cell-diffs` → flash animation, update label with new value
- Propagators in `propagators-fired` → highlight edges
- New cells/propagators (round 0 → 1) → fade in
- Contradiction → red pulse on the cell

### 5c: Round Annotations

Show the current round's summary as a status bar annotation:
- `"Round 3: 4 propagators fired, 2 cells narrowed"`
- `"Round 7: unify #3 ↔ #5 → Int, trait-resolve #8 → Eq Int"`
- `"Round 12: Contradiction at Cell #15"` (red)
- `"Quiescence: 18 rounds, 42 cells solved, 0 unsolved"` (green)

### 5d: Bookmarked Rounds

Allow the user to bookmark specific rounds. Useful for comparing "before and after"
a particular propagation burst. Since each round's snapshot is already retained
(O(1) pointer), bookmarking is free.

### 5e: Future — Per-Firing Detail Within a Round

For advanced users or custom propagator networks, allow expanding a single BSP round
to see the individual propagator firings within it. This would use Option A
(per-firing snapshots) scoped to just the selected round — not the entire elaboration.
Deferred until custom prop-net specification support is in place.

**Files**: Modified `propagator-view.ts` (timeline UI + diff rendering)
**Dependencies**: Phase 4 (graph panel), Phase 1 (BSP round data)

## Phase 6: Polish and Integration

### 6a: Bidirectional Source Linking

- Click a metavariable in source → highlight its cell in the graph
- Click a cell in the graph → highlight its source location + show type in InfoView
- Diagnostic hover → link to the contradiction cell in the graph

### 6b: Focused Subgraph View

For large networks, allow the user to:
- Select a source expression → show only the subgraph reachable from its cells
- "Expand neighborhood" — show N hops from a selected cell
- Collapse infrastructure cells (registries, etc.) to reduce noise

### 6c: ATMS Diagnosis View

When a contradiction exists:
- Show the nogood set (minimal contradictory assumptions)
- Highlight the causal path from assumptions to contradiction
- Use `atms-explain` to compute minimal diagnosis

### 6d: Export

- Export graph as SVG (for documentation, papers, wiki articles)
- Export trace as JSON (for external analysis)

## Tradeoff Analysis

### Trace Capture Strategy

| Approach | Memory (typical) | Memory (peak) | Perf overhead | Replay quality | Code change |
|----------|-----------------|---------------|---------------|----------------|-------------|
| A: Full per-firing snapshots | ~32KB | ~680KB | O(1) cons/step | Perfect | Small (accumulator) |
| B: Callback observer | Varies | Varies | 1 call/step | Varies | Moderate |
| C: Minimal diff log | ~20KB | ~420KB | ~Free (BSP already diffs) | O(N) reconstruction | Small |
| **D: BSP-round snapshots** | **~3.2KB** | **~64KB** | **Near-zero** | **Instant per-round** | **Minimal** |

**Chosen: Option D.** BSP rounds are the semantic unit of propagation. The scheduler already
computes diffs; we just stop discarding them. Memory is <0.1% of heap in all measured cases.
Per-firing resolution deferred to future work on custom prop-net specifications.

### Graph Rendering Library

| Library | Layout | Rendering | Scale | Bundle | Control | Recommendation |
|---------|--------|-----------|-------|--------|---------|----------------|
| Cytoscape.js | Force, hierarchical, breadthfirst | Canvas (opaque) | ~2K nodes | ~400KB | Low — opaque API | Not chosen |
| **D3 + d3-dag** | **Sugiyama/layered (DAG-native)** | **Canvas (direct)** | **5K+ nodes** | **~65KB** | **Full** | **Chosen** |
| D3 + Elk.js | Sugiyama/layered (port-based) | SVG or Canvas | ~3K nodes | ~300KB | High | Viable alternative |
| D3-force only | Force-directed | SVG or Canvas | ~3K nodes | ~30KB | High | Wrong layout for DAGs |

**Chosen: D3 + d3-dag.** The propagator network is a bipartite DAG — cells and
propagators form two node sets with directed edges always crossing between them.
Sugiyama/layered layout makes information flow direction visible, which is the core
purpose of the visualization. Force-directed layout obscures this structure.

D3's modularity means we bundle only the subpackages we need (~65KB total vs ~400KB
for Cytoscape or ~250KB for all of D3). Canvas rendering gives 60fps animation for
BSP-round replay at 5K+ nodes. Full rendering control means Phase 5 (replay animation)
is direct draw calls, not API workarounds.

The "boilerplate" concern is addressed by noting that our rendering code IS the domain
logic — it expresses propagator network semantics (cell states, propagator firings,
ATMS assumptions), not generic graph chrome. This aligns with First-Class by Default:
the visualization code is specific to our domain, not a configuration of someone else's
abstraction.

### Visualization Approach

| Approach | Pros | Cons | Recommendation |
|----------|------|------|----------------|
| Static snapshot only | Simple, no trace overhead | No animation, less educational | Start here (Phase 4a-d) |
| BSP-round replay | Natural granularity, low memory | Not per-firing | Phase 5 (additive) |
| Per-firing replay | Maximum detail | Higher memory, GS scheduler only | Future (custom prop-nets) |
| Live incremental (Tier 3+) | Real-time as user types | Requires incremental elaboration | Future (when LSP Tier 3+ lands) |
| Separate Electron app | No VS Code coupling | Separate install, context switching | Not recommended |
| Web-based (localhost) | Cross-editor | Deployment complexity | Not recommended for Phase 0 |

## Principle Alignment

### Principles This Design Honors

- **Invisible infrastructure, visible behavior**: The propagator network is infrastructure;
  the visualization makes its behavior visible without changing it.
- **Completeness over deferral**: Each phase is self-contained and useful on its own.
  Phase 4 (static graph) is valuable without Phase 5 (replay).
- **The tool is the documentation**: The visualization explains propagators better than
  any paper. This aligns with the project's educational mission.
- **Zero-cost-when-off**: The observer parameter adds no overhead when disabled,
  matching the `current-perf-counters` pattern used throughout the codebase.

### Principles Addressed by This Design (Self-Critique Incorporated)

**First-Class by Default** — Phase 0 addresses this directly. The trace is defined as
a first-class data type (`prop-trace`, `bsp-round`, `cell-diff`) before any capture or
serialization code. JSON is a thin adapter, not the canonical representation. The data
is inspectable from the REPL, testable via `equal?`, composable (traces can be filtered,
concatenated, diffed), and will map 1:1 to a future Prologos `data` declaration. This
ensures the trace is reusable beyond visualization — test assertions, programmatic
analysis, and Prologos-side tooling all consume the same data.

**Decomplection** — The observer callback (`current-bsp-observer`) decouples the
scheduler from trace accumulation strategy. The scheduler emits round records; how they
are collected, stored, streamed, or discarded is the caller's concern. This is cleaner
than a `box-of-list` which couples the scheduler to a specific accumulation pattern and
requires the scheduler to know about list reversal semantics.

**Homoiconicity as Invariant** — The trace data types are transparent Racket structs
that correspond to a planned Prologos `data` declaration (see Phase 0d). When Prologos
gains reflection/FFI, the trace becomes first-class Prologos data, inspectable and
manipulable with the same tools as any other program value.

### Known Gaps and Future Work

**ATMS non-monotonic events** — BSP rounds capture monotonic cell writes naturally, but
non-monotonic ATMS operations (assumption retraction, nogood discovery) require explicit
event records. Phase 0 includes `atms-event` variants for this purpose. The capture code
(Phase 1) must hook into the ATMS operations that fire during elaboration — this is the
one place where new instrumentation is genuinely needed (as opposed to retaining existing
diffs). The complexity is bounded: ATMS events are rare relative to cell writes, and the
hook points are well-defined in `atms.rkt`.

**Tier 3+ incremental elaboration** — The current design assumes full re-elaboration per
file (Tier 2 LSP). When incremental elaboration lands (Tier 3+), the trace model needs
to handle *partial* re-elaboration: only some cells/propagators are re-fired, and the
trace should capture the delta, not repeat the unchanged portion. The decoupled observer
pattern helps here — the incremental elaborator can install an observer that only records
rounds in the re-elaborated region. But the `prop-trace` struct may need a
`parent-trace` field or a way to represent trace composition. This is explicitly deferred
until Tier 3+ design is further along; the Phase 0 data types are designed to be
extensible via the `metadata` hasheq and struct subtypes.

**Propagator-First Infrastructure** — The visualization should eventually support
user-defined propagator networks, not just the elaboration network. The current design
is scoped to elaboration traces because that's what exists today. The Phase 0 data types
are generic (`prop-trace` wraps any `prop-network`, not specifically `elab-network`),
so extending to user-defined networks requires no data type changes — only new capture
points.
