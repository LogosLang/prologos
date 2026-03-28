# Research: Parallel Propagator Scheduling

**Date**: 2026-03-28
**Stage**: 0/1 (Research — feeds PAR Track 2 design)
**Context**: PAR Track 1 established BSP-as-default with CALM-correct sequential scheduling. This document explores true parallelism: concurrent propagator execution across cores.

---

## 1. Current State

PAR Track 1 delivered BSP scheduling with structural propagator capture. The `sequential-fire-all` executor fires all worklist propagators against the same snapshot, one at a time. The "parallel" in BSP refers to the scheduling model (all see same snapshot), not concurrent execution.

**What we have**:
- CALM-correct BSP: order-independent monotone fixpoint
- `fire-and-collect-writes` + `bulk-merge-writes`: captures value diffs, new cells, new propagators, contradictions
- Snapshot isolation: fire functions see consistent state
- Two-fixpoint outer loop: value stratum + topology stratum
- A/B benchmarks: BSP 2.3% faster than DFS (within noise)

**What we need**: Replace `sequential-fire-all` with a concurrent executor that fires N propagators simultaneously on N cores.

---

## 2. Racket 9 Parallelism Landscape

### 2.1 Parallel Threads (NEW in Racket 9)

[Racket 9 introduced parallel threads](https://blog.racket-lang.org/2025/11/parallel-threads.html) — shared-memory OS threads created via `(thread #:pool 'own ...)`. Key properties:

- **Shared memory**: All threads see the same heap. No serialization needed.
- **CAS operations**: `box-cas!` uses processor-level atomics. Lock-free algorithms work.
- **GC**: Not parallelized with the program. GC pauses all threads.
- **Memory model**: Exposes machine's weak memory model (not sequentially consistent).
- **Overhead**: 6-8% for sequential programs with fine-grained mutable operations.
- **What works**: Parameters, mutable hash tables, struct operations — things that blocked futures.

**Assessment for our use**: Parallel threads are the right primitive. Our fire functions use struct-copy (allocation), CHAMP operations (functional), and net-cell-write (merge). All of these should work in parallel threads. The weak memory model is fine because each fire function operates on its own snapshot (no shared mutable state during firing).

### 2.2 Futures (Limited)

Futures block on allocation, GC, parameters, and many Racket operations. Our fire functions allocate heavily (struct-copy, CHAMP insert). **Not viable for general propagator firing.**

We already have `make-parallel-fire-all` using futures in propagator.rkt. It works for simple fire functions but blocks for most real ones. Parallel threads remove these limitations.

### 2.3 Places (Heavyweight)

Separate VMs with message-passing. Too heavyweight for per-propagator or per-round parallelism. Might be useful for coarse-grained parallelism (e.g., test suite parallelism, which we already have via batch workers).

### 2.4 FFI (Escape Hatch)

Racket's FFI to C/Rust could provide a parallel executor. The fire function would need to be representable in the foreign language. For our immutable CHAMP-based networks, this would require serializing the network or sharing memory via the FFI. High complexity, uncertain benefit.

**Recommendation**: Start with parallel threads. They're native, shared-memory, and support the operations our fire functions use.

---

## 3. Concurrent Data Structure Considerations

### 3.1 Our Current Architecture

Fire functions receive an **immutable snapshot** and return a **new immutable network**. `fire-and-collect-writes` diffs the result against the snapshot. `bulk-merge-writes` applies all diffs to the canonical network.

This is already parallel-friendly:
- Each fire function operates on its own copy (snapshot). No contention during firing.
- The merge phase is sequential — applies diffs one at a time.

**The contention point is `bulk-merge-writes`**, not the fire functions. If we parallelize firing but keep merge sequential, the speedup is bounded by `fire-time / (fire-time + merge-time)`.

### 3.2 Lock-Free CHAMP

[CHAMP](https://en.wikipedia.org/wiki/Hash_array_mapped_trie) (Compressed Hash-Array Mapped Prefix-tree) is inherently concurrent-safe when immutable — multiple threads can read the same CHAMP simultaneously. Our CHAMPs are persistent (structural sharing), so concurrent reads are free.

For the merge phase, we need concurrent writes. Options:
- **Sequential merge** (current): O(total-diffs). Simple, correct.
- **Partitioned merge**: Split diffs by cell-id hash range. Each partition merges independently. O(total-diffs / K) with K partitions.
- **CAS-based merge**: Each diff applied via `box-cas!` on a shared mutable cell store. Retries on conflict. O(diffs) with low contention (most propagators write to disjoint cells).

### 3.3 The Clojure Approach

[Clojure's persistent data structures](https://github.com/clojure/clojure/blob/master/src/jvm/clojure/lang/PersistentHashMap.java) are immutable and safe for concurrent access. Mutations go through atoms (`swap!` with CAS) or refs (STM). For our case, the atom approach maps well: the canonical network is an atom, and each merge is a `swap!` (CAS retry on conflict).

### 3.4 Recommended Approach

**Phase 1**: Keep the current architecture. Parallelize firing only. `bulk-merge-writes` stays sequential. This gives us `fire-time` speedup with zero merge complexity.

**Phase 2**: If merge becomes the bottleneck, switch to CAS-based merge using `box-cas!` on a shared network box. Each thread applies its diffs via CAS, retrying on conflict. Contention is low because propagators mostly write to disjoint cells.

---

## 4. Scheduling Strategies

### 4.1 From Datalog: Semi-Naive + Partitioned Relations

[Souffl&eacute;](https://souffle-lang.github.io/pdf/cc.pdf) compiles Datalog to parallel C++ using semi-naive evaluation. Key insights:
- **Partitioned relations**: Data is partitioned across threads. Each thread processes its partition independently. Cross-partition communication via shared data structures.
- **Work-list per thread**: Each thread maintains its own work-list. Stolen work from other threads when idle (work-stealing).
- **Delta computation**: Only new tuples (deltas) are processed each round, not the full relation. This is analogous to our BSP round — only dirty propagators fire.

**Applicability**: Our propagator network IS a set of relations (cells) with rules (propagators). The Souffl&eacute; approach of partitioning by relation and using semi-naive evaluation maps directly to our BSP with per-round worklists. The work-stealing optimization would help with load balancing when propagators have unequal fire times.

### 4.2 From Timely Dataflow: Logical Timestamps + Progress Tracking

[Naiad/Timely Dataflow](https://dl.acm.org/doi/10.1145/2517349.2522738) uses logical timestamps to track progress through iterative computations. Each operator processes data at specific timestamps, and the system tracks which timestamps are "complete" (all data processed).

**Applicability**: Our BSP rounds are implicit timestamps. The topology stratum is a "loop" in Timely Dataflow terms. Progress tracking (knowing when a round is complete) is already handled by BSP's synchronization barrier. Timely Dataflow's approach of fine-grained timestamps within a round could enable pipelining — propagators from round N+1 start firing as soon as their inputs from round N are available, without waiting for the full round to complete.

### 4.3 Chunk-Based Parallelism

Partition the worklist into K chunks (K = core count). Each chunk fires sequentially on its own thread. After all chunks complete, merge results.

- **Pros**: Low overhead (K threads, not N). Load balancing via equal-sized chunks.
- **Cons**: Unequal fire times lead to idle threads. No work-stealing.
- **Variation**: Dynamic chunk sizing with work-stealing queue.

### 4.4 The `:auto` Heuristic

When to parallelize:
- **Worklist size threshold**: Parallel only when `len(worklist) > K * min_batch`. Below this, sequential is faster (thread overhead > fire time savings).
- **Fire function cost**: If average fire time > thread spawn overhead (~10-100&mu;s), parallel wins. Our M2 measured ~1&mu;s per fire — so we need ~100 propagators per round.
- **Network size**: Larger networks have more independent propagators. Smaller networks are better served by DFS.
- **Historical data**: Track the ratio of fire-time to merge-time per network. If fire-time dominates, parallelize.

---

## 5. Write Contention and Merge Strategies

### 5.1 The Monotone Merge Advantage

Our lattice merges are **commutative, associative, and idempotent** (for well-behaved lattices). This means:
- `merge(merge(A, B), C) = merge(A, merge(B, C))` — order doesn't matter
- `merge(A, A) = A` — duplicate writes are harmless
- No need for conflict detection or abort-retry

This is strictly simpler than general STM. STM handles arbitrary read-write conflicts. We only have monotone writes to shared cells with commutative merge.

### 5.2 Simplified STM: Lattice-Merge Transactions

Instead of full STM (abort on conflict), we can use **lattice-merge transactions**:
1. Each thread fires propagators against the snapshot
2. Each thread collects write diffs locally
3. Merge phase: apply all diffs to canonical network
4. For concurrent merge: use `box-cas!` with lattice join as the CAS update function

If two threads write to the same cell, the CAS retry applies the lattice join of both values. Since `merge(merge(old, A), B) = merge(old, merge(A, B))` (associativity), the result is the same regardless of merge order.

### 5.3 WAL (Write-Ahead Log) Approach

Each fire function writes to a thread-local log. After all threads complete, logs are merged sequentially. This is essentially our current architecture with concurrent firing.

- **Pro**: Zero contention during firing. Merge is deterministic.
- **Con**: Merge is sequential (the current bottleneck moves from firing to merging).
- **Optimization**: Sort logs by cell-id, then merge in parallel by partition.

### 5.4 Known Limitation: Non-Idempotent Merges

PAR Track 1 discovered that `list-append` (non-idempotent) causes double-merge issues under BSP. For parallel execution, non-idempotent merges are even worse — N threads could each produce a merged value that gets merged again during the bulk-merge phase. **Any cell with a non-idempotent merge function must be excluded from parallel firing** (forced sequential for that propagator).

---

## 6. Measurement Needs

Before designing the parallel executor, we need empirical data:

### 6.1 Worklist Size Distribution

We have PERF-COUNTERS but not a "propagators-per-BSP-round" histogram. We need:
- Average worklist size at each BSP round entry
- Distribution: what fraction of rounds have >10, >100, >1000 propagators?
- This determines whether parallelism is worthwhile (>100 propagators per round needed)

### 6.2 Fire Function Duration Distribution

M2 measured ~1&mu;s for a trivial fire. But real fire functions vary:
- SRE structural relate: may decompose (create cells+propagators)
- Narrowing: may evaluate RHS (create cells)
- Simple value propagation: ~1&mu;s
- Complex type-checking: potentially 10-100&mu;s

We need a histogram of actual fire durations from the test suite.

### 6.3 Merge Phase Cost

How long does `bulk-merge-writes` take? Is it dominated by `net-cell-write` calls (merge function evaluation) or CHAMP operations (structural)? This determines whether merge parallelization is needed.

### 6.4 Thread Spawn/Join Overhead

Racket 9 parallel threads: what's the actual cost of `(thread #:pool 'own ...)` and joining? This determines the minimum batch size for parallelism.

### 6.5 GC Impact

Parallel fire functions allocate heavily (struct-copy per cell write). Does this trigger more frequent GC? Does GC pause time scale with thread count?

---

## 7. Proposed Research Program

### Phase R1: Instrumentation (1-2 hours)

Add per-BSP-round counters:
- Worklist size at round entry
- Total fire time per round (wall clock)
- Total merge time per round
- Number of cell writes per round
- Write contention: how many propagators write to the same cell in one round?

Run the full test suite + adversarial benchmarks with instrumentation. Produce histograms.

### Phase R2: Parallel Thread Proof-of-Concept (2-3 hours)

Replace `sequential-fire-all` with a parallel version using Racket 9 parallel threads:
- Partition worklist into K chunks
- Fire each chunk on a parallel thread
- Join all threads
- Merge results sequentially (current `bulk-merge-writes`)

Measure: wall time, speedup ratio, thread overhead.

Test on: `type-adversarial.prologos` (3.9s, CPU-bound) and `constraints-adversarial.prologos` (0.7s).

### Phase R3: Contention Analysis (1-2 hours)

From R1 data, analyze:
- What fraction of cell writes conflict (same cell from different propagators)?
- For conflicting writes, is the merge order-independent? (Should be, for idempotent merges.)
- What's the maximum write set overlap between any two propagators in a round?

This determines whether CAS-based merge is practical or if sequential merge suffices.

### Phase R4: Literature Survey (2-3 hours)

Deep dives into:
- [Souffl&eacute;'s parallel C++ backend](https://souffle-lang.github.io/pdf/cc.pdf): partitioning, work-stealing, delta computation
- [Timely Dataflow in Rust](https://github.com/TimelyDataflow/timely-dataflow): progress tracking, pipelining, operator scheduling
- [Parallel union-find](https://dl.acm.org/doi/10.1145/2517349.2522738): lock-free merge operations on shared data structures
- CRDTs (Conflict-free Replicated Data Types): lattice-based merge without coordination — directly applicable

### Phase R5: Design Document (2-3 hours)

Synthesize R1-R4 into a PAR Track 2 Stage 3 design document:
- Architecture: which parallelism mechanism (parallel threads + WAL merge)
- Granularity: chunk-based vs per-propagator
- `:auto` heuristic: thresholds from R1 data
- Implementation phases
- Success criteria: >2x speedup on type-adversarial workload

---

## 8. Open Questions

1. **Is our propagator workload CPU-bound or memory-bound?** If memory-bound (CHAMP cache misses dominate), parallelism may not help — all threads contend for the same L3 cache.

2. **Can we pipeline BSP rounds?** Instead of waiting for all propagators to complete before starting merge, start merging as soon as some complete. This overlaps fire and merge latency.

3. **Should the `:auto` heuristic be adaptive?** Start with DFS, switch to BSP+parallel after measuring the first few rounds. Or: track per-network statistics across commands and use historical data.

4. **What about NUMA?** On multi-socket systems, memory locality matters. Should we partition the network by NUMA domain?

5. **How do LKan/RKan bridges interact with parallelism?** Bridges cross strata. If two propagators in different strata fire in parallel, the bridge semantics must be preserved. Our current stratification (S(-1)/S(0)/S(1)/S(2)) is sequential between strata. Parallelism is within a stratum only.

6. **Can we use Racket's `unsafe-fx+` family for lattice operations?** If merge functions use only fixnum arithmetic, unsafe operations avoid the overhead of type checks. This could make individual fire functions faster regardless of parallelism.

7. **Multi-strata towers**: What if we have multiple topology rewrites that want to happen on different parts of the same underlying topology? Can we do parallel exploration over multiple rewrites safely? This connects to e-graphs (PReduce) and hypergraph rewriting (PRN) — both involve exploring multiple rewrite paths simultaneously.

8. **Write-ahead log vs shared-state**: For our specific workload (many small writes to disjoint cells), is WAL or shared-state faster? WAL has zero contention but pays merge cost. Shared-state has contention on hot cells but no separate merge phase.

---

## 9. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| GC pauses dominate parallel overhead | Medium | High | Measure GC time per round. If >50% of fire time, parallelism is moot. |
| Thread spawn overhead > fire time savings | Medium | Medium | Chunk-based parallelism with min batch size. `:auto` threshold. |
| Non-idempotent merges in production code | Low | Medium | Audit all merge functions. Flag non-idempotent ones for sequential-only. |
| Weak memory model causes subtle bugs | Low | High | Use `box-cas!` for all shared writes. Avoid raw mutation. |
| CHAMP allocation pressure triggers excessive GC | Medium | Medium | Profile allocation rate. Consider CHAMP node pooling. |

---

## Sources

- [Parallel Threads in Racket v9.0](https://blog.racket-lang.org/2025/11/parallel-threads.html)
- [Racket Parallelism Guide](https://docs.racket-lang.org/guide/parallelism.html)
- [Racket Futures Reference](https://docs.racket-lang.org/reference/futures.html)
- [Naiad: A Timely Dataflow System](https://dl.acm.org/doi/10.1145/2517349.2522738)
- [Timely Dataflow in Rust](https://github.com/TimelyDataflow/timely-dataflow)
- [Souffl&eacute; Parallel Datalog](https://souffle-lang.github.io/pdf/cc.pdf)
- [CHAMP / Hash Array Mapped Trie](https://en.wikipedia.org/wiki/Hash_array_mapped_trie)
- [Lock-Free Hash Trie Design](https://www.sciencedirect.com/science/article/abs/pii/S0743731521000010)
- [Software Transactional Memory](https://en.wikipedia.org/wiki/Software_transactional_memory)
- [Optimizing Parallel Recursive Datalog Evaluation](https://dl.acm.org/doi/pdf/10.1145/3514221.3517853)
- [Clojure PersistentHashMap](https://github.com/clojure/clojure/blob/master/src/jvm/clojure/lang/PersistentHashMap.java)
