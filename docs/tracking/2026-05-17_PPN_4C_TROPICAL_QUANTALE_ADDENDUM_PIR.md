# PPN 4C Tropical Quantale Addendum — Post-Implementation Review

**Date**: 2026-05-17
**Track**: PPN 4C Phase 9+10+11 Addendum — Tropical Quantale Substrate Completion (γ-bundle-wide: 1A-iii-b + 1A-iii-c + 1B + 1C + 1V)
**Duration**: 2026-04-21 → 2026-05-17 (26 calendar days; ~25 active sessions; ~80-100 active hours estimated)
**Commits**: ~64 commits in scope (`de357aa1` Stage 1 research → `b8405dfb` Phase 1V atomic close)
**Test delta**: 7914 → 8224 (+310 tests; ATMS retirements −90 offset by tropical-fuel + cache consistency + property-sweep additions +400)
**Suite wall delta**: 119.3s → 114.7s (**−4.6s wall time despite +310 tests** — strongest quantitative signal of D.4's success)
**Code delta**: net negative in production code (−2649 LoC across 1A retirement; +~2000 LoC tropical-fuel/specialized-cells/cache infrastructure; net ~−650 LoC production); +~3500 LoC docs (design + dailies + research)
**Design docs**: [Stage 1 research](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) · [Pre-0 plan](2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md) · [Design (D.1→D.4)](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) · [D.2.SC self-critique](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md) · [D.3.EC external critique](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_EXTERNAL_CRITIQUE.md) · [parent: PPN 4C Phase 9 design](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) · [PPN 4C parent track](2026-04-17_PPN_TRACK4C_DESIGN.md)

---

## 1. What Was Built

The PPN 4C Tropical Quantale Addendum delivered **two architectural outputs of unequal magnitude** — only one of which was foreseen at Stage 1.

### Delivery 1 (FORESEEN): Tropical Quantale as First Production Optimization-Quantale

The stated intent (per D.1 §1.1): *"Phase 9's tropical fuel cell is the first practical instantiation of a tropical-lattice / quantale / semiring / cost-optimization structure in Prologos production code... it deserves the most careful considerations that we can pay it its dues."*

What landed:

- **`tropical-fuel-primitives.rkt`** (pure algebra; cycle-safe leaf module): bot (0) + top (+inf.0) + merge (min, Lawvere join) + meet (max) + tensor (+, cost composition) + left-residual (b − a when b ≥ a, else 0)
- **`tropical-fuel.rkt`** (SRE-integration layer): domain registration with 11 declared algebraic properties + merge-registry + meet-registry. Variety placement empirically validated via Track 2I property-sweep at Phase 1V Commit 7: **SD ✓ Modular ✓ Distributive ✓ Heyting ✓ Stone ✗ Boolean ✗ Whitman ✓** — exact prediction for a total-order chain. F11 critical halt-and-investigate gate ✓ PASSED — all 3 ⭐ declared-and-swept properties (distributive + has-pseudo-complement-{rel,abs}) CONFIRM at 100% non-vacuity.
- **Multi-quantale composition NTT model** (§4.2): TypeFacetQ + TropicalFuelQ as independent Q-modules; Galois bridge type-cost-bridge declared (Form A/B/C); quantale-of-bridges forward-compatible with quantaloids.
- **ATMS substrate consolidation**: Tier 2 (13 deprecated atms internal API functions + atms struct + atms-believed; 1A-iii-b) and Tier 3 (14 surface ATMS AST structs + 14-file pipeline; 1A-iii-c) RETIRED — modern solver-context (from BSP-LE Track 2) becomes sole hypothetical-reasoning substrate. **−2649 LoC** across Phase 1A.
- **Cell-as-canonical realized**: struct field `prop-net-cold-fuel` + macro `prop-network-fuel` RETIRED at 1C-iv-b (`00f7ce05`). Cell IS the live state. The D.3 hybrid-pivot scaffolding never shipped — its empirical motivation was falsified by the §13.6 spike.
- **Form C cross-reference**: parent design doc §9.5.A NEW (`b8405dfb`) with UC1/UC2/UC3 explicit pointers to addendum §9.7 + algebraic property empirical validation pointer. Closes the §6.5 capture-gap discipline.

### Delivery 2 (UNFORESEEN): Specialized Cell Type Framework + Cell/Propagator/Scheduler Orthogonality

This delivery emerged during D.3.EC critique resolution (2026-05-14) when the user articulated:
> *"We've explored three scheduler implementations without changes to the network computation... given our CALM-compliant network architecture, it is conceivable that we could have arbitrary number of different schedulers to run the same network — even in different languages. This could make Prologos highly portable if done correctly... The problem I see, is about coupling too much on the scheduler, complecting what should be orthogonal — making a thin scheduler and portability more tricky."*

That insight rejected the D.3 hybrid-pivot wholesale and reframed the architecture toward on-network optimized cell type. What landed:

- **Specialized cell type framework** (`specialized-cells.rkt` + `prop-net-warm` extensions to 5 fields + `specialized-cell-meta` 6-field struct): cell metadata declares `:tier` + `:storage` + `:fires-on` + `:on-write-check` + `:on-read-check` + `:merge-fn` (cached). Direct fixnum mutation under no-speculation (fast path); tagged-cell-value fallback under speculation (correctness preserved).
- **Cell/Propagator/Scheduler Orthogonality principle**: codified as top-level principle in [`DESIGN_PRINCIPLES.org`](principles/DESIGN_PRINCIPLES.org) (commit `6a628bc7`). Optimization location rule: state storage at cell layer; fire-pattern at propagator layer; scheduling efficiency at scheduler layer. The architecture has three orthogonal concerns; mixing them destroys portability across schedulers (Gauss-Seidel, BSP, Zig+LLVM, future distributed). Prophylactic for PReduce + OE + SH + PM 12 + PPN 4D tracks.
- **Well-known direct-ref cache pattern** instantiated 3× empirically (under-speculation? + fuel-cell-cache + worldview-cache-cache) — template validated IN-TRACK at Phase 1V Commits 3b + 5b (the codified prediction at Commit 4 was empirically refuted-to-confirmed at Commit 5b with zero implementation surprises beyond audit).
- **4 codifications graduated to principles documents** at Commit 4 (`90c271fa`):
  1. DEVELOPMENT_LESSONS: "Cache Projection Should Model Read-Side + Write-Side Independently"
  2. DEVELOPMENT_LESSONS: "Cache Write-Through With Persistent CHAMP: Explicit Audit List IS the Drift Mitigation"
  3. DESIGN_PRINCIPLES: "Specialized Cell Type Framework as Cross-Track Template"
  4. (Plus orthogonality principle itself codified at `6a628bc7`)
- **Performance results**: Cell-write fast path **3.94-4.52 ns/cycle production** at Var-A N=100 (−47.9% vs pre-Item-#1 baseline 7.56 ns/cycle); cell-read **10.9 ns/call** (−85% vs pre-Item-#1-bis 74.3 ns/call); **zero major-GC at 100k decrements** (R3 baseline structurally preserved throughout Phase 1); 5700× memory improvement vs Pre-0 A7.3 at 100k decrements (§13.6 spike empirical proof).

### Architectural significance — why Delivery 2 reaches further

Delivery 1 is a SUBSTRATE for ~2 known consumers (Phase 3C + PReduce Track 4). Delivery 2 is a CROSS-TRACK TEMPLATE that enables 5+ tracks across 4 series (PM 12 + PReduce Tracks 1+5 + OE Tracks 0-4 + SH Tracks 1+4+6 + PPN 4D). The unforeseen delivery is the more architecturally significant outcome — and Phase 1V codified it not only as code (the framework + the 3 cache instances) but as principle (the Orthogonality discipline + the Cross-Track Template promotion). The meta-lesson is elevated at §10.

---

## 2. Timeline and Phases

The arc spans **2026-04-21 to 2026-05-17** (26 calendar days; ~25 active sessions). The design-to-implementation ratio is unusual — design + critique + Pre-0 + reframing occupied ~17 days (D.1 → §13.6 spike) before substrate implementation began at Phase 1B (2026-05-15). Once architecture was settled (D.4 canonical post-spike), the implementation arc ran ~3 days: Phase 1B (4 sub-phases, 1 day) + Phase 1A retirements (2 commits, < 1 day) + Phase 1C (6 sub-phases, 1 day) + Phase 1V (8 commits, 1 day).

### 2.1 Chronological commit timeline

| Commit | Date | Phase | Description | LoC |
|---|---|---|---|---|
| `de357aa1` | 04-21 | Stage 1 research | Tropical quantale research document | +1000/−0 |
| `fc4b9d3e` | 04-26 | Stage 3 D.1 draft | γ-bundle-wide design doc | +1179/−0 |
| `f79650fa` | 04-26 | Pre-0 plan | 38-test plan across 8 tiers | +1172/−0 |
| `f6576479` → `8a29f6af` | 04-26 | Pre-0 execution | M+A+E+R+S tiers; 22 design-affecting findings | ~+1610/−287 |
| `219d8eb9` | 04-26 | D.2.SC | Self-critique P/R/M/S; 18 findings (3 BLOCKING) | +628/−0 |
| `2a4d938c` | 04-26 | D.2 revise | Hybrid pivot architecture committed (later reversed) | +382/−118 |
| `0538582f` → `76a73ada` | 05-02 | D.3 batch (10 commits) | 18 D.2.SC findings closed | ~+342/−52 |
| `61d7ab07` | 05-14 | D.3.EC | External critique; 11 findings | +513/−1 |
| `6a628bc7` | 05-14 | **Orthogonality** | Codify Cell/Propagator/Scheduler Orthogonality principle | +381/−1 |
| `45181c07` | 05-14 | D.4 scaffold | Specialized cell framework §4.6 + Pre-0 spike plan §13.6 | +460/−39 |
| `7b681b9e` | 05-14 | **§13.6 spike ✓ PASS** | D.4 canonical — framework feasible (W1+ 6.4 ns; 0 major-GC) | +590/−0 |
| `ae057b3a` + `bb503255` | 05-14 | D.4 canon | Full §9 + §10 + §15 content; governance (Issue #55 close) | +702/−200 |
| `77daf81c` + `8aa4c907` | 05-15 | §13.6.A Option 13 ✓ | Deferred-write 2.16 ns/cycle (2.4× faster than struct-copy) | +1072/−39 |
| `3cecc1f6` | 05-15 | 1B-i spike | cell-meta storage gate PASS (4.06 ns/call) | +284/−1 |
| `73c9407d` | 05-16 | 1B-ii impl | Specialized cell framework — gate PASS 2.98 ns/cycle | +626/−26 |
| `f7bc1ce6` | 05-16 | 1B-iii impl | Tropical quantale primitive — C1+C2+C3 axioms PASS | +532/−1 |
| `c83dd78e` | 05-16 | 1B-iv impl | Canonical fuel cell registration; **8286 / 127.4s** | +341/−48 |
| `cd770a06` → `ee5010c1` | 05-16 | Phase 1C (6 sub-phases) | Variant A/B migrations + check sites + 1C-iv-{a,b} migrations + retirements; **cell IS sole live state** at `00f7ce05` (1C-iv-b); 1C-vi A/B/C report | ~+3000/−1300 |
| `d9c91f38` | 05-17 | 1A-iii-c impl | Surface ATMS AST 14-file pipeline retirement | +5/−1143 |
| `fef06994` | 05-17 | 1A-iii-b impl | Tier 2 deprecated ATMS internal API retirement | +96/−1606 |
| `2535c886` | 05-17 | 1V Commit 1 | Phase 1V mini-design + §11.2 D.4 CANONICAL reframing | +219/−12 |
| `e6308cb6` + `b07d8f87` | 05-17 | 1V Commit 2 | Item #1 merge-fn-caching (PARTIAL-RECOVERY −23.5%) | +410/−13 |
| `b138bca7` + `95ad2625` + `129f8173` | 05-17 | 1V Commit 3 | Item #1-bis fuel-cell direct-ref caching (✓ GATE-MET; **6× projected savings**; −47.6% cumulative) | +849/−20 |
| `90c271fa` | 05-17 | 1V Commit 4 | Option C gate re-calibration (§13.7.A) + **3 codifications graduated** | +325/−2 |
| `48b3993d` + `a69638ae` | 05-17 | 1V Commit 5 | Item #1-quater worldview-cache caching (✓ FORWARD-INVESTMENT; pattern reuse validated) | +486/−41 |
| `252f8c87` + `b1b5b9ce` | 05-17 | 1V Commit 6 | F14 retirement (`tropical-fuel-merge-for-cell` inlined-duplicate via two-layer module split) | +318/−85 |
| `48f52ed2` | 05-17 | session snapshot | Post-Commit-6b state | +258/−0 |
| `278be33d` + `a4e9f417` | 05-17 | 1V Commit 7 | Item #3 SRE property-sweep verification (**✓ F11 GATE PASSED**) | +646/−3 |
| `b8405dfb` | 05-17 | **1V Commit 8 — ATOMIC CLOSE** | Phase 1 VAG ATOMIC CLOSE ✓ ALL GATES PASS | +266/−1 |

### 2.2 Phase-to-phase test/wall progression

| Boundary | HEAD | Tests | Wall | Δ vs Pre-Stage-1 |
|---|---|---|---|---|
| Pre-Stage-1 baseline | (pre-`de357aa1`) | 7914 | 119.3s | — |
| Post-Pre-0 + design + spikes (docs/throwaway only) | `7b681b9e` | 7914 | 119.3s | 0 / 0 |
| Post-1B-iv (Phase 1B CLOSE) | `c83dd78e` | 8286 | 127.4s | +372 / +8.1s |
| Post-1C-vi (Phase 1C CLOSE) | `ee5010c1` | 8299 | 120.9s | +385 / +1.6s |
| Post-1A retirements (Phase 1A CLOSE) | `fef06994` | 8209 | 98.4s | +295 / **−20.9s** |
| Post-1V Commit 3b (Items #1+#1-bis) | `129f8173` | 8209 | 96.2s | +295 / −23.1s |
| Post-1V Commit 5b (Item #1-quater) | `a69638ae` | 8213 | 97.2s | +299 / −22.1s |
| Post-1V Commit 7b (Item #3 sweep) | `a4e9f417` | 8219 | 108.8s | +305 / −10.5s |
| **Post-1V Commit 8 (Phase 1 ATOMIC CLOSE)** | `b8405dfb` | **8224** | **114.7s** | **+310 / −4.6s** |

**Design-to-implementation time ratio**: roughly 17 days design + critique + Pre-0 (04-26 → 05-14) vs 3 days implementation (05-15 → 05-17) — **5.7:1 design:impl**. This is the longest design-discipline arc in the recent 10-PIR window (compare BSP-LE 2 at 0.6:1; SRE 2H at 2.5:1). The high ratio correlates with low bug count during implementation (see §4).

### 2.3 What was deferred

Per §1.3 of the design doc:

- **Phase 1E** (`that-*` storage unification per parent D.3 §7.6.16) — 5 carry-forward Q1-Q5 questions; conversational Stage 4 mini-design when context returns to it
- **Phase 2** (orchestration unification) — separate addendum after Phase 1 closes
- **Phase 3A/B/C** (union types via ATMS + hypercube + residuation error explanation) — Phase 3C is the first downstream consumer of Form C
- **Phase V** (capstone + parent-PIR for Phase 9 Addendum entirely) — after all parent phases close
- **Multi-quantale composition implementation** — NTT model shipped; computational realization deferred to Phase 3C UC2 consumer + future PReduce
- **Quantaloids** (Stubbe 2013 many-object quantales) — out of scope; flagged for future when multi-domain cost currencies co-exist
- **Polynomial Lawvere Logic / Rational Lawvere Logic** (Bacci-Mardare-Panangaden-Plotkin 2023) — language-surface form for self-hosting; out of scope per Stage 1 research §11.7
- **General residual solver** (BSP-LE Track 6 forward reference) — Phase 1B consumes BSP-LE 2B substrate without coupling to relational layer
- **OE Series formalization** — first production landing happened here; formal OE master tracking decision deferred to user per addendum §6.6 OE Series row

All deferrals are genuine dependencies or future architectural decisions, not exhaustion/scope-creep. DEFERRED.md updated accordingly.

---

## 3. Test Coverage

### 3.1 New / modified test files

| File | Status | Test count | Phase | Categories covered |
|---|---|---|---|---|
| `tests/test-tropical-fuel.rkt` | NEW + extended | 56 (was 0 at Stage 1) | 1B-iii, 1B-iv, 1C-vi | C1+C2+C3 algebraic axioms; merge/meet/tensor/residuation; +inf.0 boundary cases; C4/C5; γ3-b behavioral contract (tropical-fuel-counter-parity); δ3 regression; allocation verification (D-1B-ii-3) |
| `tests/test-specialized-cells.rkt` | NEW | 9 + 4 cache consistency = 13 | 1B-ii, 1V Commit 3b, 1V Commit 5b | Specialized cell registration; fast-path dispatch; cache consistency after write/reset/fork/promote/dependents-update for fuel-cell-cache + worldview-cache-cache |
| `tests/test-elaboration-parity.rkt` | EXTENDED | 16 (incl. tropical-fuel-counter-parity §15 axis) | 1C-vi | Cell-as-canonical parity vs pre-D.4 counter behavior |
| `tests/test-sre-sd-properties.rkt` | EXTENDED | +5 net for tropical-fuel section | 1V Commit 7b | Sweep registration + finding count + shape verification + 3 ⭐ declared-and-swept assertions (distributive + has-pseudo-complement-{rel,abs}) |
| `tests/test-atms.rkt`, `tests/test-atms-integration.rkt`, `tests/test-atms-types.rkt` | DELETED | −90 tests aggregate | 1A-iii-b, 1A-iii-c | Tier 2 + Tier 3 ATMS retirement; coverage migrated to test-solver-context where gaps existed |

### 3.2 Aggregate

- **Net suite delta**: 7914 → 8224 = **+310 tests** across the arc
- **Highest peak**: 8299 at 1C-vi (`ee5010c1`); subsequent Phase 1A retirement dropped to 8209
- **Final**: 8224 at `b8405dfb` (within §11.3 118-127s variance band; 4.6s under midpoint)

### 3.3 Acceptance / parity validation

- **Probe**: `examples/2026-04-22-1A-iii-probe.prologos` (28 commands) ran cleanly at every Phase 1V close. Semantic diff = 0 (per Phase 1V Commit 8 verification): 28 commands → 28 elaboration result strings matching expected types (Int / String / Map / List / Option / Bool); exit 0; final propagators=0
- **Parity axes** (§15):
  - tropical-fuel-counter-parity (1C-vi γ3-b) — OLD counter vs NEW cell exhaustion equivalence ✓
  - atms-deprecated-api-parity (1A-iii-b) — deprecated callers either migrated or removed ✓
  - surface-atms-ast-elaboration-parity (1A-iii-c) — post-retirement: surface forms produce parse error ✓
  - tropical-fuel-merge-parity (1B) — merge semantics + threshold firing ✓

### 3.4 Captured artifacts (data/benchmarks/)

- `tropical-pre0-baseline-2026-04-26.txt` (13313 bytes) — Pre-0 M+A+E+R+S baselines; reference for A/B comparison
- `tropical-spike-d4-2026-05-14.txt` — §13.6 spike W1-W5 measurements
- `tropical-spike-d4-option13-2026-05-15.txt` — §13.6.A Option 13 measurements
- `tropical-fuel-phase9-sweep-2026-05-17.txt` (3963 bytes) — Track 2I property-sweep findings table (20-property variety placement + per-finding detail + 5 witness footnotes)
- 1C-vi A/B/C report — production-realistic-N measurements

---

## 4. Bugs Found and Fixed

Phase 1V's bug count was unusually low (~5 distinct bugs across 3 days of implementation) — the inverse correlation between design-iteration count and bug count (P-B from §16 longitudinal patterns) held.

### 4.1 1B-ii merge-fn correctness bug in fast-path

**Surfaced**: 1B-iv (`c83dd78e`) — cell-registration tests revealed it
**Root cause**: 1B-ii's specialized cell fast-path called the wrong merge function (used a default/fallback rather than the registered `:merge-fn` per the cell-meta declaration)
**Why plausible**: the framework introduces a new dispatch layer; the fast-path skips the slow-path's registry lookup; the cache was populated but the lookup path was wrong
**Fix**: redirected fast-path through registered `:merge-fn` access pattern
**Generalization**: codified at workflow.md "Network Reality Check" — when introducing a new dispatch layer, verify the new path produces equivalent results to the old path under realistic inputs (microbench correctness vs perf separation)

### 4.2 F15 + F18 dual-path require missing (cycle-broken SRE domain)

**Surfaced**: F15 at Commit 7a re-audit (test path); F18 at Commit 7b impl (tool path)
**Root cause**: F14 (Commit 6) retired the inlined-duplicate by extracting algebraic primitives to a leaf module. `propagator.rkt` requires only the primitives now (per the cycle-break design). The `register-domain!` call in `tropical-fuel.rkt` (the SRE-integration module) only fires when that module is explicitly required. Neither `test-sre-sd-properties.rkt` nor `tools/run-phase9-sweep.rkt` originally required it.
**Why plausible**: pre-F14, anyone using tropical-fuel-merge implicitly loaded the SRE-integration module too (via the inlined duplicate). Post-F14, the require pattern became explicit per call site — but the test + tool files weren't updated as part of the F14 retirement.
**Fix**: added `(require "../tropical-fuel.rkt")` to both files
**Codification candidate (2 data points; watching list)**: "Domain-registration require must land at BOTH test path AND tool path when SRE-integration module is decoupled via cycle-break"

### 4.3 F16 naming-inversion concern (REFUTED by measurement)

**Surfaced**: Commit 7a mini-design re-audit
**Root cause**: NOT a bug — a pre-impl over-cautious prediction. Mini-design F16 predicted `has-pseudo-complement-abs` might REFUTE under Lawvere natural-order naming (bot=0 + merge=min means crude "max(a, x) = 0" only for a=0)
**Outcome**: Commit 7b empirical measurement showed CONFIRM at 7/7 = 100% non-vacuity. The sweep's pseudo-complement check is more sophisticated than crude meet-equals-bot analysis (residuation-aware).
**Lesson**: trust measurement over pre-impl conjecture for declared-property verification; codification candidate (1 data point; watching list)

### 4.4 Test-facet-sre-registration batch-worker linklet staleness (Phase 1V Commit 8 verification)

**Surfaced**: full-suite run at Phase 1V Commit 8 verification
**Root cause**: `.zo` linklet mismatch from recompile cycle interactions during Phase 1V (bench-tropical-fuel.rkt recompile may have invalidated batch-worker `.zo` of unrelated tests via shared transitive deps)
**Why plausible**: individual test PASSED (21/21); batch worker hit stale linklet — classic two-context boundary bug (P-E from §16)
**Fix**: targeted recompile + force-rerun → 8224 / 114.7s / 0 failures
**Codification candidate (1 data point; watching list)**: "Post-recompile linklet-staleness across unrelated batch-worker .zo: force-rerun resolves cleanly"

### 4.5 Phase 1V Commit 2 Item #1 — §13.7 gate-decision-tree gap

**Surfaced**: Commit 2b measurement (Var-A N=100 = 5.78 ns/cycle, −23.5% recovery)
**Root cause**: NOT a bug — a methodology gap. The §13.7 ε-measurement-driven decision tree had 3 named ranges (≤ 3 ns ratify; 3.5-4 ns escalate; no Δ → investigate). Measurement landed at 5.78 ns — in an UNCOVERED range (4-6 ns substantial-but-insufficient).
**Resolution**: user-directed Option (d) — defer combined Item #1 + Item #1-bis measurement to Commit 3 close; conditional Item #1-ter if combined fails. Item #1-bis subsequently hit ≤ 5 ns gate; Item #1-ter NOT triggered.
**Lesson**: decision trees in gate-decision protocols need explicit "fall-through" ranges for measurements that don't match named ranges. Codification candidate at watching list.

---

## 5. Design Decisions and Rationale

### 5.1 γ-bundle-wide scope (Phase 1A-iii-b + 1A-iii-c + 1B + 1C + 1V atomic)

**Decision**: bundle Tier 2 + Tier 3 ATMS retirement with tropical fuel substrate introduction + canonical migration + atomic close.
**Rationale**: per Q-A3 — these are naturally adjacent. Retiring the OLD substrate (deprecated atms internal API + surface AST) is co-temporal with shipping the NEW substrate (tropical primitive). Bundling closes Phase 1 atomically at one VAG.
**Principle served**: Completeness over deferral; Decomplection (separate atms-retirement from tropical-fuel-introduction at the file level, but ship together for review coherence)

### 5.2 D.4 architectural reframing (rejected D.3 hybrid pivot)

**Decision**: When D.3.EC critique surfaced user-articulated Cell/Propagator/Scheduler Orthogonality concern, REFRAME the entire hybrid pivot (D.3 §10.1.A + §10.A + §10.B) toward on-network specialized cell type framework. D.3 had committed to "preserve struct-field as off-network live state + cell substrate for Phase 3C consumers" — D.4 inverted this: cell IS the live state; specialized cell mechanism declares per-cell storage strategy.
**Rationale**: D.3's hybrid pivot's empirical motivation was an EXTRAPOLATION (Pre-0 R-19 measured struct-copy GC profile; concluded "cell-write would trigger major-GC" without measuring it). The §13.6 spike was scheduled as the FALSIFICATION TEST. When the spike PASSED (6.4 ns + 0 major-GC + 0.8 ns + per-decrement 7.3 ns), it falsified the hybrid pivot's empirical foundation. Conditional commit state ("D.4 PREFERRED vs D.3 FALLBACK") was resolved by measurement, not by argument.
**Principles served**: Cell-as-Single-Source-of-Truth (D.4 preserves; D.3 inverted); Cell/Propagator/Scheduler Orthogonality (D.4 honors; D.3 had scheduler-coupled scaffolding hint via "Option E BSP-aware piggyback" historical anti-pattern)
**Discipline established (newly codified)**: *"Never extrapolate a principle-violating commit when the alternative can be directly measured."*

### 5.3 Option 13 deferred-write at round boundaries (D.4 refinement)

**Decision**: Within the D.4 framework, the BSP scheduler maintains a local-var fuel counter for the hot path; the cell is read at round entry, written at round exit (or immediately on exhaustion).
**Rationale**: Per Phase 1B friend-surfaced concern about per-fire dispatch overhead. The local-var is scheduler-internal SCRATCH (not cache of off-network state) — the cell IS still canonical. §13.6.A spike measured 2.16 ns/cycle (2.4× faster than native struct-copy 5.2 ns) — Option 13 is structurally FASTER than the pre-D.4 native implementation, not just "no regression."
**Principle served**: Orthogonality (the scheduler-side local-var doesn't leak optimization decisions to the cell layer; the cell remains canonical and scheduler-agnostic)

### 5.4 §4.6 Specialized cell type framework — composes Options A+B+C+D from D.3.EC exploration

**Decision**: Extend cell mechanism with per-cell declarations: `:tier` (storage tier — hot/warm/cold) + `:storage` (strategy — monotone-counter / general / sparse) + `:fires-on` (notification policy — any-change / threshold-crossing / monotonic-progress) + `:on-write-check` (inline predicate) + `:on-read-check` (inline predicate) + `:merge-fn` (cached).
**Rationale**: D.3.EC exploration had 5 options A-E for on-network optimization. Option E (BSP-aware piggyback) was rejected on Orthogonality grounds (scheduler-coupled). Options A+B+C+D each addressed a different concern: storage (A), threshold-as-predicate (B), fire-skip (C), tier (D). The framework composes all four — cell registration declares all properties; cell mechanism dispatches accordingly; scheduler stays uniform.
**Principles served**: Most Generalizable Interface (one framework covers 4 concerns); First-Class by Default (cell metadata is data, not magic); Decomplection (storage/policy/predicate are separable concerns); Orthogonality (all 4 declarations live at cell layer)

### 5.5 Form C cross-reference (capture-gap closure)

**Decision**: At Phase 1V Commit 8, add §9.5.A to parent design doc (2026-04-21_PPN_4C_PHASE_9_DESIGN.md) with explicit UC1/UC2/UC3 cross-reference back to addendum §9.7 + algebraic property empirical validation pointer (Commit 7b sweep artifact).
**Rationale**: Per addendum §6.5 Form C plan (decided at D.1): "Phase 3C design (§9.5 'Phase 3C deliverables' in current D.3) gets a NEW subsection with cross-reference back to this addendum's §6.5 + §9.7." Phase 3C is the first downstream consumer; without the cross-reference, the implementer might not pick up the UC enumeration.
**Principle served**: Capture-gap discipline (DEVELOPMENT_LESSONS.org codification: "every 'future phase X handles Y' claim requires capture verification or explicit capture creation at the time of the claim")

### 5.6 Option C gate re-calibration (§13.7.A) at Commit 4

**Decision**: After Item #1+#1-bis measurement landed at 3.96 ns/cycle (Var-A N=100), update §13.7 gate from ≤ 5 ns unilateral revision to ~4 ns measurement-driven (Option C). Codification graduated alongside.
**Rationale**: The original §13.7 1B-ii gate was ≤ 3 ns; unilaterally revised to ≤ 5 ns at 1B-iv close. Item #1+#1-bis measurement showed production reality is ~4 ns based on CHAMP dispatch structural floor (§13.6.A MOCK 2.16 ns + production CHAMP overhead ~1.8 ns ≈ 4 ns). Measurement-driven re-calibration is honest engineering; unilateral gate revision without measurement was a red flag.
**Principle served**: "Don't unilaterally revise gates when measurement-driven discussion is available" (newly codified at Commit 4 alongside the 3 graduated codifications)

### 5.7 Track 2I property-sweep verification (Item #3 at Phase 1V Commit 7)

**Decision**: Wire Track 2I `all-sweep-properties` to tropical-fuel SRE domain. Assert ONLY on the 3 ⭐ declared-and-swept properties (distributive + has-pseudo-complement-{rel,abs}); capture 17 BONUS swept properties as design-doc artifact (no assertions). Honest separation: assertable = "validates the declared properties at registration"; non-asserted bonus = "additional empirical evidence about structural lattice character."
**Rationale**: Avoid over-binding on un-declared properties whose result (especially REFUTE) is expected for a chain (e.g., relatively-complemented for a chain is REFUTE because chains aren't Boolean; that's not a bug, it's structurally correct).
**Principle served**: Honest framing (assertion scope = declared properties; bonus findings as captured artifact); Correct-by-construction (assertable confirmations match registration intent)

---

## 6. Lessons Learned

### 6.1 User-articulated insight can reshape design mid-resolution — codify principles immediately

The Cell/Propagator/Scheduler Orthogonality principle emerged from user critique-resolution dialogue, not from analytical exploration. Specifically: D.3.EC Group 1 batch acceptance review. The user said: *"If we're using off-network scaffolding to optimize, and that we'll need to retire with the PReduce/SH series anyways... PReduce series, we're planning on working through next, so we'd be potentially facing the same sort of concern. I'm wondering if there's an optimization path that we haven't considered, that would be more sustainable long-term."*

This reframed the entire hybrid pivot decision and led to D.4. The principle was **codified immediately** (not as a watching-list candidate) because (a) it's a foundational principle with multi-track impact (PReduce + OE + SH Series + PM 12 + PPN 4D), (b) without it, future tracks would re-derive the same conclusion (compounding architectural debt), and (c) the cost of one codification session ≈ multi-session × N tracks if re-derived per track.

**Pattern (2 data points)**: User-articulated architectural principle reshapes mid-resolution design — first instance was "memory as first-class measurement" at Pre-0 planning; second was orthogonality this session. Promotion candidate at 3rd instance.

### 6.2 The §13.6 spike is the falsification protocol — when extrapolation justifies a principle-violating commit, direct measurement IS the falsification discipline

D.3 hybrid pivot rested on Pre-0 R-19 extrapolation (struct-copy GC profile → "cell-write would trigger major-GC"). The extrapolation was REASONABLE but NEVER DIRECTLY MEASURED for the specialized cell mechanism. D.3.EC MG1 surfaced this gap; the §13.6 spike was the falsification test. Result: D.4 PASSED (6.4 ns + 0 major-GC at 100k). D.3 hybrid pivot retired before shipping.

**Codification candidate (1 data point; watching list)**: "When an architectural choice rests on extrapolation, the next round should always include a falsification test that DIRECTLY measures the alternative before locking in." Validate at 2-3 more tracks.

### 6.3 Codification claim validation IN-TRACK is methodology proof

At Commit 4, the codification "Specialized Cell Type Framework as Cross-Track Template" predicted the pattern would generalize. At Commit 5b (Item #1-quater worldview-cache-cache), the pattern was instantiated a SECOND time within the same arc and landed with **zero implementation surprises beyond audit** (F1-F9 covered all sites correctly). This validates the codification IN-TRACK rather than waiting for a future track.

**Methodology**: when codifying a cross-track template, look for opportunities to validate the prediction within the current arc. If the second instance lands clean, the codification has empirical support beyond the initial data point.

### 6.4 Empirical sweep refutes pre-impl naming-inversion concern — trust measurement over crude pre-impl conjecture

F16 mini-design predicted `has-pseudo-complement-abs` may REFUTE under Lawvere natural-order naming (bot=0 + merge=min means crude "max(a, x) = bot=0" only for a=0). Measurement at Commit 7b showed 7/7 CONFIRM at 100% non-vacuity. The sweep's check is more sophisticated than crude meet-equals-bot analysis (residuation-aware).

**Lesson**: when reasoning about declared properties, prefer empirical sweep over crude pre-impl analysis. The infrastructure (Track 2I property-sweep) has more sophisticated semantics than ad-hoc analysis suggests.

### 6.5 Domain-registration require must land at BOTH test path and tool path (post-cycle-break)

F14 retirement (Commit 6b) extracted algebraic primitives to a leaf module to break the import cycle. Post-retirement, `register-domain!` fires only when the SRE-integration module is explicitly required. F15 (test path) + F18 (tool path) both surfaced this — the test file + the standalone tool each needed `(require "../tropical-fuel.rkt")`.

**Pattern (2 data points; watching list)**: When cycle-broken SRE domain extraction lands, the registration becomes opt-in per code path. Future cycle-breaks (PM 12 + PReduce module-load infrastructure) should pro-actively audit both test path AND tool path require chains.

### 6.6 Production reality lands in uncovered ranges — decision-tree protocols need explicit fall-through ranges

§13.7 ε-measurement-driven decision tree had 3 named ranges (≤ 3 ns ratify; 3.5-4 ns escalate; no Δ → investigate). Item #1 measurement landed at 5.78 ns — in an UNCOVERED range (4-6 ns substantial-but-insufficient). Resolution: Option (d) extension to defer combined measurement to next sub-phase.

**Lesson**: gate-decision protocols should explicitly cover the "fall-through" range for measurements that don't match named ranges. The protocol's robustness improves with explicit "what if measurement is between names" handling.

### 6.7 Scaffolding-pass as distinct phase preserves design momentum without committing speculative work

D.4 scaffolding pass (commit `45181c07`) established the structure (version bump, headline subsections, status notes on superseded sections) WITHOUT committing the full content drill-down. The full §9 + §10 + §15 D.4 revisions were deferred to post-spike sessions.

**Rationale**: Doing full content NOW would be speculative work if the spike falsified D.4. The scaffolding ANNOTATED the design state without committing to either architecture's full detail. After the spike, exactly one architecture got the full revision.

**Codification candidate (1 data point; watching list)**: "Scaffolding pass as distinct phase preserves design momentum without committing speculative work." Validate when next 'conditional commit state' moment occurs.

### 6.8 Two-layer module split for cycle-breaking is reusable precedent

F14 retirement extracted pure algebraic primitives to `tropical-fuel-primitives.rkt` (leaf module; zero non-Racket deps); `tropical-fuel.rkt` re-exports for backward compat + adds SRE-integration. `propagator.rkt` requires primitives directly.

**Pattern**: Future tracks (PReduce + OE + PM 12) that introduce algebraic primitives at the network layer can follow this pattern. Codification candidate at 1 data point; promotion when next track adopts.

### 6.9 Forward-investment optimization at speculation paths is a real methodology shape

Item #1-quater (worldview-cache-cache) wins don't show in the current `bench-tropical-fuel.rkt` because the bench doesn't exercise tagged-cell-value branches (speculation paths). The optimization IS valuable; the measurement is silent. The wins land later (Phase 3A union-type ATMS branching; Phase 3C consumer paths under speculation).

**Lesson**: when an optimization targets a code path the current bench doesn't exercise, document explicitly so future maintainers don't conclude "no measured benefit = unnecessary." The measurement gap is a bench-coverage problem, not an optimization-value problem.

### 6.10 Honest framing through the entire arc

Phase 1V's discipline of TWO-COLUMN VAG (catalogue vs challenge) was applied at every sub-phase close. The catalogue→challenge transition is NEVER natural — it must be actively forced. The PIR's §6 challenges should themselves be challenged: did we catalogue or did we challenge? Re-reading sub-phase VAGs, the challenges genuinely surfaced inherited patterns (F14 inlined duplicate; F15+F18 require-missing; F16 naming-inversion concern; F18 tool path dual fix) — none were rationalized away.

---

## 7. Metrics

### 7.1 Quantitative summary

| Metric | Value | Comparison |
|---|---|---|
| Calendar duration | 26 days (04-21 → 05-17) | Longest in 10-PIR window |
| Active sessions (estimated) | ~25 sessions | vs ~8-10 typical |
| Active hours (estimated) | ~80-100 hours | vs ~30-50 typical |
| Commits in scope | ~64 | vs 18-95 range in 10-PIR window |
| Design iterations | 8 (D.1 → Pre-0 → D.2 → D.2.SC → D.3 → D.3.EC → D.4 scaffolding → D.4 canonical → Option 13 refinement) | vs 3-5 typical; matches BSP-LE Track 2/2B (13 each) |
| Critique findings closed | 29 (18 D.2.SC + 11 D.3.EC); 18 of 22 became MOOT under D.4 reframing | New pattern: architectural reframing dissolves prior critique findings |
| Production code delta | net **−650 LoC** (−2649 retirement + ~+2000 new) | NEGATIVE net production code is unusual |
| Test code delta | **+310 tests** (peaked at 8299; dropped to 8209 post-1A retirement; back to 8224 at close) | |
| Documentation delta | **+~3500 lines** across design + dailies + research | ~3:1 docs:code ratio |
| Suite wall time delta | **−4.6s** (119.3s → 114.7s) despite +310 tests | -28s alone from 1C-iv-b dual-write elimination |
| Codifications graduated | **4** (3 at Commit 4 + Orthogonality at `6a628bc7`) | vs 0-2 typical |
| Watching-list codification candidates | **~14** surfaced across the arc | High; reflects unforeseen architectural delivery |
| Bugs introduced | ~5 (most resolved within same sub-phase) | Low; consistent with high design-discipline arc (5.7:1 design:impl) |

### 7.2 Performance results — Phase 1V optimizations

| Measurement | Value | vs Baseline |
|---|---|---|
| Cell-write fast path (Var-A N=100) | **4.52 ns/cycle** at close | −47.9% vs pre-Item-#1 7.56 ns |
| Cell-write (Var-A N=1000) | **1.40 ns/cycle** | Under ≤ 3 ns original target |
| Cell-read | **10.9 ns/call** | −85% vs pre-Item-#1-bis 74.3 ns |
| Check-site | **10.7 ns/call** | −86% vs pre-Item-#1-bis 76.9 ns |
| GC at 100k decrements | **0 major-GC** | R3 baseline structurally preserved |
| Memory at 100k decrements (specialized cell) | 1.1 KB alloc / 0.0 KB retain | vs Pre-0 A7.3 6251 KB → **5700× improvement** |
| §13.6 W1+ specialized cell-write with dispatch | 6.4 ns/call | ~4× under target ≤ 30 ns |
| §13.6.A Option 13 amortized (MOCK) | 2.16 ns/cycle | 2.4× faster than native struct-copy 5.2 ns |
| C1+C2+C3 algebraic axioms (1B-iii) | ALL PASS | tropical-fuel quantale empirically validated at registration |
| Track 2I sweep F11 critical gate (Commit 7b) | 3 ⭐ properties CONFIRM at 100% | Variety placement: SD/Modular/Distributive/Heyting/Whitman ✓; Stone/Boolean ✗ (chain prediction) |

### 7.3 LoC churn per phase

| Phase | Production LoC | Test LoC | Doc LoC | Total |
|---|---|---|---|---|
| Stage 1+2 (research + audits) | 0 | 0 | +1000 | +1000 |
| D.1 draft + Pre-0 plan | 0 | +1183 | +2351 | +3534 |
| D.2.SC + D.2 revise + D.3 batch | 0 | 0 | +1352 | +1352 |
| D.3.EC + orthogonality + D.4 canon + Option 13 | 0 | 0 (throwaway spikes ~+1143) | +3225 | +3225 (+1143 throwaway) |
| Phase 1B (1B-i → 1B-iv) | ~+450 | ~+800 | ~+533 | ~+1783 |
| Phase 1A-iii-b (atms.rkt retirement) | **−1606 / +96** | (incl. above) | +321 | **net −1189** |
| Phase 1A-iii-c (surface AST 14-file retirement) | **−1143 / +5** | (incl. above) | +395 | **net −743** |
| Phase 1C (1C-i → 1C-vi) | net **−550 prod** | +750 | +2100 | +2300 |
| Phase 1V Commits 1-8 | ~+1100 / −150 | +200 | +2300 | +3450 |

---

## 8. What's Next

### 8.1 Immediate (post-Phase-1 dependencies)

| Track | Phase 1V Deliverable Consumed | Specific Integration |
|---|---|---|
| **Phase 1E** (parent track) | — | `that-*` storage unification; 5 carry-forward Q1-Q5; conversational Stage 4 mini-design |
| **Phase 3C** (parent track, future addendum) | Form C cross-reference (§9.5.A) | UC1/UC2/UC3 proof-of-concept; consumes `tropical-left-residual` + algebraic property declarations (empirically validated via §11.X.6.1) |
| **PReduce Track 1** (e-class cell substrate) | Specialized cell type framework (§4.6) | E-class cells adopt `:tier 'hot` + specialized storage; hashcons IS cell-id-from-structural-hash. **Gates on Phase 1B + Track 0.1 closure** |
| **PReduce Track 4** (cost-guided extraction) | Tropical residuation operator | **Direct consumer** of `tropical-fuel.rkt` residuation + budget cell + threshold check |
| **OE Track 0/1/2** | First production landing IS this addendum | Multi-dimensional cost extensions (MemoryCostQ, MessageCountQ) inherit §11.X.6.1 atomic numeric domain wiring pattern + §4.6 specialized cell framework |

### 8.2 Medium-term

| Track | Phase 1V Deliverable Consumed | Specific Integration |
|---|---|---|
| **PM Track 12** (parameters → cells for module loading) | Specialized cell type framework + Orthogonality | 23+ macros.rkt registries (schema, ctor, type-meta, etc.) + module-registry + per-elab stores → on-network specialized cells with `:tier 'hot` + write-through. PM 12 is "longitudinal pattern 7 architectural response" per MASTER_ROADMAP §817 |
| **PPN Track 4D** (Attribute Grammar Substrate Unification) | Specialized cell type framework | Grammar rule registry co-locates with PM 12 specialized cells. Attribute facets get `:tier 'hot` registrations |
| **PReduce Track 5** (persistence) | `.pnet` round-trip of cell-meta + specialized cell framework | Cross-session caching via specialized cells with persistence semantics — content-addressed e-class storage |
| **SH Track 1** (`.pnet` network-as-value) | Specialized cell metadata becomes part of `.pnet` IR | Cell-meta fields (`:tier` + `:storage` + `:fires-on` + `:on-write-check` + `:on-read-check` + `:merge-fn`) are serializable per-cell metadata |

### 8.3 Long-term (post-PReduce / SH delivery)

| Track | Phase 1V Deliverable Consumed | Specific Integration |
|---|---|---|
| **SH Track 4** (production LLVM substrate) | Cell/Propagator/Scheduler Orthogonality principle | **THE LOAD-BEARING ENABLER for thin Zig scheduler** — optimization at cell layer means Zig scheduler doesn't need per-cell branching. `:storage 'monotone-counter` maps cleanly to LLVM `atomicrmw add` with `monotonic` ordering |
| **SH Track 6** (runtime services GC) | `:on-write-check` cell-meta + zero major-GC structural guarantee | GC-friendly behavior structurally guaranteed for monotone-counter cells (Phase 1V's §13.6 W3 empirically demonstrated) |
| **PPN Track 9** (self-describing serialization) | `.pnet` extension framework | Specialized cell metadata as part of serialization format; grammar-based `.pnet` format |
| **Multi-quantale composition implementation** (Phase 3C UC2 + future) | NTT model from §4.2 + quantaloid forward-compat | When 3+ quantale instances ship, quantale-of-bridges composition extends without breaking type-cost-bridge interface |

### 8.4 9 Open questions future tracks will face

These are concrete integration questions that future tracks will need to resolve. None block Phase 1 close; all flagged for the right-phase mini-design.

1. **`.pnet` round-trip of `specialized-cell-meta`** — cell-id stays; does the meta declaration ride along, or get re-derived from cell-id-to-domain mapping? (SH Track 1 + PReduce 0.3)
2. **Submodule-scope as cell-space primitive** — does Orthogonality hold for SCOPE-BOUNDED cells (per-submodule cell-id space)? (PM Track 12)
3. **`:fires-on 'threshold-crossing` in Zig comptime** — per-tag-batch generator vs inlined static branch? (SH Track 4)
4. **Merge-fn cache survival in Zig** — compile-time table lookup vs runtime atomic? (SH Track 4)
5. **Multi-cost-currency per-cell predicate composition** — does framework support per-cell predicate composition without runtime overhead? (OE Track 1, PReduce 4)
6. **E-class merge with partial information** — `:on-write-check` predicate vs stratum boundary? (PReduce Track 1)
7. **Attribute-grammar rule registry as specialized-cell registry** — per-facet `:tier 'hot` vs shared attribute-record compound cell? (PPN 4D)
8. **Worldview-cache-cache scaling under nested speculation** — does 3-instance pattern scale to depth >5? (PReduce Track 6)
9. **Cross-session e-class persistence at scale** — millions of e-classes; does cell-meta serialize at acceptable size? (PReduce Track 5)

---

## 9. Key Files

### 9.1 NEW modules

| File | Role |
|---|---|
| `racket/prologos/tropical-fuel.rkt` | Tropical quantale SRE-integration (124 LoC); registers domain with 11 declared properties + merge-fn + meet-fn |
| `racket/prologos/tropical-fuel-primitives.rkt` | Pure algebraic primitives leaf module (106 LoC; zero non-Racket deps); cycle-safe; re-exported by tropical-fuel.rkt |
| `racket/prologos/specialized-cells.rkt` | Public convenience layer for specialized cell registration; `make-monotone-counter-meta`, `make-cold-general-meta` constructors for future tracks |
| `racket/prologos/tests/test-tropical-fuel.rkt` | 56 tests across C1-C5 axioms + boundary cases + tropical-fuel-counter-parity behavioral contract |
| `racket/prologos/tests/test-specialized-cells.rkt` | 13 tests for specialized cell framework + cache consistency |
| `racket/prologos/benchmarks/micro/bench-tropical-fuel.rkt` | M10/M11/M12 algebra primitives + C-A7.x decrement scaling + Var-A/B amortized + R4 layout + GC profile |
| `racket/prologos/data/benchmarks/tropical-fuel-phase9-sweep-2026-05-17.txt` | Track 2I property-sweep findings (variety placement + 20-property detail) |

### 9.2 MODIFIED modules

| File | Modification |
|---|---|
| `racket/prologos/propagator.rkt` | `prop-net-warm` struct 2→5 fields (+ under-speculation? + fuel-cell-cache + worldview-cache-cache); `specialized-cell-meta` struct (6 fields); `net-cell-write` fast-path dispatch; well-known direct-ref cache pattern at 8 WT-* sites; fuel-cell-id (11) + fuel-budget-cell-id (12) constants; F14 retirement of `tropical-fuel-merge-for-cell` inlined duplicate |
| `racket/prologos/atms.rkt` | Tier 2 retirement: 13 deprecated functions + struct + atms-believed removed (`fef06994`) |
| `racket/prologos/syntax.rkt` | 14 surface ATMS AST structs retired (`d9c91f38`) |
| Multiple 14-file AST pipeline | Tier 3 surface ATMS AST retirement: substitution.rkt, zonk.rkt, reduction.rkt, pretty-print.rkt, qtt.rkt, typing-core.rkt, surface-syntax.rkt, parser.rkt, elaborator.rkt, etc. |
| `racket/prologos/tools/run-phase9-sweep.rkt` | NEW tropical-fuel entry in sweep-config + `(require "../tropical-fuel.rkt")` (F18) |
| `racket/prologos/tests/test-sre-sd-properties.rkt` | NEW tropical-fuel section + 5 test-cases + `(require "../tropical-fuel.rkt")` (F15) |
| `racket/prologos/tests/test-elaboration-parity.rkt` | NEW Phase 1C-vi tropical-fuel-counter-parity §15 axis (D.4 reframed) |

### 9.3 Principles + rules documents

| File | Update |
|---|---|
| `docs/tracking/principles/DESIGN_PRINCIPLES.org` | NEW § Cell/Propagator/Scheduler Orthogonality (top-level principle); NEW § Specialized Cell Type Framework as Cross-Track Template |
| `docs/tracking/principles/DEVELOPMENT_LESSONS.org` | NEW § Cell/Propagator/Scheduler Orthogonality (codified lesson); NEW § Cache Projection Should Model Read-Side + Write-Side Independently; NEW § Cache Write-Through With Persistent CHAMP |
| `.claude/rules/on-network.md` | Cross-reference to Orthogonality + scheduler-coupled-optimization anti-pattern |
| `.claude/rules/propagator-design.md` | Cross-reference to Orthogonality + rejected Option E historical example |
| `docs/tracking/MASTER_ROADMAP.org` | OE Series caveat refined to Orthogonality inheritance discipline |
| `docs/tracking/DEFERRED.md` | Hybrid pivot retirement entry (closed as superseded by D.4) |
| `docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md` | NEW §9.5.A Form C cross-reference (Phase 1V Commit 8) |

### 9.4 Tracking + design documents

| File | Role |
|---|---|
| `docs/tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md` | Main design doc (5489+ lines; D.1→D.4 trajectory + Phase 1V close subsections §11.X through §11.X.7) |
| `docs/tracking/2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md` | Pre-0 plan (38 tests across 8 tiers; 22 design-affecting findings) |
| `docs/tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md` | D.2.SC (18 findings via P/R/M/S) |
| `docs/tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_EXTERNAL_CRITIQUE.md` | D.3.EC (11 findings via fresh CL/MG/SP/OS/TD/AP/TS/EX/MB lenses) |
| `docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md` | Stage 1 research (~1000 lines; 12 sections) |
| `docs/tracking/standups/2026-04-26_dailies.md` + `docs/tracking/standups/2026-05-13_dailies.md` | Decision log + surprise journal across the arc |
| Various handoff documents | Cross-session context preservation; especially `2026-05-14_TROPICAL_D4_REFRAMING_HANDOFF.md` |

---

## 10. Lessons Distilled

Per POST_IMPLEMENTATION_REVIEW.org § 10 MANDATORY:

| Lesson | Distilled To | Status |
|---|---|---|
| Cell/Propagator/Scheduler Orthogonality principle | DESIGN_PRINCIPLES.org § Cell / Propagator / Scheduler Orthogonality + .claude/rules/on-network.md + .claude/rules/propagator-design.md | ✅ DONE (`6a628bc7`) |
| Specialized Cell Type Framework as Cross-Track Template | DESIGN_PRINCIPLES.org § Specialized Cell Type Framework as Cross-Track Template | ✅ DONE (`90c271fa`) |
| Cache Projection Should Model Read-Side + Write-Side Independently | DEVELOPMENT_LESSONS.org § Cache Projection Read/Write Independently | ✅ DONE (`90c271fa`) |
| Cache Write-Through With Persistent CHAMP — explicit audit list IS the drift mitigation | DEVELOPMENT_LESSONS.org § Cache Write-Through With Persistent CHAMP | ✅ DONE (`90c271fa`) |
| "Never extrapolate a principle-violating commit when the alternative can be directly measured" | DEVELOPMENT_LESSONS.org candidate | ⬜ Pending — promote in next PIR refinement pass (1 data point; validate with 2-3 more tracks) |
| User-articulated insight reshapes design mid-resolution | DEVELOPMENT_LESSONS.org candidate | ⬜ Watching list (2 data points: memory as first-class earlier; Orthogonality this arc); promotion at 3rd instance |
| Codification claim validation IN-TRACK is methodology proof | DESIGN_METHODOLOGY.org candidate | ⬜ Watching list (1 data point); promotion when methodology pattern reaches 2-3 instances |
| Empirical sweep refutes pre-impl naming-inversion concern | DEVELOPMENT_LESSONS.org candidate | ⬜ Watching list (1 data point); promotion when measurement-refutes-conjecture pattern reaches 2-3 instances |
| Domain-registration require must land at BOTH test path and tool path (cycle-broken SRE) | .claude/rules/pipeline.md candidate | ⬜ Watching list (2 data points: F15 + F18 same commit); relevant for future cycle-broken SRE domain wiring; promotion at 3rd cycle-break instance |
| Production reality lands in uncovered ranges — decision-tree protocols need explicit fall-through ranges | .claude/rules/workflow.md candidate | ⬜ Watching list (1 data point at §13.7 / Option (d)); promotion when next gate-decision-tree fall-through occurs |
| Scaffolding-pass as distinct phase preserves design momentum | DESIGN_METHODOLOGY.org candidate | ⬜ Watching list (1 data point at D.4 scaffolding pass `45181c07`); promotion when next conditional-commit-state moment occurs |
| Two-layer module split for cycle-breaking | .claude/rules/pipeline.md candidate | ⬜ Watching list (1 data point at F14); promotion when next track adopts |
| Forward-investment optimization at speculation paths — bench-coverage gap is not optimization-value problem | DEVELOPMENT_LESSONS.org candidate | ⬜ Watching list (1 data point at Item #1-quater); promotion when next "silent measurement" optimization lands |
| Atomic numeric domain wiring is FIRST instance — precedent for OE/PReduce cost dimensions | DEVELOPMENT_LESSONS.org candidate | ⬜ Watching list (1 data point at §11.X.6.1); promotion when OE Track 0 wires its first cost domain |
| Post-recompile linklet-staleness across batch-worker .zo — force-rerun resolves | .claude/rules/testing.md candidate | ⬜ Watching list (1 data point at Phase 1V Commit 8); promotion at 3rd instance |
| `+inf.0`/NaN edge cases in tropical algebra surface at residuation boundary | DEVELOPMENT_LESSONS.org candidate | ⬜ Watching list (1 data point at F12 mini-design + F16 refuted measurement); promotion when next tropical-quantale-flavored domain lands |

**Meta-lesson elevated (per §10 mandate)**:

> **The unforeseen architectural delivery (specialized cell type framework + Cell/Propagator/Scheduler Orthogonality) is more architecturally significant than the foreseen one (tropical quantale primitive). Phase 1V's discipline of TWO-COLUMN VAG + user-articulated principle codification + immediate cross-track template promotion enabled the unforeseen delivery to become a load-bearing production-validated framework — not just a research note.**

The methodology takeaway: when user critique-resolution surfaces a principle with multi-track impact, **codify immediately** (don't put it on the watching list). The cost of one codification session ≈ multi-session × N tracks if re-derived per track. Phase 1V's Commit 4 graduated 4 codifications simultaneously — this is a methodology pattern worth replicating.

---

## 11. Where We Got Lucky

Per POST_IMPLEMENTATION_REVIEW.org § "Where We Got Lucky": what could have gone worse but didn't?

1. **The §13.6 spike could have FAILED** (D.3 hybrid pivot would have shipped; the architectural pivot would have retired; we'd have lived with off-network struct-field as live state). The spike PASSED with W1+ 6.4 ns (4× under target). If specialized-cell-meta dispatch had had hidden allocation cost we didn't anticipate, the entire D.4 reframing would have been falsified.

2. **F16 naming-inversion concern could have MATERIALIZED** as REFUTE on `has-pseudo-complement-abs`, which would have invalidated the tropical-fuel registration's `'has-pseudo-complement prop-confirmed` declaration (F11 critical halt-and-investigate gate). Instead, the sweep's check is more sophisticated than crude pre-impl analysis suggested — CONFIRM at 100% non-vacuity. We were lucky that the infrastructure (Track 2I property-sweep) had quantale-aware semantics built in.

3. **Item #1 + Item #1-bis combined could have failed §13.7 gate**. The pre-impl projection was ~0.3 ns/cycle savings for Item #1-bis alone; actual was −1.82 ns/cycle (~6× projected). The combined recovery (−47.6% from pre-Item-#1 baseline) was substantially better than projection. If projection had held, Item #1-ter would have been triggered (additional implementation work).

4. **F18 surfaced at impl-time, not at production deploy**. F15 caught the test path require; F18 caught the tool path require at first sweep CLI run (pre-final-suite). If F18 had surfaced post-deploy (e.g., when someone tried to use the sweep tool to verify a different domain), it would have been an embarrassing miss.

5. **Phase 1V Commit 8 first full-suite run had a stale-linklet failure** (test-facet-sre-registration). Individual test passed; batch hit `.zo` staleness from recompile cycle. Targeted recompile + force-rerun resolved cleanly — but if the failure had been a real semantic regression rather than linklet staleness, we'd have been stalled.

6. **The Cell/Propagator/Scheduler Orthogonality principle wasn't on anyone's radar pre-D.3.EC**. If the user had accepted D.3 hybrid pivot at face value, we'd have shipped a scaffolded architecture that future tracks would inherit as the de-facto template. The orthogonality principle surfacing AT THIS MOMENT (vs at PReduce Track 1 design time, when retrofit would be expensive) was timing luck.

7. **Pre-0's 22 design-affecting findings** were comprehensive enough that no major design surprise emerged at implementation time. Most "surprises" at impl-time were re-audit findings (F15-F18) that fell out of the discipline pattern, not architectural surprises. The 17-day design-and-critique arc (04-26 → 05-14) bought us the implementation-cleanliness we saw at Phase 1B/1C/1V (3 days of relatively-clean implementation).

---

## 12. What's Surprised Us

1. **The unforeseen delivery is more architecturally significant than the foreseen one**. Phase 1V's specialized cell framework + Orthogonality principle enables 5+ tracks; the tropical quantale primitive enables ~2 known consumers. We started building "the first tropical quantale instance"; we landed "the cross-track cell-layer template + the architectural discipline that makes thin schedulers viable."

2. **Codification claim validated IN-TRACK** at Commit 5b. The Commit 4 codification "Specialized Cell Type Framework as Cross-Track Template" made a prediction; Commit 5b validated it with zero implementation surprises beyond audit. We rarely get to validate a codification's prediction within the same arc.

3. **F16 naming-inversion concern REFUTED by measurement**. Mini-design predicted has-pseudo-complement-abs may REFUTE; measurement showed CONFIRM at 100%. The sweep's check is more sophisticated than my crude pre-impl analysis modeled.

4. **Item #1-bis saves 6× projected** at production-realistic N=100 (−1.82 ns/cycle vs ~0.3 ns projection). Cause: the projection accounted for write-side savings only; the read-side optimization (BSP convergence check fires every iteration) was unmodeled. Codification: "Cache Projection Should Model Read-Side + Write-Side Independently" (graduated at Commit 4).

5. **Wall time IMPROVED despite +310 tests** (119.3s → 114.7s = −4.6s). −28s alone from 1C-iv-b dual-write elimination. We expected ~+10-20s for the tropical-fuel test additions; we got NET FASTER.

6. **18 of 22 D.2.SC+D.3.EC findings became MOOT under D.4 reframing**. The architectural reframing eliminated the underlying concerns rather than addressing them piecemeal. We've never had a critique pattern where 80%+ of findings dissolve at a single architectural pivot.

7. **The §13.7 decision-tree gap** (Item #1 5.78 ns landed in an uncovered range between named ranges). Methodology surprise — we thought the 3 ranges (≤3 ratify / 3.5-4 escalate / ~no Δ investigate) covered the space; production reality found the gap.

8. **F18 (require missing at tool path)** was NOT predicted at §11.X.6 mini-design (only F15 was named). The same issue surfaced in a different code path at impl time. Codification: "Domain-registration require must land at BOTH test path and tool path."

9. **The "propagator network IS the compiler" framing was already in research notes** (April 30 + May 2 deep research) but Phase 1V is when it became actionable. The specialized cell framework + Orthogonality principle is what makes "thin scheduler" viable; the research notes had the framing but lacked the framework.

---

## 13. What Assumptions Were Wrong

Not "what broke" — what did we BELIEVE about the problem space that turned out to be false?

1. **D.3 hybrid pivot was "principled decomplection"**. We claimed (and committed at `2a4d938c`) that preserving struct-field as off-network live state + cell substrate for Phase 3C consumers was "principled decomplection" of fast-path optimization from architectural substrate. The user's D.3.EC critique surfaced this as Cell-as-Single-Source-of-Truth INVERSION. The decomplection framing was scaffolding rationalization. D.4 reframing acknowledged this explicitly.

2. **The empirical motivation for D.3 (Pre-0 R-19) justified the architectural commit**. The R-19 finding ("zero major-GC during 100k struct-copy decrements") was used to EXTRAPOLATE "cell-write at the same rate would trigger major-GC pressure." The extrapolation was REASONABLE but UNTESTED. The §13.6 spike directly measured the alternative and falsified the extrapolation. Codified discipline: "Never extrapolate a principle-violating commit when the alternative can be directly measured."

3. **All 17 sweep properties would be relevant for tropical fuel** (per mini-design F1 said 17; reality was 20). Phase 11-15 had added 5 properties since the mini-design reference point. F17 corrected this at re-audit — but the discipline failure was the mini-design's reference to "17 properties" without re-grepping at fresh HEAD.

4. **The sweep's `has-pseudo-complement-abs` check would refute under naming inversion** (F16 mini-design concern). My crude pre-impl analysis (max(a, x) = bot=0 only for a=0) didn't model the sweep's actual quantale-aware check. The sweep is more sophisticated than crude analysis suggested.

5. **Tropical fuel's algebraic property declarations were fully validated by C1+C2+C3 axioms** (at 1B-iii). The C-series axioms are NECESSARY but not SUFFICIENT for the broader algebraic property declarations (distributive, modular, Heyting, etc.). Track 2I property-sweep at Phase 1V Commit 7 provided the additional empirical evidence. We were treating C1+C2+C3 as a complete validation; it was a partial one. Discipline: declared SRE properties need empirical sweep verification.

6. **Phase 1V was just "atomic close + minor optimizations"**. The §11.X mini-design at Commit 1 said 5 commits. Phase 1V grew to 8 commits as Items #1 / #1-bis / #1-quater / F14 retirement / Option C re-calibration / Item #3 each surfaced. The methodology was robust enough to absorb the growth (Option (d) discipline; conditional commits), but the initial scoping was optimistic.

7. **The optimization claim of "amortized per-cycle cost ≤ 3 ns" (§13.7 1B-ii original gate)** was based on §13.6.A MOCK measurements (2.16 ns). Production reality has irreducible CHAMP cell-meta dispatch overhead ~1.8 ns; the production floor is ~4 ns. Option C re-calibration (Commit 4) updated the gate to reflect this; the original unilateral revision to ≤ 5 ns was correct in spirit but lacked the measurement-driven discussion that Option C provides.

---

## 14. What We Learned About the Problem Itself

Implementation always teaches things that research and design cannot. Does our understanding of the problem domain differ from what we started with?

1. **The "tropical quantale" framing is one instance of "specialized cell types"**. We thought we were building the tropical quantale's first production instance; we ended up building the framework for ALL future cost-optimization quantales (MemoryCostQ, MessageCountQ, multi-cost-currency tracking). The tropical quantale's structural shape (atomic numeric domain, ZERO ctor-descs, total-order chain) is the simplest case in a family of specialized cell types.

2. **Algebraic property validation has two distinct dimensions**: (a) **structural** axioms verified at construction (C1+C2+C3 at 1B-iii: commutativity, associativity, idempotence; algebraic identities) vs (b) **empirical** property declarations verified by sweep (Track 2I at Phase 1V Commit 7: distributive, has-pseudo-complement-{rel,abs}, etc.; declared SRE properties). Both are necessary; neither is sufficient alone.

3. **Cell-as-canonical (D.4) is a stronger architectural commitment than we initially understood**. D.1 framing was "cell substrate alongside fast-path counter." D.3 explicitly preserved the struct field + macro. D.4 retires them entirely. The architectural discipline "cell IS the live state" turned out to be much more enabling than "cell is one of two source-of-truth options" — it forced the §4.6 framework to be sufficient for hot-path use.

4. **The Pre-0 phase's value is partly in measurement, partly in surfacing UNCOVERED questions**. Pre-0 R-19 wasn't just a measurement — it was a SURFACED QUESTION ("will cell-write at the same rate triggers major-GC?") that the D.4 reframing was the only viable response to. The 22 design-affecting findings from Pre-0 are not 22 datapoints; they are 22 surfaced architectural questions.

5. **The Track 2I property-sweep infrastructure is more powerful than its origin track suggested**. It was built for SRE Track 2I's SD∨/SD∧ checks; Phase 1V wired it to verify ANY domain's declared algebraic properties empirically. The infrastructure is genuinely cross-track reusable. Codification candidate (1 data point at §11.X.6.1; promotion when OE/PReduce wire their first domains).

6. **The "propagator network IS the compiler" framing requires the specialized cell framework as its enabling infrastructure**. Pre-Phase-1V research notes had the framing; Phase 1V delivered the framework that makes it actionable. Without per-cell storage strategy declarations + scheduler-neutral fire-on policy + Orthogonality discipline, the framing is research aspiration. With them, the framing is engineering trajectory.

7. **Multi-iteration design discipline (8 iterations across 17 days) correlates with implementation cleanliness (3 days; ~5 bugs)**. The 5.7:1 design:impl ratio is high but the resulting implementation arc was the cleanest in recent memory. The longitudinal pattern P-B (design:implementation ratio + iteration count vs bug count) held strongly.

---

## 15. Are We Solving the Right Problem?

Argyris's double-loop learning — questioning the goals themselves, not just the methods.

**Original goal** (D.1, 2026-04-26): *"This will be the first instantiation of optimization as tropical quantales in our architecture that it deserves the most careful considerations that we can pay it its dues."*

**What we actually built**: a cross-track CELL-LAYER TEMPLATE + the architectural discipline that makes thin schedulers viable + the empirical validation of the first specialized cell type framework + 4 graduated codifications.

**Is the framing correct?** The framing "first tropical quantale instance" was correct but incomplete. The work was always going to deliver more than that (per addendum §6.6 OE Series row: "First production landing establishes pattern"). What was unforeseen was that the PATTERN would be the SPECIALIZED CELL FRAMEWORK + ORTHOGONALITY DISCIPLINE rather than just the tropical quantale algebraic shape.

**Should we have scoped differently?** No. The discovery emerged from the work — specifically from D.3.EC critique resolution + user-articulated principle. Pre-defining the scope would have required pre-having the insight. The methodology (Pre-0 → Stage 3 critique rounds → external critique → user dialogue → architectural reframing → spike-falsification → implementation → in-track codification validation) is what enabled the discovery.

**Open architectural question**: Should "the propagator network IS the compiler" be a CODIFIED principle in DESIGN_PRINCIPLES.org? Per user (Q3 in pre-PIR discussion): *"This is a known-known by me the developer at this point. Not sure adding more context adds anything meaningful."* The framing remains research-aspirational + operationally-engineered-piece-by-piece. The Orthogonality principle operationalizes part of it; the Specialized Cell Type Framework as Cross-Track Template operationalizes another part. The full framing will become a codified principle when the third operational piece lands (likely at SH Track 1 or PReduce Track 1).

---

## 16. Longitudinal Survey (10 Most Recent PIRs)

Per POST_IMPLEMENTATION_REVIEW.org § 16 mandate. Cross-reference with the 10 most recent PIRs (not 2-3). Patterns spanning 3+ are codification-ready; 5+ are architectural.

### 16.1 Longitudinal table

| # | Track | Date | Duration | Commits | Test Δ | Code Δ | Design Iterations | Bugs |
|---|---|---|---|---|---|---|---|---|
| **0** | **PPN 4C Tropical Addendum** (this PIR) | **2026-04-21 → 2026-05-17** | **26d / ~25 sess / ~80-100h** | **~64** | **7914→8224 (+310)** | **~−650 prod / +310 test / +3500 doc** | **8 (D.1→D.4 + Option 13)** | **~5** |
| 1 | BSP-LE Track 2B | 2026-04-16 | 5.4d / ~19.7h / 8 sess | 43 | 7529→7765 (+236) | +4348/−489 across 28 files | D.1–D.13 (13) | 14 |
| 2 | BSP-LE Track 2 | 2026-04-10 | ~35h / 4 sess | ~95 | 7609→7745 (+136) | ~2500 LoC | D.1–D.13 (13) | 7 |
| 3 | PPN Track 4B | 2026-04-07 | ~17h / 3 sess | 47 | 7578→7609 (+31) | +2117/−281 | D.1–D.2 (2) | 9 |
| 4 | PPN Track 4 | 2026-04-04 | ~3 sess | 69 | 7551→7574 (+23) | ~+925/−1400 | D.1–D.4 (4) | 6 |
| 5 | SRE Track 2D | 2026-04-03 | ~11h / 1 sess | 18 | 7526→7551 (+25) | ~750 + 318 test | D.1–D.5 (5) | 2 |
| 6 | SRE Track 2H | 2026-04-03 | ~14h / 2 sess | 30 | 7491→7526 (+35) | ~500 + 120 new | D.1–D.5 (5) | 3 |
| 7 | PPN Track 3 | 2026-04-02 | ~30h / 2 sess | 70+ | 7491→7491 (+0) | ~1400 added | D.1–D.5b + §11 + §12 (7) | 6+ |
| 8 | SRE Track 2G | 2026-03-30 | ~10h / 1 sess | 11 | 7459→7491 (+32) | ~440 + 105 + 241 | D.1–D.3 + NTT (4) | 3 |
| 9 | PPN Track 2B | 2026-03-30 | ~10h / 1 sess | 18 | 7459→7454 (−5) | ~600/−100 | D.1–D.3b + §11 + §12 (6+) | 3 |
| 10 | PPN Track 2 | 2026-03-29 | ~8.5h / 1 sess | 68 | 7529→7529 (+0) | +3258/−8 | D.1–D.3 + NTT (6) | 4 |

**Phase 1V positioning**: longest duration, most active hours, second-most commits (after BSP-LE Track 2 at 95). Iteration count (8) is below BSP-LE 2/2B (13 each) but above other tracks (2-7).

### 16.2 Cross-PIR patterns relevant to Phase 1V

#### Patterns spanning 5+ PIRs (architectural; demand systemic response)

- **P-A: Pre-0 benchmarks reshape design (10/10)**. Phase 1V's §13.6 spike was THE falsification test for D.4 reframing. The 22 Pre-0 findings shaped the entire D.2 → D.3 → D.4 trajectory. **Phase 1V: STRONG MATCH** — pattern fully exhibited.

- **P-B: Design:implementation ratio inversely correlates with bug count (10/10)**. Phase 1V at 5.7:1 design:impl is the HIGHEST in the window; bug count ~5 is consistent with the inverse correlation (tracks at 0.3-0.6:1 average 6-9 bugs). **Phase 1V: STRONG MATCH** — extends the pattern.

- **P-C: Critique rounds prevent drift (9/10)**. Phase 1V had 3 distinct critique rounds (D.2.SC + D.3.EC + user-articulated orthogonality reframing). Each surfaced findings that would have been mid-implementation pivots. **Phase 1V: STRONG MATCH**.

- **P-D: Wrong lattice/merge assumptions (7/10)**. Phase 1V's F16 naming-inversion concern was a wrong assumption ABOUT THE SWEEP'S CHECK; the assumption was refuted by measurement. Phase 1V is a partial match (the assumption was refuted, not materialized as bug). **Phase 1V: PARTIAL MATCH** — preventive case.

- **P-E: Two-context boundary bugs (6/10)**. Phase 1V's F15+F18 dual-path require missing IS a two-context boundary issue (test path + tool path each independently). **Phase 1V: STRONG MATCH** — new data point that demonstrates the architectural pattern persists despite codification.

- **P-F: Integration phases dominate time (7/10)**. Phase 1V's integration was unusual — 8 design iterations + Pre-0 + critique consumed ~17 days BEFORE implementation began. The implementation phase was actually FAST (3 days for 4 sub-phases + 8 1V commits). **Phase 1V: INVERTED PATTERN** — design dominated time, integration was fast.

#### Patterns spanning 3-4 PIRs (codification-ready)

- **P-G: Validated ≠ Deployed (4/10)**. Phase 1V's D.4 vs D.3 conditional commit state had this risk built in — the §13.6 spike was the falsification protocol that ensured the architecture was DEPLOYED, not just validated. **Phase 1V: PATTERN AVOIDED** — disciplined response.

- **P-H: Belt-and-suspenders masks bugs (3/10)**. Phase 1V explicitly REJECTED the D.3 hybrid pivot's belt-and-suspenders pattern (cell substrate alongside off-network struct-field). The orthogonality principle CODIFIES the discipline against this. **Phase 1V: PATTERN CODIFIED** — addressed architecturally.

- **P-I: User scope challenges improve designs (4/10)**. Phase 1V's D.4 reframing was triggered by user-articulated orthogonality concern. Without the user challenge, D.3 hybrid pivot would have shipped. **Phase 1V: STRONG MATCH** — user challenge was load-bearing.

- **P-J: +0 suite test delta (4/10 initially)**. Phase 1V is +310 — strongly breaks the pattern. Dedicated test phase (Phase 1V Commit 7 SRE property-sweep verification) explicitly part of close. **Phase 1V: PATTERN BROKEN** — methodology improvement.

- **P-K: Side-effect coupling is on-network blocker (4/10)**. Phase 1V's 1C-iv-b (cell IS sole live state at `00f7ce05`) explicitly retired the side-effect-coupling pattern for fuel tracking. **Phase 1V: PATTERN ADDRESSED** for this domain; persists in other domains (meta-resolution boundary remains).

- **P-L: Microbench claim verification load-bearing (3+/10)**. Phase 1V's §13.7 Option C re-calibration is a NEW data point — measurement-driven gate discussion after Item #1 partial recovery + Item #1-bis gate-met. **Phase 1V: NEW DATA POINT** — pattern extends.

#### Patterns spanning 2 PIRs (watching list)

- **W-3: Module Theory direct sum has two realizations (tagged-shared-carrier > separate-cells-with-bridges)** — Phase 1V's multi-quantale composition NTT model (§4.2) is the THIRD realization of this pattern: TypeFacetQ + TropicalFuelQ as independent Q-modules with Galois bridge. **Phase 1V: 3rd DATA POINT** — pattern reaching codification threshold.

- **W-5: PIR methodology checklist not followed** — Phase 1V's PIR (this document) is being written WITH the methodology checklist in hand (per Stage 4 mandate). Validates the codification.

### 16.3 Top 5 PIRs to cross-reference

Per Agent 1 longitudinal survey ranked by pattern overlap:

1. **BSP-LE Track 2B** (2026-04-16) — most recent + most architecturally comparable. Match points:
   - Mid-track design mantra introduction → architectural redesign of inherited code (Phase R)
   - Microbench verification load-bearing for perf claim (Tier 1 62×)
   - Belt-and-suspenders surfacing real bug (Phase 5a)
   - 13 design iterations + iteration-weighted vs calendar D:I ratio
   - Emergent objectives expanded beyond D.1
   
   **Cite for**: empirical-validation moments, adversarial-framing graduation, codification graduations.

2. **BSP-LE Track 2** (2026-04-10) — direct predecessor; reframe from "one mechanism replaces N" to "N+1 found via N+1 Principle." Match points:
   - 13 design iterations
   - Phase 11 root cause discipline
   - One-mechanism-not-three completeness
   - Speculation unified
   
   **Cite for**: Hyperlattice Conjecture codification + worldview cache persistence IS commit (O(1) by doing nothing) parallels.

3. **SRE Track 2G** (2026-03-30) — quantale infrastructure predecessor; distributivity refutation. Match points:
   - Algebraic property surprise during implementation
   - NTT modeling found architectural impurity
   - Pre-0 inference caught wrong declaration
   - Per-relation/per-ordering algebraic structure
   
   **Cite for**: algebraic-validation-as-specification + per-ordering refinement applied to tropical fuel.

4. **SRE Track 2H** (2026-04-03) — type lattice quantale predecessor (Phase 1V's tropical-quantale-merge extends 2H's quantale infrastructure). Match points:
   - User scope challenge to expand from "half-semiring" to full quantale
   - Vision Alignment Gate introduction
   - whnf fast-path independent empirical discovery
   - Algebraic specification (V4 distributivity = 0/512)
   
   **Cite for**: vision-alignment graduation + scope-completeness pattern that Phase 1V applied via tropical-fuel-merge atomic close.

5. **PPN Track 4B** (2026-04-07) — attribute evaluation predecessor; 90% on-network. Match points:
   - ⊥ must be distinguishable (context-bot conflation) — same lattice-design discipline as tropical (0, ∞, ⊤, ⊥) carrier
   - Ephemeral PU vs on-main-network reframing
   - Imperative bridges retirement (6 enumerated)
   - `#f` registration as invisible deferral
   
   **Cite for**: lattice-design discipline + retirement-plan-required pattern.

### 16.4 Codifications graduated from prior PIRs

| Codification | Originating PIR(s) | Destination |
|---|---|---|
| Network Reality Check (3 binary questions) | PPN 4 | `.claude/rules/workflow.md` |
| Design mantra (4 rules files) | BSP-LE 2B (mid-track) | `on-network.md`, `propagator-design.md`, `workflow.md`, `structural-thinking.md` |
| SRE lattice lens (6 questions) | BSP-LE 2 + SRE 2G/2H | `structural-thinking.md`, `CRITIQUE_METHODOLOGY.org` |
| Hyperlattice Conjecture | BSP-LE 2 | `structural-thinking.md` |
| Belt-and-suspenders as blocking red flag | BSP-LE 2B + BSP-LE 2 | `workflow.md` |
| Validated ≠ Deployed gate | PPN 2B | `workflow.md` |
| Vision Alignment Gate (3 questions) | SRE 2H | `workflow.md` + `DESIGN_METHODOLOGY.org` |
| Phase completion blocking checklist | SRE 2H | `workflow.md` |
| Two-Context Audit | (historical, reinforced PPN 3 §11) | `pipeline.md` |
| Diagnostic protocol when blocked (5 steps) | PM Track 10 | `workflow.md` |
| PIR methodology as live checklist | SRE 2H/2D | `workflow.md`, `POST_IMPLEMENTATION_REVIEW.org` |
| Dedicated test phase MANDATORY | SRE 2D (3rd instance), PPN 4B | `workflow.md` |
| Conversational implementation cadence | BSP-LE 2 + 2B | `DESIGN_METHODOLOGY.org` Stage 4 |
| `propagator-design.md` (fire-fn parameters, broadcast, set-latch, etc.) | BSP-LE 2/2B | `propagator-design.md` |
| Stratification on propagator base | BSP-LE 2B Phase R4 + PAR 1 + PM 7 + PM 2 | `stratification.md` |
| Module Theory direct sum via tagging | BSP-LE 2B Resolution B | `structural-thinking.md` |
| NTT model REQUIRED for propagator tracks | SRE 2G + PPN 2 | `workflow.md` + `DESIGN_METHODOLOGY.org` |
| Pre-0 algebraic validation (not just perf) | SRE 2G/2H/2D | `DESIGN_METHODOLOGY.org` |
| Microbench claim verification per sub-phase | (PPN 4C S2.c-iii) | `workflow.md` + `DESIGN_METHODOLOGY.org` |
| **Cell/Propagator/Scheduler Orthogonality** (THIS ADDENDUM) | **PPN 4C Tropical Addendum (D.3.EC review)** | `DESIGN_PRINCIPLES.org` + `on-network.md` + `propagator-design.md` |
| **Specialized Cell Type Framework as Cross-Track Template** (THIS ADDENDUM) | **PPN 4C Tropical Addendum (Phase 1V Commit 4)** | `DESIGN_PRINCIPLES.org` |
| **Cache Projection Read/Write Independently** (THIS ADDENDUM) | **PPN 4C Tropical Addendum (Phase 1V Commit 4)** | `DEVELOPMENT_LESSONS.org` |
| **Cache Write-Through With Persistent CHAMP** (THIS ADDENDUM) | **PPN 4C Tropical Addendum (Phase 1V Commit 4)** | `DEVELOPMENT_LESSONS.org` |

**Phase 1V's contribution**: 4 new codifications graduated (1 architectural principle + 3 lessons). High vs typical (0-2).

### 16.5 Is this an isolated outcome or part of a pattern?

**Patterns Phase 1V CONFIRMS** (extending existing patterns with new data points):
- P-A (Pre-0 reshapes 11/11)
- P-B (D:I ratio inverse correlation; 11/11)
- P-C (Critique rounds prevent drift; 10/11)
- P-E (Two-context boundary bugs; 7/11 — PERSISTS despite codification → demands architectural response per W-5 logic)
- P-I (User scope challenges improve designs; 5/11)
- P-L (Microbench claim verification; 4+/11)
- W-3 (Module Theory direct sum tagging > bridges; 3rd data point → codification threshold)

**Patterns Phase 1V BREAKS** (methodology improvements):
- P-J (+0 test delta — broken by Phase 1V's +310; dedicated test phase mandate effective)
- P-F (integration phases dominate time — INVERTED by Phase 1V's design-dominated arc; high D:I ratio correlates with fast implementation)

**New patterns surfacing at Phase 1V** (1-2 data points; watching list):
- User-articulated principle reshapes design mid-resolution (2 data points: memory as first-class earlier; Orthogonality this arc)
- Codification claim validation IN-TRACK is methodology proof (1 data point: Commit 4 → Commit 5b validation)
- Empirical sweep refutes pre-impl conjecture (1 data point: F16 refutation)
- Scaffolding-pass as distinct phase (1 data point: D.4 `45181c07`)
- "Rare design state where two architectures are live simultaneously" + falsification test (1 data point: D.4 vs D.3 + §13.6 spike)

**Pattern P-E (two-context boundary bugs) persistence**: 7th data point in 11-PIR window. Codification (pipeline.md "Two-Context Audit") has NOT prevented recurrence. **Recommendation**: this PIR's §10 should flag P-E as **architectural-response-demanded** rather than additional codification. Possible responses: (a) auto-registration via require-discovery, (b) build-time analysis tool that flags missing requires across cycle-broken modules, (c) `pipeline.md` checklist enforced via lint. Phase 1V's F15+F18 dual-path require pattern is the operational expression of P-E in the cycle-broken SRE domain context.

---

## 17. The PIR Itself — Process Notes

### 17.1 Methodology adherence

This PIR was written following `POST_IMPLEMENTATION_REVIEW.org` as a live checklist (per the codification at SRE 2H/2D). The 10 template sections + 16 questions structure was set up FIRST as a skeleton, then filled in. The §16 longitudinal survey was compiled via parallel agent dispatch (1 agent for the 10-PIR survey; 1 agent for forward-enablement context; 1 agent for timeline/test-delta data).

### 17.2 Notable methodology choice — Format B+C per user direction

Per user pre-PIR discussion:
- **Format B**: §1 frames both deliveries co-equal (Delivery 1 foreseen + Delivery 2 unforeseen)
- **Format C**: §10 elevates the meta-lesson ("the unforeseen architectural delivery is more architecturally significant than the foreseen one")

The PIR follows this structure. §1 leads with both deliveries' executive summaries; §10 elevates the meta-lesson.

### 17.3 PIR-lifecycle compliance

Per POST_IMPLEMENTATION_REVIEW.org § The PIR Lifecycle:
- ✅ Written immediately after completion (within same session as Commit 8 `b8405dfb`)
- ✅ Lessons distilled into principles documents (DESIGN_PRINCIPLES + DEVELOPMENT_LESSONS) — §10 table tracks status
- ✅ Watching-list codification candidates explicitly flagged with promotion criteria
- ✅ Cross-referenced with 10 most recent PIRs (§16)
- ✅ Quantitative metrics included (§7)
- ✅ "Where We Got Lucky" included (§11)
- ✅ Surprises explicitly documented (§12)
- ✅ Wrong assumptions surfaced (§13)
- ✅ Problem-domain learning (§14)
- ✅ Double-loop reflection (§15)

---

## Cross-references

- **Main design doc**: [`2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md`](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md)
- **Pre-0 plan**: [`2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md`](2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md)
- **D.2 self-critique**: [`2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md`](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md)
- **D.3 external critique**: [`2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_EXTERNAL_CRITIQUE.md`](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_EXTERNAL_CRITIQUE.md)
- **Stage 1 research**: [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md)
- **Parent track**: [`2026-04-17_PPN_TRACK4C_DESIGN.md`](2026-04-17_PPN_TRACK4C_DESIGN.md)
- **Parent addendum**: [`2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) (Form C cross-reference at §9.5.A added at Phase 1V Commit 8)
- **Dailies**:
  - [`2026-04-26_dailies.md`](standups/2026-04-26_dailies.md) — pre-fork tropical work
  - [`2026-05-13_dailies.md`](standups/2026-05-13_dailies.md) — main implementation arc + Phase 1V close
- **Top 5 cross-referenced PIRs** (per §16.3):
  - [BSP-LE Track 2B](2026-04-16_BSP_LE_TRACK2B_PIR.md)
  - [BSP-LE Track 2](2026-04-10_BSP_LE_TRACK2_PIR.md)
  - [SRE Track 2G](2026-03-30_SRE_TRACK2G_PIR.md)
  - [SRE Track 2H](2026-04-03_SRE_TRACK2H_PIR.md)
  - [PPN Track 4B](2026-04-07_PPN_TRACK4B_PIR.md)
- **Principles documents updated**:
  - [DESIGN_PRINCIPLES.org § Cell/Propagator/Scheduler Orthogonality](principles/DESIGN_PRINCIPLES.org)
  - [DESIGN_PRINCIPLES.org § Specialized Cell Type Framework as Cross-Track Template](principles/DESIGN_PRINCIPLES.org)
  - [DEVELOPMENT_LESSONS.org § Cache Projection Read/Write Independently](principles/DEVELOPMENT_LESSONS.org)
  - [DEVELOPMENT_LESSONS.org § Cache Write-Through With Persistent CHAMP](principles/DEVELOPMENT_LESSONS.org)
- **Forward-enabled tracks** (per §8):
  - PReduce Series Master: [`2026-05-02_PREDUCE_MASTER.md`](2026-05-02_PREDUCE_MASTER.md)
  - SH Series Master: [`2026-04-30_SH_MASTER.md`](2026-04-30_SH_MASTER.md)
  - PM Track 12 (scoped in PM Master): [`2026-03-13_PROPAGATOR_MIGRATION_MASTER.md`](2026-03-13_PROPAGATOR_MIGRATION_MASTER.md)
  - PPN Track 4D vision: [`docs/research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md`](../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md)

---

🎉 **PPN 4C Tropical Quantale Addendum — PIR complete.** 26 days, ~64 commits, +310 tests, −4.6s wall, 4 codifications graduated, 1 architectural principle codified, cross-track template established for 5+ future tracks. The unforeseen delivery (specialized cell type framework + Orthogonality discipline) is the architectural moment; the foreseen delivery (tropical quantale primitive) is the substrate that surfaced it.

The propagator network is closer to BEING the compiler, not just hosting it.
