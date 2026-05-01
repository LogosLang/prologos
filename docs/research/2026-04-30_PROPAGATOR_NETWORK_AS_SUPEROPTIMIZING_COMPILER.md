# The Propagator Network as a Super-Optimizing Compiler: What Prologos's Architecture Adds

**Date**: 2026-04-30
**Stage**: 0/1 (research synthesis — deep frontier survey + Prologos-distinctive architectural argument)
**Series**: SH (Self-Hosting)
**Status**: Research synthesis, no design commitments
**Author**: Claude (research synthesis with comprehensive web search)

**Reading order**: Stage 0/1 artifact per [DESIGN_METHODOLOGY.org](../tracking/principles/DESIGN_METHODOLOGY.org) § Stage 1. Companion: [`2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md`](2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md) (the "how do we get there" note). This note is the "why is the destination interesting" complement. Both register against [`2026-04-30_SH_MASTER.md`](../tracking/2026-04-30_SH_MASTER.md).

---

## 1. The thesis

The standard self-hosting story ends with "compiler is in language X, compiles to native via LLVM, comparable performance to other native-compiled languages of its tier." Prologos's architecture suggests a stronger possible endpoint: a compiler that is itself a propagator-network program, structured so that **super-optimization is intrinsic to compilation** rather than a separate pass — and where the artifacts of compilation (`.pnet` propagator-network values) carry **first-class provenance**, are **content-addressable**, are **mobile across compartments**, and are **incrementally recomputable** as natural consequences of the fixpoint substrate.

This note maps what already exists in the literature, identifies what Prologos's specific infrastructure adds, and argues the case that the architectural endpoint is genuinely competitive in super-optimization territory rather than only being competitive in conventional native-compilation territory.

The thesis is not "we'll be faster than LLVM." It's: **the dimensions on which we'd be measurably distinctive — compilation correctness via category-theoretic guarantees, optimization driven by cost-weighted lattice merges, provenance carried from type-check into runtime, deployment artifacts as content-addressed values — are dimensions the existing super-optimization literature has approached one at a time. Our architecture happens to put them on the same substrate.**

The note is Stage 0/1. No design commitments. SH master tracks open with their own designs.

---

## 2. The existing super-optimization frontier (2024–2026)

### 2.1 Equality saturation: from research to production

