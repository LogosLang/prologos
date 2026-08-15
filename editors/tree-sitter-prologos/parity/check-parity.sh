#!/usr/bin/env bash
#
# check-parity.sh — EHP T1 P1. Do both editors see the SAME captures?
#
# Runs queries/highlights.scm over parity/fixture.prologos through BOTH
# consumer paths — Emacs `treesit', and web-tree-sitter with the same .wasm the
# VS Code extension loads — and asserts each against the committed golden.
#
# This is what turns "highlights.scm is the single source of truth" from a claim
# about a file into a property that FAILS A TEST when it stops being true.
#
# Usage:
#   ./check-parity.sh                 # assert both sides against golden.tsv
#   ./check-parity.sh --update-golden # re-freeze after an INTENDED query change
#   ./check-parity.sh --emacs-only    # skip the node side (no wasm / no node)
#
# ⚠ --update-golden is not a fixup for a red run. A diff means either the query
# changed on purpose (update, and say so in the commit) or a consumer drifted
# (do NOT update — that is the bug this exists to catch).
set -euo pipefail
cd "$(dirname "$0")"

UPDATE=0
EMACS_ONLY=0
for a in "$@"; do
  case "$a" in
    --update-golden) UPDATE=1 ;;
    --emacs-only)    EMACS_ONLY=1 ;;
    *) echo "unknown flag: $a" >&2; exit 2 ;;
  esac
done

# --- WASM STALENESS GUARD ---
#
# The node side loads ../../vscode-prologos/grammars/*.wasm.  If that is older
# than the source, this script compares Emacs-at-HEAD against VS-Code-at-
# whenever, and reports a DIVERGENCE that is an artifact of the build rather
# than a real disagreement — or worse, an AGREEMENT that is equally meaningless.
#
# Not hypothetical: install.sh's wasm step fails when emcc picks up a Python
# older than 3.10, and it fails AFTER the dylib is installed. That leaves Emacs
# on the new grammar and VS Code on the old one, with nothing to say so. It has
# happened twice.
#
# Compared by CONTENT HASH of the same sources the dylib is checked against, so
# "current" means the same thing for both artifacts.
WASM_DIR="../../vscode-prologos/grammars"
WASM_PROV="$WASM_DIR/tree-sitter-prologos.wasm.provenance"
SRC_HASH="$(cat ../grammar.js ../src/scanner.c 2>/dev/null | shasum -a 256 | cut -d' ' -f1)"

if [ "$EMACS_ONLY" = "0" ]; then
  if [ ! -f "$WASM_DIR/tree-sitter-prologos.wasm" ]; then
    echo "no wasm at $WASM_DIR — VS Code side cannot run." >&2
    echo "  Build it: EMSDK_PYTHON=<python3.10+> PATH=<emsdk>:\$PATH ../install.sh" >&2
    echo "  Or measure Emacs alone: $0 --emacs-only" >&2
    exit 3
  fi
  INSTALLED_HASH=""
  [ -f "$WASM_PROV" ] && INSTALLED_HASH="$(sed -n 's/^source_sha256=//p' "$WASM_PROV")"
  if [ -z "$INSTALLED_HASH" ]; then
    echo "STALE?: the wasm has no provenance — it predates this guard, or was" >&2
    echo "        built by hand.  Re-run ../install.sh so the two consumers are" >&2
    echo "        known to share one grammar, or pass --emacs-only." >&2
    exit 3
  elif [ "$INSTALLED_HASH" != "$SRC_HASH" ]; then
    echo "STALE: the wasm was NOT built from the current source." >&2
    echo "  wasm:   ${INSTALLED_HASH:0:12}" >&2
    echo "  source: ${SRC_HASH:0:12}" >&2
    echo "  Emacs and VS Code would be running DIFFERENT grammars, so any" >&2
    echo "  parity result here is meaningless.  Re-run ../install.sh." >&2
    exit 3
  fi
fi

FIXTURE="fixture.prologos"
GOLDEN="golden.tsv"
EM_OUT="$(mktemp -t parity-emacs)"
JS_OUT="$(mktemp -t parity-node)"
trap 'rm -f "$EM_OUT" "$JS_OUT"' EXIT

# --- the fixture must PARSE CLEANLY, or the golden has holes in it ---
#
# An ERROR region yields no captures at all, so a fixture that stopped parsing
# would silently shrink the golden and the run would still be green.
ERRS="$(emacs -Q --batch -L ../../emacs -l dump-captures.el \
          --eval "(prologos-parity-error-count \"$FIXTURE\")" 2>/dev/null \
        | sed -n 's/^ERROR nodes: //p')"
if [ "${ERRS:-1}" != "0" ]; then
  echo "FAIL: fixture has $ERRS ERROR node(s) — captures inside them are LOST," >&2
  echo "      so the golden would silently lose coverage. Fix the fixture." >&2
  exit 1
fi

echo "==> Emacs (treesit)"
emacs -Q --batch -L ../../emacs -l dump-captures.el \
      --eval "(prologos-parity-dump \"$FIXTURE\")" 2>/dev/null > "$EM_OUT"
echo "    $(wc -l < "$EM_OUT" | tr -d ' ') captures"

if [ "$EMACS_ONLY" = "0" ]; then
  echo "==> VS Code (web-tree-sitter, same .wasm the extension loads)"
  node dump-captures.mjs "$FIXTURE" > "$JS_OUT"
  echo "    $(wc -l < "$JS_OUT" | tr -d ' ') captures"
fi

if [ "$UPDATE" = "1" ]; then
  cp "$EM_OUT" "$GOLDEN"
  echo "==> golden UPDATED ($(wc -l < "$GOLDEN" | tr -d ' ') captures)"
  [ "$EMACS_ONLY" = "0" ] && diff -q "$EM_OUT" "$JS_OUT" >/dev/null \
    || echo "    ⚠ the two consumers DISAGREE — you just froze one of them" >&2
  exit 0
fi

status=0
if ! diff -u "$GOLDEN" "$EM_OUT" > /tmp/parity-emacs.diff 2>&1; then
  echo "FAIL: Emacs differs from golden" >&2; sed -n '1,30p' /tmp/parity-emacs.diff >&2; status=1
else
  echo "    ✓ Emacs matches golden"
fi

if [ "$EMACS_ONLY" = "0" ]; then
  if ! diff -u "$GOLDEN" "$JS_OUT" > /tmp/parity-node.diff 2>&1; then
    echo "FAIL: VS Code differs from golden" >&2; sed -n '1,30p' /tmp/parity-node.diff >&2; status=1
  else
    echo "    ✓ VS Code matches golden"
  fi
fi

if [ "$status" = "0" ]; then
  n="$(wc -l < "$GOLDEN" | tr -d ' ')"
  if [ "$EMACS_ONLY" = "1" ]; then
    # Say what actually ran.  Claiming "both consumers agree" after checking one
    # is the same misleading-pass shape this harness exists to eliminate.
    echo "PASS (EMACS ONLY) — Emacs matches the golden on $n captures."
    echo "  VS Code was NOT checked; this run says nothing about parity."
  else
    echo "PASS — both consumers agree with the golden on $n captures"
  fi
fi
exit "$status"
