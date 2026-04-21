# Tropical Quantales: Cost-Optimization Semantics for Propagator Networks

**Date**: 2026-04-21
**Stage**: 1 — Deep Research (per [`DESIGN_METHODOLOGY.org`](../tracking/principles/DESIGN_METHODOLOGY.org) Stage 1)
**Status**: Foundational survey + Prologos-specific synthesis
**Target consumers**: PPN Track 4C Phase 9 (tropical fuel cell, backward error-explanation), future PReduce track (cost-guided rewriting / e-graph extraction), future self-hosting (quantale framing at the language surface)
**Related prior art**:
- [`qauntale_outputs/`](../../qauntale_outputs/) — quantale-as-PLP-annotation research (different use case; foundational-quantale-theory overlap)
- [`2026-03-28_MODULE_THEORY_LATTICES.md`](../research/2026-03-28_MODULE_THEORY_LATTICES.md) — module-theoretic foundations for propagator networks
- [`2026-04-02_SRE_TRACK2H_DESIGN.md`](../tracking/2026-04-02_SRE_TRACK2H_DESIGN.md) — TypeFacet quantale (sister quantale; Galois-bridge candidate)
- [`2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md`](../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md) — cell-based TMS design
- [`2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`](../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — hypercube worldview + Gray code + bitmask subcube

---

## §1 Purpose and scope

### §1.1 Why this document exists

PPN Track 4C Phase 9 introduces a **tropical fuel cell** as an on-network replacement for the imperative `(fuel 1000000)` decrementing counter currently in `prop-network`. External critique (2026-04-18) recommended this; the Phase 9 mini-design needs a clean algebraic foundation before implementation.

Two motivations:

1. **Immediate**: Phase 9's tropical fuel cell is the first practical instantiation of a tropical-lattice / quantale / semiring / cost-optimization structure in Prologos production code. The mechanism has been theorized (Hyperlattice Conjecture; BSP-LE Track 2 research on tropical semirings; Module Theory §6 e-graphs as quotient modules) but never built. Getting the algebra right on the first instantiation is architecturally load-bearing — PReduce will inherit the pattern.

2. **Structural**: the user (2026-04-21) directs that the design explore **quantales rather than merely semirings** for this work. The quantale framing aligns with SRE 2H's TypeFacet quantale, composes with Module Theory's Galois bridges, and gives residuation natively (which has direct engineering value — backward error-explanation is a residual computation, not an ad-hoc tracker).

The thesis of this document: **tropical quantales provide the algebraic substrate that Prologos's cost-optimization infrastructure — fuel, PReduce extraction, cost-guided search — needs, and the engineering benefits (residuation for provenance, module-theoretic composition, CALM-compatible parallelism) justify the extra formal weight over bare tropical semirings.**

### §1.2 What we already have (Prologos context)

- **SRE 2H** defines TypeFacet as a quantale (⊕ union-join, ⊗ tensor, left/right residuals declared). The machinery for quantale-valued cells, propagator actions over quantales, and residual-based backward reasoning is PARTLY in place for one specific quantale.
- **Module Theory research** (§5-6) frames backward chaining as residuation, e-graphs as quotient modules, and propagator composition as ring action on modules. The general framework exists; tropical instantiation does not.
- **BSP-LE 2B** ships the infrastructure that a tropical fuel cell would live on: bitmask worldview, tagged-cell-value, assumption-tagged dependents, stratum-request pattern.
- **Hyperlattice Conjecture** states that every computation expressible as lattice fixpoint; optimality follows Hasse. The conjecture PREDICTS that cost-optimization admits a lattice formulation — tropical is that formulation.
- **`qauntale_outputs/`** contains a parallel research strand exploring quantales as ProbLog annotations — different use case (probabilistic logic programming) but shares foundational sources (Fujii, Bacci, Lawvere quantale).

What we DON'T have: a principled tropical-quantale design with explicit module structure, residuation semantics, and integration with TypeFacet via Galois bridges.

### §1.3 Posture — depth-first on formal grounding

Per user direction (2026-04-21): "as much depth as we can muster, so go as deep and wide on the formal groundings that our implementation and engineering would benefit from, generally."

This document is literature-dense in §2-§8 (textbook scaffolding + specific papers), synthesis-heavy in §9-§10 (Prologos-specific tropical quantale + engineering implications), and design-facing in §11 (open questions that legitimately belong in Phase 9 design, not research).

Formality: **hybrid**. Definitions inline with prose; theorem-boxes only for load-bearing results (5-10 total). Unicode math notation (∨, ∧, ⊗, ⊑, ⊥, ⊤) over LaTeX. Concrete examples at every conceptual jump.

---

## §2 Semiring foundations for cost and aggregation

Tropical quantales are the quantale completion of tropical semirings. Understanding the semiring story is the entry point.

### §2.1 Commutative semirings, dioids, idempotent semirings

A **commutative semiring** `(S, ⊕, ⊗, 0, 1)` has:
- `(S, ⊕, 0)` a commutative monoid (additive)
- `(S, ⊗, 1)` a commutative monoid (multiplicative)
- `⊗` distributes over `⊕` on both sides
- `0 ⊗ a = 0` (absorbing zero)

Examples: `(ℕ, +, ×, 0, 1)`, `(𝔹, ∨, ∧, ⊥, ⊤)`, `(ℝ₊, +, ×, 0, 1)`.

A **dioid** (= _di_oïde) is a semiring in which `⊕` is **idempotent**: `a ⊕ a = a`. Equivalently, the additive monoid is an idempotent commutative monoid, inducing a canonical partial order `a ≤ b ⟺ a ⊕ b = b`. The dioid is a semiring equipped with a natural order.

An **idempotent semiring** is the same thing (the terminology is interchangeable in the Litvinov-Maslov tradition). See §7 for the idempotent-analysis framing.

Examples of dioids:
- `(𝔹, ∨, ∧, ⊥, ⊤)` — the Boolean semiring
- `(ℝ ∪ {+∞}, min, +, +∞, 0)` — the **min-plus (tropical) semiring**
- `(ℝ ∪ {−∞}, max, +, −∞, 0)` — the **max-plus semiring**
- `(2^X, ∪, ∩, ∅, X)` — the powerset semiring

### §2.2 Tropical semirings (min-plus and max-plus)

The **min-plus semiring** `T_{min} = (ℝ ∪ {+∞}, min, +, +∞, 0)`:
- Addition is infimum (minimum): `a ⊕ b = min(a, b)`
- Multiplication is ordinary addition: `a ⊗ b = a + b`
- Zero is `+∞` (absorbs multiplicatively: `(+∞) + a = +∞`)
- One is `0` (multiplicative identity: `0 + a = a`)
- Natural order: `a ≤ b ⟺ min(a, b) = a ⟺ a ≤ b` (i.e., smaller = below)

The **max-plus semiring** `T_{max} = (ℝ ∪ {−∞}, max, +, −∞, 0)` is dual.

These structures are the canonical tropical algebras. The name "tropical" (sometimes credited to Imre Simon, working in Brazil) distinguishes these from classical rings: addition is idempotent, there is no additive inverse, and the arithmetic is fundamentally **order-theoretic** rather than field-theoretic.

The critical property for our purposes: tropical semirings are **dioids**. The order is the core semantic object, not an afterthought. Cost computations compose via `⊗` (addition); aggregation/selection is `⊕` (min/max). Combined with completeness, they become quantales (§3).

### §2.3 Semiring-based CSP (Bistarelli-Montanari-Rossi)

**Semiring-based Constraint Satisfaction** (Bistarelli, Montanari, Rossi; _Journal of the ACM_ 1997) generalizes classical CSP, fuzzy CSP, weighted CSP, and partial CSP under a single algebraic framework. Each constraint associates a value from a commutative semiring `S` with each tuple of variable assignments; constraints combine via `⊗`; aggregation over solutions is via `⊕`.

Examples expressible in this framework:
- Classical CSP: `(𝔹, ∨, ∧)` — satisfied or not
- Fuzzy CSP: `([0,1], max, min)` — degrees of satisfaction
- Weighted CSP: `(ℝ₊, min, +)` — tropical, minimize total cost
- Probabilistic CSP: `([0,1], max, ×)` — most-likely solution

The tropical case IS the cost-minimization case. This positioning matters for Prologos: **fuel-constrained propagation is a tropical-semiring CSP**. The abstract framework gives us complexity results, algorithm schemas, and theoretical guarantees for free — our fuel cell inherits from a mature tradition.

### §2.4 Kleene algebra and Kleene star

A **Kleene algebra** `(K, ⊕, ⊗, *, 0, 1)` is an idempotent semiring equipped with a unary **star** operation satisfying:
- `1 ⊕ a ⊗ a* ≤ a*` (unfolding)
- `1 ⊕ a* ⊗ a ≤ a*` (unfolding, right)
- If `a ⊗ x ≤ x` then `a* ⊗ x ≤ x` (induction, left)
- If `x ⊗ a ≤ x` then `x ⊗ a* ≤ x` (induction, right)

Intuition: `a*` is the reflexive transitive closure of `a`: `a* = 1 ⊕ a ⊕ a² ⊕ a³ ⊕ …`. In the tropical case, `a* = min(0, a, 2a, 3a, …) = 0` if `a ≥ 0` else `−∞` — so Kleene star in `T_{min}` computes "the best path of any length, starting from cost 0."

Kleene star for matrix-valued tropical semirings gives **all-pairs shortest paths**: `(A*)_{ij}` is the tropical sum over all walks from `i` to `j`, which equals the minimum-cost path.

### §2.5 Shortest-path as tropical-semiring fixpoint

The Bellman-Ford algorithm and Floyd-Warshall algorithm are **tropical-semiring fixpoint computations** over the adjacency-matrix representation of a weighted graph.

- **Bellman-Ford**: iterate `d^{k+1}_j = min_i (d^k_i + w_{ij})`. This is matrix-vector multiplication in `T_{min}`: `d^{k+1} = A ⊗ d^k` where `A` is the weight matrix. Convergence: `n-1` iterations for an `n`-vertex graph (no negative cycles).

- **Floyd-Warshall**: compute `A*` via successive expansions. Each iteration closes one more intermediate vertex. Complexity: `O(n³)`.

- **Dijkstra**: a priority-queue-based Kleene-star computation exploiting non-negative edge weights. See Backhouse, Gondran, Minoux for the algebraic unification.

"**Dijkstra, Floyd and Warshall Meet Kleene**" (NICTA 2009) formalizes this correspondence in Isabelle/HOL: all three classical algorithms are instances of Kleene-star computation over different semirings, differing only in the semiring's properties (commutative + idempotent + closed → specific algorithm applicability).

For Prologos: **the fuel cell's cost propagation IS a tropical-semiring fixpoint**. A propagator that consumes fuel is a cost-incrementing operation in the tropical semiring; accumulated cost is a Kleene-star-like computation on the propagator dependency graph.

### §2.6 Semiring completeness

A semiring `S` is **complete** if every subset (including infinite subsets) has a supremum under `⊕`, and `⊗` distributes over arbitrary suprema.

- The classical probability semiring `(ℝ₊, +, ×)` is NOT complete (infinite sums can diverge).
- The tropical semiring `T_{min} = (ℝ ∪ {+∞}, min, +, +∞, 0)` IS complete: `+∞` is the top (no elements above it), and every subset of `ℝ ∪ {+∞}` has a well-defined infimum (minimum or `+∞`).

Completeness is the bridge to quantales: **a complete idempotent semiring = a quantale** (Fujii 2019). The tropical semiring is complete; therefore it is a quantale. Conversely, the ordinary probability semiring cannot be completed to a quantale without semantic shift (the awkward case noted in `qauntale_outputs/`).

This is why the tropical case is the natural first quantale-based implementation in Prologos: it's algebraically clean.

---

## §3 Quantales as complete structures

### §3.1 Axioms

A **quantale** is a complete sup-lattice `(Q, ≤)` equipped with an associative multiplication `⊗ : Q × Q → Q` that distributes over arbitrary joins in both arguments:

- `(⋁_i a_i) ⊗ b = ⋁_i (a_i ⊗ b)` (left distributivity over joins)
- `a ⊗ (⋁_i b_i) = ⋁_i (a ⊗ b_i)` (right distributivity over joins)

A **unital quantale** has a multiplicative identity `1 ∈ Q` satisfying `1 ⊗ a = a = a ⊗ 1`.

A **commutative quantale** has `a ⊗ b = b ⊗ a`.

Equivalently (nLab, Wikipedia): a quantale is a monoid in the symmetric monoidal category **Sup** of complete lattices and sup-preserving maps.

### §3.2 Sub-classes

| Sub-class | Extra axiom | Use |
|---|---|---|
| Commutative quantale | `a ⊗ b = b ⊗ a` | Declarative semantics |
| Unital quantale | Has multiplicative identity `1` | Normal case |
| Integral quantale | `1 = ⊤` (top of lattice) | Fuzzy logic, metric reasoning |
| Right-sided quantale | `a ⊗ ⊤ = ⊤` | Process semantics |
| Residuated quantale | Left/right residuals exist | Backward reasoning |
| Locale (frame) | `⊗ = ∧` (meet is multiplication) | Topology, intuitionistic logic |

For Prologos's tropical-fuel use case: **commutative, unital, integral, residuated**. We need commutativity (fuel-costs compose order-independently), unitality (zero-cost operation), integrality (fuel top = `+∞` is the multiplicative sink — infinite cost consumes all others), and residuation (backward error-explanation).

### §3.3 Residuated quantales

A commutative quantale `Q` is **residuated** if for every `a, b ∈ Q` there exists `a \ b ∈ Q` (the **left residual**, also written `b / a`) satisfying the adjunction:

    a ⊗ x ≤ b  ⟺  x ≤ a \ b

Equivalently, `a \ b` is the largest `x` such that `a ⊗ x ≤ b`. It is the "reverse" of multiplication: given the result `b` and one factor `a`, it recovers the other factor (up to the order).

For the tropical quantale `T_{min}`:

    a \ b = {
        b − a  if b ≥ a (i.e., b − a ≥ 0)
        +∞     if b < a
    }

Intuition: "if you've already paid `a` cost and your budget is `b`, you have `b − a` left." If the budget is already exceeded (`b < a`), the residual is `+∞` (no valid remaining cost).

Residuation in a quantale is always computable (it's the unique left adjoint of `a ⊗ ·`), provided the quantale has arbitrary joins. This is a STRUCTURAL existence guarantee, not an algorithmic one — but it tells us residuation is well-defined for any tropical quantale.

### §3.4 Complete idempotent semirings = quantales (Fujii's equivalence)

**Theorem (Fujii 2019, §2)**: Every commutative unital quantale is a complete idempotent semiring under the identification `a ⊕ b := a ∨ b` (join as addition) and `a ⊗ b := a ⊗ b` (multiplication preserved).

Conversely, every complete idempotent semiring with distributive multiplication over arbitrary sums is a commutative quantale.

This is the bridge. In our context:
- **Tropical semiring** (min-plus) is an idempotent semiring; completeness gives us the tropical QUANTALE directly.
- **Lawvere quantale** `([0,∞], ≥, 0, +)` is exactly the tropical quantale (with `≥` as the order, i.e., smaller is above).

The correspondence is not merely formal — it means every theorem about commutative quantales applies to complete idempotent semirings, and vice versa. We can cite quantale-theoretic results (Russo, Stubbe, Abramsky-Vickers) and apply them to tropical-semiring-based infrastructure without restatement.

### §3.5 Locales, frames, and their relation to quantales

A **frame** (or locale) is a quantale in which `⊗ = ∧` (meet): multiplication is the lattice meet, necessarily commutative, idempotent, and integral. Frames are the algebraic duals of topological spaces (point-free topology).

Frames are a SUB-class of quantales: they represent pure "observational" structure without temporal/compositional ordering. Quantales broader than frames model observations that may CHANGE STATE (Abramsky-Vickers 1993) — the move from commutative/idempotent meet to more general "then" composition.

For Prologos: the SRE 2H TypeFacet quantale is NOT a frame (its `⊗` is not `∧` — tensor distributes over joins but is not meet). The tropical quantale is also not a frame — `⊗ = +` is addition, not lattice meet. Both are proper quantales.

### §3.6 Quantaloids (brief note)

A **quantaloid** is a many-object quantale: a category enriched in Sup. A quantale is a quantaloid with exactly one object. Stubbe (2013) gives a comprehensive survey.

Relevance to Prologos: if we ever want to formalize multi-domain cost tracking (different cost currencies for different subsystems — fuel vs memory vs messages), quantaloids provide the categorical structure for "hom-objects between domains are quantale-valued."

For Phase 9 single-quantale (tropical fuel) implementation, quantaloids are out of scope. Flagged for future work.

---

## §4 Lawvere's enriched category framework

### §4.1 V-categories

A **category enriched in a monoidal category `V`** (a **V-category**) replaces hom-sets with hom-objects from `V`. Composition is a V-morphism `hom(B,C) ⊗ hom(A,B) → hom(A,C)`. Identity is a V-morphism `I → hom(A,A)` where `I` is the monoidal unit.

When `V = Set` with Cartesian product, V-categories ARE ordinary categories. When `V = Ab` (abelian groups), V-categories are "Ab-categories" (morphisms form abelian groups with composition bilinear). When `V` is a quantale (viewed as a one-object monoidal category), V-categories acquire a quantitative structure.

### §4.2 Lawvere 1973: generalized metric spaces

Lawvere's seminal 1973 paper _Metric Spaces, Generalized Logic, and Closed Categories_ (reprinted in _Theory and Applications of Categories_ 2002) establishes:

> Metric spaces ARE categories enriched in the monoidal poset `([0,∞], ≥, 0, +)`.

That is, a "Lawvere metric space" is a V-category where:
- Objects = points
- Hom-objects = non-negative extended reals (distances)
- Composition = triangle inequality: `d(A,C) ≤ d(A,B) + d(B,C)` is exactly the V-category composition law
- Identity = `0 ≤ d(A,A)` is the unit law

This is not a metaphor. The axioms of a metric space ARE the axioms of a V-category for the specific `V = ([0,∞], ≥, 0, +)`. Lawvere used this to unify metric geometry with logic (topologies as frames, preorders as Set-categories, metric spaces as `[0,∞]`-categories — all are enriched categories differing only in `V`).

Differences from classical metrics:
- Lawvere metrics allow `d(A,B) = ∞` (objects may be infinitely far apart)
- Lawvere metrics allow `d(A,B) = 0` for `A ≠ B` (points can be "equal up to distance")
- Lawvere metrics need NOT be symmetric (`d(A,B) ≠ d(B,A)` allowed)

These generalizations preserve the V-category structure; classical metrics are the symmetric special case.

### §4.3 The Lawvere quantale as the unifying V

The monoidal poset `([0,∞], ≥, 0, +)` IS a quantale:
- Complete lattice (every subset has infimum in `[0,∞]`)
- Monoid `(+, 0)`
- Addition distributes over infima

This is the **Lawvere quantale**. When we say "the tropical quantale" in the metric/cost context, we mean the Lawvere quantale (or equivalent formulations using `≤` instead of `≥`, or using `max` instead of `min`).

The critical insight: **a tropical cost is a Lawvere metric. A fuel-budget computation is a Lawvere-metric fixpoint. A cost-bounded search is a V-functor from a goal structure to the Lawvere quantale.**

### §4.4 Rational and Polynomial Lawvere Logic

Recent work (Bacci-Mardare-Panangaden-Plotkin 2023; Dagstuhl CSL 2026 _Rational Lawvere Logic_ invited paper) develops propositional logics over the Lawvere quantale. Sequents express **inequalities between rational functions** over non-negative extended reals; the logic supports quantitative reasoning about metric spaces and behavioral distances between programs.

**Polynomial Lawvere Logic** (Dagstuhl 2026) extends this by adding multiplication, turning the Lawvere quantale into a richer algebra — the Lawvere quantale becomes a semiring and then a quantale with additional structure.

For Prologos: these logics are exactly the kind of surface we'd want to expose if fuel/cost becomes first-class at the language level. A user might write `:cost ≤ f(n) + g(m)` as a spec-level assertion, to be discharged by the type checker against the tropical quantale.

Phase 9 scope does NOT touch language surface; this is forward-referenced work for future self-hosting and the extended spec system.

### §4.5 Value quantales and convergence

A **value quantale** (Flagg) is a quantale satisfying additional axioms that guarantee well-behaved topological / metric reasoning — affine, completely distributive lattice, closure-under-finite-joins of specific subsets. The category of value-quantale-enriched categories is equivalent to a natural class of topological spaces.

The Lawvere quantale IS a value quantale. So is any tropical quantale of practical interest in Prologos.

**Convergence and quantale-enriched categories** (Jäger-Güloğlu 2017) establishes convergence theory for V-categories where `V` is an arbitrary value quantale. This gives us a formal framework for "fixpoint convergence of cost-tracked propagator networks" without hand-waving.

---

## §5 Residuation theory

Residuation is the backbone of backward reasoning. It converts forward "given `a`, compute `a ⊗ x` for various `x`" into backward "given `a` and `b`, find the largest `x` with `a ⊗ x ≤ b`". For Prologos, this is the mechanism that makes backward error-explanation algebraically principled rather than ad-hoc.

### §5.1 Residuated maps and sup-preserving maps

A function `f : P → Q` between complete lattices is **sup-preserving** (or **sup-continuous**, or **joins-preserving**) if `f(⋁_i x_i) = ⋁_i f(x_i)` for all subsets `{x_i}`.

**Theorem (classical, see e.g. Blyth-Janowitz)**: `f : P → Q` is sup-preserving if and only if it has a right adjoint `f^* : Q → P` satisfying `f(x) ≤ y ⟺ x ≤ f^*(y)`. The right adjoint is called the **residual** of `f`.

This is the algebraic form of the Galois connection: `f ⊣ f^*` are **adjoint functors between poset categories**. Sup-preservation on the left forces the existence (and uniqueness) of the right adjoint.

**Key fact**: the quantale operation `a ⊗ ·` is sup-preserving in its right argument (by quantale distributivity). Therefore its residual `·/a` exists, giving us `a \ b = (a ⊗ ·)^*(b)`. This is WHY quantales have residuation for free.

### §5.2 Closure operators

A **closure operator** `c : P → P` on a poset is an **extensive** (`x ≤ c(x)`), **monotone** (`x ≤ y ⟹ c(x) ≤ c(y)`), **idempotent** (`c(c(x)) = c(x)`) map.

**Theorem (pairwise correspondence)**: on a complete lattice, the following are in one-to-one correspondence:
1. Sup-preserving surjections `f : P → Q`
2. Closure operators `c : P → P` (via `c = f^* ∘ f`)
3. Galois connections `(f, f^*)` between `P` and `Q`

This triple correspondence is the technical core of residuation theory. Propagators as sup-preserving maps induce closure operators on the cell-value lattice — the closure is "what the propagator structurally commits to." This is a precise formalization of the intuition "propagators are monotone accumulators."

### §5.3 Galois connections as adjoint pairs

A **monotone Galois connection** between posets `(P, ≤_P)` and `(Q, ≤_Q)` is a pair `(f, g)` of monotone functions `f : P → Q, g : Q → P` satisfying:

    f(x) ≤_Q y  ⟺  x ≤_P g(y)

`f` is the **left adjoint** (= sup-preserving / residuated); `g` is the **right adjoint** (= inf-preserving / residual).

Galois connections compose: given `P ⇄ Q ⇄ R`, we get `P ⇄ R` by composition of the adjoint pairs. This is **functor composition in the 2-category of posets**.

For Prologos: cross-domain bridges (TypeFacet ↔ Fuel quantale, scope ↔ commitments, ...) are Galois connections. They compose via connection composition. This is the formalization behind the "Module Theory Galois bridges" framing in §5 of the Module Theory research.

### §5.4 The quantale of Galois connections

**Theorem (Garcia-Serrada-Orejas, _Algebra Universalis_ 2004)**: the set of all Galois connections on a complete lattice `L`, ordered componentwise, is itself a quantale under composition.

This is a beautiful meta-structural fact. The set of BRIDGES between quantales (or more generally, adjoint pairs on a fixed lattice) forms a quantale. So:
- Bridges between TypeFacet and Fuel compose via quantale operations
- Chaining bridges corresponds to tensor `⊗` in the bridge-quantale
- The bridge-space itself has residuation (we can ask "what bridge, composed with `b`, gives the composite bridge `c`?")

For Prologos's architecture: this tells us that the bridge-space is structurally REGULAR and admits the same reasoning we apply to base quantales. It is not a lawless collection of functions — it's a quantale in its own right.

### §5.5 Residuation on tropical series (Inria/IEEE)

**"Residuation of tropical series: rationality issues"** (Gaubert-Katz-Cohen-Quadrat) studies residuation in the specific tropical-power-series setting used for control theory and discrete-event systems. Central question: when is the residual of a rational tropical series itself rational?

Findings relevant to Prologos:
- Residuation in tropical-power-series is decidable under natural finiteness conditions
- For delay-control systems (analogous to our BSP-round-based cost tracking), residuals can be computed in polynomial time given bounded state
- The computational cost of backward reasoning is not prohibitive — it's in the same complexity class as forward propagation

Implication: **tropical-quantale residuation is algorithmically feasible in Prologos's setting**. Not every quantale has efficient residuation algorithms; the tropical case has strong positive results.

### §5.6 Backward reasoning via residuation — synthesis

From §5.1-§5.5, the picture is coherent:

- Propagators are sup-preserving maps on cell-value lattices
- Every sup-preserving map has a unique residual (right adjoint)
- The residual IS the backward-reasoning operator (given output, compute largest input)
- In tropical quantales, residuals have clean formulas (`a \ b = b − a` when `b ≥ a`)
- Composition of residuals corresponds to composition of propagators in reverse direction

This aligns with **Module Theory §5**: "backward chaining IS residuation." The tropical case is the first concrete implementation target. For Phase 9's tropical fuel cell, this means:

- The fuel-consumption chain during propagator firing is a sequence of tropical `⊗` operations
- The residual computation walks this chain backward
- Fuel exhaustion at `+∞` (the tropical `⊤`) has a residual explanation as "reverse cost-accumulation along the dependency graph"
- Module Theory §6 (e-graphs as quotient modules) extends this to the PReduce rewriting setting: cost-guided extraction IS tropical-quantale residuation on the quotient module

Further reference: the **tropical polynomial optimization** literature (MDPI 2021 "Algebraic Solution of Tropical Polynomial Optimization Problems") explicitly uses **backward elimination + forward substitution** as the algorithmic core. This is the operational shape of residual-based error-explanation.

---

## §6 Quantale modules

Quantale modules generalize abelian-group modules to the order-theoretic setting. For Prologos, they are the formal framework for "cells with values in a quantale, acted on by propagators."

### §6.1 Left / right Q-modules

Let `Q` be a quantale. A **left Q-module** is a complete lattice `M` together with an action `· : Q × M → M` satisfying:

- `a · (⋁_i m_i) = ⋁_i (a · m_i)` (sup-preservation in `M`)
- `(⋁_i a_i) · m = ⋁_i (a_i · m)` (sup-preservation in `Q`)
- `(a ⊗ b) · m = a · (b · m)` (associativity of action)
- `1 · m = m` (unital, if `Q` is unital)

A **right Q-module** is the mirror (action `M × Q → M`). Commutative quantales have equivalent left and right modules; for our use case (commutative tropical quantale), we don't distinguish.

### §6.2 Sup as the natural home

The category `Sup` of complete lattices and sup-preserving maps is symmetric monoidal closed, with a tensor product `P ⊗ Q` representing "joint states." A quantale is a monoid in Sup; a Q-module is an action of this monoid on another Sup-object (a complete lattice).

**Theorem (classical)**: 2-modules (modules over the Boolean quantale `𝔹 = {⊥, ⊤}`) are exactly complete lattices. Equivalently: every complete lattice is a `𝔹`-module under the action `⊥ · m = ⊥, ⊤ · m = m`.

This means quantale modules generalize complete lattices — they ARE complete lattices equipped with an action by a richer algebraic structure.

For Prologos:
- Cells hold values in a complete lattice (bot, top, joins)
- Propagators are sup-preserving endomaps (monoid actions on the cell lattice)
- The monoid they inhabit is a quantale (composition distributes over joins)
- Therefore cells are quantale modules, and propagators are quantale-module homomorphisms

This is not new terminology for existing structure — it's the precise formal framing of what Prologos already does.

### §6.3 Russo 2010: quantale modules structure theory

**Russo (arXiv:1002.0968)** _Quantale Modules and their Operators_ is the canonical modern reference for quantale-module theory. Key results:

- Characterization of sub-modules, quotient modules, and module morphisms
- Tensor products of Q-modules
- Duality theory (Sup is self-dual under `P ↦ P^op`)
- Projective and injective modules over quantales
- Relationship to Abramsky-Vickers' observational semantics

Russo establishes that much of classical ring-module theory transfers to quantale modules with appropriate modification. This is load-bearing for Prologos: we can apply module-theoretic reasoning (submodule decomposition, tensor products, quotient constructions) to cell-lattices without re-deriving from scratch.

### §6.4 Module morphisms, tensor products, residuated actions

A **Q-module morphism** `f : M → N` preserves joins and action: `f(⋁_i m_i) = ⋁_i f(m_i)` and `f(a · m) = a · f(m)`.

The **tensor product** `M ⊗_Q N` has universal property: Q-bilinear maps `M × N → P` correspond to Q-linear maps `M ⊗_Q N → P`. This gives us the mechanism for "combining cell values across cells."

**Residuated actions**: if the action `Q × M → M` is sup-preserving in the second argument (which is required by the module axioms), it has a residual `M × M → Q` giving "the minimum scalar needed to produce a result." For tropical Q-modules, this computes "the minimum cost to reach a target state."

### §6.5 Cells as Q-modules

In Prologos terms: a cell holds a value in a complete lattice `C` (bot, top, joins). The propagators watching the cell act on it via `P × C → C`, where `P` is the set of propagators. This action:
- Preserves joins (merges compose monotonically)
- Is associative (composition of propagators is well-defined)
- Has a unit (identity propagator)

If we equip `P` with join (for "which propagator fires first is a choice made by the scheduler") and composition, `P` is a quantale. The cell `C` is then a `P`-module.

This is a rigorous formalization of the intuitive "cells are acted on by propagators." And it's not just notation: it gives us access to all the module-theoretic machinery (sub-modules, tensor products, residuation, duality) for reasoning about cell/propagator systems.

### §6.6 Propagators as Q-module homomorphisms

A **propagator morphism** between two cells `C1` and `C2` is a Q-module morphism `f : C1 → C2`. Concretely: a function that reads `C1`'s value, computes a value in `C2`, and satisfies:
- `f(⋁_i v_i) = ⋁_i f(v_i)` (sup-preservation — propagator output respects cell merges)
- `f(a · v) = a · f(v)` (action-preservation — propagator commutes with the quantale action)

The second condition is where tropical structure matters: if `C1` and `C2` are both `T_{min}`-modules (both track cost), then a propagator `f : C1 → C2` must **preserve cost transformations**. Specifically, if `a` is a cost and `v` is a cell value, then "apply cost `a` then propagate" equals "propagate then apply cost `a`" — propagator commutes with cost scaling.

This is a strong constraint. It rules out propagators that silently absorb or manufacture cost; it forces propagators to be faithful with respect to the tropical structure. For fuel accounting, this is exactly what we want.

### §6.7 Tarski fixpoint on Q-modules — CALM parallel

**Tarski's fixpoint theorem**: every monotone map on a complete lattice has a least fixpoint, computable as the join of the iterated images of bot.

For Q-modules: every Q-module endomap (that is, Q-module morphism from `M` to `M`) has a least fixpoint in `M`. Convergence is guaranteed in the complete-lattice setting.

The CALM theorem (Hellerstein 2010) for distributed systems states that **monotone computations are coordination-free**. This is Tarski's theorem applied to the distributed setting: if each node's computation is a monotone endomap on its local lattice, the global least fixpoint is reached without explicit synchronization.

For Prologos: the propagator network is a Q-module fixpoint computation. CALM guarantees correctness regardless of scheduling order (for the monotone stratum S0). Stratification (S1, S(-1)) handles non-monotone effects by isolating them between strata, preserving the Tarski-fixpoint structure within each stratum.

**The tropical fuel cell lives naturally in this framework**: fuel is a Q-module value; fuel-consuming propagators are Q-module endomorphisms; fuel exhaustion is reaching `⊤ = +∞` in the Q-module. Monotonicity is automatic (fuel only accumulates — you never "un-pay" cost). CALM theorem applies.

---

## §7 Idempotent analysis — the Litvinov-Maslov lineage

Idempotent analysis is the mathematical-physics tradition that developed much of the tropical/idempotent machinery independently from the logic/CS quantale line. Understanding this lineage gives us access to a mature body of results (and algorithms) for idempotent semi-modules that directly transfers to quantale-module applications.

### §7.1 Maslov dequantization

**V. P. Maslov** (1980s-1990s) observed that replacing `(ℝ, +, ×)` by `(ℝ ∪ {−∞}, max, +)` (the max-plus semiring) converts many nonlinear problems into "linear" problems over the idempotent semiring. The transformation is termed **Maslov dequantization**: it corresponds to taking the Planck constant `ℏ` to zero in a specific asymptotic limit, turning quantum-mechanical / statistical problems into tropical optimization.

The correspondence (Litvinov-Maslov 2001, _Mathematical Notes_):

    classical arithmetic (+, ×, 0, 1)
      ↓  ℏ → 0  (dequantization)
    tropical arithmetic (min, +, +∞, 0)   or   (max, +, −∞, 0)

Many classical optimization problems (Hamilton-Jacobi equations, variational principles) become linear in the idempotent setting. The dequantization gives a systematic method for transferring classical techniques to tropical ones.

### §7.2 Idempotent semi-modules

An **idempotent semi-module** is a module over an idempotent semiring (= quantale, by the Fujii equivalence §3.4). Litvinov-Maslov developed functional analysis for these — the theory of functions with values in idempotent semi-modules, linear operators, spectra, eigenvalues, etc.

Key results:
- **Idempotent Fourier transform**: Legendre transform plays the role of the Fourier transform; Hamilton-Jacobi equations become "linear" in the tropical sense
- **Idempotent integration**: integral with respect to an "idempotent measure" is a max / sup operation
- **Spectral theory for idempotent operators**: tropical eigenvalues (Perron-Frobenius analogs) govern convergence of iterated operations

For Prologos: these are the mature mathematical-physics results that apply to our tropical-quantale cells. We don't need to develop this from scratch; we inherit.

### §7.3 Litvinov-Maslov 2001: _Idempotent Functional Analysis_

**Litvinov-Maslov 2001** (_Mathematical Notes_, arXiv:math/0009128) is the canonical reference for the algebraic approach to idempotent analysis. The paper establishes:

- Axiomatic framework for idempotent semi-modules
- Spaces of continuous functions with values in idempotent semirings
- Linear operators and their spectra
- Duality theory (Legendre transform as the idempotent Fourier transform)
- Applications to Hamilton-Jacobi-Bellman equations

For Prologos: we can cite this directly as the functional-analytic foundation for cell-lattice-valued functions (i.e., propagator fire functions viewed as functions on cell state spaces).

### §7.4 Correspondence principle

Litvinov-Maslov formulate the **correspondence principle for idempotent calculus**: there is a systematic dictionary translating classical (real-valued) constructions into idempotent ones. Examples:

| Classical | Idempotent (max-plus) |
|---|---|
| Addition `+` | Max `∨` |
| Multiplication `×` | Addition `+` |
| Integral `∫` | Supremum `sup` |
| Fourier transform | Legendre transform |
| Linear operator | Idempotent-linear operator |
| Eigenvalue | Tropical eigenvalue |
| Green's function | Max-plus kernel |

The correspondence principle is not merely analogy — it is a FUNCTORIAL relationship between classical analysis and idempotent analysis. Much of the classical toolkit transfers.

For Prologos: when we need a technique for analyzing tropical-quantale computations (convergence rates, stability, perturbation theory), we first check the idempotent-analysis literature for the translated classical result.

### §7.5 Idempotent optimization and discrete-event systems (BCOQ)

**Baccelli, Cohen, Olsder, Quadrat** (1992) _Synchronization and Linearity: An Algebra for Discrete Event Systems_ is the canonical reference for max-plus algebra applied to discrete-event systems (DES). DES are systems whose state changes at discrete times driven by events; synchronization of parallel processes, queueing networks, and scheduling problems all fit this framework.

Key results:
- Max-plus matrix operations model DES dynamics
- Kleene star of max-plus matrices gives "asymptotic" behavior
- Tropical eigenvalues govern long-run throughput
- Cyclic schedules are computable via max-plus Perron-Frobenius theory

For Prologos: the **BSP round structure IS a discrete-event system**. Each BSP superstep is an "event"; propagator firings synchronize at round boundaries; cost accumulation per round is max-plus-linear. The BCOQ framework applies to our scheduling analysis.

Specific applications:
- **Throughput analysis**: max-plus eigenvalue of the per-round cost matrix gives asymptotic cost growth rate
- **Cycle detection**: tropical Perron-Frobenius theory detects cost-accumulating cycles (which cause non-termination in cost-bounded search)
- **Schedule optimization**: cyclic scheduling results transfer to "which propagators to fire in which round to minimize total cost"

This is a direct transfer of mature DES results to Prologos's scheduling analysis. Phase 9 does not need to develop this from scratch.

### §7.6 Implication for Prologos

The Litvinov-Maslov tradition tells us:
- Our tropical fuel cell lives in a mature mathematical theory
- The functional analysis of cell-valued functions is developed
- The algorithmic techniques (Kleene star, tropical eigenvalues) are known
- Complexity results and asymptotic analyses transfer from DES literature
- The correspondence principle gives us a systematic translation for new problems

We are not pioneering; we are specializing a well-developed framework to our specific architecture. This is a strength: Phase 9's tropical fuel cell has a deep theoretical foundation, which reduces risk of unexpected pathologies at scale.

---

## §8 Cost semantics and abstract interpretation

Abstract interpretation (Cousot-Cousot 1977) is the foundational framework for sound program-analysis via monotone functions on ordered domains. Quantale-valued cost analysis is a natural extension.

### §8.1 Cousot-Cousot abstract interpretation

**Abstract interpretation** approximates program semantics via a pair of complete lattices `(C, ⊑_C)` (concrete) and `(A, ⊑_A)` (abstract), connected by a **Galois connection** `α : C → A, γ : A → C`. Program constructs induce monotone maps on `C`; their abstract counterparts are computed via `α ∘ f ∘ γ`. Soundness is guaranteed by the Galois connection; precision is lost via the `γ ∘ α` approximation.

Key properties:
- **Soundness**: `α(f(c)) ⊑_A f_#(α(c))` — the abstract computation over-approximates the concrete
- **Fixpoint transfer**: `α(lfp f) ⊑_A lfp f_#` — abstract fixpoint over-approximates concrete fixpoint
- **Termination**: finite lattice or well-founded measure guarantees abstract-interpretation termination

### §8.2 Injecting abstract interpretations into cost models

**"Injecting Abstract Interpretations into Linear Cost Models"** (Navas-Mera-López-García-Hermenegildo, arXiv:1006.5098) extends abstract interpretation to **linear cost models**: programs are analyzed for resource consumption (cost, time, memory) using an algebraic structure equipped with linearity properties.

Relevant to Prologos:
- Cost models are formalized as semiring/quantale valuations
- Abstract interpretation framework carries over with minimal modification
- Soundness theorems hold: the cost-abstract interpretation over-approximates actual cost
- Complexity: polynomial in program size for most practical analyses

For Phase 9: this is the theoretical justification for using tropical-quantale-valued abstract interpretation to analyze fuel-bounded computations. Our fuel analysis IS a linear-cost abstract interpretation in this sense.

### §8.3 Cost-based semantics for weighted knowledge bases

**"Cost-Based Semantics for Querying Inconsistent Weighted Knowledge Bases"** (arXiv:2407.20754) extends algebraic model counting (AMC) to a cost-semiring setting: each interpretation has a cost (sum of violated weighted axioms); answers are defined either by bounded-cost interpretations or by optimal-cost interpretations.

Technical contributions:
- Cost-aggregation via tropical semiring
- Complexity analysis for cost-bounded and cost-optimal query answering
- Relationship to abstract model counting and weighted logic programming

Relevance to Prologos: this is another body of cost-semantics theory we can cite. It's especially relevant for future self-hosted queries that need cost-bounded resolution (e.g., "find me the minimum-cost proof").

### §8.4 Bisimulations for quantale-weighted networks (Filomat 2023)

**"Bisimulations for weighted networks with weights in a quantale"** (Filomat 2023, vol. 37, no. 11) develops bisimulation theory for networks whose edges are weighted by elements of a commutative quantale. Central results:

- Bisimulation = Galois connection on weighted-network states
- Quantale structure gives the right notion of "equivalent behavior modulo quantitative distinction"
- Coalgebraic framing: weighted networks are coalgebras for an appropriate functor on Sup

For Prologos: bisimulation is the right algebraic notion of "two propagator networks have equivalent behavior." For cost-tracked networks (fuel, memory, messages), bisimulation in a quantale-weighted setting is the correct formalism. This matters for optimization: rewriting a propagator network in a bisimulation-preserving way guarantees behavior is preserved.

### §8.5 Quantitative behavioral reasoning

**"Quantitative Behavioural Reasoning for Higher-order Effectful Programs: Applicative Distances"** (Gavazzo 2018) applies quantale-valued metrics to effectful higher-order programs, giving behavioral distances that measure "how much two programs differ in observable behavior."

Relevance: this gives us a formalism for reasoning about the OBSERVABLE cost differences between two implementations of the same propagator network. Useful for benchmarking (A/B) and optimization work: "does this rewrite preserve cost behavior up to distance `ε`?"

---

## §9 Tropical quantale — definition and structure

Having surveyed the foundations, we now assemble the specific tropical-quantale definition we need for Phase 9.

### §9.1 Formal definition

The **tropical quantale** (min-plus variant) is the structure `T_{min} = (ℝ ∪ {+∞}, ≤_{rev}, +, 0)` where:

- **Carrier**: non-negative extended reals `[0, +∞]` (we use the non-negative part for fuel — negative fuel doesn't make sense)
- **Order**: `a ≤_{rev} b ⟺ a ≥ b` (reverse order — smaller cost is "higher" in the lattice)
- **Join**: `⋁_{rev} {a_i} = inf_i a_i = min_i a_i` (reversed sup is inf)
- **Meet**: `⋀_{rev} {a_i} = sup_i a_i = max_i a_i`
- **Tensor**: `a ⊗ b = a + b` (ordinary addition; `+∞ + a = +∞` by convention)
- **Unit**: `0` (additive identity; `0 + a = a`)
- **Top (in `≤_{rev}`)**: `0` (minimum cost is the top)
- **Bot (in `≤_{rev}`)**: `+∞` (infinite cost is the bottom — unreachable)

Note the order-reversal: in the cost interpretation, "lower cost is better," so we orient the lattice so that `0` is top and `+∞` is bot. This is conventional in the Lawvere-quantale literature.

Alternative formulation (max-plus, bit less natural for fuel): `T_{max} = (ℝ ∪ {−∞}, ≤, +, 0)` with join = max, top = `+∞` (unbounded), bot = `−∞`.

For Phase 9 we use `T_{min}` throughout. When we say "tropical quantale" without qualification, we mean `T_{min}` in the `[0, +∞]` variant.

### §9.2 Lattice + monoid + distributivity verification

Checking the quantale axioms for `T_{min}`:

1. **Complete lattice**: `([0, +∞], ≤_{rev})` is a complete lattice. Any subset of `[0, +∞]` has an infimum (including `+∞` and `0` themselves).

2. **Monoid `(+, 0)`**: addition is associative, commutative, with identity `0`.

3. **Distributivity**: `a + inf_i b_i = inf_i (a + b_i)`. For all `a, b_i ∈ [0, +∞]`, this holds because addition is monotone in both arguments. Distributivity in the reversed order corresponds to ordinary monotone arithmetic.

So `T_{min}` is a **commutative unital quantale**. It is also **integral**: `1 = 0` is the multiplicative unit, and `⊤ = 0` is the lattice top (in `≤_{rev}`). These coincide. `T_{min}` is integral.

### §9.3 Residuals

By the quantale structure, `T_{min}` has residuals. The **left residual** `a \ b` satisfies `a ⊗ x ≤_{rev} b ⟺ x ≤_{rev} a \ b`, that is, `a + x ≥ b ⟺ x ≥ a \ b`.

Solving: `x ≥ b − a` (when `b ≥ a`), and `x ≥ 0` always (since `x ∈ [0, +∞]`). So:

    a \ b = {
        b − a    if b ≥ a
        0        if b < a  (vacuously satisfied, residual is `0` = top)
    }

Since `T_{min}` is commutative, `a \ b = b / a`.

The residual has a clean operational meaning for fuel: **given that you've spent `a` fuel and your budget was `b`, the residual `b \ a = a − b` (when `a ≥ b`, else `0`) is the "overspend."** When residual is `+∞`, you've exhausted the budget entirely.

Wait — let me recompute with proper attention. The Lawvere-quantale convention uses `≥` as the order, so `b ≥ a` in the Lawvere order means `b ≤ a` in the natural order. The residual formula depends on the convention.

For Prologos: we want the operational reading "fuel left = budget − cost_so_far". In the `T_{min}` with natural `≤_{rev}` (smaller = higher):
- `budget ≤_{rev} cost_so_far` (cost has exceeded budget) means `budget ≥ cost_so_far` in natural order
- `budget \ cost_so_far` is the remaining budget when `cost_so_far ≤ budget`

Operationally: `remaining = budget − cost_so_far` when non-negative, else `+∞` (exhausted).

This is the **residual in the Lawvere-metric convention**. The algebra is clean.

### §9.4 Tropical quantale module structure

A **`T_{min}`-module** `M` is a complete lattice with a cost-action `+ : T_{min} × M → M` satisfying the module axioms. Concretely: `M` is a lattice of states; each state has an associated cost; propagators increment costs; join in `M` is "take the cheapest state"; cost-action scales all states' costs by an amount.

This is EXACTLY the framework Prologos needs:
- **Cells with fuel**: the cell value is a pair `(state, cost)` where `state ∈ L` (some state lattice) and `cost ∈ T_{min}`. This is a `T_{min}`-module.
- **Propagators with cost**: a propagator that consumes `c` fuel is a `T_{min}`-module morphism that scales cost by `+c`.
- **Fuel exhaustion**: when `cost = +∞` (tropical bot), the state is "unreachable."

The module-theoretic framing provides the full toolkit: submodules (subsets of reachable states under a cost budget), tensor products (combining costs from multiple sources), residuation (backward cost tracing).

### §9.5 Max-plus Kleene star — O(n⁴) algorithm

**Modified Kleene Star Algorithm** (Wilopo et al., MDPI 2023) presents an `O(n⁴)` algorithm for computing the max-plus Kleene star of an `n × n` matrix. The classical algorithm is `O(n(n!))` (factorial — impractical); the modified algorithm leverages the specific properties of tropical matrices to run in polynomial time.

For Prologos: if we represent the propagator dependency graph as a tropical matrix, Kleene star computes "the cheapest path of any length between any two propagators." This gives us:
- **Asymptotic throughput**: the max-plus eigenvalue is the Kleene-star-convergent cost per round
- **Critical path**: the longest-cost path sequence (for parallelism bounds)
- **Cost-bounded search**: given a fuel budget, pre-compute which (source, target) pairs are reachable

Implementation cost: `O(n⁴)` is reasonable for `n` propagators in the hundreds-to-thousands range. For larger networks, faster algorithms exist (e.g., Seidel-based `O(n^{2.376})`), but for Prologos scale `O(n⁴)` is adequate.

### §9.6 "Dijkstra, Floyd, Warshall Meet Kleene" — formal framework

**Bernhard Beckert, Steffen Lange** (NICTA 2009) formalize the correspondence between classical shortest-path algorithms (Dijkstra, Floyd-Warshall) and Kleene-algebra computations in Isabelle/HOL. Their framework:

- All three algorithms are instances of Kleene-star computation over different semirings
- Correctness proofs reduce to Kleene-algebra axiom verification
- Complexity bounds follow from the algebraic structure

For Prologos: this gives us a **formal verification target** for our tropical-quantale infrastructure. If we formalize fuel-cost computations as Kleene-star operations in the tropical quantale, we can transfer the NICTA verification directly (or at least its proof patterns).

This is deferred work (not Phase 9 scope), but pinned here for future self-hosted proof-aware compilation.

### §9.7 Summary table: what each layer adds

| Layer | Adds | Key use in Prologos |
|---|---|---|
| Tropical semiring | Addition (⊕ = min), multiplication (⊗ = +) | Basic cost algebra |
| Dioid = idempotent semiring | Natural order from idempotent addition | Cost comparison |
| Complete semiring | Arbitrary joins; convergence of infinite sums | Termination analysis |
| Quantale (= complete idempotent semiring) | Quantale axioms; distributivity over arbitrary joins | Our core structure |
| Residuated quantale | Left/right residuals | Backward error-explanation |
| Integral quantale (1 = ⊤) | Unit coincides with lattice top | Clean fuel semantics |
| Lawvere quantale (specific instance) | Metric interpretation; V-category framing | Distance/cost enrichment |
| Q-module structure | Cells as modules; propagators as homomorphisms | Formal cell/propagator theory |

The takeaway: **every layer buys something concrete for Prologos engineering**. Semirings alone would give us cost arithmetic; quantales give us completeness + residuation; V-category framing gives us metric-style enrichment; Q-modules give us formal cell/propagator theory.

---

## §10 Prologos-specific synthesis — design implications

This section translates the foundations into concrete implications for Phase 9's tropical fuel cell and PReduce's future cost-guided rewriting.

### §10.1 Tropical fuel cell as min-plus quantale cell

**Proposal**: Phase 9 ships a cell `fuel-cell-id` whose value is in `T_{min} = ([0, +∞], ≤_{rev}, +, 0)`, with:

- **Initial value**: `0` (tropical top — no cost accumulated)
- **Merge function**: `min` (tropical join — take the cheapest cost-accumulation path)
- **Contradiction predicate**: `= +∞` (tropical bot — exhausted)

Propagators that consume fuel write `cost_after = cost_before + Δc` via `net-cell-write`. The merge function `min` ensures monotone accumulation (cost only increases along any path, but the cell-value is the MINIMUM cost across alternative paths — consistent with tropical-semiring shortest-path semantics).

Phase 1f classification: `'structural` if we want per-component fuel tracking (different cost currencies), `'value` if it's atomic cost. For the minimum-viable Phase 9, we propose `'value` — single scalar fuel, like `(fuel 1000000)` today.

### §10.2 Fuel exhaustion as contradiction via quantale-top

When fuel reaches `+∞` (tropical bot), the cell is in contradiction. The standard contradiction mechanism (`net-contradiction` flag on the network) triggers, halting computation.

Advantage over the current decrementing-counter approach: **the contradiction mechanism is now structurally unified** with other contradictions (type-top, classify-inhabit-contradiction, etc.). A single contradiction-handling path in the propagator scheduler applies uniformly.

Implementation note: the merge function `min` combined with `contradicts? = (= +∞)` is the full contradiction story. No separate "check fuel" code needed anywhere — the cell-write path detects exhaustion automatically.

### §10.3 Residuation as fuel-cost error-explanation

When fuel exhaustion fires (cell reaches `+∞`), the user deserves an explanation: **which propagators consumed the fuel, in what quantities, leading to exhaustion?**

The **residuation computation** provides this natively:

    given: budget B (= initial fuel), exhaustion cost C = +∞
    compute: reverse-decomposition of C into contributing propagator costs

Algorithmically: walk the propagator dependency graph backward from the exhausting write, summing the per-propagator costs until the sum equals `B`. This IS the residual `B \ C` computed along the dependency chain.

This is not ad-hoc diagnostic tooling — it's the quantale residual, computed over the Q-module structure of the fuel cell. Module Theory §5 ("backward chaining IS residuation") directly applies.

**Engineering value**: instead of hand-rolling a fuel-exhaustion-explanation subsystem (error messages, heuristic blame-assignment), the residuation framework gives a principled mechanism that:
- Is algebraically correct (proof-preserving under the quantale axioms)
- Extends to multi-quantale cost (future: fuel + memory + messages)
- Composes with other backward-reasoning mechanisms (type-error provenance, BSP-LE nogood traces)

### §10.4 Galois bridge: tropical fuel ↔ SRE 2H TypeFacet quantale

The SRE 2H TypeFacet is a quantale (⊕, ⊗, residuals). The tropical fuel cell is a quantale (`T_{min}`). These are two quantales in the same network.

**Galois bridge**: a pair of sup-preserving maps `(α, γ)` between TypeFacet and `T_{min}`, corresponding to:
- `α` (forward): given a type, what's the lower-bound cost of elaborating to that type? (E.g., pure types are cost-0; types requiring trait resolution cost `Δ_trait`; unions cost `Δ_union × |components|`.)
- `γ` (backward): given a fuel budget, what types are elaborable within budget?

This bridge is a proper Galois connection (by §5.1-§5.3). It composes with the existing SRE 2H bridges via quantale-of-Galois-connections structure (§5.4).

**Engineering value**: cost-aware elaboration becomes algebraically principled:
- Cost-bounded elaboration = `γ` applied to budget
- Cost-of-elaboration = `α` applied to type goal
- Cost-explanation = residual through the Galois bridge

For Phase 9 MVP: this bridge is DEFERRED (it requires wiring at the elaboration level). The infrastructure (tropical fuel cell + residuation) ships in Phase 9; the bridge is future work.

### §10.5 Module-theoretic framing

Cells are Q-modules; propagators are Q-module homomorphisms. Concretely for Phase 9:
- Fuel cell is a `T_{min}`-module (trivially — the module IS `T_{min}` itself viewed as a 1-dimensional `T_{min}`-module)
- Cells that track cost (e.g., per-meta cost of elaboration) are `T_{min}`-modules
- Propagators that consume fuel are `T_{min}`-module homomorphisms scaling cost by `+Δ`

This framing gives us:
- **Sub-module decomposition**: which cells participate in fuel accounting? (the submodule structure identifies them)
- **Tensor products**: combining cost from multiple cells (the product quantale-module structure)
- **Residuation**: backward cost tracing (as in §10.3)

For engineering: the framing is not abstract overhead — it's the precise formalization of what we're already building. It gives us guarantees (monotonicity, fixpoint convergence, CALM) for free.

### §10.6 Hypercube / worldview interaction — cost-per-branch

In BSP-LE 2B, the worldview is a Q_n hypercube (bitmask, size 2^n for n assumptions). Each worldview corresponds to a bit-pattern of committed assumptions.

**Tropical extension**: each worldview has a COST — the accumulated fuel under that assumption combination. The cost function is a map `Q_n → T_{min}` from the hypercube to the tropical quantale.

This map is a Q_n-module structure on `T_{min}`: worldview assumptions act on cost (each assumption carries its own cost contribution).

**Implication**: cost-aware worldview search prunes branches whose cost exceeds budget. The cost-per-branch is computed by summing bit-costs along the hypercube path from ⊥ to the current worldview.

Hypercube algorithms from the 2026-04-08 addendum (Gray code, bitmask subcube) extend naturally:
- **Gray code traversal** visits adjacent worldviews differing by one assumption — cost changes by one assumption's cost per step. Optimal CHAMP sharing + optimal cost-update (single-assumption adjustment per step).
- **Bitmask subcube pruning** extends to cost-subcube pruning: "all worldviews containing this nogood exceed cost budget" is a tropical-subcube check.

This integrates Phase 9 (tropical fuel) with Phase 9β (hypercube algorithms) cleanly. The cost structure is orthogonal to the Boolean worldview structure but composes multiplicatively with it.

### §10.7 PReduce template — cost-guided rewriting

PReduce (future track) performs e-graph rewriting with cost-guided extraction. The e-graph is a quotient module (Module Theory §6); the extraction is **residuation on the tropical quantale**.

Template:
- E-graph is the free monoid on rewrite rules, quotiented by rule applications (Module Theory §6)
- Each rule has a cost (tropical tensor element)
- Extraction = find the minimum-cost representative of the equivalence class
- Computed via tropical-quantale Kleene star on the rule-application dependency graph

PReduce inherits Phase 9's tropical-quantale infrastructure. Specifically:
- Fuel cell → cost cell (per e-class, not global)
- Propagator-as-homomorphism → rewrite-rule-as-morphism (same formal structure)
- Residuation → extraction (one specific instance)

For engineering: writing PReduce on top of Phase 9's tropical-quantale substrate is much cheaper than rebuilding the algebra. The common primitives (cost-cell, residuation, Galois bridges) are the Phase 9 deliverables.

### §10.8 BSP-LE 2B `(fuel 1000000)` — current state and migration path

Current state (as of 2026-04-21): `prop-network-fuel` is a plain field on `prop-net-cold` struct, decremented by `(- (prop-network-fuel net) n)` in `run-to-quiescence-bsp`. When fuel reaches 0, the loop exits.

This is OFF-network state. Phase 9's tropical fuel cell migrates this to:
- Cell value in `T_{min}`
- Accumulated cost (monotone increase) rather than decrementing counter
- Contradiction at `+∞` equivalent to current "fuel <= 0" check
- Configured initial fuel = `+∞ − B` where `B` is the budget (dual encoding)

Actually, cleaner encoding: the cell holds **accumulated cost** starting at `0`, and the budget is compared to the cell value via a threshold propagator. When accumulated cost exceeds budget, the threshold propagator writes contradiction.

Migration steps (proposed — subject to audit refinement):
1. Introduce `fuel-cost-cell-id` pre-allocated in `make-prop-network`, initial value `0`, merge `min`
2. Introduce `fuel-budget-cell-id` holding the budget (constant, read-only after initialization)
3. Threshold propagator watches both cells; fires contradiction if `cost > budget`
4. Each propagator firing emits a cost increment (via `net-cell-write` with `cost_after = cost_before + Δ`)
5. Retire `prop-network-fuel` field in `prop-net-cold`
6. Retire the decrement-and-check code in `run-to-quiescence-bsp`

This is tropical-quantale-native: accumulated cost is the tropical `⊗`-product along the propagator firing sequence; `min` merge selects the cheapest accumulation across parallel branches; contradiction at budget-exceeded is the tropical-quantale top.

### §10.9 What the quantale framing buys over bare-semiring (summary)

| Aspect | Bare tropical semiring | Tropical quantale |
|---|---|---|
| Cost arithmetic | ✓ (min, +) | ✓ (min, +) |
| Monotone accumulation | ✓ (idempotent) | ✓ (idempotent) |
| Shortest path | ✓ (Kleene star) | ✓ (Kleene star) |
| Arbitrary joins | No (finite only) | ✓ (complete lattice) |
| Residuation (backward reasoning) | Ad-hoc | ✓ (structural) |
| CALM / Tarski fixpoint | Partial | ✓ (full) |
| Galois bridge composition | Ad-hoc | ✓ (quantale of bridges) |
| Module-theoretic framing | No | ✓ (mature theory) |
| V-category enrichment | No | ✓ (Lawvere framework) |
| Idempotent functional analysis | Partial | ✓ (Litvinov-Maslov) |

For Phase 9 specifically, the residuation + Galois + module framing enable:
- Principled backward error-explanation
- Composable bridges (Fuel ↔ TypeFacet, future ↔ Session, ...)
- Formal cell/propagator semantics
- Transfer of mature mathematical-physics results (DES, idempotent analysis)

The cost of the quantale framing is conceptual, not implementation: the algebra on tropical quantales is the SAME as on tropical semirings (operations are `min` and `+`); what changes is the theoretical framework we reason about.

---

## §11 Open research questions (for Phase 9 design dialogue)

These are questions that legitimately belong in Phase 9 design — they are design decisions informed by this research, not to be resolved here.

### §11.1 Which sub-class of quantale fits Phase 9?

Candidates:
- **Commutative unital integral residuated quantale** (`T_{min}` default) — maximally rich, supports all foundational techniques
- **Commutative unital residuated** (drop integrality) — allows `1 ≠ ⊤`, useful if fuel-unit and fuel-exhaustion diverge
- **Non-residuated** (drop residuals) — gives up backward reasoning, simpler

Lean: commutative unital integral residuated. This is `T_{min}` in the Lawvere convention. It's the richest and most analyzable.

### §11.2 Fuel granularity

Per-propagator-firing? Per-cell-write? Per-BSP-round? Per-subsystem (trait resolution vs unification)?

Current (fuel 1000000) is per-propagator-firing (one decrement per prop fire). Simplest; highest granularity.

Tradeoffs:
- **Per-firing**: simple, precise, but high overhead if firings are frequent and cheap
- **Per-write**: coarser; avoids accounting overhead for pure-observation fires
- **Per-round**: least precise; useful for BSP-level throughput bounds
- **Per-subsystem**: semantically rich; requires subsystem identification at fire time

Lean: **per-propagator-firing for compatibility** with current (fuel 1000000); per-subsystem as optional tagging for finer-grained analysis. Mini-design decides.

### §11.3 Residuation cost — backward-walk feasible?

Residuation on a propagator dependency graph of `n` propagators is `O(n)` per residual query. For typical elaboration (n in hundreds to thousands), this is cheap.

For error-explanation at contradiction time, the backward walk fires at most once per exhaustion. Computational cost is negligible.

For proactive pruning (residuation during forward propagation), cost scales. Deferred to future optimization.

### §11.4 Interaction with existing `(fuel 1000000)` counter

Must retire cleanly. The migration path in §10.8 above is the proposed plan. Audit (Stage 2) surveys actual call sites; design (Stage 3) locks the migration sequence.

### §11.5 PReduce extraction: semiring or quantale?

Extraction from an e-graph is tropical-semiring Kleene-star computation in the classical formulation. The quantale framing adds:
- Residuation for backward "explain why this rewrite was extracted"
- Module-theoretic reasoning about rule composition
- Galois bridge to other cost domains (memory cost of rewriting, time cost, etc.)

Lean: start with tropical-quantale framework from day one. The marginal cost over bare semiring is small; the engineering benefits compound.

### §11.6 Multi-quantale composition

Phase 9 ships one quantale (tropical fuel). Future: multi-quantale (fuel + memory + messages + time). Each a quantale; each with bridges to others.

Question: what's the natural combining structure? Options:
- **Product quantale**: `Q1 × Q2` — independent coordinates, simplest
- **Tensor product of quantales**: `Q1 ⊗ Q2` — richer, captures interactions
- **Quantaloid**: multi-object — formally richest, operationally heaviest

Mini-design for a future phase, not Phase 9. Captured here as forward reference.

### §11.7 Self-hosting: quantale framing at the language surface?

Prologos aims for self-hosting. If quantale-valued cost is first-class in the implementation, should it be first-class in the language?

Lean: yes, eventually. The Extended Spec System already supports `:properties` declarations; extending to `:cost ≤ f(n)` is a natural step. Polynomial Lawvere Logic (Dagstuhl 2026) is the logical framework.

For Phase 9: NO surface exposure. Only infrastructure. Language-level exposure is future work pinned to the self-hosting trajectory.

---

## §12 References

### §12.1 Semiring and tropical foundations
- Butkovič, P. _A note on tropical linear and integer programs_. Journal of Optimization Theory. [https://pure-oai.bham.ac.uk/ws/files/55103920/Butkovic_Note_Linear_Journal_Optimization_Theory.pdf](https://pure-oai.bham.ac.uk/ws/files/55103920/Butkovic_Note_Linear_Journal_Optimization_Theory.pdf)
- Maclagan, D., Sturmfels, B. _Introduction to Tropical Geometry_. AMS 2015.
- Gaubert, S., et al. _Max-plus algebra in discrete-event systems_. (Multiple papers.)
- Mohri, M. _Semiring Frameworks and Algorithms for Shortest-Distance Problems_. [https://www.researchgate.net/publication/2836268](https://www.researchgate.net/publication/2836268)
- Bistarelli, S., Montanari, U., Rossi, F. _Semiring-based Constraint Satisfaction and Optimization_. J. ACM 1997. [https://dl.acm.org/doi/10.1145/256303.256306](https://dl.acm.org/doi/10.1145/256303.256306)

### §12.2 Quantale theory
- Rosenthal, K. I. _Quantales and their Applications_. Longman Scientific 1990.
- Resende, P. _Quantales and Observational Semantics_. Portuguese survey.
- Abramsky, S., Vickers, S. _Quantales, Observational Logic and Process Semantics_. MSCS 1993. [https://sjvickers.github.io/QuProc.pdf](https://sjvickers.github.io/QuProc.pdf)
- nLab. _Quantale_. [https://ncatlab.org/nlab/show/quantale](https://ncatlab.org/nlab/show/quantale)
- nLab. _Module over a quantale_. [https://ncatlab.org/nlab/show/module+over+a+quantale](https://ncatlab.org/nlab/show/module+over+a+quantale)
- Russo, C. _Quantale Modules and their Operators_. arXiv:1002.0968. [https://arxiv.org/pdf/1002.0968](https://arxiv.org/pdf/1002.0968)
- Kruml, D., Paseka, J. _Algebraic and Categorical Aspects of Quantales_. (Handbook chapter.)
- Manuell, G. _Quantalic Spectra of Semirings_. arXiv:2201.06408. [https://arxiv.org/pdf/2201.06408](https://arxiv.org/pdf/2201.06408)

### §12.3 Enriched category theory
- Lawvere, F. W. _Metric spaces, generalized logic, and closed categories_. Reprints in TAC, Vol 1. [http://www.tac.mta.ca/tac/reprints/articles/1/tr1.pdf](http://www.tac.mta.ca/tac/reprints/articles/1/tr1.pdf)
- Stubbe, I. _An introduction to quantaloid-enriched categories_. 2013. [https://www-lmpa.univ-littoral.fr/~stubbe/PDF/SurveyQCats.pdf](https://www-lmpa.univ-littoral.fr/~stubbe/PDF/SurveyQCats.pdf)
- Fong, B., Spivak, D. _Seven Sketches in Compositionality_. Cambridge 2019.
- Kelly, G. M. _Basic Concepts of Enriched Category Theory_. CUP 1982 (TAC reprint).
- Bacci, G., Mardare, R., Panangaden, P., Plotkin, G. _Propositional Logics for the Lawvere Quantale_. arXiv:2302.01224. [https://arxiv.org/abs/2302.01224](https://arxiv.org/abs/2302.01224)
- Kurz, A. _Logic Enriched over a Quantale_. CALCO 2025 invited. [https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CALCO.2025.2](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CALCO.2025.2)
- Dagstuhl CSL 2026. _Rational Lawvere Logic_. [https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CSL.2026.3](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CSL.2026.3)

### §12.4 Residuation and Galois connections
- Blyth, T. S., Janowitz, M. F. _Residuation Theory_. Pergamon 1972.
- Erné, M., et al. _A primer on Galois connections_. Math. Surveys 1993.
- _Galois connection_ (nLab). [https://ncatlab.org/nlab/show/Galois+connection](https://ncatlab.org/nlab/show/Galois+connection)
- Garcia, A., Serrada, M., Orejas, F. _The quantale of Galois connections_. Algebra Universalis 2004. [https://link.springer.com/article/10.1007/s00012-004-1901-1](https://link.springer.com/article/10.1007/s00012-004-1901-1)
- Gaubert, S., Katz, R., Cohen, G., Quadrat, J.-P. _Residuation of tropical series: rationality issues_. [https://inria.hal.science/inria-00567390/](https://inria.hal.science/inria-00567390/)
- Krivulin, N. _Algebraic Solution of Tropical Polynomial Optimization Problems_. MDPI 2021. [https://www.mdpi.com/2227-7390/9/19/2472](https://www.mdpi.com/2227-7390/9/19/2472)

### §12.5 Idempotent analysis
- Litvinov, G. L., Maslov, V. P. _Idempotent Functional Analysis: An Algebraic Approach_. Math. Notes 2001. [https://link.springer.com/article/10.1023/A:1010266012029](https://link.springer.com/article/10.1023/A:1010266012029)
- Litvinov, G. L., Maslov, V. P. _Idempotency: The correspondence principle_. (Proceedings volume.)
- Litvinov, G. L. _Maslov dequantization, idempotent and tropical mathematics: A brief introduction_. J. Math. Sciences 2007. [https://link.springer.com/article/10.1007/s10958-007-0450-5](https://link.springer.com/article/10.1007/s10958-007-0450-5)
- Baccelli, F., Cohen, G., Olsder, G. J., Quadrat, J.-P. _Synchronization and Linearity: An Algebra for Discrete Event Systems_. Wiley 1992.
- _Idempotent analysis_ (Encyclopedia of Mathematics). [https://encyclopediaofmath.org/wiki/Idempotent_analysis](https://encyclopediaofmath.org/wiki/Idempotent_analysis)
- Fujii, S. _Enriched Categories and Tropical Mathematics_. arXiv:1909.07620. [https://ar5iv.labs.arxiv.org/html/1909.07620](https://ar5iv.labs.arxiv.org/html/1909.07620)

### §12.6 Abstract interpretation and cost
- Cousot, P., Cousot, R. _Abstract interpretation: a unified lattice model_. POPL 1977.
- Cousot, P. _Abstract Interpretation Frameworks_. [https://faculty.sist.shanghaitech.edu.cn/faculty/songfu/cav/AIF.pdf](https://faculty.sist.shanghaitech.edu.cn/faculty/songfu/cav/AIF.pdf)
- Navas, J., Mera, E., López-García, P., Hermenegildo, M. _Injecting Abstract Interpretations into Linear Cost Models_. arXiv:1006.5098. [https://arxiv.org/abs/1006.5098](https://arxiv.org/abs/1006.5098)
- _Cost-Based Semantics for Querying Inconsistent Weighted Knowledge Bases_. arXiv:2407.20754. [https://arxiv.org/abs/2407.20754](https://arxiv.org/abs/2407.20754)
- Gavazzo, F. _Quantitative Behavioural Reasoning for Higher-order Effectful Programs: Applicative Distances_. [https://inria.hal.science/hal-01926069](https://inria.hal.science/hal-01926069)

### §12.7 Operational / algorithmic
- Wilopo, et al. _Modified Kleene Star Algorithm Using Max-Plus Algebra_. MDPI Computation 2023. [https://www.mdpi.com/2079-3197/11/1/11](https://www.mdpi.com/2079-3197/11/1/11)
- Backhouse, R., Carré, B. _Regular algebra applied to path-finding problems_. 1975.
- Gondran, M., Minoux, M. _Graphs, Dioids and Semirings_. Springer 2008.
- _Kleene star_ (Wikipedia). [https://en.wikipedia.org/wiki/Kleene_star](https://en.wikipedia.org/wiki/Kleene_star)
- NICTA. _Dijkstra, Floyd and Warshall Meet Kleene_. [https://trustworthy.systems/publications/nicta_full_text/5506.pdf](https://trustworthy.systems/publications/nicta_full_text/5506.pdf)
- _Min-plus matrix multiplication_ (Wikipedia). [https://en.wikipedia.org/wiki/Min-plus_matrix_multiplication](https://en.wikipedia.org/wiki/Min-plus_matrix_multiplication)

### §12.8 Applied (networks, bisimulations)
- _Bisimulations for weighted networks with weights in a quantale_. Filomat 2023. [https://www.pmf.ni.ac.rs/filomat-content/2023/37-11/37-11-1-18444.pdf](https://www.pmf.ni.ac.rs/filomat-content/2023/37-11/37-11-1-18444.pdf)
- Höhle, U. _The weak subobject classifier axiom and modules in Sup_. Cahiers TGDC 2025. [https://cahierstgdc.com/wp-content/uploads/2025/01/Ulrich_HOHLE-_-LXVI-1.pdf](https://cahierstgdc.com/wp-content/uploads/2025/01/Ulrich_HOHLE-_-LXVI-1.pdf)
- Niefield, S. B. _Cahiers de Topologie et Géométrie Différentielle Catégoriques_ 1996. [https://www.numdam.org/item/CTGDC_1996__37_2_163_0.pdf](https://www.numdam.org/item/CTGDC_1996__37_2_163_0.pdf)
- _Dualizing sup-preserving endomaps of a complete lattice_. arXiv:2101.10493. [https://arxiv.org/abs/2101.10493](https://arxiv.org/abs/2101.10493)

### §12.9 Prologos-internal cross-references
- [`docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`](./2026-03-28_MODULE_THEORY_LATTICES.md)
- [`docs/tracking/2026-04-02_SRE_TRACK2H_DESIGN.md`](../tracking/2026-04-02_SRE_TRACK2H_DESIGN.md)
- [`docs/tracking/principles/DESIGN_PRINCIPLES.org`](../tracking/principles/DESIGN_PRINCIPLES.org) § Hyperlattice Conjecture
- [`docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`](./2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md)
- [`docs/research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md`](./2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md)
- [`qauntale_outputs/quantales-problog-semirings-brief.md`](../../qauntale_outputs/quantales-problog-semirings-brief.md) (sibling research strand)

---

## Document status

**Stage 1 research artifact** — background for PPN 4C Phase 9 audit + design. To be supplemented by Phase 9 audit document (Stage 2) and Phase 9 design document (Stage 3); tropical-fuel-specific design section lives in Phase 9 Design.

This document is a living reference; cross-references from Phase 9 audit/design back here carry the full literature citation. New findings during implementation that refine the theoretical framing should be added here as supplementary sections rather than scattered across phase documents.

**Next steps**: Phase 9 audit (`docs/tracking/2026-04-21_PPN_4C_PHASE_9_AUDIT.md`) opens with this research as foundational input.
