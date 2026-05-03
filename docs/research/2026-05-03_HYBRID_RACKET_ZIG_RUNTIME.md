# Hybrid Racket-Zig Runtime — Research Sprint

**Date**: 2026-05-03
**Stage**: 1 — research synthesis. No design commitments; informs a future implementation track.
**Series**: SH (Self-Hosting), parallel/alternative to Track 1 LLVM lowering.
**Branch context**: `claude/prologos-layering-architecture-Pn8M9`
**Author**: Claude (research synthesis).

**Cross-references**:
- [SH Master Tracker](2026-04-30_SH_MASTER.md)
- [Self-Hosting Path and Bootstrap Stages](../research/2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md)
- [Concurrency Primitives for the .pnet → LLVM Substrate](../research/2026-05-02_CONCURRENCY_PRIMITIVES_LLVM_SUBSTRATE.md) — Zig-side BSP design building blocks that compose with this hybrid model
- [Kernel Pocket Universes design](2026-05-02_KERNEL_POCKET_UNIVERSES.md) — the kernel PU primitive sits inside this runtime
- [PReduce-lite Design Doc](2026-05-02_PREDUCE_LITE_DESIGN.md) — Racket-side reducer that this hybrid runtime would host on the hot path
- [PReduce-lite PIR](2026-05-03_PREDUCE_LITE_PIR.md) — terminal state of Racket-side reducer
- [Low-PNet IR Design Doc](2026-05-02_LOW_PNET_IR_TRACK2.md) — alternate lowering path (LLVM IR generation for a fully-Zig binary)
- `runtime/prologos-runtime.zig` — existing 544-line single-threaded BSP kernel with per-tag profiling
- `runtime/prologos-hamt.zig` — existing 441-line CHAMP-style persistent map (Track 6 path A)

---

## 1. Frame

### 1.1 The proposal in one paragraph

