# I/O Library Design: Capabilities + Sessions + Propagators

**Status**: Phase I/II Research + Design
**Date**: 2026-03-05
**Supersedes**: `docs/tracking/2026-03-01_1200_IO_LIBRARY_DESIGN.md` (World-token approach)
**Tracking**: `docs/tracking/2026-03-05_IO_LIBRARY_DESIGN_V2.md`

---

## Context

This design document reconsiders the I/O Library for Prologos in light of two major
systems built since the original IO design (2026-03-01):

- **Capability Types** (Phases 7a-7d, 8a-8c complete): Zero-method traits as authority
  proofs, `:0` erased (zero cost), `:1` linear transfer, lexical resolution, propagator-
  based cap-inference with ATMS provenance.
- **Session Types** (S1-S8 complete): `session`/`defproc`/`spawn` with the 8-operator
  matrix (`!`/`?`/`!!`/`??`/`!:`/`?:`/`!!:`/`??:`), duality, choice/offer, propagator-
  as-scheduler runtime, and the double-boundary IO model from the Session Type Design §12.

The original IO design used Mercury-style `World :1` token threading. This is now
superseded by fine-grained capabilities. The key insight: **capabilities make `World`
obsolete**. `{fs :0 ReadCap}` is more specific than `World :1 ->`, costs zero at runtime,
and integrates naturally with the propagator-based cap-inference already built.

**What this document does**: Takes the research from the prior IO design, the Capability
Security principles, the Session Type Design (especially §12 on integration, boundary
ops, and double-boundary), and the core principles (progressive disclosure, correctness
through types, decomplection) to produce an idealized IO Library design.

**What this document does NOT do**: Specify implementation details. This is Phase I/II
research — identifying what the ideal API looks like, what gaps exist, and what
infrastructure is needed before library code can be written.

---

## 1. Design Evolution: From World Token to Capabilities

### 1.1 What the Original Design Got Right

The 2026-03-01 IO design established several principles that remain valid:

- **Data out, not streams**: IO returns plain Prologos data (`String`, `List`, `Map`)
  that composes with existing collection ops. No special IO wrappers beyond `Result`.
- **Three-layer architecture**: Pure Prologos → Capability layer → Host bridge (thin FFI)
- **Schema validation at the boundary**: Dependent types for schema-typed IO
- **`with-open` as bracket pattern**: Following `with-transient` for resource scoping

### 1.2 What Changes

| Aspect | Original Design | New Design |
|--------|----------------|------------|
| **Effect discipline** | `World :1` token threading | Fine-grained capability traits (`:0` erased) |
| **IO marking** | `!IO` suffix on return type | `{fs :0 ReadCap}` on spec (inferred) |
| **Handle lifecycle** | Linear handle + `with-open` macro | Session-typed channel to IO service |
| **Protocol** | Implicit (convention) | Explicit session types (`session FileRead`) |
| **Boundary** | Single (FFI call) | Double-boundary (cap check → IO bridge → external) |
| **Concurrency** | Not addressed | Propagator-as-scheduler via `defproc` |
| **Authority model** | Implied by `World` possession | Explicit capability hierarchy with attenuation |
| **Runtime cost** | `World :1` is a runtime value | `:0` capabilities are erased — zero runtime cost |

### 1.3 The Key Insight: Channels ARE Handles

In the original design, `Handle` was a separate opaque type. In the capability+session
design, a channel endpoint IS the handle:

```prologos
;; Original: Handle is an opaque FFI value
spec read-all : Handle :1 -> <Handle :1 * String>

;; New: Channel endpoint IS the handle, protocol IS the lifecycle
session FileRead
  +>
    | :read-all -> ! String . FileRead
    | :read-line -> ! String? . FileRead
    | :close -> end

defproc file-reader : FileRead {fs :0 ReadCap}
  offer self
    | :read-all ->
        self ! [io-read-all self.resource]
        rec
    | :read-line ->
        self ! [io-read-line self.resource]
        rec
    | :close ->
        [io-close self.resource]
        stop
```

The session type IS the handle's API. Duality IS the client/server contract.
Linear channel consumption IS resource cleanup. No separate `Handle` type needed.

---

## 2. Core Architecture: The IOPropNet

### 2.1 Double-Boundary Model (from Session Type Design §12.5)

```
User Code (pure)
    |
    +-- compile-time: capability check (cap-inference propagator)
    |   "Does this code have {fs :0 ReadCap}?"
    |
    v
IO Bridge Cell (in propagator network)
    |
    +-- runtime: session type advancement
    |   "Is the protocol in a state that allows this operation?"
    |
    v
IO Propagator (side-effecting)
    |
    +-- external world (filesystem, network, database)
```

