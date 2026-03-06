# IO Library Implementation Design

**Status**: Implementation Phase — IO-A/B/C/D complete, IO-E next
**Predecessor**: `docs/tracking/2026-03-05_IO_LIBRARY_DESIGN_V2.md` (Phase I — API research + gap analysis)
**Template**: Follows the format of `docs/tracking/2026-03-03_SESSION_TYPE_DESIGN.md`
**Date**: 2026-03-05

---

## Progress Tracker

| Phase | Sub-phase | Status | Commit | Notes |
|-------|-----------|--------|--------|-------|
| IO-A | A1: Opaque type marshalling | ✅ | `8a2f5d0` | 13 tests; `expr-opaque` AST node + marshalling in `foreign.rkt`; pass-throughs in substitution/zonk/reduction/pretty-print |
| IO-A | A2: Path + IOError types | ✅ | `1a6d926` | 14 tests; `path.prologos` (3 fns via qualified `str::append`), `io-error.prologos` (6 ctors); deferred `path-parent`/`path-extension`/`path-file-name` (need `substring`/`index-of`) |
| IO-A | A3: IO capability extensions | ✅ | `da67f31` | 18 tests; +`AppendCap`, +`StatCap`, +`IOCap`; hierarchy `FsCap/NetCap/StdioCap → IOCap → SysCap`; used `capability`+`subtype` declarations (pragmatic, not D17 union types — see note below) |
| IO-B | B1: IO state lattice | ✅ | `2f1ebbf` | 5 tests; `io-bot/io-top/io-opening/io-open/io-closed` + merge function in `io-bridge.rkt` |
| IO-B | B2: IO bridge propagator | ✅ | `1b9b91a` | 5 tests; side-effecting fire-fn, `io-bridge-open-file`, `make-io-bridge-cell`; local session predicates (avoids modifying session-runtime.rkt) |
| IO-B | B3: FFI bridge to Racket | ✅ | `d4934d4` | 5 tests; `io-ffi.rkt` with 12-entry registry + wrapper fns; `io-close-port` generic close (Racket has no `close-port`) |
| IO-C | C1: `proc-open` runtime | ✅ | `5b14a07` | `rt-new-io-channel` (5 cells: 4 standard + 1 IO state); `proc-open` match arm in `compile-live-process`; broke io-bridge↔session-runtime circular dep via local `io-msg-bot?` |
| IO-C | C2: Integration tests | ✅ | `7cde920` | 11 tests in 3 groups: channel creation, direct IO channel read/write/error/close, compile-live-process integration |
| IO-D | D1: File IO functions | ✅ | `cc1c1e1` | 8 tests; `read-file`, `write-file`, `append-file` via `foreign racket "io-ffi.rkt"`; fixed `handle-foreign-decl` module path resolution + auto-export bug |
| IO-D | D2: Console IO functions | ✅ | `8f5235a` | 4 tests; `print`, `println`, `read-ln` in io.prologos; print/println added to prelude |
| IO-D | D3: `with-open` macro | ⏳ | | DEFERRED → IO-E (needs session ops) |
| IO-D | D4: Filesystem query functions | ✅ | `832cd5e` | 7 tests; `exists?`, `file?`, `dir?` in `prologos::io::fs`; `io-ffi-path-exists` wrapper (Racket `file-exists?` excludes dirs); `list-dir` deferred (needs List marshalling) |
| IO-D | D5: `main` powerbox mechanism | ⏳ | | DEFERRED → IO-H (needs cap inference) |
| IO-E | E1: Protocol definitions | | | `FileRead`/`FileWrite`/`FileRW` |
| IO-E | E2: Session-based file IO | | | IO service processes |
| IO-E | E3: Protocol composition tests | | | IO protocols compose with user protocols |
| IO-F | F1: Linear handle type | | | `Handle :1`, fio functions |
| IO-F | F2: fio bracket pattern | | | `fio-with-open` |
| IO-G | G1: CSV parser | | | RFC 4180 parsing |
| IO-G | G2: CSV file functions | | | `read-csv`, `write-csv` |
| IO-H | H1: Cap inference pipeline | | | Wire into `driver.rkt` |
| IO-I | I1: `cap-set` with type exprs | | | Extend cap-set for applied caps |
| IO-I | I2: `extract-capability-requirements` for `expr-app` | | | `FileCap "/data"` extraction |
| IO-I | I3: Cap-type bridge for applied caps | | | α/γ for `expr-app` cap types |
| IO-I | I4: Path-indexed cap tests | | | End-to-end dependent caps |
| IO-J | J1: Elaborator binder scope | | | Extend gamma for dep session continuation |
| IO-J | J2: Runtime dep send/recv | | | `sess-dsend`/`sess-drecv` predicates + `substS` |
| IO-J | J3: Grammar + E2E tests | | | Update grammar.ebnf; dep session E2E tests |

### Implementation Notes

**IO-A3 vs D17 (Composite Capability Model)**: D17 specifies composite capabilities as
union types (`type FsCap = ReadCap | WriteCap | AppendCap | StatCap`), but IO-A3 used
`capability` + `subtype` declarations instead. This pragmatic approach works because the
capability inference system operates on symbol registries (not type-level constructs), and
transitive closure of `subtype` declarations produces the same subtyping relationships
(`ReadCap <: FsCap <: IOCap <: SysCap`). Revisiting with true union type syntax remains
possible but is not blocking — the subtype hierarchy is semantically correct.

**IO-A2 Deferred Functions**: `path-parent`, `path-extension`, and `path-file-name` are
deferred because they require `substring` and `index-of` string operations not yet available
in the Prologos standard library. Added to DEFERRED.md.

**`spec` syntax discovery**: `.prologos` spec declarations use NO colon after the function
name: `spec path String -> Path`, not `spec path : String -> Path`. This was undocumented
in the implementation design but is consistent across the entire codebase.

### Phase Dependency Graph

```
IO-A1 (Opaque FFI) ──┐
IO-A2 (Path/IOError)  ├── IO-B (IO Bridge) ── IO-C (Boundary Ops) ──┐
IO-A3 (IO Caps) ─────┘                                              │
                                                                     ├── IO-D (File IO + Console + with-open + FS Queries + main) ──┐
                                                                     │                                                              │
                                                                     │   ┌── IO-E (Session Protocols + Composition Tests)           │
                                                                     │   ├── IO-F (Functional IO)                                   │
                                                                     └───┤   ├── IO-G (CSV)                                        │
                                                                         └── IO-H (Cap Inference) ── IO-I (Dependent Caps)         │

IO-J (Dep Send/Recv) ── no IO dependencies; can start immediately ── IO-G upgrade (schema-typed CSV)
```

---

## Table of Contents

