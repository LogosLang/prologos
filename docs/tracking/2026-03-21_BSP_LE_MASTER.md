# BSP-LE Series: The Logic Engine, Realized

**Created**: 2026-03-21
**Status**: Series inception — Tracks being scoped
**Thesis**: The logic engine operates as a BSP propagator network with ATMS-managed worldview exploration, completing the vision from the Logic Engine Design (Phases 4-7) on the infrastructure Tracks 1-7 and PUnify Parts 1-2 established.

---

## Series Thesis

> Every piece of the logic engine — unification, search, tabling, negation, constraint solving — operates on propagator cells and communicates through lattice merges. Choice points are ATMS assumptions. Conjunction is worklist scheduling. Backtracking is nogood accumulation. Tabling is cell quiescence. Parallel exploration is BSP. The solver language makes all of this user-configurable.

This thesis is the realization of the Logic Engine Design document (`2026-02-24_LOGIC_ENGINE_DESIGN.org`, Phases 4-7), built on the infrastructure delivered by:
- **Propagator Migration Series** (Tracks 1-7): persistent cells, stratified retraction, readiness propagators, pure resolution
- **PUnify Parts 1-2**: cell-tree unification substrate, constructor descriptor registry, polymorphic solver dispatch

## Origin Documents

| Document | Role |
|----------|------|
| `2026-02-24_LOGIC_ENGINE_DESIGN.org` | Comprehensive blueprint — Phases 4-7 define BSP-LE scope |
| `2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md` | Detailed architectural vision — the "Multiverse Multiplexer" |
| `2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md` | Infrastructure prerequisite — allocation efficiency |
| `2026-03-21_CATEGORICAL_STRUCTURE_FIVE_SYSTEMS.org` | Categorical grounding — precise structure of each subsystem |
| `2026-03-21_PROPAGATOR_NETWORK_TAXONOMY.org` | Cross-disciplinary classification and theoretical context |
| `RELATIONAL_LANGUAGE_VISION.org` | Three-layer model, solver language vision |
| `2026-03-07_FL_NARROWING_DESIGN.org` | Definitional trees, residuation-first principle |
| `2026-03-14_WELL_FOUNDED_LOGIC_ENGINE_DESIGN.md` | WF-LE bilattice oracle design |

### External Context: Categorical Recommendations for BSP

Captured in `standups/standup-2026-03-21.org` § "Categorical Recommendations for BSP":

- **Left Kan extensions for pipelined strata**: Speculatively forward partial fixpoints between strata within BSP supersteps. Monotonicity of the pushforward guarantees soundness — speculative results are always below eventual fixpoint, so stratum n+1 never needs to retract, only continue propagating when more information arrives.
- **Right Kan extensions for demand-driven forwarding**: Stratum n+1 registers threshold interests in specific stratum-n cells. Barriers forward only demanded cells, enabling partial barriers and earlier quiescence.
- **Polynomial functor interfaces**: Network topology as polynomial functor maps — formal module boundaries for propagator networks with guaranteed composition.
- **Operads for propagator typing**: Multi-input propagators as multimorphisms in a colored operad — feeds into self-hosting story.

These inform the BSP Pipeline Track specifically and the Series architecture generally.

---

## Progress Tracker

| # | Track | Description | Status | Design Doc | Notes |
|---|-------|-------------|--------|------------|-------|
| 0 | Allocation Efficiency | struct-copy optimization, CHAMP batching, field-group splitting | ⬜ | Pending | Audit complete (`f7bd03d`); foundation track — benefits all subsequent |
| 1 | UnionFind | Persistent disjoint sets for solver state; UF + PropNetwork dual | ⬜ | Pending | LE Phase 4; can proceed in parallel with Track 2 |
| 2 | ATMS Solver | Clause-as-assumption, N-ary speculation, worldview enumeration, two-tier activation | ⬜ | Pending | LE Phase 5 + Part 3 §6; the Multiverse Multiplexer |
| 3 | Tabling | Table registry, producer/consumer propagators, SLG completion detection | ⬜ | Pending | LE Phase 6; depends on Track 2 |
| 4 | BSP Pipeline | Pipelined strata (left Kan), demand-driven forwarding (right Kan), partial barriers | ⬜ | Pending | Extends LE Phase 2.5; Kan extension architecture |
| 5 | Solver Language | Connect solver-config knobs, pre-defined configurations, surface syntax | ⬜ | Pending | LE Phase 7; depends on all previous |
| — | PUnify Cleanup | Bridge retirement (Part 2 Phase 5d), 5 parity bug fixes | ⬜ | N/A | Prerequisite cleanup before Series begins |