Two independent checks, at two different times, using two different propagator
networks — defense in depth.

### 2.2 IOPropNet as Lattice

IO operations form a lattice for the propagator network:

```
IOState lattice:
  bottom = unopened (no IO has occurred)
  open(path, mode) = file is open
  data(bytes) = data has been read/written
  closed = file handle released
  top = error (contradiction — e.g., read after close)
```

The IO propagator monitors the session state cell and the IO state cell:
- Session says `Send String` → IO propagator writes data to file, advances both cells
- Session says `End` → IO propagator closes file, marks IO cell as `closed`
- Attempt to read after close → IO cell goes to top (contradiction)

### 2.3 How It Connects to Existing Infrastructure

| Component | Already Built | Used For |
|-----------|--------------|----------|
| Cap-inference network | Phase 7-8 | Compile-time authority verification |
| Session propagators | S1-S8 | Protocol advancement + type checking |
| ATMS provenance | Phase D1-D4 | Derivation chains for IO errors |
| Galois connections | Phase 6a-6f | Cross-domain bridges (cap <-> session) |
| `run-to-quiescence` | Phase 2 | Scheduling IO propagators |
| Double-boundary model | Designed (§12.5) | IO bridge architecture |

---

## 3. Capability Hierarchy for IO

### 3.1 Fine-Grained Capabilities

Following CAPABILITY_SECURITY.md §Composition:

```prologos
;; Leaf capabilities (zero-method traits — pure authority proofs)
trait ReadCap        ;; can read from filesystem
trait WriteCap       ;; can write to filesystem
trait AppendCap      ;; can append to files
trait MkdirCap       ;; can create directories
trait DeleteCap      ;; can delete files/directories
trait StatCap        ;; can query file metadata

trait HttpCap        ;; can make HTTP requests
trait WsCap          ;; can open WebSocket connections
trait ListenCap      ;; can listen on a port

trait DbReadCap      ;; can read from databases
trait DbWriteCap     ;; can write to databases

trait SpawnCap       ;; can spawn child processes
trait ClockCap       ;; can read system clock
trait EnvCap         ;; can read environment variables
trait StdioCap       ;; can use stdin/stdout/stderr
```

### 3.2 Composite Capabilities (Union Types)

From CAPABILITY_SECURITY.md §Composite Union:

```prologos
;; Composite capabilities are unions (weakening, not contraction)
type FsReadCap   = ReadCap | StatCap
type FsWriteCap  = WriteCap | AppendCap | MkdirCap | DeleteCap
type FsCap       = FsReadCap | FsWriteCap
type NetCap      = HttpCap | WsCap | ListenCap
type DbCap       = DbReadCap | DbWriteCap
type IOCap       = FsCap | NetCap | DbCap | StdioCap | ClockCap | EnvCap
```

Subtype subsumption: `ReadCap <: FsReadCap <: FsCap <: IOCap`. A function requiring
`{ReadCap}` is satisfied by a caller with `{FsCap}` — zero-cost, automatic.

### 3.3 Progressive Disclosure (Three Tiers)

From DESIGN_PRINCIPLES.org §Progressive Disclosure and Session Type Design §12.2:

**Tier 1 — Beginners (99% of code): No capabilities visible.**

```prologos
ns my-app

;; Just works — compiler infers {fs :0 ReadCap} on main
defn main []
  let data := [read-file "data.csv"]
  [print data]
```

The compiler infers that `read-file` requires `ReadCap`, propagates it to `main`,
and the runtime provides it. The programmer never writes a capability annotation.

**Tier 2 — Intermediate: Explicit capabilities on function signatures.**

```prologos
;; Explicit capability requirement — visible in spec
spec process-data {fs :0 ReadCap} : Path -> Result String IOError
defn process-data [p]
  [read-file p]
```

**Tier 3 — Expert: Dependent, path-scoped capabilities + session protocols.**

```prologos
;; Path-indexed capability — grants access to one specific file
spec read-config {cap :0 FileCap "/etc/app.conf"} : Result Config IOError
defn read-config []
  match [read-file [path "/etc/app.conf"]]
    | ok content -> [parse-config content]
    | err e -> err e
```

---

## 4. Session Protocols for IO

### 4.1 File IO as Session Type

```prologos
;; Client-side view: what the user does
session FileRead
  +>
    | :read-all  -> ? String . end
    | :read-line -> ? String? . FileRead     ;; rec: can read more
    | :close     -> end

;; Server-side (dual): what the IO runtime does
;; dual(FileRead) = &> | :read-all -> ! String . end
;;                     | :read-line -> ! String? . dual(FileRead)
;;                     | :close -> end
```

