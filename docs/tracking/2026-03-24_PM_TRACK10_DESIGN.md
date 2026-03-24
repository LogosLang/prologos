# PM Track 10: Module Loading on Network — Stage 3 Design

**Stage**: 3 (Design — D.2, revised with Pre-0 benchmark data + .pnet serialization)
**Date**: 2026-03-24
**Series**: PM (Propagator Migration)
**Prerequisite**: PM 8F ✅ (cell-id in expr-meta, cell-primary reads)
**Status**: Draft D.2

## Source Documents

- [Stage 2 Audit](2026-03-24_PM_TRACK10_STAGE2_AUDIT.md) — concrete measurements + architecture map
- [Unified Infrastructure Roadmap](2026-03-22_UNIFIED_PROPAGATOR_NETWORK_ROADMAP.md) — on/off-network boundary
- [PM 8F PIR](2026-03-24_PM_8F_PIR.md) — deferred Phase 5 + Phase 7
- [SRE Master](2026-03-22_SRE_MASTER.md) — SRE Track 6 = Track 10 (partial)
- [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md) — network/stratification types
- [Master Roadmap](MASTER_ROADMAP.org) — Track 10 = convergence point
- [Pre-0 Benchmark Suite](../../racket/prologos/benchmarks/micro/bench-track10-module-loading.rkt) — parameterize, cache-hit, CHAMP fork, prelude e2e, isolation, memory

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| Pre-0 | Microbenchmarks + adversarial | ✅ | `313a930` — see §3.Pre-0 for results |
| 0 | Acceptance file baseline | ⬜ | |
| 1 | Network-active module loading + .pnet serialization | ⬜ | THE highest-value phase — 20s → ~50ms cold start |
| 2 | Prelude as persistent shared network | ⬜ | Fork from deserialized prelude .pnet |
| 3 | Test isolation via subnetwork scoping | ⬜ | Architectural value (not performance — setup is already 2.2μs) |
| 4 | Absorb PM 8F deferrals | ⬜ | CHAMP fallback removal, defaults at solve-time |
| 5 | Eliminate dual-path (snapshot retirement) | ⬜ | module-network-ref as sole source of truth |
| 6 | Parameter reduction (incremental) | ⬜ | Architectural cleanup, not performance-critical (3.4μs/scope) |
| 7 | Verification + A/B benchmarks + PIR | ⬜ | Compare against Pre-0 baselines |

---

## 1. Vision and Goals

### 1.1 What We're Solving

The Stage 2 audit identified the root architectural problem: **module loading
is entirely imperative** — `current-prop-net-box = #f` during module
elaboration (driver.rkt:1575). Modules are elaborated without a live
propagator network, their cells are discarded, and their results are captured
as hasheq snapshots.

**Pre-0 benchmark data (D.2 revision)** revealed the cost distribution:

| Component | Cost | Impact |
|-----------|------|--------|
| First-time prelude elaboration | ~20s | Paid once per process (per worker) |
| 41-param parameterize × 63 modules | ~214μs | Negligible (D.1 overestimated) |
| Cache-hit import loop × 63 modules | ~410μs | Negligible (D.1 overestimated) |
| CHAMP fork (5000 entries) | 287ns | Replacement is viable |
| Per-test state restoration | 2.2μs | Already fast |

**D.1 was wrong about the bottleneck.** Parameterize overhead and cache-hit
costs are microseconds, not seconds. The real costs are:

1. **The 20s cold-start**: First-time elaboration of 63 prelude modules
   through the full AST pipeline. Paid once per worker process. With 10
   batch workers, ~20s wall time at suite start. Cannot be reduced by
   caching in memory — must be reduced by **not elaborating from source**.

2. **The structural tax on pipeline dispatch**: Every new AST node adds match
   arms to zonk, substitution, reduction, qtt, elaboration. This slows ALL
   elaboration (prelude + test bodies). The First-Class Paths +55s regression
   (185s → 240s) is from this, not from prelude re-loading. Track 10 addresses
   this by eliminating re-elaboration of prelude modules via serialized cache.

3. **The dual-path burden**: Module state exists as BOTH env-snapshot (hasheq)
   AND module-network-ref (cells). Architectural complexity, not performance.

4. **Test isolation complexity**: 306 `with-fresh-meta-env` calls across 50+
   test files. Architectural complexity — the parameterize cost is 2.2μs,
   but the code is fragile and verbose.

### 1.2 What Track 10 Delivers

**The propagator network is live from first instruction to last. Module
elaboration results are serialized to disk and deserialized on cold start.**

- **Module network serialization (`.pnet` files)**: Elaborated module state
  (cell values, registries, metadata) is serialized to disk via Racket's
  `fasl` format. On cold start, `.pnet` files are deserialized directly —
  no re-parsing, no re-elaboration, no re-type-checking. Like `.zo` for
  Racket modules, but for propagator networks.

