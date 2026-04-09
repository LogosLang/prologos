# BSP-LE Track 2: ATMS Solver + Cell-Based TMS — Stage 3 Design

**Date**: 2026-04-07
**Series**: BSP-LE (Logic Engine on Propagators)
**Scope**: Cell-Based TMS (folding Track 1.5) + ATMS Solver + Non-Recursive Tabling
**Status**: D.12 — Phase 8 on-network tabling (table-store dissolved, registry cell, one-true-tabling, emergent completion, SRE lattice lens, self-hosting path)
**Self-critique**: [P/R/M Analysis](2026-04-07_BSP_LE_TRACK2_SELF_CRITIQUE.md) (17 findings, D.2)
**External critique**: [Architect Review](2026-04-08_BSP_LE_TRACK2_EXTERNAL_CRITIQUE.md) (16 findings, D.3)
**Stage 1/2**: [Research + Audit](../research/2026-04-07_BSP_LE_TRACK2_STAGE1_AUDIT.md)
**Prior art**: [Logic Engine Design](2026-02-24_LOGIC_ENGINE_DESIGN.org) §4-7, [PUnify Part 3](2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md), [Cell-Based TMS Note](../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md)

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Pre-0: benchmarks + acceptance file | ✅ | Baselines captured (0a-0c). Acceptance file (0d) at implementation start. |
| 1 | Decision cell infrastructure + broadcast propagator | ✅ | 1A: `4df2a4d8` decision-cell.rkt. 1Bi: `a50fc138` A/B data. 1Bii: `fb0650a3` broadcast propagator + profile. 35 tests, 392/392, 7644 tests. |
| 2 | PU-per-branch lifecycle | ✅ | commit `0a78069a`. dependent-entry struct, #:assumption on net-add-propagator, make-branch-pu, perf-inc-inert-dependent-skip!, 7 tests. 393/393, 7651 tests. |
| 3 | Per-nogood propagators (RKan) | ✅ | commit `a38baefb`. Commitment cell (structural, provenance=value), broadcast commit-tracker, narrower, contradiction detector, topology handler. 9 tests. |
| 4 | Bitmask-tagged cell values (TMS retired) | ✅ | 4a+4b: `72394146`. 4-tests: `PENDING`. tagged-cell-value + worldview cache + net-cell-read/write. 35 new tests. Consumer migration deferred to Phase 5 (decision cells → worldview derivation) + Phase 9 (parameter removal). |
| 5 | ATMS struct dissolution + compound cells + consumer migration | ✅ | 18 commits. Compound cells + solver-context + projection: on-network ✅. 8 consumers migrated ✅. 25 architecture tests ✅. Tagged-cell-value path deployed: eager worldview cache update, promote-cell-to-tagged, key-map cells as tagged-cell-values, elab-speculation-bridge dual-write. **Remaining scaffolding**: solver-state-solve-all (compatibility shim — per-assumption writes need Phase 6 PU isolation). 396/396, 7731 tests. |
| 6+7 | Propagator-native solver (merged: clause matching + goal dispatch) | ✅ | 9 commits. All 5 goal types (unify, is, app, not, guard). Multi-clause PU branching with answer accumulator. Gray code ordering. typing-propagators union branching migration (dual-write). 16 tests. Vision gates ✅. Scaffolding: NAF/guard synchronous (S1 in Phase 9). |
| 8 | On-network tabling | ✅ | 8.1-3: `f2410a57` compound scope cells. 8.4: `54a5fce4` table registry cell. 8.5-7: `5261df52` producer/consumer. Test: `b9f2862d`. One-true-tabling. Vision gates ✅. 17 tests. |
| 9 | Strategy dispatch + parameter migration | ✅ | 9a: `97d8048d` :strategy dispatch (auto→DFS, atms→propagator). 9b-1: `5af7f1aa` metavar-store reads worldview bitmask. 9b-2: `48c718b4` cell-ops reads worldview bitmask. 9b-4: `29344a04` typing-propagators TMS removal REVERTED — union type regression. current-speculation-stack retained (dual-write). Full retirement → Phase 11. |
| 10 | Solver config wiring | ⬜ | `:strategy`, `:execution`, `:tabling` operational |
| 11 | Parity validation + inert-dependent checkpoint | ⬜ | DFS ↔ propagator-native equivalence. R7 hotspot. **CHECKPOINT**: review inert-dependent data → S(-1) lattice-narrowing cleanup if warranted. |
| T | Dedicated test files | ⬜ | Per-phase |
| PIR | Post-implementation review | ⬜ | |

---

## §1 Objectives

**End state**: The logic engine's search, branching, and memoization operate entirely on the propagator network. Choice points are decision cells (SRE structural lattice, alternatives = constructors). Branch isolation is structural (PU-per-branch). Nogood propagation narrows decision cells via filtered right Kan extension. The ATMS struct is dissolved — all state lives in cells, all mutations are cell writes, query functions read cell values. Tabling is producer/consumer propagators on accumulator cells. The `solver-config` knobs are operational. The DFS solver (`solve-goals` at `relations.rkt:600`) is retired as the default path.

**What changes**: DFS `append-map` → propagator quiescence. Sequential clause iteration → concurrent PU-per-branch exploration. Explicit substitution threading → implicit propagation through cells. `current-speculation-stack` parameter → decision cells (no worldview cell — the worldview EMERGES from decisions). The `atms` struct → dissolved into cells + query functions.

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

### §2.5 SRE Lattice Composition Analysis

Seven lattices participate in the solver architecture. Each is classified as VALUE (pure join) or STRUCTURAL (SRE-derived decomposition), with algebraic properties declared:

| Lattice | Carrier | Order | Merge | Kind | Properties | Hasse diagram |
|---|---|---|---|---|---|---|
| Worldview | P(AssumptionId) | ⊆ | set-union | Value (DERIVED) | Boolean, distributive, Heyting, frame | **Hypercube Q_n** — optimal traversal via Gray code, O(log n) diameter |
| Nogood | P(P(AssumptionId)) | ⊆ | set-union | Value | Boolean, distributive | Powerset of powerset — complex; nogoods are independent units |
| Decision (per amb) | P(Alternatives) | ⊇ (reverse) | set-intersection | **Structural** | Boolean (dual powerset), constraint narrowing | **Dual hypercube** — narrowing traverses downward; bitmask enables O(1) subcube ops |
| Term Value | existing structural | — | SRE merge | Structural | Per Track 2H (Heyting ground sublattice) | Constructor tree — adjacency = differ by one constructor field |
| Answer Accumulator | P(Answer) | ⊆ | set-union | Value | Boolean, distributive | Powerset — grows monotonically, no traversal optimization needed |
| Assumptions | P(Assumption) | ⊆ | set-union | Value | Boolean, distributive | Hypercube — but only grows, never traversed for search |
| Counter | Nat | ≤ | max | Value | Chain | Linear chain — trivial adjacency |

**(SRE Lattice Lens Q6: Hasse diagram analysis)**

The worldview and decision lattices have hypercube Hasse diagrams (Boolean powerset). This is a structural identity: the ATMS worldview space for n assumptions IS Q_n. Two worldviews are Hasse-adjacent iff they differ by exactly one assumption (Hamming distance 1).

This identity enables:
- **Gray code traversal**: explore worldviews changing one assumption per step — maximizes CHAMP structural sharing (Hamming-adjacent worldviews share almost all network state)
- **Subcube pruning**: a nogood `{h_A, h_B, h_C}` identifies a subcube Q_{n-3} of contradicted worldviews. Membership test: `(wv AND ng) == ng` — O(1) bitmask operation
- **Hypercube broadcast**: distribute nogoods to all worldviews in log_2(W) rounds
- **Hypercube all-reduce**: synchronize BSP barriers in log_2(T) rounds for T threads
- **Recursive decomposition**: Q_n = Q_{n-1} × Q_1 — splitting on one assumption halves the space

These Hasse-diagram operations require **bitmask representation** of assumption sets (see Phase 1, §4 additive bitmask). For n ≤ 63 (Racket fixnum), all operations are O(1) machine instructions. For n > 63, Racket exact integers handle arbitrary precision.

Research note: [Hypercube BSP-LE Design Addendum](../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md)

#### §2.5a Key Architectural Finding: Decisions Are Primary, Worldview Is Derived

**(1.3) Two-level decision structure:**
- **Group-level decision cell**: ONE per `atms-amb` call, on the OUTER network. Tracks which alternatives remain viable across all branches. Shared. Narrows as nogoods eliminate alternatives.
- **Branch PU**: Each branch reads its group's decision cell but does NOT have its own "decision cell." A branch has a committed assumption that is either in the group's domain (alive) or not (pruned via narrowing). The branch PU is alive iff its assumption is still in the group-level cell's domain.

Per-nogood propagators (4.1) narrow the GROUP-level cell. Contradiction detection watches the GROUP-level cell. Branch PUs react to narrowing of the group cell they participate in.

The SRE analysis reveals that **decision cells are the primary structural construct**. The worldview is a derived aggregate — the union of all decision singletons. This reframes the architecture:

- Each `atms-amb` creates a **decision cell** (SRE structural domain, alternatives = constructors)
- Nogoods narrow **decisions** (not worldviews) — eliminating alternatives from decision domains
- Branches are created per-**decision alternative**, not per-worldview-combination
- The worldview cell is COMPUTED from decision cells: `worldview = ∪ {chosen(D) | D ∈ decisions}`
- The ATMS struct's `believed` field is unnecessary — the worldview is derived

The decision lattice maps directly onto the SRE form registry:
- Alternatives = constructors (mutually exclusive tags)
- Choosing alternative h = matching constructor h → decompose into h's clause body
- Two alternatives simultaneously = contradiction (same as merging Pi with Sigma → type-top)
- Narrowing = eliminating constructors (same as constraint narrowing on types via Track 2H)

This uses EXISTING infrastructure: constraint-cell.rkt (powerset under intersection), SRE form registry (constructor decomposition), Track 2H (structural narrowing).

#### §2.5b Lattice Bridge Diagram

```
Assumptions ──(accumulate)──→ Worldview ←──(aggregate)── Decisions
                                  │                         ↑
                                  │                    (narrow)
                                  │                         │
                                  │                      Nogoods
                                  │
                          (gate per-branch)
                                  │
                    ┌─────────────┼─────────────┐
                    ↓             ↓             ↓
              Term cells    Term cells    Term cells
              (branch 1)    (branch 2)    (branch K)
                    │             │             │
                    └─────────────┼─────────────┘
                                  │
                          (commit results)
                                  ↓
                          Answer Accumulator
```

#### §2.5c Bridges (Galois Connections Between Domains)

| Bridge | From | To | α (forward) | Notes |
|---|---|---|---|---|
| Accumulate | Assumptions | Worldview | New assumption → extend worldview | Monotone |
| Aggregate | Decisions (all) | Worldview | Union of singletons → worldview | Derived; worldview is read-only aggregate |
| Narrow | Nogoods | Decisions | Nogood eliminates alternative from decision domain | Filtered RKan per-decision |
| Decompose | Worldview | Decisions | `π_G(W) = W ∩ alternatives(G)` | Structural projection |
| Gate | Worldview | Term cells | TMS-tagged read under worldview | Per-branch filtering |
| Choose | Decision (singleton) | Branch topology | Committed choice → install clause body in PU | Topology mutation |
| Commit | Term cells (per-branch) | Answer Acc | Branch result → answer set | Monotone set-union |
| WorldviewToType | Worldview | Type lattice | Assumptions constrain type visibility | Cross-system |
| WorldviewToTerm | Worldview | Term lattice | Assumptions constrain term values | Cross-system |
| HammingToCHAMP | Adjacency distance | CHAMP structural diff | Lower Hamming distance = more CHAMP sharing | Gray code exploits this |
| SubcubeToNogood | Subcube bitmask | Pruned worldview set | `(wv AND ng) == ng` = O(1) subcube membership | Bitmask enables |
| DimensionToBSP | Hypercube dimension k | BSP superstep k | One dimension per round = log_2 synchronization | All-reduce topology |

