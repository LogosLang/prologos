// prologos-runtime-hybrid.zig — second kernel implementation.
//
// Hybrid Racket-Zig runtime: same BSP scheduler as the original kernel,
// but with three architectural extensions for hosting Racket-side code:
//
//   1. Tagged i64 cells (8-bit tag + 56-bit payload), so cells can hold
//      Int / Bool / Nat / Bot / Top / RacketHandle without changing the
//      kernel's underlying flat-array layout.
//
//   2. Dynamic fire-fn dispatch: rather than a hardcoded `switch (tag)`,
//      the kernel exposes `prologos_register_fire_fn(tag, shape, kind,
//      fn_ptr)` so Racket can register both kernel-native fire-fns
//      (Zig-compiled) and Racket-callback fire-fns (slow path) at
//      runtime.
//
//   3. Variable-arity propagators (1-1, 2-1, 3-1, N-1) — N-1 supports
//      higher-arity rules (e.g., expr-reduce dispatching across N
//      constructor arms) without repeating the install API per shape.
//
// Built as `libprologos-runtime-hybrid.so` and loaded by the Racket-Zig
// hybrid binary via `(ffi-lib "libprologos-runtime-hybrid")`.
//
// Profiling: total fire ns/count by tag (existing) + callback fire
// ns/count by tag (new). The callback profile drives migration triage:
// after a representative workload run, sort tags by callback_ns
// descending; the top-N are the next migration targets (port to
// kernel-native).
//
// Cross-references:
//   docs/tracking/2026-05-03_HYBRID_RUNTIME_DESIGN.md — design doc
//   docs/research/2026-05-03_HYBRID_RACKET_ZIG_RUNTIME.md — Stage 1 research
//   runtime/prologos-runtime.zig — first kernel (LLVM-lowering consumer)
//
// Pinned to Zig 0.13.0.

const cells = @import("core/cells.zig");
const profile = @import("core/profile.zig");
const format = @import("core/format.zig");

extern fn abort() noreturn;

// ============================================================
// Cell store + propagator state
// ============================================================

const MAX_CELLS: u32 = 4096;       // Phase 8 may grow this
const MAX_PROPS: u32 = 4096;
const MAX_INPUTS: u32 = 16;        // for variable-arity propagators

const CellStore = cells.CellStore(i64, MAX_CELLS);
var store: CellStore = CellStore.init(0);

// Per-prop metadata. shape ∈ {1,2,3,N}; tag indexes the dispatch table.
const SHAPE_1_1: u32 = 1;
const SHAPE_2_1: u32 = 2;
const SHAPE_3_1: u32 = 3;
const SHAPE_N_1: u32 = 4;

var prop_shape: [MAX_PROPS]u32 = undefined;
var prop_tags:  [MAX_PROPS]u32 = undefined;
var prop_in0:   [MAX_PROPS]u32 = undefined;
var prop_in1:   [MAX_PROPS]u32 = undefined;
var prop_in2:   [MAX_PROPS]u32 = undefined;
var prop_out:   [MAX_PROPS]u32 = undefined;

// For SHAPE_N_1 propagators: input cid arrays packed into a flat arena.
// prop_in_arena_off[pid] is the start offset; prop_in_arena_len[pid] the count.
var prop_in_arena: [MAX_PROPS * MAX_INPUTS]u32 = undefined;
var prop_in_arena_off: [MAX_PROPS]u32 = undefined;
var prop_in_arena_len: [MAX_PROPS]u32 = undefined;
var prop_in_arena_used: u32 = 0;

var num_props: u32 = 0;

// ============================================================
// Tagged-i64 cell value layout
// ============================================================
//
// 64 bits = [8-bit tag][56-bit payload].
// payload sign-extends for tag 0 (Int).

pub const TAG_INT: u8 = 0;
pub const TAG_BOOL: u8 = 1;
pub const TAG_NAT: u8 = 2;
pub const TAG_BOT: u8 = 3;
pub const TAG_TOP: u8 = 4;
pub const TAG_HANDLE: u8 = 5;

inline fn tag_of(v: i64) u8 {
    return @intCast(@as(u64, @bitCast(v)) >> 56);
}

inline fn payload_of(v: i64) i64 {
    // Sign-extend the 56-bit payload.
    const u = @as(u64, @bitCast(v)) & ((@as(u64, 1) << 56) - 1);
    if ((u >> 55) != 0) {
        // Negative: set high 8 bits.
        return @bitCast(u | (@as(u64, 0xFF) << 56));
    }
    return @bitCast(u);
}

