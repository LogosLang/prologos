# Cell & Propagator Allocation Audit

**Date**: 2026-03-20
**Scope**: `propagator.rkt`, `champ.rkt`, `elaborator-network.rkt`, `global-env.rkt`
**Thesis**: Any even modest gains in allocation efficiency — speed or memory — will have disproportionate effect on the propagator network, because of the scale at which cells and propagators are created and the increasing degree to which the system depends on them.

---

## 1. Data Structures Under Audit

### 1.1 `prop-network` (propagator.rkt:147–161)

The immutable core. **13 fields**:

```
cells, propagators, worklist, next-cell-id, next-prop-id, fuel,
contradiction, merge-fns, contradiction-fns, widen-fns,
cell-decomps, pair-decomps, cell-dirs
```

Every mutation returns a new `prop-network`. Racket's `struct-copy` copies all 13 field slots into a fresh struct even when only 1–3 change. This is the dominant per-operation allocation cost.

### 1.2 `prop-cell` (propagator.rkt:120)

2-field struct: `(value dependents)`. Lightweight individually, but copied per-cell-write and per-propagator-registration.

### 1.3 `elab-network` (elaborator-network.rkt:92–98)

5-field wrapper: `(prop-net cell-info next-meta-id id-map meta-info)`. Every elab-level operation creates both a new `prop-network` AND a new `elab-network` — the wrapper adds one `struct-copy` atop each prop-level operation.

### 1.4 CHAMP trie (champ.rkt)

All cell/propagator/merge-fn/contradiction-fn/dependent maps are CHAMP (Compressed Hash-Array Mapped Prefix-tree) persistent tries. O(log₃₂ N) — typically depth 2–3 for 100–1000 elements. Each insert at a trie level copies the content vector (`vec-insert` at champ.rkt:448–460: `make-vector(len+1)` + element-by-element copy).

---

## 2. Cell Allocation: `net-new-cell` (propagator.rkt:259–276)

### Cost per call

| Operation | Allocations |
|-----------|-------------|
| `prop-cell` construction | 1 struct (2 fields) |
| `cell-id` wrapper | 1 struct |
| `champ-insert` into `cells` | 1–3 vector copies (trie depth) |
| `champ-insert` into `merge-fns` | 1–3 vector copies |
| `struct-copy prop-network` (13 fields) | **1 full struct** |
| If `contradicts?`: second `struct-copy prop-network` + 1 more `champ-insert` | +1 full struct + 1–3 vectors |

**Typical path (with contradiction check)**: 2 struct-copies of a 13-field struct + 3 CHAMP inserts (each = 1–3 vector allocations) = **~11 allocations**.

**At the elab level** (`elab-fresh-meta`, elaborator-network.rkt:159–172): adds another `elab-network` constructor call (5-field struct) + 1 `champ-insert` into `cell-info`. The elab-network is NOT struct-copied — it's constructed directly, which is marginally cheaper. Total elab-fresh-meta: **~14 allocations**.

### Scale

Every type metavariable, every infrastructure cell (definition cells, param-name cells), every PUnify decomposition cell is an `elab-fresh-meta`. A single `def` command with polymorphic type inference can create 10–30 metas; a prelude load creates hundreds. The per-command `register-global-env-cells!` (global-env.rkt:345–360) recreates all definition cells sequentially via `for/fold`, each triggering the full allocation chain.

---

## 3. Propagator Allocation: `net-add-propagator` (propagator.rkt:690–714)

### Cost per call

| Operation | Allocations |
|-----------|-------------|
| `propagator` struct | 1 struct (3 fields) |
| `prop-id` wrapper | 1 struct |
| Per input cell: `champ-lookup` + `champ-insert` (deps) + `struct-copy prop-cell` + `champ-insert` (cells) | **per input**: 1 struct-copy (2-field) + 2 CHAMP inserts |
| Final `struct-copy prop-network` | 1 full struct (13 fields) |
| `champ-insert` into propagators | 1–3 vector copies |

**Cost is O(N) in number of input cells.** For a unification propagator with 2 inputs: 2 prop-cell copies + 4 CHAMP inserts + 1 prop-network struct-copy + 1 CHAMP insert = **~14 allocations**. For a barrier propagator with 5 conditions: **~26 allocations**.

The `for/fold` over inputs (line 696) accumulates CHAMP mutations one at a time — each insert operates on the trie produced by the previous insert, which is correct for persistence but means N sequential trie modifications rather than a single batch.

