# CHAMP Performance Audit

**Date**: 2026-03-21
**Scope**: `champ.rkt` — the persistent hash trie underlying all propagator network state
**Motivation**: BSP-LE Track 0 Phase 0 baselines revealed that CHAMP operations (0.27–1.08μs) are 10× more expensive than struct-copy (0.03μs). Phase 5's transient CHAMP attempt regressed 44% for small batches. The CHAMP is the actual bottleneck — not the network struct layout.
**Prior work**: [Cell/Propagator Allocation Audit](2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md), [BSP-LE Track 0 PIR](2026-03-21_BSP_LE_TRACK0_PIR.md)

---

## 1. Architecture Overview

The CHAMP (Compressed Hash Array Mapped Prefix-tree) is Prologos's persistent hash map. It backs 6 maps in `prop-network`:

| Map | Key type | Value type | Typical size | Mutations/command |
|-----|----------|-----------|--------------|-------------------|
| `cells` | `cell-id` (struct wrapping nat) | `prop-cell` | 50–500 | 10–100 (cell writes) |
| `propagators` | `prop-id` (struct wrapping nat) | `propagator` | 20–200 | 5–50 (prop adds) |
| `merge-fns` | `cell-id` | procedure | 50–500 | 10–30 (cell creates) |
| `contradiction-fns` | `cell-id` | procedure | 5–50 | 1–5 (cells with contradicts?) |
| `cell-decomps` | `cell-id` | (cons tag (listof cell-id)) | 0–100 | 0–50 (decomposition) |
| `pair-decomps` | (cons cell-id cell-id) | #t | 0–50 | 0–25 (dedup) |

Plus per-cell dependency maps (`prop-cell.dependents`): each cell has a small CHAMP mapping `prop-id → #t` (typically 1–3 entries).

### Key characteristics

- **Small maps**: Most maps have 50–500 entries. Trie depth is 1–2 (5-bit segments, 32-way branching).
- **Sequential integer keys**: `cell-id` and `prop-id` wrap sequential nats (0, 1, 2, ...). The hash IS the integer — `cell-id-hash` returns the nat directly.
- **High mutation frequency**: `cells` map is mutated on every cell write (the hot path). During quiescence, this can be 20–100 mutations per run.
- **Structural sharing**: The persistent CHAMP shares unchanged branches between versions. After a single insert, the old and new CHAMP share all nodes except the 1–2 nodes on the modified path.

---

## 2. Cost Analysis: Where Time Is Spent

### 2.1 Insert — The Dominant Operation

`champ-insert` (line 151) is the most frequently called CHAMP operation. Profile from BSP-LE Track 0 Phase 0:

| Context | Per-call cost | Calls per command | Total per command |
|---------|--------------|-------------------|-------------------|
| Cell write (cells map) | ~0.15μs | 20–100 | 3–15μs |
| Cell create (cells + merge-fns) | ~0.30μs (×2 maps) | 10–30 | 3–9μs |
| Propagator add (propagators + cells for deps) | ~0.50μs | 5–50 | 2.5–25μs |
| Dependency registration (per-cell dependents) | ~0.10μs | 10–100 | 1–10μs |

**Total estimated CHAMP insert cost per command: 10–60μs.** Across hundreds of commands in a module load: 2–12ms of pure CHAMP insert time.

### 2.2 Insert Cost Breakdown

For a typical insert into a 100-entry CHAMP (depth 2):

| Step | Cost | Allocations |
|------|------|-------------|
| Hash segment extraction (2 levels) | ~10ns | 0 |
| `popcount` + `data-index` (2 levels) | ~20ns | 0 |
| `equal?` key comparison | ~15ns (cell-id: small struct) | 0 |
| `make-de` (3-vector for data entry) | ~15ns | 1 vector (3 slots) |
| `vector-copy` (content array, depth 1) | ~30ns (4–8 elements) | 1 vector |
| `vector-copy` or `vec-insert` (depth 0) | ~30ns (4–8 elements) | 1 vector |
| `champ-node` construction (2 levels) | ~20ns | 2 structs |
| `champ-root` construction | ~10ns | 1 struct |
| **Total** | **~150ns** | **~5 allocations** |

The dominant costs are **vector allocation + copy** and **struct construction**. The hash computation and bitwise operations are negligible.

### 2.3 Lookup

`champ-lookup` (line 110) is called more frequently than insert (every cell read, every merge-fn lookup, every contradiction-fn check, every dependency lookup):

| Step | Cost |
|------|------|
| Hash segment extraction | ~5ns |
| Bitmap check + popcount | ~10ns |
| `vector-ref` into content | ~5ns |
| `equal?` key comparison | ~15ns |
| **Total (depth 1, hit)** | **~35ns** |
| **Total (depth 2, hit)** | **~55ns** |

Lookup is cheap. The `equal?` on cell-id/prop-id structs is the largest single cost.

### 2.4 Transient Operations

`champ-transient` (line 515) converts persistent → mutable:

