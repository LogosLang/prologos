# BSP-LE Track 0: Propagator Allocation Efficiency — Stage 3 Design

**Date**: 2026-03-21
**Status**: Draft (D.1 — awaiting critique)
**Parent**: BSP-LE Series ([Master Roadmap](2026-03-21_BSP_LE_MASTER.md))
**Audit**: [Cell & Propagator Allocation Audit](2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md) (commit `f7bd03d`)
**Prerequisite**: None — unblocked, first in implementation order
**Principle**: Every subsequent Track (PM Track 8, CIU, BSP-LE Tracks 1-5) creates cells and propagators at scale. Fixing allocation efficiency first means all later benchmarks are representative.

---

## Progress Tracker

| # | Phase | Description | Status | Commit | Notes |
|---|-------|-------------|--------|--------|-------|
| 0 | Acceptance + baselines | Micro-benchmarks + A/B baselines | ⬜ | | Establish pre-optimization numbers |
| 1 | eq?-first fast path | `net-cell-write` fixpoint check | ⬜ | | Quick win, no architectural change |
| 2 | Merge identity audit | All merge functions return identical input on no-change | ⬜ | | Enables eq?-only fixpoint check |
| 3 | Mutable worklist/fuel | Box-based worklist inside quiescence loop | ⬜ | | Highest per-iteration win |
| 4 | Field-group struct split | prop-network → hot/warm/cold inner structs | ⬜ | | Largest total impact, biggest change surface |
| 5 | Batch cell registration | Transient CHAMP for multi-cell setup | ⬜ | | Eliminates dead intermediate networks |
| 6 | Propagator input batching | Transient CHAMP for multi-input registration | ⬜ | | Follow-on to Phase 5 pattern |
| 7 | Verification + A/B | Full suite + comparative benchmarks | ⬜ | | Quantify total improvement |

---

## 1. Problem Statement

The propagator network is an immutable persistent data structure. Every mutation returns a new network. The dominant cost is `struct-copy prop-network` — a 13-field struct copied on every cell write, propagator addition, and worklist iteration.

For a representative command (15 metas, 15 propagators, 50 worklist iterations, 30 cell changes):
- ~125 copies of a 13-field struct (~14 KB)
- ~215 dead intermediate CHAMP tries
- Thousands of deep `equal?` comparisons for fixpoint detection

This is not catastrophic per command, but multiplied by hundreds of commands in a module load, it becomes the dominant allocation source. And every subsequent Track (PM Track 8, CIU, BSP-LE) will add more cells and propagators — the allocation profile gets worse, not better.

### What We Want

After this Track:
- Worklist loop does **zero struct allocation** per iteration
- Cell writes allocate only the cell struct + CHAMP update (not the full network)
- Batch operations (multi-cell registration) use transient CHAMPs
- Fixpoint detection uses `eq?` (pointer equality), not `equal?` (structural)
- All optimizations preserve the pure data-in/data-out contract

---

## 2. Design: Seven Phases, Increasing Architectural Impact

The phases are ordered by the audit's priority ranking, with adjustments for dependency: Phase 1-2 (eq? fast path + merge audit) are prerequisites that enable Phase 3-4 to be maximally effective.

### Phase 0: Acceptance File + Baselines

**Goal**: Establish quantitative baselines before any optimization.

**Deliverables**:
1. **Micro-benchmarks** (new file `benchmarks/micro/bench-alloc.rkt`):
   - `net-new-cell`: 100 sequential cell additions on a fresh network
   - `net-cell-write`: 100 writes to existing cells (mix of change/no-change)
   - `net-add-propagator`: 50 propagator additions with 2 inputs each
   - `run-to-quiescence`: synthetic network of 100 cells, 50 propagators, run to fixpoint
   - Each benchmark: warmup + 30 samples with GC between, reporting mean/median/stddev/CV

2. **A/B baseline**: `bench-ab.rkt benchmarks/comparative/ --runs 15` — capture current wall-time distributions for the 10 comparative programs + solver adversarial.

3. **Per-command verbose**: Run a representative module with `process-file #:verbose #t` and capture `cell_allocs` and `prop_firings` per command as a profile.

4. **Acceptance file**: Not a `.prologos` file — this Track is infrastructure-only. Instead, the acceptance criterion is: **full test suite passes with identical results, and A/B benchmarks show measurable improvement**.

### Phase 1: eq?-First Fast Path in Cell Write

**Goal**: Replace `(equal? merged old-val)` with `(or (eq? merged old-val) (equal? merged old-val))` in `net-cell-write`.

