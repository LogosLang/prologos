# Persistent Propagator Network (Logic Engine Phase 2)

**Created**: 2026-02-24
**Completed**: 2026-02-24
**Plan file**: `.claude/plans/buzzing-launching-pascal.md`
**Purpose**: Implement the monotonic data plane — the core runtime substrate for the logic engine — as a persistent, immutable propagator network backed by CHAMP maps.

---

## Status Legend

- ✅ **Done** — implemented, tested, passing

---

## Summary

| Component                           | Status | Details                                              |
|-------------------------------------|--------|------------------------------------------------------|
| `propagator.rkt`                    | ✅     | 5 structs, 9 pure operations, ~200 lines             |
| `tests/test-propagator.rkt`         | ✅     | 22 tests — core cell operations                      |
| `tests/test-propagator-network.rkt` | ✅     | 16 tests — topology and wiring                       |
| `tests/test-propagator-persistence.rkt` | ✅ | 17 tests — quiescence, persistence, backtracking     |
| `tools/dep-graph.rkt`               | ✅     | Source dep + 3 test deps added                       |
| Propagator test files               | ✅     | 55 total tests, all passing (~1.1-1.2s each)         |

---

## Architecture

The propagator network is a **persistent, immutable value**. All operations are pure: take a network, return a new network. The old network is never modified (structural sharing via CHAMP).

- **Backtracking** = keep old reference (O(1))
- **Snapshots** = free (binding a variable IS a snapshot)
- **No mutation** — all state in one `prop-network` struct

This is Racket-level infrastructure with **0 new AST nodes**. Cell values are opaque Racket values (no dependency on `syntax.rkt` or the Prologos type system). Phase 3 will wire it into the Prologos type system.

---

## Data Structures

### Identity Types

```racket
(struct cell-id (n) #:transparent)   ;; deterministic Nat counter
(struct prop-id (n) #:transparent)   ;; deterministic Nat counter
```

### Core Structs

```racket
(struct prop-cell (value dependents) #:transparent)
;; value: any Racket value (lattice element)
;; dependents: champ-root (prop-id → #t)

(struct propagator (inputs outputs fire-fn) #:transparent)
;; inputs/outputs: list of cell-id
;; fire-fn: (prop-network → prop-network) — pure state transformer

(struct prop-network
  (cells             ;; champ-root : cell-id → prop-cell
   propagators       ;; champ-root : prop-id → propagator
   worklist          ;; list of prop-id (ephemeral; empty at quiescence)
   next-cell-id      ;; Nat — monotonic counter
   next-prop-id      ;; Nat — monotonic counter
   fuel              ;; Nat — step limit to prevent runaway
   contradiction     ;; #f | cell-id — first contradiction encountered
   merge-fns         ;; champ-root : cell-id → (val val → val)
   contradiction-fns ;; champ-root : cell-id → (val → Bool)
  ) #:transparent)
```

### Hash Helpers

Use the integer directly as hash — cell-id and prop-id wrap Nats, so the Nat itself is a perfect hash (unique, deterministic). This skips `equal-hash-code` overhead.

```racket
(define (cell-id-hash cid) (cell-id-n cid))
(define (prop-id-hash pid) (prop-id-n pid))
```

---

## Pure Operations

| Operation | Signature | Description |
|-----------|-----------|-------------|
| `make-prop-network` | `[fuel] → prop-network` | Create empty network (default 1M fuel) |
| `net-new-cell` | `net val merge-fn [contradicts?] → (values net cell-id)` | Add cell with initial value and merge function |
| `net-cell-read` | `net cid → value` | Read cell's current value |
| `net-cell-write` | `net cid val → net` | Merge value into cell, enqueue dependents |
| `net-add-propagator` | `net inputs outputs fire-fn → (values net prop-id)` | Add propagator, register dependencies, schedule |
| `run-to-quiescence` | `net → net` | Fire propagators until fixed point |
| `net-contradiction?` | `net → Bool` | Has contradiction been detected? |
| `net-quiescent?` | `net → Bool` | Is worklist empty? |
| `net-fuel-remaining` | `net → Nat` | Remaining fuel steps |

### Key Invariants

- **No-change optimization**: `net-cell-write` returns the exact same network object (`eq?`) when `(equal? merged old-val)`. This is critical for termination of monotone networks.
- **Contradiction is sticky**: Once `prop-network-contradiction` is set, `run-to-quiescence` returns immediately.
- **Fuel prevents runaway**: Non-monotone networks (or bugs) are bounded by the fuel counter.
- **Dependent enqueuing**: Only propagators registered as dependents of a cell are enqueued when that cell changes.

---

## Files Created

| File | Description |
|------|-------------|
| `propagator.rkt` | Core module: 5 structs + 9 pure operations (~200 lines) |
| `tests/test-propagator.rkt` | 22 tests: network creation, cell CRUD, merge behavior, contradiction |
| `tests/test-propagator-network.rkt` | 16 tests: add-propagator, dependencies, topology, chains, diamond, fan-out/in |
| `tests/test-propagator-persistence.rkt` | 17 tests: quiescence, convergence, fuel, contradiction, persistence, backtracking, LVar-style |

## Files Modified

| File | Change |
|------|--------|
| `tools/dep-graph.rkt` | Source dep: `propagator.rkt → (champ.rkt)`; 3 test deps |

---

## Test Categories

### test-propagator.rkt (22 tests)

