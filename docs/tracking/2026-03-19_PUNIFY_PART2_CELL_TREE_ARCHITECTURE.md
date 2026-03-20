# PUnify Part 2: Cell-Tree Unification Architecture

**Created**: 2026-03-19
**Status**: Design (pre-implementation)
**Parent**: Track 8 — Propagator Infrastructure Migration
**Part 1**: `2026-03-19_PUNIFY_STRUCTURAL_UNIFICATION_PROPAGATORS.org` (surface wiring + baselines)
**Audit**: `2026-03-18_TRACK8_PROPAGATOR_INFRASTRUCTURE_AUDIT.org`
**Master**: `2026-03-13_PROPAGATOR_MIGRATION_MASTER.md`

---

## 1. Purpose and Scope

PUnify Part 2 replaces **both unification systems** with **cell-tree structures** on
the propagator network, using a shared domain-agnostic constructor descriptor registry.
This is the first half of Track 8 (the second half migrates remaining imperative
state: mult bridges, id-map, etc.).

**Two systems, one infrastructure**:
- **System 1** (type-level, `unify.rkt`): 37-case classifier, propagator-integrated,
  handles metas, de Bruijn, compound types → cell-tree with type constructor descriptors
- **System 2** (solver-level, `relations.rkt`): 5-case flat substitution, DFS
  backtracking → cell-tree with data constructor descriptors, DFS search retained

**What changes**:
- System 1: `classify-whnf-problem` dispatcher and decomposition logic become
  propagator operations on cell-trees via type constructor descriptors
- System 2: `unify-terms` (15 lines, 5 cases) migrates to cell-tree operations
  via data constructor descriptors; DFS backtracking and `solve-goals` preserved
- Both systems share the same `ctor-registry.rkt` and generic decompose/reconstruct

**What doesn't change**: The 10 type-level classification categories, the three-valued
result semantics, de Bruijn handling, DFS search strategy in the solver, WHNF reduction,
and level unification (numeric lattice, not tree-structured).

**Why both systems**: Part 1 benchmarking revealed that the adversarial benchmarks
stress System 2, while the original Part 2 design targeted System 1. This
benchmark/architecture disconnect is resolved by scoping both systems into Part 2 —
the descriptor registry validates its genericity by serving two domains, and our
benchmarks now measure what our architecture changes.

**Success criteria**:
- Type-adversarial benchmark (17.9s baseline) does not regress by more than 10%
- Solve-adversarial benchmark (14.3s baseline) does not regress by more than 10%
- Full test suite (7214 tests, ~183s) stays green
- Type-level classification distribution unchanged
- Solver-level: prelude constructor unification works in `defr` contexts (currently broken)

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

### 2.4 State Mutation: `solve-meta!` (metavar-store.rkt:1501-1575)

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

**Current**: `occurs?` (unify.rkt:109-120) walks the AST to check if meta `id`
appears in `term`. Linear in term size.

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

### 2.6 System 2: Solver-Level Unification (`relations.rkt`)

The solver uses a completely separate, simpler unification system:

**`unify-terms`** (relations.rkt:434-449): 5-case flat substitution unifier:
```
unify-terms(t1, t2, subst):
  t1' = walk(t1, subst)    ;; follow substitution chains
  t2' = walk(t2, subst)
  cond:
    equal?(t1', t2') → subst            ;; identical after walk
    symbol?(t1')     → extend(subst, t1', t2')  ;; bind logic var
    symbol?(t2')     → extend(subst, t2', t1')  ;; bind logic var
    (list? t1') ∧ (list? t2') →
      foldl unify-terms over zip(t1', t2')       ;; structural recursion on lists
    else → #f                                     ;; failure
```

**`walk`** (lines 415-422): Substitution chain following with `eq?` cycle detection.
**`walk*`** (lines 425-430): Deep resolution — walks all sub-terms for output.
**`normalize-term-deep`** (lines 255-274): AST → solver term bridge. Converts
Prologos AST to flat list/symbol representation for the solver.

**Key differences from System 1**:
- No occurs check (can create infinite terms silently)
- No compound type decomposition beyond flat lists (prelude constructors fail)
- No constraint postponement — unification either succeeds now or fails
- No interaction with the propagator network — pure substitution map
- No de Bruijn indices — solver terms use named symbols
- DFS backtracking via `solve-goals`/`solve-single-goal` (not propagator worklist)

**`solve-goals`** (lines 458-467): Conjunction solver — folds goals left-to-right,
threading substitution. **`solve-app-goal`** (lines 683-751): Relation lookup with
fresh variable renaming (α-renaming per clause attempt).

---

### 3.8 Callback Elimination

**From Track 8 audit**: 6+ callback parameters (`current-prop-cell-write`,
`current-prop-cell-read`, `current-prop-has-contradiction?`, etc.) bridge between
unify.rkt and the propagator network. These are an indirection layer that adds
complexity and prevents the type checker from being a direct propagator participant.

**Target**: Cell-tree operations are native propagator operations — no callbacks needed.

### 3.9 System 2: No Occurs Check

**Current**: `unify-terms` blindly extends the substitution without checking if the
variable being bound appears in the term. `(unify X (cons 1 X) {})` silently creates
an infinite substitution chain. `walk*` may loop or produce garbage.

**Target**: Cell-tree unification gets occurs check for free — cycle detection is
checking cell-pointer reachability (§3.4). Data constructor cells share this mechanism.

### 3.10 System 2: No Compound Type Decomposition

**Current**: `unify-terms` only decomposes flat lists (Racket `list?`). Prologos data
constructors like `(some 42)`, `(cons 1 (cons 2 nil))`, `(pair "a" 3)` are normalized
to list representation by `normalize-term-deep`, but compound types with nested structure
beyond flat lists fail. Prelude constructor unification in `defr` contexts is broken.

**Target**: Data constructor descriptors enable structural decomposition of any registered
constructor — `(some X)` decomposes into a `some`-tagged cell with one sub-cell.
The same generic decompose/reconstruct from §5.6.3 handles both systems.

### 3.11 System 2: No Constraint Postponement

**Current**: `unify-terms` either succeeds or fails immediately. There is no analog to
`flex-app` postponement — if a logic variable hasn't been bound yet and the other side
is a compound term, the solver must bind eagerly (losing the constraint relationship).

**Target**: Cell-tree unification naturally supports partial information — a logic variable
is a cell at `⊥`. When the other side is a compound term, decomposition creates sub-cells
and installs propagators. The constraint is live on the network and fires when the variable
is eventually bound. This enables constraint-logic-programming patterns within `defr`.

### 3.12 System 2: AST→Solver Term Bridge Fragility

**Current**: `normalize-term-deep` (relations.rkt:255-274) converts Prologos AST to flat
list/symbol solver terms. `solver-term->prologos-expr` and `ground->prologos-expr` convert
back. These bridges are fragile — new AST node types require manual extension in both
directions, and mismatches produce opaque runtime errors.

**Target**: Data constructor descriptors provide the same `extract-fn`/`reconstruct-fn`
interface for both directions. The bridge becomes: decompose AST via descriptor → create
cells → reconstruct AST via descriptor. No separate normalize/denormalize functions needed.

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
(elaborator-network.rkt:428-444) ALREADY exists for exactly this purpose. PUnify
extends it from a utility to the primary unification mechanism.

