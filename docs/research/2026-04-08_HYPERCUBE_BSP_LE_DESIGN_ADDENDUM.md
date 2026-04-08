# Hypercube Structure of the Worldview Space — BSP-LE Track 2 Design Addendum

**Date**: 2026-04-08
**Parent design**: [BSP-LE Track 2 D.6](../tracking/2026-04-07_BSP_LE_TRACK2_DESIGN.md)
**Source**: [Hypercube Conversation](../standups/standup-2026-04-08.org) § "Hypercube Conversation"
**Status**: Draft — captures design implications while context is fresh

---

## §1 The Structural Identity

The ATMS worldview space for n assumptions IS the hypercube Q_n — the Boolean lattice 2^n. This is not a metaphor. It is a structural identity:

- **Nodes**: all binary strings of length n (2^n worldviews, each assumption believed or not)
- **Edges**: two worldviews are adjacent if they differ by exactly one assumption (Hamming distance 1)
- **The Hasse diagram of the Boolean lattice IS the hypercube graph**

Our design already uses the Boolean powerset lattice (Option E, §2.1 of the parent design). What we have NOT captured: the **adjacency structure** — which worldviews are "one step apart." This adjacency is what hypercube algorithms exploit.

### What this adds to the SRE lattice analysis

The parent design's SRE lattice lens (§2.5) classified the worldview lattice as:
- Boolean, distributive, complemented, Heyting, frame
- Value lattice (derived from decision cells)

The hypercube adds:
- **Adjacency metric**: Hamming distance between worldviews = number of differing assumptions
- **Recursive decomposition**: Q_n = Q_{n-1} × Q_1 (fixing one assumption splits the space in half)
- **Logarithmic diameter**: any two worldviews are at most n hops apart
- **Embedding richness**: contains rings, meshes, trees, butterflies as substructures

These are NOT new lattice properties — they are properties of the **Hasse diagram** of an existing lattice. The SRE should capture adjacency/metric structure alongside algebraic properties.

---

## §2 Implications for BSP-LE Track 2 Phases

### §2.1 Phase 6: Gray Code Traversal for Branch Exploration

When `atms-amb` creates N branch PUs, the ORDER in which branches are explored matters. Our current design doesn't specify an order — branches fire in whatever order BSP schedules them.

**Gray code insight**: A Gray code on Q_n is a Hamiltonian path that changes one bit per step. For our ATMS, Gray code traversal means: explore worldviews in an order that changes one assumption at a time. Since CHAMP structural sharing means adjacent worldviews (differing by one assumption) share almost all network state, **Gray code order maximizes CHAMP reuse**.

