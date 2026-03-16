# Track 5: Global-Env Consolidation + Dependency Edges — Post-Implementation Review

**Date**: 2026-03-16
**Duration**: ~5.5 hours design + implementation (08:34 – 14:07 PST, two sessions with context break)
**Commits**: 16 (from `339fedb` through `8e782d5`)
**Test delta**: +24 new tests (7124 → 7148)
**Code delta**: +1696 lines, −127 lines across 24 files
**Suite health**: 7148 tests, 372 files, 213.3s — all pass, no regressions
**Design doc**: `docs/tracking/2026-03-16_TRACK5_GLOBAL_ENV_DEPENDENCY_EDGES.md`
**Acceptance file**: `examples/2026-03-16-track5-acceptance.prologos`
**Prior PIR**: Track 4 PIR (`2026-03-16_TRACK4_ATMS_SPECULATION_PIR.md`)

---

## 1. What Was Built

Track 5 converted `current-global-env` from parameter-primary to a two-layer cell architecture with persistent per-module networks and cross-module dependency edges.

**Before Track 5**: Module definitions lived in immutable hasheq snapshots cached in `module-info`. Module loading accumulated definitions by `hash-set` into a parameter. Cross-module dependencies were implicit (buried in elaboration trace, not recorded).

**After Track 5**: Each loaded module has a `module-network-ref` — a persistent propagator network holding one cell per definition, a lifecycle status cell (`mod-loaded`), a materialized snapshot hash (belt-and-suspenders), and a `dep-edges` map recording which definitions depend on which others (with same-file vs module source annotations). Definition writes during elaboration go through `global-env-add`, which writes to Layer 1 cells when a prop-network is active and falls back to `current-global-env` parameter update when not. The 22 env-threading wrappers in driver.rkt are eliminated — `global-env-add` is now self-updating.

This is infrastructure for incremental re-elaboration: when an LSP server detects a source change, the dependency edges identify which definitions need re-checking, and the persistent module networks provide the stable environment for doing so.

---

## 2. Timeline and Phases

| Phase | Commit | Time | Tests | Suite (s) | Description |
|-------|--------|------|-------|-----------|-------------|
| D.1 | `339fedb` | 08:34 | — | — | Stage 2/3 design document |
| D.2 | `17142ec` | 10:27 | — | — | Rework: persistent module networks, cross-module edges, lifecycle |
| D.2+ | `b0c63bc` | 10:53 | — | — | External critique: shadow-cell pattern, performance hypotheses |
| D.3 | `9febbb5` | 11:09 | — | — | Self-critique: principle alignment (6 aligned, 3 tensions) |
| 0 | `157f7aa` | 11:47 | 7124 | 187.1 | Acceptance file (294 expressions, 12 BUGs) + baseline |
| 1 | `7ad5b88` | 12:18 | 7139 | ~196 | Module-network-ref infrastructure + shadow-cell prototype (15 tests) |
| 2 | `085b77d` | 12:34 | 7139 | 196.8 | `global-env-remove!` + failure cleanup consolidation |
| 3 | `011fe3f` | 12:53 | 7147 | 207.7 | Per-module network activation + dual-path validation |
| 4 | `b70331a` | 13:06 | 7148 | ~209 | Cross-module dependency edge recording |
| 5 | `1fb01ea` | 14:06 | 7148 | 213.3 | Write consolidation + dual-path validation removal |
| 6 | — | 14:07 | 7148 | 213.3 | Performance validation (this session) |

**Design-to-implementation ratio**: Design (D.1–D.3) took ~2.5 hours. Implementation (Phases 0–6) took ~2.5 hours. Ratio ≈ 1:1. This reflects three factors: (1) the design built on well-established patterns from Tracks 1–4, (2) the risk profile was moderate (no user-facing changes), (3) the D.2 rework was substantial (persistent networks, lifecycle lattice, shadow-cell pattern were all settled in design, not discovered during implementation).

**Context break**: The session hit a context limit between Phases 4 and 5. The continuation summary captured all state accurately; no rework was needed. Phase 5's regression (§4.1) was introduced in the continuation session, not caused by the break.

---

## 3. Test Coverage

### New tests

