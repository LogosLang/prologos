- [Core Values](#org1fb5c6e)
  - [Correctness Through Types](#orge765c87)
  - [Simplicity of Foundation](#orga658b0c)
  - [Progressive Disclosure](#org82c1062)
  - [Pragmatism with Rigor](#org39b4720)
- [Decomplection](#orgabec0bb)
  - [Collections and Backends](#org06557ab)
  - [Schema / Defn and Trait Bundles](#orgf716e3a)
  - [No Trait Hierarchies &mdash; Bundles Only](#org1536335)
  - [Session / Defproc for Protocol Types](#org22c274f)
  - [Data vs. Control](#org8fdbee4)
  - [Compile-Time vs. Runtime](#orgea192a6)
- [Layered Architecture](#org6251ebf)
- [First-Class by Default](#org8fe7ae5)
  - [The Session Types Lesson](#org674a486)
  - [Application](#org96c27c0)
  - [Relationship to Other Principles](#org6408406)
- [The Most Generalizable Interface](#org4f5da7d)
- [Homoiconicity as Invariant](#org1c4ebd9)
- [AI-First Design](#org3981845)
- [Spec as Living Interface](#org53f3134)
  - [Spec as Living Interface](#org3e32559)
  - [Open Metadata, Closed Semantics](#org9bb8da0)
  - [Holes are Conversations](#orgabc6b3e)
  - [Keyword Symmetry](#orga88fff3)
  - [Pi Types as Implementation Detail](#orgb1596ea)
- [Correct by Construction](#org033a7b4)
  - [Relationship to Other Principles](#org57166d0)
- [Open Extension, Closed Verification](#org23476ec)
- [Propagators as Universal Computational Substrate](#orgc971375)
  - [Relationship to Other Principles](#org036ba01)
- [Propagator-First Infrastructure](#orgb7444dc)
  - [The Composition Argument](#org4d7a8d5)
  - [When Not To Use Propagators](#org8fad36a)
  - [Stratified Propagator Networks](#org757e099)
  - [Relationship to First-Class by Default](#org357118c)
  - [Application](#orgadad18b)
- [Data Orientation](#org9a6f5ea)
  - [The Core Pattern](#orgfae9b1d)
  - [Relationship to Other Principles](#org7b369af)
  - [The Semi-Naive Evaluation Connection](#org2b22fbe)
  - [The Free Monad Analogy](#org76ad018)
  - [Design Invariant: Propagator Statelessness](#orgf384e2d)
  - [Application](#org7e29f0c)



<a id="org1fb5c6e"></a>

# Core Values

Prologos is built on a small set of non-negotiable values that inform every design decision. When principles conflict, this ordering reflects priority.

For how these values are applied in practice through our research, design, and implementation process, see [DESIGN<sub>METHODOLOGY.org</sub>](DESIGN_METHODOLOGY.md).


<a id="orge765c87"></a>

## Correctness Through Types

The type system is the primary mechanism for ensuring program correctness. Dependent types, linear types, and session types are not academic curiosities &mdash; they are practical tools for eliminating entire classes of bugs at compile time. A well-typed Prologos program makes illegal states unrepresentable.


<a id="orga658b0c"></a>

## Simplicity of Foundation

The language rests on a minimal, uniform foundation: homoiconic terms with prefix notation. Every syntactic form &mdash; types, expressions, sessions, processes &mdash; shares a single AST representation. Complexity is built through composition, not special cases. The grammar should fit on one page.


<a id="org82c1062"></a>

## Progressive Disclosure

A user should be productive on day one with simple functional programming. The full power of dependent types, session types, linear types, and logic programming reveals itself gradually as understanding deepens. No feature is mandatory. The same codebase can be read at multiple depths by collaborators with different expertise.


<a id="org39b4720"></a>

## Pragmatism with Rigor

Deep theory hides behind an approachable surface. The Curry-Howard correspondence, lattice-theoretic constraint propagation, and pi-calculus foundations are there &mdash; but users interact with `spec`, `defn`, `session`, and `defproc`, not Greek letters. Proofs are constructed automatically by proof search when possible.


<a id="orgabec0bb"></a>

# Decomplection

*Decomplect*: to unbraid, unweave &mdash; to separate things that are incidentally coupled. This is a central design philosophy borrowed from Clojure's Rich Hickey, applied at every level of the language.


<a id="org06557ab"></a>

## Collections and Backends

Collection abstractions (Seqable, Buildable, Foldable, Indexed, Keyed, Setlike) are decoupled from their concrete backends (RRB-Tree, CHAMP, thunked cons). Users program against traits; implementations are swappable with zero code changes. Adding a new backend (e.g., B+ tree for sorted maps) requires only implementing the trait interface.


<a id="orgf716e3a"></a>

## Schema / Defn and Trait Bundles

Data shape (`schema`) is decoupled from behavior (`defn` / `impl`). Trait bundles (`bundle Numeric := (Add, Sub, Mul, Neg, Abs, FromInt)`) decomplect trait inheritance &mdash; bundles are conjunctive (AND), not implicative (IMPLIES). This avoids the diamond problem and superclass brittleness of Haskell/Rust.


<a id="org1536335"></a>

## No Trait Hierarchies &mdash; Bundles Only

Prologos does not support trait hierarchies, supertraits, or trait inheritance. This is a non-negotiable design principle, not a missing feature.

The entire rationale for the `bundle` concept is to replace hierarchical inheritance with flat, conjunctive composition:

-   `bundle Num := (Numeric, Comparable)` is pure sugar, expanded at parse time into a flat conjunction: `(Add A) (Sub A) ... (Eq A) (Ord A)`
-   No trait *implies* another trait. No trait *requires* another trait as a precondition. Each trait is independent.
-   `:include` on a trait refers only to bundled traits as conjunctive refinement with set semantics (de-duplication). It does NOT establish a hierarchy.

Why this matters:

1.  **No diamond problem**: There is no lattice of traits to navigate
2.  **No superclass brittleness**: Adding/removing a trait from a bundle never breaks downstream code &mdash; it only changes the expansion
3.  **Closed under composition**: Bundles compose bundles, all the way down
4.  **Simple mental model**: A bundle IS a set of traits. `:include` is set union. There is no inheritance graph to reason about.

Concretely, the following is **illegal** in Prologos:

```prologos
;; WRONG: This implies BoundedLattice inherits from Lattice
trait BoundedLattice {A : Type}
  :includes (Lattice A)     ;; NO --- traits do not include other traits
  top : A

;; RIGHT: Use a bundle for composition
bundle BoundedLattice := (Lattice, HasTop)

trait HasTop {A : Type}
  top : A
```

The `:include` keyword on `trait` is reserved for future bundled-trait syntax (conjunctive refinement), never for hierarchical inheritance.


<a id="org22c274f"></a>

## Session / Defproc for Protocol Types

Protocol specification (`session`) is decoupled from process implementation (`defproc`). A session describes *what* communication happens; a defproc describes *how* one endpoint behaves. This mirrors the spec/defn duality: session is to defproc what spec is to defn.

Because session types are first-class types, named session types compose naturally: a continuation position can reference any named session type, enabling complex protocols to be assembled from simpler building blocks. The process (`defproc`) sees a single session type regardless of whether the protocol was composed from multiple named types or defined monolithically. See [Protocols as Types](PROTOCOLS_AS_TYPES.md).


<a id="org8fdbee4"></a>

## Data vs. Control

Types and expressions (tree-structured data) use brackets: `[f x y]`. Processes (linear control flow) use indentation. This syntactic distinction reflects a genuine semantic boundary: computing values vs. sequencing actions.


<a id="orgea192a6"></a>

## Compile-Time vs. Runtime

QTT multiplicities (`:0`, `:1`, `:w`) explicitly separate type-level reasoning (erased at runtime) from value-level computation. Proofs are first-class at type-check time but vanish from the compiled output.


<a id="org6251ebf"></a>

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

Note that Layer 5 (Protocols) supports **composition through the type system**: named session types can appear in continuation positions, enabling complex protocols to be assembled from simpler phases. This is not a separate mechanism &mdash; it falls out of session types being first-class types. See [Protocols as Types](PROTOCOLS_AS_TYPES.md).


<a id="org8fe7ae5"></a>

# First-Class by Default

When introducing a language construct &mdash; types, multiplicities, session protocols, traits, propagator cells &mdash; make it a *first-class citizen*: a value that can be stored, passed, returned, abstracted over, and computed upon. The marginal cost of first-class-ness is typically modest (reification plus type rules), but the option value is unbounded. First-class constructs compose with every other first-class construct, creating a combinatorial surface area for emergent capabilities that cannot be predicted at design time.


<a id="org674a486"></a>

## The Session Types Lesson

Session types in Prologos were designed as protocol specifications. Because they were made first-class types (not a special-purpose annotation system), they could appear anywhere types appear &mdash; including as continuation type arguments to other session types. This yielded composable protocol phases: a capability that was not designed but *fell out* of the first-class decision. No amount of upfront analysis would have predicted this; it emerged from the combinatorial interaction of session types with the existing type system.

This is the general pattern: first-class-ness creates *affordances you cannot anticipate*. The architectural decision (make it first-class) precedes and enables the capability discovery (composable protocols, type-directed search, trait-polymorphic narrowing, etc.). Deferring first-class treatment "until we need it" forecloses discoveries we cannot yet name.


<a id="org96c27c0"></a>

## Application

| Construct        | First-class as          | Enables                                             |
|---------------- |----------------------- |--------------------------------------------------- |
| Types            | Values of `Type`        | Dependent types, type-level programming             |
| Multiplicities   | Lattice elements        | QTT, resource-sensitive computation                 |
| Session types    | Types in continuations  | Composable protocol phases                          |
| Traits           | Propositions / types    | Trait-polymorphic narrowing, dispatch as constraint |
| Propagator cells | Network-resident values | Cross-domain bidirectional inference                |
| Code             | `Datum` values          | Homoiconic metaprogramming                          |


<a id="org6408406"></a>

## Relationship to Other Principles

First-Class by Default is the *meta-principle* behind several existing Prologos design choices:

-   **Homoiconicity**: code is first-class data (`Datum` type with 8 constructors)
-   **Session types as types**: protocols are first-class in the type system
-   **Layered architecture**: each layer's constructs are independently useful *because* they are first-class &mdash; they compose with constructs from other layers
-   **Spec as living interface**: specs are first-class because their metadata is structured data, not opaque annotations

The principle also serves as a *design heuristic*: when uncertain whether a construct should be reified, default to yes. The cost of premature first-class-ness (unused reification machinery) is far less than the cost of premature opacity (foreclosed capabilities requiring architectural rework).


<a id="org4f5da7d"></a>

# The Most Generalizable Interface

When designing any abstraction, prefer the interface that serves the widest range of use cases without sacrificing correctness. Concretely:

-   Seq as the universal iteration protocol &mdash; every collection type implements `Seq` with native, efficient operations (`first`, `rest`, `empty?`). `LSeq` is a specific lazy sequence type, not a mandatory intermediary. Generic operations dispatch through `Seq` (or `Functor` for structure-preserving map) directly to per-type implementations. Syntactic sugar (`xs[0]`, `xs.*field`) generates trait constraints (`Indexed`, `Keyed`, `Seq`) resolved on the propagator network &mdash; not constructor-specific dispatch
-   Traits over concrete types &mdash; `Foldable` over `List`-specific folds
-   Bundles over supertraits &mdash; composition over inheritance
-   Union types over separate sum types when the domain calls for openness
-   `A?` (nilable) over `Option A` for everyday nullable values

The goal: *logical OR grows and scales without breaking priors*. Adding a new type to a union, a new trait to a bundle, or a new backend to a collection abstraction should never require modifying existing code.


<a id="org1c4ebd9"></a>

# Homoiconicity as Invariant

Homoiconicity is not a convenience &mdash; it is a *strong invariant* of the language. Every syntactic form has a canonical s-expression representation. Every piece of surface syntax can be quoted, inspected, and reconstructed. Macros operate on post-parse AST (where whitespace has been resolved), and all syntactic sugar must be expressible as data.

This invariant enables:

-   User-defined macros that are first-class language extensions
-   Code-as-data for metaprogramming, optimization, and code generation
-   Self-hosting: the compiler is a Prologos program operating on Prologos ASTs
-   AI agent self-inspection: agents can inspect and modify their own reasoning


<a id="org3981845"></a>

# AI-First Design

Prologos is designed with AI agents as first-class citizens alongside human programmers. This means:

-   **Provenance tracking**: Information flow is explicit; agents can trace how conclusions were derived
-   **Proof terms as explanation**: Every type-checked decision comes with a machine-checkable justification
-   **Homoiconic self-modification**: Agents can inspect and rewrite their own code
-   **Session types for agent protocols**: Multi-agent communication is type-safe and deadlock-free
-   **Confidence as type**: Uncertainty can be expressed in the type system (dependent types on probability, lattice-valued propositions)

The language is designed so humans and agents can collaborate at different depths of the same codebase &mdash; agents reasoning about proofs while humans read the surface syntax.


<a id="org53f3134"></a>

# Spec as Living Interface

`spec` is not merely a type signature &mdash; it is the primary interface between the programmer and the language's verification machinery. All function metadata converges at the spec: types, documentation, examples, properties, contracts, and refinements. A well-written spec should be sufficient to understand a function's behavior without reading its implementation.


<a id="org3e32559"></a>

## Spec as Living Interface

The spec is *living* because it participates in the development process:

-   **Examples** in specs can be auto-run as tests
-   **Properties** in specs can be verified by property-based testing (Phase 2) or upgraded to compile-time proof obligations (Phase 3)
-   **Contracts** in specs generate runtime assertions at function boundaries
-   **Refinements** in specs compile to Sigma types (dependent pairs with proofs)

The same spec syntax upgrades from testing to proving without modification. This is the principle of *Properties are Types in Waiting*: every `:property` in a spec has a dual life. Today it is a runtime QuickCheck property. Tomorrow it is a Pi type that the compiler verifies statically. The programmer writes the same spec; the verification backend upgrades transparently.


<a id="org9bb8da0"></a>

## Open Metadata, Closed Semantics

The spec metadata map is open to new keys (forward-compatibility). Unrecognized keys are stored but not acted upon. Recognized keys have precise, well-defined semantics. This follows the Postel principle (liberal in what you accept, conservative in what you emit) and prevents the schema explosion problem.


<a id="orgabc6b3e"></a>

## Holes are Conversations

The `??` typed hole syntax initiates a dialogue between the programmer and the type system. The type checker responds with the expected type, available bindings, and suggestions. This is not an error &mdash; it is the normal mode of interactive development in a dependently-typed language.

`??` is fundamentally different from `_` (type inference hole). `_` says "infer this for me automatically" (for the machine). `??` says "I don't know what goes here &mdash; help me" (for the human). The former is silent; the latter is a conversation.


<a id="orga88fff3"></a>

## Keyword Symmetry

The language's abstraction keywords form a symmetric system:

| Abstraction        | Keyword    | What it names                   | Composition                      |
|------------------ |---------- |------------------------------- |-------------------------------- |
| Function interface | `spec`     | Type + metadata                 | Multi-arity via `\vert`          |
| Method requirement | `trait`    | Method signature                | `:laws` via `property`           |
| Requirement group  | `bundle`   | Conjunction of traits           | Bundle includes traits/bundles   |
| Proposition group  | `property` | Conjunction of `:holds` clauses | `:includes` other properties     |
| Type abstraction   | `functor`  | Parameterized type + structure  | `:compose`, `:identity`, `:laws` |

Each keyword names a different kind of thing; metadata keys describe it progressively. The same design pattern (keyword + structured metadata) scales uniformly across the entire system.


<a id="orgb1596ea"></a>

## Pi Types as Implementation Detail

Dependent types are the *implementation substrate* &mdash; they give the type system its power. But the surface language speaks in domain terms:

-   "This function sorts lists" → `spec sort [List A] -> [List A]`
-   "Sorting requires ordering" → `:where (Ord A)`
-   "Sorting is idempotent" → `:properties (sortable-laws A)`
-   "A transducer transforms reductions" → `functor Xf {A B}`
-   "Transducers compose" → `:compose xf-compose`

Pi types, Sigma types, universe levels, and multiplicity annotations exist in `:unfolds` blocks, in the elaborator, and in the type checker. They are *available* when needed, but the primary interface is structured metadata expressed through keywords.


<a id="org033a7b4"></a>

# Correct by Construction

Prefer designs where correctness is a structural property of the architecture, not a property maintained by discipline. A correct-by- construction system makes the wrong thing hard to express rather than relying on vigilance to avoid it. This applies at every level:

-   **Type system**: illegal states are unrepresentable (dependent types, session types, QTT multiplicities)
-   **Data structures**: persistent/immutable by default; mutation is opt-in and scoped (`transient~/~persist!`)
-   **Protocols**: session types ensure both endpoints agree; violation is a type error, not a runtime crash
-   **Infrastructure**: propagator networks ensure derived state is always consistent with source state; no explicit invalidation discipline needed
-   **Resolution**: stratified propagator networks make constraint readiness and resolution structurally emergent &mdash; a constraint's readiness propagator fires when its dependencies become ground, rather than requiring a scan loop to discover it. Callbacks and defensive scanning are symptoms of resolution logic that lives outside the network.
-   **Concurrency**: linearity prevents data races; session types prevent protocol violations; capability types prevent unauthorized access

The upfront cost of correct-by-construction is higher than the ad-hoc alternative. The long-term cost is dramatically lower: every subsequent feature built on correct-by-construction foundations inherits its guarantees without additional effort. Bugs that *cannot exist* need not be tested for, debugged, or documented as caveats.

This principle is the philosophical foundation for [Propagator-First Infrastructure](#orgb7444dc): building the LSP server's state management on propagator cells makes incremental consistency a structural property of the network topology, rather than a property maintained by hand-written invalidation code.


<a id="org57166d0"></a>

## Relationship to Other Principles

-   **Correctness Through Types** is correct-by-construction applied to user programs via the type system
-   **Open Extension, Closed Verification** is correct-by-construction applied to the open-world assumption: new code cannot break verified guarantees
-   **Propagator-First Infrastructure** is correct-by-construction applied to tooling and infrastructure: derived state is always consistent because the network enforces it
-   **Gödel Completeness** is correct-by-construction applied to termination: every computation on the propagator network provably halts, not because of fuel bounds, but because of structural properties (finite lattices, well-founded measures, widening convergence). Non-termination is unrepresentable in the decidable kernel. See [GÖDEL<sub>COMPLETENESS.org</sub>](GÖDEL_COMPLETENESS.md).


<a id="org23476ec"></a>

# Open Extension, Closed Verification

New types, traits, instances, and bundles can always be added (open world). But verification is closed: once a program type-checks, adding new code cannot break existing guarantees. This is achieved through:

-   Parametric polymorphism (theorems for free)
-   QTT linearity (resources cannot be duplicated or discarded silently)
-   Session type duality (both endpoints of a protocol must agree, preserved through composition)
-   Monotonic constraint propagation (type inference only accumulates information)
-   Capability security (authority cannot be forged, only delegated; see [Capability Security](CAPABILITY_SECURITY.md))


<a id="orgc971375"></a>

# Propagators as Universal Computational Substrate

Prologos is an *exploration project*. The central thesis is that propagator networks &mdash; as described by Radul and Sussman, extended by Forbus and de Kleer &mdash; constitute a universal computational substrate capable of unifying type inference, constraint solving, logic programming, session verification, and incremental compilation under a single architectural model.

This thesis is not contingent. It is the reason this project exists.

Every avenue in the design space must be explored. Declining to pursue an architectural possibility because "it might not pay off" or "the performance case is weak" is antithetical to the project's purpose. The value of exploration is not limited to the branches that succeed:

-   **A refutation is a discovery**: if propagator-driven unification proves structurally inferior to algorithmic unification, that is a genuine contribution &mdash; a result that others navigating this design space can use. Map the dragons.

-   **Failure is forward motion**: a failed branch constrains the search space. It tells us where the architecture's limits are and redirects attention to branches that remain open. We fail forward, adjust our approach, and descend other branches.

-   **The fixpoint is the starting point**: "Propagators as a Universal Computational Substrate" is our greatest fixpoint. We begin there and work outward, meeting the rest of the world with what we discover. If a specific propagator application (cell-tree unification, ATMS solver, propagator-driven narrowing) encounters a genuine limit, we mark it and explore adjacent branches in the design space.

-   **Completeness over caution**: the design space is rich. We owe it thoroughness. An unexplored branch is a missed opportunity for learning. Timidity in exploration is the only failure mode that produces no knowledge.

This principle supersedes performance arguments, effort estimates, and risk assessments when evaluating whether to pursue an architectural direction. The question is not "will this pay off?" but "will we learn something valuable?" The answer is always yes.


<a id="org036ba01"></a>

## Relationship to Other Principles

-   **Propagator-First Infrastructure** is the *practical application* of this thesis: default to propagator cells because we are exploring what happens when everything is on the network.
-   **First-Class by Default** shares the same philosophy: make it first-class not because you need it today, but because unexplored composition is unexplored capability.
-   **Correct by Construction** provides the safety net: propagator networks with finite lattices and well-founded measures guarantee termination, so exploration cannot produce unsound divergence.


<a id="orgb7444dc"></a>

# Propagator-First Infrastructure

When building internal infrastructure &mdash; caches, indices, registries, environment maps &mdash; default to propagator cells over mutable hash tables. The synergy of composing propagator networks exceeds the sum of their parts: each new propagator-backed structure can participate in cross-domain information flow with every other propagator-backed structure, creating emergent capabilities that isolated mutable stores cannot provide.


<a id="org4d7a8d5"></a>

## The Composition Argument

A propagator cell is a monotonic accumulator with automatic dependency propagation. A hash table is a mutable store with manual invalidation. The difference is small for a single structure in isolation. But when *multiple* structures coexist, propagator networks compose:

-   A type index cell (srcloc → type) that depends on a metavariable cell automatically updates when the meta is solved &mdash; no explicit "zonk the index" pass needed.
-   A definition location cell that depends on module loading automatically reflects newly-loaded modules &mdash; no explicit "rebuild the index" step.
-   A diagnostic cell that depends on type index cells automatically retracts when the source is re-elaborated &mdash; incremental re-checking falls out of the network topology.

With mutable hash tables, each of these cross-cutting dependencies requires explicit plumbing (invalidation callbacks, dirty flags, rebuild passes). With propagator cells, the plumbing is the network itself.


<a id="org8fad36a"></a>

## When Not To Use Propagators

Not all state is monotonic. Propagators are the wrong choice when:

-   The value can decrease or retract (use ATMS-backed cells instead, which compose *with* the propagator network for non-monotonic recovery)
-   The access pattern is pure lookup with no dependency tracking (rare in practice for infrastructure that participates in the compilation pipeline)
-   The structure is ephemeral and single-use (per-command scratch space)

Even for non-monotonic cases, the design pattern of *monotonic layers with ATMS-backed retraction* often applies. This recovers non-monotonic behavior within the propagator paradigm rather than stepping outside it.


<a id="org757e099"></a>

## Stratified Propagator Networks

When a system requires non-trivial control flow over propagation &mdash; resolution that depends on quiescence, constraint retry that depends on readiness, actions that perturb state at a higher stratum &mdash; the design pattern is *stratified propagator networks*, not imperative orchestration.

Each stratum is a propagator layer with its own lattice:

-   Stratum 0: base propagation (type unification, lattice merges)
-   Stratum 1: readiness detection (constraint cells whose dependencies are ground)
-   Stratum 2: resolution commitment (trait lookup, unification retry)

Inter-stratum edges use the same Galois connection pattern as cross-domain bridges (session→effect, module→file). Stratum *n+1* activates only after stratum *n* reaches quiescence. Changes from stratum *n+1* perturb stratum *n*, restarting the cascade. The layered recovery principle ensures the non-monotonicity of perturbation is recovered through structural ordering.

This pattern replaces:

-   **Callback parameters** that inject resolution logic across module boundaries
-   **Scan loops** that iterate constraint stores to find ready constraints
-   **Immediate paths** that eagerly resolve at registration time
-   **Wakeup indices** that manually track which constraints depend on which metas

All of these are symptoms of resolution logic living *outside* the propagator network. Stratified propagator networks bring resolution *into* the network, making readiness and resolution structurally emergent rather than imperatively discovered.

**Provenance**: Discovered during Track 6 Phase 8d analysis (2026-03-17). The existing stratified resolution loop (`run-stratified-resolution!`) is a hand-written orchestrator with this pattern partially implemented. The callbacks it invokes are vestigial &mdash; the loop itself is the load-bearing path. Track 7 replaces the hand-written loop with actual stratified propagator layers (S(-1), S0, L1, L2) using Gauss-Seidel scheduling across layers.

**Termination**: Each stratum terminates individually (Level 1: Tarski fixpoint on finite lattice). Cross-stratum feedback terminates via well-founded measure (Level 2: type depth decreases per resolution cycle). The full layered quiescence terminates as a composition of per-layer guarantees. See [GÖDEL<sub>COMPLETENESS.org</sub>](GÖDEL_COMPLETENESS.md) for the hierarchy of termination guarantees and the decidability discipline for propagator networks.


<a id="org357118c"></a>

## Relationship to First-Class by Default

This principle is the infrastructure-facing corollary of [First-Class by Default](#org8fe7ae5). First-Class by Default says: reify language constructs as first-class values. Propagator-First Infrastructure says: build internal state as first-class network participants. Both principles produce the same kind of emergent composition &mdash; the combinatorial interaction of independently-designed components creating capabilities that no single component was designed to provide.


<a id="orgadad18b"></a>

## Application

| Infrastructure        | Na&iuml;ve Approach          | Propagator-First Approach                                             |
|--------------------- |---------------------------- |--------------------------------------------------------------------- |
| Type index            | `(make-hash)` + manual zonk  | Cell per position; metas propagate solutions                          |
| Definition registry   | `(hasheq)` + rebuild on load | Cell per name; module loading propagates                              |
| Diagnostic set        | Recompute on save            | Cell per form; elaboration changes propagate                          |
| Module exports        | Snapshot at load time        | Cell per module; re-export propagates                                 |
| Completion cache      | Rebuild periodically         | Cell per namespace; imports propagate                                 |
| Constraint resolution | Callback + scan loop         | Readiness cell per constraint; resolution propagator fires when ready |


<a id="org9a6f5ea"></a>

# Data Orientation

Prefer structures where behavior is derived from data transformations rather than embedded in imperative control flow. Effects become first-class descriptions of intent, interpreted at explicit control boundaries rather than executed in-line.

This principle addresses a specific form of incidental complexity: *control flow with embedded effects*. When a function braids pure computation with effectful operations (state mutations, recursive callbacks, registry lookups), the result is hard to reason about, hard to observe, hard to test in isolation, and hard to roll back during speculation. Data orientation separates the *what* (a description of the work to be done) from the *when* and *how* (interpretation at a controlled boundary).


<a id="orgfae9b1d"></a>

## The Core Pattern

Instead of:

```
resolve-constraint! c =
  zonk type-args                   ;; pure
  lookup instance registry         ;; read effect
  solve-meta! dict-meta solution   ;; write effect, re-entrant
```

Data orientation produces:

```
describe-resolution c =
  zonk type-args                                  ;; pure
  lookup instance registry                        ;; read (from cell)
  return (ResolveTraitDict dict-meta solution)     ;; DATA: action descriptor

interpret actions =
  for each action in actions:
    execute action, collect new descriptors
  if new descriptors: iterate
  else: fixpoint
```

The action descriptors form a *free algebra* over the effect signature. The interpreter is the *fold* that evaluates the algebra.

The next step beyond action descriptors: make *readiness itself* a cell value. Rather than scanning constraint stores to collect action descriptors, a readiness propagator watches each constraint's dependency cells and transitions a readiness cell from `pending` to `ready` when all dependencies are ground. The action descriptor is the cell value; the interpreter reads ready cells rather than scanning for them. This eliminates the imperative scan loop and makes the resolution pipeline fully propagator-driven (see [Stratified Propagator Networks](#org757e099) under Propagator-First Infrastructure).

This separation yields:

1.  **Inspectability**: the worklist is data &mdash; it can be logged, counted, visualized in the observatory, validated for confluence
2.  **Testability**: resolution logic can be unit-tested with mock descriptors without running the full elaborator
3.  **Ordering control**: the interpreter chooses evaluation order, enabling stratification without modifying the resolution logic itself
4.  **Totality**: the interpreter can enforce fuel limits, detect cycles, and guarantee termination &mdash; structurally, not by convention
5.  **Speculation safety**: descriptors are data in cells, captured by snapshots


<a id="org7b369af"></a>

## Relationship to Other Principles

Data Orientation is the *unifying principle* behind several existing Prologos design choices:

-   **Propagator-First Infrastructure**: data (cells) over state (mutable hashes). Propagators are data-oriented by construction &mdash; they read cells, write cells, and compute pure transformations. Data orientation generalizes this pattern beyond infrastructure to *all* effectful computation.

-   **Layered Recovery Principle** (`EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org`): "reasoning about effects happens monotonically&hellip; executing effects happens at a control boundary." This *is* data orientation applied to IO effects. Data orientation recognizes the same pattern applies to internal effects (constraint resolution, trait lookup, meta solving).

-   **Correct by Construction**: data structures that make wrong states unrepresentable. Action descriptors make *wrong orderings* unrepresentable &mdash; the interpreter controls ordering, not the producer of descriptors.

-   **Decomplection**: separating what from when. Data orientation decomplects effect description from effect interpretation, the same way session types decomplect protocol specification from process implementation.

-   **First-Class by Default**: action descriptors are first-class data &mdash; storable, passable, inspectable, serializable. Embedded effects are none of these things.


<a id="org2b22fbe"></a>

## The Semi-Naive Evaluation Connection

Data orientation connects to Datalog's semi-naive evaluation. Naive evaluation re-scans all rules on every iteration. Semi-naive evaluation tracks the *delta* (newly derived facts) and only applies rules affected by the delta. In propagator terms: propagators fire only when their input cells change &mdash; the network's worklist is the delta. This is inherently data-oriented: the worklist is data describing what needs to happen next.


<a id="org76ad018"></a>

## The Free Monad Analogy

Categorically, data orientation implements the *free monad* pattern. Instead of executing effects immediately, the system builds a description of effects (the free algebra) and interprets them in a controlled loop (the fold). The description is a value; the interpretation is a function. Both are first-class, testable, and composable.


<a id="orgf384e2d"></a>

## Design Invariant: Propagator Statelessness

Propagators must be *stateless pure fire functions*: `net \to net`. Any state that matters for provenance, speculation, or observability must live in cells, not in closures. A propagator that captures mutable state in its closure creates invisible state that:

-   Is not captured by `save-meta-state` / `restore-meta-state!`
-   Is not observable by the observatory
-   Is not subject to confluence guarantees
-   Leaks across speculative branches

This invariant ensures that the propagator network remains the single source of truth. Threshold propagators (`make-threshold-fire-fn`, `make-barrier-fire-fn`) demonstrate the correct pattern: they read cell values on every invocation, compute a predicate, and either run the body or return the network unchanged. The "memory" is in the cells, not the closure. On monotone lattices, this stateless approach is observationally identical to a stateful "fire once" propagator &mdash; but preserves full observability.


<a id="org7e29f0c"></a>

## Application

| Domain            | Imperative (effects-in-control-flow)          | Data-Oriented (effects-as-descriptors)                |
|----------------- |--------------------------------------------- |----------------------------------------------------- |
| Constraint retry  | `retry-constraints-via-cells!` mutates status | Readiness propagator produces `RetryConstraint` data  |
| Trait resolution  | `resolve-fn` callback calls `solve-meta!`     | Resolution propagator produces `ResolveTraitDict`     |
| Error reporting   | `raise` / `error` during resolution           | Error descriptors accumulated in error cell           |
| Instance registry | `hash-set!` on mutable parameter              | Cell write to CHAMP-backed registry cell              |
| IO effects        | Execute during AST walk                       | Collect ordering in session cells; execute at barrier |
