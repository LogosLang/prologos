#!/usr/bin/env bash
#
# check-vocabulary.sh — EHP D2 (option E) contract gate.
#
# Asserts, in BOTH directions:
#   →  every capture highlights.scm emits is documented in queries/captures.md
#      and resolves in every consumer's mapping
#   ←  every mapping entry is emitted, or is a root of something emitted
#
# Deliberate exceptions live in known-gaps.tsv, one row each, with a reason.
set -euo pipefail
cd "$(dirname "$0")"
exec emacs -Q --batch -L ../../emacs -l ./check-vocabulary.el -f prologos-vocab-check
