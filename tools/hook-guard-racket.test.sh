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

# ── DEFERRED 163: pkill/killall match by name or command line across EVERY
# session on the machine; Step 0's `pkill -f batch-worker.rkt` killed other
# sessions' suites. Only a parent-scoped pkill (-P <pid>) may name racket.
L163="DEFERRED 163"
echo "MUST DENY (machine-wide kill of racket / batch workers — DEFERRED 163):"
check "pkill -f racket"         'pkill -f racket' DENY "$L163"
check "pkill -f batch-worker"   'pkill -f batch-worker' DENY "$L163"
check "the old runner Step 0"   'pkill -f batch-worker.rkt' DENY "$L163"
check "pkill racket (by name)"  'pkill racket' DENY "$L163"
check "killall racket"          'killall racket' DENY "$L163"
check "killall -9 racket"       'killall -9 racket' DENY "$L163"
check "killall -m regex"        'killall -m "rack.*"' DENY "$L163"
check "pkill -9 -f racket"      'pkill -9 -f racket' DENY "$L163"
check "pkill -KILL -f"          'cd /tmp && pkill -KILL -f batch-worker' DENY "$L163"
check "clustered -fi, -i regex" 'pkill -fi "RACK.T"' DENY "$L163"
check "pkill -x racket"         'pkill -x racket' DENY "$L163"
check "the runner by name"      'pkill -f run-affected-tests' DENY "$L163"
check "racket.*runner regex"    'pkill -f "racket.*run-affected-tests"' DENY "$L163"
check "regex that hits racket"  'pkill -f "rack.t"' DENY "$L163"
check "any .rkt"                "pkill -f '\\.rkt'" DENY "$L163"
check "every prologos process"  'pkill -f prologos' DENY "$L163"
check "another checkout, abs"   'pkill -f /Users/x/prologos/.claude/worktrees/par4-p0/racket/prologos/tools/batch-worker.rkt' DENY "$L163"
check "empty pattern = all"     'pkill -f ""' DENY "$L163"
check "through sudo"            'sudo pkill -f racket' DENY "$L163"
check "through timeout"         'timeout -k 5 10 pkill -f batch-worker' DENY "$L163"
check "after ;"                 'sleep 1; pkill -f racket || true' DENY "$L163"
# A pgrep whose output can reach a kill IS a pkill with the same arguments. Judged by
# co-occurrence in one command text (pipe, $(…), backticks, a variable, a temp file).
check "kill \$(pgrep -f)"        'kill $(pgrep -f racket)' DENY "$L163"
check "kill \`pgrep\`"           'kill `pgrep -f batch-worker`' DENY "$L163"
check "pgrep | xargs kill"      'pgrep -f batch-worker.rkt | xargs kill' DENY "$L163"
check "pgrep | xargs kill -9"   'pgrep -f racket | xargs kill -9' DENY "$L163"
check "pgrep by NAME"           'kill -9 $(pgrep racket)' DENY "$L163"
check "quoted \$(pgrep)"         'kill "$(pgrep -f run-affected-tests)"' DENY "$L163"
check "via a variable"          'p=$(pgrep -f batch-worker); kill $p' DENY "$L163"
check "via a file"              'pgrep -f racket > /tmp/p; xargs kill < /tmp/p' DENY "$L163"
check "ps | grep | awk | kill"  "ps aux | grep batch-worker | awk '{print \$2}' | xargs kill" DENY "$L163"
check "ps | grep -i | kill -9"  "ps -axo pid,command | grep -i RACKET | awk '{print \$1}' | xargs kill -9" DENY "$L163"
check "pgrep -v = all but"      'pgrep -v -f Safari | xargs kill' DENY "$L163"
check "pkill -v = all but"      'pkill -v Safari' DENY "$L163"
check "kill -9 -1 = every proc" 'kill -9 -1' DENY "$L163"
check "kill -- -1"              'kill -- -1' DENY "$L163"
check "kill -s KILL -1"         'kill -s KILL -1' DENY "$L163"
check "quoted \$(pkill)"         'echo "$(pkill -f racket)"' DENY "$L163"
check "quoted \`pkill\`"         'echo "`pkill -f racket`"' DENY "$L163"

