# BSP-LE — The Logic Engine, realized on propagators (Series Master stub)

The Series Master is still the flat [`../../2026-03-21_BSP_LE_MASTER.md`](../../2026-03-21_BSP_LE_MASTER.md) (thesis,
the track table, track scope summaries, dependencies). It moves here when the tracking corpus is reorganized en masse,
which the owner schedules (see [`../README.md`](../README.md)). Until then this file indexes the track directories that
exist in the new layout, and the flat documents that remain their record.

The directory name `BSP_LE` follows the corpus's existing BSP-LE filenames (`…_BSP_LE_TRACK2_DESIGN.md`).

| Track | Directory | State |
|---|---|---|
| 3 — Tabling (SLG memoization), opening with Stage A, the ATMS label semantics (DEFERRED 177's fix) | [`BSP_LE_3/`](BSP_LE_3/) · log: [`BSP_LE_3/BSP_LE_3_LOG.md`](BSP_LE_3/BSP_LE_3_LOG.md) | 🔄 opened 2026-10-19 by owner decision (PAR 4 O-17 (a)); [kickoff](BSP_LE_3/2026-10-19_BSP_LE_3_KICKOFF.md); Stage 1 next. Work on branch `bsple3-tabling` (nested worktree `.claude/worktrees/bsple3-tabling`); under owner decision W-1 the track's documents ride the branch and reach `main` at checkpoint merges |

Tracks 0, 2 and 2B (✅), 1 and 5 (⬜), and 4 (superseded by the PAR series) have no directory.

## BSP-LE 3: documents of record that stay flat

| Document | Role |
|---|---|
| [`../../2026-03-21_BSP_LE_MASTER.md`](../../2026-03-21_BSP_LE_MASTER.md) `:55`, `:142-187` | Track 3's row and scope, with its two retirement obligations |
| [`../../2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md`](../../2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md) | Seed (pre-design): the tabled-generator and guard issues, with prototyped mechanisms |
| [`../../2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md`](../../2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md) §9, §9.6 | Tabling design and support-set tables (designed, never built) |
| [`../../2026-04-07_BSP_LE_TRACK2_DESIGN.md`](../../2026-04-07_BSP_LE_TRACK2_DESIGN.md) · [PIR](../../2026-04-10_BSP_LE_TRACK2_PIR.md); [`../../2026-04-10_BSP_LE_TRACK2B_DESIGN.md`](../../2026-04-10_BSP_LE_TRACK2B_DESIGN.md) · [PIR](../../2026-04-16_BSP_LE_TRACK2B_PIR.md) | The ATMS solver that Stage A corrects |
| `../../DEFERRED.md` §177 (and §157's 2026-10-18 addendum, §184) | The defect, its fix shape, and the decision placing it here |

## Proposed edits to owner-owned surfaces — UNAPPLIED (2026-10-19)

Nothing below has been edited.

1. **BSP-LE master, track table row 3** (`:55`): add "**Stage A: ATMS label semantics (DEFERRED 177; PAR 4 O-17
   (a), 2026-10-19)**: checkpointed before tabling", set the status to 🔄, and link this directory.
2. **BSP-LE master, §Track 3** (`:142-187`): a short Stage A paragraph naming the six fix parts, the DFS-vs-ATMS
   differential as the gate shared with the retirement obligations, and the read rule pinned to label ⊆ W for both
   answers and tables (§9.6's "consistent with W" is weaker).
3. **`MASTER_ROADMAP.org` §BSP-LE**: the Status line (`:77`) adds "Track 3 opened 2026-10-19 (Stage A: DEFERRED 177's
   fix)", and the Tracks table row 3 (`:89`) changes from ⬜ to 🔄.
4. **`tracks/README.md`**: the "Current" list gains `tracks/BSP_LE/BSP_LE_3/`. That edit rides this track's branch
   (it is an index, not a roadmap), and is applied in the kickoff commit.
