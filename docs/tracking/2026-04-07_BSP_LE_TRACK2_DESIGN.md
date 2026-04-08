# BSP-LE Track 2: ATMS Solver + Cell-Based TMS — Stage 3 Design

**Date**: 2026-04-07
**Series**: BSP-LE (Logic Engine on Propagators)
**Scope**: Cell-Based TMS (folding Track 1.5) + ATMS Solver + Non-Recursive Tabling
**Status**: D.3 — post external critique (16 findings incorporated)
**Self-critique**: [P/R/M Analysis](2026-04-07_BSP_LE_TRACK2_SELF_CRITIQUE.md) (17 findings, D.2)
**External critique**: [Architect Review](2026-04-08_BSP_LE_TRACK2_EXTERNAL_CRITIQUE.md) (16 findings, D.3)
**Stage 1/2**: [Research + Audit](../research/2026-04-07_BSP_LE_TRACK2_STAGE1_AUDIT.md)
**Prior art**: [Logic Engine Design](2026-02-24_LOGIC_ENGINE_DESIGN.org) §4-7, [PUnify Part 3](2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md), [Cell-Based TMS Note](../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md)

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Pre-0: benchmarks + acceptance file | ✅ | Baselines captured (0a-0c). Acceptance file (0d) at implementation start. |
| 1 | Decision cell infrastructure + broadcast propagator | ✅ → 🔄 | 1A: `4df2a4d8` decision-cell.rkt (pure leaf), 30 tests. 1Bi: A/B data (broadcast 2.3-75.6× faster). 1Bii: revise to broadcast model. |
| 2 | PU-per-branch lifecycle | ⬜ | Create from parent, commit via topology request, drop via topology request |
| 3 | Per-nogood propagators (RKan) | ⬜ | (4.1) Per-NOGOOD propagator, fan-in=|ng|. Contradiction → topology drop request. |
| 4 | Speculation migration | ⬜ | 6 files (R1): propagator.rkt, elab-speculation-bridge, typing-propagators, metavar-store, cell-ops, test-tms-cell |
| 5 | ATMS struct dissolution | ⬜ | All 7 fields → cells. Struct REMOVED. atms.rkt becomes query function library. (P4) |
| 6 | Clause-as-assumption in PUs | ⬜ | Parallel-map clause matching (M1) + PU per surviving clause |
| 7 | Goal-as-propagator dispatch | ⬜ | 5 goal types (no cut — P2). NAF at S1 via BSP barrier (M6). Answer accumulator (M5). |
| 8 | Producer/consumer tabling | ⬜ | Table registry check in goal dispatcher. Non-recursive completion. |
| 9 | Two-tier activation + parameter removal | ⬜ | 9a: Tier 1→2 via topology stratum (M4). 9b: REMOVE `current-speculation-stack` (6.1). |
| 10 | Solver config wiring | ⬜ | `:strategy`, `:execution`, `:tabling` operational |
| 11 | Parity validation | ⬜ | DFS ↔ propagator-native result equivalence. Deep nesting hotspot (R7). |
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

| Lattice | Carrier | Order | Merge | Kind | Properties |
|---|---|---|---|---|---|
| Worldview | P(AssumptionId) | ⊆ | set-union | Value (DERIVED) | Boolean, distributive, Heyting, frame |
| Nogood | P(P(AssumptionId)) | ⊆ | set-union | Value | Boolean, distributive |
| Decision (per amb) | P(Alternatives) | ⊇ (reverse) | set-intersection | **Structural** | Boolean (dual powerset), constraint narrowing |
| Term Value | existing structural | — | SRE merge | Structural | Per Track 2H (Heyting ground sublattice) |
| Answer Accumulator | P(Answer) | ⊆ | set-union | Value | Boolean, distributive |
| Assumptions | P(Assumption) | ⊆ | set-union | Value | Boolean, distributive |
| Counter | Nat | ≤ | max | Value | Chain |

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
| `tms-cells` | RETIRED (Phase 5) | — | — | Cell storage moves to prop-network |
| `next-assumption` | Counter cell | Nat, ≤ | max | Monotone. (2.3) Written ONLY at topology stratum (sequential) — prevents concurrent ID collision. |
| `believed` | **ELIMINATED** | — | — | Worldview emerges from decision cells — no separate representation |
| `amb-groups` | Decision cells (one per amb, §2.5a) | P(Alternatives), ⊇ | set-intersection | Structural lattice, SRE-registered |

