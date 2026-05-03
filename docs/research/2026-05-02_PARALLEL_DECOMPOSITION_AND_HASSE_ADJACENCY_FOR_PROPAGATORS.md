# Parallel Decomposition and Hasse Adjacency on Propagator Networks: A Foundational Synthesis

**Date**: 2026-05-02
**Stage**: 0/1 (deep research synthesis — vocabulary, theory grounding, novelty staking; no design commitments)
**Series**: [PTF (Propagator Theory Foundations)](../tracking/2026-03-28_PTF_MASTER.md)
**Companion notes** (deep surveys, integrated by reference):
- [Parallel Algorithms Survey](2026-05-02_PARALLEL_ALGORITHMS_SURVEY.md) — BSP/PRAM/NC, hypercube, prefix-scan, communication-avoiding, MPC, lower bounds, cellular automata, dataflow networks (782 lines)
- [Lattice Canonical Forms Survey](2026-05-02_LATTICE_CANONICAL_FORMS_SURVEY.md) — Whitman, Reading-Speyer-Thomas, Birkhoff, Stone/Priestley/Esakia dualities, Krull-Schmidt, varieties, modular, continuous, convex geometries, Hasse graph properties (697 lines)
- [Architecture Novelty Survey](2026-05-02_ARCHITECTURE_NOVELTY_SURVEY.md) — propagator lineage, CALM, GoI, interaction nets, e-graphs, Datalog, categorical parallelism, Hasse-adjacency precedents (Garg LLP), self-hosting comparisons (582 lines)

**Sister notes** (lateral context):
- [Lattice Variety and Canonical Form for SRE](2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md) (element-level theory; FL_V(X))
- [Lattice Hierarchy and Distributivity for Propagators](2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md) (per-variety operational catalog)
- [Module Theory on Lattices](2026-03-28_MODULE_THEORY_LATTICES.md) (module-theoretic backbone)
- [Hypercube BSP-LE Design Addendum](2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) (the design consumer)

**Operational supplement**: [S-Lens Reference](2026-05-02_S_LENS_REFERENCE.md) — distillation for active design-review use.

---

## 0. Why this note exists

Two threads in our existing work converge on a gap.

**Thread A — Hyperlattice Conjecture, asserted but ungraded.** [`structural-thinking.md`](../../.claude/rules/structural-thinking.md) §1 states: *"the Hasse diagram of the lattice IS the optimal parallel decomposition of that computation."* Today the evidence rests on **one** worked example — the ATMS worldview space being Q_n with the hypercube as its Hasse diagram, exploited in [`HYPERCUBE_BSP_LE_DESIGN_ADDENDUM`](2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md). Boolean is the *easy* case: the Hasse diagram of B_n IS the n-cube as a graph, and hypercube algorithms (Akl 1989; Leighton 1991) are the canonical parallel-computing toolkit for that topology. The conjecture asserts something across **all** varieties.

**Thread B — Two-mind-space tension, named but not formalized.** *"Information flow on a network is a different design mind-space than algorithmic thinking; and so our adoption of this research helps frame how we structure our network."* (Project conversation, 2026-05-02.) The framing distinguishes:

- **Algorithmic-thinking mind-space**: parallel-algorithm theory — BSP supersteps, hypercube communication, prefix-scan trees, butterflies, work-depth complexity bounds.
- **Information-flow mind-space**: propagator-network architecture — cells, monotone merges, Hasse-driven dataflow, fixpoint quiescence.

These mind-spaces are not in opposition. They are in **correspondence** — and the Hyperlattice Conjecture asserts that correspondence is structural: the algorithmic optimum and the network's Hasse adjacency are two views of the same object.

This note frames a foundational synthesis that addresses both threads:

1. **Survey the algorithmic-theory mind-space** — what parallel-algorithm theory says per lattice variety.
2. **Survey the lattice-theory mind-space** — what canonical-form and decomposition theorems say per variety.
3. **Integrate the four S-Lens lenses** — element / variety / module / adjacency — as a unified framework.
4. **Grade the Hyperlattice Conjecture by variety** — what's per-variety-precedented (graded form), what's the universal extension (apparent novelty).
5. **Stake novelty** — what we inherit, what we extend, what's apparent novelty worth external verification.

The note is Stage 0/1 — vocabulary, theory grounding, system survey, gap identification, and an implementation-note shape recommendation. It does NOT propose a design. A Stage 3 design track would follow if pursued; that decision is downstream.

The companion deep surveys (Parallel Algorithms, Lattice Canonical Forms, Architecture Novelty) are the substrate. This note is the synthesis layer that lifts them onto Prologos's specific architectural claims.

---

## 1. The two-mind-space framing

Before the technical content: the framing distinction itself, made precise.

### 1.1 Algorithmic-thinking mind-space

When we think about parallel computation algorithmically, we ask:

- Which model? (PRAM, BSP, MPC, LogP, async)
- What's the depth? (work-depth analysis; Brent's theorem T_p ≤ T_1/p + T_∞)
- What's the communication topology? (hypercube, butterfly, mesh, fat-tree)
- What's the synchronization cost? (BSP barrier latency L; the g/L parameters of Valiant's BSP cost formula T = w + h·g + ℓ)
- What's the lower bound? (Ω(log n) for any associative reduction; communication complexity bounds; P-completeness)

These are questions about **how to execute** a parallel computation efficiently. The answers come from algorithm design — Akl 1989, Leighton 1991, Bertsekas-Tsitsiklis 1989, Blelloch 1990, Demmel et al., Karloff-Suri-Vassilvitskii 2010. See [`PARALLEL_ALGORITHMS_SURVEY.md`](2026-05-02_PARALLEL_ALGORITHMS_SURVEY.md) for depth.

### 1.2 Information-flow mind-space

When we think about computation as information flow on a propagator network, we ask:

- Which lattice does this cell live in?
- What's the merge function (the join)?
- What propagators read this cell and write where?
- What's the Hasse adjacency between cell values? (Element-to-element refinement structure.)
- When does the network quiesce? (Fixpoint.)

These are questions about **what the structure is**. The answers come from order theory + lattice theory — Tarski 1955, Birkhoff 1933, Whitman 1941, Freese-Ježek-Nation 1995, Reading-Speyer-Thomas 2019. See [`LATTICE_CANONICAL_FORMS_SURVEY.md`](2026-05-02_LATTICE_CANONICAL_FORMS_SURVEY.md) for depth.

