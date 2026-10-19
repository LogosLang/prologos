# PAR 4 · Stage 1 (R3) — Contention Analysis: where parallel propagator execution actually stalls, and what dissolves it

**Track**: PAR 4 — the row `2026-03-27_PAR_MASTER.md:33` opens as *"Contention analysis +
literature survey + design doc. Racket futures + STM/WAL/FFI. Write contention without constant
re-firing."* This document is **R3**, the contention analysis — a Stage-1 research record.
**Written at** `7a0116ec` (no source changes; measurement only). **Machine**: Apple M5 Max, 18
cores (6 "Super" + 12 "Performance"), Racket **9.3** CS / Chez 10.5.0 (first measured on 9.0; all
floors re-verified unchanged on 9.3). **Probes**: profile skill `racket-performance-probing/scripts/`
(re-runnable; names cited per finding). **Prior record this supersedes**:
`2026-04-10_BSP_LE_TRACK2B_DESIGN.md` §"Investigation Results" (lines ~1070–1129) and
`tracks/BSP-LE/BSP-LE_2B/handoffs/2026-04-16_BSP_LE_2B_HANDOFF.md` §3.9 "Racket parallelism ceiling (accepted)".

> Owner's framing that this record confirms with numbers: *parallel search is scheduler
> technology; per-core executors are children of the scheduler.* The one ingredient the
> framing needed is that **an executor owns memory**.

## 0. The result in one paragraph

The 2B record attributed the parallel ceiling to the ~8 µs OS wakeup and declared no Racket
mechanism could beat it. The wakeup is real for *scheduler-routed* signals (semaphore hop
7.3 µs, reproduced) but a raw shared-memory handoff between parallel threads is **~60 ns in
pure Racket 9** — 120× under the record, no FFI. Behind it is the real ceiling: **allocation
does not scale across Chez threads or places** (global mutex on allocation-area refill,
verified in `c/alloc.c`), and the real solver is **allocation-bound** — wall ≈ bytes ÷ 2.2 GB/s
on every path. Parallel speedup is a function of allocation *intensity*; the solver's ~2 KB/µs
caps it at ≤3×. The BSP fire protocol pays every written byte **twice** (fire on snapshot,
diff, re-merge) with bookkeeping that costs as much as both writes. An **arena executor** —
executor = (core, arena), fires as in-place lattice joins, owner-partitioned cells, direct
local writes under chaotic iteration — reaches the **same fixpoint at every K and in
asynchronous mode**, costs **95–131 ns / ~0 B per fire against 1 500 ns / 2.8 KB today**, and
at today's fire weight scales **7× at K=8, 13× at K=16**.

## 1. Signalling floor (`pingpong.rkt`, `fanout.rkt`, `spinpool.rkt`)

