# Record note — guards + hook wiring + eq?-table sweep (branch `guards-hook-sweep`)

Base `58241c0c` (main HEAD at worktree creation, 2026-10-13). Written at `c02d77b5`.
Racket 9.3 (`/Applications/Racket v9.3/bin/racket`); bash 5.3 (`/opt/local/bin/bash`, what
`env bash` resolves to here) and `/bin/bash` 3.2 both exercised; `/usr/bin/awk` 20200816 (BWK).
**Not merged** — the coordinator verifies and merges.

| Commit | What |
|---|---|
| `9d24d463` | DEFERRED 159 (a): the guard refuses a compile without `PLT_CS_COMPILE_LIMIT` |
| `e9b2a30e` | DEFERRED 163 open (2): the guard refuses a machine-wide `pkill`/`killall` of racket processes |
| `d5359d2a` | DEFERRED 162 open (2): `benchmark-tests.rkt`'s two eq?-keyed per-file tables (fixed, tested) |
| `c02d77b5` | chore: the guard's old unbounded-racket message named the 9.0 binary |

**Headline finding, before the details: the guard is registered nowhere today** (§3). Items 1
and 2 are tested and committed, but they are inert in every session until someone registers
the hook. That registration is the owner's decision (§3 gives the options), and it is the
precondition for the 159(a) and 163(2) status flips in §5.

---

## 1. DEFERRED 159 (a) — `raco make` without the compile limit — `9d24d463`

**What changed.** `tools/hook-guard-racket.sh`:
- `:79` `guard_analyse`, a POSIX-awk tokenizer and analyser. Racket detection used regexes
  over the raw command string. That cannot tell which word is the command, or which
  environment it runs in, so the new rules work on tokens instead:
  - split at unquoted `; & && | || ( )`, backticks and newlines, keeping `2>&1`, `>&2` and
    `&>` as redirections;
  - drop `#` comments; honour `'…'`, `"…"` and backslash escapes;
  - skip shell keywords;
  - see through executors (`timeout`, `env`, `nice`, `nohup`, `time`, `exec`, `command`,
    `xargs`, `sudo`, `caffeinate`, `stdbuf`, `setsid`), each with its own argument-taking
    options (`:271-278`);
  - analyse `find … -exec CMD` and `bash|sh|zsh|dash|ksh -c 'CMD'` / `eval` as commands of
    their own, with the environment they inherit.
- `:177-190` is the rule. It refuses `raco make|setup`, `raco pkg install|update`, and
  `raco test --make|-y` when the command's environment lacks `PLT_CS_COMPILE_LIMIT` ≥ 1000000.
  The binary may be spelled as bare `raco`, any path ending `/raco` (quoted or not), or
  `racket -l-|-l|--lib raco[/main.rkt]`. The last is `bin/raco`'s own exec line, measured:
  the script ends `exec "${bindir}/racket" -N "$0" '-l-' 'raco/main.rkt' …`.
- `:352` is the message. It cites DEFERRED 159, gives the inline command, and says that an
  export from an earlier Bash call is invisible to the hook, so the limit must be inlined. It
  also warns that a bare `raco` can resolve to `/opt/homebrew/bin/raco` → Racket **9.0**
  (measured: `ls -la /opt/homebrew/bin/raco`).
- `.claude/rules/testing.md:120-124` documents the denial.

**Decisions (each pinned by a row):**

| Shape | Verdict | Why |
|---|---|---|
| `PLT_CS_COMPILE_LIMIT=1000000 raco make …` (also through `timeout -k`) | allow | prefix assignment reaches the process |
| `env PLT_CS_COMPILE_LIMIT=1000000 raco make …` | allow | same |
| `export PLT_CS_COMPILE_LIMIT=1000000 && … raco make` (earlier in the same command) | allow | exported for every later command |
| `PLT_CS_COMPILE_LIMIT=1000000; export PLT_CS_COMPILE_LIMIT; raco make` | allow | same |
| `PLT_CS_COMPILE_LIMIT=1000000; raco make` | **deny** | an unexported shell variable never reaches the child |
| `PLT_CS_COMPILE_LIMIT=1000000 cd x && raco make` | **deny** | the prefix applies to `cd` only |
| `raco make …; export PLT_CS_COMPILE_LIMIT=…` | **deny** | the export comes after the compile |
| `…=10000` / `…=` | **deny** | value must be a decimal ≥ 1000000 (10000 is the CS default, i.e. the interpreted state); a `$VAR` value is refused too |
| `export …; env -i raco make` | **deny** | `env -i` clears it |
| `raco setup`, `raco pkg install\|update`, `raco test --make\|-y` | **deny** w/o limit | beyond the brief, see below |
| `raco test` (no `--make`), `raco pkg show`, `raco expand`, GNU `make` | allow | nothing written to `compiled/` |
| `grep "raco make"`, `git commit -m "raco make …"`, `echo raco make`, a `#` comment | allow | not a command word |

