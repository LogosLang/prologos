# Native Kernel Pocket Universes — Design Doc

**Date**: 2026-05-02 (revised 2026-05-02 to incorporate concurrency-substrate findings)
**Status**: Stage 3 design proposal — **awaiting option selection**
**Track**: SH (Self-Hosting) — kernel infrastructure track (sequencing TBD per option chosen)
**Branch**: `claude/prologos-layering-architecture-Pn8M9`

**Cross-references**:
- [Concurrency Primitives for the `.pnet` → LLVM Substrate (2026-05-02)](../research/2026-05-02_CONCURRENCY_PRIMITIVES_LLVM_SUBSTRATE.md) — **load-bearing** sibling research that refines the kernel API + cell layout for parallel BSP. Specifically: §4 per-(worker, PU) write logs + cell-partitioned merge; §5 cache-line-aligned `CellSlot`; §6 worker-PU binding contract + `pu_run_parallel`; §7.3 LOC breakdown of PU-specific original work
- [Sprint G — Tail-Rec as PU + Iteration Stratum](2026-05-02_SPRINT_G_PU_ITERATION_STRATUM.md) — narrow case; this doc supersedes its kernel section
- [Depth Alignment Research rev 2](2026-05-02_DEPTH_ALIGNMENT_RESEARCH.md) — origin (CALM critique)
- [BSP-LE Track 2 Design (2026-04-07)](2026-04-07_BSP_LE_TRACK2_DESIGN.md) §2.5a — "decisions are primary, worldview is derived"
- [SRE Track 2G Design (2026-03-30)](2026-03-30_SRE_TRACK2G_DESIGN.md) §3.1 — Phase 6 PU scaffolding lesson
- [Low-PNet IR Track 2 (2026-05-02)](2026-05-02_LOW_PNET_IR_TRACK2.md) — IR substrate
- [BSP-Native Scheduler (2026-05-01)](2026-05-01_BSP_NATIVE_SCHEDULER.md) — Sprint D parent track; PU primitive is its substrate
- `.claude/rules/stratification.md` — canonical taxonomy (S0, Topology, S1 NAF, S0 Guard, S(-1), L1, L2, Stratum 3)
- `.claude/rules/on-network.md` — design mantra
- `runtime/prologos-runtime.zig` — current Zig kernel (`MAX_CELLS`/`MAX_PROPS` flat arrays, single S0 BSP loop)
- `racket/prologos/propagator.rkt:2420–2665` — Racket-level `register-stratum-handler!` + BSP outer loop dispatch
- `racket/prologos/relations.rkt:115–245` — S1 NAF handler (canonical "fork + reset + run + extract" pattern)

---

## 1. Summary

A **Pocket Universe (PU)** is a scoped sub-network with its own lifecycle, strata stack, and worldview, communicating with its parent only via designated entry/exit cells. Today, PU-like patterns exist in eight different forms across the codebase (tabulated in § 3) — most are scaffolding, none are unified, and the Zig kernel has no concept of them at all.

This doc designs a **general kernel-level PU primitive** that subsumes:
- S1 NAF's `fork-prop-network` + `net-cell-reset` + handler pattern
- ATMS branch lifecycle (decision cells, worldview tagging, S(-1) retraction)
- Sprint G's tail-rec iteration stratum
- Future: well-founded semantics (S2), fork-on-union, constraint activation, self-hosted compiler passes

**The thesis**: every non-monotone operation in the project should reduce to "instantiate a PU with strata X, Y, Z; let it run to fixpoint or signal halt; read the exit cells." The kernel provides the lifecycle primitives; Racket-level code provides the stratum handlers; Low-PNet IR provides the declarative shape.

**The output of this doc**: not a single design, but a **design space with five concrete options** (§ 11). The user reviews; we then commit to one and produce the implementation track plan.

---

## 2. Why a kernel-level PU primitive

### 2.1 Symptoms of the missing primitive

| Symptom | Where it shows up |
|---|---|
| Each non-monotone operation reinvents its own scaffolding | `relations.rkt`'s NAF fork pattern, `metavar-store.rkt`'s `run-retraction-stratum!`, `wf-engine.rkt`'s bilattice loop, `metavar-store.rkt`'s `save-meta-state`/`restore-meta-state!` |
| Two strata-orchestration mechanisms (BSP scheduler vs `run-stratified-resolution!`) | `propagator.rkt:2665` (BSP) vs `metavar-store.rkt:1873` (sequential) |
| Save/restore boxes are off-network and Track-8-flagged for retirement | `save-meta-state` snapshots 6 mutable boxes; brittle, off-network, doesn't compose |
| Sprint G's pragmatic "PU as LLVM loop" doesn't generalize | works for tail-rec; cannot represent runtime-allocated ATMS branches, fork-on-union, or nested PUs |
| Non-monotone state advance hidden inside S0 (CALM violation) | F.5/F.6 bridges; the fix per CALM is a stratum boundary, which requires the PU primitive |
| Future translators (NTT, expr-iterate, expr-loop, expr-fold, ATMS-aware union types) inherit the missing primitive | each will hack its own scaffolding |

### 2.2 What "in the kernel" buys

Putting PUs in the Zig runtime (rather than emitting them as LLVM control flow per Sprint G) gives:

1. **Composability**: a PU's strata can themselves install child PUs without LLVM-level recursion.
2. **Scheduler-agnostic**: works under any scheduler that respects strata ordering, not tied to BSP snapshot semantics.
3. **One source of truth**: kernel API for `pu_alloc`/`pu_run`/`pu_exit` replaces the eight ad hoc schemes.
4. **Self-hosting alignment**: the self-hosted compiler will need to express "compile this pass as a PU." If PUs are a kernel primitive, the IR-to-IR transformations can target them directly.
5. **Unifies stratification**: every stratum lives in some PU. The "default global PU" is the parent network we have today. Specialized PUs (NAF, ATMS branch, iteration) are children.

