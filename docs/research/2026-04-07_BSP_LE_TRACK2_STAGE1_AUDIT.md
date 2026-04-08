# BSP-LE Track 2: ATMS Solver + Cell-Based TMS — Stage 1 Research + Stage 2 Audit

**Date**: 2026-04-07
**Series**: BSP-LE (Logic Engine on Propagators)
**Scope**: Track 1.5 (Cell-Based TMS) folded into Track 2 (ATMS Solver)
**Status**: Stage 1/2 — research synthesis + codebase audit
**Next**: Stage 3 design document

---

## 1. Track Scope and Thesis

BSP-LE Track 2 delivers the **ATMS Solver on cell-based TMS** — the Multiverse Multiplexer from the Logic Engine Design (Phases 4-7), realized on the propagator infrastructure Tracks 1-8 and PPN 0-4B established.

The track folds in Track 1.5 (Cell-Based TMS) because the TMS rearchitecture should be driven by the solver's needs, not designed in isolation. The solver tells us what the worldview cell API must look like; the TMS rearchitecture delivers it.

**Thesis**: Every piece of the logic engine — unification, search, tabling, negation, constraint solving — operates on propagator cells and communicates through lattice merges. Choice points are ATMS assumptions. Conjunction is worklist scheduling. Backtracking is nogood accumulation. Parallel exploration is BSP with cell-based worldviews.

**What this track delivers**:
1. Cell-based TMS: worldview as cell value, not ambient parameter state
2. Clause-as-assumption: `atms-amb` over matching clauses replaces DFS `append-map`
3. Goal-as-propagator: each goal type becomes a propagator installation
4. Two-tier activation: Tier 1 (no ATMS overhead) → Tier 2 (on first `amb`)
5. Operational solver config: `:strategy`, `:execution`, `:tabling` become real

**What it does NOT deliver** (subsequent tracks):
- UnionFind persistent disjoint sets (BSP-LE Track 1 — can parallel)
- Tabling / SLG completion (BSP-LE Track 3 — depends on Track 2)
- Pipelined strata / Kan extensions (BSP-LE Track 4)
- Solver surface syntax (BSP-LE Track 5)

---

## 2. Source Documents (Stage 1 Research Synthesis)

### 2.1 Primary Architecture Documents

| Document | Lines | Role |
|----------|-------|------|
| [Logic Engine Design](../tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org) | 2892 | Comprehensive blueprint: Phases 4-7 define BSP-LE scope. Persistent ATMS, TMS cells, two-tier activation, BSP parallel worldview exploration, solver language. |
| [PUnify Part 3: Multiverse Multiplexer](../tracking/2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md) | 959 | Detailed solver architecture: clause-as-assumption, goal-as-propagator, propagator taxonomy mapping, categorical composition (lattice domains + Galois connections + strata tower). DFS→ATMS migration path. |
| [Cell-Based TMS Design Note](2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md) | 101 | TMS rearchitecture: worldview as cell value, migration phases A-D, scope estimate (~450 lines). |
| [BSP-LE Series Master](../tracking/2026-03-21_BSP_LE_MASTER.md) | 224 | Series tracking: 6 tracks + Track 1.5, dependency graph, scope summaries, success criteria. |

### 2.2 Infrastructure Predecessors

| Document | Role |
|----------|------|
| [PAR Track 1 Design](../tracking/2026-03-27_PAR_TRACK1_DESIGN.md) | BSP-as-default: CALM audit, dynamic topology guards, stratified barrier protocol. BSP is now the production scheduler. |
| [PAR Track 1 PIR](../tracking/2026-03-28_PAR_TRACK1_PIR.md) | BSP deployment: 10 bugs found (CALM violations, decomp-request invisible to diff, infinite loops), all resolved. |
| [PPN Track 4B Design](../tracking/2026-04-05_PPN_TRACK4B_DESIGN.md) | Attribute evaluation: 5-facet attribute-map cell, P1/P2/P3 propagator patterns, on-main-network typing. Discovered need for cell-based TMS (Phase 8 blocked). |
| [PPN Track 4B PIR](../tracking/2026-04-07_PPN_TRACK4B_PIR.md) | 90% on-network typing, 6 imperative bridges documented. TMS is the architectural bottleneck. |

