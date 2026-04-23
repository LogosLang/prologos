# PPN 4C Addendum Step 2 S2.b Handoff

**Date**: 2026-04-23 (substantial session arc — T-2 delivered, Step 2 S2.a delivered, Step 2 S2.b scope-discovered, handoff pending)
**Purpose**: Transfer context into a continuation session to pick up **Step 2 S2.b-i (call-site audit)** — the next unit of work under the rescoped Option S2.b-staged approach.

**Before reading anything else**: read [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org). The Hot-Load Reading Protocol requires reading EVERY §2 document IN FULL before summarizing understanding back to the user.

**CRITICAL meta-lessons carried forward from this session**:

1. **Migrating a cell-allocation factory migrates the IDENTITY of those cells** — the factory's return value is consumed by many propagator installations and direct readers, not just the obvious "read a meta's value" call sites. Scope a cell-factory migration by enumerating IDENTITY CONSUMERS, not just READERS. Candidate for DEVELOPMENT_LESSONS.org post-S2.b.

2. **Measurement surprises can be POSITIVE** — the S2.a benchmark showed compound-cell reads are **55% FASTER** than per-cell reads (predicted slight regression; reality: big win). When hypotheses are wrong in the "too pessimistic" direction, the architectural case STRENGTHENS.

3. **Bounce-back measurement discipline > automatic gate** — per-phase, Claude proposes what to measure, user decides. Preserves velocity without losing rigor.

4. **Option B > Option A for Step 2** — no new `elab-meta-read/write` API; use existing `elab-cell-read/write` + `compound-cell-component-ref/write` helpers. Avoids parallel API debt that Track 4D would have to retire.

5. **Phase 1E persistence** — the `that-*` / meta-access storage unification is NOT in Step 2 scope (confirmed architectural dialogue); it's Phase 1E, sequenced AFTER Step 2, BEFORE Phase 1B. D.3 §7.6.16 captures the implementation note so no context is lost.

---

## §1 Current Work State (PRECISE)

