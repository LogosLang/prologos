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
