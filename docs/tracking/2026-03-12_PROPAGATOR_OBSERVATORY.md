# Propagator Network Observatory — Design Document

**Date**: 2026-03-12
**Status**: Stage 2-3 (Architecture Design)
**Builds on**: Propagator Visualization (`2026-03-12_PROPAGATOR_VISUALIZATION_DESIGN.md`), Design Principles (Propagator-First Infrastructure, First-Class by Default, Correct by Construction)

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| **0** | **Core data types + capture protocol** | ⬜ | `prop-observatory.rkt` |
| **1** | **Observatory serialization** | ⬜ | `observatory-serialize.rkt` |
| **2** | **Session type integration** | ⬜ | `session-propagators.rkt` |
| **3** | **Capability inference integration** | ⬜ | `capability-inference.rkt` |
| **4** | **Type inference integration** | ⬜ | `metavar-store.rkt` / `driver.rkt` |
| **5** | **LSP observatory endpoint** | ⬜ | `lsp/server.rkt` |
| **6** | **VS Code multi-network UI** | ⬜ | `propagatorView.ts` |
| **7** | **Cross-network links** | ⬜ | All integration points |

---

## 1. Problem

Prologos uses propagator networks in at least five subsystems — type inference, session type checking, capability inference, narrowing, and ATMS — but each subsystem creates and consumes its networks in isolation. The existing Propagator View (Phases 0–4c) can visualize one network at a time, specifically the shared elab-network from type inference. There is no mechanism to:

