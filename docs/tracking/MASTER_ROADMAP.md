- [Purpose](#org15bdd7a)
- [Active Series](#org502485c)
  - [Propagator Migration  — *Bringing elaboration state onto the propagator network*](#org430a7d0)
    - [Completed Tracks](#orgc5f5d1d)
    - [Pending Tracks](#org836837c)
  - [BSP-LE  — *The Logic Engine, realized on propagators*](#orge0be547)
    - [Tracks](#org8ab4d25)
    - [Prerequisites](#org60ed52f)
  - [CIU (Collection Interface Unification)  — *All collection dispatch through traits on the propagator network*](#org798acc8)
    - [Tracks](#org50addb0)
  - [SRE (Structural Reasoning Engine)  — *PUnify as universal structural decomposition/composition substrate*](#orge5c0654)
    - [Key Insight](#org57fc61b)
    - [Tracks](#orgb08acfa)
    - [SRE ↔ PM Cross-Dependencies](#orge92e06b)
    - [Two-Layer Architecture](#org6172caa)
    - [Cross-Cutting Simplifications](#orgbbd91dd)
  - [NTT (Network Type Theory)  — *Typing discipline for propagator networks themselves*](#org97020a9)
    - [Research Documents](#org4f6b219)
    - [The 7-Level Type Tower](#org1249359)
    - [Self-Hosting Trajectory](#org0da5e30)
- [Completed Standalone Tracks (not part of a Series)](#org29e1623)
- [Standalone Design Documents (Not Yet Implemented / Future Scope)](#org1752851)
- [Audits](#org11a6928)
- [Research Documents](#org5902333)
  - [Active Research (feeding current design)](#orgef3f7e2)
  - [Completed/Background Research](#org4bd85ad)
- [Principles Documents](#org17aa87f)
- [Deferred Work](#org1aaa66f)
- [Current Implementation Order](#orgec2ddb6)
- [Cross-Series Dependencies](#orgb4774db)



<a id="org15bdd7a"></a>

# Purpose

This document is the top-level index into all organized work in Prologos. It tracks active Series, standalone Tracks, and completed efforts — with links to detailed design documents, PIRs, audits, and Master Roadmaps.

Consult this document to answer: "What's in flight? What's next? Where is the design for X?"

See [WORK<sub>STRUCTURE.org</sub>](principles/WORK_STRUCTURE.md) for how work units (Series, Tracks, Phases, Audits) are defined.


<a id="org502485c"></a>

# Active Series


<a id="org430a7d0"></a>

## Propagator Migration  — *Bringing elaboration state onto the propagator network*

|                    |                                                                                                                                                                                                                                                                          |
|------------------ |------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Master Roadmap** | [2026-03-13<sub>PROPAGATOR</sub><sub>MIGRATION</sub><sub>MASTER.md</sub>](2026-03-13_PROPAGATOR_MIGRATION_MASTER.md)                                                                                                                                                     |
| **Thesis**         | Every piece of mutable state that participates in type-checking flows through one unified propagator network.                                                                                                                                                            |
| **Status**         | Tracks 1–8D complete. Tracks 8E–11 pending. Track 8 delivered: TMS-tagged state, worldview-aware reads, restore-meta-state! retirement, 14/23 callbacks eliminated, HKT impl/resolution, bridge propagators (trait/hasmethod/constraint-retry), pure α/γ fire functions. |


<a id="orgc5f5d1d"></a>

### Completed Tracks

| Track                                                                  | Description                                          | PIR                                                         | Key Result                                                                                                  |
|---------------------------------------------------------------------- |---------------------------------------------------- |----------------------------------------------------------- |----------------------------------------------------------------------------------------------------------- |
| [Foundation](2026-03-11_1800_PROPAGATOR_FIRST_MIGRATION.md)            | Cell abstraction, 42 state sites migrated            | —                                                           | Dual-write cells for all propagator-natural state                                                           |
| [Track 1](2026-03-12_TRACK1_CONSTRAINT_CELL_PRIMARY.md)                | Cell-primary constraint tracking                     | [PIR](2026-03-12_TRACK1_CELL_PRIMARY_PIR.md)                | Cells are single source of truth for constraints                                                            |
| [Track 2](2026-03-13_TRACK2_REACTIVE_RESOLUTION_DESIGN.md)             | Reactive resolution (stratified quiescence)          | —                                                           | S0→S1→S2 replaces batch post-passes                                                                         |
| [Track 3](2026-03-13_TRACK3_CELL_PRIMARY_REGISTRIES.md)                | Cell-primary registries (28 readers)                 | [PIR](2026-03-16_TRACK3_CELL_PRIMARY_REGISTRIES_PIR.md)     | All computation reads are cell-primary                                                                      |
| [Track 4](2026-03-16_TRACK4_ATMS_SPECULATION.md)                       | ATMS speculation (per-meta TMS cells)                | [PIR](2026-03-16_TRACK4_ATMS_SPECULATION_PIR.md)            | Learned-clause pruning, save/restore 6→3 boxes                                                              |
| [Track 5](2026-03-16_TRACK5_GLOBAL_ENV_DEPENDENCY_EDGES.md)            | Global-env consolidation + dependency edges          | [PIR](2026-03-16_TRACK5_GLOBAL_ENV_DEPENDENCY_EDGES_PIR.md) | Per-module persistent networks, cross-module dep edges                                                      |
| [Track 6](2026-03-16_TRACK6_DRIVER_SIMPLIFICATION.md)                  | Driver simplification + cleanup                      | [PIR](2026-03-17_TRACK6_DRIVER_SIMPLIFICATION_PIR.md)       | Parameterize 30→13, callback elimination, first clean suite                                                 |
| [Track 7](2026-03-18_TRACK7_PERSISTENT_CELLS_STRATIFIED_RETRACTION.md) | Persistent registry cells + stratified retraction    | [PIR](2026-03-18_TRACK7_PIR.md)                             | 29 persistent cells, S(−1) retraction, readiness propagators, pure resolution                               |
| [Track 8](2026-03-21_TRACK8_DESIGN.md)                                 | Infrastructure migration + HKT + bridge propagators  | [PIR](2026-03-22_TRACK8_PIR.md)                             | TMS-tagged state, worldview-aware reads, pure α/γ bridges, HKT impl/resolution, restore-meta-state! retired |
| [Track 8D](2026-03-22_TRACK8D_DESIGN.md)                               | Pure bridge fire functions (Completeness correction) | [PIR §12](2026-03-22_TRACK8_PIR.md)                         | Bridges read cells directly via net-cell-read; no zonk, no box, no with-enet-reads                          |


<a id="org836837c"></a>

### Pending Tracks

| Track    | Description                                                         | Status                                                                          | Design/Audit                                                                            |
|-------- |------------------------------------------------------------------- |------------------------------------------------------------------------------- |--------------------------------------------------------------------------------------- |
| Track 8E | Remaining registries + warnings as cells (17 registries)            | Scoped in [Unified Roadmap](./2026-03-22_UNIFIED_PROPAGATOR_NETWORK_ROADMAP.md) | Depends on Track 8D                                                                     |
| Track 8F | Meta-info as cells (solve-meta! → cell-write)                       | Scoped in Unified Roadmap                                                       | Depends on Track 8E                                                                     |
| Track 9  | Reduction as Propagators — interaction nets, GoI, e-graph rewriting | Stage 1 research                                                                | [Research note](2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md); may become Track Series |
| Track 10 | Network-first init + box elimination                                | Scoped in Unified Roadmap                                                       | Depends on Track 8F; may become Track Series                                            |
| Track 11 | LSP Integration — incremental re-elaboration, live diagnostics      | Not started                                                                     | [Early notes](2026-03-19_TRACK10_DESIGN_NOTES.md); depends on Track 9 + Track 10        |

Track 8 (complete) unblocked CIU Series Tracks 3–5 and BSP-LE. Track 9 enables interaction-net reduction, GoI-style fixpoint computation, e-graph equality saturation. Track 10 is the convergence point: no box, no dual-writes, module loading on-network. See [Unified Propagator Network Infrastructure Roadmap](./2026-03-22_UNIFIED_PROPAGATOR_NETWORK_ROADMAP.md) for the comprehensive on-network/off-network boundary analysis.

**Note on PUnify**: PUnify Parts 1–2 originated as the first half of Track 8's scope (cell-tree unification for the type-level and solver-level systems). The scope was large enough that it was broken out as an independent effort with its own design documents and PIR. PUnify's cell-tree infrastructure is now a prerequisite for BSP-LE Track 2 (ATMS Solver) and is the foundation for the SRE Series.


<a id="orge0be547"></a>

## BSP-LE  — *The Logic Engine, realized on propagators*

|                    |                                                                                                                                                                       |
|------------------ |--------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Master Roadmap** | [2026-03-21<sub>BSP</sub><sub>LE</sub><sub>MASTER.md</sub>](2026-03-21_BSP_LE_MASTER.md)                                                                              |
| **Thesis**         | Choice points are ATMS assumptions, conjunction is worklist scheduling, backtracking is nogood accumulation, tabling is cell quiescence, parallel exploration is BSP. |
| **Status**         | Track 0 complete. Tracks 1–5 pending.                                                                                                                                 |
| **Origin**         | [Logic Engine Design (Phases 4–7)](2026-02-24_LOGIC_ENGINE_DESIGN.md), [PUnify Part 3 (Multiverse Multiplexer)](2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md)  |


<a id="org8ab4d25"></a>

### Tracks

| Track | Description                               | Status                                                                                                                                                                                                         | Depends On                                                                                                        |
|----- |----------------------------------------- |-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |----------------------------------------------------------------------------------------------------------------- |
| 0     | Allocation Efficiency                     | ✅ [Design](2026-03-21_BSP_LE_TRACK0_ALLOCATION_EFFICIENCY_DESIGN.md) [PIR](2026-03-21_BSP_LE_TRACK0_PIR.md) + [CHAMP](2026-03-21_CHAMP_PERFORMANCE_DESIGN.md) [CHAMP PIR](2026-03-21_CHAMP_PERFORMANCE_PIR.md) | — ([Audit](2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md), [CHAMP Audit](2026-03-21_CHAMP_PERFORMANCE_AUDIT.md)) |
| 1     | UnionFind (persistent disjoint sets)      | ⬜                                                                                                                                                                                                             | Track 0                                                                                                           |
| 2     | ATMS Solver (Multiverse Multiplexer)      | ⬜                                                                                                                                                                                                             | Track 0                                                                                                           |
| 3     | Tabling (SLG memoization)                 | ⬜                                                                                                                                                                                                             | Track 2                                                                                                           |
| 4     | BSP Pipeline (Kan extension architecture) | ⬜                                                                                                                                                                                                             | Track 3                                                                                                           |
| 5     | Solver Language                           | ⬜                                                                                                                                                                                                             | All previous                                                                                                      |


<a id="org60ed52f"></a>

### Prerequisites

| Item                                             | Status                                                                                                                                                                                                                                                                               |
|------------------------------------------------ |------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| PUnify Parts 1–2 (cell-tree unification)         | ✅ Complete ([PIR](2026-03-19_PUNIFY_PARTS1_2_PIR.md))                                                                                                                                                                                                                               |
| PUnify Cleanup (toggle flip + bridge retirement) | ⬜ BLOCKED: Option module loading hangs with punify ON. 2/5 parity bugs fixed (Phase -1); 3/5 reclassified as fixture gaps. Toggle flip blocked by Option hang — needs cell-tree unification debugging for sum types during module loading. Bridge retirement depends on toggle flip. |


<a id="org798acc8"></a>

## CIU (Collection Interface Unification)  — *All collection dispatch through traits on the propagator network*

|                    |                                                                                                                                                                                       |
|------------------ |------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Master Roadmap** | [2026-03-21<sub>CIU</sub><sub>MASTER.md</sub>](2026-03-21_CIU_MASTER.md)                                                                                                              |
| **Thesis**         | Syntactic sugar generates trait constraints resolved on the propagator network — not constructor-specific dispatch. User-defined collections participate in all syntax automatically. |
| **Status**         | Track 0 complete. Tracks 1–2 pre-Track 8; Tracks 3–5 post-Track 8.                                                                                                                    |
| **Origin**         | [Collection Interface Audit](2026-03-20_COLLECTION_INTERFACE_AUDIT.md), [Unification Design](2026-03-20_COLLECTION_INTERFACE_UNIFICATION_DESIGN.md)                                   |


<a id="org50addb0"></a>

### Tracks

| Track | Description                                                  | Status                                                    | Pre/Post Track 8 |
|----- |------------------------------------------------------------ |--------------------------------------------------------- |---------------- |
| 0     | Trait Hierarchy Design (deep Stage 2)                        | ✅ [Audit](2026-03-21_CIU_TRACK0_TRAIT_HIERARCHY_AUDIT.md) | Pre              |
| 1     | Seq Protocol (Seq-as-trait, native instances, LSeq demotion) | ⬜                                                        | Pre              |
| 2     | Syntactic Sugar Normalization (dot-brace, ground-expr? fix)  | ⬜                                                        | Pre              |
| 3     | Trait-Dispatched Access (`surf-get` generates constraints)   | ⬜                                                        | Post Track 8     |
| 4     | Trait-Dispatched Iteration (broadcast via Seq)               | ⬜                                                        | Post Track 8     |
| 5     | Union-Aware Dispatch                                         | ⬜                                                        | Post Track 8     |


<a id="orge5c0654"></a>

## SRE (Structural Reasoning Engine)  — *PUnify as universal structural decomposition/composition substrate*

|            |                                                                                                                                                                                                                                                                        |
|---------- |---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Thesis** | PUnify is not "the unification algorithm on propagators" — it is the universal structural reasoning engine. Every system that analyzes, decomposes, or matches structure (elaboration, trait resolution, pattern compilation, reduction) uses the same SRE primitives. |
| **Status** | Track 0 complete. Track 1 next.                                                                                                                                                                                                                                        |
| **Master** | [SRE Series Master Tracking](2026-03-22_SRE_MASTER.md)                                                                                                                                                                                                                 |
| **Origin** | [SRE Research (2026-03-22)](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md), Track 8D principles audit                                                                                                                                                          |


<a id="org57fc61b"></a>

### Key Insight

The elaborator manually creates cells and installs propagators for every AST node. But this IS structural decomposition — exactly what PUnify's `structural-unify-propagator`, `identify-sub-cell`, `get-or-create-sub-cells` already do. The elaborator becomes: create cells, call `structural-relate`, recurse. PUnify installs the propagators. Bidirectional type checking partially dissolves (the SRE propagates both directions).


<a id="orgb08acfa"></a>

### Tracks

| Track                                              | Description                                                                                    | Status                                | Depends On                                                          |
|-------------------------------------------------- |---------------------------------------------------------------------------------------------- |------------------------------------- |------------------------------------------------------------------- |
| [0](2026-03-22_SRE_TRACK0_FORM_REGISTRY_DESIGN.md) | SRE Form Registry — domain-parameterized structural decomposition                              | ✅ [PIR](2026-03-22_SRE_TRACK0_PIR.md) | sre-core.rkt: 6 functions, 23 type ctor-descs, term-value validated |
| 0.5                                                | Structural Relation Engine — parameterize by relation (equality, subtyping, duality, coercion) | ⬜                                    | Track 0                                                             |
| 1                                                  | Elaborator-on-SRE — typing-core as structural-relate calls                                     | ⬜                                    | Track 0                                                             |
| 2                                                  | Trait Resolution-on-SRE — impl lookup via structural matching                                  | ⬜                                    | Track 0.5 (subtyping)                                               |
| 3                                                  | Session Types-on-SRE — duality via involution relation                                         | ⬜                                    | Track 0.5 (duality)                                                 |
| 4                                                  | Pattern Compilation-on-SRE — scrutinee decomposition via SRE                                   | ⬜                                    | Track 0                                                             |
| 5                                                  | Reduction-on-SRE — interaction nets, e-graph, GoI                                              | ⬜                                    | Track 1, PM 8F; IS PM Track 9                                       |
| 6                                                  | Module Loading-on-SRE — exports/imports as structural matching                                 | ⬜                                    | Track 1; IS PM Track 10 (partial)                                   |


<a id="orge92e06b"></a>

### SRE ↔ PM Cross-Dependencies

```
PM Series (state migration)          SRE Series (system migration)
─────────────────────────            ────────────────────────────
PM 8D ✅ (bridges+registries)    →   SRE Track 0 ✅ (form registry)
PM 8E (17 registries as cells)   ↔   SRE Track 1 (elaborator-on-SRE)
                                      SRE Track 0.5 (relation engine)
                                      SRE Track 2 (trait resolution)
                                      SRE Track 3 (sessions)
                                      SRE Track 4 (pattern compilation)
PM 8F (meta-info as cells)       ↔   SRE Track 5 (reduction-on-SRE)
PM Track 9 = SRE Track 5
PM Track 10                      =   SRE Track 6 (module loading)
```

**Recommended interleaved ordering**:

1.  SRE Track 1 → 2. PM 8E → 3. SRE Track 0.5 → 4. SRE Track 2 →
2.  SRE Tracks 3+4 (parallel) → 6. PM 8F → 7. SRE Track 5/PM 9 →
3.  SRE Track 6/PM 10 (convergence)


<a id="org6172caa"></a>

### Two-Layer Architecture

-   **Layer 1: SRE** (within-domain): Registered structural forms, decomposition/composition propagators
-   **Layer 2: Galois Bridges** (between-domain): Pure α/γ connections between different lattice domains

Both layers live on the same propagator network and compose automatically. The SRE makes within-domain reasoning automatic; bridges make between-domain reasoning automatic.


<a id="orgbbd91dd"></a>

### Cross-Cutting Simplifications

When elaboration, resolution, matching, and reduction all use the SRE:

-   **Zonk** → eliminated during elaboration (cell reads are current)
-   **Ground-check** → cell-level property (propagator watches sub-cells)
-   **Occurs check** → graph cycle detection in cell dependency graph
-   **Error reporting** → contradiction cells accumulate structural info
-   **Incremental re-elaboration** → propagation (dependency graph IS the incremental compilation graph)
-   **Speculation** → unified TMS across all SRE-based systems


<a id="org97020a9"></a>

## NTT (Network Type Theory)  — *Typing discipline for propagator networks themselves*

|            |                                                                                                                                                                                                                                                                                                                                                                               |
|---------- |----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Thesis** | Propagator networks have a natural type theory: lattice types → cell types → propagator types → network types (polynomial functors) → bridge types (Galois connections) → stratification types → fixpoint/interaction types. Dependent types express monotonicity, adjunction laws, well-foundedness. Progressive disclosure hides the categorical structure from most users. |
| **Status** | Stage 0-1 research. 4 research documents scoped.                                                                                                                                                                                                                                                                                                                              |
| **Origin** | Track 8D principles audit, 2026-03-22 outside conversation on typing a network                                                                                                                                                                                                                                                                                                |


<a id="org4f6b219"></a>

### Research Documents

| # | Document                                             | Stage | Status        | Scope                                                                                                                                                 |
|--- |---------------------------------------------------- |----- |------------- |----------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | Categorical Foundations of Typed Propagator Networks | 0-1   | 🔄 In progress | Polynomial functors vs PROPs; Grothendieck fibrations over stratum posets; Kan extensions; quantale enrichment; relationship to Five Systems analysis |
| 2 | Network Type Theory for Prologos                     | 1-2   | ⬜ Next       | 7-level type tower; dependent types for monotonicity/adjunction/well-foundedness; progressive disclosure layers; trait system integration             |
| 3 | Language Design: Network Type Ergonomics             | 2     | ⬜            | Surface syntax for `lattice`, `cell`, `propagator`, `network`, `bridge`, `stratification`; composition with `spec`, `schema`, `functor`, `bundle`     |
| 4 | Engineering: Self-Hosting via Network Types          | 1-2   | ⬜            | SRE form registry as polynomial functor data model; compile-time type checking cost; bootstrapping strategy; workstream ordering                      |


<a id="org1249359"></a>

### The 7-Level Type Tower

| Level | Type                 | Categorical Structure                                      | What It Guarantees                                   |
|----- |-------------------- |---------------------------------------------------------- |---------------------------------------------------- |
| 0     | Lattice Type         | Carrier + partial order + join + ⊥                         | Values combine monotonically                         |
| 1     | Cell Type            | `Cell L` parameterized by lattice                          | Writes are joins, not replaces                       |
| 2     | Propagator Type      | `Prop [Cell L₁...] → Cell L₂` + `:where Monotone`          | Output ≥ f(inputs) in lattice order                  |
| 3     | Network Type         | Polynomial functor `P(y) = Σ_{i∈I} y^{B_i}`                | Typed interfaces, compositional wiring               |
| 4     | Bridge Type          | Galois connection + adjunction laws                        | Sound cross-domain information flow                  |
| 5     | Stratification Type  | Grothendieck fibration over stratum poset                  | Monotone within fibers, non-monotone across barriers |
| 6     | Fixpoint/Interaction | lfp (inductive) / gfp (coinductive) / Left Kan / Right Kan | Convergence, demand-driven/speculative interaction   |


<a id="org0da5e30"></a>

### Self-Hosting Trajectory

1.  Build SRE in Racket (type-informed: carry lattice/monotonicity annotations as data)
2.  Express network types in Prologos (dependent types + trait system)
3.  Use Prologos network types to verify SRE form registrations ← **inflection point**
4.  Express elaborator as SRE `structural-relate` calls
5.  Express type checker as stratified propagator network
6.  Compiler is a Prologos program that type-checks itself


<a id="org29e1623"></a>

# Completed Standalone Tracks (not part of a Series)

These are Tracks that were independently scoped and completed outside of any Series.

| Track                       | Date       | Design                                                                                                                               | PIR                                         | Key Result                                                                                                          |
|--------------------------- |---------- |------------------------------------------------------------------------------------------------------------------------------------ |------------------------------------------- |------------------------------------------------------------------------------------------------------------------- |
| First-Class Paths           | 2026-03-20 | [Design](2026-03-20_FIRST_CLASS_PATHS_DESIGN.md)                                                                                     | —                                           | Phases 0–7c: 14-file pipeline, broadcast `.*field`, renaming `^`. Phase 8 (Lens) deferred.                          |
| First-Class Traits          | 2026-03-09 | [Design](2026-03-09_FIRST_CLASS_TRAITS_STAGE3_DESIGN.md)                                                                             | [PIR](2026-03-09_FIRST_CLASS_TRAITS_PIR.md) | All 11 sub-phases: trait/impl/bundle/spec/defn/schema surface syntax.                                               |
| FL Narrowing                | 2026-03-07 | [Design](../research/2026-03-07_FL_NARROWING_DESIGN.md)                                                                              | [PIR](2026-03-08_FL_NARROWING_PIR.md)       | Definitional trees, residuation-first, term lattice.                                                                |
| Narrowing + Abstract Interp | 2026-03-07 | [Design](2026-03-07_NARROWING_ABSTRACT_INTERPRETATION_DESIGN.md)                                                                     | —                                           | All phases ✅: DT extraction, term lattice, narrowing propagator.                                                   |
| IO Implementation           | 2026-03-05 | [Design](2026-03-05_IO_IMPLEMENTATION_DESIGN.md)                                                                                     | [PIR](2026-03-06_IO_IMPLEMENTATION_PIR.md)  | IO-A through IO-J: file, net, session IO.                                                                           |
| Effectful Computation (A+D) | 2026-03-07 | [Design](2026-03-07_ARCHITECTURE_AD_IMPLEMENTATION_DESIGN.md)                                                                        | [PIR](2026-03-07_ARCHITECTURE_AD_PIR.md)    | AD-A through AD-F: effect position lattice, Galois bridge, effect ordering, executor, ATMS branching.               |
| Session Types               | 2026-03-03 | [Design](2026-03-03_SESSION_TYPE_DESIGN.md)                                                                                          | [PIR](2026-03-04_SESSION_TYPE_PIR.md)       | Protocol types, duality, propagator-based session checking.                                                         |
| Explain / Provenance        | 2026-03-14 | [Design](2026-03-14_EXPLAIN_PROVENANCE_DESIGN.md)                                                                                    | —                                           | All 7 phases complete: derivation trees for relational queries.                                                     |
| Well-Founded LE             | 2026-03-14 | [Design](2026-03-14_WELL_FOUNDED_LOGIC_ENGINE_DESIGN.md)                                                                             | [PIR](2026-03-14_WFLE_PIR.md)               | Bilattice oracle, WF-NAF, 3-valued negation.                                                                        |
| Propagator Visualization    | 2026-03-12 | [Design](2026-03-12_PROPAGATOR_VISUALIZATION_DESIGN.md)                                                                              | —                                           | Phases 0–5c ✅: trace capture, JSON serialization, LSP handler, WebView graph, timeline slider. 5d + 6a-6d deferred. |
| PUnify Parts 1–2            | 2026-03-19 | [P1 Design](2026-03-19_PUNIFY_STRUCTURAL_UNIFICATION_PROPAGATORS.md), [P2 Design](2026-03-19_PUNIFY_PART2_CELL_TREE_ARCHITECTURE.md) | [PIR](2026-03-19_PUNIFY_PARTS1_2_PIR.md)    | Cell-tree unification, descriptor registry, polymorphic solver dispatch. Breakout from Track 8 first half.          |
| BSP-LE Track 0              | 2026-03-21 | [Design](2026-03-21_BSP_LE_TRACK0_ALLOCATION_EFFICIENCY_DESIGN.md)                                                                   | [PIR](2026-03-21_BSP_LE_TRACK0_PIR.md)      | hot/warm/cold struct split, mutable worklist, batch API. GC eliminated on hot path; wall-time neutral.              |
| CHAMP Performance           | 2026-03-21 | [Design](2026-03-21_CHAMP_PERFORMANCE_DESIGN.md)                                                                                     | [PIR](2026-03-21_CHAMP_PERFORMANCE_PIR.md)  | Owner-ID transients (16× faster at N=2), eq?-first, value-only fast path. Track 0 Phase 5 rehabilitated.            |


<a id="org1752851"></a>

# Standalone Design Documents (Not Yet Implemented / Future Scope)

Design documents that exist but are not currently scoped into active work. They may be promoted to Tracks when their prerequisites are met or the project roadmap reaches them.

| Document                                                                 | Status                       | Notes                                                                            |
|------------------------------------------------------------------------ |---------------------------- |-------------------------------------------------------------------------------- |
| [Capabilities as Types](2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md) | Design complete, not started | Capability hierarchy, QTT enforcement, ATMS provenance                           |
| [IO Library V2](2026-03-05_IO_LIBRARY_DESIGN_V2.md)                      | Design/research              | Extended IO: Bytes type, binary IO, SQLite FFI                                   |
| [IO Library V1](2026-03-01_1200_IO_LIBRARY_DESIGN.md)                    | Superseded by V2             | Original IO design                                                               |
| [Track 10 Design Notes (Provenance)](2026-03-19_TRACK10_DESIGN_NOTES.md) | Notes only                   | Two-tier provenance, LSP integration; scoped under Propagator Migration Track 10 |
| [Relational Fact Design](2026-03-06_1400_RELATIONAL_FACT_DESIGN.md)      | Design discussion            | Captured from mobile session                                                     |
| [Path Algebra](2026-03-03_PATH_ALGEBRA_DESIGN.md)                        | Superseded                   | Extended by First-Class Paths                                                    |
| [Schema/Selection](2026-03-02_2200_SCHEMA_SELECTION_DESIGN.md)           | Implemented                  | Part of First-Class Traits                                                       |


<a id="org11a6928"></a>

# Audits

| Audit                                                                                | Date       | Status | Motivated                                    |
|------------------------------------------------------------------------------------ |---------- |------ |-------------------------------------------- |
| [Pipeline Audit](../research/2026-03-11_PROPAGATOR_FIRST_PIPELINE_AUDIT.md)          | 2026-03-11 | ✅     | Propagator Migration Foundation + Tracks 1–7 |
| [LE Subsystem Audit](2026-03-03_LE_SUBSYSTEM_AUDIT.md)                               | 2026-03-03 | ✅     | Logic Engine Design                          |
| [WS-Mode Audit](2026-03-10_WS_MODE_AUDIT.md)                                         | 2026-03-10 | ✅     | Three-level WS validation protocol           |
| [Generic Numerics Audit](2026-03-11_GENERIC_NUMERICS_AUDIT.md)                       | 2026-03-11 | ✅     | Numeric trait instances                      |
| [Stratified Architecture Audit](2026-03-18_STRATIFIED_ARCHITECTURE_AUDIT.md)         | 2026-03-18 | ✅     | Track 7 S(−1) retraction design              |
| [Track 8 Infrastructure Audit](2026-03-18_TRACK8_PROPAGATOR_INFRASTRUCTURE_AUDIT.md) | 2026-03-18 | ✅     | Track 8 design direction                     |
| [Cell/Propagator Allocation Audit](2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md)   | 2026-03-20 | ✅     | BSP-LE Track 0 (Allocation Efficiency)       |
| [Collection Interface Audit](2026-03-20_COLLECTION_INTERFACE_AUDIT.md)               | 2026-03-20 | ✅     | CIU Series                                   |
| [CHAMP Performance Audit](2026-03-21_CHAMP_PERFORMANCE_AUDIT.md)                     | 2026-03-21 | ✅     | CHAMP Performance Track                      |


<a id="org5902333"></a>

# Research Documents

See `docs/research/` for the full set.


<a id="orgef3f7e2"></a>

## Active Research (feeding current design)

| Document                                                                             | Date       | Stage | Feeds Into         |
|------------------------------------------------------------------------------------ |---------- |----- |------------------ |
| [Structural Reasoning Engine](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) | 2026-03-22 | 0-1   | SRE Series scoping |
| Categorical Foundations of Typed Propagator Networks                                 | 2026-03-22 | 0-1 🔄 | NTT Research Doc 1 |
| Network Type Theory for Prologos                                                     | —          | 1-2 ⬜ | NTT Research Doc 2 |
| Language Design: Network Type Ergonomics                                             | —          | 2 ⬜  | NTT Research Doc 3 |
| Engineering: Self-Hosting via Network Types                                          | —          | 1-2 ⬜ | NTT Research Doc 4 |


<a id="org4bd85ad"></a>

## Completed/Background Research

| Document                                                                                                 | Date       | Relevance                                                               |
|-------------------------------------------------------------------------------------------------------- |---------- |----------------------------------------------------------------------- |
| [Propagator Network Taxonomy](../research/2026-03-21_PROPAGATOR_NETWORK_TAXONOMY.md)                     | 2026-03-21 | Cross-disciplinary classification of propagator architecture            |
| [Categorical Structure of Five Systems](../research/2026-03-21_CATEGORICAL_STRUCTURE_FIVE_SYSTEMS.md)    | 2026-03-21 | Precise categorical characterization of each subsystem; feeds NTT Doc 1 |
| [Layered Recovery Categorical Analysis](../research/2026-03-13_LAYERED_RECOVERY_CATEGORICAL_ANALYSIS.md) | 2026-03-13 | Opfibration framework for layered recovery principle; feeds NTT Doc 1   |
| [Next-Gen Logic Programming](../research/2026-03-16_NEXT_GEN_LOGIC_PROGRAMMING.md)                       | 2026-03-16 | Survey: tabling, constraints, parallelism in modern LP                  |
| [Propagators as Model Checkers](../research/2026-03-07_PROPAGATORS_AS_MODEL_CHECKERS.md)                 | 2026-03-07 | Verification via propagator infrastructure                              |
| [Formal Modeling on Propagators](../research/2026-03-14_FORMAL_MODELING_ON_PROPAGATORS.md)               | 2026-03-14 | Formal methods perspective on the architecture                          |


<a id="org17aa87f"></a>

# Principles Documents

These are the design cornerstones that all work builds against:

| Document                                                                                       | Scope                                                               |
|---------------------------------------------------------------------------------------------- |------------------------------------------------------------------- |
| [DESIGN<sub>METHODOLOGY.org</sub>](principles/DESIGN_METHODOLOGY.md)                           | Five design stages, critique cycles, WS validation protocol         |
| [DESIGN<sub>PRINCIPLES.org</sub>](principles/DESIGN_PRINCIPLES.md)                             | Language design principles: decomplection, traits, propagators, Seq |
| [WORK<sub>STRUCTURE.org</sub>](principles/WORK_STRUCTURE.md)                                   | How we organize work: Series, Tracks, Audits, Phases                |
| [POST<sub>IMPLEMENTATION</sub><sub>REVIEW.org</sub>](principles/POST_IMPLEMENTATION_REVIEW.md) | PIR methodology: 16 questions, template, anti-patterns              |
| [DEVELOPMENT<sub>LESSONS.org</sub>](principles/DEVELOPMENT_LESSONS.md)                         | Accumulated lessons from implementation                             |
| [PATTERNS<sub>AND</sub><sub>CONVENTIONS.org</sub>](principles/PATTERNS_AND_CONVENTIONS.md)     | Naming, Nat vs Int, coding conventions                              |
| [LANGUAGE<sub>VISION.org</sub>](principles/LANGUAGE_VISION.md)                                 | Language vision and identity                                        |
| [ERGONOMICS.org](principles/ERGONOMICS.md)                                                     | Ergonomics principles and selective disclosure                      |
| [RELATIONAL<sub>LANGUAGE</sub><sub>VISION.org</sub>](principles/RELATIONAL_LANGUAGE_VISION.md) | Three-layer model for relational programming                        |


<a id="org1aaa66f"></a>

# Deferred Work

See [DEFERRED.md](DEFERRED.md) for the single source of truth on deferred items. Last consolidated sweep: 2026-03-20.

Key high-priority deferred items now absorbed into Series:

-   `Seq` as proper trait → CIU Track 0/1
-   Allocation efficiency → BSP-LE Track 0
-   `restore-meta-state!` retirement → Propagator Migration Track 8


<a id="orgec2ddb6"></a>

# Current Implementation Order

The following sequence reflects the current prioritization, informed by dependency analysis and leverage:

```
 1. PUnify Cleanup          (pre-Series: 5 parity bugs + bridge retirement)  BLOCKED (Option hang)
 2. BSP-LE Track 0          (Allocation Efficiency)                          ✅ (PIR 00a873f)
 2b. CHAMP Performance       (Owner-ID transients — standalone)              ✅ (PIR b748e5d)
 3. CIU Track 0             (Trait Hierarchy Audit)                          ✅ (commit f62fc06)
 4. PM Track 8              (Parts A/B/C/D — all complete)                   ✅ (PIR fe2673e)
 5. NTT Research Doc 1      (Categorical Foundations)                        ← ACTIVE
 6. NTT Research Doc 2      (Network Type Theory — discussion)              ← NEXT
 7. SRE Series scoping      (Tracks 0–4, informed by NTT research)
 8. PM Track 8E             (17 remaining registries as cells)
 9. CIU Tracks 1–5          (implementation on Track 8 infrastructure)
10. BSP-LE Tracks 1–5       (logic engine on Track 8 infrastructure)
11. PM Track 8F → 9 → 10    (meta-info cells, reduction, box elimination)
```

**Rationale** (updated post-Track 8):

-   **NTT research before further infrastructure**: The SRE + NTT insights fundamentally reframe how we approach PM Tracks 8E–10, BSP-LE, and CIU. Building infrastructure without the type-informed data model means retrofitting later. Research Docs 1–2 establish the categorical foundations and type tower that inform the SRE form registry design.

-   **SRE Series scoping depends on NTT**: The SRE form registry's data model should carry typing information from day one (lattice types, monotonicity class, component types). This "types-ready" approach means the transition from annotated-but-unchecked to checked is a toggle, not a rewrite.

-   **PM 8E before CIU/BSP-LE**: The 17 remaining registries (warnings, debug, parsing state) becoming cells further reduces the imperative surface area. CIU Track 3 (`surf-get` constraint generation) benefits from registry cells being propagation-visible.

-   **PM Tracks 8F–10 may become Track Series** given scope: meta-info as cells (8F), reduction as propagators (9), and network-first init (10) each have enough internal structure for multiple sub-tracks.

Steps 9 and 10 are not strictly sequential — CIU and BSP-LE Tracks can interleave based on priority and what's unblocked.


<a id="orgb4774db"></a>

# Cross-Series Dependencies

```
PM Track 8 ✅ ─────────────────┬──→ CIU Tracks 3–5 (UNBLOCKED)
                               ├──→ BSP-LE Tracks 1–5 (UNBLOCKED)
                               ├──→ PM Track 8E → 8F → 9 → 10
                               │
NTT Research Docs 1–4 ────────┼──→ SRE Series scoping
                               │     ├──→ SRE Track 0 (Form Registry) ✅
                               │     ├──→ SRE Track 1 (Subtyping Relations)
                               │     ├──→ SRE Track 2 (Elaborator-on-SRE)
                               │     └──→ SRE Tracks 3–4
                               │
SRE Track 0 ✅ ───────────────┴──→ PM Track 9 (Reduction-on-SRE)
                                   PM Track 10 (Network-first init)
```

The SRE Series is the new architectural foundation. NTT research informs its design. PM Tracks 8E–10 and SRE Tracks can interleave — each delivers standalone value. The convergence point (PM Track 10 + SRE Track 1) is where the box disappears and the elaborator runs on the SRE.