24 new tests in `test-module-network-01.rkt`:
- 9 lifecycle merge tests (`mod-status-merge` lattice: stale dominates, loaded beats loading)
- 7 CRUD tests (make, add-definition, lookup, write, set-status, materialize)
- 4 shadow-cell prototype tests (cross-network read, propagation, simulated reload)
- 4 dependency edge tests (same-file, module source, edge list structure)

### Integration coverage

The existing 7124 tests provide comprehensive integration coverage. Every test that loads a module (via `ns` or `imports`) exercises the module-network-ref construction path (Phase 3), the cell-aware global-env-add path (Phase 5), and the cross-module dep recording (Phase 4). The dual-path validation in Phase 3 verified cell/hash agreement across all 200+ module loads in the full suite before being removed in Phase 5.

### Acceptance file

The acceptance file (`2026-03-16-track5-acceptance.prologos`) exercises 13 sections (A–L, Z) covering prelude operations, trait dispatch, pattern matching, data structures, closures, pipelines, string/char, maps, modules, generics, higher-order functions, and a baseline canary. 294 pass, 0 errors, 12 pre-existing BUGs documented. Run at L3 after every phase with 0 regressions.

### Coverage gap

No tests exercise the dependency edges at the *consumer* level — no code reads `dep-edges` to trigger re-elaboration. The edges are recorded and stored, but their consumption is LSP scope. The Phase 4 unit tests verify edge structure but not edge-triggered behavior.

---

## 4. Bugs Found and Fixed

### 4.1 Phase 5a: Env-threading removal broke 65 test files

**Problem**: Phase 5a removed 22 `(current-global-env (global-env-add ...))` wrappers in driver.rkt, since `global-env-add` returns env unchanged when cell infrastructure is active (prop-net-box set). The assumption was that the wrapper was always a no-op.

**Why it was wrong**: 65 test files use `run-ns-last` from `test-support.rkt`, which creates a fresh environment *without* a prop-network (`current-prop-make-network` defaults to `#f`). In this path, `reset-meta-store!` doesn't create a network, so `current-global-env-prop-net-box` remains `#f` inside `process-command`. `global-env-add` then takes the legacy hash-set path and returns a *new* hash — the `(current-global-env ...)` wrapper was the mechanism that persisted this new hash into the parameter.

**Symptoms**: Two failure modes:
1. "Unbound variable" errors in module loading (e.g., `prologos::core::eq`) — definitions written during module loading were lost
2. `hash-set: contract violation, expected hash?, given #<void>` — tests using `global-env-add` functionally (composing return values) got void from `(current-global-env ...)` setter instead of a hash

**Fix**: Moved the parameter update *into* `global-env-add` itself. In the cell path: write to Layer 1 cells, return env unchanged. In the legacy path: update `current-global-env` parameter AND return the new hash (preserving functional composition). This makes `global-env-add` self-updating — callers never need the wrapper.

**Root cause**: The analysis assumed `current-global-env-prop-net-box` is always set inside `process-command`. This is true when `current-prop-make-network` is set (which is always the case in production — `process-file` and `process-string` set it up). But `run-ns-last` in test-support.rkt doesn't set up the network factory, so the 65 test files that use it operate in the legacy (no-network) path. The design doc's audit ("Category A: ~23 env-threading writes") didn't distinguish between production paths (network always active) and test paths (network sometimes absent).

**Time cost**: ~45 minutes (initial implementation, test run, diagnosis, fix, re-test).

### 4.2 Phase 3: module-info struct field addition required 20 site updates

**Problem**: Adding the 9th `module-network` field to `module-info` required updating every construction site. 15 test-stdlib files had single-line constructions (sed-amenable), but `test-namespace.rkt` had a multi-line construction that sed missed.

**Why it matters**: This is the Pipeline Exhaustiveness pattern (`.claude/rules/pipeline.md` §New Struct Field) applied to a non-AST struct. The same risk applies: stale `.zo` caches cause "expected N fields" errors, and pattern-matching sites must be updated.

**Fix**: sed for the 15 single-line sites, manual Edit for the multi-line site, `raco make driver.rkt` to recompile dependents.

---

## 5. Design Decisions and Rationale

### 5.1 Two-layer architecture (Layer 1 cells + Layer 2 parameter)

