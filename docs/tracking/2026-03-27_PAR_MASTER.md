# PAR Series: Parallel Scheduling

**Thesis**: CALM guarantees order-independence only on fixed topologies. Dynamic topology (cell/propagator creation during fire) requires stratification. BSP with stratified topology enables true parallel scheduling across all propagator-based architectures.

**Origin**: CALM violation discovered 2026-03-27 (BSP vs SRE subtype decomposition). [Parallel Scheduling Research](../research/2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md). BSP-LE Track 4 (superseded).

**Relates to**: BSP-LE (supersedes Track 4), PM (substrate), SRE (decomposition = topology change), PPN (hypergraph rewriting = topology change), PRN (rewrite application = topology change).

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
| 0 | CALM topology audit + stratified topology design | ⬜ | Audit all `net-new-cell`/`net-add-propagator` calls in fire functions. Design decomposition-request protocol. |
| 1 | BSP-as-default | ⬜ | After Track 0 resolves all CALM violations. `:auto` heuristic for when to use BSP vs DFS. |
| 2 | True parallelism mechanism | ⬜ | Racket futures have fundamental limitations (no mutation, GC pauses). Investigate: FFI to C/Rust worker pool, Racket Places, custom mechanism. See [Parallel Scheduling Research](../research/2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md). |
| 3 | `:auto` heuristic + production deployment | ⬜ | Network size threshold, propagator count, fire function cost estimation. Like solver's `:auto` setting. |

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

## Known Challenges

### Racket Futures Limitations
- Cannot perform mutation (fire functions currently mutate via `net-cell-write`)
- GC pauses affect all futures simultaneously
- No true OS-thread parallelism for non-numeric workloads
- See [Parallel Scheduling Research](../research/2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md) for analysis

### Dynamic Topology Sources (Audit Needed)
- SRE decomposition (`sre-decompose-generic`): creates sub-cells + sub-propagators
- PUnify dispatch: may create cells during structural unification
- Tabling: may create memo cells
- Bridge installation during elaboration
- **Full audit is Track 0's first deliverable**

### `:auto` Heuristic Design
- Small networks (<10 propagators): BSP overhead exceeds benefit
- Medium networks (10-100): sequential BSP may match DFS
- Large networks (100+): parallel BSP should outperform DFS
- The heuristic needs empirical calibration, not theoretical prediction

---

## Cross-Series Impact

PAR is cross-cutting — it affects the scheduling substrate that ALL series run on:

- **PPN**: Hypergraph rewriting rules that add parse tree nodes are topology changes → need topology strata
- **SRE**: Structural decomposition is the primary source of dynamic topology → Track 0's main refactoring target
- **PReductions**: E-graph saturation adds equality nodes → topology change
- **BSP-LE**: ATMS hypothesis creation → topology change
- **PM**: Network construction during elaboration → topology audit scope
