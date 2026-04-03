# SRE Track 2D: Rewrite Relation — Post-Implementation Review

**Date**: 2026-04-03
**Duration**: ~6 hours design, ~4 hours implementation. 1 session.
**Commits**: 16 (from `c26fe96e` Stage 2 audit through `74036cbe` additional lifts)
**Test delta**: 7526 → 7526 (+0 — Pre-0 benchmarks validate, no dedicated test file yet)
**Code delta**: ~600 lines added in sre-rewrite.rkt (new module). ~25 lines modified in surface-rewrite.rkt (pipeline integration).
**Suite health**: 384/384 files, 7526 tests, 138.1s, all pass
**Design iterations**: D.1 → D.2 (Pre-0) → D.3 (self-critique, 3 lenses) → D.4 (incorporating findings + discussion) → D.5 (external critique, 12 findings)
**Design docs**: [Design](2026-04-03_SRE_TRACK2D_DESIGN.md), [Stage 2 Audit](2026-04-03_SRE_TRACK2D_STAGE2_AUDIT.md)
**Series**: SRE (Structural Reasoning Engine) — Track 2D

---

## 1. Stated Objectives and Evolution

**Original (D.1)**: Lift PPN 2-3's 12 lambda-based rewrite rules onto the SRE as first-class DPO spans with explicit interfaces.

**Scope refinement during design**: The user pushed for propagator-only architecture — per-rule propagators (not iteration), K as sub-cells (not hash scaffolding), PUnify for template instantiation (not imperative walk), form tags as first-class ctor-descs. These made the design significantly more propagator-native than the D.1 draft.

**Final**: 11 of 13 rules lifted to SRE spans (85%). 5 simple, 5 fold, 1 tree-structural. 2 remaining as lambda (cond: arm-splitting, mixfix: precedence resolution). Critical pair analysis validates strong confluence (0 pairs). Per-rule propagator factory built. Pipeline integration via dual path (SRE first, lambda fallback).

## 2. What Was Built

The SRE has a REWRITE RELATION — the 4th relation type. `sre-rewrite.rkt` (600 lines) provides:
- **DPO span struct** (`sre-rewrite-rule`): pattern-desc LHS, named K interface, template-tree RHS, metadata (directionality, cost, confluence class)
- **pattern-desc**: extends ctor-desc with positional child patterns, literal matching, variadic tail. Grammar Form compilation target.
- **PUnify holes**: `$punify-hole` and `$punify-splice` tagged parse-tree-nodes for template markers
- **match-pattern-desc**: structural pattern matching on parse-tree-nodes
- **instantiate-template**: fill holes from K bindings (PUnify-compatible)
- **Fold combinator**: right-fold over variable-length children (list-literal, lseq-literal, do, pipe-gt, compose)
- **Tree-structural combinator**: per-position processing for quasiquote
- **Propagator factory**: `make-rewrite-propagator-fn` creates fire functions for per-rule propagators
- **Binding context**: abstracts hash vs network cells for K
- **Critical pair analysis**: arity-aware overlap detection (0/11 rules overlap)
- **Form-tag ctor-descs**: form tags as first-class in `'form` domain

## 3. Timeline and Phases

| Phase | Commit | Key Result |
|-------|--------|------------|
| Audit | `c26fe96e` | 12 rules cataloged, DPO correspondence, 3 layers identified |
| Design D.1 | `6fe1b681` | 8-phase design |
| Pre-0 | `299ead31` | 28 benchmarks, expand-compose duplicate found |
| D.3 self-critique | `ae6763e2` | 11 findings. R1 (ctor-descs), M2 (per-rule propagators), M4 (K sub-cells) |
| D.5 external critique | `c585fe6b` | 12 findings. F2 (Phase 7 iteration), F7 (conflict merge), F9 (tree combinator) |
| Phase 1 | `1b059003` | sre-rewrite.rkt infrastructure |
| Phase 2 | `25a697aa` | 5 simple rules lifted |
| Phase 3a | `e67f0820` | Fold combinator + 3 fold rules |
| Phase 3b | `dbf793d5` | Tree-structural combinator + quasiquote |
| Phase 4 | `c86594be` | Propagator factory |
| Phase 5 | `59609525` | K binding context |
| Phase 6 | `43773669` | Critical pair analysis (0 pairs) |
| Phase 7 | `b061d832` | Pipeline integration (SRE first, lambda fallback) |
| Additional lifts | `74036cbe` | pipe-gt + compose lifted (11/13 rules) |

## 4. Bugs Found and Fixed

**Bug 1: expand-compose registered twice (Pre-0).** Track 2 (right-to-left) and Track 2B (left-to-right) both registered with same tag. Track 2B was dead code. SRE registry only has the correct (left-to-right) version.

## 5. What Went Well?

