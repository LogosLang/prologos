# CHAMP Performance — Post-Implementation Review

**Date**: 2026-03-21
**Duration**: ~3 hours within a single session (audit + design + implementation)
**Design-to-implementation ratio**: ~1:1 (D.1 + external critique D.2 + self-critique D.3, then 7 phases)
**Commits**: 8 implementation (`c3e1b37` through `cfcead4`)
**Test delta**: 7313 → 7330 (+17 acceptance tests in `test-champ-owner-id.rkt`)
**Code delta**: +450 / −64 across 3 .rkt files (0 new source files; 1 new test file)
**Suite health**: 7330 tests, 378 files, 232.9s, all pass
**Design docs**: [CHAMP Performance Audit](2026-03-21_CHAMP_PERFORMANCE_AUDIT.md), [CHAMP Performance Design](2026-03-21_CHAMP_PERFORMANCE_DESIGN.md)
**Prior work**: [BSP-LE Track 0 PIR](2026-03-21_BSP_LE_TRACK0_PIR.md) (identified CHAMP as actual bottleneck; Phase 5 rejected due to transient overhead)
**Prior PIRs**: BSP-LE Track 0, PUnify Parts 1-2, Track 7

---

## 1. What Was Built

The CHAMP (Compressed Hash Array Mapped Prefix-tree) — the persistent hash trie backing all propagator network state — was optimized in three layers:

**Low-risk wins (Phases 1-3)**: `vector-copy!` (memcpy) replaces manual element-by-element loops in `vec-insert`/`vec-remove`. All 6 key comparison sites use `eq?`-first with `equal?` fallback. Value-only updates return the identical node (zero allocation) when the new value is `eq?` to the existing value — propagating through ALL trie levels so the entire merge→champ-insert→net-cell-write chain short-circuits on no-change writes.

**Owner-ID transient infrastructure (Phases 4-6)**: Each `champ-node` gains an `edit` field (gensym per transaction). Owned nodes are mutated in place; shared nodes are path-copied and stamped. Three transient operations (`tchamp-insert-owned!`, `tchamp-delete-owned!`, `tchamp-insert-join-owned!`) follow the ownership discipline. `tchamp-freeze-owned` walks the trie clearing edit fields — O(modified nodes), not the old O(N log N) full rebuild.

**Verification + rehabilitation (Phase 7)**: The owner-ID transient cycle at N=2 measured 6.0μs vs the old hash-table transient's 95.5μs — **16× faster**. This rehabilitated BSP-LE Track 0 Phase 5: `net-add-propagator` now uses owner-ID transients for dependency registration, eliminating the 44% regression that caused Phase 5's rejection.

---

## 2. Timeline and Phases

| Phase | Commit | Suite (s) | What |
|-------|--------|-----------|------|
| D.1 | `12035d0` | — | Audit (8 findings) + design (7 phases) |
| D.2 | `a3337e6` | — | External critique: 7 items (ownership invariant, make-de allocation, freeze cost, accumulate pattern) |
| D.3 | `310573a` | — | Self-critique: 6 gaps (acceptance test, delete/insert-join scope, pipeline checklist, deferred section, exposure constraint) |
| 0 | `c3e1b37` | — | Baselines: insert 0.16μs, transient N=2: 95.5μs. 8 §A acceptance tests |
| 1-3 | `57e052d` | 234.7 | vector-copy!, eq?-first (6 sites), value-only fast path (all trie levels). 3 §B tests |
| 4 | `1fd5eff` | 232.5 | Edit field on champ-node. 12 constructor sites. Zero regression |
| 5-6 | `ce5a4df` | 234.7 | Owner-ID transient insert/delete/insert-join + freeze. 6 §C-F tests |
| 7 | `cfcead4` | 232.9 | Benchmarks: N=2 95.5→6.0μs (16×). net-add-propagator rehabilitated |

---

## 3. Test Coverage