1. **Capture** any propagator network at its quiescence boundary, regardless of subsystem
2. **Correlate** networks across subsystems (e.g., a session type cell's value that corresponds to a type inference metavariable)
3. **Serialize** a uniform representation consumable by multiple tools (VS Code visualizer, CLI debugger, REPL inspector, test harness, CI diagnostic reporter)
4. **Observe** the full constellation of networks produced during elaboration of a single program

This is an infrastructure gap. As more subsystems move to propagator-first architecture, the need for general observability grows superlinearly — every new subsystem potentially interacts with every existing one, and the debugging surface grows as N².

## 2. Vision

**Every propagator network in Prologos is observable.** A single `observatory` value captures every network produced during elaboration, preserves per-cell metadata and cross-network references, and serializes to a stable JSON schema. Tools consume the observatory data — they don't know or care which subsystem produced it.

The observatory is **data-oriented**: it captures immutable snapshots of network state at well-defined points (quiescence boundaries). It does not instrument the runtime or modify propagation semantics. The trace IS the execution history — not a lossy summary of it.

The observatory is **zero-cost when off**: `(current-observatory)` = `#f` means no allocation, no capture, no overhead. Same pattern as the existing `current-bsp-observer` parameter.

## 3. Design Principles Applied

### 3.1 Propagator-First Infrastructure

The observatory is itself propagator-network-aware. It doesn't bolt observability onto a system that happens to use propagators — it is designed around the specific structure of propagator networks: cells with lattice values, propagators as edges, quiescence as the natural capture boundary, BSP rounds as the unit of state evolution.

### 3.2 First-Class by Default

Networks, captures, and the observatory itself are **values** — immutable, inspectable, serializable, composable. A `net-capture` can be stored in a test assertion, printed to JSON, diffed against another capture, or passed to a visualization backend. There is no observer/callback-tangled state that can only be consumed in the moment it's produced.

### 3.3 Correct by Construction

The capture happens at quiescence — the point where the network has reached its fixed point and all cell values are self-consistent. The capture is append-only (captures accumulate in the observatory, never mutated). The serialization is a pure function from `observatory` to JSON. There are no partial captures, no race conditions, no inconsistent intermediate states to debug.

### 3.4 The Most Generalizable Interface

The observatory is subsystem-agnostic. A `cell-meta` struct replaces the type-inference-specific `elab-cell-info`. Any subsystem that calls `run-to-quiescence` can participate with a 3-line integration. The JSON schema is tool-agnostic — a CLI debugger, a REPL inspector, a CI reporter, and the VS Code visualizer all consume the same format.

### 3.5 Decomplection

Network **capture** (what happened) is decoupled from network **display** (how it looks). Cell **metadata** (what a cell means) is decoupled from cell **value** (what it holds). Cross-network **links** (what relates) are decoupled from network **topology** (what connects within). Subsystem **identity** is a label, not a type hierarchy.

### 3.6 Zero-Cost Abstraction

The `current-observatory` parameter defaults to `#f`. When off:
- No `cell-meta` structs are allocated
- No `net-capture` snapshots are taken
- `capture-network` is a thin wrapper that calls `run-to-quiescence` directly
- The only overhead is a single `(current-observatory)` parameter lookup per quiescence call

This matches the existing `current-bsp-observer` pattern that has been in production since Phase 1 with zero measurable overhead.

## 4. Subsystem Inventory

Every subsystem that creates or uses a propagator network is a potential observatory participant. The following inventory maps the current landscape:

| Subsystem | Network Ownership | Typical Cell Count | Typical Prop Count | Lattice Domain | Lifecycle | Capture Point |
|-----------|------------------|--------------------|--------------------|----------------|-----------|---------------|
| **Type inference** | Shared (`elab-network` in `metavar-store.rkt`) | 50–500 per command | 0–50 (see §4.1) | Types, mults | Per-command (reset at `reset-meta-store!`) | Command boundary |
| **Session types** | Local per `defproc` (`session-propagators.rkt`) | 2–10 per process | 4–8 | Session protocols | Per process check | `run-to-quiescence` at line 572 |
| **Capability inference** | Local per module (`capability-inference.rkt`) | 1 per function | 1 per call edge | Capability sets | Per module | `run-to-quiescence` at line 295 |
| **Narrowing** | Caller-provided (`narrowing.rkt`) | Term cells | Definitional tree props | Term lattice | Per narrowing query | Caller's quiescence |
| **ATMS** (future) | Local per query | Assumption cells | Justification props | Truth values | Per query | TBD |
| **Effects** (future) | Shared or local | Effect variable cells | Effect propagators | Effect rows | TBD | TBD |

### 4.1 Current Edge Production in the Elab-Network

Investigation (2026-03-12) revealed that the shared elab-network typically produces **0 propagator edges** during standard elaboration. Root causes:

1. **One-sided constraints**: The elaborator grounds one side of a unification before posting, so `extract-shallow-meta-ids` returns empty on that side, and no cross-product propagator is created
2. **Fast path**: `elab-add-unify-constraint` short-circuits when both cells are ground (line 193–198)
3. **Session types use `type-proc`**: Pattern-matching checker, not propagator-based
4. **Capability/narrowing**: Only exercised in specific code patterns

This means the elab-network capture (Phase 4) will often show cells but no edges — which is accurate and useful (it shows the metavariable landscape), but edges will appear primarily in session and capability captures.

## 5. Architecture

### 5.1 Core Data Types

```
┌─────────────────────────────────────────────────────┐
│ observatory                                          │
│   captures: [net-capture ...]     (append-only)      │
│   links: [cross-net-link ...]     (append-only)      │
│   metadata: hasheq                (session context)  │
└─────────────────────────────────────────────────────┘
         │ contains
         ▼
┌─────────────────────────────────────────────────────┐
│ net-capture                                          │
│   id: symbol (gensym)                                │
│   subsystem: symbol ('type-inference, 'session, ...) │
│   label: string ("session:greeter")                  │
│   network: prop-network (immutable snapshot)         │
│   cell-metas: champ (cell-id → cell-meta)            │
│   trace: prop-trace | #f                             │
│   timestamp-ms: fixnum                               │
│   parent-id: symbol | #f (for sub-networks)          │
└─────────────────────────────────────────────────────┘
         │ per cell
         ▼
┌─────────────────────────────────────────────────────┐
│ cell-meta                                            │
│   subsystem: symbol                                  │
│   label: string ("meta-42", "cap:process-csv")       │
│   source-loc: srcloc | #f                            │
│   domain: symbol ('type, 'session-protocol, ...)     │
│   extra: hasheq (subsystem-specific data)            │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ cross-net-link                                       │
│   from-capture-id: symbol                            │
│   from-cell-id: cell-id                              │
│   to-capture-id: symbol                              │
│   to-cell-id: cell-id                                │
│   relation: symbol ('type-of, 'constrains, ...)      │
└─────────────────────────────────────────────────────┘
```

**`cell-meta`** is the subsystem-agnostic replacement for `elab-cell-info`. Where `elab-cell-info` carries `ctx`, `type`, and `source` specific to type inference, `cell-meta` carries generic metadata suitable for any subsystem. Subsystem-specific data goes in the `extra` hasheq.

**`net-capture`** bundles an immutable `prop-network` snapshot with its cell metadata and optional BSP trace. The `parent-id` field supports hierarchical captures (e.g., narrowing sub-networks spawned within a type inference command).

**`cross-net-link`** represents a semantic relationship between cells in different networks. These are registered explicitly by integration code, not inferred — the observatory doesn't guess what relates to what.

**`observatory`** is the session-level container. One observatory per elaboration run (or per LSP document update). Contains all captures and all cross-network links produced during that run.

### 5.2 Capture Protocol

The capture protocol is the central mechanism. It wraps `run-to-quiescence` to snapshot the network at its fixed point.

```
         ┌───────────────┐
         │ Subsystem code │  (session-propagators.rkt, capability-inference.rkt, ...)
         └───────┬───────┘
                 │ calls
                 ▼
         ┌───────────────────────────┐
         │ capture-network            │
         │   net, subsystem, label,   │
         │   cell-metas               │
         └───────┬───────────────────┘
                 │
    ┌────────────┼────────────────┐
    │ observatory = #f            │ observatory ≠ #f
    │                             │
    ▼                             ▼
  run-to-quiescence          install BSP observer (if trace? = #t)
  return net                 run-to-quiescence
                             build net-capture
                             observatory-register!
                             return net
```

**Key properties:**
- **Transparent**: callers get the same `prop-network` back regardless of whether the observatory is on or off
- **Non-invasive**: no modification to `run-to-quiescence` itself
- **Composable with existing tracing**: `capture-network` respects and extends `current-bsp-observer`, it doesn't replace it

### 5.3 Observatory Lifecycle

```
  ┌─────────────────────────────────────────────────┐
  │ LSP: elaborate-and-publish-diagnostics!          │
  │                                                  │
  │  1. (define obs (make-observatory file-uri))     │
  │  2. (parameterize ([current-observatory obs])    │
  │       (process-file ...))                        │
  │  3. (set! uri->observatory obs)  ;; store        │
  │                                                  │
  │  During (process-file ...):                      │
  │    - Type inference: elab-network captured        │
  │    - Session check: local net captured            │
  │    - Capability inference: local net captured     │
  │    - Cross-links registered                      │
  └─────────────────────────────────────────────────┘
```

The observatory is created at the start of an elaboration, installed via parameter, and accumulated into during elaboration. After elaboration, the observatory is stored for retrieval by the LSP handler.

### 5.4 Mutable vs Immutable

The observatory's internal lists (captures, links) must be mutable during accumulation — captures arrive as subsystems reach quiescence during elaboration. After elaboration, the observatory is effectively frozen. This matches the pattern of the `elab-network` itself: mutable during elaboration, immutable after.

Implementation: box-of-list for captures and links during accumulation, frozen to list on read.

## 6. Serialization Schema

The observatory serializes to a JSON schema that extends the existing `prop-trace` schema (version 1, from `trace-serialize.rkt`). The new schema is version 2.

```json
{
  "version": 2,
  "observatory": {
    "captures": [
      {
        "id": "cap1234",
        "subsystem": "session",
        "label": "session:greeter",
        "parentId": null,
        "timestampMs": 1710000000,
        "network": {
          "cells": [
            {
              "id": 0,
              "value": "!String",
              "label": "step-0",
              "subsystem": "session",
              "domain": "session-protocol",
              "sourceLoc": {"line": 8, "col": 0, "file": "greeter.prologos"}
            }
          ],
          "propagators": [
            {"id": 0, "name": "session-send", "inputs": [0], "outputs": [1]}
          ],
          "stats": {
            "totalCells": 4,
            "totalPropagators": 3,
            "contradiction": null
          }
        },
        "trace": null
      }
    ],
    "links": [
      {
        "fromCapture": "cap1234",
        "fromCell": 0,
        "toCapture": "cap5678",
        "toCell": 3,
        "relation": "type-of"
      }
    ],
    "metadata": {
      "file": "examples/greeter.prologos",
      "totalCaptures": 3,
      "subsystems": ["type-inference", "session", "capability"],
      "elapsedMs": 42
    }
  }
}
```

**Backward compatibility**: The existing `$/prologos/propagatorSnapshot` LSP method continues to work. When the observatory is available, it returns the first capture's trace data in the version 1 format. This keeps the existing VS Code panel working during the transition.

**Reuse**: `serialize-network-topology` and `serialize-prop-trace` from `trace-serialize.rkt` are called inside `serialize-net-capture`. Cell metadata is merged into the cell JSON objects by the observatory serializer.

## 7. Integration Points

Each integration is a small, localized change — typically 3–5 lines wrapping an existing `run-to-quiescence` call with `capture-network`.

### 7.1 Session Type Checking (`session-propagators.rkt:572`)

```racket
;; Before:
(define net3 (run-to-quiescence net2))

;; After:
(define net3
  (capture-network net2 'session
    (format "session:~a" (object-name proc))
    (build-session-cell-metas net2 channel-cells trace)))
```

`build-session-cell-metas` constructs a CHAMP mapping `cell-id → cell-meta` from the channel-cells and session-op trace. Each cell gets domain `'session-protocol`, a label like `"self"` or `"chan:x"`, and the process's source location.

### 7.2 Capability Inference (`capability-inference.rkt:295`)

```racket
;; Before:
(define net-final (run-to-quiescence net1))

;; After:
(define net-final
  (capture-network net1 'capability
    "capability:module"
    (build-capability-cell-metas name->cid env)))
```

`build-capability-cell-metas` constructs metadata from `name->cid`. Each cell gets domain `'capability-set`, a label of the function name, and the function's source location.

### 7.3 Type Inference Elab-Network

The elab-network is shared and long-lived (per command). It doesn't call `run-to-quiescence` — constraints are resolved inline during elaboration. The capture point is the **command boundary** in `driver.rkt`, just before `reset-meta-store!` destroys the current network.

```racket
;; In process-command, after elaboration, before reset:
(when (current-observatory)
  (define elab-net (unbox (current-prop-net-box)))
  (observatory-register-capture!
    (current-observatory)
    (net-capture (gensym 'cap) 'type-inference
                 (format "elab:~a" (abbreviate-form cmd))
                 (elab-network-prop-net elab-net)
                 (elab-cell-info-champ->cell-metas elab-net)
                 (current-captured-trace)
                 (current-inexact-milliseconds)
                 #f)))
```

`elab-cell-info-champ->cell-metas` adapts the existing `elab-cell-info` structs into generic `cell-meta` structs.

### 7.4 Cross-Network Links

Registered explicitly at integration boundaries. For example, when a session type check references a metavariable from the elab-network:

```racket
(when (current-observatory)
  (observatory-register-link!
    (current-observatory)
    (cross-net-link session-capture-id session-cell-id
                    elab-capture-id meta-cell-id
                    'type-of)))
```

This is Phase 7 work — it requires the session checker to know the elab-network's capture ID, which means the capture ID must be threaded through or stored in the observatory for lookup.

## 8. LSP Protocol

### 8.1 New Method: `$/prologos/observatorySnapshot`

**Request**: `{ "uri": "file:///path/to/file.prologos" }`

**Response**: Full observatory JSON (schema version 2, see §6)

The handler retrieves the stored observatory for the given URI and serializes it. If no observatory exists (file not yet elaborated, or observatory was off), returns an empty observatory.

### 8.2 Backward Compatibility

`$/prologos/propagatorSnapshot` continues to work. It extracts the first type-inference capture from the observatory and returns its trace in version 1 format.

### 8.3 Observatory Installation

In `elaborate-and-publish-diagnostics!`:

```racket
(define obs (make-observatory uri))
(parameterize ([current-observatory obs])
  ;; existing elaboration code
  (process-file ...))
(hash-set! uri->observatory uri obs)
```

This is 3 lines of change in `server.rkt`.

## 9. VS Code UI

### 9.1 Multi-Network Selector

The existing `propagatorView.ts` WebviewPanel gains a **network selector** at the top:

```
┌──────────────────────────────────────────────────┐
│ [▼ elab:def-factorial] [session:factorial] [cap]  │  ← dropdown or tabs
│                                                    │
│  ┌──────────────────────────────────────────────┐ │
│  │          (existing D3 force graph)            │ │
│  │                                               │ │
│  │    ●──────●──────●                            │ │
│  │    │      │      │                            │ │
│  │    ●──────●      ●                            │ │
│  │                                               │ │
│  └──────────────────────────────────────────────┘ │
│                                                    │
│  Legend: ● type-inference  ● session  ● capability │
│  Filter: [✓] type  [✓] session  [✓] capability     │
└──────────────────────────────────────────────────┘
```

- Each capture in the observatory becomes a selectable entry
- Selecting a capture renders its network in the existing D3 graph
- Subsystem-specific colors apply (extending the existing Phase 4c color scheme)
- Filter checkboxes let users show/hide by subsystem

### 9.2 Cross-Network Links

When multiple captures are visible (e.g., side-by-side or overlaid):
- Cross-network links render as **dashed lines** between cells in different captures
- Link labels show the relation type ("type-of", "constrains")
- This is Phase 7 UI work and can be deferred

### 9.3 Capture Summary

A collapsible summary panel shows:
- Total captures, grouped by subsystem
- Cell/propagator/contradiction counts per capture
- Timestamp ordering (elaboration sequence)
- Quick-filter by subsystem

## 10. Testing Strategy

### 10.1 Unit Tests (`test-observatory-01.rkt`)

- `net-capture` construction and field access
- `cell-meta` construction
- `observatory` accumulation (register 3 captures, verify order)
- `cross-net-link` construction
- `capture-network` with observatory=#f (passthrough)
- `capture-network` with observatory (capture registered)
- `capture-network` with trace?=#t (BSP observer installed)

### 10.2 Serialization Tests (`test-observatory-02.rkt`)

- `serialize-cell-meta` → JSON round-trip
- `serialize-net-capture` → JSON with network topology embedded
- `serialize-observatory` → full JSON schema version 2
- `serialize-cross-net-link` → JSON
- Backward compat: version 1 extraction from observatory

### 10.3 Integration Tests

- `process-string` a `defproc` with `current-observatory` → verify session capture appears
- `run-capability-inference` with `current-observatory` → verify capability capture
- `process-file` on a `.prologos` file with mixed forms → verify multi-capture observatory
- Verify existing tests pass unmodified (observatory = #f by default)

## 11. File Inventory

| File | Action | Purpose |
|------|--------|---------|
| `racket/prologos/prop-observatory.rkt` | **NEW** | Core structs, `current-observatory`, `capture-network`, `make-observatory`, `observatory-register-capture!`, `observatory-register-link!` |
| `racket/prologos/observatory-serialize.rkt` | **NEW** | `serialize-observatory`, `serialize-net-capture`, `serialize-cell-meta`, `serialize-cross-net-link` |
| `racket/prologos/session-propagators.rkt` | Modify | Wrap `run-to-quiescence` with `capture-network`, add `build-session-cell-metas` |
| `racket/prologos/capability-inference.rkt` | Modify | Wrap `run-to-quiescence` with `capture-network`, add `build-capability-cell-metas` |
| `racket/prologos/metavar-store.rkt` or `driver.rkt` | Modify | Capture elab-network at command boundary, add `elab-cell-info-champ->cell-metas` |
| `racket/prologos/lsp/server.rkt` | Modify | `$/prologos/observatorySnapshot` handler, `current-observatory` installation |
| `editors/vscode-prologos/src/propagatorView.ts` | Modify | Multi-network selector UI, subsystem filter |
| `racket/prologos/tests/test-observatory-01.rkt` | **NEW** | Unit tests for capture protocol |
| `racket/prologos/tests/test-observatory-02.rkt` | **NEW** | Serialization tests |

## 12. Reuse Points

- **`propagator.rkt:139–190`**: `cell-diff`, `bsp-round`, `prop-trace`, `current-bsp-observer`, `make-trace-accumulator` — used by `capture-network` for trace capture
- **`trace-serialize.rkt`**: `serialize-network-topology`, `serialize-prop-trace` — called by `serialize-net-capture` for the network and trace portions
- **`elaborator-network.rkt`**: `elab-cell-info` struct — adapted to `cell-meta` via `elab-cell-info-champ->cell-metas`
- **`propagatorView.ts`**: Existing D3 force graph — extended with network selector, not rewritten
- **`champ.rkt`**: CHAMP maps for `cell-metas` field in `net-capture` (same structure as `prop-network` uses)

## 13. Future Extensions

- **Narrowing integration**: When narrowing uses caller-provided networks, the caller registers the capture. Requires `parent-id` threading.
- **ATMS integration**: ATMS-backed cells with assumption/retraction events. The `atms-event` hierarchy in `propagator.rkt` is already designed for this.
- **Effect inference**: When effect propagators exist, they participate via the same `capture-network` protocol.
- **CLI debugger**: Reads observatory JSON from file or pipe, renders network topology as ASCII art or table.
- **REPL inspector**: `(observatory-inspect)` command shows captures in the REPL.
- **CI reporter**: Captures observatory in test mode, reports anomalies (unexpected contradictions, unusually large networks).
- **Diffing**: Compare two observatory snapshots (e.g., before/after a code change) to see what changed in the network topology.
- **Streaming**: For long-running elaborations, stream captures as they're produced (via observatory observer callback) rather than accumulating.

## 14. Design Decisions and Trade-offs

### 14.1 Why `cell-meta` instead of extending `elab-cell-info`?

`elab-cell-info` is type-inference-specific: it carries `ctx` (typing context) and `type` (expected type), which have no meaning for session or capability cells. Making it generic would either require stuffing irrelevant fields with `#f` or creating a hierarchy. A separate, flat `cell-meta` struct with a subsystem-agnostic schema and an `extra` hasheq for subsystem-specific data is cleaner and doesn't pollute the existing elab-network code.

### 14.2 Why gensym for capture IDs?

Captures need unique IDs for cross-network linking. Alternatives:
- **Counter**: Requires threading a counter through all subsystems. Fragile.
- **Content hash**: Expensive (networks are large). Over-engineered for an in-session identifier.
- **Gensym**: Cheap, unique within a session, good enough for linking during one elaboration. Not suitable for cross-session persistence, but that's not a current requirement.

### 14.3 Why mutable accumulation in the observatory?

Captures arrive from different subsystems at different times during elaboration. A purely functional approach would require threading the observatory through every subsystem call — invasive and fragile. A parameter + mutable-box approach (like `current-meta-store`) is the established pattern in the codebase and matches the lifecycle (build during elaboration, freeze after).

### 14.4 Why not instrument `run-to-quiescence` directly?

Instrumenting `run-to-quiescence` would automatically capture every network. But:
- Not every `run-to-quiescence` call is worth capturing (internal retries, speculative attempts)
- Cell metadata is subsystem-specific — `run-to-quiescence` doesn't know what cells mean
- The label and parent-id require caller context

The `capture-network` wrapper gives callers explicit control over what is captured and how it's labeled, at the cost of 3 lines per integration point.

### 14.5 Why append-only captures?

Captures are snapshots at quiescence boundaries. They are inherently historical — you want to see what happened, not what's happening now. Append-only is the natural data model. It also makes the observatory trivially serializable (no cycles, no mutable references between captures).
