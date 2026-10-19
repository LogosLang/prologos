#!/bin/bash
# C8: which live branches change the scheduler or the merges D.2 touches, relative to main (three-dot: changes on the branch since merge-base)?
cd /Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors
FILES="racket/prologos/propagator.rkt racket/prologos/type-lattice.rkt racket/prologos/decision-cell.rkt racket/prologos/typing-propagators.rkt racket/prologos/relations.rkt racket/prologos/metavar-store.rkt racket/prologos/atms.rkt racket/prologos/sre-core.rkt racket/prologos/qtt.rkt racket/prologos/resolution.rkt racket/prologos/classify-inhabit.rkt racket/prologos/elaborator-network.rkt racket/prologos/stratified-eval.rkt"
for b in ciu6-path-selection deferred-sweep-146-149 ppn4c-elaboration-on-network par4-p0 f3a-census egraph-relational-spike preduce-autonomy heuristic-thompson-a2091b dazzling-wescoff-4b692b; do
  if git rev-parse -q --verify "$b" >/dev/null; then
    mb=$(git merge-base main "$b")
    stat=$(git diff --shortstat "$mb" "$b" -- $FILES)
    files=$(git diff --name-only "$mb" "$b" -- $FILES | xargs -n1 basename 2>/dev/null | tr '\n' ' ')
    ahead=$(git rev-list --count main.."$b")
    echo "$b | ahead of main: $ahead | last: $(git log -1 --format=%cs $b) | $stat | $files"
  else
    echo "$b | (no local ref)"
  fi
done
# power check: a branch known to have changed propagator.rkt relative to an OLD base must show nonzero
echo "power: par4-p0 vs its parent 4097b1c8~5 on propagator.rkt: $(git diff --shortstat 4097b1c8~5 par4-p0 -- racket/prologos/propagator.rkt)"
