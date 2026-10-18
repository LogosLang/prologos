#!/usr/bin/env bash
#
# hook-guard-racket.sh — PreToolUse/Bash guard: refuse to run the Racket binary
# without a wall-clock bound.
#
# THE LAST LAYER. `tools/scratch-run.sh` makes the runaway shape unrepresentable
# for anyone who uses it; this makes NOT using it impossible. It is enforced by
# the harness rather than by the model, which is the point — the 2026-08-08
# incident (three orphaned harnesses, ~14 GB, one at 12.6 GB, still running 45-75
# minutes after their workflow finished) was caused by SUBAGENTS, and a subagent
# cannot be relied on to have read a rule. A PreToolUse hook applies to their
# Bash calls too.
#
# Reads the hook payload on stdin, decides, and prints a PreToolUse decision.
# Silence (exit 0, no output) = allow.
#
# DENIES:
#   · a command that invokes the racket binary with no timeout/gtimeout -k;
#   · a COMPILE — raco make|setup, raco pkg install|update, raco test --make,
#     however raco is spelled (bare, any path, racket -l- raco) — whose
#     environment lacks PLT_CS_COMPILE_LIMIT >= 1000000 (DEFERRED 159; the
#     environment model is described at guard_analyse below);
#   · a pkill/killall whose pattern or name can reach a racket process (by
#     name, by command line, or as a regex) and is not parent-scoped with
#     pkill -P <pid> — these act machine-wide, across sessions (DEFERRED 163).
# ALLOWS:
#   · anything not invoking racket at all (including `raco`, which is bounded
#     compilation — and whose path contains no "/racket" token anyway), as
#     long as a compile carries the limit
#   · tools/scratch-run.sh                (bounds it itself)
#   · run-affected-tests.rkt, bench-ab.rkt (own their workers and timeouts)
#   · any command already wrapped in `timeout -k` / `gtimeout -k`
#
# ⚠ `timeout` WITHOUT `-k` IS NOT ACCEPTED, deliberately. The orphan that
# started all this carried `timeout 550` and was alive at 1h18m: bare timeout
# sends SIGTERM, and Racket CS in a tight allocation/GC loop never services it.
# Accepting bare `timeout` would re-open the exact hole this closes.
#
set -uo pipefail

payload="$(cat)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0

deny() {
  # One object, read by both harnesses (disjoint keys; each ignores the other's):
  #   Claude Code  — hookSpecificOutput.permissionDecision
  #   Hermes       — top-level decision:"block" + reason (agent/shell_hooks.py,
  #                  _parse_pre_tool_call). Without these Hermes treats the deny as an allow.
  jq -nc --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    },
    decision: "block",
    reason: $r
  }'
  exit 0
}

