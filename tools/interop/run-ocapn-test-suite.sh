#!/usr/bin/env bash
#
# run-ocapn-test-suite.sh — start the Racket OCapN test server,
# run the upstream `ocapn-test-suite` (Python) against it, capture
# results.
#
# The upstream test suite expects 4-field crypto-signed
# op:start-session frames; our current bridge implements only the
# 2-field shape. Until crypto handshake support lands, every test
# is expected to FAIL — this script's exit code does NOT reflect
# pass/fail; the CI gate is "we can run the suite at all, and we
# capture the diagnostics for future work."
#
# Usage:
#   tools/interop/run-ocapn-test-suite.sh [PORT] [TEST_SUITE_DIR]
#
# Environment:
#   OCAPN_TEST_SUITE_DIR  — path to the cloned ocapn-test-suite
#                          (default: ./tmp/ocapn-test-suite, cloned
#                          on first run)
#   OCAPN_TEST_PORT       — TCP port for the Racket server (default 22045)
#
# Exit:
#   0 — suite ran (even with failures); diagnostics captured.
#   1 — suite failed to run (server didn't start, suite not present,
#       dependency missing). Non-pass-related setup errors.

set -uo pipefail

PORT="${1:-${OCAPN_TEST_PORT:-22045}}"
SUITE_DIR="${2:-${OCAPN_TEST_SUITE_DIR:-/tmp/ocapn-test-suite}}"

REPO_ROOT="$(cd "$(dirname "$0")"/../.. && pwd)"
SERVER_SCRIPT="$REPO_ROOT/tools/interop/run-ocapn-test-server.rkt"

# Clone the test suite if missing.
if [ ! -d "$SUITE_DIR" ]; then
  echo "[run-ocapn-test-suite] cloning ocapn-test-suite to $SUITE_DIR"
  git clone --depth 1 https://github.com/ocapn/ocapn-test-suite "$SUITE_DIR" || {
    echo "[run-ocapn-test-suite] FAILED to clone test suite" >&2
    exit 1
  }
fi

if [ ! -f "$SUITE_DIR/test_runner.py" ]; then
  echo "[run-ocapn-test-suite] test_runner.py missing in $SUITE_DIR" >&2
  exit 1
fi

# Sanity-check Python deps.
python3 -c "import cryptography, cffi, stem" 2>/dev/null || {
  echo "[run-ocapn-test-suite] python deps missing — need python3-cryptography python3-cffi python3-stem"
  echo "                       on ubuntu: apt-get install -y python3-stem"
  echo "                       on pip:   pip3 install cryptography cffi"
  exit 1
}

echo "[run-ocapn-test-suite] starting Racket server on 127.0.0.1:$PORT"
SERVER_LOG=$(mktemp -t ocapn-server.XXXXXX)
racket "$SERVER_SCRIPT" --port "$PORT" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
trap "kill $SERVER_PID 2>/dev/null; rm -f $SERVER_LOG" EXIT

# Give the server a moment to bind.
sleep 3
if ! kill -0 $SERVER_PID 2>/dev/null; then
  echo "[run-ocapn-test-suite] server failed to start. log:" >&2
  cat "$SERVER_LOG" >&2
  exit 1
fi

# Hardcoded swiss-num for the Car Factory builder, per the test
# suite README. The host/port are how the test suite reaches us.
LOCATOR="ocapn://JadQ0++RzsD4M+40uLxTWVaVqM10DcBJ.tcp-testing-only?host=127.0.0.1&port=$PORT"

echo "[run-ocapn-test-suite] running test suite against $LOCATOR"
echo "[run-ocapn-test-suite] EXPECTED FAILURES until crypto handshake support lands"
echo "----------------------------------------------------------------"

cd "$SUITE_DIR"
# The suite will block waiting for OUR op:start-session reply
# (the Racket server doesn't yet send one — needs crypto handshake
# support, gap tracked in MASTER_ROADMAP.org). A 30s timeout is
# enough for at least the first test's connection to register.
timeout 60 python3 test_runner.py --captp-version "1.0-prologos-prerelease" "$LOCATOR"
SUITE_EXIT=$?
# Exit codes: 0 = all pass, 1 = some failed, 124 = timed out
# (expected: test suite blocks on absent crypto handshake reply).

echo "----------------------------------------------------------------"
echo "[run-ocapn-test-suite] suite exit code: $SUITE_EXIT"
echo "[run-ocapn-test-suite] server log tail:"
tail -20 "$SERVER_LOG"

# Exit 0: we ran the suite. Pass/fail is captured in output above
# but doesn't determine our exit code — see header comment.
exit 0
