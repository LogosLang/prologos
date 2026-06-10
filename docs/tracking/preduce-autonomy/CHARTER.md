# PReduce Autonomy Charter

**Created**: 2026-06-10
**Status**: ACTIVE (experiment running) — this document is the standing directive for the autonomous PReduce loop
**Branch**: `preduce-autonomy` (worktree `/Users/avanti/dev/projects/prologos-preduce-auto`), based at main `d1586b15`
**Owner**: Zachary Larson (async review; not in the loop in real time)

---

## 1. Purpose

This is a deliberate experiment: drive the PReduce series (design AND implementation,
track by track) through a **fully autonomous, long-running loop**, using the project's
existing methodology — Design Methodology 5-stage discipline, Critique Methodology,
Design Principles, the Propagator Mantra, Language Vision — with the owner reviewing
asynchronously rather than co-designing in real time.

Two outcomes are being measured simultaneously:

1. **Object-level**: PReduce tracks closed with the same design quality and verification
   rigor as interactive sessions produce.
2. **Meta-level**: how far the autonomous process can be pushed before quality degrades,
   and WHERE it degrades. Degradation findings are first-class deliverables — record
   them honestly in the ledger and dailies; do not paper over them.

The known structural risk (named at charter time, to be watched): **self-administered
adversarial critique catalogues instead of challenges**. Every mitigation in §5 exists
because of this. If the mitigations fail, say so in the ledger rather than simulating
rigor.

## 2. Scope and sequencing

**In scope**, in order (sequencing amended 2026-06-10 per owner direction):

- **Phase A — footing. INTERACTIVE, not loop work.** The owner decided (2026-06-10)
  that Tracks 0.1–0.3 design closure happens as main-session co-design with the owner,
  per the workflow.md "design dialogue stays main-session + user-interactive" discipline.
  Status:
  - A.0 Housekeeping — ✅ DONE interactively 2026-06-10: TBGH research layer committed
    (main `c27bcc89`), grounding-audit staleness fixes committed (main `533bfcab`),
    branch rebased onto main. DEFERRED.md triage remains open (fold into A.1 opening).
  - A.1 Track 0.1 closure — interactive co-design (in progress).
  - A.2 Track 0.2 closure — interactive co-design.
  - A.3 Track 0.3 closure — interactive co-design.
- **Phase B — implementation tracks: THE LOOP'S ENTRY POINT.** Runs in Master order
  (Track 1 e-class substrate first), each track gated on its locked design from Phase A
  and on prerequisite verification. NOTE from the 2026-06-10 grounding audit: the
  tropical-fuel substrate is VERIFIED production-deployed (gate is satisfiable), but
  (i) `tropical-left-residual` has zero production consumers — Track 4's on-network
  wrapping is greenfield; (ii) the monotone-counter fast path is speculation-gated —
  Track 6 gets the slow path; (iii) the e-class cell's order/enrichment declaration has
  NO existing SRE realization — Track 1 needs new domain infrastructure per the locked
  0.1 design.

**Out of scope / hard stops regardless of autonomy level:**

- No commits to `main`. All work lands on `preduce-autonomy`. The owner merges.
- No retirement or production-default flip of `reduction.rkt` or any production path
  (Track 8 endgame is categorically owner-gated, even on this branch).
- No force-push, no history rewriting, no touching the owner's standups
  (`docs/standups/` is write-once/read-only per CLAUDE.local.md), no edits to
  `my_notes.org`/`my_notes.md`.
- No pushes to remotes, no PR creation, no external publication. Everything stays local.
- No edits to files outside this worktree.

## 3. Decision authority

The experiment is **fully autonomous through-and-through**: the loop decides and
proceeds rather than queueing on the owner. Reviewability replaces permission.
Every non-trivial decision gets a ledger entry (§6) with one of three labels:

| Label | Meaning | Examples |
|---|---|---|
| **ROUTINE** | Within established patterns; cite the precedent/principle | test layout, file naming, following an SRE-Track-0 analog |
| **SIGNIFICANT** | A real design choice between live options; ledger entry must show the options considered, the critique outcome, and the principle that decided it | lattice realization choices, stratum assignment, cell granularity |
| **OWNER-PROVISIONAL** | A decision the owner explicitly flagged for approval, decided provisionally to keep the loop unblocked | any owner-census point (see below) reached by the loop before the owner has settled it in Phase A |

