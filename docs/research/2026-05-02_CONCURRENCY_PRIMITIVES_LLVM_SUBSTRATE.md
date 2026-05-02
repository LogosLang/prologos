# Concurrency Primitives for the `.pnet` → LLVM Substrate: Layered Catalog, Reference Implementations, and What We'd Build vs. Wrap

**Date**: 2026-05-02
**Stage**: 1 — research synthesis. No design commitments; informs Sprint D and successor concurrency tracks.
**Series**: SH (Self-Hosting), parallel to Track 6 (Runtime services).
**Branch context**: `claude/prologos-layering-architecture-Pn8M9` carries the in-flight prototype. This note is downstream of the architectural commitments in that branch + the SH master.
**Author**: Claude (research synthesis).

**Cross-references:**
- [SH Master Tracker](../tracking/2026-04-30_SH_MASTER.md)
- [Self-Hosting Path and Bootstrap](2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md)
- [Propagator Network as Super-Optimizing Compiler](2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md)
- [BSP-Native Scheduler (current state)](../tracking/2026-05-01_BSP_NATIVE_SCHEDULER.md)
- [Kernel Pocket Universes design](../tracking/2026-05-02_KERNEL_POCKET_UNIVERSES.md)

---

## 1. Frame

What this note accepts as given:

- **`.pnet` lowers directly to LLVM** (not through MLIR). The propagator network *is* the IR; tropical-quantale cost on cells makes equality saturation intrinsic to the merge operation; routing optimization through MLIR's dialect tower would split that single-fixpoint property across two layers and is rejected on architectural grounds (see [super-optimizing compiler note](2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md) §3.1).
- **A thin scheduler runtime is written in Zig**, alongside `.pnet`-aware compiled fire-fn bodies. `runtime/prologos-runtime.zig` is the current realization (sequential).
- **The propagator network's BSP discipline is the parallelism target** — snapshot → fire-all → merge → schedule. CALM-monotone within S0; non-monotone work at higher strata.
- **Pocket Universes (PUs) are the unifying primitive** for nested sub-networks (NAF, ATMS branches, iteration, future passes). Concurrency must compose with the PU model.

What this note asks: **given the above, what concurrency primitives does the Zig kernel need to implement parallel BSP correctly and competitively?** Layered catalog of the operations in a BSP round, reference implementations of each, what to port, what to FFI-wrap, what to write ourselves. Calibration questions to anchor decisions. No implementation plan — that's downstream Sprint D / Track 6 work.

This note is Stage 1. No commitments; informs the design phase.

---

## 2. Current state (factual)

The Zig kernel today (`runtime/prologos-runtime.zig`, 544 lines, single-threaded):

- Flat fixed arrays: `MAX_CELLS=1024`, `MAX_PROPS=1024`, `MAX_DEPS=16`. Cells are `i64`. (Bound for prototype; not production sizes.)
- Three propagator shapes hard-coded — `(1,1)`, `(2,1)`, `(3,1)` — with `switch(tag)` dispatch in `fire_against_snapshot`.
- BSP loop: `take_snapshot` (memcpy of `cells[]` into `snapshot[]`) → drain `worklist[]` against snapshot → append `(out_cid, value)` to `pending_writes` → `merge_pending_writes` (calls `prologos_cell_write` per pending write, which compares to current value and schedules subscribers if changed) → `swap_worklists`.
- Last-write-wins merge (no per-domain merge functions yet).
- Subscriber tracking via `cell_subs[cid][0..num_subs]`.
- Dedup via `in_worklist[pid]` byte array.
- Instrumentation: `stat_rounds`, `stat_fires_total`, `stat_fires_by_tag`, `stat_writes_committed`, `stat_writes_dropped`, `stat_max_worklist`, optional per-tag wall-time profiling.
- `clock_gettime(CLOCK_MONOTONIC)` resolves through vDSO (~30ns per call on Linux x86_64).
- No allocator, no GC, no atomics, no thread library imports. Zero dynamic allocation in the steady state.
- HAMT in Zig (`runtime/prologos-hamt.zig`, 441 lines) lives separately; not yet integrated into cell representation. Track 6 path A.

The BSP-Native design doc (2026-05-01) names the parallelism plan: Sprint D = `std.Thread` worker pool + sharded worklist + per-thread write log + sequential merge. This note is the substrate research for Sprint D and what comes after.

---

## 3. Layered primitive catalog

A BSP round factors into named operations. Per operation, the fastest known native primitive on Linux x86_64 / aarch64, with cost (uncontended) and reference. Costs are single-operation; throughput is operation-dependent.

### 3.1 Snapshot publish (round start)

**What**: make round-`R` cell state visible to all workers as a read-only view.

**Sequential prototype**: `take_snapshot()` memcpy of `cells[i64; 1024]` (8KB per round). Trivial because cells are small and few.

