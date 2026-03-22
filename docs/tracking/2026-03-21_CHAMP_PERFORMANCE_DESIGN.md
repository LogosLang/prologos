# CHAMP Performance — Stage 3 Design

**Date**: 2026-03-21
**Status**: Draft (D.1)
**Audit**: [CHAMP Performance Audit](2026-03-21_CHAMP_PERFORMANCE_AUDIT.md)
**Prerequisite**: None — independent of all Series. Benefits all propagator-network consumers.
**Prior work**: [BSP-LE Track 0 PIR](2026-03-21_BSP_LE_TRACK0_PIR.md) (identified CHAMP as actual bottleneck), [BSP-LE Track 0 Phase 5](2026-03-21_BSP_LE_TRACK0_ALLOCATION_EFFICIENCY_DESIGN.md) (transient regression — motivation for owner-ID)
**Principle**: CHAMP operations are 10× more expensive than struct-copy. Every cell write, cell creation, propagator registration, and lookup goes through CHAMP. Optimizing CHAMP benefits every Track in every Series.

---

## Progress Tracker

| # | Phase | Description | Status | Commit | Notes |
|---|-------|-------------|--------|--------|-------|
| 0 | Baselines | CHAMP-specific micro-benchmarks: insert, lookup, transient cycle, per-depth | ⬜ | | Extends bench-alloc.rkt with CHAMP-level measurements |
| 1 | `vector-copy!` for array ops | Replace manual loop in `vec-insert`/`vec-remove` with memcpy | ⬜ | | Low-risk, mechanical. Addresses F-3 |
| 2 | `eq?`-first key comparison | Parameterized key-eq? with `eq?` fast path | ⬜ | | Addresses F-1. Propagator CHAMPs use `eq?`; user maps keep `equal?` |
| 3 | Value-only update fast path | Return same node when new value `eq?` old value | ⬜ | | Addresses F-4. Compounds with Track 0 Phase 1 (eq?-first in net-cell-write) |
| 4 | Owner-ID node structure | Add `edit` field to `champ-node`; ownership check infrastructure | ⬜ | | Addresses F-5. Foundation for Phase 5 |
| 5 | Owner-ID transient operations | In-place mutation for owned nodes; path-copy for shared | ⬜ | | Addresses F-5. Rehabilitates BSP-LE Track 0 Phase 5 |
| 6 | Owner-ID freeze | O(1) freeze (clear edit field, not full rebuild) | ⬜ | | Completes owner-ID transient. `tchamp-freeze` becomes near-free |
| 7 | Verification + A/B | Micro-benchmarks, suite regression, BSP-LE Track 0 Phase 5 revisit | ⬜ | | Target: measurable wall-time improvement on full suite |

---

## 1. Problem Statement

BSP-LE Track 0 optimized `prop-network` struct layout and eliminated per-iteration allocation in the quiescence loop. The result: **wall-time neutral** (+2%). The Phase 0 baselines revealed why: `struct-copy` costs 0.03μs, while `champ-insert` costs 0.15–0.50μs per call. The CHAMP is the actual bottleneck.

Every propagator network operation goes through CHAMP:
- **Cell write** (the hot path): 1 lookup + 1 insert into `cells` + 1 lookup into `merge-fns` + 1 lookup into `contradiction-fns`
- **Cell create**: 1 insert into `cells` + 1 insert into `merge-fns` + optional insert into `contradiction-fns`
- **Propagator add**: 1 insert into `propagators` + N inserts into per-cell `dependents` maps + N lookups into `cells`
- **Cell read**: 1 lookup into `cells`

The audit identified 8 specific inefficiencies, with owner-ID transients (F-5) as the highest-leverage optimization.

### What We Want

After this Track:
- **Transient cycle is O(modified paths)**, not O(all entries) — rehabilitates accumulate-and-flush patterns
- **Value-only updates skip vector copy** — the common case in cell writes
- **Key comparison uses `eq?`** for propagator network maps — 3–5× faster per comparison
- **Array operations use `vector-copy!`** (memcpy) instead of element-by-element loops
- **Measurable wall-time improvement** on the full suite (the target BSP-LE Track 0 missed)

