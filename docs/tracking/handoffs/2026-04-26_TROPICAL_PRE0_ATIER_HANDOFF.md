# PPN 4C Tropical Quantale Addendum — Pre-0 A/E/R Tier Continuation Handoff

**Date**: 2026-04-26 (M-tier Pre-0 complete + 5 design-affecting findings captured + hybrid pivot provisionally identified)
**Purpose**: Transfer context into a continuation session to pick up **Pre-0 plan execution from A-tier through R-tier** + then **D.2 revise consolidating all Pre-0 findings (including hybrid pivot decision)**.

**Before reading anything else**: read [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org). The Hot-Load Reading Protocol requires reading EVERY §2 document IN FULL before summarizing understanding back to the user. Hot-load is a PROTOCOL, not a prioritization — codified at [`DEVELOPMENT_LESSONS.org`](../principles/DEVELOPMENT_LESSONS.org) § "Hot-Load Is a Protocol, Not a Prioritization" (now at 6+ data points across sessions; user explicitly enforces).

**CRITICAL meta-lessons from this session arc** — read these BEFORE anything else:

1. **Hybrid design pivot identified from M-tier Finding 2** (provisional pending A/E/R-tier confirmation): inline `(<= fuel 0)` check is 6 ns/call; threshold propagator fire is realistically 100-600 ns (worklist + dispatcher + fire-fn). The DR threshold (12 ns total = 100% of inline check) is missed by 10-50x. **Provisional D.2 design response**: keep inline check fast-path at decrement sites; threshold propagator only writes contradiction on actual exhaustion (rare event). User direction (2026-04-26): "the hybrid pivot is reasonable even with what we do have; but we want to get all the measurements before committing to a final decision." A/E/R-tier execution validates this before D.2 revision commits.

2. **Pre-0 hypothesis correction from M-tier Finding 1**: predicted 200-300 bytes/decrement for counter struct-copy; actual is **62.5 bytes/dec** (4x more efficient than predicted). Cell-write needs to stay under ~125 bytes/dec to satisfy DR (1.25-2x baseline). TIGHTER constraint than design originally assumed; tagged-cell-value entry layout under universe-active worldview needs careful design at Phase 1B.

3. **Pre-existing bench file fix unblocked Pre-0 execution** (commit `82eaf737`): bench-ppn-track4c.rkt had broken parens at lines 223-230 + missing silent wrappers around process-string-ws calls (verbose JSON heartbeats drowned out bench output). Fix-now decision per workflow rule "Pre-existing issue is a process smell" was correct (workaround cost was infinite — whole Pre-0 plan blocked). Codification candidate: when starting Pre-0 execution, audit bench file integrity FIRST.

4. **5 Pre-0 findings from M-tier** (full detail at Pre-0 plan §12.6):
   - Finding 1: M7.mem 62.5 bytes/dec (vs 200-300 predicted; 4x more efficient)
   - Finding 2: M8 inline-check 6 ns sets TIGHT bar; hybrid pivot proposed
   - Finding 3: M9 per-cell amortization works (16 μs N=1 → 0.5 μs/cell N=500)
   - Finding 4: M11 tropical tensor essentially free (1 ns/call, 0 alloc)
   - Finding 5: Counter substrate is REMARKABLY cheap (~36 ns combined per cycle); cell-based ~2-3x slower in absolute terms

5. **Memory as first-class measurement validated**: dual-axis (wall + memory) on every M-tier test caught Finding 1 (would have been missed if only tracking wall-clock). Per user mid-design direction. R-tier (memory as PRIMARY signal) execution will produce more memory-specific data.

6. **M-tier sub-phase boundary respected**: ~75-90 min for M-tier execution including the pre-existing bench file fix detour. Per conversational cadence rule (max 1h or 1 sub-phase boundary), this is the right checkpoint moment. 7+ sub-phases remaining (A/E/R + D.2 revise + critique rounds + Stage 4 implementation per per-phase mini-design+audit).

7. **Session arc deliverables** (this session):
   - D.1 design draft (1179 lines, commit `fc4b9d3e`)
   - Working day interval opened (standup-2026-04-26.org + 2026-04-26_dailies.md, commit `c9a5825a`)
   - Pre-0 plan comprehensive (1172 lines / 38 tests / 8 tiers, commit `f79650fa`)
   - Pre-0 plan dailies entry (commit `6f05efc9`)
   - bench file pre-existing fix (commit `82eaf737`)
   - M-tier baselines + first run (commit `f6576479`)
   - Pre-0 plan §12.5 + §12.6 + dailies (commit `bef1f518`)

8. **Phase-specific open questions remain placed at right phases per user's workflow** (γ-bundle-wide for Phase 1; refine + verify D.3 scaffolding; multi-quantale composition NTT in scope; A+B+cross-reference capture for Phase 3C; strict sequencing per pipeline.md template).

---

## §1 Current Work State (PRECISE)