**Production primitive**: **epoch-based reclamation (EBR)** with persistent CHAMP-backed cell store. Snapshot becomes a pointer copy (free); commit creates a new immutable version; readers within the round see the snapshot version; reclamation happens at the round boundary (which is a global epoch advance — a barrier we're already paying for).

**Why EBR not hazard pointers**: HP bound unreclaimed nodes per-thread but pay per-node cost on every read; EBR is "blocking" in the lock-free sense (reclamation can stall under unbounded contention), but BSP gives us **explicit, periodic phase boundaries** — every round-end is an epoch advance that flushes pending reclamation. The pathology that makes EBR blocking in general (a stalled reader holding back reclamation indefinitely) cannot occur because no reader survives a round boundary. We get EBR's performance with HP-equivalent bounded memory because the epoch advances on a known cadence.

**Cost**: 0ns reads, log(N) write to persistent structure (post-CHAMP integration). Reclamation amortized at round boundary.

**References**: [Brown 2017 "Reclaiming Memory for Lock-Free Data Structures"](https://arxiv.org/pdf/1712.01044) (comparison of all three schemes), [libqsbr](https://github.com/rmind/libqsbr) (reference implementation, ~500 lines C, EBR + QSBR variants).

**Algorithm sketch**:
```
struct Epoch { atomic_u64 global_epoch; }
per-thread: atomic_u64 local_epoch = 0;  // 0 = idle, otherwise = epoch when entered

enter_critical(): local_epoch.store(global_epoch.load(), Release)
exit_critical():  local_epoch.store(0, Release)
try_advance():    // called at round boundary
    target = global_epoch.load() + 1
    for t in threads:
        e = t.local_epoch.load(Acquire)
        if e != 0 and e < target: return  // active reader; wait
    global_epoch.fetch_add(1, AcqRel)
    // safe to free everything retired in epoch (target - 2)
```

For our BSP: every worker enters critical at round start, exits at round end. `try_advance` at scheduler barrier. Pre-reclaimed retire-list flushes on advance.

### 3.2 Worklist (per-task pop and steal)

**What**: workers pop ready propagators from their local queue; idle workers steal from busy peers.

**Sequential prototype**: flat array `worklist[MAX_PROPS]` indexed by `worklist_len`.

**Production primitive**: **Chase-Lev work-stealing deque** with the Lê et al. 2013 weak-memory-model ordering. Owner pushes/pops at the bottom (LIFO); thieves steal from the top (FIFO). Lock-free; one CAS on the steal path; relaxed ops on owner path.

**Cost**: ~5-15ns owner pop (no atomic if non-empty), ~30-80ns thief steal (one CAS, often contended).

**References**:
- [Chase & Lev 2005 "Dynamic Circular Work-Stealing Deque"](https://www.dre.vanderbilt.edu/~schmidt/PDF/work-stealing-dequeue.pdf) — original paper, sequentially-consistent.
- [Lê et al. 2013 "Correct and Efficient Work-Stealing for Weak Memory Models"](https://fzn.fr/readings/ppopp13.pdf) — the *correct* memory orderings for ARM/POWER. **This is the implementation to follow.** Note: known integer-overflow bug, fixed in [crossbeam-deque](https://github.com/crossbeam-rs/crossbeam) (Rust) and [ConcurrentDeque](https://github.com/ConorWilliams/ConcurrentDeque) (C++17).
- [wingolog 2022 commentary](https://wingolog.org/archives/2022/10/03/on-correct-and-efficient-work-stealing-for-weak-memory-models) — readable critique of Lê et al. with the bugfix.

**Algorithm sketch** (push/pop owner side; steal side per Lê et al.):
```
Deque { atomic_u64 top, bottom; atomic<Array*> array; }

push(v):  // owner only
    b = bottom.load(Relaxed)
    t = top.load(Acquire)
    a = array.load(Relaxed)
    if (b - t) >= a.size: a = grow(a)
    a[b % a.size] = v
    atomic_thread_fence(Release)
    bottom.store(b + 1, Relaxed)

pop():    // owner only — LIFO
    b = bottom.load(Relaxed) - 1
    a = array.load(Relaxed)
    bottom.store(b, Relaxed)
    atomic_thread_fence(SeqCst)
    t = top.load(Relaxed)
    if t > b: bottom.store(t, Relaxed); return EMPTY  // empty
    v = a[b % a.size]
    if t < b: return v                                 // non-contended
    if !top.compare_exchange(t, t+1, SeqCst, Relaxed):
        v = EMPTY                                       // lost race
    bottom.store(t + 1, Relaxed)
    return v

steal():  // thief — FIFO
    t = top.load(Acquire)
    atomic_thread_fence(SeqCst)
    b = bottom.load(Acquire)
    if t >= b: return EMPTY
    a = array.load(Consume)
    v = a[t % a.size]
    if !top.compare_exchange(t, t+1, SeqCst, Relaxed): return RETRY
    return v
```

**Port to Zig**: ~200 lines. The algorithm is canonical; nothing Prologos-specific. **Wholesale port from crossbeam-deque or ConcurrentDeque, adapt to Zig's `std.atomic` API.**

### 3.3 Per-task dispatch (fire-fn invocation)

**What**: a worker that has popped propagator `pid` invokes its fire-fn against snapshot, produces a write.

**Sequential prototype**: `fire_against_snapshot` does `switch(shape)` then `switch(tag)`, both inlinable by LLVM. Cost ~5ns per fire (i64 arithmetic dominates; switch is predicted).

**Production primitive**: **comptime-specialized per-tag fire batches**. Instead of one switch-on-tag fired per propagator, generate (at scheduler-build time, via Zig's `comptime`) one tight loop per tag that processes all propagators of that tag in a batch. SoA layout (`prop_in0[]`, `prop_in1[]`, `prop_out[]`) is already SoA-friendly. Per-tag batches enable LLVM autovectorization on tags whose fire-fn is uniform (int-add on 4×i64 lanes, etc.).

**Why not function pointers**: dispatch via `fn_ptr_table[tag](inputs, outputs)` defeats inlining and adds an indirect-call cost (~3-5ns + branch-predictor pressure). Switch-on-tag-of-known-set or per-tag specialized loops are both strictly better.

**Cost**: 1-3ns per fire after comptime specialization; 5-10× on uniformly-typed batches via SIMD.

**References**: Zig comptime is the right substrate ([overview](https://kristoff.it/blog/what-is-zig-comptime/)). The transformation is a known-good pattern in Datalog evaluators ([Soufflé semi-naive evaluation](https://souffle-lang.github.io/)) — they generate per-rule specialized C++ code via Futamura projection. Our analog: per-tag specialized Zig at scheduler-build.

**Sketch**:
```zig
// At scheduler-build (comptime), for each (shape, tag) registered in .pnet:
inline fn fire_batch_2_1_int_add(start: u32, end: u32) void {
    var i = start;
    while (i < end) : (i += 1) {  // LLVM vectorizes this loop
        const a = snapshot[prop_in0[i]];
        const b = snapshot[prop_in1[i]];
        pending_val[i] = a + b;
        pending_cid[i] = prop_out[i];
    }
}

// Dispatch: walk the round's worklist, partitioning by tag, invoking the
// specialized batch fn per partition. Partitioning is O(N) but happens once
// per round.
```

**Port**: this is Prologos-specific (the tag set is determined by `.pnet`); cannot be wholesale ported. It's roughly 150 LOC of Zig comptime + per-tag templates.

### 3.4 Atomic operations (CAS)

**What**: the floor primitive for any contended state mutation.

**Cost**: ~10-20ns uncontended; 100-1000+ns contended. **Used sparingly** — every contended atomic in the hot path is a scaling tax.

**Production discipline**: avoid where possible by using per-thread state with merge at barrier. CAS appears in:
- Worklist `top` and `bottom` (Chase-Lev).
- EBR `global_epoch` advance.
- Futex wake/wait on barrier.
- Possibly per-cell write-pending flag if cell-partitioned merge is too coarse.

**Reference**: x86 `lock cmpxchg`, aarch64 `casal`. Zig's `std.atomic` exposes these directly via `cmpxchgWeak` / `cmpxchgStrong`.

### 3.5 Round barrier

**What**: all workers reach round-end before any advance.

**Production primitive**: **sense-reversing barrier** for small N (≤16); **dissemination barrier** for large N (≤64); **hierarchical (tournament) barrier** for very large N or NUMA-aware deployments.

**Cost**: ~50-100ns uncontended at small N; ~200-400ns hierarchical at 64 cores.

**Reference**: Mellor-Crummey & Scott 1991 "Algorithms for scalable synchronization on shared-memory multiprocessors" — canonical. Modern: Brendan Gregg's surveys; Tigerbeetle does *not* need barriers (they're single-threaded by design — see §8 below).

**Sketch (sense-reversing)**:
```zig
const Barrier = struct {
    counter: atomic.Value(u32),
    sense: atomic.Value(bool),
    n: u32,
};

per-thread: local_sense: bool = false

barrier_wait(b: *Barrier):
    local_sense = !local_sense
    if (b.counter.fetchAdd(1, .acq_rel) == b.n - 1):
        // last thread arrived
        b.counter.store(0, .release)
        b.sense.store(local_sense, .release)
    else:
        while (b.sense.load(.acquire) != local_sense): cpu.relax()
```

**Port to Zig**: ~50 lines, wholesale-portable algorithm.

### 3.6 Wait/wake (idle worker parking)

**What**: a worker with no work parks until awoken.

**Production primitive**: **Linux futex**, exposed in Zig 0.13+ via `std.Thread.Futex.wait` / `Futex.wake`. Userspace fast-path; kernel only on actual contention. macOS analog: `__ulock_wait` / `__ulock_wake` (exposed via `os.darwin.ulock_wait` in modern Zig).

**Cost**: ~150ns wake (one syscall in the kernel-trip case; cheaper if uncontended); free wait.

**Discipline**: persistent worker pool, futex-parked between rounds. **Not** thread-fork-per-round. The crossover analysis in `BSP_NATIVE_SCHEDULER.md` (N=32-64 propagators per round) assumed thread-fork cost; with persistent pool + futex park, crossover drops to N>4 propagators per round because the per-round overhead is one futex wake (~150ns) per worker, not one thread-fork (~5μs) per worker.

**References**: [Linux futex(2) man page](https://man7.org/linux/man-pages/man2/futex.2.html); [WebKit ParkingLot](https://webkit.org/blog/6161/locking-in-webkit/) (the polished application of futex-style parking).

### 3.7 Allocator

**What**: any dynamic allocation outside the cell/propagator arenas (e.g., per-round write logs that grow, persistent CHAMP nodes, Chase-Lev deque growth).

**Production primitive**: **mimalloc**, FFI-wrapped from Zig via `@cImport`. v3 simplified ownership model; fast for both uniform and varied allocation patterns.

**Why not write our own**: the gap between mimalloc and a hand-rolled allocator at production scale is ~2 years of perf tuning. Reasonable Zig-native alternatives exist ([jdz_allocator](https://github.com/joadnacer/jdz_allocator), an rpmalloc-style allocator) but for a substrate where allocator behavior under contention matters, mimalloc is the lowest-risk choice.

**Cost**: ~5-10ns per allocation in the per-thread fast path (mimalloc's per-thread heap).

**Integration**: `mi_heap_new()` per worker thread for arena-style allocations; default `mi_malloc` for shared/cross-thread. The Zig FFI is direct via `@cImport({ @cInclude("mimalloc.h"); })`.

**References**: [mimalloc](https://github.com/microsoft/mimalloc); [mimalloc-bench](https://github.com/daanx/mimalloc-bench); [Zig integration discussion](https://github.com/microsoft/mimalloc/issues/561).

### 3.8 Persistent associative map (CHAMP)

**What**: cell representation that allows snapshot-as-pointer-copy.

**Production primitive**: **CHAMP** (Compressed Hash-Array Mapped Prefix-tree), the same data structure Racket's CHAMP cells use. The C++ analog is [Immer](https://github.com/arximboldi/immer) (Sinusoid 2017). Zig has `runtime/prologos-hamt.zig` (441 lines, in progress, Track 6 path A).

**Cost**: ~20-50ns per persistent op with structural sharing; identity comparison free for unchanged subtrees.

**References**: [Steindorfer & Vinju 2015 OOPSLA](https://michael.steindorfer.name/publications/oopsla15.pdf) (CHAMP); [Puente 2017 ICFP "Persistence for the Masses"](https://public.sinusoid.es/misc/immer/immer-icfp17.pdf) (Immer; RRB-Vector + Champ in C++).

**Direction**: don't generalize away from this. The cell representation should evolve toward CHAMP-backed compound values, not away. The first move is: define `Cell` as a value-type alias (currently `= i64`, eventually `= union { scalar: i64, hamt: *HamtNode, ... }`), so generalization doesn't ripple through every fire-fn.

### 3.9 Summary table

| Primitive | Cost (uncontended) | Reference impl | Port strategy |
|---|---|---|---|
| EBR snapshot | 0ns reads | libqsbr | **port + adapt** (~150 LOC Zig) |
| Chase-Lev deque | 5-30ns | crossbeam-deque, Lê et al. 2013 | **port** (~200 LOC Zig) |
| Per-tag fire batches | 1-3ns/fire | none — Prologos-specific | **write ourselves** |
| Atomic CAS | 10-20ns | `std.atomic` | reuse stdlib |
| Sense-reversing barrier | 50-100ns | Mellor-Crummey 1991 | **port** (~50 LOC Zig) |
| Futex park | 150ns wake, free wait | `std.Thread.Futex` | reuse stdlib |
| Allocator (mimalloc) | 5-10ns | microsoft/mimalloc | **FFI wrap** |
| Persistent CHAMP | 20-50ns/op | Immer (C++); existing prologos-hamt.zig | **complete in-progress port** |

---

## 4. The hidden architecture: per-(worker, PU) write logs + cell-partitioned merge

The contention model we cannot afford under multi-thread BSP is "lock-free atomic merge-on-write" — every fire that produces a write attempts a CAS on the destination cell. At ~10-20ns CAS uncontended and 100-1000+ns under contention, with N propagators per round each producing one write, this becomes the bottleneck. BSP-LE 2B's Racket-side measurement (parallel can't beat sequential) had a more pessimistic version of this same problem.

**The architecture that sidesteps it:**

1. **Per-(worker, PU) write log.** Each worker, while bound to a PU for the duration of a round, accumulates writes locally — `(cid, value)` pairs in a thread-local array. No atomics. No contention. The log is the worker's private state for this round.

2. **Cell-partitioned merge.** After fire phase ends, cells are partitioned across workers by `cid mod P` (where P = worker count). Worker `w` is assigned all cells with `cid mod P == w`. For each of its assigned cells, worker `w`:
   - Walks all workers' write logs, pulling out writes destined for this cell (filter by `cid`).
   - Computes the merged value via the cell's domain merge function (last-write-wins, set-union, type-merge, etc.).
   - Compares to the current cell value; if changed, writes the new value and schedules subscribers in worker `w`'s next-round bitset.

3. **Per-worker `in_worklist` bitset.** Replaces the shared `in_worklist[pid]` byte array. OR-merged at round boundary into a single bitset that drives the next round's worklist construction.

This is the BSP analogue of [Differential Dataflow's](https://github.com/TimelyDataflow/differential-dataflow) per-worker *arrangement*. The properties:

- **Zero cross-worker atomic operations during fire phase.** Each worker writes only to its own log.
- **Zero cross-worker atomic operations during merge phase.** Each cell has exactly one merger (the worker whose `cid mod P` matches).
- **The only cross-worker primitives are the round barrier and the worklist deque.** Both are O(1) per round, not O(N) per fire.

Cost estimate: per round, ~`N × 1-3ns` fire work (parallelizable across workers) + ~`N × 5ns` merge work (parallelizable across cells) + ~`200ns` barrier. At N=1000 propagators per round and P=8 workers, round wall ≈ 1000×3ns/8 + 1000×5ns/8 + 200ns ≈ 1300ns. Single-threaded ≈ 8000ns. Speedup ~6× at 8 cores, which is what we'd want.

The interesting question is the worker-binding-per-round contract. Two options:

- **Strict binding** (worker bound to one PU per round): clean write-log architecture; idle workers if some PUs finish early.
- **Inter-round re-binding** (worker can switch PUs at round boundary): better load balancing across sibling PUs running concurrently; same write-log architecture (per round).

Strict binding is the correct starting point. Inter-round re-binding is a Sprint D+1 optimization, gated on measuring whether the load imbalance matters at the workloads we care about.

---

## 5. Layout concerns

The single-threaded prototype has `cells: [MAX_CELLS]i64` — a contiguous 8KB array. Fine. **Once cells become dynamic, layout becomes the dominant scaling concern.**

**False sharing as the actual bottleneck.** A cache line is 64 bytes (128 on Apple Silicon / aarch64). When two threads write to two `i64` cells that share a cache line, the line bounces between caches at MESI-protocol speed (~50-200 cycles per bounce). The 3.1× collapse measured in [alic.dev's false-sharing post](https://alic.dev/blog/false-sharing) is exactly this on a lock-free queue — and the queue had nothing visibly wrong; the contention was purely cache-coherence.

**The architectural commitment that must be made before cells become dynamic:**

```zig
// NOT this:
cells: ArrayList(i64),  // 8 cells per cache line; false sharing endemic

// THIS:
const CellSlot = extern struct {
    value: i64,
    write_pending: u32,
    subscriber_head: u32,
    _pad: [64 - 16]u8 = undefined,  // 64B aligned (or 128B on aarch64)
};
cells: ArrayList(CellSlot),
```

One cell per cache line. 8× memory inflation (8B → 64B) but the working set is small in absolute terms (10K cells × 64B = 640KB), and the false-sharing tax disappears.

**NUMA awareness.** Multi-socket isn't today's concern but the hooks should exist in the cell-allocation API:

```zig
fn prologos_pu_cell_alloc(pu, domain, init_value, numa_hint: i8) CellRef
//   numa_hint: -1 = no preference, 0..N = preferred NUMA node
```

A naive policy ("cells live near the worker most likely to write them, derived from the dataflow graph at lowering time") can be plumbed through later. Today: pass-through, no policy. The point is the *interface* exists.

**Cell affinity from the dataflow graph.** When `.pnet` is lowered, the dataflow graph is known. Cells written by propagators in the same dataflow component should ideally be allocated to the same NUMA node and mapped to workers with affinity to that node. This is a static-analysis problem at lowering time, not a runtime concern. Defer until needed; just preserve the API surface.

---

## 6. PU-aware concurrency

Pocket Universes (per the [kernel PU design doc](../tracking/2026-05-02_KERNEL_POCKET_UNIVERSES.md)) are *namespaces of state*. Schedulers are *execution machinery*. They factor cleanly:

| Resource | Scope |
|---|---|
| Worker thread pool | **process-wide** (one pool, all PUs share) |
| Memory allocator (mimalloc per-thread heaps) | **process-wide** |
| EBR epoch state | **process-wide** |
| NUMA affinity discipline | **process-wide** |
| Round-local write logs | **per-(worker × PU)** |
| Worklist | **per-PU** |
| `in_worklist` bitset | **per-PU** |
| Halt / fuel counter | **per-PU** |
| Round counter, stats | **per-PU** |
| Worldview-bit context | **per-PU** |
| Cell + propagator arenas | **per-PU** |

**One scheduler with PU-aware scheduling state.** Don't proliferate worker pools. The cost of pools-per-PU at small N (4-16) is OS context-switching and cache-thrashing across siblings; at deeper nesting depths (ATMS speculation can spawn dozens of branches) you'd run out of cores fast.

**The exception: sibling PU concurrency.** When a parent stratum handler spawns N independent child PUs (ATMS branches with disjoint worldview bits, fork-on-union per-alternative branches), they can run concurrently — branch A on workers 1-4, branch B on workers 5-8. This is **not** "scheduler-per-PU"; it's a **batched-run primitive on the same scheduler:**

```zig
pub extern fn prologos_pu_run_parallel(
    pus: [*]const PUHandle,
    count: u32,
    fuel_total: u64,
) PUResult;
```

Implementation: workers dynamically partition across the N child PUs, each worker bound to one PU per round but able to re-bind at round boundary. All children barrier together at fuel-exhaust or all-halt. Single API; covers ATMS branches, fork-on-union, parallel speculation, future parallel compiler-pass dispatch.

**Worker-PU binding contract.** The architecturally-load-bearing constraint:

> **A worker is bound to one PU for the duration of one BSP round.** Within a round it can steal *within that PU* (Chase-Lev across same-PU workers) but **not across PUs**. At round boundary it can re-bind to a sibling PU if the parent is in `pu_run_parallel` mode.

This constraint keeps the per-(worker, PU) write log architecture clean. A worker that fires propagators in PU A and then steals from PU B would commingle their writes in a shared log; the merger of B's cells wouldn't see them. Per-round binding sidesteps the issue at no measurable cost — load imbalance within a round is bounded by the round's wall time (microseconds at most) and corrects at the next round boundary.

**Bit allocation for worldview tags.** ATMS-deep recursion can exhaust 64-bit worldview masks (PU design Q2). Strategy: bits are allocated from a per-tree free list at PU spawn; freed at PU dealloc. At depth >64 simultaneous live bits, promote to `BigBitmask` (variable-length); incurs cost; deferred until measurement shows it bites. Path-aware allocation (siblings on disjoint tree paths can reuse bits since they never co-exist in any worldview filter) is a possible optimization, deferred.

**Privileged cell ops under multi-thread.** `cell_overwrite` / `cell_reset` (PU design §5.5) check at runtime that caller is a stratum handler. Implementation: thread-local "current handler" flag, set when worker enters handler invocation, cleared at exit. Cheap. The structurally cleaner answer is Low-PNet IR distinguishing privileged-emit vs regular propagators, with the kernel check as defense-in-depth.

---

## 7. What to wholesale port, FFI to, write ourselves

The substrate factors into three categories with sharply different effort profiles.

### 7.1 Wholesale port (small, canonical algorithms)

These are well-described in literature; reference implementations exist in C/C++/Rust; the Zig version is translation, not invention.

| Algorithm | LOC (estimate) | Reference impl |
|---|---|---|
| Chase-Lev work-stealing deque | ~200 | crossbeam-deque (Rust), ConcurrentDeque (C++17), Lê et al. 2013 |
| Sense-reversing / dissemination barrier | ~50-100 | Mellor-Crummey & Scott 1991 |
| EBR with limbo bags | ~150 | libqsbr (C) |
| Per-thread bitset OR-merge | ~30 | trivial |
| Cache-line-aligned cell slot type | ~20 | trivial |

**Total: ~500 LOC Zig.** None of it Prologos-specific. Each algorithm is canonical and the bug-prone parts (memory orderings) are settled in the cited references. The Lê et al. 2013 weak-memory-model corrections matter — the original Chase-Lev 2005 paper used SC operations which are slow on aarch64; the relaxed/acquire/release mix in the 2013 paper is the modern correct version.

### 7.2 FFI wrap (mature C libraries)

| Library | Why FFI not rewrite |
|---|---|
| **mimalloc** | 2 years of perf tuning at production scale; v3 is well-engineered; rewriting buys nothing |
| **liburcu** (optional) | If we want RCU semantics in addition to EBR; mature, BSD-licensed |
| **libnuma** (optional, Linux) | NUMA topology queries; small surface, but mature |

**Total**: 3 `@cImport` files, ~50 lines of Zig wrapper each. Zig's `@cImport` directly translates C headers; no manual binding work.

### 7.3 Write ourselves (Prologos-specific)

This is the load-bearing original work. No reference implementations because the integration points are specific to our cell + PU + `.pnet` model.

| Component | LOC (estimate) | Why original |
|---|---|---|
| Per-(worker, PU) write log + cell-partitioned merge | ~400 | Specific to our cell model and PU binding contract |
| PU-binding-per-round scheduler logic | ~300 | Specific to our PU semantics |
| `pu_run_parallel` batched-run primitive | ~200 | Sibling concurrency for ATMS / fork-on-union |
| Comptime per-tag specialized fire batches | ~150 + per-tag templates | Specific to our `.pnet` tag set; LLVM autovectorization target |
| `.pnet`-aware cell layout (NUMA hint, affinity) | ~100 | Specific to our `.pnet` format |
| Worldview-bit allocator (per-tree free list, path-aware) | ~150 | Specific to ATMS / PU semantics |
| Privileged cell-op runtime check (thread-local handler flag) | ~50 | Specific to PU design §5.5 |
| Persistent CHAMP cell value generalization | (continues `prologos-hamt.zig`) | Already in flight |

**Total: ~1300-1500 LOC of original Zig.** Concentrated in the `.pnet`/PU integration boundary, which is exactly where prior art *can't* help.

### 7.4 Aggregate library footprint

**~3000-5000 LOC Zig** for the full concurrency substrate. Roughly:
- 500 LOC ported algorithms
- 150 LOC FFI shims
- 1500 LOC original Prologos-specific design
- 500-800 LOC tests + microbenchmarks
- 500-1500 LOC integration with existing `prologos-runtime.zig` + `prologos-hamt.zig`

For comparison: `prologos-runtime.zig` is 544 LOC sequential + `prologos-hamt.zig` is 441 LOC. Adding a parallel substrate roughly 4× the current Zig footprint. Manageable scope; not a multi-quarter effort if focused.

**Suggested module layout:**
```
runtime/
  prologos-runtime.zig         (existing; sequential kernel)
  prologos-hamt.zig            (existing; persistent CHAMP)
  concurrency/
    deque.zig                  (Chase-Lev, ported)
    barrier.zig                (sense-reversing + hierarchical, ported)
    ebr.zig                    (epoch reclamation, ported)
    write_log.zig              (per-(worker, PU) accumulator, original)
    merge.zig                  (cell-partitioned merge, original)
    worker_pool.zig            (persistent pool + futex park, original)
    pu_scheduler.zig           (PU-binding logic + pu_run_parallel, original)
    layout.zig                 (CellSlot + NUMA hooks, original)
    bit_alloc.zig              (worldview bit allocator, original)
    mimalloc.zig               (FFI shim)
```

---

## 8. Benchmark peers

Three engineered systems define the performance tier we're comparing against. Not implementation choices — measurement anchors.

### 8.1 Soufflé (Datalog → C++)

[Soufflé](https://souffle-lang.github.io/) compiles Datalog to parallel C++ via Futamura projection. Production-grade; used for billion-fact program analysis (Doop). Specific innovations:
- **Semi-naive evaluation** + magic-set transformation — both load-bearing for incremental fixpoint.
- **EQREL** ([PACT 2019](https://souffle-lang.github.io/pact19)) — specialized parallel union-find that avoids enumerating all pairs in equivalence classes, scales to half a billion pairs. Reference impl: `souffle-lang/souffle` C++ source.
- Parallel B-trees as the relation backing store.

**Relevance to us**: Soufflé's *exact* problem is bottom-up fixpoint with monotone joins, and they've engineered for it. Their numbers are a hard ceiling we can compare against on workloads that reduce to Datalog (capability inference closure, trait resolution, capability-safety hypergraph analysis from the [capability-Datalog research note](2026-04-23_CAPABILITY_SAFETY_DATALOG_HYPERGRAPHS.md)).

**EQREL specifically**: if any of our merge functions reduce to "compute equivalence closure" (likely candidates: SRE structural unification once it migrates fully on-network; PReduce e-graph merges), EQREL's parallel union-find machinery is the algorithm to study. Reference: [wjakob/dset](https://github.com/wjakob/dset) (lock-free C++ disjoint set with path compression and union-by-rank), [uf_rush](https://github.com/Khojasteh/uf_rush) (Rust port).

### 8.2 Differential Dataflow

[Differential Dataflow](https://github.com/TimelyDataflow/differential-dataflow) (Frank McSherry et al.) is the closest *model* match. Incremental fixpoint with provenance, on timely dataflow. Materialize built a commercial DBMS on it. Specific reference points:
- **Per-worker arrangement** — the per-thread state structure that makes DD scale. Direct precedent for our per-(worker, PU) write log architecture.
- **Differential collections** with timestamps — we don't need the full timestamp lattice yet, but the *shape* of "incremental updates flow through dataflow operators" maps to "incremental cell changes flow through propagators."
- **Reported numbers**: 10M-node / 50M-edge graph computation in ~8 seconds with 2 workers, scaling to multiple workers with sublinear coordination cost.

**Relevance to us**: DD has solved many of the engineering problems we'll face. The patterns transfer; the implementation does not (DD is in Rust and is a runtime library, not a code generator).

### 8.3 Galois / Ligra (graph-shape BSP)

For workloads that look like graph fixpoints — propagator networks where the dependency graph dominates — [Galois](https://iss.oden.utexas.edu/?p=projects/galois) (UIUC) and [Ligra](https://github.com/jshun/ligra) (CMU) are the academic gold standards. Hundreds of GTEPS for graph fixpoints. Numbers worth being aware of even if our workloads aren't pure graph.

### 8.4 TigerBeetle (the engineering discipline)

[TigerBeetle](https://github.com/tigerbeetle/tigerbeetle) is the most successful production Zig systems project. Their *workload* is OLTP financial accounting — fundamentally different from ours (theirs has inherent contention precluding partitioning, hence single-threaded by design). Their *engineering discipline* transfers directly:

- **Determinism as a meta-principle.** Same input → same logical result via same physical path. They built deterministic simulation testing (DST) on top, running 1000 dedicated CPU cores 24/7 for fuzzing. Our `.pnet` round-trip determinism is the same shape — we'd benefit from the same testing infrastructure.
- **Static memory allocation.** TigerBeetle never frees memory and never multithreads. We need both (allocation for dynamic cells; multi-thread for parallel BSP), but the *posture* — explicit budget, no surprises, no GC pauses — is correct.
- **Power-of-Ten safety rules.** NASA-derived. Every loop has a bound. No runaway recursion. Static memory budgets enforced. Adopt the rules even though our workload differs from theirs.
- **Why Zig over Rust.** Their primary cited benefit is the favorable ratio of expressivity to language complexity. Our Sprint D + Track 6 effort would benefit from the same ratio.

References: [TigerBeetle ARCHITECTURE.md](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/ARCHITECTURE.md); [matklad's "Zig and Rust" comparison](https://matklad.github.io/2023/03/26/zig-and-rust.html).

**The honest framing**: TigerBeetle's workload says "single-threaded is correct." Ours says "BSP + per-worker write logs is correct." The engineering discipline is shared; the architectural conclusion differs because the workloads differ.

---

## 9. Calibration questions and measurement methodology

Before committing to any of the above primitives, the prototype needs to surface specific measurements. The Zig kernel already has good instrumentation hooks (`stat_rounds`, `stat_fires_total`, per-tag wall time). What's missing for the parallelism investment decision:

### 9.1 Calibration questions

1. **What is `run_ns / rounds` on the longest-running benchmark today?** Anchors where parallelism crossover lives. If rounds are 5μs each, futex wake (150ns) is 3% overhead; parallelism pays at very small worker counts. If rounds are 50ns each, per-round overhead dominates and we should coalesce rounds, not parallelize within them.

2. **What is `fires_total / rounds` (mean propagators per round)?** Anchors per-round task granularity. With 1-3ns per fire (post comptime specialization), rounds need ~100+ fires for meaningful parallelism at 8 workers. Below that, sequential is correct.

3. **What's the distribution of fires across tags?** If 90% of fires are one tag, comptime-specialized batches for that tag dominate. If fires are uniformly distributed across many tags, batch overhead may not pay.

4. **What's the merge-phase wall time as fraction of round wall time?** If merge is <10% of round, the cell-partitioned merge architecture is over-engineering. If merge is >30% (likely under multi-thread without the architecture), it's the dominant concern.

5. **What's the false-sharing impact at the current scale?** Microbenchmark: two threads writing to adjacent cells in `cells[]` vs separated by cache-line padding. If the impact is <5% at today's small N, layout work is premature; if >20%, it's the highest-leverage immediate change.

### 9.2 Measurement infrastructure to add

Beyond the existing instrumentation, the calibration above wants:

- **Per-round wall-time histogram** (`stat_round_ns_p50`, `_p90`, `_p99`) — not just total `run_ns / rounds`. Mean hides bimodal distributions; percentiles reveal them.
- **Per-tag fire count + wall time** — already present (`stat_fires_by_tag`, `stat_ns_by_tag` when `profile_per_tag` enabled). Confirm this is enabled in the calibration runs.
- **Worklist-size distribution** — current `stat_max_worklist` is high-water mark only. Add a small histogram (round counts per `worklist_len` bucket: 1-10, 10-100, 100-1000, etc.).
- **Cell-write distribution** — which cells are "hot" (written every round) vs cold. Inform NUMA / layout strategy.
- **Microbenchmark harness for false sharing** — small Zig program that writes to two cells in a tight loop, with and without padding, measures L1d miss rate via `perf_event_open`. Can be a one-off; doesn't need to live in the kernel.

### 9.3 The bench runs to actually do

Before Sprint D commits to any specific primitive choice, run these on the current sequential prototype:

1. **Per-round wall time** on each of the existing benchmarks (n0/, sprint-F.6 retiming, gen-iter, pell). Anchors questions 1-2.
2. **Tag distribution** on the same benchmarks. Anchors question 3.
3. **False-sharing microbench** (one-off, ~50 LOC Zig). Anchors question 5.

These three measurements answer most of the open questions about which primitives matter at our actual scale. ~2 hours of work; could be done before any concurrency code is written.

---

## 10. Open research questions

Things still loose that this note doesn't settle:

1. **Per-domain merge function dispatch under multi-thread.** Today the kernel uses last-write-wins (i64 cells, deterministic fire-fns). When per-domain merge functions arrive (set-union, type-merge, capability-set-union, tropical-min), the cell-partitioned merge needs to look up the right merge function per cell. Function-pointer dispatch costs ~5ns per merge; comptime specialization (one merge loop per domain) eliminates it. Resolve when domain set is settled.

2. **EBR vs alternatives at our scale.** EBR is the right starting point because phase boundaries make its blocking pathology unreachable. But: at very deep nesting (ATMS depth 100+), the per-PU EBR state may itself become memory-heavy. Alternatives: hazard pointers (bounded but slower), [interval-based reclamation](https://www.cs.rochester.edu/~scott/papers/2018_PPoPP_IBR.pdf) (Wen et al. PPOPP 2018, hybrid), [HP-RCU / HP-BRCU](https://dl.acm.org/doi/10.1145/3626183.3659941) (SPAA 2024, expedited hazard pointers). Defer until depth measurements show EBR memory pressure.

3. **The deterministic-replay story.** TigerBeetle's deterministic simulation testing is the gold standard; we'd want the same for `.pnet` correctness verification. Multi-thread BSP makes determinism harder (work-stealing is non-deterministic). Two paths: (a) deterministic mode that pins workers and steal-orders; (b) accept non-determinism in production but have a deterministic single-threaded mode for verification. Option (b) is simpler. Resolve in concert with Track 10 (bootstrap verification).

4. **GPU as a concurrency target.** A BSP round is a kernel launch; per-cell merge is `atomicOr` / `atomicAdd` / segment-scan. The `prologos_pu_run` API is GPU-friendly. The substrate would be a GPU dialect on top of the same `.pnet` substrate. Real headroom (100-1000× for bit-parallel inner loops on H100-class GPUs), real engineering cost. Speculative; not on the immediate path.

5. **NUMA policy beyond the API.** The cell-allocation API gets a `numa_hint` early. Actually using it requires a static-analysis pass over the `.pnet` dataflow graph at lowering time. The pass exists in concept; design and implementation are open work. Defer until multi-socket deployment is on the immediate horizon.

6. **What does Sprint D's MVP look like?** Concretely: which subset of these primitives lands first? My instinct is **Chase-Lev deque + persistent worker pool with futex park + per-(worker, PU=root) write logs + cell-partitioned merge + sense-reversing barrier**. ~1500 LOC Zig. Defers EBR, NUMA, comptime per-tag batches, `pu_run_parallel`. Each of those becomes Sprint D+1, D+2, etc., gated on calibration measurement showing they pay.

7. **The relationship to PReduce / Track 9.** PReduce introduces tropical-quantale cost on cells, e-graph merges, equality saturation as the merge operation. The merge function becomes more expensive (not just last-write-wins). Cell-partitioned merge architecture is even more important under PReduce because per-cell merge work goes up. Calibration: re-measure post-PReduce.

8. **The relationship to Track 1 (`.pnet` network-as-value).** When `.pnet` round-trips propagator structure, the kernel learns to load propagators from `.pnet` data. The cell-id allocation, prop-id allocation, subscriber-list construction all happen at load time, deterministically from `.pnet` content. Multi-thread loading is possible but probably not worth it at small scale.

---

## 11. Summary: the recommendation in one paragraph

Sprint D should land a parallel BSP substrate on the existing single-threaded Zig kernel by composing five well-understood primitives — **Chase-Lev work-stealing deque** (~200 LOC Zig, ported from Lê et al. 2013), **sense-reversing barrier** (~50 LOC, ported from Mellor-Crummey 1991), **persistent worker pool with futex parking** via `std.Thread.Futex` (~150 LOC, original), **per-(worker, PU) write logs with cell-partitioned merge** (~400 LOC, original — the architecture that sidesteps lock-free atomic merge contention), and **cache-line-aligned `CellSlot`** (~20 LOC, original) — for an aggregate ~800 LOC of new Zig. **EBR** (~150 LOC ported), **comptime per-tag specialized fire batches** (~150 LOC original), and **`pu_run_parallel`** (~200 LOC original) follow as Sprint D+1/D+2 work, gated on measurement. The full concurrency substrate is ~3000-5000 LOC Zig, factoring as ~500 LOC ported algorithms, ~150 LOC FFI shims to mimalloc, ~1500 LOC Prologos-specific original design (concentrated in the `.pnet` / PU integration boundary), plus tests and integration. Benchmark peers are Soufflé, Differential Dataflow, Galois — measurement targets, not implementation choices. Engineering-discipline peer is TigerBeetle — adopt the determinism + Power-of-Ten posture even though their workload differs from ours. Three calibration measurements (per-round wall, tag distribution, false-sharing impact) on the current prototype answer most open questions about which primitives matter at our actual scale; ~2 hours of work, doable before any concurrency code lands.

---

## 12. References

### Algorithms
- Chase, D. & Lev, Y. (2005). "Dynamic Circular Work-Stealing Deque." *SPAA '05*. [PDF](https://www.dre.vanderbilt.edu/~schmidt/PDF/work-stealing-dequeue.pdf)
- Lê, N. M., Pop, A., Cohen, A., & Zappa Nardelli, F. (2013). "Correct and Efficient Work-Stealing for Weak Memory Models." *PPOPP '13*. [PDF](https://fzn.fr/readings/ppopp13.pdf)
- Mellor-Crummey, J. & Scott, M. L. (1991). "Algorithms for scalable synchronization on shared-memory multiprocessors." *TOCS 9(1)*.
- Brown, T. (2017). "Reclaiming Memory for Lock-Free Data Structures: There has to be a Better Way." [arXiv:1712.01044](https://arxiv.org/pdf/1712.01044)
- Wen, H., Izraelevitz, J., Cai, W., Beadle, H. A., & Scott, M. L. (2018). "Interval-Based Memory Reclamation." *PPOPP '18*. [PDF](https://www.cs.rochester.edu/~scott/papers/2018_PPoPP_IBR.pdf)
- Steindorfer, M. J. & Vinju, J. J. (2015). "Optimizing Hash-Array Mapped Tries for Fast and Lean Immutable JVM Collections." *OOPSLA '15* (CHAMP).
- Puente, J. P. B. (2017). "Persistence for the Masses: RRB-Vectors in a Systems Language." *ICFP 2017*. [PDF](https://public.sinusoid.es/misc/immer/immer-icfp17.pdf)

### Reference implementations
- [crossbeam-deque](https://github.com/crossbeam-rs/crossbeam) — Rust Chase-Lev deque (correctly handles Lê et al. integer-overflow bug)
- [ConcurrentDeque](https://github.com/ConorWilliams/ConcurrentDeque) — C++17 Chase-Lev
- [libqsbr](https://github.com/rmind/libqsbr) — C reference EBR + QSBR
- [microsoft/mimalloc](https://github.com/microsoft/mimalloc) — production allocator (FFI target)
- [arximboldi/immer](https://github.com/arximboldi/immer) — C++ persistent data structures (reference for prologos-hamt.zig)
- [wjakob/dset](https://github.com/wjakob/dset) — lock-free disjoint set (EQREL-style)

### Benchmark peers
- Soufflé Datalog. [Project](https://souffle-lang.github.io/), [PACT'19 EQREL paper](https://souffle-lang.github.io/pact19)
- Differential Dataflow. [GitHub](https://github.com/TimelyDataflow/differential-dataflow), [Materialize blog on memory management](https://materialize.com/blog/managing-memory-with-differential-dataflow/)
- Galois (UIUC). [Project page](https://iss.oden.utexas.edu/?p=projects/galois)
- Ligra (CMU). [GitHub](https://github.com/jshun/ligra)

### Engineering-discipline peers
- TigerBeetle. [Project](https://github.com/tigerbeetle/tigerbeetle), [Architecture](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/ARCHITECTURE.md)
- matklad, "Zig and Rust" (2023). [Post](https://matklad.github.io/2023/03/26/zig-and-rust.html)

### False sharing and cache architecture
- alic.dev, "Measuring the impact of false sharing." [Post](https://alic.dev/blog/false-sharing)
- riyaneel.github.io, "The Invisible Lock: Cache Coherency and the Physics of False Sharing." [Post](https://riyaneel.github.io/posts/cache-coherency/)

### Prologos prior research
- [SH Master Tracker](../tracking/2026-04-30_SH_MASTER.md)
- [Self-Hosting Path and Bootstrap Stages](2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md)
- [Propagator Network as Super-Optimizing Compiler](2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md)
- [BSP-Native Scheduler](../tracking/2026-05-01_BSP_NATIVE_SCHEDULER.md)
- [Kernel Pocket Universes design](../tracking/2026-05-02_KERNEL_POCKET_UNIVERSES.md)
- [Capability Safety as Datalog Hypergraphs](2026-04-23_CAPABILITY_SAFETY_DATALOG_HYPERGRAPHS.md)
