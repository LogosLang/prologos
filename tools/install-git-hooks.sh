#!/usr/bin/env bash
#
# install-git-hooks.sh — one-shot installer for project git hooks
#
# Symlinks executable hook scripts from tools/git-hooks/ into .git/hooks/.
# Git does not track .git/hooks/ contents, so each dev runs this once.
#
# Hooks are committed under tools/git-hooks/ so edits propagate through
# the symlink — no "edit and forget to copy" pattern.
#
# ⚠⚠ THE LINKS ARE RELATIVE, AND THAT IS LOAD-BEARING (fixed 2026-08-13).
# This script used to `ln -s "$REPO_ROOT/tools/git-hooks/$name"` — an ABSOLUTE
# target — while PRINTING the relative form, so its own output asserted the
# property it did not have. When the project moved to `logos/prologos`, every
# installed hook became a DANGLING symlink and git skips a hook it cannot
# execute: the pre-commit `check-parens` gate was silently dead, with no error
# on any commit. It FAILS OPEN, which is why it went unnoticed. A relative link
# survives a move and survives a clone to any path.

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  echo "error: not inside a git repository" >&2
  exit 1
fi
cd "$REPO_ROOT"

HOOKS_SRC="$REPO_ROOT/tools/git-hooks"

# Resolve the REAL hooks dir rather than assuming `.git/hooks`: under a git
# worktree `.git` is a file, and `core.hooksPath` can move it anywhere. Only the
# standard layout has a statically-known relative route, so anything else falls
# back to absolute WITH A WARNING rather than silently installing a link that
# points at the wrong place.
# ⚠ `core.hooksPath` OVERRIDES the hooks directory ENTIRELY. If it is set to an
# absolute path and the repo moves, git looks in a directory that no longer
# exists and runs NO HOOKS AT ALL — silently, on every commit, with `.git/hooks/`
# fully populated and completely ignored. That is exactly what was found here on
# 2026-08-13 (it pointed at the pre-move checkout). Refuse to install into a void.
CONFIGURED_HOOKS_PATH="$(git config --get core.hooksPath || true)"
if [ -n "$CONFIGURED_HOOKS_PATH" ] && [ ! -d "$CONFIGURED_HOOKS_PATH" ]; then
  echo "error: core.hooksPath is set to '$CONFIGURED_HOOKS_PATH', which does not exist." >&2
  echo "       git is therefore running NO hooks. It was almost certainly an absolute" >&2
  echo "       path left over from before the repo moved. Clear it so git uses the" >&2
  echo "       default \$GIT_DIR/hooks, then re-run this script:" >&2
  echo "         git config --unset core.hooksPath" >&2
  exit 1
fi

HOOKS_DST="$(git rev-parse --git-path hooks)"
case "$HOOKS_DST" in
  /*) ;;
  *) HOOKS_DST="$REPO_ROOT/$HOOKS_DST" ;;
esac

if [ ! -d "$HOOKS_SRC" ]; then
  echo "error: $HOOKS_SRC does not exist" >&2
  exit 1
fi
if [ ! -d "$HOOKS_DST" ]; then
  echo "error: $HOOKS_DST does not exist (is .git missing?)" >&2
  exit 1
fi

installed=0
skipped=0
for hook in "$HOOKS_SRC"/*; do
  name="$(basename "$hook")"
  # Skip non-files + documentation
  [ -f "$hook" ] || continue
  case "$name" in
    README*|*.md|*.txt|*.bak|.*) continue ;;
  esac

  target="$HOOKS_DST/$name"

  # Respect a DELIBERATE disable. Renaming a hook to `<name>.disabled` is how
  # this repo turns one off (the mempalace post-commit auto-mine is disabled that
  # way). Without this guard a re-install silently RE-ENABLES it — and the person
  # re-installing is usually doing so to repair something else entirely.
  if [ -e "$target.disabled" ] || [ -L "$target.disabled" ]; then
    echo "skipped:   $name — $name.disabled is present (deliberately disabled; remove it to re-enable)"
    skipped=$((skipped + 1))
    continue
  fi

  # Make the source executable (idempotent; safer than relying on git preserving chmod)
  chmod +x "$hook"

  # If the target is a symlink, replace it. If it's a regular file, back up.
  if [ -L "$target" ]; then
    rm "$target"
  elif [ -f "$target" ]; then
    echo "warning: $target exists as a regular file; moving to $target.bak" >&2
    mv "$target" "$target.bak"
  fi

  # RELATIVE target when the layout is standard — see the header. `.git/hooks/X`
  # is two levels below the repo root, so `../../tools/git-hooks/X` is the route.
  if [ "$HOOKS_DST" = "$REPO_ROOT/.git/hooks" ]; then
    link_target="../../tools/git-hooks/$name"
  else
    link_target="$hook"
    echo "warning: non-standard hooks dir ($HOOKS_DST) — installing an ABSOLUTE symlink, which breaks if the repo moves" >&2
  fi

  ln -s "$link_target" "$target"

  # VERIFY IT RESOLVES. The whole defect this guards against is a link that
  # exists but points at nothing: git skips an unexecutable hook silently, so an
  # unverified install reports success while installing a no-op.
  if [ ! -e "$target" ]; then
    echo "error: $target was created but does not resolve (-> $link_target)" >&2
    exit 1
  fi
  if [ ! -x "$target" ]; then
    echo "error: $target resolves but is not executable" >&2
    exit 1
  fi

  echo "installed: .git/hooks/$name -> $link_target"
  installed=$((installed + 1))
done

if [ "$installed" -eq 0 ] && [ "$skipped" -eq 0 ]; then
  echo "no hooks found under $HOOKS_SRC" >&2
  exit 1
fi

echo
echo "$installed hook(s) installed, $skipped skipped as disabled."
echo "Edits to tools/git-hooks/* now apply immediately (the links are relative,"
echo "so they survive the repo being moved or cloned to a different path)."
