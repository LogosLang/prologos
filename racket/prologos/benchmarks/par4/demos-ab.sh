#!/usr/bin/env bash
# demos-ab.sh — PAR 4 P0 §10: the medium tier, interleaved, on limited builds.
#   benchmarks/par4/demos-ab.sh PRETRACK_TREE ROUNDS OUTDIR
# Legs per round, in order: pretrack (its own bench-parallel-demos.rkt) · this tree threshold 256 ·
# this tree threshold off. Each leg's full stdout goes to OUTDIR/<round>-<leg>.txt. The tracked
# data/benchmarks/parallel-demo-results.json is restored in BOTH trees after every leg (DEFERRED 155).
set -u
PRE="$1"; ROUNDS="${2:-2}"; mkdir -p "$3"; OUT="$(cd "$3" && pwd)"
HERE="$(cd "$(dirname "$0")/../.." && pwd)"          # racket/prologos of this tree
R="/Applications/Racket v9.3/bin/racket"
mkdir -p "$OUT"
restore() { git -C "$1" checkout -q -- data/benchmarks/parallel-demo-results.json 2>/dev/null || true; }
for r in $(seq 1 "$ROUNDS"); do
  echo "== round $r  $(uptime | sed 's/.*load/load/')" | tee -a "$OUT/loads.txt"
  (cd "$PRE/racket/prologos" && timeout -k 10 300 "$R" benchmarks/micro/bench-parallel-demos.rkt > "$OUT/$r-pretrack.txt" 2>&1); restore "$PRE/racket/prologos"
  (cd "$HERE" && timeout -k 10 300 "$R" benchmarks/par4/demos-threshold.rkt 256 > "$OUT/$r-b1-256.txt" 2>&1); restore "$HERE"
  (cd "$HERE" && timeout -k 10 300 "$R" benchmarks/par4/demos-threshold.rkt off > "$OUT/$r-b1-off.txt" 2>&1); restore "$HERE"
done
echo done
