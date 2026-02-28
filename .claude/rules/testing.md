# Testing

- **Primary**: `racket tools/run-affected-tests.rkt` -- runs affected tests, records per-file timing to `data/benchmarks/timings.jsonl`
- **Full suite**: add `--all` flag. Also: `--jobs N`, `--timeout N`, `--no-record`, `--no-skip`
- **Reporting**: `racket tools/benchmark-tests.rkt --report` / `--trend FILE` / `--compare REF` / `--slowest N`
- **Skip list**: `tests/.skip-tests` -- 2 pathological perf tests skipped by default (use `--no-skip` to include)
- **Guideline**: Keep test files under ~20 test-cases / ~30s wall time for good thread-pool parallelism
- **Pre-compilation**: Both runners call `raco make driver.rkt` before tests (skip with `--no-precompile`)
- **DAG impact**: `prelude.rkt` or `syntax.rkt` -> nearly all tests; single `.prologos` lib -> 1-15 tests; single test -> 1 test
- **Fallback**: `raco test -j 10 prologos/tests/` -- no timing recorded
- **Shared fixture pattern** (REQUIRED): All test files that use `process-string` must use the shared fixture pattern — load modules ONCE at module level via `define-values`, each test reuses the cached env via `run`/`run-last`. Never use per-test `run-ns`/`run-ns-last` that creates fresh env per call. See `tests/test-char-string.rkt` or `tests/test-hashable-01.rkt` for the canonical pattern. Use `prelude-module-registry` from `test-support.rkt` as the starting module registry (not `(hasheq)`).
