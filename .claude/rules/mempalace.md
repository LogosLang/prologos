# MemPalace (Project Memory) — Phase 2 Experimental Guardrails

**Status**: Experimental (Phase 2, started 2026-04-22). MCP-only integration. Evaluate against committed tracking docs before relying on any result for architectural decisions.

**Setup (one-time, per-developer)**:
```
uv tool install mempalace
cd /path/to/prologos
mempalace init . --yes --lang en
mempalace mine ./docs --wing prologos
```
`.mcp.json` at repo root registers the MCP server; Claude Code picks it up automatically after restart.

**Verify**:
```
mempalace status                # should show WING: prologos, N drawers
```

## What mempalace is good for

Semantic lookup of **stable architectural concepts** across our committed docs (`docs/tracking/**`, `docs/research/**`, `docs/standups/**`, `docs/spec/**`, `docs/stdlib-book/**`, principles docs). Use via the MCP tools `mempalace_search`, `mempalace_status`, `mempalace_list_wings`, `mempalace_list_rooms`, `mempalace_get_taxonomy`.

**Good queries** — Phase 1 eval confirmed ≥4/5 canonical hits:
- Role A vs Role B decomplection
- charter alignment re-sequencing
- Hyperlattice Conjecture
- Module Theory Realization B
- SRE lattice lens six questions
- Track 4D attribute grammar substrate unification
- map open-world `_` value type ergonomics (T-2 question)
- specific commit hashes (exact text match)
- design mantra / PU heuristic / with-speculative-rollback retirement

## What mempalace is NOT good for (critical)

### Recency-sensitive queries

**The palace stores verbatim history and has no date-weighted ranking.** When our state changes over the project's timeline (PIR outcomes, retired mechanisms, disproven conjectures, current code behavior), semantic search will often prefer the older, more elaborated discussion over the newer update.

**Known failure mode (Phase 1 eval, 2026-04-22)**: `mempalace_search "F7 distributivity"` returns the pre-T-3 "F7 conjecture holds" claim (SRE Track 2H D.1 + Track 2H PIR §7 "We got lucky — F7 holds") ahead of the 2026-04-22 disproof (in dailies + test-sre-track2h update). Acting on top-1 would be wrong.

**Rule**: NEVER query mempalace for "current state" or "is X still true?" questions without cross-checking. Those questions go through:
1. The most recent dailies (`docs/tracking/standups/`)
2. The current design doc's Progress Tracker
3. The most recent handoff document's §1 + §4

### Decisions about what's CURRENTLY in the codebase

mempalace indexes `docs/`, not Racket source. For source code, use `Grep` / `Glob` / `Read`. For "what does function X currently do", read the file — don't ask mempalace.

### Wake-up and room filtering

`mempalace wake-up` produces unreliable "essential story" output (Phase 1 eval: it surfaced a random imported research note rather than project-canonical content). Do not use it. Also `--room` filtering did not work for our corpus — all 417 docs landed in `room:general`. Ignore the room taxonomy; query without filter or use `--wing prologos`.

### Temporal knowledge graph

mempalace includes a bitemporal triple store (`docs/schema.sql`, `knowledge_graph.py`) but it is **NOT auto-populated by `mine`**. The `~/.mempalace/knowledge_graph.sqlite3` does not exist after mining unless facts are manually asserted via `kg.add_triple(...)`. This means the "temporal validity" feature does NOT mitigate the recency problem for our use. (Source: verified empirically after mining 23,497 drawers of `docs/` — no KG file created; `miner.py` / `diary_ingest.py` have zero `add_triple` calls.)

If we ever want real recency mitigation, we'd have to maintain a parallel triple store of key "status" facts by hand (e.g., `"F7" "is_status" "DISPROVEN" valid_from="2026-04-22"`). That duplicates what our dailies + PIR discipline already does; don't bother unless we find a compelling use.

## Anti-patterns (do NOT do)

