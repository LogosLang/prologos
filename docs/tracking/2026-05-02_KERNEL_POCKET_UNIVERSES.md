# Pocket Universes & Stratification — Kernel Substrate Design

**Date**: 2026-05-02
**Status**: Stage 3 design proposal (rev 2.1 — dissolved + minimal scope)
**Track**: SH (Self-Hosting) — kernel substrate (sequencing TBD per option chosen)
**Branch**: `claude/prologos-layering-architecture-Pn8M9`

**Architectural shift from rev 1**: An earlier draft of this doc proposed kernel-level PU and stratum-handler primitives (a `prologos_pu_*` API family of ~12 functions, 5 new IR node kinds, etc.). Review feedback challenged the architecture: *if PReduce comprehends PUs and strata at compile time, they can dissolve into propagator-network topology, and the kernel can stay simple.* That challenge holds for almost everything except a small, well-bounded set of irreducible kernel additions. This rev adopts the dissolved architecture; rev 1 is summarized as Appendix A and recoverable from git history (commit prior to this rev).

**Architectural shift from rev 2 (rev 2.1, scope addendum)**: Rev 2 claimed the kernel needed only two additions (`cell_reset` + topology-mutation deferral). A subsequent finding (Racket's `fork-prop-network` at `propagator.rkt:715-719` gives each forked sub-network its own fresh fuel counter, used by `process-naf-request` for inner-goal isolation) revealed that **per-scope fuel is a third irreducible kernel concern** — it does not dissolve into topology because per-PU isolation requires the kernel to attribute fire-fuel to the originating scope, and bound divergent sub-computations without depleting the parent's budget. This rev adds a minimal scope mechanism (4 APIs: `scope_enter` / `scope_run` / `scope_read` / `scope_exit`) to the kernel. Most of rev 2's wins (no stratum-handler register, no worldview at kernel, no entry/exit/halt tables, no per-PU arena, no IR node-kind growth) survive. Total kernel API surface goes from rev-2's 6 functions to **10 functions** (still 6 functions less than rev 1's ~12+ PU primitive API). See § 2.5 for the analysis.

**Cross-references**:

*Track-internal*
- [Sprint G — Tail-Rec as PU + Iteration Stratum](2026-05-02_SPRINT_G_PU_ITERATION_STRATUM.md) — narrow case; this doc supersedes its kernel section
- [Depth Alignment Research rev 2](2026-05-02_DEPTH_ALIGNMENT_RESEARCH.md) — origin (CALM critique)
- [Low-PNet IR Track 2 (2026-05-02)](2026-05-02_LOW_PNET_IR_TRACK2.md) — IR substrate
- [SH Series Alignment](2026-05-02_SH_SERIES_ALIGNMENT.md) — track placement
- [BSP Native Scheduler](2026-05-01_BSP_NATIVE_SCHEDULER.md) — current native kernel state
- [SH Master Tracker](2026-04-30_SH_MASTER.md) — Track 4 (production substrate) and Track 6 (runtime services)
- [DEFERRED.md § "Off-Network Registry Scaffolding"](DEFERRED.md) — PM Track 12 boundary; Category D in § 9.1 below
- [PM Master § Track 12](2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) — owns `with-speculative-rollback` retirement (coordinate sequencing)

*Project rules*
- `.claude/rules/stratification.md` — canonical taxonomy (S0, Topology, S1 NAF, S0 Guard, S(-1), L1, L2, Stratum 3)
- `.claude/rules/on-network.md` — design mantra ("off-network state is debt against self-hosting")
- `.claude/rules/workflow.md` § "Ban 'pragmatic'…" — scaffolding-without-retirement-plan rule
- `.claude/rules/propagator-design.md` — fan-in / set-latch / fire-once patterns

*Prior art (research + design)*
- [BSP-LE Track 2 Design (2026-04-07)](2026-04-07_BSP_LE_TRACK2_DESIGN.md) §2.5a — "decisions are primary, worldview is derived"
- [BSP-LE Track 2 Stage 1 Audit §4.3a](../research/2026-04-07_BSP_LE_TRACK2_STAGE1_AUDIT.md) — PU-per-branch ATMS architecture (now: per-branch tagged-value tagging within global HAMT)
- [SRE Track 2G Design (2026-03-30)](2026-03-30_SRE_TRACK2G_DESIGN.md) §3.1 — Phase 6 PU scaffolding lesson
- [SRE Track 2G PIR (2026-03-30)](2026-03-30_SRE_TRACK2G_PIR.md) §5 — "30-line eager scaffolding for what's structurally a PU" precedent
- [PAR Track 0 CALM Audit (2026-03-27)](2026-03-27_PAR_TRACK0_CALM_AUDIT.md) — first canonical "non-monotone in S0 → stratify" precedent
- [Propagator Network Taxonomy (2026-03-21) §9.3](../research/2026-03-21_PROPAGATOR_NETWORK_TAXONOMY.md) — original PU formulation (structural decomposition)
- [PTF Master § PU pattern](2026-03-28_PTF_MASTER.md) — reusable pattern catalog

*Project artifacts*
- `runtime/prologos-runtime.zig` — current Zig kernel (~545 LOC; `MAX_CELLS`/`MAX_PROPS` flat arrays, single S0 BSP loop). Phase 1 adds `cell_reset` + 2-tier outer loop + topology-mutation deferral; Phase 2 refactors flat arrays to HAMT-rooted.
- `runtime/prologos-hamt.zig` — **Issue #42 Path A, already shipped** (442 LOC; persistent HAMT, path-copy CoW, C-ABI exports `prologos_hamt_*`, 10 Zig unit tests including persistence properties). Substrate for Phase 2 HAMT-rooted cell storage.
- [HAMT Track 6 doc](2026-05-02_HAMT_ZIG_TRACK6.md) — design + scope of the shipped HAMT (notes its GC constraint: "nodes leak on insert/remove")
- `runtime/test-hamt.c` — HAMT C-ABI smoke test
- `racket/prologos/propagator.rkt:84` — `fork-prop-network` provide
- `racket/prologos/propagator.rkt:188` — `register-stratum-handler!` provide
- `racket/prologos/propagator.rkt:715-719` — `fork-prop-network` definition (CHAMP O(1) fork; the canonical "no copying" mechanism this design ports)
- `racket/prologos/propagator.rkt:1145-1154` — `net-cell-reset` (the canonical "non-monotone replace" mechanism; Phase 1 ports this to Zig)
- `racket/prologos/propagator.rkt:1216-1226` — `net-cell-write` (merge mode)
- `racket/prologos/propagator.rkt:1571` — `make-branch-pu` (re-conceptualized as elaborator in this rev)
- `racket/prologos/propagator.rkt:2257-2263` — comment narrating the BSP-LE 2B retirement of `register-topology-handler!` (Category-A retirement; § 9.1)
- `racket/prologos/propagator.rkt:2274-2280` — BSP outer loop's tiered structure (the 2-tier model Phase 1 ports to Zig)
- `racket/prologos/propagator.rkt:2282-2295` — `register-stratum-handler!` (re-conceptualized as elaborator)
- `racket/prologos/propagator.rkt:2330-2536` — `run-to-quiescence-bsp` (the 2-tier outer loop reference impl)
- `racket/prologos/relations.rkt:115-245` — S1 NAF handler (canonical "fork + reset + run + extract" pattern)
- `racket/prologos/meta-universe.rkt` — N→1 compound PU pattern (preserved transparently; § 5.6)
- `racket/prologos/low-pnet-ir.rkt` — current 8 IR node kinds + Sprint-G's `iter-block-decl` (retired Phase 6)
- `racket/prologos/ast-to-low-pnet.rkt:613` — `lower-tail-rec` (rewritten Phase 4)
- `racket/prologos/network-to-low-pnet.rkt` — `prop-network-to-low-pnet` (Phase 2.B); comment update Phase 4
- `racket/prologos/low-pnet-to-llvm.rkt` — `lower-low-pnet-to-llvm` (extended Phase 5 for `cell_reset` emission)
- `tools/pnet-compile.rkt` — end-to-end driver (`.prologos` → `.pnet` → `.ll` → binary)

---

## 1. Summary

A **Pocket Universe (PU)** is a scoped sub-network with its own lifecycle, strata stack, and worldview, communicating with its parent only via designated entry/exit cells. A **stratum handler** is a non-monotone computation that fires after S0 quiescence, advancing state that S0 propagators cannot.

Today, PU-like patterns exist in eight different forms (tabulated in § 3) — most are scaffolding, none are unified, and the Zig kernel can't express them at all (no runtime topology mutation; no `cell_reset`).

**The architectural decision** (this doc): PUs and strata are **compiler abstractions**, not kernel primitives. They live at the Racket-runtime / NTT / PReduce layers; they elaborate to **pure cells + propagators + topology** in Low-PNet IR; the kernel sees only the substrate.

**The kernel adds exactly three things** (§ 6):

1. **`cell_reset(cell, value)`** — non-monotone replace operation. The only cell-write primitive that can't be expressed as a propagator (any monotone encoding has unbounded cell-value growth — see § 2.2).
2. **Topology-mutation deferral**: when `cell_alloc` or `prop_install` is called during a BSP fire round, the kernel defers application to between rounds. This is the BSP-LE 2B mechanism that already exists in the Racket runtime (`propagator.rkt:17-22`); Phase 1 ports it to Zig. (§ 2.3)
3. **Scope APIs** (`scope_enter` / `scope_run` / `scope_read` / `scope_exit`) — minimal nested-execution primitive supporting per-scope fuel budget + per-scope HAMT-rooted snapshot + nested BSP run. Required because per-PU fuel does not dissolve into topology (matches Racket's `fork-prop-network` + nested `run-to-quiescence` pattern at `propagator.rkt:715-719` + `relations.rkt:128-172`). The kernel learns about *scopes* (runtime fuel-attribution units), not *PUs* (compiler abstraction); user-level PUs map onto kernel scopes when they need runtime isolation. (§ 2.5, § 5.9)

The kernel API surface goes from rev-1's ~12 functions to **10 functions** (5 existing + `cell_reset` + 4 scope APIs). No `prologos_pu_*` API. No `register_stratum_handler!` API in the kernel. No new Low-PNet IR node kinds. Scopes are runtime-only; the IR doesn't grow node kinds for them (handler bodies just call the scope APIs from inside their fire-fns).

**The thesis**: the kernel is a minimal substrate; PUs and strata compose above it via elaboration. Sprint G's `iter-block-decl` retires; tail-rec lowers to a self-feedback iteration propagator with `cell_reset` writes. NAF / ATMS handler bodies use the scope APIs for nested isolated runs. **Topology is the language; the kernel runs it; scope is the irreducible runtime concept that sits beside topology, not above it.**

---

## 2. Why the kernel stays minimal — the dissolve audit

The argument for kernel-level PU primitives (rev 1 of this doc) was: PUs are pervasive across NAF / ATMS / iteration / future tracks; one mechanism beats eight. That argument is correct *that the abstractions are real*; it was wrong *about where they need to live*. The challenge: **does each PU/stratum capability dissolve into substrate-level (cell + propagator + topology) representation, or does it require a kernel concept above cells/propagators?**

### 2.1 Capability-by-capability dissolve audit

| Capability | Dissolves into substrate? | How |
|---|---|---|
| **Cell scoping** (R1, R2 — child cells invisible to parent) | ✅ Yes | Compiler emits child cells in a separate cell-id range; only entry/exit propagators bridge the namespaces. The "scoping" is a compile-time discipline; the kernel sees one flat namespace. |
| **Stratum ordering** (handler-N after handler-(N-1)) | ✅ Yes | Topology IS the ordering. Handler-N's input cell is handler-(N-1)'s "done" cell. BSP enqueues handler-N when handler-(N-1) writes "done." |
| **Worldview tagging** (R6 — ATMS branches) | ✅ **Already dissolved** | `tagged-cell-value` is a merge function (`propagator.rkt:1156-1176`). Cells whose merge fn is `make-tagged-merge` accumulate per-worldview entries; readers filter via `current-worldview-bitmask` parameter. Already on-network; no kernel-level concept needed. |
| **Halt-when** (R9 — termination predicate) | ✅ Yes | Guard propagator breaks the iteration cycle. When `cond = halt-when-value`, the iteration propagator writes to a terminal `result` cell instead of looping back; no further enqueue; quiescence terminates. |
| **Nested PUs** (R7 — composability) | 🟡 **Partial** | Nested *topology* dissolves: the compiler emits inner-PU cells/propagators inside outer-PU cell-id range. Nested *runtime fuel scopes* do not — they need a kernel scope stack (§ 2.5, § 5.9). |
| **Static PU lifecycle** (compile-time-known PUs) | ✅ Yes | Pure compile-time elaboration. PReduce / `lower-tail-rec` emits the cells/propagators at build time. Kernel never sees a "PU" for static cases. |
| **Dynamic PU lifecycle** (R10 — ATMS at runtime, recursive NAF, runtime PReduce) | 🟡 **Partial — needs scope** | Topology mutation gives runtime cell/prop allocation (R3); but per-invocation fuel isolation needs the kernel scope mechanism (§ 2.5). NAF inner-goal evaluation is the canonical case: each invocation runs in a fresh scope with its own fuel budget so a divergent inner goal doesn't drain the parent. |
| **Cell-write modes** (R4 — non-monotone state advance) | ❌ **Irreducible** | Cannot be expressed as a monotone propagator; needs `cell_reset`. See § 2.2. |
| **Per-scope fuel + nested BSP run** (Racket's `fork-prop-network` fresh-fuel pattern) | ❌ **Irreducible** | Per-PU fuel attribution requires the kernel to know which scope a fire belongs to. Topology-only encodings either bloat (per-fire decrement of a fuel cell) or fail to isolate (parent fuel still drains on child fires). See § 2.5. |

### 2.2 The irreducible primitive: `cell_reset`

Non-monotone replacement cannot be expressed as a propagator. Propagators in S0 must be monotone (otherwise BSP convergence breaks — the network can oscillate indefinitely). The CALM theorem is precise on this point.

You *can* encode "reset" via versioning: each write writes `(version, value)` to a strictly-monotone version cell; readers extract the latest-version value. But this has **unbounded cell-value growth**. For Pell N=100 iteration, that's 100 entries per state cell. For a long-running ATMS / NAF / PReduce program, the version dimension grows without bound. Not acceptable.

Therefore: the kernel must support a non-monotone replace API. Two design choices for the API:

- **(a) Replace + don't enqueue dependents** — matches Racket's `net-cell-reset` (`propagator.rkt:1145-1154`). Used today only for "clear the request cell" patterns.
- **(b) Replace + enqueue dependents** — useful for iteration's "advance state" pattern.

This rev picks **(a)** to match Racket exactly. For iteration, the compiler emits an explicit re-firing trigger (a monotone counter cell written via `cell_write`) alongside the `cell_reset` calls. Details in § 5.5.

### 2.3 The other irreducible primitive: topology-mutation deferral

For dynamic PU cases (ATMS at runtime, recursive NAF, runtime PReduce passes), the network must grow at runtime. The compiler can't know how many `amb` branches will fire (depends on runtime data) or how many recursive NAF invocations will happen (depends on iteration count). Cells/propagators must be allocatable mid-execution.

The mechanism: `cell_alloc` and `prop_install` callable during a BSP fire round, with kernel-side deferral to between-round application. This is the BSP-LE 2B mechanism, already in the Racket runtime (`propagator.rkt:17-22`):

> During BSP fire rounds (current-bsp-fire-round? = #t):
>   - net-cell-read: allowed (reads from snapshot)
>   - net-cell-write: allowed (value writes captured by CHAMP diff)
>   - net-new-cell: allowed (captured via next-cell-id comparison)
>   - net-add-propagator: allowed but DEFERRED (not on worklist until topology stratum)

The Zig kernel doesn't currently support this — `prologos_cell_alloc` and `prologos_prop_install` are startup-only. Phase 1 ports the Racket mechanism: collect mid-fire alloc/install calls; apply between rounds; new cells get cell-ids assigned post-fire; new propagators get scheduled in the topology tier.

This is **not a "stratum-handler primitive"** — it's a property of the existing cell/propagator APIs. The kernel still has only `cell_alloc` and `prop_install`; their semantics extend to mid-fire calls.

### 2.4 What the kernel doesn't get (be honest)

The kernel doesn't enforce CALM monotonicity. If a propagator calls `cell_reset` from S0 context, BSP convergence guarantees break. By-convention enforcement (matching Racket's `current-bsp-fire-round?` parameter; § 5.5) puts the responsibility on the compiler / handler author. This was the design choice in the previous rev; it survives unchanged.

The kernel doesn't enforce cell-id-namespace isolation between "PUs." The compiler emits child PU cells in a distinct cell-id range; if a buggy propagator writes outside its declared range, the kernel won't catch it. Same trade-off as the by-convention CALM enforcement.

The kernel doesn't have a "stratum handler" type or registration API. Stratum handlers are PROPAGATORS that happen to call `cell_reset` and read a designated request cell. The compiler emits them; the kernel doesn't distinguish them from any other propagator.

### 2.5 The third irreducible primitive: per-scope fuel + nested BSP run

The rev-2 design assumed dynamic PU lifecycle dissolves into "topology mutation between rounds." That assumption is incomplete. **Per-PU fuel does not dissolve into topology**, and per-PU fuel is required by the canonical NAF / ATMS use cases.

**Evidence that Racket needs per-PU fuel today**:

`propagator.rkt:715-719` — `fork-prop-network` gives each fork its own fresh fuel counter (default 1M):

> ```racket
> (define (fork-prop-network net [fuel 1000000])
>   (prop-network
>    (prop-net-hot '() fuel)                              ;; fresh worklist + fuel
>    (prop-net-warm (prop-network-cells net) #f)          ;; shared cells, no contradiction
>    (prop-network-cold net)))                            ;; shared
> ```

`relations.rkt:128-172` — the S1 NAF handler uses this directly: `(define forked (net-cell-reset (fork-prop-network main-net) ...))` then `(define fork3 (run-to-quiescence fork2))`. The fork's BSP run uses its own 1M fuel budget; parent's remaining fuel is untouched by the inner-goal evaluation.

The semantic encoded: **the inner goal gets a bounded but generous budget that doesn't drain the parent's**. A divergent inner goal exhausts the fork's fuel and returns; the parent computation continues with its own fuel intact.

**Why this doesn't dissolve into topology** (audit of attempted encodings):

- *Fuel-cell-per-PU pattern* — every PU body propagator subscribes to a fuel cell, decrements on fire, halt-guard sets a "halted" cell that body propagators check.
  - **Fails**: when local fuel hits 0, body propagators read "halted=true" and skip — but they still fire (kernel still pulls them off worklist), consuming PARENT fuel. The whole point of per-PU fuel is to bound the parent's exposure to a divergent child; this encoding fails that.
- *Multiple `run_to_quiescence` calls with compiler-emitted handoff* — parent stops, child runs separately, result feeds back, parent resumes.
  - **Fails**: this requires the compiler to fragment what's logically one BSP loop into multiple. NAF's "S0 quiesces → handler fires → fork runs nested → handler resumes" is one outer-loop iteration in Racket; splitting it across `run_to_quiescence` calls requires kernel-side suspend/resume — which is heavier than a simple nested run.
- *Single very-large global fuel* — set fuel = 100B, treat exhaustion as catastrophic.
  - **Fails**: doesn't solve isolation. A divergent inner goal consumes 100B fuel; parent never resumes.
- *Per-propagator divergence detection ("fired N times without progress, halt")*.
  - **Fails**: undecidable in general; conflicts with stratified handlers (which legitimately need many rounds to make progress); too heuristic.

The pattern across all attempts: **per-PU fuel requires the kernel to know which propagators belong to which scope** (so it can stop processing them when scope-fuel runs out, without affecting other scopes). That knowledge is irreducibly a kernel concept.

**Therefore**: the kernel must support a scoped nested-execution mechanism. Two design choices:

- **(a) Re-add full PU lifecycle** (rev 1) — heavy; brings back per-PU arenas, strata stack, entry/exit/halt tables.
- **(b) Add a minimal scope mechanism** — kernel-tracked snapshot + fuel + nested run + read + exit. No PU lifecycle, no cell-id namespace isolation, no entry/exit tables, no worldview at kernel.

This rev picks **(b)**. Four kernel APIs (`scope_enter` / `scope_run` / `scope_read` / `scope_exit`); details in § 5.9 and § 6. The scope concept maps onto runtime PUs (each NAF inner-goal evaluation, each ATMS branch run = one scope) but the kernel never names them as PUs — scopes are pure runtime fuel-attribution units.

**What this preserves from rev 2**: cells, propagators, BSP, `cell_reset`, topology-mutation deferral, 2-tier outer loop, single global cell-id namespace, by-convention privilege enforcement, no IR node-kind growth, worldview-tagged values at the merge layer.

**What this does NOT add back from rev 1**: PU as first-class kernel object, stratum-handler register API, per-PU strata stack, entry/exit/halt declarative tables, per-PU arenas, worldview-bit allocator at kernel, cell-id namespace isolation.

The dissolved insight survives — most of it. Per-PU fuel is the one capability that doesn't dissolve, and it's added back at minimum cost (4 narrow APIs) instead of being used to justify the full PU primitive.

---

## 3. Inventory: what exists today (compressed)

| Use case | Today's realization | What's wrong | What it needs (per this design) |
|---|---|---|---|
| **S0 monotone fixpoint** | `propagator.rkt` BSP outer loop, kernel `run_to_quiescence` | Nothing — canonical case | Stays as the inner-loop primitive |
| **Topology mutation** | `register-stratum-handler!` `:tier 'topology` (BSP-LE 2B addendum migrated all topology handlers off the legacy `register-topology-handler!` chain in `propagator.rkt:2257-2263`) | Was previously two mechanisms (legacy + general); now unified at the Racket level | Kernel needs to port the 2-tier outer loop + topology-mutation deferral from Racket to Zig |
| **S1 NAF** | `relations.rkt:115-245` `process-naf-request`: `fork-prop-network` + `net-cell-reset` + handler that runs inner goal in fork, extracts result | Pattern is correct; uses Racket-level `register-stratum-handler!` API | Re-express via the dissolved model: handler IS a propagator; "fork" is HAMT root pointer-share (already in `prologos-hamt.zig`); reset is `cell_reset` |
| **S(-1) Retraction** | `metavar-store.rkt:1392` `run-retraction-stratum!` (sequential, off-network) | Sequential invocation; not a stratum on the BSP base | Re-express as a stratum-handler propagator within the elaborator network's topology |
| **L1 Readiness, L2 Resolution** | `metavar-store.rkt:904, 984` (sequential strata in resolution loop) | Same — sequential, off-network | Same migration pattern |
| **ATMS speculation / branches** | Decision cells + worldview cells + `with-speculative-rollback` macro + box save/restore | `with-speculative-rollback` flagged for PM Track 12 retirement; doesn't compose with self-hosting | Worldview tagging via `tagged-cell-value` (already on-network); branch lifecycle via HAMT root pointer-share (no kernel "PU" needed) |
| **Sprint G iteration** | `iter-block-decl` IR node + LLVM loop in `@main` (in-flight) | Off-network LLVM loop; doesn't compose with NAF/ATMS inside iteration body | Re-express as iteration propagator with `cell_reset` writes + monotone re-firing trigger; pure cells + propagators in Low-PNet IR |
| **Well-founded semantics (S2)** | `wf-engine.rkt` bilattice cells, predicate-level | Not stratum-modeled | Re-express as a stratum-handler propagator with bilattice merge fn |
| **Future fork-on-union (PPN 4C Phase 10)** | Designed; not implemented | N/A | Each alternative branch is a propagator with worldview-tagged writes (already on-network) |
| **Future self-hosted compiler passes** | Not started | N/A | Each pass is a sub-network of cells/propagators in the global namespace; pass output cells become next pass's input cells |

---

## 4. Requirements for the substrate

A general substrate kernel must support:

| # | Requirement | Driving use case | Status |
|---|---|---|---|
| R1 | **Cells + propagators + BSP scheduler** | All | Existing |
| R2 | **Cell-write modes**: merge (existing) + reset (NEW, non-monotone replace) | Iteration, NAF reset, retraction | Phase 1 |
| R3 | **Topology mutation between rounds** — `cell_alloc` / `prop_install` callable mid-fire, deferred | Dynamic PUs (ATMS, recursive NAF, runtime PReduce) | Phase 1 |
| R4 | **2-tier outer loop** — topology mutations applied before value-tier propagators | Required for newly-allocated propagators to fire on subsequent rounds | Phase 1 |
| R5 | **Persistent (HAMT-rooted) cell storage** | O(1) BSP snapshot; per-scope snapshots use HAMT root pointer-share | Phase 2 |
| R6 | **Worldview-tagged values** — `tagged-cell-value` merge function | ATMS branches | Existing (Racket); no kernel changes needed |
| R7 | **Termination** — propagator quiescence + global fuel bound | All | Existing |
| R8 | **Per-scope fuel + nested BSP run** — `scope_enter` / `scope_run` / `scope_read` / `scope_exit`; isolated sub-execution with separate fuel budget against parent | NAF inner-goal evaluation, ATMS branch run, recursive PReduce passes — anywhere a sub-computation must be bounded without depleting parent fuel | Phase 1 (§ 2.5, § 5.9) |

R1, R6, R7 exist today (R6 in Racket). R5 is the `prologos-hamt.zig` wiring (Phase 2). R2-R4 + R8 are the new substrate primitives shipped in Phase 1.

**What the substrate explicitly does NOT provide** (lifted into compiler / Racket runtime):
- Per-PU arenas — one global cell store; PUs are compile-time cell-id ranges; runtime scopes share the global HAMT via root pointer-share
- Per-PU strata stack — strata are encoded as propagator topology
- Stratum-handler registration API — handlers ARE propagators
- PU lifecycle API (`pu_alloc` / `pu_run` / `pu_dealloc`) — PU is a compiler abstraction; the kernel scope mechanism (R8) is narrower than full PU lifecycle and serves only fuel attribution + snapshot isolation
- Privileged-mode cell-write enforcement — by-convention (matches Racket; § 5.5)
- Worldview-bit allocator — managed at the worldview-merge-function layer
- PU "entry / exit / halt" tables — encoded as propagator wiring or done by the handler fire-fn (which calls scope APIs and `cell_write`s back to parent)
- Cell-id namespace isolation per scope — single global cell-id namespace; child scope writes go to scope's HAMT root via R8, not via cell-id discrimination

---

## 5. Architecture — three layers, kernel-minimal

### 5.1 Layered model

```
┌──────────────────────────────────────────────────────────────┐
│ Layer 2: NTT / PReduce / `lower-tail-rec` (compiler)         │
│   - PU and stratum-handler forms (NTT syntax)                │
│   - Iteration form, fork-on-union, ATMS forms                │
│   - Elaborates to Low-PNet IR using existing 8 node kinds    │
│   - NO new IR node kinds; PUs/strata are TOPOLOGY PATTERNS   │
└──────────────────────────┬───────────────────────────────────┘
                           │ Low-PNet IR (cells + propagators
                           │   + dep-edges + write-decls + stratum-decl tier)
┌──────────────────────────┴───────────────────────────────────┐
│ Layer 1: Racket runtime / `propagator.rkt` (interpreter)      │
│   - register-stratum-handler! (re-conceptualized:             │
│     emits "request-cell + handler-propagator" topology)       │
│   - make-branch-pu (re-conceptualized: HAMT root pointer-share)│
│   - 5+ existing production handlers — API unchanged            │
│   - low-pnet-to-prop-network adapter (Phase 4 deliverable)     │
└──────────────────────────┬───────────────────────────────────┘
                           │ cell + propagator + cell_reset
                           │   + topology-mutation deferral
┌──────────────────────────┴───────────────────────────────────┐
│ Layer 0: Kernel substrate (Zig)                                │
│   - cell_alloc, prop_install (callable mid-fire, deferred)     │
│   - cell_read, cell_write (merge), cell_reset (replace, NEW)   │
│   - run_to_quiescence (2-tier outer loop)                      │
│   - HAMT-rooted cell store (Phase 2; O(1) snapshot)            │
│   - scope_enter / scope_run / scope_read / scope_exit (NEW;    │
│     per-scope fuel + nested BSP run; § 5.9)                    │
└────────────────────────────────────────────────────────────────┘
```

### 5.2 Layer 0 — kernel substrate (Zig)

**Responsibilities**: run cells + propagators in BSP rounds; merge writes via cell merge functions; defer mid-fire topology mutations to between-round application; provide `cell_reset` for non-monotone replace; provide scoped nested BSP runs with per-scope fuel attribution.

**What the kernel knows**: cell-ids (u32), propagator-ids, cell values (i64), merge functions per cell domain, fire functions per propagator (dispatched via `HandlerTag` / `FIRE-FN-TAG-REGISTRY`), cell-id namespaces (global, single), the 2-tier outer loop ordering invariant, a stack of active scopes (each with its own HAMT root, worklist, and fuel counter; current scope = top-of-stack).

**What the kernel doesn't know**: PUs (compile-time abstraction), strata (compile-time abstraction; ordering encoded in topology), branches (compile-time abstraction; runtime divergence via worldview tagging), worldviews (Racket parameter / merge-function concern), stratum handlers (just propagators), entry/exit tables (propagator wiring), halt-when predicates (in fire-fn body), NAF / ATMS / iteration (compile-time elaboration). Those are all Layer 1 / Layer 2 concepts that elaborate to substrate-level cells/propagators or use the scope APIs from inside a fire-fn body.

The 2-tier outer loop:

```
run_to_quiescence(fuel):
  while fuel > 0:
    # Tier 1: topology — apply deferred cell_alloc/prop_install from previous fires
    apply_pending_topology_mutations()
    schedule_newly_installed_propagators()

    # Tier 2: value — fire propagators in BSP rounds until S0 quiesces
    while worklist non-empty and fuel > 0:
      snapshot = current cell store
      for propagator in worklist:
        fire propagator on snapshot
        collect writes (merge or reset)
        collect new cell_alloc / prop_install calls (deferred)
        decrement fuel
      apply collected writes to cell store
      enqueue propagators that subscribed to changed cells

    # Quiescence reached. If topology mutations were deferred, loop.
    if no pending topology and no new worklist entries:
      return halt
```

This is the existing Racket pattern (`propagator.rkt:2274-2280`, `:2330-2536`) ported to Zig.

### 5.3 Layer 1 — Racket runtime (propagator.rkt)

**Existing API stays the same**. The 5 production callers of `register-stratum-handler!` (NAF, narrowing, sre-core, elaborator-network, typing-propagators) and the `make-branch-pu` users continue to work unchanged.

**Implementation re-conceptualization**:

- `register-stratum-handler! request-cell handler-fn :tier 'value` — was: registers a handler in the Racket-level tiered outer loop. Now: same registration, but conceptually "this is an elaborator that emits a propagator whose input is `request-cell` and whose body is `handler-fn` (allowed to call `cell_reset`)." The Racket runtime implements this by inserting the handler into its outer loop, equivalent to emitting the corresponding propagator in the network. From the kernel's view (when this code is lowered for native execution): the handler is just a propagator.

- `make-branch-pu parent-net assumption-id [bit-position]` — was: forks the parent network via `fork-prop-network`. Now: same fork, but conceptually "this is an elaborator that produces a HAMT root pointer-share." The branch is just a derived HAMT root. ATMS branches use `tagged-cell-value` writes within the shared HAMT for worldview divergence.

The semantic shift is: these APIs are abstraction-layer helpers on top of the substrate, not runtime primitives that the kernel implements. The kernel knows about cells, propagators, BSP, and `cell_reset`; the Racket runtime knows about strata, handlers, and PUs.

### 5.4 Layer 2 — NTT / PReduce / lower-tail-rec (compiler)

NTT keeps `pocket-universe` and `stratum-handler` forms (§ 7). PReduce understands them semantically. At compile time, PReduce / `lower-tail-rec` elaborates each form into substrate-level cells + propagators + dep-edges in Low-PNet IR.

Examples:

- An NTT iteration form lowers to: state cells + iteration propagator (with `cell_reset` writes for non-monotone advance + a `cell_write` to a tick counter for re-firing) + halt-guard propagator.
- An NTT stratum-handler form lowers to: a request cell (with set-union merge) + a handler propagator (input = request cell; body = the handler's NTT body, including `cell_reset` calls; clears request cell at exit).
- An NTT pocket-universe form lowers to: a contiguous cell-id range for the PU's scope + entry propagators (parent → child) + exit propagators (child → parent) + the PU's body cells/propagators.

**Critical**: Low-PNet IR does NOT grow new node kinds for these patterns. The existing 8 kinds (`cell-decl`, `propagator-decl`, `domain-decl`, `write-decl`, `dep-decl`, `stratum-decl`, `entry-decl`, `meta-decl`) plus the existing `stratum-decl` tier ordering are sufficient.

### 5.5 Cell write semantics

Two cell-write modes (matches Racket's two-mode model — `net-cell-write` and `net-cell-reset` in `propagator.rkt:1216, 1145`):

| Mode | API | Semantics | Caller (by convention) |
|---|---|---|---|
| **merge** | `cell_write(cid, value)` | apply domain merge fn; enqueue dependents | propagators (S0); also fine from handlers |
| **reset** | `cell_reset(cid, value)` | replace value, no merge; **does NOT enqueue dependents** | stratum-handler propagators only |

**Iteration's "advance state" pattern**:

Because `cell_reset` doesn't enqueue dependents, the iteration propagator needs another way to re-fire. The pattern emitted by `lower-tail-rec`:

```
;; Compiler emits (substrate-level Low-PNet IR):
cell-decl: state-a, state-b, n, tick, result, cond
propagator-decl: iter-step
  inputs: state-a, state-b, n, tick     ;; tick triggers re-firing
  outputs: state-a, state-b, n, tick, result
  body:
    if n = 0:
      cell_write(result, state-a)       ;; merge mode; final write
      ;; no writes to a/b/n/tick → no re-enqueue → quiesce
    else:
      cell_reset(state-a, state-b)      ;; non-monotone replace
      cell_reset(state-b, state-a + state-b)
      cell_reset(n, n - 1)
      cell_write(tick, tick + 1)        ;; merge mode (LWW or +1 monotone);
                                        ;; enqueues iter-step for next round
```

The `tick` cell is a monotone counter (e.g., LWW); each `cell_write(tick, +1)` enqueues `iter-step` (because `iter-step` subscribes to `tick`); BSP next round fires `iter-step` again with the reset state values.

**Privilege enforcement** is by convention, not runtime-checked. Matches Racket's `current-bsp-fire-round?` model. Code comments at each API entry-point document which mode is permitted in S0 vs handler context. The kernel does NOT trap if an S0 propagator calls `cell_reset` (matches Racket).

**For the merge mode to be testable**, Phase 1 ships at least one non-trivial merge fn (`min`-merge i64 — useful for fuel cells anyway). Without this, `cell_write` and `cell_reset` are observationally identical under the LWW-only kernel and the test gate "verify merge vs reset semantics" is vacuous. See § 14 Phase 1.

### 5.6 Worldview integration — already on-network

ATMS branches don't need a kernel "PU per branch" concept. The mechanism is already on-network at the merge-function layer:

- A cell whose merge fn is `make-tagged-merge` accumulates `(hasheq worldview-bit-set → value)` entries
- Writes during a speculation use `current-worldview-bitmask` parameter; the merge fn tags the new value
- Reads filter by current worldview's bit-set; entries from non-matching branches are invisible

This is `propagator.rkt:1156-1176` (`promote-cell-to-tagged`, `make-tagged-merge`). No kernel changes; PReduce just configures the appropriate merge functions for cells that participate in ATMS.

**Compound-cell pattern preserved**: `racket/prologos/meta-universe.rkt`'s N→1 compound PU pattern (4 compound cells holding `(hasheq meta-id → tagged-cell-value)`) keeps working transparently. The kernel doesn't care about the cell's value shape; cells hold `i64` (today) or richer values (future); the N→1 compound is an application-level convention on the cell's value type.

### 5.7 Tier dispatch (kernel invariant, not API)

Kernel's 2-tier outer loop (§ 5.2): topology mutations applied first; then value-tier propagators fire. This matches Racket's `propagator.rkt:2274-2275`:

> S0 → topology-tier strata → (S0 restart if new worklist) → value-tier strata → (S0 restart if new worklist) → fixpoint.

The kernel knows about exactly **2 tiers** (topology and value). Finer-grained ordering between value-tier handlers is encoded in topology — handler-N's input cell is handler-(N-1)'s output cell.

**This is not an API.** It's an outer-loop invariant. Compilers / Racket runtime / handler authors don't get to override the tier ordering at the kernel level; they encode finer ordering as topology.

### 5.8 Communication contract — entry/exit/halt as topology

Compile-time, PReduce / `lower-tail-rec` emits:

- **Entry**: a propagator that reads a parent cell at PU start, writes to a child cell. The compiler ensures this propagator fires before any other propagator in the PU's body (via topology — its output is the input of the body propagators).
- **Exit**: a propagator that reads a child cell after the PU body quiesces, writes to a parent cell. Topology again — its input is the body's "result" cell.
- **Halt-when**: a guard inside the iteration propagator (§ 5.5 iteration pattern) — when `cond` matches `halt-when-value`, the propagator skips the loop-back writes; quiescence terminates the iteration.

No kernel-level entry/exit/halt tables. The compiler emits the wiring; the kernel runs it.

For *static* PUs (compile-time-known body, no per-invocation isolation needed), this is the entire story. For *dynamic* PUs that need per-invocation fuel isolation (NAF, ATMS, recursive PReduce), the handler fire-fn additionally uses the scope APIs (§ 5.9) to wrap the inner run.

### 5.9 Scope and nested execution

A **scope** is the kernel's runtime fuel-attribution unit. The kernel maintains a stack of active scopes; the top-of-stack is the *current* scope, against which all cell reads/writes and propagator fires are accounted.

**Scope mechanics**:

- `scope_enter(parent_fuel_charge)` — pushes a new scope onto the stack:
  - Snapshots the current scope's HAMT root (O(1) pointer-share via `prologos-hamt.zig`).
  - Allocates a fresh worklist (initially empty) and a fresh fuel counter (set on the next `scope_run` call).
  - Charges `parent_fuel_charge` against the *parent* scope's fuel (the cost of creating the scope; small fixed value).
  - Returns a `ScopeRef` handle.

- `scope_run(scope, fuel)` — runs the BSP outer loop on `scope` with its own fuel budget:
  - Sets `scope`'s fuel counter to `fuel`.
  - Runs the 2-tier outer loop: topology mutations applied first, then value-tier propagators fire, until quiescence or fuel exhaustion.
  - Writes during this run go to `scope`'s HAMT root (via path-copy CoW); parent's HAMT is unaffected.
  - Mid-fire `cell_alloc` / `prop_install` calls during the scope run go to `scope`'s data, deferred per the topology-mutation mechanism.
  - Returns `RunResult` (`halt` / `fuel_exhausted` / `trap`).
  - **Blocking semantic**: the calling fire-fn (in the parent scope) is paused until `scope_run` returns. The parent's BSP outer loop is suspended; only `scope`'s propagators fire during this call.

- `scope_read(scope, cell)` — reads a cell value from `scope`'s HAMT root. Used after `scope_run` returns to extract results.

- `scope_exit(scope)` — pops `scope` off the stack:
  - Releases `scope`'s HAMT root reference (the HAMT itself is GC'd when no other refs hold it).
  - Parent scope's HAMT is unchanged (writes during the scope run did NOT propagate to parent unless the handler explicitly called `cell_write` on a parent cell).
  - **Important**: any results the handler wants to publish to the parent must be explicitly written via `cell_write` on parent-scope cells before calling `scope_exit`.

**Nesting**: scopes nest. A handler propagator firing in scope A can call `scope_enter` to push scope B; the fire-fn in scope B can in turn call `scope_enter` to push scope C; and so on. Each scope has its own fuel and HAMT root. Stack-discipline: the kernel requires `scope_exit` calls to be properly nested (LIFO with respect to `scope_enter`).

**Scope vs PU correspondence** (one-to-one when a runtime PU is invoked, but they're different concepts):

| Compile-time concept (Layer 2) | Runtime mechanism (Layer 0) |
|---|---|
| A *static* PU (compile-time-known body, no per-invocation isolation) | Plain cells/propagators in the global scope; no scope_* APIs needed. |
| A *dynamic* PU invocation (NAF inner-goal eval, ATMS branch run, recursive PReduce) | One `scope_enter` / `scope_run` / `scope_read*` / `scope_exit` cycle inside the handler's fire-fn. |
| Nested PUs | Nested scopes (LIFO stack). |
| Multiple invocations of the same PU definition | Multiple scope cycles (one per invocation), each with its own fuel. |

**Why scope, not PU**: the kernel doesn't need to know "this scope corresponds to a NAF inner goal" or "this scope is an ATMS branch." It only needs to attribute fuel and isolate snapshots. *Naming it scope (a runtime mechanism) instead of PU (a compile-time abstraction) keeps the kernel honest about what it actually does.*

**Reference implementation in Racket**: `fork-prop-network` (`propagator.rkt:715-719`) + `run-to-quiescence` invocation on the fork. The Racket runtime calls these explicitly inside handler bodies; the kernel-side scope APIs are the same pattern with explicit enter/exit/read calls instead of implicit Racket box mutation.

**Worked example — NAF handler using scope APIs**:

```
fire-fn-naf-handler(naf-pending-cell):
  pending = cell_read(naf-pending-cell)
  for (naf-aid, info) in pending:
    scope = scope_enter(parent_fuel_charge=10)
    ; install inner-goal cells/props (deferred mid-fire; appear in scope)
    inner-goal-cells = cell_alloc(...)
    install-inner-goal-propagators(inner-goal-cells, info)
    result = scope_run(scope, fuel=1_000_000)
    if result == halt:
      inner-provable = scope_read(scope, inner-result-cell) != bottom
      if inner-provable:
        ; Write nogood to parent worldview
        wv = cell_read(worldview-cache-cell)
        cell_write(worldview-cache-cell, wv & ~(1 << naf-bit-pos))
    scope_exit(scope)
  cell_reset(naf-pending-cell, empty)  ; clear request
```

This matches `process-naf-request` (`relations.rkt:115-245`) one-to-one in semantics; the migration in Phase 5 (Category C in § 9.1) is a mechanical re-expression of the existing handler against the kernel scope APIs.

---

## 6. Kernel API surface (Zig signatures)

```zig
// Existing
pub const CellRef = u32;        // global cell-id namespace
pub const PropRef = u32;
pub const HandlerTag = u32;     // dispatched via FIRE-FN-TAG-REGISTRY pattern (§ 15.3)
pub const ScopeRef = u32;       // NEW — opaque kernel-tracked scope handle (§ 5.9)

pub const RunResult = enum(u8) { halt, fuel_exhausted, trap };

pub extern fn prologos_cell_alloc(domain: u8, init: i64) CellRef;
pub extern fn prologos_prop_install(
    fire_fn: HandlerTag,
    in_cells: [*]const CellRef, in_count: u8,
    out_cells: [*]const CellRef, out_count: u8,
) PropRef;
pub extern fn prologos_cell_read(cell: CellRef) i64;
pub extern fn prologos_cell_write(cell: CellRef, value: i64) void;     // merge mode
pub extern fn prologos_run_to_quiescence(fuel: u64) RunResult;

// NEW — non-monotone replace
pub extern fn prologos_cell_reset(cell: CellRef, value: i64) void;
//   replace; no merge; no enqueue dependents
//   by-convention: only called from stratum-handler propagators
//   matches Racket's net-cell-reset (propagator.rkt:1145-1154)

// NEW — scope APIs (§ 5.9; matches Racket's fork-prop-network + run-to-quiescence
//                    pattern at propagator.rkt:715-719 + relations.rkt:128-172)
pub extern fn prologos_scope_enter(parent_fuel_charge: u64) ScopeRef;
//   Push new scope. Snapshots current scope's HAMT root (O(1) pointer-share).
//   Charges parent_fuel_charge against parent scope's fuel.
//   Returns ScopeRef handle.

pub extern fn prologos_scope_run(scope: ScopeRef, fuel: u64) RunResult;
//   Run BSP outer loop on `scope` with its own fuel budget.
//   Writes go to `scope`'s HAMT (CoW); parent unaffected.
//   Blocks calling fire-fn until scope quiesces or fuel exhausts.
//   Mid-fire cell_alloc / prop_install during this run go to `scope`.

pub extern fn prologos_scope_read(scope: ScopeRef, cell: CellRef) i64;
//   Read a cell value from `scope`'s HAMT root.
//   Used after scope_run to extract result before scope_exit.

pub extern fn prologos_scope_exit(scope: ScopeRef) void;
//   Pop scope. Releases scope's HAMT root reference.
//   Parent's HAMT unchanged unless handler explicitly cell_write'd to parent.
//   Stack-discipline: must be properly nested (LIFO) with respect to scope_enter.
```

**Implicit semantics changes** (Phase 1):
- `cell_alloc` and `prop_install` during a fire round: deferred to next-round application (matches Racket's BSP-LE 2B mechanism)
- `run_to_quiescence` runs the 2-tier outer loop: topology then value (matches `propagator.rkt:2274-2280`)
- `cell_alloc` / `prop_install` / `cell_read` / `cell_write` / `cell_reset` always target the *current scope* (top-of-stack); the global root scope is the default.

**10 functions** total; 5 genuinely new (`cell_reset` + 4 scope APIs). The deferral and 2-tier outer loop are mechanism changes to the existing `cell_alloc` / `prop_install` / `run_to_quiescence` functions, not new APIs.

Notes:
- Matches Racket two-mode model exactly (§ 5.5). No `cell_overwrite` (replace + enqueue) — earlier rev had this; dropped because it was ergonomic-only and Racket doesn't have it.
- Scope is the runtime fuel-attribution + snapshot-isolation mechanism (§ 5.9). It is *not* a PU — PUs are compile-time abstractions; the kernel doesn't name them. Scopes nest via the kernel's stack.
- No PU handle (use `ScopeRef` for runtime; PUs are compile-time abstractions). No worldview-bit parameter. No entry/exit/halt setters. No stratum-handler register. Those are Layer 1 / Layer 2 concepts.
- Privilege enforcement on `cell_reset` is by convention (matches Racket; § 5.5). No runtime trap.
- `RunResult` includes `trap` — propagators may trap on contradiction; the kernel propagates from `scope_run` to the calling fire-fn just like from top-level `run_to_quiescence`.

---

## 7. NTT model (compiler-layer abstractions)

Per the workflow rule "NTT model REQUIRED for propagator designs," speculative NTT syntax. **These are Layer 2 forms; they elaborate to Layer 0 substrate at compile time.**

```ntt
;; Iteration form — elaborates to substrate per § 5.5 iteration pattern
(iteration iter-pell
  (:state
    (state-a :lattice :scalar :init 0)
    (state-b :lattice :scalar :init 1)
    (n       :lattice :scalar :init :input))
  (:advance
    (state-a ← state-b)
    (state-b ← state-a + state-b)
    (n       ← n - 1))
  (:halt-when (= n 0))
  (:result state-a))


;; Stratum-handler form — elaborates to (request-cell + handler-propagator)
(stratum-handler atms-fork-handler
  (:request-cell  fork-request-cell)
  (:tier          :value)
  (:body
    (let ((b (make-branch-pu current-net (allocate-bit))))
      (within-branch b (run-inner-goal))
      (commit-or-retract b))))


;; Pocket-universe form — elaborates to (cell-id range + entry/exit propagators + body)
(pocket-universe naf-goal
  (:cells (goal-result :lattice :bool :init :bot))
  (:entry  (parent-context → goal-context))
  (:exit   (goal-result → parent-naf-result))
  (:body
    (run-goal goal-context goal-result)))
```

### NTT correspondence table — what elaborates to what

| NTT form | Elaboration target (Layer 0 substrate) | Mediated by |
|---|---|---|
| `(iteration ... :advance ... :halt-when ...)` | iteration propagator with mixed `cell_write` / `cell_reset` writes (§ 5.5) + monotone tick cell | `lower-tail-rec` (Phase 4) |
| `(stratum-handler ... :body ...)` (static, no per-invocation isolation) | request cell + handler propagator subscribing to it | PReduce stratum elaborator (future track); `register-stratum-handler!` in Racket runtime today |
| `(pocket-universe ... :cells ... :entry ... :exit ... :body ...)` (static) | child cell-id range + entry propagators + exit propagators + body cells/propagators | PReduce PU elaborator (future track); `make-branch-pu` in Racket runtime today |
| `(stratum-handler ... :scoped #t :inner-fuel N :body ...)` (dynamic, per-invocation isolation — NAF / ATMS pattern) | request cell + handler propagator whose fire-fn calls `scope_enter` / `scope_run(fuel=N)` / `scope_read*` / `scope_exit` around the inner work | PReduce + scope-aware elaborator (Phase 4-5); `process-naf-request` in Racket runtime today (uses `fork-prop-network` + nested `run-to-quiescence`) |
| `(within-branch b ...)` | sets `current-worldview-bitmask` for writes inside body (within active scope) | `tagged-cell-value` merge fn |
| `(allocate-bit)` | calls into worldview-bit allocator (Racket-level function) | Existing Racket utility |

### NTT gaps surfaced

1. NTT today has no iteration syntax — forms above are speculative. PReduce will define them.
2. NTT today has no `:advance` / `:halt-when` clauses — needed for iteration form.
3. NTT today has no PU-as-form — needed for `pocket-universe` form.

These are recorded for the future PReduce / NTT track. **None require kernel changes** — they all elaborate to existing kernel primitives.

---

## 8. Lowering implications

### 8.1 Low-PNet IR — NO new node kinds

The current Low-PNet IR has 8 node kinds (`cell-decl`, `propagator-decl`, `domain-decl`, `write-decl`, `dep-decl`, `stratum-decl`, `entry-decl`, `meta-decl`) plus Sprint G's `iter-block-decl`.

**After this design**:

- **NO new node kinds added.** The 8 existing kinds are sufficient to express PUs, strata, iteration, NAF, ATMS as topology patterns.
- `iter-block-decl` is **retired** (Sprint G scaffolding; § 14 Phase 6).
- `write-decl` gains a write-mode tag (`:merge` vs `:reset`) so `lower-low-pnet-to-llvm` can emit `cell_write` vs `cell_reset` appropriately. Backward-compatible default = `:merge`.
- `stratum-decl` continues to express tier ordering (the kernel's 2-tier invariant); no changes.

The IR delta is **one tag field on `write-decl` + `iter-block-decl` deletion** — far smaller than rev 1's "5 new node kinds."

### 8.2 AST → Low-PNet (`ast-to-low-pnet`, Phase 2.D)

`lower-tail-rec` (`ast-to-low-pnet.rkt:613`) refactors to emit the iteration pattern (§ 5.5). NO new IR node kinds emitted. ~80-150 LOC delta (mostly net deletions of bridge-cell scaffolding).

The function emits:
- 4 `cell-decl`s: state cells (a, b), n, tick, result
- 1 `propagator-decl`: iter-step (inputs include tick; outputs include all five cells)
- 5 `dep-decl`s: input subscriptions
- (the propagator's body is a fire-fn — emitted via the existing FIRE-FN-TAG-REGISTRY pattern)
- N `write-decl`s for initial values

For halt detection inside iter-step's body, the fire-fn branches; if `n = 0`, it emits a write-decl with `:merge` mode (final write to result); otherwise it emits write-decls with `:reset` mode (state advance) plus a `:merge` mode write to tick (re-firing trigger).

### 8.3 Low-PNet → LLVM (`lower-low-pnet-to-llvm`, Phase 2.C/D)

Adds emission for `cell_reset` (write-decl with `:reset` mode tag) — calls `prologos_cell_reset` instead of `prologos_cell_write`. Removes Sprint G's `@main`-loop emission paths.

NO PU-specific emission paths. All cells / propagators emit the same way they do today; the only delta is per-write-decl mode dispatch.

### 8.4 prop-network → Low-PNet (`prop-network-to-low-pnet`, Phase 2.B)

No change needed. The existing translator already emits cells / propagators / write-decls / dep-decls. With write-decl gaining a mode tag, `prop-network-to-low-pnet` should emit `:reset` for cells written via `net-cell-reset` and `:merge` for cells written via `net-cell-write`. ~10 LOC.

---

## 9. Migration of existing strata + Sprint G

The track-by-track migration plan:

| Track | What migrates | Mechanism (per dissolved arch) | Effort | Risk |
|---|---|---|---|---|
| **Topology stratum** | ~~replace legacy `register-topology-handler!`~~ — **already done** (BSP-LE 2B addendum, 2026-04-16; `propagator.rkt:2257-2263`). | Remaining work: kernel-level 2-tier outer loop (Phase 1). | small | low — mechanical |
| **S1 NAF** | Re-express `process-naf-request` to use the dissolved + scope pattern: handler IS a propagator, `fork-prop-network` becomes `scope_enter`+`scope_run`+`scope_read`+`scope_exit` (per-invocation fuel isolation), reset is `cell_reset`. | API unchanged at the Racket level (`register-stratum-handler!` + `fork-prop-network`); native implementation maps to scope APIs (§ 5.9 worked example). | medium | medium |
| **S(-1) Retraction** | Promote from sequential `run-stratified-resolution!` invocation to a stratum-handler propagator subscribed to a retraction-request cell. | Same handler logic; encoded as substrate-level propagator. | medium | low |
| **L1, L2 (constraint resolution)** | Same — promote to stratum-handler propagators. | Same pattern. | medium | low |
| **Sprint G iteration** | Replace `iter-block-decl` lowering with the iteration pattern (§ 5.5); `iter-block-decl` is **retired** (deleted, Phase 6). | `lower-tail-rec` emits cell-decl + propagator-decl + dep-decl + write-decl (with mode tags); LLVM emitter dispatches on write-mode. | small | low — IR substrate is reused; specific node kind is not |
| **ATMS branches** | Use `tagged-cell-value` merge functions (already on-network) for worldview tagging; per-branch run uses scope APIs (`scope_enter`/`scope_run`/`scope_exit`) for fuel isolation when the branch evaluation might diverge. | No kernel "branch" primitive needed (worldview tagging at merge layer); scope APIs for fuel isolation per-branch run. | medium-large | medium |
| **Future: fork-on-union** | Same as ATMS branches (worldview-tagged writes per alternative). | (covered by ATMS) | | |
| **Future: well-founded semantics** | Bilattice cells become a stratum-handler propagator with bilattice merge fn. | medium-large | medium |
| **Future: self-hosted compiler passes** | Each pass is a sub-network of cells/propagators in the global namespace; pass output cells become next pass's input cells. | NO kernel "PU pass" concept; just compositional topology. | large | low |

The Sprint G **iteration stratum** lands FIRST (smallest, validates the substrate). NAF / S(-1) / L1 / L2 next (medium). ATMS last (largest, retires `with-speculative-rollback` once PM Track 12 closes its dependent retirements).

**Workflow-rule citation against Sprint G** (`.claude/rules/workflow.md` § "Ban 'pragmatic'…" + "scaffolding without a retirement plan"). Sprint G's `iter-block-decl` framed itself as pragmatic realization of the iteration-stratum NTT, but did not name the artifact's retirement plan: an LLVM loop in `@main` is **off-network surface** with no path back on-network short of the work this doc proposes. § 14 Phase 6 deletes `iter-block-decl`; Phase 4 retargets `lower-tail-rec` to the substrate-level iteration pattern.

### 9.1 Legacy ordering-enforcement scaffolding inventory

A full audit of pre-existing scaffolding for ordering / strata / non-monotone enforcement, with retirement responsibility assigned. Phase 6 deletes the items in **B**; Phases 4-5 migrate the items in **C**; this track does **not** touch items in **D** (other tracks own them) or **E** (intentionally kept).

**Category A — Already retired (cite for context, do not re-retire)**

| Artifact | Where | Status | Retired by |
|---|---|---|---|
| `register-topology-handler!` legacy try-each chain | `propagator.rkt:2257-2263` (retirement comment) | RETIRED | BSP-LE 2B addendum, 2026-04-16. All topology handlers migrated to `register-stratum-handler!` with `:tier 'topology`. |
| `current-speculation-stack` parameter / TMS mechanism | `propagator.rkt:1359` (retirement comment) | RETIRED | TMS retirement S1.a-c. Replaced by tagged-cell-value worldview tagging. |
| `save-base-elaboration-network` | `metavar-store.rkt:2901` (retirement comment) | RETIRED | Track 7 Phase 6. Persistent cells now in dedicated registry network. |

**Category B — Retired by THIS track (Phase 6 deletion)**

| Artifact | Where | Why it goes |
|---|---|---|
| `iter-block-decl` IR node | `racket/prologos/low-pnet-ir.rkt:29` (provide), `:102-126` (struct), `:251-262` (parse), `:288` (pp), `:373-383` (validate) | Sprint G scaffolding; replaced by substrate-level iteration pattern (§ 5.5, § 14 Phase 4). |
| Sprint G `@main`-loop emission paths | `racket/prologos/low-pnet-to-llvm.rkt` (Sprint G additions) | Same — Phase 5 emits `cell_reset` / `cell_write` calls instead. |
| Sprint G depth-alignment + bridge-cell helpers in `lower-tail-rec` | `racket/prologos/ast-to-low-pnet.rkt` (around `:613` `lower-tail-rec`; the depth-alignment + identity-bridge helpers introduced for Sprint G's lowering shape) | `lower-tail-rec`'s rewrite (§ 14 Phase 4) makes them unreachable. |
| `run-stratified-resolution!` (imperative variant) | `racket/prologos/metavar-store.rkt:2079` | Already documented as "mostly dead code — superseded by `run-stratified-resolution-pure`" (`:2075-2078`). Phase 5 finishes the retirement. |
| `current-in-stratified-resolution?` parameter | `racket/prologos/metavar-store.rkt:2081` | Used only by `run-stratified-resolution!`; goes with it. |

**Category C — Migrated (NOT deleted) by THIS track (Phases 4-5)**

| Artifact | Where | What changes |
|---|---|---|
| `lower-tail-rec` | `racket/prologos/ast-to-low-pnet.rkt:613` | Phase 4: emits substrate-level iteration pattern (§ 5.5) instead of `iter-block-decl`. Same function, different IR output. |
| `run-stratified-resolution-pure` | `racket/prologos/metavar-store.rkt:2131` | Migrate from explicit S(-1) → S0 → S1 → S2 sequencing to a **registered set of stratum-handler propagators** subscribed to per-stratum request cells. The kernel's 2-tier outer loop drives the same sequence. Net: explicit Racket loop becomes data; ordering is enforced by topology + tier. |
| `process-naf-request` (S1 NAF handler) | `racket/prologos/relations.rkt:115-245` | Phase 5+: re-express via dissolved pattern (handler IS a propagator; fork via HAMT root pointer-share; reset via `cell_reset`). API unchanged at the call-site level. |

**Category D — Flagged for OTHER tracks (do NOT retire here; coordinate)**

| Artifact | Owning track | Status here |
|---|---|---|
| `with-speculative-rollback` | PM Track 12 light cleanup (~20-30 min mechanical, 6 caller sites) per `DEFERRED.md` § "PM Track 12 design input from PPN 4C Phase 1A-iii-a-wide Step 1 + T-1" | **Do not touch.** This track ships the substrate (worldview-tagged HAMT cells); PM 12 uses it. |
| `save-meta-state` / `restore-meta-state!` | Internal to `elab-speculation-bridge.rkt`; retires alongside `with-speculative-rollback` | **Do not touch.** |
| Off-network registry parameters (Hasse-registry, impl registry, type-meta universe Racket parameters, per-domain meta-store parameters, etc.) | PM Track 12 (catalogued in `DEFERRED.md` § "Off-Network Registry Scaffolding") | **Do not touch.** |

**Category E — Intentionally kept (not legacy; not in scope)**

| Artifact | Where | Why kept |
|---|---|---|
| `current-bsp-fire-round?` parameter | `propagator.rkt` (early comment block lines 17-22) | The by-convention privilege signal; matches our § 5.5 design choice. **Not legacy.** |
| `with-forked-network` macro | `propagator.rkt:729-740` | Useful test-isolation utility. **Not legacy.** |
| `register-stratum-handler!` + tiered BSP outer loop | `propagator.rkt:2282`, `:2330-2536`, `:2487` | Re-conceptualized as elaborator (§ 5.3); API unchanged. **Not legacy.** |
| `make-branch-pu` + `fork-prop-network` | `propagator.rkt:1571`, `:715` | Re-conceptualized as elaborator (§ 5.3); HAMT root pointer-share is the canonical mechanism. **Not legacy.** |

**Phase 6 unambiguous deletion checklist**: items in B above. Each deletion is a separate commit with the citation table updated to "DELETED in commit `<hash>`." After Phase 6, `grep -rn 'iter-block-decl\|run-stratified-resolution!\|current-in-stratified-resolution?'` should return only retirement-context references in this doc and in tombstone comments at deletion sites.

---

## 10. Open questions

| # | Question | Resolution |
|---|---|---|
| Q1 | When `cell_alloc` is called mid-fire-round, what cell-id namespace does it use? | Same as the parent fire's namespace (matches Racket's `current-cell-id-namespace`). Phase 2. |
| Q2 | Order of topology-mutation application: FIFO or LIFO? | FIFO (insertion order). Matches Racket. Phase 2. |
| Q3 | Per-cell fuel cost for `cell_reset` vs `cell_write`? | Same (1 fuel each). Phase 1. |
| Q4 | HAMT GC | Inherited from `2026-05-02_HAMT_ZIG_TRACK6.md` § 2 — leak; address in separate Track 6 GC track. |
| Q5 | Multiple HAMT roots for ATMS branches (per-branch divergence) vs single global HAMT with tagged-value? | Single global HAMT with `tagged-cell-value` merge. Matches existing Racket model. Per-branch HAMT roots are a future optimization if tagged-value compaction becomes a bottleneck. |
| Q6 | Trap recovery: what happens if a propagator traps mid-fire? | `run_to_quiescence` returns `trap`; caller decides. (`@main` may abort; a parent stratum-handler propagator may catch and convert to a `cell_write` to a "contradiction" cell.) |
| Q7 | Self-hosting: how does the bootstrap kernel implement `cell_reset` + topology deferral + scope APIs? | Bootstrap Racket runtime already has all three (`net-cell-reset` + BSP-LE 2B mechanism + `fork-prop-network` + nested `run-to-quiescence`); native Zig kernel implements them in Phase 1; self-hosted Prologos runtime is downstream. |
| Q8 | Cell-id allocation across scope boundaries: when a child scope calls `cell_alloc`, does the new cell get a global cell-id (visible to parent after `scope_exit`) or a scope-local cell-id (invisible to parent)? | **Global cell-ids; scope-local visibility via HAMT root.** Cell-ids are globally allocated (single counter); the cell exists in `scope`'s HAMT root only; reading the cell from a parent scope returns "not present" (or default init value) until/unless the parent explicitly inherits the scope's HAMT root. Matches Racket's `fork-prop-network` semantics: cells exist in the fork's CHAMP; the parent doesn't see them after the fork is dropped. |
| Q9 | Trap behavior across scope boundaries: if a propagator traps inside `scope_run`, what happens? | `scope_run` returns `RunResult.trap`; the calling fire-fn (in the parent scope) decides — propagate via `cell_write` to a contradiction cell, retry with different parameters, or trap upward. Same model as Racket's exception-bubbling-through-fork pattern. § 15.15. |
| Q10 | Default `parent_fuel_charge` for `scope_enter`? | **10 fuel units** (constant). Small fixed cost so creating many scopes (e.g., per-NAF-aid in `process-naf-request`) is bounded but not free. Phase 1 default; revisit if profiling shows scope-creation pressure. § 15.16. |

Many open questions from rev 1 (per-PU arena strategy, worldview-bit allocator, PU lifecycle re-entry, stratum dispatch order, compound PU cells, snapshot semantics across PUs) **partially evaporate** in this rev: PU-primitive concerns vanish; the few that remain (like scope cell-id semantics, trap propagation across scopes) are answered above.

---

## 11. Options for review

This is the section the user asked for. Three options after the dissolve insight:

### Option A — **Status quo**: keep PUs at Racket level; no kernel changes

- No kernel changes.
- Sprint G stays as LLVM-loop hack (works for tail-rec).
- ATMS branches stay as `fork-prop-network` + box save/restore at Racket level.
- Native runtime never gets dynamic topology mutation — no path to native NAF / ATMS / iteration.

**Cost**: 0 days. **Unlocks**: nothing for native. **Tech debt**: high.

### Option B — **Kernel-PU primitive** (rev 1 of this doc; now Appendix A)

- Add ~12 functions to Zig kernel (`prologos_pu_*` family + stratum-handler register).
- Add 5 new IR node kinds.
- Per-PU arenas, strata stack, lifecycle, entry/exit/halt tables in the kernel.

**Cost**: ~15-25 days. **Unlocks**: full migration table. **Limits**: largest kernel surface; ports concepts that don't need kernel-level enforcement.

**Why rejected**: the dissolve audit (§ 2) shows almost everything works as compiler abstractions over substrate; kernel-level PU primitives are over-engineered. See § 12.4 and Appendix A.

### Option C — **Dissolved + minimal scope (this rev 2.1, recommended)**

- Add 5 functions to Zig kernel: `cell_reset` + 4 scope APIs (`scope_enter` / `scope_run` / `scope_read` / `scope_exit`).
- Port topology-mutation deferral + 2-tier outer loop from Racket to Zig.
- Refactor flat arrays to HAMT-rooted (Phase 2; uses `prologos-hamt.zig`); scope HAMT roots reuse the same machinery.
- NO new IR node kinds; `write-decl` gains a mode tag; scope APIs called from inside fire-fn bodies (no IR change).
- PReduce / `lower-tail-rec` / Racket runtime do the elaboration; handler fire-fns call scope APIs for per-invocation isolation.

**Cost**: ~12-17 days (kernel ~7, IR ~1, lowering ~3, Sprint G migration ~2, NAF migration ~3, regression suite ~2).
**Unlocks**: every entry in § 9's migration table including NAF/ATMS with proper per-invocation fuel isolation matching Racket semantics. Self-hosted compiler can express each pass as compositional topology with scoped sub-runs where runtime isolation matters.
**Limits**: PU abstraction lives in compiler; per-invocation runtime isolation lives in kernel as scope (the irreducible kernel concession identified in § 2.5). Slightly more kernel surface than rev-2's "6 functions" but still 6 fewer functions than rev 1.

### Option D — **Hybrid**: dissolve strata, keep full kernel-PU lifecycle

- Strata as topology (per Option C) — no kernel stratum API.
- BUT keep rev-1-style full PU lifecycle (`pu_alloc` / `pu_run` / `pu_dealloc` + entry/exit/halt tables + per-PU strata stack) for runtime PU cases.

**Cost**: ~15-18 days. **Unlocks**: same as C, but with extra kernel surface for PU lifecycle that's not justified once scope APIs (Option C) cover the irreducible runtime concern.
**Limits**: half-and-half; once scope APIs handle fuel isolation + nested run, the rest of rev-1 PU lifecycle is gold-plating. Per-PU strata stack replaceable by topology; entry/exit/halt by propagator wiring.

**Why secondary to C**: scope APIs cover the irreducible runtime concern (per-PU fuel + isolated nested run); the rest of rev-1's PU primitive doesn't add capability over compiler-emitted topology.

### Recommendation summary

| Option | Kernel API count | Cost | Unlocks Sprint G | Unlocks runtime ATMS w/ proper isolation | Replaces save/restore boxes | Self-hosting alignment |
|---|---|---|---|---|---|---|
| A (status quo) | 5 (existing) | 0d | ✗ | ✗ | ✗ | ✗ |
| B (rev 1; rejected) | ~12 | ~20d | ✓ | ✓ | ✓ | ✓ but over-engineered |
| **C (rev 2.1)** | **10** | ~14d | ✓ | ✓ | ✓ | ✓ minimal — 6 fewer APIs than B |
| D (hybrid) | ~14 | ~17d | ✓ | ✓ | ✓ | ✓ but redundant w/ scope |

Recommendation: **Option C (rev 2.1)**. Kernel stays small (10 functions, 5 added); scope APIs are the minimum concession to per-PU fuel isolation; aligns with "kernel stays simple, compose above" as far as is honestly possible without losing NAF/ATMS semantics.

---

## 12. Adversarial framing (Vision Alignment Gate)

Per `.claude/rules/workflow.md` § "VAG / principles gate / mantra audit MUST be ADVERSARIAL." Two-column format (catalogue → adversarial challenge), grouped by the three workflow-rule axes: **on-network**, **complete**, **vision-advancing**.

### 12.1 On-network?

| Catalogue (what we claim) | Challenge: could this be MORE on-network? |
|---|---|
| ✓ All PU/stratum abstractions live above the kernel (§ 5) | The compiler emits topology that encodes them. Is the topology itself on-network? — *Yes; cells, propagators, dep-edges, write-decls are all on-network. The TOPOLOGY is the program; the kernel runs it.* |
| ✓ `cell_reset` is a new kernel primitive | Is `cell_reset` itself on-network? — *Partially. The OPERATION is a kernel API call (off-network from the propagator's view). But the EFFECT (cell value change) is on-network and observable. Same shape as today's Racket `net-cell-reset`. Catalogued as known minor off-network surface.* |
| ✓ Scope APIs are new kernel primitives (§ 5.9) | Are scope APIs on-network? — *Partially. The OPERATIONS (`scope_enter` / `scope_run` / `scope_read` / `scope_exit`) are kernel API calls. The EFFECT (per-scope HAMT, per-scope fuel, per-scope worklist) is observable in cell values. Scope is a runtime mechanism that mirrors Racket's `fork-prop-network` + nested `run-to-quiescence` pattern (`propagator.rkt:715-719` + `relations.rkt:128-172`) — same off-network shape as Racket has today. Catalogued as known off-network surface; could be made more on-network by exposing scope-stack-state as a cell, but no use case demands this yet.* |
| ✓ Worldview tagging is on-network via `tagged-cell-value` | Is the worldview-bitmask parameter on-network? — *Today: no — `current-worldview-bitmask` is a Racket parameter. Future: yes — when worldviews become first-class cells (PM Track 12 / NTT), the parameter retires.* |
| ✓ Topology mutation deferral is on-network | The pending-mutation list is an internal kernel data structure. Is it observable? — *Today: no, kernel-internal. Could be exposed as a "pending-mutations cell" if a use case demands. Catalogue as known scaffolding.* |
| ✓ Stratification mantra ("All-at-once, all in parallel, structurally emergent information flow ON-NETWORK") | Iteration's tick-cell counter — is that on-network? — *Yes, it's a cell in the network. Compiler-emitted, but no different from any other cell.* |

**Verdict**: 5 of 5 mantra words pass cleanly. The on-network discipline holds at the substrate level (cells, propagators, topology); the off-network surfaces (kernel API calls for `cell_reset` and the 4 scope APIs, worldview parameter, pending-mutation list) are catalogued as deferral candidates with named retirement plans where applicable.

**Compared to rev 1**: the dissolved + minimal-scope architecture has a *smaller* off-network surface than rev 1's kernel-PU primitive. Rev 1 had PU handles (off-network ids), entry/exit tables (off-network kernel state), stratum-handler dispatch table (off-network registry). Rev 2.1 has only `cell_reset`, the 4 scope APIs (vs rev 1's 12 PU APIs), the worldview parameter, and the pending-mutation list. Net: ~6 fewer off-network kernel surfaces than rev 1.

### 12.2 Complete?

| Catalogue | Challenge: could this be MORE complete? |
|---|---|
| ✓ Each phase in § 14 has a deliverable + test gate | Phase 7 (PReduce walkthrough) is documentation, not code. Does that complete the consumer-validation claim? — *It validates the compositionality claim (substrate suffices for PReduce's needs); it doesn't implement PReduce.* |
| ✓ Kernel API specified down to Zig signatures (§ 6) | What about the FIRE-FN-TAG-REGISTRY pattern for handler dispatch? — *Reused from existing Low-PNet → LLVM emitter (`low-pnet-to-llvm.rkt:43`). § 15.3.* |
| ✓ Worldview / ATMS works without kernel changes | Does it? — *Yes; `tagged-cell-value` merge fn is already in `propagator.rkt:1156-1176`. Phase 2's HAMT-rooted refactor preserves it. Verified by the existing speculation-bridge tests (`tests/test-speculation-bridge.rkt`).* |
| ✓ Iteration pattern (§ 5.5) is concrete | But: it requires the compiler to emit a tick cell. Is this brittle? — *Concern: if the compiler forgets the tick, iteration doesn't re-fire and silently terminates after one round. Mitigation: `lower-tail-rec`'s test gate verifies tail-rec acceptance examples produce correct N-step iteration.* |
| ✗ NO microbench-claim-verification phase initially | Sprint G's design didn't have one either. Phase 5 microbench gate (§ 14) measures tail-rec via dissolved pattern vs Sprint G's hypothetical `@main`-loop baseline. |

### 12.3 Vision-advancing?

| Catalogue | Challenge: could it be MORE vision-advancing? |
|---|---|
| ✓ Removes a known CALM violation (same as Sprint G's claim) | Already done by Sprint G's design framing; this doc inherits the win. |
| ✓ Establishes the kernel substrate that future tracks consume | Sprint G punts that to "Track 6 Path B"; this doc IS that path. |
| ✓ Aligns native runtime with Racket-side stratification discipline | Racket has had `register-stratum-handler!` for two months; native catching up via dissolved primitives (cell_reset + topology deferral) closes the gap with minimal API surface. |
| ✓ Composes with future schedulers (multi-thread, seminaive) | HAMT-rooted cells are NUMA-friendly; topology-mutation deferral is parallelism-ready. |
| ✓ Pragmatic decoration audit | Is any part of this rationalizing? — *§ 11 Option A explicitly identifies status quo as tech debt. § 9 commits to a full migration plan. § 10 Q4 names HAMT GC as v1 scaffolding with named v2 retirement (Track 6 GC). Worldview integration: zero additional work needed (already on-network).* |
| ✓ Smaller kernel than rev 1 | Rev 1 was ~12 functions + 5 IR kinds; rev 2.1 is 10 functions + 0 IR kinds + 1 tag field. Smaller surface = less to maintain, less to break. (Rev 2's "6 functions" claim was incomplete; § 2.5 documents the per-scope-fuel finding that necessitated 4 additional scope APIs.) |
| Could it be MORE vision-advancing? | Yes — the dissolved architecture means future PReduce / NTT work can introduce new abstractions (transactions, temporal modalities, capabilities-as-strata) without touching the kernel. The kernel stays stable; abstractions compose above. |

### 12.4 Why rev 1 was (mostly) rejected — and what survived as scope (preserved for posterity)

Rev 1's kernel-PU primitive design over-fit to a real problem (eight ad hoc patterns) by adding the wrong fix (kernel-level PU type with full lifecycle). The right fix was: PUs are real abstractions, but they live mostly at the COMPILER layer; the kernel needs only the substrate they elaborate to PLUS a minimal scope mechanism for runtime fuel isolation (the one rev-1 capability that survived the dissolve audit).

Specific rev-1 designs that don't survive:
- Per-PU arenas — replaced by single global HAMT + per-scope HAMT root pointer-share (HAMT CoW gives O(1) "fork" without kernel "PU" type)
- `prologos_pu_alloc` / `_dealloc` (lifecycle as object) — replaced by `scope_enter` / `scope_exit` (lifecycle as stack-discipline runtime mechanism, not first-class object)
- Per-PU strata stack — replaced by topology (handler-N's input is handler-(N-1)'s output cell)
- Stratum-handler register API — replaced by "handlers ARE propagators" with by-convention `cell_reset` permission
- Entry/exit/halt declarative tables — replaced by entry/exit/halt PROPAGATORS (compiler-emitted) and handler-fire-fn-driven scope wrap
- Worldview-bit allocator API — replaced by worldview-tagging at the merge-function layer (already on-network)
- 5 new IR node kinds — replaced by zero new node kinds + one tag field on `write-decl`

Specific rev-1 designs that survived (in different form):
- `prologos_pu_run` (per-PU bounded execution) — survives as `scope_run(scope, fuel)`. Same fuel-bounded nested run; simpler API (no PU lifecycle, just a stack-discipline scope handle).
- Per-PU fuel attribution — survives as per-scope fuel counter. The kernel does need to know which scope a fire belongs to; fuel attribution is the irreducible reason.

The architectural lesson: when ad hoc patterns proliferate, the right question is "what's the minimum substrate they all reduce to?" not "what's the minimum primitive that subsumes them?" The follow-up question is: "of the things that don't reduce to substrate, what's the smallest API that captures them?" For PUs, that smallest API is the 4 scope functions — much smaller than rev-1's full PU primitive, but not zero.

---

## 13. Decision points to resolve before implementation begins

The user reviews this doc and answers:

1. **Which option (A-D)?** — determines the implementation track scope. Recommended C.
2. **Sprint G interaction**: do we (a) finish Sprint G's LLVM-loop hack as committed scaffolding and migrate to substrate-pattern later, or (b) pause Sprint G and land the substrate primitive first, with iteration as the first migrated case? Recommended (b) — substrate-pattern is smaller than Sprint G's continuation.
3. **Track sequencing**: where does this land relative to other in-flight tracks (PPN 4C, the SH series N0/N1/N2)?
4. **Effort budget**: 10 vs 15 days — which is acceptable?
5. ~~Bootstrap-vs-Zig~~ — **resolved**: Racket interpreter already has the substrate (§ 5.3 + § 15.6); native Zig kernel implements in Phase 1.

When these are answered, the next step is beginning Phase 1 of the staged plan in § 14.

---

## 14. Phased implementation plan (concrete deliverables + test gates)

Once § 13 is resolved, work proceeds in nine phases. Phase 0 is this design proposal; subsequent phases are sized to land as individual review-able commits with their own test gates. Total estimated scope is consistent with § 11 Option C (~10-15 days). Each phase names the file(s) touched, the LOC budget, the deliverable, and the gate that lets us call the phase done.

| Phase | What | Files | Scope | Deliverable | Test gate |
|---|---|---|---|---|---|
| **0** | THIS DOC (rev 2) | `docs/tracking/2026-05-02_KERNEL_POCKET_UNIVERSES.md` | — | Stage-3 design proposal with dissolved architecture, Options A-D, decision points | User review and approval of § 13 decision points |
| **1** | Native kernel — `cell_reset` + 2-tier outer loop + topology-mutation deferral + min-merge i64 + **scope APIs** | `runtime/prologos-runtime.zig`, `runtime/test-substrate.c` (new) | ~350 LOC Zig + ~150 LOC C test | (a) `prologos_cell_reset` API (matches Racket `net-cell-reset`: replace, no merge, no enqueue). (b) 2-tier outer loop in `prologos_run_to_quiescence` (port `propagator.rkt:2274-2280` pattern). (c) Topology-mutation deferral: `cell_alloc` / `prop_install` calls during fire are queued, applied between rounds (port BSP-LE 2B mechanism from Racket). (d) `min`-merge i64 domain alongside existing LWW i64 — enables non-vacuous `cell_write` vs `cell_reset` distinguishability test. (e) **Scope APIs (`scope_enter` / `scope_run` / `scope_read` / `scope_exit`; § 5.9, § 6)** — kernel-tracked scope stack; per-scope fuel counter; per-scope worklist; per-scope HAMT root (interim: a derived flat-array snapshot until Phase 2's HAMT lands; Phase 2 swaps in HAMT root pointer-share for true O(1)). Mid-fire `cell_alloc`/`prop_install` during `scope_run` go to the active scope. | New C smoke test: (i) deferred-alloc test — propagator calls `cell_alloc` mid-fire; new cell appears between rounds; subsequent propagators reference it. (ii) merge-vs-reset test under min-merge: `cell_write(c, 5); cell_write(c, 3) → c=3` (commutative); `cell_reset(c, 7) → c=7` (replace). (iii) 2-tier ordering test: a topology-mutation propagator and a value-tier propagator both fire; topology applies first. (iv) **scope-fuel-isolation test**: parent runs with fuel=100, calls `scope_enter`, runs `scope_run(fuel=1000)` whose body diverges (propagator that re-enqueues itself); scope returns `fuel_exhausted` after 1000; parent has `100 - 10 = 90` fuel remaining (only the `parent_fuel_charge`); parent's BSP outer loop continues. (v) **scope-write-isolation test**: parent has cell C with value 5; handler enters scope, writes via `cell_write(C, 100)` inside scope; scope_exit; parent reads C and gets 5 (scope's writes did not propagate). (vi) **scope-explicit-publish test**: same as (v) but handler calls `result = scope_read(scope, C)` and then `cell_write(parent-result-cell, result)` before `scope_exit`; parent sees the published value. **All currently-passing acceptance examples pass unchanged.** |
| **2** | Native kernel — HAMT-rooted cell storage (also upgrades scope snapshot from Phase 1's interim mechanism to true O(1) HAMT pointer-share) | `runtime/prologos-runtime.zig`, `runtime/test-substrate.c` | ~300 LOC Zig refactor | Refactor flat `cells[MAX_CELLS]` → `cells: prologos_hamt_t` (single global HAMT root). Replace flat snapshot copy with HAMT root pointer copy (O(1) snapshot). Drop `MAX_CELLS` cap. **Scope snapshots upgrade**: Phase 1's interim flat-array snapshot in `scope_enter` becomes HAMT root pointer copy (O(1)); `scope_run`'s writes go to scope's HAMT via path-copy CoW; `scope_exit` releases the scope's HAMT root. Same for `props` if natural; `cell_subs` may stay flat for now (separate optimization). | C test: (i) HAMT-CoW persistence (mirrors `prologos-hamt.zig` test "persistence: old root unaffected by insert into derived root", lines 380-392). (ii) **scope-snapshot-O(1) microbench**: `scope_enter` from a 100K-cell parent completes in O(1) — previously O(100K) under the Phase-1 interim snapshot mechanism. **Existing acceptance examples still pass after the flat-array refactor** — this is the largest single regression risk. |
| **3** | Low-PNet IR — write-decl mode tag | `racket/prologos/low-pnet-ir.rkt`, `racket/prologos/tests/test-low-pnet-ir.rkt` | ~30 LOC Racket | Add a write-mode tag to `write-decl` (`'merge` default for backward compat; `'reset` for non-monotone). Update `parse-low-pnet`, `pp-low-pnet`, `validate-low-pnet`. Bump LOW_PNET_FORMAT_VERSION 1.0 → 1.1 and add validator rule V12. **NO new node kinds.** | Round-trip pp ↔ parse for write-decl with both modes; validator accepts both; `'merge` is default when mode tag absent (backward-compat: V1.0 IR re-parses unchanged). **All 22 pre-existing IR tests pass unchanged + 10 new V1.1 mode tests = 32 total.** |
| **4** | AST → Low-PNet — `lower-tail-rec` rewrite + Low-PNet → prop-network adapter | `racket/prologos/ast-to-low-pnet.rkt`, `racket/prologos/low-pnet-to-prop-network.rkt` (new), `racket/prologos/network-to-low-pnet.rkt` (comment update), tests | ~150 LOC + ~200 LOC adapter | (a) Refactor `lower-tail-rec` (line 613) to emit the substrate iteration pattern (§ 5.5): cell-decl + propagator-decl + dep-decl + write-decl with `:merge` (tick) + `:reset` (state) modes. NO new IR kinds. Sprint G depth-alignment + bridge-cell scaffolding becomes obsolete; quarantine. (b) Ship `low-pnet-to-prop-network` (§ 15.6) — walks Low-PNet IR and materializes a runnable `prop-network` via existing `propagator.rkt` primitives. Update the rejected-direction comment in `network-to-low-pnet.rkt:33-35`. | Tail-rec acceptance examples produce a propagator-decl with `:reset` write-decls (verify via `pp-low-pnet`). Round-trip gate (no LLVM in the loop): `(run-prop-network (low-pnet-to-prop-network (ast-to-low-pnet typed-ast)))` produces the same final cell values as the existing AST-direct interpreter path for every tail-rec / NAF / topology acceptance example. |
| **5** | Low-PNet → LLVM — write-mode dispatch + Category-C migrations | `racket/prologos/low-pnet-to-llvm.rkt`, `racket/prologos/metavar-store.rkt`, `racket/prologos/relations.rkt`, tests | ~100 LOC Racket emission + ~150 LOC Category-C migrations | (a) **Emission**: `lower-low-pnet-to-llvm` dispatches on write-decl mode tag — `:merge` → `prologos_cell_write`, `:reset` → `prologos_cell_reset`. Handler fire-fns that need scope isolation emit calls to `prologos_scope_enter` / `_run` / `_read` / `_exit` (no IR change; just kernel calls inside fire-fn body). NO PU-specific emission paths. (b) **Category-C migration**: re-express `run-stratified-resolution-pure` (`metavar-store.rkt:2131`) as registered stratum-handler propagators (S(-1) retraction, S1/L1 readiness, S2 resolution). Re-express `process-naf-request` (`relations.rkt:115-245`) using the scope APIs per § 5.9's worked example: handler fire-fn calls `scope_enter` per NAF aid, installs inner goal on scope, `scope_run` with fresh fuel, `scope_read` to extract result, `scope_exit`. The Racket `fork-prop-network` + nested `run-to-quiescence` becomes the kernel scope APIs one-to-one. | All 34 acceptance examples lower and run; Pell N=5 = 29; benchmark suite green. **Microbench gate**: tail-rec via dissolved pattern within ±20% of Sprint G's hypothetical `@main`-loop baseline (Phase 8 PIR). **NAF isolation gate**: a NAF inner goal that diverges (artificial test) returns `fuel_exhausted` from `scope_run` after the configured 1M fuel; parent computation continues with parent fuel intact (within `parent_fuel_charge` of the pre-handler value). **Category-C migration gate**: existing `run-stratified-resolution-pure` callers and existing NAF use sites continue to pass with no behavioral diff. |
| **6** | Quarantine — retire all Category-B legacy ordering scaffolding (§ 9.1) | `racket/prologos/low-pnet-ir.rkt`, `racket/prologos/ast-to-low-pnet.rkt`, `racket/prologos/low-pnet-to-llvm.rkt`, `racket/prologos/metavar-store.rkt` | Net deletions | Delete the full Category-B set per § 9.1's inventory: (a) `iter-block-decl` IR node + parse + pp + validate; (b) Sprint G's `@main`-loop emission paths in `low-pnet-to-llvm.rkt`; (c) depth-alignment + bridge-cell helpers in `ast-to-low-pnet.rkt` no longer reachable from rewritten `lower-tail-rec`; (d) `run-stratified-resolution!` and `current-in-stratified-resolution?`. Bump Low-PNet IR version. Each deletion is a separate commit with a tombstone comment. | Full suite green; § 9.1 grep-check passes: `grep -rn 'iter-block-decl\|run-stratified-resolution!\|current-in-stratified-resolution?' racket/ runtime/ docs/tracking/2026-05*` returns hits ONLY in retirement-context comments. |
| **7** | PReduce design walkthrough — consumer validation | `docs/tracking/2026-MM-DD_PREDUCE_USES_DISSOLVED_SUBSTRATE.md` (new) | Documentation only | 1-2 page note showing PReduce's lowering uses substrate primitives (cell_reset + topology mutation + tagged-value worldviews) **without further kernel work**. Walks through one PReduce reduction case as substrate-level cells/propagators. Confirms the substrate is sufficient for PReduce's compositional needs. | Documentation only — no code. PReduce track owners can read this and confirm the kernel substrate is sufficient. *Validates the design claim "substrate suffices" without committing to ship PReduce in this track.* |
| **8** | Benchmark + PIR | `racket/prologos/tests/bench-ab.rkt`, `docs/tracking/2026-MM-DD_KERNEL_SUBSTRATE_PIR.md` (new) | Measurements + PIR | Run `bench-ab.rkt` (Pell, fib, sum-to) comparing to F.5/F.6 baseline AND to a Sprint-G-`@main`-loop hypothetical (one-off measurement). Write Post-Implementation Review per the 16-question template. Capture answers to § 12 VAG challenges. | PIR completes; comparison data captured; PIR's "what scaffolding did we ship?" answer matches § 12.1 (kernel API call surface for `cell_reset`, worldview parameter, pending-mutation list) — no surprise off-network surfaces. |
| **9** | Commit + push + roadmap update | `docs/tracking/MASTER_ROADMAP.org`, `docs/tracking/2026-05-02_SH_SERIES_ALIGNMENT.md`, this doc | Documentation | Update Master Roadmap with Track 4/6 partial-completion entry. Update SH Series Alignment doc. Mark this doc's status banner "Implemented" with commit-hash links per phase. | Branch ready for review / merge; downstream tracks (PReduce, ATMS migration, future NTT) cite the kernel substrate as a stable surface. |

**Critical-path observations**:

1. **Phase 1 + 2 are the only ones that block downstream work.** Once kernel substrate (incl. scope APIs) ships, IR / lowering work parallelizes with consumer migrations.
2. **Phase 4's mid-phase IR/LLVM gap is tolerated.** Same shape as Sprint G's Phase 2 ↔ Phase 3 gap.
3. **Phase 6 is a deletion phase** — the workflow rule's "named retirement plan" being executed across the full Category-B set.
4. **Phase 7 (PReduce walkthrough) is the design's compositionality check.** If PReduce needs even one more kernel API beyond Phase 1's substrate (cells / propagators / `cell_reset` / scope), the design has not earned the "substrate suffices" claim, and we revisit before Phase 8.
5. **Total scope is smaller than rev 1, slightly larger than rev 2** (~12-17 days vs rev 1's ~15-25 days vs rev 2's claimed ~10-15 days). The 4 scope APIs add ~150 LOC + ~70 LOC of test to Phase 1 over rev 2; everything else is unchanged.
6. **Scope APIs are deliberately Phase-1, not deferred.** Without them, NAF and ATMS migration in Phase 5 cannot be honestly tested — a divergent inner goal would consume parent global fuel and break parent's computation. Shipping scope APIs in Phase 1 means the NAF migration in Phase 5 can be validated against per-invocation fuel isolation (the canonical Racket semantic).

### 14.1 Day-by-day sequencing (single engineer; ~14 days)

Concrete decomposition of the phase plan above into per-day deliverables. Each day ends with a commit + tests-green gate.

| Day | Phase | Deliverable | Files | Gate |
|---|---|---|---|---|
| **1** | 1a | `cell_reset` API + `min`-merge i64 domain + dispatch | `runtime/prologos-runtime.zig`, `runtime/test-substrate.c` (new) | merge-vs-reset distinguishability test passes (§ 15.9) |
| **2** | 1b | 2-tier outer loop in `prologos_run_to_quiescence` + topology-mutation deferral (queue + between-round application) | `runtime/prologos-runtime.zig` | deferred-alloc + 2-tier ordering tests pass (§ 14 Phase 1 i, iii) |
| **3** | 1c | Scope APIs (`scope_enter` / `scope_run` / `scope_read` / `scope_exit`) with **interim flat-array snapshot** (Phase 2 will swap in HAMT) | `runtime/prologos-runtime.zig` | scope stack-discipline traps work (§ 15.14) |
| **4** | 1d | Scope test suite: fuel-isolation, write-isolation, explicit-publish, trap-propagation, nested scopes | `runtime/test-substrate.c` | All 6 scope tests + acceptance regression green |
| **5** | 2a | HAMT migration: `cells[MAX_CELLS]` → `prologos_hamt_t` (single global root); existing tests stay green | `runtime/prologos-runtime.zig` | acceptance suite passes |
| **6** | 2b | Scope snapshots upgrade: interim flat-array → HAMT root pointer-share; `scope_run` writes go to scope's HAMT via CoW | `runtime/prologos-runtime.zig` | scope-snapshot-O(1) microbench (§ 14 Phase 2 ii) |
| **7** | 2c | Regression sweep + 100K-cell `scope_enter` benchmark; HAMT GC leak documented (Track 6 follow-up) | tests | All acceptance + microbenches pass |
| **8** | 3 | Low-PNet IR `write-decl` mode tag (`'merge` default; `'reset`); parse / pp / validate; bump LOW_PNET_FORMAT_VERSION 1.0→1.1 + add V12 validator rule. `low-pnet-to-llvm` rejects `'reset` writes (delegated to Day 11 emission). | `racket/prologos/low-pnet-ir.rkt`, `racket/prologos/low-pnet-to-llvm.rkt`, `tests/test-low-pnet-ir.rkt` | All 22 pre-existing IR tests pass + 10 new V1.1 tests = 32; LLVM tests still pass (mode-merge default); round-trip works for both modes |
| **9** | 4a | `lower-tail-rec` rewrite: emit substrate iteration pattern (state cells + iter-step propagator + tick + halt-guard) instead of `iter-block-decl` | `racket/prologos/ast-to-low-pnet.rkt` | Tail-rec acceptance examples produce `propagator-decl` + mode-tagged `write-decl`s (verify via `pp-low-pnet`) |
| **10** | 4b | New `low-pnet-to-prop-network` adapter (~200 LOC): walks Low-PNet IR, materializes runnable `prop-network` via `propagator.rkt` primitives | `racket/prologos/low-pnet-to-prop-network.rkt` (new) | Round-trip gate: `(run-prop-network (low-pnet-to-prop-network (ast-to-low-pnet typed-ast)))` matches AST-direct interpreter for tail-rec / NAF / topology examples — **NO LLVM in the loop** |
| **11** | 5a | LLVM emission: `lower-low-pnet-to-llvm` dispatches on write-decl mode; emits `prologos_cell_write` vs `prologos_cell_reset`; emits scope-API calls inside fire-fn bodies | `racket/prologos/low-pnet-to-llvm.rkt` | Pell N=5 = 29 via dissolved pattern; 34 acceptance examples lower and run |
| **12** | 5b | Category-C migrations: `process-naf-request` → scope APIs (per § 5.9 worked example); `run-stratified-resolution-pure` → registered stratum-handler propagators | `racket/prologos/relations.rkt`, `racket/prologos/metavar-store.rkt` | NAF isolation gate: divergent inner goal returns `fuel_exhausted`; parent fuel intact except for `parent_fuel_charge` |
| **13** | 6 | Category-B retirements (one commit per item with tombstone comments): `iter-block-decl`, Sprint-G `@main` paths, Sprint-G depth-alignment scaffolding, `run-stratified-resolution!`, `current-in-stratified-resolution?` | as listed § 9.1 B | grep-check passes (§ 9.1 final paragraph); full suite green |
| **14** | 7+8+9 | PReduce walkthrough doc (1-2 pages, § 14 Phase 7); `bench-ab.rkt` run + PIR; Master Roadmap + SH Series Alignment updates; commit + push | several docs | PIR completes; downstream tracks can cite this kernel surface as stable |

**Critical path**:
```
Phase 1 (kernel) ─┬─→ Phase 2 (HAMT refactor; scope HAMT roots use Phase 2 substrate)
                  └─→ Phase 3 (IR mode tag) ─→ Phase 4 (lowering) ─→ Phase 5 (LLVM + Category-C migrations)
                                                                                  │
                                                                       Phase 6 (Category-B retirements)
                                                                                  │
                                                                       Phase 8 (benchmarks + PIR) ─→ Phase 9 (commit + roadmap)
```
Phase 7 (PReduce walkthrough doc) is non-blocking; can run any time after Phase 0.

**Parallelization opportunities** (with two engineers, can drop ~4 days from critical path):
- Phase 1 (Days 1-4 in Zig) ‖ Phase 3 (Day 8 in Racket IR) — different files, different languages
- Phase 7 (PReduce walkthrough doc, ~half-day) — drafted any time after Phase 0
- Phase 4a (`lower-tail-rec` rewrite) — can start as soon as Phase 3's IR contract is locked, in parallel with Phase 1 in Zig

**Sprint G interaction (§ 13 #2 — recommended Option (b)): pause Sprint G; this track absorbs the iteration case as Phase 4 (Day 9) of the new sequence**. Sprint G's Phase 1 (`iter-block-decl` IR node) is sunk cost (~1 day); Sprint G's Phases 2-6 (~5-7 days) would all be wasted because the `@main`-loop output is the off-network surface this track retires.

---

## 15. Implementation review notes (gotchas surfaced during the design walk-through)

These are concerns the architectural sections leave under-specified but which will block Phase 1-2 progress if not pinned down before code starts.

### 15.1 Two-mode cell writes (matches Racket); ship min-merge i64 in Phase 1

**Decision (resolved)**: kernel adopts Racket's two-mode model — `cell_write` (merge + enqueue dependents) and `cell_reset` (replace, no merge, no enqueue dependents). Privilege enforcement is by-convention, not runtime-trapped (matches Racket; § 5.5).

**Why min-merge i64 must ship in Phase 1**: today's Zig kernel is i64 LWW for every cell. Under LWW, `cell_write` and `cell_reset` are observationally identical (both replace; both fire dependents because LWW is technically a merge that happens to discard the old value). Phase 1's deliverable is updated to include `min`-merge i64 alongside the existing LWW i64. With min-merge: `cell_write(c, 5)` then `cell_write(c, 3)` → `c = 3` (commutative); `cell_reset(c, 5)` from a propagator → `c = 5` regardless. Cost: ~50 LOC for merge-fn dispatch + one new domain registration. Folded into Phase 1's ~200 LOC budget.

### 15.2 Iteration pattern's tick cell — compiler responsibility

The iteration pattern (§ 5.5) requires the compiler to emit a `tick` cell (monotone counter) and a `cell_write(tick, +1)` call inside the iteration propagator's body. **Without the tick write, iteration silently terminates after one round** (because `cell_reset` doesn't enqueue dependents).

This is a compile-time correctness obligation on `lower-tail-rec`. The Phase 4 test gate verifies tail-rec acceptance examples produce N-step iteration (not 1-step). If a future iteration-emitting compiler pass forgets the tick, the resulting program will not iterate.

**Mitigation**: a Phase 4 helper `emit-iteration-pattern` consolidates the pattern; future emitters use it; the helper's tests verify the tick cell is always emitted.

### 15.3 Handler dispatch reuses existing `FIRE-FN-TAG-REGISTRY` pattern

`racket/prologos/low-pnet-to-llvm.rkt:43` already provides `FIRE-FN-TAG-REGISTRY` for per-propagator fire-fn dispatch. Stratum-handler propagators are just propagators — same dispatch mechanism, no new registry needed. ~0 LOC delta.

### 15.4 Topology-mutation deferral semantics — port faithfully from Racket

The BSP-LE 2B mechanism in Racket has subtle semantics that Phase 1 must port exactly:

- `cell_alloc` mid-fire returns a new cell-id IMMEDIATELY (so the propagator can use it). The cell's value is the init value; reads succeed; writes are buffered and applied at end-of-round (same as any other write).
- `prop_install` mid-fire returns a new prop-id IMMEDIATELY. The propagator is registered but **not on the worklist** for the current round. Topology-tier processing schedules it for the next round.
- `cell_alloc` from a value-tier propagator: cell appears at start of next round (between-round application).
- `cell_alloc` from a topology-tier handler: cell appears in the same tier's continuation (handlers fire serially within a tier).

These are spelled out in `racket/prologos/propagator.rkt:17-22, 1461-1473`. Phase 1's Zig port must match.

### 15.5 `cell_reset` interaction with HAMT-CoW (Phase 2)

When `cell_reset(c, v)` is called and `c` lives in a HAMT, the kernel performs a path-copy CoW insert (just like `cell_write`). The "no enqueue" semantic only affects the worklist; it doesn't change the HAMT update mechanics. Phase 2's HAMT refactor preserves both modes' semantics.

### 15.6 The Racket interpreter already has the substrate; only kernel needs to catch up

A previous draft claimed "Racket-side mirror is a structural prerequisite." **That was wrong** — the Racket interpreter has working PU + stratification today (5 production handlers; `make-branch-pu` test suite; `register-stratum-handler!` 5+ caller sites). The actual gap is the Zig kernel doesn't have `cell_reset` or topology-mutation deferral.

`propagator.rkt`'s existing primitives stay unchanged in API. Their *role* shifts conceptually (§ 5.3) but their implementation already works correctly in the Racket interpreter.

**Phase 4 ships `low-pnet-to-prop-network`** (~200 LOC adapter) so IR-rewritten `ast-to-low-pnet` output can be tested in the Racket interpreter before Phase 5 ships LLVM emission. This is the new permanent translator; updates the rejected-direction comment in `network-to-low-pnet.rkt:33-35`.

### 15.7 `prop-network-to-low-pnet` learns the write-mode tag

When `prop-network-to-low-pnet` (Phase 2.B translator) introspects a runtime prop-network and emits `write-decl`s, it should distinguish writes via `net-cell-reset` (emit `:reset`) from writes via `net-cell-write` (emit `:merge`). ~10 LOC update in Phase 3 alongside the IR change.

### 15.8 Sprint G commit hash for Phase 6's deletion target

Phase 6 says "delete `iter-block-decl`" but should reference the introducing commit so the diff is reviewable as "revert + replace." Identify the commit before Phase 6 (likely the one that added `iter-block-decl` to `racket/prologos/low-pnet-ir.rkt:102-126` and its parse/pp/validate plumbing). Phase 0 (today) records this commit hash in the doc.

### 15.9 Phase 1 test gate verifies merge-vs-reset distinguishability

With the new `min`-merge i64 domain (§ 15.1), the test in `runtime/test-substrate.c` is non-vacuous:

```c
// Setup: cell c with min-merge i64 domain, init = 100
cell_write(c, 5); assert(read(c) == 5);    // min(100, 5) = 5
cell_write(c, 3); assert(read(c) == 3);    // min(5, 3) = 3
cell_write(c, 5); assert(read(c) == 3);    // min(3, 5) = 3 (commutative)
cell_reset(c, 7); assert(read(c) == 7);    // replace, bypass merge
```

This gate is impossible without min-merge, which is why § 15.1 ships them together.

### 15.10 Acceptance-example count is brittle

Phase 1/2/5 test gates say "currently-passing acceptance examples on this branch continue to pass" rather than pinning a specific count (which drifts between branches). Same protection without committing to a moving number.

### 15.11 Implementation defaults for spec gaps (challenge during Phase 1 if any cause friction)

Two spec-completeness gaps with recommended defaults:

| Gap | Default | Rationale |
|---|---|---|
| Stratum dispatch order across multiple eligible value-tier handlers | **Declaration order**, matching Racket's `process-tier` (`propagator.rkt:2487`). After topology tier completes, value-tier handlers fire in registration order. Deterministic. | Adopts Racket model directly; can be refined later if a use case demands explicit prioritization. |
| Trap recovery: what happens if a propagator traps mid-fire? | `run_to_quiescence` returns `trap`; caller decides. `@main` may abort; a parent stratum-handler propagator may catch and convert to a `cell_write` to a "contradiction" cell. | Matches Racket's exception-propagation behavior in the BSP outer loop. |

### 15.12 prologos-hamt.zig is already shipped — Phase 2 uses it directly

`runtime/prologos-hamt.zig` (Issue #42 Path A) is **already built and tested** (442 LOC, 10 unit tests, persistence properties verified, C-ABI exports). Phase 2 uses it directly; no separate "v2 upgrade" needed. The HAMT GC constraint (`2026-05-02_HAMT_ZIG_TRACK6.md` § 2: "nodes leak on insert/remove") is inherited; acceptable for substrate scope; revisit when Track 6 GC lands.

#### 15.12.1 HAMT GC leak — Phase 2 follow-up note (Day 7)

Day 6 wires the kernel's `cells_root` directly to the persistent HAMT, with each `cell_write` / `cell_reset` producing a new root via path-copy CoW. The displaced root pointer is dropped on the floor (per the HAMT module's documented "nodes leak on insert/remove" semantic — `prologos-hamt.zig:8`).

For the kernel's current scope, this leak is bounded:

* **Steady-state programs** (no `scope_run` cycles, no recursive PReduce): the leak grows at the rate of one CoW path-copy per `cell_write` / `cell_reset`. At ~40 bytes per HAMT branch node and a typical path length of ~3-4 levels for `MAX_CELLS=1024`, that is ~120-160 bytes per write. A program performing 100K writes leaks ~16 MB — uncomfortable for long-running services but trivially bounded for batch compilation + run-and-exit.
* **Scope-using programs** (NAF, ATMS, recursive PReduce after Phase 5 lands): each `scope_run` cycle generates a derived HAMT root that is referenced by the scope's record while alive, then becomes unreachable on `scope_exit` (along with all its CoW path nodes that diverged from the parent's root). Today these all leak.

**Track-6 GC integration plan** (sketch; not on this track's critical path):
1. **Reference counting** at the HAMT-node level — adds ~4 bytes per node + atomic inc/dec on every CoW, but enables prompt collection at `scope_exit`.
2. **Periodic mark-and-sweep** rooted at `cells_root` + every live `scope_records[i].saved_cells_root` — runs during quiescence (between `run_to_quiescence` calls), bounded pause time.
3. **Generational** — recycled small arenas for short-lived path-copy nodes during a single `run_to_quiescence`, freed wholesale at quiescence.

Recommendation: ship (1) when Track 6 starts its GC sub-piece. The kernel exposes the saved-root set via `scope_records[i].saved_cells_root` for whichever GC strategy lands; this design intentionally does not encode a GC choice.

The Day 7 microbench (`runtime/bench-scope-enter.c`) does NOT exercise the leak — `scope_enter`+`scope_exit` cycles don't allocate HAMT nodes (only pointer-share). The leak shows up in workloads with many `cell_write` calls. Future Phase 5 NAF migration tests will be the first to surface scope-cycle node leakage at scale; that is the appropriate moment to revisit Track 6 GC integration.

### 15.13 Naming canonicalization (one-source-of-truth check)

After this rev (2.1), the kernel API names are normative across §§ 5-8 and § 14. Verify before Phase 1 starts:

| Concept | Canonical name | Where defined |
|---|---|---|
| Allocate cell | `prologos_cell_alloc` | § 6 |
| Install propagator | `prologos_prop_install` | § 6 |
| Read cell | `prologos_cell_read` | § 6 |
| Write cell (merge mode) | `prologos_cell_write` | § 6 |
| Replace cell value (no merge, no enqueue) | `prologos_cell_reset` | § 6 |
| Run BSP outer loop | `prologos_run_to_quiescence` | § 6 |
| Push scope (snapshot + fresh fuel/worklist) | `prologos_scope_enter` | § 6, § 5.9 |
| Run BSP outer loop on scope with its own fuel | `prologos_scope_run` | § 6, § 5.9 |
| Read cell from scope's HAMT | `prologos_scope_read` | § 6, § 5.9 |
| Pop scope (release HAMT root) | `prologos_scope_exit` | § 6, § 5.9 |
| IR node for non-monotone write | `write-decl` with `:reset` mode | § 8.1 |
| IR node for merge write | `write-decl` with `:merge` mode (default) | § 8.1 |

If any subsequent edit reintroduces `prologos_pu_*` API (note: scope APIs are not PU APIs — they're the runtime fuel-attribution mechanism), `pu-decl` / `stratum-handler-decl` / `pu-entry-decl` / `pu-exit-decl` / `pu-halt-decl` IR nodes, or `iter-block-decl` (as anything but a retirement reference), it's a regression against this table.

### 15.14 Scope stack-discipline enforcement (and what happens if it's violated)

The kernel maintains a stack of active scopes. `scope_enter` pushes; `scope_exit` pops. The kernel requires that `scope_exit` calls be properly nested with respect to `scope_enter` calls (LIFO order).

**Violation modes**:

1. *Forgotten `scope_exit`*: a fire-fn enters scope but never exits before returning. Result: the scope stays on the stack; subsequent `cell_*` calls in the parent fire-fn (and elsewhere) target the leaked scope's HAMT root, not the parent's. This corrupts subsequent reads/writes. **Mitigation**: kernel-side debug-mode assertion that `scope_enter` count == `scope_exit` count between fire-fn invocations.
2. *Out-of-order `scope_exit`*: fire-fn pops a scope that's not the current top. Result: returns the wrong HAMT root to the active scope. **Mitigation**: `scope_exit(scope_handle)` takes the scope handle as argument (already in the API); kernel verifies `scope_handle == top-of-stack` and traps if not.
3. *Double `scope_exit`*: fire-fn pops the same scope twice. Result: pops a scope that's not the one the second exit thinks it's popping. **Mitigation**: scope handle becomes invalid after `scope_exit`; second exit traps.

Phase 1 implements (1) as a debug-only assertion (release builds skip the check for performance); (2) and (3) as runtime traps in all builds (low cost, high value).

### 15.15 Trap propagation across scope boundaries

If a propagator inside `scope_run` triggers a contradiction or trap (e.g., a domain check fails):

- The kernel sets `scope`'s contradiction flag.
- `scope_run` returns `RunResult.trap` to the calling fire-fn (in the parent scope).
- The handler's fire-fn decides what to do:
  - **Convert to data**: write the contradiction to a parent-scope "contradiction" cell (e.g., `cell_write(parent-naf-failed-cell, true)`); call `scope_exit`; continue.
  - **Propagate upward**: don't catch; the calling fire-fn returns; the parent scope's BSP loop sees the trap (handler propagator's fire-fn returning a trap signal) and propagates further.
  - **Retry**: clean up partial state via `cell_reset` calls on parent cells; call `scope_exit`; re-attempt with different parameters.

Same model as Racket's exception-bubbling-through-fork pattern. The kernel doesn't impose a policy; the handler chooses.

**Phase 1 test**: a divergent-then-trap inner goal in `scope_run`; verify the handler can catch the trap, write a "naf failed" indicator to the parent, and continue without aborting the parent BSP outer loop.

### 15.16 Default `parent_fuel_charge` calibration

`scope_enter(parent_fuel_charge)` charges the parent for creating the scope. Default 10 fuel units.

Rationale: scope creation is cheap (one HAMT root pointer copy + one fuel-counter init + one stack push) — not zero-cost (push and snapshot pointer copy do require some work) but small. 10 units allows ~100K scope creations per million-fuel parent budget; orders of magnitude beyond what NAF / ATMS handlers in current acceptance examples create.

**Profile in Phase 8**: if scope-creation pressure (e.g., recursive NAF with thousands of inner calls) causes parent fuel to deplete primarily on scope-creation overhead, lower the charge or batch scope creation. Calibration data goes into the PIR.

---

## Appendix A: Rejected alternatives

### A.1 Rev 1 — full kernel-PU primitive (rejected)

Rev 1 of this doc proposed a kernel-level PU and stratum-handler primitive:

- Kernel API: ~12 functions (`prologos_pu_alloc` / `_run` / `_dealloc` / `_set_entry` / `_set_exit` / `_set_halt` / `_register_stratum` / `_cell_alloc_in` / `_cell_write_in` / `_cell_reset_in` / `_cell_read_in` / `_prop_install_in`)
- 5 new Low-PNet IR node kinds: `pu-decl`, `stratum-handler-decl`, `pu-entry-decl`, `pu-exit-decl`, `pu-halt-decl`
- Per-PU arenas (HAMT-rooted), per-PU strata stack, lifecycle management, entry/exit/halt declarative tables
- Worldview-bit allocator API at the kernel
- Cost: ~15-25 days

**Why rejected**: § 12.4 details. Summary: PUs are real abstractions but they live mostly at the COMPILER layer (Racket runtime, NTT, PReduce); the kernel needs the SUBSTRATE they elaborate to plus a minimal scope mechanism for fuel isolation (§ 2.5). Rev 1 over-engineered by adding kernel concepts above cells/propagators when the dissolve audit (§ 2) shows most capabilities work as topology with three irreducible kernel additions (`cell_reset` + topology deferral + scope APIs).

### A.2 Rev 2 — pure dissolve, no scope (rejected)

Rev 2 (immediately prior version of this doc) proposed dissolving everything into topology, with the kernel adding only `cell_reset` + topology-mutation deferral (6 functions total, no scope APIs).

**Why rejected**: per-PU fuel does not dissolve into topology (§ 2.5). Without per-scope fuel isolation, a divergent NAF inner goal would consume parent global fuel and break the parent computation. Rev 2's "global fuel only" model loses the NAF / ATMS isolation that Racket has had since `fork-prop-network` shipped (`propagator.rkt:715-719`).

The dissolve insight survived (most of rev 2's claims hold; see § 12.4 "what survived"); but the "kernel adds only two things" claim was incomplete. **Rev 2.1 is the corrected dissolved + minimal-scope architecture** — most of rev 2 plus 4 narrow scope APIs that recover per-PU fuel isolation at the smallest possible kernel-surface cost.

Recoverable from git history at the rev-1 commit and rev-2 commit (immediately prior to rev 2.1). Not preserved in full to keep this doc manageable.

---

**End of design doc.**
