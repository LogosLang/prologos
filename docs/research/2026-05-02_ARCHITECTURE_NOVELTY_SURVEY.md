# Architecture Novelty Survey (Working Draft)

**Date**: 2026-05-02
**Author**: Claude (Opus 4.7, 1M context)
**Status**: Working draft for the three-thread research synthesis on Prologos's load-bearing architectural claims
**Scope**: Frontier-staking thread — what's prior art, what's partial precedent, what's apparent novelty
**Method**: WebSearch + WebFetch over the published literature on each topic + cross-reference against project-internal claims in `structural-thinking.md`, `on-network.md`, the Hypercube BSP-LE addendum (2026-04-08), and the lattice-variety / lattice-hierarchy notes (2026-04-30).

The two project claims under audit:
- **C1 (Hyperlattice Conjecture)**: *every computable function is expressible as a fixpoint computation on lattices, and the Hasse diagram of the lattice IS the optimal parallel decomposition of that computation.*
- **C2 (algorithmic-thinking ↔ information-flow duality)**: *parallel-algorithm theory (BSP, hypercube, prefix-scan) and information-flow on a propagator network are different design mind-spaces but stand in correspondence — the algorithmic optimum and the network's Hasse adjacency are two views of the same structure.*

**Tagging convention**: each finding is one of:
- **GROUNDED PRIOR ART** — Prologos is inheriting; cite the source.
- **PARTIAL PRECEDENT** — related claim exists but with different scope/framing; the gap is meaningful.
- **APPARENT NOVELTY (verify)** — no clear precedent located in this search; flag for external review.

---

## §1. Propagator networks lineage

### 1.1 Existing claims

**Sussman & Radul, "The Art of the Propagator"** (MIT-CSAIL-TR-2009-002, January 2009; abridged at Intl Lisp Conf 2009). Quote from the project page: "the basic computational elements are autonomous machines interconnected by shared cells through which they communicate. Each machine continuously examines the cells it is interested in, and adds information to some based on deductions it can make from information from the others." The cells' merge function is required to "determine a (semi-)lattice (up to equivalence by equivalent?)" with associativity, commutativity, idempotence — i.e., the lattice constraint is *correctness of merging* (CALM-like, before CALM was named).

**Sussman, "We Really Don't Know How to Compute!"** (Strange Loop 2011). The closest thing to a parallel-decomposition claim anywhere in the lineage: "even though propagator networks are typically implemented with a message queue and a single thread, theoretically each propagator could be run in parallel, sending messages back and forth." This is a *possibility* claim, not an *optimality* claim.

**Steele's PhD thesis (1980), "The Definition and Implementation of a Computer Programming Language Based on Constraints"** (MIT). The "locality principle" (Steele 1980): "each constraint or each class of constraint is propagated independently of the existence or non-existence of other constraints" — *local* propagation, but no parallelism story per se.

**Predecessors — the lineage Sussman/Radul build on**:
- **Kahn (1974), "The Semantics of a Simple Language for Parallel Programming"** (IFIP). Deterministic dataflow: a network of sequential processes communicating via unbounded FIFO channels; output is a deterministic function of inputs regardless of timing. *Determinism* is the framing, not optimality. The lattice content is implicit (channels are continuous functions on Scott domains).
- **Waltz (1972, MIT PhD thesis)**, polyhedral scene labeling. Constraint propagation as iterative narrowing of variable domains. Not parallel in the original; later parallel versions in O(log³ n) on EREW PRAM with O(n³ / log³ n) processors exist (1990s+) but are not the primary framing.
- **Mackworth (1977), "Consistency in Networks of Relations"** (AIJ 8(1), 99–118). Arc-, path-, node-consistency. AC-3 is the canonical algorithm. No parallel-decomposition claim.
- **Cellular automata** (von Neumann 1948 lectures; Wolfram 1980s+). Local update, parallel by construction, but no lattice/Hasse framing — the "parallelism" is about uniform spatial layout, not Hasse-driven decomposition.
- **Connectionist networks / PDP** (Rumelhart-McClelland 1986). Parallel by physiological analogy; lattice content is buried in activation functions, not exposed as a parallel-decomposition story.

### 1.2 What Prologos adds

The Sussman/Radul propagator model is a substrate inherited essentially as-is. Two project-specific contributions sit on top:
- **Mantra-driven discipline**: "All-at-once, all in parallel, structurally emergent information flow ON-NETWORK." Sussman/Radul left parallelism as an afterthought ("could be run in parallel"). Prologos elevates it to a design constraint.
- **Hasse-adjacency claim** (C1): not present in Sussman/Radul. The original propagator paper says lattice merges must be correct; it does *not* say the Hasse diagram is the optimal parallel structure. That's a Prologos-specific claim.

### 1.3 Tag

- **GROUNDED PRIOR ART**: the propagator model itself (Sussman/Radul 2009; Steele 1980), the lattice/merge correctness story, the cells-with-merge architecture.
- **APPARENT NOVELTY (verify)**: the explicit parallel-decomposition claim tying parallelism to Hasse adjacency. The lineage *could* have made this claim — it didn't.

---

## §2. CALM theorem

### 2.1 Existing claims

**Hellerstein (2010), "The Declarative Imperative: Experiences and Conjectures in Distributed Logic"** (CIDR keynote / SIGMOD Record). The original conjecture: *consistency = logical monotonicity*. Coordination-free implementations exist iff the program is monotonic in its logic.

**Ameloot, Neven, Van den Bussche (2013)**, "Relational transducers for declarative networking." Formal proof of the CALM conjecture for the relational-transducer model: a query has a coordination-free distributed implementation iff it is monotone.

**Hellerstein & Alvaro (2019)**, "Keeping CALM: When Distributed Consistency Is Easy" (arXiv:1901.01930 → CACM 2020). Survey, restatement, and extensions: monotone programs admit streaming, message-reordering-tolerant implementations.

**BloomL (Conway et al. 2012, SoCC)**, "Logic and Lattices for Distributed Programming." Generalizes Bloom's set-based CALM to *user-defined lattices* — any lattice with a monotone merge admits coordination-free distributed semantics. This is the explicit CALM-on-arbitrary-lattices generalization Prologos inherits.

**LVars (Kuper-Newton 2013, FHPC)**, "LVars: Lattice-based Data Structures for Deterministic Parallelism." A user-specified semilattice; threshold reads + monotone writes give *deterministic-by-construction* parallelism. Quote from the paper's framing: lattices ensure determinism through "monotonic store growth and determinism" — when all updates move monotonically upward, the result is independent of scheduling order. Determinism is the proven property; *no claim that the lattice's Hasse diagram is the optimal parallel structure*.

**Differential dataflow (McSherry, Murray, Isaacs, Isard 2013, CIDR)** — uses lattices (multi-dimensional logical timestamps) for incremental computation. The lattice provides the *structure of differences*, not an optimal parallel decomposition.