### 2.3 What it doesn't buy (be honest)

- It doesn't make any single use case faster. It makes them *uniform*.
- It doesn't replace the existing Racket-level handlers — they still write the strata logic. PUs are the *substrate*.
- It will not retire `save-meta-state`/`restore-meta-state!` immediately; that's an orthogonal Track 8 concern that PUs *enable* but don't perform.

---

## 3. Inventory: what exists today (compressed)

| Use case | Today's realization | What's wrong | What it needs |
|---|---|---|---|
| **S0 monotone fixpoint** | `propagator.rkt` BSP outer loop, kernel `run_to_quiescence` | Nothing — this is the canonical case | Stays as the inner-loop primitive of every PU |
| **Topology mutation** | `register-topology-handler!` (legacy box, `propagator.rkt:2420`) | Two mechanisms (legacy + general) for the same problem | Unify under the general stratum API; topology becomes "the canonical S+1 stratum" |
| **S1 NAF** | `relations.rkt:115–245`: `fork-prop-network` + `net-cell-reset` + handler that runs inner goal in fork, extracts result | The pattern is correct but ad hoc; reused by ATMS but copy-pasted | Express as: PU with one stratum (inner-goal S0), exit cell = provability bool |
| **S(-1) Retraction** | `metavar-store.rkt:1392` `run-retraction-stratum!` (sequential, off-network) | Sequential invocation; not a stratum on the BSP base | Express as a stratum *within* the elaborator PU |
| **L1 Readiness, L2 Resolution** | `metavar-store.rkt:904, 984` (sequential strata in resolution loop) | Same — sequential, off-network | Express as strata within the elaborator PU |
| **ATMS speculation / branches** | Decision cells + worldview cells + `with-speculative-rollback` macro + box save/restore | Off-network rollback path; doesn't compose with self-hosting | Express as: each branch is a child PU with its own worldview tag |
| **Sprint G iteration** | `iter-block-decl` IR node + LLVM loop in `@main` (in-flight) | Pragmatic, but only one-stratum; doesn't compose with NAF/ATMS inside the iteration body | Express as: PU with one iteration stratum, kernel handles loop |
| **Well-founded semantics (S2)** | `wf-engine.rkt` bilattice cells, predicate-level | Not stratum-modeled; iterative outside stratum framework | Express as a stratum kind: Kleene fixpoint over three-valued bilattice |
| **Future fork-on-union (PPN 4C Phase 10)** | Designed; not implemented | N/A — would be inheritable scaffolding without primitive | Express as: per-alternative child PUs, retracted on contradiction |
| **Future self-hosted compiler passes** | Not started | N/A | Express as: each pass is a PU; pass output cells become next pass's entry cells |

---

## 4. Requirements derived from inventory

A general kernel PU must support:

| # | Requirement | Driving use case |
|---|---|---|
| R1 | **Scoped cells** — a PU has cells the parent cannot read without going through an exit channel | All; isolation |
| R2 | **Scoped propagators** — propagators in a PU don't fire on parent-cell changes (and vice versa, except via entry/exit) | All |
| R3 | **Strata stack** — a PU has an ordered list of registered strata (S0, then handler-1, handler-2, …) iterated by the outer loop until quiescence at all levels | NAF, S(-1), L1, L2, iteration |
| R4 | **Cell overwrite semantics for strata** — strata can write to cells *bypassing the merge function* (e.g., iteration state advance, retraction narrowing). Regular S0 propagators always merge. | Iteration, S(-1) |
| R5 | **Cell reset for strata** — strata can reset cells back to ⊥ (e.g., NAF's `net-cell-reset` on the fork) | NAF |
| R6 | **Worldview integration** — each PU instance has a worldview bit (or tag); cell writes within the PU are tagged; cross-PU reads filter by worldview | ATMS branches |
| R7 | **Lifecycle hooks** — `pu_alloc` / `pu_install` / `pu_run` / `pu_exit_signal_check` / `pu_dealloc`. Strata may invoke `pu_alloc` to spawn child PUs. | All; nesting |
| R8 | **Entry/exit contract** — declared at PU creation: which parent cells the PU reads (entry), which PU cells the parent reads on exit (exit). Kernel enforces no other cross-boundary access. | All; isolation |
| R9 | **Termination** — every PU has an exit predicate (a cell whose value, when matching a constant, signals halt) and a fuel bound. Exhaustion of either ends the run. | NAF (provability bool), iteration (cond cell), ATMS branch (retraction signal) |
| R10 | **Fork-style cloning** — copy parent PU's cells into a new child PU instance with the same shape (NAF's current pattern). Child runs to its own fixpoint. | NAF, fork-on-union, ATMS speculation |
| R11 | **Composable with worldview bitmask filtering** — the existing `current-worldview-bitmask` parameter at the BSP level still works inside any PU | ATMS, NAF inside an ATMS branch |
| R12 | **Tropical-lattice fuel** — fuel as a `min`-merging lattice cell on the parent network, rather than imperative integer counter | PPN 4C Phase 9 mini-design M2; future |

R12 is "nice to have" — start with imperative integer fuel; promote to lattice cell later. R1–R11 are load-bearing.

---

## 5. Architecture — recommended primary

This section describes the architecture I recommend, before laying out the option space (§ 11). It corresponds to **Option C** in § 11, which is the "full kernel-level PU" design.

### 5.1 Conceptual model

