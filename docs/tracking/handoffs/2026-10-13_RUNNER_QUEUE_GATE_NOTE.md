# Runner queue + gate batch — record note (branch `runner-queue-gate`)

Written 2026-10-13 at `c47c450b` (base `58241c0c`), worktree
`.claude/worktrees/runner-queue-gate`. Machine: macOS 27.0.1, 18 cores, Racket 9.3 CS, every
build with `PLT_CS_COMPILE_LIMIT=1000000`. **Not merged.** No `--all` was run, by instruction:
every runner path below was checked with targeted runs (`--tests`) and scratch probes, under a
private `PROLOGOS_SUITE_LOCK` so that no probe could block a real run. Scratch probes are in
`~/.hermes/profiles/logos-language-designer/cache/scratch/runner-queue-gate/` (that directory is
pruned after 24 h; the commit messages quote what they printed).

`file:line` citations of code are at `c47c450b`. The test line numbers quoted as red or mutation
evidence are as of the commit that introduced each test; later commits shift some of them.

## Commits

| # | hash | item |
|---|------|------|
| 1 | `92472849` | Part 1: the machine-wide suite queue (`tools/suite-lock.rkt`) |
| 2 | `2999a74b` | (a) DEFERRED 161: a unit that reports PASS with 0 tests is NO RESULT |
| 3 | `57a542e2` | (b) 164 open 2: a GUARD refusal exits 3 |
| 4 | `fa6437fc` | (c) 164 open 3: medians skip partial/annotated records, plus `annotate-invalid-timings.rkt` |
| 5 | `f20220df` | (e) 164 open 5: timestamps carry the local offset; schema 4 |
| 6 | `36bd4e7d` | (f) 162 open 1: the stale "impact NIL" comment |
| 7 | `1753757d` | (g-i) 160 support: failure logs kept per run |
| 8 | `58dcf0f8` | (d) 164 open 4: worker stderr drained; dead-worker banner shows it |
| 9 | `6a806d03` | (g-ii) 160 support: worker→unit sequence recorded |
| 10 | `bd6fddd1` | (h) the worker's own modules are precompiled (stale test-support.zo) |
| 11 | `c47c450b` | extra: the collector stops waiting once every worker has exited |
| 12 | (this note) | |

The commits run a, b, c, e, f, g-i, d, g-ii, h, so that the per-run directory (g-i) existed
before (d) wrote stderr into it.

**Tests added: 34 test-cases in 4 files.** New: `tests/test-suite-lock.rkt` (10),
`tests/test-annotate-invalid-timings.rkt` (3), `tests/test-timings-timestamp.rkt` (3). Extended:
`tests/test-suite-plan.rkt`, from 10 to 28. The last targeted run had 9 files (the 4 above plus
test-substitution, test-hashable-01, test-p2-debug, test-multiclause-debug and
test-record-pnet-cache): **114 tests, all pass**, schema-4 record written.

**Suite shape after merge** (from `--all --dry-run`, measured): the branch plans **494 of 497**
files (3 skipped). The same base minus this batch plans **492 of 495**, measured with `58241c0c`'s
runner, which includes test-suite-lock.rkt. Against main, the branch adds 3 test files and removes
1 unit, test-support.rkt, which is no longer dispatched. The coordinator's file-by-file reconcile
should show +3 files, −test-support.rkt, and +34 tests.

---

## Part 1 — machine-wide suite queue (`92472849`)

**What changed.** The new `tools/suite-lock.rkt` is a writer-preferring readers–writer lock built
on OS file locks (`port-try-file-lock?`):
- **The lock** (`suite-lock-path`, :96) is `~/Library/Caches/prologos/suite.lock`, one per user,
  shared by every checkout. On non-macOS systems it lives under the XDG cache directory.
  `PROLOGOS_SUITE_LOCK` overrides it. `(find-system-path 'temp-dir)` was rejected because it is
  per process environment: TMPDIR differs between sessions here.
- **The turnstile** `<lock>.intent`: every taker holds it on the way in. A waiting exclusive taker
  keeps holding it while it waits, which gives writer preference (`acquire-suite-lock!`, :212).
