# BSP-LE Track 0: Propagator Allocation Efficiency — Stage 3 Design

**Date**: 2026-03-21
**Status**: Draft (D.3 — self-critique + principles alignment)
**Parent**: BSP-LE Series ([Master Roadmap](2026-03-21_BSP_LE_MASTER.md))
**Audit**: [Cell & Propagator Allocation Audit](2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md) (commit `f7bd03d`)
**Prerequisite**: None — unblocked, first in implementation order
**Principle**: Every subsequent Track (PM Track 8, CIU, BSP-LE Tracks 1-5) creates cells and propagators at scale. Fixing allocation efficiency first means all later benchmarks are representative.

---

## Progress Tracker

| # | Phase | Description | Status | Commit | Notes |
|---|-------|-------------|--------|--------|-------|
| 0 | Acceptance + baselines | Micro-benchmarks + A/B + memory baselines | ✅ | `8c4da4a` | cell-alloc 0.42μs, cell-write 0.27/0.09μs, struct-copy 0.03μs |
| 1 | eq?-first fast path | `net-cell-write` fixpoint check | ✅ | `19274b5` | Both net-cell-write and net-cell-write-widen. 7308 tests pass 232s |
| 2 | Merge identity audit | All merge functions return identical input on no-change | ✅ | `7e8875b` | 13/17 non-preserving; 6 fixed in infra-cell.rkt; 4 already OK; 7 structural (unfixable) |
| 3 | Struct split + mutable worklist | Combined: hot/warm/cold split + box-based worklist | 🔄 | | Landed together — drain pattern requires 2-field hot struct |
| 3a | Struct-copy site classification | Classify 25 sites by hot/warm/cold group | ✅ | `a5de346` | 6 hot, 4 warm, 6 cold, 4 w+h, 2 w+c, 1 all. Fire fns safe. |
| 3b | Inner struct definitions + accessor macros | Define hot/warm/cold structs + zero-cost macro wrappers | ✅ | `bfe8e4f` | hot(2)/warm(2)/cold(9). 29 sites in propagator.rkt + 4 external files. 7308 tests 240.5s |
| 3c | Mutable worklist/fuel + hot struct | Box-based worklist, drain-and-clear on 2-field hot | ✅ | `7a94274` | Drain pattern + eq? identity. Serial + traced. 7308 tests 238.2s |
| 3d | Warm-group cell write | `net-cell-write` copies only warm group | ✅ | `bfe8e4f` | Already achieved by Phase 3b migration — warm+hot only, cold shared |
| 3e | Cold-group allocation ops | `net-new-cell`/`net-add-propagator` copy cold group | ✅ | `bfe8e4f` | Already achieved by Phase 3b migration — warm+cold only, hot untouched |
| 3f | Accessor macros → stable API | Retain macros as public API; remove "compatibility" framing | ✅ | | Macros decouple 18 consumer files from inner struct layout — keeping them IS the right design |
| 4 | Batch cell registration | Transient CHAMP + next-cell-id range pre-allocation | ⬜ | | Eliminates dead intermediate networks |
| 5 | Propagator input batching | Transient CHAMP for multi-input registration | ⬜ | | Follow-on to Phase 4 pattern |
| 6 | Verification + A/B | Full suite + comparative benchmarks + memory | ⬜ | | Target: ≤180s suite (10-20% improvement) |

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

2. **Change/no-change ratio**: Instrument `net-cell-write` to count how many calls result in actual changes vs. no-ops (the `equal? merged old-val` path). This validates the "~80% no-change" claim from the audit — if the actual ratio is lower, Phase 2's case for making merge functions identity-preserving is stronger.

3. **A/B baseline**: `bench-ab.rkt benchmarks/comparative/ --runs 15` — capture current wall-time distributions for the 10 comparative programs + solver adversarial.

4. **Per-command verbose**: Run two representative workloads with `process-file #:verbose #t`:
   - **Prelude load** (heavy definition registration, many cells, moderate propagation): a `.prologos` file that imports the full prelude + several library modules.
   - **Solver adversarial** (`benchmarks/comparative/constraints-adversarial.prologos`): many small commands, heavy propagation per command, stress-tests the quiescence loop.

   Capture `cell_allocs` and `prop_firings` per command as profiles for both workloads.

5. **Memory baseline**: `(collect-garbage 'major)` + `(current-memory-use)` before and after processing each representative workload. Establishes retained-memory baseline — the persistent CHAMP structure means old intermediate networks may be retained by closures or parameters.

