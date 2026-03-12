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

### 4b: Graph Rendering

Use a lightweight graph library in the webview. Options:
- **Cytoscape.js**: Mature, supports force-directed + hierarchical layouts, good performance
  up to ~500 nodes. Ideal for propagator networks which are typically small-to-medium.
- **D3-force**: More control, but more boilerplate. Better for custom aesthetics.
- **Elk.js**: Layered/hierarchical layout (good for dataflow graphs). Can combine with
  simple SVG rendering.

**Recommended: Cytoscape.js** — best balance of features, performance, and simplicity.
Can switch to Elk.js for layout if hierarchical rendering is preferred.

### 4c: Visual Encoding

| Element | Visual | Encoding |
|---------|--------|----------|
| Cell (unsolved) | Circle, gray | Dashed border, "?" label |
| Cell (solved) | Circle, green | Solid border, value label |
| Cell (contradicted) | Circle, red | Solid border, "⊤" label |
| Propagator | Diamond/square, blue | Label with kind ("unify", "trait", etc.) |
| Edge (input) | Arrow → propagator | Thin line |
| Edge (output) | Arrow → cell | Thick line |
| Firing | Edge flash | Brief animation on the output edge |
| ATMS assumption | Triangle, yellow | Assumption name label |

### 4d: Interaction

- **Click cell** → show detail panel (value, typing context, source) + highlight source location
- **Click propagator** → show inputs/outputs, kind, firing count
- **Hover** → tooltip with summary
- **Click source location** → highlight corresponding cell(s) in graph
- **Filter** → toggle cell domains (type metas, mult metas, session metas, registries)
- **Layout** → switch between force-directed and hierarchical

### 4e: Bundled Dependencies

Cytoscape.js (~400KB minified) bundled into the extension's `out/` directory.
Loaded in the webview via a local URI.

**Files**: New `editors/vscode-prologos/src/propagator-view.ts`, `editors/vscode-prologos/src/propagator-view.css`
**Modified**: `package.json` (command, panel), `extension.ts` (registration)
**Dependencies**: Phase 3 (LSP endpoint for data), Cytoscape.js (bundled)
**Tests**: Manual visual testing + snapshot tests for serialization

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
