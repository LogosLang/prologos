#!/usr/bin/env bash
#
# run-ocapn-test-suite.sh — start the Racket OCapN test server,
# run the upstream `ocapn-test-suite` (Python) against it, capture
# results.
#
# The Racket OCapN test server speaks the canonical 4-field
# crypto-signed op:start-session handshake (Phase 58.b) and validates
# the inbound op:start-session, aborting on an unsupported CapTP
# version (Phase 58.c). This script runs the SELECTED subset of the
# upstream suite (see tools/interop/ocapn-run-tests.py) — the tests
# the current implementation targets — and gates CI on them passing.
#
# Usage:
#   tools/interop/run-ocapn-test-suite.sh [PORT] [TEST_SUITE_DIR]
#
# Environment:
#   OCAPN_TEST_SUITE_DIR  — path to the cloned ocapn-test-suite
#                          (default: /tmp/ocapn-test-suite, cloned
#                          on first run)
#   OCAPN_TEST_PORT       — TCP port for the Racket server (default 22045)
#   OCAPN_SUITE_TIMEOUT   — wall-clock budget for the whole selected
#                          run, in seconds (default 900)
#
# Exit:
#   0 — every selected test passed.
#   1 — a selected test failed or errored, the runner exited non-zero
#       (which includes the allow-list drift check), the run timed out,
#       or setup failed (server didn't start, suite not present,
#       dependency missing).

set -uo pipefail

# The compiler's giant match functions (whnf/nf ~990 arms) exceed Racket CS's
# default compile limit and fall back to the INTERPRETER. The Racket server
# below spends nearly all its time in reduction, and upstream's tests carry
# their own wall-clock budgets, so an interpreted build does not merely run
# slow -- it FAILS. Measured on this exact suite: 17/17 compiled, 14 passed +
# 1 errored interpreted, which is precisely what CI reported before this line
# existed.
#
# Set here as well as in the workflow so the gate does not depend on the
# caller's environment.
export PLT_CS_COMPILE_LIMIT="${PLT_CS_COMPILE_LIMIT:-1000000}"

PORT="${1:-${OCAPN_TEST_PORT:-22045}}"
SUITE_DIR="${2:-${OCAPN_TEST_SUITE_DIR:-/tmp/ocapn-test-suite}}"
SUITE_TIMEOUT="${OCAPN_SUITE_TIMEOUT:-900}"

REPO_ROOT="$(cd "$(dirname "$0")"/../.. && pwd)"
SERVER_SCRIPT="$REPO_ROOT/tools/interop/run-ocapn-test-server.rkt"

# The upstream conformance suite, PINNED.
#
# ⚠ PINNED 2026-08-05, after an unpinned `--depth 1` clone of HEAD broke CI on a
# commit that touched no OCapN code at all. Upstream
# ocapn-test-suite#41 ("message-framing") wrapped every CapTP message in a
# NETSTRING:
#
#     -  message.to_syrup()              /  syrup.syrup_read(socketio)
#     +  Netstring(message.to_syrup())   /  Netstring.read(socketio)
#
# This server speaks RAW Syrup, so neither side could parse the other: we logged
# "inbound start-session REJECTED (40 bytes)" and the Python side died with
# "Expected ASCII digit when reading netstring length prefix". All 24 tests
# errored in 0.179s.
#
# The npm half of this gate is already pinned for exactly this reason — the
# install step uses `npm ci` against a committed lockfile so that "the drift
# gate means what its diagnostic says it means". This is the same argument: an
# unpinned clone tests UPSTREAM'S HEAD, not our code, so the gate turns red for
# reasons no commit here caused and green again without anyone fixing anything.
#
# Adopting the new framing is REAL WORK on the wire format and is filed
# separately — see DEFERRED.md § "OCapN: upstream moved to netstring framing".
# When it lands, bump this SHA in the same commit.
#
# Verified green at this SHA (24 passed / 0 failed / 0 errored, 2026-08-05).
OCAPN_SUITE_SHA="${OCAPN_SUITE_SHA:-74db78f}"

