# PReduce uses the dissolved kernel substrate (no further kernel work)

**Date**: 2026-05-02
**Status**: Documentation (Phase 7 of `2026-05-02_KERNEL_POCKET_UNIVERSES.md`)
**Author**: kernel-PU implementation track (Day 14)
**Cross-references**:
- [Kernel Pocket Universes (rev 2.1)](2026-05-02_KERNEL_POCKET_UNIVERSES.md) — the substrate this doc validates
- [PM Track 9: Reduction as Propagators](2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md) — the consumer being validated
- [Depth Alignment Research](2026-05-02_DEPTH_ALIGNMENT_RESEARCH.md) §4 — calls out PReduce's "in-S0 anti-pattern" risk

## 1. Purpose

The kernel-PU rev 2.1 design claims that the substrate it ships
(cells + propagators + `cell_reset` + topology-mutation deferral +
scope APIs + tagged-value worldviews) is **sufficient** for
PReduce's compositional needs — that is, when PM Track 9
("Reduction as Propagators") goes from Stage 1 research to
implementation, it can be expressed against this substrate **without
further kernel work**.

This document validates that claim by walking through one PReduce
reduction case as substrate-level cells/propagators end-to-end.
Per § 14 Phase 7's gate: "1-2 page note … Documentation only —
no code. PReduce track owners can read this and confirm the kernel
substrate is sufficient. *Validates the design claim 'substrate
suffices' without committing to ship PReduce in this track.*"

The walkthrough is on a single representative case (trait-dispatched
WHNF reduction); the full PReduce surface is much larger
(`reduction.rkt` is ~4000 lines, ~50 cases), but every case
decomposes into the same primitive operations — once we show that
those primitives are all in the kernel substrate, the rest follows
mechanically.

## 2. The case: trait-dispatched WHNF reduction

From `2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md` § 2 (the
canonical PReduce vision example):

```
Expression: [idx-nth $dict xs 0]
               ↓
Cell: whnf([idx-nth $dict xs 0])
  depends on: cell($dict), cell(xs), cell(0)
               ↓ (when $dict solved to PVec--Indexed--dict)
Cell updates: whnf([idx-nth PVec--Indexed--dict xs 0]) → [rrb-get xs 0]
```

A reduction request `whnf E` where `E` mentions an unsolved meta
`$dict`. The reducer cannot fire until `$dict` is bound; once it is,
the reducer should produce `[rrb-get xs 0]` and any downstream
reduction cells that depend on this WHNF should re-fire automatically.

PReduce's design: model the WHNF result as a cell whose value
depends on the metas the reducer reads; install a reduction
propagator that re-fires when those dependencies change.

## 3. Substrate decomposition (what the kernel sees)

Below: every operation the elaborator emits to install this case,
keyed to the kernel API it lowers to. **No PReduce-specific kernel
primitive is required.** All of these are already in the kernel
shipped by Phases 1-2 (Days 1-7) of this track.

### 3.1 Cell allocation (kernel API: `prologos_cell_alloc`)

Two cells per reduction case:

| Cell | Domain | Initial | Notes |
|---|---|---|---|
| `whnf-result-cell`  | LWW i64 (or LWW expr-pointer) | ⊥ | Holds the WHNF of the expression. |
| `whnf-deps-cell`    | set-of-cell-id (monotone union) | ∅ | Holds the dynamic dependency set the reducer accumulated on its last fire. |

Both use kernel `prologos_cell_alloc(domain, init)`. Pulled from
runtime/prologos-runtime.zig. No PReduce-specific cell kind; the
domain registry already supports LWW and set-union (the latter via
`merge_value` extensions; same shape as the existing `min`-merge
i64 domain shipped Day 1).

### 3.2 The reduction propagator (kernel API: `prologos_prop_install`)

One propagator per cached expression:

```
prologos_prop_install(
  fire_fn       = WHNF_REDUCER_TAG,        // dispatched via FIRE-FN-TAG-REGISTRY
  in_cells      = [meta($dict), cell(xs), cell(0)],   // dependencies
  in_count      = 3,
  out_cells     = [whnf-result-cell, whnf-deps-cell],
  out_count     = 2,
)
```

The fire-fn body:

```
fire-fn-whnf-reducer(meta-dict, cell-xs, cell-0):
  dict-val = cell_read(meta-dict)
  xs-val   = cell_read(cell-xs)
  zero-val = cell_read(cell-0)
  if dict-val == bottom:
    return                            // stuck — no write, no enqueue
  result, new-deps = reduce-whnf-internal([idx-nth dict-val xs-val zero-val])
  cell_write(whnf-result-cell, result)        // merge mode: standard
  cell_write(whnf-deps-cell, new-deps)        // set-union merge
```

Three things to observe about this fire-fn:

1. **The reducer is a pure Racket/Zig function** consumed by the
   fire-fn body — `reduce-whnf-internal` is the existing
   `reduction.rkt` engine, called from inside the propagator. It
   reads cells via `cell_read`, computes a result, and writes it
   back. No new kernel concept.

2. **The "stuck" case is naturally idempotent**: when `dict-val`
   is bottom, the fire-fn returns without writing. Standard
   `cell_write`'s no-change guard means no dependents enqueue.
   When `$dict` later resolves, the meta-cell's write enqueues
   this propagator, which re-fires; `dict-val` is now concrete;
   reduction succeeds and writes the result.

3. **Re-fire on dependency change is automatic**: the propagator's
   `in_cells` declares the deps, so the BSP scheduler enqueues
   this propagator on any of those cells changing. The fire-fn
   body computes a new dependency set on every fire (because the
   reduction may have taken different sub-paths) and writes it to
   `whnf-deps-cell` — but the propagator's static input set is
   the **upper bound** of what it ever reads. PReduce's lazy-cell
   creation strategy (§ 5 of TRACK9 doc) effectively expands this
   upper bound on every re-fire by adding new propagator edges
   for the latest deps; that's a topology mutation.

### 3.3 Topology mutation during fire (kernel: 2-tier outer loop)

