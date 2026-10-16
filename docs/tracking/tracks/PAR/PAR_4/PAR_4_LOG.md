# PAR 4 — track LOG (append-only, newest at the bottom)

Entry shape = the dailies' (`DAILIES_METHODOLOGY.org`): `### <outcome headline> — \`hash\` (date)`
with **Why / decision**, **Surprise / correction**, **Next**. The dailies' STATE head stays the
re-grounding surface; its sparse LOG points here. Opened 2026-10-12 with the per-track-log
convention (`../../README.md`). Named `LOG.md` until 2026-10-15, when it was renamed `PAR_4_LOG.md` under the owner's
`{SERIES}_{TRACK}_LOG.md` convention; on `main` it keeps the old name until checkpoint 2.

### R3 measurement day, recorded first as the ad-hoc "PSF" probe series — no commit (2026-10-12)
- **Why / decision**: owner reopened the 2B parallel-search question ("a 1–10 ns switching
  primitive via FFI?"). Eleven probes answered it and found the real ceiling. Full text of
  the day's four entries is in `../../../standups/2026-10-12_dailies.md` LOG (headlines:
  *Semaphore floor reproduced; raw-memory handoff is ~60 ns* · *K-way fan-out ~1.8 µs/round;
  allocating work goes 9× SLOWER in parallel* · *Scaling is a function of allocation
  intensity; the solver is allocation-bound* · *Spin-pool prototype*). Consolidated as
  §1–§3 of [`research/2026-10-12_PAR_4_STAGE1_CONTENTION_ANALYSIS.md`](research/2026-10-12_PAR_4_STAGE1_CONTENTION_ANALYSIS.md).
- **Surprise / correction**: the session coined a series name ("PSF"). Series are
  owner-designated; this work is **PAR 4 Stage 1**, the row the PAR master already opened. Renamed;
  the dailies keep the historical headlines.
- **Next**: executor = (core, arena).

### Executor = (core, arena) measured; PSF-2 census; PSF-3 on the real tagged lattice — no commit (2026-10-12)
- **Why / decision**: owner's reframing (parallelism as scheduler technology; per-core
  executors as children of the scheduler) given its missing ingredient — an executor owns
  memory — and measured. Census: a light fire = 1.4 KB ceremony + 0.5 KB write + 0.9 KB
  re-merge; every written byte paid twice. Arena on the real `tagged-cell-value`: same
  fixpoint at every K and in DIRECT (async) mode; 95–131 ns / ~0 B per fire vs 1 500 ns /
  2.8 KB. Dailies LOG headlines: *Executor = (core, arena)…* · *PSF-2 — allocation-site
  census…* · *PSF-3 — arena executors on the REAL tagged lattice…*. Consolidated as §4–§5
  of the R3 record.
- **Surprise / correction**: three harness bugs (P ∤ K caught by the fixpoint check;
  heap baseline must delta-wrap writes; convergence counts canonical changes only) and one
  latent quadratic in the real lattice (entries never deduplicated) — R3 record §8–§9.
- **Next**: fire-weight sweep.

### R3 closed: fire-weight sweep — 7× at K=8, 13× at K=16 at today's fire weight — no commit (2026-10-12)
- **Why / decision**: PSF-3's "≥6× at K=8" prediction had failed on trivially light fires
  (3 reads + a max, ~24 ns), where per-executor cost rises with K on local data — a memory
  ceiling. Was it a design input or a footnote? `arena-tagged4.rkt` (DIRECT, quiescence,
  `WORK=` fixnum iterations per fire):

  | compute per fire | K=1 ns/fire | K=4 | K=8 | K=16 |
  |---|---|---|---|---|
  | ~0 | 24 | 2.4× | 2.2× | 2.9× |
  | ~100 ns | 112 | 3.9× | 4.7× | 8.5× |
  | ~1 µs (≈ today's fire) | 943 | 3.7× | **7.0×** | **12.8×** |
  | ~9 µs | 8 900 | 3.9× | 7.2× | 13.4× |

  Same fixpoint hash at every K and every weight. **Footnote**: at real fire weight the
  arena executor scales near-linearly (84 % efficiency at K=16). The memory ceiling matters
  only below ~100 ns per fire. R3 is complete; the record is
  [`research/2026-10-12_PAR_4_STAGE1_CONTENTION_ANALYSIS.md`](research/2026-10-12_PAR_4_STAGE1_CONTENTION_ANALYSIS.md)
  (§6 answers the PAR master's Challenge 1 directions; §7 is the candidate design for R5;
  §8 the deferred candidates).
- **Surprise / correction**: none in the data. Process: the track directory
  `tracks/PAR/PAR_4/` and this LOG were opened under the new per-track layout
  (`tracks/README.md`); the flat PAR master and `MASTER_ROADMAP.org` were NOT edited —
  the proposed Track-2 row edit and the Challenge-1 revision note are in
  `tracks/PAR/README.md` for the owner.
- **Next**: **R4** (literature survey — the PAR master names STM/WAL/FFI; R3 has answered
  those; the survey that now matters is chaotic/asynchronous iteration (Cousot, Bertsekas),
  LVars/Bloom (CALM) and partitioned graph engines (Pregel/GraphLab/Ligra) for the ownership
  cut) → **R5** (design doc). Owner's call whether R4 is a short note folded into R5.

### Design Methodology opened: the `R` labels retired, Stage 2 gap analysis written — no commit (2026-10-12)
- **Why / decision**: owner asked what the `R` designators are. They are the PAR master's
  own undefined labels (`2026-03-27_PAR_MASTER.md:32-33`), used once in the 2026-03-27
  dailies (lines 112–113) as five numbered research items of Track 2 (R1 round statistics,
  R2 the parallel PoC, R3 contention analysis, R4 survey, R5 design doc). They duplicate the
  methodology's stages and are never spelled out. **Retired** in this track's documents:
  work is named by Design-Methodology stage. The 03-28 dailies also record "R3–R5 closed as
  answered by implementation" while the master shows ⬜ — an inconsistency for the owner's
  master edit. **Owner ruling: PAR 4 "Arena Executors"** (the PoC track is closed; this has its own
  design/implementation/PIR, which is what a Track is). Directory and filenames renamed.
- **Stage 2** ([`2026-10-12_PAR_4_STAGE2_GAP_ANALYSIS.md`](2026-10-12_PAR_4_STAGE2_GAP_ANALYSIS.md)),
  grep-backed: 200 `net-cell-write` sites / 35 files; 210 reads; 107 `net-new-cell` sites with
  **66 distinct merge functions**; `fork-prop-network` only **5 sites / 2 files**; 186
  worldview sites / 9 files. Two facts reshape the design: (1) cells hold arbitrary values —
  so the arena is a **storage tier** (the 4 fixnum lattices = 47 % of allocation sites),
  plugged into the existing `specialized-cell-meta` seam (`propagator.rkt:1899-1982`), while
  the **scheduler half** (ownership, direct S0 writes, no snapshot/diff/re-merge) applies to
  every cell; (2) forking is rare in code — the ATMS layers bitmasks instead — so arena copy
  may be acceptable, pending a Pre-0 count. Seven gaps/questions each mapped to a Pre-0
  measurement or a D.1 audit; the load-bearing one is **Q1, round-synchronous visibility**
  (DIRECT mode makes same-round writes visible).
- **Surprise / correction**: the Stage-1 literature half is thin — R3 *names* chaotic
  iteration, LVars/CALM and Pregel/GraphLab but did not survey them. Owed as a short
  addendum before or alongside D.1.
- **Next**: owner rulings (track name; D.1 scope = both halves in one design, recommended);
  then **Stage 3 D.1** with the Pre-0 benchmark list from §3: fork frequency per query,
  elaborator bytes/µs, edge locality on real networks, solver parity under a DIRECT prototype.

### PAR 4 ruled; master + roadmap updated; Stage-1 research synthesis commissioned — no commit (2026-10-12)
- **Why / decision**: owner rulings: the track is **PAR 4 — Arena Executors**; the PAR master
  and `MASTER_ROADMAP.org` are to reflect it and be checked for staleness; a fresh Stage-1
  research synthesis (prior art + frontier) is required, grounded in fundamental principles,
  properly labelled, in the track's `research/` subdirectory. Done: directory + filenames
  renamed `PAR_2` → `PAR_4`; the contention record moved to
  `research/2026-10-12_PAR_4_STAGE1_CONTENTION_ANALYSIS.md`; `2026-03-27_PAR_MASTER.md`
  gained a 2026-10-12 revision note, a Track-4 row, the Track-2 "R3–R5" row corrected from
  ⬜ to "➡ Track 4" (the 2026-03-28 dailies had closed it as "answered by implementation";
  the master never recorded that), and §Challenge 1 marked superseded with the reasons;
  `MASTER_ROADMAP.org` §PAR status + planned-tracks table updated; all links checked (0
  broken). `tracks/README.md` + `tracks/PAR/README.md` updated.
- **Research**: mempalace is alive on this machine (CLI `mempalace search`, 94 984 drawers;
  the MCP is not wired into this session). Prior-art corpus sized: ~8 500 lines across
  `RESEARCH_PARALLEL.md`, the two `PARALLEL_PROPAGATOR_SCHEDULING` docs,
  `PARALLEL_ALGORITHMS_SURVEY`, `PARALLEL_DECOMPOSITION_AND_HASSE_ADJACENCY`,
  `MODULE_THEORY_LATTICES`, `LATTICE_HIERARCHY_AND_DISTRIBUTIVITY`,
  `LATTICE_FOUNDATIONS_PPN` (already states "chaotic iteration = propagator scheduling"),
  the hypercube BSP-LE addendum, `ASYNCHRONOUS_PROGRAMMING_QUANTALE`, and
  `2026-02-23_LATTICE_PROPAGATOR_RESEARCH`. Two isolated drafting agents commissioned in
  parallel, each with the owner's standards (first principles; prior examples critiqued
  against our own prior art; theorem/measurement/precedent/conjecture kept apart; every
  assumption testable and mapped to Q1–Q7 / Pre-0; citations web-verified or flagged):
  `research/…_STAGE1_PRIOR_ART_SYNTHESIS_DRAFT.md` (what the corpus concluded, what is
  reusable, what Stage 1 refutes) and `research/…_STAGE1_FRONTIER_SURVEY_DRAFT.md`
  (chaotic/asynchronous iteration — Chazan–Miranker, Cousot, Bertsekas, Üresin–Dubois;
  Tarski/ACC/widening; CALM — Ameloot et al.'s proof; LVars quasi-determinism; CRDTs and
  delta-state CRDTs; concurrent revisions; Pregel/GraphLab/PowerGraph/Ligra/Galois;
  Soufflé and Naiad progress tracking; Dijkstra–Scholten / Mattern termination detection;
  Valiant's BSP cost model; region-based memory management; coherence/false sharing;
  Radul–Sussman). The two drafts are inputs; the Stage-1 synthesis of record will be
  written by hand from them, critiqued, and will supersede both (drafts kept as record).
