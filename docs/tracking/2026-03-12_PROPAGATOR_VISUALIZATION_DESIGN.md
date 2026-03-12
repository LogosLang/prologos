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
Snapshots are zero-cost references. This makes trace capture and replay fundamentally simple —
just keep a list of network snapshots at each step.

## Critical Path

```
Phase 1 (Trace Capture)
    ↓
Phase 2 (Serialization)
    ↓
Phase 3 (LSP Endpoint) ← depends on Phase 1 + 2
    ↓
Phase 4 (VS Code Panel) ← depends on Phase 3
    ↓
Phase 5 (Step-Through)  ← depends on Phase 4 + trace data from Phase 1
    ↓
Phase 6 (Polish)        ← depends on Phase 4 + 5
```

Phases 1 and 2 can be developed/tested independently of the VS Code extension.
Phase 4 can start with static snapshot rendering while Phase 5 adds replay.

## Phase 1: Trace Capture

**Goal**: Record a timestamped event log during elaboration: cell creations, cell writes,
propagator registrations, propagator firings, contradictions, and ATMS events.

### 1a: Event Structs

Define trace event types in a new `trace.rkt`:

```racket
(struct trace-event (step-number kind data) #:transparent)

;; kind is one of:
;; 'cell-new       data: (hasheq 'cell-id N 'merge-kind symbol 'source string)
;; 'cell-write     data: (hasheq 'cell-id N 'old-value any 'new-value any 'changed? bool)
;; 'prop-new       data: (hasheq 'prop-id N 'inputs (listof N) 'outputs (listof N) 'kind symbol)
;; 'prop-fire      data: (hasheq 'prop-id N 'writes (listof N))
;; 'contradiction  data: (hasheq 'cell-id N 'value any)
;; 'atms-assume    data: (hasheq 'assumption-id N 'name symbol)
;; 'atms-nogood    data: (hasheq 'assumption-ids (listof N))
;; 'quiescence     data: (hasheq 'steps N 'unsolved N 'contradicted N)
```

### 1b: Instrumented Network Operations

Wrap `net-cell-write`, `net-add-propagator`, and `run-to-quiescence` with optional
trace capture controlled by a parameter:

```racket
(define current-trace-log (make-parameter #f))  ;; #f = off, box of list = on

(define (trace-emit! event)
  (define log (current-trace-log))
  (when log
    (set-box! log (cons event (unbox log)))))
```

The parameter is `#f` by default — zero overhead in normal operation.
Only the LSP (or test harness) sets it to capture traces.

### 1c: Snapshot Bookmarks

Since the network is persistent, capture a reference to the network state at each
quiescence point (or at each step in detailed mode):

```racket
(struct trace-snapshot (step-number network) #:transparent)
```

These are O(1) to create (just a pointer to the CHAMP root). The detailed step-by-step
snapshots enable replay in Phase 5.

**Files**: New `racket/prologos/trace.rkt`
**Modifications**: `propagator.rkt` (instrumented wrappers), `elaborator-network.rkt` (elab-solve trace hooks)
**Tests**: ~10 (trace capture on small networks, verify event ordering)
**Dependencies**: None (purely additive)

## Phase 2: Network Serialization

**Goal**: Serialize a network snapshot + trace log to JSON for consumption by LSP/VS Code.

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

Extend `elaborate-and-publish-diagnostics!` to optionally capture the elaboration network
(not just the global-env and spec-store):

```racket
;; In elaborate-and-publish-diagnostics!:
(define captured-elab-network #f)
(define captured-trace-log #f)

(parameterize ([current-trace-log (box '())]
               ...)
  (process-file tmp-path)
  (set! captured-elab-network (current-elab-network))
  (set! captured-trace-log (reverse (unbox (current-trace-log)))))
```

Store in lsp-state:
```racket
(struct lsp-state
  (...
   elab-networks     ;; hash: uri → elab-network (snapshot after elaboration)
   trace-logs        ;; hash: uri → (listof trace-event)
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

## Phase 5: Step-Through Replay

**Goal**: Replay the elaboration trace step-by-step, showing cells narrowing over time.

### 5a: Timeline Control

Add a timeline control bar below the graph:
- Play/pause button
- Step forward/backward
- Speed control
- Step counter: "Step 14 / 87"
- Jump to contradiction (if any)

### 5b: Differential Rendering

On each step, compute the diff from the previous state:
- Cells that changed value → flash animation, update label
- Propagator that fired → highlight edges
- New cells/propagators → fade in
- Contradiction → red pulse on the cell

Since network snapshots are persistent, the diff is computed by comparing
cell values between consecutive snapshot references.

### 5c: Trace Event Annotations

Show the current trace event as a status bar annotation:
- `"Cell #3 wrote: Int → (Int → Int)"` (narrowing)
- `"Propagator #7 fired (unify #3 ↔ #5)"`
- `"Contradiction at Cell #12"` (red)
- `"Quiescence reached: 8 solved, 0 unsolved"` (green)

### 5d: Bookmarked Snapshots

Allow the user to bookmark specific steps. Useful for comparing "before and after"
a particular propagation. Since snapshots are O(1), this is trivially cheap.

**Files**: Modified `propagator-view.ts` (timeline UI + diff rendering)
**Dependencies**: Phase 4 (graph panel), Phase 1 (trace data)

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

| Approach | Pros | Cons | Recommendation |
|----------|------|------|----------------|
| Static snapshot only | Simple, no trace overhead | No animation, less educational | Start here (Phase 4a-d) |
| Full step-by-step trace | Maximum insight | Memory for snapshots, UI complexity | Phase 5 (additive) |
| Live incremental (Tier 3+) | Real-time as user types | Requires incremental elaboration | Future (when LSP Tier 3+ lands) |
| Separate Electron app | No VS Code coupling | Separate install, context switching | Not recommended |
| Web-based (localhost) | Cross-editor | Deployment complexity | Not recommended for Phase 0 |

## Principle Alignment

- **Invisible infrastructure, visible behavior**: The propagator network is infrastructure;
  the visualization makes its behavior visible without changing it.
- **Homoiconicity**: The network is data; the visualization is a view of that data.
- **Completeness over deferral**: Each phase is self-contained and useful on its own.
  Phase 4 (static graph) is valuable without Phase 5 (replay).
- **The tool is the documentation**: The visualization explains propagators better than
  any paper. This aligns with the project's educational mission.
