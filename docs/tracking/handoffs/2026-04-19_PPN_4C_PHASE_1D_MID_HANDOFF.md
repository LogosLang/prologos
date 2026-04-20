# PPN Track 4C — Phase 1d Mid-Campaign Handoff

**Date**: 2026-04-19
**Purpose**: Transfer the hard-earned context from this session (Phase 0 closure through Phase 1d-B) into a continuation session. Phase 1 is substantially complete; remaining work is Phase 1d triage + Phase 1e correctness refactors + Phase 1f enforcement + Phase 1V gate.

**Before reading anything else**: read [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org) carefully. This handoff is structured per that protocol. The Hot-Load Reading Protocol requires reading EVERY §2 document IN FULL before summarizing understanding back to the user.

---

## §1 Current Work State (PRECISE)

- **Track**: PPN Track 4C — "Bring elaboration completely on-network."
- **Design version**: **D.3** (external critique round closed 2026-04-18; Phase 1d/1e un-fold added 2026-04-19). All 17 external critique findings resolved.
- **Last commit**: `6ce7a50d` — "PPN 4C Phase 1d-B: per-subsystem merge fn SRE registrations"
- **Branch**: `main`
- **Suite state**: 4443 affected-tests GREEN, 109.2s (no regression). Acceptance file clean via `process-file`.
- **Lint state**: 35 sites registered / 49 sites unregistered (24 → 23 unique) / 1 inline-lambda / 5 parameterized-passthrough (called "ambiguous-name" in tool) / 1 domain-override / 11 multi-line. `--strict` exits 0 (no new unregistered beyond baseline).

### Progress Tracker status (§2 of design doc)

| Phase | Status | Notes |
|---|---|---|
| 0 | ✅ | Acceptance + Pre-0 + parity skeleton |
| 1a | ✅ | `tools/lint-cells.rkt` + baseline (commit `eb4b7bd8`) |
| 1b | ✅ | `merge-fn-registry.rkt` Tier 2 API (commit `f990ddd7`) |
| 1c | ✅ | `#:domain` kwarg + Tier 3 inheritance (commit `827637c2`) |
| **1.5** | ✅ | **srcloc infrastructure** (commit `793e106d`) |
| **2** | ✅ | **4 facet SRE registrations** (commit `1423259d`) |
| **2b** | ✅ | **Hasse-registry primitive** (commit `c669db51`) |
| **1d-A** | ✅ | **infra-cell generic merges** (commit `f9345fd6`) |
| **1d-B** | ✅ | **per-subsystem merges** (commit `6ce7a50d`) |
| **1d-C** | ⬜ | inline lambda rewrite at `typing-propagators.rkt:1887` |
| **1d-D** | ⬜ | 11 multi-line site inspection + classification |
| **1d-E** | ⬜ | lint tool "ambiguous-name" → "parameterized-passthrough" |
| **1d-F** | ⬜ | trace remaining 23 unique unregistered merge fns |
| **1d-close** | ⬜ | re-baseline lint; goal `--strict` exits 0 with empty baseline |
| **1e** | ⬜ | **correctness refactors** (η split + replace-cell audit) — NEW phase, not deferred to DEFERRED.md |
| **1f** | ⬜ | structural enforcement + hard-error flip |
| **1V** | ⬜ | Vision Alignment Gate |
| 3-12, 11b, T, V | ⬜ | unchanged from prior handoff |

### Next immediate task

**Complete Phase 1d remainder**, in order:

1. **1d-C**: rewrite the 1 inline lambda at `typing-propagators.rkt:1887` — `(lambda (old new) (append old new))` → use registered `merge-list-append`
2. **1d-D**: inspect 11 multi-line sites (atms.rkt:761,478,473; bilattice.rkt:102,97; parser.rkt:2422,2412; propagator.rkt:1467; relations.rkt:305; tabling.rkt:211,110) and classify each (most will use already-registered merge fns)
3. **1d-E**: update `tools/lint-cells.rkt` — rename "ambiguous-name" category to "parameterized-passthrough" for clarity (D3 resolution 2026-04-19)
4. **1d-F**: trace remaining 23 unique unregistered names — probably inline-defined, ungrepped, or otherwise edge cases
5. **1d-close**: `--save-baseline`; verify `--strict` exits 0; update dailies + Progress Tracker

After 1d close: Phase 1e (correctness refactors), Phase 1f (enforcement), Phase 1V (gate), then Phase 3+.

---

## §2 Documents to Hot-Load (ORDERED)

**CRITICAL**: the Hot-Load Reading Protocol requires reading EVERY document in §2 IN FULL. Sampling 40 lines and saying "I have full context" is not acceptable. If any document is unclear, ASK before proceeding.

