# CIU 6 — track LOG (append-only, newest at the bottom)

CIU Track 6 — Anonymous Records, Collections & Path Selection. Entry shape is the dailies'
(`../../../principles/DAILIES_METHODOLOGY.org`): `### <outcome headline> — \`hash\` (date)` with
**Why / decision**, **Surprise / correction**, **Next**. The dailies' STATE head stays the
re-grounding surface and its sparse LOG points here. Opened 2026-10-13 under the per-track-log
convention (`../../README.md`); the series stub and the index of the flat documents of record
are in [`../README.md`](../README.md).

### Before this LOG: the journal of record 2026-07-05 → 2026-09-08 — pointer only
- **Where the history is.** Decisions: D4 §3, the ledger
  ([`../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md`](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md),
  Q_L…Q_U54; earlier D1–D29 in the track doc). Per-slice records: D4 §5, by anchor
  (`#p4e-1b`, `#p4e-1b-sequencing`, `#p4e-1b-v-c`, …). The surprise journal: the dailies
  `../../../standups/2026-07-05` → `2026-09-08_dailies.md` (14 files mention the track; the P4e
  arc is in `2026-08-10`, `-08-11`, `-08-12`, `-08-14`, `-08-15`, `-09-08`). Handoffs: 15 under
  `../../../handoffs/` (latest `2026-08-11_CIU_T6_P4e-1b_handoff.md`, written at P4e-1a's close).
- **Position at hand-over** (`2026-09-08_dailies.md` STATE, recorded at `7a0116ec`): Path
  Selection phase P4e (the `*` family), slice **1b-v-C — the fold — ✅** (`24fc1be4` pins ·
  `a492bbb7` the fold): one semantic authority (`postfix-star-sentinel-table`,
  `reader-forms.rkt`) for the reader, the splitter, the printer and `form-deps`. Battery 573 ·
  acceptance 88/88 · arrival matrix `*` and `*_` 209/209, `*-` and `*-_` 0/209 · suite
  10 248 / 488 / 0 (189.0 s, Racket 9.0, old runner).
- **Next at hand-over**: 1b-vi (below).

### CIU 6 resumed in its own worktree; `tracks/CIU/` opened; baseline re-measured on Racket 9.3 — docs commit on main (2026-10-13)
- **Why / decision**: owner — continue CIU 6 "in its own working tree (so not to collide with
  any work that may be coming into `main`)", and track it under `tracks/` with a per-track LOG
  and sparse dailies. Branch **`ciu6-path-selection`** off `main` @ `58241c0c`, nested worktree
  `.claude/worktrees/ciu6-path-selection`; main receives tested checkpoint merges only, never a
  rebase once hashes are cited. Opened `tracks/CIU/README.md` as a stub over the flat series
  master (nothing moved; the flat CIU 6 documents of record are indexed there; three UNAPPLIED
  edits to the roadmap and the master proposed there), this LOG, and rolled the dailies to
  `2026-10-13_dailies.md` (cross-track STATE head + sparse pointers; roll triggers: track shift
  and the 488-line prior file).
- **Re-grounding** (the track's own lesson: re-ground before resuming a parked track). Main
  moved **27 commits** since `7a0116ec`. In `racket/`, they touch `champ.rkt`,
  `decision-cell.rkt`, `driver.rkt`, `propagator.rkt`, `lsp/server.rkt`, the runner
  (`batch-worker`, `run-affected-tests`, `suite-plan`) and six new test files. **None of the
  star family's surfaces moved** (zero commits on `parser.rkt`, `reader-forms.rkt`,
  `parse-reader.rkt`, `macros.rkt`, `syntax.rkt`, `typing-core.rkt`, `typing-errors.rkt`,
  `reduction.rkt`, `pretty-print.rkt`, `elaborator.rkt`, `surface-rewrite.rkt`, the battery,
  the matrix, the acceptance file). The toolchain moved 9.0 → **9.3**, and the runner gained
  whale sharding and working LPT dispatch.
- **Baseline at `58241c0c`, in the worktree** (built with `PLT_CS_COMPILE_LIMIT=1000000`;
  `reduction`/`typing-core`/`elaborator`/`parser` `.zo` byte-identical to main's):

  | gate | 2026-10-13 (9.3) | at hand-over (9.0) |
  |---|---|---|
  | suite `--all --force-rerun` | 10 289 tests / 492 files, 57.4 s, **1 failure** — `test-error-messages` `:465:2`, DEFERRED 160's suite-only flake; alone 44/44 pass | 10 248 / 488 / 0, 189.0 s |
  | battery `test-path-selection.rkt` | 573 test-cases; sharded ×5, 23.5–38.9 s per shard | 573 |
  | acceptance `run-file.rkt --check` | 88 / 88 | 88 / 88 |
  | arrival matrix | `*` 209/209 · `*_` 209/209 · `*-` 0 · `*-_` 0 (the pre-1b-vi state) | same |

  The +41 tests / +4 files are main's (the sweep merge and the runner's tests). The two wall
  times are not a performance comparison: different toolchain, build flags and runner.
- **Surprise / correction**: none in the CIU surfaces. The baseline's one failure is a third
  sighting of DEFERRED 160 (same check, same message as the second); a data point with the
  preserved log was added to that entry.
- **Pending owner decision W-1** (workflow, not a design question): where CIU 6's track
  documents (this LOG, D4's per-slice records) are committed between checkpoint merges — on
  the branch with the code (lean), or on main as PAR 4 does. Shared registers (DEFERRED
  entries, the dailies) go to main either way. Analysis in this session's reply; record the
  answer here.
- **Next**: **1b-vi, the star-collapse slice** (D4 `#p4e-1b-sequencing`, row 1b-vi):
  `*-` ([Q_U48](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u48), total collapse —
  ruled), the `*-_` decision (open), the cont-axis **totality dispatcher** (the six
  `select-star-cont` readers are binary tests on `'flatten-synth`; an unknown cont reads as
  bare `*`), and `typing-errors.rkt`'s prose column (15 formatters spelling `*`/`*_` per kind —
  the printer defect's twin, `#p4e-1b-v-c`). Two owner decisions come first
  ([Q_U52](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u52) §1–2): what total collapse
  does to a **renamed** ancestor (`t4{a^p.b.c*-}`), and the **`*->` token boundary**. Opens
  with the grounding mini-audit, re-deriving those counts at this HEAD.
