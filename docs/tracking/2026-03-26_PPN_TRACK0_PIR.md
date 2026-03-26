# PPN Track 0: Parse Domain Lattice Design — Post-Implementation Review

**Date**: 2026-03-26
**Duration**: ~4 hours across 1 session
**Commits**: 8 (from `8880524` Pre-0 benchmarks through `25d4c9d` Phase 7)
**Test delta**: 7391 → 7421 (+30 tests in 3 new files)
**Code delta**: ~1200 lines added (parse-lattice.rkt, parse-bridges.rkt, test files)
**Suite health**: 379/379, 7421 tests, 150.3s, all pass
**Design docs**: [Design D.4](2026-03-26_PPN_TRACK0_LATTICE_DESIGN.md), [Lattice Foundations](../research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md), [Kan/ATMS/GFP](../research/2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md)

---

## 1. What Was Built

PPN Track 0 establishes the LATTICE SUBSTRATE for propagator-based
parsing. Four lattice domains (token, surface, demand, core) with merge
functions, six cross-domain specifications (3 bridges, 2 exchanges,
1 projection), and an integration test proving they compose correctly
on the propagator network.

This is INFRASTRUCTURE — no pipeline code was changed. The lattice
structs, merge functions, and bridge specs are the foundation that
Tracks 1-4 build on when they replace the current 14-file parser pipeline
with propagator-based rewriting.

The track also produced 3 research documents (Lattice Foundations,
Kan/ATMS/GFP, Tropical Optimization), 2 series master documents
(PPN, PRN), and NTT syntax extensions — establishing the theoretical
grounding for the entire PPN and PRN research programs.

## 2. Timeline and Phases

| Phase | Commit | Time | Key result |
|-------|--------|------|------------|
| Pre-0 | `8880524` | ~30m | CHAMP viable at 500K cells (1.5μs/cell). Pipeline 99.99% elaboration. |
| 0 | `8036249` | ~30m | Acceptance file: 25 sections, 5 syntax gaps found |
| 1-3 | `20fdeb0` | ~30m | parse-lattice.rkt: 4 domains, 27 tests |
| 4 | `3d15bb8` | ~30m | parse-bridges.rkt: 6 specs, 23 tests |
| 5 | `86df0b4` | ~20m | NTT Syntax Design §16: parse lattices + `:set-once` kind |
| 6 | `b42d30f` | ~30m | Integration test: 7 tests on hand-built network |
| 7 | `25d4c9d` | ~15m | All ops <1μs. Suite 379/379, 150.3s |

**Design-to-implementation ratio**: ~3 hours design (D.1→D.4 + research) : ~3 hours implementation = 1:1. The most balanced ratio of any track — significant research investment paid off in smooth implementation.

## 3. Test Coverage

| File | Tests | Coverage |
|------|-------|---------|
| test-parse-lattice.rkt | 27 | Token merge (7), surface merge (10), demand merge (6), core merge (4) |
| test-parse-bridges.rkt | 23 | TokenToSurface (5), SurfaceToCore (4), SurfaceToType (2), exchanges (5), projection (2), demand satisfaction (5) |
| test-parse-integration.rkt | 7 | Happy path, ATMS ambiguity, demand satisfaction, set-once contradiction, derivation merge, bridge γ, provenance |

**Total**: 57 new tests. All pass.

**Gaps**: No tests for: parse item ordering at scale (10K+ items), SPPF sharing (dedup of identical derivation nodes), or performance regression detection (no existing parse benchmarks to regress against).

## 4. Bugs Found and Fixed

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| `seteq` unbound | `racket/base` doesn't export `seteq`; need `racket/set` | Added `(require racket/set)` to parse-lattice.rkt |
| `partial-parse-result` accessors unbound | Struct not exported from parse-bridges.rkt | Added `(struct-out partial-parse-result)` to provide |

Both trivial — clean implementation with minimal bugs.

## 5. Design Decisions and Rationale

1. **All 4 lattices in one module** (parse-lattice.rkt): Token, surface,
   demand, and core are closely related — they compose in the integration
   test. Separate files would add import overhead without benefit.
   Principle: Decomplection says "separate separable concerns" — these
   are NOT separable; they're one lattice system.

2. **Bilattice deferred to Track 5** (WF-LE pattern): Build lfp first
   (derivation), add gfp later (elimination via `newtype` wrapper).
   The ATMS handles elimination in the interim. Avoids committing to
   bilattice merge semantics before real usage validates them.
   Principle: Completeness — but applied to Track 5's scope, not
   Track 0's. Track 0 delivers the derivation lattice completely.