### §2.0 Start here

0. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org) — THIS protocol. Read first to ground the reading discipline.

### §2.1 Always-Load (every session, per HANDOFF_PROTOCOL §2a)

1. [`CLAUDE.md`](../../../CLAUDE.md) + [`CLAUDE.local.md`](../../../CLAUDE.local.md) — project + local instructions
2. [`MEMORY.md`](../../../MEMORY.md) — auto-memory index
3. [`DESIGN_METHODOLOGY.org`](../principles/DESIGN_METHODOLOGY.org) — 5 stages + Implementation Protocol. **UPDATED THIS SESSION**: step 1 "Mini-design audit" added (commit `3beeb3ae`); existing steps 1-5 renumbered to 2-6. Step 5d "Drift-risks-cleared?" also added to Vision Alignment Gate.
4. [`DESIGN_PRINCIPLES.org`](../principles/DESIGN_PRINCIPLES.org) — 10 principles + Hyperlattice Conjecture
5. [`CRITIQUE_METHODOLOGY.org`](../principles/CRITIQUE_METHODOLOGY.org) — three lenses (P/R/M) + SRE lattice lens

### §2.2 Architectural Rules (automatically loaded via `.claude/rules/` but MUST be internalized)

6. [`.claude/rules/propagator-design.md`](../../../.claude/rules/propagator-design.md) — fire-once, broadcast, `#:component-paths`
7. [`.claude/rules/on-network.md`](../../../.claude/rules/on-network.md) — self-hosting mandate. **THE DESIGN MANTRA lives here.**
8. [`.claude/rules/structural-thinking.md`](../../../.claude/rules/structural-thinking.md) — SRE 6 questions + Module Theory § "Direct Sum Has Two Realizations" (critical for Hasse-registry pattern match)
9. [`.claude/rules/testing.md`](../../../.claude/rules/testing.md) — diagnostic protocol; TRIGGER-level intervention
10. [`.claude/rules/pipeline.md`](../../../.claude/rules/pipeline.md) — exhaustiveness checklists + Two-Context Audit
11. [`.claude/rules/stratification.md`](../../../.claude/rules/stratification.md) — stratum infrastructure
12. [`.claude/rules/prologos-syntax.md`](../../../.claude/rules/prologos-syntax.md) — WS syntax conventions
13. [`.claude/rules/workflow.md`](../../../.claude/rules/workflow.md) — operational discipline (phase completion, commit discipline, registries tracking)

### §2.3 Session-Specific — THE D.3 DESIGN (READ IN FULL)

14. [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md) — **THE D.3 design. Read in full.** Key sections updated THIS session:
    - §2 Progress Tracker (new Phase 1.5, 2b, 1d, 1e, 1f, 1V rows; all completed phases ✅)
    - §6.1.1 — Phase 11b architectural shape (read-time derivation) + trace monoidal category research input
    - §6.5.1 — `:constraints` tag distributivity (Phase 2 artifact)
    - §6.9 — Phase 2 mini-audit findings + per-facet merge fn table
    - §6.9.1 — Phase 1.5 srcloc infrastructure scope
    - §6.9.2 — per-facet D2 framework table (aspirational/declared/inference/delta)
    - §6.12 — Hasse-registry primitive, refined 2026-04-19 (SRE+PUnify integration, emergent filter-based lookup, prior-art alignment)
    - §6.12.6 — L_impl / L_inhabitant concrete instantiations
    - §17 — Reality-Check Artifacts appendix (grep commands)
    - Phase 1 work list (items 1-10) shows all completed + remaining sub-phases

15. [`docs/tracking/2026-04-18_PPN_TRACK4C_EXTERNAL_CRITIQUE.md`](../2026-04-18_PPN_TRACK4C_EXTERNAL_CRITIQUE.md) — external critique (closed; 17 findings resolved)

16. [`docs/tracking/2026-04-17_PPN_TRACK4C_SELF_CRITIQUE.md`](../2026-04-17_PPN_TRACK4C_SELF_CRITIQUE.md) — self-critique (closed; round summary at §8)

17. [`docs/tracking/2026-04-17_PPN_TRACK4C_AUDIT.md`](../2026-04-17_PPN_TRACK4C_AUDIT.md) — Stage 2 audit

18. [`docs/tracking/2026-04-17_PPN_TRACK4C_PRE0_REPORT.md`](../2026-04-17_PPN_TRACK4C_PRE0_REPORT.md) — Pre-0 findings

### §2.4 Session-Specific — PRIOR HANDOFF (context continuity)