### §2.6b No Worldview Cell — Worldview Emerges from Decisions

The worldview is NOT a cell. It is the COLLECTION of decision cells. Any propagator needing assumption information reads the relevant decision cell(s) directly.

- A propagator in branch B reads decision-cell-B for its assumption
- Consistency checking decomposes per-decision: "is decision G still viable?" = "is decision-cell-G non-empty?" — a per-cell check, not a global scan
- Global consistency = conjunction (AND-fan-in) of per-decision viability cells
- Global consistency EMERGES from the fan-in. No aggregation step. No derived cell.

If a cross-system bridge needs the full assumption set (e.g., worldview→type filtering), it reads the relevant decision cells via fan-in. This is more decomplected than a single worldview aggregate — each propagator reads only the decisions it cares about.

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
| `atms-consistent?` | Fan-in: AND of per-decision non-empty checks | ✓ Propagator (fan-in) |
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
  (when [empty? [read decision-G]]
    [write topology-requests [set [drop-pu G]]])         ;; M3: emit REQUEST, not direct drop

propagator branch-committer {G : AmbGroup}
  :reads  [decision-G : Cell (DecisionDomain G),
           result-G : Cell Answer]
  :writes [answer-accumulator : Cell (Set Answer),
           topology-requests : Cell (Set TopologyRequest)]
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

