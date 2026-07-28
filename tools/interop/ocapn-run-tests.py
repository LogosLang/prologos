#!/usr/bin/env python3
# ocapn-run-tests.py — selective runner for the upstream ocapn-test-suite.
#
# The upstream `test_runner.py` can only run a whole test MODULE: its
# `CapTPTestLoader` injects the netlayer at the TestCase-CLASS level, so
# `loadTestsFromName` against an individual method fails. Several
# upstream tests (crossed-hellos, op:deliver, op:gc, op:listen, ...)
# need a swiss-num object registry and outbound connections that the
# Prologos OCapN implementation does not provide yet (Phase 59+). Left
# in the run they block on the 120s socket timeout and starve the
# tests we DO pass of the CI time budget.
#
# This runner builds a TestSuite from an explicit allow-list of the
# upstream tests the current implementation targets. Extend SELECTED
# as new phases land.
#
# Usage: ocapn-run-tests.py <locator> [captp-version]
# Env:   OCAPN_TEST_SUITE_DIR — path to the cloned ocapn-test-suite
#                               (default: /tmp/ocapn-test-suite)

import importlib
import os
import sys
import unittest

SUITE_DIR = os.environ.get("OCAPN_TEST_SUITE_DIR", "/tmp/ocapn-test-suite")
sys.path.insert(0, SUITE_DIR)
os.chdir(SUITE_DIR)

from utils.ocapn_uris import OCapNPeer
from utils.test_suite import CapTPTestRunner
from netlayers.testing_only_tcp import TestingOnlyTCPNetlayer

# (module, class, [method, ...]) — the upstream tests the current
# Prologos OCapN implementation targets.
#
# Phase 58.c/58.d: the test server validates an inbound op:start-session
# and aborts on an unsupported CapTP version or an invalid location
# signature, and on an op:abort sent before the handshake completes.
# The crossed-hellos / op:deliver / op:gc / op:listen tests need the
# server to drive captp-core with a swiss-num object registry (Phase 59+).
SELECTED = [
    ("tests.op_start_session", "OpStartSessionTest", [
        "test_captp_remote_version",
        "test_start_session_with_invalid_version",
        "test_start_session_with_invalid_signature",
    ]),
    ("tests.op_deliver", "OpDeliverTest", [
        "test_deliver_with_resolver",
        # Greeter (Phase 59b part 3). Was excluded while it HUNG rather than
        # failed, burning the runner's budget. Two bugs kept it silent, both
        # on the "no answer position, no resolve-me" path:
        #   1. a descriptor's table position arrives as a Syrup positive
        #      INTEGER (`1+`), so it decodes to syrup-int; nat-payload only
        #      accepted syrup-nat and returned none for its own target;
        #   2. the greeter's reply target is the PEER's export position,
        #      which collides with our local actor ids — eff-send-only routed
        #      it back into the local actor table instead of the wire.
        "test_send_deliver_no_answer_or_response",
        # Promise pipelining (Phase 59b part 10). The Car Factory chain:
        # builder -> factory -> car -> string, every link answering with a NEW
        # OBJECT, and the peer never waiting for a link to resolve before
        # addressing the next. Needs `eff-spawn` so a behaviour can name the
        # object it is about to create in its own return value.
        "test_deliver_promise_pipeline",
        "test_promise_pipeline_with_break",
    ]),
    ("tests.op_abort", "OpAbortTest", [
        "test_abort_before_setup",
    ]),
    # Third-party handoff, EXPORTER side (Phase 59b part 5). Both sessions are
    # the suite dialling us — the gifter and the receiver are different peers —
    # so this needs no outbound-connection capability, only a gift table that
    # outlives a single connection (ocapn-gift-ffi.rkt).
    #
    # The other three in this class each need one more distinct feature:
    # All four in this class now pass:
    #   valid_handoff            -> the base flow
    #   wait_deposit_gift        -> park a withdrawal until the deposit lands
    #   invalid_handoff_count    -> per-(session, side) handoff-count tracking
    #   invalid_signature        -> real Ed25519 verification of the receive
    ("tests.third_party_handoffs", "HandoffRemoteAsExporter", [
        "test_valid_handoff",
        "test_valid_handoff_wait_deposit_gift",
        "test_handoff_receive_invalid_handoff_count",
        "test_handoff_receive_invalid_signature",
    ]),
    # op:listen (Phase 59b part 4). Gated on the promise-resolver object
    # (swiss-num IokCxYmMj04nos2JN1TDoY1bT8dXh6Lr), which is now PRE-SEEDED
    # per connection rather than created on demand: every upstream test that
    # asks for a (vow, resolver) pair asks exactly once, on its own fresh
    # connection. That avoids needing a behaviour to allocate a promise and
    # spawn an actor mid-turn, which is what forces a step-behavior signature
    # change (still required for the Car Factory).
    # op:gc-exports (Phase 59b part 8). A deliver with no answer position and no
    # resolve-me has no reply channel, so every desc:import-object in its args
    # is garbage the moment the turn ends -- which is exactly the shape these
    # three send. test_gc_answer needs op:gc-answers for an ANSWER position and
    # is a separate mechanism.
    ("tests.op_gc", "OpGcExportsTest", [
        "test_gc_export_emitted_single_object",
        "test_gc_export_with_multiple_refrences",
        "test_gc_export_with_multiple_refrences_in_different_messages",
    ]),
    # op:gc-answers (Phase 59b part 9). The greeter's outbound send is now a
    # real question -- fresh promise + a beh-resolver actor exported as the
    # resolve-me -- so the peer can answer it, and once it settles the answer
    # entry is released.
    ("tests.op_gc", "OpGcAnswersTest", [
        "test_gc_answer",
    ]),
    ("tests.op_listen", "OpListenTest", [
        "test_op_listen_to_promise_and_fulfill",
        "test_op_listen_to_promise_and_break",
        "test_op_listen_already_has_answer",
    ]),
]


def main():
    if len(sys.argv) < 2:
        sys.stderr.write("usage: ocapn-run-tests.py <locator> [captp-version]\n")
        return 2
    locator = sys.argv[1]
    captp_version = sys.argv[2] if len(sys.argv) > 2 else "1.0"

    uri = OCapNPeer.from_uri(locator)
    netlayer = TestingOnlyTCPNetlayer(uri.hints.get("host"))
    runner = CapTPTestRunner(netlayer, uri, captp_version, verbosity=2)

    suite = unittest.TestSuite()
    selected_count = 0
    for mod_name, cls_name, methods in SELECTED:
        mod = importlib.import_module(mod_name)
        cls = getattr(mod, cls_name)
        for method in methods:
            suite.addTest(cls(netlayer, uri, captp_version, method))
            selected_count += 1

    print(f"ocapn-run-tests: running {selected_count} selected test(s) "
          f"against {locator}")
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