if [ ! -d "$SUITE_DIR" ]; then
  echo "[run-ocapn-test-suite] cloning ocapn-test-suite to $SUITE_DIR (pinned $OCAPN_SUITE_SHA)"
  git clone https://github.com/ocapn/ocapn-test-suite "$SUITE_DIR" || {
    echo "[run-ocapn-test-suite] FAILED to clone test suite" >&2
    exit 1
  }
fi

# Check out the pin. Done on EVERY run, not only after a fresh clone, so a
# pre-existing checkout (a dev box, a warm CI cache) cannot silently run a
# different revision than CI does — which is precisely how this drift stayed
# invisible locally while CI was red.
if ! ( cd "$SUITE_DIR" && git checkout -q "$OCAPN_SUITE_SHA" 2>/dev/null ); then
  echo "[run-ocapn-test-suite] pin $OCAPN_SUITE_SHA not present; fetching" >&2
  ( cd "$SUITE_DIR" && git fetch -q origin && git checkout -q "$OCAPN_SUITE_SHA" ) || {
    echo "[run-ocapn-test-suite] FAILED to check out pinned SHA $OCAPN_SUITE_SHA" >&2
    exit 1
  }
fi
echo "[run-ocapn-test-suite] suite at $(cd "$SUITE_DIR" && git rev-parse --short HEAD)"

if [ ! -f "$SUITE_DIR/test_runner.py" ]; then
  echo "[run-ocapn-test-suite] test_runner.py missing in $SUITE_DIR" >&2
  exit 1
fi

# Sanity-check Python deps.
# NOTE: `stem` is deliberately NOT required. It is imported only by
# upstream's onion netlayer, which these tests never use — we drive the
# tcp-testing-only netlayer. Requiring it made the whole gate unrunnable
# in containers where stem will not build. ocapn-run-tests.py imports the
# netlayer directly rather than going through upstream's test_runner.py,
# which is what pulls in onion.
python3 -c "import cryptography, cffi" 2>/dev/null || {
  echo "[run-ocapn-test-suite] python deps missing — need python3-cryptography python3-cffi"
  echo "                       on pip:   pip3 install cryptography cffi"
  exit 1
}

echo "[run-ocapn-test-suite] starting Racket server on 127.0.0.1:$PORT"
# Overridable so a diagnosis can keep the log. The default is still a temp
# file; only the cleanup differs, and a stray temp file is cheaper than a
# session spent reading a STALE log from a previous run because the path was
# guessed rather than known.
SERVER_LOG=${OCAPN_SERVER_LOG:-$(mktemp -t ocapn-server.XXXXXX)}
racket "$SERVER_SCRIPT" --port "$PORT" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
trap "kill $SERVER_PID 2>/dev/null; [ -n \"${OCAPN_SERVER_LOG:-}\" ] || rm -f $SERVER_LOG" EXIT

# Wait for the server to bind. It loads the Prologos OCapN modules
# at startup (process-string of the handshake preamble), which
# takes ~15-25s. Poll the log for the "listening" line rather than
# a fixed sleep.
SERVER_READY=
for i in $(seq 1 60); do
  if grep -q "listening on" "$SERVER_LOG" 2>/dev/null; then
    SERVER_READY=1
    break
  fi
  if ! kill -0 $SERVER_PID 2>/dev/null; then
    break
  fi
  sleep 1
done
if [ -z "$SERVER_READY" ]; then
  echo "[run-ocapn-test-suite] server failed to start / bind. log:" >&2
  cat "$SERVER_LOG" >&2
  exit 1
fi

# Hardcoded swiss-num for the Car Factory builder, per the test
# suite README. The host/port are how the test suite reaches us.
LOCATOR="ocapn://JadQ0++RzsD4M+40uLxTWVaVqM10DcBJ.tcp-testing-only?host=127.0.0.1&port=$PORT"

# Every selected test must pass, and there must be at least this many of
# them — the count is the length of SELECTED in ocapn-run-tests.py, which
# spans op_start_session, op_deliver, op_abort, third_party_handoffs,
# op_gc and op_listen. Raise it in lockstep when SELECTED grows; the
# runner's own drift check is what catches a test appearing UPSTREAM.
EXPECTED_PASS=24