**Refinement**: Option C is further refined with a **lattice-first architecture**
(§5.6) — a type constructor descriptor registry that formalizes the recursive
sum-of-products structure, providing generic decomposition/reconstruction and
compositional monotonicity guarantees. This is a design discipline over Option C's
mechanics, not a different option — the runtime operations are identical.

**Pros**:
- Incremental migration — types don't need to change representation upfront
- On-demand allocation — cells only created when actually needed for unification
- Registry dedup — `cell-decomps` and `pair-decomps` prevent redundant creation
- Meta reuse — `current-structural-meta-lookup` already maps metas to cells
- Low initial overhead — 80% of unify calls hit fast-path and never create cells
- Compatible with existing TMS infrastructure (cells are TMS-tracked)
- Natural fit for the existing two-network architecture
- Lattice-first framing gives compositional correctness and design vocabulary

**Cons**:
- Doesn't achieve "types are cells from birth" (that's a later migration)
- Still has AST→cell conversion cost on first decomposition
- Decomposition registry must survive across commands for cross-command types

**Verdict**: Best risk/reward ratio. Uses proven patterns. Incremental. Lattice
framing aligns with propagator-first principles and enables compositional reasoning.

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
| `get-or-create-sub-cells` | elaborator-network.rkt:428-444 | Pi/Sigma/App decomposition |
| `identify-sub-cell` with meta lookup | elaborator-network.rkt:407-426 | Meta cells reused across decompositions |
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

### 5.4 Termination Argument