### 2.3 Categorical and Theoretical Foundations

| Document | Lines | Key Insight |
|----------|-------|-------------|
| [Categorical Foundations](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) | ~800 | Polynomial functor interfaces for propagator networks. Dual quantale enrichment (correctness lattice + tropical optimization lattice). |
| [Categorical Structure of Five Systems](../tracking/2026-03-21_CATEGORICAL_STRUCTURE_FIVE_SYSTEMS.org) | ~400 | Precise categorical structure of each subsystem: elaboration, type inference, trait resolution, pattern matching, logic engine. |
| [Propagator Network Taxonomy](../tracking/2026-03-21_PROPAGATOR_NETWORK_TAXONOMY.org) | ~300 | Cross-disciplinary classification: structural, lifecycle, scheduling patterns. |
| [Module Theory on Lattices](2026-03-28_MODULE_THEORY_LATTICES.md) | ~200 | E-graphs as quotient modules. ATMS as module over Boolean assumption algebra. Residuation replaces narrowing search. |
| [Tropical Optimization](2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) | ~300 | Cost-weighted rewriting via tropical semirings. ATMS worldview selection as shortest-path in min-plus algebra. |

### 2.4 Related Vision Documents

| Document | Role |
|----------|------|
| [Relational Language Vision](../tracking/principles/RELATIONAL_LANGUAGE_VISION.org) | Three-layer model: functional, relational, solver. The solver language vision. |
| [FL Narrowing Design](../tracking/2026-03-07_FL_NARROWING_DESIGN.org) | Definitional trees, residuation-first principle. Narrowing already installs propagators. |
| [Well-Founded Logic Engine](../tracking/2026-03-14_WELL_FOUNDED_LOGIC_ENGINE_DESIGN.md) | WF-LE bilattice oracle for 3-valued NAF. `current-naf-oracle` parameter. |
| [Parallel Propagator Scheduling](2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md) | Topological-sort rounds, CAS cell writes, work-stealing. OR-parallel foundation. |

### 2.5 Research Synthesis: Key Architectural Decisions from Prior Art

**From Logic Engine Design (Phases 4-7)**:
- ATMS is a persistent, immutable value (CHAMP-backed). Worldview switching = `struct-copy` with new `believed` set.
- Two-tier activation: Tier 1 (no ATMS overhead) for deterministic queries, Tier 2 (full ATMS) activated on first `amb`. This is `:strategy :auto`.
- Clause assumptions are persistent and mutually exclusive. Failed worlds pruned by nogoods, not retraction.
- BSP parallel worldview exploration: each worldview gets its own `run-to-quiescence-bsp`. Persistent network = no copying, CHAMP structural sharing.

**From PUnify Part 3 (Multiverse Multiplexer)**:
- DFS solver loop (`solve-goals` at `relations.rkt:600`) replaced by propagator network quiescence.
- Clause-as-assumption: each matching clause gets an `atms-amb` assumption. Mutual exclusion via pairwise nogoods.
- Goal-as-propagator: each goal type (app, unify, is, not, guard) becomes a propagator installation with inputs/outputs.
- Conjunction = fan-in (N→1): N subgoal cells → conjunction-satisfied cell via countdown latch.
- The Multiverse Multiplexer = fan-out (1→N): one decision point fans out into N ATMS worlds.
- Three-axis composition: lattice domains (Galois connections), strata (fixpoint tower), worldviews (ATMS tree).

**From Cell-Based TMS Design Note**:
- Current TMS uses `current-speculation-stack` parameter — OFF-NETWORK state influencing ON-NETWORK computation.
- Fix: worldview as cell value. Propagators read worldview from cell input. `tms-read`/`tms-write` already accept stack as argument — the parameter just needs to be replaced by a cell read.
- Migration is backward-compatible: optional worldview argument, then gradual migration, then parameter removal.