- **Info files** `<lock>.d/<pid>-<n>.json` record pid, mode, state (waiting or holding), checkout,
  command, start and acquired times. Each one stays **locked by its taker** for the taker's
  lifetime. A reader that can lock one knows its taker is dead and deletes it (`suite-lock-holders`,
  :171). The file is created under a `.tmp` name, locked, then renamed, so a reader never sees it
  unlocked (`create-info!`, :149). Each acquire sweeps leftovers.
- `call-with-suite-lock` (:273) releases **inside the exit handler**, so every `(exit n)` in the
  runner releases before the process ends. The OS covers crashes and SIGKILL.
- **Modes** (`suite-lock-mode`, :78): `--all`, an info.rkt-triggered all run, and any run of ≥100
  files are **exclusive**; a targeted run is **shared**. The 100-file threshold is
  `historical-medians`' own boundary between a suite and a targeted run.
  - The runner wraps the work in `with-suite-lock` (`tools/run-affected-tests.rkt:371`).
  - Call sites: targeted :435, `--all` :525, info.rkt :554, affected :602. The lock is held through
    precompile and run.
  - `bench-ab.rkt:314` and `benchmark-tests.rkt:569` are timing runs and take it exclusively; so
    does `annotate-invalid-timings.rkt:74`.
- **While waiting**, `make-wait-reporter` (:323) prints each holder (pid, mode, state, since,
  checkout, command). It reprints when the set changes, and at least every 60 s.
- **`--no-wait`** exits **75** (EX_TEMPFAIL) with a banner and runs nothing. It works on the
  runner, bench-ab and benchmark-tests.
- The re-run GUARD is now `rerun-guard!` (:340). It runs before queueing and again after a wait.
- Documented in `.claude/rules/testing.md` (the "Runs QUEUE machine-wide" bullet).
- Small fix while there: `bench-ab.rkt`'s module-level `putenv` printed `#t`.

**Tests**: `tests/test-suite-lock.rkt`, 10 test-cases:
- exclusive blocks both exclusive and shared;
- shared admits shared;
- release is idempotent, and a refused `--no-wait` leaves nothing behind;
- **a holder subprocess killed with SIGKILL releases the lock, and its info file is swept**;
- **writer preference**;
- what a waiter is told (info-file content);
- the lock is released before `(exit N)` takes effect;
- busy with `--no-wait`;
- the path is the same for every checkout and the env override works;
- the mode rule.

Red first: the module was missing (compile error).

**Mutations**, each red and then restored byte-exact:

| mutation | result |
|---|---|
| shared takers bypass the turnstile | "a shared taker may not overtake a waiting exclusive one" |
| no stale-file probe | "only our own info file remains" |
| exclusive takers take shared | 7 checks fail |
| no release inside the exit handler | "the lock was free when the process would have exited" |

**End to end** (`e2e-lock.sh`, private lock path, holder = `hold-lock.rkt`):

| scenario | result |
|---|---|
| exclusive holder; targeted runner `--no-wait` | exit 75 in 0–1 s; banner names the holder `pid 13778 exclusive holding since 04:25:19 (2s) /scratch/holder hold-lock exclusive 20` |
| same; `bench-ab --no-wait`, `benchmark-tests --no-wait` | both exit 75 |
| same holder, which exits after 20 s **without releasing**; targeted runner waits | prints the holder, "Suite lock acquired (shared) after waiting 18.1s", runs, exit 0 |
| shared holder; targeted runner | no wait, exit 0 |
| shared holder; `bench-ab --no-wait` | exit 75 |
| SIGKILL the shared holder | 1 info file left over; the next run sweeps it (0 left) |

**Not covered.** Two OS users would not queue: the lock is per home directory. Behaviour on Linux
or NFS is untested. Several waiting exclusive takers are served in polling order (1 s), which is
not FIFO.

> ⚠ **Only checkouts whose runner contains `suite-lock.rkt` take part.** An older checkout's runner
> neither waits nor is waited for, so its runs still contend. These are the same 8 checkouts
> DEFERRED 163 open(1) lists, plus every checkout that is not at this merge.

---

## (a) DEFERRED 161 — zero tests is no result (`2999a74b`)

