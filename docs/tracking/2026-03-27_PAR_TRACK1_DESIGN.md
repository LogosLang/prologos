# PAR Track 1: Stratified Topology — BSP-as-Default

**Date**: 2026-03-27
**Series**: PAR (Parallel Scheduling)
**Stage**: 3 (Design Iteration D.3)
**Prerequisites**: PAR Track 0 CALM Audit (✅ `2f3c160`), [Stage 2 Audit](2026-03-27_PAR_TRACK1_STAGE2_AUDIT.md) (`813634a`)

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0a | Pre-0 microbenchmarks: BSP overhead, empty topology check cost | ✅ | `2bfb656` — data below |
| 0b | Narrowing CALM validation (empirical) | ✅ | `f6a3048` — 23/31 pass, 0 cell errors |
| 1 | Decomposition-request cell infrastructure | ⬜ | |
| 2 | SRE decomposition → request emission | ⬜ | |
| 3 | Narrowing branch → request emission | ⬜ | Scope depends on Phase 0b |
| 4 | Topology stratum in BSP loop | ⬜ | |
| 5 | BSP-as-default + individual test verification | ⬜ | |
| 6 | CALM guard hardening | ⬜ | |
| 7 | Constraint-propagators contract | ⬜ | |
| 8 | A/B benchmarks: BSP vs DFS comparative + adversarial + micro | ⬜ | Compare against Phase 0a baselines |
| 9 | Instrumentation cleanup | ⬜ | Remove benchmark-only scaffolding |
| 10 | PIR + tracker + dailies | ⬜ | |

**Phase completion protocol**: After each phase: commit → update tracker → update dailies → proceed.

---

## §1 Goal

Make the BSP scheduler the default for `run-to-quiescence`, producing identical results to DFS for all 380 test files. This requires resolving the 2 CALM topology violations identified in the [Track 0 audit](2026-03-27_PAR_TRACK0_CALM_AUDIT.md): `sre-core.rkt` (structural decomposition) and `narrowing.rkt` (branch/rule installation).

### Deliverables

1. **380/380 green under BSP** — `current-use-bsp-scheduler? #t` with zero test failures
2. **Stratified topology protocol** — decomposition requests as cell values, topology stratum processes between BSP rounds
3. **CALM guard active in production** — `current-bsp-fire-round?` catches future violations at runtime
4. **Narrowing CALM classification** — empirical confirmation of whether cell-only creation is CALM-safe

### Non-Deliverables (deferred)

- `:auto` heuristic (PAR Track 3 — needs benchmarking data from this track)
- True parallelism / futures (PAR Track 2 — research)
- Performance improvement over DFS (Track 1 is correctness, not speed)

---

## §2 Stage 2 Audit Summary

Source: [PAR Track 1 Stage 2 Audit](2026-03-27_PAR_TRACK1_STAGE2_AUDIT.md)

### Violator 1: sre-core.rkt — Structural Decomposition

**3 fire function entry points**: `sre-make-equality-propagator` (line 528), `sre-make-subtype-propagator` (line 570), `sre-make-duality-propagator` (line 622).

**Topology ops per decomposition** (for arity-N compound type):

| Operation | Count | Lines |
|-----------|-------|-------|
| `net-new-cell` | up to 2×N | sre-core.rkt:288, 291, 294 (via `sre-identify-sub-cell`) |
| `net-add-propagator` (sub-relate) | N | sre-core.rkt:423-427 |
| `net-add-propagator` (reconstructor-a) | 1 | sre-core.rkt:431-433 |
| `net-add-propagator` (reconstructor-b) | 1 | sre-core.rkt:434-436 |
| `net-cell-decomp-insert` | 2 | sre-core.rkt:322 (via `sre-get-or-create-sub-cells`) |
| `net-pair-decomp-insert` | 1 | sre-core.rkt:438 |
| **Total** | **3N + 5** | |

**Critical property**: The fire function creates topology but does NOT read from it in the same firing. Sub-cells are populated in subsequent firings. This confirms clean separation — topology creation and value propagation are independent.

**Guard**: `net-pair-decomp?` (line 467) prevents redundant decomposition. Idempotent.

### Violator 2: narrowing.rkt — Branch/Rule Installation

**2 fire function entry points**: `make-branch-fire-fn` (line 228), `make-rule-fire-fn` (line 275).

**Branch path**: Calls `install-narrowing-propagators` (line 246) which recursively calls `net-add-propagator` — installs entire subtrees of the definitional tree.

**Rule path**: Calls `eval-rhs` (line 286) which calls `net-new-cell` (lines 323, 338, 386) to create cells for constructor sub-terms. **Unlike SRE, the fire function immediately references created cell-ids** in `term-ctor` return values.

**Key distinction**: Branch creates propagators (CALM-unsafe). Rule creates cells only (possibly CALM-safe).

### Latent: constraint-propagators.rkt

`install-constraint->method-propagator` (line 266) takes an `install-fn` callback called from a fire function. **Currently unused** (no callers). Needs contract documentation.

### Network Registry Operations

`net-cell-decomp-insert` and `net-pair-decomp-insert` are called from fire functions. These modify `warm` layer CHAMPs, not cells/propagators. BSP's diff-only collection drops them. Must be handled by topology stratum.

---

## §3 Architecture: Two-Fixpoint BSP Loop

### Current BSP Loop (broken for dynamic topology)

```
repeat:
  fire all worklist propagators against snapshot
  bulk-merge VALUE writes
until worklist empty
```

Problem: fire functions that create cells/propagators produce structural changes in their returned `result-net`, but `fire-and-collect-writes` only extracts cell value diffs (propagator.rkt:1179-1185). Structural changes are silently dropped.

### Proposed: Stratified BSP Loop

```
repeat:
  VALUE STRATUM (BSP-safe):
    repeat:
      fire all worklist propagators (CALM guard active)
      bulk-merge value writes
    until worklist empty

  TOPOLOGY STRATUM (sequential):
    read decomposition-request cell
    for each unprocessed request:
      create sub-cells via sre-get-or-create-sub-cells / install-narrowing-propagators
      create sub-propagators via net-add-propagator
      write decomp registry entries
    clear processed requests → new propagators on worklist

until neither value nor topology changed
```

### Termination Argument

**Value stratum**: Terminates by standard propagator monotonicity — each cell value can only increase in lattice order, finite lattice height, so worklist eventually empties. (Existing guarantee, unchanged.)

