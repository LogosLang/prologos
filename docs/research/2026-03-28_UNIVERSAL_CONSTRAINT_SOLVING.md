# Universal Domain Constraint Solving: Algebraic Structure Determines Strategy

**Date**: 2026-03-28
**Status**: Research note
**Attribution**: Based on outside conversation and research scan for Prologos universal constraint solving vision.
**Cross-references**:
- Module Theory note: `../research/2026-03-28_MODULE_THEORY_LATTICES.md`
- Algebraic Embeddings note: `../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md`
- PTF Master: `../tracking/2026-03-28_PTF_MASTER.md`
- SRE Master: `../tracking/2026-03-22_SRE_MASTER.md`
- BSP-LE Master: `../tracking/2026-03-21_BSP_LE_MASTER.md`

---

## 1. Thesis

Any domain with sufficient algebraic structure supports automatic constraint solving via propagators. The algebraic structure of the domain *determines* what solving strategies are available, how efficient they can be, and whether decidability is guaranteed. A language with a propagator-based constraint engine can inspect the algebraic properties of a domain and automatically select the optimal solving strategy — making a single constraint operator (`#=`) domain-polymorphic.

This note synthesizes six lines of research into a unified vision: the algebraic CSP dichotomy (Bulatov-Zhuk), lattice-based constraint propagation, domain-polymorphic unification (E-unification), residuated lattices and backward reasoning, monotone fixpoint computation (CALM), and the DPLL(T) modular solver architecture.

---

## 2. The Algebraic CSP Dichotomy: Structure Determines Tractability

### The Bulatov-Zhuk Theorem

The CSP dichotomy theorem, proved independently by Bulatov and Zhuk (FOCS 2017, JACM 2020), resolves a conjecture of Feder and Vardi: every finite-domain CSP is either solvable in polynomial time or NP-complete, with no intermediate complexity. The dividing line is purely algebraic: a CSP over a finite domain D is tractable if and only if its polymorphism algebra admits a **Taylor term** — an idempotent operation satisfying a non-trivial identity.

The key insight is that the complexity of a CSP depends solely on the **polymorphisms** of the constraint relations — the functions that preserve all constraints simultaneously. A domain whose polymorphisms include weak near-unanimity (WNU) operations of all arities >= 3 is precisely the class solvable by local consistency propagation. Domains with majority polymorphisms admit bounded-width resolution. Domains with Mal'cev polymorphisms admit Gaussian-like elimination. Domains lacking any Taylor term are NP-complete.

Recent work by Barto, Brady, Bulatov, Kozik, and Zhuk (2021) unifies the three algebraic approaches to the CSP — absorption theory (local consistency), Bulatov's theory (colored graphs), and Zhuk's theory (bridge absorption) — via minimal Taylor algebras, providing a single framework for tractability classification.

### Implications for Prologos

The polymorphism classification provides a **decision procedure for strategy selection**. When a constraint domain is registered in the propagator network, its algebraic structure can be inspected:

| Algebraic Property | Solving Strategy | Prologos Component |
|---|---|---|
| Taylor term present | Tractable; choose sub-strategy | Universal gate |
| WNU polymorphisms | Local consistency propagation | Core propagator loop |
| Majority operation | Bounded-width resolution | SRE relation engine |
| Mal'cev operation | Gaussian elimination | Linear constraint solver |
| Semilattice operation | Meet/join propagation | Cell lattice operations |
| No Taylor term | NP-complete; need search | ATMS + backtracking |

The propagator network does not need to know which strategy to use at design time. The algebraic structure of the domain dictates the strategy at registration time. This is the CSP-theoretic justification for the "one engine, many theories" meta-pattern identified in the Algebraic Embeddings note.

---

## 3. Lattice-Based Constraint Propagation

### Abstract Interpretation as Constraint Solving

Abstract interpretation (Cousot and Cousot, 1977) is fundamentally constraint solving over lattice domains. A program analysis computes the least fixpoint of a system of equations over an abstract lattice — which is exactly what a propagator network does. The connection runs deeper than analogy:

