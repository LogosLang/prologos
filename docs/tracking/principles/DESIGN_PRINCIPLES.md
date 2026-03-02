- [Core Values](#orga11b862)
  - [Correctness Through Types](#org8116739)
  - [Simplicity of Foundation](#org4bb9c5e)
  - [Progressive Disclosure](#org2c29b6a)
  - [Pragmatism with Rigor](#orgcf5fb33)
- [Decomplection](#org6402dc7)
  - [Collections and Backends](#orgf962ba7)
  - [Schema / Defn and Trait Bundles](#org8988fab)
  - [Session / Defproc for Protocol Types](#org5eaf9b1)
  - [Data vs. Control](#org1411d36)
  - [Compile-Time vs. Runtime](#org180e484)
- [Layered Architecture](#org1e2c3bb)
- [The Most Generalizable Interface](#orgab46305)
- [Homoiconicity as Invariant](#org3436762)
- [AI-First Design](#org810aa8f)
- [Open Extension, Closed Verification](#orge31d626)



<a id="orga11b862"></a>

# Core Values

Prologos is built on a small set of non-negotiable values that inform every design decision. When principles conflict, this ordering reflects priority.


<a id="org8116739"></a>

## Correctness Through Types

The type system is the primary mechanism for ensuring program correctness. Dependent types, linear types, and session types are not academic curiosities &#x2014; they are practical tools for eliminating entire classes of bugs at compile time. A well-typed Prologos program makes illegal states unrepresentable.


<a id="org4bb9c5e"></a>

## Simplicity of Foundation

The language rests on a minimal, uniform foundation: homoiconic terms with prefix notation. Every syntactic form &#x2014; types, expressions, sessions, processes &#x2014; shares a single AST representation. Complexity is built through composition, not special cases. The grammar should fit on one page.


<a id="org2c29b6a"></a>

## Progressive Disclosure

A user should be productive on day one with simple functional programming. The full power of dependent types, session types, linear types, and logic programming reveals itself gradually as understanding deepens. No feature is mandatory. The same codebase can be read at multiple depths by collaborators with different expertise.


<a id="orgcf5fb33"></a>

## Pragmatism with Rigor

Deep theory hides behind an approachable surface. The Curry-Howard correspondence, lattice-theoretic constraint propagation, and pi-calculus foundations are there &#x2014; but users interact with `spec`, `defn`, `session`, and `defproc`, not Greek letters. Proofs are constructed automatically by proof search when possible.


<a id="org6402dc7"></a>

# Decomplection

*Decomplect*: to unbraid, unweave &#x2014; to separate things that are incidentally coupled. This is a central design philosophy borrowed from Clojure's Rich Hickey, applied at every level of the language.


<a id="orgf962ba7"></a>

## Collections and Backends

Collection abstractions (Seqable, Buildable, Foldable, Indexed, Keyed, Setlike) are decoupled from their concrete backends (RRB-Tree, CHAMP, thunked cons). Users program against traits; implementations are swappable with zero code changes. Adding a new backend (e.g., B+ tree for sorted maps) requires only implementing the trait interface.


<a id="org8988fab"></a>

## Schema / Defn and Trait Bundles

Data shape (`schema`) is decoupled from behavior (`defn` / `impl`). Trait bundles (`bundle Numeric := (Add, Sub, Mul, Neg, Abs, FromInt)`) decomplect trait inheritance &#x2014; bundles are conjunctive (AND), not implicative (IMPLIES). This avoids the diamond problem and superclass brittleness of Haskell/Rust.


<a id="org5eaf9b1"></a>

## Session / Defproc for Protocol Types

Protocol specification (`session`) is decoupled from process implementation (`defproc`). A session describes *what* communication happens; a defproc describes *how* one endpoint behaves. This mirrors the spec/defn duality: session is to defproc what spec is to defn.


<a id="org1411d36"></a>

## Data vs. Control

Types and expressions (tree-structured data) use brackets: `[f x y]`. Processes (linear control flow) use indentation. This syntactic distinction reflects a genuine semantic boundary: computing values vs. sequencing actions.


<a id="org180e484"></a>

## Compile-Time vs. Runtime

QTT multiplicities (`:0`, `:1`, `:w`) explicitly separate type-level reasoning (erased at runtime) from value-level computation. Proofs are first-class at type-check time but vanish from the compiled output.


<a id="org1e2c3bb"></a>

# Layered Architecture

The language is designed as composable layers, each independently useful:

| Layer | Feature   | Keyword   | Dual   |
|----- |--------- |--------- |------ |
| 1     | Functions | `defn`    | `fn`   |
| 2     | Relations | `defr`    | `rel`  |
| 3     | Types     | `spec`    | `:`    |
| 4     | Data      | `schema`  | `{}`   |
| 5     | Protocols | `session` | `dual` |
| 6     | Processes | `defproc` | `proc` |
| 7     | Bundles   | `bundle`  | --     |

Each layer adds capability without invalidating the layers below. A program using only layers 1-3 is a standard typed functional program. Adding layer 4 gives data modeling. Layer 5-6 adds concurrent protocol verification. Layer 7 composes trait constraints. Users choose their depth.


<a id="orgab46305"></a>

# The Most Generalizable Interface

When designing any abstraction, prefer the interface that serves the widest range of use cases without sacrificing correctness. Concretely:

-   Seq (lazy sequence) as the universal collection abstraction &#x2014; all collections convert through `LSeq` as a hub type
-   Traits over concrete types &#x2014; `Foldable` over `List`-specific folds
-   Bundles over supertraits &#x2014; composition over inheritance
-   Union types over separate sum types when the domain calls for openness
-   `A?` (nilable) over `Option A` for everyday nullable values

The goal: *logical OR grows and scales without breaking priors*. Adding a new type to a union, a new trait to a bundle, or a new backend to a collection abstraction should never require modifying existing code.


<a id="org3436762"></a>

# Homoiconicity as Invariant

Homoiconicity is not a convenience &#x2014; it is a *strong invariant* of the language. Every syntactic form has a canonical s-expression representation. Every piece of surface syntax can be quoted, inspected, and reconstructed. Macros operate on post-parse AST (where whitespace has been resolved), and all syntactic sugar must be expressible as data.

This invariant enables:

-   User-defined macros that are first-class language extensions
-   Code-as-data for metaprogramming, optimization, and code generation
-   Self-hosting: the compiler is a Prologos program operating on Prologos ASTs
-   AI agent self-inspection: agents can inspect and modify their own reasoning


<a id="org810aa8f"></a>

# AI-First Design

Prologos is designed with AI agents as first-class citizens alongside human programmers. This means:

-   **Provenance tracking**: Information flow is explicit; agents can trace how conclusions were derived
-   **Proof terms as explanation**: Every type-checked decision comes with a machine-checkable justification
-   **Homoiconic self-modification**: Agents can inspect and rewrite their own code
-   **Session types for agent protocols**: Multi-agent communication is type-safe and deadlock-free
-   **Confidence as type**: Uncertainty can be expressed in the type system (dependent types on probability, lattice-valued propositions)

The language is designed so humans and agents can collaborate at different depths of the same codebase &#x2014; agents reasoning about proofs while humans read the surface syntax.


<a id="orge31d626"></a>

# Open Extension, Closed Verification

New types, traits, instances, and bundles can always be added (open world). But verification is closed: once a program type-checks, adding new code cannot break existing guarantees. This is achieved through:

-   Parametric polymorphism (theorems for free)
-   QTT linearity (resources cannot be duplicated or discarded silently)
-   Session type duality (both endpoints of a protocol must agree)
-   Monotonic constraint propagation (type inference only accumulates information)
-   Capability security (authority cannot be forged, only delegated; see [Capability Security](CAPABILITY_SECURITY.md))