**File**: `propagator.rkt` line ~359

**Change**: Single line. The `eq?` check is O(1) and catches the ~80% case where the merge function returns the identical input value (pointer equality). Only when `eq?` fails does it fall back to structural `equal?`.

**Measurement**: Phase 0 micro-benchmarks re-run. The `net-cell-write` benchmark should show improvement proportional to the fraction of no-change writes (expected ~80% of all writes during quiescence are no-ops).

**Risk**: None — `eq?` is strictly stronger than `equal?`. If `eq?` returns true, `equal?` would too.

### Phase 2: Merge Identity Audit

**Goal**: Verify (and fix) that all merge functions return the *identical* input value (same Racket object, not just structurally equal) when the input wins the merge.

**Scope**: All merge functions registered in the system:
- `type-lattice-merge` (type-lattice.rkt)
- `mult-lattice-merge` (mult-lattice.rkt)
- `session-lattice-merge` (session-lattice.rkt)
- `merge-hasheq-union` (infra-cell.rkt)
- `merge-hasheq-list-append` (infra-cell.rkt)
- `merge-list-append` (infra-cell.rkt)
- Any merge functions created by PUnify (ctor-registry descriptors)

**Pattern**: For each merge function `f(old, new)`:
```
if result is semantically equal to old → return old (not a fresh copy)
if result is semantically equal to new → return new (or old, depending on convention)
only if genuinely new → return fresh value
```

**Why this matters**: If merge functions consistently return identical objects on no-change, Phase 1's `eq?` check catches ALL no-change cases, and `equal?` becomes dead code on the hot path. This compounds with Phase 3-4: fewer false-positive "changes" means fewer struct-copies.

**Deliverable**: Per-merge-function test cases verifying identity preservation. Any merge function that creates fresh values on no-change is fixed.

### Phase 3: Mutable Worklist/Fuel in Quiescence Loop

**Goal**: Replace per-iteration `struct-copy prop-network` in `run-to-quiescence-inner` with mutable boxes for worklist and fuel.

**File**: `propagator.rkt` lines ~835-852

**Design**:
```racket
(define (run-to-quiescence-inner net)
  (define wl (box (prop-network-worklist net)))
  (define remaining-fuel (box (prop-network-fuel net)))
  (let loop ([net (struct-copy prop-network net [worklist '()] [fuel 0])])
    ;; net now has empty worklist/zero fuel — worklist/fuel live in boxes
    (cond
      [(prop-network-contradiction net) (finalize net wl remaining-fuel)]
      [(<= (unbox remaining-fuel) 0) (finalize net wl remaining-fuel)]
      [(null? (unbox wl)) (finalize net wl remaining-fuel)]
      [else
       (define pid (car (unbox wl)))
       (set-box! wl (cdr (unbox wl)))
       (set-box! remaining-fuel (sub1 (unbox remaining-fuel)))
       (define prop (champ-lookup (prop-network-propagators net) pid))
       (if (eq? prop 'none)
           (loop net)
           (let ([net* ((propagator-fire-fn prop) net)])
             ;; propagator may have added to worklist via net-cell-write
             ;; those additions went into the struct's worklist field
             ;; drain them into our mutable box
             (set-box! wl (append (prop-network-worklist net*) (unbox wl)))
             (loop (struct-copy prop-network net* [worklist '()]))))])))

(define (finalize net wl fuel)
  (struct-copy prop-network net
    [worklist (unbox wl)]
    [fuel (unbox fuel)]))
```

**Key subtlety**: Propagator fire functions call `net-cell-write`, which appends dependents to the network's worklist field. After each fire, we drain the struct's worklist into our mutable box and clear the struct's worklist. This way, fire functions don't need to know about the mutable box — they write to the struct as normal.

**Pre-requisite audit**: Verify no propagator fire function reads `prop-network-worklist` or `prop-network-fuel`. Search for all call sites of these accessors. Expected: only `run-to-quiescence-inner` and `run-to-quiescence-bsp` read them.

**Measurement**: Eliminates ~50 struct-copies per command (one per worklist iteration). Re-run Phase 0 micro-benchmarks.

**Risk**: Moderate. The drain-and-clear pattern must correctly handle propagators that add new work during their firing. Test with adversarial networks that create cascading worklist additions.

### Phase 4: Field-Group Struct Split

**Goal**: Split `prop-network` from a flat 13-field struct into nested hot/warm/cold groups.

