# BSP-LE 3 — Log

Append-only, newest at the bottom. Entry shape: `### <outcome headline> — \`hash\` (date)` with **Why / decision**,
**Surprise / correction**, **Next** (`docs/tracking/principles/DAILIES_METHODOLOGY.org`). The log is named
`LOG_BSP-LE_3.md` by owner decision (2026-10-19, BSP-LE only); it was `BSP_LE_3_LOG.md`, after the convention
`{SERIES}_{TRACK}_LOG.md`, until the series move (`18b94286`).

**Earlier history** (before this directory existed) lives in the documents that moved here with the series: the
BSP-LE master
(`docs/tracking/tracks/BSP-LE/2026-03-21_BSP_LE_MASTER.md`, §Track 3), the Track 3 seed
(`docs/tracking/tracks/BSP-LE/BSP-LE_3/2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md`), and DEFERRED's two Rel T1 scaffolding sections. The track
had no design and no commits.

### BSP-LE 3 opened, with Stage A (the ATMS label semantics, DEFERRED 177's fix) placed first by owner decision (PAR 4 O-17 (a)) — docs commit on the branch (2026-10-19)
- **Why / decision**:
  - PAR 4's D.3 critique found that the shipped ATMS solver returns answers DFS rejects. The defect is DEFERRED 177:
    three rows plus two more shapes, all schedule-independent and reachable with one `not` goal under `:auto`.
  - The owner asked to find the track that owns the fix, and to start it concurrently. No BSP-LE row held it, so the
    PAR 4 session posed the question as O-17.
  - The owner chose (a): *"Ok, with BSP-LE 3 (a). Good to generate the kickoff."*
  - Track 3's own design reads tables by support set (PUnify Part 3 §9.6), which is the same lattice as the fix's
    label read. Its retirement obligations, Check 3 and Check 4, need the same gating instrument, the DFS-vs-ATMS
    differential.
- **Setup** by the PAR 4 session:
  - PAR 4 checkpoint 3 (`dba9f502`, docs only) so that O-16 and O-17 are on main.
  - DEFERRED 177's addendum recording the decision (main `99cbd9f5`).
  - This worktree from main `99cbd9f5`, built with the limit: `.zo` equal to main's for `reduction`, `driver`,
    `propagator`, `relations`, `decision-cell` and `atms`. `timings.jsonl` copied.
  - The three probes behind 177 re-run on main's code: the same wrong answers.
- **Records**:
  - the kickoff [`2026-10-19_BSP-LE_3_KICKOFF.md`](handoffs/2026-10-19_BSP-LE_3_KICKOFF.md): the charter, the inputs, the
    contract with PAR 4, PPN 4C and PAR 4B, the method by stage, and Stage 1's differential and survey;
  - the series stub [`../README.md`](../README.md), which carries the proposed master and roadmap edits, unapplied.
- **Next**: a fresh session runs the kickoff's §0, reads in its §6 order, summarises back to the owner, and waits for
  confirmation before Stage 1's measurements.