inline fn box(comptime tag: u8, payload: i64) i64 {
    const masked = @as(u64, @bitCast(payload)) & ((@as(u64, 1) << 56) - 1);
    return @bitCast((@as(u64, tag) << 56) | masked);
}

// Marshaling APIs exposed to Racket.
export fn prologos_cell_box_int(payload: i64) i64 {
    return box(TAG_INT, payload);
}

export fn prologos_cell_box_bool(payload: u8) i64 {
    return box(TAG_BOOL, @intCast(payload & 1));
}

export fn prologos_cell_box_nat(payload: i64) i64 {
    return box(TAG_NAT, payload);
}

export fn prologos_cell_box_handle(handle_index: u64) i64 {
    return box(TAG_HANDLE, @bitCast(handle_index));
}

export fn prologos_cell_box_bot() i64 {
    return box(TAG_BOT, 0);
}

export fn prologos_cell_box_top() i64 {
    return box(TAG_TOP, 0);
}

export fn prologos_cell_value_kind(boxed: i64) u32 {
    return tag_of(boxed);
}

export fn prologos_cell_unbox_payload(boxed: i64) i64 {
    return payload_of(boxed);
}

// ============================================================
// Dynamic fire-fn dispatch table
// ============================================================

const N_TAGS: u32 = profile.N_TAGS;

const FireFn1_1 = *const fn (i64) callconv(.C) i64;
const FireFn2_1 = *const fn (i64, i64) callconv(.C) i64;
const FireFn3_1 = *const fn (i64, i64, i64) callconv(.C) i64;
const FireFnN_1 = *const fn (u32, [*]const i64) callconv(.C) i64;

pub const KIND_KERNEL: u8 = 0;
pub const KIND_RACKET_CALLBACK: u8 = 1;

// Per-shape, per-tag dispatch tables. null = unregistered (firing
// would trap).
var fire_fn_1_1: [N_TAGS]?FireFn1_1 = [_]?FireFn1_1{null} ** N_TAGS;
var fire_fn_2_1: [N_TAGS]?FireFn2_1 = [_]?FireFn2_1{null} ** N_TAGS;
var fire_fn_3_1: [N_TAGS]?FireFn3_1 = [_]?FireFn3_1{null} ** N_TAGS;
var fire_fn_n_1: [N_TAGS]?FireFnN_1 = [_]?FireFnN_1{null} ** N_TAGS;

// Per-tag, per-shape kind (for callback profiling). KIND_KERNEL by default.
var fire_kind_1_1: [N_TAGS]u8 = [_]u8{KIND_KERNEL} ** N_TAGS;
var fire_kind_2_1: [N_TAGS]u8 = [_]u8{KIND_KERNEL} ** N_TAGS;
var fire_kind_3_1: [N_TAGS]u8 = [_]u8{KIND_KERNEL} ** N_TAGS;
var fire_kind_n_1: [N_TAGS]u8 = [_]u8{KIND_KERNEL} ** N_TAGS;

// Returns 0 on success, error code otherwise.
export fn prologos_register_fire_fn(
    tag: u32, shape: u32, kind: u32, fn_ptr: *const anyopaque,
) u32 {
    if (tag >= N_TAGS) return 1;
    const k: u8 = @intCast(kind);
    switch (shape) {
        SHAPE_1_1 => {
            fire_fn_1_1[tag] = @ptrCast(@alignCast(fn_ptr));
            fire_kind_1_1[tag] = k;
        },
        SHAPE_2_1 => {
            fire_fn_2_1[tag] = @ptrCast(@alignCast(fn_ptr));
            fire_kind_2_1[tag] = k;
        },
        SHAPE_3_1 => {
            fire_fn_3_1[tag] = @ptrCast(@alignCast(fn_ptr));
            fire_kind_3_1[tag] = k;
        },
        SHAPE_N_1 => {
            fire_fn_n_1[tag] = @ptrCast(@alignCast(fn_ptr));
            fire_kind_n_1[tag] = k;
        },
        else => return 2,
    }
    return 0;
}

// ============================================================
// Built-in kernel fire-fns (auto-registered at init)
// ============================================================
//
// These mirror the original kernel's hardcoded set so simple programs
// (int arithmetic) run fast without Racket callbacks.

