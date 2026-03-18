# Track 7: Persistent Registry Cells + Stratified Propagator Network + QTT Multiplicity Cells — Stage 2/3 Design

**Created**: 2026-03-18
**Status**: DESIGN COMPLETE (D.1 + D.2 external critique + D.3 self-critique — ready for Phase 0)
**Depends on**: Track 3 ✅, Track 4 ✅, Track 5 ✅, Track 6 ✅
**Enables**: Track 8 (Unification as Propagators), Track 9 (GDE), Track 10 (LSP)
**Master roadmap**: `2026-03-13_PROPAGATOR_MIGRATION_MASTER.md` Track 7
**Audit**: `2026-03-18_STRATIFIED_ARCHITECTURE_AUDIT.md`
**Prior PIRs**: Track 4 (TMS cell architecture), Track 5 (persistent module networks), Track 6 (stratified prop-net insight, dual-write reframing, context-loss risk)
**Principle references**: DESIGN_PRINCIPLES.org § "Stratified Propagator Networks", DEVELOPMENT_LESSONS.org § "Callbacks Are a Propagator-First Anti-Pattern", GÖDEL_COMPLETENESS.org (termination guarantee hierarchy)

---

## Progress Tracker

| Phase | Description | Status | Termination | Notes |
|-------|-------------|--------|-------------|-------|
| D.1 | Initial design document | ✅ | — | This document |
| D.2 | External critique + response | ✅ | — | §14; threshold-cell redesign, scanning audit, assumption taxonomy |
| D.3 | Self-critique (principle alignment) | ✅ | — | §9+§15; T1 resolved (Option A), T2-T6 documented, all tensions addressed |
| 0a | Acceptance file | ✅ | — | 5 bugs discovered; session/relational/speculation coverage |
| 0b | `process-file` verbose instrumentation | ✅ | — | 12-field VERBOSE JSON per command (commit `8b8acfe`); perf-counters 12→15 fields (commit `1056469`) |
| 0c | Adversarial constraint graph + baseline capture | ✅ | — | First prelude-using comparative benchmark; 54 metas, 29 res-cycles; ~14.3s median; full suite baseline saved (commit `1810d2b`) |
| 1 | Persistent registry network infrastructure | ✅ | L1 (finite registries) | WS-C: `current-persistent-registry-net-box` + `init-persistent-registry-network!` (commit `51a839e`) |
| 2 | Registry cell persistence migration | ✅ | L1 (monotone merge) | WS-C: 29 cells in persistent prop-network; reads/writes retargeted (commit `51cb896`) |
| 3 | Dual-write elimination | ✅ (3a) | — (no new propagators) | WS-C: 3a done (per-command overhead removed); 3b deferred to Phase 6 (param writes + read fallback retained for seeding + test isolation) |
| 4 | Assumption-tagged scoped cells | ✅ | L1 (finite assumptions) | WS-B: 14 cells tagged; read functions unwrap; merge-constraint-status-map updated |
| 5 | S(-1) retraction stratum | ✅ | L1 (assumption set ↓) | WS-B: `run-retraction-stratum!` cleans 11 scoped cells; belt-and-suspenders with restore |
| 6 | Belt-and-suspenders retirement | ✅ | — (removal, not addition) | WS-B: 6a restore retained (structural state), 6b-c dead code, 6d test fixtures, 6e reads cell-primary, 6f deferred (harmless), 6g batch-worker box-contents snapshot |
| 7a | Module extraction + callback elimination | ✅ | — (restructuring only) | WS-B: `resolution.rkt` with unified dispatcher; 3 callbacks → 1 executor |
| 7b | Resolution chain purification | ✅ | — (signature change) | WS-B: pure write chain + solve-meta! sole box boundary; read bridge via parameterize |
| 8a | Readiness propagators (L1) | ✅ | L1 (fire once per dep) | WS-B: audit done; ready-queue + threshold-cell propagators installed |
| 8b | Resolution propagators (L2) | ✅ | L2 (type depth ↓) | WS-B: ready-queue consumption in pure loop |
| 8c | Stratified loop elimination | ✅ | L1+L2 (composed) | WS-B: scanners removed; ready-queue sole action source; loop retained for fuel/progress |
| 9 | QTT multiplicity cells + cross-domain bridges | ✅ (infra) | L1 (3-element lattice) | WS-A: all infrastructure exists (Track 4); wiring blocked by prop-net/elab-net boundary in decompose-pi (Track 8 scope) |
| 10 | Performance validation + PIR | 🔄 | — | Benchmarks complete: 0 regression; PIR pending |

---

## Non-Goals

Track 7 does NOT deliver:

- **LSP integration** — persistent cells and retraction benefit the LSP, but LSP-specific concerns (file watching, incremental re-elaboration triggers) are Track 10.
- **Cross-module shadow-cell consistency** — Track 5's shadow-cell pattern is batch-correct. Multi-invocation consistency is Track 10 (LSP).
- **Persistent definition cells** — definition cells already persist via `current-definition-cells-content` (Track 5 pattern). Track 7 extends this pattern to registries only. The asymmetry is principled: **registry cells are per-category** (one cell per registry type — schema, ctor, trait, impl, etc. — 29 total, known statically, allocated once at file init), while **definition cells are per-name** (each `def`, `type`, `defn` gets its own cell — hundreds per file, allocated dynamically as definitions are elaborated). The persistent network is designed for small, static state with stable cell IDs. A growing, dynamic collection of definition cells would make it large and violate that design intent.
- **GDE minimal diagnoses** — Track 7 builds the propagator infrastructure that GDE will consume (Track 9).

---

## 1. Problem Statement

After six tracks of propagator migration, the architecture carries three forms of transitional debt:

**1. Per-command cell recreation**: Every command recreates 29+ registry cells from parameters via `register-macros-cells!`, `register-warning-cells!`, and `register-narrow-cells!`. The parameters are the persistent store; cells are ephemeral propagation shadows. This means:
- 29 cell allocations + network insertions per command (~7000 tests × 29 = ~200K cell creations during a test run)
- The dual-write pattern (param + cell) in every `register-*!` function exists because cells aren't persistent
- Cell-id parameters are reset every command, making cell references unstable

Track 6 PIR §5.2 identified this correctly: "parameter writes are the persistent data store; cell writes are for propagation." But this is transitional — the propagator-first architecture says cells should BE the persistent store.

**2. No retraction for infrastructure cells**: TMS retraction (Track 6 Phases 2+3, 4) works for value-level cells (metavariables) but not for infrastructure cells (constraints, wakeups, warnings) that use monotonic accumulation (`merge-hasheq-union`, `merge-list-append`). The Phase 5b belt-and-suspenders retirement is blocked because `restore-meta-state!` must still snapshot/restore the network box for infrastructure cells.

**3. Imperative scanning and callback indirection**: The stratified resolution loop's Stratum 1 iterates all constraints/traits/hasmethods each cycle (O(total)). Resolution logic is injected via 3 callback parameters that break circular module dependencies. Both patterns work but violate propagator-first principles — readiness should be a cell value, resolution should be structural.

### Workstream ordering: hard thing first

Following the principle established in Tracks 4-6, Track 7 orders workstreams by architectural significance:

- **WS-C (Persistent Registry Cells)** — most foundational. Changes the persistence model from parameters to cells. All other workstreams benefit from stable cell references.
- **WS-B (Stratified Retraction + Readiness Propagators)** — depends on WS-C for stable cell infrastructure. S(-1) retraction and readiness propagators need cells that persist across commands.
- **WS-A (QTT Multiplicity Cells)** — smallest, lowest risk. Can proceed independently once the network architecture is stable.

---

## 2. Architectural Foundation

### 2.1 Two-network architecture: persistent + ephemeral

The key insight from Track 5's definition cell pattern: `current-definition-cells-content` (persistent hasheq) + per-command cell recreation in `register-global-env-cells!`. Definitions persist; their cells are recreated each command. This works but creates unstable cell references.

Track 7 introduces a **persistent network** that lives alongside the per-command elab-network:

```
┌─────────────────────────────────────────────────────────┐
│  Per-File Persistent State                               │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Persistent Registry Network (NEW in Track 7)     │   │
│  │  • 24 macros registry cells                       │   │
│  │  • 3 warning accumulator cells                    │   │
│  │  • 2 narrowing constraint cells                   │   │
│  │  • Created once at file/prelude load time         │   │
│  │  • Survives across commands                       │   │
│  │  • Cell IDs are STABLE (never recreated)          │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  current-definition-cells-content (existing — Track 5)   │
│  current-module-definitions-content (existing — Track 6) │
│  current-prelude-env (existing — belt-and-suspenders)    │
│                                                          │
├─────────────────────────────────────────────────────────┤
│  Per-Command Ephemeral State                             │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Elab-Network (existing — created by reset-meta)  │   │
│  │  • Metavariable cells (per-meta)                  │   │
│  │  • Constraint infrastructure cells (12)           │   │
│  │  • Definition cells (recreated from content)      │   │
│  │  • TMS cells for speculation                      │   │
│  │  • Cleared per command via reset-meta-store!      │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  current-meta-store, current-constraint-store, etc.      │
└─────────────────────────────────────────────────────────┘
```

**Why two networks, not one?** Metavariables and constraints are genuinely per-command — they're created, solved, and discarded within a single type-checking pass. Registries are genuinely per-file — a `type` or `trait` defined in command 1 must be visible in command 2. Mixing them in one network means either (a) the whole network is recreated per command (current approach — destroys registry cell stability), or (b) the network persists but metas/constraints must be selectively cleared (complex, error-prone).

Two networks with different lifecycles is the clean separation. The elab-network handles per-command inference. The persistent network handles cross-command state. Reads can consult both; writes go to the appropriate network based on the data's lifecycle.

### 2.2 The CHAMP advantage

Both networks are CHAMP-based (`prop-network`). Two separate `prop-network` instances share no CHAMP structure by default, but this is fine — the persistent network is small (~29 cells) and its cost is amortized across many commands. The elab-network is the large, per-command structure with potentially hundreds of metavariable cells.

### 2.3 Cell stability enables downstream architecture

With persistent cells, cell IDs become stable file-level identifiers. This enables:
- **Readiness propagators** (WS-B Phase 8): a propagator watching a registry cell doesn't need to be recreated each command
- **S(-1) retraction** (WS-B Phase 5): the retraction propagator watches persistent cells, not ephemeral ones
- **LSP observation** (Track 10): the LSP can watch registry cells for changes without needing per-command cell-id rediscovery
- **Dual-write elimination** (WS-C Phase 3): once cells persist, parameters are unnecessary for persistence — cells ARE the persistent store

### 2.4 Stratified retraction: S(-1) as the dual of NAF-LE aggregation

The stratified architecture audit (§4.4) established that retraction is the dual of aggregation in stratified semantics. Both are non-monotonic operations made safe by stratification — computing to fixpoint before downstream strata observe the result.

The S(-1) stratum handles retraction for **scoped cells** — cells that participate in speculation:

| Cell Class | Examples | Retraction | Persistence |
|------------|----------|------------|-------------|
| **Permanent** | 24 macros registries | Not retractable | Persistent network |
| **Scoped** | 8 constraint, 3 wakeup, 3 warning cells | S(-1) retraction | Elab-network (per-command) |
| **Value** | Metavariable cells | TMS retraction (existing) | Elab-network (per-command) |

Permanent cells (registries) don't participate in speculation — a `type` definition isn't created speculatively. Scoped cells (constraints, wakeups, warnings) are created during elaboration and may be created under speculative assumptions. Value cells (metas) already have TMS retraction from Track 4/6.

### 2.5 The complete stratified propagator network

Track 7 delivers the **full stratified propagator network** — not just readiness propagators and retraction, but also resolution propagators and the elimination of the hand-written stratified loop. The complete architecture:

```
┌──────────────────────────────────────────────────────────────────────┐
│  Layered Network Quiescence (replaces run-stratified-resolution!)     │
│                                                                       │
│  S(-1): Retraction Layer                                              │
│    Watches: believed-assumptions cell                                 │
│    Fires: cleanup propagators for scoped cells                        │
│    Non-monotone, contained below S0                                   │
│                                                                       │
│  S0: Type Propagation Layer                                           │
│    Existing: unification propagators, meta cells                      │
│    Fires: when meta cell values change                                │
│    Monotone (type lattice)                                            │
│                                                                       │
│  L1: Readiness Detection Layer                                        │
│    New: fan-in readiness propagators (1 per constraint)               │
│    Countdown latch: O(1) readiness check via ground-count             │
│    Writes: action descriptors to ready-queue channel cell             │
│    O(changed), not O(total) — no scanning                             │
│                                                                       │
│  L2: Resolution Commitment Layer                                      │
│    New: resolution propagator watching ready-queue                    │
│    Fire function IS the resolution logic                              │
│    Output: solve-meta! → writes to meta cells → perturbs S0          │
│    No callbacks — logic is structural                                 │
│                                                                       │
│  Scheduling: Hybrid BSP/Gauss-Seidel                                  │
│    WITHIN each stratum: BSP (all dirty propagators fire per round)    │
│    BETWEEN strata: Gauss-Seidel (S(-1)→S0→L1→L2, sequential)         │
│    Justified by CALM: intra-stratum propagation is monotone (safe     │
│    for BSP/no coordination). Inter-stratum transitions are non-       │
│    monotone from the higher stratum's perspective (need coordination  │
│    = barrier = Gauss-Seidel ordering).                                │
│    Feedback: if L2 wrote to S0 cells, restart from S(-1)             │
│                                                                       │
│  Termination: quiescence across ALL layers                            │
│  (replaces fuel counter in hand-written loop)                         │
│                                                                       │
│  Bridge Propagators (Galois Connection)                               │
│    Persistent registry network ←→ Elab-network                       │
│    One-way bridge per registry cell: persistent cell is source,       │
│    shadow cell in elab-network is target. Created once per command    │
│    (lazy — fired once on initial sync). Cheaper than recreating 29   │
│    cells and seeding from parameters.                                 │
└──────────────────────────────────────────────────────────────────────┘
```

