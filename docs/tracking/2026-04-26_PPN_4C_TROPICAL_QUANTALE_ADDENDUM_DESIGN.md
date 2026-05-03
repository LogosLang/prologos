# PPN Track 4C Tropical Quantale Addendum: Phase 1 Substrate Completion — Design

**Date**: 2026-04-26
**Stage**: 3 — Design per [DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) Stage 3
**Version**: D.3 — D.2.SC self-critique findings incorporated (in progress; per-finding resolution review with user)
**Scope**: PPN 4C Phase 1A-iii-b + 1A-iii-c + 1B + 1C + 1V (γ-bundle-wide; closes Phase 1 entirely)
**Status**: Stage 3 design cycle — D.3 incorporating critique findings; further critique rounds (external) pending

**Prior stages** (this track):
- Stage 1 research: [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) (commit `de357aa1`) — depth-first formal grounding; 12 sections, ~1000 lines
- Stage 2 audit: this session 2026-04-26 (audit findings persist into this design at §6, §7, §8, §9, §10)
- **Pre-0 phase**: [`docs/tracking/2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md`](2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md) ✅ 100% COMPLETE (M+A+E+R+S-tiers; 22 design-affecting findings; commits `f6576479`, `bef1f518`, `4be5e875`, `d270769b`, `d0934329`, `76129725`, `8a29f6af`)

---

## D.3 Revision Summary (2026-04-26 — in progress)

**Version bump**: D.2 → D.3 incorporates accepted findings from [D.2.SC self-critique](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md) (P/R/M/S; 18 findings; 3 BLOCKING + 10 REFINEMENT + 5 ACKNOWLEDGE + 0 PUSHBACK).

**Per-finding resolution review with user — applied incrementally per ACCEPT (no queue)**:

