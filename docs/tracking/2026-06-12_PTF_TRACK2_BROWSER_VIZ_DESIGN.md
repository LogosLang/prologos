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
| 1 | Stage 3 design lock: D1–D7 + critique round + VAG | ✅ | iter 46; §7; LOCKED (amended) |
| 0A | Acceptance file `examples/2026-06-12-ptf-track2-viz.prologos` + corpus definition (ordering debt from critique B1 — acceptance precedes ALL implementation) | ✅ | iter 47; Level-3 clean (17 commands, 0 errors); corpus audit §8 |
| 2a | In-container full-suite baseline (gate for any production edit) | ✅ | iter 48: **8658/439 ALL PASS, 401.5s** (after env fixes: rackcheck + `raco pkg install --link` + one stale 8.10 .zo; 9 env-failures → 0; zero flakes) |
| 2b | Production hooks: Tier-1 observer call (A1); pre-registered fallbacks: observer-site timestamps (A2), solve-boundary observatory hook (A4) — full suite + bench A/B at close | ✅ | iter 49 (`6d25e58`): armed path = per-fire champ-diff + one bsp-round; unarmed byte-identical; 3 unit tests; suite 8666/439 GREEN (400.6s ≈ baseline); fallbacks NOT yet needed (2c validates); corpus never takes Tier-1 (falsified-workload note in ledger) |
| 2c | `tools/viz-export.rkt` + golden tests (tests land WITH the exporter) | ✅ | iter 50 (`b0bbb88`): ALL criteria PASS on the corpus — monotone ✓, captures==commands ✓, **solver free path ✓** (relation epochs 67-81c/172-179p); fallbacks NOT needed; envelope ≤880KB |
| T | Dedicated test file `tests/test-viz-export.rkt` (schema regression) | ✅ | landed with 2c; 7/7 (envelope keys, parity, monotone, identity coverage, D7 bounds, solver-epoch assert, jsexpr round-trip) |
| 3 | Standalone browser viewer: topology + playback; component-aware layout; coverage display | ✅ | iter 51 (`10b0f4a`): tools/viz/index.html + check.js; headless core verification ALL PASS on the corpus; **browser acceptance = owner's machine** (no GUI in the container — honest limitation); artifacts delivered to owner |
| 4 | Riders per data: compound-cell component diffs; D7 depth; solver hook if 2c validation demands; any rider adding cells/propagators carries its own NTT model | ⬜ | |

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

Status: **LOCKED (amended)** — two independent adversarial critics returned
1 BLOCKER + 4 MAJOR (Critic A, refutation mandate) and 1 BLOCKER + 4 MAJOR
(Critic B, P/R/M/S + red-flags). All adjudicated in §7.7 (including push-backs);
amendments applied in-place below; 2-column VAG in §7.8. The single largest
amendment: **"tools-only Phase 2" was overturned** — the owner's goal requires
two minimal production hooks (Tier-1 observer call; pre-registered fallbacks),
so Phase 2 splits into 2a (baseline) / 2b (hooks, gated) / 2c (exporter).

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
trace-serialize.rkt is FROZEN this track. **AMENDED AT LOCK (critique B5 —
the "fold-in decision point" was a validated≠deployed dangle): PATH B is
DECIDED.** Identity is exporter-local as the END-STATE of this track, not a
waystation: the fields are unproven until the viewer exists, and core-schema
churn must not precede validation. The VS Code panel's identity-hollowness
(F4) is explicitly OUT-OF-SCOPE — owner-queue material. Fold-in re-opens only
via a new owner-decided track.

### D3 — Viewer: single-file static HTML+JS, dependency-free, in `tools/viz/`

