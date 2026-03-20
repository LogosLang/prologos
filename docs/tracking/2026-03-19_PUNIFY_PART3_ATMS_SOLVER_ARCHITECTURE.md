# PUnify Part 3: ATMS-World Solver Architecture

**Created**: 2026-03-19
**Status**: Design (pre-implementation)
**Parent**: Track 8 — Propagator Infrastructure Migration
**Part 1**: `2026-03-19_PUNIFY_STRUCTURAL_UNIFICATION_PROPAGATORS.org` (surface wiring + baselines)
**Part 2**: `2026-03-19_PUNIFY_PART2_CELL_TREE_ARCHITECTURE.md` (cell-tree unification substrate)
**Vision**: `RELATIONAL_LANGUAGE_VISION.org` (§ Solver Architecture: three-layer model)
**Audit**: `2026-03-18_TRACK8_PROPAGATOR_INFRASTRUCTURE_AUDIT.org`

---

## 1. Purpose and Scope

PUnify Part 3 replaces the solver's **DFS search strategy** with **ATMS-world
exploration** on the propagator network. Where Part 2 migrates the unification
*substrate* (both type-level and solver-level) to cell-trees via shared descriptors,
Part 3 migrates the *search strategy* — the mechanism by which the solver explores
alternative clause matches and manages backtracking.

This is the "Maximum" vision from the solver conversation: Forbus & de Kleer's
ATMS-based logic programming realized on our existing Track 2/4/7 infrastructure.

**What changes**:
- DFS backtracking (`solve-goals` threading substitutions through recursive calls)
  becomes ATMS-world exploration (each clause attempt is an assumption, quiescence
  replaces recursion, nogoods replace backtracking)
- Sequential clause exploration becomes concurrent world maintenance
- Explicit substitution threading becomes implicit propagation through cell-trees
- `solve-app-goal`'s per-clause try/catch becomes per-clause assumption creation

**What doesn't change**:
- Cell-tree unification substrate (Part 2 delivers this)
- Constructor descriptor registry (Part 2 delivers this)
- The user-facing `solve`/`defr` syntax
- Relation registration and clause storage
- `is` goal evaluation, guard predicates
- Mode annotations (future concern, not Part 3)

**Depends on**: Part 2 complete (cell-tree unification for both systems)

**Success criteria**:
- Solve-adversarial benchmark (14.3s baseline) does not regress by more than 15%
  (wider budget than Part 2 because the search strategy change is more fundamental)
- Left-recursive `defr` relations terminate (currently diverge — tabling prerequisite)
- All acceptance file solver sections pass
- Prelude constructor unification in `defr` contexts works (Part 2 prerequisite)
- Multiple solutions returned correctly (ATMS worlds enumerate all answers)

---

## 2. Current Architecture: DFS Search

### 2.1 The DFS Loop

```
solve-goals(goals, subst):
  foldl over goals:
    solve-single-goal(goal, subst) → subst' | #f
  return subst' | #f

solve-single-goal(goal, subst):
  match goal:
    app-goal    → solve-app-goal(rel, args, subst)
    unify-goal  → unify-terms(lhs, rhs, subst)
    is-goal     → evaluate + bind
    not-goal    → NAF: solve fails? → succeed with current subst
    cut-goal    → prune remaining clauses
    guard-goal  → evaluate predicate

solve-app-goal(rel, args, subst):
  clauses = lookup-relation(rel)
  for each clause:
    fresh-vars = α-rename(clause-params)
    subst' = unify-terms(args, fresh-vars, subst)
    if subst':
      result = solve-goals(clause-body, subst')
      if result: return result          ← first-solution DFS
  return #f                              ← all clauses exhausted
```

### 2.2 What DFS Gets Right

- **Simple**: ~100 lines of Racket for the complete solver
- **Predictable**: Clause ordering determines exploration order, matches Prolog semantics
- **Low overhead**: No infrastructure cost beyond the substitution hasheq
- **First-solution efficient**: For deterministic queries, DFS finds the answer immediately

