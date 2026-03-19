# PUnify Part 2: Cell-Tree Unification Architecture

**Created**: 2026-03-19
**Status**: Design (pre-implementation)
**Parent**: Track 8 — Propagator Infrastructure Migration
**Part 1**: `2026-03-19_PUNIFY_STRUCTURAL_UNIFICATION_PROPAGATORS.org` (surface wiring + baselines)
**Audit**: `2026-03-18_TRACK8_PROPAGATOR_INFRASTRUCTURE_AUDIT.org`
**Master**: `2026-03-13_PROPAGATOR_MIGRATION_MASTER.md`

---

## 1. Purpose and Scope

PUnify Part 2 replaces the **algorithmic pattern-matching unifier** (`unify.rkt`) with
**cell-tree structures** on the propagator network. This is the first half of Track 8
(the second half migrates remaining imperative state: mult bridges, id-map, etc.).

**What changes**: The `classify-whnf-problem` dispatcher and its decomposition logic
become propagator operations on cell-trees rather than recursive Racket function calls.

**What doesn't change**: The 10 classification categories themselves, the three-valued
result semantics (#t / 'postponed / #f), the de Bruijn handling, and the solver-level
unification in `relations.rkt` (System 2 — flat substitution, independent of PUnify).

**Success criterion**: The type-adversarial benchmark (17.9s baseline) does not regress
by more than 10%. The full test suite (7214 tests, ~183s) stays green. Classification
distribution is unchanged (level 36%, flex-rigid 24%, pi 18%, ok 14%, binder 6%, sub 3%).

---

## 2. Current Architecture: How Unification Works Today

### 2.1 Entry Point: `unify-core` (unify.rkt)

```
unify-core(ctx, t1, t2)
  → perf-inc-unify!
  → pre-WHNF spine comparison (optimization: avoid WHNF for identical spines)
  → WHNF reduce both sides
  → classify-whnf-problem(t1', t2')
  → dispatch on classification tag
  → return #t | 'postponed | #f
```

Key: unify-core is **recursive**. Decomposition of Pi, Sigma, app, etc. generates
sub-goals that are solved by recursive calls to `unify-core`. There is no worklist;
the call stack IS the worklist.

### 2.2 The Classifier: `classify-whnf-problem` (lines 240-391)

Pure function. 10 output tags, ~150 lines of pattern matching:

| Tag | Trigger | Action in Dispatcher | % of Classifications |
|-----|---------|---------------------|---------------------|
| `ok` | Identical terms, wildcards, same-meta | Return #t | 14% |
| `conv` | Atom/neutral mismatch | `conv-nf` check | ~0% (rare) |
| `flex-rigid` | Bare unsolved meta vs concrete | `solve-flex-rigid` | 24% |
| `flex-app` | Applied meta (spine) | `solve-flex-app` → postpone | ~0% |
| `sub` | Rigid-rigid app decomposition | Recursive unify fn + arg | 3% |
| `pi` | Pi vs Pi | Recursive unify dom + open cod | 18% |
| `binder` | Sigma or Lambda | Recursive unify fst + open snd | 6% |
| `level` | Type₀ vs Type₁ | `unify-levels` | 36% |
| `union` | Union types | `unify-unions` | ~0% |
| `retry` | HKT normalization needed | Normalize → re-classify | ~0% |

**Critical observation**: 80% of unify calls (7,626 of 9,530) never reach the
classifier — they hit the fast-path (pre-WHNF spine comparison or identical-pointer
check). Only 1,904 calls reach `classify-whnf-problem`.

### 2.3 Decomposition (inline in dispatcher, lines 400-436)

Structural decomposition is NOT in separate functions — it's inline in the match
dispatcher. For each structural case:

**Pi** (lines 417-424):
```racket
(define x (expr-fvar (gensym 'unify)))
(and (unify-core ctx dom-a dom-b)                          ;; domain
     (unify-core ctx (open-expr (zonk-at-depth 1 cod-a) x)  ;; codomain
                     (open-expr (zonk-at-depth 1 cod-b) x)))
```

**Sigma/Lambda** (lines 427-433): Same pattern — unify first, open second with fresh fvar.

**App** (lines 323-327): Decompose `(expr-app f1 a1)` vs `(expr-app f2 a2)` into
`(unify f1 f2) ∧ (unify a1 a2)`.

### 2.4 State Mutation: `solve-meta!` (metavar-store.rkt:1523-1575)

When flex-rigid solves a meta:
1. Increment perf counter
2. Set progress signal (for stratified resolution wake-up)
3. Lookup meta-info from CHAMP
4. Immutably update meta-info status to 'solved
5. Write back to elab-network (or box fallback)
6. **Write solution to propagator cell** (line 1558-1562)
7. Post-write consistency validation
8. Mark as solved in unsolved-metas cell

Step 6 is the key bridge: solving a meta writes to the propagator network, which
can trigger downstream propagators (trait resolution, constraint wakeup, etc.).

### 2.5 Postponement (lines 589-612, 753-779)

`flex-app` (applied meta, e.g., `?F Nat` vs `Int → Bool`) can't be solved immediately.
The constraint is registered with `add-constraint!`, which:
1. Creates constraint cells on the propagator network
2. Installs readiness propagators (wake up when mentioned metas solve)
3. Runs quiescence — may solve immediately if downstream propagation provides info

If quiescence doesn't solve it, returns `'postponed`. The top-level `unify` wrapper
(line 753-779) has a second quiescence check before committing to 'postponed.

---

## 3. Gap Analysis: What Must Change

### 3.1 Recursive Call Stack → Propagator Worklist

**Current**: Decomposition creates sub-goals solved by recursive `unify-core` calls.
The Racket call stack is the implicit worklist.

**Problem**: This is inherently sequential. A Pi decomposition must complete domain
unification before starting codomain unification. No fan-in is possible.

**Target**: Sub-goals become cells on the propagator network. The worklist schedules
them. Fan-in: when both domain and codomain of Pi are constrained by different sources,
both propagate toward the same conclusion cell.

### 3.2 AST Terms → Cell-Trees

**Current**: Types are AST nodes (`expr-Pi`, `expr-app`, `expr-meta`, etc.). Unification
walks these trees with pattern matching.

**Problem**: A type mentioned in multiple places is a different AST node each time.
Solving a meta in one place doesn't automatically propagate to the other — zonk must
be called to substitute. There's no structural sharing.

**Target**: Types are trees of cells. A metavariable is a cell. When solved, all
references to that cell see the update immediately through the propagator network.
Zonk becomes "read the cell-tree" rather than "substitute all metas".

### 3.3 WHNF Before Classification

**Current**: Both sides are WHNF-reduced before classification. This is essential
for correctness (otherwise `(fn [x] x) Nat` wouldn't reduce to `Nat`).

**Gap**: In cell-tree world, when do we reduce? Options:
- **Eager**: Reduce when cell value is written → cell always holds WHNF
- **Lazy**: Reduce when cell is read for classification → delay work
- **Hybrid**: Reduce on write for small terms, lazy for large/expensive reductions

The current profiling shows WHNF reduction is part of the 10% unify time — not
separately measured. Need micro-benchmark data for WHNF cost.

### 3.4 Occurs Check → Cycle Detection

**Current**: `occurs-check-meta` (line 103-127 in unify.rkt) walks the AST to check
if meta `id` appears in `term`. Linear in term size.

**Target**: In cell-tree, cycle detection is checking if following cell pointers
creates a cycle. O(depth) with a visited set, potentially O(1) with cell identity.

### 3.5 The `fire` Function

**Current**: There is no explicit "fire" function in unify.rkt. The dispatcher IS the
fire function — it matches on classifications and recursively calls unify-core.

**Target**: The cell-tree fire function is a propagator: when a cell value changes,
wake up all propagators that depend on it. For structural decomposition, this means:
"when a Pi cell is constrained, decompose into domain-cell and codomain-cell and
propagate constraints to each."

### 3.6 Three-Valued Results in Propagator World

**Current**: `unify-core` returns #t / 'postponed / #f synchronously.

**Problem**: In propagator world, results are asynchronous — a cell might be
`type-bot` (unsolved) now but get constrained later.

**Target**: Unification becomes "connect two cell-trees" — the connection either:
- Succeeds immediately (both sides fully known, compatible)
- Succeeds partially (some sub-cells constrained, others pending)
- Fails immediately (contradiction detected)
- Fails later (contradiction detected after propagation)

The `'postponed` result maps to "registered propagators, waiting for more info."

### 3.7 `meta-info` / `id-map` Not TMS-Aware

**From Track 8 audit**: `meta-info` and `id-map` in `elab-network` are CHAMP maps
but NOT tracked by TMS. This means `restore-meta-state!` can't retract meta solutions
made during speculation.

**Implication for PUnify**: If cell-trees store meta solutions as cell values (which
they should), and cells ARE TMS-tracked (Track 4 established this), then migrating
meta solutions from CHAMP to cells automatically gets TMS retraction. This is a
qualitative win — one of the architectural motivations.

### 3.8 Callback Elimination

**From Track 8 audit**: 6+ callback parameters (`current-prop-cell-write`,
`current-prop-cell-read`, `current-prop-has-contradiction?`, etc.) bridge between
unify.rkt and the propagator network. These are an indirection layer that adds
complexity and prevents the type checker from being a direct propagator participant.

**Target**: Cell-tree operations are native propagator operations — no callbacks needed.

---

## 4. Design Options

### Option A: Thin Wrapper — Propagator Shell Around Existing Unifier

**Approach**: Keep `classify-whnf-problem` and the dispatcher largely intact.
Wrap each `unify-core` call in a propagator that reads input cells, runs the
existing algorithm, and writes results to output cells.

**Pros**: Minimal code change. Low risk. Easy to A/B test.
**Cons**: Doesn't achieve structural sharing. Doesn't eliminate callbacks.
Doesn't enable fan-in. Essentially just adds overhead.

**Verdict**: Insufficient. This adds propagator ceremony without the benefits.

### Option B: Full Cell-Tree — Types Are Trees of Cells From Construction

**Approach**: When the elaborator creates a type (e.g., Pi(Nat, ?A → Bool)),
it creates a tree of cells: a Pi-cell with domain-cell (holding Nat) and
codomain-cell (holding ?A → Bool, itself a Pi-cell). Metavariables ARE cells
(already true — `elab-fresh-meta` creates a cell). Unification connects
cell-trees by adding propagators between corresponding nodes.

**Pros**: Full structural sharing. Native fan-in. Clean architecture.
**Cons**: High risk — touches every type construction site. Cell allocation
explosion potential. Complex migration.

**Verdict**: The target architecture, but needs a migration strategy.

### Option C: Lazy Cell-Tree — On-Demand Decomposition (RECOMMENDED)

**Approach**: Types start as AST nodes (status quo). When unification FIRST
needs to decompose a compound type, it creates sub-cells on demand using the
existing `get-or-create-sub-cells` pattern from `elaborator-network.rkt`.
Subsequent unifications of the same type reuse cached sub-cells.

**Key insight**: The `get-or-create-sub-cells` + decomposition registry pattern
(elaborator-network.rkt:407-444) ALREADY exists for exactly this purpose. PUnify
extends it from a utility to the primary unification mechanism.

**Pros**:
- Incremental migration — types don't need to change representation upfront
- On-demand allocation — cells only created when actually needed for unification
- Registry dedup — `cell-decomps` and `pair-decomps` prevent redundant creation
- Meta reuse — `current-structural-meta-lookup` already maps metas to cells
- Low initial overhead — 80% of unify calls hit fast-path and never create cells
- Compatible with existing TMS infrastructure (cells are TMS-tracked)
- Natural fit for the existing two-network architecture

**Cons**:
- Doesn't achieve "types are cells from birth" (that's a later migration)
- Still has AST→cell conversion cost on first decomposition
- Decomposition registry must survive across commands for cross-command types