---

## Dependency Graph

```
PUnify Cleanup ──→ Track 0 (Allocation Efficiency)
                      │
                      ▼
              ┌───────┴───────┐
              ▼               ▼
      Track 1 (UF)    Track 2 (ATMS Solver)
              │               │
              └───────┬───────┘
                      ▼
              Track 3 (Tabling)
                      │
                      ▼
              Track 4 (BSP Pipeline)
                      │
                      ▼
              Track 5 (Solver Language)
```

**Parallelism**: Tracks 1 and 2 can proceed in parallel (LE Design explicitly notes this). Track 4 (BSP Pipeline) could potentially start alongside Track 3 if pipelined strata are orthogonal to tabling infrastructure.

**Track 8 interaction**: Track 8 (Propagator Infrastructure Migration) is a parallel Series effort. BSP-LE does not block on Track 8, but Track 8 improvements (callback elimination, module restructuring) may simplify BSP-LE implementation. Cross-Series requirements to be documented as Tracks are designed.

---

## Track Scope Summaries

### Track 0: Allocation Efficiency

**Source**: Allocation audit (`2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md`, commit `f7bd03d`)

**Why first**: Every subsequent Track creates more cells, propagators, and ATMS worldviews. The audit identifies `struct-copy prop-network` (13-field copy) as the dominant per-operation allocation cost, with 6 optimization opportunities. Fixing this first means every subsequent Track benefits.

**Scope**:
1. Mutable worklist/fuel in quiescence loop (biggest single win — eliminates struct-copy on every propagator firing)
2. Field-group struct splitting (hot/warm/cold separation)
3. Batch cell registration via transient CHAMP builder
4. Additional optimizations from audit (cell-write fast path, propagator registration batching, elab-network construction)

**Not in scope**: Incremental GC / provenance-aware reclamation (deferred — understand patterns first).

### Track 1: UnionFind

**Source**: Logic Engine Design Phase 4 (`2026-02-24_LOGIC_ENGINE_DESIGN.org` §Phase 4)

**Scope**: Persistent disjoint sets (`uf-make`, `uf-find`, `uf-union`, `uf-same?`) backed by persistent-vector path compression. Integration with the solver state as a dual representation alongside cell-trees: UF handles var-var bindings (`?x = ?y`), cell-trees handle var-value bindings (`?x = suc zero`).

**Key design question**: UF updates are monotone (union grows the equivalence class) but find has a non-monotone optimization (path compression writes). Persistent path compression returns a new UF without mutating the original — compatible with ATMS worldview branching.

### Track 2: ATMS Solver (The Multiverse Multiplexer)

**Source**: Logic Engine Design Phase 5 + Part 3 §6 (`2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md`)

**Scope**:
- Clause-as-assumption: `atms-amb` over matching clauses, replacing `append-map` DFS
- Goal-as-propagator: each goal type (app, unify, is, not, guard) becomes a propagator installation
- Conjunction as worklist scheduling: sub-goals fire when input cells have information
- Two-tier activation: `:strategy :auto` starts in Tier 1 (no ATMS overhead), upgrades to Tier 2 on first choice point
- Single-clause fast path: deterministic goals incur zero ATMS overhead
- Residuation-first: goal propagators suspend on ⊥ input cells
- Solution enumeration: ATMS worldviews → binding maps via `atms-solve-all`

**Core architectural change**: The DFS solver loop (`solve-goals` at `relations.rkt:600`) is replaced by propagator network quiescence. Search is ATMS-managed worldview exploration. Backtracking is nogood accumulation.

### Track 3: Tabling

**Source**: Logic Engine Design Phase 6 (`2026-02-24_LOGIC_ENGINE_DESIGN.org` §Phase 6)

**Scope**:
- Table registry (persistent CHAMP: predicate → table-entry)
- Producer/consumer propagators: first call to a tabled predicate is the "producer" (runs the relation body, writes answers to table cell); subsequent calls are "consumers" (read from table cell)
- SLG completion detection: a tabled predicate is "complete" when its table cell has quiesced (no new answers after a full round)
- Lattice answer modes: set-union (all answers), lattice-join (aggregation), first-answer
- `spec` metadata integration: `:tabled true/false` on specs
- BSP compatibility: table producers/consumers are BSP-compatible propagators

**Key architectural property**: Tabling uses accumulator cells with `SetLattice` merge (answers only grow). Completion = quiescence of the table cell. This is a natural fit for the propagator model — "is this tabled predicate complete?" is a threshold check on the table cell's stability.