1. [Document Purpose](#1-document-purpose)
2. [Design Decisions Summary](#2-design-decisions-summary)
3. [Prerequisites: What's Already Built](#3-prerequisites)
4. [IO Capability Types](#4-io-capability-types)
5. [Opaque Type Marshalling](#5-opaque-type-marshalling)
6. [IO Bridge Architecture](#6-io-bridge-architecture)
7. [Boundary Operations Runtime](#7-boundary-operations-runtime)
8. [Dependent Send/Receive](#8-dependent-sendreceive)
9. [Path and IOError Types](#9-path-and-ioerror-types)
10. [FFI Bridge Layer](#10-ffi-bridge-layer)
11. [Convenience Functions and `with-open`](#11-convenience-functions-and-with-open)
12. [Filesystem Query Functions](#12-filesystem-query-functions)
13. [`main` as Powerbox](#13-main-as-powerbox)
14. [IO Session Protocols](#14-io-session-protocols)
15. [Functional IO (`fio`) Module](#15-functional-io-fio-module)
16. [Console IO](#16-console-io)
17. [CSV and Structured Data](#17-csv-and-structured-data)
18. [Capability Inference Pipeline Integration](#18-capability-inference-pipeline-integration)
19. [Dependent Capabilities](#19-dependent-capabilities)
20. [IO Test Infrastructure](#20-io-test-infrastructure)
21. [Target Example Programs](#21-target-example-programs)
22. [Module Structure and Prelude](#22-module-structure-and-prelude)
23. [Phased Implementation Roadmap](#23-phased-implementation-roadmap)
24. [Deferred Features](#24-deferred-features)
25. [References](#25-references)

---

<a id="1-document-purpose"></a>

## 1. Document Purpose

This document bridges the gap between the IO Library Design V2 (Phase I — "what the API
should look like") and implementation ("how to build it"). It specifies:

- **Exact files to create or modify**, with function signatures and struct definitions
- **Phased sub-tasks** with explicit dependencies, so each sub-phase can be implemented
  and committed independently
- **Lattice definitions** for the IO bridge propagator layer
- **Integration points** with existing session runtime, capability inference, and FFI

The Phase I document (`IO_LIBRARY_DESIGN_V2.md`) remains the canonical reference for API
surface, design rationale, and example programs. This document assumes familiarity with it.

### Scope

**In scope** (Phases IO-A through IO-J):
- Opaque FFI marshalling, Path type, IOError type
- IO bridge propagator infrastructure
- Boundary operation runtime (`proc-open`)
- Core file IO convenience functions (`read-file`, `write-file`, etc.)
- File session protocols (`FileRead`, `FileWrite`, etc.)
- Functional IO module (`fio`) with linear handles
- Console IO (`print`, `println`, `read-ln`)
- CSV reading/writing
- Capability inference wired into compilation pipeline
- Dependent capabilities (`FileCap "/data"`) — path-indexed authority proofs
- Dependent send/receive (`!:`/`?:`) — value-dependent session protocols

**Out of scope** (see §24 Deferred):
- Network IO (`connect`/`listen`) — Phase 2+
- Database IO (`db-open`, SQLite) — Phase 2+
- Relational integration (`:source csv` on `defr`) — Phase 3+

---

<a id="2-design-decisions-summary"></a>

## 2. Design Decisions Summary

Decisions resolved in Phase I (IO Library Design V2 §12) plus new implementation decisions:

| # | Decision | Resolution | Source |
|---|----------|-----------|--------|
| D1 | Effect discipline | Fine-grained capability traits (`:0` erased), not `World :1` | V2 §1.2 |
| D2 | Handle model | Hybrid: session channels (`io`) + linear handles (`fio`) | V2 §12.2, resolved as Option C |
| D3 | Module split | `prologos.core.io` (sessions) + `prologos.core.fio` (functional) | V2 §12.2 |
| D4 | Prelude inclusion | `print`, `println`, `read-ln` in prelude; file IO requires `use prologos.core.io` | V2 §12.1 |
| D5 | Binary IO | Deferred to Phase 2; text IO (`String`) first | V2 §12.3 |
| D6 | Error recovery | Errors are `Result` values in protocol; no session short-circuit | V2 §12.4 |
| D7 | IO mocking | Swap IO propagator (server side); session protocol unchanged | V2 §12.5 |
| D8 | `defn main` vs `defproc main` | Support both; `defn` for simple scripts, `defproc` for concurrent | V2 §12.6 |
| D9 | Path type | String wrapper initially (not opaque Racket path) | New |
| D10 | Opaque FFI strategy | `expr-opaque` wrapper struct; pass-through marshalling | New |
| D11 | IO bridge cell | New lattice in propagator network; side-effecting fire-fn | New |
| D12 | Boundary op runtime | Single-endpoint channel + IO bridge propagator (not channel pair) | New |
| D13 | `with-open` pattern | Follows `with-transient` macro pattern; session channel internally | V2 §5.2 |
| D14 | Console IO | Direct FFI to Racket `display`/`read-line`; no session for Tier 1 | New |
| D15 | fio handle threading | Bracket pattern (`fio-with-open`); linear `Handle :1` type | V2 §12.2 |
| D16 | fio internal architecture | `fio` backed by session channels internally (thin wrapper over `io`); not direct FFI | V2 §12.2 ("fio is a thin ergonomic layer over io") |
| D17 | Composite capability model | **Union types** for composite caps (`type FsCap = ReadCap \| WriteCap`); attenuation via natural subtyping (`ReadCap <: FsCap`). Existing `capabilities.prologos` standalone declarations need revision. | CAPABILITY_SECURITY.md §Composite Union; see §4 |
| D18 | Console IO capability | Console IO (`print`, `println`, `read-ln`) **infers `StdioCap`** via standard cap inference; `:0` erased, invisible at Tier 1 but compiler-tracked. `StdoutSession`/`StdinSession` (Tier 3) require explicit `{stdio :0 StdioCap}` | Revised per critique; see §16 |
| D19 | Bracket naming | `with-open` for both `io` and `fio` modules; `with-session` reserved for explicit session channel acquisition | New |
| D20 | `main` as powerbox | Runtime provisions inferred capabilities to `main`; `defn main` desugars to a process internally | V2 §7, §12.6 |
| D21 | IO error codes | `E4xxx` range for IO and capability errors | New; see §24 |

---

<a id="3-prerequisites"></a>

## 3. Prerequisites: What's Already Built

| Component | File(s) | Lines | Status | Used For |
|-----------|---------|-------|--------|----------|
| Session type AST | `sessions.rkt` | 126 | Complete | 13 constructors incl. `sess-dsend`/`sess-drecv` |
| Process AST | `processes.rkt` | 94 | Complete | `proc-open`/`proc-connect`/`proc-listen` defined |
| Session runtime | `session-runtime.rkt` | 673 | Complete (sync) | `compile-live-process`, channel pairs, msg/choice lattices |
| Process typing | `typing-sessions.rkt` | ~280 | Complete | Type-checks boundary ops (cap-gate + session bind) |
| Capability inference | `capability-inference.rkt` | 546 | Complete (flat caps) | Propagator-based transitive cap closure |
| Cap-type bridge | `cap-type-bridge.rkt` | ~200 | Complete | Galois connection (alpha/gamma) between cap and type domains |
| ATMS provenance | `atms.rkt` + `atms-provenance.rkt` | ~400 | Complete | Derivation chains for cap/session errors |
| FFI marshalling | `foreign.rkt` | 164 | Complete (primitives) | Nat/Int/Rat/Bool/Unit/Char/String marshalling |
| Propagator network | `prop-network.rkt` + related | ~600 | Complete | CHAMP-backed, `run-to-quiescence`, lattice cells |
| Expression AST | `syntax.rkt` | 1076 | Complete | All expression types |
| `with-transient` macro | `macros.rkt` L4752-4773 | 22 | Complete | Template for `with-open` |
| Boundary op parsing | `parser.rkt` L5192-5203 | 12 | Complete | `parse-boundary-op` for `open`/`connect`/`listen` |
| Boundary op elaboration | `elaborator.rkt` L3417-3422 | 6 | Complete | `elaborate-boundary-op` |
| WS preprocessing | `macros.rkt` L1194-1236 | 42 | Complete | `expand-open`/`expand-connect`/`expand-listen` |
| Union types | `typing-core.rkt` | — | Complete | Composite capabilities via union |
| Subtype system | `typing-core.rkt` | — | Complete | Transitive subtype closure, coercion registry |
| Schema system | multiple | — | Complete | Field registry, typed construction |
| Capability types | `lib/prologos/core/capabilities.prologos` | 38 | **Needs revision** (IO-A3) | 4 leaf caps (ReadCap, WriteCap, HttpCap, StdioCap) + 3 standalone composite caps (FsCap, NetCap, SysCap) — composites must become union types per D17 |
| Capability parser | `parser.rkt` L2826-2848 | 22 | Complete | `(capability Name)` and `(capability Name (p : Type))` — parameterized form already supported |

### What Exists But Is NOT Implemented at Runtime

| Component | What Exists | What's Missing |
|-----------|-------------|----------------|
| `proc-open` | Struct, parser, elaborator, type-checker | `compile-live-process` match arm — currently falls through silently at L636 |
| `proc-connect` | Struct, parser, elaborator, type-checker | Same — no runtime match arm |
| `proc-listen` | Struct, parser, elaborator, type-checker | Same — no runtime match arm |
| `sess-dsend`/`sess-drecv` | Struct, `dual`/`substS`/`unfoldS`, reader, preparse, parser, type-checker, pretty-printer | Elaborator discards binder name (§7.2 Gap 1); runtime predicates exclude dsend/drecv (§7.2 Gap 2) |
| Cap inference in compile path | `run-capability-inference` function | Wired into REPL `(cap-closure)` only, not normal compilation |

---

<a id="4-io-capability-types"></a>

## 4. IO Capability Types

### 4.1 Existing Infrastructure

The file `lib/prologos/core/capabilities.prologos` currently defines 7 capability types
and 6 subtype relationships using standalone declarations:

```prologos
;; Currently exists — but NEEDS REVISION (see §4.3):
capability ReadCap       ;; leaf: read from filesystem          ← KEEP as capability
capability WriteCap      ;; leaf: write to filesystem           ← KEEP as capability
capability HttpCap       ;; leaf: make HTTP requests            ← KEEP as capability
capability StdioCap      ;; leaf: use stdin/stdout/stderr       ← KEEP as capability
capability FsCap         ;; WRONG: should be union type, not standalone capability
capability NetCap        ;; WRONG: should be union type, not standalone capability
capability SysCap        ;; WRONG: should be union type, not standalone capability

;; Currently exists — REDUNDANT after union type revision:
subtype ReadCap FsCap    ;; DERIVED from union membership
subtype WriteCap FsCap   ;; DERIVED from union membership
subtype HttpCap NetCap   ;; DERIVED from union membership
subtype FsCap SysCap     ;; DERIVED from union membership
subtype NetCap SysCap    ;; DERIVED from union membership
subtype StdioCap SysCap  ;; DERIVED from union membership
```

Per CAPABILITY_SECURITY.md §Composite Union, composite caps must be **union types**
(authority that encompasses any variant), not standalone declarations with subtype
hierarchies. Phase IO-A3 revises this file — see §4.3 for the rationale and §4.2
for the target state.

The parser (`parser.rkt` L2826-2848) already supports both `(capability Name)` and
the parameterized form `(capability Name (p : Type))` — this means dependent capability
declarations like `capability FileCap (p : Path)` can be parsed today.

### 4.2 Target Capability Hierarchy (after IO-A3)

Doc1 (V2 §3.1) specifies 14 leaf capabilities. For file IO (Phases IO-A through IO-G),
we add two new leaf capabilities and revise composites to union types:

```prologos
;; Leaf capabilities (zero-method traits):
capability ReadCap       ;; read from filesystem
capability WriteCap      ;; write to filesystem
capability AppendCap     ;; append to files (NEW)
capability StatCap       ;; query file metadata (NEW)
capability HttpCap       ;; make HTTP requests
capability StdioCap      ;; use stdin/stdout/stderr

;; Composite capabilities (union types — per CAPABILITY_SECURITY.md):
type FsCap  = ReadCap | WriteCap | AppendCap | StatCap
type NetCap = HttpCap
type IOCap  = FsCap | NetCap | StdioCap
type SysCap = IOCap
```

Attenuation is natural subtyping: `ReadCap <: FsCap <: IOCap <: SysCap`.

The remaining leaf capabilities from Doc1 (MkdirCap, DeleteCap, WsCap, ListenCap,
DbReadCap, DbWriteCap, SpawnCap, ClockCap, EnvCap) are deferred to Phase 2+ alongside
their corresponding IO modules (network, database, process spawning). When added,
they expand their respective union types (e.g., `type NetCap = HttpCap | WsCap`).

### 4.3 Composite Capability Model (Decision D17)

CAPABILITY_SECURITY.md §Composite Union is unambiguous: composite capabilities are
**union types**, not standalone declarations with subtype hierarchies.

The logical distinction is fundamental:
- **Bundles are conjunctive (AND)** — contraction, narrowing, "must satisfy all"
- **Composite caps are disjunctive (OR)** — weakening, widening, "grants any of these"

Union types are the correct expression because a capability is something you *have*
(authority), not something you *must prove* (constraint). `FsCap` grants authority that
*encompasses* both reading and writing — this is union, not intersection.

**Decision D17**: Composite capabilities are **union types**. Attenuation follows
naturally as subtyping (`ReadCap <: FsCap` because a variant is a subtype of its union).

```prologos
;; Leaf capabilities — zero-method traits as authority proofs
capability ReadCap
capability WriteCap
capability AppendCap
capability StatCap
capability HttpCap
capability StdioCap

;; Composite capabilities — union types (authority encompasses any variant)
type FsCap    = ReadCap | WriteCap | AppendCap | StatCap
type NetCap   = HttpCap
type IOCap    = FsCap | NetCap | StdioCap
type SysCap   = IOCap   ;; SysCap encompasses all IO authority (+ future: SpawnCap, ClockCap)
```

Attenuation falls out of union type subsumption:
- `ReadCap <: FsCap` — read authority is a subset of filesystem authority
- `FsCap <: IOCap` — filesystem authority is a subset of all IO authority
- `IOCap <: SysCap` — IO authority is a subset of system authority

When a function requires `{ReadCap}` and the caller has `{fs : FsCap}`, the compiler
resolves it through subtype subsumption — `ReadCap <: FsCap`, so `FsCap` satisfies
the `ReadCap` requirement. No explicit attenuation needed. This is the zero-cost
common case (CAPABILITY_SECURITY.md §Attenuation as Subtyping).

**Migration note**: The existing `capabilities.prologos` uses standalone `capability`
declarations for composites (`capability FsCap`) with explicit `subtype` declarations.
Phase IO-A3 must revise these to union type definitions. The `subtype` declarations
for leaf-to-composite relationships become redundant (derived from union membership)
but may be retained as explicit documentation or for the subsumption checker if it
doesn't yet derive subtypes from union structure automatically.

### 4.4 IOCap — Top of IO Hierarchy

Doc1 §3 defines `IOCap` as the top-level IO authority. Per the union model:

```prologos
type IOCap = FsCap | NetCap | StdioCap
type SysCap = IOCap   ;; SysCap = IOCap for now; expands with SpawnCap, ClockCap later
```

`IOCap` and `SysCap` are distinct — `IOCap` encompasses IO authority, while `SysCap`
encompasses all system authority (IO + process spawning + clock access + future
capabilities). For Phase 1, `SysCap = IOCap` (they're equivalent), but the names are
kept separate for forward compatibility. `main` receives `SysCap`.

### 4.5 AST Pipeline Impact

If the existing `capability` keyword creates standalone zero-method traits and the
union type `type` keyword already creates union types, no new AST is needed — we just
use `type` instead of `capability` for composites. The `capability` keyword remains
for leaf capabilities (zero-method traits).

**Open question**: Does the capability inference propagator handle union-typed caps?
It currently works with atomic symbol names in `cap-set`. If `FsCap` is now a union
type rather than an atomic cap name, `extract-capability-requirements` may need to
resolve through union membership. This should be verified in Phase IO-A3 and addressed
in Phase IO-H (capability inference pipeline integration).

### 4.6 Tests (~5, part of IO-A3)

- Composite cap `FsCap` is a union type (`ReadCap | WriteCap | AppendCap | StatCap`)
- Attenuation: `ReadCap <: FsCap` via union subsumption
- Transitive: `ReadCap <: FsCap <: IOCap <: SysCap`
- Function requiring `{ReadCap}` satisfied by caller with `{FsCap}` (subsumption)
- `IOCap` and `SysCap` exist as top-level union types
- Regression: leaf capabilities (`ReadCap`, `WriteCap`, etc.) unchanged

---

<a id="5-opaque-type-marshalling"></a>

## 5. Opaque Type Marshalling

### 5.1 Problem

`foreign.rkt` marshals between Prologos values and Racket values for a fixed set of base
types (Nat, Int, Rat, Bool, Unit, Char, String). IO operations need to pass Racket-native
opaque values (file ports, database connections, network sockets) through the Prologos
runtime without interpretation.

### 5.2 Design

**New struct in `syntax.rkt`:**

```racket
;; Opaque wrapper: holds a Racket value that the Prologos runtime
;; cannot inspect. Used for file ports, db connections, etc.
(struct expr-opaque (value tag) #:transparent)
;; value: the raw Racket value (port, connection, etc.)
;; tag: symbol identifying the opaque type ('file-port, 'db-conn, etc.)
```

**New type-level marker in `syntax.rkt`:**

```racket
;; Opaque type constructor: (OpaqueType 'file-port)
(struct expr-OpaqueType (tag) #:transparent)
```

**Changes to `foreign.rkt`:**

```racket
;; In base-type-name:
[(expr-OpaqueType tag) (string->symbol (format "Opaque:~a" tag))]

;; In marshal-prologos->racket:
[(Opaque) val]  ;; unwrap: just extract the Racket value
;; Or more precisely, pattern match on the tag prefix:
[else
 (if (string-prefix? (symbol->string base-type) "Opaque:")
     (if (expr-opaque? val) (expr-opaque-value val) val)
     (error 'foreign "Unsupported marshal-in type: ~a" base-type))]

;; In marshal-racket->prologos:
[else
 (if (string-prefix? (symbol->string base-type) "Opaque:")
     (expr-opaque val (string->symbol
                       (substring (symbol->string base-type) 7)))
     (error 'foreign "Unsupported marshal-out type: ~a" base-type))]
```

### 5.3 Alternative Rejected: Simple Pass-Through

A simpler approach would add a single `'Opaque` symbol to `base-type-name` without tag
differentiation. **This is rejected** — it loses type safety. All opaque values become
the same type, meaning a file port could be passed where a database connection is
expected. The tagged approach costs ~5 more lines but preserves the invariant that
different opaque types (`file-port` vs. `db-conn`) are distinct at the type level.
Type safety at the FFI boundary is non-negotiable.

### 5.4 AST Pipeline Impact

| File | Change |
|------|--------|
| `syntax.rkt` | Add `expr-opaque`, `expr-OpaqueType` structs |
| `foreign.rkt` | Add opaque cases to `base-type-name`, `marshal-prologos->racket`, `marshal-racket->prologos` |
| `pretty-print.rkt` | Add `expr-opaque` → `#<opaque:tag>` display |
| `reduction.rkt` | `expr-opaque` is a value (no reduction needed) |
| `zonk.rkt` | Pass-through for `expr-opaque` |
| `substitution.rkt` | Pass-through for `expr-opaque` (no free variables) |

### 5.5 Tests (~8)

- Marshal Racket port → `expr-opaque` → Racket port round-trip
- Tagged opaque types are distinct (`'file-port` vs `'db-conn`)
- Pretty-print displays `#<opaque:file-port>`
- Opaque values survive reduction (are values)
- Error on marshalling unsupported types (existing behavior preserved)

---

<a id="6-io-bridge-architecture"></a>

## 6. IO Bridge Architecture

### 6.1 Overview

The IO bridge is the mechanism by which session protocol operations (`!`/`?`/`select`/
`offer`) on IO channels translate into actual side effects (reading/writing files, network
operations). It sits between the session runtime and external resources, implementing the
"double-boundary" model from Session Type Design §12.5.

### 6.2 IO State Lattice

```
IOState lattice (flat with distinguished elements):

  io-bot          (⊥ — no IO has occurred)
    │
  io-opening(path, mode)    (file is being opened)
    │
  io-open(port, mode)       (file is open, port is the Racket port)
    │
  io-closed                 (file handle released)
    │
  io-top          (⊤ — contradiction: e.g., read after close)
```

```racket
;; In NEW file: racket/prologos/io-bridge.rkt

(define io-bot 'io-bot)
(define io-top 'io-top)

(struct io-opening (path mode) #:transparent)
(struct io-open (port mode) #:transparent)
(define io-closed 'io-closed)

(define (io-bot? v) (eq? v 'io-bot))
(define (io-top? v) (eq? v 'io-top))
(define (io-closed? v) (eq? v 'io-closed))

(define (io-state-merge old new)
  (cond
    [(io-bot? old) new]
    [(io-bot? new) old]
    [(io-top? old) io-top]
    [(io-top? new) io-top]
    ;; Valid transitions: opening → open, open → closed
    [(and (io-opening? old) (io-open? new)) new]
    [(and (io-open? old) (io-closed? new)) new]
    ;; Same state: idempotent
    [(equal? old new) old]
    ;; Everything else: contradiction
    [else io-top]))

(define (io-state-contradicts? v) (io-top? v))
```

### 6.3 IO Bridge Propagator

The IO bridge propagator is a **side-effecting** propagator. Unlike normal propagators
(which are pure lattice joins), this one performs actual IO when fired. This is by design —
the propagator network is the IO scheduler.

```racket
;; Pseudocode for the IO bridge propagator
(define (make-io-bridge-propagator io-cell session-cell msg-in-cell msg-out-cell)
  (lambda (net)
    (define io-state (net-cell-read net io-cell))
    (define sess-state (net-cell-read net session-cell))
    (define msg-out (net-cell-read net msg-out-cell))
    (cond
      ;; File is open and session expects a send (client writing data)
      [(and (io-open? io-state)
            (sess-send? sess-state)
            (not (msg-bot? msg-out)))
       ;; SIDE EFFECT: write to file
       (define port (io-open-port io-state))
       (write-string (expr-string-val msg-out) port)
       (flush-output port)
       net]  ;; session advancement handled by session-runtime

      ;; File is open and session expects a recv (client reading data)
      [(and (io-open? io-state)
            (sess-recv? sess-state))
       ;; SIDE EFFECT: read from file
       (define port (io-open-port io-state))
       (define data (read-string 1048576 port))  ;; read up to 1MB
       (define result
         (if (eof-object? data)
             (expr-ctor 'none (list))      ;; Option: none
             (expr-ctor 'some (list (expr-string data)))))  ;; Option: some
       (net-cell-write net msg-in-cell result)]

      ;; Session ends → close the file
      [(and (io-open? io-state)
            (sess-end? sess-state))
       ;; SIDE EFFECT: close file port
       (close-port (io-open-port io-state))
       (net-cell-write net io-cell io-closed)]

      [else net])))
```

### 6.4 Integration with `run-to-quiescence`

IO bridge propagators participate in the same `run-to-quiescence` loop as session
propagators. The scheduling is:

1. Session propagators fire first (advancing protocol state)
2. IO bridge propagators fire when session cells change (performing IO)
3. IO results flow back through msg-in cells
4. Session propagators fire again (advancing to next protocol step)
5. Repeat until quiescence

No special scheduling priority is needed — the data dependency graph naturally orders
session advancement before IO operations before result delivery.

### 6.5 Error Handling in the IO Bridge

IO errors (file not found, permission denied, etc.) are caught by the IO bridge propagator
and converted to Prologos `Result` values:

```racket
(with-handlers
  ([exn:fail:filesystem?
    (lambda (e)
      (define err (make-io-error-from-exn e))
      (net-cell-write net msg-in-cell
        (expr-ctor 'err (list err))))])
  ;; ... perform IO ...
  (net-cell-write net msg-in-cell
    (expr-ctor 'ok (list result))))
```

Racket exceptions are caught at the IO bridge boundary and converted to `Result` values.
The session protocol sees only values, never exceptions. This maintains the guarantee that
errors are handled in the type system.

### 6.6 File: `racket/prologos/io-bridge.rkt`

**Estimated size**: ~200 lines

**Provides**:
- `io-bot`, `io-top`, `io-opening`, `io-open`, `io-closed` — lattice elements
- `io-state-merge`, `io-state-contradicts?` — lattice operations
- `make-io-bridge-propagator` — creates a side-effecting IO propagator
- `make-io-bridge-cell` — creates a fresh IO state cell in a runtime network
- `io-bridge-open-file` — performs the `open` side effect, returns `io-open` state

**Requires**: `prop-network.rkt`, `sessions.rkt`, `syntax.rkt`

---

<a id="7-boundary-operations-runtime"></a>

## 7. Boundary Operations Runtime

### 7.1 Problem

`proc-open`, `proc-connect`, and `proc-listen` are parsed, elaborated, and type-checked,
but `compile-live-process` in `session-runtime.rkt` (L636) falls through silently for
these forms. They need match arms that create IO channels.

### 7.2 `proc-open` — File Open

Unlike `proc-new` (which creates a channel pair with two endpoints), `proc-open` creates
a **single-endpoint channel** where the other side is an IO bridge propagator:

```racket
;; In compile-live-process, add before the fallback:

[(proc-open path-expr session-type cap-type cont)
 ;; 1. Create a single channel endpoint (not a pair)
 (define-values (rnet1 ep io-cell)
   (rt-new-io-channel rnet session-type))
 ;; 2. Resolve the path expression
 (define path-val (resolve-expr path-expr bindings))
 ;; 3. Perform the open side effect (capability already checked at type-check time)
 (define rnet2
   (rt-cell-write rnet1 io-cell
     (io-opening (expr-string-val path-val) 'read)))  ;; mode from session type
 ;; 4. Install IO bridge propagator
 (define-values (rnet3 _pid)
   (rt-add-propagator rnet2
     (list io-cell
           (channel-endpoint-session-cell ep)
           (channel-endpoint-msg-out-cell ep))
     (list (channel-endpoint-msg-in-cell ep)
           io-cell)
     (make-io-bridge-propagator
       io-cell
       (channel-endpoint-session-cell ep)
       (channel-endpoint-msg-in-cell ep)
       (channel-endpoint-msg-out-cell ep))))
 ;; 5. Actually open the file (side effect)
 (define rnet4 (io-bridge-open-file rnet3 io-cell))
 ;; 6. Trace
 (define trace*
   (rt-trace-add trace (channel-endpoint-session-cell ep)
     (format "proc-open: file ~a" (expr-string-val path-val))))
 ;; 7. Recurse into continuation with the endpoint bound
 (compile-live-process rnet4 cont
   (hash-set channel-eps 'ch ep) bindings trace*)]
```

### 7.3 `rt-new-io-channel` — Single-Endpoint Channel Creation

```racket
;; Create a single channel endpoint backed by an IO bridge cell.
;; Unlike rt-new-channel-pair, there is no dual endpoint — the "other side"
;; is the IO bridge propagator.
(define (rt-new-io-channel rnet session-type)
  (define net (runtime-network-prop-net rnet))
  ;; Create the 4 standard cells + 1 IO state cell
  (define-values (net1 msg-out-id) (net-add-cell net msg-bot msg-lattice-merge))
  (define-values (net2 msg-in-id) (net-add-cell net1 msg-bot msg-lattice-merge))
  (define-values (net3 sess-id) (net-add-cell net2 session-type sess-lattice-merge))
  (define-values (net4 choice-id) (net-add-cell net3 choice-bot choice-lattice-merge))
  (define-values (net5 io-id) (net-add-cell net4 io-bot io-state-merge))
  (define ep (channel-endpoint msg-out-id msg-in-id sess-id choice-id))
  (values
    (struct-copy runtime-network rnet [prop-net net5])
    ep
    io-id))
```

### 7.4 `proc-connect` and `proc-listen` — Deferred

`proc-connect` (network) and `proc-listen` (server socket) follow the same pattern as
`proc-open` but with different FFI calls. They are deferred to Phase 2+ (network IO).
The infrastructure built for `proc-open` (single-endpoint channels, IO bridge propagators)
directly generalizes to these cases.

### 7.5 Tests (~12)

- `proc-open` creates a single-endpoint channel (not a pair)
- IO bridge cell starts at `io-bot`, transitions through `io-opening` → `io-open`
- File read via session protocol returns correct data
- File write via session protocol writes correct data
- Close operation closes the file port (verified via Racket `port-closed?`)
- Error on opening nonexistent file → `Result` error value
- Error on read after close → IO cell goes to `io-top`
- Session protocol advancement integrates correctly with IO bridge
- End-to-end: open → read-all → close pipeline

---

<a id="8-dependent-sendreceive"></a>

## 8. Dependent Send/Receive

### 8.1 Current State — Much Further Along Than Previously Documented

The pipeline for `!:`/`?:` is **almost entirely complete**. The prior claim that this
was "blocked on reader/parser token work" was stale and incorrect. Here is the actual
layer-by-layer status:

| Layer | Status | File | Notes |
|-------|--------|------|-------|
| WS reader (`!:`/`?:` tokens) | **DONE** | `reader.rkt` L636-658 | Tokenize as `'!:` / `'?:` symbols |
| Session preparse | **DONE** | `macros.rkt` L826-1075 | `desugar-session-ws`, `regroup-session-tokens` handle `!:` / `?:` |
| Surface syntax structs | **DONE** | `surface-syntax.rkt` L1066-1067 | `surf-sess-dsend`, `surf-sess-drecv` |
| Sexp parser | **DONE** | `parser.rkt` L4681-4723 | `(DSend (n : T) Cont)` / `(DRecv (x : T) Cont)` |
| Elaborator | **GAP** | `elaborator.rkt` L3201-3215 | Binder name **discarded** — continuation cannot reference bound variable |
| Sessions IR | **DONE** | `sessions.rkt` L33-34 | `dual`, `substS`, `unfoldS` all correct |
| Type-checker | **DONE** | `typing-sessions.rkt` L146-177 | `substS` on send; `ctx-extend` on recv |
| Runtime propagator | **GAP** | `session-runtime.rkt` L64-70 | `sess-send-like?`/`sess-recv-like?` exclude `sess-dsend`/`sess-drecv` |
| Pretty-printer | **DONE** | `pretty-print.rkt` L1246-1251 | Fresh name generation |
| Grammar docs | **STALE** | `grammar.ebnf` L1099-1100 | WS operator syntax not documented |
| Tests (existing) | **PARTIAL** | `test-session-parse-02.rkt`, `test-session-ws-01.rkt` | Parse + WS desugar pass; no E2E dependent-type tests |

### 8.2 The Two Real Gaps

**Gap 1: Elaborator binder scope** (`elaborator.rkt` L3201-3208)

The `name` from `surf-sess-dsend`/`surf-sess-drecv` is discarded during elaboration.
For `?: n Nat . ? [Vec String n] . end` to work, the elaborator must extend gamma with
`n : Nat` when elaborating the continuation session body (exactly as `expr-Pi` binding
works for function types).

```racket
;; Current (L3201-3208): name is discarded
[(surf-sess-dsend name type-surf cont-surf _loc)
 (let ([ty (elaborate type-surf)])
   (let ([cont (elaborate-session-body cont-surf ...)])
     (maybe-wrap-throws (sess-dsend ty cont) throws-type)))]

;; Fix: extend gamma before elaborating continuation
[(surf-sess-dsend name type-surf cont-surf _loc)
 (let ([ty (elaborate type-surf)])
   (let ([cont (parameterize ([current-gamma (ctx-extend (current-gamma) ty 'mw)])
                 (elaborate-session-body cont-surf ...))])
     (maybe-wrap-throws (sess-dsend ty cont) throws-type)))]
```

The same pattern applies to `surf-sess-drecv`. This is ~10 lines of change.

**Gap 2: Runtime predicates** (`session-runtime.rkt` L64-70)

`sess-send-like?` and `sess-recv-like?` do not include the dependent variants:

```racket
;; Current:
(define (sess-send-like? v) (or (sess-send? v) (sess-async-send? v)))

;; Fix (add sess-dsend):
(define (sess-send-like? v) (or (sess-send? v) (sess-async-send? v) (sess-dsend? v)))
(define (sess-send-like-cont v)
  (cond [(sess-send? v) (sess-send-cont v)]
        [(sess-async-send? v) (sess-async-send-cont v)]
        [(sess-dsend? v) (sess-dsend-cont v)]))

;; Same for recv:
(define (sess-recv-like? v) (or (sess-recv? v) (sess-async-recv? v) (sess-drecv? v)))
(define (sess-recv-like-cont v)
  (cond [(sess-recv? v) (sess-recv-cont v)]
        [(sess-async-recv? v) (sess-async-recv-cont v)]
        [(sess-drecv? v) (sess-drecv-cont v)]))
```

Additionally, the runtime needs to substitute the actual sent value into the continuation
session type (using `substS`). Currently `compile-live-process` advances the session cell
via `sess-send-like-cont` which just extracts the continuation. For dependent send, the
continuation must have `substS` applied with the actual value:

```racket
;; In the Send match arm, after writing the value:
(define raw-cont (sess-send-like-cont sess))
(define actual-cont
  (if (sess-dsend? sess)
      (substS raw-cont 0 val)  ;; substitute sent value into continuation
      raw-cont))
```

### 8.3 What Dependent Sessions Enable

Beyond schema-typed IO, dependent send/receive is essential for:

- **Length-indexed protocols**: `!: n Nat . ! [Vec String n] . end` — send exactly `n` items
- **Schema-typed file reading**: `?: header [List String] . ? [List [Record header]] . end`
- **Negotiated protocols**: `!: format Keyword . ? [FormatData format] . end` — response type depends on request
- **Capability transfer**: `!: cap CapType . ? [Attested cap] . end` — prove authority was received

### 8.4 No Dependency on IO Infrastructure

Dependent send/receive is a session type feature, not an IO feature. It has **zero
dependency** on Phases IO-A through IO-D. It can be implemented immediately, in parallel
with the IO infrastructure phases. The two gaps are small (~20 lines total) and all
supporting infrastructure (IR, typing, parsing, reader) is complete.

---

<a id="9-path-and-ioerror-types"></a>

## 9. Path and IOError Types

### 9.1 Path Type

**Decision D9**: String wrapper initially, not opaque Racket path.

```prologos
;; lib/prologos/data/path.prologos
ns prologos.data.path :no-prelude

type Path := MkPath String

spec path : String -> Path
defn path [s] [MkPath s]

spec path-str : Path -> String
defn path-str [p]
  match p
    | MkPath s -> s

spec path-join : Path Path -> Path
defn path-join [a b]
  [MkPath [string-append [path-str a] "/" [path-str b]]]

spec path-parent : Path -> Path
defn path-parent [p]
  ;; Find last "/" and take prefix
  ...

spec path-extension : Path -> Option String
defn path-extension [p]
  ;; Find last "." and take suffix
  ...

spec path-file-name : Path -> String
defn path-file-name [p]
  ;; Find last "/" and take suffix
  ...
```

Pure operations only — no IO in this module.

### 9.2 IOError Type

```prologos
;; lib/prologos/data/io-error.prologos
ns prologos.data.io-error :no-prelude

type IOError
  := FileNotFound Path
   | PermissionDenied Path
   | IsDirectory Path
   | AlreadyExists Path
   | NotAFile Path
   | IOFailed String
```

### 9.3 Racket-Side Error Mapping

```racket
;; In io-bridge.rkt or io-ffi.rkt
(define (make-io-error-from-exn e path-val)
  (define msg (exn-message e))
  (cond
    [(regexp-match? #rx"No such file" msg)
     (expr-ctor 'FileNotFound (list path-val))]
    [(regexp-match? #rx"Permission denied" msg)
     (expr-ctor 'PermissionDenied (list path-val))]
    [(regexp-match? #rx"Is a directory" msg)
     (expr-ctor 'IsDirectory (list path-val))]
    [(regexp-match? #rx"File exists" msg)
     (expr-ctor 'AlreadyExists (list path-val))]
    [else
     (expr-ctor 'IOFailed (list (expr-string msg)))]))
```

### 9.4 Tests (~10)

- `Path` constructor and accessors round-trip
- `path-join` concatenates with separator
- `path-parent`, `path-extension`, `path-file-name` extract correctly
- `IOError` constructors and pattern matching
- Racket exception → `IOError` mapping

---

<a id="10-ffi-bridge-layer"></a>

## 10. FFI Bridge Layer

### 10.1 File: `racket/prologos/io-ffi.rkt`

This module wraps Racket's file IO primitives as foreign functions callable from Prologos.
It uses opaque type marshalling (§4) for file ports.

**Estimated size**: ~120 lines

```racket
;; racket/prologos/io-ffi.rkt
#lang racket/base
(require "syntax.rkt"
         "foreign.rkt")

(provide io-ffi-registry)

;; Registry: maps function names to (cons racket-procedure type-descriptor)
;; These are registered as foreign functions in the namespace.

(define io-ffi-registry
  (hasheq
    ;; File operations
    'io-open-input    (cons open-input-file    '((String) . Opaque:file-port))
    'io-open-output   (cons open-output-file   '((String) . Opaque:file-port))
    'io-read-string   (cons port-read-string   '((Opaque:file-port) . String))
    'io-read-line     (cons port-read-line     '((Opaque:file-port) . String))
    'io-write-string  (cons port-write-string  '((Opaque:file-port String) . Unit))
    'io-close         (cons close-port         '((Opaque:file-port) . Unit))
    'io-port-closed?  (cons port-closed?       '((Opaque:file-port) . Bool))
    ;; Console
    'io-display       (cons display-wrapper    '((String) . Unit))
    'io-displayln     (cons displayln-wrapper  '((String) . Unit))
    'io-read-ln       (cons read-line-wrapper  '(() . String))
    ;; Filesystem queries
    'io-file-exists?  (cons file-exists?       '((String) . Bool))
    'io-directory?    (cons directory-exists?   '((String) . Bool))
    ))

;; Wrapper functions to handle Racket IO nuances
(define (port-read-string port)
  (define s (read-string 1048576 port))  ;; 1MB max
  (if (eof-object? s) "" s))

(define (port-read-line port)
  (define s (read-line port))
  (if (eof-object? s) "" s))

(define (port-write-string port str)
  (write-string str port)
  (void))

(define (display-wrapper str) (display str) (void))
(define (displayln-wrapper str) (displayln str) (void))
(define (read-line-wrapper) (read-line))
```

### 10.2 Registration in Namespace

These FFI functions are registered in the namespace during module loading, similar to how
`register-foreign!` works in `driver.rkt`. The `io-ffi-registry` is imported by the
IO library modules and registered as foreign bindings.

### 10.3 Two Tiers of the IO API Surface

There are two tiers of the IO API surface, both backed by the same FFI bridge:

1. **Session-based IO** (`prologos.core.io`, Tier 2-3):
   Process → session channel → IO bridge propagator → Racket IO → results back through channel

2. **Functional linear IO** (`prologos.core.fio`, Tier 2 alternative):
   Prologos function → `(foreign ...)` call → `io-ffi.rkt` → Racket IO → marshalled result

These are **two tiers of the same IO architecture**, not two competing implementations.
Both go through the same Racket IO functions in `io-ffi.rkt`, and both enforce capability
checking at compile time. The difference is the user-facing abstraction: session protocols
vs. linear handle threading. Console IO convenience functions (§16) also use direct FFI
but are part of Tier 1 progressive disclosure, not an escape hatch — they carry the same
`StdioCap` requirement, just invisibly via `:0` erased parameters.

---

<a id="11-convenience-functions-and-with-open"></a>

## 11. Convenience Functions and `with-open`

### 11.1 Core IO Module: `lib/prologos/core/io.prologos`

```prologos
;; lib/prologos/core/io.prologos
ns prologos.core.io :no-prelude
use prologos.data.path :refer [Path path path-str]
use prologos.data.io-error :refer [IOError]

;; === Tier 1: One-shot convenience functions ===
;; These open, perform IO, and close internally.
;; Capability requirements are inferred by the compiler.

spec read-file : Path -> Result String IOError
defn read-file [p]
  ;; Implementation: open session channel, read-all, close
  ...

spec write-file : Path String -> Result Unit IOError
defn write-file [p content]
  ...

spec read-lines : Path -> Result [List String] IOError
defn read-lines [p]
  match [read-file p]
    | ok content -> ok [split content "\n"]
    | err e -> err e

spec append-file : Path String -> Result Unit IOError
defn append-file [p content]
  ...

;; === Tier 2: Bracketed resource management ===

spec with-open : Path Keyword <(ch : FileRW) -> A> -> Result A IOError
defn with-open [p mode body]
  ;; Opens a session channel, passes to body, closes on exit
  ...
```

### 11.2 Implementation Strategy for Convenience Functions

Each convenience function internally:

1. Creates a session channel via `open` (boundary op)
2. Performs the session protocol (select, send/receive)
3. Closes the channel (select `:close`)
4. Returns the result

In Phase 0, where the session runtime is single-threaded and runs to quiescence,
the implementation can use a simpler direct-FFI approach initially, with session
protocol enforcement at the type level. The full session-channel implementation
follows in Phase IO-E.

**Phase IO-D approach** (initial): Direct FFI calls with capability checking at type level:

```prologos
spec read-file : Path -> Result String IOError
defn read-file [p]
  ;; Direct FFI — session protocol enforced at type level, not runtime
  foreign io-read-all [path-str p]
```

**Phase IO-E approach** (full): Session channel internally:

```prologos
spec read-file : Path -> Result String IOError
defn read-file [p]
  open p : FileRead
  select ch :read-all
  let result := ch ?
  select ch :close
  result
```

### 11.3 `with-open` Macro (Decision D19)

Following the `with-transient` pattern in `macros.rkt`:

```racket
;; (with-open path mode (fn [ch] body))
;; → (let [ch (open path mode)]
;;     (let [result (body ch)]
;;       (select ch :close)
;;       result))
(define (expand-with-open datum)
  (unless (and (list? datum) (= (length datum) 4))
    (error 'with-open
           "expected (with-open path mode fn-expr), got ~v" datum))
  (let ([path-expr (cadr datum)]
        [mode (caddr datum)]
        [fn-expr (cadddr datum)])
    `(let [__wopen_ch (open ,path-expr ,mode)]
       (let [__wopen_result (,fn-expr __wopen_ch)]
         (select __wopen_ch |:close|)
         __wopen_result))))

(register-preparse-macro! 'with-open expand-with-open)
```

### 11.4 Tests (~30)

- `read-file` reads file content correctly
- `read-file` on nonexistent file → `err (FileNotFound ...)`
- `write-file` creates file with content
- `write-file` overwrites existing file
- `append-file` appends to existing file
- `read-lines` splits on newlines
- `with-open` opens, runs body, closes
- `with-open` closes even on error (bracket guarantee)
- Capability inference: `read-file` infers `{ReadCap}`
- Capability inference: `write-file` infers `{WriteCap}`
- End-to-end: write then read round-trip

---

<a id="12-filesystem-query-functions"></a>

## 12. Filesystem Query Functions

### 12.1 Functions (from V2 §5.1)

Doc1 specifies four filesystem query convenience functions. These are Tier 1 (no
handles, no session concepts visible) and use direct FFI calls with capability inference.

```prologos
;; In lib/prologos/io/fs.prologos
ns prologos.io.fs :no-prelude
use prologos.data.path :refer [Path path-str]

;; All require {StatCap} — inferred, never visible to Tier 1 users

spec exists? : Path -> Bool
defn exists? [p]
  foreign io-file-exists? [path-str p]

spec file? : Path -> Bool
defn file? [p]
  foreign io-is-file? [path-str p]

spec dir? : Path -> Bool
defn dir? [p]
  foreign io-directory? [path-str p]

spec list-dir : Path -> Result [List Path] IOError
defn list-dir [p]
  ;; foreign io-directory-list wraps Racket directory-list
  foreign io-directory-list [path-str p]
```

### 12.2 FFI Extensions

`io-ffi.rkt` needs additional entries:

```racket
;; Add to io-ffi-registry:
'io-is-file?       (cons file-exists?-not-dir  '((String) . Bool))
'io-directory-list  (cons directory-list-wrapper '((String) . (List String)))
```

### 12.3 Tests (~8, part of IO-D4)

- `exists?` returns `#t` for existing file
- `exists?` returns `#f` for nonexistent path
- `file?` returns `#t` for file, `#f` for directory
- `dir?` returns `#t` for directory, `#f` for file
- `list-dir` returns list of paths for existing directory
- `list-dir` returns error for nonexistent directory
- Capability inference: `exists?` infers `{StatCap}`
- Capability inference: `list-dir` infers `{StatCap}`

---

<a id="13-main-as-powerbox"></a>

## 13. `main` as Powerbox

### 13.1 Design (from V2 §7, CAPABILITY_SECURITY.md §Authority Root)

`main` is the authority root — the only place capabilities are minted from nothing. The
runtime grants the full `SysCap` to `main`, which can then delegate narrower capabilities
to called functions and spawned processes via subtype subsumption.

This is the critical mechanism for Tier 1 progressive disclosure: users write `defn main`
with no capability annotations; the compiler infers what's needed; the runtime provides it.

### 13.2 Two Forms of `main` (Decision D8, D20)

**`defn main` — Simple scripts, sequential IO**

```prologos
;; Compiler infers capabilities from body
;; Runtime provisions SysCap; inferred caps resolve via subsumption
defn main []
  let data := [read-file [path "input.txt"]]
  [println data]
```

`defn main` is **strictly sequential** — `spawn` is illegal in `defn main` context (it
is only legal in `defproc` context, where channel management is explicit). This is enforced
by the type system: `spawn` requires a process context, and `defn main` desugars to a
single-shot process with no exposed channels.

`defn main` desugars internally to a process with a single "run body to completion"
session. The user never sees this. The desugaring:

```
defn main [] body
→ defproc __main_proc : __RunToCompletion {sys : SysCap}
    let __result := body
    self ! __result
    stop
```

Where `__RunToCompletion` is an internal session type: `! A . end`.

**`defproc main` — Concurrent programs, explicit channel management**

```prologos
;; Explicit capabilities in header
defproc main [args : List String] {sys : SysCap}
  spawn file-watcher FsCap       ;; ReadCap <: FsCap <: SysCap
  spawn api-server NetCap
  ...
```

### 13.3 Implementation

#### 13.3.1 Compile-Time: Cap Inference on `main`

After capability inference (Phase IO-H), `driver.rkt` stores the inferred cap closure
for `main`:

```racket
;; In driver.rkt, after run-capability-inference:
(when (hash-has-key? cap-closures 'main)
  (current-main-capabilities (hash-ref cap-closures 'main)))
```

#### 13.3.2 Runtime: Cap Provisioning

The runtime provisions capabilities to `main` before execution. For Phase 0 (no
concurrent runtime), this is a compile-time check only — the capabilities are `:0`
(erased), so no runtime values need to be constructed:

```racket
;; In driver.rkt, when running main:
;; 1. Check that the program's cap closure is satisfiable
;;    (all caps are subtypes of SysCap — trivially true for IO caps)
;; 2. No runtime action needed — :0 caps are erased
;; 3. Proceed to execute main
```

For a future concurrent runtime, capability provisioning would create actual
capability tokens that are passed through the process network.

#### 13.3.3 `defn main` Desugaring

In `macros.rkt` or `elaborator.rkt`, when a `defn main` is encountered:

```racket
;; Detect defn main (no defproc main exists)
;; Desugar:
;;   (defn main [] body)
;; → (defproc __main_wrapper : __MainSession {sys : SysCap}
;;     (let __result body)
;;     (send self __result)
;;     stop)
;; Where __MainSession = (sess-send (type-of-body) (sess-end))
```

This is the same pattern as how `defn` with IO calls needs to be wrapped — the
desugaring creates a process context where capabilities can be resolved.

**Note**: For Phase 0 (no concurrent runtime), the desugaring may be simpler: just
execute the body directly with capability checking at type-check time. The full process
desugaring is needed when the concurrent runtime exists. The key is that the type
checker sees the capability requirements on `main` and verifies them.

### 13.4 Tests (~8, part of IO-D5)

- `defn main [] [println "hello"]` — caps inferred, program runs
- `defn main` with `read-file` — `ReadCap` inferred and satisfied
- `defn main` with `read-file` + `write-file` — both caps inferred
- `defproc main` with explicit `{sys : SysCap}` — accepted
- Cap subsumption: child requiring `ReadCap` satisfied by parent's `SysCap`
- Error: function requiring `ReadCap` called from non-main context without cap — type error
- Cap closure of `main` matches expected set

---

<a id="14-io-session-protocols"></a>

## 14. IO Session Protocols

### 14.1 File: `lib/prologos/core/io-protocols.prologos`

```prologos
;; lib/prologos/core/io-protocols.prologos
ns prologos.core.io-protocols :no-prelude
use prologos.data.io-error :refer [IOError]

;; === File Read Protocol ===

session FileRead
  +>
    | :read-all  -> ? [Result String IOError] . end
    | :read-line -> ? [Result [Option String] IOError] . FileRead
    | :close     -> end

;; === File Write Protocol ===

session FileWrite
  +>
    | :write    -> ! String . FileWrite
    | :write-ln -> ! String . FileWrite
    | :flush    -> FileWrite
    | :close    -> end

;; === File Append Protocol ===

session FileAppend
  +>
    | :append -> ! String . FileAppend
    | :close  -> end

;; === Bidirectional File IO Protocol ===

session FileRW
  +>
    | :read-all  -> ? [Result String IOError] . FileRW
    | :read-line -> ? [Result [Option String] IOError] . FileRW
    | :write     -> ! String . FileRW
    | :write-ln  -> ! String . FileRW
    | :seek      -> ! Int . FileRW
    | :close     -> end
```

### 14.2 IO Service Processes

Each session type has a corresponding IO service process that implements the server
(dual) side. These processes run as IO bridge propagators — they watch the session
cell and perform the corresponding IO operation.

```prologos
;; Server-side process for FileRead (dual)
;; This is compiled into an IO bridge propagator, not a regular process.
defproc file-read-service : dual FileRead
  offer self
    | :read-all ->
        let data := [io-read-all self.resource]
        self ! data
        stop
    | :read-line ->
        let line := [io-read-line self.resource]
        self ! line
        rec
    | :close ->
        [io-close self.resource]
        stop
```

### 14.3 Composition: Protocols as Types

Following `PROTOCOLS_AS_TYPES.org`, IO protocols compose naturally through the mechanisms
described in that document: named continuations enable protocol sequencing, channel passing
enables protocol delegation, and capability requirements union across composed phases. The
examples below show the IO-specific surface; see `PROTOCOLS_AS_TYPES.org` for the full
composition model (§Protocol Composition, §Named Continuations, §Channel Passing).

```prologos
;; A logging protocol that composes FileWrite with a header phase
session LogSession
  ! String          ;; send log file path
  ? FileWrite       ;; receive a FileWrite channel back (protocol composition)
  end

;; Or inline: a protocol that reads then writes
session CopyProtocol
  ? Path . ? Path              ;; receive source and dest paths
  ? [Result String IOError]    ;; read phase result
  ! [Result Unit IOError]      ;; write phase result
  end
```

### 14.4 Protocol Composition Tests (IO-E3)

Following PROTOCOLS_AS_TYPES.org, IO protocols must compose with each other and with
user-defined protocols. This is the "composition is the test" principle — if IO protocols
don't compose, the architecture has a problem.

```prologos
;; A user protocol that composes with FileRead
session ReadAndProcess
  ? Path                               ;; receive a file path
  ? [Result String IOError]            ;; read result (from FileRead phase)
  ! [Result ProcessedData ProcessError] ;; processing result
  end

;; Protocol that transitions to FileWrite after reading
session CopyProtocol
  ? Path . ? Path                       ;; source and dest
  ? [Result String IOError]             ;; read phase
  ! [Result Unit IOError]               ;; write phase
  end
```

**Tests** (~5):
- IO protocol composes with user-defined continuation
- Duality preserved through composed IO protocol
- Capability requirements union across composed protocol phases
- Mixed IO protocol (FileRead phase → user processing → FileWrite phase)
- Type error when composition violates protocol structure

### 14.5 Error Handling: Phase 1 vs Phase 2

**Phase 1 approach** (this document): Each IO operation returns `Result A IOError`.
Error handling is explicit at each call site — the user pattern-matches on `ok`/`err`.
This is simple and works immediately.

**Phase 2 target**: Session `throws` (desugaring already exists at the elaboration level,
commit `78e6638`). Once the `throws` runtime is implemented, IO protocols can declare
error escalation:

```prologos
session FileRead throws IOError
  +>
    | :read-all  -> ? String . end        ;; no Result wrapper — throws on error
    | :read-line -> ? [Option String] . FileRead
    | :close     -> end
```

The `throws` desugaring wraps each operation with automatic error checking and escalation
to the session's error handler. This eliminates the `Result` wrapper at each step and is
the natural fit for session-based IO.

**Priority**: `throws` runtime is a **near-term priority** after Phase 1 IO lands. The
elaboration-level desugaring is already complete; only the runtime `catch`/`escalate`
match arms need implementation (~50-100 lines in `session-runtime.rkt`). This is tracked
in §24 Deferred Features.

### 14.6 Tests (~20 for IO-E1/E2, ~5 for IO-E3)

- `FileRead` session type duality check
- `FileWrite` session type duality check
- `FileRead` protocol: select `:read-all`, receive data
- `FileRead` protocol: select `:read-line` multiple times, then `:close`
- `FileWrite` protocol: select `:write` multiple times, then `:close`
- `FileAppend` protocol: append operations
- `FileRW` protocol: mixed read/write operations
- Protocol violation: read after close → contradiction
- Protocol violation: wrong branch selection → contradiction
- End-to-end: file-read-service with actual file

---

<a id="15-functional-io-fio-module"></a>

## 15. Functional IO (`fio`) Module

### 15.1 Design Rationale

The `fio` module provides an alternative to session-based IO for users who prefer
functional handle threading (familiar to Rust, Haskell, C programmers). It uses
linear types (`:1` multiplicity) to ensure handles are used exactly once.

This is the "Tier 1/2 alternative" from Design V2 §12.2 — simpler than session types
but still safe via linearity.

### 15.2 Internal Architecture (Decision D16)

Per Doc1 V2 §12.2: "Internally, `fio` handles are backed by session channels —
`with-open` creates a channel to the IO service but presents a handle API. This means
no code duplication in the runtime. `fio` is a thin ergonomic layer over `io`."

`fio` functions do NOT use direct FFI calls. They create session channels to the IO
bridge internally and present a linear handle API externally. This ensures:

- **Single IO path**: All IO goes through the same IO bridge propagators
- **Uniform mocking**: Swapping the IO propagator works for both `io` and `fio`
- **No code duplication**: `fio-read-all` uses the same IO bridge as `io`'s `read-file`
- **Consistent error handling**: Same `Result`/`IOError` from the same bridge

**Performance open question**: A one-shot `fio-read-all` creates a session channel,
installs one IO bridge cell, and runs the session protocol — all for a single read.
In practice this is one lattice cell transition (`io-bot → io-open → io-closed`),
not a heavyweight protocol, but it IS more overhead than a direct FFI call. If
profiling after Phase IO-F shows measurable overhead for one-shot operations, a
fast path (direct FFI for `fio-read-all`/`fio-write`) can be added without changing
the API. Until then, uniform architecture takes priority over speculative optimization.

The `Handle` type wraps a session channel endpoint, not a raw Racket port:

### 15.3 Handle Type

```prologos
;; lib/prologos/core/fio.prologos
ns prologos.core.fio :no-prelude
use prologos.data.path :refer [Path path-str]
use prologos.data.io-error :refer [IOError]

;; Handle wraps a session channel endpoint with linear ownership.
;; Internally backed by a FileRW session channel to the IO bridge.
;; The :1 multiplicity ensures exactly-once use.
type Handle := MkHandle ChannelEndpoint

;; Open a file, returning a linear handle
;; Internally: creates a session channel via proc-open, wraps in Handle
spec fio-open : Path Keyword -> Result Handle IOError
defn fio-open [p mode]
  ;; open p mode creates a session channel to IO bridge
  ;; wrap the endpoint in Handle for linear tracking
  ...

;; Read all content (consumes handle, returns new handle + data)
;; Internally: select :read-all on the wrapped channel, receive result
spec fio-read-all : Handle :1 -> <Handle :1 * Result String IOError>
defn fio-read-all [h]
  match h
    | MkHandle ch ->
        ;; Session protocol: select :read-all, receive Result
        select ch :read-all
        let result := ch ?
        [MkHandle ch, result]

;; Write content (consumes handle, returns new handle)
spec fio-write : Handle :1 String -> <Handle :1 * Result Unit IOError>
defn fio-write [h content]
  match h
    | MkHandle ch ->
        select ch :write
        ch ! content
        [MkHandle ch, ok unit]

;; Close handle (consumes handle, does not return it)
spec fio-close : Handle :1 -> Result Unit IOError
defn fio-close [h]
  match h
    | MkHandle ch ->
        select ch :close
        ok unit
```

### 15.4 Bracket Pattern: `fio-with-open`

```prologos
;; Bracket pattern for fio: opens, runs body with linear handle, closes.
;; The body receives a Handle :1 and must return (Handle :1 * A).
spec fio-with-open : Path Keyword <Handle :1 -> <Handle :1 * A>> -> Result A IOError
defn fio-with-open [p mode body]
  match [fio-open p mode]
    | ok h ->
        let [h2, result] := [body h]
        let _ := [fio-close h2]
        ok result
    | err e -> err e
```

### 15.5 Usage Example

```prologos
ns my-app
use prologos.core.fio

defn main []
  fio-with-open [path "data.txt"] :read fn [h]
    let [h2, result] := [fio-read-all h]
    match result
      | ok data -> [h2, [process data]]
      | err e -> [h2, [handle-error e]]
```

### 15.6 QTT Enforcement

The `:1` multiplicity on `Handle` is enforced by the QTT checker. If a handle is:
- Used zero times → QTT error: "linear value unused (resource leak)"
- Used more than once → QTT error: "linear value used more than once"

This is the same mechanism already used for session channel endpoints.

### 15.7 Tests (~15)

- `fio-open` returns a linear handle
- `fio-read-all` consumes and returns handle
- `fio-write` consumes and returns handle
- `fio-close` consumes handle (no return)
- QTT: handle used zero times → error
- QTT: handle used twice → error
- `fio-with-open` bracket: opens and closes correctly
- `fio-with-open` bracket: closes on error
- Read/write round-trip via fio
- `fio` functions infer correct capabilities

---

<a id="16-console-io"></a>

## 16. Console IO

### 16.1 Design

Console IO (`print`, `println`, `read-ln`) is the simplest IO operation and the most
commonly used (debugging, REPL interaction). It does NOT use session types — it's
direct FFI calls with capability inference.

Per Decision D18, console IO **infers `StdioCap`** via the standard capability
inference mechanism. The capability is `:0` erased (zero runtime cost) and invisible
to Tier 1 users — `main` has `SysCap` which subsumes `StdioCap`, so it "just works."
But the compiler tracks the authority chain: `cap-closure` shows console IO usage,
and security auditing can identify all I/O-performing functions.

### 16.2 Implementation

```prologos
;; In lib/prologos/core/io.prologos (alongside file IO)

spec print {_ :0 StdioCap} : String -> Unit
defn print [s]
  foreign io-display s

spec println {_ :0 StdioCap} : String -> Unit
defn println [s]
  foreign io-displayln s

spec read-ln {_ :0 StdioCap} : Result String IOError
defn read-ln []
  foreign io-read-ln
```

### 16.3 Prelude Inclusion (Decision D4, D18)

Per Decisions D4 and D18, **all standard console IO functions** are included in the
prelude: `print`, `println`, `read-ln`. These are debugging and interaction
essentials that belong in every program's default vocabulary.

All three infer `{_ :0 StdioCap}` via standard capability inference. For Tier 1 users
this is invisible — `main` provisions `SysCap` (which subsumes `StdioCap`), so
`println "hello"` works without the user ever seeing a capability annotation. But the
compiler knows: if a helper function calls `println`, its inferred cap set includes
`StdioCap`. This maintains the invariant that **a function's authority is exactly the
set of capabilities it receives as parameters** (CAPABILITY_SECURITY.md).

Session-based console IO (Tier 3, §16.4) additionally requires explicit `StdioCap`
in the `defproc` header.

```racket
;; In namespace.rkt, add to prelude-imports:
(imports [prologos::core::io :refer [print println read-ln]])
```

### 16.4 Session-Based Console (Optional, Tier 3)

For programs that want structured console IO with explicit capability control:

```prologos
session StdoutSession
  rec
    +>
      | :print   -> ! String . StdoutSession
      | :println -> ! String . StdoutSession
      | :done    -> end

session StdinSession
  rec
    +>
      | :read-line -> ? [Option String] . StdinSession
      | :done      -> end
```

These are provided in `io-protocols.prologos` and require `{stdio :0 StdioCap}` in
the process's capability set. The convenience functions in §16.2 do NOT use these
protocols — they use direct FFI calls and are cap-free per Decision D18.

### 16.5 Tests (~5, included in IO-D2)

- `println` outputs string with newline
- `print` outputs string without newline
- `read-ln` reads from stdin (test with mock)
- `println` infers `{StdioCap}` via cap inference (D18)
- `cap-closure` on a function calling `println` shows `StdioCap` in cap set
- `StdoutSession`/`StdinSession` require explicit `{stdio :0 StdioCap}` in defproc

---

<a id="17-csv-and-structured-data"></a>

## 17. CSV and Structured Data

### 17.1 CSV Parser

```prologos
;; lib/prologos/core/csv.prologos
ns prologos.core.csv :no-prelude
use prologos.core.io :refer [read-file write-file]
use prologos.data.path :refer [Path]
use prologos.data.io-error :refer [IOError]

;; Parse a CSV string into rows of fields
spec parse-csv : String -> List [List String]
defn parse-csv [s]
  ;; Split by newlines, then by commas
  ;; Handle quoted fields (RFC 4180)
  ...

;; Parse CSV with first row as headers → list of keyword maps
spec parse-csv-maps : String -> List [Map Keyword String]
defn parse-csv-maps [s]
  let rows := [parse-csv s]
  match rows
    | cons header rest ->
        let keys := [map string-to-keyword header]
        [map (fn [row] [zip-map keys row]) rest]
    | nil -> '[]
```

### 17.2 Convenience Functions

```prologos
spec read-csv : Path -> Result [List [List String]] IOError
defn read-csv [p]
  match [read-file p]
    | ok content -> ok [parse-csv content]
    | err e -> err e

spec read-csv-maps : Path -> Result [List [Map Keyword String]] IOError
defn read-csv-maps [p]
  match [read-file p]
    | ok content -> ok [parse-csv-maps content]
    | err e -> err e

spec write-csv : Path [List [List String]] -> Result Unit IOError
defn write-csv [p rows]
  let content := [csv-rows-to-string rows]
  [write-file p content]
```

### 17.3 Schema-Typed CSV (Dependent Send/Receive — Priority)

Schema-typed CSV is a first-class target for the IO library and a key motivator for
prioritizing dependent send/receive (Phase IO-J). When `!:`/`?:` are implemented,
CSV reading becomes type-safe against a schema:

```prologos
;; Schema-typed CSV reading — the killer app for dependent sessions
session TypedCsvRead {S : Schema}
  ?: header [List String]
  ? [List [Record S]]            ;; each row validates against schema
  end
```

This requires IO-J (dependent send/receive) to be complete. **IO-J should be
implemented before or in parallel with IO-G** — dependent sessions are the mechanism
that elevates CSV from "untyped maps" to "schema-validated records". Without this,
`read-csv-maps` returns `List [Map Keyword String]` with no static guarantees about
which keys exist or what types the values have.

Phase IO-G (CSV) initially ships with untyped maps (§17.1-17.2). Schema-typed CSV
(this subsection) upgrades when IO-J completes. Both can proceed in parallel.

### 17.4 Tests (~20)

- `parse-csv` splits simple CSV
- `parse-csv` handles quoted fields with commas
- `parse-csv` handles quoted fields with newlines
- `parse-csv` handles empty fields
- `parse-csv-maps` creates keyword maps from header row
- `read-csv` reads CSV from file
- `read-csv-maps` reads CSV with headers
- `write-csv` writes rows to file
- Round-trip: write then read CSV

---

<a id="18-capability-inference-pipeline-integration"></a>

## 18. Capability Inference Pipeline Integration

### 18.1 Current State

`capability-inference.rkt` implements a complete propagator-based transitive closure
algorithm for capability requirements. However, it's only accessible via REPL commands
(`(cap-closure name)` and `(cap-audit name cap)` in `driver.rkt` L502-515). It is NOT
wired into the normal compilation pipeline.

### 18.2 What Needs to Change

For Tier 1 progressive disclosure (users never write capability annotations), capability
inference must run automatically:

1. **After type-checking all definitions in a module**: Run `run-capability-inference`
   over the module's definitions
2. **Annotate `main` with inferred capabilities**: The runtime provides capabilities
   based on the inferred set
3. **Insufficient capabilities are a compiler error**: If a user writes
   `{fs :0 ReadCap}` but the function also needs `WriteCap`, this is an **error** —
   the function claims less authority than it exercises. This is a security violation
   (the declared capability set is insufficient to cover the actual operations).
4. **Over-declared authority is a compiler warning**: If a user writes
   `{fs :0 FsCap}` but the function only needs `ReadCap`, this is a **warning** —
   the function claims more authority than it uses (dead authority, violates POLA).
   This is the same pattern as W2002 (dead authority) in process cap warnings.

### 18.3 Implementation

```racket
;; In driver.rkt, after process-top-level-defs:

;; Run capability inference over all definitions in the module
(define cap-closures
  (run-capability-inference
    (hash-keys (current-global-env))
    (current-global-env)))

;; If 'main exists, attach inferred capabilities to its type
(when (hash-has-key? cap-closures 'main)
  (define main-caps (hash-ref cap-closures 'main))
  (unless (set-empty? main-caps)
    ;; Store for runtime to provide
    (current-main-capabilities main-caps)))
```

### 18.4 Limitation: Flat Cap Names Only

`extract-capability-requirements` in `capability-inference.rkt` (L130-141) only handles
`(expr-fvar name)` domains — plain capability names like `ReadCap`. Applied/dependent
caps like `(FileCap "/data")` are silently ignored. This is acceptable for Phase IO-A–H
(all caps are flat names). Dependent caps are Phase 7e-7g work.

### 18.5 Tests (~10)

- `defn f [] [read-file ...]` → cap closure includes `ReadCap`
- Transitive: `defn g [] [f]` → cap closure includes `ReadCap`
- `defn main [] [g]` → main inferred with `ReadCap`
- Explicit cap matches inference → no warning
- Explicit cap missing from inference → warning
- Multiple caps compose: `read-file` + `write-file` → `{ReadCap, WriteCap}`

---

<a id="19-dependent-capabilities"></a>

## 19. Dependent Capabilities

### 19.1 Motivation

Being able to specify *which file* a function has access to is fundamental to the
capability security model. Without dependent capabilities, all file IO functions require
a blanket `{ReadCap}` — granting access to the entire filesystem. With dependent
capabilities, authority can be scoped to specific paths:

```prologos
;; Without dependent caps: blanket filesystem access
spec read-config : Path -> Result Config IOError
;; Inferred: {fs :0 ReadCap}  — can read ANY file

;; With dependent caps: scoped to one path
spec read-config {cap :0 FileCap "/etc/app.conf"} : Result Config IOError
;; Can ONLY read /etc/app.conf — principle of least authority
```

This is the difference between "has filesystem access" and "has access to this specific
file" — the core value proposition of capability security.

### 19.2 Current State (Phases 7a-7d Complete)

Capability types as zero-method traits with `:0` erased binders are fully working:
- Parsing: `{cap :0 ReadCap}` in spec headers
- Type formation: capability traits participate in type checking
- Scope tracking: lexical capability resolution
- Functor-based resolution: trait instance lookup

**What's missing** (Phases 7e-7g, previously deferred):
- `cap-set` holds only symbols — cannot represent `[FileCap "/data"]`
- `extract-capability-requirements` (L130-141 of `capability-inference.rkt`) only
  matches `(expr-fvar name)` — silently ignores `(expr-app (expr-fvar 'FileCap) ...)`
- Cap-type bridge α/γ functions don't handle applied capability types
- No surface syntax for dependent cap requirements in foreign blocks

### 19.3 Design

#### 19.3.1 Cap-Set with Type Expressions

Currently `cap-set` is a `seteq` of symbols. It needs to hold arbitrary type expressions
for applied capabilities:

```racket
;; Current: (seteq 'ReadCap 'WriteCap)
;; New:     (set (cap-entry 'ReadCap #f)
;;               (cap-entry 'FileCap (expr-string "/data"))
;;               (cap-entry 'WriteCap #f))

(struct cap-entry (name index) #:transparent)
;; name: symbol — the capability trait name
;; index: #f for flat caps, or an expr for dependent caps

;; Subsumption: (cap-entry 'ReadCap #f) subsumes (cap-entry 'FileCap "/data")
;; iff ReadCap <: FileCap in the subtype registry
```

The cap-set becomes a `set` using `equal?` comparison (not `eq?`), since `cap-entry`
structs with expression indices need structural equality.

#### 19.3.2 `extract-capability-requirements` Extension

```racket
(define (extract-capability-requirements type)
  (let loop ([ty type] [caps (set)])  ;; set, not seteq
    (match ty
      [(expr-Pi mult dom cod)
       (define new-caps
         (cond
           ;; Flat cap: {fs :0 ReadCap}
           [(and (eq? mult 'm0)
                 (expr-fvar? dom)
                 (capability-type? (expr-fvar-name dom)))
            (set-add caps (cap-entry (expr-fvar-name dom) #f))]
           ;; Applied cap: {cap :0 [FileCap "/data"]}
           [(and (eq? mult 'm0)
                 (expr-app? dom)
                 (expr-fvar? (expr-app-fn dom))
                 (capability-type? (expr-fvar-name (expr-app-fn dom))))
            (set-add caps (cap-entry
                           (expr-fvar-name (expr-app-fn dom))
                           (expr-app-arg dom)))]
           [else caps]))
       (loop cod new-caps)]
      [_ caps])))
```

#### 19.3.3 Cap-Type Bridge Updates

The α (abstraction) and γ (concretization) Galois connection functions in
`cap-type-bridge.rkt` need to handle applied cap types:

```racket
;; α: type domain → cap domain
;; Currently: (expr-fvar 'ReadCap) → 'ReadCap
;; Extended:  (expr-app (expr-fvar 'FileCap) (expr-string "/data"))
;;            → (cap-entry 'FileCap (expr-string "/data"))

;; γ: cap domain → type domain
;; Currently: 'ReadCap → (expr-fvar 'ReadCap)
;; Extended:  (cap-entry 'FileCap (expr-string "/data"))
;;            → (expr-app (expr-fvar 'FileCap) (expr-string "/data"))
```

#### 19.3.4 Capability Subsumption

A function requiring `{FileCap "/data"}` is satisfied by a caller with `{FsCap}` —
the blanket cap subsumes the specific one. With union-typed composites (D17), the
subsumption chain is:

```
FileCap "/data" <: ReadCap <: FsCap (= ReadCap | WriteCap | ...) <: IOCap <: SysCap
```

The subsumption check becomes: for each required `cap-entry`, check if the provided
cap-set contains a subsuming entry. Flat caps always subsume their applied refinements.
Union type membership provides the subtype relationships — `ReadCap <: FsCap` because
`ReadCap` is a variant of the `FsCap` union.

#### 19.3.5 Dependent Cap in Convenience Functions

With dependent caps, the Tier 3 API becomes:

```prologos
;; Path-indexed read: can only read this specific file
spec read-config {cap :0 FileCap "/etc/app.conf"} : Result Config IOError
defn read-config []
  [read-file [path "/etc/app.conf"]]

;; Path-parameterized: cap depends on the path argument
spec read-specific {A : Type} {p : Path} {cap :0 FileCap p} : Result A IOError
defn read-specific [p]
  [read-file p]
```

Tier 1 and Tier 2 continue to use flat caps — `read-file` infers `{ReadCap}` (blanket).
Dependent caps are Tier 3 for security-conscious code.

### 19.4 Tests (~15)

- `cap-entry` with flat cap equals existing behavior
- `cap-entry` with applied cap (`FileCap "/data"`) round-trips
- `extract-capability-requirements` extracts flat caps (regression)
- `extract-capability-requirements` extracts applied caps
- Cap-set subsumption: `ReadCap` subsumes `FileCap "/data"`
- Cap-set subsumption: `FileCap "/data"` does NOT subsume `ReadCap`
- Cap-type bridge α: applied cap type → cap-entry
- Cap-type bridge γ: cap-entry → applied cap type
- Transitive inference with dependent caps through call chain
- End-to-end: `spec` with `{FileCap "/data"}` type-checks correctly
- End-to-end: mismatched path rejected
- `cap-closure` REPL command shows dependent caps
- `cap-audit` REPL command with path-indexed cap

---

<a id="20-io-test-infrastructure"></a>

## 20. IO Test Infrastructure

### 20.1 Challenge

IO operations interact with the filesystem, console, and (eventually) network. Testing
IO requires either real side effects (slow, non-deterministic, cleanup-prone) or mocking
(requires infrastructure).

### 20.2 Temp Directory Pattern (Phase IO-D onwards)

For file IO tests, use Racket's `make-temporary-directory` to create isolated test
directories:

```racket
;; In test-io-file-01.rkt
(define test-dir (make-temporary-directory))
(define test-file (build-path test-dir "test.txt"))

(define (cleanup!)
  (when (directory-exists? test-dir)
    (delete-directory/files test-dir)))

;; Each test writes to test-dir, reads back, checks result
;; cleanup! called in a dynamic-wind or test teardown
```

All IO integration tests create their own temp directory, write test files there, and
clean up after themselves. This avoids polluting the project tree and allows parallel
test execution.

### 20.3 IO Propagator Mocking (Phase 2+)

Per Decision D7, IO mocking works by swapping the IO propagator (server side) while
keeping the session protocol unchanged (client side). This is deferred to Phase 2+ but
the architecture supports it:

```racket
;; Future: mock IO propagator for testing
;; Instead of make-io-bridge-propagator (real IO):
;; Use make-mock-io-propagator that returns canned responses
;; Session client code is unchanged — it sees the same protocol
```

### 20.4 Console IO Mocking

For `println`/`read-ln` tests, use Racket's `with-output-to-string` and
`with-input-from-string` at the FFI bridge layer:

```racket
;; Capture println output
(define output
  (with-output-to-string
    (lambda () (run-prologos-expr '(println "hello")))))
(check-equal? output "hello\n")

;; Simulate read-ln input
(define result
  (with-input-from-string "user input\n"
    (lambda () (run-prologos-expr '(read-ln)))))
(check-equal? result (make-ok "user input"))
```

### 20.5 Mini-Capstone: File IO Integration Validation

After completing Phase IO-D (core file IO), run a mini-capstone integration test that
exercises the full path from Prologos source through the IO bridge to real filesystem
operations and back:

```racket
;; test-io-capstone-01.rkt — Integration capstone
;; 1. Parse + elaborate + type-check a Prologos program that reads/writes files
;; 2. Execute via session runtime with real IO bridge
;; 3. Verify file was created with correct contents
;; 4. Verify read-back matches
;; 5. Clean up temp directory
```

This validates that the entire pipeline (WS reader → parser → elaborator → type checker →
runtime → IO bridge → FFI → filesystem) works end-to-end.

---

<a id="21-target-example-programs"></a>

## 21. Target Example Programs

These examples from V2 §13 serve as concrete validation targets. Each maps to a phase
completion milestone — when the phase is done, the corresponding example should compile
and run correctly.

### 21.1 Hello World (Tier 1) — after IO-D2

```prologos
ns hello

[println "Hello, world!"]
```

No capabilities. No session types. No handles. Just works.
**Validates**: Console FFI, `println` in prelude, cap-free console (D18).

### 21.2 Read and Process a File (Tier 1) — after IO-D1 + IO-D5

```prologos
ns word-count

defn main []
  match [read-file [path "input.txt"]]
    | ok content ->
        let words := [split content " "]
        [println [format "Word count: {}" [length words]]]
    | err e ->
        [println [format "Error: {}" [show e]]]
```

**Validates**: `read-file`, `Path`, `IOError`, `defn main` as powerbox (D20),
capability inference (IO-H).

### 21.3 CSV Processing (Tier 1) — after IO-G2

```prologos
ns csv-process

defn main []
  match [read-csv-maps [path "employees.csv"]]
    | ok rows ->
        let names := |> rows
          filter [fn [r] [eq? [map-get r :dept] "Engineering"]]
          map [fn [r] [map-get r :name]]
        [println [format "Engineers: {}" names]]
    | err e ->
        [println [format "Error: {}" [show e]]]
```

**Validates**: CSV library, pipe operator, `defn main` powerbox.

### 21.4 Multi-File Processing (Tier 2) — after IO-D3

```prologos
ns merge-files

defn merge [input-paths output-path]
  let contents := [map read-file input-paths]
  let merged := [string-join [filter-map ok? contents] "\n"]
  [write-file output-path merged]
```

**Validates**: `read-file`/`write-file` composition, `with-open` bracket pattern.

### 21.5 Concurrent IO (Tier 3) — after IO-E2 + IO-D5

```prologos
ns concurrent-io

session WorkProtocol
  ? Path
  ! [Result String IOError]
  end

defproc file-loader : dual WorkProtocol {fs :0 ReadCap}
  path := self ?
  self ! [read-file path]
  stop

defproc main [args : List String] {sys :0 SysCap}
  let paths := [map path args]
  let results := [map (fn [p]
    new [my-ch worker-ch] : WorkProtocol
    spawn file-loader worker-ch ReadCap
    my-ch ! p
    my-ch ?) paths]
  [println [format "Loaded {} files" [length results]]]
  stop
```

**Validates**: Session protocols, `proc-open`, concurrent IO, capability subsumption
(ReadCap <: SysCap), `defproc main`.

---

<a id="22-module-structure-and-prelude"></a>

## 22. Module Structure and Prelude

### 22.1 Module Layout

```
lib/prologos/
  data/
    path.prologos            ;; Path type + pure operations
    io-error.prologos        ;; IOError data type
  core/
    io.prologos              ;; Session-based IO convenience functions
    fio.prologos             ;; Functional IO with linear handles
    io-bridge.prologos       ;; IO protocol definitions for bridge layer
    io-protocols.prologos    ;; FileRead/FileWrite/etc. session types
    csv.prologos             ;; CSV reading/writing
  io/
    fs.prologos              ;; Filesystem queries (exists?, list-dir)
    console.prologos         ;; Stdin/stdout/stderr (if separated from io.prologos)
```

All modules use `:no-prelude` (standard for library code, avoids circularity).

### 22.2 Prelude Additions

```racket
;; In namespace.rkt, add to prelude-imports list:
;; Console IO in prelude — standard debugging + interaction
(imports [prologos::core::io :refer [print println read-ln]])
(imports [prologos::data::path :refer [Path path]])
(imports [prologos::data::io-error :refer [IOError]])
```

File IO (`read-file`, `write-file`, etc.) requires explicit `use prologos.core.io`.
This follows Decision D4 — pure functions shouldn't see file IO by default, but
console IO (`print`, `println`, `read-ln`) belongs in the prelude as standard
debugging and interaction aids.

**Note**: The `prelude-imports` list in `namespace.rkt` uses `(imports [module::path :refer [...]])`
syntax with `::` separators (Racket-side), not dot-separated module paths. The `.prologos` files
use `use prologos.core.io :refer [...]` with dot separators (surface syntax).

### 22.3 Dependency Graph for `dep-graph.rkt`

New test files need entries in `tools/dep-graph.rkt`:

```racket
;; IO library tests depend on:
;; - syntax.rkt (expr-opaque)
;; - foreign.rkt (opaque marshalling)
;; - io-bridge.rkt (IO propagators)
;; - io-ffi.rkt (Racket FFI wrappers)
;; - session-runtime.rkt (proc-open)
;; - The .prologos library files they test
```

---

<a id="23-phased-implementation-roadmap"></a>

## 23. Phased Implementation Roadmap

### Dependency Graph

```
IO-A1 (Opaque FFI) ──┐
IO-A2 (Path/IOError)  ├── IO-B (IO Bridge) ── IO-C (Boundary Ops) ──┐
IO-A3 (IO Caps) ─────┘                                              │
                                                                     ├── IO-D (Core File IO + Console + with-open + FS Queries + main) ──┐
                                                                     │                                                                    │
                                                                     │   ┌── IO-E (Session Protocols + Composition Tests)                 │
                                                                     │   ├── IO-F (Functional IO)                                         │
                                                                     │   ├── IO-G (CSV)                                                   │
                                                                     └───┤                                                                │
                                                                         └── IO-H (Cap Inference) ── IO-I (Dependent Caps)               │

IO-J (Dep Send/Recv) ── no dependencies on IO-A through IO-I; can be done immediately
```

IO-E, IO-F, IO-G, IO-H, and IO-I are independent of each other (except IO-I depends on
IO-H for pipeline integration). They can be implemented in any order after IO-D.

**IO-J has no IO dependencies** — it fixes two small gaps in the existing session type
infrastructure. It can and should be implemented first, as dependent protocols are
essential for the IO library's typed session patterns.

**IO-A3** (IO capability extensions) has no code dependencies — it only adds new
`capability` and `subtype` declarations to `capabilities.prologos`. It should be done
early to establish the capability hierarchy before IO functions reference it.

---

### Phase IO-A: Opaque FFI and Foundation Types

#### IO-A1: Opaque Type Marshalling

**Goal**: `foreign.rkt` can pass opaque Racket values through the Prologos runtime.

**Files modified**:
| File | Change |
|------|--------|
| `racket/prologos/syntax.rkt` | Add `expr-opaque` (value + tag) and `expr-OpaqueType` (tag) structs |
| `racket/prologos/foreign.rkt` | Add opaque cases to `base-type-name`, `marshal-prologos->racket`, `marshal-racket->prologos` |
| `racket/prologos/pretty-print.rkt` | Add `expr-opaque` → `#<opaque:tag>` |
| `racket/prologos/reduction.rkt` | Add `expr-opaque` as value (no reduction rule) |
| `racket/prologos/zonk.rkt` | Pass-through for `expr-opaque` |
| `racket/prologos/substitution.rkt` | Pass-through for `expr-opaque` |

**Tests**: `tests/test-io-opaque-01.rkt` (~8 tests)
**Depends on**: Nothing

#### IO-A2: Path and IOError Types

**Goal**: `Path` and `IOError` types available as Prologos data types.

**Files created**:
| File | Content |
|------|---------|
| `lib/prologos/data/path.prologos` | `Path` type, `path`, `path-str`, `path-join`, `path-parent`, `path-extension`, `path-file-name` |
| `lib/prologos/data/io-error.prologos` | `IOError` type with 6 constructors |

**Files modified**:
| File | Change |
|------|--------|
| `tools/dep-graph.rkt` | Add test entries for path and io-error |

**Tests**: `tests/test-io-path-01.rkt` (~10 tests)
**Depends on**: Nothing (pure data types)

#### IO-A3: IO Capability Extensions

**Goal**: Revise `capabilities.prologos` to use **union types** for composite capabilities
(per CAPABILITY_SECURITY.md §Composite Union, Decision D17). Add new leaf capabilities.
See §4 for full design.

**Files modified**:
| File | Change |
|------|--------|
| `lib/prologos/core/capabilities.prologos` | Add `AppendCap`, `StatCap` leaves; revise `FsCap`, `NetCap` to union types; add `IOCap`, `SysCap` as union types |

**Revised `capabilities.prologos`**:
```prologos
;; Leaf capabilities — zero-method traits (authority proofs)
capability ReadCap       ;; read from filesystem
capability WriteCap      ;; write to filesystem
capability AppendCap     ;; append to files (distinct from overwrite)
capability StatCap       ;; query filesystem metadata
capability HttpCap       ;; make HTTP requests
capability StdioCap      ;; use stdin/stdout/stderr

;; Composite capabilities — union types (authority encompasses any variant)
type FsCap  = ReadCap | WriteCap | AppendCap | StatCap
type NetCap = HttpCap
type IOCap  = FsCap | NetCap | StdioCap
type SysCap = IOCap    ;; expands later: IOCap | SpawnCap | ClockCap
```

**Migration**: Removes standalone `capability FsCap`, `capability NetCap`, `capability SysCap`
declarations and their `subtype` declarations. Union membership provides the subtype
relationships automatically (`ReadCap <: FsCap` because `ReadCap` is a variant of `FsCap`).

**Tests**: `tests/test-io-cap-types-01.rkt` (~5 tests: parse, union type formation, subtype
subsumption via union membership, transitive attenuation)
**Depends on**: Nothing (pure declarations); but verify union-based subsumption works with
existing `subtype` registry (may need `auto-register-union-subtypes` in typing-core.rkt)

---

### Phase IO-B: IO Bridge Infrastructure

#### IO-B1: IO State Lattice

**Goal**: IO state lattice defined and tested independently of session runtime.

**Files created**:
| File | Content |
|------|---------|
| `racket/prologos/io-bridge.rkt` | `io-bot`, `io-top`, `io-opening`, `io-open`, `io-closed`; `io-state-merge`; `io-state-contradicts?` |

**Tests**: Part of `tests/test-io-bridge-01.rkt` (~5 lattice tests)
**Depends on**: IO-A1

#### IO-B2: IO Bridge Propagator

**Goal**: Side-effecting IO propagator that watches session cells and performs IO.

**File modified**: `racket/prologos/io-bridge.rkt` (extend)

**Functions added**:
- `make-io-bridge-propagator` — creates the side-effecting propagator closure
- `make-io-bridge-cell` — creates a fresh IO state cell in runtime network
- `io-bridge-open-file` — performs file open, transitions `io-opening` → `io-open`

**Tests**: Part of `tests/test-io-bridge-01.rkt` (~5 propagator tests)
**Depends on**: IO-B1

#### IO-B3: FFI Bridge to Racket

**Goal**: Racket file/console primitives wrapped and registered.

**Files created**:
| File | Content |
|------|---------|
| `racket/prologos/io-ffi.rkt` | `io-ffi-registry` hash; wrapper functions for Racket IO |

**Tests**: Part of `tests/test-io-bridge-01.rkt` (~5 FFI tests)
**Depends on**: IO-A1 (opaque marshalling)

**Total Phase IO-B tests**: ~15 in `tests/test-io-bridge-01.rkt`

---

### Phase IO-C: Boundary Operations Runtime

#### IO-C1: `proc-open` Runtime

**Goal**: `compile-live-process` handles `proc-open` with IO bridge integration.

**Files modified**:
| File | Change |
|------|--------|
| `racket/prologos/session-runtime.rkt` | Add `proc-open` match arm (before L636 fallback); add `rt-new-io-channel` function |
| `racket/prologos/session-runtime.rkt` | Add `(require "io-bridge.rkt")` |

**Functions added to `session-runtime.rkt`**:
- `rt-new-io-channel` — creates single-endpoint channel + IO state cell
- `proc-open` match arm — wires endpoint to IO bridge propagator

**Depends on**: IO-B

#### IO-C2: Integration Tests

**Tests**: `tests/test-io-boundary-01.rkt` (~12 tests)
- Open creates single-endpoint channel
- IO bridge cell transitions correctly
- File read via proc-open returns data
- File write via proc-open writes data
- Error handling: nonexistent file
- Close via session end

**Depends on**: IO-C1

---

### Phase IO-D: Core File IO Convenience Functions

#### IO-D1: File IO Functions

**Goal**: `read-file`, `write-file`, `read-lines`, `append-file` available.

**Files created**:
| File | Content |
|------|---------|
| `lib/prologos/core/io.prologos` | Convenience functions using direct FFI (initial approach) |

**Tests**: `tests/test-io-file-01.rkt` (~15 tests)
**Depends on**: IO-C (for the FFI infrastructure; initial impl may use direct FFI)

#### IO-D2: Console IO Functions

**Goal**: `print`, `println`, `read-ln` available.

**Added to**: `lib/prologos/core/io.prologos`

**Tests**: Part of `tests/test-io-file-01.rkt` (~5 console tests)
**Depends on**: IO-D1

#### IO-D3: `with-open` Macro

**Goal**: Bracketed resource management via `with-open` macro.

**Files modified**:
| File | Change |
|------|--------|
| `racket/prologos/macros.rkt` | Add `expand-with-open` + registration |

**Tests**: Part of `tests/test-io-file-02.rkt` (~10 tests)
**Depends on**: IO-D1

#### IO-D4: Filesystem Query Functions

**Goal**: `exists?`, `is-file?`, `is-dir?`, `list-dir` available. See §12 for full design.

**Files modified**:
| File | Change |
|------|--------|
| `lib/prologos/io/fs.prologos` | Query functions (NEW) |
| `racket/prologos/io-ffi.rkt` | Add `io-ffi-file-exists?`, `io-ffi-directory-exists?`, `io-ffi-directory-list` |

**Tests**: `tests/test-io-fs-01.rkt` (~8 tests)
**Depends on**: IO-D1 (needs FFI infrastructure)

#### IO-D5: `main` as Powerbox

**Goal**: Runtime provisions inferred capabilities to `main`; `defn main` desugars to
a process internally. See §13 for full design.

**Files modified**:
| File | Change |
|------|--------|
| `racket/prologos/driver.rkt` | Detect `main`, run cap inference, provision caps to runtime |
| `racket/prologos/macros.rkt` | `defn main` desugaring to `defproc __main_proc` |
| `racket/prologos/session-runtime.rkt` | Accept provisioned caps, create `SysCap` (or inferred subset) |

**Tests**: Part of `tests/test-io-main-01.rkt` (~8 tests)
**Depends on**: IO-D1, IO-H (cap inference must be wired in)

**Total Phase IO-D tests**: ~46 across `test-io-file-01.rkt`, `test-io-file-02.rkt`,
`test-io-fs-01.rkt`, and `test-io-main-01.rkt`

---

### Phase IO-E: File Session Protocols

#### IO-E1: Protocol Definitions

**Goal**: `FileRead`/`FileWrite`/`FileAppend`/`FileRW` session types defined.

**Files created**:
| File | Content |
|------|---------|
| `lib/prologos/core/io-protocols.prologos` | Session type definitions for file IO |

**Tests**: `tests/test-io-session-01.rkt` (~10 tests: duality checks, protocol validation)
**Depends on**: IO-D

#### IO-E2: Session-Based File IO

**Goal**: IO service processes; line-by-line reading via session protocol.

**Files modified**:
| File | Change |
|------|--------|
| `lib/prologos/core/io.prologos` | Upgrade convenience functions to use session protocol internally |
| `lib/prologos/io/fs.prologos` | Filesystem query functions (`exists?`, `list-dir`) |

**Tests**: `tests/test-io-session-02.rkt` (~10 tests)
**Depends on**: IO-E1

#### IO-E3: Protocol Composition Tests

**Goal**: Validate that IO protocols compose correctly with user-defined protocols.
See §14.4 for full design.

**Tests**: `tests/test-io-session-03.rkt` (~5 tests)
- IO protocol embedded in a user-defined application protocol
- Sequential composition of `FileRead` then `FileWrite`
- Named continuation composition
- IO protocol passed through a forwarder process

**Depends on**: IO-E1, IO-E2

**Total Phase IO-E tests**: ~25 across `test-io-session-01.rkt` through `test-io-session-03.rkt`

---

### Phase IO-F: Functional IO Module

#### IO-F1: Linear Handle Type

**Goal**: `Handle :1` type; `fio-read-all`, `fio-write`, `fio-close`.

**Files created**:
| File | Content |
|------|---------|
| `lib/prologos/core/fio.prologos` | Handle type, fio functions with linear handle threading |

**Tests**: `tests/test-io-fio-01.rkt` (~10 tests: handle lifecycle, QTT enforcement)
**Depends on**: IO-D (needs FFI infrastructure)

#### IO-F2: fio Bracket Pattern

**Goal**: `fio-with-open` bracket pattern.

**Added to**: `lib/prologos/core/fio.prologos`

**Tests**: Part of `tests/test-io-fio-01.rkt` (~5 tests)
**Depends on**: IO-F1

**Total Phase IO-F tests**: ~15

---

### Phase IO-G: CSV and Structured Data

#### IO-G1: CSV Parser

**Goal**: Pure CSV parsing functions.

**Files created**:
| File | Content |
|------|---------|
| `lib/prologos/core/csv.prologos` | `parse-csv`, `parse-csv-maps`, `csv-rows-to-string` |

**Tests**: `tests/test-io-csv-01.rkt` (~12 tests: parsing, quoting, edge cases)
**Depends on**: Nothing (pure functions), but file-based tests need IO-D

#### IO-G2: CSV File Functions

**Goal**: `read-csv`, `read-csv-maps`, `write-csv` file operations.

**Added to**: `lib/prologos/core/csv.prologos`

**Tests**: Part of `tests/test-io-csv-01.rkt` (~8 tests)
**Depends on**: IO-D + IO-G1

**Total Phase IO-G tests**: ~20

---

### Phase IO-H: Capability Inference Integration

#### IO-H1: Wire Inference into Compilation Pipeline

**Goal**: `run-capability-inference` runs automatically after type-checking a module.

**Files modified**:
| File | Change |
|------|--------|
| `racket/prologos/driver.rkt` | Call `run-capability-inference` after `process-top-level-defs`; store main caps |
| `racket/prologos/capability-inference.rkt` | Add `current-main-capabilities` parameter |
| `racket/prologos/namespace.rkt` | Provide inferred caps to runtime |

**Tests**: `tests/test-io-cap-01.rkt` (~10 tests)
- `read-file` call infers `ReadCap`
- Transitive inference through call chain
- `main` accumulates all caps
- Warning on cap mismatch

**Depends on**: IO-D (needs IO functions to test against)

---

### Phase IO-I: Dependent Capabilities

#### IO-I1: Cap-Set with Type Expressions

**Goal**: `cap-set` holds `cap-entry` structs (name + optional index) instead of bare symbols.

**Files modified**:
| File | Change |
|------|--------|
| `racket/prologos/capability-inference.rkt` | `cap-entry` struct; update `cap-set` from `seteq` to `set`; update all cap-set operations |

**Tests**: Part of `tests/test-io-dep-cap-01.rkt` (~4 tests)
**Depends on**: IO-H (cap inference pipeline must be wired in)

#### IO-I2: `extract-capability-requirements` for Applied Caps

**Goal**: `extract-capability-requirements` recognizes `(expr-app (expr-fvar 'FileCap) ...)`.

**Files modified**:
| File | Change |
|------|--------|
| `racket/prologos/capability-inference.rkt` | Extend `extract-capability-requirements` match for `expr-app` |

**Tests**: Part of `tests/test-io-dep-cap-01.rkt` (~3 tests)
**Depends on**: IO-I1

#### IO-I3: Cap-Type Bridge for Applied Caps

**Goal**: α/γ Galois connection handles `expr-app` capability types.

**Files modified**:
| File | Change |
|------|--------|
| `racket/prologos/cap-type-bridge.rkt` | Extend α (type→cap) and γ (cap→type) for applied caps |

**Tests**: Part of `tests/test-io-dep-cap-01.rkt` (~4 tests)
**Depends on**: IO-I1

#### IO-I4: Path-Indexed Capability End-to-End

**Goal**: Full dependent capability flow — spec with `{FileCap "/data"}`, type-check, inference, subsumption.

**Tests**: `tests/test-io-dep-cap-02.rkt` (~4 end-to-end tests)
**Depends on**: IO-I2, IO-I3

**Total Phase IO-I tests**: ~15 across `test-io-dep-cap-01.rkt` and `test-io-dep-cap-02.rkt`

---

### Phase IO-J: Dependent Send/Receive

**Priority**: HIGH — no IO dependencies, can be implemented immediately.
Only two small gaps remain (see §8 for full analysis).

#### IO-J1: Elaborator Binder Scope

**Goal**: `surf-sess-dsend`/`surf-sess-drecv` extend gamma with the bound variable
when elaborating the continuation, so `?: n Nat . ? [Vec String n] . end` resolves `n`.

**Files modified**:
| File | Change |
|------|--------|
| `racket/prologos/elaborator.rkt` | L3201-3215: extend gamma with binder in `surf-sess-dsend`/`surf-sess-drecv` cases (~10 lines) |

**Tests**: Part of `tests/test-io-dep-session-01.rkt` (~5 tests)
**Depends on**: Nothing — all other layers are complete

#### IO-J2: Runtime Dependent Send/Recv

**Goal**: `sess-send-like?`/`sess-recv-like?` include `sess-dsend`/`sess-drecv`;
`compile-live-process` applies `substS` to substitute actual values into dependent
continuation session types.

**Files modified**:
| File | Change |
|------|--------|
| `racket/prologos/session-runtime.rkt` | L64-70: extend predicates + cont accessors for dsend/drecv (~8 lines) |
| `racket/prologos/session-runtime.rkt` | L428-485: add `substS` application in send path for `sess-dsend` (~5 lines) |

**Tests**: Part of `tests/test-io-dep-session-01.rkt` (~5 tests)
**Depends on**: IO-J1

#### IO-J3: Grammar Update + E2E Tests

**Goal**: Update `grammar.ebnf` with WS-mode `!:` / `?:` syntax (currently only documents
sexp forms). Full end-to-end tests through WS reader → preparse → parse → elaborate →
type-check → runtime for dependent session types.

**Files modified**:
| File | Change |
|------|--------|
| `docs/spec/grammar.ebnf` | Add WS-mode `!: name Type` / `?: name Type` operator syntax |
| `docs/spec/grammar.org` | Update prose companion with examples |

**Tests**: `tests/test-io-dep-session-02.rkt` (~8 E2E tests)
- `?: n Nat . ? [Vec String n] . end` — length-indexed recv
- `!: format Keyword . ? [FormatData format] . end` — negotiated protocol
- Duality of dependent session types
- Process runtime with dependent send/recv: values substituted correctly
- Type error on mismatched dependent type

**Depends on**: IO-J2

**Total Phase IO-J tests**: ~18 across `test-io-dep-session-01.rkt` and `test-io-dep-session-02.rkt`

---

### Summary Table

| Phase | Sub-phase | Description | Tests | Depends On |
|-------|-----------|-------------|-------|------------|
| IO-A | A1 | Opaque type marshalling | ~8 | — |
| IO-A | A2 | Path + IOError types | ~10 | — |
| IO-A | A3 | IO capability extensions | ~5 | — |
| IO-B | B1 | IO state lattice | ~5 | A1 |
| IO-B | B2 | IO bridge propagator | ~5 | B1 |
| IO-B | B3 | FFI bridge to Racket | ~5 | A1 |
| IO-C | C1 | `proc-open` runtime | — | B |
| IO-C | C2 | Integration tests | ~12 | C1 |
| IO-D | D1 | File IO functions | ~15 | C |
| IO-D | D2 | Console IO functions | ~5 | D1 |
| IO-D | D3 | `with-open` macro | ~10 | D1 |
| IO-D | D4 | Filesystem query functions | ~8 | D1 |
| IO-D | D5 | `main` as powerbox | ~8 | D1, H |
| IO-E | E1 | Protocol definitions | ~10 | D |
| IO-E | E2 | Session-based file IO | ~10 | E1 |
| IO-E | E3 | Protocol composition tests | ~5 | E1, E2 |
| IO-F | F1 | Linear handle type | ~10 | D |
| IO-F | F2 | fio bracket pattern | ~5 | F1 |
| IO-G | G1 | CSV parser | ~12 | — (pure) |
| IO-G | G2 | CSV file functions | ~8 | D, G1 |
| IO-H | H1 | Cap inference pipeline | ~10 | D |
| IO-I | I1 | Cap-set with type expressions | ~4 | H |
| IO-I | I2 | `extract-capability-requirements` for `expr-app` | ~3 | I1 |
| IO-I | I3 | Cap-type bridge for applied caps | ~4 | I1 |
| IO-I | I4 | Path-indexed cap E2E | ~4 | I2, I3 |
| IO-J | J1 | Elaborator binder scope | ~5 | — (independent) |
| IO-J | J2 | Runtime dep send/recv | ~5 | J1 |
| IO-J | J3 | Grammar + E2E tests | ~8 | J2 |
| **Total** | | | **~199** | |

---

<a id="24-deferred-features"></a>

## 24. Deferred Features

| Feature | Reason | Phase | Blocked On |
|---------|--------|-------|------------|
| Network IO (`connect`/`listen`) | Different FFI layer (sockets) | IO-K | IO-B infrastructure |
| Database IO (`db-open`, SQLite) | Opaque db connections + SQL | IO-L | IO-A1 (opaque) + Racket `db` lib |
| Relational integration (`:source csv`) | Depends on relational language maturity | IO-M | CSV + relational subsystem |
| Dependent caps in foreign blocks | `:requires [FileCap p]` syntax | IO-N | IO-I (dependent caps) |
| `Bytes` type | Not needed for text IO | Phase 2 | Nothing |
| Streaming/lazy IO | LSeq + handle lifetime management | Phase 2+ | `Bytes` + lazy evaluation |
| IO mocking framework | Swap IO propagators in test context | Phase 2+ | IO-B infrastructure |
| `proc-connect` runtime | Same pattern as `proc-open`, different FFI | IO-K | IO-C pattern |
| `proc-listen` runtime | Same pattern as `proc-open`, different FFI | IO-K | IO-C pattern |
| Session `throws` / error escalation | Session error handling via `throws` clause. Desugaring exists (commit `78e6638`); runtime `catch`/`escalate` match arms needed (~50-100 lines). **Near-term priority** after Phase 1 IO lands — see §14.5. | Post IO-E | Session runtime error model (elaboration done) |
| SQLite capstone integration | End-to-end DB IO with opaque handles + session protocols | IO-L+ | IO-L + IO-E patterns |
| IO + relational integration | Narrowing, tabling, and mode constraints for IO in logic programming context. How do `defr` relations interact with IO effects? Requires clarifying the semantics of IO in a relational/backtracking context — side effects must be controlled or prohibited during search. | Phase 3+ | Relational subsystem maturity + IO-E |

### IO Error Code Range (Decision D21)

IO and capability errors use the `E4xxx` range:

| Range | Category | Examples |
|-------|----------|----------|
| E4001-E4099 | File IO errors | File not found, permission denied, path invalid |
| E4100-E4199 | Console IO errors | Stdin closed, encoding error |
| E4200-E4299 | Network IO errors | Connection refused, timeout (Phase 2+) |
| E4300-E4399 | Capability errors | Missing capability, cap subsumption failure |
| E4400-E4499 | Session IO errors | IO bridge failure, protocol violation in IO context |

All deferred items are tracked in `docs/tracking/DEFERRED.md`.

---

<a id="25-references"></a>

## 25. References

### Predecessor Documents
- `docs/tracking/2026-03-05_IO_LIBRARY_DESIGN_V2.md` — Phase I API design + gap analysis
- `docs/tracking/2026-03-01_1200_IO_LIBRARY_DESIGN.md` — Original IO design (World token)
- `docs/tracking/2026-03-03_SESSION_TYPE_DESIGN.md` — Session type design (§12: IO integration)
- `docs/tracking/2026-03-03_SESSION_TYPE_IMPL_PLAN.md` — Session type implementation plan
- `docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md` — Capability system design

### Design Principles
- `docs/tracking/principles/CAPABILITY_SECURITY.md` — Capability security model
- `docs/tracking/principles/PROTOCOLS_AS_TYPES.org` — Protocol composition through types
- `docs/tracking/principles/DESIGN_PRINCIPLES.org` — Core design principles
- `docs/tracking/principles/DESIGN_METHODOLOGY.md` — Five-phase methodology
- `docs/tracking/principles/ERGONOMICS.org` — Progressive disclosure tiers

### Implementation Files (Current State)
- `racket/prologos/syntax.rkt` — Expression AST (1076 lines)
- `racket/prologos/foreign.rkt` — FFI marshalling (164 lines)
- `racket/prologos/session-runtime.rkt` — Process compiler (673 lines)
- `racket/prologos/sessions.rkt` — Session type AST (126 lines)
- `racket/prologos/processes.rkt` — Process AST (94 lines)
- `racket/prologos/typing-sessions.rkt` — Process typing (~280 lines)
- `racket/prologos/capability-inference.rkt` — Cap inference (546 lines)
- `racket/prologos/macros.rkt` — Macro system incl. `with-transient`
- `racket/prologos/driver.rkt` — Compilation driver

### Deferred Work
- `docs/tracking/DEFERRED.md` — IO Library section + Capabilities Phase 7e-7g
