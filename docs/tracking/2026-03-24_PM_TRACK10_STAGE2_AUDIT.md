# PM Track 10: Module Loading on Network — Stage 2 Audit

**Date**: 2026-03-24
**Stage**: 2 (Codebase Audit)
**Series**: PM (Propagator Migration)
**Purpose**: Concrete findings to feed Stage 3 design. Facts and measurements, not proposals.

**Related documents**:
- [Unified Propagator Network Roadmap](2026-03-22_UNIFIED_PROPAGATOR_NETWORK_ROADMAP.md) — on/off-network boundary analysis
- [PM 8F Design](2026-03-24_PM_8F_METAS_AS_CELLS_DESIGN.md) — metas as cells (prerequisite)
- [PM 8F PIR](2026-03-24_PM_8F_PIR.md) — deferred Phase 5 (defaults) and Phase 7 (CHAMP removal) to Track 10
- [Master Roadmap](MASTER_ROADMAP.org) — Track 10 = convergence point
- [SRE Master](2026-03-22_SRE_MASTER.md) — SRE Track 6 = Track 10 (partial)
- [Test Runner](../../tools/run-affected-tests.rkt) — timing data source

---

## 1. Motivation: The Prelude Loading Tax

### 1.1 Performance Data

Timing analysis of `data/benchmarks/timings.jsonl` reveals a ~55s regression
(185s → 240s) between commits `02a4563` (2026-03-20 13:00) and `c7bb09f`
(2026-03-20 18:27), caused by First-Class Paths Phases 1-7 (4 new AST nodes
across 14 pipeline files).

**Per-file regression distribution** (377 files):
- 313 files: near-zero change (no prelude loading)
- 28 files: +10-16s each (prelude-loading tests)
- Mean: +1.0s, Median: +0.1s, Max: +16.7s

The regression is **bimodal**: prelude-loading tests got uniformly ~12s slower.
Non-prelude tests were unaffected. The cause is not the new AST nodes themselves
but the **compound effect of more match arms across 63 prelude module
elaborations**.

### 1.2 The Structural Tax

Every new AST node added to the language (new match arms in zonk, substitution,
reduction, elaboration, qtt, pretty-print) makes EVERY prelude module
elaboration slightly slower. With 63 prelude modules, small per-expression
overhead compounds. As the language grows (NTT forms, PPN constructs, effect
types), this tax increases.

**Current trajectory**: 28 prelude-heavy test files × ~12s overhead = ~336s of
wasted wall time per full suite run. At 10 jobs parallel, that's ~34s of the
~240s wall time attributable to the prelude tax.

---

## 2. Module Loading Entry Points

### 2.1 Primary Entry Points

| Function | File | Line | Triggers |
|----------|------|------|----------|
| `process-file` | driver.rkt | 1436 | .prologos file processing |
| `process-string` / `process-string-ws` | driver.rkt | 1350, 1395 | In-memory processing |
| `process-command` | driver.rkt | 377 | Per-command orchestration |
| `load-module` | driver.rkt | 1510 | Core module loader |
| `ensure-module-loaded` | namespace.rkt | 764 | Module import resolution |
| `install-module-loader!` | driver.rkt | 1754 | Callback installer |

### 2.2 The `load-module` Pipeline (driver.rkt:1510-1750)

For each module:
1. Cache lookup in `current-module-registry` (line 1512)
2. Circular dependency check (line 1536)
3. File path resolution via `resolve-ns-path` (line 1540)
4. **Fresh parameterize block with 41 parameters** (lines 1558-1598)
5. Read file (WS reader for .prologos, sexp otherwise)
6. Preparse, expand, parse, process all commands
7. Capture env-snapshot and build module-info
8. Register in `current-module-registry`
9. Import definitions into caller's `current-prelude-env`

### 2.3 The 41-Parameter Scope (driver.rkt:1558-1598)

