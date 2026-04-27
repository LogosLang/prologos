# PPN 4C Tropical Quantale Addendum — D.2 Self-Critique (P/R/M/S)

**Date**: 2026-04-26
**Stage**: 3 — Self-Critique per [`DESIGN_METHODOLOGY.org`](principles/DESIGN_METHODOLOGY.org) Stage 3 + [`CRITIQUE_METHODOLOGY.org`](principles/CRITIQUE_METHODOLOGY.org)
**Critique target**: [`2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md`](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) (D.2; commit `2a4d938c`)
**Status**: D.2.SC — findings drafted; resolution review with user pending; D.3 incorporates accepted findings

---

## §1 Purpose and scope

Per CRITIQUE_METHODOLOGY § Integration with Design Methodology: D.2 self-critique applies P/R/M/S lenses BEFORE circulating for external review. This document is the persistent paper trail. Findings tagged with lens code (P/R/M/S) + sequential number for traceability.

**Critique scope** — all major D.2 design decisions:
- The hybrid pivot architecture for Phase 1C (D.2's most significant commit)
- γ-bundle-wide scope (Q-A3 / D.1 §1.2)
- Multi-quantale composition NTT (Q-Open-3 β / D.1 §4.2)
- Phase 3C cross-reference capture (Q-Open-2 / D.1 §6.5)
- SRE lattice lens analysis (D.1 §14.4)
- NTT model extensions (D.1 §4)
- Phase 1V VAG structure (D.1 §11; D.2 updates)

**Seed**: 5 forward-captured adversarial questions from D.2 §17 (numbered Q1-Q5 below). The critique expands beyond the seed.

---

## §2 Methodology (TWO-COLUMN adversarial framing)

Per CRITIQUE_METHODOLOGY § Cataloguing Instead of Challenging: cataloguing is the DEFAULT failure mode. Each finding has TWO COLUMNS:

- **Column 1 (catalogue)**: the check passes / doesn't pass
- **Column 2 (challenge)**: could this be MORE aligned? What inherited pattern was preserved without challenge?

If Column 2 has no entries, the gate WAS NOT applied adversarially.

**Red-flag patterns to scrutinize** (per CRITIQUE_METHODOLOGY):
- "preserved for backward-compat"
- "for symmetry" / "for safety" / "for testing"
- "with-handlers" / defensive guards
- "constraint imposed by X" where X is itself off-network

**Finding format**:
```
[Lens][N]: [Decision being critiqued]

  Column 1 (catalogue): [does it pass the check?]
  Column 2 (challenge): [could this be MORE aligned? What's preserved without challenge?]

  Severity: BLOCKING / REFINEMENT / ACKNOWLEDGE / PUSHBACK
  → Resolution: [proposed action]
```

**Severity definitions**:
- **BLOCKING**: D.3 must address before Stage 4 implementation; reflects a genuine design defect or principle violation
- **REFINEMENT**: D.3 should improve design language or add captures; doesn't block Stage 4
- **ACKNOWLEDGE**: legitimate concern but defer to per-phase mini-design+audit (the recurring pattern of "right place for the question")
- **PUSHBACK**: critique premise is wrong or based on misunderstanding; D.3 should respond with grounded counter

---

## §3 Lens P — Principles Challenged

The P lens forces each major decision through the 10 load-bearing principles + the workflow.md red-flag patterns. Where could the design be MORE aligned?

### P1 — Hybrid pivot's "decomplection" framing vs Cell-as-Single-Source-of-Truth

**Decision**: D.2 §10.1 frames the hybrid pivot as "decomplection of fast-path optimization (struct-copy + inline check) from architectural substrate (cell + threshold propagator)." Decrement sites preserve struct field; cell is for Phase 3C consumers.

**Column 1 (catalogue)**: ✓ "different code paths" claim is consistent with Decomplection principle (DESIGN_PRINCIPLES.org § Decomplection).

**Column 2 (challenge)**: Cell-as-Single-Source-of-Truth is a load-bearing principle (DESIGN_PRINCIPLES.org § Propagator-First Infrastructure: "Default to propagator cells over mutable hash tables"; § Correct by Construction: derived state always consistent with source state). Under hybrid, the **struct field IS the live state** for fuel-cost tracking; the cell is derived (synced lazily at semantic transitions). The principle's STATEMENT — cell is primary, derived state propagates from it — is INVERTED under hybrid. The "DIFFERENT code paths" framing names the staleness gap as architectural decomplection, but the underlying violation is: the live state lives off-network (struct field), and a cell mirrors it sporadically. This is the `make-parameter` with hasheq red flag from on-network.md, just with `struct-copy` of `prop-net-cold` instead of `make-parameter`.

**Severity**: REFINEMENT (not BLOCKING). The decomplection framing is principled IF the staleness contract is exhaustively enumerated (Q-1C-3 deferred to mini-design); but the principle inversion deserves explicit acknowledgment in D.3.

→ **Resolution**: D.3 should explicitly acknowledge: "Under the hybrid pivot, the struct-field `prop-net-cold-fuel` is the LIVE STATE for fuel-cost; the cell is DERIVED via lazy sync at semantic transitions. This inverts the typical Cell-as-Single-Source-of-Truth pattern. The justification: per Pre-0 R-19, ANY architecture that makes the cell primary at per-decrement granularity triggers major GC pressure (architectural failure under R3 baseline). The decomplection is empirically forced, not a stylistic choice. **Subject to retirement when self-hosted Prologos with a different runtime makes per-decrement cell-write GC-friendly** (Track 4D / SH Series consideration; explicitly tracked as scaffolding-with-retirement-plan, NOT a permanent pattern)."

This honest framing transforms the hybrid from "decomplection" (which sounds permanent) to "scaffolding pending runtime infrastructure" (which has a retirement plan).

### P2 — "Belt-and-suspenders is a blocking red flag" (workflow.md)

**Decision**: D.2 §10.2 says struct field `prop-net-cold-fuel` + macro `prop-network-fuel` are PRESERVED alongside the new fuel-cost-cell + threshold propagator.

**Column 1 (catalogue)**: ✓ Hybrid argues the mechanisms address DIFFERENT code paths (per-decrement HOT vs Phase 3C consumer). Not the same code path with two mechanisms.

**Column 2 (challenge)**: workflow.md anti-pattern: "When you find yourself keeping the OLD mechanism alongside a NEW mechanism 'for safety', STOP." The defense — "different code paths with different performance profiles" — is the EXACT shape of "for safety." Test: if the cell and the struct field could be unified (single source of truth with appropriate caching), would the design accept that? If "no" and the reason is "performance," then the dual mechanism IS the "old preserved alongside new for performance" anti-pattern, only with "performance" instead of "safety" as the rationale. Per workflow.md: "Bug in new mechanism is hidden because the old still 'works' for the test case."

The specific risk: Phase 1B implementation lands; M7 microbench-claim verification (per §9.10 / §11.3) shows cell-write IS fast enough. We then discover the hybrid was overengineered — but by then the dual mechanism is shipped, the test case "works for both," and the redundancy is permanent.

**Severity**: REFINEMENT. Not BLOCKING because the empirical evidence (R-19) genuinely shows GC failure at full migration; but the framing should call out the risk explicitly.

→ **Resolution**: D.3 should add an empirical-validation gate: "Phase 1B close re-microbenches M7 (cell-write vs struct-copy). IF cell-write is within 50% of struct-copy at per-decrement rate AND R3 GC profile under cell-write stays at zero major-GC, THEN the hybrid pivot is reconsidered — the struct field is retired, the cell becomes the single source of truth. The hybrid is the FALLBACK for the case where measurement shows the full migration unworkable, not the default."

This transforms hybrid from "default architecture" to "empirically-bounded fallback architecture with reconsider-on-evidence gate."

### P3 — "Validated ≠ Deployed" (workflow.md)

**Decision**: Under hybrid, the cell substrate is INSTALLED (allocated + threshold propagator wired) but does not carry per-decrement information flow. Decrement sites use struct-copy.

**Column 1 (catalogue)**: ✓ The cell substrate IS deployed for Phase 3C consumer paths (UC1/UC2/UC3 read the cell at semantic-phase granularity). It's not a feature flag defaulting to off.

**Column 2 (challenge)**: workflow.md "Validated Is Not Deployed": "When new infrastructure is built alongside old infrastructure, a common pattern emerges: the new path is validated (all tests pass) and the track is declared complete — but the parameter controlling the switch defaults to the OLD path." Under hybrid, the PER-DECREMENT path defaults to OLD (struct-copy). The new path (cell substrate) is "validated alongside" but only carries CONSUMER traffic, not DECREMENT traffic. The hot path stays on the old mechanism; the new mechanism is ceremonial for the hot-path concern that motivated the design.

The specific concern: future maintainers see "fuel-cost-cell + threshold propagator installed" and assume fuel-tracking is on-network. They write Phase 3C consumer code that reads the cell. The cell is stale (only synced at semantic transitions). The Phase 3C consumer's behavior is incorrect because the live state was off-network all along.

**Severity**: BLOCKING for D.3 (architectural staleness contract must be explicit). REFINEMENT for D.2 (the staleness is acknowledged in §10.1 + D-1C-6).

→ **Resolution**: D.3 explicit "Cell Staleness Contract" section in §10:
> The fuel-cost-cell value lags the struct-field by at most one semantic transition. Phase 3C consumers MUST either (a) accept the staleness and reason about cost-as-of-last-transition, or (b) trigger an explicit sync via `(net-fuel-cost-sync net)` before reading. The contract is enforced at the API surface — `net-fuel-cost-read` returns the cell value (potentially stale); `net-fuel-cost-read/synced` triggers sync first.

The contract makes staleness a typed property of the API, not a hidden trap.

### P4 — "Pragmatic" hidden under "decomplection"

**Decision**: D.2 calls the hybrid pivot "principled decomplection of fast-path from substrate." Per workflow.md "'Pragmatic' Is a Rationalization for Incomplete," the discipline is: replace "pragmatic" with "incomplete" and see if the rephrased sentence still feels acceptable.

**Column 1 (catalogue)**: ✓ "Decomplection" is a load-bearing principle (DESIGN_PRINCIPLES.org § Decomplection). Naming a design choice as "decomplection" is principled.

**Column 2 (challenge)**: Apply the test. "The hybrid pivot is INCOMPLETE migration — decrement sites preserve struct field because cell-write at per-decrement rate triggers major GC under current Racket runtime." Does this rephrasing feel acceptable? **Yes — it does**, because it names the specific blocker (Racket runtime GC behavior at high per-decrement cell-write rate). The completed migration is BLOCKED by a runtime concern, not by design choice.

**Severity**: REFINEMENT. The rephrased framing is more honest and aligns with the "deferred to Track N because [specific dependency]" pattern from workflow.md.

→ **Resolution**: D.3 reframe Phase 1C scope language:
- BEFORE (D.2): "Phase 1C INTRODUCES the canonical tropical fuel substrate as architectural foundation for Phase 3C consumers... WITHOUT migrating the per-decrement hot path."
- AFTER (D.3): "Phase 1C INTRODUCES the canonical tropical fuel substrate. Per-decrement hot-path migration is INCOMPLETE — deferred to SH Series (self-hosted runtime with GC characteristics suitable for per-decrement cell-write rate; tracked at DEFERRED.md). The substrate IS deployed for Phase 3C consumer paths (semantic-phase granularity); the per-decrement path remains on struct-copy until runtime infrastructure permits."

This is honest about WHAT'S deferred, WHY (specific dependency), and WHERE (DEFERRED.md tracking).

### P5 — γ-bundle-wide scope vs Conversational Cadence rule

**Decision**: D.2 §1.2 + Q-A3: γ-bundle-wide bundles 1A-iii-b (~250-400 LoC deletion) + 1A-iii-c (~600-1000 LoC deletion across 14 files) + 1B (~150-250 LoC new) + 1C (~10-50 LoC under hybrid) + 1V. Total: ~1010-1700 LoC.

**Column 1 (catalogue)**: ✓ γ-bundle-wide is a DESIGN scope decision; implementation can be sub-phased per Stage 4 Per-Phase Protocol.

**Column 2 (challenge)**: workflow.md "Conversational implementation cadence: Max autonomous stretch ~1h or 1 phase boundary." 1A-iii-c alone is 14-file pipeline retirement = at minimum ~3-5 sub-phases. Bundling it with 1B + 1C means Phase 1 has ~10+ implementation sub-phases. Is this still "γ-bundle-wide" or has it become "γ-bundle-massive"? The conversational cadence rule applies at sub-phase granularity, not phase granularity, so the rule isn't violated — but the framing of "bundle Phase 1 atomically via 1V" obscures the actual sub-phase count.

**Severity**: ACKNOWLEDGE. Not a principle violation; just a framing precision concern.

→ **Resolution**: D.3 §1.2 add a sub-phase count estimate: "γ-bundle-wide bundles ~12-15 implementation sub-phases (1A-iii-b: ~5 sub-phases; 1A-iii-c: ~8 sub-phases; 1B: ~3 sub-phases; 1C: ~5 sub-phases under hybrid; 1V: 1 atomic close). Each sub-phase respects conversational cadence (max ~1h)."

### P6 — "Future PReduce series inherits" framing (D.1 §6.6)

**Decision**: D.2 cross-cutting concerns matrix (§6.6) lists "Future PReduce series — Inherits tropical quantale primitive — First production landing establishes pattern."

**Column 1 (catalogue)**: ✓ The pattern-establishment claim is principled — first instantiations DO establish patterns for downstream consumers.

**Column 2 (challenge)**: The "first production landing" framing was load-bearing for the user direction "this will be the first instantiation of optimization as tropical quantales in our architecture that it deserves the most careful considerations." But under the hybrid pivot, Phase 1C's actual production code change (per R1 below) is small. The "first production landing" sets PATTERNS for downstream, but the patterns being established are: "introduce cell substrate alongside preserved off-network fast-path mechanism." Do we want this hybrid pattern as the template for future PReduce / OE Series consumers?

**Severity**: REFINEMENT. The pattern question deserves explicit consideration.

→ **Resolution**: D.3 §6.6 update PReduce/OE row: "First production landing establishes pattern. **Under hybrid pivot**: the pattern is 'cell substrate co-exists with off-network fast-path until runtime supports full migration.' Future PReduce / OE consumers should design to TARGET full cell-substrate migration (per the original D.1 framing) and only fall back to hybrid pattern if measurement shows runtime constraints. The hybrid is a SCAFFOLDING pattern, not the architectural target."

---

## §4 Lens R — Reality-Check (Code Audit)

The R lens grounds design claims in the actual codebase. What scope claims don't match what the code actually says?

### R1 — Phase 1C actual code change is very small under hybrid

**Decision**: D.2 §10 frames Phase 1C as "Canonical BSP fuel substrate (hybrid pivot architecture)." Sub-phase plan reduced from 9 to 5 sub-phases.

**Column 1 (catalogue)**: ✓ The sub-phase plan IS reduced; this is honestly reflected in §10.4.

**Column 2 (challenge)**: Quantitative reality check. Under hybrid:
- 1C-i Pre-impl audit: ~0 LoC (reading)
- 1C-ii Allocate cells in make-prop-network + install threshold propagator: ~10-20 LoC NEW
- 1C-iii On-exhaustion cell-write at decrement sites + saved-fuel sync + pretty-print update: ~15-30 LoC modified
- 1C-iv Selective read-as-value migration + new Phase 3C UC tests: ~20-40 LoC modified + new tests
- 1C-v Verification + close: ~0 LoC

Total: ~45-90 LoC change. Compare to D.1 §1.2 estimate "Phase 1C ~250-400 LoC across propagator.rkt + scattered." That estimate is now WAY off; under hybrid, Phase 1C is one of the smallest sub-phases in the bundle.

**Severity**: REFINEMENT. The estimate is stale; D.3 should reflect the new scope.

→ **Resolution**: D.3 §1.2 update Phase 1C estimate to ~45-90 LoC. Add commentary: "Phase 1C's small code-change footprint under hybrid is the empirical consequence of preserving the per-decrement hot path. The design weight is in the architectural framing (cell substrate + threshold propagator + staleness contract + Phase 3C consumer API), not in code volume."

### R2 — 17 production refs to `prop-network-fuel` under hybrid all PRESERVED

**Decision**: D.2 §10.2 says all 17 production refs preserved under hybrid; only typing-propagators saved-fuel + pretty-print + 3 read-as-value sites get touched.

**Column 1 (catalogue)**: ✓ The audit grounding is preserved from D.1 §2.2 Q-Audit-1.

**Column 2 (challenge)**: Per the audit, the 17 production refs are "4 decrement + 11 check + 3 read-as-value + 1 macro-defining call." Under hybrid: decrement (4) preserved; check (11) preserved; read-as-value (3) selectively migrated; macro definition preserved. So the audit framing of "17 production refs to migrate" was relevant to D.1's full-migration design but isn't really the right scope under D.2's hybrid. The Q-Audit-1 finding is being CARRIED FORWARD without reframing for the new scope.

**Severity**: REFINEMENT.

→ **Resolution**: D.3 §10.2 add: "Under hybrid pivot, Q-Audit-1's 17 production refs are categorized: 15 PRESERVED (4 decrement + 11 check + macro definition + most read-as-value) — no migration; 2-3 SELECTIVELY MIGRATED (read-as-value sites at semantic-transition paths). The original audit count is REFERENCE for completeness; the actual migration scope is much smaller per hybrid scope."

### R3 — "Semantic transition" enumeration is incomplete

**Decision**: D.2 §10.1 + Q-1C-3 deferred to mini-design enumerate "semantic transitions" where cell sync occurs: start of phase / exhaustion-write / save-restore / Phase 3C UC explicit query / on-exhaustion.

**Column 1 (catalogue)**: ✓ Q-1C-3 is named as deferred; "deferred to per-phase mini-design+audit" is the principled pattern (per user's workflow direction).

**Column 2 (challenge)**: But the staleness contract (per P3 resolution) needs the enumeration to be EXHAUSTIVE for Phase 3C consumer correctness. What's missing from the named transitions:
- BSP round boundaries (within a single elaboration)?
- Topology-stratum transitions (when new cells/propagators are added)?
- Sub-phase boundaries within a single command processing?
- Speculative-rollback boundaries (per `with-speculative-rollback` retirement scope)?
- Inter-test boundaries (per-test fuel reset semantics)?

If the enumeration isn't exhaustive at Phase 1C-iii mini-design, Phase 3C consumers may discover "semantic transition" doesn't cover their use case post-implementation.

**Severity**: ACKNOWLEDGE → must be exhaustively enumerated at 1C-iii mini-design (per Q-1C-3) BEFORE Phase 1C-iv. D.3 should be explicit about this gate.

→ **Resolution**: D.3 §10.7 strengthen Q-1C-3: "Cell-update cadence — enumerate ALL semantic transitions (this enumeration is BLOCKING for Phase 1C-iv); list at least: start of phase / end of phase / exhaustion-write / save/restore boundaries / BSP round boundaries / topology-stratum transitions / sub-phase boundaries / speculation rollback / inter-test boundaries / Phase 3C UC explicit query sites. For each: is the cell synced? What's the staleness bound? Resolve at 1C-iii mini-design with code in hand."

### R4 — Phase 1B close microbench-claim verification list

**Decision**: D.2 §11.3 Phase 1V exit criteria includes "Pre-0 microbench claims verified (re-microbench M7+M8+M13 to confirm per-decrement cycle preserved; M10+M11+M12+R4 from Phase 1B implementation checklist at §9.10)."

**Column 1 (catalogue)**: ✓ Microbench-claim verification is per the codified rule (DEVELOPMENT_LESSONS.org § Microbench-Claim Verification Pays Off Across Sub-Phase Arcs).

**Column 2 (challenge)**: §11.3 names M7+M8+M13+M10+M11+M12+R4. Missing from the list:
- A7 (high-frequency decrement) — load-bearing for "per-decrement cycle preserved" claim at scale
- A9 (speculation rollback) — load-bearing for "no leak under hybrid" claim
- E7 (probe baseline) — load-bearing for full-pipeline regression check
- E8 (deep-id stress) — Pre-0 finding 13 said "hybrid pivot CRITICAL here"; verification needs explicit re-bench

If these are not re-microbenched, "claims landed" can't be verified.

**Severity**: REFINEMENT.

→ **Resolution**: D.3 §11.3 expand Phase 1V exit criteria microbench list: M7+M8+M13 (per-decrement cycle); M10+M11+M12 (Phase 1B substrate); R4 (cell layout); A7+A9 (memory pressure + speculation); E7+E8 (full-pipeline). 11 microbench re-runs at Phase 1V close. The list is comprehensive for the "did the perf claims land" verification.

---

## §5 Lens M — Propagator-Mindspace

The M lens challenges for imperative "step-think" disguised as on-network design. Where does the cell-substrate framing hide imperative ordering?

### M1 — Threshold propagator under hybrid is propagator-as-decoration

**Decision**: D.2 §10.1 says threshold propagator is "installed as the structural guarantee that contradiction-on-exhaustion routes through the propagator network for any path that updates the cell." Under hybrid, cell-writes are RARE events.

**Column 1 (catalogue)**: ✓ The propagator IS installed; on cell-write it fires; on exhaustion (rare) it writes contradiction. The information flow exists structurally.

**Column 2 (challenge)**: Per the Network Reality Check (`workflow.md`):
1. Which `net-add-propagator` calls? — 1 (threshold propagator at make-prop-network setup)
2. Which `net-cell-write` calls produce the result? — At decrement sites detecting exhaustion (rare events)
3. Can you trace: cell creation → propagator installation → cell write → cell read = result?

Under hybrid, the propagator fires only on rare exhaustion events. For 99.999%+ of decrements, the propagator does nothing. It's "installed for architectural symmetry" — but does it actually CARRY information flow on the per-decrement timescale? **No.** The decrement-site decides exhaustion via inline check; the cell-write + propagator-fire chain is the AFTERMATH of the decision, not the decision itself. The decision IS imperative (`if (>= new-fuel-cost budget) ...`).

This is the same shape as PPN Track 4's failure mode: data structures and propagator vocabulary that wraps imperative dispatch. The propagator is structurally present but doesn't carry the load-bearing computation.

**Severity**: BLOCKING for D.3. Either:
- (a) Acknowledge the threshold propagator is decorative under hybrid, with a retirement plan (e.g., "when SH Series migrates fuel tracking on-network, the threshold propagator becomes load-bearing"), OR
- (b) Reframe the threshold propagator's role honestly: "structural guarantee for non-decrement-site cell-write paths; specifically, Phase 3C consumer paths that mutate the fuel cell." The decoration framing is REPLACED with a genuine information-flow role for the consumer paths.

→ **Resolution**: D.3 §10 add explicit subsection "The threshold propagator's role under hybrid":
> Under hybrid, the threshold propagator does NOT carry per-decrement information flow (decrement sites use inline check + struct-copy; the cell isn't written per-decrement). The propagator's load-bearing role is for **non-decrement-site cell-write paths**:
> 1. Phase 3C consumer paths that update fuel cost (e.g., UC1 walks accumulating cost across propagator dependency chains)
> 2. On-exhaustion path (decrement site detects exhaustion, writes final cost to cell, propagator fires)
> 3. Speculation rollback restoring cell value
>
> For per-decrement information flow on the hot path: NOT propagator-mediated under hybrid. This is acknowledged scaffolding pending SH Series runtime support.

This honest framing gives the propagator a real role (the consumer paths) while acknowledging the hot-path decoration.

### M2 — "Decrement site decides to write cell on exhaustion" is imperative dispatch

**Decision**: D.2 §10.3 "On exhaustion (decrement site detects cost >= budget)" pattern: decrement site has inline check; on exhaustion, decrement site writes final cost to cell to trigger threshold propagator.

**Column 1 (catalogue)**: ✓ The pattern is documented; on-exhaustion routing through propagator network is named.

**Column 2 (challenge)**: The decrement site IS deciding (`if (<= new-fuel 0) ...`) which path to take. That's imperative dispatch. The propagator-mindspace alternative would be: decrement site writes the new cost to the cell unconditionally; the threshold propagator detects exhaustion via cell value; firing emerges from the cell state, not from the decrement site's decision. Under hybrid, we're choosing imperative dispatch for performance — the cost of unconditional cell-write would be the per-decrement propagator-fire cost (per Pre-0 M-2).

So the pattern IS imperative; the framing should acknowledge it. Per `propagator-design.md` "Information vs. instruction": "Does the design describe what information flows where (declarative), or what steps happen in what order (imperative)?"

**Severity**: REFINEMENT.

→ **Resolution**: D.3 §10.3 reframe the on-exhaustion pattern explicitly:
> The decrement site's `(<= new-fuel 0)` check IS imperative dispatch. The propagator-mindspace ideal would be unconditional cell-write with propagator-emergent exhaustion; this is INFEASIBLE under hybrid (per Pre-0 R-19 GC pressure). The hybrid CHOOSES imperative dispatch for the hot-path; the cell + propagator handle the rare-event consumer paths emergently.

### M3 — "Cell-update cadence at semantic transitions" is imposed ordering

**Decision**: D.2 §10.1: cell value updated at SEMANTIC TRANSITIONS (start of phase / exhaustion-write / save/restore boundaries) — NOT per-decrement.

**Column 1 (catalogue)**: ✓ The cadence is named; per Q-1C-3 the enumeration is deferred to mini-design.

**Column 2 (challenge)**: "Semantic transitions" are POINTS IN TIME defined by control flow. "Update at start of phase" is imperative ordering imposed on the cell-update mechanism. The propagator-mindspace alternative: the cell value is monotonically computed from the struct field via a derived-cell pattern (e.g., a "cost-monitor" propagator watching the struct field via some bridge mechanism); the cell value updates EMERGENTLY when the struct field changes, with appropriate batching to amortize overhead.

But that bridge is exactly what the hybrid avoids. So the "semantic-transition cadence" IS imposed ordering. Per `propagator-design.md` "Emergent vs. imposed ordering": "Does the execution order emerge from dataflow dependencies, or is it imposed by the design?"

**Severity**: ACKNOWLEDGE — the imposed ordering is the consequence of the imperative-dispatch hot-path (M2). Naming the connection clarifies the design.

→ **Resolution**: D.3 §10.1 add: "The cell-update cadence (semantic-transition-only) is IMPOSED ORDERING, not emergent from dataflow. This is the consequence of preserving struct-field as live state (per M2 + R-19): without per-decrement cell-write, the cell's update points must be imperatively chosen. The trade-off is explicit: imposed ordering (lose mantra alignment at hot-path) vs major-GC-risk (lose runtime feasibility). Hybrid chooses the former."

---

## §6 Lens S — Structural

The S lens applies SRE / PUnify / Hyperlattice + Hasse / Module-theoretic / Algebraic-structure-on-lattices analysis. **LOAD-BEARING for this addendum** per CRITIQUE_METHODOLOGY mandate (quantale algebra is a major structural target).

### S1 — §14.4 SRE lattice lens Q5 (PRIMARY/DERIVED) is INCONSISTENT with hybrid

**Decision**: D.1 §14.4 Q5 says "PRIMARY for fuel-cost tracking; cells over the quantale are PRIMARY storage."

**Column 1 (catalogue)**: ✓ §14.4 was written under D.1's full-migration assumption.

**Column 2 (challenge)**: Under D.2 hybrid, the **struct field is the live state** (per P1 challenge). The cell is DERIVED via lazy sync at semantic transitions. Q5's classification flips: cell is DERIVED, struct field is PRIMARY for fuel-cost. **§14.4 was NOT updated in D.2.** This is a direct inconsistency between §10 (hybrid pivot) and §14.4 (full-migration SRE analysis).

**Severity**: BLOCKING for D.3 — §14.4 must be updated to reflect hybrid pivot consistently.

→ **Resolution**: D.3 §14.4 update Q5 entry:
> | Q5 Primary/Derived | **Under D.1's full-migration design**: PRIMARY for fuel-cost tracking; cell is PRIMARY storage. **Under D.2 hybrid pivot**: struct-field `prop-net-cold-fuel` is PRIMARY (live state); cell is DERIVED (lazy sync at semantic transitions per P1 + R3). The classification inversion is explicit; under SH Series runtime, primary inverts back to cell. |

Also update Q3, Q4, Q6 if they assumed full migration:
- Q3 Bridges: Galois bridge to TypeFacetQ projects from the cell; under hybrid, that projection is from POSSIBLY-STALE state. Bridge correctness depends on staleness contract (P3).
- Q4 Composition: TypeFacetQ + TropicalFuelQ co-existence holds; tagged-cell-value semantics under hybrid where the cell receives few writes still composes (single-value lattice element per worldview).
- Q6 Hasse diagram: linear chain visited at semantic-transition values, not per-decrement values; the lattice ordering is preserved (subset of values still totally-ordered) but the granularity is coarser. Compute topology unchanged (trivially parallel).

### S2 — Threshold propagator with `:fires-when` extension that doesn't exist yet

**Decision**: D.1 §4.1 declares `propagator tropical-fuel-threshold :fires-when (>= fuel-cost budget)` with extension-note "NTT extension: `:fires-when` (predicate) — runtime-condition-gated fire — Generalizes existing `:fires-once-on-threshold`; flagged in D.3 §4.5 as refinement candidate."

**Column 1 (catalogue)**: ✓ The extension is FLAGGED as refinement candidate; not a hidden extension.

**Column 2 (challenge)**: Under hybrid (D.2 §10), the threshold propagator's role is "fire on cell-write, check `(>= cost budget)`, write contradiction if exhausted." Under D.2's DECORATION framing (M1), this is a fire-then-conditional-write pattern. The `:fires-when` NTT extension would let us declare "fire ONLY when condition holds" — but under hybrid, we don't actually need that, because cell-writes are rare and unconditional cost-then-contradiction-write semantic is fine.

So the `:fires-when` extension is NOT load-bearing under hybrid. The threshold propagator can be expressed in current NTT vocabulary (existing :fires-once-on-threshold or unconditional fire with predicate body).

**Severity**: REFINEMENT — the NTT extension claim is overstated for the hybrid scope.

→ **Resolution**: D.3 §4.1 update extension-note: "Under D.1's full-migration design, `:fires-when` would prevent per-decrement threshold checks at the scheduler level. Under D.2 hybrid pivot, cell-writes are rare; the threshold propagator can use existing `:fires-once-on-threshold` semantics (or unconditional fire with predicate body in fire-fn). The `:fires-when` NTT extension is no longer load-bearing for THIS addendum; it remains a future NTT refinement candidate for tracks where per-event filtering at scheduler level is performance-critical."

### S3 — Multi-quantale composition NTT: bridge declared-but-not-implemented

**Decision**: D.1 §4.2 declares `bridge type-cost-bridge :alpha [TypeFacetQ -> TropicalFuelQ] :gamma [TropicalFuelQ -> TypeFacetQ] :preserves [Galois]`.

**Column 1 (catalogue)**: ✓ The bridge is declared structurally; quantale-of-bridges composition pattern documented.

**Column 2 (challenge)**: A bridge declaration without α/γ implementation is structurally a TODO. The "multi-quantale composition NTT" claim is weaker than framing suggests — we have:
- TypeFacetQ as a Q-module (shipped via SRE 2H)
- TropicalFuelQ as a Q-module (this addendum's substrate)
- A DECLARATION that they connect via type-cost-bridge

But the COMPOSITION isn't actually computable until α/γ are implemented (deferred to Phase 3C). So "multi-quantale composition NTT" in D.1's §4 is structurally:
- ✓ Two Q-modules co-exist (computable today)
- ⬜ Bridge composition (NOT computable until Phase 3C UC2 implements α/γ)
- ⬜ Quantale-of-bridges (NOT computable; depends on bridge implementation)

The NTT model is COMPLETE in the sense that it declares what would compose; it's INCOMPLETE in the sense that the composition isn't computationally realized.

**Severity**: REFINEMENT.

→ **Resolution**: D.3 §4.2 add explicit completeness statement:
> The multi-quantale composition NTT model declares the composition pattern + bridge interface. Computational realization is partial:
> - ✓ Q-module co-existence (this addendum)
> - ⬜ Bridge α/γ implementation (Phase 3C UC2 consumer)
> - ⬜ Quantale-of-bridges composition (future PReduce / OE Track 1 multi-cost-currency tracking)
>
> The model is LOAD-BEARING for downstream design (gives Phase 3C UC2 the type-level interface to implement against); it is NOT a runtime-realized composition until Phase 3C lands.

### S4 — Quantaloids out-of-scope creates partial-abstraction risk

**Decision**: D.1 §1.3 + §4.4: "Quantaloids (out of scope) — when multi-domain cost currencies emerge (memory + messages + time), the quantale-of-quantales pattern (Stubbe 2013) becomes load-bearing."

**Column 1 (catalogue)**: ✓ Quantaloids out-of-scope is explicit; rationale stated; trigger-condition ("multi-domain cost currencies") named.

**Column 2 (challenge)**: But this addendum SHIPS multi-quantale composition NTT (TypeFacetQ + TropicalFuelQ). If we know the future generalization is quantaloids, are the multi-quantale primitives we're shipping today FORWARD-COMPATIBLE with quantaloids? Or will we have to redo the composition pattern when quantaloids land?

Per S-lens "Algebraic structure on lattices": multi-quantale composition without quantaloid-readiness is shipping an ad-hoc pair-of-quantales pattern. The bridge between Q1 and Q2 is a Galois connection; the bridge between (Q1, Q2) and Q3 needs the quantale-of-quantales structure. If we don't account for this in §4.2, we're shipping a partial abstraction.

**Severity**: REFINEMENT.

→ **Resolution**: D.3 §4.2 + §4.4 forward-compatibility check:
> The multi-quantale composition pattern shipped here (`bridge :alpha :gamma :preserves [Galois]`) is forward-compatible with quantaloids: a quantaloid extends the bridge composition with an extra layer (quantale-of-quantale-of-bridges); the primitives we ship today (Q-module + Galois bridge) are quantaloid-natural. When future tracks add 3rd+ quantale instances (MemoryCostQ, MessageCountQ), the composition pattern extends without breaking the type-cost-bridge interface.

This is a forward-compatibility VERIFICATION (not a new feature), and it makes the abstraction's incrementality explicit.

### S5 — SRE registration's quantale property declarations validation

**Decision**: D.1 §9.4 declares quantale + commutative-quantale + unital-quantale + integral-quantale + residuated + has-pseudo-complement in the SRE domain registration.

**Column 1 (catalogue)**: ✓ Property declarations are exhaustive; per Stage 1 research §9.2 quantale axioms are well-grounded.

**Column 2 (challenge)**: SRE domain registration runs property INFERENCE at registration to verify declared properties. Per D.1 §9.4: "Property inference (per Phase 2 of PPN 4C tradition): runs explicitly at registration to verify quantale laws (commutativity, associativity, idempotence, distributivity, residuation laws). Per Track 3 §12 + SRE 2G precedent, expect ≥1 lattice-law verification finding (possibly 0 since quantale axioms are well-grounded)."

But quantale laws involve `tropical-tensor` (= `+`) and `tropical-fuel-merge` (= `min`) at SCALE — distributivity is `(+ a (min b c)) = (min (+ a b) (+ a c))`, which holds for finite numbers but may have edge cases at `+inf.0`. SRE Track 2H's property inference DID find 1+ lattice-law disproofs (per F7 distributivity disproof; mempalace.md notes). What if tropical quantale's distributivity has similar edge case?

**Severity**: ACKNOWLEDGE — Phase 1B mini-design must verify quantale laws empirically (per Pre-0 plan §5 C-series).

→ **Resolution**: D.3 §9.4 strengthen: "Phase 1B implementation MUST run C-series (Pre-0 plan §5) post-registration to verify quantale axioms hold for the actual `+` / `min` / `+inf.0` representation. Particular attention to edge cases at `+inf.0` (does `(+ +inf.0 (min b c)) = (min (+ +inf.0 b) (+ +inf.0 c))` hold? Both sides should equal `+inf.0` by absorbing-element semantics, but verify via assertion). C-series failure → critical correctness bug; halt before Phase 1C."

---

## §7 Synthesis — finding prioritization

| Finding | Lens | Severity | Key concern |
|---|---|---|---|
| P1 | P | REFINEMENT | Hybrid inverts Cell-as-Single-Source-of-Truth principle; needs explicit acknowledgment + retirement plan |
| P2 | P | REFINEMENT | Belt-and-suspenders red flag; needs empirical-validation gate at Phase 1B close |
| P3 | P | **BLOCKING** | Cell staleness contract must be explicit (typed API surface) |
| P4 | P | REFINEMENT | Reframe "decomplection" as "incomplete (deferred to SH Series)" honestly |
| P5 | P | ACKNOWLEDGE | γ-bundle scope precision (sub-phase count) |
| P6 | P | REFINEMENT | "First production landing pattern" — name hybrid as scaffolding pattern, not target |
| R1 | R | REFINEMENT | Phase 1C estimate stale; ~45-90 LoC under hybrid (was ~250-400) |
| R2 | R | REFINEMENT | 17 production refs framing carried forward without rescoping |
| R3 | R | ACKNOWLEDGE | Q-1C-3 enumeration must be exhaustive (BLOCKING for Phase 1C-iv) |
| R4 | R | REFINEMENT | Phase 1V microbench list incomplete (add A7+A9+E7+E8) |
| M1 | M | **BLOCKING** | Threshold propagator is decoration on hot path; honest reframing required |
| M2 | M | REFINEMENT | Imperative dispatch in on-exhaustion pattern; acknowledge explicitly |
| M3 | M | ACKNOWLEDGE | Imposed ordering at semantic transitions; trade-off explicit |
| S1 | S | **BLOCKING** | §14.4 Q5 PRIMARY/DERIVED inconsistent with hybrid; UPDATE required |
| S2 | S | REFINEMENT | `:fires-when` NTT extension not load-bearing under hybrid |
| S3 | S | REFINEMENT | Bridge declared-but-not-implemented; completeness statement explicit |
| S4 | S | REFINEMENT | Quantaloid forward-compatibility check |
| S5 | S | ACKNOWLEDGE | C-series quantale axiom verification at Phase 1B close (Pre-0 plan §5 already covers) |

**Counts**:
- BLOCKING (3): P3 (staleness contract), M1 (propagator decoration framing), S1 (§14.4 Q5 inconsistency)
- REFINEMENT (10): P1, P2, P4, P6, R1, R2, R4, M2, S2, S3, S4
- ACKNOWLEDGE (5): P5, R3, M3, S5, (other)

**3 BLOCKING findings** must be addressed in D.3 before Stage 4 implementation begins.
**10 REFINEMENTS** improve design language and add captures; do not block but should be incorporated.
**5 ACKNOWLEDGEs** are real concerns deferred to per-phase mini-design+audit (existing pattern).

---

## §8 Resolution proposals — D.2 → D.3 incorporation

### §8.1 BLOCKING (must address in D.3)

**P3 — Cell Staleness Contract (NEW §10 subsection)**:
- Add §10.1.5 (or similar) "Cell Staleness Contract" to D.3
- Specify: staleness bound (at most one semantic transition); API surface enforcement (`net-fuel-cost-read` returns possibly-stale; `net-fuel-cost-read/synced` triggers sync first)
- Make staleness a typed property of the API
- Cross-reference Q-1C-3 (cadence enumeration) as the load-bearing input

**M1 — Threshold propagator's role under hybrid (HONEST REFRAMING in §10)**:
- Replace "structural guarantee for any path that updates the cell" with explicit role enumeration:
  1. Phase 3C consumer paths (UC1/UC2/UC3 cell-mutating consumers)
  2. On-exhaustion path (rare; decrement-site-triggered)
  3. Speculation rollback (cell-restore via worldview narrow)
- Explicitly acknowledge: "for per-decrement information flow, the threshold propagator is NOT load-bearing under hybrid; this is scaffolding pending SH Series runtime"

**S1 — §14.4 SRE Lattice Lens update (Q5 + dependent Qs)**:
- Update Q5 to acknowledge dual classification (D.1 full-migration vs D.2 hybrid)
- Update Q3 (bridge from cell projects from possibly-stale state)
- Update Q4 (Q-module composition holds; staleness doesn't break tagged-cell-value semantics)
- Update Q6 (Hasse diagram visited at coarser granularity; lattice structure preserved)

### §8.2 REFINEMENT (incorporate but not blocking)

- **P1**: Acknowledge cell-as-single-source-of-truth inversion explicitly
- **P2**: Add empirical-validation gate at Phase 1B close (re-microbench M7; reconsider hybrid if cell-write fast enough)
- **P4**: Reframe "decomplection" as "incomplete migration deferred to SH Series" with specific blocker named (Racket runtime GC at per-decrement cell-write rate)
- **P6**: Update §6.6 PReduce/OE row to call hybrid a SCAFFOLDING pattern, not template
- **R1**: Update §1.2 Phase 1C estimate to ~45-90 LoC under hybrid
- **R2**: Reframe Q-Audit-1's 17 refs as "audit COMPLETE; under hybrid, 15 PRESERVED + 2-3 SELECTIVELY MIGRATED"
- **R4**: Expand §11.3 Phase 1V microbench list (M7+M8+M13+M10+M11+M12+R4 + A7+A9+E7+E8 = 11 re-runs)
- **M2**: Acknowledge on-exhaustion pattern is imperative dispatch (named connection to M1)
- **S2**: Update §4.1 `:fires-when` extension-note: not load-bearing under hybrid
- **S3**: §4.2 explicit "computational realization is partial" statement
- **S4**: §4.2 + §4.4 add quantaloid forward-compatibility verification

### §8.3 ACKNOWLEDGE (defer to mini-design or strengthen as gate)

- **P5**: D.3 §1.2 add sub-phase count estimate (~12-15 implementation sub-phases across γ-bundle)
- **R3**: D.3 §10.7 strengthen Q-1C-3 to BLOCKING-for-1C-iv with enumeration list (BSP rounds, topology transitions, etc.)
- **M3**: D.3 §10.1 acknowledge imposed ordering as consequence of hybrid scoping
- **S5**: D.3 §9.4 strengthen C-series gate (Phase 1B close MUST run quantale axiom verification)

### §8.4 Pushbacks (not in this critique)

No findings with PUSHBACK severity in this round — the critique surfaced concerns that have legitimate resolutions, not premise errors. This is consistent with D.2 being a thorough revision that already incorporated user direction; the BLOCKING findings are MORE granular discipline (staleness contract, propagator role, §14.4 consistency) rather than fundamental design errors.

---

## §9 Process notes

### §9.1 Adversarial framing self-check

Per CRITIQUE_METHODOLOGY § Cataloguing Instead of Challenging: "If the gate passes without challenging at least one inherited pattern, it likely catalogued — re-run with adversarial framing."

Inherited patterns this critique CHALLENGED (not just catalogued):
- ✓ Hybrid pivot's "decomplection" framing (P1, P4)
- ✓ Struct field + macro PRESERVED for "performance" (P2)
- ✓ Cell substrate "DEPLOYED" for consumer paths but not hot path (P3)
- ✓ Threshold propagator "installed for architectural symmetry" (M1)
- ✓ "Semantic transitions" as cadence (R3, M3)
- ✓ §14.4 SRE analysis carried forward without hybrid update (S1)
- ✓ Multi-quantale composition NTT computational completeness (S3)
- ✓ Quantaloids out-of-scope vs forward-compatibility (S4)

**At least 8 inherited patterns challenged; adversarial framing applied per discipline.**

### §9.2 The 5 forward-captured questions from D.2 §17 — coverage

| D.2 §17 Q | Critique finding(s) |
|---|---|
| Q1 (P): Hybrid decomplection genuinely principled? | P1 + P4 (acknowledged inversion + incomplete framing) |
| Q2 (P): Struct+macro preserved as belt-and-suspenders? | P2 (empirical-validation gate proposed) |
| Q3 (R + Q-1C-3): "Semantic transition" exhaustively enumerable? | R3 (strengthen Q-1C-3 to BLOCKING for 1C-iv) |
| Q4 (M + S): Cell staleness violates single-source-of-truth? | P3 (staleness contract) + S1 (§14.4 Q5 update) |
| Q5 (S): SRE lattice lens analysis hold under hybrid? | S1 (§14.4 update) + S4 (quantaloid forward-compat) |

All 5 forward-captured questions have at least one critique finding addressing them. Coverage ✓.

### §9.3 Pre-PIR insight — codification candidate

**Codification candidate**: "Forward-captured adversarial questions in design doc §17 transform from speculative scrutiny into self-critique seeds." 

Pattern: D.2 §17 enumerated 5 adversarial questions intentionally as forward-captures for the next critique round. D.2.SC (this document) addresses all 5 via specific findings (per §9.2 mapping). The seed-to-finding ratio was 1-to-2+ (each seed produced multiple findings as the critique expanded scope). Worth codifying after 1-2 more design cycles confirm the pattern.

---

## §10 Cross-references

- D.2 design: [`2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md`](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md)
- Pre-0 plan: [`2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md`](2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md)
- CRITIQUE_METHODOLOGY: [`principles/CRITIQUE_METHODOLOGY.org`](principles/CRITIQUE_METHODOLOGY.org)
- DESIGN_METHODOLOGY: [`principles/DESIGN_METHODOLOGY.org`](principles/DESIGN_METHODOLOGY.org)
- workflow rules: [`.claude/rules/workflow.md`](../../.claude/rules/workflow.md)
- on-network mantra: [`.claude/rules/on-network.md`](../../.claude/rules/on-network.md)
- propagator-design: [`.claude/rules/propagator-design.md`](../../.claude/rules/propagator-design.md)
- structural-thinking: [`.claude/rules/structural-thinking.md`](../../.claude/rules/structural-thinking.md)

---

## Document status

**D.2 self-critique drafted (D.2.SC)** — ready for resolution review with user.

Per CRITIQUE_METHODOLOGY § Integration: D.3 incorporates accepted findings. The user reviews this critique, decides per finding: ACCEPT (D.3 changes) / ACCEPT-PROBLEM-REJECT-SOLUTION (D.3 with our resolution) / REJECT-WITH-JUSTIFICATION (push back) / DEFER-WITH-TRACKING (DEFERRED.md entry).

**Working through the points**: each finding has a Severity + Resolution proposal. Recommended order:
1. **3 BLOCKING findings** (P3, M1, S1) — must resolve before Stage 4
2. **10 REFINEMENTS** — incorporate as D.3 changes (most are textual updates to design doc)
3. **5 ACKNOWLEDGEs** — defer to per-phase mini-design+audit OR strengthen as gates per §8.3

After review + resolution: D.3 design revision commits accepted findings. Stage 4 implementation per per-phase mini-design+audit opens next.
