# PAR 4 · P0 — Pre-0 measurements: small, medium and large tiers; A/B against the pre-track record

**Track**: PAR 4 — Arena Executors ([D.1](2026-10-12_PAR_4_D1_DESIGN.md) §9 Pre-0 plan; tracker row P0).
**Measured at** `7a0116ec` on branch **`par4-p0`** (nested worktree `.claude/worktrees/par4-p0`),
commit **`4097b1c8`** — instrumentation, harness, parity skeleton and all raw data. Main has since
moved to `f3d7f5e3` (driver/LSP/toolchain commits; none touch the measured files).
> **Where this lives now (2026-10-13).** PAR 4 work moved to its own track branch,
> **`par4-arena-executors`** (nested worktree `.claude/worktrees/par4-arena-executors`), created at
> `3643f56e` — `par4-p0` with main merged in twice by the sweep session (`a456c370`, `3643f56e`; merges,
> not rebases, so every hash cited here stays valid). `par4-p0` is kept as a frozen pointer.
> ⚠ **Build caveat** ([merge-laws note §7c](2026-10-13_PAR_4_P0_DOMAIN_MERGE_LAWS_NOTE.md), DEFERRED 159):
> main's tree ran an interpreted compiler from 10-12 20:24 to 10-13 02:55, and timings taken in
> `par4-p0` before 02:17 cannot be verified as limited-build after the fact. Counts in this record
> (rounds, fires, widths, writes, forks, routes) are unaffected; within-run A/Bs keep their direction.
> The timing rows a decision rests on are re-measured on a verified limited build in **§10**.
**Machine**: Apple M5 Max, 18 cores (6 S + 12 P), Racket 9.3 CS. **Ambient load** 4–9 throughout
(another session's suite and editor processes); timings are best-of-N or interleaved, counts are
deterministic. **Labels**: MEASUREMENT · MODEL (arithmetic over measurements) · CONJECTURE ·
CORRECTION.

> **Method note on scope.** The owner asked for measurements in the small and in the large, e2e,
> A/B against pre-track work, with an eye for surprises that theory would not predict. Three
> tiers were measured: **small** (primitive probes), **medium** (the real network/solver code on
> synthetic shapes — where the pre-track record lives), **large** (the language-level corpus
> through `process-file`, and the whole test suite under four schedulers). The large tier is
> where most surprises were — and two of them were defects in the *instruments*, which had to be
> fixed in method before any number could be trusted (§1.2).

## 0. Result

The theory held everywhere it was tested; the workload does not yet need most of the design;
and the largest available wins are **sequential defects in today's scheduler**, one of which
erased the pre-track parallel result.

1. **Theorems hold in the code we have** — MEASUREMENT. 40 random monotone networks with cycles
   reach **one fixpoint** under BSP, the sequential (DIRECT K=1) drain, four installation orders,
   and two random schedules; the arena prototype reaches the **same hash at every K** and every
   fire weight; every divergence the theory predicts (non-idempotent merge, absence read,
   anti-monotone pair, fire-counted fuel) **is observed** and pinned (§4.3).
2. **The pre-track record does not reproduce, and the cause is a default** — MEASUREMENT. PAR 2's
   1.42× on wide networks is 1.03× today; same-machine A/B shows HEAD **5.8× slower sequentially**
   on wide networks; `git bisect` → `a7b015dd` (2026-04-15) set `current-tree-reduce-threshold`
   to 256, which spawns ~n green threads per wide round on the sequential executor. Threshold off
   at HEAD: **4.8–5.3× faster**. DEFERRED **150** (§3).
3. ⚠ **CORRECTED in §10.2** — the 7 % below divides by a window that is ~80 % the instrument's own two
   forced major GCs (DEFERRED 152); excluding them, **S0 is 24–30 % of corpus work** and the corpus-wide
   H-S + K=8 model is 1.26–1.34×, not 1.06×. As first written:
   **In the large, S0 is a minority of work, concentrated in typing-heavy files** — MEASUREMENT.
   Of 1 253 ms of corpus work (prelude preloaded), BSP S0 rounds are **7.0 %**; but in
   `constraints-adversarial` the scheduler is **85 %** of command time and in `type-adversarial`
   38 %. Within S0 the **merge phase ≥ the fire phase** and `pu-value-diff` alone is 70 % of
   command time — the "paid twice" write cost from Stage 1, now seen in the large (§2.2).
4. **Search does not run on the network today, and cannot yet be made to** — MEASUREMENT. The
   `:auto` router sends the corpus's queries to DFS (e.g. 49 DFS / 3 ATMS / 1 Tier-1 in
   `atms-adversarial`); forcing ATMS returns **wrong answers on all three solver files**
   (`unknown`, empty answer sets) — the filed Rel T1 A.2b scaffolding (DEFERRED §"Rel T1 A.2b →
   BSP-LE Track 3"). **PAR 4's search payoff is gated on BSP-LE Track 3** — a dependency D.1 did
   not state (§2.4).
5. **End-to-end numbers mostly measured loading** — MEASUREMENT. A near-empty file costs 2.6 s in
   `process-file`, **92 % of it reading the `.pnet` cache twice**; with the cache disabled the
   same file elaborates in **0.53 s** (results identical). DEFERRED **151**; plus two forced major
   GCs per `process-file` (**152**) and counters blind to BSP fires (**154**) (§1.2).
6. **Several D.1 premises change** (§5): O-2's stated theorem was wrong (CORRECTION); forks are
   one per ATMS query but copy an *empty* template (Q2 resolved cheaply); the flat tier has
   **zero** dynamic writes on the corpus outside forced ATMS (A-13); cut locality is a non-issue
   (≤ 10 % foreign writes even round-robin); the sequential drain is **not** a valid DIRECT-K=1
   oracle — it has no stratum layer (§4.4).
7. **Q1 is not clean, and BSP is not an oracle for part of S0** (§9, added after the static
   audit landed). 3 live non-monotone sites, 8 absence-reading, 7 unstable latches — and **nine
   non-join merges written inside S0** (scope cells, worldview cell-1, tagged cells, the `:usage`
   and `:warnings` facets, the ready queue, fork requests, meta-solution output, type cells).
   Three of the audit's judgements are now measurements: BSP **loses updates today** when two
   propagators write a cell undeclared (DEFERRED 157); a fire-once installed inside a fire
   **loses fire-once** (158); and declaring the guard's output does **not** fix its lost
   retraction — the last-writer-wins lattice is the defect, and the grow-only invalidated-bits
   lattice fixes it under every schedule.

> **Added 2026-10-14 — §11 (O-9 evidence).** With DEFERRED 150's tree path off, the full suite passes, and
> the prelude caches are identical module by module. A merge-order census shows why the suite cannot tell
> the two apart: no round of 256+ fires carries an undeclared write. The same census measures item 7 in
> production: 2.0 % of the suite's multi-result rounds (5.8 % of the corpus's) end with different cell
> values when their results are applied in reverse order.

## 1. Method

### 1.1 Instruments (branch `par4-p0`, `4097b1c8`)

| instrument | what it measures | notes |
|---|---|---|
| `PROLOGOS_SCHEDULER=bsp\|seq\|seq-shuffle` (+`PROLOGOS_SCHED_SEED`) | runs ANY workload (incl. the whole suite) under BSP, the sequential Gauss–Seidel drain, or the drain with uniformly random pick order | read once at load (`propagator.rkt`); the solver's own re-parameterization now defers to it (`stratified-eval.rkt`) |
| `PROLOGOS_SOLVER_STRATEGY=atms\|depth-first\|auto` + route counter | forces a solve route; counts tier1/dfs/atms per run | seeds `current-solver-strategy-override` |
| fork counter | `fork-prop-network` calls | |
| `benchmarks/par4/p0-profile.rkt stats\|census\|profile` | per BSP round: width, fire-ms, merge-ms, writes · per outermost elaborator quiescence call: wall, bytes, fires · census of every write by merge-fn / value kind / tagged entries · dynamic cut locality · CC of the largest network · sampler profile (inclusive/self) | one file per process (`p0-sweep.sh`); `P0_PRELOAD` measures WORK, `P0_NO_PNET` the cold-cache workflow, `P0_REPEAT` more samples |
| `detect.rkt`, `arena-tagged4.rkt` | P0-4 detection schemes; P0-7 fire-weight sweep | |
| `bisect-demos.sh`, `cold-warm-parity.rkt`, `pnet-read-cost.rkt`, `suite-schedulers.sh` | pre-track bisect predicate; result parity cache-on/off and DFS/ATMS; `.pnet` read cost; suite × 4 schedulers | |
| `tests/test-arena-parity.rkt` | the D.1 parity skeleton (9 tests) | §4.3 |

