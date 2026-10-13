#!/bin/bash
# mut-dump.sh — mutation check for tools/pnet-dump.rkt and its tests. Each mutation must turn a test RED;
# the file is restored from a pristine copy after each, and a final green run proves the restore.
set -u
cd "$1"   # racket/prologos of the fasl worktree
RK="/Applications/Racket v9.3/bin/racket"; RACO="/Applications/Racket v9.3/bin/raco"
T="--tests tests/test-pnet-dump.rkt --tests tests/test-pnet-header.rkt"
S=$(mktemp -d)
cp tools/pnet-dump.rkt $S/tool.orig; cp pnet-serialize.rkt $S/ser.orig
run() { timeout -k 10 300 "$RK" tools/run-affected-tests.rkt --no-record $T 2>&1 | grep -E '^[0-9]+ tests in'; }
mut() { # name file perl-expr
  local f=$2
  perl -0pi -e "$3" "$f"
  if cmp -s "$f" "$S/$( [ "$f" = pnet-serialize.rkt ] && echo ser || echo tool ).orig"; then echo "MUTATION DID NOT APPLY: $1"; return; fi
  PLT_CS_COMPILE_LIMIT=1000000 timeout -k 10 900 "$RACO" make -j 8 tools/pnet-dump.rkt driver.rkt tools/batch-worker.rkt tests/test-support.rkt >/dev/null 2>&1
  echo "$1 -> $(run)"
  cp "$S/$( [ "$f" = pnet-serialize.rkt ] && echo ser || echo tool ).orig" "$f"
}
mut "M1 fasl body read as text"         tools/pnet-dump.rkt 's/\(if fasl\?\n              \(read-pnet-body in\)/(if #f\n              (read-pnet-body in)/'
mut "M2 usage errors exit 1, not 64"    tools/pnet-dump.rkt 's/\(exit EXIT-USAGE\)\)/(exit 1))/'
mut "M3 canonical form = identity"      tools/pnet-dump.rkt 's/\(define \(pnet-canonical v\)\n  \(cond/(define (pnet-canonical v)\n  (cond [#t v]/'
mut "M4 verdict always fresh"           tools/pnet-dump.rkt 's/\(define \(verdict-line pf ns\)\n/(define (verdict-line pf ns) "fresh: a load will use this cache")\n(define (verdict-line-unused pf ns)\n/'
mut "M5 slot names lose one"            pnet-serialize.rkt 's/ user-operators user-precedence-groups\)\)/ user-operators))/'
PLT_CS_COMPILE_LIMIT=1000000 timeout -k 10 900 "$RACO" make -j 8 tools/pnet-dump.rkt driver.rkt tools/batch-worker.rkt tests/test-support.rkt >/dev/null 2>&1
cmp tools/pnet-dump.rkt $S/tool.orig && cmp pnet-serialize.rkt $S/ser.orig && echo "restored: both files byte-identical to the originals"
echo "after restore -> $(run)"
rm -rf "$S"
