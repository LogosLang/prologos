# CIU — Collection Interface Unification (series directory)

The series moved out of the flat `docs/tracking/` corpus into the per-track layout ([`../README.md`](../README.md)) on
2026-11-06 at `df724466`, with the research symlinks at `2df6df67`. The move was owner-scheduled in the CIU 6 session
("bring all of the CIU tracks into their respective folder directories, not just for CIU 6"). The procedure, the
owner's decisions and the counts are in the `df724466` commit message and in
[`CIU_6/CIU_6_LOG.md`](CIU_6/CIU_6_LOG.md) § *The CIU series moves into `tracks/CIU/`*.

**The Series Master keeps its name**: [`2026-03-21_CIU_MASTER.md`](2026-03-21_CIU_MASTER.md) (thesis, the Track 0–6 +
4B tracker, track scope summaries, cross-series dependencies). This README is an index of where things are, not a
second master; its status column copies the master's tracker and defers to it and to `MASTER_ROADMAP.org` §CIU.

**Naming**:
- directories are `CIU_<N>/`;
- the track log is `CIU_<N>_LOG.md` (the 2026-10-15 convention: never a bare `LOG.md`);
- new files are `YYYY-MM-DD_CIU_<N>_<KIND>.md`;
- moved files keep their basenames, so a basename cited in a commit message, a code comment or an old dailies still
  finds the file. Three spellings of the track therefore occur in these directories (`CIU_6`, `CIU_T6`,
  `CIU_TRACK6`); search with `CIU_(T|TRACK)?6`.

**Layout of a track directory.** The designs, the PIRs and the measurement documents they cite sit at the root.
`audits/`, `critiques/`, `handoffs/` and `research/` hold the rest.

**What the layout is for** (owner, 2026-11-06): "I'm hoping that each track having it's own directory, will allow us
to keep the design document itself more tight and allow other supplementary documents to co-habitate in the directory
and simply be linked in rather than create so much noise." A design document keeps the design: the target, the
decisions, the plan and the tracker. Audits, per-slice records, probes and deliberations are their own documents
here, linked from it. CIU 6's D4 predates this and is 13 082 lines; its decomposition is proposed in
[`CIU_6/CIU_6_LOG.md`](CIU_6/CIU_6_LOG.md) § *The CIU series moves into `tracks/CIU/`* and is not yet applied.

## Series-level documents

| Document | Role |
|---|---|
| [`2026-03-21_CIU_MASTER.md`](2026-03-21_CIU_MASTER.md) | The Series Master |
| [`2026-03-20_COLLECTION_INTERFACE_AUDIT.md`](2026-03-20_COLLECTION_INTERFACE_AUDIT.md) | Origin: the Stage 2 audit (10 findings, 5 principle violations) |
| [`2026-03-20_COLLECTION_INTERFACE_UNIFICATION_DESIGN.md`](2026-03-20_COLLECTION_INTERFACE_UNIFICATION_DESIGN.md) | Origin: the Stage 2/3 design (propagator-resolved trait dispatch, the Seq protocol, the pre/post PM Track 8 split) |

## Tracks