**What changed.** The gate is now pure functions in `tools/suite-plan.rkt`:
`gate-verdict`/`gate-incomplete?`/`gate-all-pass?` (:311–326), used at `run-affected-tests.rkt:1288`.
- "All pass" means every dispatched unit reported AND every unit that reported pass ran ≥ 1 test.
- The rule applies **per unit**, so an empty shard is caught as well.
- A fail or timeout with 0 tests stays a FAILURE (exit 1), because its error is the useful output.
- The progress line labels such a unit `EMPTY — 0 tests` (:1122). The summary reads
  `INCOMPLETE — k reported PASS with 0 tests: …`; the run exits 2 and records nothing.

**Exemption mechanism: an explicit list.** `TEST-FREE-FILES` (`suite-plan.rkt:294`) holds
`test-multiclause-debug.rkt` and `test-p2-debug.rkt`, both printf debug scripts. A marker comment
was rejected for three reasons:
1. An exemption from a gate should be auditable in one place and pinned by a test.
2. A marker travels with copy-paste and silently exempts the new file.
3. The runner would have to read the text of every test file to find markers.

A declared file that does run tests is printed as a stale declaration.

**test-support.rkt is no longer a unit** (`NON-TEST-MODULES`, :288; `drop-non-test-modules` is
used at :505, :545, :579). Every worker loads it at startup, so dispatching it was a cached no-op
that could only report 0 tests. Measured: `58241c0c`'s runner planned 493 of 496 files including
test-support.rkt; this commit plans 492 of 495 without it. Main's last full record (`fd2986cc`)
had exactly 3 zero-test units: test-p2-debug, test-multiclause-debug and test-support.

**Tests**: 5 test-cases in `tests/test-suite-plan.rkt`. Red against the old rule written as the
same functions: 4 of 5 failed (:206, :215, :225, :240). The fifth (missing units, and a failure
with 0 tests) passes under both rules; it is a regression guard. End to end with a scratch file
that has no tests:
- before: `PASS (0.0s) … all pass`, exit 0;
- after: `EMPTY — 0 tests … INCOMPLETE`, exit 2.