Each module load creates a fresh `parameterize` with 41 bindings:
- `current-prelude-env` (fresh hasheq)
- `current-ns-context` (#f)
- `current-meta-store` (fresh hasheq)
- 6 registries inherited from caller (preparse, ctor, type-meta, multi-defn,
  subtype, coercion, capability)
- `current-prop-net-box` (#f — fresh network, no cross-module pollution)
- `current-definition-cells-content` (fresh hasheq)
- `current-module-registry-cell-id` (#f)
- Plus ~30 more constraint/resolution/cache parameters

---

## 3. Prelude Loading Path

### 3.1 Trigger: `(ns foo)` Command

When `(ns foo)` is processed:
1. `process-ns-declaration` (namespace.rkt:614) called from `preparse-expand-all`
2. Creates empty namespace context (line 621)
3. Checks if prelude needed (lines 623-626):
   - Skip for: `:no-prelude`, `prologos::core`, library modules
   - Full prelude for: user modules
4. Iterates `prelude-imports` (40 import specs, namespace.rkt:444-599)
5. Each import → `process-imports` → `process-imports-spec` →
   `ensure-module-loaded` → `load-module`

### 3.2 Prelude Content

**40 import specs** covering:
- Core combinators (`prologos::core`)
- Data types: Ordering, Bool, Nat, Pair, Eq, Datum
- Char, String
- Container types: Option, Result, List, MapEntry, LSeq, Set
- Traits: Eq, Ord, Add/Sub/Mul/Div/Neg/Abs, From/Into/TryFrom, Algebra, Lattice
- Collection traits: Reducible, Collection
- Hashable
- String ops, PVec ops, Map ops, Set ops
- Instance registrations (side-effect only)

### 3.3 Module Dependencies

Prelude modules have internal dependencies (e.g., `prologos::data::list`
imports `prologos::data::nat`). Total unique module loads for a full prelude
is ~63 (40 direct + ~23 transitive).

`prelude-dependency?` (namespace.rkt:436) prevents circular loading by
identifying library modules that must NOT auto-import the prelude.

---

## 4. Module State Storage

### 4.1 Module-Info Structure

```
(struct module-info
  (namespace exports env-snapshot file-path
   macros type-aliases specs definition-locations
   module-network))
```

- **env-snapshot**: hasheq of all definitions (legacy dual-path)
- **module-network**: `module-network-ref` with persistent propagator network

### 4.2 Module-Network-Ref Structure

```
(struct module-network-ref
  (prop-net cell-id-map mod-status-cell
   dep-edges snapshot-hash))
```

- **prop-net**: persistent propagator network (Track 5 deliverable)
- **cell-id-map**: symbol → cell-id mapping
- **mod-status-cell**: lifecycle tracking (loading → loaded → stale)
- **dep-edges**: cross-module dependency tracking
- **snapshot-hash**: materialized env (belt-and-suspenders)

### 4.3 State Location Map

| State | Storage | Scope | Persistence |
|-------|---------|-------|-------------|
| Module registry | `current-module-registry` parameter | File/session | Shared via cache |
| Namespace context | `current-ns-context` parameter | Per-file | Parameter lifetime |
| Module definitions | `env-snapshot` in module-info | Global | Cached in registry |
| Module network | `module-network-ref` in module-info | Per-module | In module-info |
| Persistent registries | `current-persistent-registry-net-box` | Per-file | Box lifetime |
| Prelude env | `current-prelude-env` parameter | Per-command | Parameter lifetime |
| Elaboration network | Created per-command | Per-command | Fresh each time |
| Meta-stores | `current-meta-store` etc. | Per-command | Reset per command |

---

## 5. Test Isolation Mechanism

### 5.1 Prelude Cache (test-support.rkt:74-121)

Prelude loaded **ONCE at module load time** (~3s):

```racket
(parameterize ([current-prelude-env (hasheq)]
               [current-module-registry (hasheq)]
               ...)
  (install-module-loader!)
  (process-string "(ns prelude-cache)\n")
  (init-persistent-registry-network!)
  ...)
```

Returns 6 cached values:
- `prelude-module-registry` (shared across all tests)
- `prelude-prelude-env`
- `prelude-trait-registry`
- `prelude-ctor-registry`
- `prelude-persistent-registry-net-box`
- `prelude-preparse-registry`

### 5.2 Per-Test Isolation (run-ns-last, test-support.rkt:130-154)

```racket
(parameterize
  ([current-prelude-env        (hasheq)]            ;; fresh
   [current-module-registry    prelude-module-registry]  ;; SHARED
   [current-persistent-registry-net-box ...]         ;; SHARED
   [current-definition-cells-content (hasheq)]       ;; fresh
   ...)
  (install-module-loader!)
  (last (process-string s)))
```

**Per-test fresh**: prelude-env, definition-cells, ns-context, meta-stores
**Per-test shared**: module-registry, trait/ctor/preparse registries, persistent network

### 5.3 Batch Worker (batch-worker.rkt:149-240)

- Loads prelude ONCE at startup
- Saves post-prelude state (19 macros params, 7 namespace params, registries)
- Restores per-file from saved snapshot
- Fresh box per file for persistent-registry-net-box

### 5.4 Key Finding: Prelude Does NOT Re-Elaborate Per Test

On cache hit (driver.rkt:1516), `load-module` returns immediately and imports
the cached env-snapshot. The 63 modules are elaborated ONCE per process.

**However**: the 41-parameter `parameterize` block is still created per cache-hit
module import. For 63 modules × per-test, that's 63 parameterize scopes created
and torn down. The overhead is not re-elaboration but parameter management.

---

## 6. Propagator Network During Module Loading

### 6.1 Network Lifecycle

| Phase | Network | Cells | Persisted? |
|-------|---------|-------|------------|
| `process-file` init | Persistent registry network | Registry cells | Yes (per-file) |
| `load-module` | `current-prop-net-box` = #f (no network) | Module definition cells | Discarded |
| Module-network-ref creation | Per-module persistent network | Definition cells | Yes (in module-info) |
| `process-command` | Fresh elaboration network | Command-local cells | No (per-command) |

### 6.2 Key Finding: Module Elaboration Has No Live Network

`load-module` sets `current-prop-net-box` to `#f` (driver.rkt:1575). Module
elaboration happens without a propagator network. Cells created during
module elaboration are captured into the module-network-ref AFTER elaboration
completes.

This means: **module loading is entirely imperative**. The propagator network
is not available during module elaboration. This is the fundamental architectural
gap Track 10 must address.

---

## 7. Deferred Items From Prior Tracks

### 7.1 From PM 8F

- **Phase 5**: Defaults at solve-time (currently at boundary via `default-metas`)
- **Phase 7**: CHAMP fallback removal (requires cells in ALL contexts including module loading)

### 7.2 From Track 8

- **B2e**: Macros dual-write removal (module-load-time fallback needed)

### 7.3 From SRE Track 2

- **Track 2B**: Polarity inference integration into `data` elaboration

---

## 8. Concrete Measurements

### 8.1 Call Site Counts

| Pattern | Count | Files |
|---------|-------|-------|
| `current-module-registry` reads | 12 | 3 (namespace.rkt, driver.rkt, test-support.rkt) |
| `current-module-registry` writes | 4 | 2 (namespace.rkt, driver.rkt) |
| `current-prelude-env` reads | 28 | 4 |
| `current-prelude-env` writes | 15 | 3 |
| `load-module` calls | 3 | 2 (driver.rkt, namespace.rkt) |
| `parameterize` blocks in driver.rkt | 8 | 1 |
| `install-module-loader!` calls | 7 | 3 (driver.rkt, test-support.rkt, batch-worker.rkt) |
| `with-fresh-meta-env` calls | 306 | ~50 test files |
| `process-string` calls in tests | 400+ | ~80 test files |

### 8.2 File Sizes

| File | Lines | Module loading lines (est.) |
|------|-------|---------------------------|
| driver.rkt | 2217 | ~500 (load-module + helpers) |
| namespace.rkt | 787 | ~300 (resolution + prelude) |
| test-support.rkt | ~200 | ~120 (prelude cache + isolation) |
| batch-worker.rkt | ~250 | ~100 (save/restore) |

### 8.3 Module Loading Time

From test-support.rkt timing: prelude loading takes ~3s (one-time cost).
Batch worker eliminates per-file re-loading. But the 41-parameter scope
creation per cache-hit import still happens ~63 times per test.

---

## 9. Architecture Summary

### 9.1 Current Architecture (Imperative)

```
process-file → init persistent registry → for-each command:
  │                                          process-command
  │                                            ├── reset-meta-store!
  │                                            ├── register cells
  │                                            ├── elaborate
  │                                            └── store results
  └── for-each import:
        load-module
          ├── cache check
          ├── 41-param parameterize
          ├── read file
          ├── parse + elaborate (no live network!)
          ├── capture env-snapshot
          ├── build module-network-ref
          └── import into caller env
```

### 9.2 Key Architectural Facts

1. **Module loading is entirely imperative** — no live propagator network
2. **41 parameters per module load** — created/torn down even on cache hit
3. **Prelude modules elaborated once** per process, cached in module-registry
4. **Test isolation via parameterize** — 15+ bindings per test
5. **Dual-path storage** — env-snapshot (hasheq) + module-network-ref (cells)
6. **Module definition cells discarded** during loading, recreated in module-network-ref
7. **The prelude tax scales with AST complexity** — more node types = slower module loading

### 9.3 What Track 10 Must Deliver

1. **Module loading on live network** — cells available during elaboration
2. **Prelude as persistent network** — loaded once, shared via structural sharing
3. **Test isolation via subnetwork scoping** — not parameterize
4. **Eliminate the 41-parameter scope** — state lives in network, not parameters
5. **Eliminate the prelude tax** — module loading cost independent of AST complexity
6. **Absorb 8F deferrals** — CHAMP fallback removal, defaults at solve-time

---

## 10. Source Files Index

| File | Role in module loading |
|------|----------------------|
| `driver.rkt` | `load-module`, `process-file`, `process-command`, `install-module-loader!` |
| `namespace.rkt` | Module registry, `ensure-module-loaded`, prelude-imports, ns resolution |
| `test-support.rkt` | Prelude cache, `run-ns-last`, test isolation fixtures |
| `batch-worker.rkt` | Per-file save/restore, prelude sharing across test files |
| `global-env.rkt` | Global environment storage |
| `metavar-store.rkt` | Meta-store reset, `with-fresh-meta-env` |
| `elaborator-network.rkt` | Per-command elaboration network lifecycle |
| `propagator.rkt` | Network creation, cell operations |
