# PAR 4 · Stage 2 — Gap Analysis: what the arena executor has to fit, measured from code

**Serves**: **PAR 4 — Arena Executors** (owner ruling 2026-10-12; opened from the Track-2 row
`2026-03-27_PAR_MASTER.md:33`). **Stage 1 input**:
[`research/2026-10-12_PAR_4_STAGE1_CONTENTION_ANALYSIS.md`](research/2026-10-12_PAR_4_STAGE1_CONTENTION_ANALYSIS.md).
**Written at** `7a0116ec`. Counts are `grep` over `racket/prologos/*.rkt` production sources
(tests, benchmarks, tools, compiled excluded); commands recorded in §6 so they can be re-run.
Per `DESIGN_METHODOLOGY.org:122-134`, every count here is a measurement, not an estimate.

> ⚠ **CORRECTION (2026-10-12, same day)** — the merge-function census in §0.1 and §1 was computed
> over `-r .` and **included tests and benchmarks**. Re-run production-only (123 `net-new-cell`
> sites): `max-merge`/`flat-merge`/`+` are overwhelmingly test cells; the production merges are
> structured (`merge-hasheq-replace` 23, `term-merge` family 9, `merge-list-append` 6, type/msg/
> session/choice lattices 29, …). The "47 % fixnum-representable" claim is **withdrawn**; the
> genuine non-join merges to audit are `merge-list-append`, `merge-hasheq-replace`,
> `merge-replace` (30 sites, infra cells). Moreover a static site count cannot decide the storage
> tier — one `logic-var-merge` site allocates thousands of cells per query — so eligibility is
> decided by a **dynamic cell census** (new Pre-0 A-13). Full table and consequences:
> [`research/2026-10-12_PAR_4_STAGE1_RESEARCH_SYNTHESIS.md` §5](research/2026-10-12_PAR_4_STAGE1_RESEARCH_SYNTHESIS.md).
> The site counts for `net-cell-write`/`read`/`net-new-cell`/`net-add-propagator`/`fork` in §1
> excluded tests and stand. Fact 2 (forks are rare) stands.

## 0. The two facts that shape the design

1. **Cells hold arbitrary Racket values under 66 distinct merge functions.** The arena
   prototype held fixnums under `max` and a bitmask-tagged set. So "replace the network with
   an fxvector" is not a design; **a storage tier is**. The four fixnum-representable lattice
   kinds (`max-merge` 108, `flat-merge` 104, `or-merge` 20, `tagged-cell-merge`/
   `tagged-aware-flat-merge` 19 — **251 of ~530 `net-new-cell` merge arguments, 47 %**) can
   live flat; structured values (`type-merge` 12, `session-lattice-merge` 32, `term-merge` 7,
   `msg-lattice-merge` 10, 61 inline lambdas, …) keep heap values. The scheduler half of the
   design (ownership, direct S0 writes, no snapshot/diff/re-merge) applies to **every** cell
   regardless of tier; the flat half applies to the 47 %.