### 2.3 What DFS Gets Wrong

**No termination guarantee.** Left-recursive relations diverge:
```
defr ancestor [?x ?y]
  &> (parent x y)
  &> (parent x z) (ancestor z y)   ;; recursive — DFS loops if no match
```

**Redundant computation.** Shared subgoals across branches are re-solved from scratch.
If 10 clauses all need `(type ?x)`, that subgoal is evaluated 10 times.

**No constraint interaction.** Unification in one branch can't inform another branch.
If branch A discovers `X = Int` and branch B needs `X`, B starts from scratch.

**Sequential-only.** Each clause is tried one at a time. No opportunity for concurrent
exploration or early pruning across branches.

**Backtracking destroys information.** When a branch fails, all its bindings are lost.
There's no record of *why* it failed — no dependency tracking, no learned clauses.
The same failed combination may be re-explored in a different context.

---

## 3. Existing Infrastructure: What We Already Have

### 3.1 ATMS Data Structure (`atms.rkt`)

A **persistent, immutable ATMS** (Assumption-based Truth Maintenance System):

```racket
(struct atms
  (assumptions    ; hasheq: assumption-id → assumption (name, datum)
   believed       ; hasheq: assumption-id → #t (current worldview)
   nogoods        ; (listof hasheq) — known-inconsistent assumption sets
   amb-groups     ; (listof (listof assumption-id)) — mutual exclusion groups
   cell-data      ; hasheq: cell-id → (listof (value . support-set))
   network        ; prop-network (optional, for cell operations)
   next-assumption ; natural — monotonic counter
   ))
```

**Key operations** (all pure, return new ATMS):
- `atms-assume` — create a new assumption (returns ATMS* + assumption-id)
- `atms-retract` — remove assumption from believed set
- `atms-add-nogood` — record an inconsistent assumption set
- `atms-consistent?` — check if an assumption set is consistent with all nogoods
- `atms-amb` — create N mutually exclusive assumptions (N pairwise nogoods)
- `atms-write-cell` / `atms-read-cell` — worldview-filtered cell access
- `atms-with-worldview` — switch believed set (view different world)

**Critical for Part 3**: `atms-amb` directly maps to clause exploration — each
clause attempt is one of N mutually exclusive alternatives. The ATMS automatically
generates pairwise nogoods preventing belief in two clauses simultaneously.

### 3.2 TMS Cell Infrastructure (`propagator.rkt`)

Propagator cells support TMS-branched values:

- `tms-cell-value` wraps cell values with branch metadata
- `current-speculation-stack` — stack of assumption-ids for nested speculation
- `net-cell-write` routes writes to TMS branches when speculation stack is non-empty
- `net-cell-read` unwraps through TMS branches using current worldview
- `net-commit-assumption` — promote branch values to base (successful speculation)
- `net-retract-assumption` — remove branch values (failed speculation)

### 3.3 Speculation Framework (`speculation.rkt`)

`with-speculative-rollback` already implements the ATMS-hypothesis-per-branch pattern
for **type checking** (Church fold attempts, union type checking):

1. Create ATMS hypothesis for the branch
2. Push hypothesis onto `current-speculation-stack`
3. Run the speculative computation (cell writes go to TMS branches)
4. On success: `net-commit-assumption` promotes branch values
5. On failure: `net-retract-assumption` + `restore-meta-state!` + record nogood
6. **Learned-clause pruning**: Before running a branch, check if the proposed
   assumption set subsumes any known nogood — skip the branch entirely

This is **exactly the pattern** for ATMS-world solver exploration. The difference
is that type-checking speculation is binary (one branch tried at a time) while
solver exploration is N-ary (all clauses explored as parallel worlds).

### 3.4 Stratified Resolution (`resolution.rkt`)

