#!/bin/sh
# Guard against unnecessary full-suite re-runs.
# Checks if any .rkt file changed since the last timings.jsonl entry.
# If no changes detected, prints a warning and exits 1.
# Usage: sh tools/guard-suite-rerun.sh && racket tools/run-affected-tests.rkt --all

TIMINGS="racket/prologos/data/benchmarks/timings.jsonl"
FAILURES="racket/prologos/data/benchmarks/failures"

# Get timestamp of last timings entry
if [ -f "$TIMINGS" ]; then
    LAST_RUN=$(stat -f '%m' "$TIMINGS" 2>/dev/null || stat -c '%Y' "$TIMINGS" 2>/dev/null)
    NOW=$(date +%s)
    ELAPSED=$(( NOW - LAST_RUN ))

    if [ "$ELAPSED" -lt 300 ]; then
        # Check if any .rkt files changed since last run
        CHANGED=$(find racket/prologos -name '*.rkt' -newer "$TIMINGS" 2>/dev/null | head -1)
        if [ -z "$CHANGED" ]; then
            echo "========================================" >&2
            echo "GUARD: No .rkt files changed since last suite run (${ELAPSED}s ago)." >&2
            echo "Read failure logs instead: data/benchmarks/failures/*.log" >&2
            echo "Or run individual tests: raco test tests/test-NAME.rkt" >&2
            echo "========================================" >&2
            exit 1
        fi
    fi
fi

# If we get here, either no prior run or files changed — proceed
exit 0
