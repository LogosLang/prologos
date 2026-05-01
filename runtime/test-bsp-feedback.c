// test-bsp-feedback.c — validate BSP scheduler under cell feedback.
//
// Builds cyclic networks via the kernel API directly (no compiler in
// the loop) and checks that the BSP barrier keeps reads/writes
// consistent across rounds. This is the structural test for Sprint E:
// once feedback works at the kernel level, source-level iterative
// forms (Sprint E.3) can target it.
//
// Test 1 — counter: counter_next = counter + 1; counter ← counter_next.
//   With max_rounds=N, counter advances ⌊N/2⌋ times (each increment
//   takes 2 BSP rounds: compute counter_next, then feedback to counter).
//
// Test 2 — iterative fib(N) via gated next-state: each iteration uses
//   continue = (i < N) and three select propagators to either advance
//   (a, b, i) ← (b, a+b, i+1) or stay frozen. The network terminates
//   on its own once i reaches N (no further cell changes).

#include <stdio.h>
#include <stdint.h>

extern uint32_t prologos_cell_alloc(void);
extern void     prologos_cell_write(uint32_t, int64_t);
extern int64_t  prologos_cell_read(uint32_t);
extern uint32_t prologos_propagator_install_1_1(uint32_t tag, uint32_t in0, uint32_t out);
extern uint32_t prologos_propagator_install_2_1(uint32_t tag, uint32_t in0, uint32_t in1, uint32_t out);
extern uint32_t prologos_propagator_install_3_1(uint32_t tag, uint32_t in0, uint32_t in1, uint32_t in2, uint32_t out);
extern void     prologos_run_to_quiescence(void);
extern void     prologos_set_max_rounds(uint64_t);
extern uint64_t prologos_get_stat(uint32_t);
extern void     prologos_reset_stats(void);
extern void     prologos_print_stats(void);

#define ASSERT_EQ(name, got, expected) do {                          \
    if ((int64_t)(got) != (int64_t)(expected)) {                     \
        fprintf(stderr, "FAIL %s: got=%lld expected=%lld\n",         \
            (name), (long long)(got), (long long)(expected));        \
        return 1;                                                    \
    }                                                                \
} while (0)

// ---------- Test 1: counter ----------
static int test_counter(void) {
    prologos_reset_stats();
    uint32_t counter      = prologos_cell_alloc();  prologos_cell_write(counter, 0);
    uint32_t one          = prologos_cell_alloc();  prologos_cell_write(one, 1);
    uint32_t counter_next = prologos_cell_alloc();  prologos_cell_write(counter_next, 0);

    // counter_next = counter + 1
    prologos_propagator_install_2_1(0 /* int-add */, counter, one, counter_next);
    // counter ← counter_next  (feedback)
    prologos_propagator_install_1_1(0 /* identity */, counter_next, counter);

    // 11 rounds = 5 full increments + 1 terminal round.
    // Each increment is 2 rounds (compute, then feedback).
    prologos_set_max_rounds(11);
    prologos_run_to_quiescence();

    int64_t final = prologos_cell_read(counter);
    fprintf(stderr, "test1: counter after 11 rounds = %lld (expect 5)\n",
            (long long)final);
    ASSERT_EQ("counter final", final, 5);
    return 0;
}

// ---------- Test 2: iterative fib(N) ----------
static int test_iter_fib(int N, int64_t expected) {
    prologos_reset_stats();
    prologos_set_max_rounds(0);  // unlimited; the network self-terminates

    // State cells
    uint32_t a   = prologos_cell_alloc();  prologos_cell_write(a, 0);
    uint32_t b   = prologos_cell_alloc();  prologos_cell_write(b, 1);
    uint32_t i   = prologos_cell_alloc();  prologos_cell_write(i, 0);
    // Constants
    uint32_t one = prologos_cell_alloc();  prologos_cell_write(one, 1);
    uint32_t Nc  = prologos_cell_alloc();  prologos_cell_write(Nc, N);
    // Step results (computed each iteration)
    uint32_t a_step = prologos_cell_alloc();  prologos_cell_write(a_step, 0);
    uint32_t b_step = prologos_cell_alloc();  prologos_cell_write(b_step, 0);
    uint32_t i_step = prologos_cell_alloc();  prologos_cell_write(i_step, 0);
    // Continue flag
    uint32_t cont   = prologos_cell_alloc();  prologos_cell_write(cont, 0);
    // Next-state cells
    uint32_t a_next = prologos_cell_alloc();  prologos_cell_write(a_next, 0);
    uint32_t b_next = prologos_cell_alloc();  prologos_cell_write(b_next, 1);
    uint32_t i_next = prologos_cell_alloc();  prologos_cell_write(i_next, 0);

    // Step propagators (the iteration "function")
    prologos_propagator_install_1_1(0,        b,   a_step);  // a_step = b
    prologos_propagator_install_2_1(0, a, b,   b_step);      // b_step = a + b
    prologos_propagator_install_2_1(0, i, one, i_step);      // i_step = i + 1
    // Continue gate
    prologos_propagator_install_2_1(5, i, Nc,  cont);        // cont = (i < N)
    // Next-state via select(cont, step, current). When cont=0 we freeze.
    prologos_propagator_install_3_1(0, cont, a_step, a, a_next);
    prologos_propagator_install_3_1(0, cont, b_step, b, b_next);
    prologos_propagator_install_3_1(0, cont, i_step, i, i_next);
    // Feedback edges
    prologos_propagator_install_1_1(0, a_next, a);
    prologos_propagator_install_1_1(0, b_next, b);
    prologos_propagator_install_1_1(0, i_next, i);

    prologos_run_to_quiescence();

    int64_t fib_N = prologos_cell_read(a);
    int64_t i_final = prologos_cell_read(i);
    int64_t cont_final = prologos_cell_read(cont);
    fprintf(stderr,
            "test2: fib(%d) = %lld (expect %lld), i=%lld, cont=%lld, "
            "rounds=%llu, fires=%llu, max_worklist=%llu\n",
            N, (long long)fib_N, (long long)expected,
            (long long)i_final, (long long)cont_final,
            (unsigned long long)prologos_get_stat(0),
            (unsigned long long)prologos_get_stat(1),
            (unsigned long long)prologos_get_stat(4));
    ASSERT_EQ("fib(N)", fib_N, expected);
    ASSERT_EQ("i terminated at N", i_final, N);
    ASSERT_EQ("cont = 0 at termination", cont_final, 0);
    if (prologos_get_stat(5) /* fuel_exhausted */ != 0) {
        fprintf(stderr, "FAIL fib(%d): fuel exhausted (network did not self-terminate)\n", N);
        return 1;
    }
    return 0;
}

int main(void) {
    if (test_counter()) return 1;
    // Validate against pre-computed fib values:
    //   fib(0)=0, fib(1)=1, fib(2)=1, fib(5)=5, fib(10)=55, fib(20)=6765
    if (test_iter_fib(0,  0))    return 1;
    if (test_iter_fib(1,  1))    return 1;
    if (test_iter_fib(2,  1))    return 1;
    if (test_iter_fib(5,  5))    return 1;
    if (test_iter_fib(10, 55))   return 1;
    if (test_iter_fib(20, 6765)) return 1;
    fprintf(stderr, "test-bsp-feedback: ALL PASSED\n");
    return 0;
}