**Design**:
```racket
(struct prop-net-hot (worklist fuel) #:transparent)

(struct prop-net-warm (cells contradiction) #:transparent)

(struct prop-net-cold (merge-fns contradiction-fns widen-fns
                       propagators next-cell-id next-prop-id
                       cell-decomps pair-decomps cell-dirs)
  #:transparent)

(struct prop-network (hot warm cold) #:transparent)
```

**Mutation profiles**:
- **Hot** (every worklist iteration): `worklist`, `fuel` → 2-field copy
- **Warm** (every cell write with change): `cells`, `contradiction` → 2-field copy
- **Cold** (only at allocation time): 9 fields → shared by pointer during iteration

**Impact**: After Phase 3 (mutable worklist), the hot group is no longer copied per-iteration. The warm group drops from 13-field to 2-field per cell-write. Cold fields are never copied during the quiescence loop.

**Sub-phases**:
- **4a**: Define new inner structs. Create accessor compatibility layer (macros or wrapper functions that access `(prop-net-warm-cells (prop-network-warm net))` via `(prop-network-cells net)`).
- **4b**: Update `net-cell-write` — only copies warm group.
- **4c**: Update `net-new-cell` and `net-add-propagator` — copies cold group (allocation-time operations).
- **4d**: Update all remaining `struct-copy prop-network` sites (25 total in propagator.rkt) to copy only the relevant group.
- **4e**: Remove compatibility layer if all sites are migrated.

**Risk**: Largest change surface (25 struct-copy sites + all field accessors). Mechanical but tedious. Compatibility wrappers (4a) allow incremental migration with the test suite passing at each sub-phase.

**Measurement**: Field-copy savings. Re-run Phase 0 micro-benchmarks. Expected: ~2600 fewer field copies per command (audit §10 estimate).

### Phase 5: Batch Cell Registration

**Goal**: Use transient CHAMP for multi-cell setup in `register-global-env-cells!` and similar batch operations.

**File**: `global-env.rkt` lines ~345-360, `elaborator-network.rkt` (initial network setup)

**Design**:
```racket
(define (batch-register-cells net cell-specs)
  ;; cell-specs: (listof (list name initial-val merge-fn contradicts?))
  (define tcells (champ-transient (prop-network-cells (prop-network-warm net))))
  (define tmerge (champ-transient (prop-net-cold-merge-fns (prop-network-cold net))))
  (define tcontra (champ-transient ...))
  (for ([spec (in-list cell-specs)])
    (match-define (list name init merge contra?) spec)
    (define cid (next-cell-id ...))
    (tchamp-insert! tcells cid (prop-cell init '()))
    (tchamp-insert! tmerge cid merge)
    (when contra? (tchamp-insert! tcontra cid contra?)))
  ;; Single freeze + single struct construction
  (define new-warm (struct-copy prop-net-warm ...
    [cells (tchamp-freeze tcells)]))
  (define new-cold (struct-copy prop-net-cold ...
    [merge-fns (tchamp-freeze tmerge)] ...))
  (struct-copy prop-network net [warm new-warm] [cold new-cold]))
```

**Savings**: For 50 definition cells, saves ~49 intermediate prop-network copies + ~100 dead CHAMP tries. One-time per command start.

**Risk**: Low. The transient CHAMP infrastructure is already implemented and tested (champ.rkt:497-544). The batch pattern is a straightforward application.

### Phase 6: Propagator Input Batching

**Goal**: Use transient CHAMP for multi-input propagator registration in `net-add-propagator`.

**File**: `propagator.rkt` line ~696

**Design**: Same pattern as Phase 5 — convert cells CHAMP to transient, register all input dependencies, freeze once.

**Savings**: For propagators with N inputs, saves N-1 intermediate CHAMP tries. Small per-propagator win but accumulates across 15+ propagators per command.

**Risk**: Low. Follow-on to Phase 5 pattern.

### Phase 7: Verification + A/B Comparison

**Deliverables**:
1. Full test suite (7308+ tests, all pass)
2. A/B benchmark comparison vs Phase 0 baselines:
   - `bench-ab.rkt benchmarks/comparative/ --runs 15` — wall-time improvement
   - `bench-micro.rkt benchmarks/micro/bench-alloc.rkt` — per-operation improvement
   - Solver adversarial benchmark — should not regress
3. Per-command verbose comparison: `cell_allocs` and `prop_firings` unchanged (semantics preserved), wall-time reduced
4. Suite time target: measurable improvement from current ~200s baseline

---

## 3. Design Decisions

