// prologos-runtime.zig — N0 + propagator BSP scheduler kernel.
//
// The "physics" of the propagator network for the smallest viable runtime.
// Provides:
//
//   prologos_cell_alloc()                    -> u32 cell-id
//                                              shorthand for (DOMAIN_LWW_I64,
//                                              init=0); preserved for
//                                              backward compatibility.
//   prologos_cell_alloc_with_domain(domain, init) -> u32 cell-id
//                                              domain selects per-cell merge
//                                              function. domains:
//                                                0=DOMAIN_LWW_I64
//                                                  (last-write-wins;
//                                                  init typically 0)
//                                                1=DOMAIN_MIN_I64
//                                                  (commutative min-merge;
//                                                  init typically I64_MAX
//                                                  so any later write
//                                                  reduces it)
//                                              See § 5.5 + § 14 Phase 1
//                                              of 2026-05-02_KERNEL_POCKET_UNIVERSES.md.
//   prologos_cell_write(id, val)             -> void
//                                              merging write: dispatches on
//                                              cell domain, applies merge fn
//                                              (val_new = merge(old, val));
//                                              if val_new != old, schedules
//                                              subscribers. Monotone.
//   prologos_cell_reset(id, val)             -> void
//                                              non-merging replacement
//                                              write: bypasses the merge fn,
//                                              replaces cell value, does NOT
//                                              schedule subscribers. Mirrors
//                                              Racket's net-cell-reset (see
//                                              § 5.5 + § 15.9 + design
//                                              Appendix A.2 of
//                                              2026-05-02_KERNEL_POCKET_UNIVERSES.md).
//                                              Conventionally privileged:
//                                              elaborator + scope handlers
//                                              only (enforced by convention,
//                                              matching Racket).
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
// Cells + per-cell merge domain
// =====================================================================
//
// Domain dispatch (Sprint 2026-05-02 Phase 1 Day 1; see
// 2026-05-02_KERNEL_POCKET_UNIVERSES.md § 5.5 + § 14):
//
//   DOMAIN_LWW_I64 (0): merge(old, new) = new      (last-write-wins)
//   DOMAIN_MIN_I64 (1): merge(old, new) = min(old, new)
//                                                  (commutative; bottom = I64_MAX)
//
// Adding a domain = (a) reserve a tag value here, (b) extend
// merge_value(), (c) document the conventional bottom-init in the
// header. cell_reset() bypasses merge for any domain.

pub const DOMAIN_LWW_I64: u8 = 0;
pub const DOMAIN_MIN_I64: u8 = 1;

const I64_MAX: i64 = 0x7fffffffffffffff;

var cells: [MAX_CELLS]i64 = [_]i64{0} ** MAX_CELLS;
var snapshot: [MAX_CELLS]i64 = [_]i64{0} ** MAX_CELLS;
var cell_domain: [MAX_CELLS]u8 = [_]u8{0} ** MAX_CELLS;
var num_cells: u32 = 0;

// merge_value: pure binary merge dispatch. Must be commutative,
// associative, and idempotent for every non-LWW domain (CALM).
// LWW is non-monotone but is the kernel's default for back-compat
// and for the elaborator's explicit-update pattern (replace via
// cell_reset is preferred; LWW cell_write exists for legacy callers
// and the BSP merge phase, where convergence is guaranteed by the
// network's acyclic-or-fuel-bounded shape).
fn merge_value(domain: u8, old: i64, new: i64) i64 {
    return switch (domain) {
        DOMAIN_LWW_I64 => new,
        DOMAIN_MIN_I64 => if (new < old) new else old,
        else => abort(),
    };
}

// Default-bottom init for a domain. Used by prologos_cell_alloc()
// (the no-arg legacy API) and as a documented convention for callers
// of prologos_cell_alloc_with_domain that pass init=0 expecting the
// "natural bottom" (we do NOT silently substitute; callers pass init
// explicitly so the convention is visible at the call site).
fn domain_bottom(domain: u8) i64 {
    return switch (domain) {
        DOMAIN_LWW_I64 => 0,
        DOMAIN_MIN_I64 => I64_MAX,
        else => abort(),
    };
}

