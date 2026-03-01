# I/O Library Design for Prologos

**Status**: Phase 1 Research + Phase 2 Gap Analysis + Phase 3 Draft Design
**Date**: 2026-03-01
**Tracking**: `docs/tracking/2026-03-01_1200_IO_LIBRARY_DESIGN.md`

---

## 1. Motivation

Prologos needs an I/O library to:

1. **Read/write files** — the foundational capability for any practical language
2. **Support the relational language** — loading external data (CSV, SQLite) as facts for graph querying across database tables
3. **Demonstrate Prologos's unique strengths** — linear types for resource safety, session types for protocol correctness, dependent types for schema validation
4. **Be portable** — expressed in pure Prologos as much as possible, with a thin FFI layer for host-specific primitives that could be re-targeted to another host

### The Portability Principle

The string library (`prologos::data::string`) is a direct FFI bridge — every operation is a `foreign racket` import. This works but is maximally non-portable: changing the host means rewriting every import.

The I/O library should follow a different pattern:

```
┌─────────────────────────────────────────────────┐
│  Pure Prologos Layer (portable)                 │
│  Path, CSV parsing, schema validation,          │
│  convenience functions, with-open, etc.         │
├─────────────────────────────────────────────────┤
│  Capability Layer (portable types, host impl)   │
│  trait IO { read-bytes, write-bytes, ... }      │
│  trait FileSystem { open, stat, remove, ... }   │
├─────────────────────────────────────────────────┤
│  Host Bridge (thin, per-host)                   │
│  foreign racket "..." [racket-open ...]         │
│  foreign racket "..." [racket-read-bytes ...]   │
└─────────────────────────────────────────────────┘
```

The bottom layer is the only part that changes per host. The middle and top layers are pure Prologos.

---

## 2. Research Survey

### 2.1 Linear/Affine Types and I/O

| Language | Mechanism | Resource Strategy | Key Insight |
|----------|-----------|-------------------|-------------|
| **Clean** | Uniqueness types | Unique `*World` token threaded through; file handles are unique values | World-passing makes I/O order explicit without monads |
| **Rust** | Ownership + borrowing | `File` is owned; `Drop` trait for cleanup; `BufReader` borrows | RAII via ownership; compiler proves no use-after-free |
| **Idris 2** | QTT (same as Prologos) | `1 Handle` is linear; `withFile` scopes lifetime | Closest model to Prologos; dependent protocols possible |
| **Linear Haskell** | Linear arrows (`a %1 -> b`) | Linear `Handle` in linear-base library | Retrofitted linearity; less ergonomic than native QTT |
| **ATS** | Linear viewtypes | `FILEref` is a linear view; must be explicitly freed | Very low-level; maximum control, minimum ergonomics |