`tools/viz/index.html` — hand-rolled Canvas rendering, no build step, no
vendored libraries. Loads trace JSON via file-input/drag-drop (file:// safe;
no server, no CORS exposure) with optional `fetch` for served contexts.
Bipartite conventions REUSED from propagatorView.ts (cells=circles,
propagators=diamonds; replay-with-scrubber semantics); CODE not reused — the
extension's rendering core is entangled with its bundler + d3 subpackages and
one `acquireVsCodeApi()` seam; porting costs more than rewriting at this
feature size and would couple the standalone viewer to extension internals.
**AMENDED AT LOCK (critique B4): this is INCOMPLETE DECOMPLECTION, named** —
the more-aligned end-state is a shared rendering core with thin VS Code +
browser adapters; deferred because the standalone viewer must not depend on
the extension's build pipeline. Revisit triggers: >1k-node corpus graphs OR
the panel adopting the identity fields.
Layout **(amended per critique A5)**: component-aware from day one —
disconnected components laid out independently and arranged in a grid;
self-loops rendered as arcs on the node (the probe showed self-loops are
REAL: propagator 8 has inputs=[34], outputs=[34]); BFS-layering within
components. Legibility acceptance on the relations corpus file gates Phase 3
close. **Pre-registered revisit condition** (unchanged): >1k-node graphs or
unreadable layouts → revisit layout (d3-dag port or WebWorker Sugiyama) as
its own decision — do not silently grow the hand-rolled one.

### D4 — Cell/propagator identity: best-available-wins stack

(1) well-known cell-id table (cells 0–21, from propagator.rkt's named
constants); (2) `prop-network-cell-domains` champ → domain symbol (the
post-universe-migration replacement for hollow `elab-cell-info` — finding F4);
(3) `elab-cell-info` srcloc/type when present; (4) the existing value-shape
heuristic as floor. **AMENDED AT LOCK (critique B2, resolved WITH DATA —
probe rerun, iteration 46)**: cell-domains coverage on the demo is **24/44
(55%), 7 distinct domains** (hasheq-replace ×9, monotone-set ×7,
hash-of-lists-accumulator ×3, tropical-fuel ×2, constraint-status-map,
error-descriptor-map, hasse-registry) — NOT hollow, but below the 70% bar, so
the pre-registered rename fires: the claim is **"best-available identity with
MEASURED coverage"**, not "colors by domain primarily". The exporter emits
per-level coverage stats in the envelope; the viewer displays them. Note:
domain names are merge-strategy-flavored — the palette maps them to
lattice-meaningful colors, which honestly serves "how the system works" (the
merge structure IS the system). Propagators: srcloc from the propagator
struct (PPN 4C Phase 1.5 field) rendered as tooltip + (in served contexts)
source link.

### D5 — G3 (Tier-1 observer dropout): **REVISED AT LOCK — the fix is PROMOTED to Phase 2b**

Original posture (defer to Phase 4, mitigate with a viewer message) was
REFUTED by both critics: Critic A showed simple fire-once programs (the
canonical relational demos) produce ZERO rounds — "arbitrary programs" is
false without the fix; Critic B showed the "visibility" mitigation had no
data source — a hardcoded string, not surfacing. **Resolution: the observer
call lands in the Tier-1 branch (propagator.rkt:3437–3471) in Phase 2b** —
zero-cost when unarmed (one parameter read, the price Tier-2 already pays),
semantics scheduler-independent (it REPORTS fires; it alters nothing — the
orthogonality rule is satisfied at the propagator/observation layer, not via
an exporter-mode scheduler flag). The Phase-4 counter is DROPPED — dissolved
by the fix (observed fast-path runs leave no dropout to count). Gates: 2a
full-suite baseline precedes; bench A/B at 2b close (Tier-1 is the hot path;
the testing.md regression rules apply).

### D6 — NTT model: NOT APPLICABLE (named, with reasoning)

This track adds NO cells, propagators, lattices, bridges, or strata — it is a
read-side projection of existing network state through the established
zero-cost observer parameter. The NTT-model requirement binds tracks that BUILD
on the network; the only candidate production touch (D5's Tier-1 counter/
observer) is deferred to Phase 4 and gets its own mini-design there. Mantra
check: observation tooling's PURPOSE is information flow OUT of the network to
humans; the capture mechanism is the codified `current-bsp-observer` pattern
(zero overhead when `#f`).

