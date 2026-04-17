# Structural Thinking: SRE, Lattices, and the Hyperlattice Conjecture

> **"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."**

This document captures the structural reasoning framework that governs all architectural decisions in Prologos. It is not optional background — it is the lens through which every design choice is evaluated. The design mantra above is the operational form of the Hyperlattice Conjecture — what the conjecture demands of every line of code we write.

## The Hyperlattice Conjecture

**Every computable function is expressible as a fixpoint computation on lattices. The Hasse diagram of the lattice IS the optimal parallel decomposition of that computation.**

Two claims:
1. **Universality**: every computation → fixpoint on lattices. This is the mandate for putting everything on-network.
2. **Optimality**: the Hasse diagram provides the optimal parallel structure. This is the mandate for how we decompose computation.

The hypercube research (§2 of the addendum) provides the strongest evidence for claim 2: the ATMS worldview space IS the Boolean lattice Q_n, whose Hasse diagram IS the hypercube graph. The hypercube's adjacency structure directly gives us Gray code traversal (optimal CHAMP sharing), subcube pruning (O(1) nogood containment), and hypercube all-reduce (optimal BSP barriers). The parallel decomposition of the worldview exploration IS the Hasse diagram's adjacency structure.

This is not a metaphor. It is a structural identity.

## SRE Lattice Lens (6 Questions)

Every lattice in the system — every cell value, every merge function, every domain — MUST be analyzed through the SRE lattice lens. The 6 questions are codified in CRITIQUE_METHODOLOGY.org:

### Q1: Classification — VALUE or STRUCTURAL?

- **VALUE lattice**: the cell holds a single evolving value (type, constraint, answer set). Information refines monotonically.
- **STRUCTURAL lattice**: the cell holds a compound structure where components evolve independently (scope-cell, decisions-state, commitments-state). The lattice is a product of component lattices.

### Q2: Algebraic Properties

What algebraic structure does the lattice have?

| Property | Implication |
|---|---|
| Boolean | Complementable — can express negation |
| Distributive | Meet distributes over join — composition is well-behaved |
| Heyting | Implication operator — can express conditional refinement |
| Join-semilattice | Only joins (no meets needed) — CALM-safe, coordination-free |

Most of our lattices are join-semilattices (monotone accumulation). This is by design — CALM theorem guarantees coordination-free execution for monotone computations.

### Q3: Bridges to Other Lattices

How does this lattice compose with others? Every bridge between lattices is a Galois connection (left adjoint preserves joins). Bridges define information flow paths:

- Decision cells → worldview cache (projection: OR of committed bits)
- Table cell → consumer query (projection: filter by ground args, project free args)
- Scope cell → table entry (identity: scope IS the answer)

When two lattices need to communicate, define the Galois connection. If you can't, the bridge is not well-typed.

### Q4: Composition — Full Bridge Diagram

Draw the full bridge diagram showing ALL lattices in the design and ALL bridges between them. Composition of bridges must be type-correct (Galois connections compose).

### Q5: Primary vs Derived

Which lattice is PRIMARY (the authoritative source) and which is DERIVED (a projection/cache)?

- Decision cells are PRIMARY → worldview cache is DERIVED
- Table cells are PRIMARY → consumer results are DERIVED
- Scope cells are PRIMARY → table entries are copies

Derived lattices can be recomputed from primary. Primary lattices cannot be derived from anything.

### Q6: Hasse Diagram — The Optimality Argument

**What is the Hasse diagram of this lattice?**

This is the most important question. The Hasse diagram reveals:

1. **Adjacency metric**: which elements are "one step apart." This determines the optimal traversal order (Gray code = Hamiltonian path on the Hasse diagram).

2. **Recursive decomposition**: how the lattice factors into sub-lattices. This IS the parallel decomposition — independent sub-lattices can be computed concurrently.

3. **Diameter**: the maximum distance between any two elements. This bounds the computation depth (number of BSP rounds to reach fixpoint).

4. **Subcube structure**: for Boolean lattices, nogoods identify subcubes (prunable subgraphs). Subcube membership is an O(1) bitmask check.

The Hasse diagram IS the computation's parallel structure. The nodes are states. The edges are single refinement steps. A path through the diagram IS a computation trace. The optimal parallel execution IS the shortest set of paths that covers all reachable nodes.

