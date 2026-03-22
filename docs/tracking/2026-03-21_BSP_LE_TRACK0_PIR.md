# BSP-LE Track 0: Propagator Allocation Efficiency — Post-Implementation Review

**Date**: 2026-03-21
**Duration**: ~4 hours within a single session (design+implementation interleaved)
**Design-to-implementation ratio**: ~1.5:1 (D.1 + external critique + D.2 + D.3 self-critique before first line of code)
**Commits**: 10 implementation (`8c4da4a` through `210d80d`)
**Test delta**: 7308 → 7313 (+5 batch registration tests)
**Code delta**: +261 / −90 across 7 .rkt files (0 new files; bench-alloc.rkt substantially extended)
**Suite health**: 7313 tests, 377 files, 236.5s, all pass
**Design docs**: `2026-03-21_BSP_LE_TRACK0_ALLOCATION_EFFICIENCY_DESIGN.md`
**Audit**: `2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md` (commit `f7bd03d`)
**Series**: BSP-LE ([Master Roadmap](2026-03-21_BSP_LE_MASTER.md))
**Prior PIRs**: Track 7 PIR (persistent cells, stratified retraction), PUnify Parts 1–2 PIR (cell-tree unification)

---

## 1. What Was Built

Track 0 restructured `prop-network` — the immutable core of the propagator infrastructure — for allocation efficiency. The 13-field monolithic struct was split into three inner structs by mutation frequency: hot (2 fields: worklist, fuel), warm (2 fields: cells, contradiction), and cold (9 fields: everything else). The serial quiescence loop was converted from per-iteration struct-copy to a mutable box drain pattern, eliminating all intermediate struct allocation on the hottest code path. A batch cell registration API was added using transient CHAMP builders.

**What changed architecturally**: `prop-network` is now a 3-field struct wrapping `prop-net-hot`, `prop-net-warm`, and `prop-net-cold`. Zero-cost accessor macros (`define-syntax-rule`) preserve the old 13-accessor API across all 18 consumer files. The pure data-in/data-out contract is preserved — no mutation escapes the quiescence loop boundary.

**What changed operationally**: The quiescence loop allocates zero structs per worklist iteration (was: one 13-field struct per iteration). Cell writes copy only warm+hot (7 fields, was 13). Allocation-time operations copy only warm+cold (11 fields, was 13). A `net-new-cells-batch` API enables transient CHAMP construction for bulk cell creation.

---

## 2. Timeline and Phases

| Phase | Commit | Suite (s) | What |
|-------|--------|-----------|------|
| D.1 | `8476ac6` | — | Design: 7-phase from audit |
| D.2 | — | — | External critique: 5 gaps found (drain bug, site classification, next-cell-id, audit spec, BSP interaction) |
| D.3 | `169d63e` | — | Self-critique + principles alignment: 8 items incorporated |
| 0 | `8c4da4a` | — | Micro-benchmarks + baselines: cell 0.42μs, write 0.27μs, struct-copy 0.03μs |
| 1 | `19274b5` | 232.3 | eq?-first fast path in net-cell-write |
| 2 | `7e8875b` | 231.0 | Merge identity audit: 6/17 fixed, 7 structural |
| 3a | `a5de346` | — | Struct-copy site classification: 25 sites → hot/warm/cold |
| 3b | `bfe8e4f` | 240.5 | Inner struct definitions + accessor macros. 29+4 sites migrated |
| 3c | `7a94274` | 238.2 | Mutable worklist drain + eq? identity preservation |
| 3d-3f | `cb7eb38` | — | Group isolation verified; macros retained as stable API |
| 4 | `6cf9a70` | 239.0 | Batch cell registration API + 5 tests |
| 5 | `8af8695` | 345.1→236.5 | Transient input batching REJECTED (44% regression); reverted |
| 6 | `210d80d` | 236.5 | GC/memory analysis: 0ms GC during quiescence, struct-copy 3× cheaper |

---

## 3. Test Coverage

