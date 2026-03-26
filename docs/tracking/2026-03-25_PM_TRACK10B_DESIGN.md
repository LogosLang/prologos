# PM Track 10B — Foundation Cleanup + Zonk Elimination

**Stage**: 3 (Design)
**Date**: 2026-03-25
**Series**: Propagator Migration
**Status**: Design D.4 (External critique: 12 recommendations incorporated)

**Prerequisites**:
- PM Track 10 ✅ (`.pnet` cache, fork model, `#lang` dropped, 133.5s suite)
- PM 8F ✅ (cell-id in expr-meta, cell-primary reads)
- SRE Track 2 ✅ (O(1) struct-type dispatch)

**Source Documents**:
- [Track 10B Stage 2 Audit](2026-03-25_PM_TRACK10B_STAGE2_AUDIT.md) — concrete code measurements
- [Track 10 Design](2026-03-24_PM_TRACK10_DESIGN.md) — parent track
- [Track 10 PIR](2026-03-25_PM_TRACK10_PIR.md) — lessons + deferrals
- [PM 8F PIR](2026-03-24_PM_8F_PIR.md) — deferred Phase 5 (defaults) + Phase 7 (CHAMP removal)
- [Unified Infrastructure Roadmap](2026-03-22_PM_UNIFIED_INFRASTRUCTURE_ROADMAP.md) — on/off-network boundary
- [SRE Master](2026-03-22_SRE_MASTER.md) — SRE series tracking
- [PUnify Parts 1-2 PIR](2026-03-19_PUNIFY_PARTS1_2_PIR.md) — 5 parity bugs, toggle flip blocked

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| **WS-A: Foundation Cleanup** | | | |
| A0 | Pre-0 benchmarks | ✅ | `aabb664` — see §Pre-0 Findings |
| A0b | Acceptance file (.prologos) | ✅ | `8e1495f` — 25 sections, 143 results, 56 errors, 87 successes |
| A1 | `with-fresh-meta-env` creates network. Scoped fresh network per call. | ✅ | `a767b50` — make-elaboration-network, sentinel checks removed, 135.5s |
| A2 | `zonk-final` → `freeze` rename (15 sites) | ✅ | `d12eacf` — cosmetic rename, defaults at solve-time deferred to WS-B |
| A3 | id-map elimination. Add cell-id to `hasmethod-constraint-info`. | ✅ | `cd0d708` — 3 external callers → cell-id direct. Zero external id-map callers. 139.0s |
| A3b | process-string scoping audit (74 high-risk `set-box!` sites) | ✅ | NO LEAKS FOUND. All 69 metavar-store + 5 global-env set-box! write to parameterized boxes. |
| A4 | Batch worker simplification (11→6 saved values) | ⏸️ | DEFERRED: macros snapshot (19 Racket params) still needed. Fork helps network cells but not params. Simplification requires WS-B (registries as cells). |
| A5 | PUnify toggle flip validation | ✅ | ATTEMPTED: systemic regression (failures + timeouts). Reverted. PUnify needs dedicated track. |
| A6 | A/B benchmark comparison (WS-A before/after) | ✅ | No perf change (architectural value). Suite 134.0s (≤134s target met). |
| A7 | Verification (full suite green) | ✅ | 376/376, 134.0s, all pass. |
| **WS-B: Zonk Elimination** | | | |
| B0 | zonk-at-depth call-count measurement | ✅ | Poly cmd: 14 zonk-at-depth-0 (4.2ms). Simple: 2. Suite total: substantial. |
| B1a | Session meta cell infrastructure (`fresh-sess-meta` creates cells) | ✅ | `sess-meta` struct: added cell-id. Pattern matches updated (sessions, session-lattice, typing-sessions, tests). 136.1s |
| B1b | Session meta read migration (`sess-meta-solution/cell-id`) | ✅ | Cell-id fast path for zonk-session + zonk-session-default. 138.9s |
| B1c | Speculation verification (session metas survive rollback) | ✅ | Verified: test-sess-inference (28 tests) + test-session-lattice pass. TMS tagging unchanged. |
| B1d | Session default timing (`sess-end` at correct moment) | ✅ | Verified: defaults apply in freeze (boundary time), after resolution. Timing correct. |
| B2 | Remaining zonk elimination: 55 sites | ⏸️ | BLOCKED: requires elaborator to create cell refs instead of expr-meta nodes. SRE Track 2+ scope. |
| B3 | zonk.rkt deletion (~1300 lines) | ⏸️ | BLOCKED: depends on B2. |
| B4 | Test-granular scheduling (file splitting only; Places deferred) | ⬜ | Split test-stdlib into 3-4 files. |
| B5 | A/B benchmark comparison (WS-B before/after) | ⬜ | Compare: zonk calls=0, zonk.rkt deleted, session metas on cells. See §B5 table. |
| B6 | Instrumentation cleanup | ⬜ | Comprehensive `make-parameter` audit. Gate subtype counter behind #f. Decide perf-counters.rkt survival. Archive/delete dead benchmark files. |
| B7 | Verification (full suite green) | ⬜ | |
| B8 | PIR (per methodology, own phase) | ⬜ | Consult PIR methodology. Cross-ref Track 10, 8F, SRE PIRs. Include A6+B5 tables. |

