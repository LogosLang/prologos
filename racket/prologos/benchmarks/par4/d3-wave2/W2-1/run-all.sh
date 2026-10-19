#!/bin/bash
# W2-1: run gran-probe.rkt over the 19 comparative files, ONE file per process, sequentially.
# usage: bash run-all.sh <timing-reps>
set -u
cd /Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-1
C=/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/comparative
R="/Applications/Racket v9.3/bin/racket"
REPS=${1:-5}
mkdir -p out
echo "start $(date) | $(uptime)" > out/run-all.log
for p in "$C"/*.prologos; do
  b=$(basename "$p" .prologos)
  s=$(date +%s)
  timeout -k 10 150 "$R" gran-probe.rkt "$p" "out/$b.json" "$REPS" >> out/run-all.log 2>&1
  echo "exit $? $b $(( $(date +%s) - s ))s" >> out/run-all.log
done
echo "end $(date) | $(uptime)" >> out/run-all.log