Definition lookups check Layer 1 (per-file cells, `current-definition-cells-content`) first, then Layer 2 (prelude/module env, `current-global-env`). This preserves backwards compatibility — the parameter path works for tests, module loading fallback, and any code that reads `current-global-env` directly.

**Rationale**: The alternative (cell-only, no parameter fallback) would require rewriting all 65 test files that use `run-ns-last` and any code that reads the parameter directly. The two-layer approach follows the belt-and-suspenders principle established in Tracks 1–4: both paths coexist, the new path is validated against the old, the old is removed when confidence is established.

### 5.2 Persistent module-network-ref (not ephemeral)

Module networks persist in the module cache (inside `module-info`). They survive across commands and are shared by all importers of that module. This is the foundation for LSP incremental re-elaboration — the network is the stable substrate that outlives any single elaboration.

**Rationale**: The alternative (ephemeral networks materialized on demand) would require re-creating the network structure on every import. Persistent networks with structural sharing (CHAMP) have negligible memory overhead and O(1) lookup — equivalent to the hasheq snapshots they replace.

### 5.3 Dependency edges record source provenance (same-file vs module)

Each dependency edge records whether the source was a same-file definition (`'same-file`) or a module import (`'module`). This distinction matters for re-elaboration: same-file changes require re-checking within the file; module changes may require re-loading the module first.

**Rationale**: A boolean tag is cheap (cons cell) and provides essential information for the LSP invalidation algorithm. Without it, the LSP would need to re-discover source provenance by cross-referencing the module cache — a computation that's O(modules × definitions) instead of O(1) per edge.

### 5.4 global-env-add self-updates (Phase 5 final design)

Rather than removing the env-threading wrapper (which breaks the legacy path), the responsibility was moved into `global-env-add` itself. Both paths (cell and legacy) now handle their own persistence — callers just call `(global-env-add env name type value)` and the function does the right thing.

**Rationale**: This is a better factoring than the original design's "remove wrappers." The original approach required callers to know which path is active; the new approach encapsulates the dispatch. It also eliminates a class of future bugs — any new call site gets correct behavior without remembering to wrap.

### 5.5 Dual-path validation removal timing

The dual-path validation (cell reads match hash reads) ran for Phases 3 and 4 — approximately 7147 tests × 200+ module loads = ~1.4M validation checks with 0 mismatches. This established sufficient confidence to remove the assertion in Phase 5.

**Rationale**: The belt-and-suspenders pattern prescribes removal when confidence is established. Keeping the assertion indefinitely would add O(definitions) work per module load with zero diagnostic value.

---

## 6. Lessons Learned

### 6.1 Test paths and production paths can diverge on infrastructure assumptions

The Phase 5a regression (§4.1) happened because `run-ns-last` doesn't set up `current-prop-make-network`, creating a code path where `global-env-add` uses the legacy (no-network) behavior. This path doesn't exist in production (`process-file`/`process-string` always set up the factory). The design doc's audit of env-threading sites was correct for production but missed the test path.

**Implication**: When analyzing infrastructure changes that depend on "always active" parameters (like prop-net-box), explicitly check whether tests use the same setup. In Prologos, `run-ns-last` vs the shared fixture pattern (`define-values` at module level) have different infrastructure assumptions. The shared fixture pattern goes through `process-string` (full setup), while `run-ns-last` uses a minimal parameterize (no network factory).

### 6.2 Self-updating functions are better than caller-side wrappers

Moving the parameter update into `global-env-add` itself (rather than requiring callers to wrap with `(current-global-env ...)`) is a strictly better factoring. It eliminates 22 wrapper sites, prevents future bugs from missing wrappers, and handles both the cell and legacy paths correctly. The lesson generalizes: when a function's side effects need to be visible to callers, make the function responsible for the visibility — don't delegate it to every call site.

**Implication**: Audit other functions that follow the `(current-X (f (current-X) ...))` pattern. If `f`'s side effects should always be visible, `f` should update the parameter internally.

### 6.3 The mechanical pattern continues: first phase = all decisions, rest = application