**Mutations**: forcing `gate-verdict`'s empty list to `'()` turns 2 test-cases red. Restoring the
runner's old `incomplete?`/`all-pass?` makes the end-to-end probe exit 0 with "all pass" again.

**History, measured on a copy of main's timings.jsonl, report only.** Of 949 valid full-suite
records, **2** contain an undeclared PASS/0-test unit, both with `all_pass` true:
`test-generators.rkt` (the 161 incident) and `test-int-list-quick.rkt`. They are NOT annotated;
see open question 4.

## (b) 164 open 2 — GUARD refusal exits 3 (`57a542e2`)

**What changed.** The exit codes now live in one table, `suite-plan.rkt` § EXIT STATUS (:336–339):
0 pass, 1 failures, 2 incomplete, **3 guard refused**, plus 75 lock busy from `suite-lock.rkt:71`.
The GUARD (`run-affected-tests.rkt:362`) prints `Exit status 3: NOTHING WAS RUN (not a pass).` and
exits 3. The final exits use the constants. Documented in testing.md (the exit-code list and the
§ `--force-rerun` note).

**Test**: `suite-plan/exit codes`. The two ran-nothing codes must be nonzero and all five codes
distinct.

**End to end**: fresh timings.jsonl, then `--all --dry-run`. `--dry-run` was used so that a guard
that failed to fire could still run nothing.
- before: exit 0;
- after: exit 3;
- `--force-rerun` still gets past the guard.

**Mutations**: `EXIT-GUARD-REFUSED 0` turns the test red; the runner's old `(exit 0)` makes the
end-to-end run exit 0 again.

## (c) 164 open 3 — medians skip polluted records, plus the annotation tool (`fa6437fc`)

**What changed.**
- `record-invalid-reason` (`suite-plan.rkt:106`) returns a reason when a record carries
  `"invalid"`, or when `len(results) < file_count`.
- `historical-medians` skips such records (:85), and they no longer use up its window of 5 runs.
- New tool `tools/annotate-invalid-timings.rkt [--dry-run] <path>`:
  - It inserts `"invalid":"results N < file_count M (DEFERRED 164)"` as the FIRST key and keeps
    every other byte of the line.
  - It is idempotent: already-annotated and unparseable lines are left alone.
  - It rewrites atomically (temp file + rename) and holds the suite lock exclusively.

**Tests**:
- 2 test-cases in test-suite-plan. Red against the old reader: :59 got 999999 instead of 10, and
  :68 got 888888 instead of 20.
- 3 in `test-annotate-invalid-timings.rkt`: annotation, idempotence, and a file round trip with
  `--dry-run`.

**Mutations**: dropping the medians filter turns the 2 red again; dropping the already-annotated
clause turns all 3 annotation tests red.

**Measured on a COPY of main's file.** Copy taken 2026-10-13 04:3x; sha `820d9800…`, 201,970,866
bytes, 1936 records, 971 with file_count ≥ 300. Main's file was **not** touched.
- **24 records annotated: 13 full-suite with `all_pass` true** (DEFERRED 164's 13), 9 full-suite
  with `all_pass` false, and 2 with file_count < 300 (258 and 210 files).
- An independent Python count gives the same 13/9/2.
- Exactly 24 lines changed, and each changed line is the original with only the key inserted.
- A second pass annotated 0 records and left the sha unchanged (`bf7cfd11…`).

The annotated list runs from 2026-03-04 to 2026-08-05; the tool prints each record's timestamp,
commit and reason. **Running it on main's file is the coordinator's step** (see below).

## (e) 164 open 5 — explicit offset, schema 4 (`f20220df`)

**What changed.**
- `bench-lib.rkt`: `TIMINGS-SCHEMA-VERSION` = 4 (:261); `seconds->iso-timestamp` (:265) writes
  e.g. `2026-10-13T04:38:21-07:00`; `current-iso-timestamp` (:263).
- `parse-record-timestamp` (:284) honours an explicit offset. It reads `Z` as UTC only for schema
  ≥ 4, and as the local clock for schema ≤ 3 or unversioned records.
- Both writers (`run-affected-tests.rkt:1421`, `benchmark-tests.rkt:122`) now write
  `TIMINGS-SCHEMA-VERSION`; each previously wrote a literal 3.

**Existing readers accept both forms.** The Racket reporters treat the field as an opaque string.
`benchmark-dashboard.py`'s `fromisoformat(ts.replace("Z","+00:00"))` parses the new form: checked,
the recorded timestamp gives epoch 1791891501, equal to `date +%s` at that moment. The first 19
characters are the local clock in both formats, so a string sort stays chronological across the
cut-over. Old records stay as written; the schema number marks the cut-over.

**Tests**: `tests/test-timings-timestamp.rkt`, 3 test-cases. Red with the old formatter: 2 of 3
failed (the timestamp ended in `Z`, and the schema was 3).

**Mutations**: forcing the offset to 0 turns 2 test-cases red ("…+00:00 should end in -07:00");
schema 3 turns 1 red.

One bug in my own test was fixed on the way: the format regexp first used `#rx` with `{n}`, which
needs `#px`.

## (f) 162 open 1 — comment (`36bd4e7d`)

`run-affected-tests.rkt:909` now says the "impact NIL" measurement is **REFUTED — DEFERRED 162**:
both legs ran the inert sort. It cites 389b3413's 127.6 → 110.5 s and notes that the ratio holds
but the absolute seconds do not. There is no test, since only a comment changed.

## (g-i) 160 support — per-run failure logs (`1753757d`)

**What changed.**
- **Archive.** Each run writes to `data/benchmarks/failures/runs/<run-id>/`. The run id is the
  local `YYYYMMDDTHHMMSS-<pid>` (`make-run-id`, `suite-plan.rkt:357`). Workers get it as
  `--failure-dir` (`run-affected-tests.rkt:1011–1017`), and logs carry a `run:` line.
- **Nothing deletes logs any more.** The worker's delete-on-pass is gone (`batch-worker.rkt:477`).
- **Latest view.** `failures/*.log` remains the per-file **latest** view, refreshed for every file a
  run reports (`refresh-failure-views!`, :649).
- **Retention.** A fully passing run keeps no directory. The newest **20** directories with
  evidence are kept (`FAILURE-RUNS-KEPT`, :354; `runs-to-prune`, :364), and `failures/latest`
  links to the newest.
- **Commands.** `--failures-run ID|latest` prints one archived run; `--failures` reports the
  archive's size and newest id.
- `.gitignore` now ignores the whole `failures/` directory.
- testing.md protocol step 1 is updated.

