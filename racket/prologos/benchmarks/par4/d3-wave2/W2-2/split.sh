#!/bin/bash
# W2-2 Q4: single-instrument split (main-thread sampler), executor OFF in every leg. Run under the suite lock.
S=/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-2
C=$S/tree/racket/prologos/benchmarks/comparative
R="/Applications/Racket v9.3/bin/racket"
OUT=$S/split; mkdir -p $OUT; cd $S
for rep in 1 2; do
for f in constraints-adversarial type-adversarial; do
  for leg in B D E; do
    case $leg in
      B) E="W22_EXEC_OFF=1";;
      D) E="W22_EXEC_OFF=1 W22_KEYED_DIFF=1";;
      E) E="W22_EXEC_OFF=1 W22_KEYED_DIFF=1 W22_DELTA_WRITES=1";;
    esac
    echo "# $rep $f $leg $(date +%H:%M:%S) $(uptime | sed 's/.*load averages*: //')" >> $OUT/schedule.txt
    env $E timeout -k 10 200 "$R" w22-split.rkt $C/$f.prologos 40 | sed "s/^W22SPLIT:/W22SPLIT:$leg:/" >> $OUT/split.jsonl
  done
done
done
