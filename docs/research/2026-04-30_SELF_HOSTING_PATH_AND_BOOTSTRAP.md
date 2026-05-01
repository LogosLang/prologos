# Self-Hosting Path and Bootstrap Stages

**Date**: 2026-04-30
**Stage**: 0/1 (research synthesis + implementation-track-suggestion note — not a design)
**Series**: SH (Self-Hosting)
**Status**: Research note — captures conversation outputs and bootstrap-stage trajectory; no design commitments
**Author**: Claude (research synthesis from extended dialogue)

**Reading order**: Stage 0/1 artifact per [DESIGN_METHODOLOGY.org](../tracking/principles/DESIGN_METHODOLOGY.org) § Stage 1. Companion: [`2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md`](2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md) (deeper research report on Prologos-distinctive contribution). Both register against [`2026-04-30_SH_MASTER.md`](../tracking/2026-04-30_SH_MASTER.md).

**Source dialog**: 2026-04-30 multi-turn research conversation on self-hosting. This note captures the outputs.

---

## 1. Why this note exists

Two formulations of "self-hosting" are common, and they get conflated:

- *Standard / metacircular*: "the X compiler is written in X." Eventually, yes. Today, no — Phase 0 is `#lang racket/base` per [`CLAUDE.md`](../../CLAUDE.md).
- *Specific to Prologos*: "the compiler is structured as cells + propagators on a propagator network — the same substrate user programs run on." This is the load-bearing architectural commitment, expressed in [`structural-thinking.md`](../../.claude/rules/structural-thinking.md), [`on-network.md`](../../.claude/rules/on-network.md), and the active PPN/SRE/PM/BSP-LE/CIU work.

A friend's question in the source dialogue sharpened the picture further: even when both senses are achieved, "the substrate is implemented in Racket" remains true unless the substrate is *also* retired from Racket. That is the **two-axis retirement** observation. This note formalizes the staging.

The note is Stage 0/1. No design commitments. SH series tracks open with their own designs when prerequisites are met.

---

## 2. Three layers, two retirement axes

The system stacks three things:

1. **Substrate** — propagator-network primitives: cell allocation, propagator installation, BSP scheduler, CHAMP persistent maps, ATMS, stratification. Currently Racket (`propagator.rkt`, ~5K lines).
2. **Compiler** — program that takes Prologos source → propagator-network artifacts. Currently Racket; structured (with ongoing work) as cells/propagators on the substrate from layer 1.
3. **User programs** — Prologos programs that compile to propagator-network executions on the same substrate.

The friend's first question collapsed (1) and (2) into "the compiler"; that's the standard-self-hosting framing. The sharper question separates them and asks for the retirement story for *each*. Two axes:

- **Axis 1 (runtime Racket)**: substrate (1) becomes native, no longer Racket-implemented. Deployed Prologos programs run as native binaries.
- **Axis 2 (compile-time Racket)**: compiler (2) becomes Prologos, no longer Racket-implemented. Prologos developers no longer need Racket.

Most languages retire axis 1 well before axis 2. GHC's runtime is C and has been since the 1990s; the Haskell-in-Haskell port came much later. Rust bootstrapped from OCaml; once `rustc` self-hosted, the OCaml stage retired. **There's no requirement that both retire simultaneously, and nothing in our architecture requires it either.**

---

## 3. Stages: A → A.5 → B → C

### Stage A (current, 2026-04-30)

- Substrate: Racket
- Compiler: Racket; increasingly structured as cells/propagators on substrate
- User programs: compiled by Racket, run by Racket-hosted substrate

Active series filling out the architectural commitment that "compiler IS network": PPN, SRE, PM, BSP-LE, CIU. PPN Track 4 (compiler IS the network) is the load-bearing prerequisite for everything downstream — once it lands, the architectural claim moves from "in progress" to "delivered." All other SH-series tracks gate on it.

**Compiler perf characterization** ([`2026-04-01_PPN_TRACK3_DESIGN.md`](../tracking/2026-04-01_PPN_TRACK3_DESIGN.md) §2.3): on a 70-command `.prologos` file, parse 0ms (unmeasurable), elaboration+typecheck 443ms (27%), **reduction 1049ms (64%)**. Reduction is the dominant cost. Track 9 / PReduce addresses this.