# ════════════════════════════════════════════════════════════════════════════
# COMMAND-SHAPE RULES (DEFERRED 159, 163). These need to know WHICH word of a simple
# command is the command, and which environment it runs with, so they work on a
# tokenized command rather than on regexes over the raw string:
#
#   · split at unquoted ; & && | || ( ) ` and newlines; drop # comments; honour
#     '…', "…" and backslash escapes (a quoted "raco make" is one word, so
#     `git commit -m "raco make …"` and `grep "raco make"` are not compiles);
#   · per simple command: skip shell keywords ({ ! do then …), take leading
#     VAR=… assignments as that command's environment, then see THROUGH
#     executors (timeout, env, nice, nohup, time, exec, xargs, sudo, …) to the
#     command they run; `find … -exec CMD` and `bash|sh|zsh -c 'CMD'` are
#     analysed as commands of their own, with the environment they inherit.
#   · environment model for PLT_CS_COMPILE_LIMIT, in order of the command text:
#     `VAR=v cmd` and `env VAR=v cmd` set it for cmd only; `export VAR=v` (or
#     `VAR=v; export VAR`) sets it for every LATER command; a bare `VAR=v;` is a
#     shell variable that a child does NOT see; `env -i` clears it; `unset`
#     removes it. An export from an EARLIER Bash call is invisible here — the
#     payload is only this command's text — so the message says to inline it.
#
# The analyser prints one finding per line; empty output = nothing to refuse.
#   DENY159 <TAB> <offending simple command>
#   PKILL|KILLALL <TAB> <flags> <TAB> p:<pattern> <TAB> <offending command>
guard_analyse() {
  awk '
function base(s) { sub(/.*\//, "", s); return s }
function is_assign(t) { return t ~ /^[A-Za-z_][A-Za-z0-9_]*=/ }
function aname(t) { return substr(t, 1, index(t, "=") - 1) }
function aval(t) { return substr(t, index(t, "=") + 1) }
function limit_ok(set, val) { return set && val ~ /^[0-9]+$/ && val + 0 >= 1000000 }
function flush_word() {
  if (have) { NT++; T[NSEG, NT] = word }
  word = ""; have = 0
}
function end_seg() {
  flush_word()
  if (NT > 0) { SEGNT[NSEG] = NT; NSEG++ }
  NT = 0
}
function match_paren(str, k,    n, d, c) {   # str[k..] follows "$(": index of its ")"
  n = length(str); d = 1
  for (; k <= n; k++) {
    c = substr(str, k, 1)
    if (c == "(") d++
    else if (c == ")" && --d == 0) return k
  }
  return n + 1
}
function tokenize(str,    n, i, c, nc, inS, inD, j) {
  NSEG = 1; NT = 0; word = ""; have = 0; inS = 0; inD = 0
  n = length(str)
  for (i = 1; i <= n; i++) {
    c = substr(str, i, 1)
    if (inS) { if (c == "\047") inS = 0; else word = word c; continue }
    if (inD) {
      if (c == "\\" && i < n) {
        nc = substr(str, i + 1, 1)
        if (nc == "\"" || nc == "\\" || nc == "$" || nc == "`") { word = word nc; i++; continue }
        if (nc == "\n") { i++; continue }
      }
      # A command substitution inside "…" RUNS: analyse it as a command of its own
      # (outside quotes the ( ) ` separators already make it a segment).
      if (c == "$" && substr(str, i + 1, 1) == "(") {
        j = match_paren(str, i + 2)
        enqueue(substr(str, i + 2, j - i - 2), EXP_SET, EXP_VAL)
        word = word substr(str, i, j - i + 1); i = j; continue
      }
      if (c == "`" && (j = index(substr(str, i + 1), "`"))) {
        enqueue(substr(str, i + 1, j - 1), EXP_SET, EXP_VAL)
        word = word substr(str, i, j + 1); i += j; continue
      }
      if (c == "\"") inD = 0; else word = word c
      continue
    }
    if (c == "\\") {
      if (i < n) { nc = substr(str, i + 1, 1); i++; if (nc != "\n") { word = word nc; have = 1 } }
      continue
    }
    if (c == "\047") { inS = 1; have = 1; continue }
    if (c == "\"") { inD = 1; have = 1; continue }
    if (c == " " || c == "\t") { flush_word(); continue }
    if (c == "#" && !have) { while (i < n && substr(str, i + 1, 1) != "\n") i++; continue }
    if (c == "&") {
      # 2>&1, >&2, &>file are redirections, not separators
      if ((have && word ~ /[<>]$/) || substr(str, i + 1, 1) == ">") { word = word c; have = 1; continue }
      end_seg(); continue
    }
    if (c == ";" || c == "|" || c == "\n" || c == "(" || c == ")" || c == "`") { end_seg(); continue }
    word = word c; have = 1
  }
  end_seg()
}
function seg_text(s, a, b,    j, out) {
  out = ""
  for (j = a; j <= b; j++) out = out (j > a ? " " : "") T[s, j]
  gsub(/[\t\n]/, " ", out)
  return out
}
function enqueue(str, set, val) { QN++; QS[QN] = str; QSET[QN] = set; QVAL[QN] = val }

# One simple command: tokens T[s, i..e], run with the limit state (set, val).
function analyse_cmd(s, i, e, set, val,    t, b, j, k, sub1, c1, compiling, flags, scoped, endopt, pats, ch, n, sig, inv, havepat) {
  while (i <= e) {
    t = T[s, i]; b = base(t)
    if (b in EXEC) {
      i++
      if (b == "env" || b == "sudo") {
        while (i <= e) {
          t = T[s, i]
          if (t == "-i" || t == "-" || t == "--ignore-environment") { set = 0; i++; continue }
          if (t ~ /^-/) { if (index(ARGOPT[b], " " t " ")) i++; i++; continue }
          if (is_assign(t)) { if (aname(t) == LIM) { set = 1; val = aval(t) }; i++; continue }
          break
        }
      } else {
        while (i <= e && T[s, i] ~ /^-./) { if (index(ARGOPT[b], " " T[s, i] " ")) i++; i++ }
        if ((b == "timeout" || b == "gtimeout") && i <= e) i++      # the DURATION
      }
      continue
    }
    if (b == "find") {
      for (j = i + 1; j <= e; j++)
        if (T[s, j] == "-exec" || T[s, j] == "-execdir" || T[s, j] == "-ok" || T[s, j] == "-okdir") {
          for (k = j + 1; k <= e && T[s, k] != ";" && T[s, k] != "+"; k++) ;
          analyse_cmd(s, j + 1, k - 1, set, val)
          j = k
        }
      return
    }
    if (b in SHELLS) {
      for (j = i + 1; j < e; j++) {
        if (T[s, j] ~ /^-[A-Za-z]*c[A-Za-z]*$/) { enqueue(T[s, j + 1], set, val); return }
        if (T[s, j] !~ /^-/) break
      }
      return
    }
    if (b == "eval") { enqueue(seg_text(s, i + 1, e), set, val); return }
    break
  }
  if (i > e) return

  # ── DEFERRED 159: raco make|setup, raco pkg install|update, raco test --make,
  # spelled as raco (any path) or as racket -l-/-l/--lib raco[/main.rkt].
  sub1 = 0
  if (b == "raco") sub1 = i + 1
  else if (b == "racket")
    for (j = i + 1; j < e; j++)
      if ((T[s, j] == "-l-" || T[s, j] == "-l" || T[s, j] == "--lib") && T[s, j + 1] ~ /^raco(\/main(\.rkt)?)?$/) { sub1 = j + 2; break }
  if (sub1 && sub1 <= e) {
    compiling = 0; c1 = T[s, sub1]
    if (c1 == "make" || c1 == "setup") compiling = 1
    else if (c1 == "pkg" && sub1 < e && (T[s, sub1 + 1] == "install" || T[s, sub1 + 1] == "update")) compiling = 1
    else if (c1 == "test") { for (j = sub1 + 1; j <= e; j++) if (T[s, j] == "-y" || T[s, j] == "--make") compiling = 1 }
    if (compiling && !limit_ok(set, val)) print "DENY159\t" seg_text(s, i, e)
  }

  # ── DEFERRED 163: pkill / killall / pgrep. Emit each pattern of a pkill or pgrep
  # that is NOT parent-scoped (-P/--parent), and each name of a killall (which
  # cannot be); the shell side decides whether it can match a racket process. A
  # PGREP finding only counts when the same command text also runs a kill (KILL).
  #   PKILL|KILLALL|PGREP <TAB> flags <TAB> p:<pattern> <TAB> <offending command>
  # flags: f = full command line, i = ignore case, x = exact, r = regex (killall),
  #        v = inverted (every process that does NOT match)
  if (b == "pkill" || b == "killall" || b == "pgrep") {
    flags = "-"; scoped = 0; endopt = 0; pats = ""
    for (j = i + 1; j <= e; j++) {
      t = T[s, j]
      if (endopt || t !~ /^-/ || t == "-") { pats = pats SUBSEP t; continue }
      if (t == "--") { endopt = 1; continue }
      if (t ~ /^-[0-9]+$/ || t ~ /^-(SIG)?[A-Z][A-Z]+[0-9]*$/) continue   # -9, -KILL, -USR1 (not -P123)
      if (t ~ /^--/) {
        if (t ~ /^--parent(=|$)/) scoped = 1
        else if (t == "--full") flags = flags "f"
        else if (t == "--ignore-case") flags = flags "i"
        else if (t == "--exact") flags = flags "x"
        else if (t == "--regexp") flags = flags "r"
        else if (t == "--inverse") flags = flags "v"
        if (t !~ /=/ && index(LONGARG, " " t " ")) j++
        continue
      }
      for (k = 2; k <= length(t); k++) {
        ch = substr(t, k, 1)
        if (index(SHORTARG[b], ch)) {               # option with an argument
          if (b != "killall" && ch == "P") scoped = 1
          if (b == "killall" && ch == "c") { if (k < length(t)) pats = pats SUBSEP substr(t, k + 1); else if (j < e) pats = pats SUBSEP T[s, j + 1] }
          if (k == length(t)) j++
          break
        }
        if (b != "killall" && ch == "f") flags = flags "f"
        else if (ch == "i" && b != "killall" || ch == "I") flags = flags "i"
        else if (b != "killall" && ch == "x") flags = flags "x"
        else if (b != "killall" && ch == "v") flags = flags "v"
        else if (b == "killall" && (ch == "m" || ch == "r")) flags = flags "r"
      }
    }
    if (!(b != "killall" && scoped)) {
      n = split(substr(pats, 2), PARR, SUBSEP)
      if (pats == SUBSEP || pats == "") { n = 1; PARR[1] = "" }
      for (k = 1; k <= n; k++) {
        t = PARR[k]; gsub(/[\t\n]/, " ", t)
        print toupper(b) "\t" flags "\tp:" t "\t" seg_text(s, i, e)
      }
    }
  }

  # ── kill: a marker (does this command text kill at all?), and the machine-wide
  # form of kill itself: pid -1 signals EVERY process the user owns. The first -N
  # (or -s/-n SIG) is the signal; a later -1, or one after --, is the pid.
  if (b == "kill") {
    print "KILL\t-\tp:\t" seg_text(s, i, e)
    sig = 0; endopt = 0
    for (j = i + 1; j <= e; j++) {
      t = T[s, j]
      if (!endopt && t == "--") { endopt = 1; continue }
      if (!endopt && t == "-l") break
      if (!endopt && (t == "-s" || t == "-n")) { sig = 1; j++; continue }
      if (!endopt && !sig && t ~ /^-./) { sig = 1; continue }
      if (t == "-1") print "KILLALLPROCS\t-\tp:\t" seg_text(s, i, e)
    }
  }

  # ── ps … | grep PAT … | … kill: grep selects the pids from full command lines,
  # so its pattern is a pkill -f pattern. An inverted grep (-v) is an exclusion
  # filter in that idiom, not the selection, and is skipped.
  if (b == "ps") print "PS\t-\tp:\t" seg_text(s, i, e)
  if (b == "grep" || b == "egrep" || b == "fgrep") {
    flags = "-f"; pats = ""; inv = 0; endopt = 0; havepat = 0
    for (j = i + 1; j <= e; j++) {
      t = T[s, j]
      if (endopt || t !~ /^-/ || t == "-") { if (!havepat) { pats = pats SUBSEP t; havepat = 1 }; continue }
      if (t == "--") { endopt = 1; continue }
      if (t ~ /^--/) {
        if (t == "--invert-match") inv = 1
        else if (t == "--ignore-case") flags = flags "i"
        else if (t ~ /^--regexp=/) { pats = pats SUBSEP substr(t, 10); havepat = 1 }
        else if (t == "--regexp" && j < e) { j++; pats = pats SUBSEP T[s, j]; havepat = 1 }
        else if (t !~ /=/ && index(GREPLONGARG, " " t " ")) j++
        continue
      }
      for (k = 2; k <= length(t); k++) {
        ch = substr(t, k, 1)
        if (ch == "e") {                            # -e PAT / -ePAT
          if (k < length(t)) pats = pats SUBSEP substr(t, k + 1); else if (j < e) { j++; pats = pats SUBSEP T[s, j] }
          havepat = 1; break
        }
        if (index("fmABCdD", ch)) { if (k == length(t)) j++; break }
        if (ch == "v") inv = 1
        else if (ch == "i") flags = flags "i"
      }
    }
    if (!inv && havepat) {
      n = split(substr(pats, 2), PARR, SUBSEP)
      for (k = 1; k <= n; k++) {
        t = PARR[k]; gsub(/[\t\n]/, " ", t)
        print "GREP\t" flags "\tp:" t "\t" seg_text(s, i, e)
      }
    }
  }
}

function analyse_segment(s,    i, e, set, val, pre, pv, j) {
  i = 1; e = SEGNT[s]
  while (i <= e && (T[s, i] in KW)) i++
  set = EXP_SET; val = EXP_VAL; pre = 0
  while (i <= e && is_assign(T[s, i])) {
    if (aname(T[s, i]) == LIM) { set = 1; val = aval(T[s, i]); pre = 1; pv = val }
    i++
  }
  if (i > e) {                     # VAR=v alone: a shell variable, NOT in a child env
    if (pre) { SH_SET = 1; SH_VAL = pv; if (EXP_SET) EXP_VAL = pv }
    return
  }
  if (T[s, i] == "export") {
    for (j = i + 1; j <= e; j++) {
      if (is_assign(T[s, j]) && aname(T[s, j]) == LIM) { EXP_SET = 1; EXP_VAL = aval(T[s, j]); SH_SET = 1; SH_VAL = EXP_VAL }
      else if (T[s, j] == LIM && SH_SET) { EXP_SET = 1; EXP_VAL = SH_VAL }
    }
    return
  }
  if (T[s, i] == "unset") {
    for (j = i + 1; j <= e; j++) if (T[s, j] == LIM) { EXP_SET = 0; SH_SET = 0 }
    return
  }
  analyse_cmd(s, i, e, set, val)
}

{ buf = buf (NR > 1 ? "\n" : "") $0 }
END {
  LIM = "PLT_CS_COMPILE_LIMIT"
  split("{ } ! if then else elif do while until", a, " "); for (k in a) KW[a[k]] = 1
  split("timeout gtimeout env nice nohup time exec command builtin xargs sudo caffeinate stdbuf setsid", a, " ")
  for (k in a) EXEC[a[k]] = 1
  split("bash sh zsh dash ksh", a, " "); for (k in a) SHELLS[a[k]] = 1
  ARGOPT["timeout"] = ARGOPT["gtimeout"] = " -k -s --kill-after --signal "
  ARGOPT["nice"] = " -n "
  ARGOPT["xargs"] = " -E -I -J -L -n -P -R -S -s -d -a "
  ARGOPT["sudo"] = " -u -g -C -h -p -U -r -t -D -R -T "
  ARGOPT["env"] = " -u -C -S -P "
  ARGOPT["exec"] = " -a "
  ARGOPT["time"] = " -f -o "
  ARGOPT["caffeinate"] = " -t -w "
  SHORTARG["pkill"] = "FGMNPUgstuO"      # takes an argument (P = parent: scoped)
  SHORTARG["killall"] = "utcoynZ"       # c = a process name (checked as one)
  SHORTARG["pgrep"] = SHORTARG["pkill"] "d"   # pgrep -d DELIM
  GREPLONGARG = " --file --max-count --after-context --before-context --context --devices --directories --label --include --exclude --exclude-dir "
  LONGARG = " --parent --signal --pgroup --session --terminal --euid --uid --group --pidfile --ns --nslist --older --runstates --env --user --older-than --younger-than --context "
  QN = 1; QS[1] = buf; QSET[1] = 0; QVAL[1] = ""
  for (q = 1; q <= QN && q <= 32; q++) {
    EXP_SET = QSET[q]; EXP_VAL = QVAL[q]; SH_SET = 0; SH_VAL = ""
    tokenize(QS[q])
    for (s = 1; s < NSEG; s++) analyse_segment(s)
  }
}'
}

findings="$(printf '%s' "$cmd" | guard_analyse)"

# ── DEFERRED 163: can a pkill pattern / killall name reach a racket process?
# Two tests, either suffices:
#   (1) it NAMES one: racket, raco, batch-worker, run-affected-tests, bench-ab,
#       prologos or .rkt, any case — this catches every checkout's absolute
#       paths, which no fixed sample list could;
#   (2) as the regex pkill/killall would use (grep -E is the same regcomp ERE),
#       it matches a sample: process NAMES always, and the command LINES of
#       live racket processes when pkill has -f. Catches `rack.t`, `.`, "".
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
RKT="/Applications/Racket v9.3/bin/racket"
SAMPLE_NAMES="racket
raco"
SAMPLE_LINES="$RKT $ROOT/racket/prologos/tools/batch-worker.rkt --stdin --file-timeout 300
$RKT tools/run-affected-tests.rkt --all
$RKT $ROOT/racket/prologos/lsp/server.rkt
$RKT -N /Applications/Racket v9.3/bin/raco -l- raco/main.rkt make -j 4 driver.rkt
$RKT $ROOT/racket/prologos/tools/run-file.rkt probe.prologos"

reaches_racket() { # reaches_racket <kind> <flags> <pattern>
  local kind="$1" flags="$2" pat="$3" lc re samples gopt=-E
  lc="$(printf '%s' "$pat" | tr '[:upper:]' '[:lower:]')"
  case "$lc" in
    *racket*|*raco*|*batch-worker*|*run-affected-tests*|*bench-ab*|*prologos*|*.rkt*) return 0 ;;
  esac
  # killall without -m/-r compares names exactly; (1) already covered those.
  [ "$kind" = KILLALL ] && [[ "$flags" != *r* ]] && return 1
  # -v (pkill/pgrep): every process that does NOT match — nearly everything, and
  # racket whenever the pattern misses it. Deny it whatever the pattern (an inverted
  # pattern that names racket still selects every OTHER process of every session).
  [[ "$flags" == *v* ]] && return 0
  samples="$SAMPLE_NAMES"
  [ "$kind" = PKILL ] && [[ "$flags" == *f* ]] && samples="$SAMPLE_NAMES
$SAMPLE_LINES"
  [[ "$flags" == *i* ]] && gopt=-Ei
  re="$pat"; [[ "$flags" == *x* ]] && re="^($pat)\$"
  grep $gopt -q -e "$re" <<<"$samples" 2>/dev/null
}

deny163() { # deny163 <offending command> [<why this shape counts as one>]
  deny "Refusing a machine-wide kill of racket processes (DEFERRED 163):

    $1
${2:+
$2
}
pkill/killall select by process NAME or COMMAND LINE across every session on
this machine: other agents' suites, other worktrees, the editor's LSP server.
On 2026-10-13 a runner's \`pkill -f batch-worker.rkt\` killed all the workers of
concurrent suites in other checkouts (main lost 18 workers, twice), and before
fd2986cc those runs went on to print \"all pass\" (DEFERRED 164).

Kill only what you started:

    kill <pid>                                   # from \$! or a pgrep you have read
    pkill -P <your-runner-pid> -f <pattern>      # only that parent's children

Orphans of a runner that died (reparented to PID 1) — this checkout only:

    pkill -P 1 -f \"\$(git rev-parse --show-toplevel)/racket/prologos/tools/batch-worker.rkt\"

(what run-affected-tests.rkt does since b45bbf44). Look first: pgrep -fl <pattern>.
killall cannot be parent-scoped; use kill or pkill -P."
}

# Does this command text run a kill at all? (Then a pgrep, or a ps | grep, in it can
# feed that kill — through a pipe, \$(…), a variable or a file — and is judged as the
# pkill it amounts to. Co-occurrence over-approximates the dataflow; the cost is a
# look-and-kill-something-else in ONE call, which the message says to split.)
has_kill=0; has_ps=0
grep -q $'^KILL\t' <<<"$findings" && has_kill=1
grep -q $'^PS\t' <<<"$findings" && has_ps=1
FED="A pgrep (or ps | grep) in the same command as a kill is judged as the pkill it
amounts to: its output can reach the kill through a pipe, \$(…), a variable or a
file. If the kill is unrelated, split it: look in one call, kill the pid you read
in the next."

while IFS=$'\t' read -r kind what pat seg; do
  case "$kind" in
    PKILL|KILLALL)
      reaches_racket "$kind" "$what" "${pat#p:}" || continue
      deny163 "$seg" ;;
    PGREP)
      [ "$has_kill" = 1 ] || continue
      reaches_racket PKILL "$what" "${pat#p:}" || continue
      deny163 "$seg" "$FED" ;;
    GREP)
      [ "$has_kill" = 1 ] && [ "$has_ps" = 1 ] || continue
      reaches_racket PKILL "$what" "${pat#p:}" || continue
      deny163 "$seg" "$FED" ;;
    KILLALLPROCS)
      deny163 "$seg" "kill with pid -1 signals EVERY process you own — every session's, not just
