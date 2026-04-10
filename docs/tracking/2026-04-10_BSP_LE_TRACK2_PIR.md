# BSP-LE Track 2: ATMS Solver + Cell-Based TMS — Post-Implementation Review

**Date**: 2026-04-10
**Duration**: ~35h active across 4 sessions (Apr 7-10), split: ~12h design (Stages 1-3), ~20h implementation (Stage 4), ~3h PIR+benchmarks
**Commits**: ~95 total (design: ~30, implementation: ~60, process/tooling: ~5)
**Test delta**: 7609 → 7745 (+136 tests across 5 new test files)
**Code delta**: ~2500 new/modified lines across ~25 source + test files; 1 new source module (`decision-cell.rkt`), 5 new test files
**Suite health**: 397/397 files, 7745 tests, ~126s, all pass
**Design docs**: `docs/tracking/2026-04-07_BSP_LE_TRACK2_DESIGN.md` (D.13, ~2000 lines, 13 design iterations)
**Self-critique**: `docs/tracking/2026-04-07_BSP_LE_TRACK2_SELF_CRITIQUE.md` (17 findings)
**External critique**: `docs/tracking/2026-04-08_BSP_LE_TRACK2_EXTERNAL_CRITIQUE.md` (16 findings)
**Stage 1/2**: `docs/research/2026-04-07_BSP_LE_TRACK2_STAGE1_AUDIT.md`
**Handoff**: `docs/tracking/standups/2026-04-09_2300_session_handoff.md`

---

## 1. What Was Built

A propagator-native logic solver that replaces the DFS backtracking solver with concurrent, order-independent clause execution on a propagator network. The solver uses BSP (Bulk Synchronous Parallel) scheduling to fire all clause propagators concurrently, with per-propagator worldview bitmasks providing branch isolation via tagged-cell-values.

This is the largest single track in the project's history: 13 design iterations (D.1 through D.13), 33 critique findings resolved across self-critique and external architect review, 12 implementation phases (0-11), and a complete speculation mechanism replacement — retiring `current-speculation-stack` in favor of a single mechanism (tagged-cell-value + worldview cache) with O(1) commit and O(1) retract.

Key deliverables:
- **Tagged-cell-value**: Bitmask-tagged speculative writes with O(1) commit (worldview cache persistence) and O(1) retract (bit clear). Replaces TMS tree entirely.
- **Compound cells**: `decisions-state` (merge-maintained bitmask), `commitments-state`, `scope-cell` (one per variable scope). Reduces cell allocation dramatically.
- **Decision cell infrastructure**: Pure lattice-algebraic module (`decision-cell.rkt`) with decision domains, nogoods, assumptions, counters — all as lattice operations.
- **Broadcast propagator**: General-purpose N-item parallel propagator with scheduler-decomposable profile. A/B validated: 2.3x faster at N=3, 75.6x at N=100 vs N-propagator model.
- **Solver-context**: Replaces ATMS struct. Phone book of cell-ids — no second source of truth.
- **Propagator-native solver**: `install-goal-propagator` (5 types: unify, is, app, not, guard), `install-conjunction`, `install-clause-propagators`, concurrent multi-clause via per-propagator worldview bitmask.
- **On-network tabling**: Table registry as a cell, producer/consumer propagators, one-true-tabling, completion emergent from BSP fixpoint.
- **Unified speculation**: `current-speculation-stack` RETIRED. Single mechanism. O(1) commit/retract vs O(cells) TMS fold.

---

## 2. Timeline and Phases

### Session 1: April 7 — Design Start (~8h)

| Time Est. | Activity | Commits | Key Output |
|---|---|---|---|
| ~2h | Stage 1/2: Research synthesis + codebase audit | `04a97d4c` | 5 prior art sources synthesized, TMS/ATMS/DFS code audited, scope estimated ~1700 lines |
| ~3h | D.1: Full Stage 3 design (Phases 0-11) | `b4b7cb6d`, `b5012185`, `6b2d3878`, `24837b28`, `b9543075` | 11-phase design, NTT model across 7 levels (revealed gaps), Pre-0 design |
| ~1h | Self-critique: P/R/M three-lens analysis (17 findings) | `43335d5e` | Decisions-primary architecture, ATMS dissolution, parallel-map → broadcast |
| ~30m | Phase 0a-0c: Pre-0 benchmarks + adversarial baselines | `dd945c96` | 21 micro + 4 adversarial baselines captured |
| ~1h30m | D.2: Self-critique findings incorporated + Hyperlattice Conjecture | `92067d82`, `a51c9be2` | ATMS dissolution design, SRE lattice lens mandatory practice, Hyperlattice Conjecture codified |

### Session 2: April 8 — Critique + Phases 0d-3 (~10h)

| Time Est. | Activity | Commits | Key Output |
|---|---|---|---|
| ~1h30m | External critique + D.3 (16 findings: 2 critical, 8 major, 5 minor, 1 obs) | `4d140623`, `fc2add21`, `83e519ec` | Per-NOGOOD propagators (Critical 4.1), constraint-cell convention (Critical 1.1), grounded pushback methodology |
| ~20m | Phase 0d: Acceptance file | `b3dff529` | Acceptance methodology + `.prologos` file |
| ~1h30m | Phase 1A: Decision cell infrastructure | `4df2a4d8` | `decision-cell.rkt` (pure leaf). Decision domain, nogood lattice, assumptions, counter. 30 tests. |
| ~30m | Phase 1Bi: A/B benchmark | `a50fc138` | Broadcast 2.3x @ N=3, 75.6x @ N=100 |
| ~1h | Phase 1Bii: Broadcast propagator + scheduler profile | `fb0650a3` | `net-add-broadcast-propagator`, broadcast-profile metadata |
| ~2h | D.4a-d: Broadcast audit + component-path invariant | `060568d2`-`79198cf6` | Broadcast replaces N-propagator throughout design. NTT §3.1a component-path invariant. |
| ~1h | Phase 2: Assumption-tagged dependents + branch PU | `0a78069a` | `dependent-entry`, `make-branch-pu`, `perf-inc-inert-dependent-skip!`. 7 tests. |
| ~1h30m | Phase 3: Per-nogood infrastructure | `a38baefb` | Commitment cell (structural, provenance=value), broadcast commit-tracker, narrower, contradiction detector, topology handler. 9 tests. Mini-design conversation resolved: SRE lens on commitment cell. |
| ~30m | D.5-D.6: Phase 2-3 redesign from design conversations | `3f589b02`, `a9cda857` | Assumption-tagged dependents (emergent dissolution), per-nogood redesign from mini-design |