### 4.2 File Write as Session Type

```prologos
session FileWrite
  +>
    | :write     -> ! String . FileWrite     ;; send data, continue
    | :write-ln  -> ! String . FileWrite     ;; send line, continue
    | :flush     -> FileWrite                ;; force write to disk
    | :close     -> end

session FileAppend
  +>
    | :append    -> ! String . FileAppend
    | :close     -> end
```

### 4.3 Bidirectional IO

```prologos
session FileRW
  +>
    | :read-all  -> ? String . FileRW
    | :read-line -> ? String? . FileRW
    | :write     -> ! String . FileRW
    | :seek      -> ! Int . FileRW
    | :close     -> end
```

### 4.4 Database as Session Type

```prologos
session DbSession
  +>
    | :query   -> ! String . ! [List String] . ? [Result [List [List String]] DbError] . DbSession
    | :execute -> ! String . ! [List String] . ? [Result Int DbError] . DbSession
    | :close   -> end
```

### 4.5 Network as Session Type

```prologos
session HttpRequest
  ! HttpMethod . ! Url . ! Headers . ! Body?
  ? [Result HttpResponse HttpError]
  end

session TcpStream
  rec
    +>
      | :send -> ! Bytes . TcpStream
      | :recv -> ? [Result Bytes NetError] . TcpStream
      | :close -> end
```

### 4.6 Stdin/Stdout as Session Type

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
      | :read-line -> ? String? . StdinSession
      | :done      -> end
```

---

## 5. API Surface: The Prologos Way

### 5.1 Convenience Functions (Tier 1 — No Handles, No Capabilities Visible)

These are the primary API. They handle open/read/close internally. The user
never sees a Handle, a channel, or a capability annotation.

```prologos
;; File reading
spec read-file   : Path -> Result String IOError
spec read-lines  : Path -> Result [List String] IOError
spec read-bytes  : Path -> Result Bytes IOError

;; File writing
spec write-file  : Path -> String -> Result Unit IOError
spec append-file : Path -> String -> Result Unit IOError
spec write-bytes : Path -> Bytes -> Result Unit IOError

;; CSV
spec read-csv      : Path -> Result [List [List String]] IOError
spec read-csv-maps : Path -> Result [List [Map Keyword String]] IOError
spec write-csv     : Path -> [List [List String]] -> Result Unit IOError

;; Filesystem queries
spec exists?   : Path -> Bool
spec is-file?  : Path -> Bool
spec is-dir?   : Path -> Bool
spec list-dir  : Path -> Result [List Path] IOError

;; Console
spec print   : String -> Unit
spec println : String -> Unit
spec read-ln : Result String IOError
```

The compiler infers capabilities. `read-file` has the inferred constraint
`{fs :0 ReadCap}` — the user never sees it unless they ask.

### 5.2 Bracketed Resource Functions (Tier 2 — Explicit Handle, Implicit Capabilities)

For multi-step IO, use `with-open` (following `with-transient` pattern):

```prologos
;; with-open opens, runs body, closes — handle is a session channel
spec with-open : Path -> Mode -> <(ch : FileRW) -> A> -> Result A IOError

;; Usage
defn process-file [p]
  with-open p :read fn [ch]
    select ch :read-all
    data := ch ?
    [parse-data data]
```

The key difference from the original design: the "handle" is a channel endpoint
with a session type. The body communicates with the IO service via the session
protocol. `with-open` manages the lifecycle.

### 5.3 Process-Based IO (Tier 3 — Full Session Control)

For complex IO patterns, use `defproc` directly:

```prologos
;; A process that reads line-by-line and processes
defproc line-processor : dual FileRead {fs :0 ReadCap}
  let file-ch := open [path "data.csv"] :read {fs}
  rec
    select file-ch :read-line
    match [file-ch ?]
      | some line ->
          [process-line line]
          rec
      | none ->
          select file-ch :close
          stop
```

### 5.4 Capability-Aware IO (Tier 3 — Expert)

```prologos
;; Explicit capability in header
defproc web-scraper : ScraperProtocol {net :0 HttpCap, fs :0 WriteCap}
  url := self ?
  let resp := [http-get url]
  let data := [extract-data resp]
  [write-file [path "output.json"] [to-json data]]
  self ! :done
  stop

;; Main as powerbox — subtype subsumption handles attenuation
defproc main [args : List String] {sys : IOCap}
  spawn data-loader ReadCap       ;; compiler resolves ReadCap <: IOCap
  spawn report-writer WriteCap    ;; compiler resolves WriteCap <: IOCap
  ...
