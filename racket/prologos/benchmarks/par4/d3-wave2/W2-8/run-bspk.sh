#!/bin/bash
# W2-8: BSP-K A/B over targets, one process per target, run while holding the suite lock.
cd /Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-8
for t in micro:grid12 micro:gc500 micro:wave1000 /Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/comparative/constraints-adversarial.prologos /Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/comparative/type-adversarial.prologos /Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/comparative/bool-logic.prologos /Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/comparative/implicit-args.prologos; do
  echo "UPTIME $(uptime)"
  timeout -k 10 180 "/Applications/Racket v9.3/bin/racket" w28-bspk.rkt $t 7 2>&1 | grep '^W28BSPK:'
done
echo "UPTIME $(uptime)"
