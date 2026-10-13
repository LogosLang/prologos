#!/bin/bash
# mutate151.sh — mutation red-checks for DEFERRED 151(a) in the worktree.
# Each mutation: patch pnet-serialize.rkt, rebuild, run test-pnet-header.rkt, restore, cmp.
set -u
W=/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/per-process-152-151/racket/prologos
SC=/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/per-process-152-151
cd "$W" || exit 1
cp pnet-serialize.rkt "$SC/ps.good"
RACO="/Applications/Racket v9.3/bin/raco"
build_test() {
  PLT_CS_COMPILE_LIMIT=1000000 timeout -k 10 500 "$RACO" make -j 4 driver.rkt tests/test-pnet-header.rkt >/dev/null 2>&1 || { echo "BUILD FAILED"; return; }
  timeout -k 10 300 "$RACO" test tests/test-pnet-header.rkt 2>&1 | grep -E "tests? passed|test failures"
}
mutate() { # name python-old python-new
  echo "== mutation: $1"
  python3 - "$2" "$3" <<'EOF'
import sys
p='pnet-serialize.rkt'; s=open(p).read(); old,new=sys.argv[1],sys.argv[2]
assert s.count(old)==1, ("pattern count", s.count(old)); open(p,'w').write(s.replace(old,new))
EOF
  build_test
  cp "$SC/ps.good" pnet-serialize.rkt
  cmp pnet-serialize.rkt "$SC/ps.good" && echo "restored"
}
# M1: pnet-stale? parses the body too (the v10 cost, in v11 clothes)
mutate "stale-reads-body" \
"              (call-with-input-file pnet-path read-pnet-header))" \
"              (call-with-input-file pnet-path (lambda (in) (define h (read-pnet-header in)) (read in) h)))"
# M2: no prefix peek — read whatever the first datum is
mutate "no-prefix-peek" \
"  (and (bytes? pre)
       (bytes=? pre pnet-header-prefix)
       (let ([h (read in)])" \
"  (and #t
       (let ([h (read in)])"
# M3: version gate ignores the version
mutate "version-gate-off" \
"       (equal? (cadr h) PNET_VERSION)" \
"       #t"
echo "== restored build"
build_test
git -C "$W" diff --stat -- pnet-serialize.rkt
