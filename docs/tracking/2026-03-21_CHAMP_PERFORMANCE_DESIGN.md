# CHAMP Performance — Stage 3 Design

**Date**: 2026-03-21
**Status**: Draft (D.2 — external critique incorporated)
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
| 6 | Owner-ID freeze | O(modified nodes) freeze — walk + clear edit, not full rebuild | ⬜ | | Completes owner-ID transient. Old freeze was O(N log N); new is O(modified paths × depth) |
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
| `champ-node` construction 3-field vs 4-field | Regression baseline for Phase 4 edit field addition |
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

**Specificity note**: This optimization benefits use cases where values have *identity stability* — where the merge/update function returns the identical Racket object on no-change. Our propagator network merge functions satisfy this (BSP-LE Track 0 Phase 2 ensured it). User-facing `Map` and `Set` operations with freshly-constructed values (strings, lists) won't see improvement from Phase 3 because freshly-allocated values are never `eq?` to existing ones. This is expected — Phase 3 targets the propagator hot path, not general-purpose map operations.

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

**Risk**: The 4th field adds ~8 bytes per node. For a 500-entry CHAMP with ~50 nodes, that's ~400 bytes. Negligible. Every persistent insert that path-copies nodes now constructs 4-field structs instead of 3-field — ~5 extra field writes per insert at ~1ns each = ~5ns regression (~3% of the ~150ns insert cost). Phase 0 baselines include a 3-field vs 4-field construction benchmark to measure this precisely before committing Phase 4.

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
           ;; Value update on owned node
           (cond
             [(eq? (de-val entry) val)
              ;; Same value — no mutation needed (Phase 3 fast path in transient mode)
              (values node #f)]
             [else
              ;; Different value — mutate vector in place (saves content vector copy)
              (vector-set! arr idx (make-de hash key val))
              (values node #f)])]
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

**Known remaining allocation in owned-node value update**: The `make-de` call still allocates a fresh 3-vector data entry (`#(hash key val)`) even though only the value changed. The content vector mutation is saved (the larger allocation — 8-16 words), but the data entry allocation (3 words) remains. Eliminating this would require inlining key/hash/value into the content vector (3 slots per entry instead of a reference to a 3-vector), which changes the content vector layout and ripples through `data-index`, `node-index`, `vec-insert`, `vec-remove`, and all iteration code. This is flagged as a potential Phase 5.5 follow-up if profiling shows the data entry allocation is significant after the content vector copy is eliminated.

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

### Ownership Invariant (Phases 4–6)

**The fundamental invariant: a persistent reference must never observe a mutation made through a transient.**

This requires two guarantees:

1. **Edit tokens are globally unique and never recycled.** Racket's `gensym` provides this — gensyms are never `eq?` to each other, by language specification. A new transient with a fresh gensym will never falsely claim ownership of nodes from a previous transient.

2. **Abandoned transients are safe.** If a transient is created but never frozen (e.g., exception during processing), the owned nodes retain their edit field pointing to a gensym that no one holds. Future transients use different gensyms, so these nodes are treated as shared (copied on touch, not mutated). In our codebase, abandonment is not a practical concern: the quiescence loop (`run-to-quiescence-drain` in `propagator.rkt`) always runs to completion — it's a tail-recursive loop with three termination conditions (empty worklist, fuel exhaustion, contradiction), all of which reach `finalize`. There is no `with-handlers` or exception-based early exit. The ATMS speculation path (`save-meta-state!`/`restore-meta-state!`) operates on the `meta-info` CHAMP in `metavar-store.rkt`, not on the prop-network cells CHAMP.

3. **Freeze must clear ALL owned nodes on ALL reachable paths.** The freeze walk visits every child of every owned node (not just modified children) because an owned node at depth 0 may have both owned and shared children. The walk's cost is O(owned-nodes × branching-factor), which for our typical networks (depth 1–2, branching ~8) is 2–6 nodes × 8 children = 16–48 checks. This scales linearly with owned-node count if networks grow (Track 8 adding more cells), but remains small relative to the O(N log N) cost of the old full-rebuild freeze.

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

### Accumulate-During-Quiescence: Conceptual Design

The highest-value application of owner-ID transients. The pattern:

1. Enter `run-to-quiescence-drain` (the serial quiescence loop)
2. Convert the cells CHAMP to an owned transient (get edit token — O(1), no conversion needed with owner-ID)
3. Quiescence loop: propagators fire, cell writes go through owned-transient insert (in-place mutation for owned nodes)
4. On quiescence exit: freeze the cells CHAMP (O(modified nodes))
5. Return persistent network with frozen cells

**The contract question**: `net-cell-write` currently returns a new `prop-network`. In transient mode, the cells CHAMP is mutated in place — so what does `net-cell-write` return?

**Recommended approach** (Option A — same pattern as Track 0 Phase 3c mutable worklist): The owned-transient cells reference is held as a local mutable in the quiescence loop, NOT stored in the `prop-network` struct. `net-cell-write` receives the transient as a parameter (or accesses it via a thread-local parameter). Fire functions receive a `prop-network` with the pre-quiescence cells field (stale), but the quiescence loop holds the live transient separately.

This is exactly the Track 0 Phase 3c pattern (mutable worklist box held locally, network struct has empty worklist). The pure data-in/data-out contract is preserved at the quiescence boundary: immutable network in, immutable network out. Within the loop, the transient is a local mutable — same scope discipline.

**Why defer implementation to post-Track 8**: Threading the transient through `net-cell-write` requires modifying `net-cell-write`'s API (adding a transient parameter or using a thread-local parameter). `net-cell-write` is called from 15+ sites through the `current-prop-cell-write` callback in `metavar-store.rkt`. Track 8 Part B eliminates these callbacks — fire functions will call `net-cell-write` directly via `cell-ops.rkt`. Threading the transient through the direct API is cleaner than threading it through the callback indirection layer.

Implementation belongs in Phase 7 of this Track or as a Track 8 follow-on, once the callback elimination is in place.

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
