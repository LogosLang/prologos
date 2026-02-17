# Implementation Guide: Core Data Structures for Πρόλογος

## A Layered, Seq-Centric Architecture for Persistent Collections in a Dependently-Typed Functional-Logic Language

---

## Table of Contents

1. [Introduction and Scope](#1-introduction-and-scope)
2. [Architectural Principles](#2-architectural-principles)
   - 2.1 [The Four-Layer Abstraction Model](#21-the-four-layer-abstraction-model)
   - 2.2 [Persistence, Structural Sharing, and the Immutability Invariant](#22-persistence-structural-sharing-and-the-immutability-invariant)
   - 2.3 [QTT Multiplicities and Memory Strategy](#23-qtt-multiplicities-and-memory-strategy)
   - 2.4 [Lattice Compatibility for Propagators](#24-lattice-compatibility-for-propagators)
   - 2.5 [Seq as the Architectural Hub](#25-seq-as-the-architectural-hub)
3. [Prerequisite Infrastructure](#3-prerequisite-infrastructure)
   - 3.1 [Core Representation Requirements](#31-core-representation-requirements)
   - 3.2 [Hash Function Architecture](#32-hash-function-architecture)
   - 3.3 [Comparison and Ordering Traits](#33-comparison-and-ordering-traits)
   - 3.4 [Racket GC Integration](#34-racket-gc-integration)
   - 3.5 [Trait System Foundation](#35-trait-system-foundation)
4. [Layer 1: User-Facing Collection Types](#4-layer-1-user-facing-collection-types)
   - 4.1 [Vec — Indexed Persistent Vectors (`@[...]`)](#41-vec--indexed-persistent-vectors-)
   - 4.2 [Map — Persistent Hash Maps (`{...}`)](#42-map--persistent-hash-maps-)
   - 4.3 [Set — Persistent Hash Sets (`#{...}`)](#43-set--persistent-hash-sets-)
   - 4.4 [List — Immutable Cons Lists (`'[...]`)](#44-list--immutable-cons-lists-)
   - 4.5 [Seq — Lazy Sequences (`~[...]`)](#45-seq--lazy-sequences-)
   - 4.6 [Unified Collection API and Type-Preserving Operations](#46-unified-collection-api-and-type-preserving-operations)
5. [Layer 2: Smart Default Implementations](#5-layer-2-smart-default-implementations)
   - 5.1 [CHAMP for Map and Set](#51-champ-for-map-and-set)
   - 5.2 [RRB-Tree for Vec](#52-rrb-tree-for-vec)
   - 5.3 [Cons Cells for List](#53-cons-cells-for-list)
   - 5.4 [Thunked Cons for Seq](#54-thunked-cons-for-seq)
   - 5.5 [Small-Size Optimization Strategy](#55-small-size-optimization-strategy)
   - 5.6 [Transient (Mutable Builder) Operations](#56-transient-mutable-builder-operations)
6. [Layer 3: Explicit Variant Types](#6-layer-3-explicit-variant-types)
   - 6.1 [SortedMap and SortedSet (Persistent B+ Tree)](#61-sortedmap-and-sortedset-persistent-b-tree)
   - 6.2 [Deque (Finger Tree)](#62-deque-finger-tree)
   - 6.3 [PriorityQueue (Pairing Heap)](#63-priorityqueue-pairing-heap)
   - 6.4 [ConcurrentMap (Ctrie)](#64-concurrentmap-ctrie)
   - 6.5 [SymbolTable (Adaptive Radix Tree)](#65-symboltable-adaptive-radix-tree)
   - 6.6 [UnionFind (Persistent Disjoint Sets)](#66-unionfind-persistent-disjoint-sets)
7. [Seq as Universal Abstraction](#7-seq-as-universal-abstraction)
   - 7.1 [The Seq-Centric Model](#71-the-seq-centric-model)
   - 7.2 [Seqable — Producing Sequences](#72-seqable--producing-sequences)
   - 7.3 [Buildable — Materializing Collections](#73-buildable--materializing-collections)
   - 7.4 [Type-Preserving Operations (Vec in → Vec out)](#74-type-preserving-operations-vec-in--vec-out)
   - 7.5 [Orthogonal Specialized Traits (Indexed, Keyed, Setlike)](#75-orthogonal-specialized-traits-indexed-keyed-setlike)
   - 7.6 [Seq Operations Replace Iteration](#76-seq-operations-replace-iteration)
   - 7.7 [Graduated Complexity (Beginners → Experts)](#77-graduated-complexity-beginners--experts)
8. [Lattice-Compatible Collections and Propagator Integration](#8-lattice-compatible-collections-and-propagator-integration)
   - 8.1 [LVar Semantics and Monotonic Data Structures](#81-lvar-semantics-and-monotonic-data-structures)
   - 8.2 [LVar Map — Monotonic Associative Containers](#82-lvar-map--monotonic-associative-containers)
   - 8.3 [LVar Set — Growing Sets with Threshold Reads](#83-lvar-set--growing-sets-with-threshold-reads)
   - 8.4 [Propagator Cell Architecture](#84-propagator-cell-architecture)
   - 8.5 [CRDT-Inspired Structures for Distributed Actors](#85-crdt-inspired-structures-for-distributed-actors)
   - 8.6 [Merge Functions and Conflict Resolution](#86-merge-functions-and-conflict-resolution)
9. [Dependent Types over Collections](#9-dependent-types-over-collections)
   - 9.1 [Length-Indexed Vectors (Vec n A)](#91-length-indexed-vectors-vec-n-a)
   - 9.2 [Bounded Collections and Refinement Types](#92-bounded-collections-and-refinement-types)
   - 9.3 [Proof-Carrying Operations](#93-proof-carrying-operations)
   - 9.4 [Erasure Strategy: Zero-Cost Proofs via QTT](#94-erasure-strategy-zero-cost-proofs-via-qtt)
   - 9.5 [Pattern Matching and Narrowing over Collections](#95-pattern-matching-and-narrowing-over-collections)
10. [Racket Prototype Implementation Strategy](#10-racket-prototype-implementation-strategy)
    - 10.1 [Module Architecture and Organization](#101-module-architecture-and-organization)
    - 10.2 [Struct-Based Node Representation](#102-struct-based-node-representation)
    - 10.3 [Generic Dispatch via Racket Generics](#103-generic-dispatch-via-racket-generics)
    - 10.4 [Integration with Existing Prototype](#104-integration-with-existing-prototype)
    - 10.5 [Testing Infrastructure](#105-testing-infrastructure)
11. [Memory Management in Racket](#11-memory-management-in-racket)
    - 11.1 [Racket's GC Model and Collection Lifetime](#111-rackets-gc-model-and-collection-lifetime)
    - 11.2 [QTT-Guided Optimization Opportunities](#112-qtt-guided-optimization-opportunities)
    - 11.3 [Transient Operations via Mutable Structs](#113-transient-operations-via-mutable-structs)
    - 11.4 [Cross-Actor Collection Sharing via Places](#114-cross-actor-collection-sharing-via-places)
    - 11.5 [Weak References and Ephemerons](#115-weak-references-and-ephemerons)
12. [Phased Implementation Plan](#12-phased-implementation-plan)
    - 12.1 [Phase 1: Core Foundation (Weeks 1–6)](#121-phase-1-core-foundation-weeks-16)
    - 12.2 [Phase 2: Optimized Backends (Weeks 7–14)](#122-phase-2-optimized-backends-weeks-714)
    - 12.3 [Phase 3: Specialized Structures (Weeks 15–22)](#123-phase-3-specialized-structures-weeks-1522)
    - 12.4 [Phase 4: Integration and Adaptation (Weeks 23–30)](#124-phase-4-integration-and-adaptation-weeks-2330)
    - 12.5 [Dependency Graph and Critical Path](#125-dependency-graph-and-critical-path)
    - 12.6 [Testing Strategy per Phase](#126-testing-strategy-per-phase)
13. [Key Challenges and Open Problems](#13-key-challenges-and-open-problems)
14. [References and Key Literature](#14-references-and-key-literature)

---

## 1. Introduction and Scope

Πρόλογος (Prologos) is a dependently-typed functional-logic programming language that unifies the declarative paradigm of logic programming with the expressiveness of dependent types and the performance characteristics of modern functional compilation. The core data structures presented in this guide form the foundation upon which all collection operations, constraint propagation, and program execution depend.

This guide addresses a fundamental architectural decision that distinguishes Prologos from prior languages: the elevation of `Seq ~[]`, the lazy sequence abstraction, from a convenience utility to the *universal abstraction* through which all collection types expose their contents. This choice reflects deep commitments to both language design and implementation strategy. Rather than building a complex supertrait hierarchy that forces newcomers to reason about contravariance, closure traits, and associated type projection, we present a flat, orthogonal trait system where `Seq` acts as a Rosetta stone between different collection representations.

The implementation strategy is three-layered. Layer 1 consists of user-facing collection types: `@[1 2 3]` for indexed persistent vectors, `{a: 1, b: 2}` for hash maps, `#{1 2 3}` for hash sets, `'[1 2 3]` for cons lists, and `~[...]` for lazy sequences. Layer 2 provides the smart, data-structure-specific implementations that ensure good time and space complexity: CHAMP (Compressed Hash Array Mapped Prefix-tree) for maps and sets, RRB-Trees (Relaxed Radix Balanced Trees) for vectors, cons cells for lists, and thunked lazy cons for sequences. Layer 3 supplies explicit variants for specialized use cases: `SortedMap` backed by persistent B+ Trees, `Deque` implemented as Finger Trees, `PriorityQueue` using Pairing Heaps, `ConcurrentMap` via Ctries, and `SymbolTable` via Adaptive Radix Trees.

The target implementation is a Racket prototype residing at `/mnt/prologos/racket/prologos/`, which contains foundational modules such as `typing-core.rkt` for type representation, `qtt.rkt` for quantitative type theory mechanics, `sessions.rkt` for session typing integration, and initial implementations of core structures. This guide is simultaneously a specification for the Racket prototype and a roadmap for eventual compilation to lower-level targets.

Scope and motivation are critical. This guide deliberately excludes runtime garbage collection internals, operating system level memory management, and micro-optimization concerns such as CPU cache line layout. Instead, it focuses on the *logical architecture* of data structures as they present themselves to language users and intermediate compiler phases. We address how collections compose with the type system, particularly how QTT (Quantitative Type Theory) multiplicity annotations affect sharing strategies, and how lattice structures enable constraint propagators to maintain invariants across collection updates.

The guide is structured for a spectrum of audiences. Newcomers to Prologos will discover the user-facing API first—how to write `map inc @[1 2 3]` and understand that it returns a `Vec` unchanged in type. Intermediate developers will explore the trait system and how orthogonal traits like `Indexed`, `Keyed`, and `Setlike` permit generic algorithms that work across multiple collection types without requiring complex constraint inheritance. Advanced implementers will study the implementations themselves and understand the trade-offs between copying strategies, structural sharing, and lazy evaluation. Throughout, we maintain the principle of *graduated complexity*: basic operations are transparent and composable, while expert features remain accessible without forcing every programmer to engage with them.

---

## 2. Architectural Principles

### 2.1 The Four-Layer Abstraction Model

The architecture rests on four distinct layers of abstraction, each addressing a specific concern in the design space. The bottommost layer, which we do not address in this guide, consists of the runtime memory model and garbage collection. Above that lies the *persistent data structure layer*, which defines how values are represented in memory, how structural sharing is maintained, and how mutations (in the transient sense of building) are performed. The next layer up comprises the *trait system*, which provides a contract language for generic algorithms to express their requirements without committing to specific implementations. The topmost layer is the *user-facing collection API*, which presents an intuitive interface to Prologos programmers.

This layering is intentional. The user rarely needs to know that a `Map` is implemented as a CHAMP, or that updates exploit structural sharing to achieve logarithmic time complexity. The trait system abstracts away these details while remaining sufficiently fine-grained to permit zero-cost abstractions. This contrasts with languages that expose implementation details in their type signatures or languages that hide all details in opaque runtime behavior, forcing programmers to resort to benchmarking to understand performance characteristics.

The four-layer model also resolves a tension between expressiveness and usability. A programmer writing a generic algorithm that works on any `Seqable` type needs only to know that `to-seq` produces a sequence; the algorithm is oblivious to whether the input is a `Vec`, `List`, or `Map`. Yet when that algorithm is *instantiated* at a concrete type, the compiler can inline the specific `to-seq` implementation and optimize the entire pipeline. This is the opposite of runtime polymorphism: we achieve genericity through static specialization.

### 2.2 Persistence, Structural Sharing, and the Immutability Invariant

All user-facing collections in Prologos are persistent (or functional). A persistent data structure guarantees that after an update operation, both the original and the updated version coexist and remain accessible. This property is essential for logic programming, where backtracking may return to earlier program states. It is equally vital for concurrency, where shared data must not race or corrupt itself.

The efficiency of persistence derives from *structural sharing*. When we insert a new key into a `Map`, we do not copy the entire map. Instead, we create a new root node containing a reference to its children, which in turn share children with the old root. Only the nodes on the path from the root to the insertion point are created anew. The unchanged subtrees are literally shared: both the old and new map point to the same memory locations. This means that persistent updates take logarithmic time and space proportional to the depth of the tree, not the size of the collection.

The immutability invariant underpins this entire strategy. Once a node is created and published to the world, no one—not the creator, not the original collection, not any alias—may modify it. This invariant is enforced at the language level by type system restrictions and at the runtime level by value semantics. In Prologos, collections are values, not references. Passing a `Map` to a function is cheap (a pointer or immediate value), but calling a function on a `Map` cannot corrupt that `Map` because the function receives the value, not write access to its memory.

This contrasts sharply with mutable data structures. A mutable hash table requires synchronization primitives if accessed from multiple threads. Transactional memory systems track writes and abort on conflict. Copy-on-write mechanisms copy data speculatively. The persistent approach avoids these hazards entirely: sharing is safe because mutation is impossible.

Yet persistence alone would be expensive if every update required allocating a new root node and all ancestors. Prologos addresses this through transient (mutable builder) operations, which we discuss in Layer 2. Transient builders allow efficient batch updates within a single scope, exploiting the fact that intermediate values are not shared with the rest of the program.

### 2.3 QTT Multiplicities and Memory Strategy

Quantitative Type Theory introduces multiplicity annotations to track how often a value is used. A value with multiplicity zero (written `0.x`) is never used and can be erased entirely by the compiler. A value with multiplicity one (written `1.x`) is used exactly once; the compiler can apply linear-logic optimizations, including move semantics and in-place updates. A value with multiplicity omega (written `ω.x` or unbounded) can be used any number of times and must be treated conservatively.

These multiplicities inform the memory strategy for collections. When a function is declared as `defn f [x : 1.Vec A] : ...`, the type system guarantees that `x` is used exactly once in the body of `f`. This allows the compiler to perform a *destructive update*: if the function builds a new `Vec` by appending to `x`, the implementation can reuse the allocation of `x` provided that `x` is never read again. This is safe because linearity ensures that the old value is no longer accessible after the update.

By contrast, when a value has unrestricted multiplicity (omega), the compiler must assume that any update might be observed by other references to the same collection. Structural sharing is the correct strategy in this case, ensuring that the old and new values diverge in their content while sharing memory.

The interplay between multiplicities and structural sharing is subtle. An unrestricted `Map` must use CHAMP to ensure fast persistent updates. But a linear `Map` (used exactly once) could, in principle, be mutated in place. Prologos exposes this choice to advanced programmers through explicit `Transient` builders (described in Section 5.6), which mark regions where mutation is safe and observable performance gains are possible.

### 2.4 Lattice Compatibility for Propagators

Prologos unifies functional programming with logic programming through constraint propagators. A propagator is a concurrent actor that maintains an invariant over a set of logical variables and asynchronously refines their domains. When a variable's domain is refined (reduced in its lattice order), the propagator recomputes and may refine other variables.

Collections must integrate into this lattice-based model. A key requirement is that each collection type induces a lattice order under which refinement has clear semantics. For `Set`, the lattice is subset inclusion: a set `S'` refines `S` if `S' ⊆ S`. For `Map`, refinement is pointwise: `M'` refines `M` if for each key present in both, the values are related by the lattice order of the value type. For `Vec`, refinement is element-wise.

This lattice structure enables propagators to express constraints declaratively. For instance, a constraint that "the sum of elements in a vector must not exceed a threshold" can be implemented as a propagator that, when the threshold is refined downward, tightens the bounds on each element. The propagator need not be aware of the specific memory layout of the `Vec`; it only needs to understand the lattice order and have a way to construct refined versions of the collection.

The consequence is that data structure implementations must support *incremental refinement* without requiring the entire collection to be copied or rebuilt. For sets and maps, this is natural: we can refine a set by removing elements, one at a time. For indexed collections like `Vec`, refinement is trickier; we must be able to update elements at specific indices efficiently. This is precisely why RRB-Trees are chosen for `Vec` over simpler structures: they provide logarithmic-time indexed access and update, enabling efficient constraint propagation.

### 2.5 Seq as the Architectural Hub

The central architectural innovation of Prologos is the elevation of `Seq` to the role of universal abstraction for collection access. Every collection type implements `Seqable`, exposing a method `to-seq : C A -> Seq A` that produces a lazy sequence of elements. Conversely, every collection type implements `Buildable`, with a method `from-seq : Seq A -> C A` that materializes a sequence into a collection of the appropriate type.

This design resolves several longstanding tensions in language design. First, it eliminates the need for a complex trait hierarchy. Rather than declaring a `Collection` supertrait with methods for `size`, `map`, `filter`, and `fold` (each with complicated variance rules), we provide a single abstraction point: `Seqable`. Any algorithm that works with `Seqable` works with any collection. Specialized traits like `Indexed` (for `nth` and `length`) remain orthogonal, allowing a programmer to express precisely which operations their algorithm requires without committing to a specific collection type.

Second, the `Seq`-centric model naturally exposes lazy evaluation. Many collection operations—filtering, mapping, flattening—are most naturally expressed as lazy transformations. A traditional iterator-based design forces a choice: either iterators are lazy and allocation is deferred, forcing the user to reason about lifetimes and borrowing, or iterators are eager and collections are rebuilt on every operation. By making `Seq` the primary abstraction and allowing `Seqable` types to emit sequences, we give both strategies equal standing. A `Vec` can be converted to a `Seq` for lazy processing, and the result can be materialized back into a `Vec` (or `List`, `Set`, `Map`) as needed.

Third, the `Seq`-centric model naturally integrates with dependent types and refinement. A sequence can be refined element-by-element as constraints are solved. Propagators that refine constraints can emit refined sequences, which can then be collected back into refined collections. This interplay between lazy sequences and constraint propagation is central to the hybrid declarative-procedural execution model of Prologos.

The implementation of `Seq` itself is simple: it is a lazy cons cell, optionally parameterized over the type of elements. A `Seq A` is either the empty sequence or a cons cell containing an element of type `A` and a thunk that, when forced, produces the rest of the sequence. This simplicity is intentional. By keeping `Seq` minimal, we ensure that it can be efficient and that optimizations are straightforward. The complex work of representing collections efficiently is deferred to the specialized types.

---

## 3. Prerequisite Infrastructure

### 3.1 Core Representation Requirements

Before implementing any collection type, we must establish the foundational representations and operations that all data structures will rely upon. In the context of the Racket prototype, this infrastructure includes facilities for creating structures, computing hashes, comparing values for equality and order, and managing references in a way compatible with Racket's memory model.

The most basic requirement is a *value representation*. In Πρόλογος, as in Racket, values are arbitrary Scheme objects that can be wrapped in records, vectors, or user-defined structures. For implementation purposes, we must be able to store collections as structures with fields for sub-components (children, metadata, etc.). The Racket `struct` form provides this directly. In a compiled implementation targeting a lower-level runtime, we would need to allocate records on the heap and ensure that pointer tagging and header information are correct.

A crucial aspect of representation is the *uniqueness of identity*. In Racket (and most garbage-collected languages), every allocated object has a unique identity, distinct from its value. Two objects are `eq?` if they are the same object (same memory address) and `equal?` if they have the same structure and content. For persistent data structures, we exploit this distinction: two collections can be `equal?` (same elements) without being `eq?` (same memory). This allows structural sharing: if two maps share a subtree, that shared subtree is `eq?` to both, even though the two maps are distinct objects.

A second requirement is *memoization of computed properties*. Many data structure implementations benefit from caching expensive computations. For instance, a hash map might cache the count of elements, avoiding the need to traverse the entire structure when `size` is requested. In Racket, this is straightforward: a field in the struct simply stores the cached value. Care must be taken to ensure that cached values remain valid whenever the structure is updated (or ensure that updates always create new structures with recomputed caches).

A third requirement is *pointer representation* for indirection and lazy evaluation. In Racket, a thunk is a zero-argument function that, when called, produces a value. We use thunks extensively for lazy sequences. Alternatively, we can use promise structures that cache their result after the first force. The key point is that representation must support delayed computation.

Finally, we require *bulk operations* on primitive arrays: fast sequential access, mutation within a transient scope, and conversion to/from persistent structures. Racket provides vectors (`#(1 2 3)`), which are mutable arrays with O(1) indexing. For the RRB-Tree implementation of `Vec`, we will use Racket vectors to store child pointers and branch metadata.

### 3.2 Hash Function Architecture

Persistent hash-based data structures (CHAMP for maps and sets, hash tables for symbol tables) depend critically on hash function architecture. The hash function must distribute values uniformly across the output space, must be deterministic (the same value always hashes to the same output), and must respect equality (if two values are `equal?`, they must hash to the same value).

In Prologos, we distinguish between *structural hashing* and *identity hashing*. Structural hashing computes a hash based on the content of a value. For example, the structural hash of the list `(1 2 3)` is the same regardless of where the list is allocated. Identity hashing computes a hash based on the object's memory address, changing if the object is relocated by garbage collection. Structural hashing is appropriate for keys in maps and elements in sets, ensuring that `{(1 2 3): "a"}` and another map constructed independently with the same key have compatible lookups. Identity hashing is appropriate for memoization tables where we want to cache results keyed by object identity.

The architecture consists of a *hash function interface* that is polymorphic over the type being hashed. In Racket, we implement this as a generic procedure:

```racket
(define (hash-code x)
  (cond
    [(number? x) (modular-hash-number x)]
    [(string? x) (modular-hash-string x)]
    [(symbol? x) (modular-hash-symbol x)]
    [(pair? x) (combine-hash-codes
                 (hash-code (car x))
                 (hash-code (cdr x)))]
    [(vector? x) (combine-hash-codes
                   (hash-code (vector-length x))
                   (foldl (lambda (elt acc)
                            (combine-hash-codes acc (hash-code elt)))
                          0
                          (vector->list x)))]
    [else (object-hash x)]))
```

The `modular-hash-*` functions are primitives that compute well-distributed hashes for built-in types, exploiting knowledge of their representation. The `combine-hash-codes` function merges two hashes to produce a new hash, typically using multiplication by a large prime and XOR. The `object-hash` fallback uses identity-based hashing.

A critical aspect of hash-based structures is collision handling. In a CHAMP, collisions are resolved by storing all key-value pairs with the same hash in a single entry, using equality tests to find the correct pair. In a Ctrie (used for concurrent maps), collisions trigger trie navigation at a finer hash granularity. The hash function itself need not be perfect; perfect hashing is a luxury reserved for static collections. Instead, we design for the common case (no collisions) and handle collisions as a fallback.

### 3.3 Comparison and Ordering Traits

Collections that support ordering (sorted maps, priority queues) depend on a *comparison function* that defines a total or partial order on elements. In Prologos, we provide an abstraction over comparison, allowing users to specify custom orderings without duplicating data structure implementations.

The `Ord` trait defines a total order:

```prologos
trait Ord (A : Type)
  compare : A -> A -> Ordering

defn-enum Ordering
  | LT
  | EQ
  | GT
```

The `compare` function returns an `Ordering` indicating how two elements relate. Derived operations like `<`, `<=`, `>`, `>=` are defined in terms of `compare`. For types with a natural order (numbers, strings, symbols), `Ord` instances are provided automatically by the compiler.

For heterogeneous collections (maps with keys of different types, or sets containing mixed types), we must define a *lexicographic* order that assigns a priority to types and compares within types. For instance, we might define an order where all numbers compare before all strings, and within each category, values are compared in the usual way. This is necessary for implementing polymorphic sorted maps.

In the Racket prototype, comparison is implemented as a procedure that returns a numeric value or symbol:

```racket
(define (compare-values x y)
  (cond
    [(< x y) 'LT]
    [(> x y) 'GT]
    [else 'EQ]))

(define (total-order x y)
  (let ([x-type-order (type-priority x)]
        [y-type-order (type-priority y)])
    (if (= x-type-order y-type-order)
        (compare-values x y)
        (if (< x-type-order y-type-order) 'LT 'GT))))
```

### 3.4 Racket GC Integration

The Racket runtime provides a garbage collector that automatically frees objects when they are no longer reachable. For persistent data structures, this is a significant advantage: we need not manually manage the lifetime of shared sub-structures. When a map is no longer referenced, the garbage collector will eventually collect it and its children, even though other maps may reference some of its subtrees.

A subtlety arises when we use weak references. A weak reference is a pointer to an object that does not prevent garbage collection; if the only references to an object are weak, the garbage collector will collect it. Weak references are useful for memoization tables that should not keep values alive. In Racket, weak vectors and weak boxes provide this facility.

For the constraint propagator system, weak references are essential. A propagator that caches refined constraints should not keep those constraints alive; if a constraint is no longer referenced by the main computation, it should be garbage-collected, and the propagator's cache should transparently forget about it.

Another consideration is *finalizers*. A finalizer is a procedure that is called when an object is about to be garbage-collected. Finalizers can be used for cleanup actions (closing files, releasing locks, etc.). In Prologos, finalizers are not essential for data structures themselves but are useful for ensuring that external resources are released when collections that reference them become unreachable.

### 3.5 Trait System Foundation

The trait system of Prologos is the primary abstraction mechanism for generic programming. A trait is a set of required methods and optional default implementations. Types can implement multiple traits, and traits have no supertraits (enforcing orthogonality).

The fundamental traits for collections are:

```prologos
trait Seqable (C : Type -> Type)
  to-seq : C A -> Seq A

trait Buildable (C : Type -> Type)
  from-seq : Seq A -> C A
  empty : C A
```

Every collection type must implement `Seqable` and `Buildable` to participate in the universal collection protocol. Additional orthogonal traits provide specialized operations:

```prologos
trait Indexed (C : Type -> Type)
  nth : C A -> Nat -> Option A
  length : C A -> Nat
  update : C A -> Nat -> A -> C A

trait Keyed (C : Type -> Type -> Type)
  get : C K V -> K -> Option V
  assoc : C K V -> K -> V -> C K V
  dissoc : C K V -> K -> C K V
  keys : C K V -> Seq K
  vals : C K V -> Seq V

trait Setlike (C : Type -> Type)
  member? : C A -> A -> Bool
  insert : C A -> A -> C A
  remove : C A -> A -> C A
```

The design principle is that these traits are orthogonal: a type implements only those traits whose operations are efficient. A `Vec` implements `Indexed`, `Seqable`, and `Buildable`. A `Map` implements `Keyed`, `Seqable`, and `Buildable`. A `Set` implements `Setlike`, `Seqable`, and `Buildable`. There is no hierarchy; no trait extends another.

The implementation of trait resolution in the compiler is straightforward. When a generic function is declared with constraints, the compiler collects all constraints and resolves them at instantiation time by looking up the implementing type in a trait registry. This is similar to Haskell's typeclass system, but without the complication of supertrait relationships.

---

## 4. Layer 1: User-Facing Collection Types

### 4.1 Vec — Indexed Persistent Vectors (`@[...]`)

Vectors are ordered collections of elements accessible by index. The syntax `@[1 2 3]` constructs a vector containing the numbers 1, 2, and 3. Vectors are persistent: updating an element creates a new vector sharing structure with the old one. Vectors implement the `Indexed` trait, providing `nth` for element access, `length` for the number of elements, and `update` for creating a modified vector.

In terms of semantics, a vector is a partial function from indices (natural numbers less than the length) to elements. The `nth` function looks up an element by index, returning `(some x)` if the index is in bounds or `(none)` otherwise. The `length` function returns the count of elements. The `update` function produces a new vector where the element at a specified index has been replaced; if the index is out of bounds, the vector is unchanged.

The vector type is declared as:

```prologos
defn Vec (A : Type) : Type = ...

instance Seqable Vec where
  to-seq v = vec-to-seq v 0

instance Buildable Vec where
  from-seq s = vec-from-seq s
  empty = @[]

instance Indexed Vec where
  nth v i = vec-nth v i
  length v = vec-length v
  update v i x = vec-update v i x
```

The semantics of conversion are clear: `to-seq` produces a lazy sequence of elements in order, and `from-seq` collects a sequence into a vector of the same length, in the same order.

**Core Operations.**

| Operation | Type | Complexity | Notes |
|-----------|------|-----------|-------|
| `length` | `Vec A →ω Nat` | O(1) | Cached in root node. |
| `nth` | `Vec A → Nat →ω Option A` | O(log₃₂ n) | Radix lookup in RRB-Tree. |
| `update` | `Vec A → Nat → A → Vec A` | O(log₃₂ n) | Path copy in radix tree. |
| `push` | `Vec A → A → Vec A` | O(1) amortized | Append to tail. |
| `pop` | `Vec A → Option (Vec A × A)` | O(1) amortized | Remove from tail. |
| `concat` | `Vec A → Vec A → Vec A` | O(log n + log m) | RRB-Tree concatenation. |
| `slice` | `Vec A → Nat → Nat → Vec A` | O(log n) | Substring of RRB-Tree. |

### 4.2 Map — Persistent Hash Maps (`{...}`)

Maps are unordered collections of key-value pairs. The syntax `{a: 1, b: 2}` constructs a map with two entries. Maps are persistent and implement the `Keyed` trait. The primary operations are `get` (lookup a value by key), `assoc` (insert or update a key-value pair), and `dissoc` (remove a key). Additional operations `keys` and `vals` produce sequences of keys and values respectively.

The map type is polymorphic in both keys and values: `Map K V` is a map from type `K` to type `V`. Keys must be comparable for equality; values can be arbitrary.

```prologos
defn Map (K : Type) (V : Type) : Type = ...

instance Seqable (Map K) where
  to-seq m = champ-to-seq m

instance Buildable (Map K) where
  from-seq s = foldl (lambda (m kv) (assoc m (fst kv) (snd kv))) empty s
  empty = {}

instance Keyed Map where
  get m k = champ-lookup m k
  assoc m k v = champ-insert m k v
  dissoc m k = champ-delete m k
  keys m = seq-map fst (to-seq m)
  vals m = seq-map snd (to-seq m)
```

**Core Operations.**

| Operation | Type | Complexity | Notes |
|-----------|------|-----------|-------|
| `empty` | `Map K V` | O(1) | Empty CHAMP root. |
| `get` | `Map K V → K →ω Option V` | O(log₃₂ n) | CHAMP trie traversal. |
| `assoc` | `Map K V → K → V → Map K V` | O(log₃₂ n) | Path copy. |
| `dissoc` | `Map K V → K → Map K V` | O(log₃₂ n) | Path copy. |
| `size` | `Map K V →ω Nat` | O(1) | Cached. |

### 4.3 Set — Persistent Hash Sets (`#{...}`)

Sets are unordered collections of unique elements. The syntax `#{1 2 3}` constructs a set containing three elements. Sets are persistent and implement the `Setlike` trait. The primary operations are `member?` (test membership), `insert` (add an element), and `remove` (remove an element).

Internally, a set is implemented as a map from elements to unit (the type with a single value). This reuses all of the machinery of hash maps while specializing the value type.

```prologos
defn Set (A : Type) : Type = Map A Unit

instance Seqable Set where
  to-seq s = seq-map fst (to-seq (set-as-map s))

instance Buildable Set where
  from-seq s = foldl insert empty s
  empty = #{}

instance Setlike Set where
  member? s x = is-some (get (set-as-map s) x)
  insert s x = assoc (set-as-map s) x ()
  remove s x = dissoc (set-as-map s) x
```

**Core Operations.**

| Operation | Type | Complexity | Notes |
|-----------|------|-----------|-------|
| `member?` | `Set A → A →ω Bool` | O(log₃₂ n) | Membership test. |
| `insert` | `Set A → A → Set A` | O(log₃₂ n) | Idempotent add. |
| `union` | `Set A → Set A → Set A` | O(n + m) | Set union. |
| `intersection` | `Set A → Set A → Set A` | O(min(n, m)) | Common elements. |

### 4.4 List — Immutable Cons Lists (`'[...]`)

Lists are ordered collections using a cons-cell representation. The syntax `'[1 2 3]` constructs a list containing three elements. Lists are persistent and implement `Seqable` and `Buildable`. Unlike vectors, lists are not designed for random access; their strength is in O(1) head access and tail manipulation.

A list is either the empty list or a cons cell containing a head element and a tail list:

```prologos
defn-enum List (A : Type)
  | nil : List A
  | cons : A -> List A -> List A

instance Seqable List where
  to-seq nil = seq-empty
  to-seq (cons hd tl) = seq-cons hd (to-seq tl)

instance Buildable List where
  from-seq s = seq-fold-right cons nil s
  empty = nil
```

**Core Operations.**

| Operation | Type | Complexity | Notes |
|-----------|------|-----------|-------|
| `cons` | `A → List A → List A` | O(1) | Prepend. |
| `head` | `List A →ω Option A` | O(1) | First element. |
| `tail` | `List A →ω Option (List A)` | O(1) | All but first. |
| `append` | `List A → List A → List A` | O(n) | Left list traversed. |
| `length` | `List A →ω Nat` | O(n) | Linear scan. |

### 4.5 Seq — Lazy Sequences (`~[...]`)

Sequences are lazy, potentially infinite collections. The syntax `~[1 2 3]` constructs a finite sequence, but sequences may also be infinite, defined by a recurrence relation or by an external source.

A sequence is defined inductively as either empty or a cons cell containing an element and a thunk that, when forced, produces the rest of the sequence:

```prologos
defn-enum Seq (A : Type)
  | seq-empty : Seq A
  | seq-cons : A -> (Thunk (Seq A)) -> Seq A
```

The key operation on sequences is `seq-force`, which evaluates the thunk to obtain the rest of a sequence. Sequences form a monad under `seq-bind`, allowing chaining of lazy computations. They also form a functor under `seq-map`, allowing element-wise transformations.

```prologos
-- Infinite sequence: natural numbers.
nats : Seq Nat
nats = unfold (λ n → (n, n + 1)) 0

-- Take first n elements, materializing into a List.
first-five : List Nat
first-five = from-seq (seq-take 5 nats)  -- '[0 1 2 3 4]
```

### 4.6 Unified Collection API and Type-Preserving Operations

The cornerstone of the Seq-centric design is the ability to write generic algorithms that are *type-preserving*: an operation that takes a `Vec` and produces a `Vec`, without type-level gymnastics or type casting.

Consider the `map` function:

```prologos
defn map [f : A -> B, c : C A] : C B where (Seqable C, Buildable C) =
  from-seq (seq-map f (to-seq c))
```

This function takes a collection `c` of type `C A` and produces a value of type `C B`. The type variable `C` is a type constructor (a function from types to types). The constraints `(Seqable C, Buildable C)` indicate that `C` must implement both traits.

The implementation converts the collection to a sequence using `to-seq`, applies `seq-map` to transform elements, and then materializes the result back into a collection of the same type using `from-seq`. The key insight is that the type of the result is `C B`, not `Seq B` or some other type. Thus:

```prologos
map inc @[1 2 3]     -- Vec Nat -> Vec Nat => @[2 3 4]
map inc '[1 2 3]     -- List Nat -> List Nat => '[2 3 4]
map inc ~[1 2 3]     -- Seq Nat -> Seq Nat => ~[2 3 4]
map inc #{1 2 3}     -- Set Nat -> Set Nat => #{2 3 4}
```

The same principle applies to other operations. A `filter` function:

```prologos
defn filter [p : A -> Bool, c : C A] : C A where (Seqable C, Buildable C) =
  from-seq (seq-filter p (to-seq c))
```

And `fold` requires only `Seqable`, not `Buildable`, because the result is a scalar:

```prologos
defn fold [f : B -> A -> B, z : B, c : C A] : B where (Seqable C) =
  seq-fold f z (to-seq c)
```

Size, emptiness, and membership tests are defined in terms of `Seq`:

```prologos
defn size [c : C A] : Nat where (Seqable C) =
  seq-count (to-seq c)

defn empty? [c : C A] : Bool where (Seqable C) =
  seq-null? (to-seq c)

defn contains? [c : C A, x : A] : Bool where (Seqable C) =
  seq-any? (eq? x) (to-seq c)
```

These operations are generic and work on any collection type. For some types (like `Vec`), we can provide efficient overrides that avoid conversion to a sequence. But the default implementations are always available, ensuring that no collection type is left without these operations.

---

## 5. Layer 2: Smart Default Implementations

### 5.1 CHAMP for Map and Set

The Compressed Hash Array Mapped Prefix-tree (CHAMP) is a persistent hash trie designed for efficient representation of maps and sets. It is the default implementation for `Map` and `Set` in Prologos, offering logarithmic-time operations, excellent cache locality, and minimal memory overhead compared to dense arrays.

A CHAMP node is a trie node that compresses multiple hash bits into a single node. The node contains two bitmaps: `datamap`, which records which hash buckets contain data (key-value pairs), and `nodemap`, which records which hash buckets contain child nodes. A single array stores both data entries and child node pointers, compacted to contain only the buckets that are actually used.

The structure is declared as:

```racket
(struct champ-node (datamap nodemap array) #:transparent)
```

Here, `datamap` and `nodemap` are unsigned integers where each bit corresponds to a hash bucket. If bit `i` of `datamap` is set, then the data for hash bucket `i` is present in the array. Similarly for `nodemap`. The array contains data entries (key-value pairs) corresponding to set bits in `datamap`, followed by child node pointers corresponding to set bits in `nodemap`.

To look up a key in a CHAMP, we navigate the trie level by level, extracting a segment of the hash code at each level:

```racket
(define (champ-lookup root hash key)
  (define (loop node h level)
    (let* ([segment (bitwise-and (arithmetic-shift h (- (* level 5)))
                                  #b11111)]
           [bit (arithmetic-shift 1 segment)]
           [data-mask (champ-node-datamap node)]
           [node-mask (champ-node-nodemap node)])
      (cond
        [(not (zero? (bitwise-and data-mask bit)))
         ;; Data is present in this node
         (let ([idx (bitcount (bitwise-and data-mask (- bit 1)))])
           (let* ([arr (champ-node-array node)]
                  [entry (vector-ref arr idx)])
             (if (equal? (car entry) key)
                 (some (cdr entry))
                 (none))))]
        [(not (zero? (bitwise-and node-mask bit)))
         ;; Child node is present
         (let* ([data-count (bitcount data-mask)]
                [idx (+ data-count
                        (bitcount (bitwise-and node-mask (- bit 1))))]
                [child (vector-ref (champ-node-array node) idx)])
           (loop child h (+ level 1)))]
        [else (none)])))
  (loop root hash 0))
```

The lookup function traverses the trie, extracting 5-bit segments of the hash at each level (since 2^5 = 32 buckets per node). At each node, we check if the data or a child node is present for the current segment. If data is present, we compare keys to find the match. If a child node is present, we recurse. If neither is present, the key is not in the map.

Insertion into a CHAMP exploits structural sharing. When inserting a new key-value pair, we traverse the trie until we find the correct position. If the position is empty, we create a new node with the bit set in the `datamap` and the entry added to the array. If a collision occurs (the same hash bucket already contains data), we may create a new child node at the next level or adjust the structure as needed. Data entries are packed at the front of the array; inserting at the data index preserves the bidirectional layout because child nodes at the end shift by one slot.

The key insight of CHAMP over simpler hash tries is compression. By using bitmasks, a CHAMP node can have as few as one or two entries, avoiding the 32 array slots that a traditional hash array would require. This reduces memory consumption dramatically, typically by a factor of 8–16 compared to a naive hash table.

**Canonical Form.** A key advantage of CHAMP over HAMT is *canonical form*: the structure of a CHAMP map is uniquely determined by its contents, regardless of insertion order. This enables fast equality checks.

**Performance Characteristics.** CHAMP offers 22–85% faster iteration than HAMT (due to data-first layout), 3–25x faster equality checks, and 16–68% less memory per node.

### 5.2 RRB-Tree for Vec

The RRB-Tree (Relaxed Radix Balanced Tree) is a persistent array data structure that provides O(log n) access, update, and append operations. It is the default implementation for `Vec` in Prologos.

An RRB-Tree is similar to a B-tree but relaxes the strict balance requirement to allow efficient functional updates. The tree is structured as a trie of blocks, where each node can have a variable number of children (typically between 16 and 32). Each node also stores metadata about the number of elements in each child, allowing indexed access without traversing every child.

The RRB-Tree node structure is:

```racket
(struct rrb-node (children counts) #:transparent)
```

Here, `children` is a vector of child nodes (or leaf nodes containing elements), and `counts` is a vector of cumulative element counts. `counts[i]` records the total number of elements in children 0 through i, allowing binary search to find the child containing a given index.

Indexed access to an element at position `idx` proceeds by binary search on the `counts` vector to locate the correct child:

```racket
(define (rrb-nth tree idx)
  (define (loop node idx)
    (cond
      [(leaf-node? node)
       (if (< idx (vector-length (leaf-children node)))
           (some (vector-ref (leaf-children node) idx))
           (none))]
      [else
       (let ([child-idx (binary-search-counts (rrb-node-counts node) idx)])
         (if (>= child-idx 0)
             (let ([child-offset
                    (if (= child-idx 0)
                        0
                        (vector-ref (rrb-node-counts node) (- child-idx 1)))])
               (loop (vector-ref (rrb-node-children node) child-idx)
                     (- idx child-offset)))
             (none)))]))
  (loop tree idx))
```

Updating an element at position `idx` follows a path from the root to the leaf, copying all nodes on the path while sharing untouched subtrees:

```racket
(define (rrb-update tree idx value)
  (define (loop node idx depth)
    (cond
      [(leaf-node? node)
       (let ([new-arr (vector-copy (leaf-children node))])
         (vector-set! new-arr idx value)
         (make-leaf-node new-arr))]
      [else
       (let ([child-idx (binary-search-counts (rrb-node-counts node) idx)])
         (let ([child-offset
                (if (= child-idx 0) 0
                    (vector-ref (rrb-node-counts node) (- child-idx 1)))])
           (let* ([old-child (vector-ref (rrb-node-children node) child-idx)]
                  [new-child (loop old-child (- idx child-offset) (+ depth 1))]
                  [new-children (vector-copy (rrb-node-children node))]
                  [new-counts (vector-copy (rrb-node-counts node))])
             (vector-set! new-children child-idx new-child)
             (make-rrb-node new-children new-counts))))]))
  (loop tree idx 0))
```

**Concatenation.** The magic of RRB-Trees is efficient concatenation: the algorithm "zips" the spines of two trees in O(log(min(n, m))) time, sharing the bulk of both trees.

**Display/Focus Optimization.** For sequential operations, an RRB-Tree maintains a cached path from root to the recently-accessed leaf, enabling amortized O(1) appends.

**Small-Size Optimization.** For vectors with ≤ 32 elements, no trie overhead is used; a flat array is stored directly.

### 5.3 Cons Cells for List

The `List` type is implemented using cons cells, the simplest possible persistent data structure. A cons cell is either the empty list `nil` or a pair `(cons head tail)` containing an element and a reference to the rest of the list.

In the Racket prototype, cons cells are implemented directly as structures:

```racket
(struct prologos-cons (head tail) #:transparent)
(define prologos-nil '())

(define (list-nth lst idx)
  (cond
    [(null? lst) (none)]
    [(= idx 0) (some (prologos-cons-head lst))]
    [else (list-nth (prologos-cons-tail lst) (- idx 1))]))

(define (list-length lst)
  (if (null? lst)
      0
      (+ 1 (list-length (prologos-cons-tail lst)))))
```

These operations are simple but take linear time in the worst case. This is acceptable because lists are primarily used for sequential access, not random access. When random access is needed, a vector is more appropriate.

### 5.4 Thunked Cons for Seq

Sequences are implemented as lazy cons cells, where the tail of a sequence is wrapped in a thunk:

```racket
(struct seq-cons-cell (head thunk) #:transparent)
(define seq-empty (void))

(define (seq-cons hd thk)
  (seq-cons-cell hd thk))

(define (seq-force s)
  (if (void? s)
      seq-empty
      (let ([thk (seq-cons-cell-thunk s)])
        (thk))))

(define (seq-head s)
  (if (void? s)
      (none)
      (some (seq-cons-cell-head s))))
```

The lazy evaluation is critical for sequences. Consider a sequence generated by a recurrence relation:

```racket
(define (nat-seq n)
  (seq-cons n (lambda () (nat-seq (+ n 1)))))
```

This generates an infinite sequence of natural numbers starting from `n`. The thunk `(lambda () (nat-seq (+ n 1)))` is not evaluated until `seq-force` is called on it. This allows processing infinite sequences without allocating infinite memory.

Sequence operations like `seq-map` and `seq-filter` are defined recursively, preserving laziness:

```racket
(define (seq-map f s)
  (if (void? s)
      seq-empty
      (seq-cons (f (seq-cons-cell-head s))
                (lambda () (seq-map f (seq-force s))))))

(define (seq-filter p s)
  (if (void? s)
      seq-empty
      (if (p (seq-cons-cell-head s))
          (seq-cons (seq-cons-cell-head s)
                    (lambda () (seq-filter p (seq-force s))))
          (seq-filter p (seq-force s)))))
```

Both operations produce new thunks that, when forced, continue the computation. This allows processing an infinite sequence by taking only finitely many elements.

### 5.5 Small-Size Optimization Strategy

Many persistent data structures benefit from special handling of small collections. A CHAMP node with only one entry, for instance, could be represented as a single key-value pair instead of a full node structure, saving memory.

Prologos employs several small-size optimizations. For maps and sets smaller than a threshold (typically 8–16 elements), we use a dense array representation (a simple vector of key-value pairs or elements), avoiding the overhead of CHAMP. A lookup in a dense array is O(n) but with a small constant, making it faster than trie navigation for small collections. For vectors, leaf nodes in the RRB-tree are capped at a maximum branching factor (typically 32 elements). A vector with fewer than 32 elements is represented as a single leaf node, avoiding unnecessary trie levels. For sequences, we cache the head and tail of a sequence node, avoiding repeated thunk forcing for common access patterns.

These optimizations are transparent to the user. Generic algorithms that work with the trait interface automatically benefit from the optimized representations without modification.

### 5.6 Transient (Mutable Builder) Operations

Despite the benefits of persistence, building a large collection incrementally through persistent updates can be inefficient. Appending 1000 elements to a vector through persistent `update` calls would create 1000 intermediate vectors, each with distinct root nodes.

Transient builders address this by allowing temporary mutability within a controlled scope. A transient is a mutable variant of a persistent collection that can be modified in place. Once all updates are complete, the transient is "frozen" into an immutable persistent collection. The type system ensures that a transient cannot escape its defining scope, preventing mutations from affecting shared data.

```prologos
trait Transient (C : Type -> Type)
  transient : C A -> Transient-C A
  freeze : Transient-C A -> C A

defn build-vec [n : Nat] : Vec Nat =
  let tr = transient (@[] : Vec Nat) in
  let _unit = for i in 0..(n - 1) do
    transient-push! tr i
  freeze tr
```

In the Racket prototype, transient operations are implemented using mutable vectors:

```racket
(define (vec-transient v)
  ;; Create a mutable copy of the underlying array
  (vector-copy (rrb-to-vector v)))

(define (vec-transient-push! tr val)
  ;; Append to mutable vector
  (vector-append! tr val))

(define (vec-freeze tr)
  ;; Convert back to persistent RRB-Tree representation
  (vector-to-rrb tr))
```

The type system ensures that a transient is used linearly (exactly once), and the `freeze` operation returns the final persistent collection. Within the transient scope, mutations are safe and efficient.

---

## 6. Layer 3: Explicit Variant Types

### 6.1 SortedMap and SortedSet (Persistent B+ Tree)

When the order of keys or elements matters, `SortedMap` and `SortedSet` provide an alternative to the unordered `Map` and `Set`. These types maintain their elements in sorted order according to a provided comparison function, enabling operations like range queries and ordered iteration.

The implementation uses a persistent B+ tree, a variant of the B-tree where all data is stored in leaf nodes and internal nodes contain only keys for routing. A B+ tree with branching factor `b` maintains the invariant that every node has between `b/2` and `b` children, ensuring that the tree height is logarithmic in the number of elements.

```racket
(struct btree-node (keys children leaf?) #:transparent)

(define (btree-lookup tree key cmp)
  (define (loop node)
    (if (btree-node-leaf? node)
        ;; Leaf node: search within entries
        (let ([idx (find-position key (btree-node-keys node) cmp)])
          (if (and (>= idx 0)
                   (equal? (car (vector-ref (btree-node-keys node) idx)) key))
              (some (cdr (vector-ref (btree-node-keys node) idx)))
              (none)))
        ;; Internal node: binary search and recurse
        (let ([idx (binary-search key (btree-node-keys node) cmp)])
          (loop (vector-ref (btree-node-children node) idx)))))
  (loop tree))
```

Operations include range queries (`range : SortedMap K V → K → K → Seq (K × V)`), in-order iteration, and predecessor/successor lookups, all in O(log₃₂ n). The `Seqable` instance for `SortedMap` produces elements in sorted order:

```prologos
instance Seqable (SortedMap K) where
  to-seq m = btree-inorder-seq m
```

### 6.2 Deque (Finger Tree)

A deque supports O(1) amortized operations at both ends via a monoid-annotated Finger Tree (Hinze-Paterson). A Finger Tree maintains a "finger" on the front and back of the tree, allowing O(1) operations at the extremities:

```prologos
defn-enum FingerTree (A : Type)
  | ft-empty : FingerTree A
  | ft-single : A -> FingerTree A
  | ft-deep : Digit A -> FingerTree (Node A) -> Digit A -> FingerTree A

defn-enum Digit (A : Type)
  | d1 : A -> Digit A
  | d2 : A -> A -> Digit A
  | d3 : A -> A -> A -> Digit A
  | d4 : A -> A -> A -> A -> Digit A
```

| Operation | Complexity |
|-----------|-----------|
| push-front / push-back | O(1) amortized |
| pop-front / pop-back | O(1) amortized |
| index | O(log n) |
| concat | O(log(min(n, m))) |

The monoid parameter enables reuse: Size monoid → indexed sequence, Priority monoid → priority queue, Key monoid → ordered sequence.

### 6.3 PriorityQueue (Pairing Heap)

A priority queue using Pairing Heaps, suitable for propagator activation scheduling:

```racket
(struct pairing-heap (value children) #:transparent)
(define pairing-heap-empty null)

(define (pairing-heap-merge h1 h2 cmp)
  (cond
    [(null? h1) h2]
    [(null? h2) h1]
    [else
     (if (<= (cmp (pairing-heap-value h1) (pairing-heap-value h2)) 0)
         (pairing-heap (pairing-heap-value h1)
                       (cons h2 (pairing-heap-children h1)))
         (pairing-heap (pairing-heap-value h2)
                       (cons h1 (pairing-heap-children h2))))]))
```

| Operation | Complexity |
|-----------|-----------|
| insert | O(1) |
| find-min | O(1) |
| delete-min | O(log n) amortized |
| merge | O(1) |

### 6.4 ConcurrentMap (Ctrie)

A lock-free concurrent hash trie (Prokopec et al.) supporting O(1) snapshots. A Ctrie is similar to a CHAMP but designed for concurrent access via atomic compare-and-swap (CAS) operations. Snapshots simply clone the root I-Node reference; mutations after snapshot create new I-Nodes, leaving the snapshot view untouched (GCAS technique).

In the Racket prototype, concurrent maps are implemented via Racket's `place` mechanism for true parallelism. The design is included for completeness and for future multi-threaded implementations.

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| lookup | O(log n) | Lock-free. |
| insert | O(log n) | Lock-free, CAS loop. |
| snapshot | O(1) | Copy root reference. |

### 6.5 SymbolTable (Adaptive Radix Tree)

An ART (Adaptive Radix Tree) with adaptive node sizes: Node4, Node16, Node48, Node256. All operations are O(k) where k = key length. Used for symbol interning during compilation and for storing compiler intermediate representations and variable bindings.

### 6.6 UnionFind (Persistent Disjoint Sets)

A persistent union-find (Conchon & Filliâtre) with backtracking support. Uses path splitting to maintain balance without destructive path compression. Critical for type unification during elaboration.

```racket
(struct uf-node (parent rank) #:transparent)

(define (uf-find node)
  (if (= (uf-node-parent node) (object-id node))
      node
      (let ([root (uf-find (uf-node-parent node))])
        (uf-node (uf-node-parent root) (uf-node-rank node)))))

(define (uf-union node1 node2)
  (let ([root1 (uf-find node1)]
        [root2 (uf-find node2)])
    (cond
      [(equal? root1 root2) node1]
      [(<= (uf-node-rank root1) (uf-node-rank root2))
       (uf-node root2 (if (= (uf-node-rank root1) (uf-node-rank root2))
                          (+ (uf-node-rank root2) 1)
                          (uf-node-rank root2)))]
      [else (uf-node root1 (uf-node-rank root1))])))
```

| Operation | Complexity |
|-----------|-----------|
| find | O(log n) |
| union | O(log n) |
| backtrack | O(k) where k = operations to undo |

---

## 7. Seq as Universal Abstraction

### 7.1 The Seq-Centric Model

The foundational insight of the Prologos architecture is that `Seq ~[]` should not be merely one collection type among many, but rather the *universal abstraction* through which all collections expose their contents. This inversion of perspective—placing sequences at the center rather than the periphery—resolves fundamental design tensions and enables a system that is simultaneously simple for beginners and powerful for experts.

The traditional approach to collection design uses iteration or traversal as the abstraction. A language provides an `Iterator` interface that all collections implement, and generic algorithms consume iterators. This approach works but has several drawbacks. First, iterators expose imperative mutation (stateful traversal), forcing algorithms to reason about iterator state and position. Second, iterators implicitly assume bounded collections; extending iterators to lazy, potentially infinite sequences requires additional abstractions. Third, the type signature of an iterator is complex—it must track lifetime parameters (for borrowed data) or allocate closure environments for continuation.

The functional approach uses higher-order functions: `fold`, `map`, and other recursive operations. But this approach also has drawbacks. Each operation is a separate function, and combining operations (e.g., "map then filter") requires either explicit composition or automatic fusion.

The sequence-centric approach unifies these perspectives. A `Seq` is a lazy cons cell, the simplest possible persistent data structure. Every collection can be converted to a `Seq` using `to-seq`, and every `Seq` can be materialized into a collection using `from-seq`. This enables seamless composition: you can convert a `Vec` to a `Seq`, apply lazy transformations, and convert back to a `Vec`, all while the type system tracks that the result is a `Vec`.

The benefits are substantial. First, beginners can learn a single composition pattern: "convert to sequence, transform, convert back". No need to learn multiple operation names or understand variance in type parameters. Second, experts can implement custom collections and automatically inherit a rich set of operations (map, filter, fold, take, drop, zip, etc.) by implementing just two methods: `to-seq` and `from-seq`. Third, the abstraction naturally accommodates infinite sequences and lazy evaluation without complicating the core design.

### 7.2 Seqable — Producing Sequences

The `Seqable` trait is the gateway from concrete collections to lazy sequences. Any type implementing `Seqable` commits to providing a single method:

```prologos
trait Seqable (C : Type -> Type)
  to-seq : C A -> Seq A
```

This method is the *only* requirement for a collection to participate in generic algorithms. A collection need not be indexed (no `nth`), need not be keyed (no `get`), need not be set-like (no `member?`). If it is `Seqable`, it can be mapped, filtered, folded, counted, and iterated over.

The contract is that `to-seq` produces a sequence of all elements in the collection, in some order (which may be unspecified for unordered collections like `Set` and `Map`). The sequence is finite for finite collections, though this is not enforced by the type system.

In the Racket prototype, `to-seq` is implemented as a generic procedure that dispatches on the collection type:

```racket
(define (to-seq c)
  (cond
    [(pvec? c) (vec-to-seq c)]
    [(pmap? c) (map-to-seq c)]
    [(pset? c) (set-to-seq c)]
    [(plist? c) (list-to-seq c)]
    [(seq? c) c]
    [else (error "Type does not implement Seqable")]))

(define (vec-to-seq v)
  (let ([len (pvec-length v)])
    (let loop ([i 0])
      (if (< i len)
          (seq-cons (pvec-nth v i) (lambda () (loop (+ i 1))))
          seq-empty))))

(define (list-to-seq lst)
  (if (null? lst)
      seq-empty
      (seq-cons (car lst) (lambda () (list-to-seq (cdr lst))))))
```

### 7.3 Buildable — Materializing Collections

The `Buildable` trait is the counterpart to `Seqable`, allowing sequences to be materialized back into concrete collections:

```prologos
trait Buildable (C : Type -> Type)
  from-seq : Seq A -> C A
  empty : C A
```

The `from-seq` method takes a sequence and produces a collection of type `C A`. For most collections, `from-seq` is straightforward: consume the sequence and insert each element into the collection. For indexed collections like `Vec`, the elements are inserted in order. For unordered collections like `Set`, the order is irrelevant.

```racket
(define (vec-from-seq s)
  ;; Consume sequence and build RRB-tree via transient
  (let loop ([s s] [acc (transient-vec)])
    (if (void? s)
        (freeze-vec acc)
        (begin
          (transient-vec-push! acc (seq-cons-cell-head s))
          (loop (seq-force s) acc)))))

(define (map-from-seq s)
  ;; Consume sequence of (k . v) pairs and build CHAMP
  (let loop ([s s] [m (champ-empty)])
    (if (void? s)
        m
        (let ([kv (seq-cons-cell-head s)])
          (loop (seq-force s)
                (champ-insert m (car kv) (cdr kv)))))))
```

A subtle point: `from-seq` must be *consistent* with `to-seq`. That is, `(from-seq (to-seq c))` should be equal to `c` (up to potential differences in structural sharing). This invariant ensures that round-tripping through sequences is lossless.

### 7.4 Type-Preserving Operations (Vec in → Vec out)

The power of combining `Seqable` and `Buildable` is the ability to write generic, type-preserving operations. Consider the `map` function:

```prologos
defn map [f : A -> B, c : C A] : C B where (Seqable C, Buildable C) =
  from-seq (seq-map f (to-seq c))
```

This function has a remarkable property: the type of the result is `C B`, the same collection type as the input. If you call `map` on a `Vec`, you get a `Vec` back. If you call it on a `List`, you get a `List` back. If you call it on a `Set`, you get a `Set` back. This is achieved without any type-level programming, pattern matching on types, or runtime type tags.

This design pattern extends to many operations:

```prologos
defn filter [p : A -> Bool, c : C A] : C A where (Seqable C, Buildable C) =
  from-seq (seq-filter p (to-seq c))

defn take [n : Nat, c : C A] : C A where (Seqable C, Buildable C) =
  from-seq (seq-take n (to-seq c))

defn append [c1 : C A, c2 : C A] : C A where (Seqable C, Buildable C) =
  from-seq (seq-append (to-seq c1) (to-seq c2))
```

### 7.5 Orthogonal Specialized Traits (Indexed, Keyed, Setlike)

While `Seqable` and `Buildable` provide a universal protocol for collection access, not all collections support all operations efficiently. To accommodate these differences without forcing all collections into a least-common-denominator interface, Prologos provides *orthogonal specialized traits*. These traits are not in a hierarchy; a collection can implement any subset of them.

The `Indexed` trait provides operations for ordered, indexable collections:

```prologos
trait Indexed (C : Type -> Type)
  nth : C A -> Nat -> Option A
  length : C A -> Nat
  update : C A -> Nat -> A -> C A
```

The `Keyed` trait provides operations for key-value mappings:

```prologos
trait Keyed (C : Type -> Type -> Type)
  get : C K V -> K -> Option V
  assoc : C K V -> K -> V -> C K V
  dissoc : C K V -> K -> C K V
  keys : C K V -> Seq K
  vals : C K V -> Seq V
```

The `Setlike` trait provides operations for membership testing:

```prologos
trait Setlike (C : Type -> Type)
  member? : C A -> A -> Bool
  insert : C A -> A -> C A
  remove : C A -> A -> C A
```

A generic algorithm that requires indexed access declares its constraint explicitly:

```prologos
defn reverse [c : C A] : C A where (Indexed C, Seqable C, Buildable C) =
  let len = length c in
  from-seq (seq-reverse-with-length len (to-seq c))
```

This separation of concerns ensures that algorithms are written at the most general level possible, without forcing unnecessary constraints. An algorithm that only needs to count elements requires only `Seqable`. An algorithm that needs indexed access requires `Indexed`. An algorithm that needs a total order requires an `Ord` constraint.

### 7.6 Seq Operations Replace Iteration

In Prologos, `Seq` replaces iteration entirely. The fundamental operations on sequences are:

```prologos
defn seq-head [s : Seq A] : Option A = ...
defn seq-tail [s : Seq A] : Option (Seq A) = ...
defn seq-empty? [s : Seq A] : Bool = ...

defn seq-cons [x : A, s : Seq A] : Seq A = ...
defn seq-append [s1 : Seq A, s2 : Seq A] : Seq A = ...

defn seq-map [f : A -> B, s : Seq A] : Seq B = ...
defn seq-filter [p : A -> Bool, s : Seq A] : Seq A = ...
defn seq-take [n : Nat, s : Seq A] : Seq A = ...
defn seq-drop [n : Nat, s : Seq A] : Seq A = ...
defn seq-zip [s1 : Seq A, s2 : Seq B] : Seq (A × B) = ...

defn seq-fold [f : B -> A -> B, z : B, s : Seq A] : B = ...
defn seq-count [s : Seq A] : Nat = ...
defn seq-any? [p : A -> Bool, s : Seq A] : Bool = ...
defn seq-all? [p : A -> Bool, s : Seq A] : Bool = ...
```

These operations are sufficient to express any sequential algorithm. They are lazy when possible (map, filter, take, drop, zip all return sequences without consuming their inputs), but can be made eager by demanding a result (fold, count, any?, all? all force evaluation).

The advantage over iterators is that sequences are values, not mutable state. There is no "current position" or "has next" state to manage. Instead, a sequence is either empty or a cons cell with a head and a thunk for the tail. Processing a sequence is pattern matching and recursion, not state mutation.

Multiple operations can be chained without creating intermediate collections:

```prologos
@[1 2 3 4 5]
  |> to-seq
  |> seq-filter (fun x -> x > 2)
  |> seq-map (fun x -> x * 2)
  |> from-seq
  -- => @[6 8 10]
```

### 7.7 Graduated Complexity (Beginners → Experts)

The final aspect of the Seq-centric model is its accommodation of learners at every level. Beginners need not understand traits, specialization, or constraint resolution. They can simply learn the collection API: `@[...]` for vectors, `{...}` for maps, `#{...}` for sets, and a few operations like `map`, `filter`, and `fold`.

Intermediate learners can explore the trait system, understanding that `map` works on any `Seqable` type and that specialized traits like `Indexed` provide efficient access for certain operations. They might write generic functions that preserve collection type:

```prologos
defn double-elements [c : C Nat] : C Nat where (Seqable C, Buildable C) =
  map (fun x -> 2 * x) c
```

Advanced learners can reason about laws and specialization. They might ask: "Does this operation preserve order? Does it preserve element multiplicity (for multisets)? Does it respect the lattice structure for constraint propagation?" They can write specialized implementations for particular types and rely on the compiler to inline and optimize them. They might explore type-level programming, using dependent types to capture invariants:

```prologos
defn indexed-filter [c : C A, p : A -> Bool] : Vec { x : A | p x }
  where (Indexed C, Seqable C, Buildable Vec) = ...
```

The design ensures that complexity is not imposed on beginners. A novice programmer can write `map inc @[1 2 3]` without understanding traits or type specialization. The same infrastructure that makes this work also supports advanced type-level reasoning by those who need it.

---

## 8. Lattice-Compatible Collections and Propagator Integration

In systems with nondeterminism and constraint solving, collections themselves become computational objects that must participate in search semantics. The Seq-centric model integrates naturally with lattice-theoretic structures where collections grow monotonically toward fixed points. This section explores how Prologos collections interact with logical variables (LVars), propagators, and the constraint resolution engine described in the type system documentation.

### 8.1 LVar Semantics and Monotonic Data Structures

Logical variables in Prologos differ fundamentally from mutable references in imperative languages. An LVar represents a single value that is refined through unification and constraint propagation. Once a variable is bound, it cannot be reassigned to a different value; however, the *term* it is bound to can grow—this is the foundation of monotonic data structure semantics.

When a Seq itself becomes a value in a logical variable, refinement proceeds through growth in the lattice of finite partial Seqs. The unification algorithm operates on both the spine of the Seq (its structural shape) and the contents of elements, allowing constraints like "the tail of this Seq must unify with another Seq" to drive computation.

The lattice order `⊑` on Seqs is defined constructively: a Seq S₁ ⊑ S₂ if S₁ is a prefix of S₂, or if elements at each position are related by their own ⊑ relations. This connects directly to the dependent type system: a `Seq (LVar A)` represents a growing sequence of logical variables, each of which refines independently toward its solution. A `LVar (Seq A)` represents a single variable holding a Seq that grows in length or element precision.

The semantics of `to-seq` on LVar-containing structures demands careful handling. When calling `(to-seq (make-lvar))`, the operation either succeeds immediately if the LVar is already bound to a Seqable structure, or it blocks the current propagation step, registering a constraint dependency. This is distinct from eager evaluation: the propagator network determines when growth can proceed.

### 8.2 LVar Map — Monotonic Associative Containers

A `LVar-Map` is a persistent map where keys are fixed but values are logical variables that refine over time. This structure is fundamental for constraint satisfaction problems where attributes of entities are gradually resolved. The implementation combines a CHAMP hash structure with per-entry constraint cells.

```racket
(struct lvar-map (champ-root constraints) #:transparent)

(define (lvar-map-get lm key)
  (match (hash-ref (lvar-map-champ-root lm) key #f)
    [#f (error "key not found")]
    [val val]))

(define (lvar-map-put lm key val)
  (let* ([old-root (lvar-map-champ-root lm)]
         [new-root (hash-set old-root key val)]
         [old-constraints (lvar-map-constraints lm)]
         [new-constraints (cons (cons key val) old-constraints)])
    (lvar-map new-root new-constraints)))

(define (lvar-map-unify lm1 lm2)
  (let loop-keys ([keys (hash-keys (lvar-map-champ-root lm1))]
                  [acc lm1])
    (if (null? keys)
        acc
        (let* ([key (car keys)]
               [v1 (lvar-map-get acc key)]
               [v2 (hash-ref (lvar-map-champ-root lm2) key #f)])
          (if v2
              (let ([unified (unify-terms v1 v2)])
                (if unified
                    (loop-keys (cdr keys) (lvar-map-put acc key unified))
                    #f))
              (loop-keys (cdr keys) acc))))))
```

The `lvar-map-unify` operation ensures that when two LVar-Maps are unified in the search space, their keys must have compatible bindings. If a key exists in both maps, the values must unify; if a key exists only in one map, the unified result includes it. This monotonic semantics ensures that once a key-value pair is in the map, it cannot be removed or contradicted—only refined.

### 8.3 LVar Set — Growing Sets with Threshold Reads

A `LVar-Set` represents a set whose membership is gradually determined through constraint solving. Unlike eager sets that require all elements upfront, a LVar-Set can grow as constraints narrow the solution space. The structure supports two operations beyond standard set operations: *threshold reads* and *must-exclude assertions*.

A threshold read on a LVar-Set succeeds only when the set has grown to a certain size or when specific elements have been confirmed. This is useful for problems where computation should proceed once a critical invariant is satisfied. A must-exclude assertion adds a constraint that certain elements cannot enter the set, helping prune the search space.

```racket
(struct lvar-set (cardinality-lvar elements constraints) #:transparent)

(define (lvar-set-add ls elem)
  (let* ([new-elems (set-add (lvar-set-elements ls) elem)]
         [new-constraints (cons `(add ,elem) (lvar-set-constraints ls))])
    (lvar-set (lvar-set-cardinality-lvar ls) new-elems new-constraints)))

(define (lvar-set-must-exclude ls elem)
  (let ([new-constraints (cons `(exclude ,elem) (lvar-set-constraints ls))])
    (lvar-set (lvar-set-cardinality-lvar ls) (lvar-set-elements ls) new-constraints)))

(define (lvar-set-freeze ls)
  ;; Once frozen, the set cannot grow further
  ;; All threshold constraints are checked
  (let ([final-size (length (lvar-set-elements ls))])
    (if (positive? final-size)
        (set-map (lvar-set-elements ls) (λ (x) x))
        #f)))
```

The threshold mechanism integrates with the propagator network: a constraint like "wait until size ≥ 5" registers a propagator that wakes when the cardinality LVar is updated. This allows lazy computation and early pruning of infeasible branches.

### 8.4 Propagator Cell Architecture

A propagator cell is a container for a value undergoing constraint refinement. It encapsulates a mutable reference to the current value, a network of dependent propagators, and metadata about the constraint domain. The cell architecture allows multiple propagators to observe and update the same value without explicit threading of state.

```racket
(struct prop-cell (value domain propagators) #:transparent #:mutable)

(define (make-prop-cell initial-value domain)
  (prop-cell initial-value domain (make-hash)))

(define (prop-cell-update cell new-value)
  (let ([old-value (prop-cell-value cell)]
        [dom (prop-cell-domain cell)])
    (match (domain-merge dom old-value new-value)
      [#f (error "merge failed: inconsistent domains")]
      [merged-val
       (begin
         (set-prop-cell-value! cell merged-val)
         (for-each (λ (prop) (propagator-wake prop))
                   (hash-values (prop-cell-propagators cell))))])))
```

The domain parameter specifies how values in the cell merge. For Seqs, the domain is the lattice of partial Seqs with `⊑` as the order and `⊔` as the join. For LVar-Maps, the domain merges key-value bindings. When a new value enters the cell, the domain-specific merge function computes the refined value, and all dependent propagators are awakened to propagate consequences.

### 8.5 CRDT-Inspired Structures for Distributed Actors

When collections are shared across Prologos actors (via session types or asynchronous channels), they must tolerate concurrent modification and eventual consistency. CRDT (Conflict-free Replicated Data Type) principles ensure that commutative updates converge to a single state regardless of order.

The Seq lattice naturally supports CRDT semantics when augmented with vector clocks or timestamps. An operation like `(seq-append elem)` is tagged with the actor's logical clock, ensuring that replicas compute the same total order on elements.

```racket
(struct crdt-seq (logical-clock entries) #:transparent)

(define (crdt-seq-append seq elem timestamp)
  (let* ([new-clock (max (crdt-seq-logical-clock seq) (+ timestamp 1))]
         [new-entries (cons `(,timestamp . ,elem) (crdt-seq-entries seq))])
    (crdt-seq new-clock new-entries)))

(define (crdt-seq-merge seq1 seq2)
  ;; Merge two replicas by combining entries and choosing total order
  (let* ([entries1 (crdt-seq-entries seq1)]
         [entries2 (crdt-seq-entries seq2)]
         [all-entries (sort (append entries1 entries2)
                            (λ (a b) (< (car a) (car b))))]
         [max-clock (max (crdt-seq-logical-clock seq1)
                         (crdt-seq-logical-clock seq2))])
    (crdt-seq max-clock all-entries)))
```

### 8.6 Merge Functions and Conflict Resolution

The polymorphic merge operation is the heart of monotonic semantics. A merge function for a domain specifies how two refinements of the same value combine. The merge must be associative, commutative, and idempotent (a semilattice structure) to guarantee convergence in constraint networks.

For primitive domains like integers with an inequality constraint, merge is the greatest lower bound (for constraints) or least upper bound (for refinements toward a solution). For composite domains like Seqs, merge recursively applies to both structure and elements. For LVar-Maps, merge pointwise merges values at each key.

```racket
(define ((merge-semilattice dom) val1 val2)
  (match dom
    [`(seq ,elem-dom)
     (if (and (list? val1) (list? val2))
         (let ([len1 (length val1)] [len2 (length val2)])
           (if (= len1 len2)
               (map (merge-semilattice elem-dom) val1 val2)
               (error "seq length mismatch")))
         (error "expected lists"))]
    [`(map ,_key-dom ,val-dom)
     (if (and (hash? val1) (hash? val2))
         (let* ([keys1 (hash-keys val1)]
                [keys2 (hash-keys val2)]
                [all-keys (set-union (list->set keys1) (list->set keys2))])
           (foldl (λ (k acc)
                    (let ([v1 (hash-ref val1 k #f)]
                          [v2 (hash-ref val2 k #f)])
                      (hash-set acc k
                        (cond
                          [(and v1 v2) ((merge-semilattice val-dom) v1 v2)]
                          [v1 v1]
                          [v2 v2]))))
                  (make-hash)
                  all-keys))
         (error "expected hashes"))]
    [`(lvar-set)
     (set-union val1 val2)]
    [_ (if (equal? val1 val2) val1 #f)]))
```

When a merge fails—returning `#f` because values are incompatible—the search branch backtracks. This ensures that the constraint network remains consistent.

---

## 9. Dependent Types over Collections

The full power of dependent typing emerges when collection types depend on properties of elements and structural properties like length. A vector type `(Vec n A)` is a collection of type `A` with statically known length `n`. Operations on such vectors produce results whose types are computed from the input types and proven properties.

### 9.1 Length-Indexed Vectors (Vec n A)

A length-indexed vector `(Vec n A)` is a collection of elements of type `A` whose length is *n*, where *n* is a type-level natural number. The type is fully type-safe: operations that concatenate vectors produce a vector whose length type is the sum of the input lengths; operations that drop elements produce appropriately shortened types.

```prologos
data Vec : Nat -> Type -> Type
  nil : Vec 0 A
  cons : (x : A) -> (xs : Vec n A) -> Vec (n + 1) A

type Fin : Nat -> Type
  zero : Fin (n + 1)
  succ : (i : Fin n) -> Fin (n + 1)

lookup : (v : Vec n A) -> (i : Fin n) -> A
lookup (cons x _xs) zero = x
lookup (cons _x xs) (succ i) = lookup xs i
```

No `None` is needed; the type guarantees the index is valid.

**Concatenation with proofs:**

```prologos
concat : (v1 : Vec m A) -> (v2 : Vec n A) -> Vec (m + n) A
concat nil v2 = v2
concat (cons x xs) v2 = cons x (concat xs v2)
```

Operations preserve types: `(map inc @[1 2 3])` returns `@[2 3 4]` with the same vector type `Vec 3 Int`. This type preservation relies on the mapping function returning elements of the same type, and the Seq structure itself remaining unchanged in length.

### 9.2 Bounded Collections and Refinement Types

Beyond length, collections can be refined by predicates expressing properties of elements. A refinement type `{Seq A | P}` is a Seq of type `A` satisfying predicate `P`. Common refinements include sortedness, element bounds, and uniqueness (for sets).

```prologos
defn sorted-merge [s1 : {Seq A | sorted}, s2 : {Seq A | sorted}]
  : {Seq A | sorted} =
  match (s1, s2) with
  | (seq-empty, _s) => s2
  | (_s, seq-empty) => s1
  | (seq-cons h1 t1, seq-cons h2 t2) =>
    if h1 <= h2
    then seq-cons h1 (sorted-merge (t1 ()) s2)
    else seq-cons h2 (sorted-merge s1 (t2 ()))
```

Intersection of refinements is straightforward: a Seq satisfying both `sorted` and `unique` has the intersection refinement type. This compositional approach keeps the type system modular.

### 9.3 Proof-Carrying Operations

Operations that guarantee refinements must carry proofs that the result satisfies the required predicate. A proof in Prologos's dependent type system is a type-theoretic term that the elaborator can check against the required type.

```prologos
sorted-vec-append :
  (v1 : Vec m A) -> (0.proof1 : sorted v1) ->
  (v2 : Vec n A) -> (0.proof2 : sorted v2) ->
  (0.proof-disjoint : (∀ x y, x ∈ v1 → y ∈ v2 → x ≤ y)) ->
  {Vec (m + n) A | sorted}
```

The proof arguments `proof1`, `proof2`, and `proof-disjoint` are marked with multiplicity 0—they are evidence used only during type checking and erased at runtime.

### 9.4 Erasure Strategy: Zero-Cost Proofs via QTT

The Quantitative Type Theory (QTT) framework built into Prologos allows proof terms and type-level computation to be erased at runtime, resulting in zero-cost abstractions. A variable appearing in a type only (not in a computational term) is marked with usage 0, and the elaborator erases it during code generation.

For the sorted-append example above, the proof arguments are used only in type positions. The elaborator verifies correctness at compile time; the generated Racket code becomes:

```racket
(define (sorted-vec-append-erased v1 v2)
  (match (cons v1 v2)
    [(cons '() v2) v2]
    [(cons (cons x tl) v2)
     (cons x (sorted-vec-append-erased tl v2))]))
```

This erasure is sound because the elaborator has already verified at compile time that the refinements hold. The runtime code is identical to a straightforward concatenation, but with the static guarantee that the result remains sorted.

The QTT system tracks usage quantifiers: `0` for erasable, `1` for linear, `ω` for unrestricted. For collection operations, most type-level properties are marked `0`, enabling aggressive erasure.

### 9.5 Pattern Matching and Narrowing over Collections

Pattern matching in Prologos automatically narrows dependent types. When matching a vector of type `(Vec n A)` against `(cons x tl)`, the type of `tl` is automatically refined to `Vec (n - 1) A`. Similarly, matching against `nil` narrows `n` to `0`.

```prologos
vec-split-at : (v : Vec n A) -> (k : Nat) -> (0._proof : k ≤ n) ->
  (Vec k A) × (Vec (n - k) A)
vec-split-at _v 0 _proof = (nil, _v)
vec-split-at (cons x xs) (succ k') _proof =
  let (left, right) = vec-split-at xs k' _proof' in
  (cons x left, right)
```

The elaborator uses type narrowing to verify pattern coverage. If a pattern match does not cover all type-theoretically possible cases, or if a case is unreachable given the refined type, the elaborator reports this. This prevents runtime errors from incomplete pattern matching over dependent types.

---

## 10. Racket Prototype Implementation Strategy

The Prologos prototype in Racket provides a functional foundation for the core language before optimization passes and specialized backends are added. The architecture emphasizes modularity, testability, and integration with Racket's metaprogramming infrastructure.

### 10.1 Module Architecture and Organization

The `/mnt/prologos/racket/prologos/` directory is organized into layers, each with clear responsibilities and minimal coupling.

**Parsing and AST:** `reader.rkt` implements the Prologos reader (extending Racket's `#lang` mechanism) to parse Prologos source into S-expressions. `parser.rkt` transforms S-expressions into an abstract syntax tree (AST) representation. `sexp.rkt` contains utilities for working with symbolic expressions, including hygienic macro expansion.

**Type System:** `typing-core.rkt` defines the core type language, including base types (`Int`, `Bool`, `Str`), composite types (`Vec`, `Seq`, `Map`), and dependent types. `qtt.rkt` implements Quantitative Type Theory, tracking usage quantifiers and enabling erasure of zero-cost proofs. `unify.rkt` provides the unification algorithm for constraint solving and type inference.

**Elaboration and Code Generation:** `elaborator.rkt` transforms the parsed AST into a fully type-checked intermediate representation, performing constraint resolution and proof verification. `zonk.rkt` implements the zonking pass that normalizes types and substitutes resolved type variables.

**Runtime and Collections:** The new `collections.rkt` module implements the Seq-centric collection system, including the persistent data structures (CHAMP, RRB-Tree) and the generic dispatch mechanism. `prelude.rkt` defines standard functions and types, including arithmetic, comparison, list operations, and common predicates.

**Actor and Concurrency:** `processes.rkt` defines the actor model and message passing. `sessions.rkt` implements session types for safe channel-based communication.

**REPL and Interaction:** `main.rkt` serves as the entry point, initializing the language environment and loading the prelude. `repl.rkt` implements the read-eval-print loop with support for interactive refinement and constraint checking.

### 10.2 Struct-Based Node Representation

Persistent data structures in Racket are implemented using transparent structs, chosen for their performance characteristics and seamless interoperation with the type system.

For RRB-Trees (used in vectors):

```racket
(struct rrb-node (count array) #:transparent)
(struct rrb-branch (count children) #:transparent)

(define (rrb-node-ref node idx)
  (if (< idx (rrb-node-count node))
      (vector-ref (rrb-node-array node) idx)
      #f))

(define (rrb-node-set node idx val)
  (let ([new-array (vector-copy (rrb-node-array node))])
    (vector-set! new-array idx val)
    (rrb-node (rrb-node-count node) new-array)))
```

For CHAMP hash tables:

```racket
(struct champ-node (bitmap array size) #:transparent)

(define (champ-node-ref node hash shift)
  (let* ([bit-pos (bitwise-and (arithmetic-shift hash (- shift)) #x1f)]
         [idx (popcount (bitwise-and (champ-node-bitmap node)
                                     (sub1 (arithmetic-shift 1 bit-pos))))])
    (if (bitwise-bit-set? (champ-node-bitmap node) bit-pos)
        (vector-ref (champ-node-array node) idx)
        #f)))
```

### 10.3 Generic Dispatch via Racket Generics

Racket's generic interface mechanism (`racket/generic`) provides a clean way to define polymorphic operations without introducing a rigid type hierarchy:

```racket
(require racket/generic)

(define-generics seqable
  (to-seq seqable)
  #:fast-defaults
  ([list?
    (define (to-seq lst) (lazy-seq-from-list lst))]
   [vector?
    (define (to-seq vec) (lazy-seq-from-vector vec))]))

(define-generics buildable
  (from-seq buildable seq)
  (collection-empty buildable)
  #:fast-defaults
  ([list?
    (define (from-seq _ seq) (seq->list seq))
    (define (collection-empty _) '())]
   [vector?
    (define (from-seq _ seq) (seq->vector seq))
    (define (collection-empty _) (vector))]))

(define-generics indexed
  (coll-get indexed idx)
  (coll-set indexed idx val))

(define-generics keyed
  (coll-get-key keyed key)
  (coll-set-key keyed key val)
  (coll-has-key? keyed key))
```

These generics are automatically dispatched: when `to-seq` is called on a Prologos collection, the elaborator invokes the Seqable method. The `#:fast-defaults` clause allows direct dispatch to Racket built-ins without wrapper overhead.

### 10.4 Integration with Existing Prototype

The collection system integrates with the existing type checker and elaborator. When a collection literal like `@[1 2 3]` appears in the source, the reader parses it as a special form. The elaborator infers the type `Vec 3 Int` based on element types and syntactic length, then generates code that constructs a persistent vector.

```racket
;; In elaborator.rkt
(define (elaborate-vec-literal elements env)
  (let* ([elems-elaborated (map (λ (e) (elaborate e env)) elements)]
         [elem-types (map (λ (ed) (elab-result-type ed)) elems-elaborated)]
         [unified-type (unify-types elem-types)])
    (if unified-type
        (elab-result
          `(pvec-from-list
            (list ,@(map elab-result-term elems-elaborated)))
          `(Vec ,(length elements) ,unified-type))
        (error "vector elements have incompatible types"))))
```

Operations like `map` over collections dispatch through the elaborator to generate specialized code. When `(map inc @[1 2 3])` is elaborated, the type checker verifies that `inc` has type `Int → Int`, then generates code that constructs a new vector of the same length with mapped elements.

### 10.5 Testing Infrastructure

The Racket prototype uses `rackunit` for testing, organized by module:

```racket
(require rackunit "collections.rkt")

(define-test-suite vec-construction
  (test-case "create empty vector"
    (let ([v (pvec-empty)])
      (check-equal? (pvec-size v) 0)))

  (test-case "create vector from list"
    (let ([v (pvec-from-list '(1 2 3 4 5))])
      (check-equal? (pvec-size v) 5)
      (check-equal? (pvec-get v 0) 1)
      (check-equal? (pvec-get v 4) 5)))

  (test-case "persistent update"
    (let* ([v1 (pvec-from-list '(1 2 3))]
           [v2 (pvec-set v1 1 99)])
      (check-equal? (pvec-get v1 1) 2)   ;; Original unchanged
      (check-equal? (pvec-get v2 1) 99)))) ;; New version updated
```

Test suites are organized hierarchically, allowing selective execution during development. Continuous integration runs the full test suite on each commit.

---

## 11. Memory Management in Racket

Racket's memory model differs fundamentally from languages requiring manual resource management. The garbage collector handles object lifetime, but the Prologos language and its collection structures can be optimized through understanding and leveraging Racket's GC behavior, QTT-guided analyses, and mutable transient structures for localized mutation.

### 11.1 Racket's GC Model and Collection Lifetime

Racket uses a generational, concurrent garbage collector with three tiers: the nursery (Gen 0) collects frequently, the intermediate generation (Gen 1) less frequently, and the mature generation (Gen 2) rarely. Objects are promoted through generations as they survive successive collection cycles, with the assumption that long-lived objects require less frequent collection.

For Prologos collections, this model has favorable implications. Persistent data structures like vectors, maps, and seqs are allocated as immutable structs in the nursery. When a structural update occurs (e.g., `(pvec-set v 5 new-val)`), a new struct is created with modified content, and the old struct becomes immediately collectable if no reference remains. The GC quickly reclaims short-lived intermediate structures, keeping memory pressure low.

Shared structure in persistent collections also interacts favorably with GC. When two vectors share a tail due to path copying (as in RRB-trees), only one copy of the shared tail exists in memory. The GC ensures that the shared structure is not reclaimed until all references disappear.

### 11.2 QTT-Guided Optimization Opportunities

Quantitative Type Theory provides static information about variable usage that can guide both memory optimization and code generation. A variable marked with usage 0 does not appear in the computational term and can be erased entirely. A variable with usage 1 appears exactly once and cannot be duplicated; such variables are candidates for linear handling with minimal copying.

Consider a function that processes a large vector once:

```prologos
defn fold-sum [v : 1.Vec Int] : Int =
  fold (+) 0 v
```

The type of `v` has usage 1: it appears exactly once. The elaborator can generate code that passes `v` by reference without copying. For mutable structures used temporarily during computation, QTT can guide when mutable versions are safe—if a buffer has a linear lifetime (created, used once, then converted), it can be allocated in a stack-like manner rather than relying on GC to reclaim it.

### 11.3 Transient Operations via Mutable Structs

For operations that build large structures incrementally, Racket allows temporary use of mutable data structures. A transient vector is a mutable Racket vector that is gradually filled, then converted to a persistent Prologos vector once construction is complete.

```racket
(define (transient-vector-builder)
  (let ([buffer (make-vector 10)]
        [size 0])
    (define (add! elem)
      (when (>= size (vector-length buffer))
        (let ([new-buffer (make-vector (* 2 (vector-length buffer)))])
          (vector-copy! new-buffer 0 buffer)
          (set! buffer new-buffer)))
      (vector-set! buffer size elem)
      (set! size (+ size 1)))

    (define (finalize)
      (pvec-from-vector (vector-copy buffer 0 size)))

    (cons add! finalize)))
```

This pattern avoids repeated allocation of persistent vectors during incremental construction. The mutable buffer is local to the builder closure and never escapes to the Prologos type system, ensuring that type safety is maintained.

### 11.4 Cross-Actor Collection Sharing via Places

Racket's `place` mechanism enables true parallelism by creating isolated processes that communicate via message passing. Collections shared across places must be serialized and deserialized (or use Racket's `place-shared` for carefully managed shared memory).

For Prologos actor systems, CRDT-backed collections (from Section 8.5) are natural choices for cross-place sharing. A CRDT collection can be serialized, sent across the place boundary, merged with the local replica, and sent back, with the property that the final state converges regardless of message order.

```racket
(define (actor-process-with-shared-collection initial-seq)
  (let ([local-seq initial-seq])
    (let loop ()
      (let ([msg (place-channel-get)])
        (match msg
          [`(update ,remote-seq)
           (set! local-seq (crdt-seq-merge local-seq remote-seq))
           (loop)]
          [`(read-all)
           (place-channel-put (crdt-seq-to-seq local-seq))
           (loop)]
          [`(stop) (void)])))))
```

### 11.5 Weak References and Ephemerons

For collections that may hold large values, Racket's weak reference mechanism allows cycles to be broken and objects to be collected even if held by containers. An ephemeron is a weak reference that includes both a key and a value; the value is retained only as long as the key is reachable through normal references.

In Prologos, ephemerons are useful for memoization and cache implementations. Weak references in LVar-Maps prevent long-lived constraint cells from retaining large data structures unnecessarily. Once an LVar is resolved and the solution extracted, weak references to intermediate Seqs used in constraint solving can be reclaimed.

---

## 12. Phased Implementation Plan

The implementation of the Prologos collection system and dependent type support is organized into overlapping phases spanning 30 weeks. Each phase produces a functioning subsystem that is tested and integrated before the next phase begins.

### 12.1 Phase 1: Core Foundation (Weeks 1–6)

**Objective:** Establish the fundamental data structures and Seq-centric model in Racket.

**Weeks 1–2: Seq Abstraction and Lazy Sequences.** Implement `lazy-seq` as a thunk-based constructor. Create `seq-cons`, `seq-empty`, `seq-force`, `seq-rest`. Implement `to-seq` and `from-seq` protocols as generic functions. Write test suite for lazy sequence operations (map, filter, fold). Integration: wire into the elaborator's desugaring pass.

**Weeks 3–4: Persistent Vector (RRB-Tree).** Implement RRB-Tree node structure with shift-based indexing. Build `pvec-get`, `pvec-set`, `pvec-push`, `pvec-pop`. Implement `pvec-from-list`, `pvec-from-seq`, `pvec-to-list`. Create test suite covering indexing, updates, construction. Implement `Seqable` and `Buildable` for vectors. Integration: add `@[...]` literal syntax to reader and parser.

**Weeks 5–6: Persistent Map (CHAMP).** Implement CHAMP node structure with bitmap compression. Build `champ-get`, `champ-set`, `champ-delete`, `champ-has-key?`. Implement `champ-from-list`, `champ-merge` for unification. Create test suite covering all operations. Implement `Keyed` generic for maps. Integration: add `{...}` literal syntax to reader.

**Deliverables:** Lazy Seq, RRB-Tree Vector, CHAMP Map with full test coverage. Language integration for collection literals. Benchmark memory usage and throughput against baseline Racket collections.

### 12.2 Phase 2: Optimized Backends (Weeks 7–14)

**Objective:** Implement specialized structures for common use cases and optimize Seq operations.

**Weeks 7–8: Persistent List and Set.** Implement cons-list as Seqable (leveraging existing Racket infrastructure). Implement hash-based Set with `Setlike` generic. Build set operations: union, intersection, difference. Integration: add `'[...]` and `#{...}` literal syntax.

**Weeks 9–10: Seq Fusion and Lazy Evaluation.** Implement transducers for composable Seq operations. Optimize chains like `(map f (filter p seq))` into single pass. Build test suite comparing fused vs. unfused operations. Integration: update elaborator to detect and fuse Seq operations.

**Weeks 11–12: Mutable Transient Structures.** Implement transient vector builder with mutable buffer. Build transient map builder for efficient incremental construction. Write test suite verifying immutability after finalization. Integration: add `transient!` syntax to language for scoped mutation.

**Weeks 13–14: Memory Layout Optimization.** Profile Racket allocation patterns for collections. Optimize CHAMP bitmaps for modern CPUs. Run performance benchmarks on large collections. Integration: conditional compilation for memory-optimized variants.

**Deliverables:** Set, List, optimized Seq operations, transients, memory-efficient layouts. Full test coverage including performance benchmarks.

### 12.3 Phase 3: Specialized Structures (Weeks 15–22)

**Objective:** Implement lattice-compatible structures, dependent types, and constraint integration.

**Weeks 15–16: LVar and Logical Variables.** Implement `LVar` struct and basic unification. Build constraint accumulation and backtracking. Integration: wire into elaborator's type inference.

**Weeks 17–18: LVar-Map and LVar-Set.** Implement monotonic map semantics with constraints. Build threshold reads and must-exclude assertions. Integration: expose in prelude and type system.

**Weeks 19–20: Propagator Network.** Implement propagator cell with awakening mechanism. Build domain-specific merge functions. Integration: connect to constraint solver in elaborator.

**Weeks 21–22: Length-Indexed Vectors and Dependent Types.** Implement `Vec n A` type with type-level Nats. Build dependent pattern matching with type narrowing. Integration: update elaborator to handle dependent type checking.

**Deliverables:** LVar infrastructure, monotonic structures, propagators, and dependent type support with full test suite.

### 12.4 Phase 4: Integration and Adaptation (Weeks 23–30)

**Objective:** Integrate all components, optimize for Prologos's logical programming model, and prepare for multi-threaded/distributed scenarios.

**Weeks 23–24: QTT Integration and Proof Erasure.** Integrate QTT usage tracking with elaborator. Implement erasure of zero-cost proofs. Benchmark runtime of erased vs. non-erased code. Integration: make erasure default in compilation.

**Weeks 25–26: CRDT-Backed Collections.** Implement CRDT Seq with vector clocks. Build merge and replication logic. Integration: add CRDT variants to type system.

**Weeks 27–28: Actor and Place Integration.** Implement collection serialization for place boundaries. Build cross-place communication patterns. Integration: expose in actor runtime and prelude.

**Weeks 29–30: Comprehensive Testing and Documentation.** Full integration testing of all components. Benchmark suite covering performance-critical paths. Documentation and examples for collection APIs. Final optimization passes and refactoring.

**Deliverables:** Fully integrated collection system with QTT, CRDT, and actor support. Comprehensive test suite with coverage >95%. Documentation and tutorials.

### 12.5 Dependency Graph and Critical Path

The critical path for implementation proceeds as follows. The Seq abstraction (Weeks 1–2) is the base; all other structures depend on it. Vector and Map are implemented in parallel (Weeks 3–6). Fusion and Transients (Weeks 9–12) depend on the Seq abstraction and vectors, enabling efficient operations. LVars (Weeks 15–16) depend on core structures and enable constraint solving. Dependent Types (Weeks 21–22) depend on LVars and type inference, enabling static verification. QTT and Erasure (Weeks 23–24) depend on dependent types, providing the final optimization step.

Parallel work tracks: Weeks 7–8 (Set/List) can proceed independently. Weeks 19–20 (Propagators) can begin once LVars are complete. Weeks 25–26 (CRDTs) can begin once core structures are solid. Weeks 27–28 (Actors) depend on CRDTs and propagators.

### 12.6 Testing Strategy per Phase

Each phase employs a three-tier testing strategy. **Unit Tests** exercise individual functions in isolation using `rackunit` with randomized property tests. **Integration Tests** verify that multiple components work together (e.g., vectors constructed from Seqs and vice versa, type-preserving `map` operations). **Performance Benchmarks** measure throughput and memory usage on standard workloads using Racket's `time` and profiling tools. Continuous integration runs the test suite on every commit and tracks benchmark trends. Any test failure blocks further development; any benchmark regression > 5% triggers investigation.

---

## 13. Key Challenges and Open Problems

The integration of dependent types, constraint solving, and persistent data structures raises fundamental questions about efficiency and usability.

**Type Checking Completeness.** Dependent types are decidable only under certain restrictions (e.g., terminating functions for proofs). Prologos must determine when proof checking halts and when to defer proofs to runtime. The current QTT framework guides erasure but does not automatically prove that proofs are unnecessary; human annotation via usage quantifiers may be required.

**Seq Fusion Optimality.** Composing multiple transducers (map, filter) into a single pass requires fusion rules that preserve semantics. For lazy Seqs, fusion must interact correctly with backtracking and constraint propagation—a single pass cannot explore all branches. The elaborator must detect when fusion is safe (for deterministic operations) and when separate passes are necessary (for nondeterministic operations).

**Memory Scaling.** Prologos's lattice semantics allows collections to grow indefinitely toward fixed points. For large constraint problems, the accumulated Seqs and LVar-Maps can consume significant memory. Periodically "compacting" the constraint state (extracting solutions and discarding intermediate structures) is necessary, but determining when compaction is safe without losing information is an open problem.

**Actor Coherence.** When CRDTs are replicated across actors, the system must ensure that all actors eventually converge. Partial failure scenarios (actor crashes, network partitions) can leave replicas in inconsistent states. Implementing Byzantine-resistant consensus or weaker forms of coherence remains challenging.

**Proof Relevance.** Some proofs carry computational content (e.g., witnesses for existential statements), while others are purely informational. Determining which proofs can be erased and which must be retained requires sophisticated type system machinery. Currently, QTT is conservative, retaining proofs unless explicitly marked as zero-usage.

**Pattern Matching Performance.** Dependent type pattern matching with type narrowing can require expensive runtime type checks if the elaborator cannot prove that certain cases are statically unreachable. Optimizing this without losing type safety is an active area of research.

**Collection Shape Mismatches.** The type system does not prevent choosing an unsuitable collection for a workload. Education, documentation, and runtime warnings are needed to guide programmers toward appropriate collection choices.

---

## 14. References and Key Literature

**Persistent Data Structures:**

1. Okasaki, C. (1998). *Purely Functional Data Structures*. Cambridge University Press.

2. Driscoll, J. R., Sarnak, N., Sleator, D. D., & Tarjan, R. E. (1989). "Making Data Structures Persistent." *Journal of Computer and System Sciences*, 38(1), 86–124.

3. Bagwell, P. (2001). "Ideal Hash Trees." *Technical Report*, EPFL.

4. Steindorfer, M. J., & Vinju, J. J. (2015). "Optimizing Hash-Array Mapped Tries for Fast and Lean Immutable JVM Collections." *Proceedings of OOPSLA*.

5. Hinze, R., & Paterson, R. (2006). "Finger Trees: A Simple General-Purpose Data Structure." *Journal of Functional Programming*, 16(2), 197–217.

**Quantitative Type Theory & Linear Types:**

6. McBride, C. (2016). "I Got Plenty o' Nuttin'." *Proceedings of A List of Successes That Can Change the World (LSUC)* Workshop.

7. Atkey, R. (2018). "Syntax and Semantics of Quantitative Type Theory." *Proceedings of POPL*, ACM.

8. Wadler, P. (1990). "Linear Types Can Change the World!" In *IFIP TC 2 Working Conference on Programming Concepts and Methods*.

**Dependent Types and Type-Driven Development:**

9. Brady, E. (2017). *Type-Driven Development with Idris*. Manning Publications.

10. Bove, A., Dybjer, P., & Norell, U. (2009). "A Brief Overview of Agda." *International School on Theorem Proving and Dependent Types*.

**Concurrent Programming and Determinism:**

11. Kuper, L., & Newton, R. R. (2013). "LVars: Lattice Variables for Deterministic Parallelism." *Proceedings of PLDI*.

12. Kuper, L., Turon, A., Krishnaswami, N. R., & Newton, R. R. (2014). "Liquid Effects." *Proceedings of ICFP*.

**Distributed Data Structures and CRDTs:**

13. Shapiro, M., Preguiça, N., Baquero, C., & Zawirski, M. (2011). "Conflict-free Replicated Data Types." In *SSS*.

**Lattice Theory and Fixed-Point Semantics:**

14. Cousot, P., & Cousot, R. (1977). "Abstract Interpretation: A Unified Lattice Model for Static Analysis of Programs." *Proceedings of POPL*, ACM.

**Propagators and Constraint Solving:**

15. Radul, A., & Sussman, G. J. (2009). "The Art of the Propagator." *Technical Report*, MIT.

**Constraint Logic Programming:**

16. Jaffar, J., & Maher, M. J. (1994). "Constraint Logic Programming: A Survey." *Journal of Logic Programming*.

**Actor Models:**

17. Hewitt, C., Bishop, P., & Steiger, R. (1973). "A Universal Modular Actor Formalism for Artificial Intelligence." In *IJCAI*.

**Racket and #lang Systems:**

18. Flatt, M., Findler, R. B., & PLT. (2023). *The Racket Reference*. https://docs.racket-lang.org/.

19. Felleisen, M., Findler, R. B., & Flatt, M. (2009). *Semantics Engineering with PLT Redex*. MIT Press.

**Memory Management and Garbage Collection:**

20. Jones, R., & Lins, R. (1996). *Garbage Collection: Algorithms for Automatic Dynamic Memory Management*. Wiley.

21. Bacon, D. F., Cheng, P., & Rajan, V. T. (2004). "A Unified Theory of Garbage Collection." *Proceedings of OOPSLA*, ACM.

**Type Inference and Unification:**

22. Robinson, J. A. (1965). "A Machine-Oriented Logic Based on the Resolution Principle." *Journal of the ACM*.

23. Damas, L., & Milner, R. (1982). "Principal Type-Schemes for Functional Programs." *Proceedings of POPL*, ACM.

**Concurrent Tries:**

24. Prokopec, A., Bronson, N. G., Bagwell, P., & Odersky, M. (2012). "Concurrent Tries with Efficient Non-Blocking Snapshots." *Proceedings of PPoPP*.

**Persistent Union-Find:**

25. Conchon, S., & Filliâtre, J.-C. (2007). "A Persistent Union-Find Data Structure." *Proceedings of ML Workshop*.

**Adaptive Radix Trees:**

26. Leis, V., Kemper, A., & Neumann, T. (2013). "The Adaptive Radix Tree: ARTful Indexing for Main-Memory Databases." *Proceedings of ICDE*.

**Pairing Heaps:**

27. Fredman, M. L., Sedgewick, R., Sleator, D. D., & Tarjan, R. E. (1986). "The Pairing Heap: A New Form of Self-Adjusting Heap." *Algorithmica*, 1(1–4), 111–129.
