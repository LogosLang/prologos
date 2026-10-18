#!/bin/bash
cd /Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-8
for t in micro:grid12i micro:grid20i /Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/comparative/constraints-adversarial.prologos /Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/comparative/type-adversarial.prologos; do
  echo "UPTIME $(uptime)"
  timeout -k 10 170 "/Applications/Racket v9.3/bin/racket" w28-bspk.rkt $t 5 2>&1 | grep '^W28BSPK:'
done
echo "UPTIME $(uptime)"
