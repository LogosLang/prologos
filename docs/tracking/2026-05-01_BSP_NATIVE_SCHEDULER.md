# SH/BSP-Native — BSP Scheduler in the Native Runtime

**Status**: Sprint B+C landed (2026-05-01). Sprint D (multi-thread parallelism) deferred.
**Track**: SH-Series, sub-piece of Track 6 ("Concurrency: thread pool for BSP scheduler").
**Predecessor**: BSP-LE Track 2B (Racket-side; commit c5e0fe2).

## Summary

The Zig kernel (`runtime/prologos-runtime.zig`) now runs propagators under
proper bulk-synchronous parallel (BSP) discipline: snapshot → fire all
worklist members against the snapshot → merge writes → enqueue subscribers
of changed cells → repeat. Termination is guaranteed for monotone networks
and bounded for non-monotone ones via a fuel parameter.

A first-class instrumentation surface is exposed: per-round, per-fire,
per-tag, per-cell-write counters readable from C/LLVM via
`prologos_get_stat(key)` and printable as JSON via
`prologos_print_stats()`.

## Why BSP, why now

Prior to this change the kernel used a Jacobi-ish single-pass worklist:
`run_to_quiescence` iterated `worklist[0..len]` once and stopped. Reads
hit live `cells[]`; writes both committed AND scheduled subscribers
*during* the same fire. This is correct for **acyclic** networks with
exactly-once propagator firings (all SH programs through Sprint A). It is
**not** correct for cyclic networks — a self-loop would either explode
(every fire enqueues itself) or settle non-deterministically depending on
worklist ordering.

Sprint A introduced `select` and comparison primitives, which is the
prerequisite for conditional dataflow. The next step toward
iterative-without-unrolling (Sprint D) is feedback: a cell whose
next-round value is a function of its current-round value. BSP is the
discipline that makes feedback well-defined.

## BSP cycle structure

Each round:

1. **Worklist drain.** All pids enqueued during install or the prior
   round's merge phase are moved into `worklist[]`. `next_worklist[]`
   is cleared.
2. **Snapshot.** `cells[]` is copied verbatim into `snapshot[]`.
   All reads during this round will go through `snapshot`.
3. **Fire.** For each pid in `worklist`, `fire_against_snapshot(pid)`:
   - reads operands from `snapshot[]`
   - computes the fire-fn's result
   - appends `(out_cid, value)` to `pending_writes`
   - bumps `stat_fires_total` and `stat_fires_by_tag[tag]`
   - clears `in_worklist[pid]` so the same pid can be re-scheduled if
     a downstream change demands it
4. **Barrier.** `merge_pending_writes()` walks `pending_writes` and calls
   `prologos_cell_write(cid, value)`. That function commits the change
   to `cells[]` (if different from the current value) and enqueues
   `cell_subs[cid][*]` into `next_worklist`.
5. **Swap.** `worklist ← next_worklist`; if empty, terminate.

This is the same shape as Racket's `run-to-quiescence-bsp` in
propagator.rkt (lines 2330–2450), specialized for our flat-i64-cells +
fixed-shape-propagator world.

## CALM safety

Read-from-snapshot decouples reads from writes. All propagators in a
round see the same state. Their writes are commutatively merged at the
barrier (in our current case, last-write-wins per cell, which is fine
because all our fire-fns are deterministic functions of their inputs:
two propagators cannot legally write different values to the same cell
in the same round — that would be a contradiction).

This is the standard CALM-monotone story. Because cells are i64 and
merges are last-write-wins, the kernel **doesn't need a per-domain merge
function** today; one can be added later as a per-domain function pointer
in the propagator-decl table.

## Fuel and termination

`prologos_set_max_rounds(n)` bounds the BSP loop to `n` rounds. Default
is `DEFAULT_MAX_ROUNDS=100000`. When exhausted, the loop exits cleanly
(no abort), `stat_fuel_exhausted=1`, and the caller can still
`prologos_cell_read` whatever value has been computed. `n=0` means
unlimited.

Fuel is the kernel's escape valve for non-monotone cycles (e.g.
`x = x+1` would never terminate naturally). It also bounds runaway in
the presence of bugs.

## Instrumentation interface

Six exports:

```c
extern void     prologos_set_max_rounds(uint64_t n);
extern uint64_t prologos_get_stat(uint32_t key);
extern void     prologos_reset_stats(void);
extern void     prologos_print_stats(void);
```

Stat keys (currently exposed):

| key | meaning |
|----|----|
| 0   | `rounds` — completed BSP rounds |
| 1   | `fires_total` — propagator fires across all rounds |
| 2   | `writes_committed` — `cell_write` calls that changed cells[] |
| 3   | `writes_dropped` — `cell_write` calls that hit equal value |
| 4   | `max_worklist` — high-water mark of pending pids |
| 5   | `fuel_exhausted` — 0/1 |
| 6   | `num_cells` — allocated cells |
| 7   | `num_props` — installed propagators |
| 100..115 | `fires_by_tag[key-100]` — per-fire-fn-tag fire counts |

`prologos_print_stats()` emits a one-line JSON object to stderr without
linking printf (writes via `extern fn write(int, *u8, usize)`):