- **Next**: merge + critique the drafts into
  `research/2026-10-12_PAR_4_STAGE1_RESEARCH_SYNTHESIS.md`; then D.1.

### Stage 1 synthesis of record written; one commissioned finding withdrawn; Stage-2 census corrected — no commit (2026-10-12)
- **Why / decision**: both drafts read in full (prior-art 323 lines, 17-row inventory, R1–R15;
  frontier 478 lines, T1–T18, A-1…A-12, 40 verified citations, 10 flagged unverifiable). Merged
  and critiqued by hand into
  [`research/2026-10-12_PAR_4_STAGE1_RESEARCH_SYNTHESIS.md`](research/2026-10-12_PAR_4_STAGE1_RESEARCH_SYNTHESIS.md)
  (supersedes both; drafts kept as record). The two load-bearing claims are now theorem
  instances with hypotheses: S0 without a barrier = Üresin–Dubois/Bertsekas asynchronous
  iteration (A1–A3 + box + monotone inflationary + ACC; single-writer-per-cell IS hypothesis
  2(c)); barrier = stratum boundary = CALM's only-if (fixpoint detection is non-monotone), so
  quiescence detection replaces the barrier and gets its own Pre-0. **Q1 is re-stated as a
  theorem precondition**: every S0 *propagator* monotone in its inputs (A-1) — merge-is-a-join
  is necessary, not sufficient. New design elements from the survey: a frozen bit per flat
  record (LVars `freeze`); counter-scheme quiescence detection (Mattern/Naiad/LVish).
- **Surprise / correction** ⚠: the frontier draft's "18 `+`/`int-merge` cells are not
  semilattices" was traced to MY Stage-2 merge census, which had included tests/benchmarks;
  production count is **0**. Withdrawn. The same contamination sinks Stage 2's "47 %
  fixnum-representable sites" (also withdrawn; correction note added to the Stage-2 doc). The
  real production non-join merges are `merge-list-append` 6, `merge-hasheq-replace` 23,
  `merge-replace` 1 (infra cells) — the genuine A-2 audit. Second-order lesson: a static site
  census cannot decide the storage tier (one `logic-var-merge` site ⇒ thousands of cells per
  query); eligibility needs a **dynamic cell census** (Pre-0 A-13). Lesson for the skill: any
  grep census must exclude tests/benchmarks/tools explicitly and say so in the artifact.
- **Next**: **Stage 3 D.1** — design doc with: the two halves (scheduler / storage tier),
  region lifetimes (network/query/fork), the frozen bit, quiescence detection, and the Pre-0
  benchmark list A-1…A-13 (parity under DIRECT, dynamic cell census, fork frequency, cut
  locality, detection scheme, fires-to-fixpoint on fuel cells, elaborator bytes/µs).

### Stage 3 D.1 drafted — no commit (2026-10-12)
- **Why / decision**: [`2026-10-12_PAR_4_D1_DESIGN.md`](2026-10-12_PAR_4_D1_DESIGN.md). Two
  halves landable separately: **H-S** (scheduler: K as a cell, persistent parked executors,
  ownership from a topology-stratum partition, SPSC delta lanes, DIRECT S0 writes, counter-scheme
  quiescence detection replacing the round barrier, frozen bit) and **H-F** (storage tier: four
  flat record kinds behind `specialized-cell-meta-storage`, Tofte–Talpin regions per partition
  with declared lifetimes, compaction at topology, heap tier publishes by pointer store). Gates
  present: tracker at §3 with `P4.close`; NTT model §7; mantra audit §10; principles + codebase
  reality check §11 (file:line per phase, seam verified: `storage` has `'general` ×8,
  `'monotone-counter` ×1); termination §8; Pre-0 §9 with 7 performance axes + 7 semantic axes
  + parity skeleton `test-arena-parity.rkt`.
