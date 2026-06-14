# PReduce → Default + On-Network Compute/Recursion — Next-Session Plan

**Created**: 2026-06-14
**Status**: ⬜ PLANNED — design + implementation for the next session(s)
**Branch**: `claude/charming-archimedes-98yb48` (prototype for a future
propagator-native Prologos, built on the PReduce on-network-reduction prototype)
**Owner directive (2026-06-14)**: move PReduce to default and implement the
missing on-network functionality so the propagator network *genuinely computes*
(not just records). Commit in phases, incrementally.
**Companions**: `2026-06-14_PTF_VIZ_ROADMAP.md` (the viz side; this is its
Phase C made concrete) · `2026-06-12_PTF_TRACK2_BROWSER_VIZ_DESIGN.md` § BRANCH
DIRECTIVE · PReduce Master `2026-05-02_PREDUCE_MASTER.md` (the thesis this
advances) · `docs/tracking/preduce-autonomy/{CHARTER,LEDGER,HANDOFF}.md`.

---

## 1. Why this work, and what "done" means

The visualization surfaced a precise truth about the substrate (see the viz
roadmap): with on-network reduction enabled, the e-graph **records** each
reduction step as a `union` propagator (DPO rewriting — PRN §2 confirmed), but
the actual **computing** is still off-network functions:

- the per-step **value compute** (`377+233=610`) is `(apply + …)` inside
  `instantiate-template` (`rule-dispatch.rkt`), not a propagator;
- the **recursion driver** (`fib`→`fib`) is the recursive `whnf`
  (`reduction.rkt`);
- rule application is **atomic** inside `preduce-ingest-int` (intern → dispatch
  → union → its own `run-to-quiescence`), so the redex / rule-fire / result
  collapse into one observed round — you never see `int+(377,233)` as a live
  cell.

This plan advances the substrate toward the **PReduce thesis** (PReduce Master):
*"Reduction lifts entirely onto the propagator network … `reduction.rkt` is
retired in its entirety … rule application IS propagator firing … equivalence
classes ARE shared cells."*

**`done` for this work = the success criterion is the VIZ**: running a reduction
program through `tools/viz-export.rkt` shows the computation happening *as
propagation* across observable BSP rounds — a redex cell appears, a rule/compute
propagator fires, the result cell is written, values flow — with no decoder
overlays needed. For `parallel-reduction` the arithmetic shows as
`read-A,B → write-C` propagators; for `fib` the recursion shows as propagators.

**Out of scope (named, deferred)**: PERFORMANCE. The PReduce verdict (Track 3/4
PIRs) is that on-network reduction is wall-clock-FREE to *record* but memo ≤ cost
on the Racket substrate; the perf payoff routes through SH/Zig lowering. This
plan is about **architectural + visualization completeness**, not speed. Per
charter §5.8 (honesty about the curve): **wall-clock regression is EXPECTED and
ACCEPTED here**; measure it, record it, do not panic or optimize prematurely.

---

## 2. Methodology this plan binds to (repo conventions)

Every phase below follows the standing discipline — non-negotiable:

- **DESIGN_METHODOLOGY.org 5 stages** per phase that introduces new
  architecture (research → audit → design → implement → PIR). Phases that are
  pure flips/mechanical may compress, but must say so.
- **Grounding-audit opener** for each design phase (the `grounding-audit`
  workflow / HEAD-pinned read-only facets) — never design from memory of the
  code; re-verify the surfaces in §6 at the session's HEAD.
- **NTT model REQUIRED** for every phase that adds propagators/cells/lattices
  (Phases 2–4): cells (`:reads`/`:writes`), propagator fire functions, lattice
  declarations, with a correspondence table to the Racket implementation.
- **Network Reality Check (3 questions)** before any "on-network" claim:
  (a) which `net-add-propagator` calls were added? (b) which `net-cell-write`
  produces the result? (c) can you trace cell-creation → propagator-install →
  cell-write → cell-read = result? "None/no" ⇒ the phase is still imperative.
