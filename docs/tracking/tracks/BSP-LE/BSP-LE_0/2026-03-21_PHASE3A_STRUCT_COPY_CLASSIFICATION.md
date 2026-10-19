# Phase 3a: Struct-Copy Site Classification

**Date**: 2026-03-21
**Scope**: All 25 `struct-copy prop-network` sites in `propagator.rkt`
**Purpose**: Design deliverable for BSP-LE Track 0 Phase 3 — classify each site by which field group (hot/warm/cold) it touches, before any code changes.

## Field Groups

| Group | Fields | Mutation Frequency |
|-------|--------|--------------------|
| **Hot** | `worklist`, `fuel` | Every worklist iteration |
| **Warm** | `cells`, `contradiction` | Every cell write with change |
| **Cold** | `merge-fns`, `contradiction-fns`, `widen-fns`, `propagators`, `next-cell-id`, `next-prop-id`, `cell-decomps`, `pair-decomps`, `cell-dirs` | Allocation/setup time only |

## Classification

| # | Line | Function | Fields Modified | Group(s) | Notes |
|---|------|----------|----------------|----------|-------|
| 1 | 265 | `net-new-cell` | cells, merge-fns, next-cell-id | **warm+cold** | Cell allocation |
| 2 | 271 | `net-new-cell` (contradicts?) | contradiction-fns | **cold** | Optional contradiction fn |
| 3 | 289 | `net-new-cell-desc` | cells, merge-fns, cell-dirs | **warm+cold** | Descending cell allocation |
| 4 | 296 | `net-new-cell-desc` (contradicts?) | contradiction-fns | **cold** | Optional contradiction fn |
| 5 | 371 | `net-cell-write` | cells, worklist | **warm+hot** | Cell mutation (change path) |
| 6 | 375 | `net-cell-write` (contradicted) | contradiction | **warm** | Contradiction flagging |
| 7 | 403 | `net-cell-replace` | cells, worklist | **warm+hot** | S(−1) retraction write |
| 8 | 407 | `net-cell-replace` (contradicted) | contradiction | **warm** | Contradiction flagging |
| 9 | 547 | `net-commit-assumption` | cells | **warm** | TMS commit |
| 10 | 582 | `net-retract-assumption` | cells | **warm** | TMS retraction |
| 11 | 708 | `net-add-propagator` | cells, propagators, next-prop-id, worklist | **warm+cold+hot** | Propagator registration (touches all 3) |
| 12 | 843 | `run-to-quiescence-inner` | worklist, fuel | **hot** | Worklist pop + fuel decrement |
| 13 | 864 | `run-to-quiescence-inner/traced` | worklist, fuel | **hot** | Same as #12, traced variant |
| 14 | 971 | `run-to-quiescence-bsp` | worklist, fuel | **hot** | BSP round snapshot |
| 15 | 1057 | `net-set-widen-point` | widen-fns | **cold** | Widening setup |
| 16 | 1110 | `net-cell-write-widen` | cells, worklist | **warm+hot** | Widening cell write (change path) |
| 17 | 1114 | `net-cell-write-widen` (contradicted) | contradiction | **warm** | Contradiction flagging |
| 18 | 1128 | `run-to-quiescence-widen/inner` | worklist, fuel | **hot** | Widening worklist pop |
| 19 | 1164 | `run-narrow-phase` (setup) | merge-fns | **cold** | Narrowing merge fn swap |
| 20 | 1178 | `run-narrow-phase` (inner loop) | worklist, fuel | **hot** | Narrowing worklist pop |
| 21 | 1233 | `run-narrow-phase` (cell write) | cells, worklist | **warm+hot** | Narrowing cell write |
| 22 | 1237 | `run-narrow-phase` (contradicted) | contradiction | **warm** | Narrowing contradiction |
| 23 | 1273 | `run-to-quiescence-widen` | worklist | **hot** | Seed worklist for narrowing |
| 24 | 1314 | `net-cell-decomp-insert` | cell-decomps | **cold** | Decomposition registry |
| 25 | 1327 | `net-pair-decomp-insert` | pair-decomps | **cold** | Pair decomposition registry |

## Summary by Group

| Group | Count | Sites |
|-------|-------|-------|
| **Hot only** | 6 | #12, #13, #14, #18, #20, #23 |
| **Warm only** | 4 | #6, #8, #9, #10 |
| **Cold only** | 5 | #2, #4, #15, #19, #24, #25 |
| **Warm+Hot** | 4 | #5, #7, #16, #21 |
| **Warm+Cold** | 2 | #1, #3 |
| **All three** | 1 | #11 |
| **Total** | **25** (note: cold-only is 6, not 5) | |

## Implications for Phase 3b-3f

### Hot-only sites (#12, #13, #14, #18, #20, #23)
These are the worklist iteration sites — the primary target for the mutable worklist optimization (Phase 3c). With the struct split, they copy only the 2-field hot struct. With mutable boxes, most of these become zero-allocation.

### Warm-only sites (#6, #8, #9, #10)
After the split, these copy only the 2-field warm struct. These are contradiction flagging and TMS operations — relatively infrequent.

### Warm+Hot sites (#5, #7, #16, #21)
`net-cell-write` and equivalents. These are the hot-path cell mutations. After the split, they need to update both warm (cells) and hot (worklist). Two 2-field struct-copies instead of one 13-field copy. With the mutable worklist, they only copy warm (the worklist goes into the box).

### Cold-only sites (#2, #4, #15, #19, #24, #25)
Allocation and setup operations. Cold struct is copied rarely — once per cell/propagator creation, not per iteration. The 9-field cold struct-copy is acceptable at these frequencies.

### Warm+Cold sites (#1, #3)
`net-new-cell` and `net-new-cell-desc`. These are cell allocation — they update cells (warm) and merge-fns + next-cell-id (cold). Two struct-copies (warm + cold) instead of one 13-field.

### All three (#11)
`net-add-propagator` is the most complex — it updates cells (warm for dependency registration), propagators + next-prop-id (cold), and worklist (hot for initial scheduling). This needs all three groups copied. With the mutable worklist, it drops to warm + cold.

## Phase 3c Worklist Audit

The pre-requisite audit for mutable worklist: which sites read `worklist` or `fuel`?

| Accessor | Sites | Context |
|----------|-------|---------|
| `prop-network-worklist` | #5, #7, #11, #12, #13, #14, #16, #18, #20, #21, #23 | All write to worklist (append deps or cons pid) |
| `prop-network-fuel` | #12, #13, #14, #18, #20 | All decrement fuel in worklist loops |

**No propagator fire function reads worklist or fuel.** Fire functions receive `net` and call `net-cell-write`/`net-cell-read`/`net-add-propagator` — all of which access cells, merge-fns, propagators, but not worklist or fuel directly. ✅ The mutable worklist approach is safe.
