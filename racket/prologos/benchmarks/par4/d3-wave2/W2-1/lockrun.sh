#!/bin/bash
# W2-1: heavy files, interleaved A B A B, run INSIDE the suite lock (hold-suite-lock.rkt runs this script).
cd /Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-1
C=/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/comparative
R="/Applications/Racket v9.3/bin/racket"
mkdir -p locked
echo "locked start $(date) | $(uptime)"
for i in 1 2 3; do
  for b in constraints-adversarial type-adversarial; do
    timeout -k 10 150 "$R" gran-probe.rkt "$C/$b.prologos" "locked/$b.$i.json" 7 2>&1 | tail -1
  done
done
echo "locked end $(date) | $(uptime)"