| Category           | Count | What's Verified                                      |
|--------------------|-------|------------------------------------------------------|
| Network creation   | 3     | Empty network, custom fuel, default fuel             |
| Hash helpers       | 2     | cell-id-hash, prop-id-hash                           |
| Cell creation      | 4     | Returns net+id, sequential ids, initial value, with contradicts? |
| Cell read          | 2     | Returns initial value, error on unknown              |
| Cell write (merge) | 7     | flat-merge (bot+val, same, different), max-merge (up, no-change), set-merge, error on unknown |
| Contradiction      | 2     | flat-top triggers, no predicate → no contradiction   |
| Convenience        | 2     | net-quiescent?, net-contradiction?                   |

### test-propagator-network.rkt (16 tests)

| Category              | Count | What's Verified                                    |
|-----------------------|-------|----------------------------------------------------|
| Add propagator basics | 3     | Returns net+pid, sequential ids, propagator stored |
| Dependencies          | 3     | Input cells have pid, output cells don't, multiple inputs |
| Multiple propagators  | 1     | Two propagators on same input cell                 |
| Worklist scheduling   | 2     | Scheduled on add, no duplicate scheduling          |
| Two-cell chain        | 1     | A → [copy] → B propagation                        |
| Diamond network       | 1     | A → B, A → C, B+C → D (adder)                     |
| Fan-out               | 1     | One input, two propagators, two outputs            |
| Fan-in                | 1     | Two inputs, one propagator (adder)                 |
| Adder propagator      | 1     | Design doc Section 2.5 example                     |
| Chain of 3            | 1     | A → B → C propagation                             |
| Initial firing        | 1     | Propagator fires on add when input has data        |

### test-propagator-persistence.rkt (17 tests)

| Category              | Count | What's Verified                                    |
|-----------------------|-------|----------------------------------------------------|
| Quiescence            | 3     | Simple chain, empty worklist, idempotent re-run    |
| Multi-step convergence| 1     | Chain of 5 cells                                   |
| Fuel limit            | 2     | Exhausted stops execution, normal uses minimal fuel|
| Contradiction         | 2     | Halts run-to-quiescence, propagators not fired after |
| Persistence           | 3     | Old net unchanged after write, add-propagator, run |
| Backtracking          | 2     | Reuse pre-contradiction net, multiple branches     |
| LVar-style            | 3     | Set accumulation, monotonic no-op, map pointwise   |
| Snapshot              | 1     | Network IS already persistent (binding = snapshot) |

---

## Test Merge Functions

Tests use simple Racket functions as merge-fns (not Prologos lattice instances):

```racket
;; Flat lattice: 'bot → value → 'top
(define (flat-merge old new)
  (cond [(eq? old 'bot) new] [(eq? new 'bot) old]
        [(equal? old new) old] [else 'top]))
(define (flat-contradicts? v) (eq? v 'top))

;; Max merge (numeric cells)
(define (max-merge old new) (max old new))

;; Set merge (list-based)
(define (set-merge old new) (remove-duplicates (append old new)))

;; Map merge (alist-based pointwise max)
(define (map-merge old new) ...)
```

---

## Key Design Decisions

1. **Self-contained module**: `propagator.rkt` depends only on `champ.rkt`. No dependency on `syntax.rkt`, `prelude.rkt`, or any Prologos pipeline files. This makes it testable in isolation and fast to compile.

2. **Cell values are opaque**: Any Racket value can be a cell value. The merge function and contradiction predicate are per-cell, stored in separate CHAMP maps. This avoids coupling to the Prologos type system.

3. **Per-cell merge and contradiction**: Each cell has its own `merge-fn` and optional `contradicts?` predicate, stored in CHAMP maps on the network. This supports heterogeneous lattices (different cells can use different lattice operations).

4. **Worklist as plain list**: The worklist is a simple list of prop-ids, not a CHAMP set. This is appropriate because: (a) it's ephemeral (empty at quiescence), (b) ordering doesn't affect correctness for monotone networks, (c) duplicates are harmless (just extra work).

5. **Fuel as step counter**: Prevents infinite loops from non-monotone propagators or bugs. Default 1M steps. Normal networks use minimal fuel (simple chain uses <10 steps).

6. **`eq?` optimization for no-change**: `net-cell-write` returns the exact same network object when the merged value equals the old value. Tests verify this with `check-eq?`. This is critical for monotone networks to reach a fixed point.

---

## Key Lessons

1. **`check-true` vs `check-not-false` in rackunit**: `check-true` requires exactly `#t`, not just a truthy value. `(member x lst)` returns the tail of the list (truthy but not `#t`). Use `check-not-false` for membership tests. This caused 3 test failures that were trivially fixed.

2. **CHAMP keys for dependents**: `champ-keys` returns a list of keys via `champ-fold`. The prop-id structs stored in the dependents map are recoverable via `champ-keys`, and `member` with `equal?` finds them correctly (since `prop-id` is `#:transparent`).

3. **Propagator test performance**: All 3 test files complete in ~1.1-1.2s each. Pure Racket tests with no driver/namespace overhead are extremely fast compared to Prologos language tests (which take 3-10s each due to compilation).

4. **No `champ-insert-join` needed**: Although CHAMP provides `champ-insert-join` for monotone updates, the propagator network implements its own merge logic in `net-cell-write` (because the merge function is per-cell, stored in a separate CHAMP). The cell value update uses plain `champ-insert` after computing the merge externally.

---

## Dependency Structure

```
propagator.rkt ──depends-on──> champ.rkt

test-propagator.rkt             ──depends-on──> propagator.rkt, champ.rkt
test-propagator-network.rkt     ──depends-on──> propagator.rkt, champ.rkt
test-propagator-persistence.rkt ──depends-on──> propagator.rkt, champ.rkt
```

No dependency on the AST pipeline (`syntax.rkt`, `driver.rkt`, etc.) — fully isolated.
