# PPN 4C Addendum Step 2 S2.e-i Handoff

**Date**: 2026-04-25 (S2.e session close — S2.c-v + S2.d-level + S2.d-session + S2.d-followup + S2.e mini-design ALL delivered)
**Purpose**: Transfer context into a continuation session to pick up **S2.e-i — implement Option C-4 lazy universe init in fresh-X-meta** (4 sites; ~20-40 LoC; eliminates fallback path structurally; enables aggressive retirement in S2.e-ii through S2.e-v).

**Before reading anything else**: read [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org). The Hot-Load Reading Protocol requires reading EVERY §2 document IN FULL before summarizing understanding back to the user. **Hot-load is a PROTOCOL, not a prioritization** — codified at [`DEVELOPMENT_LESSONS.org`](../principles/DEVELOPMENT_LESSONS.org) § "Hot-Load Is a Protocol, Not a Prioritization" (now at 4 data points across sessions). User explicitly enforced this at session start with "I expect that our context to reach ~500K tokens through this process" — comply.

**CRITICAL meta-lessons from this session arc** — read these BEFORE anything else:

1. **Capture-gap pattern (2 data points THIS session — graduation-ready)**. When naming a future phase as the home for work ("Phase 4D / 4 / 1E will handle X"), VERIFY the work is actually captured in that phase's design doc. User caught this twice in one session — first with §7.5.14.1 expansion (per-domain meta-store/champ-box/factory parameter parallels surfaced in S2.d-followup audit), second with §7.5.14.4 transient consolidation capture (S2.e mini-design audit). **Codified discipline**: every "future phase will handle X" claim requires capture verification (or explicit capture creation) at the time of the claim.

2. **Backward-compat-as-rationalization audit pattern (1 data point THIS session)**. The workflow.md "preserved for backward-compat" red-flag phrase IS the test. When the phrase appears in commit messages or design docs, audit consumer dependencies. If no consumers actually depend on the preserved value, it's scaffolding (honest framing) not "backward-compat" (rationalization). User caught this with the `sess-meta.cell-id = universe-cid` choice; audit revealed 2 production consumers both pass to a function that ignores the value under universe-active per Move B+. Path B reframe: change to `#f` + reframe documentation. Same pattern applied to `expr-meta.cell-id` for parallel honesty.

3. **Pipeline.md "Per-Domain Universe Migration" checklist works prophylactically (3rd data point — graduation-ready)**. S2.c-iv hit the 4-min hang BEFORE the checklist existed; S2.d-level + S2.d-session both landed cleanly with the checklist applied. ~20 min per domain post-checklist vs ~50 min pre-checklist. Codified procedural rules MULTIPLY in value as more sites adopt them.

4. **Partial-state regression unwinds when architecture completes (3 data points — graduation-ready)**. S2.a positive surprise (compound 55% faster); S2.b-iv solve-meta! +31% regression; S2.c-iv solve-meta! UNWOUND to -10% PAST baseline. Trends matter more than single-phase absolutes. Treat partial-state regressions as data points for the architecture's amortization curve, not as failures requiring immediate resolution.

5. **§5 hypothesis was framed wrong** (architectural insight, captured to Track 4D). Hypothesis "cells ≤ 42, cell_allocs ≤ 1000" was framed for PERSISTENT meta cells. Measurement reveals the bottleneck is per-command TRANSIENT elaboration (~30-50 cells per command × 28 commands = ~1100 transient allocations dominating cell_allocs). Step 2 met its actual charter (persistent meta consolidation, dispatch unification, Move B+ benefit retained); the §5 metric was framed for a different bottleneck. Per-command transient consolidation is captured in §7.5.14.4 + Track 4D research §5.4 + DEFERRED.md as Track 4D scope. **S2.e-vi MUST honestly reframe rather than rationalize.**

6. **Adversarial VAG continues to surface drift the implementer can't see**. S2.c-iv adversarial VAG surfaced 2 §7.5.14.3 drifts; user pushback on S2.d-session "backward-compat" framing surfaced Path B; user pushback on "Phase 4D / 4 / 1E will handle X" surfaced capture gaps. Implementer's vocabulary normalizes drift; only external challenge surfaces it. Strong argument for keeping conversational cadence + treating user pushback as highest-signal feedback.

7. **Full suite as regression gate when touching code is RULE, not option** (process correction this session). User correction: "we should always run full suite as a regression gate when touching actual code, and adding tests. So yes. No need to ask. That should be part of the process." Internalized.

---

## §1 Current Work State (PRECISE)