Owner-decision census (per the 2026-06-10 grounding audit; most should be settled
during the interactive Phase A, shrinking this list before the loop starts):
RESOLVED — TBGH/GBT frame adoption (RATIFIED by owner 2026-06-10; commit `c27bcc89`).
OPEN — (1) NAC as first-class rule-schema field [gates 0.2]; (2) Track 0.1 deliverable
scope (Master row vs sketch reality) [gates 0.1]; (3) tree-vs-DAG cost + eager-vs-
saturate (+ e-class-size measurement gate) [shapes 0.2 + Track 1]; (4) direct-to-LLVM
vs region IR + extract-then-lower split [gates 0.3]; (5) effect-stratum posture against
comment-only Stratum 3 [gates 0.1 sub-model 5 + Track 7]; (6) refinement-order substrate
realization [gates 0.1 sub-model 2 + Track 1]; (7) S1 Q-shape + C3.e shared residuation
API merge + HVM2 benchmark ceiling [gate Tracks 4/2]; (8) collaborator timing
(naive-reducer-now vs rebases-later) [shapes 0.3 sequencing].

OWNER-PROVISIONAL rules: decide it, document the rationale AND the concrete reversal
path (what gets reverted/reworked if the owner overrules), tag the ledger entry
prominently (`⚠ OWNER-PROVISIONAL`), and structure subsequent work to minimize the
blast radius of a reversal (prefer designs where the provisional choice is an isolated
module/parameter, not a load-bearing assumption woven through everything).

## 4. Process fidelity — the methodology applies unchanged

All existing rules and process documents bind the loop exactly as they bind an
interactive session. Non-exhaustively, the ones most at risk of silent erosion:

- **DESIGN_METHODOLOGY.org 5 stages** per track: research → audit → design → implement → PIR.
- **Acceptance file as Phase 0** for every implementation track.
- **NTT model REQUIRED** in every propagator-track design doc, with correspondence table.
- **SRE lattice lens (6 questions)** for every lattice; **Mantra challenge** at every
  decision point; **Network Reality Check** (3 questions) before any "on-network" claim.
- **Progress tracker** in every design doc before code; tracker updated per phase.
- **Phase completion 5-step blocking checklist**; commit per phase; dailies update per commit.
- **Testing discipline**: check-parens after every .rkt edit; targeted runner (never bare
  `raco test`) after production edits; full suite as regression gate ONLY (read failure
  logs, never re-run to diagnose); three-level WS validation for user-facing syntax;
  benchmark after infrastructure phases; microbench-claim verification when a perf
  claim is load-bearing.
- **PIR per track** from the 16-question checklist, skeleton-first.
- **Validated ≠ Deployed**, **belt-and-suspenders ban**, **"pragmatic" ban** — all apply.
- **Master Roadmap + PReduce Master tracker updates** on design-doc and PIR events.

## 5. Replicating co-design and adversarial critique without the owner

This is the load-bearing section. Interactive sessions get design quality from the
back-and-forth with the owner; the loop must reconstruct that pressure from
independent agents and forced structure.

**5.1 Grounding before design.** Every design opening starts with the
`grounding-audit` workflow (HEAD-pinned read-only facets + completeness critic).
R-lens-verify its returned targets surgically before trusting. Never design from
memory of the code.

**5.2 Deliberative design rounds.** For each open-question cluster in a Stage-3
design, run the `design-options-panel` workflow (proposer grounded in code facts +
process docs → adversarial critic per P/R/M/S + mantra + red-flag phrases → synthesis
cross-check). The main loop then plays the OWNER'S role against the panel output:
its job in that turn is to CHALLENGE the synthesis — find the option the panel was
too kind to, ask "could this be MORE aligned?", probe perf tradeoffs — not to accept
it. Write the challenge and its resolution into the design doc.

**5.3 Minimum critique structure per Stage-3 design (before lock):**
- ≥ 2 full adversarial critique rounds by INDEPENDENT agents (fresh context, no
  shared conversation with the drafting context), at least one explicitly prompted
  to REFUTE the design's central claim and one running the P/R/M/S lenses.
- ≥ 1 principles-challenge round (each major decision: which principle does it
  serve; each workaround: red-flag phrase scan).
- The **2-column catalogue/challenge table** written into the design doc for the
  VAG — Column 2 (could this be MORE aligned?) must challenge at least one
  inherited pattern or the VAG re-runs. This is auditable evidence for the owner.