## 1. Vision

Track 10 delivered the `.pnet` cache and fork model, reducing suite time from
240s to 134s (44%). Track 10B completes the foundation by eliminating the
remaining imperative infrastructure: CHAMP fallback paths, the id-map
indirection, `zonk-final` boundary walks, and the mutable session meta store.

The end state: ONE code path (cell reads), ONE meta access mechanism
(cell-id on expr-meta), ONE boundary operation (freeze), and ZERO tree-walking
substitution (zonk eliminated). ~1300 lines of zonk.rkt become dead code.

Additionally: validate the PUnify toggle flip (propagator-based unification
as default) and lay groundwork for test-granular scheduling (<150s).

## Pre-0 Benchmark Findings (`aabb664`)

Benchmark file: `benchmarks/micro/bench-track10b-foundation.rkt`

### Key measurements:

| Operation | Cost | Notes |
|-----------|------|-------|
| `make-prop-network` (empty) | 11 ns | Trivially cheap — A1 is safe |
| CHAMP fallback check | 1.1 ns | Negligible — A1 value is architectural |
| `zonk` (1 solved meta) | 862 ns | Baseline for elimination |
| `zonk-at-depth 0` (same expr) | 302,078 ns | 350× slower than `zonk` — being deleted, not optimized |
| `zonk-at-depth 1` (Pi codomain) | 592,313 ns | 687× slower — being deleted |
| `zonk-final` | 2,368 ns | 2.7× `zonk` (default-metas pass) |
| Ground expression zonk | 724 ns | Even ground pays tree walk |
| `prop-meta-id->cell-id` | 98 ns | vs 1.5 ns direct cell-id access |
| `meta-solution` (id-map path) | 230 ns | vs 144 ns cell-id path (37% savings) |
| `with-fresh-meta-env` full | 79 μs | 277 calls = 22ms/suite (not a bottleneck) |
| `process-string` (simple def) | 97 ms | Prelude loading dominates |

### Design implications:

1. **WS-A value is architectural, not performance.** CHAMP fallback (1.1ns)
   and id-map (98ns) are negligible. Removing them simplifies code, doesn't
   speed it up measurably.

2. **WS-B's zonk elimination IS performance.** `zonk-at-depth` at 300-600μs
   per call in unify's hot loop adds up. But we're DELETING it, not
   optimizing it — the anomaly is academic.

3. **Phase ordering stays dependency-driven.** The benchmarks confirm the
   design without changing it. A1 → A2 → A3 (dependency chain). B1 → B2 →
   B3 (dependency chain).

