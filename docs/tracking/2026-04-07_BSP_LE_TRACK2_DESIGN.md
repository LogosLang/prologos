# BSP-LE Track 2: ATMS Solver + Cell-Based TMS — Stage 3 Design

**Date**: 2026-04-07
**Series**: BSP-LE (Logic Engine on Propagators)
**Scope**: Cell-Based TMS (folding Track 1.5) + ATMS Solver + Non-Recursive Tabling
**Status**: D.1 — first draft, pre-critique
**Stage 1/2**: [Research + Audit](../research/2026-04-07_BSP_LE_TRACK2_STAGE1_AUDIT.md)
**Prior art**: [Logic Engine Design](2026-02-24_LOGIC_ENGINE_DESIGN.org) §4-7, [PUnify Part 3](2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md), [Cell-Based TMS Note](../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md)

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Pre-0: benchmarks + acceptance file | ⬜ | Baseline DFS solver perf |
| 1 | Worldview lattice cell (Option E) | ⬜ | Boolean algebra on powerset |
| 2 | PU-per-branch lifecycle | ⬜ | Create from parent, commit, drop |
| 3 | Filtered nogood watcher (RKan) | ⬜ | Per-branch intersection-filtered bridge |
| 4 | Speculation migration | ⬜ | 5 files: elab-speculation-bridge, metavar-store, cell-ops, typing-propagators, narrowing |
| 5 | ATMS↔worldview bridge | ⬜ | Unify two-layer TMS into one |
| 6 | Clause-as-assumption in PUs | ⬜ | New solver path replacing DFS |
| 7 | Goal-as-propagator dispatch | ⬜ | Propagator installation per goal type |
| 8 | Producer/consumer tabling | ⬜ | Table registry check in goal dispatcher |
| 9 | Two-tier activation | ⬜ | Tier 1→2 on first `amb` |
| 10 | Solver config wiring | ⬜ | `:strategy`, `:execution`, `:tabling` operational |
| 11 | Parity validation | ⬜ | DFS ↔ ATMS result equivalence |
| T | Dedicated test files | ⬜ | Per-phase |
| PIR | Post-implementation review | ⬜ | |

---

## §1 Objectives

**End state**: The logic engine's search, branching, and memoization operate entirely on the propagator network. Choice points are ATMS assumptions in worldview lattice cells. Branch isolation is structural (PU-per-branch). Nogood propagation is demand-driven (filtered right Kan extension). Backtracking is nogood accumulation. Tabling is producer/consumer propagators on accumulator cells. The `solver-config` knobs are operational. The DFS solver (`solve-goals` at `relations.rkt:600`) is retired as the default path.

**What changes**: DFS `append-map` → propagator quiescence. Sequential clause iteration → concurrent PU-per-branch exploration. Explicit substitution threading → implicit propagation through cells. `current-speculation-stack` parameter → worldview lattice cells.

**What doesn't change**: Cell-tree unification substrate (Part 2). Constructor descriptor registry. User-facing `solve`/`defr`/`explain` syntax. Relation registration and clause storage. `solver-config` struct and key set.

---

## §2 Algebraic Foundation: Worldview Lattice

### §2.1 The Lattice

The worldview is a **powerset lattice** over assumption-ids — a Boolean algebra.

```
Lattice:  (P(AssumptionId), ⊆)
⊥:        ∅                          (no commitments)
⊤:        U                          (all assumptions — typically contradicted)
Meet:     set-intersection           (conservative: what both agree on)
Join:     set-union                  (liberal: what either believes)
Tensor:   set-union                  (combining commitments = union)
```

**Properties**: Boolean, distributive, complemented, Heyting, frame.

This is the strongest possible lattice structure. Boolean algebra gives:
- Negation (complement): "everything except these assumptions"
- Distributivity: meets and joins interact cleanly
- Heyting implication: A → B = ¬A ∪ B
- De Morgan duality: ¬(A ∧ B) = ¬A ∨ ¬B — relevant for negation-as-failure at the worldview level

### §2.2 Nogoods and the Consistency Filter

Nogoods define forbidden subsets. A worldview W is contradicted iff `∃ N ∈ nogoods . N ⊆ W`.

The consistent worldviews form a **downward-closed set** (order ideal):
- Closed under meet (∩): removing assumptions can't create a nogood
- NOT closed under join (∪): combining assumptions from different branches might include a nogood