5. **Acceptance file**: Not a `.prologos` file — this Track is infrastructure-only. Instead, the acceptance criterion is: **full test suite passes with identical results, and A/B benchmarks show measurable improvement**.

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
- PUnify ctor-registry merge functions: `make-ctor-merge` in `ctor-registry.rkt` generates merge functions from descriptor specs. Audit the *generator*, not each generated instance — verify that `make-ctor-merge` produces functions that return the identical input on no-change.

**Pattern**: For each merge function `f(old, new)`:
```
if result is semantically equal to old → return old (not a fresh copy)
if result is semantically equal to new → return new (or old, depending on convention)
only if genuinely new → return fresh value
```

**Why this matters**: If merge functions consistently return identical objects on no-change, Phase 1's `eq?` check catches ALL no-change cases, and `equal?` becomes dead code on the hot path. This compounds with Phase 3-4: fewer false-positive "changes" means fewer struct-copies.

**Deliverable**: Per-merge-function test cases verifying identity preservation. Any merge function that creates fresh values on no-change is fixed.

### Phase 3: Combined Struct Split + Mutable Worklist

**Why combined**: The mutable worklist pattern requires a drain-and-clear after each propagator fire — clearing the struct's worklist field via `struct-copy`. On the flat 13-field struct, this drain-and-clear is a 13-field copy per fire, which defeats the purpose. With the struct split, the drain-and-clear copies only the 2-field hot group. Landing these together means the mutable worklist optimization is effective from the start.

#### Phase 3a: Struct-Copy Site Classification

**Goal**: Classify all 25 `struct-copy prop-network` sites in `propagator.rkt` by which fields they actually modify.

**Output**: A table mapping each call site (file, line, function) to the field group it touches (hot, warm, cold, or multiple). This classification IS the design work of the struct split — the struct definitions are trivial in comparison.

**Expected distribution** (from audit §9.2):
- Hot-only (worklist, fuel): `run-to-quiescence-inner` worklist pop
- Warm-only (cells, contradiction): `net-cell-write`, `net-cell-replace`
- Cold-only (merge-fns, propagators, etc.): `net-new-cell`, `net-add-propagator`
- Multiple: some sites may touch both warm and cold (e.g., cell allocation touches cells + merge-fns)

#### Phase 3b: Inner Struct Definitions + Accessor Macros

**Goal**: Define the three inner structs and a zero-cost compatibility layer.

```racket
(struct prop-net-hot (worklist fuel) #:transparent)
(struct prop-net-warm (cells contradiction) #:transparent)
(struct prop-net-cold (merge-fns contradiction-fns widen-fns
                       propagators next-cell-id next-prop-id
                       cell-decomps pair-decomps cell-dirs)
  #:transparent)
(struct prop-network (hot warm cold) #:transparent)
```

**Accessor macros** (Option A from critique — zero-cost, compile-time inlined):
```racket
(define-syntax-rule (prop-network-cells net)
  (prop-net-warm-cells (prop-network-warm net)))
(define-syntax-rule (prop-network-worklist net)
  (prop-net-hot-worklist (prop-network-hot net)))
;; ... etc for all 13 fields
```

These preserve existing call-site syntax. Migration is: define macros, verify tests pass, then incrementally migrate sites to direct inner-struct access.

#### Phase 3c: Mutable Worklist/Fuel + Hot Struct

**Goal**: Replace per-iteration struct-copy with mutable boxes for worklist/fuel.

```racket
(define (run-to-quiescence-inner net)
  (define wl (box (prop-net-hot-worklist (prop-network-hot net))))
  (define remaining-fuel (box (prop-net-hot-fuel (prop-network-hot net))))
  ;; Strip hot group once — worklist/fuel live in boxes now
  (define net0 (struct-copy prop-network net
                  [hot (prop-net-hot '() 0)]))
  (let loop ([net net0])
    (cond
      [(prop-net-warm-contradiction (prop-network-warm net))
       (finalize net wl remaining-fuel)]
      [(<= (unbox remaining-fuel) 0)
       (finalize net wl remaining-fuel)]
      [(null? (unbox wl))
       (finalize net wl remaining-fuel)]
      [else
       (define pid (car (unbox wl)))
       (set-box! wl (cdr (unbox wl)))
       (set-box! remaining-fuel (sub1 (unbox remaining-fuel)))
       (define prop (champ-lookup (prop-net-cold-propagators
                                    (prop-network-cold net)) pid))
       (if (eq? prop 'none)
           (loop net)
           (let ([net* ((propagator-fire-fn prop) net)])
             ;; Drain: fire function added to hot.worklist via net-cell-write
             ;; Move those entries to our mutable box, clear hot struct
             (set-box! wl (append (prop-net-hot-worklist
                                    (prop-network-hot net*))
                                  (unbox wl)))
             (loop (struct-copy prop-network net*
                     [hot (prop-net-hot '() 0)]))))])))

(define (finalize net wl fuel)
  (struct-copy prop-network net
    [hot (prop-net-hot (unbox wl) (unbox fuel))]))
```