// Legacy API: no-arg alloc, returns cell with DOMAIN_LWW_I64 + init=0.
// Equivalent to prologos_cell_alloc_with_domain(DOMAIN_LWW_I64, 0).
// Preserved so existing IR emitters (network-emit.rkt at the time of
// the Phase 1 patch) keep linking unchanged.
export fn prologos_cell_alloc() u32 {
    return prologos_cell_alloc_with_domain(DOMAIN_LWW_I64, 0);
}

// Domain-aware alloc. Caller picks the merge function and the initial
// value. For DOMAIN_MIN_I64 the conventional init is I64_MAX
// (= domain_bottom(DOMAIN_MIN_I64)) so the first write reduces.
//
// Safe to call mid-fire (in_fire_round=true): the new cell-id is
// returned to the caller immediately (no propagator subscribes to it
// yet, so there is no snapshot/race issue), and topo_mutated_this_run
// is asserted so the 2-tier outer loop iterates again.
export fn prologos_cell_alloc_with_domain(domain: u8, init: i64) u32 {
    if (num_cells >= MAX_CELLS) abort();
    if (domain != DOMAIN_LWW_I64 and domain != DOMAIN_MIN_I64) abort();
    const id = num_cells;
    cells[id] = init;
    cell_domain[id] = domain;
    num_cells += 1;
    if (in_fire_round) {
        topo_mutated_this_run = true;
        stat_topo_mutations += 1;
    }
    return id;
}

