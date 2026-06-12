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

**Iteration ledger this arc**: 44 = arc open + grounding audit (`5ef450a`).
45 = Phase 0.5 (`914abbb`, `c1b96bf`): Racket 9.0 installed
(8.10 REJECTED: `thread #:pool 'own`, propagator.rkt:3748), toolchain green,
probe ran clean — real edges at HEAD, headless capture end-to-end, findings
F1–F7 (§6). 46 = **Stage-3 design LOCKED (amended)** (`6dd6245` + this
commit): two independent adversarial critics → 2 BLOCKERs + 8 MAJORs
adjudicated (§7.7); "tools-only Phase 2" OVERTURNED (Tier-1 observer fix
promoted to 2b); PATH B decided for identity; D4 downgraded per in-round
measurement (55% domain coverage); D7 added; Phase 0A (acceptance file)
added per critique B1. VAG §7.8.

**Environment**: remote ephemeral container `/home/user/prologos`, branch
`claude/charming-archimedes-98yb48` (== preduce-autonomy state; push = the
persistence mechanism, ledgered OWNER-PROVISIONAL). Racket 9.0 at
`/usr/local/bin/racket` (PATH-first). If the container was RECREATED since
iteration 45: re-install 9.0 (`curl -sL -o /tmp/r.sh
https://download.racket-lang.org/installers/9.0/racket-9.0-x86_64-linux-cs.sh
&& sudo sh /tmp/r.sh --unix-style --dest /usr/local --create-dir`), then
`raco make -j 4 driver.rkt` in racket/prologos. The Workflow runtime is absent
— grounding/critique run as parallel Explore agents with the same disciplines.

## Exact next step (iteration 51)

**PTF Track 2 Phase 3 — the standalone browser viewer** (THE user-facing
deliverable; one scoped unit, but the largest one — if it needs splitting,
3a = static topology view, 3b = playback, each its own iteration):

`tools/viz/index.html` — single file, dependency-free, no build step (locked
D3). Loads a vizTrace/1 JSON via file-input/drag-drop (file:// safe; no
server). MUST-HAVES per the locked design + critique:
1. **Topology view**: bipartite Canvas graph — cells=circles,
   propagators=diamonds (conventions from propagatorView.ts; code NOT
   ported); edges propagator.inputs/outputs; COMPONENT-AWARE layout
   (disconnected components laid out independently, grid-arranged; BFS
   layering within components; SELF-LOOP arcs — they're real, e.g.
   propagator 8 inputs=[34] outputs=[34]); zoom/pan (Canvas transform);
   hover tooltips (cell value, valueDetail keys, domain, well-known name,
   propagator srcloc).
2. **Identity coloring (D4 as locked)**: color by best-available (domain →
   well-known → subsystem → heuristic); display the coverage stats — never
   pretend full coverage.
3. **Playback**: epoch selector (per-command; labels from captures) +
   round scrubber within epoch; on each round: flash the diffed cells
   (cellDiffs old→new on hover) + highlight fired propagators; coverage
   line ("N rounds across M epochs"). Per-epoch topology switch (the
   solver epochs LOOK different — that's the point: 67-81c/172-179p).
4. Validate against all 3 corpus envelopes (regenerate via the exporter;
   /tmp copies may be gone). Check in a small golden envelope? NO — large;
   regenerate on demand. Document usage at the top of index.html + in the
   design doc.
5. Browser-verification limitation: this container has no GUI browser —
   verify with node-less static checks (JSON loads, JS syntax via `node
   --check` if node exists, else careful review) + ship; the OWNER's
   browser is the real acceptance. Record the limitation honestly.

**Container noise floor (calibrate perf claims)**: A/A same-code bench
registers up to 15.3% "significant" — see ledger iter 49.

## Container re-setup recipe (if the container was recreated)

Racket 9.0 install (see Environment above) + `raco pkg install --auto
--skip-installed rackcheck` + `raco pkg install --link --auto
racket/prologos` + `raco make -j 4 driver.rkt` in racket/prologos.

## Implementation queue (after 0A) — per the LOCKED design (§7, amended)

- **2a**: in-container FULL-SUITE BASELINE (gate for any production edit).
- **2b**: production hooks — Tier-1 observer call (promoted at lock; D5
  revised); pre-registered fallbacks live here too (observer-site timestamps
  if 2c validation fails; solve-boundary observatory hook if the free path
  leaves solver epochs empty). Full suite + bench A/B at close (Tier-1 = hot
  path).
- **2c**: `tools/viz-export.rkt` + golden tests; epoch-bucketing validation
  criteria (strict monotonicity; epoch count == command count; load-epoch
  labeling); D7 semantic value detail; identity coverage stats (D4 amended:
  55% measured — "best-available with measured coverage").
- **T**: `tests/test-viz-export.rkt` schema regression (before the viewer).
- **3**: standalone single-file viewer (component-aware layout day one;
  self-loop arcs; coverage display; corpus scale audit gates entry).
- **4**: riders per data (compound-cell diffs; D7 depth; per-rider NTT
  models if any rider adds cells/propagators).

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