---

## 4. The Hot Path: `net-cell-write` (propagator.rkt:342–376)

This is THE critical path. Every propagator firing typically calls `net-cell-write` on 1–2 output cells. The worklist loop (`run-to-quiescence-inner`, line 835) fires propagators serially until quiescence.

### Cost per call (when value changes)

| Operation | Allocations |
|-----------|-------------|
| `champ-lookup` for cell | 0 (read-only) |
| `champ-lookup` for merge-fn | 0 (read-only) |
| `merge-fn` call | depends on merge (typically 0–1) |
| **If `equal? merged old-val`**: return `net` unchanged | **0** (the fast path) |
| `struct-copy prop-cell` | 1 struct (2 fields) |
| `champ-insert` into cells | 1–3 vector copies |
| `champ-keys` on dependents | 1 list allocation |
| `append` dependents onto worklist | 1 list cons per dependent |
| `champ-lookup` for contradiction-fn | 0 (read-only) |
| `struct-copy prop-network` | **1 full struct (13 fields)** |
| If contradicted: second `struct-copy prop-network` | +1 full struct |

**The no-change guard (line 359) is the termination guarantee**: bidirectional propagators that see their own output won't re-fire, and the entire network quiesces. This guard returns the *same* `net` object (pointer equality), which `elab-cell-write` (line 184) propagates upward — no elab-network allocation when nothing changes.

**Typical change path**: 1 prop-cell copy + 1 CHAMP insert + 1 prop-network copy = **~5 allocations**.

### Frequency

During elaboration of a single command, the worklist may fire 20–100+ propagators, each writing 1–2 cells. At ~5 allocations per actual change (more when the merge short-circuits to no-op), this is the dominant source of transient allocation pressure.

---

## 5. The Worklist Loop: `run-to-quiescence-inner` (propagator.rkt:835–852)

```racket
(define (run-to-quiescence-inner net)
  (cond
    [(prop-network-contradiction net) net]
    [(<= (prop-network-fuel net) 0) net]
    [(null? (prop-network-worklist net)) net]
    [else
     (let* ([pid (car (prop-network-worklist net))]
            [rest (cdr (prop-network-worklist net))]
            [net* (struct-copy prop-network net
                    [worklist rest]
                    [fuel (sub1 (prop-network-fuel net))])]
            [prop (champ-lookup ...)])
       (if (eq? prop 'none)
           (run-to-quiescence-inner net*)
           (run-to-quiescence-inner ((propagator-fire-fn prop) net*))))]))
```

**Per iteration**: 1 `struct-copy prop-network` (13 fields) just to pop the worklist and decrement fuel. This is architecturally necessary — the network is a pure value — but it means each propagator firing costs at minimum one 13-field struct allocation *before* the propagator's own work.

The loop is serial (Gauss-Seidel scheduling). There is a BSP variant (`run-to-quiescence-bsp`, line 955) that collects all ready propagators per round and fires them, but it's unused in the default path.

---

## 6. struct-copy: The Dominant Cost

### The arithmetic

`struct-copy` on a 13-field struct allocates a new struct and copies all 13 slot values, regardless of how many were changed. The cost per struct-copy:

- 1 `make-struct` (header + 13 slots = 14 words = 112 bytes on 64-bit)
- 13 field reads from old struct
- 13 field writes to new struct (1–3 are the new values, 10–12 are identical pointers)

### Occurrence counts in propagator.rkt

| Operation | `struct-copy prop-network` calls | Context |
|-----------|----------------------------------|---------|
| `net-new-cell` | 1–2 | Cell allocation |
| `net-cell-write` | 1–2 | Cell mutation (hot path) |
| `net-cell-replace` | 1 | S(-1) retraction |
| `net-add-propagator` | 1 | Propagator registration |
| `run-to-quiescence-inner` | 1 per iteration | Worklist pop + fuel decrement |
| Various others | ~18 more | Threshold ops, widening, decomposition, direction |
| **Total in propagator.rkt** | **25** | |

Plus 7 `struct-copy prop-cell` (2 fields each) and 2 `struct-copy elab-network` in elaborator-network.rkt.

### Why this matters at scale

For a command that creates 15 metas and runs unification to quiescence with 50 propagator firings:
- Cell allocation: 15 × 2 = 30 prop-network copies
- Propagator creation: ~15 × 1 = 15 prop-network copies
- Worklist iterations: 50 × 1 = 50 prop-network copies
- Cell writes (with change): ~30 × 1 = 30 prop-network copies
- **Total**: ~125 copies of a 13-field struct = ~14 KB of struct allocation per command

