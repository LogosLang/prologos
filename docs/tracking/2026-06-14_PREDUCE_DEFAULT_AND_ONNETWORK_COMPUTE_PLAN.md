# PReduce → Default + On-Network Compute/Recursion — Next-Session Plan

**Created**: 2026-06-14
**Status**: 🔄 IN PROGRESS — Phases 0–2 ✅; Phase 3 dropped (off-roadmap);
Phase 4a ✅ (recursion steps as union propagators — viz shows recursion as
propagators; suite 8678 all-pass). Phase 4b/4c (network DRIVES recursion) =
documented research frontier (worsen the perf wall on Racket; SH/Zig-era).
Phase 5 owner-gated. The viz success criterion is MET at tractable sizes.
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
| 2 | **Rule application becomes propagator firing** (arithmetic dispatch: an imperative `dispatch-rules` call → an on-network STRATUM firing, mirroring the congruence engine) | ✅ | `656a294` core (cell-22 dispatch-request + `process-dispatch-requests` topology stratum + emitter in `preduce-ingest-int`) · `edeff08` 2T · `ac65fad` cell-count test bumps. NTT model + Network Reality Check in the design doc. Suite **8674 all-pass**. Scope: arithmetic path only (the grounding finding — see below); β/δ/ι is Phase 4 |
| 3 | ~~Compute as propagators~~ **DROPPED (off-roadmap)** | ❌ | The e-graph evaluates primitives FUNCTIONALLY inside a rule (`instantiate-template`'s `(apply op args)`) — that IS the e-graph design, not an incomplete version. A standalone `int+` propagator is the *direct-compute* substrate we explicitly chose NOT to build (gives up structural sharing). Owner-approved correction 2026-06-14. "Everything-on-network" is satisfied when rule application is stratum firing (Phase 2) — the compute runs INSIDE the dispatch fire |
| 4a | **Recursion step as a union propagator** (β/δ/ι record {redex,result} via eclass-union, not a cell-write; viz shows recursion as propagators) | ✅ | `2bf9b5e` + design doc `2026-06-14_PREDUCE_T8_PHASE4_RECURSION_ON_NETWORK.md`. Suite **8678 all-pass**; fib 6 viz: 172 rounds, ≤18 props/round, union propagators visible (pre-4a: "only one propagator"). Net-threading fix preserves the recursion subtree. THE viz goal met at tractable sizes |
| 4a-perf | **Perf wall LIFTED** (call-by-value memo key + incremental viz observer) | ✅ | `02da3bd` cbv memo key (naive fib exponential→LINEAR: fib 15 reduce >120s→0.27s; acceptance 2117→194ms) + `031ff2f` incremental observer (fib 15 export 16.3s→11.1s). **fib 15 now traceable** (234 rounds, 0 errors); suite 8673 all-pass (faster: 372s). cbv key normalizes the memo KEY only; reduction stays call-by-name. See §9 of the 4a doc |
| 4b/4c/5 design | **Network-DRIVEN reduction + bypass** — demand cascade + extraction | ✅ | `12f97a7` design doc `2026-06-14_PREDUCE_T8_PHASE4b5_NETWORK_DRIVEN_REDUCTION.md`. Reframes 4b/4c/5 as one arc: `whnf-step1` one-step classifier + reduce-stratum cascade + extraction. Form-rep: expr-structs + native one-step compute (sidesteps the de-Bruijn-subst template blocker). Honest staging (whnf is ~1700 lines/dozens of constructs → multi-session) + per-construct PARITY gate |
| 5a | **whnf-step1 + whnf-via-egraph (parity-gated)** — the validated one-step primitive | ✅ | `a72b3f2`. `whnf-step1` (migrated: β/ι/suc/fst/snd/J/boolrec/ann/vhead/vtail + demand; `'native` fallback for the rest) + `whnf-via-egraph` driver. PARITY harness `test-preduce-egraph.rkt` (27 checks) == native whnf. **Pure addition — default whnf untouched.** Suite **8705 all-pass (441 files)**. 5a's driver is a LOOP (validates the decomposition) |
| 5b | **Scheduler-driven cascade** — genuine network-DRIVE | ✅ | `c49c53c`. `whnf-via-egraph-network`: the BSP scheduler drives reduction (keep-pending reduce stratum, cell-23). Network Reality Check PASSES (scheduler-driven, not a loop). PARITY-gated (== native whnf, 47 checks); **suite 8725 all-pass**. Migrated head fragment is network-driven; rest 'native; demand subterms native (set-latch = future). See §10 of the 4b5 doc |
| 5c | **DEPLOY: the cascade is the DEFAULT reduction driver** (owner: "delete the recursive off-network DRIVER, keep the compute leaf") | ✅ | `12d4131` routing hook + batch 2 (reduce/δ/meta); `84137e5` batch 1 (int arith); `c98d3a9` default flip. `whnf` routes through the cascade by default; the BSP scheduler DRIVES ground reduction; native reducer demoted to compute-leaf + non-ground fallback. PREDUCE_NATIVE=1 forces native. **Full suite with cascade as default = 8750 all-pass (386.9s, ~15% over native).** |
| limits/terminal | **Why whnf-impl can't be physically deleted** | 🔒 | TWO architectural limits (not gaps): (1) non-ground reduction (metavars) can't be PCE-interned → native fallback retained; (2) full deletion = reimplementation (higher-order fold/map/filter RECURSE; FFI), not mechanical. So the DRIVER is deleted (cascade is the driver); the COMPUTE LEAF stays (the e-graph's own compute-inside-the-rule design). Perf of full on-network compute routes to SH/Zig |
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
