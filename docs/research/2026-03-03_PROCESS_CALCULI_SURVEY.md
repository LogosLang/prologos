# Process Calculi and Session Types: A Theoretical Survey

**Date**: 2026-03-03
**Status**: Deep Research (Design Methodology Phase 1)
**Audience**: Implementors and researchers seeking theoretical grounding for The Process Language
**Scope**: Survey of process calculi, session type formalisms, and their theoretical relationships

---

## Table of Contents

- [1. Introduction](#1-introduction)
- [2. Classical Process Calculi](#2-classical-process-calculi)
  - [2.1 CCS: Calculus of Communicating Systems](#21-ccs)
  - [2.2 CSP: Communicating Sequential Processes](#22-csp)
  - [2.3 ACP: Algebra of Communicating Processes](#23-acp)
  - [2.4 Pi-Calculus: Mobile Processes](#24-pi-calculus)
  - [2.5 Join Calculus: Distributed Implementation](#25-join-calculus)
  - [2.6 Ambient Calculus: Spatial Mobility](#26-ambient-calculus)
- [3. Linear Logic and the Propositions-as-Sessions Paradigm](#3-linear-logic)
  - [3.1 Girard's Linear Logic](#31-girards-linear-logic)
  - [3.2 The Caires-Pfenning Correspondence](#32-caires-pfenning)
  - [3.3 Wadler's Classical Formulation](#33-wadlers-classical-formulation)
  - [3.4 The Correspondence Table](#34-correspondence-table)
- [4. Session Types: From Binary to Multiparty](#4-session-types)
  - [4.1 Honda's Original Session Types](#41-hondas-original)
  - [4.2 Full Binary Session Types](#42-binary-session-types)
  - [4.3 Subtyping for Session Types](#43-subtyping)
  - [4.4 Multiparty Session Types and Global Types](#44-multiparty)
  - [4.5 Scribble and Protocol Description Languages](#45-scribble)
- [5. Dependent and Refinement Session Types](#5-dependent-refinement)
  - [5.1 Dependent Session Types](#51-dependent-session-types)
  - [5.2 Refinement Session Types](#52-refinement-session-types)
  - [5.3 Value-Dependent Protocols](#53-value-dependent-protocols)
- [6. Quantitative and Graded Approaches](#6-quantitative-graded)
  - [6.1 Quantitative Type Theory and Resource Tracking](#61-qtt)
  - [6.2 Graded Modal Session Types](#62-graded-modal)
  - [6.3 Adjoint Session Types](#63-adjoint)
  - [6.4 Subexponentials and Graduated Linearity](#64-subexponentials)
- [7. Behavioral Types, Typestate, and Contracts](#7-behavioral-types)
  - [7.1 The Behavioral Types Landscape](#71-behavioral-types-landscape)
  - [7.2 Typestate](#72-typestate)
  - [7.3 Behavioral Contracts](#73-behavioral-contracts)
  - [7.4 Session Types vs Typestate: Two Perspectives](#74-sessions-vs-typestate)
- [8. Deadlock Freedom and Progress](#8-deadlock-freedom)
  - [8.1 The Deadlock Problem in Session-Typed Systems](#81-deadlock-problem)
  - [8.2 Manifest Deadlock-Freedom](#82-manifest-deadlock-freedom)
  - [8.3 Priority-Based Approaches](#83-priorities)
- [9. Practical Systems and Implementations](#9-practical-systems)
  - [9.1 Erlang/OTP: The Actor Model in Practice](#91-erlang-otp)
  - [9.2 Akka Typed: Typed Actors in Scala](#92-akka-typed)
  - [9.3 Rust Session Types](#93-rust-session-types)
  - [9.4 Links: Session-Typed Web Programming](#94-links)
  - [9.5 Effect Systems and Session Types](#95-effects)
  - [9.6 Other Notable Implementations](#96-other-implementations)
- [10. Recent Advances (2023-2026)](#10-recent-advances)
  - [10.1 Gradual Session Types](#101-gradual)
  - [10.2 Asynchronous Session Types](#102-asynchronous)
  - [10.3 Choreographic Programming](#103-choreographic)
  - [10.4 Label-Dependent Session Types](#104-label-dependent)
- [11. The Propagator Connection](#11-propagator-connection)
- [12. Comparative Summary](#12-comparative-summary)
- [13. References](#13-references)

---

<a id="1-introduction"></a>

## 1. Introduction

Concurrent and distributed programming is among the hardest problems in computer science.
Programs that communicate — whether threads sharing memory, processes exchanging messages,
or services interacting over networks — are notoriously difficult to reason about. Race
conditions, deadlocks, protocol violations, and resource leaks are endemic.

**Process calculi** are formal languages for describing and reasoning about concurrent
systems. They provide mathematical foundations for understanding what happens when
independent agents communicate. **Session types** extend this foundation by assigning
types to communication channels, ensuring that interacting parties follow agreed-upon
protocols.

This survey covers the theoretical landscape from its origins in the 1970s through
cutting-edge research in 2025. The goal is not exhaustive coverage but rather a clear
map of the key ideas, their relationships, and their strengths and limitations — providing
the theoretical grounding for any system seeking to unify dependent types, linear types,
logic programming, and typed concurrent communication.

### The Five Key Questions

Every formalism in this survey can be evaluated against five questions:

1. **What is the unit of concurrency?** (Process, actor, thread, coroutine)
2. **How do concurrent units communicate?** (Shared memory, message passing, channels)
3. **What properties does the type system guarantee?** (Protocol adherence, deadlock freedom, resource safety)
4. **How are resources tracked?** (Linear types, affine types, ownership, capabilities)
5. **How does the formalism compose?** (Sequential, parallel, choice, recursion)

---

<a id="2-classical-process-calculi"></a>

## 2. Classical Process Calculi

### 2.1 CCS: Calculus of Communicating Systems
<a id="21-ccs"></a>

**Robin Milner, 1980.** *A Calculus of Communicating Systems.* Springer LNCS 92.

CCS models concurrent systems as processes communicating via synchronous binary handshake
on named channels. A process performs actions: sending on channel `a` (written `a`) or
receiving on channel `a` (written `a-bar`). When one process sends and another receives
on the same channel, they synchronize, producing an internal (tau) action.

**Core syntax:**

```
P ::= 0            (inaction)
    | a.P           (action prefix: do a, then P)
    | P + Q         (nondeterministic choice)
    | P | Q         (parallel composition)
    | (nu a) P      (restriction: fresh channel a)
    | P[f]          (relabelling)
```

**Key innovation: Bisimulation equivalence.** CCS introduced bisimulation as the canonical
notion of process equivalence — a coinductive relation where two processes are bisimilar if
they can match each other's actions step-for-step, landing in bisimilar states. This is far
more discriminating than trace equivalence (which only compares observable action sequences)
and became the gold standard for process equivalence theory.

**Strengths:** Clean algebraic theory. Compositional operational semantics via labelled
transition systems (LTS). Equational laws (e.g., `P + Q = Q + P`, `P | Q = Q | P`).

**Limitations:** Channels are static — names cannot be created or passed as values. This
prevents modelling dynamic reconfiguration or mobile code. Communication is strictly
synchronous. No types, no resource tracking.

**Legacy:** CCS is the direct ancestor of the pi-calculus (adds name passing) and influenced
session types (which type CCS-style channels by protocol).

### 2.2 CSP: Communicating Sequential Processes
<a id="22-csp"></a>

**C.A.R. Hoare, 1978/1985.** *Communicating Sequential Processes.* Prentice Hall.

CSP takes a different approach from CCS: processes communicate by synchronizing on
**events** rather than complementary channel actions. A process is defined by the set of
events it can engage in, and communication happens when multiple processes agree on the
same event. The emphasis is on specification and verification rather than on computation.

**Core syntax:**

```
P ::= STOP          (deadlock)
    | SKIP           (successful termination)
    | a -> P         (prefix: engage in event a, then P)
    | P [] Q         (external choice)
    | P |~| Q        (internal choice)
    | P || Q         (parallel composition, synchronizing on common alphabet)
    | P ||| Q        (interleaving, no synchronization)
    | P \ X          (hiding events in set X)
    | P ; Q          (sequential composition)
```

**Key innovation: Denotational semantics via traces, failures, and divergences.** CSP
provides three increasingly discriminating semantic models:
- **Traces model:** A process is the set of its possible event sequences
- **Failures model:** Adds the concept of refusal sets (events a process can decline)
- **Failures-divergences model:** Adds divergence (infinite internal activity)

The **refinement relation** `P refines Q` means "P satisfies every property that Q does."
This enables specification-then-refinement: write an abstract spec, verify that the
implementation refines it.

**Strengths:** Powerful specification language. Industrial-strength model checking via FDR
(Failures-Divergences Refinement checker). Used in production for safety-critical systems
(e.g., Transputer, T9000 chip verification). Rich algebraic laws.

**Limitations:** Event-based (not channel-based) — no notion of directed communication.
No name passing (like CCS). No built-in types. Model checking doesn't scale to infinite
state spaces.

**Legacy:** CSP's refinement-based verification is the foundation of formal methods in
industry. The distinction between external choice (environment decides) and internal choice
(process decides) directly prefigures session type choice/offer. The `STOP`/`SKIP`
distinction foreshadows session type deadlock analysis.

### 2.3 ACP: Algebra of Communicating Processes
<a id="23-acp"></a>

**Bergstra & Klop, 1984.** *Process Algebra for Synchronous Communication.*

ACP takes a purely algebraic approach: processes are terms in an equational theory, and
process equivalence is equational provability. Where CCS uses operational semantics (LTS)
and CSP uses denotational semantics (traces/failures), ACP uses axiomatic semantics
(equational axioms).

**Key innovation: Axiomatization.** ACP provides complete axiom systems for various
process equivalences. The axioms can be oriented as rewrite rules, giving a normal form
for process terms. This makes ACP particularly suitable for tool-based reasoning.

**Strengths:** Clean algebraic foundation. Modular — different communication mechanisms
(synchronous, asynchronous, multi-party) can be axiomatized as separate theories.

**Limitations:** Less intuitive than CCS/CSP for modelling. The focus on axioms over
operational or denotational semantics makes it harder to connect to implementations.

**Legacy:** ACP's algebraic approach influenced the formal treatment of process algebras
as mathematical objects, and its modular axiomatization strategy appears in modern
frameworks for composing different concurrency models.

### 2.4 Pi-Calculus: Mobile Processes
<a id="24-pi-calculus"></a>

**Milner, Parrow, Walker, 1992.** *A Calculus of Mobile Processes.* Information and Computation.

The pi-calculus extends CCS with a single, profoundly consequential feature: **channel
names can be passed as values.** This enables modelling of dynamic process networks where
the topology of communication changes at runtime. A process can receive a channel name
and then use that name to communicate — the link was not known at compile time.

**Core syntax:**

```
P ::= 0                    (inaction)
    | x(y).P               (input: receive name y on channel x, then P)
    | x-bar<y>.P            (output: send name y on channel x, then P)
    | P | Q                 (parallel composition)
    | (nu x) P              (restriction: create fresh channel x)
    | !P                    (replication: unbounded copies of P)
```

**Key innovations:**

1. **Name passing (mobility):** `x(y).P` receives a name on channel `x` and binds it to
   `y` in continuation `P`. This models mobile references, delegation, and dynamic
   reconfiguration.

2. **Scope extrusion:** When a restricted name `(nu x)` is sent outside its original
   scope, the scope grows to encompass the receiver. This models private channel sharing
   — two processes that know a secret name can communicate privately even as their
   contexts change.

3. **Encoding of lambda calculus:** Milner showed that the lambda calculus can be
   faithfully encoded in the pi-calculus, establishing that name-passing concurrency is
   at least as expressive as sequential computation. (The converse does not hold —
   concurrency adds genuine expressiveness.)

**Strengths:** Extraordinary expressive power. Can model: object-oriented programming
(objects as processes, methods as channel receives), mobile code (send a process's
communication interface), security protocols (restricted names as secrets), and
distributed algorithms. The minimal syntax belies remarkable depth.

**Limitations:** Too expressive — the unrestricted pi-calculus is Turing-complete, so
most interesting properties are undecidable. Type systems for the pi-calculus (including
session types) are largely about taming this expressiveness. Replication (`!P`) makes
reasoning about resource usage difficult.

**Variants:**
- **Asynchronous pi-calculus** (Honda & Tokoro, 1991; Boudol, 1992): Output is
  non-blocking (`x-bar<y>` with no continuation). More realistic for distributed systems.
  Surprisingly, synchronous communication can be encoded.
- **Polyadic pi-calculus:** Send/receive tuples of names. Encodable in the monadic
  version but more convenient.
- **Applied pi-calculus** (Abadi & Fournet): Extends with data values and equational
  theories. Used in ProVerif for security protocol verification.

**Legacy:** The pi-calculus is the foundation on which session types are built. Every
session type system is, at its core, a type discipline for the pi-calculus that restricts
channel usage to follow protocols. The pi-calculus's name-passing is what makes session
delegation (passing a channel endpoint to another process) possible.

### 2.5 Join Calculus: Distributed Implementation
<a id="25-join-calculus"></a>

**Fournet & Gonthier, 1996.** *The Reflexive Chemical Abstract Machine and the Join-Calculus.*

The join calculus was designed for distributed implementation from the start. Its key
innovation is the **join pattern**: a process definition that waits for messages on
multiple channels simultaneously before firing. This models synchronization barriers
naturally.

**Core syntax:**

```
P ::= x<y>             (send message y on channel x)
    | def x(y) & z(w) |> P in Q  (join definition: when x and z both ready, fire P)
```

**Key innovation: Join patterns and locality.** A join definition `def x(y) & z(w) |> P`
defines channels `x` and `z` together, and `P` fires only when both have received messages.
This models multi-party synchronization without explicit locks. Crucially, join definitions
are **local**: the channels `x` and `z` are defined at the same location, enabling
distributed implementation where message routing is determined at definition time.

**Strengths:** Direct implementation path to distributed systems (JoCaml, Distributed
Join). Join patterns naturally model: monitors, semaphores, readers-writers locks, and
other synchronization primitives. No need for separate lock/condition variable mechanisms.

**Limitations:** Less expressive than the full pi-calculus (no input guards — can't
do `x(y).P + z(w).Q`). The locality constraint, while good for distribution, prevents
some dynamic patterns.

**Legacy:** Join patterns influenced language design in JoCaml, C-omega (Polyphonic C#),
and Rust's `select!` macro. The chemical abstract machine model (molecules = messages,
reaction rules = join patterns) provides an appealing metaphor for concurrent computation.

### 2.6 Ambient Calculus: Spatial Mobility
<a id="26-ambient-calculus"></a>

**Cardelli & Gordon, 1998.** *Mobile Ambients.* FoSSaCS.

The ambient calculus models not just communication but **spatial mobility**: computational
boundaries that can move inside and outside of each other. An ambient is a named boundary
containing processes and sub-ambients. Ambients can: enter other ambients (`in`), exit
their parent (`out`), and dissolve their boundary (`open`).

**Key innovation: Spatial types and boundary crossing.** Where the pi-calculus models
mobility of names (references), the ambient calculus models mobility of entire
computational environments. This captures: mobile agents, firewalls, virtual machines,
and sandboxes.

**Strengths:** Natural model for security boundaries, mobile code, and administrative
domains. Type systems for ambients (e.g., immobility types, group-based types) can
express security policies as types.

**Limitations:** The interaction primitives (`in`, `out`, `open`) are quite low-level
and can be difficult to reason about. Decidability results are mixed. Has seen less
practical adoption than the pi-calculus.

**Legacy:** The ambient calculus's focus on boundaries and spatial structure influenced
capability-based security models and containerization concepts. The idea that security
boundaries are first-class computational entities resonates with modern capability
type systems.

---

<a id="3-linear-logic"></a>

## 3. Linear Logic and the Propositions-as-Sessions Paradigm

### 3.1 Girard's Linear Logic
<a id="31-girards-linear-logic"></a>

**Jean-Yves Girard, 1987.** *Linear Logic.* Theoretical Computer Science 50.

Linear logic revolutionized the relationship between logic and computation by introducing
**resource sensitivity**: hypotheses are consumed when used. In classical logic, a
hypothesis `A` can be used zero, one, or many times; in linear logic, each hypothesis
must be used **exactly once** (unless explicitly marked as reusable).

**Connectives (multiplicative/additive split):**

| Classical | Linear (Multiplicative) | Linear (Additive) |
|-----------|------------------------|-------------------|
| A and B | A tensor B (A * B) — both, simultaneously | A with B (A & B) — both, client chooses |
| A or B | A par B (A `⅋` B) — both, provider chooses | A plus B (A + B) — one, provider chooses |
| A implies B | A lolli B (A -o B) — consume A, produce B | |
| not A | A-perp (A^⊥) — dual of A | |

**Exponentials:**
- `!A` (of course A) — A can be used any number of times (including zero)
- `?A` (why not A) — dual of `!A`

**Key insight: the resource interpretation.** Linear logic's connectives have natural
resource interpretations:
- `A * B`: I have both A and B (tensor product, simultaneous availability)
- `A & B`: I can provide either A or B (additive conjunction, client's choice)
- `A + B`: I will provide one of A or B (additive disjunction, provider's choice)
- `A -o B`: Give me an A and I'll give you a B (linear implication, trade)
- `!A`: I have an unlimited supply of A (reusable resource)

**Strengths:** Elegant decomposition of classical connectives into orthogonal dimensions
(multiplicative/additive, positive/negative). Natural model for resources, state, and
interaction. Proof nets provide a canonical representation of proofs.

**Limitations:** The full logic is complex (many connectives). Practical programming
with linear logic requires careful management of the `!`/`?` modalities.

### 3.2 The Caires-Pfenning Correspondence
<a id="32-caires-pfenning"></a>

**Caires & Pfenning, 2010.** *Session Types as Intuitionistic Linear Propositions.*
CONCUR.

This landmark paper established a **Curry-Howard correspondence between intuitionistic
linear logic and session types**. Just as the Curry-Howard isomorphism relates classical
logic to the lambda calculus (propositions = types, proofs = programs), the Caires-Pfenning
correspondence relates linear logic to the pi-calculus with session types:

| Intuitionistic Linear Logic | Session Types / Pi-Calculus |
|----------------------------|---------------------------|
| Proposition A | Session type S |
| Proof of A | Process implementing protocol S |
| Cut rule | Parallel composition (process creates channel pair) |
| Cut elimination | Communication (message exchange) |
| Identity axiom | Channel forwarding |
| A * B (tensor) | Send A, then continue as B |
| A -o B (lolli) | Receive A, then continue as B |
| A & B (with) | External choice (offer both branches) |
| A + B (plus) | Internal choice (select one branch) |
| !A (of course) | Shared/replicated service |
| 1 (unit) | Session termination (End) |

**Key insight: linearity = protocol compliance.** The fact that linear hypotheses must
be used exactly once corresponds to the requirement that each channel endpoint must
follow its protocol exactly — no message dropped, no message duplicated, no step skipped.
This is not an analogy; it is a mathematical isomorphism.

**Cut elimination = communication.** The cut rule in logic corresponds to process
composition: two processes connected by a channel. Cut elimination (simplifying the proof)
corresponds to the processes communicating — each step of cut elimination is a
communication step. This gives session type communication a proof-theoretic semantics.

**Consequences:**
- Type safety = soundness (well-typed processes don't get stuck)
- Deadlock freedom comes from the acyclicity of cut-free proofs
- Session types compose because linear logic proofs compose (cut)

### 3.3 Wadler's Classical Formulation
<a id="33-wadlers-classical-formulation"></a>

**Philip Wadler, 2012.** *Propositions as Sessions.* ICFP.

Wadler gave an alternative formulation using **classical** (rather than intuitionistic)
linear logic. The key difference: classical linear logic has explicit duality (negation),
so every session type S has a dual S^⊥, and the correspondence is more symmetric.

**Key innovation:** Wadler's `CP` (Classical Processes) language uses the two-sided
sequent calculus. A judgment `x1:A1, ..., xn:An |- P` means "process P implements
sessions A1 through An on channels x1 through xn simultaneously." This naturally
supports **multi-channel processes** — a single process can participate in multiple
sessions.

**Comparison:**
- Caires-Pfenning (intuitionistic): process provides one channel, consumes others
- Wadler (classical): process provides and consumes multiple channels symmetrically

**Strengths:** The classical formulation makes duality explicit and symmetric. It connects
more directly to the game-theoretic interpretation of linear logic.

### 3.4 The Correspondence Table
<a id="34-correspondence-table"></a>

The full Curry-Howard correspondence for sessions:

| Linear Logic | Session Type | Process Operation | Resource Interpretation |
|-------------|-------------|-------------------|------------------------|
| A * B | !A.S (Send A, continue S) | `send v on c; P` | Produce A, then behave as S |
| A -o B | ?A.S (Recv A, continue S) | `recv x from c; P` | Consume A, then behave as S |
| A & B | &{l1:S1, l2:S2} (Offer) | `case c of {l1 => P1, l2 => P2}` | Client chooses which branch |
| A + B | +{l1:S1, l2:S2} (Choice) | `select l on c; P` | Provider chooses which branch |
| !A | !S (Shared service) | `accept c; P` | Unlimited reuse |
| 1 | End | `close c` | Session complete |
| A^⊥ | dual(A) | Other endpoint | What the other side sees |

This correspondence is the theoretical foundation for session type systems. It provides
both the typing rules (from linear logic's proof rules) and the safety guarantees (from
linear logic's metatheory: cut elimination, identity expansion).

---

<a id="4-session-types"></a>

## 4. Session Types: From Binary to Multiparty

### 4.1 Honda's Original Session Types
<a id="41-hondas-original"></a>

**Kohei Honda, 1993.** *Types for Dyadic Interaction.* CONCUR.

Honda introduced the first session type system, typing communication channels in the
pi-calculus by the sequence of operations performed on them. The core idea: a channel
has a type that prescribes: what will be sent, what will be received, and in what order.

**Original syntax:**

```
S ::= !T.S    (output type T, then continue with S)
    | ?T.S    (input type T, then continue with S)
    | S1 + S2  (internal choice)
    | S1 & S2  (external choice)
    | mu X.S   (recursive session)
    | X        (session variable)
    | end      (termination)
```

**Key innovation: Duality.** Every session type S has a dual S-bar, representing what the
other endpoint of the channel sees. Duality is an involution: dual(dual(S)) = S.

```
dual(!T.S)   = ?T.dual(S)
dual(?T.S)   = !T.dual(S)
dual(S1 + S2) = S1 & S2  (and vice versa)
dual(end)     = end
```

When two processes communicate on a channel, one sees session type S and the other sees
dual(S). Type safety ensures they agree on the protocol.

### 4.2 Full Binary Session Types
<a id="42-binary-session-types"></a>

**Honda, Vasconcelos, Kubo, 1998.** *Language Primitives and Type Discipline for
Structured Communication-Based Programming.* ESOP.

This paper developed Honda's idea into a full programming language with session types.
Key additions:

1. **Session initiation:** The `accept`/`request` primitives create new sessions.
   `accept a(x) in P` waits on service name `a` for a connection, binding the channel
   to `x`. `request a(x) in P` connects to service `a`.

2. **Labeled choice:** Instead of binary choice, labeled branching:
   `c |> {l1: P1, l2: P2, ..., ln: Pn}` — the other endpoint selects a label.

3. **Session delegation:** A process can send a channel endpoint as a value, delegating
   its role in a session to another process. This is the session-type version of the
   pi-calculus's name passing.

4. **Type discipline:** A complete type system ensuring: protocol fidelity (messages match
   expected types), communication safety (no stuck processes), and linearity (each channel
   endpoint used exactly once per session step).

### 4.3 Subtyping for Session Types
<a id="43-subtyping"></a>

**Gay & Hole, 2005.** *Subtyping for Session Types in the Pi Calculus.* Acta Informatica.

Subtyping for session types follows the familiar variance pattern:

- **Output is covariant:** If `T1 <: T2`, then `!T1.S <: !T2.S`
  (safe to send a more specific type)
- **Input is contravariant:** If `T2 <: T1`, then `?T1.S <: ?T2.S`
  (safe to accept a more general type)
- **Choice is covariant (in labels):** Offering MORE branches is a subtype
  (safe to handle more cases than required)
- **Selection is contravariant (in labels):** Selecting from FEWER branches is a subtype
  (safe to need fewer options)

This is directly analogous to function subtyping (`T1 -> T2 <: S1 -> S2` when `S1 <: T1`
and `T2 <: S2`) — inputs are contravariant, outputs are covariant.

**Significance:** Subtyping enables protocol evolution. A server that offers more services
(more branches) can safely replace one that offers fewer. A client that requires fewer
services (fewer selections) can safely replace one that requires more. This is the
session-type version of Liskov substitution.

### 4.4 Multiparty Session Types and Global Types
<a id="44-multiparty"></a>

**Honda, Yoshida, Carbone, 2008/2016.** *Multiparty Asynchronous Session Types.* JACM.

Binary session types describe two-party protocols. Real systems involve multiple
participants. Multiparty session types (MPST) solve this by introducing **global types**
— a bird's-eye view of the entire protocol from which individual participants'
**local types** are derived via **projection**.

**The MPST methodology:**

```
1. Write global type G (choreography of all participants)
2. Project G to local types: G ↓ p for each participant p
3. Each participant p implements process P_p against local type G ↓ p
4. If each P_p conforms to G ↓ p, the composition is safe
```

**Global type syntax:**

```
G ::= p -> q : {l_i : G_i}     (p sends to q, choice of labels)
    | mu X. G                    (recursion)
    | X                          (variable)
    | end                        (termination)
```

**Projection:** `(p -> q : {l_i : G_i}) ↓ r` =
- If `r = p`: `+{l_i : G_i ↓ r}` (internal choice — p selects)
- If `r = q`: `&{l_i : G_i ↓ r}` (external choice — q offers)
- If `r != p, q`: merge `G_i ↓ r` (r's view must be consistent across branches)

**The merge condition** is the key challenge: when a participant `r` is not involved in
a choice between `p` and `q`, `r`'s local type must be the same regardless of which branch
was chosen (since `r` doesn't know which branch was taken). This limits the expressiveness
of MPST — some natural protocols are not directly expressible because they violate the
merge condition.

**Strengths:** Compositional verification. Once the global type is written and projection
succeeds, each participant can be type-checked independently. The global type serves as
documentation and specification.

**Limitations:** Not all protocols have global types. The merge condition restricts
expressiveness. Global types assume a fixed set of participants — dynamic joining/leaving
requires extensions. Projection is not always defined (non-projectable global types exist).

### 4.5 Scribble and Protocol Description Languages
<a id="45-scribble"></a>

**Scribble** (Yoshida et al.) is a protocol description language based on multiparty
session types. It provides a practical surface syntax for global types and tools for
projection, verification, and code generation.

**Example Scribble protocol:**

```
global protocol TwoBuyer(role Buyer1, role Buyer2, role Seller) {
  title(String) from Buyer1 to Seller;
  quote(Int) from Seller to Buyer1;
  quote(Int) from Seller to Buyer2;
  share(Int) from Buyer1 to Buyer2;
  choice at Buyer2 {
    accept() from Buyer2 to Seller;
    address(String) from Buyer2 to Seller;
    date(Date) from Seller to Buyer2;
  } or {
    reject() from Buyer2 to Seller;
  }
}
```

Scribble has been used in practice for specifying web service protocols, financial
trading protocols, and distributed algorithm protocols. It demonstrates that session
types can scale from theoretical curiosity to practical tool.

---

<a id="5-dependent-refinement"></a>

## 5. Dependent and Refinement Session Types

### 5.1 Dependent Session Types
<a id="51-dependent-session-types"></a>

**Toninho, Caires, Pfenning, 2011.** *Dependent Session Types via Intuitionistic Linear
Type Theory.* PPDP.

Standard session types prescribe the *structure* of communication (send, receive, choose)
but not the *content* (what specific values are sent). Dependent session types allow the
continuation of a session to depend on the value exchanged:

```
S ::= ... | (x : A) -> S    (dependent receive: bind x in continuation)
          | (x : A) * S     (dependent send: bind x in continuation)
```

**Example: length-indexed vector transmission.**

```
;; Send a natural number n, then send exactly n integers
VecSend(n : Nat) = !Nat. !^n Int. End

;; The type of the remaining session depends on what n was sent
DepVecSend = ?(n : Nat). !^n Int. End
```

This makes the session type *value-dependent*: the protocol's shape changes based on
runtime data. The type checker must reason about both types and values simultaneously.

**Connection to dependent types:** The Caires-Pfenning correspondence extends naturally
to dependent linear logic. Dependent functions in the functional world (`Pi x:A. B(x)`)
correspond to dependent sessions in the concurrent world (`(x : A) -> S(x)`). This is
the session-type version of the Curry-Howard correspondence for dependent types.

### 5.2 Refinement Session Types
<a id="52-refinement-session-types"></a>

**Toninho & Yoshida, 2025.** *Practical Refinement Session Type Inference.*

Refinement session types extend session types with arithmetic constraints. Instead of
just "send an Int", one can write "send an Int greater than 0" or "send exactly n messages":

```
S ::= ... | {x : Int | phi(x)} -> S    (refined receive: x satisfies predicate phi)
```

**Inference via SMT:** The paper shows that refinement session types can be inferred
(not just checked) by generating constraints solved by Z3. Key optimizations include
transitivity elimination and polynomial templates for arithmetic search.

**Significance:** Refinement types bring session types closer to full specification
languages. The gap between "send an Int" and "send a valid customer ID" can now be
bridged by the type system, without resorting to runtime validation.

### 5.3 Value-Dependent Protocols
<a id="53-value-dependent-protocols"></a>

Value-dependent protocols are the richest form of session types: the entire protocol
structure — not just the types of messages, but which branches exist — can depend on
previously exchanged values.

**Example: authentication-dependent protocol.**

```
AuthSession = ?(cred : Credentials).
  case verify(cred) of
    Valid   -> !AuthToken. AdminSession
    Invalid -> !ErrorMsg. End
```

The continuation (AdminSession vs End) depends on whether `verify(cred)` produces
`Valid` or `Invalid`. This requires dependent pattern matching within session types.

**Challenge:** Type checking value-dependent protocols may require evaluating functions
(like `verify`) at type-checking time, blurring the phase distinction between compilation
and execution. This connects to the broader challenges of dependent type theory.

---

<a id="6-quantitative-graded"></a>

## 6. Quantitative and Graded Approaches

### 6.1 Quantitative Type Theory and Resource Tracking
<a id="61-qtt"></a>

**Atkey, 2018.** *Syntax and Semantics of Quantitative Type Theory.* LICS.
**McBride, 2016.** *I Got Plenty o' Nuttin'.* (A Type Theory with Usage.)

QTT annotates each variable binding with a **multiplicity** from a resource semiring:
- `0`: erased (compile-time only, no runtime cost)
- `1`: linear (used exactly once)
- `omega`: unrestricted (used any number of times)

**Connection to session types:** QTT's multiplicities directly correspond to session
type linearity:
- `:0` (erased) = session type as specification (protocol type, not a runtime channel)
- `:1` (linear) = linear channel endpoint (used exactly according to protocol)
- `:w` (unrestricted) = shared channel (corresponds to `!A` in linear logic)

QTT provides a **unified framework** where linear types and unrestricted types coexist
in a single type theory, rather than requiring separate type systems. This is crucial
for a language that wants both pure functions (unrestricted) and session-typed channels
(linear).

### 6.2 Graded Modal Session Types
<a id="62-graded-modal"></a>

**Das & Pfenning, 2020.** *Graded Modal Session Types.*

Graded modal types extend QTT's multiplicities with richer annotations from arbitrary
semirings. Different resource dimensions (time, space, security level, precision) can
be tracked simultaneously.

**Key idea:** Instead of a single multiplicity, each variable carries a **vector of
grades** from different semirings. This enables tracking:
- Multiplicity (0, 1, omega) — how often is the channel used?
- Security level (public, confidential, secret) — what information flows through?
- Time budget (natural numbers) — how many protocol steps remain?
- Cost (rational numbers) — what is the communication cost?

**Significance for session types:** Graded sessions can express not just "follow this
protocol" but "follow this protocol within 5 steps, at security level confidential,
using at most 3 message exchanges."

### 6.3 Adjoint Session Types
<a id="63-adjoint"></a>

**Pruiksma & Pfenning, 2019.** *A Message-Passing Interpretation of Adjoint Logic.*

Adjoint session types use **adjoint modalities** to relate different modes of session
type usage. An adjunction `F -| U` between modes `m` and `n` means:
- `F_mn` shifts from mode `m` to mode `n` (e.g., from linear to shared)
- `U_nm` shifts from mode `n` to mode `m` (e.g., from shared to linear)

This provides a principled way to move between different resource regimes within a
single session. A linear channel can be "promoted" to a shared channel (if appropriate)
or a shared reference can be "consumed" linearly.

### 6.4 Subexponentials and Graduated Linearity
<a id="64-subexponentials"></a>

Subexponential linear logic replaces the single `!`/`?` modalities with a family of
modalities indexed by a preorder. Each level in the preorder represents a different
degree of reusability. This provides a **spectrum** between linear and unrestricted,
rather than a binary distinction.

**Relevance:** QTT's `{0, 1, omega}` is a specific three-point subexponential system.
Richer systems might track "used at most 3 times" or "used at most once per session
round."

---

<a id="7-behavioral-types"></a>

## 7. Behavioral Types, Typestate, and Contracts

### 7.1 The Behavioral Types Landscape
<a id="71-behavioral-types-landscape"></a>

**Huttel et al., 2016.** *Foundations of Behavioural Types.* ACM Computing Surveys.

"Behavioral type" is an umbrella term for type systems that describe the **dynamic
behavior** of programs, not just their static data properties. The survey identifies
three major families:

1. **Session types**: Type channels by communication protocol
2. **Typestate**: Type objects by the operations allowed in each state
3. **Behavioral contracts**: Runtime-monitored behavioral specifications

These are complementary perspectives on the same fundamental problem: ensuring that
interacting entities follow agreed-upon protocols.

### 7.2 Typestate
<a id="72-typestate"></a>

**Strom & Yemini, 1986.** *Typestate: A Programming Language Concept for Enhancing
Software Reliability.*
**Aldrich et al., 2009.** *Typestate-Oriented Programming.*

Typestate tracks the **state** of an object through its lifecycle. An object's type
changes as operations are performed on it:

```
FileHandle :: Closed --open()--> Open --read()--> Open --close()--> Closed
```

The type system prevents calling `read()` on a `Closed` file or `open()` on an already
`Open` file. Each method has a pre-state and post-state.

**Relation to session types:** Typestate and session types are two perspectives on the
same idea:
- **Session types** are **external**: they describe what the *environment* sees (the
  protocol of a channel endpoint)
- **Typestate** is **internal**: it describes what *operations* are valid on an object
  in its current state

For binary sessions, the correspondence is exact: each state in a typestate automaton
corresponds to a position in a session type, and each transition corresponds to a
send/receive operation. They are duals of the same concept.

### 7.3 Behavioral Contracts
<a id="73-behavioral-contracts"></a>

**Castagna, Gesbert, Padovani.** *A Theory of Contracts for Web Services.*

Behavioral contracts are runtime-monitored specifications: a contract describes what a
service promises to do, and a monitor checks at runtime that the service keeps its
promises. Unlike session types (which are checked statically), contracts allow
**blame assignment**: when a contract is violated, the monitor identifies which party
is at fault.

**Relevance:** Contracts bridge the gap between static and dynamic checking. A system
might use session types for the critical core and contracts for the boundary with
untyped external services. The "gradual session types" research (Section 10.1) formalizes
this bridge.

### 7.4 Session Types vs Typestate: Two Perspectives
<a id="74-sessions-vs-typestate"></a>

| Dimension | Session Types | Typestate |
|-----------|--------------|-----------|
| Perspective | External (protocol) | Internal (valid operations) |
| Subject | Channel endpoint | Object/resource |
| Verification | Static (type system) | Static or dynamic |
| Composition | Parallel (cut rule) | Sequential (state machine) |
| Duality | Built-in (dual(S)) | Implicit (client vs server) |
| Multi-party | Global types (MPST) | No standard theory |
| Foundation | Linear logic | Finite automata |

A mature system would support both perspectives: session types for inter-process
protocols, typestate for intra-process resource management. The linear type system
(QTT with `:1`) provides the common foundation.

---

<a id="8-deadlock-freedom"></a>

## 8. Deadlock Freedom and Progress

### 8.1 The Deadlock Problem in Session-Typed Systems
<a id="81-deadlock-problem"></a>

Classical binary session types guarantee deadlock freedom for **single-session
interactions**: two processes connected by one channel will never deadlock. But when
processes participate in **multiple sessions**, cyclic dependencies between channels
can cause deadlock:

```
Process P: recv on c1; send on c2
Process Q: recv on c2; send on c1
```

Both wait for the other to send first. Each individual session is well-typed, but the
composition deadlocks. This is the **multi-session deadlock problem**.

### 8.2 Manifest Deadlock-Freedom
<a id="82-manifest-deadlock-freedom"></a>

**Balzer & Pfenning, 2017.** *Manifest Deadlock-Freedom for Shared Session Types.*

Manifest deadlock-freedom extends session types with **explicit acquire/release** for
shared resources:

```
P ::= ... | acquire x; P    (acquire exclusive access to shared channel x)
          | release x; P    (release exclusive access)
```

The type system tracks which channels are acquired and ensures acyclicity: the
acquire/release pattern must follow a total order on channels. This is essentially
the "acquire locks in a fixed order" discipline, but enforced by the type system.

### 8.3 Priority-Based Approaches
<a id="83-priorities"></a>

**Padovani, 2014.** *Deadlock and Lock Freedom in the Linear Pi Calculus.*
**Kobayashi, 2006.** *A New Type System for Deadlock-Free Processes.*

Priority-based approaches assign each channel a **priority level** (a natural number).
The type system ensures that actions on higher-priority channels always happen before
actions on lower-priority channels. Deadlock requires a cycle; priorities prevent cycles.

**Kobayashi's type system** goes further: it assigns each channel both a **reliability**
(will a message eventually arrive?) and an **obligation** (will a process eventually
send?). Deadlock freedom follows from: every obligation has a matching reliability,
and the dependency graph is acyclic.

---

<a id="9-practical-systems"></a>

## 9. Practical Systems and Implementations

### 9.1 Erlang/OTP: The Actor Model in Practice
<a id="91-erlang-otp"></a>

Erlang (Armstrong et al., 1993) implements the **actor model** for telecommunications
infrastructure. Each Erlang process is a lightweight actor with its own heap, communicating
via asynchronous message passing.

**OTP (Open Telecom Platform)** provides supervision trees: processes organized
hierarchically, where parent processes monitor children and restart them on failure
("let it crash" philosophy).

**What Erlang gets right:**
- Process isolation (no shared state, no data races)
- Fault tolerance via supervision
- Hot code upgrades (replace code in a running system)
- Pattern matching on received messages
- Massive scalability (millions of lightweight processes)

**What Erlang lacks:**
- **No protocol types**: Messages are untyped. Any process can send any message to any
  other process. Protocol violations are detected at runtime (by pattern match failure
  or process crash), not at compile time.
- **No linearity**: Resources can be freely duplicated or dropped. Capability delegation
  requires trust (no static enforcement).
- **No deadlock prevention**: Deadlocks are handled by timeouts, not by the type system.

Session types address all three gaps: typed protocols, linear channels, and
(for restricted patterns) deadlock freedom.

### 9.2 Akka Typed: Typed Actors in Scala
<a id="92-akka-typed"></a>

**Akka Typed** (part of the Akka toolkit for Scala) adds type safety to the actor model.
Each actor has a type parameter describing the messages it can receive:

```scala
trait ActorRef[-T]  // contravariant: can receive T or supertypes

object MyActor {
  sealed trait Command
  case class Greet(name: String, replyTo: ActorRef[Greeting]) extends Command
  case class Greeting(message: String)
}
```

**Comparison with session types:** Akka Typed types the *messages* an actor receives but
not the *protocol* (order of messages). An `ActorRef[Command]` can receive any `Command`
at any time, regardless of protocol state. Session types would additionally enforce
"first receive `Greet`, then send `Greeting`, then terminate."

### 9.3 Rust Session Types
<a id="93-rust-session-types"></a>

**Ferrite** (Chen, 2021) and the **session-types** crate encode session types in Rust
using ownership and the type system. Rust's affine types (values used at most once unless
`Copy`) provide a natural foundation for linearity.

**Key technique:** Session types are encoded as Rust types using continuation-passing:

```rust
type Server = Recv<String, Send<i32, End>>;
type Client = <Server as HasDual>::Dual;  // Send<String, Recv<i32, End>>
```

Each `send`/`recv` operation consumes the old channel endpoint and returns a new one with
the updated session type. Rust's ownership system ensures the old endpoint can't be used
after the operation.

**Strengths:** Works in a practical systems language without language extensions. Ownership
provides linearity for free. Compile-time checking with zero runtime overhead.

**Limitations:** Extremely verbose (each protocol step changes the channel's type, leading
to complex generic signatures). No IDE support for session type reasoning. Encoding tricks
(phantom types, recursive types) can hit Rust's type inference limits.

### 9.4 Links: Session-Typed Web Programming
<a id="94-links"></a>

**Links** (Cooper et al., Edinburgh) is a programming language for web applications with
built-in session types. It compiles to JavaScript (client) and runs on a server, with
session-typed communication between client and server.

**Significance:** Links demonstrates that session types can be practical for everyday
web programming, not just concurrent systems research. The session type describes the
HTTP request/response protocol between browser and server.

### 9.5 Effect Systems and Session Types
<a id="95-effects"></a>

Algebraic effects and handlers provide an alternative approach to managing communication.
Instead of linear types, effects use a **handler** that interprets communication operations:

```
effect Channel {
  send : A -> Unit
  recv : Unit -> A
}

handler session_handler = {
  send(v) -> ... (actually send v)
  recv()  -> ... (actually receive)
}
```

**Comparison:** Effect systems don't enforce linearity — a handler can choose to ignore a
`send` or replay a `recv`. This makes them more flexible but less safe than session types.
The combination of effects and linearity (as in Koka or Frank) is an active research area.

### 9.6 Other Notable Implementations
<a id="96-other-implementations"></a>

- **Discourje** (van den Bos &"; Java): Multiparty session types for Java via runtime
  monitoring. A Clojure DSL generates monitors from Scribble protocols.
- **Sill** (Pfenning et al.): Research language implementing the full Caires-Pfenning
  theory. The most faithful implementation of linear-logic-based sessions.
- **Session Java** (Hu et al.): Java extension with session types for distributed
  programming.
- **FuSe** (Padovani): OCaml library encoding session types using OCaml's type system.
  Achieves linearity via runtime checking (not static).

---

<a id="10-recent-advances"></a>

## 10. Recent Advances (2023-2026)

### 10.1 Gradual Session Types
<a id="101-gradual"></a>

**Igarashi et al.; Jongmans & Yoshida.** Gradual session types bridge statically-typed
and dynamically-typed session endpoints. A type `?` (dynamic/unknown session type) can
interact with any session type, with runtime monitors checking protocol compliance.

**Significance:** Enables incremental adoption of session types in existing codebases.
The typed and untyped worlds interoperate safely (runtime errors at the boundary, not
type errors).

### 10.2 Asynchronous Session Types
<a id="102-asynchronous"></a>

Classical session types assume synchronous communication (send and receive happen
simultaneously). Asynchronous session types model buffered channels where send is
non-blocking and messages queue until received.

**Key results:**
- Asynchronous subtyping is undecidable in general (Bravetti et al., 2019; Lange & Yoshida, 2019)
- Decidable fragments exist for practical protocols
- The relationship between synchronous and asynchronous session types involves
  careful treatment of the output buffer

**Significance:** Real network communication is asynchronous. Synchronous session types
can be too restrictive for distributed systems.

### 10.3 Choreographic Programming
<a id="103-choreographic"></a>

**Montesi, 2023.** *Introduction to Choreographies.* Cambridge University Press.
**Hirsch & Garg, 2022.** *Pirouette: Higher-Order Typed Functional Choreographies.*

Choreographic programming is "correct by construction": instead of writing individual
processes and verifying they match a global type, you write the **choreography** directly
and compile it (via endpoint projection) into individual processes.

```
;; Choreography: buyer sends title to seller, seller responds with price
Buyer.title ~> Seller;
Seller.price ~> Buyer;
if Buyer.decide(price) then
  Buyer.accept ~> Seller;
  Seller.date ~> Buyer
else
  Buyer.reject ~> Seller
```

**Significance:** Choreographic programming eliminates the projection step (global type
-> local types) by making the choreography the primary artifact. Deadlock freedom is
guaranteed by construction. Recent work (Pirouette) adds higher-order functions to
choreographies.

### 10.4 Label-Dependent Session Types
<a id="104-label-dependent"></a>

**Thiemann, 2019.** *Label-Dependent Session Types.*

Label-dependent session types allow the session type to depend on the label chosen in
a branching operation. This is a form of dependence intermediate between simple session
types and full dependent session types:

```
S = &{l : S_l}   where S_l depends on l
```

The label itself (not just its position) determines the continuation. This enables
expressing protocols where the response format depends on the request type — a common
pattern in RPC-style protocols.

---

<a id="11-propagator-connection"></a>

## 11. The Propagator Connection

How does lattice-based constraint propagation relate to session type checking?

### 11.1 Concurrent Constraint Programming (Saraswat, 1993)

CCP models concurrent computation as agents constraining shared variables via `tell`
(add constraint) and `ask` (check if constraint is entailed). The constraint store is a
lattice; `tell` is monotonic join. This is structurally identical to a propagator network
with lattice-valued cells.

**Connection to sessions:** The `tell`/`ask` primitives of CCP correspond to `send`/`recv`
in session types: `tell` adds information (like sending a message), and `ask` blocks until
sufficient information is available (like receiving). The key difference: CCP's constraint
store is shared (all agents see all constraints), while session types enforce point-to-point
communication. Galois connections between per-channel constraint stores could bridge this
gap.

### 11.2 Session Types as Lattice Constraints

Session types form a lattice under the subtyping relation (Gay & Hole):
- Top: any session type (accepts all protocols)
- Bottom: no session type (deadlocked protocol)
- Join: most general common subtype
- Meet: most specific common supertype

Session type **inference** can be formulated as constraint propagation over this lattice:
each channel endpoint is a cell, each protocol operation adds constraints (propagators),
and the fixpoint computation infers the session type.

### 11.3 ATMS and Protocol Verification

An ATMS (Assumption-Based Truth Maintenance System) tracking protocol states can provide:
- **Derivation chains:** "Why does channel c have session type S?" — because of send
  at line 5 (A1), receive at line 8 (A2), and selection at line 12 (A3).
- **Nogoods:** "Channel c cannot be both Send Int and Recv String" — contradiction
  from assumptions A1 and A7.
- **Worldview branching:** Explore different protocol evolutions (different branches
  of an offer/choice) simultaneously.

This connects session type checking to model-based diagnosis (de Kleer & Williams):
a protocol violation is a "fault" diagnosed by finding the minimal set of inconsistent
assumptions.

---

<a id="12-comparative-summary"></a>

## 12. Comparative Summary

### 12.1 Process Calculi Comparison

| Calculus | Year | Channels | Name Passing | Types | Equivalence | Key Strength |
|----------|------|----------|-------------|-------|-------------|-------------|
| CCS | 1980 | Static | No | None | Bisimulation | Clean algebra |
| CSP | 1978 | Events | No | None | Traces/Failures | Refinement verification |
| ACP | 1984 | Algebraic | No | None | Equational | Complete axiomatization |
| Pi-calc | 1992 | Dynamic | Yes | Various | Bisimulation | Mobility, expressiveness |
| Join | 1996 | Defined | Yes | None | (Chemical) | Distributed implementation |
| Ambient | 1998 | Boundaries | Implicit | Spatial | (Various) | Security boundaries |

### 12.2 Session Type System Comparison

| System | Parties | Dependence | Resources | Deadlock-Free | Inference | Practical |
|--------|---------|-----------|-----------|---------------|-----------|-----------|
| Honda 1993 | Binary | No | No | Single-session | No | Foundation |
| HVK 1998 | Binary | No | No | Single-session | No | Language |
| Gay & Hole | Binary | No | Subtyping | Single-session | No | Theory |
| Caires-Pfenning | Binary | No | Linear (ILL) | Yes (cut-free) | Partial | Research (Sill) |
| Wadler CP | Binary | No | Linear (CLL) | Yes | Partial | Research |
| MPST (HYC) | Multi | No | No | By construction | Projection | Scribble |
| Toninho et al. | Binary | Yes | Linear | Yes | No | Research |
| Toninho-Yoshida 2025 | Binary | Refinement | Linear | Yes | Z3-based | Advancing |
| Das-Pfenning | Binary | No | Graded | Yes | No | Research |
| Balzer-Pfenning | Binary | No | Shared+Linear | Yes (manifest) | No | Research |
| Ferrite (Rust) | Binary | No | Ownership | Single-session | N/A | Library |
| Links | Binary | No | Linear | Single-session | Limited | Web apps |

### 12.3 Theoretical Foundations Comparison

| Foundation | Key Insight | Strengths | Limitations |
|-----------|------------|-----------|-------------|
| Linear logic | Resources consumed exactly once | Principled linearity, Curry-Howard | Complex (many connectives) |
| Pi-calculus | Names are values | Mobility, delegation | Undecidable properties |
| QTT | Multiplicities as semiring | Unified linear/unrestricted | Less expressive than full LL |
| Global types | Top-down protocol | Correct by construction | Merge condition limits |
| Typestate | States as types | Familiar OO model | No multi-party theory |
| Contracts | Runtime monitoring | Gradual adoption | No static guarantees |
| Propagators | Lattice fixpoints | Composable, parallel | Monotonicity requirement |

---

<a id="13-references"></a>

## 13. References

### Classical Process Calculi
- Milner, R. *A Calculus of Communicating Systems.* Springer LNCS 92, 1980.
- Milner, R. *Communication and Concurrency.* Prentice Hall, 1989.
- Hoare, C.A.R. *Communicating Sequential Processes.* Prentice Hall, 1985.
- Bergstra, J.A. and Klop, J.W. *Process Algebra for Synchronous Communication.* Information and Control, 1984.
- Milner, R., Parrow, J., and Walker, D. *A Calculus of Mobile Processes.* Information and Computation, 1992.
- Fournet, C. and Gonthier, G. *The Reflexive Chemical Abstract Machine and the Join-Calculus.* POPL, 1996.
- Cardelli, L. and Gordon, A.D. *Mobile Ambients.* FoSSaCS, 1998.
- Honda, K. and Tokoro, M. *An Object Calculus for Asynchronous Communication.* ECOOP, 1991.
- Boudol, G. *Asynchrony and the Pi-Calculus.* INRIA Report, 1992.
- Abadi, M. and Fournet, C. *Mobile Values, New Names, and Secure Communication.* POPL, 2001.

### Linear Logic
- Girard, J.-Y. *Linear Logic.* Theoretical Computer Science 50, 1987.
- Girard, J.-Y. *Light Linear Logic.* Information and Computation, 1998.

### Propositions as Sessions
- Caires, L. and Pfenning, F. *Session Types as Intuitionistic Linear Propositions.* CONCUR, 2010.
- Wadler, P. *Propositions as Sessions.* ICFP, 2012.
- Toninho, B., Caires, L., and Pfenning, F. *Higher-Order Processes, Functions, and Sessions: A Monadic Integration.* ESOP, 2013.

### Session Types
- Honda, K. *Types for Dyadic Interaction.* CONCUR, 1993.
- Honda, K., Vasconcelos, V.T., and Kubo, M. *Language Primitives and Type Discipline for Structured Communication-Based Programming.* ESOP, 1998.
- Gay, S. and Hole, M. *Subtyping for Session Types in the Pi Calculus.* Acta Informatica, 2005.
- Dezani-Ciancaglini, M. et al. *Session Types for Object-Oriented Languages.* ECOOP, 2006.
- Vasconcelos, V.T. *Fundamentals of Session Types.* Information and Computation, 2012.

### Multiparty Session Types
- Honda, K., Yoshida, N., and Carbone, M. *Multiparty Asynchronous Session Types.* JACM, 2016 (conference version POPL 2008).
- Deniélou, P.-M. and Yoshida, N. *Multiparty Session Types Meet Communicating Automata.* ESOP, 2012.
- Scalas, A. and Yoshida, N. *Less is More: Multiparty Session Types Revisited.* POPL, 2019.
- Yoshida, N. et al. *Scribble: Describing Multiparty Protocols.* 2013.

### Dependent and Refinement Session Types
- Toninho, B., Caires, L., and Pfenning, F. *Dependent Session Types via Intuitionistic Linear Type Theory.* PPDP, 2011.
- Toninho, B. and Yoshida, N. *Practical Refinement Session Type Inference.* 2025.
- Zhou, F. et al. *Label-Dependent Session Types.* POPL, 2023.

### Quantitative and Graded Types
- Atkey, R. *Syntax and Semantics of Quantitative Type Theory.* LICS, 2018.
- McBride, C. *I Got Plenty o' Nuttin'.* 2016.
- Das, A. and Pfenning, F. *Graded Modal Session Types.* 2020.
- Pruiksma, K. and Pfenning, F. *A Message-Passing Interpretation of Adjoint Logic.* 2019.

### Behavioral Types and Typestate
- Huttel, H. et al. *Foundations of Behavioural Types.* ACM Computing Surveys, 2016.
- Strom, R. and Yemini, S. *Typestate: A Programming Language Concept for Enhancing Software Reliability.* IEEE TSE, 1986.
- Aldrich, J. et al. *Typestate-Oriented Programming.* OOPSLA, 2009.
- Castagna, G., Gesbert, N., and Padovani, L. *A Theory of Contracts for Web Services.* ACM TOPLAS, 2009.

### Deadlock Freedom
- Balzer, S. and Pfenning, F. *Manifest Deadlock-Freedom for Shared Session Types.* ESOP, 2017.
- Padovani, L. *Deadlock and Lock Freedom in the Linear Pi Calculus.* LICS, 2014.
- Kobayashi, N. *A New Type System for Deadlock-Free Processes.* CONCUR, 2006.

### Practical Systems
- Armstrong, J. et al. *Concurrent Programming in Erlang.* Prentice Hall, 1993.
- Lightbend. *Akka Documentation.* https://doc.akka.io/
- Chen, R. *Ferrite: A Judgmental Embedding of Session Types in Rust.* 2021.
- Cooper, E. et al. *Links: Web Programming Without Tiers.* FMCO, 2006.
- Padovani, L. *A Simple Library Implementation of Binary Sessions.* JFP, 2017. (FuSe)

### Recent Advances
- Montesi, F. *Introduction to Choreographies.* Cambridge University Press, 2023.
- Hirsch, A. and Garg, D. *Pirouette: Higher-Order Typed Functional Choreographies.* POPL, 2022.
- Bravetti, M. et al. *On the Undecidability of Asynchronous Session Subtyping.* JACM, 2019.
- Igarashi, A. et al. *Gradual Session Types.* JFP, 2021.
- Thiemann, P. *Label-Dependent Session Types.* POPL, 2019.

### Concurrent Constraint Programming
- Saraswat, V. *Concurrent Constraint Programming.* MIT Press, 1993.
- Radul, A. *Propagation Networks.* MIT PhD Thesis, 2009.