### Stage A.5 — runtime Racket retired (axis 1)

Substrate primitives implemented as LLVM-compiled native code. Compiler still in Racket, emitting two things: (i) compiled user programs as `.pnet` propagator-network values, (ii) the substrate primitives themselves as a runtime library. Deployed Prologos programs run native; no Racket process anywhere on the user's machine.

This is the major engineering lift. Tracks 1, 2, 3, 4, 5, 6, 7, 8 in the SH master. Most are well-scoped engineering once the prerequisites land; Track 4 (production substrate) is the multi-quarter centerpiece.

The clean break: any deployed Prologos program is shippable as a single native binary. Build still requires Racket; users don't.

### Stage B — compile-time Racket retired (axis 2)

Compiler ported to Prologos. Substrate already native (post stage A.5). The Prologos-version-of-Prologos-compiler emits LLVM IR. The Racket compiler retires.

Bootstrap procedure is the standard "trusting trust" two-step:
1. Use Racket-Prologos compiler to compile the Prologos-Prologos compiler to native.
2. Run that native binary; have it compile itself.
3. Compare output of step 2 with input of step 2. If equivalent, the bootstrap is faithful.
4. Discard the Racket version. The bootstrap chain is broken.

Track 9 in the SH master.

### Stage C — bootstrap verified

Diverse Double Compilation (Wheeler 2005). Reproducible builds. The Racket dependency is now *historical only* — a record of how the first stage-B binary came to exist, not a live dependency. End of the trail.

Track 10 in the SH master.

---

## 4. `.pnet` as the runtime artifact format (the structural linchpin)

[`pnet-serialize.rkt`](../../racket/prologos/pnet-serialize.rkt) (679 lines) is current state: serializes elaboration state (cells + 10 registries + metadata + foreign proc references + gensym tags) via struct→vector + tag dispatch. Round-trip 735ms vs 20s cold-start. **Critically: the propagator and elaboration networks themselves are replaced with sentinels and rebuilt fresh on load** ([pnet-serialize.rkt:104, 428](../../racket/prologos/pnet-serialize.rkt)). So `.pnet` captures *what was elaborated*, not *the live network that did the elaborating*.

For self-hosting, this is the gap. A "compiled Prologos program" should be a propagator-network value you load and run. We have half: the cell values and registry state. We don't yet serialize the propagator structure (the topology of what watches what, the merge functions in their executable form). When that's done, `.pnet` becomes the deployment artifact format. Stage A.5 unlocks.

Why it's "the linchpin": at stage A.5, the substrate is native LLVM-compiled code. It needs an *input* to load and execute. That input is a serialized propagator network. The `.pnet` format extension to round-trip propagator structure is what makes the substrate-on-LLVM path concrete rather than vaporware. Track 1 in the SH master is this work.

The hard part: merge functions are Racket closures today. They need to become *symbolic references* to merges registered in the SRE form registry, dispatched at load time. This connects to NTT-style declarative propagator definitions — propagators-as-data, not propagators-as-Racket-procedures. The work is partly upstream of NTT progress.

---

## 5. Ordering: PReduce-first, then SH

Working ordering established in source dialogue:

1. **Land PReduce / Track 9 first.** Reduction-as-propagators with tropical/quantale cost optimization, e-graph-style equality saturation, DPO hypergraph rewriting, super-optimization. The 64%-of-compile-time reduction cost gets fixed *in Racket* via algorithmic change, not via LLVM port.
2. **Then SH series.** With PReduce delivered, self-hosted Prologos has a competitive performance story before any porting begins. Stage A.5 then ports an already-fast algorithm to native code; the multiplicative win lands.

This ordering deliberately separates *algorithmic* perf wins (PReduce, in Racket) from *constant-factor* perf wins (LLVM port). Doing them in this order means LLVM lowers an already-fast algorithm; the multiplicative gain compounds. Doing them in reverse means porting a slow algorithm and getting a slightly-less-slow algorithm.

