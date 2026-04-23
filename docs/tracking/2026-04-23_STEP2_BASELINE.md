# PPN 4C Addendum Step 2 — Performance Baseline + Hypotheses

**Date**: 2026-04-23
**Purpose**: Pre-Step-2 performance baseline; hypotheses for PU refactor's impact; validation criteria for post-Step-2 A/B comparison. Part of the measurement discipline codified this session (see §6).
**Context**: Step 2 of 1A-iii-a-wide (PU refactor + hasse-registry integration). Per D.3 §7.5.4 deliverables.
**Prior art**:
- [`2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md`](2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md) — original thesis + 25-site struct-copy audit
- [`2026-03-21_BSP_LE_TRACK0_ALLOCATION_EFFICIENCY_DESIGN.md`](2026-03-21_BSP_LE_TRACK0_ALLOCATION_EFFICIENCY_DESIGN.md) — the allocation-efficiency track design
- [`2026-03-21_BSP_LE_TRACK0_PIR.md`](2026-03-21_BSP_LE_TRACK0_PIR.md) — delivered: hot/warm/cold struct split, mutable drain loop, batch cell registration
- [`2026-04-17_PPN_TRACK4C_PRE0_REPORT.md`](2026-04-17_PPN_TRACK4C_PRE0_REPORT.md) — PPN 4C's Pre-0 baselines at track start
**Design doc**: [`2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) §7.5.4 Step 2 deliverables

---

## §1 Headline: meta-lifecycle cost has dropped dramatically since PPN 4C began

Comparing today's `bench-meta-lifecycle.rkt` (post-T-2) against 2026-04-17 PPN 4C Pre-0 baselines:

| Operation | Pre-PPN-4C (2026-04-17) | Post-T-2 (2026-04-23) | Factor |
|---|---|---|---|
| `fresh-meta` (with network) | 38.26 μs/call | 3.45 μs/call | **~11× faster** |
| `solve-meta!` | 38.99 μs/call | 8.53 μs/call | **~4.6× faster** |
| `meta-solution` (cell path) | 40.08 μs/call (CHAMP-only) | 0.205 μs/call | **~195× faster** (path changed) |
| `meta-solution/cell-id` (direct) | — (new path) | 0.344 μs/call | — |

**Caveats**:
- Pre-PPN-4C figures measured the CHAMP-bound path. Post-PPN-4C has an on-network cell path that's faster by construction; the 195× on `meta-solution` reflects a path change, not just optimization of the same path.
- `fresh-meta` and `solve-meta!` figures ARE apples-to-apples (same operation, same harness shape), and those are the ~11× and ~4.6× improvements.

The work delivered over PPN Track 4 + 4B + 4C-through-T-2 has already been closing the gap the 2026-03-20 audit predicted. Step 2's PU refactor continues this trajectory.

### Suite-level stability

Full-suite timings are remarkably stable:
- 2026-03-30 (pre-PPN-4C, post-BSP-LE-Track-0): 122-128s range (median ~125s)
- 2026-04-22 (post-Step-1+T-1): 126.7s
- 2026-04-23 (post-T-2): **118.4s** (-6.5%)

T-2 gave a small but real suite-level improvement — primarily from retiring the `with-speculative-rollback` path at map-assoc (probe `speculation_count` 12 → 0).

---

## §2 Baseline measurements — bench-meta-lifecycle (2026-04-23)

Full output from `benchmarks/micro/bench-meta-lifecycle.rkt`:

### A1: fresh-meta creation
- `fresh-meta (with network)`: **3453.0 ns/call** (10000 calls)

### A2: solve-meta! cost
- `solve-meta! (with network + resolution)`: **8531.0 ns/call** (5000 calls)

### A3: meta-solution read
- `meta-solution (solved, cell path)`: **205.0 ns/call** (50000 calls)
- `meta-solution (unsolved, cell path)`: **203.0 ns/call** (50000 calls)

### A3b: meta-solution/cell-id (fast path)
- `meta-solution/cell-id (solved, direct cell)`: **344.0 ns/call** (50000 calls)
- `meta-solution/cell-id (unsolved, direct cell)`: **351.0 ns/call** (50000 calls)

### A4: prop-meta-id->cell-id
- `prop-meta-id->cell-id`: **67.0 ns/call** (50000 calls)

### A5: raw cell read
- `elab-cell-read (direct)`: **112.0 ns/call** (50000 calls)
- `unbox net-box`: **3.0 ns/call** (50000 calls)

### B: zonk costs
- `zonk ground (Pi Int Bool)`: 1063.0 ns/call
- `zonk 1 solved meta (Pi ?X Bool, ?X=Int)`: 1307.0 ns/call
- `zonk 5 solved metas (nested Pi + app)`: 6057.0 ns/call
- `zonk deep (5-level Pi tree, 32 metas)`: 42325.0 ns/call
- `zonk-at-depth 0 (same as zonk)`: 298405.0 ns/call
- `zonk-at-depth 3 (under 3 binders)`: 423533.0 ns/call
- `zonk-final (solved meta + defaults)`: 3288.0 ns/call

### C: adversarial
- `zonk 100-meta app chain`: 130005.0 ns/call
- `zonk 10-deep meta chain`: 5080.0 ns/call
- `zonk large expr with 1 meta at depth 10`: 10873.0 ns/call

**Observation**: `zonk-at-depth 0` is ~300μs/call — a hot path. Step 2 doesn't directly target zonk but PU refactor may reduce zonk's per-call cell lookups.

---

## §3 Baseline measurements — bench-alloc (2026-04-23)

### Cell / propagator allocation
- `net-new-cell`: **0.56 μs/op** (50K cells × 50 rounds, stddev 0.46ms / 27.76ms ≈ 1.6%)
- `net-cell-write (all change)`: **0.43 μs/op**
- `net-cell-write (all no-change)`: **0.14 μs/op** — 3× cheaper than change path (eq?-first fast path working)
- `net-add-propagator`: **1.61 μs/op** (2 inputs)
- `struct-copy prop-network (worklist only)`: **0.01 μs/op** — post-BSP-LE-Track-0 hot/warm/cold split is working

### run-to-quiescence (full pipeline)
- `run-to-quiescence: 500-cell chain × 20 rounds`: **16393.70 μs/op** (16.4ms per run)
  - The full propagation cycle on a 500-propagator chain costs ~16ms — the hot path for elaboration workloads where propagator networks are non-trivial.

### Change/no-change ratio
After first propagation reaches quiescence, second propagation shows **0/50 cells changed — 100% no-change ratio**. The network is at fixed point; worklist-driven scheduling correctly avoids redundant work.

### CHAMP-level baselines (foundational)
- `champ-insert (1000 sequential keys)`: 0.17 μs/op
- `champ-insert (1000 scrambled keys)`: 0.19 μs/op
- `champ-insert (500 value-only updates)`: 0.10 μs/op
- `champ-lookup (10000 hits on 500-entry map)`: **0.04 μs/op** — very fast read path
- `champ-transient cycle (100 inserts on 500-entry map)`: **2.51 μs/op**
- `champ-insert (50000 single-key fresh maps)`: 0.03 μs/op — node construction baseline

### Owner-ID transients (faster than CHAMP transient)
- `owner-ID transient cycle (100 inserts)`: **0.24 μs/op** — ~10× faster than CHAMP transient
- `owner-ID transient (500 value-only updates)`: 0.06 μs/op
- `owner-ID transient (10 deletes)`: 0.80 μs/op

### Memory
- 500-cell chain × 100: retained **83.5 KB delta** — remarkably low retention
- 1000-cell chain × 50 quiescence: **0.1% GC ratio** (GC time is negligible vs wall time)
- 5000 sequential cell allocations: 0.0% GC ratio, 696.7 KB retained
- 2000 propagator allocations: 0.0% GC ratio

### Implication for Step 2

Current per-meta cost breakdown:
- `fresh-meta` (3.45 μs) ≈ `net-new-cell` (0.56 μs) + CHAMP-insert into id-map (~0.17 μs) + elab-network struct-copy + meta-info registration overhead (~2.7 μs remaining)

Under Step 2 PU refactor, `fresh-meta` becomes:
- Lookup universe cell-id (compile-time constant)
- `hasheq-insert` of meta-id → tagged-cell-value into universe's value (CHAMP-hashpartial op, ~0.17 μs per above)
- Single `net-cell-write` to the universe cell (~0.43 μs)
- meta-info registration stays (~1-2 μs)

**Prediction**: `fresh-meta` drops from 3.45 μs → ~1.5-2.0 μs/call (~40-55% reduction). Driven by:
1. Elimination of per-meta cell allocation (`net-new-cell` × 1 saved = 0.56 μs gone)
2. Elimination of id-map CHAMP insert (cell-id lookup is now universe-cell-id directly = 0.17 μs gone)
3. Only the universe-cell write + hasheq-insert remain

**Owner-ID transient observation** (Step 2 consideration): the owner-ID path shows 10× faster amortized cost for batch updates. If `compound-tagged-merge` can use owner-ID for fast-path per-meta updates within a single elaboration, per-meta cost could drop further. Worth evaluating during Step 2 implementation — probably not in S2.a (infrastructure) but worth flagging for S2.c (type domain migration) optimization if hot.

---

## §4 Probe per-command breakdown (post-T-2)

From `examples/2026-04-22-1A-iii-probe.prologos` with `#:verbose #t` (28 commands):

### Phase-timing aggregate (sum of 28 commands)
```
elaborate_ms: 38
parse_ms:      0
qtt_ms:       41
reduce_ms:    88
type_check_ms: 75
zonk_ms:       2
----
total:       244 ms
```

### Where time actually goes (per-command wall_ms)

Hot commands (wall_ms > 100):
- `cmd 18` (p5-list cons chain): **589 ms** — reduce_steps=21, unify_steps=18, 6 metas
- `cmd 20` (head): **584 ms** — reduce_steps=51, 3 metas
- `cmd 21` (tail): **239 ms** — reduce_steps=38, 1 meta
- `cmd 10` (p2-compose): **141 ms** — unify-heavy
- `cmd 11` (p2-compose eval): **128 ms** — reduce-heavy

Typical commands: 14-80 ms. Hot outliers dominate total wall-time.

### Finding

**Reduction cost (evaluation) dominates wall time for hot commands, not elaboration.** Hot commands are list-op heavy (cons-chain, head, tail). Step 2's PU refactor affects ELABORATION + META INFRASTRUCTURE (elaborate_ms + type_check_ms + qtt_ms totaling ~154ms), not reduction (88ms). Expected Step 2 impact on hot commands: modest (they're already mostly-reduce).

