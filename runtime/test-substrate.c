/* test-substrate.c — kernel substrate tests (Phase 1 Day 1).
 *
 * Per 2026-05-02_KERNEL_POCKET_UNIVERSES.md § 14 (Phase 1 deliverable list)
 * and § 15.9 (merge-vs-reset distinguishability gate).
 *
 * Validates:
 *   - prologos_cell_alloc_with_domain() with DOMAIN_MIN_I64 init works
 *   - prologos_cell_alloc() preserves legacy LWW + init=0 semantics
 *   - prologos_cell_get_domain reports the chosen domain
 *   - prologos_cell_write applies the cell's domain merge fn
 *     (commutative + idempotent for min-merge: write(5)+write(3)+write(5)
 *      converges to 3 regardless of order)
 *   - prologos_cell_reset bypasses the merge fn (can replace 3 → 7 on a
 *     min-merge cell, the very behaviour merge would forbid)
 *   - prologos_cell_reset does NOT enqueue subscribers
 *     (a downstream propagator subscribed to a reset-only cell does
 *      not fire even though the cell value changed)
 *   - prologos_cell_write DOES enqueue subscribers when the merged
 *     value differs from old (round-trip via the BSP scheduler)
 *   - stat_resets (key 9) tracks reset traffic; stat_writes_committed
 *     (key 2) tracks merging-write traffic
 *
 * Build: clang test-substrate.c prologos-runtime.o -o /tmp/test-substrate
 * Run:   /tmp/test-substrate     (exit 0 = all assertions passed)
 */

#include <stdio.h>
#include <stdint.h>

extern uint32_t prologos_cell_alloc(void);
extern uint32_t prologos_cell_alloc_with_domain(uint8_t domain, int64_t init);
extern void     prologos_cell_write(uint32_t id, int64_t value);
extern void     prologos_cell_reset(uint32_t id, int64_t value);
extern int64_t  prologos_cell_read(uint32_t id);
extern uint8_t  prologos_cell_get_domain(uint32_t id);
extern uint32_t prologos_propagator_install_1_1(uint32_t tag, uint32_t in0, uint32_t out0);
extern uint32_t prologos_propagator_install_2_1(uint32_t tag, uint32_t in0, uint32_t in1, uint32_t out0);
extern uint32_t prologos_test_install_during_fire_2_1(uint32_t tag, uint32_t in0, uint32_t in1, uint32_t out0);
extern uint32_t prologos_test_alloc_during_fire(uint8_t domain, int64_t init);
extern void     prologos_run_to_quiescence(void);
extern uint64_t prologos_get_stat(uint32_t key);
extern void     prologos_reset_stats(void);

extern uint32_t prologos_scope_enter(uint64_t parent_fuel_charge);
extern uint8_t  prologos_scope_run(uint32_t sid, uint64_t fuel);
extern int64_t  prologos_scope_read(uint32_t sid, uint32_t cell);
extern void     prologos_scope_exit(uint32_t sid);
extern uint32_t prologos_scope_depth(void);
extern uint8_t  prologos_scope_get_last_result(uint32_t sid);

#define RUN_RESULT_HALT            0
#define RUN_RESULT_FUEL_EXHAUSTED  1
#define RUN_RESULT_TRAP            2

#define DOMAIN_LWW_I64  0
#define DOMAIN_MIN_I64  1

static const int64_t I64_MAX_C = 0x7fffffffffffffffLL;

#define ASSERT_EQ(name, got, expected) do {                             \
    if ((int64_t)(got) != (int64_t)(expected)) {                        \
        fprintf(stderr, "FAIL %s: got=%lld expected=%lld (%s:%d)\n",    \
            (name), (long long)(got), (long long)(expected),            \
            __FILE__, __LINE__);                                        \
        return 1;                                                       \
    }                                                                   \
} while (0)

