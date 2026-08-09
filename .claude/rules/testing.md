# Testing

- **Primary**: `racket tools/run-affected-tests.rkt` -- runs affected tests, records per-file timing to `data/benchmarks/timings.jsonl`
- **Full suite**: add `--all` flag. Also: `--jobs N`, `--timeout N`, `--no-record`, `--no-skip`
- **Targeted tests (CRITICAL — use this, not bare `raco test`, after any production edit)**: `racket tools/run-affected-tests.rkt --tests tests/test-X.rkt --tests tests/test-Y.rkt` runs specific files with SCOPED PRECOMPILE (driver.rkt + the listed tests, ~0.5s incremental). This keeps test `.zo` linklets fresh after export changes in production modules, which `raco test FILE` alone does NOT do. Repeat `--tests FILE` per file (conventional command-line multi-arg pattern). **When to use targeted mode**: any time you've edited production code AND want to run specific tests — e.g., iterating on a failing test during development, verifying a fix hits the right paths, confirming a subset of tests before running the full suite. Avoids the class of "passes individually, fails in batch" / "reference to a variable that is not exported" (linklet mismatch) errors. Observed failure pattern: `raco make typing-propagators.rkt` + `raco test tests/test-X.rkt` → test's cached `.zo` holds a stale linklet snapshot of typing-propagators's exports; when exports changed, linklet-mismatch or silent wrong-results. The targeted runner's scoped precompile closes this gap. Origin: PPN 4C Phase 3c retrospective (2026-04-20) — the earlier sessions' runs didn't hit it because changes were internal (no export-surface changes); Phase 3c added multiple new provides and surfaced the gap.
- **Reporting**: `racket tools/benchmark-tests.rkt --report` / `--trend FILE` / `--compare REF` / `--slowest N`
- **Skip list**: `tests/.skip-tests` -- 2 pathological perf tests skipped by default (use `--no-skip` to include)
- **Guideline**: Keep test files under ~20 test-cases / ~30s wall time for good thread-pool parallelism
- **Delimiter check after .rkt edits**: Run `tools/check-parens.sh <file>` after EVERY edit to a `.rkt` file, BEFORE `raco make`. Instant (~100ms, read-only). Catches mismatched `()`, `[]`, `{}` with exact line:column. Eliminates trial-and-error bracket-balancing during compilation.
- **Pre-compilation**: Both runners call `raco make driver.rkt` AND all test files before tests (skip with `--no-precompile`). The suite runner's `precompile-modules!` compiles BOTH — test files are NOT in driver.rkt's dependency graph, so `raco make driver.rkt` alone does NOT recompile them.
- **Compile limit (`PLT_CS_COMPILE_LIMIT=1000000`) — ADOPTED (Rel T1 SUB.2, owner-blessed 2026-07-24)**: the runners (`run-affected-tests.rkt`, `bench-ab.rkt`) `putenv` it at startup, so all suite/bench builds get it automatically (subprocesses inherit; explicit user override respected). The compiler's giant match functions (shift/subst ~340 arms, whnf/nf ~990) exceed the CS default (10000) and fall back to the INTERPRETER — measured: shift ~830× faster compiled; suite 211→173s (−18%). **Manual `raco make` outside the runners should set it in the shell** (else the touched modules silently rebuild interpreted and the next suite run eats the difference): `PLT_CS_COMPILE_LIMIT=1000000 raco make driver.rkt`. ⚠ A/B measurement trap: `touch FILE && raco make` does NOT recompile (SHA short-circuit) — delete the `.zo`/`.dep` to force a true recompile. Evidence: `docs/tracking/2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md` §4.2.
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
- **⚠ A KILLED RUNNER STILL PRINTS "all pass" — verify `[N/N]` and the COUNT, never the summary line alone** (ARROW T1, 2026-08-05). A `--all` run SIGTERM'd at `[113/483]` emitted `2086 tests in 655.0s (483 files, 10 batch workers, all pass)`. It names the FULL file count and says "all pass" while having run a quarter of them; the tells are the test COUNT (2086 vs the real 9877) and the last `[N/M]` progress marker. Also grep `user break`. Corollary: `grep -c " FAIL "` does NOT find failures — the runner reports `N FAILURES` in the summary and `FAILED: <file>` on its own line; grep for those.
- **⚠ Three runner behaviours that mislead under load** (same session): (1) `--all` enforces a **120s per-file timeout** while `--tests` reports `timeout: 600s` — a file that normally takes ~60s fails as a TIMEOUT when the machine is busy, and its failure log shows `wall_ms: 120003` with `tests: N (0 failures)`, which is the signature of a timeout rather than an assertion failure. (2) The **"⛔ DEAD WORKERS — no results after 30s"** banner is a 30s no-output heuristic; its advice ("stale `.zo`, run `raco make`") is a guess, and the condition reproduces for `tests/test-path-selection.rkt` under `--tests` on a CLEAN base after a clean compile. (3) Before blaming a change for either, **re-run the same file on the untouched base worktree** — that A/B settles it in one command. Check `uptime` load first: other worktrees/sessions running work will starve a run to 0% CPU.
- **Output capture** (CRITICAL): Run the test suite ONCE and capture sufficient output. NEVER re-run the full suite just to see different parts of the output. Correct patterns:
  - `racket tools/run-affected-tests.rkt --all 2>&1 | tail -30` -- captures failures AND summary in one invocation
  - Or pipe to temp file: `racket tools/run-affected-tests.rkt --all > /tmp/test-output.txt 2>&1` then inspect with Read tool
  - Failure logs are always available in `data/benchmarks/failures/*.log` -- use Read tool to inspect individual failures without re-running
  - The `--failures` flag replays failure logs without re-running tests: `racket tools/run-affected-tests.rkt --failures`
