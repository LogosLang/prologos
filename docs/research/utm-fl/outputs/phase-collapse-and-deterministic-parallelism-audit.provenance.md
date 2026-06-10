# Provenance: Phase Collapse + Deterministic Parallelism Audit

- **Date**: 2026-05-08.
- **Topic**: Internal-source audit for Paper A0's two headline claims (phase collapse; order-independent deterministic parallelism via CALM).
- **Slug**: `phase-collapse-and-deterministic-parallelism`.
- **Final artifact**: `outputs/phase-collapse-and-deterministic-parallelism-audit.md` (~16 KB, 13 evidence entries E1–E13, six identified gaps G1–G6, six recommended next moves).
- **Resolves**: `open-questions.md` Q-A0-1 (phase-collapse precise statement) draft + Q-A0-2 (scheduler-portability evidence trail) draft. Begins documentation for engineering-anchors A2 and A4.

## Method

- **Internal-source only.** No new web or paper search. Direct grep over `docs/research/`, `docs/tracking/`, and `racket/prologos/` source trees.
- **Direct quotes verbatim** from corpus, with file path + section/line context.
- **Inferences flagged** as such (proposed precise statements explicitly marked "composed from corpus evidence rather than copied").

## Sources consulted

- `docs/research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md` — phase-boundary-dissolution direct quote.
- `docs/research/RESEARCH_PARALLEL.md` — compile-time + runtime unification claim.
- `docs/research/2026-03-03_PROPAGATOR_NETWORK_FUTURE_OPPORTUNITIES.md` — incremental-compiler-as-network + distributed-network message-order quotes.
- `docs/research/2026-03-03_PROCESS_CALCULI_SURVEY.md` — phase-blurring literature acknowledgment.
- `docs/tracking/2026-04-30_SH_MASTER.md` — `.pnet` as deployment-artifact format + Track 1 scope.
- `docs/tracking/2026-03-24_PM_TRACK10_PIR.md` — `.pnet` cache delivery, status table, 17 registries serialized.
- `docs/tracking/MASTER_ROADMAP.org` — Track 10 wall-time delta (240→134s).
- `docs/tracking/2026-04-07_BSP_LE_TRACK2_DESIGN.md` — clause-body order-independence; CHAMP fork.
- `docs/tracking/2026-05-02_PREDUCE_MASTER.md` — reduction-on-network thesis.
- `racket/prologos/propagator.rkt` — Gauss-Seidel + BSP/Jacobi schedulers, `current-use-bsp-scheduler?` global override, `run-to-quiescence` / `run-to-quiescence-bsp` / `run-to-quiescence-widen`.
- `racket/prologos/benchmarks/bench-scheduler-ab.rkt` — A/B benchmark infrastructure header + override scope.

## Tooling

- `rg` (ripgrep) for structured grep across docs + source.
- File reads via `Read` tool.
- No subagent delegation (audit-shape work; lead-direct).

## Limitations

- **Not a formal verification.** Audit collects evidence; does not prove the headline claims.
- **Branch state for Zig PoC + LLVM lowering not inspected.** Owner-stated; flagged as G3.
- **PReduce status forward-only.** Reduction not yet on-network; G1 is the explicit scope decision Paper A0 must make.
- **Equivalence-test gap.** A/B benchmark compares wall-time, not fixpoint identity. G2 flagged for engineering follow-up.
- **Scheduler enumeration uncertain.** Owner stated "4-5 schedulers"; audit found 4 with high confidence (Gauss-Seidel, BSP/Jacobi, widening variant, Zig PoC). Possibly more in branches; flagged as G4.

## Workflow notes

- This audit is *internal-only* — no external literature search. The matching external-positioning audit (Q-A0-4: .pnet-IR claim novelty vs equality-saturation lineage) is a separate piece of work, not bundled here.
- Quoted-verbatim discipline matched the FL+UTM round-1 audit shape.
- Structural finding (the two claims are *coupled*, with order-independence as the cause and phase collapse as the consequence) emerged during writing, not from a planned deduction. Recorded in §"Connecting the two claims to Paper A0's headline framing."
