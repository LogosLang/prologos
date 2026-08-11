#!/usr/bin/env bash
#
# scratch-run.sh — THE sanctioned way to run one .prologos file outside the
# test suite (probes, A/B legs, adversarial-verify harnesses).
#
# WHY THIS EXISTS. On 2026-08-08 three orphaned Racket processes were found
# holding ~14 GB between them, one at 12.6 GB, at 76-80% CPU, still running
# 45-75 minutes after the workflow that spawned them had finished and reported.
# They were `PPID 1` — nothing would ever reap them. Root cause was not a leak:
# each was a hand-rolled harness looping a 49-file corpus inside ONE Racket
# process, so peak heap scaled with corpus size. The three enabling mistakes,
# all of which this script removes BY CONSTRUCTION rather than by asking:
#
#   1. ONE PROCESS, MANY FILES. This script accepts EXACTLY ONE file and
#      refuses two. A corpus sweep is therefore forced to be a SHELL loop,
#      which means one process per file, which bounds peak memory at one
#      file's working set. You cannot express the 49-files-one-heap shape
#      with this tool — that is the point, and it is why the arity check is
#      an error rather than a warning.
#      ⚠ THE GATE BELONGS HERE BECAUSE run-file.rkt CANNOT HOLD IT. That tool
#      takes `#:args files files` and does `(for ([f (in-list files)])
#      (run-print f))` — N files in ONE process, exactly the dangerous shape.
#      So the hazard is not something an agent invented; it is reachable, and
#      idiomatic-looking, straight from the repo's own runner. Changing
#      run-file.rkt's arity would break the acceptance harness that passes it
#      a list, so the bound is enforced at the layer that can afford it.
#
#   2. `timeout N` WITHOUT `-k`. Measured that day: a `timeout 550` wrapper
#      was still alive at 1h18m, and the child ignored SIGTERM outright — a
#      manual `kill -TERM` on all three did nothing and SIGKILL was required.
#      Racket CS in a tight allocation/GC loop does not service SIGTERM. So
#      every run here gets `timeout -k`, with a SIGKILL follow-up.
#
#   3. ORPHANING. The child ran in the caller's process group, so when the
#      agent's shell went away the child was reparented to init and survived.
#      Here the child is put in its OWN process group and an EXIT trap kills
#      that whole group, so an interrupt or a dying parent takes the compiler
#      down with it.
#
# Usage:
#   tools/scratch-run.sh [-t SECONDS] [-c] FILE.prologos
#     -t  wall limit (default 120). SIGTERM, then SIGKILL 10s later.
#     -c  pass --check to run-file.rkt (verify ;;N=> markers instead of printing)
#
# Corpus sweep — the ONLY supported shape, one process per file:
#   for f in corpus/*.prologos; do tools/scratch-run.sh -t 60 "$f"; done
#
set -euo pipefail

TIMEOUT=120
CHECK=0
while getopts ":t:c" opt; do
  case "$opt" in
    t) TIMEOUT="$OPTARG" ;;
    c) CHECK=1 ;;
    \?) echo "scratch-run.sh: unknown flag -$OPTARG" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

# ── (1) THE ARITY GATE — the structural guarantee. Do not "improve" this into
# a loop; a loop here re-creates the exact 12.6 GB single-heap shape it exists
# to make unrepresentable.
if [ "$#" -eq 0 ]; then
  echo "scratch-run.sh: need exactly one .prologos file" >&2
  exit 2
fi
if [ "$#" -gt 1 ]; then
  cat >&2 <<'EOF'
scratch-run.sh: REFUSING a multi-file run — this takes exactly ONE file.

Running N files in one Racket process is what produced a 12.6 GB orphan on
2026-08-08: every process-file accumulates module networks, registries and
.pnet caches in the SAME heap, so peak memory scales with N.