**Verdict**: Best risk/reward ratio. Uses proven patterns. Incremental.

### Option D: Hybrid — Eager for Metas, Lazy for Structure

**Approach**: Metavariables are cells from creation (already true). Compound
types get cell-trees only on first unification (Option C). But when a meta is
solved to a compound type, eagerly decompose it into a cell-tree.

**Pros**: Combines eager propagation for metas with lazy allocation for structure.
**Cons**: Two code paths. Complexity.

**Verdict**: Option C naturally evolves into this — solve-meta! writes to cell,
propagator fires, decomposes if needed. No separate "eager" path required.

---

## 5. Recommended Design: Lazy Cell-Tree with On-Demand Decomposition

### 5.1 Core Principle: Cells Created at Point of Need

Following the existing `get-or-create-sub-cells` pattern:

```
unify(cell-a, cell-b):
  val-a = cell-read(cell-a)   ;; may be type-bot (unsolved meta) or AST
  val-b = cell-read(cell-b)   ;; may be type-bot (unsolved meta) or AST

  classify(val-a, val-b):
    ok       → return #t
    conv     → return #f
    flex-rigid(meta-cell, concrete) →
      cell-write(meta-cell, concrete)  ;; solve meta
      ;; propagator network fires downstream
    pi(dom-a, cod-a, dom-b, cod-b) →
      (dom-cell-a, cod-cell-a) = get-or-create-sub-cells(cell-a, 'pi, [dom-a, cod-a])
      (dom-cell-b, cod-cell-b) = get-or-create-sub-cells(cell-b, 'pi, [dom-b, cod-b])
      add-unify-propagator(dom-cell-a, dom-cell-b)   ;; domain constraint
      add-unify-propagator(cod-cell-a, cod-cell-b)   ;; codomain constraint
    ...
```