**From PAR Track 1 (BSP-as-default)**:
- BSP is production scheduler. Dynamic topology requires CALM guards (decomp-request wrapping).
- Speculation already works under BSP — but it's parameter-based, limiting concurrency to one worldview at a time.

**From OR-Parallel Prolog Research** (Muse, Aurora, Manchester):
- Choice point forking = worldview branching. Each worker explores one branch.
- Binding environment isolation is the core challenge. Muse copies binding arrays. Aurora uses conditional assignment.
- Cell-based TMS provides a third approach: shared CHAMP cells with TMS branch isolation. No copying, O(d) lookup. Per-branch overhead proportional to *differences*, not *totals*.
- The key advantage over Muse/Aurora: persistent data structures eliminate environment management overhead.

---

## 3. Codebase Audit (Stage 2)

### 3.1 Current TMS Implementation

**File**: `propagator.rkt` (lines 855-953)

The TMS is a tree of hasheq maps indexed by assumption-id:

```
tms-cell-value:
  base: value                          ;; depth-0 (no speculation) value
  branches: hasheq assumption-id →     ;; per-assumption overrides
    value | tms-cell-value              ;; leaf or nested sub-tree
```

Three pure operations:
- `tms-read(cell-val, stack)` — O(d) walk through branch tree, falling back to base
- `tms-write(cell-val, stack, value)` — O(d) nested CHAMP insert
- `tms-commit(cell-val, assumption-id)` — promote branch value to base, flatten sub-trees

**Key observation**: `tms-read` and `tms-write` are ALREADY pure functions that take the stack as an argument. The `current-speculation-stack` parameter is only read at two integration points:
- `net-cell-read` (line 577): `(tms-read v (current-speculation-stack))`
- `net-cell-write` (line 751): `(tms-write old-val (current-speculation-stack) new-val)`

This means the migration surface is smaller than it appears — only these two call sites need to change from reading the parameter to reading a worldview cell.

### 3.2 Speculation Users (Migration Targets)

| File | Lines | What It Does | TMS Usage |
|------|-------|-------------|-----------|
| `elab-speculation-bridge.rkt` | 302 | Church fold speculation, union type branching | Primary consumer. `parameterize` wraps around elaboration calls. Binary speculation (one branch at a time). |
| `elab-speculation.rkt` | 188 | Speculation data structures | `hypothesis-id` from `atms-amb`, speculation scope tracking |
| `typing-propagators.rkt` | (Phase 8 code) | Union type branching in attribute PU | `parameterize` wraps in fire functions. Currently unused (Phase 8 blocked). |
| `metavar-store.rkt` | (line 1321) | Meta solution under speculation | Reads `(current-speculation-stack)` when solving metas |
| `cell-ops.rkt` | (line 82-83) | Cell guard during speculation | Checks if inside speculation for validation |

### 3.3 ATMS Data Structure

**File**: `atms.rkt` (397 lines)

Already implemented and functional:
- `atms-assume` — create new assumption, returns `(values atms* aid)`
- `atms-retract` — remove from believed set
- `atms-add-nogood` — record inconsistent assumption set
- `atms-consistent?` — check set against all nogoods
- `atms-amb` — N mutually exclusive assumptions + pairwise nogoods
- `atms-with-worldview` — switch believed set (O(1) struct-copy)
- `atms-read-cell` / `atms-write-cell` — cell operations under worldview
- `atms-solve-all` — Cartesian product over amb-groups + consistency filter
- `atms-explain-hypothesis` / `atms-explain` — provenance tracking
- `atms-minimal-diagnoses` — Reiter's hitting set
- `atms-conflict-graph` — nogood visualization

**Gap**: The ATMS operates beside the propagator network, not through it. `atms-read-cell` / `atms-write-cell` are ATMS-level operations that bypass `net-cell-read` / `net-cell-write`. The integration point is the TMS layer — cell-based TMS bridges the ATMS worldview into the propagator network's cell operations.

