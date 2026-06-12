# PReduce Autonomy — Handoff

**Rewritten at the end of every iteration. Read this SECOND (after CHARTER.md) at
the start of every iteration.**

---

## Current state (as of 2026-06-12, iteration 45 closed — PTF Track 2 Phase 0.5 ✅)

**History in one paragraph**: the original Phase B loop ran 43 iterations on
2026-06-10, closed Tracks 1/2/4/5/3 with PIRs, rendered the series verdict, and
HALTED per §8 (see `RETRO.md`). Post-halt owner sessions fixed three stacked
defects and rewrote the warm verdict (9.5× warm reduce cut; suite 8663 green at
`ff739de7`). On 2026-06-12 the owner RE-ARMED the loop with a new final goal —
**a browser visualization of the propagator network with execution playback for
arbitrary prologos programs** — opened as **PTF Track 2** (design doc:
`docs/tracking/2026-06-12_PTF_TRACK2_BROWSER_VIZ_DESIGN.md`; grounding §1-§5,
empirical findings §6).

**Iteration ledger this arc**: 44 = arc open + grounding audit (commit
`5ef450a`). 45 = Phase 0.5 shakeout + probe (commits `914abbb` + this one):
Racket 9.0 installed in-container (8.10 REJECTED: `thread #:pool 'own`,
propagator.rkt:3748), toolchain green, probe `tools/viz-capture-probe.rkt` ran
clean — **real edges exist at HEAD, headless capture works end-to-end, 31.5KB
JSON for the demo**. Findings F1–F7 in the design doc §6.

**Environment**: remote ephemeral container `/home/user/prologos`, branch
`claude/charming-archimedes-98yb48` (== preduce-autonomy state; push = the
persistence mechanism, ledgered OWNER-PROVISIONAL). Racket 9.0 at
`/usr/local/bin/racket` (PATH-first). If the container was RECREATED since
iteration 45: re-install 9.0 (`curl -sL -o /tmp/r.sh
https://download.racket-lang.org/installers/9.0/racket-9.0-x86_64-linux-cs.sh
&& sudo sh /tmp/r.sh --unix-style --dest /usr/local --create-dir`), then
`raco make -j 4 driver.rkt` in racket/prologos. The Workflow runtime is absent
— grounding/critique run as parallel Explore agents with the same disciplines.

## Exact next step (iteration 46)

**PTF Track 2 Phase 1 — Stage-3 design lock** (one scoped unit: the design
round + lock; NO implementation in the same iteration). Settle the §3 design
questions, informed by §6 findings:

1. **Exporter CLI shape** (`tools/viz-export.rkt`): per-command sections vs
   whole-file merge; elab-network only day one vs +solver/ATMS; the probe's
   capture recipe (observer + observatory + capture-box) is the validated base.
2. **Schema posture**: default = REUSE the existing trace/observatory JSON
   schema (F2 shows it's complete: topology + edges + per-round diffs); decide
   the self-contained-file envelope (one JSON: topology + rounds + metadata,
   as the probe already emits).
3. **Viewer stack**: single-file static HTML+JS (no build step) vs porting
   propagatorView.ts behind a browser shim. Input: coupling is one
   `acquireVsCodeApi()` site + message passing (critic §5, ~90% portable);
   but a dependency-free single-file viewer avoids the extension's build
   pipeline entirely. Decide with a 3-column rationale (or an independent
   critique agent — this arc touches surfaces the loop did not author).
4. **Cell identity/coloring (F4)**: subsystem categorization via
   elab-cell-info is HOLLOW at HEAD — design the replacement identity source
   (candidate: `prop-network-cell-domains` champ, PPN 4C Phase 1c; plus
   well-known cell-id constants 0–21 for infra labeling; propagator srcloc
   for click-to-source).
5. **G3 posture (Tier-1 dropout)**: add the cheap counter to size the dropout
   share BEFORE choosing instrument-Tier-1 vs force-Tier-2-in-export-mode.
   Orthogonality rule: any fix must be scheduler-independent in semantics.
Write decisions into the design doc (2-column catalogue/challenge for the VAG),
ledger the lock, THEN stop — Phase 2 (exporter implementation) is iteration 47.

## Implementation queue (after Phase 1)

- Phase 2: `tools/viz-export.rkt` + golden test (+ the F3 counter; first
  in-container FULL-SUITE BASELINE before any production .rkt edit).
- Phase 3: standalone browser viewer + playback (palette + bipartite
  conventions from propagatorView.ts; Graphviz/Cytoscape rejection stands).
- Phase 4: fidelity riders per probe data (G3 fix if warranted, solver
  capture, F4 production identity improvements, F7 LSP defect hand-off).
- Phase T: test phase (mandatory).

## Open threads

- F7: LSP prop-trace capture path structurally dead (server.rkt:553 reads
  net-box post-unwind; default #f) — flagged for owner/LSP follow-up, NOT
  this track's scope.
- Retro owner queue (a)-(e) — queued, not cancelled.
- Registry-visibility flake family (3 members) — non-blocking gate policy
  stands.
- PushNotification doorbell tool: NOT available in this environment (checked
  iteration 45) — halts/track-closes are signaled via ledger + final summary
  text instead.
- In-container full-suite baseline owed before first production edit
  (Phase 2 opener).

## Gate status

Iteration 45: parens ✅ (script now PATH-portable), targeted smoke ✅
(test-trace-serialize 19/19 via the runner — batch workers verified live under
9.0), probe ✅ (0 errors, JSON artifact verified well-formed). Full suite not
yet run in this container (docs+tools-only so far); suite state inherited:
8663 green at `ff739de7`.