The Track 9 work is not in the SH series — it's in PReductions/PRN. SH lists it as a cross-series dependency. SH tracks open after Track 9 delivers (or in parallel with Track 9 for the lowest-risk SH work, e.g., Track 1 `.pnet` extension which has independent value).

**Trade-off named:** strict serial ordering (PReduce fully done → SH starts) is conservative. Interleaving (PReduce in flight → SH Track 1 in parallel since `.pnet` work is independent) is faster but introduces stage-confusion risk if either side pivots. Resolution: defer to track-opening time; SH master open question 7 records the decision point.

---

## 6. PoC scope (Track 3)

Smallest end-to-end validation of the substrate-on-LLVM path:

- **Slice**: simply-typed lambda calculus. No dependent types, no QTT, no sessions, no capabilities. Simplest possible Prologos subset.
- **Compile path**: existing Racket compiler elaborates a small program in this slice. Track 1 `.pnet` extension captures the result as a propagator-network value.
- **Runtime path**: Track 4-precursor minimal LLVM-compiled substrate (cells + propagators + BSP, ~500-1500 lines of Rust or C++). Loads the `.pnet`, allocates native memory, dispatches propagators, runs BSP to quiescence, prints result.
- **Validation**: end-to-end execution outside Racket; native-vs-Racket perf comparison on this slice.

What this validates: substrate primitives are implementable outside Racket; `.pnet` can be loaded by something that's not the Racket compiler; propagator-network execution model survives translation to imperative native code.

What this *doesn't* validate: full language coverage, perf on large programs, GC at scale, FFI, capabilities, sessions, dependent types. Those are stage A.5 production concerns; the PoC just opens the door.

**Estimated scope**: 1-2 weeks of focused work, given Track 1 `.pnet` extension exists. Without Track 1, scope inflates to 3-4 weeks because the PoC has to invent its own serialization format.

**Smaller alternative** (one-week scope): skip `.pnet` entirely. Hand-write a propagator network in Rust/C++ that implements one specific Prologos elaboration (e.g., type-checking `id : forall a. a -> a`). Get it running, measure latency vs Racket. Less interesting end-to-end but proves the substrate-primitives-in-LLVM claim with minimum dependency.

---

## 7. Runtime services to flag (Track 6)

Racket gives us four things "for free" today; native substrate must provide all four:

### 7.1 Garbage collection

Options ranked by ambition:
- **Boehm-Demers-Weiser conservative GC** (BDW): few-thousand-line dependency, well-tested, gets us up fast. Performance ceiling is real but acceptable for stage A.5 first cut. Idris 2 used this initially.
- **MMTk integration**: Memory Management Toolkit — modular, multi-language, configurable collectors (semi-space, mark-region, immix). More work to integrate, more competitive performance, future-proof. Active development; Rust ecosystem support is mature.
- **Region-based + reference-counting + epoch reclamation, CHAMP-aware**: most ambitious; aligned with the persistent-data architecture (CHAMP gives us natural sharing, refcounting works well, regions match propagator-network lifetimes). Research effort; years of work to do well.

Recommendation: BDW for stage A.5 first cut, MMTk or custom for production. Decision deferred to Track 6 design time.

### 7.2 Concurrency

- BSP scheduler is currently Racket threads (or sequential simulation in places).
- Native substrate needs a thread pool. Work-stealing for BSP rounds.
- Lock-free CHAMP operations for cell merges (CHAMP is naturally amenable; lock-free persistent data structures are well-studied).
- Per-propagator-worldview bitmask filtering means parallel BSP rounds don't conflict on cell writes (already designed at the algorithmic level; engineering at native level).

### 7.3 I/O

- Capability-typed effect handlers per the capabilities-as-types design.
- Stage A.5+ inverts FFI direction (Track 7): substrate calls OS / native libs directly via Prologos's own FFI machinery.
- Standard library bindings for filesystem, network, process, time — all capability-gated.

### 7.4 Module loading and the JIT story

- Today: Racket loads modules via its own machinery (`require`, `dynamic-require`).
- Native: load `.pnet` files, link against substrate runtime, possibly JIT-compile hot paths.
- AOT vs JIT: AOT (whole-program-compile-to-native) is simpler to start; JIT (hot-path optimization) is the perf ceiling. Likely AOT-first, JIT later.

