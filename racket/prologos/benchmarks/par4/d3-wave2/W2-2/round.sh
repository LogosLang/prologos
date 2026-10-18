#!/bin/bash
# W2-2: one interleaved round = the four legs, order rotated by round number. Run under the suite lock.
# usage: round.sh ROUND OUTDIR
S=/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-2
C=$S/tree/racket/prologos/benchmarks/comparative
R="/Applications/Racket v9.3/bin/racket"
r=$1; OUT=$2
FILES=$(ls $C/*.prologos | grep -v parity-adversarial)   # DEFERRED 153: crashes at HEAD (uncaught DFS depth limit)
LEGS=(${LEGSET:-A B C D})
NL=${#LEGS[@]}
cd $S
for (( i=0; i<NL; i++ )); do
  leg=${LEGS[$(( (i + r) % NL ))]}
  case $leg in
    A) E="W22_NONE=1";;
    B) E="W22_EXEC_OFF=1";;
    C) E="W22_KEYED_DIFF=1";;
    D) E="W22_EXEC_OFF=1 W22_KEYED_DIFF=1";;
    E) E="W22_EXEC_OFF=1 W22_KEYED_DIFF=1 W22_DELTA_WRITES=1";;
    P) E="W22_KEYED_DIFF=1 W22_KEYED_POWER=1";;
  esac
  echo "# round $r leg $leg $(date +%H:%M:%S) $(uptime | sed 's/.*load averages*: //')" >> $OUT/schedule.txt
  env $E timeout -k 10 300 "$R" w22-time.rkt $leg ${REPS:-5} $FILES >> $OUT/legs.jsonl 2>> $OUT/stderr.txt \
    || echo "FAIL round $r leg $leg" >> $OUT/schedule.txt
done
