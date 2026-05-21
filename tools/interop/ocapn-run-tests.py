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
# Phase 58.c: the test server validates an inbound op:start-session
# and aborts on an unsupported CapTP version. Signature validation
# (test_start_session_with_invalid_signature) is Phase 58.d; the
# crossed-hellos tests need Phase 59+.
SELECTED = [
    ("tests.op_start_session", "OpStartSessionTest", [
        "test_captp_remote_version",
        "test_start_session_with_invalid_version",
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