### 3.4 Current DFS Solver

**File**: `relations.rkt` (1266 lines)

The DFS solver at lines 600-893 (~300 lines):
- `solve-goals`: recursive append-map over goals, threading substitution
- `solve-single-goal`: dispatch on goal kind (app, unify, is, not, guard)
- `solve-app-goal`: iterate clauses, α-rename, unify, recurse on body
- `DEFAULT-DEPTH-LIMIT`: 100 (crude termination guard)

**What DFS gets right**: simple, predictable, low overhead, all-solutions.
**What DFS gets wrong**: no termination guarantee, redundant computation, no cross-branch constraint interaction, sequential-only, backtracking destroys information.

### 3.5 Solver Config

**File**: `solver.rkt` (171 lines)

Fully implemented: `solver-config` struct with all knobs (`:strategy`, `:execution`, `:threshold`, `:tabling`, `:provenance`, `:timeout`, `:semantics`, `:narrow-search`, `:narrow-value-order`, `:max-derivation-depth`). Accessors, merge function, validation. Used by `solve-goal` and `explain-goal` in `relations.rkt`.

**Gap**: Most knobs are ignored by the engine. `:strategy :auto` doesn't activate two-tier. `:execution :parallel` doesn't parallelize worldviews. `:tabling :by-default` doesn't table. Making these operational is a Track 2 deliverable.

### 3.6 Narrowing Infrastructure

**File**: `narrowing.rkt` (1240 lines, 138 functions)

Already partially on-network: installs propagators for definitional tree branches, ATMS `amb` choices over alternatives, rule-node evaluation. This is the functional-logic path that Track 2 must compose with, not replace.

Key interaction: narrowing uses `atms-amb` for Or-nodes in definitional trees. Cell-based TMS would make these narrowing propagators fully on-network — currently they use `parameterize` for speculation.

### 3.7 BSP Scheduler Integration Points

**File**: `propagator.rkt` (lines 335-520)

BSP fires all propagators in a frontier simultaneously, collects writes, merges via `bulk-merge-writes`. The `fire-and-collect-writes` function iterates propagators.

**Key change needed**: `fire-and-collect-writes` must pass worldview context to each propagator. Currently, the worldview is ambient (parameter). With cell-based TMS, each propagator reads its worldview from its input cell — but during BSP fire, the worldview cell must be readable. This requires the worldview cell to be part of the snapshot that BSP works from.

### 3.8 Cross-System TMS Consumers

| System | TMS Usage Pattern | Cell-Based Impact |
|--------|-------------------|-------------------|
| **Type inference** (typing-propagators.rkt) | Union type speculation: two branches, each with different type assumption. Currently Phase 8 blocked. | Direct beneficiary — Phase 8 becomes implementable. |
| **Elaboration** (elab-speculation-bridge.rkt) | Church fold attempts: speculate on fold interpretation, rollback if wrong. | Migrate from `parameterize` to worldview cell read. |
| **Trait resolution** (metavar-store.rkt) | Meta solution under speculation: read speculation stack to determine branch. | Migrate meta-solution TMS reads to worldview cell. |
| **Logic engine** (relations.rkt + narrowing.rkt) | Narrowing Or-nodes use `atms-amb`. Solver DFS doesn't use TMS. | The primary new consumer — clause-as-assumption needs cell-based worldview. |
| **Pattern matching** (narrowing.rkt) | Branch nodes: ATMS amb over constructor alternatives. | Already uses ATMS. Cell-based TMS makes it fully on-network. |

---

## 4. Architectural Analysis

### 4.1 The Two-Layer TMS Problem

Currently, there are **two separate TMS mechanisms** that don't compose:

1. **Cell-level TMS** (`tms-cell-value` in propagator.rkt): Branch tree inside cell values. Pure `tms-read`/`tms-write` operations. Used by the propagator network for speculation.