**Key finding**: Idris 2 is the closest model. Prologos can go further by combining QTT with session types (Idris 2 has session types but doesn't unify them with I/O).

### 2.2 Pure Functional I/O

| Language | Mechanism | Strengths | Weaknesses |
|----------|-----------|-----------|------------|
| **Haskell** | IO monad + Handle | Mature ecosystem; streaming (conduit/pipes) | Lazy I/O footguns; Handle not linear |
| **OCaml (Eio)** | Capability-passing effects | `Eio.Path.t` as capability; structured concurrency | No dependent types for schema validation |
| **Koka** | Row-polymorphic effects | `io` effect tracked in type; handlers compose | No linear types for resource safety |
| **Unison** | Abilities | `IO` ability; content-addressed code | Novel but immature ecosystem |

**Key finding**: OCaml Eio's capability-passing pattern (pass a `Fs.t` capability to code that needs filesystem access) composes beautifully with linear types. Prologos could adopt this: a linear `Fs` capability controls filesystem access.

### 2.3 Logic Programming I/O

| System | Mechanism | Key Insight |
|--------|-----------|-------------|
| **SWI-Prolog** | Streams (`open/4`, `read_term/2`, `csv_read_file/2`) | Rows returned on backtracking — natural for Prolog |
| **Mercury** | I/O state pair (`!IO` sugar for `IO0, IO` threading) | State threading with unique modes; verbose but safe |
| **Datalog (Soufflé, etc.)** | `.input`/`.output` directives with file paths | Declarative: "this relation's facts come from this CSV" |

**Key finding**: For the relational language, the Datalog model is ideal — declare that a relation's EDB (extensional database) comes from a file. SWI-Prolog's row-on-backtracking is natural but doesn't compose with our propagator-based solver. Mercury's `!IO` state threading maps directly to Prologos's linear types.

### 2.4 Data-Oriented I/O

| Language | Pattern | Key Insight |
|----------|---------|-------------|
| **Clojure** | `slurp`/`spit` + data literals | I/O returns plain data; `clojure.data.csv` returns vectors of vectors |
| **Elixir** | `File.stream!/1` + Enum/Stream | Lazy streams compose with pipeline operators |
| **Python** | `pathlib` + `with` + `csv.reader` | `pathlib.Path` is ergonomic; context managers guarantee cleanup |

**Key finding**: I/O should return plain Prologos data (List, Map, String) that composes with existing collection operations. No special "I/O result" wrapper beyond `Result` for error handling.

### 2.5 Database Access

| Pattern | Examples | Key Insight |
|---------|----------|-------------|
| **Embedded SQLite** | Rust `rusqlite`, Python `sqlite3` | Connection as linear resource; prepared statements; row iteration |
| **CSV parsing** | Universal across languages | Header row → schema mapping; streaming for large files |
| **Schema validation** | JSON Schema, Clojure Spec, Pydantic | Validate at boundary; reject early; good error messages |
| **Heterogeneous query** | Apache Calcite, Datalog EDB | Treat external sources as virtual tables; query across them |

**Key finding**: Prologos's `schema` form + relational language is a natural fit for "external tables." A `defr` with `:source csv "file.csv"` could declare a relation backed by a CSV file, with `schema` providing compile-time type checking.

---

## 3. Gap Analysis: What Prologos Already Has

### 3.1 Infrastructure That Exists

| Infrastructure | Status | Relevance |
|----------------|--------|-----------|
| **QTT multiplicity tracking** | ✅ Complete | File handles as `:1` resources |
| **Session types** | ✅ Complete | I/O protocol verification |
| **Foreign function interface** | ✅ Complete | Wrapping Racket I/O primitives |
| **Opaque types (String, Char)** | ✅ Complete | Pattern for `Handle`, `Path` types |
| **Macro system (`with-transient`)** | ✅ Complete | Pattern for `with-open` |
| **Result/Option types** | ✅ Complete | Error handling for I/O operations |
| **Collection traits** | ✅ Complete | Data from I/O composes with `map`/`filter`/`reduce` |
| **Dependent types** | ✅ Complete | Schema-dependent I/O types |
| **Trait system** | ✅ Complete | `Readable`/`Writable`/`Closable` traits |
| **`schema` form** | 🔶 Designed, not implemented | Structured data validation |
| **Relational language (`defr`)** | 🔶 Phase 7 scaffolding only | External data as relations |

### 3.2 Gaps to Address

1. **No opaque type marshalling** — `foreign.rkt` handles Nat/Int/Bool/String/Char but not arbitrary opaque values. File handles, paths, and database connections are opaque Racket values that need a pass-through marshalling strategy.

2. **No `IO` effect discipline** — Currently no mechanism to mark a function as "performs I/O" at the type level. Options: (a) use linear capability passing, (b) add an effect system, (c) rely on convention.

3. **No `Path` type** — Need a cross-platform path abstraction.

4. **No byte/binary types** — Prologos has String (UTF-8 text) but no `Bytes`/`ByteArray` for binary I/O.

5. **No streaming abstraction for I/O** — LSeq is lazy but doesn't compose with resource lifetimes (the file must stay open while the lazy sequence is consumed).

---

## 4. Design: The Prologos Way

### 4.1 Core Design Decisions

#### Decision 1: Linear Capability Passing (not IO Monad, not Effects)

Rather than an IO monad (Haskell) or algebraic effects (Koka), Prologos uses **linear capability passing**:

```prologos
;; A World capability is a linear token that proves you have I/O access
spec read-file : World :1 -> String -> <(w : World) * Result String IOError>
```

The `World` token is threaded linearly — you get one, you must give it back (transformed). This is Mercury's model, but enforced by QTT rather than unique modes.

**Why not IO monad?** Prologos doesn't have monads as a first-class abstraction yet. Threading a linear token is simpler and composes with our existing QTT infrastructure.

**Why not effects?** Effects are a research direction for Prologos, but not implemented. Linear capability passing works today with existing infrastructure and doesn't preclude adding effects later.

**Sugar**: Mercury's `!IO` notation is compelling. We could add similar sugar:

```prologos
;; Explicit threading (verbose)
spec read-file : World :1 -> String -> <(w : World) * Result String IOError>

;; With sugar (ergonomic)
spec read-file : String -> Result String IOError !IO
```

where `!IO` desugars to an extra linear `World` parameter threaded through.

**Decision: Defer `!IO` sugar to a later phase. Start with explicit linear `World` threading to validate the core design, then add sugar once the patterns are clear.**

#### Decision 2: `with-open` as Primary Resource Pattern

Following `with-transient`, define `with-open` as a bracket macro:

```prologos
;; with-open guarantees the handle is opened, used, and closed
with-open "data.csv" :read
  fn [handle]
    read-all handle
```

Desugars to:

```prologos
(let [h (open "data.csv" :read)]
  (let [result ((fn [handle] (read-all handle)) h)]
    (let [_ (close! h)]
      result)))
```

But this naive desugaring has a problem: `h` is used twice (once passed to the function, once to `close!`). With linear types, this is a violation.

**The Idris 2 solution**: `withFile` takes a continuation that receives a linear handle and must return a result *plus* the handle (or proof it was closed):

```prologos
;; Option A: CPS with linear handle
spec with-open : World :1 -> String -> Mode
             -> <(h : Handle :1) -> <(w : World) * A>>
             -> <(w : World) * Result A IOError>
```

**The Clean solution**: The function receives and returns the handle:

```prologos
;; Option B: Handle threading (simpler)
spec with-open : String -> Mode
             -> <(h : Handle :1) -> <(h2 : Handle :1) * A>>
             -> Result A IOError  !IO
```

**The Rust/Python solution**: RAII / context manager — close on scope exit:

```prologos
;; Option C: Macro-managed lifetime (our with-transient pattern)
;; The handle is linear within the body; close! is inserted by the macro
with-open "data.csv" :read
  fn [handle :1]
    ;; handle is consumed by read-all (returns data + closed token)
    read-all handle
```

**Decision: Option C (macro-managed lifetime), following our `with-transient` precedent. The macro inserts `close!` after the body. The handle is linear — the type system prevents it from escaping the scope. If the body needs multiple operations, it threads the handle explicitly within the scope.**

#### Decision 3: Data Out, Not Streams

I/O operations return **plain Prologos data**:

```prologos
read-file   : String -> Result String IOError  !IO        ;; entire file as String
read-lines  : String -> Result [List String] IOError  !IO  ;; file as list of lines
read-csv    : String -> Result [List [List String]] IOError  !IO  ;; CSV as list of rows
```

No special I/O wrappers. The result is a `Result` containing standard Prologos values that compose with `map`, `filter`, `reduce`, etc.

**For large files**: A streaming variant returns `LSeq` but requires the handle to stay open. This is a Phase 2 concern — Phase 1 targets in-memory (Regime 1: < 1M rows).

#### Decision 4: Schema Validation at the Boundary

When loading structured data (CSV, JSON, SQLite), `schema` validates at the boundary:

```prologos
schema Employee
  :name   String
  :age    Int
  :dept   String

;; read-csv-typed validates each row against the schema
read-csv-typed Employee "employees.csv"
  ;; => Result [List Employee] [SchemaError String]
```

Dependent types make the return type depend on the schema:

```prologos
spec read-csv-typed : {S : Schema} -> String -> Result [List S] SchemaError  !IO
```

**Decision: Schema validation is a Phase 2 feature, dependent on `schema` form implementation. Phase 1 returns untyped rows (`List [List String]`).**

#### Decision 5: Relational Language Integration

The ultimate goal for data access:

```prologos
;; Declare a relation backed by a CSV file
defr employee :source csv "employees.csv"
  schema Employee

;; Declare a relation backed by a SQLite table
defr department :source sqlite "company.db" "departments"
  schema Department

;; Query across both — standard relational syntax
defr employee-dept [name dept-name budget]
  employee name _ dept-id
  department dept-id dept-name budget
```

This is the Datalog EDB model: external files are extensional databases. The relational engine loads them as facts and queries across them.

**Decision: Relational integration is Phase 3, dependent on the relational language (currently Phase 7 scaffolding). Phase 1 provides the I/O primitives that Phase 3 will use.**

### 4.2 Type Design

#### Core Types

```prologos
;; Path — cross-platform file path (opaque, backed by Racket path)
data Path

;; Handle — open file handle (always linear)
data Handle

;; Mode — file open mode
data Mode = ReadMode | WriteMode | AppendMode | ReadWriteMode

;; IOError — structured error type
data IOError
  = FileNotFound Path
  | PermissionDenied Path
  | IsDirectory Path
  | AlreadyExists Path
  | IOFailed String          ;; catch-all with message
```

#### Path Operations (Pure — No I/O)

```prologos
;; Construction
spec path       : String -> Path
spec join       : Path -> String -> Path         ;; path/child
spec parent     : Path -> Option Path
spec file-name  : Path -> Option String
spec extension  : Path -> Option String
spec with-extension : Path -> String -> Path

;; Predicates (pure — check the path string, not the filesystem)
spec absolute?  : Path -> Bool
spec relative?  : Path -> Bool

;; Conversion
spec to-string  : Path -> String
```

#### File I/O Operations (Require World)

```prologos
;; Opening and closing
spec open       : Path -> Mode -> <(h : Handle :1) * World>  ;; can fail
spec close!     : Handle :1 -> World                          ;; consumes handle

;; Reading (consumes and returns handle for linear threading)
spec read-all     : Handle :1 -> <(h : Handle :1) * String>
spec read-line    : Handle :1 -> <(h : Handle :1) * Option String>
spec read-bytes   : Handle :1 -> Int -> <(h : Handle :1) * Bytes>

;; Writing
spec write-string : Handle :1 -> String -> <(h : Handle :1) * Unit>
spec write-line   : Handle :1 -> String -> <(h : Handle :1) * Unit>
spec write-bytes  : Handle :1 -> Bytes -> <(h : Handle :1) * Unit>

;; Convenience (no handle management)
spec read-file    : Path -> Result String IOError  !IO
spec write-file   : Path -> String -> Result Unit IOError  !IO
spec append-file  : Path -> String -> Result Unit IOError  !IO
spec read-lines   : Path -> Result [List String] IOError  !IO

;; Filesystem queries
spec exists?    : Path -> Bool  !IO
spec is-file?   : Path -> Bool  !IO
spec is-dir?    : Path -> Bool  !IO
spec list-dir   : Path -> Result [List Path] IOError  !IO
```

#### CSV Operations

```prologos
;; Read CSV into list of rows (each row is list of strings)
spec read-csv   : Path -> Result [List [List String]] IOError  !IO

;; Read CSV with header row (returns list of maps)
spec read-csv-maps : Path -> Result [List [Map Keyword String]] IOError  !IO

;; Write CSV from list of rows
spec write-csv  : Path -> [List [List String]] -> Result Unit IOError  !IO
```

#### SQLite Operations (Phase 2)

```prologos
;; Connection as linear resource
data Connection

spec connect    : Path -> <(c : Connection :1) * World>
spec disconnect : Connection :1 -> World

spec query      : Connection :1 -> String -> [List String]
               -> <(c : Connection :1) * Result [List [List String]] SQLError>

spec execute    : Connection :1 -> String -> [List String]
               -> <(c : Connection :1) * Result Int SQLError>

;; Convenience
spec with-db    : Path -> <(c : Connection :1) -> <(c : Connection :1) * A>>
               -> Result A SQLError  !IO
```

### 4.3 The `with-open` Macro

```prologos
;; Usage:
with-open [path :read] fn [h]
  let (h result) = [read-all h]
  (h result)                     ;; must return handle + value

;; Desugars to:
(let (h w1) = (open (path "data.csv") ReadMode w0)
  (let (h result) = ((fn [h] (let (h result) = (read-all h) (pair h result))) h)
    (let w2 = (close! h w1)
      (pair w2 result))))
```

The macro:
1. Opens the file, producing a linear handle
2. Passes it to the body
3. Receives the handle back from the body (linear — must be returned)
4. Closes the handle
5. Returns the body's result

If the body fails to return the handle, the type checker catches it: `Handle :1` was consumed but not returned.

### 4.4 Convenience Layer

For the common case of "read a file, get data, don't think about handles":

```prologos
;; read-file : one call, entire file, no handle management
defn read-file [p]
  with-open [p :read] fn [h]
    read-all h

;; read-lines : split on newlines
defn read-lines [p]
  match [read-file p]
    | (ok content) -> ok [split content "\n"]
    | (err e)      -> err e

;; read-csv : parse CSV (basic — no quoting, no escaping)
defn read-csv [p]
  match [read-lines p]
    | (ok lines) -> ok [map (fn [line] [split line ","]) lines]
    | (err e)    -> err e

;; write-file : one call, write string, done
defn write-file [p content]
  with-open [p :write] fn [h]
    write-string h content
```

These convenience functions are **pure Prologos** — they compose `with-open` with the handle operations. The only FFI is in the bottom layer (`open`, `close!`, `read-all`, `write-string`).

---

## 5. The Handle Threading Question

The biggest design tension is between **ergonomics** and **linearity**. Consider reading a file line by line:

```prologos
;; Awkward: must thread handle through every operation
with-open [p :read] fn [h]
  let (h line1) = [read-line h]
  let (h line2) = [read-line h]
  let (h line3) = [read-line h]
  (h [line1 line2 line3])
```

This is Mercury's style — correct but verbose. Alternatives:

### Option A: Uniqueness + Rebinding (Mercury's `!` Sugar)

```prologos
;; !h means "consume h, rebind h to new value"
with-open [p :read] fn [!h]
  let line1 = [read-line !h]
  let line2 = [read-line !h]
  let line3 = [read-line !h]
  [line1 line2 line3]
```

The `!h` notation means: "this variable is threaded — each use consumes and rebinds it." The type checker tracks the rebinding chain. This is syntactic sugar over the explicit threading.

### Option B: Scoped Linear State (Do-Notation)

```prologos
;; io-do block manages handle threading implicitly
with-open [p :read] io-do
  line1 <- read-line
  line2 <- read-line
  line3 <- read-line
  pure [line1 line2 line3]
```

This is Haskell's approach but with linear handles underneath. The `io-do` block desugars to explicit threading.

### Option C: Bulk Operations Only

Skip handle threading entirely for Phase 1. Only expose:

```prologos
read-file    : Path -> Result String IOError  !IO
read-lines   : Path -> Result [List String] IOError  !IO
write-file   : Path -> String -> Result Unit IOError  !IO
append-file  : Path -> String -> Result Unit IOError  !IO
```

Handle-level operations exist but are advanced/expert-only. Most users never see a Handle.

**Recommendation: Phase 1 uses Option C (bulk operations only). Phase 2 adds explicit handle threading. Phase 3 adds `!` sugar (Option A) after we have usage data on what patterns are common. Option B (do-notation) requires monad/effect infrastructure we don't have.**

---

## 6. FFI Layer Design

The bottom layer wraps Racket's I/O. This is the only non-portable part.

### 6.1 Opaque Type Marshalling

Current `foreign.rkt` doesn't handle opaque types. We need a strategy:

**Option A: Extend foreign.rkt with `:opaque` annotation**

```prologos
;; New foreign syntax for opaque types
foreign racket "racket/base" :opaque [open-input-file :as racket-open-read : String -> Handle]
```

The `:opaque` flag tells the marshaller to pass the Racket value through without conversion.

**Option B: Foreign block with manual marshalling**

```prologos
;; Foreign block wraps the Racket call with Prologos types
foreign-block racket
  (define (prologos-open-read path-str)
    (with-handlers ([exn:fail? (lambda (e) (make-io-error (exn-message e)))])
      (open-input-file path-str)))
```

**Decision: Option A is cleaner. Add `:opaque` support to `foreign.rkt`. The opaque value is wrapped in an `expr-opaque` AST node (or reuse existing opaque infrastructure).**

### 6.2 Racket Primitives Needed

```racket
;; File I/O
open-input-file   : path-string? -> input-port?
open-output-file  : path-string? -> output-port?
close-input-port  : input-port? -> void?
close-output-port : output-port? -> void?
port->string      : input-port? -> string?
read-line         : input-port? -> (or/c string? eof-object?)
write-string      : string? output-port? -> exact-nonneg-integer?

;; Path operations
build-path        : path-string? ... -> path?
path->string      : path? -> string?
file-exists?      : path-string? -> boolean?
directory-exists?  : path-string? -> boolean?
directory-list    : path-string? -> (listof path?)

;; CSV (via racket/csv or manual parsing)
;; SQLite (via db library)
```

---

## 7. Module Structure

```
lib/prologos/
  data/
    path.prologos          ;; Path type + pure operations
    io-error.prologos      ;; IOError data type
    csv-row.prologos       ;; (Phase 2) typed CSV row type
  core/
    io.prologos            ;; Core I/O operations (with-open, read/write)
    io-bridge.prologos     ;; FFI layer (foreign imports from Racket)
    csv.prologos           ;; CSV reading/writing
    sqlite.prologos        ;; (Phase 2) SQLite operations
```

### Dependency Graph

```
path.prologos (pure, no deps)
  ↓
io-error.prologos (depends on path)
  ↓
io-bridge.prologos (FFI layer, depends on path + io-error)
  ↓
io.prologos (depends on io-bridge, provides with-open + convenience fns)
  ↓
csv.prologos (depends on io, string-ops, list)
  ↓
sqlite.prologos (Phase 2, depends on io)
```

---

## 8. Phased Implementation Roadmap

### Phase 1: Core File I/O (Target: near-term)

**Goal**: Read and write files. Return plain data. Linear resource safety.

- **1a**: `Path` type + pure operations (no AST nodes needed — can be opaque String wrapper or Racket path)
- **1b**: `IOError` data type
- **1c**: FFI bridge — `open`, `close!`, `read-all`, `write-string`, `read-line` via `:opaque` foreign
- **1d**: `with-open` macro (following `with-transient` pattern)
- **1e**: Convenience functions — `read-file`, `write-file`, `read-lines`, `append-file`
- **1f**: Tests — 20+ test cases covering read/write/error handling/linear safety

**Success criteria**: Can read a file, process its contents with existing collection ops, and write results to another file. Linear type system prevents use-after-close.

**Open question: Do we need new AST nodes?** If `Handle` is an opaque type (like String), we may not need 14-file pipeline changes. The `:opaque` foreign annotation may suffice. If we want the type checker to enforce linearity *on handles specifically*, we need `expr-Handle` in `syntax.rkt` with multiplicity `m1` wired into `qtt.rkt`.

### Phase 2: CSV + Schema Validation

**Goal**: Read CSV files. Parse into structured data. Validate against schemas.

- **2a**: CSV parser — split on delimiters, handle quoting, header extraction
- **2b**: `read-csv` → `List [List String]` (untyped)
- **2c**: `read-csv-maps` → `List [Map Keyword String]` (header-keyed)
- **2d**: Schema-validated CSV reading (depends on `schema` form implementation)
- **2e**: CSV writing
- **2f**: Tests — 20+ test cases covering parsing edge cases

**Depends on**: Phase 1 complete. Phase 2d depends on `schema` form.

### Phase 3: Relational Language Integration

**Goal**: External data sources as relations for the relational language.

- **3a**: `:source csv "file.csv"` metadata on `defr`
- **3b**: Bulk loading — read CSV at relation initialization, assert as facts
- **3c**: Schema mapping — column types from `schema` form
- **3d**: Multi-source queries — join across CSV-backed and in-memory relations

**Depends on**: Phase 2 + relational language implementation (currently deferred).

### Phase 4: SQLite Integration

**Goal**: Query SQLite databases from Prologos.

- **4a**: `Connection` type (linear, like Handle)
- **4b**: `connect`/`disconnect`/`with-db` lifecycle
- **4c**: `query` — parameterized queries returning rows
- **4d**: `execute` — DDL/DML with row count
- **4e**: `:source sqlite "db.db" "table"` for relational language
- **4f**: Cross-source queries — join CSV relations with SQLite relations

**Depends on**: Phase 1 + Racket `db` library FFI.

### Phase 5: Streaming I/O (Future)

**Goal**: Process files larger than memory.

- **5a**: `read-lines-lazy` → `LSeq String` with handle lifetime tied to consumption
- **5b**: `read-csv-lazy` → `LSeq [List String]`
- **5c**: Handle lifetime tracking — type system ensures handle outlives the lazy sequence
- **5d**: Transducer integration — `|> (read-lines-lazy p) (map-xf parse) (filter-xf valid?) (into result)`

**Depends on**: Handle threading (Phase 1 explicit threading sufficient) + possibly session types for lifetime protocols.

### Phase 6: `!IO` Sugar + Handle Threading (Future)

**Goal**: Ergonomic syntax for I/O-heavy code.

- **6a**: `!` notation for linear variable rebinding
- **6b**: `!IO` annotation for implicit World threading
- **6c**: Integration with `defproc` / session types

**Depends on**: Usage data from Phases 1-4 to know what patterns need sugar.

---

## 9. Unique Prologos Opportunities

### 9.1 Dependent Types for Schema-at-the-Boundary

No other language offers this:

```prologos
;; The return type depends on the schema
spec read-csv-typed : (S : Schema) -> Path -> Result [List S] SchemaError  !IO

;; Usage — type checker knows each row is an Employee
let employees = [read-csv-typed Employee "staff.csv"]
;; employees : Result [List Employee] SchemaError
```

### 9.2 Session Types for I/O Protocols

```prologos
;; A file-reading protocol as a session type
session FileRead
  !OpenReq String Mode        ;; client sends open request
  ?OpenResp (Result Handle IOError)  ;; server responds
  rec Loop
    +{ read : ?Data String . Loop    ;; client chooses: read (server sends data)
     , close : end                   ;; or close (protocol ends)
     }
```

This statically verifies that a client opens before reading, and closes exactly once.

### 9.3 Relations Over External Data

```prologos
;; Load CSV as a relation — query it with Prolog-style syntax
defr employee :source csv "employees.csv"
  schema Employee

;; Load SQLite table as a relation
defr project :source sqlite "work.db" "projects"
  schema Project

;; Query across heterogeneous sources — natural join
?- employee ?name ?dept, project ?dept ?budget, [int-gt ?budget 100000]
```

This is Datalog over heterogeneous external sources, with compile-time schema validation.

### 9.4 Linear Types Prevent Resource Leaks (Statically)

```prologos
;; This program is a TYPE ERROR — handle escapes with-open scope
defn bad-program []
  let h = with-open ["data.csv" :read] fn [h] h   ;; ERROR: Handle :1 escapes
  read-all h                                        ;; use-after-close prevented

;; This program is a TYPE ERROR — handle used twice
defn also-bad [h :1 Handle]
  let (h1 data) = [read-all h]
  let (h2 more) = [read-all h]    ;; ERROR: h already consumed
  [data more]
```

Rust achieves similar guarantees with ownership, but Prologos's QTT is more general (it also handles erased `:0` and unrestricted `:w`).

---

## 10. Open Questions for Design Discussion

1. **World token vs. capability passing**: Should we thread a single `World` token (Mercury/Clean style) or pass specific capabilities like `Fs` (filesystem), `Net` (network), `Db` (database)? Capabilities are more fine-grained but more verbose.

2. **Phase 1 linearity**: For Phase 1 convenience functions (`read-file`, `write-file`), should the World threading be explicit or hidden behind the `!IO` annotation? If hidden, we need the sugar earlier.

3. **Error handling**: Use `Result A IOError` everywhere, or provide both `Result`-returning and exception-raising variants? (Prologos doesn't have exceptions yet.)

4. **Path representation**: Opaque Racket `path?` value, or a pure Prologos `String` with validation? Opaque is more correct (platform-specific path semantics) but less portable.

5. **Binary I/O**: How urgently do we need a `Bytes` type? CSV and text files don't need it. SQLite FFI might.

6. **Prelude inclusion**: Should `read-file`/`write-file` be in the prelude? Or always require explicit import?

---

## 11. References

### Primary Literature
- Idris 2: "Idris 2: Quantitative Type Theory in Practice" (Brady, 2021)
- Linear Haskell: "Linear Haskell: practical linearity in a higher-order polymorphic language" (Bernardy et al., 2018)
- Mercury I/O: Mercury Language Reference Manual, §15 (I/O)
- OCaml Eio: "Eio: Structured Concurrency for OCaml" (ocaml-multicore)
- Datalog EDB: "Soufflé: On rapid prototyping of program analyses" (Scholz et al., 2016)

### Existing Systems Surveyed
- Clean (uniqueness types), Rust (ownership), ATS (linear viewtypes)
- Haskell (IO monad, conduit, pipes), Koka (effects), Unison (abilities)
- SWI-Prolog (streams, csv), Mercury (unique I/O state)
- Clojure (data.csv, jdbc), Python (pathlib, csv, sqlite3)
- Apache Calcite, Datomic (heterogeneous query)
