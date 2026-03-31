# PTF Series: Propagator Theory Foundations

**Created**: 2026-03-28
**Purpose**: Theoretical underpinnings of propagator networks — what propagators ARE, how they compose, and their parallel profiles. Informs both NTT (syntax/description) and runtime scheduling.

**Relationship to other series**:
- **[PRN](2026-03-26_PRN_MASTER.md)** (Propagator-Rewriting-Network): How propagators rewrite — hypergraph grammars, e-graphs, tree rewriting
- **[NTT](2026-03-22_NTT_SYNTAX_DESIGN.md)** (Network Type Theory): How propagators are described — syntax, type declarations, network specifications
- **PTF** (this series): What propagators are — kinds, composition patterns, parallel profiles, lattice morphology
- **[PAR](2026-03-27_PAR_MASTER.md)** (Parallel Scheduling): Runtime scheduling informed by PTF theory
- **[PPN](2026-03-26_PPN_MASTER.md)** (Propagator-Parsing-Network): Application track that exercises PTF patterns

---

## Research Documents

| # | Document | Date | Status | Key Contribution |
|---|----------|------|--------|-----------------|
| 0 | [Propagator Network Taxonomy](../research/2026-03-21_PROPAGATOR_NETWORK_TAXONOMY.md) | 03-21 | Complete | Foundations survey: Radul, Kmett, Kuper LVars, category theory, lattice taxonomy, diagrammatic formalisms |
| 1 | [Propagator Taxonomy — Parallel Profiles](../research/2026-03-28_PROPAGATOR_TAXONOMY.md) | 03-28 | Draft | 5 propagator kinds (Map, Reduce, Broadcast, Scatter, Gather), 3 compound patterns, array programming connection |

## Related Work (cross-linked)

- **[NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md)** — `:lattice`, `:propagator`, `:cell` declarations. PTF adds `:kind` annotations.
- **[Lattice Foundations / Hyperlattice Conjecture](../research/2026-03-26_LATTICE_FOUNDATIONS.md)** — "Any computation as fixpoint over interconnected lattice structures." PTF describes the morphology (shapes of interconnections).
- **[Parallel Propagator Scheduling](../research/2026-03-28_PARALLEL_PROPAGATOR_SCHEDULING.md)** — Racket 9 landscape, Soufflé, Timely Dataflow. PTF kinds inform scheduling decisions.
- **[CALM Topology Lesson](principles/DEVELOPMENT_LESSONS.org)** — Fixed topology for CALM correctness. PTF's Scatter kind (topology-creating) is the exception that requires stratification.
- **[PPN Track 1 Design](2026-03-26_PPN_TRACK1_DESIGN.md)** — Set-latch pattern = Reduce/Barrier kind. Parse pipeline = Map-Reduce-Broadcast.
- **[PAR Track 1 PIR](2026-03-28_PAR_TRACK1_PIR.md)** — BSP structural propagator capture. Empirical parallel profiles (fan-out vs chain).
- **[Module Theory on Lattices](../research/2026-03-28_MODULE_THEORY_LATTICES.md)** — Propagator kinds gain algebraic grounding. Map = monotone endomorphism. Reduce = meet. Independent sub-ring elements commute = parallel-safe.
- **[Algebraic Embeddings on Lattices](../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md)** — The domain's lattice structure (distributive, Heyting, residuated, Boolean, geometric) determines which propagator kinds are available and what optimizations apply. A Heyting lattice gets pseudo-complement propagators. A residuated lattice gets automatic backward propagator derivation. A Boolean lattice gets SAT/CDCL optimizations. The algebraic structure of the lattice is a type-level property that constrains and enriches the propagator kinds.

---

## Planned Tracks

| Track | Topic | Status | Dependencies |
|-------|-------|--------|-------------|
| 0 | Propagator Kind Taxonomy | Research note complete | — |
| 1 | Kind Annotation in Propagator Struct | Not started | Track 0 |
| 2 | Pipeline Detection at Construction Time | Not started | Track 1 |
| 3 | Kind-Aware `:auto` Scheduling Heuristic | Not started | Track 2, PAR Track 2 |
| 4 | Array Programming Sublanguage Design | Not started | Tracks 0-3, NTT |
| 5 | Lattice Morphology Formalization | Not started | Hyperlattice Conjecture |

---

## Topology Design Patterns (Observed)

Patterns discovered through implementation (PPN Tracks 1-2B, PM Tracks, BSP-LE). Each is a reusable information-flow topology. Future PTF tracks should formalize these.

### Set-Latch / Functorial Map (PPN Track 1, Track 2B discussion)

One propagator lifts a scalar transformation to a container type. Input cell holds RRB(X), output cell holds RRB(Y), propagator applies `f : X → Y` per-position. ONE propagator, not N. The RRB IS a polynomial functor; the map IS `fmap f`. Structural sharing means unchanged elements are O(1). Incremental updates are O(log₃₂ N) per changed element.