This is the architectural completion of the propagator-first vision for constraint resolution. After Track 7, adding a new constraint type means adding an L1 readiness propagator (fan-in) and an L2 resolution propagator — no loop modifications, no scanning functions, no callbacks.

### 2.6 Propagator Taxonomy

Track 7 introduces several propagator patterns beyond the basic "cell A → propagator → cell B" transform. This taxonomy classifies the granular patterns used across the architecture:

**Structural patterns** (how propagators connect cells):

| Pattern | Inputs | Outputs | Description | Example |
|---------|--------|---------|-------------|---------|
| **Transform** | 1 cell | 1 cell | Monotone map between lattice values | Type substitution propagator |
| **Fan-in** | N cells | 1 cell | Combines N inputs to produce one output. Enables countdown latch optimization: maintain a ground-count per output; each input transition from ⊥ increments count; output fires when `count == N`. O(1) per input change, O(1) readiness check. Under BSP, fires once per round (checking all N inputs in one pass). | L1 readiness propagator |
| **Fan-out** | 1 cell | N cells | Broadcasts one value to N targets | Shadow cell population from module network |
| **Bridge** | 1 cell (net A) | 1 cell (net B) | Cross-network Galois connection. Lower adjoint: source → target. Upper adjoint: identity (read-only bridge) or merge (bidirectional). | Persistent registry → elab-network shadow |

**Lifecycle patterns** (how cells participate in state management):

| Pattern | Write | Read | Consume | Description | Example |
|---------|-------|------|---------|-------------|---------|
| **Value cell** | Monotone merge | Current value | — | Standard lattice cell. Value only grows. | Meta cell, type cell |
| **Accumulator cell** | List-append / hash-union | Full collection | S(-1) retraction by assumption | Collects entries tagged with assumptions. Retraction removes non-believed entries. | Constraint store, wakeup index |
| **Channel cell** | Tagged write (L1) | Read (L2) | Retract assumption (L2) → S(-1) cleanup | Produce-consume pattern. Writer tags entries with fresh assumptions; consumer reads entries and retracts their assumptions; S(-1) cleans retracted entries. All on-network. | Ready-queue between L1 and L2 |
| **Shadow cell** | Mirror from source (bridge) | Same as source | Follows source lifecycle | Read-only projection of a cell in another network. | Elab-network view of persistent registry cell |

**Scheduling patterns** (how propagators interact with the layered scheduler):

| Pattern | Layer | Scheduling | Description | Example |
|---------|-------|------------|-------------|---------|
| **Stratum propagator** | Tagged S(-1)/S0/L1/L2 | BSP within layer, Gauss-Seidel between layers | Standard layer-tagged propagator. Fires during its layer's BSP round. | All Track 7 propagators |
| **Threshold propagator** | Cross-layer | Fires at stratum transition (quiescence of lower layer) | Activates when lower layer reaches fixpoint. Used for stratum boundary logic. | S(-1) → S0 transition, L1 → L2 transition |

**Assumption taxonomy** (two uses of assumption IDs, single ID space):

| Kind | Created by | Retracted by | Tags | Trigger |
|------|-----------|-------------|------|---------|
| **Speculation assumption** | `with-speculative-rollback` (TMS) | Speculation rollback on failure | Value-level cells (metas) via TMS branches | Speculative branch disbelieved |
| **Lifecycle assumption** | L1 readiness propagator (channel cell pattern) | L2 resolution propagator after consumption | Channel cell entries (ready-queue actions) | Action consumed by resolver |

Both use the same `make-fresh-assumption!` gensym counter. No collision risk: they live in different cells (TMS-managed meta cells vs. channel cell ready-queue) and are retracted for different reasons (speculation failure vs. consumption). S(-1) handles both uniformly — it scans scoped cells for entries tagged with non-believed assumptions, regardless of assumption kind.

This taxonomy is a starting point. A richer taxonomy — including patterns for distributed/concurrent runtimes, temporal propagators, and higher-order propagators — is deferred to future research (see DEFERRED.md).

### 2.7 Readiness propagators: O(changed) replaces O(total)

The audit (§2.1) identified 6 scanning functions in S1 that iterate all constraints/traits/hasmethods each cycle. The replacement:

- At constraint registration time, create a **readiness propagator** that watches the constraint's dependency cells
- When all dependencies become non-bot, the propagator writes an action descriptor to a **ready-queue cell**
- S1 becomes a cell read (pop from ready-queue) instead of a scan

This is the standard propagator-network approach: instead of polling for readiness, react to it.

---

## 3. Infrastructure Gap Analysis

### What we have (from Tracks 1–6)

| Infrastructure | Status | Source |
|----------------|--------|--------|
| Per-definition persistent cells | ✅ | Track 5 (`current-definition-cells-content`) |
| Module-network-ref (persistent per-module) | ✅ | Track 5 |
| TMS cells for metavariables | ✅ | Track 4/6 |
| TMS retraction for value cells | ✅ | Track 6 Phases 2+3, 4 |
| Speculation stack push + commit | ✅ | Track 6 Phases 2+3 |
| Elaboration guard removal | ✅ | Track 6 Phase 8b-c |
| Net-box scoping to command | ✅ | Track 6 Phase 8b-c |
| Cell-primary readers (unconditional) | ✅ | Track 3 + Track 6 |
| Stratified resolution loop (S0-S1-S2) | ✅ | Track 2 |
| Action descriptor pattern | ✅ | Track 2 Phase 4 |

### What we need

| Gap | Required For | Phase | Complexity |
|-----|-------------|-------|-----------|
| Persistent registry network | Stable cell IDs, dual-write elimination | WS-C Phase 1 | Medium |
| Registry cell migration | Move 29 cells to persistent network | WS-C Phase 2 | Medium |
| Assumption tagging on scoped cell writes | S(-1) retraction | WS-B Phase 4 | Low |
| Believed-assumptions cell | S(-1) trigger | WS-B Phase 5 | Low |
| S(-1) retraction propagator | Cleanup non-believed entries | WS-B Phase 5 | Medium |
| Ready-queue cell + per-constraint readiness propagators | Replace S1 scanning | WS-B Phase 8 | Medium |
| Module restructuring for callback inlining | Direct resolution calls | WS-B Phase 7 | Low |
| Mult lattice + cells | QTT in network | WS-A Phase 9 | Low |
| Type ↔ mult bridge propagators | Cross-domain reasoning | WS-A Phase 9 | Low |

---

## 3b. Design: Phase 0 — Baseline, Instrumentation, Adversarial Graph

### Phase 0a: Acceptance File ✅

**Delivered**: `examples/2026-03-18-track7-acceptance.prologos` (commit `3101ea5`). Exercises session types, process definitions, relational features, speculation interleaved with declarations, registry accumulation stress. 5 L3 bugs discovered (user `data` constructors unbound at file level, `{A}` + multi-arity defn parser crash, match-in-defn-body crash, let-in-match reader failure, `->` in identifiers).

### Phase 0b: `process-file` Verbose Instrumentation

**Goal**: Add a `--verbose` (or parameterized) mode to `process-file` that emits per-command elaboration summaries in a structured format. This is the diagnostic foundation for Phases 7-8 belt-and-suspenders validation and the adversarial benchmark.

**Per-command output** (when verbose):

| Field | Description | Source |
|-------|-------------|--------|
| `command-index` | Sequential command number in the file | `process-file` loop counter |
| `form-summary` | First 80 chars of the source form | Reader output |
| `metas-created` | Metavariables allocated this command | `perf-inc-meta-created!` (existing) |
| `metas-solved` | Metavariables solved this command | `perf-inc-meta-solved!` (existing) |
| `constraints-registered` | Postponed constraints created | `perf-inc-constraint-count!` (existing) |
| `trait-resolutions` | Trait constraints resolved | `perf-inc-trait-resolve-steps!` (existing) |
| `prop-firings` | Propagator firings during quiescence | NEW: instrument `run-to-quiescence` |
| `s1-scan-time-ms` | Time in S1 readiness scanning | NEW: wrap `collect-ready-*` |
| `s0-quiescence-time-ms` | Time in S0 type propagation | NEW: wrap `run-to-quiescence` |
| `resolution-cycles` | Iterations of `run-stratified-resolution!` | NEW: count loop iterations |
| `cell-allocs` | Cells allocated this command | NEW: `perf-inc-cell-alloc!` |
| `wall-ms` | Total command wall time | `current-inexact-milliseconds` delta |

**Output format**: One JSON object per command to stderr (when `current-verbose-mode` is `#t`). Parseable by the adversarial benchmark harness. Does not affect stdout result output.

```racket
;; Example output line:
;; {"cmd":3,"form":"[+ [* 2 3] [- 10 4]]","metas":4,"solved":4,
;;  "constraints":0,"traits":2,"firings":12,"s1_ms":0.1,"s0_ms":0.3,
;;  "cycles":1,"cells":6,"wall_ms":1.2}
```

**Integration**: Add `current-verbose-mode` parameter (default `#f`). `process-file` accepts optional `#:verbose #t`. The acceptance file and adversarial benchmark pass this flag. Normal test runs are unaffected.

**Scope**: Minimal — instrument existing counters + add 4 new timing/counting points. No architectural changes. This is plumbing for Phases 7-10, not a feature.

### Phase 0c: Adversarial Constraint Graph + Baseline Capture

**Goal**: Create a synthetic `.prologos` file that exercises the constraint resolution pipeline under adversarial conditions, and capture baseline performance of the current hand-written loop.

**File**: `examples/2026-03-18-track7-adversarial.prologos`

**Graph structure** (concrete Prologos expressions):

1. **Deep cascading resolution chains (depth 5+)**: Nested trait constraints where resolving one unblocks the next.
   ```
   ;; Num Int resolves to: Add Int + Sub Int + Mul Int + Neg Int + Abs Int + FromInt Int
   ;; Each sub-trait resolution is a separate L2 action.
   ;; Nesting: [+ [* [- [abs x] [neg y]] z] w] triggers 5+ cascading resolutions.
   ```

2. **Wide fan-out (20+ constraints per meta)**: A single polymorphic function applied to many different types in one expression, creating many trait constraints that share a meta.
   ```
   ;; 20+ independent [+] calls in a list, each creating independent Num constraints
   ;; but sharing the return-type meta of the enclosing expression.
   ```

3. **Nested speculation (3+ levels)**: Deeply nested union types that trigger cascading `with-speculative-rollback`.
   ```
   ;; def v : <<Int | Bool> | <String | Rat>> := 42
   ;; Three levels of union → three speculation depths.
   ```

4. **Cascading resolution feedback**: Trait hierarchy where resolving one instance unblocks another.
   ```
   ;; User-defined trait hierarchy: Showable requires Describable requires Eq
   ;; Resolving Eq Int → dict-meta solved → unblocks Describable Int readiness
   ;; → Describable Int resolved → unblocks Showable Int readiness
   ;; (NOTE: requires user-defined traits, blocked by the data-constructor L3 bug.
   ;;  Use prelude traits: Ord requires Eq. Num requires Add+Sub+Mul+...
   ;;  These already cascade.)
   ```

**Baseline capture**: Run the adversarial graph with verbose mode (`#:verbose #t`). Record:
- Per-command JSON (from Phase 0b instrumentation)
- Total `resolution-cycles` across all commands
- Total `prop-firings` across all commands
- Total `s1-scan-time-ms` (the scanning cost that L1 readiness propagators will eliminate)
- Total wall time

Store baseline in `data/benchmarks/adversarial-baseline.json`. Phase 8 compares the layered scheduler against this baseline.

**Measurement methodology**: Run 3× and take median (reduce noise). The adversarial graph should be deterministic (no randomness, same constraint ordering every run).

---

## 4. Design: WS-C — Persistent Registry Cells

### Phase 1: Persistent Registry Network Infrastructure

**Goal**: Create the persistent network and the lifecycle management around it.

**New parameter**: `current-persistent-registry-net-box` — holds a `box` containing the persistent `prop-network` for registry cells. Created once per file/prelude load, survives across commands.

**New function**: `init-persistent-registry-network!`
```racket
(define (init-persistent-registry-network!)
  ;; Create a fresh prop-network for persistent registries
  (define net (make-net))  ;; via current-prop-make-network
  (current-persistent-registry-net-box (box net)))
```