- **Mantra audit** + **SRE lattice lens** at every design decision.
- **Acceptance file as Phase 0** (this plan's Phase 0): a `.prologos` file whose
  on-network reduction must become fully visible; run via `process-file` +
  `tools/viz-export.rkt` before/after every phase.
- **Testing**: `check-parens.sh` after every `.rkt` edit; the targeted runner
  (`run-affected-tests.rkt --tests …`, never bare `raco test`) after production
  edits; **full suite as the regression gate ONLY** (read failure logs, never
  re-run to diagnose); benchmark (`bench-ab.rkt --runs 10`) after each
  reduction-path phase against the prior baseline.
- **Incremental commits**: one commit per phase (or sub-phase), conventional
  message, Series-prefixed, no co-author tags. Update the Progress Tracker +
  ledger + dailies per commit (this is the autonomy branch).
- **Validated ≠ Deployed / belt-and-suspenders ban / "pragmatic" ban** all
  apply — especially: a phase that keeps the old path "for safety" alongside the
  new is incomplete, not safe.

---

## 3. Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| 0 | Baseline + acceptance file + scope-lock measurement | ✅ | `98e3b35` acceptance file (0-error, 155 rounds); suite ingest-ON baseline = 8669 all-pass (flipping breaks nothing); ingest hooks scope-locked (β/ι/δ/int-folds) |
| 1 | **On-network reduction is the ONLY path** — native deleted (owner upgraded "flip" → "flip + delete native") | ✅ | `1741476`+`<this>`: removed `current-preduce-ingest?`/`-int-folds?` gate, de-gated β/ι/δ/int ingest arms, deleted duplicate native arms; removed `PREDUCE_INGEST` env + viz `--reduce`/`--no-reduce`; ported `test-preduce-ingest`; deleted on/off micro-bench. **Full suite 8671 ALL PASS (406.7s).** Absorbs part of Phase 5 (native compute arms gone; `whnf` still drives). |
| 2 | **Rule application becomes observable propagator firing** (un-collapse the atomic ingest; rules fire across BSP rounds on the observed network) | ⬜ | NTT model; Network Reality Check; viz shows redex → rule-fire → result across rounds |
| 3 | **Compute as propagators** (arithmetic primitive: a propagator reads operand cells, writes result — replacing `(apply op …)` in `instantiate-template`) | ⬜ | NTT model; viz shows `read-A,B → write-C`; `parallel-reduction` reads as real compute-propagation |
| 4 | **Recursion / β-δ on-network** (the recursion driver becomes propagator-driven rewriting; `fib`→`fib` unfolding on the network) | ⬜ | hardest; likely needs a design panel; viz shows fib's recursion as propagators |
| 5 | **Route the covered fragment through the e-graph, bypassing `reduction.rkt`** (the Track 8 slice for what's now fully on-network) | ⬜ | terminal; owner-checkpoint before landing; parity gate vs the recursive reducer |
| T | Dedicated tests per phase (`tests/test-preduce-*` extensions) | ⬜ | rule-firing observability, compute-propagator parity, recursion-on-network parity |

Update ⬜→🔄→✅ + commit hash per phase, in this table and the autonomy ledger.

---

## 4. Phase detail

### Phase 0 — Baseline, acceptance file, scope-lock (no production code)

- **Full-suite baseline** with ingest OFF (current default before Phase 1) and a
  second run with `PREDUCE_INGEST=1` (ingest ON) — capture both `timings.jsonl`
  + any failures. This quantifies exactly what flipping the default breaks
  (correctness regressions to fix in Phase 1) and the wall-clock delta.
- **bench-ab baseline** (`--runs 10 benchmarks/comparative/ --output`) ON vs OFF.
- **Acceptance file** `examples/2026-06-14-onnetwork-reduction.prologos`:
  reduction-heavy, 0-error, exercising arithmetic (the `parallel-reduction`
  shape) + δ unfolds + recursion (fib). The success instrument: export it with
  `tools/viz-export.rkt` after each phase and confirm the new on-network
  structure is visible.
- **Scope-lock**: confirm against current HEAD which reduction kinds the ingest
  hooks already cover (`reduction.rkt` `#:when (current-preduce-ingest?)` sites)
  vs. which need new work (compute, recursion).
- Gate: suite state captured (both modes); acceptance file Level-3 clean.

### Phase 1 — PReduce ingestion as the default

- **Flip** `current-preduce-ingest?` default → #t (`reduction.rkt:1323`). Decide
  `current-preduce-ingest-int-folds?` posture (default already #t). Retire / keep
  the `PREDUCE_INGEST` env override as a *disable* switch only (no dual
  production path — Validated≠Deployed).
- **Fix correctness regressions** surfaced by the suite: the e-graph result MUST
  equal the native reduction for every covered redex (the `match best … _ →
  (op-fn a b)` fallback in `preduce-ingest-int` is the parity check; any
  divergence is a bug to fix, not to fall back around).
- Gate: **full suite green** with ingest on by default; bench A/B recorded
  (regression expected — log it per §1, do not optimize).
- Network Reality Check N/A (no new propagators; this is a flag deployment).
- Commit: `feat(PReduce Track 8): on-network reduction is the production default`.

### Phase 2 — Rule application as observable propagator firing

- **Problem**: `preduce-ingest-int` → `dispatch-rules` → `apply-rule` →
  `eclass-union` + `run-to-quiescence` happens atomically *inside* the reducer's
  `whnf`, on the `prn-box` registry network, so the steps collapse into one
  observed round.
- **Objective**: make rule application a propagator that fires across observable
  BSP rounds — install rule propagators that watch e-class cells and, when an
  e-class whose term matches a rule LHS appears, fire to produce + union the
  RHS. "Rule application IS propagator firing" (the thesis).
- **Design questions (Stage-3, grounding-audit + likely a design panel)**:
  - Does the rule become a propagator on the *main* observed network, or does
    the registry network's quiescence need to surface to the observer per round?
  - Topology: rules as standing propagators (fire on matching e-class births)
    vs. a dispatch propagator keyed by head-symbol. Use the existing rule
    registry (`current-rule-registry-cell-id`) + congruence-style watchers.
  - Termination / confluence: this is non-monotone rewriting — which stratum?
    (`.claude/rules/stratification.md`; PReduce SM4 critical-pairs-by-join.)
- **NTT model REQUIRED**; **Network Reality Check** must pass.
- Gate: the acceptance file's reduction is visible step-by-step in the viz
  (redex cell → rule propagator fires → result cell, across rounds); full suite
  green; parity with native reduction.
- Commit (may sub-phase: 2a dispatch-as-propagator, 2b observability).

### Phase 3 — Compute as propagators

- **Objective**: the arithmetic primitive becomes a propagator that **reads the
  operand cells and writes the result cell**, replacing `(apply op args)` inside
  `instantiate-template` (`rule-dispatch.rkt:176`, `compute-ops` table). Then
  `int+(377,233)` is a propagator with inputs = the two operand e-classes,
  output = the sum e-class — genuine compute-as-propagation.
- **Design questions**: a primitive-op propagator family (one per `compute-ops`
  entry) installed when a rule's RHS has a `(compute …)` node; the fire function
  reads operand cell values, computes, writes. Cohesion with the e-graph (the
  result still interns + shares via hashcons). SRE lattice lens on the
  result-cell domain.
- **NTT model REQUIRED**; **Network Reality Check** must pass (this is the
  clearest `read-A,B → write-C` propagator in the whole substrate).
- Gate: `parallel-reduction` exported + viewed shows the arithmetic tree
  reducing as compute-propagators (no `union ≡`-only view); full suite green;
  bench recorded.
- Commit.

### Phase 4 — Recursion / β-δ on-network

- **Objective**: move the recursion driver on-network — `fib`→`fib` unfolding
  becomes propagator-driven rewriting (δ unfold + β as e-graph rules firing as
  propagators), so the recursion STRUCTURE lives on the network rather than in
  the recursive `whnf`. This is PReduce Track 2's β/δ realized as *standing
  propagators*, not gated hooks called from `whnf`.
- **This is the hardest phase** — research-grade; the recursion control flow is
  the part the recursive reducer owns. Expect a full Stage-3 design arc
  (grounding-audit + `design-options-panel` + ≥2 adversarial critique rounds +
  NTT model). May reveal that fuel/termination + the strata interaction needs
  its own sub-design (consume BSP-LE 2B speculative infra if non-confluent).
- Gate: `fib` exported + viewed shows the recursion as propagators (the
  fibonacci DAG built by firing rules, not by off-network calls); parity with
  native fib; full suite green.
- Commit (expect multiple sub-phases).

### Phase 5 — Bypass `reduction.rkt` for the covered fragment (Track 8 slice)

- **Objective**: for reduction kinds now fully on-network (arithmetic, δ/β as
  covered), route `whnf`/`nf` through the e-graph extraction instead of the
  recursive arms — the beginning of "`reduction.rkt` retired in its entirety."
- **Owner-gated** (charter §2 hard stop: Track 8 endgame is owner-checkpointed
  even on this branch). STOP and checkpoint with the owner before landing.
- Gate: parity (e-graph reduction == native reduction on the full acceptance
  corpus + suite); the bypassed arms are deleted, not kept alongside
  (belt-and-suspenders ban).
- Commit only after owner sign-off.

---

## 5. Risks, open questions, honest caveats

- **Perf regresses; that's accepted** (§1). The risk is *panic-optimizing* —
  don't. Record the curve; the payoff is SH/Zig (out of scope).
- **Phase 1 may surface latent correctness bugs** in the ingest path (it's been
  gated off, so its production exposure is thin). Budget time for parity fixes.
- **Phases 2 & 4 are genuine research** — rule-application-as-propagator and
  recursion-on-network are the PReduce thesis's hard core. They may need design
  panels and may reveal that a clean realization requires substrate work beyond
  this plan's framing. If a phase's design doesn't lock cleanly, STOP and
  surface the design question rather than forcing an imperative shim.
- **Non-confluence / termination**: on-network rewriting is non-monotone; the
  stratum assignment (S0 vs Sk) and fuel bounding must be designed
  (`stratification.md`, PReduce SM4). Don't hand-wave it.
- **The e-graph runs on a separate `prn-box` network today** — Phase 2's
  observability hinges on reconciling that with the observed BSP timeline. This
  is a real architectural question to ground first.

---

## 6. Key code surfaces (re-verify at session HEAD before trusting)

- `reduction.rkt`: `current-preduce-ingest?` (:1323, the flag to flip);
  `preduce-ingest-int` (the atomic ingest); the `#:when (current-preduce-ingest?)`
  hook sites (~:1527/1548/1563 δ/β, :1662-1668 int folds); `whnf`/`nf` (the
  recursive driver to eventually bypass).
- `rule-dispatch.rkt`: `dispatch-rules` (:239), `apply-rule` (computes via
  `instantiate-template` then `eclass-union`), `instantiate-template` (:176, the
  `(compute …)` → `(apply op args)` site = where the arithmetic is a function),
  `compute-ops` table.
- `eclass-graph.rkt`: `eclass-intern`, `eclass-union` (:136, the union
  propagator = the rewrite-as-propagator we already have),
  `current-eclass-containment-box` (the viz capture; extend for rewrite pairs if
  Phase 2 needs it).
- `driver.rkt`: `PREDUCE_INGEST` env handling (~:2304) — becomes the *disable*
  switch after Phase 1.
- `tools/viz-export.rkt` + `tools/viz/index.html`: the success instrument —
  each phase's acceptance is "the new on-network structure is visible here."
- PReduce Master `2026-05-02_PREDUCE_MASTER.md` (thesis + Track 6/7/8 framing);
  PReduce Track 2/3 PIRs (the gated-off + perf-verdict context).

---

## 7. First action for the next session

1. Re-read this plan + the viz roadmap + the PReduce Master thesis + the branch
   directive. Re-ground the §6 surfaces at HEAD (grounding-audit).
2. Do **Phase 0** (baseline both modes + acceptance file + scope-lock). Commit.
3. Open **Phase 1** (flip the default), run the suite, fix parity regressions,
   commit. Then proceed phase-by-phase, one commit per phase, updating this
   tracker + the ledger + dailies as you go.

Stop and checkpoint with the owner at: any phase whose design won't lock cleanly
(surface the question), the first wall-clock regression worth a decision, and
**before Phase 5** (owner-gated).
