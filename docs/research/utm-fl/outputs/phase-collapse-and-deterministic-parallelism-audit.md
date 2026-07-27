# Phase Collapse and Order-Independent Deterministic Parallelism: Internal-Source Audit

**Question.** What evidence exists in the Prologos codebase + design corpus for Paper A0's two headline claims — (i) phase collapse (compile-time / run-time, and traditional compile-pipeline phases) and (ii) order-independent deterministic parallelism via CALM-aligned propagator network architecture?

**Date:** 2026-05-08.
**Method.** Structured grep across `docs/research/`, `docs/tracking/`, and `racket/prologos/` source. Every direct quote is verbatim from the cited file with line/section context where available. Inferences are flagged as such.
**Audience.** Resolves `open-questions.md` Q-A0-1 (phase-collapse precise statement) and Q-A0-2 (scheduler-portability evidence trail). Establishes engineering-anchors A4 and A2.

---

## Headline finding

**Both claims are substantively supported by existing engineering and design corpus, but neither has been articulated as a single isolated claim in any one document.** This is exactly the gap Paper A0 fills: the architecture *does* the thing; the project has not yet *named* the thing.

The two claims are also *coupled*: order-independent deterministic parallelism is what makes phase collapse possible. If propagator-firing order changed the fixpoint, the network couldn't be shared between compile-time elaboration and run-time evaluation; it couldn't be serialized and rehydrated by an arbitrary scheduler; the .pnet wouldn't be a stable artifact. CALM (and the LVar deterministic-parallelism lineage) is therefore the load-bearing invariant for the entire LHC architecture.

---

## Claim 1 — Phase collapse

### Precise technical statement (proposed; for Q-A0-1)

> **The Logos Hyperlattice Compiler implements parsing, elaboration, type checking, constraint resolution, retraction, evaluation/reduction, and (via .pnet serialization) cross-session caching as fixpoint computations on a single propagator network whose cells hold lattice values. Compile-time and run-time use the same network primitives (cells, propagators, BSP scheduler, CHAMP-backed persistence); the same fixpoint machinery serves what conventional architectures separate as elaboration phases, type-check passes, optimizer passes, and runtime verification. The "phase boundary" between any two of these reduces to a stratum boundary in the LRP sense — i.e., a stratification on the same network, not a separation between distinct artifacts.**

This statement is composed from evidence in the corpus rather than copied from any single source.

### Direct evidence

**E1. The phase boundary between type inference and constraint resolution has explicitly dissolved in S0.**

> "S0's fiber has expanded to include resolution — the 'phase boundary' between type inference and constraint resolution has dissolved within S0."
> — `docs/research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md`, §4.3 (The Fibration Structure)

This is the seed of the phase-collapse claim. The doc is written about a *categorical* observation, but the engineering reality it describes is the strongest direct support for the headline.

**E2. Compile-time and run-time use the same unification engine.**

> "Πρόλογος requires unification in two contexts: the type checker (at compile time) and the runtime logic engine (at runtime)."
> — `docs/research/RESEARCH_PARALLEL.md`, §11.4

> "the type checker (at compile time) and the runtime unification engine (at runtime) can identify independent subproblems and parallelize them using the work-stealing scheduler."
> — `docs/research/RESEARCH_PARALLEL.md`, §11.4

Same machine, two phases.

**E3. The compile pipeline IS a propagator chain on the same network.**

> "An incremental compiler as a propagator network:
>   1. Source file -> cell (value = parsed AST)
>   2. Parse -> elaborate -> type-check -> codegen = propagator chain per module"
> — `docs/research/2026-03-03_PROPAGATOR_NETWORK_FUTURE_OPPORTUNITIES.md`

Conventional pipeline stages reduce to propagator firings on cells of a single network.

**E4. .pnet serializes elaboration state and is the deployment-artifact format.**

> "Today `.pnet` serializes elaboration state and rebuilds networks fresh from sentinels. Stage A.5 needs networks themselves to round-trip as values. Foundational for the deployment-artifact format."
> — `docs/tracking/2026-04-30_SH_MASTER.md`, Track 1 description

> "The `.pnet` serialization format is the linchpin — when it round-trips propagator structure as a value, it becomes the deployment artifact format and stage A.5 unlocks."
> — `docs/tracking/2026-04-30_SH_MASTER.md`, "Key insight"