19. [`docs/tracking/handoffs/2026-04-18_PPN_4C_D2_EXTERNAL_CRITIQUE_HANDOFF.md`](2026-04-18_PPN_4C_D2_EXTERNAL_CRITIQUE_HANDOFF.md) — handoff that STARTED this session. Critical for continuity; reference for all design decisions pre-this-session.

### §2.5 Session-Specific — CURRENT DAILIES

20. [`docs/tracking/standups/2026-04-19_dailies.md`](../standups/2026-04-19_dailies.md) — extensive session log: Phase 0 closure, Stage 4 methodology codification, Phase 1 mini-design audit, Phase 1a-c / 1.5 / 2 / 2b / 1d-A-B implementations with drift-risks status

### §2.6 Session-Specific — PPN LINEAGE

21. [`docs/tracking/2026-03-26_PPN_MASTER.md`](../2026-03-26_PPN_MASTER.md) — series tracker. §4 has 7 cross-cutting lessons from BSP-LE 2B.

22. [`docs/tracking/2026-04-04_PPN_TRACK4_PIR.md`](../2026-04-04_PPN_TRACK4_PIR.md) — Track 4 PIR; §3.4b on zonk retirement (unmet, now owned by 4C Phase 12)

23. [`docs/tracking/2026-04-07_PPN_TRACK4B_PIR.md`](../2026-04-07_PPN_TRACK4B_PIR.md) — Track 4B PIR; §12 notes zonk retirement still deferred; §1 "side effects ARE attributes"

24. [`docs/tracking/2026-04-16_BSP_LE_TRACK2B_PIR.md`](../2026-04-16_BSP_LE_TRACK2B_PIR.md) — BSP-LE 2B PIR. §16.4 Module Theory Resolution B; §16.5 skip-the-mechanism; §16.8 per-variable split entries

### §2.7 Session-Specific — RESEARCH (cited by D.3)

25. [`docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`](../../research/2026-03-28_MODULE_THEORY_LATTICES.md) — **Critical for O3, Hasse-registry, and understanding Realization B everywhere**