```
                ┌──────────────────────────────────────┐
                │ Global root PU (today's parent net)  │
                │                                      │
                │   strata stack:                      │
                │     S0   (BSP propagator drain)      │
                │     +1   (topology)                  │
                │     +2   (registered: NAF, ...)      │
                │                                      │
                │   cells: c0..cN                      │
                │   props: p0..pM                      │
                │                                      │
                │   ┌──────────────────────────────┐   │
                │   │ Child PU (e.g. NAF goal)     │   │
                │   │   strata: [S0]               │   │
                │   │   entry-cells: parent c0..c2 │   │
                │   │   exit-cells:  child  c2     │   │
                │   │   cells: c0..c4              │   │
                │   │   props: p0..p3              │   │
                │   │   worldview-bit: 7           │   │
                │   │                              │   │
                │   │   ┌──────────────────────┐   │   │
                │   │   │ Grandchild PU        │   │   │
                │   │   │   ...                │   │   │
                │   │   └──────────────────────┘   │   │
                │   └──────────────────────────────┘   │
                └──────────────────────────────────────┘
```

The global root PU is the network we have today; existing strata (topology, NAF, S(-1)) are its strata stack. Specialized child PUs (NAF, ATMS branch, iteration) are spawned dynamically by strata handlers.

### 5.2 Lifecycle

```
caller (parent stratum handler)                  kernel
  │
  │  pu_alloc(parent, capacity, worldview-bit) ─►│  allocate handle, arenas
  │ ◄─ pu_handle ──────────────────────────────  │
  │                                              │
  │  pu_install_cell(pu, domain, init) ─────────►│  alloc cell-id (PU-scoped)
  │  pu_install_prop(pu, ins, outs, fn-tag) ────►│  alloc prop-id
  │  pu_register_stratum(pu, idx, handler-id, request-cell)
  │                                              │
  │  pu_set_entry(pu, parent-cid → pu-cid) ─────►│  records mapping
  │  pu_set_exit(pu, pu-cid → parent-cid) ──────►│  records mapping
  │  pu_set_halt_when(pu, exit-cell, value) ────►│  records halt predicate
  │                                              │
  │  pu_initial_writes(pu, ...) ────────────────►│  initial state
  │                                              │
  │  pu_run(pu, fuel) ──────────────────────────►│  outer loop:
  │                                              │    repeat:
  │                                              │      run S0 to quiescence
  │                                              │      for each registered stratum (in order):
  │                                              │        if request-cell non-empty:
  │                                              │          invoke handler
  │                                              │      check halt-when
  │                                              │      if halt or fuel exhausted: break
  │                                              │    write exit cells back to parent
  │ ◄─ result (halt | fuel-exhausted | trap) ──  │
  │                                              │
  │  pu_dealloc(pu) ────────────────────────────►│  free arenas, release worldview bit
```

### 5.3 Cell + propagator scoping

Each PU owns three arenas:
- `cells[]`: per-PU cell array of `CellSlot` (cache-line-aligned slot, not flat i64 — see below)
- `props[]`: per-PU propagator array
- `write_logs[W]`: per-(worker, PU) write logs — one log per worker assigned to this PU during a round

**Cell representation** (per concurrency-substrate §5):
```zig
const CellSlot = extern struct {
    value: i64,
    write_pending: u32,
    subscriber_head: u32,
    _pad: [64 - 16]u8 = undefined,  // 64B aligned; 128B on aarch64
};
```
One cell per cache line. 8× memory inflation (8B → 64B) but the working set is small in absolute terms (10K cells × 64B ≈ 640KB) and the false-sharing tax disappears entirely. False sharing was measured at 3.1× collapse on a lock-free queue with adjacent i64 cells; not optional.

**Per-(worker, PU) write logs** (per concurrency-substrate §4): during the fire phase of a round, each worker accumulates `(cid, value)` writes in its thread-local log for the PU it's bound to. No atomics. No contention. After fire phase ends, cells are partitioned across workers by `cid mod P`; each worker walks all peers' logs to merge writes destined for its assigned cells. This sidesteps the lock-free atomic merge contention that killed BSP-LE 2B's Racket-side parallelism.

Cell-ids are **PU-relative**, not global. A cell-id `(pu-handle, 5)` is distinct from `(other-pu, 5)`. The kernel tracks the `(pu, idx)` pair internally; the public API uses an opaque `CellRef` packed struct that carries both.

Entry mappings are dictionaries `parent-cell-ref → pu-cell-ref`. On `pu_run` start, the kernel copies parent values into the entry-mapped child cells. On `pu_run` exit, the kernel copies exit-mapped child values back to the parent.

This is **physical isolation**: child cells live in a separate memory arena. Reads/writes on child cells inside the PU don't touch parent cells. This is the simplest model that gives R1, R2, R8 simultaneously, and it composes cleanly with the per-(worker, PU) write log architecture (each PU's writes are accumulated in logs scoped to that PU).

### 5.4 Stratum stack

Each PU has an ordered list `strata: (stratum-idx → (handler-tag, request-cell-id))`. Stratum 0 is always S0 (the BSP drain loop), built into the kernel. Strata `1..k` are user-registered, fired in order after S0 quiesces.

The handler is identified by an integer tag; the kernel dispatches via a static jump table (LLVM lowering emits a switch). Handlers are pure-by-contract: `(pu × pending-hash) → void` (writes flow through cell-write APIs).

### 5.5 Cell overwrite semantics

Three cell-write modes:

| Mode | API | Caller | Semantics |
|---|---|---|---|
| **merge** | `cell_write(pu, cid, value)` | propagators (S0) | apply domain merge fn |
| **overwrite** | `cell_overwrite(pu, cid, value)` | strata handlers only | replace value, bypass merge |
| **reset** | `cell_reset(pu, cid)` | strata handlers only | set value to domain bot, clear flags |

The kernel enforces that S0 propagators cannot call overwrite/reset, with **defense in depth**:
- **Structural** (Low-PNet IR): propagator-decl gains a `:privileged` flag (default `#f`). Stratum handlers emit propagators with `:privileged #t`; regular fire-fns emit with `#f`. The lowering stage statically guarantees regular propagators don't reference the privileged kernel APIs.
- **Runtime** (Zig kernel): a thread-local "current handler" flag, set when a worker enters a stratum handler invocation, cleared at exit. `cell_overwrite` / `cell_reset` check the flag and trap if false. Cheap (~1ns thread-local read).

