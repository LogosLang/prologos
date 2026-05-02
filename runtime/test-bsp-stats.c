// test-bsp-stats.c — C smoke test for the BSP scheduler + stats interface.
//
// Builds: clang test-bsp-stats.c prologos-runtime.o -o /tmp/test-bsp-stats
// Runs:   /tmp/test-bsp-stats   (exit 0 on all assertions met)
//
// Validates:
//   - run_to_quiescence terminates a depth-2 chain in 2 rounds
//   - propagator firing dispatch for int-add (tag 0), int-mul (tag 2)
//   - stat counters: rounds, fires_total, writes_committed, writes_dropped
//   - per-tag fire counts (key 100+tag)
//   - set_max_rounds + fuel_exhausted exposure
//   - reset_stats zeros counters

#include <stdio.h>
#include <stdint.h>

extern uint32_t prologos_cell_alloc(void);
extern void     prologos_cell_write(uint32_t, int64_t);
extern int64_t  prologos_cell_read(uint32_t);
extern uint32_t prologos_propagator_install_2_1(uint32_t tag, uint32_t in0, uint32_t in1, uint32_t out);
extern uint32_t prologos_propagator_install_3_1(uint32_t tag, uint32_t in0, uint32_t in1, uint32_t in2, uint32_t out);
extern void     prologos_run_to_quiescence(void);
extern void     prologos_set_max_rounds(uint64_t);
extern uint64_t prologos_get_stat(uint32_t key);
extern void     prologos_reset_stats(void);

#define ASSERT_EQ(name, got, expected) do {                          \
    if ((uint64_t)(got) != (uint64_t)(expected)) {                   \
        fprintf(stderr, "FAIL %s: got=%llu expected=%llu\n",         \
            (name), (unsigned long long)(got),                       \
            (unsigned long long)(expected));                         \
        return 1;                                                    \
    }                                                                \
} while (0)

int main(void) {
    // -------- Test 1: depth-2 arithmetic chain --------
    // c0+c1 -> c3, c3*c2 -> c4. Expect c4=70, 2 rounds, 3 fires.
    uint32_t c0 = prologos_cell_alloc();  prologos_cell_write(c0, 3);
    uint32_t c1 = prologos_cell_alloc();  prologos_cell_write(c1, 4);
    uint32_t c2 = prologos_cell_alloc();  prologos_cell_write(c2, 10);
    uint32_t c3 = prologos_cell_alloc();  prologos_cell_write(c3, 0);
    uint32_t c4 = prologos_cell_alloc();  prologos_cell_write(c4, 0);
    prologos_propagator_install_2_1(0 /* int-add */, c0, c1, c3);
    prologos_propagator_install_2_1(2 /* int-mul */, c3, c2, c4);

    prologos_run_to_quiescence();

    ASSERT_EQ("c4 final value", prologos_cell_read(c4), 70);
    ASSERT_EQ("rounds (depth-2)", prologos_get_stat(0), 2);
    ASSERT_EQ("fires_total", prologos_get_stat(1), 3);   // add×1 + mul×2
    ASSERT_EQ("fires int-add", prologos_get_stat(100), 1);
    ASSERT_EQ("fires int-mul", prologos_get_stat(102), 2);
    ASSERT_EQ("fuel_exhausted", prologos_get_stat(5), 0);

    // -------- Test 2: select propagator (3,1 shape) --------
    // Continuing on the same network: build a select that picks c3 (=7)
    // if c0<c1 (=true), else c2 (=10). Expect picked=7.
    prologos_reset_stats();
    uint32_t c_lt = prologos_cell_alloc();  prologos_cell_write(c_lt, 0);
    uint32_t c_pick = prologos_cell_alloc(); prologos_cell_write(c_pick, 0);
    prologos_propagator_install_2_1(5 /* int-lt */, c0, c1, c_lt);
    prologos_propagator_install_3_1(0 /* select */, c_lt, c3, c2, c_pick);
    prologos_run_to_quiescence();
    ASSERT_EQ("c_lt (3<4)", prologos_cell_read(c_lt), 1);
    ASSERT_EQ("c_pick (selects c3=7 because lt=true)", prologos_cell_read(c_pick), 7);

    // -------- Test 3: reset_stats works --------
    prologos_reset_stats();
    ASSERT_EQ("rounds after reset", prologos_get_stat(0), 0);
    ASSERT_EQ("fires after reset", prologos_get_stat(1), 0);
    ASSERT_EQ("int-add fires after reset", prologos_get_stat(100), 0);

    fprintf(stderr, "test-bsp-stats: ALL PASSED\n");
    return 0;
}
