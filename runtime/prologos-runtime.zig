// prologos-runtime.zig — N0 + propagator scheduler kernel.
//
// The "physics" of the propagator network for the smallest viable runtime.
// Provides:
//
//   prologos_cell_alloc()                    -> u32 cell-id
//   prologos_cell_write(id, val)             -> void
//   prologos_cell_read(id)                   -> i64
//
//   prologos_propagator_install_2_1(tag, in0, in1, out0) -> u32 prop-id
//                                              binary fire-fn dispatch
//                                              tags: 0=int-add, 1=int-sub,
//                                                    2=int-mul, 3=int-div
//   prologos_run_to_quiescence()             -> void
//                                              fire all scheduled
//                                              propagators until empty
//
// Cell storage: fixed array of 1024 i64 cells.
// Propagator storage: fixed array of 1024 propagators, (2,1) shape only.
// Subscriptions: each cell has up to 16 subscribed propagators.
//
// Scheduler model: Jacobi-ish worklist. Each install enqueues the
// propagator. `run_to_quiescence` drains the worklist; firing a
// propagator may enqueue more (subscribers of changed cells). For
// arithmetic networks (no cycles, propagators write once) this
// terminates in O(N) rounds where N is the number of propagators.
//
// No reference counting, no GC, no I/O, single-threaded.
// Builds via `zig build-obj prologos-runtime.zig` into prologos-runtime.o.
// Pinned to Zig 0.13.0.

extern fn abort() noreturn;

const MAX_CELLS: u32 = 1024;
const MAX_PROPS: u32 = 1024;
const MAX_DEPS: u32 = 16;

// =====================================================================
// Cells
// =====================================================================

var cells: [MAX_CELLS]i64 = [_]i64{0} ** MAX_CELLS;
var num_cells: u32 = 0;

export fn prologos_cell_alloc() u32 {
    if (num_cells >= MAX_CELLS) abort();
    const id = num_cells;
    num_cells += 1;
    return id;
}

export fn prologos_cell_write(id: u32, value: i64) void {
    if (id >= num_cells) abort();
    if (cells[id] != value) {
        cells[id] = value;
        // Schedule subscribers (the propagators that depend on this cell)
        var i: u32 = 0;
        while (i < cell_num_subs[id]) : (i += 1) {
            enqueue(cell_subs[id][i]);
        }
    }
}

export fn prologos_cell_read(id: u32) i64 {
    if (id >= num_cells) abort();
    return cells[id];
}

// =====================================================================
// Propagators (Sprint 1 scope: (2,1) shape only)
// =====================================================================
//
// For each propagator pid we store: tag, in0, in1, out0.
// Tags are small ints (registry below). Future sprints can broaden
// to other shapes (1,1), (3,1), or fully variable arity.

var prop_tags: [MAX_PROPS]u32 = undefined;
var prop_in0:  [MAX_PROPS]u32 = undefined;
var prop_in1:  [MAX_PROPS]u32 = undefined;
var prop_out:  [MAX_PROPS]u32 = undefined;
var num_props: u32 = 0;

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

export fn prologos_propagator_install_2_1(
    tag: u32,
    in0: u32,
    in1: u32,
    out0: u32,
) u32 {
    if (num_props >= MAX_PROPS) abort();
    const pid = num_props;
    prop_tags[pid] = tag;
    prop_in0[pid]  = in0;
    prop_in1[pid]  = in1;
    prop_out[pid]  = out0;
    num_props += 1;
    subscribe(in0, pid);
    subscribe(in1, pid);
    enqueue(pid);
    return pid;
}

// =====================================================================
// Scheduler — worklist BSP
// =====================================================================

var worklist: [MAX_PROPS * MAX_DEPS]u32 = undefined;
var worklist_len: u32 = 0;

fn enqueue(pid: u32) void {
    if (worklist_len >= worklist.len) abort();
    worklist[worklist_len] = pid;
    worklist_len += 1;
}

fn fire(pid: u32) void {
    const tag = prop_tags[pid];
    const a = cells[prop_in0[pid]];
    const b = cells[prop_in1[pid]];
    const out_cid = prop_out[pid];
    var result: i64 = 0;
    switch (tag) {
        0 => result = a + b,    // kernel-int-add
        1 => result = a - b,    // kernel-int-sub
        2 => result = a * b,    // kernel-int-mul
        3 => result = @divTrunc(a, b),  // kernel-int-div (signed truncating)
        else => abort(),
    }
    prologos_cell_write(out_cid, result);
}

export fn prologos_run_to_quiescence() void {
    var idx: u32 = 0;
    while (idx < worklist_len) : (idx += 1) {
        fire(worklist[idx]);
    }
}