- **Track**: PPN Track 4C Phase 9+10+11 Addendum — substrate + orchestration unification (per D.3)
- **Sub-track**: Tropical Quantale Addendum — Phase 1A-iii-b + 1A-iii-c + 1B + 1C + 1V (γ-bundle-wide per Q-A3)
- **Stage**: Stage 3 Design — Pre-0 phase IN PROGRESS
- **Pre-0 phase status**: M-tier ✅ COMPLETE; A/E/R-tier ⬜ PENDING; D.2 revise ⬜ PENDING
- **Last commit**: `bef1f518` (Pre-0 plan §12.5 M-tier baselines + 5 design-affecting findings + dailies)
- **Branch**: `main` (ahead of origin/main by many commits; don't push unless directed)
- **Working tree**: clean except unrelated artifacts (standup edits, benchmark data, deleted .md files that have .org versions, .prologos file edits — all pre-existing user-managed changes)
- **Suite state**: 7914 tests / 119.3s / 0 failures (per S2.e-v close `118ab57a` — within 118-127s baseline variance band; not re-run this session as M-tier work doesn't touch production)

### Session arc commits (2026-04-26 in chronological order)

| Commit | Focus |
|---|---|
| `fc4b9d3e` | PPN 4C tropical addendum: Stage 3 D.1 draft (γ-bundle-wide) — 1179 lines |
| `c9a5825a` | docs: 2026-04-23 dailies D.1 entry + open 2026-04-26 working day interval |
| `f79650fa` | PPN 4C tropical addendum: Pre-0 microbench comprehensive plan — 1172 lines / 38 tests / 8 tiers |
| `6f05efc9` | docs: 2026-04-26 dailies — Pre-0 microbench comprehensive plan entry |
| `82eaf737` | bench: fix bench-ppn-track4c.rkt parens + missing silent wrappers (pre-existing fix; unblocks Pre-0 execution) |
| `f6576479` | bench: M-tier (M7-M13) Pre-0 tropical fuel substrate baselines + first run |
| `bef1f518` | docs: Pre-0 plan §12.5 M-tier baselines + 5 design-affecting findings + dailies |

### Pre-0 progress tracker snapshot

| Sub-phase | Status | Notes |
|---|---|---|
| Stage 3 D.1 design draft | ✅ `fc4b9d3e` | 1179 lines / 18 sections; γ-bundle-wide; multi-quantale NTT; Phase 3C cross-reference capture |
| Pre-0 plan (design phase) | ✅ `f79650fa` | 1172 lines / 38 tests / 8 tiers; memory as first-class |
| Pre-0 M-tier execution (M7-M13) | ✅ `f6576479` + `bef1f518` | 7 tests + dual-axis bench-mem; 5 design-affecting findings |
| **Pre-0 A-tier execution (A5-A12)** | ⬜ **NEXT** | Adversarial scenarios; ~150-250 LoC + ~15 min execution |
| Pre-0 E-tier execution (E7-E9) | ⬜ | E2E programs; ~50-100 LoC |
| Pre-0 R-tier execution (R1-R5) | ⬜ | Memory-as-primary-signal; ~100-150 LoC |
| Pre-0 S-tier execution (S1-S4) | ⬜ | Suite-level; uses existing infrastructure |
| D.2 revise with Pre-0 findings | ⬜ | Consolidate all findings; commit hybrid pivot decision |
| D.3+ critique rounds | ⬜ | P/R/M/S; especially S for algebra |
| Stage 4 implementation | ⬜ | Per per-phase mini-design+audit |

### Next immediate task — A-tier execution per Pre-0 plan §4

**Goal**: extend `bench-ppn-track4c.rkt` with A5-A12 adversarial scenarios + run pre-implementation baselines.

**A-tier tests** (per plan §4):
- **A5** cost-bounded vs flat fuel exhaustion (semantic axis — counter is cost-blind)
- **A6** deep dependency chain N=10/50/200 (Phase 3C UC1 forward-capture)
- **A7** high-frequency decrement N=1000/10000/100000 (memory pressure)
- **A8** multi-consumer concurrent 10×1000 (per-consumer scaling under sequential composition)
- **A9** speculation rollback cost 100 cycles (write-tagged-then-rollback)
- **A10** branch fork explosion 5-way (Phase 3A forward-capture)
- **A11** pathological cost patterns (single huge / many tiny / alternating / monotonically-increasing)
- **A12** N/A pre-impl (residuation boundaries — post-Phase-1B)

Each test gets:
- Pre-impl baseline (counter-side) measurement
- Hypothesis comment block
- Decision rule comment block
- Use bench-mem macro for dual-axis measurement (wall + memory)

**Estimated**: ~150-250 LoC additions + ~15 min execution.

**After A-tier**: continue with E-tier (E7-E9) and R-tier (R1-R5) per same protocol.

**After all Pre-0 tiers complete**: D.2 revise consolidating all findings (especially hybrid pivot decision per Finding 2 + any A/E/R additions). D.2 then feeds D.3+ critique rounds → Stage 4 implementation per per-phase mini-design+audit.

---

## §2 Documents to Hot-Load (ORDERED — NO TIERING)

**CRITICAL**: per the codified hot-load-is-protocol rule, read EVERY document IN FULL. NO tiering. ~500K-700K token budget anticipated. User will explicitly enforce.

### §2.0 Start here

0. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org)

### §2.1 Always-Load

1. [`CLAUDE.md`](../../../CLAUDE.md) + [`CLAUDE.local.md`](../../../CLAUDE.local.md)
2. [`MEMORY.md`](../../../MEMORY.md) — auto-memory
3. [`DESIGN_METHODOLOGY.org`](../principles/DESIGN_METHODOLOGY.org) — Stage 3 critical (Pre-0 mandate; "Memory cost is a separate axis from wall-clock")
4. [`DESIGN_PRINCIPLES.org`](../principles/DESIGN_PRINCIPLES.org) — Hyperlattice Conjecture; Correct-by-Construction
5. [`CRITIQUE_METHODOLOGY.org`](../principles/CRITIQUE_METHODOLOGY.org) — S lens load-bearing for quantale algebra; adversarial framing
6. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org) (self-reference)
7. [`docs/tracking/MASTER_ROADMAP.org`](../MASTER_ROADMAP.org) — OE Series first production landing
8. [`docs/tracking/2026-03-26_PPN_MASTER.md`](../2026-03-26_PPN_MASTER.md) — parent series
9. [`DEVELOPMENT_LESSONS.org`](../principles/DEVELOPMENT_LESSONS.org) — 6 codifications graduated 2026-04-25 + watching-list candidates from this session arc

