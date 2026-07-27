# Paper A0 — The Logos Hyperlattice Compiler: A Propagator-Network Compiler with Phase Collapse

**Status**: skeleton v0.1.
**Type**: Systems / artifact paper.
**Target venues**: PLDI, OOPSLA, CGO, ICFP system-paper track.
**Time-to-submit estimate**: ~6+ months from now, **gated on PReduce reaching readiness** (per owner direction 2026-05-08). Possibly aligned with proximity to fully self-hosting. The wait is a deliberate choice for the strongest paper; other papers in the programme can be drafted in parallel and held / released after A0.
**Owner**: TBD.
**Co-authors**: TBD.
**Acknowledgments planned**: J. B. Nation (algebraic guidance on lattice substrates).

---

## 0. Working title alternatives

- *The Logos Hyperlattice Compiler: A Propagator-Network Compiler with No Phases*
- *Compilation as Fixpoint: A Propagator-Network Architecture for a Dependently-Typed Language*
- *LHC: Compile-Time and Run-Time as the Same Network*

---

## 1. Headline claims (two)

Per owner direction (2026-05-08), Paper A0 carries **two** headline claims, structurally coupled:

**H1 — Order-independent deterministic parallelism.** The propagator network's fixpoint is invariant under propagator firing order. Demonstrated empirically across at least four schedulers (Gauss-Seidel sequential, BSP/Jacobi parallel, widening variant — all in `racket/prologos/propagator.rkt` — plus a Zig BSP PoC operating on serialized `.pnet`). Architecturally enforced by lattice-valued cells + monotone propagators + semilattice merge. This is the **CALM / LVars / BloomL lineage realized at the granularity of an entire programming-language compiler**, not just a runtime data-structure library.

**H2 — Phase collapse.** The Logos Hyperlattice Compiler implements parsing, elaboration, type checking, constraint resolution, retraction, and (via .pnet serialization) cross-session caching as fixpoint computations on a single propagator network. Compile-time and run-time use the same network primitives. Conventional compile-pipeline phases reduce to stratum boundaries on the same network, not separations between distinct artifacts.

**Coupling**: H1 is the *cause*, H2 is the *consequence*. Lattice-valued cells + monotone propagators + semilattice merge ⇒ order-invariant fixpoint ⇒ scheduler-portable network state ⇒ `.pnet`-as-IR ⇒ no preferred phase ordering ⇒ phase collapse.

## 2. Supporting claims

- C1: `.pnet` is its own IR. The propagator-network state is directly executable by a thin scheduler; no separate IR construction phase is required. (Anchor: `pnet-serialize.rkt` ships as of Track 10; see `outputs/phase-collapse-and-deterministic-parallelism-audit.md` E4–E5.)
- C2: Scheduler portability evidence: A/B benchmark infrastructure exists in `racket/prologos/benchmarks/bench-scheduler-ab.rkt`, exercising the equivalence across the *entire* compiler (unify, elab-speculation, bridges, tabling), not just one subsystem.
- C3: Persistent-data-structure backing (CHAMP) makes `fork-prop-network` O(1) via structural sharing — the practical enabler for treating the network as a first-class value.
- C4: NTT (Network Type Theory) functions as design meta-language; speculative specifications catch real bugs before implementation. Used for every propagator infrastructure piece since inception.
- C5: The architecture supports a dependently-typed, QTT-linear, session-typed, π-calculus-based language without phase boundaries between elaboration and (planned) reduction. Reduction lift to network is in flight via PReduce series.

## 3. Outline (TBD; revised for dual-headline framing)