1. **The self-critique + user discussion fundamentally improved the architecture.** D.1 was data-layer-only. The user pushed: per-rule propagators (M2), K as sub-cells (M4), PUnify for templates (R2), fold as micro-stratified PU. Each push moved the design from scaffolding toward the permanent architecture.
2. **The Pre-0 critical pair analysis caught a real bug** (expand-compose duplicate) and validated strong confluence.
3. **The user's push to lift ALL rules** caught incomplete delivery. Moved from 8/13 (62%) to 11/13 (85%).

## 6. What Went Wrong?

1. **Initial design delivered dual-path as acceptable.** The user correctly identified this as the "validated ≠ deployed" pattern. Rules that CAN be lifted SHOULD be lifted.
2. **Phase 3a claimed cond couldn't be lifted.** Actually, cond CAN be lifted with a richer step function — the real blocker is arm syntax formalization (Grammar Form scope). This was imprecise scoping.

## 7. Where We Got Lucky

1. **Zero critical pairs across all 11 SRE rules.** If any had overlapped, the dual-path integration would have produced different results depending on which system fires first.

## 8. What Surprised Us?

1. **The fold combinator was simple.** `run-fold` is literally `foldr`. The complexity is in the step functions, not the combinator.
2. **The circular dependency between sre-rewrite.rkt and surface-rewrite.rkt** required local tag constant definitions. An architectural smell but pragmatic for Phase 7.

## 9. How Did the Architecture Hold Up?

The SRE relation infrastructure (from Track 2F) is extensible — adding the 4th relation followed the same pattern as subtype and duality. The ctor-desc registry accepted form-domain registrations cleanly. The form pipeline's monotone shell accommodated SRE dispatch alongside lambda dispatch.

Friction: the circular dep for tag constants. Long-term fix: extract tag constants to a shared module.

## 10. Key Design Decisions and Rationale

| Decision | Rationale | Principle |
|----------|-----------|-----------|
| Form tags as first-class ctor-descs | SRE-native structural decomposition | First-Class by Default (4) |
| Per-rule propagators (not iteration) | Parallel-safe, no priority needed | Propagator-First (1) |
| PUnify holes (not imperative walk) | Structural unification fills holes | Propagator-First (1) |
| Fold as PU micro-strata (Option C) | One cell, no per-step allocation | Data Orientation (2) |
| Conflict merge → top (contradiction) | Overlapping rewrites = grammar ambiguity | Correct-by-Construction (3) |

## 11. Lessons Learned

**L1: "Dual path during migration" is a rationalization for incomplete delivery.** If rules CAN be lifted, lift them. The dual path should exist only for rules with genuine architectural blockers (cond arm-splitting, mixfix precedence).

**L2: The fold combinator is trivially simple because Racket's `foldr` IS the combinator.** The design complexity was in understanding the lattice structure (micro-stratified PU), not in the implementation.

## 12. Metrics

| Metric | Value |
|--------|-------|
| Rules lifted to SRE | 11/13 (85%) |
| Critical pairs | 0 (strongly confluent) |
| New module | sre-rewrite.rkt (~600 lines) |
| D:I ratio | 1.5:1 |
| Suite wall time change | 136.7s → 138.1s (noise) |

## 13. What's Next

- **Grammar Form R&D**: Track 2D's 11 lifted rules ARE the concrete DPO/HR examples. pattern-desc IS the Grammar Form compilation target.
- **PPN Track 4**: critical pair analysis + sub-cell interfaces consumed by elaboration-on-network.
- **Cond arm-splitting**: Grammar Form formalizes arm syntax → cond becomes liftable.
- **Dedicated test file**: Track 2D has no persistent regression tests (Pre-0 benchmarks validate but aren't in suite).

## 14. Key Files

| File | Role |
|------|------|
| `sre-rewrite.rkt` | NEW: DPO spans, pattern-desc, holes, fold/tree combinators, propagator factory, critical pairs |
| `surface-rewrite.rkt` | Modified: V0-2 delegates to SRE rules first, lambda fallback |

## 15. Lessons Distilled

| Lesson | Distilled To | Status |
|--------|-------------|--------|
| L1: Dual path = incomplete delivery | DEVELOPMENT_LESSONS.org | Pending |
| L2: Fold combinator = foldr (trivial) | Noted in PIR | — |
| Pre-0 critical pair analysis catches bugs | DESIGN_METHODOLOGY.org (reinforced) | 3rd instance |

## 16. Technical Debt Accepted

| Debt | Rationale | Tracking |
|------|-----------|----------|
| Cond stays as lambda | Arm-splitting needs Grammar Form formalization | Grammar Form scope |
| Mixfix stays as lambda | Precedence resolution, not pattern→template | Architectural — different mechanism |
| Local tag constants in sre-rewrite.rkt | Circular dep with surface-rewrite.rkt | Extract to shared module |
| apply-all-sre-rewrites uses for/or (iteration) | Transitional until per-rule propagators wired on network | Phase 7 notes |
| No persistent test file | Pre-0 benchmarks validate | Follow-up |
