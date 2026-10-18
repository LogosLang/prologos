#!/bin/bash
# W2-4 Q2: race census over the medium tier (benchmarks/comparative, 19 files), production executor,
# RACE=1 (chaperoned shared boxes) + PERFCHAP=1 (chaperoned perf counters) during every executor call.
W=/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-4
P=/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos
RKT="/Applications/Racket v9.3/bin/racket"
mkdir -p $W/q2/tier
cd $P
for f in benchmarks/comparative/*.prologos; do
  tag=$(basename $f .prologos)
  RACE=1 PERFCHAP=1 EXEC=${EXEC:-prod} PLT_CS_COMPILE_LIMIT=1000000 timeout -k 10 120 "$RKT" $W/w24-run.rkt $f > $W/q2/tier/$tag.${EXEC:-prod}.out 2>&1
  echo "$tag exit=$? $(grep '^W24' $W/q2/tier/$tag.${EXEC:-prod}.out | cut -c5-)"
done
