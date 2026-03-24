# PM Track 10: Module Loading on Network — Stage 3 Design

**Stage**: 3 (Design — D.1)
**Date**: 2026-03-24
**Series**: PM (Propagator Migration)
**Prerequisite**: PM 8F ✅ (cell-id in expr-meta, cell-primary reads)
**Status**: Draft D.1

## Source Documents

- [Stage 2 Audit](2026-03-24_PM_TRACK10_STAGE2_AUDIT.md) — concrete measurements + architecture map
- [Unified Infrastructure Roadmap](2026-03-22_UNIFIED_PROPAGATOR_NETWORK_ROADMAP.md) — on/off-network boundary
- [PM 8F PIR](2026-03-24_PM_8F_PIR.md) — deferred Phase 5 + Phase 7
- [SRE Master](2026-03-22_SRE_MASTER.md) — SRE Track 6 = Track 10 (partial)
- [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md) — network/stratification types
- [Master Roadmap](MASTER_ROADMAP.org) — Track 10 = convergence point

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| Pre-0 | Microbenchmarks + adversarial | ⬜ | Baseline: parameterize cost, cache-hit import, prelude load |
| 0 | Acceptance file baseline | ⬜ | |
| 1 | Network-active module loading | ⬜ | `current-prop-net-box` ≠ #f during load-module |
| 2 | Prelude as persistent shared network | ⬜ | Load once, share via CHAMP structural sharing |
| 3 | Test isolation via subnetwork scoping | ⬜ | Replace 306 `with-fresh-meta-env` parameterize blocks |
| 4 | Eliminate 41-parameter scope | ⬜ | State in network cells, not Racket parameters |
| 5 | Absorb PM 8F deferrals | ⬜ | CHAMP fallback removal, defaults at solve-time |
| 6 | Eliminate dual-path (snapshot retirement) | ⬜ | module-network-ref becomes sole source of truth |
| 7 | Verification + A/B benchmarks + PIR | ⬜ | Compare against Pre-0 baselines |

---

## 1. Vision and Goals

### 1.1 What We're Solving

The Stage 2 audit identified the root architectural problem: **module loading
is entirely imperative** — `current-prop-net-box = #f` during module
elaboration (driver.rkt:1575). Modules are elaborated without a live
propagator network, their cells are discarded, and their results are captured
as hasheq snapshots. This creates:

1. **The prelude tax**: 63 module elaborations through the full AST pipeline.
   Every new AST node makes every module load slower. Currently ~12s per
   prelude-heavy test (28 files affected).

2. **The 41-parameter scope**: Each module load creates a `parameterize` with
   41 bindings — even on cache hits. 63 modules × per-test = 63 scope
   creations/teardowns per test.

3. **The dual-path burden**: Module state exists as BOTH env-snapshot (hasheq)
   AND module-network-ref (cells). Every read must check both. Every write
   must update both.

4. **Test isolation complexity**: 306 `with-fresh-meta-env` calls across 50+
   test files, each parameterizing 15+ bindings. Fragile, verbose, error-prone.

### 1.2 What Track 10 Delivers

**The propagator network is live from first instruction to last.**

- Module loading happens on the network. Cells created during elaboration
  persist in the module's subnetwork.
- The prelude is a persistent shared network loaded once per process.
  Tests reference it via CHAMP structural sharing — O(1), not O(n).
- Test isolation is subnetwork scoping — fork the network, test in the fork,
  discard the fork. No parameterize.
- The 41-parameter scope is eliminated. State lives in network cells.
- The dual-path (snapshot + cells) collapses to cells-only.

### 1.3 Performance Targets

| Metric | Current | Target | Rationale |
|--------|---------|--------|-----------|
| Prelude-heavy test overhead | ~12s | <1s | Shared network, no re-import |
| Full suite wall time | ~240s | <180s | Eliminate prelude tax |
| Module cache-hit cost | ~0.5ms | <0.05ms | No parameterize, no env import loop |
| Test isolation setup cost | ~2ms | <0.1ms | Subnetwork fork, not parameterize |
| Parameter count in load-module | 41 | 0 | State in cells |

### 1.4 NTT Speculative Syntax