Phase 1 (infrastructure + shadow-cell prototype) and Phase 3 (per-module activation) required genuine design work. Phases 2 (removal consolidation), 4 (dep edges), and 5 (cleanup) were mechanical application of patterns established in Phases 1 and 3. This echoes Track 3 PIR §6.1 and Track 4 PIR §6.3: the first conversion is where all decisions happen.

**Pattern maturity**: This pattern has held for 5 consecutive tracks. It's now a planning heuristic: budget Phase 1 at 2–3× subsequent phases.

### 6.4 Belt-and-suspenders with explicit retirement criteria

The dual-path validation had an explicit exit condition: "0 mismatches across the full test suite for ≥2 phases." This made the Phase 5 removal a principled decision rather than an arbitrary one. Prior tracks used belt-and-suspenders but didn't always specify when to remove the safety net.

**Implication**: When introducing a belt-and-suspenders mechanism, define the retirement criteria upfront. Examples: "remove after N test suite runs with 0 divergences," "remove when consumer migration is complete."

### 6.5 Context breaks are manageable with good state capture

The session hit a context limit between Phases 4 and 5. The continuation summary preserved all state accurately — uncommitted changes, file locations, parameter names, design decisions. No rework was needed. The key factors: commit after every phase (state is in git, not in context), update tracking docs with commit hashes (provides traceability), and the summary captured both completed and pending work.

---

## 7. What Went Well

1. **Design iterations settled all major questions**: Three design rounds (D.1, D.2 rework, D.2+ critique) resolved persistent networks, lifecycle lattice, shadow-cell pattern, performance hypotheses, and TMS-ready API before any code was written. No design-level surprises during implementation.

2. **Acceptance file caught 0 regressions across all phases**: The 294-expression acceptance file served as a regression gate after every phase. Its value is cumulative — each phase confirms the entire pipeline still works, not just the new code.

3. **Dual-path validation provided quantitative confidence**: 0 mismatches across ~1.4M checks justified removing the safety net. This is the belt-and-suspenders pattern working as designed — safety net proves correctness, then is removed cleanly.

4. **Phase 2's consolidation eliminated real maintenance burden**: The 6 identical 4-line inline removal patterns (12 `hash-remove` calls) were a genuine DRY violation. `remove-failed-definition!` is both simpler and cell-aware.

5. **Commit-per-phase workflow enabled clean context break recovery**: Every phase was committed before the next started. When the context broke, the git history was the source of truth.

## What Went Wrong

1. **Phase 5a's incorrect assumption about test infrastructure** (§4.1): The analysis that "the wrapper is always a no-op" was wrong for 65 test files. Cost: ~45 minutes of debugging and fix. The error was in the analysis (not checking whether tests use the same infrastructure), not in the approach (self-updating functions are correct).

2. **14% performance overhead**: 213.3s vs 187.1s baseline. The hypothesis was "performance-neutral or slightly faster." The overhead likely comes from the additional parameter updates in `global-env-add`'s legacy path (now updating `current-global-env` on every call, not just the original wrapper sites) and the module-network-ref construction at the end of each module load. This is within the 25% threshold but worth monitoring.

## Where We Got Lucky

1. **The Phase 5a regression was immediately diagnosable**: The error messages ("Unbound variable" in module loading, "`hash-set` given void") pointed directly at `global-env-add` behavior. If the regression had been a subtle type-checking divergence (correct types but different error messages), diagnosis would have taken much longer.

2. **No `run-ns-last` tests exercise dep-edge recording**: If any `run-ns-last` test imported a module and then checked dependency edges, the Phase 4 implementation would have needed to handle the no-network path for dep recording. The recording code only fires when `current-elaborating-name` is set, which requires the full elaboration pipeline — `run-ns-last` tests that use `ns` go through this pipeline, but the dep recording worked correctly because those tests don't inspect the edges.

## What Surprised Us

1. **The dual-path validation found exactly 0 mismatches**: The design doc's risk analysis rated module loading behavior change as "high risk." The belt-and-suspenders approach was motivated by this risk. In practice, the cell and hash paths agreed perfectly from the first test run. This suggests the two-layer architecture is well-factored — writes and reads are symmetric.

2. **Phase 3 required 20 construction site updates for one struct field**: The `module-info` struct's 9th field cascaded to 15 test-stdlib files, test-namespace.rkt, and 4 driver.rkt sites. The Pipeline Exhaustiveness checklist covers AST nodes but the same pattern applies to any widely-constructed struct.

