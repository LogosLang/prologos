# PAR 4 · Stage 1 — Research Synthesis of record: prior art, frontier, and what Track 4 may rely on

**Serves**: PAR 4 — Arena Executors (`2026-03-27_PAR_MASTER.md` Track-4 row). **Supersedes** the two
commissioned drafts, which are kept as record and carry the detail this document points into:
[`…_STAGE1_PRIOR_ART_SYNTHESIS_DRAFT.md`](2026-10-12_PAR_4_STAGE1_PRIOR_ART_SYNTHESIS_DRAFT.md) (our corpus;
17-row inventory, 15 refutations R1–R15) and
[`…_STAGE1_FRONTIER_SURVEY_DRAFT.md`](2026-10-12_PAR_4_STAGE1_FRONTIER_SURVEY_DRAFT.md) (primary literature;
18-row theorem table T1–T18, 12 assumptions A-1…A-12, verified bibliography). Measurements are in
[`…_STAGE1_CONTENTION_ANALYSIS.md`](2026-10-12_PAR_4_STAGE1_CONTENTION_ANALYSIS.md). **Written at**
`7a0116ec`. Labels: **THEOREM** (with hypotheses) · **MEASUREMENT** (ours, probe named) ·
**PRECEDENT** · **CONJECTURE** (ours, testable, mapped to a Pre-0) · **TASTE**.

> Method note, per the owner's standard: both drafts were read in full and spot-checked; one of
> their findings was **withdrawn** here after re-measurement (§5 below), and the Stage-2 gap
> analysis carries a correction because of it. A refuted claim is a result; it is recorded, not
> erased.

## 0. What Track 4 may rely on, in one paragraph

