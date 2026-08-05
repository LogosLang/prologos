#!/usr/bin/env bash
#
# lint-hygiene.sh — correctness-focused hygiene gate for the Racket tree
#
# Runs, in order:
#   1. Custom project lints (BLOCKING, baseline-gated — only NEW findings fail):
#        lint-pnet-registration  — AST nodes missing .pnet serialization
#                                  registration (vector-impostor class)
#        lint-fire-fn-capture    — fire fns reading/writing a captured
#                                  stale network (silent write-loss class)
#        lint-memo-hash          — equal-based hashes near memo/cache
#                                  context (depth-bounded-hash O(N^3) class)
#        lint-parameters         — make-parameter sites missing test
#                                  isolation registration (leakage class)
#   2. raco review (REPORT-ONLY, if installed: raco pkg install review) on
#      the target files — unused identifiers/requires, shadowing, suspicious
#      code. Require-ORDERING warnings are filtered out (formatting, not
#      correctness). Report-only because review has stylistic false
#      positives; the signal is for the author, not the gate.
#
# Usage:
#   tools/lint-hygiene.sh                 # lints + review over modified .rkt files
#   tools/lint-hygiene.sh --staged        # lints + review over staged .rkt files
#   tools/lint-hygiene.sh --all           # lints + review over ALL production .rkt files
#   tools/lint-hygiene.sh FILE.rkt ...    # lints + review over the given files
#
# Exit: non-zero iff a BLOCKING custom lint found NEW (non-baselined) issues.
#
# Racket resolution: $RACKET env var, else the project-standard macOS path,
# else `racket` on PATH.

set -u

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "lint-hygiene: not inside a git repository" >&2; exit 1; }
PROLOGOS_DIR="$REPO_ROOT/racket/prologos"

# --- Racket resolution (portable: owner macOS path, CI/Linux PATH) ---------
if [ -z "${RACKET:-}" ]; then
  if [ -x "/Applications/Racket v9.0/bin/racket" ]; then
    RACKET="/Applications/Racket v9.0/bin/racket"
  elif command -v racket >/dev/null 2>&1; then
    RACKET="$(command -v racket)"
  else
    echo "lint-hygiene: no racket found (set \$RACKET)" >&2; exit 1
  fi
fi

# --- Target file selection -------------------------------------------------
mode="modified"
explicit_files=()
for arg in "$@"; do
  case "$arg" in
    --staged) mode="staged" ;;
    --all)    mode="all" ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) mode="explicit"; explicit_files+=("$arg") ;;
  esac
done

case "$mode" in
  staged)   files=$(git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=AM -- '*.rkt') ;;
  modified) files=$(git -C "$REPO_ROOT" diff --name-only --diff-filter=AM HEAD -- '*.rkt' 2>/dev/null) ;;
  all)      files=$(cd "$REPO_ROOT" && find racket/prologos -name '*.rkt' \
                      -not -path '*/compiled/*' -not -path '*/tests/*' \
                      -not -path '*/benchmarks/*' -not -path '*/tools/*') ;;
  explicit) files=$(printf '%s\n' "${explicit_files[@]}") ;;
esac

failures=0

# --- 1. Custom lints (blocking, baseline-gated) ----------------------------
# These scan their own fixed surfaces (whole production tree) regardless of
# the target file list — they are fast (~2s total) and baseline-gated, so
# they only fail on NEW findings.
echo "== custom lints (blocking; only NEW findings fail) =="
for lint in lint-pnet-registration lint-fire-fn-capture lint-memo-hash lint-parameters; do
  out=$(cd "$PROLOGOS_DIR" && "$RACKET" "tools/$lint.rkt" --strict 2>&1)
  if [ $? -ne 0 ]; then
    echo "FAIL: $lint"
    echo "$out"
    echo ""
    failures=$((failures + 1))
  else
    echo "ok:   $lint"
  fi
done

# --- 2. raco review (report-only, correctness-filtered) --------------------
if [ -n "$files" ]; then
  if "$RACKET" -l raco -- review --help >/dev/null 2>&1; then
    echo ""
    echo "== raco review (report-only; require-ordering noise filtered) =="
    review_out=""
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      [ -f "$REPO_ROOT/$f" ] || [ -f "$f" ] && true || continue
      target="$f"; [ -f "$REPO_ROOT/$f" ] && target="$REPO_ROOT/$f"
      out=$("$RACKET" -l raco -- review "$target" 2>&1 \
              | grep -v 'should come before' || true)
      [ -n "$out" ] && review_out="$review_out$out"$'\n'
    done <<< "$files"
    if [ -n "$review_out" ]; then
      printf '%s' "$review_out"
      echo "(report-only — fix what is real, ignore what is not)"
    else
      echo "clean."
    fi
  else
    echo ""
    echo "note: raco review not installed — skipping (raco pkg install review)"
  fi
else
  echo ""
  echo "no target .rkt files for review ($mode)."
fi

if [ $failures -ne 0 ]; then
  echo ""
  echo "$failures blocking lint(s) failed."
  exit 1
fi
exit 0
