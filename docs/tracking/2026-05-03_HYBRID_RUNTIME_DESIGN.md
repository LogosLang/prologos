# Hybrid Racket-Zig Runtime — Design Doc (Stage 3)

**Date**: 2026-05-03
**Status**: Stage 3 design — implementation begins after user review
**Track**: SH (Self-Hosting) — alternate path to Track 1 LLVM lowering
**Branch**: `claude/prologos-layering-architecture-Pn8M9`

**Cross-references**:
- [Hybrid Runtime Stage 1 Research](../research/2026-05-03_HYBRID_RACKET_ZIG_RUNTIME.md) — origin; defines the four seam options + recommends Option C
- [Concurrency Primitives Substrate](../research/2026-05-02_CONCURRENCY_PRIMITIVES_LLVM_SUBSTRATE.md) — Sprint D parallel BSP composes with this runtime
- [Kernel Pocket Universes](2026-05-02_KERNEL_POCKET_UNIVERSES.md) — the kernel PU primitive is internal to the runtime
- [PReduce-lite Design](2026-05-02_PREDUCE_LITE_DESIGN.md) — the Racket-side reducer hosted on the hybrid runtime
- [PReduce-lite PIR](2026-05-03_PREDUCE_LITE_PIR.md) — terminal state of the Racket-side reducer
- [Low-PNet IR Track 2](2026-05-02_LOW_PNET_IR_TRACK2.md) — alternate full-LLVM lowering path; converges with this design
- `runtime/prologos-runtime.zig` — existing 544-line kernel, the FIRST kernel implementation
- `runtime/prologos-hamt.zig` — existing 441-line CHAMP map

---

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| 0 | FFI calibration on this host (Racket-CS 9.0 + Zig 0.13) | ✅ | forward 14-42 ns/call; callback 170-180 ns/call; R1 (FFI dominates) tractable |
| 1 | Extract shared core: `runtime/core/` with BSP scheduler + cell store + profiling | ⬜ | shared by both kernels |
| 2 | Refactor `prologos-runtime.zig` to use core (the FIRST kernel implementation) | ⬜ | preserve existing API + tests |
| 3 | Build hybrid kernel `prologos-runtime-hybrid.zig` (the SECOND implementation) — dynamic dispatch table + tagged-i64 cells + callback profiling + variable-arity propagators | ⬜ | |
| 4 | Build system: Makefile producing `libprologos-runtime.so` + `libprologos-runtime-hybrid.so` | ⬜ | |
| 5 | C tests for both kernels (positive: cell+prop+run-to-quiescence; negative: error path) | ⬜ | |
| 6 | Racket FFI bridge: `runtime-bridge.rkt` + `runtime/prop-network.rkt` shim | ⬜ | mirrors existing propagator.rkt API |
| 7 | Cell-value marshaling: tagged-i64 + Racket handle table | ⬜ | per-call lifetime; reset between (preduce e) calls |
| 8 | Host PReduce-lite on hybrid runtime; run all 90 unit tests + 2000-case differential gate | ⬜ | the validation gate |
| 9 | `raco distribute` packaging + launcher script | ⬜ | single-binary distributable |
| 10 | First migration: top-3 Racket fire-fns to Zig native (data-driven from Phase 8 callback profile) | ⬜ | |
| 11 | PIR | ⬜ | per POST_IMPLEMENTATION_REVIEW.org |

Status legend: ⬜ not started, 🔄 in progress, ✅ done, ⏸️ blocked.

**Estimated calendar**: ~10-12 days single-developer track. Phases 1-3 (~3 days) deliver the second kernel implementation. Phases 4-7 (~3 days) wire up the Racket side. Phase 8 (~1 day) validates correctness. Phases 9-10 (~2 days) deploy. Phase 11 (~0.5 day) PIR.

---

## 1. Summary

The hybrid runtime is a **second Zig kernel implementation** sitting alongside the existing `runtime/prologos-runtime.zig`. Both kernels share a factored core (`runtime/core/`) that owns the BSP scheduler, cell store primitives, worklist management, and profiling counters. The two implementations diverge on:

| Aspect | Original kernel | Hybrid kernel |
|---|---|---|
| Cell value type | flat `i64` | tagged `i64` (8-bit tag + 56-bit payload) |
| Fire-fn dispatch | hardcoded `switch (tag)` over ~10 known tags | dynamic table `tag → fn-ptr` registered at install time |
| Propagator shapes | 1-1, 2-1, 3-1 (fixed) | 1-1, 2-1, 3-1, **N-1** (variable arity) |
| Racket callback support | none | yes (callback fire-fns + per-tag callback profiling) |
| Consumer | LLVM-lowered standalone binaries (PR #39 SH Series Track 1) | Racket-Zig hybrid binaries (this design) |
| Cell capacity | fixed `MAX_CELLS=1024` | growable (start 1024, expand as needed) |

The two kernels are **complementary, not competing**. The original kernel ships as `libprologos-runtime.so` and links into LLVM-lowered programs. The hybrid kernel ships as `libprologos-runtime-hybrid.so` and is loaded by the Racket-Zig hybrid binary via `ffi-lib`. The factored core is built once and statically linked into both `.so` files.

**Calibrated FFI overhead** (Phase 0, this host): forward Racket → Zig is 14-42 ns/call; callback Zig → Racket is 170-180 ns/call. This is at the low end of expectations, making the hybrid approach economically viable: even un-migrated Racket-callback fire-fns cost ~180 ns vs Zig-native ~3 ns (a 60× gap, but in absolute terms ~180 ns × 10K fires = ~2 ms per program, not a dominant cost).

---

## 2. Factorization — what's shared, what's specific

### 2.1 Shared core (`runtime/core/`)

These modules live in `runtime/core/` and are compiled once into a static `.a` linked into both kernels:

| Module | LOC est | Purpose |
|---|---|---|
| `core/bsp.zig` | ~150 | BSP scheduler: `take_snapshot`, fire loop, `merge_pending_writes`, `swap_worklists`, fuel + run_ns timing |
| `core/cells.zig` | ~80 | Cell store ops parameterized by value type via Zig generic: `cell_alloc`, `cell_read`, `cell_write`, `cell_subscribe`. The cell value type is a comptime parameter; original passes `i64`, hybrid passes a tagged-i64 variant. |
| `core/worklist.zig` | ~60 | `schedule(pid)` + dedup via `in_worklist` + bounded ring of pid arrays |
| `core/profile.zig` | ~120 | `stat_*` counters, `now_ns` (CLOCK_MONOTONIC), per-tag profiling, JSON `print_stats` output |
| `core/format.zig` | ~50 | `buf_putc`/`buf_puts`/`buf_putu64` shared by both kernels' `print_stats` |
| **Total** | **~460** | factored from the existing 544-LOC kernel |

The core is **stateless modules with explicit state passed in** — Zig's generic functions + `comptime` allow both kernels to instantiate the same scheduler with different cell-value types and dispatch strategies. No code duplication; both kernels' `fire_against_snapshot` calls into shared `core.fire_loop()` which calls back into the kernel-specific dispatch function via a comptime-known pointer.

### 2.2 Original kernel-specific (`runtime/prologos-runtime.zig`)

After Phase 2 refactor:

| Component | LOC est | Notes |
|---|---|---|
| `cells: [MAX_CELLS]i64` flat array (the cell-value-type instantiation) | ~10 | parameterizes the core's cell store |
| Hardcoded `fire_dispatch_original(tag, shape, in_values) -> i64` | ~50 | the existing `switch (tag)` body, extracted to a function |
| Exported APIs: `prologos_cell_alloc/write/read`, `prologos_propagator_install_N_1`, `prologos_run_to_quiescence`, `prologos_get_stat`, etc. | ~80 | thin wrappers calling into core |
| **Total** | **~140** (down from 544) | majority of code moved to core |

### 2.3 Hybrid kernel-specific (`runtime/prologos-runtime-hybrid.zig`)

Net new code:

| Component | LOC est | Notes |
|---|---|---|
| `cells: [MAX_CELLS]i64` (tagged) — same flat-array layout, but each i64 is interpreted as 8-bit tag + 56-bit payload | ~30 | + `tag_box` / `tag_unbox` helpers |
| Dynamic dispatch table `fire_fn_by_tag: [N_TAGS]?*const fn` + `kind_by_tag: [N_TAGS]u8` | ~30 | KIND_KERNEL=0, KIND_RACKET_CALLBACK=1 |
| `fire_dispatch_hybrid(tag, shape, in_values) -> i64` | ~50 | looks up fn-ptr from table; calls native or invokes Racket callback |
| `prologos_register_fire_fn(tag, shape, kind, fn_ptr) -> u32` API | ~30 | populates the dispatch table |
| `prologos_propagator_install_n_1(tag, inputs[], num_inputs, out0)` | ~40 | variable-arity install with input-cid arena |
| Callback profiling: `stat_callback_ns_by_tag[N_TAGS]`, `stat_callbacks_by_tag[N_TAGS]` + `print_callback_summary` API | ~80 | mirrors existing per-tag profile; sorted-by-time output |
| Tagged-i64 marshaling APIs: `prologos_cell_box`, `prologos_cell_unbox`, `prologos_cell_value_kind` | ~30 | exposed for Racket-side handle table |
| Round-callback hook: `prologos_set_round_callback(fn_ptr)` | ~20 | invoked between BSP rounds; lets Racket run stratum handlers |
| **Total** | **~310** | new code |

**Total runtime/ size after refactor**: ~140 (original) + ~310 (hybrid) + ~460 (core) ≈ ~910 LOC vs ~544 today. Net +370 LOC, but the additional 370 buys us a fully-factored second kernel implementation.

---

## 3. Architecture diagram

```
                                     ┌──────────────────────────────────┐
                                     │ Racket Prologos compiler         │
                                     │   - parser.rkt, elaborator.rkt   │
                                     │   - typing-core.rkt, qtt.rkt     │
                                     │   - preduce.rkt (PReduce-lite)   │
                                     │   - lib/prologos/*.prologos      │
                                     └─────────────┬────────────────────┘
                                                   │
                                                   ▼
                              ┌──────────────────────────────────────────┐
                              │ runtime-bridge.rkt (NEW)                 │
                              │   ffi-lib "libprologos-runtime-hybrid"   │
                              │   define-rt prologos_cell_alloc, ...     │
                              └─────────────┬────────────────────────────┘
                                            │
                                            ▼
                                ┌──────────────────────────────────────────┐
                                │ libprologos-runtime-hybrid.so (NEW)      │
                                │                                          │
                                │   prologos-runtime-hybrid.zig            │
                                │     ┌────────────────────────────────┐   │
                                │     │ Hybrid-specific:               │   │
                                │     │   tagged-i64 cells             │   │
                                │     │   dynamic-dispatch fire-fns    │◀──┼── Racket callbacks
                                │     │   register_fire_fn API         │   │   via fn-ptr
                                │     │   variable-arity propagators   │   │
                                │     │   callback profiling           │   │
                                │     │   round-callback hook          │   │
                                │     └────────────────────────────────┘   │
                                │                  │                       │
                                │  ┌───────────────▼───────────────────┐   │
                                │  │ runtime/core/  (SHARED)           │   │
                                │  │   bsp.zig    cells.zig            │   │
                                │  │   worklist.zig    profile.zig     │   │
                                │  │   format.zig                      │   │
                                │  └───────────────────────────────────┘   │
                                │                  ▲                       │
                                │     ┌────────────┴───────────────┐       │
                                │     │ Original-specific:         │       │
                                │     │   flat-i64 cells           │       │
                                │     │   hardcoded switch dispatch│       │
                                │     │   1-1/2-1/3-1 only         │       │
                                │     └────────────────────────────┘       │
                                │                  │                       │
                                │              libprologos-runtime.so      │
                                │              (REFACTORED, BACKWARD-      │
                                │               COMPATIBLE)                │
                                └──────────────────────────────────────────┘
                                            ▲
                                            │
                              ┌─────────────┴────────────────────────────┐
                              │ LLVM-lowered standalone binaries          │
                              │   (PR #39 SH Series Track 1)              │
                              └──────────────────────────────────────────┘
```

Both `.so` files share the core static library via `zig build-lib` linking. The Racket-Zig hybrid binary loads `libprologos-runtime-hybrid.so`; LLVM-lowered standalones link statically against `libprologos-runtime.so` (or its `.o` equivalent today).

---

## 4. NTT model

Per workflow rule "NTT model REQUIRED for propagator designs," speculative NTT for the hybrid kernel:

```ntt
;; ===== Shared core =====

(propagator-network
  (:scheduler bsp
    (:cell-allocator core/cells.cell-alloc)
    (:scheduler-loop core/bsp.run-to-quiescence)
    (:profiler core/profile.stats)
    (:fuel-cell tropical-fuel)))     ;; tropical-quantale, future PPN 4C M2

;; ===== Original kernel =====
(kernel-instance original
  (:cell-value-type i64)
  (:dispatch (:hardcoded
    (:tag 0 :shape 1 :fire kernel-identity)
    (:tag 1 :shape 1 :fire kernel-int-neg)
    (:tag 2 :shape 1 :fire kernel-int-abs)
    (:tag 0 :shape 2 :fire kernel-int-add)
    ;; ... 7 more
    ))
  (:exports prologos_cell_alloc prologos_cell_write prologos_cell_read
            prologos_propagator_install_1_1 ... prologos_run_to_quiescence ...))

;; ===== Hybrid kernel =====
(kernel-instance hybrid
  (:cell-value-type tagged-i64)      ;; 8-bit tag + 56-bit payload
  (:dispatch (:dynamic
    (:table fire_fn_by_tag :capacity N_TAGS)
    (:registry prologos_register_fire_fn (tag shape kind fn-ptr))))
  (:propagator-shapes 1-1 2-1 3-1 N-1)
  (:profiling (:per-tag-fires t)
              (:per-tag-ns t)
              (:per-tag-callback-ns t)
              (:per-tag-callback-count t))
  (:hooks
    (:round-callback set_round_callback))
  (:cell-marshaling
    (:tagged-i64
      (:tag-int 0)
      (:tag-bool 1)
      (:tag-nat 2)
      (:tag-bot 3)
      (:tag-top 4)
      (:tag-racket-handle 5)
      ;; tags 6-255 reserved
      ))
  (:exports (... original APIs ... +
            prologos_register_fire_fn
            prologos_propagator_install_n_1
            prologos_cell_box prologos_cell_unbox prologos_cell_value_kind
            prologos_set_round_callback
            prologos_print_callback_summary)))
```

### NTT correspondence table

| NTT construct | Zig realization | Racket realization |
|---|---|---|
| `(:scheduler bsp ...)` | `core/bsp.zig run_to_quiescence` | `runtime-bridge.rkt prologos_run_to_quiescence` |
| `(:cell-allocator ...)` | `core/cells.cell_alloc<T>(comptime T)` | `(define-rt prologos_cell_alloc (_fun -> _uint32))` |
| `(:dispatch (:hardcoded ...))` | `switch (tag)` body in original kernel | n/a — original kernel doesn't expose dispatch to Racket |
| `(:dispatch (:dynamic (:table ...)))` | `fire_fn_by_tag: [N_TAGS]?*const fn` array | `(define-rt prologos_register_fire_fn ...)` |
| `(:cell-value-type tagged-i64)` | `fn box_int(v: i64) i64 { return v; }`, `fn box_bool(v: bool) i64 { return @bitCast(@as(u64, 1) << 56 \| @as(u64, @intFromBool(v))); }`, etc. | per-call handle table; tag 5 = handle index |
| `(:propagator-shapes ... N-1)` | `prologos_propagator_install_n_1(tag, inputs[], num_inputs, out0)` | `(define-rt prologos_propagator_install_n_1 (_fun ... -> _uint32))` |
| `(:hooks (:round-callback ...))` | `prologos_set_round_callback(fn_ptr)`; called between BSP rounds | wrap Racket fn as `function-ptr`, register at runtime init |
| `(:cell-marshaling (:tagged-i64 ...))` | `prologos_cell_box`, `prologos_cell_unbox`, `prologos_cell_value_kind` | per-call handle table; `box-racket-value` / `unbox-racket-handle` helpers |

### NTT gaps surfaced

1. **NTT today has no kernel-instance / shared-core syntax**. New: `(kernel-instance NAME ...)` + `(propagator-network (:scheduler ...))` separation. Recorded for future NTT track.

2. **NTT today has no dispatch-strategy declaration**. New: `(:dispatch (:hardcoded ...) | (:dynamic ...))`. Lets a kernel-instance declare its dispatch shape at compile time.

3. **NTT today has no cell-value-type comptime parameter**. The cell store is generic over value type; NTT needs a way to express this. New: `(:cell-value-type T)` clause.

These gaps are not blocking implementation — the Zig code uses Zig's `comptime` directly. The NTT model is architectural reference.

---

## 5. Concrete API surface (final)

### 5.1 Core (`runtime/core/`)

```zig
// core/bsp.zig
pub fn RunToQuiescence(comptime Cells: type, comptime FireDispatch: type) type {
    return struct {
        pub fn run(cells: *Cells, fire_dispatch: *FireDispatch) void {
            // BSP loop — see existing prologos-runtime.zig:356 for full body
        }
    };
}

// core/cells.zig
pub fn CellStore(comptime Value: type, comptime CAPACITY: u32) type {
    return struct {
        cells: [CAPACITY]Value,
        snapshot: [CAPACITY]Value,
        num_cells: u32,
        cell_subs: [CAPACITY][16]u32,
        cell_num_subs: [CAPACITY]u32,
        // ... methods: alloc, read, write, subscribe, take_snapshot
    };
}

// core/worklist.zig — bounded work queue with dedup
pub fn Worklist(comptime CAPACITY: u32) type { ... }

// core/profile.zig — counters, timings
pub const Profile = struct {
    stat_rounds: u64,
    stat_fires_total: u64,
    stat_fires_by_tag: [N_TAGS]u64,
    stat_writes_committed: u64,
    stat_writes_dropped: u64,
    stat_max_worklist: u64,
    stat_fuel_exhausted: u64,
    stat_run_ns: u64,
    stat_ns_by_tag: [N_TAGS]u64,
    profile_per_tag: bool,
    pub fn reset(self: *Profile) void { ... }
    pub fn print_json(self: *const Profile, num_cells: u32, num_props: u32) void { ... }
};
```

### 5.2 Original kernel (`runtime/prologos-runtime.zig` after refactor)

```zig
const core = @import("core/all.zig");

const Cells = core.cells.CellStore(i64, 1024);
var cells: Cells = .{};

fn fire_dispatch(tag: u32, shape: u32, in0: i64, in1: i64, in2: i64) i64 {
    // The existing switch (tag) body, extracted
}

const Runner = core.bsp.RunToQuiescence(Cells, @TypeOf(fire_dispatch));

export fn prologos_run_to_quiescence() void {
    Runner.run(&cells, fire_dispatch);
}
// ... other exports as thin wrappers
```

### 5.3 Hybrid kernel (`runtime/prologos-runtime-hybrid.zig`)

```zig
const core = @import("core/all.zig");

// Tagged-i64 cell value
const TaggedI64 = i64;  // top 8 bits = tag; bottom 56 = payload

const TAG_INT: u8 = 0;
const TAG_BOOL: u8 = 1;
const TAG_NAT: u8 = 2;
const TAG_BOT: u8 = 3;
const TAG_TOP: u8 = 4;
const TAG_RACKET_HANDLE: u8 = 5;

inline fn tag_of(v: TaggedI64) u8 {
    return @intCast(@as(u64, @bitCast(v)) >> 56);
}
inline fn payload_of(v: TaggedI64) i64 {
    return @bitCast(@as(u64, @bitCast(v)) & ((@as(u64, 1) << 56) - 1));
}
inline fn box(tag: u8, payload: i64) TaggedI64 {
    return @bitCast((@as(u64, tag) << 56) | (@as(u64, @bitCast(payload)) & ((@as(u64, 1) << 56) - 1)));
}

const Cells = core.cells.CellStore(TaggedI64, 1024);
var cells: Cells = .{};

// Dynamic dispatch
const FireFn1_1 = *const fn (TaggedI64) callconv(.C) TaggedI64;
const FireFn2_1 = *const fn (TaggedI64, TaggedI64) callconv(.C) TaggedI64;
const FireFn3_1 = *const fn (TaggedI64, TaggedI64, TaggedI64) callconv(.C) TaggedI64;
const FireFnN_1 = *const fn (u32, [*]const TaggedI64) callconv(.C) TaggedI64;

const KIND_KERNEL: u8 = 0;
const KIND_RACKET_CALLBACK: u8 = 1;

var fire_fn_1_1: [N_TAGS]?FireFn1_1 = [_]?FireFn1_1{null} ** N_TAGS;
var fire_fn_2_1: [N_TAGS]?FireFn2_1 = [_]?FireFn2_1{null} ** N_TAGS;
var fire_fn_3_1: [N_TAGS]?FireFn3_1 = [_]?FireFn3_1{null} ** N_TAGS;
var fire_fn_n_1: [N_TAGS]?FireFnN_1 = [_]?FireFnN_1{null} ** N_TAGS;
var fire_kind: [N_TAGS]u8 = [_]u8{0} ** N_TAGS;

export fn prologos_register_fire_fn(
    tag: u32, shape: u32, kind: u32, fn_ptr: *const anyopaque,
) u32 {
    if (tag >= N_TAGS) return 1;
    fire_kind[tag] = @intCast(kind);
    switch (shape) {
        1 => fire_fn_1_1[tag] = @ptrCast(@alignCast(fn_ptr)),
        2 => fire_fn_2_1[tag] = @ptrCast(@alignCast(fn_ptr)),
        3 => fire_fn_3_1[tag] = @ptrCast(@alignCast(fn_ptr)),
        4 => fire_fn_n_1[tag] = @ptrCast(@alignCast(fn_ptr)),
        else => return 2,
    }
    return 0;
}

fn fire_dispatch(tag: u32, shape: u32, ...) TaggedI64 {
    const t0: u64 = if (profile_per_tag) now_ns() else 0;
    const result = switch (shape) {
        1 => fire_fn_1_1[tag].?(in0),
        2 => fire_fn_2_1[tag].?(in0, in1),
        3 => fire_fn_3_1[tag].?(in0, in1, in2),
        4 => fire_fn_n_1[tag].?(num_inputs, inputs_ptr),
        else => unreachable,
    };
    if (profile_per_tag) {
        const t1 = now_ns();
        const dt = t1 - t0;
        stat_ns_by_tag[tag] += dt;
        if (fire_kind[tag] == KIND_RACKET_CALLBACK) {
            stat_callback_ns_by_tag[tag] += dt;
            stat_callbacks_by_tag[tag] += 1;
        }
    }
    return result;
}

// ... other exports
```

### 5.4 Racket bridge (`racket/prologos/runtime-bridge.rkt`)

```racket
#lang racket/base

(require ffi/unsafe ffi/unsafe/define)

(define-ffi-definer define-rt
  (ffi-lib "libprologos-runtime-hybrid"))

(define-rt prologos_cell_alloc            (_fun -> _uint32))
(define-rt prologos_cell_write             (_fun _uint32 _int64 -> _void))
(define-rt prologos_cell_read              (_fun _uint32 -> _int64))
(define-rt prologos_propagator_install_1_1 (_fun _uint32 _uint32 _uint32 -> _uint32))
(define-rt prologos_propagator_install_2_1 (_fun _uint32 _uint32 _uint32 _uint32 -> _uint32))
(define-rt prologos_propagator_install_3_1 (_fun _uint32 _uint32 _uint32 _uint32 _uint32 -> _uint32))
(define-rt prologos_propagator_install_n_1 (_fun _uint32 (_array _uint32 _) _uint32 _uint32 -> _uint32))
(define-rt prologos_run_to_quiescence       (_fun -> _void))
(define-rt prologos_register_fire_fn        (_fun _uint32 _uint32 _uint32 _pointer -> _uint32))
(define-rt prologos_cell_box                (_fun _uint64 -> _int64))
(define-rt prologos_cell_unbox              (_fun _int64 -> _uint64))
(define-rt prologos_cell_value_kind         (_fun _int64 -> _uint32))
(define-rt prologos_set_round_callback      (_fun _pointer -> _void))
(define-rt prologos_get_stat                (_fun _uint32 -> _uint64))
(define-rt prologos_print_callback_summary  (_fun -> _void))

(provide (all-defined-out))
```

---

## 6. Cell-value marshaling — the load-bearing engineering

Per § 5 of the research note. Recap: tagged-i64 with Racket-managed handle table, per-call lifetime.

### 6.1 Tag layout (8-bit tag, 56-bit payload)

| Tag | Meaning | Payload |
|---|---|---|
| 0 | Int (signed) | 56-bit signed int (range ±2⁵⁵) |
| 1 | Bool | 0 or 1 |
| 2 | Nat | 56-bit unsigned int |
| 3 | Bot (preduce-bot) | unused |
| 4 | Top (preduce-top, contradiction) | unused |
| 5 | Racket handle | index into Racket-managed handle table |
| 6 | Pair handle (preduce-pair, fst-cid + snd-cid co-located) | composite — see § 6.3 |
| 7-255 | Reserved | future use |

### 6.2 Range constraint on Int

Tag 0's payload is 56 bits (signed). Prologos `expr-int n` payloads are arbitrary-precision in principle but practically i64. **Constraint**: ints whose magnitude exceeds 2⁵⁵ must use tag 5 (Racket handle). The `prologos_cell_box` helper detects overflow and routes to handle-table.

In practice, all PReduce-lite test programs use small ints (≤32 bits magnitude); the range constraint only bites for unusual programs.

### 6.3 Pair packing optimization (defer)

PReduce-lite pairs carry two cell-ids. Tag 6 packs both 28-bit cell-ids into the 56-bit payload (28 bits each = 256M cells, plenty). Avoids handle-table indirection for the common pair case.

Defer this optimization to a Phase 7b sub-phase if profile shows pair-projection is hot. Initial impl uses tag 5 for all pairs.

### 6.4 Handle table (Racket side)

```racket
(define HANDLE-TABLE-SIZE 4096)
(define handle-table (make-vector HANDLE-TABLE-SIZE #f))
(define handle-next 0)

(define (box-racket-value v)
  ;; Returns a handle-tagged i64 for the Racket value v.
  (define i handle-next)
  (when (>= i HANDLE-TABLE-SIZE)
    (error 'box-racket-value "handle table full"))
  (vector-set! handle-table i v)
  (set! handle-next (+ i 1))
  (prologos_cell_box i))   ;; Zig packs (5 << 56) | i

(define (unbox-racket-handle handle-tagged-i64)
  (define i (prologos_cell_unbox handle-tagged-i64))
  (vector-ref handle-table i))

(define (reset-handle-table!)
  ;; Called at start of each (preduce e) invocation.
  (vector-fill! handle-table #f)
  (set! handle-next 0))
```

The handle table:
- Has fixed size (4096; expandable if profile shows pressure)
- Resets per `(preduce e)` call (one-shot reduction model; long-lived networks defer to future work)
- Stores Racket values directly (no GC interaction concerns; vector entries are GC-tracked normally)
- Is single-threaded per Racket-CS (the runtime is single-threaded; Sprint D parallel BSP is post-MVP)

---

## 7. Per-phase implementation protocol

Mirrors PReduce-lite's protocol (per workflow rule on conversational implementation cadence + per-phase commit/push):

1. **Plan**: re-read this design doc + the research note's relevant section; write a phase mini-plan in the commit message.
2. **Implement**: code per the plan. For each Zig file change, run `zig build-lib` to verify compilation.
3. **Validate**: per-phase test gate. Phases 1-3 (kernel work) gated by C tests; Phase 6+ (Racket bridge) gated by Racket-side tests; Phase 8 is the load-bearing differential gate.
4. **Commit + push**: phase isn't done until pushed; tracker updated with commit hash.
5. **If failure**: diagnose + fix in same phase. **If sticky** (3+ failed attempts): redesign the phase, write a delta in this doc, user-checkpoint before continuing.
6. **Next phase** starts only after current is ✅.

---

## 8. Validation strategy

### 8.1 Per-phase gates

| Phase | Gate |
|---|---|
| 1 | Core compiles; unit test for each module (cells.zig, bsp.zig, etc.) — Zig `zig test` |
| 2 | Original kernel after refactor passes existing C tests (`test-bsp-feedback.c`, `test-bsp-stats.c`) |
| 3 | Hybrid kernel compiles; new C test for register_fire_fn + N-arity install + run-to-quiescence with native fire-fn |
| 5 | C tests for both kernels pass; both `.so` files load cleanly via `dlopen` from a smoke binary |
| 6 | Racket-side smoke test: alloc cell via FFI, read/write, run-to-quiescence with one Racket-callback fire-fn |
| 7 | Tagged-i64 round-trip test (Racket → Zig → Racket via handle table; preserve identity) |
| 8 | **Load-bearing**: PReduce-lite hosted on hybrid runtime → all 90 unit tests pass + 2000-case differential gate runs with 0 mismatches. Same as on Racket-side runtime today. |
| 9 | `raco distribute` produces a bundle; bundle runs on a clean Linux container; factorial-iter outputs 120 |
| 10 | Top-3 migrated fire-fns: callback-ns-by-tag drops; total wall time drops |

### 8.2 The headline correctness gate

**Phase 8** is the gate that proves the entire design works: the same PReduce-lite tests that pass today on the Racket-side propagator network must pass identically when hosted on the hybrid kernel. Specifically:

```bash
# Today (PReduce-lite on Racket propagator.rkt):
cd racket/prologos
raco test tests/test-preduce-phase{1,2,3,4,5,6,10,11b,14b,15-differential,15b-differential}.rkt
# → 90 tests + 2000 differential cases, 0 failures

# Phase 8 gate (PReduce-lite on hybrid Zig runtime):
PROLOGOS_RUNTIME=hybrid raco test tests/test-preduce-phase*.rkt
# → identical: 90 tests + 2000 differential, 0 failures
```

The `PROLOGOS_RUNTIME=hybrid` env var (or a parameter `current-runtime-impl`) toggles between the existing Racket prop-network and the hybrid Zig kernel. Tests run on both; results must match exactly.

---

## 9. Decision points to resolve before implementation

| # | Question | Default / lean |
|---|---|---|
| 1 | Implement Phase 1 core factorization in-place (modify `prologos-runtime.zig` to import from `core/`) or build `core/` first then refactor as Phase 2? | **Build core first**, refactor original second. Lower risk; original keeps working until we explicitly switch it over. |
| 2 | Use Zig's `comptime` for cell-value-type genericity, or accept some duplication? | **Use comptime**. Zig generic types via `fn CellStore(comptime T) type` is idiomatic; minimal cost. |
| 3 | Single `.so` (compile-time switch between original/hybrid) or two `.so` files? | **Two `.so`**. They serve different consumers; runtime selection via `ffi-lib` path. |
| 4 | Phase 7 handle table: per-call reset (simpler) or explicit release API (more flexible)? | **Per-call reset for v1**. Explicit release deferred to long-lived-networks future work. |
| 5 | Phase 8 differential gate: compare against Racket prop-network (current) only, or also against `nf` (PReduce-lite design's gate)? | **Both**. Add a third differential leg: `(preduce-via-hybrid e) ≡ (preduce e) ≡ (nf e)`. |
| 6 | First-migration target (Phase 10): pick top-3 from Phase 8 callback profile, or pre-commit to specific fire-fns now? | **Profile-driven**. Pre-commit risks porting low-volume fire-fns. |
| 7 | Multi-thread BSP (Sprint D): part of this track or separate? | **Separate**. Sprint D is its own track per the concurrency-substrate doc; this track is single-threaded. |
| 8 | Cell capacity: keep fixed `MAX_CELLS=1024`, or grow at install time? | **Grow on overflow**. Real PReduce-lite programs already exceed 1024 cells (factorial-iter 1 5 ≈ 100s of cells; longer recursions blow past 1024). Implement growable-arena with doubling. |

User reviews and either confirms defaults or overrides. Defaults assume "ship the cheapest path that doesn't paint into a corner."

---

## 10. Adversarial framing (Vision Alignment Gate)

| Catalogue | Challenge |
|---|---|
| ✓ Two-kernel design with shared core | Could be one kernel with compile-time flags? — *No: comptime flags would couple the original and hybrid bodies; clean separation costs ~370 LOC and gives independent evolution.* |
| ✓ Hybrid is additive (new file, new `.so`) | Does it touch the existing kernel? — *Phase 2 refactors the existing kernel to use the shared core. This is invasive but necessary; preserved behavior validated via existing C tests as the gate.* |
| ✓ Tagged-i64 cells | Does this introduce performance cost vs flat i64? — *One bit-extract + branch per cell-read for non-int values. ~0.5 ns per access. Native int access (tag 0) is the same as before since tag 0 + small payload = the i64 value as-is for positive numbers.* |
| ✓ Per-call handle table reset | Does this leak memory across long-running programs? — *Per-call reset means handles are released between (preduce e) calls. v1 targets one-shot reductions; long-lived programs need a future explicit-release API.* |
| ✓ Forward FFI 14-42 ns, callback 170 ns | Are these numbers from a representative workload, or microbench-only? — *Microbench. Real workloads will have additional indirection (Racket fire-fn body, cell reads via FFI). Per-tag profiling Phase 10 is the truth-test.* |
| ✓ "Continue to LLVM track in parallel" | Are we sure this doesn't bifurcate effort? — *The two tracks share the kernel ABI (cell-id ↔ i64). Hybrid uses tagged-i64 internally but exposes the same FFI signatures. LLVM track and hybrid track converge: LLVM-compiled fire-fns can register into the hybrid dispatch table.* |
| ✓ Decision-point #6 "profile-driven" | Is this honest, or rationalization for not picking now? — *Honest: PReduce-lite's hot fire-fns aren't obvious from inspection. preduce-merge fires per cell write; make-app-fire per dynamic β; make-natrec-fire per natrec step. The profile will tell us the actual ratio.* |
| ✓ "Single-threaded for v1" | Is parallel BSP integration architectural debt? — *Named. Sprint D is its own track. The hybrid kernel's APIs (round-callback, handle table) are designed to be thread-compatible, but the implementation is single-threaded.* |

---

## 11. References

### Stage 1 origin
- [Hybrid Runtime Stage 1 Research](../research/2026-05-03_HYBRID_RACKET_ZIG_RUNTIME.md)

### Composing tracks
- [Concurrency Primitives Substrate](../research/2026-05-02_CONCURRENCY_PRIMITIVES_LLVM_SUBSTRATE.md) — Sprint D parallel BSP design
- [Kernel Pocket Universes](2026-05-02_KERNEL_POCKET_UNIVERSES.md) — orthogonal; PUs are an internal kernel concern
- [PReduce-lite Design](2026-05-02_PREDUCE_LITE_DESIGN.md) — the consumer
- [PReduce-lite PIR](2026-05-03_PREDUCE_LITE_PIR.md) — terminal state of the consumer

### Existing infrastructure
- `runtime/prologos-runtime.zig` — 544 LOC, the original kernel
- `runtime/prologos-hamt.zig` — 441 LOC, CHAMP map (used by future cell-store HAMT integration)
- `runtime/test-bsp-feedback.c`, `runtime/test-bsp-stats.c` — existing C tests for the original kernel
- `runtime/ffi-bench.zig` — Phase 0 calibration source
- `/tmp/ffi-bench.rkt` — Phase 0 calibration runner

### Methodology
- [POST_IMPLEMENTATION_REVIEW.org](principles/POST_IMPLEMENTATION_REVIEW.org) — for Phase 11 PIR
- [DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) — Stage 3 design discipline
- `.claude/rules/on-network.md` — design mantra
- `.claude/rules/propagator-design.md` — propagator design checklist

---

**End of design doc. Awaiting user confirmation on decision points 1-8 before Phase 1 implementation begins.**