### 1.3 The correspondence claim

The Hyperlattice Conjecture asserts that these two mind-spaces stand in correspondence at the Hasse-adjacency level:

> **For each lattice variety V, an algorithmic optimum exists, and the network's Hasse adjacency IS that optimum's structural realization.**

This is structurally analogous to other duality claims in the literature:

- **Kowalski (1979) "Algorithm = Logic + Control"**: an algorithm decomposes into a logical specification (what) and a control strategy (how). Closest published analog to our framing, but says different specific things — Kowalski separates *logic* from *control*; we couple *algorithmic-optimum* with *information-flow-structure*.
- **Stone duality** (1936): Boolean algebras ↔ Stone spaces — algebra-side and topology-side as two views of one object.
- **Birkhoff representation** (1933): finite distributive lattices ↔ posets of join-irreducibles — algebra and combinatorics as two views.
- **Curry-Howard correspondence**: types ↔ propositions, programs ↔ proofs — two mind-spaces in correspondence.

The closest precedent for the *specific* algorithmic ↔ information-flow framing is **none directly** ([`ARCHITECTURE_NOVELTY_SURVEY.md`](2026-05-02_ARCHITECTURE_NOVELTY_SURVEY.md) §9 found no clear precedent across multiple search variants). The framing appears to be Prologos-specific. Tagged APPARENT NOVELTY for external verification.

### 1.4 Why the distinction matters operationally

The two mind-spaces differ in what they help us *decide*:

- **Algorithmic mind-space helps decide structure**: when designing a new propagator pattern, we ask "what algorithmic optimum applies here?" and the answer (hypercube all-reduce, butterfly prefix-scan, Birkhoff order-ideal traversal, …) tells us which Hasse-adjacency structure to install on the network.
- **Information-flow mind-space helps decide invariants**: when reviewing a propagator design, we ask "is this monotone? Does the merge respect the lattice axioms? Are bridges Galois connections?" and the answers determine correctness, CALM-safety, and composability.

Both are necessary. Neither is sufficient alone.

This note makes the correspondence explicit so designs can move fluently between the two mind-spaces — choosing the algorithmic optimum *because* it's the network's Hasse adjacency, and choosing the network's Hasse adjacency *because* it realizes the algorithmic optimum.

---

## 2. Parallel-algorithm theory: the algorithmic side

This section integrates [`PARALLEL_ALGORITHMS_SURVEY.md`](2026-05-02_PARALLEL_ALGORITHMS_SURVEY.md) at synthesis level. For depth on each topic, see the survey.

### 2.1 Computational models

Three load-bearing models, in increasing operational concreteness:

**PRAM** (Fortune-Wyllie 1978). A shared-memory abstraction with p processors and synchronous timesteps. CRCW (concurrent-write), CREW (exclusive-write), EREW (exclusive-everything) variants. **Brent's theorem** (1974): on p processors, runtime T_p ≤ T_1/p + T_∞ where T_1 is total work and T_∞ is the longest dependency chain (depth). The depth bound is what couples PRAM to lattice theory — *the longest chain in the Hasse diagram of the work IS the depth bound*.

**BSP** (Valiant 1990 "A Bridging Model for Parallel Computation"). Supersteps separated by global barriers; cost T = w + h·g + ℓ where w is local computation, h is communication volume, g is the per-message gap, ℓ is the synchronization latency. BSP's barrier semantics is exactly the propagator network's quiescence-then-next-stratum pattern (per [`stratification.md`](../../.claude/rules/stratification.md)).

**MPC / MapReduce** (Karloff-Suri-Vassilvitskii 2010). Sublinear-memory machines with round complexity; the 1-vs-2-cycles conjecture establishes Ω(log n) round lower bounds for sublinear-memory MPC on natural problems. The round complexity in MPC is structurally the same as BSP superstep count.

### 2.2 Complexity classes and bounds

