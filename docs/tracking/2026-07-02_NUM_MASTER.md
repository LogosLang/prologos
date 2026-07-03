# Num Series — Master Roadmap

**Series**: `Num` — numerics systems of Prologos
**Founded**: 2026-07-02
**Master**: `docs/tracking/2026-07-02_NUM_MASTER.md` (this document)
**Linked from**: `docs/tracking/MASTER_ROADMAP.org` § Active Series

---

## Thesis

The `Num` Series is the home for **all work on the numerics systems of Prologos** — the numeric tower (Nat / Int / Rat / Posit / Float), refinement-via-trait, literal and display models, numeric ergonomics, and the type-system treatment of numeric polymorphism. It is a coherent, long-lived container: numerics work recurs across the project's lifetime (representation, precision, ergonomics, generic dispatch), and this series keeps that work indexed in one place rather than scattered across ad-hoc dated docs.

Design discipline follows the project standard (Stage 1–3 design cycle, grounding audits, on-network/mantra where the network is touched, three-stage typing parity per `pipeline.md`). Numerics-specific priors (the Feb Numerics Tower, the ergonomics audit, coercion/subtyping notes) are foundational inputs, not separate efforts.

## Status

Series founded 2026-07-02, seeded from the in-flight Numerics track. **Track 1** (Numerics Tower Completion) is ✅ **complete** (N1–N6; N6f reconciliation capstone done 2026-07-02) — unblocks DEMO P1. **Track 2** (Generic `Num`) is a **proposed** track with an implementation-note seed.

## Tracks

| Track | Description | Status | Design / seed |
|---|---|---|---|
| **1 — Numerics Tower Completion & Refinement** | `Float` as a full compute primitive; numeric tower reconceived as refinement-via-trait (nominal-erased Sign-backed refined types); context-typed polymorphic literal model; round-tripping display; exponent lexing; ergonomics; vision/roadmap reconciliation. Sub-phases N0–N6 (N6f = the reconciliation capstone). | ✅ **N1–N6 complete** (N6f done 2026-07-02; `sum`/`product` dict→where deferred → DEFERRED.md) → DEMO P1 | Charter: [`2026-06-30_NUMERICS_TRACK_CHARTER.md`](2026-06-30_NUMERICS_TRACK_CHARTER.md) · Stage-3 D.2: [`2026-06-30_NUMERICS_TRACK_STAGE3_DESIGN.md`](2026-06-30_NUMERICS_TRACK_STAGE3_DESIGN.md) |
| **2 — Generic `Num` (constraint-as-type numeric functions)** *(proposed)* | A bundle/constraint name usable directly in TYPE position (`spec square Num -> Num`) so numeric functions can be written over any numeric type. Includes the constraint-as-type desugar, keyword→trait-method routing for `+ - * /` on constrained abstract operands, and the deeper **heterogeneous** case (different numeric type per argument, result = numeric-join). | ⬜ **proposed** (seed note; not yet Stage-1) | Seed: [`2026-07-02_GENERIC_NUM_TYPE_NOTE.md`](2026-07-02_GENERIC_NUM_TYPE_NOTE.md) |

**Sequencing note**: Track 2 is *out of focus for the current DEMO needs* (owner, 2026-07-02) and is deliberately NOT folded into Track 1's N6f capstone. Track 1 completes (→ DEMO P1 unblock) before Track 2 opens its own Stage-1→3 cycle.

## Foundational prior art (inputs, not tracks)

- [`2026-02-19_NUMERICS_TOWER_ROADMAP.md`](2026-02-19_NUMERICS_TOWER_ROADMAP.md) — the original tower (Phases 1–3f ✅: posits, Int/Rat, traits, within-family subtyping, cross-family conversions; Phase 4 Float ⬜ → **completed by Track 1**).
- [`2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org`](2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org) — 6 problems / 8 gaps / 4 decisions (the ergonomics backlog; absorbed by Track 1 N6f).
- [`2026-02-22_NUMERIC_COERCION.md`](2026-02-22_NUMERIC_COERCION.md) · [`2026-02-27_1400_REFINED_NUMERIC_SUBTYPING.md`](2026-02-27_1400_REFINED_NUMERIC_SUBTYPING.md) · [`2026-03-11_GENERIC_NUMERICS_AUDIT.md`](2026-03-11_GENERIC_NUMERICS_AUDIT.md) · [`2026-03-11_GENERIC_NUMERICS_SPRINT.md`](2026-03-11_GENERIC_NUMERICS_SPRINT.md) · [`2026-02-21_2300_NUMERICS_PERF.md`](2026-02-21_2300_NUMERICS_PERF.md).

## Cross-series relationships

- **UCS Series (track 5)** — the *general* `Type@named-property` refinement surface + `trait`-as-type-producer + full (liquid-typing) inference is UCS-owned; Track 1 ships only the fixed built-in Sign refinement slice. Note: [`2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md`](2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md).
- **PPN Series** — bringing numeric typing + refinement fully on-network (retiring Track 1 N5's function-level scaffolding) is a future PPN track. Note: [`2026-06-30_NUMERICS_ON_NETWORK_PPN_NOTE.md`](2026-06-30_NUMERICS_ON_NETWORK_PPN_NOTE.md).
- **DEMO Series (Track 1)** — the dependency-resolver demo's JSON numbers spawned Num Track 1; DEMO P1 (JSON parser) unblocks after Track 1 completes.

## Candidate future tracks (unscheduled)

- Heterogeneous-numeric type-level join as a relational `NumJoin A B C` (needs functional-dependency / output-mode inference) — the theory-aligned realization for Generic `Num`'s heterogeneous case (see the Track 2 seed note).
- Numeric performance (representation efficiency, quire/fused ops) — see the perf prior-art note.
- Additional numeric families / interop (decimal, fixed-point, bignum) as tower extensions.

---
*Num Series Master, founded 2026-07-02. Seeded from the in-flight Numerics track (now Track 1) + the Generic-`Num` grounding audit (Track 2 seed).*
