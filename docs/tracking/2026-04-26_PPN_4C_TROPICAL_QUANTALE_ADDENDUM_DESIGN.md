# PPN Track 4C Tropical Quantale Addendum: Phase 1 Substrate Completion — Design

**Date**: 2026-04-26
**Stage**: 3 — Design per [DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) Stage 3
**Version**: D.1 — first comprehensive draft
**Scope**: PPN 4C Phase 1A-iii-b + 1A-iii-c + 1B + 1C + 1V (γ-bundle-wide; closes Phase 1 entirely)
**Status**: Stage 3 design cycle opening; D.1 draft → Pre-0 microbenchmark → D.2+ critique rounds

**Prior stages** (this track):
- Stage 1 research: [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) (commit `de357aa1`) — depth-first formal grounding; 12 sections, ~1000 lines
- Stage 2 audit: this session 2026-04-26 (audit findings persist into this design at §6, §7, §8, §9, §10)

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

**Phase 1C — Canonical BSP fuel migration** (~250-400 LoC across propagator.rkt + scattered)
- Allocate canonical fuel-cost cell at `cell-id 11` + budget cell at `cell-id 12` in `make-prop-network` (per D.3 §10.3)
- Install threshold propagator at network setup
- Retire `prop-network-fuel` syntax-rule + `prop-net-cold-fuel` field
- Migrate 17 production `propagator.rkt` references (lines per audit Q-Audit-1: 65, 399, 1817, 1824, 1872, 2329, 2366, 2373, 2384, 2875, 2992, 3000, 3045, 3053, 3132, 3135, 3142)
- Migrate 1 typing-propagators.rkt:2269 reference + 1 pretty-print.rkt:463 reference
- Migrate 13 test references across 7 files (mechanical, read-only checks)
- Migrate 2 bench-alloc.rkt references

**Phase 1V — Vision Alignment Gate Phase 1** (closes 1A + 1B + 1C atomically)
- Adversarial TWO-COLUMN VAG (per `9f7c0b82` codification) on all four sub-phases
- Covers 1A-iii-b + 1A-iii-c + 1B + 1C completion
- Closes Phase 1 entirely

**Total estimate**: ~1250-2050 LoC (mix of deletion and new code; net likely deletion-dominant).

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
| Stage 3 | Design doc (this) | 🔄 D.1 | Drafting |
| Pre-0 | Microbenchmark plan execution (M7-M9 + A5 + F-tropical extensions to bench-ppn-track4c.rkt) | ⬜ | Per §13 |
| **1A-iii-b** | Tier 2 deprecated ATMS internal API retirement | ⬜ | Per §7 |
| **1A-iii-c** | Tier 3 surface ATMS AST 14-file pipeline retirement | ⬜ | Per §8 |
| **1B** | Tropical fuel primitive + SRE registration | ⬜ | Per §9 |
| **1C** | Canonical BSP fuel migration | ⬜ | Per §10 |
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
| **Future PReduce series** | Inherits tropical quantale primitive for cost-guided rewriting / e-graph extraction | First production landing establishes pattern |
| **OE Series** | This addendum is OE Track 0/1/2's first production landing | Per MASTER_ROADMAP.org § OE; formalization decision deferred |
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

---

## §10 Phase 1C — Canonical BSP fuel migration

### §10.1 Scope and rationale

Replace the imperative `(fuel 1000000)` decrementing counter with the on-network tropical fuel cell. Allocate canonical cells at well-known IDs (cell-id 11/12 per §4.3). Migrate 17 production refs + 13 test refs + 2 bench refs.

### §10.2 Audit-grounded migration plan (Q-Audit-1 findings)

**Allocation in `make-prop-network`** (refined from D.3 §10.3):
```racket
(define (make-prop-network [fuel 1000000])
  ;; ... existing allocations (cell-ids 0-10) ...
  
  ;; NEW: Phase 1C — canonical tropical fuel cells
  (define-values (net1 fuel-cid) (net-new-tropical-fuel-cell base-net))
  ;; (verify cell-id allocated as 11 — well-known position)
  
  (define-values (net2 budget-cid) (net-new-tropical-budget-cell net1 fuel))
  ;; (verify cell-id allocated as 12)
  
  ;; Install threshold propagator
  (define threshold-prop (make-tropical-fuel-threshold-propagator fuel-cid budget-cid))
  (net-add-propagator net2 (list fuel-cid budget-cid) '() threshold-prop)
  ;; ...
)
```