fn kernel_identity(a: i64) callconv(.C) i64 { return a; }
fn kernel_int_neg(a: i64) callconv(.C) i64 {
    return box(TAG_INT, -payload_of(a));
}
fn kernel_int_abs(a: i64) callconv(.C) i64 {
    const p = payload_of(a);
    return box(TAG_INT, if (p < 0) -p else p);
}

fn kernel_int_add(a: i64, b: i64) callconv(.C) i64 {
    return box(TAG_INT, payload_of(a) + payload_of(b));
}
fn kernel_int_sub(a: i64, b: i64) callconv(.C) i64 {
    return box(TAG_INT, payload_of(a) - payload_of(b));
}
fn kernel_int_mul(a: i64, b: i64) callconv(.C) i64 {
    return box(TAG_INT, payload_of(a) * payload_of(b));
}
fn kernel_int_div(a: i64, b: i64) callconv(.C) i64 {
    return box(TAG_INT, @divTrunc(payload_of(a), payload_of(b)));
}
fn kernel_int_eq(a: i64, b: i64) callconv(.C) i64 {
    return box(TAG_BOOL, if (payload_of(a) == payload_of(b)) 1 else 0);
}
fn kernel_int_lt(a: i64, b: i64) callconv(.C) i64 {
    return box(TAG_BOOL, if (payload_of(a) < payload_of(b)) 1 else 0);
}
fn kernel_int_le(a: i64, b: i64) callconv(.C) i64 {
    return box(TAG_BOOL, if (payload_of(a) <= payload_of(b)) 1 else 0);
}

fn kernel_select(c: i64, t: i64, e: i64) callconv(.C) i64 {
    return if (payload_of(c) != 0) t else e;
}

// Tag indexing: 0=identity, 1=neg, 2=abs (shape 1)
//               0=add, 1=sub, 2=mul, 3=div, 4=eq, 5=lt, 6=le (shape 2)
//               0=select (shape 3)
fn register_built_ins() void {
    fire_fn_1_1[0] = kernel_identity;
    fire_fn_1_1[1] = kernel_int_neg;
    fire_fn_1_1[2] = kernel_int_abs;
    fire_fn_2_1[0] = kernel_int_add;
    fire_fn_2_1[1] = kernel_int_sub;
    fire_fn_2_1[2] = kernel_int_mul;
    fire_fn_2_1[3] = kernel_int_div;
    fire_fn_2_1[4] = kernel_int_eq;
    fire_fn_2_1[5] = kernel_int_lt;
    fire_fn_2_1[6] = kernel_int_le;
    fire_fn_3_1[0] = kernel_select;
}

var initialized: bool = false;

fn ensure_init() void {
    if (initialized) return;
    register_built_ins();
    initialized = true;
}

// ============================================================
// Cell + propagator API (exported)
// ============================================================

export fn prologos_cell_alloc() u32 {
    ensure_init();
    return store.alloc();
}

// Direct cell write — emits boxed value (already tagged). Writers
// from Racket pre-box via prologos_cell_box_*. The kernel doesn't
// validate tag bits.
export fn prologos_cell_write(id: u32, value: i64) void {
    if (store.write_unchecked(id, value)) {
        prof.writes_committed += 1;
        var i: u32 = 0;
        while (i < store.num_subs(id)) : (i += 1) {
            schedule(store.sub_at(id, i));
        }
    } else {
        prof.writes_dropped += 1;
    }
}

export fn prologos_cell_read(id: u32) i64 {
    return store.read(id);
}

// Snapshot-read: returns the cell value from the current round's
// snapshot (taken at the start of the BSP round). Native fire-fns
// already read from snapshot via store.read_snapshot; this export
// gives the same view to Racket-side callback fire-fns. Required
// for BSP correctness — see 2026-05-05_HYBRID_KERNEL_CALLBACK_BSP_BUG.md
// § REMAINING.
export fn prologos_cell_read_snapshot(id: u32) i64 {
    return store.read_snapshot(id);
}

fn subscribe(cid: u32, pid: u32) void {
    store.subscribe(cid, pid);
}

export fn prologos_propagator_install_1_1(tag: u32, in0: u32, out0: u32) u32 {
    ensure_init();
    if (num_props >= MAX_PROPS) @panic("hybrid kernel: MAX_PROPS exceeded in install_1_1 (raise MAX_PROPS in prologos-runtime-hybrid.zig)");
    const pid = num_props;
    prop_shape[pid] = SHAPE_1_1;
    prop_tags[pid]  = tag;
    prop_in0[pid]   = in0;
    prop_out[pid]   = out0;
    num_props += 1;
    subscribe(in0, pid);
    schedule(pid);
    return pid;
}

