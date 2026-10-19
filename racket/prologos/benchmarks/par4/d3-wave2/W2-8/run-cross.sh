#!/bin/bash
cd /Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-8
for t in micro:grid4i micro:grid6i micro:grid8i micro:grid10i; do
  echo "UPTIME $(uptime)"
  timeout -k 10 170 "/Applications/Racket v9.3/bin/racket" w28-bspk.rkt $t 7 2>&1 | grep '^W28BSPK:'
done
echo "UPTIME $(uptime)"