- **17 new tests** in `test-champ-owner-id.rkt` across 6 sections:
  - §A (8): Persistent baseline — insert, update, delete, insert-join, large map, fold, identity, existing transient
  - §B (3): Value-only update identity — same-value returns eq? node, different-value returns new node, chain of 100 same-value updates
  - §C (3): Owner-ID transient — insert+freeze, delete, insert-join
  - §D (1): Concurrent transients don't interfere
  - §E (1): Freeze invariant — `champ-all-persistent?` verifies no owned nodes remain
  - §F (1): Post-freeze transient copies, not mutates
- **31 internal CHAMP tests** (champ.rkt module+ test) — all pass unchanged
- **Gap**: No test exercises the owner-ID transient under high concurrency stress (many interleaved transients on the same base map). The D1 test covers 2 concurrent transients; a stress test with 10-20 would be more thorough.

---

## 4. Bugs Found and Fixed

**Bug 1: Value-only fast path didn't propagate through trie levels** (`57e052d`)
- Phase 3 added `(eq? val existing-val)` check at the leaf node level. But for multi-level tries, the parent node still copies its content vector to update the child pointer — even though the child pointer didn't change (child returned the same node).
- **Root cause**: `node-insert`'s child-recurse case always did `(vector-copy arr)` + `(vector-set! new-arr idx new-child)` regardless of whether `new-child eq? child`.
- **Fix**: Added `(if (eq? new-child child) (values node #f) ...)` check at the child-recurse level. Also added `(if (eq? new-node old-node) root ...)` check at the `champ-insert` root level.
- **Why it matters**: Without propagation, the §B3 test ("100 same-value updates return eq? root") failed — intermediate levels reconstructed nodes needlessly.

**Bug 2: champ-insert always reconstructed champ-root** (`57e052d`)
- `champ-insert` called `(champ-root new-node ...)` unconditionally, creating a new root wrapper even when the node was unchanged.
- **Root cause**: The root-level function didn't check eq? on the node before wrapping.
- **Fix**: `(if (eq? new-node old-node) root (champ-root new-node ...))`.

No bugs in the owner-ID transient implementation (Phases 4-6). The acceptance tests caught both Phase 3 bugs before they reached the full suite.

---

## 5. Design Decisions and Rationale

| # | Decision | Rationale | Outcome |
|---|----------|-----------|---------|
| D1 | `eq?`-first (Option B) over per-map parameter | Simpler, no API change, benefits all CHAMPs | Proven pattern from Track 0 Phase 1 |
| D2 | Edit field on `champ-node` (4th field) | Per-node ownership enables partial path-copying | Zero regression (232.5s vs 234.7s) |
| D3 | `gensym` for edit tokens | Globally unique, never recycled — ownership invariant guaranteed by Racket language spec | No correctness issues |
| D4 | Three critique rounds (D.1→D.2→D.3) | D.2 caught ownership invariant gaps; D.3 caught missing delete/insert-join, pipeline checklist, acceptance test | 7th instance of design critique materially changing design |
| D5 | Accumulate-during-quiescence deferred to post-Track-8 | Threading transient through callback-based `net-cell-write` would create temporary API complexity that Track 8 removes | Conceptual design documented; implementation clean when callbacks eliminated |
| D6 | Accessor macros retained from Track 0 | Decouples 18 consumer files from inner struct layout | Validated: Phase 4's struct change to champ-node required no external file updates |

---

## 6. Lessons Learned

**6.1 Owner-ID transients are the correct answer for persistent data structure performance.** The hash-table-based transient was a stopgap that worked for large batches but catastrophically regressed for small ones (95.5μs at N=2). Owner-ID transients achieve O(modified paths) regardless of batch size — 6.0μs at N=2, 0.28μs at N=100. The Clojure community discovered this over a decade ago; our independent rediscovery confirms the design is load-bearing, not incidental.

**6.2 Value-only fast paths must propagate through ALL levels of a recursive structure.** Adding eq? at the leaf level is insufficient — parent levels must also check whether their children changed. This is the same principle as BSP-LE Track 0's eq?-first in `net-cell-write` but applied recursively through the trie. The general rule: **any identity-preserving optimization in a recursive structure must be applied at every recursion level, not just the base case.**