### Track 4: BSP Pipeline

**Source**: Logic Engine Design Phase 2.5 (extended) + external categorical recommendations

**Scope**:
- **Pipelined strata (left Kan extension)**: At each BSP barrier, speculatively forward stratum n's current partial fixpoint to stratum n+1. Monotonicity guarantees speculative results are sound lower bounds — stratum n+1 never retracts, only continues.
- **Demand-driven forwarding (right Kan extension)**: Stratum n+1 registers threshold interests in specific stratum-n cells. Barriers forward only demanded cells, reducing communication volume and enabling earlier quiescence.
- **Partial barriers**: Synchronize only cells with cross-worldview dependencies; independent worldviews proceed without waiting. ATMS dependency tracking identifies which cells need synchronization.
- **Combined pipeline**: The left and right Kan extensions are adjoint — speculative forwarding of demanded cells gives the same result as waiting for completion and extracting what's needed.

**Design constraint**: Must preserve BSP's core invariants (superstep structure, barrier synchronization, deterministic semantics). Pipelining and demand-driven forwarding are optimizations *within* BSP, not alternatives to it.

**Research component**: The Kan extension pipeline is categorically well-motivated but implementation-wise novel. This Track may need a heavier Stage 2 (research) phase than the others.

### Track 5: Solver Language

**Source**: Logic Engine Design Phase 7 (`2026-02-24_LOGIC_ENGINE_DESIGN.org` §Phase 7)

**Scope**:
- Make `solver-config` knobs operational: `:strategy`, `:execution`, `:threshold`, `:tabling`, `:provenance`, `:timeout`, `:semantics`
- Pre-defined solver configurations: `default-solver`, `sequential-solver`, `debug-solver`, `depth-first-solver`
- `:strategy :depth-first` preserves exact DFS semantics (backward compatibility)
- `:strategy :auto` activates the two-tier engine (Tier 1 → Tier 2 on first amb)
- `:execution :parallel` enables BSP worldview exploration
- Integration with WF-LE oracle for `:semantics :well-founded`

---

## Relationship to Other Series

### Propagator Migration Series (Tracks 1-8)

BSP-LE is a **consumer** of Propagator Migration infrastructure. Track 7's persistent cells, stratified retraction, and readiness propagators are direct prerequisites. Track 8's callback elimination and module restructuring may simplify BSP-LE Tracks 2-3 but are not hard dependencies.

### PUnify (Parts 1-3)

PUnify Parts 1-2 are **prerequisites** — the cell-tree unification substrate and constructor descriptor registry are used directly by BSP-LE Track 2. The former "Part 3" design document becomes the architectural vision for BSP-LE Track 2 (ATMS Solver) specifically and the Series generally.

### Collection Interface Unification

The Collection Interface Design's post-Track 8 phases (T1-T4) are independent of BSP-LE. The pre-Track 8 phases (ground-expr? fix, dot-brace) can proceed in parallel.

---

## Success Criteria (Series-Level)

1. **Left-recursive `defr` relations terminate** (tabling)
2. **All acceptance file solver sections pass at Level 3** (end-to-end)
3. **Solve-adversarial benchmark does not regress >15%** from 14.3s baseline
4. **`:strategy :auto` activates two-tier engine** — Tier 1 for deterministic, Tier 2 on first amb
5. **`:execution :parallel` enables BSP worldview exploration** above `:threshold`
6. **`:strategy :depth-first` preserves exact DFS semantics** (backward compatibility)
7. **Allocation efficiency: measurable improvement** in per-cell and per-propagator allocation costs

---

## Open Questions

1. **Track ordering flexibility**: Can Track 4 (BSP Pipeline) start before Track 3 (Tabling) is complete? The Kan extension pipeline is orthogonal to tabling infrastructure, but they share the BSP barrier mechanism.

2. **Part 3 design document disposition**: Reframe as Series origin document, or split into per-Track design documents? Current recommendation: keep as origin document; each Track gets its own Stage 3 design doc that references it.

3. **Polynomial functor interfaces**: Directly engineering-relevant (module system for propagator networks) but research-heavy. Scope as a research document during the Series, potentially becoming a Track if the design crystallizes.

4. **5 PUnify parity bugs**: Fix as Series prerequisite (PUnify Cleanup) or fold into Track 2? Recommendation: prerequisite — they must be fixed before Track 2 flips `current-punify-enabled?` to default-on.
