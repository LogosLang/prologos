// runtime/core/cells.zig — generic cell store + subscriber lists.
//
// Comptime-parameterized over Value type and CAPACITY. Both kernels
// instantiate this with their own Value type:
//   original kernel: CellStore(i64, 1024)
//   hybrid kernel:   CellStore(i64, 1024)  — i64 reinterpreted as
//                                            tagged-i64 (8-bit tag +
//                                            56-bit payload)
//
// The cell-store API is intentionally narrow: alloc, read, write,
// subscribe, take_snapshot. The kernel-specific dispatch + scheduler
// drive these primitives; this module is data structure only.

extern fn abort() noreturn;

pub const MAX_DEPS: u32 = 16;

pub fn CellStore(comptime Value: type, comptime CAPACITY: u32) type {
    return struct {
        const Self = @This();

        cells: [CAPACITY]Value,
        snapshot: [CAPACITY]Value,
        num_cells: u32,
        cell_subs: [CAPACITY][MAX_DEPS]u32,
        cell_num_subs: [CAPACITY]u32,

        pub fn init(default_value: Value) Self {
            return .{
                .cells = [_]Value{default_value} ** CAPACITY,
                .snapshot = [_]Value{default_value} ** CAPACITY,
                .num_cells = 0,
                .cell_subs = undefined,
                .cell_num_subs = [_]u32{0} ** CAPACITY,
            };
        }

        pub fn alloc(self: *Self) u32 {
            if (self.num_cells >= CAPACITY) abort();
            const id = self.num_cells;
            self.num_cells += 1;
            return id;
        }

        pub fn read(self: *const Self, id: u32) Value {
            if (id >= self.num_cells) abort();
            return self.cells[id];
        }

        pub fn read_snapshot(self: *const Self, id: u32) Value {
            if (id >= self.num_cells) abort();
            return self.snapshot[id];
        }

        // Set the cell directly. Returns true iff the value changed.
        // Caller is responsible for scheduling subscribers on change.
        pub fn write_unchecked(self: *Self, id: u32, value: Value) bool {
            if (id >= self.num_cells) abort();
            const old = self.cells[id];
            // Compare by bit-pattern for arbitrary Value types.
            const changed = !valuesEqual(Value, old, value);
            if (changed) self.cells[id] = value;
            return changed;
        }

        pub fn subscribe(self: *Self, cid: u32, pid: u32) void {
            if (cid >= self.num_cells) abort();
            const n = self.cell_num_subs[cid];
            if (n >= MAX_DEPS) abort();
            self.cell_subs[cid][n] = pid;
            self.cell_num_subs[cid] = n + 1;
        }

        pub fn take_snapshot(self: *Self) void {
            var i: u32 = 0;
            while (i < self.num_cells) : (i += 1) {
                self.snapshot[i] = self.cells[i];
            }
        }

        pub fn num_subs(self: *const Self, cid: u32) u32 {
            return self.cell_num_subs[cid];
        }

        pub fn sub_at(self: *const Self, cid: u32, idx: u32) u32 {
            return self.cell_subs[cid][idx];
        }
    };
}

// Bit-equal comparison for arbitrary types. Works for i64, structs,
// packed integers, etc. — the cell value is treated as opaque bits.
fn valuesEqual(comptime T: type, a: T, b: T) bool {
    const Bytes = [@sizeOf(T)]u8;
    const ab: Bytes = @bitCast(a);
    const bb: Bytes = @bitCast(b);
    var i: usize = 0;
    while (i < ab.len) : (i += 1) {
        if (ab[i] != bb[i]) return false;
    }
    return true;
}
