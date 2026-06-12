# PIR — PTF Track 2: Standalone Browser Visualization + Arbitrary-Program Trace Export

**Date**: 2026-06-12 (track opened and closed the same day, loop iterations 44–52)
**Design doc**: `2026-06-12_PTF_TRACK2_BROWSER_VIZ_DESIGN.md`
**Mode**: fully autonomous loop (PReduce-autonomy charter, re-armed), remote
ephemeral container
**Naming note (found at close)**: this track named itself "PTF Track 2" from
the driver's observatory comments ("PTF Track 1 Phase 0", driver.rkt:1062);
the Master's PTF (Propagator Theory Foundations) section independently plans a
"Track 2: Pipeline Detection". The Master row for THIS work is listed as
**PTF Track V (Visualization Tooling)** to disambiguate; the track's own docs
keep their internal name.

## §1 Stated objectives (Q1)

Owner direction (verbatim, the /loop re-arm): "generate a browser
visualization that can show the propagator network and play execution in
order to show how the system works for arbitrary prologos programs."

## §2 Delivered (Q2)

- `tools/viz-export.rkt` — headless CLI exporter: `.prologos` → vizTrace/1
  JSON (per-command topologies, epoch-bucketed timestamped rounds, per-epoch
  last-snapshot topologies, measured identity stack, bounded value detail,
  always-computed validation block).
- `tools/viz/index.html` — single-file dependency-free browser viewer:
  component-aware layered Canvas topology w/ self-loop arcs, zoom/pan/hover,
  D4 identity coloring with displayed coverage, epoch+round playback with
  fired/diffed highlighting and old→new diff attribution.
- `tools/viz/check.js` — headless node verification of the viewer's pure core.
- `tools/viz-capture-probe.rkt` — the Phase 0.5 instrument (kept; prints
  per-command errors, domain coverage).
- **One production edit**: propagator.rkt Tier-1 observer call (gap G3) —
  armed path per-fire champ-diff w/ attribution; unarmed byte-identical.
- Tests: `tests/test-viz-export.rkt` (7 golden checks), 3 Tier-1 observer
  cases in `tests/test-propagator-bsp.rkt`.
- Acceptance: `examples/2026-06-12-ptf-track2-viz.prologos` (17 commands,
  Level-3 clean; elaboration + pipelines + relations/solve + NAF).
- Phases: 0, 0.5, 1, 0A, 2a, 2b, 2c, T, 3 — all ✅ (9/9; Phase 4 riders
  adjudicated at close: 2 dissolved, 1 dormant, 2 deferred). Commits
  `5ef450a`..`10b0f4a` (~12 on the arc).

## §3 Timeline (Q3)

One day, 9 loop iterations: 44 grounding (5 facets + critic) → 45 env
shakeout + probe (Racket 9.0 wall found+fixed; F1–F7) → 46 design lock w/ 2
adversarial critics (2 BLOCKERs + 8 MAJORs adjudicated) → 47 acceptance file +
corpus audit → 48 full-suite baseline (8658 green after 9 env fixes) → 49
Tier-1 observer edit (suite 8666 green) → 50 exporter + golden test (all 2c
criteria pass) → 51 viewer shipped + delivered → 52 close. Design:impl ratio
≈ 4:5 iterations.

## §4 Deferred (Q4) — riders adjudication per data

- **Solve-boundary observatory hook**: DISSOLVED — the free path (per-epoch
  last-round snapshots) exposes solver topology (validated 2c).
- **A2 observer-site timestamps**: DORMANT — exporter-side bucketing
  validated on the corpus (monotone; captures==commands).
- **F4 production identity (panel revival)**: OUT OF SCOPE per locked PATH B
  — owner-queue material.
- **Compound-cell component diffs** + **D7 unpacking depth**: DEFERRED.md
  entries with pre-registered triggers (viewer users need sub-cell playback /
  deeper hash views).
- **Viewer layout upgrade**: trigger stands (>1k-node corpus graphs).

## §5 What went well (Q5)

- **Reuse over rebuild**: PTF Track 1's capture layer (observer, trace
  structs, serializers, observatory) carried ~70% of the exporter — the
  grounding audit found it before design, preventing a greenfield mistake.
- **The probe-first discipline**: every design claim that later mattered
  (edges exist; domains 55%; solver free path) was settled with DATA before
  or at lock, not discovered mid-implementation.
- **Independent adversarial critics on unfamiliar surfaces** found 2 genuine
  BLOCKERs the in-context draft missed (Tier-1 dropout; missing acceptance
  file) — the RETRO.md prediction about panels confirmed on first test.
- **Per-fire champ-diff in the Tier-1 observer**: reusing the PReduce-era
  shape-P infrastructure gave BETTER diff attribution than Tier-2's
  per-round diffs, at armed-only cost.

## §6 What went wrong (Q6)

- 2 acceptance-fixture syntax failures from trusting the syntax DOC over the
  implementation (`map [int+ 1 _]` partials fail inference; colon-form
  `spec` parses dependent w/ single-clause defn) — gate-caught, but each cost
  a diagnose-fix cycle. Why it seemed right: the doc is normative-looking.
- Bench PRE baseline launched concurrently with a compile — contaminated,
  killed, redone post-hoc (structural adjudication + clean A/A run).
- The stop-hook forced commits mid-validation twice (commit-then-fix chains);
  harmless but noisy history.

## §7 Where we got lucky (Q7)

- The relational runtime's solve path runs enough BSP rounds for snapshots to
  carry solver topology — the free path could plausibly have been empty
  (DFS-internal), forcing the production hook. The 2c validation would have
  caught it, but the schedule won the coin flip.