| Step | Cost for N entries |
|------|-------------------|
| `champ-fold/hash` to scan all entries | O(N) — visits every node |
| `hash-set!` per entry | O(N) — N hash table insertions |
| **Total** | **O(N) with high constant** |

`tchamp-freeze` (line 541) converts mutable → persistent:

| Step | Cost for N entries |
|------|-------------------|
| `for/fold` over hash entries | O(N) |
| `champ-insert` per entry | O(N × log₃₂N) — rebuilds entire trie |
| **Total** | **O(N log N) with very high constant** |

**This is why Phase 5 regressed**: For a 500-entry cells map, transient + 2 inserts + freeze = ~500 hash-set! + 500 champ-inserts. For 2 sequential persistent inserts: 2 × (2 vector-copies + 2 node structs) = ~10 allocations. The transient approach is ~100× more expensive for N=2.

---

## 3. Findings

### F-1: Key Comparison Uses `equal?` When `eq?` Would Suffice

**Lines**: 128, 174, 271 (lookup and insert)

All propagator network keys are `cell-id` or `prop-id` structs wrapping unique nats. Two cell-ids with the same nat are the *same* cell-id (created once, never duplicated). `eq?` (pointer equality) is sufficient and 3–5× faster than `equal?` (which traverses the struct fields).

**Impact**: Every lookup and insert pays ~15ns for `equal?` instead of ~3ns for `eq?`. With thousands of lookups per command, this is ~12μs/command wasted.

**Caveat**: The CHAMP is a general-purpose data structure — it also backs user-facing `Map` and `Set` where keys may be strings or complex values requiring `equal?`. A key-comparison function parameter (defaulting to `equal?`) would let propagator-network CHAMPs use `eq?` while user-facing maps keep `equal?`.

### F-2: Data Entry 3-Vectors Are Unnecessary for Network Maps

**Line**: 51 (`make-de` creates `#(hash key val)`)