### 5.2 On-Demand Creation Strategy (Answering Q1)

**Q1**: "We have other patterns on our propagator architecture that efficiently
use on-demand creation... we should investigate how that would fit this design."

**Answer**: The existing on-demand patterns map directly:

| Existing Pattern | Location | PUnify Analog |
|-----------------|----------|---------------|
| `get-or-create-sub-cells` | elaborator-network.rkt:407-444 | Pi/Sigma/App decomposition |
| `identify-sub-cell` with meta lookup | elaborator-network.rkt:407-422 | Meta cells reused across decompositions |
| `cell-decomps` registry | prop-network struct | Cache: "has this cell been decomposed?" |
| `pair-decomps` registry | prop-network struct | Cache: "have these two cells been unified?" |
| Session continuation cells | session-propagators.rkt:107-144 | Codomain cells (opened under binder) |
| `elab-fresh-meta` (starts at type-bot) | elaborator-network.rkt:156 | Unsolved meta = cell at bottom |

**The lifecycle of a cell-tree node**:

```
1. BIRTH: Type created as AST node (no cells yet)
   Pi(Nat, ?A → Bool) is just an expr-Pi struct

2. FIRST UNIFICATION: Cell-tree created on demand
   unify(Pi(Nat, ?A→Bool), Pi(?B, Int→Bool))
   → get-or-create-sub-cells(cell-for-pi-1, 'pi, [Nat, ?A→Bool])
     → dom-cell-1 = new cell(Nat)       ← only if not already decomposed
     → cod-cell-1 = new cell(?A→Bool)   ← only if not already decomposed
   → get-or-create-sub-cells(cell-for-pi-2, 'pi, [?B, Int→Bool])
     → dom-cell-2 = cell-for-meta-?B    ← REUSE existing meta cell!
     → cod-cell-2 = new cell(Int→Bool)

3. PROPAGATION: Sub-cell unification as propagators
   → unify-propagator(dom-cell-1, dom-cell-2)  → writes Nat to ?B's cell
   → unify-propagator(cod-cell-1, cod-cell-2)  → recursive decomposition

4. SUBSEQUENT UNIFICATION: Reuse cached decomposition
   unify(Pi(Nat, ?A→Bool), Pi(Nat, ?C→Bool))
   → get-or-create-sub-cells(cell-for-pi-1, 'pi, ...)
     → CACHE HIT: returns same dom-cell-1, cod-cell-1
   → new sub-cells only for the second operand
```

