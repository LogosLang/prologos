#!/usr/bin/env bash
#
# check-regexps.sh — EHP P5: the #match? dialect gate.
#
# Every `#match?' regex in the SHARED highlights.scm must be honourable by BOTH
# consumers.  Emacs evaluates #match? in EMACS regexp syntax (where ( ) | are
# literal); VS Code gets PCRE.  A pattern only one side can honour is a
# SILENTLY DEAD rule.
#
# The gate calls prologos-ts--translate-regexp rather than carrying its own
# notion of the translatable subset — one authority, so the two cannot drift.
set -euo pipefail
cd "$(dirname "$0")"
exec emacs -Q --batch -L ../../emacs -l ./check-regexps.el -f prologos-rx-check