**Export well-known cell-ids**: `fuel-cost-cell-id = 11`, `fuel-budget-cell-id = 12` per §4.3.

### §10.3 Per-site migration patterns (refined from D.3 §10.4)

**Decrement sites** (4 sites: propagator.rkt:2384, 3000, 3053; potentially 1 more in widening path):

```racket
;; BEFORE
(struct-copy prop-net-cold ... [fuel (- (prop-network-fuel net) n)])

;; AFTER
(net-cell-write net fuel-cost-cell-id
                (+ (net-cell-read net fuel-cost-cell-id) n))
;; The min-merge ensures monotone accumulation; threshold prop watches for exhaustion
```

**Check sites** (11 sites: `<= 0` patterns at 1817, 2366, 2373, 2992, 3045, 3132, 3135, 3142 + `> 0` at 2329):

```racket
;; BEFORE
[(<= (prop-network-fuel net) 0) net]

;; AFTER
[(net-contradiction? net) net]
;; The threshold propagator writes contradiction when cost >= budget
```

**Read-as-value sites** (3 sites: 1824, 1872, 2875):
```racket
;; BEFORE
(define remaining-fuel (box (prop-network-fuel net)))

;; AFTER
;; Reading the fuel-cost cell directly:
(define current-cost (net-cell-read net fuel-cost-cell-id))
(define current-budget (net-cell-read net fuel-cost-cell-id))
(define remaining-fuel (box (- current-budget current-cost)))
;; OR: use tropical-left-residual:
(define remaining-fuel (box (tropical-left-residual current-cost current-budget)))
```

**Macro definition retirement** (propagator.rkt:399):
```racket
;; RETIRE: (define-syntax-rule (prop-network-fuel net) ...)
;; Replace with cell-read at all call sites
```

**Field retirement** (propagator.rkt:337 prop-net-cold struct):
- Remove `fuel` field from prop-net-cold struct
- All callers updated to use cell-read
- Verify struct-copy callers don't reference fuel field

**typing-propagators.rkt:2269** (saved-fuel restoration):
```racket
;; BEFORE
(define saved-fuel (prop-network-fuel net2w))
;; (later restore)

;; AFTER
(define saved-fuel-cost (net-cell-read net2w fuel-cost-cell-id))
;; (later: net-cell-write to restore — but actually this is rollback territory;
;;  may be handled by elab-net snapshot mechanism — verify at impl time)
```

**pretty-print.rkt:463** (display):
```racket
;; BEFORE
[(expr-prop-network v) (format "#<prop-network ~a>" (prop-network-fuel v))]

;; AFTER
[(expr-prop-network v) (format "#<prop-network cost=~a budget=~a>"
                                (net-cell-read v fuel-cost-cell-id)
                                (net-cell-read v fuel-budget-cell-id))]
```

**Test migrations** (13 sites, 7 files — mechanical):
- `(prop-network-fuel net)` → `(net-cell-read net fuel-cost-cell-id)` for cost reads
- `(- old-fuel new-fuel)` → cost difference reads
- `(check-equal? (prop-network-fuel result) 0)` → `(check-equal? (net-cell-read result fuel-cost-cell-id) initial-budget)` (NB: semantics shift — measuring accumulated cost vs remaining fuel)

**Bench migrations** (2 sites in bench-alloc.rkt):
- Same mechanical pattern as test migrations

### §10.4 Sub-phase plan

