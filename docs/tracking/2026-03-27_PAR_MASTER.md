# PAR Series: Parallel Scheduling

**Thesis**: CALM guarantees order-independence only on fixed topologies. Dynamic topology (cell/propagator creation during fire) requires stratification. BSP with stratified topology enables true parallel scheduling across all propagator-based architectures.

**Origin**: CALM violation discovered 2026-03-27 (BSP vs SRE subtype decomposition). [Parallel Scheduling Research](../research/2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md). BSP-LE Track 4 (superseded).

**Relates to**: BSP-LE (supersedes Track 4), PM (substrate), SRE (decomposition = topology change), PPN (hypergraph rewriting = topology change), PRN (rewrite application = topology change).

**Revised 2026-10-12** (owner): **Track 4 — Arena Executors** opened from the Track-2 "R3–R5" row; the
undefined `R1–R5` labels are retired (work is named by Design-Methodology stage). Track 4's
artifacts live under the new per-track layout, [`tracks/PAR/PAR_4/`](tracks/PAR/PAR_4/) (log:
[`LOG.md`](tracks/PAR/PAR_4/LOG.md)). §Challenge 1 below is **superseded** by Track 4's Stage-1
record — see its revision note. Staleness fixed in the same pass: the 2026-03-28 dailies had
recorded "R3–R5 closed as answered by implementation" while this table showed ⬜; the row now
says what happened.

---

## Key Insight

Fire functions that call `net-new-cell` or `net-add-propagator` change the lattice topology. CALM says nothing about convergence over changing lattices. BSP's `fire-and-collect-writes` only diffs cell VALUES — structural changes are silently dropped, producing wrong results.

**The invariant**: Within a stratum, topology is FIXED. Between strata, topology may change.

**The architecture**: Two fixpoints.
1. **Value fixpoint** (BSP-safe, parallelizable): fire all propagators, converge values on fixed topology.
2. **Topology fixpoint** (sequential): read decomposition requests, create cells/propagators.
3. Repeat until neither changes.

**Guard**: `current-bsp-fire-round?` parameter. `net-new-cell` and `net-add-propagator` error during BSP fire rounds. Implemented in commit `af35f5e`.

---

## Tracks

