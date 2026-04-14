# BSP-LE Track 2B Session Handoff — 2026-04-13

## §1: Current Work State

**Track**: BSP-LE Track 2B — Parity Deployment + Parallel Search
**Design**: D.12 (`docs/tracking/2026-04-10_BSP_LE_TRACK2B_DESIGN.md`)
**Last commit**: `472db662` — all-specificity merge in tagged-cell-read + leaf bitmask filter
**Suite health**: 398/398 files, 7745-7750 tests, ~120s, all pass
**Dailies**: `docs/tracking/standups/2026-04-12_dailies.md`

### Progress Tracker

| Phase | Description | Status |
|---|---|---|
| 0a-c | Investigation (parity, benchmarks, executors) | ✅ |
| 1a | Clause selection as decision-cell narrowing | ✅ `a1df50f4`→`b47b9787` |
| 1b | Discrimination tree (data value) + flat installation | ✅ `1eae7eb8`→`cb4758f4` |
| **2a** | **NAF via worldview assumption + S1 provability** | **🔄 Basic+variable cases FIXED. Multi-result composition remaining.** |
| 2b | NAF evaluation stratum in BSP | ⬜ |
| 3 | Guard as propagator | ⬜ |
| 5a-5c | Tier 1 optimizations | ⬜ |
| 6 | `:auto` switch + adaptive executor | ⬜ |
| T | Parity regression suite | ⬜ |

### Next Immediate Task

**Unify fact-row PU branching with multi-clause concurrent pattern.** The current fact-row PU tags writes but doesn't install per-branch propagator infrastructure. This breaks bitmask composition when NAF + fact-row branching compose (arg↔param bridge fires under ONE bitmask, needs to fire under MULTIPLE bitmasks — one per fact-row branch).

The fix: fact rows should use `install-one-clause-concurrent` style per-row installation with full propagator copies per branch. This unifies the treatment and makes bitmask composition structural.

---

## §2: Documents to Hot-Load

### Always-Load (every session)
1. `CLAUDE.md` + `CLAUDE.local.md`
2. `MEMORY.md`
3. Rules: `propagator-design.md`, `on-network.md`, `structural-thinking.md`, `testing.md`, `pipeline.md`, `workflow.md`

### Session-Specific (READ IN FULL)

| Document | Lines | Why |
|---|---|---|
| `docs/tracking/2026-04-10_BSP_LE_TRACK2B_DESIGN.md` | ~600 | D.12 design: stratified NAF, Phase structure, all benchmark data |
| `docs/tracking/2026-04-10_BSP_LE_TRACK2B_SELF_CRITIQUE.md` | ~170 | 15 findings with D.7 outcomes |
| `docs/tracking/2026-04-10_BSP_LE_TRACK2B_EXTERNAL_CRITIQUE.md` | ~135 | 18 findings (2 critical) |
| `docs/tracking/2026-04-10_BSP_LE_TRACK2B_CRITIQUE_RESPONSE.md` | ~130 | 15 actions, all resolved |
| `docs/tracking/standups/2026-04-12_dailies.md` | ~80 | Current session log, NAF design evolution |
| This handoff document | — | State transfer |

### Key Source Files

| File | What | Hot Lines |
|---|---|---|
| `racket/prologos/relations.rkt` | Solver, discrimination, NAF, conjunction | Lines 1768-1870 (NAF), 1870-1930 (conjunction), 2100-2180 (fact-row PU), 2380-2460 (S1 eval), 2490-2550 (result reading) |
| `racket/prologos/decision-cell.rkt` | Tagged-cell-value, scope-cell, completion lattice | Lines 404-435 (tagged-cell-read — recently changed to all-specificity merge) |
| `racket/prologos/propagator.rkt` | BSP scheduler, worldview cache, fire-and-collect-writes | Lines 925-965 (net-cell-write tagged path), 2267-2358 (run-to-quiescence-bsp) |
| `racket/prologos/atms.rkt` | solver-context, solver-assume, solver-add-nogood | Lines 470-560 |