### Session 1: §0 clean, read in the kickoff's order; the owner confirmed the Stage-1 plan with plan notes KN-1…KN-15 — docs commit on the branch (2026-10-19)
- **§0**: every expected value held (branch, build fingerprints, the three probes' lines). Drift: main had moved by
  docs only. Chat bound to the worktree (`state.db`: cwd = this worktree, branch `bsple3-tabling`). `BL-n` re-checked:
  0 uses, pattern power 3/3.
- **Why / decision**: the owner confirmed the summary and the plan, including the four points that needed a yes:
  *"Confirmed on points 1-4."* The plan notes are `KN-n` (0 prior uses; pattern power 3/3), defined here because they
  were first written in the chat:
  - **KN-1** W2-4 Q1(b) already ran forced ATMS against DFS on 17 programs (23 lines with an answer DFS rejects, 53
    missing, 60 unresolved or `unknown`, 10 other; `racket/prologos/benchmarks/par4/d3-wave2/W2-4/W2-4-return.json`,
    `q1-run.sh`). The kickoff's "W2-4 counted only the auto-routed queries" (§5.1) is inaccurate. Workload 1 opens by
    replicating Q1(b) on this tree.
  - **KN-2** The strategy override short-circuits the route at `stratified-eval.rkt:251`, before Check 3 and Check 4
    (`:292-293`), so forced-ATMS differences mix Stage A's mechanisms, Stage B's shapes and term-conversion `unknown`s.
    Every query carries its Check 1–4 flags; Stage A's gate is computed where Check 3 and Check 4 are false.
  - **KN-3** (owner yes) Route facts per query (goal, strategy, Check 1–4 flags, route) are recorded by an
    observation-only hook in `stratified-eval.rkt` on this branch. `par4-solve-routes` (`:181-184`) counts per file
    only. Whether the hook reaches main is decided at Stage A's checkpoint (precedent: PAR 4 O-10, CP-2).
  - **KN-4** Tier 1 (`:236-238`) and `:semantics well-founded` (`:226`) run before the strategy dispatch: those
    queries are "not routable", never "agree".
  - **KN-5** ATMS's NAF calls DFS's `solve-goal` for the inner provability check (`relations.rkt:200`, `:315`): the two
    legs are not independent on `not` goals.
  - **KN-6** (owner yes) Generated programs get a third oracle, the perfect model of the ground program over a finite
    domain (stratified negation; PRECEDENT to verify: Apt, Blair and Walker 1988; Przymusinski 1988). Generation is
    range-restricted; unsafe NAF is its own family. DFS-wrong cases it finds are filed in DEFERRED, not fixed here.
  - **KN-7** The comparator: `test-solver-parity.rkt` uses `list->set` (hides duplicates); W2-4's `compare.py` cannot
    parse nested maps and normalizes `_gNNN` only. A balanced-delimiter parser with canonical α-renaming; set
    equality (2B design §9 item 3) plus a multiset-only class.
  - **KN-8** (owner yes) Eight classes: agree, ATMS-extra, ATMS-missing, ATMS-unresolved, duplicates-only, ATMS-error,
    no reference, not routable.
  - **KN-9** A DFS depth abort (DEFERRED 153) kills the rest of the file: that file is re-run split into one query per
    process.
  - **KN-10** The 177 addendum's "control" `(pick ?x)(= ?y 1)(= ?x ?y)` (`DEFERRED.md`, the second table of 177's
    2026-10-18 addendum) is masked: the same shape with `2` gives ATMS `@[{:x 1, :y 2}]` against DFS `@[{:x 2, :y 2}]`
    (W2-7 Q6: `W2-7/w27-row2.out:7-8`). CONJECTURE: it agrees because 1 is `pick`'s first alternative. The generator
    closes each program under permutation of constants and clauses (a metamorphic relation); a correcting addendum on
    177 is owed with the Stage-1 record.
  - **KN-11** (owner yes) `:execution :sequential` runs ATMS under the drain (`stratified-eval.rkt:301`), and W2-6's
    model gives schedule-dependent wrong answers there (R7, R8): an ATMS-sequential leg on the workloads we author.
  - **KN-12** W2-6's files letter the fix parts differently from DEFERRED 177: W2-6 (b) = 177 (d), (c) = (e),
    (e) = (b), "row2" = (c). Records cite 177's letters.
  - **KN-13** The models specify the fix and do not model production: W2-7's model of today matches the solver on 6
    of 10 programs as multisets (`w27-row2-model.out`).
  - **KN-14** (Stage B) The seed's guard prototype narrows by AND-NOT on cell 1 between rounds, the write that row 1
    and PD-10 remove; Stage B re-derives it on nogoods, and reads PD-7 (synthesis `:352`).
  - **KN-15** (owner yes) Survey additions: Clark 1978 (NAF, floundering), Van Gelder, Ross and Schlipf 1991 (WFS),
    McKeeman 1998 (differential testing) and the metamorphic-testing literature.