- **Shared fixture pattern** (REQUIRED): All test files that use `process-string` must use the shared fixture pattern — load modules ONCE at module level via `define-values`, each test reuses the cached env via `run`/`run-last`. Never use per-test `run-ns`/`run-ns-last` that creates fresh env per call. See `tests/test-char-string.rkt` or `tests/test-hashable-01.rkt` for the canonical pattern. Use `prelude-module-registry` from `test-support.rkt` as the starting module registry (not `(hasheq)`).
- **Test files require production modules by RELATIVE path (`"../X.rkt"`), never by collection path (`prologos/X`)** (REQUIRED). The installed `prologos` collection resolves to the MAIN checkout; in a git worktree, a collection-path require therefore loads a SECOND copy of the compiler (the main checkout's — not the code under test) as a separate module instance. That instance instantiates lazily on the first requiring test file's per-file thread in a batch worker; parameter mutations made at its module load time (e.g. `install-default-typing-domain!`'s `register-typing-rule!` calls) live in that thread's cells and DIE with the thread, so every later collection-requiring test in the same worker sees pristine parameter defaults (empty typing-rule registry → registry-dispatched typing yields `'type-bot` while custom match arms still work). Symptom signature: order-dependent batch flake that always passes via `--tests` (single file = it instantiates on its own thread). Two incidents: 2026-06-29 (SRE-registry batch isolation) + 2026-07-14 (`test-sre-coverage` — diagnosed via per-worker trace + prefix bisection; 6 PPN-4C-era test files converted). 424/430 test files already follow the relative convention. **3rd sighting (2026-07-26): the surface extends beyond test requires — lib `foreign racket "prologos/X"` declarations hit the same trap** (reason.prologos's keyword-ops → second instance → `keyword-name: expected a Keyword value, got #(struct:expr-keyword …)`; 6 schema/seal/validate tests failed in ANY worktree while green in main). Structural fix landed: `foreign-module-path->require-spec` (pnet-serialize.rkt) is THE canonical resolver — "prologos/X" resolves to the RUNNING compiler's own X.rkt at BOTH resolution sites (handle-foreign-decl + the .pnet re-link); write new foreign/dynamic-require resolution through it, never a fresh `(string->symbol …)` collection fallback. Related trap fixed alongside: `--no-pnet-cache` was a NO-OP (batch-worker only acted on env "1" while the parameter defaults #t) — it "ruled out" the cache while the cache was in play; if a cache-disabling flag is load-bearing for a diagnosis, verify it actually flips the parameter. See `DEVELOPMENT_LESSONS.org` § "Two Compiler Instances: the Collection-Path Trap".
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
- **Bench workload validity — check the WORKLOAD before trusting the measurement** (promoted 2026-07-25, Rel T1 SUB.2; 1 of 3 trap data points that session). A synthetic benchmark can measure something other than what you think: a generated 340-arm dispatch loop accumulated into an unbounded integer, so the "dispatch cost" was really **bignum arithmetic** (diagnosed by `sample <pid>` showing `big_add_pos` — not by reading the generator). Before believing any surprising bench number: `sample` the process, and sanity-check that per-call cost scales the way the workload's shape predicts. Bound accumulators (`modulo`), and prefer per-call costs you can cross-check against a second, differently-shaped workload.
- **Bench A/B under long-session ambient**: sequential bench invocations are NOT a valid A/B — ambient drift across minutes-long windows swamps small deltas (CVs 3–9% vs ≤1% quiescent). Prefer the **deterministic-work counters** (the `PERF-COUNTERS` line; exact, ambient-immune) over wall for A/B; for wall, interleave or **worktree-pin the baseline** (a perf-worktree is the safe form when owner-WIP occupies the main tree). ⚠ **Correction (2026-07-27, GitHub #58 P4): `bench-ab --ref` DOES NOT EXIST** — the flag was never implemented (`tools/bench-ab.rkt:254-276` accepts only `--runs`/`--output`; the B leg runs against the same tree, `:178`). The earlier warning here ("`--ref` stashes, unsafe then") described a hazard of a feature that isn't there, while `workflow.md` separately *instructed* its use — so the documented default A/B path silently measured identical code twice. Worktree-pinning is not the safer option, it is the ONLY one. Counter-probe any surprising attribution (a missing `cd` once measured the baseline twice → wrong mover attribution). **Re-confirmed 2026-07-25 (Rel T1 SUB hot-scan)**: a late-session suite pair came back 203.5 s then 212.0 s — the *warm* run SLOWER than the cold one — while the same change measured a clean 6.9× on an **interleaved same-process micro** (±0 across two rounds). When wall and micro disagree, the micro wins and the wall run is ambient, not evidence; say so rather than reporting the wall delta. Also: **never compile (or run anything else heavy) while a timing suite is in flight** — doing so contaminated one baseline run that session and it had to be discarded.
- **Pre-push gate**: A git pre-push hook (`.git/hooks/pre-push`) runs the full suite if no `timings.jsonl` entry exists for HEAD. If a run already exists for the current commit, the hook skips (no redundant re-run). Bypass with `git push --no-verify` in emergencies.
- **Pre-commit gate**: A git pre-commit hook (`tools/git-hooks/pre-commit`, installed via `tools/install-git-hooks.sh`) runs `tools/check-parens.sh` on staged `.rkt` files. ~100ms per file (read-syntax via Racket); blocks the commit on delimiter mismatch with exact line:column. Closes the bug class where mechanical edits (sed surgery, batch refactors) introduce unbalanced parens that break `raco pkg install` downstream — a pattern that hit `main` once already (commit `d7bd97a4`, fixed in PR #29). Bypass with `git commit --no-verify` for genuine emergencies; failures otherwise are real bugs to fix before committing.
- **Parameter-leakage lint** (A3-static-lint, BSP-LE Track 2B addendum) -- `racket tools/lint-parameters.rkt` classifies each `make-parameter` call as private / test-registered / unclassified. Uses a baseline file (`tools/parameter-lint-baseline.txt`) to track currently-accepted unclassified parameters; only flags NEW additions. Run: `racket tools/lint-parameters.rkt` (report), `--strict` (exit non-zero if new unclassified found — for CI / manual audit), `--save-baseline` (accept current state as new baseline). Architectural answer is PM Track 12 (parameters → cells for module loading) which obsoletes this lint. Longitudinal pattern 7 (two-context boundary bugs, 6+ PIRs) — tactical near-term protection against silent regressions.

## ⭐ Running the compiler OUTSIDE the suite — use `tools/scratch-run.sh`, never a hand-rolled harness

**The incident (2026-08-08).** Three adversarial-verify subagents each hand-rolled
an A/B harness, and the harnesses outlived the workflow that spawned them by
45–75 minutes at **PPID 1** — orphaned, unreapable, ~14 GB between them, one at
**12.6 GB**, two pinned at 76–80% CPU. Not a leak: RSS sawtoothed by gigabytes
(9.1 GB → 1.7 GB observed), so GC was reclaiming. The shape was the problem —
**49 `process-file` calls in ONE Racket process**, each accumulating module
networks, registries and `.pnet` caches in the same heap, so peak memory scaled
with corpus size.

**Use the wrapper:**
```bash
tools/scratch-run.sh [-t SECONDS] [-c] ONE-FILE.prologos
for f in corpus/*.prologos; do tools/scratch-run.sh -t 60 "$f"; done   # sweeps
```
It enforces three things structurally, so none of them depends on remembering:
one file per process (it **refuses** a second argument), `timeout -k` with a
SIGKILL follow-up, and its own process group with an EXIT trap.

**Three facts behind those, each measured — do not re-learn them:**

1. **`timeout N` WITHOUT `-k` IS NOT A LIMIT.** The orphan carried `timeout 550`
   and was alive at 1h18m. A manual `kill -TERM` on all three did *nothing*;
   SIGKILL was required. Racket CS in a tight allocation/GC loop does not
   service SIGTERM. Re-confirmed in the wrapper's own smoke test: a `-t 1` run
   exits 124 after **7s**, i.e. the SIGKILL is what ends it. Any bare
   `timeout N racket …` in a command or an agent prompt is a latent orphan.
2. **`setsid` DOES NOT EXIST ON macOS.** A wrapper that branches on it and falls
   through leaves the child in the CALLER's process group — so a group-kill in
   cleanup kills the caller. Use `set -m` (job control gives a background job
   its own process group, non-interactively too), and never group-kill a pgid
   equal to your own.
3. **`racket/prologos/tools/run-file.rkt` ACCEPTS N FILES** (`#:args files files`
   → `(for ([f (in-list files)]) (run-print f))`). The dangerous shape is
   reachable, and looks idiomatic, straight from the repo's own runner — which
   is why the arity bound lives in `scratch-run.sh` and not there (the
   acceptance harness legitimately passes it a list).

**Safety net:** `tools/reap-scratch-racket.sh` lists (default) or `--kill`s
Racket processes whose **cwd is under a temp dir** — the discriminator that
catches any harness, however named, while never touching the LSP server,
racket-mode, or a `prologos/repl`, which all run from the project tree or `$HOME`.
Run it after any workflow that ran the compiler.

**In agent/workflow prompts**, say this explicitly: use `tools/scratch-run.sh`;
do not loop a corpus inside one process; do not leave background processes; and
the orchestrator should reap afterwards. Agents copy whatever runner they are
handed — these three copied a single-file scratch runner and *added* the loop.

### The hook — harness-enforced, because a subagent will not read a rule

`tools/hook-guard-racket.sh` is a **PreToolUse/Bash hook** that DENIES any Bash
command invoking the Racket binary without a `timeout -k` bound. It is enforced
by the harness, not by the model, so it binds SUBAGENT Bash calls too — which is
the point: subagents caused the incident, and a subagent cannot be relied on to
have read this file.

Allowed through: `raco`; `tools/scratch-run.sh`; `run-affected-tests.rkt` and
`bench-ab.rkt` (they own their own workers and timeouts); anything already
carrying `timeout -k` / `--kill-after`. A bare `timeout N` is DENIED on purpose —
see the SIGTERM fact above.

**It is not committed by default.** `.claude/settings.json` is untracked in this
repo (`.claude/settings.local.json` is the tracked one), so the hook must be
installed per clone. To install:

    jq '. + {hooks: {PreToolUse: [{matcher: "Bash", hooks: [{type: "command",
        command: "<REPO>/tools/hook-guard-racket.sh", timeout: 10}]}]}}' \
      .claude/settings.json > /tmp/s && mv /tmp/s .claude/settings.json

Then verify it FIRES — a hook that is silently inert is the failure mode:
attempt an unbounded run and confirm it is refused.

⚠ **Two things to know before editing the guard.**
1. Run `tools/hook-guard-racket.test.sh` after ANY change. Its ALLOW rows are
   what keep `raco`, the suite runner and `grep racket` working; over-denying is
   not harmless. The table has already caught a missed shape (racket invoked
   THROUGH a wrapper) and a run that was green only because the guard was not
   executable.
2. **Self-reference hazard**: the guard inspects the RAW command string, so a
   shell command that merely CONTAINS an example invocation — a heredoc
   documenting the pattern — is itself blocked. Write such files with an editor,
   not a heredoc.
