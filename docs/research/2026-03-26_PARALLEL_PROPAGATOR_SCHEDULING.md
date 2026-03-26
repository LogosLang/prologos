# Parallel Propagator Scheduling and Array Programming — Research Note

**Date**: 2026-03-26
**Stage**: 0 (Conversational insight from PPN Track 1 design discussion)
**Series touches**: BSP-LE, PPN, PRN, PM

**Related documents**:
- [BSP-LE Master](../tracking/2026-03-21_BSP_LE_MASTER.md) — logic engine on propagators
- [PPN Track 1 Design](../tracking/2026-03-26_PPN_TRACK1_DESIGN.md) — tree-builder as prefix scan
- [PRN Master](../tracking/2026-03-26_PRN_MASTER.md) — theory series
- [Hyperlattice Conjecture discussion](../tracking/2026-03-26_PPN_TRACK1_DESIGN.md#1-architectural-center) — any computation as fixpoint

---

## 1. The Gap: Sequential BSP vs True Parallelism

Our current BSP scheduling is sequential — the worklist drains one
propagator at a time in BFS order. "BSP" in our system means
"breadth-first stratum processing," not Valiant's Bulk Synchronous
Parallel where processors fire independently and synchronize at barriers.

The CALM theorem (Consistency As Logical Monotonicity) guarantees:
monotone computations are coordination-free. The result is the same
regardless of firing order. This means truly parallel firing is
CORRECT for all our monotone propagators. We just don't DO it yet.

## 2. What Truly Parallel Propagation Requires

### 2.1 Lock-free cell reads

Multiple propagators reading the same cell simultaneously. Our CHAMP
and RRB are persistent (immutable) — reads are naturally thread-safe.
No locks needed.

### 2.2 Atomic cell writes

Multiple propagators writing to the same cell. Monotone merge is
commutative: `merge(write_A, write_B) = merge(write_B, write_A)`.
Implementation: compare-and-swap (CAS) on the cell value. Read current,
compute merge with new, CAS. If CAS fails (concurrent writer), retry
with new current value. Convergence guaranteed by monotonicity.

### 2.3 Parallel worklist

N workers pulling from a shared concurrent worklist. Work-stealing
(Cilk/Rayon model) balances load dynamically. Each worker: pull
propagator → fire → write results → pull next.

### 2.4 Barrier synchronization for strata

S0 propagators fire in parallel. When ALL have quiesced → barrier.
S1 propagators fire in parallel. Et cetera. This IS Valiant's BSP:
compute (parallel) → synchronize (barrier) → communicate (read new
cell values) → next superstep.

## 3. Topological-Sort Rounds: The Key Invention

The read-dependency graph of propagators determines the MINIMUM number
of sequential ROUNDS. Within each round, all propagators fire in
parallel.

**Algorithm**:
1. Build dependency graph: propagator B depends on propagator A if B
   reads a cell that A writes.
2. Topological sort: assign each propagator a ROUND number = max(round
   of dependencies) + 1.
3. Execute: Round 0 (all propagators with no dependencies → parallel).
   Round 1 (all propagators whose dependencies are in Round 0 → parallel).
   Et cetera.

**For the parse tree-builder (PPN Track 1)**:
- Round 0 (parallel): all indent measurers (each reads chars, writes
  one indent RRB entry). Embarrassingly parallel — N measurers fire
  simultaneously.
- Round 1 (sequential): tree builder (reads ALL indent entries, writes
  tree M-type). One propagator, O(n) work.

But Round 1's tree builder IS parallelizable as a prefix scan (§4).
So with the prefix-scan optimization:
- Round 0 (parallel): indent measurers
- Round 1 (parallel): prefix-scan tree builder (O(log n) depth, O(n) work)

**Total depth**: O(log n). Total work: O(n). Optimal.

## 4. Prefix Scan as Propagator Pattern

The tree-builder's computation — parent(i) = nearest preceding line
with less indentation — IS a prefix scan.

The indent stack operator is a MONOID ACTION:
- PUSH(indent, id): add to stack
- POP-TO(indent): remove entries ≥ indent
- SIBLING: same indent, replace top

These compose ASSOCIATIVELY: the composition of two stack operations
is another stack operation. Associativity is the requirement for
parallel prefix scan (Blelloch 1990).

**Performance**:
- Sequential: O(n) work, O(n) depth → 102 μs for 4000 lines
- Parallel (p processors): O(n/p + log n) depth → ~8 μs for 4000
  lines on 10 processors (12× speedup)

## 5. Array Programming as Propagator Patterns

Array operations ARE propagator patterns:

| Array operation | Propagator pattern | Parallelism |
|----------------|-------------------|-------------|
| `map f array` | One propagator per element, all independent | Embarrassingly parallel |
| `scan + array` | Binary reduction tree (O(log n) depth) | Parallel prefix scan |
| `reduce + array` | Same tree, only root produces output | Parallel reduction |
| `filter pred array` | Per-element predicate + compaction | Parallel with scan for indices |
| `broadcast val array` | One source cell, N reader propagators | Embarrassingly parallel |

The scheduler RECOGNIZES these patterns in the dependency graph and
applies the optimal parallel schedule. No special "array mode" —
the parallelism falls out of the propagator structure.

**The invention**: a scheduler that DISCOVERS array-operation patterns
in the dependency graph and applies known-optimal parallel schedules
(prefix scan, reduction tree, work-stealing map). The propagator
model EXPRESSES the computation; the scheduler OPTIMIZES the execution.

## 6. Connection to BSP-LE

BSP-LE Track 0 (allocation efficiency) optimized CHAMP operations.
BSP-LE Track 4 envisions parallel exploration. The parallel scheduler
is the BRIDGE:

- **BSP-LE Track 4** adds parallel exploration (multiple ATMS branches
  on different processors). Each branch runs to fixpoint independently.
  Nogoods are shared via CAS on the ATMS nogood set.

- **Parallel propagator scheduling** (this research) adds parallel
  firing WITHIN a single branch. Monotone propagators with no
  read-dependencies fire simultaneously.

- **Combined**: branches explore in parallel (BSP-LE Track 4) AND
  within each branch, propagators fire in parallel (this research).
  Two levels of parallelism.

## 7. Implementation Path

1. **Current (Track 1)**: Sequential scheduler. Correct. Fast enough
   (~306 μs for parse, ~134s for test suite).

2. **BSP-LE Track N (parallel scheduler)**: Topological-sort rounds.
   Propagators in the same round fire on OS threads (Racket futures
   or foreign-thread integration). CAS for cell writes. Barrier at
   round boundaries.

3. **Array programming track**: Register array operations (map, scan,
   reduce) as propagator PATTERNS. The parallel scheduler recognizes
   patterns and applies optimal schedules. Users write `map f xs` and
   get parallel execution automatically.

4. **Self-tuning**: The scheduler measures per-round parallelism
   (how many propagators fire per round) and adapts: if parallelism
   is low (most rounds have 1-2 propagators), fall back to sequential
   (lower overhead). If high (rounds with 100+ propagators), use
   parallel execution.

## 8. The Hyperlattice Conjecture Connection

**Postulate**: Any computation as fixpoint over lattice structures.
**Corollary**: Optimal computation exists on the structure.

The parallel scheduler DISCOVERS the optimal computation: the
topological-sort rounds give the MINIMUM sequential depth. The
parallel firing within each round gives maximum concurrency.
The CALM theorem guarantees correctness. This IS the Corollary
realized — the scheduler finds the optimal execution order
from the lattice structure.

## 9. Open Questions

1. **Can Racket's runtime support truly parallel propagator firing?**
   Green threads (cooperative) won't work. Racket futures have
   restrictions (no mutation in futures). Racket Places have
   serialization barriers. OS thread integration via FFI is possible
   but complex.

2. **What is the overhead of CAS on cell writes?** If CAS retry is
   frequent (many propagators writing the same cell), contention
   could negate parallelism benefits.

3. **Can the scheduler's topological sort be INCREMENTAL?** When a
   propagator is added or removed, updating the round assignments
   without full re-sort. Important for dynamic networks (Track 7
   grammar extensions).

4. **What is the minimum parallelism threshold?** Below some number
   of independent propagators, parallel overhead exceeds sequential
   cost. The scheduler should detect this and stay sequential.

5. **Does the prefix-scan pattern compose with ATMS branching?**
   A prefix scan within a speculative branch: does the scan see
   branch-local cell values (via worldview filtering)? The
   interaction between parallel scan and TMS tagging needs design.