The critical bridge is **Narrow (Nogoods → Decisions)**: nogoods flow to decision cells, not to worldview cells. (4.1) Each NOGOOD gets its own propagator — one per nogood, with fan-in = |nogood| (typically 2-3 cells). The propagator reads the decision cells of ALL groups mentioned in the nogood. When all assumptions except one are committed (their group's decision cell is a singleton), it narrows the remaining group's decision cell to exclude that assumption.

This is per-NOGOOD, not per-decision (4.1 correction from external critique). Each nogood is its own information-flow unit. Cost per new nogood: O(|nogood|) propagator installation + O(1) when it fires. Scale: O(nogoods) propagators total, each with fan-in 2-3. At 10000 nogoods: 10000 propagators with fan-in 2-3 = 20000-30000 dependency edges. (4.2: corrected from O(decisions × |nogood|) to O(|nogood|) per nogood.)

---

## §2.6 ATMS Struct Dissolution (P4 Resolution)

The ATMS struct (`atms.rkt`, 7 fields) dissolves entirely into cells on the propagator network. No field requires off-network storage.

### §2.6a Field → Cell Mapping

| ATMS Field | Cell Replacement | Lattice | Merge | Notes |
|---|---|---|---|---|
| `network` | IS the prop-network | — | — | The substrate, not a field to dissolve |
| `assumptions` | Assumptions accumulator cell | P(Assumption), ⊆ | set-union | Monotone: assumptions only added |
| `nogoods` | Nogood cell (already designed §2.2) | P(P(AssumptionId)), ⊆ | set-union | Monotone: nogoods only grow |
| `tms-cells` | RETIRED (Phase 4) | — | — | TMS tree replaced by bitmask-tagged cell values |
| `next-assumption` | Counter cell | Nat, ≤ | max | Monotone. (2.3) Written ONLY at topology stratum (sequential) — prevents concurrent ID collision. |
| `believed` | **ELIMINATED** | — | — | Worldview emerges from decision cells — no separate representation |
| `amb-groups` | Decision cells (one per amb, §2.5a) | P(Alternatives), ⊇ | set-intersection | Structural lattice, SRE-registered |

### §2.6b Worldview Emerges from Decisions via Compound Cell

**Updated D.10** (reconciles with Phase 4 worldview cache cell, Phase 5 compound decisions cell design):

Decision cells are PRIMARY. The worldview is a DERIVED bitmask, maintained structurally by the compound decisions cell's merge function — not by propagators.

**Compound decisions cell**: ONE cell holds ALL decision state, component-indexed by group-id. Value struct: `(decisions-state components bitmask)` where `components` is `(hasheq group-id → decision-domain-value)` and `bitmask` is the OR of all committed assumptions' bit positions. The merge function recomputes the bitmask from all components on every merge — retraction (component narrowing) naturally removes bits.

**Worldview cache cell** (cell-id 1, pre-allocated in Phase 4): Holds the current worldview bitmask for `net-cell-read`'s tagged-cell-value filtering. Updated by ONE projection propagator that watches the compound decisions cell, extracts the bitmask field, writes to cell-id 1. O(1) work per fire. Merge: replacement (not ior — the projection writes the complete recomputed bitmask each time).

**No fan-in aggregation**: The merge function IS the aggregation. No N micro-propagators, no centralized fan-in. The cell's merge maintains the bitmask structurally. The single projection propagator is a transparent bridge to cell-id 1, not an aggregation step.

- A propagator in branch B reads its group's component of the compound decisions cell via component-path
- Consistency checking: per-decision contradiction detection (Phase 3 infrastructure), not a global fan-in (1.2 external critique resolution)
- The compound decisions cell eliminates M separate decision cell allocations → 1 cell
- Component-indexed access preserves per-group precision for per-nogood propagators

### §2.6c Retraction = Decision Cell Narrowing (SRE Structural Operation)

The word "retract" disappears from the architecture. All worldview changes are **decision cell narrowing**:

- Nogood involving h2 → narrow decision-cell-G to exclude h2
- Explicit retraction of h2 → narrow decision-cell-G to exclude h2
- Branch commitment to h1 → narrow decision-cell-G to {h1}

These are ALL the same cell write: `set-intersection(current-domain, domain-minus-excluded)`. The mechanism is unified. Decision cell narrowing IS SRE structural narrowing — the same operation that narrows a type's constructor set when pattern matching eliminates a constructor.

Standalone assumptions (not from any amb) are decision cells with one alternative: `{h}`. Retraction = narrow from `{h}` to `∅`. Everything goes through decision cells.

### §2.6d ATMS Operations → Cell Operations + Query Functions

| ATMS Operation | Replacement | On-network? |
|---|---|---|
| `atms-assume` | Write to assumptions-cell + counter-cell. Create trivial decision cell `{h}`. | ✓ Cell writes |
| `atms-retract` | Narrow decision cell to exclude assumption | ✓ Cell write (SRE narrowing) |
| `atms-add-nogood` | Write to nogood cell (set-union) | ✓ Cell write |
| `atms-consistent?` | Per-decision contradiction detection (Phase 3 infrastructure, 1.2 resolution). Read compound decisions cell components. No global fan-in. | ✓ Component reads |
| `atms-with-worldview` | Set decision cells to specific values | ✓ Cell writes |
| `atms-amb` | Create N assumptions + decision cell + pairwise nogoods | ✓ Cell writes + topology (decision cell creation) |
| `atms-read-cell` | RETIRED — `net-cell-read` with decision context | ✓ |
| `atms-write-cell` | RETIRED — `net-cell-write` | ✓ |
| `atms-solve-all` | REPLACED — answer accumulator cell. Branching topology covers product space. | ✓ |
| `atms-explain-hypothesis` | Query function: read nogood cell + assumptions cell, filter | ✓ Read-only (correctly off-network — consumer of cell state) |
| `atms-explain` | Query function: read nogoods + decision cells | ✓ Read-only |
| `atms-minimal-diagnoses` | **Tropical semiring CSP** (see §2.6e) | ✓ Our own solver infrastructure |
| `atms-conflict-graph` | Query function: read nogoods, build graph | ✓ Read-only |

### §2.6e Tropical Hitting Set: Diagnosis as Constraint Satisfaction

The greedy hitting-set algorithm for `atms-minimal-diagnoses` dissolves into a constraint satisfaction problem over a tropical semiring — solvable by our own ATMS solver infrastructure.

**Formulation:**

Each violated nogood S_i = {a1, a2, a3} becomes an `amb` (decision cell): "which assumption from this nogood do we retract?" The alternatives are the nogood's assumptions. The cost = number of assumptions retracted (minimize via tropical semiring).

```
For each violated nogood S_i:
  decision-cell-i : DecisionDomain = alternatives(S_i)
  ;; "choose which assumption to retract from this nogood"

Cost accumulator (5.2: deduplicates shared retractions):
  retracted-assumptions : Cell (Set AssumptionId)
  merge = set-union  (unique assumptions retracted)
  Cost = cardinality of the set (not sum of per-nogood counts)
  
  If nogood-1 chooses h2 and nogood-2 also chooses h2,
  the set contains h2 ONCE → cost = 1 (correct).
  
  The minimum-cost worldview (tropical min over all combinations)
  = the minimum hitting set
```

The tropical semiring `(Nat, min, +, ∞, 0)`:
- `min` selects the cheapest diagnosis
- `+` accumulates retraction costs
- Each decision cell contributes its choice's cost to the total

This uses the same solver infrastructure (same code, same functions) but on a FRESH, SEPARATE propagator network (5.1). The diagnostic solver does NOT run on the outer solver's network — that would cause diagnostic decision cells to interact with outer nogood watchers. The set of violated nogoods is extracted as data, a fresh solver context is created, and the diagnostic CSP is solved on the fresh network. The "self-referential" nature is in the CODE (same functions), not the NETWORK (same cells). The "greedy algorithm" dissolves into lattice operations. The computation is parallel by construction (CALM: monotone cost accumulation is coordination-free).

For our typically small nogoods (2-3 assumptions), this is a near-2-SAT problem — propagation solves it in very few rounds.

**Hyperlattice Conjecture**: Every computable function can be represented as a fixpoint calculation on lattices. The hitting-set algorithm was the test case: the "algorithm" was a failure of imagination about lattice structure, not a genuine limit of the model. The tropical semiring provides the right structure. See `DESIGN_PRINCIPLES.org` § "The Hyperlattice Conjecture."

### §2.6f What Remains of atms.rkt

The `atms` struct is eliminated. `atms.rkt` becomes a **library of query functions** that read cell values and compute derived results:

- `explain-hypothesis`: read nogood cell + assumptions cell → filter → explanation
- `explain-all`: read nogoods + decision cells → filter → violated nogoods
- `minimal-diagnoses`: formulate as tropical CSP → solve via solver infrastructure
- `conflict-graph`: read nogoods → build graph

These are correctly off-network: they are CONSUMERS of propagation results, like pretty-printing. They run after quiescence, reading final cell values. The module provides a query API over network state, not a state management mechanism.

---

## §3 NTT Model

### §3.1 Lattice Declarations

```prologos
;; NO worldview lattice cell — worldview EMERGES from decision cells (§2.6b)
;; The Worldview type exists for the type bridge (§3.5) but is not a cell.
;; It is a READ-ONLY aggregate computed via fan-in when needed.

lattice NogoodSet
  :type  (Set (Set AssumptionId))
  :bot   (set-empty)
  :join  set-union
  :merge set-union
  :kind  :value

;; THE PRIMARY STRUCTURAL LATTICE: Decision domain per amb group
;; Follows constraint-cell.rkt convention (1.1): powerset under intersection,
;; bot = unconstrained, top = empty = contradiction.
;; Compatible with bulk-merge-writes — merge is intersection (narrowing).
lattice DecisionDomain {G : AmbGroup}
  :type  (Set AssumptionId)              ;; subset of G's alternatives
  :bot   [alternatives G]               ;; all viable (unconstrained — constraint-cell bot)
  :top   (set-empty)                    ;; contradicted (empty — constraint-cell top)
  :meet  set-intersection               ;; narrowing (= constraint-cell merge)
  :join  set-union                      ;; relaxing
  :properties [:boolean :distributive :complemented]
  :kind  :structural                    ;; SRE: alternatives = constructors
  :lattice :structural                  ;; SRE form registry applies
  :convention :constraint-cell           ;; (1.1) explicitly uses constraint-cell.rkt pattern

impl Lattice (DecisionDomain G)
  merge [a b] := [set-intersection a b] ;; constraint-cell merge: intersection = narrowing
  bot?  [d]   := [= d [alternatives G]] ;; unconstrained = least info
  top?  [d]   := [set-empty? d]         ;; contradiction = over-constrained
```

### §3.1a NTT Invariant: Component-Path Required for Compound Cell Access

**Invariant**: Any propagator that reads or writes a compound cell (a cell whose value is a nested structure with addressable positions — hasheq, attribute-map, commitment-status, etc.) MUST declare `:component-paths` specifying which positions it accesses. A propagator reading a compound cell without component-paths is a TYPE ERROR in the NTT model.

**Rationale**: Without component-paths, a propagator watching a compound cell fires on EVERY change to the cell, including changes to positions the propagator doesn't care about. This causes thrashing — unnecessary firings that do no useful work. For cells with many positions (e.g., a decision cell in a 100-alternative group, or an attribute-map with 30+ positions), the thrashing is proportional to the position count.

**The invariant prevents specification of thrashing patterns.** A design that type-checks under this invariant is guaranteed to have precise firing — every propagator fires only when its specific interests change.

**Exceptions**: Scalar cells (Nat, Bool, single values) and flat set cells (set-union accumulators) don't have addressable positions — component-paths is N/A. The invariant applies only to cells with `:kind :structural` or explicitly compound value types.

**Audit (Track 2)**: All propagators and interfaces verified:

NTT §3 propagators:
- 4 propagators access compound cells WITH component-paths ✅ (broadcast-commit-tracker, nogood-narrower, decision-contradiction-detector, branch-committer)
- 1 propagator accessing compound cells REMOVED (per-nogood-watcher — superseded by commitment-cell decomposition, which uses component-paths)
- 8 propagators access only scalar/flat cells — invariant N/A ✅

NTT §3 interfaces (Level 3):
- `BranchPU` interface: reads `decision-G` (compound) WITH component-path `(decision-G . h_i)` ✅ — fires only when this branch's alternative status changes

Phase descriptions (§4, §6):
- Phase 6 Step 2: branch PU access to decision cell has component-path ✅
- Phase 6 Step 2: sub-goal propagators read PU-local variable cells (not compound outer cells) ✅
- Phase 6 Step 2: outer arg cells are resolved (ground values, no compound structure) ✅
- Phase 3: commitment cells use component-indexed writes ✅
- Phase 7: conjunction propagators operate on PU-local cells ✅
- Phase 7: NAF cross-PU bridge writes to flat outer result cell (no compound) ✅

### §3.2 Level 0: Properties and Lattice Laws

```prologos
property Boolean {L : Type}
  :where [Lattice L]
         [BoundedLattice L]
         [Complemented L]
         [Distributive L]

property Frame {L : Type}
  :where [Lattice L]
         [Distributive L]
         ;; meet distributes over arbitrary joins

;; Hasse diagram structure for Boolean lattices (SRE Lattice Lens Q6)
;; The Hasse diagram of a Boolean lattice IS a hypercube Q_n.
;; This property enables optimal parallel communication patterns.
property HypercubeAdjacency {L : Type}
  :where [Boolean L]
  :metric hamming-distance                    ;; |a Δ b| = number of differing elements
  :diameter n                                 ;; max distance = number of generators
  :recursive-decomposition (L = L_{n-1} × L_1)  ;; splitting on one generator
  :bitmask-representable (n ≤ 63)            ;; fixnum O(1) operations
```

### §3.3 Level 2: Propagator Declarations

```prologos
propagator branch-creator {clauses : (List ClauseInfo)}    ;; atms-amb
  :reads  [assumptions : Cell (Set Assumption),
           counter : Cell Nat]
  :writes [assumptions : Cell (Set Assumption),
           counter : Cell Nat,
           nogoods : Cell NogoodSet]
  :non-monotone                                    ;; topology mutation (CALM)
  ;; Create N assumptions, decision cell, pairwise nogoods, N PUs
  ;; Emits topology requests for decision cell + PU creation
  [atms-amb-on-network clauses]

;; OLD filtered-nogood-decision-watcher REMOVED (had for-each step-think).
;; Replaced by per-nogood-watcher (4.1) + broadcast commit-trackers below.

propagator decision-contradiction-detector {G : AmbGroup}
  :reads  [decision-G : Cell (DecisionDomain G)]
  :writes [topology-requests : Cell (Set TopologyRequest)]
  :component-paths [(decision-G . :domain)]              ;; watches domain cardinality, not specific alternatives
  (when [empty? [read decision-G]]
    [write topology-requests [set [drop-pu G]]])         ;; M3: emit REQUEST, not direct drop

propagator branch-committer {G : AmbGroup}
  :reads  [decision-G : Cell (DecisionDomain G),
           result-G : Cell Answer]
  :writes [answer-accumulator : Cell (Set Answer),
           topology-requests : Cell (Set TopologyRequest)]
  :component-paths [(decision-G . :domain)               ;; watches domain for singleton
                    (result-G . :value)]                  ;; watches result for non-bot
  (when [and [singleton? [read decision-G]]
             [not [bot? [read result-G]]]]
    [write answer-accumulator [set [read result-G]]]     ;; M5: answer accumulator
    [write topology-requests [set [commit-pu G]]])       ;; M3: topology request

propagator broadcast-clause-match                          ;; M1: ONE propagator, N items
  :reads  [arg-cells : Cell TermValue ...]
  :writes [match-results : Cell (Set (Pair ClauseInfo Bindings))]
  :broadcast-profile
    :items    clauses                                      ;; data-indexed arity
    :item-fn  (λ [ci args] [try-alpha-rename-and-unify ci args])
    :merge-fn set-union
  ;; Fire function: read inputs ONCE, process ALL clauses, ONE write
  (let [args [map read arg-cells]]
    (let [results [for/list [ci clauses]
                    [try-alpha-rename-and-unify ci args]]]
      [write match-results [filter-not-false results]]))

;; (1.2) NO global consistency-fan-in. Consistency = absence of per-decision
;; contradiction. Each decision cell has a contradiction detector (Phase 3)
;; that fires when domain → ∅. Global consistency EMERGES from the absence
;; of any contradiction — no aggregation step, no centralized worldview.

;; per-nogood-watcher SUPERSEDED by broadcast-commit-tracker + nogood-narrower.
;; The commitment-cell decomposition (below) handles the same logic with:
;;   - Component-indexed writes (no thrashing on irrelevant decision changes)
;;   - Emergent counting in the merge function
;;   - Threshold-triggered narrowing
;; The per-nogood-watcher without component-paths would thrash: it fires on
;; EVERY decision cell narrowing, even irrelevant ones. The commitment-cell
;; decomposition avoids this by only tracking the specific alternatives
;; each nogood cares about.

;; Per-nogood commitment tracking: structural unification of nogood pattern against decisions
;; Cell value: { G_A: #f | h_A, G_B: #f | h_B, ... }  — partial nogood pattern match
;; Merge: per-position OR (once committed, stays committed). Carries assumption-id, not Bool.
;; Full match (all non-#f) = contradiction. Cell value IS the provenance.

cell commitment-{ng} : (Hasheq Group (Option AssumptionId))
  :value   { G_A : #f, G_B : #f, ... }               ;; initially unmatched
  :merge   (λ [old new] [hash-union old new #:combine or])  ;; per-position OR
  :contradicts? (λ [v] [for/and [val [hash-values v]] val])  ;; all non-#f
  :kind :structural                                    ;; SRE: component-indexed by group
  :component-paths [G for G in [groups-of ng]]

propagator broadcast-commit-tracker {ng : Nogood}
  :reads  [decision-G : Cell (DecisionDomain G) for G in [groups-of ng]]
  :writes [commitment-{ng}]
  :broadcast-profile
    :items    [groups-of ng]
    :item-fn  (λ [G decision-values]
               ;; Structural: is decision-G a singleton containing the nogood member?
               (let [d [decision-value-for G decision-values]]
                 (when [and [decision-committed? d]
                            [equal? [decision-committed-assumption d]
                                    [nogood-member-for ng G]]]
                   (hasheq G [nogood-member-for ng G]))))
    :merge-fn hash-union-or
  :component-paths [(commitment-{ng} . G) for G in [groups-of ng]]

propagator nogood-narrower {ng : Nogood}
  :reads  [commitment-{ng}]
  :writes [decision-remaining : Cell (DecisionDomain G')]
  :component-paths [(commitment-{ng} . G) for G in [groups-of ng]]  ;; fire when any position changes
  ;; For |ng|=2: read two positions. One non-#f, one #f → narrow the #f group.
  ;; For |ng|=3: read three positions. Two non-#f, one #f → narrow the #f group.
  ;; The output target is WHICH position is still #f — structural, not scanned.
  (let [positions [read-all-positions commitment-{ng} [groups-of ng]]]
    (let [filled [filter non-false? positions]]
      (when [= [length filled] [- [length ng] 1]]
        (let [remaining-group [the-group-with-#f positions]]
          [narrow [decision remaining-group]
                  [exclude [nogood-member-for ng remaining-group]]]))))

propagator nogood-contradiction-detector {ng : Nogood}
  :reads  [commitment-{ng}]
  :writes [nogoods : Cell NogoodSet]
  :component-paths [(commitment-{ng} . G) for G in [groups-of ng]]
  ;; When all positions are non-#f, the cell value IS the provenance.
  ;; Write the assumption-id set to the nogoods cell.
  (let [positions [read-all-positions commitment-{ng} [groups-of ng]]]
    (when [all? non-false? positions]
      [write nogoods [set [hash-values positions]]]))

propagator goal-unify
  :reads  [lhs : Cell TermValue, rhs : Cell TermValue]
  :writes [lhs : Cell TermValue, rhs : Cell TermValue]      ;; bidirectional
  [unify-cells lhs rhs]

propagator goal-is
  :reads  [expr : Cell TermValue]
  :writes [var : Cell TermValue]
  [write var [eval [read expr]]]

propagator goal-naf
  :reads  [inner-result : Cell Answer]
  :writes [naf-result : Cell Answer]
  :non-monotone                                    ;; succeeds on ABSENCE of info
  (if [bot? [read inner-result]]
    [write naf-result success]     ;; inner failed → naf succeeds
    [write naf-result failure])    ;; inner succeeded → naf fails

propagator table-producer
  :reads  [clause-body-results : Cell Answer ...]
  :writes [table-answers : Cell (Set Answer)]
  [write table-answers [set [read clause-body-results]]]

propagator table-consumer
  :reads  [table-answers : Cell (Set Answer)]
  :writes [local-result : Cell Answer]
  [write local-result [read table-answers]]
```

### §3.4 Level 3: Network Interfaces and Implementations

```prologos
;; The polynomial functor interface for a solver branch PU
;; §3.1a invariant: all compound cell inputs declare component-paths
interface BranchPU {h_i : AssumptionId}
  :inputs  [decision-G : Cell (DecisionDomain G)     ;; group-level decision (compound)
              :component-paths [(decision-G . h_i)]   ;; fire only when THIS branch's alternative changes
            nogoods : Cell NogoodSet                  ;; shared (flat — no component-paths needed)
            parent-facts : Cell (Set Fact) ...]       ;; inherited (flat)
  :outputs [result : Cell Answer                      ;; branch result (flat)
            new-nogoods : Cell NogoodSet]              ;; nogoods discovered (flat)
  :lifetime :speculative
  :tagged-by Assumption

;; The interface for the overall solver network
;; Note: NO atms struct. Solver context = cell-ids (phone book, not state).
interface SolverNet
  :inputs  [query-goals : Cell (List GoalDesc),
            relation-store : Cell RelationStore,
            table-store : Cell TableStore]
  :outputs [answers : Cell (Set Answer)]             ;; M5: answer accumulator
  :cells   [assumptions : Cell (Set Assumption),     ;; dissolved ATMS fields
            nogoods : Cell NogoodSet,
            counter : Cell Nat,
            decisions : Cell (Set CellId)]            ;; list of decision cell-ids

;; Parameterized network: one branch per matching clause
;; THIS is the N→M functor from Phase 6
functor ClauseBranch {ci : ClauseInfo, bindings : FreshBindings}
  interface BranchPU
  embed body-goals : GoalConjunction (clause-info-goals ci)
  connect bindings -> body-goals.inputs
          body-goals.outputs -> result

;; Parameterized conjunction: simultaneous goal installation
;; M2: goals list is an ENUMERATION, not an ordering
functor GoalConjunction {goals : (List GoalDesc)}
  interface
    :inputs  [var-cells : Cell TermValue ...]
    :outputs [result : Cell Answer]
  ;; All goals installed simultaneously — order-independent
  ;; Dataflow determines execution order
```

### §3.5 Level 4: Bridges (Galois Connections)

```prologos
;; PRIMARY BRIDGE: Nogoods narrow decision domains (not worldviews)
;; This is the filtered RKan watcher, per-decision
bridge NogoodToDecision {G : AmbGroup}
  :from NogoodSet
  :to   (DecisionDomain G)
  :alpha (λ [ngs] 
    ;; For each nogood involving an alternative from G:
    ;; if the other assumptions in the nogood are all believed,
    ;; eliminate G's alternative from the decision domain
    [decision-narrow-by-nogoods ngs G])
  :preserves [Monotone]                 ;; nogoods grow → domain shrinks (dual monotone)

;; Decisions aggregate into worldview (worldview is DERIVED)
bridge DecisionsToWorldview
  :from (DecisionDomain G) ...          ;; all decision cells
  :to   Worldview
  :alpha (λ [decisions] [set-union-all [map singleton decisions]])
  :preserves [Monotone Structural]

;; Worldview gates type inference
bridge WorldviewToType
  :from Worldview
  :to   TypeLattice
  :alpha worldview->type-filter

;; Worldview gates term values (per-branch TMS read)
bridge WorldviewToTerm
  :from Worldview
  :to   TermValue
  :alpha worldview->term-filter

;; Decision singleton triggers branch topology creation
bridge DecisionToTopology {G : AmbGroup}
  :from (DecisionDomain G)
  :to   TopologyRequest
  :alpha (λ [domain]
    (when [singleton? domain]
      [topology-request :commit-branch [the-element domain]])
    (when [empty? domain]
      [topology-request :drop-branch G]))
  :preserves [Monotone]                 ;; domain only shrinks → requests only accumulate
```

### §3.6 Level 5: Stratification

```prologos
stratification SolverLoop
  :strata [S-neg1 S0 S1]
  :scheduler :bsp
  :fixpoint :lfp
  :fuel 1000000

  :fiber S0
    :mode monotone
    :speculation :atms                   ;; TMS-based branching enabled
    :branch-on [multi-clause-match]      ;; amb trigger
    :bridges [WorldviewToType WorldviewToTerm NogoodToDecision]
    :networks [solver-net]

  :fiber S1
    :mode monotone
    :scheduler :gauss-seidel             ;; NAF needs sequential evaluation
    ;; goal-naf fires here: after S0 quiesces, check if inner goals succeeded

  ;; (6.5) Using exchange model (bidirectional) instead of barrier (unidirectional).
  ;; The fixpoint cycle is: S0 → S(-1) → S0 (re-enter). :fixpoint :lfp implies this.
  :exchange S0 <-> S-neg1
    :left  new-nogoods -> pruning-targets
    :right pruned-decisions -> re-fire-surviving-propagators

  :where [WellFounded SolverLoop]

;; The solver config IS a stratification (subsumes solver keyword)
stratification DepthFirstSolver
  :extends SolverLoop
  :fiber S0
    :speculation :none                   ;; no branching — DFS backtracking
    :scheduler :sequential

stratification ParallelSolver
  :extends SolverLoop
  :fiber S0
    :scheduler :bsp                      ;; parallel worldview exploration
    :speculation :atms
```

### §3.7 Level 6: Exchange (Inter-Stratum Adjunctions)

```prologos
;; Filtered nogood propagation IS an exchange:
;; S0 (computation) discovers nogoods → S(-1) (retraction) prunes branches
exchange S0 <-> S-neg1
  :left  new-nogoods -> pruning-targets          ;; left: forward nogoods
  :right pruned-worldviews -> freed-resources    ;; right: reclaim PU resources
  :kind  kan                                     ;; right Kan: demand-filtered

;; NAF exchange: S0 results → S1 negation check
exchange S0 <-> S1
  :left  partial-fixpoint -> naf-inputs          ;; left: S0 results feed NAF
  :right naf-results -> s0-constraints           ;; right: NAF outcomes constrain S0
  :kind  suspension-loop                         ;; S1 suspends until S0 quiesces
```

### §3.8 NTT ↔ Racket Correspondence Table (Expanded)

| NTT Level | NTT Construct | Racket Implementation | File |
|---|---|---|---|
| **L0** | `lattice DecisionDomain` | `decision-domain-merge`, `decision-from-alternatives` | decision-cell.rkt |
| **L0** | `lattice NogoodSet` | `nogood-merge` (= `set-union`) | decision-cell.rkt |
| **L0** | `property Boolean` | SRE property declaration via Track 2G | sre-core.rkt |
| **L2** | `propagator broadcast-clause-match` | `net-add-broadcast-propagator` (ONE propagator, N items) | propagator.rkt |
| **L2** | `propagator broadcast-commit-tracker` | Broadcast over groups, writes assumption-id to component positions | propagator.rkt |
| **L2** | `propagator nogood-narrower` | Threshold on commitment cell, narrows remaining group | propagator.rkt |
| **L2** | `propagator nogood-contradiction-detector` | Full commitment → write provenance to nogoods cell | propagator.rkt |
| **L2** | `propagator branch-creator` | `atms-amb-on-network` | relations.rkt |
| **L2** | `propagator per-nogood-watcher` | `install-nogood-propagator` (one per nogood, fan-in = |ng|) | propagator.rkt |
| **L2** | `propagator contradiction-detector` | Extension of `net-cell-write` contradiction path | propagator.rkt |
| **L2** | `propagator branch-pruner` | Topology request via `pu-drop` | propagator.rkt |
| **L2** | `propagator branch-committer` | Topology request via `pu-commit` + `tms-commit` | propagator.rkt |
| **L2** | `propagator goal-unify` | Cell-tree unification propagator | relations.rkt |
| **L2** | `propagator goal-naf` | NAF propagator at S1 | relations.rkt |
| **L2** | `propagator table-producer/consumer` | `install-table-producer/consumer` | tabling.rkt |
| **L3** | `interface BranchPU` | PU struct with input/output cell lists | propagator.rkt |
| **L3** | `interface SolverNet` | Solver network entry point | relations.rkt |
| **L3** | `functor ClauseBranch` | `install-clause-propagators` per matching clause | relations.rkt |
| **L3** | `functor GoalConjunction` | `install-conjunction` (simultaneous) | relations.rkt |
| **L4** | `bridge WorldviewToType` | Worldview cell → type constraint filtering | typing-propagators.rkt |
| **L4** | `bridge NogoodToWorldview` | `install-nogood-watcher` (filtered RKan) | propagator.rkt |
| **L5** | `stratification SolverLoop` | BSP scheduler config + stratum assignment | propagator.rkt / solver.rkt |
| **L5** | `:speculation :atms` on fiber | Worldview cell + TMS branching on S0 | propagator.rkt |
| **L6** | `exchange S0 <-> S-neg1` | Nogood → pruning cycle at barrier | propagator.rkt |
| **L6** | `exchange S0 <-> S1` | NAF suspension until S0 quiesces | relations.rkt |
| — | `current-speculation-stack` (RETIRED) | Worldview cell read inside fire functions | propagator.rkt |
| — | PU-per-branch | `make-branch-pu` (implements `BranchPU` interface) | propagator.rkt |

*(6.2: D.1 correspondence table removed. See §3.8 for the expanded D.2+ version.)*

---

## §4 Phase Design: Phases 0–5

### Phase 0: Pre-0 Benchmarks + Acceptance File

**Existing infrastructure** (17 solver test files, ~889 assertions; 3 adversarial benchmarks; 2 solver micro-benchmarks):

| Asset | Purpose | Baseline |
|---|---|---|
| `solve-adversarial.prologos` (281 lines, 14 sections) | Full DFS solver path: unification, backtracking, conjunction, is-goals, narrowing, facts, constructors | bench-ab.rkt baseline |
| `constraints-adversarial.prologos` | Prelude loading + registry + per-command cell allocation | bench-ab.rkt baseline |
| `scheduler-adversarial.prologos` | BSP overhead: deep nesting, wide types, topology ping-pong | bench-ab.rkt baseline |
| `bench-solve-pipeline.rkt` | Micro: full solve path with controlled relation stores | bench-micro.rkt |
| `bench-solver-unify.rkt` | Micro: DFS unification primitives (walk, unify-terms, normalize) | bench-micro.rkt |
| 17 solver test files (~889 assertions) | Functional correctness: relations, narrowing, WF engine, solver config, tabling | raco test |

#### Pre-0 Baseline Data (R6: captured, informs design)

| Benchmark | Baseline | Notes |
|---|---|---|
| solve-adversarial.prologos | 4221ms median | DFS solver: 14 sections, 281 lines |
| constraints-adversarial.prologos | 4392ms median | Prelude + registry + per-command cells |
| scheduler-adversarial.prologos | 3855ms median | BSP overhead: deep/wide types |
| atms-adversarial.prologos | 4521ms median | NEW: 12 sections, 125 commands |
| bench-solve-pipeline: simple unify ×2000 | 0.24ms | Per-goal overhead |
| bench-solve-pipeline: 50 goals ×500 | 6.61ms | Conjunction overhead |
| bench-solver-unify: deep walk ×50 bindings | 14.67ms | Substitution walk |
| bench-solver-unify: binary tree d=8 | 4.27ms | Structural unification |

**Track 2 infrastructure baselines** (bench-bsp-le-track2.rkt):

| Operation | Time | Per-op | Design implication |
|---|---|---|---|
| TMS read depth 1/5/10 | 1.9/8.3/17.8ms per 100K | 19/83/178 ns | Linear in depth → PU-per-branch avoids depth scaling |
| TMS write depth 1/5/10 | 1.1/6.9/14.3ms per 50K | 21/137/287 ns | Linear in depth |
| TMS commit leaf/nested | 13.7/3.7ms per 100K/50K | 137/75 ns | Commit is cheap |
| ATMS assume | 1.9ms per 10K | 190 ns | Cheap per-assumption |
| ATMS amb (3/10 alternatives) | 12.5/20.9ms per 5K/2K | 2.5/10.5 μs | Linear in N |
| Intersection check (10∩2) | 12.5ms per 200K | 62 ns | Filtered nogood watcher is viable |
| Subset check (2⊆10) | 6.1ms per 200K | 30 ns | Consistency check is cheap |
| make-prop-network | 0.9ms per 10K | 90 ns | PU creation base cost |
| net-new-cell | 1.4ms per 5K | 270 ns | Cell allocation |
| net-add-propagator | 1.6ms per 2K | 810 ns | Propagator registration |
| run-to-quiescence (empty/1-prop) | 3.3/15.1ms per 10K/5K | 330ns/3μs | Scheduler overhead |

**Key design implications from data**: PU creation (network + cells + propagators) ≈ 5-10μs. For 10-way branching ≈ 50-100μs — dominated by computation, not allocation. Decision cell narrowing (set-intersection) ≈ 62ns — negligible. The architecture is viable from a performance standpoint.

#### Phase 0a: Baseline Capture

**Run and record** (all before any code changes):

```bash
# 1. Comparative: A/B baseline for all adversarial benchmarks
racket tools/bench-ab.rkt --runs 15 benchmarks/comparative/solve-adversarial.prologos --output data/benchmarks/bsp-le-t2-baseline-solve.json
racket tools/bench-ab.rkt --runs 15 benchmarks/comparative/constraints-adversarial.prologos --output data/benchmarks/bsp-le-t2-baseline-constraints.json
racket tools/bench-ab.rkt --runs 15 benchmarks/comparative/scheduler-adversarial.prologos --output data/benchmarks/bsp-le-t2-baseline-scheduler.json

# 2. Micro: solver primitives baseline
racket benchmarks/micro/bench-solve-pipeline.rkt > data/benchmarks/bsp-le-t2-baseline-micro-pipeline.txt
racket benchmarks/micro/bench-solver-unify.rkt > data/benchmarks/bsp-le-t2-baseline-micro-unify.txt

# 3. Full suite: record timings for regression detection
raco make driver.rkt
racket tools/run-affected-tests.rkt --all --no-precompile

# 4. Per-command verbose: identify hotspots in solve-adversarial
racket -e '(require "driver.rkt") (process-file "benchmarks/comparative/solve-adversarial.prologos" #:verbose #t)' 2> data/benchmarks/bsp-le-t2-baseline-verbose.txt
```

#### Phase 0b: New Micro-Benchmarks

**`bench-bsp-le-track2.rkt`** — new micro-benchmark targeting Track 2 infrastructure:

| Benchmark | What it measures | Why it matters |
|---|---|---|
| `worldview-cell-create` | Time to create a worldview lattice cell | N cells per N branches |
| `worldview-merge` | Time to merge two worldview sets (set-union) | Every cell write under speculation |
| `nogood-check` | Time to check worldview against M nogoods | Per-branch per-nogood-write |
| `nogood-intersection-filter` | Time to check intersection of nogood with branch assumptions | Core of filtered RKan watcher |
| `pu-create-from-parent` | Time to create a branch PU from parent network | N PUs per N-way amb |
| `pu-drop` | Time to drop a branch PU | Structural GC on contradiction |
| `pu-commit` | Time to commit a branch PU to parent | Promoting winning branch |
| `tms-read-depth-N` | Time to read through TMS tree at depth N (1, 2, 5, 10) | Deep speculation overhead |
| `tms-write-depth-N` | Time to write through TMS tree at depth N | Deep branch divergence cost |
| `clause-match-bulk-N` | Time to bulk-match N clauses (α-rename + unify) | N→M filtering cost |

These provide per-operation baselines that isolate Track 2 infrastructure costs from end-to-end solver costs. The adversarial benchmarks measure the whole pipeline; the micro-benchmarks measure the building blocks.

#### Phase 0c: New Adversarial Benchmark

**`atms-adversarial.prologos`** — new comparative benchmark targeting propagator-native search:

| Section | What it stresses | Expected behavior |
|---|---|---|
| A1: Deterministic queries (no amb) | Tier 1 overhead: zero ATMS cost for deterministic queries | Must match DFS within 5% |
| A2: Binary choice (2 clauses) | Minimal branching: 2 PUs, 1 nogood possible | < 2× DFS (branching overhead) |
| A3: Wide choice (10+ clauses) | N→M filtering: bulk clause matching efficiency | N PUs created, M survive |
| A4: Deep choice nesting (5+ levels) | TMS depth: speculation stack → TMS tree depth 5+ | TMS read/write at depth |
| A5: Contradiction cascade | Nogood propagation: one contradiction triggers pruning across branches | Filtered RKan efficiency |
| A6: Tabled predicate (non-recursive) | Producer/consumer: memoization avoids redundant derivation | First call = producer, subsequent = consumer |
| A7: Many small solves (50+) | Per-command ATMS overhead: worldview cell setup/teardown | Tier 1 for deterministic, Tier 2 only when needed |
| A8: Shared variables across branches | Branch cell isolation: writes in branch A invisible to branch B | TMS branch separation |
| A9: Mixed deterministic + nondeterministic | Tier 1→2 transition mid-query | Seamless transition |
| A10: Concurrent worldview exploration | Multiple PUs in same BSP superstep | Parallelism without interference |
| A11: Transitive variable chains | Substitution propagation depth in cell-tree model | Cell-tree walk chains vs hasheq walk |
| A12: NAF + ATMS interaction | Negation-as-failure under worldview branching | S1 fires after S0 quiescence per worldview |

Each section is designed to be run independently AND as part of the full benchmark. Sections A1 and A7 specifically measure overhead — they should be competitive with (or better than) DFS, since deterministic queries should never touch ATMS infrastructure.

#### Phase 0d: Acceptance File

**`examples/2026-04-07-bsp-le-track2.prologos`** — exercises all Track 2 features in ideal WS syntax:

```
Section 1: Basic solve (Phase 6-7 baseline)
  - Ground fact lookup
  - Single-clause defr
  - Multi-clause defr with backtracking
  - Inline rel with conjunction
  
Section 2: Propagator-native search (Phase 6)
  - Multi-clause dispatch → comment: "PU-per-clause"
  - Shared variables across goals → comment: "dataflow-ordered"
  - Contradiction → comment: "nogood recorded, branch pruned"
  
Section 3: Tabling (Phase 8)
  - Non-recursive tabled predicate
  - Consumer reads producer's answers
  
Section 4: Solver config (Phase 9-10)
  - :strategy :depth-first (DFS backward compat)
  - :strategy :auto (Tier 1 → Tier 2)
  - :tabling :by-default
  
Section 5: Explanation/provenance (future — commented out)
  - explain query → derivation tree
```

Sections 1-4 are uncommented as phases complete. Section 5 is aspirational (Track 5 scope — `:provenance :atms`).

**Phase completion gate**: Acceptance file runs at Level 3 (`process-file`) with 0 errors. Each phase uncomments its corresponding section.

### Phase 1: Decision Cell Infrastructure + Parallel-Map Propagator

**What changes**:

1. **`propagator.rkt`**: Decision cell lattice infrastructure:
   - `decision-domain-merge`: `set-intersection` (narrowing: more restrictions = more info)
   - `decision-domain-bot?`: `(equal? domain all-alternatives)` (all viable = least info)
   - `decision-domain-top?`: `(hash-empty? domain)` (empty = contradicted)
   - Decision cells are SRE structural lattice cells — alternatives = constructors
   - Register decision domain as SRE domain via Track 2G property infrastructure

2. **`propagator.rkt`**: Nogood cell infrastructure:
   - `nogood-merge`: `set-union` on sets of sets (monotone: nogoods only grow)
   - Nogood cell is a regular cell created by `net-new-cell` with `nogood-merge`

3. **`propagator.rkt`**: Assumptions accumulator cell + counter cell:
   - `assumptions-merge`: `set-union` (monotone: assumptions only added)
   - Counter cell: `max` merge (monotone Nat)

4. **`propagator.rkt`**: Broadcast propagator pattern (M1, replaces N-propagator model):
   - `net-add-broadcast-propagator`: installs ONE propagator that processes N items internally
   - ONE fire, ONE diff, ONE merge — constant infrastructure overhead regardless of N
   - Results accumulated via single cell write with merged output
   - The `propagator` struct gains an optional `broadcast-profile` field:
     `(broadcast-profile items item-fn merge-fn)` — metadata the scheduler uses to decompose for parallel execution
   - When `broadcast-profile` is `#f` (default): existing behavior, zero overhead for non-broadcast propagators
   - When `broadcast-profile` is set: the scheduler checks item count vs threshold. Below: sequential loop. Above: decompose into K chunks across parallel threads (Racket 9 `thread #:pool 'own`).
   - This IS a polynomial functor: fan-out depends on input data. The broadcast-profile carries the arity.

   **A/B benchmark data (Phase 1Bi)**:
   | N | A (N-propagator) | B (broadcast) | Ratio |
   |---|---|---|---|
   | 3 | 6.2 μs | 2.7 μs | 2.3× |
   | 10 | 17.3 μs | 2.9 μs | 5.9× |
   | 50 | 127.2 μs | 3.7 μs | 34.7× |
   | 100 | 364.4 μs | 4.8 μs | 75.6× |

   N-propagator model: linear overhead (810ns install + 3μs fire per propagator).
   Broadcast model: constant overhead (~2.7μs base + ~0.02μs per item).

   First consumer: clause matching (Phase 6). Generalizes to: per-nogood commitment tracking (Phase 3), goal conjunction (Phase 7), pairwise nogood installation (Phase 5), pattern matching, trait lookup, module resolution.

5. **Worldview = derived bitmask** (§2.6b, updated D.10): Decision cells are PRIMARY, organized in ONE compound decisions cell (component-indexed by group-id). The compound cell's merge maintains a derived bitmask (OR of committed assumptions' bit positions). ONE projection propagator writes this bitmask to the worldview cache cell (cell-id 1). `net-cell-read` reads the cache for O(1) tagged-cell-value filtering. Retraction = component narrowing → merge recomputes bitmask → bits naturally disappear. No micro-propagators, no fan-in aggregation — the merge IS the aggregation.

