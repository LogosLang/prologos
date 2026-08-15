#!/usr/bin/env bash
#
# check-families.sh — do BOTH consumers give a capture the same ROLE?
#
# check-parity.sh proves they see the same CAPTURES.  Nothing compared what
# those captures RESOLVE TO, so one capture could be a constant in Emacs and a
# string in VS Code with every gate green.
#
# ⚠ This compares ROLE, never COLOUR.  Colour is per-editor and per-theme by
# design (captures.md); role is meaning, and meaning is shared.  See families.tsv.
set -euo pipefail
cd "$(dirname "$0")"
exec emacs -Q --batch -L ../../emacs -l ./check-families.el -f prologos-fam-check