### Session 3: April 9 — Phases 4-10 + Process Docs (~14h, largest session)

| Time Est. | Activity | Commits | Key Output |
|---|---|---|---|
| ~30m | D.7: Hypercube woven into design + Phase 1/3 touchups | `8a66109d`, `6e9fe7df`, `0c2fb13d` | SRE Lattice Lens Q6 codified. Bitmask on decision-set. Subcube pruning. +10 tests. |
| ~1h30m | Phase 4a+4b: Tagged-cell-value + worldview cache | `72394146` | `tagged-cell-value` struct, `tagged-cell-read`/`write`/`merge`, worldview cache cell (id=1). **Bug: next-cell-id not bumped** → fixed. |
| ~30m | Phase 4c analysis: Consumer migration deferred | — | Scoping asymmetry identified. Principled deferral to Phases 5/6/9. |
| ~30m | Phase 4 tests | `eb03d060` | 35 new tests (24 unit + 11 network integration). |
| ~1h | D.8-D.10: Phase 4/5 design conversations | `27ab5a4d`, `7e95552e`, `d66e55f7` | PU-based speculation, bitmask-tagged values, compound cell architecture (7 design decisions). |
| ~3h | Phase 5 implementation (13 commits, 5.1a-5.8b) | `03a41328`-`bc14289f` | Fire-once to propagator.rkt, broadcast #:component-paths, worldview cache → replacement merge, compound decisions/commitments cells, worldview projection, solver-context, solver-state wrapper, 8 consumer files migrated, 4 test files updated, 25 architecture tests. |
| ~45m | D.11: Merged Phase 6+7 design | `9167a300` | Mutual recursion between clause matching + goal dispatch → merged phases. |
| ~3h | Phase 6+7: Propagator-native solver (~15 commits) | `029b8a5d`-`a2dfa4eb` | 5 goal types, multi-clause PU branching, answer accumulator, Gray code ordering, typing-propagators migration. **Bugs: BSP fire-and-collect-writes used net-cell-read** (silent write drops); **promote-cell-to-tagged didn't update merge function**. 16 tests. |
| ~30m | D.12: Phase 8 on-network tabling design | `5da6342a` | Compound scope cells, table registry cell, producer/consumer, one-true-tabling. |
| ~1h30m | Phase 8: On-network tabling (4 commits) | `f2410a57`-`e796da41` | Scope cells (one per clause scope), table registry cell, producer/consumer propagators, tabling test. |
| ~30m | Phase 9a: Strategy dispatch | `97d8048d` | `:strategy :atms` → `solve-goal-propagator`. `:auto` → DFS. |
| ~30m | Phase 9b-1/2: Worldview bitmask migration | `5af7f1aa`, `48c718b4` | metavar-store + cell-ops read worldview bitmask only. |
| ~30m | Phase 9b-4: TMS removal attempt + REVERT | `29344a04` | typing-propagators TMS removal caused union type regression. **Root cause deferred to Phase 11.** |
| ~30m | Phase 10: Solver config wiring | `6fe6679c` | `:execution`, `:tabling`, `:timeout` knobs operational. |
| ~2h | Process documents + tooling | `c16499bb`, `e09d4936`, `aac9b1cd`, `99292f53`, `a59ad2b8` | `propagator-design.md`, `on-network.md`, `structural-thinking.md`, `check-parens.sh`, bench-lib.rkt fix, handoff document. |

### Session 4: April 10 — Phase 11 + PIR (~5h)

| Time Est. | Activity | Commits | Key Output |
|---|---|---|---|
| ~1h | D.13: Phase 11 unified speculation design | `196e2fc4` | Root cause analysis: TMS nesting hid tagged path. Demand-driven commit design. Combined worldview bitmask. Same-specificity merge. |
| ~2h | Phase 11 implementation (4 commits) | `f1f71412`-`1ccff0b9` | TMS removed from typing-propagators (union types PASS), elab-speculation-bridge TMS removed, all 5 consumers migrated to worldview-bitmask-only. `current-speculation-stack` RETIRED. |
| ~1h | A/B benchmarks | — | 13/15 programs no significant change. 2 flagged (high CV, likely noise). Adversarial: 0% change. |
| ~1h | PIR + final docs | `11ea0036` | This document. |

### Summary

| Metric | Value |
|---|---|
| Design time (Stages 1-3) | ~12h (34%) |
| Implementation time (Stage 4) | ~20h (57%) |
| PIR + benchmarks + process docs | ~3h (9%) |
| Design-to-implementation ratio | 0.6:1 |
| Design iterations | 13 (D.1 through D.13) |
| Critique findings incorporated | 33 (17 self + 16 external) |
| Phases with mini-design conversations | 6 (Phases 3, 5, 6+7, 8, 9, 11) |

---

## 3. What Was Delivered (§1-§2 PIR Methodology Questions)

**Stated objectives** (from design doc §1):

| Objective | Status | Evidence |
|---|---|---|
| DFS `append-map` → propagator quiescence | ✅ Delivered | `solve-goal-propagator` in relations.rkt uses BSP run-to-quiescence |
| Sequential clause iteration → concurrent PU-per-branch | ✅ Delivered | `install-one-clause-concurrent` with per-propagator worldview bitmask |
| Explicit substitution threading → implicit propagation | ✅ Delivered | Scope cells with net-cell-write, unification writes to components |
| `current-speculation-stack` → decision cells | ✅ Delivered | Phase 11: worldview bitmask only, stack RETIRED |
| `atms` struct → dissolved into cells | ✅ Delivered | `solver-context` (phone book of cell-ids), `solver-state` (wrapper) |
| Tabling = producer/consumer on accumulators | ✅ Delivered | `install-table-producer`/`install-table-consumer` in relations.rkt |
| `solver-config` knobs operational | ✅ Delivered | `:execution`, `:tabling`, `:timeout` all wired |
| DFS solver retired as default | ⬜ Deferred | `:auto` stays DFS pending parity validation |