export fn prologos_propagator_install_2_1(tag: u32, in0: u32, in1: u32, out0: u32) u32 {
    ensure_init();
    if (num_props >= MAX_PROPS) @panic("hybrid kernel: MAX_PROPS exceeded in install_2_1");
    const pid = num_props;
    prop_shape[pid] = SHAPE_2_1;
    prop_tags[pid]  = tag;
    prop_in0[pid]   = in0;
    prop_in1[pid]   = in1;
    prop_out[pid]   = out0;
    num_props += 1;
    subscribe(in0, pid);
    subscribe(in1, pid);
    schedule(pid);
    return pid;
}

export fn prologos_propagator_install_3_1(tag: u32, in0: u32, in1: u32, in2: u32, out0: u32) u32 {
    ensure_init();
    if (num_props >= MAX_PROPS) @panic("hybrid kernel: MAX_PROPS exceeded in install_3_1");
    const pid = num_props;
    prop_shape[pid] = SHAPE_3_1;
    prop_tags[pid]  = tag;
    prop_in0[pid]   = in0;
    prop_in1[pid]   = in1;
    prop_in2[pid]   = in2;
    prop_out[pid]   = out0;
    num_props += 1;
    subscribe(in0, pid);
    subscribe(in1, pid);
    subscribe(in2, pid);
    schedule(pid);
    return pid;
}

export fn prologos_propagator_install_n_1(
    tag: u32, inputs: [*]const u32, num_inputs: u32, out0: u32,
) u32 {
    ensure_init();
    if (num_props >= MAX_PROPS) @panic("hybrid kernel: MAX_PROPS exceeded in install_n_1");
    if (num_inputs > MAX_INPUTS) @panic("hybrid kernel: MAX_INPUTS exceeded in install_n_1 (raise MAX_INPUTS)");
    if (prop_in_arena_used + num_inputs > prop_in_arena.len) @panic("hybrid kernel: prop_in_arena exhausted in install_n_1");
    const pid = num_props;
    prop_shape[pid] = SHAPE_N_1;
    prop_tags[pid]  = tag;
    prop_in_arena_off[pid] = prop_in_arena_used;
    prop_in_arena_len[pid] = num_inputs;
    prop_out[pid] = out0;
    num_props += 1;
    var i: u32 = 0;
    while (i < num_inputs) : (i += 1) {
        prop_in_arena[prop_in_arena_used + i] = inputs[i];
        subscribe(inputs[i], pid);
    }
    prop_in_arena_used += num_inputs;
    schedule(pid);
    return pid;
}

// ============================================================
// BSP scheduler — same shape as original kernel but with dynamic
// dispatch instead of hardcoded switch
// ============================================================

var prof: profile.Profile = .{};
var cb_prof: profile.CallbackProfile = .{};

var worklist:      [MAX_PROPS]u32 = undefined;
var worklist_len:  u32 = 0;
var next_worklist: [MAX_PROPS]u32 = undefined;
var next_worklist_len: u32 = 0;
var in_worklist: [MAX_PROPS]u8 = [_]u8{0} ** MAX_PROPS;

var pending_cid: [MAX_PROPS]u32 = undefined;
var pending_val: [MAX_PROPS]i64 = undefined;
var pending_len: u32 = 0;

fn schedule(pid: u32) void {
    if (in_worklist[pid] != 0) return;
    in_worklist[pid] = 1;
    if (next_worklist_len >= MAX_PROPS) @panic("hybrid kernel: next_worklist overflow (>= MAX_PROPS scheduled in one round)");
    next_worklist[next_worklist_len] = pid;
    next_worklist_len += 1;
    if (next_worklist_len > prof.max_worklist) {
        prof.max_worklist = next_worklist_len;
    }
}