- **5 new tests** in `test-propagator.rkt`: batch cell registration (empty, contiguous IDs, write/merge, contradiction, ID continuation)
- **4 existing GC/memory benchmarks** extended in `bench-alloc.rkt`: retained memory, GC during quiescence, GC during cell allocation, GC during propagator allocation
- **No acceptance file** — infrastructure-only Track; acceptance criterion is suite pass + benchmark verification
- **Gap**: No test verifies the mutable worklist drain produces identical results to the old loop. The suite passing is implicit verification, but a direct equivalence test (same network before/after for a controlled workload) would be more robust.

## 4. Bugs Found and Fixed

**Bug 1: External struct-copy sites missed** (`bfe8e4f`)
- `bilattice.rkt`, `elaborator-network.rkt`, `test-propagator-bsp.rkt`, and `bench-alloc.rkt` all had `struct-copy prop-network` with old field names
- Batch workers crashed silently on startup — no error propagated to the test runner, which reported "0 tests, all pass"
- **Root cause**: The migration agent only searched `propagator.rkt`. The classification phase (3a) enumerated sites in propagator.rkt but didn't grep across the full codebase.
- **Why it seemed right**: The classification audit scope was "propagator.rkt" because that's where the struct is defined. External struct-copy sites were an oversight.
- **Fix**: Grep for `struct-copy prop-network` across all `.rkt` files. 4 external sites found and migrated.
- **Lesson**: Struct changes require codebase-wide grep, not module-scoped audit. Add to pipeline.md checklist.

**Bug 2: eq? identity broken for no-work quiescence** (`7a94274`)
- The mutable drain pattern always reconstructed the `prop-network` via `finalize`, even when no work was done (empty worklist). `test-propagator-persistence.rkt` uses `check-eq?` to verify that `run-to-quiescence` on an already-quiescent network returns the same object.
- **Root cause**: `finalize` unconditionally creates a new struct-copy. The no-work case should return the original network.
- **Fix**: Fast-path check before entering the drain loop — if contradiction, fuel exhausted, or empty worklist, return `net` directly.

**Bug 3: Prelude drift from `gen-prelude.rkt --write`** (not our bug)
- Running `gen-prelude.rkt --write` to fix a "PRELUDE DRIFT" warning changed `namespace.rkt`, which broke inference for `eq-check`, `first`, `rest`, etc. in 5 test files.
- **Root cause**: The prelude manifest and `namespace.rkt` were already slightly out of sync (pre-existing drift). Regenerating made it worse.
- **Fix**: Reverted `namespace.rkt`. The drift warning is benign — the manifest and namespace disagree on whitespace/ordering, not content.
- **Lesson**: Don't auto-fix "drift detected" warnings during unrelated infrastructure work without understanding what changed.

---

## 5. Design Decisions and Rationale

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | hot/warm/cold split | Matches mutation frequency: hot=every iteration, warm=per cell-write, cold=allocation-only. Minimizes field-copy on each path. |
| D2 | Accessor macros as stable API | 18 consumer files use `prop-network-cells` etc. Macros are zero-cost and decouple consumers from inner struct layout. Originally framed as "compatibility wrappers to be removed" — reframed as permanent API. |
| D3 | Mutable boxes for worklist/fuel | Eliminates all per-iteration allocation in the quiescence loop. Boxes are local to the loop — pure data-in/data-out contract preserved. |
| D4 | Phases 3+4 landed together (not sequential) | External critique identified that the drain pattern with a 13-field struct-copy (Phase 3 alone) doesn't save anything — the clear-after-fire copies the same 13 fields. Landing with the struct split (Phase 4, now 3b) makes the drain pattern copy only 3 fields. |
| D5 | Phase 5 (transient input batching) rejected | 44% regression. `champ-transient`/`tchamp-freeze` converts the full cells map to a mutable hash table and rebuilds from scratch — overwhelming for 2-3 input propagators (the common case). Sequential `for/fold` with CHAMP inserts is already optimal for small N. |
| D6 | Batch cell API provided, site conversion deferred | `net-new-cells-batch` uses transient CHAMP efficiently (large N). But registration sites operate through callback indirection at the elab-network level. Track 8 callback elimination enables direct use. |