Per DESIGN_METHODOLOGY.md §3 ("State termination arguments for propagator-hosted
computation"), any design adding propagators must include explicit termination
arguments with guarantee levels per GÖDEL_COMPLETENESS.md.

**`unify-propagator` termination: Level 1 (Tarski fixpoint)**

Each `unify-propagator` watches two cells and fires when either changes. On each
firing, it reads both cell values, classifies, and either:
- Does nothing (ok, both-⊥) — net unchanged, no new firings
- Writes to a meta-cell (flex-rigid) — the meta cell moves from ⊥ toward a concrete
  value on the type lattice. Monotone: metas never un-solve.
- Creates sub-cells and adds new unify-propagators (pi, binder, sub) — this is the
  recursive case.

**Why the recursive case terminates**: Each decomposition step reduces the **AST depth**
of the cell values being unified. Pi decomposition produces domain and codomain, each
strictly smaller than the Pi term. App decomposition produces func and arg, each
strictly smaller than the App. Since AST depth is a natural number, this well-founded
measure decreases at each decomposition step. At depth 0, values are atoms or metas —
no further decomposition is possible. The maximum observed recursive depth is 5 (from
profiling); pathological types could be deeper but are always finite (no infinite types
in the system — checked by `occurs?`).

**Why the meta-write case terminates**: The type lattice is finite for any given
unification problem (finite number of metas, finite number of type constructors in
scope). Each meta-cell transition (⊥ → concrete value) is monotone and irreversible.
The number of metas is bounded (448 created per acceptance run, from profiling).
Therefore, at most 448 flex-rigid firings can occur before all metas are solved.
Each solving may wake downstream propagators, but those propagators either:
(a) classify as `ok` (no further work), or (b) decompose (depth decreases), or
(c) solve another meta (bounded count decreases). The product of
`(metas remaining × max depth)` is a well-founded measure that decreases on every
non-trivial firing.

**Level and union cases**: Level unification stays imperative (not a propagator).
Union unification is rare (~0%) and bounded by the finite union width.

**Cross-stratum interaction**: `unify-propagator` operates within a single stratum
(the base propagation stratum S0). It does not interact with higher strata (constraint
resolution, trait resolution). The stratified quiescence mechanism from Track 2/7
ensures that S0 reaches fixpoint before higher strata activate. Changes from higher
strata (e.g., resolving a trait that reveals a concrete type for a meta) may trigger
new `unify-propagator` firings at S0, but the same Tarski fixpoint applies —
the perturbation moves cells monotonically forward.

**Guarantee**: Level 1 (Tarski fixpoint on finite lattice). No fuel mechanism
needed for correctness, though the existing fuel limit in `prop-network` provides
a safety net for implementation bugs.

### 5.5 Handling De Bruijn Indices Under Binders

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

### 5.6 Lattice-First Architecture: Recursive Sum-of-Products

The type lattice for propagator cells is not a flat lattice — it is a **recursive
sum-of-products lattice**. Recognizing this formally and building the implementation
around it provides compositional correctness, a single source of structural truth,
and the design vocabulary for composing with future propagator infrastructure.

#### 5.6.1 The Lattice Structure

```
TypeLattice = Lifted(FlatLattice(Atom) ⊔ Σ_{tag ∈ Tags} ∏_{i=1..arity(tag)} L_i)

where:
  Atom       = {Nat, Bool, Int, String, Type(n), tycon(name), fvar(x), ...}
  Tags       = {Pi, Sigma, App, Eq, Vec, Fin, Pair, Lam, PVec, Set, Map}
  L_i        = TypeLattice for most components
               MultLattice for Pi's multiplicity component
               (dependent on prior components for binder codomains)
  Lifted(L)  = {⊥} ∪ L ∪ {⊤}  (type-bot and type-top)
```

Each constructor tag gives a **product lattice** over its components. The overall
type is a **sum lattice** (tagged disjoint union) over tags. The `Lifted` wrapper
adds `type-bot` (no information, fresh meta) and `type-top` (contradiction).

**Implementation note**: The formal sum-of-products structure provides compositional
monotonicity guarantees and design vocabulary for cross-domain composition (Track 8).
The implementation dispatches by tag equality, which is the correct realization of the
sum lattice's join: same summand → component-wise product merge; different summands → ⊤.
The formalization is not over-specified — it proves that per-component monotonicity
implies product monotonicity structurally, eliminating the need to hand-verify
`try-unify-pure`'s ~170 lines of recursive decomposition for each new compound type.

**This structure already exists implicitly** in three places:
- `type-lattice.rkt`: `try-unify-pure` recursively decomposes by tag (~170 lines)
- `unify.rkt`: `classify-whnf-problem` classifies by tag (~150 lines)
- `elaborator-network.rkt`: `maybe-decompose` creates sub-cells by tag (~100 lines)

All three encode the same structural knowledge independently. The lattice-first
design unifies them.

**Existing validation**: System 3 (`term-lattice.rkt` + `narrowing.rkt`) already
implements this exact pattern for FL narrowing: `term-ctor(tag, sub-cells)` where
sub-cells are cell-ids, `term-merge` as the lattice join, `term-walk` for variable
resolution through cells. PUnify brings Systems 1 and 2 toward System 3's model —
the architecture is proven, not speculative.

#### 5.6.2 Domain-Agnostic Constructor Descriptor Registry

A single registration site for all compound structure — **both type constructors
(System 1) and data constructors (System 2)**. The file is `ctor-registry.rkt`
(not `type-ctor-registry.rkt`) to reflect the domain-agnostic scope.

```racket
(struct ctor-desc
  (tag            ; symbol: 'Pi, 'Sigma, 'App, 'cons, 'some, 'suc, ...
   arity          ; natural: number of sub-components
   recognizer-fn  ; (AST-value → boolean) — is this value of this constructor?
   extract-fn     ; (AST-value → (list component ...))
   reconstruct-fn ; ((list cell-value ...) → AST-value)
   component-lattices  ; (list (merge-fn contradicts?) ...)
   binder-depth   ; natural: how many components are under a binder (0 for App, 1 for Pi/Sigma)
   domain         ; symbol: 'type or 'data — which system owns this
   ))
```

**Type constructor registrations** (System 1):

```racket
(register-ctor! 'Pi
  #:arity 3  ;; mult, domain, codomain
  #:extract (λ (v) (list (expr-Pi-mult v) (expr-Pi-domain v) (expr-Pi-codomain v)))
  #:reconstruct (λ (cs) (expr-Pi (first cs) (second cs) (third cs)))
  #:component-lattices (list mult-lattice type-lattice type-lattice)
  #:binder-depth 1  ;; codomain is under a binder
  #:domain 'type)

(register-ctor! 'App
  #:arity 2  ;; func, arg
  #:extract (λ (v) (list (expr-app-func v) (expr-app-arg v)))
  #:reconstruct (λ (cs) (expr-app (first cs) (second cs)))
  #:component-lattices (list type-lattice type-lattice)
  #:binder-depth 0
  #:domain 'type)

(register-ctor! 'Eq
  #:arity 3  ;; type, lhs, rhs
  #:extract (λ (v) (list (expr-Eq-type v) (expr-Eq-lhs v) (expr-Eq-rhs v)))
  #:reconstruct (λ (cs) (expr-Eq (first cs) (second cs) (third cs)))
  #:component-lattices (list type-lattice type-lattice type-lattice)
  #:binder-depth 0
  #:domain 'type)
```

**Data constructor registrations** (System 2):

```racket
(register-ctor! 'cons
  #:arity 2  ;; head, tail
  #:extract (λ (v) (list (second v) (third v)))  ;; from '(cons h t)
  #:reconstruct (λ (cs) (list 'cons (first cs) (second cs)))
  #:component-lattices (list term-lattice term-lattice)
  #:binder-depth 0
  #:domain 'data)

(register-ctor! 'some
  #:arity 1  ;; inner
  #:extract (λ (v) (list (second v)))  ;; from '(some x)
  #:reconstruct (λ (cs) (list 'some (first cs)))
  #:component-lattices (list term-lattice)
  #:binder-depth 0
  #:domain 'data)

(register-ctor! 'suc
  #:arity 1  ;; predecessor
  #:extract (λ (v) (list (second v)))  ;; from '(suc n)
  #:reconstruct (λ (cs) (list 'suc (first cs)))
  #:component-lattices (list term-lattice)
  #:binder-depth 0
  #:domain 'data)

(register-ctor! 'pair
  #:arity 2  ;; fst, snd
  #:extract (λ (v) (list (second v) (third v)))
  #:reconstruct (λ (cs) (list 'pair (first cs) (second cs)))
  #:component-lattices (list term-lattice term-lattice)
  #:binder-depth 0
  #:domain 'data)
```

**Key insight**: Data constructor descriptors use the same generic
decompose/reconstruct/merge from §5.6.3. The `domain` field distinguishes which
lattice family to use for component cells (type-lattice vs term-lattice), but the
infrastructure is shared. Adding a new data constructor is one registration, not a
new case in `unify-terms` + `normalize-term-deep` + `ground->prologos-expr`.

#### 5.6.3 Generic Operations Derived From Descriptors

All three currently-independent implementations (for System 1) plus the fragile
normalize/denormalize bridge (for System 2) collapse into generic operations
parameterized by the descriptor:

**Generic decomposition** (replaces `maybe-decompose` + per-tag cases + `normalize-term-deep`):
```
generic-decompose(net, cell, value):
  tag = constructor-tag(value)   ;; works for both type and data constructors
  desc = lookup-ctor-desc(tag)
  if not desc: return net  ;; atom, no decomposition
  components = desc.extract-fn(value)
  ;; Handle binder components: open under fresh fvar
  ;; (get-or-create-sub-cells does NOT open binders — caller's responsibility)
  if desc.binder-depth > 0:
    x = gensym('punify)
    for i in [desc.arity - desc.binder-depth .. desc.arity):
      components[i] = open-expr(zonk-at-depth(1, components[i]), x)
  (net*, sub-cells) = get-or-create-sub-cells(net, cell, tag, components)
  ;; fvar x is captured in the cell-decomps registry via the opened component
  ;; values — cache hit returns the same opened sub-cells with the same fvar
  return net*
```

**Generic reconstruction** (replaces `make-pi-reconstructor`, `make-app-reconstructor`,
... + `ground->prologos-expr`):
```
generic-reconstructor(parent-cell, desc, sub-cells):
  fire(net):
    values = map(net-cell-read, sub-cells)
    if any ⊥: return net  ;; wait for more info
    if any ⊤: return net-cell-write(net, parent-cell, ⊤)  ;; contradiction
    return net-cell-write(net, parent-cell, desc.reconstruct-fn(values))
```

**Generic merge** (replaces `try-unify-pure` recursive cases + `unify-terms` list case):
```
generic-merge(v1, v2):
  tag1, tag2 = constructor-tag(v1), constructor-tag(v2)
  if tag1 ≠ tag2: return ⊤  ;; sum lattice: different summands → contradiction
  desc = lookup-ctor-desc(tag1)
  cs1, cs2 = desc.extract-fn(v1), desc.extract-fn(v2)
  merged = zipWith(component-merge, desc.component-lattices, cs1, cs2)
  if any ⊤: return ⊤
  return desc.reconstruct-fn(merged)
```

#### 5.6.4 What This Gives Us

**Single source of structural truth.** Adding a new compound type OR data constructor
requires ONE descriptor registration. The pipeline exhaustiveness checklist
(`.claude/rules/pipeline.md`) currently requires touching 14 files for a new AST node;
the descriptor registry reduces the compound-type-specific surface to one registration
site. For data constructors, the current triple of `normalize-term-deep` +
`solver-term->prologos-expr` + `ground->prologos-expr` collapses to one descriptor.

**Compositional monotonicity.** Product lattice monotonicity: if each component
merge is monotone, the product merge is automatically monotone (standard theorem).
The only per-component proof obligation is that `type-lattice-merge` and
`mult-lattice-merge` are monotone — already established. The recursive/compound
case is handled by the generic product construction. No hand-verification of
170 lines of `try-unify-pure` needed.

**Design vocabulary for Track 8 second half.** When multiplicity and level domains
come onto the network, a Pi cell's multiplicity sub-cell is naturally a product
lattice component — the Pi descriptor says "my first component is a MultLattice
cell." Cross-domain propagation becomes projection into a different component
lattice, not a bespoke bridge. Session types, capabilities, and future domains
follow the same pattern.

**Galois connection between representations.** The flat type lattice (current
`type-lattice-merge` over AST values) and the tree-structured type lattice
(cell-trees with sub-cells) are connected by a Galois connection:
- α : Tree → AST (fold the tree back into a flat AST — the reconstructor)
- γ : AST → Tree (unfold an AST into sub-cells — the decomposer)
Recognizing this formally means the on-demand decomposition (Option C) IS the
γ injection into the tree lattice, applied lazily. And reconstruction IS α.

**Lattice-indexed families for dependent types.** Pi's codomain lattice depends
on the domain value (the opened binder). The descriptor's `binder-depth` field
marks which components are under binders, and the decomposition machinery
creates fresh fvars for opening. This is the lattice-indexed family from the
lattice catalog (§ Lattice-Indexed Families) made concrete.

#### 5.6.5 What This Does NOT Give Us

**Performance differences.** The descriptor lookup adds one hash lookup per
decomposition (~343 Pi cases → ~17µs total). The generic lambda dispatch is
equivalent to the current match clause dispatch. The runtime operations are
identical to ad-hoc Option C — the lattice framing is a design discipline,
not a different execution path.

**Level unification.** Levels (36% of classifications) are numeric lattice
operations, not tree-structured. They stay imperative. The descriptor registry
covers compound types only.

**Union unification.** Unions have variable width (not fixed arity per tag).
The sum-of-products model doesn't directly cover them. Unions are rare (~0%)
and stay as a special case.

### 5.7 Performance Cost Analysis: Grounded Numbers

Moving structural decomposition from inline recursion to cell-tree propagators
has a concrete, measurable cost. This section provides the grounded analysis.

#### 5.7.1 Cost of a Single Cell

`net-new-cell` (propagator.rkt:259) performs:
- 1 `cell-id` struct allocation
- 1 `prop-cell` struct allocation (value + champ-empty dependents)
- 2-3 `champ-insert` operations (cells, merge-fns, optionally contradiction-fns)
- 1-2 `struct-copy prop-network` (13-field struct, shallow copy)
- For TMS cells: +1 `tms-cell-value` struct allocation

**Total per cell**: ~4-5 allocations + 2-3 CHAMP inserts + 1-2 struct-copies.

#### 5.7.2 Cost of a Cell Write

`net-cell-write` (propagator.rkt:342) performs:
- 2-3 `champ-lookup` operations (cell, merge-fn, optionally contradiction-fn)
- 1 `merge-fn` call (the lattice join)
- 1 `equal?` check (old vs merged — for compound types, walks the AST)
- If changed: 1 `struct-copy prop-cell`, 1 `champ-insert`, worklist append

#### 5.7.3 Current Inline Cost vs Cell-Tree Cost Per Pi Decomposition

**Current (inline recursion)**:
- 3 struct field accesses (O(1) each — direct accessor, ~1ns)
- 1 `gensym` + 2 `zonk-at-depth` + 2 `open-expr` walks
- 2 recursive `unify-core` calls (continues on call stack)
- **No CHAMP operations. No cell creation. No prop-network struct-copy.**

**Cell-tree (on-demand decomposition)**:
- `get-or-create-sub-cells` × 2: 4-6 new cells, 2 registry lookups + 2 inserts
- `elab-add-unify-constraint` × 2: 2 propagator creations, 4 cell reads
- 2 reconstructor propagators
- ~12-20 CHAMP operations, ~8-12 prop-network struct-copies total

#### 5.7.4 Aggregate Cost Estimate

For the acceptance file (163 commands, 1,904 classifications):

| Classification | Count | New Cells | New Propagators | CHAMP Ops |
|---------------|-------|-----------|-----------------|-----------|
| level (36%)   | ~686  | 0         | 0               | 0         |
| ok (14%)      | ~267  | 0         | 0               | 0         |
| flex-rigid (24%) | ~457 | 0-457  | 0               | ~900      |
| pi (18%)      | ~343  | ~1,400    | ~1,400          | ~5,000    |
| binder (6%)   | ~114  | ~450      | ~450            | ~1,700    |
| sub (3%)      | ~57   | ~230      | ~230            | ~850      |
| **Total**     | 1,904 | **~2,100-2,500** | **~2,100** | **~8,500** |

At measured per-operation costs:
- 2,500 cell creations × ~600ns each: **~1.5ms**
- 8,500 CHAMP operations × ~300ns each: **~2.6ms**
- 4,000 prop-network struct-copies × ~200ns each: **~0.8ms**
- 2,100 propagator fire cycles × ~500ns each: **~1.1ms**
- Worklist scheduling overhead: **~2-5ms**

**Total estimated overhead: ~8-11ms per acceptance file run** (0.05-0.06% of 17.9s).

This is well within the 10% regression budget. The 80% fast-path (zero cells)
is the key enabler — only 20% of unify calls create any cells at all.

#### 5.7.5 Memory Cost

Per cell: ~200-300 bytes (cell-id, prop-cell, CHAMP entries, TMS wrapper).
2,500 cells × 250 bytes = **~625KB** additional per file.
Current working set: ~5-15MB. This is ~4-6% increase — negligible.

#### 5.7.6 Compensating Factors

**Shallower `equal?` checks.** Currently `net-cell-write` calls `(equal? merged
old-val)` which for compound types walks the full AST tree. With cell-trees,
leaf cells hold atoms — `equal?` becomes pointer comparison. This partially
offsets the CHAMP overhead.

**Reduced `try-unify-pure` recursion.** The current `make-structural-unify-propagator`
calls `type-lattice-merge` → `try-unify-pure` which does deep recursive structural
comparison. With cell-trees, this recursion is replaced by shallow per-component
merge at each cell level. The total work is similar but distributed differently.

**Memoized decomposition.** The `cell-decomps` registry means repeated unifications
against the same compound type (e.g., the prelude's `map` function type unified
in multiple call sites) reuse cached sub-cells. Currently each unification does
fresh structural recursion. For types unified multiple times, cell-trees amortize.

### 5.8 Interaction with Existing Infrastructure

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

### 5.9 Design Principle Tensions and Conscious Trade-offs

#### 5.9.1 Ephemeral State and Propagator Justification

DESIGN_PRINCIPLES.md § "When Not To Use Propagators" identifies propagators as the
wrong choice when *"the structure is ephemeral and single-use (per-command scratch
space)"*. Cell-trees ARE per-command: types are elaborated fresh each command and the
elab-network is reset by `reset-elab-network-command-state` (§10, Q2). This warrants
explicit justification for why propagators are still the right tool here.

