#!/bin/bash
# spine-census-isolated.sh — run spine-census with ONE PROCESS PER FILE.
#
# WHY THIS EXISTS. tools/spine-census.rkt runs every file in a single process and
# never resets the trait/spec/bundle registries between them, so a divergence it
# reports may be an artifact of an earlier file's state rather than a property of
# the file under test. MEASURED 2026-08-03, --mode raw-datum over 163 files:
#
#     batched   14 divergences · 24 file crashes
#     isolated   7 divergences · 36 file crashes
#
# BOTH numbers are real and NEITHER is "the truth" on its own:
#   · isolation removes 7 POLLUTION ARTIFACTS — all 7 came from
#     pairs-and-options.prologos, which reports 0 divergences alone;
#   · isolation ADDS 12 crashes, because batching lets earlier files register
#     what later ones need (lib modules with real dependencies).
# So: isolated divergences are CONFIRMED · batched-only ones are SUSPECT ·
# files that crash alone are UNMEASURABLE this way. Report all three.
#
# Usage:  tools/spine-census-isolated.sh OUT.tsv [mode]      (default raw-datum)
#         Run from anywhere inside the repo; the corpus is derived from git, so
#         this works in a worktree without editing a hardcoded path.
# Output: one row per file — divergences<TAB>crashes<TAB>equivalent<TAB>path
#         plus REASON-prefixed detail lines for each divergence, then a summary.
set -u

OUT="${1:?usage: spine-census-isolated.sh OUT.tsv [mode]}"
MODE="${2:-raw-datum}"
RACKET="${RACKET:-/Applications/Racket v9.0/bin/racket}"
JOBS="${JOBS:-3}"

ROOT="$(git rev-parse --show-toplevel)" || { echo "not in a git repo" >&2; exit 1; }
cd "$ROOT/racket/prologos" || { echo "no racket/prologos under $ROOT" >&2; exit 1; }
: > "$OUT"

runone() {
  local f="$1" out d c e
  out=$(timeout 120 "$RACKET" tools/spine-census.rkt --mode "$MODE" --verbose "$f" 2>/dev/null)
  d=$(printf '%s' "$out" | grep -oE 'DIVERGE +: [0-9]+' | grep -oE '[0-9]+$')
  c=$(printf '%s' "$out" | grep -c 'CRASH')
  e=$(printf '%s' "$out" | grep -oE 'EQUIVALENT \(tree could win\) +: [0-9]+' | grep -oE '[0-9]+' | tail -1)
  printf '%s\t%s\t%s\t%s\n' "${d:-NA}" "${c:-0}" "${e:-0}" "$f"
  printf '%s' "$out" | grep -A 3 'at \./' | sed "s|^|REASON	$(basename "$f")	|"
}

i=0
while IFS= read -r rel; do
  runone "$ROOT/$rel" >> "$OUT" &
  i=$((i+1))
  if [ $((i % JOBS)) -eq 0 ]; then wait; fi
done < <(git -C "$ROOT" ls-files '*.prologos')
wait

echo "DONE" >> "$OUT"

awk -F'\t' -v m="$MODE" '
  !/^REASON/ && !/^DONE/ { n++; if ($1 != "NA") d += $1; if ($2 > 0) c++ }
  END { printf "isolated: %d divergences · %d crashes · %d files (mode=%s)\n", d, c, n, m }
' "$OUT"