```

**Implicit attenuation via subtype subsumption**: Because `ReadCap <: FsCap <: IOCap`,
the compiler can automatically resolve a child's `{ReadCap}` requirement from the
parent's `{sys : IOCap}`. No explicit `attenuate` call needed for the common case.
The spawned process gets proof of the narrower authority; the parent retains its full
authority (`:0` is erased — it's a proof, not a value being consumed). Explicit
`attenuate` is only needed for `:1` (linear) authority *transfer*, where the parent
permanently gives up its own access.

---

## 6. Boundary Operations

From Session Type Design §12.4:

| Operation | Syntax | Capability | Returns |
|-----------|--------|------------|---------|
| Internal channel | `new [a b] : S` | None | Channel pair |
| Open file | `open path : S {cap}` | `ReadCap`/`WriteCap`/`FsCap` | Channel endpoint |
| Connect network | `connect addr : S {cap}` | `NetCap`/`HttpCap` | Channel endpoint |
| Listen on port | `listen port : S {cap}` | `ListenCap`/`NetCap` | Channel endpoint |
| Open database | `db-open path : S {cap}` | `DbCap`/`DbReadCap` | Channel endpoint |
| Spawn process | `spawn proc {cap}` | `SpawnCap` (or parent) | Process handle |

All return channel endpoints. Once you have the endpoint, communication is
uniform — same `!`, `?`, `select`, `offer` operators. The capability check is
at creation time, not at use time (seL4 model).

---

## 7. `main` as Powerbox

From CAPABILITY_SECURITY.md §Authority Root and Session Type Design §12.3:

```prologos
;; The runtime grants all system capabilities to main
;; This is the ONLY place capabilities are minted from nothing
defn main {sys : IOCap}
  ;; Beginner: just use convenience functions
  let data := [read-file [path "input.csv"]]
  [println [format "Read {} bytes" [string-length data]]]

;; Or as a process for complex IO
defproc main [args : List String] {sys : IOCap}
  ;; Subtype subsumption: compiler resolves FsCap <: IOCap, NetCap <: IOCap
  spawn file-watcher FsCap       ;; gets only filesystem authority
  spawn api-server NetCap        ;; gets only network authority
  ...
```

No external manifest file. The capability chain is in the code, visible in
types, auditable by the compiler. **The type signatures ARE the security manifest.**

Explicit `split-cap` / `attenuate` is available for `:1` linear authority transfer
(where the parent genuinely gives up its own access), but the common `:0` case
uses implicit subtype resolution — zero ceremony.

---

## 8. Error Handling

IO errors use the existing `Result` type — no special IO error wrapper:

```prologos
data IOError
  = FileNotFound Path
  | PermissionDenied Path
  | IsDirectory Path
  | AlreadyExists Path
  | ConnectionRefused String
  | Timeout Int
  | IOFailed String              ;; catch-all with message

;; Session-level error: protocol includes error in type
session FileRead
  +>
    | :read-all  -> ? [Result String IOError] . end
    | :read-line -> ? [Result String? IOError] . FileRead
    | :close     -> end
```

The `Result` is part of the session protocol — errors are values, not exceptions.
The type system ensures every IO error path is handled.

---

## 9. Module Structure

```
lib/prologos/
  data/
    path.prologos            ;; Path type + pure operations (no IO)
    bytes.prologos           ;; Bytes type (binary data)
    io-error.prologos        ;; IOError data type
  core/
    io.prologos              ;; Session-based IO — the "Prologos way" (recommended)
    fio.prologos             ;; Functional IO — linear handle threading (alternative)
    io-bridge.prologos       ;; FFI layer (foreign imports from Racket, shared)
    io-protocols.prologos    ;; Session types for IO (FileRead, FileWrite, etc.)
    csv.prologos             ;; CSV reading/writing
  io/
    fs.prologos              ;; Filesystem operations (exists?, list-dir, etc.)
    net.prologos             ;; Network operations (http-get, connect, etc.)
    db.prologos              ;; Database operations (query, execute, etc.)
    console.prologos         ;; Stdin/stdout/stderr