**Why cell-trees justify propagator overhead despite being per-command**:

1. **Cross-domain dependency within a command**. A single command's elaboration involves
   multiple interacting domains: type unification, trait constraint resolution, meta
   solving, and stratified quiescence. Cell-trees participate in all of these. When a
   `unify-propagator` solves a meta, it wakes trait resolution propagators (stratum L1)
   which may solve other metas, which wake further unify-propagators. This cross-domain
   interaction is the composition argument from DESIGN_PRINCIPLES — even within a single
   command's lifetime, the synergy of composing multiple propagator-backed structures
   exceeds what isolated mutable stores provide.

2. **TMS retraction during speculation**. Within a single command, speculative
   type-checking (`save-meta-state`/`restore-meta-state!`) may execute multiple
   try-and-backtrack cycles. Cell-tree state on TMS-tracked cells gets clean retraction
   for free. The current non-TMS-tracked meta-info CHAMP requires manual snapshot/restore
   — the very fragility that PUnify aims to eliminate (§3.7). The "ephemeral" lifetime
   doesn't remove the need for retraction within that lifetime.

3. **Fan-in within a command**. A meta appearing in multiple type positions gets
   constrained from multiple sources during a single command's elaboration. With AST
   unification, each constraint is processed sequentially. With cell-trees, constraints
   from independent unification sites propagate to the same meta-cell — the propagator
   worklist handles ordering. This is the fan-in capability that justifies propagators
   even for short-lived state.

