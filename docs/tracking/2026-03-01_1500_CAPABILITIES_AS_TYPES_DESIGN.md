# Capabilities as Types: Design Document

**Status**: Phase 1 Research + Phase 2 Gap Analysis + Phase 3 Design Draft
**Date**: 2026-03-01
**Tracking**: `docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md`
**Principles**: `docs/tracking/principles/CAPABILITY_SECURITY.md`
**Prerequisite for**: I/O Library Design, Session Types for Authority Protocols, FFI Security

---

## Table of Contents

- [1. Motivation and Scope](#1-motivation)
- [2. Research Survey](#2-research)
  - [2.1 Operating System Capability Models](#21-os-capabilities)
  - [2.2 Object-Capability Languages and Frameworks](#22-ocap-languages)
  - [2.3 Linear/Affine Types as Capability Enforcement](#23-linear-capabilities)
  - [2.4 Capability Calculi and Type-Theoretic Foundations](#24-capability-calculi)
  - [2.5 Component Sandboxing and Capability Routing](#25-sandboxing)
  - [2.6 Synthesis: What the Research Tells Us](#26-synthesis)
- [3. Gap Analysis](#3-gap-analysis)
  - [3.1 Infrastructure That Exists](#31-exists)
  - [3.2 Infrastructure Gaps](#32-gaps)
  - [3.3 Principle Alignment Check](#33-alignment)
- [4. Design](#4-design)
  - [4.1 Capability Declaration](#41-declaration)
  - [4.2 The Capability Kind Marker](#42-kind-marker)
  - [4.3 Composite Capabilities via Union Types](#43-composite)
  - [4.4 Attenuation via Subtyping](#44-attenuation)
  - [4.5 Capability Resolution: Lexical, Not Global](#45-resolution)
  - [4.6 Capability Inference Through the Call Graph](#46-inference)
  - [4.7 The Authority Root](#47-authority-root)
  - [4.8 Dependent Capabilities](#48-dependent)
  - [4.9 The `:w` Warning Mechanism](#49-w-warning)
  - [4.10 Session Types as Capability Protocols](#410-sessions)
  - [4.11 Revocation](#411-revocation)
  - [4.12 Testing Capabilities](#412-testing)
- [5. Concrete Type Designs](#5-types)
  - [5.1 Standard Capability Hierarchy](#51-hierarchy)
  - [5.2 Example: Filesystem Capabilities for I/O Library](#52-fs-example)
  - [5.3 Example: Network Capabilities](#53-net-example)
  - [5.4 Example: Dependent Path Capability](#54-dependent-example)
- [6. Relationship to I/O Library Design](#6-io-relationship)
- [7. Phased Implementation Roadmap](#7-roadmap)
- [8. Open Questions for Design Discussion](#8-open-questions)
- [9. References](#9-references)

---

<a id="1-motivation"></a>

## 1. Motivation and Scope

The [Capability Security principles document](principles/CAPABILITY_SECURITY.md) establishes that Prologos is capability-secure by design: authority to perform effects is expressed through fine-grained capabilities in the type system, and the compiler verifies the Principle of Least Authority (POLA) statically.

This document is the **design-level specification** for how capabilities are expressed as types. It answers the concrete questions that the principles document leaves open:

1. **How is a type marked as a capability type?** (The "capability kind" question)
2. **How does the compiler resolve capability requirements?** (The "lexical resolution" mechanism)
3. **How does capability inference flow through the call graph?**
4. **How does the compiler warn on `:w` for capabilities but not traits?**
5. **What does the standard capability hierarchy look like?**
6. **How do dependent capabilities work in practice?**
7. **How does revocation work?**

The scope is the **type system and compiler infrastructure** for capabilities. The I/O library, FFI security, and session-typed authority protocols are *applications* of this infrastructure, designed separately but constrained by the decisions made here.

### What This Document Is NOT

- Not a principles document (that's `CAPABILITY_SECURITY.md`)
- Not the I/O library design (that's `2026-03-01_1200_IO_LIBRARY_DESIGN.md`, which this supersedes on capability questions)
- Not the session types design (a future document)

The I/O design's `World` token approach (Decision 1 in that document) is **superseded** by this document's fine-grained capability model. Rather than a single opaque `World` token (Mercury/Clean), Prologos uses typed, composable capabilities (`FsCap`, `NetCap`, `DbCap`) that the type system tracks individually.

---

<a id="2-research"></a>

## 2. Research Survey

Research conducted across three domains: (1) operating system capability models, (2) object-capability languages and frameworks, and (3) typed capability systems from programming language theory.

<a id="21-os-capabilities"></a>

### 2.1 Operating System Capability Models

#### seL4 Microkernel

seL4 is the gold standard for formally verified capability security. Key mechanisms:

- **CSpace (Capability Space)**: Each thread has a CSpace — a tree of CNode objects containing capability slots. A capability is addressed by a path through the CNode tree (guard bits + index at each level). There is no ambient authority; all kernel operations require an explicit capability argument.

- **Capability Derivation Tree (CDT)**: The kernel maintains a global tree tracking how every capability was derived. If capability B was minted from capability A (via `Copy`, `Mint`, or `Retype`), B is a child of A in the CDT. This enables **hierarchical revocation**: revoking A automatically invalidates all descendants.

- **Capability Operations**:
  | Operation | Meaning | Prologos Analogue |
  |-----------|---------|-------------------|
  | **Copy** | Duplicate a capability into another slot | `:w` multiplicity (or explicit `copy-cap`) |
  | **Mint** | Copy with reduced rights (badge + access rights mask) | Attenuation via subtyping |
  | **Move** | Transfer a capability (source slot becomes empty) | `:1` linear transfer |
  | **Delete** | Remove a capability from a slot | Linear consumption |
  | **Revoke** | Delete all derived capabilities (CDT children) | Revocation via linear scope exit |
  | **Retype** | Create new typed capabilities from untyped memory | Authority root minting |

- **Badge**: A word-sized value stamped onto a capability at Mint time. Used to distinguish which client sent a message through a shared endpoint. In Prologos: a dependent type index (`FileCap path`) serves the same purpose — identifying which specific resource a capability authorizes.

- **Formal Verification**: seL4 has a machine-checked proof (in Isabelle/HOL) that the C implementation refines the abstract specification, which in turn satisfies authority confinement: capabilities cannot be forged, and authority propagates only through explicit operations. Prologos aims for the same property via the type system rather than a separate proof.

**Key insight for Prologos**: seL4's capability operations map cleanly onto QTT multiplicities. The CDT maps onto lexical scope nesting. The badge maps onto dependent type indices. The formal verification goal maps onto type soundness.

#### Google Fuchsia / Zircon

Fuchsia's Zircon microkernel uses capabilities at multiple levels:

- **Handles**: User-space values representing kernel object references. Each handle carries a **rights bitmask** (`ZX_RIGHT_READ`, `ZX_RIGHT_WRITE`, `ZX_RIGHT_DUPLICATE`, `ZX_RIGHT_TRANSFER`, etc.). Rights can only be reduced, never amplified — attenuation is monotonic.

- **Component Framework**: Components receive capabilities through **routing declarations** in their manifest. A component can only access services explicitly routed to it by its parent. There is no way to "discover" a service — you have it or you don't. This is POLA at the architectural level.

- **FIDL Protocols**: Fuchsia's Interface Definition Language uses the `resource` keyword to mark types that contain handles (capabilities). The FIDL compiler enforces that resource types cannot be duplicated, only moved — a form of linearity at the IDL level.

- **Namespace Sandboxing**: Each component's `/svc` namespace contains only the services it has been granted. The kernel validates handle rights at every system call boundary.

**Key insight for Prologos**: Fuchsia's rights bitmask is a *runtime* representation of what Prologos can enforce *statically* via union type membership. The FIDL `resource` keyword is analogous to our capability kind marker — a way to tell the compiler "this type represents authority, not data."

<a id="22-ocap-languages"></a>

### 2.2 Object-Capability Languages and Frameworks

#### E Language (Mark Miller)

The foundational work on object capabilities in a programming language:

- **References ARE capabilities**: In E, the only way to affect the world is through references. If you hold a reference to a file object, you can call its methods. If you don't, you can't. There is no `System.getFile()` ambient authority — you must be *given* a file reference.

- **Capability Discipline (5 Rules)**:
  1. **No ambient authority** — no global mutable state, no static methods with side effects
  2. **Only connectivity begets connectivity** — you can only obtain a reference through another reference you already hold
  3. **No forgery** — you cannot fabricate a reference from a string or integer
  4. **Encapsulation** — objects can restrict which of their methods are callable
  5. **Only introduction provides introduction** — A can introduce B to C only if A already has references to both B and C

- **Eventual Sends and Vats**: E uses **eventual-send** (`<-`) for asynchronous, potentially remote invocation. A Vat is a single-threaded event loop (like an Erlang process). Capabilities can be sent across Vat boundaries via eventual sends, enabling distributed capability security.

- **Promise Pipelining**: When you send a message to a promise (a not-yet-resolved capability), E pipelines subsequent messages to the eventual target. This reduces round-trips in distributed capability systems. In Prologos terms: session types could formalize the pipelining protocol.

- **The Confused Deputy**: Miller's canonical example of why ACLs fail. A compiler that writes to a log file is tricked into overwriting a billing file because it "runs as" a user with billing access. In a capability system, the compiler has a reference to the log file and ONLY the log file — it cannot be confused about which file to write.

**Key insight for Prologos**: E's five rules map onto our type system guarantees. Rule 1 (no ambient authority) is enforced by capability resolution being lexical, not global. Rule 3 (no forgery) is enforced by capabilities having no public constructors. Rule 2 (connectivity begets connectivity) is the call-chain resolution model.

#### Mark Miller's Later Work: SES, Compartments, Agoric

Miller continued the capability security agenda into JavaScript and blockchain:

- **Secure ECMAScript (SES)**: A frozen subset of JavaScript where all primordials (built-in objects) are frozen, global scope is attenuated, and the only way to affect the world is through explicitly granted "endowments." Demonstrates that capability security can be retrofitted onto an existing language (at significant engineering cost).

- **Compartments**: A Compartment is a lightweight sandbox with its own global scope and module loader. Modules loaded in a Compartment can only access capabilities provided by the Compartment's `endowments` and `moduleMap`. This is the JavaScript version of Prologos's "library code has no ambient authority."

- **Agoric and CapTP**: Capability Transfer Protocol — a protocol for securely sending capabilities between Vats (processes) over the network. Formalizes the rules for remote capability introduction, attenuation, and revocation. In Prologos: session types formalize these protocols at compile time.

- **Membrane Pattern**: A membrane wraps an object graph, interposing on all cross-membrane references to enforce attenuation. When the membrane is revoked, all cross-membrane capabilities become inert. This is a *runtime* pattern; Prologos can express the same invariant *statically* via linear scope exit.

- **Powerbox Pattern**: A UI pattern where code that needs a capability requests it from the user (via a file picker, etc.) rather than having ambient access. The powerbox is the authority root — the human user is the ultimate source of authority. In Prologos: `main` is the powerbox.

**Key insight for Prologos**: Miller's body of work shows that capability security is a whole-system property, not just a language feature. The membrane pattern (revocation of an object graph) maps onto linear scope exit. The powerbox pattern maps onto the authority root.

<a id="23-linear-capabilities"></a>

### 2.3 Linear/Affine Types as Capability Enforcement

#### Austral

Austral is the most direct comparison — a language designed from the ground up with linear types AND capability security:

- **Two Universes**: `Free` (unrestricted, can be duplicated) and `Linear` (must be used exactly once). All capability types (file handles, sockets, etc.) are in the Linear universe. Pure data (strings, integers) is in the Free universe.

- **Capability Modules**: Austral uses a module-level mechanism — modules declare which capabilities they require, and the build system enforces that only authorized modules can access I/O.

- **No `:0` Equivalent**: Austral has no erased-but-verified mode. A linear capability must exist at runtime if it's used. This means authority checking always has runtime cost — unlike Prologos's `:0` mode where the capability is verified at compile time and erased.

- **`borrowing` References**: Austral allows temporary non-consuming access to linear values via `borrow` — similar to Rust's borrows but simpler (no lifetimes, just lexical scope). In Prologos: `:0` multiplicity gives "compile-time borrow" — you prove the capability exists without consuming it.

**Key insight for Prologos**: Austral validates the "linear types + capability security" combination but is weaker than what Prologos can offer. Prologos's `:0` mode (erased proof of authority) gives zero-cost capability checking that Austral can't express. Prologos's dependent types give resource-specific capabilities that Austral can't express.

#### Pony Reference Capabilities

Pony uses six reference capabilities forming a lattice:

| Capability | Alias | Send | Description |
|-----------|-------|------|-------------|
| `iso` | no | yes | Isolated — only one reference exists. Like `:1`. |
| `val` | yes | yes | Value — deeply immutable, can be shared. Like `:0` data. |
| `ref` | yes | no | Reference — mutable, not sendable. Like `:w` local. |
| `box` | yes | no | Box — readable, not writable. Read-only view. |
| `trn` | no | no | Transition — mutable but becoming `val`. |
| `tag` | yes | yes | Tag — identity only, no read/write. |

Pony's **deny capabilities matrix** defines which combinations of aliases are safe (no data races). The **viewpoint adaptation** rules determine what reference capability you get when accessing a field through a reference of a given capability.

**Key insight for Prologos**: Pony's lattice of six capabilities is more fine-grained than QTT's three multiplicities, but addresses a *different problem* (data-race freedom vs. authority control). However, the concept of a **capability lattice with subtyping** is directly relevant — Prologos's capability hierarchy forms a lattice where attenuation moves down and composition moves up.

#### Granule: Graded Modal Types

Granule is a research language that generalizes linearity to arbitrary **coeffects** — a type system where resources are tracked by an arbitrary semiring:

- Types are annotated with a **grade** from a user-definable resource algebra
- The default semiring is `{0, 1, many}` (isomorphic to QTT)
- But users can define richer semirings: e.g., `{read, write, readwrite}` for file access rights
- Coeffect polymorphism allows abstracting over the grade

**Key insight for Prologos**: Granule shows that QTT is a *specific instance* of a more general coeffect system. If Prologos ever needs richer capability tracking than `:0`/`:1`/`:w` (e.g., distinguishing read-authority from write-authority at the multiplicity level), graded modal types provide the theoretical foundation. For now, QTT + union type capability hierarchy is sufficient.

<a id="24-capability-calculi"></a>

### 2.4 Capability Calculi and Type-Theoretic Foundations

#### Crary & Morrisett (1999): Capabilities as Types

The foundational type-theoretic treatment of capabilities:

- **Key idea**: Capabilities are *types*, not values. A capability is a proof that a certain memory region has a certain type. Operations require the appropriate capability as a type-level argument.

- **Capability-Pointer Separation**: A pointer is a value (runtime data). A capability is a type-level proof that the pointer is valid and has a given type. The capability can be erased at runtime — only the pointer is needed.

- **Subtyping on Capabilities**: If capability A subsumes capability B (A gives more access than B), then A is a subtype of B. This enables weakening: passing a broader capability where a narrower one is required.

- **Duplication and Linearity**: In the Crary-Morrisett system, capabilities can be duplicated (they're proofs, not resources). Linear capabilities (non-duplicable authority tokens) require extending the system.

**Key insight for Prologos**: This is the theoretical foundation for our `:0` mode. When a capability constraint is at `:0`, it IS a Crary-Morrisett capability — a type-level proof of authority that is erased at runtime. When it's at `:1`, it's a *linear* capability — a runtime token that enforces single-use. Prologos unifies both in one system.

#### Dependent Types and Capabilities

Several research lines connect dependent types with capabilities:

- **Dependent capability types**: A capability indexed by the resource it authorizes. `FileCap : Path -> Type` says "a capability to access a specific file." This is richer than a flat `ReadCap` because it distinguishes *which* file you can read.

- **Existential capabilities**: A function returns `exists p. FileCap p * Handle p` — a capability bundled with the resource it authorizes, where the specific path is opaque. The caller knows they have *some* file access but can't inspect which file. This enables capability transfer without information leakage.

- **Pi-types for capability-parameterized operations**: `(p : Path) -> FileCap p -> Result String IOError` — the operation is parameterized by the path, and the capability must match.

**Key insight for Prologos**: Dependent capabilities are the richest tier of our system. They correspond to seL4's badged capabilities (capabilities that name specific kernel objects). Prologos is uniquely positioned to express these because it has full dependent types — Austral, Pony, and Granule do not.

<a id="25-sandboxing"></a>

### 2.5 Component Sandboxing and Capability Routing

#### WASI (WebAssembly System Interface)

WASI is the most successful recent deployment of capability-based I/O:

- **Pre-opened Directories**: A WASI program can only access directories explicitly granted at startup. There is no `open("/etc/passwd")` — only `openat(pre_opened_fd, "data.csv")`. The pre-opened file descriptors are the capabilities.

- **Fine-grained Rights**: Each file descriptor carries a rights mask (`FD_READ`, `FD_WRITE`, `FD_SEEK`, `FD_TELL`, `PATH_OPEN`, `PATH_CREATE_FILE`, etc.). Rights can only be reduced, never amplified.

- **No Global Filesystem**: There is no `/` root. The component's view of the filesystem is exactly the set of pre-opened directories. This is POLA enforced at the OS/runtime level.

**Key insight for Prologos**: WASI's model is the runtime analogue of what Prologos enforces at compile time. WASI's pre-opened directories correspond to the capabilities granted at `main`. WASI's rights masks correspond to our capability union types (a `FsCap = ReadCap | WriteCap` is a "rights mask" expressed as a type). The key advantage of Prologos's approach: violations are caught *before* the program runs.

<a id="26-synthesis"></a>

### 2.6 Synthesis: What the Research Tells Us

Across all surveyed systems, five themes emerge:

**Theme 1: Capabilities must be unforgeable and non-ambient.**
Every system — seL4, E, Fuchsia, WASI, Austral, Pony — agrees that capabilities cannot be fabricated from nothing and that code cannot access capabilities it wasn't explicitly granted. This is the fundamental property.

**Theme 2: Attenuation is monotonic (rights only decrease).**
Fuchsia's rights bitmask, seL4's Mint operation, E's membrane pattern, WASI's reduced rights on `openat` — all enforce that you can create a weaker capability from a stronger one, but never the reverse. In type-theoretic terms: attenuation is subtyping, and subtyping is monotonic.

**Theme 3: The authority root is special.**
seL4's initial thread, E's powerbox, WASI's pre-opened directories, Austral's module declarations, Prologos's `main` — every system needs a place where capabilities originate. Below the authority root, all capability flow is through explicit delegation.

**Theme 4: Linear types are the ideal enforcement mechanism.**
Austral, Clean, Rust ownership, Pony's `iso`, seL4's Move — linearity ensures that capabilities cannot be silently duplicated or leaked. Among surveyed systems, only Prologos (via QTT) offers *three* modes of capability usage: erased proof (`:0`), linear transfer (`:1`), and unrestricted (`:w` with warning). This is strictly more expressive than any other system.

**Theme 5: Static verification is strictly superior to runtime checking.**
seL4 proves authority confinement in Isabelle/HOL. Pony proves data-race freedom via its type system. Austral proves resource safety via linearity. Runtime capability checks (Fuchsia, WASI, E) can fail at runtime — static checks (Prologos, Austral, Pony) cannot. Prologos aims for the strongest guarantee: compile-time verification of authority, resource safety, AND protocol correctness (via session types).

---

<a id="3-gap-analysis"></a>

## 3. Gap Analysis

<a id="31-exists"></a>

### 3.1 Infrastructure That Exists

| Infrastructure | Status | Relevance to Capabilities |
|----------------|--------|--------------------------|
| **QTT (`:0` / `:1` / `:w`)** | Complete | The enforcement mechanism — `:0` for authority proofs, `:1` for authority transfer |
| **Union types (`expr-union`)** | Complete | Composite capabilities as `type FsCap := ReadCap \| WriteCap` |
| **Subtype declarations** | Complete | Attenuation — `ReadCap <: FsCap` with transitive closure |
| **Implicit arguments (`{A : Type}`)** | Complete | Capability parameters in specs — `{fs :0 ReadCap}` |
| **Trait system** | Complete | Capability declaration as zero-method traits |
| **Dependent types** | Complete | Resource-indexed capabilities — `FileCap : Path -> Type` |
| **Session types** | Complete | Protocols for capability delegation |
| **`schema` form** | Designed | Structured data validation at capability-governed boundaries |
| **Elaborator (`elaborator.rkt`)** | Complete | Site for capability inference and resolution |
| **Type checker (`typing-core.rkt`)** | Complete | Site for capability verification |
| **QTT checker (`qtt.rkt`)** | Complete | Site for `:w` warning on capability types |
| **Foreign function interface** | Complete | Wrapping host I/O; needs capability gating |
| **Propagator network (`propagator.rkt`)** | Complete | Lattice-based cells, BSP scheduler, `run-to-quiescence` — capability inference IS a monotonic fixed-point problem |
| **ATMS (`atms.rkt`)** | Complete | Provenance for capability requirements — "why does f require ReadCap?" answered by ATMS dependency trees |
| **Galois connections / cross-domain propagators** | Complete | Cross-network communication between type inference and capability inference networks |
| **SetLattice** | Complete | CapabilitySet as `PowerSet(CapabilityType)` — join is set union, bot is `{}` |
| **Abstract domains (Sign, Parity, Interval)** | Complete | Precedent for domain-specific lattices over the propagator network |

The core message: **Prologos already has the type-system primitives AND the constraint-solving infrastructure** needed for capability security. The propagator network, ATMS, and Galois connections — built for the Logic Engine — are directly applicable to capability inference. What's missing is the *glue* — the mechanisms that connect these primitives into a coherent capability system.

<a id="32-gaps"></a>

### 3.2 Infrastructure Gaps

#### Gap 1: Capability Kind Marker

**Problem**: The compiler cannot currently distinguish a capability type from a regular type. Both `ReadCap` (a capability) and `Eq` (a trait) are traits. The compiler needs to know which is which to:
- Default capability constraints to `:0` (not `:w`)
- Warn on `:w` capability constraints
- Use lexical resolution instead of global resolution

**Required**: A mechanism to mark a type as a capability type. Options explored in [§4.2](#42-kind-marker).

#### Gap 2: Lexical Capability Resolution

**Problem**: The trait instance resolver (`resolve-trait-constraints!` in `typing-core.rkt`) searches the global instance registry. Capabilities must NOT be in the global registry — they must resolve from the lexical scope (function parameters, module-level grants).

**Required**: A separate resolution path for capability constraints that searches the lexical environment (function parameters, let-bound values, module-level declarations) instead of the global instance registry. See [§4.5](#45-resolution).

#### Gap 3: Capability Inference Through Call Graphs

**Problem**: Currently, the elaborator and type checker work function-by-function. Capability inference requires propagating capability requirements through the call graph: if `f` calls `g`, and `g` requires `{ReadCap}`, then `f` must also require `{ReadCap}` (unless `f` explicitly provides it). This is a monotonic fixed-point computation over a PowerSet lattice — exactly the class of problem the Logic Engine's propagator network was built to solve.

**Required**: A propagator network where each function is a cell holding its CapabilitySet, call edges are propagators that union callee requirements into callers, and `run-to-quiescence` computes the transitive capability closure. The ATMS threads provenance through the network, enabling "why does f require ReadCap?" queries. See [§4.6](#46-inference).

#### Gap 4: Multiplicity Defaulting for Capability Constraints

**Problem**: Currently, implicit arguments default to `:0` (erased). This is correct for trait constraints AND for capability constraints — but the mechanism should be explicit and documented, not accidental.

**Required**: Explicit defaulting rules for capability constraints: `:0` by default, `:1` when explicitly annotated for transfer. The `:w` case triggers a warning.

#### Gap 5: Foreign Function Capability Gating

**Problem**: Currently, `foreign` declarations can import any host function without capability requirements. A `foreign racket` import of `open-input-file` should require `{FsCap}`.

**Required**: Capability annotations on `foreign` declarations: `foreign racket "..." {fs : FsCap} [racket-open : ...]`. See [§4.7](#47-authority-root) for how foreign imports are the "leaves" of the capability tree.

<a id="33-alignment"></a>

### 3.3 Principle Alignment Check

| Principle (DESIGN_PRINCIPLES) | Alignment |
|-------------------------------|-----------|
| **Correctness Through Types** | Capability verification IS type checking. Authority correctness is a type-level property. |
| **Simplicity of Foundation** | No new language mechanisms — capabilities use existing traits, union types, subtyping, implicit params. |
| **Progressive Disclosure** | Pure code sees no capabilities. I/O code sees `{ReadCap}` in inferred type (if asked). Expert code writes explicit capability params. |
| **Pragmatism with Rigor** | The theoretical foundation (Crary-Morrisett capability calculus, ocap model) hides behind `{ReadCap}` annotations. |
| **Decomplection** | Capabilities are decoupled from: identity (no ACLs), I/O mechanism (capability ≠ file handle), protocol (session types are separate). |
| **The Most Generalizable Interface** | Union types for composition, subtyping for attenuation — the most general mechanisms available. |
| **Open Extension, Closed Verification** | New capability types can be added (open world), but adding a capability type cannot break existing type-checking guarantees (closed verification). |

---

<a id="4-design"></a>

## 4. Design

<a id="41-declaration"></a>

### 4.1 Capability Declaration

Capabilities are declared as **zero-method traits** with a `capability` marker:

```prologos
;; A capability is a zero-method trait marked with `capability`
capability ReadCap          ;; authority to read from filesystem
capability WriteCap         ;; authority to write to filesystem
capability HttpCap          ;; authority to make HTTP requests
capability WsCap            ;; authority for WebSocket connections
capability DbCap            ;; authority to access databases
capability SpawnCap         ;; authority to spawn child processes
capability ClockCap         ;; authority to read system clock
```

The `capability` keyword is sugar for a zero-method trait with the capability kind marker (see [§4.2](#42-kind-marker)). It is NOT a new language mechanism — it desugars to an annotated trait:

```prologos
;; `capability ReadCap` desugars to:
trait ReadCap :capability
```

The `:capability` metadata on the trait is the kind marker. The `capability` keyword is surface sugar that makes the intent clear without requiring users to know about trait metadata.

**Why zero-method?** A capability is a *proof of authority*, not an interface. You don't call methods on a capability — you pass it to functions that check for it. This is the Crary-Morrisett model: capabilities are types (proofs), not values (objects).

However, the design does not preclude method-bearing capabilities in future. A `capability FileSystem` with a `read-bytes` method would make the capability and the operation inseparable — the most secure form (you can't have the operation without the authority). This is a Phase 2 consideration.

<a id="42-kind-marker"></a>

### 4.2 The Capability Kind Marker

The compiler needs a way to distinguish capability types from regular trait types. This is the "kind marker" — a piece of metadata on the trait that changes how the compiler handles constraints involving this trait.

#### Mechanism

When a trait is marked as a capability (via `capability` keyword or `:capability` metadata), the compiler:

1. **Registers it in the capability registry** (a separate registry from the trait instance registry)
2. **Defaults constraints to `:0`** — `{fs : ReadCap}` is `{fs :0 ReadCap}` unless annotated otherwise
3. **Warns on `:w`** — `{fs :w ReadCap}` triggers a compiler warning
4. **Uses lexical resolution** — resolves `ReadCap` from the call chain, not the global instance registry
5. **Participates in capability inference** — propagates requirements through the call graph

#### Implementation

The capability registry is a simple set in the compiler state:

```
current-capability-types : (Setof Symbol)
```

When the elaborator encounters a trait constraint, it checks:
```
(if (set-member? (current-capability-types) trait-name)
    (resolve-capability-constraint ...)   ;; lexical resolution
    (resolve-trait-constraint ...))        ;; global resolution
```

This is a clean separation: the *same* constraint syntax (`{X : T}`) is used for both traits and capabilities, but the resolution mechanism differs based on whether `T` is a capability type.

<a id="43-composite"></a>

### 4.3 Composite Capabilities via Union Types

As established in the principles document, composite capabilities are **union types** (weakening / set-union of authority), not bundles (contraction / conjunction of constraints):

```prologos
;; Composite capabilities as union types
type FsCap    := ReadCap | WriteCap
type NetCap   := HttpCap | WsCap
type SysCap   := FsCap | NetCap | DbCap | SpawnCap | ClockCap
```

Having `FsCap` means having authority that *includes* both reading and writing. The union expands the set of permitted operations.

#### Why Union Types Compose Correctly

Consider a function that needs both filesystem and network access:

```prologos
spec sync-files {fs :0 FsCap} {net :0 HttpCap} : Path -> URL -> Result Unit SyncError
```

The function has TWO capability constraints — one for filesystem, one for network. This is a conjunction at the *constraint level* (the function needs BOTH), but each individual capability is a union at the *authority level* (FsCap grants read OR write).

This is the correct decomposition:
- **Capabilities compose via union** (what authority each capability grants)
- **Requirements compose via conjunction** (what authorities a function needs)

Bundles confuse these two levels — a bundle would make `FsCap` a conjunction ("must satisfy ReadCap AND WriteCap"), which is backwards.

<a id="44-attenuation"></a>

### 4.4 Attenuation via Subtyping

Union type membership gives natural subtyping:

```prologos
;; ReadCap is a member of FsCap (:= ReadCap | WriteCap)
;; Therefore ReadCap <: FsCap — read authority is a subset of full fs authority
ReadCap  <: FsCap
WriteCap <: FsCap

;; FsCap is a member of SysCap
FsCap    <: SysCap
NetCap   <: SysCap
DbCap    <: SysCap
SpawnCap <: SysCap
ClockCap <: SysCap

;; Transitive closure (computed automatically by existing subtype infrastructure):
;; ReadCap <: FsCap <: SysCap  (chained form)
;; Therefore ReadCap <: SysCap
```

This means:
- A function requiring `{ReadCap}` can be called by anyone with `{FsCap}` or `{SysCap}`
- The compiler resolves this via existing subtype subsumption
- No explicit attenuation needed for the common case (`:0` authority checking)

For explicit attenuation (`:1` authority transfer — giving away a narrower capability):

```prologos
;; Explicit attenuation: consume FsCap, produce ReadCap
;; The caller loses full fs authority and keeps only read authority
spec attenuate-to-read : FsCap :1 -> ReadCap :1
```

This is the seL4 Mint operation, expressed as a linear function.

<a id="45-resolution"></a>

### 4.5 Capability Resolution: Lexical, Not Global

This is the most important design decision. Capabilities resolve differently from traits:

| Aspect | Traits | Capabilities |
|--------|--------|-------------|
| **Registry** | Global instance registry | No global registry |
| **Resolution** | Compiler searches all registered instances | Compiler searches lexical scope (parameters, let-bindings, module declarations) |
| **Availability** | Available everywhere (ambient) | Available only where explicitly granted (non-ambient) |
| **Multiplicity default** | `:w` (unrestricted) | `:0` (erased proof) |
| **`:w` behavior** | Normal, no warning | Warning: "unrestricted capability" |

#### Resolution Algorithm

When the compiler encounters a capability constraint `{cap : CapType}`:

1. **Search function parameters**: Does any parameter have type `CapType` or a supertype of `CapType`?
2. **Search let-bindings**: Is `CapType` bound in an enclosing `let`?
3. **Search module-level grants**: Does the module declare `{CapType}` in its module-level capability set?
4. **Search the call chain (inference)**: If none of the above, propagate the requirement upward to the caller. The caller must provide the capability.
5. **If at the authority root (`main`)**: The runtime provides the capability. No propagation needed.
6. **If no resolution**: Type error — "Required capability `ReadCap` not available. The function `foo` requires filesystem read access, but no `ReadCap` is in scope."

#### Example

```prologos
capability ReadCap
capability WriteCap
type FsCap := ReadCap | WriteCap

;; main receives SysCap from the runtime (authority root)
defn main {sys :0 SysCap}
  [process-data [path "/data/input.csv"] [path "/data/output.csv"]]

;; process-data doesn't declare capability params — they're inferred
defn process-data [in-path out-path]
  let data := [read-file in-path]      ;; read-file requires {ReadCap}
  let result := [transform data]        ;; pure — no capabilities
  [write-file out-path result]         ;; write-file requires {WriteCap}

;; The compiler infers:
;;   process-data requires {ReadCap, WriteCap}
;;   which is equivalent to {FsCap}
;;   main has {SysCap} which subsumes {FsCap}
;;   Resolution: SysCap >: FsCap >: ReadCap ✓
;;   Resolution: SysCap >: FsCap >: WriteCap ✓
```

<a id="46-inference"></a>

### 4.6 Capability Inference via Propagator Network

Capability inference is a **monotonic fixed-point computation** over a PowerSet lattice — exactly the class of problem the Logic Engine's propagator network was built to solve. Rather than implementing a hand-rolled fixed-point pass, we reuse the existing propagator infrastructure (`propagator.rkt`), gaining uniform quiescence detection, ATMS provenance, and CHAMP-backed persistence for free.

#### The Propagator Network Architecture

```
   Capability Inference Network (separate from type inference)
   ┌────────────────────────────────────────────────────────┐
   │                                                        │
   │  ┌──────────┐  call-edge   ┌──────────────┐           │
   │  │ read-file│─────────────▶│ process-data  │           │
   │  │ {ReadCap}│  propagator  │ {ReadCap, ... }│          │
   │  └──────────┘              └───────┬───────┘           │
   │                                    │ call-edge         │
   │  ┌───────────┐  call-edge  ┌──────▼───────┐           │
   │  │write-file │─────────────▶│    main      │           │
   │  │{WriteCap} │  propagator  │ {Read,Write} │           │
   │  └───────────┘              └──────────────┘           │
   │                                                        │
   │  ┌──────────┐                                          │
   │  │transform │  (no call-edge propagators)              │
   │  │   {}     │  → stays at ⊥ = pure                    │
   │  └──────────┘                                          │
   │                                                        │
   │  Lattice: PowerSet(CapabilityType)                     │
   │  Join: set-union    Bot: {}    Top: AllCaps            │
   │  Quiescence: run-to-quiescence → fixed point           │
   └────────────────────────────────────────────────────────┘
```

#### Network Construction

The network is built as a **post-type-checking pass** (after all functions in a module are type-checked):

1. **Cell creation**: For each function `f` in the module, create a cell `cap-cell(f)` with domain `PowerSet(CapabilityType)`, initialized to `{}` (empty = pure).

2. **Seed leaf cells**: For functions with explicit capability declarations in their specs (`{fs :0 ReadCap}`), merge the declared capabilities into their cell. These are the "axioms" of the network.

3. **Wire call-edge propagators**: For each call `f → g` in the call graph, add a propagator: `when cap-cell(g) changes, union its value into cap-cell(f)`. This is `net-add-propagator!` with a `set-union` merge.

4. **Run to quiescence**: `run-to-quiescence` computes the fixed point. All cells now hold their **capability closure** — the transitive set of capabilities required.

5. **Verify authority roots**: Check that `main`'s explicit capability set subsumes its inferred closure. Emit errors for uncovered capabilities.

#### The Capability Closure

The **capability closure** of a function is the fixed-point value of its cell — the full set of capabilities transitively required by its body. This is analogous to the "effect set" in effect type systems, but using capabilities instead of effects.

```prologos
;; After run-to-quiescence, cells hold:
;;   cap-cell(main):         {ReadCap, WriteCap}  (inferred)
;;   cap-cell(process-data): {ReadCap, WriteCap}  (inferred from callees)
;;   cap-cell(read-file):    {ReadCap}             (seeded from spec)
;;   cap-cell(write-file):   {WriteCap}            (seeded from spec)
;;   cap-cell(transform):    {}                    (pure — no propagators fired)
```

The capability closure is:
- **Inferred** — the programmer doesn't write it unless they choose to
- **Visible** — an IDE command or REPL query can display it
- **Auditable** — security review reduces to inspecting capability closures
- **Monotonic** — adding a callee can only expand the closure, never shrink it
- **Provenance-tracked** — with ATMS threading (see below), each capability in the closure has a derivation chain

#### ATMS Provenance: "Why Does f Require ReadCap?"

By threading the ATMS through the capability inference network, every capability in every cell's closure carries a **derivation tree** explaining how it was inferred:

```
cap-cell(process-data) contains ReadCap because:
  └─ call-edge propagator from cap-cell(read-file)
     └─ read-file spec declares {fs :0 ReadCap}
        └─ foreign import racket::open-input-file requires ReadCap
```

This is the **capability audit trail** — answering "why does this function need filesystem access?" by tracing the derivation tree. The ATMS provides this for free when the network is constructed with ATMS-backed cells. This directly realizes the "compiler as capability auditor" vision from §2.3.

#### Separate Networks, Cross-Domain Communication

The capability inference network is **separate** from the type inference network:

- **Different lattice domains**: Type inference cells hold metavariable solutions (types); capability cells hold `PowerSet(CapabilityType)`.
- **Different lifecycles**: Type inference runs during elaboration (per-function); capability inference runs post-elaboration (whole-module).
- **Different monotonicity guarantees**: Type inference can backtrack (speculative checking); capability inference is purely monotonic (no backtracking needed).

When the two networks need to communicate — e.g., capability inference needs type information to resolve which branch of a union type is relevant, or type inference needs capability information to resolve ambiguous overloads — **cross-domain propagators** via Galois connections (Phase 6c infrastructure: `net-add-cross-domain-propagator`) provide the bridge. Information discovered in one domain flows into the other through well-defined abstraction/concretization functions.

This architecture scales to additional analysis domains (abstract interpretation, property inference) as separate networks that interoperate through the same Galois connection mechanism.

<a id="47-authority-root"></a>

### 4.7 The Authority Root

Every capability chain starts at the authority root. In Prologos:

```prologos
;; main is the authority root — capabilities are granted by the runtime
defn main {sys :0 SysCap}
  ...
```

The authority root is the ONLY place where capabilities are "minted from nothing." In seL4 terms, this is the initial thread receiving capabilities from the kernel at boot time. In E terms, this is the powerbox. In WASI terms, these are the pre-opened file descriptors.

#### Foreign Functions as Capability Leaves

Foreign function declarations are the "leaves" of the capability tree — the points where capabilities connect to actual host operations:

```prologos
;; Foreign imports require capability annotations
foreign racket "racket/base" {fs :0 ReadCap}
  [racket-open-input : String -> Handle]

foreign racket "racket/base" {fs :0 WriteCap}
  [racket-open-output : String -> Handle]

foreign racket "racket/base" {net :0 HttpCap}
  [racket-http-get : String -> String]
```

The capability annotation on `foreign` ensures that importing a host I/O function inherits the appropriate capability requirement. A module that imports `racket-open-input` automatically requires `{ReadCap}` — the capability flows upward through inference.

#### The REPL

The REPL operates as a "super-main" with `{SysCap}` — full authority. This is pragmatic: interactive development shouldn't be gated by capability requirements. The security boundary is at `main` in compiled programs, not at the REPL.

<a id="48-dependent"></a>

### 4.8 Dependent Capabilities

Dependent types enable resource-specific capabilities — a capability that authorizes access to a *specific* resource, not just a *class* of resources:

```prologos
;; A capability indexed by the path it authorizes
capability FileCap (p : Path)

;; read-file with path-specific capability
spec read-file-dep : {p : Path} -> FileCap p :1 -> Result String IOError

;; Only works with a capability for THAT EXACT file
defn main {sys :0 SysCap}
  let cap := [mint-file-cap sys [path "/data/input.csv"]]
  [read-file-dep cap]   ;; ✓ — cap authorizes /data/input.csv
  ;; [read-file-dep cap2] where cap2 : FileCap (path "/etc/passwd")
  ;; would be a TYPE ERROR — wrong path
```

This is seL4's badge model expressed in the type system. The dependent index `p : Path` serves the same purpose as seL4's badge — distinguishing which specific resource a capability authorizes.

#### When to Use Dependent Capabilities

Dependent capabilities are the **richest tier** of the capability system. They should be used when:
- Fine-grained access control matters (multi-tenant systems, sandboxed plugins)
- The security policy needs to distinguish specific resources (specific files, specific database tables, specific API endpoints)
- Formal verification of authority confinement is needed

For most programs, non-dependent capabilities (`{ReadCap}`, `{HttpCap}`) are sufficient. Dependent capabilities are available for programs that need them — progressive disclosure.

<a id="49-w-warning"></a>

### 4.9 The `:w` Warning Mechanism

The compiler warns when a capability constraint uses `:w` (unrestricted):

```prologos
;; This triggers a warning:
spec bad-example {fs :w FsCap} : Unit -> Unit
;; WARNING: Unrestricted capability `:w` on `FsCap` — consider `:0`
;;   (authority proof) or `:1` (authority transfer).

;; This is fine — `:0` is the default for capabilities:
spec good-example {fs :0 FsCap} : Path -> Result String IOError

;; This is also fine — explicit `:1` for transfer:
spec delegate {fs :1 FsCap} : Process -> Unit

;; This is fine — `:w` on a TRAIT (not a capability) is normal:
spec show {Eq A} : A -> String    ;; {Eq A} is :w by default, no warning
```

#### Implementation

The warning is emitted in `qtt.rkt` during multiplicity checking:

```
;; Pseudocode for the warning check
(when (and (capability-type? constraint-type)
           (eq? multiplicity 'mw))
  (emit-warning
    (format "Unrestricted capability `:w` on `~a` — consider `:0` (authority proof) or `:1` (authority transfer)."
            constraint-type)))
```

The check is simple because it keys off the capability registry ([§4.2](#42-kind-marker)).

<a id="410-sessions"></a>

### 4.10 Session Types as Capability Protocols

Session types govern how capabilities are delegated between processes:

```prologos
;; A session type for requesting filesystem access
session FileAccessProtocol
  !Request Path                                    ;; client sends path
  ?Response (Result (FileCap p :1) DenyReason)     ;; server grants or denies
  +{ use : !Done . end                             ;; client uses and signals done
   , release : end                                 ;; or releases immediately
   }
```

This verifies at compile time:
- The client requests before receiving a capability
- The server responds with a linear capability (`:1` — exactly one grant)
- The client either uses the capability and signals completion, or releases it
- The protocol terminates (no leaked capabilities)

**The fusion of session types and capability types** is where Prologos offers something no other language does: compile-time verification of distributed authority delegation protocols.

This is Agoric's CapTP (Capability Transfer Protocol) formalized in the type system. Where CapTP relies on runtime protocol enforcement, Prologos session types provide static guarantees.

<a id="411-revocation"></a>

### 4.11 Revocation

Revocation — invalidating a previously granted capability — is one of the hardest problems in capability security.

#### seL4's Approach: CDT-based Hierarchical Revocation

In seL4, revoking a capability invalidates all capabilities derived from it (children in the CDT). This requires a global kernel data structure tracking derivation.

#### E's Approach: Membrane-based Revocation

In E, a membrane wraps an object graph. Revoking the membrane invalidates all cross-membrane references. This requires a runtime proxy layer.

#### Prologos's Approach: Linear Scope as Revocation Boundary

Linear types provide a natural revocation mechanism:

```prologos
;; Parent grants a capability to a child scope
defn with-limited-fs [action]
  let cap :1 := [mint-read-cap sys [path "/data"]]
  let result := [action cap]   ;; cap is consumed — child can't keep it
  result                       ;; after this line, cap no longer exists

;; The child function receives cap :1 — it MUST consume it
;; After the scope exits, the capability is gone
;; This is revocation by scope exit
```

When a `:1` capability exits its scope, it's consumed. No CDT or membrane needed — the type system ensures the capability doesn't outlive its intended scope.

For more complex revocation (revoking a capability that was shared via `:w`, or revoking a capability held by a remote process via session types), the design needs further work. This is deferred to the session types design phase.

**Revocation hierarchy**:
- **Scope-based revocation** (`:1` consumption) — available now via QTT
- **Protocol-based revocation** (session type `?Revoke`) — requires session types design
- **Hierarchical revocation** (CDT-style, all descendants) — a future research direction

<a id="412-testing"></a>

### 4.12 Testing Capabilities

Capabilities compose naturally with testing:

```prologos
;; In production: main grants real capabilities
defn main {sys :0 SysCap}
  [app sys]

;; In tests: grant only the capabilities the test needs
defn test-read-file
  let mock-fs :0 := [mock-read-cap]       ;; a test-only mock capability
  let result := [read-file mock-fs [path "/test/data.csv"]]
  [assert-ok result]

;; In tests: verify that pure code requires NO capabilities
defn test-transform
  ;; No capability parameters — transform is pure
  let result := [transform test-data]
  [assert-eq result expected]
```

The key property: **testing pure code requires no capability mocking.** The type system guarantees that `transform` performs no I/O — it has no capability parameters. Only functions with capability requirements need capability injection in tests.

This is a major ergonomic advantage over effect systems, where even testing pure code may require effect handlers.

---

<a id="5-types"></a>

## 5. Concrete Type Designs

<a id="51-hierarchy"></a>

### 5.1 Standard Capability Hierarchy

```
SysCap
├── FsCap = ReadCap | WriteCap
├── NetCap = HttpCap | WsCap
├── DbCap
├── SpawnCap
└── ClockCap
```

```prologos
;; Leaf capabilities (finest grain)
capability ReadCap
capability WriteCap
capability HttpCap
capability WsCap
capability DbCap
capability SpawnCap
capability ClockCap

;; Composite capabilities (union types)
type FsCap  := ReadCap | WriteCap
type NetCap := HttpCap | WsCap
type SysCap := FsCap | NetCap | DbCap | SpawnCap | ClockCap

;; Subtype registrations (for attenuation resolution)
;; Infix `<:` is syntactic sugar for `subtype`: `A <: B` desugars to `($subtype A B)`
ReadCap  <: FsCap
WriteCap <: FsCap
HttpCap  <: NetCap
WsCap    <: NetCap
FsCap    <: SysCap
NetCap   <: SysCap
DbCap    <: SysCap
SpawnCap <: SysCap
ClockCap <: SysCap
;; Transitive (chained): ReadCap <: FsCap <: SysCap
```

This hierarchy is **open for extension** — users can define their own capability types:

```prologos
;; User-defined capabilities
capability EmailCap           ;; authority to send emails
capability PaymentCap         ;; authority to process payments
capability AuditCap           ;; authority to write audit logs

type BusinessCap := EmailCap | PaymentCap | AuditCap
```

<a id="52-fs-example"></a>

### 5.2 Example: Filesystem Capabilities for I/O Library

This example shows how the capability system integrates with the I/O library design:

```prologos
;; Low-level operations (leaf functions with declared capabilities)
spec open-read  {fs :0 ReadCap}  : Path -> Result Handle IOError
spec open-write {fs :0 WriteCap} : Path -> Result Handle IOError
spec close!     : Handle :1 -> Unit
spec read-all   {fs :0 ReadCap}  : Handle :1 -> <Handle :1 * String>
spec write-str  {fs :0 WriteCap} : Handle :1 -> String -> <Handle :1 * Unit>

;; Convenience functions (capabilities inferred from body)
spec read-file  : Path -> Result String IOError
;; Compiler infers: {fs :0 ReadCap} from calling open-read + read-all
defn read-file [p]
  match [open-read p]
    | [ok h]  -> let (h content) := [read-all h]
                 let _ := [close! h]
                 [ok content]
    | [err e] -> [err e]

spec write-file : Path -> String -> Result Unit IOError
;; Compiler infers: {fs :0 WriteCap} from calling open-write + write-str
defn write-file [p content]
  match [open-write p]
    | [ok h]  -> let (h _) := [write-str h content]
                 let _ := [close! h]
                 [ok unit]
    | [err e] -> [err e]
```

Note: the `World` token from the I/O design doc is **replaced** by the capability constraints. Instead of threading `World :1` through every I/O function, we use `{fs :0 ReadCap}` or `{fs :0 WriteCap}`. The capability is erased at `:0` — zero runtime cost.

<a id="53-net-example"></a>

### 5.3 Example: Network Capabilities

```prologos
spec http-get  {net :0 HttpCap} : URL -> Result String NetError
spec http-post {net :0 HttpCap} : URL -> String -> Result String NetError
spec ws-connect {net :0 WsCap}  : URL -> Result WsHandle NetError

;; A function that uses both fs and net:
spec sync-to-server : Path -> URL -> Result Unit SyncError
;; Inferred: {fs :0 ReadCap, net :0 HttpCap}
defn sync-to-server [local-path server-url]
  match [read-file local-path]
    | [ok data]  -> match [http-post server-url data]
                      | [ok _]   -> [ok unit]
                      | [err e]  -> [err [net-error e]]
    | [err e]    -> [err [fs-error e]]
```

The compiler computes: `sync-to-server` requires `{ReadCap, HttpCap}`. A caller with `{SysCap}` can call it (via `SysCap >: FsCap >: ReadCap` and `SysCap >: NetCap >: HttpCap`).

<a id="54-dependent-example"></a>

### 5.4 Example: Dependent Path Capability

```prologos
;; Dependent capability: authority for a specific path
capability FileCap (p : Path)

;; Mint a path-specific capability from a broader one
spec mint-file-cap {fs :0 FsCap} : (p : Path) -> FileCap p

;; Read using a path-specific capability
spec read-file-dep : {p : Path} -> FileCap p :1 -> Result String IOError

;; Usage:
defn process-data {fs :0 FsCap} [p : Path]
  let cap := [mint-file-cap p]         ;; FileCap p, minted from FsCap
  match [read-file-dep cap]           ;; cap consumed (linear)
    | [ok data]  -> [transform data]
    | [err e]    -> [handle-error e]
```

This is the highest tier of capability security. The type `FileCap (path "/data/input.csv")` authorizes access to EXACTLY that file. Attempting to use it for a different file is a type error.

---

<a id="6-io-relationship"></a>

## 6. Relationship to I/O Library Design

This document **supersedes** the I/O Library Design's Decision 1 (World token approach). The mapping:

| I/O Design (Old) | This Design (New) |
|-------------------|-------------------|
| `World :1` token threaded through | `{ReadCap}` / `{WriteCap}` as erased implicit params |
| Single `World` type | Fine-grained `FsCap`, `NetCap`, `DbCap`, etc. |
| Mercury-style `!IO` sugar | Not needed — capabilities are erased at `:0` |
| `open : Path -> Mode -> <Handle :1 * World>` | `open-read {fs :0 ReadCap} : Path -> Result Handle IOError` |
| `read-file : World :1 -> String -> <World * Result>` | `read-file {fs :0 ReadCap} : Path -> Result String IOError` |

The key improvements:
1. **No threading**: Capabilities at `:0` are erased — no runtime parameter to thread
2. **Fine-grained**: `{ReadCap}` vs `{WriteCap}` instead of a single opaque `World`
3. **Compositional**: Functions requiring only `{ReadCap}` can be called from contexts with `{FsCap}` or `{SysCap}` without conversion
4. **No `!IO` sugar needed**: The entire `!IO` notation and handle-threading verbosity problem disappears when capabilities are erased implicit parameters

The I/O Library Design's other decisions remain valid:
- Decision 2 (`with-open` macro pattern) — still applicable
- Decision 3 (Data out, not streams) — unchanged
- Decision 4 (Schema validation at boundary) — unchanged
- Decision 5 (Relational language integration) — unchanged

---

<a id="7-roadmap"></a>

## 7. Phased Implementation Roadmap

### Phase 1: Capability Declaration and Kind Marker

**Goal**: The compiler can distinguish capability types from regular traits.

- **1a**: `capability` keyword as first-class top-level form (own AST struct, not desugaring to `trait`)
- **1b**: Capability registry in compiler state (`current-capability-types`)
- **1c**: Registration of `capability` declarations in the registry during elaboration
- **1d**: Tests — capability types are registered; regular traits are not

**Depends on**: Nothing. Can start immediately.
**Estimated scope**: ~3 new AST nodes, ~6 files in pipeline, ~10 tests.

### Phase 2: Multiplicity Defaulting and `:w` Warning

**Goal**: Capability constraints default to `:0` and warn on `:w`.

- **2a**: Default capability constraints to `:0` in `elaborator.rkt` (or wherever implicit argument multiplicities are assigned)
- **2b**: `:w` warning emission in `qtt.rkt` for capability-typed constraints
- **2c**: Tests — capability constraints at `:0` (default), `:1` (explicit), `:w` (warns)

**Depends on**: Phase 1 (capability registry).
**Estimated scope**: ~50 lines in `elaborator.rkt`, ~30 lines in `qtt.rkt`, ~15 tests.

### Phase 3: Infix `<:` Subtyping Syntax + Standard Capability Hierarchy

**Goal**: Infix `<:` for readable subtype declarations. Define the standard capability types and their subtype relationships.

- **3a**: `<:` infix operator in WS reader, desugaring to `($subtype A B)`. Chained form `A <: B <: C` desugars to `($subtype A B) ($subtype B C)`.
- **3b**: Leaf capability declarations (`ReadCap`, `WriteCap`, `HttpCap`, etc.)
- **3c**: Composite capabilities as union types (`FsCap := ReadCap | WriteCap`, etc.)
- **3d**: Subtype registrations using `<:` syntax (`ReadCap <: FsCap`, etc.)
- **3e**: Library file: `lib/prologos/core/capabilities.prologos`
- **3f**: Tests — `<:` parsing, subtype resolution, union subsumption, transitive closure

**Depends on**: Phase 1. Phase 2 (for correct multiplicity defaulting).
**Estimated scope**: ~30 lines reader change for `<:`, ~1 new `.prologos` file, ~25 tests.

### Phase 4: Lexical Capability Resolution

**Goal**: Capability constraints resolve from the lexical scope, not the global trait registry.

- **4a**: Separate resolution path in `typing-core.rkt` for capability constraints
- **4b**: Search function parameters for matching capability types
- **4c**: Subtype-aware resolution (a parameter of type `FsCap` satisfies a `ReadCap` requirement)
- **4d**: Error messages for missing capabilities ("Required capability `ReadCap` not available in scope")
- **4e**: Tests — resolution from parameters, subtype resolution, missing capability errors

**Depends on**: Phase 1, Phase 3 (for subtype relationships).
**Estimated scope**: ~150 lines in `typing-core.rkt`, ~30 tests. This is the most significant implementation phase.

### Phase 5: Capability Inference via Propagator Network

**Goal**: The compiler infers capability requirements from function bodies using the Logic Engine's propagator network, with ATMS provenance for capability auditing.

- **5a**: Create `CapabilitySet` lattice type — `PowerSet(CapabilityType)` with join = set-union, bot = `{}`. Implement `Lattice` trait for it (or leverage existing `SetLattice` infrastructure).
- **5b**: Build capability inference network post-type-checking: one cell per function in the module, initialized to `{}`. Seed leaf cells from declared spec capabilities.
- **5c**: Wire call-edge propagators: for each call `f → g`, add propagator that unions `cap-cell(g)` into `cap-cell(f)`.
- **5d**: `run-to-quiescence` computes capability closures for all functions simultaneously.
- **5e**: Thread ATMS through the network — each capability in each cell's closure carries a derivation tree. Implement `:capability-audit` REPL command that traces "why does f require ReadCap?" via ATMS dependency traversal.
- **5f**: Verify authority roots: check that `main`'s explicit capability set subsumes its inferred closure. Emit capability-specific error messages (E-codes) for uncovered requirements, with ATMS-derived "because" chains.
- **5g**: Display capability closures on request (REPL command `:cap-closure f`).
- **5h**: Tests — inferred capabilities match expected, pure functions have empty closures, ATMS provenance traces correct, mutual recursion converges, `:w` warned capabilities propagate correctly.

**Depends on**: Phase 4 (lexical resolution must work before inference can propagate). Propagator network infrastructure (complete). ATMS infrastructure (complete).
**Estimated scope**: ~300 lines (network construction + CapabilitySet lattice + REPL commands), ~35 tests.
**Design principle**: Completeness Now — build ATMS provenance from the start rather than adding it later. The "why does f require ReadCap?" query is a core part of the capability auditing story and must be available from Phase 5 onward.

### Phase 6: Foreign Function Capability Gating

**Goal**: Foreign function imports declare capability requirements.

- **6a**: Syntax for capability annotations on `foreign` blocks
- **6b**: Elaboration of foreign capability requirements
- **6c**: Integration with capability inference (foreign imports are leaves of the capability tree)
- **6d**: Tests — foreign imports with/without capabilities, inference from foreign calls

**Depends on**: Phase 5 (inference propagates foreign requirements upward).
**Estimated scope**: ~100 lines in `foreign.rkt` + elaborator, ~15 tests.

### Phase 7: Dependent Capabilities (Future)

**Goal**: Capabilities indexed by specific resources.

- **7a**: `capability FileCap (p : Path)` — parameterized capability declaration
- **7b**: Minting dependent capabilities from broader ones
- **7c**: Dependent resolution (matching path indices)
- **7d**: Tests — path-specific capabilities, type errors on path mismatch

**Depends on**: Phase 4-6 stable. May require extensions to the dependent type infrastructure.
**Estimated scope**: ~200 lines, ~20 tests. Research needed on interaction with elaborator.

### Phase 8: Cross-Network Interfacing (Future)

**Goal**: Enable the capability inference network to communicate with the type inference network (and future analysis networks) via Galois connections.

- **8a**: Define the abstraction/concretization functions between the type inference lattice domain and the `CapabilitySet` lattice domain — e.g., abstracting a union type `ReadCap | WriteCap` into `{ReadCap, WriteCap}` in the capability domain.
- **8b**: Wire cross-domain propagators via `net-add-cross-domain-propagator` (Phase 6c infrastructure) so that type-level discoveries (e.g., narrowing a union branch) inform capability inference, and capability requirements inform type resolution when ambiguous.
- **8c**: Tests — cross-network information flow, bidirectional propagation, fixed-point convergence across networks.
- **8d**: Investigate multi-agent scenario: separate agents operating on separate propagator networks (each carrying dependent-typed proof objects as provenance) cross-referencing via cross-network propagators. This would enable collaborative reasoning with machine-checkable justification chains across network boundaries.

**Depends on**: Phase 5 (capability inference network operational). Galois connection infrastructure (Phase 6c, complete).
**Estimated scope**: Research-heavy. ~150 lines for cross-domain propagator wiring, ~20 tests. Multi-agent scenario (8d) is exploratory.

### Phase 9: Session Types for Capability Protocols (Future)

**Goal**: Compile-time verification of capability delegation protocols.

- **9a**: Session types that carry capability types as payloads
- **9b**: Linear capability transfer within session communication
- **9c**: Revocation as a session protocol state

**Depends on**: Session types design (separate document). Phase 4-5.

---

<a id="8-open-questions"></a>

## 8. Open Questions for Design Discussion

### Q1: Should `capability` be a keyword or a trait annotation? — **RESOLVED**

**Decision**: `capability` is a **first-class top-level form** with its own AST struct (Option A). It does NOT desugar to `trait`. Rationale:
- Different resolution semantics (lexical, not global registry)
- Different QTT defaults (`:0` by default, not `:w`)
- Different extension paths (dependent capabilities, not trait instances)
- Clear syntactic signal of intent — as fundamental as `trait`, `schema`, or `session`

### Q2: Module-level capability declarations?

Should modules be able to declare their capability requirements explicitly (like Austral's module-level declarations)?

```prologos
;; Option: module-level capability declaration
ns my-module
  :capabilities [ReadCap WriteCap]
```

- Pro: Makes capability requirements visible at the module level
- Con: Redundant if capability inference works well — the inferred closure IS the module's requirements

**Recommendation**: Defer. Let capability inference compute module closures. If users want explicit module-level declarations, add them as documentation/assertions later.

### Q3: Capability parametricity?

Should functions be polymorphic over capabilities?

```prologos
;; Capability-polymorphic function
spec with-cap {C : Capability} : C :1 -> (C :1 -> A) -> A
defn with-cap [cap action]
  [action cap]
```

This requires capabilities to form a kind (`Capability : Kind`), not just be marked types.

**Recommendation**: Interesting but deferred. The current design (capabilities as marked traits) is simpler and sufficient for Phase 1-6.

### Q4: Capability delegation vs. capability passing?

When a function calls another function that requires a capability, should this be:

**Option A**: Implicit delegation (the compiler propagates the caller's capability to the callee)
**Option B**: Explicit passing (the caller must name the capability in the call)

```prologos
;; Option A: implicit
defn process [p]
  [read-file p]    ;; compiler resolves ReadCap from caller's scope

;; Option B: explicit
defn process [p]
  [read-file @ReadCap p]    ;; explicit capability argument
```

**Recommendation**: Option A (implicit delegation) for `:0` capabilities (the common case — erased proofs). Option B (explicit passing) for `:1` capabilities (linear transfer — the caller needs to know their capability is being consumed).

### Q5: Interaction with the macro system?

Macros like `with-open` and `with-transient` expand into code that may require capabilities. Should macro expansion site inherit the enclosing scope's capabilities?

**Recommendation**: Yes. Macro expansion happens before capability inference. The expanded code is analyzed like any other code — its capability requirements propagate normally through inference. No special mechanism needed.

### Q6: How do capability unions interact with pattern matching?

If `FsCap = ReadCap | WriteCap`, can you pattern match on a capability to determine which sub-capability you have?

```prologos
defn check-cap [cap : FsCap]
  match cap
    | ReadCap  -> "read only"
    | WriteCap -> "write only"
```

**Recommendation**: No. Capabilities at `:0` don't exist at runtime — there's nothing to match on. At `:1`, the question is interesting but dangerous (it leaks information about which authority was granted). Defer this question.

---

<a id="9-references"></a>

## 9. References

### Foundational
- Dennis, J. B. & Van Horn, E. C. (1966). "Programming Semantics for Multiprogrammed Computations." *Communications of the ACM*.
- Miller, M. (2006). "Robust Composition: Towards a Unified Approach to Access Control and Concurrency Control." PhD Thesis, Johns Hopkins University.
- Miller, M., Morningstar, C., & Frantz, B. (2000). "Capability-based Financial Instruments." *Proc. Financial Cryptography*.

### Operating Systems
- Klein, G. et al. (2009). "seL4: Formal Verification of an OS Kernel." *SOSP*.
- seL4 Reference Manual. https://sel4.systems/Info/Docs/seL4-manual-latest.pdf
- Fuchsia Component Framework. https://fuchsia.dev/fuchsia-src/concepts/components/v2
- Zircon Handles and Rights. https://fuchsia.dev/fuchsia-src/concepts/kernel/handles

### Capability Calculi
- Crary, K. & Morrisett, G. (1999). "Type Structure for Low-Level Programming Languages." *ICALP*.

### Languages and Type Systems
- Brady, E. (2021). "Idris 2: Quantitative Type Theory in Practice." *ECOOP*.
- Clebsch, S. et al. (2015). "Deny Capabilities for Safe, Fast Actors." *AGERE*.
- Orchard, D. et al. (2019). "Quantitative Program Reasoning with Graded Modal Types." *ICFP* (Granule).
- Austral Language Specification. https://austral-lang.org/

### Patterns and Practice
- Miller, M. & Shapiro, J. (2003). "Paradigm Regained: Abstraction Mechanisms for Access Control." *ASIAN*.
- WASI Specification. https://github.com/WebAssembly/WASI
- Agoric / CapTP. https://agoric.com/

### Prologos Internal
- `docs/tracking/principles/CAPABILITY_SECURITY.md` — Principles document
- `docs/tracking/principles/DESIGN_PRINCIPLES.md` — Core values and design principles
- `docs/tracking/principles/LANGUAGE_VISION.md` — Language vision ("5th correctness problem")
- `docs/tracking/2026-03-01_1200_IO_LIBRARY_DESIGN.md` — I/O library design (superseded on capability model)
- `docs/tracking/2026-02-27_1400_REFINED_NUMERIC_SUBTYPING.md` — Subtype infrastructure used for attenuation
