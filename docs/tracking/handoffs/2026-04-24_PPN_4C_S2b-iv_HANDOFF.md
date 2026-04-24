# PPN 4C Addendum Step 2 S2.b-iv Handoff

**Date**: 2026-04-24 (session arc: 2026-04-23 continuation + 2026-04-24 work through handoff prep)
**Purpose**: Transfer context into a continuation session to pick up **Step 2 S2.b-iv** — the set-latch rewrite of constraint retry + trait/hasmethod bridge readiness under the compound universe cell model.

**Before reading anything else**: read [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org). The Hot-Load Reading Protocol requires reading EVERY §2 document IN FULL before summarizing understanding back to the user.

**CRITICAL meta-lessons carried forward from this session arc**:

1. **Set-latch is the PRIME design pattern for fan-in**, not an optimization. Codified in `.claude/rules/propagator-design.md` 2026-04-24. Use before writing any fan-in. The imperative fan-in has three defects (re-reads all per fire, loses identity, breaks under compound cells) — set-latch solves all three structurally using first-class primitives we already ship.

2. **5 integration-surfaced class-mismatch findings** across the T-3 + S2.b arc. Pattern graduation-ready for DEVELOPMENT_LESSONS.org: *Stage 2 audits for API migrations must include integration-test runs of realistic workloads, not just static site enumeration.*

3. **Full suite at 110.7s** post-S2.b-iii (vs 118-127s baseline) — ~7-13% faster. Unexpected S2.b win confirming the compound path's read performance advantage + scheduler work reduction from fewer per-meta cells. Preserves the bounce-back measurement plan for S2.b close.

4. **The Stage 4 content-location methodology** was clarified this session (commit `d269cd1e`): mini-design and mini-audit outcomes persist to the DESIGN DOC (not dailies, not separate audit files); steps 1 and 2 are CO-DEPENDENT, cycling together. Dailies hold the opening bookmark (<10min) + commit story only. D.3 §7.5.1, §7.5.8, §7.5.10, §7.5.11, §7.5.12, §7.6.15 are canonical examples.

5. **Phase 3b (mempalace code-wing) ABANDONED** 2026-04-23 — negative finding documented in `.claude/rules/mempalace.md`. Do not re-attempt without upstream file-type filter or AST-aware chunking.

---

## §1 Current Work State (PRECISE)

