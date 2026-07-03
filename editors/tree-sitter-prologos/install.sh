#!/usr/bin/env bash
#
# install.sh — regenerate, build, and install the Prologos tree-sitter grammar.
#
# Run this after editing grammar.js, or on a fresh checkout, so that the grammar
# Emacs loads matches prologos-ts-mode's font-lock rules. A stale grammar makes
# Emacs 31+ report `treesit-font-lock-rules-mismatch` and silently disable
# font-lock features (see gh#73-adjacent). This is the single source of truth for
# building the grammar — don't hand-copy dylibs.
#
# Usage:
#   ./install.sh                 # install into ~/.emacs.d/tree-sitter/
#   ./install.sh /some/other/dir # install into a custom treesit load dir
#
# Requires the tree-sitter CLI. Prefers the repo-local one (npm install here),
# else a tree-sitter on PATH.
#
set -euo pipefail
cd "$(dirname "$0")"

DEST="${1:-$HOME/.emacs.d/tree-sitter}"

case "$(uname -s)" in
  Darwin) EXT="dylib" ;;
  *)      EXT="so"    ;;
esac
LIB="libtree-sitter-prologos.${EXT}"

# Locate the tree-sitter CLI: repo-local first, then PATH.
TS="./node_modules/.bin/tree-sitter"
if [ ! -x "$TS" ]; then
  TS="$(command -v tree-sitter || true)"
fi
if [ -z "${TS:-}" ]; then
  echo "error: tree-sitter CLI not found." >&2
  echo "  Install it (e.g. 'npm install' in this dir, or 'cargo install tree-sitter-cli')." >&2
  exit 1
fi

echo "==> tree-sitter: $TS"
echo "==> generating parser from grammar.js"
"$TS" generate

echo "==> building $LIB"
"$TS" build -o "$LIB"

echo "==> installing to $DEST/$LIB"
mkdir -p "$DEST"
cp "$LIB" "$DEST/$LIB"

echo
echo "Done. Restart Emacs to load the rebuilt grammar."
echo "Verify in Emacs: open a .prologos file — no treesit-font-lock warning,"
echo "and keywords (def, defn, spec, defmacro, trait, ...) are highlighted."
