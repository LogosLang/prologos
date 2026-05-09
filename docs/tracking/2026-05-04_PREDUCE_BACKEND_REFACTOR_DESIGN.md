# PReduce-lite + Hybrid: Swappable Backend Refactor — Design Plan

**Date**: 2026-05-04
**Status**: Stage 3 design — implementation begins after user review
**Track**: PReduce / SH (cross-cutting) — refactor of `racket/prologos/preduce.rkt` + `racket/prologos/preduce-hybrid.rkt`
**Branch**: `claude/prologos-layering-architecture-Pn8M9` (this branch)

**Cross-references**:
- [PReduce-lite PIR (consolidated)](2026-05-04_PREDUCE_LITE_PIR.md) — terminal state of the Racket-only reducer
- [Hybrid Runtime PIR](2026-05-04_HYBRID_RUNTIME_PIR.md) — terminal state of the Zig-kernel + Racket-bridge stack
- `racket/prologos/preduce.rkt` (1509 LOC) — current Racket-only reducer
- `racket/prologos/preduce-hybrid.rkt` (407 LOC) — current Zig-kernel host (Phase 8b scope only)

---

## 1. Motivation

Today there are **two separate reducer implementations** that share ~all of compile-expr's logic but duplicate the code because their backend primitives differ:

| Aspect | preduce.rkt | preduce-hybrid.rkt |
|---|---|---|
| Cell allocation | `net-new-cell net bot merge` returns `(values net cid)` | `(prologos_cell_alloc)` returns `cid` (kernel-side state) |
| Propagator install | `net-add-fire-once-propagator net inputs outputs fire-fn` | `prologos_propagator_install_n_1 tag inputs cid-out` (after `allocate-fresh-callback!`) |
| Cell value model | arbitrary Racket values held directly (struct, expr, primitive) | tagged-i64 (8-bit tag + 56-bit payload) + handle table for non-tagged values |
| Threading style | functional — `net` threaded through every call as `(values cid net)` | side-effecting — kernel state is implicit FFI library state |
| Fire-fn registration | first-class closure passed to net-add-* | callback registered at a fresh tag via `allocate-fresh-callback!` |
| Coverage today | Phases 1–15 + 10b (~120 AST node cases) | Phase 8b only (~20 AST node cases) |

The duplication has costs:
- **Phase 10/10b on hybrid is a port, not a "wire it up."** ~150-250 LOC of compile-expr logic must be re-written against hybrid primitives. Same for any future preduce-lite phase.
- **Two files to keep in sync.** Bug fixes, optimizations, semantic clarifications must land twice. Already paid: `current-fvar-stack` + `statically-reducible-lam` are duplicated verbatim with the same comments.
- **Three-way differential gate is the only forcing function.** The 13/13 differential between `nf` ≡ `preduce` ≡ `preduce-hybrid` catches semantic divergences but not sooner-better feedback (per-test, per-case).
- **Pattern repeats**: `runtime/core/` factored cells/profile/format from the Zig kernels, but the BSP scheduler stayed unfactored (hybrid PIR §15 debt). The Racket reducer + hybrid reducer parallel is the same shape one layer up.

The refactor: **factor compile-expr into a backend-agnostic core, parameterized by a backend interface.** The two existing reducers become thin entry points that wire their respective backends into the shared core.

---

## 2. Audit — What's Shared, What's Specific

### 2.1 Shared (both reducers do the same thing)

These are mechanically the same in both files; only the primitive calls differ:

- **AST dispatch shape**: `match e` on AST nodes, recursive descent with `env` for bvar bindings
- **Static fast-paths**: `(expr-fst (expr-pair a b))` → return cid-a directly; `(expr-vhead (expr-vcons _ _ h _))` → return cid-h; `(expr-app (expr-lam _ _ body) arg)` → static-β
- **Recursion guard**: `current-fvar-stack` parameter for self-recursive fvar inlining (duplicated verbatim)
- **`statically-reducible-lam`**: walk an fvar to its def value, check if it's a lambda; recursion-guarded (duplicated verbatim)
- **Phase boundaries**: same Phase 1–15 + 10b conceptual structure
- **AST node coverage criterion**: same hard-error policy on unsupported nodes
- **Stuck-value structs**: `preduce-lam` / `preduce-pair` / `preduce-vcons` / `preduce-user-ctor` (preduce.rkt) parallel `preduce-hybrid-lam` / `preduce-hybrid-pair` (hybrid). Same shape, separate types.