- **Track**: PPN Track 4C Phase 9+10+11 Addendum — substrate + orchestration unification (per D.3)
- **Parent track**: PPN Track 4C ([`2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md))
- **Phase**: 1A-iii-a-wide Step 2 (PU refactor) — Option B per D.3 §7.5.4
- **Sub-phase**: **S2.c-v + S2.d-level + S2.d-session + S2.d-followup + S2.e mini-design ALL ✅** (this session arc); **S2.e-i NEXT** (Option C-4 lazy universe init in fresh-X-meta)
- **Stage**: Stage 4 Implementation
- **Design document**: D.3 at [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — §7.5.15 NEW captures S2.e mini-design + 7 sub-phases + Option C-4 decision; §7.5.14.4 NEW captures per-command transient finding for Track 4D scope
- **Last commit**: `209d5721` (S2.e mini-design + 4 captures)
- **Branch**: `main` (ahead of origin/main by many commits; don't push unless directed)
- **Working tree**: clean except benchmark data + pnet cache artifacts + user's standup additions
- **Suite state**: **7920 tests / 116.7s / 0 failures** (last full-suite run at S2.d-followup `34972bac` close — within 118-127s baseline variance, on lower end)
- **Baseline doc**: [`2026-04-23_STEP2_BASELINE.md`](../2026-04-23_STEP2_BASELINE.md) — §12.4 added 2026-04-25 with post-S2.c-iv data + STRONG GO for S2.d decision

### Progress Tracker snapshot (D.3 §3, post-S2.e-mini-design close)

| Sub-phase | Status | Commit |
|---|---|---|
| 1A-iii-a-wide Step 1 (TMS retirement) | ✅ | 5 sub-phase commits |
| Path T-1 (documentation) | ✅ | `b7f8e58d` |
| Path T-2 (Open by Design) | ✅ | 3 commits + tracker |
| T-3 (set-union merge) | ✅ | 4 commits |
| Step 2 S2.a (infrastructure) | ✅ | `ded412db` |
| Step 2 S2.a-followup | ✅ | `2bab505a` |
| Step 2 S2.b (TYPE domain) | ✅ CLOSED | 12+ commits ending `aeb0ff24` |
| Step 2 S2.c mini-design | ✅ | `107a37c6` |
| Step 2 S2.precursor | ✅ | `1c3970d0` |
| Step 2 S2.c-i (3 tasks) | ✅ | `3ceec4fc` + `9e975d45` |
| Step 2 S2.c-ii | ✅ | `bf25be40` |
| Step 2 S2.c-iii | ✅ | 6 commits ending `8f686a6f` |
| Step 2 S2.c-iii Move B+ corrective | ✅ | 3 commits: `9f7c0b82` + `c86596e0` + `08468e5e` |
| Step 2 S2.precursor++ (CBC compound-cell + γ=#f) | ✅ | `22866050` |
| Step 2 S2.c-iv (mult migration) | ✅ | 3 commits ending `2210557c` |
| Methodology codifications (round 1) | ✅ | `9f7c0b82` |
| Methodology codifications (round 2) | ✅ | `d5aba2c6` |
| **S2.c-v (probe + acceptance + microbench + GO)** | ✅ | `03d08184` (THIS SESSION) |
| **S2.d-level (LEVEL universe migration)** | ✅ | `badf5fa9` (THIS SESSION) |
| **S2.d-session (SESSION universe migration — All 4 domains universe-active)** | ✅ | `440e6139` (THIS SESSION) |
| **S2.d-followup (Path B honesty reframe + capture gaps)** | ✅ | `34972bac` (THIS SESSION) |
| **S2.e mini-design + 4 captures** | ✅ 🔄 design landed | `209d5721` (THIS SESSION) |
| **Step 2 S2.e-i (Option C-4 lazy init in 4 fresh-X-meta sites)** | ⬜ **NEXT** | — |
| Step 2 S2.e-ii (retire `current-prop-mult-cell-write`) | ⬜ | — |
| Step 2 S2.e-iii (retire 3 factory callbacks) | ⬜ | — |
| Step 2 S2.e-iv (retire 6 store/champ-box params + 4 fallback fns + meta-domain-info cleanup) | ⬜ | — |
| Step 2 S2.e-v (retire `elab-add-type-mult-bridge` test-only) | ⬜ | — |
| Step 2 S2.e-vi (final §5 measurement + honest reframe + 4 codifications) | ⬜ | — |
| Step 2 S2.e-VAG (adversarial close) | ⬜ | — |
| Phase 1E (`that-*` storage unification) | ⬜ | — |
| Phase 1B (tropical fuel) | ⬜ | Follows 1E |

### Next immediate task — S2.e-i

**Goal**: Implement Option C-4 lazy universe init in 4 `fresh-X-meta` sites. Scope ~20-40 LoC. ZERO test fixture surgery required. Eliminates fallback path structurally; enables aggressive retirement in S2.e-ii through S2.e-v.

**Per D.3 §7.5.15.1**: Option C-4 = lazy-init universe cells in `fresh-X-meta` when `net-box` is set but `universe-cid` is not. Implementation pattern:

```racket
(define (fresh-meta ctx type source)
  ...
  (define net-box (current-prop-net-box))
  ;; C-4 lazy init: ensure universe cells exist for this network
  (when (and net-box (not (current-type-meta-universe-cell-id)))
    (set-box! net-box (init-meta-universes! (unbox net-box))))
  (define type-universe-cid (current-type-meta-universe-cell-id))
  ...)
```

**4 sites** to touch in `metavar-store.rkt`:
1. `fresh-meta` (type domain — line ~1755)
2. `fresh-mult-meta` (line ~2618 — currently has universe-path branch from S2.c-iv)
3. `fresh-level-meta` (line ~2479 — currently has universe-path branch from S2.d-level)
4. `fresh-sess-meta` (line ~2710 — currently has universe-path branch from S2.d-session post-followup with cell-id=#f)

**Drift risks (D1-D5 named in §7.5.15.3)**:
- D1: `init-meta-universes!` must be safe to call mid-fresh-X-meta (atomic; no in-flight network state). Verify by audit + targeted tests.
- D2: champ-fallback dead-pointer cleanup — `meta-domain-info` entries reference `'champ-fallback` + `'legacy-fn`; entries must be cleaned (not just functions retired). NOT in S2.e-i scope (that's S2.e-iv); but be aware.
- D3: test fixture surprise — some tests may explicitly test the meta-store / champ-box parameters. Targeted tests catch.
- D4: §5 hypothesis temptation to rationalize (NOT S2.e-i scope; S2.e-vi handles).
- D5: capture discipline regression — apply per-domain capture uniformly.

**Estimated scope**: ~30-60 min total (mini-design done; just implement + verify + commit). No microbench-claim-verification obligation (no load-bearing microbench claim for S2.e-i).

**After S2.e-i**: S2.e-ii (~5 min — delete `current-prop-mult-cell-write` and its single read site).

---

## §2 Documents to Hot-Load (ORDERED — NO TIERING)

**CRITICAL**: per the codified hot-load-is-protocol rule, read EVERY document IN FULL. NO tiering. ~500K token budget anticipated. User will explicitly enforce.

### §2.0 Start here

0. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org)

### §2.1 Always-Load

1. [`CLAUDE.md`](../../../CLAUDE.md) + [`CLAUDE.local.md`](../../../CLAUDE.local.md)
2. [`MEMORY.md`](../../../MEMORY.md)
3. [`DESIGN_METHODOLOGY.org`](../principles/DESIGN_METHODOLOGY.org) — Stage 2-4 critical (Per-Phase Protocol with adversarial VAG + microbench claim verification)
4. [`DESIGN_PRINCIPLES.org`](../principles/DESIGN_PRINCIPLES.org)
5. [`CRITIQUE_METHODOLOGY.org`](../principles/CRITIQUE_METHODOLOGY.org) — § Cataloguing Instead of Challenging extends to all gates
6. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org) (self-reference)
7. [`docs/tracking/MASTER_ROADMAP.org`](../MASTER_ROADMAP.org)
8. [`docs/tracking/2026-03-26_PPN_MASTER.md`](../2026-03-26_PPN_MASTER.md)
9. [`DEVELOPMENT_LESSONS.org`](../principles/DEVELOPMENT_LESSONS.org) — UPDATED entries for Stage 2 audits + Hot-Load is Protocol; **2 NEW codification candidates from this session**: (a) capture-gap pattern (2 data points), (b) backward-compat-as-rationalization audit pattern (1 data point) — graduation pending S2.e-vi

### §2.2 Architectural Rules (loaded via `.claude/rules/`)

10. [`.claude/rules/on-network.md`](../../../.claude/rules/on-network.md)
11. [`.claude/rules/structural-thinking.md`](../../../.claude/rules/structural-thinking.md)
12. [`.claude/rules/propagator-design.md`](../../../.claude/rules/propagator-design.md)
13. [`.claude/rules/workflow.md`](../../../.claude/rules/workflow.md) — adversarial VAG + microbench-claim-verification + "preserved for backward-compat" red-flag rules
14. [`.claude/rules/testing.md`](../../../.claude/rules/testing.md) — full suite as regression gate when touching code is RULE
15. [`.claude/rules/pipeline.md`](../../../.claude/rules/pipeline.md) — § "Per-Domain Universe Migration" checklist (3 prophylactic data points; graduation-ready)
16. [`.claude/rules/stratification.md`](../../../.claude/rules/stratification.md)
17. [`.claude/rules/mempalace.md`](../../../.claude/rules/mempalace.md)
18. [`.claude/rules/prologos-syntax.md`](../../../.claude/rules/prologos-syntax.md)

### §2.3 Session-Specific — THE DESIGN DOCUMENTS (READ IN FULL)

19. [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — D.3 addendum design. **Critical sections updated this session**:
    - **§3 Progress Tracker** — S2.c-v + S2.d-level + S2.d-session + S2.d-followup + S2.e mini-design rows added 2026-04-25
    - **§7.5.13.6.1** — S2.c-iii mini-audit findings (5 surprises with mantra-violation framing)
    - **§7.5.13.6.2** — Honest re-VAG with adversarial framing (Move B+)
    - **§7.5.14** — S2.e Forward Scope Notes:
      - **§7.5.14.1 EXPANDED 2026-04-25** — per-domain off-network parameter retirements (10 params total: 3 meta-store + 3 champ-box + 3 factory + 1 write callback)
      - **§7.5.14.2** — Session-domain dual-surface retirement
      - **§7.5.14.3** — Mult-domain post-migration cleanup
      - **§7.5.14.4 NEW 2026-04-25** — per-command transient cell consolidation finding (Track 4D scope, with full per-command breakdown table)
      - **§7.5.14.5** — placeholder
    - **§7.5.15 NEW 2026-04-25** — S2.e mini-design (5 subsections): Option C-4 decision, sub-phase partition, drift risks D1-D5, completion criteria, cross-cutting captures verified

20. [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md) — PPN 4C parent design. Same critical sections as prior handoffs: §1, §2, §6.3 (Phase 4 with cache-field retirements), §6.7 (Phase 11), §6.10 (Phase 9+10), §6.11 (Hyperlattice/SRE/Hypercube), §6.12 (Hasse-registry), §6.13 (PUnify audit), §6.15 (Phase 3 :type/:term), §6.16 (Phase 13).

21. [`docs/research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md`](../../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md) — Track 4D vision. **§5.4 NEW 2026-04-25** — forward-pointer to per-command transient consolidation as Track 4D scope.

### §2.4 Session-Specific — Baseline + Hypotheses

22. [`docs/tracking/2026-04-23_STEP2_BASELINE.md`](../2026-04-23_STEP2_BASELINE.md) — UPDATED 2026-04-25 with §12.4 (post-S2.c-iv measurement + STRONG GO for S2.d). S2.e-vi will add §12.5 with post-S2.e measurement + honest §5 reframing.

23. [`docs/tracking/DEFERRED.md`](../DEFERRED.md) — UPDATED 2026-04-25 with:
    - **PM Track 12 section** (~line 361+): 4 NEW entries from S2.d-followup audit (per-domain meta-store, per-domain champ-box, per-domain factory callbacks, mult write callback)
    - **"Future Track 4D Scope: Per-Command Transient Cell Consolidation" NEW section** (at end): cross-track tracking entry for the §7.5.14.4 finding

### §2.5 Session-Specific — THE PRIMARY CODE FILES (read for understanding)

24. [`racket/prologos/metavar-store.rkt`](../../../racket/prologos/metavar-store.rkt) — POST-S2.d-followup state:
    - `meta-domain-info` table (~line 2330): ALL 4 domains have `'universe-active? = #t` ('type, 'mult, 'level, 'session)
    - `meta-domain-solution` core (~line 2371): Move B+ form (option 4 PURE for universe-active path; legacy-fn dispatch retained for fallback)
    - `fresh-meta` (~line 1755): universe-path branch sets `meta-cell-id` to **#f** under universe-active (Path B reframe 2026-04-25)
    - `fresh-mult-meta` (~line 2618): universe-path branch from S2.c-iv (mult-meta has no cell-id field on struct)
    - `fresh-level-meta` (~line 2479): universe-path branch from S2.d-level (level-meta has no cell-id field)
    - `fresh-sess-meta` (~line 2710): universe-path branch sets `cell-id` to **#f** under universe-active (Path B reframe; was misleadingly universe-cid)
    - `solve-meta-core!`, `solve-mult-meta!`, `solve-level-meta!`, `solve-sess-meta!`: ALL have universe-cid dispatch via `meta-universe-cell-id?` predicate
    - **PARAMETERS TO RETIRE in S2.e-i through S2.e-iv** (per §7.5.14.1):
      - 3 meta-store parameters (lines ~2474, 2609, 2740)
      - 3 champ-box parameters (lines ~1402-1404)
      - 3 factory callbacks (lines ~1647, 1651, 1652)
      - 1 mult write callback (line ~1648)
      - 4 champ-fallback functions (lines ~2224, 2231, 2243, 2254)
      - meta-domain-info `'champ-fallback` + `'legacy-fn` entries become dead pointers post-S2.e-iv

25. [`racket/prologos/meta-universe.rkt`](../../../racket/prologos/meta-universe.rkt) — universe-cell parameters + helpers. **`init-meta-universes!` at line 175** is the function S2.e-i calls lazily. Already imported by metavar-store.rkt.

26. [`racket/prologos/propagator.rkt`](../../../racket/prologos/propagator.rkt) — S2.precursor++ extension at line 3260+ (compound-cell CBC contract via component-paths)

27. [`racket/prologos/elaborator-network.rkt`](../../../racket/prologos/elaborator-network.rkt) — `elab-add-type-mult-bridge` at line ~1175 (S2.e-v retirement target per §7.5.14.3)

28. [`racket/prologos/driver.rkt`](../../../racket/prologos/driver.rkt) — mult-bridge callback at line ~2658 (production path; test surface is `elab-add-type-mult-bridge`)

### §2.6 Session-Specific — Probe + Acceptance + Bench

29. [`racket/prologos/examples/2026-04-22-1A-iii-probe.prologos`](../../../racket/prologos/examples/2026-04-22-1A-iii-probe.prologos) — probe (28 expressions). Post-S2.d state: cell_allocs=1181 (-2 from S2.c-iv 1183 = level win), other counters identical.

30. [`racket/prologos/examples/2026-04-17-ppn-track4c.prologos`](../../../racket/prologos/examples/2026-04-17-ppn-track4c.prologos) — PPN 4C acceptance file.

31. [`racket/prologos/data/probes/2026-04-22-1A-iii-baseline.txt`](../../../racket/prologos/data/probes/2026-04-22-1A-iii-baseline.txt) — probe baseline for diff comparison.

32. [`racket/prologos/benchmarks/micro/bench-meta-lifecycle.rkt`](../../../racket/prologos/benchmarks/micro/bench-meta-lifecycle.rkt) — Section A through F. S2.e-vi runs full sequence for final §5 measurement.

### §2.7 Session-Specific — Dailies + Prior Handoffs

33. [`docs/tracking/standups/2026-04-23_dailies.md`](../standups/2026-04-23_dailies.md) — **current dailies**. Contains FULL S2.e session arc:
    - S2.c-v narrative (probe + acceptance + microbench + GO decision)
    - S2.d-level + S2.d-session narratives (atomic per pipeline.md checklist)
    - S2.d-followup narrative (Path B reframe + capture gap completion)
    - S2.e mini-design narrative (Option C-4 + 4 captures + transient finding + 7 sub-phases)

34. [`docs/tracking/handoffs/2026-04-25_PPN_4C_S2c-v_HANDOFF.md`](2026-04-25_PPN_4C_S2c-v_HANDOFF.md) — **prior handoff** (this session's pickup point). 7 meta-lessons + S2.c-v scope + 35-doc hot-load list.

35. [`docs/standups/standup-2026-04-23.org`](../../standups/standup-2026-04-23.org) — user's standup for the working-day interval (write-once / read-only from Claude's side per CLAUDE.local.md).

---

## §3 Key Design Decisions (RATIONALE — do NOT re-litigate)

### §3.1 S2.c-v close — Move B+ benefit verified surviving S2.c-iv

**Decided at commit `03d08184`**:
- Probe diff = 0 semantic + acceptance file 0 errors
- Section F microbench: Path 1 went 625 → 372 ns at W1 (~84% of predicted 302 ns Move B+ benefit retained); ~250 ns/call drop across all workloads
- 3 of 6 §5 criteria MET: fresh-meta 2.13 μs, solve-meta! 7.67 μs (regression UNWOUND, -10% PAST baseline), meta-solution 0.383 μs
- 2 transitional (cells, cell_allocs — S2.e-deferred per §12.4.5)
- Suite within variance (124.2s in 118-127s band)
- **STRONG GO for S2.d**

### §3.2 S2.d — All 4 meta domains universe-active

**Decided across S2.d-level (`badf5fa9`) + S2.d-session (`440e6139`)**:
- Pipeline.md "Per-Domain Universe Migration" checklist applied prophylactically to both domains
- Atomic 3-edit pattern per domain (fresh-X-meta + solve-X-meta! + 'universe-active? flip)
- NO cross-domain bridges for level/session (self-contained)
- NO γ retirement applicable
- S2.d-level probe: cell_allocs 1183 → 1181 (-2 level win)
- S2.d-session probe: 1181 (no change — sessions not exercised in probe)
- All 4 domains universe-active: 'type ✓ + 'mult ✓ + 'level ✓ + 'session ✓ — meta-domain-info dispatch fully unified
- Mini-design + audit + impl + verify took ~20 min per domain (vs S2.c-iv's ~50 min with hang detour)

### §3.3 S2.d-followup — Path B (honesty reframe) + capture gap completion

**Decided at commit `34972bac`** (per user pushback on "preserved for backward-compat" framing):

- **Path B**: cell-id field under universe-active path = **#f** (was misleadingly universe-cid)
  - `expr-meta.cell-id` (S2.b-iii path) — was `type-universe-cid`, now `#f`
  - `sess-meta.cell-id` (S2.d-session path) — was `sess-universe-cid`, now `#f`
  - Audit revealed NO callers depend on the field's value being non-#f
  - Per Move B+, meta-domain-solution IGNORES explicit-cid under universe-active
  - Honest signaling: "no per-meta cell allocated" rather than misleading "looks meaningful"
  - Field itself awaits Phase 4 retirement per D.3 §7.5.14.2

- **Capture gap completion**: 5 missing items now captured:
  - D.3 §7.5.14.1 expanded from session-only → per-domain (10 off-network parameters across 3 non-type domains)
  - DEFERRED.md PM 12 section: 4 NEW entries (per-domain meta-store, per-domain champ-box, per-domain factory callbacks, mult write callback)

### §3.4 S2.e mini-design + 4 captures (commit `209d5721`)

**Decided across S2.e mini-design dialogue + audit**:

- **Option C-4 (lazy universe init in fresh-X-meta)** ADOPTED over Option A (full retirement + test fixture surgery) and Option B (preserve fallback). Eliminates fallback path STRUCTURALLY without test fixture surgery.

- **7 sub-phase partition**: S2.e-i (Option C-4 lazy init) → S2.e-ii (mult write callback) → S2.e-iii (3 factory callbacks) → S2.e-iv (6 store/champ-box params + 4 fallback fns + meta-domain-info cleanup) → S2.e-v (elab-add-type-mult-bridge test-only) → S2.e-vi (final §5 measurement + honest reframe + 4 codifications) → S2.e-VAG (adversarial close)

- **Per-command transient finding** (§7.5.14.4 NEW): cell_allocs cumulative measurement reveals per-command TRANSIENT elaboration (~30-50 cells per command × 28 commands = ~1100 transient allocations) dominates the metric. Step 2 met its actual charter (persistent meta consolidation); the §5 metric was framed for a different bottleneck. Per-command transient consolidation is Track 4D scope.

- **4 captures** prevent missed-work gap:
  1. D.3 §7.5.14.4 — track-internal capture with per-command breakdown
  2. D.3 §7.5.15 — S2.e mini-design persisted
  3. Track 4D research §5.4 — forward-pointer
  4. DEFERRED.md "Future Track 4D Scope" — cross-track tracking

### §3.5 Cross-cutting concerns (carried — STILL APPLY)

| Parent Track Phase | Addendum Interaction | Notes |
|---|---|---|
| Phase 3 (`:type`/`:term` split) ✅ | Step 2 compound cells coexist | Universe cells don't duplicate/contradict attribute-map |
| **Phase 4 (CHAMP retirement)** ⬜ | Absorbs cache-field retirements | `expr-meta-cell-id` + `sess-meta.cell-id` + `current-lattice-meta-solution-fn` callback |
| Phase 7 (parametric trait resolution) ⬜ | Consumes S2.b-iv bridge factory pattern | dict-cell-id propagators |
| Phase 8 (Option A freeze) ⬜ | Reads `:term` facet via `that-*` | |
| Phase 9 (BSP-LE 1.5 cell-based TMS) ⬜ | Step 2 tagged-cell-value substrate | Step 2 depends on S1 (DONE) |
| Phase 9b (γ hole-fill) ⬜ | Shares hasse-registry | Set-latch + broadcast pattern (S2.b-iv) consumed |
| Phase 10 (union via ATMS) ⬜ | Tagged entries per universe component | compound-tagged-merge supports branch-tagged writes |
| Phase 11 (strata → BSP) ⬜ | Meta universes affect retraction stratum | S(-1) clears per-meta entries |
| Phase 12 (Option C freeze) ⬜ | `expr-cell-ref` struct; reading IS zonking | Universe cell addressing via meta-id component-path |
| **Track 4D (NEW capture)** ⬜ | Per-command transient cell consolidation | §7.5.14.4 + Track 4D research §5.4 + DEFERRED.md |

---

## §4 Surprises and Non-Obvious Findings

### §4.1 Per-command transient cell allocation dominates cell_allocs (architectural insight)

`cell_allocs` counter tracks `net-new-cell` invocations (NOT cell-version-updates from `net-cell-write`). Probe measurement: persistent network has 54 cells; `cell_allocs` cumulative is 1181. Difference: ~1127 transient allocations across 28 commands.

Per-command breakdown (from probe verbose):
- Even simple `def x := 42` allocates ~37 cells (attribute-record, structural decomposition, scratch typing)
- Function defs: ~35-51 cells
- Polymorphic functions: ~51 cells

**Step 2's universe consolidation addressed PERSISTENT meta cells** (the right charter). Per-command transient consolidation is a SEPARATE optimization concern — captured for Track 4D.

### §4.2 §5 hypothesis was framed wrong

Hypothesis "cells ≤ 42, cell_allocs ≤ 1000" assumed per-meta cell consolidation would dominate the metric. Reality: per-meta savings approximately offset by universe + hasse-registry + compound-merge infrastructure cells (+4 net). Per-command transients dominate cell_allocs.

S2.e-vi MUST honestly reframe rather than rationalize "the architecture is right, the metric was framed wrong is good enough." Honest answer: metric was framed for the wrong bottleneck; capture that finding (§7.5.14.4 + Track 4D); Step 2 met its actual charter.

### §4.3 "Preserved for backward-compat" was rationalization (Path B trigger)

User pushback on S2.d-session commit message's "preserved for backward-compat" framing. Audit revealed NO callers actually depend on the cell-id field's value:
- 2 production consumers (zonk-session + zonk-session-default) pass `(sess-meta-cell-id s)` to `sess-meta-solution/cell-id`
- Per Move B+, that function IGNORES explicit-cid under universe-active

Path B reframe: cell-id under universe-active = `#f` (honest "no per-meta cell allocated" signaling). Same applied to expr-meta for parallel honesty.

### §4.4 Capture-gap pattern (2 data points this session — graduation-ready)

Both caught by user pushback when I named future phases without verifying capture:
1. **S2.d-followup audit**: §7.5.14.1 said "session-domain off-network parameter retirements" but mult/level had parallel patterns not captured. Fix: expand §7.5.14.1 to per-domain (10 parameters total) + add 4 DEFERRED.md PM 12 entries.
2. **S2.e mini-design**: I claimed "Phase 4D / 4 / 1E will handle per-command transient consolidation" — none of those phases actually captured the work. Fix: 4 captures (§7.5.14.4 + §7.5.15 + Track 4D §5.4 + DEFERRED.md).

**Codification candidate**: every "future phase will handle X" claim requires capture verification (or explicit capture creation) at the time of the claim. 2 data points; ready for DEVELOPMENT_LESSONS.org graduation.

### §4.5 Pipeline.md "Per-Domain Universe Migration" checklist worked prophylactically (3 data points — graduation-ready)

- S2.c-iv (pre-checklist): 4-min hang detour, ~50 min total
- S2.d-level (post-checklist): clean, ~20 min
- S2.d-session (post-checklist): clean, ~20 min

Codified procedural rules MULTIPLY in value as more sites adopt them. Graduation-ready for DEVELOPMENT_LESSONS.org.

### §4.6 Solve-meta! regression unwound past baseline (positive amortization signal)

S2.b-iv flagged solve-meta! at 11.14 μs (+31% from 8.53 μs baseline) as watching-list concern. S2.c-iv showed 7.67 μs (-10% PAST baseline). Hypothesis: S2.b-iv measured a half-migrated state; atomic mult-domain migration unified dispatch + eliminated mult per-meta cells; dispatch overhead amortizes across more meta-solve calls.

**Codification candidate**: micro-benchmark regressions in PARTIAL-migration states often UNWIND when the architecture completes the cross-cutting migration. 3 data points across S2 arc. Ready for codification post-Step-2.

### §4.7 Hot-load IS protocol (3rd reinforcement this session)

User explicitly enforced at session start: "I expect that our context to reach ~500K tokens through this process." This is the 4th data point across sessions for the codified rule. Pattern: implementer attempts partial summarize-back without full deep-read; user catches; full reading proceeds; substantive understanding deepens.

---

## §5 Open Questions and Deferred Work

### §5.1 S2.e-i execution (immediate next)

**Concrete plan**:

1. Implement Option C-4 lazy init in 4 sites (`fresh-meta`, `fresh-mult-meta`, `fresh-level-meta`, `fresh-sess-meta`)
2. Each site: `(when (and net-box (not (current-X-meta-universe-cell-id))) (set-box! net-box (init-meta-universes! (unbox net-box))))`
3. Verify: probe + targeted tests + full suite
4. Tracker + dailies + commit

**Estimated**: ~30-60 min total. ZERO test fixture surgery. Should land cleanly.

### §5.2 S2.e-ii through S2.e-VAG (after S2.e-i)

Per §7.5.15.2 sub-phase plan:
- S2.e-ii: retire `current-prop-mult-cell-write` (~5 min, single deletion)
- S2.e-iii: retire 3 factory callbacks (~10 min)
- S2.e-iv: retire 6 store/champ-box params + 4 champ-fallback functions + clean meta-domain-info entries (~30-60 min, larger scope)
- S2.e-v: retire `elab-add-type-mult-bridge` test-only (~15 min, includes test rewrite)
- S2.e-vi: final §5 measurement + honest reframing + 4 codifications (~60 min, documentation-heavy)
- S2.e-VAG: adversarial Vision Alignment Gate close (~30 min)

Total Step 2 close: ~3-4 hours of focused work.

### §5.3 S2.e-vi — 4 codifications (Step 2 arc deliverable)

Most important deliverable of S2.e (besides the architecture):

1. **Pipeline.md "Per-Domain Universe Migration" checklist works prophylactically** — 3 data points; graduate to DEVELOPMENT_LESSONS.org
2. **Capture-gap pattern** — 2 data points this session; "every 'future phase will handle X' claim requires capture verification"; graduate
3. **Partial-state regression unwinds when architecture completes** — 3 data points; "trends matter more than single-phase absolutes"; graduate
4. **Backward-compat-as-rationalization audit pattern** — 1 data point; "the workflow.md 'preserved for backward-compat' red-flag IS the test"; codify per-pattern (1 more data point would graduate)

### §5.4 Cross-track absorptions (still relevant)

- **Phase 4** (post-Step-2): retires `expr-meta.cell-id` + `sess-meta.cell-id` cache fields + `current-lattice-meta-solution-fn` callback
- **PM Track 12**: retires the 10 off-network parameters captured in DEFERRED.md (per-domain meta-store, champ-box, factory callbacks, mult write callback)
- **Track 4D**: per-command transient cell consolidation (Stage 1 research; concrete designs await)

### §5.5 Watching-list (post-S2.e-vi codifications)

After this session's 4 codification candidates graduate, watching list should be reset or updated. Active items pre-graduation:

| Pattern | Data points | Promotion gate |
|---|---|---|
| Capture-gap pattern | 2 (this session) | Ready (S2.e-vi) |
| Pipeline.md universe migration prophylactic | 3 (S2.c-iv contrast + S2.d-level + S2.d-session) | Ready (S2.e-vi) |
| Partial-state regression unwinds | 3 (across S2 arc) | Ready (S2.e-vi) |
| Backward-compat-as-rationalization | 1 (this session) | 1 more → ready |

---

## §6 Process Notes

### §6.1 Adversarial VAG / Mantra / Principles discipline (carried)

Codified at commit `9f7c0b82`. **TWO-COLUMN discipline** at every gate. If Column 2 is empty, gate was not adversarial. **If gate passes without challenging at least one inherited pattern, re-run with adversarial framing.** Same applies to Mantra Audit, Principles-First Gate, P/R/M/S lenses.

### §6.2 Microbench claim verification (per-sub-phase obligation when applicable)

Codified at `9f7c0b82`. STEP2_BASELINE.md §6.1 captures the exception. **S2.e doesn't carry microbench-claim-verification obligation** (no load-bearing microbench claim for S2.e sub-phases). S2.e-vi runs full bench-meta-lifecycle for §5 measurement, but that's the §5 hypothesis validation, not microbench claim verification.

### §6.3 Per-Domain Universe Migration checklist (apply prophylactically — proven)

Codified at `d5aba2c6` in `.claude/rules/pipeline.md`. 3 data points proving prophylactic value (S2.c-iv contrast + S2.d-level + S2.d-session). Apply to any future per-domain dispatch migration without exception.

### §6.4 Capture-gap discipline (NEW codification candidate)

When naming a future phase as the home for work ("Phase X will handle Y"), VERIFY the work is actually captured in that phase's design doc. If not captured: either capture it now, or honestly say "not yet captured — opening a TODO." 2 data points this session; ready for codification at S2.e-vi.

### §6.5 Conversational implementation cadence (carried)

Max autonomous stretch: ~1h or 1 sub-phase boundary. This session's natural checkpoints:
- S2.c-v decision (after measurement results landed)
- S2.d-level + S2.d-session (per user's two-commit lean)
- S2.d-followup (after user pushback on "backward-compat" framing → architectural conversation about ideal landing)
- S2.e mini-design (recap + audit + capture gap fixes)

### §6.6 Per-phase completion 5-step checklist (workflow.md)

a. Test coverage (or explicit "no tests: refactor" justification)
b. Commit with descriptive message
c. Tracker update (⬜ → ✅ + commit hash + key result)
d. Dailies append (what was done, why, design choices, lessons/surprises)
e. THEN proceed to next sub-phase

### §6.7 Full suite as regression gate when touching code is RULE (process correction)

User correction this session: "we should always run full suite as a regression gate when touching actual code, and adding tests. So yes. No need to ask. That should be part of the process." Internalized.

### §6.8 mempalace Phase 3 active

Post-commit hook auto-mines docs on commits touching `docs/tracking/**` or `docs/research/**`. Logs at `/var/tmp/mempalace-auto-mine.log`. Phase 3b (code wing) ABANDONED.

### §6.9 Session commits (this S2.c-v + S2.d arc + S2.e mini-design)

| Commit | Focus |
|---|---|
| `03d08184` | S2.c-v close: probe + acceptance + Section F microbench all green; STRONG GO for S2.d |
| `badf5fa9` | S2.d-level: LEVEL universe migration (atomic per pipeline.md checklist) |
| `440e6139` | S2.d-session: SESSION universe migration — All 4 domains universe-active |
| `34972bac` | S2.d-followup: honesty reframe (Path B) + capture-gap completion |
| `209d5721` | S2.e mini-design + 4 captures (Option C-4 lazy init plan + per-command transient finding for Track 4D) |

5 commits this session arc; substantial methodology + architecture both.

---

## §7 What the Continuation Session Should Produce

### §7.1 Immediate (S2.e-i execution)

1. Hot-load EVERY §2 document IN FULL (per the codified hot-load-is-protocol rule — NO TIERING; ~500K tokens; user will enforce)
2. Summarize understanding back to user — especially:
   - All 4 domains universe-active (S2.d complete)
   - S2.d-followup Path B honesty reframe (cell-id under universe-active = #f for both expr-meta and sess-meta)
   - S2.e mini-design Option C-4 lazy init plan (7 sub-phases)
   - Per-command transient finding (Track 4D scope)
   - 4 codification candidates pending S2.e-vi graduation
   - 7 meta-lessons from this arc (top of this handoff)
3. Open S2.e-i: implement Option C-4 lazy init in 4 fresh-X-meta sites (~20-40 LoC)
4. Verify: probe + targeted tests + full suite
5. Per-phase 5-step completion (test, commit, tracker, dailies, proceed)
6. Then S2.e-ii (single-deletion; ~5 min)

### §7.2 Medium-term (S2.e through Step 2 close)

S2.e-ii through S2.e-VAG per §7.5.15.2 sub-phase plan. ~3-4 hours of focused work to close Step 2.

### §7.3 Longer-term

- Phase 1E (`that-*` storage unification) — dedicated design cycle per D.3 §7.6.16
- Phase 1B (tropical fuel primitive) + 1C (canonical instance)
- Phase 2 (orchestration unification)
- Phase 3 (union via ATMS + hypercube)
- Phase V (capstone + PIR)

### §7.4 Post-addendum

- Main-track PPN 4C Phase 4 (CHAMP retirement) — absorbs cache-field retirements
- PM Track 12 (module loading on network) — retires 10 off-network parameters captured in DEFERRED.md
- PPN Track 4D (attribute grammar substrate unification) — per-command transient consolidation per §7.5.14.4

---

## §8 Final Notes

### §8.1 What "I have full context" requires

Per HANDOFF_PROTOCOL.org §8.1:
- Read EVERY document in §2 IN FULL (35 documents — **NO SKIPPING, NO TIERING** per the codified rule)
- Articulate EVERY decision in §3 with rationale (especially Path B reframe + S2.e Option C-4 + per-command transient finding capture)
- Know EVERY surprise in §4 (especially the per-command transient finding + the 2 capture-gap data points + the §5 hypothesis was framed wrong)
- Understand §5.1 (S2.e-i execution) without re-litigating

Good articulation example for S2.e-i opening:

> "S2.e-i implements Option C-4 lazy universe init in 4 fresh-X-meta sites per D.3 §7.5.15.1. The pattern: in fresh-X-meta, when net-box is set but universe-cid is not (pre-init test contexts), lazy-call `init-meta-universes!` to allocate the universe cells. Eliminates the fallback path STRUCTURALLY without test fixture surgery. ~20-40 LoC across the 4 sites. Verify with probe (expect identical to baseline) + targeted tests + full suite. Then per-phase 5-step completion. Next sub-phase S2.e-ii is the trivial mult write callback retirement (~5 min). The architecture work is small; the most important deliverable of S2.e is at S2.e-vi (final §5 measurement + honest reframing per §7.5.14.4 + 4 codifications graduation)."

### §8.2 Git state at handoff

```
branch: main (ahead of origin/main by many commits; don't push unless directed)
HEAD: 209d5721 (S2.e mini-design + 4 captures)
prior session arc:
  34972bac S2.d-followup: honesty reframe + capture-gap completion (Path B)
  440e6139 S2.d-session: All 4 domains universe-active
  badf5fa9 S2.d-level: LEVEL universe migration
  03d08184 S2.c-v close: STRONG GO for S2.d
  bae037d5 (S2.c-v handoff — prior session's tail)
working tree: clean (benchmark/cache artifacts untracked; user's standup additions untouched per workflow rule)
suite: 7920 tests / 116.7s / 0 failures (last verified at 34972bac S2.d-followup close)
```

### §8.3 User-preference patterns (carried + observed this session)

- **Completeness over deferral** — Path B + capture-gap completion happened immediately upon user surfacing the gap; not deferred.
- **Architectural correctness > implementation cost** — Option C-4 chosen over Option B despite Option B being lower-scope (Option C-4 is structurally cleaner).
- **External challenge as highest-signal feedback** — user pushback caught what implementer's VAG missed THREE times this session arc:
  1. "Backward-compat" framing on sess-meta.cell-id (Path B trigger)
  2. "Phase 4D / 4 / 1E will handle X" without verifying capture (S2.e mini-design capture-gap fix)
  3. "Probe cell" terminology imprecision + PU-consolidation framing (per-command transient finding surfaced)
- **Process improvements codified, not memorized** — capture-gap discipline is now a codification candidate; ready to graduate at S2.e-vi.
- **Conversational mini-design** — design + audit outcomes persist to D.3 (now 5 §7.5.X subsections this arc); pattern continued.
- **Per-commit dailies discipline** — followed throughout this session.
- **Hot-load discipline strict** — user explicitly enforced at session start with "~500K tokens through this process". 4th data point across sessions; codified rule reinforced.
- **Audit-first methodology** — heavy use this session: S2.d-followup audit revealed Path B necessity + 5 capture gaps; S2.e mini-design audit revealed transient finding + 4 captures.
- **Context-window awareness delegated to user** — user monitors and signals handoff timing. This handoff opened at user direction.
- **Decisive when data is clear** — Option C-4 decision took ~3 messages of dialogue (A vs B vs C surfaced; user requested C elaboration; decision made). Path B reframe took ~2 messages (audit confirmed; immediate adoption).
- **Full suite as rule, not option** — explicit process correction this session; no asking for permission.

### §8.4 Session arc summary

Started with: pickup from `2026-04-25_PPN_4C_S2c-v_HANDOFF.md` (S2.c-v pending — measurement + GO/no-go decision).

Delivered:
- **S2.c-v close** (commit `03d08184`) — probe + acceptance + Section F microbench verified Move B+ ~80% gain SURVIVED S2.c-iv; 3/6 §5 criteria MET; STRONG GO for S2.d
- **S2.d-level** (commit `badf5fa9`) — LEVEL universe migration; pipeline.md checklist applied prophylactically; clean ~20-min landing
- **S2.d-session** (commit `440e6139`) — SESSION universe migration; All 4 domains universe-active; meta-domain-info dispatch fully unified
- **S2.d-followup** (commit `34972bac`) — Path B honesty reframe (cell-id under universe-active = #f) + 5 capture gaps fixed (D.3 §7.5.14.1 expansion + 4 DEFERRED.md PM 12 entries)
- **S2.e mini-design + 4 captures** (commit `209d5721`) — Option C-4 lazy init plan (7 sub-phases) + per-command transient finding (Track 4D scope) captured in 4 places

Key architectural insights captured:
- **Per-command transient cell allocation dominates `cell_allocs`** (not persistent meta cells per §5 hypothesis framing)
- **§5 hypothesis was framed for the wrong bottleneck** — Step 2 met its actual charter; per-command transient consolidation is Track 4D scope
- **Path B**: cell-id under universe-active = #f (honest signaling rather than misleading universe-cid)
- **Capture-gap pattern**: 2 data points; codification-ready

Suite state through arc: 124.2s (S2.c-iv close) → 124.2s (S2.c-v) → ~125s (S2.d-level) → 124.2s? (S2.d-session) → 117.1s (S2.d-followup) — within 118-127s variance band; trending toward lower end.

**5 commits this session arc; ~250+ LoC net production + design doc + tests + 4 captures across 4 documents. The methodology improvements (capture-gap discipline + adversarial VAG operating + Path B honesty reframe pattern) are the most important deliverables of this arc — they prevent the next arc from repeating today's drifts.**

**The context is in safe hands.** S2.e-i is well-scoped (Option C-4 lazy init in 4 sites; ~20-40 LoC). S2.e-ii through S2.e-vi proceed per the documented sub-phase plan. S2.e-VAG closes Step 2. Phase 1E and beyond per the longer-term roadmap. Next session opens with the standard hot-load protocol (FULL list, NO TIERING) → mini-design audit → S2.e-i execution.