Scope adherence: 12/13 phases complete (Phase T deferred). 7/8 objectives delivered. The remaining objective (DFS retirement as default) is gated on parity validation — the propagator solver is functional but hasn't been validated against all DFS test cases.

---

## 4. What Was Deferred and Why (§4)

| Deferred Item | Reason | DEFERRED.md? | Target |
|---|---|---|---|
| `:auto` → propagator default | Genuine dependency: parity validation needed across all solver test cases | Yes | BSP-LE Track 2 follow-up |
| TMS dead code removal (~200 lines) | Low risk, cosmetic. Phase 11 retired consumers; definitions remain. | No (trivial) | Next quiet interval |
| DFS ↔ propagator parity testing | Genuine dependency: needs systematic run of DFS tests through `:atms` path | Yes | BSP-LE Track 2 follow-up |
| Inert-dependent data review | Deferred pending instrumentation data from parity benchmarks | Yes | BSP-LE Track 3 |
| S(-1) lattice-narrowing cleanup | Deferred pending instrumentation data | Yes | BSP-LE Track 3 |
| Phase T: Test consolidation | Cleanup task, not feature | No | Next interval |
| NAF/guard synchronous execution | Scaffolding: should be BSP barrier (S1 stratum) | Yes | BSP-LE Track 3 |
| Tropical hitting set implementation | Designed (§2.6e), implementation deferred | Yes | Future track |
| SRE domain registration for solver lattices | Needs SRE Track 3 infrastructure for per-relation merge-registry | Yes | SRE Track 3 |

Distinction: `:auto` switch and parity testing are genuine dependencies — the propagator solver needs validation before becoming default. TMS dead code and Phase T are completeness items deferred for convenience, not dependency. NAF synchronous execution is honest scaffolding (labeled, with retirement plan).

---

## 5. What Went Well (§5)

1. **Design conversation cadence**: 6 mini-design conversations during implementation (Phases 3, 5, 6+7, 8, 9, 11) caught architectural issues before they became mid-implementation pivots. Phase 5's compound cell architecture conversation (7 design decisions) eliminated what would have been ~10 micro-propagators with one merge function. Phase 11's user-driven "N+1 Principle" conversation found demand-driven commit (the option not yet considered) when both proposed options were unsatisfying.

2. **The D.1-D.13 design evolution**: 13 iterations is unprecedented in this project. Each iteration was driven by actual findings — self-critique (17), external critique (16), hypercube pivot, broadcast audit, and 6 mini-design conversations. The design was genuinely alive throughout implementation, not a frozen specification.

3. **Broadcast propagator A/B validation**: Phase 1Bi's A/B benchmark (broadcast 2.3x @ N=3, 75.6x @ N=100) gave quantitative confidence before propagating the pattern. The data changed the entire design (D.4: broadcast replaces N-propagator throughout).

4. **Per-propagator worldview bitmask**: The key enabling idea for concurrent clause execution. Rather than forking the network (expensive, loses CHAMP sharing) or sequentializing clauses (defeats the purpose), each propagator's fire function sets its own worldview bitmask. `net-cell-write` tags writes; `net-cell-read` filters reads. All clauses execute on the SAME network. This fell out naturally from the tagged-cell-value infrastructure built in Phase 4.

5. **Unified speculation**: Phase 11 unified elaboration speculation and solver speculation into a single mechanism. O(1) commit (worldview cache persistence = no operation) and O(1) retract (bit clear + snapshot restore for scaffolding). This was the user's explicit architectural directive: invest energy in one general path, not maintain multiple parallel approaches.

6. **Root cause discipline in Phase 11**: The Phase 9b-4 TMS removal regression was NOT band-aided. It was deferred to Phase 11 with explicit root cause investigation. The root cause (TMS nesting hiding tagged path: `(tms-cell-value (tagged-cell-value ...))` caused dispatch on outer type) was non-obvious — it required understanding the interaction between two promotion paths. The fix was surgical: remove promote-cell-to-tms entirely, tagged-only promotion.

7. **check-parens.sh**: A simple tool that eliminates an entire class of wasted time. Bracket-balancing trial-and-error during large refactors (Phase 6+7 had multiple rounds) became instant delimiter validation (~100ms, read-only). Low effort, high ongoing value.

---

## 6. What Went Wrong (§6)

1. **Full suite re-runs for diagnostics (5+ instances)**: Despite rules being in place, the anti-pattern of re-running the ~130s full suite to "see which tests fail" recurred 5+ times during the Apr 9 session. Each re-run wastes 2+ minutes. The trigger-level protocol was strengthened again, but this is a recurring issue across sessions (see §16 longitudinal pattern).

2. **Phase 9b-4 premature TMS removal**: Attempted to remove TMS from typing-propagators without understanding the nesting interaction. The regression was caught (union type test failure), but the attempt + revert + investigation cost ~30 minutes. Should have done the root cause investigation FIRST, then attempted removal — not the other way around.

3. **Tagged-cell-value entry ordering bug (Phase 5.9)**: `make-tagged-merge` appended old entries before new. `tagged-cell-read` with strict `>` returned first match at max specificity — which was the OLDEST value. Fix: prepend new entries. This was a subtle ordering assumption that produced silently wrong results (wrong value returned, no error). Only caught because a test asserted the specific returned value.

4. **Worldview cache replacement vs OR (Phase 11)**: Right branch's write replaced left's bitmask via replacement merge on the worldview cache cell. The replacement merge was correct for the projection propagator (Phase 5.1c), but NOT for direct writes from speculation branches. Fix: write combined bitmask (`bitwise-ior` of left + right). This was a context-dependent merge semantics error — the same cell needed different merge behavior depending on the writer.

5. **Stale .zo cascades from struct changes**: Phases 1, 2, and 5 all hit stale `.zo` failures from struct field additions (`broadcast-profile`, `perf-counters`, `prop-network`). Each required `raco make` on the specific test file. The `precompile-modules!` fix (bench-lib.rkt now compiles test files) was added mid-track, but the issue had already cost ~30 minutes cumulative.

---

## 7. Where We Got Lucky (§7)

1. **Phase 11 root cause was clean**: The TMS nesting root cause (`promote-cell-to-tms` after `promote-cell-to-tagged` created double-wrapped value) could have been a deep architectural incompatibility requiring a redesign of how cell promotions compose. Instead, it was a clean fix: remove `promote-cell-to-tms` entirely, use tagged-only promotion. The fact that tagged-cell-value was already general enough to handle all speculation cases was not guaranteed — it could have had its own edge cases.