Track 2/7 established stratified quiescence:
- `run-to-quiescence` — fire propagators until worklist is empty
- `run-to-layered-quiescence` — fire through stratified layers
- Strata: S(0) for monotone propagation, S(1) for constraint resolution,
  S(-1) for retraction (Track 7)
- The solver's NAF (`not` goals) requires stratum boundaries — negation observes
  completed lower strata

### 3.5 What Needs to Be Built

| Component | Status | What's Missing |
|-----------|--------|----------------|
| ATMS data structure | ✅ Complete | — |
| TMS-branched cells | ✅ Complete | — |
| Speculation framework | ✅ Complete | N-ary extension (currently binary) |
| Cell-tree unification | 🔄 Part 2 | Data constructor descriptors + solver cells |
| Clause-as-assumption | ❌ New | Map clause selection to `atms-amb` |
| Goal-as-propagator | ❌ New | Map conjunction to propagator scheduling |
| Tabling | ❌ New | SLG resolution for termination + memoization |
| NAF + ATMS interaction | ❌ New | Stratified negation in multi-world context |
| Solution enumeration | ❌ New | Extract surviving worlds as answer stream |

---

## 4. Design: ATMS-World Solver

### 4.1 Core Model: Clauses as Assumptions

```
solve(goal, network):
  clauses = lookup-relation(goal.rel)
  if no clauses: contradiction!

  ;; Create N mutually exclusive clause assumptions
  (atms*, clause-hyps) = atms-amb(network.atms, clause-labels)

  for each (clause, hyp) in zip(clauses, clause-hyps):
    under hyp:
      ;; α-rename: fresh cells for clause variables
      fresh-cells = create-fresh-logic-var-cells(clause.params)

      ;; Unify goal args with clause params via cell-tree (Part 2)
      for each (arg-cell, param-cell) in zip(goal.arg-cells, fresh-cells):
        add-unify-propagator(arg-cell, param-cell)

      ;; Schedule clause body goals as propagators
      for each sub-goal in clause.body:
        schedule-goal-propagator(sub-goal, clause-var-cells)

  run-to-quiescence()

  ;; Solutions = surviving consistent worlds
  return enumerate-consistent-worldviews(atms*)
```

### 4.2 Goals as Propagators

Each goal type becomes a propagator:

**App-goal propagator** (relational call):
```
app-goal-propagator(rel, arg-cells):
  watched: arg-cells (fire when any arg gets more info)
  fire(net):
    ;; Recursive: create nested ATMS-world solve for the sub-relation
    solve(rel-goal(rel, arg-cells), net)
```

**Unify-goal propagator** (structural unification — Part 2):
```
unify-goal-propagator(lhs-cell, rhs-cell):
  ;; This IS the unify-propagator from Part 2
  ;; Decomposes via descriptors, adds sub-cell propagators
```

**Is-goal propagator** (evaluate and bind):
```
is-goal-propagator(var-cell, expr, var-cells):
  watched: var-cells used in expr
  fire(net):
    if all watched cells have values:
      result = evaluate(expr, var-cell-values)
      net-cell-write(var-cell, result)
```

**Not-goal propagator** (NAF — stratified):
```
not-goal-propagator(sub-goal):
  stratum: S(1)  ;; fires only after S(0) quiesces
  fire(net):
    ;; Check if sub-goal has any surviving world
    if no consistent world for sub-goal: succeed (negation holds)
    else: fail (negation violated)
```

### 4.3 Conjunction as Worklist Scheduling

Current DFS folds goals left-to-right. ATMS-world conjunction is different:

```
schedule-conjunction(goals, var-cells, network):
  for each goal in goals:
    create-goal-propagator(goal, var-cells)
    add to network worklist

  ;; Goals fire based on readiness, not textual order
  ;; A goal fires when its watched cells have enough info
  ;; Order emerges from data dependencies, not syntax
```

This is the key semantic shift: **goal ordering becomes data-driven, not syntactically
determined**. A goal that can make progress fires first, regardless of its position
in the clause body.

### 4.4 Backtracking as Nogood Accumulation

