# PReduce Autonomy — Handoff

**Rewritten at the end of every iteration. Read this SECOND (after CHARTER.md) at
the start of every iteration.**

---

## Current state (as of 2026-06-12, iteration 44 — RE-ARMED on a new arc)

**History in one paragraph**: the original Phase B loop ran 43 iterations on
2026-06-10, closed Tracks 1/2/4/5/3 with PIRs, rendered the series verdict, and
HALTED per §8 (see `RETRO.md`). Post-halt, owner-interactive sessions fixed three
stacked defects and REWROTE the warm verdict for real corpora (ppn-track4c WARM
reduce 123ms vs 1172ms OFF — 9.5×; suite 8663 green at `ff739de7`). On
2026-06-12 the owner RE-ARMED the loop with a new final goal:

> a browser visualization that can show the propagator network and play
> execution, to show how the system works, for arbitrary prologos programs.

This opened **PTF Track 2** (design doc:
`docs/tracking/2026-06-12_PTF_TRACK2_BROWSER_VIZ_DESIGN.md`). The retro's owner
queue (a)-(e) stays queued behind it.

**Environment (changed — read this)**: the loop now runs in a REMOTE EPHEMERAL
container at `/home/user/prologos`, branch `claude/charming-archimedes-98yb48`
(verified: `preduce-autonomy` is an ancestor, zero divergence — this branch IS
the autonomy state). Persistence = commit + push to that branch (ledger
OWNER-PROVISIONAL, 2026-06-12): still no main, no PRs. Racket is NOT installed;
apt offers 8.10, project pins 9.0. The Workflow runtime is absent — grounding
audits run as parallel Explore agents with the same disciplines (HEAD-pin, cite
SHA, verified-vs-inferred, completeness critic).

## Exact next step (iteration 45)

**PTF Track 2 Phase 0.5 — environment shakeout + empirical capture probe** (one
scoped unit):

1. Install Racket (try apt 8.10 first; if the codebase won't compile, use the
   upstream 9.0 installer). Smoke: `raco make racket/prologos/driver.rkt`, then
   ONE targeted test via the runner.
2. Write a THROWAWAY probe script (not the production exporter): arm
   `current-bsp-observer` (make-trace-accumulator) + `current-observatory`,
   run `racket/prologos/lib/examples/prop-viz-demo.prologos` via process-file,
   dump topology + rounds JSON via trace-serialize/observatory-serialize.
3. Answer with DATA: (a) are propagator inputs/outputs non-empty at today's HEAD
   (the March "0 edges" staleness question)? (b) how many rounds does a typical
   file record — does the Tier-1 fast path (propagator.rkt:3437–3471, NO observer
   call) swallow the trace for simple programs (gap G3)? (c) cells/propagators/
   diff-volume magnitudes (gap G6). R-lens the design doc §5 targets while there.
4. Record findings in the design doc (Phase 0.5 row), ledger if decisions fall
   out, dailies, rewrite this handoff. The Stage-3 design lock (Phase 1) is the
   NEXT unit after that — do not start it in the same iteration.

## Implementation queue (after Phase 0.5)

1. Phase 1: Stage-3 design lock — exporter CLI shape, schema posture (default
   leaning: reuse the existing observatory/trace JSON schema verbatim), viewer
   stack (single-file static HTML+JS vs porting propagatorView.ts's core), G3
   posture (Tier-1 observer call vs exporter-mode flag — orthogonality-check the
   flag), playback granularity (rounds-only day one). Design rounds per charter
   §5; the critique can be in-context 3-column IF panel-skip reasons are recorded
   (retro precedent), but this arc touches surfaces the loop did NOT author —
   lean toward at least one independent critique agent.
2. Phase 2: `tools/viz-export.rkt` headless CLI exporter + golden test.
3. Phase 3: standalone browser viewer + playback (reuse palette + bipartite
   conventions from propagatorView.ts; Graphviz/Cytoscape REJECTED in the March
   design — don't relitigate).
4. Phase 4: fidelity riders (G3 production fix, solver-network capture, G5
   component diffs) — scope per probe data.

## Open threads

- Retro owner queue (a)-(e) — queued, not cancelled: SH/Zig lowering case;
  registries-as-cells (kills the 3-member flake family); D5 + observer hook;
  prn residue fix; Phase-2/boolrec riders.
- HANDOFF process note: late-loop iterations stopped rewriting this file (RETRO
  absorbed the role at halt). Resumed as of iteration 44 — keep the discipline.
- The registry-visibility flake family (3 members, DEFERRED.md) — non-blocking
  gate policy stands: batch-only failures pass if green individually.
- Charter §7 mentions PushNotification doorbells on halts/track closes — tool
  availability in this environment unverified; check at next halt/close event.

## Gate status

Iteration 44 was docs-only (design doc + ledger + dailies + this handoff) — no
code gates due. Suite state inherited: 8663 green at `ff739de7` (post-halt,
owner-verified). NO gates have been run in THIS container yet (no Racket) —
Phase 0.5 establishes local green before any production edit.
