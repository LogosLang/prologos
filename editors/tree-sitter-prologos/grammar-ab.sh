#!/usr/bin/env bash
#
# grammar-ab.sh — per-file A/B of the grammar over the corpus.
#
#   ./grammar-ab.sh save     # measure now, store as the baseline
#   ./grammar-ab.sh diff     # measure now, compare per file; exit 1 if any file WORSE
#
# Options:  --baseline FILE   use a different baseline path
#           --allow-stale     measure even if the installed parser is stale
#
# The workflow for a grammar change:
#   ./install.sh && ./grammar-ab.sh save     # BEFORE the change
#   <edit grammar.js>
#   ./install.sh && ./grammar-ab.sh diff     # AFTER
#
# ⚠ WHY PER FILE.  .claude/rules/tree-sitter-grammar.md: a real fix can improve
# one file while error-RECOVERY CHURN degrades another that does not contain the
# construct at all.  Netted totals hide that, and the rule has always said so —
# what was missing was an instrument, so the A/B kept being improvised, badly.
set -euo pipefail
cd "$(dirname "$0")"

MODE=""
BASELINE=".grammar-ab-baseline.tsv"
ALLOW_STALE=0
while [ $# -gt 0 ]; do
  case "$1" in
    save|diff)     MODE="$1"; shift ;;
    --baseline)    BASELINE="$2"; shift 2 ;;
    --allow-stale) ALLOW_STALE=1; shift ;;
    *) echo "usage: $0 {save|diff} [--baseline FILE] [--allow-stale]" >&2; exit 2 ;;
  esac
done
[ -n "$MODE" ] || { echo "usage: $0 {save|diff} [--baseline FILE] [--allow-stale]" >&2; exit 2; }

# --- STALENESS GUARD ---
#
# Same contract as check-corpus.sh, and for the same reason: this measures the
# INSTALLED parser, not grammar.js.  ⚠ A REFUSAL IS NOT A RESULT — exit 3 here
# once got read by a differ as "every file improved to zero".  Compared by
# CONTENT HASH; mtimes lie across worktrees and clock skew.
PROV="$HOME/.emacs.d/tree-sitter/libtree-sitter-prologos.dylib.provenance"
SRC_HASH="$(cat grammar.js src/scanner.c 2>/dev/null | shasum -a 256 | cut -d' ' -f1)"
if [ "$ALLOW_STALE" != "1" ]; then
  INSTALLED_HASH=""
  [ -f "$PROV" ] && INSTALLED_HASH="$(sed -n 's/^source_sha256=//p' "$PROV")"
  if [ -z "$INSTALLED_HASH" ]; then
    echo "STALE?: the installed parser has no provenance — run ./install.sh." >&2
    exit 3
  elif [ "$INSTALLED_HASH" != "$SRC_HASH" ]; then
    echo "STALE: the installed parser was NOT built from the current source." >&2
    echo "  installed: ${INSTALLED_HASH:0:12}" >&2
    echo "  source:    ${SRC_HASH:0:12}" >&2
    echo "  Run ./install.sh first, or pass --allow-stale." >&2
    exit 3
  fi
fi

exec emacs -Q --batch \
  -L ../emacs \
  --eval "(setq prologos-ab--mode \"$MODE\")" \
  --eval "(setq prologos-ab--baseline \"$BASELINE\")" \
  -l ./grammar-ab.el \
  -f prologos-ab-run