Step 2 wins will concentrate in commands with many metas (cmd 18 has 6 metas, cmd 20 has 3) and commands that allocate many cells per elaboration.

### Cell allocation per command

`cell_allocs` ranges 26-48 per command. Total: 1071 across 28 commands. `meta_created`: 16 across 28 commands.

So ~66 cell_allocs per meta created (10000s of cell-writes per meta lifecycle). Per-meta cost in cell-writes is the real target.

---

## §5 Hypotheses for Step 2

### Quantitative predictions

| Metric | Pre-Step-2 | Step-2 predicted | Mechanism |
|---|---|---|---|
| `fresh-meta` per-call | 3.45 μs | **1.5-2.0 μs** | No `net-new-cell`; hasheq-insert into universe |
| `solve-meta!` per-call | 8.53 μs | **5-7 μs** | Same writeover cost; no id-map update |
| `meta-solution` (cell path) | 0.205 μs | **0.25-0.35 μs** | Hash-ref into universe vs direct cell read (slightly SLOWER by constant) |
| Probe `cells` | 50 | **~35-40** | 16 meta cells → 4 universe cells (net -12) |
| Probe `cell_allocs` (total) | 1071 | **~850-950** | Fewer struct-copy prop-network per meta-creation |
| Probe `meta_created` | 16 | unchanged | Same logical metas |
| Probe `prop_firings` | 0 (this probe) | unchanged | Component-paths preserve granularity |
| Probe `wall_ms` total | ~2500 | **-5 to -10%** | Allocation savings + reduced struct-copy |
| Probe `mem_retained_bytes` | 3.33 MB | **~2.8-3.0 MB** | Fewer cell struct instances; 1 hasheq per universe |
| Full suite wall time | 118.4s | **114-118s** | Conservative; most tests aren't meta-heavy |