This satisfies R4, R5 and resolves Sprint G § 7.4's open question. Per the concurrency-substrate doc § 6 (last subsection): "the structurally cleaner answer is Low-PNet IR distinguishing privileged-emit vs regular propagators, with the kernel check as defense-in-depth" — both layers, not either.

### 5.6 Worldview integration

Each PU is allocated with a worldview bit position (the parent assigns a unique bit). Cell writes inside the PU are tagged with that bit. Reads inside the PU filter by the bit.

For ATMS branches: parent allocates child PU with bit `b`. The child's cells inherit the tag `b ∪ inherited-tags`. Sibling branches (same parent, different bits) have disjoint tags — their cell writes don't interfere.

For non-speculative PUs (NAF, iteration): the worldview bit is "inherited" from the parent (no new bit allocated). The PU's cells live in the parent's worldview.

### 5.7 Nesting + worker-PU binding contract

A stratum handler in PU `P` may call `pu_alloc(P, ...)` to spawn a child PU. The kernel chains the parent pointer: child's `parent_pu` is `P`. Recursion is allowed; depth-first by construction.

Termination of nested PUs: each PU has its own fuel; total fuel for the tree is the parent's. Child fuel deducted from parent's bucket on `pu_run` entry; refunded on early exit.

**Worker-PU binding contract** (per concurrency-substrate §6 — load-bearing for the per-(worker, PU) write log architecture):

> A worker is bound to one PU for the duration of one BSP round. Within a round it can steal *within that PU* (Chase-Lev across same-PU workers) but **not across PUs**. At round boundary it can re-bind to a sibling PU if the parent is in `pu_run_parallel` mode (§ 6 below).

This constraint keeps the per-(worker, PU) write log clean. A worker that fires propagators in PU A and then steals from PU B mid-round would commingle writes in a shared log; the merger of B's cells wouldn't see them. Per-round binding sidesteps the issue at no measurable cost — load imbalance within a round is bounded by round wall time (microseconds at most) and corrects at the next round boundary.

**Sibling-PU concurrency**: when a parent stratum spawns multiple child PUs that don't depend on each other (ATMS branches with disjoint worldview bits, fork-on-union per-alternative branches, parallel speculation), they execute concurrently via `pu_run_parallel` rather than sequentially. Single scheduler, dynamically partitioned across siblings; not "scheduler-per-PU."

### 5.8 Communication contract

The kernel enforces, at runtime: the only cell-refs a PU can read/write are (a) its own cells, (b) entry-mapped parent cells (read-only inside the PU until `pu_run` exits and writes propagate back), (c) exit-mapped cells (write-only via `pu_set_exit_value`). Any other cross-boundary access traps.

This is stronger than the Racket implementation today (which uses Racket-level discipline). Putting it in the kernel makes the boundary architectural, not advisory.

---

## 6. Kernel API surface (Zig signatures)

```zig
// Opaque handle types
pub const PUHandle = u32;
pub const CellRef = packed struct { pu: PUHandle, idx: u32 };
pub const PropRef = packed struct { pu: PUHandle, idx: u32 };
pub const StratumId = u8;     // 0..63 strata per PU
pub const HandlerTag = u32;   // dispatched via static table

pub const PUResult = enum(u8) { halt, fuel_exhausted, trap, child_trap };

// Cache-line-aligned cell representation (per concurrency-substrate §5).
// Required for any future multi-thread BSP — false sharing on adjacent i64
// cells caused 3.1× collapse in the cited reference benchmark.
pub const CellSlot = extern struct {
    value: i64,
    write_pending: u32,
    subscriber_head: u32,
    _pad: [64 - 16]u8 = undefined,  // 64B aligned (128B on aarch64)
};

// ---- Lifecycle
pub extern fn prologos_pu_alloc(
    parent: PUHandle,         // 0 = root
    cell_capacity: u32,
    prop_capacity: u32,
    worldview_bit: i8,        // -1 = inherit parent
) PUHandle;

pub extern fn prologos_pu_dealloc(pu: PUHandle) void;

// ---- Topology (within a PU)
pub extern fn prologos_pu_cell_alloc(
    pu: PUHandle, domain: u8, init_value: i64,
    numa_hint: i8,            // -1 = no preference; 0..N = preferred NUMA node
) CellRef;

pub extern fn prologos_pu_prop_install(
    pu: PUHandle, fire_fn_tag: HandlerTag,
    in_cells: [*]const CellRef, in_count: u8,
    out_cells: [*]const CellRef, out_count: u8,
) PropRef;

// ---- Entry / exit contract
pub extern fn prologos_pu_set_entry(pu: PUHandle, parent: CellRef, child: CellRef) void;
pub extern fn prologos_pu_set_exit(pu: PUHandle, child: CellRef, parent: CellRef) void;
pub extern fn prologos_pu_set_halt(pu: PUHandle, exit_cell: CellRef, halt_when: i64) void;

// ---- Strata
pub extern fn prologos_pu_register_stratum(
    pu: PUHandle, idx: StratumId,
    handler: HandlerTag,
    request_cell: CellRef,    // empty hashmap by default
) void;

// ---- Cell ops (regular)
pub extern fn prologos_cell_read(pu: PUHandle, cell: CellRef) i64;
pub extern fn prologos_cell_write(pu: PUHandle, cell: CellRef, value: i64) void;

// ---- Cell ops (privileged: only callable from stratum handler context)
pub extern fn prologos_cell_overwrite(pu: PUHandle, cell: CellRef, value: i64) void;
pub extern fn prologos_cell_reset(pu: PUHandle, cell: CellRef) void;

// ---- Run (single PU)
pub extern fn prologos_pu_run(pu: PUHandle, fuel: u64) PUResult;

// ---- Run (sibling PUs concurrently — per concurrency-substrate §6)
// Workers dynamically partition across the N child PUs; each worker bound to
// one PU per round, may re-bind to a sibling at round boundary. All children
// barrier together at fuel-exhaust or all-halt. Covers ATMS branches,
// fork-on-union, parallel speculation, future parallel compiler-pass dispatch.
pub extern fn prologos_pu_run_parallel(
    pus: [*]const PUHandle,
    count: u32,
    fuel_total: u64,
) PUResult;
```