**6.3 Negative results are reversible when the underlying constraint changes.** BSP-LE Track 0 Phase 5 was rejected because the hash-table transient was too expensive for small batches. The CHAMP Performance Track removed that constraint (owner-ID transients). The Phase 5 approach — transient for dependency registration — was correct in concept; only the implementation mechanism was wrong. This validates documenting rejections with clear reasoning: the documented "why" made it straightforward to revisit when the "why" changed.

**6.4 Three critique rounds (D.1→D.2→D.3) is now the established pattern.** D.1 captures the initial design. D.2 (external) catches structural issues (ownership invariant, make-de allocation, freeze cost model). D.3 (self-critique + principles alignment) catches methodology gaps (acceptance tests, pipeline checklists, scope completeness). Each round found genuinely different issues — they're not redundant.

**6.5 Phase 0 baselines establish the quantitative target that Phase 7 validates against.** The N=2 transient cycle at 95.5μs was the target; Phase 7 measured 6.0μs. Without the baseline, the 6.0μs result has no meaning. With it, we can say "16× improvement." This is the same pattern as BSP-LE Track 0 (baselines before optimization) now validated across a second Track.

**6.6 The audit→design pipeline produces well-scoped Tracks.** The CHAMP Performance Audit identified 8 findings with priority rankings (P0: owner-ID, P1: eq?-first + value-only, P2: vector-copy!, P3: deferred items). The design translated these directly into 7 phases ordered by priority and dependency. No phase was added during implementation that wasn't in the audit; no audit finding was dropped without explicit deferral. The pipeline works.

---

## 7. Metrics

| Metric | Phase 0 Baseline | Phase 7 Final | Delta |
|--------|-----------------|---------------|-------|
| Suite time | 234.7s (post-Track 0) | 232.9s | -0.8% (within noise) |
| Test count | 7313 | 7330 | +17 |
| champ-insert (sequential) | 0.16μs | — | (not re-measured — Phases 1-3 benefit is structural) |
| champ-insert (value-only) | 0.10μs | **→ 0 when eq?** | (Phase 3: identity fast path) |
| Old transient N=2 | **95.5μs** | — | (hash-table based) |
| Owner-ID transient N=2 | — | **6.0μs** | **16× faster** |
| Owner-ID transient N=10 | — | **1.1μs** | **18× faster** (vs old 19.4μs) |
| Owner-ID transient N=100 | — | **0.28μs** | **9× faster** (vs old 2.57μs) |
| Owner-ID value-only update | — | **0.07μs** | 30% faster than persistent (0.10μs) |
| champ-node fields | 3 | 4 | +1 (edit field, ~8 bytes/node) |
| net-add-propagator (suite) | 234.7s (sequential) | 232.9s (owner-ID) | neutral (was 345s with old transient) |

---

## 8. What's Next

### Immediate
- **PUnify cleanup**: 5 parity bugs (next in implementation order)
- **PM Track 8 D.1 critique**: Design ready, informed by CIU Track 0 + both allocation tracks

### Medium-term (Track 8 + post-Track 8)
- **Accumulate-during-quiescence**: Owner-ID transients enable the pattern where the quiescence loop operates on an owned transient, cell writes mutate in place, and freeze produces the persistent result. Implementation deferred to post-Track-8 (callback elimination enables clean API threading). This could eliminate CHAMP allocation on the entire hot path.
- **net-new-cells-batch with owner-ID**: Track 0's batch API uses the old transient; switching to owner-ID would improve batch cell creation for moderate N.

### Long-term (BSP-LE Tracks 2-4)
- **BSP per-round transient**: Each BSP round could operate on an owned transient — all propagator firings within a round mutate in place, freeze at round boundary. Natural fit for the owner-ID architecture.
- **ATMS worldview transient**: Speculative exploration creates temporary cell states. Owner-ID transients provide efficient per-worldview mutation with O(modified-nodes) rollback via freeze/abandon.

---

## 9. Key Files

