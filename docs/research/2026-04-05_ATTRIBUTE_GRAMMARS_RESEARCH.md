# Attribute Grammars: Catamorphisms, Aspects, and Propagator Architecture

**Date**: 2026-04-05
**Purpose**: Research report for PPN Track 4B — connecting attribute grammar theory to Prologos propagator-native elaboration

---

## §1 The Fundamental Connection: Attribute Grammars ARE Catamorphisms

The foundational result (Fokkinga, Jeuring, Meertens & Meijer, 1991): [attribute grammars translate to catamorphisms](https://research.utwente.nl/en/publications/a-translation-from-attribute-grammars-to-catamorphisms/). A catamorphism is a fold over an algebraic data type. An attribute grammar specifies HOW to fold — what to compute at each node, what to pass down, what to pass up.

The Haskell wiki states this directly: attribute grammars are ["a formalism for writing catamorphisms in a compositional fashion"](https://wiki.haskell.org/The_Monad.Reader/Issue4/Why_Attribute_Grammars_Matter). Instead of hand-writing tree traversals (which IS what imperative `infer` does — a 589-arm match over the AST), the grammar declarations specify WHAT to compute. The system handles HOW.

**For Prologos**: The imperative `infer` function IS a hand-written catamorphism. It folds over the AST, computing types bottom-up (synthesized) while threading context top-down (inherited). Track 4B replaces this with the ATTRIBUTE GRAMMAR specification — declarative rules that propagators evaluate to fixpoint. The SRE typing domain is the beginning of this specification.

### The Categorical View

[Attribute grammars have categorical semantics](https://link.springer.com/chapter/10.1007/978-3-540-70583-3_23) — they correspond to initial algebra semantics on the category of attributed trees. The catamorphism IS the unique morphism from the initial algebra (the AST type) to the attribute algebra (the type/constraint/usage computation).

For Prologos: the AST IS the initial algebra. The attribute record (type × context × multiplicity × constraint × warning) IS the target algebra. The propagator evaluation IS the catamorphism — the unique fold that computes attributes from the tree structure.

---

## §2 Aspect-Oriented Attribute Grammars: Modular Attribute Definitions

### The Silver System (MELT, University of Minnesota)

[Silver](https://melt.cs.umn.edu/silver/index.html) is an extensible attribute grammar system where attribute definitions are MODULAR — spread across aspects that are woven together. Key concepts:

- **Aspect productions**: attribute definitions written separately from production declarations, [woven together at compile time](https://melt.cs.umn.edu/silver/concepts/aspects/). "The declarations and definitions in the aspect were included in the original production."
- **Forwarding**: new syntax constructs can define their semantics by forwarding to existing constructs, enabling [modular language extension](https://www.sciencedirect.com/science/article/pii/S0167642309001099).
- **Separate compilation**: grammar modules compile independently; aspects weave at runtime.

**For Prologos**: The SRE typing domain IS aspect-oriented attribute definition. Each `register-typing-rule!` call IS an aspect production — an attribute definition added to a production (expr kind) without modifying the original definition. Multiple aspects (type, constraint, multiplicity) can be registered independently for the same production. This IS the Silver model, implemented via our SRE domain registry.

### Aspect-Oriented Programming Connection

The connection between AG and AOP is formalized: ["attribute grammars bring aspect-oriented programming to functional programming by helping writing catamorphisms compositionally"](https://dl.acm.org/doi/10.1145/1631687.1596586). Each attribute kind (type, constraint, multiplicity) is an ASPECT. The aspects are WOVEN into the catamorphism (the fold over the AST). The result is a COMPOSED fold that computes ALL aspects simultaneously.

**For Prologos**: Track 4A implemented the TYPE aspect. Track 4B adds the CONSTRAINT, MULTIPLICITY, and WARNING aspects. Each is a set of attribute definitions (propagator fire functions) registered in the SRE domain. The propagator evaluation weaves them into a single fixpoint computation. This IS aspect-oriented catamorphism.

---

## §3 Circular and Reference Attribute Grammars

### Circular Attribute Grammars (CAGs)

[Circular Reference Attributed Grammars](https://www.researchgate.net/publication/222429290_Circular_Reference_Attributed_Grammars_-_Their_Evaluation_and_Applications) allow iterative fixed-point computations via recursive (circular) attribute equations. The evaluation uses a worklist algorithm that iterates until convergence.

**For Prologos**: This IS the propagator model. Circular dependencies (e.g., mutual recursion, type inference with constraints that feed back into type refinement) are handled by the propagator scheduler's fixpoint iteration. The "worklist algorithm" in CAG evaluation IS `run-to-quiescence`. The propagator model is a GENERALIZATION of circular attribute grammar evaluation.

### Reference Attribute Grammars (RAGs)

[Reference attributes](https://link.springer.com/chapter/10.1007/978-3-319-02654-1_17) allow attributes to point to OTHER nodes in the tree — not just ancestors/descendants. This enables non-local dependencies (like type lookup in a symbol table).

**For Prologos**: The context lattice (Track 4A Phase 1c) IS a reference attribute — `bvar(k)` references a binding k positions up the scope tree. The global environment lookup (`fvar`) is a reference attribute to the module-level symbol table. These are already on-network via context cell positions and global-env bridge reads.

### Demand-Driven Evaluation

CAG evaluation can be [demand-driven](https://link.springer.com/article/10.1007/BF03037280) — attributes are evaluated lazily when needed, or data-driven — evaluated eagerly as dependencies become available.

**For Prologos**: The propagator model is DATA-DRIVEN (eager). When a cell value changes, dependent propagators fire. This is the right model for our ephemeral PU — we want the fixpoint computed completely before reading the result. Demand-driven would be appropriate for an interactive/incremental mode (future: LSP integration).

---

## §4 Higher-Order Attribute Grammars

[Higher-order attribute grammars](https://www.researchgate.net/publication/234803748_Higher_order_attribute_grammars) allow attribute values to be TREES THEMSELVES — an attribute can be a new AST that is then further attributed. This enables compilation via transformation: an attribute computes a translated tree, which is then attributed in the target language's grammar.

**For Prologos**: The elaboration phase (surface → core translation) IS a higher-order attribute. The `elaborate` function computes a CORE AST from the surface AST — the core AST is an attribute value that is then further attributed (type inference). In the AG model, this is a higher-order attribute: the surface form's `core` attribute IS a new tree, and the type/constraint/multiplicity attributes are computed on that new tree.

The form pipeline (Track 3) already supports this: the form cell's PU value holds the parse tree, which enriches through pipeline stages. The "core expr" IS an attribute of the form cell, computed by the surface rewriting propagators. Type inference attributes are computed on the core expr attribute.

---

## §5 The JastAdd System: CRAGs in Practice

[JastAdd](https://link.springer.com/chapter/10.1007/978-3-642-18023-1_4) implements Circular Reference Attributed Grammars with:
- **Object-oriented AST representation** with reference attributes linking tree parts
- **Aspect-oriented modularization**: behavior split into aspects (name analysis, type checking, code generation)
- **On-demand evaluation**: attributes computed lazily on first access, cached for subsequent reads
- **Fixed-point iteration** for circular attributes

JastAdd has been used to build [complete Java compilers (JastAddJ)](https://www.researchgate.net/publication/222429290_Circular_Reference_Attributed_Grammars_-_Their_Evaluation_and_Applications) with modular aspect composition.

**For Prologos**: JastAdd validates the AG approach for real compilers. The key difference: JastAdd uses demand-driven (lazy) evaluation with caching. Prologos uses data-driven (eager) evaluation via propagator fixpoint. Both converge to the same result; the evaluation strategy differs. Our ephemeral PU model (eager evaluation to quiescence) is simpler for batch compilation. JastAdd's on-demand model is better for incremental/interactive compilation.

---

## §6 The Kiama Library: Lightweight AGs

[Kiama](https://github.com/inkytonik/kiama) is a Scala library for language processing that embeds attribute grammar evaluation as a domain-specific language. Key features:

- **Cached, uncached, higher-order, parameterized, and circular attributes**
- **Circular attributes with fixed-point evaluation** — the `circular` function takes an initial value and evaluates until convergence
- [Dataflow analysis as circular attributes](https://inkytonik.github.io/kiama/Dataflow) — variable liveness computed as fixed-point over a control flow graph

**For Prologos**: Kiama's circular attribute evaluation (iterate until convergence) IS propagator quiescence. Kiama's dataflow analysis as circular attributes IS constraint resolution as attribute evaluation. The Prologos propagator model is more general (handles non-local dependencies, stratification, ATMS branching) but Kiama validates the core approach.

---

## §7 Implications for Prologos Track 4B

### §7.1 The Attribute Record as Algebra

The attribute record `{type, context, multiplicity, constraints, warnings}` IS the target algebra of the catamorphism. The propagator evaluation IS the unique fold from the initial algebra (AST) to this target. The CHAMP-backed global attribute store (§9 of the Track 4B design) IS the MEMOIZED catamorphism — computed once, shared structurally.

### §7.2 Aspects as Domain Facets

Each attribute domain (type, constraint, multiplicity, warning) IS an aspect in the Silver/JastAdd sense. The SRE typing domain IS the aspect production mechanism. Extending it to `register-attribute-rule!` with per-facet definitions IS aspect weaving — composing independently-defined attribute equations into a single catamorphism.

### §7.3 Circular Attributes as Propagator Fixpoint

Circular dependencies (mutual recursion, constraint-fed type refinement) are handled identically in CRAGs and propagator networks: iterate the worklist/scheduler until convergence. The BSP stratification (S0/S1/S2) adds ORDERED evaluation that CRAGs handle with evaluation scheduling. The ATMS adds speculative branching that CRAGs don't support — this is where Prologos goes beyond standard AG.

### §7.4 Higher-Order Attributes for Elaboration

The surface→core translation IS a higher-order attribute. The core AST is an attribute value that is further attributed. This validates the Track 4B approach: elaboration and type inference are NOT separate phases — they're attribute evaluation at different levels of the same grammar.

### §7.5 The `that` Operation

In AG terms, `that` IS an attribute QUERY — a way to access the computed attribute record for a node. In Silver terms, it's an attribute access on a production. In the global attribute store, it's a CHAMP lookup. As user-facing syntax, it's a first-class mechanism for querying and extending the attribute grammar at the language level.

### §7.6 Structural Sharing as Memoized Catamorphism

The CHAMP-backed global attribute store IS a memoized catamorphism. Common sub-folds (e.g., `type(int+) = Int→Int→Int`) are computed ONCE and shared. The `.pnet` cache persists the memoization across sessions. This is the AG equivalent of attribute caching in JastAdd — but with structural sharing via persistent data structures.

---

## §8 Key References

### Foundational
- Fokkinga, Jeuring, Meertens & Meijer (1991). [A translation from attribute grammars to catamorphisms](https://research.utwente.nl/en/publications/a-translation-from-attribute-grammars-to-catamorphisms/). Squiggolist 2(1).
- [Attribute Grammars and Categorical Semantics](https://link.springer.com/chapter/10.1007/978-3-540-70583-3_23). LNCS.

### Systems
- Van Wyk et al. [Silver: an Extensible Attribute Grammar System](https://www.sciencedirect.com/science/article/pii/S0167642309001099). Science of Computer Programming.
- Magnusson & Hedin. [Circular Reference Attributed Grammars — Evaluation and Applications](https://www.researchgate.net/publication/222429290_Circular_Reference_Attributed_Grammars_-_Their_Evaluation_and_Applications). Science of Computer Programming.
- Sloane. [Lightweight Language Processing in Kiama](https://inkytonik.github.io/assets/papers/gttse09.pdf). GTTSE.
- Hedin. [An Introductory Tutorial on JastAdd Attribute Grammars](https://link.springer.com/chapter/10.1007/978-3-642-18023-1_4). GTTSE.

### Aspect-Oriented
- Viera, Swierstra & Swierstra. [Attribute Grammars Fly First-Class](https://dl.acm.org/doi/10.1145/1631687.1596586). ICFP 2009.
- Van Wyk. [Aspects as Modular Language Extensions](https://www.sciencedirect.com/science/article/pii/S1571066105826283). ENTCS.
- [Why Attribute Grammars Matter](https://wiki.haskell.org/The_Monad.Reader/Issue4/Why_Attribute_Grammars_Matter). The Monad Reader.

### Higher-Order and Circular
- Vogt, Swierstra & Kuiper. [Higher Order Attribute Grammars](https://www.researchgate.net/publication/234803748_Higher_order_attribute_grammars). PLDI 1989.
- [Circular Higher-Order Reference Attribute Grammars](https://link.springer.com/chapter/10.1007/978-3-319-02654-1_17). SLE 2013.
- [Composable Semantics Using Higher-Order Attribute Grammars](https://conservancy.umn.edu/items/97b64b3f-321f-4e0e-8746-6d1c6ffed372). U. Minnesota.
