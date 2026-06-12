# PTF Track 2 — Standalone Browser Visualization + Arbitrary-Program Trace Export

**Created**: 2026-06-12 (PReduce-autonomy loop re-arm, iteration 44)
**Status**: OPENED — grounding complete; Stage 3 design decisions next
**Owner goal (verbatim direction, 2026-06-12)**: "generate a browser visualization
that can show the propagator network and play execution in order to show how the
system works for arbitrary prologos programs."
**Grounded at HEAD**: `ff739de7` (branch carries the full preduce-autonomy state)
**Prior art**: PTF Track 1 (observatory + VS Code panel) — this track extends it;
see `docs/tracking/2026-03-12_PROPAGATOR_VISUALIZATION_DESIGN.md` +
`2026-03-12_PROPAGATOR_OBSERVATORY.md`.

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| 0 | Grounding audit (5 facets + adversarial critic) | ✅ | this commit; synthesis below |
| 0.5 | Environment shakeout + empirical capture probe (install Racket in container; run a demo file with observer armed; verify non-empty rounds + real edges; measure counts) | ⬜ | next loop unit; de-risks all design decisions |
| 1 | Stage 3 design lock: exporter CLI shape + JSON schema posture + viewer stack | ⬜ | design rounds per charter §5 |
| 2 | `tools/viz-export.rkt` — headless CLI: `.prologos` in → self-contained trace JSON out | ⬜ | reuses trace-serialize + observatory-serialize |
| 3 | Standalone browser viewer (no build step) consuming the trace JSON; topology view + BSP-round playback | ⬜ | reuse rendering architecture + palette from propagatorView.ts |
| 4 | Fidelity riders: Tier-1 observer coverage, solver-network capture, compound-cell component diffs | ⬜ | scope per Phase 0.5 findings |
| T | Test phase: exporter golden test + schema regression | ⬜ | mandatory per workflow.md |

## 1. Grounding synthesis (what EXISTS at `ff739de7`)

All findings verified by HEAD-pinned read-only facet agents + an adversarial
completeness critic; citations are file:line at this HEAD.

**Capture layer — exists and is LSP-agnostic:**
- `current-bsp-observer` parameter + `make-trace-accumulator` (propagator.rkt
  ~576/594): when armed, the Tier-2 BSP loop calls the observer at every round end
  (propagator.rkt:3581–3598) with a `bsp-round` record.
- Trace structs: `bsp-round` (round-number, network-snapshot, cell-diffs,
  propagators-fired, contradiction, atms-events), `cell-diff` (cell-id, old, new,
  source-propagator), `prop-trace` (initial-network, rounds, final-network,
  metadata) — propagator.rkt:543–560.
- JSON serialization: `trace-serialize.rkt` (jsexpr; lattice values stringified).
  `serialize-network-topology` (trace-serialize.rkt:111–171) emits cells AND
  propagators **with `inputs`/`outputs` cell-id arrays** — real edges are in the
  schema (critic-verified, trace-serialize.rkt:155–162).
- Multi-network capture: `prop-observatory.rkt` (`capture-network`, cell-meta with
  subsystem/label/srcloc) + `observatory-serialize.rkt` → JSON. Headless-capable;
  nothing LSP-dependent in the capture path (critic verdict §3).
- Driver hooks: `process-string/return-net` (driver.rkt:1959–1964) returns the
  elab-network; `current-network-capture-box` + per-command observatory capture
  (driver.rkt:1036–1058). One elaboration network per `process-file`
  (driver.rkt:2234); ATMS solver network is a SEPARATE prop-network per command
  (driver.rkt:481–482); per-module networks during module load (driver.rkt:2589).