```prologos
;; The prelude as a persistent shared network
network prelude-net : PreludeInterface
  :lifetime :persistent
  embed nat-module  : ModuleNet
        bool-module : ModuleNet
        list-module : ModuleNet
        ;; ... 63 modules
  connect nat-module.exports -> bool-module.imports
          nat-module.exports -> list-module.imports
          ;; ... transitive dependency wiring

;; Test isolation as subnetwork scoping
network test-context : TestInterface
  :lifetime :speculative
  :fork-from prelude-net    ;; structural sharing via CHAMP
  embed test-module : ModuleNet
  connect prelude-net.exports -> test-module.imports

;; Module loading stratification
stratification ModuleLoadLoop
  :strata [S-parse S-elaborate S-resolve S-commit]
  :fiber S-parse
    :networks [reader-net parser-net]
  :fiber S-elaborate
    :networks [elab-net type-net]
    :bridges [TypeToMult TypeToSession]
  :fiber S-resolve
    :networks [trait-net readiness-net]
  :fiber S-commit
    :networks [registry-net]
    :mode commit
  :fuel 100
```

---

## 2. Architecture: From Parameterize to Subnetworks

### 2.1 Current Architecture (Imperative)

```
process-file
  ├── init-persistent-registry-network  (ONE per file)
  ├── for-each command:
  │     process-command
  │       ├── parameterize (6 bindings)
  │       ├── reset-meta-store!
  │       ├── fresh elab-network
  │       ├── elaborate + type-check
  │       └── store in global-env
  └── for-each import:
        load-module
          ├── cache check (current-module-registry)
          ├── parameterize (41 bindings!)
          ├── read + parse + elaborate  (no live network!)
          ├── capture env-snapshot
          ├── build module-network-ref
          └── import into caller env
```

### 2.2 Target Architecture (Network-Native)

```
process-file
  ├── create-file-network  (persistent, shared subnetwork of prelude)
  │     └── CHAMP fork from prelude-net
  ├── for-each command:
  │     process-command
  │       ├── create-command-subnetwork  (fork from file-network)
  │       ├── elaborate on live network
  │       ├── resolve on live network
  │       └── commit: merge command-subnetwork into file-network
  └── for-each import:
        load-module
          ├── cache check: is module in prelude-net?  → O(1) ✓
          ├── create-module-subnetwork  (fork from file-network)
          ├── elaborate on live subnetwork
          ├── commit: persist module-subnetwork
          └── wire exports into caller's network
```

### 2.3 The Key Mechanism: CHAMP Fork

Our CHAMP (Compressed Hash Array Mapped Prefix-tree) supports O(1)
structural sharing. A "fork" is:

```racket
(define child-net (champ-fork parent-net))
;; child-net shares ALL of parent's data
;; writes to child create path-copies (CoW)
;; parent is UNMODIFIED
```

This is how we implement subnetwork scoping:
- **Prelude-net** is the root: loaded once, immutable after loading
- **File-net** forks from prelude-net: file-local state overlays prelude
- **Command-net** forks from file-net: command-local state overlays file
- **Test-net** forks from prelude-net: test isolation without parameterize

Each fork is O(1) (single reference copy). Writes are O(log₃₂ n) (path-copy).
Reads see the child's overlay then fall through to the parent.

### 2.4 What "Live Network During Module Loading" Means

Currently `load-module` sets `current-prop-net-box = #f`. The module is
elaborated in a vacuum — no cells, no propagators, no network.