The drain-and-clear now copies only the 2-field hot struct — not the full 13-field network. This is the key reason Phases 3 and 4 must land together.

**Pre-requisite audit** (must complete before implementation):
1. **Direct accessor grep**: Search for `prop-network-worklist` and `prop-network-fuel` across the entire codebase. Expected: only `run-to-quiescence-inner`, `run-to-quiescence-bsp`, and network construction/finalization.
2. **Indirect access check**: Verify that no propagator fire function calls any helper that reads worklist or fuel. Fire functions should only call `net-cell-read`/`net-cell-write`/`net-add-propagator`.
3. **Recursive quiescence check**: Verify no fire function calls `run-to-quiescence` recursively (which would read fuel from the struct).
4. **Contingency**: If any fire function reads worklist or fuel, the mutable-box approach needs revision. Fallback: keep worklist/fuel in the hot struct but benefit from the 2-field copy (still a win over 13-field, just not zero-allocation).

#### Phase 3d: Warm-Group Cell Write

**Goal**: `net-cell-write` copies only the warm group (cells + contradiction).

After the struct split, a cell write that changes a value needs to update only `prop-net-warm` (2 fields), not the full network. The cold group (merge-fns, propagators, etc.) is shared by pointer.

#### Phase 3e: Cold-Group Allocation Ops

**Goal**: `net-new-cell` and `net-add-propagator` copy only the cold group when they need to update merge-fns, propagators, or ID counters.

#### Phase 3f: Remove Accessor Macros

**Goal**: After all 25 struct-copy sites and all field accessor call sites are migrated to use inner structs directly, remove the compatibility macros.

**Risk**: Largest change surface in the Track. Mitigated by:
- 3a classification before any code changes
- 3b macros enabling incremental migration with passing tests at each sub-phase
- Each sub-phase independently testable

**Scope boundary — `elab-network`**: This Track optimizes `prop-network` internals. The `elab-network` wrapper (5 fields) also has `struct-copy` overhead — every `elab-cell-write` wraps `net-cell-write`'s result in a new `elab-network`. This is a smaller cost (5 fields vs 13→2) and Track 8 Part B's cell-ops extraction will restructure the elab-network layer. Optimizing `elab-network` is out of scope for this Track.

**Pipeline checklist (Phase 3f)**: The `.claude/rules/pipeline.md` "New Struct Field" checklist applies to Phase 3b (adding inner struct fields). Phase 3f (removing accessor macros) requires verifying that all pattern-match and accessor sites have been migrated. Run `raco make driver.rkt` to recompile all transitive dependents after struct changes — stale `.zo` caches cause "expected N fields" errors.

**Phase 3c observable state note**: The `net0` network passed to propagator fire functions has an empty worklist and zero fuel in its hot group (the real values live in mutable boxes). If any code inspects `prop-network-fuel` on a network mid-quiescence, it sees 0 instead of the actual remaining fuel. The pre-requisite audit (items 1-3) should catch any such code, but this scenario is explicitly flagged: the observable state of the network during iteration differs from the logical state.

**BSP loop note**: Phase 3c optimizes the serial (Gauss-Seidel) loop. The BSP loop (`run-to-quiescence-bsp`) has a different worklist pattern — it collects per-round propagator sets. An analogous optimization for the BSP loop (mutable round buffer) should be designed as part of BSP-LE Track 4 (BSP Pipeline). The struct split (3b-3e) benefits both loops equally.

### Phase 4: Batch Cell Registration

**Goal**: Use transient CHAMP for multi-cell setup in `register-global-env-cells!` and similar batch operations.

**File**: `global-env.rkt` lines ~345-360, `elaborator-network.rkt` (initial network setup)

**next-cell-id strategy**: Pre-allocate a range of IDs rather than incrementing per-cell. The cold struct's `next-cell-id` is incremented by N once, and IDs `start..start+N-1` are used in the batch loop. This means one cold-struct copy instead of N.