The design has two load-bearing claims, and both are instances of theorems with stated
hypotheses rather than folklore. **(i) S0 can run without a barrier and reach the same
fixpoint.** Asynchronous-iteration theory — Chazan–Miranker 1969 → Cousot 1977 → Bertsekas
1983 → Üresin–Dubois 1990 (T4–T8) — gives the exact conditions: a *monotone, inflationary*
operator on a product of lattices (the box condition = one record per cell), finite chains for
termination, and three schedule conditions: reads see only already-written values (A1), every
dirty cell is eventually re-fired (A2), no value is used forever (A3). Our corpus already stated
the synchronous form ("chaotic iteration = propagator scheduling",
`LATTICE_FOUNDATIONS_PPN.md:418-442`) and our own prototype measured the predicted outcome (same
fixpoint hash at K ∈ {1,2,4,8,16}, BSP and DIRECT, `arena-tagged*.rkt`). What the theorems do
**not** give for free, and what Q1 therefore *is*: every S0 **propagator** must be a monotone
function of its input cells — a join-shaped merge is necessary, not sufficient. **(ii) The
barrier belongs at the stratum boundary.** CALM (Ameloot–Neven–Van den Bussche, T9) proves
monotone ⇔ coordination-free *and* that detecting the fixpoint is non-monotone; so quiescence
detection is unavoidable coordination, which can be a counter scheme (Mattern; Naiad; LVish)
costing about what our 0.8 µs barrier costs, once per stratum transition instead of per round.
`stratification.md` already places S(−1) and S1 there; LVars' `freeze`, Naiad's frontiers and
Flix's `fix` are the same rule in four traditions. Everything else — ownership, deltas, the
arena — is engineering under those two theorems, and our own earlier scheduling proposals (CAS
on cells, work-stealing writers, hypercube all-reduce, "the 8 µs wakeup is fundamental") are
each refuted by the Stage-1 measurements for a reason the theorems name: they admit multiple
writers per component (violating Bertsekas–Tsitsiklis' "own component never stale") or
replicate state (the double-write defect × K).

## 1. Theorems the design rests on (hypotheses stated; full table T1–T18 in the frontier draft §1)

| | result | hypotheses | source (verified) | what it licenses here |
|---|---|---|---|---|
| T1 | Knaster–Tarski: monotone f on a complete lattice has an lfp = ⨅{x : f(x) ≤ x} | complete lattice; f monotone | Tarski 1955 | the S0 target exists and is unique; nothing about reaching it |
| T2/T3 | Kleene iteration reaches lfp in finitely many steps under the ascending chain condition; without ACC, widening ∇ forces termination at a precision cost | continuity or monotone+ACC; ∇ an upper bound with finite chains | Cousot–Cousot POPL 1977 §9 | "termination is structural" = per-cell ACC × finitely many cells per solve (Q5 keeps the second true) |
| T5–T8 | Asynchronous iteration converges to the same lfp for every schedule satisfying A1 (causal reads), A2 (every component updated infinitely often), A3 (finite staleness), given a monotone inflationary operator on a product of posets with finite chains; on finite domains these box conditions are also *necessary* | as stated; Bertsekas' box condition = state is a product of per-cell lattices; B–T Assumption 2(c): a processor's view of its own component is never stale | Cousot RR-88 (abstract verified, body not read); Bertsekas 1983 (read); Üresin–Dubois JACM 1990 (read; two auxiliary results corrected in Agda, JAR 2020 — main theorem stands) | DIRECT mode. Ownership is not an optimisation of CAS: single-writer-per-cell is the hypothesis 2(c) that makes the theorem apply |
| T9 | CALM: a query is coordination-free ⇔ oblivious ⇔ monotone; fixpoint *detection* is non-monotone | relational transducers, arbitrary horizontal partition, fair asynchronous delivery | Ameloot et al. JACM 2013 Thm 12/13 (arXiv 1012.2858); Hellerstein–Alvaro CACM 2020 Thm 1 | the partition is semantically free (Q4 is pure cost); the stratum boundary is where coordination is unavoidable. Caveat: stated for monotone logic over sets; the lattice generalisation is the LVars/Bloom^L folklore, not in the JACM proof |
| T10/T11 | LVars determinism (lub writes + threshold reads); quasi-determinism with `freeze` (late write ⇒ `error`) | writes are lubs; reads are threshold reads; handler quiescence detected by the runtime | Kuper–Newton FHPC 2013 Thm 1; Kuper et al. POPL 2014 Thm 1 | our reads are not threshold reads, so the burden moves to propagator monotonicity (Q1); our stratum barrier is a *global* freeze — a per-cell frozen bit makes a late S0 write a classified error |
| T12/T13 | CvRDT convergence; δ-CRDT: all replicas converge if every delta is joined at least once anywhere — proof needs only ACI | join-semilattice payload; inflationary mutators; **idempotence** | Shapiro et al. SSS 2011 Thm 1; Almeida–Shoker–Baquero JPDC 2018 Prop 5.1 | owner-bucketed dirty lists are delta-groups: no ordering, no acks, duplicates harmless — *iff* merges are idempotent (§5) |
| T14 | Kahn determinacy: continuous processes on histories have a unique minimal solution | continuity; blocking reads | Kahn 1974 | same proof shape with lattices for histories; non-consuming reads are the easier case |
| T17 | BSP cost = w + g·h + L per superstep | — | Valiant CACM 1990 | L ≈ 0.8–1 µs (measured); the barrier matters when per-round work ≈ L — the tail rounds of every solve (BSP 15 vs DIRECT 10 rounds measured) |
| T18 | Region soundness: `letregion` bulk-free, no access after deallocation | ML-like, stack discipline | Tofte–Talpin 1997 | the arena is a region; its price is no intra-region reclamation ⇒ compaction is ours to build; its lifetime (network / query / fork) must be declared in D.1 |

## 2. What our corpus already settled (reusable; prior-art draft §2)

1. **Chaotic iteration = propagator scheduling**, hypotheses written down
   (`LATTICE_FOUNDATIONS_PPN.md:418-442`); independently re-derived as "propagator network ≅ cc(D),
   quiescence = lfp" (`ASYNCHRONOUS…QUANTALE…md:789-823`). THEOREM, in-house.
2. **Submodule independence = parallelizability** (`MODULE_THEORY_LATTICES.md:257-264`): connected
   components of the cell/propagator graph are the ideal partition; the ownership cut is its
   relaxation (cross-partition deltas = the off-diagonal terms; cut size = Valiant's h). The
   "~1 hour experiment" proposed there was never run — it is **Pre-0 Q4**. CONJECTURE to test
   with it: the real network is one giant component because request-accumulator cells and the
   worldview cache are hubs, so the usable cut excludes hub cells (their writes are only read at
   the stratum boundary anyway).
3. **Barrier = stratum boundary** (`stratification.md:60-92`): the admission test "does this
   computation require others to reach quiescence first?" is the CALM only-if direction. Corollary
   for Q1: a round-synchronous-visibility dependency *inside S0* is an undeclared stratum.
4. **Scope sharing > bridges** (2B handoff `:118-119`; `structural-thinking.md:95-105`): the ATMS
   labels (worldview bitmasks on shared cells) instead of copying — why `fork-prop-network` has 5
   call sites, and why the arena inherits cheap branching for free (Q2 is only about S1 NAF and
   fork-on-union).
5. **BSP cost model and Multi-BSP** (`PARALLEL_ALGORITHMS_SURVEY.md:43-67`): the model stands; every
   parameter the corpus assumed is now measured (L: 80 µs → 0.8 µs; g: 8 µs → 60 ns; the dominant
   term was never w but *bytes allocated* at 2.2 GB/s).
6. **The Boolean-lattice realisations** (`HYPERCUBE…ADDENDUM.md:50-62`, `LATTICE_HIERARCHY…md:251-258`):
   the subcube test and O(1) bitmask ops are what the flat tagged record implements. A point the
   corpus implied but did not state: the entries component is a powerset whose covering relation
   is single insertion — one Hasse edge = one append = one release-fenced word write. That is
   *why* the append-only DIRECT protocol is lock-free (MEASUREMENT for tagged cells; CONJECTURE
   that it generalises exactly to lattices whose flat encoding is prefix-closed — §4 A-4).
7. **Fork strategies** (`2026-02-23_LATTICE_PROPAGATOR_RESEARCH.md:63-130`): ATMS labelling vs MUSE
   copying vs stack splitting = the three Q2 options; an arena fork-by-copy *is* MUSE.

## 3. What the Stage-1 measurements refute in our corpus (prior-art draft §3 has all fifteen)

| old claim | refuting measurement | corrected statement |
|---|---|---|
| "The fundamental bottleneck is Racket's inter-thread communication … 8 µs … macOS scheduler cost" (`2B_DESIGN.md:1116-1129`); "no Racket-level mechanism beats the OS wakeup" (`2B_HANDOFF.md:111`) | box + fences 58–68 ns/hop; K=8 dispatch+barrier 0.8 µs (`pingpong.rkt`, `spinpool.rkt`) | the 8 µs is the price of *scheduler-routed* signals; raw memory is a cache-line transfer |
| CAS on cells; lattice-merge transactions; CAS on one shared network box (`03-26_SCHEDULING.md:35-41`, `03-28:86,136-144`) | owner-bucketed deltas: no CAS, identical fixpoint at every K | multiple writers per component violate B–T 2(c); ownership makes the write a store + release |
| work-stealing shared worklist (`03-26:43-47`, `RESEARCH_PARALLEL.md:737`) | dense per-executor deltas made the join O(K·C) (three defects, contention record §5) | fires are scheduled by the owner of the written cell; stealing is OPEN only if writes still land in owner buckets (straggler spread 2× is the cost to beat) |
| topological rounds = minimum rounds (`03-26:56-69`) | BSP 15 rounds, DIRECT 10 (`arena-tagged3.rkt`) | a lower bound for *synchronous* schedules only; inside S0 there is no round to minimise |
| "weak memory model is fine because snapshots" (`03-28:37`) | DIRECT has shared mutable records; release/acquire per record required | the snapshot argument held for the BSP executor only |
| "the contention point is `bulk-merge-writes`" (`03-28:67`) | census: 50 % ceremony, 17 % write, 33 % re-merge (`census.rkt`) | half the cost is the fire *protocol* (snapshot, returned network, output-set, diff), and the merge is not sequential under ownership |
| `:auto` by fire time vs spawn cost; GC pauses are the risk (`03-28:119,186,272`) | scaling is a function of bytes/µs (`intensity.rkt`); GC off still 0.9× (`gctune.rkt`); `c/alloc.c` refill mutex | executors are parked, not spawned; the governing variable is allocation intensity; PAR Track 3's `:auto` must be re-based on it |
| persistent structures "sidestep reclamation" and are the default (`RESEARCH_PARALLEL.md:896-900`, `03-26:31-33`) | ~~`champ-lookup` 64 B per read~~ (withdrawn 2026-10-13: production reads are 0 B — the probe measured `equal?` on a fresh key; see the CONTENTION_ANALYSIS correction); the write-side path copy (492–1 147 B per new-key insert) stands; every written byte paid twice | persistence is right for the network-as-value (fork, `.pnet`), wrong for the hot write path |
| hypercube all-reduce of state (`HYPERCUBE…ADDENDUM.md:75-77`) | nothing to all-reduce under ownership; K-flag reduce 0.8 µs | replicating merged state to every thread is the double-write defect × K |
| PAR Track 2 "4.45× synthetic, 1.42× real" — recorded without cause (`PAR_MASTER.md:40`) | real fires allocate ~2 KB/µs | *explained*, not refuted: the PoC's ceiling was the allocator |

Pattern: every refuted proposal assumed **shared mutable cells** or **replicated/persistent state**;
the Stage-1 design removes both. The one external confirmation worth quoting (via the LHC band,
`lhc/…/2026-08-16_STAGE1_B4_SCHEDULER.md`): Soufflé's relation structure scaled 59× alone and gave
1.9× on the real fixpoint — "bounded by the memory system and the relation representation, not by
scheduling policy". That is the axis.

## 4. The open questions, re-stated as theorem preconditions with tests (feeds Pre-0)

| # | assumption | kind | test | maps to |
|---|---|---|---|---|
| A-1 | every S0 propagator is a monotone function of its input cells under the worldview fixed for the solve | THEOREM precondition (T5/T8/T10) | static audit of the 103 `net-add-propagator` sites; parity suite under DIRECT at K=16 with randomised executor delays | **Q1** |
| A-2 | every S0 merge is ACI and inflationary with finite chains | THEOREM precondition (T2/T12/T13) | per-merge table (ACI? inflationary? height) over the **production** merge functions — see §5 for the real list | Q1 |
| A-3 | no S0 code observes *absence* ("not yet written") — all negative tests live at S1 | THEOREM (CALM only-if) | audit of the 186 worldview sites and of reads followed by emptiness checks inside S0 fires | Q1 |
| A-4 | a reader under DIRECT always sees a valid lattice element (flat encodings prefix-closed; heap cells publish by one pointer store under release) | design invariant | per-lattice encoding review; torn-read detector at K=16 | §2.6 |
| A-5 | executors are fair: none parks with a non-empty bucket; no fire caches an input across fires | THEOREM precondition (UD A2/A3) | park/unpark protocol with a drain check; grep for memoised reads | Q7 |
| A-6 | quiescence detection is exact (every produced dirty entry is consumed once) | boundary correctness | counter invariants in debug builds; **new Pre-0**: double-scan vs barrier vs atomic counter at K ∈ {4,8,16}, with detection latency | §1 T9 |
| A-7 | forks per query are rare enough for arena copy, else partition-granular COW | MEASUREMENT | count `fork-prop-network` per query on `benchmarks/comparative/`; cells touched per fork | Q2 |
| A-8 | the owner cut reduces cross-partition *writes* enough to pay for partitioning | MEASUREMENT | fraction of declared output edges crossing the cut: round-robin vs connected components vs balanced hypergraph partition | Q4 |
| A-9 | per-round work is small enough that L ≈ 1 µs matters | MEASUREMENT (T17) | rounds and fires/round per query on the corpus | §1 T17 |
| A-10 | region lifetimes (network / query / fork) are explicit; growth inside a live region is bounded by compaction | design + MEASUREMENT (T18) | region bytes per query; entries-per-cell distribution | Q5, Q6 |
| A-11 | cross-core transfer ≈ 60 ns on the target machine | MEASUREMENT | `pingpong.rkt` (done); hydroo core-to-core matrix on the M5 Max for the record | — |
| A-12 | heap-tier cells publish by a single pointer store; their merge allocation bounds scaling by the intensity law | MEASUREMENT | bytes/µs of elaborator fires on a real file | Q3 |
| **A-13** | **the tier decision is made on the RUNTIME cell population by merge kind, not on static sites** | correction (§5) | **new Pre-0**: count live cells by merge-fn at quiescence on the comparative corpus | Q3 |

Also from the survey, two design elements that were not in the Stage-2 candidate: a **frozen bit**
per flat record (LVars' `freeze`, T11) so a late S0 write after the boundary is a classified
error; and **quiescence detection as a counter scheme** (produced/consumed per executor, padded,
double-scanned) replacing the S0 barrier — CALM says the coordination cannot be argued away,
only made cheap. Reproducibility: Astrée/PIKOS abandoned asynchronous iteration under *widening*
for reproducibility (LHC band §2.3); our fuel-on-write contradiction (`stratification.md:150-153`)
is widening-shaped — whether fuel exhaustion before fixpoint depends on fire *count*, which
DIRECT changes, is a Pre-0 measurement (fires-to-fixpoint BSP vs DIRECT on fuel-bounded cells).

## 5. A finding withdrawn, and the correction it forces (this document's own critique)

The frontier draft reports as its third most important result that 18 `+`/`int-merge` cells are
not join-semilattices. That number came from the Stage-2 merge census, which — re-run today
production-only — turns out to have included tests and benchmarks: **every `+` and `int-merge`
site is in `benchmarks/micro/*` or `tests/test-branch-pu.rkt`; the production count is 0.** The
finding is withdrawn. The same contamination invalidates Stage 2's "47 % of allocation sites are
fixnum lattices" (`max-merge` 108 / `flat-merge` 104 were overwhelmingly test cells). The
**production** census (123 `net-new-cell` sites, all argument shapes):

| merge | sites | kind | A-2 status |
|---|---|---|---|
| `merge-hasheq-replace` (`infra-cell.rkt:141`) | 23 | per-key last-writer-wins over a hasheq | **not a join unless each key is written once or monotonically — audit** |
| `term-merge`, `solver-term-merge`, `logic-var-merge` | 9 | unification result | join on the term lattice; **the hot solver path — thousands of cells per query from 1 site** |
| `merge-list-append` (`infra-cell.rkt:166`) | 6 | `append` | **non-idempotent, order-dependent — audit** |
| `type-unify-or-top`, `msg-lattice-merge`, `session-lattice-merge`, `choice-lattice-merge`, `rrb-embedded-merge`, `eff-pos-merge`, `io-state-merge` | 29 | structured lattices | joins by construction (to be table-checked) |
| `cap-set-join`, `merge-set-union`, `counter-merge` (= max), `hasse-merge-hash-union` | 7 | set / max | joins, flat-representable |
| `merge-replace` (`infra-cell.rkt:199`, "non-monotonic per-clause narrowing") | 1 | replace | **not a join — by design; must sit at a stratum boundary** |
| other (`generic merge`/`merge-fn` passed in, registries, decisions/commitments/assumptions/nogood) | ~48 | various | table-check |

Two consequences for D.1. (1) The genuine A-2 audit items are `merge-list-append`,
`merge-hasheq-replace` and `merge-replace` — 30 sites, all in infra cells (registries, warnings,
narrowing), i.e. most likely written at topology/elaboration time rather than in the S0 hot
loop; the audit must say which. (2) A static site count cannot decide the storage tier: one
`logic-var-merge` site allocates thousands of cells per query. The flat tier's coverage is
therefore **unknown until the dynamic census (A-13) runs** — and the flat tier is likely to be
justified by the *solver's* cells (logic variables, tagged entries, decision bitmasks), not by a
percentage of source sites. The Stage-2 document carries a correction note pointing here.

## 6. Gaps that remain (neither corpus nor survey closes them)

- Serialization of flat tiers (`.pnet`) — nothing in-house or external beyond "rebuild at load".
- Interning / hash-consing for structured lattice values (Q3) — adjacent prior art in the LHC
  cell band (`…_STAGE1_B2_CELL.md:1333,1554`, Salsa generations); a later track.
- A verified statement of Racket 9's memory-model guarantees for `memory-order-acquire/release`
  on `box`/`fxvector` stores (the DIRECT protocol relies on them; measured to work, not read from
  the docs) — D.1 must cite the Racket reference section.
- Numeric cross-core latency for Apple M5 Max from an independent source (ours stands at ~60 ns).

## 7. Bibliography

Our documents: see the prior-art draft §6 (twenty entries with line ranges). External: see the
frontier draft §5 (forty entries with DOIs/URLs; §4 there lists the ten that could not be fully
verified — Cousot RR-88 body, B–T 1989 Prop 6.2.1 text, Concurrent Revisions body, Chandy–Misra,
Dijkstra–Feijen–van Gasteren, Hennessy–Patterson chapter, AnandTech/chipsandcheese numbers, Radul
& Sussman TR-2009-002, Bloom^L).
