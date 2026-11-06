# CIU — Collection Interface Unification (Series Master stub)

The Series Master is still the flat [`2026-03-21_CIU_MASTER.md`](2026-03-21_CIU_MASTER.md)
(thesis, the Track 0–6 + 4B tracker, track scope summaries, cross-series dependencies). It
moves here when the tracking corpus is reorganized en masse (owner-scheduled; see
[`../README.md`](../README.md)). Until then this file indexes the track directories that exist
in the new layout and, for each, the flat documents that remain its record.

| Track | Directory | State |
|---|---|---|
| 6 — Anonymous Records, Collections & Path Selection | [`CIU_6/`](CIU_6/) · log: [`CIU_6/CIU_6_LOG.md`](CIU_6/CIU_6_LOG.md) | 🔄 Path Selection, phase P4e (the `*` family): slice 1b-v-C ✅ `a492bbb7`; **1b-vi 🔄 opened 2026-10-13** — [grounding audit](CIU_6/audits/2026-10-13_CIU_6_P4e-1b-vi_GROUNDING_AUDIT.md), D4 Q_U55 pending. Work continues on branch `ciu6-path-selection` (nested worktree `.claude/worktrees/ciu6-path-selection`); per owner decision W-1 the track's documents ride the branch and reach `main` at checkpoint merges |

Tracks 0–5 and 4B have no directory: none has been worked since the layout was adopted.

## CIU 6 — documents of record that stay flat

The track ran 2026-07-05 → 2026-09-08 before this directory existed. Nothing is moved (a move
breaks links in both directions); new CIU 6 artifacts go in `CIU_6/`, and `CIU_6/CIU_6_LOG.md` is
the journal from 2026-10-13 on.

| Document | Role |
|---|---|
| [`CIU_6/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md`](CIU_6/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md) | Track doc — decisions D1–D29 (§2a rounds 1–7) |
| [`CIU_6/2026-07-06_CIU_T6_F1_STRUCTURAL_RECORDS_DESIGN.md`](CIU_6/2026-07-06_CIU_T6_F1_STRUCTURAL_RECORDS_DESIGN.md) · [D.3 critique](CIU_6/critiques/2026-07-06_CIU_T6_F1_STAGE3_CRITIQUE_D3.md) · [F1b PIR](CIU_6/2026-07-19_CIU_T6_F1B_PIR.md) | F1 (records / `Map`↔schema seal / validate) — COMPLETE |
| [`CIU_6/2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md`](CIU_6/2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md) · [D.3 critique](CIU_6/critiques/2026-07-26_CIU_T6_PATH_SELECTION_D3_CRITIQUE.md) | Path Selection D.2 — closed as the record of rounds 1–8b; surface superseded by the spec |
| [`CIU_6/2026-07-28_path-selection-spec.md`](CIU_6/2026-07-28_path-selection-spec.md) | The normative surface — a guide, not a prescription |
| [`CIU_6/2026-07-28_CIU_T6_PATH_SELECTION_D4.md`](CIU_6/2026-07-28_CIU_T6_PATH_SELECTION_D4.md) | **D4 — the live implementation design**: Progress Tracker, §3 decision ledger (Q_L…Q_U54), §5 per-phase records. Link by anchor (`#q-u52`, `#p4e-1b-sequencing`), never by line |
| [`CIU_6/research/2026-08-09_STAR_SURFACE_CENSUS.md`](CIU_6/research/2026-08-09_STAR_SURFACE_CENSUS.md) | The `*` family's measured input |
| `../../handoffs/*CIU_T6*`, `*CIU_TRACK6*` (15 files, latest [`2026-08-11_CIU_T6_P4e-1b_handoff.md`](CIU_6/handoffs/2026-08-11_CIU_T6_P4e-1b_handoff.md)) | Session handoffs |
| `../../standups/2026-07-05 … 2026-09-08_dailies.md` | The journal before `CIU_6/CIU_6_LOG.md` (STATE of record at resume: `2026-09-08_dailies.md`) |
| `racket/prologos/tests/test-path-selection.rkt` · `racket/prologos/examples/2026-07-26-ciu-t6-path-selection.prologos` · `racket/prologos/tools/star-arrival-matrix.rkt` | Battery · acceptance file (`tools/run-file.rkt --check`) · the star arrival matrix |

## Proposed edits to owner-owned surfaces — UNAPPLIED (2026-10-13)

Found while opening the directory; nothing below has been edited.

1. **`MASTER_ROADMAP.org` §CIU → Tracks table** lists Tracks 0–5 only. Track 6 (🔄) and
   Track 4B (⬜, chartered in D4) appear only in the Status prose, and the Track 2 row says ⬜
   where the series master marks it ⛔ superseded by Track 6 (Track 3 is re-chartered there
   too). Proposed: add rows 4B and 6, mark 2 ⛔ and 3 re-chartered, matching the series
   master's tracker.
2. **Stale position, both masters.** The roadmap's CIU Status cell and the series master's
   header status both end at the P4d close (2026-08-08, "NEXT = P4e"); the roadmap's
   *Last updated* line names P4d slice 4c. Since then P4e-0 slice A, P4e-1a, and P4e-1b
   slices i–v plus 1b-v-C have shipped (D4 tracker, row P4e). Proposed: one status sentence
   ("P4e-1b through 1b-v-C ✅ `a492bbb7`; 1b-vi next") plus a pointer to `tracks/CIU/CIU_6/`.
3. **Series master Track 6 row** (tracker table): add the directory link beside the existing
   design-doc links.
