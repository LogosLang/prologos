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

**In scope**, in order:

- **Phase A — footing** (do FIRST, before any new design work):
  - A.0 Housekeeping: reconcile the PReduce Master's cross-references against the
    2026-05-09 substrate-research internal note §10 drift log; commit the untracked
    Track 0.1 architectural sketch (`docs/research/2026-05-02_PREDUCE_TRACK01_ARCHITECTURAL_SKETCH.md`)
    after verifying its content is current; DEFERRED.md triage for PReduce-relevant items.
    Low-stakes by design — it exercises the loop machinery (ledger, handoff, gates,
    dailies) where mistakes are cheap.
  - A.1 Track 0.1 closure — architectural sketch finalized through the full
    deliberative process (§5), including the NTT model (MANDATORY per workflow.md).
  - A.2 Track 0.2 closure — rule-property taxonomy.
  - A.3 Track 0.3 closure — `.pnet` extension + LLVM lowering interface design.
- **Phase B — implementation tracks** in Master order (Track 1 e-class substrate first),
  each gated on its design closure and on prerequisite verification (Track 1 gates on
  PPN 4C Phase 1B `tropical-fuel.rkt` — VERIFY the substrate actually shipped before
  consuming it; do not assume from docs).

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
| **OWNER-PROVISIONAL** | A decision the owner explicitly flagged for approval, decided provisionally to keep the loop unblocked | the three pre-flagged points from the 2026-05-09 engineering memo: (1) NAC support as first-class rule requirement, (2) C3.e shared residuation API as merge target with the Logic Engine, (3) HVM2 as Track 2 benchmark target |

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
