# IO Library Implementation Design

**Status**: Design Phase (Phase II)
**Predecessor**: `docs/tracking/2026-03-05_IO_LIBRARY_DESIGN_V2.md` (Phase I — API research + gap analysis)
**Template**: Follows the format of `docs/tracking/2026-03-03_SESSION_TYPE_DESIGN.md`
**Date**: 2026-03-05

---

## Progress Tracker

| Phase | Sub-phase | Status | Commit | Notes |
|-------|-----------|--------|--------|-------|
| IO-A | A1: Opaque type marshalling | | | `expr-opaque` + `foreign.rkt` |
| IO-A | A2: Path + IOError types | | | String wrapper, 6 error ctors |
| IO-B | B1: IO state lattice | | | `io-bridge.rkt` |
| IO-B | B2: IO bridge propagator | | | Side-effecting fire-fn |
| IO-B | B3: FFI bridge to Racket | | | `io-ffi.rkt` |
| IO-C | C1: `proc-open` runtime | | | `compile-live-process` match arm |
| IO-C | C2: Integration tests | | | Open + session + IO bridge E2E |
| IO-D | D1: File IO functions | | | `read-file`, `write-file`, etc. |
| IO-D | D2: Console IO functions | | | `print`, `println`, `read-ln` |
| IO-D | D3: `with-open` macro | | | Bracket pattern |
| IO-E | E1: Protocol definitions | | | `FileRead`/`FileWrite`/`FileRW` |
| IO-E | E2: Session-based file IO | | | IO service processes |
| IO-F | F1: Linear handle type | | | `Handle :1`, fio functions |
| IO-F | F2: fio bracket pattern | | | `fio-with-open` |
| IO-G | G1: CSV parser | | | RFC 4180 parsing |
| IO-G | G2: CSV file functions | | | `read-csv`, `write-csv` |
| IO-H | H1: Cap inference pipeline | | | Wire into `driver.rkt` |
| IO-I | I1: `cap-set` with type exprs | | | Extend cap-set for applied caps |
| IO-I | I2: `extract-capability-requirements` for `expr-app` | | | `FileCap "/data"` extraction |
| IO-I | I3: Cap-type bridge for applied caps | | | α/γ for `expr-app` cap types |
| IO-I | I4: Path-indexed cap tests | | | End-to-end dependent caps |

---

## Table of Contents