echo "[run-ocapn-test-suite] running selected tests against $LOCATOR"
echo "[run-ocapn-test-suite] gate: >= $EXPECTED_PASS passed, 0 failed, 0 errored, runner exit 0"
echo "----------------------------------------------------------------"

# The selective runner (ocapn-run-tests.py) lives in this repo; it
# chdir's into the suite dir itself. CapTP version "1.0" matches what
# the upstream tests assert on.
# Budget: each selected test costs ~3s locally but ~25s on a GitHub runner
# (every step-connection is a process-string that re-loads modules). The old
# 90s budget fit 5 tests and silently truncated the run at 6 when the count
# grew to 9 — the suite reported MILESTONE NOT MET for a TIMEOUT, not a
# failure. The 600s that replaced it was 25s x 24 tests EXACTLY, i.e. no
# headroom at all, and `|| true` still hid exit 124. Both are fixed below:
# 900s of budget, and a timeout is now reported AS a timeout.
# Note the deliberate absence of `|| true`: it does not merely discard the
# exit code, it OVERWRITES PIPESTATUS (`true` is a simple command), so
# SUITE_EXIT read 0 unconditionally. This script does not `set -e`, so the
# bare pipeline is safe.
OCAPN_TEST_SUITE_DIR="$SUITE_DIR" timeout "$SUITE_TIMEOUT" python3 -u \
  "$REPO_ROOT/tools/interop/ocapn-run-tests.py" \
  "$LOCATOR" "1.0" 2>&1 | tee /tmp/ocapn-suite-output.txt
SUITE_EXIT=${PIPESTATUS[0]}

# Count pass/error/fail markers. `grep -c` prints "0" and exits 1 when there
# is no match, so `|| echo 0` would append a SECOND line and `[` would then
# reject the two-line string "0\n0" with "integer expression expected" —
# firing exactly when zero tests passed. `|| true` keeps grep's own "0".
N_PASS=$(grep -c " \.\.\. ok$" /tmp/ocapn-suite-output.txt || true)
N_ERROR=$(grep -c " \.\.\. ERROR$" /tmp/ocapn-suite-output.txt || true)
N_FAIL=$(grep -c " \.\.\. FAIL$" /tmp/ocapn-suite-output.txt || true)
echo ""
echo "[run-ocapn-test-suite] tests passed: $N_PASS"
echo "[run-ocapn-test-suite] tests errored: $N_ERROR"
echo "[run-ocapn-test-suite] tests failed: $N_FAIL"

echo "----------------------------------------------------------------"
echo "[run-ocapn-test-suite] runner exit code: $SUITE_EXIT"
echo "[run-ocapn-test-suite] server log tail:"
tail -20 "$SERVER_LOG"

# The gate. Every one of these was computed and echoed before and none was
# compared, so a 25th failing test passed the gate.
GATE_OK=1
if [ "$SUITE_EXIT" -eq 124 ]; then
  echo "[run-ocapn-test-suite] TIMEOUT after ${SUITE_TIMEOUT}s — this is a" >&2
  echo "                       budget problem, not a test failure. Raise" >&2
  echo "                       OCAPN_SUITE_TIMEOUT (and the job's" >&2
  echo "                       timeout-minutes) before reading the counts." >&2
  GATE_OK=0
elif [ "$SUITE_EXIT" -ne 0 ]; then
  echo "[run-ocapn-test-suite] runner exited $SUITE_EXIT" >&2
  GATE_OK=0
fi
if [ "$N_FAIL" -ne 0 ] || [ "$N_ERROR" -ne 0 ]; then
  echo "[run-ocapn-test-suite] $N_FAIL failed, $N_ERROR errored" >&2
  GATE_OK=0
fi
if [ "$N_PASS" -lt "$EXPECTED_PASS" ]; then
  echo "[run-ocapn-test-suite] only $N_PASS passed, expected >= $EXPECTED_PASS" >&2
  GATE_OK=0
fi

if [ "$GATE_OK" -eq 1 ]; then
  echo "[run-ocapn-test-suite] gate met ($N_PASS passed, 0 failed, 0 errored)"
  exit 0
else
  echo "[run-ocapn-test-suite] GATE NOT MET" >&2
  exit 1
fi