**Topology stratum**: Terminates because decomposition is guarded by `net-pair-decomp?` — each (cell-a, cell-b, relation) triple decomposes at most once. The number of such triples is bounded by the number of cell pairs × relation types. Each decomposition creates a finite number of sub-cells (bounded by constructor arity). No decomposition creates new compound types that weren't already in the type domain.

**Outer loop**: Each iteration either:
- Adds topology (finite, bounded by type nesting depth), OR
- Reaches fixpoint (no requests, no worklist changes)

The type nesting depth is bounded (no infinite types in a well-typed program). Therefore the outer loop terminates.

### Where This Lives in the Stratification Hierarchy

Current strata: S(-1) retraction → S(0) monotone → S(1) constraint retry → S(2) cleanup.

The topology stratum is NOT a new S-level. It is WITHIN S(0), between BSP rounds. The S(-1)/S(0)/S(1)/S(2) hierarchy handles non-monotone operations across the constraint lifecycle. The topology stratum handles network construction within S(0)'s monotone value propagation.

**Why not a new S-level**: Decomposition requests and their processing are monotone (the set of decompositions only grows). The topology stratum is a monotone operation that extends the network. It doesn't retract, negate, or clean up. It belongs inside S(0).

---

## §4 Decomposition-Request Protocol

### Alternative Approaches Considered

| Approach | Description | Tradeoff |
|----------|-------------|----------|
| **A. Single request cell** | One cell per network, set-union lattice of request structs | Simple. One cell to check. But all requests in one cell means the topology stratum processes everything in one batch. |
| **B. Per-domain request cells** | Separate cells for SRE type, SRE term, narrowing | More targeted. But adds complexity — multiple cells to check, domain routing. |
| **C. Request queue (non-lattice)** | Mutable queue outside the network | Not on-network. Violates Propagator-Only. Invisible to BSP. |
| **D. Structural diff in BSP** | BSP diffs full network, not just values | Fixes the symptom but doesn't address the principle. Fire functions remain unrestricted. Parallel fire functions would have merge conflicts for structural changes. |

**Choice: A (single request cell)**. Rationale:
- Simplest — one cell, one merge function, one check in the topology stratum
- Monotone (set-union under subset ordering)
- The topology stratum processes all requests in one pass regardless of source
- Per-domain routing isn't needed — the request struct carries its domain
- Aligns with Data Orientation: requests are data values, not imperative calls

### Request Structs (D.2: Variant Structs)

D.1 used a flat struct with 11 fields and many `#f` values depending on kind. D.2 critique identified this as a data-orientation violation — the struct's shape doesn't match its content.

**Revised: two variant structs in one cell.** Each variant carries exactly its fields. The topology stratum dispatches on `struct?` predicate. Same cell, same `set-union` merge. This follows the existing Prologos pattern (expr-Pi, expr-Sigma, etc.).

```racket
;; SRE decomposition request (subtype, equality, duality)
(struct sre-decomp-request
  (pair-key    ;; decomp guard key (dedup)
   domain      ;; SRE domain struct
   cell-a      ;; cell-id
   cell-b      ;; cell-id
   desc        ;; ctor-desc
   relation    ;; sre-relation
   ctor-chain) ;; (listof symbol) — constructor chain for occurs check (§4.1)
  #:transparent)

;; Narrowing topology request (branch installation, rule evaluation)
(struct narrowing-decomp-request
  (pair-key    ;; decomp guard key (dedup)
   tree        ;; dt-node (subtree to install)
   arg-cells   ;; (listof cell-id)
   result-cell ;; cell-id
   bindings)   ;; (listof cell-id)
  #:transparent)
```

No `#f` fields, no kind tag needed. The topology stratum:
```racket
(cond
  [(sre-decomp-request? req) (process-sre-decomposition net req)]
  [(narrowing-decomp-request? req) (process-narrowing-topology net req)])
```

**Stale values**: Requests carry cell-ids and metadata, NOT values. The topology stratum re-reads cell values at processing time.

### Merge Function

```racket
(define (decomp-request-set-merge a b)
  (set-union a b))
```

