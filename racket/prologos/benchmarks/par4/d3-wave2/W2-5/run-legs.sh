#!/bin/bash
# W2-5: run dyn.rkt legs over a file list, one process per (file, leg); summarise vs seq.
# usage: run-legs.sh <outdir> <legs...> -- <files...>
set -u
W=/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-5
RK="/Applications/Racket v9.3/bin/racket"
OUT=$1; shift
LEGS=()
while [ "$1" != "--" ]; do LEGS+=("$1"); shift; done
shift
mkdir -p "$OUT"
for f in "$@"; do
  b=$(basename "$f" .prologos)
  for leg in "${LEGS[@]}"; do
    timeout -k 10 300 "$RK" "$W/dyn.rkt" "$W/out/census-params.tsv" "$leg" "$f" > "$OUT/$b.$leg.out" 2> "$OUT/$b.$leg.err"
    echo "$b $leg exit=$?" >> "$OUT/exit.log"
  done
done