Called once at file start (in `process-file`/`load-module`), not per command. The box is parameterized at file scope — batch-worker's parameterize restores it to the post-prelude snapshot per test file.

**Pipeline checklist (D.3 T6)**: New parameter `current-persistent-registry-net-box` must be added to:
1. `test-support.rkt` parameterize block
2. `batch-worker.rkt` save/restore list
3. `with-fresh-meta-env` if applicable (likely not — registries are not meta-related)
4. Track 5 PIR lesson: audit that `run-ns-last` test path correctly initializes the persistent network, not just the production path.

**Cell-id stability**: Registry cell-id parameters (`current-schema-registry-cell-id`, etc.) are set once during init, not reset per command. They become file-scoped stable references.

**Integration via bridge propagators**: The elab-network (per-command) and persistent-registry-network (per-file) are separate `prop-network` instances. Rather than routing reads to the correct network via conditionals, we use **bridge propagators** (Galois connections) to project persistent registry values into the elab-network as shadow cells:

```racket
;; Per-command: create shadow cells in elab-network bridged from persistent network
(define (bridge-registries-to-elab!)
  (for ([persistent-cid (in-list persistent-registry-cell-ids)])
    (define shadow-cid (net-add-cell! elab-net (cell-read persistent-cid)))
    (add-bridge-propagator! persistent-cid shadow-cid)))
```

This means:
- **Writes** go to the persistent network (via `macros-cell-write!` pointing to persistent net-box)
- **Reads during elaboration** go through shadow cells in the elab-network (same network as metas — no cross-network routing needed)
- **Bridge propagators** keep shadows in sync (lazy — only fire when persistent cell changes during the command)
- **Shadow cells auto-clean** when the elab-network is cleared per command — no explicit cleanup

This is the same cross-network bridge pattern Track 5 uses for module→file definition shadowing. The existing `macros-cell-read-safe` helpers read from the shadow cell in the elab-network, not from the persistent cell directly.

### Phase 2: Registry Cell Persistence Migration

**Goal**: Migrate 29 registry cells from per-command creation to persistent creation.

**Changes to `register-macros-cells!`**:
- Currently: creates 24 cells in the elab-network per command
- After: creates 24 cells in the persistent network ONCE (at init time)
- `register-macros-cells!` becomes `init-macros-cells!`, called from `init-persistent-registry-network!`
- Per-command `register-macros-cells!` call in `process-command` is removed

**Same treatment for**:
- `register-warning-cells!` → `init-warning-cells!` (3 cells)
- `register-narrow-cells!` → `init-narrow-cells!` (2 cells)

**Cell initialization**: Cells are initialized from current parameter values at init time — same data, different lifecycle. The persistent network's cells hold the accumulated state; subsequent `register-*!` calls write to the persistent cell.

**Belt-and-suspenders**: During Phase 2, keep parameter writes (dual-write). Validate that persistent cell reads match parameter reads after each command.

### Phase 3: Dual-Write Elimination

**Goal**: Remove per-command overhead from registry cell management. Cells in the persistent network are now the sole runtime store; parameter writes are retained only for module-load-time seeding.

**Phase 3a (delivered)**: Remove per-command cell creation calls and elab-network net-box scoping:
- `register-macros-cells!`, `register-warning-cells!`, `register-narrow-cells!` calls removed from `process-command` (already no-ops from Phase 2)
- `current-macros-prop-net-box`, `current-warnings-prop-net-box`, `current-narrow-prop-net-box` scoping removed from `process-command`'s parameterize (reads/writes go directly to persistent network)

**Phase 3b (deferred to Phase 6)**: Full parameter write removal and read-path simplification. Blocked by two dependencies:

1. **Module-load-time seeding**: `macros.rkt` has ~20 register calls at module load time (built-in Nat/Bool/Unit ctors, subtype pairs, etc.) that execute before any persistent network exists. These write to parameters, which `init-macros-cells!` reads to initialize persistent cells. Removing parameter writes from `register-*!` functions would lose these built-in registrations. **Resolution**: Phase 6 will either (a) replay built-in registrations into the persistent network directly, or (b) move built-in registrations to a separate init function that runs after persistent network creation.

2. **Test fixture isolation**: `test-support.rkt` sets `[current-persistent-registry-net-box #f]` for test isolation. With this setting, all `macros-cell-read-safe` calls return `'not-found`, and the read-* functions fall back to parameters. Removing the parameter fallback would break ~160 test files. **Resolution**: Phase 6 will update test-support.rkt to initialize a persistent network per test (or per shared fixture), eliminating the need for parameter fallback.

**What's achieved after Phase 3a**:
- Per-command overhead reduced: no registry cell creation, no registry net-box scoping
- Persistent network is the runtime authority for reads and writes during `process-command`
- Parameters still written (dual-write) but only needed as seeds and test fallback
- batch-worker already snapshots `current-persistent-registry-net-box` (Phase 1)

---

## 5. Design: WS-B — Stratified Retraction + Readiness Propagators

### Phase 4: Assumption-Tagged Scoped Cells

**Goal**: Tag writes to scoped cells (constraints, wakeups, warnings) with the creating assumption ID.

**Which cells are scoped** (14 total):
- 8 constraint cells (constraint store, trait/hasmethod/capability constraints, trait/hasmethod cell-maps, constraint status)
- 3 wakeup cells (wakeup registry, trait wakeup, hasmethod wakeup)
- 3 warning cells (coercion, deprecation, capability)

**Tagging mechanism**: Each entry written to a scoped cell carries an `assumption-id` field. At speculation depth 0 (no speculation), the assumption-id is `#f` (unconditional — always believed). During speculation, the assumption-id is the current speculation hypothesis.

```racket
;; Tagged entry for constraint store:
(struct tagged-constraint (constraint assumption-id) #:transparent)

;; Write: tag with current assumption
(define (add-constraint-tagged! c)
  (define aid (current-speculation-assumption))  ;; #f at depth 0
  (write-constraint-to-store! (tagged-constraint c aid)))
```

**Merge functions**: `merge-hasheq-union` and `merge-list-append` work unchanged — they accumulate tagged entries the same way they accumulate untagged entries. The tagging is transparent to accumulation.

**Read functions**: For now, reads return all entries (tagged + untagged). S(-1) retraction removes non-believed entries. Between S(-1) and S0, reads see only believed entries. At depth 0 (no speculation), all entries have `#f` assumption-id (always believed) — zero overhead.

### Phase 5: S(-1) Retraction Stratum

**Goal**: Implement the retraction stratum that cleans scoped cells before S0 fires.

**New cell**: `current-believed-assumptions-cell-id` — holds the set of currently-believed assumption IDs. Updated by `with-speculative-rollback` when an assumption is retracted.

**S(-1) retraction propagator**: Watches the believed-assumptions cell. When the set shrinks (assumption retracted):

```racket
(define (run-retraction-stratum!)
  (define believed (read-believed-assumptions))
  (define prev-believed (current-prev-believed-assumptions))
  (define retracted (set-subtract prev-believed believed))
  (unless (set-empty? retracted)
    ;; Clean all scoped cells
    (for ([cell-id (in-list scoped-cell-ids)])
      (retract-entries! cell-id retracted))
    (current-prev-believed-assumptions believed)))

(define (retract-entries! cell-id retracted-set)
  ;; Read current cell value, remove entries tagged with retracted assumptions
  (define current-val (cell-read cell-id))
  (define cleaned (remove-retracted current-val retracted-set))
  (when (not (equal? current-val cleaned))
    (cell-write! cell-id cleaned)))
```

For `merge-hasheq-union` cells: filter entries by `(not (set-member? retracted-set (tagged-entry-assumption-id entry)))`.

For `merge-list-append` cells: filter list elements similarly.

**Integration with stratified loop**: S(-1) runs at the START of each `run-stratified-resolution!` iteration, before S0:

```racket
(let loop ([fuel fuel] [meta-id trigger-meta-id])
  (when (> fuel 0)
    ;; S(-1): Retraction — clean scoped cells
    (run-retraction-stratum!)
    ;; S0: Type propagation (existing)
    (run-quiescence!)
    ;; S1: Readiness scan (existing, then replaced by Phase 8)
    (define actions (collect-ready-actions))
    ;; S2: Resolution commitment (existing)
    (execute-resolution-actions! actions)
    (when (unbox progress-box)
      (loop (sub1 fuel) meta-id))))
```

**Depth-0 fast path**: At speculation depth 0, no assumptions are retracted. `run-retraction-stratum!` checks `(set-empty? retracted)` and returns immediately. Zero overhead for the common case.

### Phase 6: Belt-and-Suspenders Retirement (Phase 5b Gate)

**Goal**: Remove transitional persistence mechanisms that are superseded by the persistent registry network (Phases 1-3) and S(-1) retraction (Phase 5).

**Precondition**: With S(-1) retraction handling scoped cells, TMS retraction handling value cells, and the persistent registry network holding registry state, both the network-box snapshot AND the Track 6 base-network pattern become redundant.

**What gets retired**:

1. **Network-box restore** in `save-meta-state`/`restore-meta-state!` — S(-1) retraction + TMS handles rollback.

2. **`current-persistent-base-network`** (Track 6 Phase 6) — the elab-network no longer needs to persist across commands. Registry cells live in the persistent registry network; the elab-network goes back to being fully per-command (fresh each time via `make-elaboration-network`).

3. **`reset-elab-network-command-state`** (Track 6 Phase 6) — the selective-reset function that preserved cell values while clearing propagators/metas/id-map. No longer needed when `reset-meta-store!` creates a fresh elab-network per command.

4. **`save-base-elaboration-network`** — no base network to save.

**Why these are safe to retire together**: Track 6's base-network pattern was transitional — it kept registry cells alive across commands by *not destroying the elab-network*. Track 7 replaces this with a cleaner separation: persistent state in the persistent registry network, ephemeral state in a fresh-per-command elab-network. The base-network pattern mixed lifecycle concerns (persistent registry cells + ephemeral meta cells in one network, requiring selective reset). The two-network architecture decomplects them.

**Belt-and-suspenders validation**: Run the full test suite with BOTH mechanisms active, comparing results. Then:
1. Disable network-box restore in `restore-meta-state!` → verify identical results
2. Remove `current-persistent-base-network` usage in `reset-meta-store!` (revert to fresh `make-elaboration-network` per command) → verify identical results
3. Remove `reset-elab-network-command-state` and `save-base-elaboration-network` → dead code

**Implementation finding (Phase 6a)**: `restore-meta-state!` CANNOT be fully retired in Track 7. TMS retraction handles cell value branches; S(-1) handles scoped cell entries. But **meta-info CHAMP and id-map are fields of `elab-network`**, not TMS cells. Metas created/solved during speculation need structural rollback that only the network-box restore provides. Full retirement requires making meta-info and id-map TMS-aware — scoped to Track 8 (Unification as Propagators) or a dedicated structural-state-as-cells workstream.

**What IS retired in Phase 6**: The Track 6 base-network pattern (per-command lifecycle, NOT speculation rollback):

**Changes to `reset-meta-store!`**: Remove the `current-persistent-base-network` branch. Always create a fresh `make-elaboration-network` per command. Registry cell reads come from the persistent network, not from persisted cells in the elab-network.

**`save-meta-state` / `restore-meta-state!`**: RETAINED — still needed for structural state (meta-info, id-map) rollback during speculation. Retirement deferred to when meta-info/id-map become TMS-aware cells.

**Phase 3b deferred items** (absorbed into Phase 6):

4. **Parameter write removal from `register-*!` functions**: Remove the `(current-X-registry (hash-set ...))` line from all ~22 register functions. Requires module-load-time built-in registrations to be replayed into the persistent network directly (either a separate init function or a registration queue that replays at network init time).

5. **Parameter fallback removal from `read-*` functions**: Remove the `(if (eq? v 'not-found) (current-X-registry) v)` pattern from all ~24 read functions. The persistent cell becomes the sole read path. Requires `test-support.rkt` to initialize a persistent network in all fixture parameterize blocks (replacing `[current-persistent-registry-net-box #f]` with an initialized network).

6. **batch-worker simplification**: Remove `save-macros-registry-snapshot` / `restore-macros-registry-snapshot!` (24 parameter saves/restores). The `current-persistent-registry-net-box` snapshot already captures all registry state atomically.

**Result**: `save-meta-state`/`restore-meta-state!` reduce from 1 box to 0 boxes. `reset-meta-store!` simplifies from conditional (base-network vs fresh) to unconditional fresh. All 24 macros registry parameters become vestigial (no writes, no reads). Speculation is fully managed by TMS + S(-1). Persistence is fully managed by the persistent registry network. The elab-network is purely ephemeral again — the clean architectural state.

### Phase 7: Callback Inlining + Resolution Purification

**Goal**: Replace 3 callback parameters with direct, pure function calls. Purify the resolution chain so that all functions from `solve-meta-core` through resolution produce `enet → enet*` (no box writes). This is the "hard thing first" — paying the purification cost here means Phase 8b simply wires pure functions into propagators.