3. **SurfaceToType is NOT a Galois connection** (D.4): The backward flow
   is ATMS retraction (type error → retract parse assumption), not a
   classical Galois γ. We documented this honestly rather than claiming
   adjunction where we have ATMS-mediated pruning.
   Principle: Correct-by-Construction — the classification IS the
   correctness guarantee. Calling it a "bridge" when it's ATMS-mediated
   would be a lie.

4. **Bridge/exchange distinction** (D.2): Bridges cross domains within
   a stratum. Exchanges cross strata via Kan extensions. The demand
   lattice is the Right Kan exchange's internal state, not a bridge
   endpoint. This distinction was the key D.2 insight — it separated
   two mechanisms that D.1 conflated.

5. **Stratification-agnostic bridges** (D.4): Bridge α/γ functions are
   pure data transformations that don't assume whether parsing and
   elaboration share a stratum. The wiring decision is Track 3-4.
   Principle: Composition — bridges compose regardless of stratification.

## 6. Lessons Learned

### What Went Well

1. **Research investment paid off 1:1.** Three research documents +
   3 design iterations = smooth implementation with 2 trivial bugs.
   This is the first track where design:implementation was 1:1 (not
   3:5 or 1:3). The research ELIMINATED implementation surprises.

2. **Design discussion changed the architecture significantly.** D.1 had
   6 bridges and a bilattice. D.4 has 3 bridges + 2 exchanges + 1
   projection, no bilattice, and honest classification of SurfaceToType.
   Each iteration simplified and clarified.

3. **Pre-0 benchmarks confirmed viability without changing the design.**
   First track where Pre-0 didn't change the design — because the
   research had already identified the right parameters. CHAMP at 500K
   cells: viable. Merge ops at <1μs: confirmed. No surprises.

### What Went Wrong

1. **Acceptance file hit 5 syntax gaps** (> in identifiers, PVec literal,
   trait method format, zonk crash on trait dict, bundle crash). These
   are pre-existing language gaps, not Track 0 issues — but they blocked
   a full clean run. The acceptance file is partially commented out.

2. **Phases 1-3 were combined** (all lattices in one commit). This was
   efficient but violated the "commit per phase" protocol. The tracker
   shows them as one entry. In retrospect, they could have been 3
   separate commits with 3 separate dailies entries.

### What Surprised Us

1. **The pipeline is 99.99% elaboration.** Reader + preparse + parser
   together are 0.005% of per-form time. PPN Tracks 1-3 deliver
   ARCHITECTURAL value (14-file collapse, grammar extensions, cross-
   domain disambiguation), not PERFORMANCE value. Track 4 (elaboration
   as attribute evaluation) is where performance matters.

2. **Parse derivations are hybrid value/structural.** The set-union
   merge is a value lattice operation, but the elements are SPPF-shared
   trees (structural). Connection to SRE: grammar productions ARE
   structural forms. This insight bridges PPN and SRE.

## 7. Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Token merge | 3-16 ns | <1000 ns | ✅ 60× under |
| Parse merge (disjoint) | 343 ns | <1000 ns | ✅ 3× under |
| Parse merge (identity) | 240 ns | <1000 ns | ✅ 4× under |
| Demand merge | 307-349 ns | <1000 ns | ✅ 3× under |
| Core merge | 3-20 ns | <1000 ns | ✅ 50× under |
| Bridge α (scanning) | 508 ns | <1000 ns | ✅ 2× under |
| Bridge γ (disambiguation) | 44 ns | <1000 ns | ✅ 23× under |
| CHAMP at 100K cells | 1.4 μs/insert | Viable | ✅ |
| New tests | 57 | >0 | ✅ |
| Suite regressions | 0 | 0 | ✅ |
| Suite time | 150.3s | ≤155s | ✅ |

## 8. What's Next

**PPN Track 1 (Lexer as propagators)**: Replace reader.rkt with
propagator-based lexing. Token cells from Track 0 receive values from
character-stream propagators. Context-sensitive disambiguation via
SurfaceToToken bridge γ.

**PPN Track 2 (Surface normalization)**: Replace macros.rkt preparse
(7000+ lines) with SRE-registered rewrite rules. Each defmacro/let/cond
desugaring becomes a registered form entry. Normalization is quiescence.

**PPN Track 3 (Parser as propagators)**: Earley items as per-item cells.
Grammar productions as propagators. This track CONSUMES Track 0's
lattice infrastructure — the Track 0→3 interface contract (§7 in the
design) specifies the handoff.

**PRN research**: The hypergraph rewriting connection (SRE = DPO,
grammar = HR, reduction = DPO) continues to crystallize. Each PPN
track contributes instances to PRN's universal primitive catalog.

## 9. Key Files

