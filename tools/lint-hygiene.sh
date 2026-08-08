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
#   tools/lint-hygiene.sh --diff REF      # lints + review over .rkt files changed vs REF
#                                         # (merge-base when computable, else REF itself —
#                                         # the CI mode: review only what the PR touched)
#   tools/lint-hygiene.sh FILE.rkt ...    # lints + review over the given files
#
# Review time budget: raco review costs ~10-15s PER FILE on this tree's large
# modules (measured 2026-08-06 — a full-tree sweep is ~25 min, which blew CI's
# 10-min lint job). The review step is therefore bounded by LINT_REVIEW_TIMEOUT
# seconds (default 240) when the `timeout` command exists; on expiry the report
# is truncated with a note. Blocking lints are never bounded — they are ~2s.
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
diff_ref=""
explicit_files=()
expect_diff_ref=0
for arg in "$@"; do
  if [ "$expect_diff_ref" -eq 1 ]; then
    diff_ref="$arg"; expect_diff_ref=0; continue
  fi
  case "$arg" in
    --staged) mode="staged" ;;
    --all)    mode="all" ;;
    --diff)   mode="diff"; expect_diff_ref=1 ;;
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) mode="explicit"; explicit_files+=("$arg") ;;
  esac
done
if [ "$mode" = "diff" ] && [ -z "$diff_ref" ]; then
  echo "lint-hygiene: --diff requires a ref argument" >&2; exit 1
fi

case "$mode" in
  staged)   files=$(git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=AM -- '*.rkt') ;;
  modified) files=$(git -C "$REPO_ROOT" diff --name-only --diff-filter=AM HEAD -- '*.rkt' 2>/dev/null) ;;
  all)      files=$(cd "$REPO_ROOT" && find racket/prologos -name '*.rkt' \
                      -not -path '*/compiled/*' -not -path '*/tests/*' \
                      -not -path '*/benchmarks/*' -not -path '*/tools/*') ;;
  diff)     # merge-base when computable (local three-dot semantics); in a
            # shallow CI clone merge-base fails — fall back to REF itself,
            # which against the PR merge commit is exactly the PR's changes.
            base=$(git -C "$REPO_ROOT" merge-base "$diff_ref" HEAD 2>/dev/null || echo "$diff_ref")
            files=$(git -C "$REPO_ROOT" diff --name-only --diff-filter=AM "$base" HEAD -- '*.rkt' 2>/dev/null) ;;
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
    # collect existing files (repo-relative or absolute) into one invocation
    targets=()
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if [ -f "$REPO_ROOT/$f" ]; then targets+=("$REPO_ROOT/$f")
      elif [ -f "$f" ]; then targets+=("$f")
      fi
    done <<< "$files"
    review_timed_out=0
    if [ ${#targets[@]} -gt 0 ]; then
      # Bound the report-only step: review costs ~10-15s/file here, and an
      # unbounded sweep once ate CI's whole 10-min lint budget (PR #81).
      budget="${LINT_REVIEW_TIMEOUT:-240}"
      # coreutils timeout on Linux/CI; perl-alarm fallback on macOS (stock
      # macOS ships no `timeout`, and an uncapped run would make the
      # pre-commit 60s cap a fiction on the primary dev machine). perl's
      # alarm survives exec, so the review process dies on SIGALRM (rc 142).
      if command -v timeout >/dev/null 2>&1; then
        raw_out=$(timeout "$budget" "$RACKET" -l raco -- review "${targets[@]}" 2>&1)
        [ $? -eq 124 ] && review_timed_out=1
      elif command -v perl >/dev/null 2>&1; then
        raw_out=$(perl -e 'alarm shift @ARGV; exec @ARGV' "$budget" \
                    "$RACKET" -l raco -- review "${targets[@]}" 2>&1)
        [ $? -eq 142 ] && review_timed_out=1
      else
        raw_out=$("$RACKET" -l raco -- review "${targets[@]}" 2>&1)
      fi
      # require-ordering noise comes in BOTH spellings ("should come before"
      # / "should come after") — filter both.
      review_out=$(printf '%s\n' "$raw_out" \
                     | grep -vE 'should come (before|after)' || true)
    else
      review_out=""
    fi
    if [ -n "$review_out" ]; then
      printf '%s\n' "$review_out"
      echo "(report-only — fix what is real, ignore what is not)"
    else
      echo "clean."
    fi
    if [ "$review_timed_out" = "1" ]; then
      echo "note: review report TRUNCATED at ${budget}s (LINT_REVIEW_TIMEOUT) — ${#targets[@]} file(s) requested"
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
