# PPN Track 4C Phase 9+10+11 Addendum — Path T-3 T3-C3 Re-Audit Handoff

**Date**: 2026-04-22
**Purpose**: Transfer context from this session (1A-ii-a + 'mult SRE + 1A-ii-b attempt-revert + Path T decision + T-3 mini-design/audit/Stage3 + Commit A DELIVERED + Commit B attempted-and-paused) into a continuation session. T3-C3 systematic re-audit is the NEXT immediate work.

**Before reading anything else**: read [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org). The Hot-Load Reading Protocol requires reading EVERY §2 document IN FULL before summarizing understanding back to the user.

**CRITICAL meta-lesson carried forward**: three consecutive "accidentally load-bearing mechanism" findings in this addendum track. Stage 2 audits can miss these patterns when they only check inline predicates. T3-C3 is the systematic response — audit downstream fallback dependencies too.

---

## §1 Current Work State (PRECISE)

- **Track**: PPN Track 4C Phase 9+10+11 Addendum (Path T — lattice-first)
- **Sub-phase**: Path T-3 (type lattice set-union merge redesign)
- **Stage**: Stage 4 Implementation; Commit A ✅ delivered; Commit B ⏸️ PAUSED pending T3-C3 re-audit
- **Design document**: D.3 at [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — §7.6 houses full T-3 design; §7.6.12 + §7.6.13 are the critical NEW sections this session added
- **Last commit**: `fa1a7b9c` — dailies for pause
- **Branch**: `main`
- **Working tree**: clean — all reverts committed
- **Suite state**: probe baseline at 329d4f30 (28 expressions, 0 errors); targeted tests pass (129+89 across multiple runs); no full suite run this session

### Progress Tracker status (D.3 §3)

Key T-3 rows:

| Sub-phase | Status | Commits |
|---|---|---|
| T-3 mini-design | ✅ | `9c3172e0` |
| T-3 Stage 2 audit | ✅ **INCOMPLETE** | `6fddc5f7` — missed fallback-dependency sites |
| T-3 probe baseline | ✅ | `329d4f30` |
| **T-3 Commit A** (Role B migration + helper) | ✅ | `37aaba2b` — zero behavior change |
| **T-3 Commit B** (set-union fallthrough) | ⏸️ PAUSED | reverted; blocking finding recorded in D.3 §7.6.12 |
| **T-3 T3-C3 re-audit** | ⬜ | **NEXT TASK** — §7.6.13 criteria |

### Next immediate task

**T3-C3 systematic re-audit** per D.3 §7.6.13. Audit steps:

1. **Grep inline `(type-top? ...)` checks** that inspect `type-lattice-merge` results — original §7.6.9 found 4 sites, all migrated in Commit A (37aaba2b)
2. **Grep for `type-lattice-contradicts?` / `net-contradiction?` consumers** downstream of cells using type-lattice-merge as merge-fn. These may be relying on spurious contradictions from structural mismatch.
3. **Audit `typing-propagators.rkt:1878-1920`** (expr-union typing): writes component types instead of `[Type lv]`. Fix to write `(expr-Type (infer-level ...))` — architecturally correct AND removes the fallback dependency. This is the known-affected site.
4. **Audit OTHER `expr-foo` typing cases** in typing-propagators.rkt: grep for `type-map-write net ... tm-cid e <sub-expr>` patterns where `<sub-expr>` is the expression itself, not its TYPE. Each such site is potentially relying on merge-produces-top for correct semantics downstream.
5. **Audit cell merge-fn uses with `type-lattice-contradicts?`**: enumerate all cells allocated with `type-lattice-merge` as merge-fn + `type-lattice-contradicts?` as contradicts?. Check consumer logic for fallback dependencies.

Once audit complete:
- Migrate newly-found sites (likely to `type-unify-or-top` OR architectural fix like typing-propagators.rkt:1907/1919)
- Re-attempt Commit B (set-union fallthrough)
- Expected outcome: test-union-types passes + all other tests remain green

### Acceptance criteria for Commit B retry

- Probe (`examples/2026-04-22-1A-iii-probe.prologos`) diff = 0 against baseline
- `test-type-lattice.rkt` tests updated to expect union construction for incompatible atoms (5 assertions; see §7.6.9 + dailies 2026-04-22)
- `test-union-types.rkt:234` (infer `<Nat | Bool>` expects `[Type 0]`) PASSES — requires typing-propagators.rkt:1878-1920 fix
- Full suite green
- No other regressions

---

## §2 Documents to Hot-Load (ORDERED)

**CRITICAL**: read every document IN FULL. No skimming.

### §2.0 Start here

0. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org)

### §2.1 Always-Load

1. [`CLAUDE.md`](../../../CLAUDE.md) + [`CLAUDE.local.md`](../../../CLAUDE.local.md)
2. [`MEMORY.md`](../../../MEMORY.md)
3. [`DESIGN_METHODOLOGY.org`](../principles/DESIGN_METHODOLOGY.org) — Stage 4 Per-Phase Protocol especially
4. [`DESIGN_PRINCIPLES.org`](../principles/DESIGN_PRINCIPLES.org) — especially Correct-by-Construction + Decomplection
5. [`CRITIQUE_METHODOLOGY.org`](../principles/CRITIQUE_METHODOLOGY.org) — P/R/M/S lenses; Lens S features heavily in T-3

### §2.2 Architectural Rules

6. [`.claude/rules/on-network.md`](../../../.claude/rules/on-network.md) — design mantra
7. [`.claude/rules/structural-thinking.md`](../../../.claude/rules/structural-thinking.md) — SRE, Module Theory Realization B, PU heuristic
8. [`.claude/rules/propagator-design.md`](../../../.claude/rules/propagator-design.md) — cell allocation efficiency (the PU heuristic question user surfaced mid-session)
9. [`.claude/rules/workflow.md`](../../../.claude/rules/workflow.md) — per-commit dailies discipline
10. [`.claude/rules/testing.md`](../../../.claude/rules/testing.md) — diagnostic protocol (used extensively this session)
11. [`.claude/rules/pipeline.md`](../../../.claude/rules/pipeline.md)
12. [`.claude/rules/stratification.md`](../../../.claude/rules/stratification.md)
13. [`.claude/rules/prologos-syntax.md`](../../../.claude/rules/prologos-syntax.md)

### §2.3 Session-Specific — THE DESIGN DOCUMENT (READ IN FULL)

14. [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — **D.3, THE design**. ~1100 lines. Critical NEW sections this session added:
    - **§3 Progress Tracker** (UPDATED): T-3 sub-rows showing delivered + paused state
    - **§7.5.8** Sub-A experiment + three architectural findings → Path T pivot
    - **§7.5.9** Path T — lattice-first decision
    - **§7.6** (NEW, full) — T-3 mini-design resolution:
      - §7.6.1-§7.6.7: mini-design resolutions (Q-T3-1 through Q-T3-9)
      - §7.6.9: Stage 2 audit findings (**INCOMPLETE** — §7.6.13 enhances)
      - §7.6.10: Stage 3 design
      - §7.6.11: Stage 4 implementation (Commit A DELIVERED, Commit B PAUSED)
      - **§7.6.12** (NEW, CRITICAL): Third accidentally-load-bearing mechanism + T3-C3 decision
      - **§7.6.13** (NEW, CRITICAL): Enhanced audit criteria for T3-C3

### §2.4 Session-Specific — PRIOR ART (CRUCIAL for T-3)

15. [`racket/prologos/subtype-predicate.rkt`](../../../racket/prologos/subtype-predicate.rkt) lines 339-353 — **THE TEMPLATE**: `subtype-lattice-merge` applied set-union semantics to the SUBTYPE relation. T-3 applies the same pattern to the EQUALITY relation. Read this function carefully.

16. [`racket/prologos/union-types.rkt`](../../../racket/prologos/union-types.rkt) — `build-union-type` (line 124), `flatten-union`, `dedup-union-components`, `union-sort-key`. Used by T-3's Commit B merge fallthrough.

### §2.5 Session-Specific — TYPE LATTICE + RELATED

17. [`racket/prologos/type-lattice.rkt`](../../../racket/prologos/type-lattice.rkt) — `type-lattice-merge` (line 140; current = pre-Commit-B), **`type-unify-or-top`** (NEW this session, line ~180; encodes equality-enforcement via current merge semantics). Read both.

18. [`racket/prologos/elaborator-network.rkt`](../../../racket/prologos/elaborator-network.rkt) — 4 migrated Role B sites use `type-unify-or-top`:
    - `make-unify-propagator` (line 152-170)
    - `elab-add-unify-constraint` fast path (line 178-188)
    - `make-structural-unify-propagator` (line ~895-909)
    - `elaborator-topology stratum handler for pair-decomp` (line 1110-1141)

19. [`racket/prologos/typing-propagators.rkt`](../../../racket/prologos/typing-propagators.rkt) — **line 1878-1920** (expr-union typing): the KNOWN ARCHITECTURALLY-WRONG site. Writes component types (Nat, Bool) to position `e`'s :type facet instead of `[Type lv]`. Fix needed in T3-C3.

20. [`racket/prologos/typing-core.rkt`](../../../racket/prologos/typing-core.rkt) — line 459-462: the sexp-based `infer` for `expr-union` that CORRECTLY returns `[Type lv]` via `infer-level`. This is what the on-network path accidentally falls back to pre-Commit-B via contradiction detection.

21. [`racket/prologos/tests/test-type-lattice.rkt`](../../../racket/prologos/tests/test-type-lattice.rkt) — 5 assertions at lines 39, 72, 85, 188, 255 currently expect `type-top`; MUST UPDATE when Commit B lands. Dailies 2026-04-22 captures the exact expected-new values.

22. [`racket/prologos/tests/test-union-types.rkt`](../../../racket/prologos/tests/test-union-types.rkt) — line 234 `(infer <Nat | Bool>)` expects `"[Type 0]"`. This is the CANARY test that flagged the 3rd finding.

### §2.6 Session-Specific — PROBE + ACCEPTANCE

23. [`racket/prologos/examples/2026-04-22-1A-iii-probe.prologos`](../../../racket/prologos/examples/2026-04-22-1A-iii-probe.prologos) — 6-scenario behavioral probe (28 expressions)
24. [`racket/prologos/data/probes/2026-04-22-1A-iii-baseline.txt`](../../../racket/prologos/data/probes/2026-04-22-1A-iii-baseline.txt) — captured baseline
25. [`racket/prologos/examples/2026-04-17-ppn-track4c.prologos`](../../../racket/prologos/examples/2026-04-17-ppn-track4c.prologos) — PPN 4C acceptance file (broader regression check)

### §2.7 Session-Specific — DAILIES

26. [`docs/tracking/standups/2026-04-19_dailies.md`](../standups/2026-04-19_dailies.md) — session entries for 2026-04-21 AND 2026-04-22 (this session). Key sections:
    - 2026-04-22 top: 1A-ii-a delivered + 'mult SRE
    - 2026-04-22 mid: 1A-iii Sub-A reverted + Path T pivot
    - 2026-04-22 "T-3 mini-design RESOLVED"
    - 2026-04-22 "T-3 Stage 2 audit + Stage 3 design"
    - 2026-04-22 "T-3 Stage 4 Commit A DELIVERED + Commit B PAUSED"

### §2.8 Session-Specific — PRIOR HANDOFF (continuity)

27. [`docs/tracking/handoffs/2026-04-21_PPN_4C_PHASE_1A_HANDOFF.md`](2026-04-21_PPN_4C_PHASE_1A_HANDOFF.md) — prior session's handoff. This session picked it up; the work evolved substantially (1A-i ✅ → 1A-ii attempt 1 reverted → Sub-A reverted → Path T pivot → T-3).

### §2.9 Tracking metadata

28. [`docs/tracking/DEFERRED.md`](../DEFERRED.md)

---

## §3 Key Design Decisions (RATIONALE — do NOT re-litigate)

### §3.1 Path T decision (lattice-first) — 2026-04-22

Three architectural findings surfaced from attempt 1 + Sub-A + user observations:
1. Multiple competing sources of truth for speculation worldview
2. Map open-world typing misalignment
3. Type lattice set-union merge inadequacy

User direction: work through **T-3 first** as prerequisite; persist findings in current D.3 (not separate artifact). T-1 and T-2 defer until T-3 resolves.

### §3.2 T-3 mini-design — Z-wide + Framing C — Set-union + Role A/B + PU via compound cells

All Q-T3-1 through Q-T3-9 settled (D.3 §7.6.1-§7.6.7). Key commitments:
- Set-union merge for equality relation (mirrors subtype-lattice-merge template)
- **Decomplection of merge (Role A = accumulate) vs unify-check (Role B = enforce equality)** via `type-unify-or-top` helper
- Two atomic commits (Commit A migration, Commit B semantics change)
- PU refactor (4 per-domain universes + shared hasse-registry) deferred into 1A-iii-a-wide post-T-3
- Pre-0 behavioral probe required before + after each commit

### §3.3 T-3 Commit A delivered — 2026-04-22 (`37aaba2b`)

`type-unify-or-top` helper in type-lattice.rkt; 4 Role B sites in elaborator-network.rkt migrated. Zero behavior change validated (probe + 129 targeted tests).

### §3.4 T-3 Commit B attempted + PAUSED — 2026-04-22

Fallthrough changed from `type-top` to `build-union-type(list v1 v2)`. 5 test-type-lattice.rkt assertions updated. Probe passed. But test-union-types:234 regressed. Reverted.

### §3.5 Path T3-C3 decision — 2026-04-22

User direction: systematic re-audit before Commit B retry. Three accidentally-load-bearing findings (attempt 1, Sub-A, Commit B) confirm a PATTERN — the Stage 2 audit criteria need enhancement (D.3 §7.6.13).

---

## §4 Surprises and Non-Obvious Findings

### §4.1 Three accidentally-load-bearing mechanisms (THE critical pattern)

The addendum track has hit this pattern THREE TIMES:

1. **TMS dispatch at net-cell-write:1248** (attempt 1, 2026-04-21) — `tms-write old '() new` updated BASE regardless of `current-worldview-bitmask` because TMS path uses `current-speculation-stack` (= `'()`). When migrating type cells to tagged-cell-value, this bypass disappears; speculative writes now tag entries per branch instead of updating base. Discovered via Sub-A diagnostic.

2. **`with-speculative-rollback` bitmask scaffolding** (Sub-A, 2026-04-22) — the function parameterizes `current-worldview-bitmask` AND writes to worldview-cache-cell PLUS saves elab-net snapshot. Under TMS path, the bitmask writes were ignored (TMS bypass above), so only the snapshot was load-bearing. Under tagged-cell-value, both mechanisms activate simultaneously, breaking try-rollback semantics.

3. **expr-union typing's merge-produces-top fallback** (Commit B, 2026-04-22) — at typing-propagators.rkt:1907/1919, writes of COMPONENT types to position `e`'s :type facet result in `type-lattice-merge(Nat, Bool) = type-top` pre-T-3. Downstream path detects type-top → falls back to sexp `infer` → returns `[Type 0]` correctly. Under set-union merge, no contradiction signal → no fallback → returns the union (garbage as the TYPE of a union-type expression).

**Principle** (to codify):
> Contradiction-detection-as-fallback is a hidden Role B pattern. Stage 2 audits must check downstream dependencies (not just inline predicates). Three instances = pattern.

### §4.2 subtype-lattice-merge is THE template

SRE Track 2H applied set-union redesign to the SUBTYPE relation months ago (subtype-predicate.rkt:339-353). T-3 applies the same pattern to the EQUALITY relation. The STRUCTURAL DIFFERENCE is one condition: subtype has `subtype?` absorption (comparable types absorb), equality only has `equal?` absorption.

### §4.3 Probe diff doesn't catch everything

Commit B's probe diff was 0, but test-union-types regressed. The probe covered map-type union inference (`{:name "alice" :age 30}`) but NOT `(infer <Nat | Bool>)` — the expr-union `infer` case. Probe scenarios need to cover more semantic axes (per the 1A-ii Pre-0 semantic axis lesson).

### §4.4 expr-union on-network typing is ARCHITECTURALLY WRONG

Lines 1907/1919 write component types (Nat, Bool) as the `:type` of the union-type expression. This is incorrect — the TYPE of a union-type expression is `[Type lv]` (the universe), not its components. The code accidentally worked via contradiction-detection fallback to sexp infer. T3-C3 must fix this directly.

### §4.5 Testing protocol discipline validated (and violated once)

User gently corrected me mid-session: full suite is a regression gate, not a diagnostic tool. Failure logs persist — read them instead of re-running. Course-corrected for the rest of the session. Dailies reflect this.

### §4.6 Per-commit dailies discipline

Started this session (previously batched). Each commit triggers a dailies update. Multiple commits landed with their own dailies entries. Discipline sustained.

---

## §5 Open Questions and Deferred Work

### §5.1 T3-C3 re-audit (NEXT SESSION'S MAIN WORK)

Per §7.6.13:
- Audit item 1 (inline checks) — DONE in §7.6.9 (4 sites found + migrated)
- Audit item 2 (downstream fallback) — OPEN; focus area
- Audit item 3 (contradicts? consumers) — OPEN; focus area

Concrete audit steps in §1 "Next immediate task" above.

### §5.2 typing-propagators.rkt:1878-1920 architectural fix

Known-affected site. Write `[Type lv]` directly (architecturally correct) instead of component types. The specific fix needs investigation of how `install`, `ctx-pos`, and `e` interact in the install function — consult the function's surrounding context to understand whether the fix goes at line 1907/1919 (type-map-write) or somewhere upstream.

### §5.3 Enhanced probe coverage

Add expr-union-based scenarios to the probe (`<Nat | Bool>`, `(infer <...>)`, type annotations with union types). The attempt-1 + Commit B pattern shows probe coverage is the early-warning mechanism.

### §5.4 Remaining Path T work (post-T-3)

- **T-1 speculation consolidation** — `with-speculative-rollback` simplification; remove bitmask scaffolding from try-rollback callers; many sites become unnecessary post-T-3 (set-union merge handles map-assoc type-incompatibility naturally)
- **T-2 Map open-world realignment** — typing-core.rkt:1196-1217 map-assoc rule; explicit `build-union-type` becomes redundant OR migrate to `_` open-world value type per ergonomics design
- **1A-iii-a-wide** — post-T-3: type cell migration + PU refactor (4 domain universes + shared hasse-registry + compound-tagged-merge + elab-meta-read/write API)
- **1A-iii-b** (Tier 2 atms cleanup) + **1A-iii-c** (Tier 3 surface ATMS AST) — independent of Path T

### §5.5 Deferred items stable

No new DEFERRED.md entries this session.

---

## §6 Process Notes

### §6.1 Mini-design in design document (codified)

User corrected mid-session: "We are not doing a full Stage 1-3 design document separate from our current efforts. That's too heavy on the process ... Let's work through design in dialogue, that can persist in our current design document."

All T-3 design work persists in D.3 §7.6. No separate research/audit/design artifacts. Mini-design = conversational dialogue with resolutions captured IN D.3.

### §6.2 Multi-hypothesis parallel diagnostic (validated)

User teaching earlier in session (Path Z investigation): "test multiple hypotheses at once to see which approach can produce or mitigate the bug." Applied in Commit B regression: reverted only the fallthrough to confirm it was the specific source, while keeping Commit A active. Diagnostic converged in 1-2 cycles instead of 3+.

### §6.3 Three-accidentally-load-bearing pattern — codifiable

Emerging principle: **when migrating an infrastructure API, audit not just inline consumers but DOWNSTREAM DEPENDENCIES on side-effects the API produces**. For merge functions: check whether callers rely on specific merge RESULTS (type-top for incompatible) that downstream logic treats specially (contradiction fires, fallback paths trigger).

### §6.4 Per-commit dailies discipline sustained

Each commit this session triggered a dailies update. Multiple commits (9c3172e0, 6fddc5f7, 37aaba2b, 17d26e74, fa1a7b9c) each have corresponding dailies entries.

### §6.5 Commit span this session

From `b6d8a9c1` (post-prior-handoff) through `fa1a7b9c` (this handoff's dailies). Key landmarks:
- Session start: 1A-i complete, 1A-ii-a pending mini-design
- Session arc: 1A-ii-a → 'mult SRE → 1A-iii Sub-A (reverted) → Path T pivot → T-3 design → Stage 2 audit → Commit A → Commit B (paused)
- Session end: stable post-Commit-A state; T3-C3 queued

---

## §7 What the Continuation Session Should Produce

### §7.1 Immediate (T3-C3 re-audit execution)

1. Hot-load every §2 document IN FULL
2. Summarize understanding back to user; validate (especially the 3-accidentally-load-bearing pattern)
3. Execute T3-C3 re-audit per §7.6.13 + §5.1 steps
4. Persist findings in D.3 (§7.6.14 or equivalent)
5. Migrate newly-found sites (likely a new Commit A extension or Commit A.2)
6. **Fix typing-propagators.rkt:1878-1920 expr-union typing** (write [Type lv] directly)
7. Retry Commit B (set-union fallthrough) + test-type-lattice.rkt assertion updates
8. Validate: probe diff = 0, targeted tests pass, full suite regression check
9. Commit + tracker + dailies per-commit

### §7.2 Medium-term (post-Commit-B)

- 1A-iii-a-wide Step 2: PU refactor (4 per-domain universes + shared hasse-registry + compound-tagged-merge + elab-meta-read/write API migration)
- T-1: speculation mechanism consolidation
- T-2: Map open-world realignment
- 1A-iii-b: Tier 2 atms cleanup
- 1A-iii-c: Tier 3 surface ATMS AST retirement

### §7.3 Longer-term

Per D.3 §7.7-§7.11: Phase 1B (tropical fuel), Phase 1C (canonical BSP fuel instance), Phase 1V, Phase 2, Phase 3, Phase V.

---

## §8 Final Notes

### §8.1 What "I have full context" requires

- Read EVERY document in §2 IN FULL
- Articulate EVERY decision in §3 with rationale
- Know EVERY surprise in §4 — especially §4.1 (3 accidentally-load-bearing findings pattern)
- Understand the open questions in §5.1 but DO NOT pre-resolve them

Good articulation: "T-3 Commit A is delivered (37aaba2b) — type-unify-or-top helper + 4 Role B site migrations, zero behavior change. Commit B was attempted and paused — set-union merge fallthrough regressed test-union-types:234 because typing-propagators.rkt:1878-1920 relies on type-lattice-merge producing type-top to trigger a fallback to sexp-based infer at typing-core.rkt:459 for [Type 0]. This is the third 'accidentally load-bearing mechanism' in the addendum track. T3-C3 requires a systematic re-audit before Commit B retry."

### §8.2 Git state

```
branch: main
HEAD: fa1a7b9c (dailies)
  preceded by 17d26e74 (D.3 pause + 3rd finding)
  preceded by 37aaba2b (Commit A — Role B migration)
  preceded by 4d1bcc25 (dailies for audit)
  preceded by 6fddc5f7 (Stage 2 audit + Stage 3 design)
  ...

working tree: clean

Commit B changes: REVERTED
  - type-lattice.rkt: fallthrough back to type-top
  - tests/test-type-lattice.rkt: reverted via git checkout
```

### §8.3 User-preference patterns observed

- **Conversational mini-design in existing document** — user explicitly rejected separate Stage 1-3 artifacts for T-3
- **Architectural completeness > implementation cost** — "without concern of the implementation cost. Pragmatic implementation shortcuts should never be on the table"
- **Principled over mechanical** — path T3-C3 chosen over T3-C1 ("fix specific case") because principle-driven audit prevents future instances
- **Multi-hypothesis diagnostic** — user taught this earlier; session applied in Commit B regression
- **Context awareness delegated to user** — "I'll explicitly request a handoff when we get to 85-90%"; don't offer context-wrap options unsolicited

### §8.4 Gratitude

User's observations THIS SESSION were decisive:
- "Multiple different mechanisms — or 'sources of truth' — that are trying to compete here?" → surfaced correct-by-construction tension
- "Maps being union typed ... our ergonomics design principle has explicitly been designed for Maps to be 'Open World'" → surfaced T-2 concern
- "If our union type merge is producing top, then it makes me wonder if our lattice design is inadequate. The merge should follow set-union semantics" → named T-3 architectural pivot
- "We have prior art in BSP-LE 2B — have we compared to this design, are we effectively reusing this infrastructure, efficiently?" → identified T-1 concern
- "When creating large amounts of cells, we should always be asking ourselves: Is this a Pocket Universe (PU) efficiency target?" → PU refactor surfaced
- "Are we unintentionally conflating two separate concerns? ... merge on types, Are we ... squishing two things together that should be separate, and potentially walking into a bug-pocalypse?" → Q-T3-8 Role A/B decomplection surfaced — saved T-3 from being a bug-pocalypse

Each observation redirected the session toward better architectural framings. Honor this pattern.

**The context is in safe hands.**