racket's." ;;
    DENY159) deny "Refusing a compile without PLT_CS_COMPILE_LIMIT (DEFERRED 159):

    $what

Racket CS compiles a function larger than PLT_CS_COMPILE_LIMIT (default 10000)
with the INTERPRETER. The compiler's giant \`match\` functions (whnf/nf,
shift/subst, the elaborator and typing-core arms) are all larger, so a build
without the limit is silently slow: no error, no warning. MEASURED 2026-10-13:
main ran that way for ~6.5 h — suite 1.23-1.28x slower, single files up to 25x.
The test runner's putenv cannot repair it afterwards: raco make never recompiles
a .zo that is already up to date.

Put the limit ON THIS COMMAND (inline):

    PLT_CS_COMPILE_LIMIT=1000000 \"/Applications/Racket v9.3/bin/raco\" make -j 4 driver.rkt

  or  env PLT_CS_COMPILE_LIMIT=1000000 <cmd>
  or  export PLT_CS_COMPILE_LIMIT=1000000 && <cmd>   (in the SAME command)

An export made by an EARLIER command is invisible to this check — it reads only
this command's text — so inline it even if your shell already has it. The value
must be a number >= 1000000. Use the quoted 9.3 binary: a bare \`raco\` on PATH
can resolve to /opt/homebrew/bin/raco, which is Racket 9.0.
raco setup, raco pkg install|update and raco test --make compile too; and since
prologos-dev is a LINKED package, they rebuild the MAIN checkout's compiled/." ;;
  esac
done <<<"$findings"

# ── Is the racket BINARY invoked? Two forms, both anchored so that merely
# mentioning the word (grep racket, echo racket, a path in a comment) is not a
# match:
#   (a) a path ending in /racket        — "/Applications/Racket v9.0/bin/racket"
#   (b) the bare word `racket` at COMMAND position: start of line/string, or
#       after ; && || | ( or a newline, with optional VAR=... env prefixes.
#   (c) the bare word `racket` after an EXECUTOR that runs its argument
#       (`timeout 900 racket …`, `env FOO=1 racket …`, `nohup racket …`).
#       ⚠ (c) IS NOT OPTIONAL: without it `timeout 900 racket foo.rkt` — the
#       orphan's own shape, minus the absolute path — reads as neither a
#       /racket path nor a command-position bare word, and sails through. Caught
#       by the decision table, which is why that table exists.
#
# ⚠ STRIP-THEN-DECIDE, not allowlist-then-decide. `racket --version|--help|-h`
# prints and exits, so it cannot hang and needs no bound. But expressing that as
# "allow if the command contains --version" is a BYPASS: `racket --version &&
# racket foo.rkt` would sail through on the harmless half. Caught by the decision
# table the moment the row was added. So remove the harmless invocations from a
# WORKING COPY and decide on whatever invocation remains.
scan="$(sed -E 's/racket["'\'']?[[:space:]]+(--version|--help|-h)([[:space:]]|$)/ /g' <<<"$cmd")"