echo "MUST ALLOW (parent-scoped kills, unrelated kills, read-only process queries):"
check "orphans of THIS checkout" 'pkill -P 1 -f /Users/x/prologos/racket/prologos/tools/batch-worker.rkt' ALLOW
check "parent-scoped"           'pkill -P 12345 -f racket' ALLOW
check "parent-scoped, attached" 'pkill -P12345 racket' ALLOW
check "parent-scoped, long opt" 'pkill --parent 12345 -f batch-worker' ALLOW
check "unrelated pkill -f"      'pkill -f "sleep 999"' ALLOW
check "unrelated pkill"         'pkill caffeinate' ALLOW
check "unrelated pkill python"  'pkill -9 -f my-probe.py' ALLOW
check "unrelated killall"       'killall Safari' ALLOW
check "pgrep is read-only"      'pgrep -f racket' ALLOW
check "pgrep -fl batch-worker"  'pgrep -fl batch-worker.rkt' ALLOW
check "kill one pid"            'kill 12345' ALLOW
check "-x: exact name, not racket" 'pkill -x rack' ALLOW
check "ps | grep"               'ps -axo pid,ppid,command | grep batch-worker' ALLOW
check "grep mentions pkill"     'grep -n "pkill -f batch-worker" racket/prologos/tools/run-affected-tests.rkt' ALLOW
check "echo mentions pkill"     'echo pkill -f racket' ALLOW
check "pgrep, parent-scoped"    'kill $(pgrep -P 4242 -f batch-worker)' ALLOW
check "pgrep -P | xargs kill"   'pgrep -P 4242 -f batch-worker | xargs kill' ALLOW
check "pgrep unrelated + kill"  'kill $(pgrep -f Safari)' ALLOW
check "kill a pid file"         'kill $(cat runner.pid)' ALLOW
check "ps | grep, no kill"      'ps aux | grep racket' ALLOW
check "ps | grep -v, unrelated" "ps aux | grep -v grep | grep Safari | awk '{print \$2}' | xargs kill" ALLOW
check "ps | grep -v racket"     "ps aux | grep -v racket | grep Safari | awk '{print \$2}' | xargs kill" ALLOW
check "grep a FILE, kill a pid" 'grep -c racket build.log; kill 12345' ALLOW
check "kill -1 PID = SIGHUP"    'kill -1 12345' ALLOW
check "kill -HUP PID"           'kill -HUP 12345' ALLOW
check "single-quoted is text"   "git commit -m 'never: kill \$(pgrep -f racket)'" ALLOW
check "escaped \\\$ is text"      'git commit -m "never: kill \$(pgrep -f racket)"' ALLOW
check "quoted \$(…) unrelated"   'echo "$(date) $(pgrep -f racket | wc -l) racket procs"' ALLOW

# The rows above count ANY output as a deny. Both harnesses read different fields:
# Claude Code reads hookSpecificOutput.permissionDecision; Hermes's shell-hook bridge
# (agent/shell_hooks.py _parse_pre_tool_call) blocks only on a top-level
# "decision": "block" and shows "reason". A deny that one harness cannot read is an allow.
echo "DENY IS READ BY BOTH HARNESSES:"
dialect() { # dialect "<label>" "<payload>" "<jq predicate on the output>"
  out=$(printf '%s' "$2" | "$G")
  if [ -n "$out" ] && jq -e "$3" >/dev/null 2>&1 <<<"$out"; then
    printf '  ok   %s\n' "$1"
  else
    printf '  FAIL %s (out=%s)\n' "$1" "${out:0:160}"; fails=$((fails+1))
  fi
}
cc='{"tool_name":"Bash","tool_input":{"command":"raco make driver.rkt"}}'
dialect "Claude Code: permissionDecision deny"  "$cc" '.hookSpecificOutput.permissionDecision == "deny"'
dialect "Hermes: decision block + reason"       "$cc" '.decision == "block" and (.reason | test("PLT_CS_COMPILE_LIMIT"))'
# Hermes sends tool_name "terminal" with the same tool_input.command shape.
hm='{"hook_event_name":"pre_tool_call","tool_name":"terminal","tool_input":{"command":"pkill -f batch-worker.rkt"},"session_id":"t","cwd":"/tmp"}'
dialect "Hermes terminal payload is guarded"    "$hm" '.decision == "block"'
dialect "Hermes payload, compile rule"          '{"hook_event_name":"pre_tool_call","tool_name":"terminal","tool_input":{"command":"raco make driver.rkt"}}' '.decision == "block"'
out=$(printf '%s' '{"hook_event_name":"pre_tool_call","tool_name":"terminal","tool_input":{"command":"PLT_CS_COMPILE_LIMIT=1000000 raco make driver.rkt"}}' | "$G")
if [ -z "$out" ]; then echo "  ok   Hermes payload, compliant compile allowed"; else echo "  FAIL Hermes payload, compliant compile allowed"; fails=$((fails+1)); fi
out=$(printf '%s' '{"hook_event_name":"pre_tool_call","tool_name":"read_file","tool_input":{"path":"raco make"}}' | "$G")
if [ -z "$out" ]; then echo "  ok   other Hermes tools pass through"; else echo "  FAIL other Hermes tools pass through"; fails=$((fails+1)); fi
# The guard is registered ONCE (user level), so its hint cannot name the script's own
# checkout; it names the shell's, at run time. And it must allow what it suggests.
out=$(printf '%s' '{"tool_name":"terminal","tool_input":{"command":"pkill -f batch-worker.rkt"}}' | "$G")
if jq -e '.reason | contains("$(git rev-parse --show-toplevel)/racket/prologos/tools/batch-worker.rkt")' >/dev/null 2>&1 <<<"$out"; then
  echo "  ok   orphan hint names the shell's checkout, not the guard's"
else echo "  FAIL orphan hint names the shell's checkout, not the guard's"; fails=$((fails+1)); fi
hint=$(jq -r '.reason' <<<"$out" | grep -E '^ +pkill -P 1 -f ' | sed 's/^ *//')
check "the guard allows its own orphan hint" "$hint" ALLOW

echo
if [ "$fails" -eq 0 ]; then echo "all rows pass"; else echo "FAILURES: $fails"; fi
exit "$fails"
