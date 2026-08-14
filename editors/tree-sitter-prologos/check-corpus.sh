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
ALLOW_STALE=0
MAX_SWALLOWS=""
MAX_PCT=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --max) MAX="$2"; shift 2 ;;
    --allow-stale) ALLOW_STALE=1; shift ;;
    --max-swallows) MAX_SWALLOWS="$2"; shift 2 ;;
    *)     ARGS+=("$1"); shift ;;
  esac
done

# --- STALENESS GUARD ---
#
# The gate measures the INSTALLED dylib, not grammar.js.  Editing the grammar
# and running this without ./install.sh measures the OLD parser and reports no
# change — which reads as "my fix did nothing".  That cost real time during TSG
# T1, and a warning in a doc only works while someone is reading it.
#
# Compared by CONTENT HASH, not mtime: mtimes lie across worktrees, fresh
# checkouts and clock skew.
DEST_DEFAULT="$HOME/.emacs.d/tree-sitter"
PROV="$DEST_DEFAULT/libtree-sitter-prologos.dylib.provenance"
SRC_HASH="$(cat grammar.js src/scanner.c 2>/dev/null | shasum -a 256 | cut -d' ' -f1)"
if [ "$ALLOW_STALE" != "1" ]; then
  INSTALLED_HASH=""
  [ -f "$PROV" ] && INSTALLED_HASH="$(sed -n 's/^source_sha256=//p' "$PROV")"
  if [ -z "$INSTALLED_HASH" ]; then
    echo "warning: no provenance for the installed parser — run ./install.sh" >&2
    echo "         (measuring anyway; it may not be built from this source)" >&2
  elif [ "$INSTALLED_HASH" != "$SRC_HASH" ]; then
    echo "STALE: the installed parser was NOT built from the current source." >&2
    echo "  installed: ${INSTALLED_HASH:0:12}" >&2
    echo "  source:    ${SRC_HASH:0:12}" >&2
    echo "  Run ./install.sh first, or pass --allow-stale to measure anyway." >&2
    exit 3
  fi
fi

# --- RATCHET: read the checked-in budget unless overridden ---
BUDGET_FILE="corpus-budget.txt"
if [ -z "$MAX_SWALLOWS" ] && [ -f "$BUDGET_FILE" ]; then
  MAX_SWALLOWS="$(sed -n 's/^max_swallows=//p' "$BUDGET_FILE")"
fi
if [ -z "$MAX_PCT" ] && [ -f "$BUDGET_FILE" ]; then
  MAX_PCT="$(sed -n 's/^max_unparsed_pct=//p' "$BUDGET_FILE")"
fi

exec emacs -Q --batch \
  -L ../emacs \
  --eval "(setq prologos-ts-check--max \"$MAX\")" \
  --eval "(setq prologos-ts-check--max-swallows \"${MAX_SWALLOWS:-}\")" \
  --eval "(setq prologos-ts-check--max-pct \"${MAX_PCT:-}\")" \
  -l ./check-corpus.el \
  -f prologos-ts-check-corpus \
  ${ARGS[@]+"${ARGS[@]}"}
