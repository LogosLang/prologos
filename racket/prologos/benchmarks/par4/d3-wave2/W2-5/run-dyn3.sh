#!/bin/bash
# W2-5: dyn3.rkt (per-parameter stale attribution) over files; one process per file.
set -u
W=/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-5
RK="/Applications/Racket v9.3/bin/racket"
OUT=$1; shift
mkdir -p "$OUT"
for f in "$@"; do
  b=$(basename "$f" .prologos)
  timeout -k 10 300 "$RK" "$W/dyn3.rkt" "$W/out/census-params.tsv" "$f" > "$OUT/$b.out" 2> "$OUT/$b.err"
  echo "$b exit=$?" >> "$OUT/exit.log"
done
echo ALLDONE >> "$OUT/exit.log"