Neutrality: with the knobs unset, `PERF-COUNTERS` are **identical** to pristine main on 5
comparative files (type-, constraints-, atms-, solve-adversarial, implicit-args).

### 1.2 Two instrument defects found first (they change how every number must be read)

| defect | measurement | consequence for method | filed |
|---|---|---|---|
| `process-file` start is dominated by the `.pnet` cache: `pnet-stale?` `read`s each whole file for a 2-element header, then the loader reads it again | 39 files / 15.7 MB; one full `read` of all = **1 207 ms** (9.0: 1 222 ms — not a 9.3 regression); near-empty file 2 590 ms with cache vs **526 ms** without; results identical modulo gensym numbering (4 files diffed) | e2e on short files ≈ 90 % loading; **WORK is measured with the prelude preloaded in-process** (`P0_PRELOAD`), which is what batch workers and the LSP see | DEFERRED 151 |
| `process-file` forces two major GCs (`measure-memory-before/-after`) | ≈ 45 ms and 33 % of samples per file regardless of work | PHASE-TIMINGS shares and bench-ab walls are inflated; command work is read from the profiler's `process-command` inclusive time | DEFERRED 152 |
| `prop_firings` counts only the sequential drain; `perf-inc-prop-alloc!` is never called | `solve-adversarial` under BSP: `cell_allocs` 4 079, `prop_firings` 0, `prop_allocs` 0 | the "prefer deterministic counters" rule (`testing.md`) cannot see the network; P0 counts come from round stats and the observer | DEFERRED 154 |
| `benchmarks/comparative/parity-adversarial.prologos` crashes at HEAD (uncaught DFS depth limit) | reproduced on pristine main | excluded from corpus aggregates (18 of 19 files) | DEFERRED 153 |
| `bench-parallel-demos.rkt` rewrites a tracked result file | it overwrote PAR 2's committed result in main (restored; both kept in `data/par4-p0/`) | medium-tier runs are done in throwaway worktrees and restored | DEFERRED 155 |

### 1.3 Baselines

- **B-pretrack** = PAR 2's code `ce4cde52` (2026-03-28) — the pre-track record, re-run on this
  machine (§3).
- **B0** = `7a0116ec` as is. **B0′** = `7a0116ec` with `current-tree-reduce-threshold` = `#f`.
  Every PAR 4 phase must be A/B'd against **B0′** (or against main after DEFERRED 150 lands) —
  otherwise PAR 4 is credited with removing a defect it did not cause (§6).
- **Superseded 2026-10-13** (§10): main now carries the sweep's sequential fixes on the measured path
  (146 `champ.rkt`, 147 the fire protocol — light fire 1 386 → 928 B, 148 `decision-cell.rkt`, F3(a)
  `type-lattice.rkt`). The baseline pair for P2 is therefore **B1** = `3643f56e` (branch start, all of
  those) and **B1′** = B1 with the tree-reduce threshold `#f`; `fbd5a322` remains the as-is record.

## 2. Large tier — the language-level corpus

### 2.1 Where end-to-end time goes

| near-empty prelude-importing file | wall | dominated by |
|---|---|---|
| cache on (default) | 2 590 ms | `deserialize-module-state` 46 %, `pnet-stale?` 45 % |
| cache off (elaborate 39 modules from source) | 526 ms | `pos->line-col` 23 %, `handle-foreign-decl` 7 %, forced GC 10 % |
| `:no-prelude` files (church-folds, records-typing) | 38–44 ms | — |

### 2.2 Work-only Amdahl (prelude preloaded; BSP; 18 files) — `data/par4-p0/comparative-stats-bsp.jsonl`

⚠ *Corrected in §10.2: the forced GC is ~56 ms per file, 1 005 of the 1 253 ms; against work without it
S0 is 24–30 %.* Totals: work 1 253 ms (incl. ~45 ms forced GC per file), **S0 rounds 87.6 ms = 7.0 %**
(fire 60.2, merge 27.4); 682 rounds, 2 879 fires; elaborator quiescence calls 181, of which 162
fire nothing. Per file, only three exceed 3 %:

| file | S0 / work | rounds | width p50 / p90 / max | µs per fire | merge per round |
|---|---|---|---|---|---|
| constraints-adversarial | 42.1 / 123 ms (34 %) | 212 | 3 / 14 / 38 | 23.0 | 74.7 µs |
| type-adversarial | 35.4 / 121 ms (29 %) | 182 | 3 / 12 / 84 | 22.1 | 59.6 µs |
| implicit-args | 3.8 / 62.5 ms (6 %) | 29 | 3 / 14 / 21 | 24.0 | 8.1 µs |
| all other 15 | ≤ 3 % | | | | |

Round-width histogram over the corpus (rounds / fire-ms): width 1: 241 / 0.6 · 2–3: 247 / 10.5 ·
4–7: 106 / 7.4 · 8–15: 48 / 17.2 · 16–63: 39 / 23.8 · ≥ 64: 1 / 0.7. **Two thirds of fire time is
in rounds of width ≥ 8**, but 72 % of rounds have width ≤ 3.

Against **command time** (profiler, 10 repetitions, `data/par4-p0/scratch/prof10-*.json`):

| file | command / run | `run-to-quiescence-bsp` | `bulk-merge-writes` | `fire-and-collect-writes` | `pu-value-diff` |
|---|---|---|---|---|---|
| constraints-adversarial | 46.5 ms | **85 %** | 41 % | 34 % | **70 %** |
| type-adversarial | 45.4 ms | 38 % | 21 % | 11 % | 24 % |
| atms-adversarial | 25.6 ms | ~0 | 0 | 0 | 0 |

`pu-value-diff` (component diff under `net-cell-write/slow-path`, deciding which dependents of an
attribute map to wake) runs in the fire **and again** in `bulk-merge-writes`: the census's
"every written byte is paid twice", in the large. ⚠ Open discrepancy: `type-adversarial`'s
single-run round stats (35 ms S0) are twice its 10-rep profile mean (17 ms) — warm state after the
first repetition; single-run figures are upper bounds.

**Models** (MODEL; fire time assumed to divide by min(width, K) — an upper bound, since these
fires allocate at 750–810 B/µs and the Stage-1 intensity law caps allocation-heavy scaling):

| file | H-S sequential only (merge phase removed) | today's BSP, K=8 | H-S + K=8 | H-S + K=16 | S0 free |
|---|---|---|---|---|---|
| constraints-adversarial | **1.52×** | 1.76× | 4.43× | 4.75× | 10.5× |
| type-adversarial | **1.31×** | 1.77× | 3.07× | 3.26× | 4.5× |
| bool-logic, atms-adversarial | ≈ 1.0× | ≤ 1.11× | ≤ 1.13× | | ≤ 1.15× |

### 2.3 Dynamic census, cut locality, network size (A-13, A-8, Q4) — `comparative-census-bsp.jsonl`

| | corpus (auto routing) | `atms-adversarial`, forced ATMS |
|---|---|---|
| value writes observed | 651 | 204 |
| by merge | `attribute-map-merge-fn` **78.6 %**, `meta-solution-merge` 15.5 %, `merge-set-union` 2.9 %, `resolution-stratum-merge` 2.9 % | tagged-cell merge **58 %**, `table-answer-merge` 36 %, `viability-merge` 6 % |
| value kinds | hash 79 %, list 18 %, custom-set 3 % | tagged 58 % |
| tagged entries per write | — (none) | 0: 32 · 1: 83 · 2: 3 |
| foreign writes, K=8 round-robin | **9.9 %** of fires; foreign in-edges 10.6 % (block-64: 3.5 %) | 0 % of fires; in-edges 37.5 % RR / 0 % block-64 |
| outs / ins per fire | 1.10 / 0.99 | 1.24 / — |
| largest network observed | 167 cells (one hub cell, degree 154) | 205 cells, 105 propagators |
| forks | 6 (in the whole corpus) | **55 for 52 queries** |