**Viewer prior art — exists, in the WRONG host for this goal:**
- `editors/vscode-prologos/src/propagatorView.ts` (1952 lines): Canvas + d3-dag
  Sugiyama layout for the bipartite DAG (cells=circles, propagators=diamonds),
  d3-zoom/quadtree/drag, BSP-round timeline scrubber with differential rendering,
  subsystem palette (type-inference #6a9955 / infrastructure #888 / multiplicity
  #b48ead), click-to-source. Phases 0–5 of the March design are COMPLETE.
- VS Code coupling is thin: one `acquireVsCodeApi()` site (propagatorView.ts:1878)
  + message passing for editor commands/state; the rendering core is host-agnostic
  (critic verdict §5: ~90% portable).
- Graphviz/Cytoscape were evaluated and REJECTED in the March design (§4.2) with
  recorded rationale — the browser viewer should not relitigate this.

**What .pnet/.pnetx can and cannot provide:**
- Both are VALUE/registry-oriented; `prop-network`/`elab-network` serialize as
  runtime sentinels (pnet-serialize.rkt:101–105). The Track 5 .pnetx sections are
  cell-state projections (eclasses + rewrites), NO topology. **Verdict: not a viz
  source; the trace/observatory path is the right substrate.**

## 2. Gap analysis (what the owner's goal needs that does NOT exist)

| # | Gap | Evidence |
|---|---|---|
| G1 | No headless CLI tool runs a `.prologos` file and writes trace/observatory JSON to disk (sweep of tools/ + racket/prologos/tools/: none) | critic §3 |
| G2 | No standalone browser viewer; the only viewer is the VS Code webview fed by LSP endpoints | facet 5 |
| G3 | Tier-1 fast-path BSP runs (zero-worldview, fire-once-only worklists — the COMMON case for simple elaborations) **skip the observer entirely** (propagator.rkt:3437–3471 flush has no observer call) — simple programs would record zero rounds | critic §1/§6 |
| G4 | Solver-network (relations/solve) and per-module networks are not linked into one capture story; observatory captures are per-command elab-network snapshots | critic §6 |
| G5 | Compound/universe cells (post-PPN 4C) hold many components per cell; `cell-diff` is whole-cell — playback granularity inside compound cells is an open question | critic §4 |
| G6 | March-era scale estimates (~40–500 nodes/command) predate universe-cell consolidation; no current empirical counts | critic §4 |

## 3. Design questions for Stage 3 (settle at Phase 1, after the Phase 0.5 probe)

1. **Exporter shape**: new `tools/viz-export.rkt` wrapping `process-file` with
   observer + observatory armed, emitting ONE self-contained JSON (topology +
   rounds + metadata) per run. Open: per-command sections vs whole-file merge;
   which networks (elab only day one vs elab+solver).
2. **Schema posture**: reuse the existing observatory/trace JSON schema verbatim
   (keeps VS Code panel compatibility) vs a viz-specific envelope around it.
   Default leaning: REUSE — the schema already carries edges, subsystems, srclocs.
3. **Viewer stack**: single-file static HTML+JS (no build step; vendored d3
   subpackages or dependency-free Canvas) vs porting propagatorView.ts behind a
   browser shim. Open until the rendering-core extraction cost is sized.
4. **G3 posture**: instrument Tier-1 with an observer call (small production touch
   in propagator.rkt — needs its own mini-audit + perf guard since Tier-1 IS the
   fast path) vs an exporter-mode flag forcing Tier-2. The flag is
   scheduler-coupling-suspect (cell/propagator/scheduler orthogonality); the
   observer call must be zero-cost when unarmed.
5. **Playback granularity**: rounds-only day one (matches captured data) with
   per-fire detail deferred; G5 component-level diffs deferred unless the probe
   shows compound cells dominate the interesting traffic.

## 4. Environment constraints (loop now runs in a remote container)

- Racket is NOT installed; apt offers 8.10 while the project pins 9.0 — version
  risk to verify at Phase 0.5 (worst case: build from upstream installer).
- Persistence = commit + push to the session branch (see ledger OWNER-PROVISIONAL
  entry); no main, no PRs, owner merges — charter §2 intent preserved.

## 5. R-lens targets carried to Phase 0.5 (verify surgically before design lock)

- propagator.rkt:3437–3471 — confirm Tier-1 observer dropout in code (critic-reported).
- propagator.rkt:3581–3598 — confirm Tier-2 observer call shape + what it receives.
- trace-serialize.rkt:155–171 — confirm emitted JSON keys against a REAL dump.
- driver.rkt:1036–1058 — confirm observatory capture fires per command by default
  when `current-observatory` is set (and what arms it outside LSP).
- Empirical: run `racket/prologos/lib/examples/prop-viz-demo.prologos` with
  observer armed; count cells/propagators/rounds/diff-volume; check non-empty
  propagator `inputs`/`outputs` at today's HEAD (the March "0 edges" note is
  probe-scoped, critic-adjudicated likely stale post-PPN-4C — verify with data).
