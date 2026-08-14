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
  echo "PASS — both consumers agree with the golden on $(wc -l < "$GOLDEN" | tr -d ' ') captures"
fi
exit "$status"