2. **Same-specificity merge discovered during Phase 11, not production**: The bug where `tagged-cell-read` returned the first match instead of merging all same-specificity entries was caught during union type testing. In production, this would have produced incorrect type inference for any union type with co-committed branches. Catching it during the track (rather than as a post-deployment regression) saved significant debugging time.

3. **A/B benchmarks showed no regression**: 13/15 programs showed no statistically significant change. The 2 flagged programs (church-folds -10.9%, pattern-matching -8.3%) had high CVs (17.7%, 29.2%), indicating measurement noise. The adversarial benchmarks (designed to stress Track 7 infrastructure) showed 0% change. This could have gone differently — the tagged-cell-value path adds a branch to every `net-cell-read` call, and the worldview bitmask check runs on every read. That this has zero measurable impact at Tier 1 (worldview=0 → base fast path) was hoped for but not guaranteed.

4. **BSP fire-and-collect-writes bug caught early**: The silent write-dropping from using `net-cell-read` instead of `net-cell-read-raw` for diffing was caught during Phase 6+7's first multi-clause test. If this had slipped past into a more complex test scenario, it would have been extremely difficult to diagnose — writes simply disappear, with no error signal.

---

## 8. What Surprised Us (§8)

1. **The merge IS the fan-in**: Phase 5's compound decisions cell eliminated the expected fan-in infrastructure (N micro-propagators, centralized aggregator) by putting the aggregation in the merge function. The merge recomputes the bitmask from all components on every write — retraction naturally removes bits. This was a design-conversation discovery (D.10, design decision #1) that simplified the architecture significantly. The surprise: the propagator model's merge semantics are powerful enough to express aggregation that would otherwise require explicit propagators.

2. **13 design iterations**: The D.1-D.13 evolution was unexpected in its extent. Each iteration was driven by actual findings, not churn. D.4 (broadcast audit) changed every phase. D.7 (hypercube) added structural operations. D.10 (compound cells) eliminated infrastructure. D.13 (unified speculation) resolved the deepest architectural question. A frozen Stage 3 design would have missed all of these.

3. **TMS nesting as root cause**: The Phase 9b-4 regression seemed like a tagged-cell-value semantics gap (wrong merge for attribute-map speculation). The actual root cause was structural: `promote-cell-to-tms` running AFTER `promote-cell-to-tagged` created `(tms-cell-value (tagged-cell-value ...))`. `net-cell-read` dispatched on the outer type (TMS), so the tagged path was never reached. This was invisible to per-component testing — only manifested when BOTH promotion paths ran on the SAME cell.

4. **Gray code ordering is natural, not forced**: Branch PU creation in Gray code order (changing one assumption bit per step) maximizes CHAMP structural sharing between adjacent branches. This fell out of the hypercube analysis (D.7, SRE Lattice Lens Q6) — it's not an optimization trick but a structural property of the Hasse diagram. Adjacent worldviews share almost all network state.

5. **Worldview cache persistence IS commit**: The insight that "doing nothing" is the correct commit operation. When a speculation branch succeeds, the worldview cache cell retains the branch's bit. Tagged entries written during the branch remain visible under that bit. No `net-commit-assumption`. No fold. O(1) by doing nothing. The retract path (bit clear + snapshot restore for off-network stores) is O(1) as well. This was the user's "N+1 Principle" discovery during Phase 11 design — the demand-driven option not yet considered.

---

## 9. How Did the Architecture Hold Up (§9)

**Propagator network**: Excellent. The network absorbed all new cell types (tagged-cell-value, decisions-state, commitments-state, scope-cell) without modification to the core scheduling loop. BSP `fire-and-collect-writes` needed one fix (raw reads for diffing), but the architecture was fundamentally sound. The per-propagator worldview bitmask extended the existing parameterize mechanism naturally.

**CHAMP data structure**: Excellent. The immutable persistent hash tries handle tagged-cell-value entries, compound cell components, and scope cell bindings without modification. The merge-fns CHAMP correctly stores per-cell merge functions. CHAMP structural sharing makes Gray code traversal optimal by construction.

**Elaboration bridge**: Adequate with known scaffolding. `elab-speculation-bridge.rkt` still uses snapshot/restore for off-network stores (meta-info, constraint store, id-map). This is explicitly labeled scaffolding for PPN Track 4C (dissolving these stores into cells). The worldview cache writes (commit path) and bit clears (retract path) integrate cleanly.

**SRE infrastructure**: Validated the lattice analysis framework. The 6-question SRE lattice lens was exercised on 7 lattices (§2.5 of design doc). The decisions-primary finding (worldview is derived, not primary) was a direct product of the SRE analysis. However, SRE domain registration for solver lattices was deferred — the runtime property infrastructure isn't ready for per-relation merge registries.

**Test infrastructure**: The shared fixture pattern (`test-support.rkt`, `prelude-module-registry`) scaled well. The `solver-config` parameterization in tests is clean. However, the lack of DFS-vs-propagator parity tests is a gap — correctness is validated per-feature but not systematically across all existing solver tests.

---

## 10. What Does This Enable (§10)

**Immediate**:
- `:auto` → propagator switch once parity validated — propagator solver becomes the default for all logic queries
- TMS dead code removal (~200 lines in propagator.rkt) — clean up retired mechanisms

**Medium-term**:
- **PPN Track 4C**: Elab-network dissolution (meta-info, constraint store, id-map → cells). The speculation bridge's snapshot/restore scaffolding has an explicit retirement path.
- **BSP-LE Track 3**: Left-recursive tabling (SLG completion frames). The on-network tabling infrastructure (table registry cell, producer/consumer propagators) provides the foundation.
- **SRE Track 3**: Trait resolution on propagators. Decision cells + compound cells provide the branching infrastructure.

**Long-term**:
- **All compiler registries as cells**: Table registry as on-network cell (Phase 8) pioneers the pattern. Module registry, relation store, trait dispatch tables follow the same pattern.
- **Self-hosting path**: The propagator-native solver uses the same infrastructure (cells, propagators, BSP scheduling) that the elaborator uses. The distance between "compiler infrastructure" and "solver infrastructure" has collapsed.
- **Parallel exploration**: Per-propagator worldview bitmask enables multi-threaded clause exploration when combined with the BSP scheduler's thread pool (PAR Track 2).