- **Module loading on live network**: Cells created during elaboration persist
  in the module's subnetwork. No more `current-prop-net-box = #f`.

- **Prelude as persistent shared network**: Deserialized from `.pnet` files
  on cold start (~50ms), forked via CHAMP structural sharing for each test.

- **Test isolation via subnetwork scoping**: Fork the network, test in the
  fork, discard the fork. CHAMP CoW guarantees isolation.

- **Dual-path retirement**: `env-snapshot` removed; `module-network-ref`
  (cell values) is the sole source of truth.

### 1.3 Performance Targets (revised from Pre-0 data)

| Metric | Current | Target | Rationale |
|--------|---------|--------|-----------|
| Cold-start prelude load | ~20s per worker | <100ms | .pnet deserialization, not elaboration |
| Full suite wall time | ~240s | <200s | Cold-start elimination + reduced pipeline tax |
| Module cache-hit cost | ~6.5μs | <1μs | CHAMP lookup, no import loop |
| Test isolation setup | 2.2μs | <0.5μs | CHAMP fork (287ns for 5000 entries) |
| Parameter count in load-module | 41 | <10 | Incremental migration, not zero (some are Racket-intrinsic) |

**Note on the 12s per-test regression**: Pre-0 data shows this is from
heavier pipeline dispatch (more match arms), NOT from prelude re-loading.
Track 10 reduces this indirectly: with `.pnet` serialization, the prelude's
elaboration results bypass the pipeline entirely. Tests that USE prelude
definitions benefit because those definitions are already in cells — no
re-elaboration through the heavier pipeline. The improvement depends on
how much of each test's time is spent re-elaborating prelude-imported
definitions vs. elaborating new test-local code.

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

### 2.5 Module Network Serialization (`.pnet` files)

**The highest-leverage mechanism in Track 10.** Pre-0 benchmarks show that
the 20s cold-start is the dominant cost — and it's pure elaboration (parsing
+ type-checking + resolution of 63 modules from source). Serializing the
elaboration RESULT eliminates this cost on subsequent runs.

#### 2.5.1 What Gets Serialized

For a fully-elaborated module (quiescent network, all metas solved, all
constraints resolved), the propagators are INERT — they've already fired.
The cell values ARE the result. We serialize the result, not the mechanism:

| Serialized | Format | Size estimate |
|-----------|--------|--------------|
| Cell values (type exprs, definitions) | `fasl` (struct trees) | ~50 bytes/def |
| Registry state (ctor, trait, preparse) | `fasl` (hasheqs) | ~2KB/module |
| Module metadata (exports, specs, macros source) | `fasl` | ~1KB/module |
| Definition-to-cell-id mappings | `fasl` (symbol→int) | ~0.5KB/module |
| Source hash (staleness check) | SHA-256 | 32 bytes |

| NOT serialized | Why |
|---------------|-----|
| Propagators | Already fired — inert. Mechanism, not result. |
| Worklist | Empty after quiescence |
| Contradiction state | Clean after successful elaboration |
| Closures (macro transformers) | Not serializable; re-parse from cached source |

Estimated total: ~5KB per module × 63 = ~315KB for full prelude `.pnet` cache.

#### 2.5.2 Staleness Check

```racket
(define (pnet-stale? module-ns)
  (define pnet-path (ns->pnet-path module-ns))
  (define source-paths (module-transitive-sources module-ns))
  (or (not (file-exists? pnet-path))
      (let ([cached-hash (pnet-source-hash pnet-path)]
            [current-hash (hash-sources source-paths)])
        (not (equal? cached-hash current-hash)))))
```

Hash the module source + all transitive dependency sources. If hash matches
the cached `.pnet`, deserialize. If stale, re-elaborate from source and
re-serialize. Same model as `raco make` for `.zo` files.

#### 2.5.3 The Load Path

```
load-module(ns):
  1. Memory cache hit? → return (current behavior, ~129ns)
  2. .pnet exists AND fresh? → deserialize into network (~1-5ms)
  3. Neither → elaborate from source (~300ms/module)
             → serialize to .pnet
             → cache in memory
```

Step 2 is the new path — 400-2000× faster than step 3.

#### 2.5.4 Serialization Mechanism: Racket `fasl`

Racket's FASL (Fast Assembly Language) is the same format `.zo` files use.
`fasl->output` / `fasl->input` from `racket/fasl` handle arbitrary Racket
values including structs, numbers, strings, hasheqs, vectors — everything
in our module state EXCEPT closures.

Our type expressions (expr-Pi, expr-app, etc.) are standard Racket structs.
Registry entries are hasheqs of structs. Module metadata is structs + lists.
All serializable via `fasl`.