Data entries store the hash alongside the key-value pair. This is correct for general maps where re-hashing is expensive. But for network maps, the hash IS the key (cell-id-hash returns the cell-id's nat). The 3-vector is a 3-slot allocation where a 2-slot pair (key, value) would suffice — or even just the value, since the key is derivable from the hash.

**Impact**: Every insert allocates an unnecessary 3-vector. For 50 inserts/command, that's 50 extra allocations.

### F-3: `vec-insert` Uses Element-by-Element Copy, Not `vector-copy!`

**Lines**: 448–460

`vec-insert` copies elements one by one in a manual loop. Racket's `vector-copy!` (which maps to memcpy for homogeneous vectors) would be 5–10× faster for the copy phase. Similarly `vec-remove` (lines 463–474).

**Impact**: For content vectors of 4–8 elements (typical), the difference is small in absolute terms (~10ns). But it's called on every insert and delete.

### F-4: Value-Only Updates Copy the Entire Content Vector

**Lines**: 175–177

When inserting a key that already exists (value update, the common case for cell writes), the code does:
```racket
(define new-arr (vector-copy arr))
(vector-set! new-arr idx (make-de hash key val))
```

This copies the entire content vector (4–16 elements) to change one entry. For the propagator network, where the vast majority of inserts are value updates (cell writes to existing cells), this is the hot path.

**Alternative**: If values were stored in mutable boxes within the data entry, value updates would be O(1) — mutate the box, no vector copy. The persistent/immutable semantics would be maintained at the snapshot boundary (copy-on-freeze), not on every update.

### F-5: No In-Place Transient Mutation (Owner-ID Pattern)

**Current transient** (lines 499–545): Converts to Racket hash table + rebuilds from scratch.

Clojure's CHAMP uses an **owner-ID** (edit field) on each node. When a transient operation encounters a node owned by the current transaction, it mutates in place. When it encounters a shared (persistent) node, it copies it and stamps it with the current owner. This means:
- Transient insert of a new key: path-copy only the 1–2 shared nodes, mutate owned nodes in place.
- Transient insert of an existing key (value update): mutate the data entry in place if owned.
- Freeze: clear the owner-ID (O(1) — no rebuild needed).

**Impact**: Owner-ID transients would make the transient/freeze cycle O(modified paths), not O(all entries). This would rehabilitate the Phase 5 approach: `net-add-propagator` with 2–3 inputs would path-copy 1–2 nodes (same as persistent), but with the advantage that consecutive transient inserts share the same owned path.

### F-6: Sequential Integer Keys Concentrate Trie Modifications

Cell-ids and prop-ids are sequential integers (0, 1, 2, ...). With 5-bit hash segments, cells 0–31 all map to the same depth-0 node. Cells 0–1023 share the top two levels. This means:
- Inserting cells 100–110 modifies the SAME depth-0 and depth-1 nodes 10 times, each time copying the same vectors.
- With owner-ID transients, these 10 inserts would modify the node in place after the first copy — 1 copy instead of 10.
- Without owner-ID transients, a scrambled hash (multiply by prime, then take 5-bit chunks) would distribute inserts across different branches, reducing the chance that consecutive inserts collide on the same path.

**Impact**: Sequential-key locality amplifies both the problem (repeated path copies of the same nodes) and the benefit of owner-ID transients (in-place mutation of recently copied nodes).

### F-7: `popcount` Is Implemented in Software

**Lines**: 69–76

Our `popcount` does 5 bitwise operations (Hamming weight via parallel bit counting). Modern CPUs have a hardware `POPCNT` instruction. Racket doesn't expose this directly, but `unsafe-fxpopcount` (available in `racket/unsafe/ops` on Racket 8.7+) uses the hardware instruction when available.

**Impact**: `popcount` is called twice per trie level per operation (once for `data-index`, once for `node-index`). At 2 levels and ~100 operations per command, that's ~400 popcount calls/command. Software popcount is ~5ns; hardware is ~1ns. Savings: ~1.6μs/command. Small but free.

### F-8: No Specialized Small-Map Representation

For the per-cell `dependents` map (typically 1–3 entries mapping `prop-id → #t`), a full CHAMP trie is overkill. A flat association list or small vector would have lower overhead for N ≤ 4:
- CHAMP: 1 champ-root + 1 champ-node + 1 content vector = 3 allocations minimum
- Flat vector of 2 entries: 1 allocation

**Impact**: Every cell has a dependents map. With 200 cells, that's 200 small CHAMPs that could be flat vectors. The lookup cost difference is negligible (linear scan of 2–3 entries vs trie lookup), but the allocation savings compound.

---

## 4. Priority Assessment

| Finding | Impact | Effort | Priority |
|---------|--------|--------|----------|
| F-5: Owner-ID transients | **High** — rehabilitates transient for all batch sizes; enables accumulate-and-flush patterns | High (touches all CHAMP operations) | **P0** |
| F-4: Value-only update optimization | **High** — cell writes are the hot path; O(1) vs O(N) for content vector | Medium (mutable box in data entry) | **P1** |
| F-1: `eq?`-based key comparison | **Medium** — 3–5× faster per comparison, thousands of calls | Low (parameterize key-eq fn) | **P1** |
| F-3: `vector-copy!` for vec-insert/remove | **Low-Medium** — small absolute savings, every operation | Low (drop-in replacement) | **P2** |
| F-6: Hash scrambling for sequential keys | **Medium** — reduces path collisions for batch inserts | Low (change hash function) | **P2** |
| F-8: Small-map specialization | **Low-Medium** — allocation savings for per-cell dependents | Medium (new representation + dispatch) | **P3** |
| F-2: Eliminate 3-vector data entries | **Low** — one allocation per insert saved | Medium (changes data entry representation) | **P3** |
| F-7: Hardware popcount | **Low** — ~1.6μs/command saved | Low (one-line change) | **P3** |

---

## 5. Recommendations

### R-1: Owner-ID Transients (addresses F-5, F-6)

Implement Clojure-style ownership tracking for CHAMP nodes. Each node gets an `edit` field (a gensym per transaction). Transient operations check ownership before deciding to mutate or copy. Freeze clears the edit field — O(1), no rebuild.

This is the highest-leverage change because it enables:
- **Small-batch transient operations** (F-5): `net-add-propagator` with 2–3 inputs would be efficient in transient mode (BSP-LE Track 0 Phase 5 rehabilitation)
- **Accumulate-during-quiescence pattern**: The quiescence loop operates on an owned transient; cell writes mutate in place; freeze at quiescence exit produces the persistent version
- **Sequential-key optimization** (F-6): Consecutive cell-id inserts share the same owned path — 1 copy instead of N

### R-2: Parameterized Key Comparison (addresses F-1)

Add an optional `key-eq?` parameter to CHAMP construction (defaulting to `equal?`). Propagator network CHAMPs use `eq?`; user-facing maps keep `equal?`.

### R-3: `vector-copy!` for Array Operations (addresses F-3)

Replace manual element-by-element copy in `vec-insert` and `vec-remove` with `vector-copy!`. Drop-in replacement, no API change.

### R-4: Value-Only Update Fast Path (addresses F-4)

When inserting a key that already exists, if the value is `eq?` to the existing value, return the same node (no allocation). When the value differs, consider mutable-box data entries for transient mode (value update = box mutation, no vector copy).

---

## 6. Relationship to BSP-LE Track 0

BSP-LE Track 0's PIR (§15, Assumption 1) identified: "struct-copy is the dominant allocation cost — wrong. CHAMP operations are 10× more expensive." The Track 0 work optimized struct layout and eliminated per-iteration allocation; this audit examines the next layer down — the CHAMP operations that Track 0's baselines revealed as the actual bottleneck.

Track 0 Phase 5 (transient input batching) was rejected because the current transient implementation rebuilds from scratch. Owner-ID transients (R-1) would make Phase 5's approach viable, potentially yielding the wall-time improvement that Track 0 targeted but didn't achieve.
