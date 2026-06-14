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

## The gap (where we want to be vs. what we have) — refined 2026-06-14

The clarifying discovery: with on-network reduction on, the e-graph records the
**arithmetic** reduction steps (int folds) as union rewrites — but for a program
whose essence is RECURSION (fib), the recursion itself is NOT on-network. Empirics
(fib trace): the e-classes are literal values + the fibonacci results
(`2,3,5,8,…,233,377`); there are essentially **no `(int+ …)` redex terms and no
fib-application/recursion terms on the network**. So:

- **What IS on-network and showable today**: ARITHMETIC reduction. A program whose
  computation is arithmetic — the balanced tree in `parallel-reduction` — reduces
  ENTIRELY on the network (the 256-wide round IS the computation as propagation).
  That workload already demonstrates the goal.
- **What is NOT on-network**: (a) the **recursion / control flow** — `fib` calling
  `fib` is the off-network recursive `whnf` driver (`reduction.rkt`); (b) the **RHS
  value compute** — `377+233=610` is `instantiate-template` (a function), not a
  compute-propagator; (c) the **redex structure** is consumed (we recover it via
  the containment side-channel for the viz).

So the honest gap, by program shape: **arithmetic-shaped computation is already
computation-as-propagation on the network; recursion/control-shaped computation
(fib) has its essence off-network until the language moves it on-network.**

## The plan

### Phase A — make the on-network reduction LEGIBLE (viz-side, tractable now)

Highest near-term value: turn "`union ≡` between two identical cells" into a
readable reduction step. Pure viz/exporter work; no language changes. Best shown
on `parallel-reduction` (fully on-network arithmetic).

- **A.1 Capture the rewrite pairs.** At union time, record `(redex-term ⇒
  result-term)` — a new gated side-channel like the containment capture. The
  exporter emits per-round "rewrites applied."
- **A.2 Reduction-step readout.** Sidebar + node label/tooltip show what fired
  this round as a rewrite (`int+(377, 233) ⇒ 610`), not "union ≡".
- **A.3 Directed containment.** Containment edges directed (operand → result) so
  the DAG reads as dataflow.
- **A.4 Normal-form highlight.** Mark the extracted result e-class and the chain
  to it — "here is the answer, here is how it was reached."

Outcome: the arithmetic reduction reads as computation — you watch redexes
rewrite to results and the answer build, on the network.

### ~~Phase B — instrument reduction.rkt~~ — DROPPED (contradicts the directive)

Originally proposed: instrument `reduction.rkt`'s `whnf`/`nf` to show the
recursion. **Removed 2026-06-14 (owner caught it):** `reduction.rkt` is the
OFF-network recursive reducer. Instrumenting it would visualize the off-network
reduction — directly against the branch directive ("always use / show the
on-network, propagator-native reduction"). The correct way to show the recursion
is to make it on-network (Phase C), not to instrument the off-network driver.
There is no "off-network bridge" lens on this branch.

### Phase C — close the language gap: recursion + compute as propagators (PReduce endgame, owner-gated)

For recursion/control-shaped programs (fib) to show as propagation, the language
must move recursion + compute on-network. This is the PReduce series' future,
not viz work:

- **C.1 Recursion / β-δ on-network** — the recursion driver (`fib`→`fib`
  unfolding) becomes propagator-driven rewriting on the e-graph, so the recursion
  STRUCTURE is on the network (not just the arithmetic leaves).
- **C.2 RHS compute as propagators** — an `int+` propagator reading operand
  e-classes and writing the sum (replacing `instantiate-template`); the
  arithmetic appears as `read-A,B → write-C` propagators.
- **C.3 Rule dispatch as propagation** — rules fire as propagators on e-classes
  (replacing imperative `dispatch-rules`).
- **C.4 Track 8** — the e-graph as the reduction ENGINE, retiring
  `reduction.rkt` (owner-gated).

**Key property**: the viewer renders whatever propagators a trace contains, so as
C.1–C.4 land, the viz shows full computation-as-propagation **with no viewer
changes** — fib's recursion would simply appear as propagators the way the
arithmetic tree does now.

## Sequencing recommendation (revised 2026-06-14)

| When | Phase | Owner of the work | Why |
|---|---|---|---|
| Now | **A** (viz legibility) | this branch | Makes the on-network ARITHMETIC reduction read as computation (best on `parallel-reduction`) |
| Future | **C** (recursion + compute on-network) | PReduce series (language) | The only honest way to show recursion-shaped computation (fib) as propagation; viz already ready |

Phase B is gone — there is no off-network bridge; we either show what's
on-network (A) or move more on-network (C).

**One-line framing**: *we've built the instrument; Phase A sharpens it for the
reduction that's on-network now (arithmetic), and Phase C (the language) is where
recursion/control also become propagation — at which point the instrument
delivers its full promise unchanged.*

## Immediate next step (proposed)

Start **Phase A** — capture rewrite pairs + reduction-step readout + directed
containment. Validate on `parallel-reduction` (whose computation is fully
on-network arithmetic), where it most directly delivers "watch the computation
happen as propagation." fib stays the honest illustration of the recursion gap
that Phase C closes.