This is not catastrophic for a single command, but multiply by hundreds of commands in a module load and it becomes the dominant allocation source.

---

## 7. CHAMP Internals: Vector Copy Cost

Each `champ-insert` at a given trie level calls `vec-insert` (champ.rkt:448–460):

```racket
(define (vec-insert vec idx val)
  (define len (vector-length vec))
  (define new (make-vector (+ len 1)))
  ;; element-by-element copy, shift right after idx
  new)
```

This allocates a vector of `len+1` words and copies all existing elements. For the typical CHAMP node at depth 0–1, vectors are 2–8 entries. The cost is small per-insert but accumulates with the 2–3 inserts per cell allocation and 4+ per propagator allocation.

The **update-in-place** path (same key, different value — line 175) does `vector-copy` (full vector clone) rather than vec-insert, which is cheaper (no growth, just clone).

---

## 8. Existing Batch Infrastructure (Unused)

### Transient CHAMP builder (champ.rkt:497–544)

The codebase already implements a mutable transient builder:

- `champ-transient`: Convert persistent CHAMP → mutable hash table
- `tchamp-insert!`: O(1) amortized hash-set!
- `tchamp-freeze`: Rebuild persistent CHAMP from hash entries (O(n log n))

**This is designed exactly for batch construction** — insert N entries with O(1) amortized each, then freeze once. Total: O(N) + O(N log N) = O(N log N).

Compare to N sequential `champ-insert` calls: O(N log N) but with N intermediate trie allocations that are immediately garbage. The transient builder avoids all intermediate allocations.

**Currently unused for network operations.** `register-global-env-cells!` (global-env.rkt:345–360) does N sequential elab-network updates via `for/fold`, each creating intermediate networks. The cells CHAMP, merge-fns CHAMP, and cell-info CHAMP each see N sequential inserts producing N-1 dead intermediate tries.

---

## 9. Optimization Opportunities

All optimizations below preserve the pure data-in → data-out contract. The network remains an immutable value; only the internal implementation of construction/mutation changes.

### 9.1 Batch Cell Registration (Moderate impact, low risk)

**Target**: `register-global-env-cells!` and initial network setup.

**Approach**: Accumulate all cell data in a list, then build the CHAMP maps in one pass using the transient builder:

```
1. Collect all (name, initial-value, merge-fn, contradicts?) tuples
2. champ-transient on cells map → tchamp
3. For each tuple: tchamp-insert! cell, tchamp-insert! merge-fn
4. tchamp-freeze → new cells CHAMP, new merge-fns CHAMP
5. One struct-copy prop-network with both new maps
```

**Savings**: N cell registrations currently = N struct-copies of prop-network + N struct-copies of elab-network. Batch: 1 struct-copy of prop-network + 1 elab-network construction. For 50 definition cells, saves ~49 copies of each struct + ~100 dead intermediate CHAMP tries.

### 9.2 Field-Group Struct Splitting (High impact, moderate risk)

**Target**: The 13-field `prop-network` struct.

**Observation**: The 13 fields have different mutation frequencies:

- **Hot** (mutated every worklist iteration): `worklist`, `fuel`
- **Warm** (mutated per cell-write): `cells`, `contradiction`
- **Cold** (mutated only at allocation time): `merge-fns`, `contradiction-fns`, `widen-fns`, `cell-decomps`, `pair-decomps`, `cell-dirs`, `propagators`, `next-cell-id`, `next-prop-id`

**Approach**: Split into inner structs by mutation frequency:

```
prop-network:
  hot:  (worklist fuel)                    — 2 fields, copied every iteration
  warm: (cells contradiction)              — 2 fields, copied per cell-write
  cold: (merge-fns contradiction-fns ...)  — 9 fields, copied only at setup
```

**Effect**: The worklist loop's struct-copy drops from 13-field to 2-field. Cell-write drops from 13 to 2+2=4 fields (hot+warm). Cold fields are shared by pointer — no copy until a new cell or propagator is added.

**Savings**: At 50 propagator firings per command, saves ~50 × (13-2) = 550 unnecessary field copies per command. The warm group saves another ~30 × (13-4) = 270 field copies. Total: ~820 fewer field copies per command.