**Tests**: 3 test-cases (run-id order and uniqueness; retention; which names are a file's logs).

**End to end** with a scratch file that fails, then passes:
- before: the passing re-run deleted the only log ("evidence of run 1: GONE");
- after: `runs/<id>/test-zz-flip.rkt.log` survives, and the top-level view shows none.

**Mutations**: if retention keeps everything, test-suite-plan.rkt:301 goes red. If the worker is
not given `--failure-dir`, the end-to-end probe loses the evidence again.

## (d) 164 open 4 — worker stderr drained (`58dcf0f8`)

**Measured: the 164 open(4) conjecture holds, and the effect is worse than "lost output".** A
scratch test wrote ≈240 KB to the worker's real fd 2 (`/dev/stderr`, outside the per-file
capture) and then passed:
- the **old runner** reported `TIMEOUT (20.0s)` for that passing file and then **hung** in
  `subprocess-wait` until my 200 s `timeout` killed it (exit 124). The worker blocks flushing the
  full pipe as it exits;
- the **new runner** reports PASS in 0.0 s, exit 0, and its `worker-0.stderr.log` holds 4007
  lines.

**What changed.**
- Each worker's stderr is read on its own thread (`run-affected-tests.rkt:1023`), timestamped, and
  attributed to the unit that worker was running at the time (`attribute-stderr`,
  `suite-plan.rkt:410`). The cap is 20000 lines per worker.
- After the run, the run directory receives:
  - `worker-N.stderr.log`: everything, with a marker at each dispatch;
  - for a **failed** unit, the stderr attributed to it, appended to its log;
  - for a dispatched unit that **never reported**, a `NO RESULT` log (:1261) with the worker's
    pid, exit status and stderr. This is also copied to the top-level view.
- Every worker writes the prelude's 5 metric lines at load (measured: PERF-COUNTERS,
  PHASE-TIMINGS, PROVENANCE-STATS, MEMORY-STATS, CELL-METRICS). `metric-line?` (:437) excludes
  them as evidence, so they keep no run directory.
- **Dead-worker banners** used to say "Run `raco make driver.rkt`". They now print each worker's
  first stderr lines (`print-worker-stderr-digest`, :623). For a linklet mismatch they name the
  **stale module** — the importing instance — and the rebuild command (`diagnose-worker-stderr`,
  :423).
- Shown on the item-(h) repro: the banner names `tests/test-support.rkt`, and
  `test-substitution.rkt.log` reads `NO RESULT` with the `instantiate-linklet` text.

**Tests**: 4 test-cases (attribution, log names, the diagnosis on the verbatim repro stderr,
metric lines). **Mutations**:
- attribution always to the worker: :323 red;
- no diagnosis: :347 red;
- an inert drain: the flood probe gives no result within 30 s ("ABORTED", exit 2).

## (g-ii) 160 support — worker→unit sequence (`6a806d03`)

**What changed.** `worker-sequences` (`suite-plan.rkt:452`) builds, per worker, its index, its pid
and the exact work lines it was sent, in dispatch order. The lines are relative to
`racket/prologos/` and keep the shard suffix `\tI/K`. The result goes:
- into every recorded run as `'workers` (`run-affected-tests.rkt:1435`);
- into the run directory as `run.json` (:1336), with run_id, checkout, command, verdict and unit
  counts. This includes INCOMPLETE runs, which write no timings record.

**Replay in one process** — checked on a 2-unit run: same results, same order:

```
cd racket/prologos
jq -r '.workers[N].units[]' data/benchmarks/failures/runs/<id>/run.json \
  | racket tools/batch-worker.rkt --stdin --file-timeout 300
```

**Size**: 174 bytes for 3 units. A full run is about 490 work lines, estimated at 15–20 KB but not
measured; records average about 104 KB (201.97 MB over 1936 records).

**Test**: 1 test-case (order, pid, relative lines, shard suffix, round trip through
`parse-work-line`). **Mutation**: leaving the lines absolute turns :371 red.

## (h) the worker's own modules — stale test-support.zo (`bd6fddd1`)

**Reproduced in this worktree.** The recipe matters:
- an edit to `substitution.rkt` alone did **not** reproduce it here, because driver.rkt's exported
  names did not move;
- adding a keyword-argument `define` to `driver.rkt` before `process-file` shifts the lifted names.
  After `raco make driver.rkt tests/test-substitution.rkt`, a direct worker start fails with
  `instantiate-linklet: mismatch … name: process-file31.1 … importing instance:
  tests/test-support.rkt`;
