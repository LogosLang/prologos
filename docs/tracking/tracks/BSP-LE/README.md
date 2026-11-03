# BSP-LE — The Logic Engine, realized on propagators (series directory)

The series moved out of the flat `docs/tracking/` corpus into the per-track layout ([`../README.md`](../README.md))
on 2026-10-19 at `18b94286` (owner-scheduled, in the BSP-LE 3 session), with the research symlinks at `5674e875`. The
procedure, the owner's decisions and the counts are in the `18b94286` commit message and in
[`BSP-LE_3/LOG_BSP-LE_3.md`](BSP-LE_3/LOG_BSP-LE_3.md) § *The BSP-LE series moves into `tracks/BSP-LE/`*.

**The Series Master keeps its name**: [`2026-03-21_BSP_LE_MASTER.md`](2026-03-21_BSP_LE_MASTER.md) (thesis, the
Progress Tracker, track scope summaries, dependencies). This README is an index of where things are, not a second
master; the status column copies `MASTER_ROADMAP.org` §BSP-LE and defers to it.

**Naming** (owner decision, 2026-10-19):
- directories are `BSP-LE_<N>/`, with the series' prose spelling;
- the track log is `LOG_BSP-LE_<N>.md`. This is BSP-LE only; other series keep their own log names (`PAR_4_LOG.md`,
  `PPN4C_LOG.md`, CIU 6's `LOG.md`);
- new files are `YYYY-MM-DD_BSP-LE_<N>_<KIND>.md`;
- moved files keep their basenames (`…_BSP_LE_TRACK2_DESIGN.md`), so a basename cited in a commit message, a code
  comment or an old dailies still finds the file. Both spellings therefore occur in this directory; search with
  `BSP[-_]LE`.

Each track directory keeps its designs, PIRs and the measurement documents they cite at its root, with `handoffs/`,
`critiques/` and `audits/` subdirectories for the historical context.

## Tracks

| Track | Directory | Documents | Roadmap status |
|---|---|---|---|
| 0 — Allocation Efficiency | [`BSP-LE_0/`](BSP-LE_0/) | [design](BSP-LE_0/2026-03-21_BSP_LE_TRACK0_ALLOCATION_EFFICIENCY_DESIGN.md) · [PIR](BSP-LE_0/2026-03-21_BSP_LE_TRACK0_PIR.md) · [Phase 3a struct-copy classification](BSP-LE_0/2026-03-21_PHASE3A_STRUCT_COPY_CLASSIFICATION.md) · CHAMP Performance [design](BSP-LE_0/2026-03-21_CHAMP_PERFORMANCE_DESIGN.md) · [PIR](BSP-LE_0/2026-03-21_CHAMP_PERFORMANCE_PIR.md) · audits: [allocation](BSP-LE_0/audits/2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md), [CHAMP](BSP-LE_0/audits/2026-03-21_CHAMP_PERFORMANCE_AUDIT.md) | ✅ (the master's tracker still says ⬜; see the proposed edits below) |
| 1 — UnionFind | none | (no documents) | ⬜ |
| 1.5 — Cell-Based TMS | folded into 2 | [design note](research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md) | folded into Track 2 |
| 2 — ATMS Solver + Cell-Based TMS | [`BSP-LE_2/`](BSP-LE_2/) | [design](BSP-LE_2/2026-04-07_BSP_LE_TRACK2_DESIGN.md) · [PIR](BSP-LE_2/2026-04-10_BSP_LE_TRACK2_PIR.md) · [Stage 1/2 audit](research/2026-04-07_BSP_LE_TRACK2_STAGE1_AUDIT.md) · critiques: [self](BSP-LE_2/critiques/2026-04-07_BSP_LE_TRACK2_SELF_CRITIQUE.md), [external](BSP-LE_2/critiques/2026-04-08_BSP_LE_TRACK2_EXTERNAL_CRITIQUE.md) · handoffs: [hypercube](BSP-LE_2/handoffs/2026-04-08_BSP_LE_TRACK2_HYPERCUBE_handoff.md), [2026-04-09 session](BSP-LE_2/handoffs/2026-04-09_2300_session_handoff.md) | ✅ |
| 2B — Parity Deployment + Parallel + On-Network | [`BSP-LE_2B/`](BSP-LE_2B/) | [design D.13](BSP-LE_2B/2026-04-10_BSP_LE_TRACK2B_DESIGN.md) · [PIR](BSP-LE_2B/2026-04-16_BSP_LE_TRACK2B_PIR.md) · [hypercube addendum](research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) · critiques: [self](BSP-LE_2B/critiques/2026-04-10_BSP_LE_TRACK2B_SELF_CRITIQUE.md), [external](BSP-LE_2B/critiques/2026-04-10_BSP_LE_TRACK2B_EXTERNAL_CRITIQUE.md), [response](BSP-LE_2B/critiques/2026-04-10_BSP_LE_TRACK2B_CRITIQUE_RESPONSE.md) · handoffs: [04-13](BSP-LE_2B/handoffs/2026-04-13_BSP_LE_2B_HANDOFF.md), [04-16](BSP-LE_2B/handoffs/2026-04-16_BSP_LE_2B_HANDOFF.md) | ✅ |
| 3 — Tabling (SLG memoization), opening with Stage A: the ATMS label semantics (DEFERRED 177's fix) | [`BSP-LE_3/`](BSP-LE_3/) | [seed](BSP-LE_3/2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md) · [kickoff](BSP-LE_3/handoffs/2026-10-19_BSP-LE_3_KICKOFF.md) · log: [`LOG_BSP-LE_3.md`](BSP-LE_3/LOG_BSP-LE_3.md) | 🔄 opened 2026-10-19 by owner decision (PAR 4 O-17 (a)); Stage 1 next. Branch `bsple3-tabling` (nested worktree `.claude/worktrees/bsple3-tabling`); under owner decision W-1 the track's documents ride the branch and reach `main` at checkpoint merges |
| 4 — BSP Pipeline | none | — | superseded by the PAR series |
| 5 — Solver Language | none | — | ⬜ |
| 6-future — General Residual Solver | none | master §Track 6-future | ⬜ |

**Research** ([`research/`](research/)): the three single-series notes above. `docs/research/` keeps symlinks to them
for browsing; every repo link names the real path here.

**Stays flat**, because it is cross-series: the origin documents
([`../../2026-02-24_LOGIC_ENGINE_DESIGN.org`](../../2026-02-24_LOGIC_ENGINE_DESIGN.org),
[`../../2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md`](../../2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md))
and the research that only touches BSP-LE (Kan extensions / ATMS / GFP, parallel propagator scheduling, module theory).

## BSP-LE 3: documents of record outside its directory

| Document | Role |
|---|---|
| [`2026-03-21_BSP_LE_MASTER.md`](2026-03-21_BSP_LE_MASTER.md) `:55`, `:142-187` | Track 3's row and scope, with its two retirement obligations |
| [`../../2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md`](../../2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md) §9, §9.6 | Tabling design and support-set tables (designed, never built) |
| `../../DEFERRED.md` §177 (and §157's addenda, §184) | The defect, its fix shape, and the decisions placing it here |

## Proposed edits to owner-owned surfaces — UNAPPLIED (2026-10-19)

Items 1–3 have not been edited. Item 4 is an index, applied on the branch.

1. **BSP-LE master, track table row 3** (`:55`): add "**Stage A: ATMS label semantics (DEFERRED 177; PAR 4 O-17
   (a), 2026-10-19)**: checkpointed before tabling", set the status to 🔄, and link this directory. **Staleness found
   during the move**: the same table's row 0 (`:47`) still reads ⬜ "Pending", while `MASTER_ROADMAP.org`'s BSP-LE row
   0 reads ✅ with the design, PIR and CHAMP Performance documents; proposed: set row 0 to ✅ with links into
   `BSP-LE_0/`.
2. **BSP-LE master, §Track 3** (`:142-187`): a short Stage A paragraph naming the six fix parts, the DFS-vs-ATMS
   differential as the gate shared with the retirement obligations, and the read rule pinned to label ⊆ W for both
   answers and tables (§9.6's "consistent with W" is weaker).
3. **`MASTER_ROADMAP.org` §BSP-LE**: the Status line (`:77`) adds "Track 3 opened 2026-10-19 (Stage A: DEFERRED 177's
   fix)", and the Tracks table row 3 (`:89`) changes from ⬜ to 🔄.
4. **`tracks/README.md`**: the "Current" list gains `tracks/BSP-LE/BSP-LE_3/` (applied in the kickoff commit), and
   "Moved so far" gains BSP-LE (applied with the move).