The nogood set is a separate lattice cell with set-union merge (monotone: nogoods only accumulate).

### §2.3 Stratification

| Operation | Stratum | Monotonicity | Justification |
|---|---|---|---|
| Add assumption (extend worldview) | S0 | Monotone | ⊆ grows |
| Accumulate nogood | S0 | Monotone | nogood set grows |
| Detect contradiction | S0 | Monotone | consistent → contradicted is upward |
| Retract assumption (prune branch) | S(-1) | Non-monotone | ⊆ shrinks |
| Commit branch (promote to base) | S(-1) | Non-monotone | restructures TMS tree |
| PU drop (garbage-collect branch) | S(-1) | Non-monotone | removes topology |

### §2.4 SRE Domain Registration

```racket
;; In sre-core.rkt or a new sre-worldview.rkt
(define worldview-sre-domain
  (make-sre-domain
   #:name 'worldview
   #:lattice-bot (seteq)
   #:lattice-top 'worldview-top  ;; sentinel — all assumptions
   #:merge set-union
   #:contradicts? (lambda (wv nogoods)
                    (for/or ([ng (in-list nogoods)])
                      (subset? ng wv)))
   ;; Properties declared via Track 2G infrastructure
   #:properties '(boolean distributive complemented heyting frame)))
```

### §2.5 Galois Connections to Other Domains

| Source | Target | Bridge | Direction |
|---|---|---|---|
| Worldview | Type lattice | Assumption gates type: under W, meta ?x has type T | W → Type |
| Worldview | Term lattice | Assumption gates term: under W, solver var ?y = V | W → Term |
| Worldview | Constraint lattice | Worldview activates constraints | W → Constraints |
| Nogood set | Worldview | Filtered nogood → contradiction | Nogoods → W (RKan) |

---

## §3 NTT Model

### §3.1 Lattice Declarations

```
lattice Worldview
  :type  (Set AssumptionId)
  :bot   (set-empty)
  :top   assumption-universe
  :meet  set-intersection
  :join  set-union
  :properties [:boolean :distributive :complemented :heyting :frame]

impl Lattice Worldview
  merge [a b] := [set-union a b]
  bot?  [w]   := [set-empty? w]

lattice NogoodSet
  :type  (Set (Set AssumptionId))
  :bot   (set-empty)
  :join  set-union
  :merge set-union
```

### §3.2 Cell Declarations

```
cell worldview-base : Worldview
  :writes [tier2-activator, branch-creator]
  :reads  [all-propagators-at-depth-0]

cell worldview-B : Worldview                      ;; one per branch B
  :writes [branch-creator]
  :reads  [PU-B-propagators, nogood-watcher-B]

cell nogoods : NogoodSet
  :writes [contradiction-detectors...]
  :reads  [nogood-watchers...]

cell table-answers-P : (Set Answer)               ;; one per tabled predicate P
  :writes [producer-P]
  :reads  [consumers-P...]
  :merge  set-union                               ;; answers only accumulate
```

### §3.3 Propagator Declarations

```
propagator branch-creator                          ;; atms-amb
  :inputs  [worldview-parent]
  :outputs [worldview-B1 ... worldview-BN, nogoods]
  :fire    Create N PUs, each extending parent worldview with one assumption.
           Record pairwise mutual-exclusion nogoods.
  :topology-mutation yes                           ;; CALM: stratified topology protocol
  :stratum S0 (request), topology-stratum (execution)

propagator filtered-nogood-watcher                 ;; right Kan extension (one per branch)
  :inputs  [nogoods]
  :outputs [worldview-B]
  :guard   (any? (λ (ng) (intersects? ng assumptions-B)) new-nogoods)
  :fire    Write 'contradicted to worldview-B
  :stratum S0

propagator contradiction-detector                  ;; inside PU-B
  :inputs  [some-cell-in-PU-B]
  :outputs [nogoods]
  :guard   (= val lattice-top)
  :fire    Write (set assumptions-of-B) to nogoods
  :stratum S0

propagator branch-pruner                           ;; S(-1) retraction
  :inputs  [worldview-B]
  :outputs [PU-B-lifecycle]
  :guard   (= wv 'contradicted)
  :fire    Drop PU-B (structural GC)
  :stratum S(-1)

propagator branch-committer                        ;; S(-1) commitment
  :inputs  [worldview-B, result-cell-B]
  :outputs [parent-result-cell]
  :guard   (and (consistent? wv) (not (bot? result)))
  :fire    Commit PU-B: promote values to parent, dissolve PU
  :stratum S(-1)

propagator goal-app                                ;; clause dispatch
  :inputs  [relation-cell, arg-cells...]
  :outputs [result-cell]
  :fire    Lookup matching clauses.
           If tabled: check table registry (producer/consumer).
           If single clause: install directly (no amb, Tier 1).
           If multiple: atms-amb → branch-creator → PU per clause.
  :stratum S0

propagator table-producer                          ;; first call to tabled pred
  :inputs  [clause-body-cells...]
  :outputs [table-answers-P]
  :fire    Derive answers from clause body, write to accumulator
  :stratum S0

propagator table-consumer                          ;; subsequent calls to tabled pred
  :inputs  [table-answers-P]
  :outputs [result-cell]
  :fire    Read answers from accumulator, propagate to local result
  :stratum S0
```

