# Research Report: Garbage Collection Innovations

## From Stop-the-World to Pauseless: Pony's ORCA Protocol, Type-Assisted Memory Management, and Concrete Guidance for Πρόλογος

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [GC Foundations and the Stop-the-World Problem](#2-gc-foundations-and-the-stop-the-world-problem)
   - 2.1 [Mark-and-Sweep: McCarthy's Original Algorithm](#21-mark-and-sweep-mccarthys-original-algorithm)
   - 2.2 [Copying Collectors and Generational GC](#22-copying-collectors-and-generational-gc)
   - 2.3 [Reference Counting and Cycle Detection](#23-reference-counting-and-cycle-detection)
   - 2.4 [The Tri-Color Abstraction and Write Barriers](#24-the-tri-color-abstraction-and-write-barriers)
   - 2.5 [Why Stop-the-World Is Unacceptable](#25-why-stop-the-world-is-unacceptable)
3. [Concurrent and Incremental Collectors](#3-concurrent-and-incremental-collectors)
   - 3.1 [Concurrent Mark-Sweep: Boehm and Printezis](#31-concurrent-mark-sweep-boehm-and-printezis)
   - 3.2 [Baker's Treadmill and Real-Time GC](#32-bakers-treadmill-and-real-time-gc)
   - 3.3 [Snapshot-at-the-Beginning vs. Incremental Update](#33-snapshot-at-the-beginning-vs-incremental-update)
   - 3.4 [The Sapphire Collector: Copying Without Stopping](#34-the-sapphire-collector-copying-without-stopping)
4. [Modern Pauseless Collectors](#4-modern-pauseless-collectors)
   - 4.1 [Azul C4: Continuously Concurrent Compacting Collector](#41-azul-c4-continuously-concurrent-compacting-collector)
   - 4.2 [ZGC: Colored Pointers and Sub-Millisecond Pauses](#42-zgc-colored-pointers-and-sub-millisecond-pauses)
   - 4.3 [Shenandoah: Brooks Forwarding Pointers](#43-shenandoah-brooks-forwarding-pointers)
   - 4.4 [Go's GC: From STW to Concurrent Tri-Color](#44-gos-gc-from-stw-to-concurrent-tri-color)
   - 4.5 [Erlang/BEAM: Per-Process Heaps](#45-erlangbeam-per-process-heaps)
5. [Pony's No-Stop-the-World Garbage Collector](#5-ponys-no-stop-the-world-garbage-collector)
   - 5.1 [Reference Capabilities: The Foundation](#51-reference-capabilities-the-foundation)
   - 5.2 [The Deny Capabilities Matrix](#52-the-deny-capabilities-matrix)
   - 5.3 [Per-Actor Heaps and Mark-and-Don't-Sweep](#53-per-actor-heaps-and-mark-and-dont-sweep)
   - 5.4 [No Safepoints, No Write Barriers](#54-no-safepoints-no-write-barriers)
   - 5.5 [GC Scheduling: Behavior Boundaries and Allocation Pressure](#55-gc-scheduling-behavior-boundaries-and-allocation-pressure)
6. [ORCA: Cross-Actor Reference Counting](#6-orca-cross-actor-reference-counting)
   - 6.1 [The Problem of Shared References Across Actors](#61-the-problem-of-shared-references-across-actors)
   - 6.2 [Weighted Deferred Distributed Reference Counting](#62-weighted-deferred-distributed-reference-counting)
   - 6.3 [INC and DEC Protocol Messages](#63-inc-and-dec-protocol-messages)
   - 6.4 [Causal Ordering Without Global Synchronization](#64-causal-ordering-without-global-synchronization)
   - 6.5 [Cycle Detection for Actor Cycles](#65-cycle-detection-for-actor-cycles)
   - 6.6 [Performance Characteristics of ORCA](#66-performance-characteristics-of-orca)
7. [Pony's LLVM Integration for GC](#7-ponys-llvm-integration-for-gc)
   - 7.1 [Compilation Pipeline: Pony Source to Native Code](#71-compilation-pipeline-pony-source-to-native-code)
   - 7.2 [Simplified Root Tracking via the Actor Model](#72-simplified-root-tracking-via-the-actor-model)
   - 7.3 [The Runtime: libponyrt](#73-the-runtime-libponyrt)
   - 7.4 [Work-Stealing Scheduler](#74-work-stealing-scheduler)
   - 7.5 [Pool Allocators and Size Classes](#75-pool-allocators-and-size-classes)
8. [Region-Based Memory Management](#8-region-based-memory-management)
   - 8.1 [Tofte-Talpin Region Inference](#81-tofte-talpin-region-inference)
   - 8.2 [Cyclone: Regions with Linear Types](#82-cyclone-regions-with-linear-types)
   - 8.3 [Project Verona: Regions and Concurrent Owners](#83-project-verona-regions-and-concurrent-owners)
9. [Ownership and Capability-Based Approaches](#9-ownership-and-capability-based-approaches)
   - 9.1 [Rust's Ownership Model](#91-rusts-ownership-model)
   - 9.2 [Vale's Generational References](#92-vales-generational-references)
   - 9.3 [Lobster's Compile-Time Reference Counting](#93-lobsters-compile-time-reference-counting)
10. [Type-System-Assisted GC: The Cutting Edge](#10-type-system-assisted-gc-the-cutting-edge)
    - 10.1 [Perceus: Garbage-Free Reference Counting](#101-perceus-garbage-free-reference-counting)
    - 10.2 [FBIP: Functional But In-Place](#102-fbip-functional-but-in-place)
    - 10.3 [Lean 4: RC with Destructive Updates](#103-lean-4-rc-with-destructive-updates)
    - 10.4 [LXR: Reference Counting Meets Mark-Region](#104-lxr-reference-counting-meets-mark-region)
    - 10.5 [QTT Multiplicities and GC Strategy](#105-qtt-multiplicities-and-gc-strategy)
11. [Hybrid GC Strategies](#11-hybrid-gc-strategies)
    - 11.1 [The Unified Theory: Tracing and RC as Duals](#111-the-unified-theory-tracing-and-rc-as-duals)
    - 11.2 [Ulterior Reference Counting](#112-ulterior-reference-counting)
    - 11.3 [Immix and RC-Immix: Mark-Region Collectors](#113-immix-and-rc-immix-mark-region-collectors)
12. [GC for Functional Languages](#12-gc-for-functional-languages)
    - 12.1 [OCaml 5.0: Multicore GC](#121-ocaml-50-multicore-gc)
    - 12.2 [GHC: Lazy Evaluation and Non-Moving Collection](#122-ghc-lazy-evaluation-and-non-moving-collection)
    - 12.3 [Clean's Uniqueness Types](#123-cleans-uniqueness-types)
13. [LLVM's GC Infrastructure](#13-llvms-gc-infrastructure)
    - 13.1 [Statepoints, Stack Maps, and Safepoints](#131-statepoints-stack-maps-and-safepoints)
    - 13.2 [Shadow Stacks vs. Precise Stack Scanning](#132-shadow-stacks-vs-precise-stack-scanning)
    - 13.3 [Current Limitations and Workarounds](#133-current-limitations-and-workarounds)
    - 13.4 [How Julia, Crystal, and Others Handle GC with LLVM](#134-how-julia-crystal-and-others-handle-gc-with-llvm)
14. [Formal Verification of Garbage Collectors](#14-formal-verification-of-garbage-collectors)
    - 14.1 [CakeML: Verified Generational GC](#141-cakeml-verified-generational-gc)
    - 14.2 [CertiCoq: Verified Coq Extraction](#142-certicoq-verified-coq-extraction)
    - 14.3 [Iris and Separation Logic for GC Correctness](#143-iris-and-separation-logic-for-gc-correctness)
15. [Emerging Techniques](#15-emerging-techniques)
    - 15.1 [Mesh: Compacting Without Relocating](#151-mesh-compacting-without-relocating)
    - 15.2 [NUMA-Aware Collection](#152-numa-aware-collection)
    - 15.3 [Stochastic Rounding and GC for Heterogeneous Memory](#153-stochastic-rounding-and-gc-for-heterogeneous-memory)
16. [Implementation Guidance for Πρόλογος](#16-implementation-guidance-for-πρόλογος)
    - 16.1 [Design Principles: What Prologos Needs from a GC](#161-design-principles-what-prologos-needs-from-a-gc)
    - 16.2 [The Three-Tier Architecture: QTT + Per-Actor + Hybrid RC](#162-the-three-tier-architecture-qtt--per-actor--hybrid-rc)
    - 16.3 [Tier 0: Compile-Time Erasure via QTT Multiplicities](#163-tier-0-compile-time-erasure-via-qtt-multiplicities)
    - 16.4 [Tier 1: Deterministic Deallocation for Linear Values](#164-tier-1-deterministic-deallocation-for-linear-values)
    - 16.5 [Tier 2: Per-Actor Generational Collection](#165-tier-2-per-actor-generational-collection)
    - 16.6 [Tier 3: ORCA-Style Cross-Actor Protocol](#166-tier-3-orca-style-cross-actor-protocol)
    - 16.7 [Perceus-Style RC for Unrestricted Values](#167-perceus-style-rc-for-unrestricted-values)
    - 16.8 [LLVM Backend: Concrete Integration Strategy](#168-llvm-backend-concrete-integration-strategy)
    - 16.9 [Prototype Strategy: Racket First, LLVM Second](#169-prototype-strategy-racket-first-llvm-second)
    - 16.10 [Session Types as GC Hints](#1610-session-types-as-gc-hints)
    - 16.11 [Compiler Error Messages for Memory Errors](#1611-compiler-error-messages-for-memory-errors)
    - 16.12 [A Concrete Design Sketch](#1612-a-concrete-design-sketch)
    - 16.13 [Phased Implementation Plan](#1613-phased-implementation-plan)
17. [References and Key Literature](#17-references-and-key-literature)

---

## 1. Introduction

Garbage collection—the automatic reclamation of memory that is no longer reachable by a program—is one of the most consequential runtime subsystems in any managed language. Since John McCarthy introduced the first garbage collector for Lisp in 1960, the field has evolved through decades of increasingly sophisticated algorithms, driven by the relentless tension between two competing demands: the throughput cost of collection work, and the latency cost of pausing application execution while that work is performed.

The "stop-the-world" pause—a period during which all application threads are halted to allow the garbage collector to safely traverse and modify the heap—has been the central challenge in GC design. For latency-sensitive applications (financial trading systems, real-time control, interactive services, streaming data pipelines), even brief pauses can violate service-level agreements, corrupt time-dependent computations, or cascade through distributed systems as health-check failures.

The most radical solution to this problem comes from the Pony programming language, which achieves truly zero global GC pauses through a co-design of its type system and runtime. Pony's **reference capabilities** (iso, val, ref, box, trn, tag) statically prevent data races, enabling each actor to collect its own heap independently without any coordination with other actors. For cross-actor references, Pony's **ORCA protocol** (Ownership and Reference Counting-based garbage collection in the Actor world) provides fully concurrent, lock-free reference tracking through message-based coordination—all without a single stop-the-world pause.

This report provides an exhaustive survey of garbage collection innovations, from the foundational algorithms through the current state of the art, with particular emphasis on Pony's approach and the broader landscape of pauseless and type-assisted memory management. We are concerned with extracting concrete, actionable guidance for incorporating a no-stop-the-world garbage collector into Πρόλογος—a functional-logic language with dependent types, quantitative type theory (QTT), session types, actor-based concurrency, homoiconic syntax, and an LLVM compilation target.

---

## 2. GC Foundations and the Stop-the-World Problem

### 2.1 Mark-and-Sweep: McCarthy's Original Algorithm

John McCarthy invented garbage collection circa 1959 for Lisp. The mark-and-sweep algorithm works in two phases: (1) starting from a set of root references (stack, global variables), traverse the object graph and mark every reachable object; (2) sweep through the entire heap, reclaiming every unmarked object. This is simple, correct, and general—but it requires halting all program execution during both phases, because the mutator (the running program) could otherwise invalidate the collector's view of the heap.

### 2.2 Copying Collectors and Generational GC

C. J. Cheney's 1970 non-recursive list-compacting algorithm divides the heap into two semi-spaces (FromSpace and ToSpace). Collection copies all live objects from FromSpace to ToSpace, compacting them and reclaiming the entirety of FromSpace in one operation. The elegance of Cheney's algorithm is that it uses the destination region itself as a breadth-first queue, requiring no auxiliary data structures.

David Ungar's 1984 generational scavenging exploits the **generational hypothesis**: most objects die young. By partitioning objects by age into a young generation (nursery) collected frequently and an old generation collected rarely, generational collectors dramatically reduce the cost of typical collections. Andrew Appel extended this in 1989, showing how Cheney's algorithm integrates naturally with generational collection.

### 2.3 Reference Counting and Cycle Detection

George Collins introduced reference counting in 1960: each object maintains a count of incoming references, and objects are freed when their count drops to zero. Reference counting provides immediate reclamation (no separate collection phase) and predictable latency, but cannot reclaim cyclic data structures.

David Bacon and V.T. Rajan solved the cycle problem in 2001 with concurrent cycle collection: objects whose counts are decremented (but not to zero) become candidate cycle roots, and a local traversal detects and collects cyclic garbage. Their concurrent variant handles race conditions from simultaneous mutation.

### 2.4 The Tri-Color Abstraction and Write Barriers

Dijkstra, Lamport, Martin, Scholten, and Steffens introduced the tri-color abstraction in 1978, providing the theoretical foundation for all concurrent garbage collectors. Objects are classified as white (not yet reached), gray (reached but not fully scanned), and black (reached and fully scanned). The **tri-color invariant** states that no black object may point directly to a white object.

**Write barriers** (instrumentation on pointer stores) preserve this invariant during concurrent collection. Dijkstra's insertion barrier marks a stored pointer's target gray if the container is black. Steele's deletion barrier marks the old target gray when a reference is overwritten. These barriers allow the mutator and collector to run concurrently without corrupting each other's view of the object graph.

### 2.5 Why Stop-the-World Is Unacceptable

Stop-the-world pauses create cascading failures in distributed systems: load balancers mark paused services as unhealthy, upstream services exhaust connection pools, downstream databases are overwhelmed by retry storms. For a language designed for actor-based concurrent programming—as Πρόλογος is—global GC pauses would undermine the fundamental promise of actor isolation: that one actor's memory behavior should not affect another actor's latency.

---

## 3. Concurrent and Incremental Collectors

### 3.1 Concurrent Mark-Sweep: Boehm and Printezis

Hans-J. Boehm, Alan J. Demers, and Scott Shenker published "Mostly Parallel Garbage Collection" at PLDI 1991, performing marking concurrently with mutators and using write barriers to track objects modified during concurrent marking. Tony Printezis and David Detlefs extended this to a generational form (ISMM 2000), where the young generation is collected with brief stop-the-world pauses while the old generation is collected mostly concurrently.

### 3.2 Baker's Treadmill and Real-Time GC

Henry Baker's 1992 Treadmill algorithm performs real-time garbage collection without object motion. Objects are organized in doubly-linked lists representing the tri-color sets; transitioning an object between colors is an O(1) unlink-and-relink operation. This provides bounded pause times at the cost of memory locality (no compaction) and per-object list overhead.

### 3.3 Snapshot-at-the-Beginning vs. Incremental Update

Two dominant write barrier strategies for concurrent collection:

**Snapshot-at-the-beginning (SATB):** Any object live at the start of concurrent marking is considered live for that collection cycle. When a pointer is overwritten, the old target is marked gray. This is conservative (retains some floating garbage) but simple and efficient.

**Incremental update:** When a pointer is stored into a black object, the container is re-grayed for rescanning. This is more precise but requires a remark phase to process re-grayed objects.

### 3.4 The Sapphire Collector: Copying Without Stopping

Richard Hudson and Eliot Moss's Sapphire collector (2001) achieved on-the-fly copying collection for the Jikes RVM without stopping the world. The key innovation was per-thread flipping: each thread transitions from old to new object copies individually, avoiding the need for a global synchronization point. Results showed median pauses reduced by 31% and maximum pauses by 71%.

---

## 4. Modern Pauseless Collectors

### 4.1 Azul C4: Continuously Concurrent Compacting Collector

The C4 collector (Click, Tene, Wolf) is a generational pauseless GC used in Azul's Platform Prime JVM. C4 uses read barriers for concurrent compaction and remapping, and performs young and full heap collections concurrently and simultaneously. It is the first production-ready generational pauseless collector for Java, sustaining high allocation rates with sub-millisecond pause times.

### 4.2 ZGC: Colored Pointers and Sub-Millisecond Pauses

Oracle's ZGC (Java 11+, generational from Java 21) achieves sub-millisecond pauses through colored pointers—64-bit object references carrying metadata bits encoding object state (mark, remap, metadata). Load barriers intercept all heap object accesses, checking and handling relocated objects transparently. ZGC's pause times are O(1) with respect to heap size, consistently in the microsecond range.

Generational ZGC (Java 21–25) eliminated the 3× virtual memory mapping overhead of non-generational ZGC, achieving 10% throughput improvement and 10–20% reduction in P99 pause times. Netflix's production deployment confirmed sub-millisecond pause time variance across diverse workloads.

### 4.3 Shenandoah: Brooks Forwarding Pointers

Red Hat's Shenandoah (JDK 12+) uses Brooks forwarding pointers for concurrent compaction: each object carries an extra word pointing to itself (or to its relocated copy). During concurrent relocation, the forwarding pointer is atomically updated, and read barriers transparently follow the indirection. Shenandoah targets sub-10ms pauses independent of heap size.

### 4.4 Go's GC: From STW to Concurrent Tri-Color

Go's garbage collector evolved from stop-the-world (pre-1.5) to concurrent tri-color marking with sub-millisecond pauses. The GC pacer uses a control-theoretic proportional controller to determine cycle start time based on heap size, allocation rate, and GOGC target. Application goroutines assist with marking when allocation outpaces GC workers, maintaining a 30% CPU budget (25% dedicated GC workers, 5% goroutine assists). Uber reported saving 70,000+ CPU cores across 30 services through GOGC tuning and memory ballast techniques.

### 4.5 Erlang/BEAM: Per-Process Heaps

Erlang achieves soft real-time guarantees through per-process memory isolation: each lightweight process (actor) has its own private heap with independent generational GC. Collection of one process does not pause any other process. Since Erlang/OTP R12B, per-process GC uses generational semi-space copying (Cheney algorithm). The exception is large binaries (>64 bytes), which are stored in a shared binary heap with reference counting—a pragmatic compromise that slightly weakens the isolation guarantee.

---

## 5. Pony's No-Stop-the-World Garbage Collector

### 5.1 Reference Capabilities: The Foundation

Pony's GC innovations are inseparable from its type system. The language defines six **reference capabilities** that control how objects may be accessed and shared:

**iso (Isolated):** The reference is the only variable anywhere in the program that can read from or write to the object. An iso reference can be safely transferred between actors because it guarantees exclusive access.

**val (Value):** The reference is to immutable data. No variable in any actor can modify the object, so val references can be freely shared across actors for concurrent reads.

**ref (Reference):** A standard mutable reference, usable only within the owning actor. Multiple ref aliases may exist within one actor, but ref references cannot cross actor boundaries.

**box (Box):** A read-only reference that guarantees no other actor has write access. Box is the "read-only view" capability, usable as a common supertype of both val and ref for polymorphic read-only code.

**trn (Transition):** A mutable reference that allows local read aliases. Designed for building up data structures that will eventually be frozen to val—the name "transition" reflects this lifecycle.

**tag (Tag):** An identity-only reference: it cannot read or write the object's data, but can be compared for identity and passed between actors. Used for actor references themselves.

Only **iso**, **val**, and **tag** are "sendable"—they can safely cross actor boundaries. The others provide local flexibility within a single actor.

### 5.2 The Deny Capabilities Matrix

Pony's capabilities are based on the insight of **deny capabilities** (Clebsch, Drossopoulou, Blessing, McNeil 2015): rather than expressing what a reference can do, each capability expresses what it denies other references from doing. This inversion enables the compiler to statically prove that no data races can occur:

- **iso** denies all local and global read and write aliases—absolute exclusivity
- **val** denies all write aliases (local and global)—safely shareable for reading
- **trn** denies global read and write aliases but permits local read aliases
- **ref** denies global write aliases
- **box** denies global write aliases
- **tag** denies all access except identity comparison

The compiler verifies at compile time that these deny constraints are satisfied at every point in the program. This means Pony programs are provably free of data races and deadlocks (Pony uses no locks). This static guarantee is the key to Pony's GC: because the type system prevents problematic sharing patterns, the garbage collector needs no read barriers, no write barriers, no card tables, and no global synchronization.

### 5.3 Per-Actor Heaps and Mark-and-Don't-Sweep

Each actor in a Pony program has its own private heap. Rather than pausing to garbage collect one large global heap, Pony constantly garbage collects individual actor heaps concurrently:

**Mark-and-don't-sweep.** Pony's local GC is a variant of mark-sweep in which unreachable objects are never explicitly freed. The collector traces from the actor's root references, marking all reachable objects. Unreachable objects are simply not visited—their memory has zero impact on GC time. This means GC is **O(n) on the reachable graph**, not on total heap size.

**Mark bits stored separately.** Pony stores mark bits in a separate bitmap data structure, not within the objects themselves. This means object contents are never written during GC, avoiding cache pollution and enabling simpler lock-free tracing.

### 5.4 No Safepoints, No Write Barriers

Traditional concurrent GCs require **safepoints** (locations where the runtime can safely interrupt execution to start collection) and **write barriers** (instrumentation on pointer stores to track inter-generational or cross-thread references). Pony eliminates both:

**No safepoints needed.** GC only runs when an actor is not executing a behavior (message handler). Between behaviors, the actor has no active stack frames—all root references are in the actor's persistent data structures. There is no stack to scan, no register state to capture, and no need for compiler-inserted safepoint polls.

**No write barriers needed.** The reference capability type system statically prevents the reference patterns that write barriers are designed to track. Mutable references (ref) cannot cross actor boundaries; only immutable (val), isolated (iso), and identity-only (tag) references can be shared. This means inter-actor mutations of the kind that write barriers catch simply cannot occur in well-typed Pony programs.

The elimination of both safepoints and write barriers is a major performance advantage, as these mechanisms impose overhead on every function call (safepoints) and every pointer store (write barriers) in other concurrent GCs.

### 5.5 GC Scheduling: Behavior Boundaries and Allocation Pressure

An actor's local GC is triggered based on allocation pressure: a collection cycle runs if the memory allocated by the actor exceeds a gradually increasing threshold. Collection is always scheduled between behavior invocations—never during behavior execution—so there is no need to interrupt running code.

---

## 6. ORCA: Cross-Actor Reference Counting

### 6.1 The Problem of Shared References Across Actors

While per-actor heaps handle objects local to a single actor, the challenging problem is cross-actor references. When Actor A allocates an object and sends an immutable (val) reference to Actor B, who forwards it to Actor C—who owns the object? When can it be collected? The allocating actor (A) cannot know how many other actors hold references without explicit coordination.

### 6.2 Weighted Deferred Distributed Reference Counting

ORCA solves this problem through **weighted, deferred, distributed reference counting**. The key principles:

**Ownership.** Every object is owned by the actor that allocated it. The owner maintains a **local reference count** representing the number of other actors that may hold references.

**Foreign counts.** Non-owning actors maintain **foreign reference counts** for objects they hold references to. These are local to each actor and do not require synchronization to update.

**Weighted counting.** When an actor sends a reference to a non-owned object, it does not always send a protocol message to the owner. Instead, it "splits" its own reference weight:

- If the actor's foreign count for the object is greater than 1, it can decrement its own count and let the receiving actor inherit part of the weight—no protocol message needed.
- If the foreign count is 1 or less, the actor sets its count to k+1 (a configurable batch size, typically 256), sends an INC(object, k) message to the owner, and then proceeds with the transfer.

This amortization means that one protocol message covers ~k reference transfers, dramatically reducing overhead.

### 6.3 INC and DEC Protocol Messages

The ORCA protocol uses two message types:

**INC(object_id, k):** Sent by a non-owning actor to the owning actor. The owner increments its local reference count by k. This message is sent when a non-owning actor needs to "top up" its foreign count to cover future reference transfers.

**DEC(object_id, k):** Sent when an actor drops all its references to a non-owned object. The owner decrements its local reference count by k. When the owner's local count reaches zero and the object is not reachable from the owner's own roots, the object can be collected.

Crucially, these protocol messages are **piggybacked on application messages**, not sent as separate communications. This reduces the overhead to essentially zero in the common case.

### 6.4 Causal Ordering Without Global Synchronization

ORCA maintains correctness through the causal ordering guarantee already provided by the actor model: messages sent by one actor to another arrive in order. This means:

- INC messages always arrive before the corresponding reference is used
- DEC messages always arrive after the reference is dropped
- No global synchronization barrier is needed—each actor makes GC decisions based solely on its own local state

The protocol is **fully concurrent**: multiple actors can send INC/DEC messages simultaneously, process application messages, and perform local GC—all without any coordination beyond normal message passing.

### 6.5 Cycle Detection for Actor Cycles

Reference counting cannot collect cyclic structures. In ORCA, the relevant cycles are **actor cycles**: Actor A holds a reference to Actor B, which holds a reference to Actor A, and both have nonzero reference counts despite being collectively unreachable.

Pony addresses this with a **cycle detector** that runs concurrently with normal execution:

1. **Detection.** Identify groups of blocked actors (idle with no pending messages) that form reference cycles.
2. **Confirmation.** Send confirmation messages to all cycle members. If all confirm they are still blocked, the cycle is stable.
3. **Collection.** If confirmation succeeds, collect the entire cycle.
4. **Abort.** If any member receives a message during confirmation (breaking the cycle), abort and retry later.

Recent work on Pony has moved toward **distributed cycle detection**, where actors participate directly in the protocol rather than relying on a centralized detector—improving scalability and reducing single-point-of-failure risk.

### 6.6 Performance Characteristics of ORCA

The message overhead of ORCA is low:

- No protocol messages are needed for heap mutations within an actor (only local operations)
- Reference transfers between actors piggyback on application messages
- INC messages are amortized: one message for ~k transfers (batch size configurable)
- DEC messages are deferred and batched when convenient

Production experience with Wallaroo (a streaming data platform built entirely in Pony) demonstrates millions of messages per second with microsecond latencies—validating ORCA's practical efficiency.

---

## 7. Pony's LLVM Integration for GC

### 7.1 Compilation Pipeline: Pony Source to Native Code

Pony uses ahead-of-time (AOT) compilation targeting LLVM:

1. Pony source is parsed into an AST
2. Type checking verifies all reference capability constraints
3. The AST is lowered to LLVM IR
4. LLVM optimization passes are applied
5. Native machine code is generated for the target platform

The Pony runtime (libponyrt) is compiled as LLVM bitcode and linked with the application, enabling interprocedural optimizations between user code and the runtime.

### 7.2 Simplified Root Tracking via the Actor Model

Traditional GC systems require complex stack maps and stack scanning to identify GC roots. Pony's approach is radically simpler:

- GC only runs between behavior invocations, when the actor has no active stack frames
- All root references are in the actor's persistent data (fields), not on the stack
- No stack crawling, register capture, or binary metadata generation needed
- The actor's object references serve directly as the GC root set

This simplification is a direct consequence of the actor model: because actors process messages sequentially and GC runs at message boundaries, there is never a need to scan mid-execution state.

### 7.3 The Runtime: libponyrt

The Pony runtime provides:

- **Actor management:** Creation, lifecycle, message queues
- **Garbage collection:** Per-actor heaps, mark-and-don't-sweep, ORCA protocol
- **Scheduling:** Work-stealing scheduler (one thread per CPU core)
- **Allocation:** Pool allocators with size classes

An empty actor requires approximately 240 bytes on 64-bit systems, making millions of concurrent actors practical.

### 7.4 Work-Stealing Scheduler

Pony's scheduler uses one thread per CPU core with work-stealing for load balancing. Each scheduler maintains a queue of actors with pending messages. When a scheduler's queue is empty, it steals work from other schedulers. New actors are initially scheduled on the creating actor's scheduler (preserving cache locality). This design scales linearly with core count on typical workloads.

### 7.5 Pool Allocators and Size Classes

Each actor's heap uses pool allocators organized by size classes (16B, 32B, 64B, 128B, etc.). Objects are allocated from the pool matching their required size, minimizing fragmentation and allocation overhead. This is significantly faster than general-purpose malloc for the small, frequent allocations typical of actor-based programs.

---

## 8. Region-Based Memory Management

### 8.1 Tofte-Talpin Region Inference

Mads Tofte and Jean-Pierre Talpin's 1997 work on region-based memory management automates memory management through compile-time region analysis. The heap is divided into regions that are allocated and deallocated with stack discipline. A type-and-effect-based static analysis infers where each object should be allocated and when its region can be freed. The ML Kit compiler demonstrated this approach for Standard ML, achieving memory management without garbage collection through compile-time analysis alone.

### 8.2 Cyclone: Regions with Linear Types

Cyclone (a safe dialect of C) integrated region-based memory with type safety, including linear types for region deallocation. Variables qualified as linear (L) are restricted in usage to enable safe region freeing. Practical experience showed that porting C to Cyclone required approximately 8% code changes, of which only 6% were region annotations—demonstrating the practicality of region-based approaches.

### 8.3 Project Verona: Regions and Concurrent Owners

Microsoft's Project Verona organizes objects into isolated regions with **concurrent owners (cowns)**—lightweight units encapsulating mutable data with single-thread-of-execution semantics. Regions provide natural lifetime boundaries, reference counting tracks inter-region references, and the type system prevents data races. Verona's 2023–2024 research on message-passing allocators optimizes allocation for high-throughput message systems with lock-free queue implementations.

---

## 9. Ownership and Capability-Based Approaches

### 9.1 Rust's Ownership Model

Rust replaces runtime GC with compile-time ownership checking via the borrow checker. Each heap-allocated value has a single owner; ownership transfers on assignment (move semantics). Borrowed references allow temporary access without ownership transfer. Lifetimes track reference validity. The borrow checker enforces: exactly one mutable borrow OR any number of immutable borrows at any point. This achieves GC-like convenience with manual-memory-management performance—zero runtime overhead, zero pauses, and cache-efficient allocation patterns.

### 9.2 Vale's Generational References

Vale introduces **generational references**: every object carries a "current generation" integer incremented on free, and every pointer stores a "remembered generation" from creation time. On dereference, the pointer's generation is compared to the object's current generation; a mismatch indicates use-after-free (caught at runtime). This achieves only 10.84% overhead—less than half of reference counting—with deterministic deallocation and no pause times.

### 9.3 Lobster's Compile-Time Reference Counting

Lobster combines automatic reference counting with ownership analysis to eliminate 95% of RC overhead at compile time. The algorithm identifies a single owner for each heap allocation; all other uses are treated as "borrows" requiring no RC operations. Flow-sensitive type specialization allows functions to be specialized for different ownership patterns. The result is near-zero RC overhead with fully automatic memory management.

---

## 10. Type-System-Assisted GC: The Cutting Edge

### 10.1 Perceus: Garbage-Free Reference Counting

Perceus (Alex Reinking, Ningning Xie, Microsoft Research, PLDI 2021) is a breakthrough algorithm that combines precise reference counting with reuse analysis to achieve garbage-free code generation. The compiler emits RC increment instructions at assignments and decrement instructions at scope exits, freeing objects immediately when their count reaches zero. Critically, reuse analysis detects when an object can be destructively updated in-place (when its RC is 1), transforming functional code into efficient imperative execution without programmer intervention.

Perceus is implemented in the Koka language (Microsoft Research), which compiles directly to C with no runtime system or garbage collector. Performance is competitive with OCaml's ocamlopt and GHC, and Koka code sometimes outperforms hand-optimized C for memory-intensive workloads.

### 10.2 FBIP: Functional But In-Place

Building on Perceus, FBIP (Functional But In-Place Programming) establishes a programming paradigm where pure functional code is physically executed as in-place mutations when the compiler can prove reuse safety. The analogy to tail-call optimization is apt: just as TCO allows writing loops with function calls, FBIP allows writing mutations with pure functional syntax. For a language with actors and session types like Πρόλογος, FBIP enables buffer updates in message handlers without explicit mutation, with the type system (via QTT) proving update safety.

### 10.3 Lean 4: RC with Destructive Updates

Lean 4 (Microsoft Research) uses reference counting as its primary GC, with a key insight: "many objects die just before creating an object of the same kind." When an object's refcount reaches 0, Lean immediately reuses the allocation. The compiler's `reset` and `reuse` instructions prove isolation (object not shared) and perform destructive updates. This means `List.map` reuses the original list structure when the input has refcount 1—functional code with imperative performance.

### 10.4 LXR: Reference Counting Meets Mark-Region

LXR (Zhao, Blackburn, McKinley, PLDI 2022) is a hybrid collector that uses reference counting with temporal coarsening on the fast path (amortizing RC tracking across multiple pointer modifications) and periodic SATB tracing on the slow path (handling cycles). LXR delivers better P99/P99.9 tail latencies than purely concurrent collectors like ZGC, while maintaining competitive throughput. This controlled approach achieves better worst-case latency than fully concurrent collectors.

### 10.5 QTT Multiplicities and GC Strategy

Quantitative Type Theory (Atkey, McBride; implemented in Idris 2) assigns a multiplicity to each variable binding: 0 (erased at runtime), 1 (used exactly once), or ω (unrestricted). This has direct implications for garbage collection:

**0-multiplicity values** are erased at compile time—they exist only in the type system and generate no runtime code whatsoever. No GC burden.

**1-multiplicity values** are used exactly once, meaning their ownership is statically tracked. They can be freed deterministically immediately after use—no GC needed. This corresponds to stack allocation or linear-region allocation.

**ω-multiplicity values** may be aliased, shared, and used multiple times. These are the only values that require traditional GC or reference counting.

For Πρόλογος, which uses QTT as its core type theory, this means the type system directly partitions values into three memory management strategies—a powerful advantage over languages where all values must be treated uniformly by the GC.

**QTT syntax in Πρόλογος and GC implications.** In Πρόλογος's syntax, multiplicities annotate bindings:

```
;; 0-multiplicity: type index, erased at runtime (no allocation)
(def vector-length
  (forall (a : Type) (n : 0 Nat)
    (-> (Vec n a) Nat)
    (fn (v) ...)))

;; 1-multiplicity: linear, deterministic deallocation
(def consume-channel
  (-> (ch : 1 (Session FileTransfer)) Unit)
  (fn (ch) (session/close ch)))   ;; ch freed here

;; ω-multiplicity (default): shared, GC-managed
(def process-data
  (-> (data : (List Int)) Int)
  (fn (data) (foldl + 0 data)))
```

The compiler's multiplicity checker determines the GC tier for each binding: 0 → erased (Tier 0), 1 → deterministic (Tier 1), ω → RC/GC (Tier 2). For dependent functions where a type index (0-multiplicity) is used to compute a value-level structure, the compiler verifies that the index is never used at runtime—only its *result* (the computed type) survives elaboration.

---

## 11. Hybrid GC Strategies

### 11.1 The Unified Theory: Tracing and RC as Duals

Bacon, Cheng, and Rajan's seminal 2004 paper "A Unified Theory of Garbage Collection" proved that tracing and reference counting are mathematical duals: tracing operates on "live objects" (matter), RC operates on "dead objects" (anti-matter), and all high-performance collectors are hybrids combining both techniques. This framework explains why pure RC (lacks cycle collection) and pure tracing (lacks immediate reclamation) are both suboptimal, and why the most effective collectors blend both approaches.

### 11.2 Ulterior Reference Counting

Blackburn and McKinley's Ulterior Reference Counting (OOPSLA 2003) provides a principled hybrid: a bump-pointer nursery (young generation) with copying collection handles the high mutation rate of young objects, while a reference-counted mature space handles the low-mortality, low-mutation old generation. This achieves the throughput of generational copying with the bounded pause times of RC.

### 11.3 Immix and RC-Immix: Mark-Region Collectors

Immix (Blackburn and McKinley, PLDI 2008) divides the heap into blocks (32KB) and lines (128B), performing mark-region collection with opportunistic copying when fragmentation is detected. Immix achieves 7–25% total application performance improvement over canonical algorithms. RC-Immix layers reference counting on top of Immix, combining immediate reclamation with tracing-based cycle collection.

---

## 12. GC for Functional Languages

### 12.1 OCaml 5.0: Multicore GC

OCaml 5.0 (2022) introduced multicore support with a two-tier GC: a stop-the-world parallel minor collector (all domains pause briefly for nursery collection) and a mostly concurrent major collector (concurrent mark-sweep for the old generation). Interestingly, a concurrent minor collector was experimentally implemented but rejected because the stop-the-world parallel approach showed better throughput and latency in benchmarks—a pragmatic trade-off.

### 12.2 GHC: Lazy Evaluation and Non-Moving Collection

GHC's garbage collector faces unique challenges from Haskell's lazy evaluation: thunks (suspended computations) can hold transitive closures of large data structures, making memory behavior difficult to predict. GHC 8.10+ introduced a non-moving old-generation collector with concurrent marking, exploiting the fact that lazy thunk evaluation entry points naturally implement read barriers. This achieves lower pause times at the cost of slightly larger working sets compared to a moving collector.

### 12.3 Clean's Uniqueness Types

Clean pioneered uniqueness types in the 1980s: the type system tracks whether values are unique (single reference, can be updated in-place) or shared (may be aliased). Unique values can be stack-allocated or reused; shared values require GC. Clean demonstrated that a significant portion of program values are unique, substantially reducing GC pressure. Clean's uniqueness types directly influenced Rust's ownership model and are subsumed by linearity (1-multiplicity in QTT).

---

## 13. LLVM's GC Infrastructure

### 13.1 Statepoints, Stack Maps, and Safepoints

LLVM provides GC infrastructure through three key intrinsics:

**gc.statepoint:** Models a call that may trigger GC. Encodes safepoint information and pointer relocation records. The `RewriteStatepointsForGC` pass transforms potential-GC calls into statepoint sequences.

**gc.relocate:** Extracts a relocated pointer after a statepoint. Each relocatable pointer gets its own gc.relocate intrinsic, tied to the statepoint by index.

**gc.result:** Extracts the actual return value of the call wrapped by the statepoint.

These three intrinsics form a "statepoint relocation sequence" that enables precise, relocating garbage collection in LLVM-compiled code.

**Stack maps** describe the locations of GC-managed pointers (in registers and on the stack) at each safepoint. The runtime's GC can use these maps to precisely identify and update all live references during collection.

### 13.2 Shadow Stacks vs. Precise Stack Scanning

**Shadow stacks** maintain a parallel stack tracking all live GC references at runtime. The older `@llvm.gcroot` mechanism supports shadow stacks. This approach is simple but adds overhead to every function entry and exit.

**Precise stack scanning** (via statepoints and stack maps) uses compiler-generated metadata to reconstruct exact pointer locations at each safepoint. This is more efficient (no runtime overhead outside safepoints) but requires more complex compiler support. Full support exists for x86-64 and AArch64.

### 13.3 Current Limitations and Workarounds

LLVM's GC infrastructure has known limitations:

- Relatively static since initial design, with limited evolution
- Few language frontends use it extensively (Julia partially, some research languages)
- Interaction with LLVM optimization passes is sometimes unclear (optimizations may move or eliminate statepoints)
- Thread-safety and concurrency considerations are incomplete
- GC strategy plugin design requires early architectural decisions

Many languages targeting LLVM work around these limitations by implementing their own GC infrastructure outside LLVM's built-in support, using LLVM only for code generation and optimization.

### 13.4 How Julia, Crystal, and Others Handle GC with LLVM

**Julia** uses a non-moving, partially concurrent, generational mark-sweep collector. Objects smaller than 2KB use per-thread pool allocators; larger objects use libc malloc. Mark bits are stored in object headers (2 lowest bits). Julia uses LLVM for code generation but implements its own GC infrastructure.

**Crystal** uses the Boehm-Demers-Weiser conservative GC (bdw-gc). This is a practical choice that avoids LLVM GC complexity entirely: Boehm GC scans the stack conservatively without compiler cooperation.

**Zig** explicitly avoids garbage collection, using explicit allocator parameters for all heap allocation. LLVM is used purely for optimization and code generation.

---

## 14. Formal Verification of Garbage Collectors

### 14.1 CakeML: Verified Generational GC

The CakeML project includes the first formally verified generational garbage collector, proved correct in HOL4 with approximately 10,000 lines of theorem prover code. Key verified invariants include correct reachability (no live objects collected), safe relocation (pointer updates preserve semantics), generational invariant preservation, and completeness (all unreachable objects eventually collected).

### 14.2 CertiCoq: Verified Coq Extraction

CertiCoq provides verified extraction from the Coq proof assistant to C, including a high-performance generational GC with initial correctness proofs. Because CertiCoq handles immutable data (no destructive updates), the GC verification task is simpler than for mutable languages.

### 14.3 Iris and Separation Logic for GC Correctness

The Iris framework (Jung et al., ICFP 2015+) provides higher-order separation logic for reasoning about concurrent systems, including GC correctness. Recent work includes "Modular Verification of Safe Memory Reclamation" (OOPSLA 2023) and "Verified Message-Passing Concurrency with Session Types" (POPL 2024)—the latter directly applicable to a language like Πρόλογος that combines actors and session types. The Iris framework enables compositional proofs of GC safety: prove each module's memory behavior independently, then compose the proofs.

---

## 15. Emerging Techniques

### 15.1 Mesh: Compacting Without Relocating

Mesh (Berger, Powers, Tench, McGregor, PLDI 2019) achieves heap compaction for C/C++ programs—which store raw pointers, making object relocation impossible—by remapping virtual memory pages. Two fragmented pages whose live objects don't overlap are "meshed" by mapping both to the same physical page, reclaiming the other. Production deployments showed 16–39% memory reduction for Firefox and Redis.

### 15.2 NUMA-Aware Collection

Modern multi-socket systems have non-uniform memory access (50–100ns local vs. 200–300ns remote). NUMA-aware collectors minimize cross-socket traffic by allocating and collecting objects near the requesting thread. G1GC (JEP 157) and ZGC both support NUMA-aware allocation. For actor-based systems like Πρόλογος, per-actor heaps provide natural NUMA isolation—actors can be pinned to sockets, keeping their heaps in local memory.

### 15.3 Stochastic Rounding and GC for Heterogeneous Memory

The emergence of heterogeneous memory systems (HBM at 10–20ns, DRAM at 50–100ns, CXL at 300–500ns) creates opportunities for tiered GC: frequently accessed objects in fast memory, cold objects in slow memory. Session types and QTT multiplicities can provide hints about access patterns, enabling the GC to make informed placement decisions without runtime profiling.

---

## 16. Implementation Guidance for Πρόλογος

This section provides concrete, actionable guidance for incorporating a no-stop-the-world garbage collector into Πρόλογος. The recommendations are informed by the extensive research surveyed above and tailored to Πρόλογος's specific combination of features: dependent types, QTT, session types, actor-based concurrency, homoiconic syntax with `()` groupings, and LLVM compilation.

### 16.1 Design Principles: What Prologos Needs from a GC

Given Πρόλογος's design goals, the GC must satisfy:

**No global stop-the-world pauses.** Actors must be independently collectible. One actor's memory behavior must never pause another actor.

**Type-system integration.** QTT multiplicities (0, 1, ω) should directly inform memory management strategy. The GC should not treat all values uniformly when the type system provides richer information.

**Deterministic behavior for linear resources.** Values with multiplicity 1 (linear types) and session-typed channels must be freed deterministically, not at the whim of a tracing collector.

**Excellent, human-readable error messages.** (From NOTES.org, marked VERY IMPORTANT.) Memory-related errors—whether detected at compile time (linearity violations, use-after-free through QTT) or runtime (reference count anomalies)—must produce clear, Rust-like or Gleam-like diagnostic messages.

**LLVM compatibility.** The GC must work with LLVM's code generation pipeline, either using LLVM's built-in GC infrastructure or implementing custom support.

**No silent wrapping.** Consistent with the numeric design philosophy: overflow of reference counts, heap exhaustion, and other memory failures must be detected and reported, never silently ignored.

### 16.2 The Three-Tier Architecture: QTT + Per-Actor + Hybrid RC

We recommend a three-tier memory management architecture that exploits Πρόλογος's type system to minimize GC pressure:

```
┌─────────────────────────────────────────────────────┐
│           Πρόλογος Memory Management                │
├─────────────────────────────────────────────────────┤
│ Tier 0: Compile-time erasure (0-multiplicity)       │
│         No runtime cost whatsoever                  │
├─────────────────────────────────────────────────────┤
│ Tier 1: Deterministic deallocation (1-multiplicity) │
│         Stack alloc / linear regions / Perceus RC   │
├─────────────────────────────────────────────────────┤
│ Tier 2: Per-actor generational collection           │
│         Nursery (bump-pointer) + tenured (RC)       │
│         Pony-style: GC at behavior boundaries       │
├─────────────────────────────────────────────────────┤
│ Tier 3: Cross-actor ORCA-style protocol             │
│         Weighted deferred reference counting        │
│         Distributed cycle detection                 │
└─────────────────────────────────────────────────────┘
```

### 16.3 Tier 0: Compile-Time Erasure via QTT Multiplicities

Values with 0-multiplicity in QTT exist only at compile time—they are type indices, proofs, and compile-time computations that are completely erased before code generation. The compiler must:

1. Track multiplicities through the elaboration pipeline
2. Verify that 0-multiplicity values are never used at runtime
3. Erase all 0-multiplicity bindings during code generation (no allocation, no GC)

This is significant because Πρόλογος's dependent type system will have many type-level computations (e.g., the `n` in `Vec n a`, proof terms for refinement types). All of these are 0-multiplicity and generate zero runtime overhead.

### 16.4 Tier 1: Deterministic Deallocation for Linear Values

Values with 1-multiplicity (used exactly once) have statically known lifetimes. The compiler should:

**Stack-allocate where possible.** If a 1-multiplicity value's lifetime is bounded by the current function scope, allocate it on the stack. No GC involvement.

**Linear region allocation.** For 1-multiplicity values that cross function boundaries (e.g., passed linearly to a called function), use a linear region allocator. The region is freed when the linear binding is consumed.

**Perceus-style reuse.** When a 1-multiplicity value is consumed and a new value of the same type is immediately created, the compiler should emit reuse instructions (as in Perceus/Koka). This transforms functional code into in-place updates with zero allocation.

**Session-typed channels.** Channels with linear session types are 1-multiplicity resources. When a session protocol reaches its `close` state, the channel is deterministically freed. The compiler should verify (via the session type) that channels are always properly closed.

### 16.5 Tier 2: Per-Actor Generational Collection

For ω-multiplicity values within a single actor, use per-actor generational collection modeled on Pony's approach:

**Per-actor nursery.** Each actor has a bump-pointer nursery for young ω-multiplicity allocations. Nursery collection uses Cheney-style copying, moving surviving objects to a tenured space.

**Tenured space with RC.** The tenured space uses Perceus-style reference counting with a backup tracing pass for cycle collection. Immediate reclamation (RC reaches 0) handles the common case; periodic tracing handles cycles.

**Collection at behavior boundaries.** Like Pony, collection runs between message processing (behavior invocations), never during execution. This means:
- No safepoints are needed within behavior execution
- No stack scanning required (no active frames during GC)
- Collection time is bounded by the actor's live object count

**Allocation pressure trigger.** GC is triggered when the actor's allocation since last collection exceeds a dynamically adjusted threshold. The threshold adapts based on the actor's allocation patterns.

### 16.6 Tier 3: ORCA-Style Cross-Actor Protocol

For objects shared across actors (via `val` or `tag` capabilities in Pony's terminology; via immutable shared types in Πρόλογος), use an ORCA-style protocol:

**Ownership.** The allocating actor owns each shared object and maintains a local reference count.

**Weighted counting.** Non-owning actors maintain foreign counts. INC/DEC messages are amortized over batch sizes (~256 transfers per protocol message).

**Message piggybacking.** GC protocol messages are piggybacked on application messages, adding negligible overhead.

**Distributed cycle detection.** Actor cycles are detected through a distributed confirmation protocol. Blocked actors that form reference cycles are identified, confirmed, and collected without global coordination.

The key adaptation for Πρόλογος is that the type system provides more information than Pony's capabilities:

- **0-multiplicity references** never cross actor boundaries (erased)
- **1-multiplicity references** are transferred exclusively (like Pony's iso), requiring no reference counting
- **ω-multiplicity immutable references** can be shared freely (like Pony's val), requiring ORCA-style counting
- **Session-typed channels** follow a protocol that determines their lifetime statically

This means the ORCA protocol is only needed for ω-multiplicity immutable values shared across actors—a smaller set than in Pony, where all sendable references require ORCA tracking.

**ORCA message encoding.** Protocol messages are piggybacked on application messages transparently by the compiler and runtime. The programmer never sees GC metadata; the runtime wraps each message in an envelope:

```
;; Internal message envelope (not visible to programmer)
;; Compiler-generated:
(message-envelope
  (target actor-b)
  (payload (process-chunk data))
  (gc-metadata
    (inc (object-ref data) 256)   ;; INC: bump owner's count by 256
    (dec (object-ref old-ref) 1))) ;; DEC: drop reference to old-ref
```

The compiler emits INC/DEC metadata by analyzing which ω-multiplicity references are transferred in each `send` operation. The runtime extracts and applies GC metadata before dispatching the application payload to the actor's behavior handler. This is entirely automatic—the programmer works only with application-level messages.

### 16.7 Perceus-Style RC for Unrestricted Values

For ω-multiplicity values within a single actor, Perceus-style precise reference counting provides the best combination of determinism and performance:

1. **Emit RC increment at assignment** and **RC decrement at scope exit**
2. **Free immediately** when count reaches 0
3. **Reuse analysis:** Detect objects with RC=1 that can be destructively updated
4. **Frame-limited reuse (FLR):** Robust reuse analysis that is stable across minor code changes

The compiler generates C-style RC operations:

```c
// Generated by Πρόλογος compiler (conceptual)
struct List *xs = alloc_list(...);
list_incref(xs);
struct List *ys = process(xs);
list_decref(xs);  // may free if RC=0
```

**Backup cycle collection.** Periodically (e.g., every N behaviors), perform a local SATB (snapshot-at-the-beginning) trace within the actor's tenured space to detect and collect cyclic garbage. This runs concurrently with other actors.

### 16.8 LLVM Backend: Concrete Integration Strategy

Two viable strategies for LLVM integration:

**Strategy A: LLVM Statepoints (for future precision)**

Use LLVM's gc.statepoint, gc.relocate, and gc.result intrinsics:

```llvm
; At a potential GC point (e.g., function call, allocation)
%token = call token (...) @llvm.experimental.gc.statepoint(
  i64 0, i32 0, void ()* @function,
  i32 0, i32 0,
  i64 %live_ref_1, i64 %live_ref_2)

; After GC, references may have been relocated
%relocated_1 = call i64 @llvm.experimental.gc.relocate(
  token %token, i32 0, i32 0)
```

Define a Πρόλογος-specific GC strategy plugin that:
- Tracks actor heap pointers as GC roots
- Emits statepoints at message send/receive and allocation points
- Generates stack maps for precise stack scanning
- Supports the per-actor collection model

**Strategy B: C Backend via Perceus Emission (recommended for prototyping)**

Generate C code with explicit RC operations, as Koka does:

```c
// Πρόλογος-generated C code
prologos_object_t *obj = prologos_alloc(sizeof(MyType));
prologos_incref(obj);
// ... use obj ...
prologos_decref(obj);  // frees if RC=0, triggers reuse analysis
```

This avoids LLVM's GC complexity entirely. The Pony runtime itself uses this approach: libponyrt is a C runtime that manages heaps and scheduling, with Pony code compiled to LLVM IR that calls into the runtime for allocation and GC.

**Recommendation:** Start with Strategy B for the prototype (simpler, proven by Koka and Pony), then migrate to Strategy A for the production compiler when LLVM statepoint support matures.

### 16.9 Prototype Strategy: Racket First, LLVM Second

Consistent with the phased implementation plan from the IMPLEMENTATION_GUIDANCE.md, the GC should be prototyped in two phases:

**Phase 1 (Racket prototype):** Implement the type-directed memory management (Tiers 0–1) in Racket. Use Racket's built-in GC for ω-multiplicity values. Focus on verifying that QTT multiplicity tracking correctly classifies values into the three tiers. Implement a simplified ORCA protocol using Racket's channels/actors.

**Phase 2 (LLVM production):** Implement the full three-tier architecture targeting LLVM. Build libprologosrt (the runtime library) in C, modeled on libponyrt. Implement per-actor heaps, pool allocators, ORCA protocol, and cycle detection. Use LLVM for code generation with C-backend RC emission (Strategy B above).

### 16.10 Session Types as GC Hints

Πρόλογος's session types provide information that no existing GC exploits: the communication protocol of a channel determines the lifetime pattern of messages flowing through it.

**Protocol-driven allocation.** A session type like:

```
(session-type FileTransfer
  (send Filename)
  (recv FileHandle)
  (rec loop
    (choose
      (read  (recv Chunk) loop)
      (close (end)))))
```

tells the compiler that Chunk values are created in the `read` branch and consumed before the next iteration. This is a strong hint for nursery allocation: chunks have short, predictable lifetimes and can be collected aggressively.

**Session completion as deallocation.** When a session reaches its `end` state, all resources associated with the session can be freed. The type system guarantees this state is reached (via linearity of the channel), so no GC is needed for session-scoped resources.

**Formal integration with the three-tier architecture.** A session-typed channel is itself a 1-multiplicity (linear) value, placing it in Tier 1 (deterministic deallocation). But the values flowing *through* the channel may be ω-multiplicity. The compiler can exploit the session structure to optimize these ω-multiplicity allocations:

1. **Session-scoped regions.** Allocations that the type system can prove are consumed within one iteration of a `rec` loop (like `Chunk` above) can be allocated in a session-scoped region—a lightweight arena that is bulk-freed at the loop boundary, bypassing per-object GC entirely.

2. **Resource tracking via session state.** The compiler maintains a "session resource set" for each active session. When the session enters its `end` state, the runtime frees all resources in the set. Because the session type guarantees that `end` is reached (linearity of the channel), this deallocation is provably safe.

3. **GC scheduler integration.** The GC scheduler can use session type information to prioritize collection: actors currently blocked on a session receive (waiting for a message) are good candidates for collection, because their working set is stable.

4. **Dependent session types for precision.** When session types are indexed by dependent types (e.g., `(session-type (Transfer n) (rec loop (if (> n 0) (send Chunk (Transfer (- n 1))) (end))))`), the compiler can statically determine the number of loop iterations and pre-allocate the session region to the exact required size.

### 16.11 Compiler Error Messages for Memory Errors

The NOTES.org desideratum for "Excellent, human-readable, compiler errors in the likes of Rust or Gleam" applies directly to memory-related errors:

**Linearity violation:**
```
error[E0301]: linear value used more than once
  ┌─ src/main.prologos:15:5
  │
12 │   (let channel (open-session server))
  │        ─────── linear value created here
  │
15 │   (send channel "hello")
  │         ─────── first use here (consumed)
  │
17 │   (send channel "world")
  │         ─────── ERROR: second use of consumed linear value
  │
  = help: `channel` has multiplicity 1 and was consumed at line 15
  = help: to send multiple messages, use the session type's
          recursive structure
```

**Unused linear resource:**
```
error[E0302]: linear value not consumed
  ┌─ src/main.prologos:10:7
  │
10 │   (let file (open-file "data.txt"))
  │        ──── linear value created here, never consumed
  │
  = help: values with multiplicity 1 must be consumed exactly once
  = help: did you forget to call (close file)?
```

### 16.12 A Concrete Design Sketch

Here is how the three-tier GC integrates with Πρόλογος syntax:

```
;; === Actor with GC-informed types ===

(actor FileProcessor

  ;; State: ω-multiplicity (may be aliased, needs GC)
  (state
    (processed-count : Int)           ;; ω: arbitrary precision, GC-managed
    (cache : (HashMap String Chunk))) ;; ω: shared mutable, GC-managed

  ;; Behavior: processes incoming messages
  ;; GC runs BETWEEN behavior invocations
  (behavior process-file
    (msg : 1 FileRequest)             ;; 1: linear, freed after behavior
    (let filename (file-request/name msg))  ;; consumed: msg freed here

    ;; 0-multiplicity: type-level proof, erased at runtime
    (let prf : 0 (valid-filename filename))

    ;; 1-multiplicity: linear file handle, deterministic close
    (let-linear (fh (open-file filename))
      (let contents (read-all fh))    ;; fh consumed here, freed

      ;; ω-multiplicity: cached result, may be shared
      (hashmap/insert cache filename contents)
      (set! processed-count (+ processed-count 1)))))

;; === Cross-actor sharing (ORCA protocol) ===

(actor Coordinator
  (behavior distribute
    (data : val ChunkList)            ;; val: immutable, shareable
    ;; ORCA tracks cross-actor references to data
    (for-each workers
      (fn (w) (send w (process-chunk data))))))
    ;; When all workers drop their val references,
    ;; ORCA decrements owner's count; data is freed
    ;; when count reaches 0
```

### 16.13 Phased Implementation Plan

**Phase 1: QTT Multiplicity Tracking (Month 1–3)**
- Implement multiplicity checking in the type checker
- Verify 0-multiplicity erasure in code generation
- Implement 1-multiplicity deterministic deallocation (stack/RAII)
- Test with simple programs; verify that linear values are never GC'd

**Phase 2: Per-Actor Collection (Month 3–6)**
- Implement per-actor heap data structure (modeled on libponyrt)
- Implement mark-and-don't-sweep local GC
- Implement bump-pointer nursery with copying collection
- Implement Perceus-style RC for tenured ω-multiplicity values
- Test with single-actor programs; measure pause times

**Phase 3: ORCA Protocol (Month 6–9)**
- Implement reference capability checking (iso/val/tag sendability)
- Implement INC/DEC protocol with weighted counting
- Implement message piggybacking
- Test with multi-actor programs; verify correctness under concurrency

**Phase 4: Cycle Detection and Polish (Month 9–12)**
- Implement distributed cycle detection for actor cycles
- Implement periodic SATB backup tracing for object-level cycles
- Performance tuning: allocation thresholds, batch sizes
- Benchmarking against Erlang, Pony, and Go GC
- Integration testing with session types and dependent types

**Phase 5: LLVM Production Backend (Month 12–18)**
- Implement libprologosrt in C (pool allocators, per-actor heaps, scheduler)
- Implement LLVM code generation with C-backend RC emission
- Optionally: migrate to LLVM statepoints for precise collection
- Production-quality error messages for memory errors
- Stress testing with large actor populations and sustained load

---

## 17. References and Key Literature

### Foundational Works

1. McCarthy, J. (1960). "Recursive Functions of Symbolic Expressions and Their Computation by Machine, Part I." *Communications of the ACM*, 3(4).
2. Collins, G. E. (1960). "A Method for Overlapping and Erasure of Lists." *Communications of the ACM*, 3(12).
3. Cheney, C. J. (1970). "A Nonrecursive List Compacting Algorithm." *Communications of the ACM*, 13(11).
4. Dijkstra, E. W., Lamport, L., Martin, A. J., Scholten, C. S., & Steffens, E. F. M. (1978). "On-the-fly Garbage Collection: An Exercise in Cooperation." *Communications of the ACM*, 21(11).
5. Ungar, D. (1984). "Generation Scavenging: A Non-Disruptive High Performance Storage Reclamation Algorithm." *SIGPLAN Notices*, 19(5).
6. Appel, A. W. (1989). "Simple Generational Garbage Collection and Fast Allocation." *Software—Practice and Experience*, 19(2).

### Concurrent and Incremental Collection

7. Boehm, H.-J., Demers, A. J., & Shenker, S. (1991). "Mostly Parallel Garbage Collection." *PLDI 1991*.
8. Baker, H. G. (1992). "The Treadmill: Real-Time Garbage Collection Without Motion Sickness." *ACM SIGPLAN Notices*, 27(3).
9. Printezis, T. & Detlefs, D. (2000). "A Generational Mostly-Concurrent Garbage Collector." *ISMM 2000*.
10. Hudson, R. & Moss, E. (2001). "Sapphire: Copying GC Without Stopping the World."
11. Bacon, D. & Rajan, V. T. (2001). "Concurrent Cycle Collection in Reference Counted Systems."

### Pauseless and Ultra-Low-Pause Collectors

12. Click, C., Tene, G., & Wolf, M. (2005). "The Pauseless GC Algorithm." *VEE 2005*.
13. Tene, G., Iyengar, B., & Wolf, M. (2011). "C4: The Continuously Concurrent Compacting Collector." *ISMM 2011*.
14. Liden, P. & Karlsson, S. (2018). "ZGC: A Scalable Low-Latency Garbage Collector." JEP 333.
15. Flood, C. et al. (2016). "Shenandoah: An Open-Source Concurrent Compacting Garbage Collector for OpenJDK." *PPPJ 2016*.

### Pony and ORCA

16. Clebsch, S. & Drossopoulou, S. (2013). "Fully Concurrent Garbage Collection of Actors on Many-Core Machines." *OOPSLA 2013*.
17. Clebsch, S., Drossopoulou, S., Blessing, S., & McNeil, A. (2015). "Deny Capabilities for Safe, Fast Actors." *AGERE! 2015*.
18. Clebsch, S., Franco, J., Drossopoulou, S., Yang, A. M., Wrigstad, T., & Vitek, J. (2017). "Orca: GC and Type System Co-Design for Actor Languages." *OOPSLA 2017*.
19. Clebsch, S., Drossopoulou, S., Blessing, S., & McNeil, A. (2016). "Pony: Co-designing a Type System and a Runtime." *SPLASH 2016*.

### Type-System-Assisted Memory Management

20. Reinking, A., Xie, N., de Moura, L., & Leijen, D. (2021). "Perceus: Garbage Free Reference Counting with Reuse." *PLDI 2021*.
21. Lorenzen, A., Leijen, D., & Swierstra, W. (2022). "FP²: Fully in-Place Functional Programming." *ICFP 2023*.
22. Atkey, R. (2018). "Syntax and Semantics of Quantitative Type Theory." *LICS 2018*.
23. Brady, E. (2021). "Idris 2: Quantitative Type Theory in Practice." *ECOOP 2021*.

### Hybrid Collectors

24. Bacon, D., Cheng, P., & Rajan, V. T. (2004). "A Unified Theory of Garbage Collection." *OOPSLA 2004*.
25. Blackburn, S. M. & McKinley, K. S. (2003). "Ulterior Reference Counting: Fast Garbage Collection Without a Long Wait." *OOPSLA 2003*.
26. Blackburn, S. M. & McKinley, K. S. (2008). "Immix: A Mark-Region Garbage Collector with Space Efficiency, Fast Collection, and Mutator Performance." *PLDI 2008*.
27. Zhao, W., Blackburn, S. M., & McKinley, K. S. (2022). "Low-Latency, High-Throughput Garbage Collection." *PLDI 2022*. (LXR)

### Region-Based and Ownership Approaches

28. Tofte, M. & Talpin, J.-P. (1997). "Region-Based Memory Management." *Information and Computation*, 132(2).
29. Grossman, D. et al. (2002). "Region-Based Memory Management in Cyclone." *PLDI 2002*.
30. Gordon, C., Parkinson, M., Parsons, J., Bromfield, A., & Duffy, J. (2012). "Uniqueness and Reference Immutability for Safe Parallelism." *OOPSLA 2012*.

### Functional Language GC

31. Sivaramakrishnan, K. C. et al. (2020). "Retrofitting Parallelism onto OCaml." *ICFP 2020*.
32. Gamari, B. & Dietz, L. (2020). "Alligator Collector: A Latency-Optimized Garbage Collector for Functional Programming Languages." *ISMM 2020*.
33. de Moura, L. & Ullrich, S. (2021). "The Lean 4 Theorem Prover and Programming Language." *CADE 2021*.

### LLVM GC Infrastructure

34. LLVM Documentation. "Garbage Collection Safepoints in LLVM." https://llvm.org/docs/Statepoints.html
35. LLVM Documentation. "Garbage Collection with LLVM." https://llvm.org/docs/GarbageCollection.html
36. LLVM Documentation. "Stack Maps and Patch Points in LLVM." https://llvm.org/docs/StackMaps.html

### Formal Verification

37. Myreen, M. O. (2010). "Reusable Verification of a Copying Collector." *VSTTE 2010*.
38. Anand, A. et al. (2017). "CertiCoq: A Verified Compiler for Coq." *CoqPL 2017*.
39. Jung, R. et al. (2015). "Iris: Monoids and Invariants as an Orthogonal Basis for Concurrent Reasoning." *ICFP 2015*.

### Emerging Techniques

40. Powers, B., Tench, D., Berger, E., & McGregor, A. (2019). "Mesh: Compacting Memory Management for C/C++ Applications." *PLDI 2019*.

### Production Experience

41. Wallaroo Labs. "Why We Used Pony to Write Wallaroo." https://blog.wallaroolabs.com/2017/10/why-we-used-pony-to-write-wallaroo/
42. Netflix Technology Blog. "Bending Pause Times to Your Will with Generational ZGC." 2024.
43. Uber Engineering. "How We Saved 70K Cores Across 30 Mission-Critical Services." 2023.
