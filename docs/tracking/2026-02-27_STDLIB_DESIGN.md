# Prologos Standard Library Design — Phase 1: Deep Research

**Date**: 2026-02-27
**Methodology Phase**: Phase 1 (Deep Research) → Phase 2 (Refinement) pending
**Scope**: Complete redesign of standard library organization, naming, presentation, and gap analysis

---

## Table of Contents

- [Part I: Cross-Ecosystem Research Survey](#part-i-cross-ecosystem-research-survey)
  - [1. Mainstream Systems (Go, Java, Rust)](#1-mainstream-systems)
  - [2. Functional Systems (Haskell, Clojure, Elixir)](#2-functional-systems)
  - [3. Dependently-Typed / Logic Systems (Lean 4, Idris 2, SWI-Prolog, Mercury)](#3-dependently-typed--logic-systems)
  - [4. General Library Design Principles](#4-general-library-design-principles)
- [Part II: Current State Analysis](#part-ii-current-state-analysis)
  - [5. Strengths of the Current Library](#5-strengths)
  - [6. Problems and Pain Points](#6-problems-and-pain-points)
- [Part III: Design Principles for the Prologos Standard Library](#part-iii-design-principles)
  - [7. Core Design Principles (Derived)](#7-core-design-principles)
- [Part IV: Proposed Reorganization](#part-iv-proposed-reorganization)
  - [8. The Book Model](#8-the-book-model)
  - [9. Module Architecture](#9-module-architecture)
  - [10. The Prelude — What's In, What's Out](#10-the-prelude)
  - [11. Naming Conventions](#11-naming-conventions)
- [Part V: Gap Analysis and Roadmap](#part-v-gap-analysis-and-roadmap)
  - [12. Missing Abstractions](#12-missing-abstractions)
  - [13. Implementation Roadmap](#13-implementation-roadmap)
- [Part VI: Syntax and Presentation Standards](#part-vi-syntax-and-presentation-standards)
  - [14. The Idealized `spec` Signature](#14-idealized-spec-signature)
  - [15. File Layout Convention](#15-file-layout-convention)
  - [16. Documentation Standards](#16-documentation-standards)
- [Part VII: Open Questions for Critique](#part-vii-open-questions)

---

## Part I: Cross-Ecosystem Research Survey

### 1. Mainstream Systems

#### Go

**Philosophy**: Simplicity, readability, orthogonality. The Go standard library is famously flat — packages like `fmt`, `io`, `net/http`, `os`, `strings`, `bytes`, `sort` are at most one level deep. There is no deep nesting.

**Key patterns**:
- **Small interfaces, big functions**: `io.Reader` and `io.Writer` are 1-method interfaces that compose everything. The `io` package alone provides `Copy`, `TeeReader`, `MultiReader`, `LimitReader`, `SectionReader` — all built from the 1-method interface. This is Go's "narrow waist."
- **Iter package** (Go 1.23+): The new `iter` package defines `Seq[V]` and `Seq2[K,V]` as function types (`func(yield func(V) bool)`). Iterators are plain functions, not interface implementations. The `slices` and `maps` packages gained iterator-producing functions. This is Go's eventual convergence on a seq abstraction — notably late (Go 1.0 had no generics).
- **Argument order**: The source/receiver comes first (e.g., `strings.HasPrefix(s, prefix)`). Functions are grouped by type in dedicated packages (`strings.Split`, `bytes.Split`).
- **Naming**: Short, lowercase, unexported-by-default. `io.ReadAll` not `io.ReadAllBytes`. No stuttering: `http.Server` not `http.HttpServer`.
- **Conservative generics**: Generics arrived in Go 1.18 but the stdlib barely uses them. The `slices` and `maps` packages are the main generic stdlib packages. The community lesson: don't over-abstract with generics; concrete types are easier to understand.

**Lessons for Prologos**: Go's flat package structure and small-interface philosophy resonate with our bundle/trait design. The 1-method interface = 1 function pattern is exactly our single-method trait pattern. Go's iter design (iterators as functions) parallels our LSeq/Seqable approach.

#### Java

**Philosophy**: Object-oriented, enterprise-grade, backward-compatible. The Collections Framework (Java 1.2) and Stream API (Java 8) are the relevant stdlib designs.

**Key patterns**:
- **Collections Framework hierarchy**: `Collection → List/Set/Queue`, `Map` (separate). Each interface defines a contract; `AbstractList`, `AbstractSet` provide skeletal implementations. Users implement the abstract class, not the raw interface.
- **Stream API**: `stream().filter(...).map(...).collect(...)`. Lazy, single-use, parallel-capable. Collectors are the "Buildable" equivalent: `Collectors.toList()`, `Collectors.toSet()`, `Collectors.groupingBy()`. The `Collector` interface is complex (4 methods) but composable.
- **Functional interfaces**: `Function<T,R>`, `Predicate<T>`, `Consumer<T>`, `Supplier<T>` are the building blocks. Each is a single abstract method (SAM), enabling lambda syntax.
- **Naming**: Verbose but descriptive. `Collections.unmodifiableList()`, `Optional.orElseGet()`. Method names describe the operation completely.
- **The primitives problem**: `int` vs `Integer`, `IntStream` vs `Stream<Integer>`. Boxing overhead forced specialized stream types. A cautionary tale about type system gaps leaking into API design.

**Lessons for Prologos**: Java's Collector abstraction (supplier + accumulator + combiner + finisher) is richer than our Buildable (just `from-seq`). This matters for parallel folds. The Stream API's laziness + terminal operation design influenced every subsequent language. Java's verbosity is a warning: names should be descriptive but not bureaucratic.

#### Rust

**Philosophy**: Zero-cost abstractions, ownership, fearless concurrency. The standard library has a distinctive 3-layer architecture.

**Key patterns**:
- **core/alloc/std layering**: `core` = no allocator needed (traits, primitives, iterators). `alloc` = heap allocation (Vec, String, Box). `std` = OS interaction (fs, net, io, thread). Libraries target the narrowest layer possible. This is onion architecture for a standard library.
- **Iterator as king**: The `Iterator` trait (1 required method: `next()`) with ~75 provided methods is the crown jewel. `map`, `filter`, `fold`, `collect`, `chain`, `zip`, `enumerate`, `flat_map`, `take`, `skip`, `peekable` — all zero-cost, all lazy. The `IntoIterator` trait makes `for` loops work on anything.
- **FromIterator / Collect**: The dual of `Iterator`. `fn collect<B: FromIterator<Self::Item>>(self) -> B` builds any collection from any iterator. This is Rust's "Buildable" — and it's the most-used generic pattern in the ecosystem.
- **Trait hierarchy**: `Display` (human-readable), `Debug` (programmer-readable), `Clone`, `Copy`, `Default`, `PartialEq`/`Eq`, `PartialOrd`/`Ord`, `Hash`. These are the "fundamental" traits. Most have `#[derive]` support.
- **Prelude**: `std::prelude::v1` auto-imports ~30 items: the fundamental traits, `Option`, `Result`, `Vec`, `String`, `Box`, `Iterator`, `IntoIterator`, `FromIterator`, `Clone`, `Copy`, `Send`, `Sync`. Deliberately small.
- **Error handling**: `Result<T, E>` everywhere. The `?` operator for propagation. `From<E>` trait for error conversion. `thiserror` and `anyhow` in the ecosystem.
- **Naming**: `snake_case` for functions, `CamelCase` for types. Methods read as verbs: `iter()`, `map()`, `filter()`, `collect()`. `into_*` for ownership-taking conversions, `as_*` for borrows, `to_*` for cloning conversions.

**Lessons for Prologos**: Rust's layered stdlib (core/alloc/std) is the strongest model for Prologos. Our `core/` and `data/` split is similar in intent but not as cleanly motivated. Rust's Iterator + FromIterator = our Seqable + Buildable. Rust's prelude discipline (small, deliberate) should inform our prelude. The `into_*`/`as_*`/`to_*` naming convention is excellent and we should adopt a version of it.

---

### 2. Functional Systems

#### Haskell

**Philosophy**: Mathematical purity, type-class hierarchy, laziness by default.

**Key patterns**:
- **The Prelude**: Haskell's Prelude is both loved and hated. It auto-imports ~200 names. The community has produced alternative preludes (`rio`, `relude`, `protolude`, `foundation`) that address common complaints: `String` is `[Char]` (slow), no `Text` or `ByteString`, `Monad` doesn't require `Applicative`, `head` and `tail` are partial, numeric hierarchy is awkward.
- **Foldable-Traversable Proposal (FTP)**: Generalized `foldr`, `foldMap`, `mapM_`, `sequence_` to work on any `Foldable`, not just lists. This was controversial because it made error messages worse (ambiguous types) and some code harder to read. The lesson: generality has a readability cost.
- **Typeclass hierarchy**: `Functor → Applicative → Monad`. `Foldable → Traversable`. `Semigroup → Monoid`. `Eq → Ord`. `Num → Fractional → Floating`. Each level adds capability. The hierarchy is deep and interconnected.
- **Naming**: Short function names in `Prelude`: `map`, `filter`, `foldr`, `foldl`, `zip`, `unzip`, `take`, `drop`, `head`, `tail`. Qualified imports for disambiguation: `Data.Map.lookup`, `Data.Set.member`. The naming is concise but assumes context.
- **Module organization**: `Data.List`, `Data.Map`, `Data.Set`, `Data.Sequence`, `Data.Vector`, `Data.Text`, `Data.ByteString`. Each is a self-contained module with similar operations. The pattern: `empty`, `singleton`, `fromList`, `toList`, `null`, `size`, `member`, `insert`, `delete`, `map`, `filter`, `foldl'`, `foldr`, etc.
- **Argument order**: Function-last for lists (`map f xs`), key-first for maps (`Map.lookup k m`). Inconsistent, driven by historical currying patterns.

**Lessons for Prologos**: Haskell's Prelude problems are a cautionary tale. Importing too many names creates ambiguity. But the alternative (qualified everything) creates verbosity. The sweet spot is a small prelude with opt-in generics — which is close to what we have. Haskell's typeclass hierarchy (Functor → Applicative → Monad) is what our trait/bundle system enables; we should build toward it. The FTP controversy teaches that generalization must come with clear error messages.

#### Clojure

**Philosophy**: Simplicity, data orientation, immutability by default, "it is better to have 100 functions operate on one data structure than 10 functions on 10 data structures" (Perlis).

**Key patterns**:
- **clojure.core as a book**: ~700 functions in a single namespace, logically ordered. The namespace reads sequentially: foundational predicates → collections → sequences → transducers → concurrency → IO. A developer can read through `clojure.core` like a reference manual.
- **The seq abstraction**: Every collection (`list`, `vector`, `map`, `set`, `string`, `array`, `stream`) can produce a `seq` — a logical list of elements. `map`, `filter`, `reduce`, `take`, `drop`, `concat` all work on seqs. This is Clojure's narrow waist. Critically, seq operations return lazy sequences — the output type is always seq, not the input type.
- **Protocols**: `ISeq`, `ISeqable`, `ILookup`, `IAssociative`, `ICounted`, `IIndexed`, `IReduce`. These are Clojure's traits. They're minimal (1-3 methods) and mostly invisible to users — the public API is the functions that call through them.
- **Transducers**: Composable algorithmic transformations independent of their input source. `(comp (map inc) (filter even?) (take 5))` creates a transducer that works on sequences, channels, observables. This is the zero-copy version of seq composition.
- **Argument order**: Collection-last for sequence operations (`(map f coll)`, `(filter pred coll)`). This enables threading: `(->> coll (map f) (filter pred) (take 5))`. Lookup operations are target-first: `(get m k)`, `(nth v i)`.
- **Naming**: Short, no redundancy. `assoc` not `map-associate`. `conj` not `collection-conjoin`. `first`/`rest` not `head`/`tail`. Predicates end in `?`: `empty?`, `nil?`, `contains?`, `some?`. The vocabulary is small and memorable.
- **Data-first, abstraction-second**: Functions work on concrete data (maps, vectors) before you ever need protocols. You can use Clojure for years without knowing what `ISeq` is.
- **Destructuring**: `(let [{:keys [name age]} person] ...)` — built into the language, works everywhere bindings work.

**Lessons for Prologos**: Clojure's model is our strongest inspiration. The seq abstraction = our Seqable/LSeq. The "collection-last" argument order enables pipe threading. The single-namespace organization (reading like a book) is exactly what the user wants. The key difference: Prologos has types, so our "book" can have explicit signatures that serve as documentation. Clojure's protocols (invisible to users, driving the public API) is the ideal relationship between our traits and our surface functions. The naming convention (short, no redundancy, `?` for predicates) should be adopted wholesale.

#### Elixir

**Philosophy**: Pragmatic functional programming, immutability, the BEAM VM, "let it crash" supervision.

**Key patterns**:
- **Enumerable + Collectable**: `Enumerable` (≈ our Seqable+Foldable) is the "can be iterated" protocol. `Collectable` (≈ our Buildable) is "can be built into." `Enum` module provides eager operations; `Stream` module provides lazy operations. The user chooses laziness explicitly.
- **Enum as the gateway**: `Enum.map/2`, `Enum.filter/2`, `Enum.reduce/3`, `Enum.sort/1`, `Enum.group_by/2`, `Enum.zip/2`, `Enum.chunk_by/2`, `Enum.flat_map/2`, `Enum.into/2`. These work on lists, maps, ranges, streams, MapSet — anything implementing `Enumerable`. Users learn `Enum` and it works everywhere.
- **The `|>` pipe**: `data |> transform1 |> transform2 |> output`. First argument is piped. This drives argument order: data-first for piping.
- **Naming**: Module-qualified but concise. `Enum.map`, `Map.put`, `String.split`, `List.flatten`. `?` suffix for boolean returns: `Enum.empty?`, `Map.has_key?`. `!` suffix for bang/dangerous variants: `Map.fetch!` (raises on missing), `Enum.fetch!`.
- **into/2**: `Enum.into(source, target)`. Converts between collection types. This is exactly our `into` function.
- **Protocols vs Behaviours**: Protocols are data-driven polymorphism (like our traits). Behaviours are callback contracts (like our trait method signatures in a different context). The distinction is useful.

**Lessons for Prologos**: Elixir's Enum module is a strong model for our generic collection functions — a single module with all the operations, dispatching via protocols. The eager/lazy split (Enum vs Stream) is something we should consider: our current approach (everything through LSeq) is always lazy, which may surprise users expecting eager evaluation. Elixir's `!` convention for error-raising variants is worth adopting. The pipe-first argument order aligns with our `|>` operator.

---

### 3. Dependently-Typed / Logic Systems

#### Lean 4

**Philosophy**: Theorem proving meets practical programming. Lean 4's standard library (Std4/Batteries) bridges formal verification and software engineering.

**Key patterns**:
- **Layered stdlib**: `Init` (bootstrapping), `Std` (batteries), `Mathlib` (mathematics). Each layer extends the previous. `Init` is tiny (basic types, `Decidable`, `BEq`, `Hashable`). `Std` adds data structures and algorithms. `Mathlib` adds heavy mathematics.
- **Decidable**: Instead of a boolean equality function, Lean uses `Decidable (a = b)` which returns a proof of equality OR a proof of inequality. This is richer than `Bool` — the caller gets evidence, not just a bit. For practical programming, `BEq` (boolean equality, like our `Eq`) coexists alongside `DecidableEq`.
- **Array vs List vs Vector**: `Array` is the practical workhorse (O(1) amortized append, O(1) access). `List` is the inductive type for proofs. `Vector n α` is length-indexed for dependent types. Each exists for a specific purpose. The lesson: having multiple sequence types is fine if each serves a clear role.
- **Naming conventions**: `camelCase` for functions, `PascalCase` for types/theorems. `List.map`, `Array.push`, `HashMap.insert`. Methods follow `TypeName.methodName` pattern. Dot notation is pervasive: `xs.map f` = `List.map f xs`.
- **instance/deriving**: `instance : BEq Nat where beq := ...`. The `deriving` mechanism auto-generates instances for algebraic types. This is more ergonomic than our manual `impl` blocks.
- **Notation/Syntax**: Lean has powerful syntax extension (`syntax`, `macro`, `elab`). Standard mathematical notation (`∀`, `∃`, `∧`, `∨`, `→`) is used in theorem statements but not in programs. The dual surface is explicit.

**Lessons for Prologos**: Lean's `Decidable` vs `BEq` distinction models the graduated path we should offer: boolean equality for day-to-day programming, proof-carrying equality for formal reasoning. Lean's layered stdlib (Init/Std/Mathlib) maps well to a potential Prologos layering (core types / collections+traits / mathematical structures). The dot notation (`xs.map f`) is something we should consider if our parser supports it (we have map-key dot access already).

#### Idris 2

**Philosophy**: Dependent types for practical programming, with QTT (Quantitative Type Theory) for resource management.

**Key patterns**:
- **Minimal prelude**: Idris 2's prelude is deliberately small: basic types, `Eq`, `Ord`, `Show`, `Functor`, `Applicative`, `Monad`, `Foldable`, `Traversable`, `Decidable`, and some core functions. Additional functionality lives in `Data.*` and `Control.*` modules.
- **Vect and Fin**: `Vect n a` (length-indexed vector) and `Fin n` (bounded natural) are first-class stdlib types, not library additions. Dependent types are used for everyday programming, not just proofs.
- **DecEq**: `DecEq` is a typeclass where `decEq x y` returns `Yes prf` or `No contra`. Like Lean's `Decidable`, this is richer than boolean equality.
- **Effects via QTT**: Linear types (`:1`) mark resources that must be used exactly once. Prologos shares this: our `:0`/`:1`/`:w` multiplicities come from the same QTT foundation.
- **Interface hierarchy**: `Functor → Applicative → Monad`, `Foldable → Traversable`, `Eq → Ord`, `Semigroup → Monoid`. The hierarchy is cleaner than Haskell's (Idris learned from Haskell's mistakes).
- **Naming**: Similar to Haskell but with some differences. `map`, `foldr`, `foldl`, `filter`, `length`. Qualified imports for disambiguation.

**Lessons for Prologos**: Idris 2 demonstrates that QTT (which we share) and dependent types (which we share) can coexist with a practical stdlib. The interface hierarchy (with proper layering from day one) is what we should build toward. Idris's `DecEq` is the blueprint for our graduated `Eq` → `DecEq` path.

#### SWI-Prolog

**Philosophy**: Practical logic programming, extensive library, "batteries included."

**Key patterns**:
- **library() modules**: `use_module(library(lists))`, `use_module(library(aggregate))`, `use_module(library(apply))`. Flat namespace with descriptive module names.
- **Multi-directional predicates**: `append(Xs, Ys, Zs)` can compute the concatenation (mode `+,+,-`), split a list (mode `-,-,+`), or check a relationship (mode `+,+,+`). This is the relational paradigm's superpower: one definition, multiple uses.
- **Naming**: `snake_case` with type prefix for disambiguation: `atom_string/2`, `number_chars/2`, `msort/2`, `predsort/3`. Arity is part of the name: `append/3` is different from `append/2`.
- **Library organization**: `lists` (list operations), `apply` (higher-order), `aggregate` (group-by), `assoc` (association lists), `ordsets` (ordered sets), `rbtrees` (red-black trees), `pairs` (key-value pairs). Each module is self-contained.

**Lessons for Prologos**: Multi-directional predicates (the relational paradigm) are what our `defr`/`rel` keywords enable. SWI-Prolog's experience shows that the same predicate serving multiple modes is enormously powerful but requires mode annotations for clarity — exactly what our relational language vision proposes.

#### Mercury

**Philosophy**: Logical-functional programming with static types, modes, and determinism.

**Key patterns**:
- **Mode system**: Every predicate/function declares modes. `list.append(in, in, out) is det` means "given two input lists, produces one output list, deterministically." Modes are part of the type signature.
- **Determinism categories**: `det` (exactly one solution), `semidet` (zero or one), `nondet` (zero or more), `multi` (one or more), `cc_nondet`, `cc_multi`, `erroneous`, `failure`. This is a taxonomy of computational effects.
- **Multiple implementations**: Mercury has `set.set` (balanced tree), `set.set_univ` (bitset for small universes), `set.set_ordlist` (sorted list). The interface is the same; the implementation varies. This is our trait-instance pattern.
- **Module hierarchy**: `list`, `map`, `set`, `string`, `int`, `float`, `char`, `bool`, `io`, `solutions`. Flat-ish, grouped by data type.

**Lessons for Prologos**: Mercury's determinism categories map to our type system's capability: `det` = total function, `semidet` = `Option`-returning, `nondet` = `List`-returning (or lazy stream). Mercury shows that modes + determinism = a rich type discipline for logic programs. This should inform our `defr` design.

---

### 4. General Library Design Principles

#### The Narrow Waist (Perlis Epigram #9)

> "It is better to have 100 functions operate on one data structure than 10 functions on 10 data structures."

This is the most important library design principle. A "narrow waist" is a single abstraction that many producers and many consumers work through:

- **Clojure**: seq abstraction (ISeq)
- **Rust**: Iterator trait
- **Go**: io.Reader / io.Writer
- **Unix**: byte streams (stdin/stdout)
- **HTTP**: request/response

The narrow waist creates an `m × n` connection matrix with only `m + n` implementations (each producer implements "to-seq", each consumer implements "from-seq"). Without it, you need `m × n` conversion functions.

**For Prologos**: Our narrow waist is `LSeq` (lazy sequence) mediated by `Seqable` (to-seq) and `Buildable` (from-seq). This is correct and should remain the central design. But the waist must be truly narrow — it should be the *only* way generic operations work, not one of several competing mechanisms.

#### Rich Hickey: "Simplicity Matters" / "Simple Made Easy"

Key takeaways:
- **Simple ≠ Easy**: Simple means "not interleaved/complected." Easy means "near at hand." A library should be both, but simplicity trumps ease.
- **Growth over breakage**: Accretion (adding) is good. Retirement (soft deprecation + eventual removal) is acceptable. Breakage (changing meaning of existing names) is never acceptable.
- **Data > Functions > Macros**: Prefer plain data. When you need behavior, use functions. Macros only when functions can't express it. This is the "data orientation" principle.

**For Prologos**: Our `spec` metadata (`:doc`, `:pre`, `:post`, `:properties`, `:examples`) is data about functions — this aligns with Hickey's data orientation. Our trait system (functions dispatched via type) is the function layer. Our `defmacro` is the macro layer. The layering is correct.

#### Progressive Disclosure

From UI design but applicable to APIs:
1. **Level 0**: Import prelude, call functions. No types needed.
2. **Level 1**: Add `spec` signatures for documentation and type checking.
3. **Level 2**: Add trait constraints (`where`) for generic functions.
4. **Level 3**: Add `property` declarations for formal properties.
5. **Level 4**: Add `functor` declarations for type abstractions.
6. **Level 5**: Add dependent types (Pi/Sigma) for proof-carrying code.

Each level is opt-in. A programmer at level 0 should never encounter level 5 concepts unless they choose to. The standard library should demonstrate all levels but present level 0-1 as the default.

#### The Pit of Success

Design the API so that the easiest way to use it is also the correct way. Wrong usage should be hard or impossible, not just documented as wrong.

**For Prologos**: Type signatures are our pit of success — incorrect usage is a type error. But *discoverability* is also part of the pit: if the right function is hard to find, users will write their own (worse) version. This argues for a flat, well-organized namespace.

#### The Expression Problem

Philip Wadler's challenge: can you add both new types AND new operations without modifying existing code? The standard solutions:
- **Haskell/Rust/Prologos**: Typeclasses/traits. New types implement existing traits (new "rows"). New traits add operations to existing types (new "columns"). ✓ Solves both directions.
- **OOP**: Subclassing adds new types easily but adding new operations requires modifying the base class. ✗ One direction only.
- **ML modules/functors**: Signatures and structures solve both directions but with heavier syntax.

**For Prologos**: Our trait + impl system is the Expression Problem solution. The stdlib should be designed so that user-defined types can implement all standard traits, and user-defined traits can be implemented for all standard types, without any modification to the stdlib.

#### Documentation as the Library

From the Rust ecosystem's emphasis on `rustdoc` and docs.rs:
- **Every public function has a doc comment**
- **Every module has a module-level doc comment**
- **Examples are runnable tests** (doc-tests)
- **Cross-references link to related functions**

**For Prologos**: Our `:doc` metadata on `spec` is the mechanism. But it's currently optional and inconsistently applied. The design should mandate `:doc` on every public `spec` in the standard library, with `:examples` for the most-used functions.

---

## Part II: Current State Analysis

### 5. Strengths of the Current Library

1. **Correct narrow waist**: Seqable/Buildable/Foldable mediated by LSeq is the right abstraction. The `to-seq → transform → from-seq` pattern preserves collection types.

2. **Clean trait design**: Single-method traits (Foldable, Seqable, Functor) where the dict IS the function give zero-overhead dispatch. Multi-method traits (Eq, Ord, Buildable) use minimal structs.

3. **Property declarations exist**: `property` keyword with `:forall`, `:holds`, `:includes`, `:where` is already more expressive than most library property systems. `algebraic-laws.prologos` demonstrates composable law hierarchies.

4. **Metadata-rich specs**: `:doc`, `:deprecated`, `:see-also`, `:pre`, `:post`, `:invariant`, `:properties`, `:examples` — the metadata vocabulary is comprehensive (post-audit hardening).

5. **Functor keyword**: Named type abstractions with `:unfolds` and category-theoretic metadata (`:variance`, `:fold`, `:unfold`) are unique to Prologos.

6. **Bundle composition**: `bundle Collection {C : Type -> Type} (Seqable C) (Buildable C) (Foldable C)` composes traits without inheritance.

7. **Subtype declarations**: `subtype PosInt Int`, `subtype Zero Int via zero-to-int` with transitive closure is a clean refinement type mechanism.

8. **Generic collection functions**: `collection-fns.prologos` provides type-preserving generic `map`, `filter`, `reduce`, etc. that shadow List-specific versions.

### 6. Problems and Pain Points

#### P1: Dispersed Organization (The Core Problem)

The library has **122 files** across 2 directories:
- `core/` (100 files): traits, instances, operations, bundles, properties, functors, generic ops
- `data/` (22 files): types, type-specific operations

But the organization within these directories is **flat and arbitrary**. Files are named by their role (`eq-trait.prologos`, `eq-instances.prologos`, `eq-derived.prologos`, `eq-char-instance.prologos`, `eq-string-instance.prologos`, `eq-numeric-instances.prologos`) rather than by their conceptual position in a reading order. A newcomer looking for "how to compare things for equality" must discover 6 different files.

**Contrast with Clojure**: `clojure.core` puts `=`, `==`, `not=`, `identical?`, `compare` in a single namespace, near each other, readable top-to-bottom. You never need to know about `IEquiv` or `IPersistentCollection` to use them.

#### P2: Instance Explosion

Every combination of (trait, type) gets its own file:
```
eq-instances.prologos        # Eq for Nat, Bool, List, Option, Pair, ...
eq-numeric-instances.prologos # Eq for Int, Rat, Posit*
eq-char-instance.prologos     # Eq for Char
eq-string-instance.prologos   # Eq for String
ord-instances.prologos        # Ord for Nat, Bool, ...
ord-numeric-instances.prologos
ord-char-instance.prologos
ord-string-instance.prologos
...
```

This is **30+ files** just for trait instances. Each file is small (typically 5-30 lines) and exists solely for module system reasons (avoiding circular dependencies, side-effect registration). The files are necessary at the implementation level but shouldn't be visible at the conceptual level.

#### P3: Inconsistent Surface Syntax

Some library files use WS mode (modern):
```prologos
spec map [A -> B] [List A] -> List B
defn map [f xs]
  match xs
    | nil       -> nil
    | cons a as -> cons [f a] [map f as]
```

Others use sexp mode (legacy):
```racket
(spec map {A B : Type} {C : Type -> Type} (Seqable C) -> (Buildable C) -> (-> A B) -> (C A) -> (C B))
(defn map [$seq $build f xs]
  (Buildable-from-seq $build B (lseq-map A B f ($seq A xs))))
```

The generic collection functions (`collection-fns.prologos`) are entirely in sexp mode with explicit dict parameters. The concrete type implementations (`list.prologos`, `eq-trait.prologos`) use WS mode. This inconsistency makes the library harder to read as a reference.

#### P4: Dict Parameters Leak Into Signatures

The generic functions expose the trait resolution mechanism:
```prologos
spec map {A B : Type} {C : Type -> Type} (Seqable C) -> (Buildable C) -> (-> A B) -> (C A) -> (C B)
defn map [$seq $build f xs] ...
```

Users see `$seq` and `$build` — implementation details of trait resolution. In Clojure, `(map f coll)` takes two arguments. In Rust, `iter.map(f)` takes one. Our generic `map` takes **four** (two dicts, function, collection). The `where` clause mechanism can hide dicts, but the current library doesn't use it.

#### P5: Prelude Complexity

The prelude in `namespace.rkt` has **10 tiers** of imports (~140 lines of require statements). This complexity reflects the implementation dependency graph, not the user's mental model. Users don't think in tiers; they think in concepts (equality, ordering, collections, arithmetic, etc.).

#### P6: Naming Inconsistencies

- `foldr` vs `reduce` (both are folds; `reduce` is the left fold)
- `head` (returns default) in `list.prologos` vs `head` (returns Option) in `collection-fns.prologos`
- `lseq-map` / `lseq-filter` (prefixed) vs `map` / `filter` (unprefixed, shadowing)
- `pvec-any?` / `pvec-all?` (prefixed) vs `any?` / `all?` (generic, unprefixed)
- `map-filter-vals` / `map-keys-list` (inconsistent with the `-ops` pattern)
- `gmap` / `gfilter` / `gfold` (prefixed generics in `generic-ops.prologos`) vs `map` / `filter` / `reduce` (unprefixed generics in `collection-fns.prologos`)

The duplication between `generic-ops.prologos` (g-prefixed) and `collection-fns.prologos` (shadowing) is especially confusing.

#### P7: Missing Abstractions

- No `Applicative` or `Monad` traits (the Functor → Applicative → Monad tower)
- No `Traversable` (mapping with effects)
- No `Show` / `Display` trait (string conversion)
- No `Default` trait (default values)
- No `Iterator` protocol (pull-based, stateful iteration — distinct from lazy seq)
- No generic `sort` (only on List)
- No `Semigroup` / `Monoid` traits (only properties, not dispatchable traits)
- No `zip` / `zip-with` generics (only on List)
- No error handling abstractions (Result is a type, but no `?`-like propagation)

#### P8: The Map HKT Problem

`Map K V` has two type parameters, but our collection traits (`Seqable`, `Foldable`, `Buildable`, `Functor`) expect `{C : Type -> Type}` (one parameter). This means Map can't participate in generic collection operations. The workaround (`map-ops.prologos`) is a separate set of standalone functions. This is a genuine type system limitation, but the library organization should acknowledge it more explicitly (perhaps via a dedicated `Keyed` trait family).

---

## Part III: Design Principles for the Prologos Standard Library

### 7. Core Design Principles (Derived)

From the cross-ecosystem research and our project principles, the following design principles should govern the standard library:

#### DP1: The Library Reads Like a Book

**Source**: Clojure's `clojure.core`, user's explicit request.

The standard library should have a **canonical reading order**. A developer reading from the beginning should encounter:
1. Foundational types and predicates
2. Core abstractions (equality, ordering)
3. Collections and their operations
4. Transformation and combination
5. Advanced abstractions (functors, lattices, effects)

Each section builds on the previous. No forward references to unexplained concepts.

#### DP2: Narrow Waist, Wide Surface

**Source**: Perlis Epigram #9, Clojure seq, Rust Iterator.

The `LSeq` abstraction mediated by `Seqable`/`Buildable` is the narrow waist. All generic collection operations go through it. But the surface API should be wide — many functions, clear names, obvious behavior. Users interact with `map`, `filter`, `reduce`, not with `Seqable` and `Buildable`.

#### DP3: Traits Are Infrastructure, Functions Are Interface

**Source**: Clojure protocols, Elixir Enum module.

Users should think in terms of functions: `[map f xs]`, `[filter pred xs]`, `[reduce f z xs]`. Traits (`Seqable`, `Buildable`, `Foldable`) are the dispatch mechanism — they should be invisible in normal usage. The `where` clause mechanism hides trait dicts from function signatures. Every generic function should use `where`, not positional dict parameters.

#### DP4: One Name, One Meaning

**Source**: Go no-stutter rule, Clojure naming.

Each function name should have exactly one meaning across the entire library:
- `map` always means "apply function to each element"
- `filter` always means "keep elements satisfying predicate"
- `fold` always means "combine elements with accumulator"
- `eq?` always means "structural equality"

No `gmap` vs `map` vs `lseq-map` — just `map`, resolved by the type system.

#### DP5: Progressive Disclosure of Complexity

**Source**: Our Language Vision, Extended Spec Design.

The standard library should be usable at every level of sophistication:
- **Beginner**: Call `map`, `filter`, `reduce` on lists. No types needed.
- **Intermediate**: Write `spec` signatures, use `where` constraints, work with `Option` and `Result`.
- **Advanced**: Define traits, implement instances, use `property` declarations.
- **Expert**: Use dependent types, session types, linear types, propagators.

Each level should have clear library support and documentation.

#### DP6: Consistent Argument Order

**Source**: Clojure collection-last, Elixir data-first, Rust method syntax.

For pipeable operations (functions you chain with `|>`), the **data argument comes last**:
```prologos
;; Good: data-last enables piping
spec map : (A -> B) -> C A -> C B
|> xs (map inc) (filter even?) (take 5)

;; Also good for lookup operations: target-first
spec get : Map K V -> K -> Option V
```

The rule: **transformation functions are data-last; access functions are target-first.**

#### DP7: Completeness Over Minimalism

**Source**: Our Development Lessons ("Completeness Over Deferral").

When a concept exists in the library (e.g., `Eq`), it should be complete:
- Trait definition
- Laws (as `property` declarations)
- Instances for all standard types
- Derived operations (`neq?` from `eq?`)
- Documentation
- Examples

No half-built concepts. Each addition to the library is a complete, tested, documented unit.

#### DP8: Layered Architecture

**Source**: Rust core/alloc/std, Lean Init/Std/Mathlib.

The standard library has three conceptual layers:

| Layer | Name | Contents | Dependency |
|-------|------|----------|------------|
| 0 | **Foundation** | Types (Nat, Bool, List, Option, Result), basic operations | None |
| 1 | **Core** | Traits (Eq, Ord, Add, ...), generic ops, collections | Foundation |
| 2 | **Extended** | Lattices, propagators, algebraic structures | Core |

Each layer depends only on lower layers. User code defaults to Layer 0+1 (the prelude).

---

## Part IV: Proposed Reorganization

### 8. The Book Model

The library is reorganized as a **book** — a single logical sequence of modules that reads top-to-bottom, with clear chapter boundaries. Each "chapter" is a module file. The book has parts.

```
lib/prologos/
├── prelude.prologos              # Re-exports the "default vocabulary"
│
├── foundation/                    # Part I: Foundation
│   ├── 01-bool.prologos          # Bool, and, or, not, if-then-else
│   ├── 02-nat.prologos           # Nat, zero, suc, add, mult, pred, zero?
│   ├── 03-int.prologos           # Int operations
│   ├── 04-rat.prologos           # Rat operations
│   ├── 05-char.prologos          # Char operations
│   ├── 06-string.prologos        # String operations
│   ├── 07-option.prologos        # Option, some, none, map-option, unwrap-or
│   ├── 08-result.prologos        # Result, ok, err, map-result, and-then
│   ├── 09-pair.prologos          # Pair, fst, snd
│   ├── 10-ordering.prologos      # Ordering (LT, EQ, GT)
│   └── 11-never.prologos         # Never (empty type)
│
├── traits/                        # Part II: Traits (interfaces)
│   ├── 01-eq.prologos            # Eq trait + laws + neq? + instances for ALL types
│   ├── 02-ord.prologos           # Ord trait + laws + lt/gt/le/ge/min/max/clamp + instances
│   ├── 03-hashable.prologos      # Hashable trait + instances
│   ├── 04-show.prologos          # Show trait (NEW) + instances
│   ├── 05-default.prologos       # Default trait (NEW) + instances
│   ├── 06-add.prologos           # Add trait + instances
│   ├── 07-sub.prologos           # Sub trait + instances
│   ├── 08-mul.prologos           # Mul trait + instances
│   ├── 09-div.prologos           # Div trait + instances
│   ├── 10-neg.prologos           # Neg trait + instances
│   ├── 11-abs.prologos           # Abs trait + instances
│   ├── 12-from.prologos          # From/Into traits + instances
│   ├── 13-numeric.prologos       # Num, Fractional bundles + FromInt/FromRat
│   └── 14-semigroup.prologos     # Semigroup, Monoid traits (NEW) + instances
│
├── collections/                   # Part III: Collections
│   ├── 01-seq.prologos           # LSeq type + operations (the narrow waist)
│   ├── 02-seqable.prologos       # Seqable trait + instances for all collection types
│   ├── 03-foldable.prologos      # Foldable trait + instances
│   ├── 04-buildable.prologos     # Buildable trait + instances
│   ├── 05-indexed.prologos       # Indexed trait + instances
│   ├── 06-functor.prologos       # Functor trait + laws + instances
│   ├── 07-list.prologos          # List type + ALL list operations
│   ├── 08-pvec.prologos          # PVec type + operations
│   ├── 09-set.prologos           # Set type + operations
│   ├── 10-map.prologos           # Map type + operations (standalone, not trait-based)
│   ├── 11-collection.prologos    # Generic collection functions (map, filter, reduce, ...)
│   ├── 12-conversions.prologos   # into, vec, to-list, from-list, ...
│   └── 13-transducer.prologos    # Transducer type + xf combinators
│
├── algebra/                       # Part IV: Algebraic Structures
│   ├── 01-lattice.prologos       # Lattice trait + instances
│   ├── 02-bounded.prologos       # HasTop, BoundedLattice bundle
│   ├── 03-galois.prologos        # GaloisConnection trait + instances
│   ├── 04-widenable.prologos     # Widenable trait + instances
│   ├── 05-identity.prologos      # AdditiveIdentity, MultiplicativeIdentity
│   └── 06-laws.prologos          # Algebraic property declarations
│
├── effects/                       # Part V: Effects & Error Handling (future)
│   ├── 01-io.prologos            # IO operations (future)
│   └── 02-error.prologos         # Error handling patterns (future)
│
└── propagator/                    # Part VI: Propagator Infrastructure
    └── 01-propagator.prologos    # PropNetwork, cells, propagators
```

#### Key Changes from Current Structure

1. **foundation/** replaces scattered `data/` files. Each foundation type gets ALL its operations in one file (no separate `nat.prologos` + `nat-ops.prologos`).

2. **traits/** consolidates trait + instances + derived ops. `01-eq.prologos` contains the `Eq` trait, its laws, `neq?`, AND instances for Nat, Bool, Int, Rat, Char, String, List, Option, Result, Pair, PVec, Set. No more 6 separate files for equality.

3. **collections/** brings together the sequence abstraction, collection traits, concrete types, and generic operations. The canonical reading order: understand the seq abstraction (01-03), then learn each collection type (07-10), then see the generic operations that work across all of them (11).

4. **algebra/** groups mathematical structures that build on traits.

5. **No numbered prefixes in actual module names** — the numbers are for the book reading order. Module names remain `prologos::foundation::bool`, `prologos::traits::eq`, etc.

### 9. Module Architecture

#### The Consolidation Principle

**Current**: 1 file per (trait, type) pair → 30+ instance files
**Proposed**: 1 file per concept → each file contains trait + ALL instances + derived ops

This requires addressing the circular dependency problem. Currently, `eq-trait.prologos` can't import `List` (because `list.prologos` transitively depends on `eq-trait`). The solution:

**Option A: Forward-declaration with deferred instances**
The trait file defines the trait. Instance registration happens when the type's file loads. A type file like `07-list.prologos` both defines `List` AND registers `impl Eq List`, `impl Ord List`, `impl Foldable List`, etc.

**Option B: Consolidated per-concept files with explicit ordering**
`traits/01-eq.prologos` defines `Eq` and instances for foundation types (Nat, Bool, Int, Rat, Char, String). Collection type instances (Eq for List, PVec, Set) are registered in the collection type files.

**Recommendation**: Option B. It mirrors Rust's approach (trait defined in one crate, `impl` in the type's crate) and avoids circular dependencies naturally. The rule: **instances live with the type, not with the trait** (except for foundation types, which are imported by the trait file).

#### The Prelude Module

A single `prelude.prologos` re-exports the default vocabulary:

```prologos
ns prologos::prelude :no-prelude

;; Foundation
require [prologos::foundation::bool    :refer-all]
require [prologos::foundation::nat     :refer-all]
require [prologos::foundation::option  :refer-all]
require [prologos::foundation::result  :refer-all]
require [prologos::foundation::pair    :refer-all]
;; ... etc

;; Traits (re-export trait names + derived ops)
require [prologos::traits::eq   :refer [Eq eq? neq?]]
require [prologos::traits::ord  :refer [Ord compare lt? gt? le? ge? min max clamp]]
require [prologos::traits::show :refer [Show show]]
;; ... etc

;; Collections (re-export generic ops)
require [prologos::collections::collection :refer [map filter reduce fold
                                                    length concat any? all?
                                                    find take drop head empty?
                                                    into to-list sort zip]]
```

The prelude is the **table of contents** — it shows what's available without overwhelming.

### 10. The Prelude — What's In, What's Out

Drawing from Rust's deliberate prelude and Clojure's comprehensive core, the prelude should include:

**IN** (auto-imported by `ns`):
- **Foundation types**: Bool, Nat, Int, Rat, Option, Result, Pair, List, PVec, Set, Map, String, Char
- **Foundation constructors**: true, false, zero, suc, some, none, ok, err, nil, cons, pair
- **Core traits**: Eq, Ord, Show, Default, Add, Sub, Mul, Div, Neg, Abs, From, Into
- **Generic collection ops**: map, filter, reduce, fold, length, concat, any?, all?, find, take, drop, sort, zip, head, tail, empty?, into, to-list
- **Numeric bundles**: Num, Fractional, FromInt, FromRat
- **Arithmetic functions**: plus, minus, times, divide, negate, abs, sum, product
- **Comparison predicates**: eq?, neq?, lt?, gt?, le?, ge?, min, max, compare, clamp
- **Control flow**: if, match, fn
- **Identity/Utility**: id, const, compose (>>), pipe (|>), not, and, or

**OUT** (available via explicit import):
- **Algebraic structures**: Lattice, HasTop, BoundedLattice, GaloisConnection, Widenable
- **Advanced collection traits**: Seqable, Buildable, Foldable, Indexed, Functor (users call generic functions, not traits)
- **Propagator infrastructure**: PropNetwork, new-lattice-cell, etc.
- **Transducers**: map-xf, filter-xf, take-xf, etc.
- **LSeq operations**: lseq-map, lseq-filter, etc. (users use generic `map`/`filter`)
- **Algebraic laws**: property declarations
- **Posit types**: Posit8, Posit16, Posit32, Posit64

**Rationale**: The prelude should contain everything a programmer needs for everyday work without any explicit imports. Specialized tools (lattices, propagators, transducers) are opt-in.

### 11. Naming Conventions

Drawing from the cross-ecosystem analysis, establish these naming rules:

#### Functions
- **snake_case** (matching Prologos conventions): `map`, `filter`, `fold-left`
- **Predicates end in `?`**: `empty?`, `eq?`, `zero?`, `contains?`, `some?`
- **Conversion prefix `to-`**: `to-list`, `to-string`, `to-seq`
- **Conversion prefix `from-`**: `from-list`, `from-string`, `from-seq`
- **Unsafe/partial variants end in `!`** (Elixir convention): `unwrap!` (panics on None), `head!` (panics on empty)
- **No module name in function name**: `keys` not `map-keys`, `insert` not `set-insert`. Use qualified imports for disambiguation: `m::keys`, `s::insert`.
- **Generic functions use the shortest name**: `map` not `gmap` or `collection-map`

#### Types
- **PascalCase**: `List`, `PVec`, `Option`, `Result`, `Map`, `Set`
- **Traits are PascalCase adjectives/nouns**: `Eq`, `Ord`, `Hashable`, `Seqable`, `Foldable`, `Buildable`

#### Argument Order
- **Transformation functions**: function first, data last: `map f xs`, `filter pred xs`
- **Lookup/access**: target first, key second: `get m k`, `nth v i`
- **Fold/reduce**: function first, seed second, data last: `fold f z xs`
- **Binary operators**: follow mathematical convention: `add x y`, `eq? x y`

---

## Part V: Gap Analysis and Roadmap

### 12. Missing Abstractions

| Gap | Description | Priority | Dependency |
|-----|-------------|----------|------------|
| **G1**: Show trait | String representation for all types | **High** | None — pure addition |
| **G2**: Default trait | Default values for types | **High** | None — pure addition |
| **G3**: Semigroup/Monoid traits | Composable `append`/`empty` abstraction | **High** | Add trait exists, needs generalization |
| **G4**: Applicative trait | `pure` + `ap` for effectful sequencing | Medium | Functor trait exists |
| **G5**: Monad trait | `bind`/`>>=` for effectful composition | Medium | Applicative (G4) |
| **G6**: Traversable trait | `traverse`/`sequence` for effects over structures | Medium | Applicative (G4), Foldable |
| **G7**: Generic sort | `sort` for any Ord collection | **High** | Ord, Seqable, Buildable |
| **G8**: Generic zip/unzip | `zip`, `zip-with`, `unzip` for any collection | **High** | Seqable, Buildable |
| **G9**: Error propagation | `?` operator or `and-then` chains for Result | Medium | Result type exists |
| **G10**: DecEq | Decidable equality (proof-carrying) | Low | Eq, dependent types |
| **G11**: Cloneable/Copy | Value copying semantics | Low | QTT multiplicities handle this |
| **G12**: Range type | `range 1 10`, `range-by 0 100 5` | **High** | Nat, Seqable |
| **G13**: String builder | Efficient string concatenation | Medium | String, Buildable |
| **G14**: IO abstractions | File, network, stdin/stdout | Low | Foreign FFI |
| **G15**: Concurrency | Channels, spawn, async | Low | Session types infrastructure |

### 13. Implementation Roadmap

#### Phase A: Foundation Consolidation (Reorganization)

Restructure existing files into the book model without changing any functionality:
1. Create directory structure (`foundation/`, `traits/`, `collections/`, `algebra/`)
2. Consolidate trait + instance files (e.g., 6 eq files → 1 `traits/01-eq.prologos` + instances in type files)
3. Convert remaining sexp-mode files to WS mode
4. Apply `where` clauses to all generic functions (replacing positional dict params)
5. Update `namespace.rkt` prelude to use new paths
6. Update all tests
7. Verify zero regressions

**Risk**: This is a large refactor touching many files. Mitigation: do it in sub-phases (A1: directory structure, A2: consolidation, A3: syntax migration, etc.).

#### Phase B: New Traits (Show, Default, Semigroup/Monoid)

1. Define `Show` trait with `show : A -> String`
2. Define `Default` trait with `default : A`
3. Define `Semigroup` trait with `append : A -> A -> A`
4. Define `Monoid` trait extending Semigroup with `mempty : A`
5. Implement instances for all foundation and collection types
6. Add to prelude

#### Phase C: Generic Operations Expansion

1. Generic `sort` (using Ord)
2. Generic `zip`, `zip-with`, `unzip`
3. Generic `group-by`, `partition-by`
4. Generic `chunk`, `window`
5. `Range` type with Seqable instance
6. `enumerate` (zip with indices)

#### Phase D: Applicative/Monad Tower

1. Define Applicative trait: `pure : A -> F A`, `ap : F (A -> B) -> F A -> F B`
2. Define Monad trait: `bind : F A -> (A -> F B) -> F B`
3. Instances for Option, Result, List
4. Define Traversable trait: `traverse : (A -> F B) -> T A -> F (T B)`
5. Do-notation or monadic comprehension syntax (future)

#### Phase E: Presentation Polish

1. Ensure every public `spec` has `:doc`
2. Add `:examples` to most-used functions
3. Add `:properties` references where algebraic laws exist
4. Generate browsable documentation from `:doc` metadata
5. Write a "Standard Library Guide" document

---

## Part VI: Syntax and Presentation Standards

### 14. The Idealized `spec` Signature

Every public function in the standard library should use the idealized `spec` syntax from the Extended Spec Design work. The goal: **all Pi and Sigma types live in or map to ergonomic keywords on `spec`**.

#### Level 1: Simple monomorphic function
```prologos
spec length : List A -> Nat
  :doc "Number of elements in the list"
```

#### Level 2: Polymorphic with implicit binders
```prologos
spec map {A B} : (A -> B) -> List A -> List B
  :doc "Apply a function to every element"
```

#### Level 3: Constrained polymorphism with `where`
```prologos
spec sort {A} : List A -> List A
  :where (Ord A)
  :doc "Sort elements in ascending order"
```

#### Level 4: Higher-kinded with `where` (generic collections)
```prologos
spec map {A B} {C : Type -> Type} : (A -> B) -> C A -> C B
  :where (Seqable C) (Buildable C)
  :doc "Apply a function to every element of any collection"
```

#### Level 5: With properties
```prologos
spec reverse {A} : List A -> List A
  :doc "Reverse the order of elements"
  :properties
    - involution-laws A
```

#### Level 6: With pre/post conditions
```prologos
spec head! {A} : List A -> A
  :pre [not [empty? xs]]
  :doc "First element; panics if empty"
```

**Critical syntactic decision**: The `where` clause replaces positional dict parameters. The current `(defn map [$seq $build f xs] ...)` becomes:

```prologos
spec map {A B} {C : Type -> Type} : (A -> B) -> C A -> C B
  :where (Seqable C) (Buildable C)
defn map [f xs]
  ...
```

The dict parameters (`$seq`, `$build`) are **automatically injected** by the `where` mechanism. Users never see them. This is the single most important syntax change for library readability.

### 15. File Layout Convention

Every library file follows this layout:

```prologos
ns prologos::<part>::<name>

;; Module documentation (comment block)
;; ========================================
;; <Module Name>
;; ========================================
;; <Description of what this module provides>
;; <Key concepts and design rationale>

;; ---- Imports ----
require [...]

;; ---- Type Definitions (if any) ----
data <Type> ...

;; ---- Trait Definition (if this module defines a trait) ----
trait <Name> {params}
  <methods>
  :doc "..."
  :laws
    - ...

;; ---- Instances (for foundation types) ----
impl <Trait> <Type>
  ...

;; ---- Derived Operations ----
spec <derived-op> ...
  :doc "..."
defn <derived-op> ...

;; ---- Properties (if any) ----
property <name> ...
```

The ordering within a file mirrors the reading order: types first (what are we talking about?), then traits (what can they do?), then instances (how do they do it?), then derived operations (what else can we build?), then properties (what laws hold?).

### 16. Documentation Standards

Every public definition in the standard library MUST have:

1. **`:doc` string**: One sentence describing what it does.
2. **Type signature**: Via `spec` with `where` for constraints.
3. **`:examples`** (for core functions): At least one usage example.

For traits:
4. **`:laws`**: Algebraic laws as property references.

For important functions:
5. **`:see-also`**: Cross-references to related functions.
6. **`:deprecated`**: For functions being retired (with replacement suggestion).

Example of a fully-documented function:

```prologos
spec filter {A} {C : Type -> Type} : (A -> Bool) -> C A -> C A
  :where (Seqable C) (Buildable C)
  :doc "Keep only elements satisfying the predicate"
  :examples
    - [filter even? '[2N 3N 4N 5N 6N]]  ;; => '[2N 4N 6N]
    - [filter [gt? 3N] @[1N 2N 3N 4N]]  ;; => @[4N]
  :see-also [remove, partition, take-while]
```

---

## Part VII: Open Questions for Critique

The following questions are unresolved and should be addressed in the critique phase:

### Q1: Should we use numeric prefixes in file names?

The book model suggests a reading order. Options:
- **Numbered**: `01-bool.prologos`, `02-nat.prologos` — explicit order, ugly names
- **Unnumbered**: `bool.prologos`, `nat.prologos` — clean names, order lives in a manifest
- **Mixed**: Numbers in the directory listing (via a `READING_ORDER.md`), clean names in code

### Q2: How do we handle the Map HKT problem?

Map has two type parameters and can't implement `Seqable {C : Type -> Type}`. Options:
- **A**: Accept it; Map operations remain standalone with their own naming convention
- **B**: Create a parallel `Keyed` trait family: `KeyedSeqable {M : Type -> Type -> Type}`, `KeyedFoldable`, etc.
- **C**: Use type-level partial application: `Seqable (Map K)` where `(Map K)` has kind `Type -> Type`. This requires HKT support for partially-applied type constructors.

### Q3: Should generic functions use `where` or positional dict params?

The plan proposes `where` everywhere. But `where` relies on trait resolution at call sites, which may fail for complex constraints. The current positional style is explicit and always works. Options:
- **A**: `where` everywhere (clean signatures, relies on resolver)
- **B**: `where` for simple constraints, positional for complex ones
- **C**: `where` in the spec, positional in the defn (current pattern for some functions)

### Q4: How deep should the trait hierarchy go?

Immediate need: Eq, Ord, Add/Sub/Mul/Div, Seqable/Foldable/Buildable, Functor.
Medium-term: Applicative, Monad, Traversable, Semigroup, Monoid.
Long-term: Category, Arrow, Comonad, Profunctor.

How far should Phase 0 go? Options:
- **A**: Stop at Functor (current state) — add Applicative/Monad when needed
- **B**: Build through Monad in the initial design — it unlocks do-notation and monadic error handling
- **C**: Build the full FP tower — Category through Traversable

### Q5: Eager vs Lazy generic operations?

Currently, all generic operations go through LSeq (lazy). Elixir separates `Enum` (eager) from `Stream` (lazy). Options:
- **A**: Keep current lazy-only approach (simpler, one mechanism)
- **B**: Provide both `map` (eager, materialized) and `map-lazy` (lazy, streaming)
- **C**: Eager by default, lazy via `lazy [map f xs]` wrapper or transducers

### Q6: What goes in `foundation/` vs `traits/`?

If `Bool` defines `and`, `or`, `not` — do those go in `foundation/01-bool.prologos`?
What about `if-then-else`? What about `Eq Bool`?

**Proposed rule**: Foundation files define the type, constructors, and operations that don't require any traits. Trait instances go in the trait files (for the trait's own "standard" instances) or in the type files (for collection types that implement many traits).

### Q7: How should we handle the `where` syntax migration?

Converting `(defn map [$seq $build f xs] ...)` to `defn map [f xs] where (Seqable C) (Buildable C)` requires the compiler to auto-inject dict params. This mechanism exists (`maybe-inject-where` in macros.rkt) but may not handle all current patterns. Should we:
- **A**: Migrate all at once (breaking change, clean result)
- **B**: Migrate incrementally (mixed styles coexist temporarily)
- **C**: Keep both styles, document when to use which

### Q8: Instance placement — with trait or with type?

Current: instances are in separate files.
Proposed: consolidate.
But where?

- **Rust rule**: `impl Trait for Type` can be in either the trait's crate or the type's crate (orphan rule).
- **Proposed rule**: Foundation type instances go in the trait file. Collection type instances go in the collection type file. This keeps trait files self-contained for basic types while allowing collection types to be self-describing.

---

## Part VIII: Evolution — The Literate Book System

**Date**: 2026-02-27 (later in the day)

The directory-based reorganization proposed in Part IV was superseded by a deeper
insight: **separate the dependency DAG from the presentation order.** Instead of
reorganizing files into directories, we keep module paths stable and introduce a
**literate book system** where:

1. **Chapter files** (`lib/prologos/book/*.prologos`) contain prose + code, using
   Prologos itself as the format (comments for prose, `module` directives for
   compilation unit boundaries)
2. **A tangler** (`tools/tangle-stdlib.rkt`) extracts one `.prologos` file per
   module into `.tangled/`, preserving all existing module paths
3. **An OUTLINE manifest** defines reading order — chapters named, not numbered
4. **A weaver** (future) generates browsable HTML documentation from chapters

### Resolved Open Questions

- **Q1** (numeric prefixes): RESOLVED — chapters named, ordinals from OUTLINE position
- **Q6** (foundation vs traits): RESOLVED — chapters consolidate by concept (e.g., "equality" chapter has Eq trait + all instances)
- **Q8** (instance placement): RESOLVED — instances with the **motivating concept** (the trait's chapter)

### Implementation Status

Phase 1 (tangler + first chapter) is complete:
- `lib/prologos/book/OUTLINE` — manifest with equality chapter
- `lib/prologos/book/equality.prologos` — first chapter (7 modules)
- `tools/tangle-stdlib.rkt` — tangler (~175 LOC)
- Code-only verification: all 7 tangled modules have identical code to originals
- Test suite: 471+ tests pass across 20 files, zero regressions

## Appendix A: File Count Comparison

| | Current | Proposed |
|---|---------|----------|
| Total .prologos files | ~122 | ~35-45 |
| Instance-only files | ~30 | 0 (consolidated) |
| Trait files | ~20 | ~14 (consolidated) |
| Data type files | ~22 | ~13 (in foundation/) |
| Generic ops files | ~10 | ~3 (in collections/) |
| Algebraic structure files | ~12 | ~6 (in algebra/) |

The consolidation reduces file count by ~60-70% while increasing average file size. Each file becomes a meaningful, self-contained chapter.

## Appendix B: Prelude Symbol Count Comparison

| System | Prelude Symbols | Notes |
|--------|----------------|-------|
| Haskell Prelude | ~200 | Widely criticized as too large |
| Rust std::prelude | ~30 | Deliberately minimal |
| Clojure clojure.core | ~700 | Single namespace, not auto-imported (but always available) |
| Idris 2 Prelude | ~80 | Moderate |
| **Prologos (current)** | **~200** | Similar to Haskell, spread across 10 tiers |
| **Prologos (proposed)** | **~120-150** | Reduced by removing trait dicts, consolidating |

## Appendix C: Cross-Reference of Research to Principles

| Research Finding | Prologos Principle | Design Decision |
|-----------------|-------------------|-----------------|
| Clojure single namespace | DP1 (Book Model) | Consolidated modules with reading order |
| Rust Iterator/FromIterator | DP2 (Narrow Waist) | LSeq + Seqable/Buildable |
| Clojure invisible protocols | DP3 (Traits = Infrastructure) | `where` clauses hide dicts |
| Go no-stutter | DP4 (One Name) | `keys` not `map-keys` |
| Extended Spec Design | DP5 (Progressive Disclosure) | 7 levels of spec complexity |
| Clojure collection-last | DP6 (Argument Order) | Data-last for pipeable functions |
| Development Lessons | DP7 (Completeness) | Each concept is fully implemented |
| Rust core/alloc/std | DP8 (Layered) | foundation/traits/collections/algebra |

---

*This document is Phase 1 (Deep Research) output per the [Design Methodology](principles/DESIGN_METHODOLOGY.md). It should be subjected to critique (Phase 2/3) before any implementation begins.*