fn fire_against_snapshot(pid: u32) void {
    const shape = prop_shape[pid];
    const tag = prop_tags[pid];
    const out_cid = prop_out[pid];
    const t0: u64 = if (prof.profile_per_tag) profile.now_ns() else 0;
    // Read kind from the per-shape table BEFORE the switch dispatch so
    // its value is unambiguously visible after the switch (avoids any
    // Zig 0.13 switch-arm scoping confusion with var captures).
    const kind: u8 = switch (shape) {
        SHAPE_1_1 => fire_kind_1_1[tag],
        SHAPE_2_1 => fire_kind_2_1[tag],
        SHAPE_3_1 => fire_kind_3_1[tag],
        SHAPE_N_1 => fire_kind_n_1[tag],
        else => KIND_KERNEL,
    };
    const result: i64 = switch (shape) {
        SHAPE_1_1 => blk: {
            const fn_ptr = fire_fn_1_1[tag] orelse @panic("hybrid kernel: fire_fn_1_1 dispatch on uninstalled tag");
            break :blk fn_ptr(store.read_snapshot(prop_in0[pid]));
        },
        SHAPE_2_1 => blk: {
            const fn_ptr = fire_fn_2_1[tag] orelse abort();
            break :blk fn_ptr(
                store.read_snapshot(prop_in0[pid]),
                store.read_snapshot(prop_in1[pid]),
            );
        },
        SHAPE_3_1 => blk: {
            const fn_ptr = fire_fn_3_1[tag] orelse abort();
            break :blk fn_ptr(
                store.read_snapshot(prop_in0[pid]),
                store.read_snapshot(prop_in1[pid]),
                store.read_snapshot(prop_in2[pid]),
            );
        },
        SHAPE_N_1 => blk: {
            const fn_ptr = fire_fn_n_1[tag] orelse abort();
            const off = prop_in_arena_off[pid];
            const len = prop_in_arena_len[pid];
            var buf: [MAX_INPUTS]i64 = undefined;
            var i: u32 = 0;
            while (i < len) : (i += 1) {
                buf[i] = store.read_snapshot(prop_in_arena[off + i]);
            }
            break :blk fn_ptr(len, &buf);
        },
        else => abort(),
    };
    if (pending_len >= MAX_PROPS) abort();
    pending_cid[pending_len] = out_cid;
    pending_val[pending_len] = result;
    pending_len += 1;
    prof.fires_total += 1;
    if (tag < N_TAGS) {
        prof.fires_by_tag[tag] += 1;
        debug_pp_seen += if (prof.profile_per_tag) @as(u64, 1) else @as(u64, 0);
        debug_kind_at_fire = kind;
        debug_kind_eq_callback += if (kind == KIND_RACKET_CALLBACK) @as(u64, 1) else @as(u64, 0);
        if (prof.profile_per_tag) {
            const t1 = profile.now_ns();
            const dt = t1 - t0;
            prof.ns_by_tag[tag] += dt;
            if (kind == KIND_RACKET_CALLBACK) {
                cb_prof.callbacks_by_tag[tag] += 1;
                cb_prof.callback_ns_by_tag[tag] += dt;
                debug_inner_branch_taken += 1;
            }
        } else if (kind == KIND_RACKET_CALLBACK) {
            cb_prof.callbacks_by_tag[tag] += 1;
        }
    }
}
var debug_kind_eq_callback: u64 = 0;
var debug_inner_branch_taken: u64 = 0;
export fn prologos_debug_kind_eq_callback() u64 { return debug_kind_eq_callback; }
export fn prologos_debug_inner_branch_taken() u64 { return debug_inner_branch_taken; }

// Write 7 to cb_prof.callbacks_by_tag[idx]; read back; return read value.
// If write+read are consistent, returns 7. If something's broken, returns 0.
export fn prologos_debug_write_read_cb(idx: u32) u64 {
    cb_prof.callbacks_by_tag[idx] = 7;
    return cb_prof.callbacks_by_tag[idx];
}

export fn prologos_debug_n_tags() u32 { return N_TAGS; }
export fn prologos_debug_size_profile() u32 { return @sizeOf(profile.Profile); }
export fn prologos_debug_size_cb_profile() u32 { return @sizeOf(profile.CallbackProfile); }

var debug_pp_seen: u64 = 0;
var debug_kind_at_fire: u8 = 99;
export fn prologos_debug_pp_seen() u64 { return debug_pp_seen; }
export fn prologos_debug_kind_at_fire() u8 { return debug_kind_at_fire; }

fn merge_pending_writes() void {
    var i: u32 = 0;
    while (i < pending_len) : (i += 1) {
        prologos_cell_write(pending_cid[i], pending_val[i]);
    }
    pending_len = 0;
}

fn swap_worklists() void {
    var i: u32 = 0;
    while (i < next_worklist_len) : (i += 1) {
        worklist[i] = next_worklist[i];
    }
    worklist_len = next_worklist_len;
    next_worklist_len = 0;
}

var max_rounds: u64 = 100000;

export fn prologos_set_max_rounds(m: u64) void {
    max_rounds = m;
}