**Concrete implication for Phase 6**: When `atms-amb` creates M branch PUs from matching clauses, the branches' assumption-ids form a subset of the hypercube. The exploration order should follow a Gray code on this subset — each successive branch differs from the previous by one assumption. The PU fork from the previous branch's network (instead of the parent's) maximizes structural sharing.

**Implementation**: The branch PU list returned by `atms-amb-on-network` should be ordered by Gray code. For M branches with M assumptions, a standard reflected Gray code gives the optimal ordering. For M = 2, it's trivial (0→1 or 1→0). For M = 3+, use the standard n-bit Gray code algorithm.

**Expected benefit**: Each branch PU fork starts from a network that differs from the previous branch by ONE assumption's effects. CHAMP structural sharing means the fork copies only the cells affected by that one assumption change — O(affected cells) instead of O(all cells).

### §2.2 Phase 3: Subcube Pruning for Nogoods

When a nogood `{h_A, h_B, h_C}` is learned, ALL worldviews containing that combination are contradicted. These worldviews form a **subcube** Q_{n-3} of the full Q_n — all 2^{n-3} combinations of the remaining n-3 assumptions.

**Current design**: Per-nogood commitment cells track which assumptions are committed, and the narrower prunes the remaining group. This works per-nogood.

**Hypercube insight**: The pruned subcube is identifiable STRUCTURALLY — it's a known subgraph of the hypercube. Any worldview whose assumption set CONTAINS the nogood as a subset is in the pruned subcube. This is the `nogood-member?` check from `decision-cell.rkt` — but the hypercube perspective reveals it as a **subcube membership test**, which can be implemented as a bitmask operation.

**Concrete implication**: If assumptions are mapped to bit positions, a nogood `{h_1, h_3, h_5}` corresponds to a bitmask `0b101010`. A worldview with bits `0b111010` contains the nogood (the nogood bits are a subset). The check is: `(worldview & nogood-mask) == nogood-mask` — a single AND + comparison. O(1), no hash operations.

**Implementation**: Decision cells could use bitmask representation alongside (or instead of) hasheq for the assumption set. The subcube membership test becomes a bitwise operation. For n ≤ 64, a single 64-bit integer suffices. For n > 64, a bitvector.

**Expected benefit**: Nogood checking becomes O(1) bitwise operations instead of O(|nogood|) hash lookups. At scale (thousands of nogoods, hundreds of assumptions), this is a significant constant-factor improvement.

### §2.3 Phase 9-10: Hypercube All-Reduce for BSP Barriers

When BSP synchronizes across threads, the barrier is currently a flat synchronization point — all threads wait for all others. The hypercube all-reduce pattern gives the optimal tree:

- log_2(T) rounds for T threads
- Each round: pairwise communication between partners differing in one "dimension" (bit)
- Total messages: T × log_2(T)
- Each thread sends and receives O(N/T) data

**Concrete implication for Phase 9-10**: When `:execution :parallel` is active and T ≥ 4 threads, the BSP barrier should use hypercube all-reduce instead of flat synchronization. The `make-parallel-thread-fire-all` executor (already in propagator.rkt) partitions work across threads — the barrier merge phase can follow the hypercube pattern.

**Implementation**: The barrier phase in `run-to-quiescence-bsp` currently collects all writes and merges sequentially (`bulk-merge-writes`). With hypercube all-reduce: in round k, thread i communicates with thread i XOR 2^k. Partners exchange their local cell writes and merge. After log_2(T) rounds, every thread has the complete merged state.

**Expected benefit**: For T = 8 threads (M-series Mac), 3 rounds of pairwise merge instead of 7 sequential merges. Reduces barrier latency by ~50% for the merge phase.

### §2.4 Nogood Broadcast: Hypercube Distribution Pattern

When a nogood is discovered in one worldview and must be propagated to all active worldviews, the hypercube broadcast pattern reaches all worldviews in log_2(W) rounds for W active worldviews.

**Current design**: Per-nogood topology requests accumulate in the topology-request cell (set-union merge). The topology stratum processes them. This is correct but doesn't specify the DISTRIBUTION pattern when multiple worldviews exist simultaneously.

**Hypercube insight**: If W worldviews are active (W branch PUs), broadcasting a new nogood to all of them follows the binomial tree pattern embedded in the hypercube: the source worldview sends to log_2(W) partners, each partner forwards to their remaining partners, and in log_2(W) rounds all worldviews have the nogood.

**Concrete implication**: When multiple branch PUs are active, nogood propagation should follow hypercube broadcast order rather than arbitrary order. The "arbitrary" order from set-union merge happens to be deterministic (CHAMP iteration order) but not optimal.

**Implementation**: The nogood topology watcher, when broadcasting `nogood-install-request` descriptors, could order them according to the hypercube dimension: first the nogoods that affect dimension 0 (lowest assumption bit), then dimension 1, etc. This interleaves with the BSP superstep structure — each superstep processes one "dimension" of the broadcast.

### §2.5 WF-LE Connection: Bitonic Sort and Mixed Fixpoint

The hypercube conversation identifies that the WF-LE's mixed fixpoint (alternating lfp/gfp) IS a bitonic computation. The bitonic merge network interleaves ascending and descending phases optimally.

**Implication for future WF integration**: When BSP-LE Track 2's solver infrastructure is extended with WF semantics (`:semantics :well-founded`), the BSP scheduler should use bitonic merge scheduling for the lfp/gfp alternation. This is Track 3+ scope but the structural connection should be captured now.

---

## §3 SRE Lattice Lens: Boolean Powerset with Adjacency

### §3.1 The New SRE Property: Adjacency Metric

The Boolean powerset lattice has algebraic properties (Boolean, distributive, etc.) that we already catalog. The hypercube adds a METRIC property — Hamming distance between elements — that is not captured by the algebraic structure alone.

Proposed SRE property declaration:

```prologos
property HypercubeAdjacency {L : Lattice}
  :where [Boolean L]                          ;; only applies to Boolean lattices
  :metric hamming-distance                    ;; number of differing elements
  :diameter n                                 ;; max distance = number of generators
  :recursive-decomposition (L = L_{n-1} × L_1)  ;; splitting on one generator
```

This property enables:
- **Gray code ordering**: explore elements in minimum-metric-step order
- **Subcube identification**: nogoods identify subcubes by bitmask
- **Dimension-ordered operations**: process one generator at a time (log n rounds)

### §3.2 Bitmask Representation as SRE Structure

If the Boolean powerset is represented as bitmasks, the SRE structural operations become bitwise:

| SRE Operation | Set Operation | Bitmask Operation |
|---|---|---|
| Meet (∩) | Intersection | AND |
| Join (∪) | Union | OR |
| Complement | Set complement | NOT (XOR with all-1s) |
| Subset test | ⊆ | `(a AND b) == a` |
| Symmetric difference | Δ | XOR |
| Hamming distance | \|Δ\| | popcount(XOR) |
| Adjacency test | \|Δ\| = 1 | popcount(XOR) == 1 |
| Subcube membership | nogood ⊆ worldview | `(wv AND ng) == ng` |

These are O(1) for n ≤ 64. The SRE could recognize Boolean lattices with n ≤ 64 and automatically use bitmask representation for all operations.

### §3.3 Galois Connections to Other Domains

The adjacency structure adds new bridge possibilities:

| Bridge | From | To | What it captures |
|---|---|---|---|
| Hamming → CHAMP sharing | Adjacency distance | CHAMP structural diff size | Lower distance = more sharing |
| Subcube → Nogood scope | Subcube bitmask | Set of pruned worldviews | O(1) subcube identification |
| Dimension → BSP round | Hypercube dimension k | BSP superstep k | One dimension processed per round |

---

## §4 What Changes in the Design vs What's New Infrastructure

### Changes to existing phases (refinements, not rewrites)

| Phase | What changes | Why |
|---|---|---|
| 6 | Branch exploration order follows Gray code | Maximizes CHAMP reuse |
| 3 | Optional bitmask representation for assumption sets | O(1) subcube pruning |
| 9-10 | Hypercube all-reduce for BSP barriers | Optimal synchronization topology |

### New infrastructure (additive)

| Component | What | Where |
|---|---|---|
| Gray code generator | Produces reflected Gray code ordering for n bits | `decision-cell.rkt` or new `hypercube.rkt` |
| Bitmask assumption set | Bitmask representation alongside hasheq | `decision-cell.rkt` |
| Hypercube all-reduce barrier | log_2(T)-round merge pattern | `propagator.rkt` BSP section |
| SRE adjacency property | HypercubeAdjacency on Boolean lattices | `sre-core.rkt` |

### What does NOT change

- Decision cell lattice design (powerset IS the Boolean lattice — same thing)
- Broadcast propagator infrastructure (butterfly IS the broadcast structure)
- Per-nogood commitment cells (structurally sound, bitmask is optional optimization)
- Assumption-tagged dependents (on-network viability checking is correct)
- PU-per-branch model (CHAMP structural sharing is the mechanism Gray code exploits)

---

## §5 Open Questions

1. **Should bitmask representation replace hasheq or coexist?** For n ≤ 64, bitmask is strictly faster for all set operations. For n > 64, bitvector or fall back to hasheq. The SRE could auto-select based on n.

2. **Gray code ordering for non-power-of-2 branch counts?** Standard Gray code works for 2^n elements. When `atms-amb` produces M branches where M is not a power of 2, use a partial Gray code (first M elements of the n-bit code where 2^{n-1} < M ≤ 2^n).

3. **Does the hypercube all-reduce apply within a single BSP superstep?** The all-reduce is a synchronization BETWEEN supersteps. Within a superstep, propagators fire independently. The hypercube structure applies to the BARRIER phase, not the fire phase.

4. **How does this interact with the Hyperlattice Conjecture?** The hypercube is the Boolean lattice as a communication graph. The Hyperlattice Conjecture says every computation is a fixpoint on lattices. The hypercube algorithms show the OPTIMAL COMMUNICATION PATTERN for these fixpoints. This connection should be explored — is the hypercube the "optimal structure" the conjecture predicts?

---

## §6 Cross-References

| Document | Relevance |
|---|---|
| [Parent design D.6](../tracking/2026-04-07_BSP_LE_TRACK2_DESIGN.md) | This addendum extends Phases 3, 6, 9-10 |
| [Parallel Propagator Scheduling](2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md) | Array programming patterns, prefix scan = butterfly |
| [Propagator Taxonomy](2026-03-28_PROPAGATOR_TAXONOMY.md) | Broadcast, scatter, gather kinds |
| [Categorical Foundations](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) | Polynomial functors, Kan extensions |
| [DESIGN_PRINCIPLES.org](../tracking/principles/DESIGN_PRINCIPLES.org) § Hyperlattice Conjecture | Motivation |
| [Hypercube Conversation](../standups/standup-2026-04-08.org) § "Hypercube Conversation" | Source research |