When the fire-fn discovers new dependencies (e.g., the reduced form
mentions a meta the original didn't), it needs to install **new**
propagator edges from those new dep-cells to itself. The kernel API:

```
fire-fn-whnf-reducer(...):
  ...
  for new-dep in (deps-after-this-fire MINUS deps-already-watched):
    prologos_prop_install(WHNF_REDUCER_TAG, [new-dep], 1, [...], 2)
```

This is a **mid-fire `prop_install`**. The kernel buffers it; the
2-tier outer loop applies it between value rounds. Phase 1 Day 2
of this track shipped exactly this mechanism — the
`note_topo_mutation` infrastructure in `runtime/prologos-runtime.zig`
captures `prop_install` (and `cell_alloc`) calls during fire and
applies them in the topology tier before the next value round.

**No PReduce-specific topology hook is needed**. The mid-fire
deferral mechanism is already general-purpose: any fire-fn can
call `prop_install` or `cell_alloc` and trust it'll be applied
correctly.

### 3.4 Lazy cell creation (kernel: `cell_alloc` mid-fire)

PReduce's lazy-cell strategy (§ 5 of TRACK9 doc, "only create a
reduction cell when the expression is reduced a second time") falls
out for free. The first reduction:

```
fire-fn-on-demand-reducer(expr-cell):
  expr = cell_read(expr-cell)
  result = reduce(expr)
  // First fire: don't allocate a cell yet, just return result.
  // ...but we need to remember that we reduced this.
```

For a second reduction, the fire-fn allocates a `whnf-result-cell`
mid-fire (`cell_alloc`), then writes the result to it, and
installs the standard reduction propagator. The new cell + new
propagator both go through the same topology-mutation deferral
mechanism. The kernel sees nothing PReduce-specific.

### 3.5 Speculation interaction (kernel: tagged-cell-value worldview)

PReduce's open question § 7.3 ("Interaction with speculative
reduction"): during ATMS speculation, reduction cells need to know
which worldview their result corresponds to. The kernel substrate
already handles this — every `cell_write` is tagged with the
current `worldview-cache-cell-id` value (the bitmask of active
assumptions), and `cell_read` returns the merge of all entries
visible under the current worldview.

PReduce reads cells normally; the worldview narrowing is invisible
to the reducer. **No PReduce-specific TMS interaction needed.** The
shipped substrate (Phase 1 Day 1's tagged-value merge in the
existing `cell_write` body, unchanged from Racket) already supplies
this.

### 3.6 Per-reduction isolation (kernel: scope APIs — only if needed)

If PReduce ever needs **per-reduction-call fuel isolation** (e.g.,
a reduction that may diverge — fixed-point on coinductive types —
should not exhaust the global BSP fuel), it can wrap the reducer
body in a scope cycle:

```
fire-fn-bounded-reducer(expr-cell):
  expr = cell_read(expr-cell)
  scope = scope_enter(parent_fuel_charge=10)
  // install reducer on scope; bounded fuel
  install-reducer-on-scope(expr, scope)
  result = scope_run(scope, fuel=10000)
  if result == halt:
    val = scope_read(scope, scope-result-cell)
    cell_write(whnf-result-cell, val)
  // else: timeout; treat as stuck
  scope_exit(scope)
```

This is the same pattern as the NAF handler in § 5.9 of the parent
design doc, validated by the Day 12 NAF isolation gate
(2 explicit gates passing in `tests/test-scope-apis.rkt`).

PReduce's Stage 1 design (§ 5 of TRACK9 doc) doesn't currently
specify per-reduction isolation; if it ever does, the scope APIs
are already there. **Pre-emptive: no kernel change.**

## 4. Substrate-sufficiency claim — the catalog

Crossing the four kernel additions delivered by this track against
PReduce's required operations:

| PReduce primitive | Kernel API | Shipped in |
|---|---|---|
| Allocate WHNF result cell | `prologos_cell_alloc(LWW i64, ⊥)` | Phase 1 Day 1 |
| Allocate dynamic deps cell | `prologos_cell_alloc(SET-UNION, ∅)` | Phase 1 Day 1 (domain registry; new domains follow the same pattern as `min`-merge i64) |
| Install reduction propagator | `prologos_prop_install(REDUCER_TAG, deps, [result, deps-cell])` | Phase 1 Day 1 (existing API) |
| Read meta + sub-cells from fire-fn | `prologos_cell_read` | Existing |
| Write result + new deps from fire-fn | `prologos_cell_write` (merge) | Existing (with no-change guard for stuck case) |
| Mid-fire install of new dep edges | Topology-mutation deferral | Phase 1 Day 2 |
| Mid-fire allocation of lazy result cell | `prologos_cell_alloc` mid-fire | Phase 1 Day 2 (deferred to topology tier) |
| Speculation-aware reads/writes | `tagged-cell-value` merge | Existing (Racket); kernel keeps the same convention |
| Per-reduction fuel isolation (optional) | `prologos_scope_enter` / `_run` / `_read` / `_exit` | Phase 1 Day 3, Phase 2 Day 6 |
| Replace stuck cell on demand (optional) | `prologos_cell_reset` | Phase 1 Day 1 |

**No row in this table calls for a kernel API not already shipped.**

## 5. What this rules out

The kernel substrate is sufficient for PReduce. The VAG challenges
in § 12 of the parent design doc asked specifically about
PReduce-shaped consumers; this walkthrough closes those for the
PReduce track:

- **Q12.1 — "What scaffolding will PReduce add to the kernel?"**
  None. Every operation reduces to the existing 10-function kernel
  API surface (`cell_alloc`, `prop_install`, `cell_read`,
  `cell_write`, `cell_reset`, `run_to_quiescence`, `scope_enter`,
  `scope_run`, `scope_read`, `scope_exit`).

- **Q12.2 — "Does PReduce need its own stratum?"**
  Not in the kernel. PReduce's reduction-as-its-own-stratum design
  (per § 4 of `2026-05-02_DEPTH_ALIGNMENT_RESEARCH.md`) is
  expressed at the **elaborator** layer as a registered
  stratum-handler propagator subscribed to a "reduction-pending"
  request cell. The kernel sees a propagator subscribed to a
  cell, not a stratum primitive.

- **Q12.3 — "Does PReduce need a per-reduction PU?"**
  No, but if/when it does (for divergent fixpoints), the scope APIs
  are the canonical mechanism. The kernel doesn't grow a PU type.

## 6. What PReduce track owners can take from this

When PM Track 9 starts implementation:

1. **Don't add kernel APIs.** Express every reduction operation
   against the existing 10-function surface. If a design step
   seems to require a new kernel primitive, it's almost certainly
   an elaborator concern that should be expressed as cells +
   propagators on top of the substrate.

2. **The lazy-cell strategy gets topology mutation for free.**
   Mid-fire `cell_alloc` and `prop_install` are already deferred
   to the topology tier and applied between rounds. No new
   "reduction-cell allocator" abstraction needed.

3. **Speculation interaction is automatic.** Tagged-value
   worldview narrowing happens in `cell_write` / `cell_read`
   without PReduce knowing. Reduction cells under speculative
   branches naturally narrow.

4. **Per-reduction fuel isolation, if ever needed, is one
   `scope_enter` / `scope_run` / `scope_exit` cycle around the
   reducer body** — same pattern as the NAF handler at § 5.9 of
   the parent design doc.

The design claim "the kernel substrate is sufficient for PReduce
without further kernel work" is **validated**.

---

## Appendix A: Substrate-as-cache invariant for PReduce

A subtle point that the walkthrough surfaces but doesn't dwell on:
PReduce's central insight ("the propagator network IS the cache")
is a direct consequence of the substrate's no-change guard on
`cell_write`. The reduction cell holds the latest computed WHNF;
re-fires that compute the same result write the same value; the
no-change guard prevents pointless dependent enqueueing.

This is **observably the same** as the existing memo-cache behavior
PReduce replaces, with one additional guarantee: when a meta
solution changes, the reduction cell automatically invalidates and
re-computes. The Track 8 Part C "Option D stopgap" (§ 1 of TRACK9
doc) becomes unnecessary because the substrate handles invalidation
structurally.

The kernel doesn't need to know any of this. From its view: a
propagator has inputs and outputs; on input change, fire; on output
change, enqueue dependents. PReduce just happens to use these
primitives in a particular pattern.
