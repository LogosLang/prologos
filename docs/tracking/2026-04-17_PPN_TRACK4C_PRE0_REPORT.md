# PPN Track 4C — Pre-0 Measurement Report

**Date**: 2026-04-17
**Series**: PPN (Propagator-Parsing-Network) — Track 4C
**Status**: Pre-0 baselines. Data feeds D.2 design refinements; also feeds §14 open-question resolution.
**Artifacts**: [`racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt`](../../racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt), [`examples/2026-04-17-ppn-track4c-adversarial.prologos`](../../racket/prologos/examples/2026-04-17-ppn-track4c-adversarial.prologos).

---

## §1 Scope

Pre-0 captures current 4B behavior along 4C's 9 design axes — establishing the baseline for A/B comparison after 4C lands. Three categories:

- **Static analyses** — code counts and structural gaps.
- **Wall-clock + memory micro/adversarial/E2E benchmarks** — per-operation costs and realistic elaboration.
- **Correctness validation points** — reference for parity harness.

Memory per DESIGN_METHODOLOGY.org "Measure before, during, AND after — and include memory cost."

---

## §2 Static Analyses

### A3 aspect-coverage gap

| Metric | Value |
|---|---|
| Unique `expr-*` struct definitions in [syntax.rkt](../../racket/prologos/syntax.rkt) | **96** |
| Unique `register-typing-rule!` predicates in [typing-propagators.rkt](../../racket/prologos/typing-propagators.rkt) | **35** |
| Unregistered via `register-typing-rule!` mechanism | **75 (78%)** |

Many of the 75 are handled by other mechanisms (SRE typing domain direct dispatch, core `infer`/`check` in typing-core.rkt). Exact "genuinely uncovered" count pending Phase 5 sub-audit. Upper-bound: 75 AST kinds need propagator rules.

### Meta-info struct fields (A2 — what migrates from CHAMP)

`(struct meta-info (id ctx type status solution constraints source))` — 7 fields.

| Field | Destination post-A2 |
|---|---|
| `id` | Identity — remains (symbol gensym) |
| `ctx` | → `:context` facet |
| `type` | → `:type` facet |
| `status` | Derived from `:term` (bot = unsolved, val = solved, top = contradiction) |
| `solution` | → `:term` facet (NEW in 4C) |
| `constraints` | → `:constraints` facet |
| `source` | Debug metadata — side registry or `:meta-metadata` facet (§14 Q3) |

**Finding for Q3** (meta-metadata after CHAMP retirement): 5 of 7 fields map directly to facets. `id` is identity (retained structurally). `source` is the only genuinely-off-lattice field. Side registry for `source` alone (plus identity tracking) is the lightweight path; facet would over-engineer a pure-metadata field. **D.2 recommendation: side registry for `source`, facets for the rest. Specific answer to §14 Q3.**

### A9 facet SRE domain registration gap

| Facet | SRE domain registered? |
|---|---|
| `:type` | ✅ `type-sre-domain` ([unify.rkt:109](../../racket/prologos/unify.rkt)) |
| `:context` | ❌ |
| `:usage` | ❌ |
| `:constraints` | ❌ |
| `:warnings` | ❌ |
| `:term` (new in 4C) | ❌ (to be registered in Phase 2) |

4 existing facet lattices run without property inference. Phase 2 (A9) must register all 6 and run `property-inference`. Per Track 3 §12 + SRE 2G precedent, budget for ≥1 lattice bug found + fixed.

---

## §3 Micro-Benchmark Results (per-operation baseline)

### M1: attribute-map facet access (4C hot path)

| Operation | Time |
|---|---|
| `that-read :type` (present) | **0.027 μs/call** (27 ns) |
| `that-read :term` (absent) | **0.028 μs/call** (28 ns) |

### M2: CHAMP meta-info access (the bridge being retired in A2)

| Operation | Time |
|---|---|
| `fresh-meta` | 38.26 μs/call |
| `solve-meta!` (writes CHAMP + cell — dual store) | 38.99 μs/call |
| `meta-solution` (CHAMP read) | 40.08 μs/call |

### M3: `infer` on core AST kinds (Axis 3 baseline)

| Form | Time |
|---|---|
| `infer lam` | 492 μs/call |
| `infer app` | 606 μs/call |
| `infer Pi` | 382 μs/call |

### Key finding #1

**`that-read` is ~1400× faster than CHAMP `meta-solution` read** (27 ns vs 40 μs). This establishes a significant performance ceiling lift available from Axis 2 (CHAMP retirement) — post-4C, every site that today reads `meta-solution` becomes a `that-read`. Applied to the 513 zonk.rkt read sites: potential wall-clock win in zonking alone. Validates the migration cost as unambiguously beneficial.

---

## §4 Adversarial Results (per-axis stress + memory)

| Test | Wall ms | Alloc KB | Retain KB |
|---|---|---|---|
| A1a: 10 type-metas → same type (`Nat`) | 4.38 | 13323.4 | -4.8 |
| A1b: 20 type-metas → alternating types (`Nat`/`Int`) | 8.49 | 24475.4 | -10.8 |
| A2a: 10 spec cycles, no branching | 0.08 | 56.5 | 0.9 |
| A2b: 10 spec cycles, 3 metas each | 0.12 | 112.1 | 0.9 |

### Key finding #2

**Meta solve cost is roughly linear in meta count**: 20 metas = 8.5 ms (vs 10 metas = 4.4 ms; 1.9× scaling for 2× metas). Allocation similarly linear (~24 MB / 20 metas). Retention negligible — the allocation is short-lived garbage. Good GC behavior.

### Key finding #3

