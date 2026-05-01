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
//
// We declare libc's abort() via extern rather than using std.process.abort().
// Reason: `zig build-obj` produces a freestanding object file; std-lib
// functions get statically embedded only if reachable, but referencing
// std.process.abort can introduce zig-runtime dependencies (panic handler,
// etc.) that don't resolve when clang-linked against plain libc. extern abort
// gives us the same semantics with one unresolved symbol that clang resolves
// against libc at link time — matching the local C-shim behavior we validated.

extern fn abort() noreturn;

const MAX_CELLS: u32 = 1024;

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
    cells[id] = value;
}

export fn prologos_cell_read(id: u32) i64 {
    if (id >= num_cells) abort();
    return cells[id];
}
