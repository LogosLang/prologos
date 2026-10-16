#!/bin/bash
# List every (non-comment) line mentioning each symbol, split production vs non-production
ROOT=/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos
cd "$ROOT"
prod() { find . -name '*.rkt' -not -path '*/tests/*' -not -path '*/tools/*' -not -path '*/benchmarks/*' -not -path '*/compiled/*' -print0; }
nonprod() { find . -name '*.rkt' \( -path '*/tests/*' -o -path '*/tools/*' -o -path '*/benchmarks/*' \) -not -path '*/compiled/*' -print0; }
for s in "$@"; do
  es=$(printf '%s' "$s" | sed 's/[?]/\\?/g')
  pat="(^|[^-A-Za-z0-9?!*/<>=])${es}([[:space:])]|\$)"
  echo "=== $s : PRODUCTION"
  prod | xargs -0 grep -n -E "$pat" | grep -v -E ':[0-9]+:[[:space:]]*;' | cut -c1-170
  echo "=== $s : NON-PRODUCTION (tests/tools/benchmarks)"
  nonprod | xargs -0 grep -n -E "$pat" 2>/dev/null | grep -v -E ':[0-9]+:[[:space:]]*;' | cut -c1-170
done
