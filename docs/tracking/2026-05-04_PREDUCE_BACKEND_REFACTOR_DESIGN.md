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

**Reconciliation**: the backend interface should be **side-effecting under the hood** (uniform across both backends), with preduce.rkt's network state held in a parameter. This unifies both reducers under the simpler signature `compile-expr e env → cid`. preduce.rkt's existing functional threading becomes "Racket backend installs side-effecting wrappers that read/write `(current-prop-net)`."

This is the load-bearing design decision. Alternatives:
- (A) Both backends threaded — adds scaffolding to hybrid (fake threading); preserves preduce.rkt purity.
- (B) Both backends side-effecting via a `current-prop-net` parameter on the Racket side — minor surgery to preduce.rkt; clean unified shape downstream.

Option B is cleaner. The "purity" preduce.rkt enjoys is mostly internal — callers already see `(preduce e) → expr` which is referentially transparent. Pushing the network into a parameter is a local change to preduce.rkt's compile-expr; everything outside compile-expr is unaffected.

### 2.4 Coverage gap — preduce-hybrid is at Phase 8b only

The hybrid host today covers ~20 AST cases; preduce.rkt covers ~120. The shared core after refactoring would expose all ~120 cases, but the hybrid backend would error on the unsupported ~100 because it lacks the kernel-side fire-fn implementations.

Two strategies for the gap:
- (i) **Backend capability flags**: each backend declares which operations it supports; the shared core checks and either dispatches or errors with "this backend doesn't support node X yet."
- (ii) **Backend-shared callbacks**: each AST case's fire-fn is written once (using the abstract interface); the hybrid backend's `allocate-fresh-callback!` wraps the Racket fire-fn into a kernel callback. This means the hybrid kernel runs Racket callbacks for everything not yet migrated to native — exactly the model the hybrid was designed for (per Phase 10 migration loop).

**Strategy (ii) is the clear winner.** It means the refactor is what unblocks OCapN-on-hybrid: as soon as preduce-lite Phase 10b lands in the shared core, the hybrid can run user-defined-ctor matches (via Racket callback) without any port work. Then Phase 10's profile-driven migration replaces individual hot callbacks with native fire-fns, just like today's identity bridge.

---

## 3. Design — The Backend Interface

### 3.1 Interface shape

A "backend" is a struct (or set of bound parameters) exposing these operations:

```racket
(struct preduce-backend
  (alloc-cell           ;; value → cell-id
   read-cell            ;; cell-id → value (or 'bot)
   write-cell           ;; cell-id × value → void
   install-fire-once    ;; (listof cell-id) × (listof cell-id) × fire-fn → void
   install-propagator   ;; (listof cell-id) × (listof cell-id) × fire-fn → void
   run-to-quiescence    ;; → void
   reset                ;; → void   (call before each (preduce e))
   ))
```

Where `fire-fn : (listof value) → (listof value)` — takes input values, returns output values. The backend is responsible for:
- Reading the input cells (via `read-cell`) before invoking
- Calling fire-fn with concrete (non-bot) input values
- Writing fire-fn's outputs to the output cells (via `write-cell`)
- Handling bot-input semantics (skip fire if any input is bot, until all become concrete)

The fire-fn signature is intentionally backend-agnostic — it operates on plain Racket values. The hybrid backend wraps it in box/unbox to bridge to tagged-i64 + handle table; the Racket backend invokes it directly.

**Caveat**: preduce.rkt's fire-fns today take `net` and call `net-cell-read` / `net-cell-write` themselves (line 882 onward in `make-reduce-fire`). The refactor inverts this: fire-fns take **already-read input values**, return **outputs to be written**. The backend handles cell IO.

This inversion is a moderate change to preduce.rkt's internals but improves clarity — fire-fns are pure functions over values, not mutators of the network.

### 3.2 Two concrete backend instances

**`backend-racket`** (`preduce-backend-racket.rkt`):
- Holds a `current-prop-net` parameter
- `alloc-cell` calls `net-new-cell` and updates the parameter
- `install-fire-once` wraps fire-fn into a `net`-threaded closure that does `net-cell-read` → invoke fire-fn → `net-cell-write`
- `run-to-quiescence` calls Racket's `run-to-quiescence` on the current net

**`backend-hybrid`** (`preduce-backend-hybrid.rkt`):
- Holds the kernel state (implicit FFI)
- `alloc-cell` calls `prologos_cell_alloc` + `prologos_cell_write` with the boxed initial value
- `install-fire-once` calls `allocate-fresh-callback!` with a thunk that reads cells, invokes fire-fn, writes results — same pattern as Racket but using kernel APIs
- `run-to-quiescence` calls `prologos_run_to_quiescence`
- `reset` calls `reset-handle-table!`