6. **Bitmask representation** (Hasse diagram, additive): The `decision-set` struct gains an optional `bitmask` field — a fixnum where bit i = 1 means "assumption with integer id i is viable." Computed at creation time from the alternatives (one-time cost: OR of assumption-id integers). Maintained through merge/narrow (one extra bitwise op per merge). Enables O(1) Hasse-diagram operations:
   - Hamming distance: `popcount(a XOR b)` — metric for Gray code traversal
   - Adjacency test: `popcount(a XOR b) == 1` — Hasse neighbors
   - Subcube membership: `(wv AND ng) == ng` — nogood containment
   - Gray code generation: standard reflected code on bit positions
   
   This is ADDITIVE — the hasheq remains the primary representation for enumeration and merge. The bitmask is a derived projection for fast Hasse operations. Phase 6 reads it for Gray code traversal. Phase 3 reads it for subcube pruning.

**R3 revision**: No field added to `prop-net-cold` or `prop-net-warm`. Decision cell IDs are tracked by the solver infrastructure (per-query), not by the network struct.

**Test coverage**: Decision cell creation + narrowing. Nogood cell creation + accumulation. Parallel-map propagator with 3/5/10 inputs. SRE domain registration for decision domain.

**Network Reality Check**:
1. `net-new-cell` calls: decision cells, nogood cell, assumptions cell, counter cell
2. `net-cell-write` produces result: decision narrowing via cell write
3. Cell creation → propagator installation → cell write → cell read = narrowed domain: yes

