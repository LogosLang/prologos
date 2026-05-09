// prologos-runtime.zig — N0 + propagator BSP scheduler kernel.
//
// The "physics" of the propagator network for the smallest viable runtime.
// Provides:
//
//   prologos_cell_alloc()                    -> u32 cell-id
//   prologos_cell_write(id, val)             -> void
//   prologos_cell_read(id)                   -> i64
//
//   prologos_propagator_install_1_1(tag, in0, out0) -> u32 prop-id
//                                              unary fire-fn dispatch
//                                              tags: 0=identity, 1=int-neg,
//                                                    2=int-abs
//                                              kernel-identity is the
//                                              feedback connector for
//                                              iterative networks.
//   prologos_propagator_install_2_1(tag, in0, in1, out0) -> u32 prop-id
//                                              binary fire-fn dispatch
//                                              tags: 0=int-add, 1=int-sub,
//                                                    2=int-mul, 3=int-div,
//                                                    4=int-eq,  5=int-lt,
//                                                    6=int-le
//                                              comparison results: 0/1 i64
//   prologos_propagator_install_3_1(tag, in0, in1, in2, out0) -> u32 prop-id
//                                              ternary fire-fn dispatch
//                                              tags: 0=select(cond,then,else)
//                                                    cond=in0 (0/1), then=in1,
//                                                    else=in2; out=in1 if cond
//                                                    nonzero else in2
//   prologos_run_to_quiescence()             -> void
//                                              run BSP rounds until no
//                                              writes change any cell, OR
//                                              fuel (default 100000) exhausted
//
//   prologos_set_max_rounds(max)             -> void  (set fuel; 0 = unlimited)
//   prologos_get_stat(key)                   -> u64   (instrumentation)
//   prologos_print_stats()                   -> void  (write summary to stderr)
//   prologos_reset_stats()                   -> void  (zero counters; cells/props
//                                              untouched)
//
// =====================================================================
// Scheduler model: bulk-synchronous parallel (BSP).
// =====================================================================
//
// Each BSP ROUND:
//   1. Dedup the current worklist into a "round set" of unique pids.
//   2. Snapshot cells[] → snapshot[]; reads in this round see snapshot.
//   3. Fire each pid in round set: read inputs from snapshot, compute
//      output, append (out_cid, value) to pending_writes.
//   4. Barrier: apply pending_writes to cells[]. For each write that
//      changes cells[cid], schedule cell_subs[cid] into next_worklist.
//   5. Swap worklist ← next_worklist; if empty, terminate.
//
// This decouples reads from writes within a round (CALM/ACI safe).
// For acyclic networks: terminates in O(depth) rounds. For cyclic
// networks with monotone merges: terminates at fix-point. For
// non-monotone cycles: termination is bounded by the fuel parameter.
//
// Instrumentation (Sprint C, 2026-05-01):
//   stat_rounds, stat_fires_total, stat_fires_by_tag[N_TAGS],
//   stat_writes_committed, stat_writes_dropped, stat_max_worklist.
//   Exposed via prologos_get_stat / prologos_print_stats.
//
// No reference counting, no GC, no I/O at runtime, single-threaded.
// Multi-thread parallelism deferred to future Sprint D (per-core
// chunked worklist + per-thread write log + sequential merge).
//
// Builds via `zig build-obj prologos-runtime.zig` into prologos-runtime.o.
// Pinned to Zig 0.13.0.

extern fn abort() noreturn;
extern fn write(fd: c_int, buf: [*]const u8, count: usize) isize;

// CLOCK_MONOTONIC nanoseconds via libc clock_gettime. On Linux x86_64
// this resolves through the vDSO (~30ns per call).
const timespec = extern struct {
    sec: i64,
    nsec: i64,
};
extern fn clock_gettime(clk_id: c_int, tp: *timespec) c_int;
const CLOCK_MONOTONIC: c_int = 1;

