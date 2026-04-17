# Testing

- **Primary**: `racket tools/run-affected-tests.rkt` -- runs affected tests, records per-file timing to `data/benchmarks/timings.jsonl`
- **Full suite**: add `--all` flag. Also: `--jobs N`, `--timeout N`, `--no-record`, `--no-skip`
- **Reporting**: `racket tools/benchmark-tests.rkt --report` / `--trend FILE` / `--compare REF` / `--slowest N`
- **Skip list**: `tests/.skip-tests` -- 2 pathological perf tests skipped by default (use `--no-skip` to include)
- **Guideline**: Keep test files under ~20 test-cases / ~30s wall time for good thread-pool parallelism
- **Delimiter check after .rkt edits**: Run `tools/check-parens.sh <file>` after EVERY edit to a `.rkt` file, BEFORE `raco make`. Instant (~100ms, read-only). Catches mismatched `()`, `[]`, `{}` with exact line:column. Eliminates trial-and-error bracket-balancing during compilation.
- **Pre-compilation**: Both runners call `raco make driver.rkt` AND all test files before tests (skip with `--no-precompile`). The suite runner's `precompile-modules!` compiles BOTH — test files are NOT in driver.rkt's dependency graph, so `raco make driver.rkt` alone does NOT recompile them.
- **Separate compile from test timing**: When measuring suite wall time for performance comparison, run `raco make driver.rkt` as a SEPARATE step first, THEN run the test suite with `--no-precompile`. Compilation time varies by cache state and pollutes wall time measurements.
- **Stale test `.zo` auto-recompile** -- When `--no-precompile` is used, the runner now detects stale test `.zo` files (older than the production `.zo`) and auto-recompiles them before running. This fixes the historical trap where `raco make driver.rkt` + `--no-precompile` left test `.zo` stale (because tests aren't in driver's dependency graph). Stale test `.zo` silently produced wrong results via batch-worker `dynamic-require`. With auto-recompile, the runner just handles it — typical repair <5s when only a few files are stale. Use `--force-stale-zo` to override (for intentional reproduction of old behavior); otherwise the runner keeps you safe. Confirmed trap in BSP-LE Track 2B Phase T-a diagnosis (multiple cycles of "passes individually, fails in batch").
- **DAG impact**: `prelude.rkt` or `syntax.rkt` -> nearly all tests; single `.prologos` lib -> 1-15 tests; single test -> 1 test
- **Fallback**: `raco test -j 10 prologos/tests/` -- no timing recorded
- **Full suite = regression gate only** (CRITICAL — STOP AND READ BEFORE ACTING): The full suite (~130s) is for regression checks after completing a phase, not for investigation. NEVER run the full suite to diagnose failures.
  **TRIGGER**: The moment output shows "N FAILURES" — STOP. Do NOT re-run.
  **PROTOCOL** (follow IN ORDER, do not skip steps):
  1. **Read failure logs**: `data/benchmarks/failures/*.log` (use Read tool). The logs persist — no re-run needed to see them.
  2. **Categorize**: linklet mismatch (stale .zo) vs real failure vs file-not-found (stale log)
  3. **If linklet mismatch**: `raco make tests/test-NAME.rkt` then `raco test tests/test-NAME.rkt`. NOT a full suite re-run.
  4. **If real failure**: `raco test tests/test-NAME.rkt > /tmp/test-NAME.txt 2>&1` — capture FULL output on FIRST run. Read with Read tool.
  5. **Fix the issue**. Re-run the INDIVIDUAL test to verify.
  6. **Only after ALL failures are individually fixed**: run the full suite ONE time as regression gate.
  **Anti-pattern observed 5+ times this session**: re-running full suite to "see which tests fail" or "check if fix worked." Each re-run wastes ~130s. Read the logs. Run individual tests. The full suite is the FINAL step, not the diagnostic tool.
  A guard script (`tools/guard-suite-rerun.sh`) blocks re-runs within 5 minutes if no `.rkt` files changed.
