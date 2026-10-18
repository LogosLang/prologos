#!/bin/bash
# W2-10: diagnostics/results A/B/C over executor legs (prod thread executor, sequential, drain), one process per run.
cd /Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-10
B=/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/comparative
mkdir -p ab
uptime > ab/uptime.txt
for f in constraints-adversarial type-adversarial atms-adversarial solve-adversarial scheduler-adversarial parity-adversarial dependent-types implicit-args; do
  for leg in prod seq drain; do
    PLT_CS_COMPILE_LIMIT=1000000 timeout -k 10 90 "/Applications/Racket v9.3/bin/racket" run-leg.rkt $B/$f.prologos $leg eval \
      2>&1 | grep -v "^PERF\|^PHASE\|^PROVEN\|^CELL-M" > ab/$f.$leg.out
    echo "$f $leg exit=${PIPESTATUS[0]} $(tail -1 ab/$f.$leg.out)"
  done
done
uptime >> ab/uptime.txt
