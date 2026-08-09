#!/usr/bin/env bash
#
# reap-scratch-racket.sh — find (and optionally kill) Racket processes left
# behind by scratch harnesses.
#
# THE SAFETY NET, not the guarantee. `scratch-run.sh` is what makes the runaway
# shape unrepresentable; this is for the case someone ran the compiler WITHOUT
# it — which is exactly what happened on 2026-08-08, when three adversarial-
# verify subagents hand-rolled their own harnesses and left ~14 GB running at
# PPID 1, 45-75 minutes after the workflow had finished and reported.
#
# THE DISCRIMINATOR IS THE WORKING DIRECTORY, deliberately. A scratch harness
# runs with cwd under a temp dir; every long-lived Racket process a developer
# actually wants — the LSP server, racket-mode's back end, a `prologos/repl` —
# runs from the project tree or from $HOME. Keying on cwd is what lets this be
# aggressive without ever touching those. It also does not care what the script
# is CALLED, so it still catches a harness invented tomorrow.
#
# Usage:
#   tools/reap-scratch-racket.sh            # LIST only (default — never kills)
#   tools/reap-scratch-racket.sh --kill     # SIGTERM, then SIGKILL 3s later
#   tools/reap-scratch-racket.sh --kill --min-age 300   # only if older than 5m
#
set -uo pipefail

DO_KILL=0
MIN_AGE=0            # seconds; 0 = any age
while [ "$#" -gt 0 ]; do
  case "$1" in
    --kill)     DO_KILL=1; shift ;;
    --min-age)  MIN_AGE="${2:-0}"; shift 2 ;;
    -h|--help)  sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "reap-scratch-racket.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# elapsed "[[dd-]hh:]mm:ss" -> seconds
etime_secs() {
  awk -F'[-:]' '{
    if (NF==4)      print (($1*24+$2)*60+$3)*60+$4;
    else if (NF==3) print ($1*60+$2)*60+$3;
    else if (NF==2) print $1*60+$2;
    else            print 0;
  }' <<<"$1"
}

FOUND=0
KILLED=0

while read -r pid ppid etime rss comm; do
  [ -z "${pid:-}" ] && continue
  [ "$pid" = "PID" ] && continue
  # cwd is the discriminator — scratch harnesses live in temp dirs
  cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)"
  case "$cwd" in
    /private/tmp/*|/tmp/*|/private/var/folders/*) ;;
    *) continue ;;
  esac
  age="$(etime_secs "$etime")"
  [ "$age" -lt "$MIN_AGE" ] && continue

  FOUND=$((FOUND+1))
  printf '  pid %-7s ppid %-5s up %-11s %8.1f MB  cwd %s\n' \
         "$pid" "$ppid" "$etime" "$(awk -v r="$rss" 'BEGIN{print r/1024}')" "$cwd"

  if [ "$DO_KILL" -eq 1 ]; then
    kill -TERM "$pid" 2>/dev/null
    sleep 3
    # ⚠ SIGTERM IS NOT ENOUGH — measured 2026-08-08: `kill -TERM` on all three
    # orphans did nothing at all, and SIGKILL was required. Racket CS in a tight
    # allocation/GC loop does not service SIGTERM. Never omit this follow-up.
    if kill -0 "$pid" 2>/dev/null; then kill -KILL "$pid" 2>/dev/null; fi
    KILLED=$((KILLED+1))
  fi
done < <(ps -axo pid,ppid,etime,rss,comm | grep -i 'racket' | grep -v grep)

if [ "$FOUND" -eq 0 ]; then
  echo "reap-scratch-racket.sh: no scratch Racket processes found."
elif [ "$DO_KILL" -eq 1 ]; then
  echo "reap-scratch-racket.sh: killed $KILLED of $FOUND."
else
  echo "reap-scratch-racket.sh: $FOUND found (LIST ONLY — pass --kill to reap)."
fi