- ❌ **Do NOT install the Claude Code Stop or PreCompact hooks.** They can inject `"decision": "block"` system messages into the conversation (prompt-injection path). The silent default is fine but the footgun exists. Keep integration MCP-only.
- ❌ **Do NOT mine JSONL transcripts** (`~/.claude/projects/*.jsonl` via `mempalace mine --mode convos`). Our conversation transcripts include debugging attempts and false starts that we deliberately didn't commit; retrieving them as "memory" would pollute decisions with discarded material.
- ❌ **Do NOT mine the Racket source tree** (`mempalace mine ./racket/prologos`) — validated negative 2026-04-23 (see "Phase 3b — code wing: ATTEMPTED, ABANDONED" below). mempalace's `mine --mode projects` has no file-type filter and paragraph-chunks 150M+ of non-source content (.zo compiled binaries, .dep dependency metadata, .json benchmark outputs, .pnet module caches, .golden test fixtures, `~undo-tree~` emacs autosave files). Mine stalls for hours and corrupts the palace. Re-evaluate only if future mempalace versions add extension filtering or AST-aware chunking. For code queries, use `grep`/`ripgrep` — strictly better for identifier lookups.
- ❌ **Do NOT run `mempalace repair --yes` on a production palace** — validated negative 2026-04-23. Despite the command name suggesting non-destructive index rebuild, repair silently TRUNCATED our 26,161-drawer docs wing to 10,000 drawers (62% data loss). Large files like D.3 (~2000 lines, normally ~100+ drawers) were reduced to a single drawer each, destroying search quality. Recovery path via incremental `mempalace mine` is blocked by file-level content-hash dedup (re-mine sees already-indexed files and skips them). The only reliable recovery is **full wipe + fresh mine**: `rm -rf ~/.mempalace/palace` → `mempalace init . --yes --lang en` → `mempalace mine ./docs --wing prologos`. If `mempalace status` segfaults, do this directly — do NOT run repair.
- ❌ **Do NOT use mempalace_add_drawer / mempalace_delete_drawer** unless the user explicitly asks for it. Our commit-linked tracking docs are the source of truth; don't write ephemeral content into the palace in parallel.
- ❌ **Do NOT use mempalace as authoritative** for any decision. Its output is a SEARCH HIT, not a fact. Cross-reference against current dailies/handoff/design-doc sections before using it to inform design or implementation choices.

## Phase 3b — code wing: ATTEMPTED, ABANDONED (2026-04-23)

Evaluated mining the Racket source tree into a separate `prologos-code` wing for semantic code search. Outcome: **negative**. Specific failure modes observed:

1. **Mine stalls on mixed-content directory**. The `mempalace mine ./racket/prologos --wing prologos-code` stalled for 6+ hours without completing. Root cause: no file-type filter in the `mine` subcommand (`mempalace mine --help` shows only `--no-gitignore`, `--include-ignored`, `--limit`, `--dry-run`, `--extract` — no way to exclude by extension or pattern). The Racket tree has 168MB of which most is non-source: 542 `.dep` files, 521 `.zo` compiled binaries, 155 `.json` benchmark outputs, 43 `.pnet` module caches, 110 `.golden` test fixtures, 32 `~undo-tree~` emacs autosaves.

2. **Binary-blind paragraph chunking explodes drawer count**. The code-wing mine reached 114,984 drawers before stalling — vs the docs-wing's 26,887 for comparable file count. Paragraph-chunking treats binary files as single mega-paragraphs, which sometimes chunks differently per pass and inflates drawer count without semantic value.

3. **Killing the stuck mine corrupted the palace**. After `kill` on the stuck mine process: `chroma.sqlite3` ballooned to 881 MB, 438 stale lock files accumulated, `mempalace status` segfaulted (SIGSEGV then SIGBUS). Surgical SQL delete of the 114,984 code-wing drawers + VACUUM brought sqlite back to ~458 MB and status worked again — but then `mempalace repair --yes` truncated the remaining docs wing from 26,161 to 10,000 drawers (see anti-pattern above).

4. **Semantic search on code is hypothetical anyway**. Paragraph-chunking of s-expressions isn't AST-aware — function bodies get severed at blank lines; related `define` forms end up in different chunks. Even if the mine succeeded, semantic retrieval quality for code identifiers would need to beat `grep -rn 'pattern'` which returns in 50ms with perfect recall. The conceptual-query edge cases where semantic search might add value (e.g., "callers treating meta cell-id as output target") remain unvalidated and unlikely to justify the maintenance cost of a per-commit code re-mine hook.

**Conclusion**: do not mine code into mempalace until upstream offers:
- File-type / extension filtering on `mine`
- AST-aware chunking for Lisp-family languages
- Or an explicit code-mode distinct from `projects` mode

Until then: stick to docs-only mining (Phase 2), with the post-commit hook (Phase 3) keeping the docs wing fresh.

