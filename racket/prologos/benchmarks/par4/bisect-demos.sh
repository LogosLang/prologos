#!/usr/bin/env bash
# bisect-demos.sh — git bisect run predicate: is graph-coloring-500 SEQUENTIAL fast (good) or
# slow (bad)? Runs in the detached bisect worktree. Exit 0 good, 1 bad, 125 skip.
# good: median seq < 4.0 ms   bad: > 6.0 ms   in between / compile failure: skip (125)
set -u
cd "$(git rev-parse --show-toplevel)/racket/prologos" || exit 125
R="/Applications/Racket v9.3/bin/racket"
RACO="/Applications/Racket v9.3/bin/raco"
PLT_CS_COMPILE_LIMIT=1000000 timeout -k 10 400 "$RACO" make -j 6 benchmarks/micro/bench-parallel-demos.rkt >/dev/null 2>&1 || exit 125
vals=""
for i in 1 2 3; do
  v=$(timeout -k 10 120 "$R" benchmarks/micro/bench-parallel-demos.rkt 2>/dev/null | awk '/Graph Coloring/{g=1} g && $1=="500"{print $3; exit}')
  [ -z "$v" ] && exit 125
  vals="$vals $v"
done
git checkout -q -- data/benchmarks/parallel-demo-results.json 2>/dev/null
med=$(echo $vals | tr ' ' '\n' | sort -g | sed -n 2p)
echo "$(git rev-parse --short HEAD) seq500 = $vals  median $med" >> /tmp/par4-bisect-trace.txt 2>/dev/null || true
echo "$(git rev-parse --short HEAD) median $med" >&2
awk -v m="$med" 'BEGIN{ if (m < 4.0) exit 0; else if (m > 6.0) exit 1; else exit 125 }'