- **Output capture** (CRITICAL): Run the test suite ONCE and capture sufficient output. NEVER re-run the full suite just to see different parts of the output. Correct patterns:
  - `racket tools/run-affected-tests.rkt --all 2>&1 | tail -30` -- captures failures AND summary in one invocation
  - Or pipe to temp file: `racket tools/run-affected-tests.rkt --all > /tmp/test-output.txt 2>&1` then inspect with Read tool
  - Failure logs are always available in `data/benchmarks/failures/*.log` -- use Read tool to inspect individual failures without re-running
  - The `--failures` flag replays failure logs without re-running tests: `racket tools/run-affected-tests.rkt --failures`
- **Shared fixture pattern** (REQUIRED): All test files that use `process-string` must use the shared fixture pattern — load modules ONCE at module level via `define-values`, each test reuses the cached env via `run`/`run-last`. Never use per-test `run-ns`/`run-ns-last` that creates fresh env per call. See `tests/test-char-string.rkt` or `tests/test-hashable-01.rkt` for the canonical pattern. Use `prelude-module-registry` from `test-support.rkt` as the starting module registry (not `(hasheq)`).
- **Three-level WS validation** (REQUIRED for new language features): Features that add or modify user-facing syntax must be validated at three levels:
  - **Level 1 (sexp)**: `process-string` / `run-last` — validates IR, parser internals, type rules
  - **Level 2 (WS string)**: `process-string-ws` / `run-ws-last` — validates single WS expression in preloaded env
  - **Level 3 (WS file)**: `process-file` on a `.prologos` file — validates full pipeline: reader, top-level scoping, multi-form interaction, file-level preparse
  - Level 3 is the gap that most commonly produces "works in tests, broken for users" situations. Top-level scoping, file-level preparse, and multi-form interaction differ from string-mode processing. A feature passing Level 1-2 but untested at Level 3 should be marked "DONE (sexp only)" not "DONE".
  - See `DESIGN_METHODOLOGY.org` § "WS-Mode Validation Protocol" for the full protocol including acceptance files and the canary file.
- **Performance regression detection**: After a full test suite run, check for regressions at two levels:
  - **Per-file**: Investigate any file with `wall_ms > 2× its rolling median` AND `median > 3s` (sub-3s files have too much measurement noise for ratio-based alerting). Also investigate any file exceeding **60s absolute** — it likely belongs in the skip list.
  - **Suite-level**: Investigate if total wall time exceeds **1.2× the 5-run rolling median** from `timings.jsonl`. Normal variance is 5–10%; a 20% increase signals a real regression.
  - Common causes: missing fast-path classifier update (e.g., `pattern-is-simple-flat?`), stale `.zo` cache after struct changes, broken library module compilation causing cascading slow elaboration. An 850s regression from a single missing pattern kind was observed — moderate regressions are silent without explicit comparison.
  - Use `racket tools/benchmark-tests.rkt --slowest 10` to identify per-file outliers.
- **Pre-push gate**: A git pre-push hook (`.git/hooks/pre-push`) runs the full suite if no `timings.jsonl` entry exists for HEAD. If a run already exists for the current commit, the hook skips (no redundant re-run). Bypass with `git push --no-verify` in emergencies.
- **Parameter-leakage lint** (A3-static-lint, BSP-LE Track 2B addendum) -- `racket tools/lint-parameters.rkt` classifies each `make-parameter` call as private / test-registered / unclassified. Uses a baseline file (`tools/parameter-lint-baseline.txt`) to track currently-accepted unclassified parameters; only flags NEW additions. Run: `racket tools/lint-parameters.rkt` (report), `--strict` (exit non-zero if new unclassified found — for CI / manual audit), `--save-baseline` (accept current state as new baseline). Architectural answer is PM Track 12 (parameters → cells for module loading) which obsoletes this lint. Longitudinal pattern 7 (two-context boundary bugs, 6+ PIRs) — tactical near-term protection against silent regressions.
