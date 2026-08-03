#!/usr/bin/env bash
# check-doc-twins.sh — report `.md` exports that are older than their `.org` source.
#
# `workflow.md` makes the `.org` canonical and the `.md` a generated export, so a
# stale `.md` is not merely untidy: someone grepping the principles directory can
# land on it and read a claim the `.org` has already retracted. That is the exact
# failure a doc-truth sweep exists to prevent, reintroduced by the export.
#
# Staleness is judged by LAST COMMIT TIME, not mtime — a fresh clone gives every
# file the same mtime, so mtime would report nothing on CI and everything locally.
#
# Exit 0 always: this REPORTS. Regenerating needs org-export (emacs or pandoc),
# which is not present in every environment, so a non-zero exit would gate work
# on a tool the environment may not have.
set -u
cd "$(dirname "$0")/.." || exit 1

stale=0
checked=0
while IFS= read -r org; do
  md="${org%.org}.md"
  [ -f "$md" ] || continue
  checked=$((checked + 1))
  o=$(git log -1 --format=%ct -- "$org" 2>/dev/null)
  m=$(git log -1 --format=%ct -- "$md" 2>/dev/null)
  [ -n "$o" ] && [ -n "$m" ] || continue
  if [ "$o" -gt "$m" ]; then
    stale=$((stale + 1))
    printf 'STALE  %s\n         source %s   export %s\n' \
      "$md" "$(date -d "@$o" +%F)" "$(date -d "@$m" +%F)"
  fi
done < <(find docs -name '*.org' -print | sort)

printf '\n%d/%d generated .md exports are behind their .org source.\n' "$stale" "$checked"
if [ "$stale" -gt 0 ]; then
  printf 'Each carries a banner pointing at its source. To regenerate: org-export the .org.\n'
fi
exit 0