**The closure problem**: Macros are syntax transformers = Racket closures.
Closures can't be serialized via `fasl`. Options:
- **(A)** Store macro SOURCE in `.pnet`, re-parse on deserialize
- **(B)** Exclude macros from `.pnet`; re-install from `.rkt` module on load
- **(C)** Use `racket/serialize` for closures (requires `serializable-struct`)

Option A is simplest: macros are defined as S-expressions in the source.
Store the S-expression; on deserialize, parse and install the macro.
Parsing a macro definition is microseconds, not milliseconds.

**Cell-id stability**: Cell IDs must be deterministic (same source → same IDs)
OR remapped on deserialize. Deterministic assignment is simpler: use a
counter starting from 0, assigned in definition order. Same source file →
same definition order → same cell IDs. If a dependency changes, the module
is re-elaborated (staleness check catches it) → fresh IDs.

#### 2.5.5 NTT Speculative Syntax for Serialization

```prologos
;; Module as a serializable network
network list-module : ModuleInterface
  :lifetime :persistent
  :serializable true              ;; can be written to .pnet
  :source "lib/prologos/data/list.prologos"
  :hash "a1b2c3..."              ;; source + transitive deps hash

;; Deserialization as network instantiation
network prelude : PreludeInterface
  :lifetime :persistent
  :deserialize-from "data/cache/prelude.pnet"
  :fallback elaborate-from-source  ;; if .pnet stale
```

#### 2.5.6 `.pnet` File Location

```
lib/prologos/data/list.prologos        → data/cache/prologos/data/list.pnet
lib/prologos/core/eq.prologos          → data/cache/prologos/core/eq.pnet
lib/prologos/core/arithmetic.prologos  → data/cache/prologos/core/arithmetic.pnet
```

The `data/cache/` directory mirrors the `lib/` tree. `.pnet` files are
gitignored (generated artifacts, like `.zo`). `raco make` equivalent:
a tool that pre-generates all `.pnet` files.

---

## 3. Phased Implementation (revised from Pre-0 data)

### Pre-0: Microbenchmarks ✅ (`313a930`)

**Results** (from `bench-track10-module-loading.rkt`):

| # | Measurement | Result | Implication |
|---|-------------|--------|-------------|
| A1 | 41-param parameterize | 3.4μs | NOT the bottleneck (D.1 overestimated) |
| A2 | 15-param parameterize (run-ns-last) | 1.1μs | Already fast |
| A3 | 63 × 5-param nested | 40μs | Negligible |
| B1 | Module cache-hit lookup | 129ns | Trivial |
| B2 | 50-entry env-snapshot import | 3.8μs | Trivial |
| B3 | 7 hash-union (registry propagation) | 2.5μs | Trivial |
| C1 | CHAMP fork (100 entries) | 105ns | 32× faster than parameterize |
| C2 | CHAMP fork (5000 entries) | 287ns | Prelude-scale fork viable |
| C3 | CHAMP read-through | 37ns | Parity with hash-ref |
| C4 | Fork + 10 writes | 1.1μs | Parity with hash-set |
| C5 | 4-deep fork chain | 2.3μs | Composable |
| D1 | Full `(ns bench)` | ~20s | **THE bottleneck** — first-time elaboration |
| D2 | Per-module (cached) | ~0.1ms each | Cache path is fast |
| E1 | CHAMP isolation | ✓ correct | Parent unmodified after child writes |
| E2 | 100 fork-discard cycles | <1ms, 0ms GC | No memory pressure |
| F1 | 5000-entry CHAMP memory | 262KB (53.7 bytes/entry) | Feasible |
| F2 | Fork memory overhead | 752 bytes | Negligible |
| G1 | run-ns-last state restore | 2.2μs | Already fast |

**Key finding**: The 20s cold-start (D1) is the ONLY significant cost.
Everything else is microseconds. `.pnet` serialization targets this directly.

**Design revision from data**: D.1 focused on parameterize elimination and
CHAMP fork as performance levers. Pre-0 data shows these are architectural
improvements (cleanliness, composability) not performance improvements. The
performance lever is `.pnet` serialization: 20s elaboration → ~50ms
deserialization (400×). Phase ordering revised accordingly.

### Phase 0: Acceptance File

Create `examples/2026-03-24-track10.prologos` exercising:
- Module loading (`ns`, `use`)
- Prelude access (trait instances, generic arithmetic)
- Cross-module references
- Nested module imports

Run as baseline for all subsequent phases.

### Phase 1: Network-Active Module Loading + `.pnet` Serialization

**Goal**: Modules elaborate on a live network AND results are serialized to
disk for instant cold-start loading.