- **Surprise / correction**: the NTT model did its job — `exec-idle` as an or-flag with reset is
  a counter in disguise; the honest form is a monotone per-executor epoch counter (adopted for
  D.2). And `partition` as an LWW map is only legal because it is written at the topology
  stratum; the rule "no fire function reads `owner`" falls out.
- **Next**: owner critique → P0 measurements → D.2. Four owner questions in §14 (region
  lifetime default; fuel counting changes vs fires under DIRECT; observer form; scheduler state
  as its own network).

### D.1 rulings O-1/O-2/O-4 recorded; O-3 analysed (Appendix A); DEFERRED 146–149 filed; sweep worktree opened — no commit (2026-10-12)
- **Why / decision**: owner ruled O-1 (`:query` default, `:network` registries), O-2 (fuel
  counts *changes*, not fires), O-4 (scheduler state is its own network). O-3 needed the code
  read, not a guess: `current-bsp-observer` (`propagator.rkt:572`, called `:3429` per BSP round
  with a `bsp-round` carrying the per-round CHAMP snapshot) has six consumers (LSP
  `bsp-observe`, prop-observatory, trace-serialize, measure-production-n, bench-bsp-round-stats,
  two tests) and one deliberate non-consumer (error-explanation: provenance is on-network).
  Decisive fact: the **sequential scheduler already emits one `bsp-round` per quiescence call**
  (`:2599-2640`) — the contract is already "one record per scheduler-chosen unit". Options A
  (one record per S0 run under DIRECT) / B (write-indexed event log, rounds as a view) / C
  (retire) read adversarially against orthogonality, data orientation, on-network,
  decomplection, provenance, simplicity. Recommendation A in P3 + B filed as debt (it repairs an
  orthogonality violation A perpetuates), promoted into P3 if parity diagnosis needs the
  derivation partial order. Owner to rule.
- **Surprise / correction**: the four DEFERRED candidates noticed during Stage 1 (champ-lookup
  64 B/read; fire-protocol ceremony; tagged-cell-value non-dedup; transducer-01 under 9.3) had
  **not** been filed — only noted in the dailies. Filed as **146–149** (register → 150). Lesson
  for the skill: "DEFERRED candidate" in a log entry is not a filing; file in the same step.
