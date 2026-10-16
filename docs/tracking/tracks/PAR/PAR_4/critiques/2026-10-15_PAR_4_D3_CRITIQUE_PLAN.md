# PAR 4 D.3 — the adversarial critique round: workflow (proposed)

**Of**: [`../2026-10-15_PAR_4_D2_DESIGN.md`](../2026-10-15_PAR_4_D2_DESIGN.md), after its self-critique
([`2026-10-15_PAR_4_D2_SELF_CRITIQUE.md`](2026-10-15_PAR_4_D2_SELF_CRITIQUE.md)).
**Asked for by** the owner (2026-10-15): "follow our Critique Methodology and create a dynamic workflow of agents to
adversarially critique all aspects of our design, to make it better."
**Governing text**: `CRITIQUE_METHODOLOGY.org`:
- the P/R/M lenses and the SRE lattice lens;
- the external briefing (§ Orientation for External Critics), given to every agent verbatim;
- grounded pushback and the four-way response format (§ Receiving External Critique).

**Status**: proposed; waiting for the owner's go-ahead to launch.

## Shape

The round has two waves and a hand-written synthesis. "Dynamic" means the second wave is chosen from what the first
finds rather than fixed in advance.

```
wave 1: ten critics in parallel, one per lens or concern, isolated from each other
        → structured findings (claim attacked · evidence · severity · falsifier)
triage (by hand): deduplicate; build a coverage map (D.2 section × critic); find disagreements and gaps
wave 2 (≤ 10 agents, chosen from the triage):
        settlers   — one per contested cluster; settle it by a probe or a code reading, with a power check
        defenders  — one per blocker/major finding; argue back from the codebase and the principles
        gap critics — one per D.2 section that no wave-1 critic covered adequately
synthesis (by hand): D3 critique file with a response to every finding → the D.3 revision → owner decisions
```

## Wave 1 — the critics

Each critic receives:
- D.2, the self-critique, and the inputs table's documents (paths);
- the external briefing;
- the principles doc;
- this file's rules.

Each attacks D.2 from one direction.

| id | critic | attacks | must ground in |
|---|---|---|---|
| C1 | **Principles** (P lens) | every design decision against the ten principles in `DESIGN_PRINCIPLES.org`; red-flag phrases (the fence is one) | quoted principle text and the design sentence it challenges |
| C2 | **Reality** (R lens) | every `file:line`, count and signature D.2 states, at HEAD; hidden consumers of what P0.5–P6 change; migration paths | `grep` output; files read |
| C3 | **Mindspace** (M lens) | step-think in each phase; the network reality check on every "on-network" claim (which `net-add-propagator`, which `net-cell-write`) | traced cell → propagator → write → read paths |
| C4 | **SRE lattice lens** | every lattice in D.2 (two-phase worldview, flat bands with ⊤, multiplicity chain, sets, epoch counters, assignment, residual type element): classification, algebraic properties, bridges, Hasse diagram and compute topology | lattice laws; a probe where a law is claimed |
| C5 | **Theory** | the theorems and their hypotheses: asynchronous iteration under the fence alternation; "BSP's rounds are the Kleene iterates"; the fuel bound; Mattern's double count with SPSC lanes; epoch-tagged late writes; termination levels | statements with assumptions; counterexamples as small networks |
| C6 | **Runtime and concurrency** | Racket CS 9.3 parallel threads; publication and memory ordering (risk R-2); continuation marks vs parameters across threads; allocation scaling at K > 1 (A-12); park/unpark | the Racket reference, Chez docs, and micro-probes in its scratch directory |
| C7 | **Evidence** (G-2) | each claim's evidence class (theorem / measurement / precedent / conjecture / taste); whether each phase gate *can fail*; power checks; baselines B1/B1′/B-P05; attribution | the P0 record's numbers; the gates' wording |
| C8 | **Cross-track** | the BSP-LE 3 contract (BC-1…BC-8) and the PPN 4C contract (PC-1…PC-4): does PAR 4 foreclose either track's design? does either track's live branch already contradict a contract item? | the BSP-LE 3 seed; PPN 4C's branch and log (read-only) |
| C9 | **Red team** | build concrete networks and programs that make D.2 give a wrong answer, hang, or lose a contradiction: stale reads, the fence boundary (S-9), labelled worldview reads (D2L-1), late writes, contradiction with lanes in flight, forks, fuel | runnable Racket-level probes and their output |
| C10 | **Value and scope** | whether the phase order buys the most value soonest; the realizable K > 1 value before PPN 4C (§2 item 3); the simplest design that delivers most of the value; what to cut | the P0 record's models and measurements |

Every critic must also name the strongest point **in favour** of the part it attacks (fairness, as the standing
critique process asks).

**Finding format** (structured, so the triage can be done by hand without re-reading prose). Each finding gives:
- `id`, e.g. `C5-3`;
- `lens`;
- `section` of D.2;
- `claim_attacked` (quoted);
- `severity`: blocker · major · minor;
- `evidence` (file:line, command and output, theorem, or counterexample);
- `direction`, phrased as information flow, never as "first do X, then Y";
- `falsifier`: what would show the finding wrong;
- `confidence`.

## Rules for every agent

- **Read-only on the repository.** Probes go in the agent's own scratch directory, never in the worktree. No commits,
  pushes, stashes or branch changes.
- **Racket**: `"/Applications/Racket v9.3/bin/racket"`; do not rebuild; one `.prologos` file per process; wrap runs in
  `timeout -k`; never `pkill` machine-wide (DEFERRED 163); timing only under the suite lock.
- **Measurement discipline**: every "0" or "identical" needs a power check, and every count says how it was obtained;
  conjecture is labelled.
- **Propagator mindspace**: the external briefing applies to the critics' own proposals.
- **No consensus-seeking**: critics do not see each other's output in wave 1.

## Triage, wave 2, synthesis

1. **Triage** (by hand):
   - merge duplicates, keeping each critic's evidence;
   - build the coverage map: D.2 sections × critics, flagging any section with fewer than two critics;
   - list contested clusters: findings that contradict each other or a measurement;
   - rank the rest by severity.
2. **Wave 2** (≤ 10 agents; the composition is decided by the triage and reported to the owner before launch if it
   differs from this plan by more than the counts):
   - **settlers**: given the contested cluster and both sides' evidence, they produce a probe with a power check, or a
     code reading, and a verdict;
   - **defenders**: given one blocker or major finding, they argue back from the codebase and the principles, as the
     methodology's grounded pushback asks. A finding that survives its defender is stronger for it.
   - **gap critics**: given an under-covered section, they critique it as wave 1 did.
3. **Synthesis** (by hand, the document of record): `critiques/2026-10-1x_PAR_4_D3_EXTERNAL_CRITIQUE.md`.
   - Every finding gets one of the methodology's four responses: accept · accept the problem, reject the solution ·
     reject with justification (the principle or code that refutes it) · defer with tracking (a DEFERRED entry).
   - Delegated output is input: read in full, spot-checked, and never pasted as record.
4. **D.3**: the design revised by the accepted findings. New owner decisions are ledgered as O-14 onwards. The LOG,
   dailies and DEFERRED are updated as usual.

## Cost and bounds

- Two waves of at most ten agents each.
- No agent runs the full suite. Timing probes take the suite lock.
- A third wave only on the owner's word.