4. **The precedent**: The elab-network is already per-command and already uses propagator
   cells for metas, constraints, and structural decomposition. Cell-trees extend the
   existing per-command propagator infrastructure; they don't introduce a new category
   of ephemeral propagator use. The real design question is not "should per-command state
   use propagators?" (already answered yes by Track 2/4/7) but "should unification
   decomposition participate in the existing per-command propagator network?" — and the
   composition argument makes this clearly yes.

The DESIGN_PRINCIPLES caution about ephemeral state targets a different scenario:
standalone scratch computations with no dependency tracking needs. Cell-trees are
ephemeral in lifetime but richly connected in dependency structure.

#### 5.9.2 Investment vs. Pain: The 4.8% Question

DEVELOPMENT_LESSONS.md § "Let Pain Drive Design" advises: *"Don't add features until
they're needed."* The profiling data (§2, acceptance file) shows type-level structural
unification targets represent ~4.8% of total wall time. The performance case for
cell-trees is objectively weak.

**This design is a conscious architectural investment, not a pain-driven response.**
We state this explicitly rather than disguising it as performance optimization:

1. **The investment case**: Cell-trees are enabling infrastructure for Track 8 second
   half (mult/level/session domain migration), Track 9 (GDE error provenance via
   cell-tree dependency chains), and the long-term retirement of `restore-meta-state!`.
   The descriptor registry serves as the architectural foundation for PUnify Part 3
   (ATMS-world solver), which requires cell-tree unification as a stable substrate.
   Building cell-trees now — while the unification architecture is fresh in context —
   is cheaper than building them later when the context must be re-acquired.

2. **The pain that does exist** (even if small in %-of-wall-time):
   - Three independent encodings of the same structural knowledge (~420 lines total)
     that must be kept in sync. This is maintenance pain, not performance pain.
   - Solver unification of prelude constructors is **currently broken** (§3.10). This
     is user-visible pain that the descriptor registry directly fixes.
   - Speculation fragility: meta-info not TMS-tracked (§3.7) causes subtle bugs.
     This is correctness pain that cell-trees directly address.
   - The `normalize-term-deep` / `ground->prologos-expr` bridge is fragile and requires
     manual extension for every new AST node type (§3.12). This is extension pain.

3. **The Completeness Over Deferral argument**: DEVELOPMENT_LESSONS.md also says *"When
   you have the clarity, the vision, and the full context — finish the work now."* The
   PUnify design work (Parts 1-3) has created the fullest context for unification
   architecture we've had. Deferring cell-tree implementation to "when the pain is
   sufficient" means re-acquiring this context later. The "Let Pain Drive Design"
   principle and "Completeness Over Deferral" are in tension here; we resolve it by
   noting that multiple concrete pains (broken prelude unification, speculation
   fragility, bridge fragility, triple encoding) exist alongside the forward-looking
   investment.

---

## 6. Implementation Phases

### Phase Dependency DAG

```
Phase 1 (registry) ──┬──→ Phase 2 ──→ Phase 3 ──→ Phase 4 ──┬──→ Phase 7 (callback elim)
                     │                                       │
                     └──→ Phase 5a ──→ Phase 5b ──→ Phase 5c ──→ Phase 5d
                                                              │
Phase 6 (fast-path) ◄────────────────────────────────────────┘ (after 4 AND 5d)
Phase 8 (occurs check) ◄─────────────────────────────────────┘ (after 4 AND 5d)
Phase 9 (zonk) ◄──── Phase 4 only (System 1)
```

System 1 path (Phases 2-4, 7, 9) and System 2 path (Phase 5a-5d) diverge after
Phase 1 and reconverge at Phases 6 and 8. This enables parallel development if
resources allow.

### Per-Phase Completion Criteria

Every phase is complete when ALL of the following hold:
1. All tests pass (`run-affected-tests.rkt --all`)
2. Primary benchmark within per-phase budget (≤2% regression)
3. Classification distribution unchanged (±1%) via `profile-unify.rkt`
4. Cell allocation within budget (`perf-inc-cell-alloc!` counter)
5. Propagator count within budget (`perf-inc-prop-alloc!` counter — added Phase 1)
6. Acceptance file runs with 0 errors
7. No new test failures in `data/benchmarks/failures/`

**Rollback protocol**: If a phase regresses its primary benchmark by >5% and
the regression cannot be resolved within the phase scope, rollback to the
pre-phase commit and document the failure mode. The `current-punify-enabled?`
toggle provides immediate rollback without code reversion for Phases 1-4.
For Phase 5, the solver A/B toggle provides the same safety.

### Phase 1: Constructor Descriptor Registry + Generic Infrastructure

**What**: Create the `ctor-desc` registry (§5.6.2), the generic decomposition
and reconstruction machinery (§5.6.3), and the `unify-propagator` function that
dispatches through descriptors rather than hardcoded match clauses.

**Files**: New `ctor-registry.rkt`; modified `unify.rkt`, `elaborator-network.rkt`, `relations.rkt`

**Deliverables**:
1. `ctor-desc` struct with `recognizer-fn` field: `(AST-value → boolean)` for safe
   dispatch (wraps struct predicates for types, list-tag checks for data constructors)
2. `register-ctor!` with `validate-ctor-desc!` at registration: verifies
   `(= (length (extract-fn sample)) arity)`, roundtrip `(equal? (reconstruct-fn (extract-fn v)) v)`,
   and `(= (length component-lattices) arity)`
3. `lookup-ctor-desc` for dispatch
4. Type constructor registrations for all 11 compound type tags (Pi, Sigma, App,
   Eq, Vec, Fin, Pair, Lam, PVec, Set, Map) — domain `'type`
5. Data constructor registrations for core prelude types (cons, nil, some, none,
   suc, zero, pair, ok, err) — domain `'data`
