# Testing

- **Primary**: `racket tools/run-affected-tests.rkt` -- runs affected tests, records per-file timing to `data/benchmarks/timings.jsonl`
- **Full suite**: add `--all` flag. Also: `--jobs N`, `--timeout N`, `--no-record`, `--no-skip`
- **Reporting**: `racket tools/benchmark-tests.rkt --report` / `--trend FILE` / `--compare REF` / `--slowest N`
- **Skip list**: `tests/.skip-tests` -- currently empty (all 83 files, 2717 tests pass)
- **DAG impact**: `prelude.rkt` or `syntax.rkt` -> nearly all tests; single `.prologos` lib -> 1-15 tests; single test -> 1 test
- **Fallback**: `raco test -j 10 prologos/tests/` -- no timing recorded