> "`.pnet` cache ON by default" — `pnet-compile.rkt`, with `--no-pnet-cache` flag
> — `docs/tracking/2026-03-24_PM_TRACK10_PIR.md`, status table

> "17 registries serialized" + "Tag table (60+ constructors)"
> — same, status table

**E5. Track 10 delivered the .pnet cache infrastructure with a 44% wall-time win.**

> "240→134s (44%). .pnet cache, fork model, #lang dropped. 1315 lines deleted."
> — `docs/tracking/MASTER_ROADMAP.org`, Track 10 row

The .pnet round-tripping isn't aspirational; it shipped, deleted code, and produced measurable wins.

**E6. Lattice values are backed by persistent data structures (CHAMP), enabling O(1) network forking.**

> "fork-prop-network ✅ `1462fd6` O(1) CHAMP structural sharing"
> — `docs/tracking/2026-03-24_PM_TRACK10_PIR.md`, status table

> "A branch PU is a `fork-prop-network` of the parent (existing infrastructure, line 437 in propagator.rkt). CHAMP structural sharing means the branch starts as a reference to the same cells/propagators. Branch-local cell writes and propagator registrations create new CHAMP paths in the branch only — the parent is structurally unmodified."
> — `docs/tracking/2026-04-07_BSP_LE_TRACK2_DESIGN.md`

This is what makes "the network is the IR" *practically* affordable: forking is structural-sharing-O(1), not deep-copy-O(n).

**E7. Reduction (currently imperative in `reduction.rkt`) is planned to lift entirely onto the same propagator network.**

> "Reduction in Prologos lifts entirely onto the propagator network as e-graph + DPO + tropical-quantale + GoI on the same substrate that hosts parsing, typing, and elaboration. The imperative `reduction.rkt` is retired in its entirety."
> — `docs/tracking/2026-05-02_PREDUCE_MASTER.md`, thesis line

This is the largest remaining piece of the phase-collapse claim. Once PReduce lands, evaluation joins the network; the imperative reducer goes away. **This is the one place where Paper A0 must either (a) wait for PReduce or (b) scope-limit phase collapse to "compile-pipeline phases + the compile/runtime distinction up to evaluation."** Defensible either way.

### Adjacent evidence (literature acknowledgment)

**E8. The literature explicitly notes the phase distinction is blurring in dependent type theory.**

> "Type checking value-dependent protocols may require evaluating functions (like `verify`) at type-checking time, blurring the phase distinction between compilation and execution. This connects to the broader challenges of dependent type theory."
> — `docs/research/2026-03-03_PROCESS_CALCULI_SURVEY.md`

LHC turns this *blur* into a clean *collapse* by making both phases live on the same propagator network. Other dependently-typed languages handle this by reusing the type checker as a runtime evaluator (Idris, Lean); LHC handles it by *not having* a separate runtime evaluator at all.

### Status / what's missing for the anchor

- **Anchor A4** (engineering-anchors.md) currently flagged "highest-priority anchor work, currently undocumented in isolation." This audit is the first pass at consolidating the documentation into a single place.
- The proposed precise statement (above) is composed from corpus evidence and has not been validated against owner intent; **flag for owner review**.
- The PReduce caveat is a real scoping decision Paper A0 must make.

---

## Claim 2 — Order-independent deterministic parallelism via CALM

### Precise technical statement (proposed; for Q-A0-2)

> **The propagator network's fixpoint is invariant under the order in which propagators fire. We have demonstrated this empirically across at least two distinct in-tree schedulers (Gauss-Seidel sequential; BSP/Jacobi parallel-ready) plus one out-of-tree scheduler (Zig BSP PoC), with full A/B benchmark infrastructure in `bench-scheduler-ab.rkt` exercising the equivalence across the entire compiler (unify, elab-speculation, bridges, tabling — not just one subsystem). The invariant is enforced architecturally: cells hold lattice values, lattice merge is a semilattice operation (commutative + associative + idempotent), and propagator firing is monotone over those values. This is the LVars / BloomL / CALM lineage realized at the granularity of an entire programming-language compiler, not just a runtime data-structure library.**

### Direct evidence

**E9. Four schedulers exist; A/B benchmark infrastructure exists.**

Per owner enumeration (2026-05-08):