---

## 11. What Technical Debt Was Accepted (§11)

| Debt | Rationale | Retirement Path | Severity |
|---|---|---|---|
| Off-network elab stores (meta-info, constraints, id-map) need snapshot/restore | Genuine dependency: PPN 4C will dissolve these to cells | PPN Track 4C | Medium — scaffolding with clear path |
| NAF/guard goals execute synchronously | Needs BSP barrier (S1 stratum) for correct negation stratification | BSP-LE Track 3 | Low — NAF rarely used in current test suite |
| `:auto` defaults to DFS | Parity not validated | BSP-LE Track 2 follow-up | Medium — user-visible: solver improvements don't apply unless `:strategy :atms` is explicit |
| `solver-state-solve-all` compatibility shim | Phase 6 PU isolation needed for per-assumption writes | Future cleanup | Low — works correctly, just not maximally clean |
| No DFS-vs-propagator parity test suite | Should systematically run all DFS tests through `:atms` path | Phase T or follow-up | Medium — confidence gap |

---

## 12. What Would We Do Differently (§12)

1. **Phase 11 first, not last**: The unified speculation insight (TMS nesting as root cause, tagged-only promotion) clarified the entire architecture. Had this been discovered in Phase 4 (when tagged-cell-value was first built), Phases 5-10 would have been simpler — no dual-write scaffolding, no TMS compatibility paths, no Phase 9b-4 regression. The design conversation for Phase 11 should have been a mandatory early investigation, not a deferred cleanup.