- **Track**: PPN Track 4C Phase 9+10+11 Addendum — substrate + orchestration unification (per D.3)
- **Parent track**: PPN Track 4C (per [`2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md)) — addendum is a BREAKOUT; cross-cutting concerns per §5.5 of the prior handoff still apply
- **Phase**: 1A-iii-a-wide Step 2 (PU refactor) — Option B per D.3 §7.5.4 revised 2026-04-23
- **Sub-phase**: **S2.b-ii ✅ + S2.b-iii ✅ + S2.b-iii follow-up ✅** (5 commits); **S2.b-iv NEXT** (set-latch rewrite per D.3 §7.5.12.9)
- **Stage**: Stage 4 Implementation
- **Design document**: D.3 at [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — §7.5.12 captures S2.b mini-design + §7.5.12.9 captures S2.b-iv design decision + empirical findings
- **Last commit** (code): `997a7896` (S2.b-iii follow-up: `'infra-bot` filter + worldview-cache fallback)
- **Handoff commit**: see git log at handoff time; this doc + set-latch codification + D.3 §7.5.12.9 + dailies updates
- **Branch**: `main` (ahead of origin by many commits; don't push unless directed)
- **Working tree**: clean except benchmark data + pnet cache artifacts
- **Suite state**: **7912 tests / 110.7s / 1 test file failing** (`test-constraint-retry-propagator.rkt`, 4 failures of 16 tests; see §4.2 for the 4 specific cases). 408/409 test files green. All other tests pass.
- **Baseline doc**: [`2026-04-23_STEP2_BASELINE.md`](../2026-04-23_STEP2_BASELINE.md) — §5 hypotheses + §6 bounce-back measurement + §11 PRE0-to-post-T-2 A/B

### Progress Tracker snapshot (D.3 §3, post-S2.b-iii)

| Sub-phase | Status | Commit |
|---|---|---|
| T-3 complete | ✅ | 4 commits A→B |
| 1A-iii-a-wide Step 1 | ✅ | 5 sub-phase commits |
| Path T-1 (documentation) | ✅ | `b7f8e58d` |
| Path T-2 (Open by Design) | ✅ | 3 commits + `bb058491` tracker |
| Step 2 S2.a | ✅ | `ded412db` |
| Step 2 S2.a-followup | ✅ | `2bab505a` |
| Step 2 baseline doc | ✅ | `3ba56387` |
| Step 2 revised (Option B) + Phase 1E added | ✅ | `7b602bd8` |
| Step 2 S2.b mini-design (D.3 §7.5.12) | ✅ | `b1f882fb` |
| **Step 2 S2.b-ii** (centralized dispatch) | ✅ | `82c9f426` + `128020af` tracker |
| **Step 2 S2.b-iii** (fresh-meta + solve-meta + meta-solved? dispatch) | ✅ | `cf60c397` + `b9baa4a9` tracker |
| **Step 2 S2.b-iii follow-up** (infra-bot + worldview-cache) | ✅ | `997a7896` |
| **Step 2 S2.b-iv** (set-latch rewrite) | ⬜ NEXT | — |
| Step 2 S2.b-v (driver residual + measurement) | ⬜ | — |
| Step 2 S2.c (mult domain) | ⬜ | — |
| Step 2 S2.d (level + session) | ⬜ | — |
| Step 2 S2.e (retire factories + measure) | ⬜ | — |
| Step 2 S2.f (cleanup) | ⬜ | — |
| Step 2 S2-VAG | ⬜ | — |
| Phase 1E (that-* storage unification) | ⬜ | — |
| Phase 1B (tropical fuel) | ⬜ | Follows 1E |

### Next immediate task

**S2.b-iv set-latch rewrite** per D.3 §7.5.12.9. Concrete 7-step scope captured in §7.5.12.9; summary below:

1. Add `meta-ids` field to `constraint` struct (metavar-store.rkt:283) alongside existing `cell-ids`
2. Populate `meta-ids` in `add-constraint!` from the same lhs/rhs meta walk
3. Rewrite 3 readiness pipeline sites (constraint retry `:826+`, trait bridge retry `:466+`, hasmethod bridge retry `:618+`) using set-latch pattern from propagator-design.md:
   - 1 `'monotone-set` latch cell per constraint/bridge
   - N fire-once propagators per meta-id with `:component-paths (list meta-id)`
   - 1 threshold propagator (latch non-empty → ready-queue action)
   - Factor into helper `add-readiness-set-latch!` for consistency
4. Update bridge fire-fns in resolution.rkt (`make-pure-trait-bridge-fire-fn` at :428, hasmethod analog) — signature change to accept `(universe-cid, meta-id)` pairs; body uses `compound-cell-component-ref/pnet` + `compound-cell-component-write/pnet`
5. Add `compound-cell-component-ref/pnet` + `compound-cell-component-write/pnet` pnet-level helpers to meta-universe.rkt (mirror enet-level; use `net-cell-read`/`write` instead of `elab-cell-*`)
6. Update tests in `test-constraint-retry-propagator.rkt`: `(length (constraint-cell-ids c))` → `(length (constraint-meta-ids c))` where meta-identity is the semantic check
7. Regression: full suite back to 7912/0-failure; probe diff = 0

**Expected scope**: 250-400 LoC across metavar-store.rkt + resolution.rkt + meta-universe.rkt + tests. Helper factoring reduces effective LoC vs duplicating set-latch logic at 3 sites.

---

## §2 Documents to Hot-Load (ORDERED)

**CRITICAL**: read every document IN FULL. No skimming.

### §2.0 Start here

0. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org)

### §2.1 Always-Load

1. [`CLAUDE.md`](../../../CLAUDE.md) + [`CLAUDE.local.md`](../../../CLAUDE.local.md)
2. [`MEMORY.md`](../../../MEMORY.md) — auto-memory index
3. [`DESIGN_METHODOLOGY.org`](../principles/DESIGN_METHODOLOGY.org) — especially Stage 4 Per-Phase Protocol (content-location clarification codified 2026-04-23 via commit `d269cd1e`)
4. [`DESIGN_PRINCIPLES.org`](../principles/DESIGN_PRINCIPLES.org) — Correct-by-Construction + Decomplection + Hyperlattice Conjecture
5. [`CRITIQUE_METHODOLOGY.org`](../principles/CRITIQUE_METHODOLOGY.org) — P/R/M/S lenses
6. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org) (self-reference)
7. [`docs/tracking/MASTER_ROADMAP.org`](../MASTER_ROADMAP.org) — single source of truth for series/tracks/design-docs/PIRs
8. [`docs/tracking/2026-03-26_PPN_MASTER.md`](../2026-03-26_PPN_MASTER.md) — **current series master** for PPN

### §2.2 Architectural Rules (loaded via `.claude/rules/`)

9. [`.claude/rules/on-network.md`](../../../.claude/rules/on-network.md) — design mantra
10. [`.claude/rules/structural-thinking.md`](../../../.claude/rules/structural-thinking.md) — SRE, Module Theory Realization B
11. [`.claude/rules/propagator-design.md`](../../../.claude/rules/propagator-design.md) — **UPDATED 2026-04-24** with set-latch pattern as PRIME DESIGN PATTERN for fan-in. Read this carefully — it's the blueprint for b-iv.
12. [`.claude/rules/workflow.md`](../../../.claude/rules/workflow.md) — per-commit dailies + phase completion checklist
13. [`.claude/rules/testing.md`](../../../.claude/rules/testing.md) — diagnostic protocol + targeted test discipline
14. [`.claude/rules/pipeline.md`](../../../.claude/rules/pipeline.md) — exhaustiveness checklists
15. [`.claude/rules/stratification.md`](../../../.claude/rules/stratification.md)
16. [`.claude/rules/mempalace.md`](../../../.claude/rules/mempalace.md) — **UPDATED 2026-04-23** with Phase 3 hook + Phase 3b ABANDONED finding
17. [`.claude/rules/prologos-syntax.md`](../../../.claude/rules/prologos-syntax.md)

### §2.3 Session-Specific — THE DESIGN DOCUMENTS (READ IN FULL)

18. [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — **D.3, THE addendum design**. NEW this session:
    - **§7.5.12** (NEW 2026-04-24) — S2.b sub-phase mini-design (Categories + partition + migration patterns + drift risks)
    - **§7.5.12.5** (UPDATED 2026-04-24) — scheduler component-path verification outcome: BARE `meta-id` paths, not `(cons universe-cid meta-id)`
    - **§7.5.12.9** (NEW 2026-04-24) — S2.b-iv design decision (set-latch rewrite) + full-suite empirical findings + 7-step concrete scope + drift risks
    - Tracker rows updated: S2.b-ii ✅ `82c9f426`; S2.b-iii ✅ `cf60c397`; S2.b-iv ⬜ NEXT

19. [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md) — PPN 4C PARENT DESIGN. Read the same sections listed in the prior handoff (§1, §2, §6.3, §6.7, §6.10, §6.12, §6.15, §6.16). Cross-cutting concerns per §5.5 of the prior handoff doc still apply.

20. [`docs/research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md`](../../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md) — Track 4D vision

### §2.4 Session-Specific — Baseline + Hypotheses

21. [`docs/tracking/2026-04-23_STEP2_BASELINE.md`](../2026-04-23_STEP2_BASELINE.md) — performance baseline. S2.b-v will measure against §5 hypotheses + update §12 "Actual vs Predicted". Note: the informal full-suite wall time of 110.7s vs 118-127s baseline is a data point toward the hypotheses (suite ≤ 122s).

### §2.5 Session-Specific — THE PRIMARY CODE FILES FOR S2.b-iv

**CORE infrastructure (read + understand the current state)**:

22. [`racket/prologos/meta-universe.rkt`](../../../racket/prologos/meta-universe.rkt) — **UPDATED S2.b-iii follow-up**: `compound-cell-component-ref` now uses `resolve-worldview-bitmask` helper (mirrors net-cell-read's bitmask resolution). **S2.b-iv TODO**: add `compound-cell-component-ref/pnet` + `compound-cell-component-write/pnet` pnet-level helpers.

23. [`racket/prologos/metavar-store.rkt`](../../../racket/prologos/metavar-store.rkt) — **UPDATED S2.b-ii + iii**:
    - Imports: `(only-in "meta-universe.rkt" meta-universe-cell-id? compound-cell-component-ref compound-cell-component-write init-meta-universes! current-type-meta-universe-cell-id)` (lines ~36-50)
    - `reset-meta-store!` (line 2559) calls `init-meta-universes!` at tail of new-cell-fn block
    - `fresh-meta` (line 1621) dispatches on `(current-type-meta-universe-cell-id)` — universe path registers meta-id as component of universe cell; fallback per-meta path preserved
    - `solve-meta-core!` (~line 1730) + `solve-meta-core-pure` (~line 1805) dispatch on `meta-universe-cell-id?` for writes
    - `meta-solution/cell-id` (~line 2011) dispatches with `'infra-bot` filter (b-iii follow-up)
    - `meta-solved?` (~line 2064) dispatches with `'infra-bot` filter
    - `expr-meta-bot-placeholder` helper returns `'type-bot` (symbol literal, avoids import cycle)

    **S2.b-iv TODO**:
    - Add `meta-ids` field to `constraint` struct (line 283)
    - Populate in `add-constraint!` (trace callers — the populator site builds `cell-ids` from the meta walk)
    - Rewrite the 3 readiness pipeline sites (`:466+` trait bridge retry, `:618+` hasmethod bridge retry, `:826+` constraint retry) using set-latch
    - Factor helper `add-readiness-set-latch! enet meta-ids action-builder` for single-point-of-truth

24. [`racket/prologos/resolution.rkt`](../../../racket/prologos/resolution.rkt) — bridge-fn factories unchanged so far. **S2.b-iv TODO**:
    - `make-pure-trait-bridge-factory` (line 419) + `make-pure-trait-bridge-fire-fn` (line 428) — signature + body update per D.3 §7.5.12.9 step 4
    - `make-pure-hasmethod-bridge-factory` (line 489) + `make-pure-hasmethod-bridge-fire-fn` (line 498) — analog

25. [`racket/prologos/propagator.rkt`](../../../racket/prologos/propagator.rkt) — set-latch primitives are here. **READ**:
    - `net-add-fire-once-propagator` (line 1511) — BSP-LE Track 2 Phase 5 infrastructure
    - `make-threshold-fire-fn` (line 1691) + `net-add-threshold` (line 1716) — threshold-gated firing
    - `pu-value-diff` (line 1008) — emits bare hasheq keys for flat compound cells (no cons-pair wrapping — confirmed §7.5.12.5)
    - `filter-dependents-by-paths` (line 1058) — supports arbitrary `equal?`-comparable paths

26. [`racket/prologos/infra-cell-sre-registrations.rkt`](../../../racket/prologos/infra-cell-sre-registrations.rkt) — `'monotone-set` SRE domain at line 131 (merge `merge-set-union`, bot `(seteq)`, proper join-semilattice). The latch cell's domain.

27. [`racket/prologos/decision-cell.rkt`](../../../racket/prologos/decision-cell.rkt) — `compound-tagged-merge` at line 529. The compound universe cell's merge.

### §2.6 Session-Specific — THE FAILING TEST

28. [`racket/prologos/tests/test-constraint-retry-propagator.rkt`](../../../racket/prologos/tests/test-constraint-retry-propagator.rkt) — 4 failures of 16 tests. Read the failing cases (lines 47, 109, 225, 262) to see EXACTLY what b-iv needs to produce. The `cell-ids` → `meta-ids` rename is honest architecture; the semantics the tests probe (distinct identity per meta in a constraint) is what the set-latch preserves.

### §2.7 Session-Specific — Benchmarks + Probe

29. [`racket/prologos/examples/2026-04-22-1A-iii-probe.prologos`](../../../racket/prologos/examples/2026-04-22-1A-iii-probe.prologos) — 28 expressions; baseline at `data/probes/2026-04-22-1A-iii-baseline.txt` (post-T-2 refresh). Used for probe-diff=0 checkpoint at each sub-phase.
30. [`racket/prologos/examples/2026-04-17-ppn-track4c.prologos`](../../../racket/prologos/examples/2026-04-17-ppn-track4c.prologos) — acceptance file; confirmed clean post-b-iii.
31. [`racket/prologos/benchmarks/micro/bench-meta-lifecycle.rkt`](../../../racket/prologos/benchmarks/micro/bench-meta-lifecycle.rkt) — E1-E5 compound-vs-per-cell A/B micros (S2.a landed these). For S2.b-v measurement.

### §2.8 Session-Specific — Dailies + Prior Handoffs

32. [`docs/tracking/standups/2026-04-23_dailies.md`](../standups/2026-04-23_dailies.md) — **current dailies** (creation-to-creation rule; working day interval opened 2026-04-23 but calendar date is now 2026-04-24). Full session-arc narrative. Read this and the standup.
33. [`docs/tracking/handoffs/2026-04-23_PPN_4C_S2b_HANDOFF.md`](2026-04-23_PPN_4C_S2b_HANDOFF.md) — **prior handoff** (opened this session's work). Cross-cutting concerns matrix in §5.5 still applies.
34. [`docs/tracking/handoffs/2026-04-22_PPN_4C_T-2_HANDOFF.md`](2026-04-22_PPN_4C_T-2_HANDOFF.md) — two handoffs back; still relevant for the T-3/T-2 Role A/B context.
35. [`docs/standups/standup-2026-04-23.org`](../../standups/standup-2026-04-23.org) — user's standup for this working-day interval.

---

## §3 Key Design Decisions (RATIONALE — do NOT re-litigate)

### §3.1 Option B (no elab-meta-* API) — confirmed pre-session

Per D.3 §7.5.4 revised 2026-04-23. No new `elab-meta-read/write` API; use existing `elab-cell-read/write` + `compound-cell-component-ref/write` helpers. Avoids parallel API debt that Track 4D would have to retire.

### §3.2 Bare meta-id paths, not cons-pair — VERIFIED S2.b-ii

Per D.3 §7.5.12.5. The scheduler's `filter-dependents-by-paths` supports cons-pair paths (used in typing-propagators.rkt for attribute-map firing). But for our FLAT compound universe cells `(hasheq meta-id → tagged-cell-value)`, `pu-value-diff` emits bare `meta-id` keys. Declare `:component-paths (list meta-id)`, NOT `(cons universe-cid meta-id)`. Universe-cid scoping is handled by propagator registration against input-ids.

### §3.3 Initial value for universe-registered metas = `'type-bot` symbol literal

metavar-store.rkt cannot import type-lattice.rkt (canonical cycle). Use the symbol literal `'type-bot` — `type-lattice.rkt` defines `(define type-bot 'type-bot)`, so the value IS the symbol. `expr-meta-bot-placeholder` helper returns it; `prop-type-bot?` recognizes it.

### §3.4 Set-latch is THE fan-in pattern — decided 2026-04-24

Full discussion in D.3 §7.5.12.9 + codification in `.claude/rules/propagator-design.md` § "Set-Latch for Fan-In Readiness".

Upshot: the imperative fan-in (single propagator, `for/or` over all reads) has three defects — re-reads all inputs per fire, loses identity, breaks under compound cells. Set-latch solves all three using existing first-class primitives (`'monotone-set` SRE domain, `net-add-fire-once-propagator` with `:component-paths`, `make-threshold-fire-fn`). Promoted to PRIME design pattern — consult before writing any fan-in.

**Explicit rejections**:
- Option B-inline (parallel `meta-ids` field + inline per-meta dispatch in fan-in fire-fn) — rejected. Still uses the imperative fan-in shape; would need future rework.
- Option C (defer the 4 failures) — rejected. Violates "never move on until green".

### §3.5 Integration-surfaced pattern — 5 data points, graduation-ready

Codification candidate for DEVELOPMENT_LESSONS.org: *Stage 2 audits for API migrations must include integration-test runs of realistic workloads, not just static site enumeration.*

Data points across the session arc:
1. Attempt-1 (1A-ii) — TMS dispatch at net-cell-write:1248 accidentally load-bearing for union inference
2. Sub-A (1A-iii) — `with-speculative-rollback` bitmask ignored by TMS; elab-net snapshot was the real work
3. Commit B (T-3) — `type-lattice-merge → type-top` triggered sexp-infer fallback at typing-core.rkt:459
4. b-iii `meta-solved?` — direct `elab-cell-read` on universe-cid returned raw hasheq → false "solved"
5. b-iii follow-up `'infra-bot` + worldview-cache — the universal sentinel and committed-hyp-bit escaped the dispatch paths

Do not let S2.b-iv close without either: (a) landing this DEVELOPMENT_LESSONS.org entry, or (b) explicitly deferring it to S2-VAG with reasons noted.

---

## §4 Surprises and Non-Obvious Findings

### §4.1 Compound-cell read path is FASTER than per-cell (S2.a surprise, confirmed at full suite)

S2.a benchmarks showed 43-52 ns/call for compound-cell-component-ref vs 113 ns baseline per-meta elab-cell-read. Full suite at S2.b-iii confirmed: 110.7s vs 118-127s baseline = 7-13% faster.

### §4.2 4 specific constraint retry failures — NARROW b-iv scope

Post-`997a7896` full suite: 7912 tests, 1 test file failing. The failures (from `data/benchmarks/failures/test-constraint-retry-propagator.rkt.log`):

| # | Test case | Expected | Actual | Root cause |
|---|---|---|---|---|
| 1 | `cell-ids/constraint-with-two-metas-has-two-cell-ids` (:47) | `(length cell-ids) = 2` | 1 | 2 distinct type metas → both universe-cid → `remove-duplicates` collapses |
| 2 | `via-cells/retries-when-meta-solved` (:109) | `'solved` | `'postponed` | Fan-in `(net-cell-read pnet universe-cid)` returns whole hasheq (not bot/top) → any-ground? fires incorrectly → retry path doesn't reach component |
| 3 | `integration/constraint-postponed-again-on-partial-solve` (:225) | `(length cell-ids) = 2` | 1 | Same cell-id collapse |
| 4 | `cell-ids/cell-reads-reflect-meta-solutions` (:262) | `#t` | `#f` | Direct universe-cid read for "is solved?" breaks |

All 4 point to the SAME architectural issue (universe-cid collapse in fan-in propagators) and SAME fix (set-latch rewrite).

### §4.3 BSP-LE read-logic override is INTENTIONAL (from prior handoff, still relevant)

`net-cell-read`'s tagged-cell-value dispatch at propagator.rkt:968-975 uses OVERRIDE semantics (per-propagator `current-worldview-bitmask` REPLACES worldview-cache when set). Intentional for clause-propagator isolation under BSP-LE 2/2B. S1.a's 4th-finding fix localized the worldview-BITMASK-inclusion to `with-speculative-rollback`, not global read-logic. The b-iii follow-up `resolve-worldview-bitmask` helper in meta-universe.rkt mirrors this exact logic.

### §4.4 Cell count went UP, not down (not a regression)

Baseline probe `CELL-METRICS:{"cells":50}`. Post-S2.b-iii: `cells=54`. +4 cells = 4 universe cells + 1 hasse-registry cell - (some migrated type metas). Net: more cells at probe-end, but the SHARED-vs-PER-META distinction means aggregate meta-cell allocations are lower. Full S2.b-v measurement will quantify the alloc win via `bench-meta-lifecycle` E-tier.

### §4.5 `cells=54` does NOT mean universe path isn't firing — just that per-meta counting was wrong

Briefly suspected the universe path wasn't being taken. Resolution: the probe has 16 metas total, but many are mult/level/session (S2.c/d scope — still per-meta). Only TYPE metas are migrated. The exact split isn't cleanly separable from the counter. Resolved by confirming test-mixed-map + acceptance file semantic outputs match baseline — type meta handling IS correct.

---

## §5 Open Questions and Deferred Work

### §5.1 S2.b-iv execution (immediate next)

D.3 §7.5.12.9 has the full 7-step scope. Key decisions pre-made:
- **Pattern**: set-latch (committed in D.3 §7.5.12.9 + codified in propagator-design.md)
- **Structure**: 1 latch cell + N fire-once propagators + 1 threshold per constraint/bridge
- **Helper factoring**: `add-readiness-set-latch! enet meta-ids action-builder` for single-point-of-truth across 3 install sites
- **Component-path shape**: bare `meta-id` (confirmed §7.5.12.5)
- **New pnet-level helpers**: `compound-cell-component-ref/pnet`, `compound-cell-component-write/pnet` (mirror enet-level; use `net-cell-read`/`write`)
- **Test updates**: `constraint-cell-ids` → `constraint-meta-ids` for identity-per-meta assertions

### §5.2 S2.b-v (after b-iv closes)

- Final formal measurement vs STEP2_BASELINE.md §5 hypotheses (bench-meta-lifecycle E1-E5 + probe verbose + suite timing)
- Update baseline doc §12 "Actual vs Predicted"
- Decide go-ahead for S2.c (mult domain migration)

### §5.3 DEVELOPMENT_LESSONS.org candidates (graduation-ready)

- **Stage 2 audit must include integration-test runs** — 5 data points; graduate either at b-iv close or S2-VAG
- **Set-latch as prime fan-in pattern** — codified in propagator-design.md; additional lesson-level write-up is optional (propagator-design.md is the authoritative home)

### §5.4 Watching-list carryovers

Patterns with data points, not yet graduation-ready:
- PU heuristic (N→1 compound): 5+ instances (decisions, commitments, scope, attribute-map, worldview-cache, per-meta universe). Post-S2-close → codify.
- Cell-allocation factory migrates identity: 1 data point (S2.b revert). Watching.
- Positive measurement surprises (hypothesis too pessimistic): 2 data points (S2.a compound 55% faster; S2.b-iii suite 7-13% faster). 1 more → codify.
- Process-clarification → methodology-edit cycle: 3 data points. Promote as meta-principle "methodology evolves through use"?
- mempalace semantic search for prior-art retrieval: 2 positive data points (CIU §8 D7 via T-2; Phase 1 eval). Watching.
- Mini-design in existing design doc: 3+ data points (T-3, T-2, S2.b). Promote after S2.b closes.

### §5.5 Cross-cutting concerns (from prior handoff §5.5, still applies)

Parent PPN 4C phase interactions unchanged from the 2026-04-23 handoff §5.5 matrix. Specifically watch Phase 4 (CHAMP retirement — S2.b universe-cell shape compatible with attribute-map β2 collapse) + Phase 7 (parametric trait resolution — dict-cell-id bridge-fn setup is part of b-iv's scope) + Phase 10 (union via ATMS — fork-on-union per-branch ready latches would consume the same set-latch pattern).

---

## §6 Process Notes

### §6.1 Refined Stage 4 content-location methodology (codified 2026-04-23, commit `d269cd1e`)

Mini-design + mini-audit are CONVERSATIONAL and CO-DEPENDENT. Outcomes persist to the DESIGN DOC (not dailies, not separate audit files). Dailies hold the opening bookmark (<10min) + commit story only. Standups hold user's personal notes. Three distinct homes during intra-Stage-4 loop; broader documentation web (audits, critiques, research, PIRs, roadmaps) serves distinct purposes.

**Canonical examples** in D.3: §7.5.1 PU sub-architecture resolutions, §7.5.8 Sub-A + three findings, §7.5.10 charter alignment, §7.5.11 Step 1 summary, §7.5.12 S2.b mini-design, §7.5.12.9 S2.b-iv set-latch design, §7.6.15 T-2 summary.

### §6.2 Per-phase completion 5-step checklist (workflow.md + DESIGN_METHODOLOGY)

a. Test coverage (or explicit "no tests: refactor" justification)
b. Commit with descriptive message
c. Tracker update (⬜ → ✅ + commit hash + key result)
d. Dailies append (what was done, why, design choices, lessons/surprises)
e. THEN proceed to next phase

### §6.3 Conversational cadence

Max autonomous stretch: ~1h or 1 phase boundary. Check in with user at sub-phase completions. b-iv is a sub-phase of S2.b with multiple install-site migrations — natural to checkpoint between helper landing + first site migration, and between first site + second/third.

### §6.4 Probe + acceptance file per sub-phase

- Probe (`examples/2026-04-22-1A-iii-probe.prologos`): 28 expressions; diff = 0 vs `data/probes/2026-04-22-1A-iii-baseline.txt` is the semantic gate. Counter deltas within natural variance (≤ a few percent) acceptable.
- Acceptance file (`examples/2026-04-17-ppn-track4c.prologos`): broader regression net with 28+ commands incl. polymorphic forms.
- Targeted tests (`racket tools/run-affected-tests.rkt --tests tests/...`) for the affected test files.
- Full suite regression at phase close; compare wall time to 110.7s (post-S2.b-iii baseline) — aim to stay at or below.

### §6.5 mempalace Phase 3 is active

Post-commit hook auto-mines docs on commits touching `docs/tracking/**` or `docs/research/**`. Logs at `/var/tmp/mempalace-auto-mine.log`. See `.claude/rules/mempalace.md` § Re-mine cadence.

Phase 3b (code wing) ABANDONED — do NOT re-attempt without upstream file-type filter or AST-aware chunking. See `.claude/rules/mempalace.md` § "Phase 3b — code wing: ATTEMPTED, ABANDONED (2026-04-23)".

### §6.6 Session commits (this arc)

| Commit | Focus |
|---|---|
| `d269cd1e` | DESIGN_METHODOLOGY Stage 4 content-location clarification |
| `781f83e9` | Dailies: context recovery + process clarification |
| `4ad31ff7` | mempalace Phase 3 post-commit hook |
| `6ee66910` | Dailies: hook self-test |
| `bab77ffc` | Open 2026-04-23 working day interval |
| `a9e49775` | mempalace Phase 3b ABANDONED + palace recovery |
| `b1f882fb` | D.3 §7.5.12 S2.b mini-design |
| `82c9f426` | S2.b-ii centralized dispatch |
| `128020af` | S2.b-ii tracker + dailies |
| `cf60c397` | S2.b-iii fresh-meta + solve-meta + meta-solved? dispatch |
| `b9baa4a9` | S2.b-iii tracker + dailies |
| `997a7896` | S2.b-iii follow-up: infra-bot + worldview-cache |
| (handoff commit) | Set-latch codification + D.3 §7.5.12.9 + dailies comprehensive + this handoff |

---

## §7 What the Continuation Session Should Produce

### §7.1 Immediate (S2.b-iv execution)

1. Hot-load EVERY §2 document IN FULL (especially D.3 §7.5.12 + §7.5.12.9, propagator-design.md updated set-latch section, test-constraint-retry-propagator.rkt failures, resolution.rkt bridge factories, metavar-store.rkt current dispatch state)
2. Summarize understanding back to user — especially:
   - Set-latch pattern structure + why it's THE prime fan-in pattern
   - The 4 failures and their root causes (cell-id collapse + direct universe-cid read)
   - The 7-step b-iv concrete scope (struct field, populator, 3 readiness rewrites, helper factor, bridge fire-fn updates, pnet-helpers, test updates)
   - Drift risks (fire-once + component-path semantics, bridge factory signature, impl-key-str order preservation, transition cohesion)
3. Open b-iv through conversational mini-design (restate design intent from §7.5.12.9; confirm 7-step plan; propose concrete micro-sequencing within the sub-phase — e.g., pnet-helpers first, then helper `add-readiness-set-latch!`, then constraint retry site, then trait bridge, then hasmethod bridge)
4. Execute per conversational cadence (checkpoints at each install-site migration)
5. Validate: probe diff = 0; test-constraint-retry-propagator.rkt PASSES; full suite back to 7912/0-failure (or better)
6. Per-phase completion protocol: tracker update (b-iv ✅), dailies append, commit

### §7.2 Immediate-follow (S2.b-v close)

1. Formal measurement: bench-meta-lifecycle E1-E5, probe verbose, suite timing
2. Compare against STEP2_BASELINE.md §5 hypotheses; update §12 "Actual vs Predicted"
3. Decide: hypotheses met → go-ahead for S2.c; regression → investigate
4. Per-phase completion protocol for S2.b-v

### §7.3 Medium-term (post-S2.b through addendum Phase 3)

- S2.c (mult domain) — expected smaller scope (mult metas less entangled with traits)
- S2.d (level + session) — expected smallest
- S2.e (retire old per-cell factories wholesale + final measurement)
- S2.f (peripheral cleanup)
- S2-VAG
- Phase 1E (`that-*` storage unification)
- Phase 1B (tropical fuel primitive)
- Phase 1C (canonical BSP fuel instance)
- Phase 1V (Phase 1 VAG)
- Phase 2 (orchestration)
- Phase 3 (union types via ATMS + hypercube)
- Phase V (capstone + PIR)

### §7.4 Post-addendum

- Main-track PPN 4C Phase 4 (CHAMP retirement — immediate follow-on)
- PM Track 12 (module loading on network)
- PPN Track 4D (attribute grammar substrate unification)

---

## §8 Final Notes

### §8.1 What "I have full context" requires

Per HANDOFF_PROTOCOL.org §8.1:

- Read EVERY document in §2 IN FULL
- Articulate EVERY decision in §3 with rationale — especially §3.4 (set-latch as prime pattern)
- Know EVERY surprise in §4 — especially §4.2 (the 4 specific test failures)
- Understand §5.1 (b-iv concrete 7-step scope in D.3 §7.5.12.9)

Good articulation example for b-iv opening:

> "S2.b-iv replaces the imperative fan-in pipeline (threshold + for/or + readiness) in 3 install sites (constraint retry, trait bridge, hasmethod bridge) with the set-latch pattern codified in propagator-design.md. The rewrite is necessary because `test-constraint-retry-propagator.rkt` has 4 failures under b-iii — all rooted in the fan-in's `(net-cell-read pnet universe-cid)` returning the whole hasheq instead of per-meta values. Set-latch uses existing first-class primitives (`'monotone-set` SRE domain, `net-add-fire-once-propagator`, `make-threshold-fire-fn`) and solves the collapse structurally via per-meta propagators with `:component-paths (list meta-id)`. The `constraint.meta-ids` field + `constraint-meta-ids` test assertion honest the architecture to post-S2.b (meta-id is the identity; universe-cid is the shared storage). I'll implement by factoring `add-readiness-set-latch!` helper first, then migrating the 3 install sites + tests — checkpointing at each site completion."

### §8.2 Git state at handoff

```
branch: main (ahead of origin/main by many commits; don't push unless directed)
HEAD: (handoff commit) — set-latch codification + D.3 §7.5.12.9 + dailies comprehensive + this handoff
prior: 997a7896 (S2.b-iii follow-up: infra-bot + worldview-cache)
working tree: clean (benchmark/cache artifacts untracked)
```

### §8.3 User-preference patterns (observed across the arc)

- **Completeness over deferral** — "never move on until green"; integration-test findings must be fixed, not deferred.
- **Architectural correctness > implementation cost** — user accepted Option A-refined (set-latch rewrite) over smaller Option A (inline dispatch) because the former is more structurally aligned.
- **Conversational mini-design** — user prefers mini-design through dialogue with outcomes persisted to D.3. 3+ instances confirmed this arc (T-3, T-2, S2.b).
- **Codification when patterns recur** — user prompted set-latch codification: "I think the set-latch pattern should be picked up as a prime design pattern whenever we do fan-in; it comes up often." Respect this instinct — when a pattern recurs, codify it in the rules.
- **Context-window awareness delegated to user** — handoffs at 85-95% context per user monitoring, not Claude's suggestion. 2026-04-24 handoff was user-initiated when the b-iv scope became clear + context was hot.
- **"Hot-load everything"** — hot-load discipline is strict; user expects §2 documents read IN FULL before summarizing understanding.
- **Gratitude + explicit "Ready to proceed"** — user gives clear go-aheads; when hesitant, articulates uncertainty.

### §8.4 Session arc summary

Started with: pickup from `2026-04-23_PPN_4C_S2b_HANDOFF.md` (S2.b-i audit pending).

Delivered:
- Process clarification (methodology content-location) — commit `d269cd1e`
- mempalace Phase 3 post-commit hook — `4ad31ff7`
- mempalace Phase 3b (code wing) ATTEMPTED + ABANDONED — `a9e49775`
- Opened 2026-04-23 working day interval — `bab77ffc`
- D.3 §7.5.12 S2.b mini-design — `b1f882fb`
- S2.b-ii centralized dispatch — `82c9f426`
- S2.b-iii fresh-meta + solve-meta + meta-solved? dispatch — `cf60c397`
- S2.b-iii follow-up (infra-bot + worldview-cache) — `997a7896`
- Set-latch codified in propagator-design.md (prime design pattern)
- D.3 §7.5.12.9 S2.b-iv design decision + full-suite empirical findings + 7-step scope
- Dailies comprehensive through handoff
- This handoff document

**13+ commits; ~650+ LoC net production code; 2 architectural features delivered (b-ii + b-iii); 1 infrastructure landing (mempalace Phase 3); 1 monitored-experiment negative finding documented (Phase 3b); 1 methodology refinement (Stage 4 content-location); 1 prime design pattern codified (set-latch); full suite at 110.7s (7-13% faster than baseline — S2.b win).**

**The context is in safe hands.** The design is crisp; the scope is narrow; the infrastructure exists. Next session's b-iv is an implementation of a decided architecture using well-tested primitives.