Notes:
- `worldview_bit = -1` means "inherit parent's bit." For ATMS branches, parent passes a fresh bit allocated from a per-tree free list.
- `numa_hint` on `pu_cell_alloc` is a **forward-compatible interface** — pass-through today; cell affinity from the dataflow graph is a future static-analysis pass. The point is the API surface exists so we don't have to break it later.
- `cell_overwrite` / `cell_reset` validate via the structural Low-PNet IR `:privileged` flag (compile-time) AND the thread-local handler flag (runtime). Direct calls from non-privileged propagators trap.
- `pu_run` consumes fuel. Returns `halt` if the halt-when cell matches, `fuel_exhausted` otherwise. Strata-handler traps propagate as `trap`.
- `pu_run_parallel` is the sibling-concurrency primitive. Each child has its own halt predicate; the call returns when all children halt or fuel is exhausted in aggregate.

This API surface is **~13 functions + 1 struct type**, comparable to the existing kernel surface (~10 functions).

---

## 7. NTT model

Per the workflow rule "NTT model REQUIRED for propagator designs," speculative NTT syntax for a PU:

```ntt
;; A PU declaration in NTT
(pocket-universe iter-pu
  (:strata
    (S0)                              ;; built-in: BSP drain
    (iteration                        ;; user stratum
      :request-cell iter-request-cell
      :handler iter-advance-handler
      :fires-after S0))

  (:cells
    (state-a :lattice :scalar :init 0)
    (state-b :lattice :scalar :init 1)
    (cond    :lattice :bool   :init #f))

  (:propagators
    ;; ... S0 body ...
    )

  (:entry  (parent-init-a → state-a) (parent-init-b → state-b))
  (:exit   (state-a → parent-result-a))
  (:halt-when cond #t))


(stratum-handler iter-advance-handler
  (:fires-on (request-cell != ∅))
  (:body
    ;; state ← next via privileged overwrite
    (cell-overwrite state-a (cell-read next-a))
    (cell-overwrite state-b (cell-read next-b))))


;; Spawning a child PU from a handler
(stratum-handler atms-fork-handler
  (:body
    (let ((branch-pu (pu-alloc current-pu
                       :cells 100 :props 200 :worldview-bit (allocate-bit))))
      (pu-install-from-template branch-pu union-branch-template)
      (pu-set-entry branch-pu (some-cell → branch-pu/some-cell))
      (pu-run branch-pu :fuel 1000000)
      (commit-or-retract branch-pu))))
```

### NTT correspondence table

| NTT | Racket runtime | Low-PNet IR | Zig kernel |
|---|---|---|---|
| `(pocket-universe ...)` | new struct `pu-decl` | new node `pu-decl` | `prologos_pu_alloc` |
| `(:strata (S0) (iteration ...))` | strata list | `stratum-decl` per non-S0 | `prologos_pu_register_stratum` |
| `(stratum-handler X ...)` | Racket fn registered with handler-tag | `stratum-decl handler-tag` | static dispatch table |
| `(:entry (p → c))` | entry-map | `pu-entry-decl` | `prologos_pu_set_entry` |
| `(:exit (c → p))` | exit-map | `pu-exit-decl` | `prologos_pu_set_exit` |
| `(:halt-when c v)` | halt predicate | `pu-halt-decl` | `prologos_pu_set_halt` |
| `(cell-overwrite c v)` | priv API | rule emits privileged op | `prologos_cell_overwrite` |

### NTT gaps surfaced

1. NTT today has no PU declaration syntax. New form `pocket-universe`.
2. NTT today has no privileged/non-privileged distinction on cell ops. New annotation needed (e.g., `:privileged`).
3. NTT today has no halt-predicate syntax. New `:halt-when` clause.

These are recorded for the future NTT track.

---

## 8. Lowering implications

### 8.1 Low-PNet IR additions

Add five node kinds (additive; existing nodes unchanged):

```racket
(struct pu-decl (id parent-id worldview-bit cell-capacity prop-capacity) #:transparent)
(struct pu-stratum-decl (pu-id stratum-idx handler-tag request-cell) #:transparent)
(struct pu-entry-decl (pu-id parent-cell child-cell) #:transparent)
(struct pu-exit-decl (pu-id child-cell parent-cell) #:transparent)
(struct pu-halt-decl (pu-id exit-cell halt-when-value) #:transparent)
```

Cells/propagators inside a PU are still `cell-decl` / `propagator-decl`, with an additional `pu-id` field added (currently 0 = root PU). Backwards-compatible: existing programs all live in PU 0.

The `iter-block-decl` from Sprint G Phase 1 becomes a *derived form* — the lowering rewrites `iter-block-decl` to `pu-decl` + `pu-stratum-decl` + `pu-entry-decl` + `pu-exit-decl` + `pu-halt-decl`. We can keep `iter-block-decl` as user-facing sugar.

### 8.2 AST → Low-PNet

`lower-tail-rec` emits PU IR nodes instead of bridges + feedback (same behavioral end-state as Sprint G, but expressed via the general primitive).

`relations.rkt`'s NAF lowering migrates to PU IR nodes (Phase later than Sprint G's; coordinated with this track).

### 8.3 Low-PNet → LLVM

Each PU emits:
- A constructor function `@pu_install_<n>` that calls `pu_alloc`, then loops over its cells/props/strata to install them.
- The strata handlers as LLVM functions in the same module.
- A dispatch table mapping `HandlerTag` → function pointer.