---

## 8. Architecture Assessment

### How the architecture held up

The propagator network architecture accommodated module-network-ref cleanly:
- `make-prop-network` / `net-new-cell` / `net-cell-read` / `net-cell-write` compose naturally for module definition cells
- The CHAMP-based cell storage provides structural sharing between module networks
- The existing `module-info` struct gained the `module-network` field without architectural friction

The two-layer global-env architecture (Layer 1 cells + Layer 2 parameter) is a clean separation of concerns:
- Layer 1 handles per-file definitions with cell-based persistence
- Layer 2 handles prelude/module imports with parameter-based scoping
- `global-env-snapshot` merges both layers transparently

### Extension points that were sufficient

- **Cell factory** (`net-new-cell`): Reused without modification for module definition cells
- **module-info struct**: Transparent struct, easy to extend with a new field
- **global-env-add dispatch**: The `current-global-env-prop-net-box` check cleanly separates cell and legacy paths

### Friction points

- **struct field addition cascade**: Adding a field to `module-info` required 20 construction site updates. This is inherent to Racket's positional struct construction. Named/keyword construction would mitigate it.
- **Test infrastructure divergence**: `run-ns-last` creates a subtly different environment from production code. This isn't a Track 5 problem — it's a project-wide concern that Track 5 surfaced.

---

## 9. What's Next

### Immediate (Track 6, unblocked by Track 5)

- **Dual-write elimination**: Remove parameter writes for all 28+ registries — cells become the sole write target
- **Driver simplification** (Phase 5a-5b in design doc): Env-threading cleanup beyond what Track 5 delivered
- **`current-global-env` → `current-prelude-env` rename**: Bulk rename (266 references) deferred since the parameter now genuinely represents only prelude/module env (Layer 2), not all definitions

### Medium-term (LSP, enabled by Track 5)

- **Incremental re-elaboration**: Use dep-edges to identify which definitions need re-checking when a source file changes
- **Shadow-cell materialization**: Create shadow cells in importing modules for cross-module references, enabling change propagation
- **Module staleness propagation**: Wire `mod-stale` status changes to downstream module networks via the dep-edge graph

### Long-term (Track 9 GDE, enabled by Tracks 4+5)

- **TMS-aware dependency edges**: Pass real ATMS assumptions to `definition-dep-wire!` (currently all `#f` / unconditional)
- **Multi-hypothesis module contexts**: Different LSP parameter contexts yield different module definition sets, tracked by TMS cells

---

## 10. Deferred Work

| Item | Reason | Target |
|------|--------|--------|
| TMS-ready `definition-dep-wire!` with propagator wiring (Phase 4c) | LSP scope — batch mode doesn't need active wiring | Track 6 / LSP |
| Staleness propagation to mod-status (Phase 4d) | Batch mode: modules never become stale | LSP |
| Consumer migration to cell reads (Phase 5b-5c) | `global-env-snapshot` already reads cells; pure-cell consumers are LSP scope | Track 6 |
| `module-network-ref` snapshot-hash removal | Useful as cache; removal is optimization not correctness | Track 6 |
| `current-global-env` → `current-prelude-env` rename | 266 references; mechanical but noisy; not blocking | Track 6 |

---

## 11. Metrics

| Metric | Baseline (Phase 0) | Final (Phase 6) | Delta |
|--------|-------------------|-----------------|-------|
| Test count | 7124 | 7148 | +24 |
| File count | 371 | 372 | +1 |
| Suite time | 187.1s | 213.3s | +14% |
| Module networks | 0 | 15+ (one per loaded module) | — |
| Dep edges recorded | 0 | ~200+ per module load | — |
| Env-threading wrappers | 22 | 0 | −100% |
| Failure cleanup sites | 6 (12 hash-remove) | 1 (`remove-failed-definition!`) | −83% |
| module-info fields | 8 | 9 (+module-network) | +1 |
| Implementation code | — | +1696 lines | 24 files |
| Design iterations | — | 4 (D.1, D.2, D.2+, D.3) | — |
| Bugs found | — | 1 regression (§4.1) + 1 mechanical (§4.2) | Both fixed same session |
| Dual-path mismatches | — | 0 across ~1.4M checks | Belt-and-suspenders validated |

