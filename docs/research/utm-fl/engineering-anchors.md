# Engineering Anchors

The contract between LHC engineering measurements and the papers that depend on them. Engineering moves; papers must reference *frozen* snapshots. This file tracks what is frozen for which paper.

Each anchor records:
- the empirical claim,
- the source measurement / artifact,
- the freeze point (commit / tag / archived file),
- the paper(s) that depend on it,
- drift-detection plan.

---

## Active anchors

### A1 — Whitman's condition (W) holds 10/10 across Prologos lattices

- **Claim**: Across 4 lattice-structured semantic domains × all relevant relations × {ground, wider} sublattices, Whitman's condition (W) holds in 10/10 (domain × relation × depth) combinations. Antecedent fires in 83-99% of sampled 4-tuples on the type domain (non-vacuous).
- **Source**: `docs/research/2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION.md`.
- **Method anchor**: empirical sweep, 14 algebraic properties per (domain, relation, depth). Sample sizes: type N=6 ground / N=58 wider; session N=3 ground / N=29 wider; form-cell N=7; spec-cell N=5.
- **Frozen at**: 2026-05-08, document creation date. **TODO**: pin to git commit + archive raw measurement output.
- **Papers**: B (primary empirical pillar), C (binder-boundary phenomenon).
- **Drift-detection**: any change to merge functions in `type-lattice.rkt` or sibling domain merge files re-runs the sweep. Append to `engineering-anchors.md`.
- **Risk**: medium. Type-lattice merge has been in active redesign (Track 2I). Re-runs after subsequent track changes are required before submission.

### A2 — Scheduler portability via CALM (4 schedulers confirmed, same fixpoint)

- **Claim**: At least 4 distinct propagator schedulers produce the same fixpoint on the same network state, demonstrating scheduler-order independence under CALM-aligned architecture.
- **Source / enumeration** (per `outputs/phase-collapse-and-deterministic-parallelism-audit.md` E9–E10):
  1. **Gauss-Seidel sequential** — `racket/prologos/propagator.rkt` `run-to-quiescence-inner`.
  2. **BSP / Jacobi parallel-ready** — `racket/prologos/propagator.rkt` `run-to-quiescence-bsp`. Default since PAR Track 1 Phase 5.
  3. **Widening variant** — `racket/prologos/propagator.rkt` `run-to-quiescence-widen`.
  4. **Zig BSP PoC** — out-of-tree, branch (per owner; needs pinning per G3 in audit).
- **A/B infrastructure**: `racket/prologos/benchmarks/bench-scheduler-ab.rkt` overrides `current-use-bsp-scheduler?` globally — exercises every quiescence call (unify, elab-speculation, bridges, tabling). Baseline at `data/benchmarks/bsp-le-t2-baseline-scheduler.json`.
- **Frozen at**: 2026-05-08, audit doc. **Outstanding**: G2 — add fixpoint-identity assertion to A/B (currently compares wall-time only). G3 — pin Zig PoC commit.
- **Papers**: A0 (primary novelty claim H1), B (witness for CALM-as-substrate-property).
- **Drift-detection**: scheduler count grows as new ones are written; equivalence test re-runs per scheduler.
- **Risk**: medium-low (after audit). Code + design path well-supported; remaining work is the fixpoint-identity assertion + Zig PoC pinning.

### A3 — `.pnet` is its own IR; LLVM lowering PoC

- **Claim**: The propagator network's serialized state (`.pnet`) is consumed directly by a thin BSP scheduler (Zig PoC) and lowered to LLVM (LoweredPNET). No separate IR phase is needed; the network state is the IR.
- **Source**: Zig BSP scheduler PoC + LLVM lowering on branch (per owner). **TODO**: identify branch, archive PoC source, document interface.
- **Frozen at**: not yet frozen. **Required action**: pin branch / commit; archive lowering output for representative input.
- **Papers**: A0 (primary).
- **Drift-detection**: PReduce series will modify the on-network reduction story; re-anchor after PReduce Track 0/1.
- **Risk**: high if A0 submits before PReduce stabilizes the reduction story; A0 may want to scope-limit to "compilation phases only, reduction TBD" to avoid this.

### A4 — Phase collapse: same infrastructure, compile-time + runtime + (planned) reduction

- **Claim** (precise statement, audit-derived; for owner review): The Logos Hyperlattice Compiler implements parsing, elaboration, type checking, constraint resolution, retraction, and (via .pnet serialization) cross-session caching as fixpoint computations on a single propagator network whose cells hold lattice values. Compile-time and run-time use the same network primitives; the same fixpoint machinery serves what conventional architectures separate as elaboration phases, type-check passes, optimizer passes, and runtime verification. The phase boundary between any two of these reduces to a stratum boundary in the LRP sense.
- **Sources** (per `outputs/phase-collapse-and-deterministic-parallelism-audit.md` E1–E8):
  - E1: `2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md` §4.3 — phase boundary between type inference and constraint resolution dissolved within S0.
  - E2: `RESEARCH_PARALLEL.md` §11.4 — same unification engine compile-time + runtime.
  - E3: `2026-03-03_PROPAGATOR_NETWORK_FUTURE_OPPORTUNITIES.md` — compile pipeline IS a propagator chain.
  - E4–E5: `pnet-serialize.rkt` ships; Track 10 PIR; 17 registries serialized; .pnet cache ON by default.
  - E6: CHAMP O(1) fork-prop-network (Track 10 PIR; BSP-LE Track 2 Design).
  - E7: PReduce planned to lift reduction onto the same network.
  - E8: literature acknowledgment of phase-blurring in dependent type theory.
- **Frozen at**: 2026-05-08, audit doc.
- **Papers**: A0 (headline H2).
- **Drift-detection**: any new "stage" added to the compiler must check whether it is on-network or violates the claim.
- **Outstanding** (G1): PReduce status — reduction not yet on-network; A0 either waits for PReduce or scope-limits to compile-pipeline-and-elaboration phases. Owner decision needed.
- **Risk**: medium (down from highest after audit). The claim is well-supported in corpus but still wants owner validation of the precise statement, plus the PReduce scoping decision.

### A5 — LRP instances inventory

- **Claim**: At least six engineered systems exhibit the Layered Recovery pattern: NAF-LE, WF-LE, type system stratified quiescence, effect system (QTT + sessions), stratified retraction (S(−1)), topology-strata.
- **Source**: `docs/research/2026-03-21_CATEGORICAL_STRUCTURE_FIVE_SYSTEMS.md` (covers first five) + PPN series (topology-strata + likely more).
- **Frozen at**: 2026-05-08 for the first five; topology-strata and PPN-series instances pending enumeration.
- **Papers**: A (primary).
- **Drift-detection**: each PPN-series PIR scanned for new instances; instance set grows monotonically until paper freeze.
- **Risk**: low. Instances stably exist; categorical character per instance is the formalization work.

---

## Anchor-establishment queue (need work before they can be cited)

- **A6 — NTT design coverage**: NTT has been used as design meta-language for every propagator infrastructure piece since its inception. Anchor: catalog of which design docs use NTT specifications. Papers: A0 (NTT section).
- **A7 — `.pnet` round-trip durability**: If a `.pnet` is serialized, transported, and loaded by a different scheduler in a different language, does it produce the same fixpoint? Anchor: cross-language round-trip test. Papers: A0, B.
- **A8 — PReduce roadmap as evidence**: PReduce Master shows reduction also lifts onto the propagator network (e-graph + DPO + tropical-quantale + GoI). Even pre-implementation, the design completeness is itself evidence for the phase-collapse claim. Papers: A0 (forward reference), B.

---

## Drift log

(Empty.)