Equality saturation — building an e-graph of program equivalences and extracting an optimal representative — is the most influential rewriting paradigm of the last decade. The canonical implementation is **egg** (Willsey et al. 2021, [arXiv:2004.03082](https://arxiv.org/abs/2004.03082)). **egglog** unifies egg with Datalog ([Better Together, HN](https://news.ycombinator.com/item?id=35593635)) and is the current state of the art.

Production-grade integration is uneven:

- **Cranelift** uses *acyclic e-graphs* — a constrained variant that "achieves production-grade performance at the cost of acyclicity, limiting the expressivity of rewrites." Single-pass eager rewriting; no full equality saturation. The trade-off: speed vs expressivity, and Cranelift chose speed ([egraphs community](https://egraphs.org/meeting/2025-08-21-dialegg)).
- **DialEgg** ([CGO 2025](https://2025.cgo.org/details/cgo-2025-papers/44/DialEgg-Dialect-Agnostic-MLIR-Optimizer-using-Equality-Saturation-with-Egglog), [DL](https://dl.acm.org/doi/abs/10.1145/3696443.3708957)) integrates egglog with MLIR dialect-agnostically. Still research, not production.
- **eqsat MLIR dialect** ([arXiv:2505.09363](https://arxiv.org/html/2505.09363v1)) proposes representing e-graphs *as* an MLIR dialect, allowing equality saturation on arbitrary domain-specific IRs.
- **LLM-guided strategy synthesis for equality saturation** ([arXiv:2604.17364](https://arxiv.org/html/2604.17364v1)) is 2026 research on scaling egglog.

**The frontier**: equality saturation is moving from "specialized tool" toward "general compiler infrastructure," but it's not there yet. The integration is bolted on (separate dialect, separate engine) rather than intrinsic.

### 2.2 Superoptimizers: synthesis vs stochastic

Two dominant approaches at the IR level:

- **Souper** ([Google, GitHub](https://github.com/google/souper)) — synthesis-based superoptimizer for LLVM IR. Uses SMT solvers to discover missing peephole optimizations. Integer-only; doesn't handle memory, FP, or vectors. Counterexample-guided synthesis ([Sasnauskas et al. 2017, arXiv:1711.04422](https://arxiv.org/pdf/1711.04422)).
- **STOKE** ([Schkufza et al. ASPLOS 2013](https://theory.stanford.edu/~aiken/publications/papers/asplos13.pdf)) — stochastic superoptimization for x86 assembly. MCMC sampling of program space. Sacrifices completeness for diversity; impressive results on small kernels.

Recent work:

- **Hydra** ([OOPSLA 2024, Utah](https://users.cs.utah.edu/~regehr/generalization-oopsla24.pdf)) generalizes Souper's peephole optimizations via program synthesis.
- **Minotaur** ([OOPSLA 2024](https://users.cs.utah.edu/~regehr/minotaur-oopsla24.pdf)) extends synthesis-based superoptimization to SIMD instructions.
- **LPO** ([arXiv:2508.16125](https://arxiv.org/html/2508.16125v2)) uses LLMs to discover missed peephole optimizations in LLVM.

**The frontier**: superoptimizers operate as *post-hoc* analyzers — they look at compiled IR and propose better versions. Synthesis-based ones (Souper, Hydra, Minotaur) are sound by construction; stochastic ones (Stoke) trade completeness for breadth.

### 2.3 Cost-driven optimization at the application layer

In application-domain compilers, cost-driven schedule search is well-established:

- **Halide** ([Ragan-Kelley et al. PLDI 2013](https://people.csail.mit.edu/jrk/halide-pldi13.pdf)) decouples algorithm from schedule; the compiler is "driven by an autotuner that stochastically searches the space of valid schedules." The 2019 autoscheduler ([Adams et al.](https://halide-lang.org/papers/halide_autoscheduler_2019.pdf)) combines beam search with a feed-forward neural network predicting execution time from handcrafted features.
- **TVM** ([Chen et al. OSDI 2018](https://www.usenix.org/system/files/osdi18-chen.pdf)) extends Halide's decoupling to deep-learning compilation. ML-based cost model adapts as data is collected from hardware backends; distributed schedule optimizer.

**The frontier**: cost-driven optimization is mature in domain-specific compilers but rarely flows into general-purpose compilers. The cost model is per-target, not language-level.

### 2.4 Interaction-net runtimes

A separate frontier worth naming because it's directly relevant:

- **HVM2** ([Taelin / HigherOrderCO](https://github.com/HigherOrderCO/HVM2), [paper](https://docs.rs/crate/hvm/latest/source/paper/PAPER.pdf)) — interaction-combinator runtime, beta-optimal, massively parallel. Performance numbers: 400 MIPS single-thread (Apple M3 Max) → 5,200 MIPS (16 threads) → 74,000 MIPS (RTX 4090, 32,768 threads). Interaction nets have the property that "if a net reduces to a value in n steps, then any sequence of reductions will reach that value in n steps" — order-independence yields automatic parallelism.
- **Bend** is a high-level language built on HVM2.
- **Lafont 1990, 1997** founding work; **Fernandez 2013** PhD thesis on concurrency in interaction nets.

The relevance: HVM2 demonstrates that *interaction-combinator runtimes can be massively parallel and competitive*. Track 9 / PReduce work points in the same direction.

### 2.5 Geometry of Interaction abstract machines

The third leg of the rewriting-for-compilation frontier:

- **Mackie's GoI Machine** and **Ghica's Geometry of Synthesis (GoS)** — token-passing abstract machines for the lambda calculus. Translate term to a graph, evaluate by passing a token around.
- **Dynamic GoI Machine** (Muroya & Ghica, [LMCS](https://lmcs.episciences.org/5882/pdf), [arXiv:1803.00427](https://arxiv.org/abs/1803.00427)) — combines token passing with graph rewriting. Sound and complete for CBN, left-to-right CBV, right-to-left CBV. Trade-off: pure token passing favors space efficiency at cost of time; DGoIM recovers both.

The relevance: GoI semantics gives a categorical foundation for graph-rewriting evaluation; it's the theoretical backbone connecting interaction nets to logical proof structure.

### 2.6 Self-hosting peer systems

For comparison points:

- **Lean 4** is self-hosted in Lean 4. Performance: 2-4× faster typecheck vs Lean 3, mathlib4 builds in ~2300s vs ~5400s in Lean 3 ([benchmarks](https://github.com/lacker/lean4perf)). Compilation infrastructure: register-based bytecode VM + LLVM native backend ([emergentmind summary](https://www.emergentmind.com/topics/lean-benchmarks)). **Lean4Lean** provides a verified self-hosted kernel with 20-50% overhead.
- **Idris 2** is self-hosted in Idris 2 ([FAQ](https://idris2.readthedocs.io/en/latest/faq/faq.html)). Compilation pipeline: Idris 2 syntax → TTImp → QTT → CExp → Chez Scheme. QTT erasure is explicit in types (cleanest precedent for our QTT story). Self-compiles in ~93s on a Dell XPS 13.
- **MLIR** ([dialect tower](https://mlir.llvm.org/docs/Tutorials/Toy/Ch-6/)) is the modern multi-level-IR compiler infrastructure. Progressive lowering through dialects; arith / index / memref / scf / func at high level, LLVM dialect at low level. The **Transform Dialect** ([arXiv:2409.03864](https://www.arxiv.org/pdf/2409.03864v2)) makes optimization passes themselves programmable.
- **GHC** uses the STG (Spineless Tagless G-machine) to Cmm to native pipeline. Two-layer IR with optimization opportunities at each level.

---

## 3. What Prologos's architecture has that the existing literature combines piecewise

Each of the items below corresponds to multiple separate research efforts in the existing literature. Our specific infrastructure happens to put them on the same substrate.

### 3.1 The propagator network IS the IR

In the existing landscape, optimization frameworks are bolted *onto* compilers:

- egg/egglog → MLIR via DialEgg or eqsat dialect (separate engine, separate dialect)
- Souper → LLVM IR analyzer (separate post-hoc pass)
- Halide autoscheduler → ML cost model (separate optimizer above the IR)
- HVM → interaction-combinator runtime (entirely separate runtime model)

Our position: per [`2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md`](2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md) and the PPN/SRE/PM series progress, **the propagator network is itself the intermediate representation**. There is no "high-level IR + optimization framework on top" stack; there is one substrate, with cells holding lattice values and propagators implementing the lattice merges. Typing rules, reduction rules, optimization rules, and code-generation rules all fire on the same network as propagators.

This is structurally the same move MLIR made (multi-level IR with dialects) but at runtime granularity rather than at static-pass granularity. Our "dialects" are SRE-registered domains; our "passes" are propagator firings; our "lowering" is a stratified scheduler choosing which propagators fire when. The architecture is born super-optimizing because the optimization is *the same kind of thing* as the typing.

### 3.2 Tropical/quantale cost is intrinsic, not a separate pass

In the existing landscape:

- TVM/Halide build cost models *outside* the IR.
- egg's extraction phase requires a separate cost function applied after saturation.
- Cranelift's acyclic e-graphs use eager rewriting with a fixed extraction strategy (no full saturation).

Our position: per [`2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md`](2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) and the Track 9 / PReduce direction, **cost lives in the cells themselves as tropical-quantale-valued lattice elements**. Each cell carries a cost; each merge takes the tropical minimum (cheapest derivation wins, per Viterbi-style semiring parsing). When multiple rewrite paths converge on the same cell, the cost-bounded propagator network keeps the cheapest. The cost function is not a separate post-saturation extraction — it's the merge operation.

This is operationally what egg does (saturate, extract by cost), but at the substrate level rather than the engine level. **Equality saturation happens automatically when cells are tropical-quantale-valued and propagators implement rewriting rules.** No separate engine.

### 3.3 Adhesive-category guarantees for free

In the existing landscape, equality-saturation correctness is hard:

- egg's rewrites must be carefully audited for soundness.
- Cranelift's acyclic e-graphs gives up some correctness guarantees for speed (single-pass eager rewriting can apply an unsound sequence).
- Hydra (OOPSLA 2024) generalizes Souper-discovered optimizations *with* synthesis-based correctness.

Our position: **e-graphs are adhesive** (Biondo, Castelnovo, Gadducci, [CALCO 2025](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md)). Adhesive categories axiomatize the conditions for DPO rewriting to be well-behaved — local Church-Rosser, parallelism, concurrency, critical-pair completeness. The SRE Track 2D infrastructure already implements DPO rewriting on parse trees; the Adhesive Categories research note grounds the claim formally. **`prop:ctor-desc-tag` guarantees no critical pairs** ([SRE Track 2 PIR](../tracking/2026-03-23_SRE_TRACK2_PIR.md)) — confluence by construction. Rewrites that compose the SRE's four relations (equality, subtype, duality, rewrite) inherit the full DPO toolkit.

We don't trade speed for correctness. Adhesive theory says the optimization is correct *and* parallelizable. Cranelift's acyclic compromise is unnecessary for our substrate.

### 3.4 First-class provenance from typecheck into runtime

In the existing landscape, provenance is afterthought:

- GHC carries debug info; production-grade provenance is a research effort.
- Souper / Hydra / Minotaur produce optimizations; the *justification* is in the synthesis logs, not in the compiled program.
- Cranelift and MLIR can pass through source locations but don't carry typing derivations.

Our position: per [`provenance.rkt`](../../racket/prologos/provenance.rkt), [`atms.rkt`](../../racket/prologos/atms.rkt), and the explicit `expr-derivation-type` first-class derivation mechanism, **every cell value has a derivation tree recording why the value is what it is**. Type inference, capability inference, trait resolution, reduction — all produce ATMS-tracked support sets. When `.pnet` extends to round-trip propagator structure (Track 1 in the SH master), **the deployment artifact carries derivations into runtime**. A program shipped as `.pnet` can answer "why does this function require ReadCap?" and "which clauses contributed to this value?" at runtime, not just at compile time.

This is what the [Capability Safety / Datalog research note](2026-04-23_CAPABILITY_SAFETY_DATALOG_HYPERGRAPHS.md) calls out as Prologos's specific contribution to the multi-agent / explainable-AI space. It's the same architectural feature applied here.

### 3.5 Incremental compilation as a natural consequence

In the existing landscape, incremental compilation is engineered:

- **rustc** uses **Salsa** ([rustc dev guide](https://rustc-dev-guide.rust-lang.org/queries/salsa.html), [Matsakis](https://rustc-dev-guide.rust-lang.org/queries/incremental-compilation.html)) — a generic framework for on-demand, incrementalized computation. Queries cache results; cache invalidation tracks dependencies.
- **Tree-sitter** does incremental parsing.
- GHC's recompilation checking is module-granularity.

Our position: **incremental compilation falls out of monotone fixpoint computation as a structural property**. When a cell value changes, only propagators that depend on it (transitively) need to refire. CHAMP persistent data structures preserve unchanged sub-network state automatically. The BSP scheduler's worklist-based firing is exactly demand-driven recomputation. **We don't need a Salsa-style query system; we have one for free in the substrate.**

The engineering work to make this concrete — fine-grained dependency tracking, smart re-firing, output diffing — is real, but it's substrate-level rather than added-on. `.pnet` already supports module-level caching with cell-state preservation. Cell-level incrementality is an extension of the same architecture, not a separate framework.

### 3.6 Network mobility and content addressing

In the existing landscape, deployment artifacts are platform-specific binaries:

- LLVM produces native object files; deployment is per-architecture.
- WASM gives portability but loses provenance and structure.
- IPVM / Fission Codes' content-addressed Wasm is the closest precedent ([prior research note](2026-04-23_CAPABILITY_SAFETY_DATALOG_HYPERGRAPHS.md)).

Our position: **`.pnet` is content-addressable by construction**. A propagator network has a stable hash determined by its cell values + propagator structure. Two `.pnet` files with the same hash are not just bit-equal — they're *fixpoint-equal with the same derivation tree*. This is a stronger equivalence than IPVM's deterministic-Wasm hashing, and it carries the explainability story across the wire.

The multi-agent / Vat vision wants this. Stage A.5 substrate work + `.pnet` Track 1 work delivers it.

### 3.7 Stratified rewriting subsumes pass ordering

In the existing landscape, pass ordering is a perennial compiler problem:

- LLVM optimizer pipelines are extensively tuned; pass ordering affects output quality.
- MLIR's Transform Dialect ([arXiv:2409.03864](https://www.arxiv.org/pdf/2409.03864v2)) makes pass scheduling programmable but still phase-ordered.

Our position: per [`stratification.md`](../../.claude/rules/stratification.md), the propagator scheduler runs *strata* (S0 monotone, S1 NAF, S(-1) retraction, topology). Each stratum reaches fixpoint before the next runs; within a stratum, propagators fire in dataflow order. **Pass ordering is replaced by lattice structure**: monotone optimizations live at S0, non-monotone at higher strata. There's no "is this pass before or after that pass?" question — it's "what stratum does this rule live in?" and the answer is determined by the rule's algebraic properties (monotone, retracting, topology-changing).

This is the architectural equivalent of MLIR's progressive lowering, but driven by lattice algebra rather than pass-pipeline configuration.

---

## 4. Comparison table

| Dimension | GHC | Lean 4 | Idris 2 | MLIR | Cranelift | egg/egglog | HVM2 | **Prologos (architectural endpoint)** |
|---|---|---|---|---|---|---|---|---|
| Self-hosted | ✅ | ✅ | ✅ | N/A | ❌ | ❌ | ❌ | Stage B target |
| QTT erasure | ❌ (ad-hoc) | ❌ (ad-hoc) | ✅ | N/A | ❌ | N/A | N/A | ✅ already shipped |
| E-graph rewriting | ❌ | ❌ | ❌ | DialEgg | acyclic | ✅ engine | N/A | ✅ adhesive, integrated |
| Cost-driven optimization | ❌ | partial | ❌ | research | partial | extraction | N/A | tropical-quantale on cells |
| First-class provenance | debug-info | proof terms | proof terms | source locs | source locs | rewrite logs | N/A | ATMS in .pnet |
| Incremental compilation | module-level | partial | partial | partial | partial | N/A | N/A | cell-level via fixpoint |
| Content-addressable artifacts | ❌ | ❌ | ❌ | ❌ | ❌ | N/A | N/A | .pnet |
| Adhesive guarantees | ❌ | ❌ | ❌ | ❌ | ❌ | research | N/A | ✅ via SRE |
| Dependent types | ❌ | ✅ | ✅ | N/A | N/A | N/A | N/A | ✅ |
| Capabilities (OCap-style) | ❌ | ❌ | ❌ | N/A | N/A | N/A | N/A | ✅ |
| Session types | ❌ | ❌ | ❌ | N/A | N/A | N/A | N/A | ✅ |
| Massively parallel evaluation | ❌ | ❌ | ❌ | N/A | N/A | N/A | ✅ | Track 9 target |
| Single substrate | STG+Cmm | bytecode+LLVM | TTImp+CExp+Scheme | dialect tower | acyclic e-graph | engine | combinator IR | propagator network |

The architectural endpoint isn't faster than any of these on every dimension — it's *distinctive in combining* the dimensions on the same substrate. The literature picks two or three; Prologos's architecture, if executed, picks all twelve.

---

## 5. The PReduce / Track 9 piece — why it's the linchpin for this story

The companion path note ([`2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md`](2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md) §5) commits to PReduce-first ordering. From the super-optimization frame, this ordering is even more load-bearing than the path-note framing alone suggests:

**PReduce is what makes the architectural endpoint a *super-optimizing* compiler rather than just a compiler.** The pieces:

- Reduction-as-DPO-rewriting (§3.3 above) lands the adhesive-category guarantees.
- Tropical-quantale cost on cells (§3.2 above) lands the cost-driven optimization.
- E-graph-based equality saturation as a *consequence* of the above (per [`2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md`](2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md): "the e-graph's equality saturation explores all rewrites; the tropical extraction picks the cheapest equivalent program. This is exactly egg/egglog's extraction phase.").
- Interaction-net-style parallelism (§2.4 HVM2 reference) lands the massively-parallel evaluation, since reduction-on-propagators inherits the order-independence property.
- GoI-machine-style token passing (§2.5) provides the abstract-machine semantics for evaluation; DGoIM gives soundness for multiple evaluation strategies.

After PReduce delivers, the architectural endpoint becomes: a compiler that does e-graph-style equality saturation as part of its normal evaluation, with adhesive guarantees, with tropical-cost-driven extraction, with first-class provenance, all on the same substrate that does typing and elaboration. That's a position no current production compiler holds.

Track 9 is the work that lifts the destination from "competitive with Lean 4 / Idris 2 in functional-language space" to "in the super-optimization frontier alongside egg/egglog / Souper / HVM."

---

## 6. What's speculative vs grounded

This note makes claims at varying strength levels. Honest separation:

### Grounded today

- The propagator network is the IR (PPN Tracks 1-2 done; Track 4 in flight; the architectural commitment is committed).
- E-graphs are adhesive (Biondo et al. CALCO 2025 — external result).
- The SRE form registry guarantees no critical pairs (`prop:ctor-desc-tag`, SRE Track 2 PIR).
- ATMS provenance exists (`atms.rkt`, 877 lines, capability-inference uses it).
- `.pnet` exists (~735ms load vs ~20s cold start).
- QTT erasure is well-defined (qtt.rkt, 2462 lines).
- Capability typing infrastructure exists (capability-inference.rkt, 655 lines).
- Session types on propagators (session-propagators.rkt, 633 lines).

### Designed but not delivered

- Track 9 / PReduce: tropical-quantale-cost reduction with e-graph saturation. Stage 1 research, design pending. The adhesive grounding is in place; the implementation is the work.
- Stage A.5 / LLVM substrate (SH master Tracks 1-8). Trajectory designed; no code.
- Network mobility via `.pnet`: format exists but doesn't currently round-trip propagator structure.
- Incremental compilation at cell level: substrate supports it naturally; no engineering yet.
- Per-domain canonical form (per the Lattice Variety research note 2026-04-30) — would tighten the optimality story further.

### Speculative

- That tropical-quantale-on-cells delivers competitive super-optimization in practice. The theory is clear; empirical validation requires Track 9 to land.
- That the combined architecture *meaningfully outperforms* the existing literature on at least one dimension. The combination is novel; whether the combination is also faster, more correct, or more usable is an empirical question.
- That the parallel-evaluation properties HVM2 demonstrates carry over directly to our substrate. Interaction nets are a specific algebraic structure; propagator networks are more general. The order-independence might or might not carry; need to verify.
- That `.pnet` content-addressing scales to large programs. CHAMP scales; whether the full propagator-network value hashes cleanly at scale is empirical.

---

## 7. Open research questions

1. **What's the right cost lattice?** Tropical (min-plus) is the obvious choice for Viterbi-style cheapest-derivation extraction. But propagator networks support richer quantales (per `OE Series` work, [`2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md`](../tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md)). What about combined cost lattices — instruction count × code size × power consumption × latency? The quantale framework gives us the algebra; the design choice is which combination matters.

2. **How does dependent typing interact with super-optimization?** Equality saturation in dependently-typed contexts is an open frontier ([Moss 2025, "E-Graphs with Bindings", arXiv:2505.00807](https://arxiv.org/abs/2505.00807) starts on this). Dependent types add binding structure that complicates rewriting. We have both; the integration is research territory.

3. **Can we use LLM-guided strategy synthesis?** [LLM-Guided Strategy Synthesis for Scalable Equality Saturation, arXiv:2604.17364](https://arxiv.org/html/2604.17364v1) is current research. Our network-as-data architecture would let LLMs propose new propagators directly as data. Worth experimenting once the substrate is in place.

4. **What does `.pnet` bring to remote compilation?** Content-addressed compiled artifacts → distributed compilation cache → "compile once, run anywhere" not in the WASM sense (portable execution) but in the propagator-network sense (portable derivation). Cf. the Vat / DCR vision.

5. **Where does the GoI-machine connection lead?** Token-passing GoI gives us a low-level execution model with formal semantics. DGoIM combines token passing with graph rewriting — exactly our setup. Could `.pnet` execution literally be a DGoIM, parameterized by lattice? Open theoretical question with implementation implications.

6. **Is the adhesive guarantee load-bearing for super-optimization at scale?** Acyclic e-graphs (Cranelift) work in production by giving up some correctness; adhesive theory says we don't have to. Empirical question whether the correctness guarantees translate into measurable perf benefits when combined with the cost lattice.

7. **How does this play with Lean 4 / Idris 2 type-checking?** Both have dependent types and reasonable performance. If Track 9 delivers super-optimized reduction, would Prologos's typecheck be measurably faster, or just equally fast with better provenance? The benchmark would be load-bearing for the "competitive on speed too" claim.

8. **What's the right MLIR-style dialect-tower analog?** MLIR's progressive lowering is well-engineered. Our substrate is dialect-free at runtime (lattice domains *are* dialects). Is there any value in adding a static "lowering tower" between propagator network and LLVM IR, or is the substrate-direct approach sufficient?

---

## 8. Implementation note for SH series

This note's contribution to the SH master tracker:

- **Track 9 / PReduce is a CRITICAL cross-series dependency**, not merely a "performance fix." It's what shifts the architectural endpoint from "self-hosted competitive language" to "self-hosted super-optimizing compiler." Prioritization in the SH master should reflect this: SH tracks gate behind PReduce delivery for the super-optimization story to land.
- **Track 1 (`.pnet` network-as-value) is the substrate enabler**. With Track 1 done, `.pnet` becomes the deployment-artifact format and the content-addressable / mobile / provenance-carrying claims become concrete rather than aspirational.
- **Track 4 (production LLVM substrate) is the ceiling-raising work**. After Track 9 + Track 1, native compilation removes the constant-factor handicap.
- **Track 9 + Track 1 + Track 4 together = the super-optimization-on-native story**. Each is necessary; none alone is sufficient.

Recommended ordering of SH-aware research tracks (each can be a separate Stage 1 note):

1. **Cost lattice design** — what tropical / quantale / combined cost structure does PReduce target? Fed by `2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md` and OE Series.
2. **`.pnet` extension architecture** — how do propagators-as-data work? Fed by NTT progress and SRE Track 2D adhesive-DPO.
3. **Native runtime architecture** — GC, concurrency, FFI, scheduling. Fed by `RESEARCH_GC.md` and `RESEARCH_RUST_LLVM_LANGUAGE_IMPLEMENTATION.md`.
4. **Type erasure boundary** — what survives runtime? Fed by Idris 2's QTT precedent and capability-typing research.
5. **Bootstrap mechanics** — DDC, reproducible builds, verification. Fed by Wheeler 2005.

The companion path note ([`2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md`](2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md)) carries the bootstrap-stage trajectory; this note carries the architectural-distinctiveness argument. Together they establish the SH series's purpose — not just to retire Racket, but to deliver an architecturally distinctive compiler when the retirement lands.

---

## 9. References

### Equality saturation (production frontier)
- Willsey, M., et al. (2021). egg: Fast and Extensible Equality Saturation. [arXiv:2004.03082](https://arxiv.org/abs/2004.03082)
- DialEgg (CGO 2025). [Conference page](https://2025.cgo.org/details/cgo-2025-papers/44/DialEgg-Dialect-Agnostic-MLIR-Optimizer-using-Equality-Saturation-with-Egglog) / [DL](https://dl.acm.org/doi/abs/10.1145/3696443.3708957)
- eqsat MLIR dialect. [arXiv:2505.09363](https://arxiv.org/html/2505.09363v1)
- LLM-Guided Strategy Synthesis for Scalable Equality Saturation. [arXiv:2604.17364](https://arxiv.org/html/2604.17364v1)
- Cranelift acyclic e-graphs. [egraphs community](https://egraphs.org/meeting/2025-08-21-dialegg)
- Schlatt, A. (2026). E-Graphs as a Persistent Compiler Abstraction. [arXiv:2602.16707](https://arxiv.org/abs/2602.16707)
- Moss, A. (2025). E-Graphs with Bindings. [arXiv:2505.00807](https://arxiv.org/abs/2505.00807)
- Tate-Stepp-Tatlock (2009). Equality Saturation: A New Approach to Optimization. *POPL '09*.

### Superoptimizers
- Souper. [GitHub](https://github.com/google/souper)
- Sasnauskas, R., et al. Souper: A Synthesizing Superoptimizer. [arXiv:1711.04422](https://arxiv.org/pdf/1711.04422)
- Schkufza, E., et al. (2013). Stochastic Superoptimization. *ASPLOS '13*. [PDF](https://theory.stanford.edu/~aiken/publications/papers/asplos13.pdf)
- Hydra (OOPSLA 2024). [PDF](https://users.cs.utah.edu/~regehr/generalization-oopsla24.pdf)
- Minotaur (OOPSLA 2024). [PDF](https://users.cs.utah.edu/~regehr/minotaur-oopsla24.pdf)
- LPO (2025). [arXiv:2508.16125](https://arxiv.org/html/2508.16125v2)

### Cost-driven application compilers
- Halide (PLDI 2013). [PDF](https://people.csail.mit.edu/jrk/halide-pldi13.pdf)
- Halide autoscheduler (2019). [PDF](https://halide-lang.org/papers/halide_autoscheduler_2019.pdf)
- TVM (OSDI 2018). [PDF](https://www.usenix.org/system/files/osdi18-chen.pdf)

### Interaction nets / GoI / runtime
- Lafont, Y. (1990). Interaction nets. *POPL '90*.
- Lafont, Y. (1997). Interaction Combinators.
- Girard, J.-Y. Geometry of Interaction I-V.
- Mackie, I. (1995). The Geometry of Interaction Machine.
- Muroya & Ghica (2017, 2018). Dynamic GoI Machine. [LMCS](https://lmcs.episciences.org/5882/pdf), [arXiv:1803.00427](https://arxiv.org/abs/1803.00427)
- Fernandez, M. (2013). PhD thesis, Concurrency in Interaction Nets and Graph Rewriting.
- HVM2 ([Taelin / HigherOrderCO](https://github.com/HigherOrderCO/HVM2)), [paper](https://docs.rs/crate/hvm/latest/source/paper/PAPER.pdf)

### Self-hosting peer systems
- Lean 4 self-hosting + perf. [lean4perf](https://github.com/lacker/lean4perf), [emergentmind summary](https://www.emergentmind.com/topics/lean-benchmarks)
- Idris 2 self-hosting + Chez Scheme + QTT. [Idris 2 docs](https://idris2.readthedocs.io/en/latest/faq/faq.html), [Chez backend](https://idris2.readthedocs.io/en/latest/backends/chez.html)
- MLIR dialect tower. [Toy tutorial Ch 6](https://mlir.llvm.org/docs/Tutorials/Toy/Ch-6/), [Transform Dialect](https://www.arxiv.org/pdf/2409.03864v2)
- GHC STG/Cmm pipeline. (Standard Haskell Compilation Pipeline references)

### Adhesive theory
- Lack & Sobocinski (2005). Adhesive categories.
- Biondo, Castelnovo, Gadducci (CALCO 2025). E-graphs are adhesive. (Cited in [`2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md`](2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md))

### Bootstrap verification
- Thompson, K. (1984). Reflections on Trusting Trust. CACM 27(8).
- Wheeler, D. A. (2005). Diverse Double Compilation. ACSAC '05.

### Incremental compilation
- Salsa (rustc query system). [rustc dev guide](https://rustc-dev-guide.rust-lang.org/queries/salsa.html)
- Tree-sitter incremental parsing. [GitHub](https://github.com/tree-sitter/tree-sitter)

### Prologos prior research
- [SH Master](../tracking/2026-04-30_SH_MASTER.md) — series tracker
- [Self-Hosting Path and Bootstrap Stages](2026-04-30_SELF_HOSTING_PATH_AND_BOOTSTRAP.md) — companion (the "how do we get there" note)
- [S-Expression IR to Propagator Compiler](2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md) — original four-phase trajectory
- [Hypergraph Rewriting + Propagator Parsing](2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — DPO theory + e-graphs + interaction nets
- [Adhesive Categories and Parse Trees](2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) — formal foundations
- [Tropical Optimization + Network Architecture](2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) — cost-weighted rewriting
- [Track 9 Reduction-as-Propagators](../tracking/2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md) — PReduce founding research
- [PRN Master](../tracking/2026-03-26_PRN_MASTER.md) — Propagator-Rewriting-Network theory series
- [Capability Safety as Datalog Hypergraphs](2026-04-23_CAPABILITY_SAFETY_DATALOG_HYPERGRAPHS.md) — Spera papers + multi-agent vision
- [Categorical Foundations of Typed Propagator Networks](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) — polynomial functors, Lafont, Girard

---

## 10. One-paragraph executive summary

The existing super-optimization frontier addresses individual dimensions through specialized engines: equality saturation via egg/egglog (with research-grade MLIR integration via DialEgg, production-grade-but-restricted via Cranelift's acyclic e-graphs); SMT-based and stochastic superoptimization at the IR level via Souper / Hydra / Stoke / Minotaur; cost-driven scheduling at the application layer via Halide/TVM; massively-parallel interaction-net runtimes via HVM2; token-passing abstract machines via the GoI lineage. Each engine is bolted onto a host compiler. Prologos's architectural endpoint, when SH stages land and Track 9 / PReduce delivers, **puts these dimensions on the same substrate**: the propagator network is the IR (no separate engine), tropical-quantale cost lives in cells (equality-saturation extraction is the merge operation), adhesive-category guarantees give correctness for free (no Cranelift-style trade-off), ATMS provenance threads from typecheck into runtime (no debug-info afterthought), incremental compilation falls out of monotone fixpoint (no Salsa-style query system needed), `.pnet` content-addressing makes deployment artifacts mobile values (IPVM-style portability with stronger equivalence), and stratified scheduling subsumes pass ordering (no LLVM-style pipeline tuning). The thesis is not "we'll be faster than LLVM" — it's that the combination of dimensions is novel, the combination happens to land on the same substrate by virtue of the architectural commitments already made, and the combination is what makes self-hosted Prologos genuinely distinctive in the super-optimization frontier rather than only competitive in the conventional native-compilation tier. Track 9 / PReduce-first ordering is what makes the destination interesting; SH-series stages A.5 → B → C are what make the destination shippable. Stage 0/1; no design commitments.