### Qualitative predictions

1. **Meta-read micro may slightly regress** (hash-ref overhead vs direct cell access). If regression > 30%, investigate; if < 30%, accept (trade for allocation wins).
2. **Allocation wins dominate memory retention** — the 50 cells per command were each struct-copying prop-cell into prop-net; going to 4 structs + one hasheq should shrink prop-net's cells vector substantially.
3. **GC pressure should decrease** — fewer short-lived prop-cell instances per command. `bench-ppn-track4c.rkt`'s E1-E4 memory deltas should show improvement proportional to meta count (E3 polymorphic-id was 63 MB for a tiny program; should drop meaningfully).

### Success criteria (VAG quantitative)

Step 2 ships with confidence if:
- [ ] `fresh-meta` ≤ 2.5 μs/call (27% reduction from 3.45 μs)
- [ ] `solve-meta!` ≤ 8 μs/call (6% reduction from 8.53 μs, or at worst neutral)
- [ ] `meta-solution` (post-Step-2 path) ≤ 0.4 μs/call (allows for hash-ref overhead)
- [ ] Probe `cells` ≤ 42 (allows some margin from 40 target)
- [ ] Probe `cell_allocs` ≤ 1000 (allows some margin from 950 target)
- [ ] Full suite ≤ 122s (accepts some constant-factor regression)
- [ ] Memory (E3 polymorphic-id from bench-ppn-track4c): ≥ 10% reduction from pre-Step-2 run

