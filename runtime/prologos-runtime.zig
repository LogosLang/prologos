// prologos-runtime.zig — N0 kernel.
//
// The "physics" of the propagator network for the smallest viable runtime.
// Provides three primitives, exported with the C ABI so LLVM IR emitted by
// network-lower.rkt links cleanly:
//
//   prologos_cell_alloc()          -> u32 cell-id
//   prologos_cell_write(id, val)   -> void
//   prologos_cell_read(id)         -> i64
//
// N0 storage: a fixed-size array of 1024 i64 cells, indexed by cell-id.
// No merge function (N0 has no propagators that re-write a cell).
// No persistent maps (#42 — N3 introduces those).
// No threading, no GC, no I/O.
//
// Builds via `zig build-obj prologos-runtime.zig` into prologos-runtime.o.
// Pinned to Zig 0.13.0 (see .zig-version).

const std = @import("std");

const MAX_CELLS: u32 = 1024;

var cells: [MAX_CELLS]i64 = [_]i64{0} ** MAX_CELLS;
var num_cells: u32 = 0;

export fn prologos_cell_alloc() callconv(.C) u32 {
    if (num_cells >= MAX_CELLS) {
        // N0 has no error reporting beyond aborting. Subsequent tiers add
        // contradiction handling, dynamic allocation, etc.
        std.process.abort();
    }
    const id = num_cells;
    num_cells += 1;
    return id;
}

export fn prologos_cell_write(id: u32, value: i64) callconv(.C) void {
    if (id >= num_cells) std.process.abort();
    cells[id] = value;
}

export fn prologos_cell_read(id: u32) callconv(.C) i64 {
    if (id >= num_cells) std.process.abort();
    return cells[id];
}