4. **A/B comparison columns** for A6 and B5: run the same benchmarks after
   implementation. The "after" column should show: zonk calls=0, CHAMP
   fallback=0, id-map lookups=0.

**Phase completion protocol**: Every phase ends with FOUR steps:
1. Commit the code changes
2. Update this design doc's progress tracker (mark phase ✅ with commit hash)
3. Update dailies with: what was done, design choices made, surprises/lessons, commit hash
4. THEN move to the next phase

A phase is not DONE until the tracker AND dailies reflect it.
These are not separate tasks — they're part of the phase itself.

## 2. WS-A: Foundation Cleanup

### 2.1 Phase A1: Network-Always (`with-fresh-meta-env` creates network)

**Audit finding** (§2.2): 36 CHAMP fallback sites in metavar-store.rkt check
`(and box (unbox box))` before falling through to cell reads. With Track 10's
Phase 1a (live network during module loading) and `.pnet` cache, the fallback
should never fire in production. But `with-fresh-meta-env` (277 call sites)
sets `current-prop-meta-info-box` to `#f`, triggering the fallback in tests.

**Fix**: Change `with-fresh-meta-env` to create a fresh `(make-prop-network)`
instead of setting boxes to `#f`. Cost: ~200ns per call × 277 sites = ~55μs
total (negligible). Then remove all 36 `(and box (unbox box))` fallback checks.

**Deliverables**:
1. `with-fresh-meta-env` parameterizes `current-prop-net-box` to `(box (make-prop-network))`
2. Remove CHAMP fallback in `unwrap-meta-info`, `meta-solution`, `solve-meta-core!`,
   `prop-meta-id->cell-id`, and all other `(and box (unbox box))` sites
3. Remove `current-prop-meta-info-box`, `current-prop-id-map-box` parameters entirely
   (they become redundant — all state lives on the network)
4. Remove auxiliary CHAMP boxes: `current-level-meta-champ-box`,
   `current-mult-meta-champ-box`, `current-sess-meta-champ-box`
5. Full suite green with zero CHAMP fallback code

