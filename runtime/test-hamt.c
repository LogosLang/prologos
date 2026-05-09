/* test-hamt.c — C-side smoke test for the HAMT C ABI.
 *
 * Mirrors the Zig unit tests but exercises the public C ABI declared
 * by `runtime/prologos-hamt.zig`. Built and run by CI to validate that
 * the .o links cleanly against a non-Zig caller.
 *
 * Build: clang test-hamt.c prologos-hamt.o -o test-hamt
 * Run:   ./test-hamt   (exit 0 = all passed)
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

typedef const void *prologos_hamt_t;

extern prologos_hamt_t prologos_hamt_new(void);
extern int             prologos_hamt_lookup(prologos_hamt_t h, uint32_t key, int64_t *out);
extern prologos_hamt_t prologos_hamt_insert(prologos_hamt_t h, uint32_t key, int64_t value);
extern prologos_hamt_t prologos_hamt_remove(prologos_hamt_t h, uint32_t key);
extern uint32_t        prologos_hamt_size(prologos_hamt_t h);

static int failures = 0;

#define ASSERT(cond, msg)                                                 \
    do {                                                                  \
        if (!(cond)) {                                                    \
            fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, msg); \
            failures++;                                                   \
        }                                                                 \
    } while (0)

static void test_empty(void) {
    prologos_hamt_t h = prologos_hamt_new();
    ASSERT(prologos_hamt_size(h) == 0, "empty trie size = 0");
    int64_t v;
    ASSERT(prologos_hamt_lookup(h, 42, &v) == 0, "empty trie lookup = miss");
}

static void test_single(void) {
    prologos_hamt_t h = prologos_hamt_insert(prologos_hamt_new(), 7, 100);
    ASSERT(prologos_hamt_size(h) == 1, "single insert size = 1");
    int64_t v = 0;
    ASSERT(prologos_hamt_lookup(h, 7, &v) == 1 && v == 100, "lookup 7 = 100");
    ASSERT(prologos_hamt_lookup(h, 8, &v) == 0, "lookup 8 = miss");
}

static void test_multi(void) {
    prologos_hamt_t h = prologos_hamt_new();
    for (uint32_t i = 0; i < 1000; i++) {
        h = prologos_hamt_insert(h, i, (int64_t)i * 10);
    }
    ASSERT(prologos_hamt_size(h) == 1000, "1000 inserts size = 1000");
    for (uint32_t i = 0; i < 1000; i++) {
        int64_t v = -1;
        ASSERT(prologos_hamt_lookup(h, i, &v) == 1, "lookup i hits");
        ASSERT(v == (int64_t)i * 10, "value matches");
    }
    int64_t v;
    ASSERT(prologos_hamt_lookup(h, 1000, &v) == 0, "out-of-range = miss");
}

static void test_overwrite(void) {
    prologos_hamt_t h = prologos_hamt_new();
    h = prologos_hamt_insert(h, 5, 100);
    h = prologos_hamt_insert(h, 5, 200);
    h = prologos_hamt_insert(h, 5, 300);
    ASSERT(prologos_hamt_size(h) == 1, "overwrite preserves size");
    int64_t v;
    ASSERT(prologos_hamt_lookup(h, 5, &v) == 1 && v == 300, "latest value wins");
}

static void test_remove(void) {
    prologos_hamt_t h = prologos_hamt_new();
    h = prologos_hamt_insert(h, 5, 100);
    h = prologos_hamt_insert(h, 7, 200);
    h = prologos_hamt_remove(h, 5);
    ASSERT(prologos_hamt_size(h) == 1, "remove decrements size");
    int64_t v;
    ASSERT(prologos_hamt_lookup(h, 5, &v) == 0, "removed key = miss");
    ASSERT(prologos_hamt_lookup(h, 7, &v) == 1 && v == 200, "other key intact");
}

static void test_persistence(void) {
    prologos_hamt_t h0 = prologos_hamt_new();
    prologos_hamt_t h1 = prologos_hamt_insert(h0, 5, 100);
    prologos_hamt_t h2 = prologos_hamt_insert(h1, 7, 200);
    /* h1 unaffected by insert into derived h2 */
    ASSERT(prologos_hamt_size(h1) == 1, "h1 size = 1");
    ASSERT(prologos_hamt_size(h2) == 2, "h2 size = 2");
    int64_t v;
    ASSERT(prologos_hamt_lookup(h1, 7, &v) == 0, "h1 does not see key 7");
    ASSERT(prologos_hamt_lookup(h2, 7, &v) == 1 && v == 200, "h2 sees key 7");
    ASSERT(prologos_hamt_lookup(h1, 5, &v) == 1 && v == 100, "h1 still sees key 5");
}

int main(void) {
    test_empty();
    test_single();
    test_multi();
    test_overwrite();
    test_remove();
    test_persistence();
    if (failures == 0) {
        printf("OK: all HAMT C-ABI smoke tests passed\n");
        return 0;
    } else {
        printf("FAIL: %d test(s) failed\n", failures);
        return 1;
    }
}