### 2.2 Backend-specific (the diverging primitives)

| Operation | preduce.rkt | preduce-hybrid.rkt |
|---|---|---|
| Allocate fresh cell with initial value | `alloc-value-cell net v → (values cid net)` | `(define cid (prologos_cell_alloc)) (prologos_cell_write cid (box-value v)) cid` |
| Read cell | `(net-cell-read net cid)` | `(unbox-prologos-value (prologos_cell_read cid))` |
| Write cell | `(net-cell-write net cid v)` | `(prologos_cell_write cid (box-value v))` |
| Install fire-once propagator | `(net-add-fire-once-propagator net inputs outputs fire-fn)` | `(define tag (allocate-fresh-callback! arity fire-fn)) (prologos_propagator_install_n_1 tag inputs cid-out)` |
| Install plain (re-fireable) propagator | `(net-add-propagator net inputs outputs fire-fn)` | n/a — hybrid only has fire-once today |
| Run to quiescence | `(run-to-quiescence net)` | `(prologos_run_to_quiescence)` |
| Reset between calls | construct fresh `prop-network` | `(reset-handle-table!)` + kernel state survives but cell IDs reset |
| Box/unbox cell value | identity (Racket value held directly) | `box-prologos-value` / `unbox-prologos-value` (tagged-i64 + handle indirection) |

### 2.3 Threading style — the structural divergence

**preduce.rkt threads `net`** through every compile-expr call. Every primitive returns `(values cid net*)`. The reducer is pure functional over the network value.

**preduce-hybrid.rkt is side-effecting** on the kernel's implicit state. compile-expr-hybrid returns just `cid`; the kernel state mutates underneath.

**Reconciliation**: keep functional threading throughout. preduce.rkt's existing `(values cid net)` shape is correct as-is; the hybrid backend wraps the kernel's implicit state in a unit/sentinel `net` value to preserve the threading discipline. The cost is one extra value passed and returned per primitive call (negligible at the Racket layer; multi-value return is fast in Racket-CS).

**Why functional, in-and-out-of-native**: the SH Track 1 deliverable is "`.pnet` network-as-value" — networks become first-class values that round-trip through cells. When compile-expr eventually runs natively (SH Track 9: compiler-in-Prologos), it IS a propagator program over network-valued cells:

- AST is a cell value (input)
- The compiled propagator network is a cell value (output)
- compile-expr is a propagator: reads AST cell, writes network cell
- A fire-fn that "installs another propagator" needs the network as input/output — it can't side-effect a network it doesn't hold a reference to

That target world demands functional threading. Side-effecting is a convenience for the bring-up vehicle but a dead-end for self-hosting:

| | Functional (chosen) | Side-effecting |
|---|---|---|
| preduce.rkt surgery | none (unchanged) | ~80 call-site flip |
| preduce-hybrid.rkt surgery | wrap with fake-threaded sentinel (~50 LOC) | minor (already side-effecting) |
| Native target fit (SH Track 9) | ✅ matches network-as-value | ❌ ambient state has no analogue |
| `current-bsp-fire-round?` hack retirement path | retires when native (the parameter becomes the threaded net itself) | persists |
| `.pnet` round-trip (SH Track 1) | natural | needs retrofit |

The threading IS the dataflow edge in native execution. Preserving it today is "for free" in the architectural sense — it's already preduce.rkt's shape.