| Finding | Severity | Decision | D.3 changes |
|---|---|---|---|
| **P3** Cell Staleness Contract | BLOCKING | ACCEPT | NEW §10.B "Cell Staleness Contract" — typed dual-API discipline (`net-fuel-cost-read` vs `net-fuel-cost-read/synced`) |
| **M1** Threshold propagator role under hybrid | BLOCKING | ACCEPT | NEW §10.A "The threshold propagator's role under hybrid" — three load-bearing roles (Phase 3C consumer paths + on-exhaustion + speculation rollback); per-decrement acknowledged as scaffolding pending SH Series |
| **S1** §14.4 SRE lattice lens Q5 PRIMARY/DERIVED inconsistency | BLOCKING | ACCEPT | UPDATE §14.4 Q3+Q4+Q5+Q6 with hybrid-aware classification |
| **P1+P4** Hybrid inverts Cell-as-Single-Source-of-Truth principle (P1) + reframe "decomplection" as "incomplete migration" honestly (P4) | REFINEMENT | ACCEPT (CONSOLIDATED) | NEW §10.1.A "Honest framing & retirement plan" consolidates P1 + P4 into a single tighter section (per user direction "cleaner design document"). Two framings (decomplection + incomplete-migration) both true; principle inversion acknowledged; retirement plan named; four-surface tracking (design-doc + DEFERRED.md + [GitHub Issue #55](https://github.com/LogosLang/prologos/issues/55) + Q-1B-6 + §11.3 gates). |
| **P2** Belt-and-suspenders red flag; empirical-validation gate | REFINEMENT | ACCEPT (with Phase 1B mini-design opening spike) | NEW Q-1B-6 at §9.9 — empirical-validation spike at Phase 1B mini-design opening (cheap; ~30 min; pre-implementation falsification test); §11.3 Phase 1V exit criteria adds final-verification gate (post-implementation). Two-gate discipline: spike challenges hybrid pre-build; Phase 1V verifies post-build. "Learning is valuable either way" per user direction. |
| **P6** "First production landing establishes pattern" risks templating hybrid scaffolding | REFINEMENT | ACCEPT (with MASTER_ROADMAP.org variation) | UPDATE §6.6 PReduce + OE Series rows: hybrid-as-scaffolding-NOT-template caveat; future consumers design TO TARGET full cell-substrate; per-track empirical justification + four-surface tracking discipline if hybrid needed. NEW MASTER_ROADMAP.org § OE Series "Scaffolding caveat" row at the roadmap level (where future-track designers go FIRST when planning new tracks, not buried in D.3). |
| **P5** γ-bundle scope precision (sub-phase count) | ACKNOWLEDGE | ACCEPT | UPDATE §1.2 — add sub-phase count estimate under γ-bundle-wide (~12-15 implementation sub-phases: 1A-iii-b ~5; 1A-iii-c ~8; 1B ~3; 1C ~5 under hybrid; 1V atomic close); name the bundle-vs-sub-phase scope distinction (DESIGN scope vs IMPLEMENTATION scope); also note Phase 1C estimate reframed under D.2 hybrid pivot (~45-90 LoC, was ~250-400 in D.1) per R1 REFINEMENT acceptance forward-pointer. |
| **R1** Phase 1C estimate stale (~45-90 LoC under hybrid; was ~250-400 D.1) | REFINEMENT | ACCEPT | UPDATE §1.2 Phase 1C estimate to ~45-90 LoC with explicit hybrid-vs-D.1 reframing (zero-migration list of preserved sites + actual migration list); §10.1 NEW R1 commentary subsection: small footprint is intentional NOT "easy migration"; future PReduce/OE consumers should not misread small footprint as evidence of easy migration (work was DEFERRED via scaffolding per §10.1.A + Issue #55, not eliminated). |
| **R2** Q-Audit-1 17-refs framing carried forward without rescoping | REFINEMENT | ACCEPT | UPDATE §10.2 — add R2 commentary at audit-grounding location; categorize 17 refs under hybrid (15 PRESERVED + 2-3 SELECTIVELY MIGRATED); name "17 production refs" as REFERENCE for completeness (full architectural scope) vs actual hybrid migration scope ~3-5 sites; future SH Series migration recovers full 17-ref scope per Issue #55 + DEFERRED.md. |
| **R4** Phase 1V microbench list incomplete | REFINEMENT | ACCEPT | EXPAND §11.3 Phase 1V exit criteria microbench list to 11 re-runs: M7+M8+M13 (per-decrement cycle) + M10+M11+M12+R4 (Phase 1B substrate; per §9.10) + A7+A9 (high-frequency decrement + speculation rollback; NEW per R4) + E7+E8 (full-pipeline regression; NEW per R4). Each with concrete target values per Pre-0 baseline Findings (7, 8, 13, 16, 17). Comprehensive falsification discipline per microbench-claim verification rule. |
| (REFINEMENTs + ACKNOWLEDGEs continuing) | various | TBD | Walking through with user; added to this table as accepted |

**3 BLOCKING + 7 REFINEMENTs (P1+P4 consolidated; P2; P6; R1; R2; R4) + 1 ACKNOWLEDGE (P5) accepted.** P-lens complete (6/6); R-lens 3/4 complete.

---

## D.2 Revision Summary (2026-04-26)

**Version bump**: D.1 → D.2 incorporates Pre-0 findings + commits hybrid pivot architecture for Phase 1C.

**What changed from D.1 → D.2**:

| Section | D.1 → D.2 |
|---|---|
| Front matter | Version D.2; Pre-0 phase 100% COMPLETE noted |
| §3 Progress Tracker | Pre-0 ✅ COMPLETE (was ⬜) |
| **§10 Phase 1C (REWRITTEN)** | **Hybrid pivot architecture** — preserve inline `(<= fuel 0)` fast-path at decrement sites; cell + threshold propagator are architectural substrate for Phase 3C consumers, NOT per-decrement live state |
| §10.1 Scope | Reframed: substrate-introduction phase (NOT counter-replacement); existing struct field + macro + decrement/check sites preserved for fast-path |
| §10.3 Per-site migration patterns | DRAMATICALLY reduced scope: hot-path preserved; only non-hot-path read sites + observability paths migrate to cell-mediated APIs |
| §10.4 Sub-phase plan | Reduced from 9 to 5 sub-phases (decrement migration + check migration + macro retirement + field retirement REMOVED) |
| §10.5 Drift risks | Updated to reflect hybrid scope |
| §10.7 Open questions | Added Q-1C-3 (cell-update cadence: lazy vs eager vs semantic-transition-only) |
| §16.5 | Hybrid pivot decision committed (was provisional pending Pre-0) |

**Empirical rationale for hybrid pivot** (8 supporting findings + S-tier baseline):

| Tier | Finding | Direction |
|---|---|---|
| M-2 (origin) | Inline check 6 ns vs propagator fire 100-600 ns | Hybrid pivot proposed |
| M-5 | Counter substrate ~36 ns combined cycle | Tight cost budget |
| A-11 | Linear 12 ns/dec scaling, pattern-blind | Empirical confirmation |
| E-13 | E8 deep-id high-frequency stress (50 levels × 100-600 ns risk) | Hybrid pivot CRITICAL |
| E-15 | Alloc-heaviness baseline regardless of fuel | Phase 1C must NOT compound |
| **R-16** | **ZERO GC during 100k decrements** | **Hybrid pivot STRUCTURAL FIT** |
| **R-17** | Bounded retention 15 bytes/cycle long-term | Phase 1C tagged-cell DR set |
| **R-19** | **Without hybrid, full cell-based path triggers major GC at 100k rate** | **Hybrid is ONLY architecture preserving GC-friendly property** (strongest single piece of evidence) |
| **S-20** | **`prop_firings` + `prop_allocs` ZERO suite-wide pre-impl** | **Architectural baseline: Phase 1C threshold propagator is FIRST production on-network propagator firing in elaboration; clean reference** |

Full 22-finding detail: [Pre-0 plan §12.6](2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md#126-key-pre-0-findings-from-m-tier-execution-2026-04-26).

**Hybrid pivot architectural summary**:
- **Decrement sites**: PRESERVE existing struct-copy + inline `(<= fuel 0)` check (zero migration on per-decrement hot path; ~30-40 ns total cycle preserved)
- **Cell substrate**: canonical fuel-cost-cell + fuel-budget-cell allocated at well-known IDs (cell-id 11/12); SRE registered; threshold propagator installed
- **Cell role**: ARCHITECTURAL substrate for Phase 3C consumers (UC1 fuel-exhaustion blame attribution; UC2 cost-bounded elaboration via Galois bridge; UC3 per-branch cost tracking under union-type ATMS); NOT per-decrement live state
- **Cell-update cadence**: at SEMANTIC TRANSITIONS — start of phase, exhaustion-write, save/restore boundaries via existing snapshot mechanism (NOT per-decrement)
- **On exhaustion**: decrement site's inline check trips → write final cost to fuel-cost-cell → threshold propagator fires (rare event) → writes contradiction → routes through propagator network for architectural correctness

**Why hybrid IS principled (not belt-and-suspenders per workflow.md)**:
- Inline check + cell-write are NOT redundant mechanisms handling the same code path
- Inline check handles the per-decrement HOT PATH (common case; ~30-40 ns)
- Cell + threshold propagator handle Phase 3C consumer paths (rare; semantic-phase-granularity)
- The mechanisms address DIFFERENT code paths with DIFFERENT performance profiles
- This is decomplection: fast-path optimization separated from architectural substrate

**What this enables (Phase 3C consumer-readiness)**:
- UC1 walk algorithm feasibility: 297 ns for N=200 (per A6.3) vs <100 μs DR target = 340× margin
- UC2 cost-bounded elaboration: 117 ms baseline (per E9.1) — pattern feasible under Phase 1B substrate
- UC3 per-branch fork: 11.9 KB/branch (per A10.1) — per-branch cell management empirically grounded
- All three Phase 3C UCs operate on the cell at semantic-phase granularity, not per-decrement

---

**Parent addendum**: [`2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) (D.3) — this addendum **refines and extends** D.3 §7.5.6 (Tier 2 ATMS internal retirement), §7.5.7 (Tier 3 surface ATMS AST retirement), §7.7 (Phase 1B deliverables), §7.8 (Phase 1C deliverables), §7.9 (Phase 1V), §7.10 (termination args), §7.11 (parity-test strategy), §10 (tropical quantale implementation skeleton), §13 (consolidated termination), §16.1 (Phase 1 mini-design items). Per Q-Open-1 (refine + verify, don't re-litigate), D.3 scaffolding is treated as **draft D.0**; D.1 incorporates with refinement, audit-grounding, multi-quantale composition NTT extension, and Phase 3C cross-reference capture.

**Parent track**: [`2026-04-17_PPN_TRACK4C_DESIGN.md`](2026-04-17_PPN_TRACK4C_DESIGN.md) (PPN 4C D.3)

---

## §1 Thesis and scope

### §1.1 Addendum thesis

Per Stage 1 research §1.1: *"Phase 9's tropical fuel cell is the first practical instantiation of a tropical-lattice / quantale / semiring / cost-optimization structure in Prologos production code."* User direction (2026-04-21): *"explore quantales rather than merely semirings."* User direction (2026-04-26): *"this will be the first instantiation of optimization as tropical quantales in our architecture that it deserves the most careful considerations that we can pay it its dues."*

The thesis: **tropical quantales provide the algebraic substrate that Prologos's cost-optimization infrastructure — fuel, PReduce extraction, cost-guided search, OE Series consumers — needs, and the engineering benefits (residuation for provenance, module-theoretic composition, CALM-compatible parallelism) justify the extra formal weight over bare tropical semirings.**

This addendum ships:
1. **Tropical quantale primitive** — substrate-level SRE-registered domain with Quantale + Integral + Residuated property declarations (Phase 1B)
2. **Canonical BSP scheduler instance** — replaces imperative `(fuel 1000000)` decrementing counter with on-network tropical fuel cell (Phase 1C)
3. **Multi-quantale composition NTT model** — formalizes how TypeFacet quantale (SRE 2H, shipped) and TropicalFuel quantale (Phase 1B) co-exist via quantale modules and Galois bridges (§4)
4. **ATMS substrate retirement** — both Tier 2 (deprecated `atms.rkt` internal API) and Tier 3 (surface ATMS AST 14-file pipeline) retirement bundled, closing Phase 1 entirely (Phases 1A-iii-b + 1A-iii-c)
5. **Phase 3C residuation cross-reference capture** — anticipated Phase 3C consumer use cases enumerated (Form B); residuation operator unit-tested in Phase 1B (Form A); Phase 3C proof-of-concept captured as cross-reference in D.3 Phase 3 design (Form C deferred to right phase per capture-gap discipline)

### §1.2 Phase scope (γ-bundle-wide)

**Phase 1A-iii-b — Tier 2 deprecated ATMS internal API retirement** (~250-400 LoC deletion)
- 13 deprecated functions in `atms.rkt:213-251+`: atms-assume, atms-retract, atms-add-nogood, atms-consistent?, atms-with-worldview, atms-amb, atms-read-cell, atms-write-cell, atms-solve-all, atms-explain-hypothesis, atms-explain, atms-minimal-diagnoses, atms-conflict-graph
- `atms` struct + `atms-believed` field + `atms-empty` constructor retirement (per BSP-LE 2B D.1 finding: decision cells are primary, worldview is derived)
- Provides cleanup at `atms.rkt:41-61`
- Internal consumer cleanup: pretty-print.rkt:502 (`atms?`), stratified-eval.rkt:206 (`[(atms) #t]` symbol case)
- Test migrations/deletions: `tests/test-atms.rkt` audit + decide migrate-to-solver-state vs delete

**Phase 1A-iii-c — Tier 3 surface ATMS AST 14-file pipeline retirement** (~600-1000 LoC deletion across 14 files)
- 14 surface AST structs at `syntax.rkt:202-208, 750-767`: expr-atms-type, expr-assumption-id-type, expr-atms-store, expr-atms-new, expr-atms-assume, expr-atms-retract, expr-atms-nogood, expr-atms-amb, expr-atms-solve-all, expr-atms-read, expr-atms-write, expr-atms-consistent, expr-atms-worldview
- `surface-syntax.rkt:925-933` — 10 surf-atms-* structs (per D.3 §7.5.7)
- `parser.rkt:2531-2607` — surface atms parse rules (~80 lines)
- `elaborator.rkt:2438-2466` — surface atms elaboration (~30 lines)
- `reduction.rkt:2842-3635` — surface atms evaluation (~100 lines per D.3 §7.5.7)
- `zonk.rkt:358-1258` — surface atms traversal (~50 lines per D.3 §7.5.7)
- `pretty-print.rkt:506-521` — surface atms pretty-printing
- `pretty-print.rkt:1142-1146` — uses-bvar0?
- `qtt.rkt:1773-1839` — surface atms type rules
- `typing-core.rkt` — surface atms type-check
- Dependency cleanup per D.3 §7.5.7: `typing-errors.rkt`, `substitution.rkt`, `qtt.rkt`, `trait-resolution.rkt`, `capability-inference.rkt`, `union-types.rkt`
- Test deletions: `tests/test-atms.rkt`, `tests/test-atms-integration.rkt`, `tests/test-atms-types.rkt` (full surface AST exercise — coverage replaced by solver-state-driven tests if any gap surfaces)

**Phase 1B — Tropical fuel primitive + SRE registration** (~150-250 LoC new module + tests)
- New module `racket/prologos/tropical-fuel.rkt`: cell factory + budget cell + threshold propagator + residuation operator
- SRE domain registration with full quantale property declarations (Quantale, Integral, Residuated, Commutative)
- Tier 2 linkage: `register-merge-fn!/lattice tropical-fuel-merge #:for-domain 'tropical-fuel`
- Tests `tests/test-tropical-fuel.rkt`: merge semantics, cell allocation, threshold firing, residuation operator, per-consumer independence, cross-consumer cost composition

**Phase 1C — Canonical BSP fuel substrate** (~45-90 LoC under D.2 hybrid pivot; was ~250-400 LoC under D.1 full-migration design — see §10 + D.3 R1 REFINEMENT)

Under D.2 hybrid pivot (per §10), Phase 1C scope dramatically reduces:
- Allocate canonical fuel-cost cell at `cell-id 11` + budget cell at `cell-id 12` in `make-prop-network` + install threshold propagator: ~10-20 LoC NEW
- On-exhaustion cell-write at decrement sites + saved-fuel sync at semantic-transition boundaries (typing-propagators.rkt:2269) + pretty-print.rkt:463 dual display: ~15-30 LoC modified
- Selective read-as-value migration (3 sites; only those at semantic-transition paths) + new Phase 3C UC tests for cell-mediated APIs: ~20-40 LoC modified + new tests

**PRESERVED under hybrid (zero migration; was migration target under D.1):**
- 4 decrement sites (struct-copy + inline check)
- 11 check sites (inline `(<= fuel 0)`)
- `prop-network-fuel` macro (propagator.rkt:399)
- `prop-net-cold-fuel` struct field (propagator.rkt:337)
- 13 test references (most preserve struct-field assertions)
- 2 bench-alloc.rkt references (measure decrement cost; struct-copy preserved)

**D.1's original audit scope (Q-Audit-1 17 production refs)** carried forward as REFERENCE for completeness but actual migration is much smaller per hybrid scope (per D.3 R2 REFINEMENT acceptance; see also §10.2).

**Phase 1V — Vision Alignment Gate Phase 1** (closes 1A + 1B + 1C atomically)
- Adversarial TWO-COLUMN VAG (per `9f7c0b82` codification) on all four sub-phases
- Covers 1A-iii-b + 1A-iii-c + 1B + 1C completion
- Closes Phase 1 entirely

**Total estimate**: ~1250-2050 LoC (mix of deletion and new code; net likely deletion-dominant). **Note: Phase 1C estimate was reframed under D.2 hybrid pivot to ~45-90 LoC (was ~250-400 in D.1) — see §10 + D.3 R1 REFINEMENT acceptance for the rescoped breakdown; the upper-bound total is conservative pre-1B-mini-design refinement.**

**Sub-phase count under γ-bundle-wide** (D.3 from P5 ACKNOWLEDGE): ~12-15 implementation sub-phases (1A-iii-b ~5; 1A-iii-c ~8; 1B ~3; 1C ~5 under hybrid; 1V atomic close). Each sub-phase respects conversational cadence (max ~1h per `workflow.md` "Conversational implementation cadence" rule); the bundle is at the DESIGN scope, sub-phasing is at the IMPLEMENTATION scope. The "γ-bundle-wide" framing names the design-scope coherence (1V closes Phase 1 atomically); it does NOT compress the implementation into a single autonomous stretch.

### §1.3 Out of scope (explicit deferrals)

- **Phase 1E** (`that-*` storage unification per D.3 §7.6.16) — sequenced AFTER this addendum's implementation; conversational Stage 4 mini-design with 5 carry-forward design questions (Q1-Q5)
- **Phase 2** (orchestration unification per D.3 §8) — separate addendum after Phase 1 closes
- **Phase 3A+B+C** (union types via ATMS + hypercube + residuation error explanation per D.3 §9) — separate addendum; Phase 3C is the FIRST DOWNSTREAM CONSUMER of the tropical residuation operator (forward-captured per §6.5)
- **Phase V** (capstone + PIR for Phase 9 Addendum entirely) — after all phases close
- **Multi-quantale composition implementation** — NTT model in scope (§4), full implementation is Phase 3C consumer + future PReduce
- **Quantaloids** (many-object quantales per Stage 1 research §3.6, Stubbe 2013) — out of scope; flagged for future when multi-domain cost currencies (memory, messages, time) co-exist
- **Polynomial Lawvere Logic / Rational Lawvere Logic** (Bacci-Mardare-Panangaden-Plotkin 2023; Dagstuhl CSL 2026) — language-surface form for self-hosting; out of scope per Stage 1 research §11.7
- **General residual solver** (BSP-LE Track 6 forward reference per D.3 §6.11.7) — Phase 1B consumes BSP-LE 2B substrate without coupling to relational layer
- **OE Series formalization** — first production landing happens here; OE Series Master tracking decision deferred to user post-implementation per handoff §5.4

### §1.4 Relationship to D.3 (refine + verify, don't re-litigate)

Per Q-Open-1 decision (2026-04-26): D.3 scaffolding for Phase 1 is treated as draft D.0. This document **refines and extends**:

| D.3 reference | This addendum |
|---|---|
| §7.5.6 (1A-iii-b deliverables) | §7 — refined with audit data; sub-phase plan; drift risks |
| §7.5.7 (1A-iii-c deliverables) | §8 — refined with audit data; 14-file migration ordering; test disposition |
| §7.7 (Phase 1B deliverables) | §9 — refined with API specifics; residuation operator; multi-quantale NTT integration |
| §7.8 (Phase 1C deliverables) | §10 — refined with audit-verified 17 production sites; per-site migration patterns |
| §7.9 (Phase 1V) | §11 — refined with adversarial VAG TWO-COLUMN structure |
| §7.10 (Phase 1 termination args) | §12 — consolidated per-Phase termination |
| §7.11 (Phase 1 parity-test strategy) | §15 — extended with 1A-iii-b/c parity axes |
| §10 (Tropical quantale implementation) | §9.4-§9.7 — refined SRE registration code skeleton, primitive API, canonical instance |
| §13 (Consolidated termination) | §12 — per-phase consolidated |
| §16.1 (Phase 1 mini-design items) | §16 — placed at right phase per user's workflow (per-phase mini-design+audit before each phase's implementation) |

Cross-cutting concerns from D.3 (§3 Progress Tracker, §4 NTT Model with Phase 1B started, §5 Mantra Audit, §6 Architectural decisions Q-A1/Q-A2/Q-A7/Q-A8) remain authoritative; this addendum extends with §4 (multi-quantale composition NTT completion).

D.3's Progress Tracker rows for Phase 1 (1A-iii-b, 1A-iii-c, 1B, 1C, 1V) all point to this document for implementation planning.

---

## §2 Research and audit inputs

### §2.1 Stage 1 research

[`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) (~1000 lines, 12 sections). Key inputs for this design:

- **§2** — Semiring foundations (commutative semirings, dioids, idempotent semirings, tropical semiring as min-plus, Bistarelli-Montanari-Rossi semiring CSP, Kleene algebra, semiring completeness)
- **§3** — Quantale axioms (commutative + unital + integral + residuated; Fujii's equivalence: complete idempotent semiring = quantale)
- **§4** — Lawvere's enriched category framework (V-categories; Lawvere quantale `([0,∞], ≥, 0, +)` IS the tropical quantale; metric spaces ARE V-categories enriched in tropical quantale)
- **§5** — Residuation theory (sup-preserving maps, closure operators, Galois connections, quantale of Galois connections)
- **§6** — Quantale modules (cells as Q-modules; propagators as Q-module morphisms; Tarski fixpoint on Q-modules; CALM parallel)
- **§7** — Idempotent analysis (Litvinov-Maslov tradition; max-plus matrix operations for DES; tropical eigenvalues)
- **§9** — Tropical quantale definition + structure (T_min in `[0, +∞]` Lawvere convention; commutative + unital + integral; clean residuation formula `a \ b = b - a when b ≥ a, else 0`)
- **§10** — Prologos-specific synthesis: tropical fuel cell as min-plus quantale cell; fuel exhaustion as quantale-top; residuation as fuel-cost error-explanation; Galois bridge to TypeFacet
- **§11** — Open Phase 9 design questions (mini-design items)

### §2.2 Stage 2 audit (this session, 2026-04-26)

**Q-Audit-1 — `prop-network-fuel` migration scope**: 17 production refs (propagator.rkt × 17) + 1 typing-propagators + 1 pretty-print + 13 test refs + 2 bench refs. Migration well-bounded. Detail in §10.

**Q-Audit-2 — ATMS retirement surfaces**: 13 deprecated functions in atms.rkt:213-251+; atms struct at line 159+ (with atms-believed field); 14 surface AST structs in syntax.rkt:202-208, 750-767; surface parse rules at parser.rkt:2531-2607; pretty-print + qtt + reduction + zonk + test files. Detail in §7 (Tier 2) and §8 (Tier 3).

**Q-Audit-3 — `tropical-fuel.rkt` clean-slate confirmed**: file does not exist. 5 anticipated consumer scaffolding sites in production: sre-rewrite.rkt:95 (cost field), atms.rkt:856 (TODO comment), parse-lattice.rkt:136+193+200 (cost + priority fields). These are bookmarks for downstream consumers (Phase 3C, Track 6 OE-WeightedParsing, future PReduce). Detail in §9.

### §2.3 Prior art

- **Module Theory on Lattices** ([`2026-03-28_MODULE_THEORY_LATTICES.md`](../research/2026-03-28_MODULE_THEORY_LATTICES.md)) — quantale modules (`Q ⊗ M → M`); residuation as narrowing; cells as Q-modules
- **Tropical Optimization Network Architecture** ([`2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md`](../research/2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md)) — earlier framing with Goodman semiring parsing, ATMS, stratification
- **Algebraic Embeddings on Lattices** ([`2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md`](../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md)) — universal engine vision; quantales for resources; QTT multiplicities as quantale action
- **SRE Track 2H** ([`2026-04-02_SRE_TRACK2H_DESIGN.md`](2026-04-02_SRE_TRACK2H_DESIGN.md)) — TypeFacet quantale (sister quantale; Galois-bridge candidate; first quantale shipped in production)
- **BSP-LE Track 2B** — Module Theory Realization B (tagged-cell-value with bitmask layers on shared carrier); set-latch + broadcast pattern; substrate Phase 1B inherits
- **PPN 4C Phase 3 (shipped)** — `classify-inhabit-value` Module Theory Realization B tag-dispatch on shared carrier; demonstrates the multi-tag composition pattern Phase 1B's NTT model extends

### §2.4 Methodology + rules

- [`DESIGN_METHODOLOGY.org`](principles/DESIGN_METHODOLOGY.org) — Stage 3 cycle: D.1 → Pre-0 → D.2 → D.3+ critique rounds; NTT Model Requirement; Design Mantra Audit; Pre-0 Benchmarks Per Semantic Axis; Parity Test Skeleton; Lens S (Structural) for algebra
- [`CRITIQUE_METHODOLOGY.org`](principles/CRITIQUE_METHODOLOGY.org) — § Cataloguing Instead of Challenging; SRE Lattice Lens mandatory for all lattice design decisions
- [`DESIGN_PRINCIPLES.org`](principles/DESIGN_PRINCIPLES.org) — Hyperlattice Conjecture; Correct-by-Construction; Most Generalizable Interface; First-Class by Default
- [`DEVELOPMENT_LESSONS.org`](principles/DEVELOPMENT_LESSONS.org) — 6 codifications graduated 2026-04-25 from Step 2 arc (Pipeline.md prophylactic, Capture-gap, Partial-state regression unwinds, Audit-first, Audit-driven Wide-vs-Narrow, Sed-deletion 2-pass operational, Microbench-claim verification across sub-phase arcs) — **all apply prophylactically to this design**
- [`.claude/rules/on-network.md`](../../.claude/rules/on-network.md), [`propagator-design.md`](../../.claude/rules/propagator-design.md), [`structural-thinking.md`](../../.claude/rules/structural-thinking.md), [`pipeline.md`](../../.claude/rules/pipeline.md), [`workflow.md`](../../.claude/rules/workflow.md) — architectural rules

---

## §3 Progress Tracker

Per DESIGN_METHODOLOGY Stage 3 "Progress Tracker Placement" discipline.

| Sub-phase | Description | Status | Notes |
|---|---|---|---|
| Stage 1 | Research doc (tropical quantale, ~1000 lines) | ✅ | commit `de357aa1` |
| Stage 2 | Audits (Q-Audit-1/2/3) | ✅ | This session 2026-04-26 |
| Stage 3 D.1 | Design doc draft | ✅ | commit `fc4b9d3e` |
| **Pre-0 plan** | Comprehensive 38-test plan across 8 tiers (M/A/C/X/E/R/S/V) | ✅ | commit `f79650fa` (1172 lines) |
| **Pre-0 M-tier** | M7-M13 micro-benchmarks (5 findings) | ✅ | commit `f6576479` + `bef1f518` |
| **Pre-0 A-tier** | A5-A12 adversarial (6 findings) | ✅ | commit `4be5e875` |
| **Capture-gap closure** | M10/M12/A12/R4 captured at D.1 §9.10 (single source of truth) | ✅ | commit `d270769b` |
| **Pre-0 E-tier** | E7-E9 end-to-end (4 findings) | ✅ | commit `d0934329` |
| **Pre-0 R-tier** | R3+R5 memory-as-PRIMARY (4 findings + R4 capture) | ✅ | commit `76129725` |
| **Pre-0 S-tier** | S1-S4 suite-level via existing tooling (3 findings) | ✅ | commit `8a29f6af` |
| **Stage 3 D.2** | Pre-0 findings incorporated; hybrid pivot committed | ✅ | this commit |
| Stage 3 D.3+ critique rounds | P/R/M/S lenses (especially S for algebra); possibly external critique | ⬜ | NEXT |
| **1A-iii-b** | Tier 2 deprecated ATMS internal API retirement | ⬜ | Per §7 |
| **1A-iii-c** | Tier 3 surface ATMS AST 14-file pipeline retirement | ⬜ | Per §8 |
| **1B** | Tropical fuel primitive + SRE registration | ⬜ | Per §9 |
| **1C** | Canonical BSP fuel migration (HYBRID PIVOT — D.2) | ⬜ | Per §10 |
| **1V** | Vision Alignment Gate Phase 1 (closes 1A + 1B + 1C) | ⬜ | Per §11 |

**Sub-phase ordering** (γ strict sequencing per Q-Open-4):
- 1A-iii-b and 1A-iii-c can land in any order or in parallel (independent of tropical work)
- 1B must complete before 1C (1C consumes 1B's primitive)
- 1V closes everything atomically

**Recommended execution order** (per audit + dependency):
1. **1B** first — substrate ships clean; consumers depend on it
2. **1A-iii-b** + **1A-iii-c** can parallelize with 1C — they're orthogonal to tropical fuel
3. **1C** consumes 1B's primitive
4. **1V** closes everything

Per-phase mini-design+audit happens BEFORE each phase's implementation per user's workflow (Stage 4 Per-Phase Protocol).

---

## §4 NTT Model — multi-quantale composition (extending D.3 §4.1)

Per DESIGN_METHODOLOGY Stage 3 NTT Model Requirement. D.3 §4.1 has Phase 1B's single-quantale NTT model started; this section completes it with multi-quantale composition (per Q-Open-3 (β) decision).

### §4.1 Tropical fuel quantale (Phase 1B delivery, refined from D.3 §4.1)

```ntt
;; Tropical fuel lattice — atomic extended-real (Lawvere convention, T_min variant)
type TropicalFuel := Nat | Infty
  :lattice :value
  :ordering :reverse  ;; smaller cost is "higher" in the lattice (Lawvere convention)

;; Tropical quantale instance: min-plus algebra
;; Per research §9.1 (commutative integral residuated quantale)
;; Per Fujii equivalence (research §3.4): complete idempotent semiring = quantale
trait Lattice TropicalFuel
  spec tropical-join TropicalFuel TropicalFuel -> TropicalFuel
  defn tropical-join [a b] -> (min a b)  ;; ⊕ = min (idempotent)
  spec tropical-bot -> TropicalFuel
  defn tropical-bot -> 0  ;; identity for min (Lawvere top)

trait BoundedLattice TropicalFuel
  :extends [Lattice TropicalFuel]
  spec tropical-top -> TropicalFuel
  defn tropical-top -> Infty  ;; absorbing for min (Lawvere bot — exhausted)

trait Quantale TropicalFuel
  :extends [Lattice TropicalFuel]
  spec tropical-tensor TropicalFuel TropicalFuel -> TropicalFuel
  defn tropical-tensor [a b] -> (+ a b)  ;; ⊗ = +
  spec tropical-unit -> TropicalFuel
  defn tropical-unit -> 0  ;; multiplicative identity (= bot in integral case)

trait Integral TropicalFuel
  :extends [Quantale TropicalFuel]
  ;; Integral: 1 = ⊤ (in Lawvere convention, both are 0)

trait Residuated TropicalFuel
  :extends [Quantale TropicalFuel]
  spec tropical-left-residual TropicalFuel TropicalFuel -> TropicalFuel
  defn tropical-left-residual [a b]
    -> (if (>= b a) (- b a) 0)  ;; b / a = b - a when b >= a, else top (0 in Lawvere)

;; Primitive cell factory (consumer-instantiable)
propagator net-new-tropical-fuel-cell
  :reads  []
  :writes [Cell TropicalFuel :init 0]

;; Canonical budget cell factory
propagator net-new-tropical-budget-cell
  :reads  []
  :writes [Cell TropicalFuel :init Budget]

;; Threshold propagator (factory)
;; NTT extension: :fires-when (predicate) — runtime-condition-gated fire
;; Generalizes existing :fires-once-on-threshold; flagged in D.3 §4.5 as refinement candidate
propagator tropical-fuel-threshold  :extension-note
  :reads  [Cell TropicalFuel (at fuel-cid),
           Cell TropicalFuel (at budget-cid)]
  :writes [Cell Contradiction]
  :component-paths [(cons fuel-cid #f), (cons budget-cid #f)]
  :fires-when (>= fuel-cost budget)
  fire-fn: write-contradiction
```

### §4.2 Multi-quantale composition (NEW — addresses Q-1B-3 + Q-1B-5)

Two quantales co-exist in the network post-Phase-1B:
- **TypeFacet quantale** (SRE 2H, shipped) — Q_T = (TypeExpr, ⊕_T = union-join, ⊗_T = type-tensor, residuals)
- **TropicalFuel quantale** (Phase 1B target) — Q_F = (TropicalFuel, ⊕_F = min, ⊗_F = +, residual)

Per Module Theory research §6.4 (quantale modules) + §6.7 (Tarski fixpoint on Q-modules + CALM parallel):

```ntt
;; Two quantales as separate Sup-monoids
quantale TypeFacetQ :type TypeExpr ...
quantale TropicalFuelQ :type TropicalFuel ...

;; Each cell is a module over (potentially multiple) quantales
;; Type meta universe cell — module over TypeFacetQ
cell type-meta-universe
  :type Cell (hasheq MetaId TaggedCellValue<TypeExpr>)
  :q-module TypeFacetQ
  :action (q ⊗_T m)  ;; quantale action: type-tensor scales type-meta values

;; Tropical fuel cell — module over TropicalFuelQ (1-dimensional case)
cell tropical-fuel-cost
  :type Cell TropicalFuel
  :q-module TropicalFuelQ
  :action (q ⊗_F m)  ;; addition scales accumulated cost

;; CROSS-QUANTALE INTERACTION: Galois bridge (Module Theory §5)
;; Future Phase 3C / OE Track 1: type-cost projection
;; α: TypeFacetQ → TropicalFuelQ — "what's the lower-bound elaboration cost of this type?"
;; γ: TropicalFuelQ → TypeFacetQ — "what types are elaborable within this budget?"
;; The bridge is a Galois connection per Module Theory §5.1-§5.4
;; PHASE 1B SCOPE: declare the bridge interface; implementation deferred to Phase 3C consumer
bridge type-cost-bridge
  :alpha [TypeFacetQ -> TropicalFuelQ]
  :gamma [TropicalFuelQ -> TypeFacetQ]
  :preserves [Galois]
  :forward-capture (Phase 3C residuation error explanation)
```

**Composition pattern** (per research §5.4 — quantale of Galois connections):
- The set of Galois bridges between quantale cells forms a quantale itself under composition
- TypeFacetQ ↔ TropicalFuelQ bridge composes with future bridges (TypeFacetQ ↔ MemoryCostQ, TropicalFuelQ ↔ MessageCountQ, etc.) via quantale operations
- Per research §6.7: monotone Q-module endomorphisms have Tarski fixpoints; CALM theorem applies; multi-quantale composition is coordination-free under monotone joins

**Mantra-aligned**: cells are Q-modules (on-network); quantale actions are propagators (info flow through cells); bridges are Galois-connection propagators (structurally emergent); composition via quantale-of-bridges (all-at-once + parallel).

### §4.3 Architecture — where tropical fuel cells live alongside type universe cells

Per Q-1B-3 cross-cutting concern: physical placement of tropical fuel cells in `make-prop-network`:

```ntt
;; make-prop-network well-known cell-id allocation (extending current Q_T cells)
cell-id 0  :name decomp-request-cell  ;; PAR Track 1
cell-id 1  :name worldview-cache       ;; BSP-LE 2B
cell-id 2-9 :name <reserved-substrate>  ;; (per current state)
cell-id 10 :name classify-inhabit-request-cell  ;; PPN 4C Phase 3
cell-id 11 :name fuel-cost-cell                  ;; NEW Phase 1C — TropicalFuel module
cell-id 12 :name fuel-budget-cell                ;; NEW Phase 1C — TropicalFuel module
;; (future) cell-id 13+ — additional tropical-quantale instances per consumer
```

Per Q-Open-3 (β) decision: TypeFacet universe cells (post-Step-2 Phase 1A) and TropicalFuel cells (Phase 1C) co-exist as **independent Q-modules over different quantales**. They share the same `prop-network` substrate but operate on different lattices. No interference; CALM-safe.

### §4.4 NTT Observations

Per NTT methodology "Observations" subsection requirement (D.3 §4.5 already covered Phase 1B observations; this extends with multi-quantale):

1. **Everything on-network?** Yes. Tropical fuel cells are on-network; multi-quantale composition is via quantale-of-bridges (each bridge is a propagator); no off-network state added.

2. **Architectural impurities revealed?** None at multi-quantale composition level. Per Q-1B-4 (residuation operator implementation), the operator IS a read-time helper (pure function on TropicalFuel × TropicalFuel → TropicalFuel) — not a propagator. Justified by quantale algebraic structure; Phase 3C consumer wraps it in a propagator if needed.

3. **NTT syntax gaps surfaced**:
   - `:q-module Q` — declare cell as Q-module; flagged for NTT design resumption
   - `:action (q ⊗ m)` — quantale action declaration
   - `bridge ... :preserves [Galois]` — Galois connection annotation; aligns with existing bridge syntax
   - `:fires-when (predicate)` — runtime-condition-gated fire (already flagged D.3 §4.5)

4. **Quantaloids (out of scope)** — when multi-domain cost currencies emerge (memory + messages + time), the quantale-of-quantales pattern (Stubbe 2013) becomes load-bearing. Not Phase 1 scope; flagged for future.

---

## §5 Design Mantra Audit (Stage 0 gate)

Per DESIGN_METHODOLOGY Stage 0 Design Mantra Audit. Mantra: *"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."*

| Component | All-at-once | Parallel | Emergent | Info flow | On-network |
|---|---|---|---|---|---|
| Tropical fuel cell primitive (1B) | ✓ per-cell alloc | ✓ consumer-parallel | ✓ from SRE domain | ✓ cell merges | ✓ cell-based |
| Canonical BSP fuel instance (1C) | ✓ pre-alloc in make-prop-network | ✓ threshold propagator + fire-fn | ✓ from fuel/budget comparison | ✓ cost accumulates via merge | ✓ cell-based |
| Multi-quantale composition (§4) | ✓ all bridges installed at registration | ✓ Q-module independence | ✓ from Galois connection structure | ✓ via bridge propagators | ✓ |
| Residuation operator (read-time) | N/A (pure function) | — | ✓ from quantale algebra | ✓ caller threads result through cells | read-time pure function |
| ATMS internal retirement (1A-iii-b) | N/A (deletion) | — | — | — | removes off-network deprecated APIs |
| Surface ATMS AST retirement (1A-iii-c) | N/A (deletion) | — | — | — | removes 14-file pipeline scaffolding |

**Findings**: all components satisfy mantra. The residuation operator is intentionally a read-time pure function (per Q-1B-4 lean); when a propagator needs it, the propagator wraps it — keeping the operator algebraically simple AND consumer-flexible. This is the SAME pattern as `type-tensor-core` (SRE 2H) being a read-time function while `make-pi-fire-fn` wraps it in a propagator.

**Adversarial challenge**: could the residuation operator be MORE on-network? E.g., as a propagator that watches a contradicted fuel cell + writes a derivation chain cell?
- Counter-challenge: Phase 1B's primitive doesn't HAVE a derivation chain cell — that's Phase 3C's anticipated infrastructure (forward-captured per Q-Open-2). Wrapping the operator as a propagator in Phase 1B would prematurely commit to Phase 3C's design. Read-time helper is the right abstraction layer for the primitive.

---

## §6 Architectural decisions (refined from D.3)

Per Q-Open-1 (refine + verify, don't re-litigate). D.3 §6 architectural decisions (Q-A1, Q-A2, Q-A7, Q-A8) remain authoritative; this section refines + adds new decisions surfaced by this addendum.

### §6.1 Q-A1 — Phase partitioning (refined to γ-bundle-wide)

**Original D.3 decision**: 3 phases sequential (1, 2, 3 — substrate / orchestration / features); sub-phases A-Z as needed.

**Refinement (this addendum)**: γ-bundle-wide for Phase 1 (1A-iii-b + 1A-iii-c + 1B + 1C + 1V all in scope). Per Q-Open-1 + Q-Audit-2 findings: ATMS retirement (1A-iii-b/c) is naturally adjacent to substrate work — deprecating the OLD substrate (atms struct + surface AST) alongside shipping the NEW one (tropical primitive). 1V can close all of Phase 1 atomically.

### §6.2 Q-A2 — Tropical fuel cell placement (PRESERVED from D.3)

**D.3 decision**: Option 3 with canonical instance. Substrate-level tropical quantale registered as SRE domain; primitive API for consumer instantiation; canonical BSP scheduler instance allocated in `make-prop-network` using the primitive.

**This addendum verification**: Q-Audit-3 confirms `tropical-fuel.rkt` doesn't exist (clean slate); `make-prop-network` signature confirmed at propagator.rkt:81 (where canonical instance lives per cell-id 11/12 in §4.3). 5 anticipated consumer scaffolding sites in production (sre-rewrite, atms.rkt TODO, parse-lattice × 3) confirm the substrate-level placement is architecturally meaningful.

**No changes**.

### §6.3 Q-A3 — ATMS retirement scope (RESOLVED — γ-bundle-wide)

**D.3 §16.1 deferred to mini-design**: "how much of ATMS retirement (deprecated atms struct, atms-believed field per BSP-LE 2B D.1 finding, surface AST migration) is in Phase 1 vs deferred?"

**This addendum decision (per Q-Open-1 user direction γ-bundle-wide)**: ALL of ATMS retirement in Phase 1.
- 1A-iii-b: Tier 2 internal API + struct + atms-believed
- 1A-iii-c: Tier 3 surface AST 14-file pipeline + tests
- Both bundled per γ-bundle-wide decision

### §6.4 Q-A5 — atms-believed retirement timing (RESOLVED)

**D.3 §16.1 deferred to mini-design**: "atms-believed retirement timing (architecturally coupled to Q-A3)"

**This addendum decision**: atms-believed retires WITH the atms struct in Phase 1A-iii-b. Per BSP-LE Track 2 D.1 finding (decision cells are primary, worldview is derived as union of committed assumption bits), the atms-believed field was vestigial — the field tracking which assumptions are believed is structurally derivable and was a parallel source of truth. Retirement is structurally clean.

### §6.5 Q-A2-extension (NEW) — Phase 3C residuation cross-reference capture

**Per Q-Open-2 (A+B+cross-reference capture)**:

- **Form A** (Phase 1B unit test): tests/test-tropical-fuel.rkt includes test cases for the residuation operator. Cases:
  - `(tropical-left-residual 0 0) = 0` (identity)
  - `(tropical-left-residual 5 10) = 5` (b - a when b >= a)
  - `(tropical-left-residual 10 5) = 0` (top — overspend)
  - `(tropical-left-residual a infty) = (- infty a)` (= infty for finite a)
  - `(tropical-left-residual infty b) = 0` (vacuous)
- **Form B** (Phase 1B design enumerates Phase 3C anticipated use cases):
  - **UC1**: Fuel exhaustion → reverse-walk propagator dependency graph from contradicted cell → sum per-step costs → identify which propagators consumed the budget → blame attribution. Per research §10.3.
  - **UC2**: Cost-bounded elaboration — given a budget, compute "what types are elaborable within budget" via γ direction of type-cost-bridge (§4.2). Per research §10.4.
  - **UC3**: Per-branch cost tracking in union-type ATMS branching (Phase 3A) — per-branch tropical fuel cell allocated; threshold per branch; residuation walks per-branch dependency chain on contradiction.
- **Form C** (Phase 3C cross-reference capture): D.3 Phase 3 design (§9.5 "Phase 3C deliverables" in current D.3) gets a NEW subsection with cross-reference back to this addendum's §6.5 + §9.7 (residuation operator + UC enumeration). This is the capture mechanism — when Phase 3C design opens, the implementer picks up the cross-reference and runs the proof of concept for UC1/UC2/UC3.

This is the capture-gap pattern's correct application: capture lives at the right phase (3C), not in current phase (1B); cross-reference makes it discoverable; design-time enumeration ensures it's load-bearing.

### §6.6 Cross-cutting concerns matrix (refined)

| Parent Track Phase | This addendum interaction | Notes |
|---|---|---|
| Step 2 ✅ CLOSED | Tropical fuel cells co-exist with type meta universe cells per §4.3 | No interference; different quantales |
| **Phase 1A-iii-b + 1A-iii-c (this addendum)** | ATMS substrate retirement bundled | Tier 2 + Tier 3 both in scope per γ-bundle-wide |
| **Phase 1B + 1C + 1V (this addendum)** | Tropical fuel substrate ships | First optimization-quantale instantiation |
| Phase 1E | AFTER this addendum implementation lands | 5 carry-forward Q1-Q5 per D.3 §7.6.16; conversational Stage 4 |
| Phase 2 (orchestration) | Independent of this addendum | Likely after Phase 1E |
| Phase 3A/B/C | Phase 3C consumes tropical residuation operator | Forward-captured per §6.5 |
| Phase 4 (CHAMP retirement, parent track) | Coordinates with PM Track 12 on cache fields | Orthogonal mostly |
| Track 4D | Per-command transient consolidation | Forward-captured in DEFERRED.md from Step 2 |
| **Future PReduce series** | Inherits tropical quantale primitive for cost-guided rewriting / e-graph extraction | **First production landing establishes pattern. Hybrid-as-scaffolding caveat (D.3 from P6 REFINEMENT)**: under D.3 hybrid pivot, the pattern being established is SCAFFOLDING (cell substrate co-exists with off-network fast-path until SH Series runtime supports full migration per [Issue #55](https://github.com/LogosLang/prologos/issues/55)), NOT the architectural target. **Future PReduce consumers should DESIGN TO TARGET full cell-substrate migration** (per D.1's original framing) and only fall back to hybrid pattern IF measurement shows runtime constraints (with their own R-19-equivalent empirical justification + Issue tracking + DEFERRED.md entry per the four-surface tracking discipline at §10.1.A). The hybrid is a SCAFFOLDING pattern, NOT a template. |
| **OE Series** | This addendum is OE Track 0/1/2's first production landing | Per MASTER_ROADMAP.org § OE; formalization decision deferred. **Same hybrid-as-scaffolding caveat as PReduce row above (D.3 from P6 REFINEMENT)**: future OE consumers (cost-bounded weighted parsing, multi-cost-currency tracking, future cost-guided search) target full cell-substrate per D.1 design intent; hybrid scaffolding pattern requires per-track empirical justification (their own R-19-equivalent baseline) + retirement plan with specific blocker named + four-surface tracking. Without this discipline, hybrid scaffolding propagates as the implicit architectural default across the codebase, perpetuating the Cell-as-Single-Source-of-Truth principle inversion (per §10.1.A). |
| **Future Self-Hosting** | Polynomial Lawvere Logic is the language-surface form | Out of scope per §1.3 |

---

## §7 Phase 1A-iii-b — Tier 2 deprecated ATMS internal API retirement

### §7.1 Scope and rationale

Retire the deprecated `atms.rkt` internal API (13 functions + struct + atms-believed field). Modern API (`solver-context`/`solver-state` from BSP-LE 2) coexists; this phase removes the deprecated parallel surface.

### §7.2 Audit-grounded scope (Q-Audit-2 findings)

**Functions to retire** (atms.rkt:213-251+, all exported at lines 41-61):
1. `atms-assume` (line 213)
2. `atms-retract` (line 225)
3. `atms-add-nogood` (line 235)
4. `atms-consistent?` (line 241)
5. `atms-with-worldview` (line 251)
6. `atms-amb`
7. `atms-read-cell`
8. `atms-write-cell`
9. `atms-solve-all`
10. `atms-explain-hypothesis`
11. `atms-explain`
12. `atms-minimal-diagnoses`
13. `atms-conflict-graph`
14. `atms-amb-groups` (accessor)

**Struct to retire**:
- `atms` struct (line 159+) with fields including `atms-believed`
- `atms-empty` constructor
- `atms?` predicate (referenced at pretty-print.rkt:502, stratified-eval.rkt:206)

**Internal consumer cleanup**:
- `pretty-print.rkt:502`: replace `(if (atms? v) (hash-count (atms-assumptions v)) 0)` with solver-state-based equivalent OR remove if dead
- `stratified-eval.rkt:206`: `[(atms) #t]` symbol case — verify no longer reachable post-Tier-2 retirement; remove or migrate

**Tests**:
- `tests/test-atms.rkt` — pre-migration audit: which tests verify deprecated APIs vs modern solver-state? Decision: migrate tests to use `solver-state` API where coverage gap exists; delete tests that verify only-deprecated behavior

### §7.3 Sub-phase plan

- **1A-iii-b-i** — Pre-implementation audit (mini-audit): grep all production callers of each deprecated function; classify migration target (solver-state equivalent or delete); enumerate test cases per category
- **1A-iii-b-ii** — Function retirement (atomic commit): retire 13 functions + struct + atms-empty; remove from provide block (atms.rkt:41-61)
- **1A-iii-b-iii** — Internal consumer cleanup: pretty-print.rkt + stratified-eval.rkt
- **1A-iii-b-iv** — Test migration/deletion: per audit findings
- **1A-iii-b-v** — Verification + close: probe + targeted suite + full suite + parity test

### §7.4 Drift risks (per phase mini-design + audit before implementation)

Risks named at design time; verified at implementation:
- **D-b-1**: Deprecated function may have hidden callers not caught by grep (e.g., dynamically-resolved via `eval` or callback)
- **D-b-2**: Test deletion vs migration decision — verify modern solver-state API has equivalent coverage
- **D-b-3**: pretty-print.rkt `atms?` removal may surface dead code paths
- **D-b-4**: stratified-eval.rkt symbol case may have semantic significance (e.g., type predicate) — audit before removal

### §7.5 Termination + parity

- Termination: pure deletion phase; no new propagators; no recursive structure changes. Trivially terminates.
- Parity: tropical-fuel-parity axis doesn't apply here. Per D.3 §7.11, this phase contributes "ATMS-deprecated-API parity" axis — pre-retirement vs post-retirement: behavior identical for non-ATMS-deprecated callers; deprecated callers either migrated or removed.

### §7.6 Open questions (deferred to per-phase mini-design+audit per user's workflow)

- Q-1A-iii-b-1: Test migration vs deletion criteria — needs audit of test coverage gap
- Q-1A-iii-b-2: pretty-print.rkt `atms?` removal — does this surface dead code or active state we should preserve via solver-state?

---

## §8 Phase 1A-iii-c — Tier 3 surface ATMS AST 14-file pipeline retirement

### §8.1 Scope and rationale

Retire the surface ATMS AST 14-file pipeline. The user-facing surface ATMS expressions (e.g., `(atms-new (net-new 1000))`, `(atms-assume atms :h0 true)`) are scaffolding from a pre-solver-state era. Modern solver-state-driven approach replaces; surface AST retirement removes the 14-file maintenance burden per the AST node pipeline checklist (`.claude/rules/pipeline.md`).

### §8.2 Audit-grounded scope (Q-Audit-2 findings)

**Per `.claude/rules/pipeline.md` "New AST Node" checklist applied IN REVERSE** (retirement):

**Core pipeline (always touched)**:
1. `syntax.rkt:202-208` — 14 surface AST struct exports
2. `syntax.rkt:750-767` — 14 struct definitions
3. `substitution.rkt` — verify shift/subst cases for atms-* (likely exists; remove)
4. `zonk.rkt:358-1258` — surface atms traversal (~50 lines per D.3 §7.5.7)
5. `reduction.rkt:2842-3635` — surface atms evaluation (~100 lines)
6. `pretty-print.rkt:506-521` — surface atms display
7. `pretty-print.rkt:1142-1146` — uses-bvar0?
8. `pnet-serialize.rkt` — verify reg0!/reg1!/regN! for auto-cache (likely retire)
9. `typing-core.rkt` — surface atms type-check
10. `qtt.rkt:1773-1839` — surface atms type rules

**User-facing surface syntax**:
11. `surface-syntax.rkt:925-933` — 10 surf-atms-* structs (per D.3 §7.5.7)
12. `parser.rkt:2531-2607` — surface atms parse rules (~80 lines)
13. `elaborator.rkt:2438-2466` — surface atms elaboration

**Dependency cleanup** (per D.3 §7.5.7):
- `typing-errors.rkt`, `substitution.rkt`, `qtt.rkt`, `trait-resolution.rkt`, `capability-inference.rkt`, `union-types.rkt` — grep + remove references

**Tests**:
- `tests/test-atms.rkt` — DELETE (full surface AST exercise)
- `tests/test-atms-integration.rkt` — DELETE (~100 test cases per audit observation)
- `tests/test-atms-types.rkt` — DELETE

**Trace/serialize**:
- `trace-serialize.rkt:75-89` — atms-event:* references (these are EVENT types, not the atms struct; verify if they reference deprecated state — they may stay if event types remain valid)

### §8.3 Sub-phase plan (14-file pipeline retirement ordering)

Per pipeline.md retirement protocol (REVERSE of "New AST Node"):

- **1A-iii-c-i** — Pre-implementation audit (mini-audit): grep every file in pipeline.md checklist; verify all 14 structs are in scope; identify any external callers in lib/ or examples/; classify trace-serialize references
- **1A-iii-c-ii** — Surface forms retirement (parse + elaboration): parser.rkt + elaborator.rkt + surface-syntax.rkt — surface forms can no longer be parsed
- **1A-iii-c-iii** — Pipeline core retirement (substitution + zonk + reduction + pretty-print): cores can no longer process them
- **1A-iii-c-iv** — Type rules retirement (typing-core + qtt): type-checker can no longer type them
- **1A-iii-c-v** — Struct definition retirement (syntax.rkt): structs no longer exist
- **1A-iii-c-vi** — Test deletion (3 test files; ~100+ test cases)
- **1A-iii-c-vii** — Dependency cleanup (typing-errors + substitution + qtt + trait-resolution + capability-inference + union-types) + trace-serialize verification
- **1A-iii-c-viii** — Verification + close: probe + targeted suite + full suite + parity test

### §8.4 Drift risks

- **D-c-1**: Hidden parser callers (e.g., macro expansion of atms-* forms)
- **D-c-2**: Library files (lib/) referencing surface ATMS forms — would surface as elaboration errors post-retirement
- **D-c-3**: `examples/` files using surface ATMS — verify and migrate to solver-state-based approach OR delete examples
- **D-c-4**: trace-serialize atms-event:* references — these might be event types valid for solver-state too; audit before retiring
- **D-c-5**: Test deletion may surface unrelated test isolation issues — verify with shared-fixture pattern

### §8.5 Termination + parity

- Termination: deletion phase; trivially terminates
- Parity: "surface-ATMS-AST-elaboration parity" — pre-retirement: surface forms parse + elaborate + type-check + reduce; post-retirement: surface forms parse error (correct behavior — forms no longer exist)

### §8.6 Open questions (deferred to per-phase mini-design+audit)

- Q-1A-iii-c-1: trace-serialize.rkt atms-event:* — retire with surface AST or preserve for solver-state events?
- Q-1A-iii-c-2: examples/ files using surface ATMS — migrate to solver-state OR delete entirely?
- Q-1A-iii-c-3: lib/ files using surface ATMS — extent of migration impact

---

## §9 Phase 1B — Tropical fuel primitive + SRE registration

### §9.1 Scope and rationale

Ship the foundational tropical fuel primitive: a new `tropical-fuel.rkt` module + SRE domain registration + tests. This is the substrate that Phase 1C (canonical BSP migration), Phase 3C (residuation error explanation, future), and OE Series consumers (future PReduce, weighted parsing per parse-lattice.rkt scaffolding) build on.

### §9.2 Architecture (refined from D.3 §7.7 + §10)

**Module**: `racket/prologos/tropical-fuel.rkt` (NEW; clean slate per Q-Audit-3)

**Imports** (per Phase 1B's foundational positioning):
- `sre-core.rkt` (for `make-sre-domain` + `register-domain!`)
- `merge-fn-registry.rkt` (for `register-merge-fn!/lattice`)
- `propagator.rkt` (for `net-new-cell` + `net-add-propagator` + `net-cell-read`/`write` + `net-contradiction`)
- No higher-level dependencies (primitive is foundational)

**Provides**:
```racket
(provide
  ;; Lattice constants
  tropical-fuel-bot           ;; = 0
  tropical-fuel-top           ;; = +inf.0
  tropical-fuel-merge         ;; = min
  tropical-fuel-contradiction?  ;; = (= +inf.0)
  tropical-fuel-tensor        ;; = +
  tropical-left-residual      ;; (a b) -> (if (>= b a) (- b a) 0)
  ;; Cell factories
  net-new-tropical-fuel-cell   ;; net -> (values net cell-id)
  net-new-tropical-budget-cell ;; net budget -> (values net cell-id)
  ;; Propagator factory
  make-tropical-fuel-threshold-propagator  ;; fuel-cid budget-cid -> propagator
  ;; SRE domain (referenced by registrations)
  tropical-fuel-sre-domain)
```

### §9.3 Algebraic foundations (refined from research §9-§10)

**Tropical quantale `T_min = ([0, +∞], ≤_rev, +, 0)`** in Lawvere convention:
- Carrier: non-negative extended reals `[0, +∞]`
- Order: `a ≤_rev b ⟺ a ≥ b` (smaller cost is "higher" — Lawvere)
- Join (⊕): `min` (idempotent — cost-minimization)
- Meet (⋀): `max`
- Tensor (⊗): `+` (cost composition)
- Unit (1 = ⊤_rev): `0` (zero-cost operation)
- Bot (⊥_rev): `+∞` (infinite cost — exhausted)

**Quantale axioms verified** (per research §9.2):
- ✅ Complete lattice
- ✅ Commutative + Unital + Integral monoid
- ✅ Distributivity over arbitrary joins/meets
- ✅ Residuation: `a \ b = b - a when b ≥ a, else 0` (research §9.3)

### §9.4 SRE domain registration (refined from D.3 §10.1)

```racket
(define tropical-fuel-sre-domain
  (make-sre-domain
    #:name 'tropical-fuel
    #:merge-registry tropical-fuel-merge-registry
    #:contradicts? (λ (v) (= v +inf.0))
    #:bot? (λ (v) (= v 0))
    #:bot-value 0
    #:top-value +inf.0
    #:classification 'value      ;; atomic extended-real
    #:declared-properties
      (hasheq 'equality
              (hasheq 'commutative-join     prop-confirmed
                      'associative-join     prop-confirmed
                      'idempotent-join      prop-confirmed
                      'has-meet             prop-confirmed
                      'distributive         prop-confirmed
                      ;; QUANTALE properties
                      'quantale             prop-confirmed
                      'commutative-quantale prop-confirmed
                      'unital-quantale      prop-confirmed
                      'integral-quantale    prop-confirmed
                      'residuated           prop-confirmed
                      'has-pseudo-complement prop-confirmed))
    #:operations
      (hasheq 'tensor   (hasheq 'fn tropical-fuel-tensor
                                'properties '(distributes-over-join
                                              associative
                                              has-identity
                                              commutative))
              'residual (hasheq 'fn tropical-left-residual
                                'properties '(adjoint-to-tensor)))))

(register-domain! tropical-fuel-sre-domain)
(register-merge-fn!/lattice tropical-fuel-merge #:for-domain 'tropical-fuel)
```

**Property inference** (per Phase 2 of PPN 4C tradition): runs explicitly at registration to verify quantale laws (commutativity, associativity, idempotence, distributivity, residuation laws). Per Track 3 §12 + SRE 2G precedent, expect ≥1 lattice-law verification finding (possibly 0 since quantale axioms are well-grounded).

### §9.5 Primitive API (refined from D.3 §10.2)

```racket
;; Allocate a fuel cost cell (initial 0; merge min)
(define (net-new-tropical-fuel-cell net)
  (net-new-cell net 0 tropical-fuel-merge #:domain 'tropical-fuel))

;; Allocate a budget cell (initial budget; merge = first-write-wins via custom)
;; Budget cells are write-once-then-read; merge prefers existing value
(define (net-new-tropical-budget-cell net budget)
  (net-new-cell net budget budget-merge-first-wins))

;; Threshold propagator factory
(define (make-tropical-fuel-threshold-propagator fuel-cid budget-cid)
  (λ (net)
    (define cost (net-cell-read net fuel-cid))
    (define budget (net-cell-read net budget-cid))
    (if (>= cost budget)
        (net-contradiction net 'tropical-fuel-exhausted)
        net)))

;; Residuation operator (read-time pure function — Q-1B-4 lean)
(define (tropical-left-residual a b)
  (if (>= b a) (- b a) 0))  ;; b - a when b >= a, else top (0 in Lawvere)
```

### §9.6 Tests (refined from D.3 §7.7)

`tests/test-tropical-fuel.rkt` (NEW):

**Merge semantics** (5+ tests):
- `(tropical-fuel-merge 0 0) = 0` (bot identity)
- `(tropical-fuel-merge +inf.0 0) = 0` (top absorbing for ≤_rev)
- `(tropical-fuel-merge 5 3) = 3` (min)
- `(tropical-fuel-merge 5 +inf.0) = 5`
- `(tropical-fuel-contradiction? +inf.0) = #t`

**Cell allocation** (3+ tests):
- `net-new-tropical-fuel-cell` produces cell with initial value 0
- `net-new-tropical-budget-cell` with budget 1000 produces cell with initial 1000
- Multiple consumers: each gets independent cell

**Threshold propagator firing** (3+ tests):
- Cost < budget: net unchanged
- Cost = budget: contradiction fires
- Cost > budget: contradiction fires
- Per-consumer independence: two threshold propagators on different cells don't cross-contaminate

**Tensor operation** (3+ tests):
- `(tropical-fuel-tensor 3 5) = 8` (cost composition)
- `(tropical-fuel-tensor 0 5) = 5` (identity)
- `(tropical-fuel-tensor +inf.0 5) = +inf.0` (absorbing)

**Residuation operator (Form A per §6.5)** (5+ tests):
- `(tropical-left-residual 0 0) = 0` (identity)
- `(tropical-left-residual 5 10) = 5` (b - a when b >= a)
- `(tropical-left-residual 10 5) = 0` (overspend → top)
- `(tropical-left-residual 5 +inf.0) = +inf.0` (infinite remaining)
- Algebra: `(tropical-fuel-tensor a (tropical-left-residual a b)) <=_rev b` (adjunction law verification)

**SRE domain registration** (2+ tests):
- `(lookup-domain 'tropical-fuel)` returns the registered domain
- Property inference confirms declared properties (quantale, residuated, etc.)

### §9.7 Phase 3C anticipated use cases (Form B per §6.5)

Enumerated for forward-capture; cross-referenced in Phase 9 Addendum design Phase 3 section:

**UC1 — Fuel exhaustion blame attribution** (per research §10.3):
When tropical fuel cell reaches `+∞` (contradiction), Phase 3C deploys a propagator that:
1. Watches the contradicted fuel cell
2. Walks the propagator dependency graph backward from the cell
3. Sums per-step costs along the chain (using `tropical-left-residual`)
4. Identifies which propagators consumed budget → blame attribution
5. Emits derivation chain (per D.3 Phase 11b srcloc infrastructure)

**UC2 — Cost-bounded elaboration via Galois bridge** (per research §10.4):
Future Phase 3C consumer + future OE Series Track 1:
1. Allocate tropical fuel cell per type cell
2. α: type → cost mapping via type-cost-bridge (§4.2)
3. γ: budget → "elaborable types within budget" via reverse direction
4. `tropical-left-residual` computes "remaining budget after current cost"

**UC3 — Per-branch cost tracking in union-type ATMS** (per D.3 §6.10 + Phase 3A):
1. Per-branch tropical fuel cell allocated per union component
2. Threshold propagator per branch
3. Branch-local residuation walks per-branch dependency chain on contradiction
4. Aggregate cost reporting via tropical-fuel-tensor across branches

These three use cases ground the Form B anticipated-use enumeration. Phase 3C's design picks up the cross-reference and implements UC1/UC2/UC3 as proof-of-concept (Form C deferred to right phase).

### §9.8 Drift risks

- **D-1B-1**: Quantale property declarations may not all be load-bearing — verify via Phase 3C anticipated use cases (forward-capture per §9.7)
- **D-1B-2**: Residuation operator as read-time function may need to be wrapped in propagator by some consumer — leave operator as pure function; consumers wrap if needed (per Q-1B-4 lean)
- **D-1B-3**: `+inf.0` Racket float-infinity vs sentinel symbol (Q-1B-2) — see §9.9
- **D-1B-4**: API naming (Q-1B-1) — see §9.9
- **D-1B-5**: Multi-quantale composition NTT (§4) is design-only in this addendum; implementation deferred to Phase 3C consumer + future PReduce

### §9.9 Open questions (deferred to per-phase mini-design+audit per user's workflow)

- **Q-1B-1**: API naming. Lean: `tropical-fuel-merge`, `tropical-fuel-tensor`, `tropical-left-residual`. Alternative: `min-merge`, `quantale-join`, etc. Decide at 1B mini-design with code in hand.
- **Q-1B-2**: `+inf.0` (Racket float-infinity) vs sentinel `'tropical-top`. Lean: `+inf.0` — Racket-native; arithmetic well-defined (`+inf.0 + a = +inf.0`); easier interop. Alternative: sentinel for type clarity; might be more SRE-aligned. Decide at 1B mini-design.
- **Q-1B-4**: Residuation operator as read-time helper vs propagator. Lean: read-time helper (per §9.5 + §6.5). Decide at 1B mini-design with Phase 3C UC1/UC2/UC3 anticipated use cases in hand.
- **Q-1B-6 (NEW from D.2.SC P2 REFINEMENT)**: Hybrid pivot empirical-validation spike at Phase 1B mini-design opening (BEFORE substrate ships). The hybrid pivot's defense (§10 acknowledgment + Issue #55 + DEFERRED.md) extrapolates from Pre-0 R-19 (struct-copy GC-friendly) to "full cell-migration would NOT be GC-friendly." The extrapolation is reasonable but UNTESTED — Pre-0 measured struct-copy at the inline-check rate; it didn't directly compare cell-write at the inline-check rate (substrate didn't exist pre-Phase-1B).
  - **Spike (cheap; ~30 min at Phase 1B mini-design opening)**:
    - Implement minimal cell + threshold propagator scaffold (or use existing infra-cell test fixture)
    - Measure bare cell-write at inline-check rate (single quick test mirroring M7+M8 + R3-style sustained 100k-rate GC profile)
    - Compare: cell-write cost vs struct-copy cost (target: ≤ 50% overhead); R3-style GC behavior under sustained cell-write at 100k+ ops/sec (target: zero major-GC, matching struct-copy baseline)
  - **If spike PASSES (cell-write fast + GC-friendly)**:
    - **Escalate to user**: "the hybrid pivot's empirical motivation does NOT hold under Phase 1B reality; reconsider Phase 1C scope BEFORE Phase 1B ships substrate?" Discussion: do we ship Phase 1B substrate AND retire the hybrid (Phase 1C reverts to D.1 full-migration design)? Or ship Phase 1B substrate + Phase 1C hybrid as designed + Phase 4 (post-addendum) full-migration retirement?
    - **The learning is valuable either way**: even if we proceed with hybrid for scheduling reasons, the spike confirms Phase 1B substrate's cell-write characteristics for Phase 3C consumer design AND informs SH Series planning (Issue #55 retirement criteria)
  - **If spike FAILS (cell-write slow OR GC-pressured)**:
    - Confirms hybrid pivot's empirical motivation; proceed with §10 design as committed
    - Document the spike result as Pre-0 §12.6 Finding 23 (extending the 22-finding catalog); strengthens hybrid pivot's empirical grounding
  - **Cross-references**: §11.3 Phase 1V exit criteria includes a final-verification gate (post-implementation check at Phase 1V close); Q-1B-6 is the PRE-implementation spike (cheap, early signal). Both gates serve different purposes — Q-1B-6 challenges the hybrid pre-build; §11.3 verifies the hybrid's claims post-build.

### §9.10 Post-Phase-1B benchmark capture — forward-pointer for Pre-0 deferred items (NEW 2026-04-26)

Per **capture-gap discipline** (DEVELOPMENT_LESSONS.org, codified 2026-04-25; "every 'future phase X handles Y' claim requires capture verification or explicit capture creation at the time of the claim"). Pre-0 plan §3-§4 has 3 items labeled "N/A pre-impl, deferred to post-Phase-1B" — captured here at the right phase so the work isn't dropped when Phase 1B implementation opens.

Phase 1B's deliverables include `bench-tropical-fuel.rkt` (NEW; per Pre-0 plan §11.1 file table) which is the home for these post-impl benchmarks. The Form A unit tests (§9.6) cover **correctness** of the residuation operator + tensor + boundary cases; the deferred Pre-0 micros below cover **performance characterization**.

**M10 — Residuation operator (read-time pure function) cost**:
- Per Pre-0 plan §3 M10: pure function call cost on `(tropical-left-residual a b)` for various (a, b) value combinations
- Implementation site: `bench-tropical-fuel.rkt` micro section
- HYP: ~10-30 ns/call for fixnum cases; ~50-100 ns/call for `+inf.0` cases (per Pre-0 plan §3 M10 hypothesis)
- DR: if wall > 100 ns → optimize residuation operator (open-coded comparison)
- Boundary cases (per Pre-0 plan §3 M10): simple `(tropical-left-residual 5 10)`, boundary `(tropical-left-residual 0 0)`, infinite cases, pathological extreme values
- Decision input for Q-1B-4: read-time helper has near-zero overhead → consumers wrap in propagator only when needed

**M12 — SRE domain registration overhead**:
- Per Pre-0 plan §3 M12: one-time module-load cost for `register-domain! tropical-fuel-sre-domain`
- Implementation site: `bench-tropical-fuel.rkt` micro section
- HYP: < 1 ms (one-time at module load); < 10 KB per domain (struct + property declarations + merge-fn entries)
- DR: if significantly higher → investigate property inference triggering at registration vs lazy
- Sub-tests: one-time registration cost; idempotency check (repeat registration is no-op vs re-runs property inference)

**A12 — Edge-case algebra (residuation at boundaries)**:
- Per Pre-0 plan §4 A12: assertion-based correctness for 6 boundary cases + algebraic adjunction law
- Implementation site: `tests/test-tropical-fuel.rkt` (covered by Form A unit tests per §9.6 above)
- The 6 cases (a=b, a=0, b=+inf, a=+inf, a>b overspend, both 0 identity) are the boundary semantics for `(tropical-left-residual a b)`
- Cross-reference: A12 boundary cases are **the same cases** as §9.6 Form A unit tests — A12 was named in Pre-0 plan as adversarial-tier coverage but is realized via Form A unit tests
- Methodology: assertion-based correctness (rackunit `check-equal?`); wall-clock secondary (timing covered by M10)
- DR: if any boundary case produces wrong result → bug in `tropical-left-residual` implementation OR reconsider `+inf.0` representation choice (Q-1B-2)

**R4 — Memory cost of compound cell value vs flat tagged-cell-value**:
- Per Pre-0 plan §8 R4: cell value layout impact on memory
- Implementation site: `bench-tropical-fuel.rkt` micro section (R-series companion to M9 cell allocation cost)
- Tropical fuel cell IS atomic value (`'value` classification per D.1 §9.4 SRE registration); should NOT need compound layout
- HYP: per-cell base ~150-300 bytes; per-additional-worldview-tag ~50-100 bytes
- DR: if base > 1 KB → investigate cell layout; if per-worldview marginal > 200 bytes → investigate tag-entry overhead
- Sub-tests:
  - Atomic tropical fuel cell allocation (control)
  - Compare to hypothetical flat tagged-cell-value with single worldview tag
  - Compare to hypothetical compound cell with multiple worldview tags (when speculation creates branches)
- Validates D.1 §9.4 `'value` classification choice — if compound layout has comparable cost to atomic, validates the architectural decision; if compound is significantly heavier, validates keeping atomic for tropical fuel

**Phase 1B implementation checklist** (capture-gap closure):
- [ ] M10 added to `bench-tropical-fuel.rkt` (residuation operator timing measurement)
- [ ] M12 added to `bench-tropical-fuel.rkt` (SRE registration cost measurement)
- [ ] R4 added to `bench-tropical-fuel.rkt` (compound vs flat cell value layout measurement)
- [ ] A12 boundary cases verified in `tests/test-tropical-fuel.rkt` (per §9.6 Form A enumeration)
- [ ] Cross-reference verification: §9.6 Form A test list matches Pre-0 plan §4 A12 boundary cases enumeration
- [ ] Update Pre-0 plan §12.5 M10/M12/R4/A12 rows with measured baseline data post-Phase-1B
- [ ] Document any findings in Pre-0 plan §12.6 from M10/M12/R4/A12 measurements

**Why this capture is critical**: without explicit cross-reference back to D.1 §9, the Phase 1B implementer might:
- Look at D.1 §9.6 → see Form A unit tests → implement them in `test-tropical-fuel.rkt`
- Look at Pre-0 plan §4 A12 → see "deferred post-Phase-1B" → potentially DUPLICATE in `bench-tropical-fuel.rkt` thinking they're separate
- OR miss M10 / M12 entirely (no Form A counterpart in §9.6)

This subsection is the SINGLE SOURCE OF TRUTH for "what post-Phase-1B benchmarks are owed" — the implementer reads this checklist + §9.6 + Pre-0 plan §11.1 together. The capture lives at Phase 1B (the right phase per capture-gap discipline) with explicit cross-references back to Pre-0 plan items.

---

## §10 Phase 1C — Canonical BSP fuel substrate (hybrid pivot architecture)

**REWRITTEN in D.2** per Pre-0 findings. The original D.1 §10 framing — "replace the imperative `(fuel 1000000)` decrementing counter with the on-network tropical fuel cell" — was reframed by Pre-0 measurement evidence (8 supporting findings + S-tier baseline finding 20). The hybrid pivot is empirically grounded across all 5 measurement tiers (M+A+E+R+S).

### §10.1 Scope and rationale (HYBRID PIVOT — D.2)

**Phase 1C INTRODUCES the canonical tropical fuel substrate as architectural foundation for Phase 3C consumers** (UC1 fuel-exhaustion blame attribution; UC2 cost-bounded elaboration via Galois bridge; UC3 per-branch cost tracking under union-type ATMS) **WITHOUT migrating the per-decrement hot path off the existing struct-copy + inline check fast-path.**

**The hybrid architecture**:
- Decrement sites (4) PRESERVE the existing `(struct-copy prop-net-cold ... [fuel (- ... n)])` pattern (no migration; ~24 ns)
- Check sites (11) PRESERVE the existing `(<= (prop-network-fuel net) 0)` inline check (no migration; ~6 ns)
- Per-decrement total cycle stays at ~30-40 ns (matches Pre-0 baseline; no regression)
- The canonical fuel-cost-cell + fuel-budget-cell are allocated at well-known IDs (cell-id 11/12) and serve as the architectural substrate for Phase 3C consumers, NOT as per-decrement live state
- The threshold propagator is installed as the structural guarantee that contradiction-on-exhaustion routes through the propagator network for any path that updates the cell
- Cell value is updated at SEMANTIC TRANSITIONS (start of phase, exhaustion-write, save/restore boundaries via existing snapshot mechanism) — NOT per-decrement

**Empirical rationale** (Pre-0 plan §12.6 Findings 2, 5, 11, 13, 15, 16, 17, 19, 20):
- M-2: inline check 6 ns vs propagator fire 100-600 ns (10-100× regression risk if per-decrement)
- R-16: ZERO GC during 100k decrements under struct-copy; per-decrement cell-write would generate tagged-cell-value entries → MAJOR GC pressure
- R-19: hybrid pivot is the ONLY architecture preserving the GC-friendly property of the current substrate (strongest single piece of evidence)
- S-20: pre-impl `prop_firings` + `prop_allocs` are ZERO suite-wide; Phase 1C threshold propagator becomes the FIRST production on-network propagator firing in elaboration; clean architectural baseline

**Why hybrid IS principled (not belt-and-suspenders)**:
- Decrement sites' inline check + cell substrate handle DIFFERENT code paths with DIFFERENT performance profiles
- Inline check: per-decrement HOT PATH (common case; ~30-40 ns; 100k+ ops/sec in deep type inference)
- Cell + threshold propagator: Phase 3C consumer paths (rare; semantic-phase granularity; few ops per file)
- The mechanisms are NOT redundant; they decomplect fast-path optimization from architectural substrate

**D.3 R1 commentary — small code-change footprint is intentional, not "easy migration"**:

Phase 1C's small code-change footprint under hybrid (~45-90 LoC vs D.1's ~250-400) is the empirical consequence of preserving the per-decrement hot path. The design weight is in the architectural framing (cell substrate + threshold propagator + cell staleness contract per §10.B + Phase 3C consumer API + four-surface scaffolding tracking per §10.1.A), NOT in code volume.

Future PReduce / OE consumers (per §6.6 hybrid-as-scaffolding-NOT-template caveat) should NOT use Phase 1C's small footprint as evidence of "easy migration" — under hybrid, the work was DEFERRED via scaffolding (per §10.1.A retirement plan + Issue #55), NOT eliminated. The full-migration footprint (~250-400 LoC per D.1 §10.4) is recoverable as the future SH Series migration scope (per DEFERRED.md "PPN 4C tropical addendum: hybrid pivot scaffolding retirement" entry).

### §10.1.A Honest framing & retirement plan (D.3 consolidating P1 + P4 REFINEMENTs)

The "decomplection" framing in §10.1 describes WHAT the hybrid does at the architectural level. This subsection adds the WHY (specific blocker), the principle-level acknowledgment (Cell-as-Single-Source-of-Truth inversion), and the retirement plan with dual-surface tracking. Both framings are simultaneously true and intentional — design intent + honest accountability.

**Two framings, both true**:

1. **Decomplection** (positive description; what the design does): hybrid separates fast-path optimization (struct-copy + inline check at per-decrement) from architectural substrate (cell + threshold propagator at semantic-phase granularity). The mechanisms address different code paths with different performance profiles.

2. **Incomplete migration deferred to SH Series** (honest acknowledgment; why the design does it): apply the [`workflow.md` § "'Pragmatic' Is a Rationalization for Incomplete"](../../.claude/rules/workflow.md) test — replace "decomplection" with "incomplete migration" and verify the rephrased framing is acceptable:
   > "The hybrid pivot is INCOMPLETE migration — decrement sites preserve struct field because cell-write at per-decrement rate triggers major GC under current Racket runtime (per Pre-0 Finding 19 R3 baseline)."
   
   The rephrasing IS acceptable because it names the **specific blocker**: Racket runtime GC behavior at per-decrement cell-write rate. Per the codified pattern, "deferred to Track N because [specific dependency]" is the principled deferral form; "decomplection" alone (without specific blocker) would be rationalization.

**Principle inversion (acknowledged explicitly)**:

[`DESIGN_PRINCIPLES.org § Propagator-First Infrastructure`](principles/DESIGN_PRINCIPLES.org) defaults to cells over off-network state — Cell-as-Single-Source-of-Truth. Under hybrid, this principle is **INVERTED at the per-decrement timescale**: the struct-field `prop-net-cold-fuel` is the LIVE STATE for fuel-cost; the cell is DERIVED via lazy sync at semantic transitions (per §10.B Cell Staleness Contract). The inversion is empirically forced (not stylistic) per [Pre-0 Finding 19](2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md): R3 measured ZERO major GC during 100k decrements under struct-copy; ANY architecture making the cell PRIMARY at per-decrement granularity triggers major GC pressure (architectural failure under R3 baseline).

**Retirement plan**:

The inversion is SCAFFOLDING pending SH Series runtime infrastructure that makes per-decrement cell-write GC-friendly. Under SH Series:
- Per-decrement cell-write becomes feasible (cheaper GC characteristics, lighter cell representation, OR object pooling for tagged-cell-value entries)
- The cell becomes PRIMARY storage; the struct-field `prop-net-cold-fuel` is retired
- The hybrid pivot retires; full migration lands as the original D.1 design intended (see D.1 §10.3 patterns)
- §14.4 SRE lattice lens Q5 dual-classification reverts to single (cell PRIMARY)

**Dual-surface tracking** (operational + design-time visibility):
- [GitHub Issue #55](https://github.com/LogosLang/prologos/issues/55) — "PPN 4C tropical addendum: retire hybrid pivot scaffolding (per-decrement fuel-cost cell migration) under SH Series runtime" (queryable, linkable from PRs, surfaces in repo dashboards)
- [`DEFERRED.md`](DEFERRED.md) entry under "PPN 4C tropical addendum: hybrid pivot scaffolding retirement" (in-repo single-source-of-truth for deferred work)
- [`Q-1B-6` empirical-validation spike at Phase 1B mini-design opening](#§99-open-questions-deferred-to-per-phase-mini-designaudit-per-users-workflow) (PRE-implementation falsification test) + [§11.3 Hybrid pivot reconsideration gate at Phase 1V close](#§113-phase-1v-exit-criteria) (POST-implementation final verification)

The four-surface tracking (design-doc + DEFERRED.md + GitHub Issue + bracketed implementation gates) ensures the scaffolding is impossible to forget when SH Series runtime work begins.

**This is honest deferral, not principle violation** per `workflow.md` § "Validated ≠ Deployed" + `DEVELOPMENT_LESSONS.org` § "'Pragmatic' Is a Rationalization for Incomplete." The principled discipline: name the specific blocker (✓ Racket runtime GC at per-decrement cell-write rate); name the retirement trigger (✓ SH Series runtime infrastructure); track at multiple surfaces (✓ four surfaces above); verify the deferral remains valid (✓ Q-1B-6 + §11.3 falsification gates).

### §10.A The threshold propagator's role under hybrid (D.3 from M1 BLOCKING)

Per Network Reality Check (`workflow.md`): apply the three concrete questions to the threshold propagator under hybrid:

1. **Which `net-add-propagator` calls?** — 1 (at make-prop-network setup; per §10.2)
2. **Which `net-cell-write` calls produce the result?** — Cell-write-mutating call sites (per §10.B Cell Staleness Contract); decrement sites use struct-copy (NOT cell-write)
3. **Trace cell creation → propagator installation → cell write → cell read = result?** — YES for non-decrement-site paths; NO for the per-decrement hot path

**Honest reframing**: under hybrid, the threshold propagator does NOT carry per-decrement information flow. Decrement sites use inline check + struct-copy; the cell isn't written per-decrement. The propagator's load-bearing role is for **non-decrement-site cell-write paths**, of which there are exactly THREE under D.3 design:

1. **Phase 3C consumer paths** that update fuel cost. Examples:
   - UC1 walks accumulating cost across propagator dependency chains (residuation walk for fuel-exhaustion blame attribution per §9.7)
   - UC2 budget projection writes (cost-bounded elaboration via Galois bridge γ direction per §9.7)
   - UC3 per-branch cost updates under union-type ATMS branching (per §9.7)
2. **On-exhaustion path** — decrement site detects exhaustion via inline check; writes final cost to fuel-cost-cell; propagator fires (rare event); writes contradiction. This routes contradiction through propagator network for architectural correctness on the rare exhaustion event.
3. **Speculation rollback** — cell-restore via worldview narrow under tagged-cell-value semantics; threshold propagator may re-fire if rollback restores a different cost level relative to budget.

**For per-decrement information flow on the hot path**: NOT propagator-mediated under hybrid. This is acknowledged scaffolding pending SH Series runtime infrastructure that makes per-decrement cell-write GC-friendly (per Pre-0 Finding 19; current Racket runtime triggers major GC under per-decrement cell-write at 100k+ ops/sec).

**Why this matters**: this honest framing prevents the "propagator-as-decoration" failure mode (per CRITIQUE_METHODOLOGY § Lens M; PPN Track 4 retrospective). The propagator IS load-bearing — for the three named roles above, NOT for every decrement. Future maintainers reading "threshold propagator installed for Phase 1C" should understand:
- Phase 3C consumers MUST trigger the propagator via cell-write to get contradiction-on-exhaustion semantics for their consumer paths
- The propagator does NOT serve as a per-decrement "watch the cost cell, fire on every change" — that pattern is structurally avoided under hybrid for performance + GC reasons

**Cross-reference**: per §10.B Cell Staleness Contract, the propagator's three roles all involve EXPLICIT cell-write operations (not implicit per-decrement updates); this is consistent with the staleness contract's "cell value lags struct-field by at most one semantic transition" framing.

### §10.B Cell Staleness Contract (D.3 from P3 BLOCKING)

Under hybrid pivot, the fuel-cost cell's value LAGS the struct-field's live state. This subsection makes the staleness explicit at the API surface so consumers can reason correctly.

**Staleness bound**: at most one semantic transition. The cell value reflects the cost-state as-of the last semantic-transition cell-write (per Q-1C-3 enumeration, deferred to Phase 1C-iii mini-design).

**Two API surfaces** (typed read APIs):

```racket
;; net-fuel-cost-read net :: Net -> TropicalFuel
;;   Returns the cell value (POSSIBLY STALE — caller accepts staleness).
;;   Use when: cost-as-of-last-transition is sufficient for the consumer's purpose.
;;   Examples: Phase 3C UC1 walk accumulating cost from prior dependency chain
;;             snapshots; UC3 branch-local cost reads at branch-fork boundaries.
(define (net-fuel-cost-read net)
  (net-cell-read net fuel-cost-cell-id))

;; net-fuel-cost-read/synced net :: Net -> (Values Net TropicalFuel)
;;   Triggers sync from struct-field BEFORE reading. Returns updated net + live cost.
;;   Use when: caller needs LIVE cost-state at the read point.
;;   Examples: Phase 3C UC2 budget projection at semantic-phase boundary;
;;             on-exhaustion reads triggered from non-decrement-site contexts.
(define (net-fuel-cost-read/synced net)
  (define current-fuel (prop-network-fuel net))         ; struct-field live state
  (define budget (net-cell-read net fuel-budget-cell-id))
  (define current-cost (- budget current-fuel))         ; derive cost from struct-field
  (define synced-net (net-cell-write net fuel-cost-cell-id current-cost))
  (values synced-net current-cost))
```

**Discipline at the API surface**: Phase 3C consumer authors choose explicitly which API to use based on staleness tolerance. The naming convention (`/synced` suffix) makes the choice visible at the call site:
- `(net-fuel-cost-read net)` reads possibly-stale data — fine for many consumer purposes, FAST
- `(net-fuel-cost-read/synced net)` triggers sync — guaranteed live, costs one struct-field read + one cell-write

**Why this matters (Correct-by-Construction enforcement)**: per DESIGN_PRINCIPLES.org § Correct by Construction, the wrong thing should be hard to express. Without the typed API discipline, consumer code writes `(net-cell-read net fuel-cost-cell-id)` and silently accepts whatever the cell value happens to be — the staleness gap is invisible until it produces incorrect results in a Phase 3C UC. With the discipline, the consumer's read API choice IS their staleness contract; the design surface enforces the contract structurally.

**Documentation requirement**: the dual-API discipline + staleness bound MUST be documented INLINE at the API definitions in `tropical-fuel.rkt` (Phase 1B implementation), not just in this design doc. The inline documentation is the load-bearing artifact for consumer authors; the design doc is reference.

**Open question (deferred to Phase 1C-iii)**: Q-1C-3 cell-update cadence enumeration is BLOCKING for this contract — see §10.7. Without exhaustive enumeration of "what counts as a semantic transition," the staleness bound is ambiguous in practice.

### §10.2 Audit-grounded substrate plan (Q-Audit-1 findings — UNCHANGED)

**Allocation in `make-prop-network`** (per D.3 §10.3 — substrate setup is the same):
```racket
(define (make-prop-network [fuel 1000000])
  ;; ... existing allocations (cell-ids 0-10) ...

  ;; Phase 1C — canonical tropical fuel cells (architectural substrate)
  (define-values (net1 fuel-cid) (net-new-tropical-fuel-cell base-net))
  ;; (verify cell-id allocated as 11 — well-known position)

  (define-values (net2 budget-cid) (net-new-tropical-budget-cell net1 fuel))
  ;; (verify cell-id allocated as 12)

  ;; Install threshold propagator (structural guarantee for cell-write paths)
  (define threshold-prop (make-tropical-fuel-threshold-propagator fuel-cid budget-cid))
  (net-add-propagator net2 (list fuel-cid budget-cid) '() threshold-prop)
  ;; ...

  ;; PRESERVE: prop-net-cold struct still has 'fuel' field (per-decrement live state)
  ;; PRESERVE: prop-network-fuel macro at line 399 (fast-path accessor)
)
```

**Export well-known cell-ids**: `fuel-cost-cell-id = 11`, `fuel-budget-cell-id = 12` per §4.3.

**Production scope under hybrid** (vs original D.1 §10.2 audit findings):
- **Decrement sites** (4): NO migration; preserve existing struct-copy pattern
- **Check sites** (11): NO migration; preserve existing inline `(<= fuel 0)` check
- **Read-as-value sites** (3): MIGRATE selectively (architecturally-consistent paths use cell-read; performance-sensitive paths use struct-field)
- **Macro `prop-network-fuel`**: PRESERVED (still accesses struct field)
- **Struct field `prop-net-cold-fuel`**: PRESERVED (live state for fast-path)
- **typing-propagators saved-fuel** (1): MIGRATE to cell-mediated semantics (snapshot/restore boundary is a semantic transition)
- **pretty-print** (1): UPDATE to display both struct-field cost and cell-budget for debugging
- **Test sites** (13): MINIMAL migration — preserve existing struct-field assertions; ADD new tests for cell-mediated APIs where Phase 3C-relevant
- **Bench sites** (2): NO migration (bench-alloc.rkt measures decrement cost, which stays struct-copy)

**D.3 R2 commentary — Q-Audit-1 17-refs framing under hybrid**:

D.1 §2.2 Q-Audit-1 enumerated 17 production refs to `prop-network-fuel`. Under D.2/D.3 hybrid pivot, the categorization is:
- **15 PRESERVED** (no migration; per the production scope list above): 4 decrement sites + 11 check sites
- **2-3 SELECTIVELY MIGRATED** (per §10.3 selective-migration patterns): 1-2 read-as-value sites at semantic-transition paths + typing-propagators saved-fuel cell sync
- **Plus**: 1 pretty-print update (dual display); 13 test refs MOSTLY PRESERVED (struct-field assertions); 2 bench refs PRESERVED

The "17 production refs" count from Q-Audit-1 is **REFERENCE for completeness** (architectural visibility into the full migration scope D.1 envisioned); the actual MIGRATION scope under hybrid is ~3-5 sites (per R1 §1.2 reframing). Future SH Series migration will recover the full 17-ref scope (per [Issue #55](https://github.com/LogosLang/prologos/issues/55) + [DEFERRED.md](DEFERRED.md) "PPN 4C tropical addendum: hybrid pivot scaffolding retirement" entry).

This rescoping note bridges the audit grounding (17-refs framing useful for full architectural visibility) with the actual hybrid migration scope (~3-5 sites) so future readers don't misread the audit count as the implementation count.

### §10.3 Per-site patterns under hybrid (REVISED)

**Decrement sites** (4 sites — propagator.rkt:2384, 3000, 3053, +1 widening — UNCHANGED):

```racket
;; PRESERVED: struct-copy decrement (fast-path; 24 ns/call per Pre-0 M7.1)
(struct-copy prop-net-cold ... [fuel (- (prop-network-fuel net) n)])
```

**Check sites** (11 sites — propagator.rkt:1817, 2366, 2373, 2329, 2992, 3045, 3132, 3135, 3142, 65, 399 — UNCHANGED):

```racket
;; PRESERVED: inline check (fast-path; 6 ns/call per Pre-0 M8)
[(<= (prop-network-fuel net) 0) net]
```

**On exhaustion (decrement site detects cost >= budget)** — NEW pattern under hybrid:

```racket
;; When decrement would cause exhaustion, write the exhausted cost to the cell
;; This triggers the threshold propagator (rare event), which routes contradiction
;; through the propagator network for architectural correctness.
(let* ([new-fuel (- (prop-network-fuel net) n)])
  (cond
    [(<= new-fuel 0)
     ;; Exhausted — write to cell to trigger threshold propagator
     (define cost-on-exhaustion (- (prop-network-fuel-budget net) new-fuel))
     (net-cell-write net fuel-cost-cell-id cost-on-exhaustion)]
     ;; threshold propagator fires; writes contradiction; net is now contradicted
    [else
     ;; Fast-path: struct-copy update; no cell-write; no propagator fire
     (struct-copy prop-net-cold ... [fuel new-fuel])]))
```

The exhaustion path is RARE (per Pre-0 finding 5: a typical run completes within budget; exhaustion is the failure case). The cost of cell-write + propagator fire is amortized over the entire run.

**Read-as-value sites** (3 sites — selective migration):

```racket
;; Site 1: propagator.rkt:1824 (general-purpose remaining-fuel boxing)
;;   PRESERVE struct-field access (fast-path; not a semantic transition)
(define remaining-fuel (box (prop-network-fuel net)))

;; Site 2: propagator.rkt:1872 (similar pattern)
;;   PRESERVE struct-field access

;; Site 3: propagator.rkt:2875 (potentially semantic-transition path)
;;   AUDIT at 1C-iv mini-design: if path is reached at semantic-transition
;;   (e.g., before save/restore, before phase boundary), MIGRATE to cell-read
;;   to ensure cell value reflects current cost; otherwise PRESERVE struct-field
```

**typing-propagators.rkt:2269** (saved-fuel rollback — semantic transition):

```racket
;; BEFORE
(define saved-fuel (prop-network-fuel net2w))
;; ... later restore via snapshot mechanism

;; AFTER (under hybrid)
;; Save/restore IS a semantic transition; sync cell at this boundary
(define saved-fuel (prop-network-fuel net2w))  ; struct-field for fast-path
;; Cell update at the snapshot boundary (semantic transition):
(net-cell-write net2w fuel-cost-cell-id
                (- (net-cell-read net2w fuel-budget-cell-id) saved-fuel))
;; (later restore: existing snapshot mechanism handles BOTH struct-field AND cell)
```

Per Q-1C-1 (deferred to 1C-iv mini-design): verify whether elab-net snapshot mechanism already captures cell state, OR whether explicit cell-write is needed at save/restore boundaries.

**pretty-print.rkt:463** (display — update to show both):

```racket
;; BEFORE
[(expr-prop-network v) (format "#<prop-network ~a>" (prop-network-fuel v))]

;; AFTER
[(expr-prop-network v)
 (format "#<prop-network fuel=~a cost-cell=~a budget-cell=~a>"
         (prop-network-fuel v)                   ; struct-field (live state)
         (net-cell-read v fuel-cost-cell-id)     ; cell value (semantic-transition state)
         (net-cell-read v fuel-budget-cell-id))]
;; If struct-field and cell value differ, that's expected (cell is updated only at
;; semantic transitions); display both for debugging/observability.
```

**Macro `prop-network-fuel` (propagator.rkt:399)** — PRESERVED:

```racket
;; PRESERVED: still expands to struct-field access; serves fast-path callers
(define-syntax-rule (prop-network-fuel net) (prop-net-cold-fuel (prop-net-cold-of net)))
```

**Struct field `prop-net-cold-fuel` (propagator.rkt:337)** — PRESERVED:

```racket
;; PRESERVED: still in prop-net-cold struct; serves as per-decrement live state
;; Cell substrate is COMPLEMENTARY (semantic-transition state for Phase 3C consumers)
```

**Test migrations** (selective):
- 13 test sites: most PRESERVE existing `(prop-network-fuel net)` assertions (testing struct-field/counter behavior)
- ADD new tests for cell-mediated APIs:
  - Cell allocation at make-prop-network: verify cell-id 11/12 + initial values
  - Threshold propagator installation: verify cell-write triggers contradiction at boundary
  - Semantic-transition sync: verify cell value reflects cost at save/restore boundaries
  - Phase 3C UC1/UC2/UC3 cell-read patterns (forward-capture for Phase 3C tests)

**Bench migrations** (no migration):
- bench-alloc.rkt 2 sites: PRESERVE struct-copy measurement (the per-decrement cost is the architecturally-significant metric)

### §10.4 Sub-phase plan (REVISED — REDUCED scope)

Under hybrid, Phase 1C is dominated by SUBSTRATE setup, not migration. Sub-phase plan compressed from 9 to 5 sub-phases:

- **1C-i** — Pre-implementation audit (mini-audit): verify cell-id 11/12 unconflicted; identify which read-as-value sites (3) are semantic transitions vs fast-path; identify Phase 3C UC test scaffolding sites
- **1C-ii** — Allocate canonical cells in `make-prop-network` (cell-id 11/12 + threshold propagator install); export `fuel-cost-cell-id` + `fuel-budget-cell-id` constants
- **1C-iii** — Implement on-exhaustion cell-write at decrement sites (rare-event path; not per-decrement hot-path); implement typing-propagators saved-fuel cell sync at semantic-transition boundaries; update pretty-print display
- **1C-iv** — Migrate selective read-as-value sites (per audit at 1C-i); add new tests for cell-mediated APIs (substrate validation + Phase 3C UC forward-capture)
- **1C-v** — Verification + close: probe + targeted suite + full suite + parity test (tropical-fuel-parity axis: counter exhaustion AND cell-write-on-exhaustion equivalent for representative workloads); verify per-decrement performance preserved (M7+M8+M13 within Pre-0 variance)

**Sub-phases REMOVED from D.1 §10.4** (no longer needed under hybrid):
- ~~1C-iii Migrate decrement sites~~ — preserved
- ~~1C-iv Migrate check sites~~ — preserved
- ~~1C-vi Retire prop-network-fuel macro + prop-net-cold-fuel field~~ — preserved
- ~~1C-vii Migrate test sites batch mechanical~~ — minimal migration
- ~~1C-viii Migrate bench sites~~ — preserved

### §10.5 Drift risks (REVISED for hybrid)

- **D-1C-1**: Cell-update cadence ambiguity — when EXACTLY does the cell get synced from struct-field? Per Q-1C-3 (NEW): semantic-transition-only is the leaning answer, but explicit enumeration of transitions (start of phase / exhaustion / save-restore / phase-boundary) needs verification at 1C-iii mini-design
- **D-1C-2**: typing-propagators saved-fuel rollback — verify whether elab-net snapshot mechanism captures cell state automatically OR explicit cell-write at boundaries needed (per Q-1C-1)
- **D-1C-3**: Cell-id 11/12 conflicts — verify at 1C-i mini-audit no other phase has reserved these IDs
- **D-1C-4**: Threshold propagator firing semantics under speculation — verify with test-speculation-bridge that cell-write under speculation worldview correctly tags the threshold-fire event
- **D-1C-5**: Performance regression at decrement sites under hybrid — Pre-0 M7+M8+M13 baseline must be preserved (per microbench-claim verification rule). At 1C-v close: re-run M7+M8+M13 to verify ≤5% regression vs baseline.
- **D-1C-6** (NEW): Cell value vs struct-field divergence — under hybrid, the cell can be stale relative to struct-field between semantic transitions. Phase 3C consumers reading the cell must understand this; either accept staleness OR trigger sync first. Document the cell-staleness contract at 1C-ii mini-design.

### §10.6 Termination + parity

- Termination: Phase 1C substrate setup is structural (cell allocation + propagator install); preserves existing decrement+check semantics; trivially terminates
- Parity: tropical-fuel-parity axis (per D.3 §7.11) — UPDATED:
  - For representative workloads, OLD counter and NEW substrate produce IDENTICAL exhaustion semantics (struct-field counter is the live state in both cases)
  - The cell value at semantic-transition boundaries equals (budget - struct-field-fuel); this equivalence is the parity invariant
  - On-exhaustion contradiction-write routes through propagator network in NEW; same semantic effect as OLD inline `(<= fuel 0)` short-circuit
  - V-tier post-impl validates: existing tests' `(prop-network-fuel result)` assertions PASS unchanged

### §10.7 Open questions (deferred to per-phase mini-design+audit)

- **Q-1C-1** (CARRIED): typing-propagators saved-fuel rollback semantics — verify at 1C-iii mini-design
- **Q-1C-2** (CARRIED, REFRAMED): Test cell-mediated API additions — which Phase 3C UC forward-capture tests belong in Phase 1C? (The cost-accumulation semantic shift in D.1 §10.7 is moot under hybrid since struct-field assertions are preserved.)
- **Q-1C-3** (NEW under hybrid): Cell-update cadence — exhaustively enumerate semantic transitions where cell sync occurs:
  - Start of phase (initial budget allocation)?
  - End of phase (final cost capture)?
  - Save/restore boundaries (snapshot-mediated)?
  - Phase 3C UC1/UC2/UC3 explicit query sites (sync-on-read)?
  - On-exhaustion path (decrement site detects exhaustion)?
  
  Lean: enumerate at 1C-iii mini-design with code in hand; the answer informs whether cell-staleness is bounded and predictable.

---

## §11 Phase 1V — Vision Alignment Gate Phase 1

### §11.1 Scope

Adversarial TWO-COLUMN VAG (per `9f7c0b82` codification) on all of Phase 1: 1A-iii-b + 1A-iii-c + 1B + 1C closure together. Closes Phase 1 entirely.

### §11.2 VAG structure (per Stage 4 Per-Phase Protocol Step 5)

Four questions × TWO-COLUMN catalogue vs challenge:

**Question (a) On-network?**
- Catalogue: tropical fuel substrate fully on-network; ATMS deprecated APIs + surface AST retired (no off-network deprecated state)
- Challenge: are there any remaining off-network references to retired APIs? Defensive guards "for safety" preserved? Run pipeline.md "Two-Context Audit" to verify both elaboration + module-loading contexts.

**Question (b) Complete?**
- Catalogue: 1A-iii-b retirement complete (13 functions + struct + atms-believed); 1A-iii-c retirement complete (14-file pipeline); 1B primitive shipped + tested; 1C substrate setup complete (cell-id 11/12 allocated; threshold propagator installed; struct-field + macro + decrement/check sites preserved per hybrid pivot)
- Challenge: did Pre-0 microbenchmark perf claims land? Re-microbench M7+M8+M13 at close per microbench-claim verification rule (Pre-0 plan §12.6 cross-reference); per-decrement cycle should remain ~30-40 ns. Did any quantale property declarations remain speculative (capture-gap risk; M10/M12/R4/A12 captured at §9.10 Phase 1B implementation checklist)? Under hybrid: did the decomplection of fast-path + cell substrate genuinely deliver, or did edge cases force per-decrement cell writes (architectural failure)?

**Question (c) Vision-advancing?**
- Catalogue: first optimization-quantale instantiation in production; tropical fuel substrate; multi-quantale composition NTT; Phase 3C cross-reference capture; hybrid pivot's empirically-grounded decomplection
- Challenge: is the residuation operator load-bearing (Form A test passes) or speculative? Does the multi-quantale NTT actually compose with TypeFacet quantale, or is it parallel co-existence only? Is OE Series Track 0/1/2 first landing recognized? Under hybrid: is preserving the struct field + macro genuinely "fast-path needed for performance" or "scaffolding preserved for safety" (workflow.md belt-and-suspenders red flag — D.3 lens P scrutiny target)?

**Question (d) Drift-risks-cleared?**
- Catalogue: drift risks named per §7.4, §8.4, §9.8, §10.5 (D-1C-1 through D-1C-6 under hybrid) all addressed
- Challenge: did the named risks cover both correctness AND perf-vs-design-target axes? Were any inherited patterns (deprecated APIs, surface AST scaffolding) preserved without challenge? Under hybrid specifically: D-1C-5 (per-decrement perf regression) is the load-bearing perf gate — verify M7+M8+M13 stay within Pre-0 variance at 1V close.

### §11.3 Phase 1V exit criteria

- All 4 VAG questions pass under adversarial framing
- Probe diff = 0 semantically vs pre-Phase-1 baseline (S4 reference: 28 commands; Pre-0 plan §12.5 + S-tier baseline file)
- Full suite GREEN within 118-127s variance band (S1 reference: 119.288s)
- Parity tests GREEN (tropical-fuel-counter-parity reframed for hybrid per §10.6 + 1A-iii-b parity + 1A-iii-c parity)
- 1+ codifications graduated to DEVELOPMENT_LESSONS.org if patterns surfaced (capture-gap discipline at 5 data points already graduation-ready)
- Cross-reference capture in D.3 Phase 3 design verified (Form C scheduled)

**Pre-0 microbench claims verified at Phase 1V close — comprehensive list (D.3 R4 REFINEMENT)**:

Per microbench-claim verification rule ([`DEVELOPMENT_LESSONS.org § Microbench-Claim Verification Pays Off Across Sub-Phase Arcs`](principles/DEVELOPMENT_LESSONS.org)): every load-bearing Pre-0 finding requires re-microbench at Phase 1V close. **Total: 11 microbench re-runs**.

- **Per-decrement cycle preserved (3 re-runs)**: re-microbench M7 (struct-copy decrement) + M8 (inline check) + M13 (prop-network-fuel access). **Target**: per-decrement cycle (M7+M8+M13 sum) ≤ 5% regression vs Pre-0 baseline (~36 ns).
- **Phase 1B substrate baselines (4 re-runs; per §9.10 Phase 1B implementation checklist)**: M10 (residuation operator) + M11 (tropical tensor) + M12 (SRE registration overhead) + R4 (cell layout). **Target**: per Pre-0 plan §3 + §8 hypotheses at Phase 1B close.
- **High-frequency decrement at scale (3 re-runs; NEW per R4)**: re-microbench A7.1/A7.2/A7.3 (1k/10k/100k decrements). **Target**: 62.5 bytes/dec linear scaling preserved (per Pre-0 Finding 7); ZERO major-GC at 100k (per Pre-0 Finding 16 R3 baseline).
- **Speculation rollback no-leak (1 re-run; NEW per R4)**: re-microbench A9 (100 spec cycles save+write+restore). **Target**: ≤ 0 KB retention at 100 cycles (per Pre-0 Finding 8 baseline) + ≤ 30 KB at 1000 cycles (per Pre-0 Finding 17 R5 long-term residual bound).
- **Full-pipeline regression (2 re-runs; NEW per R4)**: re-microbench E7 (probe full file 28 expressions) + E8 (50-deep id composition; hybrid pivot CRITICAL scenario per Pre-0 Finding 13). **Target**: E7 wall ≤ +5% (≤ 351 ms) + memory ≤ +10% (≤ 894 MB); E8 wall ≤ +25% (per Pre-0 plan §7).

The list is comprehensive for the "did the perf claims land" verification. ~30-60 min total at Phase 1V close.

**Architectural + reconsideration gates** (D.2 + D.3 from P2 REFINEMENT):

- **Hybrid pivot performance gate** (NEW per D.2): per-decrement cycle (M7+M8+M13 sum) ≤ 5% regression vs Pre-0 baseline (~36 ns) — overlaps with R4 microbench list above
- **Hybrid pivot architectural gate** (NEW per D.2): aggregate `prop_firings` post-impl ≤ 1× per file BSP-barrier-equivalent (S-20 baseline = 0; under hybrid, threshold propagator should fire only on rare exhaustion + semantic-transition-cell-writes, NOT per-decrement)
- **Hybrid pivot reconsideration gate** (NEW per D.3 from P2 REFINEMENT): post-implementation re-microbench M7 (cell-write cost vs struct-copy) + R3 (GC profile under sustained cell-write at 100k+ ops/sec); IF cell-write ≤ 50% of struct-copy AND R3 GC stays at zero major-GC, escalate to user — "the hybrid pivot's empirical motivation does NOT hold under Phase 1B reality; reconsider hybrid retirement timing?" Cross-reference: Q-1B-6 (Phase 1B mini-design opening spike) is the EARLY signal; this Phase 1V gate is the FINAL verification. The two gates differ in timing (pre-build vs post-build) and granularity (spike vs full microbench suite); both serve the falsification-test discipline per workflow.md "Belt-and-Suspenders Masks Bugs."

---

## §12 Termination arguments

Per [GÖDEL_COMPLETENESS.org](principles/GÖDEL_COMPLETENESS.org). Each new/modified propagator + cell needs explicit termination argument.

| Component | Phase | Guarantee level | Measure |
|---|---|---|---|
| Tropical fuel cell merge (min) | 1B | Level 1 (Tarski) | Finite lattice bounded by budget; monotone min |
| Tropical fuel threshold propagator | 1B | Level 1 | Fires once at threshold; monotone cost accumulation |
| Tropical-left-residual operator | 1B | N/A (pure function) | Read-time computation |
| Canonical BSP fuel cell migration | 1C | Level 1 | Inherits tropical fuel termination; no new strata |
| ATMS deprecated API retirement | 1A-iii-b | N/A (deletion) | Pure deletion; no termination concern |
| Surface ATMS AST retirement | 1A-iii-c | N/A (deletion) | Pure deletion |

**No new strata added; no cross-stratum feedback; no well-founded measure beyond Tarski needed.**

BSP scheduler outer loop: Phase 1C makes the loop's termination structurally backed by the canonical tropical fuel cell. The cell's Tarski-fixpoint termination + threshold propagator's contradiction-on-exhaustion gives the BSP scheduler a structural termination guarantee, replacing the imperative `prop-network-fuel` decrementing counter.

---

## §13 Pre-0 benchmark plan

> **D.2 STATUS**: §13 is HISTORICAL — it sketched the Pre-0 plan at D.1 time. The comprehensive Pre-0 plan (38 tests across 8 tiers M/A/C/X/E/R/S/V; memory as first-class) lives in [`docs/tracking/2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md`](2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md) and executed to completion (M+A+E+R+S-tiers; 22 design-affecting findings; commits `f6576479` → `8a29f6af`). §13.5's predicted "If M8 shows threshold propagator overhead > 100% of inline check, reconsider threshold approach" came true at Pre-0 M-tier (Finding 2: inline 6 ns vs propagator 100-600 ns); D.2 §10 reframes Phase 1C with the hybrid pivot in response. The historical sketch below is preserved for traceability.

Per DESIGN_METHODOLOGY Stage 3 Pre-0 Benchmarks Per Semantic Axis. Extends existing `benchmarks/micro/bench-ppn-track4c.rkt` (295 lines, M1-M6 + A1-A4 + E1-E6 + V1-V3 tiers per file inspection).

### §13.1 New micros (M-tier extension)

**M7 — Tropical fuel merge (min) cost vs counter decrement**
- Setup: pre-allocated tropical fuel cell + pre-allocated counter (existing prop-network-fuel)
- Measure: `(net-cell-write net fuel-cid (+ cost n))` cost in ns/call
- Compare: `(struct-copy prop-net-cold ... [fuel (- fuel n)])` in ns/call
- Hypothesis: cell-write within 50% of struct-copy cost (acceptable; structural correctness justifies marginal cost)

**M8 — Threshold propagator firing cost vs `(<= fuel 0)` check**
- Setup: pre-allocated fuel + budget cells + threshold propagator installed
- Measure: per-write threshold check (propagator fires) cost
- Compare: `(<= (prop-network-fuel net) 0)` inline check cost
- Hypothesis: threshold propagator within 30% of inline check (single comparison + conditional write)

**M9 — Per-consumer fuel cell allocation cost (multi-consumer)**
- Setup: 1 cell vs 5 cells vs 50 cells per net
- Measure: `net-new-tropical-fuel-cell` allocation cost
- Hypothesis: O(1) per cell (cell-allocation is well-bounded)

### §13.2 New adversarial test (A-tier extension)

**A5 — Cost-bounded exploration vs flat fuel exhaustion (semantic axis)**
- Setup: workload with non-uniform per-step cost (some steps cost 1, others cost 100)
- Measure: tropical fuel exhaustion point matches budget exactly
- Compare: counter decrement exhaustion point (counter decrements by 1 regardless of step cost — semantic mismatch)
- Hypothesis: tropical fuel provides cost-aware exhaustion; counter only does step-count

### §13.3 Parity test (F-tier — new axis)

**F-tropical — Old counter vs new cell exhaustion equivalence (semantic parity)**
- Setup: 5+ representative workloads (typical elaboration, prelude load, deep type inference, etc.)
- Measure: exhaustion point under old counter (pre-1C) vs new cell (post-1C) for each workload
- Hypothesis: equivalent exhaustion points (within step-counting equivalence — old counter decrements 1/step; new cell accumulates step-cost which IS step-count if cost-per-step is 1)

### §13.4 Pre-0 execution plan

- Extend `bench-ppn-track4c.rkt` with M7-M9 + A5 + F-tropical sections (~80-120 LoC additions)
- Run pre-implementation baseline (current state, no tropical fuel cells)
- Establish predicted post-implementation deltas in this design (Phase 1V verifies actuals)
- Cost: ~15-30 min for benchmark execution; ~30-60 min for benchmark code addition

### §13.5 What Pre-0 might surface (potentially design-affecting)

- If M7 shows cell-write is significantly slower (>2x struct-copy), reconsider canonical instance approach — maybe per-consumer allocation only, with no canonical fuel cell
- If M8 shows threshold propagator overhead > 100% of inline check, reconsider threshold approach — maybe explicit check at decrement sites
- If M9 shows non-O(1) allocation, reconsider per-consumer allocation feasibility

These are unlikely (per S2 architectural pattern + BSP-LE 2B benchmarks showing cell ops are fast), but Pre-0 verifies before D.1 commits to specifics.

---

## §14 P/R/M/S Self-Critique

Applied inline during decision-making; consolidated here per DESIGN_METHODOLOGY Stage 3 requirement. The S lens (Structural — SRE/PUnify/Hyperlattice+Hasse/Module-theoretic/Algebraic-structure-on-lattices) is **load-bearing for this addendum** per CRITIQUE_METHODOLOGY mandate.

### §14.1 P — Principles challenged

| Decision | Principle served | Adversarial challenge |
|---|---|---|
| γ-bundle-wide (all of Phase 1) | Completeness; Decomplection | Could Tier 3 (1A-iii-c) defer to its own design? **No** — bundling closes Phase 1 atomically per 1V; γ-bundle-wide IS the principled choice when wide scope is achievable. |
| Multi-quantale composition NTT (β) | First-Class by Default; Most Generalizable Interface | Could be deferred to single-quantale only? **No** — multi-quantale composition makes the residuation declaration load-bearing (Phase 3C UC1/UC2/UC3 grounded); single-quantale would be capture-gap risk. |
| Form A+B+cross-reference capture for Phase 3C | Capture-gap discipline; Decomplection | Form C in Phase 1B was scope creep? **Yes** — confirmed; Form C belongs in Phase 3C with cross-reference back. |
| Residuation operator as read-time helper | Decomplection (consumer flexibility) | Should it be a propagator? **No** for Phase 1B — wrapping is consumer's choice; primitive stays algebraically simple. |
| `+inf.0` as tropical-top | Pragmatism with rigor; Most Generalizable Interface | Sentinel symbol for SRE alignment? **Lean toward `+inf.0`** but defer to 1B mini-design with code in hand. |

**Red-flag scrutiny**: no "temporary bridge", "belt-and-suspenders", "pragmatic shortcut" in this addendum's architectural commitments. Phase-specific scope items (Q-1B-1, Q-1B-2, Q-1B-4, etc.) deferred to per-phase mini-design+audit per user's workflow — this IS principled deferral, not vagueness.

### §14.2 R — Reality check (code audit)

Per §2.2 audit findings:
- Q-Audit-1: 17 production refs in propagator.rkt + 1 typing-propagators + 1 pretty-print + 13 test refs + 2 bench refs (well-bounded)
- Q-Audit-2: 13 deprecated functions + struct + 14 surface AST structs + 14-file pipeline impact (substantial but bounded)
- Q-Audit-3: tropical-fuel.rkt clean slate + 5 anticipated consumer scaffolding sites grounding the substrate-level placement

Scope claims tied to grep-backed audit data; no speculation floats above the codebase.

### §14.3 M — Propagator mindspace

Design mantra check (§5) passed for all components. Key on-network properties:
- Tropical fuel cell: pure cell-based, merge via `min`, no hidden state
- Threshold propagator: fires once at threshold; monotone
- Multi-quantale composition: cells as Q-modules; bridges as Galois-connection propagators; quantale-of-bridges
- Residuation operator: read-time pure function (consumer-wrapped if propagator semantics needed)

No "scan" / "walk" / "iterate" in design. The "fuel exhaustion" check IS a threshold propagator firing on cell write — emergent from cell state, not imperative loop.

### §14.4 S — SRE Structural Thinking (load-bearing)

**SRE lattice lens (mandatory)** per CRITIQUE_METHODOLOGY. **D.3 update from S1 BLOCKING**: §14.4 Q5 was inconsistent with D.2 §10's hybrid pivot (Q5 declared cell PRIMARY under D.1's full-migration; hybrid inverts to struct-field PRIMARY, cell DERIVED). Q5 + dependent Qs (Q3, Q4, Q6) updated below to acknowledge dual classification (D.1 full-migration vs D.2/D.3 hybrid pivot).

| Aspect | Tropical fuel quantale (this addendum) |
|---|---|
| **Q1 Classification** | VALUE lattice (atomic extended-real) — UNCHANGED across D.1/D.2/D.3 |
| **Q2 Algebraic properties** | Quantale + Commutative + Unital + Integral + Residuated; Heyting-like (residuation provides pseudo-complement-like structure); join-semilattice (idempotent min); CALM-safe — UNCHANGED across D.1/D.2/D.3 |
| **Q3 Bridges** | Future Galois bridge to TypeFacetQ (§4.2 type-cost-bridge); future bridges to MemoryCostQ, MessageCountQ (out of scope); composition via quantale-of-bridges. **D.3 hybrid clarification**: under hybrid, the cell value at projection time is POSSIBLY-STALE relative to live struct-field state (per §10.B Cell Staleness Contract). The α projection must accept the staleness OR trigger sync first via `net-fuel-cost-read/synced`. The bridge's Galois property HOLDS under the staleness contract since the cell value at any sync point IS a valid lattice element of TropicalFuelQ — staleness is "behind in time," not "wrong in lattice." |
| **Q4 Composition** | Two quantales co-exist as Q-modules; CALM-safe under monotone joins; Tarski-fixpoint per Q-module. **D.3 hybrid clarification**: TropicalFuelQ Q-module's cell receives infrequent writes (only at semantic transitions per §10.B); the tagged-cell-value semantics under speculation worldviews still composes correctly (each worldview tag holds a single TropicalFuel value; min-merge is the lattice join). Tarski-fixpoint per Q-module preserved; reduced write rate doesn't change the algebraic correctness. |
| **Q5 Primary/Derived** | **Under D.1's full-migration design**: PRIMARY for fuel-cost tracking; cell is PRIMARY storage. **Under D.2/D.3 hybrid pivot**: struct-field `prop-net-cold-fuel` is PRIMARY (live state); cell is DERIVED (lazy sync at semantic transitions per §10.B Cell Staleness Contract + Q-1C-3 cadence enumeration). The classification inversion is empirically forced by Pre-0 Finding 19 (full-cell-migration triggers major GC under R3 baseline); under SH Series runtime, primary inverts back to cell. **This dual-classification IS the scaffolding-with-retirement-plan pattern at the structural-analysis level** (per workflow.md "Validated ≠ Deployed" + DEVELOPMENT_LESSONS.org "Pragmatic Is a Rationalization for Incomplete" — the deferral is principled when the blocker is named: Racket runtime GC behavior at per-decrement cell-write rate). |
| **Q6 Hasse diagram** | Linear chain `0 ≤_rev 1 ≤_rev 2 ≤_rev ... ≤_rev +∞` (totally ordered); compute topology: trivially parallel (no decomposition needed for atomic values). **D.3 hybrid clarification**: under hybrid, the cell visits a SUBSET of the linear chain (only semantic-transition values; per-decrement values are in the struct field, not the cell). The lattice ordering is preserved (subset of values still totally-ordered); the Hasse-based optimality argument unchanged (linear chain is trivially parallel regardless of which subset is visited). |

**PUnify**: tropical fuel is atomic; PUnify-style structural unification doesn't apply at the value level. PUnify within propagator computation (e.g., when residuation is wrapped in a Phase 3C propagator) follows the same patterns as type unification.

**Hyperlattice / Hasse**: linear chain Hasse → trivially parallel; no Gray code or hypercube optimizations apply (those are Boolean lattice patterns). Cost-bounded exploration (research §3.6) over multi-quantale composition might exhibit hypercube structure if multiple cost dimensions interact (out of scope).

**Module theoretic**: cells as Q-modules per §4.2; propagators as Q-module morphisms; quantale action of cost on state; cross-quantale Galois bridges via type-cost-bridge.

**Algebraic structure on lattices**: tropical quantale fully declared (Quantale + Integral + Residuated + Commutative); residuation formula `a \ b = b - a when b ≥ a, else 0` per research §9.3; backward error-explanation algebraically grounded (Phase 3C UC1).

---

## §15 Parity test skeleton

Per D.3 §9.1 convention, parity tests wire into `tests/test-elaboration-parity.rkt`. New axes for this addendum:

| Phase | Axis | Tests to enable |
|---|---|---|
| 1A-iii-b | atms-deprecated-api-parity | Behavior identical for non-ATMS-deprecated callers; deprecated callers either migrated or removed |
| 1A-iii-c | surface-atms-ast-elaboration-parity | Pre-retirement: surface forms parse + elaborate + reduce; post-retirement: surface forms produce parse error (correct behavior — no longer exist) |
| 1B | tropical-fuel-merge-parity | Merge semantics + threshold firing + residuation operator (Form A unit tests in test-tropical-fuel.rkt; integration-level parity in test-elaboration-parity.rkt) |
| 1C | tropical-fuel-counter-parity | Old counter exhaustion vs new cell exhaustion at equivalent points for representative workloads (per F-tropical in §13.3) |

---

## §16 Open questions — phase-specific deferred to per-phase mini-design+audit

Per user's workflow direction (2026-04-26): "if there are any remaining open questions that affect the overall addendum design, we should iterate through those; otherwise, we should place the open questions on the phases they touch, and work through them as per-phase mini-design+audit prior to their implementation."

### §16.1 Phase 1A-iii-b (Tier 2 ATMS internal retirement)
- Q-1A-iii-b-1: Test migration vs deletion criteria (D-b-2 + §7.6)
- Q-1A-iii-b-2: pretty-print.rkt `atms?` removal — surface dead code or active state? (D-b-3 + §7.6)

### §16.2 Phase 1A-iii-c (Tier 3 surface ATMS AST retirement)
- Q-1A-iii-c-1: trace-serialize.rkt atms-event:* — retire or preserve for solver-state? (D-c-4 + §8.6)
- Q-1A-iii-c-2: examples/ files using surface ATMS — migrate or delete? (D-c-3 + §8.6)
- Q-1A-iii-c-3: lib/ files using surface ATMS — extent of migration impact (D-c-2 + §8.6)

### §16.3 Phase 1B (tropical fuel primitive)
- Q-1B-1: API naming (lean: `tropical-fuel-merge`/`tropical-fuel-tensor`/`tropical-left-residual`)
- Q-1B-2: `+inf.0` Racket float-infinity vs sentinel `'tropical-top` (lean: `+inf.0`)
- Q-1B-4: Residuation operator implementation — read-time helper vs propagator (lean: read-time helper)

### §16.4 Phase 1C (canonical BSP fuel substrate — hybrid pivot per D.2)
- Q-1C-1 (CARRIED): typing-propagators.rkt:2269 saved-fuel rollback semantics (D-1C-2)
- Q-1C-2 (CARRIED, REFRAMED): test cell-mediated API additions (Phase 3C UC forward-capture)
- **Q-1C-3 (NEW per D.2)**: cell-update cadence — semantic-transition enumeration (start of phase / end of phase / save-restore / Phase 3C UC query sites / on-exhaustion); lean toward semantic-transition-only sync (cell stale between transitions; consumers must accept or trigger sync); resolve at 1C-iii mini-design with code in hand

### §16.5 Cross-cutting (D.1 close + D.2 commits)
- Q-Open-2 ✅ RESOLVED at D.1: A+B+cross-reference capture per §6.5
- Q-Open-3 ✅ RESOLVED at D.1: (β) multi-quantale composition NTT in this addendum per §4.2
- Q-Open-4 ✅ RESOLVED at D.1: γ strict sequencing per pipeline.md template
- Q-A3 ✅ RESOLVED at D.1: γ-bundle-wide per §6.3
- Q-A5 ✅ RESOLVED at D.1: atms-believed retires with struct in 1A-iii-b per §6.4
- Q-1B-3 ✅ RESOLVED at D.1: cell-id 11/12 placement; co-existence as independent Q-modules per §4.3
- Q-1B-5 ✅ RESOLVED at D.1: NTT model completion via quantale-of-bridges per §4.2
- **Q-Hybrid-Pivot ✅ COMMITTED at D.2**: Phase 1C reframed to hybrid architecture per D.2 revision summary + §10 (rewritten); empirical rationale = 8 supporting findings (M-2, M-5, A-11, E-13, E-15, R-16, R-17, R-19) + S-tier baseline finding 20; per user direction "wait until all measurements before committing to a final decision" honored (Pre-0 100% complete; 22 cumulative findings; commit `8a29f6af`)

**No remaining cross-cutting open questions blocking D.2 close.** D.3+ critique rounds (P/R/M/S; especially S for algebra) opens next.

---

## §17 What's next

Per user's workflow:
1. ✅ **D.1 draft complete** (commit `fc4b9d3e`)
2. ✅ **Pre-0 microbenchmark plan + execution** — comprehensive plan (`f79650fa`) + M-tier (`f6576479`/`bef1f518`) + A-tier (`4be5e875`) + capture-gap closure (`d270769b`) + E-tier (`d0934329`) + R-tier (`76129725`) + S-tier (`8a29f6af`); 22 cumulative design-affecting findings
3. ✅ **D.2 revise** (THIS COMMIT) — Pre-0 findings incorporated; hybrid pivot architecture committed for Phase 1C; cross-cutting open questions all RESOLVED
4. ⬜ **D.3+ critique rounds** (NEXT) — P/R/M/S lenses (especially S for algebra; SRE lattice lens load-bearing per CRITIQUE_METHODOLOGY); possibly external critique. Per CRITIQUE_METHODOLOGY § Cataloguing Instead of Challenging: TWO-COLUMN adversarial framing mandatory at every gate. The hybrid pivot decision itself is a candidate for adversarial scrutiny in D.3 (is "decomplection of fast-path optimization from architectural substrate" genuinely principled, or rationalization for incomplete migration?).
5. ✅ **Stage 0 gates verified**: NTT Model Requirement (§4 ✓ multi-quantale completed); Design Mantra Audit (§5 ✓); Pre-0 Benchmarks Per Semantic Axis (§13 ✓ executed; 22 findings); Parity Test Skeleton (§15 ✓; tropical-fuel-counter-parity reframed for hybrid)
6. ⬜ **Stage 4 implementation** — per-phase mini-design+audit before each phase's implementation; phase-specific open questions (§16) resolved at phase mini-design with code in hand
   - Phase 1B substrate ships first (per Q-Open-4 strict sequencing)
   - Phase 1A-iii-b + 1A-iii-c parallelize with 1C
   - Phase 1C consumes 1B substrate (under hybrid: substrate setup + selective non-hot-path migration)
   - Phase 1V atomic close
7. **Phase 1B implementation checklist** captured at D.1 §9.10 (M10 + M12 + R4 + A12 verification)

**D.3 critique opening adversarial questions** (forward-capture for the next session):
- Is the hybrid pivot's decomplection between fast-path optimization and architectural substrate genuinely principled, or does it preserve scaffolding that should retire under the new architecture? (Lens P)
- The struct field `prop-net-cold-fuel` and macro `prop-network-fuel` are PRESERVED under hybrid — is this honest "fast-path needed for performance" or "old mechanism preserved for safety" (workflow.md belt-and-suspenders red flag)? (Lens P)
- Does the hybrid's cell-update-at-semantic-transitions cadence have well-defined, exhaustively-enumerated transitions, or is "semantic transition" ambiguous in practice? (Lens R + Q-1C-3)
- Under hybrid, the cell value can be stale relative to struct-field — does this violate "cell as single source of truth" principle (DESIGN_PRINCIPLES.org § Propagator-First Infrastructure)? (Lens M + S)
- Does the SRE lattice lens analysis (§14.4) hold under hybrid's reduced cell-write rate? (Lens S)

---

## §18 References

### §18.1 Stage 1/2 artifacts (this track)
- [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md)
- This session 2026-04-26 audit findings (Q-Audit-1/2/3) at §2.2

### §18.2 Parent and adjacent design docs
- **[`docs/tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md`](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md) — D.2.SC (P/R/M/S self-critique; 18 findings; 3 BLOCKING + 10 REFINEMENTS + 5 ACKNOWLEDGEs)** — pending resolution review with user; D.3 incorporates accepted findings
- [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — D.3 (parent addendum; refined by this doc per Q-Open-1)
- [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](2026-04-17_PPN_TRACK4C_DESIGN.md) — PPN 4C parent track
- [`docs/tracking/2026-03-22_NTT_SYNTAX_DESIGN.md`](2026-03-22_NTT_SYNTAX_DESIGN.md) — NTT syntax reference for §4
- [`docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`](../research/2026-03-28_MODULE_THEORY_LATTICES.md) — Q-modules + residuation
- [`docs/research/2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md`](../research/2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) — earlier framing
- [`docs/research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md`](../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) — quantales for resources
- [`docs/research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md`](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) — SRE foundations
- [`docs/tracking/2026-04-23_STEP2_BASELINE.md`](2026-04-23_STEP2_BASELINE.md) — measurement discipline + microbench claim verification rule

### §18.3 Cross-references for downstream consumers
- D.3 §6.10 + §9 (Phase 3 union types via ATMS + residuation error explanation) — Phase 3C consumer of tropical residuation operator (Form C cross-reference per §6.5)
- [`docs/research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md`](../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md) — Track 4D vision
- [`docs/tracking/MASTER_ROADMAP.org`](MASTER_ROADMAP.org) § OE Series — first production landing

### §18.4 Methodology and rules
- [`docs/tracking/principles/DESIGN_METHODOLOGY.org`](principles/DESIGN_METHODOLOGY.org) Stage 3 (incl. Lens S)
- [`docs/tracking/principles/DESIGN_PRINCIPLES.org`](principles/DESIGN_PRINCIPLES.org) — Hyperlattice Conjecture; Correct-by-Construction
- [`docs/tracking/principles/CRITIQUE_METHODOLOGY.org`](principles/CRITIQUE_METHODOLOGY.org) — SRE Lattice Lens; adversarial framing
- [`docs/tracking/principles/DEVELOPMENT_LESSONS.org`](principles/DEVELOPMENT_LESSONS.org) — 6 codifications graduated 2026-04-25 (apply prophylactically)
- [`.claude/rules/on-network.md`](../../.claude/rules/on-network.md), [`propagator-design.md`](../../.claude/rules/propagator-design.md), [`structural-thinking.md`](../../.claude/rules/structural-thinking.md), [`pipeline.md`](../../.claude/rules/pipeline.md), [`workflow.md`](../../.claude/rules/workflow.md)

### §18.5 Code references (verified at this session 2026-04-26)
- [`racket/prologos/propagator.rkt`](../../racket/prologos/propagator.rkt) — `make-prop-network` line 81; `prop-net-cold` struct line 337; `prop-network-fuel` macro line 399; 17 production refs per Q-Audit-1
- [`racket/prologos/atms.rkt`](../../racket/prologos/atms.rkt) — 13 deprecated functions lines 213-251+; struct + atms-believed line 159+; provides lines 41-61
- [`racket/prologos/syntax.rkt`](../../racket/prologos/syntax.rkt) — 14 surface ATMS AST structs lines 202-208 + 750-767
- [`racket/prologos/sre-core.rkt`](../../racket/prologos/sre-core.rkt) + [`merge-fn-registry.rkt`](../../racket/prologos/merge-fn-registry.rkt) — SRE registration patterns
- [`racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt`](../../racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt) — 295 lines; M1-M6 + A1-A4 + E1-E6 + V1-V3 tiers; M7-M9 + A5 + F-tropical extensions per §13

---

## Document status

**Stage 3 Design D.2** — Pre-0 findings incorporated; hybrid pivot committed. Per user's workflow direction:
1. ✅ D.1 drafted (commit `fc4b9d3e`)
2. ✅ Pre-0 microbenchmark plan + execution (M+A+E+R+S-tiers; 22 design-affecting findings; commits `f79650fa`, `f6576479`, `bef1f518`, `4be5e875`, `d270769b`, `d0934329`, `76129725`, `8a29f6af`)
3. ✅ **D.2 revise** (this commit) — hybrid pivot architecture committed for Phase 1C; cross-cutting open questions all RESOLVED
4. ⬜ D.3+ critique rounds (P/R/M/S; especially S for algebra; possibly external critique). §17 enumerates 5 forward-captured adversarial questions for D.3 opening.
5. ⬜ Stage 4 implementation per per-phase mini-design+audit. Phase 1B implementation checklist captured at §9.10 (M10 + M12 + R4 + A12 verification).

**Sub-phase mini-design+audit happens BEFORE each phase's implementation per Stage 4 Per-Phase Protocol.** Phase-specific open questions (§16) resolved at that time with code in hand.

**The architectural foundation: tropical quantale as the substrate for OE Series Track 0/1/2 first production landing + future PReduce + future cost-guided search. Phase 3C residuation error explanation as the first downstream consumer (Form C cross-reference scheduled at right phase).**

**The hybrid pivot (D.2 commit): Phase 1C reframes from "replace counter with cell" to "introduce cell substrate alongside preserved counter fast-path." The decomplection of fast-path optimization (struct-copy + inline check; ~30-40 ns) from architectural substrate (cell + threshold propagator; semantic-transition-granular) preserves R3's zero-major-GC property while routing contradiction-on-exhaustion through the propagator network. Empirically grounded across 5 measurement tiers (M+A+E+R+S; 8 supporting findings + S-tier baseline). Subject to D.3 adversarial scrutiny (is decomplection genuinely principled, or scaffolding preservation rationalized?).**
