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

# --- WASM for the VS Code extension (optional) ---
#
# The VS Code extension drives semantic highlighting from the SAME grammar, via
# web-tree-sitter. Building it here is what keeps the two editors from drifting
# apart: without this step VS Code silently keeps whatever .wasm it last had,
# which is the exact failure mode this whole track was about.
#
# Skipped without complaint when emcc is absent — it is not needed for Emacs.
# emsdk is not on PATH by default; source its emsdk_env.sh first if you want it.
WASM="tree-sitter-prologos.wasm"
VSCODE_GRAMMARS="../vscode-prologos/grammars"
VSCODE_QUERIES="../vscode-prologos/queries"

# highlights.scm is PLAIN TEXT and has nothing to do with wasm, so its copy is
# NOT gated on emcc.  It used to be, inside the branch below, which meant
# editing the queries and running this script without emsdk sourced left the
# extension on a STALE .scm and said nothing — the same silent-drift failure
# this script exists to prevent, one level down.  Caught 2026-08-14 by hashing
# source against deployed.
if [ -d "$VSCODE_QUERIES" ] || mkdir -p "$VSCODE_QUERIES"; then
  cp queries/highlights.scm "$VSCODE_QUERIES/highlights.scm"
  echo "==> installed highlights.scm to $VSCODE_QUERIES/"
fi

# SRC_HASH identifies the SOURCE both artifacts are built from, so the dylib and
# the wasm can be compared against the same thing.  Defined here because the wasm
# block below needs it too.
SRC_HASH="$(cat grammar.js src/scanner.c 2>/dev/null | shasum -a 256 | cut -d" " -f1)"

write_wasm_provenance() {
  # $1 = directory holding a copy of the wasm
  {
    echo "source_sha256=$SRC_HASH"
    echo "git_sha=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$1/$WASM.provenance"
}

if command -v emcc >/dev/null 2>&1; then
  echo "==> building $WASM (emcc found)"
  # ⚠ emcc requires Python >= 3.10 and picks up Xcode's 3.9 by default, failing
  # with an assertion.  That failure lands AFTER the dylib is installed, so
  # without a guard the session ends with Emacs on the NEW grammar and VS Code
  # on the OLD one — the exact divergence the provenance below exists to catch.
  # Set EMSDK_PYTHON to a 3.10+ interpreter if this trips.
  "$TS" build --wasm
  write_wasm_provenance .
  if [ -d "$VSCODE_GRAMMARS" ] || mkdir -p "$VSCODE_GRAMMARS"; then
    cp "$WASM" "$VSCODE_GRAMMARS/$WASM"
    write_wasm_provenance "$VSCODE_GRAMMARS"
    echo "    installed to $VSCODE_GRAMMARS/"
  fi
  echo "    wasm provenance: ${SRC_HASH:0:12}"
else
  echo "==> skipping wasm (emcc not on PATH — Emacs does not need it)"
  echo "    for VS Code: source your emsdk_env.sh, then re-run this script"
  # Deliberately do NOT delete an existing wasm: it may still be valid, and
  # deleting it would silently disable VS Code semantic tokens.  Its provenance
  # is left untouched, so check-parity.sh can tell whether it went stale.
fi

# --- SMOKE TEST: does the thing we just installed actually load and parse? ---
#
# Not ceremony.  On 2026-08-14 a bad install SIGKILLed every Emacs that touched
# it, and the failure was read as "the new grammar hangs" — a wrong diagnosis
# that cost a revert and a detour, because nothing checked the installed
# artifact at the point of installation.  This is ~0.3s.
echo "==> smoke test"
SMOKE="$(mktemp -t prologos-smoke).prologos"
printf 'defn f [x]\n  [int+ x 1]\n' > "$SMOKE"
if timeout -k 5 60 emacs -Q --batch --eval "(progn
      (require 'treesit)
      (unless (treesit-language-available-p 'prologos)
        (message \"SMOKE FAIL: grammar not loadable\") (kill-emacs 1))
      (with-temp-buffer
        (insert-file-contents \"$SMOKE\")
        (treesit-parser-create 'prologos)
        (treesit-buffer-root-node))
      (message \"    ok — loads and parses\"))" 2>&1 | tail -1; then
  :
else
  echo "    SMOKE TEST FAILED — the installed parser does not load/parse." >&2
  echo "    The previous parser was replaced by atomic rename, so any RUNNING" >&2
  echo "    Emacs is unaffected; new sessions would get this one." >&2
  rm -f "$SMOKE"
  exit 1
fi
rm -f "$SMOKE"

# --- PROVENANCE: what exactly is installed? ---
#
# Content hash, not mtime.  mtimes lie across worktrees, fresh checkouts and
# clock skew; the hash answers "is the installed parser built from THIS source?"
# directly.  check-corpus.sh reads this to refuse measuring a stale parser —
# the footgun that made a real fix look like it did nothing.
PROV="$DEST/$LIB.provenance"
{
  echo "source_sha256=$SRC_HASH"
  echo "git_sha=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$PROV"
echo "==> provenance: ${SRC_HASH:0:12} @ $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

echo
echo "Done. A RUNNING Emacs keeps the parser it already mapped — this reaches it"
echo "at its next start.  Nothing else is needed; the install is atomic and safe"
echo "to run with Emacs open."
echo "Verify: open a .prologos file — no treesit-font-lock warning, and keywords"
echo "(def, defn, spec, defmacro, trait, ...) are highlighted."