- apt's Racket 8.10 compiled the codebase cleanly enough to LOOK viable; the
  batch-worker crash surfaced `thread #:pool` before any wrong conclusions
  were drawn from 8.10 behavior.

## §8 What surprised us (Q8)

- **None of the corpus takes Tier-1** (4th falsified-workload premise): the
  critique's "simple programs trace empty" urgency was real-as-mechanism,
  wrong-as-workload. The fix stands on the unit tests.
- The LSP's own prop-trace capture path appears structurally dead (F7,
  server.rkt:553 post-unwind read) — production viz traces likely never
  worked via LSP at current HEAD.
- Container A/A bench noise: same-code runs register up to "15.3%
  significant speedup" — quantified and recorded as the local calibration bar.

## §9 Architecture hold-up (Q9)

Clean integration: ONE production edit (observer call in an existing
zero-cost-when-unarmed pattern), everything else read-side tools. The
cell/propagator/scheduler orthogonality held — the observation layer needed
no scheduler-specific coupling. Friction points: identity metadata
(elab-cell-info hollow post-universe-migration; cell-domains 55%) — the
network's OBSERVABILITY metadata lags its computation substrate, a real
finding for module-loading-on-network / PPN follow-ups.

## §10 What this enables (Q10)

- Demonstrating "how the system works" to outsiders with any program.
- A debugging instrument: per-round, per-propagator cell-write attribution
  (already finer than the VS Code panel's).
- The vizTrace/1 envelope as a stable boundary for future viewers (LSP panel
  could consume it; the schema is exporter-local but versioned).

## §11 Technical debt (Q11)

- Identity stack exporter-local (PATH B, decided not drifted) — fold-in
  reopens only via owner decision.
- `well-known-cells` table hardcoded in the exporter (mirror of
  propagator.rkt constants; cheap to extend, can drift silently).
- Viewer layout is BFS-layered, not Sugiyama — fine at ≤300 nodes, trigger
  registered for >1k.
- 3 doc-vs-implementation drifts flagged for owner (syntax doc map-partials;
  bench-ab `--ref`; spec colon-form) — not this track's scope to fix.

## §12 Do differently (Q12)

- Write the acceptance file at arc OPEN (the B1 blocker was a methodology
  rule the loop should not have needed a critic to catch).
- Validate fixture syntax against the IMPLEMENTATION (tiny probe run) before
  writing a long acceptance file, not after.

## §13 Wrong assumptions (Q13)

- "The capture pipeline is LSP-coupled" (it isn't — fully headless).
- "Subsystem coloring works" (hollow at HEAD).
- ".pnetx could be a topology source" (cell-state only).
- "Simple programs hit Tier-1" (not on this corpus).
Each was killed by grounding or probe data before it could shape code.

## §14 What we learned about the problem (Q14)

The visualization problem is 90% a CAPTURE-FIDELITY problem and 10% a
rendering problem. The interesting questions (which networks exist, which
runs are observable, what identity cells carry, how rounds map to commands)
all live on the Racket side; the browser side is straightforward once the
envelope is honest about coverage.

## §15 Right problem? (Q15)

Yes — the owner asked for exactly this, and the deliverable is the owner's
stated final goal for the re-armed loop. The deeper want ("show how the
system works") is served by the solver epochs + diff attribution; the
remaining gap to "fully pedagogical" is value rendering depth (D7 depth
rider) and DFS-internal solver steps, both named.

## §16 Longitudinal note (10 most recent PIRs)

This branch's recent PIRs (PReduce Tracks 1, 2, 4, 5, 3 — all 2026-06-10 —
plus this one) show a stable pattern set: (1) pre-registration + falsified
workload premises now appear in EVERY track (5th, 6th data points here —
the pattern is ripe and codified); (2) the gate-as-co-designer effect
(full-suite + Level-3 + golden tests catching what review missed) repeats;
(3) doc-vs-implementation drift is this arc's NEW recurring class (3
instances in one day across syntax doc, bench-ab header, spec parsing) —
candidate for a standing "docs are hypotheses, gates are facts"
DEVELOPMENT_LESSONS entry; (4) the panel-economy question from the PReduce
retro is now answered with both poles: skip panels on loop-authored
surfaces (43 iterations, zero panel regrets), run them on unfamiliar
surfaces (2 BLOCKERs found here).

## Autonomy retro (charter §9, this arc)

- **Matched interactive quality**: grounding→probe→lock→gate cadence held;
  every decision ledgered; the owner can audit 9 iterations from LEDGER +
  design doc §7 alone. The critique round did real work (the lock amendments
  were substantive, including overturning the loop's own "tools-only"
  safety posture).
- **Fell short / costs**: 2 syntax stumbles a Prologos-fluent human likely
  avoids; the stop-hook commit pressure produced commit-then-fix pairs; one
  process self-catch (concurrent bench) that discipline should have
  prevented outright.
- **Mitigations that earned their cost**: independent critics (2 BLOCKERs);
  measurement-before-lock (D4 downgrade); pre-registered fallbacks (all
  stayed dormant BECAUSE validation was designed in).
- **Environment**: the remote container is viable for the loop (Racket 9.0
  install + pkg links + recipe recorded); its bench noise floor (15.3% A/A)
  makes perf claims weaker here — push perf-critical phases to the owner's
  machine or demand structural arguments.
- **For the owner to correct at review**: browser acceptance of the viewer
  (no GUI here); the 3 doc-drift flags; the naming collision (PTF Track V);
  whether the deferred riders matter enough to schedule.