- Perf tradeoffs explored with MEASUREMENT where claims are quantitative:
  microbench before locking a perf-motivated design choice (Pre-0 discipline),
  re-microbench at phase close when the claim is load-bearing.

**5.4 Design lock.** A design locks when: critique rounds complete with all raised
issues resolved-or-explicitly-deferred (with reasons), the NTT model exists, the
bridge diagram passes the SRE lens, and the ledger entry records the lock with links.
Locked designs are still owner-reviewable; the lock means the loop may begin Stage 4
against it.

**5.5 Implementation delegation discipline.** Per workflow.md: novel-design
implementation is MAIN-LOOP work (the loop session itself edits, gates, commits).
Workflows/agents are for grounding, critique, mechanical migration over a discovered
work-list, and parallel read-only research. Agents that produce code return diffs;
the main loop applies them at known HEAD and runs the gates. Every agent reading
code must verify and cite the HEAD SHA it read against.

**5.6 Research escalation (added 2026-06-10, owner direction).** When design or
implementation hits a question whose answer lives in FRONTIER LITERATURE — not our
corpus, not our code — commission the `deep-research` skill (fan-out search +
adversarial verification + cited report). This charter IS the standing authorization
to invoke it. Triggers: an external claim becomes load-bearing for a design choice;
algorithm selection where the literature moved recently; novelty positioning before an
external-facing claim. Discipline: outputs land as `docs/research/` notes marked
AGENT-GENERATED with provenance (the 2026-06-02 sweep is the template); they are
recency-adjudicated and main-session-verified before binding (the same rule as panels
— research findings are search hits, not facts); cited into design docs by section.
Use for load-bearing unknowns, not curiosity — one commission per genuine question.
**Pre-seeded research queue** (already-known candidates, fire when their track opens):
(1) e-graphs with bindings under DEPENDENT types + QTT (Moss 2025 follow-ons; e-matching
under binders) — Track 2 Phase 3 / Q8; (2) HVM2 interaction-count methodology +
measurement harness — Track 2 design opener (the deferred benchmark-posture decision);
(3) DPOI confluence-decidability algorithmics (Bonchi et al. III) — Track 3;
(4) sharing-aware extraction (e-boost ILP, treewidth, sparse methods) — Track 4's
NP-boundary; (5) optimism-in-eqsat (Arbore-Cheung-Willsey) applicability to Q2
merge-under-partial-information — Track 1/4 seam.
**Owner-added lines (2026-06-10)**: (6) MULTI-DIMENSIONAL cost with tropical quantales —
e-class extraction under product/tensor quantale composition + the cost-model SELECTION
policy (which Q, where, when) — Track 4 design; substantial grounding EXISTS
(TROPICAL_QUANTALE_RESEARCH; addendum §4 multi-quantale NTT model) — commission a
deep-research only if Track 4's mini-design finds the existing grounding insufficient
for the composition decision, and scope it to the GAP. (7) Cross-module +
cross-compilation sharing of discovered e-classes / super-optimization RESULTS
(persistent superoptimizer caches à la Souper, distributed eqsat, content-addressed
optimization databases) — Track 5; extends the question-keyed store beyond per-module
sections. (8) Frontier DELTA sweep on e-(hyper)graphs, interaction nets, GoI — the
2026-06-02 sweep is the BASELINE; commission the delta (what moved since) before
Track 2's design opens. (9) FIRST-PRINCIPLES assessment of Petri nets, proof nets, and
bundled interactions against the lattice-propagator substrate — PRN/PTF-series theory
research, NOT PReduce-gating; commission on owner interest or when a design tension
suggests one of those frames fits better than ours. Standing framing (owner, 2026-06-10):
much of this work is green-field (lattice-based propagators as a whole), but everything
should be groundable in first principles and adjacent formal disciplines — synthesis
across those fields to ground and guide engineering is the UTM-FL programme's job, and
research commissions should serve that synthesis, not replace it.

**5.7 mempalace discipline (added 2026-06-10).** mempalace semantic search is part of
the STANDING grounding repertoire: query it at every design opening and before any
"this is new" claim (per the prior-art memory rule). ALWAYS recency-adjudicate hits
against the freshest committed source before handing them to panels — adjudicated
prior-art measurably cheapens rounds (validated SM4 + 0.3). Never treat a hit as
authoritative (the recency failure mode is documented in mempalace.md); the post-commit
docs hook keeps the palace fresh as the loop commits tracking/research docs.