**Language design implication**: A scalar function applied to a collection could automatically compile to this topology. No explicit `map` — the network structure handles it. This is the basis for array programming in the language (PTF Track 4).

**Efficiency note**: The propagator fires once per input change, producing an output that shares structure with the previous output. This is "incremental parallel map for free" — array languages don't get this without explicit diff tracking.

### Pocket Universe / Lattice Embedding (PPN Track 2, Track 2B)

One cell holds an ENTIRE embedded lattice. The merge function operates on the embedded structure. Examples: pipeline-as-cell (stage chain), mixfix-resolution-value (claim lattice), form-pipeline-value (normalization pipeline).

**Design pattern**: When N sub-computations share a common lifecycle and resolution ordering, embed them in ONE cell value rather than allocating N cells. The Pocket Universe controls allocation cost while preserving information-flow properties. The SRE can decompose the embedded value via ctor-desc.

**RRBs as trees**: An RRB of RRBs IS a tree. Structural sharing makes rewriting efficient (path-copy). The parse tree is this pattern. The mixfix resolution state is this pattern. Any computation over tree-shaped data can use RRB-embedding.

### Threshold / Gather with Latch (type inference, constraint resolution)

A cell accumulates information from N sources. A propagator fires when a threshold is reached (N of M inputs ready). The accumulated set is monotone (inputs only arrive). The output is latched (write-once). This is the Gather kind with a readiness condition.

**Example**: Polymorphic type resolution — the type cell gathers argument type information. When all arguments are typed, the polymorphic type is instantiated. The threshold is "all positions filled."

### Queue / Ordered Work Set (S(-1) retraction)

A cell holds a set of pending work items plus a monotone high-water mark. New items accumulate (monotone). The propagator processes items above the mark. The mark advances (monotone). No consumption (monotone-safe). The "queue" ordering emerges from the mark's advancement, not from FIFO discipline.

**Design consideration**: The current implementation uses an actual queue (non-monotone consumption). The lattice-compatible version uses mark advancement. Efficiency parity with true queues is an open question.

### Structural Merge / PUnify (type unification, pattern matching)

Two computations that agree on sub-structure share cells at corresponding positions. Information flows bidirectionally through shared structure. No explicit "merge step" — propagation through shared cells IS the merge.

**Generalizes to**: Module imports (shared definition cells), pattern matching (shared scrutinee cells), bidirectional type checking (shared type cells between inference and checking modes).

### Claim Lattice / Competitive Resolution (mixfix, disambiguation)

Multiple agents submit claims on shared positions. The lattice merge resolves competing claims using domain-specific ordering (precedence DAG, position-aware associativity). Incomparable claims produce ⊤ (contradiction = ambiguity error).

**Key property**: Resolution is order-independent. Claims can arrive in any order; the lattice merge produces the same result. No sequential scan. Position information is IN the claim data, not in processing order.

### Kan Extension Patterns (forward/backward flow — not yet fully realized)

Left Kan: forward propagation to fixpoint (greatest lower bound of output given input). This is what BSP does.

Right Kan: backward propagation from constraints (tightest upper bound of input given output). Designed for PPN Track 5 (type-directed disambiguation).

When both exist and coincide: the network computes the EXACT answer. The Hyperlattice Conjecture's optimality claim rests on this.

---

## Open Research Questions

1. **Can propagator kinds be inferred?** Given a fire function's input/output declaration, can we automatically classify it as Map/Reduce/Broadcast/Scatter? Or must the programmer annotate?

2. **Composition laws**: Do propagator kinds compose predictably? Is Map-Reduce always a two-round pipeline? What about Scatter-Map-Gather (three rounds)?

3. **Optimal pipeline scheduling**: Given a pipeline of known kinds, can we compute the optimal BSP round structure? (Timely Dataflow does this for its operators.)

4. **Kind polymorphism**: Can a propagator be Map in one context and Reduce in another? (e.g., a propagator with optional inputs — Map when 1 input connected, Reduce when N connected.)

5. **Topology-creating propagators and parallelism**: Scatter propagators create topology (deferred in BSP). Can we pre-compute the expected topology and create it eagerly, converting Scatter to Map+Broadcast?

6. **Array programming compilation**: How does `map f |> fold g` compile to a propagator network? Is the compilation deterministic (always produces Map→Reduce), or does it depend on the data flow?

7. **Connection to CRDTs**: Propagator kinds map to CRDT operation types. Map = state-based CRDT update. Reduce = merge. Can we formalize this connection for distributed propagator networks?

---

## Principles

PTF research is guided by:
- **Propagator-Only**: Everything is a propagator. Kinds are properties of propagators, not separate mechanisms.
- **Data Orientation**: Kinds are data (annotations on propagator structs), not behavior (no runtime dispatch on kinds unless scheduling).
- **Completeness**: The taxonomy should cover ALL propagators in the codebase. If a propagator doesn't fit a kind, the taxonomy is incomplete.
- **Composition**: Compound patterns (Map-Reduce, Scatter-Gather) should be derivable from individual kinds, not special-cased.