**Design**:
```racket
(define (batch-register-cells net cell-specs)
  ;; cell-specs: (listof (list name initial-val merge-fn contradicts?))
  (define N (length cell-specs))
  (define cold (prop-network-cold net))
  (define start-id (prop-net-cold-next-cell-id cold))
  ;; Pre-allocate ID range
  (define tcells (champ-transient (prop-net-warm-cells (prop-network-warm net))))
  (define tmerge (champ-transient (prop-net-cold-merge-fns cold)))
  (define tcontra (champ-transient ...))
  (for ([spec (in-list cell-specs)]
        [i (in-naturals)])
    (match-define (list name init merge contra?) spec)
    (define cid (cell-id (+ start-id i)))
    (tchamp-insert! tcells cid (prop-cell init '()))
    (tchamp-insert! tmerge cid merge)
    (when contra? (tchamp-insert! tcontra cid contra?)))
  ;; Single freeze + single struct construction
  (define new-warm (struct-copy prop-net-warm (prop-network-warm net)
    [cells (tchamp-freeze tcells)]))
  (define new-cold (struct-copy prop-net-cold cold
    [merge-fns (tchamp-freeze tmerge)]
    [next-cell-id (+ start-id N)]
    ...))
  (struct-copy prop-network net [warm new-warm] [cold new-cold]))
```

**Savings**: For 50 definition cells, saves ~49 intermediate prop-network copies + ~100 dead CHAMP tries. One-time per command start.

**Risk**: Low. The transient CHAMP infrastructure is already implemented and tested (champ.rkt:497-544). The batch pattern is a straightforward application.

### Phase 5: Propagator Input Batching

**Goal**: Use transient CHAMP for multi-input propagator registration in `net-add-propagator`.

**File**: `propagator.rkt` line ~696

**Design**: Same pattern as Phase 4 — convert cells CHAMP to transient, register all input dependencies, freeze once.

**Savings**: For propagators with N inputs, saves N-1 intermediate CHAMP tries. Small per-propagator win but accumulates across 15+ propagators per command.

**Risk**: Low. Follow-on to Phase 4 pattern.

### Phase 6: Verification + A/B Comparison

**Deliverables**:
1. Full test suite (7308+ tests, all pass)
2. A/B benchmark comparison vs Phase 0 baselines:
   - `bench-ab.rkt benchmarks/comparative/ --runs 15` — wall-time improvement
   - `bench-micro.rkt benchmarks/micro/bench-alloc.rkt` — per-operation improvement
   - Solver adversarial benchmark — should not regress
3. Per-command verbose comparison: `cell_allocs` and `prop_firings` unchanged (semantics preserved), wall-time reduced
4. **Memory comparison**: `(collect-garbage 'major)` + `(current-memory-use)` on representative module, compared to Phase 0 baseline. Verify mutable boxes don't prevent GC of intermediate states.
5. **Suite time target**: ≤180s (10-20% improvement from ~200s baseline). Based on audit estimates: ~148 struct-copies + 2600 field-copy savings per command, over hundreds of commands per module load.

---

## 3. Design Decisions

| # | Decision | Resolution | Rationale |
|---|----------|------------|-----------|
| D1 | Optimization ordering | eq? fast path → merge audit → combined struct split + mutable worklist → batch registration | Dependencies: merge audit enables eq?-only; struct split and mutable worklist must land together (drain pattern requires 2-field hot struct) |
| D2 | Worklist/fuel mutability | Mutable boxes inside pure loop, drain-and-clear on 2-field hot struct, finalize at exit | Preserves pure data-in/data-out contract; drain pattern cheap with 2-field struct |
| D3 | Struct split granularity | Three groups: hot (2), warm (2), cold (9) | Matches mutation frequency analysis from audit §9.2 |
| D4 | Compatibility layer | Zero-cost `define-syntax-rule` macros during migration (Option A from critique) | Compile-time inlined; preserves call-site syntax; removed after full migration |
| D5 | Struct-copy site classification | Required deliverable (Phase 3a) before any code changes | The classification IS the design work of the split; prevents ad-hoc decisions |
| D6 | Batch registration ID strategy | Pre-allocate range: increment `next-cell-id` by N once | One cold-struct copy instead of N; IDs `start..start+N-1` |
| D7 | GC / dead propagator cleanup | Deferred (audit §12 recommendation) | Allocation efficiency first; provenance value needs analysis |
| D8 | BSP quiescence loop | Not modified in this Track; analogous optimization deferred to BSP-LE Track 4 | Struct split benefits both loops; mutable worklist is serial-specific |
| D9 | Worklist data structure | `list` with `append` (current) | Adequate for typical 1-3 dependents per cell; deque optimization deferred unless profiling shows otherwise |

