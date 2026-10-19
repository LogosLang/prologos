# BSP-LE 3 — Kickoff: Tabling, opening with Stage A, the ATMS label semantics (DEFERRED 177's fix)

**Track**: BSP-LE Track 3, Tabling (SLG memoization). The row is
[`docs/tracking/tracks/BSP-LE/2026-03-21_BSP_LE_MASTER.md`](../../2026-03-21_BSP_LE_MASTER.md):55, and the scope section is
`:142-187`. On 2026-10-19 the owner placed DEFERRED 177's fix in this track as its first stage (PAR 4 decision O-17
(a)).
**Branch**: `bsple3-tabling`, worktree `.claude/worktrees/bsple3-tabling`, branched from main `99cbd9f5`, which is PAR 4
checkpoint 3 `dba9f502` plus DEFERRED's O-17 addendum. **Written at** that commit. Racket 9.3 CS, macOS, 18 cores
(6P + 12E).
**Log**: [`LOG_BSP-LE_3.md`](../LOG_BSP-LE_3.md).
**Series stub**: [`../../README.md`](../../README.md). The master stays flat; edits proposed to the owner are listed there.
**Siblings** (live in their own sessions): PAR 4 (`par4-arena-executors`), PAR 4B (`par4b-parallelism-portfolio`),
PPN 4C (`ppn4c-elaboration-on-network`), CIU 6 (`ciu6-path-selection`).

> This kickoff is a map, not authority. Re-derive every hash, count and `path:line` it quotes before relying on it.

---

## 0. Run first (expected values)

| check | command | expected |
|---|---|---|
| branch and tree | `git status -sb`; `git log --oneline -3` | `bsple3-tabling`, clean; HEAD = this kickoff's commit, parent `99cbd9f5` |
| main's moves since | `git log --oneline 99cbd9f5..main`, then the same with `-- '*.rkt'` | docs commits from other sessions. Any `.rkt` move means re-checking §7 and the sites in §3 |
| chat workspace | the desktop chip shows `bsple3-tabling` | if not: `desktop_project action=switch path=/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/bsple3-tabling` |
| build | `md5 -q racket/prologos/compiled/reduction_rkt.zo` | `6982d93d764d014744c47fe0efec91aa`. Built at creation with `PLT_CS_COMPILE_LIMIT=1000000`; `driver`, `propagator`, `relations`, `decision-cell` and `atms` also equal main's checkout |
| runner history | `racket/prologos/data/benchmarks/timings.jsonl` exists | copied from main at creation (gitignored) |
| **the defect is live** | `tools/scratch-run.sh racket/prologos/benchmarks/par4/d3-wave1/C9/c1-overwrite.prologos` (from the worktree root; one file per process) | lines `4: @[{:x 2}]` (ATMS) and `5: @[]` (DFS); `8: @[{:x 2} {:x 1}]` (ATMS) and `9: @[{:x 1}]` (DFS). Measured 2026-10-19 on main's code |
| the other two shapes | the same, with `…/d3-wave1/C9/c4-varvar.prologos` and `…/d3-wave2/W2-6/w26-crosssite.prologos` | c4: `4: @[{:x 1, :y 2}]` vs `5: @[]`. crosssite: `3: @[{:x 1, :y 1}]` vs `4: @[{:x 1, :y 1} {:x 2, :y 2}]`, and `5: @[{:x 1} {:x 2} {:x 1}]` vs `6: @[{:x 2}]`. The controls agree |

---

## 1. Charter (the owner's words)

- **The request** (2026-10-19): *"I'm wondering if we can find the track where fixing the ATMS solver is assigned (I
  believe it's in the BSP-LE series), and if we could start a kickoff on a new worktree/branch to start up that work
  concurrently, as we just did with the PAR 4B?... it seems like having that working would be a good capstone for some
  of this work in PAR..."*
- **The decision** (O-17 (a), 2026-10-19): *"Ok, with BSP-LE 3 (a). Good to generate the kickoff."* The analysis is in
  PAR 4 D.2 §15 O-17 ([`../../../PAR/PAR_4/2026-10-15_PAR_4_D2_DESIGN.md`](../../../PAR/PAR_4/2026-10-15_PAR_4_D2_DESIGN.md)).
  Its reasons:
  - Track 3's tables and the fix share one lattice.
  - One instrument, the DFS-vs-ATMS differential, gates both the fix and Track 3's retirement obligations.
  - It keeps the solver's correctness separate from PAR 4's speed work.
