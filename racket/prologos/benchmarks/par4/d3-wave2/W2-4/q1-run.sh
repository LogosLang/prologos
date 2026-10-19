#!/bin/bash
# W2-4 Q1: DFS-against-ATMS answer differential. One .prologos per process, three legs per program:
#   auto (production: no override, :strategy auto unless the program names a solver), dfs (forced), atms (forced).
# Production executor (EXEC=prod). Outputs: q1/<tag>.<leg>.out
W=/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-4
P=/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos
RKT="/Applications/Racket v9.3/bin/racket"
mkdir -p $W/q1
cd $P
FILES="
benchmarks/par4/d3-wave1/C9/c1-overwrite.prologos
benchmarks/par4/d3-wave1/C9/c4-varvar.prologos
examples/relational-demo.prologos
examples/2026-04-08-bsp-le-track2.prologos
examples/2026-07-19-rel-t1-acceptance.prologos
examples/2026-03-14-wfle-acceptance.prologos
examples/2026-03-19-punify-acceptance.prologos
examples/2026-03-20-punify-p3-acceptance.prologos
examples/2026-03-18-track7-acceptance.prologos
examples/2026-03-16-track5-acceptance.prologos
examples/2026-03-16-track6-acceptance.prologos
examples/2026-07-31-solve-carrier.prologos
examples/2026-05-08-propagator-demo.prologos
examples/dependency-demo/dependency-resolver.prologos
examples/2026-07-06-ciu-t6-f1-records.prologos
examples/2026-03-28-sudoku-demo.prologos
lib/examples/foray.prologos
benchmarks/comparative/atms-adversarial.prologos
benchmarks/comparative/solve-adversarial.prologos
benchmarks/comparative/parity-adversarial.prologos
"
for f in $FILES; do
  tag=$(basename $f .prologos)
  for leg in auto dfs atms; do
    STRAT=$leg ROUTES=1 PLT_CS_COMPILE_LIMIT=1000000 timeout -k 10 120 "$RKT" $W/w24-run.rkt $f > $W/q1/$tag.$leg.out 2>&1
    echo "$tag $leg exit=$? $(grep -c -E '^[0-9]+:' $W/q1/$tag.$leg.out) lines"
  done
done