Regression beyond these: halt, investigate.

### Neutral-or-potentially-slower paths

Honestly flagged:
- **Per-meta read through hasheq-ref**: current direct `net-cell-read` is 112ns; adding a hasheq-ref in the compound cell value adds ~100-150ns constant. Mitigation: for hot paths, we can cache meta-id → universe-component-path in meta-info metadata.
- **`compound-tagged-merge`**: merging two hasheqs pointwise has O(N) in number of keys vs per-cell O(1). Could be slower for large meta-sets, faster for small (no per-meta cell struct-copy).
- **Component-path filtering overhead**: propagators declaring `(cons universe-cell-id meta-id)` as their component-path require dependent-firing logic to check membership — adds O(1) per propagator dispatch but filters out many spurious firings.

---

## §6 Measurement discipline — bounce-back, not automatic gate

Per dialogue 2026-04-23: "more data-driven and informed decisions" — BUT "bounce back to me whether we should invest into it. Could be undue tax on time and development iterations; needs to balance with needs, not just be an automatic gate."

### The rule

**Per-phase Claude→user bounce-back**: when Claude identifies a phase as plausibly perf-material, Claude proposes measurement (what to measure, why, rough cost) → user decides. NOT an automatic trigger. Balance investment against development velocity on a case-by-case basis.

### Claude's responsibility

