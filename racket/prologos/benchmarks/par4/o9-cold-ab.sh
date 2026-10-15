#!/usr/bin/env bash
# o9-cold-ab.sh — PAR 4 O-9 evidence: cold-cache prelude elaboration (every imported module elaborated from
# SOURCE, P0_NO_PNET=1) on a near-empty file, threshold 256 (as shipped) vs off, INTERLEAVED.
#   benchmarks/par4/o9-cold-ab.sh ROUNDS OUTFILE
# Run it holding the machine-wide suite lock exclusively, so no suite starts mid-measurement:
#   racket benchmarks/par4/hold-suite-lock.rkt tools/suite-lock.rkt bash benchmarks/par4/o9-cold-ab.sh 7 data/par4-p0/o9/cold-ab.jsonl
# One JSON line per leg: the p0-profile stats fields that matter here (wall, bytes, GC, BSP rounds/fires/
# widest round, merge/fire ms) plus the whole process's user+sys CPU from /usr/bin/time, and the load average.
set -u
ROUNDS="${1:-7}"; OUT="$2"
HERE="$(cd "$(dirname "$0")/../.." && pwd)"            # racket/prologos of this tree
R="/Applications/Racket v9.3/bin/racket"
cd "$HERE"
# The PAR4_TREE_REDUCE knob was removed by owner decision O-10 (CP-2); without it the "off" leg would silently
# equal the 256 leg, so refuse. Run at eb25caee (or 8278a66d), where the knob exists.
grep -q 'getenv "PAR4_TREE_REDUCE"' propagator.rkt || {
  echo "o9-cold-ab.sh: this tree has no PAR4_TREE_REDUCE knob (removed by O-10, CP-2); run it at eb25caee" >&2; exit 2; }
for r in $(seq 1 "$ROUNDS"); do
  for leg in 256 off; do
    if [ "$leg" = off ]; then E="PAR4_TREE_REDUCE=off"; else E="PAR4_NOOP=1"; fi
    T="$(mktemp)"
    LINE="$( { /usr/bin/time -p bash -c 'exec 2>/dev/null; exec "$@"' _ env $E P0_NO_PNET=1 timeout -k 10 120 "$R" benchmarks/par4/p0-profile.rkt stats benchmarks/par4/preload-empty.prologos | grep '^P0:' ; } 2>"$T" )"
    CPU="$(awk '/^user/{u=$2} /^sys/{s=$2} END{printf "%.3f", u+s}' "$T")"; rm -f "$T"
    LOAD="$(uptime | sed 's/.*averages*: *//; s/,//g' | awk '{print $1}')"
    printf '%s\n' "$LINE" | python3 -c '
import sys, json
d = json.loads(sys.stdin.read()[3:])
keep = ["total_ms","total_mb","gc_ms","bsp_rounds","bsp_fires","width_max","bsp_merge_ms","bsp_fire_ms"]
o = {"round": int(sys.argv[1]), "leg": sys.argv[2], "cpu_s": float(sys.argv[3]), "load1": float(sys.argv[4])}
o.update({k: d[k] for k in keep if k in d})
print(json.dumps(o))' "$r" "$leg" "$CPU" "$LOAD" | tee -a "$OUT"
  done
done