```

The two IO modules (`io` and `fio`) share the same bridge layer and capability
model. `io` exposes session channels; `fio` exposes linear handles backed by
channels internally. Both are available; `io` is the default/recommended path.

All modules use `:no-prelude` (standard for library code). The convenience
functions (`read-file`, `write-file`, `println`) are exported to the prelude
for beginner access.

---

## 10. Gap Analysis: What's Needed Before Implementation

### 10.1 Already Built

| Component | Status | Notes |
|-----------|--------|-------|
| Capability types (trait-based) | Phases 7a-7d, 8a-8c | Zero-method traits, cap-inference, ATMS provenance |
| Session types | S1-S8 | Full 8-operator matrix, duality, propagator runtime |
| Propagator network | Phases 1-6 | CHAMP-backed, persistent, Galois connections |
| Foreign function interface | Complete | Wraps Racket primitives |
| Result/Option types | Complete | Error handling |
| Collection traits | Complete | Data from IO composes with `map`/`filter`/`reduce` |
| `with-transient` pattern | Complete | Template for `with-open` |
| Schema system | Phases 1-5 | Field registry, typed construction, validation |
| Union types | Complete | Composite capabilities |
| Subtype system | Phase E | Subtype declarations with transitive closure |

### 10.2 Gaps

| Gap | Severity | Description |
|-----|----------|-------------|
| **Dependent send/receive (`!:`/`?:`)** | HIGH | Needed for schema-typed IO. Reader doesn't handle `!:`/`?:` tokens yet. Session type elaboration must bind values in continuation scope. |
| **IO bridge propagators** | HIGH | The double-boundary model (§12.5) is designed but not implemented. Need `io-bridge-cell` type, `io-propagator` that performs actual side effects, and wiring into `run-to-quiescence`. |
| **`open`/`connect`/`listen` boundary ops** | HIGH | Designed in Session Type Design §12.4 but not implemented. These create channel endpoints to external resources. Need cap-gated creation + IO bridge wiring. |
| **Opaque type marshalling** | MEDIUM | `foreign.rkt` handles Nat/Int/Bool/String/Char but not opaque Racket values (file ports, db connections). Need `:opaque` foreign annotation or pass-through marshalling. |
| **Dependent capabilities (Phase 7e-7g)** | MEDIUM | Path-indexed caps like `FileCap "/data"` need `cap-set` extended to hold type expressions. Currently deferred in DEFERRED.md. |
| **`Path` type** | LOW | Could be String wrapper initially. Pure operations (join, parent, extension) are straightforward. |
| **`Bytes` type** | LOW | Not needed for text IO (Phase 1). Needed for binary IO. |
| **Streaming/lazy IO** | LOW | LSeq + open handle lifetime management. Phase 2+. |
| **Capability inference through call chains** | MEDIUM | The full lexical capability resolution mechanism (CAPABILITY_SECURITY.md §Lexical Resolution) needs a dedicated design cycle. Current cap-inference is per-function, not transitive. |

### 10.3 Priority Order

1. **Dependent capabilities (Phase 7e-7g)** — path-scoped authority so IO has a concept of "what path am I allowed to touch" from day one
2. **IO bridge propagators** — the foundational IO mechanism
3. **Boundary operations** (`open`, `connect`, `listen`) — create channels to external resources
4. **Opaque type marshalling** — FFI can pass through Racket ports
5. **Dependent send/receive (`!:`/`?:`)** — value-dependent protocols for typed IO
6. **`Path` type** — basic filesystem abstraction
7. **`Bytes` type** — binary IO (needed for SQLite FFI capstone)
8. **Convenience functions** — `read-file`, `write-file`, etc. built on top of 1-7
9. **Transitive capability inference** — full call-chain cap resolution (design round at this phase)

**Deferred to separate design iteration**: Streaming/lazy IO (needs design for LSeq + open handle lifetime management).

---

## 11. Relationship to Prior IO Design Decisions

### Decisions Preserved

- **Data out, not streams** (§4.3) — IO returns plain data. Unchanged.
- **`with-open` as bracket** (§4.2 Option C) — Macro-managed lifetime. Now session-based.
- **Schema validation at boundary** (§4.4) — Dependent types for typed IO. Needs `!:`/`?:`.
- **CSV operations** — `read-csv`, `read-csv-maps`. Built on `with-open` + session.
- **Module structure** — Pure layer / capability layer / host bridge. Preserved.

### Decisions Superseded

- **World token** (§4.1 Decision 1) — **Superseded by capabilities.** `{fs :0 ReadCap}`
  replaces `World :1 ->`. Zero runtime cost vs. runtime token threading.
- **`!IO` suffix** (§4.1) — **Not needed.** Capabilities are on the spec, not the return type.
  The type signature shows authority requirements, not a World return value.
- **Handle as opaque type** (§4.2) — **Superseded by session channels.** Channel endpoints
  ARE handles. Session type IS the API. No separate Handle type.
- **Handle threading** (§5) — **Superseded by session protocol.** No manual handle threading
  needed. The session type's continuation structure handles sequencing.
- **Phase 6: `!` notation** (§8) — **Superseded by `defproc` process syntax.** The process
  body uses `self !` / `self ?` / `select` / `offer` — no special rebinding notation.

---

## 12. Design Decisions and Discussion

### 12.1 Prelude Inclusion — RESOLVED

`print`, `println`, and friends go in the prelude (debugging aids, always available).
File, network, and database IO require explicit import: `use prologos.core.io`.

This follows the progressive disclosure principle: console output is so fundamental
that hiding it behind an import would annoy beginners. But filesystem access is a
capability — making the user write `use prologos.core.io` signals "you are opting
into side effects" and makes the boundary visible.

### 12.2 Handle vs. Channel — RESOLVED: Hybrid (Option C)

**Decision**: Support both linear handles and session channels, in separate modules
with clear separation. Session-based IO is the recommended path; handle-based IO is
the functional escape hatch.

**Module separation**:

- **`prologos.core.io`** — Session-based IO. `with-session`, `select`, channel
  operations. The "Prologos way." This is what `use prologos.core.io` gives you.
  Steers toward sessions as the natural approach.
- **`prologos.core.fio`** — Functional IO. Linear handle threading, `with-open`,
  pure functions that take and return handles. Familiar to Rust/Idris/Clean devs.
  The `f` prefix signals "functional" — no session concepts needed.

Both modules share the same underlying IO bridge propagators and capability model.
Same error types (`IOError`), same capability requirements (`ReadCap`, `WriteCap`).
The difference is the user-facing API, not the implementation.

**Internally, `fio` handles are backed by session channels** — `with-open` creates
a channel to the IO service but presents a handle API. This means no code
duplication in the runtime. `fio` is a thin ergonomic layer over `io`.

**Interop**: A program can use both modules. A `defn main` (Tier 1) using `fio`-style
`read-file` can coexist with a `defproc` (Tier 3) using session-typed channels. Both
are backed by the same IO bridge, so there are no coherence issues.

**Session-based IO (`prologos.core.io`)**:

```prologos
defn process-file [p]
  with-session p :read fn [ch]
    select ch :read-line
    let line1 := ch ?
    select ch :read-line
    let line2 := ch ?
    select ch :close
    [line1 line2]