---

## 4. WS Impact

None. This Track is infrastructure-only — no user-facing syntax changes, no new AST nodes, no parser/reader modifications. All changes are internal to `propagator.rkt` and the cell allocation pipeline.

---

## 5. Cross-Track Requirements (Provided to Other Tracks)

| Capability | Consumer Track | Phase |
|------------|---------------|-------|
| Faster propagator substrate (all operations) | PM Track 8, CIU, BSP-LE | All phases |
| Batch cell registration API | PM Track 8 Part A3 (mult/level/session cells) | Phase 4 |
| Struct split (hot/warm/cold) | BSP-LE Track 4 (BSP Pipeline — warm/cold sharing) | Phase 3b |
| Mutable worklist pattern | BSP-LE Track 4 (analogous BSP round buffer) | Phase 3c |

---

## 6. Test Strategy

| Phase | Micro-benchmark | A/B Comparison | Suite |
|-------|-----------------|----------------|-------|
| 0 | Establish baselines (timing + memory) | Establish baselines | Pass (baseline) |
| 1 | `net-cell-write` improvement | — | Pass (no behavioral change) |
| 2 | Merge identity tests (incl. ctor-registry) | — | Pass (no behavioral change) |
| 3a | — (classification deliverable, no code) | — | — |
| 3b-3f | All benchmarks improvement | A/B vs Phase 0 | Pass at each sub-phase |
| 4 | `batch-register-cells` benchmark | — | Pass |
| 5 | `net-add-propagator` improvement | — | Pass |
| 6 | All benchmarks final + memory comparison | A/B vs Phase 0 (total: ≤180s target) | Pass |

**Performance regression detection**: After each phase, the test suite must pass and no A/B benchmark may regress beyond noise (p < 0.05 on Mann-Whitney U test).

---

## 7. Key Files

| File | Phases | Changes |
|------|--------|---------|
| `propagator.rkt` | 1, 3a-3f, 5 | eq? fast path, struct split, mutable worklist, input batching |
| `champ.rkt` | — | No changes (transient infrastructure already exists) |
| `elaborator-network.rkt` | 3b, 4 | Struct accessor updates, batch registration API |
| `global-env.rkt` | 4 | `register-global-env-cells!` uses batch API |
| `type-lattice.rkt` | 2 | Merge identity verification/fix |
| `mult-lattice.rkt` | 2 | Merge identity verification/fix |
| `session-lattice.rkt` | 2 | Merge identity verification/fix |
| `infra-cell.rkt` | 2 | Merge identity verification/fix |
| `ctor-registry.rkt` | 2 | Merge generator identity verification |
| New: `benchmarks/micro/bench-alloc.rkt` | 0 | Allocation micro-benchmarks |

---

## 8. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Phase 3 worklist drain misses propagator-added entries | Low | High | Adversarial test: cascading worklist additions |
| Phase 4 struct split breaks pattern-matches across codebase | Medium | Medium | Compatibility wrappers; incremental migration; tests at each sub-phase |
| Optimizations interact negatively (e.g., struct split + mutable worklist) | Low | Medium | Phase 3 before Phase 4; measure independently and combined |
| Merge identity audit finds many non-identity-preserving functions | Medium | Low | Fix each; mostly mechanical |
| Transient CHAMP freeze cost dominates batch savings for small N | Low | Low | Measure; only apply batch pattern where N > ~10 |

---

## 9. Expected Impact (from Audit §10)

| Optimization | Struct-copies saved/cmd | CHAMP allocs saved/cmd | Notes |
|---|---|---|---|
| Phase 1-2: eq?-first + merge identity | 0 (fewer false changes → fewer downstream copies) | 0 | Enables Phase 3 |
| Phase 3: Struct split + mutable worklist | ~50 per-iteration + 2600 field-copy savings | 0 | Combined: zero allocation per iteration + 2-field cell-writes |
| Phase 4: Batch registration (50 cells) | ~98 | ~200 | One-time per command |
| Phase 5: Input batching | 0 | ~15 | Small per-propagator win |
| **Combined** | **~148 struct-copies + 2600 field-copy savings** | **~215** | + equal? elimination |

Phase 3 delivers both the struct split and mutable worklist as a combined change. The worklist loop does **zero struct allocation** per iteration (mutable boxes for hot group; cell-writes copy only the 2-field warm group).

**Suite time target**: ≤180s (10-20% improvement from ~200s baseline). ~74K struct-copies and ~1.3M field-copy savings across a representative module load (~500 commands).
