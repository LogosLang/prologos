#!/bin/bash
# Census of hidden consumers. Production = racket/prologos/**/*.rkt excluding tests/ tools/ benchmarks/ compiled/ data/
# Pattern: end-of-line aware '(NAME([[:space:])]|$)' plus bare references 'NAME([[:space:])]|$)' (for passing as value / parameterize)
# Comment lines (first non-space char ';') dropped.
ROOT=/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos
cd "$ROOT"
prod() { find . -name '*.rkt' -not -path '*/tests/*' -not -path '*/tools/*' -not -path '*/benchmarks/*' -not -path '*/compiled/*' -print0; }
nonprod() { find . -name '*.rkt' \( -path '*/tests/*' -o -path '*/tools/*' -o -path '*/benchmarks/*' \) -not -path '*/compiled/*' -print0; }
# also repo-level tools/ outside racket/prologos
REPOTOOLS=/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/tools
syms="current-tree-reduce-threshold merge-fire-results tree-reduce-fire-results bulk-merge-writes collect-deferred-propagators fire-result-new-propagators fire-result-new-cells fire-result-undeclared-writes fire-result-value-writes fire-result fire-and-collect-writes current-bsp-fire-round? current-cell-id-namespace current-source-loc current-bsp-observer current-bsp-round-stats run-to-quiescence-inner run-to-quiescence-bsp run-to-quiescence sequential-fire-all make-pool-executor make-worker-pool current-parallel-executor current-worker-pool worldview-cache-cell-id fork-prop-network make-parallel-fire-all make-parallel-thread-fire-all"
for s in $syms; do
  es=$(printf '%s' "$s" | sed 's/[?]/\\?/g')
  pat="(^|[^-A-Za-z0-9?!*/<>=])${es}([[:space:])]|\$)"
  pc=$(prod | xargs -0 grep -n -E "$pat" | grep -v -E ':[0-9]+:[[:space:]]*;' | wc -l | tr -d ' ')
  pf=$(prod | xargs -0 grep -l -E "$pat" | wc -l | tr -d ' ')
  nc=$(nonprod | xargs -0 grep -n -E "$pat" 2>/dev/null | grep -v -E ':[0-9]+:[[:space:]]*;' | wc -l | tr -d ' ')
  nf=$(nonprod | xargs -0 grep -l -E "$pat" 2>/dev/null | wc -l | tr -d ' ')
  printf '%-34s prod-lines=%-4s prod-files=%-3s nonprod-lines=%-4s nonprod-files=%s\n' "$s" "$pc" "$pf" "$nc" "$nf"
done