invokes_racket=0
grep -Eq '/racket("|'\''|[[:space:]]|$)' <<<"$scan" && invokes_racket=1
grep -Eq '(^|[;&|(]|&&|\|\|)[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*racket([[:space:]]|$)' <<<"$scan" && invokes_racket=1
grep -Eq '\b(g?timeout|env|nice|nohup|time|setsid|sudo|xargs|exec)\b[^;&|]*\bracket\b' <<<"$scan" && invokes_racket=1
[ "$invokes_racket" -eq 0 ] && exit 0

# ── Allowlist: runners that own their own bounds.
grep -q 'scratch-run\.sh'          <<<"$cmd" && exit 0
grep -q 'run-affected-tests\.rkt'  <<<"$cmd" && exit 0
grep -q 'bench-ab\.rkt'            <<<"$cmd" && exit 0

# ── Already bounded WITH a SIGKILL follow-up?
grep -Eq '\bg?timeout[[:space:]]+((-k|--kill-after)([[:space:]]|=))' <<<"$cmd" && exit 0
# `timeout 60 -k 10` ordering, and long-form after the duration
grep -Eq '\bg?timeout[[:space:]]+[^|;&]*((-k[[:space:]])|(--kill-after))' <<<"$cmd" && exit 0

if grep -Eq '\bg?timeout\b' <<<"$cmd"; then
  deny "Bounded with \`timeout\` but no \`-k\`, which is not a limit.