**Time cost of this experiment**: ~6h of stalled mine CPU + 30min of diagnosis + recovery via full palace reinit + docs re-mine. Documented here so the next session does not re-attempt without new tooling.

## Cross-check discipline

For any mempalace result that informs a decision:

1. Note the `Source:` filename mempalace returned.
2. Check the file's most recent modification timestamp / `git log` — is it stale?
3. Check the CURRENT state in the relevant dailies (`docs/tracking/standups/YYYY-MM-DD_dailies.md` latest) + handoff doc §1 (current work state) for whether the claim still holds.
4. If there's conflict, **recent dailies + handoff win**. Always.

Example cross-check:
- mempalace: "F7 distributivity conjecture holds (SRE Track 2H PIR)" → note source = `2026-04-03_SRE_TRACK2H_PIR.md`
- Current dailies (`2026-04-22_dailies.md`): "F7 DISPROVEN 2026-04-22"
- Action: use the dailies claim; ignore the mempalace result. Add a "staleness flag" note if the mempalace result might mislead a future query.

## Re-mine cadence

The palace stays fresh via an automated git hook + manual fallback. Practical rule:

- **Automated** (Phase 3, landed 2026-04-23): `tools/git-hooks/post-commit` triggers a background `mempalace mine ./docs --wing prologos` whenever a commit touches `docs/tracking/**` or `docs/research/**`. Silent; fast-path for code-only commits; logs to `/var/tmp/mempalace-auto-mine.log`. Per-developer activation: `./tools/install-git-hooks.sh` after cloning (git does not track `.git/hooks/`).
- **Manual fallback** — if the hook did not run (hook not installed on this machine, network issue, etc.): `mempalace mine ./docs --wing prologos` from the repo root. Content-hash dedup makes re-mines incremental.
- Don't sweat real-time freshness. The palace is for lookup, not authority.

Verify the hook is active on your machine:
```
ls -la .git/hooks/post-commit        # should be a symlink to tools/git-hooks/post-commit
tail -40 /var/tmp/mempalace-auto-mine.log  # inspect recent triggers
```

Design rationale for the git-hook approach (not a Claude Code hook): git post-commit runs out-of-process after the commit lands, with no path to inject content back into a Claude Code session. The prompt-injection constraint (see "Anti-patterns" above) is architecturally satisfied. The hook only calls `mempalace mine` as a subprocess and does not communicate with any running Claude instance.

## Tool surface (reference)

Read-only MCP tools (safe to use freely):
- `mempalace_search` — main retrieval; `query` string, optional `wing`/`room` filter, `results` count
- `mempalace_status` — total drawers, wing/room breakdown
- `mempalace_list_wings`, `mempalace_list_rooms`, `mempalace_get_taxonomy` — navigation
- `mempalace_check_duplicate` — check before filing (we don't file, so unused in our flow)

Write tools (DO NOT use without explicit user direction):
- `mempalace_add_drawer`, `mempalace_delete_drawer`

## Phase 2 success criteria

This rule and the integration are considered validated if, across a month of use:
- mempalace retrievals meaningfully reduced re-reading of the 35-doc hot-load on at least 3 mini-design sessions
- No decision was made on a stale mempalace hit without cross-check (zero incidents)
- No prompt-injection incident from hooks (N/A — hooks not installed, but verify nothing gets installed)
- Re-mine cadence sustained (palace size growth tracks doc-commit cadence)

If any of those fail — or if the recency problem causes a real bug — uninstall mempalace, delete the palace directory, revert this rule + `.mcp.json`, and write a brief retrospective in the dailies.

## Uninstall (if we decide to back out)

```
uv tool uninstall mempalace
rm -rf ~/.mempalace/
rm /Users/avanti/dev/projects/prologos/mempalace.yaml
rm /Users/avanti/dev/projects/prologos/entities.json
rm /Users/avanti/dev/projects/prologos/.mcp.json
rm /Users/avanti/dev/projects/prologos/.claude/rules/mempalace.md
# Then remove @.claude/rules/mempalace.md from CLAUDE.md's rules line
```

## References

- Phase 1 evaluation: see dailies 2026-04-22 session log (to be appended)
- Project repo: https://github.com/MemPalace/mempalace (MIT licensed, Python + ChromaDB + SQLite, v3.3.2 at time of adoption)
- MCP server: `python -m mempalace.mcp_server` (registered via `.mcp.json` → `uv tool run --from mempalace`)
