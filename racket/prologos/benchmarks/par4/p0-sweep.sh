#!/usr/bin/env bash
# p0-sweep.sh — PAR 4 Pre-0 corpus sweep. ONE racket process per file (bounded heap),
# `timeout -k` so a stuck file cannot outlive the sweep (scratch-run.sh lessons).
#
#   benchmarks/par4/p0-sweep.sh MODE OUT.jsonl [FILES...]
#
# MODE: stats | census | profile (see p0-profile.rkt). FILES default: the comparative
# corpus. Scheduler: export PROLOGOS_SCHEDULER=bsp|seq|seq-shuffle (+ PROLOGOS_SCHED_SEED).
set -u
MODE="$1"; OUT="$2"; shift 2
HERE="$(cd "$(dirname "$0")/../.." && pwd)"          # racket/prologos
RACKET="/Applications/Racket v9.3/bin/racket"
if [ "$#" -eq 0 ]; then set -- "$HERE"/benchmarks/comparative/*.prologos; fi
: > "$OUT"
for f in "$@"; do
  line=$(cd "$HERE" && timeout -k 10 300 "$RACKET" benchmarks/par4/p0-profile.rkt "$MODE" "$f" 2>/dev/null | grep '^P0:' | head -1)
  if [ -n "$line" ]; then echo "${line#P0:}" >> "$OUT"
  else echo "{\"file\":\"$f\",\"mode\":\"$MODE\",\"error\":\"no output (exit or timeout)\"}" >> "$OUT"; fi
  printf '.' >&2
done
echo " done: $(wc -l < "$OUT") lines → $OUT" >&2