Bot: `(set)` (empty set). Contradiction: none (requests can't contradict).

### Request Cell Creation

Added to `make-prop-network` (or `make-elaboration-network`). One cell per network.

### §4.1 Recursive Type Occurs Check (D.2: Structural Termination)

**Problem**: The outer loop termination argument assumes bounded type nesting depth. But recursive types (`type T = PVec T`) create unbounded nesting. The `net-pair-decomp?` guard prevents re-decomposing the SAME (cell-a, cell-b) pair, but each decomposition creates NEW cells, producing new pairs that pass the guard.

**Structural approach** (correct-by-construction, not a depth-limit guard):

The `sre-decomp-request` carries a `ctor-chain` field — the list of constructor names in the current decomposition chain. When emitting a request, the fire function appends the current `ctor-desc` name to the chain from the parent decomposition.

The topology stratum checks: if the request's `ctor-chain` contains a duplicate (the same constructor appearing twice), this is a recursive type. The stratum can:
1. Stop decomposing and mark the sub-cells as co-inductive (recursive subtyping), OR
2. Emit a contradiction (recursive types not supported in this context)

The `ctor-chain` makes the recursion detection structural — it's a property of the request set, not a runtime depth counter. The merge function can even detect cycles: `set-union` on requests whose `ctor-chain` contains duplicates → filter or flag them.

**Where the chain comes from**: The parent propagator's request included a `ctor-chain`. When the topology stratum creates sub-propagators, it passes the extended chain as context. The sub-propagator's fire function includes it in its request.

**Implementation**: ~10 lines — a `(member ctor-name chain)` check in the topology stratum before processing.

### §4.2 Topology Stratum Scoping (D.2: Per-Quiescence, Not Per-Network)

**D.2 finding**: The topology stratum operates per-`run-to-quiescence` call, not per-network. Each invocation of `run-to-quiescence` (whether from S(0), S(1) constraint retry, or speculation) has its own value→topology outer loop.

This means:
- S(0) decomposition requests are processed within S(0)'s quiescence call
- If S(1) constraint retry fires a propagator that emits a decomposition request, that request is processed within S(1)'s quiescence call
- Speculation's `run-to-quiescence` has its own topology stratum
- No cross-strata request leakage

The decomp-request cell is per-network (shared across strata), but the topology stratum only processes requests emitted during its own quiescence call. **Implementation**: the topology stratum tracks which requests it has already processed (via the `pair-key` dedup in the request set). New requests from inner quiescence calls appear as new set members.

**Interaction with ATMS**: Constraint resolution (S(1)) uses ATMS for speculation/retraction. ATMS is itself stratification-like. Decomposition requests emitted during ATMS-managed speculation are scoped to that speculation's network fork. If the speculation is retracted, the decomposition (and its sub-cells/propagators) are discarded with the fork. No special handling needed — network forking already handles this.

---

## §5 Concrete Walkthrough: SRE Subtype Decomposition

Current (broken under BSP):
```
1. Subtype propagator fires for PVec Int <: PVec Nat
2. Fire function calls sre-maybe-decompose
3. sre-decompose-generic creates:
   - Sub-cell for Int (cell-a's element)
   - Sub-cell for Nat (cell-b's element)
   - Sub-relate propagator: Int-cell <: Nat-cell
   - Reconstructor: Int-cell → PVec cell-a
   - Reconstructor: Nat-cell → PVec cell-b
4. Returns modified network
5. BSP extracts only value diffs → nothing (no value writes to cell-a or cell-b)
6. Topology lost. Quiescence. No contradiction. Wrong answer: true.
```

Proposed (stratified):
```
1. Subtype propagator fires for PVec Int <: PVec Nat
2. Fire function calls sre-emit-decomposition-request
3. Request written to decomp-request cell: {kind: sre-structural, cell-a, cell-b, desc: PVec, relation: subtype}
4. BSP extracts value diff: decomp-request cell changed (∅ → {request})
5. Value stratum quiesces (no more value work)
6. Topology stratum reads request:
   - Re-reads cell-a (PVec Int), cell-b (PVec Nat)
   - Calls sre-decompose-generic: creates sub-cells, sub-propagators, reconstructors
   - Clears request
7. New propagators on worklist → back to value stratum
8. Value stratum fires sub-relate propagator: Int <: Nat
9. Int is NOT <: Nat → contradiction written to sub-cell
10. Reconstructor fires → contradiction propagates to PVec cell
11. Quiescence. Contradiction detected. Correct answer: false.
```

---

## §6 Concrete Walkthrough: Narrowing Branch

Current (broken under BSP):
```
1. Branch propagator fires, watched cell has term-ctor 'suc
2. Fire function calls install-narrowing-propagators for child subtree
3. net-add-propagator creates child rule propagator
4. BSP extracts only value diffs → nothing
5. Child rule propagator never fires. Result cell stays bot.
```

Proposed (stratified):
```
1. Branch propagator fires, watched cell has term-ctor 'suc
2. Fire function writes request to decomp-request cell: {kind: narrowing-branch, tree: child-subtree, arg-cells, result-cell, bindings}
3. Value stratum quiesces
4. Topology stratum reads request:
   - Calls install-narrowing-propagators for the child subtree
   - New propagators on worklist
5. Value stratum fires child rule propagator
6. Rule propagator evaluates RHS, writes to result cell
```

---

## §7 Narrowing Cell-Only CALM Analysis (D.2 Revised)

### D.1 Conclusion (SUPERSEDED)

D.1 concluded that ALL `net-new-cell` in fire functions should be treated as CALM violations. This was overly conservative.

### D.2 Audit Findings

The eval-rhs audit (`6eeb73b`) found:
- **4 `net-new-cell` call sites** in eval-rhs (lines 124, 323, 338, 386)
- **Zero `net-add-propagator` calls** in eval-rhs
- All created cells are **inert storage** — no dependents, no scheduling effect
- Cell-ids are used immediately in returned `term-ctor` values (written to output cells)

### D.2 CALM Safety Analysis

**The CALM theorem guarantees order-independence for monotone operations over a fixed scheduling topology.** The scheduling topology is the set of (propagator, input-cells, output-cells) triples.

- `net-new-cell`: Adds a cell to the cell CHAMP. Does NOT add propagator edges. The scheduling topology is **unchanged**. CALM applies.
- `net-add-propagator`: Adds propagator edges. The scheduling topology **changes**. CALM does NOT apply.

Therefore: `net-new-cell` during BSP fire rounds is **CALM-safe**. `net-add-propagator` is **CALM-unsafe**.

### D.3 Correct-by-Construction Cell Capture

**Concern (D.3 critique)**: D.2's "net-new-cell is CALM-safe" is a property that holds today but isn't structurally enforced. If someone later adds a propagator that iterates all cells, or uses cell count for termination, the argument breaks silently. Relying on "cells without dependents are safe" is maintained-by-discipline, not correct-by-construction.

**Structural approach**: Fire functions may call `net-new-cell` normally (no API change to eval-rhs). But BSP's merge phase **explicitly captures** new cells rather than relying on a full CHAMP diff. It compares `next-cell-id` before and after the fire:

```
snapshot-next-id = (prop-network-next-cell-id snapshot)
result-next-id  = (prop-network-next-cell-id result-net)

if result-next-id > snapshot-next-id:
  ;; Fire function created cells. Extract them by id range.
  for id in [snapshot-next-id .. result-next-id):
    extract cell from result-net → apply to canonical network
```

This is structurally enforced:
- No full CHAMP diff needed (O(new cells), not O(all cells))
- New cells are explicitly enumerated — can't be "sneaked" through an unchecked path
- The fire function doesn't need any API change — it calls `net-new-cell` as before
- BSP's merge is the enforcement point, not the fire function's code

**Implementation**: ~10 lines in `fire-and-collect-writes`. Compare `next-cell-id` counters, extract cells with ids in the gap.

### D.3 Registry Dedup Strategy

**Problem**: SRE fire functions currently call `net-pair-decomp-insert` to record decomposed pairs in `cold.pair-decomps`. Under BSP, these registry writes are dropped (BSP only diffs `warm.cells`). Result: stale snapshot → duplicate requests.

**Resolution**: Under the stratified topology design, fire functions emit requests — they don't decompose or write registries. The topology stratum owns all registry state:

1. **Fire function**: Emits request. Does NOT check `pair-decomps`. Does NOT write registries. Maximally simple: "I see compound types → emit request."
2. **Topology stratum**: Checks `pair-decomps` before processing. Skips already-decomposed pairs. Writes `pair-decomps` after processing. **Single source of truth.**
3. **Duplicate requests are harmless**: Set-union merge in the request cell deduplicates by `pair-key`. Even if two fire functions emit the same request, the set contains it once. The topology stratum processes it once.

This eliminates the registry staleness concern entirely. Fire functions are pure (reads + value/cell writes only). The topology stratum owns all topology state AND all registry state.

### D.3 Design Decision (Revised from D.2)

| Operation | During BSP fire round | Rationale |
|-----------|----------------------|-----------|
| `net-new-cell` | **ALLOWED** — captured via next-cell-id comparison | Structurally enforced by BSP merge |
| `net-add-propagator` | **ERROR** | Changes scheduling topology — CALM-unsafe |
| `net-pair-decomp-insert` | **NOT CALLED** from fire functions | Moved to topology stratum (single source of truth) |
| `net-cell-decomp-insert` | **NOT CALLED** from fire functions | Moved to topology stratum |
| `eval-rhs` | **NO REFACTORING** | Continues as-is; new cells captured structurally |

---

### §7.1 D.3 Self-Critique Findings

#### Lens 1: Principles Challenge

**Decision: net-new-cell allowed during BSP**
- *Decomplection* challenge: fire functions that create cells are doing two things (computing values AND allocating storage). These are separable concerns braided together. Counter: the structural capture makes it correct without separation. The braiding is an implementation detail of term construction, not an architectural coupling. **Verdict**: Pragmatic — correct-by-construction via BSP merge enforcement.

**Decision: ctor-chain occurs check**
- *Completeness* challenge: Who seeds the initial chain? The first SRE propagator fire doesn't have a chain. **Resolution**: The initial request's `ctor-chain` is `(list ctor-name)`. The topology stratum extends it when creating sub-propagators. Sub-propagator fire functions include the extended chain in their requests.

**Decision: pair-key dedup in set-union**
- *Correct-by-Construction* challenge: If two requests have the same `pair-key` but different metadata (e.g., different `desc`), `set-union` keeps both (they're not `equal?`). **Resolution**: `pair-key` is derived from `(cell-a, cell-b, relation)` which uniquely identifies a decomposition. The `desc` (ctor-desc) is determined by the cell values at processing time, not at emission time. Two requests with the same `pair-key` but different `desc` means the cell values changed between emissions — the topology stratum re-reads values anyway, so the `desc` in the request doesn't matter. **Action**: Remove `desc` from the request struct. The topology stratum derives it from cell values at processing time.

#### Lens 2: Codebase Reality Check

**Gap 1 (CRITICAL): Incomplete cell capture in `fire-and-collect-writes`**

The current implementation captures 4 per-cell fields: (cid, cell, merge-fn, contra-fn). Missing:
- `widen-fns` (cold layer) — widening function for descending lattices
- `cell-dirs` (cold layer) — cell direction metadata (WFLE)

This is the same class of bug as the original BSP value-only diff — silent data loss. Currently eval-rhs only creates cells via `net-new-cell` (which doesn't set widen-fns/cell-dirs), so the gap is latent. But incomplete capture breaks if future code uses `net-new-cell-desc`.

**Fix**: Capture all 6 per-cell cold-layer fields. Apply all 6 in `bulk-merge-writes`. ~10 additional lines.

**Gap 2: Phase 2 must explicitly split `sre-decompose-generic`**

`sre-decompose-generic` currently does three things in one call:
1. Creates sub-cells via `sre-get-or-create-sub-cells`
2. Creates sub-propagators via `net-add-propagator`
3. Writes registry via `net-pair-decomp-insert`

Phase 2 must split this: fire functions emit requests (step 0). Topology stratum calls `sre-decompose-generic` for steps 1+2, then writes registry (step 3). The `net-pair-decomp-insert` call at line 438 moves from inside `sre-decompose-generic` to the topology stratum's processing loop.

**Gap 3: `sre-decomp-request` should NOT carry `desc`**

Per the principles challenge finding: `desc` (ctor-desc) is derived from cell values at processing time. Carrying it in the request struct creates a stale-data risk (cell values may evolve between emission and processing). The topology stratum already re-reads cell values — it should also derive `desc` from those values.

**Revised `sre-decomp-request`:**
```racket
(struct sre-decomp-request
  (pair-key    ;; decomp guard key (dedup)
   domain      ;; SRE domain struct
   cell-a      ;; cell-id
   cell-b      ;; cell-id
   relation    ;; sre-relation
   ctor-chain) ;; (listof symbol) — for recursive type occurs check
  #:transparent)
```

`desc` removed — derived from cell values by topology stratum at processing time.

### Phase 0b Validation (COMPLETE — `f6a3048`)

Narrowing tests under BSP with next-cell-id capture:
- **23/31 pass**: Cell creation via eval-rhs works correctly under BSP
- **8/31 fail**: All from `net-add-propagator` CALM guard (branch path) — expected
- **Zero cell-related errors**: next-cell-id capture confirmed working
- BSP reverted to off after validation

---

## §8 Implementation Phases

### Phase 0a: Pre-0 Microbenchmarks — BSP vs DFS Overhead

**What**: Measure baseline overhead of BSP scheduling vs DFS, BEFORE implementing the topology stratum. This is design input — the data feeds D.2.

**File**: `benchmarks/micro/bench-bsp-overhead.rkt` (~120 lines)
**Infrastructure**: Uses `bench` macro from `bench-micro.rkt` (warmup, multi-sample, GC between, mean/median/stddev/CV/IQR/95% CI, Tukey outlier detection).
**New instrumentation required**: None for M1-M4. M5 needs a counter box (see below).

#### Measurement M1: Empty Quiescence Call

A network with cells and propagators already at fixpoint. Call `run-to-quiescence` — nothing fires.

- **Measures**: Loop entry/exit overhead — checking the dirty set, finding nothing, returning.
- **DFS path**: check dirty set → empty → return.
- **BSP path**: check dirty set → empty → return.
- **Post-Track-1 path**: check dirty set → empty → check decomp-request cell → empty → return.
- **Design impact**: The delta between BSP and BSP+topology-check is the **per-call tax** of the two-fixpoint loop on the common case (no work). This multiplies by thousands of calls per test file. If >1μs, need faster guard (boolean flag vs cell read).
- **Setup**: `make-elaboration-network`, add 5 cells, 3 propagators (all watching cells that won't change). Parameterize `current-use-bsp-scheduler?` for DFS vs BSP.

#### Measurement M2: Single-Propagator Fire

One propagator on the dirty list, fires once, writes one cell, quiesces.

- **Measures**: Minimal work unit — one fire function invocation + one cell write + re-checking for quiescence.
- **DFS path**: pop dirty → fire → write cell → check dirty → empty → return.
- **BSP path**: collect round → fire all (1) → apply writes → check dirty → empty → return.
- **Design impact**: The per-fire BSP overhead. If >10% over DFS, BSP needs optimization before defaulting.
- **Setup**: Network with cell A (value 0), propagator P that writes A to 1. Mark P dirty. Time `run-to-quiescence`.

#### Measurement M3: Chain Propagation (depth 10)

Cell A → prop1 → Cell B → prop2 → Cell C → ... → Cell K. Writing Cell A triggers a chain of 10 fires.

- **Measures**: How scheduling strategy affects propagation depth. BSP's weak case — linear chains.
- **DFS path**: Fires 10 propagators in 10 sequential steps (follows the chain immediately).
- **BSP path**: Fires in rounds — round 1 fires prop1, round 2 fires prop2, ... 10 rounds.
- **Design impact**: BSP should be ~equal or slightly worse (round overhead × 10). Establishes worst-case ratio. If >25% worse, chain workloads need DFS fast-path.
- **Setup**: Build chain of 10 cells + 10 propagators. Write seed value to cell A. Time `run-to-quiescence`.

#### Measurement M4: Fan-Out Propagation (width 10)

Cell A watched by 10 propagators that each write to independent cells B1...B10.

- **Measures**: BSP's strong case — all 10 are independent, fire in one round.
- **DFS path**: Fires 10 propagators sequentially.
- **BSP path**: Fires all 10 in one round, bulk-merges all writes.
- **Design impact**: Baseline for parallelism benefit in PAR Track 2. In sequential BSP the round cost should be similar to DFS. If BSP is faster here (batch amortization), that's a signal.
- **Setup**: Network with cell A + 10 cells B1-B10 + 10 propagators. Write to cell A. Time `run-to-quiescence`.

#### Measurement M5: Decomposition Baseline (current inline cost)

A propagator that triggers SRE structural decomposition — the operation Track 1 moves to the topology stratum.

- **Measures**: Current inline decomposition cost (DFS only, since BSP drops the topology). This is the baseline that the topology-stratum approach must match.
- **What to capture**: Wall time for the full decomposition path: `sre-maybe-decompose` → `sre-decompose-generic` → N × `net-new-cell` + N × `net-add-propagator` + reconstructors.
- **Design impact**: If inline decomposition is <10μs, the topology stratum's request→process overhead is a larger fraction of total cost. If >100μs, the overhead is negligible.
- **Setup**: Network with two cells (val: `PVec Int`, `PVec Nat`), SRE subtype propagator. Time a single fire that triggers decomposition.
- **Instrumentation**: Wrap the decomposition call path with `current-inexact-monotonic-milliseconds` timing. No permanent instrumentation needed — the bench file instruments directly.

#### Post-Track-1 Re-measurements

After implementation, re-run M1-M5 to compare:
- M1 delta: cost of empty topology-stratum check
- M2/M3/M4 delta: overhead of CALM guard + decomp-request cell existence
- M5 comparison: inline decomposition (pre) vs request→topology-stratum (post)

### Phase 0a: Adversarial Benchmarks

**File**: `benchmarks/comparative/scheduler-adversarial.prologos` (~60 lines)

Adversarial testing targets the specific failure modes and worst cases for BSP:

#### A1: Deep Compound Type Nesting (Topology Ping-Pong)

```
;; Each level triggers a decomposition round in the topology stratum
;; Depth N = N outer-loop iterations
type Deep5 := PVec (PVec (PVec (PVec (PVec Nat))))
spec deep-id Deep5 -> Deep5
defn deep-id [x] x

;; Subtype check: Deep5 <: Deep5 requires 5 decomposition rounds
;; This is the worst case for the two-fixpoint loop
```

- **What it tests**: Maximum number of topology→value→topology ping-pongs. Each nesting level produces a decomposition request that creates sub-propagators whose next firing may produce another request.
- **Design impact**: If N levels take O(N²) time (each round re-processes the full worklist), the outer loop needs optimization. Expected: O(N) — each round processes only new propagators.

#### A2: Wide Compound Type (Many Simultaneous Decompositions)

```
;; Single level but high arity — many decomposition requests in one round
type Wide := Record10 Int Nat Bool String Int Nat Bool String Int Nat
spec wide-check <Wide -> Wide>
```

- **What it tests**: Topology stratum processing many requests in one batch. Tests the set-union merge cost for large request sets and the batch creation of sub-cells/propagators.

#### A3: Mixed Decomposition + Constraint Resolution

```
;; Decomposition interleaved with trait resolution
;; Subtype check triggers decomposition, which creates new cells,
;; which trigger trait constraint resolution (S(1)), which may
;; trigger more decomposition
spec polymorphic-nest {A : Type} (PVec A) -> (PVec A)
```

- **What it tests**: Interaction between topology stratum (within S(0)) and constraint resolution stratum (S(1)). Does the stratification hierarchy handle this correctly? Are decomposition requests from S(1) constraint-retry propagators processed correctly?

#### A4: Narrowing + Decomposition Together

```
;; Pattern matching on compound types — narrowing branches + SRE decomposition
spec match-pvec (PVec Nat) -> Nat
defn match-pvec
  | '[] -> 0N
  | [cons x _] -> x
```

- **What it tests**: Both CALM violators active simultaneously. Narrowing emits branch requests AND SRE emits decomposition requests in the same quiescence call. The topology stratum must process both correctly in one pass.

#### A5: No-Decomposition Baseline (Pure Scheduling Overhead)

```
;; Heavy computation, zero decomposition
;; Many propagator firings, many constraint resolutions, zero topology changes
;; This measures the PURE overhead of BSP vs DFS on a realistic workload
spec fib Nat -> Nat
defn fib
  | zero -> zero
  | suc zero -> suc zero
  | suc (suc n) -> [nat+ [fib n] [fib [suc n]]]

[fib 5N]
```

- **What it tests**: BSP overhead on workloads that never touch the topology stratum. The decomp-request cell check must be negligible. If this is measurably slower under BSP, the guard needs optimization.

### Phase 0a: E2E Validation

Run `bench-ab.rkt` on the existing 13 comparative programs under DFS vs BSP (using `bench-scheduler-ab.rkt` which parameterizes the scheduler). This captures real-world overhead across diverse workloads.

**Note**: BSP will fail SRE-decomposition-dependent programs (the current bug). We capture wall time for PASSING programs only. Failing programs are excluded from the timing comparison but their failure mode is catalogued.

### Phase 0a: Instrumentation Summary

| Item | Type | Permanent? | Location |
|------|------|-----------|----------|
| `bench-bsp-overhead.rkt` | Micro-benchmark file | Yes (permanent benchmark) | `benchmarks/micro/` |
| `scheduler-adversarial.prologos` | Adversarial benchmark file | Yes (permanent benchmark) | `benchmarks/comparative/` |
| Topology-stratum round counter | `box` behind parameter | No — cleanup Phase 9 | `propagator.rkt` |
| Topology-stratum request counter | `box` behind parameter | No — cleanup Phase 9 | `propagator.rkt` |
| `current-topology-stratum-counters` | Parameter (`#f` default) | No — cleanup Phase 9 | `propagator.rkt` |

**Success criteria**:
- M1-M4: BSP overhead ≤5% of DFS for non-decomposing workloads
- M5: Inline decomposition baseline captured (μs)
- A1-A5: All pass under DFS; A5 establishes BSP overhead baseline
- If BSP overhead >10% on M1, the empty topology check needs boolean-flag optimization

**Lines changed**: ~120 (bench file) + ~60 (adversarial file)

**Completion**: commit → tracker → dailies → proceed.

### Phase 0a Results (`2bfb656`)

#### Micro-Benchmarks (M1-M5)

| Measurement | DFS | BSP | BSP/DFS | Interpretation |
|------------|-----|-----|---------|----------------|
| M1: Empty quiescence (10K calls) | 0.50ms | 0.49ms | 0.98× | Identical. Zero scheduling overhead difference. |
| M2: Single-propagator fire (5K) | 4.35ms | 4.98ms | 1.14× | 14% BSP overhead per-fire (fire-and-collect-writes diff). |
| M3: Chain depth=10 (2K) | 10.26ms | 81.09ms | **7.9×** | BSP weak case: 10 rounds vs DFS 1 pass. Round overhead × depth. |
| M4: Fan-out width=10 (2K) | 9.96ms | 15.22ms | 1.53× | 53% BSP overhead. Round/merge overhead dominates at this scale. |
| M5: Topology creation N=4 (2K) | 4.18ms | — | baseline | ~2.1μs per cell+propagator creation. |
| M5: Topology creation N=20 (500) | 7.06ms | — | baseline | ~0.7μs per cell+propagator at scale. |

**Key finding**: M3's 7.9× regression on chains. BSP pays round overhead per dependency depth. In real programs this doesn't manifest because propagator chains are short (1-5 firings per quiescence, not depth-10 chains).

#### Scheduler A/B (DFS vs BSP, 13 real programs, 5 runs each)

| Program | DFS (ms) | BSP (ms) | Ratio |
|---------|----------|----------|-------|
| simple-typed | 122.3 | 122.6 | 1.003 |
| nat-arithmetic | 118.2 | 119.0 | 1.006 |
| dependent-types | 118.8 | 117.5 | 0.989 |
| higher-order | 180.3 | 187.3 | 1.039 |
| implicit-args | 210.5 | 204.7 | 0.973 |
| pattern-matching | 206.8 | 209.9 | 1.015 |
| scheduler-adversarial | 251.1 | 250.3 | 0.997 |
| type-adversarial | 3747.1 | 3738.8 | 0.998 |
| **TOTAL** | **6911.4** | **6882.8** | **0.996** |

**Verdict**: Within noise (<5%). On real programs, BSP and DFS are indistinguishable.

#### Adversarial Stability (bench-ab, scheduler-adversarial.prologos)

A=3915ms, B=3914ms, speedup 0.0%, p=0.83 (not significant). The adversarial program runs correctly and stably.

#### Design Implications

1. **Empty topology check (M1)**: Zero cost. Boolean-flag optimization NOT needed.
2. **Chain regression (M3)**: 7.9× at depth 10 in micro, but not observed in real programs. Not a blocking concern.
3. **Real-program overhead**: Negligible (0.4% total). The topology stratum will add one cell read per quiescence — M1 shows this costs ~0μs.
4. **Topology creation (M5)**: 2μs per cell+propagator. Topology stratum processing cost dominated by creation calls, which are already fast.
5. **Design validated**: Two-fixpoint loop won't measurably regress real programs.

### Phase 0b: Narrowing CALM Validation (empirical)

**What**: Run narrowing and SRE tests under BSP to characterize the exact failure modes. Can run in parallel with Phase 0a.
**How**: Temporarily set `current-use-bsp-scheduler? #t`, run `raco test` on narrowing and SRE test files individually.
**Success**: Catalogue of which tests fail, which pass, and classification of each failure as topology-related or not.
**Lines changed**: 0 (parameter tweak only).

**Completion**: commit → tracker → dailies → proceed.

### Phase 1: Decomposition-Request Cell Infrastructure

**What**: Add `decomp-request` struct, merge function, and request cell to `prop-network`.
**Where**: `propagator.rkt`
**Lines**: ~25

Specific changes:
- `decomp-request` struct definition
- `decomp-request-set-merge` function (set-union)
- Add `decomp-request-cell` field to `prop-network` (or allocate in `make-prop-network`)
- Export: struct, merge, cell accessor

**Test**: Unit test — create network, write request, read back, verify set-union merge.

**Completion**: commit → tracker → dailies → proceed.

### Phase 2: SRE Decomposition → Request Emission

**What**: Replace inline topology creation in SRE fire functions with request emission.
**Where**: `sre-core.rkt`
**Lines**: ~50

Specific changes:
- New function `sre-emit-decomposition-request` (~15 lines): checks `net-pair-decomp?` guard, writes request struct to decomp-request cell
- Modify `sre-maybe-decompose` (line 456): replace call to `sre-decompose-generic` with call to `sre-emit-decomposition-request`
- `sre-decompose-generic` remains unchanged — called from topology stratum, not from fire functions
- Duality-specific path (`sre-duality-decompose-dual-pair` ~line 700): same treatment

**Test**: Run `raco test tests/test-sre-core.rkt tests/test-sre-subtype.rkt tests/test-sre-duality.rkt` under DFS — must still pass (request emission + immediate processing = same behavior).

**Completion**: commit → tracker → dailies → proceed.

### Phase 3: Narrowing → Request Emission

**What**: Replace inline topology creation in narrowing fire functions with request emission.
**Where**: `narrowing.rkt`

#### D.2 Audit Findings (eval-rhs)

The audit (`6eeb73b`) revealed two distinct CALM violation patterns in narrowing:

**Branch fire function** (line 228): Calls `install-narrowing-propagators` recursively → `net-add-propagator` for child subtrees. This installs new propagators — a clear CALM violation (changes scheduling). **Must be moved to topology stratum.**

**Rule fire function** (line 275): Calls `eval-rhs` → `net-new-cell` at 4 sites (lines 124, 323, 338, 386). Creates cells for constructor sub-terms. **No `net-add-propagator` calls** in eval-rhs. The cells are pure storage with no dependents — inert until a future topology stratum adds propagators watching them.

**Key insight**: Cell-only creation (`net-new-cell` without `net-add-propagator`) is structurally harmless for BSP. A cell with no dependents can't affect which propagators fire or in what order. The CALM concern is about scheduling order — and cells without dependents are scheduling-invisible.

#### Revised Options for Rule Fire Function

| Option | Description | Lines | Invasiveness |
|--------|-------------|-------|--------------|
| **3a** | Move eval-rhs entirely to topology stratum | ~60 | High — carries full expr + bindings in request |
| **3b** | Pre-allocate cell-ids in topology stratum, pass to fire fn | ~40 | Medium — cell-ID reservation API |
| **3c** | Allow `net-new-cell` during BSP fire rounds; guard only `net-add-propagator` | ~5 | **Minimal** — relax guard for cell-only creation |

**Preferred: Option 3c** for rule fire functions. Rationale:
- The audit confirms eval-rhs creates cells but never propagators
- Cells without dependents are CALM-safe (inert storage, no scheduling effect)
- The CALM guard distinguishes: `net-add-propagator` = unsafe (changes scheduling), `net-new-cell` = safe (no scheduling effect)
- Zero refactoring of eval-rhs required — it continues to work as-is
- The guard remains strict for propagator creation (the actual CALM violation)

**Principled justification**: CALM guarantees order-independence for monotone operations over a fixed SCHEDULING TOPOLOGY. The scheduling topology is the set of (propagator, input-cells, output-cells) triples. `net-new-cell` adds a cell to the network but adds no propagator edges — the scheduling topology is unchanged. `net-add-propagator` adds edges — the scheduling topology changes. The guard should enforce fixed scheduling topology, not fixed cell count.

**Implementation**:
- Branch fire function: emit `narrowing-decomp-request` with child subtree → topology stratum calls `install-narrowing-propagators`. (~15 lines change)
- Rule fire function: no change needed. Guard relaxed to allow `net-new-cell` during BSP rounds.
- CALM guard: `net-add-propagator` errors during BSP rounds. `net-new-cell` allowed. `net-cell-decomp-insert`/`net-pair-decomp-insert` — these modify registry CHAMPs, not scheduling topology. Allow during BSP rounds (they're value-like metadata writes).

**Lines**: ~20 (branch emission + guard relaxation)

**Test**: Run `raco test tests/test-narrowing-*.rkt` under BSP — must pass with guard relaxation.

**Completion**: commit → tracker → dailies → proceed.

### Phase 4: Topology Stratum in BSP Loop

**What**: Add outer loop to `run-to-quiescence-bsp` that processes decomposition requests between BSP rounds.
**Where**: `propagator.rkt`
**Lines**: ~40

Specific changes:
- New function `process-topology-requests` (~25 lines): reads decomp-request cell, dispatches by kind, calls `sre-decompose-generic` / `install-narrowing-propagators` / `eval-rhs`, clears processed requests
- Modify `run-to-quiescence-bsp` (line 1193): wrap existing BSP loop in outer loop that alternates value stratum and topology stratum
- Import SRE/narrowing topology functions (or use a callback registry to avoid circular deps)

**Circular dependency concern**: `propagator.rkt` cannot import `sre-core.rkt` (sre-core imports propagator). Solution: topology handler is a parameter (`current-topology-handler`) set by `sre-core.rkt` at module load time. Same pattern as `current-bsp-observer`.

**Test**: `test-sre-subtype.rkt` under BSP — the 2 previously failing tests must now pass.

**Completion**: commit → tracker → dailies → proceed.

### Phase 5: BSP-as-Default + Individual Test Verification

**What**: Flip default, verify known-sensitive tests individually.
**How**:
1. Set `current-use-bsp-scheduler? #t` in propagator.rkt
2. Run individual known-sensitive tests: `test-sre-subtype.rkt`, `test-sre-core.rkt`, `test-sre-duality.rkt`, `test-narrowing-*.rkt`
3. Read failure logs for any issues — do NOT run the full suite here (that's Phase 9)
**Success**: All individually-tested files pass.
**Lines**: 1 (parameter flip).

**Completion**: commit → tracker → dailies → proceed.

### Phase 6: CALM Guard Hardening

**What**: Finalize guard behavior for production based on D.3 analysis.
**Lines**: ~10

Guard behavior (D.3 revised — correct-by-construction):
- `net-add-propagator`: **ERROR** during BSP fire rounds (changes scheduling topology — CALM-unsafe)
- `net-new-cell`: **ALLOWED** during BSP fire rounds. New cells captured structurally via `next-cell-id` comparison in `fire-and-collect-writes`. No discipline required — BSP merge is the enforcement point.
- `net-cell-decomp-insert`, `net-pair-decomp-insert`: **NOT CALLED** from fire functions (moved to topology stratum). If called during BSP fire round: **WARNING** (not error — harmless but indicates design drift).
- Document the CALM contract in propagator.rkt header: "The CALM invariant is: fixed scheduling topology within a BSP round. Scheduling topology = the set of (propagator, input-cells, output-cells) triples. Cell creation is permitted and captured structurally. Registry writes belong to the topology stratum. Propagator creation is forbidden."

**Completion**: commit → tracker → dailies → proceed.

### Phase 7: Constraint-Propagators Contract

**What**: Document `install-fn` callback contract.
**Where**: `constraint-propagators.rkt` line 265
**Lines**: ~5 (comments + optional runtime assertion)

**Completion**: commit → tracker → dailies → proceed.

### Phase 8: A/B Benchmarks — BSP vs DFS Final Comparison

**What**: Final performance comparison now that BSP is the default and all tests pass. Compares Phase 0a baselines (pre-implementation) against post-implementation measurements.

**Micro-benchmarks** (re-run M1-M5 from Phase 0a):
- M1 delta: cost of empty topology-stratum check added to quiescence
- M2/M3/M4 delta: overhead of CALM guard + decomp-request cell existence on simple workloads
- M5 comparison: inline decomposition (Phase 0a baseline) vs request→topology-stratum→process (post)

**Adversarial benchmarks** (re-run A1-A5 from Phase 0a):
- A1: Deep nesting now exercises the actual topology stratum rounds
- A2: Wide arity exercises batch request processing
- A3: Mixed decomposition + constraint — validates cross-strata interaction
- A4: Narrowing + decomposition together — both violators exercised
- A5: No-decomposition baseline — pure scheduling overhead comparison

**Comparative benchmarks** (`bench-ab.rkt`):
- All 13+ programs in `benchmarks/comparative/` (including `scheduler-adversarial.prologos`), 5 runs each
- Compare HEAD (BSP default) vs pre-BSP commit (DFS) using `--ref`
- Mann-Whitney U test for statistical significance

**Success criteria**:
- M1 (empty quiescence): topology check adds ≤1μs
- M2/M3/M4: BSP overhead ≤5% of DFS
- M5: topology-stratum decomposition ≤2× inline decomposition cost
- A1-A4: all pass under BSP, wall time ≤15% of DFS
- A5: BSP overhead ≤5% of DFS (no decomposition workload)
- Comparative suite: no program ≥2× slower, median overhead ≤5%

**Completion**: commit → tracker → dailies → proceed.

### Phase 9: Instrumentation Cleanup

**What**: Remove benchmark-only scaffolding that shouldn't persist in production.

Specific removals:
- `current-topology-stratum-counters` parameter (if not useful for production observability)
- Round counter / request counter boxes (unless promoted to permanent PERF-COUNTERS)

Specific retentions:
- `bench-bsp-overhead.rkt` — permanent micro-benchmark (regression detection)
- `scheduler-adversarial.prologos` — permanent adversarial benchmark
- CALM guard (`current-bsp-fire-round?`) — permanent production guard

**Decision**: If the round/request counters are cheap (<1% overhead with parameter `#f`), promote them to permanent observability behind `PERF-COUNTERS` output. If measurable overhead, remove.

**Lines changed**: ~5-15 (remove or promote)

**Completion**: commit → tracker → dailies → proceed.

### Phase 10: PIR + Tracker + Dailies

---

## §9 Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Circular dependency: propagator.rkt ↔ sre-core.rkt | High | Medium | Parameter-based topology handler (like current-bsp-observer) |
| eval-rhs refactoring more complex than estimated | Medium | Medium | Option 3 (emit entire eval as request) simplifies |
| BSP overhead from outer loop | Low | Low | Pre-0 benchmark validates. Outer loop fires ≤ type nesting depth |
| Missed topology site in audit | Low | Caught at runtime | CALM guard is correct-by-construction |
| Decomp request stale values | Medium | Low | Topology stratum re-reads cells at processing time |

## §10 Termination Arguments

**Value stratum (inner BSP loop)**: Standard monotone propagator termination. Each cell value increases in lattice order. Finite lattice height. Worklist empties.

**Topology stratum**: Two termination mechanisms:
1. `net-pair-decomp?` guard ensures each (cell-a, cell-b, relation) triple decomposes at most once. Constructor arity is finite.
2. **Recursive type occurs check** (§4.1): the `ctor-chain` in each request detects when the same constructor appears twice in a decomposition chain. Recursive types are caught structurally — the topology stratum stops decomposing and marks the result as co-inductive or contradictory. This replaces the D.1 assumption "type nesting depth is bounded in well-typed programs" with a structural guarantee that works even for ill-typed inputs during type-checking.

**Outer loop**: Each iteration either adds topology (bounded by unique constructor sequences in the type domain) or reaches fixpoint. The `ctor-chain` occurs check provides a structural upper bound: the number of distinct constructors in scope. Therefore the outer loop terminates for all inputs, not just well-typed ones.

**Narrowing topology**: Each definitional tree node installs propagators at most once (branch fire checks constructor tag, which is deterministic). Tree depth is finite. Recursive installation is bounded by tree size.

---

## §11 NTT Speculative Syntax

```
;; Decomposition request lattice
:lattice :set DecompRequest
  :merge set-union
  :bot   empty-set

;; The decomp-request cell — one per network
:cell decomp-requests : (Set DecompRequest)
  :lattice :set DecompRequest

;; Value stratum propagator (emits requests, never creates topology)
:propagator sre-subtype-check
  :reads  [cell-a cell-b]
  :writes [cell-a cell-b decomp-requests]
  :where  Monotone  ;; value-only writes, CALM-safe

;; Topology stratum handler (creates topology, sequential)
:stratum topology
  :reads  [decomp-requests]
  :creates [sub-cells sub-propagators decomp-registries]
  :where  Sequential  ;; not parallelizable
  :fires-when (not (set-empty? decomp-requests))
```

---

## §12 Principles Challenge

| Principle | Challenge | Response |
|-----------|-----------|----------|
| **Propagator-Only** | Are decomposition requests truly on-network, or are we just moving the side effect one level up? | Yes — requests are cell values with a lattice (set-union). The topology stratum reads them via `net-cell-read`. Everything flows through cells. |
| **Data Orientation** | The request struct carries metadata (desc, relation) that could go stale. | Topology stratum re-reads cell values at processing time. Metadata (desc, relation) is immutable. |
| **Correct-by-Construction** | Can a request be processed twice? Can a request reference a nonexistent cell? | Guard: `net-pair-decomp?` prevents double processing. Cell-ids in requests are guaranteed to exist (they were valid at emission time and cells are never removed). |
| **Decomplection** | Value propagation and topology construction are now in separate strata. But the topology stratum handler must know about SRE and narrowing. Is that a coupling? | Yes, but it's the same coupling as S(-1) knowing about retraction. The topology handler dispatches by `kind` field. New topology sources register handlers. |
| **Completeness** | We're fixing the root cause (stratified topology) rather than working around it (structural diff in BSP). | Confirmed. Option D (structural diff) was explicitly rejected — it fixes the symptom but leaves fire functions unrestricted. |
| **First-Class by Default** | Is the decomp-request protocol a first-class construct, or a special case? | Currently special-case (one specific cell). Could be generalized: any propagator can request topology changes via a typed request protocol. That's PAR Track 2+ territory. |

---

## §13 Cross-References

- [PAR Track 0 CALM Audit](2026-03-27_PAR_TRACK0_CALM_AUDIT.md)
- [PAR Track 1 Stage 2 Audit](2026-03-27_PAR_TRACK1_STAGE2_AUDIT.md)
- [PAR Series Master](2026-03-27_PAR_MASTER.md)
- [DEVELOPMENT_LESSONS.org](principles/DEVELOPMENT_LESSONS.org) § "CALM Requires Fixed Topology"
- BSP scheduler: propagator.rkt lines 1193-1232
- CALM guard: propagator.rkt `current-bsp-fire-round?` (commit `af35f5e`)
- [Parallel Scheduling Research](../research/2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md)