```

No handle threading. The channel manages sequencing via the session protocol.
Close is part of the protocol, verified by the type checker. Composes naturally
with Tier 3 (`defproc`). The session type can encode complex interactions
(branching, recursion, dependent values).

**Functional IO (`prologos.core.fio`)**:

```prologos
defn process-file [p]
  with-open p :read fn [h :1]
    let (h line1) := [read-line h]
    let (h line2) := [read-line h]
    let (h _) := [read-line h]
    (h [line1 line2])
```

Familiar to Idris 2/Mercury/Clean users. Simple mental model — a handle is a
linear value, functions are pure transformations. No session concepts needed.
Verbose (handle threading), but correct and predictable.

**Ergonomic roadmap for `fio`**: The linear threading verbosity is acknowledged.
Phase D ships with explicit threading. A later ergonomic iteration may add
`!`-rebind sugar (e.g., `let line := [read-line! h]` where `!` signals "consume
and rebind `h`"). This defers syntax design until real usage patterns emerge.

**Steering toward sessions**: `prologos.core.io` is the default import.
Documentation leads with session examples. `prologos.core.fio` is documented
as "for users who prefer functional-style linear handle threading." The
progressive disclosure path is: Tier 1 (convenience functions, no IO concepts
visible) → Tier 2 (`fio` handles or `io` sessions) → Tier 3 (`defproc` with
full channel management).

### 12.3 Binary IO and SQLite Capstone — On Roadmap

`Bytes` type is now on the roadmap (Phase B4). SQLite integration (Phase G) serves as
a capstone demo that exercises the full stack: capability-gated `db-open`, session-typed
`DbSession`, `Bytes` for binary data, schema-typed query results, and dependent
capabilities for database-scoped authority.

### 12.4 Error Handling in Sessions — Current State and IO Impact

**Current session error handling (as implemented in S1-S8)**:

Today, session types have no built-in error mechanism. A `defproc` that encounters
an error has limited options:

1. **Send an error value**: The protocol must include the error in its type.
   `? [Result String IOError]` — the receiver gets a `Result` and must handle both cases.
   This works but makes every session type carry error information explicitly.

2. **Stop the process**: `stop` terminates the process. The other endpoint sees a
   stuck channel (the session didn't reach `end`). This is currently undetected at
   runtime — no timeout or deadline mechanism.

3. **No `throws` in session types yet**: The session type design (§8.2) shows
   `throws IOError` syntax, but this is not yet implemented. A `throws` clause would
   allow the session to signal an error that short-circuits the protocol.

**Impact on IO design**:

For IO, errors are common (file not found, permission denied, connection refused).
Every IO session protocol must account for errors. Two approaches:

**Approach A: Errors as values (current — no new mechanism needed)**

```prologos
session FileRead
  +>
    | :read-all  -> ? [Result String IOError] . end
    | :read-line -> ? [Result String? IOError] . FileRead
    | :close     -> end
