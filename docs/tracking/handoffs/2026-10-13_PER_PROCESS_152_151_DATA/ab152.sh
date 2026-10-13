#!/bin/bash
# ab152.sh — ABBA in-process A/B of the test phase (DEFERRED 152) and/or load phase (151a).
# usage: ab152.sh <out.jsonl> <rounds> <legA-name>=<root> <legB-name>=<root> <test>...
# Each round runs A B B A per test file; every line carries the 1-min load average.
set -u
OUT=$1; ROUNDS=$2; A=$3; B=$4; shift 4
AN=${A%%=*}; AR=${A#*=}; BN=${B%%=*}; BR=${B#*=}
H=$(cd "$(dirname "$0")" && pwd)
RK="/Applications/Racket v9.3/bin/racket"
run() { # name root test
  local load; load=$(uptime | sed -E 's/.*load averages?: ([0-9.]+).*/\1/')
  local line; line=$(timeout -k 10 300 "$RK" "$H/run152.rkt" "$2" "$3" "$1" 2>/dev/null | grep '^RESULT ')
  echo "{\"leg\":\"$1\",\"load1\":$load,\"r\":${line#RESULT $1 }}" >> "$OUT"
  echo "$1 $3 load=$load $(echo "${line}" | cut -c1-200)"
}
for r in $(seq 1 "$ROUNDS"); do
  for t in "$@"; do
    run "$AN" "$AR" "$t"; run "$BN" "$BR" "$t"; run "$BN" "$BR" "$t"; run "$AN" "$AR" "$t"
  done
done