**5.8 Measurement as a design instrument (added 2026-06-10, owner direction).**
PReduce carries a PERFORMANCE objective, not just an architectural one: the owner
reports ~50-60% of current execution time is spent in reductions (OWNER-REPORTED —
empirically baselined at iteration 0, see §7; that measured share becomes THE
denominator for every PReduce perf claim). Consequences:

- **Baseline first**: iteration 0 captures the reduction-share profile on the
  comparative suite + the standing baselines (`bench-ab.rkt --output`, timings.jsonl,
  micro-suite) BEFORE any substrate code lands. No perf claim without its denominator.
- **Pre-0 microbench as a DESIGN tool**: when a design choice is perf-motivated
  (storage strategies, T-FLIP, shape-P magnitude, cost-cell specialization), microbench
  the candidates BEFORE locking — the existing Pre-0 discipline, standing for Phase B.
  The already-pre-named gates (D5 probe + counters, T-FLIP thresholds, M1-M3, bite
  counters, shape-P re-microbench) are instances of this rule, not exceptions.
- **A/B at every phase close touching the reduction path**: `bench-ab.rkt --runs 10`
  vs the prior baseline (`--ref` for quick checks); suite-level 1.2×-rolling-median
  and per-file regression rules (testing.md) apply; never run competing A/B
  comparisons concurrently.
- **HONESTY ABOUT THE CURVE**: early tracks may REGRESS wall-clock — e-graph ingestion
  overhead vs direct recursion is the documented Cranelift trade (7-8% compile time for
  2% runtime). The measurement regime exists to keep that VISIBLE, not to panic on it:
  pre-named expectation — Tracks 1-3 are correctness + architecture (regressions
  bounded and recorded, never silent); the perf PAYOFF thesis validates at Track 4
  (cost-guided extraction on targeted patterns: constant folding, CSE, β-η per D.1
  §2.2's success criteria) and Track 5 (cross-session amortization). Claiming early
  and panicking early are the same mistake in opposite directions.
- **Track 8 endgame**: parity is necessary; PERF IS THE POINT. The retirement case
  must include the measured reduction-share improvement against the iteration-0
  denominator.

## 6. Coordination and persistence (the file spine)

The loop assumes **every iteration wakes up amnesiac**. All state lives in files,
in this directory (`docs/tracking/preduce-autonomy/`):

- **`CHARTER.md`** (this file) — re-read at the start of EVERY iteration. The owner
  may edit it between iterations; treat the on-disk version as authoritative direction.
- **`LEDGER.md`** — append-only decision ledger. One entry per non-trivial decision:
  date/iteration, label (§3), the decision, options considered, principle cited,
  reversal path (for OWNER-PROVISIONAL), commit hash where it landed. THIS is the
  owner's primary review surface — optimize it for auditability, not brevity.
- **`HANDOFF.md`** — living handoff per HANDOFF_PROTOCOL.org, REWRITTEN (not appended)
  at the end of every iteration: current work state, exact next step, open threads,
  gate status, anything a cold session needs to continue. The first action of every
  iteration after re-reading the charter is reading this.
- **`dailies/YYYY-MM-DD_dailies.md`** — the loop's own dailies stream (separate from
  the main-session dailies in `docs/tracking/standups/` to avoid collision; same
  format and discipline: update alongside every commit, "Carried forward" +
  "Watching" sections, creation-to-creation intervals).
- **Design docs, progress trackers, PIRs** — in their normal `docs/tracking/`
  locations on this branch, per normal conventions. The coordination directory is
  for loop mechanics only; real artifacts live where they always live.

Owner review path (written here so the loop maintains it): LEDGER.md first (decisions),
then current dailies (narrative), then design docs (depth), then `git log`/diffs (code).

## 7. Iteration mechanics

**Scope cap**: one sub-phase, one design-stage step, or one critique round per
iteration — whichever is smallest. Never start a second phase's work in the same
iteration. Small iterations are what make the ledger auditable and rewinds cheap.