**Why this prevents cell explosion**:

The `cell-decomps` registry ensures each compound type is decomposed AT MOST ONCE.
The `pair-decomps` registry ensures each pair of types is unified AT MOST ONCE.
The `identify-sub-cell` meta-lookup ensures shared metas use ONE cell, not N copies.

**Profiling prediction**: With 1,904 classifications and distribution:
- level (36%): ~686 → NO cells created (level unification is numeric, not structural)
- ok (14%): ~267 → NO cells created (already equal)
- flex-rigid (24%): ~457 → 0-1 cells per (meta cell already exists; may decompose RHS)
- pi (18%): ~343 → 2-4 cells per (domain + codomain sub-cells, cached)
- binder (6%): ~114 → 2-4 cells per (same as pi)
- sub (3%): ~57 → 2 cells per (fn + arg sub-cells)

**Estimated new cells per command**: ~1,000-2,000 for the acceptance file (163 commands).
Current cell allocation is ~13,000 total (from perf counters). This adds ~10-15%.

### 5.3 The Fire Function: Unify-Propagator

The central propagator created by PUnify:

```
unify-propagator(cell-a, cell-b):
  watched: [cell-a, cell-b]
  fire(net):
    val-a = read(cell-a)
    val-b = read(cell-b)
    if val-a = type-bot or val-b = type-bot:
      return net  ;; nothing to do yet — wait for more info
    classification = classify-whnf-problem(whnf(val-a), whnf(val-b))
    match classification:
      ok → net  ;; compatible, nothing to propagate
      conv → contradiction!
      flex-rigid(meta-cell, rhs) →
        write(meta-cell, rhs)  ;; may wake other unify-propagators
      pi(...) →
        ;; decompose + add new unify-propagators for sub-goals
        ...
      level(l1, l2) →
        unify-levels(l1, l2)  ;; stays imperative — no cell-tree benefit
      ...
```

