#!/usr/bin/env bash
#
# Decision table for hook-guard-racket.sh. Run it after ANY edit to the guard.
#
# It has already earned its place twice. It caught the guard missing a racket
# invoked THROUGH a wrapper (`gtimeout <N> racket foo.rkt`) — that shape matches
# neither the /racket-path form nor the command-position bare word, and it is
# the orphan's own shape minus the absolute path. And it caught a run where
# every ALLOW row "passed" only because the guard was not executable, i.e. the
# whole allow-side was green for the wrong reason.
#
# The ALLOW rows matter as much as the DENY rows: they are what keep `raco`, the
# suite runner, and `grep racket` working. A guard that over-denies is not
# harmless.
#
# ⚠ SELF-REFERENCE HAZARD, learned the hard way: the guard inspects the raw
# command string, so a shell command that merely CONTAINS one of these example
# strings (a heredoc documenting the pattern, say) is itself blocked. Create
# files with an editor/Write, not with a heredoc quoting these examples.
#
set -uo pipefail

G="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hook-guard-racket.sh"
fails=0

check() { # check "<label>" "<command>" ALLOW|DENY
  out=$(jq -nc --arg c "$2" '{tool_name:"Bash",tool_input:{command:$c}}' | "$G")
  got=ALLOW; [ -n "$out" ] && got=DENY
  if [ "$got" = "$3" ]; then
    printf '  ok   %-5s %s\n' "$got" "$1"
  else
    printf '  FAIL got=%-5s want=%-5s %s\n' "$got" "$3" "$1"; fails=$((fails+1))
  fi
}

echo "MUST DENY (unbounded compiler runs):"
check "bare racket script"    'racket foo.rkt' DENY
check "quoted abs path"       'PLT_CS_COMPILE_LIMIT=1000000 "/Applications/Racket v9.0/bin/racket" probe.rkt' DENY
check "racket -e one-liner"   '"/Applications/Racket v9.0/bin/racket" -e "(require 1)"' DENY
check "after cd &&"           'cd /tmp && racket runmany.rkt a.prologos b.prologos' DENY
check "THE ACTUAL ORPHAN"     'gtimeout 550 "/Applications/Racket v9.0/bin/racket" runmany-w.rkt corpus/a.prologos' DENY
check "wrapper, no -k"        'gtimeout 900 racket tools/foo.rkt' DENY
check "env prefix"            'env FOO=1 racket x.rkt' DENY
check "nohup"                 'nohup racket x.rkt &' DENY

echo "MUST ALLOW (legitimate work must not break):"
check "raco make"             'PLT_CS_COMPILE_LIMIT=1000000 "/Applications/Racket v9.0/bin/raco" make driver.rkt' ALLOW
check "suite runner"          'racket tools/run-affected-tests.rkt --all' ALLOW
check "bench-ab"              'racket tools/bench-ab.rkt --runs 10' ALLOW
check "scratch-run wrapper"   'tools/scratch-run.sh -t 60 probe.prologos' ALLOW
check "bounded, -k"           'gtimeout -k 30 300 "/Applications/Racket v9.0/bin/racket" x.rkt' ALLOW
check "bounded, --kill-after" 'gtimeout --kill-after=30 300 racket x.rkt' ALLOW
check "grep mentions racket"  'grep -rn racket tools/ | head' ALLOW
check "grep -c"               'grep -c racket /tmp/f' ALLOW
check "echo mentions racket"  'echo "racket is slow"' ALLOW
check "ps | grep"             'ps -axo pid,command | grep racket' ALLOW
check "Racket dir listing"    'ls "/Applications/Racket v9.0/bin/"' ALLOW
check "unrelated"             'git status --short' ALLOW

echo
if [ "$fails" -eq 0 ]; then echo "all rows pass"; else echo "FAILURES: $fails"; fi
exit "$fails"
