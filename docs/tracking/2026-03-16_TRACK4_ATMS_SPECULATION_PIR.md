# Track 4: ATMS Speculation — Post-Implementation Review

**Date**: 2026-03-16
**Duration**: ~2 hours (single session, continued from design work)
**Commits**: 7 (from `10ecb0c` through `efbc70b`)
**Test delta**: +28 new tests (7096 → 7124, TMS cell unit tests)
**Code delta**: ~600 lines added across 5 `.rkt` files
**Suite health**: 7124 tests, 371 files, 187.1s — all pass, no regressions (2.4% faster than baseline)
**Design doc**: `docs/tracking/2026-03-16_TRACK4_ATMS_SPECULATION.md`
**Prior PIR**: Track 3 PIR (`2026-03-16_TRACK3_CELL_PRIMARY_REGISTRIES_PIR.md`)

---

## 1. What Was Built

Track 4 integrated TMS (Truth Maintenance System) cells into the propagator network for speculation-aware type inference. All four meta types (type, level, multiplicity, session) now have per-meta TMS cells that support assumption-tagged branching. Additionally, learned-clause integration prunes speculation branches known to be inconsistent from prior failures.

### Key deliverables

1. **TMS cell infrastructure** (Phase 1): `tms-cell-value` struct with recursive CHAMP tree, `tms-read`/`tms-write`/`tms-commit`/`merge-tms-cell`, `make-tms-merge` domain-aware merge factory, `net-new-tms-cell` factory
2. **TMS-transparent read/write** (Phase 2): `net-cell-read` auto-unwraps TMS values, `net-cell-write` auto-wraps; `elab-fresh-meta` creates TMS cells with `type-lattice-merge`
3. **Per-meta TMS cells for all meta types** (Phase 3): Level, mult, session metas now have per-meta TMS cells; `save-meta-state` reduced from 6 boxes to 3
4. **Learned-clause pruning** (Phase 5): Before executing a speculation branch, `atms-consistent?` check prunes branches subsumed by known nogoods

### What did NOT change

- Speculation stack push (deferred to Phase 6 cleanup — belt-and-suspenders network restore handles rollback)
- Meta-info CHAMP → write-once registry (Phase 4 deferred — 3-box save/restore works correctly)
- No user-facing behavior changes — same error messages, same type checking results

---

## 2. Timeline and Phases

| Phase | Commit | Description |
|-------|--------|-------------|
| 0 | `50b00d8` | Acceptance file + performance baseline (191.6s / 7096 tests) |
| 1 | `ecde661` | TMS cell infrastructure + 28 unit tests (197.0s / 7123 tests) |
| 2 | `10ecb0c` | TMS-transparent read/write + domain-aware merge (196.1s / 7124 tests) |
| 3 | `addaf46` | Level/mult/session → per-meta TMS cells, save/restore 6→3 boxes (188.2s) |
| 4 | — | Deferred to Phase 6 (meta-info CHAMP simplification) |
| 5 | `f0f72da` | Learned-clause pruning via atms-consistent? (187.1s) |
| 6 | — | Validated: 187.1s vs 191.6s baseline, acceptance L3 0 errors |
| 7 | this doc | PIR |

---

## 3. Test Coverage

28 new unit tests in `test-tms-cell.rkt` covering:
- TMS cell struct basics (base, branches, hasheq)
- `tms-read` at depths 0, 1, 2, 3 (tree traversal, fallback to base)
- `tms-write` (nested CHAMP insert, overwrite)
- `tms-commit` (base promotion)
- `merge-tms-cell` (recursive tree merge)
- `net-new-tms-cell` factory (with TMS merge)
- TMS-transparent network read/write via `net-cell-read`/`net-cell-write`
- Speculative write workflow simulation

The existing 7096 tests provide coverage for the TMS-transparent integration — every test that exercises type inference now runs through TMS cells at depth 0 (base fast path).

---

## 4. Architecture Decisions

### 4.1 Depth-0 fast path

At speculation depth 0 (the common case for all 7096+ existing tests), `tms-read` returns `base` directly via a single `null?` check on the speculation stack. This makes TMS cells zero-overhead for the common case.

### 4.2 Belt-and-suspenders rollback

During Phases 2-5, both network-box restore AND TMS cells coexist. The network snapshot handles rollback; TMS cells are passive (depth 0, no branching). This was essential — attempting to push the speculation stack in Phase 2c caused "already solved" errors because cell writes went to TMS branches but `solve-meta-core!` unconditionally marked meta-info as 'solved in the CHAMP.

### 4.3 Domain-aware TMS merge

`make-tms-merge` takes a domain merge function (e.g., `type-lattice-merge`) and produces a TMS merge that applies it at the base/leaf level. This was critical for contradiction detection — the naive `merge-tms-cell` doesn't understand domain semantics.

### 4.4 save/restore reduction

Reducing save/restore from 6 boxes to 3 (network + id-map + meta-info) by moving level/mult/session meta state into per-meta TMS cells within the network. The network snapshot now captures 4 meta types' worth of state.

### 4.5 Phase 4 deferral

Meta-info CHAMP → write-once registry was deferred because:
- Removing meta-info from save/restore requires handling stale entries in `all-unsolved-metas`
- Removing id-map from save/restore risks stale entries pointing to non-existent cells after restore
- The 3-box save/restore works correctly and is already a significant improvement

---

## 5. Lessons Learned

1. **Speculation stack push requires commit-on-success**: Writing to TMS branches during speculation is correct for the FAILURE path (retraction makes writes invisible). But on SUCCESS, the thunk's mutations must be visible at depth 0. Without `tms-commit` machinery, depth-0 reads see stale base values. Solution: defer stack push to when commit-on-success is implemented.

2. **Domain-aware merge is non-negotiable for TMS cells**: The generic `merge-tms-cell` (take newer base) doesn't trigger contradiction detection. `make-tms-merge(type-lattice-merge)` applies the domain merge at base level, enabling `contradicts?` checks. This was a real bug caught by `test-elaborator-network.rkt`.

3. **Performance improved slightly**: 191.6s → 187.1s (2.4% faster). The per-meta TMS cells don't add overhead because of the depth-0 fast path, and reducing save/restore from 6 boxes to 3 saves copy operations.

---

## 6. Deferred Work

- **Phase 4**: Meta-info CHAMP → write-once registry; save/restore → 1 box
- **Speculation stack push**: Route cell writes to TMS branches during speculation
- **Commit-on-success**: Promote TMS branch values to base on speculation success
- **TMS retraction**: Replace network-box restore with per-cell assumption retraction

These are blocked on each other: stack push requires commit-on-success, which requires TMS retraction to replace network restore.

---

## 7. Metrics

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