---

## 2. Design: Seven Phases

### Phase 0: CHAMP-Specific Baselines

Extend `bench-alloc.rkt` with CHAMP-level micro-benchmarks:

| Benchmark | What it measures |
|-----------|-----------------|
| `champ-insert` × 1000 (sequential keys) | Raw insert throughput for network-like workload |
| `champ-insert` × 1000 (scrambled keys) | Effect of key distribution on trie depth |
| `champ-lookup` × 10000 (hit/miss ratio) | Lookup throughput at various map sizes |
| `champ-insert` value-only update × 1000 | Cost of updating existing key (the hot path) |
| `champ-transient` + 10 inserts + `tchamp-freeze` | Current transient cycle cost at N=10 |
| Same at N=2 and N=100 | Transient crossover point |
| Per-level cost: depth 1 vs depth 2 vs depth 3 | Cost scaling with trie depth |

### Phase 1: `vector-copy!` for Array Operations

**Files**: `champ.rkt` lines 448–494

**Change**: Replace manual element-by-element loops in `vec-insert`, `vec-remove`, and `vec-remove-insert-node` with `vector-copy!`:

```racket
;; Before (vec-insert):
(let loop ([i 0])
  (when (< i idx)
    (vector-set! new i (vector-ref vec i))
    (loop (+ i 1))))

;; After:
(vector-copy! new 0 vec 0 idx)       ;; copy prefix
(vector-copy! new (+ idx 1) vec idx)  ;; copy suffix
```

`vector-copy!` maps to memcpy for flat (non-boxed) regions. For small vectors (4–8 elements), the speedup is modest (~10ns → ~3ns per copy). For larger vectors (16+ elements in deep tries or large nodes), the speedup is significant.

**Risk**: None — `vector-copy!` is a standard Racket primitive. Same semantics, better constant factor.

### Phase 2: `eq?`-First Key Comparison

**Goal**: Propagator network CHAMPs should use `eq?` for key comparison, falling back to `equal?` only when `eq?` fails.

**Design option A — Per-map key-eq? parameter**: Add a `key-eq?` field to `champ-root`. All lookup/insert/delete operations use `(key-eq? existing-key key)` instead of `(equal? existing-key key)`. Network CHAMPs are constructed with `eq?`; user-facing maps use `equal?`.

**Design option B — `eq?`-first in node operations**: Change all key comparisons from `(equal? k1 k2)` to `(or (eq? k1 k2) (equal? k1 k2))`. This is simpler (no API change) and benefits all CHAMPs — `eq?` catches identical objects in any map, not just network maps.

**Recommendation**: Option B. It's the same pattern as BSP-LE Track 0 Phase 1 (eq?-first in `net-cell-write`). No API change, no parameterization overhead, benefits all CHAMPs. The `eq?` check adds ~1ns when it fails (falling through to `equal?`), which is negligible compared to the ~12ns saved when it succeeds.

### Phase 3: Value-Only Update Fast Path

**Lines**: 174–177 (node-insert, existing key case)

**Current**: When inserting a key that already exists, copies the entire content vector:
```racket
(define new-arr (vector-copy arr))
(vector-set! new-arr idx (make-de hash key val))
(values (champ-node dm nm new-arr) #f)
```

**Optimization**: Check if the new value is `eq?` to the existing value. If so, return the same node — no allocation:
```racket
(define existing-val (de-val entry))
(cond
  [(eq? val existing-val)
   (values node #f)]  ;; same value — return identical node
  [else
   (define new-arr (vector-copy arr))
   (vector-set! new-arr idx (make-de hash key val))
   (values (champ-node dm nm new-arr) #f)])
```

**Compounds with Track 0 Phase 2**: The merge identity audit ensured merge functions return the identical input on no-change. So `merge-fn old new` returns `old` (eq?) when nothing changes. `champ-insert` with the same value then returns the same node (eq?). `net-cell-write` with the same cell then returns the same network (eq?). The entire chain short-circuits.

**Impact**: On re-propagation (100% no-change writes per Phase 0 measurement), every cell write becomes O(1) through the full stack: merge → champ-insert → net-cell-write. No allocation whatsoever.