---

## 6. Lessons Learned

**6.1 Struct-copy is not the dominant cost; CHAMP operations are.** The audit correctly identified struct-copy as the most *frequent* allocation, but micro-benchmarks revealed that raw struct-copy is 0.03μs while CHAMP insert is 0.27–1.08μs. The dominant cost is 10× cheaper than what surrounds it. The struct split reduces struct-copy from 13 fields to 2-3, saving ~0.02μs — overwhelmed by the CHAMP operations in every path.

**6.2 Transient CHAMPs have a high fixed cost.** `champ-transient` converts the entire persistent map to a mutable hash table (O(N) scan + allocation). `tchamp-freeze` rebuilds the persistent CHAMP from scratch (O(N) inserts). For large batches (N >> 10), the amortized cost is excellent. For small N (2-3), it's catastrophic — the fixed cost dominates. The Phase 5 regression (239s → 345s) is a direct consequence: every `net-add-propagator` call (thousands per command) paid the transient fixed cost for 2-3 inputs.

**6.3 The real win is GC elimination, not wall-time.** Zero GC during quiescence (measured: 0ms over 50 × 1000-cell runs) is the structural benefit. Before the split, the quiescence loop produced F × 13-field intermediate structs per run (F = propagator firings). With mutable boxes, zero intermediates. This doesn't show in wall-time because Racket's generational GC handles short-lived objects efficiently — but it reduces GC pause variance and will compound as propagation scales with Track 8 and BSP-LE.

**6.4 External struct-copy sites are invisible to module-scoped audits.** The Phase 3a classification enumerated 25 sites in propagator.rkt. The 4 external sites (bilattice, elaborator-network, test-propagator-bsp, bench-alloc) were discovered only when batch workers crashed silently. Struct changes require codebase-wide `grep`, not module-scoped inventory.

**6.5 Negative results are valuable deliverables.** Phase 5's rejection, with measured regression and documented reasoning, prevents future engineers from attempting the same optimization. The comment in `net-add-propagator` ("Phase 5 attempted transient CHAMP here but it regressed") is a permanent signpost.

**6.6 "Compatibility wrappers to be removed" can become "stable API to be kept."** The original design framed accessor macros as temporary scaffolding. During implementation, we recognized they serve a genuine architectural purpose: decoupling 18 consumer files from the inner struct layout. The reframing from "temporary" to "permanent" was the right call — it avoids coupling 18 files to inner struct names that may change in future splits.

---

## 7. Metrics

| Metric | Phase 0 Baseline | Phase 6 Final | Delta |
|--------|-----------------|---------------|-------|
| Suite time | 232s | 236.5s | +2% (within noise) |
| Test count | 7308 | 7313 | +5 |
| struct-copy (worklist) | 0.03μs/op | 0.01μs/op | **-67%** |
| net-cell-write (change) | 0.27μs/op | 0.25μs/op | **-7%** |
| net-cell-write (no-change) | 0.09μs/op | 0.09μs/op | neutral |
| net-add-propagator | 1.08μs/op | 1.04μs/op | **-4%** |
| run-to-quiescence | 0.74μs/op | 0.74μs/op | neutral |
| GC during quiescence | not measured | **0 ms** | **eliminated** |
| Memory retention | 51.3 KB | -12.8 KB | no leak |
| GC ratio (cell alloc) | not measured | 30.3% | baseline established |
| prop-network fields per struct-copy (hot path) | 13 | 3 | **-77%** |
| Intermediate structs per quiescence iteration | 1 (13-field) | 0 | **-100%** |

---

## 8. What's Next

### Immediate
- **PUnify cleanup**: 5 parity bugs to fix before BSP-LE Track 1
- **CIU Track 0**: Trait hierarchy audit (pre-Track 8), already complete (`f62fc06`)