**Key difference from current**: Instead of recursive `unify-core` calls, decomposition
adds NEW propagators to the network. The worklist schedules them. This enables:
- **Fan-in**: Two independent constraints on the same meta both write to it
- **Incremental**: Partial solutions propagate immediately
- **Retractable**: TMS can retract cell values during speculation

### 5.4 Handling De Bruijn Indices Under Binders

**Current approach** (works, preserve):
```racket
(define x (expr-fvar (gensym 'unify)))
(unify-core ctx (open-expr (zonk-at-depth 1 cod-a) x)
                (open-expr (zonk-at-depth 1 cod-b) x))
```

**Cell-tree approach**: When decomposing Pi/Sigma into sub-cells, the codomain
sub-cell holds the OPENED body (substituted with fresh fvar). This means:
- Each decomposition of a binder type creates a fresh fvar
- The codomain sub-cell value is `(open-expr (zonk-at-depth 1 cod) x)`
- Two decompositions of the same Pi MUST use the same fvar (registry ensures this)

This is a subtle invariant: the `cell-decomps` registry returns the same sub-cells
(with the same fvar substitution) on cache hit. Correctness depends on this.

### 5.5 Interaction with Existing Infrastructure

**TMS/Speculation**: Cell-tree nodes are regular TMS cells → speculation works.
When `save-meta-state` snapshots, cell-tree state is included. `restore-meta-state!`
retracts cell writes. This is a qualitative improvement: currently, meta-info is NOT
TMS-tracked (audit finding), so speculation can't cleanly retract meta solutions.

**Stratified Resolution**: The `progress-signal` cell (Track 2) continues to work.
When `solve-meta!` writes to a cell, the resolution stratum advances. PUnify just
changes HOW the write happens (from direct callback to propagator fire).

**Constraint System**: Existing `add-constraint!` (for flex-app postponement) already
creates constraint cells. PUnify's unify-propagator replaces the manual constraint
registration with a native propagator that does the same thing automatically.

**Registry Cells**: Persistent registry network (Track 3/7) is unaffected. PUnify
operates on the per-command elab-network only.

---

## 6. Implementation Phases

### Phase 1: Unify-Propagator Infrastructure

**What**: Create the `unify-propagator` function signature, the `pair-decomps`
dedup check for unification pairs, and the dispatch-to-propagator bridge.

**Files**: `unify.rkt`, `elaborator-network.rkt`

