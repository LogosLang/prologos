#!/bin/bash
# suite-ab151b.sh <rootA v11> <rootB v12> <rounds> — full suite wall, interleaved ABAB, --no-record.
# Each suite takes the machine-wide lock exclusively itself, so the legs never overlap.
set -u
A=$1; B=$2; N=$3
RK="/Applications/Racket v9.3/bin/racket"
leg() { # tag root
  local load; load=$(uptime | sed -E 's/.*load averages?: ([0-9.]+).*/\1/')
  local line; line=$(cd "$2" && timeout -k 10 580 "$RK" tools/run-affected-tests.rkt --all --force-rerun --no-record 2>&1 | grep -E '^[0-9]+ tests in ')
  echo "$1 load=$load $line"
}
for r in $(seq 1 "$N"); do
  if [ $((r % 2)) -eq 1 ]; then leg v11 "$A"; leg v12 "$B"; else leg v12 "$B"; leg v11 "$A"; fi
done