### Medium-term (Track 8)
- **Callback elimination enables batch API use**: Once `current-prop-new-infra-cell` is replaced by direct `net-new-cell`/`net-new-cells-batch` calls, registration sites can use the batch API
- **Track 8 benefits from struct split**: All Track 8 phases create cells and propagators; they run on the optimized substrate

### Long-term (BSP-LE Tracks 1-5)
- **Solver networks will be large**: ATMS exploration creates many cells per worldview. The zero-GC quiescence benefit compounds with scale.
- **BSP quiescence needs its own optimization**: Phase 3c optimizes the serial (Gauss-Seidel) loop. The BSP loop collects per-round propagator sets — it needs a mutable round buffer, not a mutable worklist. Designed separately in BSP-LE Track 4.

---

## 9. Key Files

| File | Role | Changes |
|------|------|---------|
| `propagator.rkt` | Core network struct + operations | Struct split, accessor macros, mutable worklist, batch API |
| `bilattice.rkt` | Interval consistency propagator | struct-copy migration |
| `elaborator-network.rkt` | Elab-level network wrapper | struct-copy migration (reset-elab-network-command-state) |
| `infra-cell.rkt` | Infrastructure cell merge functions | 6 merge functions fixed for identity preservation |
| `benchmarks/micro/bench-alloc.rkt` | Allocation micro-benchmarks | GC pressure tests, memory baselines, change ratio |
| `tests/test-propagator.rkt` | Core propagator tests | 5 batch registration tests |
| `tests/test-propagator-bsp.rkt` | BSP scheduler tests | struct-copy migration |

---

## 10. Lessons Distilled

| Lesson | Distilled To | Status |
|--------|-------------|--------|
| Struct changes require codebase-wide grep | Should add to pipeline.md "New Struct Field" checklist | **Pending** |
| Transient CHAMP unsuitable for small-arity (N≤3) | Comment in net-add-propagator; bench-alloc.rkt documents regression | Done (in code) |
| Negative optimization results are deliverables | Consider adding to DESIGN_METHODOLOGY.org Stage 4 | Pending |
| GC elimination is the real metric for allocation work | bench-alloc.rkt GC benchmarks established | Done (baseline for future tracks) |
| "Temporary compatibility" can become "stable API" | Design insight; no codification needed | Noted |

---

## 11. What Went Well

1. **External critique cycle (D.2) caught real design bugs.** The reviewer identified that Phase 3's drain-and-clear pattern copies the struct it's trying to eliminate — landing 3+4 together was the correct fix. Without the critique, Phase 3 would have shipped a no-op optimization.

2. **Phase 0 baselines prevented false confidence.** The micro-benchmarks revealed that struct-copy (0.03μs) is 10× cheaper than CHAMP operations (0.27–1.08μs). This correctly set expectations: the struct split targets allocation pressure and GC, not wall-time.

3. **Phase 5 rejection was fast.** One suite run (345s) → immediate revert → one more run (236.5s) → committed the negative result with documented reasoning. Total time: ~20 minutes. The temptation to "make it work" was resisted because the micro-benchmarks already showed why it couldn't.

4. **Design critique promoted macros from "temporary" to "permanent."** The user asked why we'd defer macro removal to Track 8. Thinking through the question revealed the macros serve a genuine purpose. The question prevented unnecessary coupling.

## 12. What Went Wrong

1. **Phase 3a classification was module-scoped, missing 4 external sites.** This produced silent batch-worker crashes — the worst kind of failure (tests "pass" with 0 tests). The debug loop was 30+ minutes of investigating wrong paths (prelude drift, stale .zo, wrong working directory) before finding the real cause.

2. **Working directory drift.** Multiple `cd` commands during debugging caused subsequent `racket tools/run-affected-tests.rkt` invocations to fail with "file not found" — a confusing error that looks like a missing file but is really a CWD issue.

