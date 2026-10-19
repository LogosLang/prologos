#!/bin/bash
# W2-5: dyn2.rkt (per-fire thread differential) over files; one process per (file, leg).
set -u
W=/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-5
RK="/Applications/Racket v9.3/bin/racket"
OUT=$1; shift
mkdir -p "$OUT"
for f in "$@"; do
  b=$(basename "$f" .prologos)
  for leg in fresh persist persistcap; do
    timeout -k 10 300 "$RK" "$W/dyn2.rkt" "$leg" "$f" > "$OUT/$b.$leg.out" 2> "$OUT/$b.$leg.err"
    echo "$b $leg exit=$?" >> "$OUT/exit.log"
  done
done
echo ALLDONE >> "$OUT/exit.log"