Bundle the existing Racket-implemented Prologos compiler (parser, elaborator, type-checker, PReduce-lite reducer, and standard-library `.prologos` modules) **as-is** into a distributable artifact alongside a minimal Zig runtime that owns the BSP scheduler, cell storage (HAMT), and a hardcoded set of fast fire functions. The Racket side parses Prologos programs and constructs a propagator network by **calling into the Zig runtime** (allocating cells, installing propagators). The Zig runtime executes the network on the hot path; when it needs to fire a propagator whose body lives in Racket (because we haven't migrated that fire-fn to Zig yet), it **calls back into Racket** via FFI. The runtime instruments per-tag wall-time and per-tag callback counts, producing a prioritized list of fire-fns whose Racket implementations dominate runtime — these become the next migration targets.

### 1.2 Why this approach is interesting (vs LLVM lowering)

**LLVM lowering** (SH Series Track 1, PR #39) compiles the elaborated AST → LLVM IR → native binary. The binary is fully self-contained: no Racket runtime, no interpreter overhead, theoretical maximum performance. But it requires every AST node + every reduction rule to be expressible at the LLVM IR level, which means re-implementing the Racket reducer in C-like terms. Today that pass handles three "tiers" (literals, arithmetic, top-level non-capturing functions); to handle the full language requires re-implementing closures, eliminators, traits, ATMS, the trait registry, etc. — essentially porting the Racket compiler.

**The hybrid approach** (this proposal) trades binary size + interpreter overhead for **breadth-first coverage**: a binary that runs *every* Prologos program correctly today (because Racket handles it correctly), with a clear migration path to move hot-path fire functions into Zig as profiling identifies them. Time-to-first-binary is 1-2 weeks instead of months. Each subsequent migration step is independent and incremental.

The two approaches are not exclusive — the LLVM track can continue, and the hybrid runtime can host LLVM-compiled fire functions when they exist. They share architecture (BSP scheduler, propagator network) and could converge.

### 1.3 What this research note delivers

A Stage 1 synthesis. Not a design commitment. The note answers:

- **What is the seam?** (§3 — four architectural options + recommendation)
- **What's on each side?** (§4 — concrete API surface)
- **How do values cross?** (§5 — cell-value marshaling, the hardest engineering problem)
- **How does Racket call Zig and vice versa?** (§6 — FFI mechanism + Racket-CS embedding strategies)
- **How do we identify what to move next?** (§7 — profiling instrumentation, mostly already in the kernel)
- **What goes wrong?** (§8 — risk + cost analysis)
- **If we proceed, what's the sprint plan?** (§9 — 5-6 phases, ~10-15 days)
- **What's open?** (§10 — research questions for a future Stage 2/3 design doc)

---

## 2. Current state (factual)

### 2.1 Racket side

The full Prologos toolchain in `racket/prologos/`:
- `parser.rkt` / `tree-parser.rkt` — sexp + WS-mode reader
- `elaborator.rkt` — surface-syntax → core-AST + type inference
- `typing-core.rkt` / `qtt.rkt` — type checking with QTT multiplicities
- `reduction.rkt` — 3700-LOC tree-walking reducer (the existing slow path)
- `preduce.rkt` — 1390-LOC PReduce-lite (Racket-side propagator-network reducer; just landed)
- `propagator.rkt` — propagator network primitives (cells, fire-once, BSP scheduler, register-stratum-handler, …)
- `lib/prologos/*.prologos` — standard library (Nat, Bool, List, Option, Result, traits Eq/Ord/Add/Sub/Mul, …)

### 2.2 Zig side (existing)

`runtime/prologos-runtime.zig` (544 LOC, single-threaded):
- Flat fixed cell array (`MAX_CELLS=1024`, `i64` cell value)
- Flat fixed propagator array (`MAX_PROPS=1024`, three shape kinds: 1-1, 2-1, 3-1)
- Per-tag dispatch in `fire_against_snapshot`: ~10 hardcoded fire-fns (identity, int-neg/abs/add/sub/mul/div/eq/lt/le, select)
- BSP scheduler (snapshot/diff/merge/dedup) — 100% functional today
- Per-tag profiling: `stat_fires_by_tag[N_TAGS]`, `stat_ns_by_tag[N_TAGS]` (opt-in via `prologos_set_profile_per_tag`)
- Subscriber lists (per-cell list of dependent prop-ids), `MAX_DEPS=16`
- Stats: rounds, fires_total, fires_by_tag, writes_committed, writes_dropped, max_worklist
- Compiles via `zig build-obj` to a single `.o`

`runtime/prologos-hamt.zig` (441 LOC):
- CHAMP-style persistent hash array mapped trie
- Used by N1+ programs needing structural sharing
- Not yet integrated into cell storage (cells are still flat i64)

### 2.3 What's missing

- No Racket ↔ Zig FFI — the `.o` is currently linked into LLVM-lowered programs (Tier 0-2 of PR #39) and exercised via C test harnesses. No production path embeds Racket.
- The Zig kernel hardcodes ~10 fire-fn tags. To extend, you currently edit Zig source. There's no callback-fn-table mechanism.
- Cells are `i64`; can't hold Prologos values like AST structs, lambda closures, pairs-of-values.
- No HAMT-backed cell store yet (the HAMT library exists but isn't wired in).

These are the deltas between today and the hybrid runtime. The research below assesses how big each delta is.

---

## 3. The seam — four architectural options

The fundamental question: where does the boundary between Racket and Zig sit? Four options, ordered by how much Zig owns.

### 3.1 Option A — Cells in Zig only

**Zig owns**: cell storage (HAMT-backed). Just `cell_alloc` / `cell_read` / `cell_write` / `cell_subscribe`.
**Racket owns**: everything else (network construction, scheduling, fire-fn dispatch, BSP loop).

**Hot path**: every `(net-cell-read)` / `(net-cell-write)` is an FFI call from Racket into Zig. The BSP scheduler logic stays in Racket.

**Cost**: ~1 week (just port the existing Racket cell store to Zig HAMT + bind FFI).

**Verdict**: ✗ doesn't capture the hot path. The expensive work in PReduce-lite is the BSP scheduler iterating over ~1000 propagators per round. Moving cells to Zig adds FFI overhead per cell access without taking the loop into Zig.

### 3.2 Option B — Cells + scheduler in Zig; fire-fns in Racket

**Zig owns**: cells + propagators + BSP scheduler + per-tag dispatch.
**Racket owns**: AST → network construction. All fire functions are Racket callbacks.

**Hot path**: BSP loop runs in Zig; every fire-fn invocation is an FFI call out to Racket.

**Cost**: ~1.5 weeks (Racket-side network-construction shim + Racket fire-fn callback wrapper + FFI marshaling).

**Verdict**: partial — the BSP loop is Zig-fast, but every fire is an FFI call. If 80% of fires are int-arithmetic and we have those in Zig already, this option is fine for those. If 80% of fires are Racket callbacks (PReduce-lite's case today — every preduce-merge is a Racket fn), the FFI overhead dominates and we've gained little vs running everything in Racket.

The fix for B: include a hardcoded set of "kernel" fire-fns in Zig (which we already have for int arithmetic). Tags map to either a kernel fn or a callback. As we migrate fire-fns to Zig, the callback set shrinks.

This is essentially **Option C** below.

### 3.3 Option C — Cells + scheduler + dynamic fire-fn dispatch (recommended)

**Zig owns**: cells + propagators + BSP scheduler + a dispatch table mapping `fire-fn-tag → fn ptr`. At install time, the tag is registered in the dispatch table with either:
- (a) a built-in Zig fire function (kernel set: int-add, int-mul, etc.; expand over time), OR
- (b) a Racket callback wrapper (slow path)

**Racket owns**: AST → network construction (calls Zig install APIs); the implementation of (b) callback fire-fns; everything outside the network execution loop.

**Hot path**: BSP loop runs in Zig; per-fire dispatch is one indirect call (kernel) or one FFI call (callback). The kernel-vs-callback decision is per-tag, set at registration.

**Migration strategy**: profile per-tag wall time; tags whose callback time dominates get ported to Zig (the (a) path). Migration is per-tag-at-a-time; doesn't break compatibility.

**Cost**: ~2 weeks (~1 week new Zig + ~1 week Racket FFI + integration).

**Verdict**: ✓ this is the recommended seam. Captures the BSP hot path in Zig. Migration is incremental and observable. Existing `prologos-runtime.zig` is 80% there already (cells, scheduler, per-tag profiling all done; what's missing is the dynamic dispatch table + the Racket callback bridge).

### 3.4 Option D — Full LLVM lowering (the alternative path; not this proposal)

**Zig owns**: nothing — Racket stops at compile-time, the binary is a fully-LLVM-compiled standalone.
**Racket owns**: only the compiler (offline at build time).

**Hot path**: pure native code; no FFI; theoretical max performance.

**Cost**: per the existing PR #39, Tiers 0-2 done; full coverage of the language is months of work.

**Verdict**: ✗ for this proposal — long-tail effort. ✓ as a parallel track that converges later.

### 3.5 Comparison summary

| | A (cells only) | B (sched, all callbacks) | **C (sched + dispatch table)** | D (LLVM full) |
|---|---|---|---|---|
| Hot-path BSP in native | ✗ | ✓ | **✓** | ✓ |
| Time-to-first-binary | ~1w | ~1.5w | **~2w** | months |
| Incremental fire-fn migration | n/a | n/a | **per-tag, observable** | per-feature, all-or-nothing |
| Compatibility with existing Racket Prologos | full | full | **full** | tier-limited |
| Captures FFI overhead in profile | ✓ | partial | **✓** (per-tag callback ns) | n/a |
| Composes with LLVM track | yes | yes | **yes** | self |

**Recommendation: Option C.** Existing kernel is 80% of what's needed; the remaining 20% is dynamic dispatch + Racket FFI. Profile-driven migration gives a concrete path to close the FFI overhead over time, with measurable progress at each step.

The rest of this document is Option C in detail.

---

## 4. Concrete API surface (the seam under Option C)

### 4.1 Zig kernel APIs (additions to existing surface)

```zig
// === Existing (already in runtime/prologos-runtime.zig) ===
prologos_cell_alloc() -> u32
prologos_cell_write(id: u32, val: i64) -> void
prologos_cell_read(id: u32) -> i64
prologos_propagator_install_1_1(tag, in0, out0) -> u32
prologos_propagator_install_2_1(tag, in0, in1, out0) -> u32
prologos_propagator_install_3_1(tag, in0, in1, in2, out0) -> u32
prologos_run_to_quiescence() -> void
prologos_set_max_rounds(m) -> void
prologos_get_stat(key) -> u64
prologos_print_stats() -> void
prologos_set_profile_per_tag(enabled: u32) -> void
prologos_reset_stats() -> void

// === New for hybrid runtime ===

// Register a tag → fn-ptr binding. shape ∈ {1, 2, 3} matches the
// install_N_1 family. fn_ptr is a C ABI function with signature
// determined by shape:
//   shape 1: fn(i64) i64
//   shape 2: fn(i64, i64) i64
//   shape 3: fn(i64, i64, i64) i64
// kind ∈ {KIND_KERNEL, KIND_RACKET_CALLBACK} — distinguishes for
// profiling and for cell-value marshaling discipline.
prologos_register_fire_fn(
    tag: u32,
    shape: u32,
    kind: u32,        // 0 = kernel (Zig native), 1 = Racket callback
    fn_ptr: *const fn,
) -> u32  // 0 on success, error code otherwise

// Install a propagator with arbitrary input arity (extends 1/2/3 fixed
// shapes). For higher-arity propagators (e.g., expr-reduce dispatching
// on N constructor arms). The fire-fn has signature
//   fn(num_inputs: u32, inputs: [*]const i64) i64
prologos_propagator_install_n_1(
    tag: u32,
    inputs: [*]const u32,    // cell ids
    num_inputs: u32,
    out0: u32,
) -> u32  // pid

// Cell-value marshaling — see §5.
prologos_cell_box(racket_value_handle: u64) -> i64    // returns boxed i64
prologos_cell_unbox(boxed: i64) -> u64                 // returns Racket handle
prologos_cell_value_kind(boxed: i64) -> u32            // 0=int, 1=bool, 2=racket-handle, ...

// Per-tag callback profiling (extends existing fires_by_tag).
prologos_get_callback_ns_by_tag(tag: u32) -> u64
prologos_get_callback_count_by_tag(tag: u32) -> u64
prologos_print_callback_summary() -> void   // sorted by total ns

// Generic event hook so Zig can call arbitrary Racket functions
// (used by stratum handlers to signal Racket between BSP rounds).
prologos_set_round_callback(fn_ptr: *const fn(u32) void) -> void
//   fn_ptr called with (round_number) at end of each BSP round.
//   #f / null → no callback.

// Optional: HAMT-backed cell store toggle. Default: flat array.
// When enabled, cell-id 0..N have flat backing; >N have HAMT backing.
prologos_use_hamt_cells(threshold: u32) -> void
```

### 4.2 Racket-side wrappers

`racket/prologos/runtime-bridge.rkt` (new):

```racket
#lang racket/base

(require ffi/unsafe ffi/unsafe/define)

(define-ffi-definer define-rt
  (ffi-lib "libprologos-runtime"))

(define-rt prologos_cell_alloc      (_fun -> _uint32))
(define-rt prologos_cell_write      (_fun _uint32 _int64 -> _void))
(define-rt prologos_cell_read       (_fun _uint32 -> _int64))
(define-rt prologos_propagator_install_1_1
  (_fun _uint32 _uint32 _uint32 -> _uint32))
(define-rt prologos_propagator_install_2_1
  (_fun _uint32 _uint32 _uint32 _uint32 -> _uint32))
(define-rt prologos_propagator_install_3_1
  (_fun _uint32 _uint32 _uint32 _uint32 _uint32 -> _uint32))
(define-rt prologos_propagator_install_n_1
  (_fun _uint32 (_array _uint32 0) _uint32 _uint32 -> _uint32))
(define-rt prologos_run_to_quiescence (_fun -> _void))
(define-rt prologos_register_fire_fn
  (_fun _uint32 _uint32 _uint32 _pointer -> _uint32))
;; ... etc
```

Plus a higher-level `racket/prologos/runtime/prop-network.rkt` that mirrors today's `propagator.rkt` API but routes to the Zig kernel. The existing `(net-cell-read net cid)` becomes `(prologos_cell_read cid)` (no `net` parameter — the kernel owns the singleton state).

This is a mechanical refactor of `propagator.rkt` to be a thin shim. PReduce-lite's `compile-expr` doesn't change.

### 4.3 Racket fire-fn callback wrapper

Each Racket fire-fn (e.g., the closure built by PReduce-lite's `make-app-fire`) gets wrapped as a `_fun` callback the Zig kernel can invoke:

```racket
(define (wrap-fire-fn-as-c-callback shape rkt-fire-fn)
  (case shape
    [(1) (function-ptr
          (lambda (in0)
            (rkt-fire-fn in0))
          (_fun _int64 -> _int64))]
    [(2) (function-ptr
          (lambda (in0 in1)
            (rkt-fire-fn in0 in1))
          (_fun _int64 _int64 -> _int64))]
    [(3) (function-ptr
          (lambda (in0 in1 in2)
            (rkt-fire-fn in0 in1 in2))
          (_fun _int64 _int64 _int64 -> _int64))]))
```

The `function-ptr` API in Racket FFI converts a Racket procedure into a callable C function pointer. This is the load-bearing FFI mechanism for the callback direction.

---

## 5. Cell-value marshaling — the hardest engineering problem

The existing kernel stores `i64` per cell. That's fine for `expr-int`, `expr-true/false`, `expr-nat-val`, and Bool comparison results. But PReduce-lite's value lattice includes:

- AST nodes — `(expr-pair a b)`, `(expr-suc inner)`, `(expr-int 42)` — Racket structs
- Lambda values — `(preduce-lam mw type body env)` — Racket structs containing AST sub-trees
- Container wrappers — `(expr-champ champ-empty)`, `(expr-rrb rrb-empty)`, `(expr-hset ...)`
- Pair values — `(preduce-pair fst-cid snd-cid)` — carries cell-ids of components
- Sentinels — `'preduce-bot`, `'preduce-top`

These are Racket-managed objects. They can't fit in i64. Three options:

### 5.1 Option M1 — Tagged i64 with handle table

The kernel stores `i64`. Layout:
- Bits 63..56: type tag (8 bits)
- Bits 55..0: payload
- Tag 0 = primitive int (payload is the int, sign-extended)
- Tag 1 = bool (payload 0/1)
- Tag 2 = nat-val (payload is the nat)
- Tag 3 = bot
- Tag 4 = top
- Tag 5 = Racket handle (payload is index into a Racket-managed handle table)

For tag 5, Racket maintains a `(make-vector capacity #f)` handle table. The `cell_box` API takes a Racket value, finds a free slot, returns `(<<5 56) | slot-index`. The `cell_unbox` reverse.

**Pros**: i64 cells stay; kernel doesn't need GC integration; Racket-side handle table lets us GC handles when their Racket counterparts are unreferenced.

**Cons**: every non-primitive cell read/write costs a handle-table lookup in Racket. For PReduce-lite where most cells hold AST structs, this is most cells.

### 5.2 Option M2 — Variant cell type (kernel learns about boxes)

The kernel's cell store becomes a variant: `union { i64; *opaque; }`. The kernel stores a tag bit per cell. Reads/writes use the appropriate variant. The opaque pointer is owned by Racket.

**Pros**: same performance as M1 for the lookup, but the tag bit is on the cell, not in the value. Doesn't waste 8 bits of i64.

**Cons**: changes the kernel's cell layout (every cell is now ~16 bytes instead of 8); more complex.

### 5.3 Option M3 — Push values fully into Racket; cells are pointers

The kernel stores only pointers (or handles). All cell values are Racket-managed.

**Pros**: simpler kernel.

**Cons**: every cell access is FFI through a Racket lookup. Eliminates the hot-path advantage entirely. Rejected.

### 5.4 Recommendation

**M1 (tagged i64).** Pros: zero kernel layout change. Hot path for primitive cells (int/bool/nat) is one branch in the fire-fn (extract tag, switch). Cold path for Racket-handle cells goes through FFI but those fires are already callbacks.

The handle table is small in practice (per-call, per-PReduce invocation, the handle count is ~100s of cells × low fraction with Racket values). GC happens at end-of-call by clearing the table.

The 8-bit tag space (256 type tags) is more than enough; we'll use ~10.

### 5.5 Open question: cell-id allocation across Racket-Zig

Cell-ids live in Zig. Racket calls `prologos_cell_alloc`, gets an `u32`. That id is unique in the kernel. Racket doesn't allocate cells of its own.

But what about Racket-side data structures referenced by handles? Their lifetime is bounded by:
1. The `(preduce e)` call — handles are valid until the call returns.
2. After return, the kernel state is reset (`prologos_reset_stats` + zero `num_cells`/`num_props`); the handle table clears.

This works for one-shot reductions. For long-lived networks (interactive REPL, future incremental compilation), we'd need explicit handle-release / handle-GC integration. Defer to a future "long-lived hybrid runtime" design.

---

## 6. FFI mechanism — Racket-CS embedding strategies

The hybrid runtime is a **single binary** containing both Racket-CS runtime + Zig kernel + the user's Prologos program. Three packaging strategies:

### 6.1 Strategy E1 — `raco distribute` + Zig as `.so` dependency

Use `raco distribute` to build a self-contained Racket-CS executable. Bundle `libprologos-runtime.so` (the Zig `.o` linked as a shared library). The Racket entrypoint requires `runtime-bridge.rkt`, which `dlopen`s the `.so` via `ffi-lib`.

**Pros**: standard Racket distribution path; documented; the `.so` is trivially included in the distribution directory.

**Cons**: distribution is a directory, not a single file. The user runs `bin/prologos --run program.prologos`, which expects `lib/libprologos-runtime.so` alongside.

### 6.2 Strategy E2 — `raco demod` static linking + Zig static archive

Use `raco demod` (Racket-CS) to produce a single `.zo` containing the entire Racket runtime + the user's program. Link Zig as a static `.a`. Wrap with a shell that has Racket-CS embedded.

**Pros**: closer to a single-file binary.

**Cons**: more complex build; `raco demod` is for partial-evaluation, not production embedding; not the canonical path.

### 6.3 Strategy E3 — Embed Racket-CS as a library inside Zig

Use Chez Scheme's C embedding API (`Sscheme_init`, `Sregister_symbol`, `Scall1`, etc.) to load a Racket-CS instance into a Zig host process. The Zig binary is the entrypoint; it bootstraps Racket-CS at startup, loads the user's program, then the program calls back into Zig as expected.

**Pros**: single-file binary; Zig owns startup; clearest separation.

**Cons**: undocumented for Racket-CS specifically (Chez has the docs; Racket-CS is built on Chez but adds layers); risk of undefined behavior; investment cost is high.

### 6.4 Recommendation

**E1 for v1.** It's the well-trodden path. The distribution is a directory; the user runs a launcher script. We can ship E1 as the production mode and validate E2/E3 as future optimizations if single-file matters more than time-to-ship.

`raco distribute` handles bundling Racket-CS itself, the user's `.zo` files, and the standard library `.prologos` modules. We add a step to copy `libprologos-runtime.so` into the distribution's `lib/` directory and ensure `ffi-lib` finds it.

### 6.5 FFI overhead — what we should expect

Numbers I'm extrapolating from literature (will need calibration):

| Operation | Cost | Note |
|---|---|---|
| Racket → Zig (no marshaling, primitive args) | ~50-100 ns | One indirect call via libffi or raw |
| Racket → Zig (with marshaling, struct args) | ~200-500 ns | Allocator + boxing per arg |
| Zig → Racket callback (no marshaling) | ~100-300 ns | More expensive than the forward direction; goes through Racket's foreign-call machinery |
| Zig → Racket callback (with handle resolution) | ~500-1000 ns | + handle-table lookup |

Compare to Zig-native fire (kernel int-add): ~1-3 ns per fire.

**Implication**: every Racket callback fire is ~100-500x slower than a kernel fire. Workloads dominated by callbacks won't see much speedup vs pure-Racket. The migration economics: every fire-fn moved to Zig saves the callback overhead × fires-per-run. For a fire-fn that's ~30% of total fires, migration is worth it as soon as the user runs the program enough times to amortize the migration cost.

This is exactly why per-tag profiling is load-bearing.

---

## 7. Profiling instrumentation — what we measure

The existing kernel already measures:
- `stat_rounds` — total BSP rounds
- `stat_fires_total` — total fires
- `stat_fires_by_tag[N_TAGS]` — fires per tag
- `stat_ns_by_tag[N_TAGS]` — wall time per tag (opt-in)
- `stat_writes_committed`, `stat_writes_dropped`, `stat_max_worklist`

For the hybrid runtime we add:

```zig
stat_callbacks_by_tag[N_TAGS]      // count of Racket-callback fires per tag
stat_callback_ns_by_tag[N_TAGS]    // wall time spent in Racket callbacks per tag
stat_marshal_ns_total              // wall time spent in cell-value marshaling
stat_handle_table_size_max         // peak handle-table occupancy
```

The `prologos_print_callback_summary` API sorts tags by total callback ns descending and prints a table:

```
=== Callback Profile ===
tag                       fires    total_ns   avg_ns  recommend
preduce-merge             12345    1.3M ns      105    PORT NOW (35% of run)
make-app-fire              4567    340K ns       74    consider
make-natrec-fire           1200     90K ns       75    later
kernel-int-add (native)    9876      28K ns      2.8   already native
```

This output is the migration triage tool. After running a representative workload, the developer reads the table and decides which Racket fire-fns to port to Zig next.

---

## 8. Risk + cost analysis

### 8.1 Costs

| Item | Estimate | Notes |
|---|---|---|
| Zig: dynamic-dispatch table for fire-fns | 1d | extends existing `fire_against_snapshot` with fn-ptr lookup |
| Zig: `prologos_register_fire_fn` API | 0.5d | + marshaling kind tag |
| Zig: `prologos_propagator_install_n_1` (variable arity) | 1d | new arena for input-cid arrays |
| Zig: cell-value tagged-i64 marshaling | 1d | encode/decode + handle-table interop |
| Zig: callback profiling instrumentation | 0.5d | mirrors existing per-tag profiling |
| Racket: `runtime-bridge.rkt` FFI bindings | 1d | mechanical, ~150 LOC |
| Racket: `runtime/prop-network.rkt` shim mirroring existing propagator.rkt API | 2d | refactor; fold in existing fire-once / topology infrastructure |
| Racket: callback-wrapping helper (`wrap-fire-fn-as-c-callback`) | 0.5d | uses Racket's `function-ptr` |
| Racket: handle-table for Racket values crossing the seam | 1d | per-call lifetime; reset on entry |
| Integration: `raco distribute` packaging + launcher script | 1d | including `libprologos-runtime.so` copy |
| Integration: end-to-end test on a Prologos program | 1d | factorial-iter via PReduce-lite via hybrid runtime |
| Profiling validation: run on a real workload, generate the callback summary | 0.5d | |
| **Total** | **~10 days** | one-developer single-track |

### 8.2 Risks

**R1 — FFI overhead dominates**. If most fires are Racket callbacks (the PReduce-lite case), the per-fire 100-500ns FFI cost may exceed the saved scheduler time. Result: hybrid runtime is slower than pure Racket on PReduce-lite workloads. Mitigation: port the top-3 Racket fire-fns (preduce-merge, make-app-fire, make-natrec-fire) to Zig as Phase 1.5 if the profile shows them dominating.

**R2 — Racket-CS embedding fragility**. `raco distribute` is the well-trodden path but specific behaviors (FFI library search, working-directory resolution, dynamic loading on Linux/macOS/Windows differences) may surface platform issues. Mitigation: target Linux only for v1; defer macOS/Windows.

**R3 — Cell-value marshaling boundary bugs**. Tagged i64 has 8 bits of tag and 56 bits of payload; if a Prologos int exceeds 56 bits we silently corrupt. Mitigation: bound int range at the elaborator (Prologos ints are already 64-bit per `expr-int`; need a runtime check or wider tag scheme).

**R4 — Handle-table lifetime**. If Racket GC moves objects, the kernel's stored pointers become stale. Mitigation: pin handle-table entries via Racket's `make-immobile-cell` or store integer indices into a Racket-managed vector (no movement).

**R5 — Long-running networks** (REPL, interactive programs, future incremental compilation): handles accumulate; no GC strategy. Mitigation: defer; v1 is one-shot reductions only. Future: explicit handle-release API + per-PU lifetime scoping.

**R6 — Multi-thread safety**. The Zig kernel is single-threaded today. The Racket-CS runtime is also single-threaded for callbacks (one place-channel per place, but cross-place callbacks are deeply problematic). If we later add Sprint D's parallel BSP, we need each worker to either own its own Racket runtime (impossible) or call back into a shared Racket runtime serially. Mitigation: defer multi-thread; v1 is single-threaded.

**R7 — Compatibility with full Track 9**. PReduce-lite's terminal state hosts on the hybrid runtime. Full Track 9 (incremental, dependency-tracking) adds per-cell subscription that's more complex. The hybrid runtime's cell APIs need to expose subscription metadata. Mitigation: design the APIs to allow future extension; don't paint into a corner.

### 8.3 What dominates risk

R1 (FFI overhead dominates). All other risks are tractable engineering. R1 is fundamental: if profiling shows ~80% of fires are Racket callbacks at native speed too, the hybrid runtime is no faster than pure Racket. Mitigation requires migrating fire-fns.

The good news: **PReduce-lite's hot fire-fns are mostly mechanical** (preduce-merge, identity, beta dispatch, eliminator dispatch). Each is a few-line Racket function that ports to Zig in under an hour. The migration economics work as long as we're willing to invest a few days porting the top-N.

---

## 9. Sprint plan if proceeding

If the user green-lights this approach, here's the phase plan:

### Phase 0 — Calibration (0.5 day)

Measure baseline FFI cost on the host. Microbench:
- 10M Racket → C calls (no marshaling) — measure ns/call
- 10M C → Racket callbacks — measure ns/call
- 1M tagged-i64 unbox + handle-table lookup — measure ns/op

Anchors the cost model. If numbers are 10x worse than expected (>1us per callback), pivot to Option D (LLVM lowering).

### Phase 1 — Zig dynamic dispatch (1.5 days)

- Extend `fire_against_snapshot` to look up fn-ptr from a tag-keyed table
- `prologos_register_fire_fn` API
- `prologos_propagator_install_n_1` for variable arity
- Tagged-i64 cell-value marshaling helpers (`prologos_cell_box`, `prologos_cell_unbox`, `prologos_cell_value_kind`)
- Callback profiling counters

Validate via existing C tests (`test-bsp-feedback.c`, `test-bsp-stats.c`) plus new test for dynamic dispatch.

### Phase 2 — Racket FFI bindings + bridge (2 days)

- `racket/prologos/runtime-bridge.rkt` — `define-rt` bindings for all kernel APIs
- `racket/prologos/runtime/prop-network.rkt` — high-level shim mirroring existing propagator.rkt API (cells, fire-once, BSP run-to-quiescence)
- Handle table: `make-vector` with index-based storage; reset per `(preduce e)` call
- `wrap-fire-fn-as-c-callback` helper

End-to-end smoke test: `(preduce (expr-int-add (expr-int 2) (expr-int 3)))` runs through hybrid runtime, gets `(expr-int 5)`.

### Phase 3 — PReduce-lite hosting (2 days)

- Refactor `preduce.rkt` to call into the hybrid runtime via `runtime/prop-network.rkt` instead of Racket-side `propagator.rkt`
- Run all 90 PReduce-lite unit tests + 2000-case differential gate against the hybrid runtime
- Expected: 100% pass; some fire-fns will be slower (callbacks) but correctness identical
- Generate first callback profile for a representative workload (factorial-iter 1 100, fibonacci 20)

### Phase 4 — `raco distribute` packaging (1 day)

- Build script that:
  1. Compiles Racket modules (`raco make`)
  2. Builds `libprologos-runtime.so` from Zig
  3. Runs `raco distribute` to assemble the bundle
  4. Copies `.so` into bundle's `lib/`
  5. Generates launcher script
- Test on a clean machine (Docker container) — does the produced bundle run?

### Phase 5 — First migration: top-3 Racket fire-fns to Zig (2 days)

Based on Phase 3's profile, port the top-3 Racket fire-fns to Zig:
- Likely candidates: preduce-merge (called by every cell write), kernel-identity (β / eliminator bridges), make-app-fire wrapped (every dynamic β)
- Measure speedup; validate correctness via PReduce-lite test suite + differential gate

### Phase 6 — PIR + handoff (0.5 day)

PIR per `POST_IMPLEMENTATION_REVIEW.org`. Capture:
- Calibrated FFI numbers
- Validated end-to-end binary size + cold-start time
- Migration economics confirmed/refuted
- List of next-priority fire-fns to migrate (ordered by callback profile)

**Total: ~10 days. Single-developer track.**

---

## 10. Open questions

| # | Question | Resolution path |
|---|---|---|
| Q1 | What's the actual FFI overhead on this host? | Phase 0 microbench |
| Q2 | Does Racket-CS expose `function-ptr` cleanly for arbitrary Racket procs as C function pointers? | Phase 0 — `(function-ptr proc (_fun ...))` test. Standard Racket FFI; should work. |
| Q3 | How does `raco distribute` handle a Racket binary that depends on a separate `.so`? | Phase 0 / Phase 4 — likely just `(ffi-lib "libprologos-runtime")` with `.so` in the bundle's `lib/`. |
| Q4 | Cell-id allocation: kernel grows from 1024 to 8192 to N? Or HAMT-backed dynamic? | Phase 1 — start with growable flat array (10x current), evaluate HAMT later. |
| Q5 | What about Racket's GC interacting with cells holding handles to Racket objects? | Phase 2 — use Racket-managed vector with index-based handles (no GC interaction). |
| Q6 | Multi-thread BSP integration with Racket callbacks? | Defer to Sprint D + future hybrid-multi-thread design. v1 is single-threaded. |
| Q7 | Stratum handlers (PU, NAF, retraction) — how do they cross the seam? | Phase 2/3 — `prologos_set_round_callback` API gives Zig a hook to invoke Racket between rounds. Stratum handlers stay in Racket. |
| Q8 | What about ATMS speculation / fork-on-union — those need network forking? | Defer to a kernel-PU+hybrid integration design. The kernel-PU work (separate doc) is the unifying primitive; this hybrid runtime composes with it. |
| Q9 | Long-running networks (REPL): handle GC strategy? | Defer; v1 is one-shot. Future: per-call handle-table reset, or explicit release API. |
| Q10 | Where do `.prologos` library files live in the bundle? | Standard Racket convention: `share/<collection>/lib/`. Loaded via `process-file` lookup. |
| Q11 | Compatibility with the LLVM lowering track? | Compatible — the LLVM track produces standalone binaries; the hybrid track produces Racket-bundled binaries. They share the kernel ABI. Future convergence: LLVM-compiled fire-fns linked into the hybrid kernel as native fire-fns. |
| Q12 | Does this approach compose with kernel PUs? | Yes — kernel PUs add per-PU cell arenas + strata stack to the kernel. The hybrid runtime's API surface stays the same; PUs are an internal kernel concern. |

---

## 11. Comparison with alternatives + recommendation

| Path | Time-to-binary | Coverage | Runtime perf | Composes with |
|---|---|---|---|---|
| **Hybrid (Option C, this doc)** | **~10 days** | **100% (Racket fallback)** | **medium (FFI overhead, port hot tags)** | LLVM track, kernel PUs, Sprint D parallel |
| Pure-LLVM (PR #39 SH Series Track 1) | months | tier-limited | high | hybrid (eventual convergence) |
| Pure-Racket (status quo) | 0 days | 100% | low | n/a |

**Recommendation if user proceeds**: hybrid is the right next architectural step IF the goal is "ship a working binary that runs every Prologos program in less than two weeks." It buys time for the LLVM track to mature without blocking on it. The migration economics are observable (per-tag profiling already in the kernel). The FFI risk (R1) is real but mitigable.

If the goal is "ship a maximally fast binary," LLVM is the destination; hybrid is a stepping stone.

---

## 12. References

### Racket FFI + embedding
- [Racket FFI guide](https://docs.racket-lang.org/foreign/index.html)
- [`raco distribute`](https://docs.racket-lang.org/raco/exe-dist.html) — canonical distribution path
- [`raco demod`](https://docs.racket-lang.org/raco/demod.html) — module demodularization for static linking
- [Racket-CS embedding (Chez basis)](https://racket.discourse.group/t/embedding-racket-cs-as-a-library/) — community discussion
- [Chez Scheme C interface](https://cisco.github.io/ChezScheme/csug9.5/foreign.html)

### Existing Prologos infrastructure
- `runtime/prologos-runtime.zig` — 544 LOC single-threaded BSP kernel
- `runtime/prologos-hamt.zig` — 441 LOC CHAMP persistent map
- `racket/prologos/preduce.rkt` — 1390 LOC Racket-side reducer (PReduce-lite, just landed)
- `racket/prologos/llvm-lower.rkt` — Tier 0-2 LLVM IR lowering (PR #39 SH Series Track 1)

### Related design docs
- [SH Master Tracker](2026-04-30_SH_MASTER.md) — overall self-hosting roadmap
- [Concurrency Primitives](../research/2026-05-02_CONCURRENCY_PRIMITIVES_LLVM_SUBSTRATE.md) — Zig-side BSP scheduler design (Chase-Lev deque, EBR, futex-parked workers, mimalloc, per-(worker, PU) write logs) — directly composes with the hybrid runtime as the future Sprint D parallel substrate
- [Kernel Pocket Universes](2026-05-02_KERNEL_POCKET_UNIVERSES.md) — kernel-side scoped sub-networks; orthogonal to hybrid (the hybrid runtime hosts kernel PUs internally)
- [PReduce-lite Design](2026-05-02_PREDUCE_LITE_DESIGN.md) — Racket-side reducer that lives on the hybrid runtime's hot path
- [PReduce-lite PIR](2026-05-03_PREDUCE_LITE_PIR.md) — terminal state of the Racket-side reducer

### Engineering-discipline peers
- [TigerBeetle](https://github.com/tigerbeetle/tigerbeetle) — Zig systems work; deterministic simulation testing posture
- [Riposte](https://github.com/khoek/riposte), [DrRacket](https://racket-lang.org/) — Racket binary embedding precedents

---

**End of research note.**
