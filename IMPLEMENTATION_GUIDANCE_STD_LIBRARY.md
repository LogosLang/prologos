# Implementation Guidance: Πρόλογος Standard Library

## A Phased, Dependency-Ordered Blueprint for Building a De-Novo Standard Library for a Dependently-Typed Functional-Logic Language

---

## Table of Contents

1. [Introduction and Design Philosophy](#1-introduction-and-design-philosophy)
   - 1.1 [Purpose of This Document](#11-purpose-of-this-document)
   - 1.2 [Design Principles from the Language Survey](#12-design-principles-from-the-language-survey)
   - 1.3 [The Πρόλογος Standard Library Vision](#13-the-prologos-standard-library-vision)
   - 1.4 [What Belongs in Stdlib vs. Ecosystem](#14-what-belongs-in-stdlib-vs-ecosystem)
2. [Survey of Standard Library Designs](#2-survey-of-standard-library-designs)
   - 2.1 [Java: The Cautionary Kitchen Sink](#21-java-the-cautionary-kitchen-sink)
   - 2.2 [Go: Batteries Included, Minimally](#22-go-batteries-included-minimally)
   - 2.3 [Rust: Three-Tier Layering and Trait-Based Design](#23-rust-three-tier-layering-and-trait-based-design)
   - 2.4 [Pony: Capabilities and Actor-Based I/O](#24-pony-capabilities-and-actor-based-io)
   - 2.5 [Idris 2: Dependent Types and QTT in the Library](#25-idris-2-dependent-types-and-qtt-in-the-library)
   - 2.6 [Clojure: Immutability, Sequences, and the Hosted Model](#26-clojure-immutability-sequences-and-the-hosted-model)
   - 2.7 [Haskell: Type Classes and the Batteries Problem](#27-haskell-type-classes-and-the-batteries-problem)
   - 2.8 [Erlang/OTP: Processes, Behaviours, and Supervision](#28-erlangotp-processes-behaviours-and-supervision)
   - 2.9 [Mercury and SWI-Prolog: Logic Language Standard Libraries](#29-mercury-and-swi-prolog-logic-language-standard-libraries)
   - 2.10 [Lean 4: Proof-Carrying Data Structures](#210-lean-4-proof-carrying-data-structures)
3. [Synthesis: Lessons and Anti-Patterns](#3-synthesis-lessons-and-anti-patterns)
   - 3.1 [Twelve Principles for the Πρόλογος Standard Library](#31-twelve-principles-for-the-prologos-standard-library)
   - 3.2 [Anti-Patterns to Avoid](#32-anti-patterns-to-avoid)
4. [Dependency Graph and Module Taxonomy](#4-dependency-graph-and-module-taxonomy)
   - 4.1 [The Πρόλογος Standard Library Module Map](#41-the-prologos-standard-library-module-map)
   - 4.2 [Dependency DAG](#42-dependency-dag)
   - 4.3 [The Three-Layer Architecture](#43-the-three-layer-architecture)
5. [Phase 0: Bootstrap Foundations (Weeks 1–6)](#5-phase-0-bootstrap-foundations-weeks-16)
   - 5.1 [Sprint 0.1: Primitive Types and Arithmetic (Weeks 1–2)](#51-sprint-01-primitive-types-and-arithmetic-weeks-12)
   - 5.2 [Sprint 0.2: Core Traits and Type Classes (Weeks 3–4)](#52-sprint-02-core-traits-and-type-classes-weeks-34)
   - 5.3 [Sprint 0.3: Option, Result, and Error Foundation (Weeks 5–6)](#53-sprint-03-option-result-and-error-foundation-weeks-56)
6. [Phase 1: Core Data Structures (Weeks 7–18)](#6-phase-1-core-data-structures-weeks-718)
   - 6.1 [Sprint 1.1: List and Lazy Sequences (Weeks 7–9)](#61-sprint-11-list-and-lazy-sequences-weeks-79)
   - 6.2 [Sprint 1.2: Length-Indexed Vectors (Weeks 10–11)](#62-sprint-12-length-indexed-vectors-weeks-1011)
   - 6.3 [Sprint 1.3: HAMT-Based Persistent Map and Set (Weeks 12–14)](#63-sprint-13-hamt-based-persistent-map-and-set-weeks-1214)
   - 6.4 [Sprint 1.4: Sorted Map/Set, Deque, Heap (Weeks 15–16)](#64-sprint-14-sorted-mapset-deque-heap-weeks-1516)
   - 6.5 [Sprint 1.5: Iterator and Transducer Framework (Weeks 17–18)](#65-sprint-15-iterator-and-transducer-framework-weeks-1718)
7. [Phase 2: String and Text Processing (Weeks 19–24)](#7-phase-2-string-and-text-processing-weeks-1924)
   - 7.1 [Sprint 2.1: UTF-8 String and Rope Types (Weeks 19–21)](#71-sprint-21-utf-8-string-and-rope-types-weeks-1921)
   - 7.2 [Sprint 2.2: String Formatting and Display Traits (Weeks 22–23)](#72-sprint-22-string-formatting-and-display-traits-weeks-2223)
   - 7.3 [Sprint 2.3: Regular Expressions (Week 24)](#73-sprint-23-regular-expressions-week-24)
8. [Phase 3: I/O, File System, and Resources (Weeks 25–33)](#8-phase-3-io-file-system-and-resources-weeks-2533)
   - 8.1 [Sprint 3.1: Linear I/O Foundation (Weeks 25–27)](#81-sprint-31-linear-io-foundation-weeks-2527)
   - 8.2 [Sprint 3.2: File System Operations (Weeks 28–30)](#82-sprint-32-file-system-operations-weeks-2830)
   - 8.3 [Sprint 3.3: Buffered and Streaming I/O (Weeks 31–33)](#83-sprint-33-buffered-and-streaming-io-weeks-3133)
9. [Phase 4: Concurrency and Actor Runtime (Weeks 34–48)](#9-phase-4-concurrency-and-actor-runtime-weeks-3448)
   - 9.1 [Sprint 4.1: Actor Primitives and Mailboxes (Weeks 34–36)](#91-sprint-41-actor-primitives-and-mailboxes-weeks-3436)
   - 9.2 [Sprint 4.2: Supervision Trees (Weeks 37–39)](#92-sprint-42-supervision-trees-weeks-3739)
   - 9.3 [Sprint 4.3: Session-Typed Channels (Weeks 40–42)](#93-sprint-43-session-typed-channels-weeks-4042)
   - 9.4 [Sprint 4.4: Structured Concurrency and Task Groups (Weeks 43–45)](#94-sprint-44-structured-concurrency-and-task-groups-weeks-4345)
   - 9.5 [Sprint 4.5: Parallel Iterators and Auto-Parallelization (Weeks 46–48)](#95-sprint-45-parallel-iterators-and-auto-parallelization-weeks-4648)
10. [Phase 5: Propagator Networks (Weeks 49–57)](#10-phase-5-propagator-networks-weeks-4957)
    - 10.1 [Sprint 5.1: Cells, Propagators, and Scheduler (Weeks 49–51)](#101-sprint-51-cells-propagators-and-scheduler-weeks-4951)
    - 10.2 [Sprint 5.2: Lattice Library and Merge Operations (Weeks 52–54)](#102-sprint-52-lattice-library-and-merge-operations-weeks-5254)
    - 10.3 [Sprint 5.3: Constraint Solving and Incremental Computation (Weeks 55–57)](#103-sprint-53-constraint-solving-and-incremental-computation-weeks-5557)
11. [Phase 6: Logic Programming Sub-Language (Weeks 58–69)](#11-phase-6-logic-programming-sub-language-weeks-5869)
    - 11.1 [Sprint 6.1: Unification Engine (Weeks 58–60)](#111-sprint-61-unification-engine-weeks-5860)
    - 11.2 [Sprint 6.2: Backtracking, Choice Points, and Search (Weeks 61–63)](#112-sprint-62-backtracking-choice-points-and-search-weeks-6163)
    - 11.3 [Sprint 6.3: Tabling and Datalog (Weeks 64–66)](#113-sprint-63-tabling-and-datalog-weeks-6466)
    - 11.4 [Sprint 6.4: Constraint Logic Programming (Weeks 67–69)](#114-sprint-64-constraint-logic-programming-weeks-6769)
12. [Phase 7: Numerics and Posit Arithmetic (Weeks 70–78)](#12-phase-7-numerics-and-posit-arithmetic-weeks-7078)
    - 12.1 [Sprint 7.1: Arbitrary-Precision Integers (Weeks 70–72)](#121-sprint-71-arbitrary-precision-integers-weeks-7072)
    - 12.2 [Sprint 7.2: Posit Types and Quire Accumulator (Weeks 73–75)](#122-sprint-72-posit-types-and-quire-accumulator-weeks-7375)
    - 12.3 [Sprint 7.3: Numeric Tower and Conversion (Weeks 76–78)](#123-sprint-73-numeric-tower-and-conversion-weeks-7678)
13. [Phase 8: Networking, Serialization, and Time (Weeks 79–90)](#13-phase-8-networking-serialization-and-time-weeks-7990)
    - 13.1 [Sprint 8.1: Actor-Based TCP/UDP (Weeks 79–81)](#131-sprint-81-actor-based-tcpudp-weeks-7981)
    - 13.2 [Sprint 8.2: EDN and JSON Serialization (Weeks 82–84)](#132-sprint-82-edn-and-json-serialization-weeks-8284)
    - 13.3 [Sprint 8.3: Time, Duration, and Clocks (Weeks 85–87)](#133-sprint-83-time-duration-and-clocks-weeks-8587)
    - 13.4 [Sprint 8.4: HTTP Client Foundation (Weeks 88–90)](#134-sprint-84-http-client-foundation-weeks-8890)
14. [Phase 9: Testing, Debugging, and Developer Experience (Weeks 91–102)](#14-phase-9-testing-debugging-and-developer-experience-weeks-91102)
    - 14.1 [Sprint 9.1: Test Framework and Assertions (Weeks 91–93)](#141-sprint-91-test-framework-and-assertions-weeks-9193)
    - 14.2 [Sprint 9.2: Property-Based Testing and Spec (Weeks 94–96)](#142-sprint-92-property-based-testing-and-spec-weeks-9496)
    - 14.3 [Sprint 9.3: Benchmarking and Profiling (Weeks 97–99)](#143-sprint-93-benchmarking-and-profiling-weeks-9799)
    - 14.4 [Sprint 9.4: REPL and Interactive Development (Weeks 100–102)](#144-sprint-94-repl-and-interactive-development-weeks-100102)
15. [Phase 10: FFI, Ecosystem, and Packaging (Weeks 103–111)](#15-phase-10-ffi-ecosystem-and-packaging-weeks-103111)
    - 15.1 [Sprint 10.1: C FFI and Platform Abstraction (Weeks 103–105)](#151-sprint-101-c-ffi-and-platform-abstraction-weeks-103105)
    - 15.2 [Sprint 10.2: Package Manager and Build System (Weeks 106–108)](#152-sprint-102-package-manager-and-build-system-weeks-106108)
    - 15.3 [Sprint 10.3: Documentation Generation (Weeks 109–111)](#153-sprint-103-documentation-generation-weeks-109111)
16. [Cross-Cutting Concerns](#16-cross-cutting-concerns)
    - 16.1 [Error Messages Throughout the Standard Library](#161-error-messages-throughout-the-standard-library)
    - 16.2 [Naming Conventions and API Consistency](#162-naming-conventions-and-api-consistency)
    - 16.3 [Stability Guarantees and Versioning](#163-stability-guarantees-and-versioning)
    - 16.4 [Documentation Standards](#164-documentation-standards)
17. [Concrete Syntax Sketches for Standard Library APIs](#17-concrete-syntax-sketches-for-standard-library-apis)
18. [Compilation Strategy and LLVM Integration](#18-compilation-strategy-and-llvm-integration)
    - 18.1 [Erasure Model for Dependent Types](#181-erasure-model-for-dependent-types)
    - 18.2 [QTT Compilation to LLVM](#182-qtt-compilation-to-llvm)
    - 18.3 [Actor Runtime Code Generation](#183-actor-runtime-code-generation)
    - 18.4 [Propagator Scheduler Compilation](#184-propagator-scheduler-compilation)
    - 18.5 [WAM Integration with LLVM](#185-wam-integration-with-llvm)
19. [Summary: Sprint Calendar and Milestone Map](#19-summary-sprint-calendar-and-milestone-map)
20. [References](#20-references)

---

## 1. Introduction and Design Philosophy

### 1.1 Purpose of This Document

This document provides a comprehensive, phased implementation plan for the Πρόλογος standard library — the set of modules, types, traits, and functions that ship with every Πρόλογος installation and form the foundation upon which all user code and ecosystem libraries are built. The plan is informed by an extensive survey of standard library designs across eleven programming languages — Java, Go, Rust, Pony, Idris 2, Clojure, Haskell, Erlang/OTP, Elixir, OCaml, Lean 4, Mercury, and SWI-Prolog — and by published guidance from Joshua Bloch, Rich Hickey, Rob Pike, the Rust API Guidelines, and the ISO C++ Library Design Guidelines.

Each phase is ordered by dependency: no sprint depends on work from a later phase. Within each phase, sprints are sized for 1–3 weeks of focused implementation by a small team (1–3 developers). The plan is deliberately conservative — it is better to ship a small, correct, well-documented standard library than a large, buggy one. Modules that do not need to be in the standard library are explicitly excluded.

### 1.2 Design Principles from the Language Survey

The survey reveals a striking convergence of principles across successful standard libraries:

**Simplicity over ease** (Hickey). Rich Hickey's distinction between "simple" (one braid, one responsibility) and "easy" (nearby, familiar) is the foundational design principle. Java's `Vector` conflated resizable-array and synchronization — two independent concerns — creating a class that was easy to use initially but permanently complicated the Collections Framework. Clojure's immutable persistent data structures are simple (single-concern: data) even though they require learning a new paradigm.

**Trait-based organization** (Rust, Haskell). Rust's standard library is organized around traits — `Iterator`, `Read`, `Write`, `Display`, `From`/`Into` — not around types. Haskell's type class hierarchy (`Functor → Applicative → Monad`, `Semigroup → Monoid`) defines the algebraic structure of the library. This approach enables composition: any type that implements `Iterator` can use `map`, `filter`, `fold` without the library knowing anything about the type.

**Layered architecture** (Rust, Erlang/OTP). Rust's three-tier split — `core` (no heap, no OS), `alloc` (heap, no OS), `std` (full OS) — allows the same language to target bare-metal, embedded, and desktop environments. Erlang/OTP's Kernel → Stdlib → SASL layering separates the minimal runtime from the standard library from hot-code-loading tools.

**Capabilities shape the API** (Pony). In Pony, every collection method must account for the six reference capabilities (`iso`, `val`, `ref`, `box`, `trn`, `tag`). The type system does not let you accidentally share mutable state between actors. For Πρόλογος, QTT multiplicities play the analogous role: the standard library API must be quantity-polymorphic where possible, distinguishing 0-multiplicity (erased), 1-multiplicity (linear), and ω-multiplicity (unrestricted) parameters.

**Actor-based I/O** (Pony, Erlang). Pony's TCP/UDP primitives are actors, not objects — `TCPListener`, `TCPConnection`, and `UDPSocket` communicate through messages, never blocking the caller. Erlang's entire I/O system is process-based. For Πρόλογος, I/O should follow this model: all I/O operations are actor behaviours, and blocking is impossible at the language level.

**Dependent types in the library** (Idris 2, Lean 4). Idris 2's `Data.Vect` carries its length in the type: `Vect n a`. Lean 4's `Fin n` ensures array indices are in-bounds at compile time. `Decidable.Equality` in Idris 2 returns evidence — either a proof of equality or a proof of inequality. For Πρόλογος, dependent types should permeate the standard library, not be an optional feature layered on top.

**Immutability as default** (Clojure, Haskell). Clojure's persistent data structures use Hash Array Mapped Tries (HAMTs) with structural sharing, achieving effective O(1) operations while being immutable. Haskell's purity enforces immutability at the language level. The NOTES.org desideratum — "Immutable datastructures with structural sharing, like in Clojure" — mandates this approach for Πρόλογος.

**Explicit error handling** (Rust, Go). Rust's `Result<T, E>` and the `?` operator make error propagation explicit without exceptions. Go's `if err != nil` pattern (though verbose) prevents hidden control flow. For Πρόλογος, a dependently-typed `Result` with rich error context is the primary error-handling mechanism.

### 1.3 The Πρόλογος Standard Library Vision

The Πρόλογος standard library occupies a unique design space — it must simultaneously serve as:

**A dependently-typed functional library** where types carry proofs, vectors know their length, and erased bindings have zero runtime cost.

**A logic programming runtime** where unification, backtracking, clause selection, and constraint solving are first-class operations available to every program.

**A propagator network substrate** where cells, propagators, and schedulers are standard library types, not framework-level abstractions.

**An actor-based concurrent runtime** where every I/O operation is a message, supervision trees manage failure, and session types guarantee protocol correctness.

**A posit arithmetic library** where Posit32 is as natural to use as Float64, quire accumulators enable exact dot products, and the numeric tower respects arbitrary precision.

No existing standard library serves all five roles. The closest analogies are Erlang/OTP (actors + behaviours), Idris 2 (dependent types + linear I/O), and Clojure (immutable data + logic via core.logic) — but none unifies all five. This is both the challenge and the opportunity.

### 1.4 What Belongs in Stdlib vs. Ecosystem

The survey reveals a consistent heuristic: include in stdlib only what is **fundamental** (many libraries depend on it), **stable** (not evolving rapidly), and **universal** (nearly every program needs it). The following table applies this heuristic to Πρόλογος:

| In Standard Library | In Ecosystem |
|---|---|
| Primitive types, arithmetic, numeric tower | Domain-specific numeric libraries |
| Core traits (Eq, Ord, Show, Hash, Iterator) | ORM, database drivers |
| Persistent collections (List, Vec, Map, Set) | Specialized data structures (skip lists, B-epsilon trees) |
| String, Rope, Text, Regex | Natural language processing |
| Linear I/O, File, Path | GUI frameworks |
| Actor primitives, Supervisor, Channel | Web frameworks (HTTP server) |
| Session-typed channels | Protocol-specific libraries (gRPC, WebSocket) |
| Propagator cells, propagators, scheduler | Domain-specific constraint solvers |
| Unification, backtracking, tabling | Theorem prover front-ends |
| Posit arithmetic, quire, arbitrary precision | Symbolic algebra |
| EDN serialization | Format-specific serializers (Protobuf, Avro) |
| Testing framework, property-based testing | Mocking frameworks, fuzzing harnesses |
| C FFI, platform abstraction | Language-specific FFI (Java, Python interop) |
| Package manager, build system | IDE plugins, editor integrations |
| Documentation generator | Tutorial scaffolding |

---

## 2. Survey of Standard Library Designs

### 2.1 Java: The Cautionary Kitchen Sink

Java's standard library has grown to over 6,000 classes across 224+ packages. It provides comprehensive coverage — from `java.util.concurrent.ForkJoinPool` to `java.time.ZonedDateTime` — but carries significant baggage. The evolution from `java.util.Date` (mutable, zero-indexed months, year offset from 1900) to `java.time` (immutable, well-designed, JSR 310) took 18 years and required a completely new package because the old one could not be removed. `Vector` conflated resizable-array with synchronized-access, violating single-responsibility; it was superseded by `ArrayList` but cannot be deleted. The checked-exceptions controversy demonstrates how a well-intentioned design decision (forcing error handling) can become an impediment when it interacts poorly with later features (lambdas, streams).

**Lesson for Πρόλογος**: Design for removal. Every standard library type should have a clear deprecation path. Prefer composition (separate synchronization from data structure) over conflation. Never mix orthogonal concerns in a single type.

### 2.2 Go: Batteries Included, Minimally

Go's standard library contains approximately 60 packages — an order of magnitude smaller than Java's — yet covers HTTP servers/clients, JSON, testing, cryptography, and concurrency. Go achieves this through radical minimalism: the testing package has no assertion library (tests are just `if` statements), `net/http` exposes a single `Handler` interface with one method, and `io.Reader`/`io.Writer` each define a single method. Go's dependency hygiene is instructive: the `net` package implements its own integer-to-decimal conversion to avoid depending on `fmt`.

**Lesson for Πρόλογος**: Small interfaces compose better than large ones. A single-method trait (`Read`, `Write`, `Merge`) can be implemented for any type. Avoid depending on heavy modules from lightweight ones — copy a small helper rather than pulling in a large dependency.

### 2.3 Rust: Three-Tier Layering and Trait-Based Design

Rust's split into `core` (no heap, no OS), `alloc` (heap, no OS), `std` (full OS) is the gold standard for layered standard library design. The separation enables `#![no_std]` code on embedded systems and kernels while providing the full `std` experience on desktops. Traits organize the entire library: `Iterator` (70+ adapter methods with default implementations), `From`/`Into` (infallible conversion), `TryFrom`/`TryInto` (fallible conversion), `Read`/`Write`/`Seek` (I/O), `Display`/`Debug` (formatting). The "small std, rich ecosystem" philosophy delegates HTTP, serialization, async runtimes, and logging to crates.

**Lesson for Πρόλογος**: Adopt the three-layer architecture. Define `prologos/core` (no allocation, no I/O), `prologos/alloc` (persistent data structures), and `prologos/std` (I/O, actors, networking). Define traits early — they are the skeleton of the library.

### 2.4 Pony: Capabilities and Actor-Based I/O

Pony's standard library is unique because every type and method must account for the six reference capabilities. A `HashMap` in Pony has a type signature that specifies the capabilities of keys, values, and the hash function. I/O primitives (`TCPListener`, `TCPConnection`, `UDPSocket`) are actors, not objects — they communicate via message-passing callbacks (`TCPConnectionNotify`). Pony's ORCA garbage collector provides per-actor heaps with zero stop-the-world pauses, and the standard library's collection design reflects this: `val` collections (immutable) can be freely shared across actors; `iso` collections (isolated) can be efficiently transferred.

**Lesson for Πρόλογος**: QTT multiplicities are the analog of Pony's capabilities. The standard library must be quantity-polymorphic. I/O must be actor-based. Collection APIs must distinguish between local-mutable and shared-immutable access patterns.

### 2.5 Idris 2: Dependent Types and QTT in the Library

Idris 2's standard library demonstrates what a dependently-typed library looks like. `Data.Vect n a` carries its length in the type; `append` has type `Vect n a -> Vect m a -> Vect (n + m) a`. `Data.Fin n` represents integers bounded by `n`, enabling type-safe indexing. `Decidable.Equality` returns evidence: either `Yes` with a proof of equality or `No` with a proof of inequality. Linear I/O uses the `1` multiplicity to ensure that the world token is used exactly once, preventing accidental aliasing.

The base library is deliberately thin — `Data.SortedMap` and `Data.SortedSet` use balanced trees, there are no hash maps in `base`, and the `contrib` library adds community-maintained extras like linear arrays and ANSI formatting. Idris 2's FFI supports Chez Scheme, Racket, and Gambit backends, with the programmer responsible for ensuring type correspondence.

**Lesson for Πρόλογος**: Dependent types should appear in the standard library from day one — not as an advanced feature but as the default way to express preconditions. Length-indexed vectors, bounded integers, and decidable equality should be in the core library.

### 2.6 Clojure: Immutability, Sequences, and the Hosted Model

Clojure's standard library is built around four persistent data structures — vectors, hash-maps, hash-sets, and lists — all using structural sharing via HAMTs and RRB trees. The sequence abstraction (`seq`) unifies all collections: `map`, `filter`, `reduce`, `take`, `drop` work on any seqable type. Transducers separate transformation logic from data source, enabling the same transformation to be applied to sequences, channels, and observables. Clojure's concurrency primitives — atoms, refs (STM), agents, and core.async channels — provide a toolkit for managing state change in an immutable world.

As a hosted language on the JVM, Clojure leverages Java's I/O, threading, and networking infrastructure rather than reimplementing them. `clojure.spec` provides runtime contracts and generative testing as an alternative to static types. `clojure.core.logic` brings miniKanren-based logic programming into the standard ecosystem.

**Lesson for Πρόλογος**: Adopt HAMT-based persistent maps and sets (Bagwell's research, as specified in NOTES.org). Provide a universal iteration abstraction (like `seq`). Consider transducers for composable, allocation-free transformations. The logic programming sub-language should be as integrated as `core.logic` is in Clojure — not a separate mode but a natural extension of the functional core.

### 2.7 Haskell: Type Classes and the Batteries Problem

Haskell's `base` package is minimal by design, providing the `Prelude` (core types and functions), the type class hierarchy (`Functor → Applicative → Monad`, `Semigroup → Monoid`, `Foldable → Traversable`), and basic I/O. However, this minimalism creates the "batteries not included" problem: nearly every real program requires `text` (Unicode strings), `bytestring` (binary data), `containers` (maps, sets), `transformers`, and `mtl` — none of which are in `base`. Alternative preludes (relude, RIO, Foundation) attempt to solve this by bundling best-practice libraries into a single import.

Lazy evaluation permeates the library, enabling elegant infinite data structures but creating subtle space leaks when unevaluated thunks accumulate. The `String` type (a linked list of characters) is notoriously inefficient; production code must use `Data.Text`.

**Lesson for Πρόλογος**: Include sufficient batteries in the core library — at minimum: Unicode strings, persistent collections, and the complete type class hierarchy. Design with strictness by default (lazy evaluation opt-in) to avoid space leaks. Never ship a default string type that cannot scale.

### 2.8 Erlang/OTP: Processes, Behaviours, and Supervision

Erlang/OTP's standard library is structured as applications: Kernel (mandatory runtime), Stdlib (data structures, behaviours), and SASL (hot code loading). The behaviour pattern — `gen_server`, `gen_statem`, `gen_event`, `supervisor` — defines reusable patterns for concurrent processes. Supervision trees implement the "let it crash" philosophy: rather than handling every error, processes crash and are automatically restarted by their supervisor.

ETS (Erlang Term Storage) provides constant-time access to large quantities of data in process-owned tables, automatically garbage-collected when the owner terminates. The distribution primitives (`net_kernel`, `rpc`, `global`, `pg`) enable distributed computing without external libraries.

**Lesson for Πρόλογος**: Adopt OTP-style behaviours for actor patterns. Supervision trees should be a standard library type, not a framework feature. Consider an ETS-like per-actor term store for high-performance local data.

### 2.9 Mercury and SWI-Prolog: Logic Language Standard Libraries

Mercury's standard library provides typed, mode-declared modules: `int`, `float`, `string`, `list`, `map`, `set`, `io`, `array`, `tree234`, etc. I/O is purely logical through state threading — `io.write(X, !IO)` — where `!IO` indicates an in-out state variable. Mode declarations specify which arguments are inputs vs. outputs, enabling the compiler to select efficient execution strategies.

SWI-Prolog's library contains over 100 modules organized by function: `library(lists)` for list manipulation, `library(assoc)` for AVL-tree-based association lists, `library(ordsets)` for ordered sets, `library(apply)` for higher-order predicates like `maplist`. Predicates work in multiple modes — `append(L1, L2, Result)` can concatenate or split depending on which arguments are bound.

**Lesson for Πρόλογος**: Multi-modal predicates should be a first-class standard library feature. The logic programming sub-language should provide list operations that work bidirectionally (like Prolog's `append`). I/O should be both state-threaded (for purity) and actor-based (for concurrency).

### 2.10 Lean 4: Proof-Carrying Data Structures

Lean 4's standard library features verified data structures: basic operations on `HashMap`, `HashSet`, `RBMap`, and `TreeSet` are formally proven correct with respect to simpler list-based models. The `Decidable` type class embeds proofs, and `Fin n` ensures array indices are in-bounds. Mathlib extends the standard library with nearly two million lines of formalized mathematics.

Lean 4's metaprogramming — macros, tactics, and custom elaborators — is deeply integrated: the standard library uses them to provide proof automation and domain-specific notation. The IO monad tracks both state and errors, using a world token that is consumed exactly once.

**Lesson for Πρόλογος**: Where practical, verify standard library data structures against simpler specifications. Use dependent types to make invariants visible in the API — but do not require proofs for every operation (that would make the library unusable for non-expert programmers).

---

## 3. Synthesis: Lessons and Anti-Patterns

### 3.1 Twelve Principles for the Πρόλογος Standard Library

**Principle 1: Simplicity.** Every module has one responsibility. Never conflate orthogonal concerns (Java's Vector lesson).

**Principle 2: Traits as Skeleton.** Define core traits early: `Eq`, `Ord`, `Hash`, `Show`, `Debug`, `Iterator`, `Read`, `Write`, `Merge`, `From`, `Into`. All collections and I/O types implement these traits.

**Principle 3: Three-Layer Architecture.** `prologos/core` (no allocation, no I/O), `prologos/alloc` (persistent data structures), `prologos/std` (full I/O, actors, networking).

**Principle 4: Quantity Polymorphism.** Standard library functions should be polymorphic over QTT multiplicities where possible: `(map : (forall (q : Quantity) (-> (-> a b) (List q a) (List q b))))`.

**Principle 5: Dependent Types by Default.** Length-indexed vectors, bounded integers, decidable equality, and proof-carrying results should be standard — not optional advanced features.

**Principle 6: Immutability as Default.** All standard collections are persistent with structural sharing. Mutable variants exist only for performance-critical internal use, exposed through linear types.

**Principle 7: Actor-Based I/O.** All I/O is non-blocking and actor-based. No synchronous I/O in the standard library. File reads, network operations, and timers are all actor messages.

**Principle 8: Explicit Error Handling.** `Result` and `Option` are the primary error types. No exceptions in user code. Backtracking in logic mode uses the WAM, not exceptions.

**Principle 9: Excellent Error Messages.** Every standard library operation that can fail provides rich error context with source spans, expected vs. actual values, and suggested fixes (NOTES.org: "Excellent, human-readable, compiler errors... VERY IMPORTANT").

**Principle 10: Propagators as First Class.** Cells, propagators, and the scheduler are standard library types, integrated with the actor runtime and the logic sub-language.

**Principle 11: Multi-Modal Logic.** Logic programming predicates work in multiple modes. `append` can concatenate, split, or verify. Mode analysis guides compilation.

**Principle 12: Documentation as Code.** Every public function has a doc-comment with examples. Examples are tested as part of the standard library test suite (like Rust's doc-tests).

### 3.2 Anti-Patterns to Avoid

**Java's Legacy Trap.** Never ship a type that conflates two concerns. If you must deprecate, provide a clear migration path and a timeline for removal.

**Haskell's Batteries Gap.** Do not ship a standard library that requires external packages for Unicode strings, persistent maps, or error handling. Include the batteries that 90% of programs need.

**Python 2→3 Breakage.** Establish a stability policy from day one. Use semantic versioning. Define what constitutes a breaking change. Provide deprecation warnings for at least two releases before removal.

**C++ `std::string` Encoding Ambiguity.** Define from the start: Πρόλογος strings are UTF-8. Always. No encoding ambiguity.

**Go's Pre-1.18 Generics Gap.** Do not defer essential type-system features. Πρόλογος has dependent types from day one — the standard library should use them from day one.

**Overly Broad Modules.** Avoid "utils" or "misc" modules. Every module should have a clear, cohesive purpose.

---

## 4. Dependency Graph and Module Taxonomy

### 4.1 The Πρόλογος Standard Library Module Map

The standard library comprises the following module families, organized by the namespace convention `prologos/<layer>/<module>`:

```
prologos/core/         -- Layer 0: No allocation, no I/O
  bool, nat, int, fin
  ordering, eq, ord, hash
  show, debug, format
  option, result
  function, identity

prologos/alloc/        -- Layer 1: Allocation, no I/O
  list, vect, seq
  map, set, sorted-map, sorted-set
  deque, heap
  string, rope, text
  iter, transducer
  lattice

prologos/std/          -- Layer 2: Full I/O, actors, networking
  io, file, path, buffer
  actor, mailbox, supervisor
  channel, session
  task, parallel
  propagator, cell, scheduler
  unify, search, table, clp
  posit, quire, bigint, numeric
  net/tcp, net/udp
  edn, json
  time, duration, clock
  regex
  test, property, bench
  ffi, platform
  doc
```

### 4.2 Dependency DAG

The following directed acyclic graph shows module dependencies (arrows indicate "depends on"):

```
Layer 0 (core):
  bool, nat → ordering → eq → ord → hash
  nat → fin
  eq, show → option, result
  option, result → function

Layer 1 (alloc):
  option, result, eq, ord, hash → list → vect
  list, hash → map, set
  ord → sorted-map, sorted-set
  list → deque, heap
  list, eq → string → rope → text
  list, option → iter → transducer
  eq, ord → lattice

Layer 2 (std):
  string, result → io → file, path, buffer
  io, actor → mailbox → supervisor
  actor, session types → channel → session
  actor, iter → task → parallel
  lattice, actor → cell → propagator → scheduler
  list, eq, option → unify → search → table → clp
  nat, int → posit, quire, bigint → numeric
  actor, io → net/tcp, net/udp
  string, map → edn, json
  nat → time, duration → clock
  string → regex
  result, io → test → property → bench
  io, platform → ffi
  string, io → doc
```

### 4.3 The Three-Layer Architecture

**Layer 0 (`prologos/core`)** requires nothing beyond the language primitives. It defines types that exist at compile time and at runtime but do not allocate heap memory: booleans, natural numbers, machine integers, finite types, comparison traits, option/result, and basic function combinators. This layer can be used in bare-metal or embedded contexts if Πρόλογος ever targets them.

**Layer 1 (`prologos/alloc`)** introduces heap allocation and persistent data structures. It contains the HAMT-based maps and sets, length-indexed vectors, lazy sequences, strings, ropes, iterators, transducers, and the lattice library. Everything in this layer is pure — no I/O, no side effects, no actors. It depends on Layer 0.

**Layer 2 (`prologos/std`)** is the full standard library. It introduces I/O, actors, networking, propagators, the logic sub-language, posit arithmetic, serialization, time, testing, and the FFI. It depends on both Layer 0 and Layer 1.

---

## 5. Phase 0: Bootstrap Foundations (Weeks 1–6)

Phase 0 establishes the type-theoretic foundation upon which everything else is built. No collection, no I/O, no concurrency — just types, traits, and the core vocabulary of the language.

### 5.1 Sprint 0.1: Primitive Types and Arithmetic (Weeks 1–2)

**Deliverables:**

The `prologos/core/bool` module provides the `Bool` type with `true` and `false` constructors, pattern matching, `and`, `or`, `not`, and conversion to/from `Nat`.

The `prologos/core/nat` module provides the `Nat` type (Peano naturals for type-level computation, compiled to machine words at runtime via erasure), `succ`, `pred`, addition, subtraction (saturating), multiplication, division, modular arithmetic, and comparison.

The `prologos/core/int` module provides `Int8`, `Int16`, `Int32`, `Int64`, `UInt8`, `UInt16`, `UInt32`, `UInt64`, and the polymorphic `Int` (arbitrary-precision by default, as specified in NOTES.org: "Arbitrary precision numbers, EFFICIENTLY" and "I don't like 'wrapping' Ints; I would rather throw run-time errors than silently wrapping"). Fixed-width operations detect overflow and produce a rich error rather than wrapping.

The `prologos/core/fin` module provides `Fin n` — a natural number strictly less than `n` — with arithmetic that respects bounds, conversion to/from `Nat`, and decidable equality.

```
;; Πρόλογος syntax: Fin type for bounded indexing
(data (Fin : (-> Nat Type))
  (fz : (forall (n : Nat) (Fin (succ n))))
  (fs : (forall (n : Nat) (-> (Fin n) (Fin (succ n))))))
```

**Key decisions:**

Πρόλογος integers do not wrap. Overflow on fixed-width types produces a `Result` error or promotes to arbitrary precision, depending on the context. This is a non-negotiable design requirement from NOTES.org.

`Nat` is used at the type level for dependent type indices. At runtime, `Nat` values that survive erasure are compiled to machine words (with a fallback to bigint if they exceed word size).

**Quantity Polymorphism from Day One.** Every type defined in this sprint and all subsequent sprints must be designed with QTT multiplicities in mind. Πρόλογος has three multiplicities — 0 (erased at runtime, used only for type-level computation), 1 (linear, used exactly once), and ω (unrestricted, used any number of times). The standard library API must be quantity-polymorphic wherever possible. This means:

**0-multiplicity (erased) parameters** are type indices, proof terms, and other computationally irrelevant bindings. They appear in types but generate no runtime code. Example: the `n` in `(Vect n a)` is 0-multiplicity — it exists only to carry length information during type checking and is erased before LLVM emission.

**1-multiplicity (linear) parameters** represent resources that must be used exactly once. File handles, channels, actor references, and foreign pointers are linear. The compiler inserts deallocation at the single use site — no reference counting, no GC.

**ω-multiplicity (unrestricted) parameters** are ordinary values that can be freely copied and shared. Most data values (integers, strings, collections) are unrestricted.

The standard library uses quantity-polymorphic signatures where the multiplicity does not affect semantics:

```
;; Quantity-polymorphic Option: works for linear and unrestricted values
(data (Option : (-> (q : Quantity) Type Type))
  (none : (forall (q : Quantity) (a : Type) (Option q a)))
  (some : (forall (q : Quantity) (a : Type) (-> (q a) (Option q a)))))

;; map respects the quantity of the contained value
(def option/map
  (forall (q : Quantity) (a b : Type)
    (-> (-> (q a) (q b)) (Option q a) (Option q b))))

;; Result similarly quantity-polymorphic
(data (Result : (-> (q : Quantity) Type Type Type))
  (ok  : (forall (q : Quantity) (a e : Type) (-> (q a) (Result q a e))))
  (err : (forall (q : Quantity) (a e : Type) (-> e (Result q a e)))))

;; List operations preserve quantity
(def list/map
  (forall (q : Quantity) (a b : Type)
    (-> (-> (q a) (q b)) (List q a) (List q b))))

;; Iterator yields values at the specified quantity
(trait (Iterator i)
  (type Item)
  (type (Quantity : Quantity))
  (next : (-> (1 i) (Option Quantity (Pair Item i)))))
```

When the user writes `(map f xs)` on a `(List 1 FileHandle)`, the compiler verifies that `f` consumes each file handle exactly once. When applied to `(List ω Int)`, the constraint is trivially satisfied. This unifies linear resource management and unrestricted data processing under a single API — the defining advantage of QTT over separate linear type systems.

### 5.2 Sprint 0.2: Core Traits and Type Classes (Weeks 3–4)

**Deliverables:**

The trait hierarchy that organizes the entire standard library:

```
;; The core trait hierarchy
(trait (Eq a)
  (== : (-> a a Bool))
  (/= : (-> a a Bool)
    (default (fn (x y) (not (== x y))))))

(trait (Ord a) (requires (Eq a))
  (compare : (-> a a Ordering))
  (<  : (-> a a Bool) (default ...))
  (>  : (-> a a Bool) (default ...))
  (<= : (-> a a Bool) (default ...))
  (>= : (-> a a Bool) (default ...)))

(trait (Hash a) (requires (Eq a))
  (hash : (-> a UInt64)))

(trait (Show a)
  (show : (-> a String)))

(trait (Debug a)
  (debug : (-> a String)))

(trait (Default a)
  (default : a))

(trait (Clone a)
  (clone : (-> a a)))

(trait (Semigroup a)
  (<> : (-> a a a)))

(trait (Monoid a) (requires (Semigroup a))
  (empty : a))

(trait (DecEq a) (requires (Eq a))
  (dec-eq : (-> (x : a) (y : a) (Dec (= x y)))))
```

`DecEq` is critical — it provides decidable equality with evidence, following Idris 2's pattern. When `dec-eq x y` returns `(yes prf)`, the proof `prf` can be used in dependent type computation.

Implement `Eq`, `Ord`, `Hash`, `Show`, `Debug`, `Default`, `Clone`, `Semigroup`, `Monoid` for all primitive types from Sprint 0.1.

### 5.3 Sprint 0.3: Option, Result, and Error Foundation (Weeks 5–6)

**Deliverables:**

```
;; Option type
(data (Option a)
  (none)
  (some a))

;; Result type with rich error context
(data (Result a e)
  (ok a)
  (err e))
```

The `Option` and `Result` types with comprehensive combinators: `map`, `flat-map`, `unwrap-or`, `and-then`, `or-else`, `filter`, `zip`, `zip-with`. The `?` operator (or Πρόλογος equivalent) for early return on error.

The `prologos/core/error` module defines the `Error` trait:

```
(trait (Error e) (requires (Show e) (Debug e))
  (source : (-> e (Option (dyn Error))))
  (context : (-> e (List ErrorContext))))

(record ErrorContext
  (span    : (Option SourceSpan))
  (message : String)
  (label   : (Option String)))
```

Every standard library error type implements `Error` with source spans and contextual messages, enabling the compiler and runtime to produce the excellent error messages required by NOTES.org.

---

## 6. Phase 1: Core Data Structures (Weeks 7–18)

Phase 1 builds the persistent, immutable data structures that are the backbone of Πρόλογος programs. Every collection is immutable by default with structural sharing, following the Clojure model.

### 6.1 Sprint 1.1: List and Lazy Sequences (Weeks 7–9)

**Deliverables:**

The `prologos/alloc/list` module provides the singly-linked persistent list with standard operations: `cons`, `head`, `tail`, `length`, `map`, `filter`, `fold-left`, `fold-right`, `append`, `reverse`, `zip`, `take`, `drop`, `split-at`, `partition`, `sort`, `group-by`.

Critically, many of these operations should work in multiple modes (following Mercury and Prolog):

```
;; append works in multiple modes:
;; Mode 1: (append xs ys) → zs        (concatenation)
;; Mode 2: (append ?xs ?ys zs) → ...  (splitting, logic mode)
```

The `prologos/alloc/seq` module provides lazy sequences (like Clojure's `lazy-seq` or Haskell's lists): elements are computed on demand, enabling infinite data structures and efficient pipeline processing without intermediate allocation. The implementation uses thunks that are forced at most once (memoized laziness).

### 6.2 Sprint 1.2: Length-Indexed Vectors (Weeks 10–11)

**Deliverables:**

The `prologos/alloc/vect` module provides `Vect n a` — a vector of exactly `n` elements of type `a`, where `n` is a compile-time natural number. This is the Πρόλογος analog of Idris 2's `Data.Vect`.

```
;; Length-indexed vector
(data (Vect : (-> Nat Type Type))
  (vnil  : (Vect 0 a))
  (vcons : (-> a (Vect n a) (Vect (succ n) a))))

;; Type-safe head: cannot be called on empty vector
(def vect/head
  (forall (n : Nat) (a : Type)
    (-> (Vect (succ n) a) a)))

;; Type-safe index: Fin n guarantees in-bounds access
(def vect/index
  (forall (n : Nat) (a : Type)
    (-> (Fin n) (Vect n a) a)))

;; Append carries length proof
(def vect/append
  (forall (n m : Nat) (a : Type)
    (-> (Vect n a) (Vect m a) (Vect (+ n m) a))))
```

For runtime performance, `Vect` is compiled to a flat array (not a linked list of `vcons` cells). The type-level length `n` is erased at runtime (0-multiplicity). The `Fin n` index type is compiled to a machine word, with the bound proof erased.

### 6.3 Sprint 1.3: HAMT-Based Persistent Map and Set (Weeks 12–14)

**Deliverables:**

The `prologos/alloc/map` module provides `Map k v` — a persistent hash map using Hash Array Mapped Tries (HAMTs), following Bagwell's research and Clojure's implementation. Key operations: `insert`, `lookup`, `remove`, `update`, `merge`, `merge-with`, `keys`, `values`, `entries`, `map`, `filter`, `fold`.

The `prologos/alloc/set` module provides `Set a` — a persistent hash set built on HAMT. Key operations: `insert`, `member`, `remove`, `union`, `intersection`, `difference`, `symmetric-difference`, `subset?`, `map`, `filter`, `fold`.

**Implementation details:**

The HAMT uses 5-bit chunks of the 64-bit hash, giving a branching factor of 32 and a maximum depth of ~13. For maps with fewer than 8 entries, a simple sorted array is used (following Clojure's optimization). Structural sharing ensures that insertion/deletion copies only the path from root to modified node — O(log₃₂ n) nodes, which is effectively O(1) for practical sizes.

```
;; Persistent map operations
(def map/insert
  (forall (k v : Type) (requires (Eq k) (Hash k))
    (-> k v (Map k v) (Map k v))))

(def map/lookup
  (forall (k v : Type) (requires (Eq k) (Hash k))
    (-> k (Map k v) (Option v))))
```

### 6.4 Sprint 1.4: Sorted Map/Set, Deque, Heap (Weeks 15–16)

**Deliverables:**

`prologos/alloc/sorted-map` and `prologos/alloc/sorted-set` provide persistent ordered collections using balanced trees (2-3 trees or red-black trees), requiring `Ord` rather than `Hash`. These support range queries, `min`, `max`, `range`, `split`, and ordered iteration.

`prologos/alloc/deque` provides a persistent double-ended queue (finger tree or Banker's deque), with O(1) amortized `push-front`, `push-back`, `pop-front`, `pop-back`, and O(log n) `concat`.

`prologos/alloc/heap` provides a persistent priority queue (pairing heap or leftist heap), with O(1) `find-min`, O(log n) `delete-min` and `insert`, and O(1) `merge`.

### 6.5 Sprint 1.5: Iterator and Transducer Framework (Weeks 17–18)

**Deliverables:**

The `prologos/alloc/iter` module defines the `Iterator` trait and a rich set of lazy adapters:

```
(trait (Iterator i)
  (type Item)
  (next : (-> (1 i) (Option (Pair Item i)))))

;; Lazy adapters (return new iterators, don't compute)
(def iter/map    : (-> (-> a b) (Iterator a) (Iterator b)))
(def iter/filter : (-> (-> a Bool) (Iterator a) (Iterator a)))
(def iter/take   : (-> Nat (Iterator a) (Iterator a)))
(def iter/zip    : (-> (Iterator a) (Iterator b) (Iterator (Pair a b))))
(def iter/chain  : (-> (Iterator a) (Iterator a) (Iterator a)))

;; Consuming operations (force computation)
(def iter/fold    : (-> (-> b a b) b (Iterator a) b))
(def iter/collect : (-> (Iterator a) (List a)))
(def iter/any     : (-> (-> a Bool) (Iterator a) Bool))
(def iter/all     : (-> (-> a Bool) (Iterator a) Bool))
```

Note the linear (`1`) usage of the iterator in `next` — an iterator is consumed when advanced, preventing aliasing of iterator state.

The `prologos/alloc/transducer` module provides composable transformations that are independent of data source, following Clojure's transducer model:

```
;; A transducer transforms one reducing function into another
(type (Transducer a b)
  (-> (ReducingFn b r) (ReducingFn a r)))

;; Compose transducers (no intermediate allocation)
(def xf
  (comp
    (xf/filter positive?)
    (xf/map square)
    (xf/take 10)))

;; Apply to any source
(transduce xf + 0 data)  ;; sum of squares of first 10 positive elements
```

---

## 7. Phase 2: String and Text Processing (Weeks 19–24)

### 7.1 Sprint 2.1: UTF-8 String and Rope Types (Weeks 19–21)

**Deliverables:**

The `prologos/alloc/string` module provides `String` — a UTF-8 encoded, immutable, structurally-shared byte sequence. Strings are not linked lists of characters (avoiding Haskell's mistake). They are flat byte arrays with O(1) length (in bytes), O(n) length (in code points), O(1) slice, and O(n) character iteration.

The `prologos/alloc/rope` module provides `Rope` — a balanced tree of string chunks for efficient concatenation, insertion, and deletion in large texts. Ropes provide O(log n) `insert-at`, `delete-at`, and `concat`, making them suitable for text editors and large document processing.

The `prologos/alloc/text` module provides `Text` — a higher-level text type that normalizes Unicode (NFC by default) and provides grapheme-cluster-aware operations: `length` counts grapheme clusters (not bytes or code points), `slice` operates on grapheme boundaries, and `compare` uses the Unicode Collation Algorithm.

### 7.2 Sprint 2.2: String Formatting and Display Traits (Weeks 22–23)

**Deliverables:**

A formatting system inspired by Rust's `fmt` and Clojure's `cl-format`:

```
;; Format strings with positional and named arguments
(format "Hello, {name}! You have {count} messages."
  :name "Z" :count 42)
;; => "Hello, Z! You have 42 messages."

;; The Show trait produces human-readable output
;; The Debug trait produces machine-readable output (for debugging)
;; Both are auto-derivable
```

The `Show` and `Debug` traits are auto-derivable for all algebraic data types using the compiler's metaprogramming facility.

### 7.3 Sprint 2.3: Regular Expressions (Week 24)

**Deliverables:**

The `prologos/std/regex` module provides compiled regular expressions with RE2 semantics (linear-time matching, no catastrophic backtracking). Operations: `match`, `find`, `find-all`, `replace`, `replace-all`, `split`, `captures`.

---

## 8. Phase 3: I/O, File System, and Resources (Weeks 25–33)

Phase 3 introduces side effects. This is where Πρόλογος's linear types and actor model become essential — I/O operations consume linear tokens, ensuring resources are not leaked.

### 8.1 Sprint 3.1: Linear I/O Foundation (Weeks 25–27)

**Deliverables:**

The `prologos/std/io` module provides the core I/O traits:

```
;; Read trait: consume bytes from a source
(trait (Read r)
  (read : (-> (1 r) Nat (Result (Pair Bytes r) IOError))))

;; Write trait: emit bytes to a sink
(trait (Write w)
  (write : (-> (1 w) Bytes (Result w IOError)))
  (flush : (-> (1 w) (Result w IOError))))

;; Close trait: release a resource
(trait (Close c)
  (close : (-> (1 c) (Result Unit IOError))))
```

The `1` multiplicity on the resource parameter ensures that every opened resource is eventually closed — the type system enforces it. You cannot forget to close a file handle because the linear type prevents you from discarding it.

Standard I/O handles: `stdin`, `stdout`, `stderr` — provided as actor references that accept read/write messages.

### 8.2 Sprint 3.2: File System Operations (Weeks 28–30)

**Deliverables:**

The `prologos/std/file` module provides file operations through linear handles:

```
;; Open a file, returning a linear handle
(def file/open
  (-> Path OpenMode (Result (1 FileHandle) IOError)))

;; Read entire file contents (convenience)
(def file/read-all
  (-> Path (Result String IOError)))

;; Write entire file contents (convenience)
(def file/write-all
  (-> Path String (Result Unit IOError)))
```

The `prologos/std/path` module provides cross-platform path manipulation: `join`, `parent`, `file-name`, `extension`, `with-extension`, `normalize`, `is-absolute`, `is-relative`.

### 8.3 Sprint 3.3: Buffered and Streaming I/O (Weeks 31–33)

**Deliverables:**

Buffered wrappers (`BufReader`, `BufWriter`) that reduce system call overhead. Streaming I/O that integrates with iterators:

```
;; Stream lines from a file lazily
(def file/lines
  (-> (1 FileHandle) (Iterator String)))

;; Pipe: compose reader and writer through a transformation
(def io/pipe
  (-> (1 (impl Read)) (-> Bytes Bytes) (1 (impl Write)) (Result Unit IOError)))
```

---

## 9. Phase 4: Concurrency and Actor Runtime (Weeks 34–48)

Phase 4 builds the actor-based concurrency system. This phase depends on Phase 3 (I/O) because actors need I/O for useful work, and on Phase 1 (collections) because actors use persistent data structures for their state.

### 9.1 Sprint 4.1: Actor Primitives and Mailboxes (Weeks 34–36)

**Deliverables:**

The `prologos/std/actor` module provides the actor abstraction:

```
;; Define an actor with typed message protocol
(actor counter
  (state : Int 0)

  (receive (increment n)
    (become (+ state n)))

  (receive (get reply-to)
    (send reply-to state)))

;; Spawn an actor, returning an ActorRef
(def actor/spawn
  (forall (a : Type)
    (-> (ActorDef a) (Result ActorRef ActorError))))
```

Each actor has a private mailbox (lock-free segmented queue as described in RESEARCH_RUST_LLVM_LANGUAGE_IMPLEMENTATION.md Section 15.2), a private heap (for ORCA-style per-actor GC as described in RESEARCH_GC.md), and a private WAM state (for logic programming as described in RESEARCH_RUST_LLVM_LANGUAGE_IMPLEMENTATION.md Section 15.5).

### 9.2 Sprint 4.2: Supervision Trees (Weeks 37–39)

**Deliverables:**

The `prologos/std/supervisor` module provides OTP-style supervision:

```
;; Define a supervision tree
(supervisor my-app
  (strategy : one-for-one)
  (max-restarts : 3)
  (max-time : (seconds 5))

  (children
    (child :id :database  :start (db/start config))
    (child :id :web-server :start (web/start port)
           :depends-on [:database])))
```

Restart strategies: `one-for-one` (restart only the failed child), `all-for-one` (restart all children), `rest-for-one` (restart the failed child and all children started after it). Dependency ordering ensures children are started in the correct order and stopped in reverse order.

### 9.3 Sprint 4.3: Session-Typed Channels (Weeks 40–42)

**Deliverables:**

The `prologos/std/session` module provides channels whose communication protocol is verified by the type system:

```
;; Define a session type for a login protocol
(session-type LoginProtocol
  (send Username)
  (send Password)
  (branch
    (success (recv AuthToken) end)
    (failure (recv ErrorMsg) end)))

;; Use the session
(def login
  (-> (1 (Chan LoginProtocol)) (Result AuthToken LoginError))
  (fn (ch)
    (let ch (send ch username))
    (let ch (send ch password))
    (match (offer ch)
      (success ch)
        (let (pair token ch) (recv ch))
        (close ch)
        (ok token)
      (failure ch)
        (let (pair msg ch) (recv ch))
        (close ch)
        (err (login-error msg)))))
```

The channel is linear (`1`) — it must be used exactly according to the protocol. The type system verifies that sends and receives alternate correctly.

### 9.4 Sprint 4.4: Structured Concurrency and Task Groups (Weeks 43–45)

**Deliverables:**

The `prologos/std/task` module provides structured concurrency (inspired by Kotlin's coroutine scopes and the research in RESEARCH_PARALLEL.md Section 5.5):

```
;; Task group: all tasks must complete before scope exits
(task-group
  (let x (spawn (compute-a)))
  (let y (spawn (compute-b)))
  (let z (spawn (compute-c)))
  ;; All three run concurrently
  ;; Scope waits for all to complete
  (combine (await x) (await y) (await z)))
```

Cancellation propagates: if any task fails, all sibling tasks are cancelled. This prevents resource leaks from orphaned tasks.

### 9.5 Sprint 4.5: Parallel Iterators and Auto-Parallelization (Weeks 46–48)

**Deliverables:**

The `prologos/std/parallel` module provides parallel versions of iterator operations:

```
;; Parallel map: automatically distributes work across cores
(def par/map
  (forall (a b : Type)
    (-> (-> a b) (List a) (List b))))

;; Parallel reduce: requires associative combining function
(def par/reduce
  (forall (a : Type) (requires (Monoid a))
    (-> (-> a a a) (List a) a)))

;; Parallel for-each with index
(def par/for-each
  (forall (a : Type)
    (-> (-> Nat a Unit) (List a) Unit)))
```

The compiler uses the CALM theorem (from RESEARCH_PARALLEL.md Section 9) to determine which operations are safe to parallelize without synchronization. Operations on monotonic data structures (lattice-valued cells) are automatically parallelizable.

---

## 10. Phase 5: Propagator Networks (Weeks 49–57)

Phase 5 builds the propagator network infrastructure. This depends on Phase 4 (actors, for the scheduler) and Phase 1 (collections and lattices). The propagator library must be built **before** the logic sub-language (Phase 6) because constraints in Phase 6 are compiled to propagator networks.

### 10.1 Sprint 5.1: Cells, Propagators, and Scheduler (Weeks 49–51)

**Deliverables:**

The `prologos/std/cell` module provides lattice-valued cells:

```
;; A cell holds a value from a lattice, supporting monotonic merge
(trait (Lattice a) (requires (Eq a))
  (bottom : a)
  (merge  : (-> a a a))
  (<=     : (-> a a Bool)))

;; Cell: a container for a lattice value
(def cell/new
  (forall (a : Type) (requires (Lattice a))
    (-> a (Cell a))))

(def cell/read  : (-> (Cell a) a))
(def cell/merge : (-> (Cell a) a Unit))
;; merge is monotonic: new value = (lattice/merge old new)
```

The `prologos/std/propagator` module provides propagator definitions:

```
;; A propagator watches input cells and updates output cells
(def propagator/create
  (forall (a b : Type) (requires (Lattice a) (Lattice b))
    (-> (List (Cell a)) (List (Cell b)) (-> (List a) (List b)) Propagator)))
```

The `prologos/std/scheduler` module provides the work-stealing scheduler that fires propagators when their input cells change. The scheduler integrates with the actor runtime — propagator firings are scheduled as lightweight tasks on the same work-stealing pool.

### 10.2 Sprint 5.2: Lattice Library and Merge Operations (Weeks 52–54)

**Deliverables:**

The `prologos/alloc/lattice` module provides a library of common lattices:

```
;; Lattice instances for standard types
(instance (Lattice Bool) ...)        ;; false ≤ true
(instance (Lattice (Option a)) ...)  ;; none ≤ (some x)
(instance (Lattice (Set a)) ...)     ;; subset ordering, union merge
(instance (Lattice (Map k v)) ...)   ;; key-wise merge
(instance (Lattice (Interval a)) ...)  ;; interval narrowing
(instance (Lattice (Supported a)) ...) ;; supported values with justifications
```

The `Supported` lattice (from RESEARCH_PROPAGATORS.md) carries not just a value but the reason the value was derived — enabling truth maintenance and dependency-directed backtracking.

### 10.3 Sprint 5.3: Constraint Solving and Incremental Computation (Weeks 55–57)

**Deliverables:**

Higher-level constraint-solving facilities built on propagators:

```
;; Solve a system of constraints
(solve
  (where
    (cell x : (Interval Int) (interval 1 100))
    (cell y : (Interval Int) (interval 1 100))
    (propagate (+ x y) (interval 50 50))
    (propagate (* x y) (interval 600 600))))
;; Propagators narrow x and y to their solutions
```

Incremental computation support following the Adapton model: when an input cell changes, only affected propagators re-fire. This enables efficient re-solving when constraints change incrementally (e.g., in an IDE).

---

## 11. Phase 6: Logic Programming Sub-Language (Weeks 58–69)

Phase 6 builds the logic programming facilities. This depends on Phase 5 (propagators, for constraint solving) and Phase 1 (lists, for term representation). The critical ordering question — "Does the propagator library need to be built before the logic sub-language?" — has a definitive answer: **yes.** Constraint logic programming (Sprint 6.4) compiles constraints to propagator networks. Without the propagator infrastructure from Phase 5, CLP would require a separate, less-efficient constraint solver.

### 11.1 Sprint 6.1: Unification Engine (Weeks 58–60)

**Deliverables:**

The `prologos/std/unify` module provides first-order unification and higher-order unification (pattern fragment):

```
;; Unify two terms, producing a substitution or failure
(def unify
  (forall (a : Type) (requires (Unifiable a))
    (-> a a (Result Substitution UnificationError))))

;; The Unifiable trait
(trait (Unifiable a)
  (unify-with : (-> a a Substitution (Result Substitution UnificationError)))
  (apply-subst : (-> Substitution a a))
  (occurs-check : (-> Var a Bool)))
```

Unification operates within an actor's private WAM state (trail and heap), as established in RESEARCH_RUST_LLVM_LANGUAGE_IMPLEMENTATION.md Section 15.5. Backtracking is locally contained — it never crosses actor boundaries.

### 11.2 Sprint 6.2: Backtracking, Choice Points, and Search (Weeks 61–63)

**Deliverables:**

The `prologos/std/search` module provides backtracking search with choice points:

```
;; Define a relation (multi-modal predicate)
(relation (append xs ys zs)
  (clause (append nil ys ys))
  (clause (append (cons x xs') ys (cons x zs'))
    (append xs' ys zs')))

;; Query: find all ways to split [1 2 3]
(query (append ?xs ?ys [1 2 3]))
;; => [(nil [1 2 3]) ([1] [2 3]) ([1 2] [3]) ([1 2 3] nil)]
```

Mercury-style mode and determinism analysis: the compiler analyzes each relation to determine whether it is `det` (exactly one solution), `semidet` (zero or one), `multi` (one or more), or `nondet` (zero or more). This information guides compilation — `det` predicates compile to straight-line code without choice points.

### 11.3 Sprint 6.3: Tabling and Datalog (Weeks 64–66)

**Deliverables:**

Tabling (memoization of predicate results) prevents infinite loops in recursive predicates and enables efficient fixpoint computation:

```
;; Tabled relation: results are memoized
(tabled-relation (ancestor x y)
  (clause (ancestor x y) (parent x y))
  (clause (ancestor x y)
    (parent x z)
    (ancestor z y)))
```

A Datalog evaluator for bottom-up fixpoint computation of purely logical programs, following the Soufflé model described in RESEARCH_PARALLEL.md Section 10.5. Datalog programs are automatically parallelizable.

### 11.4 Sprint 6.4: Constraint Logic Programming (Weeks 67–69)

**Deliverables:**

CLP modules that compile constraints to propagator networks:

```
;; CLP(FD): constraints over finite domains
(solve
  (where
    (var x : (FiniteDomain 1 9))
    (var y : (FiniteDomain 1 9))
    (var z : (FiniteDomain 1 9))
    (constraint (all-different [x y z]))
    (constraint (= (+ x y) z))
    (constraint (> x 3))))
```

The `constraint` forms compile to propagators: `all-different` becomes an arc-consistency propagator, arithmetic constraints become interval-narrowing propagators, and the solver uses the scheduler from Phase 5 to drive fixpoint computation.

---

## 12. Phase 7: Numerics and Posit Arithmetic (Weeks 70–78)

### 12.1 Sprint 7.1: Arbitrary-Precision Integers (Weeks 70–72)

**Deliverables:**

The `prologos/std/bigint` module provides arbitrary-precision integers that integrate with the numeric tower:

```
;; BigInt: no overflow, no wrapping, no silent truncation
;; All arithmetic operations produce exact results
(def bigint/factorial : (-> Nat BigInt))
(def bigint/pow       : (-> BigInt BigInt BigInt))
(def bigint/gcd       : (-> BigInt BigInt BigInt))
(def bigint/mod-pow   : (-> BigInt BigInt BigInt BigInt))
```

When a fixed-width operation would overflow, it automatically promotes to `BigInt` rather than wrapping (as specified in NOTES.org).

### 12.2 Sprint 7.2: Posit Types and Quire Accumulator (Weeks 73–75)

**Deliverables:**

The `prologos/std/posit` module provides posit arithmetic following RESEARCH_UNUM_INNOVATIONS.md:

```
;; Posit types with tapered precision
(type Posit8)
(type Posit16)
(type Posit32)

;; Quire: exact accumulator for dot products
(type Quire32)

;; Posit operations
(def posit/add  : (-> Posit32 Posit32 Posit32))
(def posit/mul  : (-> Posit32 Posit32 Posit32))
(def posit/sqrt : (-> Posit32 Posit32))
(def posit/fma  : (-> Posit32 Posit32 Posit32 Posit32))

;; Quire operations for exact accumulation
(def quire/init : Quire32)
(def quire/fma  : (-> Quire32 Posit32 Posit32 Quire32))
(def quire/to-posit : (-> Quire32 Posit32))

;; Convenience: exact dot product
(def posit/dot : (-> (Vect n Posit32) (Vect n Posit32) Posit32))
```

### 12.3 Sprint 7.3: Numeric Tower and Conversion (Weeks 76–78)

**Deliverables:**

The `prologos/std/numeric` module provides a unified numeric tower:

```
;; Numeric tower: Nat ⊂ Int ⊂ BigInt ⊂ Rational ⊂ Posit32 ⊂ Complex
(trait (Numeric a) (requires (Eq a) (Show a))
  (+ : (-> a a a))
  (- : (-> a a a))
  (* : (-> a a a))
  (negate : (-> a a))
  (abs : (-> a a))
  (from-int : (-> Int a)))

(trait (Fractional a) (requires (Numeric a))
  (/ : (-> a a (Result a DivisionByZero)))
  (from-rational : (-> Rational a)))
```

Conversion between numeric types uses the `From`/`Into` traits with explicit precision-loss annotations:

```
;; Lossless conversions are implicit via From
(def from : (From Int BigInt))

;; Lossy conversions require explicit call with evidence
(def posit-from-rational : (-> Rational Posit32))
;; Compiler warns: "Conversion from Rational to Posit32 may lose precision"
```

---

## 13. Phase 8: Networking, Serialization, and Time (Weeks 79–90)

### 13.1 Sprint 8.1: Actor-Based TCP/UDP (Weeks 79–81)

**Deliverables:**

Following Pony's model, TCP and UDP are actors:

```
;; TCP listener: accepts connections via actor messages
(actor tcp-listener
  (on-accept : (-> TcpConnection Unit))
  (on-error  : (-> IOError Unit)))

;; TCP connection: read/write via messages
(actor tcp-connection
  (on-receive : (-> Bytes Unit))
  (on-close   : (-> Unit))
  (send        : (-> Bytes (Result Unit IOError))))
```

Backpressure is automatic: the actor's mailbox fills when it cannot process messages fast enough, causing the TCP stack to apply flow control.

### 13.2 Sprint 8.2: EDN and JSON Serialization (Weeks 82–84)

**Deliverables:**

EDN (Extensible Data Notation) support is specified in NOTES.org. The `prologos/std/edn` module provides bidirectional EDN parsing and generation:

```
;; EDN data type
(data EDN
  (edn/nil)
  (edn/bool Bool)
  (edn/int Int)
  (edn/float Posit32)
  (edn/string String)
  (edn/keyword Keyword)
  (edn/symbol Symbol)
  (edn/list (List EDN))
  (edn/vector (Vect n EDN))
  (edn/map (Map EDN EDN))
  (edn/set (Set EDN))
  (edn/tagged Symbol EDN))

;; Serializable trait
(trait (EDNSerializable a)
  (to-edn   : (-> a EDN))
  (from-edn : (-> EDN (Result a EDNError))))
```

JSON support via `prologos/std/json` with analogous types and traits.

### 13.3 Sprint 8.3: Time, Duration, and Clocks (Weeks 85–87)

**Deliverables:**

Immutable time types (learning from Java's `java.time` design):

```
(type Instant)      ;; point in time (nanosecond precision)
(type Duration)     ;; elapsed time between two instants
(type LocalDate)    ;; date without timezone
(type LocalTime)    ;; time without timezone
(type ZonedDateTime) ;; date-time with timezone
```

### 13.4 Sprint 8.4: HTTP Client Foundation (Weeks 88–90)

**Deliverables:**

A minimal HTTP client built on the actor-based TCP stack. This is the boundary of the standard library — HTTP servers, routers, and web frameworks are left to the ecosystem.

---

## 14. Phase 9: Testing, Debugging, and Developer Experience (Weeks 91–102)

### 14.1 Sprint 9.1: Test Framework and Assertions (Weeks 91–93)

**Deliverables:**

The `prologos/std/test` module provides the testing framework:

```
;; Define a test
(test "map preserves length"
  (let xs [1 2 3 4 5])
  (let ys (map (* 2) xs))
  (assert-eq (length xs) (length ys)))

;; Test with rich error context
(test "sorted-map maintains order"
  (let m (sorted-map/from-list [(3 "c") (1 "a") (2 "b")]))
  (assert-eq (sorted-map/keys m) [1 2 3]
    :message "Keys should be in ascending order"))
```

Test discovery follows naming convention: all functions named `test/*` in modules under `test/` are automatically discovered. Tests run concurrently (each in its own actor) for speed.

### 14.2 Sprint 9.2: Property-Based Testing and Spec (Weeks 94–96)

**Deliverables:**

Property-based testing inspired by QuickCheck and Clojure's spec:

```
;; Property: reverse is an involution
(property "reverse of reverse is identity"
  (forall (xs : (List Int))
    (assert-eq (reverse (reverse xs)) xs)))

;; Spec: runtime contracts with generative testing
(spec :positive-int (fn (x) (and (int? x) (> x 0))))
(spec :non-empty-list (fn (xs) (and (list? xs) (> (length xs) 0))))
```

The property-testing framework uses type-class-based generators (`Arbitrary a`) to produce random inputs, with shrinking to find minimal failing cases.

### 14.3 Sprint 9.3: Benchmarking and Profiling (Weeks 97–99)

**Deliverables:**

The `prologos/std/bench` module provides statistically rigorous benchmarking with confidence intervals and regression detection.

### 14.4 Sprint 9.4: REPL and Interactive Development (Weeks 100–102)

**Deliverables:**

An interactive REPL built on the ORC JIT v2 (as described in RESEARCH_RUST_LLVM_LANGUAGE_IMPLEMENTATION.md Section 5.2), supporting expression evaluation, type queries, logic queries, and propagator network inspection.

---

## 15. Phase 10: FFI, Ecosystem, and Packaging (Weeks 103–111)

### 15.1 Sprint 10.1: C FFI and Platform Abstraction (Weeks 103–105)

**Deliverables:**

The `prologos/std/ffi` module provides C FFI:

```
;; Declare a foreign function
(foreign "C" "math.h"
  (def c/sin : (-> Float64 Float64))
  (def c/cos : (-> Float64 Float64)))

;; Foreign memory management
(def ffi/alloc   : (-> USize (1 (Ptr UInt8))))
(def ffi/dealloc : (-> (1 (Ptr UInt8)) Unit))
```

Foreign pointers are linear by default — they must be explicitly freed, and the type system prevents use-after-free.

### 15.2 Sprint 10.2: Package Manager and Build System (Weeks 106–108)

**Deliverables:**

A package manager and build system (analogous to Cargo, Mix, or Lake) that handles dependency resolution, compilation, testing, benchmarking, and documentation generation. Configuration in EDN format (dogfooding the serialization library).

### 15.3 Sprint 10.3: Documentation Generation (Weeks 109–111)

**Deliverables:**

The `prologos/std/doc` module provides documentation extraction from doc-comments, type signatures, and examples. Examples in doc-comments are compiled and tested as part of the test suite (Rust's doc-test model).

---

## 16. Cross-Cutting Concerns

### 16.1 Error Messages Throughout the Standard Library

Every standard library operation that can fail must produce an error message that meets the NOTES.org standard: "Excellent, human-readable, compiler errors in the likes of Rust or Gleam — VERY IMPORTANT." This applies to runtime errors, not just compile-time errors.

```
;; Example: map lookup failure
;; BAD:  "Key not found"
;; GOOD:
error[E0401]: key not found in map
  --> src/main.prologos:42:5
   |
42 |   (let name (map/lookup :name config))
   |              ^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = key:    :name
   = map has 3 entries: [:host, :port, :timeout]
   = help: did you mean ':hostname'?
   = note: use 'map/get' with a default value to avoid this error
```

**Error Design Checklist.** Every fallible standard library operation must provide:

(1) An error code (`E0401`) that is unique, searchable, and documented. (2) A one-line summary that describes *what happened*, not *what the code does*. (3) A source-span pointer showing where the error occurred, with caret underlining. (4) Context values — the expected vs. actual data that caused the failure. (5) A `help:` suggestion with a concrete fix the user can apply. (6) A `note:` with alternative approaches or deeper explanation.

**Error Type Hierarchy.** Standard library errors fall into four categories, each with distinct presentation:

*Compile-time type errors* (produced by the type checker): these display the inferred type vs. the expected type, the unification trail, and the point where types diverge. Example: "Expected `(Vect 5 Int)` but found `(Vect 4 Int)` — the lengths 5 and 4 do not unify."

*Runtime value errors* (produced during program execution): these display the operation that failed, the values involved, and recovery suggestions. The map-lookup example above is a runtime value error.

*Actor and concurrency errors* (produced by the actor runtime): these display the actor that failed, the message that caused the failure, the supervision context, and whether the actor will be restarted. Example:

```
error[E0501]: actor mailbox overflow
  --> src/server.prologos:88:3
   |
88 |   (send worker (process data))
   |   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = actor:    :worker-3 (pid 0x1a2b)
   = mailbox:  full (1024/1024 messages)
   = supervisor: :worker-pool (strategy: one-for-one)
   = help: consider increasing mailbox capacity or adding backpressure
   = note: the actor has been processing messages at 50 msg/sec
           but receiving at 200 msg/sec for the last 5 seconds
```

*Constraint and propagator errors* (produced during constraint solving): these display the constraint that failed, the cell values at the time of failure, and the propagation chain that led to contradiction. Example:

```
error[E0601]: constraint unsatisfiable
  --> src/puzzle.prologos:15:5
   |
15 |   (constraint (all-different [x y z]))
   |   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = cell x: narrowed to {3} at line 12
   = cell y: narrowed to {3} at line 13
   = cell z: unconstrained {1..9}
   = conflict: x and y both equal 3, violating all-different
   = propagation chain:
       line 10: (= (+ x 1) 4) → x = {3}
       line 13: (= y x)        → y = {3}
   = help: check constraints at lines 10 and 13 for unintended equality
```

*Unification and logic errors* (produced during logic programming): these display the terms that failed to unify, the substitution at the point of failure, and the clause selection history. Example:

```
error[E0701]: unification failure
  --> src/rules.prologos:25:3
   |
25 |   (type-of ctx (app f a) result-ty)
   |   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = cannot unify: (-> Int Bool) with (-> String Bool)
   = because:      Int ≠ String
   = in context:   f = double, a = "hello"
   = clause tried: line 20 (type-of ctx (app f a) ty-result)
   = help: the argument "hello" has type String,
           but 'double' expects type Int
```

### 16.2 Naming Conventions and API Consistency

All standard library modules follow consistent naming:

**Module names**: lowercase with hyphens (`sorted-map`, `task-group`).

**Function names**: lowercase with hyphens, verb-first for actions (`map/insert`, `file/open`, `actor/spawn`), noun-phrase for accessors (`map/keys`, `list/length`), predicate with `?` suffix (`list/empty?`, `set/member?`).

**Type names**: PascalCase (`Map`, `Set`, `Vect`, `Option`, `Result`).

**Trait names**: PascalCase (`Eq`, `Ord`, `Hash`, `Iterator`, `Lattice`).

**Parameter ordering**: the "subject" collection comes last (enabling partial application and pipe-like composition), consistent with Clojure's threading convention adapted for prefix notation.

### 16.3 Stability Guarantees and Versioning

The standard library uses semantic versioning from its first release. The stability policy:

**Stable**: Public types, traits, and functions with documented behaviour. Can be relied upon across minor versions. Removal requires at least two minor release cycles of deprecation warnings.

**Unstable**: Marked with `(unstable)` annotation. May change in minor releases. Users must opt in.

**Internal**: Not exported. May change at any time.

### 16.4 Documentation Standards

Every public item has:

A one-line summary. A description paragraph. At least one example (compiled and tested). Type signature with named parameters. Complexity guarantees (for collections). Thread-safety notes (for concurrent types). Multiplicity annotations (for linear types). Error conditions (for fallible operations).

---

## 17. Concrete Syntax Sketches for Standard Library APIs

This section provides a taste of how standard library APIs feel in Πρόλογος syntax, illustrating the homoiconic, prefix-notation, significant-whitespace design from NOTES.org.

```
;; ─── Collection Pipeline ───────────────────────────────
;; Filter, transform, and reduce a list
(def total-cost
  (-> (List Order) Posit32)
  (fn (orders)
    (fold + (posit 0)
      (map order/cost
        (filter order/active? orders)))))

;; ─── Dependent Types in Action ─────────────────────────
;; Matrix multiplication with dimension checking
(def matrix-mul
  (forall (m n p : Nat)
    (-> (Matrix m n Posit32) (Matrix n p Posit32)
        (Matrix m p Posit32))))

;; ─── Logic Programming ────────────────────────────────
;; Define a type-checker as a relation
(relation (type-of ctx expr ty)
  (clause (type-of ctx (var x) ty)
    (member (pair x ty) ctx))
  (clause (type-of ctx (app f a) ty-result)
    (type-of ctx f (arrow ty-arg ty-result))
    (type-of ctx a ty-arg))
  (clause (type-of ctx (lam x body) (arrow ty-x ty-body))
    (type-of (cons (pair x ty-x) ctx) body ty-body)))

;; ─── Propagator Constraint Solving ─────────────────────
;; Sudoku solver using propagators
(def solve-sudoku
  (-> (Grid 9 9 (Option (Fin 9))) (Result (Grid 9 9 (Fin 9)) SolveError))
  (fn (puzzle)
    (solve
      (where
        ;; Create cells for each position
        (cells grid : (Grid 9 9 (FiniteDomain 1 9)))
        ;; Fix known values
        (for-each (pair pos val) (grid/known puzzle)
          (propagate (= (grid/at grid pos) val)))
        ;; Row, column, box constraints
        (for-each row (range 0 9)
          (constraint (all-different (grid/row grid row))))
        (for-each col (range 0 9)
          (constraint (all-different (grid/col grid col))))
        (for-each box (range 0 9)
          (constraint (all-different (grid/box grid box))))))))

;; ─── Session-Typed Protocol ────────────────────────────
;; File transfer protocol with type-safe phases
(session-type FileTransfer
  (send FileName)
  (branch
    (found
      (recv FileSize)
      (recv-stream Bytes)
      end)
    (not-found
      (recv ErrorMsg)
      end)))

;; ─── Actor with Supervision ───────────────────────────
(supervisor file-service
  (strategy : one-for-one)
  (children
    (child :id :cache
      :start (cache/start (megabytes 256)))
    (child :id :worker-pool
      :start (pool/start 4 file-handler)
      :depends-on [:cache])))
```

---

## 18. Compilation Strategy and LLVM Integration

The standard library design must be informed by the compilation strategy. NOTES.org specifies LLVM as the primary target, and RESEARCH_RUST_LLVM_LANGUAGE_IMPLEMENTATION.md provides the detailed compilation architecture. This section summarizes the key compilation implications for standard library implementors.

### 18.1 Erasure Model for Dependent Types

All 0-multiplicity bindings (type indices, proof terms, computationally irrelevant parameters) are erased before LLVM IR emission. The compiler's erasure pass — operating on the ANF intermediate representation — removes all 0-multiplicity let-bindings and function parameters. By the time LLVM sees the code, a function `(def safe-head (forall (n : Nat) (-> (Vect (succ n) Int) Int)))` has become `define i64 @safe_head(ptr %vec_data)` — the `n` parameter is gone entirely.

**Implication for stdlib design:** Standard library functions may accept 0-multiplicity parameters for type-level computation (e.g., the `n` in `Vect n a`), but these parameters must not be used for runtime computation. If a function needs the length at runtime (e.g., for bounds checking in a debug build), it must also accept the length as a separate ω-multiplicity parameter or store it alongside the data.

### 18.2 QTT Compilation to LLVM

The three multiplicities compile differently:

**0-multiplicity**: Erased entirely. No LLVM IR generated.

**1-multiplicity**: Compiled to a move — no reference counting, no GC interaction. The compiler inserts deallocation at the single use site. In LLVM IR, this is simply a `store` followed by a deallocation call at the use point. The compiler can attach `!prologos.linear` metadata to track linearity through LLVM optimization passes (see RESEARCH_RUST_LLVM_LANGUAGE_IMPLEMENTATION.md Section 2.5).

**ω-multiplicity**: Compiled to either Perceus-style reference counting (for heap values, with reuse analysis as described in RESEARCH_RUST_LLVM_LANGUAGE_IMPLEMENTATION.md Section 11.2) or direct value passing (for small values that fit in registers). The `rc_increment` and `rc_decrement` calls are emitted as LLVM function calls to the Rust runtime.

### 18.3 Actor Runtime Code Generation

Actors are compiled to a combination of generated LLVM code and Rust runtime library calls. The actor's message-handling loop compiles to a function that pattern-matches on the incoming message type and dispatches to the appropriate handler. The `prologos_actor_send` and `prologos_actor_recv` FFI functions (see RESEARCH_RUST_LLVM_LANGUAGE_IMPLEMENTATION.md Section 15.3) bridge generated code and the Rust-implemented scheduler.

The work-stealing scheduler itself is implemented in Rust (not generated by the Πρόλογος compiler), linked as a static library at compile time. Standard library actors (TCP, UDP, File I/O, Timers) are pre-compiled Rust code with Πρόλογος type signatures.

### 18.4 Propagator Scheduler Compilation

For the interpreted strategy (Phase 5, Sprint 5.1), propagators are runtime objects dispatched by the scheduler — no special code generation required. For the partially compiled and fully compiled strategies (RESEARCH_RUST_LLVM_LANGUAGE_IMPLEMENTATION.md Section 14.3), the compiler generates specialized LLVM code for each constraint network, replacing the generic scheduler loop with direct function calls in a fixed order. Standard library propagators use the interpreted strategy by default; the compiler applies the compiled strategies as an optimization when the network topology is known at compile time.

### 18.5 WAM Integration with LLVM

The WAM (Warren Abstract Machine) for logic programming is implemented as a library in Rust, with each actor maintaining private WAM state (RESEARCH_RUST_LLVM_LANGUAGE_IMPLEMENTATION.md Section 15.5). Logic programming constructs (`relation`, `clause`, `query`) compile to WAM instruction sequences emitted as LLVM IR. Backtracking uses LLVM's exception handling mechanism (`invoke`/`landingpad`) with a custom personality function that restores the WAM trail (RESEARCH_RUST_LLVM_LANGUAGE_IMPLEMENTATION.md Section 3.3).

Standard library predicates (e.g., `append`, `member`, unification) are pre-compiled to WAM instructions. User-defined relations compile through the same pipeline.

---

## 19. Summary: Sprint Calendar and Milestone Map

| Phase | Weeks | Sprints | Key Deliverables | Dependencies |
|---|---|---|---|---|
| **0: Bootstrap** | 1–6 | 0.1–0.3 | Primitives, traits, Option/Result, Error | None |
| **1: Collections** | 7–18 | 1.1–1.5 | List, Vect, Map, Set, Iterator, Transducer | Phase 0 |
| **2: Strings** | 19–24 | 2.1–2.3 | String, Rope, Text, Formatting, Regex | Phase 0, 1 |
| **3: I/O** | 25–33 | 3.1–3.3 | Linear I/O, File, Path, Buffered I/O | Phase 0, 1, 2 |
| **4: Concurrency** | 34–48 | 4.1–4.5 | Actors, Supervisors, Sessions, Tasks, Parallel | Phase 0, 1, 3 |
| **5: Propagators** | 49–57 | 5.1–5.3 | Cells, Propagators, Lattices, Scheduler | Phase 0, 1, 4 |
| **6: Logic** | 58–69 | 6.1–6.4 | Unification, Search, Tabling, CLP | Phase 0, 1, 5 |
| **7: Numerics** | 70–78 | 7.1–7.3 | BigInt, Posit, Quire, Numeric Tower | Phase 0, 1 |
| **8: Net/Serial** | 79–90 | 8.1–8.4 | TCP/UDP, EDN, JSON, Time, HTTP | Phase 0, 1, 2, 3, 4 |
| **9: Testing** | 91–102 | 9.1–9.4 | Test Framework, Property Testing, REPL | Phase 0, 1, 2, 3 |
| **10: Ecosystem** | 103–111 | 10.1–10.3 | FFI, Package Manager, Doc Generator | All above |

**Total**: ~111 weeks (~2.1 years) for a complete standard library, assuming a small team (2–3 developers). Phases 7–10 can partially overlap with each other (they have fewer inter-dependencies), potentially compressing the timeline to ~90 weeks (~1.7 years).

**Critical Path**: Phase 0 → Phase 1 → Phase 3 → Phase 4 → Phase 5 → Phase 6. This chain answers the key ordering question: **propagators (Phase 5) must precede the logic sub-language (Phase 6)**, and the actor runtime (Phase 4) must precede propagators.

**Milestone 1** (Week 18): Core language is usable — primitives, collections, iterators. Programs can be written and tested.

**Milestone 2** (Week 48): Concurrent language is usable — actors, channels, session types, parallel iterators. Distributed programs can be written.

**Milestone 3** (Week 69): Full language is usable — logic programming, constraint solving, propagator networks. The complete Πρόλογος paradigm is available.

**Milestone 4** (Week 111): Production-ready — networking, serialization, testing, FFI, packaging. The ecosystem can grow.

---

## 20. References

Bagwell, P. (2000). Ideal Hash Trees. EPFL Technical Report.

Bloch, J. (2018). Effective Java, 3rd Edition. Addison-Wesley.

Bloch, J. (2006). How to Design a Good API and Why it Matters. OOPSLA Companion.

Brady, E. (2021). Idris 2: Quantitative Type Theory in Practice. ECOOP 2021.

Clebsch, S. et al. (2017). Orca: GC and Type System Co-Design for Actor Languages. OOPSLA 2017.

Hickey, R. (2012). Simple Made Easy. Strange Loop Conference.

Hickey, R. (2012). The Value of Values. JaxConf.

Kelsey, R. (1995). A Correspondence Between Continuation-Passing Style and Static Single Assignment Form. ACM SIGPLAN Workshop on Intermediate Representations.

Matsakis, N. & Klock, F. (2014). The Rust Language. ACM SIGAda.

Moura, L. & Ullrich, S. (2021). The Lean 4 Theorem Prover and Programming Language. CADE-28.

Pike, R. (2012). Go at Google: Language Design in the Service of Software Engineering. SPLASH.

Radul, A. & Sussman, G. (2009). The Art of the Propagator. MIT CSAIL Technical Report.

Reinking, A. et al. (2021). Perceus: Garbage Free Reference Counting with Reuse. PLDI 2021.

Somogyi, Z. et al. (1996). The Execution Algorithm of Mercury. JLP.

Warren, D.H.D. (1983). An Abstract Prolog Instruction Set. SRI Technical Note 309.

Wielemaker, J. et al. (2012). SWI-Prolog. Theory and Practice of Logic Programming.
