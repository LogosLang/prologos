- [The Insight](#org0e1fe4f)
- [Composition Patterns](#org1efe3c1)
  - [Pattern 1: Phase Transition (Sequential Composition)](#org05d5f47)
  - [Pattern 2: Mode Branching](#org9c40544)
  - [Pattern 3: Inline Prefix with Named Continuation](#orge72723c)
- [What This Means: Protocol Libraries](#org8e1169b)
- [The State Machine Interpretation](#org237d493)
- [The `end` Question: Intentional Design, Not Missing Feature](#org7bcae70)
  - [Why End-Splicing Is Rejected](#org3890d91)
  - [The Intentionality Principle](#org641169f)
  - [Making Protocols Composable](#org083f14a)
- [Capability Composition](#org2c9474f)
- [Relationship to Existing Type System Features](#orgbe918c6)
  - [Session Types as Layer 5](#org4a42962)
  - [Decomplection of Protocol and Process](#orgd044da7)
  - [Duality Composes](#org5b061fd)
  - [Progressive Disclosure](#org51da36a)
- [Theoretical Foundations](#orge606e45)
  - [Curry-Howard for Linear Logic (Toninho, Caires, Pfenning, 2011)](#orgb580268)
  - [Polymorphic Session Types (Caires et al., 2013)](#orgdaa8645)
  - [Context-Free Session Types (Thiemann & Vasconcelos, 2016; Padovani, 2017)](#orgdfef4e5)
  - [Scribble (Honda, Yoshida, et al.)](#org16fdb09)
  - [What Is Novel](#org5b8c5a1)
- [Design Principles for Protocol Composition](#org2ab9c3b)
- [Relationship to Other Principles](#org0c1eebd)
- [Implications for the Language](#orgdd26ddd)
  - [Protocol Libraries Become Possible](#org510cc07)
  - [Testing Protocols in Isolation](#org6a225e0)
  - [Error Handling at Phase Boundaries](#org7e144e4)
  - [AI Agent Protocols](#org1023637)
- [Inspirations](#org8c8be5d)



<a id="org0e1fe4f"></a>

# The Insight

Session types are types. Continuations are type positions. Named session types can appear in continuation positions. Therefore: **protocols compose through the type system with no additional mechanism.**

A session type describes a communication protocol. After each operation (send, receive, select, offer), there is a continuation &#x2014; a type describing "what comes next." When that continuation is a named session type, the protocol **transitions into a different protocol**. The type checker verifies the transition. The channel remains the same; only the protocol changes.

This is not syntactic sugar, not a macro expansion, not a runtime dispatch. It is the natural consequence of session types being first-class types in a dependently-typed language. Composition falls out of the type system for free.


<a id="org1efe3c1"></a>

# Composition Patterns

Three composition patterns emerge from this insight, none requiring new mechanisms beyond what session types already provide.


<a id="org05d5f47"></a>

## Pattern 1: Phase Transition (Sequential Composition)

A session type's continuation names the next phase of the protocol:

```prologos
session Handshake
  ! Version . ? Version . Authenticated  ;; after handshake → authenticate

session Authenticated
  ! Credentials
  ? [Result Token AuthError]
  +>
    | :ok   -> Ready             ;; success → operational phase
    | :fail -> end               ;; failure → done

session Ready
  +>
    | :query -> ! String . ? [Result Rows DbError] . Ready
    | :close -> end
```

The protocol flows: `Handshake → Authenticated → Ready → (loop) → end`. Each phase is a named type. Each transition is verified by the type checker. The **author** of each session type decides what comes next &#x2014; `Handshake` declares "after me comes `Authenticated`," not the caller.


<a id="org9c40544"></a>

## Pattern 2: Mode Branching

Choice operators (`+>` / `&>`) can branch into different sub-protocols:

```prologos
session DatabaseSession
  +>
    | :query  -> QueryMode
    | :admin  -> AdminMode
    | :close  -> end

session QueryMode
  ! String . ! [List Param] .
  ? [Result [List Row] DbError] .
  DatabaseSession                    ;; return to main protocol

session AdminMode
  +>
    | :vacuum -> ? [Result Unit DbError] . DatabaseSession
    | :backup -> ! Path . ? [Result Unit DbError] . DatabaseSession
```

This is **mutual recursion between protocols**. `DatabaseSession` branches to `QueryMode`, which does its work, then transitions back to `DatabaseSession`. The protocol graph can be arbitrarily complex &#x2014; any directed graph of named session types is expressible.


<a id="orge72723c"></a>

## Pattern 3: Inline Prefix with Named Continuation

Operations are written inline, with a named type taking over as the final continuation:

```prologos
session SecureFileSession
  ! Version . ? Version .                      ;; inline handshake operations
  ! Credentials . ? [Result Token AuthError] . ;; inline auth operations
  FileOps                                      ;; named type takes over
```

This is the most direct form of "do these things, then become that protocol." The inline prefix is protocol-specific; the named continuation is reusable.


<a id="org8e1169b"></a>

# What This Means: Protocol Libraries

Composition through types means session types become **building blocks**. A protocol library is a collection of named session types, each describing a reusable phase of interaction:

```prologos
;; --- Protocol building blocks ---

session Handshake
  ! Version . ? Version . Authenticated

session Authenticated
  ! Credentials . ? [Result Token AuthError] .
  +> | :ok -> Ready
     | :fail -> end

;; --- Domain protocols built from blocks ---

session Ready
  +>
    | :query -> QueryMode
    | :close -> end

session SecureDbSession
  Handshake               ;; starts with handshake → authenticated → ready
  ;; (the chain follows from Handshake's continuation declarations)
```

Each block is independently testable, independently verifiable, and independently documentable. Complex protocols are assembled from simple, well-understood components.


<a id="org237d493"></a>

# The State Machine Interpretation

Named session types are states. Operations within a session type are transitions. The continuation after each operation names the next state.

```
               Handshake
                  │
         ! Version . ? Version
                  │
                  ▼
            Authenticated
                  │
       ! Credentials . ? Result
                  │
             ┌────┴────┐
             ▼         ▼
          Ready      end
           │
    ┌──────┼──────┐
    ▼      ▼      ▼
QueryMode  │    end
    │      │
    └──────┘
 (returns to Ready)
```

This is a typed, verified finite state machine. Every transition is type-checked. Dead states are impossible (the type checker rejects protocols that don't reach `end`). Invalid transitions are type errors. The session type **is** the state machine specification.


<a id="org7bcae70"></a>

# The `end` Question: Intentional Design, Not Missing Feature

A natural question arises: if `Handshake` ends with `end`, can we compose it with `Auth` by replacing `end` with `Auth`?

```prologos
;; Both are complete, terminal protocols:
session Handshake
  ! Version . ? Version . end

session Auth
  ! Credentials . ? Token . end

;; Can we write this?
;; session Composed = Handshake . Auth    ;; hypothetical end-splicing
```

This would require **end-splicing** &#x2014; a type-level operation that substitutes `end` in one protocol with the start of another. Prologos **deliberately does not do this**, for principled reasons.


<a id="org3890d91"></a>

## Why End-Splicing Is Rejected

End-splicing introduces semantic complications:

1.  **Multiple exit points**: A protocol with several branches reaching `end` would have all of them spliced. Is that always what the author intended?

2.  **Recursive protocol interaction**: If a protocol has recursive self-references (`rec`) and `end` branches, splicing `end` must create a new recursive type where the self-references point to the spliced version. This requires type-level rewriting of recursive bindings.

3.  **Mixed continuations**: If some branches end with `end` and others with named types, which `end`​s get spliced? The semantics become ambiguous.

4.  **Retroactive composition**: A protocol defined with `end` was designed as terminal. Retroactively composing it changes its meaning without changing its definition. This violates referential transparency at the type level.


<a id="org641169f"></a>

## The Intentionality Principle

When `Handshake` says `end`, it means "*I am done &#x2014; the connection is finished*." When `Handshake` says `. Authenticated`, it means "*I am a phase, and after me comes authentication*." These are different protocols with different meanings.

A handshake-then-close and a handshake-then-authenticate are not the same handshake with different suffixes. They are different commitments. The named-continuation approach makes protocol composition **intentional**:

-   The **author** of a session type declares what comes next
-   A protocol defined with `end` is **complete** &#x2014; it is not a composable prefix
-   A protocol defined with a named continuation is **open** &#x2014; it transitions to another protocol
-   This distinction is explicit, visible in the type definition, and enforced by the type checker

This is analogous to the difference between a function that returns `A` and a function that takes a continuation `(A -> B) -> B`. Both are useful; neither is the other.


<a id="org083f14a"></a>

## Making Protocols Composable

If a protocol author intends their protocol to be used as a composable phase, they define it with a named continuation:

```prologos
;; Reusable: author explicitly says "something comes after me"
session Handshake
  ! Version . ? Version . Authenticated     ;; open: transitions to Authenticated

;; Terminal: author explicitly says "I'm the end"
session HandshakeDone
  ! Version . ? Version . end               ;; closed: terminates
```

Two types, two intentions, both clear. No machinery needed to distinguish them. The author's intent is visible in the type definition.


<a id="org2c9474f"></a>

# Capability Composition

When protocols compose, capabilities compose with them. Each named session type can carry capability requirements. The composed protocol's requirements are the union of its constituents':

```prologos
;; Each phase has its own capability requirements
session Handshake {net :0 TlsCap}
  ! ClientHello . ? ServerHello . Authenticated

session Authenticated {net :0 AuthCap}
  ! Credentials . ? Token . Ready

session Ready {fs :0 ReadCap}
  +>
    | :read -> ! Path . ? String . Ready
    | :done -> end
```

A process implementing the full `Handshake → Authenticated → Ready` chain requires `{net :0 TlsCap, net :0 AuthCap, fs :0 ReadCap}` &#x2014; the union of all phase requirements. The compiler computes this automatically. At runtime, `:0` capabilities are erased &#x2014; zero cost for authority verification.

This means:

-   **Protocols compose** &#x2014; named types in continuation position
-   **Capabilities compose** &#x2014; union of per-phase requirements
-   **Types verify the whole thing** &#x2014; the compiler checks authority at every phase transition
-   **Runtime cost is zero** &#x2014; `:0` authority proofs are erased


<a id="orgbe918c6"></a>

# Relationship to Existing Type System Features

Protocol composition through types is not an isolated feature. It connects to and reinforces several existing Prologos design principles:


<a id="org4a42962"></a>

## Session Types as Layer 5

The Layered Architecture (DESIGN<sub>PRINCIPLES</sub> §Layered Architecture) places protocols at Layer 5 (`session`) and processes at Layer 6 (`defproc`). Protocol composition works entirely within Layer 5 &#x2014; it is a property of protocol specifications, independent of process implementation. A `defproc` implements one endpoint of a (possibly composed) protocol; it does not need to know whether the protocol was assembled from multiple named session types.


<a id="orgd044da7"></a>

## Decomplection of Protocol and Process

DESIGN<sub>PRINCIPLES</sub> §Decomplection establishes that protocol specification (`session`) is decoupled from process implementation (`defproc`). Protocol composition deepens this decomplection: complex protocols can be assembled from simple building blocks at the type level, without any corresponding complexity in the process implementation. The process sees a single session type; whether it was composed from three named types or defined monolithically is invisible.


<a id="org5b061fd"></a>

## Duality Composes

Session type duality is preserved through composition. If `Handshake` transitions to `Auth`, then `dual Handshake` transitions to `dual Auth`. The type checker verifies duality for the entire composed protocol, not just each phase independently. This ensures end-to-end protocol safety.


<a id="org51da36a"></a>

## Progressive Disclosure

Protocol composition is a Tier 3 feature &#x2014; expert users building complex concurrent systems. Tier 1 users (`defn main`) never see session types. Tier 2 users (`with-open`) interact with single, monolithic protocols. Only users who need multi-phase, multi-protocol architectures encounter composition. The complexity is opt-in, following the Disappearing Features principle (ERGONOMICS §Guiding Principle).


<a id="orge606e45"></a>

# Theoretical Foundations

Protocol composition through types has roots in several lines of research, but Prologos's specific combination is novel.


<a id="orgb580268"></a>

## Curry-Howard for Linear Logic (Toninho, Caires, Pfenning, 2011)

Session types correspond to linear logic propositions under the Curry-Howard correspondence. Protocol composition corresponds to the **cut rule** &#x2014; the most fundamental operation in logic. Sequencing protocols is logically equivalent to composing proofs. The theoretical foundation for what Prologos does is as old as linear logic itself.


<a id="orgdaa8645"></a>

## Polymorphic Session Types (Caires et al., 2013)

Session types parameterized by other types, including continuation types. This gives the formal machinery for open-ended protocols: `Handshake[K] = ! Version . ? Version . K`. Prologos achieves the same effect through named continuations without requiring explicit type parameters.


<a id="orgdfef4e5"></a>

## Context-Free Session Types (Thiemann & Vasconcelos, 2016; Padovani, 2017)

Extensions that allow session types to express context-free languages, not just regular languages. This gives more expressive composition at the cost of decidability for some properties. Prologos stays within the regular fragment (tail-recursive protocols) for decidability guarantees.


<a id="org16fdb09"></a>

## Scribble (Honda, Yoshida, et al.)

A protocol description language for multiparty session types that supports protocol modules. The closest existing practical tool to protocol composition. But Scribble is a specification language &#x2014; protocols are described, not typed. Prologos makes protocols first-class types in the programming language itself.


<a id="org5b8c5a1"></a>

## What Is Novel

The **combination** is novel:

1.  Named session types as composable building blocks within a programming language (not a separate specification language)
2.  Capability composition tracking alongside protocol composition
3.  Propagator-based runtime that schedules composed protocols efficiently
4.  Progressive disclosure &#x2014; composition is opt-in, not forced
5.  The intentionality principle &#x2014; `end` means terminal, named continuations mean composable, and the distinction is a design choice

No existing language or tool unifies all five. The individual pieces are well-understood; the synthesis is new.


<a id="org2ab9c3b"></a>

# Design Principles for Protocol Composition

1.  **Protocols Are Types.** A session type is a first-class type. It can appear anywhere a type can appear &#x2014; as a continuation, as a type parameter, as a constraint. Protocol composition is type composition.

2.  **Composition Is Intentional.** The author of a session type decides whether it is composable (named continuation) or terminal (`end`). Composition is not retroactive. The type definition is a commitment.

3.  **Named Continuations, Not End-Splicing.** Protocols compose through named types in continuation position. There is no mechanism to replace `end` in a complete protocol with a continuation. The distinction between open and closed protocols is part of the protocol's meaning.

4.  **Capabilities Compose With Protocols.** When protocols compose, their capability requirements compose via union. The compiler tracks authority through every phase transition. Authority verification is free (`:0` erased).

5.  **Duality Is Preserved.** Protocol composition preserves the duality invariant. If server-side composes phases A → B → C, the client-side sees dual(A) → dual(B) → dual(C). End-to-end safety is guaranteed.

6.  **State Machines Are Types.** The protocol graph (named session types as states, operations as transitions) is verified by the type checker. Dead states, invalid transitions, and stuck channels are type errors.

7.  **Progressive Disclosure.** Simple protocols are simple to define. Composition is available when needed but never required. A monolithic `session` that does everything inline is always valid.


<a id="org0c1eebd"></a>

# Relationship to Other Principles

| Document                       | Relationship                                                                                                                                                                                                        |
|------------------------------ |------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DESIGN_PRINCIPLES.org`        | "Correctness Through Types" &#x2014; protocol composition is type composition. "Decomplection" &#x2014; protocol spec decoupled from process impl. "Layered Architecture" &#x2014; composition operates at Layer 5. |
| `LANGUAGE_VISION.org`          | "Protocol correctness" (§What Problem Does Prologos Solve?) extends from single protocols to composed protocols. "Session Types as Protocol Specifications" (§Cutting-Edge Research) gains composability.           |
| `CAPABILITY_SECURITY.md`       | "Session Types and Capability Protocols" (§Session Types) &#x2014; capability delegation follows composed protocol structure. Capability requirements union across composed phases.                                 |
| `ERGONOMICS.org`               | "Disappearing Features" &#x2014; composition is Tier 3, invisible to beginners. Progressive disclosure governs when users encounter it.                                                                             |
| `LANGUAGE_DESIGN.org`          | "Session Types as Protocol Specifications" (§Session Types) &#x2014; composition extends the specification power of session types. Duality, recursion, and choice all compose naturally.                            |
| `PATTERNS_AND_CONVENTIONS.org` | Session type naming patterns extend to composed protocols. Each named phase follows the same naming conventions.                                                                                                    |
| IO Library Design V2           | The IO design uses protocol composition extensively: `Handshake → Auth → FileOps` patterns, branching into sub-protocols, mode transitions.                                                                         |


<a id="orgdd26ddd"></a>

# Implications for the Language


<a id="org510cc07"></a>

## Protocol Libraries Become Possible

Named, composable session types enable a **standard library of protocols** &#x2014; reusable communication patterns that users can compose into application-specific protocols. Examples:

-   `Handshake` &#x2014; version negotiation
-   `TlsHandshake` &#x2014; TLS setup
-   `Auth` &#x2014; credential exchange
-   `Heartbeat` &#x2014; keepalive with timeout
-   `Pagination` &#x2014; cursor-based result traversal

These would live in `prologos.core.protocols` and compose freely.


<a id="org6a225e0"></a>

## Testing Protocols in Isolation

Each named session type can be tested independently. A test for `QueryMode` doesn't need to set up the full `DatabaseSession → QueryMode` chain &#x2014; it directly tests the `QueryMode` protocol against a mock endpoint. This mirrors how pure functions are tested independently of their callers.


<a id="org7e144e4"></a>

## Error Handling at Phase Boundaries

Errors at phase transitions &#x2014; authentication failure, handshake mismatch &#x2014; are type-level events. A branch to `end` at the wrong phase is visible in the type. Error protocols can be composed just like success protocols:

```prologos
session Authenticated
  ! Credentials . ? [Result Token AuthError] .
  +>
    | :ok   -> Ready
    | :fail -> ErrorRecovery           ;; transition to error protocol

session ErrorRecovery
  ! RetryRequest . ? [Result Token AuthError] .
  +>
    | :ok    -> Ready
    | :fail  -> end                     ;; final failure
```


<a id="org1023637"></a>

## AI Agent Protocols

Multi-agent communication (LANGUAGE<sub>VISION</sub> §AI Agent Infrastructure) benefits directly from protocol composition. Agent interaction protocols are built from composable phases:

```prologos
session AgentNegotiation
  ! Proposal . ? CounterProposal .
  +>
    | :accept -> CollaborativeWork
    | :counter -> AgentNegotiation     ;; re-negotiate
    | :reject -> end

session CollaborativeWork
  rec
    +>
      | :delegate -> ! Task . ? Result . CollaborativeWork
      | :report   -> ! Summary . end
```

The session type guarantees that agents follow the negotiation protocol, that delegation respects authority boundaries (via capabilities), and that the collaboration terminates.


<a id="org8c8be5d"></a>

# Inspirations

-   **Toninho, Caires, Pfenning** &#x2014; Session types as propositions (Curry-Howard for linear logic). Protocol composition = cut rule. The deepest theoretical foundation for this work.
-   **Honda, Yoshida, Carbone** &#x2014; Multiparty session types and the Scribble protocol description language. The closest practical precedent for protocol modularity.
-   **Lindley & Morris** &#x2014; Semantics for propositions as sessions. The cut rule gives composition; our named continuations are a user-facing expression of the same operation.
-   **Padovani** &#x2014; Context-free session types. Shows that session types can express more than regular languages, though we stay within the regular fragment for decidability.
-   **Mark Miller (E language)** &#x2014; Object-capability model. Capabilities compose through delegation; our capability composition through protocol composition mirrors this at the type level.
