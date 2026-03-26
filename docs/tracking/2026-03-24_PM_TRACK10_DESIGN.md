# PM Track 10: Module Loading on Network — Stage 3 Design

**Stage**: 3 (Design — D.4, external critique + NTT modeling)
**Date**: 2026-03-24
**Series**: PM (Propagator Migration)
**Prerequisite**: PM 8F ✅ (cell-id in expr-meta, cell-primary reads)
**Status**: Draft D.4

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
| Pre-0.5 | Serialization round-trip benchmark (D.4) | ⬜ | Time actual serialize + deserialize of prelude. Validates <100ms target. |
| 0 | Acceptance file baseline + ns-context fix | ✅ | `d5a61fa` — 7401 tests, 241.4s |
| 1a | Network-active module loading | ✅ | `a96f543` — `prop-net-box = (box (make-prop-network))` during load-module |
| 1b | `.pnet` serialization pipeline | ✅ | `9203476` — struct->vector + write/read + tag dispatch |
| 1b.2 | Tag table (60+ constructors) | ✅ | `7b8e282` — register-all-pnet-structs! |
| 2a | Foreign function provenance | ✅ | `05d93c4` — source-module + racket-name, dynamic-require re-linking |
| 2b-2e | Registry completeness (incremental) | ✅ | Preparse closures→symbols, coercion→data refs, 5 registries, capability wrappers |
| 2f | Comprehensive registry audit — ALL GREEN | ✅ | `e25061a` — 17/28 registries. 382/382, 7401 tests, 243.2s |
| 3a | .pnet cache ON + tooling | ✅ | `51e6a9e` — pnet-compile.rkt, --no-pnet-cache, 155.6s |
| 3b | fork-prop-network + with-forked-network | ✅ | `1462fd6` — O(1) CHAMP structural sharing |
| 3c | Fork integrated into test-support | ✅ | `81b5c21` — macro hygiene fix |
| 3d | process-string scoping fix — ALL GREEN | ✅ | `41b67c4` — 382/382, 149.0s (38% improvement). Root: box mutation leak. |
| 4 | Absorb PM 8F deferrals (partial) | ✅ | `f896887` — defaults at solve-time ✅. CHAMP fallback RETAINED (expander needs it). 143.9s |
| 5 | Drop `#lang prologos` + remove CHAMP fallback | 🔄 | Pivot: expander.rkt only consumer of CHAMP fallback. Drop `#lang`, delete expander+main+repl-support, remove fallback, delete zonk-final |
| 6 | Parameter reduction (incremental) | ⬜ | Architectural cleanup, scope TBD |
| 7 | Verification + A/B benchmarks + PIR | ⬜ | Compare against Pre-0 baselines + per-file regression check |

**Deferred to Track 10b**: Test-granular scheduling via Places (per-test
work items, eliminates tail effect). Requires: test discovery infrastructure,
Place worker module, place-channel result serialization. Target: <150s.
Pragmatic interim: split test-stdlib into ~10 smaller files (Option C).

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

### 2.5 Three-Layer Fork Model (D.3)

Test isolation uses three layers of CHAMP fork, each inheriting from the
layer above via structural sharing:

```
Layer 1: prelude-network (process-wide, frozen, deserialized from .pnet)
  │       Contains: all 63 prelude module definitions, registries, trait instances
  │       Lifetime: entire process
  │       Mutation: NONE (frozen after deserialization)
  │
  ├── Layer 2: test-file-network (per-file, custom definitions)
  │       Contains: prelude + test-file setup (ns declaration, helper defs, custom types)
  │       Lifetime: all tests in one file
  │       Mutation: during setup only, frozen after
  │       Created by: fork from prelude + elaborate file-level definitions
  │
  │   ├── Layer 3: test-case-network (per-test, ephemeral)
  │   │       Contains: file + one test expression's metas, constraints, errors
  │   │       Lifetime: one test case
  │   │       Mutation: during test execution
  │   │       Created by: fork from test-file-network (287ns for 5000 entries)
  │   │       Discarded: after test assertion
  │   │
  │   ├── Layer 3: (next test case...)
  │   └── ...
  │
  ├── Layer 2: (next test file...)
  └── ...
```

**Custom parameterizations become cell writes in the fork:**

```racket
;; Current: parameterize (15+ bindings)
(define-values (env run run-last)
  (make-shared-env
    (parameterize ([current-solver-strategy 'bfs]
                   [current-special-flag #t]
                   ;; ... 13 more bindings
                   )
      "(ns test-foo)\ndef helper := ...")))

;; Track 10: fork-with (cell writes, not parameterize)
(define test-file-network
  (fork-with prelude-network
    [solver-strategy-cell 'bfs]
    [special-flag-cell #t]
    (elaborate "(ns test-foo)\ndef helper := ...")))

(define (run-last s)
  (with-fork test-file-network
    (last (process-string s))))
```

`fork-with` creates a CHAMP fork, applies cell writes for custom state,
elaborates file-level definitions, returns a frozen network. `with-fork`
creates an ephemeral fork for one test case and discards after.

**D.3 Code Reality Audit — parameter classification:**

