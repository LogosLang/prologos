# BSP-LE 3 — Log

Append-only, newest at the bottom. Entry shape: `### <outcome headline> — \`hash\` (date)` with **Why / decision**,
**Surprise / correction**, **Next** (`docs/tracking/principles/DAILIES_METHODOLOGY.org`; log names follow the owner's
convention `{SERIES}_{TRACK}_LOG.md`).

**Earlier history** (before this directory existed) lives in the flat corpus: the BSP-LE master
(`docs/tracking/2026-03-21_BSP_LE_MASTER.md`, §Track 3), the Track 3 seed
(`docs/tracking/2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md`), and DEFERRED's two Rel T1 scaffolding sections. The track
had no design and no commits.

### BSP-LE 3 opened, with Stage A (the ATMS label semantics, DEFERRED 177's fix) placed first by owner decision (PAR 4 O-17 (a)) — docs commit on the branch (2026-10-19)
- **Why / decision**:
  - PAR 4's D.3 critique found that the shipped ATMS solver returns answers DFS rejects. The defect is DEFERRED 177:
    three rows plus two more shapes, all schedule-independent and reachable with one `not` goal under `:auto`.
  - The owner asked to find the track that owns the fix, and to start it concurrently. No BSP-LE row held it, so the
    PAR 4 session posed the question as O-17.
  - The owner chose (a): *"Ok, with BSP-LE 3 (a). Good to generate the kickoff."*
  - Track 3's own design reads tables by support set (PUnify Part 3 §9.6), which is the same lattice as the fix's
    label read. Its retirement obligations, Check 3 and Check 4, need the same gating instrument, the DFS-vs-ATMS
    differential.
- **Setup** by the PAR 4 session:
  - PAR 4 checkpoint 3 (`dba9f502`, docs only) so that O-16 and O-17 are on main.
  - DEFERRED 177's addendum recording the decision (main `99cbd9f5`).
  - This worktree from main `99cbd9f5`, built with the limit: `.zo` equal to main's for `reduction`, `driver`,
    `propagator`, `relations`, `decision-cell` and `atms`. `timings.jsonl` copied.
  - The three probes behind 177 re-run on main's code: the same wrong answers.
- **Records**:
  - the kickoff [`2026-10-19_BSP_LE_3_KICKOFF.md`](2026-10-19_BSP_LE_3_KICKOFF.md): the charter, the inputs, the
    contract with PAR 4, PPN 4C and PAR 4B, the method by stage, and Stage 1's differential and survey;
  - the series stub [`../README.md`](../README.md), which carries the proposed master and roadmap edits, unapplied.
- **Next**: a fresh session runs the kickoff's §0, reads in its §6 order, summarises back to the owner, and waits for
  confirmation before Stage 1's measurements.
