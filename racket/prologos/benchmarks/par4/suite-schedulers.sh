#!/usr/bin/env bash
# suite-schedulers.sh — PAR 4 P0 semantic axis IN THE LARGE: the full test suite under each
# scheduler. A test that passes under BSP and fails under DIRECT-K=1 (seq) or a random
# schedule (seq-shuffle) is a schedule-dependent S0 computation — an A-1/A-3 violation
# (non-monotone propagator or absence read) or a fuel/round-count dependence (S-6).
#   benchmarks/par4/suite-schedulers.sh OUTDIR
# Runs sequentially (never two suites at once). --no-record keeps timings.jsonl clean;
# failure logs are copied per mode before the next run overwrites them.
set -u
OUT="$1"; mkdir -p "$OUT"
HERE="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$HERE"
# The PROLOGOS_SCHEDULER knob was removed by owner decision O-10 (CP-2, 2026-10-14). Without it every mode
# would silently run BSP, so refuse; run this at the record's pinned commit (4097b1c8).
grep -q 'getenv "PROLOGOS_SCHEDULER"' propagator.rkt || {
  echo "suite-schedulers.sh: this tree has no PROLOGOS_SCHEDULER knob (removed by O-10, CP-2); run it at 4097b1c8" >&2; exit 2; }
R="/Applications/Racket v9.3/bin/racket"
run() {  # name, env...
  local name="$1"; shift
  echo "=== $name  ($(date +%H:%M:%S), load $(uptime | sed 's/.*averages: //'))"
  rm -rf data/benchmarks/failures
  env "$@" timeout -k 30 1500 "$R" tools/run-affected-tests.rkt --all --no-record --force-rerun --no-bail > "$OUT/suite-$name.txt" 2>&1
  echo "exit $?"; tail -6 "$OUT/suite-$name.txt"
  [ -d data/benchmarks/failures ] && cp -r data/benchmarks/failures "$OUT/failures-$name" || true
}
run bsp            PROLOGOS_SCHEDULER=bsp
run seq            PROLOGOS_SCHEDULER=seq
run seq-shuffle-1  PROLOGOS_SCHEDULER=seq-shuffle PROLOGOS_SCHED_SEED=1
run seq-shuffle-2  PROLOGOS_SCHEDULER=seq-shuffle PROLOGOS_SCHED_SEED=2