| # | Decision | Resolution | Rationale |
|---|----------|------------|-----------|
| D1 | Optimization ordering | eq? fast path → merge audit → mutable worklist → struct split → batch registration | Dependencies: merge audit enables eq?-only; struct split compounds with mutable worklist |
| D2 | Worklist/fuel mutability | Mutable boxes inside pure loop, finalize at exit | Preserves pure data-in/data-out contract; invisible to callers |
| D3 | Struct split granularity | Three groups: hot (2), warm (2), cold (9) | Matches mutation frequency analysis from audit §9.2 |
| D4 | Compatibility layer for struct split | Wrapper accessors during migration, removed after | Enables incremental migration with passing tests at each step |
| D5 | Batch registration API | `batch-register-cells` taking a list of specs | Clean API; existing transient CHAMP infrastructure |
| D6 | GC / dead propagator cleanup | Deferred (audit §12 recommendation) | Allocation efficiency first; provenance value needs analysis |
| D7 | BSP quiescence loop | Not modified in this Track | Same optimizations apply; BSP loop benefits from struct split |

---

## 4. Test Strategy

| Phase | Micro-benchmark | A/B Comparison | Suite |
|-------|-----------------|----------------|-------|
| 0 | Establish baselines | Establish baselines | Pass (baseline) |
| 1 | `net-cell-write` improvement | — | Pass (no behavioral change) |
| 2 | Merge identity tests | — | Pass (no behavioral change) |
| 3 | `run-to-quiescence` improvement | A/B vs Phase 0 | Pass |
| 4 | All benchmarks improvement | A/B vs Phase 3 | Pass at each sub-phase |
| 5 | `batch-register-cells` benchmark | — | Pass |
| 6 | `net-add-propagator` improvement | — | Pass |
| 7 | All benchmarks final | A/B vs Phase 0 (total improvement) | Pass |

**Performance regression detection**: After each phase, the test suite must pass and no A/B benchmark may regress beyond noise (p < 0.05 on Mann-Whitney U test).

---

## 5. Key Files

| File | Phases | Changes |
|------|--------|---------|
| `propagator.rkt` | 1, 3, 4, 6 | eq? fast path, mutable worklist, struct split, input batching |
| `champ.rkt` | — | No changes (transient infrastructure already exists) |
| `elaborator-network.rkt` | 4, 5 | Struct accessor updates, batch registration API |
| `global-env.rkt` | 5 | `register-global-env-cells!` uses batch API |
| `type-lattice.rkt` | 2 | Merge identity verification/fix |
| `mult-lattice.rkt` | 2 | Merge identity verification/fix |
| `session-lattice.rkt` | 2 | Merge identity verification/fix |
| `infra-cell.rkt` | 2 | Merge identity verification/fix |
| New: `benchmarks/micro/bench-alloc.rkt` | 0 | Allocation micro-benchmarks |

---

## 6. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Phase 3 worklist drain misses propagator-added entries | Low | High | Adversarial test: cascading worklist additions |
| Phase 4 struct split breaks pattern-matches across codebase | Medium | Medium | Compatibility wrappers; incremental migration; tests at each sub-phase |
| Optimizations interact negatively (e.g., struct split + mutable worklist) | Low | Medium | Phase 3 before Phase 4; measure independently and combined |
| Merge identity audit finds many non-identity-preserving functions | Medium | Low | Fix each; mostly mechanical |
| Transient CHAMP freeze cost dominates batch savings for small N | Low | Low | Measure; only apply batch pattern where N > ~10 |

---

## 7. Expected Impact (from Audit §10)

| Optimization | Struct-copies saved/cmd | CHAMP allocs saved/cmd | Notes |
|---|---|---|---|
| Phase 1-2: eq?-first + merge identity | 0 (fewer false changes → fewer downstream copies) | 0 | Enables phases 3-4 |
| Phase 3: Mutable worklist/fuel | ~50 | 0 | Per-iteration elimination |
| Phase 4: Field-group splitting | ~2600 field-copy savings | 0 | Copy width reduction |
| Phase 5: Batch registration (50 cells) | ~98 | ~200 | One-time per command |
| Phase 6: Input batching | 0 | ~15 | Small per-propagator win |
| **Combined** | **~148 struct-copies + 2600 field-copy savings** | **~215** | + equal? elimination |

Phases 3+4 compound: if both applied, the worklist loop does **zero struct allocation** per iteration (Phase 3 eliminates hot copies, Phase 4 means cell-writes only copy the 2-field warm group).