### Phase 2: PU-Per-Branch Lifecycle

**Design resolutions from Phase 2 mini-design conversation:**

#### 2.1 What a branch PU IS

A branch PU is a `fork-prop-network` of the parent (existing infrastructure, line 437 in propagator.rkt). CHAMP structural sharing means the branch starts as a reference to the same cells/propagators. Branch-local cell writes and propagator registrations create new CHAMP paths in the branch only — the parent is structurally unmodified.

The branch PU's identity is its assumption-id `h_i` in the group-level decision cell. **No worldview cell.** The branch accesses the decision cell via component-path `(decision-G . h_i)`, firing only when its own alternative's status changes.

Fresh variable cells for the clause's bindings are created on the branch network after forking. These are PU-local — not visible to the parent or sibling branches.

#### 2.2 Assumption-tagged dependents (emergent branch dissolution)

**There is no `pu-drop` operation.** Branches die by information flow.

Dependent entries in the cell dependents CHAMP gain an optional assumption-id:
- `prop-id → { path, assumption-id-or-#f }`
- Parent propagators: `assumption-id = #f` (always active)
- Branch propagators: `assumption-id = h_i` (active while h_i is viable)

`filter-dependents-by-paths` (which already runs on every cell change) gains one additional check per entry: "is this propagator's assumption still in its decision cell's domain?" This is one CHAMP lookup (~30ns) per dependent entry.

When a decision cell narrows to eliminate alternative h_i:
- All propagators tagged with h_i become invisible to the scheduler
- They are never fired again — their assumption check fails
- No explicit removal, no iteration, no topology request
- The branch "dissolves" by information flow through the decision cell