**Approach**: Add a `current-punify-enabled?` parameter (default #f). When enabled,
`unify-core` delegates to `unify-via-propagator`. When disabled, existing code runs.
This is the A/B toggle for regression testing.

**Test**: All 7214 tests pass with toggle OFF. Toggle ON + run a small subset.

### Phase 2: flex-rigid as Cell Write

**What**: Replace `solve-flex-rigid` → `solve-meta!` with `cell-write` to the
meta's existing propagator cell. Remove the callback indirection.

**Why first**: flex-rigid is 24% of classifications, the simplest structural case
(no decomposition needed), and `solve-meta!` already writes to a cell (line 1558).
This is mostly removing indirection.

**Test**: flex-rigid micro-benchmarks. Type-adversarial baseline.

### Phase 3: Pi Decomposition as Sub-Cells

**What**: For `pi` classification (18%), use `get-or-create-sub-cells` to create
domain and codomain sub-cells. Add `unify-propagator` for each sub-goal pair.

**Key**: This is where the recursive `unify-core` calls become propagator additions.
The domain and codomain sub-goals are scheduled on the worklist, not the call stack.

**Test**: Pi decomposition micro-benchmarks (bench-type-unify.rkt: pi-d5, pi-d10, pi-d20).

### Phase 4: Sigma/Lambda Decomposition

**What**: Same pattern as Phase 3 for `binder` classification (6%).

**Test**: Binder micro-benchmarks.

### Phase 5: App Decomposition (rigid-rigid)

**What**: For `sub` classification (3%), decompose app into fn-cell + arg-cell.

**Test**: App decomposition micro-benchmarks.

### Phase 6: Fast-Path Preservation

**What**: Ensure the 80% fast-path (pre-WHNF spine comparison, identical-pointer)
still bypasses the propagator machinery entirely. Cell-tree overhead must be zero
for cases that don't need it.

**Test**: ok-classification micro-benchmarks. Full suite timing.

### Phase 7: Callback Elimination

**What**: Remove `current-prop-cell-write`, `current-prop-cell-read`,
`current-prop-has-contradiction?` callbacks. Replace with direct cell operations.

**Depends**: Phases 2-5 complete (all decomposition paths use cells).

### Phase 8: Occurs Check as Cycle Detection

**What**: Replace AST-walking `occurs-check-meta` with cell-tree cycle detection.

**Test**: Occurs check micro-benchmarks.

### Phase 9: Zonk Simplification

**What**: Final zonk becomes "read cell-tree, return value." Intermediate zonk
reads cell values (may be type-bot for unsolved metas).

**Test**: Zonk micro-benchmarks (bench-type-unify.rkt: zonk-d10, zonk-d20).

---

## 7. What PUnify Does NOT Change

- **Level unification** (36% of classifications): Numeric lattice operations.
  No cell-tree benefit. Stays imperative.
- **Union unification**: Rare (~0%). Low priority.
- **HKT normalization** (retry): Rare. Stays as preprocessing.
- **Solver unification** (relations.rkt): System 2, flat substitution. Independent.
- **WHNF reduction**: Still called before classification. Unchanged.
- **De Bruijn infrastructure**: `zonk-at-depth`, `open-expr`, `subst` — preserved.

---

## 8. Performance Budget

| Metric | Baseline | Target | Hard Limit |
|--------|----------|--------|------------|
| Type-adversarial | 17.9s | ≤19.7s (10%) | ≤21.5s (20%) |
| Full suite | 183s | ≤200s (10%) | ≤220s (20%) |
| Cell allocation/cmd | ~82 | ≤100 | ≤120 |
| Unify wall time % | 10% | ≤12% | ≤15% |

**Per-phase budget**: Each phase must not regress type-adversarial by more than 2%.
Cumulative budget is 10%. If Phase N exceeds 2%, investigate before Phase N+1.

**Measurement**: `bench-ab.rkt --runs 10 --ref HEAD~1` after each phase.
`profile-unify.rkt` for classification distribution stability.

---

## 9. Risk Analysis

### HIGH: Cell Allocation Overhead

**Risk**: Creating sub-cells for every Pi decomposition adds allocation pressure.
With ~343 pi classifications per acceptance file run, that's ~700-1400 new cells.

**Mitigation**:
- `cell-decomps` registry prevents redundant creation (existing pattern)
- `pair-decomps` prevents redundant unification (existing pattern)
- Meta reuse via `current-structural-meta-lookup` (existing pattern)
- Fast-path (80% of calls) creates zero cells

**Detection**: Per-command cell allocation counter (`perf-inc-cell-alloc!`).

### MEDIUM: De Bruijn Correctness Under Decomposition Caching

**Risk**: Two decompositions of the same Pi must return the same opened codomain
with the same fresh fvar. If the registry cache returns stale or inconsistent
sub-cells, type checking breaks silently.

**Mitigation**: The existing `cell-decomps` registry (elaborator-network.rkt:428-433)
already handles this correctly — cache hit returns identical sub-cells. Add
assertions that decomposition is idempotent (same tag, same sub-cell count).

### MEDIUM: Propagator Ordering vs Call Stack Ordering

**Risk**: Current unification has deterministic ordering (domain before codomain,
left before right). Propagator worklist ordering is different. Some code may
depend on the specific order of meta solutions.

**Mitigation**: The stratified quiescence (Track 2) provides deterministic ordering
guarantees. But specific intra-stratum ordering may differ. Need careful testing.

**Detection**: Classification distribution must be unchanged after each phase.

### LOW: Speculation Interaction

**Risk**: `save-meta-state!` / `restore-meta-state!` currently snapshots CHAMP state.
Cell-tree state is on the propagator network, which has TMS-based retraction.

**Mitigation**: Track 4 already established TMS retraction for per-meta cells.
PUnify's cell-tree nodes use the same TMS infrastructure.

### LOW: Error Message Regression

**Risk**: Error messages currently reference AST positions. Cell-tree indirection
could make error provenance harder.

**Mitigation**: Cell-info metadata tracks source locations. Phase 7 (callback
elimination) is where error reporting changes most — test error messages explicitly.

---

## 10. Open Questions

### Q1: WHNF Timing — RESOLVED (lazy, at read time)

Reduce to WHNF when the unify-propagator fires and reads cell values, not when
values are written. This matches the current behavior (reduce before classify)
and avoids unnecessary reduction of values that are never unified.

### Q2: Cross-Command Cell Persistence

Should cell-trees survive across commands (like registry cells) or be per-command?

**Recommendation**: Per-command. Types are elaborated fresh each command. The
persistent registry network holds macro/warning cells; the elab-network (which
holds cell-trees) is reset per command (`reset-elab-network-command-state`).

### Q3: Decomposition Depth Limit

Should there be a limit on cell-tree depth? Current max recursive depth is 5
(from profiling). But pathological cases could be deeper.

**Recommendation**: No limit initially. The existing fuel mechanism in prop-network
provides a safety net. Monitor max depth in profiling.

### Q4: `pair-decomps` Symmetry

`unify(A, B)` and `unify(B, A)` should not create duplicate propagators. The
`pair-decomps` registry should be order-insensitive.

**Recommendation**: Key on `(min(id-a, id-b), max(id-a, id-b))` for canonical ordering.

---

## 11. Dependencies and Enabling

**Depends on**:
- Track 7 (complete): Persistent registry network, two-network architecture
- Part 1 (complete): Baselines, profiling infrastructure, acceptance file

**Does NOT depend on**:
- Track 8 second half (mult bridges, id-map migration)
- Track 9 (GDE)
- Track 10 (LSP)

**Enables**:
- Track 8 second half: Once unification is cell-native, mult/level/session
  migration follows the same pattern
- Track 9 (GDE): Cell-tree provenance is the foundation for diagnostic explanations
- Retirement of `restore-meta-state!`: TMS-tracked meta solutions via cells replaces
  the manual CHAMP snapshot/restore

---

## 12. Key Files

| File | Role in PUnify |
|------|---------------|
| `unify.rkt` | Primary target — classifier + dispatcher + fire function |
| `elaborator-network.rkt` | `get-or-create-sub-cells`, decomposition registry, cell creation |
| `metavar-store.rkt` | `solve-meta!`, meta-info management, callback parameters |
| `propagator.rkt` | `net-new-cell`, `net-add-propagator`, worklist, quiescence |
| `performance-counters.rkt` | `unify-profile` instrumentation |
| `tools/profile-unify.rkt` | Classification distribution monitoring |
| `tools/bench-ab.rkt` | A/B regression testing |
| `benchmarks/micro/bench-type-unify.rkt` | Per-operation micro-benchmarks |
| `benchmarks/comparative/type-adversarial.prologos` | End-to-end benchmark (17.9s baseline) |
| `examples/2026-03-19-punify-acceptance.prologos` | Acceptance file (169 cmds, 0 errors) |
