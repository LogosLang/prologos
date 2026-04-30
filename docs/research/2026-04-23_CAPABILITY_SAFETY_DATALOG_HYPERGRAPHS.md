# Capability Safety as Datalog and the Non-Compositionality of Safety: Applicability to Prologos

**Date**: 2026-04-23
**Status**: Research note (Stage 1 / Stage 2 — exploration and applicability assessment, not a design proposal)
**Author**: Claude (research scan), reviewed against current implementation
**Subjects under review**:
- Spera, C. (2026). *Safety is Non-Compositional: A Formal Framework for Capability-Based AI Systems.* arXiv:2603.15973 ([abs](https://arxiv.org/abs/2603.15973), [html](https://arxiv.org/html/2603.15973v2))
- Spera, C. (2026). *Capability Safety as Datalog: A Foundational Equivalence.* arXiv:2603.26725 ([abs](https://arxiv.org/abs/2603.26725), [html](https://arxiv.org/html/2603.26725v1))

**Vocabulary disambiguation up front.** "Capability" is overloaded across at least three traditions and the papers do not formally connect to all of them; the document earlier conflated two and is corrected here.

- **Spera's usage (these papers).** "Capability" in the *agentic-AI / capability-evaluation* sense: a thing an agent can do, an ability/skill/tool, of the kind catalogued in AI capability evaluations and tool-use research. The papers do not cite the OCap / object-capability literature and do not formally identify their "capability" with authority-tokens in the seL4/E sense. The mathematical object they study is a transitively-closed reachability hypergraph with conjunctive (AND-tail) composition rules — purely structural.
- **OCap / object-capability literature.** A *capability* is an unforgeable reference that conveys authority; held by a subject, transferable, derivable, governed by the "no ambient authority" discipline. Prologos's vision (§4.3 below; LANGUAGE_VISION; RELATIONAL_LANGUAGE_VISION) does invoke this tradition for the multi-agent story.
- **Prologos's `capability` types (today).** Effect capabilities (zero-method traits — `ReadCap`, `WriteCap`, `FsCap`, …) attached to *functions*, transitively closed across the call graph by an ATMS-backed propagator network. See [capability-inference.rkt](../../racket/prologos/capability-inference.rkt) and [2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md](../tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md).

The three are distinct. The mathematics, however, is the *same* in all three: transitive closure under composition rules over a lattice. The papers' theorems apply to any system whose composition rules form a hypergraph with conjunctive tails, which includes — but is not specific to — OCap-style authority. Most of what follows turns on that structural correspondence, not on a vocabulary identification.

---

## 1. Summary of the two papers

### 1.1 Paper A — *Safety is Non-Compositional* (2603.15973)

**The thesis.** Capability safety properties do not compose under union of agents. Formally:

> **(Def 3.2)** A *capability hypergraph* is a directed hypergraph H=(V,ℱ) where V is a set of capabilities and each hyperarc (S,T) ∈ ℱ is a composition rule: the capabilities in S *jointly* enable those in T. Hyperarcs fire under AND-semantics ("only when all elements of S are simultaneously present").
>
> **(Def 6.1)** The closure cl(A) is the smallest C ⊆ V with A ⊆ C and ∀(S,T) ∈ ℱ: S ⊆ C ⇒ T ⊆ C.
>
> **(Thm 9.2)** *Safety is non-compositional*: there exist A, B ∈ ℛ(F) such that A ∪ B ∉ ℛ(F).

The minimal counterexample: V={u₁,u₂,f}, F={f}, ℱ={({u₁,u₂}, {f})}. Both A={u₁} and B={u₂} are individually safe (neither alone fires the conjunctive edge), but their union activates the AND-rule and produces the forbidden f. Two agents each individually unable to reach a forbidden capability can, together, reach it through an emergent conjunctive dependency.

**Why hypergraphs and not graphs.** Pairwise-edge graphs cannot represent AND-preconditions; the failure mode the paper isolates *requires* multi-tail edges. Any analysis that reduces composition rules to pairwise reachability misses this entire class of vulnerability.

### 1.2 Paper B — *Capability Safety as Datalog* (2603.26725)

**The thesis.** The reachability semantics of capability hypergraphs is *exactly* propositional Datalog (Datalog_prop: monadic, ground, function-free). The encoding is tight in both directions.

> **(Def 4.1, encoding)** Each hyperedge (S,{v}) ∈ ℱ becomes the rule `has(s₁) ∧ … ∧ has(s_k) ⇒ has(v)`. For each forbidden f ∈ F, add `has(f) ⇒ forbidden`. EDB for configuration A is D_A = {has(a) : a ∈ A}.
>
> **(Thm 4.3)** Closure equals least model: cl_H(A) = {v : has(v) ∈ Π_H(D_A)}; safety equivalence: A ∈ ℛ(F) iff `forbidden` ∉ Π_H(D_A); minimal unsafe antichains are minimal witnesses.
>
> **(Thm 4.5)** Reverse direction is symmetric and isomorphism-preserving.

**What the equivalence buys you.**
- **Incremental view maintenance** (Thm 11.1): the audit surface is a stratified Datalog view, maintainable in O(|Δ|·(n+mk)) per update via DRed instead of O(|V|·(n+mk)) full recomputation.
- **Audit-surface containment is decidable in PTIME** (Thm 11.1.3) by Datalog_prop query containment — *first known* decision procedure for the problem.
- **Complexity inheritance** (Cor 5.2): fixed-program safety is in P; combined complexity P-complete; deciding minimal unsafe antichain membership is coNP-complete.
- **Why-provenance as commutative semiring** (Thm 6.2 / Cor 6.3): certificates compose, compress, and validate uniformly.
- **Locality gap** (Thm 11.3): Ω(n) asymptotic separation between incremental and global maintenance; oracle lower bound shows any correct algorithm must probe all k+1 atoms in an AND-rule's preconditions.

The two papers are tightly coupled: A diagnoses the problem (composition is structural), B gives the formal substrate for analyzing and maintaining it (Datalog_prop with semiring provenance).

---

## 2. Audit of current Prologos infrastructure relevant to these results

This section is grounded in the Explore agent's pass over the repo on 2026-04-23. Status tags follow the convention IMPLEMENTED / PARTIAL / DESIGNED / VISION / ABSENT.

### 2.1 What we already have (IMPLEMENTED)

- **[capability-inference.rkt](../../racket/prologos/capability-inference.rkt)** — Effect-capability inference for functions via the persistent propagator network. Cells per function, call edges as propagators, set-union join over a PowerSet lattice. ATMS-backed provenance: "*why does f require ReadCap?*" returns a derivation tree. **This is, modulo the agent/effect vocabulary distinction, exactly a propagator realization of the closure semantics in Paper A's Def 6.1.**
- **[atms.rkt](../../racket/prologos/atms.rkt)** (877 LOC) and **[provenance.rkt](../../racket/prologos/provenance.rkt)** — ATMS assumptions, support sets, derivation trees as first-class data. `answer-record` carries `derivation` + `support`.
- **[qtt.rkt](../../racket/prologos/qtt.rkt)** (2462 LOC) — full multiplicity tracking (0, 1, ω); the linear-resource layer.
- **[session-propagators.rkt](../../racket/prologos/session-propagators.rkt)** + **session-lattice.rkt** — propagator-based session-type checking, session cells refining monotonically, dependent session types, deadlock/completeness detection (S4f), operation tracing (S4d).
- **Derivation expressions are first-class**: `expr-derivation-type` in [typing-core.rkt:2044](../../racket/prologos/typing-core.rkt). Per LANGUAGE_VISION line 88: "Every proof search produces a derivation tree. These trees are first-class data that can be inspected, logged, serialized, and audited."
- **Stratified propagator scheduler** — see [`.claude/rules/stratification.md`](../../.claude/rules/stratification.md). S(-1) retraction, S0 monotone firing, topology stratum, S1 NAF (non-monotone validation). The infrastructure already supports the kind of stratified Datalog evaluation Paper B's incremental-maintenance results require.
- **Quantale/semiring research lineage** — `research/quantale research/` (untracked, locally present), [2026-03-16_TENSOR_PROPAGATOR_RESEARCH_PROGRAM.md](2026-03-16_TENSOR_PROPAGATOR_RESEARCH_PROGRAM.md), [2026-03-16_BEYOND_PROLOG.md](2026-03-16_BEYOND_PROLOG.md) §6 (`DistCell`, semiring-pointwise merge). Paper B's "provenance as commutative semiring" lands directly in this in-flight research line.

### 2.2 What is designed but not built (DESIGNED / PARTIAL)

- **Capability-as-types Phase 8d**: "Multi-agent cross-network reasoning" — explicitly DEFERRED in [2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md](../tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md) §7. This is precisely the seam where Paper A's non-compositionality bites.
- **Probabilistic / weighted logic** — designed in BEYOND_PROLOG §6 (DistCell, semiring lattice), not implemented.
- **Narrowing for symbolic reachability** — [2026-03-07_NARROWING_AND_SEARCH_HEURISTICS.md](2026-03-07_NARROWING_AND_SEARCH_HEURISTICS.md). Designed; not integrated into the prototype.
- **Endo-as-session-types worker compartments** — [2026-03-07_ENDO_AS_SESSION_TYPES.org](2026-03-07_ENDO_AS_SESSION_TYPES.org). Sandbox/compartment design sketch.

### 2.3 What is vision only (VISION)

- **Multi-agent orchestration** — LANGUAGE_VISION lines 374–376 ("the killer application: multi-agent orchestration where agents communicate via session-typed protocols, reason via proof search, and explain their decisions via derivation trees"). DESIGN_PRINCIPLES references "session types for agent protocols" and "AI agent self-inspection." No implementation.
- **Network mobility** — `RELATIONAL_LANGUAGE_VISION.org`: an agent constructs a knowledge base, derives conclusions, ships the entire network to another agent. No implementation.
- **Containerization / subprocess substrate for agents** — research notes only (Endo above; Racket `place` mention in IMPLEMENTATION_GUIDE_CORE_DS_PROLOGOS.md line 1565). No formal model of agent lifecycle, no sandbox boundary, no reified compartment.

### 2.4 What is genuinely absent (ABSENT)

- **Hypergraphs as a first-class network representation.** The propagator network is a directed cell-propagator graph. Multi-tail composition rules are encoded today as multi-input propagators — *operationally* hypergraph-like, but not reified as a hypergraph datatype with a closure operator we can reason about as a mathematical object. Paper A's machinery wants the latter.
- **Composition under union of agent capability sets.** We have closure of one function's capability set; we have no formal model of "two agents A, B; what is cl(A ∪ B)?" because we have no agents.
- **Audit-surface containment as a query.** `G_F(A) ⊆ G_F(A')` is not something we can ask today.
- **Forbidden capabilities / safety policy.** The capability inference machinery has no notion of a forbidden set F and no safety predicate. It infers; it does not gate.

---

## 3. Applicability analysis

I'll separate this into (a) *what the papers say about a problem we will face*, (b) *what they give us as a tool*, and (c) *where the structural fit is unusually clean*.

### 3.1 The papers diagnose a problem the multi-agent vision will hit

The Prologos vision pairs OCap-influenced authority gating with linear session types and (eventually) sandboxed compartments to deliver "secure containerized multi-agent systems with properly gated and mediated interactions." Paper A is a directly aimed warning whose mathematics is independent of which capability tradition we draw on: **per-agent gating is structurally insufficient for safety whenever composition rules have conjunctive tails.** The papers themselves work in the agentic-AI / tool-use frame, but the theorem applies to *any* system whose ability composition is captured by a hypergraph of this shape — including ours. Two compartments, each with a capability set we have audited as safe, can — through a session-mediated interaction that lets one agent's authority complete a precondition the other already partially satisfied — collectively reach a forbidden goal.

This is not hypothetical for Prologos. Two concrete realizations of the conjunctive-edge pattern in our planned design surface:

1. **Compositional resource access.** Suppose agent A holds `ReadCap(secrets)` and agent B holds `WriteCap(public-channel)`. Neither alone is an exfiltration. Composed across a session, they are. The hyperedge is `{ReadCap(secrets), WriteCap(public-channel)} → exfiltration`. Per-agent audit passes; system-level audit fails.
2. **Capability derivation across a session boundary.** OCap systems classically allow capability *introduction* across channels. If agent A can mint a derived capability c' from c and ship c' to agent B over a session, the effective capability set of B becomes B ∪ derived(A). Paper A's theorem applies pointwise.

The implication for our design: the safety story for our multi-agent vision needs a **system-level reachability analysis over the union of compartments' capability sets, with explicit conjunctive composition rules.** Per-compartment QTT linearity, per-agent capability typing, and per-channel session typing — even all three together — do not subsume this.

### 3.2 Paper B gives us the substrate for that analysis

If we accept (3.1), the question becomes: what *form* should the system-level analysis take? Paper B's answer is: it should be **propositional Datalog evaluation, equivalently a fixpoint on a hypergraph reachability lattice, with semiring-valued provenance**. This is striking because it lines up with infrastructure we already have:

- **Closure as fixpoint on a lattice.** Already what our propagator network *is*. A capability hypergraph is a particular cell layout: one cell per capability (boolean lattice `{⊥, ⊤}`), one propagator per hyperedge firing under AND-semantics. Set-union join across worldviews is already implemented in capability-inference.rkt.
- **Hyperedges as multi-input propagators.** Already what propagators *are*. We do not need a new computational primitive; we need to lift the existing mechanism to a *named* hypergraph object so we can reason about it as data (encode/decode, serialize, ship across compartments).
- **Stratified incremental maintenance.** Our scheduler already runs stratified (S(-1)/S0/Topology/S1). Paper B's DRed incremental algorithm is naturally a topology+S0 alternation: when an EDB atom is added or removed, the affected delta propagates through cells whose merge is set-union (additions monotone, retractions handled at S(-1)).
- **Why-provenance as commutative semiring.** Our ATMS already records support sets that are essentially the why-provenance semiring's elements. The DistCell / quantale work in flight extends this to weighted semirings, which is *exactly* the structure Paper B identifies as the unifying frame for certificates.

Concretely, Paper B's decidability result for audit-surface containment is the kind of static-analysis question we will want to ask of multi-agent compositions: "does configuration A' admit at least the same forbidden reachabilities as A?" In a system where agents migrate, get instantiated dynamically, or have their capability sets edited, this becomes a refactoring/regression question, and PTIME decidability is the difference between practical tooling and intractable analysis.

### 3.3 The structural fit is unusually clean

The papers describe a hypergraph reachability semantics with semiring provenance. Prologos's propagator network *is* a fixpoint engine over a lattice with ATMS provenance. The mapping is essentially:

| Paper A/B object                          | Prologos artifact                                                         |
|-------------------------------------------|---------------------------------------------------------------------------|
| Capability vertex v ∈ V                   | Cell with boolean (or weighted) lattice                                   |
| Hyperedge (S, {v})                        | Propagator with inputs S, output v, AND-fire                              |
| Closure cl(A)                             | Network quiescence under EDB seed A                                       |
| Forbidden set F                           | Distinguished cells gated by safety propagators                           |
| EDB D_A                                   | Initial cell-write set                                                    |
| Datalog_prop least model                  | Cell-state at quiescence                                                  |
| Why-provenance semiring                   | ATMS support sets (boolean) → DistCell weights (semiring extension)       |
| DRed incremental maintenance              | S(-1) retraction + S0 re-firing under topology delta                      |
| Audit-surface containment query           | Cross-network bridge query (Galois connection between two networks)       |
| Antichain of minimal unsafe configurations | Nogood set in BSP-LE worldview lattice                                    |

The right column is not a translation we'd have to invent — every entry is something the project already implements or has explicitly designed. **The papers do not propose new infrastructure; they propose a problem that our existing infrastructure is unusually well-shaped to solve.**

---

## 4. Considerations for the language / prover level

### 4.1 At the type/term level

- **Reify hypergraphs as a first-class type.** Today the propagator network is built procedurally during elaboration. To support Paper A/B-style analyses, we need a hypergraph value `Hypergraph V` that elaborates to (or is bridged from) a sub-network. Closure becomes a typed operation `closure : Hypergraph V → Set V → Set V` whose implementation is "install + quiesce + read." This is the kind of "construction lifted to data" the relational-language vision already pushes for.
- **Capability composition rules need to be typed.** A hyperedge `(S, {v})` is a *typed* claim that the simultaneous holding of capabilities in S authorizes v. In our system that is a dependent-type declaration whose witness is the derivation tree the ATMS already produces. This makes safety policies first-class, inspectable, and (per Paper B) mechanically composable.
- **Distinguish effect-capabilities (current) from authority-capabilities (papers).** These are two different structural objects, but they likely benefit from a *shared substrate*: both are "what does this thing transitively need / grant?" computed as a fixpoint over composition rules with provenance. Future capability-inference design might generalize over both, parameterized by the source/sink lattice.

### 4.2 At the propagator / network level

- **Hypergraph closure as a stratum primitive.** Closure-to-quiescence is what the network does. Adding a "capability closure stratum" — a registered handler in the sense of [stratification.md](../../.claude/rules/stratification.md) — lets safety analyses compose with existing strata (NAF, retraction, topology) cleanly.
- **Worldview-tagged capability sets for compositionality analysis.** BSP-LE Track 2's per-propagator worldview bitmask + tagged-cell-value substrate already supports "compute closure separately under A, under B, under A ∪ B, and compare." This is the operational shape of testing for non-compositional safety violations: fork three worldviews, quiesce, diff against F.
- **Semiring provenance.** ATMS is a boolean special case of the why-provenance semiring. Generalizing the support-set merge to a semiring-parametric merge (the DistCell direction) gives Paper B's certificate algebra "for free" in our existing lattice infrastructure. This is also where probabilistic and tropical reasoning unify with safety reasoning under one framework — Paper B and the in-flight quantale program land at the same point.

### 4.3 At the multi-agent / sandbox level (currently vision)

- **Compartments as named sub-networks with explicit bridge cells.** The Endo-style worker compartment design sketch, plus the Galois-connection bridge formalism in [`.claude/rules/structural-thinking.md`](../../.claude/rules/structural-thinking.md), gives us the substrate. Each compartment is a sub-network with a typed boundary; cross-compartment information flow is via bridge cells whose transfer rules are typed propagators.
- **Per-compartment audit + system-level audit.** Per-compartment is QTT + capability typing + session typing + closure-under-the-compartment's-EDB. System-level is closure-under-the-union-of-EDBs + forbidden-set check. **Paper A says the second is not implied by the first.** Both must be performed.
- **Capability derivation across channels needs an explicit composition rule.** When agent A can mint c' from c and pass c' to B over a session, that is a hyperedge `({c, channel-A→B}, {c'@B})` in the system-level hypergraph. Session types tell us *that* the channel is well-formed; the hypergraph tells us *what* gets transitively authorized.

### 4.4 At the prover level

- **Audit-surface containment as a typechecker query.** Paper B Thm 11.1.3 makes this PTIME-decidable. If we expose `audit_contains : Config → Config → Bool` as a relation in our solver, it can be queried at compile time before deploying a multi-agent configuration: "does this redeployment admit any new forbidden reachabilities?" This is a deployment-time gate that mechanically matches our "Correct-by-Construction" principle.
- **Minimal unsafe antichains as nogood explanations.** When safety analysis fails, the *minimal* unsafe configurations (Paper A's antichain ℬ(F), Paper B's coNP-complete characterization) are the explanation users need: "these k capabilities, jointly, cause the problem." Our nogood machinery (BSP-LE Track 2) already produces minimal explanations in the SAT sense; the mapping is direct.

---

## 5. Risks, caveats, open questions

- **Paper A's bad news is real.** No clever per-agent sandboxing reasons-around the conjunctive-composition theorem. Any pitch of "secure multi-agent systems via sandboxing + capability gating + session types" that does *not* include a system-level reachability analysis is making the safety claim Paper A formally refutes. Our pitch, as currently expressed in LANGUAGE_VISION lines 374–376, is in this category. The vision text needs an addendum.
- **Datalog_prop is *propositional*.** Paper B's exact equivalence is for monadic, ground, function-free Datalog. Lifting to first-order Datalog (so we can express "any agent holding ReadCap(x) for any secret x") loses the PTIME guarantees and requires care. Our dependent type system is more expressive than first-order Datalog; reconciling is open work.
- **The two papers share an author and are recent (March 2026).** Adoption is single-source. Worth tracking citation/critique. The minimal counterexample in Paper A is uncontroversial; the broader framing as "first formal proof" of non-compositionality is where independent review would help.
- **Hypergraph reification cost.** Today's network is implicit in elaboration code. Lifting to a named, serializable hypergraph datatype is non-trivial design work and shouldn't be undertaken speculatively. The pragmatic order is: (i) finish the in-flight tracks (PM 8E–10, SRE remaining, BSP-LE 3+) that mature the propagator infrastructure, (ii) build the multi-agent vision in stages that *create* the demand for hypergraph reification, (iii) at that point harvest Paper B as the formal substrate.
- **Performance.** PTIME audit-surface containment is asymptotic. Constant factors over our existing CHAMP + propagator infrastructure are unknown. The locality-gap theorem (Paper A Thm 11.3) suggests incremental analysis is essential — full recomputation per deployment is not viable.
- **The "agent" abstraction is undefined in Prologos today.** The whole analysis presupposes agents. Until we have a reified compartment / agent / process abstraction (currently vision only), we can absorb the formal results but cannot apply them concretely. Adopting these papers is partly a forcing function for designing that abstraction.

---

## 6. Recommended next actions

These are *suggestions for downstream tracks*, not commitments. Order is roughly increasing in scope.

1. **Add a section to LANGUAGE_VISION** acknowledging the non-compositionality result and committing the multi-agent design to a system-level reachability analysis, not just per-compartment gating. This is a small text edit; it costs nothing and corrects a load-bearing claim.
2. **Cross-reference these papers from [2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md](../tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md) Phase 8d** ("multi-agent cross-network reasoning"), as the formal frame for the design when it is taken up.
3. **Add a watching item to dailies / Master Roadmap**: as the quantale / DistCell semiring work matures, treat Paper B's provenance-as-semiring framing as a unifying lens — it ties safety reasoning, probabilistic reasoning, and tropical/cost reasoning into one infrastructure.
4. **When the compartment / agent abstraction enters design (post-Endo-as-session-types follow-up)**, structure the design from the start around (a) per-compartment typing and (b) a system-level capability hypergraph with named composition rules. Do not ship a multi-agent runtime that has only (a).
5. **Treat hypergraph reification as a design open question, not an implementation task.** The exact shape of "hypergraph as first-class value" interacts with the relational/network-mobility vision and should be designed once those constraints are concrete.
6. **Do not adopt Datalog as an implementation substrate.** Paper B's equivalence is theoretical: it tells us *what algorithmic results we inherit*, not *that we should switch backends*. Our propagator network already realizes the same fixpoint semantics with strictly more expressive provenance; we harvest the analyses, not the engine.

---

## 7. References to project artifacts

- Capability inference: [racket/prologos/capability-inference.rkt](../../racket/prologos/capability-inference.rkt), [docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md](../tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md)
- ATMS / provenance: [racket/prologos/atms.rkt](../../racket/prologos/atms.rkt), [racket/prologos/provenance.rkt](../../racket/prologos/provenance.rkt)
- QTT: [racket/prologos/qtt.rkt](../../racket/prologos/qtt.rkt)
- Session types on propagators: [racket/prologos/session-propagators.rkt](../../racket/prologos/session-propagators.rkt), [racket/prologos/session-lattice.rkt](../../racket/prologos/session-lattice.rkt)
- Stratification mechanism: [`.claude/rules/stratification.md`](../../.claude/rules/stratification.md)
- Structural-thinking / Galois bridges: [`.claude/rules/structural-thinking.md`](../../.claude/rules/structural-thinking.md), [`.claude/rules/on-network.md`](../../.claude/rules/on-network.md)
- Probabilistic / weighted lineage: [docs/research/2026-03-16_BEYOND_PROLOG.md](2026-03-16_BEYOND_PROLOG.md), [docs/research/2026-03-16_TENSOR_PROPAGATOR_RESEARCH_PROGRAM.md](2026-03-16_TENSOR_PROPAGATOR_RESEARCH_PROGRAM.md)
- Multi-agent / sandbox lineage: [docs/research/2026-03-07_ENDO_AS_SESSION_TYPES.org](2026-03-07_ENDO_AS_SESSION_TYPES.org), [docs/research/2026-03-03_PROCESS_CALCULI_SURVEY.md](2026-03-03_PROCESS_CALCULI_SURVEY.md)
- Vision: `docs/tracking/principles/LANGUAGE_VISION.org`, `docs/tracking/principles/RELATIONAL_LANGUAGE_VISION.org`, `docs/tracking/principles/DESIGN_PRINCIPLES.org`

---

## 8. One-paragraph executive summary

Spera's two March 2026 papers establish (A) that capability-based safety properties do *not* compose under union of agents — two individually safe agents can jointly reach a forbidden capability through emergent AND-edges in a capability hypergraph — and (B) that the closure semantics of these hypergraphs is exactly propositional Datalog, with the consequence that audit-surface containment is PTIME-decidable, incremental maintenance is asymptotically separated from full recomputation, and certificates form a commutative semiring. The papers' "capability" is used in the agentic-AI / tool-use sense (an ability an agent has), *not* in the OCap/object-capability sense and *not* matching Prologos's effect-capability types — but the structural object they formalize (transitive closure under conjunctive composition rules, with provenance) is the same fixpoint-on-a-lattice-with-provenance that our propagator network already realizes, so the algorithmic inheritance to our infrastructure is essentially free at the formal level regardless of which capability tradition one is reading them through. The actionable consequence for Prologos is that the multi-agent vision, as currently stated, makes a safety claim Paper A formally refutes for any system that relies only on per-compartment gating; system-level capability-hypergraph analysis (closure under union of agent EDBs, with forbidden-set containment as a typechecker query) needs to be a first-class part of the design when the compartment abstraction is built. Until then, these papers are best treated as a forcing function for the multi-agent design and a unifying formal frame for the in-flight quantale / DistCell / probabilistic-propagator research lines.