---

## §3: Key Design Decisions

### 1. NAF as worldview assumption + S1 stratified evaluation (D.12)

**What**: NAF goals get worldview assumptions via `solver-assume`. Conjunction pre-scans for NAF, allocates assumptions UPFRONT, wraps ALL goals (not just post-NAF) under combined NAF bitmask. S1 stratum validates NAF assumptions by checking inner goal provability at S0 fixpoint. Invalid NAF → worldview cache bit cleared.

**Why**: NAF is non-monotone. CALM requires stratification. Three same-layer approaches failed (worldview-bitmask isolation, probe variables, NAF-success cell). All fought the monotonicity boundary. Stratification is the principled solution — well-understood in logic programming.

**Rejected**: (a) Fork-based NAF (cross-network bridge problem). (b) Worldview-bitmask isolation on same layer (construction-time vs BSP-time confusion, ground goal detection impossible). (c) Probe variables (false positives from unification setup writes). (d) NAF-success cell written by discrimination (correct for basic cases but not ground inner goals).

### 2. Clause-viability is an instance of Track 2 decision cell (not a new lattice)

**What**: Same carrier P(N), same order (⊇), same merge (set-intersection), same infrastructure (decisions-state). Phase 1a adds a new narrowing BRIDGE (argument-watching propagator via discrimination), not a new lattice type.

**Why**: SRE lattice lens analysis. Reuses all Track 2 infrastructure.

### 3. On-network discrimination via fire-once broadcast propagators

**What**: One propagator per discriminating position, watches query arg cell, compares with clause discrimination data using `equal?` (same as `solver-unify-terms`), writes viable set to viability cell.

**Why**: Replaces off-network hasheq lookup. `equal?` comparison matches unification semantics. Broadcast pattern gives O(1) BSP rounds.

### 4. Discrimination tree is a data value, not an installation guide

**What**: Tree structs (`discrim-node`, `discrim-leaf`) retained for analysis/self-hosting. Propagator installation is FLAT (all positions), not tree-guided.

**Why**: Tree traversal for installation is step-think. Position ordering should emerge from BSP dataflow, not from imperative tree walking.

### 5. `tagged-cell-read` merges ALL matching entries across specificities

**What**: Changed from max-popcount selection to all-matching merge. Multi-level composition (NAF+fact-row) produces entries at different bitmask levels that all need merging.

**Why**: With max-popcount, lower-specificity entries (e.g., NAF-only label binding) were discarded when higher-specificity entries (NAF+fact-row x binding) existed. The label was lost.

### 6. Result reading filters to leaf bitmasks

**What**: Only bitmasks that aren't proper subsets of other bitmasks produce results. Plus worldview-visibility check (NAF-eliminated bits cleared from cache).

**Why**: Partial bitmasks (NAF-only without fact-row bits) produce incomplete results. Leaf filter ensures only complete branching decisions produce results.

---

## §4: Surprises and Non-Obvious Findings

### 1. NAF is non-monotone → stratification required (MOST IMPORTANT)
Every same-layer NAF implementation failed because NAF inverts provability — not monotone. CALM guarantees confluence only for monotone operations. The user identified this. Three approaches tried and failed before arriving at stratification.

### 2. Query scope cells must be promoted UPFRONT
The NAF worldview-assumption approach tags writes. But if the query scope cell isn't promoted to tagged-cell-value BEFORE any writes, the first write goes to the PLAIN base (untagged). Worldview clearing has no effect on untagged base values. Fix: promote in `solve-goal-propagator` before `install-goal-propagator`.

### 3. AST nodes vs raw values — double normalization needed
The `.prologos` pipeline produces `expr-int(20)` AST nodes. Fact-row discrimination data stores the same nodes. The S1 provability check compares them. BOTH sides need normalization to raw values for `equal?` to match. Added `normalize-for-compare` in S1 AND `expr-app` handling in `expr->goal-desc`.