- **Standing guidance**:
  - G-2, *"we can't improve what we don't measure"*: correctness evidence in three layers, inductive, co-inductive
    and testing.
  - PAR 4's O-16 part 3: a budget exhaustion is a classified outcome, and **never a nogood inside a branch**
    (DEFERRED 184's solver half lands here).

So the track has two stages, and the first ends in its own checkpoint:
- **Stage A, the ATMS label semantics.** It makes the shipped ATMS solver give DFS's answers, and lands on main
  **before any tabling work**. This is the "capstone" the owner named.
- **Stage B, tabling as chartered**: table registry, producer/consumer propagators, SLG completion, and the retirement
  of Check 3 and Check 4. It is built on Stage A's lattice.

---

## 2. What is known: the inputs (cite them; do not copy)

| input | where |
|---|---|
| **The defect and the fix shape.** Three wrong-answer rows, three mechanisms, and fix parts (a)–(c). The 2026-10-18 addendum adds a wider reach (one `not` goal under `:auto`), two more shapes, and parts (d)–(f) (per-propagator viewpoint, lifted readers, premise set P). The 2026-10-19 addendum places it here | `docs/tracking/DEFERRED.md` §177 |
| The same fix written as design rows 1–3, with the ordering constraint (W2-6-3) | PAR 4 D.3 synthesis §5.7 ([`../../../PAR/PAR_4/critiques/2026-10-18_PAR_4_D3_SYNTHESIS.md`](../../../PAR/PAR_4/critiques/2026-10-18_PAR_4_D3_SYNTHESIS.md)); SC-24 and SC-30 in its §2; PD-1 and PD-10 in its §6 |
| **The lattice-level models**, which serve as the executable spec. W2-6: all six parts give DFS's answers on 8/8 rows under 3 schedules, and dropping any one breaks a row. W2-7: 10/10 when ⊤ under ev_W is read as the nogood of the joined labels | `racket/prologos/benchmarks/par4/d3-wave2/W2-6/` (`w26-label-soundness.rkt`, `w26-viewpoint.rkt`, `w26-premise.rkt`, `w26-combined.rkt`, `w26-parity-ext.rkt`); `…/W2-7/` (`w27-row2-model.py`, `w27-row2.prologos`, Q4–Q8) |
| The reach: `:auto` routes to ATMS on one `not` goal, or at ≥ 256 facts + clauses, unless Check 3 or Check 4 fires (`stratified-eval.rkt:253-293`). In-repo, 12 of 293 auto-routed queries take ATMS, and 460 solve lines match DFS | `…/d3-wave2/W2-4/` (`README.md`, `reach/`, `compare.py`) |
| The wave-1 probes (C9 red team; C4 read-side mechanism) | `…/d3-wave1/C9/`, `…/d3-wave1/C4/` |
| **A second writer of the worldview cell**: the S1 NAF handler AND-NOTs cell 1 while the projection also writes it. Row 1 removes it | DEFERRED §157, addendum 2026-10-18 (PD-10) |
| A budget trip inside a branch becomes a nogood today; the fix makes it a classified outcome | DEFERRED §184 (solver half); PAR 4 D.2 §15 O-16 part 3 |
| **This track's charter**: the retirement obligations (Check 3: body-local variables; Check 4: guards), the four table-format co-change sites, and the prototyped mechanisms | BSP-LE master `:142-187`; [`../2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md`](../2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md); DEFERRED §§ "Rel T1 A.2b DFS-routing scaffolding → BSP-LE Track 3" and "Rel T1 A.4 guard DFS-routing scaffolding" |
| **The shared lattice**: support-set tables. Unconditional answers have support ∅ and hold in every world; conditional answers are worldview-filtered. ⚠ It reads answers "consistent with W" (`:618`), which is weaker than label ⊆ W, and that reading admits 177's leak shape. Pin ⊆ once, for both uses | `docs/tracking/2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md` §9.6 (`:612-620`) and §9 |
| What shipped the solver, and the parity suite that could not see this (15 hand-built cases, `set-equal?`) | BSP-LE Track 2 design and PIR, Track 2B design (D.13) and PIR (`docs/tracking/2026-04-*_BSP_LE_TRACK2*`); `racket/prologos/tests/test-solver-parity.rkt` |
| Our TMS prior art | `docs/tracking/tracks/BSP-LE/research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md`; `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org` (Phases 5–6) |

**Theory the fix rests on** (PRECEDENT; verify each in its primary source during the survey):
- De Kleer's ATMS (*An Assumption-based TMS*, Artificial Intelligence 28, 1986): a datum holds in environment W iff
  some environment in its label is ⊆ W. That is fix (a).
- His consumer architecture (*Problem Solving with the ATMS*, same volume): consumers run on the union of their
  antecedents' environments. That is fix (e).
- Radul and Sussman's propagators carry supported values (a value plus its premises) read in a worldview, with
  contradictions becoming nogood sets (Radul, *Propagation Networks*, MIT PhD thesis, 2009). That is the nearest
  precedent on our own substrate.
- Today's tagged cells approximate all of this with first-match reads (`decision-cell.rkt:470`) and one network-wide
  bitmask. That is why the answers are wrong under every schedule.

---

## 3. Operating rules: the contract with the other tracks

1. **File ownership.**
   - This track owns production edits to `decision-cell.rkt`, `atms.rkt`, the solver paths of `relations.rkt`
     (`unify-fire` `:2112-2120`, the NAF handler `:206-354`, clause installation, `dissolve-solver-pu` `:2869-`),
     `stratified-eval.rkt`'s routing, and the solver tests.
   - **PAR 4 owns `propagator.rkt` and `driver.rkt`.** The fix needs three sites there; request each with an
     untracked note in PAR 4's directory (`tracks/PAR/PAR_4/YYYY-MM-DD_PAR_4_NOTE_FROM_BSP_LE_3.md`):
     - **the Tier-1 predicate**, `:3410-3430`. BSP takes the Tier-1 flush when the worldview cell is zero, so a fix
       that stops writing cell 1 silently skips dependent fires (W2-6-3, measured). PAR 4 owes a seam in its P0.5:
       "speculation present" is read from the assumptions or premises, not from cell 1. **Row 1 waits for that seam.**
     - the worldview projection, `install-worldview-projection` `:978-987`;
     - the tag gate in `net-cell-write/slow-path`, `:1993`, which is also one of Track 3's four co-change sites.
   - **PPN 4C** owns elaboration. The premise set P has to keep elaboration's commit-by-keeping-the-bit working
     (`meta-universe.rkt:257-263`). Send PPN 4C a note before any change reaches that path, and put elaboration's
     speculation tests in Stage A's gate.
   - **PAR 4B** shares no files with this track.
2. **Results flow only through main** (checkpoint merges) **or notes.** Never merge another track's branch into this
   one. Bring main in by merging, never by rebasing; hashes get cited.
3. **Registers.** DEFERRED numbers come from main's `NEXT FREE`, re-read at filing time, in a docs-only commit with
   `git -C`. The dailies keep one STATE bullet for BSP-LE 3 plus sparse pointers to this track's LOG. Track documents
   ride this branch (owner decision W-1).
4. **The decision ledger** uses the prefix **`BL-n`**: 0 prior uses in `docs/` and `.claude/` on 2026-10-19, with a
   power-checked pattern. Re-check before the first use. Pose owner decisions only at stage boundaries, one per turn,
   each with a full tradeoff analysis against `DESIGN_PRINCIPLES.org`. Four live sessions must not multiply the
   owner's load. Say "decision", never "ruling".
5. **Machine.**
   - Correctness runs need no lock, but run one heavy Racket process at a time while another session is timing.
   - Timing runs hold the suite lock (from `racket/prologos/`:
     `racket benchmarks/par4/hold-suite-lock.rkt tools/suite-lock.rkt <cmd>`).
   - Put `timeout -k` on every probe, and never `pkill` machine-wide.
6. **Evidence** (G-2).
   - Every claim is labelled THEOREM, MEASUREMENT, PRECEDENT, CONJECTURE or TASTE.
   - Every "0", "identical" or "matches DFS" comes with a power row.
   - **Comparing printed output has no power for this class**: the wrong answers are stable and
     schedule-independent, so PAR 4's order differentials cannot see them. Only an answer-set differential against
     an independent semantics can.
7. **Out of scope unless the owner places it here**: DEFERRED 182's override fix and O-16's surface keys. Their
   natural home is BSP-LE Track 5 (Solver Language, master `:203-213`).

---

## 4. Method (`DESIGN_METHODOLOGY.org`, per stage)

**Stage A**:
1. **Stage 1, measurement and survey.** Write `research/YYYY-MM-DD_BSP_LE_3_STAGE1_<TOPIC>.md`, with probes and
   `.out`s under `research/`. §5 below sets out the first move.
2. **Stage 2, gap analysis.** Every count is a grep measurement, power-checked, and excludes `tests/ benchmarks/
   tools/ compiled/`. Census:
   - every reader of tagged cells, and the callers of the first-match path;
   - every writer and reader of the worldview cell;
   - every `unify-fire` variant;
   - every place a contradiction inside a branch becomes a nogood;
   - the seams this design plugs into (`file:line`).
3. **Stage 3, D.1 with its mandatory gates** (`logos-project-tracking`, `references/design-doc-gates.md`):
   - an NTT model of the label lattice, written before the prose;
   - the mantra audit and the principles challenge;
   - a termination table;
   - Pre-0 on both axes: semantic (the differential) and performance (ATMS queries before and after, under the
     lock);
   - the parity skeleton.

   Then a critique round, and D.2.
4. **Stage 4, slices.** In this order:
   1. failing-first pins: 177's rows, W2-6's shapes and W2-7's Q4–Q8 as failing tests in `test-solver-parity.rkt`;
   2. the fixes that need no new machinery;
   3. the label machinery, landed inert;
   4. the switch-on;
   5. a verify round;
   6. merge main in;
   7. the full suite;
   8. **checkpoint Stage A to main**.

**Stage B**, tabling, opens with its own Stage-1 addendum and design. It reuses Stage A's lattice and its
differential (which deletes Check 3 and Check 4) and ends in the track's PIR.

---

## 5. First move: Stage 1 of Stage A

### 5.1 The instrument: a DFS-vs-ATMS answer-set differential, with power

**What it compares.** Answer **sets**, modulo order and α-renaming of fresh variables (gensym and meta numbering vary
between identical runs), with **named** solvers per strategy. Never use an inline override: DEFERRED 182 resets
`:strategy`, so `solve-with atms-s {:timeout 0}` silently runs DFS.

**The workloads**:
1. every in-repo `solve` / `solve-with` line in `examples/`, `lib/` and the `.prologos` fixtures, run under both
   strategies **forced**, not only as `:auto` routes them (W2-4 counted only the auto-routed queries);
2. the known rows: 177's table and addendum, W2-6's cross-site shapes, W2-7's Q4–Q8;
3. **generated programs**: small relational programs over a finite domain, built from facts, clauses with `=`,
   choice, var-var unification and `not`, with shapes calibrated against the in-repo census, so the generator is not
   rigged.

**Power rows**:
- a deliberate-error row: one answer dropped or added on one side, which the differential must flag;
- the known-wrong rows, which must flag on today's code;
- controls that must agree.

**A DFS failure is "no reference", not a mismatch.** DFS's depth limit of 100 (`relations.rkt:1110`, `:1189`)
aborts the whole file (DEFERRED 153, 182), so run one file per process (`tools/scratch-run.sh`) and classify each
outcome as: agree, ATMS-wrong, ATMS-missing, or no reference.

**Reuse first**: W2-4's `compare.py`, the `reach/` harness, and `test-solver-parity.rkt`'s helpers.

### 5.2 The reach census

- Which in-repo queries reach ATMS under `:auto`, and through which condition (`stratified-eval.rkt:253-293`).
- How many more Stage B would put on-network once Check 3 and Check 4 go.

This sizes the user-visible blast radius, and Stage B's.

### 5.3 The survey (prior art, critiqued against our design)

The sourcing procedure is `logos-project-tracking`, `references/research-sourcing.md`. Search with mempalace first.
- **Ours**: the inputs in §2.
- **Primary sources**:
  - de Kleer (1986, the three AI-28 papers);
  - Forbus and de Kleer, *Building Problem Solvers* (1993), on ATMS implementation;
  - Radul (2009) and Radul and Sussman, *The Art of the Propagator*;
  - LVars (Kuper) on threshold reads: the read at W must be monotone in the cell;
  - SLG resolution and XSB tabling with well-founded negation (Chen and Warren), and tabling with answer
    subsumption, both for Stage B;
  - de Kleer-style ATMS in answer-set and constraint solvers, as a counterpoint.
- State each theorem with its assumptions.

**The deliverable**: a Stage-1 record with the differential's table (every workload, every class, the power rows), the
reach census, the survey, and the questions Stage 2 must answer.

---

## 6. Read order

1. `docs/tracking/principles/HANDOFF_PROTOCOL.org` (hot-load), then the dailies STATE **from main**:
   `git show main:docs/tracking/standups/<latest> > $TMPDIR/d.md`, because the branch's copy goes stale.
2. This kickoff, then [`LOG_BSP-LE_3.md`](../LOG_BSP-LE_3.md) and [`../../README.md`](../../README.md).
3. DEFERRED §177 in full (body and both addenda), §157's 2026-10-18 addendum, and §184.
4. The PAR 4 D.3 synthesis: §0, §2 (SC-24, SC-30), **§5.7**, §6. Then PAR 4 D.2 §15: **O-17** and O-16 (part 3).
5. The BSP-LE master: the track table, §Track 2, **§Track 3**, §Track 5. Then the Track 3 seed and the two DEFERRED
   Rel T1 scaffolding sections.
6. PUnify Part 3 §9 and **§9.6**; the cell-based TMS design note; BSP-LE 2B's design (D.13) and PIR, read for what
   "parity" was taken to mean.
7. The evidence: `racket/prologos/benchmarks/par4/d3-wave2/README.md`, `W2-4/README.md`, then W2-6's models and W2-7's
   row-2 model.
8. Skills: `logos-project-tracking` (with `references/branch-worktree-workflow.md`, `design-doc-gates.md`,
   `deferred-filing.md`), `prologos-compiler-development`, `racket-performance-probing`.

---

## 7. Facts that outlast the kickoff (highest re-derivation risk)

- **The wrong answers do not depend on the schedule.** BSP, the drain and any executor give the same wrong sets, so a
  passing suite or a clean order-differential is no evidence here.
- **`:auto`'s routing** (`stratified-eval.rkt:253-293`): ATMS on a `not` goal in a clause of the queried relation, or
  at ≥ 256 facts + clauses, *unless* a reachable relation has a body-local variable (Check 3) or a guard (Check 4).
  Those two shapes go to DFS today, and Stage B is what brings them back.
- **BSP's Tier-1 shortcut** keys on the worldview cell being zero (`propagator.rkt:3410-3430`). That is PAR 4's site,
  and its seam comes in PAR 4's P0.5.
- **A fire that raises can hang production BSP** on rounds of ≥ 8 fires (DEFERRED 181), because the thread executor
  is installed at `driver.rkt:567` until PAR 4's P0.5. Put `timeout -k` on every probe that may raise.
- **An inline solver override resets every key it does not name** (DEFERRED 182), and **`:timeout` does not bind**
  (DEFERRED 184: fuel 0 returns full answers). Use named solvers in every probe.
- **DFS aborts the whole file at depth 100** (DEFERRED 153); `benchmarks/comparative/parity-adversarial.prologos`
  crashes for that reason.
- **Fresh-variable names vary between identical runs** (W2-5-3). Compare modulo α.
- **The scratch cache is pruned after 24 h.** Commit probes under this track's `research/`, never under `data/`: the
  pre-commit stdout-clean gate treats `data/` as production.

---

## 8. Your first response

1. Run §0 and report every drift from the expected values.
2. Read in §6's order. Say which documents you read in full and which only in part.
3. Summarise back to the owner:
   - the charter, and the two stages with Stage A's checkpoint;
   - the defect, with its rows and the six parts;
   - the contract, including the three PAR 4 sites and the Tier-1 seam;
   - your Stage-1 plan: the differential's workloads, classes and power rows, the reach census, and the survey list.

   Read the code behind each planned instrument first, and give whatever changes the plan as numbered notes, each with
   `path:line`.
4. Wait for the owner's confirmation before measuring.