- **Next**: owner rules O-3; P0. Parallel: DEFERRED 146–149 in worktree
  `.claude/worktrees/deferred-sweep-146-149` (nested, harness convention; branch
  `deferred-sweep-146-149`, base `7a0116ec`, compiled; first placed as a sibling dir — owner:
  no copies of the project outside git's view — moved with `git worktree move`); handoff `../../handoffs/2026-10-12_DEFERRED_SWEEP_146-149_HANDOFF.md`.

### P0 measured — small / medium / large, A/B against the pre-track record; the theory holds, the workload does not yet need most of the design, and the biggest wins are sequential defects — `4097b1c8` on branch `par4-p0` (2026-10-13)
- **Why / decision**: owner asked for comprehensive P0 — small and large, e2e, A/B against
  pre-track work, phase gates. Record: [`2026-10-13_PAR_4_P0_MEASUREMENTS.md`](2026-10-13_PAR_4_P0_MEASUREMENTS.md).
  Instrumentation + harness + parity skeleton + raw data committed on branch `par4-p0` (nested
  worktree), behaviour-neutral (PERF-COUNTERS identical to main on 5 files). Main untouched.
- **Results**: (1) theorems hold in our code — 40 random monotone networks × 8 schedules → one
  fixpoint; arena prototype same hash at every K and fire weight; every predicted divergence
  observed and pinned (9-test parity skeleton). (2) PAR 2's 1.42× does not reproduce (1.03×);
  same-machine A/B: HEAD 5.8× slower on wide networks; `git bisect` → `a7b015dd` (2026-04-15)
  set `current-tree-reduce-threshold` 256 → ~n green threads per wide round on the SEQUENTIAL
  executor; threshold off at HEAD 4.8–5.3× faster (DEFERRED 150). (3) S0 = 7 % of corpus work,
  but 85 % of command time in constraints-adversarial (merge ≥ fire; `pu-value-diff` 70 %).
  (4) search is DFS by necessity: forced ATMS gives wrong answers on all 3 solver files (Rel T1
  A.2b) — PAR 4's search payoff is gated on BSP-LE 3. (5) e2e short-file numbers are 90 %
  loading: `.pnet` read twice (DEFERRED 151); cache-off is 4.9× faster. (6) detection: scan
  beats rounds 3.5–12× on chains, ties on bursts; fire-weight sweep 7.3–7.7× K=8, 11–14× K=16 at
  ≥ 1 µs fires.
- **Surprise / correction** ⚠: (a) MY O-2 text claimed ascent counts are schedule-independent as
  a theorem — false (S-6: 1 vs 16); the BOUND is. Callout added to D.1 §14. (b) The sequential
  drain is not a DIRECT-K=1 oracle: whole-suite runs fail 27–30 files, ~25 from NO STRATUM LAYER
  (trait resolution `E1004`), 2 from BSP-only fire-once, 2 genuine (anti-monotone asc/desc;
  readiness → `merge-list-append` duplicate — A-2 in a production pattern). (c) My parity
  skeleton had two design errors caught by running it (a chain that never exercised `+`;
  divergence rows inheriting the environment's drain). (d) My detection probe's barrier had a
  double-flip race. (e) Five instrument defects filed (DEFERRED 150–155: tree-reduce, `.pnet`,
  forced GC, parity-adversarial crash, blind counters, benches dirtying the tree); one
  benchmark run overwrote PAR 2's tracked result in main — restored from HEAD, both kept.
  (f) D.1's 103 install sites are 130 (+2 APIs omitted).
- **DEFERRED register**: entries 146–155 are mine, still UNCOMMITTED in main's working tree; a
  concurrent session committed 156 and bumped NEXT FREE to 157 past them (`f3d7f5e3`) —
  consistent, but the block is only claimed by an uncommitted file until the owner commits it.
- **Next**: static Q1 monotonicity audit (delegated, pending) → D.2: land DEFERRED 150 (or pin
  B0′), acceptance file, H-S sequential path FIRST (DIRECT K=1 inside BSP's outer loop — the
  real oracle), H-F deferred until BSP-LE 3; phase gates per P0 §6.

### Q1 static audit landed — synthesis of record written; three judgements measured; Q1 is not clean and BSP is not an oracle for nine S0 cells (2026-10-13)
- **Why / decision**: the delegated static monotonicity audit (A-1/A-2/A-3) returned
  ([draft](2026-10-13_PAR_4_P0_Q1_MONOTONICITY_AUDIT_DRAFT.md), 651 lines, pinned `7a0116ec`).
  Read in full; 9 load-bearing claims spot-checked against the code (all hold); synthesis of
  record written by hand as [P0 record §9](2026-10-13_PAR_4_P0_MEASUREMENTS.md).
- **Measured** (`benchmarks/par4/q1-mechanisms.rkt`, branch `par4-p0`): BSP loses an update when
  two propagators write a cell undeclared in one round (2 vs 6); the guard shape loses a
  retraction **whether or not its output is declared** (4 vs 0) — the LWW cell-1 lattice is the
  defect, and the grow-only invalidated-bits lattice is correct under both schedules (6/6); a
  fire-once installed inside a fire loses fire-once (4 fires vs 1 productive); the drain's
  worklist does not dedup, so an inline installer installs twice.
- **Result**: 157 sites audited (144 call sites + 13 wrapper callers); 3 live non-monotone,
  8 absence-reading, 7 unstable latches; nine non-join merges written inside S0 (cell-1, scope
  cells, tagged cells, `:usage`, `:warnings`, cell-14, cell-15, meta-solution output, type cells
  via `type-unify-or-top`'s ambient read) — on those, BSP's answer is an artifact of its order,
  not a least fixpoint. Decision framed for D.2 (§9.6): (A) confine vs (B) make them joins —
  recommendation B, staged: P2 at K=1 needs neither; the lattice fixes gate P3.
- **Surprise / correction** ⚠: my "130 install sites" was a space-delimited grep (missed
  end-of-line calls) — the count is 144; withdrawn in §5. The audit's own proposed fix for the
  guard ("declare the outputs") was refuted by measurement. My §2.5 wording "A-2 in a production
  pattern … `merge-list-append`" named the test's merge; production's analogue is cell-14
  (`resolution-stratum-merge`, append) — reworded. D.1 errata callout extended (5 items).
- **DEFERRED**: filed 157 (lost update + guard lattice), 158 (in-fire install drops flags +
  duplicate install); register → 159. Still uncommitted in main alongside 146–155.
- **Next**: D.2.

### P0 input from the DEFERRED sweep: 2 of 7 tagged-cell domain merges are joins; SRE's type-domain ACI declaration is fail-open — no commit on main (2026-10-13)
*(Entry proposed by the DEFERRED-sweep session in its note §8 and applied here by the PAR 4 session, text as proposed.)*
- **Why / decision**: DEFERRED 148 (set semantics for tagged entries, `c62cd267` on
  `deferred-sweep-146-149`) raised the keyed-map question, whose precondition is an ACI domain
  merge. M1 measured that precondition. The owner placed F3 and M2 in PAR 4's early phases. Note:
  [`2026-10-13_PAR_4_P0_DOMAIN_MERGE_LAWS_NOTE.md`](2026-10-13_PAR_4_P0_DOMAIN_MERGE_LAWS_NOTE.md).
- **Surprise / correction**: `type-unify-or-top`'s meta fallback can *erase* a contradiction
  depending on arrival order, which is stronger than the audit's "non-commutative". `try-unify-pure`'s binder arms drop
  the unified body. The SRE type-domain ACI declaration targets `type-lattice-merge`, not the installed merge, and
  is confirmed by six ground atoms that cannot fail. D.1 §6.1's "closes `:453,465`" is stale (148 closed it at `:492`).
- **Next**: D.2 decides P0-8 (M2), F3(a) in the P0.5 defect list, and F3(b)/F1/F2/E as design
  items, before P2.

### Correction applied to the Stage-1 record: `champ-lookup` reads allocate 0 B, not 64 B — no commit (2026-10-13)
- **Surprise / correction** ⚠: my Stage-1 probe looked up freshly constructed keys, so its
  "64 B per read" measured Racket CS's `equal?` on records, not CHAMP (found by the DEFERRED 146
  fix, `69f64caf`; note §7a). Correction callouts added to the CONTENTION_ANALYSIS (`:184` item,
  table row `:95` kept as the probe's raw output) and the RESEARCH_SYNTHESIS row; D.1 §6.1's
  `'flat-tagged` row updated for DEFERRED 148. The argument for owner-held records rests on the
  write side (path copy 492–1 147 B per new-key insert), which stands.
- **Lesson** (for the probing skill): a lookup probe must use the *stored* key object, or report
  stored-key and fresh-key rows side by side — production keys are `eq?`.

### Owner decisions O-5/O-6/O-8 + topology guidance G-1; the unstratified in-fire topology path is unreached by the whole suite — `fbd5a322` on branch `par4-p0` (2026-10-13)
- **Why / decision**: owner accepted the phase order (O-5: P0.5 → P0-8 census → **P1 merge
  laws** → P2 → P3; P4/P5 co-designed with BSP-LE 3, which may start after P1), placed the
  worldview lattice in PAR 4 P1 with BSP-LE 3 as consumer (O-6), and tracks the merge-laws note's
  five items as PAR 4 tracker rows (O-8). O-7 (F3(a) timing) awaits this session's lean. Recorded
  in D.1 §14 (renamed "questions and decisions"; the owner's D1–D4 labels mapped to O-5…O-8 to
  avoid colliding with "D.1").
- **Guidance G-1** (owner): creating propagators during propagation is a topology change and needs
  a stratum — "a maze whose walls change mid-solve". Read against the code: BSP has a stratified
  mechanism (topology requests → topology tier after S0 quiesces) and an unstratified one (inline
  in-fire structure → installed between rounds of the S0 inner loop, `propagator.rkt:3372-3377`).
- **Measured** (counter + `PAR4_TRAP_MIDRUN=1` trap, branch `par4-p0`): 0 in-fire structure on
  the corpus (682 rounds) and forced ATMS (297 rounds); **full suite green with the trap armed**
  (10 257 tests / 489 files); the trap fires on the M4 probe's deliberate in-fire install (power
  check). The unstratified path is dead in production under BSP.
- **Surprise / correction** ⚠: my previous reply's integration point §3.4 ("every executor needs
  158 fixed and topology changes made by request") treated 158 as a defect to repair; G-1 shows it
  is a mechanism to retire. DEFERRED 158's fix shape revised (retire; in-fire structure becomes an
  error; requests carry the full propagator spec). P0 record §9.8 added; §9.5 reworded.
- **Next**: O-7 lean given in reply; D.2.

### O-7 decided: F3(a) lands now, standalone, in the DEFERRED-sweep session — no commit (2026-10-13)
- **Why / decision**: owner accepted the lean — fix `try-unify-pure`'s binder arms before D.2,
  one commit, TDD against the `aci-laws.rkt` cases, with a before/after law check (testing the
  merge-laws note's prediction), full suite and corpus A/B. F3(b) stays a P1 design item.
  Task written as an addendum to the sweep handoff, queued behind its current item (147).
- **Next**: D.2.

*(The next two entries were proposed for this LOG by the DEFERRED-sweep session — in its merge note
`docs/tracking/handoffs/2026-10-13_DEFERRED_SWEEP_146-149_MERGE_NOTE.md` § 148 and § F3(a) — and are
applied here verbatim by the PAR 4 session on 2026-10-13, after the fact; the 148 entry predates
several entries above.)*

### DEFERRED 148 closed on the sweep branch; pair-dedup does not bound the heap baseline's chain — `c62cd267` (2026-10-13)
**Why / decision**: the heap baseline's growth was two things — duplicates (closed) and an
ascending chain per bitmask (not closable by any set-of-pairs form, flat or heap). D.1 §6.1's
flat record inherits the second; D.2 should pick the lattice (pairs vs bitmask-keyed join)
deliberately. **Surprise / correction**: the entry's cited sites were dead code; the live
site was the third. The "300 s" figure does not reproduce (2.5 s). **Next**: 146.

### F3(a) landed (O-7): binder arms return the unified body — `5ec697bf` (sweep branch, 2026-10-13)
**Why / decision**: O-7. `close-expr` (the inverse of `open-expr`, generic fallback per pipeline.md) plus the four
arms; 11 tests, mutation-checked per arm. **Surprise / correction**: the note's prediction "none of the C violations"
is refuted. C also fell (D1c 74→28, D1d 251→187, tagged(D1) 432→366), and F3(b)'s published witness needed both
defects (replaced: `(Bool ⊔ Pi(?m,Nat)) ⊔ Pi(Nat,?m) = Bool` vs `type-top`). The fallback is duplicated
(`type-lattice.rkt:172-173` and `:217-218`). In the suite the defect changed 97 of 881 binder merges with no test
observing it; the comparative corpus never reaches the arms, so it cannot serve as P2's evidence for merge-law work.
**Next**: D.2 decides F3(b) at both sites, against the new witness; P0's corpus needs a program that reaches
binder merges with unsolved metas.

### PAR 4 moved to its own branch + worktree `par4-arena-executors`; P0's timing rows re-measured on a verified limited build — and P0's "S0 = 7 %" headline corrected to 24–30 % — `3d9a208f` (2026-10-13)
- **Why / decision**: owner — move this work to its own worktree/branch under the new process
  (branches in nested worktrees; main receives periodic, tested checkpoint merges), and check the
  merge-laws note §7 and the git log for other sessions' work. Branch `par4-arena-executors` created at
  `3643f56e` (= `par4-p0` with main merged in twice by the sweep session, owner decision (viii)); the
  worktree moved to `.claude/worktrees/par4-arena-executors`; `par4-p0` kept as a frozen pointer (records
  cite it). Branch gate: **10 339 / 495 all pass** (= main's 10 330 / 494 + the 9 parity tests). From here,
  PAR 4 documents and code change on this branch only.
- **Measured** (P0 record **§10**): build fingerprints match §7c's limited build. Medium tier, both legs
  limited (PAR 2 `ce4cde52` in a throwaway worktree vs B1 threshold 256 / off, interleaved ×3): DEFERRED
  150's effect **holds and is larger** — 6.0–7.4× (graph colouring 500: 9.20 → 1.25 ms; PAR 2 1.70 ms).
  Large tier: counts identical, S0 ms within 4 %.
- **Surprise / correction** ⚠: P0 §0/§2.2/§5 divided S0 by a window that is ~80 % the instrument's own
  two forced major GCs (DEFERRED 152 — which this track filed, and then measured through). Excluding
  them, **S0 is 24–30 % of corpus work** (not 7 %), corpus H-S + K=8 1.26–1.34× (not 1.06×); the per-file
  command-time models hold (1.49× / 1.35× H-S; 4.07× / 3.26× at K=8). Callouts added at each site.
  Also from the log: this track's four suite runs (00:56–01:04) predate the machine-wide `pkill` fix
  (`b45bbf44`, DEFERRED 163) and would have killed concurrent suites' workers. The F3(a) and 148
  entries the sweep session proposed are applied above.
- **Next**: D.2 — inputs now include §7b's fire-context decision, F3(b)'s two sites, the corrected value
  proposition, B1/B1′ as the P2 baseline pair, and an acceptance file that reaches binder merges.

### Relay to a fresh session: the two owner decisions the move left open are ledgered as O-9 / O-10; main is 57 commits ahead, one file overlapping — docs commit on the branch (2026-10-13)
- **Why / decision**: the owner continues PAR 4 in a fresh session from a relay note
  (`DAILIES_METHODOLOGY.org` §Relay Notes). Its grounding pass (obligation 4) found the two decisions
  the move/re-measure report put to the owner only in the chat, so D.1 §14 now ledgers them as
  PENDING: **O-9** DEFERRED 150's production default (lean: off) and **O-10** what the first checkpoint
  merge brings to `main` (parity test + harness certainly; the env-gated P0 instrumentation kept or
  stripped). O-3 (observers, Appendix A) is still pending too.
- **Surprise / correction**: none in PAR's records. `main` is 57 commits past the branch's merge-base
  `01ef2542` (PPN series move; SW-24/25/27 of the DEFERRED sweep, with DEFERRED 160 reopened as
  MITIGATED; register at NEXT FREE 172). Only `tools/dep-graph.rkt` changed on both sides: SW-24
  derives the graph by scanning for `test-*.rkt`, which makes the branch's two-line registration of
  `test-arena-parity.rkt` obsolete, so the next main→branch merge takes main's side.
- **Next**: unchanged — D.2 (P0.5), opening by posing O-9, O-10 and O-3 with the inputs listed above.

### Main merged in (third bring-up): gate 10 394 / 502 all pass; the one predicted conflict resolved to main's derived graph — `2b1e1e78` (2026-10-13)
- **Why / decision**: owner, at the start of the fresh session: pull in main's changes safely. Merged, never
  rebased (W-1; hashes are cited). Main `99c893d4` = 59 commits past the merge-base `01ef2542` (checkpoints 3–6
  of the DEFERRED sweep, PPN 4C checkpoint 1 with the PPN series move, CIU 6 dailies).
- **Measured**: the merged tree differs from main in exactly the branch's own 135 files, each identical to
  `ea63c032`; `tools/dep-graph.rkt` is main's (the derived graph lists `test-arena-parity.rkt`; `update-deps
  --check` passes). Built with the limit; `reduction` / `typing-core` / `macros` / `elaborator` / `driver` `.zo`
  equal main's checkout byte for byte (`propagator` differs by the P0 instrumentation). Gate `--all
  --force-rerun`: **10 394 tests / 502 files, all pass** = main's 10 385 / 501 (SW-25 gate) + the 9 parity tests,
  the predicted delta exactly. The harness runs (`p0-profile.rkt stats` smoke run on `bool-logic`).
- **What main changes on this track's measured path** (in the merge message too): DEFERRED 152 means the P0
  harness's window no longer holds forced major GCs (smoke run `gc_ms` 1, was ≥ 51 on every file), so P0 §10.2's
  S0 share can be re-derived directly instead of bracketed; 151 (a)+(b) supersede P0 §0 item 5's 2.6 s load
  figure; SW-27 puts new per-`process-file` work (registry scope: 59 parameters + a forked registry network)
  inside the harness's window; 155 makes `demos-ab.sh`'s restore a no-op.
- **Surprise / correction**: the relay note counted 58 commits; main had gained one more (`99c893d4`, CIU 6
  dailies), touching no code. The runner's COUNT DROP line (`test-properties.rkt` 13 → 8 since `fd2986cc`) is
  main's `8014caef` (the test-library double count, removed before this branch was cut), not this merge.
- **Next**: summarise the track to the owner and wait for confirmation; then D.2 opens with O-9.

### O-9 decided (tree path off, then deleted in P0.5) and G-2 recorded; the evidence: the suite passes with it off, the prelude caches are identical, and a merge-order census explains why and finds order-dependence elsewhere — `eb25caee` (2026-10-14)
- **Why / decision**: owner accepted the summary and the O-9 lean: off, and delete the path. They asked first for
  the full suite with the default off ("it *should* pass if our architecture is actually CALM; if not, it would
  be a good indicator that there is more to fix"), and for the other evidence. They also gave guidance **G-2**:
  measure performance (memory, cycles/time, firings) and correctness, the latter in three layers — inductive
  (by construction: static analysis, types), co-inductive (runtime monitoring, dynamic checks, as needed),
  and testing. Both are ledgered in D.1 §14. The record is P0 **§11**.
- **Measured**:
  - Full suite under `PAR4_TREE_REDUCE=off`: **10 394 / 502 all pass**.
  - The 39 prelude caches, generated cold under 256, off and 0, are identical module by module.
  - A merge-order census (each BSP round applied flat / again / tree-combined / reversed to one snapshot) finds:
    - tree vs flat: **0 divergences** in 648 wide suite rounds, because no wide round carries an undeclared write;
    - a power row flips a program's answer 3 → 1 when the shape does occur.
  - Cold prelude elaboration: merge phase 3.03 → 0.020 ms and −7.7 MB per run, wall within noise.
- **Surprise / correction**:
  - The suite's pass was **predicted by structure**, so it is weak evidence for CALM. The census's reverse-order
    column R is the test that can fail, and it does: 249 of 12 527 multi-result suite rounds (2.0 %) and 26 of
    448 corpus rounds (5.8 %) end with different cell values. The merges involved are meta-solution output, the
    ready queue (cell-14), attribute-map facets and tagged cells. These are the Q1 audit's predicted rows, now
    measured in production.
  - Contradictions differ only in *which* cell is reported, never in whether one is.
  - Cold prelude elaboration runs only 4–5 BSP rounds; 1–2 of them are wide (the `process-file` route's widest
    is 368 fires, as DEFERRED 150 recorded).
  - My lean's second reason (a second merge order, chosen by round width) was stated as unmeasured. It is a real
    mechanism (power-T) that production does not reach (T = 0).
  - A power check of the cache comparison was itself zero-power: it overwrote a module that does not exist. It
    was caught by its 39/39 result and redone.
- **Next**: dailies + DEFERRED 150's status addendum on main; then pose **O-10** (first checkpoint contents),
  which now also covers keeping the census as a standing monitor (G-2).

### O-10 posed — what the first checkpoint merge carries; lean CP-2 "observe, don't select", now — docs commit on the branch (2026-10-14)
- **Why / decision**: owner: proceed. The tradeoff analysis is D.1 **Appendix B**: an inventory, the seven
  instruments one by one, the measured facts, options CP-1 (as is) to CP-4 (wait for P0.5), twelve worked cases,
  and the principles table. The **lean is CP-2**: before the merge, one branch commit removes the knobs that
  select a semantics (scheduler, solver strategy, tree threshold) and the in-fire trap and its counter; it keeps
  the merge-order census as an opt-in and gates the two always-on counters. Main gets the documents, parity test,
  harness and data. PENDING in §14.
- **Measured**:
  - **Cost when unset**: main vs branch on the medium tier, interleaved ×7, threshold off: 11 of 15 networks at
    0.95–1.04; four at 1.06–1.09×, inside noise at this n (constraint grid 8's ranges touch).
  - **Precedent**: main's production code reads exactly one env var, `PROLOGOS_MEMORY_STATS`, an observation
    opt-in.
  - **Demand**: no other worktree references any of the knobs.
- **Surprise / correction**: main's copies of PAR 4's documents stop at O-7. Main's P0 record still states "S0
  rounds are 7.0 %" without the correction, and DEFERRED 150's addendum on main cites a §11 that main's copy
  lacks. That is W-1 working as designed between checkpoints, but it argues against waiting (CP-4).
  Also: keeping a knob on the branch but not on main is not a stable state, because the next main→branch merge
  fast-forwards the branch to the checkpoint's tree. So withholding means a removal commit; the knobs stay in
  history at their pinned commits.
- **Next**: the owner's O-10 decision. If CP-2: the triage commit, the gate (predicted 10 394 / 502), a harness
  smoke run, then the checkpoint merge procedure (`branch-worktree-workflow.md` §4). Then O-3.

### O-10 decided (CP-2): the triage commit — the semantics-selecting knobs removed, the census kept, counters off by default; gate 10 394 / 502 — `a0b78fda` (2026-10-14)
- **Why / decision**: owner accepted CP-2. `propagator.rkt` and `stratified-eval.rkt` were rebuilt from main's
  copies plus only the census and the switch-gated fork/route counters. Main's code therefore differs from the
  branch's only by that observation code, and the P0 knobs stay in history at their pinned commits. Recorded in
  D.1 §14 and Appendix B; callouts added at P0 §8 and §11.8.
- **Measured** (`data/par4-p0/o10/triage-checks.txt`):
  - the census power rows are unchanged;
  - the harness's routes match P0 §2.4's;
  - the counters stay 0 for a plain `process-file`;
  - with `PROLOGOS_SCHEDULER=seq PROLOGOS_SOLVER_STRATEGY=atms` set, three files that failed under seq in P0 §2.5
    now pass, so an ambient setting no longer reaches the compiler;
  - the scripts that need a removed knob refuse with exit 2;
  - gate **10 394 / 502 all pass**, as predicted.
- **Surprise / correction**: one departure from B.4's wording. The counters are gated by an in-process switch that
  the harness flips, not by the census's environment variable; that removes a second ambient read. The census
  must reach the runner's workers, so it keeps its variable. Recorded in Appendix B's ledger line.
- **Next**: checkpoint 1 — merge the branch into main in a throwaway worktree, gate, reconcile file by file, then
  fast-forward main.

### Checkpoint 1: PAR 4 merged to main — gate 10 394 / 502, delta exactly `test-arena-parity` +9 — `c1f389ab` (2026-10-14)
- **Why / decision**: O-10 = CP-2, "now". Procedure: `branch-worktree-workflow.md` §4, in a throwaway detached
  worktree at main `7a13f566`:
  - recorded baseline run at main;
  - `merge --no-ff` of `3d5ecbc4`, limited build, recorded gate;
  - the message amended with the gate before main moved;
  - `merge --ff-only` of main's checkout and of this branch;
  - main's tree rebuilt with the limit, and the throwaway removed.
- **Measured**:
  - collision surface: none, against main's commits and against main's working tree (owner WIP untouched; 16
    entries before and after);
  - main before the merge: **10 385 / 501**; merged: **10 394 / 502**, all pass;
  - `suite-delta.py` over the two recorded runs: exactly `test-arena-parity.rkt` +9;
  - the merged `racket/` equals the branch tip, and the merged docs differ from it only by main's DEFERRED and
    dailies;
  - main's checkout rebuilt: `reduction` / `propagator` / `stratified-eval` / `driver` `.zo` equal this branch's
    build; `test-arena-parity`, `test-propagator-bsp` and `test-file-unit-isolation` pass in main's tree.
- **Surprise / correction**: none in the merge. Main's PAR 4 records, which stopped at O-7 with the uncorrected
  "S0 = 7.0 %", are now current. DEFERRED 150's addendum on main cites the merge (`67635edb`). No other branch
  touches the merged files (`ciu6-path-selection`, `ppn4c-elaboration-on-network` checked). Main is 27 commits
  ahead of origin; no push.
- **Next**: owner decision **O-3** (observers, Appendix A), then the rest of D.2. D.2's inputs are in §14 and P0
  §10–§11.

### O-3 re-posed: observation in logical time (lean OB-4, staged); five corrections to Appendix A; DEFERRED 176 filed — `4bd8e898` (probes + data) and the docs commit after it (2026-10-14)
- **Why / decision**: the owner opened O-3 for a deliberative decision. I re-grounded Appendix A at `2dd3ed70`
  (`racket/` = main `c1f389ab`) and added A.6–A.12, kept apart as measurement, theorem, precedent and taste:
  - corrections;
  - consumer census, corpus census and fixtures;
  - first principles;
  - options OB-1 to OB-5 (relabelled, since "A/B/C" collided with the appendix names);
  - eleven worked cases;
  - a principles table and the lean.

  **Lean: OB-4.** The user-facing trace is a function of the program: epochs everywhere, Kleene rounds on request,
  and the explanation from the fixpoint equation. Telemetry is per scheduler. P2 builds the BSP replay first, as a
  test-time parity monitor. Ledgered PENDING in §14 O-3.
- **Measured** (`benchmarks/par4/o3-observer-census.rkt`, `o3-observer-fixtures.rkt`; data `data/par4-p0/o3/`):
  - 303 of 672 BSP diff records (45.1 %) show a value the cell does not hold after the round; 283 of them are in
    fan-in rounds;
  - observing under BSP costs 0.995× wall and 1.000× allocation;
  - 364 S0 runs average 1.9 rounds each;
  - in all five fixtures, the changed set, the fired set and the fixpoint-equation contributions agree across
    schedules, while the named writer, the fire count and the round count do not.
- **Surprise / correction**: A.4's claim that write events "are scheduler-independent facts" was wrong (SC-1). A.1
  misread the record's `new` field (SC-2). The sequential scheduler's attribution is a placeholder (SC-3). The
  theorem that changes the question: BSP's rounds are the Kleene iterates (A.8 item 2), which the 2026-03-12
  visualization design had guessed. So BSP is the reference dynamics, and a replay needs only the epoch's starting
  state, not a log. Filed the observer's pre-existing defects as DEFERRED 176 on main (`bd7ef29d`).
- **Next**: the owner's O-3 decision. Its settling evidence includes the editor view's future (A.12). Then the rest
  of D.2.

### G-3 (owner): a visual debugger is a goal → O-3's lean refined (A.13); A.8 item 4 corrected — derivations need the rounds — `5fbb30df` (probe) and the docs commit after it (2026-10-14)
- **Why / decision**: the owner answered A.12's first settling question.
  - A visual debugger is a project goal, both to demonstrate the concept and as a practical
    debugging/introspection tool.
  - It is semi-abandoned and not in PAR 4's scope, but its needs shape the design.

  I recorded it as **G-3** in §14 and wrote A.13:
  - the requirements table: each need → the record that serves it → what PAR 4 provides vs DEFERRED 176 (c)/(d);
  - the critique of G-3, GT-1 to GT-6;
  - self-critique SC-9 and SC-10;
  - the refined lean.

  G-3 settles OB-4 against OB-5. Refinements: one shared key space (network, epoch, round); round records of
  (cell, old value, held value, writers, round); the execution view reserved, not built; eager epochs, lazy rounds.
  O-3 is still PENDING.
- **Measured** (`5fbb30df`, `data/par4-p0/o3/fixtures.out`): the fixtures now unfold each changed cell's final
  value into a derivation over rounds.
  - On X3's cycle the derivation is well-founded with no visited set or depth bound. It runs through intermediate
    values (c1@r3 ← p0 reading c0@r2 = (0 2)), which no fixpoint-only method can produce.
  - `error-explanation.rkt` cuts cycles with a visited set and depth 32 (`:164-195`).
- **Surprise / correction**:
  - (1) A.8 item 4 ("the explanation needs no trace") overclaimed (SC-9). The contributions need no trace, but a
    well-founded derivation on a cycle does. Corrected in place, struck through, and in A.10's note on row 9.
  - (2) My first derivation printer omitted the cell's own prior value as a premise, so X5's `top` named only p2
    and hid p1's 7. Fixed in the probe before committing. The lesson is now a requirement: round records carry
    the old value.
  - (3) A.12 item 4 ("OB-2's run trace is not built") was too strong under G-3: demonstrating order-independence
    needs an execution view (SC-10).
- **Next**: the owner's O-3 decision on the refined lean. Then the rest of D.2.

### O-3 decided: OB-4 as refined in A.13.4; O-11 ledgered; P0.5's three owner decisions made → D.2 drafting next — docs commit on the branch (2026-10-15)
- **Why / decision**: the owner: "Agreed with your reasoning and leans." Recorded **DECIDED 2026-10-15** in §14 O-3,
  in the A.12 and A.13 ledger lines and in Appendix A's callout. The date is the owner's reply; it came after
  midnight, the day after the 2026-10-14 commits.
  - The §14 entry places the consequences by phase:
    - P1 or P2: round records of (cell, old, held, writers, round), i.e. DEFERRED 176 (a);
    - P2: the shared key space, epoch records (176 (b)), records delivered as data, telemetry per scheduler, the
      BSP replay first as a test-time parity monitor, and the cost of keeping epoch start states;
    - P3: DIRECT telemetry, with the execution view reserved;
    - not PAR 4: 176 (c) and (d).
  - SC-6 (whether the observation request is a scheduler cell or a scoping parameter) is ledgered as **O-11**,
    PENDING, to be posed inside D.2 with the record schema.
  - §3's P0.5 row is now 🔄: O-9, O-10 and O-3 are made, and D.2 is drafted next.
- **D.2's inputs, gathered here so the draft starts from files, not memory**:
  1. **Phase order**, O-5: P0.5 defects → P0-8 exposure census → P1 merge laws → P2 DIRECT K=1 → P3 K>1; P4/P5
     co-designed with BSP-LE 3. §3's P1–P3 rows predate it, so D.2 rewrites the tracker.
  2. **The P0.5 defect batch**:
     - DEFERRED 150, the tree path deleted (O-9);
     - 157(a);
     - 158, the in-fire topology path retired (G-1);
     - an acceptance file that reaches binder-arm merges (P0 §10.3: the corpus reaches 0 of them, the suite 881).
  3. **The corrected value proposition** (P0 §10): S0 is 24–30 % of corpus work; corpus H-S + K=8 is 1.26–1.34×;
     per-file 1.49× / 1.35× (H-S) and 4.07× / 3.26× (K=8).
  4. **P1's merge-law plan** (merge-laws note §5): F1 bands, F2 facets, F3(b) at its two sites, E ("is a join" as
     a checked property), cells 14–15 and the worldview lattice (O-6). G-2's layers for each.
  5. **The fire context** (note §7b): `parameterize` ≈ 496 of a light fire's 928 B; a continuation mark or a field
     on the executor record costs 0 B. This also closes P0 §9.5's thread-inheritance hazard.
  6. **Baselines** for P2: B1 / B1′ (P0 §1.3). After O-9, B1′ (threshold off) is the defect-fixed baseline.
  7. **O-2's fuel restatement**: fuel counts changes, not fires, which closes `stratification.md:150-153`; P0-5's
     spread.
  8. **O-3's phase placement**, above, and **O-11**, to pose.
  9. **The owed measurement**: A-12, allocation-bounded scaling per fire at K > 1 (P0 §7).
  10. **BSP-LE 3's integration contract** (O-5: it may start after P1).
  11. **Carrying the corrections forward**: §14's O-2 and Q1-audit callouts, A-2's falsity for nine cells, A-8
      refuted for cell-1.
- **Surprise / correction**: none.
- **Next**: draft D.2 on the owner's go-ahead. Lean on placement: a new file, `…_PAR_4_D2_DESIGN.md`, with D.1 kept
  as the record of the first design. D.1's sections and its §14 ledger are cited by number from DEFERRED, the LOG
  and the dailies, and an in-place rewrite would move them. D.2 carries the live ledger, and D.1 §14 points to it.
  Then a P/R/M/S self-critique (`CRITIQUE_METHODOLOGY.org`) and the owner critique round.

### Process correction (owner): the track log is named for the track — `LOG.md` → `PAR_4_LOG.md` — docs commit on the branch (2026-10-15)
- **Why / decision**: the owner: "Log files should follow our {SERIES}_{TRACK}_LOG.md naming convention. Having 30
  files all named the same thing is unclear." Renamed with `git mv` in a commit of its own, so `git log --follow`
  keeps the history. Path-shaped citations were rewritten: the PAR stub README and the Stage-1 prior-art draft.
  Prose that states a past fact ("Not edited: `LOG.md`", merge-laws note §0, §8) was left as written.
  The owner also confirmed D.2 goes in a new file, and asked for an agent-driven adversarial critique of D.2 under
  `CRITIQUE_METHODOLOGY.org` once it is drafted.
- **Surprise / correction**: PPN 4C renamed its log on 2026-10-13, as part of the role-subdirectory decision, but
  to `PPN4C_LOG.md`, without the underscore that `{SERIES}_{TRACK}` implies (`1fe0ddf1`, on its branch). CIU 6
  still uses `LOG.md`. Neither belongs to this session, so the discrepancy goes to the owner via the dailies rather
  than being fixed here.
- **Main-side links** keep `PAR_4/LOG.md` until checkpoint 2 brings the rename. Checkpoint 2 must then rewrite:
  - the markdown links in `2026-03-27_PAR_MASTER.md` and `MASTER_ROADMAP.org`;
  - `tracks/README.md:53`'s example;
  - the dailies STATE pointer.

  It must also re-run `check-xlinks` over them. Historical dailies entries stay as written.
- **Next**: draft D.2.

### D.2 drafted (new file, owner) with its self-critique; the D.3 agent critique round planned — docs commit on the branch (2026-10-15)
- **Why / decision**: the owner confirmed D.2 goes in a new file, and asked that, once it is drafted carefully, an
  agent workflow critique it adversarially under `CRITIQUE_METHODOLOGY.org`. Three documents, all on the branch:
  - [`2026-10-15_PAR_4_D2_DESIGN.md`](2026-10-15_PAR_4_D2_DESIGN.md), the design of record. D.1 gets a "superseded"
    callout and stays as the record.
  - `critiques/2026-10-15_PAR_4_D2_SELF_CRITIQUE.md`: 19 findings under P/R/M and the SRE lattice lens; 13 applied to
    D.2, 4 open, 2 rejected.
  - `critiques/2026-10-15_PAR_4_D3_CRITIQUE_PLAN.md`: the proposed workflow. Wave 1 is ten critics (C1–C10); a
    triage; wave 2 is chosen from the triage (settlers, defenders, gap critics); the synthesis of record is written by
    hand. It waits for the owner's go.

  The `critiques/` subdirectory follows the 2026-10-13 role-subdirectory decision for new documents; nothing existing
  was moved.
- **The design sentence, revised**: S0 runs under the asynchronous-iteration hypotheses *by construction*:
  - join merges, from combinators or E-checked, with the rest fenced;
  - monotone fires, or fires in a declared stratum;
  - no topology change inside a fire (G-1).

  Given that, K executors own cells round-robin, write their own cells directly, send deltas to foreign owners,
  detect quiescence by a double-counted scan, and meet only at the stratum boundary. K = 1 is the same code.
- **Surprise / correction**:
  - (1) **The fire-side laws were missing from O-5's P1 list.** The Q1 audit's 8 absence-reading fires, 7 unstable
    latches and 3 live non-monotone fires are races at K > 1. D.2 adds P1b and poses it as O-13.
  - (2) **The fenced type cells may hold most of today's S0 work**, so the K > 1 models (4.07× / 3.26×, corpus
    1.26–1.34×) overstate the value realizable before PPN 4C. P0-8 now measures the type-cell share, and O-12 poses
    the fence.
  - (3) **D.1 A.13.4 item 4 placed the cost of keeping epoch start states in P2.** At K = 1 the persistent network
    makes it a pointer; the question belongs to P3.
  - (4) Self-critique **D2L-1**: the two-phase worldview fixes the merge, but its derived read is anti-monotone, so
    fires compute on labelled values and `live` is read only at boundaries.
  - (5) **D2P-3**: fire-once is legal only on a stable latch.
  - (6) **D2R-1**: the 11 `current-bsp-fire-round?` reads split 9 + 2, and the parameter is still deletable.
  - (7) The O-3 entry's "P2 measures the cost of keeping epoch starts" is corrected by (3).
  - Grounding: `racket/` production code is identical to main; every cited site was re-derived at HEAD (the audit's
    files are unchanged since `7a0116ec`).
- **Next**: the owner's go-ahead to launch wave 1, and O-11, O-12, O-13 (D.2 §15), which may wait for the critique.

### D.3 wave 1 launched: ten isolated critics (C1–C10) against D.2 — docs commit on the branch (2026-10-15)
- **Why / decision**: owner: "Let's do the first wave now." Every critic receives the briefing committed here,
  `critiques/2026-10-15_PAR_4_D3_WAVE1_BRIEFING.md`, verbatim. It contains the project summary, the reading list, the
  methodology's external briefing, the rules (read-only, probes in per-critic scratch, no rebuild, no suite, no
  `pkill`, evidence classes, power checks) and the JSON finding schema. Each critic also gets its own charge, per
  the plan's table. The charges are recorded in the synthesis when it is written.
- **Next**: triage of the returned findings by hand, then the wave-2 composition reported to the owner.