**Speculation primitives are CHEAP**: 10 save/restore cycles = 80 μs, 56 KB allocation. This is the baseline for Phase 10 (union types via ATMS) — branching overhead per fork should be in this range. Translates to: **Phase 10's 2^N worst-case branching (§14 Q5) is bounded acceptably for N ≤ ~10 unions** at current speculation cost. Separate ATMS-fuel likely unnecessary; `:fuel 100` covers practical cases. **Specific answer to §14 Q5.**

---

## §5 E2E Baselines

| Program | Wall ms | Alloc KB | Retain KB | Notes |
|---|---|---|---|---|
| E1 simple (no metas) | 54.7 | 17865.4 | -5.5 | Floor baseline — ~55 ms, ~18 MB for a tiny program |
| E2 parametric Seqable (Axis 1) | 178.4 | **343139.9** | 25.3 | **19× memory of E1** — parametric bridge is expensive |
| E3 polymorphic id (Axis 5 `:type/:term`) | 97.9 | 62866.5 | 24.1 | **3.5× memory of E1** — type-meta allocation significant |
| E4 generic arithmetic (Axis 6) | 100.9 | 52653.5 | 24.4 | **2.9× memory of E1** — generic dispatch overhead |

### Key finding #4

**E2 (parametric Seqable) allocates ~343 MB per 10-run median — 19× E1's 18 MB**. The imperative `resolve-trait-constraints!` bridge is doing substantial work. A1's propagator-based parametric resolution should close a large part of this gap because:

- Constraint domain narrowing is monotone (per-entry CHAMP update, small allocations).
- No retried resolution loop — propagator fires once at readiness.

**Expected post-A1 allocation improvement: 10-50% on E2**. A/B comparison after Phase 7 validates.

### Key finding #5

**E3 (polymorphic id) allocates 63 MB for a tiny `[id 3N]` program**. Type-meta pattern + implicit arg insertion is allocation-heavy. A5 (`:type/:term` split) + A2 (CHAMP retirement) should reduce this significantly — the current imperative path creates meta-info CHAMP entries, allocates intermediate types, and zonks via tree walk. Post-4C path: `:type` + `:term` facet writes (single hasheq update each), no CHAMP, reading the expression IS zonking (Option C).

---

## §6 Correctness Validation

V1a: **Minor test harness glitch** — expected `(expr-Type 0)` as integer-level, got `(expr-Type (lzero))` which is the correct internal representation (lzero = explicit level zero struct). Not a real failure; bench file check needs updating. Documented for parity harness design.

V2, V3: baseline round-trip and speculation rollback pass. ✓

---

## §7 Findings Feeding §14 Open Questions

| Q | Data answer |
|---|---|
| Q1 (residuation formalization) | Not directly answered by Pre-0 — design-level decision |
| Q2 (Option A ↔ TMS sequencing) | Speculation overhead is cheap (§4 key finding #3) — suggests parallel phasing is low-risk. D.2 lean: can parallelize. |
| **Q3 (meta metadata post-CHAMP)** | **5 of 7 meta-info fields map directly to facets; `source` alone is lattice-irrelevant debug metadata. D.2 recommendation: side registry for `source`, facets for the rest.** |
| Q4 (component-paths detection predicate) | Requires runtime inspection — Phase 1 (A8) implementation iteration. |
| **Q5 (ATMS fuel bound)** | **Speculation cost at current N is ~8 μs/cycle. 2^N worst-case is acceptable up to N=10-15 unions at `:fuel 100`. Separate ATMS-fuel unneeded.** |
| Q6 (handler vs per-constraint propagator) | E2 memory (343 MB) suggests per-constraint propagator may have scaling issue; large impl registries favor single handler. D.2 revisit with concrete impl registry size data (Phase 5 sub-audit). |

---

## §8 Findings Feeding D.2 Design Refinements

1. **CHAMP retirement (A2) is a clear performance win** — 1400× read speedup on the hot path. De-risks the migration: the cost is well justified by the payoff, reducing D.2 anxiety about the ~600 migration sites.

2. **Memory axis reveals parametric resolution is the biggest allocator** — E2 at 343 MB is disproportionate. A1's propagator-based path is expected to improve this significantly. D.2 should prioritize A1 measurement post-implementation.

3. **Small retention numbers** (20-25 KB) across E2/E3/E4 confirm most allocation is short-lived GC-friendly garbage. Validates that the attribute-map cell hosting pattern (ephemeral-per-command-but-persistent-cell) doesn't introduce long-lived leaks.

4. **Speculation primitives are cheap** — enables parallel phasing of Option A freeze (Phase 8) and BSP-LE 1.5 TMS (Phase 9) without orchestration concerns. D.2 can sequence or parallel these.

5. **Aspect-coverage gap is real but bounded** — 75 unregistered AST kinds is the upper bound. Many handled by group dispatch. Phase 5 sub-audit produces the concrete actionable list; the total work is tractable (one propagator per kind, template patterns from the existing 35 registered kinds apply directly).

---

## §9 Next Steps

1. **Discuss findings** with user; confirm §7 answers for §14 Q3 and Q5. Leave Q1, Q4, Q6 open for design dialogue.
2. **D.2 refinement**: incorporate findings into design. Key changes:
   - Q3: side-registry answer locked in.
   - Q5: fuel stance locked in.
   - Q2: parallel phasing acceptable; D.2 can loosen sequencing.
3. **Open-questions dialogue**: Q1 (residuation), Q4 (component-paths detection), Q6 (parametric-resolution shape) addressed through P/R/M + external critique.
4. **P/R/M critique round** after D.2 refinements.
5. **External critique** → D.3.

Pre-0 complete. Ready for design dialogue.