### §3.4 NTT ↔ Racket Correspondence Table

| NTT Construct | Racket Implementation | File |
|---|---|---|
| `lattice Worldview` | `worldview-merge`, `worldview-bot`, `worldview-contradicts?` | propagator.rkt (new) |
| `lattice NogoodSet` | `nogood-merge` (= `set-union`) | propagator.rkt (new) |
| `cell worldview-B` | `net-new-cell net (seteq) worldview-merge` | propagator.rkt |
| `cell nogoods` | `net-new-cell net (seteq) nogood-merge` | propagator.rkt |
| `cell table-answers-P` | `table-register ts name 'all` | tabling.rkt (existing) |
| `propagator branch-creator` | `atms-amb-on-network` (new) | relations.rkt or atms.rkt |
| `propagator filtered-nogood-watcher` | `install-nogood-watcher net nogoods-cid wv-cid assumptions` | propagator.rkt (new) |
| `propagator contradiction-detector` | Extension of existing `net-cell-write` contradiction path | propagator.rkt |
| `propagator branch-pruner` | `pu-drop` (new) | propagator.rkt |
| `propagator branch-committer` | `pu-commit` / `tms-commit` integration | propagator.rkt |
| `propagator goal-app` | `install-goal-propagator` case `:app` | relations.rkt (new) |
| `propagator table-producer` | `install-table-producer` | relations.rkt / tabling.rkt |
| `propagator table-consumer` | `install-table-consumer` | relations.rkt / tabling.rkt |
| `current-speculation-stack` (RETIRED) | Worldview cell read inside fire functions | propagator.rkt |
| PU-per-branch | `make-branch-pu parent-net worldview-cid` (new) | propagator.rkt |

---

## §4 Phase Design: Phases 0–5

### Phase 0: Pre-0 Benchmarks + Acceptance File

**Deliverables**:
- `benchmarks/comparative/solve-adversarial.prologos`: baseline DFS solver performance (current: 14.3s)
- `racket/prologos/examples/2026-04-07-bsp-le-track2.prologos`: acceptance file exercising solver features in ideal WS syntax
- Benchmark the existing DFS solver path via `bench-ab.rkt`

**Acceptance file sections** (commented out initially, uncommented as phases complete):
- Basic `solve` with ground facts
- Multi-clause `defr` with backtracking
- Tabled predicate (non-recursive)
- Solver config: `:strategy :auto`, `:strategy :depth-first`
- Explanation/provenance query

### Phase 1: Worldview Lattice Cell (Option E)

**What changes**:

1. **`propagator.rkt`**: Add worldview lattice infrastructure:
   - `worldview-merge`: `set-union` on `seteq` sets
   - `worldview-bot`: `(seteq)` (empty set)
   - `worldview-bot?`: `(hash-empty? wv)`
   - `worldview-contradicts?`: checks worldview against a nogood set
   - `nogood-merge`: `set-union` on sets of sets

2. **`propagator.rkt`**: Add per-network worldview cell slot:
   - `prop-net-cold` gains a `worldview-cid` field (or `#f` for Tier 1 networks)
   - `net-cell-read` checks: if `worldview-cid` is set, use it for TMS navigation instead of `(current-speculation-stack)`
   - `net-cell-write` same change
   - Both fall back to `(current-speculation-stack)` when `worldview-cid` is `#f` — backward compatibility for Tier 1