- with the pre-fix runner, `--tests tests/test-substitution.rkt` then gives DEAD WORKERS, `0 tests
  … ABORTED`, exit 2, and the banner says "raco make driver.rkt".

**What changed.**
- The dynamic edge is declared **once**: `WORKER-MODULE` and `WORKER-DYNAMIC-MODULES =
  ("tests/test-support.rkt")` (`suite-plan.rkt:479–480`), with
  `worker-precompile-paths` (:483) built from them.
- `batch-worker.rkt` dynamic-requires exactly that list (:84–90).
- Three paths now build those modules in the PRODUCTION stage, after driver.rkt:
  1. the targeted scoped precompile (`run-affected-tests.rkt:449` onward), which prints
     "Pre-compiling driver + the batch worker + N test file(s)";
  2. the full-suite `precompile-modules!`, via `#:extra-production` (`bench-lib.rkt:406`, called at
     `run-affected-tests.rkt:741`);
  3. the `--no-precompile` stale scan (:812). It flags a worker module as stale when its `.zo` is
     missing, older than its source, or older than `driver_rkt.zo`.

**Did the other paths have the gap?** Both compile all of `tests/`, so they covered
test-support.rkt **by accident**, and neither ever built `tools/batch-worker.rkt`. That is from
reading the code: no `--all` was run, and the old `--no-precompile` path was not exercised in the
stale state.

**Verified.** Each check started from a freshly staled state (direct worker start: exit 1,
mismatch):
- the targeted run now passes 56 tests, exit 0;
- `--no-precompile` reports "Detected 9 stale .zo file(s)" and passes;
- **a mutant without the worker paths** gives DEAD WORKERS plus `STALE COMPILED MODULE:
  …/tests/test-support.rkt`, exit 2.

driver.rkt was restored afterwards (`git diff` empty), and driver + worker + test-support were
rebuilt with the limit; a worker starts with exit 0.

**Tests**: 2 test-cases:
1. the precompile set holds batch-worker.rkt and every `WORKER-DYNAMIC-MODULES` entry;
2. a **static read** of `batch-worker.rkt` finds that every `dynamic-require` is either the unit
   under test (`abs-file`) or goes through the constant.

Red against the old set and the old worker (:392, :416). **Mutations**: a set without the dynamic
modules turns :393 red; the worker's old hardcoded test-support path turns :416 red.

## Extra — stop waiting once every worker has exited (`c47c450b`)

Found while verifying (d). This was not in the brief. A worker that died mid-unit left the
collector waiting out the whole per-file `--timeout` (300 s), and workers dead at load cost the
30 s probe.

**What changed.** The collector also syncs on `readers-done` (`run-affected-tests.rkt:1063`), which
fires once every stdout reader has finished. It then drains what is buffered and stops; the gate
turns the missing units into INCOMPLETE.

**Before and after.** The "before" is `bd6fddd1`, i.e. this change reverted.

| case | before | after |
|---|---|---|
| a file `(exit 3)`s its worker mid-file | still waiting when killed at 300 s (exit 124) | `NO RESULT: every batch worker has exited; 1 unit(s) never reported`, INCOMPLETE, exit 2, **11 s**; the NO RESULT log has exit status 3 and the stderr line |
| every worker dead at load | "no results after 30s" | **"after 0.2s"**, stale module named |

Normal runs are unchanged: 6 files on 3 workers, 111 tests, all pass. There is no unit test,
because the change is process-level; the probes above are the red/green evidence.

---

## Paste-ready DEFERRED status text

Every hash below is on branch `runner-queue-gate` and **not yet merged**. Replace each with the
merge hash once it is merged.

