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
extern void     prologos_run_to_quiescence(void);
extern uint64_t prologos_get_stat(uint32_t key);
extern void     prologos_reset_stats(void);

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

    fprintf(stderr, "test-substrate: ALL PASSED\n");
    return 0;
}
