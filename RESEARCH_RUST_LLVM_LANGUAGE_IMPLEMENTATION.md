# Research Report: Implementing Πρόλογος in Rust Targeting LLVM

## Advanced LLVM Techniques, Rust Compiler Infrastructure, and Concrete Strategies for a Dependently-Typed Functional-Logic Language

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [LLVM IR and the Type System Impedance Mismatch](#2-llvm-ir-and-the-type-system-impedance-mismatch)
   - 2.1 [LLVM IR Architecture and SSA Form](#21-llvm-ir-architecture-and-ssa-form)
   - 2.2 [The Opaque Pointer Transition](#22-the-opaque-pointer-transition)
   - 2.3 [Representing Dependent Types in LLVM IR](#23-representing-dependent-types-in-llvm-ir)
   - 2.4 [Representing Linear Types and Session Types](#24-representing-linear-types-and-session-types)
   - 2.5 [Metadata System for Semantic Preservation](#25-metadata-system-for-semantic-preservation)
3. [Advanced LLVM Features for Language Implementation](#3-advanced-llvm-features-for-language-implementation)
   - 3.1 [Garbage Collection: Statepoints, Stack Maps, and Safepoints](#31-garbage-collection-statepoints-stack-maps-and-safepoints)
   - 3.2 [Coroutines for Lightweight Actors](#32-coroutines-for-lightweight-actors)
   - 3.3 [Exception Handling and Backtracking](#33-exception-handling-and-backtracking)
   - 3.4 [Atomics and Memory Ordering for Concurrency](#34-atomics-and-memory-ordering-for-concurrency)
   - 3.5 [Debug Information Generation](#35-debug-information-generation)
   - 3.6 [Profile-Guided Optimization](#36-profile-guided-optimization)
   - 3.7 [Link-Time Optimization and ThinLTO](#37-link-time-optimization-and-thinlto)
   - 3.8 [Sanitizer Integration for Development](#38-sanitizer-integration-for-development)
4. [LLVM Pass Infrastructure](#4-llvm-pass-infrastructure)
   - 4.1 [The New Pass Manager Architecture](#41-the-new-pass-manager-architecture)
   - 4.2 [Writing Custom Optimization Passes](#42-writing-custom-optimization-passes)
   - 4.3 [Language-Specific Passes for Πρόλογος](#43-language-specific-passes-for-πρόλογος)
   - 4.4 [Pass Plugins and Pipeline Integration](#44-pass-plugins-and-pipeline-integration)
5. [LLVM Backend Infrastructure](#5-llvm-backend-infrastructure)
   - 5.1 [Instruction Selection: SelectionDAG and GlobalISel](#51-instruction-selection-selectiondag-and-globalisel)
   - 5.2 [Register Allocation Strategies](#52-register-allocation-strategies)
   - 5.3 [JIT Compilation with ORC JIT](#53-jit-compilation-with-orc-jit)
6. [MLIR: Multi-Level Intermediate Representation](#6-mlir-multi-level-intermediate-representation)
   - 6.1 [Why MLIR for Πρόλογος](#61-why-mlir-for-πρόλογος)
   - 6.2 [The Dialect System](#62-the-dialect-system)
   - 6.3 [Progressive Lowering Strategy](#63-progressive-lowering-strategy)
   - 6.4 [A Custom Πρόλογος MLIR Dialect](#64-a-custom-πρόλογος-mlir-dialect)
   - 6.5 [Relevant Built-In Dialects](#65-relevant-built-in-dialects)
7. [Rust as Implementation Language](#7-rust-as-implementation-language)
   - 7.1 [Rust LLVM Bindings: Inkwell and llvm-sys](#71-rust-llvm-bindings-inkwell-and-llvm-sys)
   - 7.2 [Cranelift as Alternative Backend](#72-cranelift-as-alternative-backend)
   - 7.3 [Melior: MLIR Bindings for Rust](#73-melior-mlir-bindings-for-rust)
   - 7.4 [Backend Abstraction Strategy](#74-backend-abstraction-strategy)
8. [Compiler Architecture in Rust](#8-compiler-architecture-in-rust)
   - 8.1 [Incremental Computation with Salsa](#81-incremental-computation-with-salsa)
   - 8.2 [Lexing with Logos](#82-lexing-with-logos)
   - 8.3 [Parsing: Chumsky, LALRPOP, and Alternatives](#83-parsing-chumsky-lalrpop-and-alternatives)
   - 8.4 [Arena Allocation for AST and IR Nodes](#84-arena-allocation-for-ast-and-ir-nodes)
   - 8.5 [String Interning with Lasso](#85-string-interning-with-lasso)
   - 8.6 [Index-Based Graphs for IR Representation](#86-index-based-graphs-for-ir-representation)
9. [Implementing the Type System](#9-implementing-the-type-system)
   - 9.1 [Bidirectional Type Checking Architecture](#91-bidirectional-type-checking-architecture)
   - 9.2 [Normalization by Evaluation (NbE)](#92-normalization-by-evaluation-nbe)
   - 9.3 [Unification with the Ena Crate](#93-unification-with-the-ena-crate)
   - 9.4 [QTT Multiplicity Checking](#94-qtt-multiplicity-checking)
   - 9.5 [Session Type Verification](#95-session-type-verification)
10. [Compiling Dependent Types](#10-compiling-dependent-types)
    - 10.1 [Idris 2's Compilation Pipeline](#101-idris-2s-compilation-pipeline)
    - 10.2 [Lean 4's LCNF Pipeline](#102-lean-4s-lcnf-pipeline)
    - 10.3 [Erasure Strategies: What Survives to Runtime](#103-erasure-strategies-what-survives-to-runtime)
    - 10.4 [QTT-Guided Code Generation](#104-qtt-guided-code-generation)
    - 10.5 [Whole-Program vs. Separate Compilation](#105-whole-program-vs-separate-compilation)
11. [Compiling Linear and Affine Types](#11-compiling-linear-and-affine-types)
    - 11.1 [Rust's MIR Borrow Checker as Case Study](#111-rusts-mir-borrow-checker-as-case-study)
    - 11.2 [Perceus: Garbage-Free Reference Counting](#112-perceus-garbage-free-reference-counting)
    - 11.3 [FBIP: Functional But In-Place](#113-fbip-functional-but-in-place)
    - 11.4 [Lean 4's Reset/Reuse Optimization](#114-lean-4s-resetreuse-optimization)
    - 11.5 [Deterministic Destruction Without GC](#115-deterministic-destruction-without-gc)
12. [Compiling Session Types](#12-compiling-session-types)
    - 12.1 [Runtime Representation of Session Channels](#121-runtime-representation-of-session-channels)
    - 12.2 [State Machine Encoding of Protocols](#122-state-machine-encoding-of-protocols)
    - 12.3 [Multiparty Session Type Projection](#123-multiparty-session-type-projection)
    - 12.4 [Channel Implementation Strategies](#124-channel-implementation-strategies)
13. [Compiling Logic Programming Features](#13-compiling-logic-programming-features)
    - 13.1 [The Warren Abstract Machine (WAM)](#131-the-warren-abstract-machine-wam)
    - 13.2 [Mercury's Compilation Strategy](#132-mercurys-compilation-strategy)
    - 13.3 [Compiling Unification to Native Code](#133-compiling-unification-to-native-code)
    - 13.4 [Choice Points, Backtracking, and the Trail](#134-choice-points-backtracking-and-the-trail)
    - 13.5 [Tabling and Memoization](#135-tabling-and-memoization)
    - 13.6 [Soufflé's Datalog Compilation via Futamura Projection](#136-soufflés-datalog-compilation-via-futamura-projection)
14. [Compiling Propagator Networks](#14-compiling-propagator-networks)
    - 14.1 [Runtime Representation of Cells and Propagators](#141-runtime-representation-of-cells-and-propagators)
    - 14.2 [Scheduler Implementation](#142-scheduler-implementation)
    - 14.3 [Compilation Strategies for Constraint Networks](#143-compilation-strategies-for-constraint-networks)
    - 14.4 [Connection to Incremental Computation](#144-connection-to-incremental-computation)
15. [Actor Runtime Implementation](#15-actor-runtime-implementation)
    - 15.1 [Work-Stealing Scheduler in Rust](#151-work-stealing-scheduler-in-rust)
    - 15.2 [Mailbox Strategies: Lock-Free and Segmented](#152-mailbox-strategies-lock-free-and-segmented)
    - 15.3 [FFI Between Rust Runtime and LLVM-Generated Code](#153-ffi-between-rust-runtime-and-llvm-generated-code)
    - 15.4 [Garbage Collector Integration](#154-garbage-collector-integration)
16. [Advanced Compilation Techniques](#16-advanced-compilation-techniques)
    - 16.1 [CPS vs. ANF vs. SSA: Choosing an IR](#161-cps-vs-anf-vs-ssa-choosing-an-ir)
    - 16.2 [Closure Conversion and Defunctionalization](#162-closure-conversion-and-defunctionalization)
    - 16.3 [Lambda Lifting](#163-lambda-lifting)
    - 16.4 [Partial Evaluation and the Futamura Projections](#164-partial-evaluation-and-the-futamura-projections)
    - 16.5 [Stream Fusion and Deforestation](#165-stream-fusion-and-deforestation)
17. [Error Reporting and Developer Experience](#17-error-reporting-and-developer-experience)
    - 17.1 [Rust-Style Diagnostics: Miette and Ariadne](#171-rust-style-diagnostics-miette-and-ariadne)
    - 17.2 [Span Tracking Through Compilation Stages](#172-span-tracking-through-compilation-stages)
    - 17.3 [Parser Error Recovery](#173-parser-error-recovery)
    - 17.4 [Language Server Protocol Integration](#174-language-server-protocol-integration)
18. [Testing and Quality Infrastructure](#18-testing-and-quality-infrastructure)
    - 18.1 [Snapshot Testing with Insta](#181-snapshot-testing-with-insta)
    - 18.2 [Property-Based Testing with Proptest](#182-property-based-testing-with-proptest)
    - 18.3 [Fuzzing with cargo-fuzz](#183-fuzzing-with-cargo-fuzz)
    - 18.4 [Benchmarking with Criterion](#184-benchmarking-with-criterion)
19. [Case Studies: Rust-Based Language Implementations](#19-case-studies-rust-based-language-implementations)
    - 19.1 [Roc: Functional Language with LLVM Backend](#191-roc-functional-language-with-llvm-backend)
    - 19.2 [Gleam: Functional Language with Multiple Targets](#192-gleam-functional-language-with-multiple-targets)
    - 19.3 [Cairo/Sierra: Provable Computation via MLIR](#193-cairosierra-provable-computation-via-mlir)
    - 19.4 [Mun: Hot-Reloading with LLVM](#194-mun-hot-reloading-with-llvm)
    - 19.5 [Boa: JavaScript Engine Architecture](#195-boa-javascript-engine-architecture)
20. [Concrete Architecture for the Πρόλογος Compiler](#20-concrete-architecture-for-the-πρόλογος-compiler)
    - 20.1 [Recommended Technology Stack](#201-recommended-technology-stack)
    - 20.2 [Compilation Pipeline Design](#202-compilation-pipeline-design)
    - 20.3 [Project Structure and Crate Organization](#203-project-structure-and-crate-organization)
    - 20.4 [Runtime System Architecture](#204-runtime-system-architecture)
    - 20.5 [Concrete Code Sketches](#205-concrete-code-sketches)
    - 20.6 [Compiler Error Messages for Πρόλογος](#206-compiler-error-messages-for-πρόλογος)
    - 20.7 [Phased Implementation Plan](#207-phased-implementation-plan)
21. [References and Further Reading](#21-references-and-further-reading)

---

## 1. Introduction

Implementing a programming language with the ambition of Πρόλογος — combining dependent types, session types, QTT linear types, actor-based concurrency, propagator networks, homoiconic syntax, and posit arithmetic — requires careful selection of implementation technology and deep understanding of the compilation targets. This report examines the two pillars of the Πρόλογος implementation strategy: **Rust** as the implementation language and **LLVM** as the compilation target.

Rust brings unique advantages for compiler implementation. Its ownership system prevents the memory safety bugs that plague C/C++ compilers, while its performance matches or approaches C++. The Rust ecosystem provides mature libraries for every stage of compiler construction: high-performance lexing (Logos), expressive parsing (Chumsky), incremental computation (Salsa), unification (Ena), arena allocation (Bumpalo), and LLVM bindings (Inkwell). Several production compilers — Roc, Gleam, Cairo, and Mun — demonstrate that Rust is a proven foundation for language implementation.

LLVM provides the most mature compilation infrastructure available. Its optimizer handles hundreds of transformation passes, its backends target every major architecture (x86-64, AArch64, RISC-V, WebAssembly), and its JIT infrastructure (ORC JIT) enables interactive development. However, LLVM's type system is deliberately low-level — it knows about integers, floats, pointers, and aggregates, but nothing about dependent types, linear ownership, session protocols, or propagator lattices. Bridging this "impedance mismatch" is the central challenge of the Πρόλογος backend, and MLIR (Multi-Level Intermediate Representation) offers a compelling solution through its extensible dialect system.

This report surveys the landscape comprehensively, then converges on a concrete architecture: a multi-crate Rust project using Inkwell for LLVM code generation, with a custom Rust runtime for actors, propagators, and garbage collection, linked with LLVM-generated user code through a well-defined FFI boundary.

---

## 2. LLVM IR and the Type System Impedance Mismatch

### 2.1 LLVM IR Architecture and SSA Form

LLVM IR (Intermediate Representation) is a strongly-typed, low-level, language-independent representation designed for optimization. All values are in Static Single Assignment (SSA) form: each variable is assigned exactly once, and PHI (Φ) nodes at control flow merge points select between values from different predecessors.

The LLVM type system is deliberately simple. Primitive types include arbitrary-width integers (`i1` through `i8192`), floating-point types (`half`, `float`, `double`, `fp128`), and `void`. Derived types include arrays (`[N x T]`), structures (`{T1, T2, ...}`), vectors (`<N x T>`), function types, and the universal opaque pointer type (`ptr`). There are no generics, no algebraic data types, no linear annotations, and no type-level computation.

Key instruction categories relevant to Πρόλογος include: terminator instructions (`ret`, `br`, `switch`, `invoke` for exception handling, `unreachable`), memory operations (`alloca` for stack allocation, `load`, `store`, `fence` for memory barriers, `cmpxchg` and `atomicrmw` for lock-free data structures), aggregate operations (`extractvalue`, `insertvalue` for structure field access), and the `call`/`invoke` pair for function calls (where `invoke` provides landing pads for exception handling, essential for backtracking).

### 2.2 The Opaque Pointer Transition

Since LLVM 15, all pointers are **opaque** (`ptr`) — they no longer carry pointee type information. Previously, `i32*` indicated a pointer to an `i32`; now, all pointers are simply `ptr`, and the type of the pointed-to value is specified at the `load`/`store` instruction.

This transition has significant implications for language implementors. Type-based alias analysis (TBAA) metadata must now be explicitly attached to memory operations to recover the type information that was previously embedded in pointer types. Recent research on Type-Alias Analysis (ISSTA 2025) proposes maintaining type-alias sets for IR variables through inference across instructions, allowing recovery of concrete type information even with opaque pointers.

For Πρόλογος, the opaque pointer transition is actually advantageous: since dependent type information was never representable in LLVM's pointer types anyway, the shift to opaque pointers with explicit metadata is closer to the compilation model Πρόλογος would adopt regardless — carry semantic information through metadata, not through LLVM's type system.

### 2.3 Representing Dependent Types in LLVM IR

The fundamental challenge is that LLVM IR has no concept of types that depend on values. A Πρόλογος type like `(Vec n Int)` — a vector of exactly `n` integers, where `n` is a runtime value — must be compiled to LLVM IR that uses only fixed types.

The primary strategy is **type erasure with witness values**. The dependent type index becomes a runtime value passed alongside the data:

```
;; Πρόλογος source
(def safe-head
  (forall (n : Nat)
    (-> (Vec (succ n) Int) Int)))

;; Compiled LLVM IR (conceptual)
;; The type (Vec (succ n) Int) becomes a pointer + length witness
define i64 @safe_head(ptr %vec_data, i64 %length) {
  ;; The type checker has verified length >= 1
  ;; so this load is statically known to be safe
  %result = load i64, ptr %vec_data
  ret i64 %result
}
```

The key insight is that the *type checker* (running at compile time, in Rust) verifies all dependent type invariants. By the time LLVM sees the code, all proofs have been checked and erased — LLVM generates efficient code without dependent type overhead.

For data types indexed by type-level values, the compiler generates tagged unions:

```
;; Πρόλογος: (data (Maybe a) (nothing) (just a))
;; LLVM: tagged union with discriminant
%Maybe = type { i8, [8 x i8] }  ;; tag + payload
;; tag 0 = nothing, tag 1 = just
```

### 2.4 Representing Linear Types and Session Types

Linear types (QTT multiplicities) are enforced entirely at compile time and leave minimal runtime trace. The key representation strategies:

**0-multiplicity (erased)**: These values do not exist at runtime. The Πρόλογος compiler removes them entirely during erasure, and LLVM never sees them. This includes type indices, proof terms, and other computationally irrelevant bindings.

**1-multiplicity (linear)**: These values are used exactly once. In LLVM IR, this maps naturally to SSA: an SSA value is defined once and used once (or not at all, if dead-code eliminated). The compiler ensures that linear values are moved (not copied) through the program, which LLVM represents as normal value passing — no reference counting needed.

**ω-multiplicity (unrestricted)**: These values may be used any number of times. They require either reference counting (for heap-allocated values) or copying (for small values). The compiler inserts explicit `rc_increment` and `rc_decrement` calls in LLVM IR.

Session types are tracked entirely at compile time. At runtime, a session-typed channel is simply a pair of pointers (to lock-free queues), with send/receive operations compiled to enqueue/dequeue calls. The protocol state machine is erased — it exists only during type checking.

### 2.5 Metadata System for Semantic Preservation

LLVM's metadata system provides a mechanism for carrying information that does not affect semantics but aids optimization and debugging. Metadata is attached to instructions, functions, or modules as named or numbered metadata nodes.

For Πρόλογος, custom metadata can preserve semantic information through the LLVM pipeline:

**Type metadata** encodes dependent type relationships for custom analysis passes. **Multiplicity metadata** marks values with their QTT multiplicity, enabling a custom LLVM pass to verify that linear values are not duplicated. **Session state metadata** records the protocol state at each channel operation for debugging. **Propagator metadata** marks propagator activation calls for scheduler integration.

The metadata approach has a key limitation: LLVM optimization passes may duplicate, move, or eliminate instructions, and metadata must be designed to remain valid under these transformations. For correctness-critical information, witness values (actual runtime values) are preferred over metadata.

---

## 3. Advanced LLVM Features for Language Implementation

### 3.1 Garbage Collection: Statepoints, Stack Maps, and Safepoints

LLVM provides explicit safepoint tracking for GC integration through the `llvm.experimental.gc.statepoint` intrinsic. At each safepoint, the runtime can identify all live heap pointers on the stack.

The statepoint mechanism works as follows. The compiler inserts statepoint intrinsic calls at potential GC points (function calls, loop back-edges, allocation sites). Each statepoint records which SSA values are live GC pointers. After a statepoint, every GC pointer must be re-read through `llvm.experimental.gc.relocate`, because the GC may have moved the object.

```
;; Before GC-safe call
%token = call token @llvm.experimental.gc.statepoint(
  i64 0, i32 0,                    ;; ID, num patch bytes
  ptr @callee,                      ;; function to call
  i32 0,                            ;; num call args
  i32 0,                            ;; flags
  ptr %live_ref1, ptr %live_ref2)   ;; live GC references

;; After: relocate pointers (GC may have moved objects)
%ref1_new = call ptr @llvm.experimental.gc.relocate(
  token %token, i32 0, i32 0)
%ref2_new = call ptr @llvm.experimental.gc.relocate(
  token %token, i32 1, i32 1)
```

For Πρόλογος, the per-actor heap model means most GC is actor-local. Statepoints are needed primarily for Tier 2 (per-actor generational GC) and Tier 3 (ORCA cross-actor protocol). Tier 0 (erased) and Tier 1 (linear/deterministic) objects do not need GC tracking.

An alternative to statepoints is the **shadow stack** approach (`@llvm.gcroot`): a linked list of stack frames, each containing pointers to GC roots. Shadow stacks are simpler to implement but add overhead to every function call. For a prototype, shadow stacks are recommended; for production, statepoints provide better performance.

### 3.2 Coroutines for Lightweight Actors

LLVM's coroutine intrinsics (`llvm.coro.*`) enable stackless resumable functions — the ideal mechanism for implementing lightweight actors and propagator suspensions.

The coroutine lifecycle uses four key intrinsics. `llvm.coro.id` initializes the coroutine frame, identifying the promise object and alignment. `llvm.coro.begin` allocates the frame buffer (or obtains it from a pre-allocated pool). `llvm.coro.suspend` suspends execution, returning a value indicating whether to resume (0), destroy (1), or use the default path. `llvm.coro.end` finalizes the coroutine.

LLVM's coroutine passes split a single coroutine function into multiple functions: a **ramp function** (executes until the first suspend), a **resume function** (continues from the last suspension point), and a **destroy function** (cleans up the coroutine frame). The frame (containing local variables that survive suspension) is heap-allocated.

For Πρόλογος actors, each actor's message processing loop is a coroutine. When the mailbox is empty, the actor suspends (via `llvm.coro.suspend`). When a message arrives, the scheduler resumes the coroutine. This is dramatically cheaper than allocating a full OS thread per actor — coroutine frames are typically a few hundred bytes versus 1-8 MB for a thread stack.

### 3.3 Exception Handling and Backtracking

LLVM provides two exception handling models: the **landingpad model** (traditional, used by C++ and most languages) and the newer **pad model** (`catchswitch`, `catchpad`, `cleanuppad`) for more structured EH.

For Πρόλογος, exception handling serves double duty: it handles actual errors (type mismatches, division by zero) and implements **backtracking** in logic programming search.

The landingpad model works as follows. A function call that might fail uses `invoke` instead of `call`, specifying both a normal continuation and an unwind destination:

```
invoke void @try_unify(ptr %term1, ptr %term2)
  to label %success unwind label %backtrack

success:
  ;; Unification succeeded, continue
  ...

backtrack:
  %exc = landingpad { ptr, i32 }
    catch ptr @unification_failure_type
  ;; Restore trail, try next clause
  call void @restore_trail(ptr %trail_mark)
  br label %next_clause
```

A custom **personality function** implements Πρόλογος-specific unwinding semantics: when backtracking, the personality function restores variable bindings from the trail stack and transitions to the next choice point.

### 3.4 Atomics and Memory Ordering for Concurrency

LLVM provides six memory ordering levels for atomic operations, matching the C11/C++11 memory model. For Πρόλογος's actor-based concurrency:

**Monotonic** (relaxed) ordering suffices for actor-local counters and statistics — no synchronization guarantees, only atomicity.

**Acquire/Release** ordering is appropriate for message passing between actors: the sender performs a `release` store to the mailbox, and the receiver performs an `acquire` load. This ensures that all writes made by the sender before the send are visible to the receiver after the receive.

**SequentiallyConsistent** ordering is needed only for shared choice points in parallel logic programming, where all threads must agree on the order of operations.

The key atomic instructions are: `load atomic` and `store atomic` for atomic reads/writes, `cmpxchg` (compare-and-swap) for lock-free data structures like actor mailboxes and propagator cells, and `atomicrmw` (atomic read-modify-write) for reference count updates (`atomicrmw add` for increment, `atomicrmw sub` for decrement).

### 3.5 Debug Information Generation

LLVM generates DWARF debug information (or CodeView on Windows) through metadata attached to instructions and functions. Key metadata types include `DICompileUnit` (one per source file), `DISubprogram` (one per function/predicate), `DILocation` (source line and column for each instruction), and `DILocalVariable` (mapping SSA values to source-level variable names).

For Πρόλογος, debug information must bridge the gap between high-level constructs and compiled code. Predicate definitions map to `DISubprogram`. Clause boundaries map to `DILocation` entries, enabling debuggers to step through clause selection. Propagator activations can be annotated with metadata linking to the source constraint. Actor message processing can be traced by annotating the message dispatch loop.

**Dependent Type Indices in Debug Information.** A key challenge is representing dependent types in DWARF, which has no concept of types that depend on values. The strategy is to encode witness values — the runtime representations of type indices — as `DILocalVariable` entries with custom annotations. For example, a function parameter `(v : (Vec n Int))` compiles to two LLVM parameters: `%vec_data` (the data pointer) and `%n` (the length witness). The debug info encodes both, with a custom `DW_AT_prologos_dependent_index` attribute linking the witness `%n` to the data `%vec_data`. A Πρόλογος-aware debugger plugin can then reconstruct the full dependent type, displaying `(Vec 5 Int)` rather than just `ptr`.

For 0-multiplicity (erased) values — proof terms, type indices used only for type checking — no debug info is emitted, since these values do not exist at runtime. However, the compiler records their erased source-level types in a separate debug section (`DW_AT_prologos_erased_binding`), enabling the debugger to display a note like `<erased: n : Nat, used at compile time only>` when the user inspects the source. This approach preserves the debugging experience for dependent types without compromising the zero-cost erasure guarantee.

### 3.6 Profile-Guided Optimization

LLVM's PGO infrastructure operates in two phases. First, the compiler inserts instrumentation counters at branch points and function entries (`-fprofile-generate`). The instrumented binary is run on representative workloads, generating `.profraw` files. Second, the `llvm-profdata` tool merges raw profiles into `.profdata` format, which the compiler reads during recompilation (`-fprofile-use`) to guide inlining, branch prediction, code layout, and vectorization decisions.

For Πρόλογος, PGO is especially valuable for logic programming: predicate call frequencies vary enormously based on the query pattern, and profile data enables the compiler to optimize hot clause selection paths. The profile metadata (`!prof` with `branch_weights`) can also guide the propagator scheduler's priority decisions.

### 3.7 Link-Time Optimization and ThinLTO

**Full LTO** merges all compilation units into a single LLVM module before optimization, enabling aggressive cross-module inlining, dead code elimination, and interprocedural optimization. The cost is long link times and high memory usage.

**ThinLTO** provides most of the benefits with dramatically better scalability. Each module generates a summary containing function signatures, call counts, and type information. At link time, the linker reads all summaries, decides which functions to import across module boundaries, and performs targeted cross-module optimization — without merging all modules into a single IR.

For Πρόλογος, ThinLTO is recommended: it enables cross-module predicate inlining (critical for logic programming performance) while maintaining fast incremental builds. The compiler should emit one LLVM module per Πρόλογος source file, with ThinLTO handling inter-module optimization.

### 3.8 Sanitizer Integration for Development

LLVM's sanitizers are invaluable during Πρόλογος development:

**AddressSanitizer (ASan)** detects use-after-free, buffer overflows, and stack buffer overflows. For Πρόλογος, ASan catches bugs in the runtime's memory management — particularly important when debugging the per-actor GC and propagator cell allocation.

**ThreadSanitizer (TSan)** detects data races. For Πρόλογος, TSan is critical for verifying that the actor model correctly prevents shared mutable access and that the propagator scheduler's work-stealing is race-free.

**MemorySanitizer (MSan)** detects reads of uninitialized memory. For Πρόλογος, MSan catches bugs in unification (reading unbound variables) and propagator cell initialization.

---

## 4. LLVM Pass Infrastructure

### 4.1 The New Pass Manager Architecture

LLVM's New Pass Manager (NPM), standard since LLVM 12 with the legacy PM fully deprecated in LLVM 14, uses concept-based polymorphism rather than virtual inheritance. Passes are organized in a hierarchy of IR units: Module → CGSCC (Call Graph Strongly Connected Component) → Function → Loop.

Each pass implements a `run()` method that takes an IR unit and its analysis manager, performs transformations, and returns a `PreservedAnalyses` value indicating which analysis results remain valid. The analysis manager lazily computes and caches analysis results (dominator trees, loop info, alias analysis) and invalidates them when passes modify the IR.

### 4.2 Writing Custom Optimization Passes

Custom passes for Πρόλογος can implement language-specific optimizations that LLVM's generic passes cannot perform:

A **tail call recognition pass** identifies tail-recursive predicate calls and marks them with the `musttail` attribute, ensuring LLVM generates a jump rather than a call. This is critical for logic programming, where predicates often recurse deeply.

A **reference count elision pass** analyzes the lifetime of reference-counted objects and removes redundant increment/decrement pairs. Given QTT metadata on instructions, the pass can verify that 1-multiplicity values never need reference counting.

A **propagator fusion pass** identifies chains of propagators where the output of one is the sole input of the next, and fuses them into a single function call, eliminating intermediate cell allocations.

### 4.3 Language-Specific Passes for Πρόλογος

Several custom LLVM passes would benefit Πρόλογος specifically:

**Session protocol validation pass**: Using session state metadata, verify that channel operations in the compiled code match the expected protocol at each program point. This pass is a debugging aid — it re-checks at the LLVM level what the type checker already verified, catching bugs in the compiler itself.

**Linear value duplication check**: Using multiplicity metadata, verify that no 1-multiplicity value is used more than once in the compiled code. Again, this is a compiler self-check.

**Unification caching pass**: Identify repeated unification patterns (e.g., the same predicate called with the same structure of arguments) and insert caching logic to avoid redundant computation.

### 4.4 Pass Plugins and Pipeline Integration

LLVM supports dynamically loaded pass plugins. A Πρόλογος-specific plugin can register passes at various extension points in the optimization pipeline: `registerPipelineStartEPCallback` for early passes (protocol validation), `registerOptimizerLastEPCallback` for late passes (RC elision, after all other optimizations), and `registerVectorizerStartEPCallback` for pre-vectorization passes (loop structure annotation for posit arithmetic).

---

## 5. LLVM Backend Infrastructure

### 5.1 Instruction Selection: SelectionDAG and GlobalISel

LLVM provides three instruction selection strategies. **FastISel** performs rapid instruction selection at `-O0` with minimal analysis — approximately 10% slower generated code than optimized, but very fast compilation. **SelectionDAG** is the traditional approach: convert LLVM IR to a DAG representation, perform type and operation legalization, DAG-combine optimizations, and instruction tiling. SelectionDAG is mature and generates good code but compiles slowly. **GlobalISel** is the emerging replacement: a modular pipeline of IR-to-machine-IR passes (legalize, register bank select, instruction select) that offers better compile times and extensibility.

For Πρόλογος, SelectionDAG is the recommended default (mature, well-tested). FastISel should be used for debug builds to speed up the development cycle. GlobalISel can be evaluated as it matures, particularly if Πρόλογος needs to target architectures where SelectionDAG coverage is incomplete (e.g., RISC-V extensions for posit arithmetic).

### 5.2 Register Allocation Strategies

LLVM provides multiple register allocation algorithms. The **Greedy** allocator (default at `-O2`/`-O3`) uses iterative coalescing with priority-based spilling — it produces the best code quality. The **Fast** allocator (default at `-O0`) uses a linear scan approach that compiles quickly. The **PBQP** (Partitioned Boolean Quadratic Problem) allocator models register allocation as a mathematical optimization problem and can handle complex architectural constraints, but is rarely faster than Greedy in practice.

For Πρόλογος, the default Greedy allocator is appropriate. The compiler should ensure that hot paths (inner loops, frequently-called predicates) are structured to minimize register pressure — this means avoiding deep nesting of live values and using explicit stack spills for large propagator activations.

### 5.3 JIT Compilation with ORC JIT

ORC JIT (On-Request Compilation) v2 is LLVM's state-of-the-art JIT framework. It supports lazy compilation (functions compiled only when first called), concurrent compilation (multiple functions compiled in parallel), and incremental addition of new code (essential for a REPL).

For Πρόλογος, ORC JIT enables several important features. An **interactive REPL** for exploring logic queries and testing predicates — each user-entered expression is compiled to a fresh LLVM module, added to the JIT, and executed. **Dynamic predicate addition** allows new clauses to be compiled and linked into the running program. **Hot code swapping** for development: recompile changed predicates and swap them into the running system.

The key ORC JIT APIs are: `LLJIT` (high-level wrapper for simple JIT scenarios), `LazyCallThroughManager` (for lazy compilation of functions), and `MaterializationUnit` (for custom compilation strategies). ORC JIT handles symbol resolution across dynamically-added modules, making it possible to incrementally grow a Πρόλογος program.

---

## 6. MLIR: Multi-Level Intermediate Representation

### 6.1 Why MLIR for Πρόλογος

MLIR addresses a fundamental limitation of direct LLVM IR emission: the semantic gap. When Πρόλογος source code is lowered directly to LLVM IR, all high-level information — dependent type indices, session protocol states, propagator network topology, lattice merge operations — is irrecoverably lost. Optimizations that depend on this information (propagator fusion, session-aware scheduling, CALM monotonicity analysis) become impossible.

MLIR's solution is **multiple levels of abstraction**. Instead of a single lowering step from Πρόλογος to LLVM IR, MLIR enables a cascade of progressively lower representations. At each level, domain-specific optimizations can be applied while the relevant semantic information is still available. Information is discarded only when it is no longer useful.

### 6.2 The Dialect System

MLIR's core extensibility mechanism is the **dialect**: a modular collection of operations, types, and attributes. Dialects can define custom operations with custom semantics, and MLIR's infrastructure handles verification, printing, parsing, and transformation uniformly.

A Πρόλογος MLIR dialect would define operations for the language's unique constructs — unification, propagator activation, session channel operations, actor message dispatch — while leveraging existing dialects for common infrastructure.

### 6.3 Progressive Lowering Strategy

The recommended lowering pipeline for Πρόλογος through MLIR:

```
Πρόλογος Source
    ↓ (Parser + Elaborator in Rust)
Πρόλογος AST (with dependent types verified)
    ↓ (Lower to MLIR)
Πρόλογος Dialect + SCF + Async + Arith
    ↓ (Propagator fusion, CALM analysis, session optimization)
SCF + Async + Arith + MemRef
    ↓ (Loop optimization, vectorization)
Affine + Arith + MemRef (for numerical kernels)
    ↓ (Lower to LLVM dialect)
LLVM Dialect
    ↓ (Export to LLVM IR)
LLVM IR
    ↓ (LLVM optimizer + backend)
Native Code
```

At each step, domain-specific optimizations are applied before the relevant information is lowered away. Propagator fusion happens at the Πρόλογος dialect level. Loop tiling happens at the Affine level. Instruction selection happens at the LLVM level.

### 6.4 A Custom Πρόλογος MLIR Dialect

A Πρόλογος-specific MLIR dialect would define operations such as:

```
// Unification operation
prologos.unify %left, %right : !prologos.term -> i1

// Propagator cell operations
%cell = prologos.cell.create : !prologos.cell<IntInterval>
prologos.cell.merge %cell, %value : !prologos.cell<IntInterval>, !prologos.interval

// Actor operations
%actor = prologos.actor.spawn @handler_fn : !prologos.actor<Protocol>
prologos.actor.send %actor, %msg : !prologos.actor<Protocol>, !prologos.msg

// Session channel operations
%ch = prologos.session.open : !prologos.channel<FileTransfer>
prologos.session.send %ch, %data : !prologos.channel<!Int.S>, i64
%val, %ch2 = prologos.session.recv %ch : !prologos.channel<?Int.S>

// Choice point for backtracking
prologos.choice [
  ^clause1(%arg : !prologos.term),
  ^clause2(%arg : !prologos.term),
  ^clause3(%arg : !prologos.term)
]
```

This dialect preserves the full semantics of Πρόλογος constructs, enabling optimizations that would be impossible at the LLVM IR level.

### 6.5 Relevant Built-In Dialects

Several MLIR built-in dialects are directly useful:

**SCF (Structured Control Flow)** provides `scf.for`, `scf.while`, `scf.if`, and critically `scf.parallel` — a parallel loop construct that represents iteration spaces executable in any order. This maps directly to Πρόλογος's automatically parallelized collection operations.

**Async** provides `async.execute` and `async.await` for concurrent operations. Actor message processing and propagator activations can be represented as async operations.

**Affine** provides polyhedral loop optimization. Numerical kernels using posit arithmetic can be represented using `affine.for` with affine index expressions, enabling loop tiling and vectorization.

**Linalg** provides structured linear algebra operations. Tensor and matrix operations with posit arithmetic can use Linalg for high-level optimization before lowering to loops.

**LLVM dialect** provides the bridge to LLVM IR — all operations lower to this dialect before export to LLVM IR for final code generation.

---

## 7. Rust as Implementation Language

### 7.1 Rust LLVM Bindings: Inkwell and llvm-sys

**Inkwell** is the recommended high-level Rust binding for LLVM. It provides a strongly-typed, safe API over LLVM's C interface, supporting LLVM versions 11 through 21 via feature flags (`llvm11-0` through `llvm21-0`). Inkwell's type system prevents many classes of LLVM misuse at compile time — passing an `IntValue` where a `FloatValue` is expected is a Rust type error, not a runtime crash.

Key Inkwell APIs for Πρόλογος include: `Module` for creating LLVM modules, `Builder` for emitting instructions, `Context` for managing LLVM types and values, `FunctionValue` for function definitions, and `PassManager` for running optimization passes.

**llvm-sys** provides raw FFI bindings to LLVM's C API via bindgen. It is lower-level than Inkwell and requires `unsafe` blocks for every call, but provides access to every LLVM C API function. Use llvm-sys when Inkwell does not expose a specific LLVM feature — for example, statepoint intrinsics, coroutine intrinsics, or custom metadata creation.

The version mapping convention is `llvm-sys-{major}{minor}1` — e.g., `llvm-sys-191` for LLVM 19.1.x. Both crates require `llvm-config` from the target LLVM version to be available at build time.

### 7.2 Cranelift as Alternative Backend

Cranelift is a code generator designed for fast compilation rather than maximum code quality. Developed by the Bytecode Alliance for WebAssembly runtimes (Wasmtime, Wasmer), Cranelift compiles approximately 10× faster than LLVM while generating code that is roughly 2% slower.

For Πρόλογος, Cranelift serves as a **development backend**: during the iterative cycle of writing, compiling, and testing Πρόλογος programs, fast compilation is more important than optimal code. The production backend (LLVM) is used for release builds.

The Rust compiler itself uses Cranelift as an optional backend (`rustc_codegen_cranelift`) for debug builds, demonstrating the viability of this dual-backend approach.

### 7.3 Melior: MLIR Bindings for Rust

Melior provides Rust bindings for MLIR, enabling Πρόλογος to define custom MLIR dialects and emit MLIR from Rust code. The Cairo Native project (StarkNet) uses Melior to compile Sierra IR through MLIR to LLVM IR, demonstrating that the Melior crate is production-viable for this use case.

Melior requires LLVM 19+ with MLIR extensions built. For the initial Πρόλογος prototype, direct LLVM IR emission via Inkwell is simpler; MLIR via Melior becomes valuable when the compiler needs multi-level optimization (Phase 3-4 of the implementation plan).

### 7.4 Backend Abstraction Strategy

The compiler should abstract over the code generation backend using a trait:

```
;; Rust architecture (conceptual, shown in Prologos syntax for consistency)
(trait CodegenBackend
  (fn compile-module (self ir : Module) (Result (Vec u8)))
  (fn jit-execute (self ir : Module name : String) (Result Value)))

(impl CodegenBackend InkwellBackend ...)
(impl CodegenBackend CraneliftBackend ...)
(impl CodegenBackend MeliorBackend ...)  ;; future MLIR path
```

This enables switching backends based on the compilation mode (debug vs. release) without changing the rest of the compiler.

---

## 8. Compiler Architecture in Rust

### 8.1 Incremental Computation with Salsa

Salsa is an incremental computation framework used by rust-analyzer (the Rust IDE support tool). It automatically tracks dependencies between function calls and caches results, recomputing only what has changed.

For Πρόλογος, Salsa provides incremental type checking — critical for IDE responsiveness. When a user modifies one function, Salsa determines which type-checking results are affected and recomputes only those, leaving unaffected results cached.

Salsa's architecture uses two types of queries: **input queries** (user-provided data, like source file contents) and **derived queries** (computed from other queries, like parse trees, type-checked modules). An "early cutoff" optimization means that if a derived query's result is unchanged despite its inputs changing, downstream queries are not recomputed.

### 8.2 Lexing with Logos

Logos compiles token definitions to a jump-table-driven state machine at compile time, achieving throughput of over 1 GB/s. Token definitions use Rust derive macros:

```
;; Prologos lexer tokens (conceptual Rust, described in Prologos terms)
;; #[derive(Logos)] on a Token enum with regex patterns:
;; Identifier: [a-z][a-z0-9_-]*
;; LParen: "("
;; RParen: ")"
;; Number: [0-9]+
;; String: "\"[^\"]*\""
;; Keyword/def: "def"
;; Keyword/fn: "fn"
;; Keyword/forall: "forall"
;; Comment: ";; ..." (skip)
;; Whitespace (with significance tracking for indentation)
```

Logos prevents backtracking and batches character reads, making it ideal for Πρόλογος's relatively simple token structure (parenthesized prefix notation with significant whitespace).

### 8.3 Parsing: Chumsky, LALRPOP, and Alternatives

**Chumsky** is a parser combinator library with excellent error recovery. For Πρόλογος's homoiconic S-expression-like syntax, Chumsky's composability is a good fit: each syntactic form is a small combinator that can be composed into larger parsers. Chumsky's error recovery means the parser can report multiple errors per file rather than halting on the first — essential for IDE integration.

**LALRPOP** is a parser generator for LR(1) grammars. It is faster than Chumsky for large files but has less ergonomic error recovery. LALRPOP would be appropriate if Πρόλογος's syntax can be expressed as a context-free grammar.

For the recommended approach: start with Chumsky for the prototype (better error messages, easier to modify as the syntax evolves), then evaluate LALRPOP for performance if parsing becomes a bottleneck.

### 8.4 Arena Allocation for AST and IR Nodes

**Bumpalo** is the recommended arena allocator. It provides fast heterogeneous allocation (just pointer bump) with excellent cache locality. All AST nodes for a compilation unit are allocated in a single arena; when compilation is complete, the entire arena is freed at once.

The key advantage for compiler implementation: arena-allocated AST nodes can contain references to each other (forming a tree) without worrying about individual lifetimes — all nodes live as long as the arena. This eliminates the need for `Rc` or `Arc` on AST nodes.

**Typed-Arena** is an alternative that provides separate arenas per type (one arena for expressions, one for patterns, one for types). This is simpler but leads to more fragmentation. For Πρόλογος, Bumpalo's single-arena approach is preferred.

### 8.5 String Interning with Lasso

String interning replaces repeated string comparisons with integer comparisons. The **Lasso** crate provides both single-threaded (`Rodeo`) and thread-safe (`ThreadedRodeo`) interners.

For Πρόλογος, all identifiers (variable names, predicate names, module names, namespace paths) should be interned. This makes equality checks O(1) and significantly reduces memory usage for programs with many repeated names — common in logic programming where predicate names recur frequently.

### 8.6 Index-Based Graphs for IR Representation

**Petgraph** provides a graph data structure with stable `NodeIndex` and `EdgeIndex` handles. For Πρόλογος, petgraph serves as the foundation for control flow graphs, data dependency graphs, and propagator network topology.

An alternative pattern used by rustc is the **index-based arena**: nodes are stored in a `Vec`, and references between nodes use indices (essentially handles). This provides stable references (indices remain valid as the vector grows) with excellent cache locality. The `index_vec` crate provides convenient wrappers for this pattern.

---

## 9. Implementing the Type System

### 9.1 Bidirectional Type Checking Architecture

Bidirectional type checking (Pierce and Turner, 2000) splits type checking into two modes: **checking** (the expected type is known, and the term is checked against it) and **inference** (the term is analyzed to determine its type). This split reduces the annotation burden on programmers while keeping type checking decidable.

For Πρόλογος, the bidirectional architecture processes the surface syntax as follows. Function definitions with type annotations use checking mode: the body is checked against the declared type. Function applications use inference mode: the function's type is inferred, then each argument is checked against the expected argument type. Lambda expressions use checking mode if an expected type is available, or require annotation otherwise.

The elaborator transforms surface syntax into a fully-annotated core term where all types are explicit and all implicit arguments are filled in. The core language is a variant of Quantitative Type Theory with dependent functions (Π-types), dependent pairs (Σ-types), universes, and inductive data types.

### 9.2 Normalization by Evaluation (NbE)

Definitional equality in dependent type theory requires normalizing terms to a canonical form and comparing. NbE (Normalization by Evaluation) leverages the host language's (Rust's) evaluation mechanism to perform normalization efficiently.

The NbE process has two phases. **Evaluation** converts syntax (terms) to semantic values: closures, neutral terms (variables applied to arguments), and data constructors. **Quotation** (readback) converts semantic values back to syntax, producing a β-normal η-long form.

Two terms are definitionally equal if and only if their quoted normal forms are syntactically identical. This is the core of the Πρόλογος type checker's equality check.

The key data types in a Rust NbE implementation are: `Term` (syntax — variables, lambdas, applications, etc.), `Value` (semantics — closures, neutral terms, constructors), and `Env` (evaluation environment mapping variables to values).

### 9.3 Unification with the Ena Crate

The **Ena** crate provides Tarjan's union-find algorithm with path compression and union by rank. For Πρόλογος, Ena implements the unification variables used during type inference and elaboration.

When the type checker encounters an implicit argument (a type that must be inferred), it creates a fresh unification variable. As type checking proceeds, constraints are accumulated: "this unification variable must be equal to Int," "these two unification variables must be equal." Ena's union-find efficiently maintains equivalence classes of unification variables and detects when a constraint is unsatisfiable (unification failure).

For first-order unification (needed at runtime for logic programming), Ena is also appropriate. For higher-order unification (needed during type checking for dependent types), Ena provides the base mechanism, supplemented with Miller's pattern unification algorithm for decidable fragments and heuristic search for the general case.

### 9.4 QTT Multiplicity Checking

QTT multiplicity checking extends the standard type checking algorithm with a resource-counting discipline. Each variable in the context is annotated with a multiplicity (0, 1, or ω), and the type checker verifies that each variable is used a number of times consistent with its multiplicity.

The multiplicity algebra is: 0 + 0 = 0, 0 + 1 = 1, 1 + 1 = ω, anything + ω = ω. The scaling operation is: 0 · anything = 0, 1 · x = x, ω · 0 = 0, ω · anything-else = ω.

In the typing rule for function application `f x`, if `f` has type `(a :_π A) → B`, then the resources consumed by `x` are scaled by π. If π = 0, the argument is erased (used 0 times, for type-level computation). If π = 1, the argument is linear (used exactly once). If π = ω, the argument is unrestricted.

The type checker maintains a **usage environment** that tracks how many times each variable has been used. At each variable occurrence, the usage count is incremented. At the end of a scope, the checker verifies that each variable's usage count matches its declared multiplicity.

### 9.5 Session Type Verification

Session type verification extends the type checker with a protocol-state tracking mechanism. Each channel variable has a session type that describes the remaining protocol. As operations are performed on the channel (send, receive, choice), the session type evolves.

The key verification rules are: after `(send ch v)` where `ch : (Chan (! T . S))`, the channel's type becomes `(Chan S)`. After `(let (v (recv ch)))` where `ch : (Chan (? T . S))`, the value `v` has type `T` and the channel's type becomes `(Chan S)`. At `end`, the channel's type must be `(Chan end)` — the protocol is complete.

Linearity (from QTT) ensures that each channel endpoint is used by exactly one actor, preventing races. The combination of session types and linearity provides static guarantees of protocol compliance and data-race freedom.

---

## 10. Compiling Dependent Types

### 10.1 Idris 2's Compilation Pipeline

Idris 2 provides the canonical compilation pipeline for a dependently-typed language with QTT:

**Source → Elaboration → TT (Core Language) → Named IR → Lambda-Lifted IR → ANF → Target Code**

The elaboration phase transforms surface syntax into the core type theory (TT), filling in implicit arguments, resolving overloading, and checking types. The TT representation preserves full dependent type information.

The Named IR phase performs the critical **erasure analysis**: 0-multiplicity arguments are removed from data constructors and function definitions. The resulting IR has no computationally-irrelevant type indices — only runtime-relevant values survive.

Lambda Lifting converts nested functions to top-level definitions, adding captured variables as extra parameters. ANF (A-Normal Form) flattens all intermediate computations into explicit let-bindings, preparing for imperative code generation.

### 10.2 Lean 4's LCNF Pipeline

Lean 4 uses LCNF (Lean Compiler Normal Form), an A-normal form variant optimized for reference-counted functional programming:

**Lean → LCNF → IR (with explicit RC ops) → C or LLVM**

LCNF preserves enough structure for powerful functional optimizations: join point insertion (identifying loops), function specialization (monomorphization), and most critically, the **reset/reuse optimization**. When an object's reference count is 1 (unique), and it will be consumed to produce a new object of the same size, the memory can be reused in-place — converting a functional update into a destructive update with zero allocation.

For Πρόλογος, Lean 4's pipeline demonstrates how reference counting, guided by multiplicity information, can achieve performance competitive with manual memory management.

### 10.3 Erasure Strategies: What Survives to Runtime

The erasure strategy determines what dependent type information is preserved at runtime:

**Fully erased** (0-multiplicity): Type indices, proof terms, and computationally-irrelevant arguments are removed entirely. For example, in `(Vec n Int)`, the length index `n` might be erased if it can be reconstructed from the runtime representation.

**Partially preserved** (witness values): Some type indices are preserved as runtime values because they are needed for computation. For example, if a function dispatches on the type index (e.g., choosing different algorithms for different-length vectors), the index must survive to runtime.

**Fully preserved** (for reflection/metaprogramming): In Πρόλογος's homoiconic system, code-as-data requires preserving type information for terms that will be inspected at runtime.

The compiler performs an erasure analysis pass after type checking: for each 0-multiplicity binding, verify that it is not needed at runtime; for each binding that is needed, compute its runtime representation.

### 10.4 QTT-Guided Code Generation

QTT multiplicities directly guide the code generator's decisions:

**0-multiplicity → no code generated.** The binding exists only during type checking and is erased. Constructors omit 0-multiplicity fields. Function calls omit 0-multiplicity arguments.

**1-multiplicity → move semantics, no reference counting.** The value is consumed exactly once, so no reference count is needed. The compiler generates a direct move (pointer copy without RC increment). Deallocation occurs immediately after the single use.

**ω-multiplicity → reference counting or GC.** The value may be shared, so reference counting tracks its lifetime. The compiler inserts `rc_inc` before each additional use and `rc_dec` when a use goes out of scope. When the count reaches zero, the value is deallocated.

### 10.5 Whole-Program vs. Separate Compilation

Whole-program compilation enables aggressive cross-module optimization: erasure analysis can determine that a type index is unused across the entire program, monomorphization can specialize polymorphic functions for their actual call sites, and dead code elimination can remove unused predicates.

Separate compilation preserves module boundaries, enabling incremental rebuilds. The trade-off is that cross-module optimization is limited to what can be expressed in module interfaces.

For Πρόλογος, the recommended approach is separate compilation with ThinLTO. Each module is compiled independently, producing LLVM bitcode. At link time, ThinLTO performs targeted cross-module optimization (inlining hot functions, specializing cross-module calls) without requiring whole-program analysis during each rebuild.

---

## 11. Compiling Linear and Affine Types

### 11.1 Rust's MIR Borrow Checker as Case Study

Rust's compilation pipeline provides the most production-proven approach to compiling linear types:

**Source → HIR (High-level IR) → MIR (Mid-level IR) → LLVM IR → Native Code**

MIR is the critical stage. The borrow checker operates on MIR, performing flow-sensitive analysis that tracks the lifetime and mutability of all variables. Rust's ownership semantics are enforced at this level — by the time LLVM sees the code, all borrowing has been verified and represented as simple pointer operations.

For Πρόλογος, the lesson is that linearity checking should happen on an intermediate representation (after type checking, before LLVM emission) where flow-sensitive analysis is practical. The Πρόλογος equivalent of MIR would be an ANF representation with multiplicity annotations.

### 11.2 Perceus: Garbage-Free Reference Counting

Koka's Perceus algorithm (Reinking et al., 2021) achieves garbage-free reference counting through static analysis:

The compiler inserts `acquire` (increment) when a value is created and `release` (decrement) when a value goes out of scope. It then optimizes consecutive `release` → `acquire` pairs into `reuse` operations when object sizes match: the old object's memory is directly reused for the new object, eliminating both the deallocation and the allocation.

The key insight: when a value has a unique reference (ref count = 1) and the last use is immediately followed by a new allocation of the same size, the release and acquire cancel out, and the memory is reused in-place. This transforms functional list operations into in-place updates:

```
;; Functional: map f (cons x xs) = cons (f x) (map f xs)
;; With Perceus reuse: if (cons x xs) has refcount 1,
;; reuse the cons cell for (cons (f x) (map f xs))
;; Result: zero allocation in the mapped list
```

For Πρόλογος, Perceus is the recommended reference counting strategy for ω-multiplicity values. The compiler performs reuse analysis after ANF conversion, identifying opportunities for in-place updates.

### 11.3 FBIP: Functional But In-Place

FBIP (Functional But In-Place) is the generalization of Perceus to arbitrary data structures. Just as tail-call optimization turns recursion into iteration, FBIP turns functional composition into in-place mutation — when the values being composed are uniquely owned.

The transformation works as follows. A pure function `f(x)` that pattern-matches on `x`, creates a new value of the same type, and returns it, can be compiled to an in-place update if `x` has a unique reference. The pattern match destructures `x`, the function modifies the fields, and the return reconstructs `x` with modified fields — but since `x` is unique, this is just a mutation.

### 11.4 Lean 4's Reset/Reuse Optimization

Lean 4 implements a variant of FBIP called reset/reuse. The compiler detects when a constructor application immediately follows a case analysis that destructures an object of the same constructor. If the destructured object has a unique reference, the compiler generates code to reuse its memory:

```
;; Lean: map f (cons x xs) = cons (f x) (map f xs)
;; Compiled (pseudocode):
;;   if refcount(cell) == 1:
;;     cell.head = f(cell.head)    // in-place update
;;     cell.tail = map(f, cell.tail)
;;     return cell                 // reuse same memory
;;   else:
;;     return alloc(cons, f(x), map(f, xs))  // fresh allocation
```

The uniqueness check (`refcount == 1`) is a single comparison, adding minimal overhead. When the check succeeds (common in functional programs where most intermediate values are consumed immediately), the allocation is eliminated.

### 11.5 Deterministic Destruction Without GC

For 1-multiplicity values in Πρόλογος, destruction is fully deterministic: the value is deallocated at the point of its single use. The compiler inserts deallocation code at the use site, with no GC involvement:

```
;; Prologos: (def consume-file (-> (f : 1 FileHandle) Unit))
;; Compiled: deallocation inserted after the single use
;;   use(f);
;;   dealloc(f);   // deterministic, compiler-inserted
```

This is the Tier 1 strategy from RESEARCH_GC.md: linear values are managed entirely by the compiler, with zero runtime overhead for reference counting or tracing.

### 11.6 Compiling Posit Arithmetic and Quire Operations

Πρόλογος adopts posit numbers as its primary floating-point representation (see RESEARCH_UNUM_INNOVATIONS.md, Section 14.8 for the type-theoretic foundations). Compiling posit arithmetic to efficient LLVM IR requires bridging the gap between hardware IEEE 754 units and the software-emulated posit format.

**SoftPosit FFI Integration.** The SoftPosit library (Berkeley's reference implementation in C) provides Posit8, Posit16, and Posit32 arithmetic operations. The Πρόλογος runtime links against SoftPosit as a static library, exposing operations through `extern "C"` functions:

```
;; Runtime exports for posit arithmetic
(extern "C" fn prologos_posit32_add (a : u32 b : u32) u32)
(extern "C" fn prologos_posit32_mul (a : u32 b : u32) u32)
(extern "C" fn prologos_posit32_div (a : u32 b : u32) u32)
(extern "C" fn prologos_posit32_sqrt (a : u32) u32)
(extern "C" fn prologos_quire32_init () Quire32)
(extern "C" fn prologos_quire32_fma (q : (Ptr Quire32) a : u32 b : u32))
(extern "C" fn prologos_quire32_to_posit (q : (Ptr Quire32)) u32)
```

**LLVM IR Representation.** Posit values are represented as their bit-width integer type in LLVM IR — a Posit32 is an `i32`, a Posit16 is an `i16`. Arithmetic operations are compiled to calls to the SoftPosit FFI functions. The compiler attaches `!prologos.posit` metadata to these values so that custom optimization passes can identify posit operations and apply posit-specific optimizations (e.g., fusing a multiply followed by an add into a fused multiply-add via the quire).

**Quire Accumulator Compilation.** The quire — a large fixed-point accumulator that enables exact dot products — is the key posit innovation for numerical accuracy. The compiler detects accumulation patterns (fold over multiply-add sequences, dot products, sum-of-products) and automatically lowers them to quire operations:

```
;; Πρόλογος source: dot product
(def dot-product
  (-> (xs : (Vec n Posit32)) (ys : (Vec n Posit32)) Posit32)
  (fold-with-quire (* x y) (zip xs ys)))

;; Compiled: quire-based accumulation
;;   q = quire_init()
;;   for i in 0..n: quire_fma(&q, xs[i], ys[i])
;;   result = quire_to_posit(&q)
;; Zero intermediate rounding — exact until final conversion
```

**SIMD Vectorization for Posit Operations.** While no current hardware provides native posit SIMD, software-emulated posit SIMD is achievable by packing multiple posit operations into SIMD lanes and executing the decode → compute → encode pipeline in parallel. The compiler identifies vectorizable posit loops during the ANF optimization phase and emits LLVM vector intrinsics for the integer-arithmetic portions of posit decode/encode. For Posit16 operations, 16 values can be processed simultaneously in a 256-bit AVX2 register; for Posit32, 8 values per register.

**GPU Offload Strategy.** For large-scale posit computations (array operations exceeding a configurable threshold, defaulting to 4096 elements), the compiler can emit GPU kernels via LLVM's NVPTX or AMDGPU backends. On GPU, posit arithmetic is software-emulated using integer ALUs — each CUDA thread processes one posit operation. The threshold for CPU SIMD vs. multi-core vs. GPU offload is determined by a cost model: small arrays (< 256 elements) use scalar posit calls, medium arrays (256–4096) use SIMD-vectorized posit, and large arrays (> 4096) are candidates for GPU offload if a compatible device is available.

---

## 12. Compiling Session Types

### 12.1 Runtime Representation of Session Channels

At runtime, a session-typed channel is a pair of concurrent queues — one for each direction of communication. The sender enqueues values; the receiver dequeues them. The session type (which governed what types could be sent and in what order) has been erased — it existed only during type checking.

The channel structure in the runtime:

```
;; Runtime channel (Rust pseudocode in Prologos notation)
(struct Channel
  (tx : (Sender (Vec u8)))     ;; serialized message queue
  (rx : (Receiver (Vec u8)))   ;; receive end
  (protocol-id : u64))         ;; debug: which protocol
```

Messages are serialized to byte vectors before enqueueing. The serialization format can be optimized: for actor-local channels, zero-copy message passing (just moving a pointer) is used; for cross-actor channels, ORCA-compatible serialization with reference count metadata is used.

### 12.2 State Machine Encoding of Protocols

During compilation, the session type is a finite state machine. Each state corresponds to a point in the protocol; each transition corresponds to a send or receive operation. The compiler verifies that the program traverses a valid path through this state machine.

At runtime, no state tracking is needed for correctness (the type checker already verified the protocol). However, for debugging, the runtime can optionally maintain a protocol state that is checked against expectations — a lightweight dynamic assertion that catches compiler bugs.

### 12.3 Multiparty Session Type Projection

For protocols involving more than two participants, the compiler performs projection: converting the global protocol description into local types for each participant. The projection algorithm ensures that each local type is a valid restriction of the global type.

Projection can fail if the global type contains pathological patterns (e.g., a participant that must decide its action based on a message it hasn't received). When projection fails, the compiler reports an error with a clear explanation of why the protocol is unrealizable.

### 12.4 Channel Implementation Strategies

Three implementation strategies are available:

**Lock-free queues** (Michael-Scott queue) provide high throughput under contention. Each actor has a private queue; senders enqueue using CAS operations. This is the recommended default for Πρόλογος.

**Rendezvous channels** (zero-buffer) provide stronger synchronization: the sender blocks until the receiver is ready. This is useful for protocols that require tight coupling between participants.

**Batched channels** accumulate multiple messages before notifying the receiver. This reduces scheduling overhead for high-frequency message patterns but increases latency. Batched channels are appropriate for propagator networks where many fine-grained updates flow between cells.

---

## 13. Compiling Logic Programming Features

### 13.1 The Warren Abstract Machine (WAM)

The WAM (Warren, 1983) remains the standard architecture for compiling Prolog. Its key components are:

**Registers**: Argument registers (A1–An) pass predicate arguments. The continuation pointer (CP) stores the return address. The environment pointer (E) addresses the current stack frame. The backtrack pointer (B) addresses the most recent choice point.

**Memory Areas**: The **heap** stores compound terms, growing upward. The **stack** stores environments (local variables) and choice points. The **trail** records variable bindings made since the last choice point, enabling undo on backtracking.

**Instruction Set**: WAM instructions include `get_structure` (match a functor), `put_structure` (build a functor), `unify_variable`/`unify_value` (unify arguments), `call`/`execute` (procedure calls, where `execute` is a tail call), `try_me_else`/`retry_me_else`/`trust_me` (choice point management), and `allocate`/`deallocate` (environment management).

For Πρόλογος, the WAM provides the foundation for compiling logic programming features, but with significant modifications for dependent types (type-directed clause selection), multiplicities (linear clauses that don't create choice points), and propagators (constraints compiled to propagator networks rather than WAM instructions).

### 13.2 Mercury's Compilation Strategy

Mercury compiles logic programs to efficient native code through a series of analyses:

**Mode analysis** determines which predicate arguments are inputs (bound at call time) and which are outputs (bound by the predicate). This enables the compiler to select the optimal clause ordering and avoid unnecessary choice points.

**Determinism analysis** classifies predicates as `det` (exactly one solution), `semidet` (zero or one solutions), `multi` (one or more solutions), or `nondet` (zero or more solutions). Deterministic predicates need no choice points, eliminating backtracking overhead.

**Superhomogeneous form conversion** flattens complex unifications in clause heads into explicit unification goals in clause bodies. This simplifies analysis and code generation.

For Πρόλογος, Mercury's mode and determinism systems provide the template for compiling logic predicates. QTT multiplicities provide additional information: a 1-multiplicity predicate argument that is consumed linearly cannot be used in backtracking (it has been consumed), so the predicate is automatically deterministic for that argument.

### 13.3 Compiling Unification to Native Code

Unification compilation follows a standard pattern. Given a clause head `f(X, g(Y, a))`, the compiler generates code that: (1) dereferences the first argument to find the current binding of X, (2) if X is unbound, bind it to the first argument value, (3) dereferences the second argument, expecting a structure `g/2`, (4) if the second argument is unbound, build the structure and bind it, (5) recursively unify the subterms.

For LLVM compilation, unification becomes a sequence of load, compare, and branch instructions. The dereference operation follows chains of variable bindings (pointer chasing). The occur check (verifying that a variable is not bound to a term containing itself) is typically omitted for performance and checked only when explicitly requested.

### 13.4 Choice Points, Backtracking, and the Trail

A choice point is created when a predicate has multiple matching clauses. It saves the current state (register values, trail position, heap pointer) so that if the first clause fails, execution can backtrack to try the next clause.

The trail records all variable bindings made since the most recent choice point. On backtracking, the trail is unwound: each recorded binding is undone, restoring variables to their unbound state.

For LLVM compilation, choice points can be implemented using LLVM's exception handling mechanism: each clause is tried with `invoke`, and failure triggers unwinding to the next clause via the landing pad. Alternatively, choice points can use explicit `setjmp`/`longjmp`-style mechanisms with the trail providing the undo log.

### 13.5 Tabling and Memoization

Tabling (SLG resolution) avoids recomputation by memoizing predicate results. The first call to a tabled predicate computes normally and stores the result in a table. Subsequent calls with the same arguments return from the table directly.

Implementation requires: a hash table indexed by predicate arguments (the answer table), suspension of incomplete computations when a tabled predicate calls itself (to avoid infinite loops), and resumption of suspended computations when new answers are added to the table.

For Πρόλογος, tabling integrates naturally with the propagator model: a tabled predicate is a propagator whose output cell is the answer table. Recursive calls that find an incomplete table suspend (the propagator waits for the cell to be updated), and new answers trigger propagator activation.

### 13.6 Soufflé's Datalog Compilation via Futamura Projection

Soufflé compiles Datalog programs to parallel C++ through what is effectively the first Futamura projection: specializing an interpreter (the Datalog evaluation algorithm) with respect to a known program (the Datalog rules) to produce a compiled program (parallel C++ that evaluates those specific rules).

Soufflé's pipeline: Datalog → RAM (Relational Algebra Machine, an intermediate representation) → Parallel C++ with OpenMP → Native binary. Relations are compiled to concurrent hash-based indexes; joins are compiled to nested loop joins; and stratified negation is computed in layers, with each layer parallelized independently.

For Πρόλογος, Soufflé's approach demonstrates that bottom-up Datalog evaluation can be compiled to efficient parallel code. Πρόλογος's propagator-based Datalog engine (described in RESEARCH_PARALLEL.md) can use a similar compilation strategy.

---

## 14. Compiling Propagator Networks

### 14.1 Runtime Representation of Cells and Propagators

Cells are represented as mutable locations holding lattice values, with a list of registered propagators to notify on updates:

```
;; Runtime cell structure (Rust conceptual)
(struct Cell
  (value : (Mutex LatValue))       ;; current lattice value
  (propagators : (Vec PropRef))    ;; propagators to fire on update
  (lattice : LatticeOps))         ;; merge, bottom, top operations

;; Runtime propagator structure
(struct Propagator
  (inputs : (Vec CellRef))         ;; cells this propagator reads
  (outputs : (Vec CellRef))        ;; cells this propagator writes
  (fire-fn : (Fn (Vec LatValue) (Vec LatValue))))  ;; computation
```

### 14.2 Scheduler Implementation

The propagator scheduler maintains a queue of propagators ready to fire (because at least one input cell has been updated). The scheduler dequeues a propagator, calls its fire function, and merges the results into output cells. If any output cell's value changes, the cell's registered propagators are added to the ready queue.

For parallel execution, the scheduler uses work-stealing: each core has a local ready queue, and idle cores steal from busy cores. The CALM property ensures that concurrent propagator firings produce the same result regardless of execution order (for monotonic sub-networks).

### 14.3 Compilation Strategies for Constraint Networks

Three strategies, with increasing specialization:

**Interpreted**: Cells and propagators are runtime objects; the scheduler is a generic event loop. Simplest to implement, suitable for the prototype.

**Partially compiled**: The constraint network topology is known at compile time (from static analysis of `where` clauses). The compiler generates specialized code that directly calls propagator functions in a fixed order, eliminating scheduler overhead. Cell allocations for pure intermediate values are replaced with SSA variables.

**Fully compiled**: The entire constraint-solving process (including fixpoint iteration) is compiled to a loop nest. Propagator fusion combines chains of propagators into single functions. Stream fusion eliminates intermediate cell allocations. The result is a tight loop that solves the constraint without any runtime overhead from the propagator abstraction.

### 14.4 Connection to Incremental Computation

Propagator networks naturally support incremental computation via the Adapton model: when an input cell changes, only affected propagators re-fire. This enables efficient re-solving when constraints change incrementally (e.g., in an IDE when the user modifies one constraint in a large system).

For the Πρόλογος runtime, the scheduler tracks which cells have changed since the last fixpoint and only re-fires affected propagators. This is a form of incremental constraint solving that avoids re-evaluating the entire network.

---

## 15. Actor Runtime Implementation

### 15.1 Work-Stealing Scheduler in Rust

The Πρόλογος runtime uses a work-stealing scheduler based on Tokio's architecture, but customized for actor and propagator workloads:

Each OS thread (one per CPU core) has a local double-ended queue (deque) of runnable actors. When an actor receives a message, it is placed on the scheduler thread's local deque. When a thread finishes processing an actor's message batch, it dequeues the next actor from its local deque (LIFO, for cache locality). When a thread's local deque is empty, it steals from a random other thread's deque (FIFO, stealing the largest/oldest tasks).

The key difference from Tokio: the Πρόλογος scheduler also handles propagator firings, which are typically much finer-grained than actor message processing. The scheduler uses adaptive batching — multiple propagator firings for the same actor are batched into a single scheduling unit to amortize overhead.

### 15.2 Mailbox Strategies: Lock-Free and Segmented

Each actor has a mailbox for receiving messages. The recommended implementation uses a **segmented lock-free queue**: the mailbox is a linked list of fixed-size segments (e.g., 64 messages per segment). Within a segment, messages are written using atomic stores; segments are linked using CAS operations.

This design provides: O(1) amortized enqueue (fast path: atomic increment within segment; slow path: allocate new segment), O(1) dequeue (the actor is the sole consumer), and bounded memory overhead (empty segments are recycled).

### 15.3 FFI Between Rust Runtime and LLVM-Generated Code

The Πρόλογος runtime is implemented in Rust but must interact with LLVM-generated user code. The FFI boundary uses `extern "C"` functions:

```
;; Rust runtime exports (conceptual)
(extern "C" fn prologos_alloc (size : usize align : usize) (Ptr u8))
(extern "C" fn prologos_dealloc (ptr : (Ptr u8) size : usize))
(extern "C" fn prologos_actor_send (actor : ActorRef msg : (Ptr u8) size : usize))
(extern "C" fn prologos_actor_recv (actor : ActorRef buf : (Ptr u8)) usize)
(extern "C" fn prologos_cell_merge (cell : CellRef value : (Ptr u8) size : usize))
(extern "C" fn prologos_rc_inc (ptr : (Ptr u8)))
(extern "C" fn prologos_rc_dec (ptr : (Ptr u8)))
```

The Inkwell code generator emits calls to these extern functions. At link time, the Rust runtime (compiled to a static library) is linked with the LLVM-generated object files to produce the final executable.

### 15.4 Garbage Collector Integration

The GC (as described in RESEARCH_GC.md) integrates with the LLVM-generated code through statepoints. The Rust runtime provides the GC implementation; LLVM-generated code provides the stack maps (via statepoints) that tell the GC where to find heap pointers.

For the prototype, a simpler shadow stack approach is recommended: the runtime maintains a linked list of GC root sets, and each function prologue/epilogue registers/deregisters its local GC roots. This is less efficient than statepoints but dramatically simpler to implement.

### 15.5 WAM State Isolation in Actor-Based Execution

A critical architectural requirement: each actor maintains its own independent WAM state. This means every actor possesses a private heap, a private trail stack, a private stack of environments and choice points, and private argument registers. No WAM state is shared between actors.

**Per-Actor Heap.** Each actor's heap is a contiguous memory region allocated from the actor's arena (consistent with the per-actor GC from RESEARCH_GC.md). Compound terms created during unification are allocated on the actor's heap. When the actor processes a query, all intermediate terms live on its heap; backtracking frees heap allocations by resetting the heap pointer to the saved state (the mark stored in the choice point).

**Per-Actor Trail.** The trail records variable bindings made during unification so that they can be undone on backtracking. Each actor's trail is private — bindings made during one actor's query resolution do not affect any other actor's variable state. This eliminates the need for synchronization on trail operations, which are among the most frequent WAM operations.

**Backtracking Is Locally Contained.** When a clause fails within an actor's query resolution, the WAM's backtracking mechanism (restoring trail entries, resetting the heap pointer, transitioning to the next choice point) operates entirely within that actor's private state. Exception-based backtracking (using LLVM's `invoke`/`landingpad` as described in Section 3.3) unwinds only within the actor's call stack — it never crosses actor boundaries.

**Cross-Actor Query Delegation.** When an actor needs to delegate a sub-query to another actor, it sends a message containing the query term. The receiving actor creates a fresh WAM execution context for that query, resolves it using its own private state, and sends the results back as messages. This is a strict message-passing boundary — no shared WAM state, no shared choice points, no cross-actor trail restoration.

```
;; Actor A asks Actor B to solve a sub-query
;; A's WAM state is suspended (choice point preserved on A's stack)
;; B creates fresh WAM state for the delegated query
;; B sends results back; A's WAM resumes from its saved state
(actor query-delegator
  (receive (solve-sub goal)
    (let result (ask other-actor (query goal)))
    ;; A's trail and heap are untouched by B's resolution
    (unify result expected)))
```

This strict isolation ensures that Πρόλογος's actor model preserves the deterministic semantics of logic programming within each actor while enabling parallel execution across actors — combining the safety of Mercury's mode/determinism system with the concurrency of Erlang's process model.

---

## 16. Advanced Compilation Techniques

### 16.1 CPS vs. ANF vs. SSA: Choosing an IR

Three intermediate representations dominate functional compiler construction:

**CPS (Continuation-Passing Style)** makes control flow explicit: every function takes an extra argument — the continuation — representing "what to do next." CPS is elegant for theoretical analysis but doubles the number of function parameters.

**ANF (A-Normal Form)** flattens nested expressions into sequences of let-bindings, where each subexpression is trivial (a variable, literal, or single function call). ANF is simpler than CPS while providing the same analytical power.

**SSA (Static Single Assignment)** is the standard for imperative compilers (including LLVM): each variable is defined exactly once, and PHI nodes merge values at control flow join points. SSA is equivalent to CPS (a deep result by Kelsey, 1995).

For Πρόλογος, **ANF is the recommended intermediate representation**. It bridges the functional source language (dependent types, pattern matching) and the imperative target (LLVM IR, which is SSA). ANF is what Idris 2 uses in its compilation pipeline, and it naturally accommodates both functional and logic programming features.

### 16.2 Closure Conversion and Defunctionalization

**Closure conversion** transforms nested functions with free variables into closed functions that receive their captured environment explicitly. This is necessary because LLVM functions cannot capture free variables.

**Defunctionalization** eliminates higher-order functions entirely by replacing function values with tagged data constructors. Each function value becomes a tag (identifying which function) plus an environment (the captured values). Application becomes a case analysis on the tag.

For Πρόλογος, closure conversion is performed during the ANF lowering phase. Defunctionalization is optional — it enables more efficient code but eliminates the ability to apply unknown function values (needed for higher-order predicates). A hybrid approach is recommended: defunctionalize known call sites (where the function is statically known) and use closure conversion for unknown call sites.

### 16.3 Lambda Lifting

Lambda lifting transforms nested function definitions into top-level definitions by adding captured variables as extra parameters. Unlike closure conversion (which creates a closure data structure), lambda lifting avoids allocation by passing captured values directly.

Lambda lifting is the primary approach in Idris 2's compilation pipeline: after type checking, all nested functions are lifted to the top level. This simplifies subsequent compilation phases, as all functions are top-level with no free variables.

For Πρόλογος, lambda lifting should be performed after erasure analysis (so that erased captures are not lifted) and before ANF conversion.

### 16.4 Partial Evaluation and the Futamura Projections

Partial evaluation specializes a program with respect to known inputs, producing a residual program that handles only the unknown inputs. The three Futamura projections demonstrate the power of this technique:

**First projection**: Specialize an interpreter with a program → a compiled version of that program. **Second projection**: Specialize a partial evaluator with an interpreter → a compiler for that language. **Third projection**: Specialize a partial evaluator with itself → a compiler generator.

For Πρόλογος, partial evaluation applies to: specializing polymorphic functions for specific type arguments (monomorphization), specializing propagator networks for known constraint structures, and specializing unification routines for known term shapes (avoiding runtime type dispatch).

### 16.5 Stream Fusion and Deforestation

Stream fusion eliminates intermediate data structures in pipelines of higher-order functions. The key idea: convert each producer/consumer pair into a step function, then fuse adjacent step functions by inlining.

For Πρόλογος, stream fusion is critical for performance of collection operations:

```
;; Without fusion: three intermediate lists
(def result
  (sum (map square (filter positive? data))))

;; With fusion: single pass, no intermediate allocation
;; Compiled to: for each x in data, if x > 0, acc += x*x
```

The compiler performs fusion during the ANF optimization phase, identifying chains of map/filter/fold operations and combining them into single-pass loops.

---

## 17. Error Reporting and Developer Experience

### 17.1 Rust-Style Diagnostics: Miette and Ariadne

The NOTES.org desideratum is clear: *"Excellent, human-readable, compiler errors in the likes of Rust or Gleam — VERY IMPORTANT."*

**Miette** is a Rust crate for producing beautiful diagnostic output with source code snippets, colors, labels, and suggested fixes. It integrates with Rust's derive macro system for ergonomic error definition.

**Ariadne** provides similar functionality with a focus on Unicode rendering and configurable color schemes. Ariadne's API is lower-level than Miette's, offering more control over output formatting.

For Πρόλογος, Miette is recommended for its ergonomic derive-macro approach: each error type is a Rust struct with annotated fields for source spans, labels, and suggestions.

### 17.2 Span Tracking Through Compilation Stages

Source spans must be preserved through every compilation phase so that errors and warnings can point to the relevant source code. The strategy:

**Parser**: Each AST node carries a `Span` (byte offset range in the source file). **Type checker**: Spans are preserved on type-checked terms, with additional spans for inferred types and implicit arguments. **ANF conversion**: Each ANF binding carries the span of its source expression. **LLVM emission**: Spans are converted to DWARF debug locations (`DILocation`) attached to LLVM instructions.

When a compilation phase creates a new node from multiple source nodes (e.g., inlining merges two functions), the span of the original call site is preserved. This ensures that debugger stepping and error messages always refer to meaningful source locations.

### 17.3 Parser Error Recovery

Error recovery enables the parser to continue after encountering a syntax error, collecting multiple errors in a single compilation pass. Strategies include:

**Panic mode**: Skip tokens until a known synchronization point (e.g., a closing parenthesis, a newline at the same indentation level). **Placeholder insertion**: Insert an error node in the AST and continue parsing. **Chumsky's built-in recovery**: The Chumsky parser combinator library provides `recover_with()` combinators that specify recovery strategies per production.

For Πρόλογος, the parser should produce a complete AST even in the presence of errors, with error nodes marking the locations of syntax problems. The type checker can then skip error nodes and continue checking the rest of the program, collecting additional errors.

### 17.4 Language Server Protocol Integration

The Language Server Protocol (LSP) enables IDE features (autocomplete, go-to-definition, hover information, inline errors) through a standardized JSON-RPC interface between the editor and a language server.

For Πρόλογος, the language server uses Salsa for incremental computation: when the user types a character, Salsa determines which analyses are affected and recomputes only those, providing real-time feedback.

Key LSP capabilities for Πρόλογος: `textDocument/diagnostics` (display type errors inline), `textDocument/hover` (show the type of an expression, including dependent type indices and session type states), `textDocument/completion` (suggest predicates, variables, and type constructors), `textDocument/definition` (navigate to predicate definitions), and `textDocument/references` (find all uses of a predicate or variable).

---

## 18. Testing and Quality Infrastructure

### 18.1 Snapshot Testing with Insta

The **Insta** crate provides snapshot testing: capture the output of a test and compare it against a stored snapshot. When the output changes, `cargo insta review` shows the diff and allows the developer to accept or reject the change.

For Πρόλογος, snapshot testing applies to: parser output (snapshot the AST for each test program), elaboration output (snapshot the fully-annotated core term), type error messages (snapshot the formatted error output), LLVM IR output (snapshot the generated code for each compilation unit), and compiled binary output (snapshot execution results).

### 18.2 Property-Based Testing with Proptest

**Proptest** generates random test inputs and verifies properties. For Πρόλογος, key properties include: "elaboration is deterministic" (same input always produces same output), "erased terms evaluate to the same result as unerased terms" (erasure correctness), "NbE normalization is idempotent" (normalizing a normal form produces the same form), and "well-typed programs do not crash" (type soundness).

### 18.3 Fuzzing with cargo-fuzz

**cargo-fuzz** uses LLVM's libFuzzer to generate random byte sequences and feed them to a target function. For Πρόλογος, fuzzing targets include the parser (must not crash on any input), the type checker (must not crash on any well-formed AST), and the code generator (must not produce invalid LLVM IR for any well-typed program).

### 18.4 Benchmarking with Criterion

**Criterion** provides statistically rigorous benchmarking with confidence intervals and regression detection. For Πρόλογος, benchmarks should cover parsing throughput (lines/second), type checking time (for progressively larger programs), code generation time, and runtime performance of compiled programs (compared against equivalent programs in other languages).

---

## 19. Case Studies: Rust-Based Language Implementations

### 19.1 Roc: Functional Language with LLVM Backend

Roc is a functional programming language implemented in Rust that targets LLVM for optimized builds and a custom "dev backend" for fast development iteration. Roc uses the Morphic solver for type inference, Perceus-style reference counting for memory management, and aggressive monomorphization.

Key lessons for Πρόλογος: Roc's dual-backend architecture (LLVM for release, custom for debug) validates the approach of using Cranelift as a development backend alongside LLVM for production. Roc's experience with Perceus confirms that reference counting with reuse analysis achieves competitive performance for functional languages.

### 19.2 Gleam: Functional Language with Multiple Targets

Gleam is a typed functional language implemented in Rust that compiles to both Erlang (for BEAM VM execution) and JavaScript. Gleam's compiler was originally written in Erlang but was rewritten in Rust to eliminate classes of compiler bugs through Rust's type system.

Key lessons for Πρόλογος: Gleam's multi-target architecture (Erlang + JavaScript from the same source) demonstrates the value of a clean IR that can be lowered to different backends. Gleam's error messages are widely praised; the implementation uses similar techniques to what Miette provides.

### 19.3 Cairo/Sierra: Provable Computation via MLIR

Cairo (StarkNet's language) compiles through Sierra (Safe Intermediate Representation) to MLIR to LLVM IR to native code. The Cairo Native project uses Melior (Rust MLIR bindings) for the Sierra → MLIR → LLVM lowering.

Key lessons for Πρόλογος: Cairo demonstrates that the MLIR path from Rust is production-viable. The Sierra → MLIR → LLVM pipeline validates the progressive lowering approach recommended for Πρόλογος. Cairo's requirement for provable computation (proofs that programs executed correctly) parallels Πρόλογος's dependent types requirement for correctness guarantees.

### 19.4 Mun: Hot-Reloading with LLVM

Mun is a statically-typed language implemented in Rust that uses LLVM for code generation and supports hot reloading — recompiling and swapping functions while the program is running. Mun achieves this through a dispatch table: all function calls go through an indirection table that is updated when functions are recompiled.

Key lessons for Πρόλογος: Mun's hot-reloading capability is valuable for interactive Πρόλογος development — redefining predicates while a logic query is running. The dispatch table approach is compatible with the propagator model (propagators reference functions through the table).

### 19.5 Boa: JavaScript Engine Architecture

Boa is a JavaScript engine implemented in Rust, featuring a custom garbage collector (`boa_gc`), string interning (`boa_interner`), and a modular crate structure. Boa uses bytecode interpretation rather than compilation to native code.

Key lessons for Πρόλογος: Boa's modular crate structure (separate crates for AST, parser, engine, GC, and interning) provides a template for Πρόλογος's project organization. Boa's custom GC demonstrates that implementing a tracing GC in Rust is feasible.

---

## 20. Concrete Architecture for the Πρόλογος Compiler

### 20.1 Recommended Technology Stack

```
Frontend:
  • logos         — lexer (jump-table DFA, 1+ GB/s throughput)
  • chumsky       — parser combinator (error recovery, composable)
  • miette        — error reporting (Rust-style diagnostics)

Analysis and Type Checking:
  • salsa         — incremental computation (query-based architecture)
  • ena           — union-find for unification / type inference
  • bumpalo       — arena allocation for AST / IR nodes
  • lasso         — string interning for identifiers

Intermediate Representation:
  • petgraph      — control flow graphs, propagator network topology
  • custom ANF    — A-Normal Form with multiplicity annotations

Code Generation:
  • inkwell       — LLVM 18+ bindings (production backend)
  • cranelift     — alternative backend (fast debug builds)
  • melior        — MLIR bindings (future: progressive lowering)

Runtime:
  • tokio         — work-stealing scheduler foundation
  • crossbeam     — lock-free data structures (mailboxes, deques)
  • gc-arena      — safe tracing GC for actor heaps
  • custom FFI    — Rust runtime linked with LLVM-generated code

Testing:
  • insta         — snapshot testing
  • proptest      — property-based testing
  • cargo-fuzz    — fuzzing
  • criterion     — benchmarking
```

### 20.2 Compilation Pipeline Design

```
Πρόλογος Source (.prologos)
    ↓ [logos + chumsky]
Concrete Syntax Tree (with spans)
    ↓ [desugaring]
Abstract Syntax Tree
    ↓ [elaboration: bidirectional type checking + NbE + unification via ena]
Core TT (fully annotated, all types explicit, QTT multiplicities)
    ↓ [erasure analysis: remove 0-multiplicity bindings]
Erased Core (only runtime-relevant values survive)
    ↓ [lambda lifting: nested functions → top-level]
Lifted Core
    ↓ [closure conversion / defunctionalization]
Closed Core (no free variables)
    ↓ [ANF conversion: flatten to let-bindings]
ANF IR (with multiplicity annotations)
    ↓ [Perceus RC insertion for ω-multiplicity values]
    ↓ [reuse analysis for FBIP optimization]
    ↓ [stream fusion for collection pipelines]
Optimized ANF
    ↓ [LLVM code generation via Inkwell]
LLVM IR Module
    ↓ [custom LLVM passes: tail call, RC elision, propagator fusion]
    ↓ [LLVM optimizer: standard passes + ThinLTO]
Object File
    ↓ [link with Rust runtime library]
Executable
```

### 20.3 Project Structure and Crate Organization

```
prologos/
├── Cargo.toml                    (workspace root)
├── crates/
│   ├── prologos-syntax/          (AST definitions, spans, tokens)
│   ├── prologos-lexer/           (logos-based tokenizer)
│   ├── prologos-parser/          (chumsky parser + error recovery)
│   ├── prologos-elaborator/      (type checking, NbE, unification, QTT)
│   ├── prologos-core/            (core TT representation)
│   ├── prologos-erase/           (erasure analysis + lambda lifting)
│   ├── prologos-anf/             (ANF IR + Perceus RC insertion)
│   ├── prologos-codegen-llvm/    (Inkwell-based LLVM emission)
│   ├── prologos-codegen-crane/   (Cranelift backend, dev builds)
│   ├── prologos-runtime/         (actor scheduler, GC, propagator engine)
│   ├── prologos-lsp/             (Language Server Protocol)
│   ├── prologos-driver/          (orchestrates compilation pipeline)
│   └── prologos-cli/             (command-line interface)
├── runtime/                      (C FFI glue for runtime ↔ LLVM)
├── tests/
│   ├── snapshots/                (insta snapshot files)
│   ├── golden/                   (end-to-end test programs)
│   └── fuzz/                     (cargo-fuzz targets)
└── benches/                      (criterion benchmarks)
```

### 20.4 Runtime System Architecture

The runtime system is a Rust library compiled to a static library and linked with LLVM-generated code. It provides:

**Actor Scheduler**: A work-stealing scheduler with one OS thread per CPU core. Each thread owns a deque of runnable actors. Actors are lightweight coroutines (implemented using LLVM's `llvm.coro.*` intrinsics for user code, and Rust's async runtime for runtime-internal work).

**Propagator Engine**: Cells hold lattice values; propagators register interest in cells. When a cell is updated (via `prologos_cell_merge`), the engine enqueues affected propagators. The scheduler fires propagators as part of its normal work-stealing loop.

**Garbage Collector**: Three-tier architecture from RESEARCH_GC.md. Tier 0: erased (0-multiplicity, no allocation). Tier 1: deterministic (1-multiplicity, compiler-inserted deallocation). Tier 2: per-actor generational + Perceus RC (ω-multiplicity local values). Tier 3: ORCA protocol (cross-actor references).

**Unification Engine**: Implements first-order unification with trail-based backtracking. Exposed to LLVM-generated code through FFI functions (`prologos_unify`, `prologos_trail_mark`, `prologos_trail_restore`).

**Memory Allocator**: A pool allocator with size classes (inspired by Pony's allocator), providing fast allocation for common object sizes. Each actor has its own allocator pool, eliminating cross-actor synchronization for allocation.

### 20.5 Concrete Code Sketches

The following illustrates how Πρόλογος source compiles through the pipeline:

```
;; === Πρόλογος Source ===
(def map
  (forall (a : Type) (b : Type) (n : 0 Nat)
    (-> (-> a b) (Vec n a) (Vec n b)))
  (fn (f xs)
    (match xs
      ((vec/nil) (vec/nil))
      ((vec/cons x rest) (vec/cons (f x) (map f rest))))))

;; === After Elaboration (Core TT) ===
;; All implicit arguments filled, types fully annotated
;; a, b : Type (erased), n : 0 Nat (erased)
;; f : ω (-> a b), xs : ω (Vec n a)

;; === After Erasure ===
;; a, b, n removed (0-multiplicity)
;; Type indices on vec/nil, vec/cons removed
;; Becomes untyped map over a raw vector structure

;; === After ANF + Perceus RC ===
;; let tag = load xs.tag
;; if tag == NIL:
;;   rc_dec(xs)            ;; release input
;;   return alloc(NIL)     ;; (or: reuse xs if same size)
;; else:
;;   let x = load xs.head
;;   let rest = load xs.tail
;;   rc_inc(f)             ;; f used twice: once for call, once for recursive
;;   let fx = call f(x)
;;   let mapped_rest = call map(f, rest)
;;   rc_dec(xs)            ;; release input cons cell
;;   return alloc(CONS, fx, mapped_rest)  ;; (or: reuse xs)

;; === LLVM IR (via Inkwell) ===
;; Standard SSA form with calls to prologos_rc_inc, prologos_rc_dec,
;; prologos_alloc, and tail call for recursive map
```

### 20.6 Compiler Error Messages for Πρόλογος

Following the NOTES.org desideratum for excellent error messages:

```
error[E0401]: Type mismatch in function application
  ┌─ src/search.prologos:15:12
  │
13 │ (def find-user
14 │   (-> String (Maybe User))
15 │   (fn (name) (lookup users name 42)))
  │                                  ^^ expected String, found Int
  │
  = help: `lookup` expects its third argument to be a String (the default
          value), but you passed the integer 42
  = hint: did you mean to pass a default user name?
          (lookup users name "unknown")
```

```
error[E0402]: Linear value used after consumption
  ┌─ src/io.prologos:22:5
  │
19 │ (def process-file
20 │   (-> (handle : 1 FileHandle) String)
  │                  ^ linear binding (must be used exactly once)
21 │   (fn (handle)
22 │     (let (contents (file/read handle))
  │                                ^^^^^^ first use (consumed)
23 │       (file/close handle)
  │                   ^^^^^^ ERROR: second use of linear value
24 │       contents)))
  │
  = help: `handle` has multiplicity 1 and was already consumed by
          `file/read` on line 22
  = hint: `file/read` returns both the contents and the handle:
          (let ((contents handle2) (file/read handle))
            (file/close handle2)
            contents)
```

```
error[E0403]: Dependent type index mismatch
  ┌─ src/matrix.prologos:8:3
  │
 5 │ (def matrix-multiply
 6 │   (forall (m n p : Nat)
 7 │     (-> (Matrix m n Float) (Matrix n p Float) (Matrix m p Float)))
 8 │   (fn (a b) (mat/mul a (mat/transpose a))))
  │                                         ^ expected (Matrix n p Float)
  │                                           found (Matrix n m Float)
  │
  = help: `mat/transpose` of a (Matrix m n Float) produces a
          (Matrix n m Float), but matrix multiplication expects the
          second argument to have dimensions (n × p)
  = note: you passed `a` (dimensions m × n) instead of `b` (dimensions n × p)
          to transpose
```

### 20.7 Phased Implementation Plan

**Phase 1 (Months 1–4): Core Language**
- Lexer (Logos) and parser (Chumsky) for homoiconic prefix syntax
- Elaborator with bidirectional type checking and NbE
- QTT multiplicity checking
- Simple LLVM code generation via Inkwell (integers, functions, pattern matching)
- Basic error reporting with Miette
- Snapshot test suite with Insta

**Phase 2 (Months 5–8): Logic and Constraints**
- WAM-inspired unification engine with trail-based backtracking
- Choice points and clause selection
- Basic propagator network runtime (cells, propagators, single-threaded scheduler)
- Session type checking and channel compilation
- Perceus RC insertion for ω-multiplicity values
- Cranelift development backend

**Phase 3 (Months 9–14): Concurrency and Performance**
- Work-stealing actor scheduler (Tokio-based)
- Per-actor GC with ORCA protocol
- Parallel propagator scheduling
- LLVM coroutine-based actors
- ThinLTO for cross-module optimization
- ORC JIT for REPL
- Language Server Protocol implementation (Salsa-based)

**Phase 4 (Months 15–20): Optimization and Scale**
- FBIP / reset-reuse optimization
- Stream fusion for collection pipelines
- Custom LLVM passes (tail call, RC elision, propagator fusion)
- Polly integration for numerical kernels
- MLIR pathway via Melior (progressive lowering)
- PGO integration
- GPU backend for data-parallel posit arithmetic
- Comprehensive benchmarking and performance tuning

---

## 21. References and Further Reading

**LLVM Infrastructure:**
- Lattner, C. and Adve, V. (2004). "LLVM: A compilation framework for lifelong program analysis and transformation." *CGO*.
- LLVM Language Reference Manual. https://llvm.org/docs/LangRef.html
- LLVM New Pass Manager. https://llvm.org/docs/NewPassManager.html
- LLVM Statepoints for GC. https://llvm.org/docs/Statepoints.html
- LLVM Coroutines. https://llvm.org/docs/Coroutines.html
- LLVM Exception Handling. https://llvm.org/docs/ExceptionHandling.html
- LLVM Atomics Guide. https://llvm.org/docs/Atomics.html
- ORC JIT Design. https://llvm.org/docs/ORCv2.html

**MLIR:**
- Lattner, C. et al. (2021). "MLIR: Scaling compiler infrastructure for domain specific computation." *CGO*.
- MLIR Dialects. https://mlir.llvm.org/docs/Dialects/
- MLIR Dialect Conversion. https://mlir.llvm.org/docs/DialectConversion/

**Rust Ecosystem:**
- Inkwell LLVM Bindings. https://github.com/TheDan64/inkwell
- llvm-sys Raw Bindings. https://github.com/tari/llvm-sys.rs
- Cranelift Code Generator. https://cranelift.dev/
- Melior MLIR Bindings. https://github.com/raviqqe/melior
- Salsa Incremental Framework. https://salsa-rs.github.io/salsa/
- Logos Lexer Generator. https://github.com/maciejhirsz/logos
- Chumsky Parser Combinator. https://github.com/zesterer/chumsky
- Miette Diagnostics. https://github.com/zkat/miette
- Ena Union-Find. https://github.com/rust-lang/ena
- Bumpalo Arena Allocator. https://github.com/fitzgen/bumpalo
- Lasso String Interner. https://crates.io/crates/lasso
- Petgraph. https://github.com/petgraph/petgraph
- Insta Snapshot Testing. https://github.com/mitsuhiko/insta
- Proptest. https://crates.io/crates/proptest
- Criterion Benchmarking. https://github.com/bheisler/criterion.rs

**Dependent Type Compilation:**
- Brady, E. (2021). "Idris 2: Quantitative Type Theory in Practice." *ECOOP*.
- Idris 2 Implementation Overview. https://idris2.readthedocs.io/
- Lean 4 Compiler Architecture. https://lean-lang.org/
- Kovács, A. "Elaboration Zoo." https://github.com/AndrasKovacs/elaboration-zoo
- Abel, A. et al. (2017). "Decidability of conversion for type theory in type theory." *POPL*.

**Linear Type Compilation:**
- Reinking, A. et al. (2021). "Perceus: Garbage free reference counting with reuse." *PLDI*.
- Lorenzen, A. et al. (2023). "Reference counting with frame-limited reuse." *ICFP*.
- Ullrich, S. and de Moura, L. (2021). "Counting immutable beans: Reference counting optimized for purely functional programming." *IFL*.

**Session Types:**
- Honda, K., Vasconcelos, V. T., and Kubo, M. (1998). "Language primitives and type discipline for structured communication-based programming." *ESOP*.
- Scalas, A. and Yoshida, N. (2019). "Less is more: Multiparty session types revisited." *POPL*.

**Logic Programming Compilation:**
- Warren, D. H. D. (1983). "An abstract Prolog instruction set." *Technical Note 309, SRI International*.
- Aït-Kaci, H. (1991). *Warren's Abstract Machine: A Tutorial Reconstruction*. MIT Press.
- Somogyi, Z. et al. (1996). "The execution algorithm of Mercury, an efficient purely declarative logic programming language." *JLP*.
- Bone, P. et al. (2012). "Automatic parallelization of Mercury programs." *PPDP*.
- Jordan, H. et al. (2016). "Soufflé: On synthesis of program analyzers." *CAV*.

**Propagator Networks:**
- Radul, A. and Sussman, G. J. (2009). "The Art of the Propagator." *MIT CSAIL Technical Report*.
- Hammer, M. et al. (2014). "Adapton: Composable, demand-driven incremental computation." *PLDI*.

**Actor Systems:**
- Agha, G. (1986). *Actors: A Model of Concurrent Computation in Distributed Systems*. MIT Press.
- Clebsch, S. et al. (2015). "Deny capabilities for safe, fast actors." *AGERE!*.
- Armstrong, J. (2007). "A history of Erlang." *HOPL III*.

**Compilation Techniques:**
- Kelsey, R. (1995). "A correspondence between continuation-passing style and static single assignment form." *IR*.
- Appel, A. W. (1992). *Compiling with Continuations*. Cambridge University Press.
- Flanagan, C. et al. (1993). "The essence of compiling with continuations." *PLDI*.
- Wadler, P. (1988). "Deforestation: Transforming programs to eliminate trees." *ESOP*.
- Coutts, D. et al. (2007). "Stream fusion: From lists to streams to nothing at all." *ICFP*.
- Jones, N. D. et al. (1993). *Partial Evaluation and Automatic Program Generation*. Prentice Hall.

**Error Reporting:**
- Rust Compiler Diagnostics. https://rustc-dev-guide.rust-lang.org/diagnostics.html
- Elm Compiler Errors. https://elm-lang.org/news/compiler-errors-for-humans
- Language Server Protocol. https://microsoft.github.io/language-server-protocol/

**Case Studies:**
- Roc Language. https://www.roc-lang.org/
- Gleam Language. https://gleam.run/
- Cairo Native. https://github.com/lambdaclass/cairo_native
- Mun Language. https://mun-lang.org/
- Boa JavaScript Engine. https://github.com/boa-dev/boa

---

*This report was prepared as part of the Πρόλογος language design research series. It should be read alongside the companion reports on Dependent Type Theory, Propagator Networks, Garbage Collection Innovations, Unum Innovations, Parallel Computing, and the Implementation Guidance document.*