**161** —
> **Fixed** on branch `runner-queue-gate` in `2999a74b` (not yet merged). The gate lives in
> `tools/suite-plan.rkt` (`gate-verdict` / `gate-incomplete?` / `gate-all-pass?`). A unit that
> reports PASS with 0 tests is a NO RESULT: the progress line says `EMPTY — 0 tests`, the run is
> INCOMPLETE, exit 2, and nothing is recorded. The rule applies per unit, so an empty shard is
> caught too. A fail or timeout with 0 tests stays a failure.
>
> Legitimately empty files are named in an explicit list, `TEST-FREE-FILES`: currently
> test-multiclause-debug.rkt and test-p2-debug.rkt. A marker comment was rejected because an
> exemption must be auditable in one place, and a marker travels silently with copy-paste. A
> declared file that runs tests is reported as stale. `tests/test-support.rkt` is no longer a unit
> (`NON-TEST-MODULES`): it is the worker's own fixture.
>
> Pinned by 5 test-cases in `tests/test-suite-plan.rkt`, red against the old rule. End to end, a
> scratch file with no tests went from "all pass", exit 0, to "INCOMPLETE", exit 2.
>
> **Open**:
> 1. *Why* test-generators ran 0 tests on a cold build is still not established. It is now loud,
>    not silent.
> 2. Main's history holds 2 such records (test-generators.rkt, test-int-list-quick.rkt, both
>    `all_pass` true). They are not annotated; that is a decision.

**164** (status of the open items) —
> **Open 1 (zero tests)**: fixed with 161, `2999a74b`.
>
> **Open 2 (GUARD exit 0)**: fixed in `57a542e2`. A refusal exits **3**, and the banner says
> "Exit status 3: NOTHING WAS RUN". All exit codes are in one table, `suite-plan.rkt` § EXIT
> STATUS: 0 / 1 / 2 / 3, plus 75 for the suite lock.
>
> **Open 3 (reader filter)**: fixed in `fa6437fc`. `historical-medians` skips records whose
> results are fewer than their file_count, or that carry `"invalid"`. The records are annotated,
> not dropped (owner decision), by `tools/annotate-invalid-timings.rkt`. The tool is idempotent,
> rewrites atomically and holds the suite lock exclusively. On a copy of main's file it annotates
> **24** records: the **13** full-suite `all_pass` ones counted here, 9 full-suite failing ones,
> and 2 smaller runs. Main's own file is not yet annotated (coordinator step).
>
> **Open 4 (stderr)**: fixed in `58dcf0f8`. **The conjecture is measured true, and the effect is
> worse than lost output**: ~240 KB to a worker's real stderr made the old runner report TIMEOUT
> for a passing file and then hang in `subprocess-wait`. Worker stderr is now drained and
> attributed per unit. It goes to `worker-N.stderr.log`, to failed units' logs, and to a NO RESULT
> log for each unit a dead worker never reported. Dead-worker banners print the stderr and name a
> stale module. `c47c450b` also stops the collector waiting 300 s once every worker has exited.
>
> **Open 5 (timestamps)**: fixed in `f20220df`. `schema_version` 4 writes the local offset
> (`…-07:00`). `bench-lib.rkt` `parse-record-timestamp` reads both forms (schema ≤ 3 `Z` = local
> clock). Old records stay as written.

**162 open 1** —
> Fixed in `36bd4e7d` (branch `runner-queue-gate`, not yet merged). The comment at
> `tools/run-affected-tests.rkt` (the "Read historical timings" block) now marks "impact NIL" as
> REFUTED and cites this entry. Open 2 and 3 are unchanged.