2. **ATMS-level TMS** (`atms-read-cell`/`atms-write-cell` in atms.rkt): Separate cell map inside the ATMS struct. Used by the logic engine for worldview management.

These are doing the same thing — maintaining branch-specific cell values — through different mechanisms. Cell-based TMS should **unify** them: the ATMS worldview becomes a cell value that the cell-level TMS reads. One mechanism, not two.

### 4.2 The Worldview Cell Design Space

Three options for how worldview flows to propagators:

**Option A: Explicit worldview cell as propagator input.**
Each speculation-aware propagator declares a worldview cell in its input list. The propagator reads it explicitly.
- Pro: Pure, explicit, composable.
- Con: Every propagator needs to know about worldview. Changes fire function signature conceptually (though `net → net` is preserved).

**Option B: Per-network worldview cell.**
The prop-network has a designated worldview cell. `net-cell-read`/`net-cell-write` auto-read it.
- Pro: Transparent to propagators. No fire function changes.
- Con: One worldview per network. Concurrent worldviews need separate networks (or network partitioning).

**Option C: Hybrid — worldview cell with per-propagator override.**
Default worldview cell on the network, but propagators can be installed with an explicit worldview cell that overrides the default.
- Pro: Most propagators are transparent; speculation-aware propagators can override.
- Con: More complex dispatch in `net-cell-read`/`net-cell-write`.

**Recommendation**: Option B for Track 2 (simplest, unblocks everything). Option C if Track 4 (BSP Pipeline) needs concurrent worldviews in the same network — but that can be a Track 4 extension.

### 4.3 OR-Parallel Worldview Exploration

The OR-parallel Prolog connection (Muse, Aurora):

| Muse/Aurora | BSP-LE Track 2 |
|---|---|
| Choice point | `atms-amb` — branch on alternative clauses |
| Binding environment copy | Worldview cell — TMS branch isolation |
| Worker/agent | Propagator set under a worldview cell |
| Shared regions | Base TMS values (depth-0, visible to all branches) |
| Private regions | Branch-specific TMS writes (per assumption-id) |
| Commit | `tms-commit` — promote branch to base |
| Backtrack | Nogood accumulation — prune worldview from future exploration |

**Key advantage over classical OR-parallelism**: No environment copying. CHAMP structural sharing means branching is O(1) for the initial split and O(writes) for branch divergence. The TMS tree tracks exactly what's different per branch; everything else is shared automatically.

**Concurrent exploration model (Track 4 extension)**: Two worldview cells (A and B) on the same network. Propagators under A fire and write to TMS branches tagged with A's assumption-id. Propagators under B do the same with B's. BSP fires both sets in the same superstep. Cell merges are safe because TMS branches are independent — A's writes don't interfere with B's.

### 4.4 Tier 1/Tier 2 Transition

The two-tier model from LE Design §5.5:

- **Tier 1**: Plain prop-network. Cells hold simple values. No TMS overhead. `run-to-quiescence` operates directly. Sufficient for deterministic queries.
- **Tier 2**: Activated on first `amb`. Cells get TMS wrappers. Worldview cell created. From this point, all reads/writes go through TMS.

