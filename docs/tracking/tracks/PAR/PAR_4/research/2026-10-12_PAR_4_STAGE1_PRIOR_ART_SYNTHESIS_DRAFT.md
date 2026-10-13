# PAR 4 · Stage 1 — Prior-Art Synthesis (DRAFT): what our own corpus already settled, what Track 4 can reuse, what the Stage-1 numbers refute

**Serves**: PAR 4 — Arena Executors (`2026-03-27_PAR_MASTER.md:43`). **Status**: DRAFT input to the
Stage-1 synthesis of record (`LOG.md` § "Stage-1 research synthesis commissioned"); a sibling
draft covers the external frontier. **Written at** `7a0116ec`; no source changes, no probes run.
**Method**: full read of the two Track-4 records and the design rules, sectioned reads of the
eleven corpus documents named in the brief, `mempalace search` for cross-checks (hits are
undated; every hit was checked against the newer documents before use). One document *outside*
the brief is included because the search surfaced it and it is the project's own prior art:
`lhc/docs/research/initial/stage1/2026-08-16_STAGE1_B4_SCHEDULER.md` (the LHC Stage-1 scheduler
band — chaotic/asynchronous iteration, CALM, quiescence, with `[V]`/`[U]` verification tags).

**Labels** used throughout: **THEOREM** (stated with its hypotheses), **MEASUREMENT** (ours, with
probe), **PRECEDENT** (someone built it), **CONJECTURE** (ours, testable, mapped to Q1–Q7 or a
Pre-0), **TASTE** (a preference, not a claim). Q1–Q7 are the Stage-2 open questions
(`2026-10-12_PAR_4_STAGE2_GAP_ANALYSIS.md:72-82`).

## 0. Summary

The corpus already contains the theorem Track 4 rests on — chaotic iteration = propagator
scheduling, with the exact hypotheses (monotone, weakly fair, finite height) written down in
`2026-03-26_LATTICE_FOUNDATIONS_PPN.md:418-442` — and the structural result that makes the
ownership partition principled: submodule independence = parallelizability
(`2026-03-28_MODULE_THEORY_LATTICES.md:262-264`), whose proposed experiment (connected components
of the cell→propagator graph) is Pre-0 Q4 under another name. The BSP cost model (Valiant's
`w + h·g + ℓ`, `2026-05-02_PARALLEL_ALGORITHMS_SURVEY.md:43-52`) is reusable *as a model* but
every parameter the corpus assumed is now measured 100× off: `ℓ` is 0.8 µs not 80 µs, `g` is a
60 ns cache-line transfer, and the dominant term was never `w` — it is bytes allocated, at
2.2 GB/s. The corpus's scheduling proposals (CAS on cells, work-stealing worklists, lattice-merge
transactions, hypercube all-reduce of state, topological-sort rounds) all presume either shared
mutable cells or replicated state; the Stage-1 result replaces both with single-owner cells, and
the LHC band supplies the textbook reason — Bertsekas–Tsitsiklis Assumption 2(c), "a node's view of
its own component is never stale", is the condition that fails exactly when two processors update
one component. What the corpus does **not** settle is Q1: it documents one round-atomicity
dependency (between-round narrowing) and already places it at the stratum boundary, but it has no
audit of S0 reads, and its own census (13 `+` merges, 6 `merge-replace`, fuel-on-write) names
cells for which the chaotic-iteration hypotheses do not obviously hold. Those are the audit items.

## 1. Inventory