- **Track**: PPN Track 4C Phase 9+10+11 Addendum — substrate + orchestration unification (per D.3)
- **Parent track**: PPN Track 4C (per [`2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md)) — the addendum is a BREAKOUT from this parent; cross-cutting concerns flow in both directions (see §5.5 Cross-cutting concerns for enumeration)
- **Phase**: 1A-iii-a-wide Step 2 (PU refactor + hasse-registry integration) — per D.3 §7.5.4 revised Option B
- **Sub-phase**: S2.a DELIVERED + S2.a-followup DELIVERED; S2.b RESCOPED to staged (S2.b-i audit → S2.b-ii through S2.b-v implementation) — **S2.b-i is the NEXT unit of work**
- **Stage**: Stage 4 Implementation
- **Design document**: D.3 at [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md)
- **Last commit**: `2bab505a` (S2.a-followup — meta-universe.rkt lightweight refactor)
- **Branch**: `main` (ahead of origin/main by many commits; don't push unless directed)
- **Working tree**: clean except benchmark data + pnet cache artifacts
- **Suite state**: 7912 tests, 125.0s, all pass (within 118-127s normal variance band)
- **Baseline doc**: [`2026-04-23_STEP2_BASELINE.md`](../2026-04-23_STEP2_BASELINE.md) — §5 hypotheses + §11 PRE0-to-post-T-2 A/B comparison + §6 measurement discipline

### Progress Tracker snapshot (D.3 §3, post-S2.a-followup)

Key rows:

| Sub-phase | Status | Commit |
|---|---|---|
| T-3 complete | ✅ | 4 commits A→B |
| 1A-iii-a-wide Step 1 | ✅ | 5 sub-phase commits |
| Path T-1 (documentation) | ✅ | `b7f8e58d` |
| Path T-2 (Open by Design) | ✅ | 3 commits `4bfbd141`/`246d4c2e`/`07fda438` + `bb058491` (tracker) |
| Step 2 baseline + hypotheses + measurement discipline | ✅ | `3ba56387` |
| Step 2 revised + Phase 1E added | ✅ | `7b602bd8` |
| **Step 2 S2.a** (infrastructure) | ✅ | `ded412db` |
| **Step 2 S2.a-followup** (meta-universe.rkt lightweight refactor) | ✅ | `2bab505a` |
| **Step 2 S2.b** (type domain migration — RESCOPED) | 🔄 staged | — |
| S2.b-i audit (NEXT) | ⬜ | — |
| S2.b-ii reader/writer update | ⬜ | — |
| S2.b-iii fresh-meta + dict-cell-id consumers | ⬜ | — |
| S2.b-iv propagator installations (:component-paths) | ⬜ | — |
| S2.b-v driver callbacks | ⬜ | — |
| Step 2 S2.c (mult domain) | ⬜ | — |
| Step 2 S2.d (level + session) | ⬜ | — |
| Step 2 S2.e (retire factories + measure) | ⬜ | — |
| Step 2 S2.f (cleanup) | ⬜ | — |
| Step 2 S2-VAG | ⬜ | — |
| **Phase 1E** (that-* storage unification) NEW | ⬜ | — (design note in D.3 §7.6.16) |
| Phase 1B (tropical fuel) | ⬜ | Follows 1E per revised sequence |

### Revised addendum sequence (post-2026-04-23)

```
1A-iii Step 1 ✅ → T-1 ✅ → T-2 ✅ → Step 2 (S2.a ✅ → S2.b... → S2-VAG)
  → Phase 1E (storage unification)
  → Phase 1B (tropical fuel)
  → 1C → 1V → Phase 2 → Phase 3 → Phase V
```

### Next immediate task

**S2.b-i audit** per Option S2.b-staged (confirmed 2026-04-23 end-of-session dialogue).

Output artifact: committed document at `docs/tracking/2026-04-23_STEP2_S2B_AUDIT.md` (or similar). Enumerates every call site that needs migration, categorized by migration pattern, with concrete per-site migration sketches.

Expected scope of S2.b per scope-discovery finding: **~500-900 LoC across ~15 files**, 2-3 sub-phases post-audit (S2.b-ii through S2.b-v).

**Acceptance criteria for S2.b-i**: audit document comprehensive enough that S2.b-ii through S2.b-v can execute without additional surprises.

---

## §2 Documents to Hot-Load (ORDERED)

**CRITICAL**: read every document IN FULL. No skimming.

### §2.0 Start here

0. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org)

### §2.1 Always-Load

1. [`CLAUDE.md`](../../../CLAUDE.md) + [`CLAUDE.local.md`](../../../CLAUDE.local.md)
2. [`MEMORY.md`](../../../MEMORY.md) — auto-memory index
3. [`DESIGN_METHODOLOGY.org`](../principles/DESIGN_METHODOLOGY.org) — Stage 4 Per-Phase Protocol especially
4. [`DESIGN_PRINCIPLES.org`](../principles/DESIGN_PRINCIPLES.org) — Correct-by-Construction + Decomplection + Hyperlattice Conjecture
5. [`CRITIQUE_METHODOLOGY.org`](../principles/CRITIQUE_METHODOLOGY.org) — P/R/M/S lenses
6. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org) (self-reference)
7. [`docs/tracking/MASTER_ROADMAP.org`](../MASTER_ROADMAP.org) — single source of truth for series/tracks/design-docs/PIRs
8. [`docs/tracking/2026-03-26_PPN_MASTER.md`](../2026-03-26_PPN_MASTER.md) — **current series master** for PPN (active track)

### §2.2 Architectural Rules (loaded via `.claude/rules/`)

9. [`.claude/rules/on-network.md`](../../../.claude/rules/on-network.md) — design mantra
10. [`.claude/rules/structural-thinking.md`](../../../.claude/rules/structural-thinking.md) — SRE, Module Theory Realization B
11. [`.claude/rules/propagator-design.md`](../../../.claude/rules/propagator-design.md) — cell allocation efficiency (PU heuristic)
12. [`.claude/rules/workflow.md`](../../../.claude/rules/workflow.md) — per-commit dailies + phase completion checklist
13. [`.claude/rules/testing.md`](../../../.claude/rules/testing.md) — diagnostic protocol + targeted test discipline
14. [`.claude/rules/pipeline.md`](../../../.claude/rules/pipeline.md) — exhaustiveness checklists (recently updated 2026-04-23)
15. [`.claude/rules/stratification.md`](../../../.claude/rules/stratification.md)
16. [`.claude/rules/mempalace.md`](../../../.claude/rules/mempalace.md) — mempalace guardrails + F7 canary
17. [`.claude/rules/prologos-syntax.md`](../../../.claude/rules/prologos-syntax.md)

### §2.3 Session-Specific — THE DESIGN DOCUMENTS (READ IN FULL)

18. [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — **D.3, THE addendum design**. ~1400+ lines post-this-session. NEW this session:
    - **§7.5.4 revised** (Option B — NO elab-meta-* API; uses compound-cell-component-ref/write helpers)
    - **§7.6.16 NEW** — Phase 1E `that-*` Storage Unification implementation notes (~150 lines, preserves architectural dialogue for future 1E opening)
    - Tracker updates: Step 2 Option B, Phase 1E row added, Phase 1B sequenced after 1E

19. **[`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md) — PPN 4C PARENT DESIGN (per user direction; ~2222 lines)**. The addendum IS a breakout from this. Cross-cutting concerns (see §5.5 below) flow between addendum and parent. Read:
    - **§1 Thesis** — "bring elaboration completely on-network; mantra as north star, NTT as guiderails, solver infrastructure (BSP-LE 2+2B) as substrate"
    - **§2 Progress Tracker** — especially Phase 3 (✅ `:type/:term` facet split with `classify-inhabit-value`), Phase 4 (⬜ CHAMP retirement — Step 2 intermediate toward this), Phase 7 (parametric trait resolution — uses dict-cell-id touched by Step 2), Phase 9b (γ hole-fill — uses Hasse-registry shared with Step 2), Phase 10 (union types via ATMS — coexists with Step 2 tagged-cell-value substrate), Phase 11 (elaborator strata → BSP scheduler), Phase 11b (diagnostic)
    - **§6.3 Phase 4** (CHAMP retirement resequenced AFTER Phase 9 per framing B; attribute-map `:type` facet absorbs meta storage — Step 2 intermediate)
    - **§6.7 Phase 11** (elaborator strata → BSP scheduler; part of addendum Phase 2A/B)
    - **§6.10 Phase 9+10** (union types via ATMS; Phase 3 of addendum delivers this)
    - **§6.12 Hasse-registry primitive** (Phase 2b, ✅ shipped; Step 2 uses the same hasse-registry-handle infrastructure)
    - **§6.15 Phase 3 mini-design** (✅ delivered; `classify-inhabit-value` shape is the precedent for Step 2 compound cells)
    - **§6.16 Phase 13** (progressive SRE domain classification — Step 2 adds 'worldview domain)

20. [`docs/research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md`](../../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md) — **PPN Track 4D proposal**. Read for context on Phase 1E — 1E is a prelude to 4D's full rules-level unification.

### §2.4 Session-Specific — Baseline + Hypotheses

21. [`docs/tracking/2026-04-23_STEP2_BASELINE.md`](../2026-04-23_STEP2_BASELINE.md) — **THE performance reference for Step 2**. 400+ lines, 12 sections:
    - **§1 Headline**: 11-195× meta-lifecycle improvements since PPN 4C started
    - **§2 bench-meta-lifecycle**: full ns/call data
    - **§3 bench-alloc**: cell/propagator/CHAMP/memory baselines
    - **§4 Probe per-command**: verbose breakdown
    - **§5 Hypotheses**: quantitative predictions + VAG success criteria
    - **§6 Measurement discipline**: bounce-back pattern (per-phase propose-then-decide)
    - **§7 Deferred**: post-Phase-4, post-Phase-3-addendum, post-PM-12 measurements
    - **§11 bench-ppn-track4c PRE0→post-T-2 A/B**: the answer to "have benchmarks moved since PPN 4C started?" (yes, meaningfully: 11-25% wall, 11-195× meta-lifecycle)

### §2.5 Session-Specific — Related Tracking Docs

22. [`docs/tracking/MASTER_ROADMAP.org`](../MASTER_ROADMAP.org) — confirms PPN series master hierarchy
23. [`docs/tracking/2026-03-13_PROPAGATOR_MIGRATION_MASTER.md`](../2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) — PM Master. PM Track 12 has THREE unlocks from PPN 4C (1e-α, 1e-β-iii, 1A-iii-a-wide Step 1+T-1). Step 2's parameter-injection pattern in meta-universe.rkt may eventually feed PM 12.
24. [`docs/tracking/DEFERRED.md`](../DEFERRED.md) — PM Track 12 registry scaffolding entries
25. [`docs/tracking/principles/POST_IMPLEMENTATION_REVIEW.org`](../principles/POST_IMPLEMENTATION_REVIEW.org) — consult when Step 2 close approaches

### §2.6 Session-Specific — THE PRIMARY CODE FILES FOR S2.b-i AUDIT

The files below are the audit target. S2.b-i's job is to enumerate every call site in them that needs migration.

**CORE infrastructure (read + understand)**:

26. [`racket/prologos/meta-universe.rkt`](../../../racket/prologos/meta-universe.rkt) — **NEW file, S2.a + S2.a-followup**. Lightweight imports (no type-lattice dep); parameter-injection for per-domain merge-fns + contradiction predicates; `init-meta-universes!` (allocates 4 compound cells + shared hasse-registry-handle); `compound-cell-component-ref` / `compound-cell-component-write` helpers; `meta-universe-cell-id?` predicate. Ready to be wired in S2.b.

27. [`racket/prologos/decision-cell.rkt`](../../../racket/prologos/decision-cell.rkt) — line ~502: `compound-tagged-merge(domain-merge)` factory added in S2.a. Works with per-component tagged-cell-value substrate.

**Lines to AUDIT in S2.b-i**:

28. [`racket/prologos/elaborator-network.rkt`](../../../racket/prologos/elaborator-network.rkt) — **line 135: `elab-fresh-meta`** (currently allocates per-meta cell; S2.b migrates to universe registration). Line ~1221+: parameter injection of merge-fns + contradiction predicates (from S2.a's followup, inert until init-meta-universes! called).

29. [`racket/prologos/metavar-store.rkt`](../../../racket/prologos/metavar-store.rkt) — callers to audit:
    - line ~1621 `fresh-meta`: wraps `elab-fresh-meta`; adds id-map + meta-info registration
    - line ~2011 `meta-solution/cell-id`: READ path (had dispatch changes attempted + reverted)
    - line ~1691-1793 `solve-meta-core!` / `solve-meta-core-pure`: WRITE path (had dispatch changes attempted + reverted)
    - line ~461 dict-cell-id (bridge-fn propagator output — affected by S2.b since dict metas ARE type metas)
    - line ~624 hm-cell-id (hasmethod propagator output — same)
    - Anywhere that calls `prop-meta-id->cell-id` + then treats the returned cid as a direct cell-id
    - `current-unsolved-metas-cell-id` interactions

30. [`racket/prologos/driver.rkt`](../../../racket/prologos/driver.rkt) — line ~2661: `prop-meta-id->cell-id` usage. Line 2544: `install-prop-network-callbacks!` registers `elab-fresh-meta`.

31. [`racket/prologos/unify.rkt`](../../../racket/prologos/unify.rkt) — lines 205, 257-259, 430: `meta-solution/cell-id` callers; `expr-meta-cell-id` direct access

32. [`racket/prologos/zonk.rkt`](../../../racket/prologos/zonk.rkt) — lines 75, 82, 492-502: zonk + zonk-at-depth use `meta-solution/cell-id`. Mock failure site surfaced `match: no matching clause for '#hasheq()`.

33. [`racket/prologos/pretty-print.rkt`](../../../racket/prologos/pretty-print.rkt) — line 81-83: `meta-solution/cell-id` for expr-meta display

34. [`racket/prologos/typing-core.rkt`](../../../racket/prologos/typing-core.rkt) — line 2817: `meta-solution/cell-id` in `infer-level`

35. [`racket/prologos/typing-propagators.rkt`](../../../racket/prologos/typing-propagators.rkt) — bridge-fn construction, hasmethod propagators, other propagators that receive meta cell-ids as output targets

36. [`racket/prologos/cell-ops.rkt`](../../../racket/prologos/cell-ops.rkt) — `elab-cell-read-worldview` and related utilities

**Support infrastructure (secondary)**:

37. [`racket/prologos/elab-network-types.rkt`](../../../racket/prologos/elab-network-types.rkt) — `elab-network` struct with `id-map`, `cell-info`, `meta-info` CHAMPs; `elab-cell-read`/`write`/`replace`. Step 2 interacts with these.

38. [`racket/prologos/hasse-registry.rkt`](../../../racket/prologos/hasse-registry.rkt) — `net-new-hasse-registry`, `hasse-registry-handle` struct; used by init-meta-universes! for shared handle

39. [`racket/prologos/infra-cell-sre-registrations.rkt`](../../../racket/prologos/infra-cell-sre-registrations.rkt) — `'worldview` SRE domain registered in S2.a (tail of file)

### §2.7 Session-Specific — Benchmarks + Probe

40. [`racket/prologos/benchmarks/micro/bench-meta-lifecycle.rkt`](../../../racket/prologos/benchmarks/micro/bench-meta-lifecycle.rkt) — **E section NEW (S2.a)**: E1-E5 compound-vs-per-cell A/B benchmarks. E4 shows compound path is 55% FASTER than E5 baseline. Extend for S2.b sub-phase measurements.

41. [`racket/prologos/benchmarks/micro/bench-alloc.rkt`](../../../racket/prologos/benchmarks/micro/bench-alloc.rkt) — cell/prop allocation + CHAMP baselines. Pre-Step-2 reference.

42. [`racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt`](../../../racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt) — M/A/E tiers. 2026-04-17 PRE0 baselines; full post-T-2 re-run documented in baseline doc §11.

43. [`racket/prologos/examples/2026-04-22-1A-iii-probe.prologos`](../../../racket/prologos/examples/2026-04-22-1A-iii-probe.prologos) — behavioral probe (28 expressions). Baseline at `data/probes/2026-04-22-1A-iii-baseline.txt` (post-T-2 refresh).

44. [`racket/prologos/examples/2026-04-17-ppn-track4c.prologos`](../../../racket/prologos/examples/2026-04-17-ppn-track4c.prologos) — PPN 4C acceptance file. Run for broader regression check.

### §2.8 Session-Specific — Dailies + Prior Handoffs

45. [`docs/tracking/standups/2026-04-22_dailies.md`](../standups/2026-04-22_dailies.md) — continuation session log appended this session. Covers: T-2 delivery, Phase 1E architectural dialogue, Step 2 baseline/hypotheses/measurement discipline, Step 2 revised + Phase 1E added, Step 2 S2.a delivery, Step 2 S2.a-followup, Step 2 S2.b rescoped.

46. [`docs/tracking/handoffs/2026-04-22_PPN_4C_T-2_HANDOFF.md`](2026-04-22_PPN_4C_T-2_HANDOFF.md) — **prior handoff** that started this session. Includes §9 mempalace Phase 2 notes.

47. [`docs/standups/standup-2026-04-22.org`](../../standups/standup-2026-04-22.org) — user's standup for this working-day interval.

---

## §3 Key Design Decisions (RATIONALE — do NOT re-litigate)

### §3.1 T-2 DELIVERED — "Open by Design" Map semantics

- Option C for the Map-value-type question: `expr-Open` as α-semantic universal type, display name "Open" (Framing 3), no user-writable syntax
- Override of 2026-03-20 CIU §8 D7 conscious + documented
- Retired `with-speculative-rollback` at map-assoc; other 5 sites scheduled for PM 12 light cleanup
- "The Pragmatic Prover" motto codified
- Probe `speculation_count` 12 → 0 (complete retirement for map ops)

### §3.2 Step 2 rescope to Option B — NO `elab-meta-*` API

Original S2.b plan introduced `elab-meta-read(enet, meta-id, domain)` / `elab-meta-write(enet, meta-id, domain, value)` as a new API. Rejected during 2026-04-23 architectural dialogue:

- Would be a PARALLEL API to `that-*` (position-keyed user-facing, per grammar form vision) at a different abstraction level
- Track 4D would have to retire it as part of its eventual storage unification
- Creates technical debt without proportional benefit

**Option B**: use existing `elab-cell-read/write(enet, cid)` mid-level API + new `compound-cell-component-ref/write(enet, cid, component-key)` helpers. No new API surface.

**Rationale**: landing-target architecture (Track 4D's `that-*` unification) is our NORTH STAR. Step 2's storage restructuring should be a clean STEPPING STONE, not a parallel path.

### §3.3 Phase 1E scheduled as dedicated follow-on

The `that-*` / meta-access storage unification is substantive work (~800-1200 LoC, 3-5 sessions) that deserves its own mini-design → Stage 2 audit → Stage 3 design cycle. Sequenced **between Step 2 and Phase 1B**.

Preserves 27 ns `that-read :type` fast path (critical constraint). Adds meta-position support via position-for-meta synthesis + that-* routing. Does NOT do rules-level unification (that's Track 4D).

D.3 §7.6.16 captures architectural considerations (7 items: position representation, meta-id ↔ position mapping, fast-path preservation, universe-cell integration, facet naming alignment, write-through semantics, Track 4D compatibility) for the future 1E mini-design cycle.

### §3.4 Measurement discipline — bounce-back, NOT automatic gate

Per-phase: Claude evaluates if phase is plausibly perf-material → proposes scope (what to measure + cost) → user decides. Balance investment against velocity.

**Always-do** (no proposal needed):
- Probe verbose run after typing/elab-touching phases (<1s)
- Suite timing comparison via `timings.jsonl` (free)
- Narrative delta in dailies

**Propose-and-wait**:
- `bench-meta-lifecycle` / `bench-alloc` / `bench-ppn-track4c` micros (3-10 min each)
- A/B via `bench-ab.rkt` (5-15 min)
- New micros for specific phases
- Dedicated hypothesis documents

**Pre-negotiated for Step 2**:
- Measurement at **S2.b end** (first-domain validation)
- Measurement at **S2.e end** (factory retirement validation vs §5 hypotheses)
- Skip S2.a/c/d/f

### §3.5 S2.a infrastructure DELIVERED

`compound-tagged-merge` factory (decision-cell.rkt), `meta-universe.rkt` with 4 universe-cell parameters + init + helpers + `meta-universe-cell-id?` predicate, `'worldview` SRE domain registered, bench-meta-lifecycle.rkt extended with E1-E5 A/B micros.

**Surprise finding**: E4 compound-cell-component-ref = 43-52 ns/call vs E5 elab-cell-read per-meta = 113 ns/call. Compound path is **~55% FASTER**, not slightly slower as §5 hypothesized. Strengthens Step 2's case.

### §3.6 S2.a-followup: meta-universe.rkt lightweight refactor

Broke potential import cycle (meta-universe.rkt → type-lattice.rkt → reduction.rkt → metavar-store.rkt → [S2.b would add] meta-universe.rkt) via parameter-injection pattern: per-domain merge-fns + contradiction predicates are injected by elaborator-network.rkt at module load.

`default-pointwise-hasheq-merge` + `default-no-contradicts?` serve as fallbacks if injection doesn't happen (currently inert since nothing calls init-meta-universes! yet).

### §3.7 S2.b rescoped to Option S2.b-staged

Attempted comprehensive S2.b migration (modify elab-fresh-meta + update meta-solution/cell-id + solve-meta-core-pure); failure mode surfaced (`match: no matching clause for '#hasheq()` in zonk.rkt:492 via unify-core). Root cause: MANY more callers of `prop-meta-id->cell-id` than anticipated — prop installations, bridge-fns, dict/hm propagator outputs, etc.

**Reverted migration**; kept infrastructure.

New plan: S2.b-i audit phase → S2.b-ii reader/writer → S2.b-iii fresh-meta + consumers → S2.b-iv propagator installations → S2.b-v driver callbacks. Each sub-sub-phase small + testable.

---

## §4 Surprises and Non-Obvious Findings

### §4.1 Compound-cell read path is FASTER than per-meta baseline (S2.a win)

§5 hypothesis: compound path likely 250-350 ns due to hash-ref overhead (regression allowed up to 0.4 μs).
Reality: 43-52 ns/call across 10-500 components (FASTER than 113 ns baseline per-meta read).

**Why**: the per-meta baseline (113 ns) includes outer-cells CHAMP walk through hundreds of cells. With fewer top-level cells (universes consolidate many into one), outer CHAMP is smaller → faster initial lookup. Hasheq-ref inside is so fast (13 ns for 500-key hasheq) that the total is still faster.

**Implication**: Step 2 is a READ-PATH WIN, not just an allocation win. Strengthens the architectural case.

### §4.2 Scope of S2.b was underestimated

Estimated 200-400 LoC per D.3 §7.5.4; reality ~500-900 LoC. Missed caller classes:

1. **`prop-meta-id->cell-id` direct consumers beyond `meta-solution/cell-id`**: dict-cell-id (metavar-store.rkt:461), hm-cell-id (:624), mult-cid (driver.rkt:2661)
2. **Propagator installations** receiving meta cell-ids as OUTPUTS: bridge-fn, hasmethod propagator, constraint-retry propagators
3. **`net-cell-read` in propagator fire functions**: pure functional reads from meta cells
4. **Constraint readiness tracking**: `current-unsolved-metas-cell-id` interactions

**Root principle** (candidate for codification): **migrating a cell-allocation factory migrates the IDENTITY of those cells across the codebase**. Scope by enumerating IDENTITY CONSUMERS, not just READERS.

### §4.3 Meta-lifecycle performance has moved dramatically since PPN 4C started

Per bench-meta-lifecycle vs 2026-04-17 PRE0:
- `fresh-meta`: 38.26 μs → 3.45 μs (~11× faster, cell path introduction)
- `solve-meta!`: 38.99 μs → 8.53 μs (~4.6× faster)
- `meta-solution` (cell path): 40.08 μs (CHAMP) → 0.205 μs (~195× faster — path CHANGED not just optimized)

**Implication**: PPN 4C work IS bearing fruit. Step 2 continues the trajectory. Phase 4 (CHAMP retirement) will harvest the remaining CHAMP overhead.

### §4.4 Phase 4 sequencing interacts with Step 2 scope

D.3 parent §6.3 (Phase 4) resequenced AFTER Phase 9 per framing B: "attribute-map :type facet absorbs meta storage; no separate A2-II follow-up." Under this framing:
- Phase 9 (cell-based TMS) is prerequisite to Phase 4 β2
- Step 2 (THIS addendum work) delivers per-domain compound cells — intermediate toward Phase 4 β2's "single authoritative attribute-map"
- Step 2 universe cells are NOT the final state; Phase 4 β2 collapses them into attribute-map facets

**Watch**: make sure S2.b doesn't over-commit to universe-cell SHAPE that Phase 4 would then have to unwind. The current shape (hasheq meta-id → tagged-cell-value) is compatible with Phase 4's `classify-inhabit-value` at attribute-record positions. Good.

### §4.5 The `#hasheq()` in zonk via unify error

Specific failure mode to remember during S2.b-i: if `elab-cell-read` is called on a universe cell (post-migration) and the caller treats the result as a raw type expression, it'll get a hasheq and crash at the next `match [(expr-X ...) ...]`.

The `meta-solution/cell-id` dispatch I added handles this IF the cell-id is a known universe cid. But callers that don't go through meta-solution/cell-id (e.g., direct net-cell-read in propagator fire functions, bridge-fn setup, etc.) need separate handling.

**S2.b-i's job**: enumerate these sites so we don't hit this failure mode again.

---

## §5 Open Questions and Deferred Work

### §5.1 S2.b-i audit scope (immediate next task)

Produce `docs/tracking/2026-04-23_STEP2_S2B_AUDIT.md` (or dated later) containing:

**Per-site enumeration**:
- File:line reference
- Current pattern (read / write / propagator input / propagator output / component-path decl)
- Meta-type context (type / mult / level / session — Step 2 only touches TYPE in S2.b-ii through S2.b-v)
- Migration pattern to apply
- Any special considerations

**Categories expected** (per §4.2 caller classes):
1. Direct `meta-solution/cell-id` callers (unify, zonk, typing-core, pretty-print) — covered by my reverted dispatch logic
2. Direct `prop-meta-id->cell-id` users + direct reads
3. Propagator installations receiving meta cell-ids as outputs
4. Bridge-fn construction (trait resolution, hasmethod)
5. Constraint-retry propagators
6. Driver callbacks (current-prop-fresh-mult-cell, etc.)
7. Current-unsolved-metas tracking

**Grep commands to run during audit**:
- `grep -rn "prop-meta-id->cell-id" racket/prologos/`
- `grep -rn "expr-meta-cell-id" racket/prologos/`
- `grep -rn "meta-solution/cell-id" racket/prologos/`
- `grep -rn "elab-fresh-meta" racket/prologos/`
- `grep -rn "elab-cell-read.*cid\|elab-cell-write.*cid" racket/prologos/` — targeted

### §5.2 Phase 4 interaction scope

Per §4.4, Step 2's universe-cell shape must be compatible with Phase 4's eventual attribute-map collapse. Check during S2.b-i whether:
- Universe-cell hasheq value shape matches attribute-map's per-position record shape
- Merge semantics compose correctly
- Any universe-cell-specific invariants that Phase 4 would need to preserve

### §5.3 Phase 1E considerations during S2.b

Phase 1E will route `that-*` to universe cells for meta positions. To make 1E clean:
- Ensure universe cell-ids are accessible via parameters (they are)
- Ensure per-meta access API is consistent (compound-cell-component-ref works)
- Don't introduce naming that 1E would need to rename

### §5.4 Racket code as separate mempalace wing

User raised this end-of-session. Deferred to post-S2.b-i evaluation:
- S2.b-i's enumerated queries ("all callers of prop-meta-id->cell-id") would be a natural eval set
- If semantic search of code adds value over grep → adopt code-wing, mine periodically
- If marginal → stick with docs-only
- Coupled consideration: post-commit hook for auto re-mine (currently deferred Phase 3 per mempalace.md)

### §5.5 Cross-cutting concerns between addendum and PPN 4C parent

Per user direction in handoff request — enumerating explicitly for future-session reference:

| Parent Track Phase | Addendum Interaction | Watch |
|---|---|---|
| Phase 3 (`:type`/`:term` split) ✅ | Step 2 compound cells coexist with attribute-map's classify-inhabit-value | Ensure universe cells don't duplicate/contradict attribute-map |
| Phase 4 (CHAMP retirement) ⬜ | Step 2 is intermediate step; Phase 4 β2 eventually absorbs | Don't over-commit to universe shape Phase 4 would rework |
| Phase 7 (parametric trait resolution) ⬜ | dict-cell-id propagators touched by S2.b | Bridge-fn setup in metavar-store.rkt:461 affected |
| Phase 8 (Option A freeze) ⬜ | Reads `:term` facet via `that-*` | 1E unifies access; Step 2 substrate enables it |
| Phase 9 (BSP-LE 1.5 cell-based TMS) ⬜ = addendum Phase 3 | Step 2 tagged-cell-value substrate | Step 2 depends on S1 substrate (done) |
| Phase 9b (γ hole-fill) ⬜ | Shares hasse-registry-handle | Universe `'worldview` hasse-registry may be reused |
| Phase 10 (union via ATMS) ⬜ = addendum Phase 3 | Tagged entries per universe component | Compound-tagged-merge supports branch-tagged writes |
| Phase 11 (strata → BSP) ⬜ = addendum Phase 2 | Meta universes affect retraction stratum | S(-1) retraction clears per-meta entries from universe cells |
| Phase 11b (diagnostic) ⬜ | Backward residuation through dependency graph | Universe-cell dependency paths need structural support |
| Phase 12 (Option C freeze) ⬜ | `expr-cell-ref` struct; reading IS zonking | Universe cell addressing via meta-id component-path |
| Phase 13 (progressive SRE classification) ⬜ | `'worldview` domain registered in S2.a | Add `'meta-universe-type` etc. classifications as domains mature |

**Strategic implication**: Step 2 is infrastructure work. It should NOT pre-commit to shapes that downstream phases will unwind. When in doubt, favor compatibility with Phase 4 β2's end state (attribute-map as single meta store).

### §5.6 Codification candidates (for DEVELOPMENT_LESSONS.org)

Watching list post-this-session:

| Pattern | Data points | Promotion gate |
|---|---|---|
| Cell-allocation factory migrates identity | 1 (S2.b scope finding) | 2 more instances → codify |
| Positive measurement surprise (hypothesis was too pessimistic) | 1 (S2.a compound-cell 55% faster) | 2 more → codify as methodology reminder |
| Architectural option discovery from dialogue (Option A/B/C framing) | 2 (T-2 α/β/γ + `_`/`Any`/`Open`; Step 2 A/B/C) | Established pattern; document in DESIGN_METHODOLOGY |
| Parameter-injection to break import cycles | 1 (meta-universe.rkt cycle break) | Might be specific; watch for more instances |
| Measurement bounce-back (Claude propose, user decide) | 1 (2026-04-23) | 2 more phases using pattern → codify |

---

## §6 Process Notes

### §6.1 Conversational mini-design cadence sustained

Step 2 mini-design + Phase 1E architectural dialogue done via chat, recorded in D.3 sections (§7.5.4 revised, §7.6.16 new). No separate Stage 1/2/3 artifacts. User-preferred pattern.

### §6.2 Per-commit dailies discipline

Every meaningful commit triggered a dailies update. The dailies file (`2026-04-22_dailies.md`) now covers the full session arc with commit-by-commit detail through Step 2 S2.a-followup. The DAILIES FILE IS STILL NAMED 2026-04-22 per workflow.md "creation-to-creation" rule — no new daily opened during this continuation session.

### §6.3 Probe + acceptance file discipline

Each sub-phase ran the probe against baseline. Probe diff = 0 (semantic) confirmed throughout. `data/probes/2026-04-22-1A-iii-baseline.txt` was refreshed post-T-2.

### §6.4 mempalace Phase 2 in use

`mcp__mempalace__mempalace_search` used successfully during architectural dialogue:
- Located 2026-03-20 CIU §8 D7 prior art (substantial find — would have been hard to locate via grep)
- Located D.3 §7.6.7 T-2 implications
- Located allocation-efficiency audit + BSP-LE Track 0 PIR

**Re-mined at end of session** to capture this session's new docs (S2.a commits, baseline doc, Phase 1E notes, Step 2 revision).

**Discipline maintained**: cross-checked every hit against current dailies + D.3 before acting on it. No recency failures observed.

### §6.5 pipeline.md refreshed this session

`.claude/rules/pipeline.md` "New AST Node" section was updated per user direction ("stale after our recent efforts"). Restructured into core pipeline / surface-syntax / on-network / unify+FFI sections. Added `pnet-serialize.rkt` as REQUIRED (was missing pre-PM-10). Added "Internal-only nodes" section with `expr-Open` as example (10 files, not 14).

### §6.6 Commit hash index (this session arc)

Key session commits (chronological):
- `fd391f5a` (prior session) — Handoff: PPN 4C T-2 pickup
- `06d4ab6c` — mempalace Phase 2 adoption
- `e85ddda5` — HANDOFF_PROTOCOL.org + MASTER_ROADMAP in hot-load
- `4bfbd141` — PPN 4C T-2 Commit 1/3: expr-Open AST + pipeline
- `246d4c2e` — T-2 Commit 2/3: typing semantics + speculation retirement
- `07fda438` — T-2 Commit 3/3: elaborator + tests + baseline
- `bb058491` — D.3 §7.6.15 + tracker: T-2 DELIVERED
- `c4b598c4` — Dailies + pipeline.md refresh
- `f8de4625` — Merge origin/main: first-contributor PR (CI fixes #3)
- `3ba56387` — Step 2 performance baseline + hypotheses + measurement discipline
- `7b602bd8` — D.3 Step 2 revised (Option B) + Phase 1E added + measurement bounce-back
- `ded412db` — Step 2 S2.a: PU refactor infrastructure
- `2bab505a` — Step 2 S2.a-followup: meta-universe.rkt lightweight refactor

---

## §7 What the Continuation Session Should Produce

### §7.1 Immediate (S2.b-i audit execution)

1. Hot-load EVERY §2 document IN FULL (especially D.3, PPN 4C parent D.3, baseline doc)
2. Summarize understanding back to user — especially:
   - The 3 class of caller categories (readers via meta-solution/cell-id; direct cell-id users; propagator installations)
   - Why S2.b was rescoped (the `#hasheq() in zonk` failure mode)
   - The "identity migration" principle
   - The positive S2.a surprise (55% faster read)
   - Cross-cutting concerns with Phase 4, Phase 7, Phase 10
3. Begin S2.b-i audit per §5.1 spec:
   - Use grep commands to enumerate call sites
   - Categorize each
   - Propose migration pattern per category
   - Produce committed document `docs/tracking/2026-04-23_STEP2_S2B_AUDIT.md` (or later date if session runs over)
4. Checkpoint with user before S2.b-ii implementation begins

### §7.2 Medium-term (post-S2.b-i, through Step 2 completion)

- **S2.b-ii** reader/writer update (meta-solution/cell-id + solve-meta-core-pure) — ~100-200 LoC
- **S2.b-iii** fresh-meta + dict-cell-id + hm-cell-id consumers — ~200-400 LoC
- **S2.b-iv** propagator installations (`:component-paths` updates) — ~100-200 LoC
- **S2.b-v** driver callbacks — ~50-100 LoC
- **S2.b measurement**: run bench-meta-lifecycle + bench-alloc; compare vs baseline §5 hypotheses
- **S2.c mult domain** migration (expected smaller)
- **S2.d level + session** migration
- **S2.e retire old factories + final measurement**
- **S2.f cleanup + S2-VAG**

### §7.3 Longer-term

- **Phase 1E** (that-* storage unification) — dedicated design cycle
- **Phase 1B** (tropical fuel primitive)
- Phase 1C/1V/2/3/V per addendum
- Post-addendum: main-track Phase 4 (CHAMP retirement) — the natural pair to Step 2

---

## §8 Final Notes

### §8.1 What "I have full context" requires

- Read every document in §2 IN FULL — especially:
  - D.3 (the addendum — our design)
  - PPN 4C parent D.3 (the parent — cross-cutting concerns)
  - 2026-04-23_STEP2_BASELINE.md (hypotheses + measurement)
  - meta-universe.rkt (the infrastructure we built)
  - 2026-04-22_dailies.md (full session narrative)
- Articulate the §3 decisions — especially why Option B not Option A, why Phase 1E exists, why bounce-back measurement
- Know the §4 surprises — especially §4.2 scope finding + §4.1 positive measurement + §4.5 specific failure mode
- Understand §5.5 cross-cutting concerns matrix — when to check parent design, when to check addendum

### §8.2 Git state

```
branch: main (ahead of origin by ~20 commits; don't push without direction)
HEAD: 2bab505a (Step 2 S2.a-followup: meta-universe.rkt lightweight refactor)
working tree: clean (benchmark/cache artifacts untracked)
```

### §8.3 User-preference patterns (observed)

- **Completeness over deferral** — user reaffirmed this session: "Our completeness and correctness principles demand of us to dig deep, stay principled, and work through the hard things that make everything else seem simple."
- **Architectural correctness > implementation cost** — "without concern of the implementation cost. Pragmatic implementation shortcuts should never be on the table for our consideration."
- **Conversational mini-design** — user prefers mini-design in existing design doc, not separate Stage 2/3 artifacts
- **Measurement bounce-back** — codified 2026-04-23: "could be undue tax on time and development iterations; needs to balance with needs, not just be an automatic gate"
- **Step back, charter-align** — user periodically pauses to ask architectural-scope questions (Option B for Step 2; Phase 1E as follow-on not absorbed)
- **"The Pragmatic Prover"** — coined 2026-04-23 as design motto. Clojure ergonomics + depdendent-type rigor; schema for verification when wanted; open defaults for exploration
- **Gratitude + explicit "Ready to proceed"** — user gives clear go-aheads; when hesitant, articulates the uncertainty

### §8.4 Session arc summary

Started with: pickup from 2026-04-22_PPN_4C_T-2_HANDOFF.md (T-2 pending).

Delivered:
- T-2 complete (3 commits)
- Step 2 baseline + hypotheses + measurement discipline (1 commit)
- Step 2 revised to Option B + Phase 1E added (1 commit)
- Step 2 S2.a infrastructure (1 commit)
- Step 2 S2.a-followup (lightweight refactor, 1 commit)
- Step 2 S2.b attempted + reverted (scope discovery)
- ~12+ commits total; ~2200 LoC added across prod + tests + docs; ~140 LoC of production deletions (speculation retirements)

The context is substantial and load-bearing. Hot-load everything. The S2.b-i audit is the next unit of work and should produce a comprehensive enumeration document before any further migration code is written.

**The context is in safe hands.**