### Phase 4: Owner-ID Node Structure

**Foundation phase** — adds the edit field to CHAMP nodes without changing behavior.

**Change**: `champ-node` gains an `edit` field:
```racket
;; Before:
(struct champ-node (datamap nodemap content) #:transparent)

;; After:
(struct champ-node (datamap nodemap content edit) #:transparent)
```

- `edit` is `#f` for persistent (shared) nodes
- `edit` is a gensym for owned (transient) nodes
- All existing `champ-node` constructors pass `#f` for edit — zero behavioral change

**Migration**: Every `(champ-node dm nm arr)` call gains a `#f` fourth argument. Mechanical grep-and-replace.

**Risk**: The 4th field adds ~8 bytes per node. For a 500-entry CHAMP with ~50 nodes, that's ~400 bytes. Negligible.

### Phase 5: Owner-ID Transient Operations

**The core optimization.** Transient insert checks ownership:

```racket
(define (tnode-insert! node hash key val level edit)
  (cond
    [(eq? (champ-node-edit node) edit)
     ;; Owned — mutate in place
     (define seg (hash-segment hash level))
     (define bit (segment-bit seg))
     (define dm (champ-node-datamap node))
     (define arr (champ-node-content node))
     (cond
       [(not (zero? (bitwise-and dm bit)))
        (define idx (data-index dm bit))
        (define entry (vector-ref arr idx))
        (cond
          [(equal? (de-key entry) key)
           ;; Value update: mutate vector in place
           (vector-set! arr idx (make-de hash key val))
           (values node #f)]
          [else
           ;; Promote to sub-node (in-place: replace data entry with node entry)
           ...])]
       ...)]
    [else
     ;; Shared — path-copy this node, stamp with current edit
     (define new-arr (vector-copy (champ-node-content node)))
     (define new-node (champ-node (champ-node-datamap node)
                                   (champ-node-nodemap node)
                                   new-arr
                                   edit))
     ;; Now recurse into the owned copy
     (tnode-insert! new-node hash key val level edit)]))
```

Key properties:
- First touch of a shared node: one vector-copy + one struct allocation (same as persistent insert)
- Subsequent touches of the same node: zero allocation (mutate in place)
- For sequential keys (cell-ids 0–31 all hit the same depth-0 node): 1 copy + 31 in-place mutations, vs 32 copies in persistent mode

**New transient API**:
```racket
(define (champ-transient-owned root)
  (define edit (gensym 'champ-edit))
  ;; Return the root node + edit token. No conversion — the trie itself IS the transient.
  (values (champ-root-node root) edit (champ-root-size root)))

(define (tchamp-insert-owned! node size-box hash key val edit)
  ;; In-place insert using ownership
  ...)

(define (tchamp-freeze-owned node size edit)
  ;; Clear edit on all owned nodes (walk the trie, set edit to #f)
  ;; O(modified nodes), not O(all entries)
  (champ-root (freeze-node node edit) size))
```

### Phase 6: Owner-ID Freeze

Freeze walks the trie and clears the `edit` field on owned nodes:

```racket
(define (freeze-node node edit)
  (cond
    [(not (eq? (champ-node-edit node) edit))
     node]  ;; shared — already persistent, skip
    [else
     ;; Owned — clear edit, recurse into children
     (define arr (champ-node-content node))
     (define nm (champ-node-nodemap node))
     ;; Freeze child nodes
     (define new-arr
       (if (zero? nm)
           arr  ;; no children — just clear edit
           (let ([copy (vector-copy arr)])
             (for ([i (in-range (popcount (champ-node-datamap node))
                                (vector-length arr))])
               (define child (vector-ref arr i))
               (when (champ-node? child)
                 (vector-set! copy i (freeze-node child edit))))
             copy)))
     (champ-node (champ-node-datamap node)
                  (champ-node-nodemap node)
                  new-arr
                  #f)]))  ;; clear edit → persistent
```

Cost: O(modified nodes). For a transient that modified 3 paths through a depth-2 trie: ~6 nodes visited, ~3 with edit cleared. The old freeze (`tchamp-freeze`) rebuilt the entire trie from a hash table — O(N log N) for N entries.