- **1C-i** — Pre-implementation audit (mini-audit): confirm 17 production sites + 13 test sites + 2 bench sites; verify migration patterns hold; identify any test semantic shifts (cost-accumulation vs remaining-fuel)
- **1C-ii** — Allocate canonical cells in `make-prop-network`; install threshold propagator; reserved cell-id 11/12 verified
- **1C-iii** — Migrate decrement sites (4 sites); verify probe + targeted suite
- **1C-iv** — Migrate check sites (11 sites); verify
- **1C-v** — Migrate read-as-value sites (3 sites); migrate typing-propagators saved-fuel; migrate pretty-print
- **1C-vi** — Retire `prop-network-fuel` macro + `prop-net-cold-fuel` field
- **1C-vii** — Migrate test sites (13 sites, 7 files) — batch mechanical
- **1C-viii** — Migrate bench sites (2 sites)
- **1C-ix** — Verification + close: probe + targeted suite + full suite + parity test (tropical-fuel-parity axis: old counter vs new cell exhaustion equivalent for representative workloads)

### §10.5 Drift risks

- **D-1C-1**: Cost-accumulation vs remaining-fuel semantic shift in tests — `(prop-network-fuel net) → 0` was "fuel exhausted"; under new semantics, `(net-cell-read net fuel-cost-cell-id)` IS the accumulated cost, not remaining. Tests need careful migration.
- **D-1C-2**: typing-propagators saved-fuel rollback — verify whether elab-net snapshot handles this or if explicit restore needed
- **D-1C-3**: Cell-id 11/12 conflicts — verify no other phase has reserved these IDs
- **D-1C-4**: Threshold propagator firing semantics under speculation — verify with test-speculation-bridge
- **D-1C-5**: `prop-network-fuel` macro retirement may surface stale usages not caught by grep

### §10.6 Termination + parity

- Termination: Phase 1C migration is structural (cell-write replaces field-update); finite migration sites; trivially terminates
- Parity: tropical-fuel-parity axis (per D.3 §7.11): for representative workloads, old counter and new cell exhaustion fire at equivalent points (allowing for the cost-vs-remaining semantic flip)

### §10.7 Open questions (deferred to per-phase mini-design+audit)

- **Q-1C-1**: typing-propagators saved-fuel rollback semantics — verify at 1C-v mini-audit
- **Q-1C-2**: Test cost-accumulation semantic shift — confirm how each test should migrate (D-1C-1)

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
- Catalogue: 1A-iii-b retirement complete (13 functions + struct + atms-believed); 1A-iii-c retirement complete (14-file pipeline); 1B primitive shipped + tested; 1C migration complete
- Challenge: did Pre-0 microbenchmark perf claims land? Re-microbench at close per microbench-claim verification rule. Did any quantale property declarations remain speculative (capture-gap risk)?

**Question (c) Vision-advancing?**
- Catalogue: first optimization-quantale instantiation in production; tropical fuel substrate; multi-quantale composition NTT; Phase 3C cross-reference capture
- Challenge: is the residuation operator load-bearing (Form A test passes) or speculative? Does the multi-quantale NTT actually compose with TypeFacet quantale, or is it parallel co-existence only? Is OE Series Track 0/1/2 first landing recognized?

**Question (d) Drift-risks-cleared?**
- Catalogue: drift risks named per §7.4, §8.4, §9.8, §10.5 all addressed
- Challenge: did the named risks cover both correctness AND perf-vs-design-target axes? Were any inherited patterns (deprecated APIs, surface AST scaffolding) preserved without challenge?

### §11.3 Phase 1V exit criteria

- All 4 VAG questions pass under adversarial framing
- Probe diff = 0 semantically vs pre-Phase-1 baseline
- Full suite GREEN within 118-127s variance band
- Pre-0 microbench claims verified (M7-M9 + A5 + F-tropical)
- Parity tests GREEN (tropical-fuel-parity + 1A-iii-b parity + 1A-iii-c parity)
- 1+ codifications graduated to DEVELOPMENT_LESSONS.org if patterns surfaced
- Cross-reference capture in D.3 Phase 3 design verified (Form C scheduled)

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

**SRE lattice lens (mandatory)** per CRITIQUE_METHODOLOGY:

| Aspect | Tropical fuel quantale (this addendum) |
|---|---|
| **Q1 Classification** | VALUE lattice (atomic extended-real) |
| **Q2 Algebraic properties** | Quantale + Commutative + Unital + Integral + Residuated; Heyting-like (residuation provides pseudo-complement-like structure); join-semilattice (idempotent min); CALM-safe |
| **Q3 Bridges** | Future Galois bridge to TypeFacetQ (§4.2 type-cost-bridge); future bridges to MemoryCostQ, MessageCountQ (out of scope); composition via quantale-of-bridges |
| **Q4 Composition** | Two quantales co-exist as Q-modules; CALM-safe under monotone joins; Tarski-fixpoint per Q-module |
| **Q5 Primary/Derived** | PRIMARY for fuel-cost tracking; cells over the quantale are PRIMARY storage |
| **Q6 Hasse diagram** | Linear chain `0 ≤_rev 1 ≤_rev 2 ≤_rev ... ≤_rev +∞` (totally ordered); compute topology: trivially parallel (no decomposition needed for atomic values) |

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

### §16.4 Phase 1C (canonical BSP fuel migration)
- Q-1C-1: typing-propagators.rkt:2269 saved-fuel rollback semantics (D-1C-2)
- Q-1C-2: Test cost-accumulation semantic shift handling (D-1C-1)

### §16.5 Cross-cutting (potentially affect overall addendum design — RESOLVE before D.1 closes)
- Q-Open-2 ✅ RESOLVED: A+B+cross-reference capture per §6.5
- Q-Open-3 ✅ RESOLVED: (β) multi-quantale composition NTT in this addendum per §4.2
- Q-Open-4 ✅ RESOLVED: γ strict sequencing per pipeline.md template
- Q-A3 ✅ RESOLVED: γ-bundle-wide per §6.3
- Q-A5 ✅ RESOLVED: atms-believed retires with struct in 1A-iii-b per §6.4
- Q-1B-3 (multi-quantale composition design — where do tropical fuel cells live alongside type universe cells): RESOLVED per §4.3 (cell-id 11/12; co-existence as independent Q-modules)
- Q-1B-5 (NTT model completion for multi-quantale composition): RESOLVED per §4.2 (multi-quantale composition NTT model + quantale-of-bridges; quantaloids out of scope per §1.3)

**No remaining cross-cutting open questions blocking D.1 close.**

---

## §17 What's next

Per user's workflow:
1. **D.1 draft complete** (this document)
2. **Pre-0 microbenchmark plan** — extend bench-ppn-track4c.rkt with M7-M9 + A5 + F-tropical per §13; run pre-implementation baselines
3. **D.2 revise** — incorporate Pre-0 findings
4. **D.3+ critique rounds** — P/R/M/S lenses (especially S for algebra); possibly external critique
5. **Stage 0 gates verified**: NTT Model Requirement (§4 ✓ multi-quantale completed); Design Mantra Audit (§5 ✓); Pre-0 Benchmarks Per Semantic Axis (§13 ✓ planned); Parity Test Skeleton (§15 ✓)
6. **Stage 4 implementation** — per-phase mini-design+audit before each phase's implementation; phase-specific open questions (§16) resolved at phase mini-design

---

## §18 References

### §18.1 Stage 1/2 artifacts (this track)
- [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md)
- This session 2026-04-26 audit findings (Q-Audit-1/2/3) at §2.2

### §18.2 Parent and adjacent design docs
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

**Stage 3 Design D.1** — comprehensive first draft. Per user's workflow direction:
1. ✅ D.1 drafted (this document)
2. ⬜ Pre-0 microbenchmark plan execution (§13)
3. ⬜ D.2 revise with Pre-0 findings
4. ⬜ D.3+ critique rounds (P/R/M/S; especially S for algebra)
5. ⬜ Stage 4 implementation per per-phase mini-design+audit

**Sub-phase mini-design+audit happens BEFORE each phase's implementation per Stage 4 Per-Phase Protocol.** Phase-specific open questions (§16) resolved at that time with code in hand.

**The architectural foundation: tropical quantale as the substrate for OE Series Track 0/1/2 first production landing + future PReduce + future cost-guided search. Phase 3C residuation error explanation as the first downstream consumer (Form C cross-reference scheduled at right phase).**
