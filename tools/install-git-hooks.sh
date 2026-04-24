#!/usr/bin/env bash
#
# install-git-hooks.sh — one-shot installer for project git hooks
#
# Symlinks executable hook scripts from tools/git-hooks/ into .git/hooks/.
# Git does not track .git/hooks/ contents, so each dev runs this once.
#
# Hooks are committed under tools/git-hooks/ so edits propagate through
# the symlink — no "edit and forget to copy" pattern.

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  echo "error: not inside a git repository" >&2
  exit 1
fi

HOOKS_SRC="$REPO_ROOT/tools/git-hooks"
HOOKS_DST="$REPO_ROOT/.git/hooks"

if [ ! -d "$HOOKS_SRC" ]; then
  echo "error: $HOOKS_SRC does not exist" >&2
  exit 1
fi
if [ ! -d "$HOOKS_DST" ]; then
  echo "error: $HOOKS_DST does not exist (is .git missing?)" >&2
  exit 1
fi

installed=0
for hook in "$HOOKS_SRC"/*; do
  name="$(basename "$hook")"
  # Skip non-files + documentation
  [ -f "$hook" ] || continue
  case "$name" in
    README*|*.md|*.txt|*.bak|.*) continue ;;
  esac

  target="$HOOKS_DST/$name"

  # Make the source executable (idempotent; safer than relying on git preserving chmod)
  chmod +x "$hook"

  # If the target is a symlink, replace it. If it's a regular file, back up.
  if [ -L "$target" ]; then
    rm "$target"
  elif [ -f "$target" ]; then
    echo "warning: $target exists as a regular file; moving to $target.bak" >&2
    mv "$target" "$target.bak"
  fi

  ln -s "$hook" "$target"
  echo "installed: .git/hooks/$name -> tools/git-hooks/$name"
  installed=$((installed + 1))
done

if [ "$installed" -eq 0 ]; then
  echo "no hooks found under $HOOKS_SRC" >&2
  exit 1
fi

echo
echo "$installed hook(s) installed. Edits to tools/git-hooks/* now apply immediately."
