# `tracks/` — per-Series, per-Track document layout (prologos)

Adopted 2026-10-12 (owner decision), mirroring `lhc/docs/tracking/tracks/README.md`.
**Applies to new work from this date.** The flat `docs/tracking/` corpus (345+ entries
across a dozen series) is reorganized only when the owner schedules a move (every inbound AND
outbound link must be rewritten with counts asserted; see the lhc README's warning). Until a
series moves, its Series Master may still live flat
(e.g. `../2026-03-27_PAR_MASTER.md`) with a stub `tracks/<SERIES>/README.md` pointing at it.

**Moved so far**: **PPN** (2026-10-13, `34ad559d`; research symlinks `71a4ab01`) — 61 documents
into [`PPN/`](PPN/), 1 840 citations rewritten in 129 files, verified by
[`tools/check-xlinks.py`](../../../tools/check-xlinks.py) (links before = after = 3 791; broken
144 → 121, the 23 repaired; 0 new). Basenames were kept (a pure directory move), so a moved
file is still found by its old name. The procedure, the decisions and what it found:
[`PPN/README.md`](PPN/README.md) and [`PPN/PPN_4C/LOG.md`](PPN/PPN_4C/LOG.md) § *The PPN series
moves into `tracks/PPN/`*.

**Moving the next series** — what the PPN move measured:
- Census before moving: every md/org link whose target resolves to a moved file, every
  relative link INSIDE a moved file (it must keep the absolute location it resolved to, even a
  broken one), every bare repo path (`docs/tracking/…`) in prose, code comments and banners, and
  the bare basenames (unchanged under a basename-preserving move). Leave raw outputs under
  `racket/prologos/data/` as printed.
- Run `tools/check-xlinks.py --json` before and after, and assert the after-set equals the
  before-set mapped through the move minus the links deliberately repaired. A pre-existing broken
  link that clearly names a moved file is repaired and listed; one whose intent is ambiguous is
  left and named.
- `git mv` in one commit; anything placed at a vacated path (a symlink) in a LATER commit, or the
  rename becomes "typechange + add" and `git log --follow` loses the history.
- Exclude symlinks from every scan: an alias's relative links resolve from the real file.

```
docs/tracking/
  tracks/<SERIES>/README.md                 ← Series Master (or a stub → the flat master, or an index)
  tracks/<SERIES>/<SERIES>_<N>/             ← everything belonging to one track, incl. handoffs
    LOG.md                                  ← ⭐ the track's own log (append-only; see below)
    YYYY-MM-DD_<SERIES>_<N>_<KIND>.md       ← audit / design / critique / probe / PIR / handoff
    research/phase<N>/                      ← that track's per-phase premise probes
  tracks/<SERIES>/research/                 ← single-series research (PPN: moved from docs/research/)
  standups/YYYY-MM-DD_dailies.md            ← cross-track dailies (STATE head + sparse LOG)
```

## The per-track LOG (new here; not in lhc's README)

Work on several tracks interleaves within a day, and a single dailies LOG makes each
track's reasoning hard to follow. So **the decision/surprise journal moves to the track**:

- `tracks/<SERIES>/<SERIES>_<N>/LOG.md` — append-only, newest at the bottom, entries in
  the dailies' shape: `### <outcome headline> — \`hash\` (date)` with **Why / decision**,
  **Surprise / correction**, **Next**. One entry per commit or per decision/surprise.
- The **dailies keep the STATE head** (the re-grounding surface — HEAD, suite, where we
  are, NEXT, blockers, watching) and a **sparse LOG** whose entries POINT at the track
  LOG entry (`→ tracks/PAR/PAR_4/PAR_4_LOG.md § <headline>`) rather than restating it.
- Relay notes and handoffs are unchanged: a handoff lives in the track directory.

## Naming

Filenames name the track as `<SERIES>_<N>`, never `<SERIES>_TRACK<N>` (owner decision in
lhc, 2026-08-17): `2026-10-12_PAR_4_STAGE2_GAP_ANALYSIS.md`, matching the directory
`PAR_4/` and the citation form `PAR 4, Stage 2`. Series are **owner-designated** and appear on
`MASTER_ROADMAP.org`; a session does not coin one. A MOVED file keeps its old basename (PPN's
`…_PPN_TRACK4C_DESIGN.md`); new files in a moved series follow the rule.

Current: `tracks/PAR/PAR_4/` — PAR Track 4, Arena Executors (D.2 and its D.3 critique written; D.3 next).
`tracks/PAR/PAR_4B/` — PAR Track 4B, the parallel and distributed architecture portfolio (opened 2026-10-18 on branch
`par4b-parallelism-portfolio`; Stage 1 next). Stage-1 research artifacts live in the track's `research/` subdirectory, named `…_STAGE1_<TOPIC>.md`.
`tracks/CIU/CIU_6/` — CIU Track 6, Anonymous Records, Collections & Path Selection: a track
already deep in implementation when the layout arrived (2026-10-13). Its flat documents of
record stay where they are and are indexed in `tracks/CIU/README.md`; the directory holds the
LOG from 2026-10-13 on and any new artifacts.
`tracks/PPN/PPN_4C/` — PPN Track 4C, Elaboration completely on-network: resumed 2026-10-13 on
branch `ppn4c-elaboration-on-network` after four months parked (addendum Phase 4B.5.b next). Its
whole record moved here with the series; the LOG starts with where the earlier history lives.
`tracks/BSP-LE/BSP-LE_3/` — BSP-LE Track 3, Tabling, opening with Stage A, the ATMS label semantics (DEFERRED 177's
fix), placed there by owner decision on 2026-10-19 (PAR 4 O-17 (a)). Opened on branch `bsple3-tabling`; Stage 1 next.
The series master stays flat and is indexed in `tracks/BSP-LE/README.md`; the directory name follows the corpus's
`BSP_LE` filenames.