After Track 10: `load-module` creates a module-subnetwork (forked from the
caller's network). Module elaboration happens on this live subnetwork.
Cells created during elaboration PERSIST in the module's subnetwork.
Propagators fire during elaboration. Type checking uses the same network.

The module-network-ref (Track 5) becomes the module's subnetwork — not a
post-hoc reconstruction, but the ACTUAL network from elaboration.

---

## 3. Phased Implementation

### Pre-0: Microbenchmarks

Measure before designing further:

**A. Parameterize overhead:**
- Time to create/teardown a 41-binding parameterize (no body)
- Time for 63 × parameterize (simulating cache-hit prelude import)
- Compare: CHAMP fork + merge cost for equivalent isolation

**B. Cache-hit import cost:**
- Time for `load-module` on cached module (env-snapshot import loop)
- Breakdown: cache lookup + parameterize + env import + registry propagation

**C. Prelude loading baseline:**
- `(process-string "(ns bench)")` end-to-end time
- Per-module breakdown within prelude loading
- Identify slowest modules (candidates for optimization)

**D. CHAMP structural sharing:**
- Fork cost for a 1000-entry CHAMP (simulating module-env)
- Read-through cost (child reads parent's entry)
- Write-in-child cost (path-copy)
- Freeze/snapshot cost

**E. Adversarial:**
- 100 modules with cross-dependencies
- Deep dependency chains (A imports B imports C ... 10 deep)
- Module with 200 definitions (large env-snapshot)

### Phase 0: Acceptance File

Create `examples/2026-03-24-track10.prologos` exercising:
- Module loading (`ns`, `use`)
- Prelude access (trait instances, generic arithmetic)
- Cross-module references
- Nested module imports

Run as baseline for all subsequent phases.

### Phase 1: Network-Active Module Loading

**Goal**: `current-prop-net-box ≠ #f` during `load-module`.

**Change**: In `load-module` (driver.rkt:1575), replace
`[current-prop-net-box #f]` with a fresh propagator network:

```racket
[current-prop-net-box (box (make-prop-network))]
```

This is the minimal change — modules now elaborate with a live network.
Cells created during elaboration exist on this network. After elaboration,
the network is captured into `module-network-ref` (already done by Track 5).

**Risk**: Module elaboration may trigger propagator behavior that wasn't
active before (resolution bridges, constraint propagation). The fresh
network is isolated (no parent), so cross-module propagation doesn't happen.
But within-module propagation DOES — trait resolution, type inference,
constraint solving all fire on the live network.

**Validation**: Full test suite. Per-module verbose output comparing with/without.

**Principles**: Propagator-First (modules elaborate on network, not in vacuum).
Completeness (the network is available everywhere, not just in process-command).

### Phase 2: Prelude as Persistent Shared Network

**Goal**: Load prelude once, share via structural sharing.

**Mechanism**: After prelude loading completes, freeze the prelude network
into a persistent CHAMP. Store it as `prelude-network` (a module-level
`define`, not a parameter). All subsequent file/command processing forks
from this persistent network.

```racket
;; In test-support.rkt:
(define prelude-network
  (parameterize (...)
    (process-string "(ns prelude-cache)")
    (champ-freeze (unbox (current-prop-net-box)))))

;; In run-ns-last:
(define test-net (champ-fork prelude-network))
(parameterize ([current-prop-net-box (box test-net)] ...)
  ...)
```

**Key insight**: The prelude network contains ALL module-network-refs,
ALL persistent registry cells, ALL prelude definitions as cells. Forking
it gives a test everything it needs — no env-snapshot import loop, no
registry propagation, no 63 × parameterize.

**Validation**: Test suite wall time should drop significantly (target: <180s).
The 28 prelude-heavy test files should show the largest improvement.

**Principles**: Data Orientation (prelude is a value, not a side-effect chain).
Composition (fork composes prelude with test-local state).

### Phase 3: Test Isolation via Subnetwork Scoping

**Goal**: Replace `with-fresh-meta-env` / `run-ns-last` parameterize with
subnetwork fork.

**Change**: `run-ns-last` becomes:

```racket
(define (run-ns-last s)
  (define test-net (champ-fork prelude-network))
  (parameterize ([current-prop-net-box (box test-net)])
    ;; Only the network parameter — everything else is IN the network
    (last (process-string s))))
```

**Migration path**: Start with `run-ns-last` (most common fixture — used
by ~80% of tests). Then `run-ns` and `run`. Then direct `process-string`
callers. Finally `with-fresh-meta-env` callers.

The 15-binding parameterize in `run-ns-last` shrinks to 1 binding
(`current-prop-net-box`). The other 14 bindings become cell reads
from the forked network.

**This is the highest-risk phase**: every test depends on isolation
correctness. Cross-test leakage = test pollution. The CHAMP fork
guarantees isolation (writes are copy-on-write, parent unmodified),
but the test must also isolate:
- Meta-store state (per-command fresh metas)
- Constraint state (per-command fresh constraints)
- Error state (per-command fresh errors)

These must either be cells in the forked network (reset on fork) or
remain as parameters (minimal parameterize).

**Validation**: Full suite + targeted cross-test isolation tests.

### Phase 4: Eliminate 41-Parameter Scope

**Goal**: State lives in network cells, not Racket parameters.

**Audit finding**: 41 parameters in `load-module`'s parameterize (driver.rkt:
1558-1598). Each parameter represents state that should be a cell:

| Parameter | Network equivalent |
|-----------|-------------------|
| `current-prelude-env` | Cell: prelude definitions in parent network |
| `current-ns-context` | Cell: namespace state (per-module) |
| `current-meta-store` | Cell: meta CHAMP (already partially on network) |
| `current-prop-net-box` | THE network itself (not a parameter) |
| `current-definition-cells-content` | Cell: definition cells (already exists) |
| 6 registries | Cells: already persistent registry cells (Track 7) |
| ~30 constraint/cache params | Cells: per-command state in the network |

**Migration**: Parameter-by-parameter. For each parameter:
1. Create equivalent cell in the network
2. Add read-from-cell in the code that reads the parameter
3. Add write-to-cell in the code that writes the parameter
4. Remove the parameter binding from `parameterize`
5. Verify: parameter access count drops to 0

**Risk**: Some parameters are read outside network scope (error formatting,
pretty-printing). These need either: cell reads with network argument, or
remain as thin parameters that are set from cell values at scope entry.

**Principles**: Propagator-First (state on network). Decomplection (separate
module state from Racket parameter dispatch). Data Orientation (state as
cells, not closures over parameters).

### Phase 5: Absorb PM 8F Deferrals

**Goal**: Complete the items deferred from PM 8F.

**5a: CHAMP fallback removal** (PM 8F Phase 7)

With module loading on-network (Phase 1), cells are available in ALL contexts.
The CHAMP fallback path in `meta-solution/cell-id` (metavar-store.rkt:1964)
can be removed. All meta reads go through cells.

**5b: Defaults at solve-time** (PM 8F Phase 5)

Move `default-metas` from boundary time (`zonk-final`) to solve time. When
the stratified resolution loop completes and level/mult metas remain unsolved,
apply defaults via cell write (not tree walk).

**5c: Macros dual-write removal** (Track 8 B2e)

With module loading on-network, the module-load-time fallback path that
writes to both parameter AND cell is unnecessary. Macros writes go to cells
only.

### Phase 6: Eliminate Dual-Path (Snapshot Retirement)

**Goal**: `module-network-ref` is the sole source of truth. Remove
`env-snapshot`.

**Currently**: Module state exists as both:
- `env-snapshot` (hasheq in module-info) — the primary read path
- `module-network-ref` (cells) — secondary, for dependency tracking

**After**: Only `module-network-ref`. Definition lookup reads from the
module's subnetwork cells. `env-snapshot` is removed from `module-info`.

**Migration**:
1. Add `module-definition-lookup` that reads from module-network-ref cells
2. Replace all `env-snapshot` reads with `module-definition-lookup`
3. Remove `env-snapshot` field from `module-info`
4. Remove snapshot creation in `load-module`
5. Remove snapshot import loop in cache-hit path

**Risk**: The cache-hit import loop (driver.rkt:1520-1522) currently copies
env-snapshot into `current-prelude-env`. Without snapshots, this loop
disappears — but callers that read from `current-prelude-env` must now
read from the network. This is Phase 4's cell migration applied to
module imports.

### Phase 7: Verification + A/B Benchmarks + PIR

**Deliverables**:
1. Run Pre-0 benchmarks against post-implementation state
2. A/B comparison: wall time, per-file times, prelude-heavy vs light
3. Verify performance targets met
4. Run acceptance file
5. Instrumentation cleanup
6. Write PIR per methodology

---

## 4. Principles Alignment (Challenge, Not Catalogue)

### 4.1 Propagator-First

**Challenge**: Is the CHAMP fork mechanism "on network"? A fork is a data
operation on the CHAMP, not a propagator operation on cells. Forking doesn't
fire propagators — it copies references.

**Response**: The fork IS the network operation for isolation. Propagation
happens WITHIN the fork. The fork creates the scope; propagation fills it.
This parallels how `make-prop-network` creates a scope that propagation
fills — nobody argues that network creation isn't "on network."

### 4.2 Completeness

**Challenge**: Phase 4 (parameter elimination) is the hardest phase and the
most likely to be deferred. Without it, we have "modules on network" but
"module loading still parameter-heavy." Is that a Completeness violation?

**Response**: Yes — but Phase 4 is bounded by Phase 1-3. Once modules
elaborate on live networks (Phase 1), the prelude is persistent (Phase 2),
and tests fork subnetworks (Phase 3), the remaining parameters are
mechanical migration. Phase 4 is labor, not design risk. The Completeness
violation would be deferring Phases 1-3, not Phase 4.

### 4.3 Correct-by-Construction

**Challenge**: CHAMP fork isolation relies on immutability — writes are
copy-on-write. But `set-box!` on `current-prop-net-box` mutates the box,
not the CHAMP. If two forks share a box, writes to one are visible to the
other.

**Response**: Each fork gets its OWN box. The fork operation is:
`(box (champ-fork (unbox parent-box)))`. The child box points to a CoW
copy. The parent box is unmodified. Isolation is structural — enforced
by CHAMP semantics, not by discipline.

### 4.4 Data Orientation

**Challenge**: Moving 41 parameters into cells means 41 cell reads where
there were 41 parameter reads. Is this more data-oriented or just different
machinery?

**Response**: Parameters are closures over mutable state. Cells are values
in a persistent data structure. The cell approach is MORE data-oriented:
cells are inspectable (you can read their history via trace), composable
(fork shares them), and observable (propagators can watch them). Parameters
are opaque.

### 4.5 Composition

**Challenge**: Does the fork mechanism compose? Can you fork a fork?

**Response**: Yes — CHAMP fork is transitive. `prelude-net` → `file-net` →
`command-net` → `speculation-net` is a chain of forks. Each level sees its
ancestors' state and overlays its own. This is the CHAMP's structural
sharing — it's designed for exactly this use case (persistent data with
efficient branching).