**Risk**: Every pattern match and accessor on `prop-network` must be updated. 25 struct-copy sites, plus all field accessors. Mechanical but tedious. Could be done incrementally (add inner structs, update accessors one group at a time).

### 9.3 Worklist + Fuel as Mutable State Inside Pure Loop (High impact, moderate risk)

**Target**: `run-to-quiescence-inner`'s per-iteration struct-copy.

**Observation**: The worklist and fuel are only used within the scope of a single `run-to-quiescence` call. They don't need to survive outside that call — the caller only cares about the final cells/propagators/contradiction state.

**Approach**: Use a mutable box or parameters for worklist and fuel inside the quiescence loop, reconstructing the final pure network at the end:

```racket
(define (run-to-quiescence-inner net)
  (define wl (mbox (prop-network-worklist net)))  ;; mutable
  (define fuel (mbox (prop-network-fuel net)))     ;; mutable
  (let loop ([net net])
    (cond
      [(prop-network-contradiction net) (finalize net wl fuel)]
      [(<= (unbox fuel) 0) (finalize net wl fuel)]
      [(null? (unbox wl)) (finalize net wl fuel)]
      [else
       (set-box! fuel (sub1 (unbox fuel)))
       (define pid (car (unbox wl)))
       (set-box! wl (cdr (unbox wl)))
       (define prop (champ-lookup ...))
       (if (eq? prop 'none)
           (loop net)
           (loop ((propagator-fire-fn prop) net)))])))
```

The contract is preserved: `run-to-quiescence` takes a `prop-network` and returns a `prop-network`. The internal use of mutable worklist/fuel is invisible to callers.

**Savings**: Eliminates 1 struct-copy (13 or 2 fields depending on 9.2) per worklist iteration. At 50–100 iterations per command, this is the single largest per-command win.

**Risk**: Moderate — `(propagator-fire-fn prop)` receives a `net` that no longer has the current worklist/fuel in its struct fields. If any propagator reads `prop-network-worklist` or `prop-network-fuel`, it would see stale values. Need to audit all propagator fire functions. The fire functions *should* only use cells/propagators/merge-fns, not worklist/fuel — but this needs verification.

### 9.4 `net-add-propagator` Input Batching (Low-moderate impact, low risk)

**Target**: The `for/fold` in `net-add-propagator` (line 696) that updates cells one at a time.

**Approach**: Use a transient CHAMP for the cells map during input registration:

```racket
(define tcells (champ-transient (prop-network-cells net)))
(for ([cid (in-list input-ids)])
  (define cell (champ-lookup cells ch cid))
  (define new-deps (champ-insert (prop-cell-dependents cell) ph pid #t))
  (tchamp-insert! tcells ch cid (struct-copy prop-cell cell [dependents new-deps])))
(define new-cells (tchamp-freeze tcells))
```