### 7.7 Critique round findings + adjudications (two independent critics, iteration 46)

**Critic A (mandate: refute the central claim)** — verdict was "substantially
refuted; recoverable with corrections"; all corrections adjudicated:

| # | Finding | Adjudication |
|---|---|---|
| A1 | BLOCKER: Tier-1 fast path skips the observer → simple fire-once programs (canonical relational demos) trace EMPTY | ACCEPTED — fix promoted to Phase 2b (see D5 revision) |
| A2 | MAJOR: timestamp epoch-correlation fragile (sub-ms rounds, coarse clocks, wrapper-outside-loop) | PARTIAL, with push-back: the wrapper records AT observer invocation (inside the loop), and Linux/macOS clocks give sub-ms float precision — the named failure modes don't apply as stated. ACCEPTED core: bucketing is UNVALIDATED → Phase 2c acceptance criteria (strict per-run monotonicity; epoch count == command count on the corpus; pre-first-capture rounds labeled as load-epoch). Pre-registered fallback: 1-line observer-site timestamps in 2b if validation fails |
| A3 | MAJOR: value rendering opaque ("hash(N entries)") — playback uninformative | ACCEPTED as **D7 (new)**: exporter-side bounded semantic detail — one-level hash unpacking (keys + per-key summary), decision/worldview cells rendered as bitmask + labels, sizes capped; lands in the envelope (PATH B consistent); trace-serialize untouched. Viewer shows detail on hover/click |
| A4 | MAJOR: solver/relations networks invisible day one — the pedagogically central propagation missing | ACCEPTED, two-part: (i) FREE PATH first — rounds carry full network snapshots and the ambient observer fires in solver BSP runs too; the exporter derives per-epoch topology from each epoch's last snapshot (A1's fix also un-hides solver fast-paths); validated on the relations corpus file in 2c; (ii) pre-registered 2b fallback: solve-boundary observatory registration if solver epochs come back empty |
| A5 | MAJOR: BFS layering fails on solver graphs (disconnected components, self-loops, wide layers) | ACCEPTED into D3: component-aware layout day one + self-loop arcs + relations-file legibility gate |
| A6 | MINOR: monochrome coloring | Merged into D4 (resolved with data — see D4 amendment) |
| A7 | MINOR: cold-cache prelude can explode the trace | ACCEPTED: `--max-rounds` + truncation flag join `--max-diffs` |

**Critic B (mandate: P/R/M/S + red-flag scan)** — verdict "cannot lock as-is";
all blockers resolved at lock:

| # | Finding | Adjudication |
|---|---|---|
| B1 | BLOCKER: no Phase-0 acceptance file (workflow.md mandate) | ACCEPTED — Phase 0A added; `examples/2026-06-12-ptf-track2-viz.prologos` is iteration 47's unit, BEFORE any implementation; corpus defined there |
| B2 | MAJOR: D4's cell-domains may be F4-hollow one level down | RESOLVED WITH DATA at lock (probe rerun): 24/44 = 55% coverage, 7 domains — not hollow, below the 70% bar → pre-registered rename FIRED (see D4 amendment) |
| B3 | MAJOR: D5's "visibility" had no data source | DISSOLVED by A1/D5 revision — observed fast-paths leave no dropout; counter dropped |
| B4 | MAJOR: D3 framed pragmatism as principle | ACCEPTED — reframed as incomplete decomplection with named deferral reason + two revisit triggers |
| B5 | MAJOR: D2's "fold-in decision point" = validated≠deployed dangle | ACCEPTED — **PATH B decided at lock**: exporter-local identity is the track's end-state; panel out-of-scope; fold-in reopens only via a new owner-decided track |
| B6 | MINOR: D6 NTT claim incomplete re Phase 4 | ACCEPTED — any Phase 4 rider adding cells/propagators carries its own NTT model; 2b's observer call adds neither |
| B7 | MINOR: envelope fields viewer-specific | ACCEPTED — D1-note: epoch-correlation fields are exporter/viewer-specific, not schema-canonical |
| B8 | MINOR: Phase T after Phase 4 | ACCEPTED — tracker reordered (2c carries its golden tests; T precedes the viewer) |
| B9 | MINOR: corpus undefined/unaudited | ACCEPTED — corpus at 0A; probe-based scale audit gates Phase 3 entry |

