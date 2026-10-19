#!/bin/bash
# W2-4 Q4: race + perf-counter census over every .prologos under examples/, lib/examples/ and
# benchmarks/comparative/ (one process per file; production executor; RACE=1 PERFCHAP=1 instrument).
W=/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-4
P=/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos
RKT="/Applications/Racket v9.3/bin/racket"
mkdir -p $W/q2/all
cd $P
for f in $(find examples lib/examples benchmarks/comparative -name '*.prologos' | sort); do
  tag=$(echo $f | tr '/' '_' | sed 's/\.prologos$//')
  RACE=1 PERFCHAP=1 PLT_CS_COMPILE_LIMIT=1000000 timeout -k 10 ${TMO:-90} "$RKT" $W/w24-run.rkt $f > $W/q2/all/$tag.out 2>&1
  ec=$?
  js=$(grep '^W24' $W/q2/all/$tag.out | cut -c5-)
  echo "$ec $f $js"
done