For each phase, Claude evaluates:
1. **Is this phase plausibly perf-material?** (e.g., changes allocation pattern, elaboration path, hot-function dispatch)
2. **If yes**: propose measurement scope (which micros, estimated cost, what hypothesis the measurement would validate)
3. **If no**: proceed without proposing measurement; note in commit message that perf was deemed out-of-scope

### User's decision criteria (informative, not prescriptive)

Reasonable grounds for user to decline measurement:
- Phase is on critical path; measurement delay isn't worth the information
- Hypothesis from prior phases already covers what this phase would reveal
- Measurement infrastructure isn't ready (e.g., new micros needed would exceed phase scope)
- Enough context exists to trust the perf outcome without dedicated measurement

Reasonable grounds to approve measurement:
- Phase transitions a major architectural pattern (compound cells, new API)
- Phase retires a significant mechanism (old path now dead)
- Prior measurements flagged this area as sensitive
- Stage 4 Step 5 VAG (vision-advancing?) criterion requires numeric validation

### What Claude WILL always do (without needing user approval)

- Probe verbose run after any phase that touches typing/elaboration (cheap, <1s)
- Full-suite timing comparison against `timings.jsonl` (free, automatic)
- Note significant-feeling deltas in dailies even absent formal measurement

### What Claude WILL propose but wait for approval

- Running `bench-meta-lifecycle` / `bench-alloc` / `bench-ppn-track4c` micros (~3-10 min each)
- A/B comparison via `bench-ab.rkt` (~5-15 min)
- New micros specifically constructed for a phase (variable cost)
- Hypothesis documents like this one (substantial writing time)

### Pre-negotiated measurement plan for Step 2

Already approved per 2026-04-23 dialogue:
- **Measurement at S2.b close** (first domain migration — validates the PU pattern): `bench-meta-lifecycle` + `bench-alloc` + relevant slice of `bench-ppn-track4c`; compare vs §2/§3/§11 baselines
- **Measurement at S2.e close** (retirement of old factories — final validation): full baseline re-run; compare vs all §5 hypotheses; §12 "Actual vs Predicted" section added to this doc
- **Skipped for S2.a, S2.c, S2.d, S2.f**: no measurement unless anomaly surfaces

Subsequent phases (Phase 1E, 1B, etc.): Claude proposes when the phase opens; user decides.

### What this doc serves (self-reference)

This baseline doc IS the `2026-04-23`-snapshot reference for post-Step-2 validation. Its §5 hypotheses + §2/§3/§11 baselines are the explicit acceptance criteria. At Step 2 close, §12 "Actual vs Predicted" gets added inline.

---

## §7 Deferred measurements

### Post-Phase-4 (CHAMP retirement)

Full meta-store efficiency measurement needs meta-info CHAMP retired. Until then:
- `source` registry still off-network
- `id-map` still parallel to cell-id lookups
- Full `fresh-meta` cost still includes CHAMP-insert overhead

Step 2 removes per-meta cell allocation; Phase 4 removes the CHAMP store. BOTH are required for the full "meta cost is just hasheq operations" state.

**Re-run full baseline** at Phase 4 close.

### Post-Phase-3-addendum (fork-on-union + hypercube)

Parallel-execution-ready measurement needs:
- Hypercube scheduler landed (Phase 3B)
- Tropical fuel primitive (Phase 1B)
- Component-path-driven dependent firing (already landed via PPN 4C Phase 1f)

We can measure Step 2's contribution to PARALLEL-READINESS structurally (reduction in cell count, compound-cell sharing efficiency) now. Actual wall-clock parallel speedup is Phase 3 addendum measurement.

**Re-run parallel-scaling benchmarks** (`bench-parallel-scaling.rkt`, `bench-parallel-stress.rkt`) at Phase 3 addendum close.

### Post-PM-12 (module loading on network)

True user-facing elaboration cost measurement requires:
- Phase 4 (CHAMP retirement)
- Phase 3 addendum (parallel execution)
- PM Track 12 (module loading on network)