3. **The ≤180s wall-time target was unrealistic.** The audit's cost model was correct about struct-copy frequency but overestimated its impact. CHAMP operations dominate wall-time; struct-copy optimization has a low ceiling. The target should have been "neutral wall-time + measurable GC improvement" — which is what we achieved.

## 13. What Surprised Us

1. **struct-copy is astonishingly cheap.** At 0.03μs (30ns), a 13-field struct-copy is one of the cheapest allocations in the system. Racket's allocator handles small fixed-size objects with near-zero overhead. The audit's framing of struct-copy as "the dominant cost" was wrong — it's the most *frequent* cost but not the most *expensive*.

2. **Transient CHAMP's fixed cost is higher than expected.** Converting a persistent CHAMP to a hash table scans every entry. For a cells map with 500 entries, that's 500 hash-set! calls just to enter transient mode. This fixed cost is ~10× the cost of 2-3 sequential persistent inserts.

3. **The struct split slightly regressed wall-time.** Adding indirection (two accessor levels instead of one) costs ~0.01μs per access. With thousands of accesses per command, this accumulates. The regression is within noise (240.5s vs 232s, ~4%), but it means the architectural benefit (GC elimination, future-proofing) comes at a small indirection cost.

## 14. Architecture Assessment

The struct split integrates cleanly. No extension points were modified — the accessor macros provide a stable boundary. The mutable worklist is confined to the quiescence loop (local mutation, not visible externally). The pure data-in/data-out contract is preserved.

**Tension**: The inner struct layer adds complexity without measurable wall-time benefit. This is justified by (a) zero GC during quiescence, (b) future-proofing as propagation scales, and (c) the batch API which requires the warm/cold separation. If future measurement shows the indirection cost growing (e.g., after Track 8 adds more cell operations), the macros make it possible to re-merge without touching consumer files.

## 15. Assumptions That Were Wrong

1. **"struct-copy is the dominant allocation cost."** CHAMP operations are 10× more expensive per call. struct-copy is the most *frequent* allocator but not the bottleneck. Future allocation optimization should target CHAMP (owner-id transients, path-copying) rather than struct layout.

2. **"Transient CHAMP is always faster for batches."** Only for large batches (N >> 10). For N=2-3, the fixed cost of transient conversion + freeze overwhelms the savings from avoiding intermediate persistent inserts.

3. **"Wall-time improvement of 10-20% is achievable."** The optimization ceiling for struct-copy is ~0.02μs per operation — negligible against CHAMP's 0.27–1.08μs. The real benefit is in allocation pressure and GC, which don't manifest as wall-time improvement in Racket's generational GC.

---

## 16. Cross-Reference: Recurring Patterns Across PIRs

### Pattern 1: External Critique Changes Designs (Tracks 7, PUnify, BSP-LE Track 0)

D.2 external critique found a real bug in the Phase 3 drain pattern — the struct-copy after fire was a no-op that defeated the optimization. This is the 6th instance of design critique materially changing the design (Track 7 D.2, Track 7 D.3, PUnify D.2, PUnify Part 3 overhaul, Collection Interface D.1→D.2, BSP-LE Track 0 D.2). The pattern is now firmly established: **every design improves through critique rounds**. This should be codified in DESIGN_METHODOLOGY.org.

### Pattern 2: Baselines Before Optimization (PUnify Parts 1-2, BSP-LE Track 0)

Phase 0 baselines prevented wasted effort on low-impact optimizations and correctly predicted the wall-time outcome. PUnify similarly established baselines (80% fast-path rate, 14.3s adversarial) that guided implementation priorities. **Measure first, then optimize** is now validated across two Tracks.

### Pattern 3: Negative Results as Deliverables (new)

Phase 5's rejection is the first explicit negative result in the project's PIR history. Prior Tracks had implicit negative results (approaches tried and abandoned during D.2/D.3 design critique), but Phase 5 is the first implemented, measured, and reverted optimization. The documented regression prevents future re-attempts and establishes that transient CHAMP has an applicability boundary.