This is the TMS principle applied to DEPENDENTS: a TMS-tagged value is invisible under the wrong worldview; a TMS-tagged dependent is invisible when its assumption is not viable. Same mechanism, applied to scheduling rather than cell reads.

#### 2.3 `pu-commit` = cell write to outer accumulator

Committing a branch does NOT merge the branch CHAMP into the parent. It writes the branch's RESULT to the outer answer-accumulator cell. The branch-committer propagator (NTT §3.3) fires when:
1. The decision cell is a singleton containing h_i (this branch was chosen)
2. The branch's result cell is non-bot

It writes the result to the outer accumulator (cross-PU bridge — branch fire function writes to parent's cell). After the write, the branch network is discarded same as a dead branch. The answer survives because it was written to the parent's cell.

**The distinction between drop and commit is ONLY whether the branch-committer fires before dissolution.** Both end with the branch becoming inert (assumption-tagged dependents ignored by scheduler).

#### 2.4 Inert dependent accumulation + instrumentation checkpoint

Inert dependent entries accumulate in the dependents CHAMP. Cost: ~30ns per inert entry per cell change (one decision cell lookup). For a cell with 16 inert entries, ~480ns overhead per change.

**Instrumentation**: Add a performance counter `perf-inc-inert-dependent-skip!` in `filter-dependents-by-paths`. Count how many inert entries are skipped per cell per change. This gives real data from adversarial benchmarks.

**Explicit checkpoint (SMART request)**: After Phase 11 parity validation, review the inert-dependent instrumentation data. If any cell accumulates >50 inert entries on hot paths, design and implement S(-1) dependents cleanup:
- The dependents set IS a lattice (set under ⊇, narrowing via intersection)
- Cleanup = `current-dependents ∩ viable-dependents` (lattice narrowing operation)
- A per-cell "dependents-cleaner" propagator at S(-1) reads dependents + decision cells, writes narrowed set
- Multiple cells fire their cleaners in parallel in the same S(-1) superstep (broadcast)
- This IS emergent, parallel, on-network — not step-think iteration

The cleanup is DEFERRED, not omitted. The instrumentation ensures we return to the question with data.

#### 2.5 Implementation

**What changes**:

1. **`propagator.rkt`**: `make-branch-pu`:
   - Calls `fork-prop-network` (existing) on the parent network
   - Takes assumption-id `h_i` as parameter — stored for tagging branch propagators
   - Returns `(values branch-net h_i)` — the branch network and its assumption identity

2. **`propagator.rkt`**: Extend `net-add-propagator` with `#:assumption` parameter:
   - When `#:assumption h_i` is provided, the dependent entry in the cell's dependents CHAMP carries `h_i`
   - Default `#f` = always active (backward compatible)
   - `make-branch-pu` propagators use `#:assumption h_i`

3. **`propagator.rkt`**: Extend `filter-dependents-by-paths`:
   - For each dependent entry with an assumption-id, check viability: is the assumption still in its decision cell's domain?
   - Requires access to decision cell state during filtering — the solver context provides the decision cell-id map
   - If not viable: skip (don't schedule). Increment `perf-inc-inert-dependent-skip!`.

4. **No `pu-drop` function.** Branch dissolution is emergent from decision cell narrowing.

5. **No `pu-commit` function.** Branch commitment is the `branch-committer` propagator writing to the outer accumulator cell.

**Interaction with existing infrastructure**: `fork-prop-network` (Track 10 Phase 3b) already does the CHAMP fork. `net-remove-propagator-from-dependents` (P2) and `net-clear-dependents` (P3) exist but are NOT used for branch lifecycle — the assumption-tagging mechanism replaces them for this use case.

**Test coverage**:
- Branch creation via fork: parent cells readable from branch
- Branch-local writes invisible to parent (CHAMP isolation)
- Assumption-tagged dependents: tagged propagator fires when assumption viable, skipped when not
- Decision cell narrows → tagged propagator becomes inert (emergent dissolution)
- Branch-committer writes to outer accumulator (cross-PU bridge)
- Inert dependent counter increments correctly

### Phase 3: Per-Nogood Propagators (Right Kan Extension)

**Design resolutions from Phase 3 mini-design conversation:**

#### 3.1 Commitment cell — SRE structural lattice analysis

**(SRE lattice lens applied):**
- **Classification**: STRUCTURAL — component-indexed by group. One compound cell per nogood, not |ng| separate cells (saves cell allocation, uses component-indexing).
- **Algebraic properties**: Product of |ng| OR-lattices. Per-position: `#f ⊔ aid = aid`, `aid ⊔ aid = aid`. Idempotent, commutative, associative.
- **Bridges**: Decision cell → commitment position (per-group bridge). Commitment cell → narrower (fan-in threshold). Commitment cell → nogood cell (contradiction = provenance).
- **Primary vs derived**: Commitment positions are PRIMARY (written by bridges from decisions). No `committed-count` field — the narrower reads positions directly (2-3 reads for |ng| = 2-3).
- **Structural unification insight**: The commitment cell IS the nogood pattern in the process of being unified against decision state. Each position fill is a partial match. Full fill = pattern fully matched = contradiction proven. The cell value IS the provenance (no gathering needed).

**Cell value**: `hasheq { G_A: #f | h_A,  G_B: #f | h_B, ... }`
- `#f` = group not yet committed to its nogood member
- `h_G` (assumption-id) = group committed — carries the IDENTITY of what committed (provenance)
- Merge: per-position `(λ [old new] (or new old))` — once set, stays set
- Contradiction: all positions non-#f (full pattern match = nogood realized)
- §3.1a compliant: propagators access via component-paths per group

#### 3.2 Commit-tracker — broadcast over groups

ONE broadcast propagator per nogood. Items = groups in the nogood. For each group: reads decision-cell-G via the broadcast's shared input values. If decision-cell-G is a singleton containing the nogood member h_G → writes `{G: h_G}` to the commitment cell at component position G.

Cell-ids for each group's decision cell are captured at installation time (structural co-installation, not a mapping lookup). The broadcast `item-fn`:
```
(λ [group-id input-values]
  ;; input-values[i] = decision cell value for group-id
  ;; (positional, established at installation — no mapping)
  (when (and (decision-committed? decision-val)
             (equal? (decision-committed-assumption decision-val)
                     (nogood-member-for-group ng group-id)))
    {group-id: (nogood-member-for-group ng group-id)}))
```

#### 3.3 Narrower — threshold on commitment cell

Watches commitment cell (all positions via component-paths). For |ng| = 2: reads two positions. If one is non-#f and the other is #f → narrow the #f group's decision cell to exclude its nogood member. Two reads, one conditional, zero scanning.

For |ng| = 3: reads three positions. If two non-#f, one #f → narrow the #f group. Three reads, one conditional.

The output target (which decision cell to narrow) is determined by WHICH position is still #f — structural, not scanned.

#### 3.4 Contradiction detector — provenance IS the cell value

When ALL commitment positions are non-#f, the cell value `{G_A: h_A, G_B: h_B}` IS the nogood. A contradiction bridge reads the commitment cell and writes the set of assumption-ids `{h_A, h_B}` to the nogoods cell. **No gathering, no scanning — the cell value IS the explanation.**

This is the structural dual: the commitment cell is the nogood "proof in progress." Each position fill is evidence. Full fill = proof complete. The proof IS the data.

#### 3.5 Topology trigger — data-driven descriptors, not callbacks

When new nogoods are discovered (nogoods cell grows), a topology watcher broadcasts `nogood-install-request` DESCRIPTORS (data, not callbacks) to the topology-request cell:

```racket
(struct nogood-install-request
  (nogood-set       ;; hasheq of assumption-ids
   group-cell-ids)  ;; (listof (cons group-id cell-id))
  #:transparent)
```

The topology-request cell's merge = set-union. Duplicate requests for the same nogood deduplicate naturally (struct equality). **No "last-seen" cell, no diff computation, no installed-set tracking.** The watcher broadcasts requests for ALL nogoods in the cell each time it fires. Duplicates merge to no-op. New nogoods produce new requests. The topology stratum pattern-matches on `nogood-install-request` and installs the per-nogood infrastructure (commitment cell + commit-tracker + narrower + contradiction detector).

#### 3.6 Decision-level contradiction detection

When a group-level decision cell narrows to ∅ (empty), the per-decision contradiction detector (installed per group at `atms-amb` time) writes to the nogoods cell. The nogood = the branch's own assumption-id set. The branch knows its own identity (from `make-branch-pu`'s assumption-id). The detector writes `{h_i}` for a single-branch contradiction, or the full assumption set for compound contradictions derived from the commitment cell (§3.4).

#### 3.7 Implementation

**What changes**:

1. **`decision-cell.rkt`**: Commitment cell merge function + contradiction predicate:
   - `commitment-merge`: per-position OR (using hash-union with `or` combiner)
   - `commitment-contradicts?`: all positions non-#f
   - `commitment-provenance`: extract assumption-id set from committed positions

2. **`propagator.rkt`**: `install-per-nogood-infrastructure`:
   - Creates commitment cell (one compound cell, component-indexed by group)
   - Installs broadcast commit-tracker (broadcast over groups, writes component positions)
   - Installs narrower (threshold propagator, watches commitment positions)
   - Installs contradiction detector (bridge: commitment cell → nogoods cell when full)

3. **`propagator.rkt`**: `nogood-install-request` struct + topology handler:
   - Struct: `(nogood-set, group-cell-ids)` — data descriptor
   - Topology stratum pattern-matches on this struct, calls `install-per-nogood-infrastructure`

4. **`propagator.rkt`**: Nogood topology watcher:
   - Watches nogoods cell
   - Broadcasts `nogood-install-request` for all nogoods in the cell
   - Topology-request cell merge deduplicates

**Cost analysis** (Pre-0 data; corrected per 4.2):
- Per nogood: 1 commitment cell (~270ns) + 1 broadcast propagator (~810ns) + 1 narrower (~810ns) + 1 contradiction detector (~810ns) = ~2.7μs install
- Per commit-tracker fire: ONE broadcast fire processing |ng| groups (2-3 reads) = ~180ns
- Per narrower fire: |ng| position reads (2-3) + one conditional = ~90ns
- Per contradiction write: read commitment cell + write to nogoods cell = ~600ns
- At 100 nogoods: ~270μs install, then propagation overhead proportional to affected nogoods only

**This IS the right Kan extension**: each nogood is its own information-flow unit. The commitment cell IS the structural unification of the nogood pattern against decision state. Provenance emerges from the cell value. Topology installation is data-driven. No scanning, no callbacks, no mutable closure state.

**(Hasse diagram: subcube pruning)** When a nogood is learned, the contradicted worldviews form a subcube of the worldview hypercube. With bitmask representation (Phase 1 item 6), subcube membership is O(1): `(wv AND ng-mask) == ng-mask`. The nogood topology watcher can use this for fast filtering — only install per-nogood infrastructure for nogoods whose subcube intersects the currently active worldviews. Subcubes that are entirely outside the explored region need no infrastructure.

**Test coverage**:
- Commitment cell merge (per-position OR, non-#f survives)
- Commit-tracker fires on decision singleton, writes correct position
- Narrower fires at N-1 threshold, narrows correct remaining group
- Contradiction detector fires at all-filled, writes correct provenance
- Topology watcher deduplicates duplicate nogood requests
- End-to-end: decision narrows → commitment tracks → narrower narrows sibling → contradiction if all committed

### Phase 4: Bitmask-Tagged Cell Values (TMS Tree Retired)

**Design resolution from Phase 4 mini-design conversation (hypercube-informed + PUnify-informed):**

#### 4.1 The Insight Chain

1. **TMS tree walk is step-think**: `tms-read(cell, stack)` walks a recursive tree indexed by an ORDERED list. Stack `(h1 h2)` ≠ `(h2 h1)` despite representing the SAME worldview in Q_n. The ordering is an imperative artifact.

2. **PU fork replaces TMS for value isolation**: CHAMP structural sharing provides branch isolation. BUT commit requires merging the fork back — `bulk-merge-writes` is an imperative loop (step-think heritage).

3. **Bitmask-tagged cell values eliminate BOTH**: Writes during speculation are tagged with the worldview bitmask. Reads filter by bitmask subset check. Commit/retract EMERGE from worldview information flow — no explicit operations needed.

4. **PUnify composes naturally**: Unification propagators during speculation are assumption-tagged (Phase 2). Their writes are bitmask-tagged. Reconciliation between branches is SRE structural unification (already on-network). No new infrastructure.

#### 4.2 Bitmask-Tagged Cell Value Model

```
tagged-cell-value:
  base:     value               ;; unconditional (worldview = 0, always visible)
  entries:  (listof (cons bitmask value))  ;; speculative writes

Read under worldview W (from worldview cache cell):
  Find entry with MOST-SPECIFIC bitmask that is SUBSET of W:
  max { (bm . v) ∈ entries | (bm AND W) == bm } by popcount(bm)
  If no entry matches: return base
  O(K) bitmask checks for K entries, each O(1)

Write under worldview W:
  Append (cons W new-value) to entries
  Monotone: entries only accumulate

Merge:
  Union entries from both sides (monotone)
```

For elaboration speculation: K = 2-3 (Church fold binary, union types binary). Negligible overhead.

The Hasse diagram insight (Q6): the "most specific match" IS the nearest ancestor in the hypercube. The bitmask subset check IS the Hasse containment test from §3.2.

**SRE lattice lens on tagged-cell-value:**
- Classification: VALUE lattice (entries accumulate, no structural decomposition)
- Properties: monotone (entries only grow), order-independent (entry ordering irrelevant)
- Hasse: the entries' bitmasks form a sub-poset of Q_n. The read finds the maximum of this sub-poset below the worldview node.
- Bridges: Decision cells → worldview cache → tagged-cell-value reads (filtering)

#### 4.3 Worldview Bitmask Cache Cell

A derived cell (well-known cell-id, e.g., cell-id 1) holds the current worldview bitmask. Computed by a fan-in propagator that watches all decision cells and ORs committed assumptions' bit positions.

- `net-cell-read` reads this ONE cell for O(1) bitmask filtering.
- Derived, not primary — consistent with decision #1 (worldview emerges from decisions).
- In Tier 1 (no speculation): cache cell holds 0 (empty worldview) → reads return base value → zero overhead.

#### 4.4 Commit and Retract Are Eliminated

**Commit** (branch succeeds): The worldview naturally includes the branch's assumption. The worldview cache cell's bitmask has the assumption's bit set. Future reads of tagged cells see the branch's entries because `(entry-bitmask AND worldview) == entry-bitmask` passes. **Nothing to do.**

**Retract** (branch fails): The assumption is eliminated from its decision cell. The worldview cache cell's bitmask does NOT include the assumption's bit. Future reads skip the branch's entries. **Nothing to do.**

`net-commit-assumption` (fold over all cells) → **eliminated**
`net-retract-assumption` (fold over all cells) → **eliminated**
`save-meta-state`/`restore-meta-state!` → **eliminated**

Commit/retract emerge from information flow through decision cells → worldview cache → tagged-cell-value reads. Fully on-network.

#### 4.5 PUnify Composition

PUnify propagators installed during speculation:
- Are assumption-tagged (Phase 2) → fire only when branch is viable
- Write to parent cells with bitmask tag → visible only under branch's worldview
- Reconciliation between branches = SRE structural unification (on-network, all-at-once)
- No new PUnify infrastructure needed — it composes with bitmask tags naturally

#### 4.6 What Changes (6 files per R1 audit)

1. **`propagator.rkt`**: Core cell operations gain bitmask-tagged support:
   - New `tagged-cell-value` struct (base + entries list)
   - `net-cell-read`: if `tagged-cell-value?` → filter entries by worldview cache bitmask → most-specific match. Replaces TMS check.
   - `net-cell-write`: if worldview bitmask is non-zero → tag the write. Replaces TMS wrapping.
   - Worldview cache cell infrastructure (well-known cell-id, fan-in propagator)
   - `net-commit-assumption` / `net-retract-assumption` → deprecated (dead code)
   - `tms-cell-value` / `tms-read` / `tms-write` → deprecated (dead code)

2. **`elab-speculation-bridge.rkt`** (line 227): Replace `parameterize` + `net-commit-assumption` with: write assumption to decision cell (worldview changes, tagged values become visible). Replace `net-retract-assumption` with: narrow decision cell (worldview changes, tagged values become invisible). The thunk runs with the worldview cache reflecting the assumption — all writes are automatically tagged.

3. **`typing-propagators.rkt`** (6 parameterize sites): Replace `parameterize` around fire functions with: the fire function runs under a worldview that includes the branch assumption. The worldview cache cell reflects this. Writes are automatically tagged.

4. **`metavar-store.rkt`** (line 1321): Replace `(current-speculation-stack)` read with worldview cache cell read. Meta solution under speculation = bitmask-tagged entry.

5. **`cell-ops.rkt`** (lines 82-83): `worldview-visible?` reads the worldview cache bitmask and checks entry tag. Replaces speculation stack membership check with bitmask subset check.

6. **`tests/test-tms-cell.rkt`**: Rewrite for bitmask-tagged model. TMS tree tests become legacy.

**R1 correction**: `narrowing.rkt` NOT in scope (doesn't read the parameter).

#### 4.7 Cascade Effects on Later Phases

- **Phase 5 (ATMS dissolution)**: `tms-cells` field retirement now happens in Phase 4 (TMS tree is dead code here). Phase 5 scope shrinks.
- **Phase 9 (parameter removal)**: `current-speculation-stack` is dead code after Phase 4. Phase 9 removes it + the deprecated TMS functions. Simpler.
- **Phase 6+ (solver)**: The solver uses bitmask-tagged cell values from the start. No separate "solver cell model" — same model as elaboration.

#### 4.8 Inert Entry Accumulation

Tagged entries from failed branches remain in cells (invisible but present). For elaboration (K = 2-3): negligible. For deep solver exploration (K = 100+): extends the Phase 11 checkpoint to cover inert tagged entries alongside inert dependents. The S(-1) lattice-narrowing cleanup pattern applies: `current-entries ∩ viable-entries`.

**Test coverage**:
- Tagged-cell-value merge (append entries, monotone)
- Read with worldview bitmask (most-specific match, subset check)
- Write under non-zero worldview (auto-tagging)
- Worldview cache cell (fan-in from decision cells)
- Elaboration speculation parity (same results as TMS-based)
- PUnify propagators produce bitmask-tagged writes correctly
- TMS code path confirmed dead (no `tms-cell-value?` hits)

### Phase 5: ATMS Struct Dissolution + Compound Cell Architecture + Consumer Migration

**Updated D.10**: Incorporates compound cell design, fire-once audit, component-path compliance, broadcast extension, worldview cache wiring, and deferred Phase 4c consumer migration.

#### 5.1 Infrastructure Prep

**5.1a: Move `net-add-fire-once-propagator` to propagator.rkt.** Currently in typing-propagators.rkt. Fire-once is a general infrastructure pattern, not typing-specific. Move to propagator.rkt and export.

**5.1b: Extend `net-add-broadcast-propagator` for component-paths.** Currently hardcodes `(dependent-entry #f #f #f)`. Add optional `#:component-paths`, `#:assumption`, `#:decision-cell` parameters (same interface as `net-add-propagator`). The commit-tracker broadcast (Phase 3) needs component-indexed watching of the compound decisions cell.

**5.1c: Update worldview cache cell merge.** Change from `bitwise-ior` (monotone accumulate) to replacement merge `(lambda (old new) new)`. The projection propagator writes the complete recomputed bitmask — replacement handles retraction correctly (removed bits disappear).

#### 5.2 Compound Decisions Cell

ONE cell holds ALL decision state, component-indexed by group-id.

```
(struct decisions-state (components bitmask) #:transparent)
;; components: hasheq group-id → decision-domain-value
;; bitmask: integer — DERIVED, recomputed by merge from all components
```

Merge function:
```
(define (decisions-state-merge old new)
  ;; Per-component: decision-domain-merge (set-intersection narrowing)
  (define merged-comps ...)   ;; merge-per-key: union keys, merge shared
  ;; Recompute bitmask from ALL components (O(M) for M groups, each O(1))
  (define bm
    (for/fold ([acc 0]) ([(gid dv) (in-hash merged-comps)])
      (if (decision-committed? dv)
          (bitwise-ior acc (arithmetic-shift 1 (assumption-id-n
                            (decision-committed-assumption dv))))
          acc)))
  (decisions-state merged-comps bm))
```

The bitmask is a **structural property of the compound value**, maintained by the merge, not by any propagator. Retraction (component narrowing) naturally removes bits — the merge recomputes from scratch each time.

**Cell allocation**: M `atms-amb` calls → 1 compound cell (not M separate cells).

**Solver context**: The `atms` struct is REMOVED. Replaced by `solver-context` record holding cell-ids:
- `decisions-cid`: the ONE compound decisions cell
- `assumptions-cid`: assumptions accumulator cell (set-union)
- `nogoods-cid`: nogood accumulator cell (set-union)
- `counter-cid`: assumption counter cell (max merge)
- `answer-accumulator-cid`: answer accumulator (set-union)

This is a phone book (WHERE the cells are), not state (what the cells HOLD). P4 self-critique resolution: no second source of truth.

#### 5.3 Compound Commitments Cell

Same pattern for per-nogood commitment tracking. ONE cell, component-indexed by nogood-id.

```
(struct commitments-state (components) #:transparent)
;; components: hasheq nogood-id → commitment-value
```

Merge: per-component dispatch to `commitment-merge`. Each nogood's commitment state is independent — component-indexed access preserves per-nogood precision.

**Cell allocation**: K nogoods → 1 compound cell (not K separate cells).

#### 5.4 Worldview Cache Wiring

ONE projection propagator watches the compound decisions cell, extracts the `bitmask` field, writes to the worldview cache cell (cell-id 1).

```
;; Projection propagator: compound decisions → worldview cache
(define projection-fire-fn
  (lambda (net)
    (define ds (net-cell-read-raw net decisions-cid))  ;; read compound value
    (define bm (if (decisions-state? ds) (decisions-state-bitmask ds) 0))
    (net-cell-write net worldview-cache-cell-id bm)))
```

O(1) work per fire: extract a struct field, write an integer. NOT fire-once — fires on every compound cell change (bitmask evolves as decisions commit). But lightweight: one field extraction, one integer comparison (merge checks equality).

#### 5.5 Per-Nogood Propagator Updates (Fire-Once + Component-Paths)

The Phase 3 per-nogood propagators are updated:

| Propagator | Fire-once? | Component-paths | Change |
|---|---|---|---|
| Broadcast commit-tracker | No (fires on each decision change) | `((decisions-cid . group-A) (decisions-cid . group-B) ...)` per nogood members | Add component-paths via extended broadcast (5.1b) |
| Nogood narrower | **Yes** (fire-once, self-cleaning) | `((commitments-cid . nogood-id))` | Change to `net-add-fire-once-propagator`. Reads specific commitment component. |
| Contradiction detector | **Yes** (fire-once, self-cleaning) | `((commitments-cid . nogood-id))` | Change to `net-add-fire-once-propagator`. Reads specific commitment component. |
| Worldview projection | No (fires on each compound change) | N/A (watches entire compound cell) | New. |

#### 5.6 ATMS Operation Migration

| ATMS Operation | Replacement | Notes |
|---|---|---|
| `atms-assume` | Write to assumptions-cell + counter-cell. Add trivial `{h}` component to compound decisions cell. | Component write to compound cell |
| `atms-retract` | Narrow component in compound decisions cell (§2.6c) | SRE structural narrowing. Merge recomputes bitmask. |
| `atms-add-nogood` | Write to nogood cell (set-union). Install per-nogood infrastructure against compound cells. | Broadcast commit-tracker uses component-paths on compound decisions cell. |
| `atms-consistent?` | Read compound decisions cell components, check per-component non-empty. No global fan-in (1.2 resolution). | Synchronous query function — correctly off-network. |
| `atms-amb` | Create N assumptions + N components in compound decisions cell + pairwise nogoods via broadcast (§6b) | Single compound cell write adds all N components |
| `atms-read-cell` / `atms-write-cell` | RETIRED — `net-cell-read` / `net-cell-write` | |
| `atms-solve-all` | REPLACED — answer accumulator cell (M5) | |

Retained as query functions (§2.6f): `explain-hypothesis`, `explain-all`, `conflict-graph`, `minimal-diagnoses` (tropical semiring CSP, deferred).

**R5 note**: Only 3 sites call `atms-amb` as an operation (atms.rkt internal, elab-speculation.rkt, reduction.rkt). The 26 `atms-amb` references in the pipeline handle the `expr-atms-amb` AST node — UNCHANGED.

#### 5.7 Consumer Migration (Deferred 4c)

With the compound decisions cell + worldview cache wired via projection propagator, the Phase 4c consumer migration completes:

**`elab-speculation-bridge.rkt`**: Instead of `parameterize([current-speculation-stack (cons hyp-id ...)])`, write a committed component `{hyp-id}` to the compound decisions cell. The merge recomputes the bitmask. The projection propagator updates the worldview cache. `net-cell-write` auto-tags writes via the tagged-cell-value path (Phase 4b). On success: leave the component (committed values visible under bitmask). On failure: restore network box (component disappears with restored network). `net-commit-assumption` and `net-retract-assumption` → **dead code**.

**`cell-ops.rkt`**: `worldview-visible?` changes from stack membership check to bitmask subset check on the worldview cache cell. Read cache cell (cell-id 1), check `(= (bitwise-and entry-bitmask worldview) entry-bitmask)`.

**`metavar-store.rkt`**: `current-speculation-assumption` reads worldview cache cell instead of `current-speculation-stack`.

**`typing-propagators.rkt`**: DEFERRED to Phase 6 (per-fire scoping needs PU isolation; gensym-based assumption-ids need integer conversion).

**`current-speculation-stack`**: Dead code after Phase 5 for sequential speculation consumers. Formal removal in Phase 9 (after typing-propagators migration in Phase 6).

#### 5.8 Test Coverage

**Behavioral parity**:
- `atms-assume` → compound cell component write parity
- `atms-amb` → compound cell N-component creation parity
- `atms-add-nogood` → compound commitments cell + per-nogood infrastructure parity
- Existing solver tests pass via relations.rkt (behavioral parity with DFS)

**Architecture-validating**:
- Compound decisions cell: component writes, merge-maintained bitmask, component-indexed reads
- Worldview projection: compound change → cache update → `net-cell-read` sees correct bitmask
- Compound commitments cell: per-nogood component isolation, commitment-merge per-component
- Fire-once narrower/contradiction detector: fires once, subsequent scheduling is no-op
- Component-path precision: broadcast commit-tracker fires only when watched group changes
- Consumer migration: `elab-speculation-bridge` writes compound cell → auto-tagged cell writes → correct `net-cell-read` under worldview
- Retraction: component narrowing → merge recomputes bitmask → removed bits disappear → tagged-cell-read returns correct value

---

## §5 WS Impact

This track does NOT add or modify user-facing Prologos syntax. The surface forms (`solve`, `defr`, `explain`, `solver`) are unchanged. The changes are entirely in the engine underneath.

WS impact: **none**. No preparse changes, no reader changes, no keyword conflicts.

---

## §6 Phase Design: Phases 6+7 – 11

### Phase 6+7 (Merged): Propagator-Native Solver

**D.11**: Merged Phase 6 (clause-as-assumption) and Phase 7 (goal-as-propagator) into one design scope. Reason: mutual recursion — `install-clause-propagators` calls `install-conjunction` which calls `install-goal-propagator` which calls `install-clause-propagators` for app goals. Cannot be implemented or tested independently.

**What this replaces**: `solve-goals` (relations.rkt:600), `solve-single-goal` (relations.rkt:612), `solve-app-goal` (relations.rkt:825) — the recursive evaluation functions that thread substitutions through `append-map`. The new functions install propagators on a network; execution emerges from dataflow.

**Dual path**: The new propagator-native functions coexist with the DFS functions. `:strategy :atms` uses the propagator path; `:strategy :depth-first` preserves the DFS path. Phase 9 wires `:strategy :auto` to choose.

#### 6+7.1 Core Functions (Mutual Recursion)

**`install-goal-propagator`** — dispatches on goal kind:

| Goal Kind | Action | Stratum | Notes |
|---|---|---|---|
| `app` | `install-clause-propagators` | S0 | May create PUs via topology request |
| `unify` | Unification propagator (cell-tree write) | S0 | Variable cells, PUnify composition |
| `is` | Evaluation propagator (functional expr → cell) | S0 | |
| `not` | NAF propagator (inner goal result → negated) | **S1** | BSP barrier = completion signal (M6). Inner-result cell on outer scope (6.3). |
| `guard` | Guard propagator (condition cell → gate) | **S1** | |

P2: `cut` is NOT implemented, OUT OF SCOPE.

**`install-conjunction`** — takes K goals + parent context:
- ONE broadcast propagator (§6b) over the goals list
- Each goal installed independently via `install-goal-propagator`
- Goal ordering is IRRELEVANT — dataflow determines execution
- Independent goals fire concurrently in the same BSP superstep
- M2: goals list is enumeration, not ordering

**`install-clause-propagators`** — three paths:
- **Facts**: unification propagator per fact row. No branching, no PU.
- **Single clause**: install directly. Tier 1 behavior — deterministic queries never touch ATMS.
- **Multi-clause**: broadcast matching (Step 1) → PU-per-survivor (Step 2).

**`create-branch-pus`** — creates M PUs from M matching clauses:
- Gray code ordering on assumption-id bit positions (hypercube §2.1). Each successive fork from previous fork's network → maximizes CHAMP sharing.
- Each PU gets worldview isolation: `make-branch-pu` writes branch's bitmask to fork's worldview cache cell (eager update, same pattern as solver-assume 5.9a).
- Pairwise nogoods via broadcast (§6b).
- Per-nogood infrastructure (Phase 3, compound commitments cell, fire-once narrower/detector).

**`clause-match-bulk`** — pure function (no network mutation):
- Takes resolved args + clause list
- Per clause: α-rename all variables, attempt arg↔param unification
- Returns `(listof (clause-info . fresh-bindings))` — only survivors
- Called WITHIN broadcast propagator's fire function (M1 resolution)
- Broadcast-profile metadata enables scheduler decomposition

#### 6+7.2 PU Worldview Isolation (Phase 5 Integration)

Each branch PU gets its own worldview via the Phase 5 infrastructure chain:

```
make-branch-pu:
  1. fork-prop-network (CHAMP sharing)
  2. Write branch's compound decisions component to fork's decisions cell
     (narrow: commit this branch, exclude siblings)
  3. Eager worldview cache write: bitmask → fork's cell-id 1
  → All cell writes in fork auto-tagged with branch's bitmask
  → net-cell-read in fork returns branch's tagged entries
  → Commit/retract emergent from worldview bitmask filtering
```

This resolves Phase 5's remaining scaffolding: `solver-state-solve-all` can become a pure query on the answer accumulator cell. PU-per-branch writes under distinct worldviews → distinct tagged entries → `tagged-cell-read` filters correctly per worldview.

#### 6+7.3 typing-propagators Migration (6f)

Phase 5 deferred this because `parameterize` per-fire scoping couldn't be replaced by the network-wide worldview cache. PU isolation resolves it:

- `wrap-with-assumption(fire-fn, aid)` → fire-fn runs in a PU fork with the fork's worldview cache set to aid's bit. No `parameterize` needed.
- `promote-cell-to-tms` → `promote-cell-to-tagged` (Phase 5.9b infrastructure)
- `(assumption-id (gensym 'union-left))` → `solver-state-assume` (integer IDs)
- `current-speculation-stack` → **dead code** after this sub-phase for ALL consumers

#### 6+7.4 Answer Accumulator (M5)

Each query has an answer accumulator cell with set-union merge. Branch-committer propagators write results. After quiescence + S(-1) pruning, the accumulator holds all answers. No scanning.

`solver-state-solve-all` changes from worldview enumeration to: read the answer accumulator cell. Pure query, correctly off-network.

#### 6+7.5 Implementation Order

Bottom-up to manage the mutual recursion:

| Step | What | Dependencies |
|---|---|---|
| 6a | Update `make-branch-pu`: worldview cache init + compound decisions narrowing | Phase 5 compound cell |
| 7a | `install-goal-propagator`: unify + is cases (no recursion) | None |
| 7b | `install-conjunction`: broadcast over goals | 7a |
| 6b | `clause-match-bulk`: pure function | None |
| 6c+d | `install-clause-propagators` + `create-branch-pus`: three-path handler, Gray code PUs | 6a, 6b, 7b |
| 6e | Answer accumulator + solver-state-solve-all update | 6c |
| 6f | typing-propagators PU migration | 6a |
| 7c | NAF + guard S1 propagators | 7a, BSP stratification |
| T | Integration + parity testing | All |

#### 6+7.6 Critique Resolutions

- **3.2**: Arg stability precondition. Readiness guard on broadcast. ✅
- **1.3**: One group-level decision component per amb. PUs read it, don't own it. ✅ (compound cell)
- **M1**: clause-match-bulk is a pure function within a broadcast fire. ✅
- **6.1**: Dual path compressed: Phase 5 deployed tagged path, Phase 6+7 deploys PU isolation → `current-speculation-stack` dead code. ✅
- **6.3**: NAF inner-result cell on outer scope. ✅
- **P3**: PU isolation = correctness (worldview bitmask) + efficiency (structural GC). ✅
- **Hypercube §2.1**: Gray code ordering for CHAMP sharing. ✅

#### 6+7.7 Test Coverage

**Architecture-validating**:
- PU worldview isolation: fork's tagged-cell-value reads filtered by fork's bitmask
- Clause matching: broadcast produces correct survivors, rejected clauses eliminated pre-PU
- Conjunction: order-independent installation, dataflow-determined execution
- Answer accumulator: multi-branch answers collected via set-union

**Behavioral parity**:
- Single-clause queries: same results as DFS
- Multi-clause queries: same answer sets as DFS (order may differ)
- Recursive queries: same results
- Each goal type in isolation

**Old Phase 6 and Phase 7 sections retained below for reference.**

---

### Phase 6 (Original — Superseded by §6+7): Clause-as-Assumption in PUs

**What this replaces**: `solve-app-goal` (relations.rkt:825-893) — the inner loop that iterates clauses via `append-map`, α-renames, unifies arguments, and recurses on clause bodies.

**What changes**:

1. **`relations.rkt`**: New function `install-clause-propagators`:
   - For a given relation call `(rel-name arg1 arg2 ...)`:
   - Look up relation in store → get variants → get facts + clauses
   - **Facts path** (no branching): For each fact row, install a unification propagator that unifies resolved args with fact terms. Facts are deterministic — no `amb`, no PU. Write results directly to the result accumulator cell.
   - **Single-clause path** (no branching): If only one clause matches, install it directly in the current network. No `amb`, no PU overhead. This IS Tier 1 behavior — deterministic queries never touch ATMS.
   - **Multi-clause path** (branching): Two-step process following the array-programming pattern:

     **Step 1 — Bulk clause matching (broadcast propagator, M1):**
     The goal-app propagator installs ONE **broadcast propagator** (Phase 1 infrastructure) over the clause list. The broadcast propagator reads the arg cells ONCE, processes ALL N clauses internally (each does α-rename + attempt unification), and writes ONE merged result to the match-result cell. Clauses that fail unification are eliminated HERE, before any PU allocation.

     The broadcast-profile metadata enables the scheduler to decompose the N items across parallel threads when N exceeds the threshold. Today: sequential internal loop. With parallel thread executor: K chunks on K cores. The propagator network sees ONE fire, ONE diff, ONE merge regardless.

     **A/B data**: At N=10 clauses, broadcast is 5.9× faster than N-propagator model. At N=50, 34.7×. Infrastructure overhead is constant (~2.7μs), not linear in N.

     **(3.2) Precondition: arg cells must be stable** (resolved, non-bot) before the broadcast fires. Match results accumulate via set-union (monotone), which means results only grow. If arg cells were refined after matching, previously-matching clauses might no longer match, but they'd remain in the accumulator (stale). In our solver, args ARE resolved once (query arguments are elaborated before the solver runs, solver variables only gain information). The readiness guard (fire only when all args are non-bot) ensures this precondition.

     **Step 2 — Branch creation (only for survivors):**
     For the M matching clauses, call `atms-amb-on-network` (now: create M decision cell entries + M branch PUs). Each PU gets:
     - Access to the group-level decision cell **with component-path `(decision-G . h_i)`** — the PU fires only when ITS alternative's status changes, not when sibling alternatives are narrowed. This is the §3.1a invariant applied to the BranchPU interface.
     - Fresh variable cells for this clause's bindings (from Step 1) — PU-local, not compound cross-PU reads
     - Sub-goal propagators installed for the clause body via broadcast conjunction (Phase 7). These read PU-local variable cells (not compound outer cells). Outer arg cells are resolved (ground values, 3.2 precondition) — no compound structure to component-index.
     - Per-nogood commitment infrastructure (Phase 3) for any nogoods involving this branch's group — commitment cells use component-indexed writes (§3.1a compliant)

     This is the N-to-M pattern from the [array-programming research](../research/2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md) §5: N candidates → M survivors, with PU allocation only for survivors. For deterministic cases (M=1), no PU is created — Tier 1 behavior.

2. **`relations.rkt`**: New function `atms-amb-on-network`:
   - Creates M PUs via Phase 2's `make-branch-pu` (only for matching clauses)
   - **(Hasse diagram: Gray code ordering)** The M branch PUs are ordered by Gray code — each successive branch differs from the previous by one assumption. `make-branch-pu` forks from the PREVIOUS branch's network (not the parent's), maximizing CHAMP structural sharing. For M = 2: trivial (0→1). For M = 3+: standard reflected Gray code on the assumption-id bit positions. The bitmask field (Phase 1 item 6) enables O(1) Hamming distance computation for ordering.
   - Records pairwise mutual-exclusion nogoods among the M branches
   - Installs per-nogood infrastructure (Phase 3) for each pairwise nogood
   - Returns the list of `(branch-pu . assumption-id)` pairs in Gray code order

3. **`relations.rkt`**: New function `clause-match-bulk`:
   - Takes resolved args + clause list
   - For each clause: α-rename all variables, attempt arg↔param unification
   - Returns `(listof (clause-info . fresh-bindings))` — only successful matches
   - This is a pure function (no network mutation) — suitable for parallel execution within a BSP superstep
   - The broadcast-profile metadata enables the scheduler to decompose into parallel chunks across OS threads (Racket 9 `thread #:pool 'own`)

4. **Variable representation**: Logic variables become cells in the branch PU's network (not symbols in a hasheq). `?x = suc ?y` becomes: write `(suc cell-y)` to `cell-x`. This is the cell-tree model from PUnify Part 2 — variables ARE cells, unification IS cell writes.

**Key architectural point**: The DFS `solve-goals` function threading substitutions through recursive `append-map` is GONE. The replacement is two-level: bulk matching (parallel, no allocation) then PU branching (only for survivors). This minimizes both propagator count and PU count.

**P3 clarification**: TMS provides CORRECTNESS isolation (branch-tagged values are invisible across branches via the TMS tree). PU provides EFFICIENCY isolation (structural GC on contradiction — drop PU = O(1), no CHAMP cleanup). Both are needed, for different reasons.

**R4 note**: The solver entry point is `reduction.rkt` (4 call sites at lines 528, 546, 599, 633 calling `stratified-solve-goal`), which dispatches to `relations.rkt`. Phase 9 (two-tier) needs to modify the dispatch in `reduction.rkt`, not just `relations.rkt`.

**Test coverage**: Single-clause dispatch (no PU), multi-clause dispatch (PU-per-clause), fact matching, clause body recursion, variable freshening as cell creation.

### Phase 7: Goal-as-Propagator Dispatch

**What this replaces**: `solve-single-goal` (relations.rkt:612-703) — the dispatch on goal kind.

**What changes**:

1. **`relations.rkt`**: New function `install-goal-propagator`:
   - Dispatches on goal kind, installs appropriate propagator:

   | Goal Kind | Propagator | Inputs | Outputs | Stratum | Notes |
   |---|---|---|---|---|---|
   | `app` | Phase 6's `install-clause-propagators` | arg cells | result cell | S0 | May create PUs via topology request |
   | `unify` | Unification propagator | lhs cell, rhs cell | (constraint) | S0 | Cell-tree unify: write to cells |
   | `is` | Evaluation propagator | expr cell | var cell | S0 | Evaluate functional expr, write to var |
   | `not` | NAF propagator | inner goal result | negated result | **S1** | Fires after S0 quiesces (M6: BSP barrier IS the completion signal) |
   | `guard` | Guard propagator | condition cell | gate | **S1** | Gates subsequent goals on condition |

   **P2**: `cut` is NOT implemented and is OUT OF SCOPE. Not listed.
   
   **M6 (NAF completion)**: The NAF propagator fires at S1, AFTER the S0→S1 BSP barrier confirms quiescence. The inner goal's result cell value at S1 fire time is its final S0 value. If ⊥ → inner goal genuinely failed → NAF succeeds. If non-⊥ → inner goal succeeded → NAF fails. The barrier IS the completion signal — no separate completion detection needed.

   **(6.3) NAF inner-result cell scope**: The NAF propagator's inner-result cell MUST be on the NAF's own network scope (outer), NOT inside any sub-PU. Inner goal propagators write to this cell via cross-PU bridges (same pattern as the answer accumulator). If inner goals branch into sub-PUs, some may be dropped (contradicted). The inner-result cell on the outer network survives PU drops. Its value at S1 reflects whether any inner derivation survived — ⊥ = all sub-PUs dropped = inner goal genuinely failed.

2. **Conjunction as broadcast (order-independent, §6b deployment)**:
   `solve-goals` (the recursive append-map) is replaced by `install-conjunction`:
   - Takes a list of K goals and a parent network/PU
   - `install-conjunction` IS a **broadcast propagator deployment** over the goals list: ONE broadcast propagator reads the shared variable cells and installs all K goal propagators in a single fire. The installation of each goal is independent (polynomial functor: fan-out = K goals).
   - Goal ordering within the clause body does NOT affect execution. `(A, B, C)` and `(C, A, B)` produce the same network topology and the same results
   - Execution order emerges from DATAFLOW: if goal A writes to cell `?x` and goal B reads `?x`, B fires after A — but this is a cell dependency discovered by the propagator network, not an ordering imposed by installation
   - Independent goals (no shared variables) fire concurrently in the same BSP superstep
   - This IS the true-parallel order-independent search: the clause-body ordering is irrelevant; the dataflow graph determines the execution schedule
   - **M2**: The goals list is an ENUMERATION (which goals to install), not an ORDERING (what sequence to execute).
   - **NAF inner goals**: When NAF's inner goal branches into sub-PUs, the sub-PU conjunction is a nested broadcast deployment — the same pattern applied recursively.

3. **Answer accumulator cell (M5)**: Each query has an answer accumulator cell with set-union merge. Branch-committer propagators (Phase 2) write results to the accumulator. After quiescence + S(-1) pruning + commit, the accumulator holds all answers. No scanning, no "collect results from surviving branches" — answers arrive via cell writes.

3. **NAF as stratum**: Negation-as-failure is inherently non-monotone (succeed if inner FAILS). This is S1 — fires after S0 quiesces. The inner goal is installed as S0 propagators. The NAF propagator is an S1 readiness-triggered propagator that checks: did the inner goal's result cell reach a value (inner succeeded → NAF fails) or stay at ⊥ (inner failed → NAF succeeds)?

   Integration with WF engine: if `(current-naf-oracle)` is set, the NAF propagator consults the bilattice oracle first. The 3-valued result (succeed/fail/defer) determines behavior without needing to evaluate the inner goal.

**Key architectural point**: Every goal type becomes a propagator installation. The goal dispatcher is a match on goal kind → propagator constructor call. This is data-oriented: adding a new goal type = adding one match case, not modifying a recursive evaluation function.

**Test coverage**: Each goal type in isolation, conjunction chaining, NAF (inner succeeds → fail, inner fails → succeed), guard (true → proceed, false → block).

### Phase 8: On-Network Tabling (D.12)

**Updated design**: dissolves `table-store` into cells on the solver's network. No separate table network. Table registration, answer accumulation, and completion are all on-network. One-true-tabling: every `defr` relation is tabled by default. Self-hosting path: table registry as a cell, pioneering the pattern for all registries (module, relation, trait).

#### 8.1 SRE Lattice Lens on Table Answers

| Question | Analysis |
|---|---|
| Q1 Classification | VALUE lattice: P(Bindings) under ⊆ |
| Q2 Properties | Join-semilattice (⊥=∅, join=set-union). Monotone. CALM-safe: coordination-free. |
| Q3 Bridges | Table cell → consumer propagator → query variable cells. Bridge is relational projection (Galois connection: preserves joins). |
| Q4 Composition | clause-execution → table-cell → consumer-propagator → query-vars. All monotone. |
| Q5 Primary/Derived | Table cell is PRIMARY (canonical answer set). Consumer results are DERIVED (projections). |
| Q6 Hasse | P(Bindings) = Boolean lattice on possible answer tuples. Each new answer moves one step up. Well-founded (no infinite descending chains) → guarantees fixpoint. |

#### 8.2 On-Network Architecture

**Table registry**: a CELL on the solver's network. Value: hasheq mapping relation-name → table-cell-id. Merge: hash-union (keys only added — monotone). Self-hosting path: all compiler registries (module, relation, trait) follow this pattern.

**Table registration**: topology request. When `install-clause-propagators` encounters a tabled relation not yet in the registry, emits a topology request: "allocate a table cell, register it." Topology stratum handles cell allocation + registry write. Same protocol as PAR Track 1.

**Table cell**: one cell per tabled relation on the solver's network. Initial value: `'()`. Merge: `all-mode-merge` (set-union with dedup). Answers accumulate monotonically.

**Completion**: EMERGENT from BSP fixpoint. A table cell that stops changing IS complete. No explicit `table-freeze`, no status field, no per-table completion tracking. Per the CALM theorem, monotone set-union is coordination-free. BSP guarantees: if a cell doesn't change in a superstep, its dependents aren't re-enqueued.

**`table-store` wrapper**: ELIMINATED. Table cells live on the solver's network. `tabling.rkt` becomes a library of merge functions and the consumer propagator pattern — not a network wrapper.

#### 8.3 Producer/Consumer Pattern

**Producer**: `install-clause-propagators` with one addition — each clause's result also writes to the table cell. Same concurrent execution model as Phase 6+7: all clauses on one network, per-propagator worldview bitmask, BSP fires all concurrently. The table cell's set-union merge accumulates answers from all clauses.

**Consumer**: ONE propagator per consumer call site. Reads the table cell, reads ground arg cells, computes relational projection (filter by ground args, project free args), writes to query variable cells. Fires whenever table cell grows or ground args change. NOT fire-once — must re-fire as new answers arrive.

**Call-site dispatch** in `install-clause-propagators`:
1. Read table registry cell for relation-name
2. If present (table cell exists): install **consumer propagator** (reads table cell → projects to query vars). No clause installation.
3. If absent: check if relation should be tabled (default: yes). If yes: emit topology request to register table cell, install clauses as **producer** (normal execution + write to table cell). If no: install normally.

#### 8.4 One True Tabling

Every `defr` relation is tabled by default. The cost per table: one cell + one propagator per consumer call site. Both O(1) CHAMP operations — negligible.

Config: `:tabling :off` for debugging/benchmarking only. No `:all` vs `:first` per-relation mode. Deterministic relations naturally converge to singleton answer sets under set-union merge. The merge function handles it structurally — no special case.

**Dropped**: `first-mode-merge`, per-relation `answer-mode`, `table-freeze`, `table-complete?` status flag. All replaced by emergent fixpoint.

#### 8.5 What Changes

| Current (`tabling.rkt`) | On-Network |
|---|---|
| `table-store` wraps separate network | Table cells on solver's network |
| `table-register` allocates on table-store's network | Topology request → solver network cell |
| `table-add` writes to table-store's cell | Producer propagator writes to solver cell |
| `table-answers` reads table-store's cell | Consumer propagator reads solver cell |
| `table-freeze` explicit status change | ELIMINATED — BSP fixpoint = complete |
| `table-complete?` status flag | ELIMINATED — cell didn't change = complete |
| `table-run` runs table-store's network | `run-to-quiescence` handles everything |
| `table-store-empty` creates separate network | ELIMINATED — no separate network |

#### 8.6 Critique Resolution

**6.4 (External)**: "conflates network and table quiescence." Resolved by emergent per-cell fixpoint. A table cell that stops changing IS complete, regardless of other cells. BSP superstep semantics guarantee this.

#### 8.7 Self-Hosting Path

Table registry as a cell pioneers the pattern for self-hosting. Every Racket `make-parameter` holding a hasheq of "things the system knows about" → a cell on the network. The current-relation-store, current-module-registry, trait dispatch tables — all become cells with merge-based accumulation. Information about the language's structure flows through the network, not through Racket-level ambient state. The Hyperlattice Conjecture operationalized: even compiler metadata is lattice-valued, flowing through cells.

#### 8.8 Test Coverage

- Table registration via topology request
- Producer writes + consumer reads (same network)
- Multiple consumers for same tabled relation
- Cross-table dependencies (non-recursive)
- Completion emerges from fixpoint (no explicit freeze)
- Tabled + non-tabled predicates coexist
- Answer projection correctness (ground args filter, free args project)

**What's NOT in scope**: Left-recursive tabling (predicate A calls A). Requires SLG completion frames — deferred to BSP-LE Track 3.

### Phase 9: Two-Tier Activation

**What changes**:

1. **`relations.rkt`**: The entry point `solve-goal` (or its replacement) checks `:strategy`:
   - `:depth-first` → use the DFS path (existing `solve-goals`, preserved for backward compatibility)
   - `:atms` → create worldview cell + ATMS from the start, use propagator path
   - `:auto` (default) → start in Tier 1 (plain prop-network), upgrade on first multi-clause match

2. **Tier 1 → Tier 2 transition** (M4: via topology stratum, NOT scaffolding):
   - Tier 1: No decision cells, no nogood cell. Single-clause matches install directly. Facts unify directly. The solver uses a plain prop-network.
   - First multi-clause match detected → goal-app propagator emits a **topology request**: "create decision infrastructure (nogood cell, assumptions cell, counter cell) on this network"
   - The topology stratum EXECUTES the request — same protocol as PAR Track 1's dynamic topology for CALM-safe structural mutation
   - CHAMP structural sharing: transition cost is O(cells added), not O(network size). Network-without-decisions → topology adds infrastructure cells → network-with-decisions.
   - Proceed with `atms-amb-on-network` for this and all subsequent multi-clause matches

3. **Existing cells continue to work**: Cells created during Tier 1 are plain values. When the decision infrastructure appears (Tier 2), `net-cell-read`/`net-cell-write` detect whether a decision context is active. If not (Tier 1), they use `current-speculation-stack` as before. If yes (Tier 2), they derive the TMS stack from decision cells. Tier 1 values are depth-0 (base) values — TMS reads with `'()` stack return them directly. No wrapping needed.

**P1 confirmation**: Two-tier IS the correct and complete design. `:auto` is the right default. Deterministic code should not pay overhead for infrastructure it doesn't use. The Tier 1→2 transition is a topology stratum operation — architecturally clean, not a code-path branch.

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

   **(Hasse diagram: hypercube all-reduce for BSP barriers)** When T ≥ 4 threads, the BSP barrier's merge phase should use hypercube all-reduce instead of flat sequential merge. In round k (for k = 0, ..., log_2(T)-1), thread i communicates with thread `i XOR 2^k` — partners exchange local cell writes and merge. After log_2(T) rounds, every thread has the complete merged state. For T = 8 (M-series Mac): 3 rounds of pairwise merge instead of 7 sequential merges. The existing `make-parallel-thread-fire-all` executor partitions work across threads — the barrier merge phase adopts the hypercube pattern.
   
   **(Hasse diagram: nogood broadcast)** When a nogood is discovered in one worldview and must be propagated to W active worldviews, the hypercube broadcast pattern reaches all in log_2(W) rounds via binomial tree. The nogood topology watcher's broadcast of `nogood-install-request` descriptors follows hypercube dimension ordering: process dimension 0 (lowest bit) first, then dimension 1, etc.

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

4. **R7: Deep nesting and wide-clause hotspots**:
   Pre-0 data shows `level4` (5 levels binary branching, 32 leaves) at 314ms — 2× the next command. `color-code` (10-clause query-all) at 187ms. These are the patterns where propagator-native search has the most opportunity (concurrent exploration) and the most risk (PU allocation overhead × branch count). Benchmark these specifically.

5. **Edge cases**:
   - Empty relation (no facts, no clauses) → fail
   - Single-fact relation → succeed, no ATMS (Tier 1)
   - Deeply nested recursion → tabling prevents divergence (non-recursive cases)
   - Contradictory goals → empty result set via answer accumulator (M5)
   - NAF with WF oracle → 3-valued behavior preserved

6. **CHECKPOINT: Inert-dependent instrumentation review** (from Phase 2 §2.4):
   Review the `perf-inc-inert-dependent-skip!` counter data from the parity benchmarks.
   - How many inert entries per cell on hot paths?
   - Is any cell accumulating >50 inert entries?
   - What is the per-change overhead from inert checks on the adversarial benchmarks?

   If the data warrants it, design and implement **S(-1) dependents cleanup as lattice narrowing**:
   - Dependents set IS a lattice (set under ⊇)
   - Cleanup = `current-dependents ∩ viable-dependents` (lattice narrowing)
   - Per-cell "dependents-cleaner" propagator at S(-1): reads dependents + decision cells, writes narrowed set
   - Multiple cells fire cleaners in parallel (broadcast over affected cells)
   - This is emergent, parallel, on-network retraction — NOT step-think iteration

   **This is an important propagator design pattern**: retraction expressed as lattice narrowing on metadata (dependents), not as imperative removal. The pattern generalizes: any network metadata that accumulates (dependents, provenance tags, trace entries) can be retracted via lattice narrowing at S(-1). Capture in `PATTERNS_AND_CONVENTIONS.org` after validation.

**Test coverage**: Parity tests, benchmark comparison, acceptance file, edge cases, inert-dependent data review.

---

## §6b Broadcast Propagator Deployment Audit

Every place in the Track 2 design where data-indexed parallel processing occurs MUST use the broadcast propagator pattern, not N separate propagators. Audit of all deployment sites:

| Phase | Component | Items | Item Function | Merge | Component-Paths? | Notes |
|---|---|---|---|---|---|---|
| **3** | Per-nogood commitment tracking | Groups in a nogood (2-3) | Check if compound decisions cell component committed to nogood member | Component-indexed hash merge | **Yes** — `((decisions-cid . group-A) ...)` per nogood members | Broadcast over groups, writes to compound commitment cell component. Requires 5.1b extension. |
| **5** | `atms-amb` pairwise nogood creation | N(N-1)/2 pairs from N alternatives | Create one nogood hasheq per pair | Nogood cell set-union | No — nogoods cell is scalar | Broadcast over pairs, one write to nogood cell |
| **6** | Clause matching | N clauses | α-rename + try-unify per clause | Set-union of matching results | No — match-result is scalar | PRIMARY consumer. Broadcast over clause list. |
| **7** | Goal conjunction installation | K goals in clause body | Install goal propagator per goal | N/A (topology, not value) | No | Each goal installs independently. Broadcast over goals for TOPOLOGY REQUESTS. |
| **8** | Producer clause body | Clause body goals | Same as Phase 7 (conjunction) | Same | No | Tabled relation body = conjunction |

**D.10 addition**: Phase 5.1b extends `net-add-broadcast-propagator` to accept `#:component-paths`, `#:assumption`, `#:decision-cell` — same interface as `net-add-propagator`. The Phase 3 commit-tracker is the first consumer that requires component-indexed broadcast on a compound cell.

**Pattern reuse beyond Track 2** (future tracks):
- SRE Track 5 (pattern compilation): broadcast over constructor alternatives
- SRE Track 3 (trait resolution): broadcast over candidate impls
- SRE Track 7 (module loading): broadcast over export/import pairs
- PPN Track 6/7 (grammar rules): broadcast over grammar productions

The broadcast propagator is the **polynomial functor made operational**. Building it here establishes the reusable pattern for all data-indexed parallel processing across the entire project.

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
2. `current-speculation-stack` parameter eliminated (all 6 consumers migrated to decision cells)
3. **`atms` struct REMOVED** (all fields dissolved into cells, §2.6). `atms.rkt` is a query function library.
4. Solve-adversarial + atms-adversarial benchmarks do not regress >15% from baseline
5. Non-recursive tabled predicates terminate and memoize
6. `:strategy :auto` activates two-tier (Tier 1 → Tier 2 via topology stratum on first `amb`)
7. `:strategy :depth-first` preserves exact DFS semantics
8. Acceptance file passes at Level 3
9. Concurrent branch exploration functional (multiple PUs in same BSP superstep)
10. **No worldview cell** — worldview emerges from decision cells, consistency via AND-fan-in
11. Answer accumulator cell collects results from committed branches (no scanning)
12. Broadcast propagator pattern functional with scheduler decomposition for parallel execution. A/B data: 2.3-75.6× faster than N-propagator model. Deployed in Phases 3, 5, 6, 7, 8 (see §6b audit).