| File | Role | Changes |
|------|------|---------|
| `champ.rkt` | CHAMP implementation | Phases 1-6: vec-insert, eq?-first, value-only, edit field, owner-ID transient, freeze |
| `propagator.rkt` | Primary CHAMP consumer | Phase 7: net-add-propagator uses owner-ID transient |
| `benchmarks/micro/bench-alloc.rkt` | Micro-benchmarks | Phase 0 baselines + Phase 7 owner-ID benchmarks |
| `tests/test-champ-owner-id.rkt` | Acceptance tests | 17 tests across 6 sections (A-F) |

---

## 10. Lessons Distilled

| Lesson | Distilled To | Status |
|--------|-------------|--------|
| Identity fast paths must propagate through all recursion levels | This PIR §6.2 | Noted — consider adding to DEVELOPMENT_LESSONS.org |
| Negative results are reversible when constraints change | This PIR §6.3; extends BSP-LE Track 0 PIR Pattern 3 | Noted |
| Three critique rounds (D.1→D.2→D.3) is the established pattern | 7th instance; should codify in DESIGN_METHODOLOGY.org | **Pending** — now 7 instances across 4 Tracks |
| Audit→design pipeline produces well-scoped Tracks | This PIR §6.6; extends WORK_STRUCTURE.org §2.2 | Already codified |
| Baselines before optimization (3rd instance) | Extends BSP-LE Track 0 PIR Pattern 2 | Already noted in prior PIR |

---

## 11. What Went Well

1. **The audit→design→implementation pipeline was seamless.** The audit identified 8 findings; the design translated them into 7 phases; implementation followed the phases exactly. No scope creep, no mid-implementation redesign, no deferred phases (all 7 delivered).

2. **Three critique rounds caught genuinely different issues.** D.1 was the initial design. D.2 (external) caught the ownership invariant gaps, the freeze cost inconsistency, and the make-de remaining allocation. D.3 (self-critique) caught the missing acceptance test, the missing delete/insert-join in Phase 5 scope, the pipeline.md checklist reference, and the deferred section. None of these overlapped — each round was independently valuable.

3. **Phase 3's value-only fast path compounds with Track 0's merge identity audit.** The full chain — merge function returns identical input → champ-insert returns identical node → net-cell-write returns identical network — now short-circuits with zero allocation on no-change writes. This wasn't designed as a cross-Track optimization; it emerged from two independent Tracks (Track 0 Phase 2 + CHAMP Phase 3) converging on the same identity-preservation principle.

4. **The 16× transient improvement directly rehabilitated a prior rejection.** BSP-LE Track 0 Phase 5 was rejected with measured evidence (345s regression). CHAMP Phase 7 rehabilitated it with measured evidence (232.9s neutral). The documentation chain — rejection with reasoning → new capability → re-test with new capability — is a model for how negative results should be tracked and revisited.

## 12. What Went Wrong

1. **Phase 3 initially didn't propagate through parent levels.** The value-only check was added at the leaf but not at the child-recurse and root levels. The §B3 acceptance test caught this immediately — the test infrastructure worked as designed (acceptance test as progress instrument). But the gap reveals a pattern: **optimizations in recursive structures must be applied at every level, not just the base case.** This is easy to miss because the base case is where the optimization is conceptually motivated.

2. **No wall-time improvement on the full suite.** The CHAMP optimizations (Phases 1-6) produced 232.9s vs 234.7s baseline — within noise. The 16× transient improvement is real but `net-add-propagator` is called ~50 times per command (vs ~100 cell writes per command). The hot path (cell writes) still uses persistent CHAMP inserts, not transients. The accumulate-during-quiescence pattern would change this, but it's deferred.

## 13. What Surprised Us

1. **Owner-ID transient N=2 is 6.0μs, not the ~0.3μs target.** The design targeted "~0.3μs for small-batch viability" (2× persistent insert cost). The actual 6.0μs is 16× better than the old 95.5μs but still 37× a persistent insert. The overhead is the initial path-copy of the root node + freeze walk. For N=2 on a 500-entry map, the first insert path-copies 1-2 depth levels (1 vector-copy each), the second mutates in place, then freeze walks 1-2 owned nodes. The path-copy cost is inherent — it's the price of ownership discipline.