**Savings**: For a propagator with N inputs, saves N-1 intermediate CHAMP tries for the cells map. The prop-cell struct-copies are still necessary (they're 2-field, cheap), but the CHAMP intermediate structures are eliminated.

### 9.5 `equal?` → `eq?` Fast Path in Cell Write (Low-moderate impact, low risk)

**Target**: The fixpoint check in `net-cell-write` (line 359): `(equal? merged old-val)`.

**Observation**: For deep type trees (nested Pi, Sigma, compound types), structural `equal?` is expensive — it traverses the entire tree. But in the common case, the merge function returns the *identical* old value (pointer equality) when nothing changed. An `eq?`-first fast path catches this ~80% case in O(1):

```racket
(if (or (eq? merged old-val) (equal? merged old-val))
    net
    ...)
```

Even better: audit all merge functions to ensure they return the *identical* input value when it wins the merge. If this invariant holds, `eq?` alone suffices and `equal?` becomes unnecessary — eliminating deep structural comparison from the hot path entirely.

**Savings**: Proportional to type-tree depth × propagator firings. For polymorphic types with 3–4 levels of nesting, this avoids thousands of recursive comparisons per command.

### 9.6 Identity-Preserving Short-Circuits (Already partially done)

`elab-cell-write` (line 184) already checks `(eq? pnet* pnet)` and returns the existing `enet` unchanged. This pattern is critical and should be verified to be applied consistently everywhere. The `net-cell-write` no-change guard (line 359) is the foundation of this.

**Audit item**: Verify that all higher-level wrappers (`elab-cell-write`, `elab-cell-replace`, `run-stratified-resolution-pure`) propagate identity through the full call chain when no change occurs.

---

## 10. Quantitative Impact Estimates

Assuming a representative command creates 15 metas, 15 propagators, and runs 50 worklist iterations with 30 cell changes:

| Optimization | Struct-copies saved | CHAMP allocs saved | Notes |
|---|---|---|---|
| 9.1 Batch registration (50 cells) | ~98 | ~200 | One-time at command start |
| 9.2 Field-group splitting | ~2600 field-copies/cmd | 0 | Reduces copy width, not count |
| 9.3 Mutable worklist/fuel | ~50 struct-copies/cmd | 0 | Eliminates per-iteration copy |
| 9.4 Input batching (avg 2 inputs) | 0 | ~15 | Small per-propagator win |
| 9.5 eq?-first fast path | 0 | 0 | Eliminates deep equal? traversals |
| **Combined** | **~148 struct-copies + 2600 field-copy savings** | **~215** | + equal? elimination |

Optimizations 9.2 and 9.3 compound: splitting the struct into hot/warm/cold means the mutable-worklist optimization isn't needed (worklist is already in the hot group), but 9.3 eliminates even the 2-field hot copy. If both are applied, the worklist loop does zero struct allocation per iteration.

---

## 11. Priority Ordering

1. **9.3 Mutable worklist/fuel** — Highest bang-for-buck. Eliminates the most frequent allocation (per-worklist-iteration). Low risk if propagator fire functions don't read worklist/fuel (likely). Audit first, then implement.

2. **9.2 Field-group splitting** — Highest total impact but largest change surface. Can be done incrementally. Worth prototyping with just the hot/cold split first (separate worklist+fuel from everything else).

3. **9.1 Batch cell registration** — Moderate impact, clean implementation, low risk. Good first optimization to land because it exercises the transient CHAMP infrastructure and proves the batch pattern.

4. **9.5 eq?-first fast path** — Quick win with no architectural change. Can be landed immediately as a standalone PR. Audit merge functions for identity-preservation first.

5. **9.4 Input batching** — Smallest impact. Worth doing as a follow-on to 9.1 once the transient CHAMP pattern is established.

---

## 12. Future Direction: Incremental GC

### The question

Threshold propagators (propagator.rkt:720–734) and barrier propagators (line 743–748) have a known lifecycle: for monotonic lattices, a threshold propagator fires at most once after its condition is met. After firing, it will never fire again — its condition remains permanently satisfied. Can these propagators clean themselves up?

### What "clean up" means in this architecture

The propagator network is an immutable value. "Deallocating" a propagator means producing a new network without that propagator. This requires:

1. Removing the propagator from the `propagators` CHAMP
2. Removing its `prop-id` from the `dependents` set of each input cell
3. Possibly removing any cells that were exclusively owned by this propagator

Each of these is a CHAMP mutation returning a new network — the same allocation cost as creating the propagator in the first place. Self-cleanup is not free.

### The provenance question

> "The network IS the replay-ability/provenance trail."

This observation is architecturally deep. The current design preserves ALL cells and propagators — the network at quiescence is a complete record of every inference step. You can trace why a cell has its value by following the propagator graph backward. This is valuable for:

- **Error attribution**: When a type error occurs, trace which propagators contributed to the contradictory cell value. The chain of propagators IS the explanation.
- **Speculation rollback**: TMS (Truth Maintenance System) cells already use the network structure for assumption-tagged speculation. The propagator graph tells you which cells need updating when an assumption is retracted.
- **Debugging**: The BSP (Bulk-Synchronous Parallel) observer traces propagator firings and cell diffs per round. Removing fired propagators would lose this traceability.

### Incremental (not stop-the-world) GC considerations

The key insight is that deallocation in a persistent data structure is fundamentally different from deallocation in a mutable one:

- **No dangling references**: Since the network is immutable, "old" versions that reference the deallocated propagator still hold valid references (to the *old* network that contains it). Only the *new* network lacks it.
- **No use-after-free**: The GC'd propagator exists in all networks created before its removal. This is both safe and problematic — "safe" because no crash, "problematic" because memory for the old propagator is retained by any live reference to a pre-removal network.
- **Incremental is natural**: Because each network operation already returns a new network, removal of dead propagators can be piggybacked onto any network mutation — no stop-the-world pause needed. A cell-write that detects a "just-fired" threshold propagator in its dependents could omit it from the new dependents set, lazily pruning the graph.

### The self-hosting connection: GC as propagator computation

This is not an aside — it's the thesis taken to its conclusion. If "propagators as universal computational substrate" is real, then the GC for propagator networks *is itself a propagator computation*: a liveness analysis that propagates "dead" upward through the dependency graph monotonically. A cell whose value has reached top makes all its downstream propagators candidates for collection if they only read that cell. This is a fixed-point computation — which is what propagators do.

This connects to the ATMS already in the codebase. ATMS justifications are decoupled provenance — they record "node N is justified by assumption set S" without keeping the computation alive. An incremental propagator GC would produce ATMS-compatible provenance records as a byproduct of reclaiming dead propagators: decouple provenance-as-data from propagator-as-mechanism. Keep the provenance chain as a lightweight log entry; deallocate the closure and its captured environment.

### Patterns to explore before committing

1. **Provenance lifetime analysis**: How long after quiescence is the propagator graph actually consulted? If error attribution only needs the graph during `check-unresolved` (immediately after elaboration), then propagators from resolved constraints could be eligible for removal after that phase.

2. **Generation-based retention**: Tag propagators with the command index that created them. Propagators from command N are irrelevant once command N's constraints are fully resolved. This gives a natural generational boundary for cleanup.

3. **Lazy dependent pruning**: Rather than explicitly removing propagators, simply skip them in the worklist loop when their threshold condition is met and their body has already been applied. The propagator struct remains in the CHAMP (preserving provenance) but its `prop-id` is removed from cell dependents (reducing worklist spam). This preserves the network-as-provenance while eliminating re-firing cost.

4. **Snapshot-and-compact**: At command boundaries, take a snapshot of the network for provenance, then create a compacted version with dead propagators removed. The snapshot lives in a provenance log; the compacted version continues as the working network. This cleanly separates the "provenance trail" concern from the "active network efficiency" concern.

### Recommendation

**Do not implement self-GC yet.** The optimization opportunities in §9 (struct splitting, mutable worklist, batch registration) address the primary allocation costs without touching the network's provenance properties. Once those are in place and the per-command allocation profile is tighter, profile again to determine whether dead-propagator retention is a measurable cost. The provenance patterns (especially #3 lazy dependent pruning and #4 snapshot-and-compact) should be prototyped as research exercises to understand the tradeoff space before committing to an architecture.

---

## 13. Measurement Plan

To validate the impact estimates above, the following measurements should be taken before and after each optimization:

1. **Micro-benchmark** (bench-micro.rkt): Add benchmarks for `net-new-cell`, `net-cell-write`, `net-add-propagator`, `run-to-quiescence-inner` on a synthetic network of 100 cells with 50 propagators.

2. **Per-command verbose** (`process-file #:verbose #t`): The `cell_allocs` and `prop_firings` counters from Track 7 Phase 0b already track the right things. Add `struct_copies` and `champ_inserts` counters gated behind `performance-counters.rkt`'s zero-cost-when-disabled pattern.

3. **Comparative A/B** (bench-ab.rkt): Run the adversarial benchmark (`constraints-adversarial.prologos`) with `--runs 15 --ref HEAD~1` after each optimization lands.

4. **Memory profiling**: Use Racket's `(collect-garbage)` + `(current-memory-use)` before and after processing a representative module to measure retained memory. The persistent nature of the CHAMP means old intermediate networks may be retained by closures or parameters — this needs measurement, not assumption.

---

## 14. Key Files Reference

| File | Role | Key functions |
|------|------|---------------|
| `propagator.rkt` | Core allocation + worklist | `net-new-cell` (259), `net-cell-write` (342), `net-add-propagator` (690), `run-to-quiescence-inner` (835) |
| `champ.rkt` | Persistent trie implementation | `champ-insert` (151), `vec-insert` (448), `champ-transient` (515), `tchamp-insert!` (522), `tchamp-freeze` (541) |
| `elaborator-network.rkt` | Elab-level wrapper | `elab-fresh-meta` (159), `elab-cell-write` (181) |
| `global-env.rkt` | Per-command cell registration | `register-global-env-cells!` (345) |
| `performance-counters.rkt` | Zero-cost counters | Infrastructure for measurement |
| `tools/bench-micro.rkt` | Function-level benchmarks | Measurement infrastructure |
| `tools/bench-ab.rkt` | A/B comparative benchmarks | Measurement infrastructure |