| mechanism, two `#:pool 'own` threads | ns / one-way hop |
|---|---|
| `semaphore-post` → `semaphore-wait` | **7 302** (= 2B's ~8 µs) |
| spin on `box` + `box-cas!` / `set-box!` + `memory-order-acquire/release` | 67–68 |
| same, orchestrator also a parallel thread | 58 |
| `box-cas!` + fence, same thread | 2.3 |

- Every mechanism in the 2B table (`sync`, `async-channel`, semaphores, `semaphore-try-wait?`
  polling — the "2 400 µs catastrophe") routes through rumble's scheduler. A box with fences
  is a cache-line transfer. **1–10 ns is not available cross-core in any language**: that is a
  same-core CAS; coherence bounds a cross-core hop at ~50–70 ns on this part.
- K-way dispatch + barrier, per-worker generation/done boxes, no shared counter: K=8
  **0.8 µs**/round (2B: ~80 µs). Workers spin **while a solve is active** (state-bounded) —
  2c's hybrid lost because its 10 µs count-bounded window was shorter than the merge phase.
- FFI crossing is **8 ns** (`ffi-futures.rkt`; `memset` on a `bytes` 19 ns) — cheap, but it
  buys nothing for the signal and a flat Racket kernel scales equally. `future`+`touch` is
  4.8 µs and shares the allocator ceiling.

## 2. Allocation ceiling (`alloc.rkt`, `scale.rkt`, `places.rkt`, `gctune.rkt`, `alloc-curve.rkt`)

Same total work, 8 threads vs sequential: pure fixnum compute **8.3×** (16 threads ~16×);
`unsafe-vector-set!` into per-thread vectors **8.0×**; 1 cons/64 iters 6.7×; cons-heavy
**~1.2×**; cons-heavy on 8 **places 0.8×**; cons-heavy with GC disabled
(`collect-trip-bytes` 1 GB → 0 ms GC) **~0.9×**. Large objects (`make-fxvector 1000`) are
*worse* in parallel than sequential (44 vs 17 ms).

**Mechanism (source-verified)**: Chez `c/alloc.c` — `S_get_more_room_help` and
`S_find_more_gc_room` take `alloc_mutex_acquire()` on every refill of a thread's allocation
area (segment granularity), plus `S_scan_dirty` and a possible collector queue. Places share
the collector and the mutex. No user-level knob (`bytes_per_segment`, `alloc_waste_maximum`
are compile-time); GC tuning is not the lever.

**The scaling law** (`intensity.rkt`, speedup vs K=1, same total work):

| bytes/µs per thread at K=1 | K=4 | K=8 | K=16 |
|---|---|---|---|
| ~1 050 | 3.1–4.2× | 3.1–3.7× | 2.8–3.0× |
| ~500 | 4.8× | 7.4× | 6.4× |
| ~180 | 4.2× | 7.6× | 11.8× |
| ~45 | 4.3× | 7.6× | 11.5× |

## 3. The solver is allocation-bound (`alloc-per-fire.rkt`)

| op (sequential) | bytes | ns | bytes/µs |
|---|---|---|---|
| one light BSP fire (N=8 / 64 per round) | 2 764 / 3 111 | 1 832 / 1 513 | 1.5–2.1 K |
| DFS 3-clause / 16-clause query | 7 129 / 35 067 | 2 952 / 14 874 | 2.4 K |
| ATMS 3-clause / 16-clause query | 58 494 / 192 172 | 27 666 / 90 098 | 2.1 K |
| `net-cell-write` (replacement merge) | 480 | 153 | 3.1 K |
| `net-cell-read` | 0 | 15 | — |
| `fork-prop-network` | 1 233 | 232 | 5.3 K |

**Wall ≈ bytes ÷ 2.2 GB/s on every row.** 2B's "DFS is 6–11× faster than ATMS" is explained:
ATMS allocates 8× the bytes. Sequential speed and parallel scaling are the same lever.

## 4. Census of one fire (`census.rkt`; `propagator.rkt:1880-2069`, `2855-2959`, `2966-3056`)

| piece | bytes | ns |
|---|---|---|
| `champ-insert` replace, N=16 / 256 / 4096 | 352 / 612 / 896 | 51 / 79 / 99 |
| `champ-lookup` (any N) | **64** | 36–55 |
| `struct-copy prop-cell` · `prop-network`+`warm`+`hot` | 64 · 96 | 4 · 10 |
| `net-cell-write`, 0 / 1 / 8 dependents | 481 / 529 / 801 | 183 / 202 / 286 |
| `net-cell-write`, no change | 0 | 56 |
| BSP per read-only fire (slope 8→64) | **1 386** | ~570 |
| BSP per read+write fire (slope 8→64) | **2 819** | ~1 500 |

A light read+write fire = **1.4 KB ceremony (50 %) + 0.5 KB the write (17 %) + 0.9 KB
re-merge (33 %)**. The protocol: fire on a snapshot → the fire returns a whole network (first
path copy + 3-struct spine) → `parameterize`×2, `for/hasheq` output-set, `champ-diff`,
`fire-result` → `bulk-merge-writes` → `net-cell-write` on the canonical **again**. Every
written byte is paid twice. Not waste in the code — the price of "network as persistent value
+ fires that return networks".

## 5. Arena executors (`arena-exec*.rkt`, `arena-tagged*.rkt`)

**Shape**: K spinning executors owned by the scheduler; each owns a partition of cells (P
logical partitions fixed, K executors own P/K each, so every K runs the identical fire set);
a cell is a fixed-stride flat record; a fire is an in-place lattice join; dirty lists are
bucketed by owner (no CAS, no contention); the join phase is the owner joining its buckets.
The REAL `tagged-cell-value` lattice (`decision-cell.rkt:397-500`) is expressed flat as
`[base, n, flag, (bm,v)×E]`: base ⊔ domain-merge, entries ∪ (insert-if-absent), read =
entries ⊆ worldview merged with base fallback.

**Semantics (the load-bearing result)**: fixpoint hash (per cell: base + sorted entries)
**identical for K ∈ {1,2,4,8,16}**, in BOTH modes — buffered (BSP: delta → barrier → owner
join) and **DIRECT** (the owner writes its own canonical records *during the fire phase*,
append-only: entry words → `memory-order-release` → count; readers count →
`memory-order-acquire` → entries). On a quiescence test (pure max lattice, 16 384 cells)
BSP converges in **15 rounds, DIRECT in 10**. This is chaotic iteration (Cousot 1977;
Bertsekas' asynchronous fixpoint): monotone + fair ⇒ the same least fixpoint. Caveat
recorded: DIRECT gives schedule-dependent *intermediate* states; BSP gives deterministic
ones. **Open question for R5**: does any ATMS/worldview logic depend on round-synchronous
visibility inside S0?

**Cost per fire, data-structure level** (same semantics, ~10 writes/cell): heap
`tagged-cell-value` + `make-tagged-merge`, delta-wrapped as `net-cell-write` does
(`propagator.rkt:2014-2019`): **172–178 ns, 187 B**. Arena buffered K=1: **117–131 ns, ~0 B**.
Arena DIRECT K=1: **95 ns** (the join phase disappears — a 2× *sequential* gain by itself).
Against today's full fire (§4): **12–16× time, >100× bytes**.

**Scaling vs fire weight** (DIRECT, quiescence, same fixpoint at every cell):

| compute per fire | K=1 ns/fire | K=4 | K=8 | K=16 |
|---|---|---|---|---|
| ~0 (3 reads + a max) | 24 | 2.4× | 2.2× | 2.9× |
| ~100 ns | 112 | 3.9× | 4.7× | 8.5× |
| ~1 µs (≈ today's fire) | 943 | 3.7× | **7.0×** | **12.8×** |
| ~9 µs | 8 900 | 3.9× | 7.2× | 13.4× |

At trivially light fires the ceiling is memory: per-executor cost rises with K on purely local
data (join 62 → 122 → 230 ns/cell at K=4/8/16; the cluster-shared L2 under all-core
streaming, ~430 B per joined cell at E=12) plus 2× straggler spread. Per-executor timings are
uniform across all 16 (no core-class effect at this scale). Three defects, each a design
lesson: a dense per-executor delta makes the join O(K·C) (→ dirty lists); random access to one
shared canonical bounces lines (→ partition for locality, as Pregel/GraphLab); K
consecutively-allocated `box` counters share a cache line (→ per-executor state is its own
object; padding alone took K=8 from 2.9× to 5.8×).

**K**: the number of executors; should be a scheduler cell, default ≈ cores − 2, never
oversubscribed (a descheduled spinner holds the barrier for an OS quantum).

## 6. What this answers in `PAR_MASTER.md` §Challenge 1

| research direction (R3 brief) | answer |
|---|---|
| STM for write contention | **Unnecessary.** Joins commute; owner-bucketed deltas (or direct owned writes) need no retry. "Write contention without constant re-firing" is the no-change short-circuit (`net-cell-write` no-change = 0 B) plus ownership. |
| WAL cells | **This is the delta arena**, measured: the dirty list IS the diff, the join IS the one write. |
| FFI (rayon / pthreads + lock-free CHAMP) | **Unnecessary for the signal** (8 ns crossing, but same hardware floor); a flat Racket kernel scales equally (8.0× mutation row) with no boundary. Viable later as a kernel substrate, not as a switch. |
| Hybrid STM + FFI | Moot given the above. |
| Premises "futures cannot mutate; threads are cooperative" | **Superseded** by Racket 9.0 parallel threads; the master needs a revision note. |

## 7. Candidate design (input to R5, conjecture until designed)

The scheduler owns K executors; executors own partitions — a cut of the propagator graph;
S0 fires write their own partition's records directly (chaotic iteration; no barrier inside
S0); cross-partition writes go through owner-bucketed deltas; **the barrier is the stratum
boundary** — S(−1) retraction and S1 NAF are precisely where round-synchronous visibility is
required, and `stratification.md` already puts them there. Phases collapse where everything
is monotone; the non-monotone boundary is where the barrier lives.

Open for R5: (1) the flat representation of a solver VALUE (interned term ids? the WAM
heap/stack/trail answer, propagator-native?); (2) fork/commit as partition-level
copy-on-write; (3) can the scheduler derive the partition from the propagator graph so
locality is structural; (4) the round-synchronous-visibility question above; (5) record
compaction (most cells carry ≤2 entries; E=12 is 216 B/cell → overflow side table).

## 8. Deferred candidates found on the way (not filed; owner's register)

1. ~~`champ-lookup` allocates 64 B per read — should be 0 (~10 % of a light fire's bytes).~~ **Withdrawn — see the correction below.**

> ⚠ **CORRECTION (2026-10-13, from DEFERRED 146 on branch `deferred-sweep-146-149`, `69f64caf`;
> [note §7a](../2026-10-13_PAR_4_P0_DOMAIN_MERGE_LAWS_NOTE.md))**: "`champ-lookup` allocates 64 B per
> read" is **wrong for production reads**. My probe looked up a *freshly constructed* `(cell-id k)` —
> `equal?` to the stored key but not `eq?` — so it measured Racket CS's `equal?` on two records
> (64 B per top-level call); the descent allocates 0 B. On `benchmarks/comparative`, 76 % of CHAMP
> data-entry comparisons and 95 % of lookups are `eq?` hits (0 B). The real `equal?` cost was on
> INSERT of a new key (now removed by comparing the stored hash first); all CHAMP `equal?` bytes are
> 0.04–0.25 % of a run's allocation. Reads are free; the write-side path copy (492–1 147 B per
> new-key insert) stands. The "~10 % of a light fire's bytes" share is withdrawn pending
> re-measurement with the corrected `census.rkt`.

2. `fire-and-collect-writes` builds a `for/hasheq` output-set per fire even for
   single-output propagators; two `champ-fold`s per slow-path write allocate closures.
3. **Latent quadratic**: `tagged-cell-write` conses and `tagged-cell-merge` appends — entries
   are never deduplicated, so a read is O(#writes ever made to the cell). Hidden today by
   query-scoped cells; the heap baseline at 100 rounds did not finish in 300 s.
4. `for … #:on-length-mismatch` (Racket 9.1) would have caught 2B handoff §4.6's zip bug.

## 9. Method notes (so the next probe doesn't relearn them)

Measure allocation with `(current-memory-use 'cumulative)`; parallel variants must do the same
total work; never busy-poll scheduler objects from the main thread; P must be divisible by K
or the fixpoint check fires (it did); a heap baseline must delta-wrap writes as
`net-cell-write` does or entry lists duplicate exponentially; convergence detection counts
canonical changes only; whole-suite wall is not a cross-version A/B on a loaded desktop.
