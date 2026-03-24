- [Purpose](#org13f82c3)
- [Methodology](#org273ecda)
  - [Inventory Scope](#org60c3733)
  - [Cross-Domain Analysis](#orgc5bea5e)
  - [Architectural Options](#org8e18154)
- [Layer 1: Imperative State Inventory](#org1273625)
  - [1.1 Core Metavariable Infrastructure](#org7b5f73f)
  - [1.2 Elab-Network Structural Fields](#org982c2c6)
  - [1.3 Constraint Infrastructure Cells (Already On-Network)](#org06da542)
  - [1.4 Persistent Registry Cells (Already On-Network)](#org1a68266)
  - [1.5 Resolution Loop State](#orgc82c331)
  - [1.6 Speculation State](#org11b69c4)
  - [1.7 Elaboration Context](#orgcbbc744)
  - [1.8 Module & Definition State](#org7a23a16)
  - [1.9 Caching & Performance](#orgf9b4497)
  - [1.10 Observation & Diagnostics](#orgede7c0e)
  - [1.11 Callback Parameters (Circular Dependency Breakers)](#org6178bbf)
- [Layer 2: Cross-Domain Bridge Analysis](#orga7c03cc)
  - [2.1 Domain Map](#org06f07ec)
  - [2.2 Cross-Domain Information Flows](#org5771229)
    - [Type → Multiplicity](#org85dea22)
    - [Type → Level](#orgdea5498)
    - [Type → Session](#org87fd539)
    - [Constraint → Type (existing, working)](#org17bfed8)
    - [Resolution → Type (existing, working)](#org9d1328f)
    - [Registry → Constraint (existing, working)](#org748083a)
  - [2.3 Bridge Architecture Decision](#org205c891)
    - [Option A: One Unified Network](#org386f187)
    - [Option B: Domain Networks with Typed Bridges](#org7043e2c)
    - [Option C: Two Networks with Domain Tags (Recommended)](#org53c5217)
- [Layer 3: Unification as Native Propagator Construct](#orgc21373a)
  - [3.1 Current Unification Architecture](#org0dfed5d)
  - [3.2 Vision: Cell-Tree Unification](#orgdf4a6f4)
  - [3.3 What the Audit Should Measure](#org8032261)
  - [3.4 Prolog-Inspired Structural Patterns](#orgacd3332)
- [Layer 4: The Limits Question](#org2f66de5)
  - [4.1 Inherently Sequential Operations](#org6246b4d)
  - [4.2 Hot-Path Reads](#org617cd38)
  - [4.3 Error Reporting & Provenance](#orgcf45ecf)
  - [4.4 Determinism](#org8b9bbea)
  - [4.5 Reduction & Normalization](#org1fbe1ea)
  - [4.6 Memo Caches](#org48ee1f3)
- [Layer 5: Architectural Vision — Track 8 Target State](#org56c7cb9)
  - [5.1 Priority 1: Structural State on Network](#org8f1c026)
  - [5.2 Priority 1: Callback Elimination](#orge18cf63)
    - [5.2.1 Callbacks Are a Dependency Graph, Not a Flat List](#orgb343a5a)
    - [5.2.2 The Circular Dependency](#org0ddc30c)
    - [5.2.3 Elimination Paths](#orga242d0a)
    - [5.2.4 Coordination Requirement](#org51be040)
  - [5.3 Priority 1: Unification as Native Construct](#org1bc32e8)
  - [5.4 Priority 2: Mult/Level/Session on Elab-Network](#orgb238f27)
  - [5.5 Priority 2: Resolution State Simplification](#org5d43862)
  - [5.6 Priority 3: Observation Cells](#org28cf954)
  - [5.7 Deferred: Reduction as Propagators](#org9863965)
  - [5.8 Deferred: Elaboration Context as Cells](#org034f049)
- [Summary: Migration Candidates by Priority](#org4c5eb79)
- [Appendix A: File Impact Map](#org0ea0174)
- [Appendix B: Measurement Plan](#orgb270e73)



<a id="org13f82c3"></a>

# Purpose

This audit maps every piece of mutable state in the Prologos elaboration pipeline, classifies cross-domain interactions, and identifies candidates for migration onto the propagator network. It is the prerequisite for Track 8 (Unification as Propagators) design work.

The guiding question: **what is NOT on the propagator network that should be, and what's the cost/benefit of putting it there?**

Motivated by the Track 7 PIR finding that the propagator-first architecture has consistently yielded correctness and performance wins (S(-1) retraction fix, eq? identity preservation, 23% suite speedup). The vision: push propagator networks as far as they go — find the actual limits, not assumed ones.


<a id="org273ecda"></a>

# Methodology


<a id="org60c3733"></a>

## Inventory Scope

Every `make-parameter`, `box`, mutable hash, and mutable struct field that participates in elaboration. For each:

1.  **Name**: parameter/variable name
2.  **Type**: what value it holds
3.  **Lifecycle**: per-command, per-file, global
4.  **Domain**: type, mult, level, session, constraint, resolution, registry, module, cache, observation
5.  **Speculation**: does `save-meta-state` / `restore-meta-state!` touch it?
6.  **Network status**: already a cell? has a cell shadow? purely imperative?
7.  **Migration candidate**: should this become a cell? at what priority?


<a id="orgc5bea5e"></a>

## Cross-Domain Analysis

For each interaction between domains:

-   What information flows?
-   Is the flow monotone or non-monotone?
-   Should the domains share a network or bridge?


<a id="org8e18154"></a>

## Architectural Options

Sketch 3+ architectures for the Track 8 target state.


<a id="org1273625"></a>

# Layer 1: Imperative State Inventory


<a id="org7b5f73f"></a>

## 1.1 Core Metavariable Infrastructure

These are the central state structures for type inference.

| Name                       | Type                     | Lifecycle   | Domain  | Speculation                             | Network Status                             | Migration                                                            |
|-------------------------- |------------------------ |----------- |------- |--------------------------------------- |------------------------------------------ |-------------------------------------------------------------------- |
| `current-prop-net-box`     | box(elab-network)        | per-command | type    | SAVED (box captured in save-meta-state) | PRIMARY cell storage                       | **Keep as box boundary** — sole imperative shell around pure network |
| `current-meta-store`       | hasheq(sym → meta-info)  | per-command | type    | Via network                             | Mapped to elab-network CHAMP (primary)     | **P1**: meta-info CHAMP → TMS-aware network field                    |
| `current-level-meta-store` | hasheq(sym → level-info) | per-command | level   | SAVED                                   | CHAMP box (`current-level-meta-champ-box`) | **P1**: merge into elab-network                                      |
| `current-mult-meta-store`  | hasheq(sym → mult-info)  | per-command | mult    | SAVED                                   | CHAMP box (`current-mult-meta-champ-box`)  | **P1**: merge into elab-network                                      |
| `current-sess-meta-store`  | hasheq(sym → sess-info)  | per-command | session | SAVED                                   | CHAMP box (`current-sess-meta-champ-box`)  | **P1**: merge into elab-network                                      |

**Key finding**: `meta-info`, `id-map`, and `next-meta-id` are elab-network struct fields but NOT TMS-managed. This is the blocker for `restore-meta-state!` retirement (Track 7 PIR §5.6). Making these TMS-aware is the highest-priority Track 8 deliverable.


<a id="org982c2c6"></a>

## 1.2 Elab-Network Structural Fields

| Name                        | Type                            | Lifecycle   | Domain | Speculation             | Network Status               | Migration                                                   |
|--------------------------- |------------------------------- |----------- |------ |----------------------- |---------------------------- |----------------------------------------------------------- |
| `elab-network.meta-info`    | CHAMP(meta-id → meta-info)      | per-command | type   | SAVED via box (not TMS) | Struct field of elab-network | **P1**: TMS-aware field or dedicated cell                   |
| `elab-network.id-map`       | CHAMP(meta-id → cell-id)        | per-command | type   | SAVED via box (not TMS) | Struct field of elab-network | **P1**: accessible from prop-net layer (blocks mult bridge) |
| `elab-network.next-meta-id` | Nat counter                     | per-command | type   | SAVED via box           | Struct field of elab-network | **P2**: monotone counter — natural ascending cell           |
| `elab-network.cell-info`    | CHAMP(cell-id → elab-cell-info) | per-command | type   | SAVED via box           | Struct field of elab-network | **P3**: metadata — less critical than meta-info/id-map      |


<a id="org06da542"></a>

## 1.3 Constraint Infrastructure Cells (Already On-Network)

14 scoped cells in elab-network. Already tracked by assumption tags and S(-1) retraction (Track 7 Phase 4-5). These are **done** — no migration needed.

| Cell ID Parameter                       | Merge Function           | Domain     | Count |
|--------------------------------------- |------------------------ |---------- |----- |
| `current-constraint-cell-id`            | merge-hasheq-union       | constraint | 1     |
| `current-trait-constraint-cell-id`      | merge-hasheq-union       | constraint | 1     |
| `current-trait-cell-map-cell-id`        | merge-hasheq-union       | constraint | 1     |
| `current-hasmethod-constraint-cell-id`  | merge-hasheq-union       | constraint | 1     |
| `current-hasmethod-cell-map-cell-id`    | merge-hasheq-union       | constraint | 1     |
| `current-capability-constraint-cell-id` | merge-hasheq-union       | constraint | 1     |
| `current-constraint-status-cell-id`     | merge-hasheq-union       | constraint | 1     |
| `current-error-descriptor-cell-id`      | merge-hasheq-union       | constraint | 1     |
| `current-wakeup-registry-cell-id`       | merge-hasheq-list-append | constraint | 1     |
| `current-trait-wakeup-cell-id`          | merge-hasheq-list-append | constraint | 1     |
| `current-hasmethod-wakeup-cell-id`      | merge-hasheq-list-append | constraint | 1     |
| `current-unsolved-metas-cell-id`        | merge-hasheq-union       | type       | 1     |
| `current-ready-queue-cell-id`           | merge-list-append        | resolution | 1     |
| `current-defn-param-names-cell-id`      | merge-hasheq-union       | registry   | 1     |


<a id="org1a68266"></a>

## 1.4 Persistent Registry Cells (Already On-Network)

29 cells in the persistent registry network (Track 7 Phases 1-3). Monotone accumulators, file-scoped. These are **done** — no migration needed.

24 macros registry cells + 3 warning cells + 2 narrowing cells.


<a id="orgc82c331"></a>

## 1.5 Resolution Loop State

| Name                                | Type           | Lifecycle   | Domain     | Speculation | Network Status         | Migration                                                             |
|----------------------------------- |-------------- |----------- |---------- |----------- |---------------------- |--------------------------------------------------------------------- |
| `current-in-stratified-resolution?` | boolean        | per-command | resolution | NOT saved   | Purely imperative flag | **P2**: re-entrancy guard — becomes structural with layered scheduler |
| `current-stratified-progress-box`   | box(boolean)   | per-command | resolution | NOT saved   | Purely imperative      | **P2**: replaced by eq? identity detection (Track 7 Phase 7b)         |
| `stratified-resolution-fuel`        | constant (100) | global      | resolution | N/A         | Purely imperative      | **P3**: fuel as descending cell (defense-in-depth)                    |


<a id="org11b69c4"></a>

## 1.6 Speculation State

| Name                            | Type                | Lifecycle      | Domain      | Speculation                  | Network Status            | Migration                                                              |
|------------------------------- |------------------- |-------------- |----------- |---------------------------- |------------------------- |---------------------------------------------------------------------- |
| `current-speculation-stack`     | list(assumption-id) | per-expression | speculation | IS the speculation mechanism | Parameter (dynamic scope) | **P3**: inherently dynamic (follows call stack) — parameter is correct |
| `current-command-atms`          | box(atms)           | per-command    | speculation | NOT saved (lazy init)        | Purely imperative         | **P3**: ATMS is separate from prop-net by design                       |
| `current-retracted-assumptions` | box(seteq)          | per-command    | speculation | Managed by S(-1)             | Purely imperative         | **P2**: could be a descending cell (set shrinks)                       |
| `current-speculation-failures`  | box(list)           | per-command    | speculation | NOT saved                    | Purely imperative         | **P3**: diagnostic — low priority                                      |


<a id="orgcbbc744"></a>

## 1.7 Elaboration Context

| Name                              | Type                    | Lifecycle      | Domain     | Speculation | Network Status    | Migration                                               |
|--------------------------------- |----------------------- |-------------- |---------- |----------- |----------------- |------------------------------------------------------- |
| `current-relational-env`          | hasheq(sym → logic-var) | per-expression | relational | NOT saved   | Purely imperative | **DEFER**: expression-local, not constraint-like        |
| `current-where-context`           | list(where-entry)       | per-expression | type       | NOT saved   | Purely imperative | **DEFER**: stack-scoped, not constraint-like            |
| `current-sess-expr-env`           | list(name.depth)        | per-expression | session    | NOT saved   | Purely imperative | **DEFER**: de Bruijn environment, inherently sequential |
| `current-infer-constraints-mode?` | boolean                 | per-expression | type       | NOT saved   | Purely imperative | **DEFER**: mode flag                                    |

These are expression-local scoping mechanisms. They follow the recursive elaboration call stack and are inherently sequential. Putting them on the network would add complexity without benefit — they're not constraints that benefit from propagation.


<a id="org7a23a16"></a>

## 1.8 Module & Definition State

| Name                                 | Type                     | Lifecycle   | Domain | Speculation | Network Status                             | Migration                                             |
|------------------------------------ |------------------------ |----------- |------ |----------- |------------------------------------------ |----------------------------------------------------- |
| `current-prelude-env`                | hasheq(qname → expr)     | per-file    | module | NOT saved   | Cell-backed via `prelude-env-prop-net-box` | Already persistent                                    |
| `current-module-registry`            | hasheq(sym → module-ast) | per-file    | module | NOT saved   | Purely imperative                          | **P3**: immutable per module — low benefit from cells |
| `current-module-definitions-content` | hasheq(qname → def-ast)  | per-file    | module | NOT saved   | Lookup cache from module-network-ref cells | Already cell-backed (Track 5-6)                       |
| `current-definition-cells-content`   | hasheq(qname → cell-id)  | per-command | module | NOT saved   | Maps names to elab-network cells           | Already cell infrastructure                           |
| `current-definition-dependencies`    | hasheq(sym → listof sym) | per-command | module | NOT saved   | Purely imperative                          | **P3**: dependency edges as propagator edges          |


<a id="orgf9b4497"></a>

## 1.9 Caching & Performance

| Name                      | Type              | Lifecycle   | Domain    | Speculation | Network Status    | Migration                                |
|------------------------- |----------------- |----------- |--------- |----------- |----------------- |---------------------------------------- |
| `current-nf-cache`        | hash(expr → expr) | per-command | reduction | NOT saved   | Purely imperative | **DEFER**: memo cache — not a constraint |
| `current-whnf-cache`      | hash(expr → expr) | per-command | reduction | NOT saved   | Purely imperative | **DEFER**: memo cache                    |
| `current-nat-value-cache` | hash(expr → nat)  | per-command | reduction | NOT saved   | Purely imperative | **DEFER**: memo cache                    |
| `current-reduction-fuel`  | box(nat)          | per-command | reduction | NOT saved   | Purely imperative | **DEFER**: fuel counter                  |

Reduction caches are pure memoization — they don't participate in constraint solving and don't benefit from propagation. Keep imperative.


<a id="orgede7c0e"></a>

## 1.10 Observation & Diagnostics

| Name                    | Type                | Lifecycle   | Domain      | Speculation | Network Status              | Migration                                           |
|----------------------- |------------------- |----------- |----------- |----------- |--------------------------- |--------------------------------------------------- |
| `current-perf-counters` | perf-counter struct | per-command | observation | NOT saved   | Purely imperative           | **P3**: monotone counters — natural ascending cells |
| `current-observatory`   | observatory-state   | per-file    | observation | NOT saved   | Purely imperative (3 boxes) | **P3**: capture cells for LSP observation           |
| `current-verbose-mode`  | boolean             | per-command | observation | NOT saved   | Purely imperative           | **DEFER**: flag                                     |


<a id="org6178bbf"></a>

## 1.11 Callback Parameters (Circular Dependency Breakers)

12 callback parameters in metavar-store.rkt installed by driver.rkt:

| Callback                            | Purpose                          | Migration                                   |
|----------------------------------- |-------------------------------- |------------------------------------------- |
| `current-prop-make-network`         | Create fresh elab-network        | **P1**: inline when module deps resolved    |
| `current-prop-fresh-meta`           | Create meta cell                 | **P1**: inline                              |
| `current-prop-cell-write`           | Merge-based cell write           | **P1**: inline                              |
| `current-prop-cell-replace`         | Raw cell replacement (S(-1))     | **P1**: inline                              |
| `current-prop-cell-read`            | Cell read                        | **P1**: inline                              |
| `current-prop-add-unify-constraint` | Add unify propagator             | **P1**: inline — becomes native unification |
| `current-prop-add-propagator`       | General propagator addition      | **P1**: inline                              |
| `current-prop-new-infra-cell`       | Create infrastructure cell       | **P1**: inline                              |
| `current-prop-run-quiescence`       | Run to fixpoint                  | **P1**: inline                              |
| `current-prop-unwrap-net`           | Extract prop-net from elab-net   | **P1**: inline                              |
| `current-prop-rewrap-net`           | Re-insert prop-net into elab-net | **P1**: inline                              |
| `current-prop-id-map-read/set`      | Access id-map field              | **P1**: inline when id-map accessible       |

These exist solely to break circular module dependencies (metavar-store ↔ elaborator-network ↔ type-lattice ↔ reduction ↔ metavar-store). Track 8 should resolve the circular dependency through module restructuring, eliminating all callbacks. However, these are *not* uniformly eliminable — see §5.2.1 for the dependency graph analysis showing that leaf/branch callbacks peeled off across Tracks 6-7 and PUnify, while root callbacks (`cell-read=/=cell-write`, 48+15 call sites) require coordinated module restructuring with id-map migration.


<a id="orga7c03cc"></a>

# Layer 2: Cross-Domain Bridge Analysis


<a id="org06f07ec"></a>

## 2.1 Domain Map

| Domain       | Core State                                       | Network Status                  | Stratum                   |
|------------ |------------------------------------------------ |------------------------------- |------------------------- |
| Type         | meta cells, unify propagators, type lattice      | elab-network (per-command)      | S0                        |
| Multiplicity | mult meta cells, mult lattice (m0 < m1 < mw)     | CHAMP boxes (legacy)            | S0 (via bridge)           |
| Level        | level meta cells, level lattice                  | CHAMP boxes (legacy)            | S0 (via bridge)           |
| Session      | session meta cells, session type checking        | CHAMP boxes (legacy)            | S0 (via bridge)           |
| Constraint   | trait/hasmethod/capability/postponed constraints | 14 scoped cells in elab-network | L1 (readiness)            |
| Resolution   | ready-queue, resolution actions                  | 1 channel cell in elab-network  | L2 (resolution)           |
| Registry     | schemas, ctors, traits, impls, macros, &hellip;  | 29 cells in persistent network  | Permanent (no retraction) |
| Module       | definitions, dependencies, module networks       | hasheq + cell-backed (Track 5)  | Per-file persistent       |
| Reduction    | nf/whnf caches, fuel                             | Purely imperative               | N/A (not constraint-like) |
| Observation  | perf counters, observatory, verbose mode         | Purely imperative               | N/A (read-only)           |


<a id="org5771229"></a>

## 2.2 Cross-Domain Information Flows


<a id="org85dea22"></a>

### Type → Multiplicity

When a Pi type is solved (`Pi (x : A) m B`), the multiplicity annotation `m` constrains a mult meta. Currently: `decompose-pi` in elaborator-network.rkt creates sub-cells for domain/codomain but cannot wire mult bridges because `id-map` is inaccessible from the prop-net layer.

**Bridge needed**: type cell → mult cell (Galois connection: extract mult from Pi annotation). **Blocked by**: `id-map` accessibility (Track 7 PIR §10.3). **Direction**: unidirectional (type → mult). Mult doesn't constrain type structure.


<a id="orgdea5498"></a>

### Type → Level

When a type expression is solved, universe level constraints may arise (`Type l` where `l` is a level meta). Currently: level solving is separate from type solving.

**Bridge needed**: type cell → level cell. **Direction**: bidirectional (`Type l` constrains `l`; `l` constrains where the type can appear).


<a id="org87fd539"></a>

### Type → Session

Session types are types — `Send Int . Recv Bool . End` is a type expression. Currently: session type checking is a separate pass in qtt.rkt.

**Bridge needed**: type cell → session cell (when type is a session type). **Direction**: bidirectional (session structure constrains type; type inference constrains session).


<a id="org17bfed8"></a>

### Constraint → Type (existing, working)

Trait constraints watch type metas. When type args become ground, constraints become ready (L1 readiness propagators). Resolution (L2) solves the dict meta, writing to a type cell.

**Status**: fully on-network (Track 7 Phase 8a-c).


<a id="org9d1328f"></a>

### Resolution → Type (existing, working)

Resolution propagators write to meta cells (type domain), which triggers S0 type propagation. The feedback loop (L2 → S0 → L1 → L2) is the stratified resolution cycle.

**Status**: fully on-network (Track 7 Phase 7b, 8b).


<a id="org748083a"></a>

### Registry → Constraint (existing, working)

Registry cells (persistent network) are read during constraint creation and resolution. Currently read via parameter fallback or cell-primary reads.

**Status**: persistent cells on-network (Track 7 Phase 1-3). Cross-network bridge not yet wired (registries in persistent network, constraints in elab-network).


<a id="org205c891"></a>

## 2.3 Bridge Architecture Decision

Three options:


<a id="org386f187"></a>

### Option A: One Unified Network

All domains on one `prop-network`. Cells tagged with domain and stratum. Scheduler respects per-cell stratum tags.

**Pros**: simplest topology, no bridge overhead, all cells share structural sharing (CHAMP). Cross-domain reads are just cell reads.

**Cons**: the network grows large (currently ~50 cells per command; would become ~100+ with mult/level/session). `reset-meta-store!` must selectively clear per-command cells while preserving persistent ones. But this is exactly what the lifecycle separation (Track 7) solved.


<a id="org7043e2c"></a>

### Option B: Domain Networks with Typed Bridges

Separate prop-networks per domain. Galois connection bridges between domains. Each network has its own stratification.

**Pros**: clean separation, each network is small and focused. Domain-specific merge functions don't interact.

**Cons**: bridge propagators add overhead and complexity. Cross-domain reads require bridge wiring. The Track 7 experience with persistent ↔ elab bridges showed this works but adds cognitive load.


<a id="org53c5217"></a>

### Option C: Two Networks with Domain Tags (Recommended)

Keep the two-network architecture (persistent + per-command) from Track 7. Within the per-command elab-network, use domain tags on cells but no separate networks. Mult/level/session cells join the elab-network alongside type cells.

**Pros**: builds on proven Track 7 architecture. No new networks to manage. Domain tags enable per-domain diagnostics without per-domain networks. Cross-domain propagators are just regular propagators (no bridges needed within the elab-network).

**Cons**: elab-network grows. But it's already designed for hundreds of cells (one per meta), so adding a few dozen mult/level/session cells is marginal.

**Recommendation**: Option C. The two-network split (persistent registries vs per-command inference) is the right lifecycle boundary. Within the inference network, domain separation should be semantic (cell tags, stratum tags) not structural (separate networks).


<a id="orgc21373a"></a>

# Layer 3: Unification as Native Propagator Construct


<a id="org0dfed5d"></a>

## 3.1 Current Unification Architecture

1.  `elab-add-unify-constraint` creates a bidirectional propagator between two cells
2.  The propagator's fire function calls the unification algorithm (pattern matching, structural decomposition)
3.  For compound types (Pi, Sigma, App), `decompose-pi/sigma/app` creates sub-cells for each component and wires unify propagators between corresponding sub-cells
4.  123 call sites to `unify*` across 11 files

This is already "unification as propagators" at the structural level — the decomposition creates a cell tree. But the unification *algorithm* (deciding how to decompose, handling mismatches) is imperative code inside the fire function.


<a id="orgdf4a6f4"></a>

## 3.2 Vision: Cell-Tree Unification

Types are represented as trees of cells from the start. A meta `?A` is a potential tree that unfolds as structure is learned. Unification is connecting two trees at their roots and letting structural propagation flow through the CHAMP-backed persistent data structures.

CHAMP structural sharing means: if both sides of a unification share a subtree (e.g., both have `Nat` in the domain position), that subtree is literally pointer-equal memory. Comparison is O(diff), not O(size).


<a id="org8032261"></a>

## 3.3 What the Audit Should Measure

Before committing to cell-tree unification, gather data on:

1.  **Unification profile**: How many unifications per command? What fraction are meta-vs-ground vs meta-vs-meta vs compound-vs-compound?
2.  **Decomposition depth**: How deep does `decompose-pi/sigma/app` go? 1 level (Pi domain/codomain)? 2+ levels (nested structures)?
3.  **Occurs check frequency**: How often does the occurs check fire? In what patterns?
4.  **Cell allocation overhead**: Pre-creating cell trees vs lazy decomposition — how many extra cells?
5.  **Current unify propagator cost**: Time in algorithmic logic vs cell operations


<a id="orgacd3332"></a>

## 3.4 Prolog-Inspired Structural Patterns

(From user's design notes — target patterns for acceptance file.)

The key insight: shared variables act as "wires" connecting different parts of the structure. Unification solves all constraints simultaneously regardless of direction.

Pattern categories:

-   **Transitive constraint chains**: A=B, B=C, C=A → all equal (circular propagation)
-   **Diamond patterns**: two paths must agree at a meeting point
-   **Structure copying**: shared variables mean solving one side solves the other
-   **Bidirectional propagation**: left constrains right and vice versa
-   **Failure detection**: incompatible constraints propagate to contradiction

These map naturally to cell-tree unification: shared metas between different parts of a type structure propagate constraints bidirectionally through the cell tree.


<a id="org2f66de5"></a>

# Layer 4: The Limits Question

Where do propagator networks NOT fit?


<a id="org6246b4d"></a>

## 4.1 Inherently Sequential Operations

Some elaboration is inherently sequential: `let` body depends on binding's type. But the dependency can be modeled as stratum ordering (binding type in S0, body elaboration in a higher stratum). The user's insight: "serial operations could just be small firings into higher strata."

**Assessment**: Not a fundamental limit. Sequential dependencies are stratum orderings. The question is whether the stratum overhead is worth it for operations that are already naturally sequential in the current architecture.


<a id="org617cd38"></a>

## 4.2 Hot-Path Reads

`meta-solution` and `ground-expr?` are called thousands of times per command. Currently O(1) hash lookups. As cell reads, they'd be CHAMP traversals (O(log32 n)). For n < 1000 metas, this is ~2 CHAMP levels.

**Assessment**: Likely negligible. The Track 7 eq? identity fix showed that CHAMP operations are cheap; the bottleneck was struct allocation, not CHAMP traversal. But **measure**.


<a id="orgcf45ecf"></a>

## 4.3 Error Reporting & Provenance

Type errors need precise source locations and causal chains. Cell-tree unification would need to preserve provenance — which cell write caused the contradiction, what was the chain of propagation.

**Assessment**: Addressable. Track 4's TMS gives us assumptions; Track 9's GDE will give us minimal diagnoses. The infrastructure exists; the question is wiring it through cell-tree unification.


<a id="org8b9bbea"></a>

## 4.4 Determinism

The current system is deterministic. Propagator networks with BSP scheduling are order-independent within a stratum, but error *reporting* order could vary.

**Assessment**: Worth testing. Add determinism checks to the adversarial benchmark (same input → same output, including error messages).


<a id="org1fbe1ea"></a>

## 4.5 Reduction & Normalization

`reduce` is a pure recursive function. Could reduction steps be propagator firings? When a cell's value changes from `(app (lam x body) arg)` to `body[x :` arg]=, that's a reduction propagator.

**Assessment**: Out of scope for Track 8. Term rewriting as parallel fixpoints is a research direction (the user notes this). Certain functions may benefit from symbolic manipulation on-network. Deferred to future research.


<a id="org48ee1f3"></a>

## 4.6 Memo Caches

NF/WHNF/nat-value caches are pure memoization. They don't participate in constraint solving.

**Assessment**: Keep imperative. Memoization is not a constraint; putting it on the network adds overhead without benefit. If reduction becomes propagator-driven (§4.5), caches become cell memoization — but that's the same future research track.


<a id="org56c7cb9"></a>

# Layer 5: Architectural Vision — Track 8 Target State


<a id="org8f1c026"></a>

## 5.1 Priority 1: Structural State on Network

Make `meta-info`, `id-map`, and `next-meta-id` TMS-aware. This enables:

-   `restore-meta-state!` retirement (structural rollback via TMS)
-   `id-map` accessibility from prop-net layer (unblocks mult bridge)
-   Clean speculation: all state TMS-managed or S(-1) retracted


<a id="orge18cf63"></a>

## 5.2 Priority 1: Callback Elimination

Resolve the circular module dependency. Inline all 12 callback parameters. Direct function calls throughout.


<a id="orgb343a5a"></a>

### 5.2.1 Callbacks Are a Dependency Graph, Not a Flat List

PUnify Parts 1-2 PIR (§16.3) revealed that callback elimination is *not* a uniform task. The 12 callbacks form a dependency hierarchy:

-   **Leaf callbacks** (easy): scanning callbacks (Track 7 eliminated 3→0). Used in one context (`process-command` scanning loop). Self-contained, straightforward to inline.

-   **Branch callbacks** (moderate): `current-prop-has-contradiction?` (PUnify Phase 7). Domain-specific — only the old unification path needed it. When PUnify replaced unification with cell-tree propagators, the check became dead code.

-   **Root callbacks** (hard): `current-prop-cell-read` (48 call sites in metavar-store.rkt) and `current-prop-cell-write` (15 sites). These serve the **entire elaboration pipeline** — `meta-solution`, `solve-meta!`, all registry readers, speculation snapshot/retraction, typing, reduction, zonk. Their elimination is not a single-track task.

The cross-track pattern is **layered peeling**:

| Track   | Eliminated                           | Why It Worked                                        |
|------- |------------------------------------ |---------------------------------------------------- |
| Track 6 | Identified callbacks as anti-pattern | Introduced `install-prop-network-callbacks!`         |
| Track 7 | Scanning callbacks (3→0)             | Self-contained in `process-command`                  |
| PUnify  | `current-prop-has-contradiction?`    | Unification-specific; dead after cell-tree migration |
| Track 8 | `current-prop-cell-read/write`       | **Requires module graph restructuring**              |


<a id="org0ddc30c"></a>

### 5.2.2 The Circular Dependency

```
metavar-store.rkt  ←needs cell operations←  elab-network.rkt
      ↑                                            |
      └────── provides meta infrastructure to ─────┘
```

`metavar-store.rkt` defines the meta/constraint/registry state that `elab-network.rkt` needs. But `elab-network.rkt` defines the `elab-cell-read=/=elab-cell-write` functions that `metavar-store.rkt` needs to access cells. Runtime callback injection breaks this cycle.


<a id="orga242d0a"></a>

### 5.2.3 Elimination Paths

Three candidate approaches (analyzed during PUnify PIR §16.3 discussion):

**Option 1: Module graph restructuring (recommended).** Extract cell-operation API from `elab-network.rkt` into a `cell-ops.rkt` that both modules can import. `elab-cell-read` and `elab-cell-write` are thin wrappers — they unwrap the `elab-network` struct to get the inner `prop-network`, then call `net-cell-read=/=net-cell-write`. If the unwrapping (and `id-map` access) were factored into an independent module, `metavar-store.rkt` could import directly. *This connects to id-map accessibility (§5.1) — both require the same restructuring.*

**Option 2: Explicit network threading.** Pass the network through function arguments instead of reading from `(current-prop-net-box)`. Eliminates parameterized indirection but adds parameter pollution across dozens of call sites in elaborator, typing-core, solver.

**Option 3: Module merge.** Combine `metavar-store.rkt` and `elab-network.rkt`. Eliminates cycle by definition but creates a ~3000+ line monolith.


<a id="org51be040"></a>

### 5.2.4 Coordination Requirement

The root callbacks resist piecemeal elimination because they depend on three concurrent changes:

1.  **Cell-ops extraction** — factor `net-cell-read=/=net-cell-write` wrappers into an importable module
2.  **id-map migration** — make meta-id → cell-id mapping independently accessible (§5.1)
3.  **Mult bridge elimination** — remove the indirection layer that prevents direct prop-net access

Each piece creates value only when done together. Doing one without the others just moves the indirection rather than removing it. This is Track 8 second-half scope — after meta-info TMS-awareness (§5.1) and cell-tree unification (§5.3) establish the foundation.


<a id="org1bc32e8"></a>

## 5.3 Priority 1: Unification as Native Construct

`unify*` becomes a structural operation: connect cell trees, let propagation flow. The 123 call sites become cell-tree connection points. `add-unify-constraint` becomes the primitive.

The `=` operator in WS-mode becomes the user-facing unification syntax, wired through elaboration as a native propagator constraint.


<a id="orgb238f27"></a>

## 5.4 Priority 2: Mult/Level/Session on Elab-Network

Merge mult, level, and session meta stores into the elab-network. Per-meta cells for all four domains (type, mult, level, session) in one network. Cross-domain bridges as propagators within the network.


<a id="org5d43862"></a>

## 5.5 Priority 2: Resolution State Simplification

`current-in-stratified-resolution?` and `current-stratified-progress-box` become unnecessary with the pure resolution chain (Track 7 Phase 7b) and eq? identity detection.


<a id="org28cf954"></a>

## 5.6 Priority 3: Observation Cells

Performance counters as monotone ascending cells. Observatory captures as cell snapshots. This enables LSP real-time observation of elaboration progress.


<a id="org9863965"></a>

## 5.7 Deferred: Reduction as Propagators

Term rewriting on-network. Symbolic manipulation. Parallel fixpoints. This is research territory — defer to a future track after Track 8 validates the cell-tree unification approach.


<a id="org034f049"></a>

## 5.8 Deferred: Elaboration Context as Cells

Typing contexts as cell values. `let`-binding types as cells whose solutions trigger body elaboration propagators. This is the "serial operations as stratum firings" idea. Explore after cell-tree unification is proven.


<a id="org4c5eb79"></a>

# Summary: Migration Candidates by Priority

| Priority  | Item                               | Current State               | Target State                         | Complexity |
|--------- |---------------------------------- |--------------------------- |------------------------------------ |---------- |
| **P1**    | meta-info TMS-awareness            | elab-network struct field   | TMS-managed or dedicated cell        | High       |
| **P1**    | id-map accessibility               | elab-network struct field   | Accessible from prop-net layer       | Medium     |
| **P1**    | Callback elimination (12 params)   | Parameters in metavar-store | Direct calls (module restructure)    | Medium     |
| **P1**    | Unification as native construct    | Algorithmic fire function   | Cell-tree structural propagation     | High       |
| **P1**    | `=` operator in WS-mode            | Reserved, partially wired   | Full pipeline (reader→elab→type)     | Medium     |
| **P2**    | Mult/level/session on elab-network | Separate CHAMP boxes        | Per-meta cells in elab-network       | Medium     |
| **P2**    | Resolution state simplification    | Flags + box                 | Structural (eq? + layered scheduler) | Low        |
| **P2**    | next-meta-id as cell               | Nat counter in struct       | Monotone ascending cell              | Low        |
| **P2**    | retracted-assumptions as cell      | box(seteq)                  | Descending cell                      | Low        |
| **P3**    | Perf counters as cells             | Imperative counters         | Monotone ascending cells             | Low        |
| **P3**    | Observatory as cells               | 3 boxes                     | Cell captures for LSP                | Low        |
| **P3**    | Dependency edges as propagators    | hasheq parameter            | Propagator edges                     | Medium     |
| **DEFER** | Reduction as propagators           | Pure recursive function     | On-network term rewriting            | Research   |
| **DEFER** | Elaboration context as cells       | Parameter-threaded list     | Context cells + stratum firing       | Research   |
| **DEFER** | Memo caches as cells               | Imperative hash             | Cell memoization                     | Research   |


<a id="org0ea0174"></a>

# Appendix A: File Impact Map

| File                        | P1 Changes                                     | P2 Changes                   | P3 Changes         |
|--------------------------- |---------------------------------------------- |---------------------------- |------------------ |
| metavar-store.rkt           | meta-info TMS, callbacks removed, unify wiring | mult/level/session migration | perf counter cells |
| elaborator-network.rkt      | id-map accessible, cell-tree unify             | mult/level/session cells     | —                  |
| propagator.rkt              | — (sufficient from Track 7)                    | —                            | —                  |
| driver.rkt                  | callback removal, module restructure           | —                            | observatory cells  |
| resolution.rkt              | inline (no callbacks)                          | —                            | —                  |
| typing-core.rkt             | unify call sites → cell-tree                   | —                            | —                  |
| unify.rkt                   | core rewrite (cell-tree unification)           | —                            | —                  |
| qtt.rkt                     | —                                              | mult cells on elab-network   | —                  |
| macros.rkt                  | —                                              | —                            | —                  |
| elab-speculation-bridge.rkt | meta-info TMS enables restore retirement       | —                            | —                  |
| batch-worker.rkt            | simplified (fewer params to snapshot)          | —                            | —                  |
| test-support.rkt            | simplified (fewer params to parameterize)      | —                            | —                  |


<a id="orgb270e73"></a>

# Appendix B: Measurement Plan

Before Track 8 design, gather concrete numbers via microbenchmarks:

1.  **Unification profile**: Instrument `unify*` calls. Count: meta-vs-ground, meta-vs-meta, compound-vs-compound. Measure decomposition depth.
2.  **Cell allocation overhead**: Count cells created per command. Estimate overhead of pre-creating cell trees.
3.  **CHAMP traversal cost**: Microbenchmark `champ-lookup` at depths 1-4 (typical meta counts: 50-200).
4.  **id-map access frequency**: Count `id-map` reads per command. This determines the importance of making it accessible from prop-net.
5.  **Callback overhead**: Measure parameter read overhead for 12 callbacks × thousands of calls per command.

Use `bench-micro.rkt` for function-level measurements. Use `bench-ab.rkt` for A/B comparison of architectural changes.