### 3.3 The shared compile-expr (`preduce-core.rkt`)

`compile-expr e env → cid` — backend-agnostic, parameterized by `(current-backend)`:

```racket
;; Pseudo-code sketch:
(define (compile-expr e env)
  (define b (current-backend))
  (match e
    [(expr-int n) ((preduce-backend-alloc-cell b) (expr-int n))]
    [(expr-pair a b)
     (define cid-a (compile-expr a env))
     (define cid-b (compile-expr b env))
     ((preduce-backend-alloc-cell (current-backend))
      (preduce-pair cid-a cid-b))]
    [(expr-fst inner)
     (cond
       [(expr-pair? inner) (compile-expr (expr-pair-fst inner) env)]
       [else
        (define cid-in (compile-expr inner env))
        (define cid-out ((preduce-backend-alloc-cell (current-backend)) preduce-bot))
        ((preduce-backend-install-fire-once (current-backend))
         (list cid-in) (list cid-out)
         (lambda (vs)
           (define v (car vs))
           (cond
             [(preduce-pair? v)
              (list ((preduce-backend-read-cell (current-backend))
                     (preduce-pair-fst-cid v)))]
             [else (error 'preduce "expected pair, got: ~v" v)])))
        cid-out])]
    ...
    ))
```

(Real implementation will use a small accessor `(b-alloc v)` etc. to avoid the `((preduce-backend-... b) args)` verbosity.)

The key idea: every compile-expr case allocates cells via the backend, installs propagators via the backend, and writes pure-value fire-fns. Both backends transparently handle the cell-IO and kernel-bridging.

### 3.4 Stuck-value structs unify

Drop `preduce-hybrid-lam` / `preduce-hybrid-pair`. Both backends use the same `preduce-lam` / `preduce-pair` / `preduce-vcons` / `preduce-user-ctor` structs from `preduce-core.rkt`. The hybrid backend's box/unbox layer handles them transparently — they're stored via the handle table, identical to other non-tagged Racket values.

### 3.5 Backend capability declaration (optional)

Each backend declares its supported AST cases as a (mutable) set. The shared core checks before compiling and errors with a clear "backend X does not yet support AST node Y" — better than the current generic "unsupported AST node" error. Optional: defer until needed. The fire-fn-as-callback strategy from §2.4 means most cases work via the callback path even on hybrid; capability flags are only for cases the hybrid kernel can't even host as a callback (e.g., expr-foreign-fn).

---

## 4. Phased Rollout