propagator per-nogood-watcher {ng : Nogood}                ;; (4.1) one per nogood
  :reads  [decision-G : Cell (DecisionDomain G)            ;; for each group G in ng
           for G in [groups-of ng]]
  :writes [decision-remaining : Cell (DecisionDomain G')]  ;; the last un-narrowed group
  ;; Fires when ANY of its input decision cells changes.
  ;; Reads all |ng| decision cells (typically 2-3).
  ;; If all except one are committed singletons containing their nogood member:
  ;; narrows the remaining group to exclude its member.
  ;; No filter/map/length — reads 2-3 cells, checks directly.
  (let [statuses [for/list [G [groups-of ng]]
                   [cons G [read [decision G]]]]]
    (let [committed [filter [fn [pair] [and [singleton? [cdr pair]]
                                            [= [the-element [cdr pair]]
                                               [member-of ng [car pair]]]]]
                            statuses]]
      (when [= [length committed] [- [length statuses] 1]]
        (let [remaining [the-uncommitted statuses committed]]
          [narrow [decision [car remaining]]
                  [exclude [member-of ng [car remaining]]]]))))

;; Per-nogood commitment tracking via broadcast propagator:
;; For nogoods of size 3+, decompose into broadcast over groups.
;; Each group's commitment status tracked via component-indexed cell.
propagator broadcast-commit-tracker {ng : Nogood}
  :reads  [decision-G : Cell (DecisionDomain G) for G in [groups-of ng]]
  :writes [commitment-{ng} : Cell (Hasheq Group Bool)]
  :broadcast-profile
    :items    [groups-of ng]
    :item-fn  (λ [G decisions] [cons G [singleton? [hash-ref decisions G]]])
    :merge-fn hash-merge
  :component-paths [(commitment-{ng} . G) for G in [groups-of ng]]
  ;; ONE fire, reads all group decisions, writes component-indexed commitment status

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
interface BranchPU
  :inputs  [decision-G : Cell (DecisionDomain G),   ;; which alternative this branch represents
            nogoods : Cell NogoodSet,                ;; shared across all branches
            parent-facts : Cell (Set Fact) ...]      ;; inherited from parent
  :outputs [result : Cell Answer,                    ;; branch result
            new-nogoods : Cell NogoodSet]             ;; nogoods discovered in this branch
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
| **L2** | `propagator broadcast-commit-tracker` | Broadcast over groups in nogood, component-indexed | propagator.rkt |
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

5. **NO worldview cell** (§2.6b): The worldview emerges from decision cells. No `worldview-cid` on the network. `net-cell-read`/`net-cell-write` use decision cells for TMS navigation in Tier 2 (Phase 9 activates this). Tier 1 uses `current-speculation-stack` as before.

**R3 revision**: No field added to `prop-net-cold` or `prop-net-warm`. Decision cell IDs are tracked by the solver infrastructure (per-query), not by the network struct.

**Test coverage**: Decision cell creation + narrowing. Nogood cell creation + accumulation. Parallel-map propagator with 3/5/10 inputs. SRE domain registration for decision domain.

**Network Reality Check**:
1. `net-new-cell` calls: decision cells, nogood cell, assumptions cell, counter cell
2. `net-cell-write` produces result: decision narrowing via cell write
3. Cell creation → propagator installation → cell write → cell read = narrowed domain: yes

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

### Phase 3: Per-Nogood Propagators (Right Kan Extension)

**What changes** (4.1: per-NOGOOD propagators, not per-decision watchers):

1. **`propagator.rkt`**: `install-nogood-propagator`:
   - `(install-nogood-propagator net nogood-set decision-cids)`
   - Creates ONE propagator per NOGOOD (not per decision cell)
   - Inputs: the decision cells of ALL groups mentioned in this nogood (fan-in = |nogood|, typically 2-3)
   - Fire function: when all groups in the nogood except one are committed (their decision cell is a singleton containing the nogood's assumption), NARROW the remaining group's decision cell to exclude its member of the nogood
   - This IS the right Kan extension: each nogood is its own information-flow unit. The propagator fires only when its specific nogood becomes relevant.

2. **When nogoods are discovered**: A contradiction in a branch writes a new nogood to the shared nogood cell. A watching propagator reads the nogood cell and installs a new per-nogood propagator for the new nogood. This is topology creation at the topology stratum — same protocol as PAR Track 1.

3. **Contradiction detection**: When a group-level decision cell narrows to ∅ (empty), it's contradicted. A per-decision contradiction propagator watches the decision cell and emits a topology request to drop ALL branch PUs that committed to alternatives in that group (M3: via topology request, not direct drop).

**Cost analysis** (Pre-0 data, §0b):
- Intersection check: 62ns per (10-element set ∩ 2-element nogood)
- Per nogood discovery: O(decisions) intersection checks, each O(|nogood|)
- Per affected decision: cell narrows, dependent propagators react
- Per unaffected decision: nothing happens
- Total: O(decisions × |nogood|) for filtering + O(affected_propagators) for reaction

**This IS the right Kan extension**: of all information in the nogood cell, forward to decision G only nogoods involving G's alternatives.

**Test coverage**: Watcher narrows decision on relevant nogood, ignores irrelevant nogoods, contradiction detection (domain → ∅), multiple decisions with independent watchers.

### Phase 4: Speculation Migration

**What changes** (6 files per R1 audit, backward-compatible):

1. **`propagator.rkt`** (lines 577, 751): The two integration points where `net-cell-read`/`net-cell-write` read `(current-speculation-stack)`. Add optional decision-cell-based TMS navigation: when a decision cell context is active, derive the speculation stack from decision cells instead of the parameter.

2. **`elab-speculation-bridge.rkt`** (line 227, 1 parameterize site): Replace `(parameterize ([current-speculation-stack (cons hyp-id ...)]) ...)` with decision cell write + fire function that reads decision context from cells.

3. **`typing-propagators.rkt`** (6 parameterize sites, lines 258-1589): The Phase 8 union branching code uses `parameterize` around fire functions. Replace with decision cell input to the fire function.

4. **`metavar-store.rkt`** (line 1321, 1 read site): Replace `(define stack (current-speculation-stack))` with decision cell read when available, parameter fallback when not.

5. **`cell-ops.rkt`** (lines 82-83, 2 read sites): Replace `(current-speculation-stack)` check with decision cell read. The `worldview-visible?` function reads from decision cells instead of parameter.

6. **`tests/test-tms-cell.rkt`** (R1: missed in D.1): Test infrastructure that parameterizes `current-speculation-stack`. Update to support decision-cell-based testing.

**R1 correction**: `narrowing.rkt` does NOT directly use `current-speculation-stack`. It uses `atms-amb` via `elab-speculation.rkt` but doesn't read the parameter. Removed from migration scope.

**Migration strategy**: Each file gets an optional decision-cell context. When present, derive TMS stack from decision cells. When absent, fall back to `(current-speculation-stack)`. Incremental migration — files migrate one at a time, suite stays green throughout.

**`current-speculation-stack` dual-path window** (6.1: compressed per "Validated Is Not Deployed"):
Phase 4 migrates all 6 consumers to support both paths (decision cells when available, parameter fallback when not). Phase 9 establishes decision cells as the primary mechanism via topology stratum. **Phase 9 sub-phase 9b: REMOVE the parameter.** Tier 1 with empty decision context = equivalent to `'()` stack. The dual-path window is Phases 4–9a (not 4–"someday"). The parameter is gone by the end of Phase 9.

**Test coverage**: Each migrated file passes existing tests (behavioral parity). New tests verify decision-cell-based TMS produces same results as parameter-based TMS.

### Phase 5: ATMS Struct Dissolution

**What changes** (per §2.6):

The `atms` struct (7 fields) is dissolved entirely into cells on the propagator network. No off-network state remains.

1. **`atms.rkt`**: The `atms` struct is REMOVED. In its place:
   - **Solver context**: a lightweight record holding cell-ids for the solver's cells (assumptions-cid, nogoods-cid, counter-cid, answer-accumulator-cid, plus a list of decision-cids). This is metadata about WHERE the cells are, not the cells' VALUES.
   - `atms-assume` → write to assumptions-cell + counter-cell. Create trivial decision cell `{h}`.
   - `atms-add-nogood` → write to nogood cell (set-union). Monotone.
   - `atms-amb` → create N assumption writes + decision cell + pairwise nogood writes. Topology request for PU creation.
   - `atms-retract` → narrow decision cell to exclude assumption (SRE structural narrowing, §2.6c). The word "retract" is ALIASED to decision-cell narrowing.
   - `atms-consistent?` → propagator: AND-fan-in of per-decision non-empty checks.
   - `atms-read-cell` / `atms-write-cell` → RETIRED. Use `net-cell-read` / `net-cell-write`.

2. **`atms.rkt`**: Retained as query function library (§2.6f):
   - `explain-hypothesis`: reads nogood cell + assumptions cell → filter → explanation
   - `explain-all`: reads nogoods + decision cells → violated nogoods
   - `minimal-diagnoses`: formulated as tropical semiring CSP (§2.6e) — future phase or deferred
   - `conflict-graph`: reads nogoods → builds graph
   - These are read-only consumers of cell values. Correctly off-network.

3. **R2 note**: The `amb-groups` field becomes the list of decision-cell-ids in the solver context. `atms-solve-all` is REPLACED by the answer accumulator (M5) — branching topology covers the product space, committed results accumulate via set-union merge.

4. **R5 note**: Only 3 sites actually call `atms-amb` as an operation (atms.rkt internal, elab-speculation.rkt, reduction.rkt). The 26 `atms-amb` references in the pipeline (parser, pretty-print, substitution, zonk) handle the `expr-atms-amb` AST node — UNCHANGED by this phase.

**Key architectural point**: There is no "ATMS struct managing worldviews" alongside cells. The cells ARE the state. The solver context is a phone book (which cell-ids to read), not a second source of truth (P4 resolution).

**Test coverage**: All existing ATMS tests rewritten to use cell operations. `atms-assume` → cell write parity. `atms-amb` → decision cell creation parity. `atms-add-nogood` → nogood cell write parity. Existing solver tests pass (behavioral parity via relations.rkt).

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
   - **Multi-clause path** (branching): Two-step process following the array-programming pattern:

     **Step 1 — Bulk clause matching (broadcast propagator, M1):**
     The goal-app propagator installs ONE **broadcast propagator** (Phase 1 infrastructure) over the clause list. The broadcast propagator reads the arg cells ONCE, processes ALL N clauses internally (each does α-rename + attempt unification), and writes ONE merged result to the match-result cell. Clauses that fail unification are eliminated HERE, before any PU allocation.

     The broadcast-profile metadata enables the scheduler to decompose the N items across parallel threads when N exceeds the threshold. Today: sequential internal loop. With parallel thread executor: K chunks on K cores. The propagator network sees ONE fire, ONE diff, ONE merge regardless.

     **A/B data**: At N=10 clauses, broadcast is 5.9× faster than N-propagator model. At N=50, 34.7×. Infrastructure overhead is constant (~2.7μs), not linear in N.

     **(3.2) Precondition: arg cells must be stable** (resolved, non-bot) before the broadcast fires. Match results accumulate via set-union (monotone), which means results only grow. If arg cells were refined after matching, previously-matching clauses might no longer match, but they'd remain in the accumulator (stale). In our solver, args ARE resolved once (query arguments are elaborated before the solver runs, solver variables only gain information). The readiness guard (fire only when all args are non-bot) ensures this precondition.

     **Step 2 — Branch creation (only for survivors):**
     For the M matching clauses, call `atms-amb-on-network` (now: create M decision cell entries + M branch PUs). Each PU gets:
     - A worldview cell extending parent with this clause's assumption
     - Fresh variable cells for this clause's bindings (from Step 1)
     - Sub-goal propagators installed for the clause body
     - A filtered nogood watcher bridging the shared nogood cell

     This is the N-to-M pattern from the [array-programming research](../research/2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md) §5: N candidates → M survivors, with PU allocation only for survivors. For deterministic cases (M=1), no PU is created — Tier 1 behavior.

2. **`relations.rkt`**: New function `atms-amb-on-network`:
   - Creates M PUs via Phase 2's `make-branch-pu` (only for matching clauses)
   - Records pairwise mutual-exclusion nogoods among the M branches
   - Installs filtered nogood watchers (Phase 3)
   - Returns the list of `(branch-pu . worldview-cid)` pairs

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

2. **Conjunction as simultaneous installation (order-independent)**:
   `solve-goals` (the recursive append-map) is replaced by `install-conjunction`:
   - Takes a list of goals and a parent network/PU
   - Installs ALL goal propagators simultaneously — no sequencing
   - Goal ordering within the clause body does NOT affect execution. `(A, B, C)` and `(C, A, B)` produce the same network topology and the same results
   - Execution order emerges from DATAFLOW: if goal A writes to cell `?x` and goal B reads `?x`, B fires after A — but this is a cell dependency discovered by the propagator network, not an ordering imposed by installation
   - Independent goals (no shared variables) fire concurrently in the same BSP superstep
   - This IS the true-parallel order-independent search: the clause-body ordering is irrelevant; the dataflow graph determines the execution schedule
   - **M2**: The goals list passed to `install-conjunction` is an ENUMERATION (which goals to install), not an ORDERING (what sequence to execute). Installation order is irrelevant.

3. **Answer accumulator cell (M5)**: Each query has an answer accumulator cell with set-union merge. Branch-committer propagators (Phase 2) write results to the accumulator. After quiescence + S(-1) pruning + commit, the accumulator holds all answers. No scanning, no "collect results from surviving branches" — answers arrive via cell writes.

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

4. **Non-recursive completion** (6.4: per-table, not network-wide): A table is complete when ALL its producer propagators have fired AND no new answers arrived in the last round. This is a per-table check, not whole-network quiescence (which would conflate unrelated propagator activity with table stability). Each table tracks its producer count and last-written superstep. After network quiescence, a table is complete if `last-written-superstep < current-superstep` AND all producers have fired.

**What's NOT in scope**: Left-recursive tabling (where predicate A calls A during its own derivation). This requires SLG completion frames — a stack of "active tables" with inter-table dependency tracking. Deferred to BSP-LE Track 3.

**Test coverage**: Non-recursive tabled predicate (memoizes), consumer reads producer's answers, table completion detection, tabled + non-tabled predicates coexist.

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

**Test coverage**: Parity tests, benchmark comparison, acceptance file, edge cases.

---

## §6b Broadcast Propagator Deployment Audit

Every place in the Track 2 design where data-indexed parallel processing occurs MUST use the broadcast propagator pattern, not N separate propagators. Audit of all deployment sites:

| Phase | Component | Items | Item Function | Merge | Notes |
|---|---|---|---|---|---|
| **3** | Per-nogood commitment tracking | Groups in a nogood (2-3) | Check if decision cell committed to nogood member | Component-indexed hash merge | Broadcast over groups, writes to commitment cell |
| **5** | `atms-amb` pairwise nogood creation | N(N-1)/2 pairs from N alternatives | Create one nogood hasheq per pair | Nogood cell set-union | Broadcast over pairs, one write to nogood cell |
| **6** | Clause matching | N clauses | α-rename + try-unify per clause | Set-union of matching results | PRIMARY consumer. Broadcast over clause list. |
| **7** | Goal conjunction installation | K goals in clause body | Install goal propagator per goal | N/A (topology, not value) | Each goal installs independently. Broadcast over goals for TOPOLOGY REQUESTS. |
| **8** | Producer clause body | Clause body goals | Same as Phase 7 (conjunction) | Same | Tabled relation body = conjunction |

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