| Track | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | CALM topology audit + stratified topology design | ✅ | [Audit](2026-03-27_PAR_TRACK0_CALM_AUDIT.md). 2 violators (SRE, narrowing), 7+ safe. LKan/RKan CALM-safe. |
| 1 | BSP-as-default + stratified topology | ✅ | [Design](2026-03-27_PAR_TRACK1_DESIGN.md), [PIR](2026-03-28_PAR_TRACK1_PIR.md). 380/380 GREEN. 10 bugs via diagnostic protocol. Structural propagator capture. BSP 2.3% faster than DFS. |
| 2 (R1-R2) | True parallel execution proof-of-concept | ✅ | Racket 9 parallel threads. 13/13 stress tests PASS. 4.45× speedup (synthetic). 1.42× on graph coloring/constraint grids. |
| 2 (R3-R5) | Contention analysis + literature survey + design doc | ➡ Track 4 | Was marked "closed, answered by implementation" in the 2026-03-28 dailies but never here. Reopened 2026-10-12 as the Stage-1 research of **Track 4**; the STM/WAL/FFI directions are answered there (STM unnecessary, WAL = the delta arena, FFI unnecessary for the signal). |
| 3 | `:auto` heuristic + production deployment | ⬜ | Network size threshold, propagator count. Kind-aware (PTF Track 3). Like solver's `:auto` setting. |
| **4** | **Arena Executors** — scheduler-owned spin executors, ownership-partitioned cells, direct S0 writes under chaotic iteration (barrier = stratum boundary), plus a flat storage tier for the fixnum lattices | 🔶 Stage 1 ✅ Stage 2 ✅ D.1 ✅ P0 ✅ (2026-10-13) · D.2 next | [P0](tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md) · [D.1](tracks/PAR/PAR_4/2026-10-12_PAR_4_D1_DESIGN.md) · [Stage 1 synthesis](tracks/PAR/PAR_4/research/2026-10-12_PAR_4_STAGE1_RESEARCH_SYNTHESIS.md) · [contention analysis](tracks/PAR/PAR_4/research/2026-10-12_PAR_4_STAGE1_CONTENTION_ANALYSIS.md) · [Stage 2 gap analysis](tracks/PAR/PAR_4/2026-10-12_PAR_4_STAGE2_GAP_ANALYSIS.md) · [LOG](tracks/PAR/PAR_4/LOG.md). Key numbers: raw-memory handoff ~60 ns (2B's 8 µs floor was scheduler-routed signals); Chez allocator does not scale (global refill mutex); solver allocation-bound (wall ≈ bytes ÷ 2.2 GB/s); arena fire 95–131 ns / ~0 B vs 1 500 ns / 2.8 KB; same fixpoint at every K incl. async mode; 7× at K=8, 13× at K=16 at today's fire weight. |

---

## Prerequisites

| Item | Status |
|------|--------|
| CALM topology guard (`current-bsp-fire-round?`) | ✅ `af35f5e` |
| BSP scheduler implementation (`run-to-quiescence-bsp`) | ✅ Track 8 C5a |
| `sequential-fire-all` executor | ✅ |
| `make-parallel-fire-all` executor (futures) | ✅ (untested at scale) |
| SRE decomposition refactoring (topology → strata) | ⬜ Track 0 |

---

## Open Research Questions

### Q1: LKan/RKan inter-stratum interactions under CALM

Kan extension mechanisms (Left Kan = speculative supply, Right Kan = demand-driven) cross stratum boundaries. Within each stratum, topology is fixed and CALM holds. Between strata, the topology may change. The question: do LKan/RKan preserve CALM guarantees across the stratum boundary?

**Hypothesis**: Yes — Kan extensions operate on the VALUES flowing between strata, not on the topology. The stratum boundary is a fixed interface (cells that exist at both levels). LKan writes speculative values into the next stratum's cells; RKan writes demand signals into the previous stratum's cells. Neither creates new cells or propagators. The topology is fixed at stratum-construction time; only values flow.

**Needs verification**: Are there cases where a Kan extension needs to CREATE new cells (e.g., demand for a new decomposition level)? If so, that's a topology change disguised as a value flow.

### Q2: Multi-strata towers — parallel topology rewrites

What if multiple topology rewrites want to happen on different parts of the same underlying network? Example: SRE decomposes `PVec (List Int)` while simultaneously PPN rewrites a parse tree node. Both are topology changes, but on independent subgraphs.

**The question**: Can we parallelize topology strata if the rewrites touch disjoint subgraphs? This would be "parallel topology exploration" — multiple topology strata running concurrently on partitioned regions.

**Connection to hypergraph rewriting**: E-graph saturation (PReduce) and grammar production application (PPN) are both topology rewrites. If two rewrite rules touch disjoint hyperedges, they can apply in parallel. This is the same question as parallel graph rewriting in DPO/SPO frameworks — and the answer depends on whether the rewrites have "critical pairs" (conflicting overlaps).

**Design Stage 0/1 research**: This connects to the PRN theory series. The CALCO 2025 result (e-graphs are adhesive categories) may provide the theoretical foundation — adhesive categories have well-defined parallel rewriting via independence conditions.

### Q3: Dynamic topology as NAF-LE analog

Dynamic topology should never be supported as an inline operation (fire function side effect). Instead, treat topology changes like negation-as-failure: a non-monotone operation that requires its own stratum.

**The analogy**:
- NAF: "if P is not derivable at quiescence, conclude ¬P" — evaluated between strata
- Dynamic topology: "if decomposition is requested at quiescence, build sub-cells" — evaluated between strata
- Both are non-monotone (NAF can retract; topology changes the domain)
- Both are safe when stratified (no interference with monotone value propagation)

**Design principle**: Any construct that modifies the network's shape (cells, propagators, dependencies) is a topology change and MUST be stratified. This applies to: SRE decomposition, e-graph node creation, tabling memo cells, parse tree rewriting, bridge installation. The CALM guard enforces this at the API level.

---

## Known Challenges

### Challenge 1: Racket Parallelism Limitations (Track 2 research)

> ⚠ **Superseded 2026-10-12 by Track 4 Stage 1** ([record](tracks/PAR/PAR_4/research/2026-10-12_PAR_4_STAGE1_CONTENTION_ANALYSIS.md) §6).
> The premises below predate Racket 9.0's parallel threads (`thread #:pool 'own`, shared-memory,
> truly parallel). Measured on 9.0/9.3: the real limit is the Chez **allocator** (a global mutex on
> allocation-area refill; places share it), not the threads; cross-thread signalling is ~60 ns via
> boxes + fences. Of the four directions: STM is unnecessary (joins commute; ownership needs no
> retry); WAL cells ARE the delta arena, now measured; FFI is unnecessary for the signal (8 ns
> crossing, same hardware floor); the hybrid is moot. Kept verbatim below as the record of the
> question as it was asked.

Racket's parallelism primitives are insufficient for our needs:
- **Futures**: Cannot perform mutation. Fire functions use `net-cell-write` which returns a new network (pure), but the BSP merge step needs to combine results from multiple futures. GC pauses affect all futures simultaneously. No true OS-thread parallelism for non-numeric workloads.
- **Places**: True OS-level parallelism but heavy (separate Racket VMs, serialized message passing). Current batch-worker model uses Places — overhead is acceptable for test-level parallelism but too heavy for per-propagator parallelism.
- **Threads**: Cooperative, not parallel. Green threads on one OS thread.

**Research directions** (Stage 0/1):
1. **Software Transactional Memory (STM)**: Clojure's STM (refs + dosync), Haskell's STM (TVar + atomically). Multiple propagators fire concurrently, each in a transaction. On write conflict, one transaction retries. Avoids constant re-firing by detecting conflicts at commit time. **Key question**: Can we build STM cells where `net-cell-write` is a transactional operation?
2. **Write-Ahead Log (WAL) cells**: Each propagator writes to a local WAL. A merge phase applies all WALs to the canonical cells. Conflicts resolved by lattice join (commutative + associative = merge order doesn't matter). Similar to BSP's current `bulk-merge-writes` but with persistent log for replay/debugging.
3. **FFI to external parallelism**: Rust `rayon` work-stealing pool via FFI. Fire functions compiled to a form that Rust can execute. Heavy investment but true parallelism. Alternative: C `pthreads` with lock-free CHAMP operations.
4. **Hybrid**: STM for write contention resolution + FFI for actual parallel execution. STM handles correctness; external runtime handles performance.

**Write contention without constant re-firing**: The key insight from STM literature. If propagator A writes to cell X and propagator B also writes to cell X, both writes are lattice joins. Since join is commutative and associative, the ORDER doesn't matter — both writes can succeed. The only question is whether the merged result triggers re-firing of dependents. STM detects this: if the merged result equals what A or B already computed from, no re-fire needed.

### Challenge 2: Dynamic Topology Sources (Track 0 audit)

Known sites (audit needed for completeness):
- SRE decomposition (`sre-decompose-generic`): creates sub-cells + sub-propagators
- PUnify dispatch: may create cells during structural unification
- Tabling: may create memo cells
- Bridge installation during elaboration
- **Full audit is Track 0's first deliverable**

**Historical note**: Prior BSP testing (before SRE Track 1) showed no failures because the only fire functions at that time were value-only. SRE Track 1 introduced `sre-decompose-generic` which creates topology inside fire functions — this is what broke CALM. The CALM guard (`af35f5e`) will catch any future violations immediately.

### Challenge 3: `:auto` Heuristic Design (Track 3)

- Small networks (<10 propagators): BSP overhead exceeds benefit
- Medium networks (10-100): sequential BSP may match DFS
- Large networks (100+): parallel BSP should outperform DFS
- The heuristic needs empirical calibration, not theoretical prediction

---

## Cross-Series Impact

PAR is cross-cutting — it affects the scheduling substrate that ALL series run on:

- **PPN**: Hypergraph rewriting rules that add parse tree nodes are topology changes → need topology strata
- **SRE**: Structural decomposition is the primary source of dynamic topology → Track 0's main refactoring target
- **PReduce**: E-graph saturation adds equality nodes → topology change
- **BSP-LE**: ATMS hypothesis creation → topology change
- **PM**: Network construction during elaboration → topology audit scope

### Module Theory

[Module Theory on Lattices](../research/2026-03-28_MODULE_THEORY_LATTICES.md): Submodule independence = parallelizability. CALM = monotone endomorphism fixpoint. `:auto` heuristic has formal basis via submodule decomposition.
