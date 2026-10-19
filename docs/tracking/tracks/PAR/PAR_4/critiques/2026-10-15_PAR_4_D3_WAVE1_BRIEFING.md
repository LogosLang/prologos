# PAR 4 D.3 — wave 1 briefing (given verbatim to every critic)

You are one of ten independent critics in the adversarial critique round of a compiler-design document. You work alone;
you will not see the other critics' output. Your job is to find what is **wrong, missing, overstated or weaker than it
could be** in the design, from the one direction you are assigned, and to ground every finding in evidence.

## The project, in five sentences

Prologos is a functional-logic language whose compiler (Racket 9.3, `#lang racket/base`) runs on a **propagator
network**: cells hold lattice values, propagators fire when their inputs change and write joins into cells, and a
scheduler runs them to a fixpoint. The network is **stratified**: S0 is the monotone value stratum; topology changes,
retraction (S(−1)) and negation-as-failure (S1) run sequentially at stratum boundaries. Today's production scheduler
is BSP (bulk-synchronous rounds: snapshot, fire every queued propagator, merge all writes, repeat). PAR 4 ("Arena
Executors") is the track that makes S0 execution as fast as possible, grounded in measurement: DIRECT writes at K = 1,
then K > 1 executors that own cells, exchange deltas and detect quiescence, with the stratum boundary the only
barrier. Correctness is meant to be a property of the architecture (join merges, monotone fires, fixed topology within
an epoch), not of care.

## What to critique

**The design under critique**: `docs/tracking/tracks/PAR/PAR_4/2026-10-15_PAR_4_D2_DESIGN.md` (D.2). Read it in full
first, all sixteen sections. Then read its self-critique,
`docs/tracking/tracks/PAR/PAR_4/critiques/2026-10-15_PAR_4_D2_SELF_CRITIQUE.md`, so that you do not repeat findings
already made. You may *extend* or *contest* them.

**Where**: the git worktree `/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors`, on branch
`par4-arena-executors` at `430e42bb`. Its `racket/prologos/` production code is identical to `main` at `c1f389ab`.
Paths below are relative to the worktree root.

**Inputs D.2 cites** (read what your charge needs):
- `docs/tracking/tracks/PAR/PAR_4/2026-10-12_PAR_4_D1_DESIGN.md`: the first design. §14 is the decisions ledger
  (O-1…O-11, owner guidance G-1…G-3). Appendix A (A.6–A.13) is the observation analysis, Appendix B the O-10 analysis.
- `docs/tracking/tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md`: the Pre-0 measurements. §0 result; §2 the
  corpus; §4 primitives; §5 corrections to D.1; §6 phase gates; §9 the static monotonicity audit (Q1); §10 the
  re-measure; §11 the merge-order census.
- `docs/tracking/tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_DOMAIN_MERGE_LAWS_NOTE.md`: law checks of the merges (M1), the
  defects F1/F2/F3, the checked-join predicate E, the fire-context costs (§7b).
- `docs/tracking/tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_Q1_MONOTONICITY_AUDIT_DRAFT.md`: the 157 audited propagator
  sites. This is an input; the synthesis of record is P0 §9.
- `docs/tracking/tracks/PAR/PAR_4/research/2026-10-12_PAR_4_STAGE1_RESEARCH_SYNTHESIS.md` (theorems T1–T18 with
  hypotheses), `…/research/2026-10-12_PAR_4_STAGE1_CONTENTION_ANALYSIS.md` (60 ns handoff, 0.8 µs barrier, allocation
  ceilings), `…/2026-10-12_PAR_4_STAGE2_GAP_ANALYSIS.md`.
- The principles: `docs/tracking/principles/DESIGN_PRINCIPLES.org` and `docs/tracking/principles/CRITIQUE_METHODOLOGY.org`.
- The rules: `.claude/rules/on-network.md`, `propagator-design.md`, `stratification.md`, `structural-thinking.md`.
- The neighbouring tracks: `docs/tracking/tracks/BSP-LE/BSP-LE_3/2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md` (BSP-LE 3, on-network search). For
  PPN 4C (elaboration on the network), read its branch with `git show
  ppn4c-elaboration-on-network:docs/tracking/tracks/PPN/PPN_4C/PPN4C_LOG.md` (read-only).
- The code: `racket/prologos/propagator.rkt` (the scheduler; `run-to-quiescence-bsp` at :3401, the BSP inner loop at
  :3465), `decision-cell.rkt`, `type-lattice.rkt`, `typing-propagators.rkt`, `relations.rkt`, `metavar-store.rkt`,
  `atms.rkt`, `sre-core.rkt`, `qtt.rkt`.

## The external briefing (CRITIQUE_METHODOLOGY.org, § Orientation for External Critics)

> *Prologos designs are evaluated from a propagator-mindspace.*
> The system's computational model is monotone information flow on a propagator network — not sequential algorithmic
> steps. When reviewing:
> - Do NOT suggest solutions that involve "first do X, then do Y." Instead, suggest what information flows where,
>   through which cells.
> - Do NOT suggest scanning/iterating data structures. Instead, suggest which propagators watch which cells and fire
>   when information arrives.
> - Sequential ordering should EMERGE from dataflow dependencies, not be imposed by design.
> - Every component should be traceable as: cell creation → propagator installation → cell writes → cell reads =
>   result.
> - If a component can't be traced this way, it should be explicitly labeled as scaffolding with a retirement plan.
> - The ten design principles (especially Propagator-First, Data Orientation, and Correct-by-Construction) are the
>   evaluation criteria, not algorithmic efficiency or implementation convenience.

Your domain expertise is wanted. Where you see a real problem whose natural fix is an algorithm, state the problem
precisely, and phrase the direction as information flow.

## Rules

1. **Read-only on the repository.** Do not edit, create, delete, commit, stash, checkout or push anything in the
   worktree or in `/Users/avanti/dev/projects/logos/prologos`. Put every probe in **your own scratch directory**:
   `/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3/<your critic id>/`.
2. **Racket**: `"/Applications/Racket v9.3/bin/racket"` (the path has a space; quote it). Do not rebuild anything
   (`raco make` is forbidden; the worktree's `compiled/` is current). A probe requires modules by absolute path, e.g.
   `(require (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))`.
   - Wrap every run in `timeout -k 10 <seconds>`.
   - Process at most one `.prologos` file per Racket process.
   - **Never** run the full test suite.
   - **Never** `pkill` or `killall` by name.
   - Keep probes small: other sessions share this machine.
   - Wall-clock timing is meaningful only when it is not your main evidence; prefer counts and allocation.
3. **Evidence classes.** Label each claim THEOREM (state its hypotheses), MEASUREMENT (give the command and its output),
   PRECEDENT (cite it), CONJECTURE, or TASTE.
   - A count needs the command that produced it.
   - A "0" or "identical" needs a power check: show that your method finds a case that should be found.
   - Cite code as `path:line`, re-derived at HEAD.
4. **Challenge, don't catalogue.** "Uses cells ✓" is worthless. For each point, ask whether it could be more true to
   its principle and what that would cost. Do not pad: three grounded findings beat fifteen speculative ones.
5. **Fairness.** Name the strongest point *in favour* of the part of the design you attack hardest.
6. **Severity**:
   - *blocker*: the design is wrong or cannot work as written;
   - *major*: a significant gap, risk or overstatement that should change the design;
   - *minor*: a local correction.

## What to return

Your final answer must be one JSON object of this shape. Prose belongs inside the fields.

```json
{
  "critic": "C<n> <name>",
  "summary": "≤ 6 sentences: your overall verdict from your direction",
  "strongest_point_in_favour": "...",
  "findings": [
    {
      "id": "C<n>-<k>",
      "lens": "P | R | M | SRE | theory | runtime | evidence | cross-track | red-team | value",
      "section": "D.2 §…",
      "claim_attacked": "quoted from D.2, or 'missing: …'",
      "severity": "blocker | major | minor",
      "evidence": "file:line, command + output, theorem with hypotheses, or a counterexample",
      "evidence_class": "THEOREM | MEASUREMENT | PRECEDENT | CONJECTURE | TASTE",
      "direction": "what should change, phrased as information flow",
      "falsifier": "what observation would show this finding wrong",
      "confidence": "high | medium | low"
    }
  ],
  "sections_examined": ["§0", "§6.3", "..."],
  "probes": ["absolute path of each probe file you wrote, with its output file"]
}
```