MEASURED 2026-08-08: an orphan carrying \`timeout 550\` was still alive at 1h18m,
and \`kill -TERM\` on it did nothing — Racket CS in a tight allocation/GC loop
does not service SIGTERM. Only the SIGKILL follow-up stops it.

Add the kill-after:   timeout -k 30 <seconds> <command>
Or use the wrapper:   tools/scratch-run.sh [-t SECONDS] ONE-FILE.prologos"
fi

deny "Refusing to run the Racket binary unbounded.

On 2026-08-08 three hand-rolled harnesses were left orphaned at PPID 1 holding
~14 GB (one at 12.6 GB) at 76-80% CPU, still running 45-75 minutes after the
workflow that spawned them had finished. Root cause was not a leak: they looped
a 49-file corpus inside ONE Racket process, so peak heap scaled with corpus size.

Use the sanctioned runner — it takes ONE file, applies \`timeout -k\`, and puts
the child in its own process group so nothing outlives the shell:

    tools/scratch-run.sh [-t SECONDS] ONE-FILE.prologos

Sweep a corpus with a SHELL loop (one process per file, bounded memory):

    for f in corpus/*.prologos; do tools/scratch-run.sh -t 60 \"\$f\"; done

Running the test suite? Use the runner that owns its own workers and timeouts:

    racket tools/run-affected-tests.rkt --tests tests/test-X.rkt

Anything else that must call racket directly needs an explicit bound:

    timeout -k 30 300 \"/Applications/Racket v9.3/bin/racket\" ...

See .claude/rules/testing.md § \"Running the compiler OUTSIDE the suite\"."
