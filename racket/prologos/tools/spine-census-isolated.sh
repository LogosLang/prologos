#!/bin/zsh
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
# So: isolated divergences are CONFIRMED; batched-only divergences are SUSPECT;
# and files that crash alone are simply UNMEASURABLE this way. Report all three.
#
# Usage: tools/spine-census-isolated.sh OUT.tsv [mode]     (default raw-datum)
# Output: one row per file, `divergences<TAB>crashes<TAB>equivalent<TAB>path`,
# plus REASON-prefixed detail lines.
OUT="$1"; MODE="${2:-raw-datum}"
R="/Applications/Racket v9.0/bin/racket"
cd "$ROOT/racket/prologos" || exit 1
: > "$OUT"
runone() {
  local f="$1" out
  out=$(timeout 120 "$R" tools/spine-census.rkt --mode "$MODE" --verbose "$f" 2>/dev/null)
  local d=$(printf '%s' "$out" | grep -oE 'DIVERGE +: [0-9]+' | grep -oE '[0-9]+$')
  local c=$(printf '%s' "$out" | grep -c 'CRASH')
  local e=$(printf '%s' "$out" | grep -oE 'EQUIVALENT \(tree could win\) +: [0-9]+' | grep -oE '[0-9]+' | tail -1)
  printf '%s\t%s\t%s\t%s\n' "${d:-NA}" "${c:-0}" "${e:-0}" "$f"
  printf '%s' "$out" | grep -A 3 'at \./' | sed "s|^|REASON\t$(basename $f)\t|"
}
i=0
for f in $(cat "$ROOT/../../.claude/worktrees/sleepy-tharp-263e0f/.corpus" 2>/dev/null || cat /private/tmp/claude-501/-Users-avanti-dev-projects-prologos--claude-worktrees-sleepy-tharp-263e0f/f0ca06a9-48be-4dd5-b314-174c52a17427/scratchpad/corpus-list.txt); do
  runone "$f" >> "$OUT" &
  i=$((i+1)); if [ $((i % 3)) -eq 0 ]; then wait; fi
done
wait
echo "DONE" >> "$OUT"
