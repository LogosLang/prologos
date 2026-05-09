// runtime/core/profile.zig — shared profile counters + timing.
//
// Owned by each kernel as a single instance. Both kernels increment
// the same counter set; the hybrid kernel additionally tracks
// callback-specific counters in its own `extra` profile.

const format = @import("format.zig");

// Tag pool size. Each propagator install in callback mode allocates
// a fresh tag here; kernel-native ops occupy the first 0..N_NATIVE
// slots. Bumped from 256 to 4096 on 2026-05-05 — W14 prime-count
// at N>=7 was hitting the old limit. Memory cost: ~384 KB across
// the dispatch + profile arrays. Real fix is fire-fn memoization
// (share tags across structurally-identical installs); this bump
// is the cheap unblock so realistic recursive workloads run.
pub const N_TAGS: u32 = 4096;

const timespec = extern struct { sec: i64, nsec: i64 };
extern fn clock_gettime(clk_id: c_int, tp: *timespec) c_int;
const CLOCK_MONOTONIC: c_int = 1;

pub fn now_ns() u64 {
    var ts: timespec = .{ .sec = 0, .nsec = 0 };
    _ = clock_gettime(CLOCK_MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1_000_000_000 + @as(u64, @intCast(ts.nsec));
}

pub const Profile = struct {
    rounds: u64 = 0,
    fires_total: u64 = 0,
    fires_by_tag: [N_TAGS]u64 = [_]u64{0} ** N_TAGS,
    writes_committed: u64 = 0,
    writes_dropped: u64 = 0,
    max_worklist: u64 = 0,
    fuel_exhausted: u64 = 0,
    run_ns: u64 = 0,
    ns_by_tag: [N_TAGS]u64 = [_]u64{0} ** N_TAGS,
    profile_per_tag: bool = false,

    pub fn reset(self: *Profile) void {
        self.rounds = 0;
        self.fires_total = 0;
        self.writes_committed = 0;
        self.writes_dropped = 0;
        self.max_worklist = 0;
        self.fuel_exhausted = 0;
        self.run_ns = 0;
        var i: u32 = 0;
        while (i < N_TAGS) : (i += 1) {
            self.fires_by_tag[i] = 0;
            self.ns_by_tag[i] = 0;
        }
    }

    pub fn print_json(self: *const Profile, num_cells: u32, num_props: u32) void {
        var fb = format.FormatBuffer.init();
        fb.puts("PNET-STATS: {");
        fb.puts("\"rounds\":");      fb.putu64(self.rounds);
        fb.puts(",\"fires\":");       fb.putu64(self.fires_total);
        fb.puts(",\"committed\":");   fb.putu64(self.writes_committed);
        fb.puts(",\"dropped\":");     fb.putu64(self.writes_dropped);
        fb.puts(",\"max_worklist\":");fb.putu64(self.max_worklist);
        fb.puts(",\"fuel_out\":");    fb.putu64(self.fuel_exhausted);
        fb.puts(",\"cells\":");       fb.putu64(@intCast(num_cells));
        fb.puts(",\"props\":");       fb.putu64(@intCast(num_props));
        fb.puts(",\"run_ns\":");      fb.putu64(self.run_ns);
        fb.puts(",\"by_tag\":[");
        var i: u32 = 0;
        while (i < N_TAGS) : (i += 1) {
            if (i > 0) fb.putc(',');
            fb.putu64(self.fires_by_tag[i]);
        }
        fb.puts("],\"ns_by_tag\":[");
        i = 0;
        while (i < N_TAGS) : (i += 1) {
            if (i > 0) fb.putc(',');
            fb.putu64(self.ns_by_tag[i]);
        }
        fb.puts("]}\n");
        fb.flush_to_stderr();
    }
};

// Per-tag callback profile (hybrid-only). Tracks Racket-callback fire
// time + count separately from total fire time, so the migration triage
// tool can identify which Racket fire-fns dominate runtime.
pub const CallbackProfile = struct {
    callbacks_by_tag: [N_TAGS]u64 = [_]u64{0} ** N_TAGS,
    callback_ns_by_tag: [N_TAGS]u64 = [_]u64{0} ** N_TAGS,

    pub fn reset(self: *CallbackProfile) void {
        var i: u32 = 0;
        while (i < N_TAGS) : (i += 1) {
            self.callbacks_by_tag[i] = 0;
            self.callback_ns_by_tag[i] = 0;
        }
    }

    pub fn print_summary(self: *const CallbackProfile) void {
        var fb = format.FormatBuffer.init();
        fb.puts("CALLBACK-PROFILE: {\"by_tag\":[");
        var i: u32 = 0;
        while (i < N_TAGS) : (i += 1) {
            if (i > 0) fb.putc(',');
            fb.putu64(self.callbacks_by_tag[i]);
        }
        fb.puts("],\"ns_by_tag\":[");
        i = 0;
        while (i < N_TAGS) : (i += 1) {
            if (i > 0) fb.putc(',');
            fb.putu64(self.callback_ns_by_tag[i]);
        }
        fb.puts("]}\n");
        fb.flush_to_stderr();
    }
};