### 2.4 Search: routing, DFS vs ATMS, and correctness

| file | routes (auto) | DFS work | forced-ATMS work | forced-ATMS answers |
|---|---|---|---|---|
| solve-adversarial | dfs 20, tier1 15 | 77.0 ms | 77.5 ms | **wrong**: `:sum unknown`, `:v2 unknown` |
| atms-adversarial | dfs 49, atms 3, tier1 1 | 82.5 ms | 95.9 ms (+16 %; 10 ms S0, 55 forks) | **wrong**: `:result unknown` (DFS 42) |
| solve-scale | dfs 1, atms 2, tier1 3 | 71.0 ms | 70.5 ms | **wrong**: empty answer set (DFS 16 rows) |

The ATMS timings compare a complete search with an incomplete one: **lower bounds** on ATMS cost,
not an A/B. Queries are 0.1–0.25 ms each; no language-level workload in the repo runs large
search on the network (the two Sudoku demos keep their solvers commented out —
`examples/sudoku-solver-demo.prologos` header).

### 2.5 The whole suite under four schedulers (A-1/A-3 in the large) — `data/par4-p0/suite/`

| scheduler | result |
|---|---|
| BSP (branch, knobs unset) | **10 255 tests, 489 files, all pass**, 108 s |
| seq (sequential drain) | 27 files fail |
| seq-shuffle, seed 1 | 28 files fail (the 27 + `test-propagator-descending-01`) |
| seq-shuffle, seed 2 | 30 files fail (+ `test-readiness-propagator`, + this track's parity file — §4.3) |

Classified from the failure logs (no reruns, per `workflow.md`):

| class | files | meaning |
|---|---|---|
| **no stratum layer**: trait resolution `E1004 no instance found` (~19), S(−1) retraction, fork-on-union, S1 NAF, HasMethod | ~25 | the sequential drain (`propagator.rkt:2713-2765`) runs S0 only; strata live in BSP's outer loop (`:3443-3500`). Not S0 schedule dependence. Note: `:execution :sequential` in a solver config routes ATMS through this drain (`stratified-eval.rkt:291`) |
| **BSP-only features**: fire-once self-clearing | 2 | `PROP-FIRE-ONCE` is implemented in BSP's merge (Phase 5a) only |
| **genuine schedule dependence** | 2 | `test-propagator-descending-01` *gauss-seidel-mixed-convergence*: an anti-monotone asc→desc pair, designed and labelled "order-dependent" (A-1 class); `test-readiness-propagator:364`: readiness → ready-queue under **`merge-list-append`** appends twice under a random order (queue length 2 ≠ 1) — A-2 observed in the test's model of a production pattern (PM Track 7 Phase 8), hidden by BSP's per-round dedup. The test builds its own `merge-list-append` cell; production's analogue is cell-14 (`resolution-stratum-merge` = append), written by the fire-once latch `metavar-store.rkt:562` (§9.4) |

## 3. Medium tier — the pre-track record, re-measured

`bench-parallel-demos.rkt` (byte-identical at both commits), same machine, Racket 9.3,
interleaved ×2 (`data/par4-p0/parallel-demos-*.json`):

| network | PAR 2 recorded (old machine) | PAR 2 code `ce4cde52` here | HEAD here | HEAD, threshold `#f` |
|---|---|---|---|---|
| graph colouring 500 (3 000 props), seq | 2.83 ms (1.42×) | 1.55 / 1.65 ms (1.11–1.19×) | 9.51 / 8.98 ms (0.99–1.02×) | **1.98 / 1.96 ms** (1.05–1.17×) |
| constraint grid 12 (3 168), seq | 3.05 ms (1.42×) | 1.83 / 1.66 (1.14–1.28×) | 9.98 / 9.96 (0.95–0.98×) | **2.02 / 2.04** (1.19–1.24×) |
| wave chain 1 000 (999), seq | 73.4 ms | 36.9 / 37.2 | 4.53 / 4.91 | **2.53 / 2.54** |

`git bisect` (11 steps, bimodal 1.7 / 9.1 ms, predicate `bisect-demos.sh`) → **`a7b015dd`
(2026-04-15) "Phase 2c: semaphore-based worker pool"**: `current-tree-reduce-threshold` `#f` → 256
(tuned with the pool attached). `propagator.rkt:3397-3398` calls `tree-reduce-fire-results … #t`
regardless of executor; `:3149-3152` spawns a green `thread` + `channel` per pair per tree level.
The chain pays it once: its first round fires all 999 initially-scheduled propagators. Corpus
rounds never reach 256 (max 84), so §2.2 is unaffected; the cold-cache prelude elaboration has
rounds of 216–368 and is. Same class of defect as BSP-LE 2B's spin-poll: scheduler-routed
concurrency on the hot path. Separately, chains got 7–15× faster since PAR 2 — the sequential
network improved substantially for narrow shapes.

## 4. Small tier — primitives and semantics

### 4.1 Quiescence detection (P0-4, `detect.rkt`, best of 5, consumed count asserted equal)

| ns/message | K=4 | K=8 | K=16 |
|---|---|---|---|
| CHAIN (one message alive) — BSP rounds | 687 | 2 600 | 5 858 |
| CHAIN — **scan** (padded per-executor counters, double scan) | 198 | 336 | 485 |
| CHAIN — atomic (one shared counter) | 173 | 360 | 512 |
| BURST (5 461 msgs, fan 4) — rounds | 24 | 47 | 92 |
| BURST — **scan** | 28 | 54 | 80 |
| BURST — atomic | 55 | 99 | 167 |

Rounds cost ≈ 0.29 µs × K per round (three barriers) and dominate dependency chains (3.5–12×);
on wide bursts scan ≈ rounds and the shared counter loses ~2× to contention. D.1 §5.4's scheme is
confirmed. (Burst wall includes per-trial thread creation; the probe's first barrier had a
double-flip race — fixed, recorded in the source.)

### 4.2 Fire-weight sweep (P0-7, `arena-tagged4.rkt`, DIRECT + CONVERGE, real tagged lattice)

| work per fire (K=1) | K=2 | K=4 | K=8 | K=16 |
|---|---|---|---|---|
| 28 ns | 1.97× | 1.88× | 1.97× | 1.62× |
| 118 ns | 2.06× | 4.04× | 5.94× | 3.88× |
| 959 ns | 1.96× | 3.94× | **7.30×** | **11.4×** |
| 9.4 µs | 1.92× | 4.03× | **7.70×** | **13.6×** |

Same fixpoint hash (1991507968) at every K and weight. Production elaboration fires are 20–27 µs
(§2.2) but allocating; the sweep's work is pure fixnum — these are ceilings for the parallel half.

### 4.3 Parity skeleton (`tests/test-arena-parity.rkt`, 9 tests; passes under bsp, seq, shuffle 2, 3)

Live rows (must agree): S-1 diamond with stale reads; **40 random monotone max-networks with
cycles × {BSP, DIRECT1} × 4 installation orders → one fixpoint each** (and under both random
drains); set-union fan-in cycle; S-7 contradiction absorbing. Divergence rows (must differ, run
under two EXPLICIT Gauss–Seidel orders so they are environment-independent): `+` accumulator
(A-2); readiness → `merge-list-append` queue (A-2; the test's model of cell-14, §9.4); absence read (A-1/A-3);
anti-monotone asc/desc pair (A-1); S-6 fuel charged **1 (BSP) vs 17 (DIRECT1)** for the same
16-way fan-in fixpoint. Pending: arena K ∈ {1,4,8,16} (`PAR4_ARENA=1`, P3).
Two design errors in the skeleton itself were caught by running it: the first `+` example was a
chain (every schedule fires the join equally often — it did not exercise the hypothesis), and the
first divergence rows used the environment's drain, so seed 2 happened to make them agree.

### 4.4 The sequential drain is not the DIRECT-K=1 oracle

D.1 treated `run-to-quiescence-inner` as "DIRECT at K=1". For S0 it is; but it has **no stratum
layer** and no fire-once semantics (§2.5), so a whole-suite DIRECT run through it measures
missing strata, not schedule dependence. The oracle for P3 parity in the large must be **BSP's
outer loop with a DIRECT S0 inside it** — which is exactly P2's K=1 executor. Its first test is
the full suite at K=1.

## 5. What this does to D.1 (inputs for D.2)

| D.1 item | P0 says | change |
|---|---|---|
| §14 O-2: "the number of strict ascents … is a property of the chain … THEOREM for a fixed ownership" | **wrong**: the S-6 row reaches one fixpoint with 1 ascent (BSP sees all 16 sources at once) or up to 16 (drain, ascending order) | CORRECTION: what is schedule-independent is the **bound** — changes ≤ Σ cell heights under every schedule. Change-counted fuel stays the cleaner choice for that reason: with budget ≥ Σ heights it cannot exhaust on a finite-height network under any schedule; fire counts have no such bound |
| Q2 fork = copy cost | forks ≈ 1 per ATMS query, but of `get-or-create-solver-template` = `(make-prop-network fuel)` — an **empty** network (`relations.rkt:3071-3075`) | copy ~20 well-known records per fork; no COW needed for search forks |
| A-13 tier eligibility | dynamic writes: attribute maps (hash) 79 %, meta solutions 16 %; flat-eligible kinds ≈ 0 outside forced ATMS; under ATMS tagged = 58 % with ≤ 2 entries | **H-F has no current workload**; defer it until on-network search is complete (BSP-LE 3); when it lands, E = 4 covers the measured distribution |
| Q4 / A-8 partition | ≤ 10 % foreign writes even round-robin; networks ≤ 205 cells | round-robin (or block-64) is adequate; no partitioner needed in P2 |
| A-1/A-3 audit scope | ⚠ CORRECTION: **144** production call sites + 13 wrapper callers = 157 (my "130" was a space-delimited grep that missed end-of-line calls; withdrawn). Dynamically schedule-dependent: the asc/desc pair (1 production `net-new-cell-desc` site, `bilattice.rkt:102`) and append queues | static audit landed — synthesis in **§9**; Q1 not clean; nine S0 non-join merges; decision for D.2 in §9.6 |
| ordering of the halves | H-S's sequential gain (1.31–1.52× on the heavy files) is comparable to the modelled parallel gain at today's widths; merge ≥ fire | **land the H-S sequential path first (DIRECT K=1 inside BSP's outer loop)**, measure, then K > 1 |
| value proposition | e2e, today's corpus: ~~S0 7 % of work; ≤ 1.2× e2e at K=8 except two files~~ **corrected §10.2: S0 24–30 % of work without the instrument's GC; corpus H-S + K=8 1.26–1.34×; the two heavy files 3.3–4.1×**; search is DFS by necessity | PAR 4's parallel payoff is for workloads **not yet on the network** — say so in D.2, and couple its search claims to BSP-LE 3 |

## 6. Phase gates — what each phase is measured against

Baseline for every row: **B0′** (= `7a0116ec` + tree-reduce threshold `#f`, or main once
DEFERRED 150 lands), worktree-pinned, interleaved. Counters come from the P0 harness until
DEFERRED 154 fixes `PERF-COUNTERS`.

| phase | assumption it tests | measured against (P0 artifact) | method | pass |
|---|---|---|---|---|
| **P0.5 (before P1)** | — | — | acceptance file `examples/2026-10-1x-par4-arena.prologos` (`workflow.md` "Acceptance file as Phase 0"); DEFERRED 150 decision; B0′ pinned | file runs 0 errors; B0′ numbers recorded |
| P1 executor pool, K as a cell | idle cost; K=1 ≡ today | suite (§2.5 BSP row); `detect.rkt` | full suite; idle CPU while parked | suite green; parked executors 0 % CPU |
| P2 ownership + DIRECT S0 at K=1 inside BSP's outer loop | A-1/A-3 in the large; H-S sequential gain | §2.5 classes; §2.2 command times; parity skeleton | **full suite under P2 K=1** (the real DIRECT oracle, §4.4); `p0-profile stats/profile` on constraints-/type-adversarial | suite green, every K=1 divergence from BSP triaged against the §9.4 sites (deterministic at K=1, so any difference is an order-dependence there or a missing layer); constraints-adversarial command time ≥ 1.4× faster (model 1.52×); merge phase gone; DEFERRED 158 fixed first |
| P3 detection + frozen bit, K>1 | T5–T8 at K>1 — which need A-2 on every S0-written cell (§9.4); detection cost | parity skeleton arena rows; `detect.rkt` scan row; fire-weight sweep | `PAR4_ARENA=1`; suite at K ∈ {4,8,16} × 2 seeds; detection latency | §9.4 merges are joins (or confined, per the §9.6 decision); DEFERRED 157 fixed; each fixed lattice moves its divergence row to a parity row; parity green at every K; suite green; detection ≤ scan row × 1.5 |
| P4 flat tier | A-13; E sizing | §2.3 census (forced ATMS) | only after BSP-LE 3 makes on-network search complete | tagged per-fire ≥ 10× vs heap (Stage 1: 12–16×) on the ATMS census workload |
| P5 fork / `.pnet` | Q2 | §2.3 forks; §1.2 `.pnet` cost | fork cost per query; `.pnet` round-trip | fork ≤ 1 µs; round-trip equal |
| P6 retire scaffolding | — | — | grep | zero references |
| P4.close | all | this document's tables, re-run | bench matrix per semantic axis, e2e corpus (work-only and full), medium-tier demos | PIR |

## 7. Not measured, and why

- **e2e search at scale**: no language-level workload exists that is both on-network and correct
  (§2.4). Owed: a search acceptance file (red until BSP-LE 3).
- **K > 1 on real network code**: needs P2/P3. The medium tier's parallel column uses today's
  executors only.
- **Allocation-bounded scaling of real elaboration fires** (A-12): bytes/µs measured per file
  (750–810 on the heavy files) but not per fire under K > 1.
- `bench-track2b-solver.rkt` was not re-run: its per-query ATMS numbers measure the incomplete
  path (§2.4) and would not decide anything until BSP-LE 3.
- Apple-specific core-to-core latency from an independent source (Stage 1 §6) — still ours only.

## 8. Reproduce

> **After owner decision O-10 (CP-2, `a0b78fda`, 2026-10-14)** the knobs this section uses (`PROLOGOS_SCHEDULER`,
> `PROLOGOS_SOLVER_STRATEGY`'s env seeding, `PAR4_TRAP_MIDRUN`) exist only up to `931b327b`. Run these commands at
> the pinned commit below, as written. On later trees, `suite-schedulers.sh` and `p0-sweep.sh` refuse (exit 2)
> rather than silently measuring BSP.

```
cd .claude/worktrees/par4-p0/racket/prologos           # branch par4-p0 @ 4097b1c8
export P0_PRELOAD=$PWD/benchmarks/par4/preload-empty.prologos
benchmarks/par4/p0-sweep.sh stats   out.jsonl          # also: profile | census
PROLOGOS_SOLVER_STRATEGY=atms benchmarks/par4/p0-sweep.sh stats atms.jsonl FILES…
benchmarks/par4/suite-schedulers.sh OUTDIR             # 4 full suites, sequential
racket benchmarks/par4/detect.rkt 4 8 16
CONVERGE=1 DIRECT=1 WORK=700 racket benchmarks/par4/arena-tagged4.rkt
raco test tests/test-arena-parity.rkt                  # under any PROLOGOS_SCHEDULER
racket benchmarks/par4/q1-mechanisms.rkt               # §9.3: lost update, guard lattice, fire-once re-install
git bisect run benchmarks/par4/bisect-demos.sh         # in a throwaway detached worktree
```

## 9. Q1 — static monotonicity audit: synthesis of record (added 2026-10-13, after the draft landed)

**Provenance.** A delegated static audit — [`2026-10-13_PAR_4_P0_Q1_MONOTONICITY_AUDIT_DRAFT.md`](2026-10-13_PAR_4_P0_Q1_MONOTONICITY_AUDIT_DRAFT.md),
651 lines, pinned to `7a0116ec` — read in full. Nine of its claims were checked against the code
and **all hold**: undeclared writes are direct-set (`propagator.rkt:3018-3045`); in-fire installs
re-installed from `(inputs outputs fire-fn)` (`:3060-3066`, `:3376`); the guard's outputs are
`'()` and it AND-NOTs cell-1 (`relations.rkt:2331-2353`); the retry bridge `set-box!`es the ambient
elab-network box inside its fire (`resolution.rkt:371-387`); `scope-cell-merge` "new wins"
(`decision-cell.rkt:887-904`); `worldview-cache-merge` is replacement (`propagator.rkt:960`);
the `:usage` facet merges by `add-usage` (`typing-propagators.rkt:416`) and the arity ≥ 3 fold
re-fires (`:1786-1797`); `type-unify-or-top`'s fallback is non-commutative
(`type-lattice.rkt:203-219`); the D.1 lines it cites exist. Three of its judgements were turned
into measurements (§9.3). The draft stays a DRAFT; this section is the record.

### 9.1 Census — MEASUREMENT (and a CORRECTION of mine)

144 production call sites: `net-add-propagator` 108, `net-add-fire-once-propagator` 30,
`net-add-broadcast-propagator` 1, `net-add-cross-domain-propagator` 5; plus 13 callers of five
wrappers (`elab-add-*`, `rt-add-propagator`, `module-network-install-fire-once`) = **157 audited**.
My §5 figure of 130 came from a space-delimited grep that misses calls ending a line (101 vs 108
for the first API) — withdrawn. D.1's 103 counted one API.

### 9.2 Verdicts — JUDGEMENT (the draft's, accepted after the spot-checks)

| class | sites | of which dead (no production caller) |
|---|---|---|
| monotone by construction | 14 | 0 |
| monotone, one-line argument (29 also emit set-union topology requests — a join) | 87 | 9 |
| threshold/latch, stable (output constant above the trigger) | 17 | 0 |
| threshold/latch, **unstable** (latches the first value; input can still grow) | **7** | 0 |
| **absence-reading** | **8** | 0 |
| **non-monotone** | **4** | 1 (`session-runtime.rkt:517`, IO in a fire) |
| topology-only / unclear / wrapper | 1 / 6 / 13 | 1 / 0 / 4 |

Live non-monotone: the constraint-retry bridge `metavar-store.rkt:1063` → `resolution.rkt:371-387`
(ambient box mutated in the fire, status cycles postponed → retrying → postponed, nested quiescence,
undeclared constraint-store write); the guard `relations.rkt:2353`; the arity ≥ 3 usage fold
`typing-propagators.rkt:1789` (re-fires into an additive merge). Absence-reading:
`relations.rkt:2132` (var = var unify copies only into an unbound side), `:2859` (tabling
producer records partial tuples), `typing-propagators.rkt:2642` (unsolved multiplicity read as ω,
`:1699`), `:2605`, `:1299`, `:2586` (own-output guards; the last is benign under intersection),
`metavar-store.rkt:692, 850` (trait / hasmethod bridges choose on a meta-containing type and the
own-output guard prevents re-choice). Unstable latches: `typing-propagators.rkt:1768, 1778, 2665,
2686, 2781, 2854, 2882`. The draft's §8 orders these as schedule-variation targets.

### 9.3 Three mechanisms, measured — `benchmarks/par4/q1-mechanisms.rkt` → `data/par4-p0/q1-mechanisms.txt`

| probe | BSP | sequential | correct | reading |
|---|---|---|---|---|
| M3: two writers, same round, ior cell, **undeclared** outputs | **2** | 6 | 6 | lost update under BSP — today |
| M3: same, outputs **declared** | 6 | 6 | 6 | declaring fixes it *for a join* |
| G: guard shape — clear own bit of worldview `0b110`, LWW cell, undeclared (as `relations.rkt:2353`) | **4** | 0 | 0 | one failed guard's bit survives |
| G: same, outputs **declared** (the draft's follow-up #1) | **4** | 0 | 0 | **not fixed** — replacement is not a join |
| G′: retraction as growth — *invalidated* bits, ior merge; worldview = committed ∧ ¬invalidated | 6 | 6 | 6 | fixed under both schedules |
| M4: fire-once installed at top level, T raised 1 → 2 → 3 | 2 fires, C = 1 | 4 fires, C = 3 | 1 productive fire, C = 1 | BSP honours fire-once; the drain has none (§2.5) |
| M4: the same propagator installed **inside a fire** | **4 fires, C = 3** | 8 fires, C = 3, **2 installs** | as above | flags lost on re-install; the drain's worklist does not deduplicate, so an inline installer runs twice |

Filed: **DEFERRED 157** (M3 + the guard's lattice), **158** (M4 + the duplicate install). The
lesson worth keeping: a static audit's proposed fix is itself a claim — "declare the outputs"
was necessary and not sufficient; the measurement located the defect in the lattice.

### 9.4 The finding that changes the design: S0 writes non-join merges, so BSP is not an oracle there

The asynchronous-iteration theorem (Üresin–Dubois 1990; Bertsekas 1983 — [Stage 1 synthesis](research/2026-10-12_PAR_4_STAGE1_RESEARCH_SYNTHESIS.md) §1, T5–T8)
needs monotone fires **and joins** for every cell written during the iteration. These are written
inside S0 and are not joins:

| cell | merge today | S0 writers | the join that would replace it | status |
|---|---|---|---|---|
| worldview cell-1 | replacement; narrowed by AND-NOT | projection `propagator.rkt:983`; guard `relations.rkt:2353` (undeclared) | committed bits (ior) and invalidated bits (ior); worldview a derived read | **measured** (G′); DEFERRED 157 |
| scope cells (logic variables) | per key, "new wins" | 8 relational sites (`relations.rkt:796, 2132, 2148, 2161, 2183, 2636, 2699, 2824`) | per-key flat lattice, conflict ⇒ ⊤ (contradiction) | CONJECTURE that no program relies on overwrite — the P2 K=1 suite run tests it |
| tagged (promoted) cells | entries appended, never deduplicated; the read folds the domain merge in arrival order | every worldview-wrapped fire | dedup (DEFERRED 148) + a join domain merge ⇒ order-independent read | follows from the two rows above |
| attribute map `:usage` facet | `add-usage` — the semiring's + | `typing-propagators.rkt:1789, 2642` | Two orders are conflated: + combines *children* inside a fire; successive *writes* need the information order (an unsolved multiplicity is unknown, not ω — `:1699` reads it as ω). Which order: D.2 decision (`qtt.rkt`'s `join-usage` is the alternation combinator, not obviously it) | open |
| `:warnings` facet; meta-solution output | append | `:2913`; `:2546` | set, with presentation order fixed at the boundary | small |
| ready queue cell-14 | append — "order may carry intent (e.g. trait-dispatch before usage-finalization)" (`propagator.rkt:802-808`) | `metavar-store.rkt:562` | set of (priority, aid, action); the handler sorts — intent made explicit, not arrival order | small |
| fork-on-union requests cell-15 | per key, last writer wins | every `type-map-write` (`typing-propagators.rkt:622-634`) | per-key join in the union-refinement order | small |
| type cells | `type-unify-or-top`: consults ambient meta solutions *inside the merge*; non-commutative when both sides hold unsolved metas | most typing and unify fires | a merge that is a function of its two arguments only; meta solutions read as cells by the caller | **deepest** — PPN territory |
| constraint store | `merge-hasheq-replace`, written undeclared by the retry bridge, which re-enters off-network elaboration inside an S0 fire | `metavar-store.rkt:1063` | the retry as a stratum action (it already cycles a status through the L2 handler) rather than an S0 fire | the only one of D.1's three named merges with an S0 writer |

**Consequence** (the theorem, applied): on these cells the BSP result is a deterministic function
of BSP's round structure and its bulk-merge order — not the least fixpoint of any lattice. "Parity
with BSP" is therefore not a correctness criterion for them. At K = 1, DIRECT is deterministic too
(a different order). At K > 1 the order is a race, and the theorem gives nothing until the merges
are joins.

### 9.5 Ambient state inside fires — the executor-thread hazard

Read inside S0 fires (MEASUREMENT, draft §6): `current-worldview-bitmask` in unwrapped fires
(`metavar-store.rkt:504`); `current-bsp-fire-round?` (13 production reads that choose between
a topology *request* and an *inline* install — the inline branch is the unstratified path §9.8
retires);
the mutable `current-prop-net-box` (`set-box!` inside the retry bridge — a data race at K > 1);
`current-lattice-meta-solution-fn` inside a *merge*. Racket threads inherit the creating thread's
parameterization at creation (Racket Reference, *Parameters*), so a long-lived executor sees
creation-time values. JUDGEMENT for D.2: a fire's dynamic context belongs to the propagator record
and the executor's per-fire setup, never to the thread.

### 9.6 Decision for D.2 — a tradeoff, weighed against the principles

Stage 2's rule was "DIRECT for all of S0 if the Q1 audit is clean; otherwise confine". It is not
clean. Two ways forward:

| | (A) confine | (B) make the lattices joins |
|---|---|---|
| what | DIRECT only for propagators whose output cells all have join merges; the rest in a BSP sub-run per S0 run | fix the §9.4 rows, so the theorem's hypotheses hold by construction; then DIRECT everywhere |
| cost | two schedulers indefinitely; the classification must be **per facet** (the attribute map is 79 % of writes, §2.3, and is non-join only through `:usage`/`:warnings`), so most measured work stays on BSP | seven lattice changes of uneven depth; the type-cell merge is deep |
| principles | manages the problem; correctness rests on the classification being right ("correctness by care") | dissolves it; correctness by construction; parity becomes a theorem; also fixes two defects BSP has today (157, 158) |

**Recommendation: B as the target, staged by the phase gates.** P2 runs at K = 1 and needs
neither — it is deterministic; its full-suite run triages any divergence from BSP against §9.4.
The lattice fixes are the gate for P3 (K > 1); each lands independently and is measured the same
way — its divergence row in the parity skeleton becomes a parity row. (A) remains available
per cell if one lattice (the type merge) resists. This is a design decision for the owner in D.2.

### 9.7 D.1 corrections applied (errata callout in D.1 §14)

103 → 144 call sites (157 audited); §5.3 "duplicates harmless *because merges are idempotent*" is
false for tagged cells, `:usage`, cell-14, `:warnings` — and for topology-installing fires (§9.3,
duplicate install); §6.1 lists worldview bitmasks as `'flat-bitmask` with `fxior` — that is the
**target** lattice (G′), not today's (replacement + AND-NOT), so adopting it is a semantic change,
not a re-representation; §5.2 / A-8's "hub cells only read at the boundary" is refuted for cell-1,
which is read and written inside S0.

### 9.8 Topology changes during propagation — stratified only through requests (added 2026-10-13, after owner guidance G-1)

The owner's guidance (D.1 §14 G-1): creating structure during propagation is a topology change and
needs a stratum — otherwise S0 solves a maze whose walls move. The code has **two** mechanisms
(read at `7a0116ec`):

| mechanism | applied where | stratified? |
|---|---|---|
| topology **request** — a set-union write to a request cell (cells 6–9), the branch taken when `current-bsp-fire-round?` is `#t` | by the topology tier, `process-tier … 'topology`, after the S0 inner loop quiesces (`propagator.rkt:3322` inner loop → `:3482`) | **yes** |
| structure created **inline** inside a fire — `fire-result-new-propagators` / `-new-cells` | `collect-deferred-propagators` + `net-add-propagator` *inside* the inner loop, between rounds, before S0 quiesces (`:3372-3377`); flags dropped (DEFERRED 158) | **no** |

**Measured** (branch `par4-p0`, counter + `PAR4_TRAP_MIDRUN=1` trap in the BSP inner loop):

| workload | structure created inside fires under BSP |
|---|---|
| comparative corpus, 18 files, prelude preloaded (682 rounds) | 0 propagators, 0 cells |
| forced ATMS: solve-adversarial, atms-adversarial, solve-scale (297 rounds) | 0, 0 |
| **full suite with the trap armed**: 10 257 tests, 489 files | **all pass** — no test reaches the path |
| power check: the M4 probe's deliberate in-fire install, trap armed | trap fires (exit 1: "1 propagators, 0 cells") |

So under BSP the unstratified path is **dead in production** (the trap can fail and did not, across the
suite). It remains reachable from fires run with `current-bsp-fire-round?` `#f` — the sequential
drain — which is where the duplicate install of §9.3 came from.

**Consequences.** (1) DEFERRED 158's fix shape is revised: not "carry the flags through", but
**retire the path** — a fire that creates structure is an error, and discovery goes through a request
that carries the full propagator spec (flags, assumption, paths, srcloc). Measured production cost: zero.
(2) Under DIRECT there are no rounds, so the inline path has no defined application point anyway;
executors run fires on a fixed topology, and the topology tier is the only writer of structure.
(3) For BSP-LE 3: tabling's producers and consumers are created by topology requests; each S0 run
solves a fixed maze. SLG completion of a region is then S0-quiescent **and** no pending topology
request for it — a conjunction the scheduler can expose as one event (CONJECTURE until BSP-LE 3's
design states how it installs).

## 10. Re-measured on a verified limited build, after the move to the track branch (2026-10-13)

**Why.** The merge-laws note §7c ([DEFERRED 159](../../../DEFERRED.md)) showed that main's tree ran an
interpreted compiler from 10-12 20:24 to 10-13 02:55, and that `par4-p0` timings before 02:17 cannot be
verified after the fact. §7c's instruction: confirm a limited build, then re-run the rows a decision rests
on. **Where**: branch `par4-arena-executors` at **B1 = `3643f56e`** — main `01ef2542` (146, 147, 148, F3(a),
runner fixes) plus the P0 instrumentation. Build verified: `reduction` / `typing-core` / `macros` `.zo` =
302 215 / 289 697 / 439 415 B, §7c's limited-build fingerprints. Suite at B1: **10 339 tests / 495 files,
all pass** (= main's gate 10 330 / 494 + the 9 parity tests). Load 6–12 throughout (other sessions active).

### 10.1 Medium tier — the pre-track A/B, both legs limited builds (`benchmarks/par4/demos-ab.sh`)

PAR 2's code `ce4cde52` in a throwaway detached worktree (built with the limit), against B1 with the
tree-reduce threshold at 256 (as shipped) and off; interleaved, 3 rounds, medians
(`data/par4-p0/demos-ab-r93-limited/`):

| sequential ms | PAR 2 `ce4cde52` | B1, threshold 256 | B1, threshold off | 256 → off | off vs PAR 2 |
|---|---|---|---|---|---|
| graph colouring 500 (3 000 props) | 1.70 | 9.20 | **1.25** | **7.4×** | 26 % faster |
| constraint grid 12 (3 168) | 1.77 | 9.34 | **1.42** | **6.6×** | 20 % faster |
| graph colouring 200 (1 200) | 0.57 | 2.82 | **0.47** | 6.0× | 18 % faster |
| wave chain 1 000 (999) | 39.6 | 4.49 | **2.39** | 1.9× | 16.6× faster |

§3's conclusions **hold on verified builds and the effect is larger** (6.0–7.4× vs §3's 4.8–5.3×): 147
made the non-tree path cheaper, so the green-thread overhead is a larger share. The bisect (§3) was
already limited-build (`bisect-demos.sh` sets the limit); §3's HEAD column is superseded by this table.
Parallel/sequential at B1 with the threshold off: 1.20× (graph colouring 500), 1.51× (grid 12) — PAR 2's
recorded 1.42× is recovered on grids once the defect is removed.

### 10.2 Large tier — and a correction to this record's headline

Corpus stats at B1 (`data/par4-p0/comparative-stats-bsp-B1.jsonl`): counts identical to P0 (682 rounds,
2 879 fires); S0 86.7 ms vs 87.6 ms; per-file S0 within 4 %. So P0's large-tier *timings* were not
measurably distorted by the build question.

**But the denominator was.** P0 §2.2 divided S0 by the `process-file` window, and that window contains
`measure-memory-before`/`-after`'s two forced major GCs (DEFERRED 152): `gc_ms` ≥ 51 ms on **every**
file, including files whose remaining work is 2–3 ms — 984 of 1 274 ms at B1. CORRECTION:

| forced-GC attribution | S0 share of corpus work | H-S sequential | BSP K=8 | H-S + K=8 | H-S + K=16 |
|---|---|---|---|---|---|
| none — as P0 §0/§2.2/§5 published | 6.8 % | 1.02× | 1.04× | 1.06× | 1.06× |
| 51 ms/file (the smallest file's GC; lower bound) | **24 %** | 1.08× | 1.15× | **1.26×** | 1.27× |
| all `gc_ms` in the window (upper bound) | **30 %** | 1.11× | 1.19× | **1.34×** | 1.36× |

Per file, without the window's GC: `constraints-adversarial` 65 %, `type-adversarial` 53 %, `implicit-args`
37 %, `nat-arithmetic` 30 %, `bool-logic` 22 %. The per-file models in §2.2 were computed against profiler
**command** time, which excludes the forced GC, and they hold at B1:

| file | command ms/run (P0 → B1) | `run-to-quiescence-bsp` | `bulk-merge-writes` | `fire-and-collect-writes` | H-S sequential | H-S + K=8 |
|---|---|---|---|---|---|---|
| constraints-adversarial | 46.5 → 48.5 | 85 → 81 % | 41 → 28 % | 34 → 47 % | 1.52 → **1.49×** | 4.43 → **4.07×** |
| type-adversarial | 45.4 → 42.5 | 38 → 39 % | 21 → 21 % | 11 → 14 % | 1.31 → **1.35×** | 3.07 → **3.26×** |

(147 moved cost from the merge phase into the fire: `bulk-merge-writes` fell, `fire-and-collect-writes`
rose; `pu-value-diff` 70 → 74 % — the "paid twice" write remains.) **What changes**: the value
proposition in §5 and the answer to "does PAR 4 have value before BSP-LE 3?" are *stronger* than first
reported — S0 is a quarter to a third of today's corpus work, not a fourteenth. **Method fix**: until
DEFERRED 152 lands (stream `per-process-152-151`), the harness's S0 share is reported against
`total − gc` and `total − min gc` as bounds, never against the raw window.

### 10.3 What the other sessions' work changes for PAR 4 (from the git log since `7a0116ec`)

| work (commit) | bears on PAR 4 | consequence |
|---|---|---|
| 147 fire protocol (`63d8f6af`): light fire 1 386 → 928 B, read+write 2 819 → 2 232 B; **`parameterize` ≈ 496 B of the 928** (note §7b) | H-S's per-fire cost model (Stage 1's 2.8 KB) | D.2 re-bases on 928 / 2 232 B. **D.2 decision**: how fire context reaches a fire — measured 496 B (today) / 144 B (one composite parameter) / 0 B (continuation mark or executor-record field); the same choice fixes §9.5's thread-inheritance hazard |
| F3(a) (`5ec697bf`, record `eeb08e7f`) | P1 merge laws | landed (O-7); refuted the note's C prediction; F3(b) has a single-defect witness and two sites (`type-lattice.rkt:172-173`, `:217-218`); **the comparative corpus never reaches the binder arms** (0 binder-arm merges in the corpus vs 881 in the suite) → P0.5's acceptance file must include binder merges with unsolved metas |
| runner (`389b3413` LPT, `b45bbf44` pkill, `fd2986cc` whales, `92472849` queue, 161/164 gate) | P2's oracle is the full suite | a green suite is now honest (161, 164); 160 (suite-only failures) is still open — P2 failures must be checked file-alone before attribution. ⚠ This track's `suite-schedulers.sh` ran four full suites (00:56–01:04) before `b45bbf44`, so it would have killed any concurrent suite's workers machine-wide (DEFERRED 163) |
| 159 (`PLT_CS_COMPILE_LIMIT`), hook stream `guards-hook-sweep` | every PAR 4 timing | every `raco make` carries the limit; verify fingerprints before a baseline (this §) |
| stream `per-process-152-151` (152 forced GCs, 151(a) `.pnet` header) | this harness | when 152 lands, the window stops including forced GC; re-derive §10.2 directly |

## 11. O-9 evidence: DEFERRED 150's tree path under the whole suite, a merge-order census, the prelude caches, cold timing (added 2026-10-14)

**Why.** The owner accepted the O-9 lean ([D.1 §14](2026-10-12_PAR_4_D1_DESIGN.md): ship the fix for
DEFERRED 150 with the tree path off, and delete it). Before that, they asked for the full suite with the
default off, as a first pass ("it *should* pass if our architecture is actually CALM; if not, it would be a good
indicator that there is more to fix"), and for the rest of the evidence: performance (memory, time, firings) and
correctness. **Where**: branch `par4-arena-executors` at `eb25caee` = main `99c893d4` merged in (`2b1e1e78`) plus
the instruments below. Builds limited (`PLT_CS_COMPILE_LIMIT=1000000`). Load average 3–9 (other sessions active).
The timing run held the machine-wide suite lock exclusively.

### 11.1 What the two paths differ in (read at main `99c893d4`)

Below 256 fires, `bulk-merge-writes` (`propagator.rkt:2978`) applies each fire result in turn: that result's new
cells, then its declared writes (merged), then its undeclared writes (by **replacement**, the DEFERRED 157
mechanism), then its contradiction. At 256 fires or more, `tree-reduce-fire-results … #t` (`:3377`) first
concatenates all the results, in order, through a tree of green threads (`merge-fire-results`, `:3090`, only
appends lists). It then applies the one combined result. So the tree path does no lattice work, and it changes
one thing: **every declared write in the round is applied before any undeclared write**, and all new cells before
either. The two orders agree exactly when no undeclared write (and no created cell) shares a round with another
result's write to the same cell.

### 11.2 Instruments (all env-gated; behaviour-neutral when unset — gate with both unset: 10 394 / 502 all pass)

| instrument | what it does |
|---|---|
| `PAR4_TREE_REDUCE` = `off` \| *n* (`propagator.rkt:2255` at `eb25caee`) | the default of `current-tree-reduce-threshold`; unset = 256, as shipped |
| `PAR4_MERGE_ORDER_CENSUS=<file>` (`:3176`, called at `:3557`) | every BSP round with ≥ 2 fire results is applied to the **same snapshot** four ways: **F** flat (today's path below 256; the reference) · **C** flat again (control: anything `equal?` cannot see) · **T** tree-combined (today's path at ≥ 256) · **R** results reversed. It compares the raw value of every cell the round wrote or created (minus C's cells), the contradiction, and the worklist as a set. The extra networks are discarded and the write/change counters are unbound while they are built. It also counts the rounds that carry undeclared writes, created cells or contradictions. Per-process totals plus ≤ 300 divergence events are written at exit (plumber flush). BSP only. |
| `benchmarks/par4/o9-merge-order-power.rkt` | power rows (§11.3) |
| `o9-pnet-compare.rkt` | two `.pnet` trees, module by module, in `pnet-canonical` form (`tools/pnet-dump.rkt`) |
| `o9-cold-ab.sh` (+ `hold-suite-lock.rkt`) | cold-cache prelude elaboration, 256 vs off, interleaved |
| `o9-census-summary.py` | aggregates a census file |

Data: `racket/prologos/data/par4-p0/o9/`.

### 11.3 Power checks first — MEASUREMENT (`power.out`, `power.jsonl`, `power-threshold.out`, `pnet-compare.out`)

| row | network (one BSP round, two writers of C) | census | C at threshold 256 / 0 / off |
|---|---|---|---|
| power-T | declared write 3 into a max cell; undeclared write `C := 1`, its result first | **T differs**, R differs | **3 / 1 / 3** — the tree order changes the program's answer |
| power-T0 | the same writers, the declared result first | R differs only | 1 / 1 / 1 |
| power-R | two undeclared read-modify-writes of an ior cell (Q1's M3) | R differs only | 2 / 2 / 2 |
| neg-join | two declared writes into a max cell (a join) | nothing differs | 3 / 3 / 3 |
| neg-ior | two declared writes into an ior cell | nothing differs | 6 / 6 / 6 |

So the census can report T and R divergences, and the shape §11.1 predicts does change a result once the tree
path takes it. The cache comparison can fail too: overwriting `core/ord.pnet` with `core/eq.pnet` is reported
(1 of 39, 15 slots). A first attempt at that check overwrote a module that does not exist, compared nothing, and
printed 39/39 identical. It was a zero-power check, caught by its own output and redone.

### 11.4 Results — MEASUREMENT

**The full suite with the default off**: **10 394 tests / 502 files, all pass** (`suite-off.log`; the pass
included the prelude caches regenerated under off).

**Prelude caches**, generated cold (`pnet-compile.rkt --clean`, then generate) under each setting: **39 of 39
modules identical** for 256 vs 256 (control), 256 vs off, and 256 vs 0 (tree path on every round).

**Merge-order census** (threshold 256, as shipped):

| population | BSP rounds | fires | rounds ≥ 256 fires (their fires) | compared rounds (≥ 2 results) | T differs | C noise | R differs: cells | R differs: contradiction | rounds with undeclared writes (in wide rounds) |
|---|---|---|---|---|---|---|---|---|---|
| full suite, 18 workers (`census-suite.*`) | 15 422 | 979 335 | **648** (813 154) | 12 527 | **0** | 0 | **249** rounds, 275 cells | 11 (7 wide) — identity only, never presence | 87 (**0**) |
| corpus, 18 files, prelude preloaded (`census-corpus.*`) | 687 | 2 901 | 0 | 448 | 0 | 0 | **26** | 0 | 0 |
| cold prelude, `pnet-compile` / `process-file` (`census-prelude-cold.jsonl`) | 5 / 4 | 2 002 / 789 | 2 (1 581) / 1 (368) | 5 / 4 | 0 | 0 | 0 | 0 | 0 |

The census suite also passes 10 394 / 502, and two census runs gave identical counts. No round in any population
created cells (G-1's finding, again). `parity-adversarial` is excluded from the corpus rows, as in §2, because it
crashes (DEFERRED 153).

R's divergences by merge function (events naming it; suite / corpus): `meta-solution-merge`
(`typing-propagators.rkt:968`) 117 / 17 · `resolution-stratum-merge` (the ready queue, cell-14;
`propagator.rkt:802` at main) 74 / 4 · `attribute-map-merge-fn` (`typing-propagators.rkt:447`) 62 / 3 ·
`make-tagged-merge`'s lambda (`decision-cell.rkt:526`) 16 / 2 · list-represented sets (`set-union-merge` and
`set-merge`, both test fixtures; `merge-list-append`, `infra-cell.rkt:166`; `topology-request-merge`) 6 / 0 · a
contradiction only 11 / 0. Of the events, 174 of 260 have no `tests/` frame on the stack, so test-file
attribution is partial.

**Cold-cache prelude elaboration**, `P0_NO_PNET=1` on a near-empty file, 10 interleaved rounds per leg
(`cold-ab.jsonl`):

| median | threshold 256 | off | paired difference |
|---|---|---|---|
| BSP merge phase (the one 368-fire round dominates) | 3.03 ms | **0.020 ms** | 151× |
| allocation, whole run | 470.7 MB | 463.1 MB | **−7.2 … −8.1 MB** in every pair |
| wall, whole run | 422.8 ms | 414.7 ms | −11.8 … +24.5 ms: within noise |
| process CPU | 0.57 s | 0.56 s | — |
| GC | 48 ms | 47 ms | — |
| rounds / fires / widest round | 4 / 789 / 368 | 4 / 789 / 368 | identical |

The medium tier, where every round is wide, stands as measured in §10.1 (6.0–7.4×). Main's merges since did not
touch `propagator.rkt`.

### 11.5 What this says about O-9

- **The flip is a no-op on everything measured.** Suite, corpus and prelude all agree, and the census says why:
  T is 0 because no wide round carries an undeclared write or a created cell (MEASUREMENT; the explanation is
  §11.1's reading checked against the census's counts). So the suite's pass is **predicted by structure**. It is
  real evidence for O-9: the default can change without changing any measured result. It is **weak** evidence
  for CALM, because the suite never presents the shape (power-T) on which the two orders differ.
- **The cost is real but concentrated.** 151× on the merge phase of a wide round and 7.7 MB per cold
  elaboration (about 21 KB per pairwise merge, if the 367 merges of a 368-result tree account for all of it:
  MODEL). End to end on cold elaboration it is below noise, because one round in four is wide. The 6–7× falls
  where networks are wide every round (§10.1).
- My lean's second reason ("a second merge order chosen by round width") is **right in mechanism** (power-T)
  and **unreached in production** (T = 0). It argues for deleting the path rather than defaulting it off:
  deletion removes the shape for good, with no knob left to bring it back.

### 11.6 What this says about CALM — the R column

The asynchronous-iteration theorem (§9.4) needs joins on every cell written during S0. A join is commutative, so
a round's outcome cannot depend on the order its results are applied in. **R measures that order-independence
directly, in production**:

- 249 of the suite's 12 527 multi-result rounds (2.0 %) and 26 of the corpus's 448 (5.8 %) end with **different
  cell values** when applied in reverse order. 11 suite rounds report a different contradiction cell (never a
  different presence).
- The merges involved are rows of the Q1 audit's table (§9.4): meta-solution output, the ready queue (cell-14),
  the attribute map's facets, tagged cells. The static audit **predicted** these, and this is their **dynamic
  witness**. The audit's other rows (worldview cell-1, scope cells, type cells, the constraint store, cell-15)
  were not observed diverging. That means the suite does not put two of their writers in one round. It does not
  show they are safe.
- R tries ONE alternative order, so its counts are **lower bounds** on order-dependent rounds.
- Equality is `equal?`: a set kept as a list differs by order even when its consumer would not care. Whether
  consumers care is not measured.
- BSP hides all of this because its order is deterministic. Under DIRECT at K > 1 the order is a race, so these
  rounds become nondeterminism. That is O-5's reason for putting P1 (merge laws) before P2/P3, now measured in
  production rather than only by audit.

**Answer to the owner's test.** The suite passed, so this test found nothing more to fix. But by the census's own
count it could not have found anything. The R column is the test that can, and it finds the audit's rows. In
G-2's terms ([D.1 §14](2026-10-12_PAR_4_D1_DESIGN.md)), the census is a **co-inductive** check: a runtime
monitor that perturbs the application order and compares outcomes. P1's "is a join" property (E) is the
**inductive** layer, and the parity suite under several schedules is the **testing** layer. D.2 should keep the
census as a standing check: the P0-8 exposure census (note §5) can extend it with per-cell merge-law counts, and
P1's gate can be "R = 0 on the S0 cells P1 converts".

### 11.7 Limits

- BSP rounds only, so not the sequential drain.
- Merge functions are assumed pure when applied three extra times. The census suite passing 10 394 / 502 with
  identical counts on two runs is evidence for that, not proof.
- R is one permutation, so its counts are lower bounds.
- Test attribution is partial (stack frames).
- The cold-timing wall difference is within noise; the allocation difference is not.

### 11.8 Reproduce

```
cd racket/prologos
PAR4_TREE_REDUCE=off racket tools/run-affected-tests.rkt --all --force-rerun --no-record --no-bail
PAR4_MERGE_ORDER_CENSUS=$PWD/c.jsonl PAR4_MC_LABEL=suite racket tools/run-affected-tests.rkt --all --force-rerun --no-record --no-bail
python3 benchmarks/par4/o9-census-summary.py c.jsonl --exclude-prelude-gen
for r in power-R power-T power-T0 neg-join neg-ior; do PAR4_MERGE_ORDER_CENSUS=$PWD/p.jsonl PAR4_MC_LABEL=$r racket benchmarks/par4/o9-merge-order-power.rkt $r; done
racket tools/pnet-compile.rkt --clean; [PAR4_TREE_REDUCE=off] racket tools/pnet-compile.rkt   # copy data/cache/pnet aside per leg
racket benchmarks/par4/o9-pnet-compare.rkt <copy-A> <copy-B>
racket benchmarks/par4/hold-suite-lock.rkt tools/suite-lock.rkt bash benchmarks/par4/o9-cold-ab.sh 10 cold-ab.jsonl
```
(Wrap each `racket` in `timeout -k`, per the hook guard.) The `PAR4_TREE_REDUCE` legs (the off-suite, the cache
generations, `o9-cold-ab.sh`, `power-threshold.out`) run at `eb25caee`: owner decision O-10 removed the knob in
`a0b78fda`, and `o9-cold-ab.sh` refuses without it. The census, the power rows and the cache comparison still run
on later trees.
