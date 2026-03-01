# Workflow

- Stage with `git add`, commit with `git commit`
- **`my_notes.org` and `my_notes.md` are READ ONLY** -- read for context, never modify
- **Feature tracking** -- create `docs/tracking/YYYY-MM-DD_HHMM_TOPIC.md` before implementation; update after completion
- **Phase subdivision** -- break large phases into a/b/c sub-phases; track done vs remaining explicitly
- **Daily summaries** -- maintain `docs/tracking/standups/YYYY-MM-DD_dailies.md` as a living document throughout the day. Create early in the session; update as work progresses (completed items, in-progress work, considerations, blockers). The current day's dailies are Claude's daily report-outs (parallel to the user's standups); prior day's dailies are read only records.
- **Link commits in documentation** -- when updating dailies, DEFERRED.md, or tracking docs to mark work complete, include a reference to the commit hash (e.g., `(commit abc1234)`). This provides traceability from docs to code and serves as a reminder to commit before documenting.
- **Print commit hash after large changes** -- after committing substantial code changes (new features, multi-file modifications, phase completions), print the commit hash so it's visible in the conversation for reference and traceability.
