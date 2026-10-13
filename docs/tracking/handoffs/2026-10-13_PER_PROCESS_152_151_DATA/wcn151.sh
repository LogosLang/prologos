#!/bin/bash
# wcn151.sh <root> <out.jsonl> <rounds> — warm vs no-cache vs cold(write) load phase, interleaved.
# cold = rm data/cache/pnet, then the SAME command that generated the cache (run152 test-transducer-01),
# so the warm legs afterwards read a cache regenerated the same way every round.
set -u
R=$1; OUT=$2; ROUNDS=$3
H=$(cd "$(dirname "$0")" && pwd)
RK="/Applications/Racket v9.3/bin/racket"
one() { # label env-prefix test
  local load; load=$(uptime | sed -E 's/.*load averages?: ([0-9.]+).*/\1/')
  local line; line=$(env $2 timeout -k 10 300 "$RK" "$H/run152.rkt" "$R" "$3" "$1" 2>/dev/null | grep '^RESULT ')
  echo "{\"leg\":\"$1\",\"load1\":$load,\"r\":${line#RESULT $1 }}" >> "$OUT"
  echo "$1 load=$load ${line:0:150}"
}
for r in $(seq 1 "$ROUNDS"); do
  one warm "X=1" -
  one nocache "PNET=off" -
  rm -rf "$R/data/cache/pnet"
  one cold "X=1" test-transducer-01.rkt
  one warm "X=1" -
done