**Two sub-phases:**

**Phase 1a: Network-active loading.**

In `load-module` (driver.rkt:1575), replace `[current-prop-net-box #f]`
with a fresh propagator network:

```racket
[current-prop-net-box (box (make-prop-network))]
```

Modules now elaborate with a live network. Cells created during elaboration
persist in the module's subnetwork. After elaboration, the network is
captured into `module-network-ref` (Track 5 already does this).

**Risk**: Module elaboration may trigger propagator behavior that wasn't
active before (resolution bridges, constraint propagation). The fresh
network is isolated (no parent), so cross-module propagation doesn't happen.
But within-module propagation DOES — trait resolution, type inference,
constraint solving all fire on the live network.

**Phase 1b: `.pnet` serialization.**

After successful module elaboration, serialize the module's cell values +
registry state + metadata to a `.pnet` file using `fasl->output`.

```racket
(define (serialize-module-network! module-ns module-info net)
  (define pnet-path (ns->pnet-path module-ns))
  (define source-hash (hash-module-sources module-ns))
  (define data
    (list source-hash
          (module-info-env-snapshot module-info)
          (extract-registry-state)
          (module-info-specs module-info)
          (module-info-exports module-info)
          (module-info-definition-locations module-info)
          (extract-macro-sources module-info)))
  (call-with-output-file pnet-path
    (lambda (out) (fasl->output data out))
    #:exists 'replace))
```

On load, check staleness and deserialize if fresh:

```racket
(define (load-module-from-pnet module-ns)
  (define pnet-path (ns->pnet-path module-ns))
  (and (file-exists? pnet-path)
       (let ([data (call-with-input-file pnet-path fasl->input)])
         (and (equal? (car data) (hash-module-sources module-ns))
              (reconstruct-module-info data)))))
```

**Load path becomes**:
1. Memory cache hit → return (~129ns)
2. `.pnet` fresh → deserialize (~1-5ms)
3. Neither → elaborate from source (~300ms/module) → serialize → cache

**Validation**: Full suite. Cold-start timing comparison. `.pnet` round-trip
(serialize → deserialize → compare with elaborated result).

**Principles**: Propagator-First (modules elaborate on network).
Completeness (elaboration results persist — no re-elaboration on cold start).
Data Orientation (serialized network is a value, not a side-effect chain).

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
| 1b | `fasl` round-trip fails for some struct types | Test with each struct type before building pipeline |
| 1b | Macro closures not serializable | Store macro source, re-parse on load (microseconds) |
| 1b | Cell-id instability across serialization cycles | Deterministic counter assignment; verify with round-trip test |
| 6 | Snapshot retirement breaks callers that assume hasheq | Grep all env-snapshot reads before removing |

---

## 6. Completion Criteria

Track 10 is DONE when:

1. ✅ `current-prop-net-box ≠ #f` during all module elaboration
2. ✅ `.pnet` files generated for all prelude modules
3. ✅ Cold-start prelude load from `.pnet` < 100ms (down from ~20s)
4. ✅ Prelude shared via CHAMP fork across tests
5. ✅ CHAMP fallback removed from `meta-solution/cell-id`
6. ✅ `env-snapshot` removed from `module-info`
7. ✅ Full suite wall time < 200s (down from ~240s)
8. ✅ All 7401+ tests pass
9. ✅ Acceptance file 0 errors
10. ✅ A/B benchmarks run and compared against Pre-0
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

6. **`fasl` compatibility with our struct types**: Do our AST structs
   (expr-Pi, expr-app, etc.) round-trip correctly through `fasl->output` /
   `fasl->input`? Need to test: struct identity, custom `gen:equal+hash`
   (expr-meta has custom equality), nested structs, hasheqs of structs.

7. **Macro transformer serialization**: Macros are closures — not
   `fasl`-serializable. Store macro SOURCE and re-parse on deserialize?
   Or exclude macros and re-install from Racket module? Measure: how many
   macros, how expensive is re-parsing vs full module load?

8. **Cell-id determinism**: Must cell IDs be deterministic (same source →
   same IDs) for `.pnet` correctness? If the deserialized network has
   cell-id 42 for `List`, but the runtime expects cell-id 57, lookups fail.
   Options: deterministic counter, or ID remapping on deserialize.

9. **Incremental `.pnet` invalidation**: If module A changes and module B
   depends on A, both `.pnet` files are stale. The transitive dependency
   hash handles this — but do we re-serialize just A and B, or all 63?
   Incremental re-serialization = faster rebuild. Full = simpler.

10. **Pre-compilation tool**: Should we add a `raco prologos-make` or extend
    `tools/run-affected-tests.rkt` to pre-generate `.pnet` files? This
    parallels `raco make` for `.zo` files.