### 2.2 What CALM leaves open

CALM says *monotone ⇒ coordination-free*. It does NOT say:
- That the lattice's structural properties (Boolean, distributive, semidistributive) yield specific parallel-decomposition strategies.
- That the Hasse diagram has any role in the *shape* of the parallel decomposition.
- That non-monotone work admits stratification (this came later — stratified Datalog, Ramalingam-Reps, etc., is a separate body).

The CALM result is an *iff* characterization of *coordination-freeness*, not an *optimality* claim about decomposition. The distinction matters: CALM says "you can run this without coordination"; Prologos C1 says "the lattice's Hasse adjacency tells you the *optimal* way to decompose it."

### 2.3 What Prologos adds

- The monotone-merge constraint is inherited directly from CALM/BloomL/LVars (no novelty here).
- The *stratification* work — S0 / S(-1) / S1 NAF / S2 well-founded / Topology — is conventional non-monotone-Datalog discipline applied to propagators. Largely inherited.
- The Hasse-diagram *optimality* claim is a strict extension of CALM. CALM says coordination-free is possible; Prologos says the lattice tells you the *shape* of the optimum. CALM is silent on shape.

### 2.4 Tag

- **GROUNDED PRIOR ART**: CALM (Hellerstein 2010, Ameloot et al. 2013) — the monotone-merge → coordination-free direction. BloomL — user-defined-lattice generalization. LVars — deterministic-parallel framing.
- **APPARENT NOVELTY (verify)**: the *optimality* extension. CALM does not claim optimality; Prologos C1 does.

---

## §3. Geometry of Interaction

### 3.1 Existing claims