---

## 5. Risk Assessment

| Phase | Risk | Mitigation |
|-------|------|------------|
| 1 | Module elaboration with live network triggers unexpected propagation | Fresh isolated network per module (no cross-module) |
| 2 | Prelude network size (63 modules of cells) exceeds memory | Measure: CHAMP sharing means cells are shared, not duplicated |
| 3 | Test isolation leakage via shared cells | CHAMP CoW guarantees isolation; add cross-test leak detection |
| 4 | 41 parameters × call sites across codebase | Incremental migration, one parameter at a time |
| 5 | CHAMP fallback removal breaks module-loading context | Phase 1 ensures cells are available everywhere |
| 6 | Snapshot retirement breaks callers that assume hasheq | Grep all env-snapshot reads before removing |

---

## 6. Completion Criteria

Track 10 is DONE when:

1. ✅ `current-prop-net-box ≠ #f` during all module elaboration
2. ✅ Prelude loaded once per process, shared via CHAMP fork
3. ✅ `run-ns-last` uses subnetwork fork (1 parameter, not 15)
4. ✅ `load-module` parameterize has <5 bindings (down from 41)
5. ✅ CHAMP fallback removed from `meta-solution/cell-id`
6. ✅ `env-snapshot` removed from `module-info`
7. ✅ Full suite wall time <180s (down from ~240s)
8. ✅ 28 prelude-heavy tests each <30s (down from ~40s)
9. ✅ All 7401+ tests pass
10. ✅ Acceptance file 0 errors
11. ✅ PIR written per methodology

