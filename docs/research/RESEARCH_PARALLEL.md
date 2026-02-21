# Research Report: Parallel Computing and Concurrency

## From HPC Foundations to Propagator-Based Parallelism: Automatic Parallelization, Parallel Unification, and Concrete Guidance for Πρόλογος

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Foundations of Parallel Computing](#2-foundations-of-parallel-computing)
   - 2.1 [Flynn's Taxonomy and Parallel Architectures](#21-flynns-taxonomy-and-parallel-architectures)
   - 2.2 [Amdahl's Law and Its Limitations](#22-amdahls-law-and-its-limitations)
   - 2.3 [Gustafson's Law: Scaled Speedup](#23-gustafsons-law-scaled-speedup)
   - 2.4 [The Work-Span Model and Brent's Theorem](#24-the-work-span-model-and-brents-theorem)
   - 2.5 [Cost Models: BSP, LogP, and PRAM](#25-cost-models-bsp-logp-and-pram)
3. [Parallel Execution Models](#3-parallel-execution-models)
   - 3.1 [Fork-Join Parallelism and Cilk](#31-fork-join-parallelism-and-cilk)
   - 3.2 [Work-Stealing Schedulers](#32-work-stealing-schedulers)
   - 3.3 [Bulk Synchronous Parallelism (BSP)](#33-bulk-synchronous-parallelism-bsp)
   - 3.4 [SPMD and Data Parallelism](#34-spmd-and-data-parallelism)
   - 3.5 [Task Parallelism and Dataflow](#35-task-parallelism-and-dataflow)
4. [Embarrassingly Parallel Patterns](#4-embarrassingly-parallel-patterns)
   - 4.1 [Map-Reduce and Parallel Map](#41-map-reduce-and-parallel-map)
   - 4.2 [Parallel Scan (Prefix Sum) and Reductions](#42-parallel-scan-prefix-sum-and-reductions)
   - 4.3 [Divide-and-Conquer and Task Farming](#43-divide-and-conquer-and-task-farming)
   - 4.4 [Data-Parallel Array Languages: APL, J, Futhark](#44-data-parallel-array-languages-apl-j-futhark)
   - 4.5 [Algorithmic Skeletons and Structured Parallelism](#45-algorithmic-skeletons-and-structured-parallelism)
5. [Automatic Parallelization](#5-automatic-parallelization)
   - 5.1 [The Polyhedral Model: PLUTO and Polly](#51-the-polyhedral-model-pluto-and-polly)
   - 5.2 [Stream Fusion and Deforestation](#52-stream-fusion-and-deforestation)
   - 5.3 [Speculative Parallelism and Transactional Memory](#53-speculative-parallelism-and-transactional-memory)
   - 5.4 [Implicit Parallelism in Functional Languages](#54-implicit-parallelism-in-functional-languages)
   - 5.5 [Granularity Control and Cost Models](#55-granularity-control-and-cost-models)
   - 5.6 [Mercury's Automatic Parallelization](#56-mercurys-automatic-parallelization)
6. [Concurrency Primitives for Typed Languages](#6-concurrency-primitives-for-typed-languages)
   - 6.1 [Session Types and Concurrent Communication](#61-session-types-and-concurrent-communication)
   - 6.2 [Multiparty Session Types (MPST) for Parallel Protocols](#62-multiparty-session-types-mpst-for-parallel-protocols)
   - 6.3 [Dependent Session Types: Indexed by Computation State](#63-dependent-session-types-indexed-by-computation-state)
   - 6.4 [The Caires-Pfenning-Toninho Correspondence](#64-the-caires-pfenning-toninho-correspondence)
   - 6.5 [Structured Concurrency: Trio, Kotlin, Swift, Java Loom](#65-structured-concurrency-trio-kotlin-swift-java-loom)
   - 6.6 [Algebraic Effects for Concurrency: Koka, OCaml 5, Frank](#66-algebraic-effects-for-concurrency-koka-ocaml-5-frank)
7. [Process Calculi and Channel-Based Concurrency](#7-process-calculi-and-channel-based-concurrency)
   - 7.1 [The π-Calculus and Mobility](#71-the-π-calculus-and-mobility)
   - 7.2 [Linear π-Calculus and Session-Typed Processes](#72-linear-π-calculus-and-session-typed-processes)
   - 7.3 [Join Calculus and JoCaml](#73-join-calculus-and-jocaml)
   - 7.4 [Communicating Sequential Processes (CSP)](#74-communicating-sequential-processes-csp)
   - 7.5 [CML First-Class Events and Selective Synchronization](#75-cml-first-class-events-and-selective-synchronization)
   - 7.6 [Software Transactional Memory (STM)](#76-software-transactional-memory-stm)
8. [Actor Extensions and Typed Concurrency](#8-actor-extensions-and-typed-concurrency)
   - 8.1 [Typed Actors and Session-Typed Actors](#81-typed-actors-and-session-typed-actors)
   - 8.2 [Supervision Trees and Fault Tolerance](#82-supervision-trees-and-fault-tolerance)
   - 8.3 [Pony's Reference Capabilities for Data-Race Freedom](#83-ponys-reference-capabilities-for-data-race-freedom)
   - 8.4 [QTT Multiplicities and Concurrency Guarantees](#84-qtt-multiplicities-and-concurrency-guarantees)
9. [Deterministic Parallelism](#9-deterministic-parallelism)
   - 9.1 [The CALM Theorem: Consistency as Logical Monotonicity](#91-the-calm-theorem-consistency-as-logical-monotonicity)
   - 9.2 [LVars: Lattice Variables for Determinism](#92-lvars-lattice-variables-for-determinism)
   - 9.3 [CRDTs: Conflict-Free Replicated Data Types](#93-crdts-conflict-free-replicated-data-types)
   - 9.4 [Bloom and CALM-Based Programming](#94-bloom-and-calm-based-programming)
10. [Parallel Logic Programming](#10-parallel-logic-programming)
    - 10.1 [OR-Parallelism: Aurora and Muse](#101-or-parallelism-aurora-and-muse)
    - 10.2 [AND-Parallelism: &-Prolog and Ciao](#102-and-parallelism-prolog-and-ciao)
    - 10.3 [Concurrent Logic Languages: PARLOG, GHC, KL1](#103-concurrent-logic-languages-parlog-ghc-kl1)
    - 10.4 [Mercury's Auto-Parallelization of Logic Programs](#104-mercurys-auto-parallelization-of-logic-programs)
    - 10.5 [Datalog Parallelization: Soufflé and Differential Dataflow](#105-datalog-parallelization-soufflé-and-differential-dataflow)
11. [Parallel Unification](#11-parallel-unification)
    - 11.1 [The Unification Problem and Its Complexity](#111-the-unification-problem-and-its-complexity)
    - 11.2 [Dwork, Kanellakis, and Mitchell: PRAM Parallel Unification](#112-dwork-kanellakis-and-mitchell-pram-parallel-unification)
    - 11.3 [Practical Parallel Unification Strategies](#113-practical-parallel-unification-strategies)
    - 11.4 [Parallel Higher-Order Unification Considerations](#114-parallel-higher-order-unification-considerations)
    - 11.5 [Parallel Constraint Solving: SAT, SMT, and CLP](#115-parallel-constraint-solving-sat-smt-and-clp)
12. [Propagator Networks as Parallel Execution Framework](#12-propagator-networks-as-parallel-execution-framework)
    - 12.1 [Natural Parallelism in Propagator Networks](#121-natural-parallelism-in-propagator-networks)
    - 12.2 [The CALM-Propagator Connection](#122-the-calm-propagator-connection)
    - 12.3 [Propagators as Unifying Parallel Runtime](#123-propagators-as-unifying-parallel-runtime)
    - 12.4 [Mapping Actors, Logic Rules, and Constraints to Propagators](#124-mapping-actors-logic-rules-and-constraints-to-propagators)
    - 12.5 [Scheduling Strategies for Propagator Networks](#125-scheduling-strategies-for-propagator-networks)
    - 12.6 [Lattice-Based Merge and Monotonic Computation](#126-lattice-based-merge-and-monotonic-computation)
13. [LLVM Infrastructure for Parallelism](#13-llvm-infrastructure-for-parallelism)
    - 13.1 [Automatic Vectorization: SLP and Loop Vectorizer](#131-automatic-vectorization-slp-and-loop-vectorizer)
    - 13.2 [Polly: The Polyhedral Optimizer for LLVM](#132-polly-the-polyhedral-optimizer-for-llvm)
    - 13.3 [OpenMP Lowering and the LLVM Runtime](#133-openmp-lowering-and-the-llvm-runtime)
    - 13.4 [MLIR Dialects: SCF, OMP, Async, and Beyond](#134-mlir-dialects-scf-omp-async-and-beyond)
    - 13.5 [LLVM Coroutines and Async/Await](#135-llvm-coroutines-and-asyncawait)
14. [Modern Parallel Language Designs](#14-modern-parallel-language-designs)
    - 14.1 [Chapel: Multiresolution Parallelism](#141-chapel-multiresolution-parallelism)
    - 14.2 [Futhark: Purely Functional GPU Programming](#142-futhark-purely-functional-gpu-programming)
    - 14.3 [Julia's Parallel Model: Tasks, Channels, and Distributed](#143-julias-parallel-model-tasks-channels-and-distributed)
    - 14.4 [Haskell's Parallel Strategies and Par Monad](#144-haskells-parallel-strategies-and-par-monad)
    - 14.5 [Rust's Rayon and Fearless Concurrency](#145-rusts-rayon-and-fearless-concurrency)
15. [Lock-Free and Wait-Free Data Structures](#15-lock-free-and-wait-free-data-structures)
    - 15.1 [Michael-Scott Queue and Harris Linked List](#151-michael-scott-queue-and-harris-linked-list)
    - 15.2 [Epoch-Based Reclamation and Hazard Pointers](#152-epoch-based-reclamation-and-hazard-pointers)
    - 15.3 [Persistent Data Structures for Concurrent Access](#153-persistent-data-structures-for-concurrent-access)
16. [Considerations for Πρόλογος Implementors](#16-considerations-for-πρόλογος-implementors)
    - 16.1 [Unified Architecture: Propagators as the Parallel Runtime](#161-unified-architecture-propagators-as-the-parallel-runtime)
    - 16.2 [Session-Typed Channels for Communication](#162-session-typed-channels-for-communication)
    - 16.3 [QTT-Guided Automatic Parallelization Strategy](#163-qtt-guided-automatic-parallelization-strategy)
    - 16.4 [Parallel Unification in the Type Checker and Runtime](#164-parallel-unification-in-the-type-checker-and-runtime)
    - 16.5 [CALM-Aware Compiler: Detecting Monotonic Computations](#165-calm-aware-compiler-detecting-monotonic-computations)
    - 16.6 [Embarrassingly Parallel by Default: The Design Philosophy](#166-embarrassingly-parallel-by-default-the-design-philosophy)
    - 16.7 [Structured Concurrency with Dependent Types](#167-structured-concurrency-with-dependent-types)
    - 16.8 [Integration with Pony-Style Actor GC](#168-integration-with-pony-style-actor-gc)
    - 16.9 [LLVM Backend: Leveraging Vectorization and Polly](#169-llvm-backend-leveraging-vectorization-and-polly)
    - 16.10 [Concrete Syntax Sketches for Parallelism in Πρόλογος](#1610-concrete-syntax-sketches-for-parallelism-in-πρόλογος)
    - 16.11 [Compiler Error Messages for Concurrency Violations](#1611-compiler-error-messages-for-concurrency-violations)
    - 16.12 [Phased Implementation Plan](#1612-phased-implementation-plan)
17. [References and Further Reading](#17-references-and-further-reading)

---

## 1. Introduction

Parallelism and concurrency represent two of the most pressing challenges in modern programming language design. As single-core clock speeds have plateaued, exploiting the parallelism available in multi-core processors, distributed systems, and heterogeneous architectures has become essential. For Πρόλογος, a language that combines dependent types, session types, linear types (via QTT), and propagator-based computation, the opportunity is extraordinary: the type system itself can guide and guarantee safe parallelization in ways that no mainstream language currently achieves.

This report surveys the landscape of parallel computing from three complementary perspectives. First, we examine the foundations of high-performance computing (HPC) — the theoretical models, execution strategies, and automatic parallelization techniques that have powered scientific computing for decades. Second, we explore concurrency primitives that harmonize with advanced type systems — session-typed channels, structured concurrency, algebraic effects, and the process calculi that underpin them. Third, and most distinctively, we investigate parallelism in the logic programming domain — OR-parallelism, AND-parallelism, parallel unification algorithms, and the emerging recognition that propagator networks provide a natural substrate for all three forms of parallelism.

A recurring theme emerges: the CALM theorem (Consistency As Logical Monotonicity) establishes that monotonically growing computations — computations over lattice structures — can be safely parallelized without coordination. Propagator networks, built fundamentally on lattice-based merge operations, are thus inherently CALM-compliant. This deep connection between Πρόλογος's propagator foundations and the theoretical guarantees of deterministic parallelism provides a principled path toward the language's stated goal: *anything that is "embarrassingly" parallel should be so automatically*.

---

## 2. Foundations of Parallel Computing

### 2.1 Flynn's Taxonomy and Parallel Architectures

Michael Flynn's 1966 classification of computer architectures remains the standard vocabulary for parallel computing. The taxonomy categorizes systems along two dimensions — instruction streams and data streams — yielding four classes.

**SISD** (Single Instruction, Single Data) describes the classical von Neumann machine. **SIMD** (Single Instruction, Multiple Data) applies one operation across many data elements simultaneously — modern GPUs and CPU vector units (SSE, AVX-512, ARM NEON) operate in this mode. **MISD** (Multiple Instruction, Single Data) is rare but appears in fault-tolerant systems. **MIMD** (Multiple Instruction, Multiple Data) describes most modern multi-core processors and distributed systems, where independent processors execute different instructions on different data.

For Πρόλογος, SIMD matters for array operations and numerical kernels (especially with posit arithmetic), while MIMD underlies the actor model and propagator network execution. The language must generate code that exploits both.

### 2.2 Amdahl's Law and Its Limitations

Gene Amdahl's 1967 observation constrains the maximum speedup achievable through parallelization. If a fraction *s* of a program is inherently sequential, the speedup with *p* processors is bounded by:

```
S(p) = 1 / (s + (1 - s) / p)
```

As *p* → ∞, the speedup approaches 1/*s*. If 5% of a program is sequential, no amount of parallelism yields more than 20× speedup. This has profound implications: eliminating sequential bottlenecks matters more than adding processors.

For language designers, Amdahl's Law motivates two strategies: (1) minimize inherently sequential operations in the runtime (GC pauses, global synchronization, sequential scheduling), and (2) maximize the parallelizable fraction through compiler analysis. Πρόλογος's per-actor GC (no global pauses) and propagator-based scheduler (no global coordination for monotonic operations) directly address both.

### 2.3 Gustafson's Law: Scaled Speedup

John Gustafson's 1988 reformulation observes that in practice, increasing processor count often accompanies increasing problem size. The scaled speedup is:

```
S(p) = p - s × (p - 1)
```

This shifts the perspective from fixed-problem speedup to fixed-time speedup. Where Amdahl's Law can seem pessimistic, Gustafson's Law observes that parallelism enables solving larger problems in the same time — the typical HPC use case.

For Πρόλογος, this reinforces the importance of scaling propagator networks: as constraint problems grow, adding more parallel propagators should proportionally expand the solvable problem space.

### 2.4 The Work-Span Model and Brent's Theorem

The work-span model provides a practical framework for analyzing parallel algorithms. The **work** *T₁* is the total number of operations (sequential execution time). The **span** *T∞* is the length of the longest sequential chain (execution time with unlimited processors). The **parallelism** is the ratio *T₁ / T∞*.

Brent's Theorem bounds the execution time on *p* processors:

```
T_p ≤ T₁/p + T∞
```

This is remarkably tight in practice. A parallel algorithm is efficient when its parallelism *T₁ / T∞* significantly exceeds *p*. Work-stealing schedulers (Section 3.2) achieve performance within a constant factor of this bound.

The work-span model applies directly to propagator networks: each propagator activation is a unit of work, and the span is determined by the longest chain of dependent propagator firings through the network.

### 2.5 Cost Models: BSP, LogP, and PRAM

**PRAM** (Parallel Random Access Machine) is the simplest theoretical model: *p* processors sharing a global memory, executing synchronous steps. Variants differ in how concurrent memory access is handled — CREW (Concurrent Read, Exclusive Write) and CRCW (Concurrent Read, Concurrent Write). PRAM algorithms provide clean asymptotic bounds (e.g., Dwork et al.'s O(log n) parallel unification runs on a CRCW PRAM).

**BSP** (Bulk Synchronous Parallel), proposed by Valiant in 1990, models computation as a sequence of supersteps: local computation, communication, and a barrier synchronization. BSP accurately models many real systems and provides a cost formula: the cost of a superstep is max(w_i) + h·g + l, where w_i is the local work, h the communication volume, g the bandwidth gap, and l the synchronization latency.

**LogP** refines BSP by characterizing the network with four parameters: Latency, overhead, gap (minimum inter-message spacing), and number of Processors. LogP captures pipelining effects that BSP misses.

For Πρόλογος, the propagator scheduler most naturally maps to BSP-like execution: propagators fire (local computation), propagate results to neighbors (communication), and the scheduler detects quiescence (implicit barrier). However, the lattice-monotonicity of propagator merge means barriers can often be relaxed — a key advantage explored in Section 12.

---

## 3. Parallel Execution Models

### 3.1 Fork-Join Parallelism and Cilk

Fork-join is the most widely used parallel execution model. A computation **forks** child tasks that execute in parallel, then **joins** (waits for) their completion before proceeding. Cilk, developed by Leiserson and colleagues at MIT, provides the canonical implementation with just two keywords: `spawn` (fork a function call) and `sync` (join all spawned children).

Cilk's genius lies in its efficiency guarantee: a Cilk program running on *p* processors completes in expected time O(T₁/p + T∞), matching Brent's theorem within constant factors. The implementation achieves this through work-stealing (Section 3.2).

The fork-join model maps naturally to divide-and-conquer algorithms: parallel merge sort, parallel quicksort, matrix multiplication, tree traversals, and recursive decompositions. For Πρόλογος, fork-join provides the primary mechanism for parallelizing recursive function calls — the compiler can insert spawn/sync when function arguments are independent.

### 3.2 Work-Stealing Schedulers

Work-stealing is the scheduling algorithm that makes fork-join practical. Each processor maintains a local deque (double-ended queue) of tasks. When a processor runs out of work, it **steals** from the bottom of a random other processor's deque. The key insight: the thief steals the oldest (largest) tasks, maximizing the payoff of stealing while minimizing steal frequency.

Blumofe and Leiserson proved that work-stealing achieves the optimal bound: expected running time is O(T₁/p + T∞) with space O(S₁ · p), where S₁ is the sequential stack space. The number of steal attempts is O(p · T∞), meaning steals are rare relative to total work.

Modern implementations include Intel TBB (Threading Building Blocks), Rust's Rayon library, Tokio (for async I/O tasks), Go's goroutine scheduler, and Java's ForkJoinPool. These vary in details — deque implementation (ABP lock-free deque), task granularity, idle behavior — but all follow the same core algorithm.

For Πρόλογος, work-stealing should schedule both actor message processing (as in Pony's runtime) and propagator firings. The scheduler must be aware that propagator firings are typically fine-grained, requiring adaptive granularity control (Section 5.5).

### 3.3 Bulk Synchronous Parallelism (BSP)

Valiant's BSP model structures computation as a sequence of supersteps, each comprising three phases: concurrent local computation by all processors, global communication where processors exchange messages, and a barrier synchronization that ensures all messages are delivered before the next superstep begins.

BSP's appeal is its simplicity of reasoning: the cost of a program is the sum of superstep costs, each of which is straightforward to estimate. Google's Pregel system for graph processing and Apache Giraph are BSP implementations at massive scale.

For logic programming, BSP naturally models bottom-up evaluation of Datalog programs: each superstep derives new facts, communicates them to relevant processors, and synchronizes before the next derivation round. Soufflé's parallel Datalog engine uses a BSP-like approach.

### 3.4 SPMD and Data Parallelism

Single Program, Multiple Data (SPMD) extends SIMD to the programming level: the same program executes on all processors, each operating on a different partition of the data. MPI programs are typically SPMD, as are GPU kernels (CUDA, OpenCL, SYCL).

Data parallelism expresses operations over collections — map, reduce, scan, filter — that can execute on each element independently. Languages like APL, J, NumPy, MATLAB, and Futhark are fundamentally data-parallel: operations on arrays implicitly distribute across available hardware.

For Πρόλογος, data-parallel operations on vectors, matrices, and higher-dimensional arrays (especially with posit arithmetic) should map to SIMD instructions via LLVM's vectorizer and, for large workloads, to GPU kernels via LLVM's NVPTX or AMDGPU backends.

### 3.5 Task Parallelism and Dataflow

In dataflow execution, a computation is a directed graph of tasks; a task becomes eligible for execution when all its inputs are available. This contrasts with control-flow execution, where the program counter dictates ordering.

Dataflow naturally expresses task parallelism without explicit synchronization — the data dependencies are the synchronization. Systems like Intel TBB's flow graph, Dask (Python), and Apple's Grand Central Dispatch implement task-parallel dataflow.

Propagator networks are a form of dataflow: propagators fire when their input cells are updated, and the network's topology determines data dependencies. The connection is deep — propagators generalize traditional dataflow by supporting bidirectional information flow and lattice-valued cells.

---

## 4. Embarrassingly Parallel Patterns

### 4.1 Map-Reduce and Parallel Map

The simplest and most powerful parallel pattern is *map*: apply a function independently to each element of a collection. Because element computations are independent, map is embarrassingly parallel — it requires zero inter-task communication.

Dean and Ghemawat's MapReduce framework (2004) extends this with a *reduce* phase that aggregates results using an associative binary operator. The power of MapReduce lies in its generality: any problem expressible as an independent per-element transformation followed by an associative aggregation can be parallelized with minimal overhead.

For Πρόλογος, `map` over any collection type should automatically parallelize when the mapping function is pure (no side effects). QTT multiplicities provide the mechanism: if the function's closure captures only 0-multiplicity (erased) or ω-multiplicity (freely copyable) values, the compiler can guarantee purity and parallelize without annotation.

```
;; Pure map — compiler auto-parallelizes
(def squares (map (fn (x) (* x x)) data))

;; Impure map — compiler prevents auto-parallelization
(def results (map (fn (x) (io/print x) x) data))
```

### 4.2 Parallel Scan (Prefix Sum) and Reductions

Parallel **scan** (also called prefix sum) computes all prefixes of a binary associative operation. Given [a₁, a₂, ..., aₙ] and operator ⊕, the inclusive scan produces [a₁, a₁⊕a₂, a₁⊕a₂⊕a₃, ...]. The Blelloch scan achieves O(n) work and O(log n) span, making it highly parallel.

Parallel **reduction** (fold) computes a single aggregate value using an associative operator. The tree-reduction pattern achieves O(n) work and O(log n) span.

These primitives are universal building blocks: parallel sorting (radix sort uses scan), stream compaction (filter uses scan to compute output positions), histogram computation, and many numerical algorithms reduce to compositions of map, scan, and reduce.

For Πρόλογος, the compiler should recognize associative operators (either through algebraic structure annotations or automatic inference from algebraic laws) and automatically parallelize folds and scans.

```
;; Associative fold — auto-parallelizable
(def total (fold/assoc + 0 values))

;; The 'assoc' qualifier tells the compiler the operator is associative,
;; enabling tree-reduction parallelization
```

### 4.3 Divide-and-Conquer and Task Farming

Divide-and-conquer algorithms recursively split a problem, solve subproblems independently, and combine results. The independence of subproblems makes this pattern naturally parallel: each recursive branch can execute concurrently.

Task farming (also called master-worker or task bag) distributes independent work items to a pool of workers. Unlike divide-and-conquer, task farming does not require recursive structure — any collection of independent tasks suffices.

Both patterns are served by work-stealing schedulers: divide-and-conquer generates tasks through recursive spawning, while task farming pre-populates the work deque. The key implementation concern is **granularity**: tasks too small waste scheduling overhead; tasks too large leave processors idle.

### 4.4 Data-Parallel Array Languages: APL, J, Futhark

APL (Iverson, 1962) pioneered the idea that operations on scalars extend naturally to arrays. The expression `A + B` adds two arrays element-wise, and `+/ A` reduces array A by addition — both are implicitly parallel.

Futhark (Henriksen et al., 2017) is a modern purely functional data-parallel language that compiles to GPU kernels. Futhark's key innovation is a moderate size-type system that tracks array dimensions, combined with aggressive fusion transformations (map-map fusion, map-reduce fusion, map-scan fusion) that eliminate intermediate arrays and generate efficient GPU code.

For Πρόλογος, Futhark demonstrates that a purely functional array sublanguage with size types can generate competitive GPU code. Since Πρόλογος already has dependent types (which subsume Futhark's size types), it can express even richer array invariants while targeting LLVM's vectorization and GPU backends.

### 4.5 Algorithmic Skeletons and Structured Parallelism

Algorithmic skeletons (Cole, 1989) abstract recurring patterns of parallel computation as higher-order functions with known-efficient parallel implementations. Common skeletons include: `farm` (apply a function to a stream of inputs using worker pool), `pipe` (chain sequential stages, each parallelized), `divide-and-conquer`, `map`, `reduce`, `scan`, `stencil` (update each element based on neighbors), and `branch-and-bound`.

The FastFlow framework, SkePU, and SkelCL provide skeleton implementations targeting multi-core CPUs and GPUs. The key insight: if a user expresses their computation using a known skeleton, the runtime can apply the optimal parallelization strategy without user intervention.

For Πρόλογος, a standard library of parallel skeletons — each backed by a verified propagator network implementation — provides the recommended path for expressing embarrassingly parallel computations.

---

## 5. Automatic Parallelization

### 5.1 The Polyhedral Model: PLUTO and Polly

The polyhedral model represents loop nests as systems of linear inequalities over an integer lattice. Loop iterations become integer points in a polyhedron, and dependencies between iterations become affine relations. This geometric representation enables powerful transformations: tiling (for cache locality), interchange (for parallelism), skewing (for wavefront parallelism), and fusion/fission (for reducing memory traffic).

The PLUTO algorithm (Bondhugula et al., 2008) automatically finds the optimal affine schedule for a loop nest — the schedule that maximizes parallelism while respecting all dependencies. PLUTO models this as an integer linear programming (ILP) problem and solves it using standard ILP solvers.

**Polly** is LLVM's implementation of the polyhedral model. Polly operates on LLVM IR, detects loops with affine bounds and access patterns (SCoPs — Static Control Parts), represents them as polyhedra using the isl (Integer Set Library), applies PLUTO-like scheduling, and generates either parallel OpenMP code or SIMD-vectorized loops.

For Πρόλογος, Polly is directly relevant: numerical loops in compiled Πρόλογος code (especially posit arithmetic kernels) can benefit from polyhedral optimization. The compiler should emit LLVM IR in a form that Polly can analyze — this means preserving loop structure through compilation rather than converting everything to tail calls.

### 5.2 Stream Fusion and Deforestation

Functional languages represent computation as pipelines of higher-order functions: `map f . filter p . map g`. Naively, each stage allocates an intermediate data structure. **Deforestation** (Wadler, 1988) and **stream fusion** (Coutts et al., 2007) eliminate these intermediaries by fusing adjacent operations into a single pass.

Stream fusion converts producer/consumer pairs into co-recursive step functions, then fuses them by inlining. The result: a pipeline like `sum . map (*2) . filter even` compiles to a single loop with no allocation.

For Πρόλογος, stream fusion is essential for parallelism: fused pipelines have lower memory traffic (better for cache and NUMA), produce tighter loops (better for SIMD vectorization), and reveal parallelism that was hidden by intermediate data structures.

### 5.3 Speculative Parallelism and Transactional Memory

When dependencies are uncertain at compile time, **speculative execution** runs tasks in parallel optimistically and rolls back if a conflict is detected. Hardware Transactional Memory (HTM), available on Intel (TSX) and IBM POWER processors, provides hardware support for optimistic concurrent execution with automatic rollback on conflict.

Software Transactional Memory (STM), pioneered by Shavit and Touitou (1995) and popularized by Haskell's STM implementation (Harris et al., 2005), provides composable atomic transactions in software. The key advantage of STM is composability: two separately correct transactional operations can be combined into a single atomic transaction, something impossible with locks.

For Πρόλογος, speculative parallelism can be applied to OR-parallel search (Section 10.1): try multiple unification branches in parallel, commit the first that succeeds, and abort the rest. STM's composability aligns with the propagator model's lattice merge — both are monotonic operations that can be safely combined.

### 5.4 Implicit Parallelism in Functional Languages

Purely functional languages offer the tantalizing promise of automatic parallelism: since expressions have no side effects, they can be evaluated in any order, including in parallel. In practice, extracting useful parallelism has proved challenging due to granularity issues — most expressions are too small to justify the overhead of parallel evaluation.

Haskell's approach uses **parallel strategies** (Marlow et al., 2010): annotations that specify evaluation order without changing semantics. The `par` combinator hints that an expression should be evaluated in parallel, while `seq` forces sequential evaluation. GHC's runtime system uses a work-stealing scheduler to distribute sparked evaluations across OS threads.

The key lesson is that automatic parallelism in pure functional languages works best when combined with programmer annotations or compiler heuristics for granularity control. Fully automatic approaches tend to either miss parallelism opportunities or introduce excessive overhead.

### 5.5 Granularity Control and Cost Models

The overhead of creating and scheduling a parallel task ranges from ~100ns (lightweight user-space scheduler) to ~10µs (OS thread creation). For parallelism to be profitable, the task must perform significantly more work than this overhead.

**Static granularity control** determines task sizes at compile time based on program analysis. Mercury (Section 5.6) uses profiling-based cost models to estimate clause execution times and only parallelizes clauses whose estimated cost exceeds a threshold.

**Dynamic granularity control** adapts at runtime. Lazy task creation (Mohr et al., 1991) defers the creation of parallel tasks until a processor becomes idle and attempts to steal work — only then is the task actually forked. This achieves near-zero overhead when parallelism isn't needed while still exploiting it when processors are available.

For Πρόλογος, a hybrid approach is recommended: static cost analysis (using dependent types to propagate size information) provides compile-time granularity estimates, while the runtime uses lazy task creation to adapt to actual workload.

### 5.6 Mercury's Automatic Parallelization

Mercury (Somogyi et al., 1996) is a logic/functional programming language with a strong type and mode system. Mercury's automatic parallelization (Bone et al., 2012) represents the state of the art for logic languages.

Mercury's approach works in three stages. First, a profiling pass collects execution cost data for each procedure. Second, the compiler's auto-parallelizer identifies pairs of conjuncts (goals executed in sequence) where both goals are expensive and their dependencies allow parallel execution. Third, a cost model estimates the parallel speedup and only introduces parallelism when it exceeds a configurable threshold.

Mercury's mode system (which tracks input/output directionality of arguments) provides the dependency information needed to determine which conjuncts are independent. This is analogous to QTT multiplicities: 0-multiplicity arguments don't create dependencies, ω-multiplicity arguments can be shared freely (read-only), and 1-multiplicity arguments create true sequential dependencies.

---

## 6. Concurrency Primitives for Typed Languages

### 6.1 Session Types and Concurrent Communication

Session types, introduced by Honda (1993) and developed by Honda, Vasconcelos, and Kubo (1998), describe the communication protocol between concurrent processes as a type. A session type specifies the sequence, direction, and payload types of messages exchanged over a channel.

The basic session type constructors are: `!T.S` (send a value of type T, then continue as S), `?T.S` (receive a value of type T, then continue as S), `S₁ ⊕ S₂` (internal choice — select one of two continuations), `S₁ & S₂` (external choice — offer both continuations to the partner), and `end` (session termination).

The key property is **duality**: if one endpoint has type S, the other has type S̄ (the dual of S). Duality ensures that every send has a corresponding receive, every internal choice meets an external choice, and the protocol cannot deadlock (for binary sessions).

For Πρόλογος, session types govern all inter-actor communication, all channel-based parallel coordination, and all interaction with external systems. Combined with dependent types, session types can encode protocols parameterized by runtime values — e.g., a channel that sends exactly *n* integers, where *n* is determined dynamically.

### 6.2 Multiparty Session Types (MPST) for Parallel Protocols

Multiparty session types (Honda, Yoshida, and Carbone, 2008) extend binary session types to protocols involving three or more participants. An MPST protocol is defined as a **global type** that describes the entire interaction, then **projected** onto each participant to produce a **local type**.

The projection operation ensures that each participant's local view is consistent with the global protocol. The key result: if each participant adheres to their local type, the global protocol is satisfied, including deadlock freedom and protocol fidelity.

For parallel computing, MPST naturally describes multi-party parallel coordination patterns: scatter-gather (one coordinator distributes work to *n* workers and collects results), pipeline (data flows through a chain of stages), and ring (processors pass messages around a ring, as in allreduce operations).

### 6.3 Dependent Session Types: Indexed by Computation State

Dependent session types (Toninho, Caires, and Pfenning, 2011) allow session types to depend on values. This enables protocols whose structure is determined at runtime.

For example, a file transfer protocol might first negotiate the number of chunks, then send exactly that many:

```
;; Dependent session type: number of chunks determines protocol structure
(session-type FileTransfer
  (! Nat                          ;; send chunk count n
   (depend n                      ;; rest of protocol depends on n
     (repeat n (! Bytes))          ;; send exactly n chunks
     (? Checksum)                  ;; receive verification
     end)))
```

This is the intersection where Πρόλογος's dependent types and session types combine most powerfully: the type checker statically verifies that a parallel protocol sends exactly the right number of messages, with the count determined by a runtime value.

### 6.4 The Caires-Pfenning-Toninho Correspondence

The Caires-Pfenning-Toninho (CPT) correspondence (2010) establishes a deep connection between linear logic and session types. Under this correspondence, propositions of linear logic correspond to session types, proofs correspond to processes, and cut elimination corresponds to communication.

Specifically: the linear logic connective ⊗ (tensor) corresponds to sending a channel, ⅋ (par) corresponds to receiving, ⊕ (plus) corresponds to internal choice, & (with) corresponds to external choice, 1 corresponds to session termination, and ! (exponential) corresponds to shared (replicable) sessions.

This correspondence ensures that well-typed processes in a CPT-based system are deadlock-free by construction — deadlock freedom follows from cut elimination, which is a fundamental property of linear logic.

For Πρόλογος, the CPT correspondence provides the theoretical foundation for combining session types with QTT: linear types (1-multiplicity) naturally correspond to session endpoints that must be used exactly once, while the exponential (ω-multiplicity) allows shared services.

### 6.5 Structured Concurrency: Trio, Kotlin, Swift, Java Loom

Structured concurrency, formalized by Martin Sústrik (2016) and popularized by Nathaniel Smith's Trio library (2018), enforces that concurrent lifetimes form a tree: a child task cannot outlive its parent scope. This eliminates orphaned tasks, dangling references to completed computations, and many classes of concurrency bugs.

In Trio (Python), a nursery scope manages child tasks:

```python
async with trio.open_nursery() as nursery:
    nursery.start_soon(fetch_url, url1)
    nursery.start_soon(fetch_url, url2)
# Both tasks guaranteed to complete or cancel before this point
```

Kotlin's coroutine scopes, Swift's task groups, and Java's virtual threads (Project Loom) all adopt structured concurrency. The key insight is that concurrent scope nesting mirrors lexical scope nesting, making concurrent programs as composable as sequential ones.

For Πρόλογος, structured concurrency is particularly natural because dependent types can encode the scope constraint: a task group's type depends on its children's types, and the type system ensures no reference escapes the scope.

### 6.6 Algebraic Effects for Concurrency: Koka, OCaml 5, Frank

Algebraic effects (Plotkin and Power, 2003; Plotkin and Pretnar, 2009) decompose computational effects into two parts: **operations** (effects declared by code) and **handlers** (implementations provided by context). This separation enables modular, composable effect handling.

For concurrency, algebraic effects provide primitives like `fork`, `yield`, `async`/`await`, and channel operations as effect operations, with the scheduler as the handler. The Koka language, OCaml 5's effect handlers, and the Frank language demonstrate this approach.

The key advantage for Πρόλογος: algebraic effects compose with the type system. An effectful function's type signature includes its effects, enabling the compiler to determine which functions are pure (and thus safely parallelizable) and which require sequential execution due to effects.

```
;; Effect-annotated type: compiler knows this is pure
(def square : (-> Int Int)
  (fn (x) (* x x)))

;; Effect-annotated type: compiler knows this has IO effects
(def print-square : (-> Int (IO Unit))
  (fn (x) (io/print (* x x))))
```

---

## 7. Process Calculi and Channel-Based Concurrency

### 7.1 The π-Calculus and Mobility

The π-calculus (Milner, Parrow, and Walker, 1992) extends CCS with **name-passing**: processes can communicate channel names, enabling dynamic reconfiguration of communication topology. The core syntax is remarkably simple: send a name on a channel, receive a name on a channel, parallel composition, restriction (create a new channel), and replication (create unbounded copies of a process).

The π-calculus is Turing-complete and serves as the foundation for virtually all modern concurrent programming models. Actors, channels, futures, and session-typed processes can all be encoded in the π-calculus.

For Πρόλογος, the π-calculus provides the semantic foundation for inter-actor communication. Channel creation corresponds to session initiation, name-passing enables delegation (passing a session endpoint to another actor), and restriction ensures channel names are scoped.

### 7.2 Linear π-Calculus and Session-Typed Processes

The linear π-calculus restricts the π-calculus so that each channel is used exactly once for sending and once for receiving. This restriction eliminates races and ensures deterministic communication.

Session-typed processes (Vasconcelos, 2012) combine linearity with protocol specifications. Each channel endpoint has a session type that evolves as communication proceeds — after sending an integer on a channel of type `!Int.S`, the endpoint's type becomes `S`. Linearity ensures that this evolution is well-defined: no aliasing means no confusion about the current protocol state.

The combination of linear channels and session types provides the strongest static guarantees for concurrent programs: no races, no deadlocks (for binary sessions), and protocol compliance by construction.

### 7.3 Join Calculus and JoCaml

The join calculus (Fournet and Gonthier, 1996) models concurrency through **join patterns**: a process can wait for messages on multiple channels simultaneously, proceeding only when all required messages have arrived.

```
join {
  get(k) & buffer(x) => k(x)     // get request + buffer content → reply
  put(x, k) & empty() => buffer(x); k()  // put request + empty signal → buffer + ack
}
```

Join patterns naturally express synchronization barriers, producer-consumer relationships, and resource pools. JoCaml implemented the join calculus as an extension to OCaml.

For Πρόλογος, join patterns provide an elegant primitive for synchronizing propagator activations: a propagator that depends on multiple cells can be expressed as a join pattern that fires only when all input cells have been updated.

### 7.4 Communicating Sequential Processes (CSP)

Hoare's CSP (1978) models concurrency as sequential processes that synchronize through channel communication. Unlike the actor model (asynchronous messaging), CSP channels are **synchronous**: the sender blocks until the receiver is ready, and vice versa. This synchronization provides a strong ordering guarantee that simplifies reasoning.

Go channels and Clojure's core.async implement CSP-style communication. Go's `select` statement allows a goroutine to wait on multiple channels, proceeding with whichever becomes ready first.

For Πρόλογος, synchronous channels can complement the primary asynchronous actor model for cases where tight synchronization is needed — e.g., a pipeline of propagator stages where each stage must complete before the next begins.

### 7.5 CML First-Class Events and Selective Synchronization

Concurrent ML (Reppy, 1991) generalizes CSP with **first-class events**: values that represent potential synchronizations. Events can be combined with `choose` (wait for any of several events), `wrap` (transform the result), `guard` (compute the event dynamically), and `withNack` (receive notification if this alternative was not chosen).

The power of CML events is composability: complex synchronization patterns can be built from simple event combinators without exposing implementation details. A module can export an event value without revealing what channels it synchronizes on.

For Πρόλογος, CML-style first-class events can be integrated with session types: an event's type includes the session type of the channel it synchronizes on, ensuring that choosing an event is always protocol-compliant.

### 7.6 Software Transactional Memory (STM)

Haskell's STM (Harris, Marlow, Peyton Jones, and Herlihy, 2005) provides composable atomic transactions for shared memory concurrency. The `atomically` function runs a transaction; `retry` blocks until a watched variable changes; `orElse` provides alternatives if the first transaction retries.

STM's key innovation is **composability**: if transaction A and transaction B are individually correct, `atomically (A >> B)` is also correct. This is impossible with lock-based programming, where composing two critical sections risks deadlock.

For Πρόλογος, STM provides a potential mechanism for shared cell access in propagator networks, though the primary model (lattice-based monotonic merge) avoids the need for transactions in most cases. STM is most useful for non-monotonic operations that require atomicity guarantees.

---

## 8. Actor Extensions and Typed Concurrency

### 8.1 Typed Actors and Session-Typed Actors

Traditional actor systems (Erlang, Akka) use dynamically typed messages — any message can be sent to any actor. This flexibility enables open systems but provides no static guarantees about protocol compliance.

Typed actors restrict the messages an actor can receive through its type. Akka Typed (Scala), for example, parameterizes actors by their message type: `Behavior[Command]` accepts only `Command` messages. Session-typed actors (Dardha, Giachino, and Sangiorgi, 2012) go further, encoding the entire communication protocol in the actor's type.

For Πρόλογος, each actor's type includes both its message protocol (as a session type) and its internal state type. The type system ensures that actors only send messages that conform to the recipient's protocol.

### 8.2 Supervision Trees and Fault Tolerance

Erlang's supervision trees organize actors into a hierarchy where parent actors monitor children and respond to failures according to a strategy: one-for-one (restart the failed child), one-for-all (restart all children), and rest-for-one (restart the failed child and all children started after it).

Supervision trees encode the principle of "let it crash": rather than trying to handle every possible error, design actors to crash cleanly and let the supervisor restart them. This provides fault tolerance without cluttering business logic with error handling.

For Πρόλογος, supervision trees can be typed: the supervisor's type includes the number and types of its children, and the restart strategy is a type-level parameter that the type checker can verify for consistency.

### 8.3 Pony's Reference Capabilities for Data-Race Freedom

Pony's reference capabilities system (Clebsch et al., 2015) provides compile-time data-race freedom through a capability lattice. Six capabilities — iso (isolated, read-write, unique), val (globally immutable), ref (local read-write, unshared), box (local read-only), trn (write-unique, transitioning to val), and tag (identity only, no access) — classify object references by their aliasing and mutability properties.

The deny capabilities matrix specifies which capability pairs are compatible for concurrent access. The key rule: if one reference can write to an object, no other actor may hold a readable or writable reference. This is enforced statically, with no runtime overhead.

For Πρόλογος, reference capabilities can be encoded using QTT multiplicities and dependent types. An `iso` reference corresponds to a 1-multiplicity binding; a `val` reference corresponds to an ω-multiplicity binding on an immutable type; a `tag` reference corresponds to a 0-multiplicity binding (type-level only).

### 8.4 QTT Multiplicities and Concurrency Guarantees

Quantitative Type Theory (McBride, 2018; Atkey, 2018) tracks how many times a binding is used: 0 (erased, type-level only), 1 (exactly once, linear), or ω (unrestricted). These multiplicities have direct implications for concurrency:

**0-multiplicity** bindings exist only at the type level and are erased at runtime. They create no data dependencies and impose no concurrency constraints — they are "free" parallelism.

**1-multiplicity** bindings must be consumed exactly once. This makes them ideal for representing unique ownership (like Pony's `iso`), session channel endpoints, and linear resources that transfer between actors without copying.

**ω-multiplicity** bindings can be freely copied and shared. They are safe for concurrent read access (like Pony's `val`) but require immutability guarantees. In Πρόλογος, ω-bindings on immutable data structures (persistent data structures with structural sharing) can be freely shared between actors.

The multiplicity system provides a language-level framework for expressing Pony-like reference capabilities without a separate capability annotation system.

---

## 9. Deterministic Parallelism

### 9.1 The CALM Theorem: Consistency as Logical Monotonicity

The CALM theorem (Hellerstein, 2010; Ameloot et al., 2011) is one of the most profound results in distributed computing: a program can be consistently evaluated without coordination (locks, barriers, consensus) if and only if it is **monotonic** — it never retracts a previously derived conclusion.

Formally, a query Q is monotonic if for all databases I ⊆ J, Q(I) ⊆ Q(J). Adding more input data to a monotonic query can only add more output — never retract previous results. Monotonic queries include unions, intersections, selections, projections, and joins (in Datalog terms: any query without negation or aggregation).

The CALM theorem guarantees that monotonic programs produce the same result regardless of message ordering, network delays, or processor speeds. This means monotonic programs can be parallelized with zero coordination overhead — the ultimate form of embarrassingly parallel computation.

For Πρόλογος, the CALM theorem provides the theoretical justification for automatic parallelization of propagator networks: since propagator merge is a monotonic lattice operation, propagator firings can be executed in any order on any processor, producing the same final result.

### 9.2 LVars: Lattice Variables for Determinism

LVars (Kuper and Newton, 2013) implement the CALM theorem as a programming model. An LVar is a variable whose value is drawn from a lattice and can only be updated by the lattice's join (least upper bound) operation. Multiple concurrent writes to an LVar are deterministic because join is commutative, associative, and idempotent.

LVars support two operations: `put` (update the LVar with a new value, which is joined with the current value) and `get` (block until the LVar's value reaches a specified threshold in the lattice). The threshold-get mechanism provides a limited form of reading that preserves determinism — a `get` returns only once the value is at or above the threshold, ensuring that the read is monotonic.

LVish (Kuper et al., 2014) extends LVars with additional lattice structures including counters (which can only increase), sets (which can only grow), and maps (which can only add entries). All of these are deterministic under concurrent access.

For Πρόλογος, cells in the propagator network are already LVars: they hold lattice values, updates use the lattice join, and propagators fire when cells reach thresholds. The connection is direct and provides deterministic parallelism by construction.

### 9.3 CRDTs: Conflict-Free Replicated Data Types

CRDTs (Shapiro et al., 2011) are data structures designed for concurrent and distributed environments that guarantee eventual consistency without coordination. **State-based CRDTs** (CvRDTs) merge concurrent states using a lattice join; **operation-based CRDTs** (CmRDTs) apply operations in any order with commutative semantics.

Common CRDTs include: G-Counter (grow-only counter), PN-Counter (positive-negative counter), G-Set (grow-only set), OR-Set (observed-remove set), LWW-Register (last-writer-wins register), and RGA (replicated growable array for ordered sequences).

CRDTs are the practical instantiation of the CALM theorem for data structures. For Πρόλογος, the persistent data structures with structural sharing (inspired by Clojure) can be implemented as CRDTs, enabling safe concurrent access from multiple actors without locks.

### 9.4 Bloom and CALM-Based Programming

Bloom (Alvaro et al., 2011) is a programming language that makes the CALM theorem practical. Programs are collections of monotonic rules (expressed in a Datalog-like syntax) that define how derived data grows over time. The Bud (Bloom Under Development) runtime automatically determines which computations can proceed without coordination and which require synchronization.

The CALM analysis in Bloom identifies **points of order**: places in the program where non-monotonic operations (negation, aggregation, or deletion) require coordination. Everything else can be freely parallelized and distributed.

For Πρόλογος, a CALM-aware compiler can perform a similar analysis: identify which propagator networks are fully monotonic (safe for unrestricted parallelism) and which contain non-monotonic operations requiring coordination points. The compiler can warn when a programmer introduces unnecessary coordination.

---

## 10. Parallel Logic Programming

### 10.1 OR-Parallelism: Aurora and Muse

OR-parallelism exploits the nondeterminism inherent in logic programming. When a goal matches multiple clause heads, each alternative represents an independent search branch that can be explored concurrently.

**Aurora** (Lusk et al., 1988) was one of the first practical OR-parallel Prolog systems. Aurora used the SRI model (Stack-Reuse with Incremental copying) to manage the shared environment: all processors share the part of the computation tree above the current choice point, while each processor has its own copy of the portion below its assigned branch. The Muse system (Ali and Karlsson, 1990) improved on Aurora with a more efficient copying strategy.

The key challenge in OR-parallelism is managing shared environments efficiently. When two processors explore sibling branches, they share variable bindings up to the choice point but need independent bindings below it. Aurora and Muse handle this through different copying strategies, each with tradeoffs between memory usage and synchronization overhead.

For Πρόλογος, OR-parallelism maps naturally to the actor model: each branch of a choice point spawns a new actor (or lightweight task) that explores that branch independently. The propagator network ensures that shared bindings are handled through lattice-based merge rather than copying.

### 10.2 AND-Parallelism: &-Prolog and Ciao

AND-parallelism executes multiple goals in the body of a clause concurrently, provided they do not share unbound variables (or their shared variables are properly managed).

**Independent AND-parallelism** (IAP) executes goals that share no unbound variables — their computations are truly independent. **Dependent AND-parallelism** (DAP) handles goals that share variables through synchronization mechanisms.

**&-Prolog** and its successor **Ciao** (Hermenegildo et al., 2012) implement both forms. Ciao's auto-parallelizer performs a **groundness analysis** — determining which variables are definitely bound at each program point — and a **sharing analysis** — determining which variables might share memory. Goals that the analysis proves independent are automatically parallelized.

For Πρόλογος, AND-parallelism corresponds to parallel evaluation of propagator inputs. When a propagator requires values from multiple cells, and those cells are updated by independent sub-networks, the sub-networks can execute in parallel. QTT multiplicities provide the independence analysis: 0-multiplicity arguments create no data dependencies, and ω-multiplicity arguments on immutable data can be safely shared.

### 10.3 Concurrent Logic Languages: PARLOG, GHC, KL1

Concurrent logic programming languages take a different approach: instead of adding parallelism to Prolog, they design new logic languages with concurrency as a primitive concept.

**PARLOG** (Clark and Gregory, 1986) uses mode declarations and commit operators to specify concurrent execution. **Guarded Horn Clauses (GHC)** (Ueda, 1986) add guard conditions that must be satisfied before a clause commits. **KL1** (Kernel Language 1), developed for Japan's Fifth Generation Computer Systems project, combined GHC with system-level features for distributed execution.

These languages use **committed choice nondeterminism**: when multiple clauses match, one is committed to and the others are discarded, providing a form of don't-care nondeterminism suited to concurrent execution.

For Πρόλογος, the guard mechanism of GHC is relevant: propagator activations can be guarded by conditions on their input cells, and commitment corresponds to the cell's lattice value advancing past a threshold.

### 10.4 Mercury's Auto-Parallelization of Logic Programs

Mercury's automatic parallelization (Bone et al., 2012) is the most sophisticated attempt to parallelize logic programs automatically. The approach works in three phases.

**Phase 1: Profiling.** Mercury's deep profiling system collects call counts, time per call, and context-switch costs for every procedure. This data is essential for estimating whether parallel execution will be profitable.

**Phase 2: Dependency Analysis.** Mercury's mode system classifies procedure arguments as input or output. Two conjuncts (goals in a clause body) are independent if the outputs of one are not inputs to the other. The auto-parallelizer builds a dependency graph of conjuncts and identifies maximal independent sets.

**Phase 3: Cost-Benefit Analysis.** For each pair of independent conjuncts, the auto-parallelizer estimates the parallel execution time (including fork/join overhead, typically 1-10µs) and compares it to sequential execution. Only conjunct pairs where the estimated parallel speedup exceeds a configurable threshold are parallelized.

Mercury's results are mixed but instructive: for programs with large independent sub-computations (tree traversals, divide-and-conquer), speedups of 5-7× on 8 cores are achieved. For fine-grained logic programs, the overhead of fork/join dominates.

### 10.5 Datalog Parallelization: Soufflé and Differential Dataflow

Datalog, a decidable fragment of Prolog (no function symbols), is inherently parallelizable because its bottom-up evaluation is monotonic — each iteration derives new facts that are added to the database, never removed.

**Soufflé** (Jordan et al., 2016) compiles Datalog to parallel C++, using BRIE (a specialized concurrent trie data structure) for relation storage, a parallel scheduler for rule evaluation, and efficient compilation of recursive rules to loop nests. Soufflé achieves near-linear scalability on multi-core machines for large static analysis benchmarks.

**Differential Dataflow** (McSherry et al., 2013) takes a different approach: it tracks the *changes* to each relation between iterations, enabling incremental recomputation. This is dramatically more efficient when most of the data is unchanged between iterations — a common case in iterative algorithms.

For Πρόλογος, Datalog evaluation can be implemented as a propagator network where each rule is a propagator and each relation is a cell containing a set of tuples (a lattice under set union). Soufflé's parallelization strategy then maps to parallel propagator scheduling.

---

## 11. Parallel Unification

### 11.1 The Unification Problem and Its Complexity

Unification is the fundamental operation in logic programming: given two terms, find a substitution (binding of variables to terms) that makes them syntactically equal, or determine that no such substitution exists.

First-order unification is decidable and has polynomial-time algorithms. Robinson's original algorithm (1965) has exponential worst case due to potential exponential growth of the most general unifier. Martelli and Montanari (1982) gave an O(n) algorithm using union-find (though the output unifier can be exponentially large). Paterson and Wegman (1978) gave an O(n) linear-time algorithm.

Higher-order unification (with lambda terms) is undecidable in general (Huet, 1973) but semi-decidable — Huet's algorithm enumerates possible unifiers. For dependently typed languages like Πρόλογος, the type checker performs higher-order unification during elaboration, typically using pattern unification (Miller, 1991) for decidable fragments and heuristic search for the general case.

### 11.2 Dwork, Kanellakis, and Mitchell: PRAM Parallel Unification

The landmark result in parallel unification is due to Dwork, Kanellakis, and Mitchell (1984): first-order unification can be performed in **O(log n)** time on a CRCW PRAM with **O(n²)** processors, where *n* is the size of the input terms.

The algorithm works in three stages. First, the two terms are represented as directed acyclic graphs (DAGs). Second, a parallel pointer-jumping algorithm computes equivalence classes of nodes that must be unified. Third, a parallel occur-check verifies that no variable is bound to a term containing itself (which would indicate a non-unifiable cyclic structure).

The pointer-jumping technique is key: starting from two nodes that must be unified, the algorithm follows pointers in parallel, halving the length of any chain in each step. After O(log n) steps, all chains have been compressed and all equivalence classes identified.

While the O(n²) processor requirement seems excessive, this is an asymptotic result — practical algorithms can use far fewer processors with sublinear speedup that is still significant for large terms.

### 11.3 Practical Parallel Unification Strategies

In practice, parallel unification can be approached at multiple granularities.

**Coarse-grained parallelism** parallelizes across unification problems rather than within them. In OR-parallel execution, each branch independently performs its own unification — these are naturally independent and can execute on separate processors. This is the dominant approach in Aurora and Muse.

**Medium-grained parallelism** parallelizes independent subproblems within a single unification. Given `f(X, Y) = f(g(a), h(b))`, the subproblems X = g(a) and Y = h(b) are independent and can proceed in parallel. The compiler can identify independent subproblems by analyzing the variable sharing structure.

**Fine-grained parallelism** implements the Dwork-Kanellakis-Mitchell algorithm or variants. This is rarely practical on current hardware due to the overhead of synchronization at the individual pointer operation level, but becomes relevant for GPU implementation where thousands of threads are available cheaply.

For Πρόλογος, medium-grained parallelism offers the best cost-benefit tradeoff: the type checker (at compile time) and the runtime unification engine (at runtime) can identify independent subproblems and parallelize them using the work-stealing scheduler.

### 11.4 Parallel Higher-Order Unification Considerations

Higher-order unification, needed for dependent type checking, presents additional challenges for parallelization. Since higher-order unification is undecidable in general, algorithms involve search (trying different substitutions), which introduces speculative parallelism.

Miller's pattern fragment (1991) restricts higher-order unification to cases where meta-variables are applied to distinct bound variables. This fragment is decidable and has a most general unifier, making it suitable for parallel execution — each pattern unification subproblem is independent.

For Πρόλογος, the strategy should be: (1) Use pattern unification for the common case, parallelizing independent subproblems. (2) For general higher-order unification, use OR-parallel search over candidate substitutions. (3) Apply timeout bounds to prevent runaway search in the undecidable general case.

### 11.5 Parallel Constraint Solving: SAT, SMT, and CLP

Constraint Logic Programming (CLP) extends logic programming with constraint domains (integers, reals, finite domains). Solving constraints is often the bottleneck in CLP, and parallel constraint solving has received significant attention.

**Parallel SAT solving** uses two main strategies. **Portfolio parallelism** runs multiple SAT solvers (or the same solver with different heuristics) on the same problem in parallel — the first to find a solution wins. **Divide-and-conquer (Cube-and-Conquer)** splits the search space into subproblems (cubes) that are solved independently.

**Parallel SMT solving** extends parallel SAT with theory solvers. The key challenge is sharing learned lemmas between parallel solver instances — lemmas derived by one instance can prune search for others, but sharing too aggressively introduces communication overhead.

For Πρόλογος, the propagator network provides a natural parallel constraint-solving framework: each constraint is a propagator, each variable is a cell, and propagator firings prune variable domains in parallel. The lattice-based merge ensures that concurrent pruning from multiple propagators is deterministic.

---

## 12. Propagator Networks as Parallel Execution Framework

### 12.1 Natural Parallelism in Propagator Networks

Radul and Sussman's propagator model (2009) is inherently parallel: propagators are autonomous computational agents that fire whenever their input cells change, independent of a global clock or program counter. Multiple propagators can fire simultaneously without violating correctness, provided that cell updates use a monotonic merge operation.

The key insight is that propagators communicate only through shared cells, and cells are updated only by merging (lattice join) the current value with the new contribution. Since lattice join is commutative, associative, and idempotent, the order in which propagator outputs are merged into a cell does not affect the final result.

This property makes propagator networks embarrassingly parallel in the CALM sense: any scheduling order, including fully concurrent execution of all fireable propagators, produces the same fixpoint. The Radul-Sussman scheduler serializes propagator firings for simplicity, but the model permits — and indeed invites — parallel scheduling.

### 12.2 The CALM-Propagator Connection

The connection between the CALM theorem and propagator networks is deep and precise. Propagator cell updates are monotonic (values only increase in the lattice ordering), and the final state of a propagator network is the least fixpoint of the collection of all propagator functions — this fixpoint is independent of the evaluation order.

This means that a propagator network meets the CALM criterion: it can be evaluated consistently (reaching the same fixpoint) without any coordination between processors. No locks, no barriers, no consensus protocol — just fire propagators whenever their inputs change, merge results into cells, and the system converges.

The only exception is when the propagator network includes non-monotonic operations (e.g., negation-as-failure, aggregation with min/max, or state mutation). These operations introduce coordination requirements — the CALM analysis identifies them as "points of order" where barriers or synchronization are needed.

### 12.3 Propagators as Unifying Parallel Runtime

The most powerful insight for Πρόλογος is that propagators can serve as a **unified parallel runtime** that subsumes actors, logic rules, constraints, and dataflow computations.

**Actors as propagators.** An actor with a mailbox is a propagator with an input cell (the mailbox, modeled as a monotonically growing queue). Message processing is a propagator firing. Inter-actor messages are cell updates. The actor's state is an output cell.

**Logic rules as propagators.** A Datalog rule `H :- B1, B2, ..., Bn` is a propagator that monitors the cells representing relations B1...Bn and adds derived tuples to the cell representing relation H. Bottom-up evaluation is propagator fixpoint computation.

**Constraints as propagators.** A constraint `X + Y = Z` with domain pruning is three propagators: one that prunes Z's domain based on X and Y, one that prunes Y's domain based on X and Z, and one that prunes X's domain based on Y and Z. Arc consistency propagation is propagator network fixpoint computation.

**Dataflow as propagators.** A dataflow node that computes f(a, b) is a propagator with input cells for a and b and an output cell for f(a, b). Dataflow graphs are directly propagator networks.

This unification means that Πρόλογος needs only one parallel scheduler — the propagator scheduler — to efficiently handle all forms of parallelism in the language.

**Fault tolerance and supervision.** When an actor crashes (e.g., due to an unhandled exception), its local propagator network must be handled. The strategy mirrors Erlang's supervision trees, mapped to propagator semantics: (1) Each actor's propagator network is a self-contained sub-network. When the actor terminates abnormally, all its local propagators and cells are invalidated. (2) The supervisor actor (itself a propagator monitoring child actor health cells) detects the failure when the child's health cell transitions to a "failed" state. (3) The supervisor's restart strategy creates a fresh actor with a fresh propagator network and re-connects the cross-actor cells (re-establishing the ORCA reference counts). (4) For dependent session types, the supervisor can verify that the restarted actor's session state is consistent with the protocol — if the session was mid-protocol, the supervisor can either restart from the beginning or resume from a checkpointed state. This approach keeps fault recovery within the propagator model rather than requiring a separate mechanism.

### 12.4 Mapping Actors, Logic Rules, and Constraints to Propagators

The mapping from high-level language constructs to propagator networks can be performed by the compiler:

**Function application:** Each function call creates a propagator that takes input cells (arguments) and produces output cells (results). Pure functions create stateless propagators; effectful functions create stateful propagators with additional cells for effects.

**Pattern matching:** Each match clause creates a propagator that tests whether the scrutinee matches its pattern and, if so, propagates bindings to the clause body. OR-parallelism over match clauses is natural: all clause propagators fire in parallel, and the first to succeed commits.

**Constraint solving:** Each constraint in a `where` clause creates propagators for forward and backward propagation. The constraint network reaches a fixpoint through parallel propagator firing.

**Actor communication:** `send` and `receive` operations create propagators that transfer values between actor mailbox cells. Session types govern the protocol, and the propagator network ensures messages are processed in order.

### 12.5 Scheduling Strategies for Propagator Networks

Several scheduling strategies have been proposed for propagator networks, each with different tradeoffs.

**Naive round-robin**: Fire each fireable propagator in turn. Simple but misses parallelism opportunities and can waste time on propagators whose inputs haven't changed.

**Priority scheduling**: Assign priorities to propagators based on their expected information gain. Propagators that prune more aggressively fire first. This is the standard approach in constraint propagation (AC-3, AC-4).

**Chaotic iteration**: Fire propagators in any order, possibly in parallel. Correct for monotonic propagators by the CALM theorem. This is the simplest parallel strategy and requires no synchronization.

**Work-stealing with affinity**: Each processor "owns" a subset of propagators (those accessing cells in its local memory). Processors first execute their own propagators, then steal from others. This exploits data locality, which is critical for NUMA architectures.

**Wavefront scheduling**: Identify levels in the propagator dependency graph — propagators at the same level can execute in parallel. Between levels, a lightweight barrier ensures all updates are visible. This combines the efficiency of chaotic iteration with the predictability of BSP.

For Πρόλογος, a hybrid work-stealing with affinity scheduler is recommended: propagators are initially assigned to processors based on cell locality, the scheduler uses work-stealing for load balancing, and the CALM property eliminates the need for barriers in monotonic sub-networks.

**NUMA-aware scheduling.** On NUMA (Non-Uniform Memory Access) architectures, memory access latency depends on which processor socket the data resides in. The propagator scheduler should be NUMA-aware through three mechanisms: (1) **Cell placement**: when a propagator network is constructed, cells are allocated in the local memory of the NUMA node where the primary propagator accessing that cell will run. (2) **Affinity-biased stealing**: when a processor steals work, it preferentially steals from processors on the same NUMA node, falling back to remote nodes only when local work is exhausted. (3) **Migration with data**: when a propagator is migrated to a different NUMA node (due to load balancing), the runtime considers migrating its hot cells as well if the access pattern is predominantly local. Chapel's locale model, which abstracts NUMA topology and allows explicit data placement through domain maps, provides the design template. The compiler should emit NUMA placement hints based on propagator network topology analysis — propagators connected through shared cells should be co-located on the same NUMA node when possible.

### 12.6 Lattice-Based Merge and Monotonic Computation

The lattice structure of propagator cells is the key enabler of parallel execution. A cell's value is drawn from a lattice (L, ⊑, ⊔), where ⊑ is the information ordering (more information = higher in the lattice) and ⊔ is the join operation (merge).

Standard lattices for Πρόλογος include:

**Type information lattice:** ⊥ (no information) → concrete type → ⊤ (contradiction/type error). Used in the type checker for unification.

**Numeric intervals:** [a, b] ⊑ [c, d] iff c ≤ a and b ≤ d. Used for numeric constraint propagation — intervals shrink as constraints are propagated.

**Domain lattice:** A ⊑ B iff A ⊆ B (reversed: smaller domains have more information). Used for finite domain constraint solving.

**Boolean lattice:** ⊥ → true/false → ⊤ (contradiction). Used for propositional constraint propagation.

**Term lattice:** Variables ⊑ partially instantiated terms ⊑ ground terms. Used for unification — each step binds a variable, increasing information.

The merge operation for each lattice is its join (⊔). When two propagators concurrently update the same cell with values v₁ and v₂, the cell's new value is v₁ ⊔ v₂ — the least upper bound, representing the combined information. Since join is commutative and associative, the order of updates doesn't matter.

---

## 13. LLVM Infrastructure for Parallelism

### 13.1 Automatic Vectorization: SLP and Loop Vectorizer

LLVM includes two automatic vectorization passes that Πρόλογος can leverage.

The **Loop Vectorizer** transforms scalar loops into vector operations. It handles loops with known trip counts (or trip counts expressible as affine functions), analyzes memory access patterns for conflicts, inserts predication for conditional execution, and supports multiple vector widths (SSE2/128-bit, AVX2/256-bit, AVX-512/512-bit, ARM NEON/128-bit, SVE/scalable).

The **SLP (Superword Level Parallelism) Vectorizer** identifies groups of independent scalar operations that can be combined into a single vector operation. Unlike the loop vectorizer, SLP works on straight-line code — it detects when multiple adjacent scalar operations perform the same operation on different data.

For Πρόλογος, the compiler should emit LLVM IR that maximizes vectorization opportunities: use arrays rather than linked lists for bulk data, ensure loop bounds are visible to the vectorizer, and use aligned memory allocation for posit arithmetic arrays.

### 13.2 Polly: The Polyhedral Optimizer for LLVM

Polly provides high-level loop transformations for LLVM IR. It detects Static Control Parts (SCoPs) — regions with affine loop bounds and array accesses — and applies transformations including loop tiling (for cache locality), loop interchange (for parallelism), loop fusion/fission (for reducing memory traffic), and automatic OpenMP parallel code generation.

Polly uses the Integer Set Library (isl) for polyhedral analysis and the PLUTO algorithm for scheduling. When a SCoP is detected, Polly computes the optimal tiling and parallelization strategy.

For Πρόλογος, Polly is most relevant for numerical kernels: matrix operations, stencil computations, and dense array operations using posit arithmetic. The Πρόλογος compiler should preserve loop structure in LLVM IR emission to maximize Polly's effectiveness.

### 13.3 OpenMP Lowering and the LLVM Runtime

LLVM supports OpenMP through the Clang frontend and a runtime library (libomp). OpenMP directives are lowered to LLVM IR that calls runtime functions for thread management, work distribution, and synchronization.

Key OpenMP constructs relevant to Πρόλογος: `#pragma omp parallel for` (parallel loop), `#pragma omp task` (fork a task), `#pragma omp taskwait` (join), `#pragma omp taskgroup` (structured task scope). Polly can automatically generate OpenMP annotations for parallelizable loops.

For Πρόλογος, the compiler can generate OpenMP-style parallel regions for embarrassingly parallel operations, leveraging LLVM's mature OpenMP runtime for thread management and work distribution. The propagator scheduler itself can be implemented atop the OpenMP task model.

### 13.4 MLIR Dialects: SCF, OMP, Async, and Beyond

MLIR (Multi-Level Intermediate Representation) extends LLVM with a framework for defining domain-specific IRs (dialects) that can be progressively lowered to LLVM IR.

Relevant MLIR dialects for Πρόλογος include:

**SCF (Structured Control Flow):** For/while loops with explicit parallelism annotations, lowered to parallel runtime calls.

**OMP dialect:** High-level representation of OpenMP constructs, lowered to LLVM's OpenMP runtime.

**Async dialect:** Async/await primitives with explicit task dependencies, lowered to coroutines or thread pool tasks.

**Linalg dialect:** High-level linear algebra operations, lowered to tiled, vectorized, and parallelized loops.

**Tensor and MemRef dialects:** Representations of multi-dimensional data with shape information, enabling optimizations like buffer allocation and layout transformation.

MLIR's progressive lowering model is particularly appealing for Πρόλογος: a high-level "Prologos dialect" can represent propagator networks, session-typed channels, and dependent types, then lower through intermediate dialects to efficient machine code.

### 13.5 LLVM Coroutines and Async/Await

LLVM supports coroutines through the `@llvm.coro.*` intrinsics. A coroutine is a function that can suspend execution and resume later, optionally on a different thread. Coroutines provide the mechanism for implementing async/await, generator functions, and cooperative multitasking.

LLVM's coroutine passes split a coroutine into multiple functions: a ramp function (initial setup), a resume function (continue after suspension), and a destroy function (cleanup). The coroutine frame (local variables that survive suspension) is allocated on the heap.

For Πρόλογος, LLVM coroutines provide the low-level mechanism for implementing lightweight actors and propagator suspensions. When a propagator is waiting for a cell update, it can suspend as a coroutine and resume when the cell value changes — this is more efficient than allocating a full thread per propagator.

---

## 14. Modern Parallel Language Designs

### 14.1 Chapel: Multiresolution Parallelism

Chapel (Chamberlain et al., 2007), developed at Cray/HPE, provides a "multiresolution" approach to parallelism. Programmers can express parallelism at multiple levels of abstraction: high-level data parallelism (forall loops, distributed arrays, reductions), task parallelism (begin, cobegin, coforall), and locale-based placement (on clauses that control data placement across NUMA domains or nodes).

Chapel's key innovations include: **domain maps** that describe how arrays are distributed across locales (block, cyclic, replicated, custom), **forall loops** with customizable parallel iterators, **locale** model for NUMA-aware and distributed execution, and **promotion** (automatic parallelization of scalar functions applied to arrays).

For Πρόλογος, Chapel demonstrates that a single language can span from shared-memory parallelism to distributed computing. Chapel's domain maps inspire the idea of "propagator maps" that control how propagator networks are distributed across processors.

### 14.2 Futhark: Purely Functional GPU Programming

Futhark (Henriksen et al., 2017) is a purely functional array language that compiles to efficient GPU (CUDA/OpenCL) and multi-core CPU code. Futhark's design philosophy is that programmers express computation using familiar functional combinators (map, reduce, scan, scatter, histogram), and the compiler handles the complex transformation to GPU kernels.

Futhark's key optimizations include: aggressive **fusion** (combining adjacent maps and reductions into single kernels), **moderate flattening** (transforming nested parallelism into flat parallelism suitable for GPUs), **memory reuse** (detecting when intermediate arrays can share memory), and **size types** (tracking array dimensions for shape-safe programs).

For Πρόλογος, Futhark demonstrates that dependent types (size types) enable significantly better parallel code generation. Πρόλογος's full dependent types can express even richer invariants, enabling the compiler to generate more aggressively optimized parallel code.

### 14.3 Julia's Parallel Model: Tasks, Channels, and Distributed

Julia provides multi-level parallelism: `@threads` for shared-memory thread parallelism, `@spawn`/`fetch` for task-based parallelism with work-stealing, channels for inter-task communication, and `Distributed` module for multi-process and multi-node execution.

Julia's most innovative parallel feature is **task migration**: a task that is blocked on I/O can be suspended and its continuation migrated to another processor, enabling M:N threading (many tasks mapped to few OS threads). Julia 1.9+ achieves scalable parallelism with millions of tasks scheduled across available cores.

### 14.4 Haskell's Parallel Strategies and Par Monad

Haskell offers two complementary approaches to deterministic parallelism.

**Parallel strategies** (Marlow et al., 2010) separate algorithm from parallelism annotations. The `using` combinator applies a strategy to a value:

```haskell
parMap f xs = map f xs `using` parList rdeepseq
```

This evaluates each element of the mapped list in parallel (sparked by `par`) to full normal form (forced by `rdeepseq`). The strategy annotations do not change the program's meaning — they only affect evaluation order.

The **Par monad** (Marlow et al., 2011) provides a more structured approach: `fork` spawns a computation, `new`/`put`/`get` create and manipulate IVars (write-once variables). The Par monad guarantees determinism — the result is independent of scheduling.

IVars in the Par monad are essentially single-write LVars (a lattice with ⊥ and one non-⊥ value), connecting Haskell's deterministic parallelism to the LVar framework and, ultimately, to propagator networks.

### 14.5 Rust's Rayon and Fearless Concurrency

Rust's Rayon library provides data parallelism through parallel iterators. Converting sequential code to parallel requires minimal changes:

```rust
// Sequential
let sum: i64 = data.iter().map(|x| x * x).sum();
// Parallel
let sum: i64 = data.par_iter().map(|x| x * x).sum();
```

Rayon uses work-stealing to schedule parallel iterator operations. The key enabler is Rust's ownership system: the borrow checker statically prevents data races, making parallel iterators safe without runtime checks.

For Πρόλογος, Rayon demonstrates that a strong static type system (ownership/linearity) enables seamless transition between sequential and parallel code. Πρόλογος's QTT system provides an even more expressive framework for the same guarantee.

---

## 15. Lock-Free and Wait-Free Data Structures

### 15.1 Michael-Scott Queue and Harris Linked List

Lock-free data structures guarantee that at least one thread makes progress in a finite number of steps, even if other threads are suspended. Wait-free structures guarantee that every thread makes progress.

The **Michael-Scott queue** (1996) is the canonical lock-free FIFO queue, using compare-and-swap (CAS) on head and tail pointers. The **Harris linked list** (2001) provides lock-free insertion and deletion using CAS with logical deletion (marking a node as deleted before physically removing it).

For Πρόλογος, lock-free queues are essential for actor mailboxes and propagator scheduling deques. The work-stealing scheduler's deque (chase-lev deque) is a lock-free structure that supports push/pop by the owner and steal by thieves.

### 15.2 Epoch-Based Reclamation and Hazard Pointers

Lock-free data structures face a memory reclamation problem: when a node is logically deleted, other threads might still hold references to it. Two solutions dominate.

**Epoch-based reclamation (EBR)** (Fraser, 2004) divides time into epochs. Threads announce when they enter a critical section; nodes deleted in epoch *e* can only be freed when all threads have passed through epoch *e+1*. Crossbeam (Rust) implements EBR.

**Hazard pointers** (Michael, 2004) require each thread to publish the pointers it is currently accessing. A node can only be freed when no thread's hazard pointer references it.

For Πρόλογος, the per-actor heap model (from the GC architecture) reduces the need for cross-actor reclamation, but actor-local lock-free structures (e.g., the propagator scheduling queue within an actor) still need reclamation. EBR, integrated with the per-actor GC cycle, is the recommended approach.

### 15.3 Persistent Data Structures for Concurrent Access

Persistent (immutable) data structures — inspired by Clojure's designs — sidestep the entire reclamation problem: since old versions are never mutated, they can be safely accessed by any thread at any time. Structural sharing means that creating a new version (with one element added or removed) shares most of its memory with the old version.

Bagwell's Hash Array Mapped Tries (HAMTs), used in Clojure's persistent maps and vectors, provide O(log₃₂ n) access and update with excellent cache behavior. Persistent vectors using Relaxed Radix Balanced Trees (RRB-Trees) provide efficient concatenation.

For Πρόλογος (which explicitly lists immutable data structures with structural sharing as a desideratum), persistent data structures are the default. They integrate naturally with the propagator model: a cell's value can be a persistent data structure, and monotonic merge can be implemented as persistent set union or persistent map merge.

---

## 16. Considerations for Πρόλογος Implementors

### 16.1 Unified Architecture: Propagators as the Parallel Runtime

The central architectural recommendation for Πρόλογος is to use the propagator network as the **unified parallel runtime**. Rather than having separate mechanisms for actor scheduling, constraint propagation, logic programming search, and data-parallel operations, all of these reduce to propagator network execution.

The architecture consists of three layers:

**Layer 1: The Propagator Network Core.** Cells hold lattice values. Propagators are functions from input cells to output cell updates. The scheduler fires propagators when input cells change.

**Layer 2: The Parallel Scheduler.** A work-stealing scheduler distributes propagator firings across available cores. Each core has a local deque of fireable propagators. Idle cores steal from busy cores. The CALM property ensures that unsynchronized parallel execution is correct for monotonic sub-networks.

**Layer 3: Domain-Specific Interfaces.** Actors, channels, constraints, and data-parallel operations are thin wrappers that create appropriate propagators and cells. The programmer sees high-level abstractions; the runtime sees only propagators.

```
;; All of these compile to propagator networks:

;; Actor communication
(send actor-b (process-chunk data))

;; Constraint propagation
(where (> x 0) (< x 100) (= y (* x x)))

;; Data-parallel map
(par/map (fn (x) (* x x)) data)

;; Logic programming search
(query (parent ?x ?y) (parent ?y ?z) (=> (grandparent ?x ?z)))
```

### 16.2 Session-Typed Channels for Communication

All inter-actor and inter-task communication in Πρόλογος should use session-typed channels. Session types provide three guarantees essential for correct parallelism: **protocol compliance** (messages are sent and received in the specified order), **linearity** (each channel endpoint is owned by exactly one actor, preventing races), and **deadlock freedom** (for binary sessions, guaranteed by duality; for multiparty sessions, by global type well-formedness).

The implementation maps session channels to propagator cells:

```
;; Define a session type for parallel map-reduce coordination
(session-type MapReduceWorker
  (? (Vec Chunk))           ;; receive work chunks
  (! (Vec Result))           ;; send results
  end)

;; The coordinator's view (dual type)
(session-type MapReduceCoordinator
  (! (Vec Chunk))            ;; send work chunks
  (? (Vec Result))           ;; receive results
  end)

;; Spawn parallel workers with session-typed channels
(def parallel-map-reduce
  (fn (f data num-workers)
    (let (chunks (partition num-workers data))
      (par/for-each chunks
        (fn (chunk ch : (Chan MapReduceWorker))
          (let (result (map f chunk))
            (send ch result)))))))
```

### 16.3 QTT-Guided Automatic Parallelization Strategy

QTT multiplicities provide the compiler with the information needed for automatic parallelization. The strategy is a three-level analysis:

**Level 1: Purity Analysis.** A function is **pure** if it captures only 0-multiplicity (erased) and ω-multiplicity (freely shared) bindings. Pure functions can be safely parallelized without restriction. The compiler marks all pure functions in a purity analysis pass.

**Level 2: Independence Analysis.** Two expressions are **independent** if they share no 1-multiplicity bindings. Independent expressions can execute in parallel. The compiler builds an independence graph where nodes are expressions and edges represent shared linear bindings.

**Level 3: Profitability Analysis.** Using dependent type information (array sizes, recursion depth bounds), the compiler estimates the cost of each expression. Expressions below a granularity threshold are not parallelized (the overhead would exceed the benefit).

```
;; The compiler analyzes this and automatically parallelizes:
(let
  (a (expensive-pure-fn x))     ;; pure, expensive → parallelize
  (b (expensive-pure-fn y))     ;; pure, expensive, independent of a → parallelize
  (c (combine a b)))            ;; depends on a, b → sequential after join

;; Equivalent to:
(let
  (a-future (par/spawn (fn () (expensive-pure-fn x))))
  (b-future (par/spawn (fn () (expensive-pure-fn y))))
  (c (combine (par/join a-future) (par/join b-future))))
```

### 16.4 Parallel Unification in the Type Checker and Runtime

Πρόλογος requires unification in two contexts: the type checker (at compile time) and the runtime logic engine (at runtime).

**Compile-time parallel unification.** The type checker performs higher-order unification during elaboration. The recommended approach: (1) decompose unification problems into independent subproblems using the term structure, (2) parallelize independent subproblems using the compiler's thread pool, (3) for the pattern fragment (Miller, 1991), use a parallel pattern unification algorithm, (4) for general higher-order unification, use OR-parallel search with speculative execution and backtracking.

**Runtime parallel unification.** Logic programming queries at runtime perform first-order unification. The recommended approach: (1) use medium-grained parallelism — parallelize independent argument unifications within a single term, (2) for OR-parallel search over multiple matching clauses, spawn lightweight tasks (as propagators) for each branch, (3) use the propagator lattice for binding representation: a variable cell starts at ⊥ and is refined to a ground term through propagation.

```
;; Parallel unification as propagator network
;; unify f(X, Y, Z) = f(a, g(b), h(c, d))
;; Three independent subproblems: X=a, Y=g(b), Z=h(c,d)

;; Compiled propagator network:
;; cell-X : Term (initially ⊥)
;; cell-Y : Term (initially ⊥)
;; cell-Z : Term (initially ⊥)
;; propagator-1: cell-X ← merge(cell-X, a)        ;; fires independently
;; propagator-2: cell-Y ← merge(cell-Y, g(b))      ;; fires independently
;; propagator-3: cell-Z ← merge(cell-Z, h(c, d))   ;; fires independently
;; All three fire in parallel; result is the composed substitution
```

### 16.5 CALM-Aware Compiler: Detecting Monotonic Computations

The Πρόλογος compiler should perform a **CALM analysis** pass that classifies computations as monotonic or non-monotonic.

**Monotonic operations** (safe for coordination-free parallelism): set union, lattice join, constraint propagation (domain narrowing), positive Datalog evaluation (no negation), propagator merge, persistent data structure growth (adding elements).

**Non-monotonic operations** (require coordination): negation-as-failure, aggregation with min/max/count, deletion, mutation, I/O, inter-actor communication (message ordering).

The compiler emits parallel code for monotonic regions without synchronization primitives. At boundaries between monotonic and non-monotonic regions (points of order), the compiler inserts barrier or synchronization instructions.

```
;; CALM analysis example:
(def process-data (data)
  ;; MONOTONIC REGION — auto-parallelized, no synchronization
  (let
    (filtered (filter positive? data))        ;; monotonic: subset
    (mapped (map (fn (x) (* x x)) filtered)) ;; monotonic: element-wise
    (accumulated (fold/union #{} mapped))     ;; monotonic: set union

    ;; POINT OF ORDER — requires synchronization
    (count (length accumulated))              ;; non-monotonic: counting

    ;; SEQUENTIAL AFTER BARRIER
    (io/print (str "Processed " count " items"))))
```

### 16.6 Embarrassingly Parallel by Default: The Design Philosophy

The NOTES.org desideratum is clear: *"anything that is 'embarrassingly' parallel, and that would benefit from being so without extra overhead costs, should be so automatically."*

The concrete implementation strategy:

**1. Parallel collections.** All standard collection operations (map, filter, reduce, for-each) automatically use parallel execution when: (a) the mapping/filtering function is pure (determined by QTT analysis), (b) the collection size exceeds a runtime-configurable threshold (default: 1024 elements), and (c) the estimated per-element cost exceeds the scheduling overhead (determined by static analysis or adaptive profiling).

**2. Parallel comprehensions.** List/set/map comprehensions that iterate over independent elements automatically parallelize:

```
;; Automatically parallelized comprehension
(def results
  (for (x data)
       (when (> x 0))
    (expensive-compute x)))
```

**3. Parallel recursion.** Recursive functions where recursive calls are independent (determined by the independence analysis) automatically use fork-join:

```
;; Automatically parallelized divide-and-conquer
(def merge-sort
  (fn (xs)
    (if (<= (length xs) 1)
      xs
      (let
        (mid (div (length xs) 2))
        (left (take mid xs))
        (right (drop mid xs))
        ;; Compiler detects: left and right are independent pure calls
        ;; Automatically inserts par/spawn and par/join
        (merge (merge-sort left) (merge-sort right))))))
```

**4. Parallel propagator networks.** All constraint solving, logic programming queries, and dataflow computations are automatically parallel — this is inherent in the propagator model.

### 16.7 Structured Concurrency with Dependent Types

Πρόλογος's structured concurrency builds on the nursery/task-group pattern, enhanced with dependent types for static guarantees.

```
;; Structured concurrency with dependent type for result collection
(def parallel-fetch
  (forall (n : Nat)
    (-> (Vec n URL) (IO (Vec n Response))))
  (fn (urls)
    ;; Task group: all tasks complete before scope exits
    (task-group
      (fn (group)
        ;; Spawn one task per URL — the Vec n guarantees n results
        (vec/par-map
          (fn (url)
            (task/spawn group (fn () (http/get url))))
          urls)))))

;; The dependent type (Vec n URL) → (Vec n Response) guarantees
;; that every URL produces exactly one response — no lost tasks
```

The type system enforces that task groups are properly scoped: the result type depends on the task group's scope, ensuring that no reference to a task or its result escapes the group.

### 16.8 Integration with Pony-Style Actor GC

The parallel runtime must integrate tightly with the GC architecture described in RESEARCH_GC.md. Key integration points:

**Per-actor propagator networks.** Each actor owns a local propagator network. Propagator cells within an actor are managed by the actor's local GC (Tier 1 deterministic or Tier 2 generational). Cross-actor cells use the ORCA protocol (Tier 3).

**GC-aware scheduling.** The work-stealing scheduler must coordinate with GC pauses. Since Πρόλογος uses per-actor GC (no global stop-the-world), an actor can GC while other actors continue executing. The scheduler treats GC as a high-priority local task.

**Linear values and parallelism.** 1-multiplicity values transfer between actors without copying (move semantics). This is both efficient (no allocation) and GC-friendly (no cross-actor references for linear values, so no ORCA messages needed).

**Immutable values and sharing.** ω-multiplicity immutable values (persistent data structures with structural sharing) can be shared freely between actors. The ORCA protocol tracks reference counts for these shared values; structural sharing minimizes the reference count overhead.

### 16.9 LLVM Backend: Leveraging Vectorization and Polly

The Πρόλογος compiler should emit LLVM IR that maximizes the effectiveness of LLVM's parallelism infrastructure:

**Vectorization.** For posit arithmetic array operations, emit loops with affine bounds and aligned memory access patterns. Use LLVM's `@llvm.vector.reduce.*` intrinsics for reductions. Add `!llvm.access.group` metadata to communicate independence to the vectorizer.

**Polly integration.** For numerical kernels (matrix multiplication, stencil computations), emit LLVM IR in SCoP form — loops with affine bounds and array accesses with affine index expressions. Polly will automatically tile for cache locality and parallelize across cores.

**OpenMP integration.** For explicitly parallel regions, emit calls to LLVM's OpenMP runtime (`__kmpc_fork_call`, `__kmpc_for_static_init`, etc.). The propagator scheduler's work-stealing can use OpenMP's task model.

**Coroutines.** For lightweight actor/propagator suspension, use LLVM's coroutine intrinsics to implement cooperative scheduling without the overhead of full thread context switches.

**MLIR pathway.** For a future production compiler, consider emitting MLIR (rather than LLVM IR directly) to enable progressive lowering through domain-specific dialects. A "Prologos dialect" for propagator networks could enable propagator-specific optimizations before lowering to parallel loops and LLVM IR.

**GPU compilation for posit arithmetic kernels.** For data-parallel posit arithmetic operations on large arrays, the compiler should target GPU execution. The strategy follows Futhark's approach, adapted for Πρόλογος: (1) The compiler identifies **GPU-eligible regions**: data-parallel operations (map, reduce, scan, stencil) over posit arrays that exceed a size threshold and use only GPU-compatible operations (no recursion, no allocation, no I/O). (2) For GPU-eligible regions, the compiler generates kernels targeting LLVM's NVPTX (NVIDIA) or AMDGPU backends. Since posit arithmetic is not natively supported on current GPUs, posit operations are compiled to software-emulated posit arithmetic using integer operations on the GPU — this is still faster than CPU execution for large arrays because GPUs have thousands of cores. (3) The host code manages data transfer: posit arrays are transferred to GPU memory before the kernel launch and results are transferred back after completion. The dependent type system enables the compiler to compute exact buffer sizes at compile time (from the array size type parameter), eliminating runtime size calculations. (4) For mixed CPU-GPU workloads, the scheduler can use a heuristic: small arrays (< 10K elements) use CPU SIMD vectorization; medium arrays (10K–1M) use CPU multi-core with Polly; large arrays (> 1M) offload to GPU. These thresholds are runtime-configurable and can be auto-tuned through profiling. (5) Future posit hardware accelerators (if they materialize from projects like the Posit Working Group's initiatives) can be targeted through custom LLVM backend passes.

### 16.10 Concrete Syntax Sketches for Parallelism in Πρόλογος

The following syntax sketches illustrate how parallelism surfaces in Πρόλογος, following the design principles from NOTES.org (homoiconic prefix notation, `()` groupings, significant whitespace):

```
;; === Parallel map (automatic for pure functions) ===
(def squares (map (fn (x) (* x x)) data))
;; Compiler auto-parallelizes: map with pure fn on large collection

;; === Explicit parallel spawn/join ===
(par/let
  (a (fetch-url url1))
  (b (fetch-url url2))
  (c (fetch-url url3))
  ;; a, b, c computed in parallel; all joined before body
  (combine a b c))

;; === Parallel for-each with session-typed coordination ===
(par/for-each workers
  (fn (worker ch : (Chan WorkerProtocol))
    (send ch (assign-task (next-task)))
    (let (result (recv ch))
      (accumulate results result))))

;; === Constraint solving (inherently parallel via propagators) ===
(solve
  (where
    (: x Int) (: y Int) (: z Int)
    (> x 0) (> y 0) (> z 0)
    (= (+ (* x x) (* y y)) (* z z))
    (< z 100))
  ;; Constraint propagators fire in parallel

;; === Logic query (OR-parallel search) ===
(query
  (parent ?x ?y)
  (parent ?y ?z)
  (grandparent ?x ?z))
;; Each matching clause explored in parallel

;; === Structured concurrency with task groups ===
(task-group (fn (group)
  (for (url urls)
    (task/spawn group
      (fn () (http/get url))))
  ;; All spawned tasks join at task-group boundary
  ))

;; === Pipeline parallelism ===
(pipe data
  (par/filter positive?)
  (par/map expensive-transform)
  (par/reduce + 0))

;; === Algebraic effect for concurrency ===
(effect Concurrent
  (op fork : (-> (-> Unit) Task))
  (op yield : (-> Unit))
  (op await : (-> Task a a)))

;; === CALM-monotonic annotation for guaranteed deterministic parallelism ===
(monotonic
  (fold/union #{} (map derive-facts database)))
;; The 'monotonic' annotation asserts CALM compliance;
;; compiler verifies and parallelizes without coordination
```

### 16.11 Compiler Error Messages for Concurrency Violations

Following the NOTES.org desideratum for excellent compiler errors, Πρόλογος should provide clear, actionable error messages for concurrency-related issues:

```
error[E0301]: Cannot auto-parallelize: function captures mutable binding
  ┌─ src/analytics.prologos:42:5
  │
40 │   (let (counter 0)
  │         ─────── ω-multiplicity mutable binding
41 │     (for-each data
42 │       (fn (x) (set! counter (+ counter 1))))
  │                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ mutation of shared binding
  │
  = help: `for-each` with pure function auto-parallelizes, but `counter`
          is mutated in the loop body
  = hint: use `fold` instead:
          (fold (fn (count x) (+ count 1)) 0 data)
  = hint: or use an atomic accumulator:
          (let (counter (atomic/new 0))
            (par/for-each data
              (fn (x) (atomic/inc! counter))))
```

```
error[E0302]: Session type violation in parallel context
  ┌─ src/protocol.prologos:28:3
  │
25 │ (def handle-request
26 │   (fn (ch : 1 (Chan RequestProtocol))
  │              ─ linear channel (must be used exactly once)
27 │     (par/let
28 │       (a (send ch (compute-a)))
  │            ^^ first use of linear channel
29 │       (b (send ch (compute-b)))
  │            ^^ ERROR: second use of linear channel
  │
  = help: linear channel `ch` cannot be used in multiple parallel branches
  = hint: use sequential sends, or split the protocol into independent channels:
          (let
            (ch-a ch-b (session/split ch))
            (par/let
              (a (send ch-a (compute-a)))
              (b (send ch-b (compute-b)))
              ...))
```

```
error[E0303]: Non-monotonic operation in `monotonic` block
  ┌─ src/analysis.prologos:15:5
  │
13 │ (monotonic
14 │   (let (facts (fold/union #{} derived))
15 │     (if (> (count facts) 100)
  │         ^^^^^^^^^^^^^^^^^ `count` is non-monotonic (aggregation)
16 │       (take 100 facts)
  │        ^^^^ `take` is non-monotonic (truncation)
17 │       facts)))
  │
  = help: the `monotonic` annotation guarantees CALM-safe deterministic
          parallelism, but this block contains non-monotonic operations
  = hint: remove the `monotonic` annotation and use explicit synchronization,
          or restructure to avoid counting:
          (fold/union #{} derived)  ;; monotonic: just collect all facts
```

### 16.12 Phased Implementation Plan

**Phase 1 (Months 1–4): Foundation**
- Implement the propagator network core (cells, propagators, lattice merge)
- Single-threaded scheduler with correct fixpoint computation
- Basic session-typed channels (binary, without dependent indexing)
- QTT purity analysis pass in the compiler
- Test with simple constraint-solving examples

**Phase 2 (Months 5–8): Parallel Scheduler**
- Implement work-stealing scheduler for propagator firings
- Per-actor propagator networks with actor-local scheduling
- Parallel collections (par/map, par/filter, par/reduce) backed by propagators
- Auto-parallelization of pure maps and independent let bindings
- LLVM backend emitting vectorizable loops for array operations
- Benchmark against sequential execution on standard parallel benchmarks

**Phase 3 (Months 9–12): Advanced Parallelism**
- OR-parallel logic programming (parallel clause search)
- Parallel unification (medium-grained, independent subproblems)
- CALM analysis pass: classify propagator networks as monotonic/non-monotonic
- Structured concurrency (task groups) with dependent type scoping
- ORCA protocol integration for cross-actor propagator cells
- Polly integration for numerical kernels

**Phase 4 (Months 13–18): Optimization and Scale**
- Adaptive granularity control (profiling-based cost model)
- MLIR integration: Prologos dialect with progressive lowering
- Multiparty session types for complex parallel coordination
- Dependent session types indexed by runtime values
- GPU backend for data-parallel posit arithmetic
- Distributed propagator networks across multiple nodes
- Comprehensive benchmarking and performance tuning

---

## 17. References and Further Reading

**Parallel Computing Foundations:**
- Flynn, M. J. (1966). "Very high-speed computing systems." *Proceedings of the IEEE*.
- Amdahl, G. M. (1967). "Validity of the single processor approach to achieving large scale computing capabilities." *AFIPS Conference Proceedings*.
- Gustafson, J. L. (1988). "Reevaluating Amdahl's Law." *Communications of the ACM*.
- Brent, R. P. (1974). "The parallel evaluation of general arithmetic expressions." *JACM*.
- Valiant, L. G. (1990). "A bridging model for parallel computation." *Communications of the ACM*.
- Culler, D. E. et al. (1993). "LogP: Towards a realistic model of parallel computation." *PPOPP*.

**Work-Stealing and Scheduling:**
- Blumofe, R. D. and Leiserson, C. E. (1999). "Scheduling multithreaded computations by work stealing." *JACM*.
- Frigo, M., Leiserson, C. E., and Randall, K. H. (1998). "The implementation of the Cilk-5 multithreaded language." *PLDI*.
- Chase, D. and Lev, Y. (2005). "Dynamic circular work-stealing deque." *SPAA*.

**Automatic Parallelization:**
- Bondhugula, U. et al. (2008). "A practical automatic polyhedral parallelizer and locality optimizer." *PLDI*.
- Grosser, T. et al. (2012). "Polly — performing polyhedral optimizations on a low-level intermediate representation." *Parallel Processing Letters*.
- Coutts, D., Leshchinskiy, R., and Stewart, D. (2007). "Stream fusion: From lists to streams to nothing at all." *ICFP*.
- Wadler, P. (1988). "Deforestation: Transforming programs to eliminate trees." *ESOP*.

**Session Types and Concurrency:**
- Honda, K. (1993). "Types for dyadic interaction." *CONCUR*.
- Honda, K., Vasconcelos, V. T., and Kubo, M. (1998). "Language primitives and type discipline for structured communication-based programming." *ESOP*.
- Honda, K., Yoshida, N., and Carbone, M. (2008). "Multiparty asynchronous session types." *POPL*.
- Caires, L. and Pfenning, F. (2010). "Session types as intuitionistic linear propositions." *CONCUR*.
- Toninho, B., Caires, L., and Pfenning, F. (2011). "Dependent session types via intuitionistic linear type theory." *PPDP*.

**Algebraic Effects:**
- Plotkin, G. D. and Power, J. (2003). "Algebraic operations and generic effects." *Applied Categorical Structures*.
- Plotkin, G. D. and Pretnar, M. (2009). "Handlers of algebraic effects." *ESOP*.

**Process Calculi:**
- Milner, R., Parrow, J., and Walker, D. (1992). "A calculus of mobile processes." *Information and Computation*.
- Reppy, J. H. (1991). "CML: A higher-order concurrent language." *PLDI*.
- Fournet, C. and Gonthier, G. (1996). "The reflexive CHAM and the join-calculus." *POPL*.
- Hoare, C. A. R. (1978). "Communicating sequential processes." *Communications of the ACM*.

**CALM, LVars, and Deterministic Parallelism:**
- Hellerstein, J. M. (2010). "The declarative imperative: Experiences and conjectures in distributed logic." *SIGMOD Record*.
- Ameloot, T. J. et al. (2011). "Relational transducers for declarative networking." *PODS*.
- Kuper, L. and Newton, R. R. (2013). "LVars: Lattice-based data structures for deterministic parallelism." *FHPC*.
- Shapiro, M. et al. (2011). "Conflict-free replicated data types." *SSS*.
- Alvaro, P. et al. (2011). "Consistency analysis in Bloom: A CALM and collected approach." *CIDR*.

**Parallel Logic Programming:**
- Lusk, E. et al. (1988). "The Aurora or-parallel Prolog system." *New Generation Computing*.
- Ali, K. and Karlsson, R. (1990). "The Muse approach to OR-parallel Prolog." *IJPP*.
- Hermenegildo, M. V. et al. (2012). "An overview of Ciao and its design philosophy." *TPLP*.
- Bone, P. et al. (2012). "Automatic parallelization of Mercury programs." *PPDP*.

**Parallel Unification:**
- Dwork, C., Kanellakis, P. C., and Mitchell, J. C. (1984). "On the sequential nature of unification." *JLP*.
- Robinson, J. A. (1965). "A machine-oriented logic based on the resolution principle." *JACM*.
- Martelli, A. and Montanari, U. (1982). "An efficient unification algorithm." *TOPLAS*.
- Miller, D. (1991). "A logic programming language with lambda-abstraction, function variables, and simple unification." *JLP*.

**Propagator Networks:**
- Radul, A. and Sussman, G. J. (2009). "The Art of the Propagator." *MIT CSAIL Technical Report*.

**Datalog Parallelization:**
- Jordan, H. et al. (2016). "Soufflé: On synthesis of program analyzers." *CAV*.
- McSherry, F. et al. (2013). "Differential dataflow." *CIDR*.

**Modern Parallel Languages:**
- Chamberlain, B. L. et al. (2007). "Parallel programmability and the Chapel language." *IJHPCA*.
- Henriksen, T. et al. (2017). "Futhark: Purely functional GPU programming with nested parallelism and in-place array updates." *PLDI*.
- Marlow, S. et al. (2010). "Seq no more: Better strategies for parallel Haskell." *Haskell Symposium*.
- Marlow, S., Newton, R., and Peyton Jones, S. (2011). "A monad for deterministic parallelism." *Haskell Symposium*.

**Lock-Free Data Structures:**
- Michael, M. M. and Scott, M. L. (1996). "Simple, fast, and practical non-blocking and blocking concurrent queue algorithms." *PODC*.
- Harris, T. L. (2001). "A pragmatic implementation of non-blocking linked-lists." *DISC*.
- Fraser, K. (2004). "Practical lock-freedom." *PhD thesis, University of Cambridge*.

**STM and Transactional Memory:**
- Harris, T. et al. (2005). "Composable memory transactions." *PPoPP*.
- Shavit, N. and Touitou, D. (1995). "Software transactional memory." *PODC*.

**Structured Concurrency:**
- Sústrik, M. (2016). "Structured concurrency." Blog post.
- Smith, N. J. (2018). "Notes on structured concurrency, or: Go statement considered harmful." Blog post.

---

*This report was prepared as part of the Πρόλογος language design research series. It should be read alongside the companion reports on Dependent Type Theory, Propagator Networks, Garbage Collection Innovations, Unum Innovations, and the Implementation Guidance document.*