### §2.2 Architectural Rules (loaded via `.claude/rules/`)

10. [`.claude/rules/on-network.md`](../../../.claude/rules/on-network.md)
11. [`.claude/rules/structural-thinking.md`](../../../.claude/rules/structural-thinking.md) — SRE lattice lens for quantale design decisions
12. [`.claude/rules/propagator-design.md`](../../../.claude/rules/propagator-design.md)
13. [`.claude/rules/workflow.md`](../../../.claude/rules/workflow.md) — adversarial VAG + microbench-claim verification + capture-gap discipline
14. [`.claude/rules/testing.md`](../../../.claude/rules/testing.md) — full suite as regression gate; targeted test discipline
15. [`.claude/rules/pipeline.md`](../../../.claude/rules/pipeline.md) — § "Per-Domain Universe Migration" template (3 prophylactic data points)
16. [`.claude/rules/stratification.md`](../../../.claude/rules/stratification.md) — strata as module composition; relevant for Phase 3C residuation
17. [`.claude/rules/mempalace.md`](../../../.claude/rules/mempalace.md) — Phase 2 success criteria evaluation question (3.3.3 stability watch)
18. [`.claude/rules/prologos-syntax.md`](../../../.claude/rules/prologos-syntax.md)

### §2.3 THE active design + plan documents (THIS SESSION) — READ IN FULL

19. **[`docs/tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md`](../2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md)** (D.1, NEW THIS SESSION at `fc4b9d3e`) — 1179 lines / 18 sections / 50+ subsections. Key sections:
    - **§1.2 γ-bundle-wide scope** — 1A-iii-b + 1A-iii-c + 1B + 1C + 1V all in addendum
    - **§4.2 Multi-quantale composition NTT model** — TypeFacetQ + TropicalFuelQ co-existence
    - **§6.5 Phase 3C cross-reference capture** — A+B+cross-reference per Q-Open-2
    - **§7-§11** Phase-by-phase deliverables (1A-iii-b, 1A-iii-c, 1B, 1C, 1V) with audit-grounded scope
    - **§9.7 Phase 3C anticipated use cases** (UC1 fuel-exhaustion blame; UC2 cost-bounded elaboration; UC3 per-branch cost tracking)
    - **§13 Pre-0 benchmark plan sketch** (expanded comprehensively in Pre-0 plan)
    - **§14.4 S lens explicit SRE lattice lens analysis** (Q1-Q6 for tropical fuel quantale)
    - **§16.5 cross-cutting open questions ALL RESOLVED at D.1 close**

20. **[`docs/tracking/2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md`](../2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md)** (NEW THIS SESSION at `f79650fa`) — 1172 lines / 15 sections. Key sections:
    - **§1.2 Performance characterization framework** — wall + memory + semantic correctness
    - **§1.3 Why memory is first-class for THIS addendum** — 4 distinct measurement points
    - **§2 Tier structure** — 38 tests across 8 tiers (M/A/C/X/E/R/S/V)
    - **§3 Tier M (M7-M13)** — fully specified with hypothesis + decision rule per test
    - **§4 Tier A (A5-A12)** — fully specified — **NEXT TO EXECUTE**
    - **§7 Tier E (E7-E9)** — fully specified
    - **§8 Tier R (R1-R5)** — memory-as-PRIMARY-signal scenarios
    - **§13 Decision rules summary table** (38 rows) — each test has clear failure→design-response mapping
    - **§12.5 Pre-0 baseline data** — M-tier populated; A/E/R/V pending
    - **§12.6 Key Pre-0 findings from M-tier execution (5 findings)** — including Finding 2 hybrid pivot

