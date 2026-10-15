#!/usr/bin/env bash
# p0-sweep.sh — PAR 4 Pre-0 corpus sweep. ONE racket process per file (bounded heap),
# `timeout -k` so a stuck file cannot outlive the sweep (scratch-run.sh lessons).
#
#   benchmarks/par4/p0-sweep.sh MODE OUT.jsonl [FILES...]
#
# MODE: stats | census | profile (see p0-profile.rkt). FILES default: the comparative
# corpus. Scheduler: BSP. (P0 chose it with PROLOGOS_SCHEDULER, removed by owner decision O-10, CP-2;
# a seq/seq-shuffle sweep runs at 4097b1c8.)
set -u
MODE="$1"; OUT="$2"; shift 2
HERE="$(cd "$(dirname "$0")/../.." && pwd)"          # racket/prologos
if [ -n "${PROLOGOS_SCHEDULER:-}" ] && ! grep -q 'getenv "PROLOGOS_SCHEDULER"' "$HERE/propagator.rkt"; then
  echo "p0-sweep.sh: PROLOGOS_SCHEDULER is set but this tree has no such knob (O-10, CP-2); run at 4097b1c8" >&2; exit 2; fi
if [ -n "${PROLOGOS_SOLVER_STRATEGY:-}" ] && ! grep -q 'getenv "PROLOGOS_SOLVER_STRATEGY"' "$HERE/stratified-eval.rkt"; then
  echo "p0-sweep.sh: PROLOGOS_SOLVER_STRATEGY is set but this tree has no such knob (O-10, CP-2); run at 4097b1c8" >&2; exit 2; fi
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