Of the 21 parameters in `run-ns-last` (test-support.rkt:130-154):
- **11 become cells** in the network (per-file/per-test state): prelude-env,
  module-definitions, definition-cells, definition-dependencies, cross-module-deps,
  ns-context, mult-meta-store, definition-cell-ids, module-registry-cell-id,
  ns-context-cell-id, defn-param-names-cell-id
- **7 are shared prelude values** that become cell reads from the prelude fork:
  module-registry, lib-paths, preparse-registry, trait-registry, impl-registry,
  param-impl-registry, persistent-registry-net-box
- **3 are network boxes** that the fork mechanism itself replaces:
  prop-net-box, prelude-env-prop-net-box, ns-prop-net-box

**Registries in the unified prelude `.pnet`** (D.3 audit verified):
- 4/6 registries fully serializable (trait: 29, impl: 156, param-impl: 3, capability: 20)
- 2/6 have named procedures needing re-link (preparse: 12/49 expanders, module: 22/40 foreign fns)
- Persistent registry cells: 27/29 clean, 2 need re-link (coercion-fns, preparse-expanders)
- Same `(foreign-proc name)` / `(preparse-expander name)` mechanism handles all cases

**Realistic parameter reduction: 21 → 3**
- `current-prop-net-box` (the fork)
- `current-output-port` (Racket I/O, can't be a cell)
- `install-module-loader!` (callback, until module loading is fully network-native)

All 7 shared prelude params are cells in the prelude network — forking gives
them for free. All 11 per-file/per-test params are cells written during fork
setup. Only Racket-intrinsic params remain.

**Tests with different prelude configurations** fork from different layers:
- `:no-prelude` tests → fork from empty `raw-network`
- Standard tests → fork from `prelude-network`
- Specialized tests → fork from a `partial-prelude-network`

### 2.6 Test-Granular Scheduling (D.3)

**Current**: Batch workers operate at FILE granularity. Each of 10 workers
gets a test FILE, processes all tests sequentially. The tail effect: 9
workers idle while 1 grinds through test-stdlib (285 tests, 132s).

**Proposed**: Workers operate at TEST granularity. Individual test cases are
work items distributed across workers. No worker is stuck on a large file.

```
Current (file-granular):
Worker 1: [test-stdlib ████████████████████████████████] 132s
Worker 2: [test-list-extended ██████████] [test-eq-ord ████] 69s + 45s
...
Worker 10: [test-parser █] [test-reader █] 6s + 1s → idle 125s

Proposed (test-granular):
Worker 1: A-1, A-5, A-9, B-1, C-3, ...  (evenly distributed)
Worker 2: A-2, A-6, A-10, B-2, C-4, ...
...
Worker 10: A-4, A-8, B-5, C-2, D-1, ...  (all finish ~simultaneously)
```

**Architecture:**

```
Main process (or coordinator):
  1. Pre-generate .pnet files for prelude + all test-file setups
  2. Discover individual tests across all files
  3. Build work queue: [(file-A, test-1, expected), (file-A, test-2, ...), ...]

10 Racket Places (one per core):
  Each Place:
    - Deserialize prelude from .pnet (~50ms, once)
    - file-cache: hash of file → frozen test-file-network
    Loop:
      - Receive (file, test-expr, expected) from coordinator
      - Get-or-create file network from cache:
          cache miss → deserialize from .pnet (~5ms) or elaborate (~100ms)
          cache hit → reuse (0ms)
      - Fork file-network → run test → check result → discard fork
      - Report (test-id, pass/fail, time) to coordinator
```

**Why Racket Places, not threads**: Racket green threads don't use multiple
cores. Places are Racket's multi-core primitive — separate memory spaces
connected by place-channels. Each Place deserializes its own prelude from
`.pnet` (fast: ~50ms). The `.pnet` files are the sharing mechanism — not
in-memory CHAMP sharing (which requires same-process threads).

**Performance estimate:**

| Metric | Current | Target |
|--------|---------|--------|
| Prelude load per worker | ~20s (elaborate) | ~50ms (deserialize) |
| File setup per worker | ~100ms (elaborate once) | ~5ms (.pnet cache) |
| Tail effect | 132s (test-stdlib pins 1 worker) | ~13s (285 tests across 10 workers) |
| Memory per worker | ~130MB (full prelude in memory) | ~6MB (.pnet) + working set |
| Total wall time | ~240s | Target <150s |

**Test discovery**: Requires either:
- **(A)** Parse test files to extract `check-equal?` / `test-case` blocks
  (complex, fragile — test syntax varies)
- **(B)** A test registration API: each test file exports a list of named
  test thunks. The runner discovers them via `dynamic-require`.
- **(C)** Keep file-level granularity but split large files into smaller
  ones. Simpler, no infrastructure change, but manual.

Option B is most principled. Option C is most pragmatic for Track 10
(split test-stdlib into test-stdlib-01 through test-stdlib-10, each ~30
tests). Option B can be a Track 10b follow-up.

**Thread-safe output**: Test results from 10 Places collected via
place-channels. Each Place sends `(test-id pass/fail wall-ms)` messages.
Coordinator collects, aggregates, reports. No interleaving.

### 2.7 Module Network Serialization (`.pnet` files)

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
| Cell values (type exprs, definitions) | `struct->vector` trees | ~50 bytes/def |
| Registry contributions (ctor, trait, preparse, subtype, coercion) | tagged vectors | ~2KB/module |
| Specs (614 across prelude) | tagged vectors | ~3KB/module |
| Definition-locations (30,908 across prelude) | symbol→location pairs | ~5KB/module |
| Module metadata (exports, namespace) | symbols/lists | ~0.5KB/module |
| Definition-to-cell-id mappings | symbol→int (for ID remapping) | ~0.5KB/module |
| Source hash (staleness check) | SHA-256 | 32 bytes |
| Foreign function names (re-linked on load) | symbols | ~0.1KB/module |

| NOT serialized | Why |
|---------------|-----|
| Propagators | Already fired — inert. Mechanism, not result. |
| Worklist | Empty after quiescence |
| Contradiction state | Clean after successful elaboration |
| Racket procedures (foreign impls) | Not serializable; re-linked by name |
| Macros (0 in prelude) | Not serializable; re-parse if needed |

**D.3 audit finding**: Round-trip tested on ALL 40 prelude modules.
18 modules serialize+deserialize cleanly (22→157KB each). 22 modules
contain Racket procedures (foreign function implementations) that require
re-linking on deserialize. Total serialized size: ~5.9MB across all modules.

**Foreign function re-linking**: Foreign definitions store a Racket
procedure (e.g., `char-upcase`). On serialize, replace with `(foreign-proc
char-upcase)`. On deserialize, look up in Racket namespace:
`(namespace-variable-value 'char-upcase)`. This is dynamic linking.

Estimated total: ~150KB per module × 63 = ~9.5MB for full prelude `.pnet`
cache (larger than D.2's estimate due to specs + definition-locations).

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

#### 2.5.4 Serialization Mechanism: `struct->vector` + Tag Dispatch (D.3)

**D.2 proposed Racket `fasl`.** D.3 self-critique found that `fasl` does NOT
work for our structs — `fasl->output` requires `#:prefab` structs, and
`racket/serialize` requires `serializable-struct`. Our 326 struct types are
`#:transparent` with `gen:equal+hash` and `prop:ctor-desc-tag`, which neither
mechanism supports without invasive changes.

**D.3 mechanism: `struct->vector` + `write`/`read` + tag dispatch reconstruction.**

Racket's `struct->vector` converts any transparent struct to a tagged vector:
`(expr-Pi 'mw Int Bool)` → `#(struct:expr-Pi mw Int Bool)`. Vectors round-trip
through `write`/`read` natively. Reconstruction dispatches on the tag symbol
to call the correct constructor.

**Why this works for ALL our types:**
- `struct->vector` ignores `gen:equal+hash` (reads raw fields) → expr-meta works
- Reconstruction calls the constructor → `prop:ctor-desc-tag` is re-attached
- `#:transparent` structs support `struct->vector` by definition
- No struct definition changes needed — zero blast radius

```racket
;; Serialize: recursively convert struct trees to vector trees
(define (deep-struct->serializable v)
  (cond
    [(struct? v)
     (define vec (struct->vector v))
     (vector-map deep-struct->serializable vec)]
    [(pair? v)
     (cons (deep-struct->serializable (car v))
           (deep-struct->serializable (cdr v)))]
    [(hash? v)
     (for/hasheq ([(k val) (in-hash v)])
       (values k (deep-struct->serializable val)))]
    [else v]))  ;; symbols, numbers, strings, booleans: already serializable

;; Deserialize: reconstruct structs from tagged vectors
(define (deep-serializable->struct v)
  (cond
    [(and (vector? v) (> (vector-length v) 0)
          (let ([tag (vector-ref v 0)])
            (and (symbol? tag)
                 (string-prefix? (symbol->string tag) "struct:"))))
     (define tag (vector-ref v 0))
     (define fields (for/list ([i (in-range 1 (vector-length v))])
                      (deep-serializable->struct (vector-ref v i))))
     (apply (tag->constructor tag) fields)]
    [(pair? v)
     (cons (deep-serializable->struct (car v))
           (deep-serializable->struct (cdr v)))]
    [(hash? v)
     (for/hasheq ([(k val) (in-hash v)])
       (values k (deep-serializable->struct val)))]
    [else v]))

;; Constructor dispatch — auto-generable from syntax.rkt
(define (tag->constructor tag)
  (case tag
    [(struct:expr-Pi)       expr-Pi]
    [(struct:expr-app)      expr-app]
    [(struct:expr-lam)      expr-lam]
    [(struct:expr-meta)     expr-meta]
    [(struct:expr-Nat)      (lambda () (expr-Nat))]
    [(struct:expr-Bool)     (lambda () (expr-Bool))]
    ;; ... ~50 commonly-occurring types
    ;; Auto-generated by: grep '(struct expr-' syntax.rkt | gen-dispatch
    [else (error 'tag->constructor "unknown tag: ~a" tag)]))
```

**Maintenance surface**: One `case` statement in `tag->constructor`. When a
new struct is added to syntax.rkt, add one line. Compare with custom
serialization (Option 3): two full functions with per-field handling for each
struct. The dispatch table can be AUTO-GENERATED from syntax.rkt by a build
script — zero manual maintenance.

**Performance**: `struct->vector` is ~10ns/struct. `write` on vectors is
Racket-native. Reconstruction via constructor call is ~10ns. For a module
with ~1000 struct instances in its env: ~20μs conversion + file I/O.

**The closure problem**: Macros are syntax transformers = Racket closures.
`struct->vector` doesn't help with closures. Resolution: store macro SOURCE
(S-expressions from the parse) in the `.pnet`, re-parse on deserialize.
Parsing a macro definition is microseconds.

**Cell-id stability**: Cell IDs must be deterministic (same source → same IDs)
OR remapped on deserialize. Deterministic assignment is simpler: use a
counter starting from 0, assigned in definition order. Same source file →
same definition order → same cell IDs. If a dependency changes, the module
is re-elaborated (staleness check catches it) → fresh IDs.

**D.3 audit verification**: Tested `struct->vector` on our actual struct types.
`expr-Pi 'mw Int Bool` → `#(struct:expr-Pi mw Int Bool)`. Tag is `struct:expr-Pi`
(symbol). Fields are preserved. Read-back produces identical vector.
Reconstruction via `(expr-Pi fields...)` produces correct struct with all
properties (`prop:ctor-desc-tag`, `gen:equal+hash`) intact.

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

## D.3 Self-Critique Findings

### D.3.1 Serialization Mechanism (Critical — changed design)

**D.2 proposed**: Racket `fasl` (Fast Assembly Language) format.

**D.3 found**: `fasl->output` is NOT available in our Racket 9.0 installation
(`compiler/fasl` module not found). `racket/serialize` requires
`serializable-struct` — would require changing 326 struct definitions.
Regular `#:transparent` structs do NOT round-trip through `write`/`read`
(read-back loses struct type identity: `test-struct? → #f`).

**Tested alternatives**:
- `#:prefab`: round-trips through `write`/`read` but CAN'T have
  `gen:equal+hash` (expr-meta) or `prop:ctor-desc-tag` (SRE dispatch).
  **Not viable.**
- `serializable-struct`: works, but requires changing 326 definitions.
  **Too invasive.**
- `struct->vector` + tag dispatch: **works.** Zero struct changes, handles
  `gen:equal+hash`, handles `prop:ctor-desc-tag` (re-attached on
  reconstruction). See §2.5.4 for mechanism.

**Lesson**: Test serialization mechanisms on ACTUAL types before designing
around them. D.2 assumed `fasl` compatibility without testing.

### D.3.2 Snapshot Retirement Breaks Non-Network Contexts (Medium)

**Phase 5 (snapshot retirement)** removes `env-snapshot` from `module-info`.
All definition lookups would go through cell reads, requiring a live network.

**Problem**: Error formatting (`format-type-error`), REPL pretty-printing,
and exception handlers run in `catch` blocks that may not have the network
in scope. These code paths currently read from `env-snapshot` (a hasheq
that doesn't need a network).

**Resolution options**:
- **(A)** Generate a frozen hasheq from cells at module-load time — but
  this is env-snapshot under a different name. Still dual-path.
- **(B)** Ensure ALL code paths have network access — thread the network
  through catch blocks, error formatters, pretty-printers.
- **(C)** The `.pnet` deserialized state IS a hasheq (the serialized form
  is vectors/lists, which `tag->constructor` reconstructs). Keep the
  deserialized form as the "frozen view" for non-network reads.

**D.3 recommends (C)**: The `.pnet` round-trip naturally produces a
non-network-dependent data structure. Module definitions are cells during
elaboration (live network) and serialized vectors on disk (`.pnet`). After
deserialization, both the cells AND the deserialized hasheq exist — but the
hasheq is generated FROM the cells, not maintained alongside them. This is
one-path (cells are source of truth) with a generated read-only view for
non-network contexts.

### D.3.3 Phase 1a Is "Network-Available," Not "Network-Native" (Low)

**D.2 claimed**: Phase 1a makes module loading "on the network."

**D.3 reality**: Phase 1a sets `current-prop-net-box` to a FRESH, ISOLATED
network. No parent, no connection to caller's network. Cross-module
propagation doesn't happen. The network provides cell storage but no
inter-module information flow.

**Assessment**: This is correct for Phase 1a — cross-module propagation
during loading would create ordering dependencies. True network-native
module loading (imports as cell references, cross-module propagation)
is Phase 2. Phase 1a should be described honestly as "network-available
during loading" not "network-native."

### D.3.4 Cell-ID Determinism Not Guaranteed (Medium)

**D.2 claimed**: "Same source → same definition order → same cell IDs."

**D.3 found**: Definition order depends on parse order (deterministic within
a file) but also on IMPORT order (which definitions are imported first).
If two modules import `prologos::data::nat`, the definitions appear in the
caller's env in the order they were imported — which depends on the
`prelude-imports` list order (deterministic) plus transitive dependency
resolution order (also deterministic, but sensitive to dependency graph
structure).

**Assessment**: Currently deterministic because `prelude-imports` is a
fixed list (namespace.rkt:444-599) and dependency resolution is depth-first.
But this is FRAGILE — adding, removing, or reordering an import changes all
downstream cell IDs. The staleness hash catches source changes, but not
import-order changes that don't change source content.

**Mitigation**: On deserialize, remap cell IDs rather than assuming
determinism. Store a `(definition-name → cell-id)` table in the `.pnet`.
On load, create fresh cell IDs and use the table to wire definitions to
the correct cells. This decouples serialization from import order.

### D.3.5 Serialized Modules Can't Incrementally Re-Elaborate (Low for Track 10)

**D.3 found**: `.pnet` files contain cell VALUES but not propagators. A
deserialized module is a snapshot — no propagators to fire if new information
arrives. If a dependency changes, the entire module must be re-elaborated
from source (staleness check → re-serialize).

**Assessment**: Correct for Track 10 (`.zo` model — recompile on change).
For Track 11 (LSP, incremental editing), a richer format may be needed:
serialize propagator DESCRIPTIONS (not closures) so they can be re-installed
on deserialize. This enables incremental re-elaboration: deserialize module
→ re-install propagators → propagate new information from changed dependency
→ only affected cells update.

**Documented as**: `.pnet` v2 requirement for Track 11. Not needed for
Track 10.

### D.3.7 Missing Serialization Content (Critical — from completeness audit)

**D.2's serialization list was incomplete.** Testing on actual prelude modules
revealed:

1. **Specs (614 total)**: Module-info contains specs for import resolution.
   Must be serialized — `(imports [module :refer [name]])` needs to know
   what specs a module exports.

2. **Definition-locations (30,908 total)**: Source location metadata for
   error reporting and IDE features. Must be serialized for correct error
   messages from imported definitions.

3. **Registry contributions**: Each module adds entries to 7 global
   registries (ctor, trait, preparse, subtype, coercion, multi-defn,
   capability). The `.pnet` must serialize WHAT EACH MODULE CONTRIBUTED
   so registries can be reconstructed on deserialize.

4. **Foreign function procedures (22/40 modules affected)**: Env-snapshot
   values contain Racket procedures for foreign functions. `struct->vector`
   exposes them; `format "~s"` prints `#<procedure:...>` which is NOT
   readable. Resolution: serialize the procedure NAME (symbol), re-link
   on deserialize via `namespace-variable-value`.

**Full round-trip test results**: 18/40 modules pass clean round-trip.
22/40 fail due to Racket procedures. With foreign function name
substitution, all 40 should pass. Total serialized size: ~5.9MB.

### D.3.8 Code Reality Audit

**Verified claims**:
- ✅ `current-prop-net-box #f` at driver.rkt:1575 (the root cause)
- ✅ 326 struct definitions in syntax.rkt, all `#:transparent`
- ✅ expr-meta has custom `gen:equal+hash` (syntax.rkt:939-947)
- ✅ `struct->vector` produces tagged vectors for our structs
- ✅ Env-snapshot values are deeply nested `expr-*` struct trees in cons pairs
- ✅ 40 modules in prelude, ~63 total with transitive dependencies, ~8350 total definitions
- ✅ CHAMP fork: 287ns for 5000 entries (Pre-0 benchmark confirmed)

**Corrected claims**:
- ❌ D.2 claimed `fasl` works for our structs → `fasl` NOT AVAILABLE in Racket 9.0
- ❌ D.2 assumed `write`/`read` round-trips structs → transparent structs LOSE type identity
- ❌ D.1 assumed parameterize is the bottleneck → Pre-0 shows 3.4μs (negligible)
- ❌ D.2's serialization list missed: specs (614), def-locations (30,908), registry contributions, foreign procedures
- ❌ D.2 assumed 0 macros was the only closure problem → 22/40 modules have foreign function procedures
- ❌ D.2 estimated ~315KB total → actual is ~5.9MB (specs + locations dominate)

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

**Challenge (D.1)**: Phase 4 (parameter elimination) is the hardest phase
and the most likely to be deferred. Is that a Completeness violation?

**Response**: Pre-0 data CHANGED this assessment. Parameter elimination
(D.1's Phase 4, now Phase 6) is 3.4μs/scope — architecturally nice but
not performance-critical. The Completeness principle is better served by
`.pnet` serialization (Phase 1b), which eliminates the 20s cold-start.
THAT is the "hard thing done right that makes everything else easier."

**D.3 challenge**: Serialized modules don't have propagators — they're
snapshots. Is a network without propagators "complete"?

**Response**: For a LOADED module, yes. The propagators have fired; the
result is final. The module's "interface" to other modules is its
exported definitions (cell values), not its internal propagators. This
is the correct boundary: propagators are the computation mechanism,
cell values are the result. Serializing the result IS complete for the
module's purpose (being imported by other modules).

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
| 1b | `struct->vector` misses a struct field or nested type | Round-trip test on ACTUAL prelude module env-snapshots before building pipeline |
| 1b | Macro closures not serializable | Store macro source, re-parse on load (microseconds) |
| 1b | Cell-id instability across serialization cycles | Store `(name → cell-id)` table in .pnet; remap on deserialize (D.3.4) |
| 1b | `tag->constructor` dispatch table incomplete | Auto-generate from syntax.rkt grep; test with round-trip on all prelude modules |
| 6 | Snapshot retirement breaks callers that assume hasheq | Grep all env-snapshot reads before removing |

---

## 6. Completion Criteria

Track 10 is DONE when:

1. ✅ `current-prop-net-box ≠ #f` during all module elaboration
2. ✅ `.pnet` files generated for all prelude modules (40/40 round-trip verified)
3. ✅ `.pnet` format version header + atomic writes + feature flag
4. ✅ Cold-start prelude load from `.pnet` < 100ms (validated by Pre-0.5)
5. ✅ Three-layer fork: prelude → test-file → test-case with `fork-with`/`with-fork`
6. ✅ `run-ns-last` reduced to 3 params (network box, output port, module loader)
7. ✅ CHAMP fallback removed from `meta-solution/cell-id`
8. ✅ `env-snapshot` removed from `module-info` (`.pnet` frozen view for non-network contexts)
9. ✅ Full suite wall time < 200s (down from ~240s). Track 10b targets <150s.
10. ✅ No individual test file regresses > 2× its pre-Track-10 median (D.4)
11. ✅ All 7401+ tests pass
12. ✅ Acceptance file 0 errors
13. ✅ 40/40 prelude modules pass serialize→deserialize→compare round-trip (D.4)
14. ✅ A/B benchmarks run and compared against Pre-0
15. ✅ Instrumentation cleanup
16. ✅ PIR written per methodology

---

## 7. Deferred Items Absorbed

| Source | Item | Phase |
|--------|------|-------|
| PM 8F Phase 5 | Defaults at solve-time | Phase 5b |
| PM 8F Phase 7 | CHAMP fallback removal | Phase 5a |
| Track 8 B2e | Macros dual-write removal | Phase 5c |
| SRE Track 2B | Polarity inference (independent, not absorbed) | N/A |

---

## 8. NTT Model (D.4)

Modeling Track 10 in NTT syntax revealed 2 gaps in NTT and 5 architectural
findings. Full NTT syntax additions captured in [NTT Syntax Design §15](2026-03-22_NTT_SYNTAX_DESIGN.md).

### 8.1 NTT Gaps Discovered

**Gap 1: NTT had no `serialize` / `deserialize` form.** Serialization is
a fundamental operation for persistent networks. NTT's Level 3 (Network
Types) needed operations for persistence — snapshotting quiescent networks
to disk and restoring them. The new forms carry typed contracts: preconditions
(`:requires [Quiescent Ground]`), exclusions (`:excludes [Propagators Closures]`),
re-linking (`:relinks [ForeignProc] :via dynamic-require`), and validation
(`:validates [FormatVersion SourceHash]`).

**Gap 2: NTT had no `fork` form.** Network isolation via structural sharing
is the mechanism for test isolation, speculation, and incremental compilation.
The new `fork` form specifies what's shared (`:shares [cells propagators
registries]`), what's reset (`:resets [worklist fuel contradiction]`), and
the isolation guarantee (`:isolation :copy-on-write`).

### 8.2 Architectural Findings from NTT Modeling

1. **Serialization and fork are Level 3 operations** on networks, alongside
   `interface`, `network`, `embed`, `connect`. Not cell-level or propagator-level.

2. **Serialization has dependent type preconditions**: `Quiescent` and `Ground`
   are propositions about network state. NTT's dependent types express these
   as `:requires` constraints.

3. **Module re-loading is non-monotone**: `stale → loading` reverses the
   status lattice. NTT `:mode monotone` flags it. Resolution: re-elaboration
   is a barrier stratum operation.

4. **Import wiring is data-dependent fan-out**: number of wired cells depends
   on module's export count. NTT `functor` handles this — the import-wire
   propagator is a functor instantiated from module metadata.

5. **Closures in cells are an optimization cache**: the NTT-typed form of a
   preparse registry entry is `(module-path × symbol)`, not a closure. The
   closure is derived. The serialized form IS the NTT-correct representation.

### 8.3 NTT Speculative Syntax for Track 10

```prologos
;; Module as a serializable persistent network
serialize prelude-snapshot : Snapshot PreludeNet
  :format :pnet-v1
  :requires [Quiescent prelude] [Ground prelude]
  :excludes [Propagators Closures]
  :relinks  [ForeignProc PreparseExpander]
    :via dynamic-require
  :gensyms  :tagged
  :source-hash :sha256

deserialize prelude-restore : PreludeNet
  :from prelude-snapshot
  :validates [FormatVersion SourceHash]
  :fallback elaborate-from-source

;; Three-layer fork for test isolation
fork test-file : PreludeNet -> FileNet
  :shares [cells propagators registries]
  :resets [worklist fuel contradiction]
  :lifetime :per-file

fork test-case : FileNet -> CaseNet
  :shares [cells propagators registries]
  :resets [worklist fuel contradiction metas constraints]
  :lifetime :ephemeral
```

---

## 9. D.4 External Critique Integration

### 9.1 Accepted (11 items)

| # | Recommendation | How incorporated |
|---|---------------|-----------------|
| 1 | `.pnet` format version | Version header in serialized file. Deserialize validates before processing. |
| 2 | Defer test-granular to Track 10b | Phase 3b removed. Target → <200s. <150s is Track 10b stretch. |
| 3 | Specify `fork-prop-network` | Added: share cold+warm.cells, reset hot (worklist/fuel), reset contradiction. ~5 lines of struct-copy. |
| 4 | Enumerate mutable state | Added: table of mutable state (boxes, hasheqs, callbacks) + fork handling. |
| 5 | `dynamic-require` for re-linking | Replaces `namespace-variable-value`. Store `(module-path . symbol)` pairs. More robust. |
| 6 | Pre-0.5 benchmark | Added as phase. Time full serialize/deserialize of actual prelude state. |
| 7 | Fix fasl references in Phase 1b | Replaced with `write`/`read` throughout. |
| 8 | Specify gensym handling | Documented: `symbol-interned?` detection, `$$N` tagging, per-module table, identity within module preserved. |
| 9 | Per-module vs unified .pnet | Clarified: per-module files for granular invalidation, unified in-memory snapshot composed from per-module files. |
| 10 | Atomic write | `write` to temp file, `rename-file-or-directory`. Prevents half-written corruption. |
| 11 | Feature flag | `current-use-pnet-cache?` parameter. `#f` = source elaboration (current behavior, rollback path). |

### 9.2 Pushed Back (2 items)

**10.5 (module loader callback)**: The reviewer worried the callback closes
over stale state. In our codebase, `install-module-loader!` installs a
closure that reads `current-module-registry` via the PARAMETER (dynamic
scoping), not a captured value. In a fork, the parameter reads the fork's
value. No shared-mutable-state bug. Verified in driver.rkt:1754.

**10.3 (prop-network is not a CHAMP)**: Accepted the naming correction
("fork-prop-network" not "champ-fork") but pushed back on the implication
that the mechanism is fundamentally different. It's the same structural
sharing, at the struct level rather than CHAMP level.

### 9.3 Mutable State Enumeration (D.4 item 4)

| State | Location | Mutable? | Fork handling |
|-------|----------|----------|---------------|
| `current-prop-net-box` | metavar-store.rkt | box (mutable) | Each fork gets own box ✅ |
| `current-mult-meta-store` | metavar-store.rkt | make-hasheq (mutable) | Must become immutable cell in fork |
| `current-meta-store` | metavar-store.rkt | make-hasheq (mutable) | Must become immutable cell in fork |
| `current-constraint-store` | metavar-store.rkt | make-hasheq (mutable) | Must become immutable cell in fork |
| `install-module-loader!` | driver.rkt | callback (shared) | Intentionally shared — reads params dynamically |
| prop-net-warm.cells | propagator.rkt | CHAMP (immutable) | Shared via structural sharing ✅ |
| prop-net-cold.* | propagator.rkt | CHAMPs (immutable) | Shared via structural sharing ✅ |
| prop-net-hot.worklist | propagator.rkt | list (mutable only during quiescence drain) | Reset to '() in fork ✅ |

### 9.4 `fork-prop-network` Specification (D.4 item 3)

```racket
(define (fork-prop-network net)
  (struct-copy prop-network net
    [hot (prop-net-hot '() (default-fuel))]      ;; fresh worklist + fuel
    [warm (struct-copy prop-net-warm (prop-network-warm net)
            [contradiction #f])]))                ;; no inherited contradiction
    ;; cold: shared (merge-fns, propagators, etc. — immutable)
    ;; warm.cells: shared (CHAMP — CoW on write)
```

O(1): two struct allocations. All CHAMP fields structurally shared.

---

## 10. Open Questions — Resolution Status

| # | Question | Status | Resolution |
|---|----------|--------|------------|
| 1 | 41 params: cells vs Racket-intrinsic? | **Partially resolved** | ~3-5 Racket-intrinsic (output-port, error-port, directory, custodian). Rest → cells. Phase 6 per-parameter audit. |
| 2 | Parallel module loading? | **Deferred** | Serial is correct + simple. Not needed for targets. |
| 3 | Registry ↔ prelude network merge? | **Resolved: YES** | One unified prelude network. Both persistent, both shared. |
| 4 | `install-module-loader!` pattern? | **Reduced** | .pnet simplifies loader. 7 call sites persist until Phase 6. |
| 5 | Batch worker compatibility? | **Resolved: simpler** | .pnet replaces save/restore. Each Place deserializes once. |
| 6 | Serialization mechanism? | **Resolved** | `struct->vector` + tag dispatch. Tested 40/40 modules. |
| 7 | Macro serialization? | **Resolved: non-issue** | 0 macros in prelude. User macros: store source, re-parse. |
| 8 | Cell-id determinism? | **Resolved: remap** | Store `(name→cell-id)` table in .pnet. Remap on deserialize. |
| 9 | Incremental invalidation? | **Resolved: full rebuild** | Re-serialize all stale + dependents. Simple. Track 11 for incremental. |
| 10 | Pre-compilation tool? | **Resolved: YES** | `tools/pnet-compile.rkt`. Integrates with test runner pre-step. |
| 11 | Non-network contexts? | **Resolved** | .pnet deserialized form = frozen read-only view (D.3.2). |
| 12 | Gensym round-trip? | **Resolved** | `symbol$$N` tagging. Per-module gensym table. 40/40 verified. |
| 13 | Foreign function procedures? | **Resolved (D.4 revised)** | `(module-path . symbol)` pairs. Re-link via `dynamic-require` (not namespace-variable-value). 22/40 modules affected. |
| 14 | Specs + def-locations serialization? | **Resolved: include** | 614 specs + 30,908 locations. Must be in .pnet for import resolution + error messages. |
| 15 | Test custom parameterizations? | **Resolved** | Three-layer fork: cell writes in Layer 2 fork replace parameterize. `fork-with` API. |
| 16 | Test-granular scheduling? | **Deferred to Track 10b** (D.4 critique: separate infrastructure project) | Option C (split large files) in Track 10. Full Places-based scheduling in Track 10b. |
| 17 | Can registries go into the prelude .pnet? | **Resolved: YES** | 4/6 clean, 2/6 need named-proc re-link. Same mechanism as foreign-proc. Persistent registry cells: 27/29 clean. Unified .pnet = modules + registries + cells. |
| 18 | Realistic parameter count after fork? | **Resolved: 21 → 3** | D.3 classified all 21: 11→cells, 7→prelude fork reads, 3→fork mechanism. Remaining: network box, output port, module loader. |
| 19 | expander.rkt network-awareness? | **Resolved: PIVOT** | Expander is sole consumer of CHAMP fallback. Drop `#lang prologos` support entirely — all code lives in `.prologos` files via `process-file`. Eliminates expander.rkt, main.rkt, repl-support.rkt, CHAMP fallback, 5 unconverted zonk-final sites. |

---

## 11. Phase 5 Pivot: Drop `#lang prologos`

### Rationale

The Phase 4 finding: `expander.rkt` is the ONLY consumer of the CHAMP
fallback. It runs in Racket's compile-time phase (phase 1) where the
propagator network, .pnet cache, and fork model don't exist. Making
it network-native requires bridging Racket's phase boundary — a
substantial infrastructure project for 6 test files.

The alternative: drop `#lang prologos` support entirely. ALL Prologos
code already lives in `.prologos` files processed by `process-file`.
The `#lang` path is historical — predates our module system, LSP
server, and .pnet cache.

### What gets deleted

| File | Lines | Purpose | Replacement |
|------|-------|---------|-------------|
| `expander.rkt` | 261 | `#lang prologos` compiler | `process-file` |
| `main.rkt` | 73 | `#lang prologos` entry point | None needed |
| `repl-support.rkt` | 68 | DrRacket REPL support | LSP server |
| 6 test-lang-* files | ~400 | `#lang` integration tests | `.prologos` acceptance files |

### What gets eliminated

- **CHAMP fallback** in `meta-solution`, `meta-solved?`, `ground-expr?` — sole consumer removed
- **`zonk-final`** — 5 unconverted sites in expander.rkt deleted. Zero remaining callers.
- **Phase 5 design concern** — expander network integration becomes moot
- **Racket phase-separation constraint** — no more phase-1 code

### Impact on interactive development

| Workflow | Before | After |
|----------|--------|-------|
| Edit in VSCode | LSP via `process-string-ws` | Same — unchanged |
| Run a file | `process-file "foo.prologos"` | Same — unchanged |
| REPL testing | `run-ns-last` via test-support | Same — unchanged |
| DrRacket REPL | `#lang prologos` + repl-support | Removed — use VSCode + LSP |

No impact on any actively used workflow. DrRacket REPL support is
the only loss, and it's unused (we use VSCode + LSP).

---

## 12. Track 10B Scope

Track 10B collects deferred items from Track 10 + related follow-on work:

| Item | Source | Description |
|------|--------|-------------|
| Test-granular scheduling | D.4 critique | Places-based per-test scheduling. Target <150s. |
| Remaining zonk elimination | PM 8F Phase 5+7 deferrals | 13 remaining `zonk`/`zonk-at-depth` calls in unify.rkt (5) + resolution (8). Requires metas-as-cells completion (expressions reference cells, not expr-meta). |
| `zonk.rkt` cleanup | Track 10 Phase 5 | After `zonk-final` deleted (Phase 5) and remaining zonk calls eliminated, `zonk.rkt` (~1300 lines) can be removed entirely. `freeze` (~200 lines in driver.rkt) is the replacement. |
| Transitive staleness | Open Q #9 | .pnet invalidation for transitive deps (module A changes → module B that imports A is stale). Currently full-rebuild. Incremental = Track 11. |
| Per-module .pnet (vs unified) | D.4 critique #7 | Granular invalidation. Currently all modules serialize. Per-module = only stale modules re-serialize. |
| `default-metas` at solve-time | PM 8F Phase 5 | Move defaults from boundary time to solve time. Deferred from 8F, absorbed partially in Track 10 Phase 4. Full completion requires level/mult meta solve path changes. |
| CHAMP fallback full removal | Track 10 Phase 4/5 | After Phase 5 drops `#lang prologos`, fallback can be removed from meta-solution/meta-solved?/ground-expr?. If any remaining path needs it, tracked here. |
| `id-map` elimination | PM 8F Phase 7 | Cell-id in expr-meta makes id-map redundant. Remove id-map, simplify meta-solution to direct cell read. |