```

Every receive returns `Result`. The client handles `ok`/`err` at each step. Verbose
but explicit — no hidden control flow. The protocol always reaches `end` cleanly
because errors are just data, not exceptions.

**Approach B: Session-level `throws` (requires new mechanism)**

```prologos
session FileRead throws IOError
  +>
    | :read-all  -> ? String . end       ;; clean types — no Result wrapper
    | :read-line -> ? String? . FileRead
    | :close     -> end

;; On error, the IO service sends an IOError on a separate error channel,
;; and the session short-circuits to end. The client sees:
;; ok: normal data flow
;; err: IOError value + protocol terminated
```

Cleaner types (no `Result` wrapper), but requires implementing `throws` in the
session type system — a new propagator for error channel, a new session operator
for "abort with error," and integration with the double-boundary model.

**Recommendation**: Start with Approach A (errors as values) for Phase D. This works
today with existing infrastructure. Add `throws` support as a separate design iteration
if the verbosity of `Result` wrappers in every protocol becomes painful.

### 12.5 IO Mocking for Tests — RESOLVED

Test contexts provide mock IO bridge propagators. The session protocol is the same;
only the IO propagator on the server side changes. This is natural in the propagator
model — swap the IO propagator, keep the protocol. The session type guarantees that
the mock and real implementations conform to the same protocol.

### 12.6 `defn main` vs `defproc main` — Both, With Different Profiles

Both forms are supported. The choice depends on what the program does:

**`defn main` — Simple scripts, sequential IO**

```prologos
ns word-count

;; defn main: capabilities inferred, no process machinery
;; Compiler infers {fs :0 ReadCap, stdio :0 StdioCap} from body
defn main []
  match [read-file [path "input.txt"]]
    | ok content ->
        let words := [split content " "]
        [println [format "Word count: {}" [length words]]]
    | err e ->
        [println [format "Error: {}" [show e]]]
```

`defn main` is a function. IO operations are called as regular functions with
inferred capabilities. No channels, no processes, no `spawn`. The compiler
infers all capability requirements from the body and resolves them from the
runtime-provided `IOCap`. This is the Tier 1 experience.

**`defproc main` — Concurrent programs, explicit channel management**

```prologos
ns web-server

;; defproc main: explicit capabilities, process spawning, channel management
defproc main [args : List String] {sys : IOCap}
  let port := [parse-int [head args]]
  let server-ch := listen port HttpProtocol NetCap

  rec
    let client-ch := server-ch ?     ;; accept connection
    spawn request-handler client-ch ReadCap WriteCap
    rec                              ;; loop: accept next connection
```

`defproc main` is a process. It has a `self` channel, can `spawn` child processes,
and explicitly manages channels and capabilities. This is the Tier 3 experience.

**Key difference**: `defn main` hides ALL process machinery. The user writes
sequential code with regular function calls. `defproc main` exposes process
machinery for programs that need concurrency, channel management, or explicit
capability delegation.

**Implementation**: `defn main` desugars internally to a process with a single
"run body to completion" session, but the user never sees this. The compiler
handles the translation.

---

## 13. Example Programs

### 13.1 Hello World (Tier 1 — Beginner)

```prologos
ns hello

[println "Hello, world!"]
```

No capabilities. No session types. No handles. Just works.

### 13.2 Read and Process a File (Tier 1)

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

### 13.3 CSV Processing (Tier 1)

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

### 13.4 Multi-File Processing (Tier 2 — Bracketed)

```prologos
ns merge-files

defn merge [input-paths output-path]
  let contents := [map read-file input-paths]
  let merged := [string-join [filter-map ok? contents] "\n"]
  [write-file output-path merged]
```

### 13.5 Concurrent IO (Tier 3 — Process)

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

defproc main [args : List String] {sys : IOCap}
  let paths := [map path args]
  let results := [map (fn [p]
    new [my-ch worker-ch] : WorkProtocol
    spawn file-loader worker-ch ReadCap   ;; compiler resolves ReadCap <: IOCap
    my-ch ! p
    my-ch ?) paths]
  [println [format "Loaded {} files" [length results]]]
  stop
```

---

## 14. Phased Implementation Roadmap