`@main` calls `pu_install_root` then `pu_run(root, fuel)`. PUs are recursively installed by their parent's handlers as needed.

---

## 9. Migration of existing strata + Sprint G

The track-by-track migration plan:

| Track | What migrates | Effort | Risk |
|---|---|---|---|
| **Topology stratum** | replace legacy `register-topology-handler!` with `register-stratum-handler!` against root PU | small | low — already exists as alternative path |
| **S1 NAF** | reframe `process-naf-request` to spawn child PU instead of `fork-prop-network` | medium | medium — semantic equivalent, but fork→PU transition needs care |
| **S(-1) Retraction** | promote from sequential `run-stratified-resolution!` invocation to root PU stratum | medium | low — same handler logic |
| **L1, L2 (constraint resolution)** | same — promote to root PU strata | medium | low |
| **Sprint G iteration** | replace `iter-block-decl` LLVM-loop lowering with PU+stratum lowering; iter-block-decl becomes derived sugar | small (just changes the LLVM emission) | low — Sprint G's IR layer is preserved |
| **ATMS branches** | spawn child PU per branch with allocated worldview bit | large | medium — most invasive; touches `with-speculative-rollback` retirement |
| **Future: fork-on-union** | same as ATMS branches | (covered by ATMS) | |
| **Future: well-founded semantics** | bilattice cells become a custom stratum kind within a predicate-PU | medium-large | medium |
| **Future: self-hosted compiler passes** | each pass is a PU; pass output is exit cell | large | low — this is the canonical use |

The Sprint G **iteration stratum** lands FIRST (smallest, validates the IR substrate). Topology unification next (cleanup). Then NAF / S(-1) / L1 / L2 (medium). ATMS last (largest, retires the most scaffolding).

---

## 10. Open questions

| # | Question | Resolution path |
|---|---|---|
| Q1 | Per-PU arena allocation strategy: fixed-size ranges, growable arenas, or pooled? | Phase 1 of implementation: start with fixed-size (capacity declared at `pu_alloc`). Pool of arenas reused on dealloc. |
| Q2 | Worldview bit allocation when a tree exceeds 64 branches | Promote bitmask to `BigBitmask` (variable-length); incurs cost; defer until > 64-branch tree appears |
| Q3 | Cross-PU cell aliasing for shared structural cells (e.g. shared trait registry) | Designate "global" cells in root PU; PUs treat root cells as read-only entry. Alternative: shared-arena cells with explicit reference semantics. |
| Q4 | Is fuel a lattice cell (R12) or imperative? | Imperative for v1; lattice-cell (min-merge) for v2. Don't conflate. |
| Q5 | Does `cell_overwrite` propagate as a worklist event? | Yes — same as `cell_write` for triggering downstream propagators. The "overwrite" is purely about merge-bypass, not about scheduler suppression. |
| Q6 | Does the kernel store PU handles statically (compile-time-known set) or dynamically? | Dynamic — ATMS spawns at runtime. Kernel maintains a free-list of PU handles. |
| Q7 | Trap recovery: what happens if a stratum handler traps? | `pu_run` returns `trap`; parent handler decides (likely: deallocate this PU, propagate as nogood). |
| Q8 | Self-hosting: how does the bootstrap kernel implement PUs? | Open. The bootstrap Racket runtime can implement PU APIs directly; the Zig runtime implements them natively; the self-hosted Prologos runtime is an open question — likely deferred to later self-hosting work. |
| Q9 | **Calibration measurements before committing to primitives** (per concurrency-substrate §9) | Run three measurements on the current sequential prototype before any kernel work begins: (1) per-round wall time on existing benchmarks (anchors parallelism crossover); (2) tag distribution (anchors comptime fire-batch payoff); (3) false-sharing microbench (anchors `CellSlot` priority). ~2 hours; gates which primitives matter at our actual scale. |
| Q10 | `pu_run_parallel` semantics under nested concurrent siblings | Each child has its own halt predicate + fuel; aggregate fuel passed at top level. When one child halts before others, its workers re-bind to siblings at next round boundary. Deadlock: a sibling that depends on another sibling's exit cell would deadlock — declare such mappings illegal at lowering time (siblings have disjoint exit-cell sets). |
| Q11 | NUMA policy (beyond preserving the API hook) | Defer until multi-socket deployment is on the immediate horizon. Static-analysis pass over the `.pnet` dataflow graph at lowering time would compute per-cell affinity hints. Today: pass-through, no policy. |
| Q12 | EBR vs alternatives at deep ATMS recursion | Per concurrency-substrate §10.2: EBR is the right starting point because BSP's phase boundaries make its blocking pathology unreachable. At ATMS depth >100, per-PU EBR state may itself become memory-heavy; alternatives (interval-based reclamation, HP-RCU) are deferred until depth measurements show pressure. |
| Q13 | Sequencing relative to Sprint D (parallel BSP substrate) | Two paths: (a) PU primitive lands first on top of sequential kernel; Sprint D adds parallelism on top; (b) PU primitive + Sprint D land together (parallel-from-day-one). Path (a) reduces risk; path (b) avoids retrofitting per-(worker, PU) write logs onto a sequential kernel. Resolved with the option-selection decision points (§13). |

---

## 11. Options for review

This is the section the user asked for. Five options, ordered by ambition:

### Option A — **Status quo**: keep PUs at Racket level only

- No kernel changes.
- Continue the eight ad hoc patterns; document them better.
- Sprint G stays as LLVM-loop hack (works for tail-rec).
- ATMS branches stay as `fork-prop-network` + box save/restore.

**Cost**: 0 days. **Unlocks**: nothing. **Tech debt**: stays high; each future feature inherits a different ad hoc pattern.

### Option B — **IR-only**: PU concept in Low-PNet IR + lowering, but kernel stays flat

