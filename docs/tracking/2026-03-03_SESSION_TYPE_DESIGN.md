# Session Type System: Phase II Design Document

**Date**: 2026-03-03
**Status**: Phase II — Refinement & Gap Analysis (Design Methodology)
**Predecessor**: `docs/research/2026-03-03_SESSION_TYPE_DESIGN_RESEARCH.md` (Phase I)
**Companion**: `docs/research/2026-03-03_PROCESS_CALCULI_SURVEY.md` (theoretical grounding)

---

## Table of Contents

- [1. Document Purpose](#1-purpose)
- [2. Design Decisions Summary](#2-summary)
- [3. Operator Matrix](#3-operators)
- [4. Protocol Declaration: `session`](#4-session)
- [5. Process Definition: `defproc`](#5-defproc)
- [6. Choice and Branching](#6-choice)
- [7. Recursion](#7-recursion)
- [8. Dependent Sessions](#8-dependent)
- [9. Channel Naming: Implicit `self`](#9-channels)
- [10. Execution Model: Propagator-as-Scheduler](#10-execution)
- [11. Execution Strategy: `strategy`](#11-strategy)
- [12. Capability Integration](#12-capabilities)
- [13. Schema Integration](#13-schema)
- [14. QTT Integration](#14-qtt)
- [15. Propagator Network Integration](#15-propagator)
- [16. Error Handling](#16-errors)
- [17. Multiparty Protocols](#17-multiparty)
- [18. Promise Resolution: `@`](#18-promises)
- [19. S-Expression Canonical Forms](#19-sexp)
- [20. Deferred to Later Phases](#20-deferred)
- [21. Implementation Plan](#21-implementation)
- [22. References](#22-references)

---

<a id="1-purpose"></a>

## 1. Document Purpose

This document consolidates all design decisions made during the Phase I → Phase II
refinement for Prologos's session type system. It resolves all 11 open questions from
the Phase I research document and establishes the concrete syntax, semantics, and
implementation direction for the `session`/`defproc`/`proc` keywords.

**Design methodology context**: This is Phase II (Refinement & Gap Analysis) of the
five-phase design methodology. Phase I (Deep Research) produced the research document
and process calculi survey. This document captures refinement decisions for review and
critique before moving to Phase III (Design Iteration) and Phase IV (Implementation).

**Scope**: Binary session types with synchronous semantics. Async operators (`!!`/`??`)
are designed into the grammar but implemented in a later phase. Multiparty global types
are deferred; the orchestrator pattern covers multi-party needs.

---

<a id="2-summary"></a>

## 2. Design Decisions Summary

| # | Phase I Open Question | Resolution |
|---|----------------------|------------|
| 1 | Operator syntax (`!`/`?` vs keywords) | `!`/`?` confirmed; extended to 8-operator matrix (§3) |
| 2 | Process self-channel (explicit vs implicit) | Implicit `self` for single-channel; explicit naming for multi-channel (§9) |
| 3 | Recursion syntax | `rec` with optional named label: `rec Loop` (§7) |
| 4 | Blocking model | Design for async from day one (`!!`/`??` in grammar); implement sync first (§3) |
| 5 | Deadlock freedom | Single-session guaranteed by construction; multi-session via propagator quiescence analysis (Phase S4) |
| 6 | Multiparty | Binary + orchestrator pattern; global types deferred (§17) |
| 7 | Schema integration (`*` Sigma) | `*` for primary data constraint; attenuations compose at type level (§13) |
| 8 | Capability integration | Three-tier model: channel-as-cap, boundary gating, in-protocol delegation (§12) |
| 9 | Propagator integration | Day-one integration; session lattice built alongside type lattice (§15) |
| 10 | Process execution model | **Propagator-as-scheduler** — processes are propagator collections, channels are cells (§10) |
| 11 | Channel implementation | Propagator cells for coordination; messages are cell writes (§10) |

**Additional decisions from refinement:**

| Decision | Resolution |
|----------|------------|
| Continuation separator | `. ` for single-line protocols (§4) |
| Dependent send/recv syntax | `!:`/`?:` operators, not parenthesized binders (§8) |
| Eventual send/recv syntax | `!!`/`??` operators (§3) |
| Execution strategy | `strategy` top-level keyword, decomplected from session (§11) |
| Capability authority root | `main` process as powerbox (§12) |
| Promise resolution | `@promise` prefix operator (§18) |
| Schema × capability composition | Attenuation as type; protocol names the type (§13) |

---

<a id="3-operators"></a>

## 3. Operator Matrix

### 3.1 The Full Operator Table

Four axes — direction (send/recv) × blocking (sync/async) × dependency (simple/dependent)
— collapsed into 2-3 character operators:

|  | Simple Send | Simple Receive | Dependent Send | Dependent Receive |
|--|---|---|---|---|
| **Blocking** | `!` | `?` | `!:` | `?:` |
| **Non-Blocking** | `!!` | `??` | `!!:` | `??:` |

### 3.2 Protocol Declaration Operators

| Operator | Context | Meaning |
|---|---|---|
| `!` | `session` | Send type (non-dependent) |
| `?` | `session` | Receive type (non-dependent) |
| `!:` | `session` | Dependent send — binds name in continuation |
| `?:` | `session` | Dependent receive — binds name in continuation |
| `!!` | `session` | Eventual send (non-blocking, returns immediately) |
| `??` | `session` | Eventual receive (returns promise) |
| `!!:` | `session` | Dependent eventual send |
| `??:` | `session` | Dependent eventual receive |
| `+>` | `session` | Internal choice (this endpoint selects) |
| `&>` | `session` | External choice (other endpoint selects) |
| `end` | `session` | Protocol termination |
| `rec` | `session` | Recursion point |
| `.` | `session` | Explicit continuation separator |
| `shared` | `session` | Shared service marker (`:w` multiplicity channel) |

### 3.3 Process Body Operators

| Operator | Context | Meaning |
|---|---|---|
| `chan !` | `defproc` | Send value on channel |
| `var := chan ?` | `defproc` | Receive value from channel |
| `chan !!` | `defproc` | Eventual send on channel |
| `var := chan ??` | `defproc` | Eventual receive (returns promise) |
| `select chan :label` | `defproc` | Internal choice — select a branch |
| `offer chan \| ...` | `defproc` | External choice — handle branch selection |
| `stop` | `defproc` | Terminate process (all channels must be at `end`) |

### 3.4 Disambiguation

**`?` collision with predicate suffix**: Context-dependent parsing resolves this.
`?` after a channel name (in `defproc` body) is receive; `?` at end of identifier
(`zero?`, `empty?`) is a predicate suffix. The parser knows whether it's inside a
process body (established by the `defproc` head).

**`??` collision with interaction hole**: `??` alone (no left-hand expression) is the
interaction hole. `expr ??` (with a channel expression on the left) is eventual receive.
The presence of the channel binding disambiguates.

### 3.5 Implementation Phasing

- **Phase 1**: `!`/`?` (synchronous blocking) — the only runtime operations
- **Phase 2**: `!!`/`??` (eventual) — async extension, sync operators remain default
- **No migration pain**: `!!`/`??` are reserved in the grammar from day one

---

<a id="4-session"></a>

## 4. Protocol Declaration: `session`

### 4.1 Basic Syntax

`session` declares a protocol type — the specification of a conversation. It is to
`defproc` what `spec` is to `defn`: the *what*, not the *how*.

```prologos
session ProtocolName
  <session-body>
```

### 4.2 Indentation-Based Continuation

Newline-indent is implicit continuation. Each line is one protocol step:

```prologos
session Greeting
  ! String
  ? String
  end
```

### 4.3 Single-Line with `. ` Separator

The `.` separator allows single-line protocols. It corresponds to the formal notation
`!A.S` (send A, then continue with S):

```prologos
session Greeting
  ! String . ? String . end
```

Rules:
- Newline-indent = implicit continuation (`.` is inferred)
- `. ` = explicit continuation (allows single-line protocols)
- Both desugar to the same s-expression

Inline branches are supported:

```prologos
session Counter
  rec . +> | :inc -> ! Nat . rec | :done -> end
```

### 4.4 Metadata

`session` follows the keyword metadata pattern established by `spec`:

```prologos
session FileAccess
  :doc "Protocol for file I/O operations"
  :deprecated "Use FileAccess2 instead"

  ! Path
  ? Result Handle IOError
  +>
    | :read  -> ? String -> rec
    | :write -> ! String -> ? Result Unit IOError -> rec
    | :close -> end
```

### 4.5 Example: Complete Protocol

```prologos
session FileAccess
  ! Path
  ? Result Handle IOError
  +>
    | :read
        ? String
        rec
    | :write
        ! String
        ? Result Unit IOError
        rec
    | :close
        end
```

---

<a id="5-defproc"></a>

## 5. Process Definition: `defproc`

### 5.1 Named Process

```prologos
defproc process-name : SessionType
  <process-body>
```

For single-channel processes, `self` is the implicit channel name (§9).

### 5.2 Anonymous Process: `proc`

`proc` creates an anonymous process (like `fn` for functions):

```prologos
;; Named
defproc greeter : Greeting
  self ! "hello"
  name := self ?
  stop

;; Anonymous (e.g., for spawning)
spawn (proc : Greeting
  self ! "hello"
  name := self ?
  stop)
```

### 5.3 Multi-Channel Processes

When a process has multiple channels, explicit naming is required:

```prologos
defproc orchestrator [buyer : BuyerProtocol, seller : SellerProtocol]
  req := buyer ?
  seller ! req
  quote := seller ?
  buyer ! quote
  ...
```

### 5.4 Process Body Operations

| Operation | Syntax | Meaning |
|-----------|--------|---------|
| Send | `chan ! expr` | Send value on channel |
| Receive | `var := chan ?` | Receive value from channel |
| Select | `select chan :label` | Choose a branch (internal choice) |
| Offer | `offer chan \| :l1 -> P1 \| :l2 -> P2` | Handle branch selection (external choice) |
| Stop | `stop` | Terminate process (all channels must be at `end`) |
| New | `new [c1 c2] : Session` | Create channel pair with session type |
| Parallel | `par P1 P2` | Run two processes in parallel |
| Link | `link c1 c2` | Forward/delegate channel c1 to c2 |

### 5.5 Pattern Matching on Received Values

```prologos
defproc auth-server : AuthProtocol
  cred := self ?
  match [verify cred]
    | Valid token ->
        select self :granted
        self ! token
        admin-session self
    | Invalid reason ->
        select self :denied
        self ! reason
        stop
```

### 5.6 Functional Computation Within Processes

Processes use the full functional language internally:

```prologos
defproc calculator : CalcProtocol
  offer self
    | :add ->
        x := self ?
        y := self ?
        self ! [+ x y]
        rec
    | :quit ->
        stop
```

---

<a id="6-choice"></a>

## 6. Choice and Branching

### 6.1 Operators

- `+>` — **Internal choice**: THIS endpoint selects which branch to take
- `&>` — **External choice**: The OTHER endpoint selects

From linear logic:
- `+>` corresponds to `A + B` (additive disjunction — I choose)
- `&>` corresponds to `A & B` (additive conjunction — you choose)

### 6.2 Branch Syntax

Branches use `| :label -> ...`, consistent with `match`, `defn` multi-clause,
and `type` variants. `:keyword` labels match schema field syntax.

**Both branch forms are supported:**

1. **Indentation-based** (multi-line): branches as indented blocks under `+>` / `&>`
2. **Inline arrow** (single-line): `| :label -> continuation -> ...`

The two forms desugar to the same s-expression and can be mixed freely:

```prologos
;; Indentation-based (multi-line)
session OrderProtocol
  ? OrderRequest
  ! Quote
  +>
    | :accept
        ? PaymentInfo
        ! Confirmation
        end
    | :reject
        end

;; Inline arrow (single-line)
session OrderProtocol
  ? OrderRequest . ! Quote . +> | :accept -> ? PaymentInfo -> ! Confirmation -> end | :reject -> end
```

### 6.3 Process Implementation

In `defproc` bodies:
- `select chan :label` implements internal choice (`+>`)
- `offer chan | :label -> ...` implements external choice (`&>`)

```prologos
defproc order-handler : dual OrderProtocol
  req := self ?
  self ! [compute-quote req]
  offer self
    | :accept ->
        payment := self ?
        self ! [process-payment payment]
        stop
    | :reject ->
        stop
```

---

<a id="7-recursion"></a>

## 7. Recursion

### 7.1 Anonymous Recursion

```prologos
session Counter
  rec
    +>
      | :inc -> ! Nat -> rec
      | :done -> end
```

### 7.2 Named Recursion

For complex protocols, named labels provide clarity:

```prologos
session TwoPhase
  rec Negotiate
    ? Offer
    +>
      | :counter -> ! CounterOffer -> Negotiate
      | :accept -> rec Execute
          ? Task
          ! Result
          +>
            | :more -> Execute
            | :done -> end
      | :reject -> end
```

### 7.3 Tail Recursion Requirement

Only tail-recursive protocols are valid — a recursion variable must appear in tail
position. This ensures protocols always make progress and don't accumulate unbounded state.

---

<a id="8-dependent"></a>

## 8. Dependent Sessions

### 8.1 `!:` and `?:` Operators

The `:` suffix signals dependency — the sent/received value binds a name in the
continuation. This replaces the parenthesized-binder syntax from Phase I:

```prologos
;; Phase I proposal (parenthesized binders — rejected):
? (n : Nat)

;; Phase II decision (operator suffix):
?: n Nat
```

The operator form is shorter, composes naturally with async variants (`!!:`/`??:`),
and makes the dependent/non-dependent distinction a property of the operator rather
than a syntax decoration.

### 8.2 Examples

```prologos
session VecTransfer
  ?: n Nat              ;; dependent receive: bind n : Nat in continuation
  ? Vec String n        ;; non-dependent receive using n
  ! Bool
  end

session AuthProtocol
  ? Credentials
  !: result AuthResult  ;; dependent send: bind result in continuation
  match result
    | Granted ->
        ! AuthToken
        AdminSession
    | Denied ->
        ! String
        end
```

### 8.3 Value-Dependent Branching

The `match` keyword in session declarations enables protocol branching on runtime values.
This connects to Toninho-Caires-Pfenning dependent session types.

---

<a id="9-channels"></a>

## 9. Channel Naming: Implicit `self`

### 9.1 Decision

`self` is a reserved keyword for the default channel name in single-channel processes.
Multi-channel processes require explicit naming.

### 9.2 Single-Channel (Common Case)

```prologos
;; self is implicit — no channel parameter needed
defproc greeter : Greeting
  self ! "hello"
  name := self ?
  stop
```

### 9.3 Multi-Channel (Explicit)

```prologos
;; Multiple channels — explicit naming required
defproc orchestrator [buyer : BuyerProtocol, seller : SellerProtocol]
  req := buyer ?
  seller ! req
  ...
```

### 9.4 Rationale

- **Progressive disclosure**: Beginners write `defproc greeter : Greeting` without
  thinking about channel plumbing
- **`self` is conventional**: Analogous to `this` in OOP, `self` in Rust/Python
- **No ambiguity**: `self` is always the default channel; explicit names always override
- **Multi-channel forces explicitness**: When multiple channels are in play, implicit
  naming would be confusing

### 9.5 Duality and Channel Pairs

Every session type `S` has a dual `dual(S)` that describes the complementary endpoint.
When `new [c1 c2] : S` creates a channel pair:

- `c1` gets type `S`
- `c2` gets type `dual(S)`

Duality is structural and recursive:

| Type | Dual |
|------|------|
| `! T . S` | `? T . dual(S)` |
| `? T . S` | `! T . dual(S)` |
| `!: x T . S` | `?: x T . dual(S)` |
| `?: x T . S` | `!: x T . dual(S)` |
| `+> { l1: S1, ..., ln: Sn }` | `&> { l1: dual(S1), ..., ln: dual(Sn) }` |
| `&> { l1: S1, ..., ln: Sn }` | `+> { l1: dual(S1), ..., ln: dual(Sn) }` |
| `end` | `end` |
| `rec . S` | `rec . dual(S)` |

**Process-level implication**: The `dual` keyword in process declarations refers to
the dual of a named session type. If `session Greeting` defines the initiator's view,
then `dual Greeting` is the responder's view:

```prologos
session Greeting
  ! String . ? String . end

;; Initiator sends first, receives second
defproc greeter : Greeting
  self ! "hello"
  name := self ?
  stop

;; Responder receives first, sends second (dual)
defproc responder : dual Greeting
  msg := self ?
  self ! "hi back"
  stop
```

Duality is enforced by the bidirectional propagator (§15.4): the two endpoints of a
channel pair are always constrained to be duals. A protocol violation on either side
produces an ATMS-traced error.

---

<a id="10-execution"></a>

## 10. Execution Model: Propagator-as-Scheduler

### 10.1 The Core Insight: Substrate Unification

In every existing language, the process execution model is a *separate mechanism* from
the type checking / constraint solving model. In Prologos, propagator-as-scheduler means
**type checking and process execution share the same computational substrate**.

A session type constraint propagator and a process execution propagator live in the same
network. The implications:

1. **Unified error reporting**: A protocol violation at runtime produces the same ATMS
   derivation chain as a protocol violation at compile time
2. **Static/dynamic duality**: At compile time, cells hold type-level information
   (session type lattice). At runtime, cells hold value-level information (actual messages).
   Same propagators, different lattice. This is a Galois connection
3. **Free backtracking**: Persistent cells give O(1) backtracking. If a protocol branch
   fails, the network can explore alternatives without rewinding global state

### 10.2 Concrete Process Model

A `defproc` compiles to a collection of propagators and cells:

```
Cell: self.out        (outgoing message cell)
Cell: self.in         (incoming message cell)
Cell: self.session    (current session state cell)

Propagator P1:
  watches: self.session
  fires when: self.session = Send(String, S)
  effect: write "hello" to self.out, advance self.session to S

Propagator P2:
  watches: self.in, self.session
  fires when: self.session = Recv(T, S) AND self.in has a value
  effect: bind name := self.in, advance self.session to S

Propagator P3:
  watches: self.session
  fires when: self.session = End
  effect: mark process as stopped
```

There is no scheduler. There is no thread. There is no blocking. There is only: cells,
propagators, and `run-to-quiescence`. The "scheduling" emerges from data dependencies.

### 10.3 Subsumption of Other Models

The propagator substrate subsumes existing concurrency models:

| Model | Propagator Encoding |
|-------|-------------------|
| **Green thread** | Linear chain of propagators, each fires once and triggers successor |
| **Coroutine** | Propagator writes to output cell, waits on input cell (yield/resume = two-cell handshake) |
| **Erlang mailbox** | Cell with list-valued lattice (messages accumulate monotonically); pattern matching = guarded propagator |
| **E-style eventual send** | Write to cell (non-blocking); promise = cell without value yet; `@promise` = propagator that blocks until cell has value; E's turn-based event loop IS `run-to-quiescence` |

**Key**: You can build all of these ON the propagator substrate, but you cannot build the
propagator substrate on top of any of them. The other models are topologically constrained;
propagators are the general case.

### 10.4 Challenges and Mitigations

**Fairness**: Propagator networks don't inherently guarantee fairness. Solution:
configurable scheduling via `strategy` declarations (§11). Default: round-robin with
fuel limits.

**Long-running computation**: Propagators are cooperative. A heavy computation blocks the
network. Mitigations: (1) fuel-limited reduction (already exists), (2) segmented execution
(break computation into propagator chains), (3) escape to OS thread for CPU-bound work.

**I/O integration**: Pure propagators are effect-free. I/O uses the double-boundary model:
`open` (compile-time capability check) → IO-bridge cell → IO propagator (runtime
verification) → external world. Capabilities gate the IO-bridge propagators (§12).

**True parallelism**: Single-threaded for Phase 0. Architecture supports future multi-core:
partitioned networks (per-thread), work-stealing across partitions, or hierarchical
scheduling. Cell abstraction can be swapped from mutable box to concurrent cell without
changing propagator code.

### 10.5 Research Directions

Work-sharing/stealing approaches rethought for propagator-as-scheduler. Priority queues
over propagators rather than over threads. The goal: anything "embarrassingly parallel"
in Prologos should be ergonomically deployable as such, where overhead doesn't eat the
benefit.

### 10.6 Choice as Cell-Write

A critical clarification of how `+>` (internal choice) and `&>` (external choice) map
to the propagator substrate: **choice is external input resolution via monotonic cell writes,
not non-determinism.**

In propagator terms:

- `select chan :label` writes `:label` to a **choice cell** associated with that channel
  endpoint. This is a regular monotonic cell write — the choice cell goes from `⊥` (no
  choice yet) to `:label`. Once written, it cannot be changed (monotonicity).

- `offer chan | :l1 -> P1 | :l2 -> P2` is a **guarded propagator**: it watches the choice
  cell and fires when the cell is resolved. The guard selects which continuation `P_i` to
  activate based on the cell's value.

```
Channel pair: new [c1 c2] : S where S contains +> { :read, :write }

  c1 side (internal choice):
    Cell: c1.choice          ;; starts at ⊥
    Propagator: select-prop
      fires when: process reaches choice point
      effect: writes :read or :write to c1.choice

  c2 side (external choice):
    Propagator: offer-prop
      watches: c1.choice     ;; NOTE: watches the OTHER endpoint's choice cell
      fires when: c1.choice ≠ ⊥
      effect: activates continuation for the chosen label
```

**Why this matters**: There is no branching or backtracking. There is no scheduler making
a non-deterministic choice. The `select` side writes to a cell; the `offer` side reads
from that cell. This is the same mechanism as any other propagator cell write — the only
difference is that the lattice is a flat set of labels rather than a numeric or type lattice.

This means the propagator-as-scheduler model handles choice with zero special machinery.
Choice cells participate in the same `run-to-quiescence` cycle as message cells and session
state cells. Deadlock occurs when the choice cell is never written to (no propagator fires
to resolve it), which is detectable as part of the standard quiescence check.

---

<a id="11-strategy"></a>

## 11. Execution Strategy: `strategy`

> **Note**: The `strategy` keyword and its property vocabulary (`:fairness`, `:fuel`,
> `:io`, `:parallelism`) are **provisional**. The exact property names and value sets
> will be refined during implementation (Phase S6) as we gain experience with real
> scheduling scenarios on the propagator substrate. The structural decision — a named,
> decomplected top-level declaration — is firm; the vocabulary within it is not.

### 11.1 Rationale

Execution strategy is **decomplected from session type definition**. A session type
describes *what* is communicated. A strategy describes *how* execution proceeds.
This follows the spec/defn separation principle.

### 11.2 Syntax

`strategy` is a top-level keyword, matching the `spec`/`schema`/`session` pattern:

```prologos
strategy realtime
  :fairness :priority
  :fuel 10000
  :io :nonblocking

strategy batch
  :fairness :round-robin
  :fuel 1000000
  :io :blocking-ok
```

### 11.3 Application

Applied at spawn time:

```prologos
spawn my-server :strategy realtime
```

Default strategy when none is specified (analogous to `default-solver`):

```prologos
strategy default
  :fairness :round-robin
  :fuel 50000
  :io :nonblocking
```

### 11.4 Strategy Properties

| Property | Values | Default | Meaning |
|----------|--------|---------|---------|
| `:fairness` | `:round-robin`, `:priority`, `:none` | `:round-robin` | Cell scheduling order |
| `:fuel` | PosInt | 50000 | Per-step propagator firing limit |
| `:io` | `:nonblocking`, `:blocking-ok` | `:nonblocking` | I/O bridge behavior |
| `:parallelism` | `:single-thread`, `:work-stealing` | `:single-thread` | Multi-core strategy (future) |

### 11.5 Expressibility

Strategies are values — they can be composed, passed, and computed:

```prologos
def my-strategy := strategy
  :fairness :priority
  :fuel [compute-fuel-from-env]
```

---

<a id="12-capabilities"></a>

## 12. Capability Integration

### 12.1 Core Principle: Channels ARE Capabilities

From `CAPABILITY_SECURITY.md`: *"A reference IS the capability."* For internal Prologos
channels: the channel endpoint is the capability. If a process holds `self : Greeting`,
it has the authority to communicate according to that protocol. No separate capability
check is needed. The channel reference was obtained legitimately (via `new`, parameter
passing, or delegation) — possession is authorization.

Consequence: **the common case is clean.** No capability annotations for pure
internal communication.

### 12.2 Three-Tier Capability Model

**Tier 1 (99% of code): No capabilities visible.**

Pure internal communication. Channel references are capabilities. Session types
constrain the protocol:

```prologos
session Counter
  rec . +> | :inc -> ! Nat . rec | :done -> end

defproc counter : Counter
  offer self
    | :inc -> self ! current . rec
    | :done -> stop
```

**Tier 2 (boundary code): Capabilities on process headers.**

When a process touches the external world, its `defproc` header declares what authority
it needs. Identical to how `spec` declares capability constraints on functions:

```prologos
defproc web-handler : HttpProtocol {net :0 NetCap, db :0 DbCap}
  req := self ?
  result := [query-db req]
  self ! result
  stop
```

The `{net :0 NetCap, db :0 DbCap}` is erased at runtime (`:0`). It's a compile-time
proof that the process was granted these authorities.

**Tier 3 (delegation code): Capabilities in the protocol.**

When the protocol itself involves authority transfer, the session type mentions
capabilities explicitly. This is rare — most protocols exchange data, not authority:

```prologos
session FileGrant
  ?: path Path
  !: cap FileCap path :1       ;; the session type shows authority transfer
  ? Unit
  end
```

### 12.3 `main` as Powerbox

`main` is the root of the authority tree. It receives capabilities from the runtime
(what the OS/environment grants the process) and delegates attenuated capabilities to
child processes:

```prologos
defproc main [args : List String] {fs : FsCap, net : NetCap, spawn : SpawnCap}
  let read-only := attenuate fs :read
  let local-net := attenuate net :localhost

  spawn web-server {local-net}
  spawn file-watcher {read-only}
  ...
```

No external manifest file. The authority chain is in the code, visible in types,
auditable by the compiler. The type signatures ARE the capability manifest.

### 12.4 Boundary Operations

External boundaries are capability-gated at creation time:

| Operation | Meaning | Capability Required |
|-----------|---------|-------------------|
| `new [a b] : S` | Internal channel pair | None (channels are caps) |
| `open path : S {cap}` | Open local resource | `FsCap`, `DbCap`, etc. |
| `connect addr : S {cap}` | Connect to remote endpoint | `NetCap` |
| `listen port : S {cap}` | Accept incoming connections | `NetCap` |
| `spawn proc {cap}` | Create new process | `SpawnCap` (or parent authority) |

All return channel endpoints. Once you have the endpoint, communication is uniform
(`chan !`, `chan ?`, `select`, `offer`). The capability check is at creation time, not
at use time. This is the seL4 model: capabilities gate *access to kernel objects*;
operations on handles are authorized by possession.

### 12.5 Double-Boundary for I/O

External I/O has two checkpoints (defense in depth):

```
Process → open (compile-time capability check)
        → IO-bridge cell
        → IO propagator (runtime verification)
        → External world
```

The compile-time check (`open`) catches most errors. The runtime check (IO propagator)
catches anything that slipped through (e.g., resource no longer exists).

### 12.6 Capability Delegation Through Sessions

The advanced case: a protocol explicitly transfers authority:

```prologos
session CapDelegation
  ?: path Path
  !: cap ReadCap path :1     ;; dependent send: linear capability for that path
  end

defproc authority-granter : CapDelegation {fs :1 FsCap}
  path := self ?
  read-cap := attenuate fs path
  self ! read-cap            ;; send the capability (linear: we give it up)
  stop
```

After `self ! read-cap`, the granter no longer has `read-cap` — it was `:1` (linear),
so sending it consumed it. QTT enforces this at compile time.

### 12.7 Capability Attenuation in Processes

```prologos
defproc supervisor {fs :1 FsCap, spawn :0 SpawnCap}
  let (fs-remaining, read-only) := split-cap fs :read

  new [my-ch child-ch] : WorkProtocol
  spawn (proc : WorkProtocol {r :0 ReadCap}
    data := [read-file "/config" {r}]
    self ! data
    stop) read-only

  ;; Supervisor keeps fs-remaining (still has write access)
  result := my-ch ?
  ...
```

### 12.8 Compiler Warnings

The compiler warns on capability issues:
- **Dead authority**: Process receives more capabilities than it uses
- **Ambient authority**: `:w` multiplicity on a capability type
- **Unattenuated pass-through**: Capability passed without narrowing when narrowing is possible
- **Union composition**: `{io : FsCap | NetCap}` — composite capability, consider separating

Warnings are informational, not errors. Sometimes composite authority is the right choice.

### 12.9 Revocation

Deferred to distributed computing phase. For single-machine application development,
linear ownership is sufficient: a capability, once delegated, is consumed.

---

<a id="13-schema"></a>

## 13. Schema Integration

### 13.1 Schema-Typed Messages

Session types reference schemas and selections for message types:

```prologos
schema Employee
  :name String
  :dept Department
  :salary Int

selection EmployeeSummary from Employee
  :requires [:name :dept]

session EmployeeService
  ? String
  ! Employee * EmployeeSummary     ;; send Employee, gated by EmployeeSummary selection
  end
```

The `* EmployeeSummary` gates field access — the receiver can only read `:name` and
`:dept`, even though the full `Employee` was sent.

### 13.2 Simple Case: Just Types

For simple protocols, schema integration is unnecessary. Just use types:

```prologos
session MovieService
  ? MovieTimesReq
  ! List MovieTime
  end
```

The `? User * MovieTimesReq` form is for when you need the full schema+selection
integration. That's an advanced feature.

### 13.3 Schema × Capability Composition

**Key insight**: Selections and capabilities are the same pattern at different levels:

| Level | Full Authority | Attenuated Authority | Mechanism |
|-------|---------------|---------------------|-----------|
| System | `FsCap` | `ReadCap` | Capability attenuation |
| Data | `Employee` | `Employee * PublicInfo` | Selection gating |
| Channel | `FileAccess` (full protocol) | Subtype (fewer branches) | Session subtyping |

All three are: "you have a reference to something, but you can only use part of it."

**Resolution: Attenuation as type, protocol names the type.**

Push attenuation into type definitions, keep protocol declarations clean:

```prologos
;; The attenuation is in the type, not the protocol
type ReadOnlyDbHandle := DbHandle * ReadOnly
type PublicEmployee := Employee * PublicInfo

;; Protocol just names the type
session EmployeeQuery
  ? String
  ! PublicEmployee
  end

session FileAccess
  ?: path Path
  !: handle ReadOnlyDbHandle
  ? Unit
  end
```

The protocol says WHAT is sent. The type definition says WHAT CONSTRAINTS apply.
Decomplected.

### 13.4 Variance at Session Boundaries

- **Input position** (`? req`): Contravariant — can relax requirements
- **Output position** (`! resp`): Covariant — can strengthen provisions

Maps to `:requires` (contravariant, input) and `:provides` (covariant, output) in
the selection system.

---

<a id="14-qtt"></a>

## 14. QTT Integration

### 14.1 Channels and Multiplicities

| Multiplicity | Channel Mode | Meaning |
|-------------|-------------|---------|
| `:1` (linear) | Default | Used exactly once per protocol step. The standard mode |
| `:w` (unrestricted) | Shared service | `!S` in linear logic — reusable service that accepts unlimited connections |
| `:0` (erased) | Compile-time only | Protocol exists for type checking but is erased at runtime |

### 14.2 Default: Linear (`:1`)

```prologos
defproc example : SomeProtocol
  self ! "hello"     ;; self transitions from (Send String . S) to S
  name := self ?     ;; self transitions from (Recv String . S') to S'
  stop               ;; self must be at End
```

### 14.3 Shared Channels (`:w`)

```prologos
session LogService
  shared
    ? String
    end

defproc logger : LogService
  msg := self ?
  [write-log msg]
  stop                ;; will be restarted (shared service)
```

### 14.4 QTT-Session Galois Connection

| QTT Multiplicity | Session Constraint |
|--|--|
| `:1` | Channel at a non-End session type (protocol in progress) |
| `:0` | Channel at End or type-level phantom |
| `:w` | Channel at a shared (`!`) session type |

---

<a id="15-propagator"></a>

## 15. Propagator Network Integration

### 15.1 Day-One Integration

Session types build on the propagator network from day one (per LE Subsystem Audit
recommendation). This avoids a later migration and enables unified error reporting.

### 15.2 Session Type Lattice

```
SessionTop (any protocol)
    |
  Send T . S  /  Recv T . S  /  Choice  /  Offer  /  Mu
    |
SessionBot (dead protocol — contradiction)
```

Subtyping rules (Gay & Hole):
- `!T1.S1 <: !T2.S2` when `T1 <: T2` and `S1 <: S2` (covariant output)
- `?T1.S1 <: ?T2.S2` when `T2 <: T1` and `S1 <: S2` (contravariant input)
- `+{l1:S1,...} <: +{l1:S1',...,ln:Sn'}` when fewer labels (contravariant)
- `&{l1:S1,...,ln:Sn} <: &{l1:S1',...}` when more labels (covariant)

### 15.3 Session Inference via Propagation

Each channel endpoint is a cell in the SessionLattice. Process operations create propagators:

| Operation | Propagator Effect |
|-----------|------------------|
| `self ! "hello"` | Constrain cell(self) to `Send String . S` for fresh meta S |
| `name := self ?` | Constrain cell(self) to `Recv T . S`; bind name : T |
| `select self :read` | Constrain cell(self) to `Choice` with `:read` branch; advance to `:read` continuation |

`run-to-quiescence` infers the session type for each channel.

### 15.4 Duality as Bidirectional Propagator

When `new [c1 c2] : S`:
- Cell(c1) = S
- Cell(c2) = dual(S)
- Bidirectional propagator: `cell(c2) = dual(cell(c1))`

### 15.5 ATMS for Protocol Verification

Each protocol step is an ATMS assumption. Protocol violations produce derivation chains:

```
Protocol violation at line 42:
  Channel self was inferred to be (Send String . End) because:
    - self ! "hello"    [line 10, assumption A1]
    - self ! "world"    [line 11, assumption A2]  <- second send advances past End
  Minimal conflict: {A1, A2}
```

### 15.6 Cross-Domain Bridges

| Bridge | What It Enables |
|--------|----------------|
| Session ↔ Type | Type inference for message types |
| Session ↔ QTT | Linear resource checking |
| Session ↔ Capability | Authority delegation verification |
| Session ↔ Schema | Selection constraint propagation |
| Session ↔ Progress | Deadlock freedom checking (Phase S4) |

### 15.7 Dependent Session ↔ Type Lattice Interaction

Dependent sessions (`!:`/`?:`) create bidirectional constraints between the session
lattice and the type lattice. Here is the propagator flow for a dependent protocol:

```
session VecTransfer
  ?: n Nat              ;; (1) dependent receive: n binds in continuation
  ? Vec String n        ;; (2) non-dependent receive using n
  ! Bool . end

Propagator network for VecTransfer checking:

  ┌─────────────────────────────────────────────────────┐
  │ SESSION LATTICE                                     │
  │                                                     │
  │  cell(self.session) ─────────────────────────────── │
  │    = DepRecv(Nat, n. Recv(Vec String n, Send Bool End)) │
  │                                                     │
  │  Propagator P1: session-step                        │
  │    watches: cell(self.session)                      │
  │    effect: advance session, emit type constraint    │
  │           ───────────────────────┐                  │
  └─────────────────────────────────┼──────────────────┘
                                    │
                         bridge propagator
                                    │
  ┌─────────────────────────────────┼──────────────────┐
  │ TYPE LATTICE                    ▼                   │
  │                                                     │
  │  cell(n) : Nat ──── type constraint ────────────── │
  │    │                                                │
  │    └──► cell(vec-type) = Vec String n               │
  │           ▲                                         │
  │           │  Propagator P2: dep-instantiate         │
  │           │    watches: cell(n)                     │
  │           │    effect: when n is known, refine      │
  │           │            Vec String n to Vec String 5 │
  │           │            (if n=5)                     │
  │                                                     │
  └─────────────────────────────────────────────────────┘
```

**Key interaction points:**

1. **DepRecv creates a type-level binding**: When the session step fires for `?: n Nat`,
   it creates a fresh cell `cell(n)` in the type lattice with initial constraint `: Nat`

2. **Type refinement feeds back into session**: When `cell(n)` is resolved (e.g., to `5`),
   the dependent continuation `Recv(Vec String n, ...)` can be fully instantiated to
   `Recv(Vec String 5, ...)`, enabling the next session step to type-check

3. **Bidirectional flow**: The session lattice generates type constraints; the type lattice
   resolves them; the resolutions feed back into session continuation instantiation. This
   is the same bidirectional propagation pattern used for universe level inference and
   multiplicity inference in the existing type checker

This interaction is unique to Prologos — other session type systems handle dependent
sessions via explicit substitution. The propagator model makes the dependency resolution
emergent from the constraint network rather than requiring a separate substitution pass.

---

<a id="16-errors"></a>

## 16. Error Handling

### 16.1 Errors as Explicit Branches

Model errors as explicit choice branches in the protocol:

```prologos
session RobustFileAccess
  ! Path
  &>
    | :ok ->
        ! Handle
        +>
          | :read -> ? String -> rec
          | :close -> end
    | :error ->
        ! IOError
        end
```

### 16.2 `throws` Clause (Phase S3)

A `throws` clause desugars to implicit `&>` at every step during elaboration:

```prologos
session FileAccess throws IOError
  ! Path
  ? Handle
  +>
    | :read -> ? String -> rec
    | :close -> end
```

This is syntactic sugar — the elaborator inserts `&> | :error -> ! IOError . end` at each
protocol step. Implemented in Phase S3 (Elaboration) as a desugaring pass. Start with
explicit branch modeling; `throws` provides ergonomic shorthand once the core works.

---

<a id="17-multiparty"></a>

## 17. Multiparty Protocols

### 17.1 Binary-First Strategy

Start with binary session types (two-party protocols). Multi-party interactions use
the **orchestrator pattern**:

```prologos
session BuyerToOrch
  ! OrderRequest
  ? Quote
  +>
    | :accept -> ! PaymentInfo -> ? Confirmation -> end
    | :reject -> end

session OrchToSeller
  ! OrderRequest
  ? Quote
  +>
    | :fulfill -> ! ShippingInfo -> ? TrackingId -> end
    | :cancel -> end

defproc orchestrator [buyer : BuyerToOrch, seller : OrchToSeller]
  req := buyer ?
  seller ! req
  quote := seller ?
  buyer ! quote
  offer buyer
    | :accept ->
        payment := buyer ?
        select seller :fulfill
        seller ! [compute-shipping payment]
        tracking := seller ?
        buyer ! [make-confirmation tracking]
        stop
    | :reject ->
        select seller :cancel
        stop
```

### 17.2 Why Not Global Types (Yet)

- Merge condition limits expressiveness
- Projection is partial
- The orchestrator pattern achieves the same effect with composable binary sessions
- Native MPST can be added later — the propagator network naturally supports
  multi-cell constraints across channels

---

<a id="18-promises"></a>

## 18. Promise Resolution: `@`

### 18.1 Syntax

`@` is a prefix operator for promise resolution (deref), analogous to Clojure's `@(deref ...)`:

```prologos
defproc async-client : AsyncGreeting
  self !! "hello"
  p := self ??            ;; p is a promise
  ;; ... do other work ...
  name := @p              ;; resolve the promise (block until value available)
  stop
```

### 18.2 Deep Deref and Pipeline Resolution

- `@@p` for recursive deref (promise resolves to another promise)
- `@>` for promise pipeline resolution — resolve a chain of dependent promises

### 18.3 Availability

`@` is not currently used in the Prologos reader (verified via `grammar.ebnf`). It's
available and consistent with "dereference" semantics across languages.

### 18.4 Implementation Phase

Implemented alongside `!!`/`??` in the async extension phase.

---

<a id="19-sexp"></a>

## 19. S-Expression Canonical Forms

Every WS-mode construct desugars to a canonical s-expression:

### 19.1 Session Declaration

```prologos
;; WS mode:
session FileAccess
  ! Path
  ? Result Handle IOError
  +>
    | :read -> ? String -> rec
    | :close -> end

;; Canonical sexp:
(session FileAccess
  (Send Path
    (Recv (Result Handle IOError)
      (Choice
        ((:read (Recv String (Mu (SVar 0))))
         (:close (End)))))))
```

### 19.2 Process Definition

```prologos
;; WS mode:
defproc greeter : Greeting
  self ! "hello"
  name := self ?
  stop

;; Canonical sexp:
(defproc greeter Greeting self
  (proc-send self "hello"
    (proc-recv self name String
      (proc-stop))))
```

---

<a id="20-deferred"></a>

## 20. Deferred to Later Phases

| Feature | Reason | When |
|---------|--------|------|
| `!!`/`??` async operators | Design complete; implement after sync core is stable | Phase 2 of session implementation |
| `@promise` resolution | Depends on `!!`/`??` | Phase 2 |
| `throws` clause | Syntactic sugar over explicit branches | Phase S3 (elaboration-level desugaring) |
| Global types (MPST) | Orchestrator pattern sufficient for now | If binary+orchestrator proves insufficient |
| Capability revocation | Distributed computing concern | Distributed channels phase |
| Work-stealing parallelism | Single-threaded is correct for Phase 0 | Performance optimization phase |
| WS mode disambiguation | `.` in session context vs map access | Parser integration phase |

---

<a id="21-implementation"></a>

## 21. Implementation Plan

### Phase S1: Session Type Parsing

- Parse `session` declarations in WS mode and sexp mode
- Parse `. ` continuation separator
- Parse `!`/`?`/`!:`/`?:`/`+>`/`&>` operators
- Parse `rec`/`end` keywords
- Parse branch syntax `| :label -> ...`
- Reserve `!!`/`??`/`!!:`/`??:` in the grammar
- Surface syntax to `sess-*` AST mapping

### Phase S2: Process Parsing

- Parse `defproc` declarations with implicit `self`
- Parse `proc` anonymous processes
- Parse multi-channel `[name : Session, ...]` bindings
- Parse `chan !`/`chan ?` in process bodies
- Parse `select`/`offer` in process bodies
- Parse `stop`/`new`/`par`/`link` keywords
- Surface syntax to `proc-*` AST mapping

### Phase S3: Elaboration

- Elaborate `session` declarations to session types (using existing `sess-*` constructors)
- Elaborate `defproc`/`proc` to process terms (using existing `proc-*` constructors)
- Handle `self` as implicit channel
- Handle dependent send/receive (`!:`/`?:`) with proper binding
- `throws` clause desugaring (syntactic sugar → implicit `&> | :error -> ...` at each step)

### Phase S4: Session Type Checking on Propagator Network

- Implement `SessionLattice` for propagator cells
- Session inference propagators (per §15.3)
- Duality bidirectional propagator
- ATMS integration for protocol violation derivations
- Cross-domain bridges (session ↔ type, session ↔ QTT)
- Deadlock detection via propagator quiescence analysis (unresolved choice cells = deadlock)

### Phase S5: Capability Integration

- `{cap :0 CapType}` on `defproc` headers
- `open`/`connect`/`listen` as capability-gated operations
- IO-bridge propagators with double-boundary checking
- Capability delegation through sessions (`:1` linear transfer)
- Compiler warnings for overauthorization

### Phase S6: `strategy` Declaration

- Parse `strategy` top-level keyword
- Strategy properties (`:fairness`, `:fuel`, `:io`)
- `spawn ... :strategy name` application
- Default strategy

### Phase S7: Runtime Execution

- Process-to-propagator compilation
- Channel cells (message passing via cell writes)
- `run-to-quiescence` as scheduler
- Session state advancement
- `stop` propagator (process termination)
- `new`/`par`/`link` process combinators

### Phase S8: Async Extension (Future)

- `!!`/`??` operators
- Promise cells
- `@` prefix operator for deref
- Promise pipelining

---

<a id="22-references"></a>

## 22. References

### Predecessor Documents
- `docs/research/2026-03-03_SESSION_TYPE_DESIGN_RESEARCH.md` — Phase I deep research
- `docs/research/2026-03-03_PROCESS_CALCULI_SURVEY.md` — Theoretical grounding
- `docs/tracking/2026-03-03_LE_SUBSYSTEM_AUDIT.md` — Subsystem audit recommending day-one propagator integration
- `docs/research/2026-03-03_PROPAGATOR_NETWORK_FUTURE_OPPORTUNITIES.md` — Propagator research

### Design Principles
- `docs/tracking/principles/DESIGN_PRINCIPLES.org` — Core design principles
- `docs/tracking/principles/LANGUAGE_VISION.org` — Language vision
- `docs/tracking/principles/CAPABILITY_SECURITY.md` — Capability security model
- `docs/tracking/principles/DESIGN_METHODOLOGY.md` — Five-phase design methodology

### Existing Implementation
- `racket/prologos/sessions.rkt` — Session type AST (9 constructors, 117 lines)
- `racket/prologos/processes.rkt` — Process AST (10 constructors, 84 lines)
- `racket/prologos/typing-sessions.rkt` — Process typing judgment (9 rules, 258 lines)
- `docs/spec/grammar.ebnf` — Session type grammar (sexp mode)
- `racket/prologos/redex/` — Formal Redex semantics (~80+ tests)

### Key External References
- Caires & Pfenning, "Session Types as Intuitionistic Linear Propositions" (CONCUR 2010)
- Honda, Yoshida, Carbone, "Multiparty Asynchronous Session Types" (JACM 2016)
- Toninho & Yoshida, "Practical Refinement Session Type Inference" (2025)
- Atkey, "Syntax and Semantics of Quantitative Type Theory" (LICS 2018)
- Gay & Hole, "Subtyping for Session Types in the Pi Calculus" (Acta Informatica 2005)
- Balzer & Pfenning, "Manifest Deadlock-Freedom for Shared Session Types" (ESOP 2017)