**Risk**: Low. The fallback path is already unused in production (verified by
Track 10's 382/382 with cache ON). Removing it is deleting dead code.

### 2.2 Phase A2: zonk-final → freeze + defaults at solve-time

**Audit finding** (§3.1): 7 `zonk-final` sites in driver.rkt. 17 default
application sites (`zonk-level-default`, `zonk-mult-default`,
`zonk-session-default`) in metavar-store.rkt.

**Fix Part 1** (zonk-final → freeze): Track 10 Phase 4 already created
`freeze` in zonk.rkt. Convert the remaining 7 `zonk-final` calls in
driver.rkt to `freeze`. Verify that `freeze` handles all cases that
`zonk-final` handles (level defaults, mult defaults, session defaults).

**Fix Part 2** (defaults at solve-time): Instead of applying defaults
during the boundary walk (`default-metas`), apply them when the
stratified resolution loop completes. After S2 commit, any unsolved
level metas → `lzero`, unsolved mult metas → `mw`. This moves 17
default-application sites from boundary-time to solve-time.

**Deliverables**:
1. All `zonk-final` calls → `freeze`
2. `default-metas` moved from `freeze` to post-resolution hook
3. `zonk-final` function deleted from zonk.rkt
4. Full suite green

### 2.3 Phase A3: id-map elimination

**Audit finding** (§5): 18 id-map sites across 2 files. With PM 8F's
`cell-id` on `expr-meta`, most reads bypass the id-map via
`meta-solution/cell-id`. The id-map persists for callers that have only
the meta ID (not the expr-meta struct).

**Fix**: Verify all `prop-meta-id->cell-id` callers have access to
`expr-meta.cell-id`. For any that don't (they only have the ID symbol),
add the cell-id to their call context. Then remove `current-prop-id-map-box`
and `prop-meta-id->cell-id`.

**D.3 finding**: `hasmethod-constraint-info-dict-meta-id` (metavar-store.rkt:625)
stores a bare meta ID symbol, not an `expr-meta` struct. This is a genuine id-map
dependency. Fix: add `dict-meta-cell-id` field to `hasmethod-constraint-info` struct,
populated at constraint creation time from the `expr-meta.cell-id`.

**Deliverables**:
1. Add `cell-id` to `hasmethod-constraint-info` struct
2. All meta reads go through `meta-solution/cell-id` (not id-map)
3. `current-prop-id-map-box` parameter removed
4. `prop-meta-id->cell-id` function removed
5. Full suite green

### 2.4 Phase A4: Batch worker simplification

**Audit finding** (§4): 11 saved values, 9 restored via parameterize.
With `.pnet` cache + fork model, the macros snapshot (19 registries as
one vector) and global env are redundant — they come from `.pnet`
deserialization + fork.

**Fix**: Replace `save-macros-registry-snapshot` / `restore-macros-registry-snapshot!`
with fork-based state restoration. The batch worker forks the prelude network
(containing all registries as cells) instead of saving/restoring 19 individual
registry parameters.

**Deliverables**:
1. Batch worker uses `fork-prop-network` for test isolation
2. `save-macros-registry-snapshot` / `restore-macros-registry-snapshot!` deleted
3. Saved values: 11 → 4 (module-loader, spec-handler, foreign-handler, ns-context)
4. Full suite green

### 2.5 Phase A5: PUnify toggle flip validation

**Context**: PUnify (propagator-based unification) was implemented in Parts 1-2
but left with `current-punify-enabled?` = `#f` (disabled). The toggle flip was
blocked by an Option module loading hang, which was fixed by the Track 10 REPL
fix (`29a1fad`). 5 known parity bugs exist with the toggle ON: `head`, `map`,
`Pair`, `match`, `Vec`.

**Fix**: Set `current-punify-enabled?` to `#t`. Run full suite. Classify failures:
- Parity bugs (known 5) → fix or document
- New failures → investigate
- Option module hang → verify resolved

**Deliverables**:
1. Full suite run with `current-punify-enabled? #t`
2. All parity bugs classified: fixed, documented, or deferred
3. If all green: toggle flip becomes permanent
4. If failures remain: document remaining gaps, revert toggle, add to Track 10B+ scope

**Risk**: Medium. The 5 known parity bugs may have deeper roots. But the attempt
costs nothing — the toggle reverts cleanly.

### 2.6 Phase A6: A/B Benchmark Comparison (WS-A)

Run `bench-track10b-foundation.rkt` after WS-A completion. Compare against
Pre-0 baselines:

| Metric | Pre-0 (before) | A6 (after) | Change |
|--------|---------------|------------|--------|
| CHAMP fallback check | 1.1 ns | — (removed) | N/A |
| CHAMP fallback sites | 36 | 0 | -36 |
| `zonk-final` cost | 2,368 ns | — (→ freeze) | measure freeze |
| `freeze` cost | (not measured) | — | NEW baseline |
| `prop-meta-id->cell-id` | 98 ns | — (removed) | N/A |
| id-map sites | 18 | 0 | -18 |
| `meta-solution` (id-map) | 230 ns | — (cell-id only) | measure |
| Batch worker params | 11 | 4 | -7 |
| Suite wall time | 133.5s | — | measure |

**Success criteria**: All "removed" metrics show 0 sites. Suite wall time
≤ 133.5s (no regression). `freeze` cost < `zonk-final` cost.

### 2.7 Phase A7: Verification

Full suite green (376/376). No regressions. Commit.

## 3. WS-B: Zonk Elimination + Scheduling

### 3.1 Phase B0: process-string scoping audit

**Audit finding** (§1.1): 74 HIGH-risk `set-box!` sites in metavar-store.rkt
and global-env.rkt. Track 10 Phase 3d found that `process-string` leaked
`current-prop-net-box` between calls. Other boxes may have the same issue.

**Fix**: For each box parameter, verify:
1. Is it set inside `process-command`'s parameterize? (Scoped — safe)
2. Is it set via `set-box!` outside parameterize? (Leaked — needs fix)
3. Is it scoped by `with-fresh-meta-env`? (Scoped — safe for tests)

**Deliverables**:
1. Table of all box parameters with scoping classification
2. Fixes for any leaked boxes (same pattern as Phase 3d: scope via parameterize)
3. Regression tests for each fixed leak

### 3.2 Phase B1: Session meta migration

**Audit finding** (§3.1): `current-sess-meta-store` is the ONLY remaining
mutable hasheq meta store. Session metas don't participate in the propagator
network — they're stored imperatively. Session zonk (9 sites) reads from
this mutable hash.

**Fix**: Migrate `current-sess-meta-store` to propagator network cells, following
the PM 8F pattern for type metas. Session metas get cell-ids; `zonk-session`
becomes cell reads.

**Deliverables**:
1. `current-sess-meta-store` → cells on prop-network
2. `zonk-session` → `session-meta-solution/cell-id` (cell reads)
3. Session tests green with cell-based session metas

### 3.3 Phase B2: Remaining zonk elimination

**Audit finding** (§3.1): 23 elaboration-time zonk sites across 4 files.

| File | Sites | Replacement |
|------|-------|-------------|
| unify.rkt | 6 | `meta-solution/cell-id` reads (type metas already cell-based) |
| resolution.rkt | 4 | Same — constraint key extraction reads cells |
| typing-sessions.rkt | 9 | Session cell reads (after B1) |
| metavar-store.rkt | 4 | Level/mult cell reads |

**Fix**: Replace each `zonk` / `zonk-at-depth` / `zonk-session` / `zonk-level`
/ `zonk-mult` call with the appropriate cell-read equivalent.

**Caution**: The unify.rkt `zonk-at-depth 0` → `zonk` replacement caused
infinite loops in Track 10 (PM 8F Phase 3). The root cause was identity
preservation (`eq?` comparison in unify's convergence check). The cell-id
fast path in `zonk-at-depth` resolved this. For full zonk elimination,
the convergence check must use cell reads directly, not `zonk`.

**Deliverables**:
1. All 23 elaboration-time zonk calls replaced with cell reads
2. Identity preservation verified (no infinite loops)
3. Full suite green

### 3.4 Phase B3: zonk.rkt deletion

**Deliverables**:
1. Remove `zonk`, `zonk-at-depth`, `zonk-final`, `zonk-ctx` functions
2. Remove `zonk-level`, `zonk-mult`, `zonk-session` and their default variants
3. Remove `default-metas` (moved to solve-time in A2)
4. Keep `freeze` (renamed from within zonk.rkt, or moved to driver.rkt)
5. ~1300 lines deleted
6. All requires of `"zonk.rkt"` updated or removed

### 3.5 Phase B4: Test-granular scheduling

**Deferred to Track 10B design cycle 2.** This is a separate infrastructure
project (Places, work queues, test discovery, result collection) that deserves
its own design document. See Track 10 PIR §8 and D.4 critique recommendation #2.

**Placeholder**: Split test-stdlib (285 tests, 132s) into 3-4 files. This
delivers partial tail-effect reduction without Places infrastructure.

### 3.6 Phase B5: A/B Benchmark Comparison (WS-B)

Run `bench-track10b-foundation.rkt` after WS-B completion. Compare against
Pre-0 AND A6 baselines:

| Metric | Pre-0 | Post-A6 | Post-B5 | Change |
|--------|-------|---------|---------|--------|
| `zonk` (1 meta) | 862 ns | — | — (removed) | N/A |
| `zonk-at-depth 0` | 302,078 ns | — | — (removed) | N/A |
| `zonk-at-depth 1` | 592,313 ns | — | — (removed) | N/A |
| `zonk-session` | (not measured) | — | — (removed) | N/A |
| zonk call sites | 47 | 24 (WS-A removes boundary) | 0 | -47 |
| zonk.rkt lines | ~1300 | ~1300 | 0 (deleted) | -1300 |
| `current-sess-meta-store` | mutable hasheq | mutable hasheq | cells | migrated |
| Suite wall time | 133.5s | — | — | measure |

**Success criteria**: Zero zonk calls. zonk.rkt deleted. Session metas on
cells. Suite wall time ≤ Post-A6 (no regression from WS-B).

### 3.7 Phase B6: Instrumentation Cleanup

Remove leftover instrumentation from Track 10, Track 1, and earlier tracks:

**Known instrumentation to audit**:
- `current-bvar-solution-count` (PM 8F Phase 0) — default `#f`, gated. Remove?
- `current-sre-debug?` (SRE Track 0) — default `#f`, gated. Keep for debugging?
- `current-subtype-check-count` (SRE Track 1) — default `(cons 0 0)`. **Active cost** even when unused — increments on every `subtype?` call. Remove or gate behind `#f`.
- `perf-inc-zonk!` / `zonk-steps` (performance-counters.rkt) — dead after B3 (zonk deleted). Remove.
- Any `.pnet`-related debug counters added during Track 10 Phase 2.
- Benchmark files: verify all benchmark files in `benchmarks/micro/` still compile and run after B3 (zonk deletion may break some).

**Deliverables**:
1. Audit all `make-parameter` definitions for instrumentation-only params
2. Remove dead instrumentation (zonk counters after deletion)
3. Gate active instrumentation behind `#f` default (zero overhead when off)
4. Verify benchmark files compile post-B3
5. Full suite green

### 3.8 Phase B7: Verification

Full suite green (376/376). All benchmarks pass. No regressions. Commit.

### 3.9 Phase B8: PIR

**Consult PIR methodology** (`docs/tracking/principles/POST_IMPLEMENTATION_REVIEW.org`)
before writing. The PIR must:
1. Follow the 16-question template (§1–§9+)
2. Cross-reference Track 10, PM 8F, SRE Track 1+2 PIRs for longitudinal patterns
3. Include A/B benchmark comparison tables (Pre-0 → A6 → B5)
4. Address: what worked, what surprised, what went wrong, what we learned
5. Distill lessons into target principles documents
6. Note any remaining deferrals with tracking references

## 4. Performance Targets

| Metric | Track 10 result | WS-A target | WS-B target |
|--------|----------------|-------------|-------------|
| Suite wall time | 133.5s | ≤ 134s (no regression) | ≤ 125s (pending call-count justification from B0) |
| `zonk` call count | 55 (revised) | 0 boundary + 31 elab | 0 total |
| CHAMP fallback sites | 36 | 0 | 0 |
| id-map sites | 18 | 0 | 0 |
| Batch worker params | 11 | 6 (D.4 fix) | 6 |
| zonk.rkt lines | ~1300 | ~1300 (still present) | 0 (deleted) |
| Leaked box params | unknown | 0 (A3b audit) | 0 |
| Session metas | mutable hasheq | mutable hasheq | cells |

**Note on targets** (D.4): WS-A value is architectural (code elimination), not
performance — per-operation costs are 1-100ns. The ≤134s target means "no
regression." WS-B's ≤125s depends on zonk call frequency in the suite — B0's
call-count measurement will validate or adjust this target.

## 5. Completion Criteria

### WS-A Complete When:
1. ✅ Zero CHAMP fallback code in metavar-store.rkt
2. ✅ Zero `zonk-final` calls (all → `freeze`)
3. ✅ Zero id-map lookups (all via `expr-meta.cell-id`); `hasmethod-constraint-info` has cell-id
4. ✅ process-string scoping audit: all HIGH-risk `set-box!` sites classified; all identified leaks fixed with regression tests
5. ✅ Batch worker uses fork, not 19-registry snapshot (11→6 saved values)
6. ✅ PUnify toggle ON with zero failures, OR documented gap analysis with dedicated PUnify track + tracking reference
7. ✅ Full suite green (376/376)
8. ✅ Suite wall time ≤ 134s (no regression), no single-file regression > 2× median
9. ✅ A/B benchmarks compared against Pre-0 baselines
10. ✅ Acceptance file passes at Level 3

### WS-B Complete When:
1. ✅ Session metas on propagator network cells
2. ✅ Speculation tests green with session metas on cells (test-speculation-bridge + test-sess-inference)
3. ✅ Zero `zonk` / `zonk-at-depth` / `zonk-session` / `zonk-level` / `zonk-mult` calls (55 sites)
4. ✅ zonk.rkt deleted (except `freeze`, moved to standalone module)
5. ✅ Instrumentation cleanup: dead counters removed, active counters gated behind `#f`
6. ✅ Full suite green
7. ✅ Suite wall time ≤ 125s (or justified deviation from B0 call-count data)
8. ✅ A/B benchmarks (B5) compared against A6 baselines
9. ✅ PIR written per methodology (separate phase B8)

## 6. Principles Alignment

### Propagator-First
- **A1**: `with-fresh-meta-env` creates a network. Every code path has a network. No more "network-optional" contexts.
- **B1**: Session metas move onto the network. Last holdout of mutable-hash meta storage eliminated.
- **A5**: PUnify toggle validates that propagator-based unification IS the default.

### Completeness
- **B2-B3**: Zonk elimination is the "hard thing done right." 1300 lines of tree-walking substitution → 0. Cell reads provide the same information at O(1) per meta, not O(tree-depth).
- **A3**: id-map elimination completes the PM 8F vision. The meta IS the cell — no indirection.

### Data Orientation
- **A4**: Batch worker uses data (forked network) not imperative snapshot/restore.
- **B1**: Session meta store becomes immutable cells, not mutable hasheq.

### Correct-by-Construction
- **A1**: CHAMP fallback removal means the system CAN'T fall back to the old path. The new path is the ONLY path — correctness by elimination of alternatives.
- **B0**: Scoping audit ensures boxes don't leak. Leaks are structural impossibilities, not runtime checks.

### Challenge: What could go wrong? (D.3 Self-Critique)

**A1 — `(not (current-prop-net-box))` sentinel in driver.rkt (CONFIRMED)**:
Lines 1390, 1437, 1482 in driver.rkt check `(if (not (current-prop-net-box)) ...)`
to decide whether to create a network. This was Track 10 Phase 3d's defense-in-depth.
After A1 makes networks always-available, these checks become dead code. **Action**:
remove the sentinel checks in A1. They're defense-in-depth that A1 renders unnecessary.

**A2 — Default timing unspecified**:
"After S2 commit" is vague. Defaults must apply after EACH COMMAND's resolution loop
(not after the entire module). A level meta unsolved after one command's S2 should be
defaulted before the next command sees it. **Action**: specify "defaults apply in
`process-command`'s post-resolution cleanup, before `freeze`."

**A3 — `hasmethod-constraint-info` has bare meta ID, no cell-id (CONFIRMED)**:
`hasmethod-constraint-info-dict-meta-id` stores a bare symbol ID, not an `expr-meta`
struct. Line 625-626 of metavar-store.rkt calls `prop-meta-id->cell-id` on it — this
is a genuine id-map dependency that can't be eliminated by just reading `expr-meta.cell-id`.
**Action**: A3 must add `cell-id` to `hasmethod-constraint-info` struct (set at creation
time when the expr-meta is available), or look up cell-id from the expr-meta when creating
the constraint. Without this fix, the id-map cannot be fully eliminated.

**A3 — Deserialized cell-ids and current network**:
Deserialized `.pnet` cell-ids were assigned during original elaboration. For PRELUDE modules
(loaded once, frozen), this is correct — the cell-ids are stable. For re-elaborated modules
(staleness triggered), new cell-ids are assigned. This is handled by the staleness check:
stale modules re-elaborate, getting fresh cell-ids. **Status**: already handled.

**A5 — PUnify parity bugs deferred AGAIN = process smell**:
The 5 known bugs (head, map, Pair, match, Vec) have been deferred since March 19 — over
a week. Our own workflow rule says: "Pre-existing issue is a process smell. If cost >30
minutes/session in workarounds, escalate." PUnify toggle is blocking the full propagator-
first vision. **Action**: strengthen A5 — commit to FIXING the 5 bugs (not just classifying
and deferring). If they can't be fixed in A5's scope, document WHY and create a dedicated
PUnify Track with a design doc.

**B3 — No stored zonk references (CONFIRMED SAFE)**:
Grep confirmed all zonk usage is direct calls, not callbacks or stored references.
Deletion produces compile-time errors for any missed sites. Correct-by-construction.

**B6 — Comprehensive parameter audit needed**:
The design lists known instrumentation params, but the lesson from Track 10 Phase 2 is:
"audit ALL, don't list known items." **Action**: B6 should grep ALL `make-parameter`
definitions and classify each as: core state, instrumentation, or dead. Don't rely on
known items list — find everything.

### D.4 External Critique Response

12 recommendations received. 10 accepted, 1 partially accepted, 1 pushed back.

| # | Recommendation | Action |
|---|---------------|--------|
| 1 | Batch worker count: 6 not 4 | **Accept**: fixed in tracker + A4 |
| 2 | Move B0 before A4 | **Accept**: moved to A3b |
| 3 | Move A5 after A4 | **Accept**: tests against final WS-A state |
| 4 | Split B1 into sub-phases | **Accept**: B1a-B1d (cell infra, reads, speculation, defaults) |
| 5 | type-lattice.rkt 8 zonk sites | **Accept**: B2 scope expanded to 55 sites |
| 6 | zonk-at-depth investigation timebox | **Accept**: B0 call-count measurement |
| 7 | Firm instrumentation commitments | **Accept**: gate behind #f, decide perf-counters |
| 8 | Revise performance targets | **Accept**: ≤134s (WS-A), ≤125s (WS-B pending B0) |
| 9 | Strengthen criteria | **Accept**: outcome-based A5, speculation for B1, tolerance |
| 10 | Acceptance file | **Accept**: A0b added |
| 11 | Specify batch worker structure | **Accept**: A4 deliverables expanded |
| 12 | .pnet stale reference risk | **Push back**: box indirection handles this (Track 10 Phase 3d verified) |

**Code verification** (D.4):
- `type-lattice.rkt` has 8 `zonk-at-depth 1` sites in merge function — CONFIRMED
- `zonk-at-depth` has NO side effects beyond tree-walking + `shift` — CONFIRMED
- All zonk usage is direct calls, no stored references — CONFIRMED (D.3)

## 7. NTT Speculative Syntax

After Track 10B, the module loading architecture maps to NTT as:

```prologos
;; The unified prelude — no CHAMP fallback, no id-map, no zonk
network prelude : PreludeNet
  :lifetime :persistent
  :serializable true                    ;; .pnet cache
  :contains [module-defs registries persistent-cells]

;; Test isolation via fork
fork test-context : PreludeNet -> TestNet
  :shares [all-cells]                   ;; structural sharing via CHAMP
  :resets [worklist fuel contradiction] ;; fresh per-test
  :isolation :copy-on-write

;; No serialize/deserialize form yet — deferred to PPN Track 0
;; (grammar-based self-describing serialization)
```

**NTT gap confirmed**: The `serialize` / `deserialize` forms proposed in
Track 10 D.4 remain proposals. Track 10B does not implement them — the
current ad-hoc `struct->vector` + `write`/`read` mechanism continues.
These forms become concrete when PPN Track 0 delivers grammar-based
serialization.