**Beyond the brief: `setup` / `pkg install|update` / `test --make`.** These also write `.zo`
files, and `prologos-dev` is a **linked** package. Measured: `raco pkg show -l -a` →
`prologos-dev … (link "/Users/avanti/dev/projects/logos/prologos/racket")`. So such a command
run from any checkout rebuilds the MAIN checkout's `compiled/`, which is the exact
159 state. Keeping or dropping this is open question 2.

**Tests** (`tools/hook-guard-racket.test.sh:73-123`). `check` gained an optional 4th
argument: the text the deny reason must contain. A row denied by a *different* rule reports
`DENY(other rule)` and fails. Without this, `racket -l- raco make` rows would pass on the
unbounded-racket rule. 26 DENY rows and 20 ALLOW rows were added.
- **Red first**: 26/26 new DENY rows failed (got ALLOW); the 45 other rows passed.
- **Green**: 71/71, also with `PATH` forcing `/bin/bash` 3.2 (BSD awk in both runs).
- **Mutation** (each restored, then `git diff --exit-code` was clean):

| Mutation | Rows red |
|---|---|
| the rule's `print` removed (rule reverted) | 26 |
| `limit_ok` ignores the value | 2 (default value, empty value) |
| a bare `VAR=v;` counted as exported | 1 (unexported shell var) |
| executors not seen through | 5 (bounded, `racket -l-` ×2, `env -i`, `xargs`) |

Cost: ~33 ms per hook call including two `jq` runs (10 calls 0.33 s, measured).

## 2. DEFERRED 163 open (2) — machine-wide `pkill`/`killall` — `e9b2a30e`

**What changed.**
- `tools/hook-guard-racket.sh:192-236` (awk) parses both commands:
  - `pkill`, BSD and procps forms: clustered flags, argument-taking options (`:279`),
    `-9`/`-KILL`/`-USR1`, `--long[=v]`, `--`;
  - `killall`: `-m`/`-r` regex, `-I`, and `-c NAME` (checked as a name).
- It emits each pattern of a `pkill` that is **not parent-scoped** (`-P <pid>`, `-P<pid>` or
  `--parent`), and each name of a `killall`, which cannot be parent-scoped.
- `:311` `reaches_racket` decides. Either test suffices:
  1. **Name test.** The pattern names a racket-side process: `racket`, `raco`,
     `batch-worker`, `run-affected-tests`, `bench-ab`, `prologos` or `.rkt`, in any case.
     This catches the absolute paths of every checkout, which no sample list can cover.
  2. **Regex test.** Applied as the ERE pkill/killall would use (`grep -E`, the same
     `regcomp`; `-i` and `-x` honoured), the pattern matches a sample:
     - process names (`racket`, `raco`) always;
     - with `pkill -f`, also the command lines of live racket processes (`:305`). These are
       the worker spawn shape (`run-affected-tests.rkt:801`), the LSP server line seen in
       `ps` on this machine, `bin/raco`'s exec line, and `run-file.rkt`.

     This test catches `rack.t`, `.` and `""`.