```
PNET-STATS: {"rounds":2,"fires":3,"committed":5,"dropped":3,"max_worklist":2,"fuel_out":0,"cells":5,"props":2,"by_tag":[1,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0]}
```

Future microbench harnesses (Sprint C "flamegraph-like data") can call
this between programs to attribute time / fire counts to specific
propagator tags.

## Lightweight thread / concurrency evaluation

The user's question: "this is where we need optimal concurrency machine
switching - lightweight threads (whats available in llvm/zig?)".

| Option | Stack | Switch cost | Status (2026-05-01) | Verdict for BSP |
|---|---|---|---|---|
| Zig `std.Thread` (pthreads on Linux) | ~80KB default | ~5μs | Mature in 0.13.0 | **Default for Sprint D worker pool** |
| Zig stackless `async` | frame size | ~50ns | **Broken in 0.13.0**; LLVM regression; slated for return | Not viable today |
| LLVM `@llvm.coro.*` intrinsics | stackless | ~100ns | Works but requires non-trivial state-machine lowering | Too much complexity for the tiny per-fire work |
| `ucontext` / libco / Boost.Context | configurable (8KB+) | ~200ns | Mature | Helps when tasks **block**; propagators don't block |

**Conclusion**: lightweight threads (fibers/coroutines/async) **are not
on the critical path** for our BSP scheduler. Their performance win is
on *blocking concurrency* (many tasks awaiting I/O). Propagator fires
are non-blocking, fixed-cost computations (10–100 ns each on i64
arithmetic). The bottleneck is the BSP barrier itself; reducing
context-switch latency below the barrier latency yields zero throughput.

For Sprint D (multi-thread BSP), the right design is a **worker pool of
OS threads via `std.Thread`** with:

- a sharded worklist (each thread pulls from its own deque or atomic
  index), with optional Chase-Lev work-stealing
- per-thread write log (each thread accumulates its `pending_writes`
  locally), merged sequentially at the barrier
- per-thread cell-id namespace for any cells allocated mid-round
  (analogous to BSP-LE Track 2B Phase 2b)

Crossover threshold to expect: per BSP-LE 2B benchmark data, Racket
crosses over at N≈128 propagators per round. The native kernel will
cross over much lower because per-fire work is similar (~50 ns) but
thread-fork overhead is similar too — meaningful parallelism likely
starts at N=32–64 propagators per round.

**For now** (Sprint B), the kernel is single-threaded. Existing programs
have ≤ 5 propagators per round; no worker pool would help.

## Validation

| Test | Outcome |
|---|---|
| All 13 `n1-arith/*.prologos` examples (existing acyclic + Sprint A new) | All pass with identical exit codes |
| New C smoke test (`runtime/test-bsp-stats.c`) | Validates depth-2 chain (2 rounds, 3 fires), select propagator dispatch, reset_stats, fuel-exhaust semantics |
| 18 `test-ast-to-low-pnet.rkt` cases + 22 `test-low-pnet-ir.rkt` + 12 `test-low-pnet-to-llvm.rkt` + 10 `test-network-to-low-pnet.rkt` | All pass |

CI step `BSP scheduler + instrumentation smoke test` added to
`.github/workflows/network-lower.yml`.

## Mantra audit

- **All-at-once**: each round fires all enqueued propagators against
  the same snapshot — no sequential dependence between fires within a
  round. ✓
- **All in parallel**: the round structure is parallelism-ready (Sprint
  D will dispatch fires across worker threads). The current single-thread
  loop is a degenerate-N=1 case of the parallel design. ✓ (architecturally)
- **Structurally emergent**: the round count is determined by network
  depth, not by any imperative ordering. select propagators "wait" for
  their cond cell to settle by virtue of the barrier, not by an explicit
  `if-cond-ready` check. ✓
- **Information flow**: every value transit is `cell_read → fire_fn →
  pending_write → cell_write → enqueue_subscribers`. No threading of
  values through return-types or parameters. ✓
- **ON-NETWORK**: the snapshot, worklist, pending_writes, and stats are
  all kernel-resident state addressed via i64 cell-ids and u32 prop-ids.
  Stats are exposed but not first-class cells *yet* — they're
  observation, not compilation input. (Future: stats could become
  cells in a meta-stratum.) Mostly ✓.

## Open follow-ups

- **Sprint D**: multi-thread worker pool (Zig `std.Thread` × N cores +
  per-thread write log + sequential merge).
- **Per-domain merge functions**: today every cell uses last-write-wins.
  Lattice cells (e.g. monotone-set, interval) would need a per-domain
  function pointer.
- **Topology stratum in the kernel**: the Racket scheduler has a
  topology stratum for mid-quiescence cell/prop allocation. The kernel
  doesn't yet — `cell_alloc` and `propagator_install_*` only run before
  `run_to_quiescence`. Mid-quiescence allocation is a Track 6 concern.
- **Stats as cells**: the longest-running propagator, the deepest cell,
  the per-tag fire histogram — all could be on-network meta-cells with
  monotone-merge semantics. Defer until we have a use case.