### 4. Worldview projection propagator overwrites cache clearing
The projection propagator (Track 2 Phase 5.4) recomputes the worldview cache from the decisions cell during BSP. If S1 clears bits, the next BSP run overwrites them. Fix: clear AFTER the second `run-to-quiescence`, not before.

### 5. `for/fold` in installation paths is step-think
All installation loops (`install-conjunction`, fact-row PU, S1 evaluation, result reading) use `for/fold` or `for/list` — sequential, imperative. The self-hosted compiler would use broadcast propagators and topology requests. This is documented scaffolding but the user correctly flagged it as a design concern.

### 6. Multi-level bitmask composition needs per-branch propagator copies
The arg↔param bridge propagator captures ONE bitmask at installation time. Multi-level branching (NAF + fact-row PU) needs the bridge to fire under MULTIPLE bitmasks. The current fact-row PU tags writes but doesn't create per-branch propagator infrastructure. This is the ROOT CAUSE of the remaining multi-result divergences.

### 7. `ctx` (solver-context) is off-network
It's a struct containing cell-ids, passed imperatively. In the self-hosted compiler it would be a cell. Documented scaffolding.

---

## §5: Open Questions and Deferred Work

### Immediate (Phase 2a remaining)
- **Unify fact-row PU with multi-clause concurrent pattern**: fact rows need per-row propagator copies (same as `install-one-clause-concurrent`). This fixes the multi-result composition with NAF.
- **Cross-relation NAF** (adversarial line 35): `(ground-vals ?x) (other-vals ?y) (not (= ?x ?y))` — involves a `unify` NAF (not `app`), which needs the S1 unify provability check to handle S0-resolved variable values.

### Phase 2b
- **BSP completion stratum**: add S1 NAF evaluation as a BSP stratum in `run-to-quiescence-bsp`. Retires the post-quiescence scaffolding in `solve-goal-propagator`. ~40-50 lines.

### Remaining Track Phases
- Phase 3: Guard as propagator
- Phase 5a-5c: Tier 1 optimizations (fire-once fast-path, lazy context, template cell)
- Phase 6: `:auto` switch
- Phase T: Parity regression suite

### DEFERRED.md Items
- TMS dead code removal (~200 lines in propagator.rkt)
- DFS↔propagator parity testing (systematic, not just adversarial)
- `:auto` → propagator default

---

## §6: Process Notes

### Design Methodology Followed
- 12 design iterations (D.1 through D.12) with design conversations at each
- 2 critique rounds (self + external) with full responses
- Phase 0 investigation with comprehensive benchmarks BEFORE implementation
- Conversational implementation cadence (checkpoints every ~1h)
- Phase completion protocol (test, commit, tracker, dailies)

### Propagator Design Rules (added this session)
- **Fire function network parameter (CRITICAL)**: fire functions MUST use their `net` parameter, never captured outer variables. Closure capture of `for/fold` accumulators causes silent data loss. Added to `propagator-design.md`.

### Key Architectural Insights
- **NAF is a worldview stratification, not a separate mechanism.** Each NAF assumption IS a worldview element. S1 validates which NAF assumptions are consistent with S0 provability.
- **The Hyperlattice Conjecture's optimality claim applies to BSP barriers.** Hypercube all-reduce gives log₂(T) rounds for T threads. Pairwise merge preserves CHAMP structural sharing.
- **Clause-viability narrowing compounds with Tier 1 optimizations.** Better narrowing → fewer branches → fire-once fast-path triggers → lower overhead.
- **"Constants" are fixpoints after one write — they still belong on-network for self-hosting.**

### Benchmark Baselines
- ATMS overhead: 25x DFS for single-fact (BSP 52.6%, goal install 30.4%, allocation 15.5%)
- Narrowing cost: 0.125us (negligible)
- Thread spawn: 3.6us (crossover at N≥128 concurrent propagators)
- Parallel executors: no benefit for current workloads (sequential is optimal)
- Fork: O(1) (22ns, CHAMP structural sharing)