**Phase B kickoff (one-time, added 2026-06-10)**: (0) owner merges `preduce-autonomy`
→ main; (1) the loop session starts IN the worktree (cwd = this repo copy) on a fresh
branch off merged main (or continuing this branch — owner's call at merge);
(2) **iteration 0 is a cheap shakeout** mirroring A.0: full-suite baseline run in the
worktree (establishes local green + timings entry), the §5.8 PERF BASELINE capture
(reduction-share profile on the comparative suite + bench-ab baselines saved with
--output — verifying the owner-reported ~50-60% reduction share empirically),
DEFERRED.md triage (the carried A.0 leftover), Phase B dailies file created — loop
machinery exercised before any production edit; (3) iteration 1 opens the implementation queue (HANDOFF order).
**The kickoff one-liner** (durable here so any session can restart the loop):
`/loop Execute ONE iteration of the PReduce autonomy experiment: read
docs/tracking/preduce-autonomy/CHARTER.md then HANDOFF.md, perform the single next
scoped unit per charter §7, run the gates, commit, update LEDGER + dailies + HANDOFF,
then continue. Halt per charter §8.`
(Dynamic /loop self-paces via wake-ups; each firing re-grounds from files by design.)

**Notification (added 2026-06-10)**: on any §8 halt/BLOCKED event and at each track
close, send a push notification to the owner (PushNotification tool) — the ledger
remains the review surface; the notification is just the doorbell.

**Budget posture**: full design panels are reserved for track/phase mini-designs;
sub-phase mini-audits use the cheaper grounding-audit workflow (workflow.md default);
single Explore agents for surgical verification. Token cost is not a hard constraint
(owner direction) but waste is still waste.

**Iteration template** (in order):
1. Re-read `CHARTER.md` (owner may have redirected) and `HANDOFF.md`.
2. Verify environment: correct worktree, branch `preduce-autonomy`, clean status,
   note HEAD SHA.
3. Do the one scoped unit of work, applying §4/§5 disciplines.
4. Run the blocking gates for that work type (parens → targeted tests → acceptance →
   suite at phase close).
5. Commit (conventional message, Series-prefixed references, no co-author tags).
6. Update LEDGER.md (if decisions were made), dailies, and the relevant progress tracker.
7. Rewrite HANDOFF.md for the next iteration.
8. Schedule the next iteration (or stop per §8).

**Failure handling**: follow the diagnostic protocol (workflow.md) — after 2-3 failed
attempts on the same problem, stop iterating and audit the domain. Read failure logs;
never re-run the full suite to diagnose.

**Context discipline (added 2026-06-10, owner question on context management)**: the loop
does not control compaction timing — it controls RECOVERABILITY. Rules: (i) bulk reading
lives in disposable agents/panels; main context holds distilled syntheses only. (ii) Every
verdict/decision is written to the design doc + ledger BEFORE the next deliberation opens —
never hold two undecided panels at once; settle→commit→next is the atomic unit. (iii) End
every iteration at a clean boundary (commit + handoff rewritten) so compaction between
units is harmless. (iv) After any compaction, re-ground from files in order: CHARTER →
HANDOFF → design-doc tracker → ledger tail — never from memory of the summary alone.
(v) If compaction lands mid-deliberation, the first post-compaction action is to re-read
the undecided artifact from its output file (panel outputs persist on disk), not to
re-run it.

## 8. Stop conditions

Halt the loop (write a BLOCKED ledger entry + final handoff, then stop scheduling)
when ANY of:

- 3 consecutive iterations fail the same gate with no new hypothesis.
- A decision is reached that genuinely exceeds even OWNER-PROVISIONAL — i.e., it
  would cross a §2 hard stop, or its reversal path can't be articulated.
- The prerequisite verification for the next track fails (e.g., `tropical-fuel.rkt`
  substrate not actually usable) and no other unblocked work exists in §2 sequencing.
- Evidence accumulates that critique quality has degraded to cataloguing (the §1
  meta-risk) and structural mitigation isn't working — halting WITH that finding is
  a successful experiment outcome, not a failure.
- The owner says stop (any message, or a charter edit).

When blocked on one thread but other §2 work is unblocked, prefer switching threads
over halting; record the switch in the handoff.

## 9. Experiment evaluation (meta-deliverable)

At each track close (alongside the PIR), append a short **autonomy retro** section
to the PIR: where the autonomous process matched interactive quality, where it fell
short, which mitigations earned their cost, what the owner had to correct at review.
At experiment end these aggregate into a dedicated retrospective for
DEVELOPMENT_LESSONS.org.