int main(void) {
    /* -------- T1: legacy alloc preserves LWW + init=0 -------- */
    uint32_t c_legacy = prologos_cell_alloc();
    ASSERT_EQ("T1.domain", prologos_cell_get_domain(c_legacy), DOMAIN_LWW_I64);
    ASSERT_EQ("T1.init",   prologos_cell_read(c_legacy),       0);
    prologos_cell_write(c_legacy, 42);
    ASSERT_EQ("T1.write",  prologos_cell_read(c_legacy),       42);
    prologos_cell_write(c_legacy, 7);  /* LWW: replace */
    ASSERT_EQ("T1.lww",    prologos_cell_read(c_legacy),       7);

    /* -------- T2: min-merge i64 domain, commutative + idempotent -------- */
    uint32_t c_min = prologos_cell_alloc_with_domain(DOMAIN_MIN_I64, I64_MAX_C);
    ASSERT_EQ("T2.domain", prologos_cell_get_domain(c_min),    DOMAIN_MIN_I64);
    ASSERT_EQ("T2.init",   prologos_cell_read(c_min),          I64_MAX_C);

    prologos_cell_write(c_min, 5);   /* min(MAX, 5) = 5 */
    ASSERT_EQ("T2.first",  prologos_cell_read(c_min),          5);

    prologos_cell_write(c_min, 3);   /* min(5, 3)   = 3 */
    ASSERT_EQ("T2.lower",  prologos_cell_read(c_min),          3);

    prologos_cell_write(c_min, 5);   /* min(3, 5)   = 3, no change */
    ASSERT_EQ("T2.greater_no_change", prologos_cell_read(c_min), 3);

    prologos_cell_write(c_min, 3);   /* idempotent */
    ASSERT_EQ("T2.idempotent", prologos_cell_read(c_min),      3);

    /* -------- T3: cell_reset bypasses merge on min-merge cell -------- */
    /* This is the core distinguishability gate: under merging semantics,
     * write(c_min, 7) when current=3 would be a no-op (min(3,7)=3).
     * reset(c_min, 7) outright replaces. */
    prologos_cell_reset(c_min, 7);
    ASSERT_EQ("T3.reset_replaces", prologos_cell_read(c_min),  7);

    /* And reset can also lower (no merge dispatch at all) */
    prologos_cell_reset(c_min, 100);
    ASSERT_EQ("T3.reset_higher", prologos_cell_read(c_min),    100);

    /* -------- T4: stat_resets vs stat_writes_committed -------- */
    /* Reset stats so we can count cleanly going forward. T1+T2+T3 above
     * already exercised both code paths; verify the counter exists and
     * that further writes/resets accumulate as expected. */
    prologos_reset_stats();
    uint32_t c_count = prologos_cell_alloc_with_domain(DOMAIN_MIN_I64, I64_MAX_C);
    prologos_cell_write(c_count, 10); /* committed (MAX → 10) */
    prologos_cell_write(c_count, 8);  /* committed (10 → 8)  */
    prologos_cell_write(c_count, 9);  /* dropped (min stays 8) */
    prologos_cell_reset(c_count, 1);  /* reset */
    prologos_cell_reset(c_count, 2);  /* reset */
    ASSERT_EQ("T4.committed", prologos_get_stat(2), 2);
    ASSERT_EQ("T4.dropped",   prologos_get_stat(3), 1);
    ASSERT_EQ("T4.resets",    prologos_get_stat(9), 2);

    /* -------- T5: cell_write DOES enqueue subscribers on a change -------- */
    /* Build: c_w (LWW) --[identity]--> c_out (LWW). Write a new value to c_w;
     * BSP run should fire the identity propagator and propagate the value
     * to c_out. */
    prologos_reset_stats();
    uint32_t c_w   = prologos_cell_alloc();
    uint32_t c_out = prologos_cell_alloc();
    prologos_propagator_install_1_1(0 /* identity */, c_w, c_out);
    /* Install schedules the prop once already; run to clear initial state. */
    prologos_run_to_quiescence();
    ASSERT_EQ("T5.initial_propagation", prologos_cell_read(c_out), 0);

    prologos_reset_stats();
    prologos_cell_write(c_w, 99);          /* should enqueue identity */
    prologos_run_to_quiescence();
    ASSERT_EQ("T5.merged_propagated", prologos_cell_read(c_out), 99);
    /* Verify the identity propagator did fire (>=1 round). */
    if (prologos_get_stat(1 /* fires_total */) < 1) {
        fprintf(stderr, "FAIL T5.fires: expected >=1, got %llu\n",
                (unsigned long long)prologos_get_stat(1));
        return 1;
    }

    /* -------- T6: cell_reset does NOT enqueue subscribers -------- */
    /* Same topology as T5, but use reset to change c_w. The identity
     * propagator must NOT fire, so c_out stays at its previous value. */
    prologos_reset_stats();
    int64_t c_out_before = prologos_cell_read(c_out);
    prologos_cell_reset(c_w, 12345);
    prologos_run_to_quiescence();
    /* c_out should be unchanged because reset bypassed the schedule. */
    ASSERT_EQ("T6.no_propagation", prologos_cell_read(c_out), c_out_before);
    /* And no rounds should have run (worklist was empty at entry). */
    ASSERT_EQ("T6.zero_rounds", prologos_get_stat(0), 0);
    ASSERT_EQ("T6.zero_fires",  prologos_get_stat(1), 0);
    /* The reset itself was counted. */
    ASSERT_EQ("T6.reset_counted", prologos_get_stat(9), 1);

    /* -------- T7: a propagator writing into a min-merge cell -------- */
    /* (a, b) ---add--> sum (min-merge). Run, observe sum=5+3=8.
     * Then change a to 1, run again: add yields 4, min(8, 4)=4.
     * Then change a to 100, run: add yields 103, min(4, 103)=4 unchanged. */
    prologos_reset_stats();
    uint32_t a    = prologos_cell_alloc();         /* LWW */
    uint32_t b    = prologos_cell_alloc();         /* LWW */
    uint32_t sum  = prologos_cell_alloc_with_domain(DOMAIN_MIN_I64, I64_MAX_C);
    prologos_cell_write(a, 5);
    prologos_cell_write(b, 3);
    prologos_propagator_install_2_1(0 /* int-add */, a, b, sum);
    prologos_run_to_quiescence();
    ASSERT_EQ("T7.first_sum", prologos_cell_read(sum), 8);

    prologos_cell_write(a, 1); /* triggers add -> 4, min(8,4)=4 */
    prologos_run_to_quiescence();
    ASSERT_EQ("T7.lower_sum", prologos_cell_read(sum), 4);

    prologos_cell_write(a, 100); /* triggers add -> 103, min(4,103)=4 */
    prologos_run_to_quiescence();
    ASSERT_EQ("T7.no_increase", prologos_cell_read(sum), 4);

    /* ====================================================================
     *  Day 2 tests: 2-tier outer loop + topology-mutation tracking
     * ==================================================================== */

    /* -------- T8: 2-tier outer loop runs at least once on plain runs -------- */
    /* Build d ---identity---> e and run; outer_iters should be >= 1, and
     * topo_mutations should remain 0 because no fire-fn allocates/installs. */
    prologos_reset_stats();
    uint32_t d = prologos_cell_alloc();
    uint32_t e = prologos_cell_alloc();
    prologos_propagator_install_1_1(0 /* identity */, d, e);
    prologos_cell_write(d, 77);
    prologos_run_to_quiescence();
    ASSERT_EQ("T8.value_propagated", prologos_cell_read(e), 77);
    if (prologos_get_stat(11 /* outer_iters */) < 1) {
        fprintf(stderr, "FAIL T8.outer_iters: expected >=1, got %llu\n",
                (unsigned long long)prologos_get_stat(11));
        return 1;
    }
    ASSERT_EQ("T8.no_topo_mutations", prologos_get_stat(10 /* topo */), 0);

    /* -------- T9: install during fire records as topology mutation -------- */
    /* Use the test hook to install a propagator while in_fire_round=true.
     * Verify the mutation is counted. The new propagator was scheduled by
     * install; running again drains it. */
    prologos_reset_stats();
    uint32_t f = prologos_cell_alloc();
    uint32_t g = prologos_cell_alloc();
    /* Manually install a relay using the in-fire hook. */
    prologos_test_install_during_fire_2_1(0 /* int-add */, d, f, g);
    ASSERT_EQ("T9.topo_recorded", prologos_get_stat(10 /* topo */), 1);
    /* d is still 77 (from T8). f starts at 0 (default LWW init). 77+0=77. */
    prologos_cell_write(f, 100);
    prologos_run_to_quiescence();
    ASSERT_EQ("T9.add_correct", prologos_cell_read(g), 177);

    /* -------- T10: alloc during fire records as topology mutation -------- */
    /* Use the alloc hook; the new cell must have correct domain + init. */
    prologos_reset_stats();
    uint32_t fresh = prologos_test_alloc_during_fire(DOMAIN_MIN_I64, I64_MAX_C);
    ASSERT_EQ("T10.domain", prologos_cell_get_domain(fresh), DOMAIN_MIN_I64);
    ASSERT_EQ("T10.init",   prologos_cell_read(fresh),       I64_MAX_C);
    ASSERT_EQ("T10.topo_recorded", prologos_get_stat(10 /* topo */), 1);
    prologos_cell_write(fresh, 42); /* min(MAX, 42) = 42 */
    prologos_run_to_quiescence();
    ASSERT_EQ("T10.merge_works", prologos_cell_read(fresh), 42);

    /* -------- T11: outer loop iterates on mid-run topology mutation -------- */
    /* Setup: chain h ---identity---> i. Run; quiesces in 1 outer iter.
     * Then use the test hook to install (h,i)→j during a simulated fire.
     * Run; outer_iters should reflect the additional iteration triggered
     * by the topology mutation that the install marker set. */
    prologos_reset_stats();
    uint32_t h = prologos_cell_alloc();
    uint32_t ii = prologos_cell_alloc(); /* `i` is the loop counter elsewhere */
    prologos_propagator_install_1_1(0 /* identity */, h, ii);
    prologos_cell_write(h, 5);
    prologos_run_to_quiescence();
    ASSERT_EQ("T11.first_value",  prologos_cell_read(ii), 5);
    uint64_t outer_after_first = prologos_get_stat(11);
    if (outer_after_first < 1) {
        fprintf(stderr, "FAIL T11.outer_after_first: expected >=1, got %llu\n",
                (unsigned long long)outer_after_first);
        return 1;
    }

    /* Now: simulate a handler that installs a new prop during the fire phase.
     * The 2-tier loop should pick up the mutation and run another outer
     * iteration (during which the new prop fires). */
    uint32_t j = prologos_cell_alloc();
    prologos_test_install_during_fire_2_1(0 /* int-add */, h, ii, j);
    /* run_to_quiescence: outer-iter 1 immediately sees worklist has the
     * new prop (install scheduled it), drains the value tier, j = 5+5 = 10.
     * topo_mutated_this_run was set by install (which set it to true), so
     * outer-iter 2 may also run (but with empty worklist and topo cleared,
     * any_inner_progress=false on entry, then exits). */
    prologos_run_to_quiescence();
    ASSERT_EQ("T11.j_value", prologos_cell_read(j), 10);
    /* Verify additional outer iterations occurred since the previous run. */
    if (prologos_get_stat(11 /* outer_iters */) <= outer_after_first) {
        fprintf(stderr, "FAIL T11.outer_iters_grew: expected >%llu, got %llu\n",
                (unsigned long long)outer_after_first,
                (unsigned long long)prologos_get_stat(11));
        return 1;
    }

    /* -------- T_scope_smoke: scope_enter/run/read/exit basic shape -------- */
    /* Day 3 deliverable smoke: prove the four scope APIs link and exhibit
     * the documented stack-discipline. Full isolation tests (fuel,
     * write-isolation, explicit-publish, trap, nested) ship Day 4. */
    {
        prologos_reset_stats();
        uint32_t depth_before = prologos_scope_depth();
        if (depth_before < 1) {
            fprintf(stderr,
                "FAIL scope_smoke.depth_before: expected >=1 (root), got %u\n",
                depth_before);
            return 1;
        }
        uint32_t sid = prologos_scope_enter(0);
        ASSERT_EQ("scope_smoke.depth_after_enter",
                  prologos_scope_depth(), depth_before + 1);
        ASSERT_EQ("scope_smoke.enters_stat", prologos_get_stat(12), 1);

        uint8_t r = prologos_scope_run(sid, 100);
        ASSERT_EQ("scope_smoke.run_result_halt", r, RUN_RESULT_HALT);
        ASSERT_EQ("scope_smoke.runs_stat", prologos_get_stat(13), 1);

        int64_t v = prologos_scope_read(sid, 0); /* root cell 0 from T1 = 7 (LWW final) */
        ASSERT_EQ("scope_smoke.read_inherits_root", v, 7);

        prologos_scope_exit(sid);
        ASSERT_EQ("scope_smoke.depth_after_exit",
                  prologos_scope_depth(), depth_before);
        ASSERT_EQ("scope_smoke.exits_stat", prologos_get_stat(14), 1);
    }

    /* -------- T12: regression — between-call install still fires -------- */
    /* Standard pattern: install between explicit run_to_quiescence calls
     * (no fire-round emulation). Outer_iters bumps by exactly 1 per call;
     * topo_mutations stays at 0 because install was outside any fire. */
    prologos_reset_stats();
    uint32_t p = prologos_cell_alloc();
    uint32_t q = prologos_cell_alloc();
    prologos_cell_write(p, 12);
    prologos_propagator_install_1_1(0 /* identity */, p, q);
    prologos_run_to_quiescence();
    ASSERT_EQ("T12.value", prologos_cell_read(q), 12);
    ASSERT_EQ("T12.no_topo", prologos_get_stat(10), 0);
    if (prologos_get_stat(11) < 1) {
        fprintf(stderr, "FAIL T12.outer_iters: expected >=1, got %llu\n",
                (unsigned long long)prologos_get_stat(11));
        return 1;
    }

    fprintf(stderr, "test-substrate: ALL PASSED\n");
    return 0;
}