- §1 Introduction — both headlines stated; cause/consequence coupling motivated.
- §2 Background — propagator networks (Sussman-Radul); CALM theorem; LVars / BloomL deterministic-parallelism lineage; lattice-valued cells.
- §3 The LHC architecture — cells, propagators, BSP scheduler, CHAMP-backed persistence, .pnet serialization.
- §4 H1: Order-independent deterministic parallelism — the architectural enforcement (lattice-valued + monotone + semilattice merge); A/B benchmark infrastructure; cross-scheduler fixpoint equivalence; the LVars/CALM-at-compiler-scale claim.
- §5 H2: Phase collapse — what collapses, what doesn't, how it's enforced. The S0-fiber-expansion observation (`2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS`); compile-time + runtime unification on the same engine; pipeline-as-propagator-chain.
- §6 .pnet as IR — serialization, round-trip, fork-prop-network O(1) via CHAMP, deployment-artifact discussion.
- §7 NTT as design meta-language — case studies of bugs caught pre-implementation; the seven-form syntax inventory.
- §8 LLVM lowering PoC — `.pnet` → LoweredPNET → LLVM via Zig BSP scheduler; cross-language scheduler portability.
- §9 Evaluation — compilation times; scheduler-equivalence protocol; .pnet round-trip durability.
- §10 Related work — equality saturation (Tate 2009); e-graphs as IR; BloomL; LVars (Kuper); CALM (Hellerstein-Alvaro); propagator literature; type-checker-as-evaluator precedents (Idris, Lean).
- §11 Limitations and future work — PReduce status (reduction lift in flight); NTT user-facing form (currently design-only); distributed scheduling; full self-hosting.

## 4. Open questions blocking this paper

See `../open-questions.md`:
- Q-A0-1 (phase-collapse precise statement) — the headline claim needs to be locked early.
- Q-A0-2 (scheduler-portability evidence trail).
- Q-A0-3 (NTT positioning — section vs sidebar).
- Q-A0-4 (.pnet IR claim novelty positioning vs equality-saturation lineage).

## 5. Engineering anchors required

See `../engineering-anchors.md`:
- A2 (scheduler portability) — needs measurement protocol + archived `.pnet`.
- A3 (`.pnet` IR + LLVM PoC) — needs branch-pinning + archived lowering output.
- A4 (phase collapse) — currently undocumented in isolation; **highest-priority anchor work**.
- A6 (NTT design coverage) — catalog of design docs that use NTT.
- A7 (`.pnet` cross-language round-trip).

## 6. Risk profile

**Lowest of any programme paper, after the wait.** Per owner direction (2026-05-08), A0 waits for PReduce to mature — possibly close to fully-hosting — to make the strongest version of the phase-collapse claim (covering reduction, not just elaboration). Other papers proceed in parallel and may be held until A0 lands. Describes existing engineering. No new theorems.

## 7. Provenance / source material

- `outputs/phase-collapse-and-deterministic-parallelism-audit.md` — internal audit consolidating evidence E1–E13 + PAR Track 2 "40-line PoC just worked" anecdote (E9-bis).
- `2026-03-22_NTT_SYNTAX_DESIGN.md`
- `2026-03-22_NTT_ARCHITECTURE_SURVEY.md`
- All NTT case-study documents (4)
- PM (Propagator Migration) PIRs — Tracks 1–8D, 8F, 10, 10B
- BSP-LE Track 2B PIR
- `2026-05-02_PREDUCE_MASTER.md` (gating dependency, not forward reference — A0 waits for PReduce)
- `2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md`
- `2026-04-30_SH_MASTER.md` (self-hosting context for full phase-collapse claim)

## 8. Acknowledgments planned

- **J. B. Nation** — algebraic guidance on lattice substrates.
- **Lior Kuper** — LVars / lattice-based deterministic parallelism is direct intellectual lineage; per owner: "our efforts stem from this, directly inspired from this work."
- **Joe Hellerstein, Peter Alvaro** — CALM theorem is the architectural invariant the system enforces; the PAR Track 2 "40-line parallel scheduler PoC just worked on first run" experience is empirical evidence in their favor.
- **BloomL team** (Conway et al.) — lattice-typed distributed programming precedent.
- **Sussman, Radul** — propagator network primitive.