2. **Phase 4 (edit field) had zero measurable regression.** The design predicted ~3% regression from the 4th field. Actual: 232.5s vs 234.7s — if anything, slightly faster. Racket's struct allocation is so cheap that one extra field is unmeasurable against CHAMP operation noise.

3. **The value-only fast path + eq?-first compound more than expected.** Phase 3 alone saves one vector-copy when values are identical. But combined with Phase 2 (eq?-first key comparison), the lookup before insert is also faster. And combined with Track 0 Phase 2 (merge identity), the merge function returns the identical value more often. Three independent optimizations compound multiplicatively on the no-change path.

## 14. Architecture Assessment

The owner-ID transient integrates cleanly into the existing CHAMP. The persistent API is unchanged — all existing code works unmodified. The new owner-ID API (`champ-transient-owned`, `tchamp-insert-owned!`, etc.) is additive. The old hash-table transient API is retained for backward compatibility (used by `net-new-cells-batch` which operates at large N where both approaches work).

**Tension**: Two transient APIs now coexist. The old one is inferior for all batch sizes (owner-ID is faster at every N). The old API should be deprecated once all callers migrate. Currently: `net-new-cells-batch` uses old transient; `net-add-propagator` uses owner-ID. Migration path: switch `net-new-cells-batch` to owner-ID, then deprecate old API.

The `champ-node` struct grew from 3 to 4 fields. This is permanent — the edit field supports both persistent (#f) and transient (gensym) modes in the same struct. The alternative (separate structs for persistent and transient nodes) would require dispatch on every access, which is worse than an unused field.

## 15. Assumptions That Were Wrong

1. **"N=2 transient target is ~0.3μs."** Actual: 6.0μs. The path-copy cost of the root node on first touch is inherent — you can't mutate a shared node in place. For a 500-entry map, the root node has a ~16-element content vector that must be copied. This is a fixed cost per transient, independent of how many inserts follow.

2. **"The value-only fast path is a leaf-level optimization."** Wrong — it must propagate through all trie levels. The recursive structure means a leaf optimization that doesn't propagate is invisible at the root, because parent levels still reconstruct.

## 16. Cross-Reference: Recurring Patterns Across PIRs

### Pattern 1: Design Critique Changes Designs (7th instance)

D.2 external critique caught ownership invariant gaps, freeze cost inconsistency, and Phase 5 scope incompleteness. D.3 self-critique caught acceptance test omission, pipeline checklist reference, and deferred section. This is now the 7th instance (Track 7 D.2, Track 7 D.3, PUnify D.2, PUnify Part 3, Collection Interface D.1→D.2, BSP-LE Track 0 D.2, CHAMP Performance D.2+D.3). **The three-round pattern (D.1→D.2→D.3) should be codified as the standard design cycle.**

### Pattern 2: Baselines Before Optimization (3rd instance)

Phase 0 baselines (N=2 at 95.5μs) established the quantitative target. Phase 7 validated against it (6.0μs, 16×). This is the 3rd instance (PUnify: 80% fast-path; BSP-LE Track 0: struct-copy 0.03μs; CHAMP: N=2 at 95.5μs). Each baseline prevented wasted effort and enabled crisp validation.

### Pattern 3: Negative Results Rehabilitation (new)

BSP-LE Track 0 Phase 5 was rejected with measured evidence. CHAMP Phase 7 rehabilitated it with measured evidence. The documentation chain made this possible: the rejection recorded *why* (transient overhead, not the batching concept), so when the *why* changed (owner-ID transients), the rehabilitation was straightforward. This extends the "negative results as deliverables" pattern from BSP-LE Track 0 PIR — negative results are not just deliverables, they're **provisional**: future work may remove the constraint that caused the rejection.

### Pattern 4: Cross-Track Optimization Compounding (new)

Track 0 Phase 2 (merge identity) + CHAMP Phase 2 (eq?-first keys) + CHAMP Phase 3 (value-only fast path) compound multiplicatively on the no-change path. These three optimizations were designed independently in different Tracks but converge on the same identity-preservation principle. The full chain — merge returns identical input → champ-insert returns identical node → net-cell-write returns identical network — produces zero allocation through the entire stack. **Independent optimizations on the identity-preservation principle compound without coordination.**