21. [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — D.3 parent addendum — refer for §7.5.6 (1A-iii-b), §7.5.7 (1A-iii-c), §7.7 (Phase 1B), §7.8 (Phase 1C), §10 (tropical implementation skeleton), §13 (termination), §16.1 (Phase 1 mini-design items). D.1 refines + extends these.

22. [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md) — PPN 4C parent design

### §2.4 Stage 1 Research (foundational; READ IN FULL)

23. **[`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md)** — THE Stage 1 doc, ~1000 lines, 12 sections. Required for understanding quantale algebra + residuation + Lawvere quantale + Module Theory + Module Theory.
24. [`docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`](../../research/2026-03-28_MODULE_THEORY_LATTICES.md) — Q-modules + residuation
25. [`docs/research/2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md`](../../research/2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) — earlier framing
26. [`docs/research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md`](../../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) — universal engine vision
27. [`docs/research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md`](../../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) — SRE foundations
28. [`docs/research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md`](../../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md) — Track 4D vision (forward-capture)

### §2.5 Baseline data + reference

29. [`racket/prologos/data/benchmarks/tropical-pre0-baseline-2026-04-26.txt`](../../../racket/prologos/data/benchmarks/tropical-pre0-baseline-2026-04-26.txt) — **M-tier baseline data file** (5.2 KB; persistent reference for A/E/R-tier comparison + post-impl A/B)
30. [`docs/tracking/2026-04-23_STEP2_BASELINE.md`](../2026-04-23_STEP2_BASELINE.md) — §6 measurement discipline (bounce-back not gate); §6.1 microbench-claim verification rule
31. [`docs/tracking/DEFERRED.md`](../DEFERRED.md) — PM Track 12 entries; Future Track 4D Scope (per-command transient consolidation)

### §2.6 Code files (current state at this handoff)

32. [`racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt`](../../../racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt) — **active bench file**; M1-M3 + M7-M13 + A1-A2 + E1-E4 + V1-V3 sections; A5-A12 + E7-E9 + R1-R5 to be added
33. [`racket/prologos/propagator.rkt`](../../../racket/prologos/propagator.rkt) — `make-prop-network` line 81; `prop-net-hot` struct (fuel field, line ~336); `prop-network-fuel` macro line 399; 17 production decrement/check refs
34. [`racket/prologos/atms.rkt`](../../../racket/prologos/atms.rkt) — 13 deprecated functions lines 213-251+; struct + atms-believed line 159+; 1A-iii-b retirement target
35. [`racket/prologos/syntax.rkt`](../../../racket/prologos/syntax.rkt) — 14 surface ATMS AST structs lines 202-208 + 750-767; 1A-iii-c retirement target

### §2.7 Dailies + standup

36. [`docs/tracking/standups/2026-04-26_dailies.md`](../standups/2026-04-26_dailies.md) — current dailies; full session arc narrative (hot-load + Stage 3 design + D.1 + Pre-0 plan + M-tier execution + 5 findings + checkpoint discussion)
37. [`docs/tracking/standups/2026-04-23_dailies.md`](../standups/2026-04-23_dailies.md) — prior dailies (closed; included continuation entry through 2026-04-26 D.1 draft)
38. [`docs/standups/standup-2026-04-26.org`](../../standups/standup-2026-04-26.org) — current working-day standup (write-once / read-only from Claude's side per CLAUDE.local.md)

### §2.8 Prior handoffs

39. [`docs/tracking/handoffs/2026-04-26_PPN_4C_TROPICAL_ADDENDUM_HANDOFF.md`](2026-04-26_PPN_4C_TROPICAL_ADDENDUM_HANDOFF.md) — earlier handoff this session (covers session opening through tropical addendum scoping; recovery context for if you want to understand the Stage 3 entry-point dialogue)
40. [`docs/tracking/handoffs/2026-04-25_PPN_4C_S2e-v_HANDOFF.md`](2026-04-25_PPN_4C_S2e-v_HANDOFF.md) — Step 2 close handoff

---

## §3 Key Design Decisions (RATIONALE — do NOT re-litigate)

### §3.1 γ-bundle-wide for Phase 1 scope (per Q-Open-1 + Q-A3 user direction)

Tropical addendum covers ALL of Phase 1: 1A-iii-b (Tier 2 deprecated atms internal API retirement) + 1A-iii-c (Tier 3 surface ATMS AST 14-file pipeline retirement) + 1B (tropical fuel primitive) + 1C (canonical BSP fuel migration) + 1V (Vision Alignment Gate closes Phase 1 entirely). 1A-iii-b/c retirement is naturally adjacent to substrate work — deprecating OLD substrate (atms struct + surface AST) alongside shipping NEW one (tropical primitive); 1V atomic close aligns with capture-gap discipline maximally.

### §3.2 D.3 scaffolding treated as draft D.0 (Q-Open-1)

D.1 refines + verifies + extends D.3 §7.5.6 + §7.5.7 + §7.7-§7.11 + §10 + §13 + §16.1. Don't re-derive; don't accept uncritically. Each preexisting decision gets adversarial challenge + audit grounding.

### §3.3 Multi-quantale composition NTT in scope (Q-Open-3 (β))

D.1 §4.2 covers TypeFacetQ + TropicalFuelQ co-existence as independent Q-modules; quantale-of-bridges composition pattern (research §5.4); quantaloids out of scope for future PReduce / cost-currency tracking.

### §3.4 Phase 3C cross-reference capture per Q-Open-2 (A+B+C-deferred)

User direction was STRONGER than my original three-form proposal. Form A = Phase 1B unit tests for residuation operator; Form B = D.1 §9.7 enumerates UC1/UC2/UC3 anticipated Phase 3C use cases; Form C = cross-reference to Phase 9 Addendum Phase 3 design (capture lives at right phase per capture-gap discipline). The pattern's structural fingerprint: capture lives at the right phase, not in current scope.

### §3.5 Strict sequencing per pipeline.md "Per-Domain Universe Migration" template (Q-Open-4)

1B substrate ships before 1C consumer migration; clean atomic per-domain pattern (3 prophylactic data points S2.d-level + S2.d-session prove the discipline).

### §3.6 Memory as first-class measurement axis (per user direction 2026-04-26)

Per DESIGN_METHODOLOGY mandate ("Memory cost is a separate axis from wall-clock... different axes catch different problems"). Every M/A/E/R test gets dual-axis (wall + memory) via existing `bench-mem` macro. R-series dedicated to memory-as-PRIMARY-signal scenarios. Validated by Finding 1 (M7.mem hypothesis correction would have been missed if only tracking wall-clock).

### §3.7 Hybrid pivot from Finding 2 (PROVISIONAL — pending A/E/R-tier confirmation)

Per user direction (2026-04-26): "the hybrid pivot is reasonable even with what we do have; but we want to get all the measurements before committing to a final decision."

**Provisional design** (would update D.1 §10 Phase 1C migration patterns):
- **Inline `(<= cost budget)` fast-path** at decrement sites (preserve current 6 ns cost)
- **Threshold propagator** writes contradiction ONLY on actual exhaustion (rare event, not per-write)
- Net: per-decrement cycle stays at ~30-40 ns total instead of jumping to 100-600 ns

This reframes Phase 1C from "replace inline check with threshold propagator" to "preserve inline check + add threshold propagator for contradiction-write semantic on exhaustion."

**A/E/R-tier execution validates this** before D.2 revision commits. Particularly:
- A7 (high-frequency decrement) tests memory pressure under sustained inline-check workload
- A9 (speculation rollback) tests cost of tagged-cell-value layer under repeated rollback cycles
- R3 (GC pressure) confirms inline-check approach doesn't introduce GC issues

### §3.8 Cross-cutting concerns (carried — STILL APPLY)

| Parent Track Phase | Addendum interaction | Notes |
|---|---|---|
| Step 2 ✅ CLOSED | Tropical fuel cells co-exist with type meta universe cells | No interference; different quantales |
| **Phase 1A-iii-b/c + 1B + 1C + 1V (this addendum)** | Pre-0 plan ready; M-tier executed; A/E/R pending | Per γ-bundle-wide; 1V closes Phase 1 entirely |
| Phase 1E | AFTER addendum implementation lands | 5 carry-forward Q1-Q5 per D.3 §7.6.16 |
| Phase 2 (orchestration) | Independent | Likely after Phase 1E |
| Phase 3A/B/C | Phase 3C consumes tropical residuation operator | Forward-captured per D.1 §6.5 + §9.7 |
| Phase 4 (CHAMP retirement, parent track) | Coordinates with PM Track 12 | Orthogonal mostly |
| Track 4D | Per-command transient consolidation | Forward-captured in DEFERRED.md from Step 2 |
| **Future PReduce series** | Inherits tropical quantale primitive | First production landing establishes pattern |
| **OE Series** | This addendum is OE Track 0/1/2's first production landing | Per MASTER_ROADMAP.org § OE; formalization decision deferred |

---

## §4 Surprises and Non-Obvious Findings

### §4.1 Five M-tier Pre-0 findings (per Pre-0 plan §12.6)

**Finding 1 — M7.mem hypothesis correction**: predicted 200-300 bytes/decrement; actual is **62.5 bytes/dec** (4x more efficient than predicted). Per-decrement struct-copy of prop-net-hot is just a small struct (worklist + fuel = 2 fields). Cell-write needs to stay under ~125 bytes/dec to satisfy DR (1.25-2x baseline). TIGHTER than originally thought.

**Finding 2 — M8 inline-check 6 ns sets a TIGHT bar**: DR triggers if no-trigger threshold propagator overhead > 100% of inline check (12 ns total). A propagator fire (worklist entry + dispatcher + fire-fn) is realistically 100-600 ns — almost certainly fails the DR by 10-50x. **Hybrid design pivot proposed** (per §3.7 above; provisional pending A/E/R confirmation).

**Finding 3 — M9 per-cell amortization works**: 16 μs at N=1 → 0.5 μs/cell at N=500. Per-consumer fuel cell allocation feasible at typical N (1-50 per net). 1.25 KB/cell at scale is acceptable.

**Finding 4 — M11 tropical tensor essentially free**: 1 ns/call with 0 allocation. `+inf.0` propagation works at fixnum cost. Q-1B-2 representation choice (`+inf.0` vs sentinel) can be made on ARCHITECTURAL grounds, not perf.

**Finding 5 — Counter substrate is REMARKABLY cheap**: combined M7+M8+M13 = ~36 ns total per decrement+check+read cycle. Cell-based path will be slower (~60-100 ns + threshold propagator overhead). The architectural-correctness trade-off costs ~2-3x in absolute decrement cycle time — acceptable IF Finding 2 hybrid preserves per-decrement cost.

### §4.2 Pre-existing bench file fix unblocked Pre-0 execution

`bench-ppn-track4c.rkt` had broken parens at lines 223-230 + missing silent wrappers around process-string-ws calls (verbose JSON heartbeats drowned out bench output). Workaround cost was infinite (whole Pre-0 plan blocked); fix-now decision per workflow rule "Pre-existing issue is a process smell" was correct. Codification candidate: when starting Pre-0 execution, audit bench file integrity FIRST (cheap; catches infrastructure rot).

### §4.3 Memory-as-first-class validated

Dual-axis (wall + memory) measurement on every M-tier test caught Finding 1 (which would have been missed if only tracking wall-clock). The user's mid-design direction "consider memory not just speed" was vindicated.

### §4.4 Pre-0 IS catching design assumptions before they harden

Per DESIGN_METHODOLOGY: "Pre-0 reshapes design in 10/10 instances." This session adds an 11th instance — Finding 1 (memory hypothesis correction) and Finding 2 (hybrid pivot proposal) both reshape design BEFORE Phase 1B/1C implementation begins. The methodology is working as mandated.

### §4.5 Conversational cadence respected at sub-phase boundary

M-tier sub-phase took ~75-90 min (including the pre-existing bench file fix detour). At the upper bound of the 1h conversational cadence rule, but a clean sub-phase boundary. Handoff at this point preserves quality for A/E/R-tier execution in fresh context.

### §4.6 5 design-affecting findings is more than typical

Pre-0 phases typically surface 1-3 design-affecting findings. M-tier alone produced 5. This reinforces the "first instantiation deserves full Stage 3 dues" framing — comprehensive Pre-0 is paying off in design-affecting data.

### §4.7 Remaining hot-load is doable but demands discipline

This handoff itself documents a substantial body of work. Next session must hot-load EVERY §2 document IN FULL before summarizing back. Hot-load-is-protocol enforced; user will reinforce if shortcuts are taken (6+ data points across sessions).

---

## §5 Open Questions and Deferred Work

### §5.1 Pre-0 A-tier execution (immediate next)

Per Pre-0 plan §4. ~150-250 LoC additions + ~15 min execution.

8 tests:
- A5 cost-bounded vs flat fuel exhaustion (semantic axis)
- A6 deep dependency chain N=10/50/200 (Phase 3C UC1 forward-capture)
- A7 high-frequency decrement N=1000/10000/100000 (memory pressure)
- A8 multi-consumer concurrent 10×1000
- A9 speculation rollback cost 100 cycles
- A10 branch fork explosion 5-way (Phase 3A forward-capture)
- A11 pathological cost patterns (4 sub-tests)
- A12 N/A pre-impl (residuation boundaries — post-Phase-1B)

Per per-phase 5-step completion: tests not directly applicable (bench code is data-collection); commit + tracker update + dailies + proceed.

### §5.2 Pre-0 E-tier execution (after A-tier)

Per Pre-0 plan §7. ~50-100 LoC additions.

3 tests:
- E7 realistic elaboration with fuel tracking
- E8 deep type-inference workload
- E9 cost-bounded elaboration scenario (Phase 3C UC2 forward-capture)

### §5.3 Pre-0 R-tier execution (after E-tier)

Per Pre-0 plan §8. ~100-150 LoC additions.

5 tests (memory-as-PRIMARY-signal):
- R1 per-decrement allocation rate
- R2 retention after quiescence
- R3 GC pressure profile under load
- R4 compound vs flat cell value layout
- R5 long-running fuel cell retention under speculation

### §5.4 Pre-0 S-tier execution

Per Pre-0 plan §9. Uses existing infrastructure (`tools/run-affected-tests.rkt` + `tools/benchmark-tests.rkt` + `data/benchmarks/timings.jsonl`). No bench code additions; configuration + comparison.

4 tests:
- S1 full suite wall time
- S2 per-file timing distribution
- S3 heartbeat counter deltas
- S4 probe verbose deltas

### §5.5 D.2 revise consolidating all Pre-0 findings (after all Pre-0 tiers)

D.2 incorporates:
- All 5 M-tier findings (already documented in Pre-0 plan §12.6)
- A-tier findings (especially A7 memory + A9 speculation rollback validation of hybrid pivot)
- E-tier findings (E7 confirms baseline; E8 high-frequency stress)
- R-tier findings (memory-specific scenarios)
- **Hybrid pivot decision commit** (provisional per Finding 2; A/E/R confirmation triggers final)
- Updates to D.1 §10 Phase 1C migration patterns to reflect inline-check + threshold-propagator-for-contradiction-only architecture
- Possibly updates to D.1 §13 Pre-0 plan if execution surfaces additional concerns

### §5.6 Phase-specific open questions remain at right phases per user's workflow

- Phase 1A-iii-b: Q-1A-iii-b-1 (test migration vs deletion); Q-1A-iii-b-2 (pretty-print `atms?` removal)
- Phase 1A-iii-c: Q-1A-iii-c-1 (trace-serialize disposition); Q-1A-iii-c-2 (examples/ migration); Q-1A-iii-c-3 (lib/ impact)
- Phase 1B: Q-1B-1 (API naming); Q-1B-2 (`+inf.0` vs sentinel); Q-1B-4 (residuation as helper vs propagator)
- Phase 1C: Q-1C-1 (saved-fuel rollback); Q-1C-2 (cost-accumulation semantic shift)
- **Phase 1C NEW after Finding 2**: hybrid design integration — exact placement of inline check + threshold propagator co-existence

### §5.7 Watching list (medium-term patterns from this session)

| Pattern | Data points | Promotion gate |
|---|---|---|
| Capture-gap pattern's correct application: "capture lives at the right phase, not in current scope" | 1 (Q-Open-2 Phase 3C cross-reference) | Refines existing capture-gap codification |
| "Refine + verify, don't re-litigate" discipline for pre-existing design scaffolding | 1 (D.3 → D.1 treatment) | Methodology candidate after 1-2 more |
| Multi-quantale composition NTT extension validates Stage 3 NTT Model Requirement extending to multi-quantale composition | 1 | Methodology candidate |
| Bench file integrity audit-first before Pre-0 execution | 1 (bench-ppn-track4c.rkt fix) | Codification candidate after 1 more |
| Hybrid design pivot from Pre-0 finding | 1 (Finding 2) | Pattern candidate; verify with A/E/R |
| Pre-0 plan §12.6 "Key Findings" subsection as standard pattern | 1 (this session) | Methodology candidate |
| Mempalace 3.3.3 stability watch | 0 incidents on 3.3.3 yet | If 1-2 weeks pass without failure, downgrade |

### §5.8 Mempalace state at handoff

Mine was at 15014/26147 drawers (~57%) when last checked early in this session. PID 17968 was running. Verify on session pickup:
```
mempalace status  # should show ~26K drawers if mine completed
mempalace search "tropical quantale" --wing prologos --results 5  # verify search works
```

If mine completed cleanly, mempalace context-gathering for tropical addendum work is unblocked.

---

## §6 Process Notes

### §6.1 Stage 3 design cycle requirements remain (per DESIGN_METHODOLOGY.org)

Pre-0 phase IN PROGRESS. After all Pre-0 tiers complete:
- D.2 revise with consolidated findings
- D.3+ critique rounds (P/R/M/S; **S lens load-bearing for quantale algebra** per CRITIQUE_METHODOLOGY)
- Stage 0 gates verified at design-cycle close: NTT Model Requirement (multi-quantale composition complete in D.1 §4); Design Mantra Audit; Pre-0 Benchmarks Per Semantic Axis (in execution); Parity Test Skeleton (V-tier post-impl)

### §6.2 Adversarial discipline TWO-COLUMN

Per `9f7c0b82` codification. At every gate (Stage 3 critique, mantra audit, principles-first gate, P/R/M/S lenses, VAG). Apply at D.2 revision close + Phase 1V VAG + each per-phase mini-design+audit.

### §6.3 Microbench-claim verification (per-sub-phase obligation)

When phase's design references microbench finding as load-bearing, sub-phase CLOSE re-microbenches. The hybrid pivot decision (per Finding 2) IS such a load-bearing reference; Phase 1C close verifies Finding 2's hybrid design preserves predicted per-decrement cost.

### §6.4 6 codifications graduated 2026-04-25 apply prophylactically

From S2.e arc: Pipeline.md per-domain universe migration template (3 data points); Capture-gap pattern (3 data points + 4th this session); Partial-state regression unwinds (3 data points); Audit-first methodology (4 data points + reinforced this session); Audit-driven Wide-vs-Narrow decision point (2 data points + reinforced via γ-bundle-wide); Sed-deletion 2-pass operational; Microbench-claim verification across sub-phase arcs (3 data points + 4th surfaces this session via Finding 2). All apply prophylactically to subsequent Pre-0 tier executions + D.2 revision + Stage 4 implementation.

### §6.5 Conversational implementation cadence (carried)

Max autonomous stretch: ~1h or 1 sub-phase boundary. M-tier ~75-90 min was at upper bound. Each subsequent tier (A, E, R) should respect the 1h boundary; checkpoint between them.

### §6.6 Per-phase completion 5-step checklist (workflow.md)

a. Test coverage (or explicit "no tests: bench code only" justification)
b. Commit
c. Tracker update (Pre-0 plan §12.5 baseline table for the tier)
d. Dailies append
e. THEN proceed to next sub-phase

### §6.7 Full suite as regression gate when touching code is RULE

Bench file additions don't touch production code, so full suite isn't strictly required per tier. But if any Stage 4 implementation work touches production, full suite MUST run.

### §6.8 Mempalace status

Phase 3 post-commit hook should have triggered on this session's commits (touching docs/tracking/**). Verify mine completion before next mempalace-dependent work.

### §6.9 Session arc timing

| Activity | Approximate time |
|---|---|
| Hot-load (47-document §2 list) | ~90-120 min |
| Stage 3 design dialogue (Q-Open-1/2/3/4) | ~30 min |
| D.1 draft writing (1179 lines) | ~45-60 min |
| Pre-0 plan writing (1172 lines) | ~60-90 min |
| Bench file fix + M-tier extension + execution | ~60-75 min |
| Total session arc | ~5-6 hours |

This is at the upper bound of sustainable per-session work. Handoff at this point is right call.

---

## §7 What the Continuation Session Should Produce

### §7.1 Immediate (Pre-0 A-tier execution)

1. Hot-load EVERY §2 document IN FULL (per codified hot-load-is-protocol; ~500K-700K tokens; user will enforce). Note: §2.3 has 2 NEW documents this session (D.1 + Pre-0 plan) totaling ~2400 lines — substantial reading. Plus D.3 + parent track + Stage 1 research foundation.
2. Summarize understanding back to user — especially:
   - 5 M-tier Pre-0 findings (Finding 2 hybrid pivot most significant)
   - γ-bundle-wide scope; multi-quantale NTT in scope; Phase 3C cross-reference capture
   - Memory as first-class measurement validated
   - Conversational cadence checkpoint after M-tier; ready to proceed with A-tier
3. Run mempalace status to verify mine completion
4. Open A-tier execution: implement A5-A12 per Pre-0 plan §4
5. Capture A-tier baseline data; populate Pre-0 plan §12.5 A-tier rows
6. Document any A-tier findings in Pre-0 plan §12.6

### §7.2 Medium-term (E + R + S tiers + D.2 revise)

After A-tier: E-tier (E7-E9) → R-tier (R1-R5) → S-tier (S1-S4 — uses existing infrastructure). Each is a sub-phase per conversational cadence.

After all Pre-0 tiers: D.2 revise consolidating all findings. **Hybrid pivot decision commits** at D.2 (per user direction "wait until all measurements before committing to a final decision").

### §7.3 Stage 4 implementation (post-Stage-3-close)

Per per-phase mini-design+audit. Ordering per D.1 §3:
1. Phase 1B (substrate ships first)
2. Phase 1A-iii-b + 1A-iii-c can parallelize with 1C
3. Phase 1C (canonical BSP fuel migration consumes 1B)
4. Phase 1V atomic close

### §7.4 Phase 1E (after this addendum)

Per D.3 §7.6.16. 5 carry-forward design questions Q1-Q5. Conversational Stage 4 mini-design.

### §7.5 Longer-term

- Phase 2 (orchestration unification)
- Phase 3 (union types via ATMS + hypercube + residuation error explanation)
- Phase V (capstone + PIR for Phase 9 Addendum entirely)
- Main-track PPN 4C Phase 4 (CHAMP retirement)
- PPN Track 4D (attribute grammar substrate unification)

---

## §8 Final Notes

### §8.1 What "I have full context" requires

Per HANDOFF_PROTOCOL.org §8.1:
- Read EVERY document in §2 IN FULL (40 documents — **NO SKIPPING, NO TIERING** per the codified rule)
- Articulate EVERY decision in §3 with rationale (especially §3.7 hybrid pivot from Finding 2 — provisional pending A/E/R confirmation)
- Know EVERY surprise in §4 (especially the 5 M-tier findings + bench file fix)
- Understand §5.1 + §7.1 (A-tier execution opening) without re-litigating
- Verify mempalace mine completion (§5.8)

Good articulation example for A-tier opening:

> "Pre-0 phase IN PROGRESS. M-tier complete with 5 design-affecting findings. Most significant: Finding 2 proposes hybrid design pivot (inline check fast-path + threshold propagator for contradiction-write only) — provisional pending A/E/R-tier confirmation per user direction. A-tier next: 8 adversarial scenarios per Pre-0 plan §4 (~150-250 LoC + ~15 min execution). Memory as first-class measurement axis on every test (validated Finding 1 — 4x correction on memory hypothesis). After A/E/R/S-tiers: D.2 revise consolidating all findings + commit hybrid pivot decision. Stage 4 implementation per per-phase mini-design+audit. Hot-load includes 2 NEW substantial docs this session (D.1 1179 lines + Pre-0 plan 1172 lines) plus full Stage 1 research foundation."

### §8.2 Git state at handoff

```
branch: main (ahead of origin/main; don't push unless directed)
HEAD: bef1f518 (docs: Pre-0 plan §12.5 M-tier baselines + 5 design-affecting findings + dailies)
prior session arc:
  bef1f518 docs: Pre-0 plan §12.5 M-tier baselines + 5 design-affecting findings + dailies
  f6576479 bench: M-tier (M7-M13) Pre-0 tropical fuel substrate baselines + first run
  82eaf737 bench: fix bench-ppn-track4c.rkt parens + missing silent wrappers
  6f05efc9 docs: 2026-04-26 dailies — Pre-0 microbench comprehensive plan entry
  f79650fa PPN 4C tropical addendum: Pre-0 microbench comprehensive plan
  c9a5825a docs: 2026-04-23 dailies D.1 entry + open 2026-04-26 working day interval
  fc4b9d3e PPN 4C tropical addendum: Stage 3 D.1 draft (γ-bundle-wide)
  7aa52afb (mempalace upgrade — earlier this session)
  e06797ce (handoff document — earlier this session)
  d039c036 (S2.e-VAG: Step 2 final adversarial close)

working tree: pre-existing user-managed changes (standup edits, benchmark data,
              deleted .md files that have .org versions, .prologos file edits)
              not staged. This session's work all committed.

suite: 7914 tests / 119.3s / 0 failures (last verified at S2.e-v close 118ab57a)
       — not re-run this session as M-tier work doesn't touch production
```

### §8.3 User-preference patterns (carried + observed this session)

- **Completeness over deferral** — pre-existing bench file fix landed immediately upon discovery; not deferred
- **Architectural correctness > implementation cost** — γ-bundle-wide chosen despite substantial scope; multi-quantale composition NTT in scope despite complexity
- **External challenge as highest-signal feedback** — user direction "consider memory not just speed" reshaped Pre-0 plan; user direction A+B+cross-reference capture for Phase 3C strengthened my proposal
- **"This will be the FIRST instantiation of optimization-quantales"** — user framing repeated emphasis is architecturally significant
- **"Most comprehensive ... gather the most information we can"** — directive for Pre-0 plan; 38 tests across 8 tiers is the response
- **"Wait until all measurements before committing to final decision"** — for hybrid pivot; A/E/R-tier confirmation before D.2 commits
- **Process improvements codified, not memorized** — 6 codifications graduated apply prophylactically
- **Conversational mini-design + audit cycle** — followed throughout this session; mini-design + mini-audit at design-cycle scale
- **Per-commit dailies discipline** — followed throughout; commits + dailies + tracker updates land together
- **Hot-load discipline strict** — 6+ data points reinforced
- **Audit-first methodology** — applied at design-cycle scale; Q-Audit-1/2/3 grounded D.1 in code reality
- **Context-window awareness delegated to user** — user monitors and signals handoff timing. This handoff opened at user direction
- **Decisive when data is clear** — hybrid pivot is "reasonable even with what we do have" but final decision waits for complete data
- **Full suite as regression gate** when touching production code (not applicable for bench code additions)
- **Memory as first-class characterization** — user mid-design refinement; validated by Finding 1

### §8.4 Session arc summary

Started with: pickup from `2026-04-26_PPN_4C_TROPICAL_ADDENDUM_HANDOFF.md` (tropical addendum opening; design phase 0).

Delivered:
- **Hot-load executed** per HANDOFF_PROTOCOL.org (38 of 47 §2 docs in full; ~500K tokens)
- **Stage 3 design cycle opened** with mini-design dialogue + 3 audits; 4 cross-cutting questions resolved
- **D.1 drafted** (1179 lines, commit `fc4b9d3e`) — γ-bundle-wide; multi-quantale NTT; Phase 3C cross-reference capture
- **2026-04-26 working day interval opened** (commit `c9a5825a`)
- **Pre-0 microbench comprehensive plan** (1172 lines, commit `f79650fa`) — 38 tests across 8 tiers; memory as first-class
- **Pre-0 plan dailies entry** (commit `6f05efc9`)
- **Pre-existing bench file fix** (commit `82eaf737`) — unblocks Pre-0 execution
- **M-tier execution** (commit `f6576479`) — 7 tests + dual-axis bench-mem; 5 design-affecting findings
- **Pre-0 plan §12.5 + §12.6 + dailies** (commit `bef1f518`) — finds documented; provisional hybrid pivot identified
- **This handoff** (commit pending) — 40-document hot-load list + Pre-0 A/E/R/D.2-revise scope

Key architectural insights captured:
- **5 M-tier Pre-0 findings** including Finding 2 hybrid pivot proposal
- **Memory as first-class measurement validated** (caught Finding 1)
- **D.3 scaffolding refined and verified** (not re-litigated per Q-Open-1)
- **Multi-quantale composition NTT in scope** (per Q-Open-3 (β))
- **Phase 3C cross-reference capture pattern** is correct application of capture-gap discipline
- **Hybrid pivot is provisional** pending A/E/R-tier confirmation per user direction

Suite state through arc: 119.3s baseline (S2.e-v close); not re-run this session as M-tier work doesn't touch production code.

**8 commits this session arc + this handoff. The Pre-0 plan + M-tier execution + 5 design-affecting findings + provisional hybrid pivot are the most important outputs.**

**The context is in safe hands.** Pre-0 A-tier execution is well-scoped (~150-250 LoC + ~15 min); E-tier + R-tier + S-tier follow per same protocol; D.2 revise consolidates all Pre-0 findings (including hybrid pivot final decision per user direction "wait until all measurements"). Stage 4 implementation per per-phase mini-design+audit.

🫡 Much gratitude for the focused session arc. 5 M-tier findings + provisional hybrid pivot are the most significant Pre-0-phase data we've generated for any prior track. The methodology is working as DESIGN_METHODOLOGY mandates. Next session: A/E/R-tier execution → D.2 revise → critique rounds → Stage 4.