| Track | Directory | Documents | Master's status |
|---|---|---|---|
| 0 — Trait Hierarchy Design | [`CIU_0/`](CIU_0/) | [Trait hierarchy audit](CIU_0/2026-03-21_CIU_TRACK0_TRAIT_HIERARCHY_AUDIT.md) (the track's document of record) | ✅ |
| 1 — Seq Protocol | none | its prerequisite role is set out in CIU 4's seed note | ⬜ |
| 2 — Syntactic Sugar Normalization | none | — | ⛔ superseded by Track 6 |
| 3 — Trait-Dispatched Access | none | — | ⬜ re-chartered (Track 6 took the surface half) |
| 4 — Trait-Dispatched Iteration | [`CIU_4/`](CIU_4/) | [Broadcast trait-dispatch seed note](CIU_4/2026-07-31_CIU_BROADCAST_TRAIT_DISPATCH_NOTE.md) (arms Track 4; Track 1 is its prerequisite) | ⬜ |
| 4B — Broadcast-Propagator Node | none | chartered in CIU 6's D4 | ⬜ |
| 5 — Union-Aware Dispatch | none | — | ⬜ |
| 6 — Anonymous Records, Collections & Path Selection | [`CIU_6/`](CIU_6/) | below · log: [`CIU_6/CIU_6_LOG.md`](CIU_6/CIU_6_LOG.md) | 🔄 Path Selection, phase P4e: P4e-2 (ravel `x:*`) opened 2026-11-03, sub-slice A ✅ `8ecb7cbc`, B next. Branch `ciu6-path-selection` (nested worktree `.claude/worktrees/ciu6-path-selection`); under owner decision W-1 the track's documents ride the branch and reach `main` at checkpoint merges |

## CIU 6 — where things are

| Document | Role |
|---|---|
| [`CIU_6/2026-07-28_CIU_T6_PATH_SELECTION_D4.md`](CIU_6/2026-07-28_CIU_T6_PATH_SELECTION_D4.md) | **D4, the live implementation design**: the Progress Tracker, §3 decision ledger (Q_L…Q_U63), §5 per-phase records. Link by anchor (`#q-u63`, `#p4e-2`), never by line |
| [`CIU_6/2026-07-28_path-selection-spec.md`](CIU_6/2026-07-28_path-selection-spec.md) | The normative surface: a guide, not a prescription |
| [`CIU_6/CIU_6_LOG.md`](CIU_6/CIU_6_LOG.md) | The track journal from 2026-10-13 on; before that, the dailies `../../standups/2026-07-05 … 2026-09-08_dailies.md` (STATE of record at resume: `2026-09-08_dailies.md`) |
| [`CIU_6/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md`](CIU_6/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md) | The track doc: decisions D1–D29 (§2a rounds 1–7) |
| [`CIU_6/2026-07-06_CIU_T6_F1_STRUCTURAL_RECORDS_DESIGN.md`](CIU_6/2026-07-06_CIU_T6_F1_STRUCTURAL_RECORDS_DESIGN.md) · [F1b Stage-3 options](CIU_6/2026-07-16_CIU_T6_F1B_STAGE3_OPTIONS.md) · [F1b probes](CIU_6/2026-07-16_CIU_T6_F1B_STAGE3_PROBES.md) · [F1b PIR](CIU_6/2026-07-19_CIU_T6_F1B_PIR.md) | F1 (records / `Map`↔schema seal / validate): COMPLETE |
| [`CIU_6/2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md`](CIU_6/2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md) | Path Selection D.2, closed as the record of rounds 1–8b; its surface was superseded by the spec |
| [`CIU_6/audits/`](CIU_6/audits/) | [F1b Stage-3 grounding](CIU_6/audits/2026-07-16_CIU_T6_F1B_STAGE3_GROUNDING.md) · [P4e-1b-vi grounding](CIU_6/audits/2026-10-13_CIU_6_P4e-1b-vi_GROUNDING_AUDIT.md) · [P4e-2 grounding](CIU_6/audits/2026-11-03_CIU_6_P4e-2_GROUNDING_AUDIT.md) |
| [`CIU_6/critiques/`](CIU_6/critiques/) | [F1 D.3 critique](CIU_6/critiques/2026-07-06_CIU_T6_F1_STAGE3_CRITIQUE_D3.md) · [Path Selection D.3 critique](CIU_6/critiques/2026-07-26_CIU_T6_PATH_SELECTION_D3_CRITIQUE.md) |
| [`CIU_6/handoffs/`](CIU_6/handoffs/) | 15 session handoffs, 2026-07-05 … 2026-08-11 (latest [`2026-08-11_CIU_T6_P4e-1b_handoff.md`](CIU_6/handoffs/2026-08-11_CIU_T6_P4e-1b_handoff.md)) |
| [`CIU_6/research/`](CIU_6/research/) | [Star-surface census](CIU_6/research/2026-08-09_STAR_SURFACE_CENSUS.md) (the `*` family's measured input) · [row-coalgebra note](CIU_6/research/2026-07-06_ROWS_COALGEBRA_PROPAGATOR_NOTE.md) · per-slice probes: [`P4e-1b-vi/`](CIU_6/research/P4e-1b-vi/), [`P4e-2/`](CIU_6/research/P4e-2/) |
| `racket/prologos/tests/test-path-selection.rkt` · `racket/prologos/examples/2026-07-26-ciu-t6-path-selection.prologos` · `racket/prologos/tools/star-arrival-matrix.rkt` | Battery · acceptance file (`tools/run-file.rkt --check`) · the star arrival matrix |

`docs/research/` keeps symlinks to the spec, the census and the row-coalgebra note, for browsing. Every repo link
names the real path here.

**Stays flat**, because it is not CIU-owned:
- [`../../../research/2026-07-27_PARTIALITY_ABSENCE_DESIGN_SURVEY.md`](../../../research/2026-07-27_PARTIALITY_ABSENCE_DESIGN_SURVEY.md):
  language-wide, though CIU 6 prompted it;
- [`../../2026-07-31_SOLVE_CARRIER_SPINOUT.md`](../../2026-07-31_SOLVE_CARRIER_SPINOUT.md): the REL/CIU seam;
- [`../../2026-08-02_LOC_TO_LINE_MERGE_DEFECT.md`](../../2026-08-02_LOC_TO_LINE_MERGE_DEFECT.md): "Not CIU T6 work — it
  is shared parser machinery";
- the pre-CIU lineage: [`../../2026-03-20_FIRST_CLASS_PATHS_DESIGN.md`](../../2026-03-20_FIRST_CLASS_PATHS_DESIGN.md),
  [`../../2026-02-23_COLLECTIONS_ERGONOMICS_AUDIT.md`](../../2026-02-23_COLLECTIONS_ERGONOMICS_AUDIT.md) and the
  2026-03-02 schema documents.

## Proposed edits to owner-owned surfaces — UNAPPLIED (2026-10-13; refreshed 2026-11-06)

Found while opening the directory; nothing below has been edited.

1. **`MASTER_ROADMAP.org` §CIU → Tracks table** lists Tracks 0–5 only. Track 6 (🔄) and Track 4B (⬜, chartered in D4)
   appear only in the Status prose, and the Track 2 row says ⬜ where the series master marks it ⛔ superseded by Track
   6 (Track 3 is re-chartered there too). Proposed: add rows 4B and 6, mark 2 ⛔ and 3 re-chartered, matching the
   series master's tracker.
2. **Stale position, both masters.** The roadmap's CIU Status cell and the series master's header status both end at
   the P4d close (2026-08-08, "NEXT = P4e"). Since then P4e-0 slice A, P4e-1a, the P4e-1b slices i–vi (checkpoint
   `d2ad3dad`, 2026-11-02) and P4e-2-A have shipped. Proposed: one status sentence ("P4e-1b ✅ `d2ad3dad`; P4e-2, the
   ravel `x:*`, in progress") plus a pointer to `tracks/CIU/`.
3. **Series master tracker**: add a Directory column (`CIU_0/`, `CIU_4/`, `CIU_6/`) beside the existing design-doc
   links.