- `:329` is the message. It cites DEFERRED 163 (and 164's "all pass" consequence), and gives
  `kill <pid>`, `pkill -P <parent> -f …`, and the runner's own orphan form
  `pkill -P 1 -f "<this checkout>/racket/prologos/tools/batch-worker.rkt"`.
- `.claude/rules/testing.md:126-130` documents the denial.

**Allowed**: parent-scoped kills, unrelated `pkill`/`killall` (`sleep 999`, `caffeinate`,
`Safari`, `my-probe.py`, `pkill -x rack`), `pgrep`, `ps | grep`, `kill <pid>`, and mentions of
these commands in `grep`/`echo`.

**Tests** (`:125-167`): 21 DENY rows and 16 ALLOW rows added.
- **Red first**: 21 failed. Twenty got ALLOW. The other, `sudo pkill -f racket`, was refused
  by the unbounded-racket rule for the wrong reason (its regex (c) matches `sudo … racket`),
  and the rule check in `check` reported it as `DENY(other rule)`.
- **Green**: 107/107 on bash 5 and 3.2. The table caught a bug on the way: `-P12345` had
  been parsed as a signal name. Fixed: a signal name needs two letters.
- **Mutation**:

| Mutation | Rows red |
|---|---|
| `reaches_racket` always false (rule reverted) | 21 |
| short `-P` not honoured | 3 (`--parent` row stays green: separate path) |
| name test (1) removed | 3 (`killall racket` ×2, another checkout's absolute path) |
| regex test (2) removed | 4 (`killall -m`, `-fi "RACK.T"`, `rack.t`, empty pattern) |

**Recommended narrowing of the allow-list (NOT applied, owner's file).**
`.claude/settings.local.json:71`, `"Bash(pkill:*)"`, has been there since `2ebf0190`
(2026-02-19). Replace it with `"Bash(pkill -P:*)"`. Parent-scoped kills still run without a
prompt, every other `pkill` prompts, and the guard refuses the racket-reaching ones either
way once it is registered. `killall` is not on the allow-list (grep: 0).

## 3. Is the hook wired? — **No. It is registered nowhere today.**

Measured (read-only):

| Settings file | PreToolUse refs to `hook-guard-racket` |
|---|---|
| main `.claude/settings.json` (untracked, 7 lines: one `racket -e` permission) | 0 |
| main `.claude/settings.local.json` (tracked) | 0 |
| every `.claude/settings*.json` in all 15 `git worktree list` checkouts (main and this one included) and both clones (`prologos-egraph-spike`, `prologos-preduce-auto`): 20 files, re-checked at the end of the session | 0 |
| `~/.claude/settings.json` (hooks: only a PostToolUse `Write\|Edit` MacMD opener), `~/.claude/settings.local.json` | 0 |
| `/Library/Application Support/ClaudeCode/` (managed policy) | does not exist |

**History, from Claude Code transcripts (`~/.claude/projects/…wizardly-mendel-2fd502/0b41d684….jsonl`):**
- The hook was installed on 2026-08-09 at 02:17–02:18Z, into the **untracked**
  `.claude/settings.json` of worktree `wizardly-mendel-2fd502`. That worktree lived under the
  repo's OLD location `~/dev/projects/prologos`, which no longer exists (`ls`: no such
  directory).
- It fired. At 02:18:25Z the main session's `racket /tmp/nonexistent-probe.rkt` was refused.
  At 02:31:24Z a **workflow subagent** (`isSidechain: true`) was refused too.
- `Bash(racket:*)` was already allow-listed (`settings.local.json:13`, since `9c6a0429`
  2026-02-08) when that command was refused. So a hook deny beats an allow rule. This is
  inferred from the historical transcript, not re-tested today.
- Inference: the registration was lost with that worktree or the repo move.
  `testing.md:132-143` still describes per-clone installation, but no clone has it.

**Which sessions it applies to:**
- **Claude Code sessions** (main session and subagents) run `.claude/settings*.json` hooks
  when the hook is registered there. The 2026-08-09 evidence confirms this, subagents included.
- **Hermes sessions do not**, and that includes this one, a Hermes subagent whose model calls
  itself Claude Code. The brief says "Claude Code sessions do not run Claude Code hooks"; read
  as Hermes sessions, that is **confirmed live**:
  1. Fed to the guard, `true || racket /nonexistent-probe.rkt` printed `deny`.
  2. The same command, run through this session's terminal tool, executed: `PROBE-RAN exit=0`.
  3. Hermes's own `pre_tool_call` shell hooks are configured nowhere: `~/.hermes/config.yaml:1842-1875`
     is a commented example only, the profile's `config.yaml` has no `hooks:` key, the
     profile `hooks/` directory is empty, and there is no `~/.hermes/shell-hooks-allowlist.json`.

  Only Hermes's own command-approval layer ran. It flagged my commands that merely
  *contained* `pkill` text ("kill hermes/gateway process") and auto-approved them, so nothing
  in Hermes reliably stops a real `pkill -f racket`.

**To make the guard live (options, none applied):**
- **Claude Code, user-level.** Add the PreToolUse block to `~/.claude/settings.json` with the
  absolute path of main's guard. One place covers main, every nested worktree and the clones.
  The catch: it applies to every project, and it denies unbounded `racket` anywhere.
- **Claude Code, per checkout.** Add it to `.claude/settings.json` (untracked) as
  `testing.md:132-143` describes. This must be repeated per worktree, which is how it was lost.
- **Hermes.**
  - Add `hooks: pre_tool_call: [{matcher: "terminal", command: <guard>, timeout: 10}]` plus
    first-use consent (or `hooks_auto_accept`).
  - Input already fits. Measured in `~/.hermes/hermes-agent/agent/shell_hooks.py:3-4` and
    `:88`: stdin carries `tool_input` (= the tool's args, so `.tool_input.command` works).
  - **Output does not fit.** Hermes honours only a top-level `action|decision: "block"`
    (`shell_hooks.py:463-482`), not Claude Code's `hookSpecificOutput.permissionDecision`.
    The guard's `deny()` would be **ignored: a fail-open**.
  - The fix is to add `decision: "block", reason: $r` at top level in `deny()`. One output
    then serves both harnesses (both keys say deny). This is not applied here: open question 1.

## 4. DEFERRED 162 open (2) — sweep of eq?-keyed tables over non-interned keys

The scope was `racket/prologos/tools/*.rkt` and `tools/*.rkt`, grepped for
`hasheq|make-hasheq|for/hasheq|for*/hasheq|hasheqv|make-weak-hasheq`, plus the
`seteq`/`memq`/`assq` family. JSON *objects* built with `hasheq 'k …` are N/A: their keys are
symbols. Lines are at `d5359d2a`.

**Probe** (`scratch/guards-hook-sweep/eq-probe.rkt`, Racket 9.3), measured:

| Comparison | Result |
|---|---|
| `"file"` read by `read-json` from two records, `eq?` | `#f` (`equal?` `#t`) |
| JSON-read vs path-built (`path->string (file-name-from-path …)`), `eq?` | `#f` |
| `make-hasheq` lookup with either other key | `MISS` |
| a literal returned by a function vs the same literal in a quoted list, `eq?` | **`#t`** (literals are interned) |
| `format`-built vs literal, `eq?` | `#f` |
| JSON object keys | all symbols |

| # | Site (file:line) | Keys: insert → lookup | Can a lookup miss? | Severity | The copied-key test |
|---|---|---|---|---|---|
| 1 | `racket/prologos/tools/benchmark-tests.rkt:212` `file-baselines` (was `make-hasheq` at `:205` @58241c0c) | insert `:215-218`: `'file` strings of previous runs via `read-all-runs` (read-json); lookup `:231-232`: the current run's `'file`, built from a path (`bench-lib.rkt:93/117` `filename-from-path`) | **Yes, always** (probe). Every file also got one sample per run, because accumulation at `:218` missed too | **Defect**: `detect-regressions-v2` returned `'()` for every run since `bf2616e8`, and `run-benchmark`'s exit status never reflected a regression. Exposure: run mode wrote 12 records to main's `timings.jsonl`, last 2026-02-26 | **FIXED `d5359d2a`** → `make-hash`; `tests/test-benchmark-tests.rkt` case 1 |
| 2 | `benchmark-tests.rkt:279` `file-samples` (was `:272`) | insert/lookup `:282-285`: `'file` strings from different JSON records | **Yes, always**. A file never reached ≥ 3 samples | **Defect**: `flag-high-variance` was always empty | **FIXED `d5359d2a`**; case 2 |
| 3 | `benchmark-tests.rkt:308-309` `total-hb`, `total-phases` | keys of JSON objects (`heartbeats`, `phases`) → symbols | No | — | — |
| 4 | `measure-production-n.rkt:91` `bucket-counts` | insert `:93-94`: string **literals** from `bucket-of` `:77-88`; lookup `:116`: literals from the quoted list `:114` | **Not today**: works only because Racket interns literal strings (probe `#t`). A computed label (`format`) would miss (probe `#f`) | Latent, low. A one-shot measurement script with no functions to test | `(hash-ref bucket-counts (string-copy "51-100") 0)` → 0 today. Fix: `make-hash`. Not fixed: no test harness, no live defect |
| 5 | `dep-graph.rkt:52/149/893/900/977` (static tables), `:1202/:1209` (`invert-dag`), `mutable-seteq` `:1098-1260`, `:1313` | quoted symbols; scanners intern with `string->symbol` (`:1111/:1120/:1149/:1171/:1182`); the runner interns changed files (`run-affected-tests.rkt:124/128/139/151`) | No (interned at every boundary) | — | `(compute-affected-tests (list (changed-source (string->symbol (string-copy "syntax.rkt")))))` hits |
| 6 | `form-deps.rkt:399` `registry`, `:409` `graph` | symbols from `read` (`:133` module name, `:140` require head) and `string->symbol` (`:234/:264/:275/:472`) | No | — | — |
| 7 | `profile-unify.rkt:191/193/194` | keys of `performance-counters.rkt:294/380/622` (quoted symbols) | No | — | — |
| 8 | `spine-census.rkt:153` `tbl` | `(cadr s)` with `symbol?` checked at `:148`; lookup `:166` by a struct-type name (symbol, `:193-198`) | No | — | — |
| 9 | `update-deps.rkt:52/75/90/105` | `string->symbol` (`:56/:59/:79/:95/:123`) | No | — | — |
| 10 | `run-phase9-sweep.rkt:64-137`, `bench-micro.rkt:86` (fixnum keys), `benchmark-report.rkt:110-294` (vega-lite objects) | empty, fixnum, symbol | No | — | — |
| 11 | `tools/bench-executors.rkt:75` `current-module-registry (hasheq)` | module-name symbols (production convention) | No | — | — |

**The five files reserved to another agent (findings only, untouched):**

| Site | Keys | Miss? |
|---|---|---|
| `run-affected-tests.rkt:772` `worker-ran` | the worker's stdin **port**: the same object at insert and lookup (`:774`). Identity is the intended key, and the inner table is `make-hash` over path strings | No |
| `suite-plan.rkt:182` `for*/fold … (hasheq)` | keys of phase/heartbeat JSON objects (symbols). (`historical-medians` `:56-63` is `for/hash` since `389b3413`) | No |
| `batch-worker.rkt:380`, `bench-lib.rkt:93/117`, `bench-ab.rkt:143/210/289` | JSON result objects (symbol keys). `bench-lib.rkt:126-170` merges read-json objects (symbol keys) | No / N/A |

The five reserved files are clean. One unrelated leftover there: DEFERRED 162 open (1), the
refuted "impact was NIL" comment, is still at `run-affected-tests.rkt:710-713`.

**Fix details (`d5359d2a`).**
- Both tables are now `make-hash`, with a comment citing 162.
- `(main)` became `(module+ main (main))` and the two functions are provided, so the test can
  require the module without starting a run. The CLI is unchanged:
  `racket tools/benchmark-tests.rkt --slowest 3` → exit 0.
- **Red first** (`run-affected-tests --tests tests/test-benchmark-tests.rkt`): `2 tests in
  3.0s (… 1 FAILURES)`. The log showed "the 5x slowdown must be reported" `actual: 0`, and
  "a file swinging 10x … must be flagged" `actual: 0`.
- **Green**: `2 tests in 3.2s (… all pass)`.
- **Mutation**: each table reverted alone → exactly its own case red (`actual: 0`).
  Restored, `git diff --exit-code` clean, green again.

## 5. Paste-ready `DEFERRED.md` status text (owner applies; not edited here)

**159, replacing the "(a)" bullet under "Prevention":**
> - **(a) DONE on branch `guards-hook-sweep` @ `9d24d463` (not yet merged).** `tools/hook-guard-racket.sh`
>   refuses `raco make|setup`, `raco pkg install|update` and `raco test --make` whose environment lacks
>   `PLT_CS_COMPILE_LIMIT` ≥ 1000000, however raco is spelled (bare, any path, `racket -l- raco`). It
>   reads inline `VAR=…`, `env VAR=…`, and an `export` earlier in the same command; a bare `VAR=…;` is
>   not exported and does not count. Decision table: 46 rows for this rule. Red first: 26/26. Mutation-checked.
>   ⚠ **Inert until registered**: no settings file registers the guard (record note §3,
>   `docs/tracking/handoffs/2026-10-13_GUARDS_HOOK_SWEEP_NOTE.md`), and Hermes sessions do not run
>   Claude Code hooks. (b) remains open.

**163, open item 2:**
> 2. ~~Agents can still do it by hand.~~ **Guard DONE on branch `guards-hook-sweep` @ `e9b2a30e` (not yet merged).**
>    `tools/hook-guard-racket.sh` refuses a `pkill`/`killall` whose pattern can reach a racket process,
>    by name (racket, raco, batch-worker, run-affected-tests, bench-ab, prologos, .rkt) or as a regex
>    over racket process names and command lines, unless it is parent-scoped (`pkill -P <pid>`).
>    Decision table: 37 rows for this rule. Red first: 21/21. Mutation-checked.
>    **Allow-list narrowing recommended, not applied:** `.claude/settings.local.json:71`
>    `Bash(pkill:*)` → `Bash(pkill -P:*)`. ⚠ **Inert until registered** (see 159 (a)).

**162, open item 2:**
> 2. **Swept 2026-10-13** (`guards-hook-sweep` @ `d5359d2a`, not yet merged; table in
>    `docs/tracking/handoffs/2026-10-13_GUARDS_HOOK_SWEEP_NOTE.md` §4). The sweep found **one more
>    instance of the class, now FIXED**: `tools/benchmark-tests.rkt` `file-baselines`/`file-samples`
>    (`make-hasheq` over read-json file names). `detect-regressions-v2` and `flag-high-variance` had
>    reported nothing since `bf2616e8`. Pinned by `tests/test-benchmark-tests.rkt` (copied keys,
>    red first, mutation-checked). One latent site: `tools/measure-production-n.rkt:91` works only
>    because string literals are interned (fix: `make-hash`, unapplied). Every other eq?-keyed table
>    in both `tools/` directories is keyed by symbols, fixnums or object identity. That includes the
>    runner's five files.

## 6. Open questions

1. **Register the guard, where?** The options are Claude Code user-level, per-checkout, and/or
   Hermes `pre_tool_call` (§3). For Hermes, `deny()` must also emit a top-level
   `decision: "block", reason`, or Hermes ignores it. That is a one-line change, not made here
   because wiring was a report-only item. Which do you want?
2. Keep the 159 rule's extension to `raco setup`, `raco pkg install|update` and
   `raco test --make` (§1), or narrow it to `raco make` as briefed?
3. The value check refuses anything but a decimal ≥ 1000000 (including `$VAR`). Is that too
   strict?
4. **Known gaps, by construction:**
   - `kill $(pgrep -f racket)` and `pgrep -f racket | xargs kill` (same blast radius, not
     `pkill`);
   - a variable command word (`"$RACO" make`);
   - `env -S '…'`;
   - `$(…)` inside double quotes;
   - an `export` inside a `( … )` subshell is credited to later commands;
   - heredoc bodies are analysed as commands (the existing self-reference hazard).

   Worth closing the `pgrep | kill` shape?
5. **Over-deny class, deliberate:** a `pkill -f` pattern that is a substring of a racket
   command line (`server`, `make`, `tools/`) is refused, because it would hit the LSP server or
   a `raco make`. Acceptable?
6. Prune `settings.local.json`'s allow rules for unlimited compiles (`:29` `Bash(raco make:*)`,
   `:144-152`) and `:13` `Bash(racket:*)`? A registered hook overrides them anyway (§3 evidence).
7. `measure-production-n.rkt:91`: apply the latent fix (`make-hash`) without a test?
8. DEFERRED 162 open (1), the refuted comment at `run-affected-tests.rkt:710-713`, is in the
   reserved file and was left for its owner.