26. [`docs/research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md`](../../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — §6.3 "dependency graph IS a proof object"

27. [`docs/research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md`](../../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) — DPO, critical-pair completeness (impl coherence)

28. [`docs/research/2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md`](../../research/2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md)

29. [`docs/research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md`](../../research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md)

30. [`docs/tracking/2026-03-22_NTT_SYNTAX_DESIGN.md`](../2026-03-22_NTT_SYNTAX_DESIGN.md) — NTT guiderails. §7.6 `:trace` modes (Phase 11b)

31. [`docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`](../../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — **CRITICAL for Hasse-registry (Phase 2b) context**. Q_n hypercube, Gray-code, subcube pruning via bitmask.

32. [`docs/research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md`](../../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md) — BSP-LE 1.5 → Phase 9

33. [`docs/research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md`](../../research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md) — `grammar` form vision

34. [`docs/research/2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md`](../../research/2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md) — self-hosting trajectory

### §2.8 Session-Specific — INFRASTRUCTURE ARTIFACTS (built this session)

35. [`racket/prologos/merge-fn-registry.rkt`](../../../racket/prologos/merge-fn-registry.rkt) — **Phase 1b**. Tier 2 API: `register-merge-fn!/lattice` + `lookup-merge-fn-domain`. Independent reverse-lookup registry per D.3 §6.8 option (a).

36. [`racket/prologos/hasse-registry.rkt`](../../../racket/prologos/hasse-registry.rkt) — **Phase 2b**. Thin wrapper on infra-cell + SRE+PUnify. Emergent filter-based lookup. Handle struct = cell-id + l-domain-name + position-fn + subsume-fn. See test file for bitmask-override Q_n pattern.

37. [`racket/prologos/infra-cell-sre-registrations.rkt`](../../../racket/prologos/infra-cell-sre-registrations.rkt) — **Phase 1d-A**. Breaks cycle `infra-cell → sre-core → ... → namespace → infra-cell`. Registrations for 7 infra-cell generic merge fns.

38. [`racket/prologos/phase1d-registrations.rkt`](../../../racket/prologos/phase1d-registrations.rkt) — **Phase 1d-B**. Bulk registrations for 17 per-subsystem merge fns + type-lattice-merge Tier 2 link.

39. [`racket/prologos/tools/lint-cells.rkt`](../../../racket/prologos/tools/lint-cells.rkt) — Phase 1a. Classifies cell-creation sites. `--strict` / `--save-baseline` / `--verbose`.

40. [`racket/prologos/tools/cell-lint-baseline.txt`](../../../racket/prologos/tools/cell-lint-baseline.txt) — Phase 1a baseline. SHRINKS as 1d progresses. Goal: empty.

41. [`racket/prologos/source-location.rkt`](../../../racket/prologos/source-location.rkt) — **Phase 1.5**. `current-source-loc` parameter (DERIVED from on-network state, NOT captured closure).

42. [`racket/prologos/surface-syntax.rkt`](../../../racket/prologos/surface-syntax.rkt) — Phase 1.5. `surf-node-srcloc` generic extractor via `struct->vector` (srcloc is last field in 360+ `#:transparent` surf-* structs).

43. [`racket/prologos/propagator.rkt`](../../../racket/prologos/propagator.rkt) — Phase 1c + 1.5 additions: `cell-domains` CHAMP on prop-net-cold; propagator srcloc field; `fire-propagator` wrapper; `net-add-propagator` `#:srcloc` kwarg.

### §2.9 Session-Specific — PARITY + TEST FILES

44. [`racket/prologos/tests/test-elaboration-parity.rkt`](../../../racket/prologos/tests/test-elaboration-parity.rkt) — parity skeleton committed as D.3 design artifact
45. [`racket/prologos/tests/test-merge-fn-registry.rkt`](../../../racket/prologos/tests/test-merge-fn-registry.rkt) — 8/8 GREEN
46. [`racket/prologos/tests/test-cell-domain-inheritance.rkt`](../../../racket/prologos/tests/test-cell-domain-inheritance.rkt) — 10/10 GREEN
47. [`racket/prologos/tests/test-source-loc-infrastructure.rkt`](../../../racket/prologos/tests/test-source-loc-infrastructure.rkt) — 12/12 GREEN
48. [`racket/prologos/tests/test-facet-sre-registration.rkt`](../../../racket/prologos/tests/test-facet-sre-registration.rkt) — 21/21 GREEN (with D2 inference-based findings)
49. [`racket/prologos/tests/test-hasse-registry.rkt`](../../../racket/prologos/tests/test-hasse-registry.rkt) — 14/14 GREEN (includes bitmask-override Q_n test)

### §2.10 Session-Specific — ACCEPTANCE + BENCH

50. [`racket/prologos/examples/2026-04-17-ppn-track4c.prologos`](../../../racket/prologos/examples/2026-04-17-ppn-track4c.prologos) — Phase 0 acceptance file. Broad pipeline exercise. Run BEFORE and AFTER each phase.
51. [`racket/prologos/examples/2026-04-17-ppn-track4c-adversarial.prologos`](../../../racket/prologos/examples/2026-04-17-ppn-track4c-adversarial.prologos) — adversarial per-axis stress
52. [`racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt`](../../../racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt) — Pre-0 bench

### §2.11 Tracking metadata

53. [`docs/tracking/DEFERRED.md`](../DEFERRED.md) — **UPDATED THIS SESSION** with scaffolding registry tracking (PM Track 12 consolidation input):
    - Tier 2 merge-fn registry
    - `current-source-loc` parameter
    - `hasse-registry-handle` Racket struct

54. [`docs/tracking/2026-03-21_BSP_LE_MASTER.md`](../2026-03-21_BSP_LE_MASTER.md) — BSP-LE Master (Track 6 "General Residual Solver" forward reference)

---

## §3 Key Design Decisions (RATIONALE — do NOT re-litigate)

Decisions this session has CLOSED. Revisiting wastes the work that settled them. If a genuine reason to re-open appears, document it explicitly.

### §3.1 Stage 4 Methodology update — Mini-design audit codified

Before any phase's codebase audit or code, **step 1 is the mini-design audit**: re-read design reference for this phase; name obligations carried; name principles in play; run mantra check; enumerate drift risks. Output = "Phase N design target" note in dailies. Existing steps renumbered 2-6. Step 5d "Drift-risks-cleared?" added to Vision Alignment Gate.

**Commit**: `3beeb3ae`. **Practice proven** across 8 phases this session.

### §3.2 Phase ordering — Phase 2 + 2b pulled forward of 1d-f

Original plan: 1d-f before Phase 2. Pulled Phase 2 forward because 1d needs Tier 1 domains to register merge fns AGAINST; then Phase 2b forward because Phase 7/9b both use Hasse-registry.

**Current ordering**: 1a-c ✅ → 1.5 ✅ → 2 ✅ → 2b ✅ → 1d (in progress) → 1e → 1f → 1V → 3+.

**Rejected**: stub domains in Phase 1d; wholesale Phase 2 later.

### §3.3 Phase 1b Tier 2 API — option (a) independent reverse-lookup registry

`register-merge-fn!/lattice` uses a separate module-level `(make-hasheq)` keyed by merge-fn identity (eq?). Independent of SRE's existing `domain-registry`. Smaller blast radius, cleaner Phase 1 boundary. PM Track 12 consolidates eventually.

**Rejected**: option (b) extend SRE domain semantics (couples Phase 1 to Tier 1 bidirectionally).

### §3.4 Phase 1c Tier 3 storage — option (β) parallel CHAMP on prop-net-cold

New `cell-domains` field on `prop-net-cold` struct. 0 external `struct-copy propagator` sites (propagators immutable after install). 1 positional constructor updated. `struct-copy prop-net-cold` sites preserved via field-preservation.

**Rejected**: (α) field on `prop-cell` (heavy hot-path cost), (γ) pair merge-fn with domain in `merge-fns` CHAMP (breaks every reader), (δ) off-network side-table (scaffolding), (ε) pure derivation (can't distinguish override from inherited).

### §3.5 Phase 1.5 srcloc — (α)+(η) hybrid; parameter DERIVED from on-network state

`current-source-loc` Racket parameter as read convenience; UNDERLYING DATA is on-network:
- Propagator struct srcloc field (part of prop-network.cold.propagators CHAMP)
- Surf-node srcloc fields (structural AST data)

Fire functions stay STATELESS — `fire-propagator` wrapper parameterizes `current-source-loc` from propagator's srcloc field.

**Rejected**: (ε) closure-capture at propagator install time (user caught — `on-network.md` § Propagator Statelessness antipattern).

### §3.6 Phase 2 — atomic Tier 1 + Tier 2 per facet; D2 framework as commit artifact

Q7 resolved: each facet registration includes BOTH Tier 1 (SRE domain) and Tier 2 (`register-merge-fn!/lattice`) together. Completeness — "facet is registered" means fully.

D2 framework (aspirational / declared / inference / delta) shipped per facet as commit artifact.

**Phase 2 findings** (per §6.9.2 table):
- `:context` non-commutative — **accepted** as quantale-like monoidal (binding-stack scope semantics)
- `:usage` non-idempotent — **accepted** as commutative MONOID (QTT semiring addition, not join-semilattice); 1 real finding within R5 K=2
- `:constraints` + `:type` no delta
- `:warnings` comm+idem refuted — **scoped to Phase 5** (srcloc struct field + merge-set-union switch; D1 resolution)

### §3.7 Phase 2b Hasse-registry — emergent filter-based, SRE+PUnify integration, NOT DAG traversal

Critical user-pushback corrections landed here:

1. **Reframed from "DAG + traversal" to filter-based** — traversal was step-think; prior art across 10+ files (tagged-cell-value + ATMS bitmask subcube + filter-dependents-by-paths) establishes filter-based pattern
2. **Hasse-registry is GENERALIZATION of existing practice**, not first implementation
3. **Default subsume-fn via PUnify + SRE** — `unify-core` with L's `'subtype` relation; consumer-provided subsume-fn carries the L domain reference
4. **Specialized lattices override subsume-fn** — e.g., Q_n bitmask (demonstrated in test file)
5. **Cell value**: `hash` (equal?-based), NOT `hasheq` — positions are structured values (pairs, types); added `hasse-merge-hash-union` as local equal?-based variant
6. **Antichain direction**: remove `p` if `q` strictly NARROWER (more specific) also subsumes query

**Rejected**: my own earlier proposal of materialized DAG edges + transitive reduction (step-think).

### §3.8 Phase 1d/1e un-folded; D1/D2/D3 resolutions

**Earlier fold** (1d + 1e) was **un-folded** 2026-04-19 after design dialogue revealed correctness refactors as a distinct category of work.

**D1** (merge-hasheq-union strategy): **δ approach** — register under `'monotone-registry` with honest D2 delta documenting non-commutative mechanics + commutative-by-intent gap. η split (identity + replace variants) scoped to **Phase 1e**, not DEFERRED.md.

**D2** (merge-last-write-wins / merge-replace): **NOT DEFERRED** to DEFERRED.md. Scoped to Phase 1e as "replace-cell audit." Per-site refactor paths:
- (1) timestamp-ordered lattice (commutative+assoc+idem upgrade; may warrant timestamped-cell primitive analogous to Hasse-registry)
- (2) identity-or-error flat lattice (contradiction on conflict)
- (3) accept as non-lattice with documented rationale

**D3** (ambiguous parameterized-passthrough sites): **LEAVE AS-IS**. Runtime Tier 3 inheritance via `lookup-merge-fn-domain` is CORRECT at these sites. Forcing `#:domain` override would OVERRIDE inheritance (cure worse than disease). Lint tool category rename only (Phase 1d-E).

### §3.9 Scaffolding registry discipline established

Every new off-network registry added this session tracked in DEFERRED.md with:
- API family / shape
- Lifecycle (when written, when read, per-command reset)
- Retirement plan (usually PM Track 12)

PM Track 12 opens with this list in hand.

### §3.10 Cycle-breaking via dedicated registration modules

Pattern established: when `register-domain!` + `register-merge-fn!/lattice` cannot be called inline (module import cycle), use a dedicated `*-sre-registrations.rkt` module imported by `driver.rkt` for side-effect registration.

Already used for Phase 1d-A (`infra-cell-sre-registrations.rkt`) and Phase 1d-B (`phase1d-registrations.rkt`).

### §3.11 (Prior decisions from D.2/D.3 external critique — STILL VALID)

All decisions from [`2026-04-18_PPN_4C_D2_EXTERNAL_CRITIQUE_HANDOFF.md`](2026-04-18_PPN_4C_D2_EXTERNAL_CRITIQUE_HANDOFF.md) §3 REMAIN BINDING:

- Thesis, 9 axes, `:type`/`:term` tag-layers, Tier 1/2/3, zonk retirement, union types via ATMS, per-(meta, trait) propagators, lazy residuation, Hasse-registry as primitive, provenance as structural emergence, PUnify audit confirming existing infrastructure covers claims, General Residual Solver deferred

---

## §4 Surprises and Non-Obvious Findings

Highest-risk items for a continuation session.

### §4.1 Stage 4 protocol extension — mini-design audit is step 1

Before Phase 1d session, Stage 4 Implementation Protocol's step 1 was "Mini-audit (codebase)." After `3beeb3ae`, step 1 is "Mini-design audit" (re-internalize the design target; no code or grep yet) and step 2 is the mini-audit. **If a continuation session skips step 1, it's not following current methodology.**

### §4.2 `merge-hasheq-union` is non-commutative by mechanics

New-wins on key collision means `(merge h1 h2) ≠ (merge h2 h1)` when keys overlap with different values. Intended registry semantics are identity-or-error, but the function doesn't enforce this — Phase 1e η split will audit.

### §4.3 Facet merge fns registered in Phase 2 don't appear at cell sites

`context-facet-merge`, `add-usage`, `constraint-merge`, `warnings-facet-merge`, `hasse-merge-hash-union` are registered but zero cells allocate with them directly. They're INNER merges inside `facet-merge` dispatch. Cells that USE facets go through `attribute-map-merge-fn` at the cell level.

Consequence: Phase 2 registrations are architecturally correct (the facets ARE registered domains) but the lint tool's "registered" count for Phase 2 alone is misleading. Phase 1d-B added attribute-map-merge-fn which is what most facet cells actually use.

### §4.4 Import cycle through namespace.rkt

`infra-cell.rkt → sre-core.rkt → ctor-registry.rkt → sessions.rkt → substitution.rkt → namespace.rkt → infra-cell.rkt`

Any module importing infra-cell cannot inline `sre-core` imports. Hence the `*-sre-registrations.rkt` pattern.

### §4.5 `type-lattice-merge` Tier 1-registered but Tier 2 missing before Phase 1d-B

`type-sre-domain` registered at `unify.rkt:109` (Phase 1 of original pre-4C work). But the Tier 2 `register-merge-fn!/lattice type-lattice-merge #:for-domain 'type` was never called. Phase 1d-B added it.

### §4.6 Prior art for Hasse decomposition is substantial (the key correction from Phase 2b)

Tagged-cell-value pattern across 10+ files + ATMS bitmask subcube membership + filter-dependents-by-paths + worldview bitmasks all EMBODY Hasse decomposition via filter-based reads on position-keyed cell values. Phase 2b's Hasse-registry **generalizes this practice**, doesn't invent it. **Critical for understanding Phase 2b's emergent design — not a graph-traversal algorithm.**

### §4.7 `:usage` non-idempotent finding under D2 framework

`(add-usage '(m1) '(m1)) = '(mw)`, not `'(m1)`. QTT semiring addition is a commutative MONOID, not a join-semilattice. R5 contingency: 1 real finding; within K=2; no Phase 2c repair stratum needed.

### §4.8 Hasse-registry `hash` vs `hasheq` bug (caught by tests)

My first Hasse-registry impl used `hasheq` (eq?-based). Positions are structured values (pairs, types) requiring `equal?` semantics. Tests caught it; fixed with local `hasse-merge-hash-union` variant.

### §4.9 Hasse-registry antichain direction bug (caught by tests)

My first antichain extraction removed `p` if `q` strictly BROADER; correct is strictly NARROWER (more specific). Tests caught it. The invariant: antichain of subsumers = positions p with no STRICTLY MORE SPECIFIC q that also subsumes.

### §4.10 Test-suite "affected-tests" shows 0 tests when pure-addition commits land

When Phase 2b landed (new hasse-registry.rkt module not imported by anything yet), affected-tests showed "No tests affected." Expected behavior — no regression because nothing downstream of new module. Discipline: also run smoke tests (test-merge-fn-registry, etc.) + acceptance file when affected-tests reports empty.

### §4.11 Prior handoff §4 surprises REMAIN VALID

All surprises from [`2026-04-18_PPN_4C_D2_EXTERNAL_CRITIQUE_HANDOFF.md`](2026-04-18_PPN_4C_D2_EXTERNAL_CRITIQUE_HANDOFF.md) §4 are still load-bearing. Most notably:
- Cell is not a lattice
- "Walks" keeps sneaking in
- PUnify reach richer than D.2 assumed
- Elaborator partially BSP-integrated
- `that-read` 1400× faster than CHAMP
- Lazy residuation needs narrowing detection
- Module Theory answered O3 provenance

---

## §5 Open Questions and Deferred Work

### §5.1 Phase 1d remaining

1. **1d-C**: inline lambda rewrite at `typing-propagators.rkt:1887` (trivial)
2. **1d-D**: 11 multi-line sites inspection (atms.rkt:761,478,473; bilattice.rkt:102,97; parser.rkt:2422,2412; propagator.rkt:1467; relations.rkt:305; tabling.rkt:211,110)
3. **1d-E**: lint tool "ambiguous-name" → "parameterized-passthrough" rename
4. **1d-F**: 23 unique merge fns remaining — likely some in 1d-D's multi-line sites, some may be inline-only
5. **1d-close**: `--save-baseline`; `--strict` green; update dailies + D.3 Progress Tracker Phase 1d row

### §5.2 Phase 1e scope (un-folded this session)

**η split**: `merge-hasheq-union` → `merge-hasheq-identity` + `merge-hasheq-replace`; audit 23 call sites; classify each; substitute variant; surface collision-with-non-equal-value bugs if any.

**Replace-cell audit**: each `merge-last-write-wins` + `merge-replace` call site classified per refactor path:
- (1) timestamp-ordered lattice
- (2) identity-or-error flat lattice
- (3) accept as non-lattice

**May surface**: timestamped-cell primitive (analogous to Hasse-registry) if path (1) is common.

### §5.3 Phase 1f — structural enforcement

Gated by 1d+1e complete (lint baseline empty). Flip the `net-add-propagator` check: structural domain + missing `:component-paths` = registration error. Remove `infer/err`-equivalent fallback paths for unregistered cells.

### §5.4 Phase 1V — Vision Alignment Gate

Phase 1's completion gate per Stage 4 step 5. Check all named drift risks from Phase 1's mini-design audit (in 2026-04-19 dailies). Confirm registration complete, enforcement live, no belt-and-suspenders, scaffolding labeled.

### §5.5 Mini-design deferrals carried from external critique (REMAIN OPEN)

All deferrals from prior handoff §5.1 are STILL ACTIVE:
- P3/Phase 6 — structural coverage lean
- C1/Phase 6 — quiescence gate (subsumed under P3)
- P4 + S1/Phase 3 — TermFacet lattice spec + merge reentrancy
- M1/Phase 7 — impl registration path
- M3/Phase 9b — γ catalog re-firing (dual to M1)
- C2/Phase 9 — cell-based TMS vs existing ATMS

### §5.6 Phase 11b research input carries

[Phase 11b needs trace monoidal category theory research read before mini-design] (Joyal-Street-Verity 1996; Hasegawa 1997; Abramsky-Haghverdi-Scott 2002). Noted in §6.1.1 of D.3.

### §5.7 Phase 5 scope expansion

Adds srcloc field to warning structs + emit-site threading (uses Phase 1.5 API) + merge switch to `merge-set-union`. Resolves Phase 2 `:warnings` D2 delta. Noted in Phase 5 tracker row.

### §5.8 `logic-var-merge` not exported from relations.rkt

Phase 1d-B noted this; excluded from registration. Small follow-up: either add to exports OR keep unregistered. Not blocking.

### §5.9 DEFERRED.md entries added this session

Per scaffolding registry discipline:
- Tier 2 merge-fn registry (`register-merge-fn!/lattice`) — Phase 1b
- `current-source-loc` parameter — Phase 1.5
- `hasse-registry-handle` Racket struct — Phase 2b

---

## §6 Process Notes

### §6.1 Codified THIS session

**Mini-design audit as Stage 4 step 1** — before any code or codebase audit. ~10 min investment. Commit `3beeb3ae`.

**D2 framework as commit artifact** — each SRE domain registration ships with its aspirational / declared / inference / delta table in the commit message.

**Scaffolding registry tracking** — every new off-network registry added with DEFERRED.md entry naming API + lifecycle + retirement plan.

**Cycle-breaking via `*-sre-registrations.rkt` modules** — when a module can't inline sre-core import due to cycle.

**"Don't DEFERRED dodge"** — when work is addressable, scope it as a named phase, not a future "someone" entry. Phase 1e was created this way (D2 resolution).

### §6.2 Operational discipline reflexes

From prior handoff (still valid):
- Lens discipline (Design Mantra, SRE 6 questions, Module Theory, PUnify, Hasse diagram)
- Progress Tracker near top of design docs
- "Stage X" not in artifact names
- Correctness over pragmatism
- Check research before inventing
- Grep-backed scope measurements
- Don't ask questions the project answers

### §6.3 Conversational cadence

Max 1h autonomous stretch before checkpoint. Works well for per-phase completion. This session ran longer stretches between checkpoints (multi-phase work in single conversational flow) but returned to user dialogue at each phase boundary.

### §6.4 Phase completion = 5-step blocking checklist

Tests (or explicit reason why not) → Commit → Tracker update → Dailies append → Proceed. Respected across 8+ phases this session.

---

## §7 What the Continuation Session Should Produce

### §7.1 Immediate (complete Phase 1d)

1. Inline lambda rewrite (`typing-propagators.rkt:1887`)
2. Multi-line site inspection (11 sites)
3. Lint tool category rename (`ambiguous-name` → `parameterized-passthrough`)
4. Re-baseline; `--strict` green
5. Phase 1d close commit + Progress Tracker update to ✅

### §7.2 Medium-term (Phase 1e)

1. η split of `merge-hasheq-union` + 23-site audit
2. Replace-cell audit (`merge-last-write-wins`, `merge-replace`)
3. Per-site refactor paths applied
4. If timestamped-cell primitive warranted, design + implement as sub-phase

### §7.3 Phase 1 close (1f + 1V)

1. Structural enforcement at `net-add-propagator` + hard-error flip
2. Vision Alignment Gate for Phase 1 against all named drift risks
3. Phase 1 ✅ — major milestone toward 4C completion

### §7.4 Beyond Phase 1

Phase 3+ per design doc. Mini-design deferrals fire at their phase-time (P3/Phase 6, P4+S1/Phase 3, M1/Phase 7, etc.).

---

## §8 Final Notes

### §8.1 What "I have full context" requires (per HANDOFF_PROTOCOL §Hot-Load Reading Protocol)

- Having read EVERY document in §2 IN FULL, not sampled
- Being able to articulate EVERY decision in §3 with rationale
- Knowing EVERY surprise in §4

If any is unclear, ASK before proceeding. "I think I understand Phase 1d" is not sufficient. "I understand Phase 1d's δ approach for `merge-hasheq-union` is non-commutative by mechanics but accepted as registry identity semantics at intent, with η split scoped to Phase 1e" is.

### §8.2 The session was long

This session covered:
- Phase 0 closure (acceptance file)
- Stage 4 methodology codification (mini-design audit)
- Phase 1 mini-design audit + mini-audit
- Phase 1a-c infrastructure
- Phase 1.5 srcloc infrastructure (hybrid α+η design)
- Phase 2 four-facet SRE registrations (with D2 framework)
- Phase 2b Hasse-registry (with user-pushback corrections on step-think)
- Phase 1d-A infra-cell generic registrations
- Phase 1d-B per-subsystem registrations

Much hard-earned context. The handoff's job is not to lose it.

### §8.3 Commits in this session (chronological)

From `d28e6029` (Phase 0 close) through `6ce7a50d` (Phase 1d-B). ~20+ commits. `git log --oneline --since 2026-04-19` shows the span.

### §8.4 Gratitude

This session has been shaped by careful, principled user pushback. Each moment the user pushed back — on "O(N) drift," on "DEFERRED.md dodging," on step-think patterns, on `ε` closure capture for srcloc, on lint "correctness" claims at parameterized-passthrough sites, on my initial DAG+traversal proposal for Hasse-registry — the design or code improved materially.

The refinements that surfaced during Phase 2b dialogue (tagged-cell-value + ATMS bitmask subcube as prior art for Hasse decomposition) were particularly load-bearing. Reframing Hasse-registry from "new infrastructure" to "generalization of existing practice" crystallized the design. That reframing was only possible because the user pointed at the prior art explicitly.

Future sessions: honor the pushback discipline. The user is a domain expert AND a co-architect. The back-and-forth IS the design process.

The context is in safe hands.