// Merging write — bypasses the BSP barrier. Used by generated IR at
// module init time (before any propagator runs) and by the BSP
// merge phase. NOT safe to call from inside a fire() — fire() must
// only emit to pending_writes.
//
// Applies the cell's domain merge function: cells[id] := merge(old,
// value). If the merged result differs from the old value, schedules
// subscribers (next round's worklist).
export fn prologos_cell_write(id: u32, value: i64) void {
    if (id >= num_cells) abort();
    const old = cells[id];
    const merged = merge_value(cell_domain[id], old, value);
    if (merged != old) {
        cells[id] = merged;
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

// Non-merging replacement write. Replaces cells[id] with `value`
// outright (bypasses the merge function for the cell's domain) and
// does NOT schedule subscribers. Mirrors Racket's net-cell-reset
// (racket/prologos/propagator.rkt). Conventionally restricted to
// elaborator-emitted IR + scope handlers (enforced by convention,
// matching Racket — see 2026-05-02_KERNEL_POCKET_UNIVERSES.md
// § 15.9 + Appendix A.2).
//
// Statistics: counted under stat_resets, not under
// stat_writes_committed/dropped, so analyses can distinguish
// monotone-merge traffic from explicit-replace traffic.
//
// Calling discipline: like cell_write, NOT safe to call from inside
// a fire() body (a fire() must emit only into pending_writes via the
// scheduler's barrier). Reset is intended for module-init code, scope
// handler bodies (e.g. NAF's publish), and the iteration pattern's
// state-cell rotation between BSP rounds.
export fn prologos_cell_reset(id: u32, value: i64) void {
    if (id >= num_cells) abort();
    cells[id] = value;
    stat_resets += 1;
}

export fn prologos_cell_read(id: u32) i64 {
    if (id >= num_cells) abort();
    return cells[id];
}

// Domain inspection (read-only). Returns the merge-domain tag the
// cell was allocated with. Useful for debug/stat tools and for
// the future Low-PNet → prop-network adapter to assert that
// reset-mode writes target valid domains.
export fn prologos_cell_get_domain(id: u32) u8 {
    if (id >= num_cells) abort();
    return cell_domain[id];
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

// note_topo_mutation(): record an in-fire topology mutation so the
// 2-tier outer loop iterates again. No-op outside a fire round.
fn note_topo_mutation() void {
    if (in_fire_round) {
        topo_mutated_this_run = true;
        stat_topo_mutations += 1;
    }
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
    note_topo_mutation();
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
    note_topo_mutation();
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
    note_topo_mutation();
    return pid;
}

// =====================================================================
// Scheduler — BSP worklist with snapshot/diff/merge + 2-tier outer loop
// =====================================================================
//
// 2-tier outer loop (§ 5.2 + § 5.7 of 2026-05-02_KERNEL_POCKET_UNIVERSES.md):
//
//   outer-while (until both tiers quiescent):
//     tier 1 — TOPOLOGY: any cell_alloc / prop_install calls deferred from
//              the previous tier-2 fire round are applied here.
//              Newly-installed props were already scheduled (via schedule())
//              when their install ran; we just need to swap_worklists()
//              so they enter the next inner-while iteration.
//     tier 2 — VALUE: BSP value rounds until quiescent (worklist drained).
//
// In-fire-round flag (`in_fire_round`):
//   - Set to true around the fire phase of an inner BSP round.
//   - When true, prop_install / cell_alloc set `topo_mutated_this_run`
//     so the outer loop knows to iterate again even after value
//     quiescence. Reads (cell_read) consult the snapshot, not cells[].
//   - Currently no fire-fn dispatched by this kernel calls alloc/install
//     (fire-fns are pure compute). The flag is structural — Phase 5's
//     handler propagators will rely on it.

var worklist:      [MAX_PROPS]u32 = undefined;  // current round's pending pids
var worklist_len:  u32 = 0;
var next_worklist: [MAX_PROPS]u32 = undefined;  // built during merge phase
var next_worklist_len: u32 = 0;

// True while the kernel is executing a fire-fn body (between
// take_snapshot() and merge_pending_writes()). Used to detect
// mid-fire topology mutations and to discriminate immediate-mode
// vs within-round operations.
var in_fire_round: bool = false;
// Set to true any time an alloc or install runs while in_fire_round is
// true. Sampled (and cleared) by the outer loop after value quiescence
// to decide whether to do another outer iteration.
var topo_mutated_this_run: bool = false;

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

// 2-tier outer loop driver. See § 5.2 + § 5.7 of
// 2026-05-02_KERNEL_POCKET_UNIVERSES.md.
//
// Each outer iteration:
//   tier 1 (topology) — apply pending topology mutations (currently a
//                       single swap_worklists() to move install-time
//                       schedule() additions onto the active worklist)
//   tier 2 (value)    — drain BSP value rounds until worklist empty
//
// After tier 2 quiesces, if topo_mutated_this_run was asserted by an
// install/alloc that ran inside a fire (in_fire_round=true), we loop
// for another outer iteration. Otherwise we terminate.
//
// Termination: outer loop exits when value-quiescent (worklist + next
// both empty) AND no fire-time topology mutations occurred during
// the just-completed value tier. Bounded by the global fuel counter
// (max_rounds), counted in inner-round granularity.
export fn prologos_run_to_quiescence() void {
    const start_ns = now_ns();

    // Outer iteration 0's tier 1: drain install-time schedule() additions
    // into the active worklist so the first inner round has work.
    swap_worklists();

    var any_inner_progress: bool = true;
    while (any_inner_progress or topo_mutated_this_run) {
        // Outer tier 1 — TOPOLOGY (between-round application).
        // Newly-installed propagators were scheduled into next_worklist
        // at install time; promote them so this outer iter's value tier
        // can fire them.
        if (worklist_len == 0 and next_worklist_len > 0) {
            swap_worklists();
        }
        // Reset the "topology mutated during fire" sticky bit before the
        // value tier so we sample only mutations from this iteration.
        topo_mutated_this_run = false;
        stat_outer_iters += 1;

        // Outer tier 2 — VALUE (BSP rounds until worklist drained).
        any_inner_progress = run_value_tier();

        // If max_rounds is set and was hit inside the value tier,
        // run_value_tier returns false and stat_fuel_exhausted is set;
        // we exit here.
        if (stat_fuel_exhausted != 0) break;

        // If the value tier did topology mutations (Phase 5 handlers),
        // we need another outer iteration to apply them.
        if (topo_mutated_this_run) {
            any_inner_progress = true; // force re-entry
        }
    }

    stat_run_ns += now_ns() - start_ns;
}

// run_value_tier: drain BSP value rounds until worklist is empty or
// fuel is exhausted. Returns true if any round fired (i.e. there was
// at least one progress event), false if the worklist was already
// empty at entry or fuel was exhausted on entry.
fn run_value_tier() bool {
    var fired_any: bool = false;
    while (worklist_len > 0) {
        if (max_rounds != 0 and stat_rounds >= max_rounds) {
            stat_fuel_exhausted = 1;
            return fired_any;
        }
        stat_rounds += 1;
        take_snapshot();

        // Mark the fire phase. fire-fns dispatched here are pure compute
        // for the kernel's current tag set, but Phase 5's handler
        // propagators will use this flag to call alloc/install and have
        // them recorded as mid-fire topology mutations.
        in_fire_round = true;
        var i: u32 = 0;
        while (i < worklist_len) : (i += 1) {
            const pid = worklist[i];
            in_worklist[pid] = 0;
            fire_against_snapshot(pid);
        }
        in_fire_round = false;
        worklist_len = 0;

        // Barrier: merge pending writes; subscribers of changed cells
        // land in next_worklist via prologos_cell_write's schedule path.
        merge_pending_writes();
        swap_worklists();
        fired_any = true;
    }
    return fired_any;
}

// Test-only hook: simulate a propagator install happening from inside
// a fire-fn body. Mirrors prologos_propagator_install_2_1 but flips
// in_fire_round around the call so the install records as a mid-fire
// topology mutation. Used by test-substrate.c to exercise the 2-tier
// outer loop's topology-tracking path.
//
// (Phase 5 will replace this with a real handler-propagator fire-fn
// that calls install during its own dispatch. For Phase 1 we expose
// this hook so the gate test can prove the structure works without
// requiring fire-fn function pointers.)
export fn prologos_test_install_during_fire_2_1(
    tag: u32,
    in0: u32,
    in1: u32,
    out0: u32,
) u32 {
    in_fire_round = true;
    const pid = prologos_propagator_install_2_1(tag, in0, in1, out0);
    in_fire_round = false;
    return pid;
}

// Test-only hook: simulate a cell allocation from inside a fire-fn body.
// Same shape as prologos_test_install_during_fire_2_1 but for cells.
export fn prologos_test_alloc_during_fire(domain: u8, init: i64) u32 {
    in_fire_round = true;
    const id = prologos_cell_alloc_with_domain(domain, init);
    in_fire_round = false;
    return id;
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
var stat_resets: u64 = 0;          // explicit-replace traffic (cell_reset)
var stat_topo_mutations: u64 = 0;  // alloc/install calls inside a fire round
var stat_outer_iters: u64 = 0;     // 2-tier outer-loop iterations
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
//   9  resets (explicit-replace traffic; cell_reset count)
//   10 topo_mutations (mid-fire cell_alloc + prop_install count)
//   11 outer_iters   (2-tier outer-loop iteration count for the
//                     last + cumulative run_to_quiescence calls)
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
        9 => stat_resets,
        10 => stat_topo_mutations,
        11 => stat_outer_iters,
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
    stat_resets = 0;
    stat_topo_mutations = 0;
    stat_outer_iters = 0;
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
    buf_puts(",\"resets\":");      buf_putu64(stat_resets);
    buf_puts(",\"topo_muts\":");   buf_putu64(stat_topo_mutations);
    buf_puts(",\"outer_iters\":"); buf_putu64(stat_outer_iters);
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
