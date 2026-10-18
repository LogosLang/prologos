#!/usr/bin/env bash
# o10-instrument-cost.sh — PAR 4 O-10 evidence: what does the P0/O-9 instrumentation cost when its env vars are
# UNSET? Main's propagator.rkt / stratified-eval.rkt differ from this branch's ONLY by that instrumentation, so the
# medium tier (bench-parallel-demos, tree-reduce threshold OFF in both legs so DEFERRED 150 does not mask it) is
# run interleaved in a main worktree and in this tree.
#   benchmarks/par4/o10-instrument-cost.sh MAIN_TREE ROUNDS OUTDIR
# Run holding the suite lock exclusively (benchmarks/par4/hold-suite-lock.rkt).
set -u
MAIN="$1"; ROUNDS="${2:-5}"; mkdir -p "$3"; OUT="$(cd "$3" && pwd)"
HERE="$(cd "$(dirname "$0")/../.." && pwd)"
R="/Applications/Racket v9.3/bin/racket"
for r in $(seq 1 "$ROUNDS"); do
  echo "== round $r  $(uptime | sed 's/.*load/load/')" | tee -a "$OUT/loads.txt"
  (cd "$MAIN/racket/prologos" && env -u PROLOGOS_SCHEDULER -u PAR4_TREE_REDUCE -u PAR4_MERGE_ORDER_CENSUS \
     timeout -k 10 300 "$R" benchmarks/par4/demos-threshold.rkt off > "$OUT/$r-main.txt" 2>&1)
  (cd "$HERE" && env -u PROLOGOS_SCHEDULER -u PAR4_TREE_REDUCE -u PAR4_MERGE_ORDER_CENSUS \
     timeout -k 10 300 "$R" benchmarks/par4/demos-threshold.rkt off > "$OUT/$r-branch.txt" 2>&1)
done
echo done