export fn prologos_run_to_quiescence() void {
    ensure_init();
    const start_ns = profile.now_ns();
    swap_worklists();
    while (worklist_len > 0) {
        if (max_rounds != 0 and prof.rounds >= max_rounds) {
            prof.fuel_exhausted = 1;
            break;
        }
        prof.rounds += 1;
        store.take_snapshot();
        var i: u32 = 0;
        while (i < worklist_len) : (i += 1) {
            const pid = worklist[i];
            in_worklist[pid] = 0;
            fire_against_snapshot(pid);
        }
        worklist_len = 0;
        merge_pending_writes();
        swap_worklists();
    }
    prof.run_ns += profile.now_ns() - start_ns;
}

// Optional round callback (Racket can hook to run stratum handlers).
var round_callback: ?*const fn (u32) callconv(.C) void = null;

export fn prologos_set_round_callback(fn_ptr: ?*const anyopaque) void {
    if (fn_ptr) |p| {
        round_callback = @ptrCast(@alignCast(p));
    } else {
        round_callback = null;
    }
}

// ============================================================
// Profiling APIs (exported)
// ============================================================

export fn prologos_set_profile_per_tag(enabled: u32) void {
    prof.profile_per_tag = enabled != 0;
}

// stat keys: per-tag arrays use 1024-wide non-overlapping ranges so
// they don't collide when N_TAGS is large. Format: (1024 * domain) +
// tag for domain ∈ {1=fires, 2=ns, 3=callbacks, 4=callback_ns}.
//   0..8: scalar counters as in original
//   1024..(1024+N_TAGS): fires_by_tag
//   2048..(2048+N_TAGS): ns_by_tag
//   3072..(3072+N_TAGS): callbacks_by_tag
//   4096..(4096+N_TAGS): callback_ns_by_tag
export fn prologos_get_stat(key: u32) u64 {
    return switch (key) {
        0 => prof.rounds,
        1 => prof.fires_total,
        2 => prof.writes_committed,
        3 => prof.writes_dropped,
        4 => prof.max_worklist,
        5 => prof.fuel_exhausted,
        6 => @intCast(store.num_cells),
        7 => @intCast(num_props),
        8 => prof.run_ns,
        else => blk: {
            if (key >= 1024 and key < 1024 + N_TAGS) {
                break :blk prof.fires_by_tag[key - 1024];
            }
            if (key >= 2048 and key < 2048 + N_TAGS) {
                break :blk prof.ns_by_tag[key - 2048];
            }
            if (key >= 3072 and key < 3072 + N_TAGS) {
                break :blk cb_prof.callbacks_by_tag[key - 3072];
            }
            if (key >= 4096 and key < 4096 + N_TAGS) {
                break :blk cb_prof.callback_ns_by_tag[key - 4096];
            }
            break :blk 0;
        },
    };
}

export fn prologos_reset_stats() void {
    prof.reset();
    cb_prof.reset();
}

export fn prologos_print_stats() void {
    prof.print_json(store.num_cells, num_props);
}

export fn prologos_print_callback_summary() void {
    cb_prof.print_summary();
}

// Debug: read prof.profile_per_tag flag.
export fn prologos_debug_profile_per_tag() u32 {
    return if (prof.profile_per_tag) 1 else 0;
}

// Debug: read fire_kind for a given tag/shape. Returns 255 for invalid.
export fn prologos_debug_fire_kind(tag: u32, shape: u32) u8 {
    if (tag >= N_TAGS) return 255;
    return switch (shape) {
        SHAPE_1_1 => fire_kind_1_1[tag],
        SHAPE_2_1 => fire_kind_2_1[tag],
        SHAPE_3_1 => fire_kind_3_1[tag],
        SHAPE_N_1 => fire_kind_n_1[tag],
        else => 255,
    };
}

// Reset the entire kernel state (cells + props + dispatch). Used between
// (preduce e) calls for the one-shot reduction model.
export fn prologos_kernel_reset() void {
    store = CellStore.init(0);
    num_props = 0;
    prop_in_arena_used = 0;
    worklist_len = 0;
    next_worklist_len = 0;
    pending_len = 0;
    var i: u32 = 0;
    while (i < MAX_PROPS) : (i += 1) {
        in_worklist[i] = 0;
    }
    prof.reset();
    cb_prof.reset();
    // Built-ins remain registered; user-registered fire-fns persist
    // across resets (the dispatch table lifetime is the .so lifetime).
}
