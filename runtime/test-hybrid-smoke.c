// test-hybrid-smoke.c — smoke test for prologos-runtime-hybrid.
//
// Validates: cell alloc + tagged box/unbox + 2-1 propagator with built-in
// kernel fire-fn (int-add) + run-to-quiescence + cell read.
//
// Build:
//   cc -o test-hybrid-smoke test-hybrid-smoke.c libprologos-runtime-hybrid.so

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

extern uint32_t prologos_cell_alloc(void);
extern void prologos_cell_write(uint32_t id, int64_t value);
extern int64_t prologos_cell_read(uint32_t id);
extern uint32_t prologos_propagator_install_2_1(
    uint32_t tag, uint32_t in0, uint32_t in1, uint32_t out0);
extern uint32_t prologos_propagator_install_n_1(
    uint32_t tag, const uint32_t* inputs, uint32_t num_inputs, uint32_t out0);
extern uint32_t prologos_register_fire_fn(
    uint32_t tag, uint32_t shape, uint32_t kind, const void* fn_ptr);
extern void prologos_run_to_quiescence(void);
extern void prologos_print_stats(void);
extern void prologos_print_callback_summary(void);
extern uint64_t prologos_get_stat(uint32_t key);
extern int64_t prologos_cell_box_int(int64_t payload);
extern int64_t prologos_cell_box_bool(uint8_t payload);
extern int64_t prologos_cell_unbox_payload(int64_t boxed);
extern uint32_t prologos_cell_value_kind(int64_t boxed);
extern void prologos_kernel_reset(void);

#define TAG_INT 0
#define TAG_BOOL 1

#define KIND_KERNEL 0
#define KIND_RACKET_CALLBACK 1

// ============================================================
// Test 1: built-in int-add kernel fire-fn
// ============================================================
static int test_built_in_add(void) {
    prologos_kernel_reset();

    uint32_t a = prologos_cell_alloc();
    uint32_t b = prologos_cell_alloc();
    uint32_t r = prologos_cell_alloc();

    prologos_cell_write(a, prologos_cell_box_int(7));
    prologos_cell_write(b, prologos_cell_box_int(35));
    // tag=0 (int-add) shape=2-1
    prologos_propagator_install_2_1(0, a, b, r);

    prologos_run_to_quiescence();

    int64_t result = prologos_cell_read(r);
    uint32_t kind = prologos_cell_value_kind(result);
    int64_t payload = prologos_cell_unbox_payload(result);

    if (kind != TAG_INT) { fprintf(stderr, "test1: wrong tag %u\n", kind); return 1; }
    if (payload != 42)   { fprintf(stderr, "test1: wrong payload %lld\n", (long long)payload); return 1; }
    printf("test1 (int-add 7 35 → 42): PASS\n");
    return 0;
}

// ============================================================
// Test 2: callback fire-fn — Racket-style fn registered, fires correctly
// ============================================================
static int64_t my_custom_double(int64_t a) {
    return prologos_cell_box_int(prologos_cell_unbox_payload(a) * 2);
}

static int test_callback(void) {
    prologos_kernel_reset();

    // Register tag 5 / shape 1 as a "callback" (kind 1); function
    // doubles its input.
    uint32_t r = prologos_register_fire_fn(5, 1, KIND_RACKET_CALLBACK, my_custom_double);
    if (r != 0) { fprintf(stderr, "test2: register failed %u\n", r); return 1; }

    uint32_t a = prologos_cell_alloc();
    uint32_t out = prologos_cell_alloc();
    prologos_cell_write(a, prologos_cell_box_int(21));

    extern uint32_t prologos_propagator_install_1_1(uint32_t, uint32_t, uint32_t);
    prologos_propagator_install_1_1(5, a, out);

    prologos_run_to_quiescence();

    int64_t result = prologos_cell_read(out);
    int64_t payload = prologos_cell_unbox_payload(result);

    if (payload != 42) { fprintf(stderr, "test2: wrong payload %lld\n", (long long)payload); return 1; }

    // Verify callback profile fired
    uint64_t cb_count = prologos_get_stat(300 + 5);
    if (cb_count == 0) {
        fprintf(stderr, "test2: callback count not tracked\n");
        return 1;
    }

    printf("test2 (callback double 21 → 42; cb_count=%llu): PASS\n", (unsigned long long)cb_count);
    return 0;
}

// ============================================================
// Test 3: variable-arity propagator — sum of N inputs
// ============================================================
static int64_t my_sum_n(uint32_t n, const int64_t* inputs) {
    int64_t total = 0;
    for (uint32_t i = 0; i < n; i++) {
        total += prologos_cell_unbox_payload(inputs[i]);
    }
    return prologos_cell_box_int(total);
}

static int test_n_arity(void) {
    prologos_kernel_reset();

    // Register tag 6 / shape 4 (N-1) as kernel-callback that sums inputs.
    prologos_register_fire_fn(6, 4, KIND_KERNEL, my_sum_n);

    uint32_t cells[5];
    for (int i = 0; i < 5; i++) {
        cells[i] = prologos_cell_alloc();
        prologos_cell_write(cells[i], prologos_cell_box_int(i + 1));  // 1, 2, 3, 4, 5
    }
    uint32_t out = prologos_cell_alloc();

    prologos_propagator_install_n_1(6, cells, 5, out);
    prologos_run_to_quiescence();

    int64_t payload = prologos_cell_unbox_payload(prologos_cell_read(out));
    if (payload != 15) { fprintf(stderr, "test3: wrong payload %lld\n", (long long)payload); return 1; }
    printf("test3 (sum 1+2+3+4+5 = 15): PASS\n");
    return 0;
}

// ============================================================
// Test 4: chained propagators (factorial-style int-mul cascade)
// ============================================================
static int test_chain(void) {
    prologos_kernel_reset();

    // (3 + 4) * (10 - 2) = 7 * 8 = 56
    uint32_t a = prologos_cell_alloc(); prologos_cell_write(a, prologos_cell_box_int(3));
    uint32_t b = prologos_cell_alloc(); prologos_cell_write(b, prologos_cell_box_int(4));
    uint32_t c = prologos_cell_alloc(); prologos_cell_write(c, prologos_cell_box_int(10));
    uint32_t d = prologos_cell_alloc(); prologos_cell_write(d, prologos_cell_box_int(2));

    uint32_t sum = prologos_cell_alloc();   prologos_propagator_install_2_1(0, a, b, sum);     // add
    uint32_t diff = prologos_cell_alloc();  prologos_propagator_install_2_1(1, c, d, diff);    // sub
    uint32_t out = prologos_cell_alloc();   prologos_propagator_install_2_1(2, sum, diff, out); // mul

    prologos_run_to_quiescence();

    int64_t payload = prologos_cell_unbox_payload(prologos_cell_read(out));
    if (payload != 56) { fprintf(stderr, "test4: wrong payload %lld\n", (long long)payload); return 1; }
    printf("test4 ((3+4)*(10-2) = 56): PASS\n");
    return 0;
}

int main(void) {
    int rc = 0;
    rc |= test_built_in_add();
    rc |= test_callback();
    rc |= test_n_arity();
    rc |= test_chain();
    if (rc == 0) {
        printf("\nAll hybrid kernel smoke tests PASSED.\n");
        prologos_print_stats();
    } else {
        fprintf(stderr, "FAILURES.\n");
    }
    return rc;
}