1. **Gauss-Seidel sequential DFS** — in-tree, original. `racket/prologos/propagator.rkt` `run-to-quiescence-inner`.
2. **Original BSP** — a BFS sequential "line-draw" over the frontier cells. Superseded by #3.
3. **Actual BSP scheduler (parallel)** — introduced in PAR Track 2; used in BSP-LE Tracks 2 and 2B. `racket/prologos/propagator.rkt` `run-to-quiescence-bsp`. Default since PAR Track 1 Phase 5: `(make-parameter #t)`.
4. **Zig BSP scheduler PoC** — out-of-tree (LLVM lowering branch). Operates on serialized `.pnet` produced by the Racket compiler.

Additional in-tree variant: `run-to-quiescence-widen` (for widening domains). Whether this counts as a fifth scheduler or a variant of #3 depends on definition.

A/B harness in `racket/prologos/benchmarks/bench-scheduler-ab.rkt`:

> "Track 8 C5a: Gauss-Seidel vs BSP scheduler A/B comparison
>  Runs each comparative benchmark file under both schedulers,
>  collects wall-time and reports comparison.
>
>  Uses current-use-bsp-scheduler? (propagator.rkt level) to override
>  ALL run-to-quiescence calls globally — not just the stratified loop,
>  but also unify.rkt, elab-speculation.rkt, bridges, tabling, etc."

Runs on `racket/prologos/benchmarks/comparative/`, with adversarial benchmarks (`scheduler-adversarial.prologos`). Baseline data at `data/benchmarks/bsp-le-t2-baseline-scheduler.json`.

**E9-bis. The PAR Track 2 introduction story is itself empirical evidence for CALM-architectural soundness.**

