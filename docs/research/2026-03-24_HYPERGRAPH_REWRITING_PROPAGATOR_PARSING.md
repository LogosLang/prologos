# Hypergraph Rewriting, Propagator Parsing, and Graph Transformation

**Stage**: 0/1 Research Synthesis
**Date**: 2026-03-24
**Scope**: Landscape survey connecting hypergraph grammars, attribute grammar evaluation, graph rewriting, and propagator-based parsing to the Prologos infrastructure

---

- [1. Context-Free Hypergraph Grammars](#1-context-free-hypergraph-grammars)
  - [1.1 HR Grammars and the Generalization of CFGs](#11-hr-grammars-and-the-generalization-of-cfgs)
  - [1.2 The Engelfriet-Heyker Theorem](#12-the-engelfriet-heyker-theorem)
  - [1.3 Courcelle's Theorem and Decidability](#13-courcelles-theorem-and-decidability)
  - [1.4 Key Researchers and Lineage](#14-key-researchers-and-lineage)
- [2. Attribute Grammars as Propagator Networks](#2-attribute-grammars-as-propagator-networks)
  - [2.1 Synthesized and Inherited as Bidirectional Flow](#21-synthesized-and-inherited-as-bidirectional-flow)
  - [2.2 Circular Attribute Grammars and Lattice Fixpoints](#22-circular-attribute-grammars-and-lattice-fixpoints)
  - [2.3 Silver and Extensible Attribute Grammars](#23-silver-and-extensible-attribute-grammars)
  - [2.4 The Propagator Correspondence](#24-the-propagator-correspondence)
- [3. Graph Rewriting Systems](#3-graph-rewriting-systems)
  - [3.1 Double-Pushout (DPO) and Single-Pushout (SPO)](#31-double-pushout-dpo-and-single-pushout-spo)
  - [3.2 Adhesive Categories](#32-adhesive-categories)
  - [3.3 E-Graphs Are Adhesive](#33-e-graphs-are-adhesive)
  - [3.4 Connection to Term Rewriting](#34-connection-to-term-rewriting)
- [4. Parsing as Incremental Information Accumulation](#4-parsing-as-incremental-information-accumulation)
  - [4.1 Chart Parsing as Fixpoint Computation](#41-chart-parsing-as-fixpoint-computation)
  - [4.2 Semiring Parsing](#42-semiring-parsing)
  - [4.3 GLL/GLR and Parse Forests as Ambiguity Lattices](#43-gllglr-and-parse-forests-as-ambiguity-lattices)
  - [4.4 Incremental Parsing via Propagation](#44-incremental-parsing-via-propagation)
- [5. Interaction Nets and Geometry of Interaction](#5-interaction-nets-and-geometry-of-interaction)
  - [5.1 Lafont's Interaction Nets](#51-lafonts-interaction-nets)
  - [5.2 Geometry of Interaction](#52-geometry-of-interaction)
  - [5.3 HVM and Practical Interaction Nets](#53-hvm-and-practical-interaction-nets)
  - [5.4 Connection to Propagator Networks](#54-connection-to-propagator-networks)
- [6. Applications to Compiler Infrastructure](#6-applications-to-compiler-infrastructure)
  - [6.1 Collapsing the Pipeline](#61-collapsing-the-pipeline)
  - [6.2 Graph Rewriting for Optimization](#62-graph-rewriting-for-optimization)
  - [6.3 Provenance and Proof Objects](#63-provenance-and-proof-objects)
  - [6.4 Incremental Compilation via Propagation](#64-incremental-compilation-via-propagation)
  - [6.5 E-Graphs as Persistent Compiler Abstraction](#65-e-graphs-as-persistent-compiler-abstraction)
- [7. Connection to Existing Prologos Infrastructure](#7-connection-to-existing-prologos-infrastructure)
  - [7.1 Hypergraph Rewriting IS Structural Decomposition (SRE)](#71-hypergraph-rewriting-is-structural-decomposition-sre)
  - [7.2 Definitional Trees as Graph Rewrite Strategies (NF-Narrowing)](#72-definitional-trees-as-graph-rewrite-strategies-nf-narrowing)
  - [7.3 Typing Graph Rewrite Rules (NTT)](#73-typing-graph-rewrite-rules-ntt)
  - [7.4 Track 9 and the Reduction-as-Propagators Vision](#74-track-9-and-the-reduction-as-propagators-vision)
- [8. How This Changes Our Thinking](#8-how-this-changes-our-thinking)
  - [8.1 Does Parsing on the Network Eliminate the Multi-Pass Pipeline?](#81-does-parsing-on-the-network-eliminate-the-multi-pass-pipeline)
  - [8.2 Does Graph Rewriting Subsume the SRE?](#82-does-graph-rewriting-subsume-the-sre)
  - [8.3 What Would a "Parsing Series" Look Like?](#83-what-would-a-parsing-series-look-like)
  - [8.4 How Does This Connect to Self-Hosting?](#84-how-does-this-connect-to-self-hosting)
- [9. Open Questions](#9-open-questions)
- [10. References](#10-references)

---

## 1. Context-Free Hypergraph Grammars

### 1.1 HR Grammars and the Generalization of CFGs

Hyperedge replacement (HR) grammars generalize context-free grammars from strings to hypergraphs. Where a CFG rewrites nonterminal symbols within a string, an HR grammar rewrites labeled hyperedges within a hypergraph. The production rules replace a single hyperedge (the "handle") with an arbitrary hypergraph fragment, preserving external attachment points --- analogous to how a CFG nonterminal has a defined position in the sentential form.

The key structural insight: just as CFGs generate trees (derivation trees) that can be read off as strings (yields), HR grammars generate derivation trees whose yields are hypergraphs. This tree-structured derivation is what makes HR grammars "context-free" --- each production applies independently of surrounding context, exactly as in the string case.

HR grammars generate languages of hypergraphs with decidable emptiness, membership (for graphs of bounded treewidth), and several closure properties inherited from the CFG case. The "pumping lemma" for HR languages parallels the string CFG pumping lemma: derivation trees of sufficient depth must contain repeated nonterminals, allowing sub-derivation extraction and iteration.

Habel and Kreowski established foundational structural results on HR languages, characterizing them through both algebraic (initial algebra semantics) and automata-theoretic (hypergraph automata) frameworks. Their "jungle evaluation" model --- where functional expressions are represented as acyclic hypergraphs and evaluation proceeds by hypergraph rewriting --- foreshadows the connection between graph rewriting and term reduction that is central to our interests.

### 1.2 The Engelfriet-Heyker Theorem

The Engelfriet-Heyker theorem (1992) establishes a precise equivalence: **context-free hypergraph grammars generate exactly the same class of term languages as attribute grammars**. This is a deep result connecting two seemingly different formalisms:

- HR grammars are a *generative* formalism: they build structure bottom-up through production application.
- Attribute grammars are an *analytic* formalism: they decorate existing parse trees with computed values.

The theorem says that the set of terms (trees) that can be generated by any HR grammar is exactly the set of terms that can be computed as the value of a designated attribute in some attribute grammar. The proof works by showing that the derivation tree of an HR grammar, when projected to its term yield, can be simulated by an attribute grammar that passes partial hypergraph descriptions as attribute values --- and conversely, that attribute grammar output trees can be generated by an HR grammar whose productions encode the attribute computations.

This equivalence has a profound implication for Prologos: **if our propagator network already implements attribute grammar evaluation (which it does, as we argue in Section 2), then it implicitly has the power of hypergraph grammar generation**. The type-level and value-level structures we compute on the network are elements of an HR-generated hypergraph language.

### 1.3 Courcelle's Theorem and Decidability

Courcelle's theorem provides the decidability foundation: any property expressible in monadic second-order logic (MSO2) --- which allows quantification over sets of vertices and edges --- can be decided in linear time on graphs of bounded treewidth. Since HR-generated graphs have bounded treewidth (the treewidth is bounded by the maximum rank of hyperedges in the grammar), this gives us:

- **Membership testing** for HR languages is decidable (and linear-time for fixed grammar).
- **MSO2-definable properties** of generated graphs are decidable.
- The proof works via tree automata: MSO2 formulas over bounded-treewidth graphs compile to finite-state tree automata that run over tree decompositions.

The practical implication: if our propagator-generated type structures stay within bounded treewidth (which they do, since type constructors have fixed arity), then a large class of static analyses over those structures are automatically decidable. This is not merely theoretical --- it means that certain whole-program analyses that seem intractable can be reduced to tree automaton problems.

### 1.4 Key Researchers and Lineage

- **Bruno Courcelle**: MSO logic on graphs, the Courcelle theorem, recognizable graph languages. His 1990 foundational paper established the MSO-treewidth connection.
- **Joost Engelfriet**: The Engelfriet-Heyker theorem, tree transducers, connections between automata on strings/trees/graphs. Systematic bridge-building between the word/tree/graph hierarchy.
- **Annegret Habel and Hans-Jorg Kreowski**: Structural properties of HR languages, jungle evaluation, algebraic characterizations. The graph-rewriting-as-computation perspective.
- **Frank Drewes**: Surveys and textbook treatment of HR grammars, connections to tree adjoining grammars.

## 2. Attribute Grammars as Propagator Networks

### 2.1 Synthesized and Inherited as Bidirectional Flow

Knuth's attribute grammars (1968) attach semantic rules to each production of a context-free grammar. Attributes come in two flavors:

- **Synthesized attributes**: computed from children, flowing *up* the parse tree. Example: the type of an expression is synthesized from the types of its subexpressions.
- **Inherited attributes**: computed from parent and siblings, flowing *down* the parse tree. Example: the type environment available at a node is inherited from its enclosing scope.

This bidirectional flow is exactly what a propagator network provides. In the Prologos elaborator today:

| Attribute Grammar Concept | Propagator Network Analog |
|---------------------------|--------------------------|
| Synthesized attribute | Cell whose value is determined by child cells via propagators |
| Inherited attribute | Cell whose value is determined by parent/sibling cells via propagators |
| Semantic rule | Propagator function |
| Attribute dependency graph | Propagator dependency graph |
| Attribute evaluation order | Propagator firing schedule |

The difference: attribute grammars require a fixed evaluation order (typically determined by a topological sort of the dependency graph per production), while propagator networks fire opportunistically as information becomes available. The propagator model is strictly more general --- it naturally handles the cases where evaluation order is not statically determinable.

### 2.2 Circular Attribute Grammars and Lattice Fixpoints

Standard attribute grammars require that the dependency graph be acyclic --- each attribute can be computed exactly once in dependency order. Circular attribute grammars (CAGs) relax this requirement, allowing cycles provided that:

1. Attribute values are drawn from a lattice of finite height.
2. All semantic functions involved in cycles are monotonic.
3. Evaluation iterates to a fixpoint.

The evaluation algorithm partitions the attribute dependency graph into strongly connected components (SCCs), topologically sorts the SCCs, and within each cyclic SCC iterates until convergence. This is precisely a lattice-based fixpoint computation --- the same mathematical object that underlies propagator network quiescence.

The connection is not merely analogous. CAG evaluation *is* propagator evaluation restricted to tree-structured dependency graphs. Our propagator network generalizes this by:

- Allowing arbitrary (non-tree) dependency topologies.
- Supporting multiple lattices (type lattice, usage lattice, constraint lattice) interacting in a single network.
- Providing stratified quiescence (S(-1), S0, S1, S2) to handle non-monotonic operations at stratum boundaries.

The Magnusson-Hedin work on Circular Reference Attributed Grammars (CRAGs) further extended this to allow references (pointers) between tree nodes, creating effectively a graph-structured dependency pattern. This is essentially what our cross-module dependency edges (Track 5) provide.

### 2.3 Silver and Extensible Attribute Grammars

Silver, developed by the MELT group at the University of Minnesota, is the most mature modern attribute grammar system. It supports:

- **Higher-order attributes**: attributes whose values are themselves decorated trees, enabling grammar composition.
- **Reference attributes**: attributes that point to other tree nodes, creating graph structures.
- **Forwarding**: a production can "forward" to another production's semantics, enabling modular language extension.
- **Collection attributes**: attributes that accumulate contributions from multiple sources.

Silver's forwarding mechanism is particularly interesting for Prologos. In Silver, a language extension can add new syntax that "forwards" to existing syntax for its semantics. This is analogous to how our elaborator desugars surface syntax into core AST --- but in Silver, the forwarding is part of the attribute grammar itself, not a separate pre-pass. This hints at how parsing and elaboration could be unified on a single propagator network.

Silver's collection attributes --- where multiple rules contribute to a single accumulated value --- are the attribute grammar analog of our propagator cells with multiple writers. The lattice-merge semantics are identical.

### 2.4 The Propagator Correspondence

Drawing these threads together, we can state the correspondence precisely:

**Theorem (informal)**: The evaluation of a (possibly circular) attribute grammar over a parse tree is equivalent to the quiescence of a propagator network where:
- Each attribute instance becomes a cell.
- Each semantic rule becomes a propagator.
- Tree structure determines wiring topology.
- Monotonic attribute computation corresponds to monotonic cell updates.
- Circular attribute evaluation corresponds to fixpoint iteration to quiescence.

The Prologos propagator network already implements the general case. The question this research raises is not "can we do attribute grammar evaluation?" but rather "can we formalize what we already do as an attribute grammar, and thereby import the decidability and composability results from AG theory?"

## 3. Graph Rewriting Systems

### 3.1 Double-Pushout (DPO) and Single-Pushout (SPO)

Graph rewriting provides the operational semantics for graph transformation. The two classical algebraic approaches differ in how they handle deletion:

**Double-Pushout (DPO)**: A rewrite rule is a span `L <- K -> R` where `L` is the left-hand side pattern, `R` is the right-hand side replacement, and `K` is the interface (the part preserved). Application requires two pushout squares in the category of graphs:

```
    L <-- K --> R
    |     |     |
    v     v     v
    G <-- D --> H
```

The "context graph" `D` must exist (the "dangling condition") --- you cannot delete a node that has edges not covered by the rule. This makes DPO well-behaved: rules are reversible, parallelism and confluence can be analyzed via critical pairs.

**Single-Pushout (SPO)**: A rewrite rule is a partial morphism `L --> R`. Application uses a single pushout, and dangling edges are implicitly deleted. SPO is more permissive but less well-behaved --- not all rules are reversible, and confluence analysis is harder.

For Prologos, the DPO approach is more natural because:
- Our propagator network already has a notion of "interface" (the attachment cells of a structural decomposition).
- Reversibility of DPO rules aligns with bidirectional propagation.
- The critical pair analysis for DPO gives us a formal tool for detecting conflicting optimizations.

### 3.2 Adhesive Categories

Adhesive categories (Lack and Sobocinski, 2005) axiomatize the categorical properties needed for DPO rewriting to work well. A category is adhesive if pushouts along monomorphisms exist and satisfy a "van Kampen" condition that ensures pushout squares compose well.

Key examples of adhesive categories:
- **Sets** (trivially).
- **Graphs** (the classical case).
- **Typed graphs** (graphs with a type morphism to a type graph).
- **Hypergraphs** (the case we care about).
- **Presheaf categories** over any small category.

The practical consequence: any formalism that lives in an adhesive category gets the full DPO rewriting theory "for free" --- local Church-Rosser, parallelism, concurrency, and critical pair analysis. Recent work (2025) has formalized adhesive category theory in the Rocq proof assistant, providing machine-checked foundations.

### 3.3 E-Graphs Are Adhesive

A breakthrough result from Biondo, Castelnovo, and Gadducci (CALCO 2025) establishes that **e-graphs form an adhesive category**. E-graphs --- the data structure underlying equality saturation --- can be defined as acyclic term graphs with an equivalence relation on nodes, closed under the operators of the signature.

The adhesiveness result means that:
- DPO rewriting rules over e-graphs are well-behaved.
- Equality saturation can be understood as iterated DPO rewriting.
- The confluence and parallelism results for adhesive categories apply to e-graph rewriting.

This connects directly to Track 9 (Reduction as Propagators) in the Prologos roadmap. If reduction on the propagator network uses an e-graph representation, and e-graphs are adhesive, then we inherit a rich algebraic theory of when reductions commute, when they conflict, and how to analyze the rewriting system for termination and confluence.

### 3.4 Connection to Term Rewriting

Term rewriting is the special case of graph rewriting where the graphs are trees (terms). The connection goes deeper:

- **Jungle evaluation** (Habel and Kreowski): represents terms as acyclic hypergraphs ("jungles"), where sharing is explicit. Term rewriting becomes hypergraph rewriting. This is more efficient than naive term rewriting because shared subterms are rewritten once.
- **Term graph rewriting**: the intermediate case between term rewriting and full graph rewriting. Crucial for implementing lazy evaluation (sharing) and optimal reduction (Lamping/Levy-style).
- **E-graphs as quotient term graphs**: an e-graph is a term graph quotiented by an equivalence relation. Equality saturation adds equalities (merging equivalence classes) and then extracts an optimal representative.

For narrowing in Prologos: definitional trees guide the decomposition of terms into sub-problems. If we represent terms as hypergraphs rather than trees, then the same definitional tree strategy extends to graph-structured data, and narrowing becomes a form of hypergraph rewriting guided by demand.

## 4. Parsing as Incremental Information Accumulation

### 4.1 Chart Parsing as Fixpoint Computation

Earley parsing (1970) and its chart-parsing relatives can be formulated as fixpoint computations over a lattice of chart items. The chart is a set of "items" --- each recording a partially-recognized production at a position in the input --- and the parsing algorithm iteratively adds items until no more can be derived.

Rau's verified Earley parser (ITP 2024) makes this explicit: the computation of a single Earley set (bin) is defined as a least fixpoint of three monotonic functions (Predict, Scan, Complete) applied iteratively. The full parse is the fixpoint of composing these bin computations across input positions.

This fixpoint structure maps directly to propagator semantics:
- Each chart item is a cell (or an element in a set-valued cell).
- Predict, Scan, and Complete are propagators that fire when new items appear.
- Parsing terminates when the network quiesces (no new items generated).
- The chart itself is a monotonically growing lattice (items are only added, never removed).

### 4.2 Semiring Parsing

Goodman's semiring parsing framework (1999) observes that many parsing algorithms share the same structure, differing only in the algebraic operations applied to combine sub-results. If you replace the Boolean "recognized/not-recognized" with values from a complete semiring, the same algorithm computes:

| Semiring | What it computes |
|----------|-----------------|
| Boolean | Recognition (yes/no) |
| Counting | Number of parses |
| Viterbi (max-product) | Most probable parse |
| Inside (sum-product) | Total probability |
| Derivation forest | All parse trees |

The semiring abstraction is natural for propagator networks: the "merge" operation on cells plays the role of the semiring addition, and propagator composition plays the role of semiring multiplication. A propagator-based parser parameterized by a semiring would compute whatever analysis the semiring encodes, with no change to the parsing infrastructure.

### 4.3 GLL/GLR and Parse Forests as Ambiguity Lattices

Generalized LL (GLL) parsing handles all context-free grammars, producing a shared packed parse forest (SPPF) that compactly represents all valid parses. The SPPF is itself a graph structure --- a DAG with sharing nodes that factor out common sub-derivations.

The Grammar Flow Graph (GFG) formulation of Earley parsing represents grammar positions as nodes in a graph, with edges for prediction, scanning, and completion. This reformulation makes the connection to graph rewriting explicit: parsing advances by traversing and annotating the GFG, and each annotation step is a local rewriting operation.

For ambiguous grammars, the parse forest is an ambiguity lattice where:
- Bottom is "no parse."
- Each partial parse is an element.
- Join (least upper bound) merges parses sharing a span.
- Top (if reached) is the complete parse of the full input.

This lattice structure is directly compatible with propagator cells whose values are parse forests, merged by SPPF union.

### 4.4 Incremental Parsing via Propagation

Tree-sitter demonstrates that incremental parsing is practical and valuable: given an edit to the source, only the affected portion of the syntax tree is re-parsed. Tree-sitter achieves this with an LR-based algorithm that stores parser state at tree boundaries, allowing resumption from the nearest unaffected state.

A propagator-based parser would achieve incrementality more naturally:
- Each parse-state cell depends on input cells and neighboring parse-state cells.
- An edit to the input changes an input cell.
- The propagator network propagates the change to affected parse-state cells.
- Unaffected cells retain their values.

The key advantage over tree-sitter: the propagator approach does not require a separate mechanism for incrementality --- it falls out of the network's dependency tracking. Moreover, because the same network handles both parsing and type-checking, an edit to the source automatically triggers re-elaboration of exactly the affected definitions. No separate invalidation pass is needed.

## 5. Interaction Nets and Geometry of Interaction

### 5.1 Lafont's Interaction Nets

Interaction nets (Lafont, 1990) are a restricted form of graph rewriting where:
- Agents (nodes) have a fixed number of typed ports, with exactly one distinguished "principal" port.
- Interaction rules apply only when two agents are connected via their principal ports.
- Each pair of agent types has at most one interaction rule.
- Rules are local: they replace the two interacting agents and their connections with a new net fragment.

These restrictions guarantee **strong confluence**: the order of rule application does not matter, and the result is unique. This is the strongest possible confluence property --- no critical pairs, no backtracking, no search.

The restriction to binary principal-port interaction may seem severe, but Lafont showed that a small set of "interaction combinators" (three agent types with six rules) is universal --- it can simulate any interaction net system and hence any computation. This is the basis for optimal lambda calculus reduction.

### 5.2 Geometry of Interaction

Girard's Geometry of Interaction (GoI) provides a semantic framework for understanding computation as paths through a graph. In the GoI perspective:
- A proof (or program) is a graph in a traced monoidal category.
- Computation (cut elimination) is modeled by the "execution formula" --- an operator that follows paths through the graph, bouncing off nodes according to local rules.
- The execution formula is invariant under cut elimination --- it computes the same value regardless of the reduction order.

The categorical setting is a traced monoidal category with a reflexive object. "Traced" means there is a feedback operation (trace) that allows paths to loop. "Reflexive" means there is an object that maps into itself, modeling higher-order functions.

For Prologos, GoI provides a potential semantic foundation for reduction on the propagator network:
- Propagator cells are objects in a monoidal category.
- Propagator connections are morphisms.
- The network topology defines paths.
- Propagation along paths is the execution formula.
- Quiescence corresponds to convergence of the execution formula.

This is speculative but tantalizing: if we can formalize propagator evaluation as a GoI-style execution formula, we inherit the invariance result (reduction-order independence) and the connection to linear logic (resource tracking).

### 5.3 HVM and Practical Interaction Nets

The Higher-order Virtual Machine (HVM) demonstrates that interaction nets are practical, not just theoretical. HVM implements lambda calculus reduction via interaction nets and achieves:
- **Beta-optimality**: some computations are exponentially faster than traditional reduction because shared subterms are reduced at most once.
- **Massive parallelism**: every interaction is independent (by confluence), so all interactions can fire simultaneously.
- **No garbage collection**: linearity constraints (explicit duplication/erasure agents) eliminate the need for tracing GC.

HVM2 compiles interaction nets to C and CUDA, achieving GPU-parallel functional computation. The Bend programming language provides a high-level front-end.

For Prologos, HVM is proof-of-concept that interaction-net-based evaluation is not academic fantasy. The question is whether our propagator network --- which is more general than interaction nets (it allows non-binary interactions and non-confluent rules) --- can achieve similar benefits for the cases where interaction-net restrictions hold.

### 5.4 Connection to Propagator Networks

The relationship between interaction nets and propagator networks:

| Interaction Nets | Propagator Networks |
|-----------------|-------------------|
| Agent | Cell (with merge function) |
| Principal port | Primary dependency |
| Auxiliary ports | Additional dependency cells |
| Interaction rule | Propagator function |
| Strong confluence | Monotonic convergence (weaker) |
| Binary interaction | Multi-input propagation |
| Linearity (built-in) | QTT (external check) |

Propagator networks are strictly more expressive: they allow non-confluent computation (via stratified quiescence and TMS-tagged speculation), non-binary interactions, and multiple simultaneous lattice domains. Interaction nets are a well-behaved fragment that enjoys stronger properties (confluence, parallelism, optimality).

The research question: can we identify which sub-computations of the Prologos elaboration/reduction pipeline satisfy the interaction net restrictions, and use that knowledge to exploit stronger parallelism and optimality properties for those sub-computations?

## 6. Applications to Compiler Infrastructure

### 6.1 Collapsing the Pipeline

The traditional compiler pipeline is a sequence of passes:

```
source -> lex -> parse -> elaborate -> typecheck -> optimize -> codegen
```

Each pass transforms one representation to another. This creates artificial phase distinctions: elaboration cannot influence parsing, type information cannot guide lexing, optimization cannot feed back into type checking.

A propagator-based compiler collapses this into a single network:
- Input cells hold source characters (or tokens).
- Parse-state cells hold partial parse results.
- AST cells hold elaborated syntax.
- Type cells hold inferred types.
- Optimization cells hold rewrite results.

All cells coexist in one network. Information flows in whatever direction the dependencies demand. Type information CAN guide parsing disambiguation. Optimization results CAN trigger re-elaboration. The "pipeline" is an emergent property of dependency order, not an architectural constraint.

This is not a new idea --- it is implicit in the attribute grammar literature (where parsing and semantic analysis happen on the same decorated tree). What is new is the combination with:
- Propagator-network incrementality (edits propagate minimally).
- Lattice-based information accumulation (partial results are useful).
- TMS-tagged speculation (ambiguous parses can be explored in parallel).

### 6.2 Graph Rewriting for Optimization

Compiler optimizations are naturally expressed as graph rewrite rules:

- **Constant folding**: pattern `(+ (const a) (const b))` rewrites to `(const (+ a b))`.
- **Dead code elimination**: a node with no consumers (no outgoing dependency edges) is removed.
- **Common subexpression elimination**: two nodes computing the same value are merged (this IS e-graph equivalence class merging).
- **Inlining**: replace a function call node with the function body graph, reconnecting parameters.

In a DPO framework, each optimization is a rewrite rule `L <- K -> R` with a well-defined interface. The adhesive category machinery gives us:
- **Confluence analysis**: which optimizations commute? (Critical pair analysis.)
- **Parallel application**: independent optimizations can fire simultaneously.
- **Phase ordering**: when optimizations do NOT commute, what ordering is best? (E-graph equality saturation explores all orderings simultaneously.)

### 6.3 Provenance and Proof Objects

A propagator network naturally maintains provenance: each cell value was determined by specific propagators firing on specific input values. This dependency graph IS a proof object --- it explains why each computed value holds.

For compiler infrastructure, this means:
- Every type assignment carries a derivation (the propagator firing chain that established it).
- Every optimization carries a justification (the rewrite rule and the match that triggered it).
- Source-to-target correspondence is maintained automatically (each target cell traces back to source cells through the propagator dependency graph).

The 2024 work on "Correctly Compiling Proofs About Programs Without Proving Compilers Correct" suggests an approach where proofs about source programs are compiled alongside the programs, even when the compiler itself is not fully verified. The propagator network's dependency tracking could serve as the substrate for such compiled proofs.

### 6.4 Incremental Compilation via Propagation

Rust's query-based compiler architecture (rustc) and the Salsa library demonstrate the demand-driven, incremental compilation approach:
- Compilation is organized as queries ("what is the type of item X?").
- Query results are memoized.
- When source changes, a red/green algorithm determines which memoized results are still valid.
- Only invalidated queries are recomputed.

This is architecturally similar to a propagator network, but with a key difference: queries are *demand-driven* (pulled), while propagators are *data-driven* (pushed). The Prologos network uses push-based propagation with stratified quiescence, which subsumes the pull-based query model --- any query can be expressed as "install a propagator that fires when the answer becomes available."

The advantage of the propagator approach over Salsa-style queries:
- No need for an explicit invalidation algorithm --- propagation handles it.
- Circular dependencies are natural (fixpoint iteration) rather than errors.
- Speculative computation (TMS-tagged alternatives) is built in.
- The same infrastructure handles both within-module and cross-module dependencies.

### 6.5 E-Graphs as Persistent Compiler Abstraction

Recent work (arxiv 2602.16707, February 2026) proposes representing e-graphs natively in the compiler's intermediate representation, rather than as a separate optimization phase. The key insight: if the e-graph persists throughout compilation, then equality information discovered during one phase is available to all subsequent phases. This avoids the "information loss" problem where an early optimization phase discovers equalities that a later phase could use but cannot access.

The implementation (using xDSL and MLIR) introduces an `eqsat` dialect that represents e-graph equivalence classes directly in the IR. Pattern rewriting can be interleaved with other compiler transformations, with the e-graph maintaining all discovered equalities.

For Prologos, this aligns with the vision of the propagator network as a persistent compilation substrate. The network already maintains all elaboration information persistently (that is the point of Tracks 5-8). Adding e-graph-style equivalence tracking would extend this to reduction/optimization information.

## 7. Connection to Existing Prologos Infrastructure

### 7.1 Hypergraph Rewriting IS Structural Decomposition (SRE)

The SRE's core operation --- `structural-relate(cell, Pi(domain-cell, codomain-cell))` --- is a hypergraph rewrite rule. It takes a cell whose value is unknown, asserts that it has Pi structure, and installs sub-cells for domain and codomain connected by propagators. This is precisely:

- **L (left-hand side)**: a single hyperedge labeled with the cell.
- **K (interface)**: the cell's attachment points.
- **R (right-hand side)**: a subgraph with Pi structure --- domain node, codomain node, and propagators connecting them to the original cell.

The SRE's decomposition cases (`make-pi-reconstructor`, `make-sigma-reconstructor`, etc.) are a catalogue of DPO rewrite rules. The structural-relate dispatcher is a rule application engine that selects the appropriate rule based on the cell's current value.

The Engelfriet-Heyker theorem tells us that these structural decomposition rules, applied according to the grammar of type constructors, generate exactly the term languages that an attribute grammar over the same types would compute. This is a formal justification for the SRE approach: it is not an ad hoc collection of cases, but a systematic application of HR grammar productions.

### 7.2 Definitional Trees as Graph Rewrite Strategies (NF-Narrowing)

NF-Narrowing uses definitional trees to guide the decomposition of terms during narrowing. A definitional tree is a strategy that says: "to narrow this function application, first examine this argument position; if it is a constructor, apply this rule; if it is a variable, narrow it first."

In graph rewriting terms, a definitional tree is a **rewrite strategy** --- a policy for selecting which rewrite rule to apply and where. The "needed narrowing" property (Antoy, Echahed, Hanus 2000) says this strategy is optimal: it never performs unnecessary narrowing steps.

The graph rewriting perspective adds something: if we represent terms as hypergraphs (with sharing), then definitional-tree-guided narrowing becomes hypergraph rewriting guided by demand analysis. Shared subterms are narrowed at most once, and the demand structure propagates through the sharing edges. This connects narrowing to the "jungle evaluation" model of Habel and Kreowski, and to HVM-style optimal reduction.

### 7.3 Typing Graph Rewrite Rules (NTT)

The NTT syntax design specifies how to type the various constructs of Prologos. Graph rewrite rules would be a new class of construct to type. The key question: what is the type of a DPO rewrite rule `L <- K -> R`?

A natural answer: a rewrite rule has a type `Graph(A) -> Graph(A)` where `A` is the type of node labels, but this is too coarse. A better answer uses the adhesive category structure:

- The rule's interface `K` specifies which part of the matched subgraph is preserved.
- The rule's type includes the graph schemas of `L` and `R`, constrained to agree on `K`.
- Dependent types can express the relationship between `L` and `R` (e.g., "the output graph has the same nodes as the input, but with different edge labels").

This suggests a potential extension to NTT: **rewrite-typed functions** whose type signature specifies not just input and output types, but the structural transformation they perform. This would be a novel contribution.

### 7.4 Track 9 and the Reduction-as-Propagators Vision

Track 9 on the Prologos roadmap is "Reduction as Propagators --- interaction nets, GoI, e-graph rewriting." This research note provides the theoretical foundations for Track 9:

- **Interaction nets** give us the confluent, parallel fragment of reduction.
- **GoI** gives us the semantic invariance result (reduction-order independence) for that fragment.
- **E-graph rewriting** (now known to be adhesive) gives us the algebraic theory of when reductions commute and how to explore the space of equivalent terms.
- **Hypergraph grammars** give us the generative theory of what structures our reductions produce.
- **Attribute grammars** give us the analytic theory of what properties we can compute over those structures.

Track 9 is not just "do reduction on the network." It is the convergence point of all these theories, applied to the specific architecture of the Prologos propagator network.

## 8. How This Changes Our Thinking

### 8.1 Does Parsing on the Network Eliminate the Multi-Pass Pipeline?

**Partially, but the answer is nuanced.**

The theoretical result is clear: parsing can be expressed as fixpoint computation on a lattice of chart items, which is a propagator network computation. The Engelfriet-Heyker theorem says attribute grammar evaluation (our elaboration) has the same power as HR grammar generation (our structural type construction). So there is no theoretical barrier to putting everything on one network.

The practical considerations:

1. **Parsing is overwhelmingly sequential in practice.** Even though chart parsing is a fixpoint computation, the Scan step must process input left-to-right. The parallelism in parsing comes from Predict and Complete, which can fire concurrently for different nonterminals at the same position. This is less parallelism than type inference enjoys.

2. **Parsing granularity is wrong for type checking.** A character-level propagator network for parsing would have cells for every input character and every parser state transition. This is orders of magnitude more cells than the type-level network needs. The granularity mismatch suggests that parsing should be a coarser-grained sub-network, feeding results into the finer-grained type network.

3. **Incremental re-parsing is the real win.** The value of putting parsing on the network is not collapsing passes --- it is incrementality. An edit to the source triggers re-parsing of only the affected region, which triggers re-elaboration of only the affected definitions, which triggers re-type-checking of only the affected types. This end-to-end incrementality is the killer application, and it does not require character-level parsing cells.

**Recommendation**: Parsing should feed into the propagator network at the definition/expression granularity, not the character granularity. The parser itself can be a conventional incremental parser (tree-sitter-style) that produces AST cells. The network handles everything from elaboration onward, with the parse-to-AST step as an entry point. This gives us the incrementality win without the granularity cost.

### 8.2 Does Graph Rewriting Subsume the SRE?

**Yes, and this is a good thing.**

The SRE's structural decomposition is a specific instance of DPO hypergraph rewriting. The decomposition rules (Pi, Sigma, etc.) are DPO rules. The structural-relate dispatcher is a rule application strategy. The bidirectional propagation is the DPO rule applied in both directions (possible because DPO rules are reversible).

Recognizing this does not invalidate the SRE --- it provides a rigorous framework for extending it:

1. **New type constructors** get new DPO rules, with the adhesive category theory ensuring they compose well with existing rules.
2. **Optimization rules** (e.g., beta reduction as a DPO rule on the type graph) can be added to the same framework, with confluence analysis to ensure they do not conflict with the structural decomposition rules.
3. **Custom user-defined structural rules** become possible --- the user defines a type constructor, and the system automatically derives the DPO decomposition rules for it.

The SRE becomes the "type-level graph rewriting engine," and the graph rewriting framework provides the theoretical tools to reason about its correctness and extensibility.

### 8.3 What Would a "Parsing Series" Look Like?

A "Parsing Series" on the roadmap would bring parsing and early compilation onto the propagator network infrastructure. Here is a sketch:

**Series: PPN (Propagator-Parsing-Network)**

| Track | Description | Depends On |
|-------|------------|-----------|
| PPN-0 | Research: formalize current WS reader as chart parser; identify lattice structure | This document |
| PPN-1 | Incremental token stream: source cells -> token cells with change propagation | PM Track 10 |
| PPN-2 | Chart-as-cells: Earley items as cells, Predict/Scan/Complete as propagators | PPN-1 |
| PPN-3 | Parse-forest-to-AST propagators: SPPF cells -> AST cells, ambiguity as TMS branches | PPN-2, BSP-LE Track 2 |
| PPN-4 | Unified incremental pipeline: edit -> re-lex -> re-parse -> re-elaborate -> re-typecheck, all via propagation | PPN-3, PM Track 11 |
| PPN-5 | Self-hosting bootstrap: Prologos WS grammar defined as HR grammar, parsed on the network | PPN-4, NTT |

PPN-0 and PPN-1 are near-term (could start after PM Track 10). PPN-5 is the long-term vision.

### 8.4 How Does This Connect to Self-Hosting?

Self-hosting requires Prologos to parse, elaborate, type-check, and compile itself. The hypergraph rewriting perspective reframes this as:

1. **The Prologos grammar is an HR grammar** whose productions generate the AST hypergraph.
2. **Elaboration is attribute grammar evaluation** on the generated AST, implemented by the propagator network.
3. **Type checking is a fixpoint computation** on the attribute-decorated AST.
4. **Compilation (codegen) is graph rewriting** from the typed AST to target code.

Self-hosting then means: the HR grammar, the attribute rules, and the graph rewrite rules are all expressed in Prologos and evaluated by the Prologos propagator network. The Engelfriet-Heyker theorem ensures that this is possible in principle --- the attribute grammar (propagator network) has sufficient power to generate the term languages that constitute its own compilation pipeline.

The NTT case studies (type checker, NF-narrowing, sessions/QTT) are already specifying sub-components of this self-hosted pipeline in Prologos syntax. The step from there to parsing-on-network completes the circle.

## 9. Open Questions

1. **Granularity trade-off**: At what granularity should parsing cells connect to elaboration cells? Per-character? Per-token? Per-definition? Per-module? The answer likely varies by use case (IDE responsiveness vs. batch compilation).

2. **Lattice design for parse states**: What is the right lattice for incremental Earley items? The naive powerset lattice (set of items at each position) has finite height but potentially exponential width. Can we exploit the grammar structure to bound this?

3. **TMS-tagged ambiguity**: Can grammatical ambiguity be represented as TMS-tagged alternative parses, unified with the existing speculation mechanism for type inference? This would unify two separate "explore alternatives" mechanisms.

4. **Interaction net fragment identification**: Which sub-computations of the Prologos elaboration pipeline satisfy the interaction net restrictions (binary principal-port interaction, strong confluence)? Can we automatically identify these and exploit the stronger properties?

5. **Adhesive category for Prologos cells**: Is the category of Prologos propagator networks (cells as objects, propagators as morphisms) itself adhesive? If so, we could apply DPO rewriting to the network itself --- meta-level graph rewriting that transforms the compilation pipeline.

6. **E-graph integration with TMS**: How do e-graph equivalence classes interact with TMS worldviews? An equality discovered in one worldview may not hold in another. Can we have per-worldview e-graph state?

7. **Optimal reduction for Prologos**: Can the HVM approach (interaction-net-based optimal reduction) be applied to Prologos's reduction engine? What subset of Prologos programs admit optimal reduction?

8. **Semiring parametricity**: Can the propagator network be parameterized by a semiring, so that the same network computes different analyses (type inference, cost estimation, resource usage) by changing the semiring?

## 10. References

### Hypergraph Grammars and Graph Rewriting

- Engelfriet, J. and Heyker, L. (1992). "Context-free hypergraph grammars have the same term-generating power as attribute grammars." *Acta Informatica*, 29(2). [Springer](https://link.springer.com/article/10.1007/BF01178504)
- Courcelle, B. (1990). "The monadic second-order logic of graphs. I. Recognizable sets of finite graphs." *Information and Computation*, 85(1). [ScienceDirect](https://www.sciencedirect.com/science/article/pii/089054019090043H)
- Habel, A. and Kreowski, H.-J. (1987). "Computing by graph transformation: Overall aims and new results." [Springer](https://link.springer.com/chapter/10.1007/BFb0017422)
- Habel, A., Kreowski, H.-J., and Plump, D. (1991). "Jungle Evaluation." *Fundamenta Informaticae*, 15(1). [SAGE](https://journals.sagepub.com/doi/abs/10.3233/FI-1991-15104)
- Drewes, F. et al. "Hyperedge Replacement Graph Grammars" (Chapter 2, course notes). [Rochester](https://www.cs.rochester.edu/u/gildea/2018_Fall/hrg.pdf)
- Biondo, R., Castelnovo, D., and Gadducci, F. (2025). "EGGs Are Adhesive!" *CALCO 2025*, LIPIcs vol. 342. [Dagstuhl](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CALCO.2025.10), [arXiv](https://arxiv.org/abs/2503.13678)

### Attribute Grammars

- Knuth, D. (1968). "Semantics of context-free languages." *Mathematical Systems Theory*, 2(2). [Semantic Scholar](https://www.semanticscholar.org/paper/Semantics-of-context-free-languages-Knuth/0b61a17906637ece5a9c5e7e3e6de93378209706)
- Magnusson, E. and Hedin, G. (2007). "Circular Reference Attributed Grammars --- Their Evaluation and Applications." *Science of Computer Programming*. [ScienceDirect](https://www.sciencedirect.com/science/article/pii/S1571066105826271)
- Jones, L. G. (1990). "Efficient evaluation of circular attribute grammars." *TOPLAS*, 12(3). [ACM](https://dl.acm.org/doi/10.1145/78969.78971)
- Van Wyk, E. et al. (2010). "Silver: An Extensible Attribute Grammar System." *Science of Computer Programming*. [ScienceDirect](https://www.sciencedirect.com/science/article/pii/S0167642309001099)

### Adhesive Categories and DPO Rewriting

- Lack, S. and Sobocinski, P. (2005). "Adhesive and quasiadhesive categories." *RAIRO --- Theoretical Informatics and Applications*.
- Minichiello, E. (2024). "Pushouts along monomorphisms" (blog post on adhesive categories). [Blog](https://www.emiliominichiello.com/blog/2024/adhesivecategories/)
- Inria (2025). "Formalizing adhesive category theory in Rocq." *JFLA 2025*. [HAL](https://inria.hal.science/hal-04859469/document)
- Corradini, A. et al. (2024). "Left-Linear Rewriting in Adhesive Categories." *CONCUR 2024*. [Dagstuhl](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CONCUR.2024.11)

### Parsing and Fixpoint Computation

- Rau, M. (2024). "A Verified Earley Parser." *ITP 2024*. [Dagstuhl](https://drops.dagstuhl.de/storage/00lipics/lipics-vol309-itp2024/LIPIcs.ITP.2024.31/LIPIcs.ITP.2024.31.pdf)
- Goodman, J. (1999). "Semiring Parsing." *Computational Linguistics*, 25(4). [ACL Anthology](https://aclanthology.org/J99-4004.pdf)
- Scott, E. and Johnstone, A. (2010). "GLL Parsing." *LDTA 2009*. [ScienceDirect](https://www.sciencedirect.com/science/article/pii/S1571066110001209)

### E-Graphs and Equality Saturation

- Willsey, M. et al. (2021). "egg: Fast and Extensible Equality Saturation." [arXiv](https://arxiv.org/abs/2004.03082)
- Schlatt, A. et al. (2026). "E-Graphs as a Persistent Compiler Abstraction." [arXiv](https://arxiv.org/abs/2602.16707)
- Moss, A. (2025). "E-Graphs with Bindings." [arXiv](https://arxiv.org/abs/2505.00807)
- EGRAPHS community workshops: [2024](https://pldi24.sigplan.org/home/egraphs-2024), [2025](https://pldi25.sigplan.org/home/egraphs-2025), [2026](https://pldi26.sigplan.org/home/egraphs-2026)

### Interaction Nets and Geometry of Interaction

- Lafont, Y. (1990). "Interaction nets." *POPL '90*. [ACM](https://dl.acm.org/doi/pdf/10.1145/96709.96718)
- Lafont, Y. (1997). "Interaction Combinators." *Information and Computation*. [Semantic Scholar](https://www.semanticscholar.org/paper/Interaction-Combinators-Lafont/6cfe09aa6e5da6ce98077b7a048cb1badd78cc76)
- Girard, J.-Y. (various). Geometry of Interaction I-V. The GoI framework in traced monoidal categories.
- Fernandez, M. (2013). "Concurrency in Interaction Nets and Graph Rewriting." PhD Thesis. [HAL](https://theses.hal.science/tel-00937224/file/Concurrency_in_Interaction_Nets_and_Graph_Rewriting.pdf)
- Taelin, V. / HigherOrderCO. "HVM: Higher-order Virtual Machine." [GitHub (HVM1)](https://github.com/HigherOrderCO/HVM1), [GitHub (HVM2)](https://github.com/HigherOrderCO/HVM2)

### Incremental Compilation

- Rust compiler team. "Incremental compilation in rustc." [Dev Guide](https://rustc-dev-guide.rust-lang.org/queries/incremental-compilation.html)
- Tree-sitter. "An incremental parsing system for programming tools." [GitHub](https://github.com/tree-sitter/tree-sitter)
- Matsakis, N. et al. "Salsa: A generic framework for on-demand, incrementalized computation." [rustc Dev Guide](https://rustc-dev-guide.rust-lang.org/queries/salsa.html)

### Compiler Correctness and Provenance

- Engel, J. et al. (2024). "Correctly Compiling Proofs About Programs Without Proving Compilers Correct." *ITP 2024*. [Dagstuhl](https://drops.dagstuhl.de/storage/00lipics/lipics-vol309-itp2024/LIPIcs.ITP.2024.33/LIPIcs.ITP.2024.33.pdf)
- Topos Institute (2025). "How to prove equations using diagrams" (e-graphs and category theory). [Blog](https://topos.institute/blog/2025-05-27-e-graphs-1/)