3. **`propagator.rkt`**: Add nogood cell infrastructure:
   - `net-new-nogood-cell`: creates a cell with `nogood-merge`
   - Nogood cell id stored alongside worldview cell id in `prop-net-cold`

**Key design decision**: The worldview cell is a REGULAR cell in the prop-network, created by `net-new-cell` with `worldview-merge`. It participates in the normal cell infrastructure — no special-casing except that `net-cell-read`/`net-cell-write` know to read it for TMS navigation.

**Test coverage**: Worldview cell creation, merge (union is idempotent), bot detection, contradiction detection against nogoods.

**Network Reality Check**:
1. `net-new-cell` calls: worldview cell, nogood cell
2. `net-cell-write` produces result: worldview written via cell write, read back via cell read
3. Cell creation → write → read = worldview value: yes

### Phase 2: PU-Per-Branch Lifecycle

**What changes**:

1. **`propagator.rkt`**: `make-branch-pu`:
   - Creates a new `prop-network` that reads specified parent cells as inputs
   - The branch PU has its own worldview cell (extending parent's worldview with the branch assumption)
   - Returns `(values branch-net worldview-cid)` — the branch network and its worldview cell

2. **`propagator.rkt`**: `pu-drop`:
   - Drops a branch PU — removes all references. O(1): just discard the branch network reference.
   - The parent network is unchanged (persistent/immutable — the branch network was a derivative, not a mutation).

3. **`propagator.rkt`**: `pu-commit`:
   - Promotes branch cell values to the parent network via `tms-commit` for each cell that was written in the branch.
   - Dissolves the PU structure — branch-specific cells are merged into parent.

**Key design decision**: A branch PU is a `prop-network` value (not a separate struct). It shares the parent's cell values via CHAMP structural sharing. Branch-specific writes go to branch-local CHAMP nodes. `pu-drop` = discard the reference. `pu-commit` = merge branch CHAMP into parent CHAMP.

**Interaction with existing PU infrastructure**: Track 4B's `infer-on-network` already creates per-command typing on the main network with P3 cleanup. Branch PUs are a different pattern — they're ephemeral sub-networks with parent-cell visibility, not scoped regions of a shared network. The two patterns coexist.

**Test coverage**: PU creation from parent, cell visibility (parent cells readable from branch), branch-local writes invisible to parent, pu-drop (branch garbage-collected), pu-commit (branch values promoted).

### Phase 3: Filtered Nogood Watcher (Right Kan Extension)

**What changes**:

1. **`propagator.rkt`**: `install-nogood-watcher`:
   - `(install-nogood-watcher net nogoods-cid worldview-cid branch-assumptions)`
   - Creates one propagator per branch that watches the nogood cell
   - Fire function: read nogoods, filter by intersection with `branch-assumptions`, if any match → write `'contradicted` to the branch's worldview cell
   - Component-path: watches `nogoods-cid` (the entire cell, not a sub-path — nogoods are flat sets)

2. **Integration with PU lifecycle**: When a branch PU is created (Phase 2), `install-nogood-watcher` is called to bridge the shared nogood cell to the branch's worldview cell. When the branch is dropped, the watcher propagator is dropped with the PU (structural GC).

**Cost analysis** (from Stage 1/2 §4.2a):
- Per nogood discovery: O(branches) intersection checks, each O(|nogood|)
- Per affected branch: propagators see contradiction and stop
- Per unaffected branch: nothing happens
- Total: O(branches × |nogood|) for filtering + O(affected_propagators) for reaction

**This IS the right Kan extension**: of all information in the nogood cell, forward to branch B only what B has demanded (nogoods involving B's assumptions).

**Test coverage**: Watcher fires on relevant nogood, doesn't fire on irrelevant nogood, multiple branches each with own watcher, cascading nogoods.

### Phase 4: Speculation Migration

**What changes** (5 files, backward-compatible):

1. **`elab-speculation-bridge.rkt`**: Replace `(parameterize ([current-speculation-stack (cons hyp-id (current-speculation-stack))]) ...)` with worldview cell write + fire function that reads worldview from cell. The `with-speculative-rollback` wrapper reads the worldview cell instead of the parameter.

2. **`metavar-store.rkt`** (line 1321): Replace `(define stack (current-speculation-stack))` with a worldview cell read when available, parameter fallback when not.

3. **`cell-ops.rkt`** (lines 82-83): Replace `(current-speculation-stack)` check with worldview cell read. The `worldview-visible?` function already exists — it just needs to read from a cell instead of a parameter.

4. **`typing-propagators.rkt`**: The Phase 8 union branching code (lines 1571-1589) already uses `parameterize` around fire functions. Replace with worldview cell input to the fire function.

5. **`narrowing.rkt`**: Or-nodes that use `atms-amb` currently install propagators under `parameterize`. Replace with PU-per-branch from Phase 2.

**Migration strategy**: Each file gets an optional worldview-cell-id parameter. When present, read worldview from cell. When absent, fall back to `(current-speculation-stack)`. This allows incremental migration — files migrate one at a time, and the test suite stays green throughout.

**`current-speculation-stack` is NOT removed in this phase** — it remains as fallback. Phase 9 (two-tier activation) makes the worldview cell the default. The parameter is removed in a cleanup sub-phase after all consumers are migrated.

**Test coverage**: Each migrated file passes existing tests (behavioral parity). New tests verify worldview cell read produces same results as parameter read.

### Phase 5: ATMS↔Worldview Bridge

**What changes**:

The Stage 1/2 audit (§4.1) identified two separate TMS mechanisms:
1. Cell-level TMS (`tms-cell-value` in propagator.rkt)
2. ATMS-level TMS (`atms-read-cell`/`atms-write-cell` in atms.rkt)

Phase 5 unifies them.

1. **`atms.rkt`**: `atms-worldview-cell`:
   - New function: given an ATMS and its believed set, create/update a worldview lattice cell whose value is the believed assumption set.
   - `atms-amb` now creates worldview cells (via Phase 2's `make-branch-pu`) instead of just returning hypothesis lists.
   - `atms-read-cell` / `atms-write-cell` are reimplemented as `net-cell-read` / `net-cell-write` on the worldview-aware network — the ATMS no longer maintains its own parallel cell map.

2. **`atms.rkt`**: Retire the `tms-cells` field from the `atms` struct:
   - The ATMS struct currently has: `network`, `assumptions`, `nogoods`, `tms-cells`, `next-assumption`, `believed`
   - After Phase 5: `tms-cells` is removed. Cell values live in the prop-network (where they belong). The ATMS manages assumptions, nogoods, and believed set — worldview management, not cell storage.

3. **Bridge propagator**: When the ATMS `believed` set changes (e.g., after `atms-add-nogood` prunes a worldview), write the new believed set to the worldview cell. This is a bridge from ATMS operations (which are still imperative — `atms-add-nogood` returns a new ATMS value) to the propagator network (where the worldview cell reflects the current state).

**Key architectural decision**: The ATMS remains a persistent value (CHAMP-backed, pure operations). But its cell storage is delegated to the prop-network. The ATMS is a worldview MANAGER; the prop-network is the cell STORE. One mechanism, not two.

**Test coverage**: ATMS `amb` creates worldview cells. ATMS cell reads go through prop-network. ATMS nogood prunes worldview cell. Existing ATMS tests pass (behavioral parity).

---

## §5 WS Impact

This track does NOT add or modify user-facing Prologos syntax. The surface forms (`solve`, `defr`, `explain`, `solver`) are unchanged. The changes are entirely in the engine underneath.

WS impact: **none**. No preparse changes, no reader changes, no keyword conflicts.

---

## §6 Phase Design: Phases 6–11

### Phase 6: Clause-as-Assumption in PUs

**What this replaces**: `solve-app-goal` (relations.rkt:825-893) — the inner loop that iterates clauses via `append-map`, α-renames, unifies arguments, and recurses on clause bodies.

**What changes**:

1. **`relations.rkt`**: New function `install-clause-propagators`:
   - For a given relation call `(rel-name arg1 arg2 ...)`:
   - Look up relation in store → get variants → get facts + clauses
   - **Facts path** (no branching): For each fact row, install a unification propagator that unifies resolved args with fact terms. Facts are deterministic — no `amb`, no PU. Write results directly to the result accumulator cell.
   - **Single-clause path** (no branching): If only one clause matches, install it directly in the current network. No `amb`, no PU overhead. This IS Tier 1 behavior — deterministic queries never touch ATMS.
   - **Multi-clause path** (branching): Call `atms-amb-on-network` to create N branch PUs (one per clause). Each PU gets:
     - A worldview cell extending parent with this clause's assumption
     - α-renamed fresh variable cells for this clause
     - Unification propagators: arg cells ↔ fresh param cells
     - Sub-goal propagators installed recursively for the clause body
     - A filtered nogood watcher bridging the shared nogood cell

2. **`relations.rkt`**: New function `atms-amb-on-network`:
   - Creates N PUs via Phase 2's `make-branch-pu`
   - Records pairwise mutual-exclusion nogoods
   - Installs filtered nogood watchers (Phase 3)
   - Returns the list of `(branch-pu . worldview-cid)` pairs

3. **Variable representation**: Logic variables become cells in the branch PU's network (not symbols in a hasheq). `?x = suc ?y` becomes: write `(suc cell-y)` to `cell-x`. This is the cell-tree model from PUnify Part 2 — variables ARE cells, unification IS cell writes.

**Key architectural point**: The DFS `solve-goals` function threading substitutions through recursive `append-map` is GONE. Conjunction becomes network topology: goal A's output cells are goal B's input cells. The propagator network handles evaluation order via quiescence — goals fire when their inputs have information, not when a sequential scheduler reaches them.

**Test coverage**: Single-clause dispatch (no PU), multi-clause dispatch (PU-per-clause), fact matching, clause body recursion, variable freshening as cell creation.

### Phase 7: Goal-as-Propagator Dispatch

**What this replaces**: `solve-single-goal` (relations.rkt:612-703) — the dispatch on goal kind.

**What changes**:

1. **`relations.rkt`**: New function `install-goal-propagator`:
   - Dispatches on goal kind, installs appropriate propagator:

   | Goal Kind | Propagator | Inputs | Outputs | Notes |
   |---|---|---|---|---|
   | `app` | Phase 6's `install-clause-propagators` | arg cells | result cell | May create PUs |
   | `unify` | Unification propagator | lhs cell, rhs cell | (constraint) | Cell-tree unify: write to cells |
   | `is` | Evaluation propagator | expr cell | var cell | Evaluate functional expr, write to var |
   | `not` | NAF propagator | inner goal result | negated result | S1: fires after inner goal quiesces |
   | `guard` | Guard propagator | condition cell | gate | S1: gates subsequent goals on condition |

2. **Conjunction as topology**: `solve-goals` (the recursive append-map) is replaced by `install-conjunction`:
   - Takes a list of goals and a parent network/PU
   - Installs goal propagators in sequence, chaining output→input
   - The "sequencing" is implicit in cell dependencies, not explicit in call order
   - If goal A writes to cell C, and goal B reads cell C, B fires after A — no explicit ordering needed

3. **NAF as stratum**: Negation-as-failure is inherently non-monotone (succeed if inner FAILS). This is S1 — fires after S0 quiesces. The inner goal is installed as S0 propagators. The NAF propagator is an S1 readiness-triggered propagator that checks: did the inner goal's result cell reach a value (inner succeeded → NAF fails) or stay at ⊥ (inner failed → NAF succeeds)?

   Integration with WF engine: if `(current-naf-oracle)` is set, the NAF propagator consults the bilattice oracle first. The 3-valued result (succeed/fail/defer) determines behavior without needing to evaluate the inner goal.

**Key architectural point**: Every goal type becomes a propagator installation. The goal dispatcher is a match on goal kind → propagator constructor call. This is data-oriented: adding a new goal type = adding one match case, not modifying a recursive evaluation function.

**Test coverage**: Each goal type in isolation, conjunction chaining, NAF (inner succeeds → fail, inner fails → succeed), guard (true → proceed, false → block).

### Phase 8: Producer/Consumer Tabling

**What changes**:

1. **`relations.rkt`**: Modify `install-clause-propagators` (Phase 6) to check table registry:
   - Before installing clauses for a relation call, check: `(table-complete? ts rel-name)`
   - If complete: install a **consumer** — read from table accumulator cell, no clause installation
   - If active (producer exists but not complete): install a **consumer** — same
   - If not registered: check `(relation-info-tabled? rel)` and `(solver-config-tabling config)`
     - If should table: call `table-register`, install a **producer** (clause propagators that write to the table cell instead of / in addition to the result cell)
     - If not: install clauses normally (Phase 6)

2. **`tabling.rkt`**: `install-table-producer`:
   - Wraps Phase 6's clause installation with an additional write: answers are written to the table accumulator cell via `table-add`
   - The table cell uses `all-mode-merge` (set-union) — answers only accumulate
   - Producer propagators fire and write answers; the cell monotonically grows

3. **`tabling.rkt`**: `install-table-consumer`:
   - Installs a propagator that reads from the table accumulator cell
   - When the table has answers, propagates them to the local result cell
   - Consumer doesn't install any clause propagators — it free-rides on the producer's work

4. **Non-recursive completion**: A table is "complete" when its accumulator cell has quiesced — no new answers after a full BSP round. Detection: after `run-to-quiescence`, check if any table cell was written during the last round. If not, mark all active tables as complete.

**What's NOT in scope**: Left-recursive tabling (where predicate A calls A during its own derivation). This requires SLG completion frames — a stack of "active tables" with inter-table dependency tracking. Deferred to BSP-LE Track 3.

**Test coverage**: Non-recursive tabled predicate (memoizes), consumer reads producer's answers, table completion detection, tabled + non-tabled predicates coexist.

### Phase 9: Two-Tier Activation

**What changes**:

1. **`relations.rkt`**: The entry point `solve-goal` (or its replacement) checks `:strategy`:
   - `:depth-first` → use the DFS path (existing `solve-goals`, preserved for backward compatibility)
   - `:atms` → create worldview cell + ATMS from the start, use propagator path
   - `:auto` (default) → start in Tier 1 (plain prop-network), upgrade on first multi-clause match

2. **Tier 1 → Tier 2 transition**:
   - Tier 1: No worldview cell. Single-clause matches install directly. Facts unify directly. The solver-env is a plain prop-network.
   - First multi-clause match detected → upgrade:
     - Create worldview cell on the network
     - Set `worldview-cid` in `prop-net-cold`
     - Create nogood cell
     - Proceed with `atms-amb-on-network` for this and all subsequent multi-clause matches
   - The transition is O(1) — create two cells, set a field. No cell scanning, no value wrapping.

3. **Existing cells continue to work**: Cells created during Tier 1 are plain values. When `net-cell-read` detects `worldview-cid` is now set, it checks if the cell value is a `tms-cell-value`. If not (plain Tier 1 value), it returns it directly — the Tier 1 value is the base (depth-0) value. TMS reads with `'()` stack return base directly. No wrapping needed.

**Test coverage**: `:strategy :depth-first` produces same results as current DFS. `:strategy :auto` produces same results. `:strategy :atms` produces same results. Tier 1→2 transition mid-query (first few goals deterministic, later goal has choice point).

### Phase 10: Solver Config Wiring

**What changes**:

1. **`solver.rkt` / `relations.rkt`**: Make knobs operational:

   | Knob | Currently | After Phase 10 |
   |---|---|---|
   | `:strategy` | Ignored (always DFS) | Routes to DFS / propagator / auto path |
   | `:execution` | Partially wired | `:parallel` uses `run-to-quiescence-bsp`, `:sequential` uses `run-to-quiescence` |
   | `:tabling` | Ignored | `:by-default` tables all `defr`; `:off` skips tabling |
   | `:timeout` | Respected | Unchanged |
   | `:provenance` | Ignored | `:atms` enables ATMS derivation trees (the ATMS already records these) |
   | `:semantics` | Respected (WF oracle) | Unchanged — WF oracle path already works |

2. **`:execution :parallel` integration**: When strategy is `:atms` or `:auto` (Tier 2), and execution is `:parallel`, worldview exploration uses `run-to-quiescence-bsp`. Multiple PU branches fire in the same BSP superstep. The `:threshold` parameter gates parallelism — if fewer than N runnable propagators, run sequentially.

3. **Pre-defined configurations**: Wire the four configurations from PUnify Part 3 §3.3:
   - `default-solver`: `:parallel`, `:auto`, `:by-default` tabling
   - `sequential-solver`: `:sequential`, `:auto`, `:by-default`
   - `debug-solver`: `:sequential`, `:auto`, `:full` provenance
   - `depth-first-solver`: `:sequential`, `:depth-first`, `:off` tabling

**Test coverage**: Each configuration produces correct results. `:parallel` vs `:sequential` produce same answers (determinism). `:tabling :off` does not table. `:tabling :by-default` tables all tabled predicates.

### Phase 11: Parity Validation

**What changes**:

1. **Full test suite with both engines**: Run every existing solver test under both `:strategy :depth-first` (DFS, existing behavior) and `:strategy :auto` (new propagator engine). Results must be identical (same answers, possibly different order).

2. **Solve-adversarial benchmark**: Run via `bench-ab.rkt` comparing DFS baseline vs new engine. Acceptance criteria: <15% regression.

3. **Acceptance file validation**: Run `examples/2026-04-07-bsp-le-track2.prologos` at Level 3 (`process-file`). All sections must pass.

4. **Edge cases**:
   - Empty relation (no facts, no clauses) → fail
   - Single-fact relation → succeed, no ATMS
   - Deeply nested recursion → tabling prevents divergence (non-recursive cases)
   - Contradictory goals → empty result set
   - NAF with WF oracle → 3-valued behavior preserved

**Test coverage**: Parity tests, benchmark comparison, acceptance file, edge cases.

---

## §6a Naming: Propagator-Native Search

The search mechanism in this design is not "backtracking" — there is no going back. The operational model:

1. **Branch forward**: Choice point creates concurrent PUs
2. **Observe failure**: Contradiction detection, monotone at S0
3. **Record failure**: Nogood accumulation, monotone
4. **Propagate**: Filtered routing to affected branches (right Kan extension)
5. **Prune**: Branch drop at S(-1), structural GC
6. **Continue**: Surviving branches proceed

Information flows exclusively forward. The only non-monotone step (pruning) is structurally isolated at S(-1). Candidate names:

- **Propagator-native search**: the search strategy is the network's natural behavior under monotone information flow
- **Forward-only search with nogood propagation**: describes the information flow direction
- **Monotone branch pruning**: describes the mechanism
- **Lattice-directed elimination**: describes the algebra

The design uses "propagator-native search" throughout. The DFS path (`:strategy :depth-first`) retains "backtracking" terminology for backward compatibility with Prolog semantics.

---

## §7 Dependencies and Cross-References

| Dependency | Status | Impact |
|---|---|---|
| BSP scheduler (PAR Track 1) | ✅ | BSP is production default. CALM topology protocol exists. |
| Persistent prop-network (PM Track 7) | ✅ | Persistent cells, stratified retraction, readiness propagators. |
| ATMS data structure (atms.rkt) | ✅ | 397 lines, fully functional. |
| TMS cell infrastructure (propagator.rkt) | ✅ | tms-read/tms-write pure functions. |
| Tabling infrastructure (tabling.rkt) | ✅ | 252 lines. Table store, register, add, answers, freeze, run. |
| Solver config (solver.rkt) | ✅ | All knobs exist but most ignored. |
| Attribute evaluation (PPN Track 4B) | ✅ | 5-facet attribute-map, P1/P2/P3 patterns. |
| SRE algebraic domain (Track 2G) | ✅ | Property declarations, domain registry. |
| Cell-tree unification (PUnify Part 2) | 🔄 | Exists but PUnify toggle has parity bugs. Design against cell-tree directly. |
| BSP-LE Track 1 (UnionFind) | ⬜ | NOT a dependency. Cell-tree sufficient. |
| BSP-LE Track 3 (Left-recursive tabling) | ⬜ | Deferred. Track 2 handles non-recursive case. |

## §8 Success Criteria

1. All existing solver tests pass (behavioral parity with DFS)
2. `current-speculation-stack` parameter eliminated (all consumers migrated to worldview cells)
3. `atms.rkt` `tms-cells` field removed (unified cell storage)
4. Solve-adversarial benchmark does not regress >15% from baseline
5. Non-recursive tabled predicates terminate and memoize
6. `:strategy :auto` activates two-tier (Tier 1 → Tier 2 on first `amb`)
7. `:strategy :depth-first` preserves exact DFS semantics
8. Acceptance file passes at Level 3
9. Concurrent worldview exploration functional (multiple PUs in same BSP superstep)