**This strengthens the Hyperlattice Conjecture's optimality claim**: if the Hasse diagram IS the parallel decomposition, and the Hasse diagram is uniquely determined by the lattice, then the lattice uniquely determines the optimal parallel decomposition. The computation's parallel structure is not a design choice — it is a structural property of the lattice.

## Module Theory of Lattices

A collection of lattices with morphisms between them forms a MODULE. The module structure governs:

1. **Tabled relations**: each relation defines a morphism (input bindings → output bindings). The collection of all tabled relations is a product module. Fixpoint on the product = independent per-component fixpoints (for non-recursive case).

2. **Clause execution**: each clause is a morphism. The relation is the coproduct (join) of all clause morphisms. Tabling memoizes the coproduct.

3. **Solver infrastructure**: the compound cells (decisions-state, commitments-state, scope-cell) are modules over the propagator network. The network's fixpoint computes the module's least fixpoint.

4. **Self-hosting**: the compiler's registries (module, relation, trait) form a module of modules. Information about the language's structure IS lattice-valued information flowing through cells.

### Direct Sum Has Two Realizations — Prefer Tagging Over Bridges

A direct sum decomposition R = C₁ ⊕ C₂ ⊕ ... ⊕ Cₙ is an algebraic fact. Its *realization* on the propagator network is a design choice. There are two:

**Realization (A): Separate cells with bridge morphisms.** Each Cᵢ is its own cell. Bridges propagate values between them via morphisms. Worldview-filtered reads during speculation COLLAPSE tagged entries on the bridge — the bridge sees only the merged value at the current worldview, losing per-branch identity. **This is a real failure mode**, not theoretical — BSP-LE Track 2B Phase 2a fought 3 design iterations (D.9 probe, D.10 bitmask, D.11 stratified) before recognizing that bridges were the root cause.

**Realization (B): Bitmask-tagged layers on a shared carrier cell.** One cell holds all components; each component's identity is a bitmask tag in the value's tagged-cell-value entries. Reconciliation is automatic through the cell's merge function. No bridges, no tag collapse.

**Heuristic**: when designing "bridges between X cells," always ask — *is there a shared-carrier-with-tagging realization?* For value-level decomposition with worldview semantics, realization (B) is structurally simpler AND eliminates the tag-collapse bug class. Bridges are the right answer only when the Cᵢ carry genuinely different types or live at different strata.

**Exemplar (Track 2B Phase 2a "Resolution B")**: clause params share the query scope cell directly. Instead of clause-scope cells + bridges to query-scope, all clause variables are bitmask-tagged layers on the shared query-scope carrier. The module decomposition (relation = coproduct of clauses) is realized by tagging, not by bridges. Reference: `.claude/rules/on-network.md`, Track 2B PIR §6.3, §12.2, §16.4.

## Structural Unification (PUnify)

Structural unification is a lattice MEET operation. Two tree-shaped values are unified by computing the greatest lower bound in the tree lattice.

PUnify compositions:
- **With tagged-cell-value**: unification propagators during speculation are bitmask-tagged. Their writes are tagged with the branch's worldview. Reconciliation between branches is SRE structural unification.
- **With scope cells**: scope cells ARE substitutions. Unification writes to specific components. The merge handles per-variable composition.
- **With table consumers**: consumer matching IS structural unification — matching a query pattern against table entries.

## Retraction as Lattice Narrowing

Retraction is NOT imperative removal. It is lattice narrowing:
- `current-elements ∩ viable-elements = narrowed-elements`
- Dependents set under ⊇ is a lattice; cleanup = intersection with viable set
- Decision cell narrowing IS retraction — removing an alternative narrows the domain

The S(-1) stratum handles non-monotone retraction by expressing it as lattice narrowing on metadata (dependents, provenance tags, trace entries). This pattern generalizes: any accumulated metadata can be retracted via intersection with a viability set.

## Design Discipline

When designing any new feature or infrastructure:

1. **Identify the lattice**: what IS the value? What is bot? What is the merge (join)?
2. **Run the 6 SRE questions**: classification, properties, bridges, composition, primary/derived, Hasse diagram.
3. **Check the Hasse diagram**: does the parallel decomposition match the Hasse structure? If not, the design fights the lattice.
4. **Verify CALM safety**: is the merge monotone? If yes, coordination-free by theorem. If not, which non-monotone steps exist and are they isolated at stratum boundaries?
5. **Check on-network**: is this a cell? Is the merge well-defined? Can the bridge be expressed as a propagator?
6. **Check module composition**: does this compose with existing lattices? Are the bridges Galois connections?
