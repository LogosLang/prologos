# `tracks/` — per-Series, per-Track document layout (prologos)

Adopted 2026-10-12 (owner decision), mirroring `lhc/docs/tracking/tracks/README.md`.
**Applies to new work from this date.** The flat `docs/tracking/` corpus (345+ entries
across a dozen series) is NOT being reorganized now — an en-masse move is a separate,
owner-scheduled task (every inbound AND outbound link must be rewritten with counts
asserted; see the lhc README's warning). Until then a Series Master may still live flat
(e.g. `../2026-03-27_PAR_MASTER.md`) with a stub `tracks/<SERIES>/README.md` pointing at it.

```
docs/tracking/
  tracks/<SERIES>/README.md                 ← Series Master (or a stub → the flat master)
  tracks/<SERIES>/<SERIES>_<N>/             ← everything belonging to one track, incl. handoffs
    LOG.md                                  ← ⭐ the track's own log (append-only; see below)
    YYYY-MM-DD_<SERIES>_<N>_<KIND>.md       ← audit / design / critique / probe / PIR / handoff
    research/phase<N>/                      ← that track's per-phase premise probes
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
  LOG entry (`→ tracks/PAR/PAR_4/LOG.md § <headline>`) rather than restating it.
- Relay notes and handoffs are unchanged: a handoff lives in the track directory.

## Naming

Filenames name the track as `<SERIES>_<N>`, never `<SERIES>_TRACK<N>` (owner decision in
lhc, 2026-08-17): `2026-10-12_PAR_4_STAGE2_GAP_ANALYSIS.md`, matching the directory
`PAR_4/` and the citation form `PAR 4, Stage 2`. Series are **owner-designated** and appear on
`MASTER_ROADMAP.org`; a session does not coin one.

Current: `tracks/PAR/PAR_4/` — PAR Track 4, Arena Executors (Stage 1 + Stage 2 written; D.1 next). Stage-1 research artifacts live in the track's `research/` subdirectory, named `…_STAGE1_<TOPIC>.md`.