---

## 12. Key Files

| File | Role |
|------|------|
| `racket/prologos/global-env.rkt` | Two-layer architecture: `global-env-add` (self-updating), `global-env-remove!`, `global-env-lookup-type` (dep recording), `global-env-snapshot` (layer merge), `record-cross-module-dep!` |
| `racket/prologos/namespace.rkt` | `module-network-ref` struct + 7 operations, `module-info` (9th field), lifecycle constants re-export |
| `racket/prologos/infra-cell.rkt` | `mod-status-merge` lifecycle lattice, `net-new-mod-status-cell` factory |
| `racket/prologos/driver.rkt` | Module loading: network construction, dep-edge population, `remove-failed-definition!`; Phase 5 env-threading cleanup |
| `racket/prologos/tests/test-module-network-01.rkt` | 24 unit tests (lifecycle, CRUD, shadow-cell, dep-edges) |
| `racket/prologos/tests/test-support.rkt` | Parameter initialization for `current-cross-module-deps` |
| `racket/prologos/tools/batch-worker.rkt` | Parameter initialization for `current-cross-module-deps` |
| `examples/2026-03-16-track5-acceptance.prologos` | L3 acceptance file (13 sections, 294 expressions) |
| `docs/tracking/2026-03-16_TRACK5_GLOBAL_ENV_DEPENDENCY_EDGES.md` | Design doc + progress tracker |

---

## 13. Cross-References

### Recurring patterns across PIRs

- **Mechanical pattern transfer** (Track 3 PIR §6.1, Track 4 PIR §6.3): The first phase in a subsystem is where design decisions happen; subsequent phases are mechanical. Track 5 continues this: Phase 1 (infrastructure) and Phase 3 (activation) were creative; Phases 2, 4, 5 were mechanical. Five consecutive tracks confirm this as a planning heuristic.

- **Belt-and-suspenders with explicit retirement** (Tracks 1–4): Track 5 adds a refinement: define retirement criteria upfront ("0 mismatches across ≥2 phases"). This makes removal principled rather than arbitrary. Prior tracks used belt-and-suspenders but didn't always specify when the safety net should come off.

- **Struct field cascade** (Track 4 PIR §"What Surprised Us" #2): Track 4 noted that adding `speculation-pruned-count` to `provenance-counters` required 3 site updates. Track 5's `module-info` field addition required 20 site updates. The Pipeline Exhaustiveness checklist covers AST nodes; it should be extended to cover widely-constructed infrastructure structs.

- **Performance stays within bounds** (all tracks): Track 1: +3%, Track 3: +1.7%, Track 4: −2.4%, Track 5: +14%. All within the 25% threshold. The cumulative trend from Track 1 baseline (~194s) to Track 5 final (213.3s) is +10% over 5 tracks — acceptable for infrastructure that enables LSP features.

### New pattern: test infrastructure divergence

Track 5 is the first PIR to surface a *test* infrastructure assumption as a bug source (§4.1). `run-ns-last` creates a subtly different environment from production (`process-file`/`process-string`). This divergence was harmless for Tracks 1–4 (read-path migrations don't care about write infrastructure) but became a bug in Track 5 (write-path consolidation depends on write infrastructure being present). Future infrastructure tracks that modify write paths should audit `run-ns-last` separately from the production path.

### Prior PIRs referenced

- Track 4 PIR (`2026-03-16_TRACK4_ATMS_SPECULATION_PIR.md`) — direct predecessor; Track 5 builds on Track 4's TMS-ready infrastructure
- Track 3 PIR (`2026-03-16_TRACK3_CELL_PRIMARY_REGISTRIES_PIR.md`) — mechanical pattern transfer; Track 5 extends cell-primary to global-env
- Track 1 PIR (`2026-03-12_TRACK1_CELL_PRIMARY_PIR.md`) — established the cell-primary pattern that Track 5 completes for global-env
- WFLE PIR (`2026-03-14_WFLE_PIR.md`) — calibration for design-to-implementation ratio (6:1 for WFLE vs 1:1 for Track 5, reflecting different risk profiles)