| # | Document (path, date) | What it claims that bears on Track 4 | Status |
|---|---|---|---|
| 1 | `docs/research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md` §4.2–4.3 (2026-03-26) | Chaotic iteration = propagator scheduling, table of correspondences; worklist strategies affect efficiency not correctness | **REUSABLE** (the theorem Track 4 stands on) |
| 2 | `docs/research/2026-03-28_MODULE_THEORY_LATTICES.md` §7, §10-PAR, §12 (2026-03-28) | Submodule independence = parallelizability; connected components of cell/propagator graph = irreducible submodules; `:auto` has a formal basis; stratification = handling of non-monotone endomorphisms | **REUSABLE** (Q4's theory); the "~1 hour experiment" §7 is Pre-0 Q4 |
| 3 | `docs/research/2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md` (2026-03-26) | CAS on cell writes; shared work-stealing worklist; topological-sort rounds = minimum rounds; futures/green threads block parallelism | **REVISED BY STAGE 1** (§2.2, §2.3, §3, §9.1–9.2); §4 prefix-scan untouched |
| 4 | `docs/research/2026-03-28_PARALLEL_PROPAGATOR_SCHEDULING.md` (2026-03-28) | Parallel threads are the primitive; contention point is `bulk-merge-writes`; CAS-merge Phase 2; WAL = sequential merge; `:auto` by fire time vs spawn cost; "weak memory model fine because snapshots" | **REVISED BY STAGE 1** (§2.1, §3.1, §3.4, §4.4, §5.2–5.3, §6.4–6.5, §8.1, §8.8); §5.4 non-idempotent merges **OPEN** (sharpened, §4 below) |
| 5 | `docs/research/RESEARCH_PARALLEL.md` §9, §12.5, §15.3, §16.1 (undated, pre-PAR) | CALM/LVars/CRDT framing; "work-stealing with affinity" recommended; persistent structures are the default and sidestep reclamation; propagators as unified runtime | §9 **REUSABLE**; §12.5 **REVISED**; §15.3 **REVISED BY STAGE 1** |
| 6 | `docs/research/2026-05-02_PARALLEL_ALGORITHMS_SURVEY.md` §1, §4, §10, §11 (2026-05-02) | Valiant BSP cost model + Multi-BSP; hypercube collectives in log p rounds; Kahn principle (BSP = synchronous specialisation of KPN); Theme 4 "communication, not computation, dominates"; Theme 5 monotone fixpoint = determinism | **REUSABLE** as model/vocabulary; parameters re-measured |
| 7 | `docs/research/2026-05-02_PARALLEL_DECOMPOSITION_AND_HASSE_ADJACENCY_FOR_PROPAGATORS.md` (2026-05-02) | Hyperlattice Conjecture graded by variety; Hasse width = parallelism budget; Garg LLP strongest precedent; Q8.1 "CALM and Hasse adjacency: same theorem?" | **OPEN** — does not yield the ownership partition (§2.6 below) |
| 8 | `docs/research/2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md` §5 (2026-04-30) | Per-domain algebraic level unlocks propagator kinds; Boolean → bitmask O(1) | **REUSABLE** for the flat tier's eligibility test (Q3) |
| 9 | `docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md` §2.1–2.4 (2026-04-08) | Gray-code branch order maximises CHAMP sharing; subcube pruning as bitmask; hypercube all-reduce for BSP barrier ("every thread has the complete merged state") | §2.2 **REUSABLE**; §2.1 **REVISED** (no CHAMP in the arena); §2.3 **SUPERSEDED** (replicated state is what ownership removes) |
| 10 | `docs/research/2026-05-05_ASYNCHRONOUS_PROGRAMMING_QUANTALE_RESEARCH_PROGRAM.md` §1.1, §3.3.7–3.3.8, §8.7 (2026-05-05) | Propagator network ≅ cc(D): closure operators, quiescence = lfp, order-independent; substrate "synchronous in its round structure"; L1 = "Zig-kernel work-stealing, EBR, parallel BSP rounds" | §3.3.7 **REUSABLE**; §1.1 framing **REVISED** (S0 need not be round-synchronous) |
| 11 | `docs/research/PROPAGATOR_NETWORKS.md` § Scheduling Strategies (undated) | Gauss-Seidel vs BSP; "Jacobi converges more slowly than Gauss-Seidel for chain topologies" | **REUSABLE**, confirmed by MEASUREMENT (15 vs 10 rounds) |
| 12 | `docs/tracking/2026-02-23_LATTICE_PROPAGATOR_RESEARCH.md` §1, §2, §6, Cross-cutting (2026-02-23) | LVars threshold reads/freeze; four fork strategies (ATMS labelling vs MUSE copying vs CRDT fork-join); "ATMS avoids physical copying by labelling" | **REUSABLE** for Q2 |
| 13 | `docs/tracking/2026-03-27_PAR_MASTER.md` § Challenge 1 (2026-03-27, revised 2026-10-12) | Futures cannot mutate; threads cooperative; STM/WAL/FFI directions | **SUPERSEDED** (owner's note at :97-104) |
| 14 | `docs/tracking/2026-04-10_BSP_LE_TRACK2B_DESIGN.md:1070-1139` (2026-04-10) | 8 µs OS wakeup is the fundamental bottleneck; spin-wait ineffective; crossover N≈256 | **REVISED BY STAGE 1** (§3 below) |
| 15 | `docs/tracking/handoffs/2026-04-16_BSP_LE_2B_HANDOFF.md:109-112, :118-119` (2026-04-16) | "No Racket-level mechanism beats the OS wakeup cost" (accepted); "scope sharing > bridges" | :109-112 **SUPERSEDED**; :118-119 **REUSABLE** (Q2) |
| 16 | `.claude/rules/stratification.md`, `on-network.md`, `propagator-design.md`, `structural-thinking.md` | Barrier = stratum boundary; cell/propagator/scheduler orthogonality ("behaviour must not depend on sync vs async"); between-round atomicity for narrowing; Realization B (tagging over bridges) | **REUSABLE** — these are the acceptance criteria for Q1 |
| 17 | `lhc/docs/research/initial/stage1/2026-08-16_STAGE1_B4_SCHEDULER.md` §1.1, §1.10, §1.12, §2.2–2.5 (2026-08-16, *outside brief*) | Cousot Prop. 28/29; Bertsekas–Tsitsiklis asynchronism + Assumption 2(c); Üresin–Dubois necessity on finite spaces; quiescence/freeze/frontier/`fix` are one mechanism; Dijkstra–Scholten termination detection; Astrée/PIKOS abandoned async iteration for reproducibility under widening; Soufflé 59× structure → 1.9× fixpoint | **REUSABLE, hand to frontier survey** (already verified in-house) |

## 2. Reusable foundations already written down

### 2.1 Chaotic iteration = propagator scheduling — THEOREM

`LATTICE_FOUNDATIONS_PPN.md:418-442` states the theorem and its three hypotheses: (1) every
transfer function applied infinitely often (fairness), (2) all monotone, (3) finite height. Its
table (variable ↔ cell, transfer function ↔ fire, iteration order ↔ worklist order, fairness ↔
every enqueued propagator eventually fires) is exactly the correspondence Stage 1 §5 relies on when
it says "monotone + fair ⇒ same least fixpoint". The LHC band (§1.1) adds the sharper statements
Track 4 needs and the corpus lacked: Cousot–Cousot Prop. 28 (any weakly fair chaotic sequence
converges to lfp), Prop. 29 (if chains are bounded by `ℓ` and every component evolves within `m`
steps, `lfp = X^m` — a termination *bound*), and the asynchronous generalisation ("reads may
observe stale values"), which is DIRECT mode by name. **How Track 4 uses it**: DIRECT mode's
"same fixpoint at every K" (MEASUREMENT, `arena-tagged*.rkt`) is the predicted consequence, not a
surprise; what still needs checking per cell is hypothesis (2) and (3) — see §4 Q1.

### 2.2 Single owner per cell — THEOREM (B–T Assumption 2(c)), confirmed by MEASUREMENT

LHC band §1.1: under partial asynchronism, clause (c) `τ^i_i(t) = t` — a processor's view of its
*own* component is current — is load-bearing: relaxing it "destroys convergence of certain
asynchronous algorithms", and it is violated "if we allow more than one processor to update the
same component." This is the formal content of Stage 1 §6's "joins commute; owner-bucketed deltas
need no retry": ownership is not an optimisation of CAS, it is the hypothesis that makes the
asynchronous theorem apply. Üresin–Dubois (band §1.1 item 2): on finite state spaces the box
conditions are *necessary* as well as sufficient — a finite-height lattice product is that case,
so there is no cleverer condition to look for. **Use**: owner-only writes become the structural
invariant (gap analysis §4 "illegal states unrepresentable"), and any proposal to let non-owners
write a canonical record must re-prove convergence, not just measure it.

### 2.3 Barrier = stratum boundary; four names for one mechanism — PRECEDENT + our rule

`stratification.md:60-71` already gives each stratum its termination level (S0 Tarski; S1
Gauss-Seidel over forks; S(−1) shrinking assumptions) and `:77-92` the admission test: "does this
computation require other propagators to REACH QUIESCENCE first?" LHC band §1.12 shows four
independent traditions converged on the same rule — Naiad frontiers, LVars freeze, Flo's
boundedness flag, Flix's `fix` ("the same effect on stratification as negation") — *a non-monotone
consumer may read only a value certified complete*. Stage 1 §7's "the barrier is the stratum
boundary" is therefore not new design; it is the project's rule read against DIRECT mode. The
corollary for Q1 is precise: a round-synchronous-visibility dependency inside S0 is, by the
project's own admission test, a stratum that was never declared.

### 2.4 Submodule independence = parallelizability — THEOREM (Krull–Schmidt, finite height) → Q4

`MODULE_THEORY_LATTICES.md:262-264`: "Independent submodules (trivial meet — no shared cells) can
fire concurrently with zero coordination. The submodule lattice IS the parallel partition." And
`:257`: "compute connected components (cells connected if any propagator reads one and writes the
other). Connected components = irreducible submodules." **Use**: this is the *ideal* partition —
cross-partition edges = 0 — and the ownership cut is its relaxation: partitions are the direct
summands, cross-partition deltas are the off-diagonal terms, and the cut size is Valiant's `h`.
The experiment §268 proposed ("dump the cell→propagator graph after quiescence, ~1 hour") was never
run; it is Pre-0 Q4. CONJECTURE to test there: the real network has one giant component because
the request-accumulator cells (`stratification.md:94-120`) and `worldview-cache` are hubs every
propagator touches, so the usable structure is a min-cut *excluding hub cells*, with hub writes
buffered as deltas to the stratum boundary (they are only read there anyway).

### 2.5 BSP cost model and Multi-BSP — THEOREM-shaped model, parameters now MEASURED

`PARALLEL_ALGORITHMS_SURVEY.md:43-54`: `T = w + h·g + ℓ`; speedup is optimal when slackness
`p·ℓ/w ≤ 1`. Multi-BSP (`:67`) adds per-level `(g, ℓ, memory)`. Stage 1 fills in the numbers for
this machine:

| parameter | corpus assumption | Stage 1 measurement (probe) |
|---|---|---|
| `ℓ` barrier | ~80 µs at K=8 (2B `:1108`) | **0.8 µs** at K=8, boxes + fences (`spinpool.rkt`) |
| `g` per unit communicated | 8 µs (semaphore hop) | **58–68 ns** per cache-line handoff (`pingpong.rkt`) |
| `w` per fire | 0.5–1 µs compute | 1.5 µs of which **~1.4 KB of allocation**, wall ≈ bytes ÷ 2.2 GB/s (`census.rkt`) |
| slackness `p·ℓ/w` at K=8, w=1 µs | 640 (hopeless) | **6.4** (one more order of magnitude of fire-weight or batching needed, or ℓ amortised over many fires — which DIRECT does by removing per-round barriers) |
| Multi-BSP level effect | not considered | join cost 62→122→230 ns/cell at K=4/8/16 on local data (cluster-shared L2); false sharing of K adjacent boxes halved K=8 speedup |

Theme 4 (`:625-630`) — "communication, not computation, dominates" — is confirmed with a twist
the survey did not anticipate: on this runtime the dominant data movement is *allocation* (the
allocator mutex plus 2.2 GB/s write bandwidth), not inter-core traffic.

### 2.6 Hasse adjacency, hypercube, Gray code — what transfers and what does not

- **Transfers (THEOREM, Boolean lattice)**: `HYPERCUBE…ADDENDUM.md:50-62` subcube test
  `(wv AND ng) == ng` is O(1); the arena's flat tagged record `[base, n, flag, (bm,v)×E]` (Stage 1
  §5) is the bitmask realisation the addendum asked for. A finer point the corpus implies but did
  not state: the entries component is a powerset lattice whose covering relation is *single
  insertion*; one Hasse edge = one append = one release-fenced word write. That is why the
  append-only DIRECT protocol is lock-free (MEASUREMENT for tagged-cell; CONJECTURE that it
  generalises to any cell whose lattice's covering steps are single-word writes — the 4 fixnum
  lattices qualify, `type-merge` does not).
- **Does not transfer**: the Hyperlattice Conjecture's "Hasse diagram IS the optimal parallel
  decomposition" (`structural-thinking.md:9`) speaks of the *value* lattice; Track 4's partition
  is over the *network graph*. They are different objects: the value lattice's diameter bounds how
  many times a cell can change (re-fire budget; Prop. 29's `ℓ`), the network graph gives the cut.
  The decomposition doc (§8.1 Q1) asks whether CALM and Hasse-adjacency are "the same theorem" —
  for Track 4 the honest answer is that neither gives the partition; module theory (§2.4) does.
  TASTE: say this plainly in the synthesis of record rather than stretch the conjecture.
- **Superseded**: all-reduce of state (§2.3 of the addendum) presumes every thread ends with the
  complete merged network — K replicas — which is the "every byte paid twice" defect multiplied
  by K. With ownership there is nothing to all-reduce; the barrier is a K-flag reduce, and at
  K ≤ 16 a flat scan (≈16 × 60 ns) is within noise of a log₂K tree. Revisit at K ≥ 32 (TASTE).

### 2.7 Propagator ≅ cc(D); quiescence = lfp — PRECEDENT, REUSABLE

`ASYNCHRONOUS…QUANTALE…md:789-823` lays out ask/tell ↔ threshold-read/monotone-write and
"quiescence = least fixed point … independent of the order in which the closure operators are
applied". Reusable as the second independent derivation of §2.1. The same document's framing of
the substrate as "synchronous in its round structure" (`:85`) is now a description of the *BSP
executor*, not of the semantics — see §3.

### 2.8 Fork strategies — PRECEDENT catalogue for Q2

`2026-02-23_LATTICE_PROPAGATOR_RESEARCH.md:63-130` names the three realisations Q2 chooses among:
ATMS labelling (no copy; the project's choice — "scope sharing > bridges", handoff `:118-119`,
`structural-thinking.md:95-105`), MUSE environment copying (what an arena fork by copy *is*), and
stack-splitting (partition-granular COW, the Q2 fallback). The corpus's own verdict — "the ATMS
approach … avoids physical copying by labelling everything" — is why `fork-prop-network` has only
5 sites (gap analysis §0.2); the arena inherits that benefit and pays only where S1 NAF and
fork-on-union genuinely fork.

## 3. Refutations and revisions (old claim → measurement → corrected statement)

| # | Old claim (quoted, cited) | Refuting measurement (Stage 1, probe) | Corrected statement |
|---|---|---|---|
| R1 | "The fundamental bottleneck is Racket's inter-thread communication cost … 8us … This is macOS scheduler cost, not Racket overhead." (`2026-04-10_BSP_LE_TRACK2B_DESIGN.md:1116-1129`) | Semaphore hop 7 302 ns reproduced; `box-cas!`/`set-box!` + acquire/release fence **58–68 ns** one-way (`pingpong.rkt`); FFI crossing 8 ns buys nothing more | The 8 µs is the cost of *scheduler-routed* signals. A raw shared-memory handoff is a cache-line transfer, ~60 ns, in pure Racket 9. The bottleneck was never signalling. |
| R2 | "No Racket-level mechanism beats the OS wakeup cost." (`2026-04-16_BSP_LE_2B_HANDOFF.md:111`) | Same as R1; K=8 dispatch + barrier **0.8 µs/round** vs 2B's ~80 µs (`spinpool.rkt`) | Every mechanism 2B tried (`sync`, `async-channel`, semaphores, `semaphore-try-wait?`) routes through rumble. Boxes with fences do not. |
| R3 | "Spin-wait is ineffective when the inter-dispatch gap (merge time) exceeds the spin window." (`…TRACK2B_DESIGN.md:1081`) | Workers spinning **while a solve is active** (state-bounded) hold the 0.8 µs barrier; 2c's 10 µs count-bounded window was the defect | Spin must be state-bounded (park between solves, Q7), not count-bounded. The lesson was about the window, not about spinning. |
| R4 | "Futures: Cannot perform mutation … Threads: Cooperative, not parallel." (`2026-03-27_PAR_MASTER.md:107-109`); "Green threads (cooperative) won't work. Racket futures have restrictions" (`2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md:178-182`) | Racket 9 `thread #:pool 'own`: pure fixnum work 8.3× at K=8, ~16× at K=16; `unsafe-vector-set!` into per-thread vectors 8.0× (`scale.rkt`) | Already marked superseded by the owner (`PAR_MASTER.md:97-104`). The threads scale; the allocator does not. |
| R5 | "Atomic cell writes … compare-and-swap (CAS) on the cell value … If CAS fails, retry" (`…03-26…SCHEDULING.md:35-41`); "Phase 2: … CAS-based merge using `box-cas!` on a shared network box" (`…03-28…SCHEDULING.md:86`); "lattice-merge transactions" (`:136-144`) | Owner-bucketed dirty lists: **no CAS, no contention**, identical fixpoint at K ∈ {1,2,4,8,16} (`arena-exec*.rkt`); STM "unnecessary" (Stage 1 §6) | CAS on cells is the wrong primitive: it admits multiple writers per component (violates B–T 2(c), §2.2) and a CAS on *one* network box serialises all K. Ownership makes the write a plain store + release fence. |
| R6 | "N workers pulling from a shared concurrent worklist. Work-stealing (Cilk/Rayon model)" (`…03-26…SCHEDULING.md:43-47`); "a hybrid work-stealing with affinity scheduler is recommended" (`RESEARCH_PARALLEL.md:737`) | Dirty lists bucketed by owner; a dense per-executor delta made the join O(K·C) (Stage 1 §5 "three defects") | Fires are scheduled by the *owner of the written cell*, not stolen from a shared queue. Stealing of fires is possible only if writes still go to owner buckets — OPEN, see §5 (straggler spread 2× is the cost to beat). |
| R7 | "Topological sort … assign each propagator a ROUND number … minimum number of sequential ROUNDS" (`…03-26…SCHEDULING.md:56-69`); "Wavefront scheduling … lightweight barrier between levels" (`RESEARCH_PARALLEL.md:735`) | Quiescence test, pure max lattice, 16 384 cells: **BSP 15 rounds, DIRECT 10** (`arena-tagged*.rkt`) | THEOREM (trivial): Jacobi needs depth-many rounds on a chain; Gauss-Seidel in the right order needs one. Topological rounds are a lower bound for *synchronous* schedules only. Inside S0 there is no round to minimise; the barrier belongs at the stratum boundary. |
| R8 | "The weak memory model is fine because each fire function operates on its own snapshot (no shared mutable state during firing)." (`…03-28…SCHEDULING.md:37`) | DIRECT protocol: entry words → `memory-order-release` → count; reader: count → `memory-order-acquire` → entries (Stage 1 §5) | Under DIRECT there *is* shared mutable state; correctness needs the release/acquire pair per record. The snapshot argument held only for the BSP executor. |
| R9 | "The contention point is `bulk-merge-writes`, not the fire functions." (`…03-28…SCHEDULING.md:67`); WAL: "Merge is sequential (the current bottleneck moves from firing to merging)" (`:151`) | Census: light fire = **1.4 KB ceremony (50 %) + 0.5 KB write (17 %) + 0.9 KB re-merge (33 %)**; `fork-prop-network` 1 233 B per fire path copy (`census.rkt`) | Half the cost is *in the fire protocol* (snapshot, returned network, `for/hasheq` output-set, `champ-diff`), not in the merge. And the merge is not sequential: the owner joins its own buckets; in DIRECT it disappears (95 vs 117–131 ns). |
| R10 | "`:auto` … If average fire time > thread spawn overhead (~10-100µs), parallel wins." (`…03-28…SCHEDULING.md:119`); "Thread Spawn/Join Overhead … determines the minimum batch size" (`:186-187`) | Scaling vs allocation intensity: ~1 050 B/µs → 2.8–3.7×; ~45 B/µs → 11.5× at K=16 (`intensity.rkt`); executors are persistent | Spawn cost is irrelevant to parked executors (one ~8 µs wake per solve). The governing variable for speedup is **bytes allocated per µs**, not ns per fire. `:auto` (PAR Track 3) must be re-based on allocation intensity. |
| R11 | "GC pauses dominate parallel overhead — Medium/High — If >50% of fire time, parallelism is moot." (`…03-28…SCHEDULING.md:272`); "Does GC pause time scale with thread count?" (`:191`) | GC disabled (`collect-trip-bytes` 1 GB, 0 ms GC): cons-heavy still **~0.9×** at 8 threads; 8 places 0.8×; `c/alloc.c` `alloc_mutex_acquire()` on every allocation-area refill (`gctune.rkt`, `places.rkt`) | The risk materialised but not as GC: it is the **allocation-area refill mutex**, shared by threads and places, no user knob. GC tuning is not the lever; not allocating is. |
| R12 | "Persistent (immutable) data structures … sidestep the entire reclamation problem … are the default." (`RESEARCH_PARALLEL.md:896-900`); "Our CHAMP and RRB are persistent — reads are naturally thread-safe. No locks needed." (`…03-26…SCHEDULING.md:31-33`) | `champ-lookup` allocates **64 B per read**; replacement insert 352–896 B; the persistent fire pays every byte twice (Stage 1 §4, §8.1) | Persistence buys thread-safe *reads* at the price of an allocation per read and a path copy per write — the very currency the allocator cannot scale. Ownership solves reclamation differently: a single writer never races a reader on its own record, and append-only records need no reclamation inside a solve. Persistence stays right for the *network as value* (fork, `.pnet`), wrong for the hot write path. |
| R13 | "Is our propagator workload CPU-bound or memory-bound? If memory-bound (CHAMP cache misses dominate), parallelism may not help" (`…03-28…SCHEDULING.md:250`) | Wall ≈ bytes ÷ 2.2 GB/s on every path (DFS, ATMS, BSP, `net-cell-write`) (`alloc-per-fire.rkt`) | A third answer: **allocation-bound**. Parallelism does help once allocation is removed (7× at K=8 at today's fire weight). "ATMS is 6–11× slower than DFS" (handoff `:106`) is explained: 8× the bytes. |
| R14 | "hypercube all-reduce … After log₂(T) rounds, every thread has the complete merged state … Reduces barrier latency by ~50%" (`HYPERCUBE…ADDENDUM.md:75-77`) | Flat K-way generation/done boxes: 0.8 µs/round at K=8; owner join 62 ns/cell at K=4 | Replicating merged state to every thread is the double-write defect ×K. Nothing to all-reduce under ownership (§2.6). |
| R15 | PAR Track 2 R2: "4.45× speedup (synthetic). 1.42× on graph coloring/constraint grids." (`PAR_MASTER.md:40`) — recorded without a cause | Intensity law (`intensity.rkt`): the real fires allocate ~2 KB/µs | Not refuted — *explained*. The 3× gap between synthetic and real is the allocation intensity of real fires; the PoC's ceiling was the allocator, not the executor. |

Pattern across R5–R12: every corpus proposal assumed one of two things — **shared mutable cells**
(CAS, transactions, work-stealing writers) or **replicated/persistent state** (all-reduce,
snapshot-per-fire, CHAMP everywhere). The Stage-1 design removes both; the LHC band's Soufflé row
(§2.5: a structure that scaled 59× alone gave 1.9× on the real fixpoint; "bounded by the memory
system and the relation representation, not by scheduling policy") is the external confirmation
that this is the right axis.

## 4. What the corpus says about Q1–Q7

**Q1 — round-synchronous visibility.** The corpus never asked the question for S0 — it assumed
rounds (`ASYNC…QUANTALE…md:85`, `PROPAGATOR_NETWORKS.md:752-764`). What it does record:
(a) `propagator-design.md:177-190` documents one genuine round-atomicity dependency — narrowing
"must be atomic per round; otherwise mid-round partial narrowing could prematurely retract a
branch" — and already realises it as a *between-round stratum handler* (`process-fork-contradiction`,
`process-retraction`). Under DIRECT that handler still runs only at S0 quiescence, so it is
unaffected *provided* S0 quiescence is detected before the handler reads (§4 Q-quiescence below).
(b) `on-network.md:67-70`: an optimisation whose "behavior depends on the scheduler's execution
mode (sequential vs parallel; sync vs async)" is a layering violation. So Q1's acceptance criterion
is the project's own rule: any S0 site whose *result* differs between BSP and DIRECT is a bug to
fix, not a constraint to design around. (c) `propagator-design.md:219` "BSP `fire-and-collect-writes`
MUST use `net-cell-read-raw` … for snapshot/result diffing" — dissolves: there is no diff.
(d) The chaotic-iteration hypotheses checked against the Stage-2 census name three cell classes to
audit (CONJECTURE, each a D.1 audit item): **`+` merge, 13 sites** — not idempotent; the value
depends on *how many times* a propagator fires, which is schedule-dependent under BSP today and
under DIRECT tomorrow; safe only if every contributor is fire-once (`…03-28…SCHEDULING.md:156`
flagged list-append for the same reason). **`merge-replace`, 6 sites** — last-writer-wins is not a
join; order-dependent by construction. **Fuel `#:on-write-check` → contradiction**
(`stratification.md:150-153`) — the contradiction write is monotone, but *whether* fuel is
exhausted before fixpoint depends on the number of intermediate writes, which DIRECT changes
(fewer rounds, unknown fire count); this is the widening-shaped non-monotonicity that made Astrée
and PIKOS abandon asynchronous iteration (LHC band §2.3). Pre-0: run the solver parity suite under
DIRECT (gap analysis Q1) **and** count fires-to-fixpoint BSP vs DIRECT on the fuel-bounded cells.

**Q2 — fork cost vs frequency.** §2.8: the corpus chose labelling over copying and explains the
5 sites. The Gray-code insight (`HYPERCUBE…ADDENDUM.md:42-48`) survives in a different coin: an
adjacent worldview differs by one assumption's *effects*, so a fork needs to copy only the
partitions those effects touched — partition-granular COW is the Hasse-adjacency argument without
CHAMP. The idiom "fork must reset the request cell" (`stratification.md:132-139`) applies unchanged
to a copied arena. Pre-0 Q2 (forks per query) stands; add: cells touched per fork, to size COW.

**Q3 — structured values.** `LATTICE_HIERARCHY…md:251-258`: Boolean/fixnum-representable domains
get O(1) bitmask operations — the eligibility test for the flat tier is the per-domain algebraic
declaration the SRE already carries (Track 2G/2I). For the 53 % heap-valued cells the corpus has
only the canonical-form program (`PARALLEL_DECOMPOSITION…md:195-205`), which is interning by another
name; it is a later track, as the gap analysis says. Pre-0 Q3 (elaborator bytes/µs) is the measure.

**Q4 — partition derivation.** §2.4. The corpus proposed the exact experiment and the exact
theory; Track 4 adds the relaxation (cut, not components) and the hub-cell conjecture.
`RESEARCH_PARALLEL.md:739` "co-locate propagators connected through shared cells" is the same
heuristic in NUMA vocabulary. `on-network.md:43-47` topology requests keep the cut valid: the graph
changes only at the topology stratum, so the partition is recomputed (or grown) there — Q5.

**Q5 — dynamic topology.** Fully covered: `PAR_MASTER.md:21-30` (the CALM guard), PAR Track 1,
`stratification.md`. The LHC band §3.1 names the external theorem (Daggitt–Griffin *dynamic
asynchronous iteration*: convergence needs each epoch to contain enough pseudocycles before
membership changes) — an epoch is a topology stratum; arenas grow there.

**Q6 — serialization.** Nothing in the corpus beyond `MODULE_THEORY_LATTICES.md:286-296` (module
loading as module sum). Gap.

**Q7 — K and parking.** Corpus: `…03-28…SCHEDULING.md:117-121` `:auto` thresholds (now re-based,
R10); 2B's "workers always sleep during merge" (R3). The corpus has no treatment of oversubscription;
Stage 1's "a descheduled spinner holds the barrier for an OS quantum" is new and the K rule
(cores − 2) is TASTE until measured on the owner's machines.

**Quiescence detection without a global barrier** (needed by Q1 and Q7, not numbered). The
prologos corpus has nothing (`…03-28…SCHEDULING.md:105` leans on "BSP's synchronization barrier").
The LHC band supplies it: Bertsekas–Tsitsiklis define termination as quiescence — "(i) no message
in transit, (ii) an update causes no change" (§1.12) — and record that *detection* is benign
(Dijkstra–Scholten) while *modifying the iteration to stop early* is where counterexamples live
(§2.2); LVars: "detecting completion is free; reading the completed value is what costs." For the
arena: (i) = every owner bucket empty, (ii) = every executor idle with no dirty cells — a K-flag
reduce, the one place the stratum handler then reads. CONJECTURE: this reduce is the only barrier
S0 needs, and its cost is the measured 0.8 µs once per stratum transition, not per round.

## 5. Gaps — hand to the frontier survey

1. **Asynchronous-iteration theory with staleness bounds** (Cousot 1977 R.R. 88; Bertsekas 1983;
   Üresin–Dubois 1990; Daggitt–Griffin 2020): the prologos corpus states only the synchronous
   chaotic form. LHC band §1.1 has it with `[V]` tags — reuse, do not redo.
2. **Termination/quiescence detection** (Dijkstra–Scholten 1980; Mattern 1987): absent from
   prologos; LHC band §2.2 cites B–T's summary only.
3. **Partitioned graph engines** (Pregel, GraphLab/PowerGraph vertex-cut vs edge-cut, Ligra,
   Galois): absent. Needed for Q4's cut heuristic and for the straggler/work-stealing question
   (R6): owner-computes vs. steal-fire-write-to-owner-bucket.
4. **Delta-state CRDTs and anti-entropy**: the corpus has CvRDT/CmRDT only (`RESEARCH_PARALLEL.md:551-557`);
   owner-bucketed deltas are delta-state CRDTs by another name — the frontier survey should say
   whether their causal-delivery conditions matter when deltas are joins of the same lattice.
5. **Allocator and region memory** (Chez `alloc.c` behaviour, region/arena allocation, NUMA-aware
   placement): the corpus discusses GC pauses and EBR (`RESEARCH_PARALLEL.md:884-892`), never the
   allocation-area mutex. Also: does Racket's `#:pool 'own` thread get its own allocation area and
   what is the refill granularity (Stage 1 says "segment"; cite the line).
6. **Reproducibility under non-monotone elements** (Astrée's deterministic partitioning, PIKOS's
   rejection of async iteration, Goblint's "sound but not fixpoints"): decides whether DIRECT mode
   must be switchable to buffered per cell class (fuel, `+`, `merge-replace`) — Q1.
7. **Interning/hash-consing for structured lattice values** (Q3): LHC band B2_CELL
   (`2026-08-16_STAGE1_B2_CELL.md:1333, :1554`, Salsa generations) is adjacent prior art.
8. **Serialization of flat tiers** (Q6): nothing anywhere in-house.
9. **Memory-model discipline for the append-only record** (release/acquire pairs, torn reads of
   multi-word entries, false sharing of per-executor state): Stage 1 found three defects
   empirically; the survey should name the formal rules (C11/Racket 9 memory model) so D.1 does
   not rediscover them.

## 6. Bibliography (our documents)

- `docs/tracking/tracks/PAR/PAR_4/research/2026-10-12_PAR_4_STAGE1_CONTENTION_ANALYSIS.md` (§1–§9)
- `docs/tracking/tracks/PAR/PAR_4/2026-10-12_PAR_4_STAGE2_GAP_ANALYSIS.md` (§0–§5)
- `docs/tracking/tracks/PAR/PAR_4/LOG.md`
- `docs/tracking/2026-03-27_PAR_MASTER.md` (:3-30, :36-43, :95-117, :149-151)
- `docs/tracking/2026-04-10_BSP_LE_TRACK2B_DESIGN.md` (:1070-1139)
- `docs/tracking/handoffs/2026-04-16_BSP_LE_2B_HANDOFF.md` (:105-134)
- `docs/tracking/2026-02-23_LATTICE_PROPAGATOR_RESEARCH.md` (:8-61, :63-130, :441-547, :549-587)
- `docs/research/RESEARCH_PARALLEL.md` (:529-565, :677-757, :874-900, :904-916, :1010-1035)
- `docs/research/2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md` (:15-83, :125-200)
- `docs/research/2026-03-28_PARALLEL_PROPAGATOR_SCHEDULING.md` (:24-53, :57-87, :90-121, :125-157, :160-192, :248-276)
- `docs/research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md` (:283-325, :374-517)
- `docs/research/2026-03-28_MODULE_THEORY_LATTICES.md` (:247-268, :333-338, :395-407, :411-421)
- `docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md` (:10-32, :38-89, :178-187)
- `docs/research/2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md` (:243-302)
- `docs/research/2026-05-02_PARALLEL_ALGORITHMS_SURVEY.md` (:27-79, :195-253, :538-590, :593-650)
- `docs/research/2026-05-02_PARALLEL_DECOMPOSITION_AND_HASSE_ADJACENCY_FOR_PROPAGATORS.md` (:21-90, :174-241, :244-302, :483-542)
- `docs/research/2026-05-05_ASYNCHRONOUS_PROGRAMMING_QUANTALE_RESEARCH_PROGRAM.md` (:81-101, :789-835, :2488-2514)
- `docs/research/PROPAGATOR_NETWORKS.md` (:730-765)
- `.claude/rules/stratification.md`, `.claude/rules/on-network.md`, `.claude/rules/propagator-design.md`, `.claude/rules/structural-thinking.md`
- *Adjacent (LHC repo, outside brief)*: `lhc/docs/research/initial/stage1/2026-08-16_STAGE1_B4_SCHEDULER.md` (:64-118, :299-367, :412-422, :468-527); `…_STAGE1_B2_CELL.md` (:1333, :1554)

**Unverified in this draft** (no probe run, no source re-read): the Racket 9 memory-model
guarantees assumed by R8; whether `fork-prop-network`'s 5 sites are all S1/fork-on-union (taken
from the gap analysis, not re-grepped); fire counts to fixpoint under DIRECT vs BSP (Stage 1 reports
rounds only); the LHC band's `[U]`-tagged primaries (Cousot 1977/78, Dijkstra–Scholten, LVars POPL'14).
