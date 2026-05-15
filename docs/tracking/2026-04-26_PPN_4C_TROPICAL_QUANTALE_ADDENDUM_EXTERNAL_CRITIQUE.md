# PPN 4C Tropical Quantale Addendum — D.3 External Critique

**Date**: 2026-05-14
**Stage**: 3 — External Critique per [`DESIGN_METHODOLOGY.org`](principles/DESIGN_METHODOLOGY.org) Stage 3 + [`CRITIQUE_METHODOLOGY.org`](principles/CRITIQUE_METHODOLOGY.org)
**Critique target**: [`2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md`](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) (D.3; commits `2a4d938c` through `76a73ada`)
**Status**: External critique drafted (D.3.EC); resolution review with user pending; D.4 incorporates accepted findings

---

## §1 Purpose and scope

Per CRITIQUE_METHODOLOGY.org § Integration with Design Methodology: external critique applies AFTER self-critique (D.2.SC completed; 18/18 findings closed in this session). External critique brings FRESH LENSES that the design author's self-critique may have missed.

**Critic stance** (per CRITIQUE_METHODOLOGY.org § Orientation for External Critics):
- Evaluate from propagator-mindspace; sequential ordering EMERGES from dataflow, not imposed
- Every component traceable as: cell creation → propagator installation → cell writes → cell reads = result
- If a component can't be traced this way, it should be explicitly labeled as scaffolding with retirement plan
- The ten design principles (especially Propagator-First, Data Orientation, Correct-by-Construction) are the evaluation criteria, not algorithmic efficiency

