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
- ❌ **Do NOT use mempalace_add_drawer / mempalace_delete_drawer** unless the user explicitly asks for it. Our commit-linked tracking docs are the source of truth; don't write ephemeral content into the palace in parallel.
- ❌ **Do NOT use mempalace as authoritative** for any decision. Its output is a SEARCH HIT, not a fact. Cross-reference against current dailies/handoff/design-doc sections before using it to inform design or implementation choices.

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

The palace goes stale unless re-mined after doc changes. Practical rule:

- After completing a phase and updating dailies/design-doc/tracker → re-mine the docs dir:
  ```
  mempalace mine ./docs --wing prologos
  ```
  mempalace dedupes on content hash, so re-mines are incremental.
- After a track closes (PIR written) → definitely re-mine.
- Don't sweat real-time freshness. The palace is for lookup, not authority.

Future optimization (not in Phase 2 scope): a git `post-commit` hook that triggers re-mine when `docs/tracking/**` or `docs/research/**` changes. Not a Claude Code hook — a git hook. Silent, no prompt injection.

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