### Phase A: Dependent Capabilities + IO Foundations
- **A1**: Dependent capabilities (Phase 7e-7g from DEFERRED.md) — path-indexed caps
  like `FileCap "/data"`. Extend `cap-set` to hold type expressions, update
  cap-type-bridge alpha/gamma functions. This gives IO a concept of "what path am I
  allowed to touch" from the start.
- **A2**: IO bridge cell type in propagator network
- **A3**: IO propagator that performs side effects during `run-to-quiescence`
- **A4**: Opaque type marshalling in `foreign.rkt` (`:opaque` annotation)
- **Depends on**: nothing (builds on existing propagator + session + cap infrastructure)

### Phase B: Boundary Operations + Path + Bytes
- **B1**: `open` boundary operation (capability-gated channel creation for files)
- **B2**: `connect` / `listen` boundary operations (network, database)
- **B3**: `Path` type (String wrapper or opaque Racket path) + pure operations
- **B4**: `Bytes` type for binary IO (needed for SQLite FFI)
- **B5**: `IOError` data type
- **Depends on**: Phase A

### Phase C: Dependent Send/Receive
- **C1**: Reader/parser support for `!:` / `?:` tokens in WS mode
- **C2**: Session type elaboration with value binding in continuation scope
- **C3**: Integration tests with schema-typed IO protocols
- **Depends on**: Phase B (needed for schema-typed IO, but IO bridge can start without)

### Phase D: Core File IO
- **D1**: FFI bridge to Racket file operations (via `:opaque` from A4)
- **D2**: `read-file`, `write-file`, `read-lines`, `append-file` convenience functions
- **D3**: `with-open` macro (bracket pattern, handle or session channel internally)
- **D4**: `println` / `print` / `read-ln` for console IO
- **D5**: Tests: 30+ covering read/write/error/capability safety
- **Depends on**: Phases A + B

### Phase E: File Session Protocols
- **E1**: `FileRead` / `FileWrite` / `FileAppend` / `FileRW` session types
- **E2**: IO service processes (dual of each session type)
- **E3**: Line-by-line reading via session protocol
- **E4**: Tests: 20+ session protocol tests
- **Depends on**: Phase D

### Phase F: CSV + Structured Data
- **F1**: CSV parser (split, quoting, headers)
- **F2**: `read-csv`, `read-csv-maps`, `write-csv`
- **F3**: Integration with schema system for typed CSV reading (uses `!:`/`?:` from Phase C)
- **Depends on**: Phase D + Phase C for schema typing

### Phase G: Database IO (SQLite Capstone)
- **G1**: `db-open` boundary operation
- **G2**: `DbSession` session type
- **G3**: SQLite via Racket `db` library + `Bytes` from B4
- **G4**: Parameterized queries, result rows
- **G5**: Demo: load SQLite database, query, return typed results
- **Depends on**: Phases A + B (especially B4 Bytes)

### Phase H: Transitive Capability Inference
- **H1**: Design round for lexical capability resolution mechanism
- **H2**: Cap-inference propagation through call chains
- **H3**: Integration tests: Tier 1 programs with zero manual cap annotations
- **Depends on**: Phase D (needs real IO functions to test against)

### Phase I: Network IO
- **I1**: `HttpRequest` / `TcpStream` session types
- **I2**: HTTP client (basic: GET/POST/PUT/DELETE)
- **I3**: WebSocket connections
- **Depends on**: Phases A + B

### Phase J: Relational Language Integration
- **J1**: `:source csv "file.csv"` metadata on `defr`
- **J2**: `:source sqlite "db.db" "table"` metadata on `defr`
- **J3**: Bulk loading as relation facts
- **J4**: Cross-source queries
- **Depends on**: Phases F + G + relational language maturity

---

## 15. References

- Prior IO design: `docs/tracking/2026-03-01_1200_IO_LIBRARY_DESIGN.md`
- Capability security: `docs/tracking/principles/CAPABILITY_SECURITY.md`
- Session type design: `docs/tracking/2026-03-03_SESSION_TYPE_DESIGN.md` (§9-14)
- Capabilities as types: `docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md`
- **Protocols as types**: `docs/tracking/principles/PROTOCOLS_AS_TYPES.org` — composable session types, protocol composition through named continuations, capability composition
- Design principles: `docs/tracking/principles/DESIGN_PRINCIPLES.org`
- Ergonomics: `docs/tracking/principles/ERGONOMICS.org`
- Language vision: `docs/tracking/principles/LANGUAGE_VISION.org`
- Propagator future opportunities: `docs/research/2026-03-03_PROPAGATOR_NETWORK_FUTURE_OPPORTUNITIES.md`
- Deferred work: `docs/tracking/DEFERRED.md`
