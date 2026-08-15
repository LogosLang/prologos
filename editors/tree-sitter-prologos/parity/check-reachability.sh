#!/usr/bin/env bash
#
# check-reachability.sh — does every declared capture actually FIRE?
#
# The third gate. check-vocabulary asks whether a capture is written and mapped;
# check-parity asks whether both consumers agree about it. Neither asks whether
# the GRAMMAR ever produces a node for it — which is how `(comment) @comment`
# stayed green while producing zero nodes across the whole library.
#
# Reports CORPUS and FIXTURE counts separately on purpose: a capture that fires
# in neither is a defect; one that fires only in the fixture is just a construct
# real code has not used yet.
set -euo pipefail
cd "$(dirname "$0")"
FN=prologos-reach-check
[ "${1:-}" = "--coverage" ] && FN=prologos-reach-coverage
exec emacs -Q --batch -L ../../emacs -l ./check-reachability.el -f "$FN"