- Add `pu-decl` / `pu-stratum-decl` / etc. to Low-PNet IR.
- Lowering allocates contiguous cell-id ranges per PU in the global flat array.
- Strata realized as LLVM functions called from `@main` in nested loops.
- Worldview tags handled in lowering (compile-time static decisions).

**Cost**: ~7-10 days (IR + lowering + Sprint G migration).
**Unlocks**: Sprint G done correctly (composable with future NAF inside iteration). Topology stratum unification.
**Limits**: doesn't support runtime-allocated PUs (ATMS branches at runtime stay ad hoc). Bigger lowering surface.

### Option C — **Full kernel-level PU primitive** (the architecture in §§ 5-8)

- Zig kernel adds the ~13-function API in § 6.
- Per-PU arenas; strata stack; privileged cell ops; worldview integration; per-(worker, PU) write logs (when paired with parallel BSP); `pu_run_parallel` for sibling concurrency.
- Runtime-allocated PUs (R10) supported natively → ATMS branches become first-class.
- Low-PNet IR adds the 5 PU node kinds + privileged-emit flag.

**Cost decomposition** (per concurrency-substrate §7.3 LOC table — the prior "~15-25 days" estimate conflated two separable layers):

| Component | LOC (Zig) | Days | Required by |
|---|---|---|---|
| PU-binding-per-round scheduler logic | ~300 | ~3 | PU primitive only |
| `pu_run_parallel` batched-run primitive | ~200 | ~2 | PU primitive only |
| Worldview-bit allocator (per-tree free list) | ~150 | ~1.5 | PU primitive only |
| Privileged cell-op runtime check | ~50 | ~0.5 | PU primitive only |
| **PU-specific original work** | **~700** | **~7** | **this track** |
| Per-(worker, PU) write log + cell-partitioned merge | ~400 | ~4 | parallel BSP (Sprint D) |
| Cache-line-aligned `CellSlot` + NUMA hooks | ~120 | ~1 | parallel BSP (Sprint D) |
| Chase-Lev deque + barrier + futex pool | ~400 | ~4 | parallel BSP (Sprint D) |
| **Concurrency substrate** | **~920** | **~9** | **Sprint D — separable** |
| Low-PNet IR (5 node kinds, privileged flag) | n/a | ~3 | this track |
| Sprint G migration (iter-block-decl → pu-decl) | n/a | ~3 | this track |
| NAF migration (`fork-prop-network` → child PU) | n/a | ~3 | this track |
| Regression suite + benchmarks | n/a | ~2 | this track |
| **PU integration work** | n/a | **~11** | **this track** |
| **Track total (PU primitive only)** | **~700** | **~18** | sequential kernel |
| **Track total (PU + concurrency)** | **~1620** | **~27** | parallel kernel |

**Sequencing options** (per Q13):
- **(a) PU-primitive-first** (~18 days): land Option C on the existing single-threaded kernel; Sprint D adds parallelism on top later. Lower risk; single-thread regression suite easier to stabilize.
- **(b) PU + Sprint D concurrent** (~27 days): land both together, parallel-from-day-one. Higher risk but avoids retrofitting per-(worker, PU) write logs onto a sequential kernel — those logs are built around the PU lifecycle, so adding them after the PU primitive is harder than adding them with it.

**Unlocks**: every entry in § 9's migration table. Self-hosted compiler can express each pass as a PU. ATMS branch lifecycle becomes scheduler-agnostic. With (b), parallel BSP across sibling PUs.
**Limits**: large; touches the kernel; need careful staged migration.

### Option D — **Tagged-subset PUs** (cheaper than C)

- Cells/propagators get a `pu-id` field (4 bytes added to each entry).
- Kernel APIs read/write filter by current PU.
- No physical isolation; flat arrays preserved.
- Strata stack registered globally with a `(pu-id, stratum-idx)` key.

