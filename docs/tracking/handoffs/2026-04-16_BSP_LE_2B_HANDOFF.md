# BSP-LE Track 2B Session Handoff — 2026-04-16

## §1: Current Work State

**Track**: BSP-LE Track 2B — Parity Deployment + Parallel Search
**Design**: D.13 (`docs/tracking/2026-04-10_BSP_LE_TRACK2B_DESIGN.md`)
**Last commit**: `98ac1b94` — dailies update (final session commit: `82b66c42` Phase 6 tracker)
**Suite health**: 398/398 files, 7750 tests (397 pass, 1 known parity issue in test-wf-comparison-01.rkt)
**Dailies**: `docs/tracking/standups/2026-04-12_dailies.md`

### Progress Tracker

| Phase | Description | Status |
|---|---|---|
| 0a-c | Investigation (parity, benchmarks, executors) | ✅ |
| 1a | Clause selection as decision-cell narrowing | ✅ |
| 1b | Position-discriminant analysis | ✅ |
| **R1** | Relation store on-network | ✅ `9bf8fff7`→`23041a2e` |
| **R2** | Fact-row PU as per-row propagator copies | ✅ `d4da77de` |
| **R3** | All goal installation propagator-mediated | ✅ `3bdf3322` |
| **R4** | General stratum infra + S1 NAF handler | ✅ `8fbc342b` |
| **R6** | PU dissolution — answer egress cell | ✅ `8e8ea659` |
| **2a** | NAF + scope sharing + product dissolution | ✅ `a6b02159`→`4b2e5bdf` |
| **2b** | Parallel tree-reduce merge (hypercube) | ✅ `bbf3eb82` |
| **2c** | Semaphore-based worker pool | ✅ `a7b015dd` |
| **2d** | Streaming BSP investigation | ✅ `1c691f86` (reverted to sync pool) |
| **3** | Guard as worldview assumption | ✅ `83276b0d` |
| **5a** | Propagator flags + Tier 1 flush + self-clearing | ✅ `333a5667`→`2181fac0` |
| **5b/5c** | Template + Tier 1 direct return + boundary normalization | ✅ `d998b06c`→`b4001cd7` |
| **6** | Adaptive :auto dispatch | ✅ `7d77d52a` |
| **T** | Parity regression suite | ⬜ |
| PIR | Post-implementation review | ⬜ |

### Next Immediate Task

**Phase T**: Parity regression suite. 2 known test failures in `test-wf-comparison-01.rkt` from the adaptive dispatch routing NAF queries to ATMS instead of DFS. Investigate: (1) is ATMS handling multi-strata NAF chains correctly? (2) should the test expectations update for ATMS behavior? Then: systematic DFS↔ATMS parity validation.

---

## §2: Documents to Hot-Load

### Always-Load (every session)
1. `CLAUDE.md` + `CLAUDE.local.md`
2. `MEMORY.md`
3. Rules: `propagator-design.md`, `on-network.md`, `structural-thinking.md`, `testing.md`, `pipeline.md`, `workflow.md`

### Session-Specific (READ IN FULL)

| Document | Lines | Why |
|---|---|---|
| `docs/tracking/2026-04-10_BSP_LE_TRACK2B_DESIGN.md` | ~1500 | D.13 design: Phase R + all optimizations. Progress tracker is source of truth. |
| `docs/tracking/standups/2026-04-12_dailies.md` | ~300 | Full session log: every phase, every lesson, every benchmark result. |
| This handoff document | — | State transfer |

The Handoff Protocol: `docs/tracking/principles/HANDOFF_PROTOCOL.org`

### Key Source Files

| File | What | Hot Sections |
|---|---|---|
| `racket/prologos/relations.rkt` | Solver, discrimination, NAF, guard, Tier 1, dissolution | `normalize-solver-value` (~line 296), `tier-1-direct-fact-return` (~line 2766), `install-conjunction` gating pre-scan (~line 2195), `process-naf-request` S1 handler (~line 112), `dissolve-solver-pu` (~line 2631) |
| `racket/prologos/propagator.rkt` | BSP scheduler, worker pool, fire-once flags, Tier 1 flush | Well-known cells (cell-ids 0-5), `PROP-FIRE-ONCE`/`PROP-EMPTY-INPUTS` flags, `run-to-quiescence-bsp` Tier 1 check + fired-set, `make-worker-pool` with spin-wait |
| `racket/prologos/stratified-eval.rkt` | Universal dispatch, Tier 1, adaptive :auto | `stratified-solve-goal` (~line 177): Tier 1 check, adaptive NAF/guard/threshold dispatch |