DFS backtracking destroys information. ATMS nogoods accumulate it.

When a unification contradiction occurs under assumption set {clause-3, sub-clause-7}:
```
atms-add-nogood(atms, {clause-3, sub-clause-7})
```

This permanently records that clause-3 and sub-clause-7 are incompatible. If any
future exploration proposes believing both, `atms-consistent?` rejects it immediately.

This is **dependency-directed backtracking** — failure prunes exactly the assumptions
that caused it, not just the most recent choice point (which is what DFS does).

### 4.5 Solution Enumeration

After quiescence, solutions are the maximal consistent assumption sets:

```
enumerate-solutions(atms):
  ;; Each amb group has mutually exclusive assumptions
  ;; A "world" is one choice per amb group
  ;; Consistent worlds survive nogood filtering
  for each consistent worldview:
    atms' = atms-with-worldview(atms, worldview)
    bindings = read-all-logic-var-cells(atms')
    yield bindings
```

For `solve` (all solutions): enumerate all consistent worldviews.
For `solve-one` (first solution): find first consistent worldview and stop.

### 4.6 Tabling: SLG Resolution for Termination

Tabling is essential for Part 3 — without it, recursive relations still diverge
(ATMS doesn't help with non-termination, only with backtracking efficiency).

**SLG (Selective Linear resolution with General negation)**:
- **Table**: memo table mapping goal patterns → {answer sets}
- **Leader**: first call to a tabled goal creates a table entry
- **Consumer**: subsequent calls to the same goal pattern consume from the table
- **Completion**: when all consumers are satisfied and no new answers are produced,
  the table is complete

```
tabled-goal-propagator(rel, arg-cells, table-registry):
  goal-key = abstract(arg-cells)  ;; ground the key
  if table-registry has goal-key:
    ;; Consumer: watch the table cell for new answers
    add-table-consumer-propagator(table-registry[goal-key], arg-cells)
  else:
    ;; Leader: create table entry, solve normally, add answers to table
    table-cell = create-table-cell(goal-key)
    table-registry[goal-key] = table-cell
    solve(rel-goal(rel, arg-cells), network)
    ;; Answers propagate to table-cell, which wakes consumers
```

The propagator network naturally handles the SLG completion criterion: when no
propagator can fire (quiescence) and no table has new answers, computation is complete.

### 4.7 Interaction with Stratified Resolution

The RELATIONAL_LANGUAGE_VISION defines three layers:
1. **Propagator Network** (Layer 1): Deterministic, monotone. Cell-tree unification lives here.
2. **ATMS Layer** (Layer 2): Hypothetical reasoning. Clause exploration lives here.
3. **Stratification** (Layer 3): Negation-as-failure, aggregation. Non-monotonic.

Part 3 implements Layer 2. Layers 1 and 3 already exist (Track 2/4/7 + Part 2).

The interaction pattern:
- **Within a stratum**: Layer 1 propagation + Layer 2 world exploration run to quiescence
- **At stratum boundary**: Layer 3 evaluates negation/aggregation, observing the
  completed lower stratum
- **Cross-stratum wake-up**: If negation evaluation at S(1) produces new information,
  it may trigger S(0) propagators, requiring another quiescence cycle

This maps to the existing `run-to-layered-quiescence` loop. Part 3 adds Layer 2
as an inner loop within S(0) quiescence:

```
layered-quiescence():
  loop:
    S(0): fire monotone propagators
          fire ATMS-world solver propagators ← NEW (Layer 2)
          until worklist empty
    S(1): evaluate negation/aggregation
          if new info produced: continue loop
    S(-1): process retractions
    if no strata produced new info: done
```

---

## 5. Gap Analysis: What Must Be Built

### 5.1 N-ary Speculation Extension

**Current**: `with-speculative-rollback` tries one branch at a time (binary choice).
**Needed**: Try N clauses simultaneously as N ATMS worlds.

The existing `atms-amb` creates the assumptions. What's missing is the orchestration:
running all N branches under their respective assumptions and collecting results.

### 5.2 Goal-as-Propagator Framework

**Current**: Goals are functions called sequentially in `solve-goals`.
**Needed**: Goals are propagators added to the network, fired by the worklist.

This requires a `goal-propagator` struct and dispatch logic for each goal type
(app, unify, is, not, cut, guard).

### 5.3 Logic Variable Cells for Solver

Part 2's Phase 5 creates solver cells for the unification substrate. Part 3 needs
these cells to also participate in the propagator worklist — when a cell is written
(variable bound), propagators watching that cell fire.

### 5.4 Tabling Infrastructure

**Current**: No tabling. Pure DFS.
**Needed**: SLG-style tabling with table registry, leader/consumer distinction,
completion detection.

This is the largest new component. XSB Prolog's SLG implementation is well-documented
and maps onto propagator networks (table entries are cells, consumers are propagators
watching those cells).

### 5.5 Cut in ATMS Context

**Current**: `cut` prunes remaining clauses in DFS (simple — stop iterating).
**Needed**: In ATMS context, `cut` means "add nogoods for all remaining clause
assumptions." After `cut`, only the current clause's world survives.

### 5.6 NAF + ATMS Interaction

**Current**: `not` goal calls solver, succeeds if solver fails.
**Needed**: `not` goal in an ATMS world observes the completed lower stratum's
worlds. If the negated goal has any surviving world, the `not` fails.

This requires stratum boundaries between positive and negated goals — the
stratification already provides this, but the ATMS world state must be visible
across strata.

---

## 6. Implementation Phases

### Phase 1: Goal-as-Propagator Framework

**What**: Create `goal-propagator` infrastructure — goal structs, dispatch, watched
cells, fire functions. Start with unify-goal (already exists from Part 2) and
is-goal (simplest new case).

**Files**: New `solver-propagators.rkt`; modified `relations.rkt`

**Test**: Existing solve tests pass through propagator-based goals (toggle).

### Phase 2: N-ary ATMS Clause Exploration

**What**: Replace `solve-app-goal`'s for-each-clause loop with `atms-amb` + per-clause
assumption execution. Each clause's unification and body goals are installed under
that clause's assumption.

**Key**: This is the core architectural shift. After this phase, backtracking is
implicit (nogoods) rather than explicit (try/catch iteration).

**Test**: Simple deterministic relations work. Multi-clause relations produce correct
first solution.

### Phase 3: Solution Enumeration

**What**: Implement `enumerate-consistent-worldviews` for `solve` (all solutions)
and `solve-one` (first solution). Extract logic variable bindings from each
consistent world by reading cells under that worldview.

**Test**: `solve` returns all solutions for multi-clause relations. Order matches
DFS order (backward compatibility).

### Phase 4: Tabling (SLG Core)

**What**: Table registry, leader/consumer propagators, completion detection.
Left-recursive relations terminate.

**This is the largest phase** and should be sub-divided once the design is more
concrete. Key sub-concerns:
- Table entry abstraction (how to key — ground args vs. partial patterns)
- Answer propagation (table cell as a set-valued cell with additive merge)
- Completion detection (when no table has new answers)
- Subsumption checking (avoid redundant table entries)

**Test**: `ancestor` relation terminates. Fibonacci tabling produces correct answers.
SLG completion tests from XSB literature.

### Phase 5: Cut and NAF in ATMS Context

**What**: Implement `cut` as nogood injection. Implement `not` as stratified
observation of ATMS world state.

**Test**: Cut semantics match Prolog. NAF with tabling produces correct WFS answers.

### Phase 6: Integration and Performance

**What**: End-to-end validation. Acceptance file. Performance tuning.

**Test**: Full solve-adversarial benchmark. Acceptance file §B-§L all pass.
Performance within budget.

---

## 7. Performance Considerations

### 7.1 ATMS Overhead

The ATMS is persistent/immutable (CHAMP-based). Each `atms-assume` is one CHAMP insert.
Each `atms-add-nogood` is one list cons. `atms-consistent?` is O(N × M) where N is
the proposed set size and M is the number of nogoods.

For a relation with K clauses and D depth of recursion:
- Assumptions: O(K × D) — one per clause attempt
- Nogoods: O(K × D) worst case — one per failed combination
- Consistency checks: O(K × D × nogoods) — checked before each branch

This is more overhead than DFS's zero infrastructure cost. The compensating factor
is **pruning**: nogoods prevent re-exploring known-bad combinations. For highly
overlapping search spaces (e.g., constraint satisfaction), this is a net win.
For simple fact lookup, it's overhead.

### 7.2 The Toggle Strategy

Like Part 2, Part 3 should have a `current-atms-solver-enabled?` toggle. Simple
`defr` relations (few clauses, no recursion) may be faster with DFS. Complex
relations (recursion, many clauses, constraint interaction) benefit from ATMS.

The toggle can be per-relation (based on analysis of clause structure) or global.

### 7.3 Tabling as Performance Win

Tabling is both a correctness feature (termination) and a performance feature
(memoization). For Datalog-style queries over fact databases, tabling turns
exponential re-derivation into linear-time table lookup.

---

## 8. Risk Analysis

### HIGH: Tabling Complexity

**Risk**: SLG resolution is a complex algorithm. Correct implementation requires
handling of leader/consumer distinction, table completion, and interaction with
negation. Bugs in tabling produce silently wrong answers.

**Mitigation**: Extensive test suite from XSB/SWI-Prolog literature. Incremental
development (positive tabling before negation).

### HIGH: Performance Regression for Simple Queries

**Risk**: ATMS overhead may make simple ground-term lookups slower than DFS.
The solve-adversarial benchmark includes many simple queries.

**Mitigation**: Fast-path — ground queries with single-clause match bypass ATMS
entirely. Toggle for ATMS vs DFS per query.

### MEDIUM: Goal Ordering Semantics

**Risk**: Prolog programs depend on left-to-right goal ordering. ATMS-world
exploration fires goals based on data readiness, potentially changing semantics.

**Mitigation**: Default to left-to-right scheduling within a conjunction (emulate
DFS ordering). Enable data-driven ordering as an opt-in optimization.

### MEDIUM: ATMS Scaling with Deep Recursion

**Risk**: Deep recursive relations create many assumptions and nogoods. ATMS
consistency checking becomes O(N²) in the worst case.

**Mitigation**: Tabling bounds recursion depth. Nogood subsumption (remove
subsumed nogoods) keeps the nogood list manageable.

### LOW: Interaction with Part 2 Cell-Trees

**Risk**: Part 3 expects Part 2's cell-tree infrastructure to be stable. If Part 2
has bugs in data constructor descriptors, Part 3 inherits them.

**Mitigation**: Part 2 is a strict prerequisite. Part 3 doesn't start until Part 2's
acceptance file passes at Level 3.

---

## 9. Open Questions

### Q1: Tabling Granularity

Should all `defr` relations be tabled by default (as RELATIONAL_LANGUAGE_VISION
proposes) or opt-in? Default tabling is correct but may have memory cost for
relations that produce infinite answer sets.

**Recommendation**: Default tabled. `defr :no-table` for opt-out. This matches
the vision document and ensures termination by default.

### Q2: DFS Compatibility Mode

Should the ATMS solver produce solutions in the same order as DFS? This matters
for backward compatibility and Prolog-style programs that depend on first-solution
semantics.

**Recommendation**: Yes, for `solve-one`. The clause ordering determines the
preference order of assumptions. `solve` (all solutions) may enumerate in a
different order.

### Q3: ATMS Per-Command or Persistent?

Should the ATMS state persist across commands (accumulating learned nogoods) or
reset per command?

**Recommendation**: Per-command initially. Persistent ATMS would require the
persistent registry network (Track 7), and learned nogoods from one command
may not apply to the next (different relation definitions).

### Q4: Solver Network Isolation

Should the solver operate on the main elab-network or a separate solver-specific
prop-network?

**Recommendation**: Separate solver network per `solve` invocation. This provides
clean isolation — solver cell state doesn't pollute the elaborator's type cells.
Part 2's Phase 5a already creates solver-specific prop-networks.

---

## 10. Theoretical Connections

### 10.1 Forbus & de Kleer (1993)

*Building Problem Solvers* — Chapter 11 describes ATMS-based logic programming.
Each clause is an assumption. Conjunction creates compound labels. Nogoods
implement intelligent backtracking. Our implementation follows this architecture
with modern persistent data structures (CHAMP) replacing their mutable hash tables.

### 10.2 XSB Prolog / SLG Resolution

Swift & Warren (1994) — *Efficient Bottom-Up Computation of Queries on Stratified
Databases*. SLG resolution provides the tabling algorithm. Our propagator network
naturally handles the table-consumer wake-up pattern (table entries are cells,
consumers are propagators).

### 10.3 Well-Founded Semantics (WFS)

The three-stratum model (S(0), S(1), S(-1)) aligns with WFS's three-valued logic:
true (proven in S(0)), false (negation succeeds in S(1)), unknown (neither stratum
produces a definitive answer). This connection was already identified in the WF-LE
architecture (Layered Recovery Principle).

### 10.4 Constraint Logic Programming (CLP)

The ATMS-world solver naturally supports CLP extensions. Constraints are propagators
on solver cells. The `#=` narrowing operator (Part 1) is already a constraint
propagator. Part 3 brings the search strategy into alignment — CLP's constraint-and-
search model IS propagators + ATMS.

---

## 11. Dependencies and Enabling

**Depends on**:
- Part 2 complete (cell-tree unification for both systems, descriptor registry)
- Track 7 complete (two-network architecture, stratified resolution)
- Track 4 complete (TMS/ATMS infrastructure)

**Does NOT depend on**:
- Track 8 second half (mult bridges, id-map migration)
- Track 9 (GDE)
- Track 10 (LSP)

**Enables**:
- Tabling — the prerequisite for scalable Datalog-style queries
- Well-Founded Semantics — three-valued logic for the relational sublanguage
- CLP integration — constraints naturally compose with ATMS-world search
- Provenance — ATMS support sets give every derived fact a justification chain
- `solve-with` — the RELATIONAL_LANGUAGE_VISION's solver-configuration combinator
- Graph-query database patterns from RELATIONAL_LANGUAGE_VISION

---

## 12. Key Files

| File | Role in Part 3 |
|------|---------------|
| `solver-propagators.rkt` | **NEW** — Goal-as-propagator framework |
| `relations.rkt` | Primary target — DFS solver → ATMS solver |
| `atms.rkt` | ATMS data structure (existing, may need extensions) |
| `speculation.rkt` | Speculation framework (extend for N-ary) |
| `ctor-registry.rkt` | Constructor descriptors (from Part 2) |
| `propagator.rkt` | TMS cells, worklist, quiescence |
| `resolution.rkt` | Stratified resolution loop |
| `elaborator-network.rkt` | Cell creation, decomposition registry |
| `benchmarks/micro/bench-solve-pipeline.rkt` | Micro-benchmarks (existing) |
| `benchmarks/comparative/solve-adversarial.prologos` | End-to-end benchmark (14.3s) |
| `examples/2026-03-19-punify-acceptance.prologos` | Acceptance file |

---

## 13. Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 1 | Goal-as-propagator framework | ⬜ | |
| 2 | N-ary ATMS clause exploration | ⬜ | |
| 3 | Solution enumeration | ⬜ | |
| 4 | Tabling (SLG core) | ⬜ | Largest phase — subdivide |
| 5 | Cut and NAF in ATMS context | ⬜ | |
| 6 | Integration and performance | ⬜ | |