fn now_ns() u64 {
    var ts: timespec = .{ .sec = 0, .nsec = 0 };
    _ = clock_gettime(CLOCK_MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1_000_000_000 + @as(u64, @intCast(ts.nsec));
}

const MAX_CELLS: u32 = 1024;
const MAX_PROPS: u32 = 1024;
const MAX_DEPS: u32 = 16;
const N_TAGS: u32 = 16;          // big enough for current 2-1 + 3-1 tags
const DEFAULT_MAX_ROUNDS: u64 = 100000;

// =====================================================================
// Cells
// =====================================================================

var cells: [MAX_CELLS]i64 = [_]i64{0} ** MAX_CELLS;
var snapshot: [MAX_CELLS]i64 = [_]i64{0} ** MAX_CELLS;
var num_cells: u32 = 0;

export fn prologos_cell_alloc() u32 {
    if (num_cells >= MAX_CELLS) abort();
    const id = num_cells;
    num_cells += 1;
    return id;
}

// Direct cell write — bypasses the BSP barrier. Used by generated IR
// at module init time (before any propagator runs) and by the BSP
// merge phase. NOT safe to call from inside a fire() — fire() must
// only emit to pending_writes.
export fn prologos_cell_write(id: u32, value: i64) void {
    if (id >= num_cells) abort();
    if (cells[id] != value) {
        cells[id] = value;
        stat_writes_committed += 1;
        // Schedule subscribers (the propagators that depend on this cell)
        var i: u32 = 0;
        while (i < cell_num_subs[id]) : (i += 1) {
            schedule(cell_subs[id][i]);
        }
    } else {
        stat_writes_dropped += 1;
    }
}

export fn prologos_cell_read(id: u32) i64 {
    if (id >= num_cells) abort();
    return cells[id];
}

// =====================================================================
// Propagators — (1,1), (2,1), and (3,1) shapes
// =====================================================================
//
// For each propagator pid we store: shape, tag, in0, in1, in2, out0.
// shape=1 means only in0 is live (in1, in2 unused).
// shape=2 means in2 unused.
// shape=3 means all three inputs live.

const SHAPE_1_1: u32 = 1;
const SHAPE_2_1: u32 = 2;
const SHAPE_3_1: u32 = 3;

var prop_shape: [MAX_PROPS]u32 = undefined;
var prop_tags:  [MAX_PROPS]u32 = undefined;
var prop_in0:   [MAX_PROPS]u32 = undefined;
var prop_in1:   [MAX_PROPS]u32 = undefined;
var prop_in2:   [MAX_PROPS]u32 = undefined;
var prop_out:   [MAX_PROPS]u32 = undefined;
var num_props:  u32 = 0;

// Per-cell subscriber list: which propagators wake when this cell changes.
var cell_subs: [MAX_CELLS][MAX_DEPS]u32 = undefined;
var cell_num_subs: [MAX_CELLS]u32 = [_]u32{0} ** MAX_CELLS;

fn subscribe(cid: u32, pid: u32) void {
    if (cid >= num_cells) abort();
    const n = cell_num_subs[cid];
    if (n >= MAX_DEPS) abort();
    cell_subs[cid][n] = pid;
    cell_num_subs[cid] = n + 1;
}

export fn prologos_propagator_install_1_1(
    tag: u32,
    in0: u32,
    out0: u32,
) u32 {
    if (num_props >= MAX_PROPS) abort();
    const pid = num_props;
    prop_shape[pid] = SHAPE_1_1;
    prop_tags[pid]  = tag;
    prop_in0[pid]   = in0;
    prop_in1[pid]   = 0;  // unused
    prop_in2[pid]   = 0;  // unused
    prop_out[pid]   = out0;
    num_props += 1;
    subscribe(in0, pid);
    schedule(pid);
    return pid;
}

export fn prologos_propagator_install_2_1(
    tag: u32,
    in0: u32,
    in1: u32,
    out0: u32,
) u32 {
    if (num_props >= MAX_PROPS) abort();
    const pid = num_props;
    prop_shape[pid] = SHAPE_2_1;
    prop_tags[pid]  = tag;
    prop_in0[pid]   = in0;
    prop_in1[pid]   = in1;
    prop_in2[pid]   = 0;  // unused
    prop_out[pid]   = out0;
    num_props += 1;
    subscribe(in0, pid);
    subscribe(in1, pid);
    schedule(pid);
    return pid;
}

export fn prologos_propagator_install_3_1(
    tag: u32,
    in0: u32,
    in1: u32,
    in2: u32,
    out0: u32,
) u32 {
    if (num_props >= MAX_PROPS) abort();
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

// =====================================================================
// Scheduler — BSP worklist with snapshot/diff/merge
// =====================================================================

var worklist:      [MAX_PROPS]u32 = undefined;  // current round's pending pids
var worklist_len:  u32 = 0;
var next_worklist: [MAX_PROPS]u32 = undefined;  // built during merge phase
var next_worklist_len: u32 = 0;

// in_worklist[pid] = 1 iff pid is in worklist OR next_worklist OR has
// already been claimed for the current round. Used for dedup.
var in_worklist: [MAX_PROPS]u8 = [_]u8{0} ** MAX_PROPS;

// pending_writes: collected during a round; applied during the barrier.
// Each entry is (cid, value). Capacity = MAX_PROPS since at most one
// write per propagator per round (each prop has exactly one output).
var pending_cid: [MAX_PROPS]u32 = undefined;
var pending_val: [MAX_PROPS]i64 = undefined;
var pending_len: u32 = 0;

// schedule(pid) — add pid to next_worklist if not already in either list.
fn schedule(pid: u32) void {
    if (in_worklist[pid] != 0) return;  // dedup
    in_worklist[pid] = 1;
    if (next_worklist_len >= MAX_PROPS) abort();
    next_worklist[next_worklist_len] = pid;
    next_worklist_len += 1;
    if (next_worklist_len > stat_max_worklist) {
        stat_max_worklist = next_worklist_len;
    }
}

// fire_against_snapshot(pid): read inputs from snapshot[], compute,
// emit (out_cid, value) into pending_writes. Does NOT call cell_write.
//
// Per-tag wall time is opt-in via prologos_set_profile_per_tag(true).
// When enabled, we bracket the dispatch with two clock_gettime calls
// (~60ns overhead per fire). When disabled, the cost is one branch.
fn fire_against_snapshot(pid: u32) void {
    const shape = prop_shape[pid];
    const tag = prop_tags[pid];
    const out_cid = prop_out[pid];
    const t0: u64 = if (profile_per_tag) now_ns() else 0;
    var result: i64 = 0;
    switch (shape) {
        SHAPE_1_1 => {
            const a = snapshot[prop_in0[pid]];
            switch (tag) {
                0 => result = a,                       // kernel-identity
                1 => result = -a,                      // kernel-int-neg
                2 => result = if (a < 0) -a else a,    // kernel-int-abs
                else => abort(),
            }
        },
        SHAPE_2_1 => {
            const a = snapshot[prop_in0[pid]];
            const b = snapshot[prop_in1[pid]];
            switch (tag) {
                0 => result = a + b,                   // kernel-int-add
                1 => result = a - b,                   // kernel-int-sub
                2 => result = a * b,                   // kernel-int-mul
                3 => result = @divTrunc(a, b),         // kernel-int-div
                4 => result = if (a == b) 1 else 0,    // kernel-int-eq
                5 => result = if (a < b) 1 else 0,     // kernel-int-lt
                6 => result = if (a <= b) 1 else 0,    // kernel-int-le
                else => abort(),
            }
        },
        SHAPE_3_1 => {
            const c = snapshot[prop_in0[pid]];   // condition (0/1)
            const t = snapshot[prop_in1[pid]];   // then-value
            const e = snapshot[prop_in2[pid]];   // else-value
            switch (tag) {
                0 => result = if (c != 0) t else e,    // kernel-select
                else => abort(),
            }
        },
        else => abort(),
    }
    if (pending_len >= MAX_PROPS) abort();
    pending_cid[pending_len] = out_cid;
    pending_val[pending_len] = result;
    pending_len += 1;
    stat_fires_total += 1;
    if (tag < N_TAGS) {
        stat_fires_by_tag[tag] += 1;
        if (profile_per_tag) {
            const t1 = now_ns();
            stat_ns_by_tag[tag] += t1 - t0;
        }
    }
}

// take_snapshot(): copy live cell values into snapshot[].
fn take_snapshot() void {
    var i: u32 = 0;
    while (i < num_cells) : (i += 1) {
        snapshot[i] = cells[i];
    }
}

// merge_pending_writes(): apply each pending write; for each write
// that changes cells[cid], schedule subscribers via cell_write's path.
// pending_writes are cleared (length zeroed).
fn merge_pending_writes() void {
    var i: u32 = 0;
    while (i < pending_len) : (i += 1) {
        const cid = pending_cid[i];
        const v = pending_val[i];
        // prologos_cell_write tracks committed/dropped counters and
        // schedules subscribers; reuse it.
        prologos_cell_write(cid, v);
    }
    pending_len = 0;
}

// =====================================================================
// Fuel and main BSP driver
// =====================================================================

var max_rounds: u64 = DEFAULT_MAX_ROUNDS;

export fn prologos_set_max_rounds(m: u64) void {
    max_rounds = m;
}

export fn prologos_run_to_quiescence() void {
    const start_ns = now_ns();
    // Move any pending installs from next_worklist into worklist for
    // the first round. (After install, schedule() puts pids into
    // next_worklist; we transfer once before round 1 starts.)
    swap_worklists();

    while (worklist_len > 0) {
        if (max_rounds != 0 and stat_rounds >= max_rounds) {
            // Fuel exhausted. Stop without abort so the caller can
            // still read whatever cell value has been computed.
            stat_fuel_exhausted = 1;
            break;
        }
        stat_rounds += 1;
        take_snapshot();

        // Phase 1: fire all pids in current round against snapshot.
        // Clear in_worklist[pid] as we consume it so that fires in
        // *this* round can re-schedule the same pid for the *next*
        // round if a downstream cell change demands it.
        var i: u32 = 0;
        while (i < worklist_len) : (i += 1) {
            const pid = worklist[i];
            in_worklist[pid] = 0;
            fire_against_snapshot(pid);
        }
        worklist_len = 0;

        // Phase 2 (barrier): merge pending writes; subscribers of
        // changed cells land in next_worklist.
        merge_pending_writes();

        // Swap for next round.
        swap_worklists();
    }
    stat_run_ns += now_ns() - start_ns;
}

fn swap_worklists() void {
    // Move next_worklist into worklist (just by swapping lengths and
    // memcpy'ing — we can't swap arrays in-place in Zig 0.13 ergonomically
    // since they're top-level vars; copy then zero next).
    var i: u32 = 0;
    while (i < next_worklist_len) : (i += 1) {
        worklist[i] = next_worklist[i];
    }
    worklist_len = next_worklist_len;
    next_worklist_len = 0;
}

// =====================================================================
// Instrumentation (Sprint C)
// =====================================================================

var stat_rounds: u64 = 0;
var stat_fires_total: u64 = 0;
var stat_fires_by_tag: [N_TAGS]u64 = [_]u64{0} ** N_TAGS;
var stat_writes_committed: u64 = 0;
var stat_writes_dropped: u64 = 0;
var stat_max_worklist: u64 = 0;
var stat_fuel_exhausted: u64 = 0;
var stat_run_ns: u64 = 0;
var stat_ns_by_tag: [N_TAGS]u64 = [_]u64{0} ** N_TAGS;
var profile_per_tag: bool = false;

export fn prologos_set_profile_per_tag(enabled: u32) void {
    profile_per_tag = enabled != 0;
}

// stat keys (must match the integers in get_stat).
//   0  rounds
//   1  fires_total
//   2  writes_committed
//   3  writes_dropped
//   4  max_worklist
//   5  fuel_exhausted (0 or 1)
//   6  num_cells (allocated)
//   7  num_props (installed)
//   8  run_ns (CLOCK_MONOTONIC ns spent in run_to_quiescence)
//   100..(100+N_TAGS)  fires for tag (key-100)
//   200..(200+N_TAGS)  ns for tag (key-200) — only populated when
//                      profile_per_tag=true
//   anything else      0
export fn prologos_get_stat(key: u32) u64 {
    return switch (key) {
        0 => stat_rounds,
        1 => stat_fires_total,
        2 => stat_writes_committed,
        3 => stat_writes_dropped,
        4 => stat_max_worklist,
        5 => stat_fuel_exhausted,
        6 => @intCast(num_cells),
        7 => @intCast(num_props),
        8 => stat_run_ns,
        else => blk: {
            if (key >= 100 and key < 100 + N_TAGS) {
                break :blk stat_fires_by_tag[key - 100];
            }
            if (key >= 200 and key < 200 + N_TAGS) {
                break :blk stat_ns_by_tag[key - 200];
            }
            break :blk 0;
        },
    };
}

export fn prologos_reset_stats() void {
    stat_rounds = 0;
    stat_fires_total = 0;
    stat_writes_committed = 0;
    stat_writes_dropped = 0;
    stat_max_worklist = 0;
    stat_fuel_exhausted = 0;
    stat_run_ns = 0;
    var i: u32 = 0;
    while (i < N_TAGS) : (i += 1) {
        stat_fires_by_tag[i] = 0;
        stat_ns_by_tag[i] = 0;
    }
}

// =====================================================================
// prologos_print_stats — write a one-line JSON summary to stderr (fd 2)
// =====================================================================
//
// We avoid printf/fprintf to keep the kernel libc-light. A small
// integer-to-decimal formatter writes into a fixed buffer; one
// write() syscall emits the full line.

var print_buf: [1024]u8 = undefined;
var print_len: usize = 0;

fn buf_putc(c: u8) void {
    if (print_len < print_buf.len) {
        print_buf[print_len] = c;
        print_len += 1;
    }
}

fn buf_puts(s: []const u8) void {
    for (s) |c| buf_putc(c);
}

fn buf_putu64(n0: u64) void {
    if (n0 == 0) {
        buf_putc('0');
        return;
    }
    var tmp: [24]u8 = undefined;
    var tlen: usize = 0;
    var n = n0;
    while (n > 0) : (n /= 10) {
        tmp[tlen] = @intCast('0' + (n % 10));
        tlen += 1;
    }
    while (tlen > 0) {
        tlen -= 1;
        buf_putc(tmp[tlen]);
    }
}

export fn prologos_print_stats() void {
    print_len = 0;
    buf_puts("PNET-STATS: {");
    buf_puts("\"rounds\":");      buf_putu64(stat_rounds);
    buf_puts(",\"fires\":");       buf_putu64(stat_fires_total);
    buf_puts(",\"committed\":");   buf_putu64(stat_writes_committed);
    buf_puts(",\"dropped\":");     buf_putu64(stat_writes_dropped);
    buf_puts(",\"max_worklist\":");buf_putu64(stat_max_worklist);
    buf_puts(",\"fuel_out\":");    buf_putu64(stat_fuel_exhausted);
    buf_puts(",\"cells\":");       buf_putu64(@intCast(num_cells));
    buf_puts(",\"props\":");       buf_putu64(@intCast(num_props));
    buf_puts(",\"run_ns\":");      buf_putu64(stat_run_ns);
    buf_puts(",\"by_tag\":[");
    var i: u32 = 0;
    while (i < N_TAGS) : (i += 1) {
        if (i > 0) buf_putc(',');
        buf_putu64(stat_fires_by_tag[i]);
    }
    buf_puts("],\"ns_by_tag\":[");
    i = 0;
    while (i < N_TAGS) : (i += 1) {
        if (i > 0) buf_putc(',');
        buf_putu64(stat_ns_by_tag[i]);
    }
    buf_puts("]}\n");
    _ = write(2, &print_buf, print_len);
}