### 7.8 Vision Alignment Gate (2-column: catalogue / challenge)

| Decision | Column 1 — catalogue (passes?) | Column 2 — could it be MORE aligned? |
|---|---|---|
| D1 envelope | Reuses production serializers; one self-contained artifact | YES, marginally: epoch fields are viewer-coupled — named non-canonical (B7) rather than pretending generality |
| D2 schema | Production schema untouched; no churn before validation | The inherited "pre-registered fold-in" pattern WAS the drift — challenged and KILLED at lock (PATH B decided; no dual path remains) |
| D3 viewer | No build step; runs from file://; conventions reused | YES: shared rendering core is more aligned — named as incomplete decomplection with explicit reopen triggers, per the pragmatic-ban rule |
| D4 identity | 4-level best-available stack; measured | The original "primarily by domain" OVERSOLD an unmeasured source — measurement (55%) forced the honest claim; this is §5.8 measurement-as-design-instrument working |
| D5 Tier-1 | Zero-cost-unarmed observation; scheduler-orthogonal | The inherited "tools-only Phase 2" posture was CHALLENGED AND OVERTURNED — safety theater that made the owner's goal undeliverable; replaced by gated minimal hooks |
| D6 NTT | N/A claim scoped to read-side phases | Tightened: per-rider NTT obligation pre-registered for Phase 4 |
| D7 values | Bounded semantic unpacking, envelope-local | Watch: depth creep — capped sizes + Phase 4 rider for depth, not silent growth |

VAG requirement met: at least one inherited pattern challenged — two were
(the D2 fold-in dangle; the tools-only Phase 2 posture), both overturned.

## 8. Phase 0A — corpus definition + audit (iteration 47)

**Corpus** (all Level-3 clean via probe/process-file at this HEAD):

| File | commands | errors | rounds | diffs | fires | last-epoch net | captures | JSON |
|---|---|---|---|---|---|---|---|---|
| `examples/2026-06-12-ptf-track2-viz.prologos` (acceptance) | 17 | 0 | 45 | 91 | 380 | 36c/6p | 17 | 41KB |
| `lib/examples/prop-viz-demo.prologos` | 4 | 0 | 17 | 35 | 152 | 44c/9p | 4 | 31.5KB |
| `examples/relational-demo.prologos` | 16 | 0 | 17 | 1 | 18 | **87c/17p** | 16 | 27KB |

**B9 scale verdict**: max topology 87 cells / 17 propagators — far under the
1k-node D3 revisit trigger. Component-aware BFS layout stands. JSON ≤ 41KB.

**A4 free-path verdict: PARTIALLY VALIDATED, positive.** Round snapshots DO
carry solver topology (relational-demo's last epoch = 87c/17p, a solver
network distinct from its 41c/0p final elab-net), and solver work is visible
(acceptance: solver_unifies 73, solver_backtracks 17, atms_hypothesis_count 3).
CAVEAT (recorded, not resolved): relational-demo's 10 solve queries produced
only 18 observed fires — the share of solve execution that runs through
BSP-observable rounds vs DFS-internal steps is UNQUANTIFIED. Phase 2c
validates per-epoch solver topology on this corpus; the pre-registered 2b
solve-boundary observatory hook remains the fallback (per §7.7 A4).

**Doc-drift flag (found by the Level-3 gate)**: `map [int+ 1 _] '[...]` and
`map [int* _ 2] [...]` — the partial-application forms shown as idiomatic in
`.claude/rules/prologos-syntax.md` — fail "Could not infer type" under `map`
at this HEAD; the generic `plus` partials work. Acceptance file uses the
working forms with a NOTE; flagged for owner (syntax-doc or inference fix —
not this track's scope).
