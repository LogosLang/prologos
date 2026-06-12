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
| 0.5 | Environment shakeout + empirical capture probe (install Racket in container; run a demo file with observer armed; verify non-empty rounds + real edges; measure counts) | ✅ | iter 45; findings §6; probe = tools/viz-capture-probe.rkt |
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

## 6. Phase 0.5 findings (iteration 45, probe = `tools/viz-capture-probe.rkt`)

Probe run: `prop-viz-demo.prologos`, 4 commands, 0 errors, 4.9s wall (cold
caches), JSON artifact 31.5KB.

- **F1 — real edges EXIST at HEAD**: the last command's elab-network has 9
  propagators, ALL with non-empty `inputs` AND `outputs`. The March "0 edges"
  note is empirically stale; the bipartite graph has real structure to draw.
- **F2 — the capture pipeline works headless end-to-end**: observer +
  observatory + `current-network-capture-box` through `process-file` with no
  LSP: 17 rounds, 35 cell-diffs (with old/new values + source propagator),
  152 fires, 4 observatory captures (one per command). Playback material is
  real and well-formed JSON.
- **F3 — Tier-1 dropout (G3) did not blank this workload** (17 Tier-2 rounds
  recorded). The per-run dropout SHARE remains unquantified — Phase 1 design
  carries a cheap counter to size it before deciding the G3 posture.
- **F4 — subsystem categorization is DEGRADED at HEAD**: all 44 cells
  categorize as `infrastructure` — `elab-cell-info` lookups return `'none` for
  every cell. The March viewer's green/purple coloring assumed per-cell
  cell-info that the PPN 4C universe migration hollowed out. The natural
  replacement identity source is the Tier-3 `cell-domains` champ
  (`prop-network-cell-domains`, PPN 4C Phase 1c) — a Phase 1 design input.
- **F5 — magnitudes are small** for per-command topology (44 cells / 9 props);
  the LSP's 33MB-prelude-capture warning remains the scale ceiling — the
  exporter keeps per-command scoping + the probe's diff cap.
- **F6 — environment**: the Racket 9.0 pin is REAL — 8.10 rejects
  `thread #:pool 'own` (propagator.rkt:3748, parallel BSP). Racket 9.0
  installed in the container; raco make, targeted runner, and batch workers
  all green (test-trace-serialize 19/19 via the runner).
- **F7 — latent defect flagged (adjacent code, NOT fixed — out of scope)**:
  `lsp/server.rkt:553` reads `current-prop-net-box` AFTER `process-file`'s
  parameterize unwinds; the parameter defaults to `#f`
  (metavar-store.rkt:1401), so the LSP's `captured-prop-trace` path appears
  structurally dead. The probe avoids the trap via
  `current-network-capture-box`. Phase 2's exporter supersedes; flag for the
  owner / an LSP follow-up.

## 7. Stage-3 design decisions (Phase 1, iteration 46)

Status: **PROPOSED — under critique** (two independent adversarial critics
running; findings and resolutions land in §7.7; 2-column VAG in §7.8; the
status flips to LOCKED only after resolution).

### D1 — Exporter: `tools/viz-export.rkt`, one self-contained JSON per run

CLI: `racket tools/viz-export.rkt FILE.prologos -o out.json [--max-diffs N]`.
Capture recipe = the probe's validated trio (`current-bsp-observer` +
`current-observatory` + `current-network-capture-box`). Envelope:

```
{ "vizTrace": 1,
  "file": ..., "wallMs": ..., "commands": N, "errors": N,
  "captures": [ {label, subsystem, status, timestampMs, sequence, topology} ],
  "finalTopology": {cells, propagators, stats},          // last elab-network
  "rounds": [ {roundNumber, timestampMs, cellDiffs, propagatorsFired,
               contradiction, atmsEvents} ],
  "identity": { "cellDomains": {cid: domain},            // D4 identity stack
                "wellKnownCells": {cid: name},
                "propagatorSrclocs": {pid: srcloc-string} } }
```

**Round↔command correlation**: `bsp-round` carries no timestamp and the
accumulator re-stamps round numbers globally across ALL scheduler runs — a raw
round list would present module-loading rounds, per-command runs, and solver
runs as ONE misleading timeline. The exporter's observer wrapper records
`(current-inexact-milliseconds)` per round; observatory captures already carry
wall-clock + sequence (driver.rkt:1059-1060). The viewer groups rounds into
command epochs by timestamp interleaving. Cheap, exporter-side, no production
edits.