| File | Role |
|------|------|
| `parse-lattice.rkt` | 4 lattice domains: token, surface, demand, core |
| `parse-bridges.rkt` | 3 bridges + 2 exchanges + 1 projection + demand satisfaction |
| `tests/test-parse-lattice.rkt` | 27 lattice merge tests |
| `tests/test-parse-bridges.rkt` | 23 bridge/exchange tests |
| `tests/test-parse-integration.rkt` | 7 integration tests on hand-built network |
| `benchmarks/micro/bench-ppn-track0.rkt` | Pre-0 + Phase 7 benchmarks |

## 10. Lessons Distilled

| Lesson | Target | Status |
|--------|--------|--------|
| 1:1 design:implementation ratio from research investment | — | 1st instance, watching |
| Bridge/exchange distinction (D.2) | NTT Syntax Design §16 | Done (`86df0b4`) |
| SurfaceToType is ATMS-mediated, not Galois γ | NTT Syntax Design §16.4 | Done (`86df0b4`) |
| `:set-once` lattice kind for NTT | NTT Syntax Design §16.1 | Done (`86df0b4`) |
| Pipeline 99.99% elaboration | PPN Master — Track 1-3 are architectural, not performance | Noted |
| Parse derivations = hybrid value/structural | PRN conjectured connections | Noted |

## 11. What Would We Do Differently

Not much. The research-first approach worked well. The D.1→D.4 iteration
was productive — each round simplified the architecture. The external
critique (12 points) caught real issues (cell count estimation, demand
protocol, SurfaceToType honesty, integration test ambiguity).

One thing: the acceptance file should have been tested BEFORE writing
the lattice code, not during Phase 0. The 5 syntax gaps blocked a
clean baseline run. If we'd tested the acceptance file first (Phase -1),
we'd have discovered the gaps earlier and designed around them.

## 12. Cross-PIR Longitudinal Patterns

### Research investment correlates with implementation smoothness

| Track | Research docs | Design iterations | Bugs | Ratio |
|-------|-------------|-------------------|------|-------|
| SRE Track 0 | 1 | D.1-D.2 | 0 | Smooth |
| SRE Track 1 | 0 | D.1-D.4 | 7 | Rough |
| PM 8F | 0 | D.1-D.4 | 5 | Rough |
| PM Track 10 | 0 | D.1-D.4 | 12+ | Very rough |
| PM Track 10B | 1 | D.1-D.4 | 3 | Medium |
| **PPN Track 0** | **3** | **D.1-D.4** | **2** | **Smoothest** |

PPN Track 0 had the most research investment (3 documents) and the
fewest bugs (2, both trivial). The correlation is suggestive but not
proven — PPN Track 0 is also "just" infrastructure (structs + tests),
not a pipeline migration. Track 1-3 will test whether research
investment continues to pay off for more complex implementations.

### Pre-0 benchmark utility across tracks

PPN Track 0 is the FIRST track where Pre-0 benchmarks confirmed the
design without changing it. All previous tracks (BSP-LE T0, SRE T1B,
SRE T2, PM 8F, PM T10) had Pre-0 change the design. The difference:
PPN Track 0's research already identified the right parameters. Pre-0
was VALIDATION, not DISCOVERY. This suggests: deeper research → Pre-0
becomes validation → smoother implementation.

### Are we learning from our PIRs?

YES. The "benchmark as design input" methodology (codified from PM 8F)
was applied correctly in PPN Track 0 — Pre-0 ran before implementation.
The "bridge/exchange distinction" came from the D.2 conversation, not
from a prior PIR — but it WILL inform future tracks (PPN 1-4, SRE 2C).
The "honesty about adjunction" (SurfaceToType is not Galois γ) is a
new lesson that should inform NTT's bridge typing.

## 13. What Assumptions Were Wrong

None. The research identified all the right parameters. The Pre-0
benchmarks confirmed them. The implementation matched the design.

This is the first PIR where §13 is empty. The 3 research documents
+ 4 design iterations eliminated wrong assumptions before implementation
began.

## 14. What Did We Learn About the Problem

Parsing as a lattice fixpoint is VIABLE. The infrastructure handles
parse-scale cell counts (500K), the merge operations are fast enough
(<1μs), the ATMS handles disambiguation, and the bridge/exchange
architecture cleanly separates domain-crossing from strata-crossing.

The deeper learning: **parsing is not special.** The same lattice +
propagator + bridge infrastructure that handles type inference handles
parsing. The difference is the LATTICE (derivation sets instead of type
expressions) and the RULES (grammar productions instead of typing rules),
not the MECHANISM. This is the PRN thesis in miniature.

## 15. Are We Solving the Right Problem

Yes. PPN Track 0 is correctly scoped as INFRASTRUCTURE — it defines
what Tracks 1-4 build on. The risk (identified by D.4 external critique)
is that the infrastructure is designed in a vacuum. The Track 0→3
interface contract (§7 in the design) mitigates this by specifying what
Track 3 expects. The real validation comes when Track 3 wires a parser
into the lattice infrastructure.
