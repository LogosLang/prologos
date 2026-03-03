# Session Type Design Research: Foundations for The Process Language

**Date**: 2026-03-03
**Status**: Deep Research (Design Methodology Phase 1)
**Audience**: Prologos design team
**Scope**: Phase I design foundations for `session`/`defproc` — syntax, semantics, integration
**Companion**: `2026-03-03_PROCESS_CALCULI_SURVEY.md` (theoretical grounding)

---

## Table of Contents

- [1. Motivation and Scope](#1-motivation)
- [2. Existing Infrastructure Inventory](#2-infrastructure)
- [3. Design Principles for The Process Language](#3-principles)
- [4. Channel Operations: Send and Receive](#4-channel-operations)
- [5. Choice and Selection](#5-choice-selection)
- [6. Protocol Declaration: The `session` Keyword](#6-session-keyword)
- [7. Process Definition: The `defproc` Keyword](#7-defproc-keyword)
- [8. Recursion and Loops](#8-recursion)
- [9. Channel Creation and Composition](#9-channels)
- [10. Linear Resource Tracking: QTT Integration](#10-qtt)
- [11. Syntax Exploration: The Prologos Way](#11-syntax-exploration)
- [12. Propagator Network Integration](#12-propagator-integration)
- [13. Schema and Capability Integration](#13-schema-capability)
- [14. Multiparty Considerations](#14-multiparty)
- [15. Blocking, Non-Blocking, and Eventual Send](#15-blocking)
- [16. Dependent Sessions: Value-Dependent Protocols](#16-dependent)
- [17. Error Handling in Protocols](#17-errors)
- [18. Open Questions for Phase 2 Refinement](#18-open-questions)
- [19. References](#19-references)

---

<a id="1-motivation"></a>

## 1. Motivation and Scope

### 1.1 The Specification Triple

Prologos has three co-equal paradigms, each with a specification form:

| Paradigm | Spec Form | Named Impl | Anonymous | Bracket | Describes |
|----------|-----------|-----------|-----------|---------|-----------|
| Functional | `spec` | `defn` | `fn` | `[...]` | What a function **computes** |
| Relational | `schema` | `defr` | `rel` | `(...)` | What data **looks like** |
| Process | `session` | `defproc` | `proc` | indentation | What a conversation **does** |

`session` is the third leg. It describes **protocols** — the structured sequence of
messages exchanged between communicating parties. Where `spec` types functions and
`schema` types data, `session` types conversations.

### 1.2 What Session Types Buy Us

1. **Protocol correctness**: Messages match expected types and arrive in expected order
2. **Deadlock freedom**: For single-session interactions, guaranteed by the type system
3. **Resource safety**: Linear channels are used exactly according to protocol (no dropped messages, no leaked channels)
4. **Capability delegation**: Authority transfers follow typed protocols (Section 13)
5. **Documentation as types**: The session type IS the protocol specification

### 1.3 Day-One Propagator Network Integration

The LE Subsystem Audit (2026-03-03) recommends building session types on the propagator
network from day one. Key reasons:

- Session type inference maps to constraint propagation over a session lattice
- Duality checking is a bidirectional propagator
- ATMS provides protocol verification with derivation chains for error messages
- Cross-domain Galois connections compose session, type, QTT, and capability constraints

### 1.4 Design Methodology

This document follows Design Methodology Phase 1 (Deep Research):
- Survey the design space with concrete syntax examples
- Identify tradeoffs and align with principles
- Produce open questions for Phase 2 (Refinement and Gap Analysis)

---

<a id="2-infrastructure"></a>

## 2. Existing Infrastructure Inventory

### 2.1 Session Types (`sessions.rkt`, 117 lines)

Nine session type constructors, translated from the Maude formal spec:

| Struct | Notation | Meaning |
|--------|----------|---------|
| `sess-send` | `!A.S` | Send type A, continue with S |
| `sess-recv` | `?A.S` | Receive type A, continue with S |
| `sess-dsend` | `!(x:A).S` | Dependent send: x binds in S |
| `sess-drecv` | `?(x:A).S` | Dependent receive: x binds in S |
| `sess-choice` | `+{l1:S1, l2:S2}` | Internal choice (this process selects) |
| `sess-offer` | `&{l1:S1, l2:S2}` | External choice (other endpoint selects) |
| `sess-mu` | `mu X. S` | Recursive session type |
| `sess-svar` | `X` | Session variable (de Bruijn index) |
| `sess-end` | `End` | Session termination |

Plus `sess-meta` (Sprint 8: unsolved session continuation for inference) and
`sess-branch-error` (sentinel for failed lookups).

Operations: `dual`, `substS` (dependent substitution), `unfold-session`, `lookup-branch`.

### 2.2 Processes (`processes.rkt`, 84 lines)

Ten process constructors:

| Struct | Meaning |
|--------|---------|
| `proc-stop` | Process termination |
| `proc-send` | Send expression on channel, continue |
| `proc-recv` | Receive from channel into typed variable, continue |
| `proc-sel` | Select branch (internal choice) on channel |
| `proc-case` | Offer branches (external choice) on channel |
| `proc-new` | Create new channel with session type |
| `proc-par` | Parallel composition |
| `proc-link` | Forward/link between channels |
| `proc-solve` | Proof search (axiomatic reasoning) |
| `proc-no-proc` | Sentinel for failed lookup |

Channel contexts: immutable hash (channel -> session type) with add/remove/lookup/update.

### 2.3 Process Typing (`typing-sessions.rkt`, 258 lines)

Nine typing rules implementing `type-proc(gamma, delta, P) -> Bool`:
- `gamma`: unrestricted context (functional types)
- `delta`: linear channel context (channel -> session mapping)

Rules: Stop, Send, Recv, Select, Case, New, Par, Link, Solve.
Context splits for `Par` rule enumerate all 2^n partitions.

Sprint 8 feature: session continuation inference via `sess-meta` — when a process
operation encounters an unsolved meta, the operation structure determines the session shape.

### 2.4 Grammar (`grammar.ebnf`, lines 1064-1091)

S-expression session type syntax is defined. WS-mode session syntax is not yet specified.

### 2.5 Formal Semantics

Full Redex formalization in `racket/prologos/redex/`: `sessions.rkt`, `processes.rkt`,
`typing-sessions.rkt`. ~80+ test cases across test files.

### 2.6 What's Missing

1. Surface syntax parsing for `session`/`defproc` (grammar exists, not integrated into parser.rkt)
2. Elaboration from surface syntax to typed processes
3. Propagator network integration
4. Runtime execution of processes (process scheduler, channel implementation)
5. WS-mode syntax design (the focus of this document)

---

<a id="3-principles"></a>

## 3. Design Principles for The Process Language

Drawing from `DESIGN_PRINCIPLES.org` and `LANGUAGE_VISION.org`:

### 3.1 Progressive Disclosure

Session types follow the same progressive disclosure ladder as the rest of Prologos:

| Level | What the user writes | What they get |
|-------|---------------------|--------------|
| 0 | Functions with `defn` | No concurrency, no sessions |
| 1 | `defproc` with simple send/recv | Basic typed communication |
| 2 | `session` declaration with branches | Full protocol specification |
| 3 | Dependent sessions, capability delegation | Value-dependent protocols |
| 4 | Multiparty, refinement, propagator integration | Research-level power |

A user writing their first `defproc` should not need to understand linear logic.

### 3.2 Decomplection

Session types participate in the decomplection strategy:
- **Session/defproc decoupled**: what the protocol IS (session) vs how it's IMPLEMENTED (defproc)
- **Protocol/data decoupled**: session types describe message ORDER; schema describes message SHAPE
- **Communication/computation decoupled**: process operations (send/recv) vs functional operations (fn/apply)
- **Linearity/multiplicity**: QTT handles resource tracking; session types handle protocol structure

### 3.3 Homoiconicity

Every session type and process expression must have a canonical s-expression representation.
The WS-mode surface syntax is sugar that desugars to s-expressions at the reader/preparse level.

### 3.4 The Most Generalizable Interface

Prefer the widest interface:
- Binary session types first (simplest, most general for two-party)
- Multiparty via orchestrator pattern (binary sessions + coordinator process)
- Future: native multiparty global types if binary+orchestrator proves insufficient

### 3.5 AI-First Design

Session types support AI agent infrastructure:
- Session-typed protocols for agent communication
- Derivation trees (ATMS) for protocol reasoning and explanation
- `proc-solve` for proof search within protocols

---

<a id="4-channel-operations"></a>

## 4. Channel Operations: Send and Receive

### 4.1 The Core Question: Syntax for Communication

Communication is the fundamental operation. The syntax must be:
- Clear about direction (sending vs receiving)
- Clear about the channel
- Clear about what's being sent/received
- Composable with the rest of Prologos

### 4.2 Design Options

**Option A: Keyword-verb (current sexp grammar)**

```prologos
;; sexp mode (current)
(send expr chan cont)
(recv chan type cont)

;; WS mode (verb-first)
send [compute-result x] on self
  <continuation>
recv response : ResultType from self
  <continuation>
```

Pros: Clear English verbs. Self-documenting. Familiar to Erlang/Elixir users.
Cons: Verbose. `on`/`from` are noise words. Continuation nesting gets deep.

**Option B: Operator-concise (`!`/`?`)**

```prologos
;; Protocol declaration
session Greeting
  ! String          ;; send a String
  ? String          ;; receive a String
  end

;; Process implementation
defproc greeter : Greeting [self]
  self ! "hello"
  name := self ?
  stop
```

Pros: Concise. `!` (bang) = output, `?` (query) = input — established in CSP/pi-calc.
Cons: `!` and `?` are overloaded (already used for predicates `zero?`, list access).
May confuse beginners.

**Option C: Arrow-chain (Haskell/do-notation inspired)**

```prologos
defproc greeter : Greeting [self]
  self <- "hello"       ;; send (arrow points to channel)
  name <- self           ;; receive (arrow points from channel)
  stop
```

Pros: Visually shows data flow direction. `<-` is familiar from Haskell do-notation.
Cons: `<-` already has meaning in some contexts. Direction is ambiguous without context.

**Option D: Channel-method (OOP-inspired)**

```prologos
defproc greeter : Greeting [self]
  [self.send "hello"]
  let name := [self.recv]
  stop
```

Pros: Familiar to OOP programmers. Method syntax is natural.
Cons: Doesn't match Prologos's functional style. `.` is already map-access syntax.

### 4.3 Preliminary Assessment

Option B (`!`/`?`) is the most aligned with Prologos's principles:
- **Concise**: Minimal syntax, maximal meaning
- **Formally grounded**: `!`/`?` are standard in session type literature
- **Progressive disclosure**: Simple at first (`!`/`?`), richer with types and dependencies

**However**, we need to resolve the `?` collision with predicate naming (`zero?`, `empty?`).
Context disambiguation: `?` after a channel name is receive; `?` at end of identifier is
predicate suffix. The parser can distinguish these syntactically.

---

<a id="5-choice-selection"></a>

## 5. Choice and Selection

### 5.1 The Duality of Choice

Session types have two kinds of branching:

- **Internal choice** (`+{...}`): THIS process decides which branch to take.
  The other endpoint must be prepared for any branch (offers all).
- **External choice** (`&{...}`): The OTHER endpoint decides.
  This process offers all branches and waits for selection.

This is the additive conjunction/disjunction from linear logic:
- `A & B` (with): I offer both A and B — you choose
- `A + B` (plus): I choose either A or B — you accept

### 5.2 Design Options

**Option A: Keyword blocks with `|` branches**

```prologos
;; Internal choice (this process selects)
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

;; External choice (other process selects)
session WorkerProtocol
  &>
    | :task
        ? TaskData
        ! TaskResult
        rec
    | :shutdown
        end
```

Operators: `+>` for internal choice (select), `&>` for external choice (offer).
Branches use `|` with `:label` keywords (consistent with schema/selection).

**Option B: `choose`/`offer` keywords**

```prologos
session OrderProtocol
  ? OrderRequest
  ! Quote
  choose
    | :accept -> ? PaymentInfo -> ! Confirmation -> end
    | :reject -> end

session WorkerProtocol
  offer
    | :task -> ? TaskData -> ! TaskResult -> rec
    | :shutdown -> end
```

**Option C: `select`/`case` (pi-calculus style)**

Note: `select` is already used as a parser keyword for session internal choice
in the existing sexp grammar (`(select chan label cont)`).

```prologos
;; In process definitions
defproc order-handler : OrderProtocol [self]
  req := self ?
  self ! [compute-quote req]
  select self
    | :accept ->
        payment := self ?
        self ! [process-payment payment]
        stop
    | :reject ->
        stop
```

### 5.3 Preliminary Assessment

Option A (`+>`/`&>`) aligns with existing Prologos conventions:
- `+>` and `&>` are session-specific operators (no collision)
- `|` branches are consistent with `match`, `defn` multi-clause, schema closed-check
- `:label` keywords are consistent with schema fields and selection paths
- Reads naturally: `+>` = "I choose forward", `&>` = "you choose forward"

For process definitions, the distinction maps naturally:
- In `session` (protocol declaration): `+>` / `&>` declare the choice structure
- In `defproc` (implementation): `select self ...` / `offer self ...` implement it

---

<a id="6-session-keyword"></a>

## 6. Protocol Declaration: The `session` Keyword

### 6.1 Design

`session` declares a protocol type — the specification of a conversation. It is to
`defproc` what `spec` is to `defn`: the what, not the how.

```prologos
session ProtocolName
  <session-body>
```

The session body is a sequence of protocol steps:

```prologos
session FileAccess
  ! Path                           ;; client sends a path
  ? Result Handle IOError          ;; server responds with handle or error
  +>                               ;; client chooses
    | :read
        ? String                   ;; server sends file contents
        rec                        ;; loop
    | :write
        ! String                   ;; client sends data to write
        ? Result Unit IOError      ;; server responds with success/error
        rec                        ;; loop
    | :close
        end                        ;; protocol terminates
```

### 6.2 Relationship to `spec`

`session` follows the keyword metadata pattern established by `spec`:

```prologos
session FileAccess
  :doc "Protocol for file I/O operations"
  :deprecated "Use FileAccess2 instead"
  :examples
    [file-access-example1]
    [file-access-example2]

  ! Path
  ? Result Handle IOError
  ...
```

### 6.3 Schema Integration

Session messages can reference schemas and selections:

```prologos
schema User
  :id UserId
  :name String
  :email Email

selection MovieTimesReq from User
  :requires [:id :address.zip]

session MovieService
  ? User * MovieTimesReq         ;; receive a User satisfying MovieTimesReq
  ! List MovieTime               ;; respond with movie times
  end
```

The `*` (Sigma) operator in `? User * MovieTimesReq` means "receive a User value
that satisfies the MovieTimesReq selection." The selection gates which fields the
process can access.

### 6.4 S-Expression Canonical Form

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

---

<a id="7-defproc-keyword"></a>

## 7. Process Definition: The `defproc` Keyword

### 7.1 Design

`defproc` defines a named process that implements a session type.

```prologos
defproc process-name : SessionType [self-channel]
  <process-body>
```

The `self-channel` is the channel endpoint this process uses to communicate with
the other party. (In Caires-Pfenning terms, this is the "provided" channel.)

### 7.2 Anonymous Processes

`proc` creates an anonymous process (like `fn` for functions):

```prologos
;; Named
defproc greeter : Greeting [self]
  self ! "hello"
  name := self ?
  stop

;; Anonymous (e.g., for spawning)
spawn (proc : Greeting [ch]
  ch ! "hello"
  name := ch ?
  stop)
```

### 7.3 Process Body Operations

| Operation | Syntax | Meaning |
|-----------|--------|---------|
| Send | `chan ! expr` | Send value on channel |
| Receive | `var := chan ?` | Receive value from channel |
| Select | `select chan :label` | Choose a branch (internal choice) |
| Offer | `offer chan \| :l1 -> P1 \| :l2 -> P2` | Handle branch selection (external choice) |
| Stop | `stop` | Terminate process (all channels must be ended) |
| New | `new [c1 c2] : Session in ...` | Create channel pair with session type |
| Parallel | `par P1 P2` | Run two processes in parallel |
| Link | `link c1 c2` | Forward channel c1 to c2 (delegation) |

### 7.4 Pattern Matching on Received Values

Received values can be pattern-matched:

```prologos
defproc auth-server : AuthProtocol [self]
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

### 7.5 Functional Computation Within Processes

Processes can use the full functional language internally:

```prologos
defproc calculator : CalcProtocol [self]
  offer self
    | :add ->
        x := self ?
        y := self ?
        self ! [+ x y]     ;; functional computation
        rec
    | :quit ->
        stop
```

---

<a id="8-recursion"></a>

## 8. Recursion and Loops

### 8.1 Recursive Session Types

Recursive protocols use `rec` / `mu`:

```prologos
;; Session declaration: explicit recursion label
session Counter
  rec Loop
    +>
      | :inc -> ! Nat -> Loop        ;; send count, loop
      | :done -> end

;; Equivalently (anonymous recursion):
session Counter
  rec
    +>
      | :inc -> ! Nat -> rec
      | :done -> end
```

### 8.2 Named vs Anonymous Recursion

Named recursion (`rec Loop ... Loop`) is clearer for complex protocols:

```prologos
session TwoPhase
  rec Negotiate
    ? Offer
    +>
      | :counter -> ! CounterOffer -> Negotiate   ;; back to negotiation
      | :accept -> rec Execute
          ? Task
          ! Result
          +>
            | :more -> Execute     ;; more tasks
            | :done -> end
      | :reject -> end
```

### 8.3 Tail Recursion

Only tail-recursive protocols are valid — a recursion variable must appear in tail
position (the last step before the branch ends). This ensures protocols always make
progress and don't accumulate unbounded state.

---

<a id="9-channels"></a>

## 9. Channel Creation and Composition

### 9.1 Channel Pairs

`new` creates a channel pair — two endpoints with dual session types:

```prologos
;; Create a channel pair
new [client server] : FileAccess

;; client has type FileAccess (sends path, receives handle, ...)
;; server has type dual(FileAccess) (receives path, sends handle, ...)
```

### 9.2 Parallel Composition

`par` runs two processes simultaneously, splitting the linear channel context:

```prologos
;; Connect a client and server
new [c s] : Greeting
par
  (proc [c]
    c ! "hello"
    name := c ?
    stop)
  (proc [s]
    greeting := s ?
    s ! "world"
    stop)
```

### 9.3 Channel Delegation (Link/Forward)

A process can delegate its channel to another process:

```prologos
;; Forward: this process exits, passing its channel to another
defproc proxy : FileAccess [self]
  link self [real-server-channel]

;; Delegation: send a channel endpoint as a message
defproc coordinator : CoordProtocol [self]
  new [worker-ch my-ch] : WorkProtocol
  self ! worker-ch          ;; send one endpoint to the client
  handle-work my-ch         ;; use the other endpoint locally
```

### 9.4 Structured Concurrency

Channels created with `new` are scoped — they cannot escape the enclosing `par` block.
This prevents dangling channel references and ensures all channels are properly closed
before the scope exits. Structured concurrency is the default; unstructured
(via capability-gated `spawn`) is available for advanced use cases.

---

<a id="10-qtt"></a>

## 10. Linear Resource Tracking: QTT Integration

### 10.1 Channels and Multiplicities

Channels are linear by default (`:1` multiplicity):

```prologos
;; Channel c has multiplicity :1 — used exactly once per protocol step
defproc example : SomeProtocol [c :1]
  c ! "hello"     ;; c transitions from (Send String . S) to S
  name := c ?     ;; c transitions from (Recv String . S') to S'
  stop             ;; c must be at End
```

### 10.2 Shared Channels

Shared channels (`:w` multiplicity) correspond to `!S` in linear logic — a
reusable service that can accept unlimited connections:

```prologos
;; A shared logging service
session LogService
  shared                    ;; marks this as a shared (reusable) session
    ? String                ;; receive log message
    end

defproc logger : LogService [self :w]
  msg := self ?
  [write-log msg]
  stop                      ;; will be restarted (shared service)
```

### 10.3 Erased Protocol Types

`:0` (erased) multiplicity for session types that exist only at compile time:

```prologos
;; The session type is erased at runtime — only used for protocol checking
spec my-service : <(s :0 ServiceProtocol) -> IO Unit>
```

### 10.4 QTT-Session Galois Connection

The QTT multiplicity lattice `{0, 1, omega}` connects to the session type lattice
via Galois connection:

- alpha: `session-type -> multiplicity`
  - `Send/Recv/Choice/Offer/Mu` -> `:1` (linear: protocol step consumes/produces)
  - `End` -> `:0` (erased: session is complete)
  - `shared S` -> `:w` (unrestricted: reusable service)

- gamma: `multiplicity -> session-constraint`
  - `:1` -> "this channel must be at a non-End session type"
  - `:0` -> "this channel is at End or is a type-level phantom"
  - `:w` -> "this channel must be a shared (`!`) session type"

---

<a id="11-syntax-exploration"></a>

## 11. Syntax Exploration: The Prologos Way

### 11.1 Guiding Principles for Syntax

1. **Ergonomic and concise**: Minimize ceremony, maximize clarity
2. **Formally grounded but approachable**: Rooted in linear logic, surface feels natural
3. **Consistent with existing Prologos conventions**: `|` branches, `:keyword` labels,
   indentation for control
4. **Protocols-as-types in the domain of everyone**: A non-expert should be able to
   read and write simple protocols

### 11.2 Variation A: Operator-Concise (Recommended Direction)

```prologos
;; Protocol declaration
session Greeting
  ! String
  ? String
  end

session FileAccess
  ! Path
  ? Result Handle IOError
  +>
    | :read  -> ? String -> rec
    | :write -> ! String -> ? Result Unit IOError -> rec
    | :close -> end

;; Process implementation
defproc greeter : Greeting [self]
  self ! "hello"
  name := self ?
  stop

defproc file-server : FileAccess [self]
  path := self ?
  self ! [open-file path]
  offer self
    | :read ->
        self ! [read-file path]
        rec
    | :write ->
        data := self ?
        self ! [write-file path data]
        rec
    | :close ->
        stop
```

**Strengths:**
- `!`/`?` are immediately recognizable from the session type literature
- `+>` (internal choice) and `&>` (external choice) are unambiguous
- `offer`/`select` in process code clearly indicate who decides
- `:keyword` labels match schema field syntax
- `rec` is clear and concise
- Indentation-based branching matches `match` and `defn` patterns

### 11.3 Variation B: Keyword-Verbose

```prologos
session FileAccess
  send Path
  recv Result Handle IOError
  choose
    | :read  -> recv String -> loop
    | :write -> send String -> recv Result Unit IOError -> loop
    | :close -> end

defproc file-server : FileAccess [self]
  recv path from self
  send [open-file path] on self
  offer self
    | :read ->
        send [read-file path] on self
        loop
    | :write ->
        recv data from self
        send [write-file path data] on self
        loop
    | :close ->
        stop
```

**Strengths:** Maximally readable. No operator overloading concerns.
**Weaknesses:** Verbose. `from`/`on` are noise. `send`/`recv` are long.

### 11.4 Variation C: Arrow-Chain

```prologos
session FileAccess
  ! Path -> ? Result Handle IOError ->
  +> :read  -> ? String -> rec
   | :write -> ! String -> ? Result Unit IOError -> rec
   | :close -> end

defproc file-server : FileAccess [self]
  path <- self
  self <- [open-file path]
  self &>
    | :read  -> self <- [read-file path] -> rec
    | :write -> data <- self -> self <- [write-file path data] -> rec
    | :close -> stop
```

**Strengths:** Very concise. Arrow chains read as data flow.
**Weaknesses:** `<-` direction is ambiguous (send or receive?). Dense.

### 11.5 Variation D: Dependent-First

For protocols where dependencies matter:

```prologos
session VecTransfer
  ? (n : Nat)                    ;; receive length (binds n)
  ? (Vec String n)               ;; receive vector of exactly n strings
  ! Bool                         ;; send acknowledgment
  end

session AuthProtocol
  ? (cred : Credentials)         ;; receive credentials (binds cred)
  ! (verdict : AuthResult)       ;; send auth result (binds verdict)
  match verdict                  ;; protocol branches on value
    | Granted token ->
        ! AuthToken
        AdminSession
    | Denied reason ->
        ! String
        end
```

This variation makes dependencies and value-branching first-class in the syntax.

### 11.6 Assessment

**Recommended direction: Variation A (Operator-Concise)** with elements of D (Dependent)
for advanced use cases.

| Feature | Syntax | Used in |
|---------|--------|---------|
| Send (protocol) | `! Type` | `session` declaration |
| Receive (protocol) | `? Type` | `session` declaration |
| Dependent send | `! (x : Type)` | `session` declaration |
| Dependent receive | `? (x : Type)` | `session` declaration |
| Internal choice | `+>` | `session` declaration |
| External choice | `&>` | `session` declaration |
| Branch | `\| :label -> ...` | Both `session` and `defproc` |
| Recursion | `rec` / `rec Label` | Both |
| Termination | `end` | `session` declaration |
| Send (process) | `chan ! expr` | `defproc` body |
| Receive (process) | `var := chan ?` | `defproc` body |
| Select (process) | `select chan :label` | `defproc` body |
| Offer (process) | `offer chan \| ...` | `defproc` body |
| Stop (process) | `stop` | `defproc` body |

---

<a id="12-propagator-integration"></a>

## 12. Propagator Network Integration

### 12.1 Session Type Lattice

Session types under subtyping form a lattice:

```
SessionTop (any protocol — accepts everything)
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

### 12.2 Session Inference via Propagation

Each channel endpoint is a cell in the `SessionLattice`. Process operations create
propagators:

```
Operation:    self ! "hello"
Effect:       Add propagator: cell(self) must be (Send String . S) for some S
              Create fresh meta-cell for S
              Write constraint to cell(self)

Operation:    name := self ?
Effect:       Add propagator: cell(self) must be (Recv T . S) for some T, S
              Bind name : T in context
              Advance cell(self) to S

Operation:    select self :read
Effect:       Add propagator: cell(self) must be (Choice with :read branch)
              Advance cell(self) to the :read continuation
```

`run-to-quiescence` infers the session type for each channel.

### 12.3 Duality as Bidirectional Propagator

When `new [c1 c2] : S` creates a channel pair:
- Cell(c1) = S
- Cell(c2) = dual(S)
- Add propagator: `cell(c2) = dual(cell(c1))` (bidirectional)

Any constraint on c1 propagates to c2 (and vice versa) via the duality propagator.

### 12.4 ATMS for Protocol Verification

Each protocol step is an ATMS assumption. When a contradiction occurs (protocol
violation), the ATMS provides the derivation chain:

```
Protocol violation at line 42:
  Channel self was inferred to be (Send String . End) because:
    - self ! "hello"    [line 10, assumption A1]
    - self ! "world"    [line 11, assumption A2]  <- second send advances past End
  But End was reached after A1, making A2 a violation.
  Minimal conflict: {A1, A2}
```

### 12.5 Cross-Domain Bridges

| Bridge | Direction | What It Enables |
|--------|-----------|----------------|
| Session <-> Type | Session step types <-> functional types | Type inference for message types |
| Session <-> QTT | Session structure <-> multiplicities | Linear resource checking |
| Session <-> Capability | Session operations <-> cap requirements | Authority delegation verification |
| Session <-> Abstract | Protocol states <-> abstract values | Static analysis of protocol properties |

---

<a id="13-schema-capability"></a>

## 13. Schema and Capability Integration

### 13.1 Schema-Typed Messages

Session types reference schemas for message types:

```prologos
schema Employee
  :name String
  :dept Department
  :salary Int

selection EmployeeSummary from Employee
  :requires [:name :dept]

session EmployeeService
  ? (query : String)                        ;; receive query string
  ! Employee * EmployeeSummary              ;; send employee with only name+dept accessible
  end
```

The selection gates field access — the receiver can only read `:name` and `:dept`,
even though the full `Employee` was sent. This is the "least authority" principle
applied to data in transit.

### 13.2 Capability Delegation via Sessions

Session types enforce capability transfer protocols:

```prologos
session FileAccessGrant
  ? (path : Path)                           ;; client requests access to a path
  ! (Result (FileCap path :1) DenyReason)   ;; server grants linear capability or denies
  +>
    | :use ->                               ;; client will use the capability
        ? Unit                              ;; client signals done
        end
    | :delegate ->                          ;; client delegates to a third party
        ? ProcessId                         ;; client tells server who gets it
        end
```

The `:1` on `FileCap path` ensures the capability is transferred exactly once —
it can't be duplicated by the receiver. QTT's linear multiplicity enforces this.

### 13.3 Variance at Session Boundaries

From the schema+selection design (section 6.5):

- **Input position** (`? req : S`): **Contravariant** — can relax requirements
  (accept more than the protocol demands)
- **Output position** (`! resp : S`): **Covariant** — can strengthen provisions
  (provide more than the protocol promises)

This maps to `:requires` (contravariant, input) and `:provides` (covariant, output)
in the selection system.

---

<a id="14-multiparty"></a>

## 14. Multiparty Considerations

### 14.1 Binary-First Strategy

Prologos starts with binary session types (two-party protocols). For multi-party
interactions, use the **orchestrator pattern**:

```prologos
;; Three-party protocol via binary sessions + orchestrator
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

### 14.2 Why Not Global Types (Yet)

Global types (MPST) add complexity:
- Merge condition limits expressiveness
- Projection is partial (not all global types project)
- Implementation requires a global coordinator or knowledge of all participants

The orchestrator pattern achieves the same effect with simpler, composable binary sessions.
If this proves insufficient, native MPST can be added later — the propagator network
naturally supports multi-cell constraints across multiple channels.

### 14.3 Future: Propagator Network as Coordination Substrate

For multiparty protocols, the propagator network can serve as the coordination mechanism:
- Each participant's session type is a cell
- Global type constraints are multi-cell propagators
- Projection is computed by `run-to-quiescence` rather than a separate algorithm

---

<a id="15-blocking"></a>

## 15. Blocking, Non-Blocking, and Eventual Send

### 15.1 Default: Synchronous (Blocking)

The default communication model is synchronous: `!` blocks until the receiver is ready,
`?` blocks until a message arrives. This matches the classical session type semantics
and is easiest to reason about.

### 15.2 Non-Blocking / Eventual Send

For asynchronous patterns, Prologos could support `!!` (eventual send) and `??`
(eventual receive / promise):

```prologos
session AsyncGreeting
  !! String          ;; non-blocking send (message buffers)
  ?? String          ;; eventual receive (returns a promise)
  end

defproc async-greeter : AsyncGreeting [self]
  self !! "hello"        ;; non-blocking: message queued
  promise := self ??     ;; returns immediately with a promise
  ;; ... do other work ...
  name := [await promise] ;; force the promise
  stop
```

### 15.3 Promise Pipelining

In distributed scenarios, promise pipelining avoids round-trips:

```prologos
;; Without pipelining: 3 round-trips
result1 := server ?
result2 := [send-and-receive server [compute result1]]
result3 := [send-and-receive server [compute result2]]

;; With pipelining: 1 round-trip (results computed on server side)
promise1 := server ??
server !! [compute promise1]
promise2 := server ??
server !! [compute promise2]
result3 := [await (server ??)]
```

### 15.4 Design Decision

**Recommendation:** Start with synchronous (blocking) semantics only. Add `!!`/`??`
as a second phase after the core is stable. Reasons:

1. Synchronous is simpler to type-check and reason about
2. Asynchronous subtyping is undecidable in general (Bravetti et al., 2019)
3. The synchronous core establishes the foundation; async is an extension

---

<a id="16-dependent"></a>

## 16. Dependent Sessions: Value-Dependent Protocols

### 16.1 What Dependent Sessions Enable

The protocol shape depends on values exchanged at runtime:

```prologos
;; Send n, then send exactly n items
session VecTransfer
  ? (n : Nat)                ;; receive n (binds n in continuation)
  ? (Vec String n)           ;; receive a vector of exactly n strings
  ! Bool                     ;; acknowledge
  end
```

### 16.2 Syntax for Dependent Send/Receive

In session declarations, parenthesized binders indicate dependency:

```prologos
;; Non-dependent (current syntax)
! String              ;; send a String (value not bound)
? Nat                 ;; receive a Nat (value not bound)

;; Dependent (value binds in continuation)
! (msg : String)      ;; send a String, bind as 'msg' in continuation
? (n : Nat)           ;; receive a Nat, bind as 'n' in continuation
```

### 16.3 Value-Dependent Branching

The most powerful form: protocol structure depends on a runtime value:

```prologos
session AuthProtocol
  ? (cred : Credentials)
  ! (result : AuthResult)
  match result
    | Granted ->
        ! AuthToken
        ! (perms : Permissions)     ;; permissions depend on who authenticated
        AdminSession perms          ;; rest of protocol depends on permissions
    | Denied ->
        ! String                    ;; error message
        end
```

This connects to the Toninho-Caires-Pfenning work on dependent session types:
`(x : A) -> S(x)` in the session type corresponds to `Pi x:A. S(x)` in the type theory.

### 16.4 Prologos's Advantage

Prologos already has full dependent types (Pi, Sigma, substitution, reduction).
Dependent session types are a natural extension — `substS` in `sessions.rkt` already
implements dependent substitution for session types. The infrastructure is ready;
only the surface syntax needs design.

---

<a id="17-errors"></a>

## 17. Error Handling in Protocols

### 17.1 The Problem

What happens when a protocol can't continue? A file server may fail to open a file;
a network connection may drop; an authentication may be invalid. Session types must
account for error paths.

### 17.2 Errors as Branches

The simplest approach: model errors as explicit choice branches:

```prologos
session RobustFileAccess
  ! Path
  &>                                ;; server decides
    | :ok ->
        ! Handle
        ... (normal protocol)
    | :error ->
        ! IOError
        end
```

This is explicit but forces the protocol designer to enumerate all error paths.

### 17.3 Exception Sessions

A more structured approach: `throws` clause on session types:

```prologos
session FileAccess throws IOError
  ! Path
  ? Handle
  +>
    | :read -> ? String -> rec
    | :close -> end
```

The `throws IOError` means: at any point in the protocol, the server may abort with
an `IOError`. The client must have a handler. This desugars to an implicit `&>` at
every step:

```prologos
;; Desugared:
session FileAccess
  &>
    | :normal -> ! Path -> &> | :normal -> ? Handle -> ... | :error -> ? IOError -> end
    | :error -> ? IOError -> end
```

### 17.4 Design Decision

**Recommendation:** Start with errors as explicit branches (17.2). The `throws`
extension (17.3) can be added as syntactic sugar in a later phase.

---

<a id="18-open-questions"></a>

## 18. Open Questions for Phase 2 Refinement

### 18.1 Syntax Decisions

1. **Operator syntax**: Is `!`/`?` the right choice, given `?` suffix for predicates?
   - Mitigation: Context-dependent parsing (after channel name = session op, end of
     identifier = predicate suffix)
   - Alternative: Different operators for session send/receive vs protocol declaration

2. **Process self-channel**: Should it be explicit `[self]` or implicit?
   - Explicit: clearer, more consistent, supports multi-channel processes
   - Implicit: simpler for single-channel (most common case)

3. **Recursion syntax**: `rec` vs `loop` vs named recursion?
   - `rec` is standard in session type literature
   - `loop` is more familiar to imperative programmers

### 18.2 Semantic Decisions

4. **Blocking model**: Synchronous first, async later? Or design for async from the start?
   - Sync first is simpler but may constrain future async extensions
   - Async from start is harder but avoids migration pain

5. **Deadlock freedom**: How much do we guarantee?
   - Single-session: free (by construction, like Caires-Pfenning)
   - Multi-session: priority-based (Padovani) or manifest (Balzer-Pfenning)?
   - Or: detect cycles in the propagator network's dependency graph?

6. **Multiparty**: Binary + orchestrator forever, or global types later?
   - Orchestrator is sufficient for most practical cases
   - Global types are cleaner for true multi-party protocols
   - The propagator network can support both

### 18.3 Integration Decisions

7. **Schema integration**: How deep should `*` (Sigma) integration go?
   - Shallow: selection just gates field access (current design)
   - Deep: selection participates in session type subtyping

8. **Capability integration**: Are capabilities sent as messages or as session constraints?
   - As messages: `! FileCap path :1` (capability is a value in the protocol)
   - As constraints: session type carries capability requirements implicitly

9. **Propagator integration**: When to build the session type lattice?
   - Phase E3 (type inference migration): add session lattice alongside type lattice
   - Independent: build session checking on propagators first, merge later

### 18.4 Runtime Decisions

10. **Process execution model**: Green threads? OS threads? Coroutines?
    - Green threads (like Erlang): lightweight, many processes
    - Coroutines (like Lua): cooperative, single-threaded
    - Propagator-scheduled: processes as propagators, `run-to-quiescence` as scheduler

11. **Channel implementation**: Shared memory queues? Message passing? Propagator cells?
    - For in-process: shared memory queues with linear ownership transfer
    - For distributed: message passing with serialization
    - For coordination: propagator cells with session-type-aware merge

---

<a id="19-references"></a>

## 19. References

### Theoretical Foundations
- See companion document: `2026-03-03_PROCESS_CALCULI_SURVEY.md`

### Prologos Design Documents
- `DESIGN_PRINCIPLES.org` — Core design principles
- `LANGUAGE_VISION.org` — Language vision and aspirations
- `DESIGN_METHODOLOGY.org` — Design process
- `CAPABILITY_SECURITY.md` — Capability security principles
- `2026-03-03_LE_SUBSYSTEM_AUDIT.md` — LE audit (session types recommendation)
- `2026-03-03_PROPAGATOR_NETWORK_FUTURE_OPPORTUNITIES.md` — Propagator research
- `2026-03-02_2200_SCHEMA_SELECTION_DESIGN.md` — Schema/selection integration

### Prologos Implementation
- `sessions.rkt` — Session type AST and operations (117 lines)
- `processes.rkt` — Process AST and channel contexts (84 lines)
- `typing-sessions.rkt` — Process typing judgment (258 lines)
- `grammar.ebnf` — Session type grammar (s-expression mode)
- `redex/sessions.rkt` — Formal Redex semantics

### Key External References
- Caires & Pfenning, "Session Types as Intuitionistic Linear Propositions" (CONCUR 2010)
- Honda, Yoshida, Carbone, "Multiparty Asynchronous Session Types" (JACM 2016)
- Toninho & Yoshida, "Practical Refinement Session Type Inference" (2025)
- Atkey, "Syntax and Semantics of Quantitative Type Theory" (LICS 2018)
- Gay & Hole, "Subtyping for Session Types in the Pi Calculus" (Acta Informatica 2005)
- Balzer & Pfenning, "Manifest Deadlock-Freedom for Shared Session Types" (ESOP 2017)
- Saraswat, "Concurrent Constraint Programming" (MIT Press 1993)
