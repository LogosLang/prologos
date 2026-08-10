#!/bin/bash
# check-parens.sh — Verify delimiter balance in a Racket file.
# Uses Racket's own reader, which gives precise error locations for
# mismatched (), [], {}, and unclosed strings.
#
# Usage: tools/check-parens.sh racket/prologos/relations.rkt
#        tools/check-parens.sh  (no args → checks all modified .rkt files)
#
# Exit 0 = all balanced. Exit 1 = error (with location).

# Prefer an explicit PROLOGOS_RACKET, then whatever is on PATH, then the
# common macOS install location. This was hardcoded to the macOS path, so on
# any other machine every invocation "failed" with `No such file or directory`
# and reported a delimiter error for a perfectly balanced file -- which also
# made the pre-commit hook that calls it a silent no-op.
RACKET="${PROLOGOS_RACKET:-}"
if [ -z "$RACKET" ]; then
    if command -v racket >/dev/null 2>&1; then
        RACKET="$(command -v racket)"
    else
        RACKET="/Applications/Racket v9.0/bin/racket"
    fi
fi
if [ ! -x "$RACKET" ]; then
    echo "check-parens.sh: no racket executable found (tried PROLOGOS_RACKET, PATH, /Applications/Racket v9.0)" >&2
    exit 2
fi

check_file() {
    local f="$1"
    # read-syntax gives precise locations; we redirect to /dev/null
    # because we only care about errors, not the parsed output.
    # Use raco expand which parses through #lang and reports syntax errors.
    # We only care about read errors (delimiter mismatches), not binding errors.
    # So: try raco make first (catches read errors with good locations).
    # If it fails, check if it's a read-syntax error (delimiter) vs other.
    "$RACKET" -e "
      (require syntax/modread)
      (define p (open-input-file \"$f\"))
      (port-count-lines! p)
      (with-module-reading-parameterization
        (lambda ()
          (let loop ()
            (define s (read-syntax \"$f\" p))
            (unless (eof-object? s) (loop)))))
      (close-input-port p)
    " 2>&1
    return $?
}

if [ $# -eq 0 ]; then
    # No args: check all modified .rkt files (staged + unstaged)
    files=$(git diff --name-only --diff-filter=AM HEAD -- '*.rkt' 2>/dev/null)
    if [ -z "$files" ]; then
        files=$(git diff --name-only --diff-filter=AM -- '*.rkt' 2>/dev/null)
    fi
    if [ -z "$files" ]; then
        echo "No modified .rkt files found."
        exit 0
    fi
else
    files="$@"
fi

errors=0
for f in $files; do
    if [ ! -f "$f" ]; then
        echo "SKIP: $f (not found)"
        continue
    fi
    output=$(check_file "$f")
    if [ $? -ne 0 ]; then
        echo "FAIL: $f"
        echo "$output" | head -5
        echo ""
        errors=$((errors + 1))
    fi
done

if [ $errors -eq 0 ]; then
    echo "All files balanced."
    exit 0
else
    echo "$errors file(s) with delimiter errors."
    exit 1
fi
