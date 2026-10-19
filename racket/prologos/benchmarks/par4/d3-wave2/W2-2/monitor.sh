#!/bin/bash
# W2-2 equivalence monitor: every eligible slow-path write compares keyed vs full diff (W22_KEYED_MONITOR=full).
# usage: monitor.sh OUTFILE EXTRA_ENV...   (one .prologos file per process; all 19 comparative files)
S=/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-2
C=$S/tree/racket/prologos/benchmarks/comparative
R="/Applications/Racket v9.3/bin/racket"
OUT=$1; shift
: > $OUT
cd $S
for f in $C/*.prologos; do
  b=$(basename $f)
  env W22_KEYED_DIFF=1 W22_KEYED_MONITOR=full W22_MONITOR_OUT=$OUT W22_FILE=$b "$@" \
    timeout -k 10 120 "$R" w22-time.rkt mon 1 $f > $OUT.$b.t 2>&1 || echo "FAIL $b" >> $OUT
done