2. **Forking is rare in code: `fork-prop-network` has 5 call sites in 2 files**
   (`propagator.rkt` 3, `relations.rkt` 2 — the S1 NAF handler and the fork-on-union
   stratum). The ATMS does NOT fork the network per branch; it layers worldview bitmasks on
   shared cells (2B's "scope sharing > bridges"). This matters because the persistent CHAMP
   network exists *for* O(1) fork (`fork-prop-network`: 232 ns, 1.2 KB), and a flat arena
   forks by copy. Whether that trade is acceptable is a **Pre-0 measurement**: forks per
   query on the comparative corpus, not a guess.

## 1. The surfaces the design touches (grep-backed)

| surface | sites | files | top files | what it means for the design |
|---|---|---|---|---|
| `(net-cell-write …)` | **200** | 35 | elaborator-network 32, sre-core 19, session-propagators 19, session-runtime 16, relations 15, propagator 14, typing-propagators 12, atms 11 | the write API stays; its *implementation* changes per tier. No caller should know the tier. |
| `(net-cell-read …)` | **210** | 37 | typing-propagators 31, elaborator-network 26, relations 23, propagator 22 | same; reads under DIRECT may see same-round writes (§3 Q1) |
| `(net-new-cell …)` | **107** | 29 | macros 24, session-runtime 16, atms 8, narrowing 7, relations 6 | the tier decision point: the merge-fn argument selects the storage tier at allocation (cf. the existing `specialized-cell-meta` tier/storage fields) |
| `(net-add-propagator …)` | **103** | 18 | elaborator-network 39, typing-propagators 13 | the partition's input: propagator in/out cell lists are the graph the cut is computed from |
| `fork-prop-network` | **5** | 2 | propagator 3, relations 2 | fork = partition-level copy-on-write; frequency to be measured |
| `run-to-quiescence*` | 23 | 10 | propagator 10, unify 3, relations 2, prop-observatory 2 | the scheduler entry; executors become scheduler-owned, not per-call |
| `current-parallel-executor` / worker pool | 10 | 2 | propagator 9, driver 1 | the parameter to retire into a scheduler cell (cells-over-parameters) |
| `tagged-cell-*` | 194 | 14 | decision-cell 50, propagator 42, metavar-store 19, meta-universe 18 | the one structured lattice already proven flat-representable (R3 §5) |
| `current-worldview-bitmask` / `worldview-cache` | **186** | 9 | propagator 97, relations 25, typing-propagators 20, elab-speculation-bridge 15 | where the round-synchronous-visibility question (§3 Q1) must be audited line by line |
| `save-meta-state` / `restore-meta-state!` | 8 | 2 | metavar-store 5, elaborator-network 1 | off-network speculation still exists (PM series' retirement target); out of scope here |

Merge-function census (`net-new-cell` third argument, 530 occurrences, **66 distinct**):
`max-merge` 108 · `flat-merge` 104 · inline `(lambda …)` 61 · `session-lattice-merge` 32 ·
`or-merge` 20 · `eff-pos-merge` 19 · `+` 13 · `type-merge` 12 · `eff-ordering-cell-merge` 12 ·
`tagged-cell-merge` 10 · `msg-lattice-merge` 10 · `type-unify-or-top` 9 ·
`tagged-aware-flat-merge` 9 · `term-merge` 7 · `merge-replace` 6 · `int-merge` 5 · `max` 5 · …

## 2. What exists already (infrastructure the design builds on, not replaces)

- **A storage-tier hook is already in `net-cell-write`** (`propagator.rkt:1899-1982`):
  `specialized-cell-meta` with `tier 'hot` and `storage 'monotone-counter` takes a fast
  path with a cached merge-fn. It still path-copies the CHAMP and the spine; it is the
  seam where a `'flat-arena` storage would plug in. (D.4 1B-ii.)
- **Ownership-friendly write semantics exist**: `net-cell-write` returns the same network on
  no-change (0 B, 56 ns) — the "write contention without re-firing" the PAR master asked
  for is this check plus ownership.
- **The BSP scheduler and strata** (`run-to-quiescence-bsp`, `register-stratum-handler!`,
  tiers `'topology` / `'value`): the barrier placement the design needs *already exists as
  the stratum boundary*. S0 is the only place the barrier is removed.
- **Spin pool + per-worker slots**: `make-worker-pool` (`propagator.rkt:3623`) has the
  shape (persistent `#:pool 'own` workers, per-worker slots) but signals through
  semaphores/async-channel and spins count-bounded. R3's `spinpool.rkt` is the replacement
  shape (boxes + fences, state-bounded spin, orchestrator on a parallel thread).
- **Partition input**: every propagator declares inputs/outputs
  (`propagator-inputs`/`-outputs`); the cut can be computed from the declared graph, and
  `fire-and-collect-writes` already treats undeclared writes as a classified exception.
- **`.pnet` serialization** (`pnet-serialize.rkt`): a flat tier must round-trip through it,
  or be reconstructed at load from the heap form. Not yet examined; design item.

## 3. Gaps and open questions (each gets a Pre-0 measurement or an audit in D.1)

| # | gap / question | how it is closed |
|---|---|---|
| Q1 | **Round-synchronous visibility**: does any of the 186 worldview sites, or any S0 fire, assume that a value written in round *r* is invisible until *r+1*? DIRECT mode makes it visible immediately (same fixpoint, different path). | Line audit of `propagator.rkt` worldview sites (97) + `relations.rkt` (25) in D.1; adversarial test: run the solver parity suite under DIRECT. |
| Q2 | **Fork cost vs frequency**: CHAMP fork 232 ns / 1.2 KB vs arena copy (3.5 MB at C=16 K, E=12 ≈ 100–300 µs). | Pre-0: count `fork-prop-network` calls per query over `benchmarks/comparative/`; if ≪ 1 per query, copy is fine; if not, partition-granular COW. |
| Q3 | **Structured values**: 53 % of cells hold heap values whose merge allocates (type-merge etc.). The intensity law (R3 §2) says this bounds scaling for structure-heavy workloads. | Pre-0: bytes/µs of the elaborator's fires (`alloc-per-fire.rkt` on a real file) to see where typing sits; design: interning/hash-consing is a later track, not this one. |
| Q4 | **Partition derivation**: can the scheduler compute the cut from the propagator graph (declared in/out lists) so locality is structural? | D.1 proposes: partition = connected-component / min-cut over declared edges at topology-stratum time; Pre-0 measures edge locality on real networks. |
| Q5 | **Dynamic topology**: `net-new-cell` inside fires (PAR Track 0 found 2 violators) needs pre-allocated arena capacity or topology-stratum growth. | Already stratified (PAR 1); arenas grow at the topology stratum only. |
| Q6 | **Serialization** (`.pnet`) of flat cells. | Design item; likely "serialize the heap form, rebuild the arena at load". |
| Q7 | **K and oversubscription** on the owner's machines; executors must park when the network is idle (not burn 16 cores between queries). | Scheduler cell for K (default cores − 2); park/unpark protocol = the one 8 µs wake per solve, not per dispatch. |

## 4. Tradeoffs made explicit

| choice | A | B | recommendation |
|---|---|---|---|
| storage | all cells flat (handles for structured values) | **two tiers**: flat for the 4 fixnum lattices, heap slots for the rest | **B** — 47 % of sites get the full win now; A needs interning (its own track) |
| S0 writes | buffered (BSP, deterministic rounds) | **direct to owned records** (chaotic iteration) | **B if Q1 audit is clean**; else A — the join phase is cheap either way (R3 §5) |
| fork | keep CHAMP for all | arena copy | **decide on Q2's number** |
| executors | per-call pool | **scheduler-owned, parked between solves** | B (owner's framing; R3 K rule) |
| partition | static round-robin | **graph cut at topology stratum** | B, with round-robin as the Pre-0 baseline |

Principle check (`DESIGN_PRINCIPLES.org`): cells over parameters (executor pool and K
become cells) ✓; decomplection (scheduler vs storage tier are separable; either lands
alone) ✓; illegal states unrepresentable (owner-only writes to a partition are structural,
not disciplined) ✓; stratification (barrier = stratum boundary — nothing new is invented;
the existing design is *used*) ✓; mantra (all-at-once / in parallel / on-network: executors
are the network's own children, their arenas its own cells) ✓.

## 5. Recommendation

Proceed to **Stage 3 (D.1)** as **two landable halves in one design**: (I) the scheduler
half — scheduler-owned spin executors, ownership partition, direct S0 writes, deltas only
across partitions, barrier at the stratum boundary — which removes the 1.4 KB ceremony and
the double write for *every* cell; (II) the storage half — a `'flat-arena` storage on the
existing `specialized-cell-meta` seam for the 4 fixnum lattices (47 % of allocation sites).
Pre-0 benchmarks: Q2 (fork frequency), Q3 (elaborator bytes/µs), Q4 (edge locality), and
the solver parity suite under a DIRECT prototype (Q1). Stage-1 addendum still owed: a
short literature note on chaotic/asynchronous iteration, LVars/CALM, and partitioned graph
engines — R3 names them but did not survey them.

## 6. Commands (re-run from `racket/prologos/`)

```
grep -c '(net-cell-write ' $(grep -l '(net-cell-write ' *.rkt)      # per file; 200 total
grep -o -h '(net-new-cell [^ ]* [^ )]* [^ )]*' -r . --include=*.rkt | awk '{print $NF}' | sort | uniq -c | sort -rn
grep -c 'fork-prop-network' propagator.rkt relations.rkt            # 3 + 2
grep -c 'current-worldview-bitmask\|worldview-cache' propagator.rkt relations.rkt typing-propagators.rkt elab-speculation-bridge.rkt
```