**Implication for the backend interface**: every primitive accepts and returns the net. For `backend-racket`, net is the actual `prop-network` struct (today's threading). For `backend-hybrid`, net is a sentinel value (e.g., `'hybrid-kernel-state`) — formal threading; the kernel state mutates underneath. For a future `backend-native`, net is a cell-id pointing to the network value being built — threading IS real dataflow.

### 2.4 Coverage gap — preduce-hybrid is at Phase 8b only

The hybrid host today covers ~20 AST cases; preduce.rkt covers ~120. The shared core after refactoring would expose all ~120 cases, but the hybrid backend would error on the unsupported ~100 because it lacks the kernel-side fire-fn implementations.

Two strategies for the gap:
- (i) **Backend capability flags**: each backend declares which operations it supports; the shared core checks and either dispatches or errors with "this backend doesn't support node X yet."
- (ii) **Backend-shared callbacks**: each AST case's fire-fn is written once (using the abstract interface); the hybrid backend's `allocate-fresh-callback!` wraps the Racket fire-fn into a kernel callback. This means the hybrid kernel runs Racket callbacks for everything not yet migrated to native — exactly the model the hybrid was designed for (per Phase 10 migration loop).

**Strategy (ii) is the clear winner.** It means the refactor is what unblocks OCapN-on-hybrid: as soon as preduce-lite Phase 10b lands in the shared core, the hybrid can run user-defined-ctor matches (via Racket callback) without any port work. Then Phase 10's profile-driven migration replaces individual hot callbacks with native fire-fns, just like today's identity bridge.

---

## 3. Design — The Backend Interface

### 3.1 Interface shape

A "backend" is a struct exposing these operations, all threading `net`:

```racket
(struct preduce-backend
  (alloc-cell           ;; net × value → (values cid net')
   read-cell            ;; net × cell-id → value
   write-cell           ;; net × cell-id × value → net'
   install-fire-once    ;; net × inputs × outputs × fire-fn → net'
   install-propagator   ;; net × inputs × outputs × fire-fn → net'
   run-to-quiescence    ;; net → net'
   fresh-net            ;; → net   (constructs a starting net for each (preduce e))
   ))
```

Where `fire-fn : net × (listof cell-id) × (listof cell-id) → net'` — the original preduce.rkt shape. The fire-fn reads its inputs, computes, writes its outputs, returns the threaded net. Same signature today; no inversion needed.

This means **preduce.rkt's existing fire-fns (`make-reduce-fire`, `make-natrec-fire`, etc.) work unchanged** when wrapped in the abstract backend interface — they already take net and do their own cell IO. The shared core just calls `((preduce-backend-install-fire-once b) net inputs outputs fire-fn)` and the fire-fn invocation discipline is preserved.

For the hybrid backend, `install-fire-once` allocates a kernel callback tag and wraps the fire-fn into a callback that bridges between kernel cells (tagged-i64 + handle table) and the Racket fire-fn's value model. The fire-fn itself is unchanged; the bridging is the backend's job.

This is a strictly weaker change than the original plan's "fire-fns become pure value-in/value-out": fire-fns stay net-threaded, which means `make-reduce-fire`'s `compile-and-bridge` recursive compilation (which itself installs more propagators) just works through the abstract backend.

### 3.2 Two concrete backend instances

**`backend-racket`** (`preduce-backend-racket.rkt`):
- `net` is the actual `prop-network` struct (today's threading)
- `alloc-cell` is `net-new-cell net v preduce-merge #:domain 'preduce-value` (just reorders existing call)
- `install-fire-once` is `net-add-fire-once-propagator` (one-line wrapper)
- `run-to-quiescence` is the existing Racket-side run-to-quiescence
- `fresh-net` constructs a fresh `prop-network`
- Read/write are `net-cell-read` / `net-cell-write`

**`backend-hybrid`** (`preduce-backend-hybrid.rkt`):
- `net` is a sentinel value (e.g., the symbol `'hybrid`) — purely formal threading; the kernel state mutates underneath
- `alloc-cell net v` → `(define cid (prologos_cell_alloc)) (prologos_cell_write cid (box-prologos-value v)) (values cid 'hybrid)`
- `install-fire-once net inputs outputs fire-fn` allocates a fresh callback tag via `allocate-fresh-callback!`, wraps fire-fn into a kernel callback that bridges box/unbox + threading-sentinel; calls `prologos_propagator_install_n_1`; returns `'hybrid`
- `run-to-quiescence net` → `(prologos_run_to_quiescence) 'hybrid`
- `fresh-net` calls `reset-handle-table!` and returns `'hybrid`
- Read/write box/unbox values through the handle table

**Future `backend-native`** (sketch only; not in this refactor):
- `net` is a cell-id pointing to the network value being built
- Each primitive becomes a propagator that reads the net cell, produces an updated network value, writes back
- compile-expr itself becomes a propagator program — the SH Track 9 endpoint

### 3.3 The shared compile-expr (`preduce-core.rkt`)

`compile-expr e env net → (values cid net')` — net-threaded, parameterized by `(current-backend)`:

```racket
;; Pseudo-code sketch (b-alloc / b-install-fire-once are accessor shorthands):
(define (compile-expr e env net)
  (match e
    [(expr-int n)
     (b-alloc (current-backend) net (expr-int n))]      ;; → (values cid net')
    [(expr-pair a b)
     (define-values (cid-a net1) (compile-expr a env net))
     (define-values (cid-b net2) (compile-expr b env net1))
     (b-alloc (current-backend) net2 (preduce-pair cid-a cid-b))]
    [(expr-fst inner)
     (cond
       [(expr-pair? inner) (compile-expr (expr-pair-fst inner) env net)]
       [else
        (define-values (cid-in net1) (compile-expr inner env net))
        (define-values (cid-out net2) (b-alloc (current-backend) net1 preduce-bot))
        (define net3
          (b-install-fire-once (current-backend) net2
                               (list cid-in) (list cid-out)
                               (make-projection-fire cid-in cid-out 'fst)))
        (values cid-out net3)])]
    ...
    ))
```

This is **structurally identical to today's preduce.rkt** — the threading shape (`(values cid net')` everywhere), the make-X-fire patterns, the static fast-paths. The only change is the abstraction layer:
- `(net-new-cell net v ...)` → `(b-alloc (current-backend) net v)`
- `(net-add-fire-once-propagator net ins outs fire-fn)` → `(b-install-fire-once (current-backend) net ins outs fire-fn)`
- `(net-cell-read net cid)` → `(b-read (current-backend) net cid)`
- `(net-cell-write net cid v)` → `(b-write (current-backend) net cid v)`

Mechanical rewrite. fire-fn closures pass through unchanged because they still take `net` and use `b-read` / `b-write` internally.

### 3.4 Stuck-value structs unify

Drop `preduce-hybrid-lam` / `preduce-hybrid-pair`. Both backends use the same `preduce-lam` / `preduce-pair` / `preduce-vcons` / `preduce-user-ctor` structs from `preduce-core.rkt`. The hybrid backend's box/unbox layer handles them transparently — they're stored via the handle table, identical to other non-tagged Racket values.

### 3.5 Backend capability declaration (optional)

Each backend declares its supported AST cases as a (mutable) set. The shared core checks before compiling and errors with a clear "backend X does not yet support AST node Y" — better than the current generic "unsupported AST node" error. Optional: defer until needed. The fire-fn-as-callback strategy from §2.4 means most cases work via the callback path even on hybrid; capability flags are only for cases the hybrid kernel can't even host as a callback (e.g., expr-foreign-fn).

---

## 4. Phased Rollout

| Phase | Description | LOC | Time | Risk |
|---|---|---|---|---|
| **0** | Audit + this design doc | — | done | — |
| **1** | Define `preduce-backend` struct + accessor shorthands (`b-alloc`, `b-read`, `b-write`, `b-install-fire-once`, `b-install-propagator`, `b-run-to-quiescence`, `b-fresh-net`) in `preduce-core.rkt`. Define `current-backend` parameter. No backend instances yet. | ~80 | 30min | low |
| **2** | **Extract** compile-expr + all helpers (`current-fvar-stack`, `statically-reducible-lam`, `try-decompose-user-ctor-app`, `make-X-fire` factories, eliminator dispatch, container compilers, all stuck-value structs) from preduce.rkt to `preduce-core.rkt`. Mechanical rewrite: `net-new-cell` → `b-alloc`, `net-add-fire-once-propagator` → `b-install-fire-once`, `net-cell-read/write` → `b-read/b-write`. fire-fn signatures unchanged (still `net → net'`). **Self-test**: not yet — needs backend instance. | ~1300 LOC moved + ~200 LOC of `b-*` substitutions | 2h | medium — large mechanical move; risk concentrated in getting all `net`-threading sites converted consistently |
| **3** | Build `backend-racket` (`preduce-backend-racket.rkt`). One-line wrappers around `net-new-cell` / `net-add-fire-once-propagator` / etc. preduce.rkt becomes a thin wrapper: imports core + Racket backend, parameterizes `current-backend`, exposes the same public API (`preduce`, `preduce-or-nf`, etc.) for backward compat. **Self-test**: all 88+12+15 = 115 unit tests + 2 differential gates green. | ~80 (backend) + ~80 (preduce.rkt thin wrapper) | 1h | medium — backward-compat surface must be preserved (re-export `preduce-user-ctor`, `preduce-bot`, `current-use-preduce?`, etc.) |
| **4** | Build `backend-hybrid` (`preduce-backend-hybrid.rkt`). Wraps `prologos_cell_*` + `prologos_propagator_install_*` + `allocate-fresh-callback!` + handle table; uses `'hybrid` sentinel as `net`. preduce-hybrid.rkt becomes thin wrapper: imports core + hybrid backend, parameterizes `current-backend`. Discard the old `compile-expr-hybrid` + duplicated helpers. **Self-test**: existing 13/13 three-way differential green. | ~150 (backend) + ~80 (thin wrapper) − ~400 (deleted from old preduce-hybrid.rkt) | 1.5h | medium — fire-fn-as-callback must marshal value boxing correctly; `current-bsp-fire-round? #f` discipline must compose through the FFI |
| **5** | **Bug-shake**: run all 100 preduce-lite unit tests + 15 OCapN tests through the hybrid backend. Most should pass on first run since compile-expr is now shared; any failures localize to backend-hybrid (handle-table fragmentation, bot-propagation, value-box edge cases). Iterate until green. | ~50 (test wiring + backend fixes) | 1.5h | high — first time hybrid sees ~100 new test cases; expect 2-5 backend bugs |
| **6** | Run OCapN-syrup tests through the hybrid kernel with `--profile`. **First non-trivial program on the kernel.** Capture per-tag callback profile; identify top-3 callbacks by `callback_ns_by_tag`. | — | 30min | low — observation only |
| **7** | Migrate top-1 callback to Zig-native (Phase 10's migration loop, applied to a real workload). Re-run with `--profile`; measure callback reduction. | ~30 (Zig) + ~10 (Racket stub remove) | 1h | low — proven loop |
| **8** | PIR for the refactor track. | — | 30min | — |

**Total**: roughly 8-10h. Phase 1+2+3 (~3.5h) lands the Racket refactor with no behavior change. Phase 4+5 (~3h) lands the hybrid backend + shakes out bugs. Phase 6+7 (~1.5h) is the user's stated goal — first OCapN program through the kernel + profile-driven migration on a real workload.

**Dependency on PReduce-lite Phase 10/10b**: ✅ already done — Phase 10b on the Racket side landed 2026-05-04. After Phase 4 lands, hybrid gets Phase 10/10b for free via Racket-callback fire-fns. Phase 7's migration is the first chance to natively replace one of those callbacks.

---

## 5. Risks

1. **Mechanical primitive-rename across ~80 sites in preduce.rkt.** Every `(net-new-cell net ...)` becomes `(b-alloc (current-backend) net ...)`; every `net-add-fire-once-propagator` similarly. Mostly find-and-replace, but easy to miss an occurrence or fat-finger an arg order. Mitigation: keep the per-phase test files green at each phase boundary; the existing 2000-case differential against `nf` is the regression net.

2. **Bot-handling semantics differ between backends.** preduce.rkt's `preduce-merge` returns the new value if old was bot; preduce-hybrid checks `prologos_cell_value_kind == TAG-BOT` explicitly in the callback. The fire-fn signature is unchanged (still `net → net'`), so each backend's `b-read` returns the value in whatever form (Racket-side `preduce-bot` sentinel vs hybrid-side TAG-BOT-tagged). Fire-fns continue to check `(preduce-bot? v)` exactly as today; the hybrid `b-read` unboxes TAG-BOT to `preduce-bot` on the way out. Mitigation: backend interface fixes the value model — `b-read` always returns Racket-side values (so `(preduce-bot? v)` works on both backends).

3. **Tag allocation timing in the hybrid backend.** preduce-hybrid currently allocates a fresh tag per fire-fn install via `allocate-fresh-callback!`. Hot-loop installs (e.g., compile-expr inside dynamic-β) will allocate many tags — risk of `N_TAGS=256` exhaustion. Mitigation: tag-pooling (reuse tags for structurally-identical fire-fns) is a deferred optimization; monitor via `prologos_debug_n_tags` after a real workload.

4. **Test-suite imports during Phase 3.** Tests `require` preduce.rkt for `preduce-user-ctor`, `preduce-bot`, `current-use-preduce?`, etc. preduce.rkt becoming a thin wrapper must preserve those exports via re-export from `preduce-core.rkt`. Mitigation: explicit `(provide (all-from-out "preduce-core.rkt"))` after the require. Audit each test file's required identifiers.

5. **Hybrid-backend Phase 5 expansion will surface bugs.** Today the hybrid covers ~13 differential-tested cases; after Phase 5, it sees the full Phase 1-15 surface. Likely bug classes: handle-table fragmentation under deep nesting, bot-propagation edge cases in eliminators (`expr-natrec` recursive call structure), FQN ctor-name handling in Phase 10b's `lookup-ctor-meta`, callback-fire-fn re-entrancy when a fire-fn installs more propagators (`current-bsp-fire-round? #f` must compose through the FFI). Mitigation: per-test-file iteration; affected-test runner for fast feedback; the existing 13/13 three-way differential as a baseline.

6. **Performance regression risk in preduce.rkt.** The new layer of indirection (`(b-alloc (current-backend) net ...)` vs `(net-new-cell net ...)`) adds 2 lookups per primitive call. For tight loops, this could add 1-3% wall time. Mitigation: define `b-alloc` etc. as inlinable accessors (Racket-CS inlines record-accessor calls on `(current-backend)` if the parameter value is fixed across the call site); benchmark before/after on the existing 7 acceptance files.

7. **`current-bsp-fire-round? #f` discipline through the FFI** (specific to hybrid). The hybrid kernel's BSP scheduling is in Zig; the parameter is a Racket-side construct that controls Racket's `net-add-propagator` behavior. When a Racket-callback fire-fn installs a new propagator into the kernel via `b-install-fire-once`, the kernel-side scheduling does NOT consult the Racket parameter — it auto-schedules per kernel rules. This is *probably* fine (kernel auto-scheduling matches what we want), but needs explicit verification. Mitigation: Phase 4 includes a test that exercises a fire-fn installing another propagator (e.g., dynamic-β → fire-fn → install body propagators), running through the hybrid kernel.

---

## 6. Acceptance Criteria

The refactor is done when:

1. **`preduce-core.rkt` exists** with backend-agnostic compile-expr.
2. **Two thin backend modules** (`preduce-backend-racket.rkt` + `preduce-backend-hybrid.rkt`) wrap their respective primitives.
3. **`preduce.rkt` is a thin wrapper** (≤100 LOC) that imports core + Racket backend + provides the same public API as today.
4. **`preduce-hybrid.rkt` is a thin wrapper** (≤100 LOC) that imports core + hybrid backend.
5. **All 115 unit tests + 2 differential gates green** under both backends.
6. **The 13/13 three-way differential** still green.
7. **OCapN-syrup tests run through the hybrid kernel** (the first non-trivial program on the kernel) with `--profile` showing the callback breakdown.
8. **Phase 10 migration loop validated on a real OCapN workload** (Phase 7 above) — at least one Racket callback migrated to Zig-native, with a measurable callback reduction.
9. **PIR documenting the refactor** lands per the standard 16-question template.

---

## 7. What This Doesn't Solve

To frame scope accurately:

- **Does not unify the two Zig kernels** (original LLVM-target vs hybrid). That's a separate factoring (the BSP-scheduler-into-`core/bsp.zig` debt from the hybrid PIR §15).
- **Does not retire preduce-hybrid-main.rkt's standalone-binary path**. The standalone binary still wraps `preduce-hybrid` via `--nf-fallback`; just the underlying compile-expr changes.
- **Does not change the FFI calibration economics** — forward 14-42 ns, callback 170-180 ns is unchanged; the refactor is purely a code-organization move.
- **Does not implement Phase 11+ on hybrid as native** — those still go through the callback path until profile-driven migration moves them.
- **Does not convert preduce-hybrid's bot-handling into something more efficient** — bot-skip is still a per-fire kernel check.

---

## 8. Connection to Existing Tracks + Debt

This refactor:

- **Pays down the "two parallel implementations" debt** flagged in the hybrid PIR §15 (analogous to the BSP-scheduler-not-in-core debt) at the Racket layer.
- **Unblocks OCapN-on-hybrid** without per-AST-case porting work (Strategy ii in §2.4 — fire-fns become Racket callbacks for free).
- **Validates the "factoring at second-instance" pattern** from PReduce-lite PIR §18 #4 — but now that we have THREE consumers in mind (preduce, preduce-hybrid, future preduce-{distributed/persistent}), the factor lands at the right time.
- **Sets up the profile-driven migration loop on real workloads.** Phase 7 above is the first migration on a non-synthetic program — the architectural premise validated against actual code.

After this lands, the analogous refactor at the **Zig layer** (extract `core/bsp.zig` + `core/worklist.zig` so both kernels share the scheduler) becomes the natural next track. Both factoring decisions wait for a third consumer, but a third Racket reducer (e.g., `preduce-distributed`) is more imminent than a third Zig kernel — so Racket layer first.

---

## 9. Progress Tracker

| Phase | Description | Status | Commits | Notes |
|---|---|---|---|---|
| 0 | Audit + this design doc (Option A revision) | ✅ | (this commit) | — |
| 1 | Define `preduce-backend` struct + accessor shorthands + `current-backend` parameter | ⬜ | — | ~80 LOC; foundation |
| 2 | Extract compile-expr + helpers to `preduce-core.rkt`; primitive-rename to `b-*` | ⬜ | — | ~1300 LOC moved + ~200 LOC primitive renames |
| 3 | Build `backend-racket`; preduce.rkt → thin wrapper | ⬜ | — | All 115 unit tests + 2 differential green |
| 4 | Build `backend-hybrid`; preduce-hybrid.rkt → thin wrapper | ⬜ | — | 13/13 three-way differential green |
| 5 | Run all 115 preduce-lite tests under hybrid backend | ⬜ | — | Bug-shake phase |
| 6 | Run OCapN-syrup through hybrid + capture profile | ⬜ | — | **First non-trivial program on the kernel** |
| 7 | Migrate top-1 hot callback to Zig-native | ⬜ | — | Profile-driven migration on a real workload |
| 8 | PIR | ⬜ | — | 16-question template |

Status legend: ⬜ not started, 🔄 in progress, ✅ done, ⏸️ blocked.

---

**End of design plan.**