---

## 8. Type erasure boundary (Track 5)

Decisions here determine what the runtime carries:

- **QTT `m0` (zero multiplicity)**: erased. This is well-defined and Idris 2 has the precedent. Use of an `m0` value is a type error caught at typecheck time; runtime never sees it.
- **Capability witnesses**: ambiguous. A capability typing parameter in source code carries authority — at runtime, does the function take a capability handle as an argument, or is it fully erased after typecheck? Different decisions for different capability kinds (effect capabilities can erase; authority capabilities for OCap/multi-agent must persist).
- **Session-typed channels**: runtime state is the message buffer + session protocol position. The protocol *type* is erased; the protocol *state* is not.
- **Dependent-type witnesses**: case-by-case. Most dependent types are typecheck-only (verifying contracts); some carry runtime witnesses (proof terms, irrefutable patterns, GADT discrimination).

Idris 2's QTT erasure provides the cleanest precedent for the m0/m1/mω axis. The capability/session/dependent-witness questions are Prologos-specific and don't have a single precedent.

This is the kind of design work that *seems* small but has implications for native-call ABI, FFI compatibility, and runtime size. Worth a focused track (Track 5) when stage A.5 design opens.

---

## 9. FFI direction inversion (Track 7)

Today's FFI Series ([`2026-04-28_FFI_MASTER.md`](../tracking/2026-04-28_FFI_MASTER.md)) is "Prologos calls Racket / other languages." kumavis's PR #35 lambda passing, eigentrust marshaling, Posit/List support — all this work is Prologos *calling out* through Racket's FFI infrastructure to other runtimes.

Stage A.5+ inverts: Prologos's substrate is native; it calls OS / native libs directly. The current FFI architecture has to be forward-compatible with this inversion. Concrete implications:

- The marshaler abstraction in `foreign.rkt` should not assume a Racket runtime. Today it does (cleanly, but it does). Track 7 is the work to refactor it.
- Capability-gating of FFI calls is the architectural invariant that should survive inversion. The OCap-style discipline is independent of which side is "native" — both sides have capabilities, the gates check at the call boundary.
- The retirement issue [#37](https://github.com/LogosLang/prologos/issues/37) flagged in the FFI Master ("retire lambda-passing scaffolding via propagator-native callbacks") is the kind of work that lands more naturally post-A.5 because propagator-native is genuinely native.

Worth coordinating: FFI Series' design choices today (in stage A) want to anticipate the inversion that lands at stage A.5. The discipline pattern from kumavis's PR #35 ("scaffolding with named retirement direction") is exactly right; the SH series will close some of those retirement directions.

---

## 10. WASM target (Track 8)

LLVM IR is the lingua franca; LLVM compiles to native or WASM. Decoupling "target IR" (LLVM) from "destination" (native binary, WASM module, embedded firmware) early avoids a costly retrofit.

Why this matters specifically for Prologos:

- The multi-agent / Vat vision (per the capability-safety research note) wants browser-side execution. WASM is the deployment vehicle for Prologos-in-browser.
- IPVM / Fission Codes precedent: deterministic Wasm, content-addressed computations. Our `.pnet` content-addressing aligns naturally; WASM-compiled substrate + `.pnet` deployment artifact = browser-deployable Prologos.
- WASM components (the WASM Component Model) align with our capability-typed boundary discipline. Each component has explicit imports/exports; capability-gating maps onto WASM's component-level type system.

Track 8 in the SH master. Doesn't gate on Track 4 (production native substrate) — both targets share the LLVM front-end. Could land either before or after Track 4; design deferred.

---

## 11. Bootstrap verification (Track 10)

Reflections on Trusting Trust (Thompson 1984): a malicious compiler can insert backdoors into binaries it produces, including into copies of itself. The attack survives source review.

Diverse Double Compilation (Wheeler 2005): the standard mitigation. Compile the Prologos-in-Prologos compiler with two *independent* compilers (Racket-Prologos and another, e.g., a previous trusted Prologos binary). Compare outputs. If they're equivalent, the trust attack is detected.

Reproducible builds: build artifacts are bit-for-bit identical across builds from the same source on the same toolchain. Combined with DDC, gives a verifiable chain from source to binary.

For SH:
- Stage B retires the Racket compile-time dependency.
- Stage C verifies that retirement was faithful — the binary you ship was actually built from the source you claim, and no compiler-trust attack inserted itself in the bootstrap chain.
- Track 10 in the SH master covers this. End of the trail.

This isn't load-bearing for *initial* self-hosting — most languages don't bother with formal DDC. It's load-bearing for *trusted* self-hosting, which the multi-agent / capability-security vision specifically wants. We're shipping a system where authority claims matter; the bootstrap chain has to be verifiable.

---

## 12. Why the contributor's "Racket is slow" anxiety has two answers

Source-dialogue framing the contributor used: Racket is slow for our reduction hot path. LLVM port would fix it.

Honest disambiguation:

- **Racket is not slow in general.** CS (Chez Scheme) backend is genuinely fast — competitive with V8 on most workloads, faster than CPython, in-league-with JVM-jitted code. Persistent data structures, hash tables, function calls, GC — all reasonably tuned.
- **What's slow is specifically reduction.** [`reduction.rkt`](../../racket/prologos/reduction.rkt) is 3739 lines of imperative tree-walking. 64% of compile time per the perf data above. The slowness is *algorithmic*, not host-language artifact.
- **LLVM port doesn't fix algorithmic slowness.** It gives constant-factor speedup (2-3× typical for tree-walking → native code), not order-of-magnitude. Order-of-magnitude wins come from changing the algorithm: e-graphs, interaction nets, supercompilation, the Track 9 / PReduce work.
- **What LLVM port *does* fix**: distribution (no Racket install required), self-hosting closure (bootstrap chain ends), perf ceiling once algorithms are good (constant factor matters when you've extracted the algorithmic wins).

The two-answer framing for the contributor:

- *Near-term*: Track 9 / PReduce in Racket. Algorithmic fix. Lands in months, not years. Reduction goes from 64% to (estimating) 5-15%, depending on how much super-optimization extracts. *In Racket*, before any port.
- *Long-term*: stage A.5. Constant factor on top of the algorithmic wins. Lands in quarters-to-years. Concretely realizes the self-hosting story.

Doing them in this order is correct. Doing them in reverse means porting a slow algorithm and getting a slightly-less-slow algorithm. The companion deep research note ([`2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md`](2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md)) carries the algorithmic-frontier discussion.

---

## 13. Open questions

1. **Track 1 (`.pnet` network-as-value): how do merge functions become serializable?** Today they're Racket closures. Options: symbolic registry references (NTT-style declarative propagators), bytecode embedding, hybrid. Resolution: NTT progress + PPN Track 4 closure.

2. **Track 4 (production substrate): host language?** Rust likely, per `RESEARCH_RUST_LLVM_LANGUAGE_IMPLEMENTATION.md`. Inkwell for LLVM bindings, MMTk for GC, mature concurrency. C++ is alternative. Prologos itself is chicken-and-egg with Track 9.

3. **Track 9 (compiler-in-Prologos): when is Prologos expressive enough?** Most needed features shipped (dependent types, QTT, capabilities, sessions, FFI, macros). Outstanding: meta-programming maturity, possibly module-system maturity. List is small.

4. **A.5 vs B ordering: strict serial or interleaved?** Strict serial is conservative; interleaved (Track 1 in parallel with PReduce) is faster but riskier if either side pivots.

5. **Track 5 erasure granularity**: per-capability decisions (effect erasure, authority preservation), per-session decisions (state vs type), per-dependent-type decisions (witness vs typecheck-only).

6. **Stage A.5 first-target**: native binary or WASM module? Both eventually; deciding which to validate first via PoC is a scope choice.

7. **What stays Racket forever?** Some things might: dev-only tooling (REPL convenience, debugging UI, IDE integration), test harness, benchmark runner. Stage C retires Racket from the *compile chain*, not necessarily from every dev workflow. Worth being honest that "Racket-free" doesn't mean "no Racket on developer's machine" if dev tooling stays.

8. **Verification scope (Track 10)**: full DDC + reproducible builds, or one of the two? Full DDC is the gold standard; reproducible builds alone is a useful subset.

---

## 14. References

### Primary trajectory
- [S-Expression IR to Propagator Compiler](2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md) — original four-phase trajectory (Phases 1–4 = Stages A → A.5 → B → C in this note's vocabulary)
- [Implementation Guidance](IMPLEMENTATION_GUIDANCE.md) — §10 LLVM target architecture, ANF/closure conversion, GC discussion, runtime
- [Rust+LLVM Implementation Research](RESEARCH_RUST_LLVM_LANGUAGE_IMPLEMENTATION.md) — full crate layout, runtime architecture, host-language case for Rust
- [Research GC](RESEARCH_GC.md) — garbage collection design

### Architectural context
- [Unified Propagator Network Roadmap](../tracking/2026-03-22_UNIFIED_PROPAGATOR_NETWORK_ROADMAP.md) — architectural endpoint diagram
- [Track 9 Reduction-as-Propagators research](../tracking/2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md) — PReduce founding research; cross-series dependency
- [PPN Master](../tracking/2026-03-26_PPN_MASTER.md) — Track 4 prerequisite chain
- [FFI Master](../tracking/2026-04-28_FFI_MASTER.md) — substrate boundary work

### Self-hosting precedents (literature)
- Thompson, K. (1984). *Reflections on Trusting Trust.* Communications of the ACM 27(8).
- Wheeler, D. A. (2005). *Countering Trusting Trust through Diverse Double-Compiling.* ACSAC '05.
- GHC's Haskell-in-Haskell self-hosting story; STG/Cmm split as runtime architecture.
- Rust's bootstrap from OCaml; clean bootstrap retirement procedure.
- Idris 2's QTT-based erasure; backend variety (Chez, Racket, etc.).
- Lean 4's self-hosting + native compilation; closest peer in design space.

### Companion this batch
- [SH Master](../tracking/2026-04-30_SH_MASTER.md) — series tracker
- [Propagator Network as Super-Optimizing Compiler](2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md) — deep research report on Prologos-distinctive contribution

---

## 15. One-paragraph executive summary

Self-hosting in Prologos is a two-axis retirement problem: axis 1 retires runtime Racket (substrate primitives go native via LLVM); axis 2 retires compile-time Racket (compiler ports to Prologos). The two axes are independent timelines and most languages retire axis 1 well before axis 2. The realistic stage progression is **Stage A** (current — Racket compiler, Racket-hosted substrate) → **Stage A.5** (substrate native, compiler still Racket — deployed Prologos programs run as native binaries with no Racket dependency) → **Stage B** (compiler ported to Prologos, substrate already native — the metacircular step) → **Stage C** (bootstrap verified via Diverse Double Compilation + reproducible builds — the trust closure). The `.pnet` serialization format is the structural linchpin: today it captures elaboration state but rebuilds runtime networks fresh on load; extending it to round-trip propagator structure as a value makes it the deployment artifact format and unlocks Stage A.5. Ordering: Track 9 / PReduce (algorithmic reduction-engine fix in Racket, leveraging tropical/quantale cost + e-graph + DPO + super-optimization) lands first; SH tracks open after, so Stage A.5 ports an already-fast algorithm. The contributor's "Racket is slow" anxiety has two answers: near-term (Track 9 / PReduce, in Racket, algorithmic) and long-term (Stage A.5, LLVM, constant-factor). Doing them in this order means LLVM lowers an already-fast algorithm; the multiplicative gain compounds. The friend's intuition — "phase where we use Racket to generate LLVM IR so we're not running on Racket at runtime, and then a later phase where we generate LLVM IR from Prologos to get off Racket entirely" — exactly maps to Stage A.5 → Stage B. Nothing in our architecture obstructs the path; the FFI Series and the LLVM backend are the two infrastructure pieces that respectively unlock Stage B (compiler-in-Prologos with substrate hosted) and Stage A.5 (substrate native, runtime Racket-free). Stage 0/1; no design commitments.