**Girard (1989), "Geometry of Interaction 1: Interpretation of System F"** (Logic Colloquium '88). The execution formula — proof normalization expressed as an operator equation. Connects cut-elimination to dynamics via algebra of operators on a Hilbert space. Subsequent versions: GoI II (1988), GoI III (1995, multiplicatives + additives), GoI V (2011, hyperfinite factor).

**Mackie (1995), "The Geometry of Interaction Machine"** (POPL 1995). An abstract machine for token-passing GoI execution; concrete computational interpretation of Girard's framework.

**Muroya & Ghica (2018), "The Dynamic Geometry of Interaction Machine"** (FSCD/CSL etc.). Adds graph-rewriting dynamics to GoI tokens.

### 3.2 Parallelism claims in the GoI lineage

GoI is intrinsically a *path-tracing* / *token-passing* model. Each token's trajectory is independent of other tokens — this could in principle be parallelized — but the published GoI literature focuses on *uniqueness of normal form* (categorical semantics) and *iteration theories / fixpoint operators* (Hasegawa, Hyland), NOT on *parallel decomposition optimality*. Quote from search: "trace axioms are equivalent to standard axioms for a fixpoint operator. Dually, with the tensor product being coproduct, the trace axioms are equivalent to standard axioms for the iteration (dagger) operation in iteration theories."

The lattice/Hasse connection in GoI is essentially absent. GoI lives in the world of operator algebras and Hilbert spaces, not order theory.

### 3.3 What Prologos adds

The connection from GoI to Prologos is *inspirational* (information flow, locality of interaction) more than *technical*. GoI does not predict Prologos's Hasse-adjacency claim; conversely, Prologos's lattice machinery does not subsume GoI's operator-algebra content.

### 3.4 Tag

- **PARTIAL PRECEDENT**: GoI gives a fixpoint-operator + iteration-theory frame for cut-elimination dynamics. Prologos's "fixpoint computation on lattices" claim has *different* technical content (lattice-theoretic vs operator-algebraic) but rhymes structurally.
- **APPARENT NOVELTY (verify)**: GoI literature does not contain Hasse-diagram parallel-decomposition claims; Prologos's claim is not GoI-derived.

---

## §4. Interaction nets

### 4.1 Existing claims

**Lafont (1990), "Interaction Nets"** (POPL 17). Local graph-rewriting formalism; agents with explicit ports; rewrite rules between agent pairs. Quote from search summary: "The framework features a type discipline for deterministic and deadlock-free (microscopic) parallelism. These properties together allow massive parallelism." Strong confluence is the core property: any two reductions of disjoint redexes commute.

**Lafont (1997), "Interaction Combinators"** (Information and Computation 137). A canonical small set of agents (γ, δ, ε) sufficient to encode any interaction system. Surpasses Turing machines and λ-calculus "in fundamental aspects" (Taelin's framing).

**Lévy (1980)**, "Optimal reductions in the lambda calculus" (To H.B. Curry: Essays). Optimal as in *no useless duplication of work*. There is no optimal strategy in time/space generally, but there IS a canonical reduction order that avoids redundant β-steps.

**Lamping (1990), "An algorithm for optimal lambda calculus reduction"** (POPL). The first concrete implementation of Lévy-optimal reduction.

**Asperti & Guerrini (1998), "The Optimal Implementation of Functional Programming Languages"** (Cambridge). Comprehensive monograph covering the Lévy-optimal / Lamping / GoI lineage. Quote: "All traditional implementation techniques for functional languages fail to avoid useless repetition of work. They are not 'optimal' in their implementation of sharing."

**HVM2 (Taelin / HigherOrderCO 2024)**, paper/repo at https://github.com/HigherOrderCO/HVM2. Reports 400 MIPS (Apple M3 Max single thread) → 5,200 MIPS (M3 Max, 16 threads) → 74,000 MIPS (RTX 4090, 32,768 threads). Quote: "achieved a near-ideal parallel speedup as a function of cores available."

### 4.2 What interaction-net parallelism predicts structurally

Strong confluence ⇒ disjoint-redex independence ⇒ embarrassingly parallel local rewriting. Crucially: this gives parallelism *without* an explicit Hasse-adjacency story. The "topology of parallelism" is the topology of the *graph being rewritten*, not the lattice of values.

Quote from search summary: "Strong confluence in interaction nets means reduction sequences commute and yield unique normal forms regardless of order ... A consequence of perfect confluence is that every normalizing interaction order produces the same result in the same number of interactions."

### 4.3 What Prologos adds

Interaction nets and propagator networks are *both* graph-rewriting / dataflow formalisms with parallelism stories, but:
- **Interaction nets**: parallelism from graph-locality + strong confluence.
- **Propagator networks (Prologos framing)**: parallelism from lattice-monotonicity + Hasse-adjacency.

These are different structural claims. The interaction-net claim is well-established; Prologos's lattice-Hasse claim is its own separate hypothesis.

### 4.4 Tag

- **GROUNDED PRIOR ART**: strong-confluence ⇒ embarrassing parallelism, locality of rewriting, near-ideal speedup at scale (HVM2 demonstrates).
- **PARTIAL PRECEDENT**: interaction nets achieve massive parallelism via *different* structural reasoning (locality + strong confluence) than the Hasse-diagram claim. Both are forms of "structure determines parallelism" — different structures, different parallelism mechanisms.
- **APPARENT NOVELTY (verify)**: the specific claim that lattice Hasse adjacency *is* the parallel decomposition. Interaction-net literature does not make this claim; HVM2's parallelism is graph-locality, not lattice-driven.

---

## §5. E-graphs as parallel decomposition

### 5.1 Existing claims

**Willsey et al. (2021), "egg: Fast and Extensible Equality Saturation"** (POPL Distinguished Paper). E-graphs as compact representation of equivalence classes; "rebuilding" as amortized invariant restoration. Quote from search: "searching for rewrite matches can be parallelized thanks to the phase separation. Either the rules or e-classes could be searched in parallel. The once-per-iteration frequency of rebuilding allows egg to establish other performance-enhancing invariants that hold during the read-only search phase."

**Zhang, Wang, Flatt, Cao, Zucker, Rosenthal, Tatlock, Willsey (2023, PLDI), "Better Together: Unifying Datalog and Equality Saturation"** (egglog). Quote: "Like Datalog, it supports efficient incremental execution, cooperating analyses, and lattice-based reasoning. Like EqSat, it supports term rewriting, efficient congruence closure, and extraction of optimized terms." Egglog supports parallel execution via `-j N` option.

**Schlatt et al. (Merckx et al. 2026, arXiv:2602.16707), "E-Graphs as a Persistent Compiler Abstraction."** xDSL/MLIR dialect (`eqsat`) for native e-graph IR; equality saturation interleaved with constructive compiler passes.

**Moss / Tiurin (2025, arXiv:2505.00807), "E-Graphs With Bindings."** Categorical interpretation in closed symmetric monoidal categories; hierarchical hypergraph DPO rewriting; addresses λ-binders.

**Biondo, Castelnovo, Gadducci (CALCO 2025), "EGGs Are Adhesive!"** (LIPIcs 342:10). Proves e-graphs (acyclic term graphs with congruence closure) form an adhesive category. Explicit categorical foundation; enables DPO rewriting theory to apply.

**Cranelift ægraphs (Fallin 2023, EGRAPHS workshop / blog 2026-04-09)**, "Acyclic E-graphs for Efficient Optimization in a Production Compiler." First e-graph in production JIT. *Not* full equality saturation — greedy single-pass, predictable compile time. Production-scale e-graph compiler optimization is now real.

### 5.2 Lattice and adjacency in the e-graph world

E-graphs canonicalize *modulo a rewrite system*, not a lattice variety. The key insight from `2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md` (this repo): "E-graphs canonicalize modulo a *rewrite system*, not a *lattice variety*. The two converge if the rewrite system is a complete confluent set of equations defining the variety, but in general they're different mechanisms."

E-graph adjacency (single rewrite step) is structurally analogous to Hasse adjacency (single covering relation in a lattice) BUT:
- E-graph "adjacency" is per-rewrite-rule, not per-cover-relation.
- E-graphs have congruence closure as a built-in equality kernel; lattices don't.
- Equality saturation explores via *applying rewrites*; lattice fixpoint computation explores via *joining/meeting elements*.

**Egglog is the closest precedent**: it explicitly combines lattice-based reasoning (Datalog) with equality saturation (e-graphs). But the framing is "use lattices for incremental analysis, use e-graphs for term equality" — not "the lattice's Hasse diagram is the parallel decomposition."

### 5.3 What Prologos adds

The Prologos framing puts everything on lattice-valued cells. E-graphs / egglog put rewrite-driven equality on top of (optionally) lattice-based incrementality. Different stack:
- **Egglog**: Datalog (lattice-based) + e-graph (congruence-rewrite-based) → unified surface.
- **Prologos**: lattice-valued cells with structural unification (PUnify) + Hasse-driven parallelism.

The "PUnify ↔ Whitman" connection (lattice-variety note §5.1) suggests the SRE *could* be brought closer to e-graph-style canonicalization, but that's not landed yet.

### 5.4 Tag

- **GROUNDED PRIOR ART**: e-graphs as parallel-explorable equivalence representations (egg's parallel match search; egglog's `-j` parallelism); production-scale e-graph compiler optimization (Cranelift ægraphs).
- **PARTIAL PRECEDENT**: egglog's lattice + e-graph unification is the closest published precedent for combining lattice reasoning with structural rewriting in a parallel-execution-friendly engine.
- **APPARENT NOVELTY (verify)**: the specific claim that *lattice Hasse adjacency* is the parallel decomposition. E-graphs achieve parallelism through phase separation + rebuilding, not through lattice topology.

---

## §6. Datalog and bottom-up evaluation

### 6.1 Existing claims

**Semi-naive evaluation** (classical, c. 1980s — Bancilhon, Ullman). Iterate: at round k, compute new tuples from rules applied to delta from round k-1. Avoids redundant re-derivation. Naturally embarrassingly parallel within a round (one rule × one delta = independent).

**Differential dataflow** (McSherry, Murray, Isaacs, Isard 2013, CIDR). Quote: "The techniques describe defined operators for use in a data-parallel program that performs the computations on the determined differences between the collections of data by creating a lattice and indexing or arranging the determined differences according to the lattice." This is the closest published statement to "lattice structure organizes the parallelism."

**Bloom / BloomL** (Alvaro, Conway, Hellerstein, Marczak — Berkeley 2010s). Datalog-based language with lattice extensions; CRDT-friendly; CALM-aligned.

**Garg's Lattice-Linear Predicate (LLP) framework** (Garg & coauthors, 2018–2024). This is the most directly relevant published precedent for a specific form of C1.

Quote from "Predicate Detection to Solve Combinatorial Optimization Problems" (Garg, SPAA 2020) summary: "By applying the lattice-linear predicate detection algorithm to unconstrained problems, researchers get the Gale-Shapley algorithm for the stable marriage problem, Dijkstra's algorithm for the shortest path problem, and Demange-Gale-Sotomayor's algorithm for the minimum market clearing price, and the lattice-linear predicate detection method yields a parallel version of these algorithms."

Quote from "A Lattice Linear Predicate Parallel Algorithm for the Dynamic Programming Problems" (Garg 2021): "The LLP algorithm views solving a problem as searching for an element in a finite distributive lattice that satisfies a given predicate B, where the predicate is required to be closed under the operation of meet (or, equivalently lattice-linear). The LLP algorithm works on the finite poset in parallel to find the least element in the distributive lattice that satisfies the given predicate, starting with the bottom element of the lattice and marching towards the top element of the lattice in a parallel fashion by advancing on any chain of the poset for which the current element is forbidden."

### 6.2 The Garg precedent specifically

This is **the strongest single precedent for Prologos C1's optimality claim**. Garg explicitly:
- Treats search as *lattice traversal* on the Hasse poset.
- Advances "in parallel along any chain of the poset" — i.e., the poset / Hasse structure determines the parallelism.
- Uses the lattice-linearity property (meet-closed predicates) as the gate for the parallel algorithm to apply.

Garg's framework yields parallel versions of Gale-Shapley, Dijkstra, MST, knapsack, longest subsequence, etc. — claiming a *general* principle (lattice-linearity ⇒ parallel algorithm via Hasse traversal).

**Critical difference**: Garg's claim is *graded* — it applies to *finite distributive lattices* with *lattice-linear predicates*. Prologos C1 asserts *every computable function* is a fixpoint on lattices, with the Hasse diagram determining optimal parallel decomposition. Garg's claim is one *worked instance* of the broader claim, not a universal statement.

### 6.3 What Prologos adds

- The conjunction "every computable function" + "Hasse is optimal" is broader than Garg's per-problem-class instances.
- Garg's framework is *concrete-algorithm-flavored* (Dijkstra, MST, knapsack); Prologos's framework is *substrate-flavored* (compile a propagator-network compiler on top).
- The *generalization* from Garg's worked-out cases to Prologos's universal claim is the apparent-novelty piece.

### 6.4 Tag

- **GROUNDED PRIOR ART**: semi-naive, differential dataflow, BloomL, Datalog parallelism.
- **STRONG PARTIAL PRECEDENT (graded form of C1)**: Garg's LLP framework. *This is the strongest single piece of literature supporting C1's optimality direction*. Garg states (a) lattice-linear predicates admit parallel detection, (b) the parallel algorithm walks the lattice's poset (Hasse), (c) this yields concrete known-optimal parallel algorithms (Dijkstra, etc.).
- **APPARENT NOVELTY (verify)**: the *universal* extension — Garg's framework applied to *every* computation (which is C1's claim). Garg never makes the universal claim; he gives many instances and a general method for *lattice-linear* problems.

---

## §7. Categorical parallelism — polynomial functors

### 7.1 Existing claims

**Joyal (1981, 1986), "Foncteurs analytiques et espèces de structures."** Combinatorial species; analytic functors. Categorical underpinnings of polynomial-functor theory.

**Gambino & Kock (2013), "Polynomial functors and polynomial monads"** (Math Proc Camb Phil Soc). Polynomial functors as a double category / framed bicategory; free monads on polynomial functors are polynomial monads.

**Spivak & Niu (2024), "Polynomial Functors: A Mathematical Theory of Interaction"** (London Math Society / arXiv:2312.00990). The category Poly of polynomial functors models interaction protocols and dynamical systems. Includes "parallel product comonoids" — the parallel product is a structural feature of Poly.

**Kock's Notes on Polynomial Functors** (lecture notes; multiple versions).

### 7.2 What categorical parallelism gives

Polynomial functors decompose into pullback / dependent-product / dependent-sum components — a *categorical* decomposition that *could* in principle correspond to parallel structure. Spivak-Niu's "parallel product" is a categorical operation (⊗ in Poly).

But: **the search did not surface a published claim that the categorical decomposition of a polynomial functor IS the optimal parallel decomposition of the computation it represents.** The categorical content is structural, not algorithmic-optimality.

### 7.3 What Prologos adds

Prologos's design docs (e.g., `2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md`, `2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md`) use polynomial-functor framing — broadcast propagator = polynomial functor made operational. The propagator-design rule references "broadcast is the polynomial functor made operational" with measured A/B speedups (2.3× at N=3, 75.6× at N=100 vs N-propagator model).

This is a *bridge* claim: polynomial functors → broadcast propagators → real parallel speedup. Whether this counts as a "categorical proof of parallel optimality" is open — it's at least a worked instance.

### 7.4 Tag

- **GROUNDED PRIOR ART**: polynomial-functor decomposition theory (Joyal, Gambino-Kock, Spivak-Niu); structural notion of parallel product in Poly.
- **PARTIAL PRECEDENT**: the categorical decomposition is structural; the *operational mapping* to parallel propagators is Prologos's specific synthesis.
- **APPARENT NOVELTY (verify)**: the explicit "polynomial functor decomposition IS optimal parallel structure" claim. Spivak-Niu treats parallel product as a structural operation, not as an optimality theorem.

---

## §8. THE KEY NOVELTY QUESTION — Hasse-adjacency as parallel-decomposition claim

This is the central question. Has anyone in the published literature stated a generalized "the Hasse diagram of a lattice is the optimal parallel decomposition" — not as a metaphor, but as a load-bearing claim?

### 8.1 Searches conducted

- "Hasse diagram parallel decomposition lattice computation"
- "Boolean lattice hypercube algorithms parallel computing Hasse"
- "Birkhoff representation distributive lattice optimal parallel computation"
- "lattice-linear" Vijay Garg predicate detection
- "Hyperlattice optimal parallel lattice fixpoint computation"
- "parallel exploration lattice topology Hasse optimal computation theorem"
- "Knaster-Tarski parallelism lattice fixpoint optimal decomposition"
- "Reading-Speyer-Thomas finite semidistributive lattice canonical"

### 8.2 What I found

**Strong precedent #1: per-variety, the precedents are graded:**

| Variety | Paralelism connection | Source |
|---|---|---|
| **Boolean (Q_n)** | The Boolean lattice's Hasse diagram IS the hypercube graph (textbook: Wikipedia, Eppstein). Hypercube algorithms (broadcast, all-reduce, prefix-scan, butterfly) are the optimal parallel patterns FOR THIS lattice. | Hypercube parallel computing 1980s+ (Stout, Wagar etc.); MIT 6.895 lecture notes |
| **Distributive** | Birkhoff's representation theorem: finite distributive lattices ↔ order-ideals of poset of join-irreducibles. Garg's LLP framework: "search the poset in parallel, advancing along any chain for which the current element is forbidden." | Garg 2020+ "Predicate Detection..."; Streit-Garg "Constrained Cuts, Flows, and Lattice-Linearity" arXiv:2512.18141 |
| **Series-parallel partial orders** | "Series-parallel graphs describe the dependencies between tasks in a parallel computation and can be extracted from functional programs relatively easily, providing a good way of visualizing the amount of parallelism in a computation." | Wikipedia "Series-parallel partial order" (Möhring et al. — classical) |
| **General poset (Dilworth)** | "Dilworth's theorem optimizes task scheduling in systems with precedence constraints and minimizes the number of processors needed for parallel task execution. The width of the precedence graph (the maximum antichain size) determines the minimum number of processors required." | Dilworth 1950; subsequent scheduling literature |
| **Semidistributive (finite)** | Reading-Speyer-Thomas 2019 fundamental theorem of finite SD lattices — canonical form; no parallel-algorithm claim landed. |

**The graded-precedent observation**: each lattice variety has its own well-known parallel-decomposition literature:
- Boolean ↔ hypercube algorithms (canonical, decades-old).
- Distributive ↔ Birkhoff + Garg LLP.
- General poset ↔ Dilworth's theorem + scheduling.

**Strong precedent #2: Hasse-as-hypercube identity (specifically for Boolean).**

The Hasse diagram of the Boolean lattice B_n IS the n-dimensional hypercube graph — this is textbook, attributed to Hassse / Birkhoff / standard references. Quote from the search: "A hypercube is defined as the undirected Hasse diagram of a Boolean lattice. The Hasse diagram of the Boolean lattice of order n is the n-dimensional hypercube."

The hypercube is *the* optimal communication topology for many parallel algorithms (Valiant BSP, prefix-scan, all-reduce, butterfly). This is well-established.

**What I did NOT find**: a *unified* statement across all lattice varieties that "the Hasse diagram is the optimal parallel decomposition." The unified claim is APPARENT NOVELTY.

### 8.3 The strongest single precedent

**Garg's LLP framework**, restricted to finite distributive lattices, makes a claim very close in shape to Prologos C1 — *for that variety*. Prologos C1 is the *generalization* of this kind of claim across varieties.

The Reading-Speyer-Thomas SD-lattice work, the Birkhoff distributive theory, and the Boolean hypercube literature can be read as *graded* per-variety instances of the claim. Putting them together as a unified "the lattice variety determines the parallel decomposition strategy" is what `2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md` already does internally — and *that* unified-across-varieties framing appears to be Prologos's specific synthesis.

### 8.4 What Prologos's framing adds

The Prologos framing is unified across:
- Lattice variety (Boolean / distributive / SD / modular / free).
- Hasse adjacency as the metric of parallel decomposition.
- Application to *every* computation expressible as lattice fixpoint.

Each of these has piecewise precedent; the *combination* — "for every variety, the variety's free lattice Hasse diagram parametrizes the parallel decomposition" — is what I cannot find in the literature.

### 8.5 Tag

- **GROUNDED PRIOR ART**: Boolean Hasse = hypercube; distributive Hasse + Birkhoff representation; Dilworth scheduling; Reading-Speyer-Thomas SD canonical form; Garg LLP framework.
- **STRONG PARTIAL PRECEDENT (graded form of C1)**: Garg's LLP for distributive lattices.
- **APPARENT NOVELTY (verify)**: the *unified-across-varieties* statement of Hasse-adjacency-IS-parallel-decomposition.
  - Specifically: the claim that the parallel decomposition of a fixpoint computation is *uniquely determined by the lattice* (not a design choice but a structural property).
  - If true and provable, this would be a significant contribution. Worth external review.

---

## §9. Algorithmic-thinking ↔ information-flow duality (C2)

### 9.1 Existing claims — closest analogs

**Kowalski (1979), "Algorithm = Logic + Control"** (CACM 22(7), 424–436). The classic decomposition: an algorithm is a *logical specification* (what) + a *control strategy* (how). Quote from the search: "an algorithm consists of a problem description (the logic part) and a strategy to perform useful computations on this description (the control part) ... In traditional programming, the programmer takes care of both logic and control aspects, while in declarative programming, the programmer takes care only of the logic, and the interpreter of the language takes care of control."

**Hoare's UTP (Unifying Theories of Programming)** — programs and specifications are both predicates; no semantic distinction. Specification ↔ implementation duality.

**Functional vs procedural / declarative vs imperative** — the broad family of programming-paradigm dualities.

**Hellerstein's "The Declarative Imperative"** title itself plays on this duality.

### 9.2 What Prologos C2 says

C2: "parallel-algorithm theory (BSP, hypercube, prefix-scan) and information-flow on a propagator network are different design mind-spaces but stand in correspondence — the algorithmic optimum and the network's Hasse adjacency are two views of the same structure."

This is *not* the same as Kowalski's logic+control decomposition. C2 says:
- *Mind-space A (algorithmic-thinking)*: think about parallel algorithms — BSP supersteps, hypercube communication, prefix-scan trees, butterflies.
- *Mind-space B (information-flow)*: think about cells, propagators, monotone merges, Hasse-driven dataflow.
- *Correspondence claim*: A's optimum and B's structure are the same object viewed differently.

This is more specific than Kowalski's general duality. It's *parallel-algorithm-theory ↔ propagator-network-shape*.

### 9.3 What I found

The search "information flow algorithmic thinking duality programming paradigm" returned essentially nothing — the only hit was educational ICT-competence material. *No clear precedent located for the specific algorithmic ↔ information-flow framing.*

The Kowalski "Algorithm = Logic + Control" framing is the closest published analog, but it's a *different* duality: logic vs control, not algorithm-thinking vs information-flow. They overlap (information-flow is a kind of declarative; algorithmic-thinking is a kind of imperative) but the specific correspondence claim — *the BSP / hypercube / prefix-scan optimum IS the propagator network's Hasse structure* — appears to be Prologos-specific.

### 9.4 Tag

- **PARTIAL PRECEDENT**: Kowalski's logic + control decomposition; Hoare's UTP; the broad declarative ↔ imperative duality literature. These are in the same conceptual neighborhood but say different specific things.
- **APPARENT NOVELTY (verify)**: the specific "parallel-algorithm-theory ↔ information-flow" mind-space-correspondence framing. *No precedent located in 3 search variants.* Flag for external review.

---

## §10. Self-hosting compilers and parallel-decomposition claims

### 10.1 Existing claims — production dependently-typed compilers

**Lean 4 (de Moura & Ullrich 2021, CADE 28)**, "The Lean 4 Theorem Prover and Programming Language." Self-hosted (Lean implemented in Lean). New typeclass resolution via tabled resolution; functional but in-place programming model. Quote from search: "Lean 4 is an efficient functional programming language based on a novel programming paradigm called functional but in-place." *No parallel-decomposition claim tied to lattice structure.*

**Idris 2 (Brady)**. Elaborator reflection (POPL 2016). Quote: "the elaborator is a function from high-level Idris abstract syntax trees to programs in this tactic language, with abstractions and effects in the tactic language including holes to be filled in and unification problems yet to be resolved." Holes + unification — propagator-shaped, but not framed as a propagator network.

**Coq / Rocq, Agda** — self-hosted to varying degrees; type-checking is tree-walking + unification + tactic engines, not a propagator-network architecture.

**GHC parallel typecheck (Marlow et al.)** — "GHC has implemented two-phase interface file generation, allowing dependent modules to start typechecking as soon as their dependencies finish typechecking." Module-level pipelining, not lattice-driven.

### 10.2 The "compiler IS a propagator network" framing

I searched explicitly: `"compiler" "is a" "propagator network" self-hosted dependently typed`. No precedent found. The propagator-network model has been used in compilers in a piecemeal way:
- Cranelift's ægraphs are propagator-shaped (e-class equivalence + invariant restoration).
- Egglog uses Datalog + e-graph for compiler-style queries.
- LVars and BloomL are propagator-model-adjacent (lattice cells, threshold reads, monotonic writes).

But none of these is "the entire compiler is a propagator network" — they're "this part of the compiler uses propagator-model-like infrastructure."

### 10.3 What Prologos asserts

Prologos's `2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md` and `2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md` (referenced in repo, unread by me here) lay out the path. The on-network mantra requires:
- Module registry → cell with hash-union merge.
- Trait dispatch tables → cells.
- Type elaboration → propagator network.
- Constraint resolution → propagator stratification (S0 / S(-1) / S1 NAF / topology).

The end state: *the entire compiler is a propagator network running on its own substrate*. This is the load-bearing self-hosting claim, and it is more aggressive than any production dependently-typed compiler.

### 10.4 Tag

- **GROUNDED PRIOR ART**: propagator-style infrastructure in compilers (Cranelift ægraphs, egglog, LVars / BloomL adjacency).
- **PARTIAL PRECEDENT**: Lean 4's tabled resolution, Idris 2's elaborator reflection, GHC's pipelined typecheck — all propagator-model-adjacent in piecewise ways.
- **APPARENT NOVELTY (verify)**: the *unified* "the entire compiler is a propagator network" claim at production-scale dependent-types / linear-types / session-types. No production-grade dependently-typed compiler has made this architectural claim. Specifically novel: the conjunction of (a) self-hosted, (b) dependently typed, (c) compiler IS a propagator network, (d) parallel-decomposition tied to lattice structure.

---

## Novelty Assessment Synthesis

### (a) What's well-precedented (we're inheriting)

1. **Propagator network model itself** — Sussman/Radul (2009), Steele (1980). Cells + monotone merge + autonomous propagators.
2. **Lattice-monotonic merge for coordination-free distribution** — CALM (Hellerstein 2010), BloomL (Conway et al. 2012), LVars (Kuper-Newton 2013).
3. **Lattice fixpoint as universal computation framework** — Tarski (1955), abstract interpretation (Cousot-Cousot 1977), denotational semantics traditions.
4. **Dataflow lineage** — Kahn (1974), constraint propagation (Waltz 1972, Mackworth 1977), differential dataflow (McSherry-Murray-Isaacs-Isard 2013).
5. **Boolean lattice ↔ hypercube identity** — textbook lattice theory; hypercube parallel computing is canonical (Valiant BSP, MIT 6.895 etc.).
6. **Strong-confluence parallelism** — Lafont 1990 interaction nets, Lévy 1980 optimal reduction, Asperti-Guerrini 1998, HVM2 (2024).
7. **E-graph parallel saturation** — Willsey et al. (2021), egglog (Zhang et al. 2023), Cranelift ægraphs (Fallin 2023+).
8. **Categorical decomposition via polynomial functors** — Joyal, Gambino-Kock, Spivak-Niu.
9. **Stratified Datalog for non-monotone work** — long literature; Conway et al., Ramalingam-Reps.
10. **Per-variety lattice canonicalization** — Whitman 1941, Reading-Speyer-Thomas 2019, Birkhoff representation.

### (b) Partial precedents with novel Prologos framing

1. **Garg's LLP framework** is the strongest single precedent for the Hasse-adjacency optimality direction — but *graded* to finite distributive lattices with lattice-linear predicates. Prologos's universal-across-varieties extension is the novel piece.
2. **Polynomial-functor parallelism** — Spivak-Niu have parallel-product as a categorical operation, but not as an optimality claim. Prologos's broadcast propagator = "polynomial functor made operational" with measured A/B speedups makes the operational connection explicit.
3. **Egglog's lattice + e-graph unification** is the closest published precedent for combining lattice reasoning with structural rewriting at substrate level — but framed differently (Datalog + e-graph), not as Hasse-adjacency parallelism.
4. **CALM** says monotone ⇒ coordination-free; Prologos C1 extends to "the lattice's structural variety determines the *shape* of the parallel decomposition." CALM is silent on shape; Prologos asserts shape.
5. **GoI's iteration theory** is parallel-decomposition-adjacent (fixpoint operators, traces) but lives in operator-algebra space; the lattice connection is absent.

### (c) Apparent novelty worth verifying via external review

1. **Hyperlattice Conjecture (C1) — universal form**: "every computable function is a fixpoint on lattices, and the Hasse diagram of the lattice IS the optimal parallel decomposition." The *universal* claim across all lattice varieties is APPARENT NOVELTY. Garg's LLP is the strongest graded precedent (distributive case); the universal extension is not literature-attested in this search.
2. **Algorithmic ↔ information-flow duality (C2)**: the specific framing — "parallel-algorithm theory and propagator-network information flow are two mind-spaces in correspondence at the Hasse-adjacency level" — APPARENT NOVELTY. Kowalski's logic + control is the closest precedent; the specific correspondence claim is not published.
3. **"The entire compiler is a propagator network" at production-scale dependent-types**: APPARENT NOVELTY. Lean 4 / Idris 2 / Coq / Rocq / Agda all have piecewise propagator-model-adjacent infrastructure (tabled resolution, holes + unification, elaborator reflection) but none claims the architecture is propagator-network-uniform.
4. **Variety-relative-free-lattice canonicalization at runtime**: the lattice-variety note (`2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md`) proposes that SRE cells are FL_V(X) elements (relatively free in variety V), and that the canonical-form theory of FL_V(X) gives Prologos optimality arguments. This composition of free-lattice canonical form (Whitman, Reading-Speyer-Thomas) with propagator-network runtime substrate appears novel — the canonical-form theorems are classical lattice theory, but their *computational role* in a propagator-network compiler is Prologos-specific.

### (d) The strongest single precedent for C1's optimality claim, and what's different

**Strongest precedent: Garg's Lattice-Linear Predicate (LLP) framework** (Garg, SPAA 2020 + sequence; "Predicate Detection to Solve Combinatorial Optimization Problems"; "Parallel Minimum Spanning Tree Algorithms via Lattice Linear Predicates"; etc.).

Garg's claim, paraphrased: for finite distributive lattices with meet-closed (lattice-linear) predicates, the parallel detection algorithm advances simultaneously along any chain of the poset for which the current element is forbidden. This yields parallel versions of Gale-Shapley, Dijkstra, MST, knapsack, and other classical algorithms — the *Hasse poset* IS the parallel decomposition for these problems.

**What's different in Prologos C1**:

1. **Universal scope**: Garg restricts to finite distributive lattices + lattice-linear predicates. Prologos asserts this for *every* computation.
2. **Variety-graded vs universal**: Garg has one tool (distributive lattice traversal); Prologos asserts a per-variety toolkit (Boolean → hypercube algorithms; distributive → Birkhoff/Garg-style; SD → Reading-Speyer-Thomas; etc.) where each variety's Hasse parametrizes its optimum.
3. **Substrate vs algorithm**: Garg gives parallel algorithms for specific problems. Prologos asserts a *runtime substrate* (the propagator network) where every computation is structurally a Hasse-driven parallel decomposition.
4. **Self-hosting closure**: Prologos closes the loop — the compiler that compiles Hasse-driven programs is itself Hasse-driven. Garg has no analog of this.

The novelty of C1, if it stands, is the *universal scope and substrate-level claim*, not the per-instance parallel-algorithm-from-lattice claim (Garg has that). External reviewers should be asked specifically:
- "Has anyone in the literature claimed the Hasse diagram of an arbitrary lattice IS the optimal parallel decomposition of the corresponding fixpoint computation, in a universal form not restricted to a specific variety?"
- "Is there a known counterexample — a fixpoint computation on a lattice where the optimal parallel decomposition demonstrably is NOT the Hasse adjacency structure?"

These are the falsifiability questions that would resolve C1's status from "apparent novelty" to "novel theorem" or "false conjecture."

---

## Reference list

### Propagator networks
- Sussman, G.J., Radul, A. (2009). "The Art of the Propagator." MIT-CSAIL-TR-2009-002. https://dspace.mit.edu/handle/1721.1/44215
- Radul, A. (2009). "Propagation Networks: A Flexible and Expressive Substrate for Computation." MIT PhD thesis.
- Sussman, G.J. (2011). "We Really Don't Know How to Compute!" Strange Loop / InfoQ. http://lambda-the-ultimate.org/node/4389
- Steele, G.L. Jr. (1980). "The Definition and Implementation of a Computer Programming Language Based on Constraints." MIT PhD thesis.
- Steele, G.L. Jr., Sussman, G.J. (1980). "Constraints — a language for expressing almost-hierarchical descriptions." MIT AI Memo.
- Sussman, G.J. (current). Propagator project. https://groups.csail.mit.edu/mac/users/gjs/propagators/

### Predecessors
- Kahn, G. (1974). "The Semantics of a Simple Language for Parallel Programming." IFIP Congress 74, 471–475.
- Waltz, D.L. (1972). "Generating Semantic Descriptions from Drawings of Scenes with Shadows." MIT PhD thesis.
- Mackworth, A.K. (1977). "Consistency in Networks of Relations." AIJ 8(1), 99–118. https://www.cs.ubc.ca/~mack/Publications/AI77.pdf
- von Neumann, J. (1966, posthumous). *Theory of Self-Reproducing Automata*. Burks (ed.), Univ. Illinois Press.
- Rumelhart, D.E., McClelland, J.L., PDP Research Group (1986). *Parallel Distributed Processing*. MIT Press.

### CALM and lattice-based distributed programming
- Hellerstein, J.M. (2010). "The Declarative Imperative: Experiences and Conjectures in Distributed Logic." SIGMOD Record (CIDR keynote).
- Ameloot, T.J., Neven, F., Van den Bussche, J. (2013). "Relational transducers for declarative networking." JACM 60(2).
- Hellerstein, J.M., Alvaro, P. (2019). "Keeping CALM: When Distributed Consistency Is Easy." arXiv:1901.01930. CACM 2020.
- Conway, N., Marczak, W.R., Alvaro, P., Hellerstein, J.M., Maier, D. (2012). "Logic and Lattices for Distributed Programming." SoCC. https://dsf.berkeley.edu/papers/UCB-lattice-tr.pdf
- Kuper, L., Newton, R.R. (2013). "LVars: Lattice-based Data Structures for Deterministic Parallelism." FHPC. https://users.soe.ucsc.edu/~lkuper/papers/lvars-fhpc13.pdf
- Kuper, L., Turon, A., Krishnaswami, N.R., Newton, R.R. (2014). "Freeze After Writing: Quasi-Deterministic Parallel Programming with LVars." POPL.
- McSherry, F., Murray, D.G., Isaacs, R., Isard, M. (2013). "Differential Dataflow." CIDR. https://www.cidrdb.org/cidr2013/Papers/CIDR13_Paper111.pdf

### Geometry of Interaction
- Girard, J.-Y. (1989). "Geometry of Interaction 1: Interpretation of System F." Logic Colloquium '88 (North-Holland).
- Mackie, I. (1995). "The Geometry of Interaction Machine." POPL.
- Muroya, K., Ghica, D.R. (2018). "The Dynamic Geometry of Interaction Machine: A Token-Guided Graph Rewriter."

### Interaction nets and optimal reduction
- Lafont, Y. (1990). "Interaction Nets." POPL 17. https://dl.acm.org/doi/pdf/10.1145/96709.96718
- Lafont, Y. (1997). "Interaction Combinators." Information and Computation 137, 69–101.
- Lévy, J.-J. (1980). "Optimal reductions in the lambda-calculus." In *To H.B. Curry: Essays on Combinatory Logic, Lambda Calculus and Formalism*, Academic Press.
- Lamping, J. (1990). "An algorithm for optimal lambda calculus reduction." POPL.
- Asperti, A., Guerrini, S. (1998). *The Optimal Implementation of Functional Programming Languages.* Cambridge Tracts in Theoretical Computer Science 45.
- Taelin, V. (2024). "HVM2: A Parallel Evaluator for Interaction Combinators." HigherOrderCO. https://github.com/HigherOrderCO/HVM2

### E-graphs and equality saturation
- Willsey, M., Nandi, C., Wang, Y.R., Flatt, O., Tatlock, Z., Panchekha, P. (2021). "egg: Fast and Extensible Equality Saturation." POPL (Distinguished Paper). arXiv:2004.03082
- Zhang, Y., Wang, Y.R., Flatt, O., Cao, D., Zucker, P., Rosenthal, E., Tatlock, Z., Willsey, M. (2023). "Better Together: Unifying Datalog and Equality Saturation." PLDI. arXiv:2304.04332
- Fallin, C. (2023). "ægraphs: Acyclic E-graphs for Efficient Optimization in a Production Compiler." EGRAPHS Workshop.
- Merckx, J., Schlatt, P., et al. (2026). "E-Graphs as a Persistent Compiler Abstraction." arXiv:2602.16707
- Tiurin, A. (2025). "E-Graphs With Bindings." arXiv:2505.00807
- Biondo, R., Castelnovo, D., Gadducci, F. (2025). "EGGs Are Adhesive!" CALCO 2025, LIPIcs 342:10. https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CALCO.2025.10
- Willsey, M. (2022). "Practical and Flexible Equality Saturation." PhD thesis, U Washington. https://www.mwillsey.com/thesis/thesis.pdf

### Lattice theory and parallel algorithms (the C1 graded-precedent literature)
- Tarski, A. (1955). "A Lattice-Theoretical Fixpoint Theorem and Its Applications." Pacific J Math 5(2), 285–309.
- Birkhoff, G. (1933). "On the combination of subalgebras." Proc Camb Phil Soc 29, 441–464. (Distributive lattices ↔ order-ideals of poset of join-irreducibles.)
- Birkhoff, G. (1935). "On the structure of abstract algebras." (HSP theorem on varieties.)
- Whitman, P.M. (1941, 1942). "Free Lattices I, II." Annals of Mathematics 42, 43.
- Freese, R., Ježek, J., Nation, J.B. (1995). *Free Lattices.* AMS Mathematical Surveys and Monographs 42.
- Reading, N., Speyer, D., Thomas, H. (2019, published 2021). "The fundamental theorem of finite semidistributive lattices." arXiv:1907.08050. Selecta Mathematica.
- Garg, V.K. (2020). "Predicate Detection to Solve Combinatorial Optimization Problems." SPAA 2020. https://users.ece.utexas.edu/~garg/dist/garg-spaa20.pdf
- Garg, V.K. (2021). "A Lattice Linear Predicate Parallel Algorithm for the Dynamic Programming Problems." ICDCN. https://dl.acm.org/doi/fullHtml/10.1145/3491003.3491019
- Garg, R., Garg, V.K. (2020). "Work Efficient Parallel Algorithms for Predicate Detection." arXiv:2008.12516
- Garg, V.K. (2019). *Introduction to Lattice Theory with Computer Science Applications.* Wiley.
- Garg, V.K., Streit, R.P. (2024). "Parallel Algorithms for Equilevel Predicates." ICDCN.
- Streit, R.P., Garg, V.K. (2025). "Constrained Cuts, Flows, and Lattice-Linearity." arXiv:2512.18141
- Dilworth, R.P. (1950). "A decomposition theorem for partially ordered sets." Annals of Mathematics 51, 161–166.

### Hypercube and BSP parallelism
- Valiant, L.G. (1990). "A Bridging Model for Parallel Computation." CACM 33(8), 103–111.
- Valiant, L.G. (2010). "A Bridging Model for Multi-Core Computing." https://people.seas.harvard.edu/~valiant/bridging-2010.pdf
- Stout, Q.F., Wagar, B. (1980s+). Parallel algorithms for hypercube computers.
- MIT 6.895 (2003). Theory of Parallel Systems lecture notes on hypercubes. https://ocw.mit.edu/courses/6-895-theory-of-parallel-systems-sma-5509-fall-2003/

### Categorical foundations
- Joyal, A. (1986). "Foncteurs analytiques et espèces de structures." Lecture Notes in Mathematics 1234, 126–159.
- Gambino, N., Kock, J. (2013). "Polynomial functors and polynomial monads." Math Proc Camb Phil Soc 154(1), 153–192. arXiv:0906.4931
- Spivak, D.I., Niu, N. (2024). *Polynomial Functors: A Mathematical Theory of Interaction.* London Math Society Lecture Note Series 498. arXiv:2312.00990
- Fong, B., Spivak, D.I. (2019). *Seven Sketches in Compositionality.*

### Self-hosting compilers / dependently typed
- de Moura, L., Ullrich, S. (2021). "The Lean 4 Theorem Prover and Programming Language." CADE 28.
- Brady, E. (2016). "Elaborator reflection: Extending Idris in Idris." ICFP. https://www.type-driven.org.uk/edwinb/papers/elab-reflection.pdf

### Logic + Control duality
- Kowalski, R.A. (1979). "Algorithm = Logic + Control." CACM 22(7), 424–436.
- Hoare, C.A.R. (1969). "An axiomatic basis for computer programming." CACM 12(10), 576–580.
- Hoare, C.A.R., He, J. (1998). *Unifying Theories of Programming.* Prentice Hall.

### Constraint satisfaction
- Mackworth, A.K. (1977). "Consistency in Networks of Relations." AIJ 8(1).
- Mackworth, A.K., Freuder, E.C. (1985). "The complexity of some polynomial network consistency algorithms for constraint satisfaction problems." AIJ 25(1).

### Abstract interpretation / dataflow lattices
- Cousot, P., Cousot, R. (1977). "Abstract Interpretation: A Unified Lattice Model for Static Analysis of Programs by Construction or Approximation of Fixpoints." POPL.
- Cousot, P., Cousot, R. (1992). "Comparing the Galois Connection and Widening/Narrowing Approaches to Abstract Interpretation." PLILP.

### Project-internal references
- `/Users/avanti/dev/projects/prologos/.claude/rules/structural-thinking.md` — Hyperlattice Conjecture, SRE lattice lens.
- `/Users/avanti/dev/projects/prologos/.claude/rules/on-network.md` — Design mantra and on-network discipline.
- `/Users/avanti/dev/projects/prologos/docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md` — Hypercube as Boolean-lattice Hasse; ATMS worldview space.
- `/Users/avanti/dev/projects/prologos/docs/research/2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md` — Free-lattice / FL_V(X) framing for SRE cells; PUnify ↔ Whitman correspondence.
- `/Users/avanti/dev/projects/prologos/docs/research/2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md` — Per-variety capability map.

---

## Methodological caveats

1. **Search coverage is necessarily partial.** Web search depth was 25+ queries across 10 topics with rephrasing on the most novelty-sensitive (§8). Some directly relevant work in less-indexed venues (workshop papers, theses, technical reports in non-English literature) may exist and not surface. The "APPARENT NOVELTY" tags should be read as *no clear precedent located in this search*, not as proof of universal novelty.

2. **PDF binary content was not always extractable.** Direct WebFetch on Garg SPAA 2020, the LLP slides, and the LLP detection paper failed to extract readable text — they were verified via abstract / search-summary sources, not full-text reading. The Garg LLP framing is well-corroborated across multiple search summaries and adjacent papers, but exact quotation requires direct PDF inspection by a human or different tooling.

3. **The Garg LLP graded precedent matters more than this survey can fully explore.** A focused follow-up should:
   - Read Garg's 2019 *Introduction to Lattice Theory with Computer Science Applications* book to see how broadly Garg generalizes the LLP framework.
   - Compare Garg's "lattice-linear predicate" condition against Prologos's monotone-merge requirement.
   - Identify any computation that Garg's framework *cannot* express but Prologos C1 claims is still Hasse-decomposable.

4. **External review specifically wanted on §8.5 falsifiability questions.** The two questions formulated there — universal-scope precedent + counterexample — should be put to lattice-theory specialists (J.B. Nation, the Reading-Speyer-Thomas axis) and parallel-algorithm-theory specialists (Vijay Garg himself, Guy Blelloch's circle on parallel scheduling theory).

---

## Cross-references in the project

- The lattice-variety note's §5.3 already states a *graded* version of C1: "*The Hyperlattice Conjecture's optimality claim, restricted to a variety V where canonical form is computable, becomes a per-variety algebraic theorem rather than a structural conjecture.*" This is the project-internal acknowledgment that the universal claim needs grading.
- The lattice-hierarchy note (`2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md`) builds the per-variety capability map this survey corroborates.
- The hypercube addendum's §5 open question 4 explicitly asks: "How does this interact with the Hyperlattice Conjecture? ... is the hypercube the 'optimal structure' the conjecture predicts?" — open question, not closed.

The pattern: the project has internally framed the per-variety graded form correctly. The unified universal form is the unresolved frontier — appropriately tagged here as APPARENT NOVELTY.
