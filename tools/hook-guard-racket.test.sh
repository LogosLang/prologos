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

check() { # check "<label>" "<command>" ALLOW|DENY ["<text the deny reason must contain>"]
  out=$(jq -nc --arg c "$2" '{tool_name:"Bash",tool_input:{command:$c}}' | "$G")
  got=ALLOW; [ -n "$out" ] && got=DENY
  # A DENY row that names its rule must be denied BY that rule: several shapes
  # (racket -l- raco make, say) are also refused by the unbounded-racket rule,
  # and a row that passes on the other rule's deny tests nothing.
  if [ "$got" = DENY ] && [ -n "${4:-}" ] && ! grep -qF -- "$4" <<<"$out"; then
    got="DENY(other rule)"
  fi
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
check "racket --version"      '"/Applications/Racket v9.0/bin/racket" --version' ALLOW
check "bare racket --version" 'racket --version' ALLOW
check "racket --help"         'racket --help' ALLOW
check "racket -h"             'racket -h' ALLOW
check "version then a RUN"    'racket --version && racket foo.rkt' DENY

# ── DEFERRED 159: a compile without PLT_CS_COMPILE_LIMIT builds the compiler's
# giant `match` functions INTERPRETED, silently. Every row names the rule, so a
# row that is refused by the unbounded-racket rule instead does not count.
L159="DEFERRED 159"
echo "MUST DENY (compile without PLT_CS_COMPILE_LIMIT — DEFERRED 159):"
check "bare raco make"          'raco make driver.rkt' DENY "$L159"
check "quoted 9.3 raco"         '"/Applications/Racket v9.3/bin/raco" make -j 4 driver.rkt lsp/server.rkt' DENY "$L159"
check "single-quoted raco"      "'/Applications/Racket v9.3/bin/raco' make driver.rkt" DENY "$L159"
check "homebrew raco (9.0!)"    '/opt/homebrew/bin/raco make driver.rkt' DENY "$L159"
check "cd && raco make"         'cd racket/prologos && raco make driver.rkt' DENY "$L159"
check "bounded, still no limit" 'timeout -k 10 500 "/Applications/Racket v9.3/bin/raco" make driver.rkt' DENY "$L159"
check "racket -l- raco make"    'timeout -k 10 300 racket -l- raco make driver.rkt' DENY "$L159"
check "bin/raco's own exec"     'timeout -k 10 300 "/Applications/Racket v9.3/bin/racket" -N raco -l- raco/main.rkt make x.rkt' DENY "$L159"
check "limit prefixes cd only"  'PLT_CS_COMPILE_LIMIT=1000000 cd racket/prologos && raco make driver.rkt' DENY "$L159"
check "unexported shell var"    'PLT_CS_COMPILE_LIMIT=1000000; raco make driver.rkt' DENY "$L159"
check "export AFTER the make"   'raco make driver.rkt; export PLT_CS_COMPILE_LIMIT=1000000' DENY "$L159"
check "the CS default value"    'PLT_CS_COMPILE_LIMIT=10000 raco make driver.rkt' DENY "$L159"
check "empty value"             'PLT_CS_COMPILE_LIMIT= raco make driver.rkt' DENY "$L159"
check "first of two unlimited"  'raco make a.rkt && PLT_CS_COMPILE_LIMIT=1000000 raco make b.rkt' DENY "$L159"
check "env -i clears it"        'export PLT_CS_COMPILE_LIMIT=1000000; env -i raco make driver.rkt' DENY "$L159"
check "xargs raco make"         'ls *.rkt | xargs -n 1 raco make' DENY "$L159"
check "find -exec raco make"    'find . -name "*.rkt" -exec raco make {} \;' DENY "$L159"
check "bash -c"                 'bash -c "cd racket/prologos && raco make driver.rkt"' DENY "$L159"
check "for loop"                'for f in a.rkt b.rkt; do raco make "$f"; done' DENY "$L159"
check "subshell"                '(cd racket/prologos; raco make driver.rkt)' DENY "$L159"
check "piped to tail"           'raco make driver.rkt 2>&1 | tail -5' DENY "$L159"
check "raco setup"              'raco setup prologos' DENY "$L159"
check "raco pkg update"         'raco pkg update --link racket' DENY "$L159"
check "raco pkg install"        'raco pkg install prologos-dev' DENY "$L159"
check "raco test --make"        'raco test --make tests/test-foo.rkt' DENY "$L159"
check "raco test -y"            'raco test -y tests/test-foo.rkt' DENY "$L159"

echo "MUST ALLOW (the limit reaches the compile, or nothing compiles):"
check "inline + timeout -k"     'PLT_CS_COMPILE_LIMIT=1000000 timeout -k 10 500 "/Applications/Racket v9.3/bin/raco" make -j 4 driver.rkt lsp/server.rkt' ALLOW
check "cd && inline"            'cd racket/prologos && PLT_CS_COMPILE_LIMIT=1000000 raco make driver.rkt' ALLOW
check "env VAR=… raco"          'env PLT_CS_COMPILE_LIMIT=1000000 raco make driver.rkt' ALLOW
check "timeout env VAR=… raco"  'timeout -k 10 500 env PLT_CS_COMPILE_LIMIT=1000000 raco make driver.rkt' ALLOW
check "export first, &&"        'export PLT_CS_COMPILE_LIMIT=1000000 && cd racket/prologos && raco make driver.rkt' ALLOW
check "export first, two makes" 'export PLT_CS_COMPILE_LIMIT=1000000; raco make a.rkt; raco make b.rkt' ALLOW
check "assign, then export it"  'PLT_CS_COMPILE_LIMIT=1000000; export PLT_CS_COMPILE_LIMIT; raco make driver.rkt' ALLOW
check "quoted value"            'PLT_CS_COMPILE_LIMIT="1000000" raco make driver.rkt' ALLOW
check "larger value"            'PLT_CS_COMPILE_LIMIT=50000000 raco make driver.rkt' ALLOW
check "racket -l- raco, limit"  'PLT_CS_COMPILE_LIMIT=1000000 timeout -k 10 300 racket -l- raco make driver.rkt' ALLOW
check "limit inherited by bash" 'PLT_CS_COMPILE_LIMIT=1000000 bash -c "raco make driver.rkt"' ALLOW
check "limit inherited by xargs" 'ls *.rkt | PLT_CS_COMPILE_LIMIT=1000000 xargs -n 1 raco make' ALLOW
check "raco test (no --make)"   'raco test tests/test-foo.rkt' ALLOW
check "raco pkg show"           '"/Applications/Racket v9.3/bin/raco" pkg show -a' ALLOW
check "raco expand"             'raco expand foo.rkt' ALLOW
check "GNU make"                'make -C docs html' ALLOW
check "grep mentions raco make" 'grep -rn "raco make" .claude/rules/' ALLOW
check "commit msg mentions it"  'git commit -m "raco make without the limit"' ALLOW
check "echo raco make"          'echo raco make driver.rkt' ALLOW
check "comment mentions it"     'git status  # then raco make driver.rkt' ALLOW

echo
if [ "$fails" -eq 0 ]; then echo "all rows pass"; else echo "FAILURES: $fails"; fi
exit "$fails"
