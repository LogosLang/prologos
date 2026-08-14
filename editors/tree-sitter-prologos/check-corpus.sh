#!/usr/bin/env bash
#
# check-corpus.sh — how much real Prologos does the tree-sitter grammar parse?
#
# Prints a per-file ERROR/MISSING table and a summary, and exits non-zero when
# the total exceeds --max (default 0).  Use it as the objective gate while
# repairing the grammar: run it, change a rule, run it again.
#
# Usage:
#   ./check-corpus.sh                 # whole default corpus, must be clean
#   ./check-corpus.sh --max 2123      # tolerate a known baseline
#   ./check-corpus.sh ../../racket/prologos/lib/prologos/core
#
# Requires the grammar to be installed (./install.sh) — it measures what Emacs
# would actually load, not what grammar.js says.
set -euo pipefail
cd "$(dirname "$0")"

MAX=0
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --max) MAX="$2"; shift 2 ;;
    *)     ARGS+=("$1"); shift ;;
  esac
done

exec emacs -Q --batch \
  -L ../emacs \
  --eval "(setq prologos-ts-check--max \"$MAX\")" \
  -l ./check-corpus.el \
  -f prologos-ts-check-corpus \
  ${ARGS[@]+"${ARGS[@]}"}