---

## ��3: Key Design Decisions

### 1. Design Mantra as first-class challenge
**What**: "All-at-once, all in parallel, structurally emergent information flow ON-NETWORK" codified in 4 rules files. Every design decision challenged against each word.
**Why**: Caught 6 architectural violations (Phase R) that tests missed. The mantra prevents drift.
**Rejected**: Treating it as a guideline rather than a gate.

### 2. Scope sharing (Resolution B) over bridges
**What**: Clause params share query scope directly. Module decomposition R = C₁ ⊕ ... ⊕ Cₙ via bitmask layers on shared carrier cell, not separate cells with morphisms.
**Why**: Bridges collapsed tagged entries (worldview-filtered reads). Scope sharing eliminates the entire tag-collapse bug class.
**Rejected**: Resolution A (tag-transparent bridges with fmap) — more complex, still has indirection.

### 3. NAF and Guard as worldview assumptions (same pattern)
**What**: Both allocate assumptions, tag subsequent goals, use nogoods for failure. NAF at S1 (non-monotone), guard at S0 (monotone).
**Why**: Reuses existing ATMS infrastructure. `install-conjunction` pre-scans for both gating kinds.
**Rejected**: NAF as threshold propagator at S0 (non-monotone can't be at S0), guard as topology request (over-complicated).

### 4. General stratum infrastructure (request-accumulator pattern)
**What**: BSP outer loop processes N strata via (request-cell, handler) pairs. Same pattern as topology stratum.
**Why**: Follows existing topology pattern. Propagators are stratum-agnostic. No gate cells, no `#:stratum` flags.
**Rejected**: Gate cells (new mechanism, not aligned with existing patterns), propagator stratum flags (violates stratum-agnosticism).

### 5. Fire-once as scheduler-level concept (no closure wrapper)
**What**: `PROP-FIRE-ONCE` flag on propagator struct. Scheduler implements fired-set + self-clearing. No closure wrapper.
**Why**: Scheduler can skip fired propagators at zero cost. Self-clearing removes from dependents. Belt-and-suspenders masked a Tier 1 detection bug.
**Rejected**: Closure-only (scheduler can't optimize), belt-and-suspenders (masks bugs).

### 6. Tier 1 direct fact return (skip BSP entirely)
**What**: Single-variant fact-only relations bypass ALL solver infrastructure. Direct matching with boundary normalization.
**Why**: 62x speedup (30.6us → 0.49us). ATMS now faster than DFS for Tier 1. The biggest win was NOT "faster BSP" but "skip BSP."
**Rejected**: BSP ceremony optimization (negligible impact — the overhead is structural).

### 7. PPN boundary normalization
**What**: `normalize-solver-value` at data entry, not at each comparison site. AST nodes → raw values once.
**Why**: PPN Track 1 insight: normalize at the domain boundary. Eliminates AST/raw comparison bugs across all matching sites.
**Rejected**: Per-site normalize-for-compare (duplicated, error-prone).

### 8. Adaptive :auto dispatch
**What**: NAF/guard → ATMS (mandatory). N ≥ threshold(256) → ATMS. Else → DFS.
**Why**: DFS is 6-11x faster for clause queries at practical sizes. ATMS only pays off when worldview assumptions are needed or parallelism kicks in (N≥256).
**Rejected**: Binary flip to ATMS (wasteful for simple queries), count-only threshold (misses NAF/guard requirement).

### 9. Racket parallelism ceiling (accepted)
**What**: OS thread wakeup ~8us dominates all cross-thread communication. Sync pool crossover at N≈256.
**Why**: Exhaustive 2d investigation: spin-wait, sync events, async-channel, spin-poll all ≥ sync pool. No Racket-level mechanism beats the OS wakeup cost.
**Rejected**: FFI to C (throwaway — self-hosting replaces), streaming BSP (overhead > benefit).

---

## §4: Surprises and Non-Obvious Findings

### 1. Scope sharing > bridges (MOST IMPORTANT architectural insight)
Multi-result NAF bug root cause: bridge propagators between clause and query scope collapsed tagged entries via worldview-filtered reads. The fix wasn't "better bridges" — it was "no bridges." Module Theory: bitmask layers on shared cell replace separate cells with morphisms.

### 2. Belt-and-suspenders masks bugs
Adding the closure wrapper back to fire-once (alongside scheduler flags) hid a Tier 1 detection bug: the bitwise check `flags & (A|B)` passed when EITHER flag was set, but should require BOTH. The wrapper prevented the double-fire, making the test pass. Removing the wrapper exposed and fixed the real issue.

### 3. Tier 1 makes strategy irrelevant for fact queries
After Tier 1 direct return: DFS and ATMS produce identical performance (0.49us) for fact-only relations. The universal Tier 1 short-circuits before strategy selection. The strategy only matters for Tier 2 (clause queries).

### 4. Phase R caused a 33% performance regression
Making everything on-network (6 well-known cells, fire-once for all writes, discrimination-data cells) added ~7.6us overhead per single-fact query (23us → 30.6us). Tier 1 direct return recovered this and then some (→ 0.49us). But Tier 2 queries still pay the Phase R overhead.

### 5. Fork inherits all cell state (recursive S1 bug)
The S1 NAF handler forks the network for inner goal evaluation. The fork inherited the NAF-pending cell contents → the fork's BSP re-processed S1 → infinite recursion. Fix: `net-cell-reset` clears NAF-pending on fork before inner BSP.

### 6. `for/fold` zip with unequal-length sequences stops early
The Tier 1 matching zipped effective-args (2 elements) with query-vars (1 element) → only checked the first position. Fix: iterate effective-args + row independently, check each position against query-vars membership.

---

## §5: Open Questions and Deferred Work

### Phase T (immediate)
- 2 test failures in `test-wf-comparison-01.rkt`: adaptive dispatch routes NAF queries to ATMS which handles them differently than DFS (no error for unstratifiable negation). Investigate: is this correct behavior or a gap?
- Systematic DFS↔ATMS parity validation across all 398 test files.

### Tier 1 expansion
- Currently only fact-only relations. Could extend to single-clause relations with simple bodies (no NAF/guard). Would cover more Tier 1 cases.

### Tier 2 ATMS overhead
- Phase R regression: Tier 2 queries pay ~30us overhead vs ~5-17us DFS. Accepted for Phase 0 — self-hosted compiler has heavier work per propagator (lower ratio).

### Self-hosting series (SH)
- Placeholder in Master Roadmap. Research note spawned on LLVM path. Concurrency runtime (CDR) design scope for `defproc`/`session`.
- BSP parallel infrastructure ready for self-hosting: tree-reduce, worker pool, cell-id namespaces.

### DEFERRED.md
- TMS dead code removal (~200 lines in propagator.rkt)
- DFS↔propagator systematic parity testing (Phase T)

---

## §6: Process Notes

### Design patterns established this session

1. **Design mantra challenge at every decision point** — codified in workflow.md, propagator-design.md, on-network.md, structural-thinking.md.
2. **N+1 Principle** — when considering N options, ask "what's the N+1th?" Applied to NAF stratification, bridge composition, parallelism approach.
3. **PPN boundary normalization** — normalize at data entry, not at each consumer. Applied to solver value matching.
4. **Measure before AND after** — every optimization benchmarked. Phase 2d exhaustive investigation saved us from adopting approaches that don't work.
5. **Belt-and-suspenders is a red flag** — dual mechanisms mask bugs. Remove the old path, fix the new one.
6. **Module Theory for scope** — bitmask layers replace separate cells with morphisms. Direct sum via tagging.
7. **Tier detection before strategy selection** — universal fast-path at dispatch level benefits ALL strategies.

### Session metrics
- ~25 commits
- 398/398 test files pass (7750 tests)
- ATMS single-fact: 0.49us (62x improvement, 2.3x faster than DFS)
- All 3 adversarial divergence categories resolved
- 6 well-known cells on solver network
- Parallel BSP infrastructure: tree-reduce + worker pool + cell-id namespaces
- Adaptive :auto dispatch with configurable threshold

### Performance summary

| Query type | DFS | ATMS (before) | ATMS (after) |
|---|---|---|---|
| Single-fact (Tier 1) | 1.13us | 23.0us | **0.49us** |
| N-clause (Tier 2) | N × ~2us | N × ~12us | N × ~12us (unchanged) |
| NAF/guard | limited | broken | **correct** |
