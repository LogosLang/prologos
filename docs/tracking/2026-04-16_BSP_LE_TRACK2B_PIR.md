# BSP-LE Track 2B — Post-Implementation Review

**Date**: 2026-04-16
**Duration**: 2026-04-11 05:15 → 2026-04-16 15:15 PDT (~5.4 days wall-clock, multi-session, context-compacted mid-track)
**Commits**: 43 (in `racket/prologos/`) from `a1df50f4` through `034aa167`
**Test delta**: 7529 → 7765 (+236, +3.1%)
**File delta**: 383 → 399 (+16 files)
**Code delta**: +4348/-489 across 28 files; core solver: +2010/-343 in relations.rkt/propagator.rkt/stratified-eval.rkt/solver.rkt
**Suite health**: 399/399 files, 7765 tests, 121s wall-clock, all pass
**Design docs**: [Design](2026-04-10_BSP_LE_TRACK2B_DESIGN.md) (D.1→D.13), [Self-Critique](2026-04-10_BSP_LE_TRACK2B_SELF_CRITIQUE.md), [External Critique](2026-04-10_BSP_LE_TRACK2B_EXTERNAL_CRITIQUE.md), [Critique Response](2026-04-10_BSP_LE_TRACK2B_CRITIQUE_RESPONSE.md)
**Handoff**: [2026-04-16_BSP_LE_2B_HANDOFF.md](handoffs/2026-04-16_BSP_LE_2B_HANDOFF.md)
**Dailies**: [2026-04-12_dailies.md](standups/2026-04-12_dailies.md)
**Predecessor PIR**: [BSP-LE Track 2](2026-04-10_BSP_LE_TRACK2_PIR.md)

---

## 1. What Was Built

Track 2B delivered three interlocking things:

**(a) On-network solver architecture.** Phase R migrated 6 solver infrastructure pieces from off-network state to propagator cells: relation store, config, discrimination data, NAF-pending accumulator, pool config, and answer egress cell. Every goal installation is now propagator-mediated — no construction-time direct writes. **General N-stratum BSP infrastructure**: Track 2B extracted the single-stratum topology pattern (PAR Track 1) into a general (request-accumulator cell + handler) mechanism, then added S1 NAF as the second concrete stratum. This is the first Prologos piece where multiple concrete stratifications coexist on the same propagator base under a uniform mechanism — architecturally reusable for future strata (well-founded semantics, cost-bounded exploration, self-hosting passes). NAF and guard unified as worldview assumptions under a single pattern. Clause-level scope sharing (Resolution B, Module Theory) eliminates bridge propagators and the tag-collapse bug class.