The transition must be: (a) O(1) (no full-network scan to wrap cells), (b) invisible to existing propagators (they don't know about TMS), (c) backward-compatible (`:strategy :depth-first` stays in Tier 1 forever).

**Implementation approach**: Tier 1 cells already pass through `tms-read` with `'()` stack — this returns `v` directly (single `null?` check). The overhead is one branch prediction per cell read. The transition to Tier 2 = create a worldview cell + set the per-network worldview cell id. Existing propagators don't change; `net-cell-read`/`net-cell-write` auto-detect the worldview cell.

---

## 5. Scope Estimate and Phase Sketch

### 5.1 Estimated Scope

| Component | Lines | Complexity |
|-----------|-------|------------|
| Cell-based TMS core (propagator.rkt) | ~150 | Medium — worldview cell, net-cell-read/write changes |
| ATMS → cell-based bridge | ~100 | Medium — atms worldview → worldview cell value |
| Migration of 5 speculation users | ~200 | Low per file — replace `parameterize` with cell read |
| Clause-as-assumption solver | ~400 | High — new solver loop replacing DFS |
| Goal-as-propagator dispatch | ~300 | High — propagator installation per goal type |
| Two-tier activation | ~100 | Medium — Tier 1→2 transition |
| Solver config wiring | ~150 | Low — connect existing knobs |
| Tests | ~300 | Medium — worldview cells, solver parity, ATMS integration |
| **Total** | **~1700** | |

### 5.2 Suggested Phase Structure (for Stage 3 design)

| Phase | Description | Scope |
|-------|-------------|-------|
| 0 | Pre-0 benchmarks + acceptance file | Baseline DFS solver performance |
| 1 | Cell-based TMS: worldview cell + net-cell-read/write changes | propagator.rkt core |
| 2 | Speculation migration: elab-speculation-bridge, metavar-store, cell-ops | 5 files |
| 3 | ATMS↔TMS bridge: ATMS worldview → worldview cell value | atms.rkt + propagator.rkt |
| 4 | Clause-as-assumption: `atms-amb` over matching clauses | New solver path in relations.rkt |
| 5 | Goal-as-propagator: propagator installation per goal type | relations.rkt refactor |
| 6 | Two-tier activation: Tier 1→2 on first `amb` | solver.rkt + relations.rkt |
| 7 | Solver config wiring: `:strategy`, `:execution` operational | solver.rkt |
| 8 | Parity validation: DFS ↔ ATMS result equivalence | Test suite |
| T | Dedicated test files | Per-phase testing |
| PIR | Post-implementation review | Retrospective |

---

## 6. Open Questions for Stage 3

1. **UnionFind ordering**: BSP-LE Track 1 (UnionFind) is listed as parallel with Track 2. Does the ATMS solver need UF for var-var bindings, or can it use cell-tree unification exclusively? If UF is needed, it's a dependency; if not, it can follow.

2. **Tabling scope boundary**: Track 3 (Tabling) depends on Track 2. But some tabling infrastructure (table registry, accumulator cells) could be designed alongside Track 2's solver. Should Phase 4-5 (clause/goal propagators) include tabling hooks, or leave them for Track 3?

3. **PUnify parity**: The PUnify Cleanup track (5 parity bugs) is listed as a BSP-LE prerequisite. Are these bugs blockers for Track 2, or can Track 2 proceed with `current-punify-enabled? = #f`?

4. **Narrowing integration**: `narrowing.rkt` already uses `atms-amb`. Does Track 2 unify the narrowing solver path with the relational solver path, or leave them as separate consumers of the same ATMS infrastructure?

5. **Worldview cell option**: Option A (explicit per-propagator), B (per-network), or C (hybrid)? This affects the propagator installation API for all solver propagators.

6. **Concurrent worldview exploration**: Is this in Track 2 scope or deferred to Track 4 (BSP Pipeline)? Track 2 can deliver sequential worldview exploration (one at a time) with the architecture that enables future parallelism.

---

## 7. Cross-References

| What | Where | Impact |
|------|-------|--------|
| PPN Track 4C (dissolve bridges) | 6 imperative bridges, including resolve-trait-constraints! | SRE Track 3 should precede 4C; Track 2 unblocks Phase 8 |
| SRE Track 3 (trait resolution) | Trait resolution participates in speculation | Benefits from cell-based TMS |
| SRE Track 5 (pattern compilation) | Pattern matching uses ATMS amb for constructor branches | Benefits from cell-based TMS + ATMS solver |
| PPN Track 4B Phase 8 (union branching) | Blocked on cell-based TMS | Directly unblocked by Track 2 Phase 1-2 |
| BSP-LE Track 3 (tabling) | Depends on Track 2 ATMS solver | Producer/consumer propagators over worldview cells |
| BSP-LE Track 4 (BSP pipeline) | Concurrent worldview exploration | Extends Track 2's cell-based worldview to parallel |