6. `generic-decompose` and `generic-reconstruct` parameterized by descriptor
7. `current-punify-enabled?` parameter (default #f) as A/B toggle
8. When enabled, `unify-core` delegates to `unify-via-propagator` which uses
   the generic machinery; when disabled, existing code runs unchanged
9. `cell-tree->sexp` debugging utility (recursive cell-tree → S-expression conversion)
10. `perf-inc-prop-alloc!` counter in `performance-counters.rkt`
11. `bench-descriptor.rkt` micro-benchmarks: lookup, extract, reconstruct, decompose, merge

**Approach**: The descriptor table is the single source of structural truth.
`make-structural-unify-propagator` (elaborator-network.rkt:889) and
`try-unify-pure` (type-lattice.rkt:168) both become thin wrappers around
generic operations. This is a refactoring gate — all subsequent phases (for
both System 1 and System 2) operate through descriptors, not hardcoded per-tag cases.

**Test**: All tests pass with toggle OFF. Toggle ON + run structural decomp tests
(`test-structural-decomp.rkt`) and a subset of the acceptance file.

**Benchmark**: `bench-ab.rkt` with toggle OFF must show no regression (refactoring
should not change behavior). Toggle ON: establish new baseline.

### Phase 2: flex-rigid as Cell Write (System 1)

**What**: Replace `solve-flex-rigid` → `solve-meta!` with `cell-write` to the
meta's existing propagator cell. Remove the callback indirection.

**Why first**: flex-rigid is 24% of classifications, the simplest structural case
(no decomposition needed), and `solve-meta!` already writes to a cell (line 1558).
This is mostly removing indirection.

**Test**: flex-rigid micro-benchmarks. Type-adversarial baseline.

### Phase 3: Pi Decomposition as Sub-Cells (System 1)

**What**: For `pi` classification (18%), `generic-decompose` uses the Pi descriptor
to create mult, domain, and codomain sub-cells via `get-or-create-sub-cells`.
`generic-reconstruct` adds the reconstructor propagator. Unify-propagators are
added for each sub-goal pair.

**Key**: This is where recursive `unify-core` calls become propagator additions.
The domain and codomain sub-goals are scheduled on the worklist, not the call stack.
The Pi descriptor's `binder-depth: 1` ensures codomain opening with fresh fvar.

**Test**: Pi decomposition micro-benchmarks (bench-type-unify.rkt: pi-d5, pi-d10, pi-d20).

### Phase 4: Sigma/Lambda/Remaining Compound Types (System 1)

**What**: Enable descriptors for Sigma, Lam, App, Eq, Vec, Fin, Pair, PVec, Set,
Map. With the generic machinery from Phase 1 and the pattern proven in Phase 3,
this is descriptor registration + test verification, not new structural code.

**Key difference from ad-hoc approach**: No per-tag `decompose-sigma`, `decompose-app`,
etc. functions needed. Each tag's descriptor drives the generic operations.

**Test**: Binder micro-benchmarks. App decomposition micro-benchmarks.

### Phase 5: Data Constructor Cell-Trees (System 2)

**What**: Migrate `unify-terms` to use cell-tree operations via data constructor
descriptors. Logic variables become cells (analogous to metas in System 1). The
DFS search strategy and `solve-goals` conjunction solver are preserved.

**Sub-phases**:

**5a: Solver cell infrastructure.** Create a solver-specific prop-network (or
per-branch prop-network clone) for cell-tree unification within solve contexts.
Logic variables get cells at `term-bot`. `walk` becomes `net-cell-read` with
chain following through cell values.

**5b: Data constructor decomposition.** `unify-terms` dispatches through
`lookup-ctor-desc` for compound terms. `(cons 1 xs)` vs `(cons 2 ys)` becomes:
decompose both via `cons` descriptor → unify head sub-cells → unify tail sub-cells.
Generic merge handles tag mismatch (cons vs nil → ⊤).

**5c: DFS backtracking with cell state.** Each `solve-app-goal` clause attempt
needs an isolated cell state — if a clause fails, cell writes from that branch
must not persist. Two strategies:
- **Copy-on-branch**: Clone the prop-network at each branch point. `struct-copy`
  of the 13-field prop-network is ~13 pointer copies (~50ns). CHAMP maps inside
  are structurally shared — only delta cells from each branch are new allocations.
- **TMS worlds**: Use TMS assumption tagging to mark per-branch writes. Retract
  on failure. More aligned with long-term ATMS vision but higher complexity.
- **Recommended**: Copy-on-branch for Phase 5. This is explicitly **interim
  infrastructure** — Part 3 (ATMS-world solver) replaces the entire DFS search
  layer, retiring copy-on-branch entirely.

**Live-branch analysis**: The DFS solver uses `append-map` over substitution
results (`solve-goals`, relations.rkt:458-467). This is depth-first: one branch
is fully explored before the next begins. At any given moment, only O(depth)
branches are live on the call stack. For the 5-hop×5 benchmark (3125 total
exploration paths), peak concurrent branches = 5 (the recursion depth). Each
live branch holds ~10 cells delta → ~50 concurrent cells, not 31,250. Past
branches' networks are garbage-collected as `append-map` returns.

**Worklist draining**: Branch points occur at goal boundaries (`solve-app-goal`
tries each matching clause). Before branching, each goal's unification runs to
quiescence (the unify-propagator fires, decomposition completes, worklist
drains). The branch receives a quiescent network with empty worklist. This
matches the current pattern: `unify-terms` runs to completion within each
clause attempt before the next attempt begins.

**5d: Bridge retirement.** Remove `normalize-term-deep`, `solver-term->prologos-expr`,
and `ground->prologos-expr`. Solver operates on AST nodes directly via descriptors.
`walk*` (deep resolution for output) becomes "read cell-tree, reconstruct via
descriptors."

Explicit responsibility mapping (verified against codebase):
```
normalize-term-deep (relations.rkt:256-275) — 4 cases:
  1. expr-logic-var mode-stripping (?/+/-) → resolved at cell creation time
  2. expr-app → cons-list flattening      → descriptor extract-fn for App
  3. expr-goal-app → keyword conversion    → descriptor for goal-app tag
  4. passthrough (atoms)                   → no conversion needed

ground->prologos-expr — reconstructs list→AST:
  1. list→expr-app chain                  → descriptor reconstruct-fn for App
  2. keyword→expr-goal-app                → descriptor reconstruct-fn for goal-app
  3. cell value resolution (walk*)        → read-cell-tree traversal via cell-tree->sexp

solver-term->prologos-expr — same as ground but preserves logic vars:
  1. symbol→expr-logic-var               → cell reference (cell at type-bot = unresolved)
  2. list reconstruction                  → descriptor reconstruct-fn
```

**Test**: solve-adversarial.prologos baseline must not regress >10%. Acceptance file
§B (user-defined relations), §D (guards), §H (is-goal), §K (mixed rel/functional),
§L (prelude constructor unification) — §L is the key unlock (currently broken).

**Benchmark**: `bench-ab.rkt` on solve-adversarial. `bench-solve-pipeline.rkt` for
micro-level comparison.

### Phase 6: Fast-Path Preservation

**What**: Ensure the 80% fast-path still bypasses the propagator machinery entirely
for System 1. For System 2, ensure simple ground-term equality (`equal?` after walk)
still short-circuits without cell creation.

**Fast-path survival analysis** (verified against unify.rkt:179-190):

The current fast-path is `(equal? z1 z2)` on zonked (not WHNF-reduced) terms —
Racket's structural `equal?`, not pointer `eq?`. After cell-tree migration:
- Cell values ARE AST nodes (until decomposed). Two independently-constructed
  but structurally-identical types have different cell-ids but identical cell
  values. `equal?` on cell values still matches.
- The fast-path *precedes* decomposition — it's the "don't decompose at all" path.
  Cell-tree migration changes what happens during decomposition, not before it.
- The second fast-path (spine-head comparison for App-vs-App before WHNF) also
  survives: it reads cell values and compares spine heads.

**Expected preservation**: The 80% fast-path rate should hold because the fast-path
tests cell values (AST nodes), not cell structure (cell-ids). Monitoring plan:
measure fast-path hit rate via `profile-unify.rkt` before and after each phase.
Alert threshold: if fast-path rate drops below 70%, investigate before proceeding.

**Test**: ok-classification micro-benchmarks. Fast-path hit rate measurement.
Full suite timing.

### Phase 7: Callback Elimination (System 1)

**What**: Remove `current-prop-cell-write`, `current-prop-cell-read`,
`current-prop-has-contradiction?` callbacks. Replace with direct cell operations
through the descriptor-generic machinery.

**Depends**: Phases 2-4 complete (all System 1 decomposition paths use cells via descriptors).

**Key**: The descriptor registry means `unify.rkt` no longer needs to know about
the propagator network's internal API — it operates through descriptors that
encapsulate the structural knowledge. Callbacks were the bridge between the
algorithmic unifier and the network; descriptors make them unnecessary.

### Phase 8: Occurs Check as Cycle Detection (Both Systems)

**What**: Replace AST-walking `occurs-check-meta` (System 1) with cell-tree cycle
detection. Add occurs check to System 2 (currently missing — §3.9). Both share the
same cell-pointer reachability check.

**Test**: Occurs check micro-benchmarks. Regression test for infinite-term prevention
in solver.

### Phase 9: Zonk Simplification (System 1)

**What**: Final zonk becomes "read cell-tree, return value." Intermediate zonk
reads cell values (may be type-bot for unsolved metas).

**Test**: Zonk micro-benchmarks (bench-type-unify.rkt: zonk-d10, zonk-d20).

---

## 7. What PUnify Does NOT Change

- **Level unification** (36% of classifications): Numeric lattice operations.
  No cell-tree benefit. Stays imperative.
- **Union unification**: Rare (~0%). Low priority.
- **HKT normalization** (retry): Rare. Stays as preprocessing.
- **DFS search strategy** (`solve-goals`, `solve-app-goal`): The conjunction solver
  and clause-level backtracking are preserved. PUnify replaces the unification
  substrate, not the search strategy. (ATMS-world search is a future track.)
- **NAF and cut**: `not` goals and `cut` in the solver are search-level, not
  unification-level. Unchanged.
- **WHNF reduction**: Still called before classification. Unchanged.
- **De Bruijn infrastructure**: `zonk-at-depth`, `open-expr`, `subst` — preserved.
- **`is` goal evaluation**: Expression evaluation in solver stays as-is.

---

## 8. Performance Budget

| Metric | Baseline | Target | Hard Limit |
|--------|----------|--------|------------|
| Type-adversarial | 17.9s | ≤19.7s (10%) | ≤21.5s (20%) |
| Solve-adversarial | 14.3s | ≤15.7s (10%) | ≤17.2s (20%) |
| Full suite | 183s | ≤200s (10%) | ≤220s (20%) |
| Cell allocation/cmd | ~82 | ≤100 | ≤120 |
| Unify wall time % | 10% | ≤12% | ≤15% |
| Propagators/cmd | ~200 (est.) | ≤400 | ≤600 |

**Per-phase budget**: Phases 1-4 (System 1) must not regress type-adversarial by
more than 2% each. Phase 5 (System 2) must not regress solve-adversarial by more
than 2% per sub-phase. Cumulative budget is 10% for each benchmark.

**Measurement**: `bench-ab.rkt --runs 10 --ref HEAD~1` after each phase.
`profile-unify.rkt` for classification distribution stability (System 1).
`bench-solve-pipeline.rkt` for solver micro-benchmarks (System 2).

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

### MEDIUM: DFS Backtracking with Cell State (System 2)

**Risk**: The DFS solver backtracks by discarding substitutions from failed branches.
With cell-trees, failed branches have written cell values that must be retracted.
If cell state leaks between branches, the solver produces incorrect results.

**Mitigation**: Copy-on-branch strategy (Phase 5c). CHAMP-based prop-network is
persistent/immutable — "cloning" is O(1) struct-copy. Each branch gets its own
network; on failure, the branch's network is simply discarded. On success, the
branch's network replaces the parent. This is analogous to the current substitution-
threading pattern (`foldl unify-terms` passing subst through) — just with a richer
data structure.

**Detection**: solve-adversarial benchmark (14.3s baseline, 0.3% CV) is the primary
regression detector. Add specific backtracking-intensive tests in Phase 5.

### MEDIUM: `normalize-term-deep` Bridge During Migration (System 2)

**Risk**: Phase 5 must incrementally migrate from flat substitution to cell-trees.
During migration, some paths use the old `normalize-term-deep` bridge while others
use descriptors. Mixed representations can cause subtle failures.

**Mitigation**: Phase 5a establishes the cell infrastructure alongside the existing
substitution. Phase 5b adds descriptor-based unification as an alternative path with
a toggle (like `current-punify-enabled?`). Phase 5d retires the bridge only after
all paths are migrated. The toggle ensures we can always fall back.

### LOW: Per-Branch Cell Allocation Pressure (System 2)

**Risk**: DFS solver may explore many branches (e.g., 5-hop×5 join = 3125 branches
in benchmarks). Each branch creates cells. Total cell allocation could be much higher
than System 1's ~2,500 cells.

**Mitigation**: Copy-on-branch shares structure — cells created in parent branches
are shared (CHAMP structural sharing). Only delta cells from each branch are new
allocations. For ground-term unification (the common case in the solver), the fast-
path short-circuits with zero cell creation.

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

### Q4: Descriptor Indirection Cost — RESOLVED (negligible)

One hash lookup per decomposition to find the descriptor. At ~343 Pi
classifications per file, that's ~17µs total. Racket's JIT handles the
lambda dispatch through struct accessors as well as match clause dispatch.

### Q5: `pair-decomps` Symmetry

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
| `ctor-registry.rkt` | **NEW** — Domain-agnostic constructor descriptor table, generic decompose/reconstruct |
| `unify.rkt` | System 1 target — classifier + dispatcher + fire function |
| `relations.rkt` | System 2 target — `unify-terms`, `walk`, `solve-goals`, DFS solver |
| `elaborator-network.rkt` | `get-or-create-sub-cells`, decomposition registry, cell creation |
| `metavar-store.rkt` | `solve-meta!`, meta-info management, callback parameters |
| `propagator.rkt` | `net-new-cell`, `net-add-propagator`, worklist, quiescence |
| `term-lattice.rkt` | Existing System 3 cell-tree pattern — model for PUnify design |
| `performance-counters.rkt` | `unify-profile` instrumentation |
| `tools/profile-unify.rkt` | Classification distribution monitoring |
| `tools/bench-ab.rkt` | A/B regression testing |
| `benchmarks/micro/bench-type-unify.rkt` | Per-operation micro-benchmarks (System 1) |
| `benchmarks/micro/bench-solve-pipeline.rkt` | Per-operation micro-benchmarks (System 2) |
| `benchmarks/comparative/type-adversarial.prologos` | End-to-end benchmark — System 1 (17.9s baseline) |
| `benchmarks/comparative/solve-adversarial.prologos` | End-to-end benchmark — System 2 (14.3s baseline) |
| `examples/2026-03-19-punify-acceptance.prologos` | Acceptance file (169 cmds, 0 errors) |

---

## 13. Design Critique Record

### D.3 Self-Critique (2026-03-19)

Cross-referenced against `DESIGN_PRINCIPLES.md`, `DESIGN_METHODOLOGY.md`,
`DEVELOPMENT_LESSONS.md`, and `PATTERNS_AND_CONVENTIONS.md`. Grounding audit
verified 10 code references against codebase (7/10 accurate, 2 minor line shifts,
1 function name corrected).

**Gaps identified and addressed in this revision**:

| Gap | Principle Source | Resolution |
|-----|-----------------|------------|
| No termination argument for `unify-propagator` | DESIGN_METHODOLOGY §3: "State termination arguments" | Added §5.4: Level 1 Tarski fixpoint, AST-depth well-founded measure |
| Ephemeral-state tension unaddressed | DESIGN_PRINCIPLES § "When Not To Use Propagators" | Added §5.9.1: cross-domain dependency, TMS retraction, fan-in, precedent arguments |
| Performance case weak, not acknowledged as trade-off | DEVELOPMENT_LESSONS § "Let Pain Drive Design" | Added §5.9.2: explicit investment-vs-pain framing with concrete pain inventory |
| `occurs-check-meta` wrong function name | Grounding audit | Corrected to `occurs?` (§3.4) |
| Line number inaccuracies (3 instances) | Grounding audit | Corrected §2.4, §5.2 table, §5.1 |

**Alignments confirmed** (no action needed):
- Propagator-First Infrastructure: core motivation, well-aligned
- Correct by Construction: TMS retraction, decomposition caching — structural guarantees
- Decomplection: three independent encodings → one descriptor registry
- Data Orientation: cells as data vs recursive calls as control flow
- First-Class by Default: type structure observable on the propagator network
- Completeness Over Deferral: both Systems 1 and 2 in scope rather than deferring System 2
- Phase-Gated Implementation: 9 phases with sub-phases, clear A/B toggle strategy

### D.2 External Critique (2026-03-19)

Comprehensive external review covering structural gaps, technical critique,
risk analysis, methodology alignment, and implementation suggestions.

**Accepted and applied to this revision**:

| Critique Point | Resolution |
|---------------|------------|
| Missing phase dependency DAG | Added DAG before §6 showing Phase 1→2→3→4→7, Phase 1→5a→5b→5c→5d, Phase 6/8 after 4+5d |
| No per-phase completion criteria | Added 7-item checklist + rollback protocol (>5% regression trigger) |
| Phase 1 deliverables underspecified | Expanded to 11 items: added `recognizer-fn`, `validate-ctor-desc!`, `cell-tree->sexp`, `perf-inc-prop-alloc!`, `bench-descriptor.rkt` |
| `ctor-desc` missing recognizer field | Added `recognizer-fn` field to struct definition |
| Lattice formalization needs clarification | Added note: lattice is design vocabulary over standard propagator ops, not new runtime machinery |
| Binder-opening pseudocode missing | Added explicit pseudocode in §5.6.3 `generic-decompose` for binder-depth handling |
| Copy-on-branch memory analysis missing | Added live-branch analysis: O(depth) not O(total-paths), worklist draining at goal boundaries |
| Bridge retirement responsibilities unclear | Added per-case mapping: all 4 `normalize-term-deep` cases → descriptor equivalents |
| Fast-path survival unargued | Added analysis: `equal?` on cell values (AST nodes) survives; 80% rate preserved; 70% alert threshold |
| No propagator count metric | Added to §8 performance budget: baseline ~200, target ≤400, hard limit ≤600 |

**Pushed back with grounded reasoning**:

| Critique Point | Pushback Rationale |
|---------------|-------------------|
| "Lattice formalization is aspirational" | The lattice IS the existing cell+propagator infrastructure with explicit vocabulary — not new runtime machinery. `term-lattice.rkt` already implements exactly this pattern. |
| "Copy-on-branch allocates full network per branch" | `struct-copy` on 13-field prop-network is ~50ns (13 pointer copies). CHAMP sharing means delta-only allocation. Not "full network" copies. |
| "Bridge retirement is too aggressive for Phase 5d" | Phase 5d retirement is restricted to System 2 only (4 cases in `normalize-term-deep`). System 1 bridge retirement happens at Phase 7. Each is narrow and testable. |
| "Interim infrastructure (both paths) is untested" | The A/B toggle strategy from Track 7 is proven — `use-cell-primary-registry` ran both paths for 37 commits. Same pattern here. |
| "Registry corruption needs formal invariants" | `validate-ctor-desc!` (accepted above) plus the descriptor registry is append-only (registered at module load, never mutated during elaboration). Append-only registries don't need corruption recovery. |
| "GÖDEL_COMPLETENESS Level 1 insufficient" | Level 1 (Tarski fixpoint on finite lattice) is correct for PUnify. Level 2 (well-founded measure + SCC) is for trait resolution, which is a separate system. The levels are independent. |
| "Should micro-benchmark generic-decompose early" | Accepted `bench-descriptor.rkt` in Phase 1 (see above) but pushed back on "should micro-benchmark the registry lookup" — one hash lookup at ~343 invocations is ~17µs total, below measurement noise. |

**Clarification questions addressed**:

| Question | Answer |
|----------|--------|
| Q1: How does lazy cell creation interact with TMS retraction? | On retraction, cells are invalidated (value → ⊥), not deleted. Decomposition cache (`cell-decomps`) entries persist as dead entries. `pair-decomps` propagators see ⊥ and stop — standard propagator monotonicity. |
| Q2: What happens if two types unify to the same meta? | `identify-sub-cell` (elaborator-network.rkt:456-467) merges cells. This is the existing pattern for meta reuse — PUnify doesn't change it, just routes through it more often. |
| Q3: How does copy-on-branch interact with constraint postponement? | System 2 currently has zero postponements (profiling data). Part 3 (ATMS-world) replaces DFS entirely, so postponement semantics become moot. For PUnify, the solver remains DFS with ground-term fast-path. |
| Q4: Occurs check — cell-tree cycle vs logical cycle? | `occurs?` (unify.rkt:109-120) checks meta-in-term, not cell-tree cycles. Cell-trees are acyclic by construction (decomposition creates children, never back-edges). The occurs check remains a pre-solve-meta guard. |
| Q5: Zonk semantics with cell indirection? | Zonk reads cell values, which are AST nodes — same as reading meta solutions today. The indirection is: meta → cell → AST value (vs current meta → CHAMP → AST value). `zonk-meta` already calls `lookup-meta-solution`; that function gains a cell-read path. |

---

## 14. Progress Tracker

| Phase | Description | Status | Notes |
|-------|------------|--------|-------|
| 0a | Core wiring (constructors, modes, `is`, `=`) | ✅ | `32d62c6`, `3e04907`, `34a5690` |
| 0b | `defr \|` literal pattern fix | ✅ | `490a4e3` |
| 0c | Acceptance file (169 cmds) | ✅ | Extended across 0a-0b |
| 0d | Adversarial benchmarks (3-tier) | ✅ | `76eb5d2` |
| 0e | Type-level unification profiling | ✅ | `364d043` |
| D.1 | Design document (this file) | ✅ | `b12a891`, `349c9d2`, `bf0d21f` |
| D.3 | Self-critique and alignment check | ✅ | This section |
| D.2 | External critique | ✅ | Accepted 10 improvements, pushed back 7, addressed 5 questions |
| 1 | Constructor descriptor registry | ✅ | `4a0567e` — fresh implementation after revert; 12 type + 9 data descriptors, generic merge/decompose wired |
| 2 | flex-rigid as cell write (System 1) | ✅ | 67f1388 — direct contradiction check, callback indirection removed |
| 3 | Pi decomposition as sub-cells (System 1) | ✅ | 52e6230 — propagator-based Pi decomposition with binder opening |
| 4 | Remaining compound types (System 1) | ⬜ | |
| 5a | Solver cell infrastructure (System 2) | ⬜ | |
| 5b | Data constructor decomposition (System 2) | ⬜ | |
| 5c | DFS copy-on-branch (System 2) | ⬜ | |
| 5d | Bridge retirement (System 2) | ⬜ | |
| 6 | Fast-path preservation | ⬜ | |
| 7 | Callback elimination (System 1) | ⬜ | |
| 8 | Occurs check as cycle detection | ⬜ | |
| 9 | Zonk simplification (System 1) | ⬜ | |
