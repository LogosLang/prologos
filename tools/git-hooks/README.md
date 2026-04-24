# Project git hooks

Committed git hook scripts for the Prologos repo. Activate with:

```sh
./tools/install-git-hooks.sh
```

This symlinks the scripts in this directory into `.git/hooks/`. Git does
not track `.git/hooks/` contents, so each developer runs the installer
once after cloning. Because these are symlinks, edits to scripts in
this directory take effect immediately — no copy step.

## Hooks

### `post-commit`

Triggers a background `mempalace mine ./docs --wing prologos` when the
just-completed commit touched `docs/tracking/**` or `docs/research/**`.

Behavior:
- **Silent**: no output unless the mine actually runs; the commit
  returns immediately
- **Background**: the mine runs detached and does not block the shell
- **Fast-path**: exits in milliseconds for code-only commits
- **Portable**: silently no-ops if `mempalace` is not installed or the
  palace has not been initialized (`~/.mempalace/palace`)
- **Idempotent**: `mempalace mine` dedups on content hash; re-mines
  after small doc changes are cheap

Log file: `/var/tmp/mempalace-auto-mine.log` — preserves every trigger
with timestamps, HEAD, changed paths sample, and mine output. Tail this
if semantic search results ever feel stale.

Provenance: landed as mempalace Phase 3 (2026-04-23). See
`.claude/rules/mempalace.md` § "Re-mine cadence" for the broader
discipline.

## Why not `core.hooksPath`?

`git config core.hooksPath tools/git-hooks` is the other option and
avoids the symlink step. We use the symlink installer because:
- It keeps `.git/hooks/` as the canonical home (matches every git
  developer's muscle memory)
- It allows per-dev local-only hooks to coexist with committed ones
  (e.g., a developer's own `pre-commit` lint) without conflicting
- It leaves the existing `pre-push` hook behavior untouched