Until all three land, "elaboration is fast for users" can't be fully measured. Target measurement: loading the full prelude (~30 modules) + running the test suite.

**Re-run acceptance files with wall-clock** at PM Track 12 close.

---

## §8 Pending data

- [x] ~~Complete `bench-alloc.rkt` output~~ — landed in §3
- [x] ~~Run `bench-ppn-track4c.rkt` M1-M6 + A1-A4 + E1-E4 tiers with memory~~ — landed in §11
- [x] ~~Save current outputs as reference for post-Step-2 A/B comparison~~ — this doc serves
- [ ] Bench-ppn-track4c V1a correctness harness glitch (1 failure) — pre-existing (same as 2026-04-17 PRE0); investigate only if Step 2 validation surfaces it

## §11 bench-ppn-track4c full A/B: PRE0 (2026-04-17) → Post-T-2 (2026-04-23)

Direct comparison against [`2026-04-17_PPN_TRACK4C_PRE0_REPORT.md`](2026-04-17_PPN_TRACK4C_PRE0_REPORT.md). Same harness, same benchmarks.

### Micro (M-tier)

| Bench | PRE0 | Post-T-2 | Delta |
|---|---|---|---|
| M1 `that-read :type` | 0.027 μs | 0.03 μs | ~neutral (within noise) |
| M1 `that-read :absent` | 0.028 μs | 0.03 μs | ~neutral |
| M2 `fresh-meta` (CHAMP path) | 38.26 μs | 32.15 μs | **-16%** |
| M2 `solve-meta!` (dual store) | 38.99 μs | 40.66 μs | +4% (within noise) |
| M2 `meta-solution` (CHAMP read) | 40.08 μs | 41.95 μs | +5% (within noise) |
| M3 `infer lam` | 492 μs | 460.94 μs | **-6%** |
| M3 `infer app` | 606 μs | 563.46 μs | **-7%** |
| M3 `infer Pi` | 382 μs | 355.45 μs | **-7%** |

**Important path distinction**: M2 measures the CHAMP-bound `meta-solution` path (still in place pending Phase 4 CHAMP retirement). `bench-meta-lifecycle` measures the newer cell path (3.45 μs fresh-meta, 0.205 μs meta-solution). **The cell path is 10× faster than the CHAMP path for fresh-meta, 200× faster for reads.** Step 2 continues the migration direction; Phase 4 retires the slower CHAMP path entirely.

### Adversarial (A-tier)

| Bench | PRE0 wall | Post-T-2 wall | Delta | PRE0 alloc | Post-T-2 alloc |
|---|---|---|---|---|---|
| A1a 10 type-metas same type | 4.38 ms | 3.79 ms | **-13%** | 13323 KB | 13346 KB |
| A1b 20 type-metas alternating | 8.49 ms | 7.52 ms | **-11%** | 24475 KB | 24507 KB |
| A2a 10 spec cycles no branching | 0.08 ms | 0.06 ms | **-25%** | 56.5 KB | 60.6 KB |
| A2b 10 spec cycles 3 metas each | 0.12 ms | 0.10 ms | **-17%** | 112.1 KB | 117.3 KB |