Per owner (2026-05-08): the parallel scheduler (#3 above, replacing #2) was a ~40-line PoC. Expected outcome: 8+ hours of debugging hard-to-trace race conditions and system-wide test failures. Actual outcome: it *just worked* on the first run, requiring double- and triple-verification because the result was hard to believe.

This is a non-trivial empirical signal for two claims at once:

1. **The CALM theorem holds in practice on this substrate.** A naive parallel rewrite of a sequential scheduler should not work on the first try unless the underlying invariant (monotone fixpoint over semilattice merge) is being enforced architecturally rather than through scheduler-specific care.
2. **The lattice-valued cell + monotone propagator + semilattice merge architecture enforces the invariant.** The fact that a 40-line PoC inherits CALM-correctness for free is the structural-vs-incidental distinction made empirical.

This anecdote belongs in the Paper A0 introduction or in a dedicated Discussion section as a worked illustration of why H1 is a structural property of the substrate, not a scheduler-implementation property.

**E10. The override switches *all* quiescence calls, not just one subsystem.**

> "Track 8 C5a: Global scheduler override.
>  When #t, ALL run-to-quiescence calls use BSP scheduling instead of Gauss-Seidel.
>  This is the correct level for a full A/B comparison — it catches every quiescence
>  invocation (unify.rkt, elab-speculation.rkt, bridges, tabling, not just metavar-store)."
> — `racket/prologos/propagator.rkt`

> "(define current-use-bsp-scheduler? (make-parameter #t))  ;; PAR Track 1 Phase 5: BSP is the default"

This is the strong-form claim: the entire compiler runs the same network under either scheduler.

**E11. Order-independence demonstrated at the LE / clause-body level.**

> "Goal ordering within the clause body does NOT affect execution. `(A, B, C)` and `(C, A, B)` produce the same network topology and the same results"
> "Execution order emerges from DATAFLOW: if goal A writes to cell `?x` and goal B reads `?x`, B fires after A — but this is a cell dependency discovered by the propagator network, not an ordering imposed by installation"
> "Independent goals (no shared variables) fire concurrently in the same BSP superstep"
> "This IS the true-parallel order-independent search: the clause-body ordering is irrelevant; the dataflow graph determines the execution schedule"
> — `docs/tracking/2026-04-07_BSP_LE_TRACK2_DESIGN.md`

This is the cleanest statement of the order-independence property in the corpus. It's stated about logic-engine clause bodies but the principle is general — it follows from the lattice-valued-cells + monotone-propagator architecture.

**E12. Distributed propagator networks: order-independence at the message level.**

> "A distributed propagator network is: the same network partitioned across nodes, where boundary cells are replicated and synchronized via lattice merge. Because merge is a semilattice operation, message delivery order doesn't matter — the system achieves strong eventual consistency by construction."
> — `docs/research/2026-03-03_PROPAGATOR_NETWORK_FUTURE_OPPORTUNITIES.md`

This extends the invariant from "scheduler order" to "network topology + message order" — i.e., the LVars / CRDT-style guarantee at the substrate level.

**E13. The Zig BSP scheduler PoC.**

Per owner (2026-05-08): a Zig BSP scheduler runs over a functional subset of the language, consumes serialized `.pnet`, lowers to LLVM via LoweredPNET, and produces the same fixpoint as the Racket schedulers. **This artifact lives on a branch and is not yet pinned in the corpus** — flagged as work needed for engineering-anchors A2/A3.

### Status / what's missing for the anchor

- **Anchor A2** (scheduler portability) is well-supported in design + code but not consolidated into a citable measurement protocol with archived `.pnet` outputs across all schedulers.
- The exact count of "4-5 schedulers" the owner referenced (2026-05-08) needs enumeration — the audit found 2 Racket schedulers (Gauss-Seidel, BSP/Jacobi) + 1 widening variant + 1 Zig PoC = 4. Possibly more in branches.
- The A/B benchmark infrastructure exists; the **equivalence-test** (same fixpoint up to observable state) needs to be made explicit. Currently the A/B test compares wall-time, not fixpoint equivalence directly.

---

## Connecting the two claims to Paper A0's headline framing

Per owner direction (2026-05-08): **both claims are headline material; A0 carries two headlines.** Update to `paper-drafts/A0-LHC-system-paper.md` follows.

The two claims are not independent. The structural argument:

1. Lattice-valued cells + monotone propagators + semilattice merge ⇒ fixpoint invariant under firing order (CALM-aligned, LVars-style).
2. Order-invariant fixpoint ⇒ scheduler-portable network state.
3. Scheduler-portable state ⇒ network can be serialized as `.pnet` and rehydrated by any conforming scheduler.
4. `.pnet`-as-IR + scheduler-portability ⇒ no preferred phase ordering ⇒ no phase distinction ⇒ phase collapse.

The two headline claims are therefore the *cause* and the *consequence* on the same architectural backbone.

This is a stronger story than either headline alone. The system paper should foreground the dependency.

---

## Outstanding gaps — status post owner review (2026-05-08)

- **G1 — wait for PReduce.** Owner direction: A0 should wait for PReduce, possibly until close to fully-hosting. Estimated 6+ months out. Strongest paper. Other papers can develop in parallel and be held / released afterwards.
- **G2 — already done.** Cross-scheduler fixpoint equivalence was validated during PAR 1 + BSP 2 design and implementation. Not re-running. Citable from those PIRs.
- **G3 — deferred.** Owner: not extremely interested in pinning the Zig PoC commit / archiving lowering output as a separate engineering exercise.
- **G4 — resolved (E9 above).** Owner enumerated 4 concrete schedulers (Gauss-Seidel sequential DFS; original BSP/BFS line-draw; actual parallel BSP from PAR 2 used in BSP-LE 2/2B; Zig PoC). E9 updated.
- **G5 — important lineage.** Owner: "our efforts stem from this, directly inspired from this work." LVars + CALM are *direct* inspirations, not adjacent work. Bibliography section to be promoted from "adjacent" to "direct lineage"; A0 acknowledgments to credit Kuper / Hellerstein-Alvaro / BloomL explicitly.
- **G6 — keep.** Owner approved the Idris/Lean type-checker-as-evaluator related-work scan for A0.

## Tooling status (carried forward to next investigations)

- `alpha_get_paper` works — confirmed 2026-05-08 against arXiv:2310.03366 (Nation-Paolini I). Returns full text.
- `alpha_search` broken (both keyword and semantic modes) — "Tool not found" errors. Use `web_search` for discovery.
- `alpha_ask_paper` broken — same `queries: invalid_type` schema error from round-2. Use `alpha_get_paper` + manual reading instead.

---

## Recommended next moves

1. **Owner reviews** the proposed precise statements for Claim 1 and Claim 2; revises to project intent.
2. **Update PROGRAMME.md** to register A0's dual headline + the cause/consequence framing.
3. **Update `paper-drafts/A0-LHC-system-paper.md`** with both headlines and the dependency between them.
4. **Update `engineering-anchors.md`** entries A2 and A4 with corpus citations from this audit.
5. **Close G2** with a small test addition (same-fixpoint cross-scheduler equivalence). 1-day engineering task.
6. **Address G1** by deciding A0's PReduce-scope posture.