**(b) Parallel BSP infrastructure.** Hypercube tree-reduce merge with per-propagator cell-id namespaces (high-bit encoding). Semaphore-based persistent worker pool replacing per-round thread creation. Exhaustive streaming BSP investigation (4 approaches, all worse than sync pool due to Racket's ~8μs cross-thread wakeup floor). Parallel crossover at N≈256 accepted for Phase 0; infrastructure ready for self-hosting where per-propagator work increases.

**(c) Tier 1 optimization + adaptive dispatch.** Universal Tier 1 fast-path (direct fact return) at `stratified-solve-goal` benefits all strategies. 62x speedup on single-fact queries (30.6μs → 0.49μs); ATMS now 2.3x faster than DFS for Tier 1. Adaptive `:auto` dispatch: NAF/guard → ATMS (mandatory), N ≥ threshold(256) → ATMS (parallel benefit), else → DFS (6-11x faster at practical sizes). Phase T then closed the parity loop: 7 correctness fixes, 15/15 systematic parity sweep, 15 permanent regression tests.

The narrative arc: D.9 design assumed NAF needed complex probe mechanisms; D.12 reframed NAF as a worldview stratification on top of ATMS; D.13 added Phase R (mantra audit) after the user introduced the design mantra as a first-class gate ("All-at-once, all in parallel, structurally emergent information flow ON-NETWORK"). The audit found 6 architectural violations tests had missed. The rest of the track cleaned them up, then optimized, then validated.

---

## 2. Timeline and Phases

| Phase | Status | Commit | Duration | Description |
|---|---|---|---|---|
| 0a | ✅ | pre-track | — | Parity baseline: 19/19 files both strategies; adversarial finds 3 divergence categories |
| 0b | ✅ | pre-track | — | 28 micro-benchmarks + overhead decomposition (ATMS 24.5x) |
| 0c | ✅ | pre-track | — | A/B executor comparison: sequential wins current workloads, threads at N≥128 |
| 1a | ✅ | `a1df50f4`→`b47b9787` | ~53 min | Clause selection as decision-cell narrowing; on-network discrimination; Categories 1+2 FIXED |
| 1b | ✅ | `1eae7eb8`→`cb4758f4` | ~12 min | Tree traversal + revert (step-think caught + fixed) |
| 2a (pre-R) | attempted | `d4f00a4c`→`7ac4cc1a` | ~60 min | NAF via worldview bitmask, probe vars, success cells — all failed for multi-result composition |
| D.11/D.12 | design | — | (out-of-band) | NAF as stratified eval, then as worldview assumption with conjunction pre-scan |
| 2a (D.12) | partial | `e928dbc0`→`472db662` | ~5h 15m (w/ breaks) | D.12 WIP (~32m) → break → basic+variable PASS (~22m active); multi-result still broken |
| **Design mantra introduced** | — | `a5cde27f` | (interstitial) | Four rules files codified; audit of Track 2B triggered |
| **R1** | ✅ | `9bf8fff7`→`23041a2e` | ~15 min | Relation store (cell-id 2), config (cell-id 3), discrim-data as on-network cells |
| **R3** | ✅ | `3bdf3322` | ~17 min (after R1) | All goal installation propagator-mediated (4 sites: unify, is, one-clause, one-clause-concurrent) |
| **R4** | ✅ | `8fbc342b` | ~4h after R3 | General N-stratum BSP; NAF-pending cell (cell-id 4); S1 fork handler; -90 lines imperative S1 |
| **R2** | ✅ | `d4da77de` | ~25 min after R4 | Fact-row PU as per-row fire-once propagators with combined bitmask |
| **R6** | ✅ | `8e8ea659` | next morning | PU dissolution → answer-cid egress (NTT SolverNet :outputs alignment) |
| 2a (R2-R6) | ✅ | `a6b02159`→`4b2e5bdf` | ~13 min | Scope sharing (Resolution B) + product-worldview dissolution; ALL adversarial NAF PASS |
| 2b | ✅ | `bbf3eb82`→`8d64954f` | ~22 min | Tree-reduce merge; per-propagator cell-id namespaces; CHAMP diff for new-cell capture |
| 2c | ✅ | `a7b015dd` | ~62 min (w/ bench) | Semaphore-based worker pool; pool config (cell-id 5); crossover N≈256 |
| 2d | ✅ | `1c691f86` | ~65 min (4 approaches) | Streaming BSP investigation: 4 approaches benchmarked, sync pool optimal; Racket thread ceiling documented |
| 3 | ✅ | `83276b0d` | ~2h after 2d | Guard as worldview assumption (same pattern as NAF); install-conjunction pre-scans both |
| 5a | ✅ | `333a5667`→`2181fac0` | ~27 min | PROP-FIRE-ONCE + PROP-EMPTY-INPUTS flags; Tier 1 flush; self-clearing fired-set; closure wrapper removed |
| 5b/5c | ✅ | `d998b06c`→`01de93f5` | ~13h (overnight) | Network template; Tier 1 direct fact return (62x speedup); PPN boundary normalization |
| 5b/5c (universal) | ✅ | `b4001cd7` | ~26 min | Tier 1 lifted to `stratified-solve-goal` — benefits ALL strategies |
| 6 | ✅ | `7d77d52a` | ~24 min | Adaptive `:auto`: Tier 1 → direct, NAF/guard → ATMS, N≥256 → ATMS, else → DFS |
| **Handoff** | — | `2392a2d9` | — | Context compaction boundary; handoff document written |
| **T-a** | ✅ | `1eb8b8cc`→`35a39865` | ~27 min | 7 correctness fixes: CWA undefined error, ground provability DFS, 0-arity delegation, gating-only markers, marker guard, entry pre-merge, product dedup |
| T (process) | ✅ | `946a98ac` | ~3 min (interstitial) | Stale .zo detection extended to cover test files |
| **T-b** | ✅ | `a4326539` | ~9 min (after T-a) | Systematic DFS↔ATMS parity sweep: 15/15 BOTH PASS |
| **T-c** | ✅ | `034aa167` | ~16 min | `test-solver-parity.rkt`: 15 regression tests across 10 divergence classes |

**Note on durations**: These are wall-clock intervals between commits, which include thinking, debugging, and reviewing — not pure coding time. "After" indicates gap time between a commit and the next, when design conversation or investigation was happening between commits.

### Working Sessions

Eight distinct working sessions (commits clustered with < 2h gaps), separated by sleep, context compactions, or travel (timezone shifted PDT → HST mid-track):

| Session | Date (local) | Span | Active | Commits | Phases covered |
|---|---|---|---|---|---|
| A | Apr 11 PDT morning | 05:15 → 06:35 | 1h 20m | 8 | 1a, 1b |
| B | Apr 13 PDT afternoon | 14:15 → 15:14 | 1h 0m | 5 | 2a first attempts (D.9/D.10/D.11 failed) |
| C | Apr 13 PDT evening | 16:59 → 20:30 | ~54m active (3h31m w/ break) | 6 | D.12 WIP, Phase 2a worldview basic |
| D | Apr 14 HST late evening | 17:21 → 22:10 | 4h 49m | 5 | R1, R3, R4, R2 |
| E | Apr 15 HST day | 09:24 → 17:13 | 7h 49m | 7 | R6, 2a Res B, 2b, 2c, 2d |
| F | Apr 15 HST evening | 19:32 → 21:47 | 2h 15m | 4 | 3, 5a, 5a fix, 5b/5c opt |
| G | Apr 16 HST morning | 10:14 → 11:04 | 50m | 3 | Tier 1 (direct + universal), Phase 6 |
| H | Apr 16 HST afternoon | 14:23 → 15:15 | 52m | 5 | T-a (3 commits), T-b, T-c |

**Active implementation time**: ~19h 40m across 8 sessions.
**Wall-clock duration**: April 11 05:15 PDT → April 16 15:15 HST = ~5 days 13 hours (5.54 days).
**Gap time** (between sessions): ~4 days 18 hours — includes sleep, a travel leg (PDT→HST), and context compaction preparation.

### Design:Implementation Analysis

- **Design phase**: D.1 through D.13 spanning April 7 → April 10 (~3 days wall-clock, variable active time). Self-critique + external critique + critique-response documents written. Design doc grew through 13 iterations responding to findings.
- **Implementation phase**: ~19h 40m active across 8 sessions over 5.5 days wall-clock.
- **D:I ratio (conservative)**: ~3 design days : 5.5 implementation wall-clock days = **0.55:1**. Below the 1.5:1 target from longitudinal PIR pattern §5.
- **D:I ratio (iteration-weighted)**: 13 design iterations × typical iteration cost (several hours each) is a stronger signal than pure calendar time. In-flight redesign (D.11 → D.12 → D.13 mid-implementation) effectively extended design investment into implementation. **Phase R itself was a design iteration triggered by the mantra audit** — the implementation stopped, design redrew 6 architectural components, implementation resumed.

**Interpretation**: 0.55:1 calendar ratio looks low, but 13 design iterations (vs typical 3-5) and multiple mid-flight redesigns indicate high total design investment. The 14 bugs found were mostly implementation-level (closure capture, zip mismatch, AST/raw divergence) rather than architectural — evidence that the design held.

### Compaction Boundary

Context compacted at `2392a2d9` (Phase 6 complete, handoff written) before Phase T. Sessions G and H post-compaction used the handoff protocol — re-read handoff document + design doc (D.13 §T) + dailies to restore understanding, then continued T-a/T-b/T-c. Successful — no re-learning required; the handoff preserved the architectural model.

---

## 3. Stated Objectives vs Delivered (Gap Analysis)

The design document's §1 stated the end state: *"The propagator-native solver IS the default solver. `:auto` routes to `solve-goal-propagator`."* with three success criteria. Here's the honest comparison:

### 3.1 Stated end-state vs actual

| Design objective | Actual delivery | Gap |
|---|---|---|
| `:auto` → propagator (always) | `:auto` → adaptive: NAF/guard → ATMS, N≥256 → ATMS, else → DFS | **Large (literal)**. The literal objective wasn't met. Measurement-driven reframing revealed DFS is 6-11x faster for practical clause queries (N<256). Adaptive dispatch is a *better* answer than the stated objective, not the stated objective. |
| Per-fact-row PU isolation | ✅ Phase R2 per-row fire-once propagators | **None**. Delivered as designed. |
| NAF: async propagator with NAF-result cell | NAF as S1 stratified worldview assumption with fork+BSP+nogood | **Mechanism changed**. D.11→D.13 redesigned NAF after D.10's async-thread approach couldn't compose multi-result cases. Delivered correctness; mechanism is different. |
| Guard: guard-test propagator with inner-goal continuation | Guard as S0 worldview assumption (same pattern as NAF) | **Mechanism changed**. Unified with NAF under the gating-kinds pattern. Simpler than the design. |
| `current-parallel-executor` → threads-default | Semaphore-based worker pool with threshold N≥256 | **Large**. Parallel infrastructure built + benchmarked but threshold-gated; not enabled by default for typical workloads. Racket parallelism floor (~8μs) makes enablement below N≈256 a regression. |
| All `defr`/`solve` tests pass through propagator path | Tests pass under both strategies (T-b 15/15 parity); most default queries still go through DFS | **Large (literal)**. The "Validated ≠ Deployed" pattern (longitudinal, 3+ PIRs) applies. |

### 3.2 Stated success criteria vs measured

| Success criterion | Measured | Status |
|---|---|---|
| All 95 test files pass with `:strategy :atms` | 15 solver-exercising files tested in T-b, all BOTH PASS | ⚠️ **Scope not explicitly matched** — unclear what specific 95 files the design meant; 15 was the actual solver-test file count per audit. Parity validated for the actual set. |
| A/B benchmarks show ≤15% regression vs DFS | Tier 1: 2.3x *faster* than DFS (62x improvement). Tier 2 (clauses): 6-11x *slower* than DFS. | ⚠️ **Partial pass**. Tier 1 wildly beats target; Tier 2 badly misses. Adaptive dispatch mitigates the Tier 2 gap by routing to DFS. |
| Parallel executor shows speedup on N≥4 clause benchmarks | No speedup below N≈256. Crossover at N=128 in original Phase 0c; Phase 2c's semaphore pool pushed to N≈256 before seeing 1.6x at N=512. | ❌ **Not met as stated**. Phase 2d exhaustive investigation showed the N≥4 target was unreachable on Racket. |

### 3.3 Emergent objectives (not in D.1 but delivered)

Mid-track, objectives expanded through design iterations D.11-D.13 and the mantra audit:

- **On-network redesign (Phase R)**: 6 architectural cleanups not in the original design. Driven by the mantra audit, not the stated objectives.
- **Tier 1 direct return (universal)**: 62x speedup by skipping BSP for fact-only relations. Emerged from Phase 5a measurement — not designed.
- **Adaptive `:auto` dispatch**: Emerged from Phase 6 crossover measurements; the stated "auto → propagator" was replaced.
- **Parity regression suite (Phase T)**: Emerged from 2 test-wf-comparison failures; evolved into a permanent regression gate (test-solver-parity.rkt, 15 tests, 10 classes).
- **Design mantra codification (4 rules files)**: Triggered by mid-track user introduction; not in D.1 but durable.

### 3.4 Deferred work (explicit tracking)

| Item | Why deferred | Tracked in |
|---|---|---|
| `:auto` default flip for clause queries | Measurement shows DFS faster at practical sizes; adaptive dispatch is the principled answer | Per "Validated ≠ Deployed" rule, the adaptive implementation IS the deployment — but the pattern continues if we don't re-examine once workloads change |
| TMS dead-code removal (~200 lines in propagator.rkt) | Low-priority cleanup, not blocking | DEFERRED.md |
| Tier 1 extension to single-clause simple bodies | Could cover more queries; out of Track 2B scope | DEFERRED.md |
| Streaming BSP enablement below N≈256 | Racket floor; awaits self-hosting with heavier per-propagator work | SH Series placeholder in Master Roadmap |
| Concurrency runtime (CDR) integration with `defproc`/`session` | Self-hosting prerequisite, not Phase 0 | SH Series placeholder |

**Scope adherence (honest accounting)**: ~60% of Design D.1's literal objectives delivered as written; ~40% redirected mid-track by measurement and design mantra audit. The redirections produced a *better* architecture than the original design (adaptive dispatch, on-network Phase R, Tier 1 universal), but that's separate from "did we do what we said we'd do." We did not.

---

## 4. Test Coverage

**New test file**: `tests/test-solver-parity.rkt` (274 lines, 15 tests, Phase T-c). Ten divergence classes covered: Tier 1 facts, single clause, multi-clause, NAF ground succeeds/fails, 2-strata / 3-strata chains, guards, mixed positive+NAF, gating-only (0-arity + with-vars), undefined NAF target, multi-fact narrowing.

**Modified test files**: `test-solver-config.rkt` (threshold 4→256 for Phase 6), `test-stratified-eval.rkt` (parameterized `current-solver-strategy-override` for batch-worker isolation), `test-propagator.rkt` + `test-observatory-01.rkt` + `test-trace-serialize.rkt` (cell count expectations updated 3 times across Phase R).

**Test growth**: 7529 → 7765 (+236). The growth spans test files not created by this track but enabled/extended: discrimination tests from Phase 1a, PU branching tests, on-network cell tests, parity tests in T-c.

**Gaps**: No acceptance `.prologos` file for Track 2B — this track was infrastructure-only with no user-facing syntax changes. The existing `2026-03-14-wfle-acceptance.prologos` covers solver integration indirectly.

---

## 5. Bugs Found and Fixed

Fourteen concrete bugs. I've grouped by root-cause class.

### 4.1 Fire Function Closure Capture (Phase 1a)

The discrimination propagator's fire function used `n` (the outer `for/fold` accumulator) instead of its `net` parameter. When called with the BSP snapshot network, writes went to the stale installation-time network. Silent wrong results — tests passed but multi-clause queries returned 1 result instead of 5. Fix at `683e2ff3`; codified in `propagator-design.md`. **Seeming correctness**: inside a `for/fold`, `n` was the "obviously right" variable to use; single-letter names + closure capture hid the shadowing. **Prevention**: fire functions now use `net` as the lambda parameter name, never `n`/`m`.

### 4.2 Step-Think Tree Traversal (Phase 1b)

Implementation traversed the discrimination tree in imperative order to install fact-row propagators. This worked but was step-think — the tree's shape imposed ordering that should emerge from dataflow. User caught it during review; reverted to flat installation + BSP-emergent ordering. `cb4758f4`. **Seeming correctness**: the tree structure was already computed, so walking it felt natural. **Prevention**: design mantra as gate (codified post-track).

### 4.3 Bridge Propagator Tag Collapse (Phase 2a, D.12 attempt)

Bidirectional bridge propagators between clause scope and query scope used `logic-var-read` (worldview-filtered) which collapsed tagged entries into a merged value, losing per-branch identity. Multi-result NAF composition returned 1 result instead of 3. Exhaustive debugging across 4 design iterations (D.9 probe → D.10 NAF bitmask → D.11 stratified → D.12 worldview assumption). **Root cause not fix but reframing**: Resolution B (scope sharing, Module Theory — bitmask layers on shared carrier cell) eliminated bridges entirely. `a6b02159`. **Seeming correctness**: bridges are a standard propagator pattern; "bidirectional bridges with fmap" felt textbook. The failure mode was invisible because it only manifested under multi-level worldview composition.

### 4.4 S1 Fork Infinite Recursion (Phase R4)

The S1 NAF handler forked the network for inner goal evaluation. The fork inherited the NAF-pending cell contents, so the fork's BSP re-processed S1 on the same request, forked again, ad infinitum. Fix: `net-cell-reset` clears NAF-pending on the fork before inner BSP. `8fbc342b`. **Seeming correctness**: forks inherit all state via CHAMP structural sharing — that's their purpose. The NAF-pending case requires explicit clearing. **Prevention**: documented as "Fork inherits all cell state" in the mantra-audit findings.

### 4.5 Fresh Inner Vars for Ground Args (Phase R4)

S1 handler created fresh inner scope-refs for ALL argument positions, including ground ones. `(gv 15)` became `(gv ?x_inner)` which matched any fact. Fix: only create inner vars for unresolved scope-refs; ground args pass through. **Seeming correctness**: `build-var-env` takes a list; easier to make all args vars than to distinguish. **Prevention**: argument classification (resolved/unresolved) before inner goal construction.

### 4.6 Belt-and-Suspenders Fire-Once (Phase 5a)

Initial Phase 5a added BOTH the scheduler-level `PROP-FIRE-ONCE` flag AND kept the closure wrapper from the old implementation. User flagged "belt-and-suspenders" as a workflow red flag. Investigation revealed a Tier 1 detection bug hidden by the wrapper: the bitwise check `flags & (A|B)` passed when EITHER flag was set (should require BOTH). Fix: `flags & (A|B) == (A|B)`. Wrapper removed. `2181fac0`. **Seeming correctness**: both mechanisms worked; removing either would reduce defense-in-depth. **Prevention**: belt-and-suspenders is a code smell, not a safety pattern — it masks bugs in the new mechanism.

### 4.7 Tier 1 Zip Bug (Phase 5b/5c)

`for/fold` zipped effective-args (2 elements) with query-vars (1 element) — Racket's `for/fold` stops at the shortest sequence, so only position 0 was checked. Facts with 2 args matched incorrectly. Fix: iterate `effective-args` and `row` independently, checking each position against query-vars membership. **Seeming correctness**: zipping parallel lists is standard Racket idiom. The length mismatch was invisible without traced output. **Prevention**: explicit length checks for parallel iteration over semantically-paired lists.

### 4.8 AST vs Raw Value Comparison (Phase 5b)

Fact values from `.prologos` files are AST nodes (`expr-string "evil"`); fact values from test stores are raw values (`"evil"`). DFS solver's `equal?`-based unification returned `#f`. Fix: PPN boundary normalization — `normalize-solver-value` at data entry (discrimination data, discrimination propagators, S1 NAF handler). Eliminates an entire bug class. `01de93f5`. **Seeming correctness**: the two code paths worked independently; the difference only surfaced at the boundary between them. **Prevention**: normalize at domain boundaries, not at each consumer.

### 4.9 CWA Undefined Relation Silent No-Op (Phase T-a, Fix 1)

`install-clause-propagators` returned the network unchanged when the relation wasn't in the store. Under stratified semantics, undefined negation targets should error (DFS behavior). The propagator solver silently applied closed-world assumption to something outside the program. Fix: error on undefined. `1eb8b8cc`. **Seeming correctness**: "return nothing" feels CWA-correct for missing data; the semantic distinction is that CWA closes over DEFINED predicates, not undefined ones. **Prevention**: `semantics` configuration defines contract; all solver paths must honor the same contract.

### 4.10 Discrimination as Provability Proxy (Phase T-a, Fix 2)

S1 handler's ground provability check used static discrimination data (alternatives compatible with args?) as a proxy for provability (did the clause body succeed?). For multi-strata NAF chains where the inner clause's body has its own NAF that fails (nogood), discrimination still said "provable" — because the clause exists structurally. Fix: call `solve-goal` (DFS) for the actual provability check. `1eb8b8cc`. **Seeming correctness**: discrimination IS a necessary condition; the gap is that it's not sufficient. **Prevention**: necessary ≠ sufficient; provability checks must be actual evaluation.

### 4.11 0-Arity Dissolution Gap (Phase T-a, Fix 3)

Dissolution reads scope cells to produce results. For 0-arity queries (empty `query-vars`), there are no scope cells. Gating-only clause bodies produce no scope writes → dissolution returns empty even when gating succeeds. Fix: 0-arity queries delegate to DFS. Documented as a structural limitation of the scope-cell result model, not an ATMS bug. `1eb8b8cc`. **Seeming correctness**: scope-cell dissolution is the general mechanism; 0-arity looked like "just a special case." **Prevention**: enumerate structural limitations of the result-production mechanism at design time.

### 4.12 Gating-Only Body No Scope Writes (Phase T-a, Fixes 4+5)

Clauses whose bodies consist entirely of gating goals (NAF/guard, no positive goals) produce no scope-cell writes. Dissolution reads nothing → 0 results even when gating succeeds. Fix: install-conjunction writes empty-scope-cell success marker under the combined gating bitmask when `all-gating?`. Dissolution collects these separately with `hash-empty?` guard (distinguishes from promoted base entries with bot bindings). `1eb8b8cc`. **Seeming correctness**: positive goals always bind vars in familiar logic programs; gating-only bodies are unusual. **Prevention**: structure analysis — does this code path produce the signal the downstream mechanism expects?

### 4.13 Per-Variable Split Entries Cross-Product (Phase T-a, Fix 6)

Fact-row propagators write x and y to the scope cell in SEPARATE `net-cell-write` calls → two tagged entries at the same bitmask (bm=3: {x="a"} AND bm=3: {y="b"}) instead of one merged entry. Dissolution's grouping treated them as independent branching sites, product computation generated compound worldviews (3|5=7) that combined independent fact rows. Results: 4 instead of 2 (one duplicate from each shared bitmask in the cross-product). Fix: pre-merge same-bitmask entries before grouping. Also: deduplicate product worldviews as defense-in-depth. `35a39865`. **Seeming correctness**: separate writes is the natural pattern for multi-variable binding; the bug only surfaces when multiple entries at the same bitmask create an artificial cross-product. **Prevention**: this one is subtle; propagator writes at the same worldview should semantically compose, so dissolution should merge them before structural analysis.

### 4.14 Batch-Worker Parameter Leakage (Phase T-a side-effect)

The batch worker uses `dynamic-require` in a shared process, so tests don't get fresh parameter scopes between files. `current-solver-strategy-override` was not in `test-stratified-eval.rkt`'s `run-prologos-string` parameterize block. Added to scope it explicitly. Individual test passed, batch runner failed. **Seeming correctness**: the parameter defaults to `#f`; most tests don't touch it. The batch runner's `dynamic-require` behavior is underdocumented. **Prevention**: test isolation functions must parameterize ALL solver-related parameters, not just those the test uses.

---

## 6. What Went Well

Things that worked — not as general platitudes, but as specific decisions or practices that paid off and should be repeated.

### 6.1 Design mantra as live gate (introduced mid-track)
The mantra — *"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK"* — was codified in 4 rules files mid-track. It caught 6 architectural violations that tests had missed. The audit triggered Phase R (6 sub-phases, ~5h active implementation), which would not have happened without the mantra. Every subsequent propagator design decision passed through the mantra challenge at each word. **Repeat**: apply the mantra at every `for/fold`, every parameter, every return value, every propagator installation.

### 6.2 Phase R as a coherent unit
Rather than incremental fixes for each of the 6 violations, Phase R fixed all of them together. Each fix interacted with the others (relation store on-network → discrimination data derivation propagators → goal installation propagator-mediated → general N-stratum infra → fact-row PU as per-row propagators → PU dissolution as egress cell). Incremental fixes would have required reworking earlier ones. **Repeat**: when an architectural audit finds related violations, fix them in one coherent pass.

### 6.3 Module Theory resolved a bug class, not an instance
After 3 failed attempts (D.9 probe, D.10 bitmask, D.11 stratified) to fix multi-result NAF composition, Resolution B (scope sharing via Module Theory's direct-sum-via-tagging) eliminated bridges entirely. Not "better bridges" — *no bridges*. This resolved the tag-collapse bug class, not one instance. **Repeat**: when patching keeps failing, look for the algebraic structure that eliminates the bug class.

### 6.4 Tier 1 skip-mechanism insight
Tier 1 direct fact return delivered 62x speedup (30.6μs → 0.49μs) by *skipping* the BSP entirely rather than optimizing it. Phase 5a's in-network optimizations delivered ~5% improvement. The biggest win wasn't making BSP faster — it was recognizing when BSP isn't needed. **Repeat**: before optimizing a mechanism, ask whether there's a class of inputs for which the mechanism isn't needed at all.

### 6.5 PPN boundary normalization (cross-track pattern transfer)
The PPN Track 1 insight — *normalize at the domain boundary, not at each consumer* — transferred cleanly to the solver's AST/raw value handling. One function (`normalize-solver-value`) at data entry (fact rows, discrimination data, NAF env) eliminated a whole bug class. **Repeat**: when a value crosses a type boundary, normalize once at the boundary.

### 6.6 Parity regression suite as design artifact
`test-solver-parity.rkt` (T-c, 15 tests, 10 classes) is more valuable than the literal "default flip" objective. It encodes the divergence classes discovered during T-a as permanent regression tests. Future work can experiment with dispatch strategies without fear of silent semantic drift. **Repeat**: for any architectural parity requirement, build the parity regression suite during the track, not as a PIR follow-up.

### 6.7 Conversational cadence preserved architecture
Every decision point was a conversation: user challenges ("N+1?", "belt-and-suspenders?", "what's Phase T?", "let's open up design considerations around X") consistently improved decisions. 13 design iterations emerged through conversation, not monologue. Phase R itself was triggered by a user challenge. **Repeat**: dialogue checkpoints at phase boundaries. Autonomous stretches longer than ~1h consistently produce architectural drift (this is confirmed across multiple PIRs).

### 6.8 Handoff protocol survived context compaction
Context compacted at `2392a2d9` between Phase 6 and Phase T. Sessions G and H post-compaction re-read the handoff document + design doc + dailies, then continued T-a/T-b/T-c without architectural drift. No re-learning required. **Repeat**: write handoff documents at phase boundaries under context pressure, not at session end.

---

## 7. Where We Got Lucky

Things that could have gone worse. Per Google SRE, this section requires intellectual honesty — luck is not a strategy, and anything that relied on it should be hardened.

### 7.1 Hash iteration order Heisenbug exposed a latent bug

The dissolution duplicate-results bug (safe-edge 4 vs 2) was latent from Phase 2a. Lucky hash iteration order in other workloads hid it. It surfaced because adding debug code to `test-stratified-eval.rkt` changed compilation → memory layout → hash iteration order → exposed the duplicate. **Luck**: had we not added debug output during T-a investigation, the bug could have hidden longer, manifesting later on different inputs. **Hardening done**: pre-merge step enforces determinism; product-worldview dedup as defense-in-depth. **Hardening NOT done**: no systematic hash-iteration-order fuzz testing. Future bugs of this class could recur.

### 7.2 The 2a bridge collapse wasn't "fixed" with partial patches

We attempted 4 approaches before Module Theory resolved it (probe vars, NAF bitmask, success cell, stratified). Each worked for basic cases. We could have shipped the first "good enough" partial patch and left multi-result composition broken, treating it as an edge case. **Luck**: user's N+1 Principle challenge pushed past "good enough" to the algebraic resolution. **Hardening**: N+1 Principle is now codified in workflow.md; should survive author changes.

### 7.3 S1 NAF infinite recursion was bounded by fuel

The S1 fork handler inherited NAF-pending contents and re-processed them, forking infinitely. **Luck**: fuel limit (1,000,000 firings) bounded the recursion before it ran out of memory. A more realistic workload (or a fuel-unlimited configuration) would have hung or exhausted memory. **Hardening**: explicit `net-cell-reset` on fork; codified as "Fork inherits all cell state" in the mantra-audit findings.

### 7.4 Belt-and-suspenders was caught early

Phase 5a initially added BOTH the closure wrapper AND scheduler flags. User flagged "belt-and-suspenders" as a workflow red flag within the same session. **Luck**: if the wrapper had been kept as "defense in depth," the Tier 1 bitwise bug (`flags & (A|B)` passing when either bit set) would have stayed hidden behind the wrapper. Tests would have passed because the wrapper prevented the double-fire. The bug would have surfaced only when the wrapper was later removed. **Hardening**: "belt-and-suspenders is a red flag" codified in workflow.md. The rule needs repetition — this is the 3rd PIR where it recurred.

### 7.5 Phase R 33% regression was recovered (and exceeded)

Phase R added 7.6μs overhead per single-fact query (23μs → 30.6μs — a 33% regression). **Luck**: Tier 1 direct return (Phase 5b/5c) recovered this and then some (30.6μs → 0.49μs, 62x improvement). Without Tier 1, Phase R would have shipped a net regression. **Hardening**: per-phase benchmark measurement caught the regression immediately; the architectural insight (skip mechanism ≫ optimize mechanism) emerged from this specific context.

### 7.6 Test-stratified-eval batch runner issue was latent

The batch worker's `dynamic-require` shared-process model leaked parameters between tests. This was discovered only because safe-edge was *already* failing due to the dissolution bug — the batch worker behavior was different from individual `raco test`, which surfaced the issue. **Luck**: without the dissolution bug, we might not have noticed the batch-worker isolation gap. **Hardening**: `current-solver-strategy-override` added to `run-prologos-string` parameterize block; stale .zo detection extended to cover test files; the test harness parameterize pattern is now mandatory.

### 7.7 Threshold 256 happened to match BSP pool crossover

Phase 6's adaptive dispatch threshold is 256 for large-clause-set → ATMS. This matches the Phase 2c benchmark crossover (pool 1.6x faster at N=512, tied at N=256). **Luck**: the threshold naturally fell on an empirically-justified value. If the threshold had been arbitrary, adaptive dispatch would have routed poorly in the crossover region. **Hardening**: the threshold is configurable via `solver-config`, so users can tune for their workload.

### 7.8 Handoff protocol worked on first use for this track

Phase T post-compaction was the first time this track used the handoff protocol. It worked. **Luck**: the handoff document was written carefully (per HANDOFF_PROTOCOL.org) with the key files, design decisions, surprises, and hot-load reading order. A less-thorough handoff would have caused re-learning or missed context. **Hardening**: the handoff document (`2026-04-16_BSP_LE_2B_HANDOFF.md`) is now an exemplar that future handoffs can reference.

---

## 8. What Surprised Us

Surprises are the richest source of learning — they reveal gaps in our mental model. Per the methodology.

### 8.1 Racket parallelism has a hard ~8μs floor

Phase 0c estimated thread crossover at N≈128 with 1.9x speedup. Phase 2d's exhaustive investigation revealed the crossover is actually **N≈256** due to OS thread wakeup cost (~8μs). Four alternative approaches benchmarked (spin-wait, sync events, async-channel, spin-poll-done-semaphores); all were worse than sync pool. No Racket-level mechanism beats the OS wakeup cost. **Surprise magnitude**: Phase 0c's design-time estimate was off by 2x in crossover and completely wrong about speedup availability below that. **Mental model update**: Racket's concurrency primitives have a fundamental floor that bounds propagator parallelism below ~0.5μs work granularity.

### 8.2 Tier 1 delivered 62x; BSP ceremony delivered ~5%

We expected BSP-level optimizations (fire-once flags, self-clearing fired-set, template forking) to drive the big wins. They delivered ~5% improvement. **Tier 1 (skip BSP entirely) delivered 62x.** **Surprise magnitude**: large. The measurement reframed the optimization work mid-Phase 5. **Mental model update**: structural overhead (allocation, cell writes, scheduling) is fixed; the only way to eliminate it is to bypass it. The skip-mechanism insight is now a general optimization principle (§16.4).

### 8.3 Tests passed but architecture was wrong

The design mantra audit found 6 architectural violations that the passing test suite hadn't surfaced. **Surprise magnitude**: large. Tests verify correctness of outputs; they don't verify that the architecture IS structurally emergent information flow. **Mental model update**: tests are insensitive to the on-network/off-network distinction. The mantra (or something like it) is the missing gate.

### 8.4 Module Theory gave a decomposition we hadn't considered

After 3 failed NAF approaches, the user suggested "Resolution B" based on Module Theory — direct-sum decomposition realized as bitmask tagging on a shared carrier cell. Not separate cells with morphisms. **Surprise magnitude**: medium. The algebraic framework suggested a realization we hadn't enumerated. **Mental model update**: when considering separate cells with bridges, always ask — is there a tagged-shared-cell realization? Usually yes. Codified in §6.3.

### 8.5 Belt-and-suspenders actively hid a bug

We thought dual mechanisms were defensive. They masked the Tier 1 bitwise check bug (`flags & (A|B)` passing when EITHER flag set, should require BOTH). **Surprise magnitude**: the category is now known (3+ PIRs), but each instance still surprises because it feels like "safety." **Mental model update**: belt-and-suspenders isn't safety; it's bug-hiding. If two mechanisms can mask a bug in either, they're not independent.

### 8.6 Hash iteration order affected correctness, not just performance

A latent dissolution bug was hidden by lucky hash iteration order. Adding debug code to the test file changed compilation → memory layout → iteration order → exposed the bug. **Surprise magnitude**: large. Hash iteration order is usually a performance concern, not a correctness concern. Here it was the difference between "test passes" and "test fails." **Mental model update**: Heisenbugs point to missing determinism invariants. The fix isn't making the bug deterministic — it's enforcing the invariant (pre-merge same-bitmask entries before structural analysis).

### 8.7 The `raco make driver.rkt` + `--no-precompile` gap

`raco make driver.rkt` recompiles production code but NOT test files (tests aren't in driver.rkt's dependency graph). `--no-precompile` bypasses the suite runner's own compilation step. Combined, test `.zo` files stay stale — and the batch worker's `dynamic-require` trusts cached .zo. **Surprise magnitude**: medium. The build infrastructure had a silent gap. **Mental model update**: never `--no-precompile` after manual `raco make driver.rkt`. Extended stale-.zo detection to cover test files (`946a98ac`).

### 8.8 Gating-only clause bodies — a normal case we hadn't modeled

`c :- not b.` (0-arity clause with gating-only body) is a standard logic programming pattern. The propagator solver's dissolution had no mechanism for it — gating goals don't write to scope cells, so dissolution read nothing even when gating succeeded. **Surprise magnitude**: medium. The dissolution design implicitly assumed positive goals would produce scope writes. **Mental model update**: result production in propagator solvers requires explicit success signals, not just absence of failure. Success-marker writes under the gating bitmask close this gap.

### 8.9 13 design iterations were required

D.1 through D.13. Design evolved through: NAF mechanism (D.9 → D.10 → D.11 → D.12), relation store on-network (D.13), Resolution B scope sharing (in D.13 post-mantra), Phase R audit findings (in D.13). **Surprise magnitude**: medium-to-large. Typical tracks land in 3-5 iterations; this one took 13. **Mental model update**: when a design area is genuinely novel (no prior art for the exact problem), iteration count scales. Compositional NAF (multi-result + multi-strata + worldview composition) was genuinely novel — our prior art covered pieces but not composition. Iterations were necessary, not wasteful.

---

## 9. Architecture Assessment — How It Held Up

Did Track 2B integrate cleanly with existing systems? Which extension points worked, which required modification?

### 9.1 Track 2 infrastructure held up perfectly

The ATMS solver (Track 2) delivered solver-context, compound cells (decisions-state, commitments-state, scope-cell), tagged-cell-value, worldview bitmask infrastructure. Track 2B built heavily on all of these and *did not modify* the core Track 2 abstractions. Scope sharing (Resolution B) used Track 2's scope cells in a new way (direct mapping rather than via bridges), but the cells themselves were unchanged.

**Held up**: worldview bitmask pattern, tagged-cell-value merge, scope cell merge function, solver-context, ATMS assumption allocation. All used extensively; none modified.

### 9.2 PAR Track 1's BSP infrastructure integrated cleanly

The BSP scheduler (PAR Track 1) with stratum handlers was the integration point for Phase R4's NAF S1 handler. `register-stratum-handler!` + request-accumulator cell pattern generalized from topology-only to N-strata without new mechanisms. The handler contract (`(net pending-hash) → net`) was unchanged.

**Held up**: BSP outer loop, topology handler pattern, request-accumulator cells, fuel bounded fixpoint iteration.

### 9.3 Phase R's on-network redesign was structural, not mechanical

Phase R moved 6 components on-network. Each was a structural shift (parameter → cell, construction-time write → fire-once propagator, imperative scan → stratum handler + cell), not a rewrite. The shift required extending primitives (6 well-known cell IDs reserved 0-5, per-propagator cell-id namespaces for parallel allocation, general strata list), but the propagator model itself accommodated all of it.

**Extended**: `PROP-FIRE-ONCE` / `PROP-EMPTY-INPUTS` flags on propagator struct. Per-propagator cell-id namespaces (high-bit encoding). Well-known cells (0-5) in `make-prop-network`.

**Unchanged**: `net-add-propagator` contract, `net-cell-write`/`net-cell-read` interface, CHAMP-backed persistence, fork semantics.

### 9.4 NTT interface alignment held

Phase R6 aligned PU dissolution with NTT's `interface SolverNet :outputs [answers]` pattern — the answer-cid is an egress cell (total sink, no internal readers), dissolution writes to it after quiescence. This matched the NTT vision cleanly. **Validation**: the NTT design vocabulary (`interface`, `:inputs`, `:outputs`, `cell`, `propagator`) maps directly to the solver's structure.

### 9.5 Friction points

**PPN boundary normalization crossed a boundary the design didn't anticipate.** AST-node values from `.prologos` elaboration vs raw values from test stores — the solver had multiple sites handling this inconsistently. The `normalize-solver-value` function (Phase 5b/5c) was the integration fix: one function at the boundary, all sites normalized. The underlying friction: no explicit typing of "what enters the solver" at the relation-info boundary.

**Batch-worker parameter isolation is a persistent friction.** The batch runner's `dynamic-require` in a shared process doesn't auto-isolate parameters. This is a longitudinal pattern (Pattern 7 in §17 longitudinal survey: "Two-Context Boundary Bugs," 6+ PIRs). Track 2B discovered `current-solver-strategy-override` wasn't in the test harness's parameterize block. The fix is pattern-level (always parameterize all solver params), not architectural — which means the friction persists.

**Dissolution's cross-product of per-variable entries was a subtle gap.** Fact-row propagators write x and y to the scope cell in separate writes; dissolution treated them as independent branching sites. The pre-merge step (§13, T-a Fix 6) bridges the gap — but the underlying design assumption (one entry per branch) doesn't hold when propagators write multiple variables separately. This is a friction between the design intuition and the implementation reality.

### 9.6 Multi-stratification as a first-class architectural pattern

Track 2B is the first Prologos piece to deliver **multiple stratifications coexisting on the same propagator base**, using a unified generalized mechanism:

| Stratum | Kind | Introduced | Handler |
|---|---|---|---|
| S0 | monotone propagator firing within a BSP round | pre-track | (no handler — base stratum) |
| Topology | structural changes between rounds (new cells, new propagators) | PAR Track 1 (`775de006`, 2026-03-28) | `register-topology-handler!` (special-cased) |
| S1 NAF | non-monotone worldview validation via fork+BSP+nogood | Track 2B Phase R4 (`8fbc342b`, 2026-04-14) | `register-stratum-handler!` (generalized) |
| S0 Guard | monotone condition evaluation with worldview assumption | Track 2B Phase 3 (`83276b0d`) | Embedded in S0 via worldview bitmask (no separate handler) |

**Two things landed in Phase R4**, not one:

1. **The second concrete stratum** — S1 NAF joined topology as a stratum above S0
2. **The stratification itself as a general pattern** — Phase R4 extracted the pattern from PAR Track 1's topology-specific handler and generalized it to N strata with a uniform (request-accumulator cell + handler function) interface. Topology is now one application of the general mechanism, not a privileged special case.

**Architectural significance**: stratification on the propagator base is now first-class, composable, and uniform. Future strata plug in via the same pattern — no gate cells, no per-stratum special mechanisms, no new primitives. Candidate future strata include well-founded semantics (S2 for odd cycles), cost-bounded exploration (tropical thresholds), constraint propagation at different activation levels, and self-hosting compiler passes. All would use the same infrastructure.

**Verification**: see `racket/prologos/propagator.rkt:2439-2444` (`stratum-handlers` box, `register-stratum-handler!`) and the BSP outer loop at line 2665 which processes `(unbox stratum-handlers)` uniformly. The topology handler at line 2448 registers via the same mechanism (though it predates the generalization and uses its own box — a cleanup candidate for unifying topology into the general strata list).

### 9.7 Net architectural assessment

Track 2 + PAR Track 1 infrastructure provided sufficient abstraction for Track 2B's scope. The modifications Track 2B made (propagator flags, well-known cells, per-propagator namespaces, general strata) are *extensions*, not *changes*. The core propagator model held. **The mantra audit was the architectural validation**: the system as designed supported on-network computation; the violations were implementation drift, not architectural gaps. The multi-stratification generalization (§9.6) is the track's most reusable architectural contribution — it's infrastructure for a class of future problems, not just NAF.

---

## 10. Design Decisions and Rationale

### 5.1 Design Mantra as First-Class Gate

Mid-track, the user introduced "All-at-once, all in parallel, structurally emergent information flow ON-NETWORK" as a design challenge to apply at every decision point. Codified in 4 rules files (`on-network.md`, `propagator-design.md`, `workflow.md`, `structural-thinking.md`). The mantra caught 6 architectural violations tests had missed — relation store as parameter, fact-row PU using `for/fold`, ground unify as construction-time write, imperative S1, result reading off-network, `for/list` in bridges. All six were addressed in Phase R. **Rationale**: tests verify what the code does; the mantra verifies what the architecture is. The two don't overlap.

### 5.2 Scope Sharing over Bridges (Resolution B, Module Theory)

Multi-result NAF composition kept failing because bridge propagators collapsed tagged entries. Three failed attempts (worldview bitmask isolation, probe vars, NAF-success cell). Resolution B: eliminate clause-level scope decomposition entirely. Clause params share the query scope directly; module decomposition (`R = C₁ ⊕ ... ⊕ Cₙ`) is realized as bitmask layers on the shared carrier cell, not as separate cells with morphisms. **Rationale**: Module Theory says direct sum via tagging is a valid decomposition; doesn't require separate cells with bridge morphisms. Eliminated the entire tag-collapse bug class (not just fixed one instance). **Rejected**: Resolution A (tag-transparent bridges with fmap) — more complex, still has indirection.

### 5.3 NAF and Guard as Worldview Assumptions (Unified Pattern)

Both are gating goals that condition subsequent computation. Both allocate assumptions via `solver-assume`, tag subsequent goals with the combined bitmask, write nogoods for failure. NAF evaluates at S1 (non-monotone — inverts provability). Guard evaluates at S0 (monotone — condition known once inputs resolve). **Rationale**: reuses existing ATMS infrastructure. `install-conjunction` pre-scans for both (gating-kinds = `'(not guard)`). **Rejected**: NAF as threshold propagator at S0 (non-monotone can't be at S0 — CALM violation); guard as topology request (over-complicated); gate cells (new mechanism; doesn't align with existing request-accumulator pattern).

### 5.4 General N-Stratum Infrastructure

BSP outer loop processes N strata via (request-cell, handler) pairs. Same pattern as the existing topology stratum. No gate cells, no `#:stratum` flags on propagators. **Rationale**: propagators are stratum-agnostic; strata exist at the scheduler level. Adding S1 for NAF extends the existing structure rather than introducing a new mechanism. **Rejected**: gate cells (new primitive, not composable with existing patterns); propagator stratum flags (violates stratum-agnosticism — each propagator would need to declare what stratum it runs in, coupling to scheduling).

### 5.5 Fire-Once as Scheduler-Level Concept

`PROP-FIRE-ONCE` and `PROP-EMPTY-INPUTS` are flag bits on the propagator struct. Scheduler implements fired-set + self-clearing. No closure wrapper. **Rationale**: scheduler can skip fired propagators at zero cost; self-clearing removes from input cells' dependents list (no future enqueuing). Belt-and-suspenders hid a real Tier 1 detection bug — removing the wrapper forced proper diagnosis. **Rejected**: closure wrapper only (scheduler can't optimize — must enter the function to check the closure's "fired?" state); belt-and-suspenders with both mechanisms (masks bugs).

### 5.6 Tier 1 Direct Fact Return

Single-variant, fact-only relations bypass ALL solver infrastructure. Direct matching with PPN boundary normalization. 62x speedup (30.6μs → 0.49μs). **Rationale**: Phase R caused a 33% regression (7.6μs per query). The biggest optimization wasn't making BSP faster — it was recognizing when BSP isn't needed. **Rejected**: BSP ceremony optimization (negligible impact — the overhead is structural, not algorithmic).

### 5.7 PPN Boundary Normalization

`normalize-solver-value` at data entry (domain boundary), not at each comparison site. AST nodes → raw values once. **Rationale**: PPN Track 1 insight: normalize at the domain boundary. Eliminates AST/raw comparison bugs across ALL matching sites. **Rejected**: per-site `normalize-for-compare` (duplicated, error-prone — we had this at N sites before).

### 5.8 Adaptive `:auto` Dispatch

Tier 1 (facts) → direct; NAF/guard → ATMS (mandatory — requires worldview); N ≥ 256 → ATMS (parallel benefit); else → DFS (6-11x faster at practical sizes). Threshold matches BSP pool crossover from Phase 2c benchmarks. **Rationale**: DFS and ATMS have different sweet spots. `:auto` routes to the right one per query. **Rejected**: binary flip to ATMS (wasteful for clause queries < 256 alternatives); count-only threshold (misses NAF/guard requirement).

### 5.9 Racket Parallelism Ceiling (Accepted)

OS thread wakeup ~8μs dominates all cross-thread communication. Sync pool crossover at N≈256. Exhaustive 2d investigation: spin-wait, sync events, async-channel, spin-poll — all ≥ sync pool. **Rationale**: no Racket-level mechanism beats the OS wakeup cost. Strategic decision: wait for self-hosting where per-propagator work increases. **Rejected**: FFI to C for lightweight threads (throwaway — self-hosting replaces); streaming BSP (overhead > benefit).

### 10.10 N+1 Principle as Design Practice

User challenge mid-track: "When considering N options, ask what's the N+1th?" Applied at multiple decision points. NAF stratification: N options = threshold / probe / success cell → N+1 = fork-based S1 handler. Bridge composition: N options = better bridges / fmap / tag-transparent → N+1 = no bridges (scope sharing). Parallelism: N options = faster BSP / async / spin → N+1 = skip BSP (Tier 1). **Rationale**: the obvious options converge on "more of the same"; the breakthrough option is usually in a different category entirely.

---

## 11. Wrong Assumptions

Not what broke — what we *believed* that turned out to be false. Wrong assumptions are more dangerous than bugs because they're invisible until they cause problems.

### 11.1 ATMS would be the default, DFS a fallback
**Believed**: propagator solver is strictly better; DFS retained only for compatibility. **Truth**: DFS is 6-11x faster for practical clause queries (N<256). ATMS's worldview machinery has fixed overhead that doesn't amortize below large clause sets. **How it manifested**: Phase 6 measurement forced adaptive dispatch. The D.1 literal objective (`:auto → propagator`) was quietly abandoned.

### 11.2 Parallel executor would benefit workloads at N≥4
**Believed**: thread-based parallelism would speed up multi-clause queries starting at small N. **Truth**: Racket OS thread wakeup (~8μs) dominates below N≈256. **How it manifested**: Phase 2d's exhaustive investigation (4 approaches benchmarked). The parallel infrastructure is architecturally correct but the payoff is bounded by Racket's primitives.

### 11.3 NAF needs an async propagator with a result cell
**Believed** (in D.1-D.10): NAF would be an async propagator that spawns a thread to evaluate the inner goal, writes result to a cell, continues. **Truth**: NAF is fundamentally non-monotone; stratification is its natural expression. D.11 → D.13 redesigned NAF as an S1 worldview assumption — simpler, correct, composable. **How it manifested**: 3 failed attempts (D.9 probe, D.10 bitmask, D.11 stratified intermediate) before D.12 landed the right design.

### 11.4 Discrimination viability equals provability
**Believed**: if discrimination narrows to a non-empty viable set for ground args, the goal is provable. **Truth**: discrimination is a *necessary* condition, not *sufficient*. It checks structural compatibility (alternatives that could match), not runtime success (alternatives whose clause bodies succeed after NAF/guard evaluation). **How it manifested**: T-a Fix 2. The 3-strata test failed (0 results for `c :- not b. b :- not a. a.`) because the ground provability check used discrimination as a proxy. DFS call replaced it.

### 11.5 `raco make driver.rkt` covers the build graph
**Believed**: recompiling driver.rkt propagates to all dependents, including test files. **Truth**: test files aren't in driver.rkt's dependency graph. `raco make driver.rkt` leaves test `.zo` stale. **How it manifested**: several cycles of "test passes individually, fails in batch runner." Fix in `946a98ac` (stale-.zo detection extended to cover test files).

### 11.6 Belt-and-suspenders is defensive
**Believed**: keeping the old mechanism alongside the new one is safe defense. **Truth**: dual mechanisms mask bugs in the new one — when the old still "works" for the test case, the new's bugs stay hidden. **How it manifested**: Phase 5a closure-wrapper + scheduler flags masked a Tier 1 bitwise check bug (`flags & (A|B)` when either bit set, should be both). Removing the wrapper exposed the real bug. Pattern now in 3+ PIRs.

### 11.7 Bridges between scope cells are the right abstraction
**Believed**: multi-level scope composition uses bridge propagators with fmap (standard propagator pattern). **Truth**: bridges collapse tagged entries because bidirectional `logic-var-read` is worldview-filtered. Scope sharing via bitmask tagging on a shared carrier cell is simpler and doesn't collapse. **How it manifested**: 3 design iterations of bridge-based NAF composition before Resolution B (Module Theory direct-sum-via-tagging) eliminated bridges entirely.

### 11.8 0-arity queries would "just work" in the propagator solver
**Believed**: scope-cell-based result production was the general mechanism; 0-arity would be a special case of the general. **Truth**: 0-arity has no scope cells, so dissolution has nothing to read. Gating-only clause bodies produce no scope writes at any arity. **How it manifested**: T-a Fix 3 (0-arity DFS delegation) and T-a Fix 4 (success markers). The propagator model's result production isn't universal — it requires explicit success signals for certain clause body shapes.

### 11.9 Gating-only clause bodies are rare edge cases
**Believed**: most clause bodies mix positive goals and gating goals; gating-only is unusual. **Truth**: `c :- not b.` and `check-ok :- not(bad "alice")` are normal logic programming patterns. Standard textbook NAF patterns exercise this. **How it manifested**: T-a surfaced failures in `test-wf-comparison-01.rkt` (3-strata) and `test-relational-e2e.rkt` (gating-only with vars).

### 11.10 Hash iteration order doesn't affect correctness
**Believed**: hash iteration order is a performance concern; deterministic output requires explicit sorting. **Truth**: for this solver, iteration order affected *correctness* — it determined whether a latent dissolution duplicate-worldview bug manifested. **How it manifested**: debug output in a test file changed compilation → memory layout → iteration order → exposed the bug. Pre-merge + dedup now enforce determinism.

**Meta-observation**: 10 wrong assumptions in one track is a lot. Most were corrected by measurement (11.1, 11.2, 11.5), one by user challenge (11.6), three by debugging (11.4, 11.8, 11.10), three by architectural insight (11.3, 11.7, 11.9). The pattern: assumptions about *performance*, *correctness equivalence*, and *generality* are systematically too optimistic.

---

## 12. What We Learned About the Problem

Implementation always teaches things that research and design cannot. What do we now understand about the problem domain that we didn't when the track started?

### 12.1 NAF is stratification, not asynchrony

The pre-track intuition: NAF is a side channel — check the inner goal asynchronously, write the result to a cell, continue. The correct framing (landed in D.12): NAF is a non-monotone operation at a higher stratum than S0. Stratification is the standard logic-programming treatment; the propagator model accommodates it via request-accumulator cell + S1 handler. **Problem insight**: the asynchrony framing was fighting the math. Stratification makes the non-monotonicity explicit and structural.

### 12.2 Scope decomposition has two algebraic realizations; only one doesn't collapse

Module Theory direct sum R = C₁ ⊕ ... ⊕ Cₙ can be realized as (a) separate cells with morphisms (bridges), or (b) tagged shared cell with bitmask layers. Realization (a) collapses tags through bidirectional bridges; realization (b) doesn't. **Problem insight**: the algebraic framework admits multiple realizations with different computational properties. The "natural" realization (separate cells) is wrong for worldview-sensitive computation; the tagged realization is correct.

### 12.3 Result production requires explicit success signals

In DFS, a clause body that "succeeds" returns the current substitution — success is the default; failure is what must be signaled. In the propagator model, result production comes from scope-cell writes by positive goals — success must be signaled (writes happen) or it's indistinguishable from failure (no writes). **Problem insight**: propagator solvers need an explicit success protocol that DFS doesn't need. Gating-only clause bodies exposed this gap — they pass (assumptions survive) but produce no writes. The success-marker pattern (T-a Fix 4) is the explicit protocol.

### 12.4 Discrimination is structure, not semantics

Discrimination data captures structural compatibility (which alternatives' argument patterns match). It does *not* capture runtime behavior (which alternatives' clause bodies succeed). **Problem insight**: structural and semantic narrowing are different computations. The propagator solver conflated them briefly (T-a Fix 2). Future narrowing work should keep them separate.

### 12.5 Propagator parallelism in Racket has a fundamental floor

Per-propagator work in the current solver is ~0.5μs. Racket's cross-thread communication has a ~8μs floor. The arithmetic bounds parallelism from below: below 16x per-propagator work, parallelism is a regression. **Problem insight**: lightweight concurrency is a compiler/runtime problem, not a library problem. Self-hosting with heavier per-propagator work (~5-50μs) changes the arithmetic; Phase 0 Racket doesn't.

### 12.6 Pre-0 benchmarks are not optional

Phase 0b estimated ATMS overhead at 24.5x (single-fact); actual decomposition (scheduling 52.6%, install 30.4%, allocation 15.5%, read 0.4%) guided Phase 5's optimization targets. Without Phase 0b, we'd have optimized the wrong things. **Problem insight**: design-time intuition about where overhead lives is reliably wrong. Measurement is the only oracle. (This is now architectural — Pattern A in the longitudinal, 10/10 PIRs.)

### 12.7 Workload characteristics drive dispatch choice

Single-fact queries: ATMS 2.3x faster via Tier 1. Multi-clause queries: DFS 6-11x faster. Multi-clause queries with NAF: ATMS required (worldview). Large clause sets (N≥256): ATMS pays off via parallelism. **Problem insight**: there is no universal best strategy. Adaptive dispatch is architecturally correct; "flip to propagator" was always the wrong framing.

### 12.8 Stratification is a general pattern, not a specific mechanism

PAR Track 1 introduced the topology stratum — useful, but special-cased. Track 2B needed S1 NAF for non-monotone evaluation. The design mantra challenge ("no gate cells, no per-stratum flags") pushed toward a general mechanism: request-accumulator cell + handler function, same shape as topology, uniformly invoked by the BSP outer loop. **The problem insight**: what looked like "topology is its own thing and NAF needs its own thing" was actually "both are instances of a single pattern." Recognizing the pattern turned two mechanisms into one.

This has a deeper consequence: **the propagator base can host arbitrarily many strata** via the same pattern. Non-monotone retraction (S-1), well-founded semantics for odd cycles (S2), cost-bounded exploration, self-hosting compilation passes — all of these are candidate future strata that plug into the same mechanism. The infrastructure is one-for-all, not one-per-stratum.

**Problem insight**: multi-stratification on a propagator base isn't a collection of special cases; it's a compositional feature of the base itself. This reframes future work: when a new computation is non-monotone, context-dependent, or order-sensitive, the question becomes "which stratum does this belong in?" — not "what new mechanism does this need?"

---

## 13. Are We Solving the Right Problem?

Argyris's double-loop learning: question the goals, not just the methods. Did the implementation reveal that the real need is different from what the design addressed?

### 13.1 The stated problem vs the revealed problem

**Stated (D.1 §1)**: "Make the propagator-native solver the default solver." Implied: propagator path is strictly better; we just need to enable it.

**Revealed**: "Produce correct results efficiently regardless of strategy, with adaptive dispatch per query." No single strategy is universally best. The real need is:
1. **Semantic equivalence** across strategies (parity) — so choice doesn't affect correctness
2. **Workload-aware dispatch** — so choice affects performance per query's shape
3. **Configurable threshold** — so users can tune for their workload
4. **Permanent regression gate** — so future changes don't silently diverge

Track 2B delivered all four. The parity regression suite (`test-solver-parity.rkt`) is arguably the most valuable deliverable — it's the infrastructure that enables future work on dispatch, thresholds, and new strategies without fear of semantic drift.

### 13.2 Was the design mantra the right framing?

**Asked**: is "all-at-once, all in parallel, structurally emergent information flow ON-NETWORK" the right north star? **Answered by Phase R**: yes. The 6 violations it caught were real architectural drift. Tests didn't surface them because tests check outputs, not structural properties. The mantra is a genuinely necessary gate for propagator architecture.

**But**: applied literally, the mantra says everything should be on-network. The 0-arity DFS delegation (T-a Fix 3) is *off-network* — delegating to DFS. Is that a mantra violation? Honest answer: yes, it's a structural limitation of the current result-production model, acknowledged as scaffolding. The mantra doesn't say "no scaffolding ever"; it says "scaffolding must be labeled with a retirement plan." The 0-arity delegation is labeled as such (PIR §18 What's Next, §14 Technical Debt).

### 13.3 Did the longitudinal patterns change our framing?

**Pattern 5 (D:I ratio)** suggests 1.5:1 target for infrastructure tracks. Track 2B delivered at 0.55:1 calendar ratio but with 13 design iterations. The pattern is more nuanced than "design more": *iteration count* is a better proxy than *calendar time*. In-flight redesign (D.11 → D.12 → D.13 during implementation) is design investment too. **Framing update**: D:I ratio is a rough indicator; iteration count better captures design investment when the design space is genuinely novel.

**Pattern 7 (two-context boundary bugs)** recurred in Track 2B via batch-worker parameter isolation. The codified `pipeline.md` "Two-Context Audit" didn't prevent it — the checklist lists parameters but doesn't prevent new ones from being added without updating the checklist. **Framing update**: pattern-level documentation is not architectural-level intervention. For 5+ PIR patterns, systemic response is needed (automated two-context testing, parameter registration requirement).

### 13.4 What problem should the NEXT track solve?

Implied by what Track 2B didn't fully resolve:

1. **Flipping `:auto`**: measurement-driven threshold experiments with realistic workloads. Using `test-solver-parity.rkt` as safety net.
2. **Tier 1 expansion**: single-clause simple bodies (no NAF/guard) could qualify. Expected 5-10x more queries covered.
3. **Two-context automated testing**: architectural intervention for the recurring pattern. Build, don't document.

These are smaller than Track 2B. The big architectural work (on-network, parallel infrastructure, adaptive dispatch) is done.

---

## 14. Technical Debt Accepted

Explicit enumeration. Each item has a rationale and a tracking reference — per the methodology, debt without tracking is abandoned work.

| Item | Rationale | Tracked in |
|---|---|---|
| `:auto` defaults to DFS for clause queries < 256 | Measurement-driven: DFS 6-11x faster at practical sizes. Adaptive dispatch is the principled answer, not a workaround. | PIR §13.1 (revealed problem) |
| 0-arity queries delegate to DFS | Structural limitation of the scope-cell result model. Labeled scaffolding, retirement plan: unify with future success-cell-based result infrastructure. | PIR §14 (this table), §13.2 (mantra assessment) |
| TMS dead code (~200 lines in propagator.rkt) | Low-priority cleanup; no blocking impact. | DEFERRED.md |
| Tier 1 only single-variant fact-only | Extension to single-clause simple bodies would cover more queries; out of Track 2B scope. | DEFERRED.md, §13.4 |
| Streaming BSP infrastructure enabled only at N≥256 | Racket floor (~8μs cross-thread) bounds parallelism. Infrastructure correct, payoff deferred to self-hosting. | SH Series placeholder in Master Roadmap |
| Batch-worker parameter isolation partial | Listed params fixed (`current-solver-strategy-override`); general solution requires auto-registration architecture. | Longitudinal pattern (6+ PIRs); §13.3 calls for architectural intervention |
| Network template is module-level mutable box (`solver-network-template`) | Caches across tests in batch worker. Not parameterized. Could leak if tests mutate. | No known leak; monitor. |
| No acceptance `.prologos` file for Track 2B | Track is infrastructure-only, no user-facing syntax. Existing WFLE acceptance covers solver integration. | PIR §4 (Test Coverage gaps) |
| Test-solver-parity unresolved-var normalization | DFS returns `X0→X0`, ATMS returns `X0→X0_g1025` — same semantics, different representation. Normalized for comparison. | Test harness documented; not a bug but a representation difference |
| Product-worldview dedup is defensive, not root-cause | Pre-merge (Fix 6) is the real fix; dedup (Fix 7) is defense-in-depth. Could remove dedup if confident pre-merge is sufficient. | T-a commit messages; acceptable because dedup has no correctness cost |

**Explicit non-debt** (things that might look like debt but aren't):
- The DFS solver is retained as `:strategy :depth-first` and as `:auto`'s default below N=256 — not debt, but a permanent backend choice.
- Adaptive dispatch thresholds (256 for size, NAF/guard routing) — configurable via `solver-config`; not debt, by design.

---

## 15. What We'd Do Differently

Not hypothetical — based on what we now know. If the answer is "nothing," the design process worked well. If substantial, the process has a gap.

### 15.1 Introduce the design mantra at Stage 0, not mid-track

The mantra audit (`a5cde27f`) caught 6 violations that triggered Phase R (~5h of work). Had the mantra been codified at track start (before Phase 1a), Phase R wouldn't have been necessary — the violations wouldn't have existed. **Gap**: the Design Methodology didn't include a mantra-style structural gate; Track 2B introduced and codified it mid-track. **Change**: new Prologos tracks should start with a mantra/principles check per `.claude/rules/structural-thinking.md` before Phase 1.

### 15.2 Run Pre-0 benchmarks for NAF composition specifically

Phase 0b measured single-fact, multi-clause, and thread scaling. It didn't measure NAF composition at multi-result scale. If it had, the bridge-collapse failure mode would have surfaced pre-implementation, driving straight to Module Theory rather than through 3 failed design iterations. **Change**: Pre-0 benchmarks should cover each semantic axis the track exercises, not just performance axes.

### 15.3 Write `test-solver-parity.rkt` at Phase T-design, not T-c

The divergence classes encoded in T-c (gating-only, 0-arity, undefined NAF targets, multi-strata chains) were *discovered* during T-a bug-hunting. Had a parity test skeleton existed at Phase 0a (when the 3 divergence categories were first identified), each divergence would have surfaced as a failing test *at design time*, driving the design decisions rather than requiring mid-Phase-T bug fixes. **Change**: parity tests are design artifacts, not regression artifacts. Write them with the design doc.

### 15.4 Acknowledge adaptive dispatch as the target from D.1

D.1 wrote "`:auto` → propagator." D.13 delivered adaptive dispatch. The redirect was measurement-forced but arguably predictable: no single strategy is universally best is a common finding across solvers. Design D.1 could have posited adaptive and measured *which strategies* to route to under what conditions. **Change**: for strategy-dispatch designs, start with adaptive; benchmark to tune, not to discover the need.

### 15.5 Write the handoff document at each phase boundary, not at compaction

The handoff written at `2392a2d9` was successful, but it was written *at* the compaction boundary. If it had been written *at each phase boundary* (R complete, 2a complete, etc.), the track would have accumulated multiple handoffs and context loss would have been cheaper throughout. **Change**: make the handoff document a living artifact, updated per-phase, rather than a terminal artifact.

### 15.6 Systematic hash-iteration-order fuzz testing

The dissolution duplicate-worldview bug was latent and Heisenbug-shaped. Other hash-iteration-dependent bugs could exist; we don't know. **Change**: add a hash-iteration-order fuzz test (randomize `current-hash-seed` or equivalent across runs) to the CI. Run the full suite under 3-5 different hash seeds. Bugs that surface only under specific seeds are determinism-missing bugs.

### 15.7 Smaller than 13 design iterations

13 iterations is the most any Prologos track has had. Some were necessary (the genuinely novel NAF composition problem). Some were avoidable (the iteration-to-avoid-premature-commitment iterations could have been collapsed into fewer larger revisions). **Change**: at each iteration, ask "could this revision have been made in the previous one?" If yes, the previous iteration was premature.

### 15.8 Things we'd keep

- **Design mantra** introduced at track mid-point turned out to be load-bearing. Would introduce earlier (§15.1), but would absolutely keep.
- **Phase R as a coherent unit** — fixing all 6 violations together was right. Would repeat.
- **Module Theory resolution** — the algebraic frame was the key unlock. Would always reach for algebraic structure when patching keeps failing.
- **Handoff protocol for context compaction** — worked. Would use again.
- **Adaptive dispatch** — measurement-driven reframing from "propagator default" to "adaptive dispatch" was the correct call.
- **Conversational cadence** — user challenges at every decision point consistently improved decisions. Would keep explicitly.

---

## 16. Lessons Learned

### 16.1 Design mantra as live challenge (not guideline)

The mantra caught 6 architectural violations tests had missed. Codified in 4 rules files. **What happened**: tests verify correctness of the code; they don't verify that the code IS structurally emergent information flow. Under implementation pressure, it's easy to write a `for/fold` that produces the right answer but through step-think ordering. **Why it matters**: tests are insensitive to the distinction; the mantra is the missing gate. **How to apply**: at every propagator installation, every `for/fold`, every parameter, every return value, challenge against each word. Name what fails, redesign, or label as scaffolding with a retirement plan.

### 16.2 Belt-and-suspenders masks bugs in the new mechanism

Phase 5a incident: closure wrapper + scheduler flags both implementing fire-once. The wrapper prevented the double-fire, which meant the test passed, which meant the scheduler-level Tier 1 detection bug was invisible. Removing the wrapper exposed and fixed the real issue. **Why it matters**: when two mechanisms do the same thing, the overlap masks bugs in either one. The "safety" of dual mechanisms is illusory. **How to apply**: if you find yourself adding a second mechanism "for safety" while keeping the old one, pause. Either delete the old and fix the new, or revert to the old.

### 16.3 Normalize at the domain boundary (PPN insight, generalized)

AST values vs raw values bugs appeared at N sites before Phase T. `normalize-solver-value` at data entry (discrimination data, fact rows, NAF env) eliminated all of them. Single function, multiple consumers. **Why it matters**: per-site normalization is duplicated, error-prone, and asymmetric — one site normalizes, another doesn't, they disagree. **How to apply**: when a value crosses a type boundary (AST → raw, string → symbol, expr-int → int), normalize once at the boundary, not at each consumer.

### 16.4 Module Theory for scope decomposition

R = C₁ ⊕ ... ⊕ Cₙ realized as bitmask layers on a shared carrier cell, not as separate cells with morphisms. Eliminated bridges and the tag-collapse bug class. **Why it matters**: algebraic structure determines implementation. The direct-sum decomposition has two realizations; one is much simpler (tagging) and eliminates a bug class. **How to apply**: when considering separate cells with bridge morphisms, ask: is there a tagged-shared-cell realization? Usually yes, usually simpler.

### 16.5 Skip the mechanism, don't optimize it (N+1 applied)

Tier 1 direct return delivered 62x speedup. All BSP ceremony optimizations combined (Phase 5a) delivered ~5% improvement. **Why it matters**: the biggest wins come from recognizing when a mechanism isn't needed, not from making the mechanism faster. The structural overhead (allocation, cell writes, scheduling) is fixed; the only way to eliminate it is to bypass it. **How to apply**: before optimizing a mechanism, ask — is there a class of inputs for which the mechanism isn't needed at all? If yes, fast-path that class.

### 16.6 Racket parallelism has a hard floor (measured, accepted)

OS thread wakeup ~8μs. No Racket-level mechanism beats it for ~0.5μs work granularity. Four approaches benchmarked exhaustively in Phase 2d. **Why it matters**: the parallel infrastructure is correct; the payoff is deferred. Knowing this lets us stop optimizing within Racket and start designing for self-hosting. **How to apply**: document the ceiling. Measure the actual work per propagator. If work < wakeup floor × overhead factor, don't parallelize — the arithmetic is against you.

### 16.7 Measure before AND after (Pre-0 insight extended)

Phase 0b guided optimization targets. Phase 2d benchmarks revealed the Racket ceiling. Phase 5 benchmarks showed the Phase R regression. Each measurement changed strategy. **Why it matters**: without pre-measurement, optimization targets the wrong thing. Without post-measurement, you don't know if you made things worse. The handoff's Phase 2d "investigation" section documents 4 approaches with data; this is the gold standard for "design from evidence." **How to apply**: every optimization phase ends with before/after measurements. If a phase has no measurement, it's not complete.

### 16.8 Hash iteration order Heisenbug → missing invariant

Adding debug output to a test file changed its compilation → different memory layout → different hash iteration order → exposed a latent duplicate-worldview bug in dissolution. The bug was there the whole time; lucky iteration order hid it. **Why it matters**: Heisenbugs point to missing invariants. The fix isn't just to make the bug deterministic — it's to add the invariant that prevents the bug class. In this case: the dissolution must produce deterministic results regardless of hash iteration order. The pre-merge + dedup fix enforces this. **How to apply**: when a bug appears/disappears based on seemingly-unrelated changes, suspect a non-deterministic dependency. Find it; add the invariant.

### 16.9 `raco make driver.rkt` doesn't recompile test files

Tests aren't in driver.rkt's dependency graph. `raco make driver.rkt` + `--no-precompile` leaves test `.zo` stale. Batch worker's `dynamic-require` trusts cached .zo; stale .zo produces silently wrong results. Extended Track 10B stale .zo detection to cover test files. **Why it matters**: the suite runner had this infrastructure (`precompile-modules!` compiles both), but the manual precompile path bypassed it. The detection gap let the confusion persist across multiple diagnostic cycles. **How to apply**: never use `--no-precompile` after manual `raco make driver.rkt`. Let the suite runner do its own precompilation.

### 16.10 Context compaction via handoff protocol works

Track spanned multiple sessions; context compacted at Phase T boundary. The handoff document (written per HANDOFF_PROTOCOL.org) preserved reasoning across the compaction. Post-compaction session re-read handoff + design doc + dailies, then continued implementation without losing architectural understanding. **Why it matters**: large tracks exceed single-session context windows. The handoff is the preservation mechanism. **How to apply**: write handoff documents at natural boundaries (phase completion, context pressure), not at session end.

---

## 17. Metrics

| Metric | Value |
|---|---|
| Wall-clock duration | April 11 05:15 PDT → April 16 15:15 HST (~5 days 13 hours, 5.54 days) |
| Active implementation time | ~19h 40m across 8 distinct working sessions |
| Working sessions | 8 (Apr 11 / Apr 13 × 2 / Apr 14 / Apr 15 × 2 / Apr 16 × 2) |
| Design iterations | D.1 through D.13 (13 iterations) |
| Design docs (not including D.N.md pointers) | 4 (DESIGN, SELF_CRITIQUE, EXTERNAL_CRITIQUE, CRITIQUE_RESPONSE) |
| Total commits (racket/prologos/) | 43 |
| Total commits (including docs) | ~65 |
| Files modified (total track) | 28 files |
| Lines added / removed | +4348 / -489 (net +3859) |
| Core solver files delta | +2010 / -343 in relations.rkt, propagator.rkt, stratified-eval.rkt, solver.rkt |
| Tests before track | 7529 tests, 383 files |
| Tests after track | 7765 tests, 399 files |
| Test delta | +236 tests, +16 files |
| Suite wall time (after) | 121s for 7765 tests on 10 batch workers |
| Bugs found and fixed | 14 (documented) |
| Bug-fix commits | 7 Phase T-a + ~5 inline during R/2a/5a = ~12 |
| Design:Implementation ratio | ~0.55:1 calendar (3 design days : 5.5 impl wall-clock); iteration-weighted much higher given 13 D.N + mid-flight Phase R redesign |
| ATMS single-fact performance | 30.6μs → 0.49μs (62x) |
| ATMS single-fact vs DFS | 23x slower → 2.3x faster (25x relative improvement) |
| Parity sweep | 15/15 files both strategies BOTH PASS |
| Parity regression tests | 15 tests, 10 divergence classes |

---

## 18. What's Next

### Immediate (next session)

1. **Distill lessons** (this PIR) into DEVELOPMENT_LESSONS.org and PATTERNS_AND_CONVENTIONS.org. See §20.
2. **Update MEMORY.md** with Track 2B completion status.
3. **Update Master Roadmap** — Track 2B ✅ on BSP-LE Master.
4. **Review DEFERRED.md** — triage items newly-unblocked by Track 2B (tabling extensions, next-track prerequisites).

### Medium-term (next track)

1. **"Validated ≠ Deployed" debt**: `:auto` still defaults to DFS for small non-NAF clause queries. A focused follow-up track to flip defaults after deeper benchmarking on realistic workloads. Per PPN Track 2B's codified lesson, this is "incomplete, not pragmatic" — schedule it.
2. **TMS dead-code removal**: ~200 lines in propagator.rkt from pre-ATMS TMS infrastructure. On DEFERRED.md.
3. **Tier 1 extension**: currently fact-only single-variant. Could extend to single-clause relations with simple positive bodies. Covers more queries.

### Long-term (self-hosting prerequisites)

1. **Concurrency runtime** (CDR): per-propagator worldview infrastructure ready. `defproc`/`session` integration designed but not implemented. Self-hosted compiler provides heavier per-propagator work — lowers BSP pool crossover naturally from N≈256 toward N≈25.
2. **Research note** (spawned during Phase 2d): LLVM path for concurrency primitives vs wait-for-self-hosting decision.

### Open questions this track surfaced

- **Non-monotone S1 processing**: current S1 handles NAF correctly but has implicit limits. What happens with N>1 non-monotone strata? The general strata-list is in place; the question is semantic (well-founded iteration), not mechanical.
- **Tier 1 extension heuristics**: when should single-clause relations qualify? At what body complexity?
- **Parallel infrastructure idle cost**: tree-reduce + pool infrastructure adds allocation even when not used. Can we keep the pool cold until N exceeds threshold?

---

## 19. Key Files

| File | Role | Key Sections |
|---|---|---|
| `racket/prologos/relations.rkt` | Solver, discrimination, NAF, guard, Tier 1, dissolution | `normalize-solver-value` (~296), `tier-1-direct-fact-return` (~2766), `install-conjunction` gating pre-scan (~2195), `process-naf-request` S1 handler (~112), `dissolve-solver-pu` (~2631), 0-arity DFS delegation (~2813) |
| `racket/prologos/propagator.rkt` | BSP scheduler, worker pool, fire-once flags, Tier 1 flush | Well-known cells (cell-ids 0-5), `PROP-FIRE-ONCE`/`PROP-EMPTY-INPUTS` flags, `run-to-quiescence-bsp` Tier 1 check + fired-set, `make-worker-pool`, general strata-list loop (~2665) |
| `racket/prologos/stratified-eval.rkt` | Universal dispatch, Tier 1, adaptive :auto | `stratified-solve-goal` (~177): Tier 1 check, adaptive NAF/guard/threshold dispatch |
| `racket/prologos/tests/test-solver-parity.rkt` | DFS↔ATMS parity regression | 15 tests, 10 divergence classes, unresolved-var normalization |
| `docs/tracking/2026-04-10_BSP_LE_TRACK2B_DESIGN.md` | D.13 design | Phase R architecture, 2a-2d optimization, adaptive dispatch |
| `docs/tracking/handoffs/2026-04-16_BSP_LE_2B_HANDOFF.md` | Session handoff | Context preservation across compaction |
| `docs/tracking/standups/2026-04-12_dailies.md` | Session log | Phase R through Phase T detailed narrative |
| `tools/parity-test.rkt` | Systematic parity sweep | 15-file comparison under both strategies |

---

## 20. Lessons Distilled

Per the PIR methodology, every lesson should flow to where future work will encounter it. Empty "Lessons Distilled" = broken PIR lifecycle.

| Lesson | Distilled To | Status |
|---|---|---|
| Design mantra as live challenge (§16.1) | `on-network.md`, `propagator-design.md`, `workflow.md`, `structural-thinking.md` | ✅ Done pre-Phase R (`a5cde27f`) |
| Belt-and-suspenders masks bugs (§16.2) | `workflow.md` blocking red-flag rule | ✅ Done (M3 process improvement, `aeeb5fcb`) |
| Normalize at the domain boundary (§16.3) | `PATTERNS_AND_CONVENTIONS.org` — Boundary Normalization anti-pattern | ✅ Done (small one-liner) |
| Module Theory for scope decomposition (§16.4) | `structural-thinking.md` — Direct Sum Has Two Realizations | ✅ Done (extends "Module Theory of Lattices") |
| Skip the mechanism, don't optimize (§16.5) | (none) | ⏹ Rejected as generalization — Tier 1 was a special case, not a principle; "skipping the mechanism" potentially conflicts with other design principles (validated in discussion 2026-04-17) |
| Racket parallelism hard floor + memory cost (§16.6) | `DEVELOPMENT_LESSONS.org` — Racket Parallelism ~8μs Floor | ✅ Done (with memory-cost axis) |
| Measure before, during, AND after; memory axis (§16.7) | `DESIGN_METHODOLOGY.org` Stage 4 | ✅ Done (extends Pre-0 rule with per-phase + memory) |
| Hash iteration Heisenbug → missing invariant (§16.8) | `DEVELOPMENT_LESSONS.org` | ⬜ Deferred — future codification candidate |
| `raco make driver.rkt` test `.zo` gap (§16.9) | `testing.md` rules | ✅ Done (W2 + I1 process improvements, `aeeb5fcb` + `0932fa49`) |
| Context compaction via handoff (§16.10) | `HANDOFF_PROTOCOL.org` | ⬜ Deferred — nice-to-have |

### Meta-lesson (Patterns Across 3+ PIRs)

From the longitudinal survey of the 10 most recent PIRs, Track 2B **confirms** these patterns (counted instances include this track):

- **Wrong lattice/merge assumptions**: 7/10 PIRs now. Same-bitmask entries merging (T-a Fix 6) is the latest instance. **Codification destination**: DESIGN_METHODOLOGY.org Pre-0 algebraic validation checklist (distributivity, idempotence, merge composition under shared bitmasks).
- **Design:Implementation ratio**: Track 2B at 0.45:1 would predict more logic bugs — offset by 13 design iterations. The correlation holds: more design investment (whether in iterations or in ratio) → fewer bugs. The 14 bugs here are mostly in implementation details (closure capture, zip mismatch, AST/raw divergence), not architectural bugs — the architecture held under 13 design iterations.
- **Integration phases dominate**: Phases 1-3 were fast; Phases R, 2a, 5b, T dominated time. Confirmed.
- **Pre-0 benchmarks reshape design**: Phase 0a/0b/0c found 3 divergence categories + ATMS overhead decomposition → rebuilt the design around them. Confirmed (architectural pattern, 10/10 PIRs).
- **Critique rounds prevent drift**: D.3, D.4 external critique caught the NAF design gaps; D.9 through D.13 iterations caught scope sharing need. Confirmed.
- **Diagnostic discipline regression**: Track 2B ran the full suite multiple times diagnostically during T-a (5+ times). Partial regression — justified by the "is the solver broken?" risk, but the pattern holds.
- **Validated ≠ Deployed**: `:auto` still defaults to DFS for small clause queries (adaptive routing). Acknowledged explicitly in §3 (Gap Analysis) and §14 (Technical Debt). Pattern continues, honestly documented.
- **Two-context boundary bugs**: Batch worker parameter leakage is the latest instance. The pattern persists because new parameters are added faster than the checklist updates.

Track 2B **extends** these patterns with new data:
- **Belt-and-suspenders masks bugs** (Pattern D in longitudinal, 4/10 PIRs now) — Phase 5a's dual fire-once mechanisms is a cleaner case than most.
- **Skip-the-mechanism vs optimize-the-mechanism** — not yet a cross-PIR pattern, but the 62x Tier 1 vs 5% BSP ceremony optimization is compelling evidence. Watch for recurrence.

### Longitudinal survey table (10 most recent PIRs)

| PIR | Date | Duration | Commits | Tests | D.N | Main Theme |
|---|---|---|---|---|---|---|
| **BSP-LE 2B** (this) | 2026-04-16 | ~5.4d/5+ sess | 43 | +236 | D.13 | On-network NAF/guard + parallel + Tier 1 + parity |
| BSP-LE 2 | 2026-04-10 | ~35h/4 sess | ~95 | +136 | D.13 | Propagator-native solver, worldview bitmask |
| PPN 4B | 2026-04-07 | ~17h/3 sess | 47 | +31 | D.2 | Attribute evaluation, 90% on-network |
| PPN 4 | 2026-04-04 | ~3 sess | 69 | +23 | D.4 | Propagator-native type inference, 46% on-network |
| SRE 2H | 2026-04-03 | ~14h | 30 | +35 | D.5 | Type lattice quantale, union types |
| SRE 2D | 2026-04-03 | ~11h | 18 | +25 | D.5 | Rewrite relation, DPO spans |
| PPN 3 | 2026-04-02 | ~30h/2 sess | 70+ | +0 | D.5b + §11 | Parser as propagators, tree-canonical pivot |
| SRE 2G | 2026-03-30 | ~10h | 11 | +32 | D.3 + NTT | Algebraic domain awareness, property inference |
| PPN 2B | 2026-03-30 | ~10h | 18 | -5 → +32 | D.3b + §12 | Merge strategy, source-line identity |
| PPN 2 | 2026-03-29 | ~8.5h | 68 | +57 | D.3 (6) | Surface normalization as propagators |

### Patterns spanning 5+ PIRs (architectural — demand systemic response)

1. **Pre-0 benchmarks reshape design** (10/10) — fully codified, mature practice.
2. **Critique rounds prevent drift** (9/10) — fully codified in DESIGN_METHODOLOGY.org.
3. **Design:Implementation ratio correlates with quality** (10/10) — partially codified; would benefit from explicit quantitative guideline.
4. **Integration phases dominate time** (7/10) — codified in DEVELOPMENT_LESSONS.org.
5. **Two-context boundary bugs** (6/10) — codified in pipeline.md; pattern persists despite codification → response needs to be architectural (automated two-context testing?), not documentary.
6. **Wrong lattice/merge assumptions** (7/10) — partially codified; longitudinal survey suggests Pre-0 algebraic validation should be more explicit.
7. **On-network migration staging prerequisites** (4/10 but growing) — this track confirms. PPN Track 4 blocked on TMS; Track 2B rebuilt during Phase R because the store wasn't on-network yet. Should be codified: "Before attempting computation X on-network, verify (1) cells, (2) algebraic properties, (3) merge semantics, (4) scheduler correctness."

### Open meta-questions

- **Is Track 2B's 0.45:1 design-to-implementation ratio a warning sign or acceptable given the 13 iterations?** The bugs found were mostly implementation-level (closure capture, zip mismatch, AST vs raw), not architectural. The architecture held. But if 13 iterations were required to land the design, the process may be under-investing in upfront research. Consider: for infrastructure tracks, is a D:I ratio target useful, or is iteration count a better proxy for design investment?
- **The diagnostic protocol regression pattern (4+ PIRs)**: codification exists, violation recurs. Is it time for a workflow guard (e.g., a git hook that blocks `raco test --all` within 5 minutes of a previous full-suite run unless `.rkt` files changed)? This would convert process discipline into infrastructure.
- **Belt-and-suspenders as an anti-pattern**: three PIRs now confirm it masks bugs. Is there a systematic way to detect dual-mechanism implementations during design review?

The PIR methodology says a pattern spanning 5+ PIRs demands systemic response. Two-context boundary bugs (6/10) and wrong lattice assumptions (7/10) are ripe for architectural intervention, not just documentation. The immediate post-PIR work should include one systemic step for each: perhaps a `pipeline.md` addition for automated two-context testing, and a `DESIGN_METHODOLOGY.org` Pre-0 algebraic validation checklist.