**Coverage day one**: the elab-network captures arrive per command via the
driver's observatory hook; session/capability/narrowing/user-reduction
subsystems register their own captures wherever those paths run (per the
PTF Track 1 observatory wiring) — the exporter exports ALL captures present.
Solver (relations/ATMS) networks have no observatory hook day one: NAMED gap,
Phase 4 rider (verify on a relations-using acceptance file in Phase 2).

### D2 — Schema: reuse the existing serializers verbatim; identity as an envelope supplement

`serialize-network-topology` + `serialize-bsp-round` are used UNCHANGED (the
probe verified completeness: edges, per-round diffs, values). The D4 identity
maps are computed BY THE EXPORTER into the envelope's `identity` section —
trace-serialize.rkt is NOT modified in Phase 2. This is named scaffolding:
keeping Phase 2 tools-only (no production edits before the in-container
full-suite baseline) at the cost of identity living outside the core schema.
**Fold-in decision point pre-registered**: at Phase 4, either the identity
section graduates into `serialize-network-topology` (if the viewer proves the
fields belong in every consumer, including the VS Code panel) or stays
exporter-local (if it's viz-specific). Not both indefinitely.

### D3 — Viewer: single-file static HTML+JS, dependency-free, in `tools/viz/`

`tools/viz/index.html` — hand-rolled Canvas rendering, no build step, no
vendored libraries. Loads trace JSON via file-input/drag-drop (file:// safe;
no server, no CORS exposure) with optional `fetch` for served contexts.
Bipartite conventions REUSED from propagatorView.ts (cells=circles,
propagators=diamonds; replay-with-scrubber semantics); CODE not reused — the
extension's rendering core is entangled with its bundler + d3 subpackages and
one `acquireVsCodeApi()` seam; porting costs more than rewriting at this
feature size and would couple the standalone viewer to extension internals.
Layout: simple BFS-layering from input-degree-0 cells (adequate at probe
magnitudes). **Pre-registered revisit condition**: if the acceptance corpus
produces >1k-node graphs or unreadable layouts, revisit layout (d3-dag port or
WebWorker Sugiyama) as its own decision — do not silently grow the hand-rolled
one.

### D4 — Cell/propagator identity: best-available-wins stack

(1) well-known cell-id table (cells 0–21, from propagator.rkt's named
constants); (2) `prop-network-cell-domains` champ → domain symbol (the
post-universe-migration replacement for hollow `elab-cell-info` — finding F4);
(3) `elab-cell-info` srcloc/type when present; (4) the existing value-shape
heuristic as floor. Viewer colors by DOMAIN primarily; subsystem retained as a
secondary facet. Propagators: srcloc from the propagator struct (PPN 4C
Phase 1.5 field) rendered as tooltip + (in served contexts) source link.

### D5 — G3 (Tier-1 observer dropout): defer the fix, surface the gap

Phase 2 ships tools-only — no scheduler edits. The dropout share CANNOT be
measured from outside (no hook in the Tier-1 branch), so quantification waits
for Phase 4's first sub-unit: a Tier-1 entry counter (production touch ⇒ its
own mini-audit + the full-suite baseline first). Mitigation NOW: the viewer
displays capture coverage prominently ("N rounds captured across M runs;
fast-path runs are not traced") so the gap is VISIBLE, never silent. Any
eventual fix must be scheduler-independent in semantics (orthogonality rule);
candidate = observer call in the Tier-1 branch (cell/propagator-layer concern,
zero-cost when unarmed), NOT an exporter-mode scheduler flag.

### D6 — NTT model: NOT APPLICABLE (named, with reasoning)

This track adds NO cells, propagators, lattices, bridges, or strata — it is a
read-side projection of existing network state through the established
zero-cost observer parameter. The NTT-model requirement binds tracks that BUILD
on the network; the only candidate production touch (D5's Tier-1 counter/
observer) is deferred to Phase 4 and gets its own mini-design there. Mantra
check: observation tooling's PURPOSE is information flow OUT of the network to
humans; the capture mechanism is the codified `current-bsp-observer` pattern
(zero overhead when `#f`).

### 7.7 Critique round findings + resolutions

(filled by the critique round below)

### 7.8 Vision Alignment Gate (2-column)

(filled at lock)