### Phase 7: Verification + BSP-LE Track 0 Phase 5 Revisit

1. **Re-run Phase 0 baselines** — measure improvement at each level
2. **Full suite** — regression check
3. **BSP-LE Track 0 Phase 5 revisit**: Re-attempt transient input batching in `net-add-propagator` using owner-ID transients. With O(modified-paths) transient cycle, the 2–3 input case should be efficient.
4. **Accumulate-during-quiescence prototype**: Test the pattern where the quiescence loop operates on an owned transient, cell writes mutate in place, and freeze produces the persistent result at loop exit. If viable, this eliminates CHAMP allocation on the hot path entirely.

---

## 3. Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | `eq?`-first (Option B) over per-map key-eq? (Option A) | Simpler, no API change, benefits all CHAMPs. Same pattern proven in Track 0 Phase 1 |
| D2 | Owner-ID edit field on `champ-node`, not on `champ-root` | Per-node ownership enables partial path-copying: shared nodes stay shared, owned nodes mutate |
| D3 | Freeze walks and clears, not rebuilds | O(modified) vs O(all entries). The whole point of owner-ID is avoiding the rebuild |
| D4 | Retain old transient API alongside owner-ID | Backward compatibility during migration. Old API works but is slower; new API is preferred |
| D5 | Phase 7 revisits BSP-LE Track 0 Phase 5 | The Phase 5 rejection was due to transient overhead, not the batching concept. Owner-ID removes the overhead |

---

## 4. Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|-----------|
| Edit field adds memory per node | Low impact — 8 bytes/node, ~50 nodes typical | Monitor via Phase 0 memory baselines |
| In-place mutation violates persistent expectations | Medium — correctness-critical | Owner-ID discipline: only owned nodes mutate; shared nodes always copy. Comprehensive test suite. |
| Freeze misses an owned node | Medium — subtle correctness bug | Freeze must walk ALL children of owned nodes. Add invariant check: after freeze, no node has the cleared edit |
| Performance regression from edit field check | Low — one eq? per node per operation | The check is ~1ns; the savings from avoiding copies are ~30ns |

---

## 5. Test Strategy

| Phase | Tests |
|-------|-------|
| 1 | Existing CHAMP test suite (champ.rkt lines 560–840) — behavioral equivalence |
| 2 | Same suite — eq? fast path is transparent to correctness |
| 3 | New: value-only update returns same node (eq?); existing suite for correctness |
| 4 | Existing suite — edit field is #f everywhere, zero behavioral change |
| 5 | New: owner-ID transient insert/lookup/delete equivalence tests; mixed persistent+transient interleaving; concurrent ownership (two active edits must not interfere) |
| 6 | New: freeze clears all owned nodes; post-freeze modifications copy (not mutate); invariant checker |
| 7 | Full suite + micro-benchmarks + BSP-LE Track 0 Phase 5 re-attempt |

---

## 6. Key Files

| File | Role | Changes |
|------|------|---------|
| `champ.rkt` | CHAMP implementation | All phases: vec-insert, key-eq?, value-only, owner-ID, freeze |
| `propagator.rkt` | Primary CHAMP consumer | Phase 7: revisit transient batching with owner-ID API |
| `benchmarks/micro/bench-alloc.rkt` | Micro-benchmarks | Phase 0: CHAMP-level baselines |

---

## 7. Relationship to Other Work

- **BSP-LE Track 0**: This Track addresses the bottleneck that Track 0's baselines identified. Track 0 optimized the layer above (struct layout); this Track optimizes the layer below (CHAMP operations). Together they cover the full allocation stack.
- **PM Track 8**: Track 8 adds more cells and propagators (mult/level/session, HKT resolution). Faster CHAMP operations compound with Track 8's increased cell count.
- **BSP-LE Tracks 2-4**: The ATMS solver and BSP pipeline create large propagator networks. Owner-ID transients enable efficient per-round accumulation in the BSP scheduler.
- **CIU Tracks 3-5**: Trait-dispatched access generates additional constraints and cell writes. Faster CHAMP lookup/insert benefits the constraint resolution hot path.