- **Surprise / correction**: main moved by four docs commits during the session; one is PAR 4 D.3's DEFERRED 157
  addendum, which places 157(b) (the guard's retraction through cell 1's replacement merge, `relations.rkt:2353`) and
  PD-10 in Stage A, with row 1. Already inside Stage A's six parts; merged in at `6caca8d0`.
- **Next**: the series move the owner asked for in the same turn (next entry), then Stage 1.

### The BSP-LE series moves into `tracks/BSP-LE/` — `18b94286` + `5674e875` (2026-10-19)
- **Why / decision**: the owner, in the same turn: *"let's make sure to reorganize the BSP-LE series
  `docs/tracking/tracks` and organizing all of this work in the `BSP-LE/BSP-LE_3` directory; the log file should be
  `LOG_BSP-LE_3.md`, not just `LOG.md`."* The log was already `BSP_LE_3_LOG.md`, so the spelling was put back to the
  owner with the census, in one form of five questions (`logos-project-tracking`, `references/series-move.md`). The
  owner chose the recommended option on all five:
  - **naming**: `tracks/BSP-LE/BSP-LE_<N>/`, `LOG_BSP-LE_3.md`, new files `YYYY-MM-DD_BSP-LE_3_<KIND>.md`; BSP-LE only,
    other series keep their log names;
  - **scope**: the whole series in the PPN layout (`handoffs/`, `critiques/`, `audits/`), with the single-series
    research notes in `tracks/BSP-LE/research/` and symlinks back;
  - **basenames** of the moved corpus documents kept (a pure directory move);
  - **every** link or path to a moved file rewritten, from anywhere; raw run outputs stay as printed;
  - **landing** as a docs-only checkpoint to main once the link check is clean, with notes to PAR 4, PAR 4B and
    PPN 4C.
- **What moved**: 25 documents plus this track's kickoff, log and series stub (28 renames). Layout, counts and
  exclusions are in the `18b94286` commit message and [`../README.md`](../README.md). 348 citations rewritten in 87
  files, all in-line (271 / 271 lines). Links before = after = 3 964; broken 121 before and after; the after-set
  equals the before-set mapped through the move (0 missing, 0 new). Main was merged in first (`6caca8d0`, registers
  only) so that the move edits main's current DEFERRED and dailies.
- **Surprise / correction**:
  - **The inventory put to the owner missed a document.** It said 24; the move has 25.
    `docs/research/2026-04-07_BSP_LE_TRACK2_STAGE1_AUDIT.md` (header "Series: BSP-LE"; Track 2's Stage 1/2 audit)
    escaped because the filename scan covered `docs/tracking/` only and the header scan skipped files named BSP_LE. It
    moved with the other research notes, under the owner's "the research notes … into `tracks/BSP-LE/research/`".
  - **Not rewritten, by design**: the d3-wave2 agent returns (`raw/wave2-returns.json`, `W2-8/W2-8-return.json`) are
    verbatim records, the same principle as `racket/prologos/data/`. One absolute path into a former checkout
    location (`docs/research/2026-05-02_ARCHITECTURE_NOVELTY_SURVEY.md:557`) was already dead and is left.
  - The move tool (scratch: `move.py`, `verify.py`) first left one directory link in the series stub pointing at the
    old directory; caught by the before/after assertion and fixed before the commit.
  - `decision-cell_rkt.zo` changes with its comment-only edit (source positions), so its fingerprint no longer equals
    main's until the checkpoint lands; `reduction_rkt.zo` and `driver_rkt.zo` are unchanged.
- **Staleness found** (proposed, not applied; series stub item 1): the master's tracker row 0 (`:47`) still reads ⬜
  while the roadmap's BSP-LE row 0 reads ✅.
- **Next**: land as a docs-only checkpoint to main; notes to PAR 4, PAR 4B and PPN 4C with the new paths; the dailies
  STATE's corpus-layout line; then Stage 1.