A-tier shows 11-25% wall-time improvements — these are the type-meta-heavy paths that moved the most. Allocation patterns are nearly identical (deep alloc structure hasn't changed; CHAMP retirement (Phase 4) is the lever).

### E2E (E-tier)

| Program | PRE0 wall | Post-T-2 wall | Δ wall | PRE0 alloc | Post-T-2 alloc | Retention Δ |
|---|---|---|---|---|---|---|
| E1 simple (no metas) | 54.7 ms | 53.50 ms | -2% | 17865 KB | 17932 KB | ~same |
| E2 parametric Seqable | 178.4 ms | 171.41 ms | **-4%** | 343139 KB | 346036 KB | 25.3 → 19.9 KB |
| E3 polymorphic id | 97.9 ms | 95.65 ms | -2% | 62866 KB | 65221 KB | ~same |
| E4 generic arithmetic | 100.9 ms | 97.06 ms | **-4%** | 52653 KB | 54065 KB | ~same |

E-tier shows 2-4% wall improvements. Allocation volume unchanged (the alloc-heavy paths are parametric Seqable's imperative resolution loop — retired by Phase 7 A1). Retention is roughly flat or slightly better.

**Key finding**: E2 (parametric Seqable at 343 MB alloc per run) remains the allocation outlier. Step 2 DOES NOT directly target this — E2's cost is the imperative `resolve-trait-constraints!` bridge (Phase 7 scope). Step 2 will NOT move E2 significantly; don't predict a big change there.

### Correctness
- V1a (harness glitch, minor): 1 failure. Pre-existing from PRE0 ("expected `(expr-Type 0)` as integer-level, got `(expr-Type (lzero))`"). Not a T-2 regression. Documented for eventual parity harness cleanup.

### Aggregate assessment

Benchmarks have moved **meaningfully but unevenly** since PPN 4C started (2026-04-17 → 2026-04-23):

- **Type-meta-heavy paths**: 11-25% faster (A1a/b, A2a/b)
- **Cell-path meta ops** (not measured in this bench, but in bench-meta-lifecycle): 10-200× faster
- **Infer core forms** (M3): 6-7% faster
- **E-tier programs**: 2-4% faster
- **Allocation volume**: nearly unchanged (major alloc wins pending Phase 4 + Phase 7)
- **Memory retention**: slightly better in E2 (19.9 KB vs 25.3 KB), roughly neutral elsewhere
- **CHAMP path** (M2): ~flat on reads/writes, -16% on fresh-meta creation

The architectural work (PPN 4A/B, 4C Phases 1-3, T-3, Step 1, T-1, T-2) has moved the needle on type-meta infrastructure meaningfully. The deeper allocation wins are gated on Phase 4 (CHAMP retirement) + Phase 7 (parametric resolution) + PM 12 (module loading). **Step 2's contribution will be incremental on top** — per-meta cell allocation elimination, measured as ~40-55% drop in `fresh-meta` cell path, ~8-12 fewer cells per command in probe.

---

---

## §9 Cross-references

- Step 2 design: [D.3 §7.5.4](2026-04-21_PPN_4C_PHASE_9_DESIGN.md)
- Step 2 mini-design dialogue: D.3 §7.5.4 (to be extended with §7.5.15 after Step 2)
- Prior art:
  - [2026-03-20 CELL_PROPAGATOR_ALLOCATION_AUDIT](2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md)
  - [BSP-LE Track 0 Design](2026-03-21_BSP_LE_TRACK0_ALLOCATION_EFFICIENCY_DESIGN.md)
  - [BSP-LE Track 0 PIR](2026-03-21_BSP_LE_TRACK0_PIR.md)
  - [PPN 4C Pre-0 Report](2026-04-17_PPN_TRACK4C_PRE0_REPORT.md)
- Design principles:
  - [`propagator-design.md`](../../.claude/rules/propagator-design.md) § Cell Allocation Efficiency
  - [`structural-thinking.md`](../../.claude/rules/structural-thinking.md) § Direct Sum Has Two Realizations
  - [DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) § Measure before, during, and after

---

## §10 Status

**COMPLETE** 2026-04-23. All 3 baselines captured (bench-meta-lifecycle §2, bench-alloc §3, bench-ppn-track4c §11). Probe verbose captured in §4. PRE0→post-T-2 A/B comparison documented (§11). Hypotheses stated (§5). Measurement discipline proposed (§6). Deferred measurements scoped (§7).

**Next**: begin Step 2 S2.a infrastructure work per D.3 §7.5.4. Validate post-Step-2 per §5 success criteria. Update with §12 "Actual vs Predicted" at Step 2 close.
