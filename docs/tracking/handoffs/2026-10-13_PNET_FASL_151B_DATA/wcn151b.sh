#!/bin/bash
# wcn151b.sh <rootA v11> <rootB v12> <out.jsonl> <rounds> — DEFERRED 151 (b): warm / no-cache / cold load
# phase in TWO trees, interleaved ABBA by round. Per tree and round (as wcn151.sh): warm, nocache,
# then rm the cache and regenerate it with ONE identical cold command (run152 test-transducer-01), then
# warm again — so every warm leg reads a cache written the same way. Run under hold-suite-lock.rkt.
set -u
A=$1; B=$2; OUT=$3; ROUNDS=$4
H=/Users/avanti/.hermes/profiles/logos-language-designer/skills/software-development/racket-performance-probing/scripts
RK="/Applications/Racket v9.3/bin/racket"
one() { # tag root label env test
  local load; load=$(uptime | sed -E 's/.*load averages?: ([0-9.]+).*/\1/')
  local line; line=$(env $4 timeout -k 10 300 "$RK" "$H/run152.rkt" "$2" "$5" "$3" 2>/dev/null | grep '^RESULT ')
  echo "{\"tree\":\"$1\",\"leg\":\"$3\",\"load1\":$load,\"r\":${line#RESULT $3 }}" >> "$OUT"
  echo "$1 $3 load=$load ${line:0:170}"
}
legs() { # tag root
  one "$1" "$2" warm X=1 -
  one "$1" "$2" nocache PNET=off -
  rm -rf "$2/data/cache/pnet"
  one "$1" "$2" cold X=1 test-transducer-01.rkt
  one "$1" "$2" warm X=1 -
}
for r in $(seq 1 "$ROUNDS"); do
  if [ $((r % 2)) -eq 1 ]; then legs v11 "$A"; legs v12 "$B"; else legs v12 "$B"; legs v11 "$A"; fi
done
