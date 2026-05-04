// runtime/core/format.zig — buffered integer-to-decimal + string output.
//
// Shared by both kernel implementations for prologos_print_stats and
// related JSON/text output. Avoids printf/fprintf to keep the kernel
// libc-light: one allocator-free fixed buffer, one write() syscall.

extern fn write(fd: c_int, buf: [*]const u8, count: usize) isize;

pub const FormatBuffer = struct {
    // Buffer must accommodate the full PNET-STATS / CALLBACK-PROFILE
    // JSON dumps, which include N_TAGS=256 per-tag entries. Worst case:
    // each entry is ~20 chars (",18446744073709551615" for u64::MAX) +
    // a few hundred chars of JSON keys + the run_ns/cells/props framing.
    // 8192 gives ~4× headroom; 1024 silently truncated and corrupted
    // the JSON output for any program with more than ~80 active tags.
    buf: [8192]u8,
    len: usize,

    pub fn init() FormatBuffer {
        return .{ .buf = undefined, .len = 0 };
    }

    pub fn reset(self: *FormatBuffer) void {
        self.len = 0;
    }

    pub fn putc(self: *FormatBuffer, c: u8) void {
        if (self.len < self.buf.len) {
            self.buf[self.len] = c;
            self.len += 1;
        }
    }

    pub fn puts(self: *FormatBuffer, s: []const u8) void {
        for (s) |c| self.putc(c);
    }

    pub fn putu64(self: *FormatBuffer, n0: u64) void {
        if (n0 == 0) {
            self.putc('0');
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
            self.putc(tmp[tlen]);
        }
    }

    pub fn flush_to_stderr(self: *FormatBuffer) void {
        _ = write(2, &self.buf, self.len);
    }
};
