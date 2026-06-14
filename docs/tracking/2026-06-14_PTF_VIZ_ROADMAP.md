# PTF Viz Roadmap — from "recording the reduction" to "computation as propagation"

**Created**: 2026-06-14 (after the goal clarified through use)
**Branch**: `claude/charming-archimedes-98yb48` (prototype for a future
propagator-native Prologos, built on the PReduce on-network-reduction prototype)
**Companion**: `2026-06-12_PTF_TRACK2_BROWSER_VIZ_DESIGN.md` (§ BRANCH DIRECTIVE)

## The goal, sharpened

A browser visualization that shows Prologos program execution **as
propagator-native reduction — computation as propagation** — for arbitrary
programs. A working prototype of how this visualization serves a *future*
Prologos where reduction is fully on-network.

## Where we are (inventory)

**Capture** (`tools/viz-export.rkt`): runs a `.prologos` file with the BSP
observer + observatory + on-network reduction (now the default), emits a
`vizTrace 2` envelope — per-round network topology, timestamped rounds, cell
diffs, the containment DAG (reduction structure, captured at intern time),
identity (domains / well-known / source). Soundness invariant tested; golden
test green; full suite 8674 green.

**Viewer** (`tools/viz/index.html`): React + SVG, live `d3-force` (smooth
settling), timeline playback + speed control, **e-class collapse**, value
labels (e-class reduced values), **containment edges** (dashed violet),
`union ≡` operation labels, infrastructure toggle, source-construct labels,
pan/zoom/fit. `check.js` headless verify + `render-mp4.js` + examples.

**What the on-network reduction shows today**: each reduction STEP (a
redex ⇒ result rewrite) is a **union propagator** on the e-graph — DPO
rewriting on the propagator substrate (PRN §2, confirmed). The e-graph's
hashcons gives automatic memoization (fib(15): 1973 calls → ~18 e-classes).

## The gap (where we want to be vs. what we have) — three layers

The clarifying discovery (2026-06-14): with on-network reduction on, the viz
faithfully shows the e-graph being *built* by rewrite-unions — but the
*computing* itself isn't all propagation yet. Three layers:

1. **Legibility gap (viz-side, ours to close now).** The rewrites ARE on-network
   (unions), but they read as "`union ≡` between two identical cells," not as
   the reduction step "`int+(377,233) ⇒ 610`." The information to make them
   legible is capturable; we just don't surface it.
2. **Coverage gap (language-side, PReduce).** The reduction STEP (the rewrite)
   is a propagator, but two things are still functions: (a) the **RHS value
   compute** (`377+233=610` via `instantiate-template`, `rule-dispatch.rkt`) —
   not a compute-propagator reading operands; (b) the **recursion driver**
   (`fib`→`fib` via `reduction.rkt`'s recursive `whnf`/`nf`). So the *act of
   computing* isn't propagation yet — only the recording of each result is.
3. **Generality gap.** On-network ingestion covers arithmetic (int folds) + δ/β;
   broader reduction kinds becoming on-network widen what the viz can show.

## The plan

### Phase A — make the on-network reduction LEGIBLE (viz-side, tractable now)

Highest near-term value: turn "union between identical cells" into a readable
reduction step. Pure viz/exporter work; no language changes.

- **A.1 Capture the rewrite pairs.** At union time, record `(redex-term ⇒
  result-term, redex-cid, result-cid)` — same mechanism as the containment
  capture (`current-eclass-containment-box`), a new gated side-channel. The
  exporter emits per-round "rewrites applied."
- **A.2 Reduction-step readout.** Sidebar shows what fired this round as a
  rewrite: `int+(377, 233) ⇒ 610`, not "union ≡". The union node's label and
  tooltip show the rewrite it applies.
- **A.3 Directed containment.** Draw containment edges directed (operand →
  result) so the DAG reads as dataflow, not an ambiguous line.
- **A.4 Normal-form highlight.** Mark the e-class that is the extracted result
  (lowest-cost form) and the chain to it — "here is the answer, here is how it
  was reached."
- **A.5 (optional) Reduction-sequence view.** A layout mode that orders the
  rewrites left-to-right as a reduction sequence (redex → result → next),
  distinct from the raw force graph — reads like a reduction trace.

Outcome: the existing on-network reduction tells its story clearly — you watch
redexes rewrite to results and the e-graph build the answer.

### Phase B — a complementary "reduction trace" lens (moderate, tractable)

To show the ACTUAL computation **including the parts still off-network** (the
recursion, the arithmetic), instrument `reduction.rkt`'s `whnf`/`nf` to emit
each rewrite step as a trace. New trace type (`reduceTrace`), same viewer with
a reduction-lens mode: `fib(15) → fib(14)+fib(13) → … → 610` as it actually
evaluates. Honest bridge: shows the computation even where it isn't yet
propagator-native, until the language catches up. Complements the propagator
lens rather than replacing it.

### Phase C — close the language gap: propagator-native compute (PReduce endgame, big, owner-gated)

For FULL computation-as-propagation the language itself must move compute +
recursion on-network. This is the PReduce series' future, not viz work:

- **C.1 RHS compute as propagators** — an `int+` propagator reading operand
  e-classes and writing the sum (replacing `instantiate-template`). Then the
  arithmetic IS propagation and appears as `read-A,B → write-C` propagators in
  the trace.
- **C.2 Rule dispatch as propagation** — rules fire as propagators watching
  e-classes (replacing imperative `dispatch-rules`).
- **C.3 Recursion / β on-network** — the recursion/β driver as propagators.
- **C.4 Track 8** — the e-graph as the reduction ENGINE, retiring
  `reduction.rkt` (owner-gated in the autonomy charter).

**Key property**: the viewer renders whatever propagators a trace contains, so
**as C.1–C.4 land, the viz shows full computation-as-propagation with no viewer
changes.** The instrument is already built for the destination.

## Sequencing recommendation

| When | Phase | Owner of the work | Why |
|---|---|---|---|
| Now | **A** (viz legibility) | this branch | High value, tractable; makes today's on-network reduction readable as computation |
| Next | **B** (reduction lens) | this branch | See the actual computation before the language fully catches up; honest bridge |
| Future | **C** (propagator-native compute) | PReduce series (language) | The endgame that makes the prototype's promise real; viz is already ready |

**One-line framing**: *we've built the instrument; Phase A sharpens it for the
reduction that's on-network now, Phase B shows the computation that isn't yet,
and Phase C (the language) is where the computation fully becomes propagation —
at which point the instrument delivers its full promise unchanged.*

## Immediate next step (proposed)

Start **Phase A** — A.1 (capture rewrite pairs) + A.2 (reduction-step readout)
+ A.3 (directed containment). That converts the current "unions between
identical cells" into legible "redex ⇒ result" reduction steps, which is the
single change that makes the propagator-based reduction *read as reduction*.