- **Propagators = abstract transfer functions**: Each propagator computes an approximation of one constraint's effect on cell values. This mirrors abstract transformers in static analysis.
- **Chaotic iteration = propagator scheduling**: The abstract interpretation fixpoint loop applies transfer functions in some order until stability. The propagator network's scheduler does the same. Both converge to the same fixpoint regardless of order (by Tarski's theorem on monotone functions over complete lattices).
- **Widening/narrowing = approximation strategies**: When lattices have infinite ascending chains, abstract interpretation uses widening to force convergence and narrowing to recover precision. Propagator networks face the same challenge with infinite-domain cells.

The modularity of abstract interpretation is directly relevant: the same fixpoint engine can be parameterized with different abstract domains (intervals, polyhedra, octagons, congruences). Each domain is a lattice with its own transfer functions. This is exactly the Prologos architecture — the propagator engine is domain-agnostic; domains register their lattice structure and propagators.

### Lattice Operations as Constraint Primitives

The fundamental operations of constraint propagation map to lattice operations:

- **Join (⊔)**: Merging information from multiple sources. When two propagators produce information about the same cell, the cell takes their join. This is constraint conjunction — the cell's value must satisfy all constraints.
- **Meet (⊓)**: Computing the intersection of possibility spaces. Used in domain filtering — when a constraint rules out some values, the cell's domain is met with the constraint's filter.
- **Complement (¬)**: Negation-as-failure, assumption retraction in the ATMS. Only available in Boolean or complemented lattices.
- **Residuation (→)**: Backward reasoning — given an output constraint, what input constraint is needed? Available in Heyting algebras and residuated lattices.

The hierarchy of lattice types determines which operations are available:

```
Partial order         → monotone propagation only
Join-semilattice      → forward accumulation (Datalog-like)
Lattice               → forward + backward filtering
Distributive lattice  → efficient meet/join interleaving
Heyting algebra       → residuation (implication, backward reasoning)
Boolean algebra       → full complement (SAT/CDCL, ATMS)
```

This hierarchy is the algebraic spine of the Prologos constraint engine.

---

## 4. Domain-Polymorphic Unification

### Beyond Free Term Algebras

Classical unification (Robinson, 1965) works over free term algebras — terms built from constructors with no equations. Real constraint domains have equations: commutativity (a + b = b + a), associativity ((a + b) + c = a + (b + c)), idempotency (a ∨ a = a), distributivity, etc. E-unification generalizes to handle these.

**E-unification** asks: given terms s and t and an equational theory E, find a substitution σ such that sσ =_E tσ. The complexity and decidability depend entirely on the equational theory:

| Theory E | Unification Type | Decidability | Example |
|---|---|---|---|
| Empty (free algebra) | Syntactic | Linear time | Standard Prolog |
| Commutativity (C) | C-unification | Finitary | Set operations |
| Associativity-Commutativity (AC) | AC-unification | Finitary | Arithmetic |
| Idempotency + AC | ACI-unification | Finitary | Lattice operations |
| Boolean algebra | Boolean unification | Finitary | ATMS assumptions |
| Distributive lattice | DL-unification | Finitary | Type lattice |
| Abelian groups | AG-unification | Unitary | Linear constraints |
| General | Undecidable | — | Arbitrary rewriting |

### Order-Sorted E-Unification

Smolka and others extended E-unification to order-sorted signatures with parametric polymorphism — exactly the setting of Prologos type inference. Subsort declarations propagate to complex type expressions (e.g., `List Nat <: List Int` from `Nat <: Int`). The Maude system implements order-sorted unification modulo common equational axioms (AC, C, identity), demonstrating that this is practical.

### Connection to Prologos

Prologos type inference currently uses syntactic unification over the type term algebra. The E-unification perspective reveals what we gain by enriching the theory:

- **Commutative unification for union types**: `<Int | String>` = `<String | Int>` requires C-unification. Currently handled ad hoc; could be systematic.
- **AC-unification for trait constraint sets**: Trait constraints are associative-commutative (order and grouping don't matter). AC-unification would handle constraint set matching natively.
- **Lattice unification for subtyping**: The type lattice has meet and join. Unification modulo lattice equations would subsume the current subtype checking.
- **The `#=` operator**: A domain-polymorphic constraint operator that dispatches to the appropriate E-unification algorithm based on the domain's equational theory. For free terms, it's Robinson unification. For lattice domains, it's lattice unification. For arithmetic, it's AC-unification.

---

## 5. Residuated Lattices and Backward Reasoning

### Residuation as the Algebra of Backward Propagation

A **residuated lattice** is a lattice (L, ⊔, ⊓) equipped with a monoid operation (·) and two residuals (\\, /) such that:

```
a · b ≤ c  ⟺  a ≤ c / b  ⟺  b ≤ a \ c
```

The residuals are the right and left adjoints of multiplication — they form a Galois connection. This is precisely the algebraic structure needed for backward constraint propagation: given a constraint on the output (c) and one input (b), compute the tightest constraint on the other input (c / b).

In a Heyting algebra (the algebraic model of intuitionistic logic), the residual of meet is implication:

```
a ⊓ b ≤ c  ⟺  a ≤ b → c
```

This gives backward reasoning for free: if we know the output must be at least c, and one input is b, the other input must be at least b → c.

### Narrowing in Functional-Logic Programming

Narrowing, the core evaluation strategy of languages like Curry, is residuation in disguise. When a function application `f(x) = c` cannot be evaluated because x is unbound, narrowing inverts f — it computes the set of values x could take to produce c. This is precisely computing the residual: x ∈ f \ c.

Curry distinguishes two operational modes:
- **Narrowing**: Non-deterministically instantiate free variables by unifying with function left-hand sides. Used for user-defined functions.
- **Residuation**: Suspend evaluation until variables are bound to ground values. Used for built-in operations and external functions.

The algebraic connection: narrowing works when the domain has a free algebra structure (constructors enumerate possibilities). Residuation works when the domain has a residuated lattice structure (the residual computes the backward answer directly). Both are instances of backward reasoning; the domain's structure determines which is appropriate.

### Connection to Prologos

The propagator network already performs forward propagation (monotone information accumulation). Residuation provides the dual — backward propagation:

- **Type inference backward reasoning**: Given a required return type, propagate constraints backward to function arguments. The type lattice, viewed as a Heyting algebra, provides implication as the backward propagator.
- **Narrowing for pattern matching**: When a match expression needs a specific constructor, narrowing on the scrutinee propagates this requirement backward. This is residuation in the constructor lattice.
- **Session type backward reasoning**: Given a required final session state, compute what protocol steps must occur. The session quantale (see Module Theory note) provides residuation.
- **QTT multiplicity backward propagation**: Given multiplicity requirements on a result, propagate multiplicity constraints backward through the term. The multiplicity semiring has residuation.

The BSP-LE logic engine's narrowing support can be understood as installing residuated-lattice-derived backward propagators alongside the standard forward propagators.

---

## 6. Monotone Fixpoint Computation and CALM

### The CALM Theorem

The CALM (Consistency As Logical Monotonicity) theorem, developed by Hellerstein and Alvaro, states: a distributed program has a consistent, coordination-free implementation if and only if it is monotonic. Monotonic programs accumulate information without retraction — their output grows monotonically with their input.

This theorem, originally about distributed systems, applies directly to constraint propagation:

- **Propagator networks are monotone programs**: Each propagator is a monotone function; cell values only increase (in the information ordering). The network computes a monotone fixpoint.
- **Coordination-free = scheduler-independent**: CALM guarantees that monotone propagator networks converge to the same fixpoint regardless of propagator firing order. This is exactly Tarski's fixpoint theorem applied at the systems level.
- **Non-monotonicity requires coordination**: Operations like negation, retraction, or assumption management (ATMS nogood recording) are non-monotone and require explicit coordination — stratification, backtracking, or truth maintenance.

### Datalog as Monotone Constraint Solving

Datalog computes the least fixpoint of a set of Horn clauses — a monotone operation over the lattice of fact sets. Each rule is a propagator: given input facts, derive new facts. The immediate consequence operator T_P is monotone, and its least fixpoint equals the minimal model.

The connection to Prologos:

- **SRE relation engine = Datalog core**: The SRE's relation engine computes fixpoints of relational constraints — exactly Datalog-style monotone fixpoint computation.
- **Stratification = CALM boundary**: When the SRE needs negation (e.g., closed-world assumption on traits), it crosses the CALM boundary and requires stratification — computing fixpoints in layers where each layer is monotone but layer transitions may negate.
- **ATMS = non-monotone coordination layer**: The ATMS manages assumptions and retractions — the non-monotone operations that CALM says require coordination. The ATMS sits above the monotone propagator layer, providing the coordination protocol.

### Fixpoint Hierarchy

The algebraic structure determines the fixpoint computation:

```
Monotone on finite lattice  → guaranteed termination, unique least fixpoint
Monotone on infinite lattice → may not terminate; need widening
ω-continuous                 → Kleene iteration converges
Scott-continuous             → denotational fixpoint = operational fixpoint
Non-monotone                 → requires stratification or well-founded semantics
```

Each level corresponds to a class of constraint problems and determines what guarantees the solver provides.

---

## 7. SMT Solvers: The DPLL(T) Architecture

### Modular Constraint Solving

The DPLL(T) framework, which underlies modern SMT solvers (Z3, CVC5), provides a proven architecture for modular constraint solving. The architecture separates:

- **SAT engine (CDCL)**: Manages Boolean structure — propositional satisfiability, clause learning, backtracking. Operates on the Boolean algebra of assumptions.
- **Theory solvers (T)**: Domain-specific decision procedures. Each handles a class of constraints (linear arithmetic, arrays, bit-vectors, strings, etc.). The theory solver checks consistency of a conjunction of ground literals in its theory.
- **Nelson-Oppen combination**: When multiple theories interact, the combination procedure exchanges equalities between shared variables, ensuring global consistency.

The insight: the SAT engine handles the Boolean algebra layer (search, backtracking, learning); theory solvers handle domain-specific lattice propagation. This separation mirrors the Prologos architecture where the ATMS handles assumption management (Boolean) while propagator cells handle domain-specific constraint propagation (lattice).

### Theory Solver Interface

Each DPLL(T) theory solver implements a standard interface:

1. **Assert**: Add a literal to the current context
2. **Check**: Is the current context consistent?
3. **Propagate**: Derive new literals implied by the current context
4. **Explain**: Given a derived literal, produce a clause justifying it
5. **Backtrack**: Retract assertions to a previous state

This interface is essentially a propagator interface with backtracking. The "Assert" is cell update; "Propagate" is propagator firing; "Check" is contradiction detection; "Explain" is justification (ATMS label); "Backtrack" is assumption retraction.

### Commonly Supported Theories

| Theory | Domain | Key Operations | Lattice Structure |
|---|---|---|---|
| EUF (equality + uninterpreted functions) | Terms | Congruence closure | Free algebra |
| LIA/LRA (linear arithmetic) | Z/Q | Simplex, Fourier-Motzkin | Ordered field |
| BV (bit-vectors) | {0,1}^n | Bit-blasting, word-level | Boolean algebra |
| Arrays | Store/Select | Read-over-write | Functional lattice |
| Strings | Sequences | Length, regex membership | Free monoid |
| Datatypes | ADTs | Constructor/selector | Free term algebra |

### Connection to Prologos

The DPLL(T) architecture validates the Prologos design:

- **ATMS = SAT engine**: The ATMS manages Boolean assumptions and learns nogoods (clauses). It provides the coordination layer for non-monotone search.
- **Propagator cells = theory solvers**: Each domain's propagators implement the theory solver interface — assert (cell update), propagate (firing), check (contradiction), explain (justification).
- **The missing piece: Nelson-Oppen for propagators**: When type constraints, session constraints, and multiplicity constraints interact, Prologos needs a combination procedure. The module-theoretic decomposition (see Module Theory note) provides this — the quotient module structure identifies inter-theory boundaries.

---

## 8. The Algebraic Structure Hierarchy

Synthesizing all six research threads, the following hierarchy emerges. Each algebraic structure includes all capabilities of structures above it and adds new ones:

```
Structure                 Capabilities                           Prologos Use
─────────────────────────────────────────────────────────────────────────────
Partial order             Monotone forward propagation           Cell ordering
Join-semilattice          Information accumulation               Core cells
Lattice                   Forward + domain filtering             Type inference
Distributive lattice      Efficient meet/join interleaving       Constraint decomposition
Heyting algebra           Residuation (backward reasoning)       Backward type propagation
Boolean algebra           Full complement, CDCL, ATMS            Assumption management
Residuated lattice        Backward propagation via residuals     Narrowing, session backward
Quantale                  Resource-aware composition             QTT multiplicities, sessions
Quantale module           Full algebraic decomposition           Module-theoretic analysis
```

### Additional Structure Overlays

Beyond the lattice hierarchy, additional algebraic properties enable specific strategies:

- **Taylor polymorphisms** → local consistency is complete (no search needed)
- **Mal'cev operations** → Gaussian elimination applies
- **Majority operations** → bounded-width resolution
- **Semilattice operations** → meet/join propagation is complete
- **Free algebra structure** → narrowing (constructor enumeration)
- **AC-equational theory** → AC-unification for constraint matching

### The Strategy Selection Algorithm

Given a constraint domain D registered with the propagator network:

1. **Inspect lattice type**: Is D a partial order? Lattice? Distributive? Heyting? Boolean?
2. **Inspect equational theory**: Does D have commutativity? Associativity? Idempotency?
3. **Inspect polymorphisms**: Does D have Taylor terms? WNU? Majority? Mal'cev?
4. **Select strategy**:
   - Boolean + finite → CDCL/ATMS
   - Heyting → forward + backward propagation via residuation
   - Distributive + Taylor → local consistency (propagation alone is complete)
   - Distributive + Mal'cev → Gaussian elimination
   - Free algebra → narrowing (constructor enumeration)
   - Lattice + no Taylor → propagation + search (ATMS-guided)
   - Partial order only → monotone accumulation, no filtering

---

## 9. The `#=` Operator: Domain-Polymorphic Constraint

The synthesis yields a design for a domain-polymorphic constraint operator `#=` that selects the solving strategy based on the domain's algebraic structure:

```
;; In Prologos surface syntax (speculative)

;; Basic constraint: domain-polymorphic
#= x 42                        ;; x must equal 42 (in whatever domain x inhabits)

;; The engine inspects x's domain:
;; - If x : Int     → linear arithmetic propagator
;; - If x : Bool    → Boolean propagator (SAT cell)
;; - If x : Nat     → narrowing propagator (constructor enumeration)
;; - If x : Type    → type unification propagator (E-unification)
;; - If x : Session → session constraint propagator (quantale residuation)

;; Relational constraints (speculative)
#= [f x] [g y]                 ;; f(x) must equal g(y) — bidirectional propagation

;; The solving strategy depends on the structure:
;; - Free algebra: narrowing (enumerate constructors of f, unify)
;; - Residuated:   forward f(x) → c, then backward g \ c → y
;; - Boolean:      CDCL (learn clauses from conflicts)
;; - Linear:       Gaussian (solve system of equalities)
```

The `#=` operator is not a new primitive — it is the *surface form* of the propagator network's constraint assertion. The novelty is that strategy selection is automatic, driven by the algebraic structure detected at domain registration time.

### Trait-Based Domain Registration

In Prologos terms, the algebraic structure hierarchy maps to a trait hierarchy:

```
trait Constrainable D           ;; minimal: partial order
trait Joinable D : Constrainable ;; join-semilattice
trait Latticed D : Joinable     ;; full lattice (meet + join)
trait Distributed D : Latticed  ;; distributive lattice
trait HeytingDomain D : Distributed ;; Heyting algebra (residuation)
trait BooleanDomain D : HeytingDomain ;; Boolean algebra (complement)
trait Residuated D : Latticed   ;; residuated lattice (not necessarily Heyting)
trait QuantaleDomain D : Residuated ;; quantale (resource tracking)
```

When a type implements `HeytingDomain`, the constraint engine automatically installs backward propagators. When it implements `BooleanDomain`, CDCL is available. The trait dispatch mechanism (SRE) selects the solving strategy.

---

## 10. Connections to Prologos Subsystems

### Propagator Migration (PM) Series

The PM series established the propagator network as the universal computation substrate. The universal constraint solving vision provides the *algebraic justification*: the propagator network is the right substrate because lattice-based constraint propagation is the universal solving strategy, and every domain with algebraic structure embeds into a lattice (Birkhoff's theorem).

### SRE Series

The SRE decomposes elaboration into structured relations. Each relation type (form dispatch, trait resolution, pattern compilation, reduction) operates on a specific algebraic domain. The SRE's form registry is a finite-domain CSP (solvable by local consistency). Trait resolution involves AC-unification (matching constraint sets modulo ordering). Pattern compilation involves free-algebra narrowing.

### BSP-LE Series

The BSP-LE logic engine implements the non-monotone layer — ATMS assumption management, tabling (fixpoint computation with negation), and search. In the universal framework, BSP-LE provides the Boolean algebra layer (ATMS) and the stratification protocol for crossing the CALM boundary.

### PTF Series

The PTF (Propagator Theory Foundations) series formalizes the algebraic structure of the propagator network. The module-theoretic lens (Module Theory note) provides the decomposition theorems. The universal constraint solving vision adds the strategy selection dimension — not just "how do propagators compose?" but "what solving strategies do the domains support?"

### Type Inference

Current type inference uses syntactic unification on a free term algebra. The E-unification perspective shows the path forward: enrich the type domain with its equational theory (subtyping = lattice order, union types = commutativity, trait constraints = AC), and the propagator network automatically gains domain-aware constraint solving.

---

## 11. Open Questions

1. **Automatic algebraic structure detection**: Can the algebraic properties of a domain (Taylor terms, WNU polymorphisms, Heyting structure) be detected automatically from the trait implementations, or must they be declared? Automatic detection is more ergonomic but potentially expensive.

2. **Complexity of strategy selection**: The Bulatov-Zhuk theorem is existential — it says a polynomial algorithm exists but doesn't always give a practical one. For each algebraic class, is the derived strategy efficient enough for interactive type checking?

3. **Infinite domains**: The CSP dichotomy theorem applies to finite domains. Prologos type domains are often infinite (function types, polymorphic types). What is the analogous theory for infinite-domain CSPs? The infinite-domain CSP program (Bodirsky et al.) provides partial answers using model-theoretic methods, but the picture is less complete.

4. **Quantale module decomposition for constraint solving**: The Module Theory note shows propagator networks are quantale modules. Does the Krull-Schmidt decomposition theorem for modules give an automatic decomposition of constraint problems into independent sub-problems?

5. **Nelson-Oppen for propagators**: The DPLL(T) Nelson-Oppen combination procedure ensures consistency across theory boundaries. What is the analogous procedure for propagator networks with multiple domain types? The quotient module structure from the Module Theory note may provide this, but the correspondence needs to be made precise.

6. **Widening for non-terminating propagation**: When a lattice domain has infinite ascending chains (e.g., numeric intervals), propagation may not terminate. Can widening operators be derived from the algebraic structure, or must they always be domain-specific?

7. **Dynamic strategy switching**: Can the constraint engine switch strategies mid-solving? For example, start with propagation, detect that the domain has Boolean structure in a sub-problem, switch to CDCL for that sub-problem. This would require the strategy selection to be incremental, not just at registration time.

8. **Residuation for all propagators**: Currently, propagators are directional (forward). Installing backward propagators requires explicit implementation. Can backward propagators be derived automatically from forward propagators via residuation, given that the domain is a residuated lattice?

---

## 12. Summary

The six research threads converge on a single architectural principle: **algebraic structure is the universal API for constraint solving**. A propagator network that can inspect the algebraic properties of its cell domains can automatically select the right solving strategy — forward propagation for lattices, backward reasoning for residuated structures, CDCL for Boolean algebras, narrowing for free algebras, Gaussian elimination for Mal'cev domains.

This is not a future aspiration but a *characterization of what Prologos already does*, viewed through the right lens. The propagator network is already a lattice fixpoint engine. The ATMS is already a Boolean algebra coordinator. Type inference is already E-unification over a lattice domain. The contribution of this research is to make the algebraic structure explicit, systematic, and exploitable — so that new domains automatically receive the strongest solving strategy their algebraic structure supports.

The `#=` operator is the surface manifestation: a single constraint operator whose behavior is determined not by its implementation but by the algebraic nature of its domain. Write `#= x v` and the engine knows whether to propagate, narrow, residuate, or search — because the domain's algebra tells it.
