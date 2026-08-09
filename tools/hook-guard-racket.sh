#!/usr/bin/env bash
#
# hook-guard-racket.sh — PreToolUse/Bash guard: refuse to run the Racket binary
# without a wall-clock bound.
#
# THE LAST LAYER. `tools/scratch-run.sh` makes the runaway shape unrepresentable
# for anyone who uses it; this makes NOT using it impossible. It is enforced by
# the harness rather than by the model, which is the point — the 2026-08-08
# incident (three orphaned harnesses, ~14 GB, one at 12.6 GB, still running 45-75
# minutes after their workflow finished) was caused by SUBAGENTS, and a subagent
# cannot be relied on to have read a rule. A PreToolUse hook applies to their
# Bash calls too.
#
# Reads the hook payload on stdin, decides, and prints a PreToolUse decision.
# Silence (exit 0, no output) = allow.
#
# DENIES: a command that invokes the racket binary with no timeout/gtimeout -k.
# ALLOWS:
#   · anything not invoking racket at all (including `raco`, which is bounded
#     compilation — and whose path contains no "/racket" token anyway)
#   · tools/scratch-run.sh                (bounds it itself)
#   · run-affected-tests.rkt, bench-ab.rkt (own their workers and timeouts)
#   · any command already wrapped in `timeout -k` / `gtimeout -k`
#
# ⚠ `timeout` WITHOUT `-k` IS NOT ACCEPTED, deliberately. The orphan that
# started all this carried `timeout 550` and was alive at 1h18m: bare timeout
# sends SIGTERM, and Racket CS in a tight allocation/GC loop never services it.
# Accepting bare `timeout` would re-open the exact hole this closes.
#
set -uo pipefail

payload="$(cat)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0

deny() {
  jq -nc --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

# ── Is the racket BINARY invoked? Two forms, both anchored so that merely
# mentioning the word (grep racket, echo racket, a path in a comment) is not a
# match:
#   (a) a path ending in /racket        — "/Applications/Racket v9.0/bin/racket"
#   (b) the bare word `racket` at COMMAND position: start of line/string, or
#       after ; && || | ( or a newline, with optional VAR=... env prefixes.
#   (c) the bare word `racket` after an EXECUTOR that runs its argument
#       (`timeout 900 racket …`, `env FOO=1 racket …`, `nohup racket …`).
#       ⚠ (c) IS NOT OPTIONAL: without it `timeout 900 racket foo.rkt` — the
#       orphan's own shape, minus the absolute path — reads as neither a
#       /racket path nor a command-position bare word, and sails through. Caught
#       by the decision table, which is why that table exists.
#
# ⚠ STRIP-THEN-DECIDE, not allowlist-then-decide. `racket --version|--help|-h`
# prints and exits, so it cannot hang and needs no bound. But expressing that as
# "allow if the command contains --version" is a BYPASS: `racket --version &&
# racket foo.rkt` would sail through on the harmless half. Caught by the decision
# table the moment the row was added. So remove the harmless invocations from a
# WORKING COPY and decide on whatever invocation remains.
scan="$(sed -E 's/racket["'\'']?[[:space:]]+(--version|--help|-h)([[:space:]]|$)/ /g' <<<"$cmd")"

invokes_racket=0
grep -Eq '/racket("|'\''|[[:space:]]|$)' <<<"$scan" && invokes_racket=1
grep -Eq '(^|[;&|(]|&&|\|\|)[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*racket([[:space:]]|$)' <<<"$scan" && invokes_racket=1
grep -Eq '\b(g?timeout|env|nice|nohup|time|setsid|sudo|xargs|exec)\b[^;&|]*\bracket\b' <<<"$scan" && invokes_racket=1
[ "$invokes_racket" -eq 0 ] && exit 0

# ── Allowlist: runners that own their own bounds.
grep -q 'scratch-run\.sh'          <<<"$cmd" && exit 0
grep -q 'run-affected-tests\.rkt'  <<<"$cmd" && exit 0
grep -q 'bench-ab\.rkt'            <<<"$cmd" && exit 0

# ── Already bounded WITH a SIGKILL follow-up?
grep -Eq '\bg?timeout[[:space:]]+((-k|--kill-after)([[:space:]]|=))' <<<"$cmd" && exit 0
# `timeout 60 -k 10` ordering, and long-form after the duration
grep -Eq '\bg?timeout[[:space:]]+[^|;&]*((-k[[:space:]])|(--kill-after))' <<<"$cmd" && exit 0

if grep -Eq '\bg?timeout\b' <<<"$cmd"; then
  deny "Bounded with \`timeout\` but no \`-k\`, which is not a limit.

MEASURED 2026-08-08: an orphan carrying \`timeout 550\` was still alive at 1h18m,
and \`kill -TERM\` on it did nothing — Racket CS in a tight allocation/GC loop
does not service SIGTERM. Only the SIGKILL follow-up stops it.

Add the kill-after:   timeout -k 30 <seconds> <command>
Or use the wrapper:   tools/scratch-run.sh [-t SECONDS] ONE-FILE.prologos"
fi

deny "Refusing to run the Racket binary unbounded.

On 2026-08-08 three hand-rolled harnesses were left orphaned at PPID 1 holding
~14 GB (one at 12.6 GB) at 76-80% CPU, still running 45-75 minutes after the
workflow that spawned them had finished. Root cause was not a leak: they looped
a 49-file corpus inside ONE Racket process, so peak heap scaled with corpus size.

Use the sanctioned runner — it takes ONE file, applies \`timeout -k\`, and puts
the child in its own process group so nothing outlives the shell:

    tools/scratch-run.sh [-t SECONDS] ONE-FILE.prologos

Sweep a corpus with a SHELL loop (one process per file, bounded memory):

    for f in corpus/*.prologos; do tools/scratch-run.sh -t 60 \"\$f\"; done

Running the test suite? Use the runner that owns its own workers and timeouts:

    racket tools/run-affected-tests.rkt --tests tests/test-X.rkt

Anything else that must call racket directly needs an explicit bound:

    timeout -k 30 300 \"/Applications/Racket v9.0/bin/racket\" ...

See .claude/rules/testing.md § \"Running the compiler OUTSIDE the suite\"."