Sub-phased: 7a (mechanical extraction), 7b (purification of writes and reads).

**Why Option A (full purification) over Option C (hybrid with wrappers)**: The D.3 self-critique initially proposed Option C (pure within L2, box-writing wrappers for legacy). On reflection, Option C perpetuates the imperative pattern — every new call site leans toward the `!`-suffix wrapper, and purity becomes "optional." Imperative patterns that persist become load-bearing; unraveling them later is harder than solving now. Option A makes purity the default and the box the exception (one entry point: `solve-meta!`). Principle alignment: Propagator Statelessness (structural, not discipline), Completeness Over Deferral (solve while context is fresh), Correct by Construction (pure functions can't diverge from the scheduler's copy). Imperativeness for performance, if needed, stays within tight local scopes that maintain data-in → data-out at their contract boundaries.

#### Phase 7a: Module Extraction

**Goal**: Extract resolution logic into `resolution.rkt`, eliminate 3 callback parameters. Imperative signatures preserved — this is the mechanical part.

**The callbacks exist to break circular deps**:
- `current-retry-unify` (metavar-store ← unify)
- `current-retry-trait-resolve` (metavar-store ← driver)
- `current-retry-hasmethod-resolve` (metavar-store ← driver)

**Approach**: Resolution functions (`try-monomorphic-resolve`, `try-parametric-resolve`, and the three resolution callbacks' bodies) move from driver.rkt to `resolution.rkt`. `execute-resolution-actions!` calls them directly. Callback parameters removed.

**Validation**: All tests pass with direct calls. No functional change — same behavior, different module structure.

#### Phase 7b: Resolution Chain Purification

**Goal**: Purify the resolution chain — all functions from `solve-meta-core` through resolution and their reads become `enet → enet*`. `solve-meta!` becomes the sole box-writing entry point.

**Call chain analysis (D.3 T1)**: Box writes occur at exactly 6 boundary functions. Everything below them (`unify-core`, `run-to-quiescence`, `elab-cell-write`, `collect-ready-*`) is already pure. The purification is mechanical: replace `(set-box! net-box (f (unbox net-box) ...))` with `(define enet* (f enet ...))` and thread forward.

**Write-path purification** — functions that write through boxes, purified to `enet → enet*`:

| Function | Current | Purified |
|----------|---------|----------|
| `solve-meta-core!` | writes meta-info + cell via box | `(solve-meta-core enet id solution) → enet*` |
| `write-constraint-to-store!` | writes constraint cell via box | `(write-constraint-to-store enet updated-c) → enet*` |
| `write-constraint-status-cell!` | writes status cell via box | `(write-constraint-status-cell enet cid status) → enet*` |
| `write-error-descriptor!` | writes error cell via box | `(write-error-descriptor enet meta-id desc) → enet*` |
| `execute-resolution-actions!` | imperative loop, box writes | `(execute-resolution-actions enet actions) → enet*` (for/fold) |
| `run-stratified-resolution!` | loop with box reads/writes | `(run-stratified-resolution enet trigger-meta-id) → enet*` |

**Read-path purification** — functions that read meta solutions through boxes, purified to read from threaded `enet`:

All meta-solution reading funnels through exactly 4 solution-getter functions. No box reading is scattered — all 12 consuming files (`zonk.rkt`, `unify.rkt`, `trait-resolution.rkt`, `typing-core.rkt`, `qtt.rkt`, `reduction.rkt`, etc.) go through these:

| Function | Current | Purified |
|----------|---------|----------|
| `meta-solution` | reads cell via `(unbox (current-prop-net-box))` | `(meta-solution-pure enet id) → Expr \| #f` |
| `meta-solved?` | reads cell via `(unbox (current-prop-net-box))` | `(meta-solved-pure? enet id) → boolean` |
| `level-meta-solution` | same two-path box pattern | `(level-meta-solution-pure enet id) → level \| #f` |
| `mult-meta-solution` | same two-path box pattern | `(mult-meta-solution-pure enet id) → mult \| #f` |

**Consuming functions within the resolution chain** get `enet`-accepting variants:

| Function | Used by | Purified |
|----------|---------|----------|
| `zonk` | Resolution functions (normalize type-args) | `(zonk-pure enet e) → Expr` — calls `meta-solution-pure` |
| `zonk-at-depth` | Constraint retry (normalize lhs/rhs) | `(zonk-at-depth-pure enet depth e) → Expr` |
| `normalize-for-resolution` | Trait/hasmethod resolution | `(normalize-for-resolution-pure enet e) → Expr` |
| `ground-expr?` (trait-resolution.rkt) | Readiness check in resolution | `(ground-expr-pure? enet e) → boolean` |

**Scope boundary**: Only the resolution chain uses the `-pure` variants. The rest of the codebase (elaboration, type-checking, pretty-printing) continues using the box-reading versions — `solve-meta!` syncs the box before and after the pure chain, so box-reading callers always see consistent state. The pure variants are for code running *within* `run-stratified-resolution` (and later, within L2 propagators) where the threaded `enet` is the source of truth.

**Resolution functions** (in `resolution.rkt`):

```racket
;; Pure: thread enet through all reads and writes
(define (resolve-trait-constraint enet dict-meta-id tc-info)
  (define trait-name (trait-constraint-info-trait-name tc-info))
  (define type-args
    (map (λ (e) (normalize-for-resolution-pure enet (zonk-pure enet e)))
         (trait-constraint-info-type-arg-exprs tc-info)))
  (cond
    [(not (andmap (λ (e) (ground-expr-pure? enet e)) type-args)) enet]
    [(or (try-monomorphic-resolve trait-name type-args)
         (try-parametric-resolve trait-name type-args))
     => (λ (dict-expr) (solve-meta-core enet dict-meta-id dict-expr))]
    [else (write-error-descriptor enet dict-meta-id ...)]))

;; Same pattern for retry-unify-constraint, resolve-hasmethod-constraint
```

**`solve-meta!` becomes the sole box-writing entry point**:

```racket
;; solve-meta! is the ONLY box-writing entry point
(define (solve-meta! id solution)
  (define net-box (current-prop-net-box))
  (define enet (unbox net-box))
  (define enet* (solve-meta-core enet id solution))
  (define enet** (run-stratified-resolution enet* id))
  (set-box! net-box enet**))
```

The rest of the codebase (elaboration, type-checking) calls `solve-meta!` which unboxes, calls the pure chain, and reboxes. This is the single point of impurity — justified because elaboration is inherently sequential (one expression at a time) and the box is the interface between the sequential elaborator and the functional network.

**Validation**: Belt-and-suspenders: compare `enet*` from pure chain against box-mediated result for 1 full suite run. The existing `!`-suffixed functions can temporarily coexist as thin wrappers (`unbox → pure → rebox`) during validation, then be removed or deprecated.

### Phase 8a: Readiness Propagators (L1)

**Goal**: Replace the 6 O(total) S1 scanning functions with per-constraint fan-in readiness propagators.

**Prerequisite: Scanning function audit**. Before implementing readiness propagators, produce a line-by-line audit of the 6 `collect-ready-*` scanning functions (`collect-ready-constraints-via-cells`, `collect-ready-constraints-for-meta`, `collect-ready-traits-via-cells`, `collect-ready-traits-for-meta`, `collect-ready-hasmethods-via-cells`, `collect-ready-hasmethods-for-meta`). The audit identifies every readiness condition (ground-check, status filter, constraint-type dispatch) that the L1 propagators must replicate. Uncovered conditions are correctness risks in Phase 8c loop elimination.

**New infrastructure**:

**Ready-queue channel cell**: A channel cell (see §2.6 taxonomy) that accumulates action descriptors for constraints whose dependencies became ready. Entries are assumption-tagged for on-network produce-consume:

```racket
(define current-ready-queue-cell-id (make-parameter #f))
;; Merge: list append (monotonic accumulation of ready actions)
;; Lifecycle: channel cell — L1 writes, L2 reads + retracts, S(-1) cleans
```

**Threshold-cell composition for one-shot readiness**: The readiness detection uses a two-stage propagator composition that guarantees each constraint fires at most once, structurally (via lattice monotonicity) rather than operationally (via runtime guards):

1. **Fan-in propagator** (N deps → 1 threshold cell): Watches all dependency cells. When all are non-⊥, writes `#t` to a per-constraint **threshold cell**.
2. **Threshold cell** (boolean, one-shot): Merge is `(λ (old new) #t)`. Once ⊤, stays ⊤. This cell transitions exactly once: ⊥ → ⊤.
3. **Readiness propagator** (1 threshold cell → ready-queue): Watches the threshold cell. Fires on the single ⊥ → ⊤ transition. Writes an assumption-tagged action descriptor to the ready-queue channel cell.

```racket
(define (register-trait-constraint-with-readiness! meta-id info dep-cell-ids)
  ;; ... existing registration ...

  ;; Stage 1: Fan-in propagator → threshold cell
  ;; One boolean threshold cell per constraint. Merge: (λ _ #t) — one-shot.
  (define-values (net* threshold-cid)
    (net-new-cell net #f (lambda (old new) #t)))

  (define total-deps (length dep-cell-ids))

  ;; Termination: Level 1 (Tarski). Each dep transitions at most once
  ;; (⊥ → solved). Threshold cell transitions at most once (⊥ → ⊤).
  (net-add-propagator!
    dep-cell-ids  ;; fan-in: ALL deps as inputs
    (list threshold-cid)  ;; single output: threshold cell
    (lambda (net . dep-vals)
      (define n-ground (count (lambda (v) (not (prop-type-bot? v))) dep-vals))
      (if (= n-ground total-deps)
          (net-cell-write net threshold-cid #t)
          net)))

  ;; Stage 2: Readiness propagator (threshold cell → ready-queue)
  ;; Fires exactly once — when threshold transitions ⊥ → ⊤.
  ;; The lattice IS the guard: no runtime status checks needed.
  (net-add-propagator!
    (list threshold-cid)  ;; single input: threshold cell
    (list (current-ready-queue-cell-id))  ;; output: ready-queue channel
    (lambda (net threshold-val)
      (if threshold-val
          (let ([assumption-id (make-fresh-assumption!)])
            (net-cell-write net (current-ready-queue-cell-id)
                            (list (tagged-action assumption-id
                                    (action-resolve-trait meta-id info)))))
          net))))
```

**Why threshold-cell composition instead of lifecycle state machine?**

The external critique (C2) identified that the original countdown-latch design could produce duplicate ready-queue entries if the readiness propagator fires again in a subsequent BSP round. Two solutions were considered:

- **Lifecycle state machine**: Track constraint status (pending → ready → queued → resolved). Readiness propagator checks `status != queued` before writing. Operational guarantee — correctness depends on runtime checks.
- **Threshold-cell composition**: Interpose a boolean cell that transitions once. The lattice enforces the one-shot property. Structural guarantee — correctness is a property of the data, not the code.

The threshold-cell approach is more propagator-first: the guarantee is lattice monotonicity, not a conditional branch. It composes better (threshold cells are observable — "how many constraints are ready?" = count of non-⊥ threshold cells). And it's simpler to implement (one cell + two propagators per constraint, no status tracking for the firing guard).

Constraint status (pending/resolved/failed) is still tracked in the existing constraint-info status field for error reporting and observability, but the ready-queue write guard is structural.

**Propagator count**: 2 propagators + 1 threshold cell per constraint. For 50 constraints: 100 propagators + 50 cells. The threshold cells are trivial (boolean, no TMS). The fan-in propagator count is unchanged (1 per constraint, not 1 per dependency).

**S1 replacement**: Instead of scanning, L1 readiness propagators write to the ready-queue channel cell. S1 disappears as a separate phase — readiness detection is now structural (propagator-driven), not imperative (scan-driven).

**Ordering**: Readiness propagators are tagged as L1 layer. Under the hybrid BSP/Gauss-Seidel scheduler, they fire after S0 reaches quiescence. The ready-queue accumulates during L1's BSP rounds. L2 reads the queue after L1 quiesces. This preserves stratum ordering.

**Belt-and-suspenders**: During Phase 8a, run BOTH the old scanning functions and the ready-queue, assert identical action descriptor sets. **Retirement criteria (D.3 T4)**: Scanning functions removed when: (a) readiness propagators produce identical action descriptor sets for ≥1 full suite run with 0 divergences, AND (b) Phase 8b is implemented (L2 consuming the ready-queue, confirming end-to-end correctness).

#### Phase 8a Prerequisite: Scanning Function Audit (completed)

Line-by-line audit of the 6 `collect-ready-*` functions identifying every readiness condition that L1 propagators must replicate.

**Constraint readiness** (`collect-ready-constraints-via-cells`, line ~666):
- Scans all constraints in `(read-constraint-store)` (list from cell)
- Ready when: status == `'postponed` AND non-empty `cell-ids` AND at least one cell non-bot/non-top
- Produces: `(action-retry-constraint c)`

**Constraint readiness — targeted** (`collect-ready-constraints-for-meta`, line ~682):
- Scans wakeup registry for the just-solved meta
- Ready when: status == `'postponed` (no cell-state check — trusts wakeup trigger)
- Produces: `(action-retry-constraint c)`

**Trait readiness** (`collect-ready-traits-via-cells`, line ~689):
- Scans `(read-trait-cell-map)` — dict-meta-id → cell-ids
- Ready when: dict meta NOT solved AND tc-info exists AND at least one type-arg cell non-bot/non-top
- Produces: `(action-resolve-trait dict-id tc-info)`

**Trait readiness — targeted** (`collect-ready-traits-for-meta`, line ~707):
- Scans trait wakeup map for the just-solved meta
- Ready when: dict meta NOT solved AND tc-info exists (no cell-state check)
- Produces: `(action-resolve-trait dict-id tc-info)`

**HasMethod readiness** (`collect-ready-hasmethods-via-cells`, line ~729):
- Scans `(read-hasmethod-cell-map)` — hm-meta-id → cell-ids
- Ready when: hm meta NOT solved AND hm-info exists AND at least one dep cell non-bot/non-top
- Produces: `(action-resolve-hasmethod hm-id hm-info)`

**HasMethod readiness — targeted** (`collect-ready-hasmethods-for-meta`, line ~717):
- Scans hasmethod wakeup map for the just-solved meta
- Ready when: hm meta NOT solved AND hm-info exists (no cell-state check)
- Produces: `(action-resolve-hasmethod hm-id hm-info)`

**Critical asymmetry in orchestration** (`run-stratified-resolution!`):
- Constraints: either `-via-cells` OR `-for-meta` (mutually exclusive, based on network availability)
- Traits and HasMethods: BOTH `-via-cells` AND `-for-meta` ALWAYS called (no mutual exclusion)
- Reason: cell scan catches transitive propagations; wakeup catches immediate targeted wakeup. Both are fast.

**Readiness lattice**: A dependency cell is "ready" when `(not (prop-type-bot? v)) AND (not (prop-type-top? v))` — i.e., the cell holds a concrete type value, neither unsolved (bot) nor contradicted (top).

**Pre-filter**: `run-retraction-stratum!` (S(-1)) removes retracted-assumption-tagged entries from all scoped cells BEFORE S1 scans. This is the only implicit filtering outside the 6 functions.

**What L1 propagators must replicate**:
1. Per-constraint fan-in: watch all dependency cells, fire when all non-bot (constraints) or any non-bot (traits/hasmethods)
2. Unsolved-meta guard: don't fire for already-solved dict/hm metas
3. Info existence: skip if constraint/trait/hasmethod info was cleared
4. Assumption tagging: read functions unwrap tags transparently; propagators produce tagged entries
5. Dual-path assembly: for traits/hasmethods, both cell-driven and wakeup-driven readiness must be captured

### Phase 8b: Resolution Propagators (L2)

**Goal**: Replace the imperative `execute-resolution-actions!` loop with resolution propagators that fire when the ready-queue has entries.

**Current architecture** (post-Phase 8a):
```
S0: run-to-quiescence (propagators fire, readiness propagators populate ready-queue)
S1: read ready-queue (cell read — O(1))
S2: execute-resolution-actions! (imperative loop over action descriptors, calls resolution functions)
    → may call solve-meta! → sets progress-box → outer loop iterates
```

**Target architecture**:
```
Layered network quiescence:
  S(-1): retraction propagators fire (clean scoped cells)
  S0:    type propagators fire (solve metas)
  L1:    readiness propagators fire (populate ready-queue)
  L2:    resolution propagators fire (consume ready-queue, call resolution logic)
         → resolution writes to meta cells → perturbs S0 → cascade continues
```

**Resolution propagator**: A single propagator that watches the ready-queue channel cell. Its fire function IS the resolution logic. Consumption uses the on-network channel cell pattern (§2.6): after processing each entry, retract its assumption so S(-1) cleans it on the next cycle.

**Implementation note (D.2 C1): snapshot-then-consume**. The resolution propagator must snapshot the ready-queue at the start of its L2 BSP round and process the snapshot, rather than iterating the live cell value. This prevents inconsistency if assumption retraction (within the same fire function) triggers S(-1) cleanup that mutates the cell value under iteration. The snapshot is a simple `let` binding of the cell value before the `for` loop:

```racket
(define (install-resolution-propagator! ready-queue-cell-id)
  ;; Termination: Level 2 (well-founded). Each resolution either produces a
  ;; concrete dictionary (terminal) or creates metas at strictly smaller type
  ;; depth. Type depth is well-founded → finite resolution chains.
  (net-add-propagator!
    (list ready-queue-cell-id)
    (lambda (net queue-val)
      ;; Snapshot: process a frozen copy, not the live cell
      (define entries (if (list? queue-val) queue-val '()))
      (for/fold ([net net]) ([tagged-entry (in-list entries)])
        (define action (tagged-action-value tagged-entry))
        (define assumption-id (tagged-action-assumption-id tagged-entry))
        ;; Execute resolution
        (match action
          [(action-retry-constraint c)
           (retry-unify-constraint! net c)]
          [(action-resolve-trait dict-meta-id tc-info)
           (resolve-trait-constraint! net dict-meta-id tc-info)]
          [(action-resolve-hasmethod hm-meta-id hm-info)
           (resolve-hasmethod-constraint! net hm-meta-id hm-info)])
        ;; Consume: retract the entry's assumption → S(-1) will clean it
        (net-retract-assumption net assumption-id)))))
```

**Scheduler implementation (D.2 clarification)**: `run-to-layered-quiescence` is a **new function** in `propagator.rkt`, distinct from the existing `run-to-quiescence`. It calls `run-to-quiescence` per-layer. Layers are a new first-class concept in `propagator.rkt`: propagators get a `layer` field (integer: -1, 0, 1, 2), and the scheduler partitions the worklist by layer, processing each in order. The existing `run-to-quiescence` is unchanged and remains available for single-layer use.

**On-network queueing lifecycle**: The ready-queue is a channel cell (§2.6 taxonomy). The full lifecycle:
1. **L1 (produce)**: Readiness propagator writes a tagged action to the channel cell
2. **L2 (consume)**: Resolution propagator reads the action, executes resolution, retracts the entry's assumption
3. **S(-1) (clean)**: On the next cycle, the retraction stratum removes retracted entries from the channel cell

All queueing state lives on the network. No off-network clearing. The channel cell pattern composes naturally with the layered scheduler — production (L1) and consumption (L2) happen in different strata, with S(-1) garbage collection.

**Feedback mechanism**: Resolution may call `solve-meta!`, which writes to a meta cell. This cell write is detected by the network's dirty-flag mechanism — the network is NOT quiescent, so propagation continues. The readiness propagators may fire again (new metas solved → new constraints ready). The cycle continues until the network reaches true quiescence across all layers.

**The progress-box becomes unnecessary**: Currently, `execute-resolution-actions!` sets `progress-box` when `solve-meta!` is called, and the outer loop checks it. With L2 as a propagator, progress is detected structurally — a cell write during L2 means the network isn't quiescent, so `run-to-quiescence` continues. No box, no loop variable.

**Re-entrancy safety**: Currently `current-in-stratified-resolution?` prevents recursive `run-stratified-resolution!` calls when L2 callbacks call `solve-meta!`. With the propagator architecture, this is structural — `solve-meta!` writes to a cell, which triggers S0 propagators within the SAME quiescence run. No re-entrancy because there's no recursive function call; it's all within the network scheduler.

**Stratum ordering**: The hybrid BSP/Gauss-Seidel scheduler (§2.5) processes layers in order:
1. Fire all S(-1) retraction propagators to BSP fixpoint
2. Fire all S0 type propagators to BSP fixpoint
3. Fire all L1 readiness propagators to BSP fixpoint
4. Fire all L2 resolution propagators to BSP fixpoint
5. If any L2 propagator wrote to an S0 cell (meta solution), go back to step 1

Intra-stratum: BSP (all dirty propagators in the layer fire per round — safe by CALM, as intra-stratum propagation is monotone). Inter-stratum: Gauss-Seidel (each layer reaches fixpoint before the next activates — required because higher strata need lower strata's complete fixpoint).

**Implementation approach**: Tag propagators with a layer identifier when created:
- S(-1) propagators: layer = -1 (retraction)
- S0 propagators: layer = 0 (type propagation, unification)
- L1 propagators: layer = 1 (readiness detection)
- L2 propagators: layer = 2 (resolution commitment)

The scheduler processes layers in order, re-entering from the lowest layer when a higher layer writes to a lower layer's cells.

### Phase 8c: Stratified Loop Elimination

**Goal**: Remove `run-stratified-resolution!` entirely. The hand-written loop becomes layered network quiescence.

**What disappears**:
- `run-stratified-resolution!` function (the hand-written S0→S1→S2 loop)
- `current-in-stratified-resolution?` parameter (re-entrancy guard)
- `current-stratified-progress-box` parameter (progress detection)
- `stratified-resolution-fuel` constant (loop fuel)
- 6 `collect-ready-*` scanning functions (replaced by L1)
- `execute-resolution-actions!` function (replaced by L2)

**What `solve-meta!` becomes**:

```racket
;; BEFORE:
(define (solve-meta! id solution)
  (solve-meta-core! id solution)
  (unless (current-in-stratified-resolution?)
    (run-stratified-resolution! id)))

;; AFTER:
(define (solve-meta! id solution)
  (solve-meta-core! id solution)
  ;; Cell write triggers network propagation automatically.
  ;; No explicit loop call needed — the network scheduler handles it.
  (run-layered-quiescence!))
```

**`run-layered-quiescence!`**: The new entry point that replaces both `run-to-quiescence` (S0 only) and `run-stratified-resolution!` (S0+S1+S2). It runs the full layered scheduler:

```racket
(define (run-layered-quiescence!)
  ;; Run the network scheduler with layer priorities:
  ;; S(-1) → S0 → L1 → L2, re-entering from S(-1) on feedback
  (define net (unbox (current-prop-net-box)))
  (define net* (run-to-layered-quiescence net))
  (set-box! (current-prop-net-box) net*))
```

**Fuel / termination**: The hand-written loop had explicit fuel (100 iterations). The layered scheduler has the network's native termination: quiescence = no dirty cells across any layer. For pathological cases (infinite solving cycles), the scheduler can track iteration count and bail at a configurable threshold — same semantics, but structural rather than a loop counter.

**The architectural payoff**: After Phase 8c, constraint resolution is a structural property of the propagator network. Adding a new constraint type (e.g., a new kind of trait constraint, or a narrowing constraint) means adding a readiness propagator (L1) and a resolution propagator (L2). No changes to a hand-written loop. No new scanning function. No new callback. The network handles scheduling, ordering, and termination.

**Belt-and-suspenders**: During Phase 8b, keep `run-stratified-resolution!` as a fallback. Compare its results against layered quiescence for every `solve-meta!` call. **Retirement criteria (D.3 T4)**: Phase 8c is the explicit retirement gate. Old path removed when: (a) layered scheduler produces identical results for ≥1 full suite run with 0 divergences, AND (b) adversarial benchmark (Q5) passes.

---

## 6. Design: WS-A — QTT Multiplicity Cells

### Phase 9: Mult Lattice + Cross-Domain Bridges

**Goal**: Bring QTT multiplicity operations into the elaboration network.

**Mult lattice**: `m0 < m1 < mw` (erased < linear < unrestricted). Already implemented as a comparison function in `qtt.rkt`. Track 7 adds a merge function and cell infrastructure.

```racket
(define (mult-lattice-merge old new)
  (cond
    [(eq? old 'mw) 'mw]
    [(eq? new 'mw) 'mw]
    [(eq? old 'm1) (if (eq? new 'm0) 'm1 new)]
    [(eq? new 'm1) 'm1]
    [else old]))  ;; both m0
```

**Cross-domain bridge propagators**: When a type metavariable is solved, its QTT usage annotations may constrain multiplicity metavariables. The bridge propagator connects type cells to mult cells:

```racket
;; Type cell solution triggers mult constraint checking
(net-add-cross-domain-propagator!
  type-cell-id
  mult-cell-id
  (lambda (type-val) (extract-mult-constraint type-val))  ;; α: type → mult
  (lambda (mult-val) mult-val))                           ;; γ: identity
```

**Concrete example**: Consider `spec f {A : Type} (x : A) -[m1]-> A`. When the type meta for `A` is solved to `Int`, the bridge propagator fires: `extract-mult-constraint` examines the Pi's multiplicity annotation and returns `m1` (linear). This writes `m1` to the mult cell associated with the usage site. If the type contains an unsolved mult-meta (e.g., `(Pi (x : Int) ?m B)` where `?m` is still `type-bot`), the bridge doesn't fire — the type isn't fully ground. The bridge is unidirectional: type → mult. Mult → type influence flows through the existing QTT checker in `qtt.rkt`, not through bridge propagators.

**Scope**: Multiplicity cells already exist (Track 4 — `elab-fresh-mult-cell`). Track 7 adds the lattice merge function and bridge propagators so that type-level reasoning can inform multiplicity inference.

---

## 7. Risk Analysis

### High risk: Persistent network lifecycle (WS-C Phase 1-2)

The persistent network must survive across commands but be correctly scoped to files. batch-worker must snapshot/restore it. Module loading must initialize it.

**Mitigation**: Follow the Track 5 pattern for `current-definition-cells-content` — proven lifecycle management. Belt-and-suspenders validation during Phase 2.

### Medium risk: S(-1) retraction correctness (WS-B Phase 5)

S(-1) must remove exactly the entries tagged with retracted assumptions, no more, no less. Over-retraction loses valid constraints; under-retraction leaves orphaned entries.

**Mitigation**: Belt-and-suspenders comparison against current network-box restore (Phase 6). Existing speculation test suite (Track 4/6) exercises the exact scenarios. Depth-0 fast path ensures zero overhead for the common case. Note: the D.2 external critique suggested targeted retraction (reverse index from assumption → affected cells). With only 14 scoped cells and depth-0 fast path covering ~95% of commands, this is premature optimization. If Phase 10 profiling reveals S(-1) as a hotspot in speculation-heavy workloads, a reverse index can be added as a targeted optimization.

### Medium risk: Readiness propagator ordering (WS-B Phase 8)

Readiness propagators fire during S0 quiescence. If a readiness propagator writes to the ready-queue before a dependency meta is fully propagated, it may produce a stale action descriptor.

**Mitigation**: Readiness propagators fire AFTER the network reaches quiescence for the triggering write. The ready-queue is read by S1, which runs after S0 quiesces. The stratum ordering guarantees consistency.

### Medium risk: Resolution propagators + loop elimination (WS-B Phase 8b-8c)

Converting `execute-resolution-actions!` from an imperative loop to a propagator changes the control flow of constraint resolution. The re-entrancy semantics change from explicit guards (`current-in-stratified-resolution?`) to structural cell-write detection.

**Mitigation**: Belt-and-suspenders during Phase 8b — run BOTH the hand-written loop and the layered scheduler, compare results. Phase 8c removes the loop only after validation. The existing Track 4/6 speculation test suite exercises the exact re-entrancy scenarios.

### Medium risk: Layered scheduler implementation (WS-B Phase 8b)

The Gauss-Seidel scheduler across 4 layers (S(-1), S0, L1, L2) with feedback from L2→S(-1) is new infrastructure. The scheduler must respect layer ordering and correctly detect when a higher layer's write perturbs a lower layer.

**Mitigation**: The pattern is proven — effect-bridge propagators (Architecture A+D) already use priority-based scheduling within `run-to-quiescence`. Track 7 extends this to 4 explicit layers. The scheduler extension can be validated independently with unit tests before wiring into constraint resolution.

### Medium risk: Callback inlining + resolution purification (WS-B Phase 7)

Module restructuring plus resolution chain purification. The resolution functions move to a new module AND are rewritten as pure `enet → enet*` functions. Call chain analysis (D.3 T1) identified exactly 6 boundary functions that need purification — the transformation is mechanical (replace box read/write with threading) but touches many call sites.

**Mitigation**: The existing call chain is well-mapped (D.3 T1 analysis). `run-to-quiescence`, `unify-core`, `elab-cell-write` are already pure — purification only affects the 6 boundary functions. Belt-and-suspenders: compare pure chain result against box-mediated result for 1 full suite run. Track 6 Phase 8d deep audit confirmed callbacks are vestigial; the purification is a natural completion of that simplification.

### Low risk: QTT multiplicity cells (WS-A Phase 9)

Tiny lattice (3 elements). Cross-domain bridges follow the proven session↔effect bridge pattern.

**Mitigation**: Track 4 already created mult cells. Track 7 adds merge function and bridges — incremental.

---

## 7b. Expected Performance Characteristics

### Current baseline (post-Track 6)

| Metric | Value | Source |
|--------|-------|--------|
| Total suite time | 235.2s | Track 6 Phase 11 |
| Test count | 7154 | Track 6 Phase 11 |
| Per-command cell creations | ~29 registry + ~12 infra = ~41 | `register-macros-cells!` + `register-warning-cells!` + `register-narrow-cells!` |
| Cell creations per suite | ~7154 × 41 ≈ 293K | Estimated from test count × per-command |
| S1 scanning per `solve-meta!` | O(total constraints) × 6 functions | `collect-ready-*` in metavar-store.rkt |
| Speculation save/restore | 1 network box + TMS retraction | Track 6 Phases 2+3, 4 |

### Per-phase expected impact

**WS-C: Persistent Registry Cells (Phases 1-3)**

| Operation | Before | After | Change |
|-----------|--------|-------|--------|
| Registry cell creation | 29 cells × ~7154 commands ≈ 208K/suite | 29 cells × 1 (per file) ≈ 29/file | ~7000× fewer allocations |
| Registry cell-id lookup | Parameter read per command | Stable reference (no lookup) | Eliminates parameter overhead |
| Register write path | Param write + cell write (dual) | Cell write only | 1 write instead of 2 |
| Parameter write overhead | 24 `hash-set` per registration | 0 | Eliminated |
| Bridge propagator cost | N/A | 29 bridge propagators per command (fire once) | New cost, but cheaper than 29 cell recreations |
| batch-worker snapshot | Save/restore 24+ parameters | Save/restore 1 box pointer | Simpler, atomic |

**Net effect**: Significant reduction in per-command overhead. The ~293K cell creations per suite drop to ~29 per file plus bridge propagator wiring. The dual-write elimination removes ~50% of registration write cost. Bridge propagators are lazy (fire once on initial sync) — cheaper than eager cell recreation + parameter seeding.

**WS-B: Stratified Retraction + Stratified Prop-Net (Phases 4-8c)**

| Operation | Before | After | Change |
|-----------|--------|-------|--------|
| S1 readiness scan | O(total constraints) × 6 functions per cycle | O(1) ready-queue read | Orders of magnitude for constraint-heavy commands |
| Readiness detection | Scan all, filter ready | Fan-in propagator fires on dep change | O(changed) not O(total) |
| Readiness check per constraint | Iterate dep list, check each | Countdown latch: compare `count == N` | O(1) vs O(deps) |
| Resolution dispatch | Callback indirection (3 parameter reads + guard checks) | Direct function call (Phase 7) → propagator fire (Phase 8b) | Eliminates indirection |
| Speculation rollback (scoped cells) | Network box restore (copy entire network snapshot) | S(-1) retraction (remove tagged entries from affected cells) | Proportional to speculated entries, not total network size |
| Speculation depth-0 overhead | Network box save (snapshot entire network) | No-op (no assumptions to track) | Eliminated for common case |
| Stratified loop fuel | Fixed 100 iterations, checked per cycle | Layered quiescence (structural termination) | Correct by construction |
| Progress detection | Box read + set per cycle | Dirty-flag on network (structural) | Eliminates box |

**Net effect**: The readiness scan elimination is the biggest win — currently O(total constraints) per `solve-meta!` cycle, which compounds for commands with many constraints. For a command with 50 constraints and 10 resolution cycles, that's 50 × 6 × 10 = 3000 scans. With L1 readiness propagators, it's 50 fan-in propagators that fire O(1) when deps change. The scanning functions become dead code.

S(-1) retraction for speculation is proportional to entries created under the retracted assumption, not to total network size. For a typical speculative branch creating 3-5 constraints, retraction touches 3-5 entries. The current network-box restore copies the entire network snapshot regardless of speculation size.

**WS-A: QTT Multiplicity Cells (Phase 9)**

Minimal performance impact. 3-element lattice, bridge propagators fire at most once per meta solve. The mult cell infrastructure already exists (Track 4); Track 7 adds merge + bridges.

### Performance risk factors

1. **Bridge propagator wiring per command**: 29 bridge propagators created per command. Each is a simple one-input propagator that fires once (initial sync from persistent cell). The cost is ~29 `net-add-propagator!` calls — comparable to the current ~29 `register-macros-cells!` cell creations, but the propagators are simpler (no parameter seeding, no cell-id parameter writes).

2. **Fan-in propagator memory**: One propagator object per constraint. For commands with hundreds of constraints (e.g., complex trait resolution), this is hundreds of propagator objects in the network. The CHAMP-based network handles this efficiently, but measure in Phase 0.

3. **Assumption tagging overhead**: Every scoped cell write gets an assumption-id field. At depth 0 (common case), this is `#f` — a single cons cell added per entry. Track 4's depth-0 fast path precedent suggests negligible overhead.

4. **Layered scheduler overhead**: The 4-layer Gauss-Seidel scheduler iterates layers in order, checking for dirty propagators in each. For layers with no dirty propagators (common for S(-1) at depth 0), the check is O(1). The BSP within each layer is the existing `run-to-quiescence` mechanism — no new overhead within a layer.

5. **Channel cell retraction overhead**: Each consumed ready-queue entry requires an assumption retraction + S(-1) cleanup. For typical commands with 5-20 resolved constraints per solve cycle, this is 5-20 retraction operations. The retraction itself is a set-subtract on the assumption set (O(log n) in CHAMP).

### Performance targets

| Metric | Target | Rationale |
|--------|--------|-----------|
| Suite wall time | ≤ 250s (≤ 6% regression from 235.2s) | Track 5's +14% was acceptable; Track 7 adds infrastructure but removes scanning overhead |
| Per-command overhead | ≤ current (no regression) | Bridge propagators ≤ cell recreation cost |
| S1 scan elimination | Measurable improvement for constraint-heavy tests | Directly proportional to constraint count |
| Speculation depth-0 | Zero new overhead | Fast path: no assumptions, S(-1) is no-op |
| Adversarial benchmark | Layered scheduler ≤ 1.5× hand-written loop | Conservative target; structural advantages may yield improvement |

### Measurement approach

Phase 0 captures the baseline. Each subsequent phase runs the full suite with timing recorded to `timings.jsonl`. Per-file regressions trigger investigation (>2× rolling median AND median >3s). Suite-level regression >15% triggers investigation before proceeding.

The adversarial benchmark (§13 Q5) provides a focused measurement of the scheduler and readiness propagator performance independent of the broader suite.

---

## 8. Learnings from Prior Tracks Applied Here

### From Track 6 PIR: Context loss causes architectural divergence

Track 6's 7b-c sync-back pattern was implemented without the context of Track 5's persistence model. **Before each phase, re-read this design doc and the audit.** Plan files capture WHAT, not WHY.

### From Track 6 PIR: "Dual-write elimination" was the wrong framing

The parameter + cell writes serve different purposes (persistence + propagation). Track 7 WS-C eliminates the parameter by making cells persistent — this is the correct framing. We're not "eliminating writes"; we're "unifying persistence into the cell layer."

### From Track 5 PIR: Belt-and-suspenders is standard practice

Every migration phase keeps both old and new paths active. Phase 6 (retirement) is the explicit gate where the old path is removed after validation.

### From Track 4 PIR: Depth-0 fast path is essential

TMS cells add zero overhead at speculation depth 0 thanks to the fast path. S(-1) retraction must have the same property: at depth 0, no assumptions are retracted, so the stratum is a no-op.

### From Track 6 PIR: Lazy initialization > mandatory initialization

The ATMS lazy-init fix taught us that infrastructure should work regardless of entry path. The persistent network should be lazily initialized if `process-command` is called without prior `init-persistent-registry-network!`.

### From Stratified Architecture Audit: Retraction is aggregation's dual

The same mathematical structure (stratified fixpoint semantics) underlies both NAF-LE aggregation and TMS retraction. S(-1) is not a new theory — it's a known structure applied to the dual problem.

---

## 9. Principle Alignment (D.3 Self-Critique)

Grounded in: DESIGN_PRINCIPLES.org, DEVELOPMENT_LESSONS.org, DESIGN_METHODOLOGY.org, GÖDEL_COMPLETENESS.org, POST_IMPLEMENTATION_REVIEW.org, Track 4/5/6 PIRs.

### Alignment summary

| Principle | Alignment | Notes |
|-----------|-----------|-------|
| Propagator-First Infrastructure | ✅ Strong | Core purpose: cells become the persistent store; callbacks → propagators; scans → readiness cells |
| Stratified Propagator Networks | ✅ Strong | Direct implementation: S(-1)/S0/L1/L2 with BSP/Gauss-Seidel |
| Correct by Construction | ✅ Strong | Threshold cells (lattice guards fire-once), structural retraction, depth-0 fast path |
| Data Orientation | ✅ Strong | Action descriptors (free monad), assumption sets, channel cell produce-consume |
| Gödel Completeness | ✅ Strong | Per-layer termination levels stated; cross-layer composition sound |
| Propagator Statelessness | ✅ Strong (after D.2+D.3) | D.2: countdown-latch box → threshold cell. D.3: resolution chain purified (Option A, §15 T1) |
| Decomplection | ✅ Strong | Clean separation: persistent registries vs ephemeral inference state |
| Simplicity of Foundation | ⚠️ Moderate tension | Two networks justified; scaling assumption should be explicit (§15 T2) |
| First-Class by Default | ⚠️ Partial gap | Constraint status not a cell; acceptable for Track 7, Track 10 concern (§15 T3) |

### Resolved tensions (from D.2)

1. **Two-network complexity** — **RESOLVED**: Two networks is the right design. Bridge propagators (Galois connections) provide clean cross-network integration. Scaling assumption documented in §15 T2.

2. **Scoped cell tagging overhead**: Depth-0 fast path: assumption-id is `#f`, negligible. Track 4 precedent confirms.

3. **Readiness propagator count** — **RESOLVED**: Threshold-cell composition (D.2 revision). 2 propagators + 1 threshold cell per constraint. Fire-once is structural (lattice monotonicity), not operational.

4. **Layered scheduler complexity** — **RESOLVED**: Hybrid BSP/Gauss-Seidel justified by CALM. Scheduler is a new function in `propagator.rkt` (D.2 clarification). Phase 0 adversarial benchmark validates empirically.

5. **Loop elimination completeness** — **RESOLVED**: Scanning function audit added as Phase 8a prerequisite (D.2). Phase 8c is explicit retirement gate for hand-written loop.

6. **Gödel Completeness per layer**: Termination levels in progress tracker. Cross-layer feedback: well-founded measure (type depth × unsolved meta count). Fuel retained as defense-in-depth.

### Open tensions (D.3 — see §15 for full analysis)

**T1. Resolution propagator purity** — **RESOLVED (Option A)**: The entire resolution chain is purified in Phase 7. Six boundary functions are made pure (`enet → enet*`); `solve-meta!` is the sole box-writing entry point. See §15 T1 and Phase 7 design.

**T2. Two-network scaling assumption** (Medium priority): The persistent network is justified while it remains small and static (~29 cells). If future tracks grow it, unification into a single network with lifecycle-tagged cells is the migration path. See §15 T2.

**T3. Constraint status as cell value** (Low priority): Constraint status (pending/resolved/failed) remains a struct field, not a cell. Track 10 (LSP) will want to observe constraint lifecycle for real-time diagnostics. See §15 T3.

**T4. Belt-and-suspenders retirement criteria** (Medium priority): Phases 8a and 8b have belt-and-suspenders validation but implicit retirement. Phase 8c should be named as the explicit retirement gate. See §15 T4.

**T5. Acceptance file must exercise multi-command patterns** (Medium priority): Track 7 doesn't add syntax, but changes infrastructure under existing syntax. The acceptance file must test define-then-use across commands. See §15 T5.

**T6. Test infrastructure divergence** (Low priority): Track 5 PIR lesson — `test-support.rkt` parameterize block must include `current-persistent-registry-net-box`. Pipeline checklist (`.claude/rules/pipeline.md` § "New Racket Parameter") covers this, but worth explicit callout in Phase 1. See §15 T6.

---

## 10. Files Modified

| File | Phase | Changes |
|------|-------|---------|
| `metavar-store.rkt` | 1, 4, 5, 7b, 8a-c | Persistent network init, assumption tagging, S(-1) stratum, purified `solve-meta-core`/`run-stratified-resolution`/solution-getters, ready-queue, resolution propagator, loop elimination |
| `macros.rkt` | 2, 3 | Cell persistence migration, dual-write elimination |
| `warnings.rkt` | 2, 3, 4 | Cell persistence migration, assumption tagging |
| `global-constraints.rkt` | 2, 4 | Cell persistence migration, assumption tagging |
| `driver.rkt` | 1, 3, 7a, 8c | Persistent network lifecycle, dual-write removal, callback elimination, solve-meta! simplification |
| `infra-cell.rkt` | 4, 9 | Assumption-tagged entries, mult lattice merge |
| `propagator.rkt` | 8b, 8c | Layer-aware propagator tagging, `run-to-layered-quiescence` scheduler |
| `elaborator-network.rkt` | 5, 8a, 8b, 9 | S(-1) integration, readiness propagators, resolution propagator, mult bridge propagators |
| `elab-speculation-bridge.rkt` | 4, 5, 6 | Assumption tracking, S(-1) trigger, retire network-box restore |
| `resolution.rkt` (NEW) | 7a, 7b | Extracted resolution logic (7a); purified to `enet → enet*` (7b) |
| `zonk.rkt` | 7b | `zonk-pure`, `zonk-at-depth-pure` variants accepting explicit `enet` |
| `trait-resolution.rkt` | 7b | `ground-expr-pure?` variant accepting explicit `enet` |
| `unify.rkt` | 7b | `normalize-for-resolution-pure` variant accepting explicit `enet` |
| `qtt.rkt` | 9 | Mult lattice merge function |
| `batch-worker.rkt` | 1, 3 | Persistent network snapshot/restore |
| `test-support.rkt` | 1, 3 | Persistent network isolation |

---

## 11. Verification Strategy

1. **Per-phase**: `racket tools/run-affected-tests.rkt --all` — 0 new failures after each phase
2. **Acceptance file**: `examples/2026-03-18-track7-acceptance.prologos` — run via `process-file` after each phase
3. **Adversarial benchmark** (Phase 0): Synthetic constraint graph with cascading resolution chains (depth 5+, trait→trait→trait), wide fan-out (one meta used by 20+ constraints), nested speculation (3+ levels), cascading resolution feedback (L2 solving metas that unblock further L1 readiness). Compare hand-written loop vs layered scheduler on iteration count, wall time, correctness. Benchmark should use concrete Prologos expressions (e.g., nested `Num` + `Eq` + `Ord` constraints that exercise the full resolution pipeline).
4. **Belt-and-suspenders**:
   - Phase 2: persistent cell reads vs parameter reads (0 divergences)
   - Phase 5: S(-1) retraction vs network-box restore (identical results)
   - Phase 6: retire network-box restore, verify suite still passes
5. **Performance**:
   - Phase 0 baseline: total suite time, per-command cell allocation count. **Measurement methodology**: instrument `net-new-cell` / `net-new-cell-desc` with a counter parameter (`current-cell-allocation-count`), capture count per command in a new `perf-inc-cell-alloc!` call. Record per-command overhead breakdown: cell creation, S1 scan time (wrap `collect-ready-*` with `current-inexact-milliseconds`), `run-to-quiescence` time.
   - Phase 3: measure dual-write elimination impact (fewer parameter writes)
   - Phase 8: measure S1 scanning time before vs. after readiness propagators
   - Phase 10: compare against Phase 0 baseline; investigate if >15% regression
5. **Speculation coverage**: Track 4/6 speculation tests exercise the exact rollback scenarios. Phase 5 must pass all existing speculation tests with S(-1) as the sole retraction mechanism for scoped cells.

---

## 12. Absorbed Deferrals

| Source | Item | Track 7 Phase |
|--------|------|---------------|
| Track 6 Phase 5b | Belt-and-suspenders retirement gate (TMS-aware infra cells) | WS-B Phase 6 |
| Track 6 Phase 8d | Callback inlining (module restructuring) | WS-B Phase 7 |
| Track 6 PIR §14 | `current-prelude-env-prop-net-box` rename | Deferred (low priority) |
| Track 3 Phase 6 | Dual-write parameter elimination for registries | WS-C Phase 3 |
| Master roadmap | QTT multiplicity cells (P5) | WS-A Phase 9 |

---

## 13. Open Questions

### Q1: One persistent network or per-subsystem persistent networks? — **RESOLVED: Option A**

Option A: One persistent registry network holding all 29 cells.
Option B: Separate networks per subsystem (macros, warnings, narrowing).

**Resolution**: Option A. All share similar lifecycle concerns. One network, better correctness reasoning, propagator-first, data-oriented, decomplected. 29 cells is small; subsystem separation adds management overhead without clear benefit.

### Q2: Warning cells — scoped with full observability — **RESOLVED**

Warnings are accumulated per-command and reported at command end. They don't persist across commands.

**Resolution**: Scoped (in elab-network) with full assumption-tagged cell treatment. This gives maximum observability: warnings as cell values with assumption tags, provenance (source location, triggering constraint, elaboration phase), and source annotations. The LSP watches warning cells; when entries are added/retracted, it updates diagnostics in real time. This is the same observability architecture as definition cells — the network IS the observable state. The principles check (observability + expressiveness through to end tooling) guided this resolution.

### Q3: Ready-queue consumption semantics — **RESOLVED: On-network channel cell**

**Resolution**: The ready-queue is a **channel cell** (§2.6 taxonomy). The consumption pattern is entirely on-network using assumption-tagged produce-consume:

1. **L1 (produce)**: Readiness propagator writes a tagged action descriptor to the channel cell
2. **L2 (consume)**: Resolution propagator reads the action, executes resolution, retracts the entry's assumption
3. **S(-1) (clean)**: On the next cycle, retraction stratum removes retracted entries

No off-network clearing. No imperative queue manipulation. The queueing lifecycle is structural — write, read, retract, clean — all through existing cell + assumption infrastructure. This pattern will be useful in distributed/concurrent runtime designs (same produce-consume semantics across processes/nodes).

### Q4: Batch-worker persistent network snapshot — **RESOLVED: 1 box**

**Resolution**: Yes, 1 box is sufficient. If the same snapshot serves all consumers, 1 box. If different modules need different views in the future, each gets its own box pointing to a different CHAMP subtree — structural sharing makes this cheap. For now, 1 box covers all 29 registry cells atomically.

### Q5: Adversarial benchmark for Phase 0 — **NEW, refined in D.2**

Phase 0 should include a synthetic adversarial constraint graph alongside the standard suite baseline:
- Deep **cascading resolution chains** (depth 5+, trait→trait→trait — e.g., resolving `Num Int` triggers `Add Int` + `Sub Int` + `Mul Int` + `Neg Int` + `Abs Int` + `FromInt Int`)
- Wide fan-out (one meta used by 20+ constraints)
- Nested speculation (3+ levels deep)
- **Cascading resolution feedback** (L2 solving dict-metas that were dependencies of other L2 constraints — e.g., `Ord a` depends on `Eq a`, so resolving `Eq Int` unblocks `Ord Int` readiness in the next L1 round)

Note: "cascading feedback" is not a dependency cycle. True cycles (A depends on B depends on A) indicate type errors. Cascading chains are convergent resolution where each step strictly reduces the set of unsolved constraints.

Run both the current hand-written loop and the layered scheduler against this graph. Compare iteration counts, wall time, and correctness. This validates the hybrid BSP/Gauss-Seidel scheduler under adversarial conditions. Measurement: instrument both paths with propagator firing counts (`perf-inc-prop-fire!`), S1 scan time, and total wall time.

### Q6: Propagator taxonomy as a design artifact — **NEW**

The granular taxonomy in §2.6 (transform, fan-in, fan-out, bridge; value, accumulator, channel, shadow; stratum, threshold) is a starting point. A richer taxonomy should include:
- **Temporal propagators**: fire after a delay or on a schedule (for reactive/streaming)
- **Higher-order propagators**: propagators that create/remove other propagators
- **Distributed propagators**: cross-process/cross-node with eventual consistency semantics

This research is deferred (see DEFERRED.md) but the Track 7 taxonomy provides the foundation.

---

## 14. D.2 External Critique Response

External critique received 2026-03-18. This section documents each concern, the grounded response, and design changes (if any).

### C1: Channel Cell Consumption Atomicity — ACCEPTED (implementation note)

**Concern**: What happens if L2 partially consumes the ready-queue before new L1 writes arrive in the same quiescence cycle?

**Response**: The scenario as described **cannot occur** under our Gauss-Seidel inter-stratum scheduling. L1 runs to BSP fixpoint before L2 starts — they are in different strata with a barrier between them (§2.5, steps 1-4). L2 cannot be "mid-consumption" when L1 fires.

The feedback path (L2 → S0 → restart from S(-1) → S0 quiesces → L1 fires → new entries → L2 fires) is well-defined: L2 starts a *fresh* BSP round on each re-entry. It sees the full accumulated queue, not a partial state.

**However**, there is a subtler implementation concern: if L2's resolution propagator iterates the queue list while also retracting assumptions (which may trigger S(-1) and mutate the cell value under iteration), the iteration could see inconsistent state. The safer implementation is snapshot-then-consume.

**Design change**: Added implementation note to Phase 8b (snapshot-then-consume).

### C2: Countdown Latch Under Feedback — ACCEPTED (threshold-cell redesign)

**Concern**: Can a meta cell transition from (partially solved) → (more solved), triggering the readiness propagator again? What prevents duplicate ready-queue entries?

**Response**: Metas do NOT transition from "partially solved" to "more solved" in our architecture. The type lattice is `type-bot < concrete-type < type-top`. Once solved via `solve-meta-core!` (metavar-store.rkt), the cell value is stable. Under TMS, branch retraction can make a meta *appear* unsolved at a particular depth, but readiness propagators use TMS-transparent reads (`net-cell-read`), so they see the base value.

However, the duplicate-firing concern is valid: if all deps are non-⊥ and the readiness propagator fires again in a subsequent BSP round (e.g., after L2 feedback), it would write another action descriptor to the ready-queue. The `(not (meta-solved? meta-id))` guard in the pseudocode handles the post-resolution case but not the window between "action written" and "resolution completed."

**Resolution**: Threshold-cell composition (see revised Phase 8a). Instead of a lifecycle state machine, we compose: fan-in propagator → boolean threshold cell (⊥ → ⊤, one-shot) → readiness propagator → ready-queue. The threshold cell's merge is `(λ (old new) #t)` — once ⊤, stays ⊤. The readiness propagator sees exactly one transition, fires exactly once. The lattice *is* the guard — structural, not operational. No runtime status checks needed for the "fire at most once" guarantee.

Constraint status (pending/resolved/failed) is still tracked for error reporting and observability, but the ready-queue write guard is structural (threshold cell monotonicity), not operational (status check).

**Design change**: Revised Phase 8a with threshold-cell composition.

### C3: Assumption ID Namespaces — ACCEPTED (documentation)

**Concern**: Are queue-entry assumptions the same as speculation assumptions? How does S(-1) know which namespace to clean?

**Response**: Both use the same `make-fresh-assumption!` gensym counter (single ID space), but serve different purposes:

- **Speculation assumptions**: Managed by TMS. Created by `with-speculative-rollback`. Retracted on speculation failure. Tag value-level cells (metas). Retraction trigger: speculation rollback.
- **Lifecycle assumptions**: Managed by channel cell pattern. Created by L1 readiness propagators. Retracted by L2 after consumption. Tag channel cell entries (ready-queue). Retraction trigger: L2 consumption.

S(-1) retracts both — it scans scoped cells for entries tagged with non-believed assumptions. The mechanisms are the same; the *triggers* differ. No collision risk because they live in different cells (scoped infrastructure cells vs. ready-queue channel cell) and are retracted for different reasons.

**Design change**: Added assumption taxonomy paragraph to §2.6.

### C4: S(-1) Retraction Performance — REJECTED

**Concern**: O(scoped cells × entries per cell) on every retraction is expensive for speculation-heavy elaboration.

**Response**: Our scoped cell count is **14** (8 constraint + 3 wakeup + 3 warning cells). Even with 100 entries per cell, iterating 14 cells × filtering entries is negligible compared to a single `run-to-quiescence` pass over hundreds of meta cells.

The depth-0 fast path means S(-1) is a no-op for ~95% of commands. For the ~5% with speculation, the constant overhead of maintaining a reverse index (assumption → affected cells) on *every* constraint registration would likely *exceed* the savings from targeted retraction on the rare rollback path.

This is premature optimization. Track 4's depth-0 fast path precedent applies: optimize the common case (depth 0 = no-op), accept linear scan on the rare case (14 cells is tiny).

**Design change**: None. Added note to §7 Risk Analysis that targeted retraction can be added as a Phase 10 optimization if profiling reveals S(-1) as a hotspot.

### C5: Definition Cell Asymmetry — REJECTED (principled distinction)

**Concern**: Why don't definition cells move to the persistent registry network?

**Response**: There is a principled distinction:

- **Registry cells are per-category**: One cell per registry type (schema, ctor, trait, impl, ...). 29 total, known statically, allocated once at file init. The persistent network is designed for this: small, static, stable cell IDs.
- **Definition cells are per-name**: Each defined name (`def x`, `type Foo`, `defn bar`) gets its own cell. Hundreds per file, allocated dynamically as definitions are elaborated. Moving these to the persistent network would make it a large, growing structure — precisely the wrong lifecycle for a "small static network."

The `current-definition-cells-content` hasheq is the right representation for per-name dynamic state. The persistent registry network is the right representation for per-category static state. Two mechanisms for two different data shapes.

**Design change**: Expanded Non-Goals §1 with the principled distinction.

### C6: Loop Elimination Completeness — ACCEPTED (audit prerequisite)

**Concern**: Has the `run-stratified-resolution!` loop been audited for accumulated edge-case handling?

**Response**: The loop itself (metavar-store.rkt lines 1308-1350) is clean — a straightforward S0→S1→S2 cycle with progress-box detection, no accumulated edge cases. However, the 6 `collect-ready-*` scanning functions may have subtle readiness conditions that must be captured by L1 readiness propagators. An audit of these scanning functions should precede Phase 8a implementation.

**Design change**: Added "Audit `collect-ready-*` scanning functions" as a Phase 8a prerequisite.

### C7: Adversarial Benchmark Specificity — ACCEPTED (terminology)

**Concern**: What does "cyclic feedback" mean exactly?

**Response**: In our context, "cyclic feedback" means **cascading resolution chains**: L2 resolves `Eq Int` → solves dict-meta → this meta was a dependency of `Ord Int` → that constraint becomes ready in next L1 round → L2 resolves `Ord Int` → etc. This is cascading resolution, not a cycle in the dependency graph. True dependency cycles (A depends on B depends on A) indicate type errors, not convergent computation.

**Design change**: Sharpened terminology in Q5: "cyclic feedback" → "cascading resolution chains." Added note that the benchmark should use concrete Prologos expressions (nested `Num` + `Eq` + `Ord` constraints).

### C8: Mult Lattice Integration Depth — NOTED (minimal expansion)

**Concern**: Phase 9 cross-domain bridge is underspecified.

**Response**: Phase 9 is intentionally thin — it's the smallest piece of Track 7. `elab-fresh-mult-cell` (Track 4) already creates mult cells. The QTT checker (`qtt.rkt`) already computes multiplicities. The bridge propagator connects what exists: when a type meta is solved to `(Pi (x : A) m B)`, the multiplicity annotation `m` informs the mult cell. If the type contains an unsolved mult-meta, the bridge doesn't fire (type isn't ground). The bridge is unidirectional: type → mult. Mult → type influence goes through the existing QTT checker.

**Design change**: Added one-paragraph concrete example to Phase 9.

### Minor Issues

- **Naming**: Fixed "run-stratified-loop!" → "run-stratified-resolution!" in §2.5 diagram.
- **Phase 0 measurement**: Added instrumentation methodology (instrument `net-new-cell` with counter parameter, capture per-command allocation counts).
- **Scheduler location**: Clarified in Phase 8b that `run-to-layered-quiescence` is a new function in `propagator.rkt` that calls `run-to-quiescence` per-layer. Layers are a new first-class concept: propagators get a `layer` field, scheduler partitions worklist by layer.

---

## 15. D.3 Self-Critique: Open Tensions

### T1. Resolution Propagator Purity — RESOLVED (Option A)

**The tension**: DESIGN_PRINCIPLES.org § "Design Invariant: Propagator Statelessness" requires propagators be pure fire functions `net → net`. The L2 resolution propagator calls resolution functions that currently write to the network through `current-prop-net-box` (a mutable box). If `run-to-layered-quiescence` holds the network value while the resolution propagator fires and writes through the box, the scheduler's copy and the box diverge. This is the same class of bug as Track 4's dual-write coherence issue (Track 4 PIR §6.1).

**Resolution: Option A (full purification)**. The entire resolution chain — both writes and reads — is purified in Phase 7b. Call chain analysis shows:
- **Writes**: Box writes occur at exactly 6 boundary functions. Purification is mechanical.
- **Reads**: All meta-solution reading funnels through exactly 4 solution-getter functions (`meta-solution`, `meta-solved?`, `level-meta-solution`, `mult-meta-solution`). No box-reading is scattered — all 12 consuming files go through these 4 functions. Creating `enet`-accepting variants of the 4 getters purifies the entire read chain. Consuming functions within the resolution chain (`zonk`, `normalize-for-resolution`, `ground-expr?`) get `-pure` variants that thread `enet`; the rest of the codebase continues using box-reading versions (consistent because `solve-meta!` syncs the box).

Options B (box-synchronized scheduler) and C (hybrid with dual signatures) were considered and rejected. Option B leaves the propagator technically impure — it writes through a side channel, violating the statelessness invariant that makes save/restore, observatory, and speculation correct. Option C perpetuates the imperative pattern — every new call site leans toward the `!`-suffix wrapper, and the pure versions become "optional." Both defer pain that only compounds later.

Option A makes purity the default and the box the exception (one entry point: `solve-meta!`). Principle alignment: Propagator Statelessness (structural, not discipline), Completeness Over Deferral (solve now while context is fresh), Correct by Construction (pure functions can't diverge from the scheduler's network copy).

See Phase 7 design for the full purification plan and function table.

### T2. Two-Network Scaling Assumption (Medium Priority)

**The tension**: DESIGN_PRINCIPLES.org § "Simplicity of Foundation" values minimal foundational constructs. Two separate `prop-network` instances with bridge propagators is more complex than one.

**Current justification**: The persistent network is small (~29 cells) and static (allocated once per file). The elab-network is large (hundreds of meta cells) and ephemeral (cleared per command). Mixing them in one network means either destroy stability (recreate all) or complicate clearing (selective reset).

**Forward-looking concern**: Track 8 (Unification as Propagators), Track 9 (GDE), and Track 10 (LSP) may want unified observation of registry cells and meta cells. Two networks means two scheduler invocations, two quiescence checks, bridge propagators for cross-network communication. If the persistent network grows beyond ~50 cells (e.g., narrowing registries, capability registries, future subsystems), the "small static" argument weakens.

**Scaling assumption (stated explicitly)**: The two-network architecture is correct *while* the persistent network remains small and static. If future tracks need to scale it beyond ~50 cells or require frequent cross-network propagation, the migration path is: unify into a single network with lifecycle-tagged cells (each cell carries a `lifecycle` field: `'persistent` or `'ephemeral`), and `reset-meta-store!` clears only ephemeral cells.

### T3. Constraint Status as Cell Value (Low Priority — Track 10)

**The tension**: DESIGN_PRINCIPLES.org § "First-Class by Default" says constructs should be first-class values. Constraint status (pending/resolved/failed) is currently a field on the `constraint-info` struct in the CHAMP store — not a cell value observable through the network.

**Why acceptable for Track 7**: Constraint status serves error reporting and the scanning functions (which are eliminated by Phase 8a). The threshold cell captures the meaningful transition (not-ready → ready). Resolution outcome is captured by the meta cell (⊥ → solved).

**Why Track 10 cares**: The LSP will want to observe constraint resolution progress for real-time diagnostics (e.g., "3 of 8 trait constraints resolved"). Watching a cell is the propagator-first way to do this; polling struct fields is the anti-pattern.

**Design change**: None for Track 7. Added to DEFERRED.md as a Track 10 prerequisite: promote constraint status to a per-constraint cell value.

### T4. Belt-and-Suspenders Retirement Criteria (Medium Priority)

**The tension**: Track 6 PIR §6.6 warns "belt-and-suspenders needs retirement gate — define concrete retirement criteria upfront."

**Current state**: Phase 6 is the explicit retirement gate for network-box restore (Phase 5b). Phase 8a has belt-and-suspenders (run both scanning and readiness propagators, compare). Phase 8b has belt-and-suspenders (run both hand-written loop and layered scheduler, compare). Neither 8a nor 8b names an explicit retirement gate.

**Design change**: Phase 8c is the explicit retirement gate for both 8a and 8b belt-and-suspenders. Retirement criteria:

- **Phase 8a**: Scanning functions removed when: (a) readiness propagators produce identical action descriptor sets for ≥1 full suite run with 0 divergences, AND (b) Phase 8b is implemented (L2 consuming the ready-queue, confirming end-to-end correctness).
- **Phase 8b**: Hand-written loop removed when: (a) layered scheduler produces identical results for ≥1 full suite run with 0 divergences, AND (b) adversarial benchmark (Q5) passes.

### T5. Acceptance File Multi-Command Patterns (Medium Priority)

**The tension**: DESIGN_METHODOLOGY.org § "WS-Mode Validation Protocol" requires Level 3 validation via `process-file`. Track 7 doesn't add syntax but changes the infrastructure under existing syntax — persistent cells, layered scheduler, retraction. The risk is that single-expression tests pass but multi-command interaction patterns (define type → define trait → define instance → query) break under the new infrastructure.

**Design change**: Phase 0's acceptance file specification must include:

1. **Multi-form interaction**: Type definition followed by trait definition followed by instance followed by query expression — all in one `.prologos` file, exercising the persistent registry network across "commands" (top-level forms).
2. **Speculation trigger**: Expression that triggers speculative type-checking (e.g., Church fold, union type), exercising S(-1) retraction of scoped cells.
3. **Cascading resolution**: Expression requiring nested trait resolution (e.g., `[+ [* 3 4] [- 10 3]]` requiring `Num Int` → `Add Int` + `Sub Int` + `Mul Int`), exercising L1 readiness → L2 resolution → S0 feedback.
4. **Prelude interaction**: Expressions that use prelude-provided traits and instances, verifying that persistent registry cells initialized during prelude loading are correctly bridged to the per-command elab-network.

### T6. Test Infrastructure Divergence (Low Priority)

**The tension**: Track 5 PIR §6.1 found that `run-ns-last` (test infrastructure) doesn't set up `current-prop-make-network` like production does. Infrastructure changes on write paths must audit both test and production paths.

**Design change**: Phase 1 includes explicit step: update `test-support.rkt`'s parameterize block to include `current-persistent-registry-net-box`. Also update `batch-worker.rkt`'s save/restore list per pipeline checklist (`.claude/rules/pipeline.md` § "New Racket Parameter"). Both are mechanical but high-consequence if missed (Track 5 regression: 45 minutes debugging).
