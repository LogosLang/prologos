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
# ATOMIC REPLACE, never `cp` over the live file.
#
# On macOS (Apple Silicon especially) overwriting a .dylib IN PLACE while any
# process has it mapped invalidates the code-signature pages, and the kernel
# kills that process: SIGKILL, "Code Signature Invalid", crashing thread inside
# dyld with no frame from the library itself.  A running Emacs with a .prologos
# buffer open is exactly such a process — i.e. the normal case when you run this
# script, which even tells you to "restart Emacs" afterwards.
#
# `mv` within the same directory is a rename: it swaps the DIRECTORY ENTRY and
# leaves the old inode alone, so already-mapped processes keep the file they
# mapped and only new loads see the new one.  Costs nothing; prevents a crash
# that looks like a grammar bug.  (Diagnosed 2026-08-14 from three Emacs crash
# reports.)
cp "$LIB" "$DEST/.$LIB.incoming.$$"
mv -f "$DEST/.$LIB.incoming.$$" "$DEST/$LIB"

echo
echo "Done. Restart Emacs to load the rebuilt grammar."
echo "Verify in Emacs: open a .prologos file — no treesit-font-lock warning,"
echo "and keywords (def, defn, spec, defmacro, trait, ...) are highlighted."
