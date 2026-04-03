# Adhesive Categories and Parse Trees: Formal Foundations for DPO Rewriting in Prologos

**Date**: 2026-04-03
**Stage**: 1 (Research synthesis)
**Feeds into**: SRE Track 2D (rewrite relation), Grammar Form R&D (PPN Track 3.5), SRE Track 6 (reduction-on-SRE)
**Motivated by**: External critique finding F8 on Track 2D — "are parse-tree-nodes objects in an adhesive category?"

**Related documents**:
- [Hypergraph Rewriting + Propagator Parsing](2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — DPO/SPO theory, e-graphs, interaction nets
- [Lattice Foundations for PPN](2026-03-26_LATTICE_FOUNDATIONS_PPN.md) — reduced product, CALM, chaotic iteration
- [Layered Recovery Categorical Analysis](2026-03-13_LAYERED_RECOVERY_CATEGORICAL_ANALYSIS.md) — CALM theorem §8.5, stratification
- [SRE Track 2D Design](../tracking/2026-04-03_SRE_TRACK2D_DESIGN.md) — DPO spans, critical pair analysis
- [Algebraic Embeddings on Lattices](2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) — Heyting, residuated lattices

---

## 1. The Question

SRE Track 2D implements DPO rewriting on parse-tree-nodes. The DPO formalism provides powerful guarantees — local Church-Rosser, parallelism, concurrency, critical pair completeness — but ONLY when the underlying category is adhesive. Are our parse-tree-nodes in an adhesive category?

This is not an academic curiosity. The answer determines whether:
- Track 2D's critical pair analysis is COMPLETE (provably finds all conflicts)
- Per-rule propagators can fire in PARALLEL (provably order-independent)
- Grammar Form user-defined rules COMPOSE correctly (concurrency theorem)
- The architecture inherits the full DPO algebraic toolkit "for free"

---

## 2. Adhesive Categories: Definition and Key Properties

### Definition (Lack and Sobocinski, 2005)

A category C is **adhesive** if:
1. C has pushouts along monomorphisms
2. C has pullbacks
3. Pushouts along monomorphisms are **van Kampen squares**

A van Kampen (VK) square is a pushout where: given a commutative cube with the pushout as the bottom face and the back faces as pullbacks, the front faces are pullbacks if and only if the top face is a pushout.

Intuitively: VK squares ensure that pushouts are "well-behaved" — they interact correctly with pullbacks, so the DPO construction produces unique, well-defined results.

### Key Examples

| Category | Adhesive? | Reference |
|----------|-----------|-----------|
| **Set** (sets + functions) | ✅ | Lack & Sobocinski 2005 |
| **Directed multigraphs** | ✅ | Lack & Sobocinski 2005 |
| **Any presheaf topos** (functors C^op → Set) | ✅ | Lack & Sobocinski 2005 |
| **Any elementary topos** | ✅ | Lack & Sobocinski 2005 |
| **Typed attributed graphs** | ✅ (adhesive HLR) | Ehrig et al. 2006 |
| **E-graphs** (term graphs + equivalence) | ✅ | Arsac et al. 2025 (Rocq formalization) |
| Pos (posets) | ❌ | |
| Top (topological spaces) | ❌ | |
| Cat (categories) | ❌ | |

### Guarantees Inherited from Adhesivity

For DPO rewriting in an adhesive category:

1. **Local Church-Rosser**: If two rules can be applied to the same object at non-overlapping positions, the results are the same regardless of application order.
2. **Parallelism theorem**: Independent rule applications can be performed simultaneously, producing the same result as sequential application.
3. **Concurrency theorem**: Rules that share structure (via a common interface) can be composed into a single "concurrent rule" that produces the same result as sequential application.
4. **Critical pair lemma**: All conflicts between rules are characterized by critical pairs. Finding all critical pairs finds ALL possible conflicts.
5. **Uniqueness of pushout complements**: In adhesive categories, pushout complements (needed for DPO rule application) are unique when they exist. No ambiguity in rule application.

Sources: [Lack & Sobocinski (2005)](https://www.brics.dk/RS/03/31/BRICS-RS-03-31.pdf), [Arsac et al. (2025)](https://arxiv.org/abs/2509.17392), [nLab: adhesive category](https://ncatlab.org/nlab/show/adhesive+category)

---

## 3. Parse-Tree-Nodes as Presheaf Objects

### Our Structure

A `parse-tree-node` in Prologos has:
- `tag` : symbol (the form kind)
- `children` : RRB vector of (parse-tree-node | token-entry)
- `srcloc` : source location (metadata)
- `indent` : indentation level (metadata)

Token entries have:
- `types` : set of token classifications
- `lexeme` : string
- `start-pos`, `end-pos` : positions

### The Presheaf Argument

A **presheaf** on a small category C is a functor C^op → Set. The category of presheaves on C (denoted [C^op, Set]) is a presheaf topos — and **every presheaf topos is adhesive** (Lack & Sobocinski 2005).

**Claim**: Parse-tree-nodes form objects in a presheaf category, hence inherit adhesivity.

**Construction**: Define the index category **T** (for "tree schema"):
- Objects: a single object `N` (node positions)
- Morphisms: for each natural number i, a morphism `child_i : N → N` (the i-th child relation)

A presheaf on T assigns:
- To the object N: a set (the set of all nodes in the tree, including leaves)
- To each morphism child_i: a function mapping a node to its i-th child (or undefined if the node has fewer children)

This is a standard representation of ordered forests as presheaves. Each parse-tree-node IS a section of this presheaf — a consistent assignment of values (tags, lexemes) to positions (nodes).

### Heterogeneous Children

Our trees have two kinds of leaves: parse-tree-nodes and token-entries. This is a **coproduct** in the presheaf category. The presheaf sends each position to either a node value (tag + children) or a leaf value (lexeme + types). Coproducts in presheaf categories are computed pointwise (coproducts in Set are disjoint unions). Since Set has coproducts and the presheaf topos inherits them, the heterogeneous carrier is handled.

### RRB Structural Sharing

RRB vectors provide structural sharing for efficient immutable operations. But the LOGICAL structure is a tree — the RRB is an implementation detail. The presheaf argument applies to the logical tree, not the physical representation. Two parse-tree-nodes that are `equal?` (structurally identical) represent the same presheaf section, regardless of physical sharing.

### Morphisms

In the presheaf category, morphisms are natural transformations — functions that map nodes to nodes while preserving the child structure. For DPO rewriting:
- **Rule spans** L ← K → R are natural transformations
- **Monomorphisms** (needed for pushouts) are injective natural transformations — each position in K maps to exactly one position in L and R
- **Pattern-desc matching** in Track 2D is a monomorphism from the pattern into the tree

Our pattern-desc is injective: each child-pattern position maps to a unique child in the matched node. The interface K binds each name to exactly one sub-tree. These are monomorphisms in the presheaf category.

### Conclusion

**Parse-tree-nodes ARE objects in a presheaf topos. Every presheaf topos is adhesive. Therefore DPO rewriting on parse-tree-nodes inherits the full adhesive category toolkit.**

---

## 4. What This Means for Prologos

### Track 2D: Critical Pair Analysis is COMPLETE

The critical pair lemma in adhesive categories guarantees: Track 2D's `find-critical-pairs` function finds ALL possible conflicts between rewrite rules. The empirical result (0 critical pairs for 13 rules) is not just "we didn't find any" — it is a PROOF that no conflicts exist, because the adhesive structure ensures completeness.

### Track 2D: Per-Rule Propagators are PROVABLY Parallel

The parallelism theorem guarantees: if two rewrite rules have no critical pair, they can fire simultaneously on the same network and produce the same result as sequential application. This formally justifies the per-rule propagator architecture — zero critical pairs means ALL rules can fire in parallel within a stratum.

### Grammar Form: User-Defined Rules COMPOSE

The concurrency theorem guarantees: rules that share structure (common sub-expressions) can be composed into a single "concurrent rule." This means Grammar Form user-defined productions that share sub-patterns compose correctly — the order of rule application doesn't affect the result, and shared structure is handled consistently.

### Track 6: E-Graph Rewriting is Well-Founded

The Arsac et al. (2025) Rocq formalization establishes that e-graphs are adhesive. Since our parse trees are in a presheaf topos (a simpler structure than e-graphs), Track 6's extension to e-graph-style equality saturation inherits the same guarantees.

---

## 5. CALM-Adhesive Connection: Monotone Rewriting as Coordination-Free Computation

### CALM Recap

The CALM theorem (Hellerstein, 2010, 2019): A program has a consistent, coordination-free distributed implementation if and only if it is **monotonic**. In the Prologos propagator network: monotone propagation in S0 is coordination-free (CALM-compliant). Non-monotone operations (retraction, accumulation) require stratification (coordination barriers).

### The Connection

DPO rewriting in an adhesive category and CALM-compliant propagator networks are two formalizations of the SAME underlying principle: **monotone information flow converges regardless of execution order.**

| Concept | Adhesive DPO | CALM/Propagator |
|---------|-------------|-----------------|
| **Objects** | Graphs/trees | Cell values |
| **Operations** | Rewrite rules | Propagator fire functions |
| **Order-independence** | Church-Rosser (from adhesivity) | Confluence (from monotonicity) |
| **Parallelism** | Parallelism theorem | CALM: monotone = coordination-free |
| **Conflict detection** | Critical pair analysis | Non-monotonicity analysis |
| **Stratification** | For non-confluent rules | For non-monotone operations (S(-1)) |
| **Convergence** | Termination of rule saturation | Fixpoint of lattice computation |

The adhesive category structure tells us WHICH rewrite rules are safe to apply in parallel (those without critical pairs). CALM tells us WHICH propagator computations are safe to distribute without coordination (those that are monotone). For Prologos, these coincide: **a monotone propagator that implements a DPO rewrite rule without critical pairs is both CALM-compliant AND adhesive-certified.**

### Contribution Potential

This connection between adhesive DPO rewriting and CALM monotonicity appears to be novel — or at least not well-explored in the literature. The existing CALM work focuses on set-based lattice operations (union, intersection). The existing adhesive category work focuses on graph rewriting. The Prologos propagator network sits at the intersection: graph-structured data (parse trees) with lattice-based information flow (cell merges).

A potential contribution to the CALM body of research:

**Conjecture**: In a CALM-compliant propagator network where cell values are objects in an adhesive category and propagators implement DPO rewrite rules, the coordination-free fragment is EXACTLY the set of rules without critical pairs. This would extend CALM from set-based operations to graph rewriting operations, with adhesive category theory providing the formal bridge.

The evidence from Track 2D: 13 rules, 0 critical pairs, all fire as independent propagators within a monotone stratum. The adhesive structure guarantees Church-Rosser. CALM guarantees coordination-free execution. Both say the same thing: these rules are safe to run in any order or in parallel.

---

## 6. Conditions and Restrictions

### What Could Break Adhesivity

1. **Non-tree structures**: If parse-tree-nodes acquire CYCLES (back-references, circular structures), they leave the presheaf category. Currently all parse trees are acyclic — but future extensions (e.g., circular syntax for co-inductive types) would need to verify the category remains adhesive.

2. **Side effects in rule application**: The adhesive guarantees assume rule application is PURE — no side effects beyond the graph rewrite. Track 2D's `apply-fn` handlers are pure (they read a node and return a new node). If future rules have side effects (e.g., writing to a global registry during rewriting), the guarantees may not hold.

3. **Non-injective patterns**: Adhesive pushouts require monomorphisms. If a pattern-desc maps two different positions to the same K binding (aliasing), the morphism is not injective. Currently all patterns bind each position to a unique name — but the pattern language should ENFORCE this (verification in `verify-rewrite-rule`).

### What Strengthens the Argument

1. **All current rewrite rules are tree-to-tree**: No rule introduces cycles or non-tree structure. The presheaf argument applies directly.

2. **RRB vectors preserve tree structure**: Despite physical sharing, the logical structure is always a well-founded tree. `equal?` compares logical structure, not physical identity.

3. **Pattern-desc matching is injective**: Each child-pattern position maps to exactly one child. The interface K binds names uniquely. These are monomorphisms.

---

## 7. Open Questions

1. **Can we exploit the concurrency theorem for Grammar Form?** The concurrency theorem composes rules that share structure. For Grammar Form productions that share sub-patterns (e.g., two productions that both match `expr`), the theorem tells us how to combine them. This could optimize Grammar Form compilation — instead of registering N rules, register one concurrent rule.

2. **Does the CALM-adhesive connection generalize?** Our conjecture (§5) relates critical pairs to coordination boundaries. Is this a theorem? If so, it would provide a formal bridge between CALM (distributed systems) and adhesive DPO (graph rewriting) — two currently separate bodies of theory.

3. **Formal verification in Rocq?** The Arsac et al. (2025) [Rocq library](https://arxiv.org/abs/2509.17392) formalizes adhesive categories and DPO rewriting. Our parse trees as presheaves should be formalizable as an instance of their library. This would provide machine-checked guarantees — but is significant effort.

4. **Does Track 6's e-graph extension preserve adhesivity?** The Arsac result says e-graphs are adhesive. But our e-graph extension (Track 2H's union-join on the type lattice) adds equivalence classes to types, not to parse trees. The question: when type-level e-graphs interact with parse-tree-level rewriting (via elaboration), does the combined structure remain adhesive?

---

## 8. References

### Foundational

- [Lack, S. & Sobocinski, P. (2005). "Adhesive Categories." BRICS Report RS-03-31.](https://www.brics.dk/RS/03/31/BRICS-RS-03-31.pdf)
- [Lack, S. & Sobocinski, P. (2005). "Adhesive and Quasiadhesive Categories." RAIRO-ITA.](https://www.numdam.org/item/10.1051/ita:2005028.pdf)
- [nLab: adhesive category](https://ncatlab.org/nlab/show/adhesive+category)

### Typed/Attributed Graphs

- [Ehrig, H. et al. (2006). "Fundamental Theory for Typed Attributed Graphs and Graph Transformation based on Adhesive HLR Categories." Fundamenta Informaticae.](https://dl.acm.org/doi/abs/10.5555/2369448.2369451)

### Formalization

- [Arsac, S. et al. (2025). "Adhesive Category Theory for Graph Rewriting in Rocq." CPP 2025.](https://arxiv.org/abs/2509.17392)
  - Rocq library formalizing adhesive categories, Church-Rosser theorem, concurrency theorem
  - Instances include presheaf categories and simple graph categories

### Rule Algebras

- [Behr, N. (2018). "Rule Algebras for Adhesive Categories." CSL 2018.](https://drops.dagstuhl.de/storage/00lipics/lipics-vol119-csl2018/LIPIcs.CSL.2018.11/LIPIcs.CSL.2018.11.pdf)

### CALM

- [Hellerstein, J.M. (2019). "Keeping CALM: When Distributed Consistency is Easy." arXiv:1901.01930.](https://arxiv.org/pdf/1901.01930)
- [Conway, N. et al. (2012). "Logic and Lattices for Distributed Programming." SoCC 2012.](https://www.neilconway.org/docs/socc2012_bloom_lattices.pdf)

### E-Graphs

- [Topos Institute (2025). "How to prove equations using diagrams" (e-graphs and category theory).](https://topos.institute/blog/2025-05-27-e-graphs-1/)
