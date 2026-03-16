# Track 4: ATMS Speculation — Post-Implementation Review

**Date**: 2026-03-16
**Duration**: ~2 hours implementation (single session, continued from Track 3 + design work)
**Design time**: ~1.5 hours (D.1–D.5 design iterations, critique rounds)
**Design-to-implementation ratio**: ~0.75:1 (contrast with WFLE's 6:1 — Track 4 was lower risk, well-precedented by Tracks 1–3)
**Commits**: 7 implementation (from `50b00d8` through `f0f72da`), plus design/doc commits
**Test delta**: +28 new tests (7096 → 7124, TMS cell unit tests)
**Code delta**: ~600 lines added across 5 `.rkt` files
**Suite health**: 7124 tests, 371 files, 187.1s — all pass, no regressions (2.4% faster than baseline)
**Design doc**: `docs/tracking/2026-03-16_TRACK4_ATMS_SPECULATION.md`
**Acceptance file**: `examples/2026-03-16-track4-acceptance.prologos`
**Prior PIR**: Track 3 PIR (`2026-03-16_TRACK3_CELL_PRIMARY_REGISTRIES_PIR.md`)

---

## 1. What Was Built

Track 4 integrated TMS (Truth Maintenance System) cells into the propagator network for speculation-aware type inference. All four meta types (type, level, multiplicity, session) now have per-meta TMS cells that support assumption-tagged branching. Learned-clause integration prunes speculation branches known to be inconsistent from prior failures.

This is infrastructure, not user-facing: the type checker produces identical results, identical error messages. The change is architectural — speculative type-checking state now lives in the propagator network as TMS cells rather than in separate CHAMPs, and `save-meta-state` dropped from 6 boxes to 3.

### Key deliverables

1. **TMS cell infrastructure** (Phase 1): `tms-cell-value` struct with recursive CHAMP tree, `tms-read`/`tms-write`/`tms-commit`/`merge-tms-cell`, `make-tms-merge` domain-aware merge factory, `net-new-tms-cell` factory
2. **TMS-transparent read/write** (Phase 2): `net-cell-read` auto-unwraps TMS values via `tms-read` with depth-0 fast path; `net-cell-write`/`net-cell-write-widen` auto-wraps; `elab-fresh-meta` creates TMS cells with `type-lattice-merge`
3. **Per-meta TMS cells for all meta types** (Phase 3): Level, mult, session metas now have per-meta TMS cells with dual write (CHAMP + cell) and cell-primary reads; `save-meta-state` reduced from 6 boxes to 3
4. **Learned-clause pruning** (Phase 5): Before executing a speculation branch, `atms-consistent?` check prunes branches subsumed by known nogoods; `perf-inc-speculation-pruned!` counter for observability

### What did NOT change

- Speculation stack push (deferred to Track 6 — belt-and-suspenders network restore handles rollback)
- Meta-info CHAMP → write-once registry (Phase 4 deferred to Track 6 — 3-box save/restore works correctly)
- No user-facing behavior changes — same error messages, same type checking results

---

## 2. Timeline and Phases

| Phase | Commit | Time (wall) | Tests | Description |
|-------|--------|-------------|-------|-------------|
| D.1–D.5 | `cf4001b`..`ae82836` | ~1.5h | — | Design analysis, critique, lattice rework, recursive CHAMP design |
| 0 | `50b00d8` | ~15min | 7096 | Acceptance file (12 sections, 1056 lines) + performance baseline (191.6s) |
| 1 | `ecde661` | ~25min | 7123 | TMS cell infrastructure + 27 unit tests (197.0s) |
| 2 | `10ecb0c` | ~30min | 7124 | TMS-transparent read/write + domain-aware merge (196.1s) |
| 3 | `addaf46` | ~25min | 7124 | Level/mult/session → per-meta TMS cells, save/restore 6→3 boxes (188.2s) |
| 4 | — | — | — | Deferred to Track 6 (meta-info CHAMP simplification — see §Phase 4 Deferral in design doc) |
| 5 | `f0f72da` | ~15min | 7124 | Learned-clause pruning via `atms-consistent?` (187.1s) |
| 6 | `62ecb3f` | ~10min | 7124 | Performance validation: 187.1s vs 191.6s baseline, acceptance L3 0 errors |
| 7 | `efbc70b` | — | — | PIR (this document) |

**Note on Phase 2**: This phase included a failed attempt (Phase 2c) to push the speculation stack, which was reverted after discovering the "already solved" bug (see §4.1). The successful Phase 2 committed the TMS-transparent read/write without stack push.

---

## 3. Test Coverage

### New tests

28 new unit tests in `test-tms-cell.rkt` covering:
- TMS cell struct basics (base, branches, hasheq)
- `tms-read` at depths 0, 1, 2, 3 (tree traversal, fallback to base)
- `tms-write` (nested CHAMP insert, overwrite)
- `tms-commit` (base promotion)
- `merge-tms-cell` (recursive tree merge)
- `net-new-tms-cell` factory (with TMS merge)
- TMS-transparent network read/write via `net-cell-read`/`net-cell-write`
- Speculative write workflow simulation (push stack, write, read under assumption)

### Integration coverage

The existing 7096 tests provide full integration coverage for the TMS-transparent layer — every test that exercises type inference now runs through TMS cells at depth 0 (base fast path). This is the critical coverage: if TMS wrapping introduced any regression in the read/write path, the entire test suite would catch it.

### Acceptance file

The acceptance file (`2026-03-16-track4-acceptance.prologos`) exercises 12 sections (A–L) covering union types, nested unions, map widening, generic dispatch, Peano arithmetic, Int/Rat, HOFs, lambdas, let/closures, Option/Result, and collections. 76 speculation events, 113 ATMS hypotheses, 32 nogoods. 0 errors at L3 throughout all phases.

### Coverage gap

No tests exercise TMS cells at speculation depth > 0 in the production code path (because the speculation stack push was deferred). The 28 unit tests simulate speculative writes via manual stack manipulation, but the actual `with-speculative-rollback` still operates at depth 0. This gap closes when Track 6 implements the stack push.

---

## 4. Bugs Found and Fixed

### 4.1 "Already solved" errors from premature speculation stack push (Phase 2c, reverted)

**Problem**: Phase 2c attempted to push the speculation stack in `with-speculative-rollback`, routing cell writes to TMS branches. On speculation success, `solve-meta-core!` wrote the solution to both the meta-info CHAMP (status → 'solved) and the TMS cell (via `net-cell-write`). The cell write went to the TMS branch (depth 1), but subsequent depth-0 reads saw the stale base value (`type-bot`). Meanwhile, the CHAMP marked the meta as 'solved. Later code that checked `meta-solved?` via cell read got `#f` (bot ≠ solved), while code that checked via CHAMP got `#t`. This inconsistency cascaded into "already solved" errors when the same meta was re-solved during a retry.

**Why it seemed right**: The design doc's Phase 2 specified "push assumption onto speculation stack" as a core step. The TMS write/read paths worked correctly in unit tests. The bug only manifested when the dual-write path (CHAMP + cell) interacted with the TMS branching — the CHAMP write doesn't know about TMS depth, so it unconditionally writes to the flat status field.

**Fix**: Reverted the stack push. Deferred to Track 6, where commit-on-success machinery will promote TMS branch values to base after successful speculation, keeping depth-0 reads consistent.

**Root cause**: The dual-write pattern (CHAMP + cell) creates a coherence requirement — both must agree on solved/unsolved status at all times. TMS branching breaks this coherence because the cell sees branch depth but the CHAMP doesn't. Eliminating the dual write (Track 6 Phase 4) removes the coherence requirement.

### 4.2 Domain-unaware TMS merge missed contradictions (Phase 2, caught in tests)

**Problem**: The initial `merge-tms-cell` implementation merged TMS values structurally (newer base wins, union branches) without applying domain-specific merge logic. This meant `type-lattice-merge` — which detects type contradictions — was never called for TMS cells. Contradiction detection was silently disabled.

**Why it seemed right**: The structural merge correctly handles TMS tree shape (recursive branch union). Domain merge seemed like an optimization, not a correctness requirement.

**Fix**: Created `make-tms-merge`, a factory that takes a domain merge function and produces a TMS merge that applies the domain merge at the base/leaf level. `elab-fresh-meta` now creates TMS cells with `make-tms-merge(type-lattice-merge, type-lattice-contradicts?)`.

**Caught by**: `test-elaborator-network.rkt` — existing tests for contradiction detection failed when TMS cells were introduced without domain-aware merge.

---

## 5. Design Decisions and Rationale

### 5.1 Depth-0 fast path (zero-overhead common case)

At speculation depth 0 (the common case for all 7096+ existing tests and most elaboration operations), `tms-read` returns `base` directly via a single `null?` check on `(current-speculation-stack)`. No tree traversal, no filtering. This means TMS cells add zero overhead beyond one conditional per read for the vast majority of type-checking operations.

**Rationale**: `meta-solved?` and `meta-solution` are the hottest operations in the type checker. Any per-read overhead would be catastrophic. The depth-0 fast path was identified in the D.5 design iteration as the key to making TMS cells viable.

### 5.2 Belt-and-suspenders rollback

During Phases 2–5, both network-box restore AND TMS cells coexist. The network snapshot handles rollback; TMS cells are passive (always at depth 0). This was a deliberate design choice, not a compromise — attempting to activate TMS branching (§4.1) revealed that the dual-write coherence problem must be solved first.

**Rationale**: The Layered Recovery Principle (established in Tracks 1 and 2) — each phase must leave the system in a working state. Belt-and-suspenders lets TMS cells prove themselves incrementally without requiring the full retraction pipeline to be operational.

### 5.3 Domain-aware TMS merge factory

`make-tms-merge` takes a domain merge function (e.g., `type-lattice-merge`) and a contradiction predicate, producing a TMS merge that applies domain logic at the base/leaf level while handling TMS tree structure at the branch level.

**Rationale**: Separation of concerns — TMS tree management is domain-independent (recursive CHAMP merge), but value merge is domain-specific (type lattice, mult lattice, last-write-wins for levels/sessions). The factory pattern lets each cell type specify its own domain merge.

### 5.4 save/restore reduction (6 → 3 boxes)

Moving level/mult/session meta state into per-meta TMS cells within the network means their state is captured by the network snapshot. `save-meta-state` no longer needs to snapshot the three separate CHAMPs.

**Rationale**: Each box in save/restore is a fragility point — any new mutable state that participates in speculation must be manually added. Reducing from 6 to 3 eliminates half the maintenance surface. The remaining 3 (network, id-map, meta-info) are candidates for Track 6's further reduction.

### 5.5 Phase 4 deferral (save/restore 3 → 1)

Meta-info CHAMP → write-once registry and id-map removal from save/restore were deferred to Track 6. See the design doc's §Phase 4 Deferral Rationale for the full prerequisite chain analysis.

**Rationale**: The prerequisite chain (stack push → commit-on-success → TMS retraction → 1-box) means Phase 4 cannot be implemented in isolation. The 3-box pattern works correctly and is already a 50% improvement. Forcing Phase 4 into Track 4 would have meant either (a) implementing the entire retraction pipeline (scope creep) or (b) implementing Phase 4 without retraction (creates new coherence bugs).

### 5.6 Per-meta TMS cells for level/mult/session (not aggregate)

Each level, mult, and session metavariable gets its own TMS cell, paralleling the existing per-meta type cells. The alternative (one aggregate TMS cell per meta type) would require per-key assumption tracking within a CHAMP — more complex and harder to reason about.

**Rationale**: Per-meta cells are simpler (each is a single lattice element with assumption tags), match the existing type meta architecture, and the cell count is small (typically a few dozen level/session metas per command).

---

## 6. Lessons Learned

### 6.1 Dual-write creates coherence requirements that TMS branching violates

The meta-info CHAMP records `status='solved` when a meta is solved. The TMS cell records the solution value. At depth 0, both agree. At depth > 0, the cell writes to a TMS branch while the CHAMP writes unconditionally. This creates an inconsistency: the CHAMP says "solved" but the cell reads "unsolved" (base = bot). The Phase 2c "already solved" bug (§4.1) is a direct consequence.

**Implication**: Any future TMS activation (stack push) MUST eliminate the dual write first. The prerequisite chain is: eliminate CHAMP dual write → push speculation stack. This ordering was not obvious from the design doc, which listed them as independent steps.

### 6.2 Domain-aware merge is non-negotiable for TMS cells

The generic `merge-tms-cell` (newer base wins) doesn't trigger domain-specific operations like contradiction detection. `make-tms-merge(type-lattice-merge)` applies the domain merge at base level, enabling `contradicts?` checks. Without this, TMS cells silently disable a core type-checking feature. Caught by existing tests (§4.2), but the failure mode was subtle — tests passed but with wrong merge behavior that would only manifest under speculation.

**Implication**: Any new TMS cell type must specify a domain merge, not rely on the default. The `make-tms-merge` factory makes this the path of least resistance.

### 6.3 The mechanical pattern from Track 3 extends to TMS conversion

Phase 3 (level/mult/session → TMS cells) was purely mechanical once Phase 2 established the TMS-transparent pattern. The same `elab-fresh-*-cell` → `net-new-tms-cell` + callback parameter + cell-primary read pattern applied identically three times. This echoes Track 3's lesson (PIR §6.1) that Phase 2 was purely mechanical once Phase 1 established the guard pattern.

**Pattern**: The first conversion in a new subsystem is where all the design decisions happen. Subsequent conversions in the same subsystem are mechanical application of the established pattern. Budget time accordingly.

### 6.4 Speculation stack push requires commit-on-success

Writing to TMS branches during speculation is correct for the failure path (retraction makes writes invisible). But on success, the thunk's mutations must be visible at depth 0. Without `tms-commit` machinery wired into the success path of `with-speculative-rollback`, depth-0 reads see stale base values. This was discovered empirically in Phase 2c, not predicted by the design doc.

**Implication**: The design doc's Phase 2 steps (push stack, run thunk, commit on success) cannot be implemented incrementally — they must be implemented together or not at all. "Push without commit" is a bug, not a partial implementation.

### 6.5 Performance can improve from structural simplification

The 2.4% speedup (191.6s → 187.1s) was unexpected — the hypothesis was that TMS cells would be performance-neutral (depth-0 fast path) or slightly slower (wrapper overhead). The improvement came from reducing save/restore from 6 box copies to 3. Each box copy is O(1) (CHAMP structural sharing), but the constant factor of 6 copies per speculation event × 76 speculation events per acceptance command adds up.

### 6.6 Learned-clause pruning fires 0 times in practice (infrastructure, not optimization)

The `atms-consistent?` check before speculation found 0 pruneable branches in the acceptance file. This is because the ATMS resets per command — nogoods from one command don't carry over to the next. Pruning would fire in pathological cases: deeply nested union-of-union types within a single expression where the same meta participates in multiple failed speculation branches.

**Implication**: Phase 5 is infrastructure for Track 9 (GDE) and extreme cases, not a performance optimization. The 0-prune result is expected, not a failure. If it later fires frequently, that indicates a pathological speculation pattern that deserves investigation.

---

## 7. What Went Well

1. **The design iteration process worked**: Five design iterations (D.1–D.5) settled all major questions before implementation. The recursive CHAMP tree representation (D.5) was the key insight — it made TMS reads O(d) via indexed CHAMP traversal instead of O(k) via list scan with subset checks.

2. **Track 3's patterns transferred directly**: The callback parameter pattern (`current-prop-fresh-level-cell`, etc.), the cell-primary read with fallback, and the elaboration guard concept all applied without modification. Track 3 was the rehearsal; Track 4 was the performance.

3. **Acceptance file caught nothing new**: All 12 sections passed at L3 after every phase. This means the TMS-transparent layer is genuinely transparent — no behavioral change, as designed. The acceptance file's value here is as a regression gate, not a bug-finder.

4. **Performance improved**: 2.4% faster, not slower. The depth-0 fast path hypothesis was validated.

## What Went Wrong

1. **Phase 2c's premature stack push**: The design doc's phasing suggested stack push as part of Phase 2, but the dual-write coherence problem wasn't surfaced until implementation. This cost ~20 minutes of debugging and a revert. The design should have identified the CHAMP dual-write as a blocker.

2. **Phase 4 deferral wasn't pre-planned**: The design doc listed Phase 4 as non-conditional ("Phase 4 is not conditional" — D.4 revision note). Implementation revealed it requires the full retraction pipeline. The deferral decision was correct, but it should have been anticipated during design.

## Where We Got Lucky

1. **The depth-0 fast path covered all existing tests**: If any existing test exercised speculation (e.g., via direct parameterization of `current-speculation-stack`), TMS cells at depth > 0 would have been exercised without the commit machinery. This would have surfaced the §4.1 bug in a much harder-to-debug context (test failure rather than a focused Phase 2c experiment).

2. **No performance regression despite wrapping all meta reads**: Every `net-cell-read` now has a TMS unwrap path (check if cell value is `tms-cell-value?`, if so call `tms-read`). The `null?` fast path on the speculation stack means this is effectively free, but if Racket's struct predicate check had measurable overhead on the hottest path, we'd have seen a regression. The bet that struct checks are negligible paid off — but it was a bet.

## What Surprised Us

1. **Phase 3 was faster than Phase 2**: Adding three new meta types' worth of TMS cells (Phase 3, 188.2s) was faster than converting the existing type meta cells (Phase 2, 196.1s). The delta likely comes from reducing save/restore boxes rather than TMS overhead — the 6→3 box reduction happened in Phase 3.

2. **The `provenance-counters` struct needed updating**: Adding `speculation-pruned-count` required updating all 3 constructor call sites in `driver.rkt` (adding the 8th positional argument). This is the Pipeline Exhaustiveness checklist's "New Struct Field" pattern — but for a performance counter struct, not an AST node. Minor but illustrative.

---

## 8. Architecture Assessment

### How the architecture held up

The propagator network architecture accommodated TMS cells with minimal friction:
- `prop-network`'s cells CHAMP stores both monotonic and TMS cells without structural changes
- The existing `net-cell-read`/`net-cell-write` API gained TMS awareness transparently
- The merge function protocol (`make-tms-merge` wrapping domain merges) composed cleanly with the existing merge infrastructure

### Extension points that were sufficient

- **Cell factory** (`net-new-tms-cell`): Clean extension of `net-new-cell` with TMS-specific parameters
- **Callback parameters** (`current-prop-fresh-level-cell`, etc.): Same pattern as Track 3's `current-prop-cell-read`, extended without modification
- **Performance counters**: Struct extension (adding `speculation-pruned-count`) was trivial

### Friction points

- **save/restore**: The 3-box pattern works but is inherently fragile — it's a manual list of state that participates in speculation. The architecture should capture this automatically (which is what Track 6's TMS retraction achieves).
- **Dual-write coherence**: The CHAMP + cell dual write creates implicit coupling that TMS branching violates. This is not new (dual write has been present since the Migration Sprint), but TMS activation surfaces it as a bug.

---

## 9. What's Next

### Immediate (Track 5, unblocked by Track 4)

- **Global-env cell-primary conversion**: 36 remaining `(current-global-env)` reads in `driver.rkt`
- **Per-module network context**: Enables module loading with a network, eliminating the two-context architecture
- **Dependency edges**: Per-definition propagator edges for incremental re-elaboration

### Medium-term (Track 6, absorbs Track 4 Phase 4)

- **Speculation stack push + commit-on-success**: Route cell writes to TMS branches, promote to base on success
- **TMS retraction**: Replace network-box restore with per-cell assumption retraction
- **save/restore → 1 box**: Network snapshot becomes the single source of truth
- **Dual-write elimination**: Remove parameter writes for all 28+ registries

### Long-term (Track 9, enabled by Track 4)

- **General Diagnostic Engine**: Multi-hypothesis conflict analysis using ATMS nogoods
- **Minimal diagnoses**: Type errors traced to the minimal set of assumptions that caused them
- **Error derivation chains**: Every speculative value in the network connects to its assumption provenance

---

## 10. Deferred Work

All deferred to **Track 6** (see design doc §Phase 4 Deferral Rationale and master roadmap §Deferrals):

| Item | Blocked by | Track |
|------|-----------|-------|
| Speculation stack push | Commit-on-success | Track 6 |
| Commit-on-success (`tms-commit` on success path) | TMS retraction | Track 6 |
| TMS retraction (replace network-box restore) | — (foundational) | Track 6 |
| Meta-info CHAMP → write-once registry | TMS retraction (for `all-unsolved-metas`) | Track 6 |
| save/restore 3 → 1 box | All of the above | Track 6 |

These form a prerequisite chain: stack push → commit → retraction → 1-box. They cannot be implemented independently.

---

## 11. Metrics

| Metric | Baseline (Phase 0) | Final (Phase 6) | Delta |
|--------|-------------------|-----------------|-------|
| Test count | 7096 | 7124 | +28 |
| File count | 370 | 371 | +1 |
| Suite time | 191.6s | 187.1s | −2.4% |
| Speculations | 76 | 76 | 0 |
| ATMS hypotheses | 113 | 113 | 0 |
| ATMS nogoods | 32 | 32 | 0 |
| Branches pruned | — | 0 | (infrastructure ready) |
| save/restore boxes | 6 | 3 | −50% |
| Implementation code | — | ~600 lines | 5 files |
| Design iterations | — | 5 (D.1–D.5) | — |
| Bugs found | — | 2 (§4.1, §4.2) | Both fixed same session |

---

## 12. Key Files

| File | Role |
|------|------|
| `racket/prologos/propagator.rkt` | TMS cell infrastructure: `tms-cell-value`, `tms-read`/`tms-write`/`tms-commit`, `merge-tms-cell`, `make-tms-merge`, `net-new-tms-cell` |
| `racket/prologos/elaborator-network.rkt` | TMS cell factories: `elab-fresh-level-cell`, `elab-fresh-sess-cell`, `elab-fresh-mult-cell` (converted to TMS) |
| `racket/prologos/metavar-store.rkt` | Per-meta TMS cell creation, cell-primary reads, `save-meta-state`/`restore-meta-state!` (6→3 boxes) |
| `racket/prologos/elab-speculation-bridge.rkt` | Learned-clause pruning via `atms-consistent?`, `current-speculation-stack` usage |
| `racket/prologos/driver.rkt` | Callback registration, provenance counter update |
| `racket/prologos/performance-counters.rkt` | `speculation-pruned-count` field + `perf-inc-speculation-pruned!` |
| `racket/prologos/tests/test-tms-cell.rkt` | 28 unit tests for TMS cell operations |
| `examples/2026-03-16-track4-acceptance.prologos` | L3 acceptance file (12 sections, 1056 lines) |
| `docs/tracking/2026-03-16_TRACK4_ATMS_SPECULATION.md` | Design doc + progress tracker |

---

## 13. Cross-References

### Recurring patterns across PIRs

- **Mechanical pattern transfer** (also Track 3 PIR §6.1): The first conversion in a subsystem is where design decisions happen; subsequent ones are mechanical. Track 3 Phase 2 was mechanical after Phase 1; Track 4 Phase 3 was mechanical after Phase 2. This pattern has held for 4 consecutive tracks. Budget the first phase at 2–3x the subsequent ones.

- **Belt-and-suspenders as standard practice** (also Tracks 1 and 2): The Layered Recovery Principle continues to pay off. Every phase left the system in a working state. The Phase 2c revert was painless because belt-and-suspenders meant the system worked without the stack push.

- **Dual-write coherence** (new pattern, unique to Track 4): This is the first PIR to surface dual-write as a *blocking* issue rather than a maintenance burden. Prior PIRs noted it as technical debt (Track 3 PIR: "dual write continues"). Track 4 reveals it as a hard blocker for TMS activation. This should inform Track 6's phasing — dual-write elimination must precede or accompany stack push.

### Prior PIRs referenced

- Track 3 PIR (`2026-03-16_TRACK3_CELL_PRIMARY_REGISTRIES_PIR.md`) — direct predecessor, same session
- Track 1 PIR (`2026-03-12_TRACK1_CELL_PRIMARY_PIR.md`) — established the cell-primary pattern that Track 4 builds on
- WFLE PIR (`2026-03-14_WFLE_PIR.md`) — calibration for design-to-implementation ratio