**Fresh lenses** (DIFFERENT from D.2.SC's P/R/M/S):
- **CL (Cognitive Load)**: documentation burden vs implementation effort; is the design over-engineered for what it delivers?
- **MG (Measurement Gap)**: did the Pre-0 phase actually measure what it extrapolated from?
- **SP (Structural Sprawl)**: section/subsection layering complexity; is the document navigable?
- **OS (Over-Specification)**: are mechanisms specified beyond what they actually do at the relevant phase?
- **TD (Tracking Duplication)**: redundant tracking surfaces — beneficial or maintenance debt?
- **AP (API Design)**: naming, consumer-facing surface, footgun risk
- **EX (External comparisons)**: how does this compare to similar work elsewhere?
- **TS (Test Strategy)**: does validation actually cover what the design claims?
- **MB (Maintenance Burden)**: long-term cost over project lifetime?

---

## §2 Methodology

External critic stance distinct from self-critique. Each finding tagged with lens code (CL/MG/SP/OS/TD/AP/EX/TS/MB) + sequential number.

**Critique grounded in**:
- D.3 design doc (1495 lines after all D.3 revisions in this session)
- D.2.SC self-critique (which closed 18 findings already)
- Pre-0 plan + baseline data
- Project principles (DESIGN_PRINCIPLES.org, on-network.md, etc.)

**Response format** (per CRITIQUE_METHODOLOGY.org § Receiving External Critique: Grounded Pushback):
- ACCEPT
- ACCEPT-PROBLEM-REJECT-SOLUTION
- REJECT-WITH-JUSTIFICATION
- DEFER-WITH-TRACKING

---

## §3 Findings

### CL1 — Documentation-to-implementation ratio: the design generates more text than code

**The concern**: Phase 1C under hybrid is now estimated at ~45-90 LoC of code change (per R1 acceptance). The design documentation for that 45-90 LoC includes:
- §10.1 Scope and rationale (HYBRID PIVOT)
- §10.1.A Honest framing & retirement plan (consolidated P1 + P4)
- §10.A Threshold propagator's role under hybrid
- §10.B Cell Staleness Contract (with dual-API discipline)
- §10.2 Audit-grounded substrate plan (+ R2 commentary)
- §10.3 Per-site patterns (+ M2 acknowledgment)
- §10.4 Sub-phase plan
- §10.5 Drift risks (D-1C-1 through D-1C-6)
- §10.6 Termination + parity
- §10.7 Open questions (Q-1C-1, Q-1C-2, Q-1C-3 expanded)
- §14.4 Q3/Q4/Q5/Q6 hybrid clarifications

Plus: Issue #55, DEFERRED.md entry, MASTER_ROADMAP.org caveat, §11.3 11 microbench re-runs gate.

That's ~500-700 lines of design doc + 3-4 tracked surfaces + 11-bench validation gate, for ~45-90 LoC of actual production code change.

**Is this proportionate?** A reasonable external critic would ask: is the design generating documentation overhead disproportionate to the implementation? The self-critique discipline (D.2.SC + this resolution arc) was THOROUGH — but thoroughness has costs. Future maintainers face cognitive load reading 500+ lines of design doc to understand 45-90 LoC of code.

**Severity**: REFINEMENT
→ **Proposed resolution**: D.4 should add a §10.0 "Phase 1C executive summary" (~10-20 lines) that captures the essence: "Allocate canonical fuel-cost-cell + fuel-budget-cell + threshold propagator in make-prop-network. Preserve struct field + macro + decrement/check sites. Add typed dual-API for cell reads (sync vs possibly-stale). Implementation ~45-90 LoC; design doc detail below for retirement-plan tracking + Phase 3C consumer interface." A reader who needs only the WHAT can read §10.0; the WHY/HOW is layered below.

---

### MG1 — Pre-0 measurement gap: cell-write itself was never measured

**The concern**: Pre-0 R-19 finding states "without hybrid pivot, full cell-based path would trigger major GC at 100k decrement rate." But Pre-0 measured **struct-copy decrement** (M7, A7) + struct-copy GC profile (R3) — it did NOT measure **cell-write decrement** + **cell-write GC profile** directly. The extrapolation is:
- Struct-copy = ~24 ns, 62.5 bytes/dec, zero major-GC at 100k (MEASURED)
- Cell-write = ??? ns, ??? bytes/dec, ??? GC profile (EXTRAPOLATED from BSP-LE 2B cell-write benchmarks at different rates)

D.3 Q-1B-6 (P2 acceptance) adds the spike at Phase 1B mini-design opening to ACTUALLY MEASURE cell-write. But this is POST-HYBRID-PIVOT-COMMIT. The hybrid pivot decision was made on extrapolated grounds; the falsification test is scheduled after the commit.

**Is this principled?** Per `DESIGN_METHODOLOGY.org`: "Pre-0 benchmarks are DESIGN INPUT, not validation." The hybrid pivot is a DESIGN OUTPUT informed by Pre-0; the empirical claim "cell-write would trigger major GC" should have been a Pre-0 measurement target, not a post-commit spike target.

**Severity**: REFINEMENT (acknowledge the gap honestly; Q-1B-6 mitigates but doesn't eliminate)
→ **Proposed resolution**: D.4 §10.1.A should add ONE sentence acknowledging the measurement gap: "The hybrid pivot's empirical foundation extrapolates from struct-copy measurements (R3 + R-19); direct cell-write measurement was DEFERRED to Phase 1B mini-design spike (Q-1B-6). This is a known Pre-0 gap — the falsification test happens post-commit rather than pre-commit. Honest framing per `workflow.md` 'Pragmatic' anti-pattern: the extrapolation is REASONABLE (BSP-LE 2B cell-write benchmarks indicate the order-of-magnitude is right) but UNVERIFIED for THIS specific cell layout (TropicalFuel single-value tagged-cell-value)."

---

### SP1 — §10 section sprawl: §10.1 + §10.1.A + §10.A + §10.B + §10.2 + §10.3 + §10.4 + §10.5 + §10.6 + §10.7 = 10 subsections under one phase

**The concern**: D.3 §10 (Phase 1C) now has 10 distinct subsections after all the resolution work:
- §10.1 + §10.1.A: scope + honest framing (2 subsections)
- §10.A + §10.B: threshold role + staleness contract (2 NEW from BLOCKINGs)
- §10.2-§10.7: substrate plan + per-site + sub-phase + risks + termination + open questions (6 subsections)

Plus inline R1/R2/M2/M3 commentary paragraphs within several subsections. Plus §14.4 hybrid clarifications cross-referencing back to §10.

The naming convention (§10.1.A vs §10.A) is inconsistent — §10.1.A is a sub-subsection of §10.1; §10.A is a sub-subsection of §10. Both exist. The numbering also has §10.2 NOT under §10.1.A (which is the new ordering) but at the same level as §10.1.

**Is this navigable?** A reader trying to understand "what does Phase 1C actually do?" faces 10 subsections + cross-references. The self-critique resolution work optimized for COMPLETENESS (every finding has a home in the doc) at the cost of NAVIGABILITY.

**Severity**: REFINEMENT
→ **Proposed resolution**: D.4 §10 restructure to a flatter hierarchy:
1. §10.1 Scope + rationale (merge §10.1 + §10.1.A into one subsection with subheadings; drop the .A naming)
2. §10.2 Architecture (merge §10.A + §10.B + §10.2 into one subsection with subheadings: "Threshold propagator role" + "Cell staleness contract" + "Substrate setup")
3. §10.3 Per-site patterns (unchanged)
4. §10.4 Sub-phase plan (unchanged)
5. §10.5 Drift risks + open questions (merge §10.5 + §10.7)
6. §10.6 Termination + parity (unchanged)

Reduces 10 subsections to 6; same content; cleaner table-of-contents view.

---

### OS1 — Threshold propagator's three roles are mostly forward-captured, not Phase 1B-real

**The concern**: §10.A (M1 BLOCKING resolution) names three load-bearing roles for the threshold propagator under hybrid:
1. **Phase 3C consumer paths** (UC1/UC2/UC3) — FORWARD-CAPTURED, doesn't exist yet
2. **On-exhaustion path** — RARE event by Pre-0 finding 5
3. **Speculation rollback** — also a Phase 3C-era concern (current `with-speculative-rollback` is being retired)

For Phase 1B + 1C SCOPE, role #1 is forward-captured (Phase 3C UC1/UC2/UC3 don't ship in this addendum). Role #2 is the only path that EXISTS in this addendum, and it's a rare event. Role #3's relevance depends on Phase 3A/B ATMS branching landing.

**Is the propagator over-specified?** The threshold propagator is INSTALLED in Phase 1C (§10.2 substrate plan), but for Phase 1B + 1C, it primarily handles role #2 (rare exhaustion). The other roles are SPECULATIVE.

A more honest framing: "the threshold propagator is installed in Phase 1C primarily for on-exhaustion routing; Phase 3C consumers will use it for additional roles when those phases ship."

**Severity**: REFINEMENT
→ **Proposed resolution**: D.4 §10.A reorder the three roles by Phase 1B/1C RELEVANCE:
1. **On-exhaustion path** (PRIMARY for Phase 1C; the propagator's actual job in this addendum)
2. **Phase 3C consumer paths** (FORWARD-CAPTURED for UC1/UC2/UC3; not Phase 1C-load-bearing)
3. **Speculation rollback** (CONDITIONAL on Phase 3A/B ATMS branching; if speculation rollback retires before Phase 3A, this role retires too)

This makes clear: for THIS addendum, role #1 is the propagator's job; roles #2 and #3 are forward-investments.

---

### TD1 — Four-surface tracking duplication is heavy for one piece of scaffolding

**The concern**: The hybrid pivot scaffolding is tracked at FOUR surfaces:
1. D.3 §10.1.A in-design
2. DEFERRED.md entry
3. GitHub Issue #55
4. Q-1B-6 + §11.3 falsification gates

Each surface duplicates much of the same content (specific blocker, retirement trigger, retirement scope). Updates to one surface must propagate to others or they drift. The user's direction was specifically that GitHub Issue + DEFERRED.md dual-surface is intentional (different visibility contexts) — but adding the in-design subsection + falsification gates makes four.

**Is this over-tracked?** A simpler structure: D.3 §10.1.A as the SINGLE SOURCE OF TRUTH for the scaffolding-with-retirement-plan content; DEFERRED.md entry + Issue #55 just LINK to §10.1.A (not duplicate the content); falsification gates (Q-1B-6 + §11.3) are CONSUMERS of §10.1.A (test the claim made there).

**Severity**: REFINEMENT (minor — duplication is intentional but content can be slimmed)
→ **Proposed resolution**: D.4 simplify DEFERRED.md entry + Issue #55 body to LINK to D.3 §10.1.A rather than DUPLICATE content. §10.1.A becomes the single source of truth; DEFERRED + Issue become reference pointers (with just the retirement-plan summary + link to §10.1.A for full context). Reduces drift risk; keeps four-surface visibility.

---

### AP1 — `net-fuel-cost-read/synced` naming asymmetry: the "safe" API has the longer name

**The concern**: D.3 §10.B Cell Staleness Contract defines:
- `net-fuel-cost-read` — returns possibly-stale
- `net-fuel-cost-read/synced` — triggers sync first

The "safe" API (synced) has the LONGER name. The "potentially unsafe" API (possibly-stale) has the SHORTER name. Per Correct-by-Construction (DESIGN_PRINCIPLES.org § Correct by Construction), "make the wrong thing hard to express" — the shorter name should be the safe default; the longer name should be the opt-in.

**Comparison to other Prologos APIs**:
- `net-cell-read` (general; possibly-stale under speculation) — base API, possibly-stale
- `net-cell-read-raw` (BSP-aware) — longer name; specific use case

So the existing convention is "longer name = specific use case." But staleness here is a SAFETY concern, not a use-case specialization. The convention probably should invert for staleness-sensitive APIs.

**Severity**: REFINEMENT (small naming consideration; might also be DEFER to Phase 1B mini-design when naming is finalized per Q-1B-1)
→ **Proposed resolution**: D.4 should note the naming asymmetry at §10.B and FLAG IT for Phase 1B mini-design (per Q-1B-1: "API naming"):
- Option A: keep current naming (`net-fuel-cost-read` = possibly-stale; `/synced` = safe)
- Option B: invert (`net-fuel-cost-read` = always synced [safe]; `net-fuel-cost-read/maybe-stale` = explicit opt-in)
- Option C: rename for clarity (`net-fuel-cost-cached` = possibly-stale; `net-fuel-cost-live` = synced)

Option B aligns with Correct-by-Construction. Option C is more descriptive. Decide at Phase 1B mini-design per Q-1B-1.

---

### TS1 — Test strategy: parity tests cover counter-vs-cell, but not staleness contract behavior

**The concern**: §15 parity test skeleton + §11.3 Phase 1V exit criteria cover:
- tropical-fuel-counter-parity (V4): OLD counter vs NEW cell exhaustion at semantic-phase boundaries
- atms-deprecated-api-parity (V5)
- surface-atms-ast-elaboration-parity (V6)

But the Cell Staleness Contract (§10.B) is a NEW consumer-facing API discipline. **Where are the staleness-contract behavioral tests?** Specifically:
- `net-fuel-cost-read` returns possibly-stale value (tested how?)
- `net-fuel-cost-read/synced` triggers sync (tested how?)
- Staleness bound = "at most one semantic transition" — verified how?
- Phase 3C consumer can correctly use either API (verified by what test?)

The parity tests verify OLD vs NEW exhaustion equivalence, but they don't verify the STALENESS CONTRACT itself. This is a Phase 1B test scope gap.

**Severity**: REFINEMENT
→ **Proposed resolution**: D.4 §9.6 Phase 1B test list should include staleness-contract behavioral tests:
- Test A: `net-fuel-cost-read` after struct-field update without sync — returns stale value (PRE-sync)
- Test B: `net-fuel-cost-read/synced` triggers sync — returns live value
- Test C: Sequence of decrements + intermediate `net-fuel-cost-read` — value reflects last-synced state (NOT current struct-field)
- Test D: After explicit semantic-transition sync — `net-fuel-cost-read` returns updated value
- Staleness bound test: across N=1, N=10, N=100 decrements between syncs, staleness gap is at most "current cost - last-synced cost" (NOT unbounded drift)

These are CONTRACT verification tests. Without them, the contract is documented but not enforced.

---

### EX1 — Tropical quantale for fuel cost: how does this compare to e-graph cost extraction?

**The concern**: The design references "first production landing for OE Track 0/1/2" and "future PReduce consumers." External comparison: **e-graph extraction with tropical cost** is a well-established pattern (Willsey et al. 2021 egg, Coward et al. 2022 colored e-graphs, Yang et al. 2021 equality saturation for tensor compilers). These systems:
- Use tropical (min-plus) semiring for cost minimization over e-classes
- Extract minimum-cost programs via tropical cost-merge (exactly our `min` join)
- Apply residuation for "best-cost-within-budget" extraction

**Is the design aware of this prior art?** D.3 §2.3 cites Module Theory + Tropical Optimization Research + Algebraic Embeddings, but doesn't explicitly compare to:
- egg / egraphs (Willsey et al.)
- equality saturation literature
- Goodman's semiring parsing (1999) — partially cited via OE Track 1

Specifically: the threshold propagator + residuation operator are EXACTLY the extraction primitives e-graph systems use. The hybrid pivot's "cell substrate alongside fast-path" pattern is novel, but the underlying tropical-quantale-as-cost-substrate is shared with e-graph extraction.

**Why this matters**: future PReduce / OE consumers will likely look at e-graph literature. The design should explicitly position itself in that landscape: "tropical fuel substrate = e-graph cost extraction primitive applied to BSP propagator fuel; reuse of established pattern."

**Severity**: REFINEMENT (positioning enhancement, not a defect)
→ **Proposed resolution**: D.4 §2.3 "Prior art" section add explicit e-graph references:
- Willsey et al. 2021 "egg: Fast and Extensible Equality Saturation"
- Coward et al. 2022 "Combining E-Graphs with Abstract Interpretation"
- Pan et al. 2024 "Type-based Optimization of E-Graph Extraction"
- Position: "Tropical quantale here is the same algebraic structure these systems use for cost extraction; the addendum applies it to BSP propagator fuel tracking + lays substrate for future PReduce consumer to do full e-graph cost extraction."

---

### MB1 — Maintenance burden: dual classification + four-surface tracking + 11-bench gate has long-term cost

**The concern**: The hybrid pivot introduces:
- Dual classification at §14.4 Q5 (D.1 vs D.2/D.3 framing)
- Four-surface tracking (design + DEFERRED + Issue + gates)
- 11 microbench re-runs at Phase 1V
- Cell staleness contract (new consumer-facing API discipline)
- Q-1C-3 enumeration (BLOCKING for 1C-iv) with 10+ candidate transitions to verify

**Total maintenance surface**: substantial. Each surface drifts independently if not maintained. When SH Series ships (retirement trigger), maintainers must:
- Retire §10.A + §10.B + §10.1.A
- Update §14.4 (revert dual classification to single)
- Close Issue #55
- Remove DEFERRED.md entry
- Retire MASTER_ROADMAP.org caveat
- Decommission Q-1B-6 + §11.3 reconsideration gate
- Remove cell staleness contract APIs (`net-fuel-cost-read/synced`)
- Migrate Phase 3C consumers if they exist

That's ~8 retirement steps across multiple files. If SH Series is 1-2 years out, maintenance drift is realistic.

**Is this proportionate?** The hybrid pivot was empirically justified (Pre-0 R-19); but the maintenance surface might be over-engineered for what's essentially a "preserve fast-path until runtime improves" decision.

**Severity**: REFINEMENT (acknowledge the burden honestly)
→ **Proposed resolution**: D.4 §10.1.A retirement-plan subsection should include an EXPLICIT RETIREMENT CHECKLIST (8+ steps named) so future maintainers have a clear path. The maintenance burden is real but addressable if the retirement path is pre-specified.

Additionally: consider whether the four-surface tracking is over-engineered. Per TD1, slimming DEFERRED + Issue #55 to LINK to §10.1.A (rather than duplicate) reduces drift surface from 4 to 2 (design-doc + link-pointers).

---

### MG2 — Cell-write GC profile under speculation worldview is also unmeasured

**The concern**: R-tier measured R5 (1000-cycle speculation retention; struct-based) and R3 (100k decrements GC profile; struct-based). But the hybrid pivot under SPECULATION worldviews creates a NEW measurement scenario:
- On-exhaustion cell-write under a speculation worldview tags the cell with that worldview's bitmask
- Phase 3A union-type ATMS branching creates multiple speculation worldviews concurrently
- Each branch's on-exhaustion cell-write tags differently

Pre-0 didn't measure this concurrent-worldview-cell-write scenario. The retention bound at §11.3 (≤ 30 KB at 1000 cycles) is from R5's SINGLE-WORLDVIEW speculation; multi-worldview branching might have different memory characteristics.

**Severity**: REFINEMENT (smaller MG; less critical than MG1 because Phase 3A is forward-captured)
→ **Proposed resolution**: D.4 §11.3 add a Phase 3A-conditional gate: "When Phase 3A union-type ATMS branching lands, re-microbench R5 + A10 (5-way fork × N decrements per branch) under multi-worldview speculation; verify retention bound holds under concurrent-worldview cell-write." Defer to Phase 3A; not Phase 1V scope.

---

### CL2 — Q-1C-3 enumeration with 10+ candidate transitions: is the staleness bound really tractable?

**The concern**: Q-1C-3 (per R3 acceptance) requires Phase 1C-iii mini-design to exhaustively enumerate SEMANTIC TRANSITIONS where cell sync occurs. The expanded candidate list includes:
- Start of phase
- End of phase
- Save/restore boundaries
- On-exhaustion path
- Phase 3C UC explicit query sites
- BSP round boundaries
- Topology-stratum transitions
- Sub-phase boundaries (probably not)
- Speculative-rollback boundaries
- Inter-test boundaries

That's 10 candidate transitions. For each:
- Decide YES (synced) or NO (not a transition)
- Document staleness bound
- Update §10.B API documentation

**Is this tractable at Phase 1C-iii?** The staleness contract claims "at most one semantic transition lag." If the enumeration has 10 yes-transitions, the contract's lag bound depends on the maximum interval between any two yes-transitions. Verifying this empirically requires test coverage for each combination.

**Severity**: REFINEMENT → likely DEFER to Phase 1C-iii mini-design with explicit acknowledgment of complexity
→ **Proposed resolution**: D.4 §10.7 Q-1C-3 add note: "Phase 1C-iii mini-design must address: how is the staleness bound VERIFIED across the full transition enumeration? Test coverage strategy: for each pair of yes-transitions, construct a workload that crosses both; verify cell value at second-transition reflects all changes between first-transition and second-transition. This is N^2 in the number of yes-transitions; with ~5-7 yes-transitions, ~25-49 pair tests. Feasible but non-trivial."

---

## §4 Findings synthesis

| Lens | Count | Severity distribution |
|---|---|---|
| CL (Cognitive Load) | 2 | REFINEMENT, REFINEMENT |
| MG (Measurement Gap) | 2 | REFINEMENT, REFINEMENT |
| SP (Structural Sprawl) | 1 | REFINEMENT |
| OS (Over-Specification) | 1 | REFINEMENT |
| TD (Tracking Duplication) | 1 | REFINEMENT |
| AP (API Design) | 1 | REFINEMENT |
| TS (Test Strategy) | 1 | REFINEMENT |
| EX (External comparisons) | 1 | REFINEMENT |
| MB (Maintenance Burden) | 1 | REFINEMENT |

**Total**: 11 findings (CL1, CL2, MG1, MG2, SP1, OS1, TD1, AP1, TS1, EX1, MB1). All REFINEMENT severity (no BLOCKING; the design is structurally sound, but has refinement opportunities from an external perspective).

**No PUSHBACK candidates pre-identified** — the response section below evaluates each finding against grounded pushback criteria.

---

## §5 Author's response to each finding

Per CRITIQUE_METHODOLOGY.org § Receiving External Critique: Grounded Pushback. For each finding: ACCEPT / ACCEPT-PROBLEM-REJECT-SOLUTION / REJECT-WITH-JUSTIFICATION / DEFER-WITH-TRACKING.

### CL1 — Doc-to-impl ratio

**Response**: ACCEPT-PROBLEM-REJECT-SOLUTION

The doc-to-impl ratio concern is REAL — 500+ lines of design for 45-90 LoC of code is high. BUT:
- Most of the design surface is RETIREMENT-PLAN content (§10.1.A scaffolding tracking; §14.4 dual classification; Q-1B-6 + §11.3 falsification gates). When SH Series retires the hybrid, MUCH of this design content retires with it. Steady-state code = 45-90 LoC; steady-state design = much smaller.
- The 500+ lines also includes Phase 3C consumer interface specification (§10.B Cell Staleness Contract + §10.A propagator roles + §9.7 UC1/UC2/UC3 enumeration). These are FORWARD-CAPTURED for Phase 3C; they're not redundant with the 45-90 LoC implementation.
- A §10.0 executive summary IS a good addition. But the layered design isn't over-engineering — it's investment in Phase 3C consumer onboarding.

**Resolution**: ACCEPT the §10.0 executive summary addition (~10-20 lines naming the WHAT). Don't restructure the existing §10.1+ content (it has legitimate purposes).

### MG1 — Cell-write not measured pre-commit

**Response**: ACCEPT

The measurement gap is real. The extrapolation from R-19 (struct-copy GC-friendly) to "cell-write would be major-GC-pressured" is reasonable but unverified. Q-1B-6 spike at Phase 1B mini-design addresses this, but post-commit rather than pre-commit. Honest framing: the hybrid pivot is empirically MOTIVATED by R-19 but not empirically VERIFIED for cell-write at the inline-check rate.

**Resolution**: ACCEPT. D.4 §10.1.A add one-sentence acknowledgment of the measurement gap (the extrapolation is reasonable but Q-1B-6 is the actual verification).

### SP1 — §10 section sprawl

**Response**: ACCEPT-PROBLEM-REJECT-SOLUTION

The sprawl is real (10 subsections). BUT the proposed restructure (merge §10.1 + §10.1.A; merge §10.A + §10.B + §10.2; etc.) loses the clear separation between:
- §10.1: Phase 1C scope
- §10.1.A: Honest framing (consolidates P1+P4)
- §10.A: Threshold propagator role (M1 BLOCKING resolution)
- §10.B: Cell Staleness Contract (P3 BLOCKING resolution)

These have DISTINCT purposes. Merging them loses the "this section addresses BLOCKING finding X" traceability.

**Resolution**: ACCEPT a §10.0 executive summary (per CL1) which acts as navigation aid; REJECT the deep restructure. The clear separation IS valuable for traceability to D.2.SC findings.

### OS1 — Threshold propagator over-specification for Phase 1B

**Response**: ACCEPT

The reordering by Phase 1B/1C relevance is honest. Role #1 (on-exhaustion) is the propagator's actual job in this addendum; roles #2 (Phase 3C consumer paths) and #3 (speculation rollback) are forward-investments.

**Resolution**: ACCEPT. D.4 §10.A reorder the three roles by Phase 1B/1C relevance (on-exhaustion FIRST; consumer paths + rollback as forward-investment).

### TD1 — Four-surface tracking duplication

**Response**: ACCEPT

The duplication across §10.1.A + DEFERRED.md + Issue #55 + falsification gates IS more than needed for content fidelity. Slimming DEFERRED + Issue #55 to LINK rather than DUPLICATE reduces drift surface while preserving visibility.

**Resolution**: ACCEPT. D.4 update DEFERRED.md entry + Issue #55 body to LINK to D.3 §10.1.A rather than duplicate (preserves summary + retirement criteria; defers full context to §10.1.A as single source of truth).

### AP1 — `net-fuel-cost-read/synced` naming asymmetry

**Response**: DEFER-WITH-TRACKING (to Phase 1B mini-design per Q-1B-1)

The naming asymmetry is a real Correct-by-Construction concern. But naming should be finalized at Phase 1B mini-design (per Q-1B-1) with code in hand. Flag it now; decide then.

**Resolution**: DEFER. D.4 §10.B add note about the naming asymmetry + reference Q-1B-1 for resolution at Phase 1B mini-design with three options (current / invert / rename).

### TS1 — Staleness contract test coverage gap

**Response**: ACCEPT

The staleness contract is a NEW behavioral API; without contract verification tests, it's documented but not enforced. The proposed test sequence (A/B/C/D + staleness bound test) is concrete.

**Resolution**: ACCEPT. D.4 §9.6 Phase 1B test list add staleness-contract behavioral tests (4 tests + staleness bound verification).

### EX1 — E-graph cost extraction positioning

**Response**: ACCEPT

External positioning is enhancement, not defect. The tropical quantale primitive IS the same algebraic structure e-graph extraction systems use. Explicit citation strengthens the design's grounding.

**Resolution**: ACCEPT. D.4 §2.3 "Prior art" add e-graph references (egg, equality saturation, type-based extraction) + position the addendum's primitive as "e-graph cost extraction primitive applied to BSP fuel."

### MB1 — Maintenance burden + retirement checklist

**Response**: ACCEPT

The maintenance burden is real; pre-specifying the retirement checklist addresses it. ~8 retirement steps named in advance gives future maintainers (or future-us under SH Series) a clear path.

**Resolution**: ACCEPT. D.4 §10.1.A retirement-plan subsection add EXPLICIT RETIREMENT CHECKLIST (8 named steps); cross-reference TD1 simplification of tracking surfaces.

### MG2 — Cell-write GC under speculation worldview unmeasured

**Response**: DEFER-WITH-TRACKING (to Phase 3A)

Phase 3A union-type ATMS branching is forward-captured; multi-worldview cell-write isn't a Phase 1B/1C concern. Defer measurement to Phase 3A when branching ships.

**Resolution**: DEFER. D.4 §11.3 add Phase 3A-conditional gate: re-microbench R5 + A10 under multi-worldview speculation at Phase 3A; not Phase 1V scope.

### CL2 — Q-1C-3 enumeration tractability

**Response**: ACCEPT

The N^2 test-pair complexity for staleness bound verification is real. Phase 1C-iii mini-design must address it. Pre-noting the complexity helps the mini-design plan time/scope.

**Resolution**: ACCEPT. D.4 §10.7 Q-1C-3 add tractability note: with ~5-7 yes-transitions, ~25-49 pair tests; non-trivial but feasible; Phase 1C-iii mini-design plans the test strategy.

---

## §6 Response distribution

| Response | Count | Findings |
|---|---|---|
| ACCEPT | 6 | MG1, OS1, TD1, TS1, EX1, MB1, CL2 |
| ACCEPT-PROBLEM-REJECT-SOLUTION | 2 | CL1 (accept summary, reject restructure); SP1 (accept summary, reject deep restructure) |
| DEFER-WITH-TRACKING | 2 | AP1 (to Phase 1B mini-design); MG2 (to Phase 3A) |
| REJECT-WITH-JUSTIFICATION | 0 | (no premise errors; all findings represent real refinement opportunities) |

**Total**: 11 findings; 8 ACCEPT / 2 ACCEPT-PROBLEM-REJECT-SOLUTION / 2 DEFER (with tracking) / 0 REJECT.

---

## §7 Resolution proposals — D.3 → D.4 incorporation

If user accepts the responses above, D.4 changes include:

### §7.1 New content
1. **§10.0** — Phase 1C executive summary (~10-20 lines)
2. **§10.B AP1 note** — naming asymmetry flag + 3 options (defer to Q-1B-1)
3. **§9.6** — staleness contract test coverage (4 tests + bound verification)
4. **§2.3** — e-graph prior art (egg + equality saturation + type-based extraction)
5. **§10.1.A retirement checklist** — 8 explicit retirement steps

### §7.2 Modifications
6. **§10.A** — reorder propagator roles by Phase 1B/1C relevance (on-exhaustion FIRST)
7. **§10.1.A** — one-sentence cell-write measurement gap acknowledgment (MG1)
8. **§11.3** — Phase 3A-conditional gate for multi-worldview cell-write (MG2)
9. **§10.7 Q-1C-3** — tractability note (~N^2 test pairs)

### §7.3 Cross-file changes
10. **DEFERRED.md entry** — slim to LINK to D.3 §10.1.A (TD1)
11. **GitHub Issue #55** — slim body to LINK to D.3 §10.1.A (TD1)

Estimated D.4 scope: ~80-120 lines net additions across D.3 + 2 cross-file slimmings.

---

## §8 Process notes

### §8.1 External-critic stance discipline

This critique adopted explicit external-critic stance distinct from self-critique:
- Self-critique (D.2.SC) applied P/R/M/S lenses focused on design's internal consistency + principle alignment
- External critique (this document) applied fresh lenses (CL/MG/SP/OS/TD/AP/TS/EX/MB) focused on:
  - Documentation burden vs implementation effort (CL)
  - Measurement gaps in Pre-0 (MG)
  - Structural complexity / navigation (SP)
  - Over-specification (OS)
  - Tracking duplication (TD)
  - Naming + consumer-facing API (AP)
  - Test strategy completeness (TS)
  - External comparisons / positioning (EX)
  - Maintenance burden over project lifetime (MB)

The lenses are GENUINELY DIFFERENT from self-critique. Some findings (MG1, MG2) emerged from "stepping outside" the design author's confidence in the Pre-0 work — recognizing the extrapolation gap that self-critique didn't surface.

### §8.2 Note on critic-vs-author overlap

Per CRITIQUE_METHODOLOGY.org caveat: the same author (Claude in this session) wrote both the design and the critique. The external-critic stance was DISTINCT in framing but not from a distinct agent. A genuinely external party (different AI, human reviewer, etc.) might find additional concerns this critique missed.

If the user wants a SECOND external critique from an actual external source (via Chrome to another AI, or human review), this document is the input package. The 11 findings + responses above represent the "what would a stance-distinct external critic likely surface" pass.

---

## §9 Cross-references

- D.3 design: [`2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md`](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md)
- D.2.SC self-critique: [`2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md`](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md)
- Pre-0 plan: [`2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md`](2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md)
- CRITIQUE_METHODOLOGY: [`principles/CRITIQUE_METHODOLOGY.org`](principles/CRITIQUE_METHODOLOGY.org)
- DESIGN_PRINCIPLES: [`principles/DESIGN_PRINCIPLES.org`](principles/DESIGN_PRINCIPLES.org)
- GitHub Issue #55: https://github.com/LogosLang/prologos/issues/55

---

## Document status

**D.3 external critique drafted (D.3.EC)** — 11 findings; author's responses included; ready for resolution review with user.

**Working through the points**: same incremental discipline as D.2.SC. Recommend walking 3-4 ACCEPT findings together as a batch (CL1 summary, MG1, EX1, MB1 retirement checklist) then handling deferrals (AP1, MG2) as note-additions; finally tackle SP1's ACCEPT-PROBLEM-REJECT-SOLUTION + remaining ACCEPTs.

After resolution review: D.4 design revision incorporates accepted findings (~80-120 lines net additions + 2 cross-file slimmings). Stage 4 implementation per per-phase mini-design+audit opens after D.4.