| Phase | Description | LOC | Time | Risk |
|---|---|---|---|---|
| **0** | Audit + this design doc | — | done | — |
| **1** | Define `preduce-backend` struct + interface signature in `preduce-core.rkt`. Empty placeholder; no implementations yet. | ~50 | 30min | low |
| **2** | Build `backend-racket` (Racket-side using net-* primitives). Migrate preduce.rkt's fire-fn signature to take pre-read values + return values. **Self-test**: run all 88+12+15 test cases under the new backend. | ~200 | 2h | medium — internal preduce.rkt surgery; touches `make-reduce-fire`, eliminator fire-fns, container ops |
| **3** | Move compile-expr (and helpers `current-fvar-stack`, `statically-reducible-lam`, `try-decompose-user-ctor-app`, eliminator dispatch, container compilers) from preduce.rkt to `preduce-core.rkt`. preduce.rkt becomes a thin wrapper: parameterize `current-backend = backend-racket`, call core's `compile-expr`, run to quiescence, read result cell, unbox. **Self-test**: same 115 test cases pass. | ~1300 LOC moved | 2h | medium — large mechanical move; differential gate validates |
| **4** | Build `backend-hybrid` (Zig-kernel-bridging). Wraps `prologos_cell_*` + `prologos_propagator_install_*` + handle table. Discard preduce-hybrid.rkt's compile-expr-hybrid; replace with thin wrapper that parameterizes `current-backend = backend-hybrid`. **Self-test**: existing 13/13 three-way differential green. | ~250 | 1.5h | medium — bot-handling semantics + tag-allocation timing |
| **5** | Verify hybrid now supports the FULL preduce-lite surface via callback fire-fns. Run all 100 preduce-lite unit tests under `preduce-hybrid`. Expect: most pass on first run; any failures localize to backend-hybrid bugs (since the compile logic is shared). Adjust backend-hybrid until green. **Self-test**: 100/100 preduce-lite tests + 13/13 three-way + 15 OCapN tests all green under hybrid. | ~50 (test wiring) | 1.5h | high — most tests have not exercised hybrid before; will likely surface 2-5 backend bugs |
| **6** | Run OCapN-syrup tests through the hybrid kernel. **First non-trivial program on the kernel.** With `--profile` enabled, capture the per-tag callback profile. Identify the top-3 callbacks by `callback_ns_by_tag`. | — | 30min | low — observation only |
| **7** | Migrate top-1 callback to a Zig-native fire-fn (Phase 10's migration loop, applied to a real workload). Re-run OCapN-syrup with `--profile`; measure callback reduction. | ~30 (Zig) + ~10 (Racket-side stub remove) | 1h | low — proven loop |
| **8** | PIR for the refactor track. | — | 30min | — |

**Total**: roughly 9-11h of work. Half a day to land Phases 1–4 (architectural refactor); another half day for Phases 5–8 (validation + first migration on real workload).

**Dependency on PReduce-lite Phase 10/10b**: ✅ already done — Phase 10b on the Racket side landed 2026-05-04. After this refactor lands, it propagates to hybrid for free (callback-mode).

---

## 5. Risks

1. **Threading-style flip in preduce.rkt is more invasive than it looks.** ~80 sites in preduce.rkt do `(define-values (cid net*) (alloc-value-cell net ...))` then thread `net*` forward. Each becomes `(define cid (b-alloc ...))`. Mostly mechanical, but easy to introduce subtle bugs (e.g., missing a `net` reset, dropping a write). Mitigation: keep the same per-phase test files green at each phase boundary; differential gate against `nf` is the regression gate.

2. **Bot-handling semantics differ between backends.** preduce.rkt's `preduce-merge` returns the new value if old was bot; preduce-hybrid checks `prologos_cell_value_kind == TAG-BOT` explicitly in the callback. The shared core needs a uniform contract: "fire-fn called only when all inputs are concrete; backend handles bot-skip." Mitigation: extract the bot-check into the backend's `install-fire-once`; fire-fns become pure.

3. **Tag allocation timing** in the hybrid backend. preduce-hybrid currently allocates a fresh tag per fire-fn install via `allocate-fresh-callback!`. Hot-loop installs (e.g., compile-expr inside dynamic-β) will allocate many tags — risk of `N_TAGS=256` exhaustion. Mitigation: tag-pooling (reuse tags for structurally-identical fire-fns) is a deferred optimization; for now, monitor tag count via `prologos_debug_n_tags` after a real workload.

4. **Test-suite churn during Phase 3 (the big move).** Moving 1300 LOC of preduce.rkt into preduce-core.rkt risks breaking imports across `tests/test-preduce-phase*.rkt` (which require preduce.rkt for things like `preduce-user-ctor`, `preduce-merge`, `current-use-preduce?`). Mitigation: preduce.rkt re-exports everything for backward compat; tests don't change.

5. **Hybrid-backend Phase 5 expansion will surface bugs.** Today the hybrid covers 13 differential-tested cases; after Phase 5, it'll need to handle the full Phase 1-15 surface. Bugs are likely (e.g., handle-table fragmentation under deep nesting, bot-propagation edge cases in eliminators, FQN ctor-name handling in user-ctor dispatch). Mitigation: per-test-file iteration, use the affected-test runner for fast feedback.

6. **Performance regression risk in preduce.rkt.** The interface inversion (fire-fn takes values instead of net) adds an extra function-call layer per fire. For tight loops (factorial, etc.), this could add 5-10% wall time. Mitigation: measure on the existing `--report` benchmark suite before+after; inline if measurable.

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
| 0 | Audit + this design doc | 🔄 | (this commit) | Pending user review |
| 1 | Define `preduce-backend` struct in `preduce-core.rkt` | ⬜ | — | Empty interface |
| 2 | Build `backend-racket` + migrate fire-fn signatures in preduce.rkt | ⬜ | — | 88+12+15 tests must stay green |
| 3 | Move compile-expr to `preduce-core.rkt`; preduce.rkt → thin wrapper | ⬜ | — | Largest move; differential gate validates |
| 4 | Build `backend-hybrid`; preduce-hybrid.rkt → thin wrapper | ⬜ | — | 13/13 three-way differential validates |
| 5 | Run all 115 preduce-lite tests under hybrid backend | ⬜ | — | Bug-shake phase |
| 6 | Run OCapN-syrup through hybrid + capture profile | ⬜ | — | First non-trivial program on the kernel |
| 7 | Migrate top-1 hot callback to Zig-native | ⬜ | — | Profile-driven migration on a real workload |
| 8 | PIR | ⬜ | — | 16-question template |

Status legend: ⬜ not started, 🔄 in progress, ✅ done, ⏸️ blocked.

---

**End of design plan.**
