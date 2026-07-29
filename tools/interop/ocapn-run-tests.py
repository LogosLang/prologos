#!/usr/bin/env python3
# ocapn-run-tests.py — selective runner for the upstream ocapn-test-suite.
#
# The upstream `test_runner.py` can only run a whole test MODULE: its
# `CapTPTestLoader` injects the netlayer at the TestCase-CLASS level, so
# `loadTestsFromName` against an individual method fails. It also imports
# the Tor onion netlayer unconditionally, which does not build in our
# containers.
#
# This runner builds a TestSuite from an explicit allow-list of the
# upstream tests the current implementation targets. Extend SELECTED
# as new phases land.
#
# The cost of an allow-list is that a test ADDED upstream is silently not
# run. `check_allow_list_drift` closes that: it enumerates the `test_*`
# methods of every targeted class, and every test-bearing class of every
# targeted module, and reports anything SELECTED does not name. Drift is
# reported up front and turned into a non-zero exit at the END, so the
# conformance signal is still produced on the run that discovers it.
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
# As of Phase 59b this is every `test_*` method of every test-bearing
# class in the six modules named below; the per-entry comments record
# what each group needed. The drift check below is what keeps that true.
SELECTED = [
    ("tests.op_start_session", "OpStartSessionTest", [
        "test_captp_remote_version",
        "test_start_session_with_invalid_version",
        "test_start_session_with_invalid_signature",
        # Crossed hellos (Phase 59b part 12). Sort the two side-ids and abort
        # the connection dialled by whichever sorts first -- a rule both peers
        # evaluate independently and agree on with no extra round trip.
        "test_crossed_hellos_mitigation_aborts_inbound",
        "test_crossed_hellos_mitigation_outbound_aborts",
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
    # Third-party handoff, RECEIVER side (Phase 59b part 13). A gifter hands us
    # a signed handoff-give; we dial the exporter it names and withdraw the
    # gift there with a handoff-receive signed by our own session key.
    ("tests.third_party_handoffs", "HandoffRemoteAsReciever", [
        "test_valid_handoff_without_prior_connection",
        "test_valid_handoff_with_prior_connection",
    ]),
    # Third-party handoff, GIFTER side (Phase 59b part 14). Both sessions are
    # ones the peer opened, so the enlivener REUSES the open connection whose
    # peer location the sturdyref names rather than dialling a new one.
    ("tests.third_party_handoffs", "HandoffRemoteAsGifter", [
        "test_provides_valid_handoff_give",
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


def check_allow_list_drift():
    """Report upstream `test_*` methods that SELECTED does not name.

    Two levels: a method added to a class we already target, and a whole
    test-bearing class added to a module we already target. Returns a list
    of human-readable drift lines (empty when the allow-list is complete).
    """
    selected_methods = {}   # (module, class) -> set(method)
    for mod_name, cls_name, methods in SELECTED:
        selected_methods.setdefault((mod_name, cls_name), set()).update(methods)

    drift = []
    for mod_name in sorted({m for m, _c, _s in SELECTED}):
        mod = importlib.import_module(mod_name)
        for cls_name in sorted(dir(mod)):
            cls = getattr(mod, cls_name)
            if not (isinstance(cls, type) and issubclass(cls, unittest.TestCase)):
                continue
            # `dir(mod)` also sees classes the module merely imported
            # (CapTPTestCase, and any sibling test class). Only audit the
            # ones this module actually defines.
            if cls.__module__ != mod_name:
                continue
            # Only count methods the class itself defines: the shared
            # CapTPTestCase / HandoffTestCase bases are inherited by every
            # subclass and would otherwise be reported N times.
            upstream = {n for n in vars(cls) if n.startswith("test_")}
            if not upstream:
                continue
            known = selected_methods.get((mod_name, cls_name))
            if known is None:
                drift.append(
                    f"{mod_name}.{cls_name} is not in SELECTED at all "
                    f"({len(upstream)} test(s): {', '.join(sorted(upstream))})")
                continue
            for missing in sorted(upstream - known):
                drift.append(f"{mod_name}.{cls_name}.{missing} is not in SELECTED")
            for stale in sorted(known - upstream):
                drift.append(
                    f"{mod_name}.{cls_name}.{stale} is in SELECTED but no "
                    f"longer exists upstream")
    return drift


def main():
    if len(sys.argv) < 2:
        sys.stderr.write("usage: ocapn-run-tests.py <locator> [captp-version]\n")
        return 2
    locator = sys.argv[1]
    captp_version = sys.argv[2] if len(sys.argv) > 2 else "1.0"

    uri = OCapNPeer.from_uri(locator)
    netlayer = TestingOnlyTCPNetlayer(uri.hints.get("host"))
    runner = CapTPTestRunner(netlayer, uri, captp_version, verbosity=2)

    drift = check_allow_list_drift()
    if drift:
        sys.stderr.write(
            "ocapn-run-tests: ALLOW-LIST DRIFT — the upstream suite has\n"
            "moved and these tests are not being run. Add them to SELECTED\n"
            "(or remove them, if they are gone upstream) and raise\n"
            "EXPECTED_PASS in run-ocapn-test-suite.sh to match:\n")
        for line in drift:
            sys.stderr.write(f"  - {line}\n")
        sys.stderr.write("\n")
        sys.stderr.flush()

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
    if not result.wasSuccessful():
        return 1
    # Run the selected tests first so the conformance signal is still
    # produced, THEN fail on drift.
    return 3 if drift else 0


if __name__ == "__main__":
    sys.exit(main())