Sweep with a shell loop instead — one process per file, bounded memory:

    for f in corpus/*.prologos; do tools/scratch-run.sh -t 60 "$f"; done
EOF
  exit 2
fi

FILE="$1"
[ -f "$FILE" ] || { echo "scratch-run.sh: no such file: $FILE" >&2; exit 2; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RACKET="${PROLOGOS_RACKET:-/Applications/Racket v9.0/bin/racket}"
[ -x "$RACKET" ] || { echo "scratch-run.sh: racket not executable at: $RACKET" >&2; exit 2; }

# The giant-match modules fall back to the CS INTERPRETER without this
# (~830x slower shift/subst) — see CLAUDE.local.md § Compile limit.
export PLT_CS_COMPILE_LIMIT="${PLT_CS_COMPILE_LIMIT:-1000000}"

# ── (3) OWN PROCESS GROUP + EXIT TRAP, so nothing outlives this shell.
#
# ⚠ `setsid` DOES NOT EXIST ON macOS. The first draft of this script branched on
# it and fell through to launching the child in the CALLER's process group — so
# the cleanup below signalled our own group and killed the caller. Caught by the
# script's own smoke test (exit 144, no output). `set -m` (job control) is the
# portable way to get a background job its own process group, and it works in a
# non-interactive shell.
set -m

OWN_PGID="$(ps -o pgid= -p $$ | tr -d ' ')"
CHILD_PGID=""
cleanup() {
  # Kill the GROUP only when we are certain it is not ours — if `set -m` were
  # ever a no-op, a group kill here would take the caller down with it. When
  # the pgid is not distinct, fall back to the single pid.
  if [ -n "$CHILD_PGID" ] && [ "$CHILD_PGID" != "$OWN_PGID" ]; then
    kill -TERM -- "-$CHILD_PGID" 2>/dev/null || true
    sleep 2
    # SIGTERM is NOT sufficient — measured. Always follow with SIGKILL.
    kill -KILL -- "-$CHILD_PGID" 2>/dev/null || true
  elif [ -n "${CHILD_PID:-}" ]; then
    kill -TERM "$CHILD_PID" 2>/dev/null || true
    sleep 2
    kill -KILL "$CHILD_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM HUP

RUNNER="$REPO/racket/prologos/tools/run-file.rkt"
[ -f "$RUNNER" ] || { echo "scratch-run.sh: missing $RUNNER" >&2; exit 2; }

ARGS=()
[ "$CHECK" -eq 1 ] && ARGS+=(--check)
# ⚠ bash 3.2 (what macOS ships, and what this script runs under) treats
# "${ARGS[@]}" on an EMPTY array as an unbound-variable error under `set -u`,
# so the DEFAULT invocation — no `-c`, hence an empty ARGS — aborted before the
# child ever launched: `scratch-run.sh: line 136: ARGS[@]: unbound variable`.
# Only the `-c` path had a non-empty array, which is why the break survived:
# the one flag that was exercised was the one that masked it.
# `${ARGS[@]+"${ARGS[@]}"}` expands to nothing when unset and to the quoted
# elements otherwise — the portable bash-3.2 idiom. Do NOT "simplify" it back.
# Found 2026-08-11 at D4.P4e-1b: FIVE independent data points in one session —
# three grounding-audit facets, the completeness critic, and the main thread —
# and three of those hand-rolled a bypass rather than report it, which is the
# precise antecedent of the 2026-08-08 orphaned-harness incident this script
# exists to prevent. A broken sanctioned path does not stop probes; it makes
# them unsafe.

# ── (2) timeout WITH -k. Prefer coreutils `gtimeout` when present (macOS ships
# no `timeout` of its own); either accepts -k.
TIMEOUT_BIN="$(command -v gtimeout || command -v timeout || true)"
if [ -z "$TIMEOUT_BIN" ]; then
  echo "scratch-run.sh: no timeout/gtimeout on PATH — refusing to run unbounded" >&2
  exit 2
fi
"$TIMEOUT_BIN" -k 10 "$TIMEOUT" "$RACKET" "$RUNNER" ${ARGS[@]+"${ARGS[@]}"} "$FILE" &
CHILD_PID=$!
CHILD_PGID="$(ps -o pgid= -p "$CHILD_PID" 2>/dev/null | tr -d ' ' || echo "$CHILD_PID")"

set +e
wait "$CHILD_PID"
STATUS=$?
set -e

if [ "$STATUS" -eq 124 ] || [ "$STATUS" -eq 137 ]; then
  echo "scratch-run.sh: TIMEOUT after ${TIMEOUT}s (killed) — $FILE" >&2
fi
exit "$STATUS"