**Cost**: ~10-15 days. Kernel changes are smaller (just add the tag field + filter logic).
**Unlocks**: same as C, but with O(N) iteration costs in some operations (filtering by tag).
**Limits**: weaker isolation guarantees (a buggy propagator in one PU could write to another's cell-id by accident — the kernel would catch via tag mismatch trap, but the failure mode is dynamic not static).

### Option E — **Hybrid kernel + LLVM**

- Kernel adds: per-PU cell-range, run-to-quiescence-on-PU, but no strata stack.
- Strata are still Racket-emitted as LLVM control flow that calls kernel `run_to_quiescence_on_pu` between stratum-body emissions.
- Compromise between B (no kernel changes) and C (full primitive).

**Cost**: ~10-12 days. Kernel changes are moderate.
**Unlocks**: cell scoping (R1, R2). Strata sequencing remains in lowering — limited composability with runtime-allocated PUs.
**Limits**: doesn't fully solve ATMS (branches still need fork pattern at Racket level).

### Recommendation summary

| Option | Cost | Unlocks Sprint G correctly | Unlocks runtime-allocated PUs (ATMS) | Replaces save/restore boxes | Self-hosting alignment | Composes with Sprint D parallel BSP |
|---|---|---|---|---|---|---|
| A | 0d | ✗ (LLVM hack stays) | ✗ | ✗ | ✗ | n/a |
| B | ~10d | ✓ | partial | partial | partial | partial (lowering-time scope, not runtime PUs) |
| C(a) | ~18d | ✓ | ✓ | ✓ | ✓ | ✓ (Sprint D adds on top, ~9d more) |
| C(b) | ~27d | ✓ | ✓ | ✓ | ✓ | ✓ (parallel-from-day-one) |
| D | ~13d | ✓ | ✓ | ✓ | ✓ (with caveats) | weak (tag-filter cost under contention) |
| E | ~11d | ✓ | partial | partial | partial | partial |

My recommendation is **Option C(a)** — the PU primitive on the existing sequential kernel, with Sprint D's parallel substrate as a separable follow-on. The two layers are architecturally distinct (PU = scope/strata/lifecycle; parallel BSP = scheduler + write logs); separating them reduces risk and lets each be measured independently. Option C(b) is justified only if we have strong evidence that retrofitting concurrency onto a sequential PU primitive will be costly — which we don't yet have. Option D is a viable cheaper alternative if even ~18d is too high. Options B and E are reasonable stepping stones if we want to land Sprint G first and defer ATMS migration.

Note: under C(a), the API surface (§ 6) is finalized day-one with all parallel-BSP-friendly fields (`numa_hint`, `CellSlot` shape, `pu_run_parallel`). The implementation is sequential; the interface preserves the future. This is the cheaper-than-c(b) path that avoids API churn when Sprint D lands.

---

## 12. Adversarial framing (Vision Alignment Gate)

Per workflow rule on adversarial VAG:

| Catalogue | Challenge |
|---|---|
| ✓ PUs are on-network | Are entry/exit mappings on-network? — *Yes; they're declared as IR nodes (pu-entry-decl, pu-exit-decl) and live as kernel-tracked tables. Not Racket parameters or hasheqs.* |
| ✓ Strata stack is uniform | But topology is currently a legacy box. Is this design forcing topology onto the new uniform path, or just leaving it as-is? — *§ 9 commits to migrating topology. Don't leave it as legacy after this track.* |
| ✓ Cell overwrite is privileged | Is "privileged" a runtime check or a structural guarantee? — *Runtime check today; structurally guaranteed only if Low-PNet IR distinguishes privileged-emit propagators from regular ones. Add an IR-level mode flag in implementation.* |
| ✓ Worldview integration | "Worldview-bit assigned per PU" — could a PU be SHARED across multiple worldviews (e.g., a cached pass result reused across branches)? — *Open question Q3 above. Initial design: no sharing. If sharing becomes necessary, add reference-counted "shared cells in root PU."* |
| ✓ Pragmatic decoration | Is any part of this rationalizing? — *§ 11 Option A explicitly identifies status quo as tech debt. § 9 commits to a full migration plan, not "we'll get to it eventually." § 10 Q4 names imperative fuel as v1 scaffolding with named v2 retirement.* |
| ✓ Composability | Can a stratum handler in PU P spawn a grandchild PU? — *Yes; § 5.7. But the design assumes finite nesting depth — what's the bound? Open. Likely: depth = parent fuel allowance.* |
| ✓ Stratum API uniform with today's | Today's `register-stratum-handler!` is per-network, not per-PU. Migration must update the API to take a PU handle. — *Yes; § 9 calls this out for topology. The change is mechanical but touches every existing stratum.* |

---

## 13. Decision points to resolve before implementation begins

The user reviews this doc and answers:

1. **Which option (A-E)?** — determines the implementation track scope. If C, also choose between C(a) sequential-first and C(b) parallel-from-day-one.
2. **Sprint G interaction**: do we (a) finish Sprint G's LLVM-loop hack as committed scaffolding and migrate to PU-based later, or (b) pause Sprint G and land the PU primitive first, with iteration as the first migrated case?
3. **Track sequencing**: where does this land relative to other in-flight tracks (PPN 4C, the SH series N0/N1/N2, Sprint D parallel BSP)?
4. **Effort budget**: ~18 days (C(a)) vs ~27 days (C(b)) vs ~13 days (D) — which is acceptable?
5. **Bootstrap-vs-Zig**: do we implement the PU primitive in (a) Racket runtime first, then port to Zig; (b) Zig first, then Racket follows; (c) both in lockstep?
6. **Calibration measurements**: do we run the three measurements from concurrency-substrate §9 (per-round wall, tag distribution, false-sharing impact) BEFORE committing to specific primitives? ~2 hours of work; would inform whether `CellSlot` cache-line padding and per-(worker, PU) write logs are essential at our actual scale or premature optimization.

When these are answered, the next step is producing the staged implementation plan (analogous to Sprint G's progress tracker) and beginning Phase 1.

---

## 14. References (added by 2026-05-02 revision)

### Concurrency substrate sources (per concurrency-substrate doc § 12)
- Lê et al. 2013, *Correct and Efficient Work-Stealing for Weak Memory Models* (PPOPP) — Chase-Lev deque memory orderings
- Mellor-Crummey & Scott 1991, *Algorithms for scalable synchronization* (TOCS) — sense-reversing barrier
- Brown 2017, *Reclaiming Memory for Lock-Free Data Structures* (arXiv 1712.01044) — EBR vs HP comparison
- Steindorfer & Vinju 2015, *Optimizing Hash-Array Mapped Tries* (OOPSLA) — CHAMP for cell representation
- Puente 2017, *Persistence for the Masses* (ICFP) — Immer; persistent data structures in C++

### Bench peers (measurement anchors, not implementation choices)
- [Soufflé](https://souffle-lang.github.io/) — Datalog → C++; EQREL parallel union-find for future on-network SRE unification
- [Differential Dataflow](https://github.com/TimelyDataflow/differential-dataflow) — closest *model* match; per-worker arrangement is direct precedent for our per-(worker, PU) write log
- [Galois](https://iss.oden.utexas.edu/?p=projects/galois), [Ligra](https://github.com/jshun/ligra) — pure-graph BSP gold standards
- [TigerBeetle](https://github.com/tigerbeetle/tigerbeetle) — engineering discipline (determinism, Power-of-Ten, static memory, no GC). Architectural conclusion differs (their workload is single-threaded; ours is BSP) but discipline transfers.

### Reference implementations to port
- [crossbeam-deque](https://github.com/crossbeam-rs/crossbeam) — Rust Chase-Lev (handles the Lê et al. integer-overflow bug correctly)
- [libqsbr](https://github.com/rmind/libqsbr) — C reference EBR + QSBR
- [microsoft/mimalloc](https://github.com/microsoft/mimalloc) — production allocator (FFI target)

---

**End of design doc.**