**160** (support items; the investigation itself is still open) —
> **Support (i)**: `1753757d`. Failure logs are kept per run in
> `data/benchmarks/failures/runs/<run-id>/`, which nothing edits. The newest 20 runs with evidence
> are kept, plus `failures/latest` and `--failures-run ID|latest`. `failures/*.log` stays as the
> per-file latest view, and a later pass no longer destroys the earlier log.
>
> **Support (ii)**: `6a806d03`. Each run records `'workers` (per worker: pid and work lines in
> dispatch order) in its timings record and in `runs/<id>/run.json`, including INCOMPLETE runs. A
> victim's worker history replays in one process:
> `jq -r '.workers[N].units[]' run.json | racket tools/batch-worker.rkt --stdin`.
>
> The discriminating measurement (`--all` ×N, then a replay of the victim's worker sequence) is now
> possible but has **not been run**.

**New entry (the coordinator assigns the number)** — *a targeted run could leave the batch
worker's own dynamic dependency stale, and every worker died at load*:
> **Found by** the coordinator, 2026-10-13, reproduced twice; reproduced again on branch
> `runner-queue-gate`. `tools/batch-worker.rkt` loads `tests/test-support.rkt` by `dynamic-require`
> (deliberately), and `raco make` never follows that edge. The `--tests` scoped precompile built
> only driver.rkt and the listed tests. After a driver.rkt rebuild, a targeted run whose tests do
> not require test-support.rkt therefore left `tests/compiled/test-support_rkt.zo` stale.
> Every worker then died at load with `instantiate-linklet: mismatch … importing instance:
> tests/test-support.rkt`. That printed as DEAD WORKERS, 0 tests, ABORTED, and the banner advised
> `raco make driver.rkt`, which cannot fix it. Even `raco make tools/batch-worker.rkt` does not
> reach the stale file.
>
> Repro: add a keyword-argument define before `process-file` in driver.rkt, which shifts the lifted
> names; an edit to substitution.rkt alone did not reproduce it on the branch. Then run
> `raco make driver.rkt tests/test-substitution.rkt` and
> `--tests tests/test-substitution.rkt`.
>
> **Fixed** in `bd6fddd1` (not yet merged):
> - the edge is declared once, as `suite-plan.rkt` `WORKER-DYNAMIC-MODULES`;
> - batch-worker.rkt dynamic-requires exactly that list;
> - `worker-precompile-paths` (batch-worker.rkt plus that list) is built in the production stage by
>   the targeted precompile, the full-suite `precompile-modules!` and the `--no-precompile` stale
>   scan. The last two had covered test-support.rkt only because they compile all of `tests/`, and
>   never built batch-worker.rkt;
> - pinned by 2 test-cases, one of them a static read of the worker;
> - `58dcf0f8` makes the banner print the worker stderr and name the stale module.
>
> **Open**:
> 1. Every checkout older than the merge still has the gap.
> 2. The full-suite precompile change was verified by reading only.

## Needs the coordinator

1. **Annotate main's timings.jsonl.** Run `racket tools/annotate-invalid-timings.rkt --dry-run
   racket/prologos/data/benchmarks/timings.jsonl` from main after merge; expect 24 newly
   annotated, 13 of them full-suite `all_pass`. Then run it without `--dry-run`. It takes the suite
   lock exclusively, but main's runner only participates **after** the merge, so run it while no
   suite is running in main.
2. **The full suite on the merge.** None was run here. Expect +3 test files, −test-support.rkt as a
   unit, and +34 tests relative to the same base. The full-suite precompile path
   (`precompile-modules! #:extra-production`) has only been verified by reading.
3. **Bring other checkouts up to date.** The queue, the stale-worker fix and the gate exist only
   where this runner is. Other checkouts' runs still contend; this extends DEFERRED 163 open(1).
4. **First full suite after merge.** The schema becomes 4 and `'workers` appears in every record.
   Check the size of a full-run `'workers` field: it is estimated, not measured.

## Open questions

1. **Affected mode.** A plain `run-affected-tests.rkt` run (no flags) that selects ≥ 100 files
   takes the lock exclusively. I chose this because such a run starts a worker per core. The
   alternative is that only `--all` is exclusive. Which?
2. **The two debug scripts.** `test-multiclause-debug.rkt` and `test-p2-debug.rkt` are printf debug
   scripts with no checks. Declare them test-free (done), or move or delete them?
3. **`--tests tests/test-support.rkt` given explicitly** is still dispatched in targeted mode and
   then reports `EMPTY` / INCOMPLETE. Drop it with a message instead?
4. **History.** Should the 2 historical records with an undeclared PASS/0-test unit
   (test-generators.rkt, test-int-list-quick.rkt) also get `"invalid"`? The tool annotates only the
   results < file_count shape today.
5. **The GUARD after a wait.** The guard re-check can refuse a queued `--all` in the same checkout
   when the run it waited for left no `.rkt` changes behind (exit 3). This is the guard's purpose,
   but it can surprise someone who wanted a flake re-run; they need `--force-rerun`.
6. **Retention.** It is 20 evidence-bearing runs, and passing runs keep no directory, so their
   sequence exists only in the timings record and is absent under `--no-record`. Is that enough
   for 160?
7. **Long timing runs block targeted runs.** A bench-ab run holds the exclusive lock for its whole
   run, possibly many minutes, so other sessions' targeted runs wait that long. This was intended
   by the brief; confirm.
8. **The first-result probe.** The 30 s probe is now mostly redundant with `readers-done`. Keep it?
