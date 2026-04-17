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

**(a) On-network solver architecture.** Phase R migrated 6 solver infrastructure pieces from off-network state to propagator cells: relation store, config, discrimination data, NAF-pending accumulator, pool config, and answer egress cell. Every goal installation is now propagator-mediated — no construction-time direct writes. General N-stratum BSP infrastructure with request-accumulator pattern (same as the existing topology stratum). NAF and guard unified as worldview assumptions under a single pattern. Clause-level scope sharing (Resolution B, Module Theory) eliminates bridge propagators and the tag-collapse bug class.

**(b) Parallel BSP infrastructure.** Hypercube tree-reduce merge with per-propagator cell-id namespaces (high-bit encoding). Semaphore-based persistent worker pool replacing per-round thread creation. Exhaustive streaming BSP investigation (4 approaches, all worse than sync pool due to Racket's ~8μs cross-thread wakeup floor). Parallel crossover at N≈256 accepted for Phase 0; infrastructure ready for self-hosting where per-propagator work increases.

**(c) Tier 1 optimization + adaptive dispatch.** Universal Tier 1 fast-path (direct fact return) at `stratified-solve-goal` benefits all strategies. 62x speedup on single-fact queries (30.6μs → 0.49μs); ATMS now 2.3x faster than DFS for Tier 1. Adaptive `:auto` dispatch: NAF/guard → ATMS (mandatory), N ≥ threshold(256) → ATMS (parallel benefit), else → DFS (6-11x faster at practical sizes). Phase T then closed the parity loop: 7 correctness fixes, 15/15 systematic parity sweep, 15 permanent regression tests.

The narrative arc: D.9 design assumed NAF needed complex probe mechanisms; D.12 reframed NAF as a worldview stratification on top of ATMS; D.13 added Phase R (mantra audit) after the user introduced the design mantra as a first-class gate ("All-at-once, all in parallel, structurally emergent information flow ON-NETWORK"). The audit found 6 architectural violations tests had missed. The rest of the track cleaned them up, then optimized, then validated.

---

## 2. Timeline and Phases

| Phase | Status | Commit | Description |
|---|---|---|---|
| 0a | ✅ | pre-track | Parity baseline: 19/19 files both strategies; adversarial finds 3 divergence categories |
| 0b | ✅ | pre-track | 28 micro-benchmarks + overhead decomposition (ATMS 24.5x) |
| 0c | ✅ | pre-track | A/B executor comparison: sequential wins current workloads, threads at N≥128 |
| 1a | ✅ | `a1df50f4`→`b47b9787` | Clause selection as decision-cell narrowing; on-network discrimination; Categories 1+2 FIXED |
| 1b | ✅ | `1eae7eb8` | Position-discriminant analysis; flat installation (reverted step-think tree traversal in `cb4758f4`) |
| 2a (pre-R) | attempted | `d4f00a4c`→`7ac4cc1a` | NAF via worldview bitmask, probe vars, success cells — all failed for multi-result composition |
| D.11/D.12 | design | — | NAF as stratified eval, then as worldview assumption with conjunction pre-scan |
| 2a (D.12) | partial | `e928dbc0`→`472db662` | Basic + variable NAF PASS; multi-result (`both-passed` 1 vs 3) still broken |
| **Design mantra introduced** | **`a5cde27f`** | Four rules files codified; audit triggered |
| **R1** | ✅ | `9bf8fff7`→`23041a2e` | Relation store (cell-id 2), config (cell-id 3), discrim-data as on-network cells |
| **R2** | ✅ | `d4da77de` | Fact-row PU as per-row fire-once propagators with combined bitmask |
| **R3** | ✅ | `3bdf3322` | All goal installation propagator-mediated (4 sites: unify, is, one-clause, one-clause-concurrent) |
| **R4** | ✅ | `8fbc342b` | General N-stratum BSP; NAF-pending cell (cell-id 4); S1 fork handler; -90 lines imperative S1 |
| **R6** | ✅ | `8e8ea659` | PU dissolution → answer-cid egress (NTT SolverNet :outputs alignment) |
| 2a (R2-R6) | ✅ | `a6b02159`→`4b2e5bdf` | Scope sharing (Resolution B) + product-worldview dissolution; ALL adversarial NAF PASS |
| 2b | ✅ | `bbf3eb82` | Tree-reduce merge; per-propagator cell-id namespaces; CHAMP diff for new-cell capture |
| 2c | ✅ | `a7b015dd` | Semaphore-based worker pool; pool config (cell-id 5); crossover N≈256 |
| 2d | ✅ | `1c691f86` | Streaming BSP investigation: 4 approaches benchmarked, sync pool optimal; Racket thread ceiling documented |
| 3 | ✅ | `83276b0d` | Guard as worldview assumption (same pattern as NAF); install-conjunction pre-scans both |
| 5a | ✅ | `333a5667`→`2181fac0` | PROP-FIRE-ONCE + PROP-EMPTY-INPUTS flags; Tier 1 flush; self-clearing fired-set; closure wrapper removed |
| 5b/5c | ✅ | `d998b06c`→`01de93f5` | Network template; Tier 1 direct fact return (62x speedup); PPN boundary normalization |
| 5b/5c (universal) | ✅ | `b4001cd7` | Tier 1 lifted to `stratified-solve-goal` — benefits ALL strategies |
| 6 | ✅ | `7d77d52a` | Adaptive `:auto`: Tier 1 → direct, NAF/guard → ATMS, N≥256 → ATMS, else → DFS |
| **Handoff** | — | `2392a2d9` | Context compaction boundary; handoff document written |
| **T-a** | ✅ | `1eb8b8cc`→`35a39865` | 7 correctness fixes: CWA undefined error, ground provability DFS, 0-arity delegation, gating-only markers, marker guard, entry pre-merge, product dedup |
| T (process) | ✅ | `946a98ac` | Stale .zo detection extended to cover test files |
| **T-b** | ✅ | `a4326539` | Systematic DFS↔ATMS parity sweep: 15/15 BOTH PASS |
| **T-c** | ✅ | `034aa167` | `test-solver-parity.rkt`: 15 regression tests across 10 divergence classes |

**Design:Implementation ratio**: D.1 through D.13 over ~8 days (April 7 design start → April 10 D.13 → April 16 T-c complete). Design phase: ~2.5 days. Implementation phase: ~5.5 days. **Ratio: 0.45:1** — lower than ideal, partially offset by 13 design iterations (in-flight redesign counts as design investment).

**Sessions**: At least 5 distinct working sessions (pre-R, R implementation, 2a-2d optimization, 3-6 dispatch, T parity). Context compacted at Phase T boundary — handoff protocol used to preserve understanding.

---

## 3. Test Coverage

**New test file**: `tests/test-solver-parity.rkt` (274 lines, 15 tests, Phase T-c). Ten divergence classes covered: Tier 1 facts, single clause, multi-clause, NAF ground succeeds/fails, 2-strata / 3-strata chains, guards, mixed positive+NAF, gating-only (0-arity + with-vars), undefined NAF target, multi-fact narrowing.

**Modified test files**: `test-solver-config.rkt` (threshold 4→256 for Phase 6), `test-stratified-eval.rkt` (parameterized `current-solver-strategy-override` for batch-worker isolation), `test-propagator.rkt` + `test-observatory-01.rkt` + `test-trace-serialize.rkt` (cell count expectations updated 3 times across Phase R).

**Test growth**: 7529 → 7765 (+236). The growth spans test files not created by this track but enabled/extended: discrimination tests from Phase 1a, PU branching tests, on-network cell tests, parity tests in T-c.

**Gaps**: No acceptance `.prologos` file for Track 2B — this track was infrastructure-only with no user-facing syntax changes. The existing `2026-03-14-wfle-acceptance.prologos` covers solver integration indirectly.

---

## 4. Bugs Found and Fixed

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

## 5. Design Decisions and Rationale

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

### 5.10 N+1 Principle as Design Practice

User challenge mid-track: "When considering N options, ask what's the N+1th?" Applied at multiple decision points. NAF stratification: N options = threshold / probe / success cell → N+1 = fork-based S1 handler. Bridge composition: N options = better bridges / fmap / tag-transparent → N+1 = no bridges (scope sharing). Parallelism: N options = faster BSP / async / spin → N+1 = skip BSP (Tier 1). **Rationale**: the obvious options converge on "more of the same"; the breakthrough option is usually in a different category entirely.

---

## 6. Lessons Learned

### 6.1 Design mantra as live challenge (not guideline)

The mantra caught 6 architectural violations tests had missed. Codified in 4 rules files. **What happened**: tests verify correctness of the code; they don't verify that the code IS structurally emergent information flow. Under implementation pressure, it's easy to write a `for/fold` that produces the right answer but through step-think ordering. **Why it matters**: tests are insensitive to the distinction; the mantra is the missing gate. **How to apply**: at every propagator installation, every `for/fold`, every parameter, every return value, challenge against each word. Name what fails, redesign, or label as scaffolding with a retirement plan.

### 6.2 Belt-and-suspenders masks bugs in the new mechanism

Phase 5a incident: closure wrapper + scheduler flags both implementing fire-once. The wrapper prevented the double-fire, which meant the test passed, which meant the scheduler-level Tier 1 detection bug was invisible. Removing the wrapper exposed and fixed the real issue. **Why it matters**: when two mechanisms do the same thing, the overlap masks bugs in either one. The "safety" of dual mechanisms is illusory. **How to apply**: if you find yourself adding a second mechanism "for safety" while keeping the old one, pause. Either delete the old and fix the new, or revert to the old.

### 6.3 Normalize at the domain boundary (PPN insight, generalized)

AST values vs raw values bugs appeared at N sites before Phase T. `normalize-solver-value` at data entry (discrimination data, fact rows, NAF env) eliminated all of them. Single function, multiple consumers. **Why it matters**: per-site normalization is duplicated, error-prone, and asymmetric — one site normalizes, another doesn't, they disagree. **How to apply**: when a value crosses a type boundary (AST → raw, string → symbol, expr-int → int), normalize once at the boundary, not at each consumer.

### 6.4 Module Theory for scope decomposition

R = C₁ ⊕ ... ⊕ Cₙ realized as bitmask layers on a shared carrier cell, not as separate cells with morphisms. Eliminated bridges and the tag-collapse bug class. **Why it matters**: algebraic structure determines implementation. The direct-sum decomposition has two realizations; one is much simpler (tagging) and eliminates a bug class. **How to apply**: when considering separate cells with bridge morphisms, ask: is there a tagged-shared-cell realization? Usually yes, usually simpler.

### 6.5 Skip the mechanism, don't optimize it (N+1 applied)

Tier 1 direct return delivered 62x speedup. All BSP ceremony optimizations combined (Phase 5a) delivered ~5% improvement. **Why it matters**: the biggest wins come from recognizing when a mechanism isn't needed, not from making the mechanism faster. The structural overhead (allocation, cell writes, scheduling) is fixed; the only way to eliminate it is to bypass it. **How to apply**: before optimizing a mechanism, ask — is there a class of inputs for which the mechanism isn't needed at all? If yes, fast-path that class.

### 6.6 Racket parallelism has a hard floor (measured, accepted)

OS thread wakeup ~8μs. No Racket-level mechanism beats it for ~0.5μs work granularity. Four approaches benchmarked exhaustively in Phase 2d. **Why it matters**: the parallel infrastructure is correct; the payoff is deferred. Knowing this lets us stop optimizing within Racket and start designing for self-hosting. **How to apply**: document the ceiling. Measure the actual work per propagator. If work < wakeup floor × overhead factor, don't parallelize — the arithmetic is against you.

### 6.7 Measure before AND after (Pre-0 insight extended)

Phase 0b guided optimization targets. Phase 2d benchmarks revealed the Racket ceiling. Phase 5 benchmarks showed the Phase R regression. Each measurement changed strategy. **Why it matters**: without pre-measurement, optimization targets the wrong thing. Without post-measurement, you don't know if you made things worse. The handoff's Phase 2d "investigation" section documents 4 approaches with data; this is the gold standard for "design from evidence." **How to apply**: every optimization phase ends with before/after measurements. If a phase has no measurement, it's not complete.

### 6.8 Hash iteration order Heisenbug → missing invariant

Adding debug output to a test file changed its compilation → different memory layout → different hash iteration order → exposed a latent duplicate-worldview bug in dissolution. The bug was there the whole time; lucky iteration order hid it. **Why it matters**: Heisenbugs point to missing invariants. The fix isn't just to make the bug deterministic — it's to add the invariant that prevents the bug class. In this case: the dissolution must produce deterministic results regardless of hash iteration order. The pre-merge + dedup fix enforces this. **How to apply**: when a bug appears/disappears based on seemingly-unrelated changes, suspect a non-deterministic dependency. Find it; add the invariant.

### 6.9 `raco make driver.rkt` doesn't recompile test files

Tests aren't in driver.rkt's dependency graph. `raco make driver.rkt` + `--no-precompile` leaves test `.zo` stale. Batch worker's `dynamic-require` trusts cached .zo; stale .zo produces silently wrong results. Extended Track 10B stale .zo detection to cover test files. **Why it matters**: the suite runner had this infrastructure (`precompile-modules!` compiles both), but the manual precompile path bypassed it. The detection gap let the confusion persist across multiple diagnostic cycles. **How to apply**: never use `--no-precompile` after manual `raco make driver.rkt`. Let the suite runner do its own precompilation.

### 6.10 Context compaction via handoff protocol works

Track spanned multiple sessions; context compacted at Phase T boundary. The handoff document (written per HANDOFF_PROTOCOL.org) preserved reasoning across the compaction. Post-compaction session re-read handoff + design doc + dailies, then continued implementation without losing architectural understanding. **Why it matters**: large tracks exceed single-session context windows. The handoff is the preservation mechanism. **How to apply**: write handoff documents at natural boundaries (phase completion, context pressure), not at session end.

---

## 7. Metrics

| Metric | Value |
|---|---|
| Wall-clock duration | April 11 05:15 → April 16 15:15 PDT (~5.4 days, multi-session) |
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
| Design:Implementation ratio | 0.45:1 (2.5 design days : 5.5 implementation days; offset by 13 iterations) |
| ATMS single-fact performance | 30.6μs → 0.49μs (62x) |
| ATMS single-fact vs DFS | 23x slower → 2.3x faster (25x relative improvement) |
| Parity sweep | 15/15 files both strategies BOTH PASS |
| Parity regression tests | 15 tests, 10 divergence classes |

---

## 8. What's Next

### Immediate (next session)

1. **Distill lessons** (this PIR) into DEVELOPMENT_LESSONS.org and PATTERNS_AND_CONVENTIONS.org. See §10.
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

## 9. Key Files

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

## 10. Lessons Distilled

Per the PIR methodology, every lesson should flow to where future work will encounter it. Empty "Lessons Distilled" = broken PIR lifecycle.

| Lesson | Distilled To | Status |
|---|---|---|
| Design mantra as live challenge (§6.1) | `on-network.md`, `propagator-design.md`, `workflow.md`, `structural-thinking.md` | ✅ Done pre-Phase R (`a5cde27f`) |
| Belt-and-suspenders masks bugs (§6.2) | `DEVELOPMENT_LESSONS.org` | ⬜ Pending — extend existing "Validated ≠ Deployed" section with belt-and-suspenders as a specific anti-pattern |
| Normalize at the domain boundary (§6.3) | `PATTERNS_AND_CONVENTIONS.org` | ⬜ Pending — codify as "PPN Boundary Normalization" pattern; reference sites in relations.rkt |
| Module Theory for scope decomposition (§6.4) | `structural-thinking.md` | ⬜ Pending — extend "Module Theory of Lattices" with concrete direct-sum-via-tagging pattern |
| Skip the mechanism, don't optimize (§6.5) | `DEVELOPMENT_LESSONS.org` | ⬜ Pending — new section "N+1 Principle in Optimization" |
| Racket parallelism hard floor (§6.6) | `DEVELOPMENT_LESSONS.org` | ⬜ Pending — document the 8μs ceiling, measurement methodology, self-hosting implication |
| Measure before AND after (§6.7) | `DESIGN_METHODOLOGY.org` (Stage 4, implementation protocol) | ⬜ Pending — elevate Pre-0 measurement rule to include phase-end measurement |
| Hash iteration Heisenbug → missing invariant (§6.8) | `DEVELOPMENT_LESSONS.org` | ⬜ Pending — new section "Heisenbugs Point to Missing Determinism Invariants" |
| `raco make driver.rkt` test `.zo` gap (§6.9) | `testing.md` rules | ⬜ Pending — document the `--no-precompile` trap, reference the extended stale .zo detection |
| Context compaction via handoff (§6.10) | `HANDOFF_PROTOCOL.org` | ⬜ Pending — add "Post-compaction reload" section based on this track's successful instance |

### Meta-lesson (Patterns Across 3+ PIRs)

From the longitudinal survey of the 10 most recent PIRs, Track 2B **confirms** these patterns (counted instances include this track):

- **Wrong lattice/merge assumptions**: 7/10 PIRs now. Same-bitmask entries merging (T-a Fix 6) is the latest instance. **Codification destination**: DESIGN_METHODOLOGY.org Pre-0 algebraic validation checklist (distributivity, idempotence, merge composition under shared bitmasks).
- **Design:Implementation ratio**: Track 2B at 0.45:1 would predict more logic bugs — offset by 13 design iterations. The correlation holds: more design investment (whether in iterations or in ratio) → fewer bugs. The 14 bugs here are mostly in implementation details (closure capture, zip mismatch, AST/raw divergence), not architectural bugs — the architecture held under 13 design iterations.
- **Integration phases dominate**: Phases 1-3 were fast; Phases R, 2a, 5b, T dominated time. Confirmed.
- **Pre-0 benchmarks reshape design**: Phase 0a/0b/0c found 3 divergence categories + ATMS overhead decomposition → rebuilt the design around them. Confirmed (architectural pattern, 10/10 PIRs).
- **Critique rounds prevent drift**: D.3, D.4 external critique caught the NAF design gaps; D.9 through D.13 iterations caught scope sharing need. Confirmed.
- **Diagnostic discipline regression**: Track 2B ran the full suite multiple times diagnostically during T-a (5+ times). Partial regression — justified by the "is the solver broken?" risk, but the pattern holds.
- **Validated ≠ Deployed**: `:auto` still defaults to DFS. Acknowledged explicitly in §8 as a follow-up track. Pattern continues, honestly documented.
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