2. **Formal merge semantics for tagged-cell-value**: Three bugs (#4 entry ordering, #6 worldview cache replacement vs OR, #7 same-specificity not merged) all stem from underspecified merge semantics. A formal specification of `tagged-cell-read`'s behavior — when to pick first match, when to merge all matches, how context-dependent merge interacts with cell-level merge — would have caught these during design. The SRE lattice lens checks algebraic properties but not operational merge semantics.

3. **Phase 0 parity baseline**: Before implementing the propagator solver, run ALL existing DFS solver tests and record results. After each phase, run the same tests through `:strategy :atms` to track parity convergence. Instead, parity testing was deferred entirely — now it's a separate effort with stale context.

---

## 13. What Assumptions Were Wrong (§13)

1. **"TMS and tagged-cell-value can coexist"**: Phases 4-9 assumed both mechanisms could be active simultaneously (dual-write). Phase 11 discovered they CANNOT — TMS nesting hides the tagged path. The assumption was reasonable (they're independent data structures), but the dispatch mechanism (`net-cell-read` branching on value type) creates an implicit ordering where the outer wrapper wins.

2. **"Worldview cache merge is context-independent"**: Phase 5.1c set the worldview cache merge to replacement (correct for the projection propagator's complete recomputation). Phase 11 discovered that speculation branches write DIRECTLY to the worldview cache, and replacement merge loses the left branch's bits. The assumption that one merge function works for all writers of a cell was wrong — different writers have different semantics.

3. **"Tagged-cell-read first-match is correct"**: The `>` popcount comparison returning the first match seemed natural (most-specific wins). Phase 11 discovered that union types create co-committed entries at the same specificity that need MERGING, not picking. The assumption that "most specific" is always a single entry was wrong for branching elaboration.

4. **"Consumer migration can be incremental"**: Phase 4c deferred consumer migration to principled points (Phases 5/6/9). In practice, the dual-write scaffolding (TMS + tagged simultaneously) created the exact nesting problem that Phase 11 had to solve. Incremental migration created a transitional state that was worse than either endpoint.

---

## 14. What Did We Learn About the Problem (§14)

1. **Speculation is a single-mechanism problem**: The project had accumulated three speculation mechanisms (TMS trees, `current-speculation-stack` parameter, tagged-cell-value bitmasks). Each handled a different case. Phase 11 proved that tagged-cell-value + worldview cache is general enough for ALL cases — elaboration speculation, solver speculation, and union branching. The Completeness principle applies: one complete mechanism beats three partial ones.

2. **The merge function IS the aggregation**: Compound cells (decisions-state, commitments-state) use their merge function to maintain derived state (bitmask, commitment tracking). No explicit fan-in propagators needed. This is a deeper insight about propagator networks: the merge is not just a "conflict resolution" mechanism — it's a general-purpose aggregation operator. Fan-in propagators are often a sign that the merge isn't doing enough.

3. **Decision cells are primary, worldview is derived**: The SRE analysis (§2.5a) revealed that the worldview is a projection of decision state, not a primary data structure. This reframes the entire ATMS architecture: nogoods narrow decisions (not worldviews), branches are per-decision-alternative (not per-worldview-combination), and retraction IS decision cell narrowing.

4. **Promotion ordering matters, structurally**: When a cell value can be promoted to multiple wrapper types (TMS, tagged), the ORDER of promotion determines dispatch behavior. `(tms (tagged ...))` dispatches on TMS; `(tagged (tms ...))` dispatches on tagged. This is not a bug — it's a structural property of algebraic data types. The fix is not to "handle both orderings" but to choose ONE mechanism (Completeness).

5. **O(1) commit is achievable via persistence**: The worldview cache persistence insight — commit = do nothing, retract = bit clear — shows that immutable data structures enable O(1) speculative commit by construction. The TMS fold approach (O(cells) commit via tree traversal) was solving a problem that immutability already solves. This has implications for all future speculation infrastructure.

---

## 15. Are We Solving the Right Problem (§15)

Yes. The propagator-native solver is the foundation everything builds on. Before this track:
- Logic queries used DFS backtracking (sequential, no CHAMP sharing between branches)
- Speculation used imperative save/restore (O(cells) commit, timing-dependent correctness)
- The ATMS was a separate data structure alongside the propagator network (second source of truth)

After this track:
- Logic queries use BSP propagation (concurrent, CHAMP sharing, order-independent)
- Speculation uses worldview bitmask (O(1) commit, structurally correct)
- All solver state lives in cells on the network (single source of truth)

The remaining gap is clear: `:auto` still defaults to DFS. The solver is built, validated, and benchmarked — but not deployed as the default. Per the "Validated Is Not Deployed" rule, this needs a focused follow-up to close.

The longer-term direction (self-hosting, all registries as cells, parallel exploration) depends on exactly this infrastructure. BSP-LE Track 2 is load-bearing for the project's architectural vision.

---

## 16. Longitudinal Survey (§16)

### 10 Most Recent PIRs

| # | Track | Date | Duration | Test Delta | Commits | Bugs | Key Wrong Assumption | D:I Ratio |
|---|---|---|---|---|---|---|---|---|
| 1 | **BSP-LE Track 2** | Apr 10 | ~35h/4 sess | +136 | ~95 | 7 | TMS/tagged coexistence; merge context-independence | 0.6:1 |
| 2 | PPN Track 4B | Apr 7 | ~17h/2 sess | +31 | 47 | 9 | Context-bot conflation; install-from-rule API too narrow | 0.5:1 |
| 3 | PPN Track 4 | Apr 4 | ~3 sess | +23 | 69 | 6 | Type-vs-value confusion; delegation = imperative-in-disguise | ~0.3:1 |
| 4 | SRE Track 2H | Apr 3 | ~14h/1 sess | +35 | 30 | 2 | Union sort key non-deterministic; type lattice not distributive | 2.5:1 |
| 5 | SRE Track 2D | Apr 3 | ~11h/1 sess | +25 | 18 | 2 | expand-compose registered twice (hidden since Track 2B) | 1.5:1 |
| 6 | PPN Track 3 | Apr 2 | ~30h/2 sess | 0 | 70+ | 6 | Tree-parser expected flat tokens; 5-arg def pattern unhandled | 0.6:1 |
| 7 | PPN Track 2B | Mar 30 | ~10h/1 sess | -5 | 18 | 0 | "Validated != deployed" — `use-tree-parser?` defaulted #f | 1:1 |
| 8 | SRE Track 2G | Mar 30 | ~10h/1 sess | +32 | 11 | 3 | Type domain declared distributive when it's NOT | 1.5:1 |
| 9 | PPN Track 2 | Mar 29 | ~8.5h/1 sess | 0 | 68 | 0 | Tree-parser would produce surfs directly; big-bang premature | 0.8:1 |
| 10 | PAR Track 1 | Mar 28 | ~14h/1 sess | 0 | ~53 | 10 | Decomp-request not in BSP diff; infinite loop from clearing | 1.5:1 |

### Recurring Patterns

**Pattern 1: Wrong lattice/merge assumptions (6/10 PIRs)**
BSP-LE 2 (merge context-independence, TMS coexistence), Track 4B (context-bot conflation), SRE 2H (non-distributive under equality), SRE 2G (type lattice not distributive), SRE 2D (expand-compose double registration), PAR 1 (decomp-request not in BSP diff). This is now the #1 risk category — any design involving merges or lattice properties should include explicit verification. The SRE lattice lens was created during this track specifically to address this pattern.

**Pattern 2: Test delta = 0 (3/10 PIRs)**
PPN Track 3, PPN Track 2, PAR Track 1 all had +0 suite test delta. BSP-LE Track 2 breaks this pattern with +136 tests. The per-phase test gate (codified at session start) is working.

**Pattern 3: Diagnostic discipline regression (recurring)**
Full suite re-runs for diagnostics recurred in this track (5+ instances) despite being addressed in PAR Track 1 and PPN Track 3 PIRs. The trigger-level protocol was strengthened again with explicit stop-and-read instructions. This pattern spans 4+ PIRs and demands a structural response — perhaps a guard script (added: `guard-suite-rerun.sh`) or a hard timeout on consecutive suite runs.

**Pattern 4: Validated != Deployed (3/10 PIRs)**
PPN Track 2B (tree-parser `#f` default), BSP-LE Track 2 (`:auto` stays DFS), PPN Track 4 (delegation wrappers around imperative). The rule was codified after Track 2B. BSP-LE Track 2 is honest about the gap (`:auto` = DFS, propagator solver is opt-in via `:strategy :atms`), but the pattern persists.

**Pattern 5: D:I ratio correlates with implementation quality**
High D:I (SRE 2H 2.5:1, SRE 2D 1.5:1, PAR 1 1.5:1) → clean implementation, few bugs. Low D:I (PPN 4 0.3:1, PPN 3 0.6:1) → diagnostic-heavy, mid-implementation pivots. BSP-LE Track 2 at 0.6:1 is low, but the 13 design iterations (mini-conversations during implementation) effectively raised the design investment without the ratio capturing it. The metric should perhaps include mid-implementation design time.

---

## Test Coverage

### New Test Files (5)

| File | Tests | Phase | Coverage |
|---|---|---|---|
| `test-decision-cell.rkt` | 45 | Phase 1 + touchups | Decision domain ops, nogood lattice, bitmask Hasse ops, broadcast BSP verification |
| `test-branch-pu.rkt` | 9 | Phase 2 + 6a additions | Branch PU lifecycle, assumption-tagged dependents, inert-dependent skip |
| `test-tagged-cell-value.rkt` | 36 | Phase 4 | 24 unit (read/write/merge/struct) + 11 network integration (worldview cache, tagging, branch isolation) |
| `test-solver-context.rkt` | 25 | Phase 5 | Solver-context creation, cell-based operations, consumer API parity, architecture validation |
| `test-propagator-solver.rkt` | 17 | Phase 6+7+8 | All 5 goal types, multi-clause branching, tabling producer/consumer, concurrent execution |

### Migrated Test Files (4)

`test-atms-types` (37), `test-elab-speculation` (18), `test-infra-cell-atms-01` (21), `test-capability-05b` (24) — updated to use `solver-state` API.

### Gaps

- No DFS-vs-propagator parity test running both strategies on same inputs
- No dedicated test for same-specificity merge in tagged-cell-read (tested indirectly via union types)
- No dedicated test for worldview cache context-dependent merge (caught by union type test, not isolated)
- No tabling stress test (large relation, many consumers)

---

## Bugs Found and Fixed

### Bug 1: `next-cell-id` not bumped (Phase 4b)

**Symptom**: Branch PU test failed — cell-id collision between branch-local cell and worldview cache.
**Root cause**: Worldview cache cell pre-allocated at cell-id 1, but `next-cell-id` stayed at 1. First user-allocated cell got cell-id 1, colliding with the cache cell.
**Why it seemed right**: Pre-allocation happened in a `define` form at module level; the `next-cell-id` mutation was in a separate `define`. Easy to miss the coupling.
**Fix**: Bump `next-cell-id` to 2 after pre-allocating cells 0 (unused sentinel) and 1 (worldview cache).
**Contributing factor**: No assertion checking that allocated cell-ids don't collide with pre-allocated ones.

### Bug 2: BSP `fire-and-collect-writes` used `net-cell-read` (Phase 6+7)

**Symptom**: Writes from concurrent clause propagators silently dropped. Multi-clause tests returned no results.
**Root cause**: `fire-and-collect-writes` uses read-before/read-after diffing to detect writes. After the fire function returns, `current-worldview-bitmask` is 0 (the parameterize scope has ended). `net-cell-read` at bitmask=0 applies worldview filtering → tagged entries invisible → diff sees no change → writes silently dropped.
**Why it seemed right**: `net-cell-read` is the standard read API. Using it for diffing seemed natural.
**Fix**: Use `net-cell-read-raw` (bypasses worldview filtering) for the snapshot/result diff.
**Contributing factor**: The silent failure mode (no error, just empty results) made this hard to diagnose. Only caught because the first multi-clause test had known expected output.

### Bug 3: `promote-cell-to-tagged` didn't update merge function (Phase 6+7)

**Symptom**: Tagged entries destroyed during merge. Cell values reverted to untagged after merge.
**Root cause**: `promote-cell-to-tagged` wrapped the cell value in `tagged-cell-value` but left the original merge function (e.g., `logic-var-merge`) in the `merge-fns` CHAMP. The original merge doesn't understand `tagged-cell-value` structure — it treats the entire struct as a value to merge, destroying the entries list.
**Why it seemed right**: Other cell promotions (e.g., to compound) worked without merge updates because their merge functions were designed for nested values.
**Fix**: `promote-cell-to-tagged` now wraps the original merge with `make-tagged-merge(domain-merge)` and updates the `merge-fns` CHAMP.

### Bug 4: Tagged-cell-value entry ordering (Phase 5.9)

**Symptom**: Wrong value returned from tagged-cell-read at same specificity.
**Root cause**: `make-tagged-merge` appended old entries before new entries. `tagged-cell-read` with strict `>` on popcount returned the first match — which was the OLDEST value, not the newest.
**Why it seemed right**: `append` preserves chronological order. But `tagged-cell-read`'s "first match" assumption means the FIRST entry at max specificity wins — so newest must be first.
**Fix**: Prepend new entries (new-first ordering).

### Bug 5: TMS nesting hid tagged path (Phase 11 — ROOT CAUSE of 9b-4 regression)

**Symptom**: Union type `<Nat | Bool>` regression when TMS `parameterize` removed from typing-propagators.
**Root cause**: `promote-cell-to-tms` running AFTER `promote-cell-to-tagged` created `(tms-cell-value (tagged-cell-value ...))`. `net-cell-read` dispatched on the outer type (TMS), so the tagged path — where worldview-filtered reads happen — was never reached. The tagged entries were present but invisible.
**Why it seemed right**: Both promotions are independently correct. The interaction was invisible to per-component testing.
**Fix**: Remove `promote-cell-to-tms` entirely. Use tagged-only promotion. One mechanism, not two.
**Contributing factor**: The dual-write scaffolding (Phases 4-9: TMS + tagged simultaneously) created the exact nesting condition. Incremental migration created a transitional state worse than either endpoint.

### Bug 6: Worldview cache replacement vs OR (Phase 11)

**Symptom**: Right speculation branch's writes invisible under left branch's worldview.
**Root cause**: Right branch wrote just its bitmask to worldview cache. The replacement merge (set in Phase 5.1c for the projection propagator) overwrote the left branch's bit. The left branch's tagged entries became invisible.
**Why it seemed right**: Replacement merge is correct for the projection propagator (which writes the complete recomputed bitmask). But speculation branches write DIRECTLY to the cache, and replacement loses the left branch's bit.
**Fix**: Write combined bitmask (`bitwise-ior` of left + right branches).

### Bug 7: Same-specificity entries not merged (Phase 11)

**Symptom**: Union types with co-committed branches returned wrong type.
**Root cause**: `tagged-cell-read` returned the first match when multiple entries had the same popcount (same number of bits set). For the solver, entries at same specificity are alternatives (pick one is fine). For elaboration, they can be co-committed truths that need MERGING.
**Why it seemed right**: "Most specific wins" is the correct principle. The error was assuming "most specific" always yields a SINGLE entry.
**Fix**: Collect all matches at max popcount, merge via domain-merge extracted from the cell's merge function.

---

## Design Decisions and Rationale

| # | Decision | Rationale | Principle |
|---|---|---|---|
| 1 | Decisions-primary, worldview derived | SRE lattice lens: decisions are structural (per-amb), worldview is aggregate. Nogoods narrow decisions, not worldviews. | Correct-by-Construction, Decomplection |
| 2 | Compound decisions cell (merge-maintained bitmask) | The merge IS the fan-in — no micro-propagators, no centralized aggregator. O(1) component-indexed access. | Propagator-First, Data Orientation |
| 3 | Broadcast propagator replaces N-propagator | A/B validated: 2.3-75.6x faster. One propagator, N items, constant overhead. Scheduler-decomposable. | Completeness (do the hard thing right) |
| 4 | Per-propagator worldview bitmask | Enables concurrent clause execution on same network. No forking (preserves CHAMP sharing). | All-at-once, Decomplection |
| 5 | One-true-tabling | Cost negligible (one cell per relation). Completion emergent from BSP. Always-on avoids the "should I table?" decision. | Completeness |
| 6 | Compound scope cells (one per scope, not per variable) | Table entries ARE scope cells. Reduces M*K to M cells. Unification writes to components. | Cell Allocation Efficiency |
| 7 | Worldview cache persistence IS commit | O(1) vs O(cells). Information flow, not imperative fold. Commit = nothing; retract = bit clear. | Correct-by-Construction |
| 8 | `current-speculation-stack` RETIRED | One mechanism. Improvements benefit everything. Tagged-cell-value + worldview cache handles all speculation cases. | Completeness, Decomplection |
| 9 | Per-NOGOOD propagators (not per-decision) | Each nogood is its own information-flow unit. Fan-in = |nogood| (typically 2-3). External critique Critical 4.1. | Data Orientation |
| 10 | Table registry as on-network cell | Pioneers self-hosting pattern: ALL compiler registries → cells. | On-Network mandate, First-Class by Default |

---

## Metrics

| Metric | Value |
|---|---|
| Total commits | ~95 (30 design + 60 implementation + 5 process) |
| Total duration | ~35h across 4 sessions |
| Design iterations | 13 (D.1 through D.13) |
| Critique findings | 33 (17 self + 16 external) |
| Files modified | ~25 (15 source + 10 test) |
| New source modules | 1 (`decision-cell.rkt`) |
| New test files | 5 |
| Test delta | +136 (7609 → 7745) |
| Suite time | ~126s (was ~134s baseline) |
| Suite health | 397/397 files, 7745 tests, all pass |
| Bugs found and fixed | 7 |
| A/B regression | 13/15 programs: no significant change. 2 flagged (church-folds -10.9%, pattern-matching -8.3%) with high CV (17.7%, 29.2%), likely measurement noise. Adversarial benchmarks: 0% change. |
| Acceptance criterion | <15% regression: MET |
| Design-to-implementation ratio | 0.6:1 (but 6 mid-implementation design conversations effectively raise this) |

---

## Key Files

| File | Role | Changes |
|---|---|---|
| `decision-cell.rkt` | NEW. Pure leaf module: tagged-cell-value, decisions-state, commitments-state, scope-cell, decision-domain, bitmask Hasse ops | Created Phase 1, extended Phases 4-8 |
| `propagator.rkt` | Core network: worldview cache cell, fire-once (general), broadcast (extended), promote-cell-to-tagged, current-worldview-bitmask, wrap-with-worldview, install-worldview-projection | Modified Phases 1-7, 11 |
| `atms.rkt` | solver-context (cell-id phone book), solver-state (wrapper), table operations. Old `atms` struct deprecated. | Rewritten Phase 5-6 |
| `relations.rkt` | Propagator-native solver: install-goal-propagator (5 types), install-clause-propagators, scope cells, tabling | Extended Phases 6+7, 8 |
| `elab-speculation-bridge.rkt` | Unified speculation: worldview cache commit/retract, O(1) paths | Modified Phases 5, 11 |
| `typing-propagators.rkt` | Union branching: tagged-only promotion (TMS removed), combined worldview bitmask | Modified Phases 6, 9, 11 |
| `stratified-eval.rkt` | `:strategy` dispatch, solver config wiring | Modified Phases 9, 10 |
| `cell-ops.rkt` | `worldview-visible?` uses worldview bitmask only (TMS fallback removed) | Modified Phase 9b, 11 |
| `metavar-store.rkt` | `current-speculation-assumption` reads worldview bitmask only | Modified Phase 9b |
| `test-decision-cell.rkt` | 45 tests: decision domain, nogood lattice, bitmask Hasse, broadcast BSP | Created Phase 1, extended |
| `test-tagged-cell-value.rkt` | 36 tests: tagged-cell-value unit + network integration | Created Phase 4 |
| `test-solver-context.rkt` | 25 tests: solver-context, cell-based operations, architecture validation | Created Phase 5 |
| `test-propagator-solver.rkt` | 17 tests: all goal types, multi-clause, tabling | Created Phase 6+7 |
| `test-branch-pu.rkt` | 9 tests: branch PU lifecycle, inert-dependent skip | Created Phase 2 |

---

## Lessons Distilled

| # | Lesson | Distilled To | Status |
|---|---|---|---|
| 1 | Fire-once for single-output propagators | `.claude/rules/propagator-design.md` | Done |
| 2 | Broadcast for independent items | `.claude/rules/propagator-design.md` | Done |
| 3 | Component-indexing mandatory for compound cells | `.claude/rules/propagator-design.md` | Done |
| 4 | Per-propagator worldview bitmask pattern | `.claude/rules/propagator-design.md` | Done |
| 5 | SRE lattice lens (6 questions) | `.claude/rules/structural-thinking.md` | Done |
| 6 | Hasse diagram optimality argument | `.claude/rules/structural-thinking.md` | Done |
| 7 | On-network self-hosting mandate | `.claude/rules/on-network.md` | Done |
| 8 | Diagnostic protocol (trigger-level intervention) | `.claude/rules/testing.md` | Done |
| 9 | check-parens.sh after .rkt edits | `.claude/rules/testing.md` | Done |
| 10 | fire-and-collect-writes must use raw reads (CRITICAL) | `.claude/rules/propagator-design.md` | Done (Phase 6+7) |
| 11 | Same-specificity merge in tagged-cell-read | Design doc §11.1 | Captured in D.13 — pending distillation to rules |
| 12 | Worldview cache combined bitmask for co-committed branches | Design doc §11.1 | Captured in D.13 — pending distillation to rules |
| 13 | Promotion ordering matters for algebraic data types | This PIR §14.4 | Pending — distill to DEVELOPMENT_LESSONS.org |
| 14 | Merge function IS aggregation (eliminates fan-in propagators) | This PIR §14.2 | Pending — distill to propagator-design.md |
| 15 | Incremental migration can create states worse than either endpoint | This PIR §13.4 | Pending — distill to DEVELOPMENT_LESSONS.org |
| 16 | O(1) commit via persistence (worldview cache retention) | This PIR §14.5 | Pending — distill to propagator-design.md |

### Process Lessons

| # | Lesson | Status |
|---|---|---|
| P1 | Full suite is NOT a diagnostic tool (5+ instances, spans 4+ PIRs) | Strengthened in testing.md. Guard script added. Demands structural response. |
| P2 | Mini-design conversations during implementation are high-value | Captured in DESIGN_METHODOLOGY.org (conversational cadence). 6 instances this track. |
| P3 | Phase completion checklist is BLOCKING (Vision Alignment Gate + Network Reality Check) | Codified in workflow.md. Successfully applied this track. |
| P4 | "Validated Is Not Deployed" — parameters defaulting to #f are gaps | Codified in workflow.md. BSP-LE Track 2 is honest about the gap (`:auto` = DFS). |