---

## 7. Deferred Items Absorbed

| Source | Item | Phase |
|--------|------|-------|
| PM 8F Phase 5 | Defaults at solve-time | Phase 5b |
| PM 8F Phase 7 | CHAMP fallback removal | Phase 5a |
| Track 8 B2e | Macros dual-write removal | Phase 5c |
| SRE Track 2B | Polarity inference (independent, not absorbed) | N/A |

---

## 8. Open Questions

1. **How many of the 41 parameters CAN be cells vs MUST remain parameters?**
   Some parameters (e.g., `current-output-port`) are Racket runtime state
   that can't be cells. Phase 4 needs a per-parameter audit.

2. **Module loading order on network**: Currently serial (each module loads
   its dependencies before itself). On the network, could we parallelize
   independent module loads? The CHAMP fork enables this — but the current
   serial loading is correct and simple.

3. **Persistent registry network ↔ prelude network**: Currently these are
   separate (persistent-registry-net-box vs module networks). Should they
   merge into one unified prelude network?

4. **The `install-module-loader!` callback pattern**: 7 call sites install
   the module loader. After Track 10, is this still needed? Or does the
   network carry the loader as a cell?

5. **Batch worker compatibility**: The batch worker saves/restores state
   across test files. With subnetwork forking, does the batch worker become
   simpler (fork prelude per file) or more complex (manage fork lifecycle)?