**NC** (Nick's Class). NC^i: problems decidable in O(log^i n) parallel time with polynomial work. Lattice operations live in low NC for simple varieties (Boolean: NC^1 for AND-OR circuits) and may not have known NC algorithms for harder ones.

**P-completeness** as the no-parallel-speedup boundary. Some lattice operations (e.g., generic CFG parsing) are P-complete, suggesting they may not parallelize beyond polynomial work — relevant when assessing which propagator computations have parallel speedup vs being inherently sequential.

**Information-theoretic lower bound**: any associative reduction on n elements requires Ω(log n) depth. This bound *appears as the depth of the longest Hasse chain* across many varieties — a hint that the lower bound is structural, not just informational.

**Communication lower bounds**. Ballard-Demmel-Holtz-Schwartz: Ω(F/√M) for matrix multiplication; communication-avoiding algorithms (2.5D) hit this bound. Modern parallel performance is **communication-bound, not computation-bound** — relevant for propagator networks where every cell write is communication.

### 2.3 The hypercube as recurring topology

Hypercube algorithms appear across the parallel-computing literature as *the* canonical optimal-communication topology (Akl 1989; Leighton 1991; Bertsekas-Tsitsiklis 1989):

- **All-reduce in log_2 T rounds** — pairwise communication along hypercube dimensions
- **Broadcast / reduce in log_2 T rounds** — recursive halving / doubling along dimensions
- **Prefix-scan on hypercube** — Blelloch's up-sweep / down-sweep maps to hypercube butterfly
- **Subcube partitioning** — recursive division for divide-and-conquer parallelism

The Boolean lattice B_n's Hasse diagram **IS** the n-dimensional hypercube graph. This isomorphism is textbook ([`LATTICE_CANONICAL_FORMS_SURVEY.md`](2026-05-02_LATTICE_CANONICAL_FORMS_SURVEY.md) §10 catalogs Hasse graph properties per variety; the Boolean ↔ hypercube identity is established).

For Boolean lattices, the Hyperlattice Conjecture's claim is therefore textbook-confirmable: the Hasse diagram is the hypercube, and the hypercube IS the optimal parallel decomposition for any Boolean-lattice computation. This is the load-bearing **graded precedent** for the conjecture in its Boolean instance.

### 2.4 Parallel prefix-scan and the butterfly network

**Blelloch 1990** "Vector Models for Data-Parallel Computing": work-efficient parallel prefix-scan in O(log n) depth via up-sweep + down-sweep on a balanced binary tree, equivalent to butterfly network at the topology level. The butterfly network is **embeddable in the hypercube** with optimal dilation.

For Prologos: broadcast propagators (per [`HYPERCUBE_BSP_LE_DESIGN_ADDENDUM`](2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) and [`PROPAGATOR_TAXONOMY`](2026-03-28_PROPAGATOR_TAXONOMY.md)) are the parallel-prefix-scan pattern made network-native. The 75.6× speedup at N=100 (BSP-LE Track 2 measurement) is the empirical confirmation that this pattern is the right algorithmic anchor — broadcast propagator IS Blelloch prefix-scan IS butterfly IS embedded hypercube.

### 2.5 Dataflow networks and monotone-fixpoint computation

**Kahn 1974** "The Semantics of a Simple Language for Parallel Programming". Kahn process networks (KPNs) are stream-processing networks where each process computes a monotone continuous function on its input streams. The Kahn Principle: KPN behavior is the **least fixpoint of a monotone continuous function** on the product domain of streams. This is *the* mathematical antecedent of propagator networks at the semantic level.

The crucial result: KPN computation is **deterministic regardless of scheduling order** — Kahn proved this from monotonicity + continuity alone. This is the same observation as **CALM** (Hellerstein 2010): monotone computation is coordination-free.

The connection: propagator networks are KPNs with cells-as-channels and merge-as-monotone-aggregation. Everything KPN says about scheduling indeterminism applies to us. Everything CALM says about distribution applies to us. The Hasse adjacency adds the **shape** dimension that neither KPN nor CALM addresses — *which schedule is optimal*, not just *that schedules converge to the same answer*.

### 2.6 Cellular automata as parallel computation

von Neumann 1948; Wolfram. CAs are parallel computations where local rules update each cell based on its neighborhood. Wolfram's Class IV CAs (Rule 110 — Cook 2004 proved Turing-complete) demonstrate that simple local rules suffice for universal computation.

The relevance: propagator networks are CA-shaped at the substrate level (local rules, parallel firing). The Hasse adjacency is what distinguishes propagator networks from generic CAs — propagator networks have *typed lattice structure* on cell values, whereas CAs have only finite-state alphabets.

### 2.7 Synthesis themes from algorithmic side

[`PARALLEL_ALGORITHMS_SURVEY.md`](2026-05-02_PARALLEL_ALGORITHMS_SURVEY.md) §11 identifies eight overarching themes; the load-bearing ones for our framing:

1. **log_2 N as universal depth bound** — hypercube algorithms, prefix-scan, NC reductions all hit log_2 N depth. The Hasse-diagram-height connection is structural: the depth bound IS the longest chain.
2. **Three universal lattice-theoretic hammers** — Kleene fixpoint, Knaster-Tarski fixpoint, Scott continuity. All three apply to propagator networks; CALM is essentially Knaster-Tarski for distributed monotone systems.
3. **Hypercube as recurring topology** — appears in BSP, prefix-scan, all-reduce, butterfly, embedded everywhere. The Boolean variety's privileged operational status.
4. **Communication dominates cost** — modern parallelism is bandwidth-bound. Propagator networks must minimize cell writes per superstep.
5. **Monotone-fixpoint = parallel determinism** — Kahn's principle + CALM = scheduling indeterminism doesn't affect correctness for monotone computations.
6. **Universality from simple local rules** — Wolfram, Lafont, Sussman-Radul. Local-rule + global-fixpoint computation is universal.

---

## 3. Lattice canonical-form theory: the information-flow side

This section integrates [`LATTICE_CANONICAL_FORMS_SURVEY.md`](2026-05-02_LATTICE_CANONICAL_FORMS_SURVEY.md) at synthesis level. For depth on each topic, see the survey.

### 3.1 The variety hierarchy

Lattices form a hierarchy by which equations they satisfy:

```
Free lattice (FL)
    ⊃ SD (semidistributive) — quasi-variety, not equational
        ⊃ Modular
            ⊃ Distributive
                ⊃ Heyting (distributive + relative pseudo-complement)
                    ⊃ Boolean (Heyting + complement)
```

Plus orthogonal enrichments: **Quantale** (multiplicative structure), **Residuated** (left/right adjoints), **Algebraic / Continuous** (Scott domain theory).

Each step adds axioms. More axioms = more algorithms (canonical form, decision procedures cheaper) but fewer lattices (fewer models satisfy more equations). The **trade-off is operational**: aiming for the most-constrained variety that genuinely models your domain unlocks the maximum algorithmic toolkit.

### 3.2 Canonical form per variety

**Free lattice FL(X)** — Whitman 1941 + Freese-Nation 1995. Theorem 1.17: every element has a unique-up-to-commutativity minimal-rank term representative. Theorem 1.18: 4-condition characterization. Theorem 1.21: free lattices are semidistributive. Algorithmic capstone Ch XI: Whitman with selective memoization runs in O(can(s) + can(t)) on canonical input.

**Finite SD lattices** — Reading-Speyer-Thomas 2019 "The fundamental theorem of finite semidistributive lattices" (arXiv:1907.08050). Constructive canonical form for all finite SD lattices, generalizing Freese-Nation to the SD case via labeling. Connection to convex geometries (Adaricheva-Gorbunov-Tumanov 2003).

**Distributive lattices** — Birkhoff 1933. Every finite distributive lattice ≅ lattice of order-ideals of its poset of join-irreducibles. **Algorithmically**: DNF/CNF as canonical form. **Structurally**: distributive lattices are essentially set lattices via Birkhoff representation.

**Boolean lattices** — Stone 1936. Boolean algebras ↔ Stone spaces (totally disconnected compact Hausdorff). Algorithmically: bitmask representation, O(1) operations for n ≤ 64.

**Modular lattices** — Dedekind 1900 (free modular lattice on 3 generators is finite, on 4 is infinite); Freese 1980. Canonical-form algorithms more complex than distributive case.

### 3.3 Decomposition theorems

**Krull-Schmidt for lattices** (Calugareanu Ch06; Schmidt-Schweigert "Universal Algebra"). Direct-sum decomposition uniqueness: every lattice with chain conditions has a unique decomposition into indecomposable direct factors (up to permutation and isomorphism). The **Goldie dimension** is the parallelism budget — the number of independent direct summands sets the parallelism upper bound for cell-component decomposition.

**Module-theoretic Krull-Schmidt** ([`MODULE_THEORY_LATTICES`](2026-03-28_MODULE_THEORY_LATTICES.md)) lifts this from lattices to Q-modules: cells as Q-modules admit direct-sum decomposition; the decomposition is unique; independent components can be computed in parallel.

**Birkhoff variety theorem** (Birkhoff 1935 HSP). Varieties = equational classes; the lattice of lattice-varieties is itself a lattice. **Relatively free lattices FL_V(X)** per variety V are the right algebra for elements of a domain that commits to V's equations.

### 3.4 Hasse diagram graph-theoretic properties

Per [`LATTICE_CANONICAL_FORMS_SURVEY.md`](2026-05-02_LATTICE_CANONICAL_FORMS_SURVEY.md) §10:

- **Width** (Dilworth's theorem 1950) — max antichain size = min chain decomposition. Sets the parallelism budget at any Hasse level.
- **Diameter** — longest chain. Bounds the depth of fixpoint convergence.
- **Treewidth** — bounded for many varieties; via Courcelle's theorem, MSO-decidable properties of bounded-treewidth Hasse diagrams are linear-time decidable.
- **Planarity** — Platt 1976 characterization. Implications for visualization + scheduling.
- **Expander properties** — the Boolean lattice's Hasse (= hypercube) is a well-known expander; expansion properties directly bound communication-efficient parallel algorithms.
- **Per-variety profiles** — different varieties have different Hasse graph profiles, which translate to different parallel-algorithm profiles.

### 3.5 Synthesis: variety determines algorithmic profile

The load-bearing observation from the lattice side: **each variety has its own canonical-form algorithm with its own complexity, AND its own Hasse-graph profile with its own parallel-algorithm match.**

| Variety | Canonical form | Hasse profile | Parallel-algorithm anchor |
|---|---|---|---|
| Boolean | Bitmask | Hypercube graph (Hasse = Q_n) | Hypercube algorithms (Akl, Leighton); butterfly; all-reduce in log_2 T rounds |
| Distributive | DNF/CNF via Birkhoff | Order-ideal poset of join-irreducibles | Garg LLP (lattice-linear predicates); Birkhoff-poset parallel traversal |
| Heyting | Distributive + pseudo-complement | Distributive Hasse + intuitionistic structure | Distributive parallelism + pseudo-complement-driven backward propagation |
| Modular | Dedekind / Freese | Modular geometry (subgroup lattices, projective geometry) | Modular-decomposition algorithms; less developed parallel toolkit |
| Semidistributive (finite) | Reading-Speyer-Thomas labeling | Convex-geometry-shaped | RST canonical form; convex-geometry parallel algorithms |
| Free | Whitman recursion (FJN Ch XI: O(can(s) + can(t))) | Breadth-4 bounded antichain width | Whitman recursive parallelism; bounded-width fan-out |
| Continuous / Algebraic | Compact-element generation; way-below | Scott domain | Domain-theoretic parallelism; lazy evaluation |

This table is the **per-variety algorithmic-anchor table** — the load-bearing artifact for the operational supplement. It's how a designer chooses the right algorithm for a given lattice in our network.

---

## 4. The Hyperlattice Conjecture, graded by variety

We now state the conjecture precisely and assess its status per variety.

### 4.1 The unified statement

> **Hyperlattice Conjecture (universal form)**: every computable function is a fixpoint on lattices, and the Hasse diagram of the lattice IS the optimal parallel decomposition of that computation.

Two claims:

1. **Universality**: every computation = fixpoint on a lattice. (Tarski 1955; abstract interpretation tradition.)
2. **Optimality**: the Hasse diagram parametrizes the optimal parallel decomposition. (The novel claim.)

The universality claim is well-established in the abstract-interpretation and domain-theory traditions. The optimality claim is what we stake.

### 4.2 Per-variety grading

Per [`ARCHITECTURE_NOVELTY_SURVEY.md`](2026-05-02_ARCHITECTURE_NOVELTY_SURVEY.md) §8.2 + the table in §3.5 above:

| Variety | Optimality status | Strongest precedent |
|---|---|---|
| **Boolean** | **CONFIRMED (textbook)** | Hasse(B_n) = hypercube graph; hypercube algorithms ARE the optimal parallel patterns for this topology. Stout 1980s, Wagar, MIT 6.895 lecture notes. |
| **Distributive** | **STRONG GRADED PRECEDENT** | Garg's Lattice-Linear Predicate (LLP) framework (SPAA 2020 + sequence). For finite distributive lattices with lattice-linear predicates, parallel detection advances along chains of the poset. Yields parallel Gale-Shapley, Dijkstra, MST, knapsack. The Hasse poset IS the parallel decomposition for this graded case. |
| **Series-parallel posets** | **CONFIRMED (classical scheduling)** | "Series-parallel graphs describe dependencies between tasks in a parallel computation... visualizing the amount of parallelism" (classical, Möhring et al.). |
| **General poset** | **PARTIAL (Dilworth)** | Dilworth's theorem gives width = minimum processors needed; not a full Hasse-as-decomposition claim, but a width-as-budget claim. |
| **Semidistributive (finite)** | **NO PUBLISHED PARALLEL CLAIM** | RST 2019 gives canonical form; no parallel-algorithm claim landed in the literature search. |
| **Modular** | **NO PUBLISHED PARALLEL CLAIM** | Decomposition theory exists (Dedekind, Freese); parallel-algorithm anchor weaker. |
| **Free** | **NO PUBLISHED PARALLEL CLAIM** | Whitman's algorithm has known complexity; parallel version not in our literature search. Breadth-4 bound suggests fan-out is bounded. |

### 4.3 What's apparent novelty

The **universal-across-varieties** statement of the conjecture is APPARENT NOVELTY (per [`ARCHITECTURE_NOVELTY_SURVEY.md`](2026-05-02_ARCHITECTURE_NOVELTY_SURVEY.md) §8.5). Per-variety precedents are graded; the unified universal claim is not literature-attested in our search.

Specifically novel:

1. The claim that the parallel decomposition is **uniquely determined by the lattice variety** (a structural property, not a design choice).
2. The claim that this holds for **every** lattice variety, not just the well-studied ones (Boolean, distributive).
3. The substrate-level realization: a **propagator network** where every cell's lattice variety drives its parallel-algorithm anchor automatically.
4. **Self-hosting closure**: the compiler that compiles Hasse-driven programs is itself a Hasse-driven propagator network. Garg has no analog of this.

### 4.4 Falsifiability questions

Per Agent 3's recommendation, the conjecture's status moves from "apparent novelty" to "novel theorem" or "false conjecture" only by external review. Two falsifiability questions worth asking external reviewers:

1. **Has anyone in the literature claimed the Hasse diagram of an arbitrary lattice IS the optimal parallel decomposition of the corresponding fixpoint computation, in a universal form not restricted to a specific variety?** (Search: lattice-theory parallel-computing distributed-systems compiler-theory domain-theory.)

2. **Is there a known counterexample — a fixpoint computation on a lattice where the optimal parallel decomposition demonstrably is NOT the Hasse adjacency structure?** (E.g., a lattice where the optimal parallel algorithm uses a different graph structure than the Hasse diagram.)

If (1) returns nothing, the universal claim is novel. If (2) returns a counterexample, the conjecture is false in its universal form (and we retreat to a graded form). Both questions are concrete and externally tractable.

### 4.5 Graded form as fallback

If the universal claim falls, the **graded form** survives:

> **Graded Hyperlattice Conjecture**: for each lattice variety V where canonical form is computable, the Hasse diagram of FL_V(X) parametrizes the optimal parallel decomposition for V-lattice fixpoint computations.

The graded form is **strongly precedented** (Boolean ↔ hypercube; distributive ↔ Garg LLP; series-parallel ↔ classical scheduling). It is the conjecture's robust core. The universal extension is the bet.

This is the same posture we take on other architectural claims: the strong form is what we shoot for; the graded form is what we definitely have.

---

## 5. Four-lens integration

The S-Lens of lattice design integrates four lenses on a propagator network. Each was previously articulated separately; this section unifies them.

### 5.1 The four lenses

| Lens | Question | Reference |
|---|---|---|
| **Element lens** | What is a cell value? What is its canonical form? When are two values equal? | [`LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE`](2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md); Whitman; Reading-Speyer-Thomas; Birkhoff |
| **Variety lens** | What algebraic identities hold? What variety does this lattice live in? What does that unlock? | [`LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS`](2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md); Birkhoff 1935 HSP |
| **Module lens** | How does this cell interact with others? What's the action of propagators on cells? When does Krull-Schmidt apply? | [`MODULE_THEORY_LATTICES`](2026-03-28_MODULE_THEORY_LATTICES.md); Calugareanu |
| **Adjacency lens** | What's the Hasse diagram? What's its graph structure? What parallel algorithm does it parametrize? | This note + [`HYPERCUBE_BSP_LE_DESIGN_ADDENDUM`](2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md); Akl, Leighton, Garg |

### 5.2 How the lenses compose

The four lenses are not independent — they nest:

```
                    Adjacency lens
                    (parallel decomp)
                          │
                          │ parametrized by
                          ▼
                    Variety lens
                    (algebraic identities)
                          │
                          │ governs
                          ▼
                    Element lens
                    (canonical form)
                          │
                          │ generates
                          ▼
                    Module lens
                    (Q-module, propagator action)
```

- **Variety determines element-lens**: which canonical-form algorithm applies (Whitman / RST / Birkhoff / bitmask).
- **Variety determines adjacency-lens**: which parallel-algorithm anchor applies (hypercube / Birkhoff-poset / RST-traversal / etc.).
- **Element-lens determines module-lens**: cells' canonical forms determine the structure on which propagators act as Q-module morphisms.
- **Module-lens enables adjacency-lens at substrate level**: cell-component decomposition (Krull-Schmidt-style) is the on-network realization of Hasse parallelism.

### 5.3 The S-Lens applied — design questions

When designing a new propagator-network domain or pattern, the S-Lens asks (in order):

1. **Element**: What canonical form does this domain admit? (Determines equality / hashcons / structure-sharing scope.)
2. **Variety**: What variety does this domain live in? (Determines which algebraic identities hold, which canonical-form algorithm to use.)
3. **Module**: What's the Q-module structure? Are propagators Q-module morphisms? Does Krull-Schmidt apply for parallel cell-component decomposition?
4. **Adjacency**: What's the Hasse diagram of this lattice? What parallel-algorithm anchor does it select? Is the propagator dispatch consistent with that algorithmic optimum?

These are extensions of the existing six-question SRE lattice lens (per [`structural-thinking.md`](../../.claude/rules/structural-thinking.md) + [`CRITIQUE_METHODOLOGY.org`](../tracking/principles/CRITIQUE_METHODOLOGY.org)). The current six questions correspond mostly to lens 2 (variety, algebraic properties) and lens 3 (module, bridges, primary-vs-derived). This note's contribution is making **lens 1 (element)** and **lens 4 (adjacency)** explicit, and showing how all four nest.

### 5.4 Connection to existing project rules

The proposed extensions to the SRE lattice lens (Q1-Q6 in [`structural-thinking.md`](../../.claude/rules/structural-thinking.md)):

- **Q1 (classification)**: VALUE / STRUCTURAL — unchanged.
- **Q2 (algebraic properties)**: refined — add explicit *variety identification*, not just property cluster.
- **Q3 (bridges)**: unchanged.
- **Q4 (composition)**: unchanged.
- **Q5 (primary/derived)**: unchanged.
- **Q6 (Hasse diagram)**: deepened — add *adjacency parametrizes parallel algorithm*; per-variety algorithmic anchor.
- **Q7 (NEW, candidate)**: *canonical form*. Which canonical-form algorithm applies? What's the equality decision procedure?

Q7 is a candidate addition. It's currently absorbed into Q1-Q6 informally (via property declarations like `commutative-join`, `idempotent-join` etc.), but making canonical form explicit gives designers a direct hook for the algorithmic-anchor table.

The operational supplement [`S_LENS_REFERENCE.md`](2026-05-02_S_LENS_REFERENCE.md) takes these candidate extensions to a polished design-review checklist.

---

## 6. Prologos-specific synthesis

Where do the four lenses + per-variety anchors land on Prologos's existing infrastructure?

### 6.1 Domain inventory by variety (per Track 2I sweep + this note)

From [`SRE_TRACK2I_SD_CHECKS_DESIGN`](../tracking/2026-04-30_SRE_TRACK2I_SD_CHECKS_DESIGN.md) Phase 3c + [`LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS`](2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md) §3:

| Domain (registration site) | Currently-declared variety | Algorithmic anchor (proposed) |
|---|---|---|
| ATMS worldview space (BSP-LE Track 2) | Boolean (Q_n) | Hypercube algorithms (Akl, Leighton); bitmask subcube pruning O(1); Gray code; all-reduce in log_2 T rounds — *already exploited per HYPERCUBE_BSP_LE_DESIGN_ADDENDUM* |
| Set cells (`infra-cell.rkt:46`, `merge-set-union`) | Boolean (powerset) | Hypercube algorithms; bitmask for n ≤ 64 |
| Form cells equality merge | Heyting (Track 2H, distributive + pseudo-complement) | Distributive parallelism (Birkhoff order-ideal traversal) + pseudo-complement-driven backward propagation |
| Form cells with no relation | Semilattice (no meet declared; SD-untestable) | Sequential pending meet declaration |
| Type lattice subtype merge | Heyting (Track 2H) | Distributive + Birkhoff + pseudo-complement |
| Type lattice equality merge | **Distributive (Phase 3c discovery)** | Distributive parallelism (Garg LLP candidate) |
| Session lattice equality | Bounded join-semilattice (no distributivity declared) | SD-candidate (sweep target) |
| Multiplicity cells (m0/m1/mw) | Small quantale (3 elements) | Bitmask / table-driven (small finite case) |
| Tropical fuel cell (PPN 4C Phase 1B) | Tropical quantale (Lawvere quantale on [0,∞]) | Tropical Kleene-star / shortest-path parallelism (Bellman-Ford / Floyd-Warshall structurally) |

This table is not exhaustive — full sweep gated on Track 2I Phase 3 closure. But it's the starting inventory.

### 6.2 Worked examples of the correspondence

**Example 1 — ATMS worldview space (already realized)**:

- Element lens: worldview = bitmask of believed assumptions; canonical form = bitmask itself (deduplicated by structural hash).
- Variety lens: Boolean lattice (powerset of assumptions).
- Module lens: cells = Q-modules over the Boolean quantale; propagators = monotone endomaps respecting the Boolean structure.
- Adjacency lens: Hasse(Q_n) = hypercube graph; algorithmic anchor = hypercube algorithms; Gray code traversal maximizes CHAMP reuse; bitmask subcube pruning for nogoods is O(1); hypercube all-reduce for BSP barrier.

This is the worked example that grounds the conjecture for the Boolean variety. It IS textbook lattice theory + textbook hypercube algorithms.

**Example 2 — Type lattice equality merge (Track 2I Phase 3c discovery)**:

- Element lens: type expressions; canonical form = ACI normalization (Track 2H `build-union-type` at unify.rkt:843); equality decidable via structural equality on canonical forms.
- Variety lens: distributive (Phase 3c flip from non-distributive — was Track 2G hidden by always-installed callback).
- Module lens: type cells as Q-modules over the type-lattice quantale (post-Track 2H Heyting redesign).
- Adjacency lens: distributive Hasse = lattice of order-ideals of join-irreducibles (Birkhoff representation); algorithmic anchor candidate = Garg LLP; per-variety canonical-form algorithm via Birkhoff — *not yet implemented; design opportunity*.

This is the example that surfaces the design opportunity. The algebraic-status flip changed which algorithmic anchor applies; the adjacency-lens analysis hadn't been done at registration time.

**Example 3 — Tropical fuel cell (PPN 4C Phase 1B, in flight)**:

- Element lens: cost values in [0, +∞]; canonical form = the value itself (totally ordered).
- Variety lens: tropical quantale (Lawvere quantale; min-plus algebra).
- Module lens: cells as T_min-modules; propagators as cost-incrementing morphisms; residuation gives backward error-explanation.
- Adjacency lens: Hasse(T_min) = totally ordered chain in [0, +∞]; algorithmic anchor = tropical Kleene-star (Bellman-Ford structurally for shortest-path; Floyd-Warshall for all-pairs); parallel via Litvinov-Maslov idempotent-analysis Perron-Frobenius eigenvalue analysis.

This is where the four lenses feed PReduce's cost-extraction substrate (per [`PREDUCE_MASTER`](../tracking/2026-05-02_PREDUCE_MASTER.md)).

### 6.3 Connection to PReduce series

PReduce's cost-guided extraction (Track 4) is structurally **Hasse-driven parallel decomposition on a quotient module**:

- E-class cells form the quotient module (Module Theory §6).
- Tropical-quantale cost annotation gives each e-class a position in the cost lattice.
- Extraction = find the minimum-cost representative = walk the Hasse adjacency of the cost lattice.
- The optimal extraction algorithm IS the Hasse-walk algorithm for the tropical lattice variety.

This connects the algorithmic-thinking ↔ information-flow duality directly to PReduce's algorithmic foundation.

### 6.4 Connection to SH series

SH's super-optimization claim (per [`SH_MASTER`](../tracking/2026-04-30_SH_MASTER.md) + [`PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER`](2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md)) rests on the parallel-decomposition optimality. If the Hyperlattice Conjecture holds (universal or strong-graded form), SH delivers a compiler whose architectural endpoint is **provably optimal at the substrate level** — not just empirically fast, but Hasse-decomposition-optimal.

This is the load-bearing connection that makes SH's "super-optimizing compiler" claim more than aspirational: it's grounded in the per-variety algorithmic-anchor table.

### 6.5 Design implications captured for SRE Master

The S-Lens reference (operational supplement) is the artifact that lands at the design-review surface. It contains:

1. The extended SRE lattice lens (six questions + Q7 canonical form).
2. Per-variety algorithmic-anchor lookup table (the §3.5 table promoted to operational form).
3. Design-review checklist additions (questions to ask of new propagator patterns).
4. Code-review sniff tests (red flags that suggest a variety mismatch or missing algorithmic anchor).

See [`S_LENS_REFERENCE.md`](2026-05-02_S_LENS_REFERENCE.md) for the polished form.

---

## 7. Novelty staking and external review

Per [`ARCHITECTURE_NOVELTY_SURVEY.md`](2026-05-02_ARCHITECTURE_NOVELTY_SURVEY.md). Reproduced here in summary; deep treatment in the survey.

### 7.1 Grounded prior art (we're inheriting)

- Propagator network model (Sussman-Radul 2009; Steele 1980).
- CALM theorem (Hellerstein 2010; BloomL Conway et al. 2012; LVars Kuper-Newton 2013).
- Lattice fixpoint as universal computation framework (Tarski 1955; Cousot-Cousot 1977).
- Dataflow lineage (Kahn 1974; Waltz 1972; Mackworth 1977; differential dataflow Murray-McSherry-Isaacs-Isard 2013).
- Boolean lattice ↔ hypercube identity (textbook).
- Strong-confluence parallelism (Lafont 1990; Lévy 1980; Asperti-Guerrini 1998; HVM2 2024).
- E-graph parallel saturation (egg Willsey 2021; egglog Zhang 2023; Cranelift ægraphs Fallin 2023+).
- Categorical decomposition via polynomial functors (Joyal; Gambino-Kock; Spivak-Niu 2024).
- Stratified Datalog for non-monotone work.
- Per-variety lattice canonicalization (Whitman 1941; RST 2019; Birkhoff 1933).

### 7.2 Partial precedents with novel framing

- **Garg's LLP framework** (SPAA 2020+) — graded distributive lattice version of C1; Prologos's universal extension is novel.
- **Polynomial-functor parallelism** (Spivak-Niu) — categorical operation; Prologos's broadcast-propagator-as-operationalized-polynomial-functor with measured A/B speedups makes the operational connection.
- **Egglog's lattice + e-graph unification** — closest precedent for substrate-level lattice + structural rewriting; framed as Datalog + e-graph, not as Hasse parallelism.
- **CALM extension** — CALM says *monotone ⇒ coordination-free*; Prologos C1 says *the variety determines the shape of the parallel decomposition*. CALM is silent on shape; we assert shape.
- **GoI's iteration theory** — fixpoint operators, traces; lives in operator-algebra space; lattice connection absent.

### 7.3 Apparent novelty (worth external verification)

1. **Hyperlattice Conjecture (universal form)**: per-variety precedents are graded; the unified universal claim is APPARENT NOVELTY.
2. **Algorithmic ↔ information-flow duality (specific framing)**: Kowalski's logic + control is closest analog; the specific correspondence claim is APPARENT NOVELTY.
3. **"Entire compiler IS a propagator network" at production-scale dependent types**: APPARENT NOVELTY. Lean 4 / Idris 2 / Coq / Rocq / Agda all have piecewise propagator-adjacent infrastructure; none claims propagator-network-uniform architecture.
4. **Variety-relative-free-lattice canonicalization at runtime**: cells as FL_V(X) elements with per-variety canonical-form algorithms IS lattice-theoretic synthesis; the *computational role* in a propagator-network compiler is Prologos-specific.

### 7.4 The strongest single precedent — Garg's LLP framework

**Garg's Lattice-Linear Predicate framework** (Vijay Garg, SPAA 2020 "Predicate Detection to Solve Combinatorial Optimization Problems"; ICDCN 2021; "Parallel Minimum Spanning Tree Algorithms via Lattice Linear Predicates"; Streit-Garg "Constrained Cuts, Flows, and Lattice-Linearity" arXiv:2512.18141).

Garg's claim, paraphrased: for finite distributive lattices with meet-closed (lattice-linear) predicates, the parallel detection algorithm advances simultaneously along any chain of the poset for which the current element is forbidden. Yields parallel Gale-Shapley, Dijkstra, MST, knapsack, longest subsequence — the **Hasse poset IS the parallel decomposition** for these problems.

What Prologos C1 adds beyond Garg:

1. **Universal scope**: Garg restricts to finite distributive lattices + lattice-linear predicates. Prologos asserts this for every computation expressible as lattice fixpoint.
2. **Variety-graded vs universal**: Garg has one tool (distributive lattice traversal); Prologos asserts a per-variety toolkit.
3. **Substrate vs algorithm**: Garg gives parallel algorithms for specific problems. Prologos asserts a runtime substrate where every computation is structurally Hasse-driven.
4. **Self-hosting closure**: Prologos closes the loop — the compiler that compiles Hasse-driven programs is itself Hasse-driven.

Garg's work is the most-load-bearing single citation for the conjecture's optimality direction. External review should specifically ask whether the universal extension of Garg's claim is published anywhere — that's the falsifiability test.

---

## 8. Open research questions

Beyond the falsifiability questions (§4.4), specific research directions that emerged from this synthesis:

### 8.1 Theory-side questions

1. **CALM and Hasse adjacency: same theorem?** Is "monotone ⇒ coordination-free" (CALM) the same theorem as "Hasse adjacency = optimal parallel decomposition" (HC) in different vocabularies? Or do they layer (CALM = correctness; HC = optimality)?

2. **Per-variety NC complexity**: for each variety V, what's the NC-class of canonical-form computation in FL_V(X)? Boolean is NC^1; distributive is in NC; SD complexity unknown to us; modular complexity heavy.

3. **Treewidth bounds per variety**: per [`LATTICE_CANONICAL_FORMS_SURVEY.md`](2026-05-02_LATTICE_CANONICAL_FORMS_SURVEY.md) §10, Hasse diagrams have variety-dependent treewidth profiles; via Courcelle's theorem, MSO-decidable properties on bounded-treewidth Hasse diagrams are linear-time decidable. Which propagator-relevant properties fall in MSO?

4. **Goldie dimension as operational parallelism budget**: Krull-Schmidt gives unique direct-sum decomposition; Goldie dimension is the count of indecomposable summands. For our cell-component decomposition (Realization B from `structural-thinking.md`), Goldie dimension IS the parallelism budget for that cell. Empirical question: do our actual cell-component decompositions saturate Goldie dimension, or fall short?

5. **Continuity / domain theory connection**: Scott's continuous lattices give a richer parallel-computation story (way-below relation; compact elements). Where does Scott domain theory plug into our framework?

### 8.2 Practical / architecture-side questions

6. **How does adjacency interact with categorical structure?** The Hasse adjacency of a Boolean lattice is the hypercube graph; for distributive lattices it's the Birkhoff order-ideal poset. What's it for Heyting? Quantale? Modular?

7. **Does the Hasse-as-parallel-decomposition claim hold for modular-but-not-distributive lattices?** Krull-Schmidt gives one form of decomposition; is there an algorithmic anchor analogous to hypercube algorithms for Boolean?

8. **Open-world lattices**: when the lattice grows during computation (new types registered, new constraints accumulated), how does the parallel-decomposition claim survive? Is there a Hasse-evolution discipline?

9. **Connection to e-graph extraction theory**: PReduce's cost-guided extraction is parallel decomposition on a quotient module. Same structure as Hasse parallelism on the cost lattice, or different?

10. **Hasse-adjacency as CHAMP structural sharing**: the addendum hints at this — Gray-code traversal maximizes CHAMP reuse because adjacent worldviews share cell state. Is there a general theorem of the form *Hasse-adjacent values share CHAMP structure*?

### 8.3 Frontier questions

11. **Self-hosting closure**: if our compiler IS a propagator network, and the network is parameterized by lattice variety, what variety is the compiler's metadata in? (Recursive metadata structure.)

12. **Compositional Hasse adjacency**: when two lattices L1, L2 are bridged via Galois connection, what's the Hasse structure of the composite? Does the parallel decomposition compose?

13. **Quantum analogs**: there's a tropical-quantum-mechanics correspondence (Maslov dequantization) — does the Hyperlattice Conjecture have a quantum analog with hypercube algorithms replaced by quantum circuits?

These are research directions, not commitments. They're listed for future work and for external collaborators to engage with.

---

## 9. Implementation note for SRE Master

This note's contribution to the SRE Master tracker:

- **The four-lens framework** (element/variety/module/adjacency) becomes the explicit architectural lens for SRE-domain registration. Not a Stage-3 design commitment, but a Stage-0/1 framework for design conversations.
- **The per-variety algorithmic-anchor table** (§3.5) is the lookup table for "which parallel algorithm matches this domain." Operational supplement [`S_LENS_REFERENCE.md`](2026-05-02_S_LENS_REFERENCE.md) houses the active form.
- **The candidate Q7 (canonical form) extension to the SRE lattice lens** is a future Stage-3 design item, gated on:
  1. Track 2I Phase 3 sweep closure (full domain inventory by variety).
  2. Empirical assessment of which canonical-form algorithms are practical at our scale.
  3. Decision on whether canonical form is per-domain user-declared or auto-derived from variety.
- **The Hyperlattice Conjecture grading** (§4.2 + §4.4) is now an explicit research artifact with two falsifiability questions for external review. SRE Master should reference this as the foundation for any future "we claim parallel-decomposition optimality" statements.
- **PReduce series consumes this** for cost-guided extraction (Track 4) — the four-lens framework directly applies to e-class cells.
- **SH series consumes this** for the super-optimization claim — without the parallel-decomposition optimality argument, "super-optimizing compiler" is empirical, not structural. With it, there's a path to provable optimality.
- **PTF series hosts this** — the synthesis is foundational lattice + algorithm theory; it doesn't fit cleanly in any application series; PTF is the right home.

---

## 10. References (synthesis-level)

For the deep reference lists per topic, see the three companion surveys.

### Foundational

- **Lattice theory**: Birkhoff (1933) "On the Combination of Subalgebras"; Birkhoff (1935) "On the Structure of Abstract Algebras"; Stone (1936); Whitman (1941); Dilworth (1950); Tarski (1955); Freese-Ježek-Nation (1995) "Free Lattices" (AMS Surveys 42); Reading-Speyer-Thomas (2019/2021) arXiv:1907.08050.
- **Parallel computing**: Brent (1974); Kahn (1974); Fortune-Wyllie (1978); Akl (1989); Bertsekas-Tsitsiklis (1989); Valiant (1990) BSP; Blelloch (1990); Leighton (1991); Karloff-Suri-Vassilvitskii (2010).
- **Propagator networks**: Sussman-Radul (2009) "The Art of the Propagator"; Radul (2009) MIT PhD; Steele (1980) MIT PhD.
- **Lattice-based distributed computing**: Hellerstein (2010) CALM; Conway et al. (2012) BloomL; Kuper-Newton (2013) LVars; Garg (2020+) LLP framework.

### Project-internal cross-references

- [`structural-thinking.md`](../../.claude/rules/structural-thinking.md) — design mantra + SRE lattice lens
- [`on-network.md`](../../.claude/rules/on-network.md) — design mantra + on-network principle
- [`stratification.md`](../../.claude/rules/stratification.md) — strata as fixpoint composition
- [`HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`](2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — Boolean variety design consumer
- [`LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md`](2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md) — element-level theory
- [`LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md`](2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md) — per-variety operational catalog
- [`MODULE_THEORY_LATTICES.md`](2026-03-28_MODULE_THEORY_LATTICES.md) — module-theoretic backbone
- [`SRE_TRACK2I_SD_CHECKS_DESIGN.md`](../tracking/2026-04-30_SRE_TRACK2I_SD_CHECKS_DESIGN.md) — Phase 3c worked example
- [`PREDUCE_MASTER.md`](../tracking/2026-05-02_PREDUCE_MASTER.md) — PReduce series consumer
- [`SH_MASTER.md`](../tracking/2026-04-30_SH_MASTER.md) — SH series consumer
- [`PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md`](2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md) — architectural-distinctiveness argument

### Companion deep surveys (this batch)

- [`PARALLEL_ALGORITHMS_SURVEY.md`](2026-05-02_PARALLEL_ALGORITHMS_SURVEY.md) (782 lines) — 10-topic deep survey of algorithmic-thinking mind-space
- [`LATTICE_CANONICAL_FORMS_SURVEY.md`](2026-05-02_LATTICE_CANONICAL_FORMS_SURVEY.md) (697 lines) — 10-topic deep survey of lattice canonical-form theory
- [`ARCHITECTURE_NOVELTY_SURVEY.md`](2026-05-02_ARCHITECTURE_NOVELTY_SURVEY.md) (582 lines) — 10-topic novelty assessment for the architectural claims

### Operational supplement

- [`S_LENS_REFERENCE.md`](2026-05-02_S_LENS_REFERENCE.md) — distillation for active design-review use

---

## Document status

**Stage 0/1 research synthesis** — vocabulary, theory grounding, system survey, gap identification, novelty staking, falsifiability questions, implementation-note shape recommendation.

**No design commitments**. A Stage 3 design track (e.g., adding Q7 canonical-form to the SRE lattice lens; per-variety algorithmic-anchor dispatch in propagator scheduler) would follow from this if pursued; that decision is downstream.

**Next steps if pursued**:
1. External review of the Hyperlattice Conjecture's falsifiability questions (§4.4).
2. Track 2I Phase 3 sweep closure (full domain inventory by variety).
3. Decision on whether to land Q7 (canonical form) in the SRE lattice lens.
4. Decision on per-variety algorithmic-anchor dispatch design (would be a substantial implementation track).

**Living document**: as more variety identifications happen (Track 2I sweep) and more algorithmic anchors get explicit (PReduce Track 4 cost extraction; future Hasse-driven scheduler work), this note's tables (§3.5, §6.1) get updated.
