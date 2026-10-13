# PPN — Propagator-Parsing-Network (series directory)

The first series moved out of the flat `docs/tracking/` corpus into the per-track layout
([`../README.md`](../README.md)). Moved 2026-10-13 at `34ad559d` (owner-scheduled), with the
research symlinks at `71a4ab01`; the procedure and its counts are in that commit message and in
[`PPN_4C/LOG.md`](PPN_4C/LOG.md) § *The PPN series moves into `tracks/PPN/`*.

**The Series Master keeps its name**: [`2026-03-26_PPN_MASTER.md`](2026-03-26_PPN_MASTER.md)
(thesis, §1 Progress Tracker, track details, cross-series connections). This README is an index
of where things are, not a second master — the status column below copies the master's §1
tracker and defers to it.

**Filenames are unchanged.** The move kept every basename (`PPN_TRACK4C_DESIGN`, not the
`PPN_4C_DESIGN` the layout's naming rule would give a new file), so a basename cited in a commit
message, a code comment or an old dailies still finds the file with `find docs -name`. Renaming
to the convention remains open; new files here follow it (`YYYY-MM-DD_PPN_<N>_<KIND>.md`).

## Tracks

| Track | Directory | Documents | Master §1 |
|---|---|---|---|
| 0 — Lattice design | [`PPN_0/`](PPN_0/) | [design](PPN_0/2026-03-26_PPN_TRACK0_LATTICE_DESIGN.md) · [PIR](PPN_0/2026-03-26_PPN_TRACK0_PIR.md) | ✅ |
| 1 — Lexer + structure as propagators | [`PPN_1/`](PPN_1/) | [design](PPN_1/2026-03-26_PPN_TRACK1_DESIGN.md) · [Stage-2 audit](PPN_1/2026-03-26_PPN_TRACK1_STAGE2_AUDIT.md) · [PIR](PPN_1/2026-03-26_PPN_TRACK1_PIR.md) | ✅ |
| 2 — Surface normalization as rewriting | [`PPN_2/`](PPN_2/) | [design](PPN_2/2026-03-28_PPN_TRACK2_DESIGN.md) · [Stage-2 audit](PPN_2/2026-03-28_PPN_TRACK2_STAGE2_AUDIT.md) · [PIR](PPN_2/2026-03-29_PPN_TRACK2_PIR.md) | ✅ |
| 2B — Production deployment + mixfix | [`PPN_2B/`](PPN_2B/) | [design](PPN_2B/2026-03-30_PPN_TRACK2B_DESIGN.md) · [PIR](PPN_2B/2026-03-30_PPN_TRACK2B_PIR.md) | ✅ |
| 3 — Parser as propagators | [`PPN_3/`](PPN_3/) | [design](PPN_3/2026-04-01_PPN_TRACK3_DESIGN.md) · [Stage-2 audit](PPN_3/2026-04-01_PPN_TRACK3_STAGE2_AUDIT.md) · [PIR](PPN_3/2026-04-02_PPN_TRACK3_PIR.md) | ✅ (see the master's Track 3 row for the 2026-08-02/03 corrections) |
| 3.5 — Grammar Form R&D | [`PPN_3.5/`](PPN_3.5/) | [design thinking](PPN_3.5/2026-04-03_GRAMMAR_FORM_DESIGN_THINKING.md); vision research stays cross-series: [`grammar` form](../../../research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md) | ⬜ |
| 4A — Typing on-network | [`PPN_4A/`](PPN_4A/) | [design D.4](PPN_4A/2026-04-04_PPN_TRACK4_DESIGN.md) · [Stage-2 audit](PPN_4A/2026-04-04_PPN_TRACK4_STAGE2_AUDIT.md) · [PIR](PPN_4A/2026-04-04_PPN_TRACK4_PIR.md) — the files say `TRACK4`; the master labels the track 4A | ✅ |
| 4B — Full attribute evaluation | [`PPN_4B/`](PPN_4B/) | [design D.2](PPN_4B/2026-04-05_PPN_TRACK4B_DESIGN.md) · [PIR](PPN_4B/2026-04-07_PPN_TRACK4B_PIR.md) | ✅ |
| **4C — Elaboration completely on-network** | [`PPN_4C/`](PPN_4C/) · log: [`PPN_4C/LOG.md`](PPN_4C/LOG.md) | see below | 🔄 |
| 4D — Attribute Grammar Substrate Unification | [`PPN_4D/`](PPN_4D/) | [implementation draft note](PPN_4D/2026-05-19_PPN_4D_IMPLEMENTATION_DRAFT_NOTE.md) · vision: [research/](research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md) | ⬜ |
| 5–9 | — | none yet | ⬜ |

Series-level, not yet a track: [`2026-06-30_NUMERICS_ON_NETWORK_PPN_NOTE.md`](2026-06-30_NUMERICS_ON_NETWORK_PPN_NOTE.md)
(numeric typing on-network, spawned by the Numerics track for a future PPN track).

## PPN 4C — three design documents, one track

4C's record is spread over three designs, which is the main thing a reader needs to know:

| Document | Role | State |
|---|---|---|
| [`2026-04-17_PPN_TRACK4C_DESIGN.md`](PPN_4C/2026-04-17_PPN_TRACK4C_DESIGN.md) (D.3) | The **parent** design: thesis, 9 axes, the Phase 0–12/T/V tracker (§2) | Phases 9, 10, 11 absorbed by the addendum (✅); 1.5, 2, 2b, 1d–1V ✅; 1 and 3 🔄; 4–8, 9b, 11b, 12a–d, 13, T, V ⬜ |
| [`2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](PPN_4C/2026-04-21_PPN_4C_PHASE_9_DESIGN.md) | The **addendum** "Substrate + Orchestration Unification" (parent Phases 9+10+11, renumbered 1–4 + V). §3 is its tracker; §18 holds Phase 4 (top-level orchestration) | **The live document.** Phases 1–3 ✅; Phase 4: 4A ✅, 4B.0–4B.5.a ✅, **4B.5.b next** |
| [`2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md`](PPN_4C/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) | The **tropical quantale addendum** (addendum Phases 1B/1C: tropical fuel, specialized cell framework, D.4 canonical) | Closed — [PIR](PPN_4C/2026-05-17_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_PIR.md) 2026-05-17 |

Around them: the parent's [Stage-2 audit](PPN_4C/2026-04-17_PPN_TRACK4C_AUDIT.md),
[Pre-0 report](PPN_4C/2026-04-17_PPN_TRACK4C_PRE0_REPORT.md),
[self-critique](PPN_4C/2026-04-17_PPN_TRACK4C_SELF_CRITIQUE.md) and
[external critique](PPN_4C/2026-04-18_PPN_TRACK4C_EXTERNAL_CRITIQUE.md); the addendum's
[Stage-2 audit](PPN_4C/2026-04-21_PPN_4C_PHASE_9_AUDIT.md) and
[Step 2 baseline](PPN_4C/2026-04-23_STEP2_BASELINE.md); the tropical addendum's
[critiques](PPN_4C/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md),
[Pre-0 plan](PPN_4C/2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md) and
[1C-vi A/B/C report](PPN_4C/2026-05-16_TROPICAL_1C_VI_ABC_REPORT.md); and 20 session handoffs
(`*_HANDOFF.md`, `*_handoff.md`, the [kickoff](PPN_4C/2026-04-17_PPN_4C_KICKOFF.md)), latest
[2026-05-26 Phase 4A](PPN_4C/2026-05-26_PPN_4C_ADDENDUM_PHASE_4A_handoff.md). Phase 4B was
journalled in the dailies (rewind checkpoints 15–22), not in handoffs — see the LOG's first entry.
The stage-0 design note is in [`research/`](research/2026-04-07_PPN_TRACK4C_DESIGN_NOTE.md).

## `research/`

Single-series PPN research, moved from `docs/research/` (owner decision 2026-10-13):
[Lattice Foundations](research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md) (Tracks 0, 3, 5) ·
[Attribute Grammars research](research/2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md) and
[The Prologos Attribute Grammar](research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md) (4B) ·
[4C design note](research/2026-04-07_PPN_TRACK4C_DESIGN_NOTE.md) ·
[Attribute Grammar Unification vision](research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md) (4D).

Each has a **symlink at its old path** in `docs/research/` so browsing that directory still
finds it. Every link in the repo names the real path here. ⚠ Open a document through its real
path: its relative links are written for this directory, and an editor that keeps the alias's
directory as the buffer's directory (Emacs with `find-file-visit-truename` nil, the default)
resolves 19 of the 5 documents' 20 links to nothing.

**Stays cross-series in `docs/research/`**: tropical quantales (PPN 4C + PReduce + SH), the
`grammar` toplevel form (PPN + PRN), Kan/ATMS/GFP parsing, adhesive categories, hypergraph
rewriting, module theory. **Stays flat in `docs/tracking/`**: the standalone
`2026-06-03_SCHEDULER_ODIFF_OPTIMIZATION.md` (surfaced by 4C Phase 4B, scoped by itself as not
part of it) and the PM 12/12B/13 notes (PM series). Code-side artifacts stay with the code: the
acceptance file `racket/prologos/examples/2026-04-17-ppn-track4c.prologos`, the benches
`racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt` and `bench-tropical-fuel.rkt`, and
`racket/prologos/data/` (raw outputs — the one path a raw output printed was left as printed).

## Proposed edits to owner-owned surfaces — UNAPPLIED (2026-10-13)

Found while moving; the move itself changed only link targets in these files.

1. **`MASTER_ROADMAP.org` § PPN, row 4C** (line 511) says "Phase 1E + Phase 2 + Phase 3 +
   Phase V + parent CHAMP retirement remain", and the sequencing list (line 881) "PPN 4C remaining
   phases (after Phase 1C lands — Phase 1E, Phase 2, Phase 3 union types via ATMS)". Per the
   addendum's §3 tracker: 1E was deferred to 4D (2026-05-19), Phase 2 closed at 2V, Phase 3 at 3V
   (2026-05-25), Phase 4A closed 2026-06-01, 4B.0–4B.5.a closed by 2026-06-10. Proposed: one
   status sentence ("addendum Phases 1–3 ✅, 4A ✅, 4B.5.a ✅ `2d791705`; 4B.5.b next") and a
   pointer to `tracks/PPN/PPN_4C/`.
2. **Series master header** `**Status**: Active (Stage 0-1 research, Track 0 design pending)` —
   stale since Track 0 closed (2026-03-26). Proposed: "Active — Tracks 0–4B ✅, 4C 🔄 (addendum
   Phase 4B), 4D ⬜".
3. **Series master §1 row 4C** links the design note, audit and D.1 only. Proposed: add the
   addendum and tropical-addendum designs, the directory, and the position (as in item 1).
