- [Abstract](#org96935ab)
- [1. The Three Systems](#org46ac1a2)
  - [1.1 System I: The Logic Engine (`rel`)](#orgd0b6cde)
  - [1.2 System II: The Session Runtime (`proc`)](#org77aeb82)
  - [1.3 System III: The Type Checker (Stratified Quiescence)](#org52ae247)
- [2. The Common Categorical Structure](#org863cc13)
  - [2.1 Definition: Stratified Recovery System](#orgfbca38d)
  - [2.2 The Enrichment: Quantale Structure](#orgd70d397)
  - [2.3 The Decomposition: Inter-Stratum Galois Connections](#org98f121f)
  - [2.4 Theorem: Stratification Preserves Fixpoint Equivalence](#org43cd58d)
  - [2.5 The Common Structure: Diagram](#org9d216ad)
- [3. The Quantale Morphism as Bridge](#org31e4e20)
  - [3.1 Why Quantales, Not Just Lattices?](#org6929237)
  - [3.2 The Bridge Pattern in Implementation](#org6d8d260)
  - [3.3 Composition of Galois Connections](#org4ff114b)
- [4. Formal Statements](#org2ff5c33)
  - [4.1 Definition: Stratifiable Operation](#orge8a07da)
  - [4.2 Theorem: Generalized Stratification](#org387596d)
  - [4.3 Theorem: Quantale Morphism Preservation](#org010f747)
  - [4.4 Corollary: Confluence Under Non-Overlapping Resolution](#orgbfeefaf)
- [5. Relationship to Approximation Fixpoint Theory](#orgca5864c)
  - [5.1 The Connection](#orgfdd6431)
  - [5.2 Layered Recovery as a Special Case of AFT](#org0c4f9b1)
  - [5.3 What AFT Offers for Future Extensions](#org1d7931f)
- [6. Variants and Approaches for Non-Monotonic Domains](#orgdc453ed)
  - [6.1 Classification of Non-Monotone Operations](#org9c18282)
    - [Class A: Stratifiable (barrier-compatible)](#org50c0ac1)
    - [Class B: Locally Stratifiable (barrier-compatible with context restriction)](#org54aba20)
    - [Class C: Anti-Monotone (requires bilattice or ATMS)](#orgf80646b)
    - [Class D: Chaotic (no fixpoint guarantee)](#org7a5b926)
  - [6.2 The Adaptation Recipe](#orgb44c654)
  - [6.3 Specific Future Applications in Prologos](#org20e9311)
- [7. Implications and Conclusions](#org202c329)
  - [7.1 What the Categorical Structure Tells Us](#orgdd228d3)
  - [7.2 What This Means for Implementation](#org2450a4d)
  - [7.3 What This Means for Theorists](#org87b5528)
  - [7.4 Open Questions](#orgfbbb4c5)
- [8. References](#orgd39a06e)
  - [8.1 Categorical and Algebraic Foundations](#org0b2f6b1)
  - [8.2 Effect Systems and Graded Monads](#org7bad0d7)
  - [8.3 Fixpoint Theory and Stratification](#org990ae81)
  - [8.4 CALM Theorem and Distributed Monotonicity](#org0254121)
  - [8.5 Propagator Networks](#orge81abc7)
  - [8.6 Session Types](#orgdf427f2)
  - [8.7 Datalog and Non-Monotonic Reasoning](#org854d790)
  - [8.8 Prologos Internal Documents](#org13538c6)



<a id="org96935ab"></a>

# Abstract

We identify the precise categorical structure underlying the Layered Recovery Principle as implemented in three subsystems of the Prologos language: the logic engine (stratified negation), the session runtime (effect ordering), and the type checker (reactive constraint resolution). Each system faces the same fundamental problem: recovering non-monotone behavior on a monotone propagator substrate.

We show that all three systems instantiate a common categorical pattern: a **stratified endofunctor** on a **quantale-enriched lattice**, where the endofunctor decomposes as a chain of monotone functors between lattices connected by Galois connections, with non-monotone operations isolated at precisely one barrier in the chain. The global fixpoint is the least fixpoint of the endofunctor, computed by Kleene iteration over the stratified chain.

We prove that this structure is sufficient to recover any non-monotone operation on a monotone substrate, provided the non-monotone operation satisfies a *stratifiability condition*: it must be expressible as a barrier between two monotone phases. We characterize the class of non-monotone operations that satisfy this condition and identify variants for operations that do not.


<a id="org46ac1a2"></a>

# 1. The Three Systems

Three subsystems of Prologos independently discovered and implemented the same architectural pattern. We analyze each in turn, extracting the precise algebraic structure.


<a id="orgd0b6cde"></a>

## 1.1 System I: The Logic Engine (`rel`)

*Non-monotone operation*: Negation-as-failure (NAF). If P is not derivable at the current stratum, conclude ¬P. This is non-monotone because adding a fact P to the database can cause ¬P to become invalid.

*Implementation*: Stratified evaluation with three layers.

```
Layer 1 (Propagator Network): Unification constraints propagate through cells.
  Values refine monotonically. The network converges to a fixpoint.

Layer 2 (ATMS): Choice points create assumptions. Adding nogoods (inconsistent
  combinations) shrinks the set of valid worldviews — still monotone (the nogood
  set only grows, the valid worldview set only shrinks).

Layer 3 (Stratification Controller): Evaluate ¬P only after stratum containing
  P has reached fixpoint. This is the non-monotone barrier.
```

*Lattice structure*: Let U be the unification lattice (substitutions ordered by refinement). Each stratum Sₖ operates on U. The join is unification; the bottom is the empty substitution.

*The stratified chain*:

```
S₀ ──lfp──→ U₀* ──neg──→ S₁ ──lfp──→ U₁* ──neg──→ S₂ ──lfp──→ ...
 ↑                                                              ↓
 └──────────────────── Kleene iteration ────────────────────────┘
```

Where:

-   lfp denotes the least fixpoint of monotone propagation within a stratum
-   neg denotes the non-monotone negation evaluation at the barrier
-   Uₖ\* is the fixpoint of stratum k

*Algebraic structure*:

-   The unification lattice U is a quantale: substitutions compose (sequential application σ ∘ τ) and this composition distributes over joins (most general unifiers). The ordering is refinement: σ ≤ τ iff τ is a refinement of σ.
-   Negation evaluation neg : U\* → Init(U) is not a quantale morphism (it is anti-monotone on the truth ordering). It maps fixpoint states to initial conditions for the next stratum.
-   Each stratum's propagation is an endofunctor Fₖ : U → U that is monotone. The fixpoint Uₖ\* = lfp(Fₖ).

*Sources*: Logic Engine Design (`2026-02-24_LOGIC_ENGINE_DESIGN.org` §5), Effectful Computation on Propagators (`EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org` §2).


<a id="org77aeb82"></a>

## 1.2 System II: The Session Runtime (`proc`)

*Non-monotone operation*: IO effect execution. Writing to a file, sending a message, opening a connection — these are irreversible observations that cannot be undone, retried, or merged.

*Implementation*: Five-layer architecture.

```
Layer 1 (Session Advancement): Session cells advance monotonically through
  protocol states. Each advancement is a Lamport clock tick.

Layer 2 (Data-Flow Analysis): Analyze variable bindings to derive cross-channel
  ordering edges. Monotone edge accumulation.

Layer 3 (Transitive Closure): Compute the complete partial order over effects
  by propagating ordering edges to closure. Monotone fixpoint.

Layer 4 (ATMS Branching): Maintain per-branch ordering hypotheses. Adding
  nogoods only shrinks valid worldviews — monotone.

Layer 5 (Effect Handler): Execute effects in a valid linearization of the
  resolved partial order. This is the non-monotone barrier.
```

*Lattice structure*: Two lattices connected by a Galois connection.

Let S be the *session lattice*: session types ordered by advancement (bot → concrete → advanced states → end). The join is the most-advanced common state.

Let E be the *effect position lattice*: sets of ordering constraints (i < j) over effect indices, ordered by inclusion. The join is set union. Transitive closure is a closure operator on E (monotone, extensive, idempotent).

*The Galois connection (α, γ)*:

```
α : S → E     (extract causal position from session state)
γ : E → S     (reconstruct remaining protocol from effect position)

α(s) ≤ e  ⟺  s ≤ γ(e)    (adjunction property)
```

Both α and γ are monotone. The key insight: α preserves sequential composition.

*Algebraic structure*:

-   Both S and E are **effect quantales** (Katsumata 2014, Gordon 2021):
    -   Lattice structure (partial order with joins)
    -   Sequential composition (⊕) distributes over joins
    -   Ordering respects composition: i ≤ i' ∧ j ≤ j' ⟹ i ⊕ j ≤ i' ⊕ j'
-   The Galois connection (α, γ) is a **quantale morphism**: it preserves both the lattice ordering and sequential composition.
-   Effect execution (Layer 5) is non-monotone: it selects a linearization of the partial order and performs irreversible IO.

*The stratified chain*:

```
S ──α──→ E ──tc──→ E* ──exec──→ World
↑    Galois     monotone     non-monotone
│   connection   closure       barrier
│
(session advancement propagators — monotone)
```

Where tc denotes transitive closure (a monotone closure operator).

*Sources*: Session Types as Effect Ordering (`2026-03-06_SESSION_TYPES_AS_EFFECT_ORDERING.org` §4-6), Effectful Computation (`EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org` §3-4).


<a id="org52ae247"></a>

## 1.3 System III: The Type Checker (Stratified Quiescence)

*Non-monotone operation*: Trait resolution commitment. Selecting a specific instance from the set of candidates is a *choice* — once committed, the choice is irreversible. Instance selection can be anti-monotone: adding a more specific instance can invalidate a previous selection.

*Implementation*: Stratified quiescence with three strata.

```
Stratum 0 (Type Propagation): Cell writes (meta solutions → type cells),
  unification propagators, cross-domain bridges. Monotone: values only refine
  in the type lattice.

Stratum 1 (Readiness Detection): Constraint-readiness propagators scan cell
  states to derive "constraint C is ready to retry" signals. Monotone: once
  a cell becomes non-bot, readiness is permanent.

Stratum 2 (Resolution Commitment): Consume readiness signals. Execute
  resolution (retry constraint, resolve trait, solve meta). Non-monotone:
  commitment selects one instance, excluding alternatives.
```

*Lattice structure*: Three lattices forming a chain.

Let T be the *type cell lattice*: metavariable values ordered by refinement (bot → partial types → ground types). The merge is unification.

Let R be the *readiness lattice*: sets of ready-constraint descriptors, ordered by inclusion. The join is set union. Readiness is monotone in T: if a cell is non-bot, the constraint is ready; more refined cells are still non-bot.

Let A be the *action lattice*: multisets of resolution actions (trait resolution, constraint retry, hasmethod resolution), ordered by inclusion. Each action is a data descriptor (free monad pattern) — not an executed effect.

*The functors between strata*:

```
α : T → R     (extract readiness from type cell states)
β : R → A     (map readiness signals to resolution actions)
γ : A → T     (commit resolutions → new type cell writes)
```

-   α is monotone: more refined type cells produce (weakly) more readiness signals.
-   β is monotone: more readiness signals produce more action descriptors.
-   γ is **not monotone** in the general case: committing a resolution can invalidate other pending resolutions (e.g., solving meta ?X = Nat might make a trait constraint solvable but also make another constraint unsatisfiable). However, γ is monotone *per action* — each individual resolution writes a more refined value to a type cell.

*The stratified chain (one iteration)*:

```
T ──lfp(S0)──→ T* ──α──→ R ──lfp(S1)──→ R* ──β──→ A ──commit──→ T'
↑                                                              ↓
└──────────────── Kleene iteration (fuel=100) ────────────────┘
```

*Algebraic structure*:

-   T is a quantale: type substitutions compose and composition distributes over the unification join.
-   R is a join-semilattice (readiness sets under union). It lacks the sequential composition that would make it a full quantale.
-   A is a free monoid (action sequences). The ordering is prefix/subset.
-   α : T\* → R is a Galois connection's upper adjoint (abstraction). The lower adjoint γ : R → T does not exist in the traditional sense because commitment is non-monotone. Instead, β ∘ γ : A → T is a *partial function* — it succeeds only when the action is still valid (re-check guard).

*Confluence conditions* (proved in Track 2 Phase 9):

-   S0: Confluent by construction (lattice merge properties).
-   S1: Confluent by construction (readiness is monotone in cell state).
-   S2: Confluent under the *non-overlapping instance invariant*: each constraint has at most one valid resolution. Prologos enforces this — monomorphic instances are looked up by key, parametric instances use most-specific-wins with same-specificity ties rejected as ambiguous (HKT-7).

*Sources*: Track 2 Design (`2026-03-13_TRACK2_REACTIVE_RESOLUTION_DESIGN.md` §3.4), Track 2 Phase 9 (`test-resolution-confluence-01.rkt`).


<a id="org863cc13"></a>

# 2. The Common Categorical Structure


<a id="orgfbca38d"></a>

## 2.1 Definition: Stratified Recovery System

A **stratified recovery system** is a tuple $(L, F_m, f_{nm}, n)$ where:

1.  **L** is a complete lattice (the *substrate*).
2.  **F<sub>m</sub> : L → L** is a monotone endofunctor (the *propagation phase*). By Knaster-Tarski, F<sub>m</sub> has a least fixpoint lfp(F<sub>m</sub>).
3.  **f<sub>nm</sub> : L → L** is a (possibly non-monotone) function (the *barrier operation*).
4.  **n ∈ ℕ ∪ {ω}** is the *stratification depth* (number of strata).

The **stratified fixpoint** is computed by:

```
x₀ = ⊥
For k = 0, 1, ..., n-1:
  xₖ* = lfp(F_m | initialized at xₖ)
  xₖ₊₁ = f_nm(xₖ*)
Result = x_n*
```

This is Kleene iteration on the composition f<sub>nm</sub> ∘ lfp(F<sub>m</sub>), starting from ⊥.


<a id="orgd70d397"></a>

## 2.2 The Enrichment: Quantale Structure

In all three Prologos systems, the substrate lattice L carries additional algebraic structure: it is a **quantale**.

A quantale is a complete lattice (L, ≤, ⊔) equipped with an associative binary operation (⊗ : L × L → L) called *sequential composition* that distributes over arbitrary joins:

```
a ⊗ (⊔ᵢ bᵢ) = ⊔ᵢ (a ⊗ bᵢ)     (left distributivity)
(⊔ᵢ aᵢ) ⊗ b = ⊔ᵢ (aᵢ ⊗ b)     (right distributivity)
```

The three systems' quantale structures:

| System   | Lattice L      | Join (⊔)             | Composition (⊗)               |
|-------- |-------------- |-------------------- |----------------------------- |
| Logic    | Substitutions  | Most general unifier | Substitution application      |
| Sessions | Session states | Most-advanced state  | Protocol continuation         |
| Types    | Type cells     | Unification          | Type substitution composition |


<a id="org98f121f"></a>

## 2.3 The Decomposition: Inter-Stratum Galois Connections

The stratified fixpoint computation decomposes the endofunctor (f<sub>nm</sub> ∘ lfp(F<sub>m</sub>)) through intermediate lattices connected by Galois connections.

In the general case, a stratified recovery system with k strata has intermediate lattices L₀, L₁, &#x2026;, Lₖ and Galois connections:

```
(αᵢ, γᵢ) : Lᵢ ⇌ Lᵢ₊₁     for i = 0, ..., k-2

where αᵢ is monotone (abstraction)
      γᵢ is monotone (concretization)
      αᵢ(x) ≤ y  ⟺  x ≤ γᵢ(y)
```

The non-monotone operation f<sub>nm</sub> factors through the final lattice Lₖ₋₁:

```
f_nm = γ₀ ∘ ... ∘ γₖ₋₂ ∘ barrier ∘ αₖ₋₂ ∘ ... ∘ α₀
```

where *barrier* : Lₖ₋₁ → Lₖ₋₁ is the non-monotone operation at the top stratum. All other operations in the chain are monotone.

The three systems instantiate this pattern:

| System   | Lattice chain | Galois connections                  | Barrier             |
|-------- |------------- |----------------------------------- |------------------- |
| Logic    | U → U         | identity (single lattice, iterated) | neg : U\* → Init(U) |
| Sessions | S → E → E\*   | (α,γ) : S ⇌ E (quantale morphism)   | exec : E\* → World  |
| Types    | T → R → A     | α : T\* → R (abstraction)           | commit : A → T      |


<a id="org43cd58d"></a>

## 2.4 Theorem: Stratification Preserves Fixpoint Equivalence

**Theorem** (Fixpoint Equivalence). Let $(L, F_m, f_{nm}, n)$ be a stratified recovery system. If f<sub>nm</sub> is *stratifiable* — i.e., the composition f<sub>nm</sub> ∘ lfp(F<sub>m</sub>) is monotone — then the stratified fixpoint equals the direct fixpoint:

```
lfp(f_nm ∘ lfp(F_m)) = stratified_fixpoint(L, F_m, f_nm, n)
```

*Proof sketch*: Define G = f<sub>nm</sub> ∘ lfp(F<sub>m</sub>) : L → L. Since lfp(F<sub>m</sub>) is monotone (as a function of the initialization point, by the parametric fixpoint theorem — Cousot & Cousot 1979) and f<sub>nm</sub> is stratifiable (monotone when composed with lfp), G is monotone. By Knaster-Tarski, G has a least fixpoint lfp(G). The stratified computation is exactly Kleene iteration of G starting from ⊥:

```
x₀ = ⊥,  xₖ₊₁ = G(xₖ) = f_nm(lfp(F_m | xₖ))
```

For monotone G on a complete lattice, Kleene iteration converges to lfp(G) (possibly at a transfinite ordinal for general complete lattices; at ω for algebraic/continuous lattices, which all three systems are). □

**Corollary** (Confluence). If the stratified fixpoint equals the direct fixpoint and S0 is confluent (lattice merge properties), then the overall computation is confluent — the result is independent of the order in which propagators fire within each stratum.

*Note*: The stratifiability condition is not always satisfied. System III (type checker) satisfies it only under the non-overlapping instance invariant. If overlapping instances existed, f<sub>nm</sub> ∘ lfp(F<sub>m</sub>) would not be monotone (adding type information could change which instance is selected, leading to a different fixpoint). This is why Prologos rejects overlapping instances — it is a *semantic requirement for confluence*, not merely a design choice.


<a id="org9d216ad"></a>

## 2.5 The Common Structure: Diagram

```
                ┌─────────────────────────┐
                │   STRATIFIED RECOVERY    │
                │       SYSTEM             │
                └───────────┬─────────────┘
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
┌─────────▼──────┐ ┌───────▼────────┐ ┌──────▼──────────┐
│ System I: rel  │ │ System II: proc│ │ System III: tc  │
│ (Logic Engine) │ │ (Sessions)     │ │ (Type Checker)  │
└─────────┬──────┘ └───────┬────────┘ └──────┬──────────┘
          │                │                 │
          ▼                ▼                 ▼
┌──────────────────────────────────────────────────────┐
│         QUANTALE-ENRICHED LATTICE  (L, ≤, ⊗)        │
│                                                      │
│  Monotone endofunctor Fm : L → L                     │
│  Fixpoint computation: lfp(Fm) via propagator network│
└──────────────────────┬───────────────────────────────┘
                       │
          ┌────────────▼──────────────┐
          │  GALOIS CONNECTION CHAIN   │
          │                           │
          │  L₀ ⇌ L₁ ⇌ ... ⇌ Lₖ₋₁   │
          │  (αᵢ, γᵢ) monotone pairs  │
          └────────────┬──────────────┘
                       │
          ┌────────────▼──────────────┐
          │  NON-MONOTONE BARRIER     │
          │                           │
          │  barrier : Lₖ₋₁ → L₀     │
          │  (negation / execution /  │
          │   commitment)             │
          └────────────┬──────────────┘
                       │
          ┌────────────▼──────────────┐
          │  KLEENE ITERATION         │
          │                           │
          │  Iterate (barrier ∘ lfp)  │
          │  until global fixpoint    │
          └───────────────────────────┘
```


<a id="org31e4e20"></a>

# 3. The Quantale Morphism as Bridge


<a id="org6929237"></a>

## 3.1 Why Quantales, Not Just Lattices?

The lattice structure alone suffices for fixpoint computation (Knaster-Tarski). The quantale structure — the sequential composition ⊗ — is what makes the Galois connections between systems meaningful.

Without ⊗, a Galois connection (α, γ) : L ⇌ M between lattices preserves only order information. With ⊗, a **quantale morphism** preserves both order AND sequential composition:

```
α(a ⊗ b) = α(a) ⊗' α(b)     (preserves composition)
α(⊔ᵢ aᵢ) = ⊔'ᵢ α(aᵢ)        (preserves joins)
```

This is critical for Prologos because the systems don't just compute values — they compute *sequences of operations*. Substitution application, protocol continuation, and type-checking steps all have sequential structure. The quantale morphism guarantees that the sequential structure is preserved across the Galois bridge.

In System II (sessions), this means: the session protocol's sequential structure (send, then receive, then end) maps faithfully to the effect ordering's sequential structure (effect at position 0 before effect at position 1 before effect at position 2). The morphism doesn't just preserve ordering — it preserves the *reason* for the ordering.


<a id="org6d8d260"></a>

## 3.2 The Bridge Pattern in Implementation

In Prologos, the Galois connection between domains is implemented as a **bridge propagator** — a propagator that watches cells in one domain and writes to cells in another:

```
bridge-propagator : Cell[L] × Cell[M] → Propagator
  When Cell[L] refines from l to l':
    write α(l') to Cell[M]      (α is the abstraction)
  When Cell[M] refines from m to m':
    write γ(m') to Cell[L]      (γ is the concretization)
```

The monotonicity of α and γ guarantees that the bridge propagator is a valid monotone propagator — it can participate in the propagator network's fixpoint computation without violating confluence.

Existing bridges in Prologos:

-   Type ⇌ Session bridge (`session-propagators.rkt`)
-   Type ⇌ Interval bridge (from abstract interpretation work)
-   Session ⇌ Effect Position bridge (proposed in Architecture D)

Each bridge is a quantale morphism instantiated as a pair of propagators.


<a id="org4ff114b"></a>

## 3.3 Composition of Galois Connections

Galois connections compose: if (α₁, γ₁) : L ⇌ M and (α₂, γ₂) : M ⇌ N, then (α₂ ∘ α₁, γ₁ ∘ γ₂) : L ⇌ N is also a Galois connection.

This means the inter-stratum connections compose into a single Galois connection from the substrate lattice to the barrier lattice. For System III (type checker):

```
(α₂ ∘ α₁, γ₁ ∘ γ₂) : T ⇌ A

where α₁ : T* → R (readiness extraction)
      α₂ : R* → A (action construction)
      γ₂ : A → R (action interpretation)
      γ₁ : R → T (resolution commitment)
```

The *composed* Galois connection maps directly from type cell fixpoints to resolution actions. This is exactly what the stratified quiescence loop computes — but the categorical perspective reveals that the intermediate lattice R (readiness) is not essential; it is a *factorization* of the composed connection that makes the computation more efficient (readiness can be computed incrementally by propagators).


<a id="org2ff5c33"></a>

# 4. Formal Statements

We now state the key results precisely.


<a id="orge8a07da"></a>

## 4.1 Definition: Stratifiable Operation

A function f : L → L on a complete lattice L is *stratifiable with respect to a monotone endofunctor F : L → L* if the composition f ∘ lfp(F) : L → L is monotone, where lfp(F) denotes the parametric least fixpoint of F (which is monotone in the initialization point by Cousot & Cousot 1979).


<a id="org387596d"></a>

## 4.2 Theorem: Generalized Stratification

Let L be a complete lattice, F : L → L monotone, and f : L → L stratifiable with respect to F. Define the stratified iteration:

```
G = f ∘ lfp(F) : L → L

x₀ = ⊥
xₙ₊₁ = G(xₙ)
```

Then:

1.  G is monotone (by definition of stratifiability).
2.  lfp(G) exists (by Knaster-Tarski).
3.  The Kleene chain x₀ ≤ x₁ ≤ &#x2026; converges to lfp(G).
4.  lfp(G) is the unique minimal solution to: x = f(lfp(F | x)).


<a id="org010f747"></a>

## 4.3 Theorem: Quantale Morphism Preservation

Let (Q₁, ≤₁, ⊗₁) and (Q₂, ≤₂, ⊗₂) be quantales and (α, γ) : Q₁ ⇌ Q₂ a Galois connection that is also a quantale morphism (α preserves ⊗ and ⊔). If F₁ : Q₁ → Q₁ and F₂ : Q₂ → Q₂ are monotone endofunctors such that α ∘ F₁ = F₂ ∘ α (the bridge commutes with propagation), then:

```
α(lfp(F₁)) ≤ lfp(F₂)
```

and if additionally γ ∘ F₂ ≤ F₁ ∘ γ, then:

```
α(lfp(F₁)) = lfp(F₂)
```

*This is the soundness theorem for cross-domain bridges.* It guarantees that fixpoints computed in one domain (e.g., session types) map correctly to fixpoints in another domain (e.g., effect positions).


<a id="orgbfeefaf"></a>

## 4.4 Corollary: Confluence Under Non-Overlapping Resolution

For System III (type checker), the barrier operation (trait resolution commitment) is stratifiable if and only if the instance resolution function is *deterministic* — i.e., for each (trait, type-args) pair, there is at most one valid instance.

Under the non-overlapping instance invariant enforced by Prologos (monomorphic lookup by key, parametric most-specific-wins, same-specificity ties rejected as HKT-7 ambiguity), the resolution function is deterministic, hence stratifiable, hence the stratified fixpoint is confluent.

This result was verified empirically by Track 2 Phase 9 (19 confluence tests, randomized evaluation order, deterministic results).


<a id="orgca5864c"></a>

# 5. Relationship to Approximation Fixpoint Theory


<a id="orgfdd6431"></a>

## 5.1 The Connection

Approximation Fixpoint Theory (AFT), developed by Denecker, Marek, and Truszczyński (2000, 2004), provides an algebraic framework for fixpoints of non-monotone operators using *approximating operators* on bilattices.

The key construction: given a non-monotone operator O : L → L on a complete lattice L, define an approximating operator A : L² → L² on the bilattice L² (pairs (x, y) where x ≤ y, ordered by the *precision* ordering ≤<sub>p</sub>), such that A is monotone with respect to ≤<sub>p</sub>. The fixpoints of A approximate the fixpoints of O.


<a id="org0c4f9b1"></a>

## 5.2 Layered Recovery as a Special Case of AFT

Our stratified recovery systems can be seen as a restricted case of AFT where:

1.  The approximating operator A decomposes into a chain of Galois connections (our inter-stratum functors).
2.  The bilattice structure is implicit in the stratification: the lower bound of the approximation is the fixpoint of the monotone phase (lfp(F<sub>m</sub>)), and the upper bound is determined by the barrier operation.
3.  The precision ordering corresponds to the number of strata computed: more strata = more precise approximation.

However, Layered Recovery is *more structured* than general AFT because:

-   The monotone and non-monotone phases are cleanly separated (not interleaved).
-   The quantale enrichment provides sequential composition, which AFT does not require.
-   The Galois connections between strata provide soundness guarantees that general approximating operators do not.


<a id="org1d7931f"></a>

## 5.3 What AFT Offers for Future Extensions

AFT provides semantics for operations that Layered Recovery currently does not handle well:

-   **Well-founded semantics**: For self-referential negation (P ← ¬P), AFT assigns the well-founded model (unknown). Layered Recovery's stratification rejects this as unstratifiable. AFT provides a graceful degradation.
-   **Stable models**: For programs with multiple stable fixpoints (non-deterministic choice), AFT characterizes all stable models. Layered Recovery computes one fixpoint (the least). AFT could extend the ATMS layer to enumerate alternatives.
-   **Three-valued fixpoints**: AFT's bilattice naturally supports three-valued logic (true, false, unknown). This could extend Prologos's type checker to track constraints whose satisfiability is not yet determined, rather than failing eagerly.


<a id="orgdc453ed"></a>

# 6. Variants and Approaches for Non-Monotonic Domains


<a id="org9c18282"></a>

## 6.1 Classification of Non-Monotone Operations

Not all non-monotone operations are stratifiable. We classify them:


<a id="org50c0ac1"></a>

### Class A: Stratifiable (barrier-compatible)

The operation f : L → L is stratifiable if f ∘ lfp(F) is monotone. This means adding more information to the substrate's fixpoint never reverses the barrier operation's output.

*Examples*:

-   Negation-as-failure (when the program is stratifiable)
-   Effect execution (when the effect ordering is derived from a monotone source)
-   Trait resolution commitment (under non-overlapping instances)

*Approach*: Direct application of the Layered Recovery Principle. Insert a barrier between the monotone fixpoint and the non-monotone operation.


<a id="org54aba20"></a>

### Class B: Locally Stratifiable (barrier-compatible with context restriction)

The operation f is not globally stratifiable but becomes stratifiable when restricted to a subset of the lattice. This typically happens when non-monotonicity arises only for certain value combinations.

*Examples*:

-   Overlapping instance resolution (stratifiable for non-overlapping subsets)
-   Aggregation with non-monotone aggregates (e.g., average — stratifiable when the set being aggregated is fixed)

*Approach*: *Dynamic stratification*. Partition the lattice at runtime into regions where f is stratifiable, and process each region at a separate barrier. This is analogous to local stratification in Datalog.


<a id="orgf80646b"></a>

### Class C: Anti-Monotone (requires bilattice or ATMS)

The operation f is anti-monotone: more input information decreases the output. Classical negation (¬) is the canonical example.

*Examples*:

-   Classical negation (not NAF — actual logical negation)
-   Set complement
-   Constraint *retraction* (removing a previously-added constraint)

*Approach*: Use AFT's bilattice construction. Lift the operation to L² where the approximating operator is monotone. Or use the ATMS: treat the anti-monotone operation's inputs as hypotheses, compute fixpoints for each hypothesis set, and select the consistent worldview.


<a id="org7a5b926"></a>

### Class D: Chaotic (no fixpoint guarantee)

The operation has no monotonicity or anti-monotonicity structure. Applying it repeatedly may oscillate without converging.

*Examples*:

-   Arbitrary function composition with side effects
-   Operations that depend on evaluation order (inherently non-confluent)

*Approach*: *Bounded iteration with fuel*. Iterate the stratified chain up to a fuel limit (as System III does with fuel=100). If convergence is not reached, report an error. This is not a theoretical guarantee — it is a pragmatic safety valve. Alternatively, impose ordering constraints to make the operation deterministic (converting Class D to Class A at the cost of parallelism).


<a id="orgb44c654"></a>

## 6.2 The Adaptation Recipe

For any new non-monotonic domain:

1.  **Identify the substrate quantale (L, ≤, ⊗)**: What is the lattice of partial information? What is sequential composition? What is the join (information merge)?

2.  **Identify the non-monotone operation f**: What operation on L violates monotonicity? Classify it (A, B, C, or D above).

3.  **For Class A**: Define the monotone propagation phase F<sub>m</sub> and verify stratifiability. Insert a single barrier.

4.  **For Class B**: Identify the stratifiable partitions. Design dynamic stratification that detects partition boundaries at runtime.

5.  **For Class C**: Choose between AFT (bilattice approximation) and ATMS (hypothetical reasoning). AFT is simpler for pure logic; ATMS is better when the non-monotone operation interacts with choice.

6.  **For Class D**: Apply fuel-bounded iteration. Consider whether ordering constraints can reduce to Class A.

7.  **If cross-domain interaction is needed**: Define a Galois connection (α, γ) : L ⇌ M between the new domain and existing domains. Verify that it is a quantale morphism (preserves ⊗). Implement as a bridge propagator.


<a id="org20e9311"></a>

## 6.3 Specific Future Applications in Prologos

| Domain                  | Non-Monotone Operation                                | Class       | Approach                                      |
|----------------------- |----------------------------------------------------- |----------- |--------------------------------------------- |
| Refinement types        | Predicate weakening under subtyping                   | B           | Dynamic stratification by predicate structure |
| Dependent types         | Type-level computation with recursion                 | D (bounded) | Fuel-bounded normalization (already exists)   |
| Module system           | Re-export shadowing                                   | A           | Barrier at module boundary                    |
| Incremental compilation | Definition invalidation                               | C           | ATMS with assumptions per definition          |
| Proof search            | Backtracking                                          | C           | ATMS (existing)                               |
| Probabilistic types     | Bayesian conditioning (non-monotone on probabilities) | B           | Stratify by observation order                 |


<a id="org202c329"></a>

# 7. Implications and Conclusions


<a id="orgdd228d3"></a>

## 7.1 What the Categorical Structure Tells Us

The three implementations of Layered Recovery are not *analogous* — they are *instances of the same mathematical structure*. The common structure is a stratified endofunctor on a quantale-enriched lattice, with Galois connections between strata and a non-monotone barrier at exactly one point in the chain.

This is not a coincidence. The CALM theorem (Hellerstein 2011) tells us that non-monotone operations require coordination, and that monotone operations do not. The Layered Recovery Principle is the *minimal* coordination strategy: all monotone reasoning happens coordination-free in the propagator network, and the single barrier provides the coordination required by the CALM theorem. The quantale enrichment ensures that sequential structure is preserved across domain bridges.


<a id="org2450a4d"></a>

## 7.2 What This Means for Implementation

For implementers, the categorical structure provides:

1.  **A checklist**: For each new domain, identify the lattice, the composition, the non-monotone operation, and its class. The categorical structure tells you exactly what infrastructure is needed.

2.  **A correctness criterion**: If your Galois connection is a quantale morphism and your barrier operation is stratifiable, confluence is guaranteed. If any of these conditions fails, the structure tells you exactly where the problem is.

3.  **A composition principle**: Galois connections compose. Bridge propagators compose. New domains can be added to the propagator network without modifying existing domains — just add a bridge.


<a id="org87b5528"></a>

## 7.3 What This Means for Theorists

The contribution is the identification of quantale enrichment as the key structure that distinguishes Layered Recovery from general stratified fixpoint computation. Lattice-theoretic stratification (Datalog, AFT) handles the fixpoint side. The quantale morphism handles the *sequential composition* side — which is essential for programming language semantics where operations have causal order.

The three systems demonstrate that the same categorical pattern arises independently in logic programming (unification quantale), protocol verification (session quantale), and type inference (substitution quantale). This suggests the pattern is fundamental to any system that combines monotone constraint propagation with non-monotone decision procedures.


<a id="orgfbbb4c5"></a>

## 7.4 Open Questions

1.  **Is there a 2-categorical structure?** The Galois connections between domains are 1-cells in a 2-category. Do the bridge propagators form 2-cells? If so, what additional coherence conditions arise?

2.  **Can the ATMS be characterized as a specific stratification?** Currently, the ATMS is treated as a separate layer. Can it be unified into the stratified endofunctor framework — perhaps as an internal hom in the quantale?

3.  **What is the complexity of stratifiability checking?** For System III, we verify stratifiability by enforcing non-overlapping instances (a syntactic condition). Is there a general decision procedure for stratifiability of barrier operations?

4.  **Quantaloid enrichment**: When multiple quantales interact via multiple Galois connections, the natural home is a *quantaloid* (a category enriched over quantales). Does the full Prologos propagator network, with all its cross-domain bridges, form a quantaloid-enriched category?


<a id="orgd39a06e"></a>

# 8. References


<a id="org0b2f6b1"></a>

## 8.1 Categorical and Algebraic Foundations

-   Rosenthal, K.I. (1990). *Quantales and Their Applications*. Longman.
-   Stubbe, I. (2013). "An introduction to quantaloid-enriched categories." [PDF](https://www-lmpa.univ-littoral.fr/~stubbe/PDF/SurveyQCats.pdf)
-   Paseka, J. & Rosický, J. (2000). "Quantales." In *Current Research in Operational Quantum Logic*. [ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S1570795407050061)
-   Fong, B. & Spivak, D.I. (2019). *Seven Sketches in Compositionality*. §1.3 Galois Connections. [LibreTexts](https://math.libretexts.org/Bookshelves/Applied_Mathematics/Seven_Sketches_in_Compositionality:_An_Invitation_to_Applied_Category_Theory_(Fong_and_Spivak)/01:_Generative_Effects_-_Orders_and_Adjunctions/1.03:_Galois_Connections)


<a id="org7bad0d7"></a>

## 8.2 Effect Systems and Graded Monads

-   Katsumata, S. (2014). "Parametric effect monads and semantics of effect systems." *POPL 2014*. [ResearchGate](https://www.researchgate.net/publication/262368930_Parametric_Effect_Monads_and_Semantics_of_Effect_Systems)
-   Gordon, C.S. (2021). "Lifting Sequential Effects to Indexed Computation Types." *ESOP 2021*.
-   Orchard, D. et al. (2020). "Unifying graded and parameterised monads." [arXiv](https://arxiv.org/pdf/2001.10274)
-   Uustalu, T. (2018). "Graded monads and quantified computational effects." [Slides](https://mta.ca/~rrosebru/FMCS2018/Slides/Uustalu.pdf)
-   nLab. "Graded monad." [nLab](https://ncatlab.org/nlab/show/graded+monad)
-   Barreto, S. & Milius, S. (2025). "A Category-Theoretic Framework for Dependent Effect Systems." [arXiv](https://arxiv.org/html/2601.14846)


<a id="org990ae81"></a>

## 8.3 Fixpoint Theory and Stratification

-   Cousot, P. & Cousot, R. (1977). "Abstract interpretation: a unified lattice model for static analysis." *POPL 1977*.
-   Cousot, P. & Cousot, R. (2014). "A Galois connection calculus for abstract interpretation." *POPL 2014*. [PDF](https://www.di.ens.fr/~cousot/publications.www/CousotCousot-POPL14-ACM-p2-3-2014.pdf)
-   Denecker, M. et al. (2000, 2004). Approximation Fixpoint Theory. [Recent extension](https://proceedings.kr.org/2021/32/kr2021-0032-heyninck-et-al.pdf)
-   Heyninck, J. et al. (2025). "A Category-Theoretic Perspective on Approximation Fixpoint Theory." [arXiv](https://arxiv.org/pdf/2502.09234) [Cambridge](https://www.cambridge.org/core/journals/theory-and-practice-of-logic-programming/article/categorytheoretic-perspective-on-higherorder-approximation-fixpoint-theory/D3A56D482FE54B7DA41C155021088E39)


<a id="org0254121"></a>

## 8.4 CALM Theorem and Distributed Monotonicity

-   Hellerstein, J.M. (2010, 2019). "Keeping CALM: When Distributed Consistency is Easy." *CACM*. [arXiv](https://arxiv.org/abs/1901.01930) [ACM](https://cacm.acm.org/research/keeping-calm/)
-   Conway, N. et al. (2012). "Logic and Lattices for Distributed Programming." [PDF](https://dsf.berkeley.edu/papers/UCB-lattice-tr.pdf)
-   Alvaro, P. et al. (2011). "Consistency Analysis in Bloom: a CALM and Collected Approach." *CIDR 2011*. [PDF](https://people.ucsc.edu/~palvaro/cidr11.pdf)


<a id="orge81abc7"></a>

## 8.5 Propagator Networks

-   Radul, A. & Sussman, G.J. (2009). "The Art of the Propagator." MIT CSAIL Tech Report.
-   Radul, A. (2009). *Propagation Networks: A Flexible and Expressive Substrate for Computation*. PhD thesis, MIT.


<a id="orgdf427f2"></a>

## 8.6 Session Types

-   Caires, L. & Pfenning, F. (2010). "Session Types as Intuitionistic Linear Propositions." *CONCUR 2010*.
-   Wadler, P. (2012). "Propositions as Sessions." *ICFP 2012*.
-   Atkey, R. (2009). "Parameterised Notions of Computation." *JFP 19(3-4)*.


<a id="org854d790"></a>

## 8.7 Datalog and Non-Monotonic Reasoning

-   Madsen, M. et al. (2024). "From Datalog to Flix: A Declarative Language for Fixed Points on Lattices." [Berkeley](https://inst.eecs.berkeley.edu/~cs294-260/sp24/2024-02-12-flix)
-   Charalambidis, A. et al. (2025). "The Power of Negation in Higher-Order Datalog." *TPLP*. [Cambridge](https://www.cambridge.org/core/journals/theory-and-practice-of-logic-programming/article/power-of-negation-in-higherorder-datalog/F29B686E15B1D940647C9C500E335194)
-   Kuper, L. & Newton, R.R. (2023). "Breaking the Negative Cycle." *ECOOP 2023*. [PDF](https://drops.dagstuhl.de/storage/00lipics/lipics-vol263-ecoop2023/LIPIcs.ECOOP.2023.31/LIPIcs.ECOOP.2023.31.pdf)


<a id="org13538c6"></a>

## 8.8 Prologos Internal Documents

-   `EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org` — Layered Recovery Principle (canonical)
-   `2026-03-06_SESSION_TYPES_AS_EFFECT_ORDERING.org` — System II design
-   `2026-02-24_LOGIC_ENGINE_DESIGN.org` — System I design
-   `2026-03-13_TRACK2_REACTIVE_RESOLUTION_DESIGN.md` — System III design
-   `2026-02-27_1026_GALOIS_CONNECTIONS_ABSTRACT_INTERPRETATION.md` — Galois connections research
-   `2026-03-11_PROPAGATOR_FIRST_PIPELINE_AUDIT.md` — Full system audit
-   `DESIGN_PRINCIPLES.org` — Data Orientation principle