1. [Document Purpose](#1-document-purpose)
2. [Design Decisions Summary](#2-design-decisions-summary)
3. [Prerequisites: What's Already Built](#3-prerequisites)
4. [Opaque Type Marshalling](#4-opaque-type-marshalling)
5. [IO Bridge Architecture](#5-io-bridge-architecture)
6. [Boundary Operations Runtime](#6-boundary-operations-runtime)
7. [Dependent Send/Receive](#7-dependent-sendreceive)
8. [Path and IOError Types](#8-path-and-ioerror-types)
9. [FFI Bridge Layer](#9-ffi-bridge-layer)
10. [Convenience Functions and `with-open`](#10-convenience-functions-and-with-open)
11. [IO Session Protocols](#11-io-session-protocols)
12. [Functional IO (`fio`) Module](#12-functional-io-fio-module)
13. [Console IO](#13-console-io)
14. [CSV and Structured Data](#14-csv-and-structured-data)
15. [Capability Inference Pipeline Integration](#15-capability-inference-pipeline-integration)
16. [Dependent Capabilities](#16-dependent-capabilities)
17. [Module Structure and Prelude](#17-module-structure-and-prelude)
18. [Phased Implementation Roadmap](#18-phased-implementation-roadmap)
19. [Deferred Features](#19-deferred-features)
20. [References](#20-references)

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

**In scope** (Phases IO-A through IO-I):
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

**Out of scope** (see §19 Deferred):
- Dependent send/receive (`!:`/`?:`) — blocked on reader/parser token work
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
| D4 | Prelude inclusion | `println` in prelude; file IO requires `use prologos.core.io` | V2 §12.1 |
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

### What Exists But Is NOT Implemented at Runtime

| Component | What Exists | What's Missing |
|-----------|-------------|----------------|
| `proc-open` | Struct, parser, elaborator, type-checker | `compile-live-process` match arm — currently falls through silently at L636 |
| `proc-connect` | Struct, parser, elaborator, type-checker | Same — no runtime match arm |
| `proc-listen` | Struct, parser, elaborator, type-checker | Same — no runtime match arm |
| `sess-dsend`/`sess-drecv` | Struct, `dual`/`substS`/`unfoldS` | No WS reader tokens (`!:`/`?:`); no runtime match arm |
| Cap inference in compile path | `run-capability-inference` function | Wired into REPL `(cap-closure)` only, not normal compilation |

---

<a id="4-opaque-type-marshalling"></a>

## 4. Opaque Type Marshalling

### 4.1 Problem

`foreign.rkt` marshals between Prologos values and Racket values for a fixed set of base
types (Nat, Int, Rat, Bool, Unit, Char, String). IO operations need to pass Racket-native
opaque values (file ports, database connections, network sockets) through the Prologos
runtime without interpretation.

### 4.2 Design

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

### 4.3 Alternative Considered: Simple Pass-Through

A simpler approach: add a single `'Opaque` symbol to `base-type-name` without tag
differentiation. This loses type safety (all opaque values are the same type). The tagged
approach costs ~5 more lines but preserves the invariant that different opaque types
(file port vs. db connection) are distinct at the type level.

### 4.4 AST Pipeline Impact

| File | Change |
|------|--------|
| `syntax.rkt` | Add `expr-opaque`, `expr-OpaqueType` structs |
| `foreign.rkt` | Add opaque cases to `base-type-name`, `marshal-prologos->racket`, `marshal-racket->prologos` |
| `pretty-print.rkt` | Add `expr-opaque` → `#<opaque:tag>` display |
| `reduction.rkt` | `expr-opaque` is a value (no reduction needed) |
| `zonk.rkt` | Pass-through for `expr-opaque` |
| `substitution.rkt` | Pass-through for `expr-opaque` (no free variables) |

### 4.5 Tests (~8)

- Marshal Racket port → `expr-opaque` → Racket port round-trip
- Tagged opaque types are distinct (`'file-port` vs `'db-conn`)
- Pretty-print displays `#<opaque:file-port>`
- Opaque values survive reduction (are values)
- Error on marshalling unsupported types (existing behavior preserved)

---

<a id="5-io-bridge-architecture"></a>

## 5. IO Bridge Architecture

### 5.1 Overview

The IO bridge is the mechanism by which session protocol operations (`!`/`?`/`select`/
`offer`) on IO channels translate into actual side effects (reading/writing files, network
operations). It sits between the session runtime and external resources, implementing the
"double-boundary" model from Session Type Design §12.5.

### 5.2 IO State Lattice

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

### 5.3 IO Bridge Propagator

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

### 5.4 Integration with `run-to-quiescence`

IO bridge propagators participate in the same `run-to-quiescence` loop as session
propagators. The scheduling is:

1. Session propagators fire first (advancing protocol state)
2. IO bridge propagators fire when session cells change (performing IO)
3. IO results flow back through msg-in cells
4. Session propagators fire again (advancing to next protocol step)
5. Repeat until quiescence

No special scheduling priority is needed — the data dependency graph naturally orders
session advancement before IO operations before result delivery.

### 5.5 Error Handling in the IO Bridge

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

### 5.6 File: `racket/prologos/io-bridge.rkt`

**Estimated size**: ~200 lines

**Provides**:
- `io-bot`, `io-top`, `io-opening`, `io-open`, `io-closed` — lattice elements
- `io-state-merge`, `io-state-contradicts?` — lattice operations
- `make-io-bridge-propagator` — creates a side-effecting IO propagator
- `make-io-bridge-cell` — creates a fresh IO state cell in a runtime network
- `io-bridge-open-file` — performs the `open` side effect, returns `io-open` state

**Requires**: `prop-network.rkt`, `sessions.rkt`, `syntax.rkt`

---

<a id="6-boundary-operations-runtime"></a>

## 6. Boundary Operations Runtime

### 6.1 Problem

`proc-open`, `proc-connect`, and `proc-listen` are parsed, elaborated, and type-checked,
but `compile-live-process` in `session-runtime.rkt` (L636) falls through silently for
these forms. They need match arms that create IO channels.

### 6.2 `proc-open` — File Open

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

### 6.3 `rt-new-io-channel` — Single-Endpoint Channel Creation

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

### 6.4 `proc-connect` and `proc-listen` — Deferred

`proc-connect` (network) and `proc-listen` (server socket) follow the same pattern as
`proc-open` but with different FFI calls. They are deferred to Phase 2+ (network IO).
The infrastructure built for `proc-open` (single-endpoint channels, IO bridge propagators)
directly generalizes to these cases.

### 6.5 Tests (~12)

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

<a id="7-dependent-sendreceive"></a>

## 7. Dependent Send/Receive

### 7.1 Current State

`sess-dsend` and `sess-drecv` structs exist in `sessions.rkt` (L33-34). `dual`, `substS`,
and `unfoldS` all handle them correctly. But:

- **No WS reader tokens**: `!:` and `?:` are not tokenized
- **No elaboration binding**: The value sent/received is not bound in the continuation scope
- **No runtime match**: `compile-live-process` has no case for dependent sessions

### 7.2 Why This Is Deferred

Dependent send/receive is needed for schema-typed IO (e.g., "send a number `n`, then
receive exactly `n` strings"). This is a powerful feature but not required for basic
file IO, where the protocol is static. The core IO library (Phases IO-A through IO-H)
uses only non-dependent session types.

### 7.3 What Phases IO-A–H Build Without It

All IO session protocols in this design use non-dependent `sess-send`/`sess-recv`:

```prologos
session FileRead
  +>
    | :read-all  -> ? [Result String IOError] . end
    | :read-line -> ? [Result [Option String] IOError] . FileRead
    | :close     -> end
```

No value binds in the continuation. The type of the next operation does not depend on
the value sent or received. This covers all of: file read, file write, CSV, console IO.

### 7.4 Implementation Sketch (for Phase IO-I)

When dependent send/receive is eventually implemented:

1. **WS reader**: Tokenize `!:` as `$sess-dep-send`, `?:` as `$sess-dep-recv`
2. **Parser**: `parse-session-op` handles `$sess-dep-send`/`$sess-dep-recv` with a
   binder name and type: `?: n Nat . ? [Vec String n] . end`
3. **Elaboration**: Bind the variable in the continuation scope (like Pi binding)
4. **Runtime**: `sess-dsend-like?`/`sess-drecv-like?` predicates; `compile-live-process`
   captures the actual value and substitutes it into the continuation session type

---

<a id="8-path-and-ioerror-types"></a>

## 8. Path and IOError Types

### 8.1 Path Type

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

spec path-join : Path -> Path -> Path
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

### 8.2 IOError Type

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

### 8.3 Racket-Side Error Mapping

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

### 8.4 Tests (~10)

- `Path` constructor and accessors round-trip
- `path-join` concatenates with separator
- `path-parent`, `path-extension`, `path-file-name` extract correctly
- `IOError` constructors and pattern matching
- Racket exception → `IOError` mapping

---

<a id="9-ffi-bridge-layer"></a>

## 9. FFI Bridge Layer

### 9.1 File: `racket/prologos/io-ffi.rkt`

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

### 9.2 Registration in Namespace

These FFI functions are registered in the namespace during module loading, similar to how
`register-foreign!` works in `driver.rkt`. The `io-ffi-registry` is imported by the
IO library modules and registered as foreign bindings.

### 9.3 Two Paths for IO

There are two ways IO operations reach the external world:

1. **IO bridge propagator path** (session-based IO, `prologos.core.io`):
   Process → session channel → IO bridge propagator → Racket IO → results back through channel

2. **Direct FFI path** (functional IO, `prologos.core.fio`):
   Prologos function → `(foreign ...)` call → `io-ffi.rkt` → Racket IO → marshalled result

Both paths go through the same Racket IO functions. The difference is how they're
invoked and how linearity/capability checking works.

---

<a id="10-convenience-functions-and-with-open"></a>

## 10. Convenience Functions and `with-open`

### 10.1 Core IO Module: `lib/prologos/core/io.prologos`

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

spec write-file : Path -> String -> Result Unit IOError
defn write-file [p content]
  ...

spec read-lines : Path -> Result [List String] IOError
defn read-lines [p]
  match [read-file p]
    | ok content -> ok [split content "\n"]
    | err e -> err e

spec append-file : Path -> String -> Result Unit IOError
defn append-file [p content]
  ...

;; === Tier 2: Bracketed resource management ===

spec with-open : Path -> Keyword -> <(ch : FileRW) -> A> -> Result A IOError
defn with-open [p mode body]
  ;; Opens a session channel, passes to body, closes on exit
  ...
```

### 10.2 Implementation Strategy for Convenience Functions

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

### 10.3 `with-open` Macro

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

### 10.4 Tests (~30)

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

<a id="11-io-session-protocols"></a>

## 11. IO Session Protocols

### 11.1 File: `lib/prologos/core/io-protocols.prologos`

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

### 11.2 IO Service Processes

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

### 11.3 Composition: Protocols as Types

Following PROTOCOLS_AS_TYPES.org, IO protocols compose naturally:

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

### 11.4 Tests (~20)

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

<a id="12-functional-io-fio-module"></a>

## 12. Functional IO (`fio`) Module

### 12.1 Design Rationale

The `fio` module provides an alternative to session-based IO for users who prefer
functional handle threading (familiar to Rust, Haskell, C programmers). It uses
linear types (`:1` multiplicity) to ensure handles are used exactly once.

This is the "Tier 1/2 alternative" from Design V2 §12.2 — simpler than session types
but still safe via linearity.

### 12.2 Handle Type

```prologos
;; lib/prologos/core/fio.prologos
ns prologos.core.fio :no-prelude
use prologos.data.path :refer [Path path-str]
use prologos.data.io-error :refer [IOError]

;; Handle wraps an opaque file port with linear ownership.
;; The :1 multiplicity ensures exactly-once use.
type Handle := MkHandle OpaqueFilePort

;; Open a file, returning a linear handle
spec fio-open : Path -> Keyword -> Result Handle IOError
defn fio-open [p mode]
  foreign io-ffi-open [path-str p] mode

;; Read all content (consumes handle, returns new handle + data)
spec fio-read-all : Handle :1 -> <Handle :1 * Result String IOError>
defn fio-read-all [h]
  match h
    | MkHandle port ->
        let data := foreign io-read-string port
        [MkHandle port, ok data]

;; Write content (consumes handle, returns new handle)
spec fio-write : Handle :1 -> String -> <Handle :1 * Result Unit IOError>
defn fio-write [h content]
  match h
    | MkHandle port ->
        foreign io-write-string port content
        [MkHandle port, ok unit]

;; Close handle (consumes handle, does not return it)
spec fio-close : Handle :1 -> Result Unit IOError
defn fio-close [h]
  match h
    | MkHandle port ->
        foreign io-close port
        ok unit
```

### 12.3 Bracket Pattern: `fio-with-open`

```prologos
;; Bracket pattern for fio: opens, runs body with linear handle, closes.
;; The body receives a Handle :1 and must return (Handle :1 * A).
spec fio-with-open : Path -> Keyword -> <Handle :1 -> <Handle :1 * A>> -> Result A IOError
defn fio-with-open [p mode body]
  match [fio-open p mode]
    | ok h ->
        let [h2, result] := [body h]
        let _ := [fio-close h2]
        ok result
    | err e -> err e
```

### 12.4 Usage Example

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

### 12.5 QTT Enforcement

The `:1` multiplicity on `Handle` is enforced by the QTT checker. If a handle is:
- Used zero times → QTT error: "linear value unused (resource leak)"
- Used more than once → QTT error: "linear value used more than once"

This is the same mechanism already used for session channel endpoints.

### 12.6 Tests (~15)

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

<a id="13-console-io"></a>

## 13. Console IO

### 13.1 Design

Console IO (`print`, `println`, `read-ln`) is the simplest IO operation and the most
commonly used (debugging, REPL interaction). It does NOT use session types — it's
direct FFI calls with capability inference.

### 13.2 Implementation

```prologos
;; In lib/prologos/core/io.prologos (alongside file IO)

spec print : String -> Unit
defn print [s]
  foreign io-display s

spec println : String -> Unit
defn println [s]
  foreign io-displayln s

spec read-ln : Result String IOError
defn read-ln []
  foreign io-read-ln
```

### 13.3 Prelude Inclusion

Per Decision D4, `println` is included in the prelude for beginner accessibility.
`print` and `read-ln` require `use prologos.core.io`.

```racket
;; In namespace.rkt, add to prelude-requires:
'(prologos.core.io (println))
```

### 13.4 Session-Based Console (Optional, Tier 3)

For programs that want structured console IO:

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

These are provided in `io-protocols.prologos` but not used by the convenience functions.

### 13.5 Tests (~5, included in IO-D2)

- `println` outputs string with newline
- `print` outputs string without newline
- `read-ln` reads from stdin (test with mock)
- `println` infers `{StdioCap}` (or no cap for console — design decision)

---

<a id="14-csv-and-structured-data"></a>

## 14. CSV and Structured Data

### 14.1 CSV Parser

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

### 14.2 Convenience Functions

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

spec write-csv : Path -> List [List String] -> Result Unit IOError
defn write-csv [p rows]
  let content := [csv-rows-to-string rows]
  [write-file p content]
```

### 14.3 Schema-Typed CSV (Dependent Send/Receive — Deferred)

When `!:`/`?:` are implemented (Phase IO-I), CSV reading can be typed by schema:

```prologos
;; Future: schema-typed CSV reading
session TypedCsvRead {S : Schema}
  ?: header [List String]
  ? [List [Record S]]            ;; each row validates against schema
  end
```

This is deferred because it depends on dependent send/receive infrastructure.

### 14.4 Tests (~20)

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

<a id="15-capability-inference-pipeline-integration"></a>

## 15. Capability Inference Pipeline Integration

### 15.1 Current State

`capability-inference.rkt` implements a complete propagator-based transitive closure
algorithm for capability requirements. However, it's only accessible via REPL commands
(`(cap-closure name)` and `(cap-audit name cap)` in `driver.rkt` L502-515). It is NOT
wired into the normal compilation pipeline.

### 15.2 What Needs to Change

For Tier 1 progressive disclosure (users never write capability annotations), capability
inference must run automatically:

1. **After type-checking all definitions in a module**: Run `run-capability-inference`
   over the module's definitions
2. **Annotate `main` with inferred capabilities**: The runtime provides capabilities
   based on the inferred set
3. **Warning on explicit caps that disagree with inference**: If a user writes
   `{fs :0 ReadCap}` but the function also needs `WriteCap`, warn

### 15.3 Implementation

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

### 15.4 Limitation: Flat Cap Names Only

`extract-capability-requirements` in `capability-inference.rkt` (L130-141) only handles
`(expr-fvar name)` domains — plain capability names like `ReadCap`. Applied/dependent
caps like `(FileCap "/data")` are silently ignored. This is acceptable for Phase IO-A–H
(all caps are flat names). Dependent caps are Phase 7e-7g work.

### 15.5 Tests (~10)

- `defn f [] [read-file ...]` → cap closure includes `ReadCap`
- Transitive: `defn g [] [f]` → cap closure includes `ReadCap`
- `defn main [] [g]` → main inferred with `ReadCap`
- Explicit cap matches inference → no warning
- Explicit cap missing from inference → warning
- Multiple caps compose: `read-file` + `write-file` → `{ReadCap, WriteCap}`

---

<a id="16-dependent-capabilities"></a>

## 16. Dependent Capabilities

### 16.1 Motivation

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

### 16.2 Current State (Phases 7a-7d Complete)

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

### 16.3 Design

#### 16.3.1 Cap-Set with Type Expressions

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

#### 16.3.2 `extract-capability-requirements` Extension

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

#### 16.3.3 Cap-Type Bridge Updates

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

#### 16.3.4 Capability Subsumption

A function requiring `{FileCap "/data"}` is satisfied by a caller with `{FsCap}` —
the blanket cap subsumes the specific one. This uses the existing subtype registry:

```
FileCap "/data" <: ReadCap <: FsReadCap <: FsCap <: IOCap
```

The subsumption check becomes: for each required `cap-entry`, check if the provided
cap-set contains a subsuming entry. Flat caps always subsume their applied refinements.

#### 16.3.5 Dependent Cap in Convenience Functions

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

### 16.4 Tests (~15)

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

<a id="17-module-structure-and-prelude"></a>

## 17. Module Structure and Prelude

### 16.1 Module Layout

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

### 16.2 Prelude Additions

```racket
;; In namespace.rkt, add to prelude-requires:
;; Minimal IO in prelude — just println for debugging
'(prologos.core.io (println))
'(prologos.data.path (Path path))
'(prologos.data.io-error (IOError))
```

File IO (`read-file`, `write-file`, etc.) requires explicit `use prologos.core.io`.
This follows Decision D4 — pure functions shouldn't see IO by default, but `println`
is a debugging aid that belongs in the prelude.

### 16.3 Dependency Graph for `dep-graph.rkt`

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

<a id="18-phased-implementation-roadmap"></a>

## 18. Phased Implementation Roadmap

### Dependency Graph

```
IO-A1 (Opaque FFI) ──┐
                      ├── IO-B (IO Bridge) ── IO-C (Boundary Ops) ── IO-D (Core File IO) ──┬── IO-E (Session Protocols)
IO-A2 (Path/IOError) ┘                                                                     ├── IO-F (Functional IO)
                                                                                            ├── IO-G (CSV)
                                                                                            ├── IO-H (Cap Inference) ── IO-I (Dependent Caps)
                                                                                            └── IO-I can start after IO-H
```

IO-E, IO-F, IO-G, IO-H, and IO-I are independent of each other (except IO-I depends on
IO-H for pipeline integration). They can be implemented in any order after IO-D.

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

**Total Phase IO-D tests**: ~30 across `test-io-file-01.rkt` and `test-io-file-02.rkt`

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

**Total Phase IO-E tests**: ~20

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

### Summary Table

| Phase | Sub-phase | Description | Tests | Depends On |
|-------|-----------|-------------|-------|------------|
| IO-A | A1 | Opaque type marshalling | ~8 | — |
| IO-A | A2 | Path + IOError types | ~10 | — |
| IO-B | B1 | IO state lattice | ~5 | A1 |
| IO-B | B2 | IO bridge propagator | ~5 | B1 |
| IO-B | B3 | FFI bridge to Racket | ~5 | A1 |
| IO-C | C1 | `proc-open` runtime | — | B |
| IO-C | C2 | Integration tests | ~12 | C1 |
| IO-D | D1 | File IO functions | ~15 | C |
| IO-D | D2 | Console IO functions | ~5 | D1 |
| IO-D | D3 | `with-open` macro | ~10 | D1 |
| IO-E | E1 | Protocol definitions | ~10 | D |
| IO-E | E2 | Session-based file IO | ~10 | E1 |
| IO-F | F1 | Linear handle type | ~10 | D |
| IO-F | F2 | fio bracket pattern | ~5 | F1 |
| IO-G | G1 | CSV parser | ~12 | — (pure) |
| IO-G | G2 | CSV file functions | ~8 | D, G1 |
| IO-H | H1 | Cap inference pipeline | ~10 | D |
| IO-I | I1 | Cap-set with type expressions | ~4 | H |
| IO-I | I2 | `extract-capability-requirements` for `expr-app` | ~3 | I1 |
| IO-I | I3 | Cap-type bridge for applied caps | ~4 | I1 |
| IO-I | I4 | Path-indexed cap E2E | ~4 | I2, I3 |
| **Total** | | | **~155** | |

---

<a id="19-deferred-features"></a>

## 19. Deferred Features

| Feature | Reason | Phase | Blocked On |
|---------|--------|-------|------------|
| Dependent send/receive (`!:`/`?:`) | Reader/parser token work needed | IO-J | WS reader tokens |
| Network IO (`connect`/`listen`) | Different FFI layer (sockets) | IO-K | IO-B infrastructure |
| Database IO (`db-open`, SQLite) | Opaque db connections + SQL | IO-L | IO-A1 (opaque) + Racket `db` lib |
| Relational integration (`:source csv`) | Depends on relational language maturity | IO-M | CSV + relational subsystem |
| Dependent caps in foreign blocks | `:requires [FileCap p]` syntax | IO-N | IO-I (dependent caps) |
| `Bytes` type | Not needed for text IO | Phase 2 | Nothing |
| Streaming/lazy IO | LSeq + handle lifetime management | Phase 2+ | `Bytes` + lazy evaluation |
| IO mocking framework | Swap IO propagators in test context | Phase 2+ | IO-B infrastructure |
| `proc-connect` runtime | Same pattern as `proc-open`, different FFI | IO-K | IO-C pattern |
| `proc-listen` runtime | Same pattern as `proc-open`, different FFI | IO-K | IO-C pattern |

All deferred items are tracked in `docs/tracking/DEFERRED.md`.

---

<a id="20-references"></a>

## 20. References

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
