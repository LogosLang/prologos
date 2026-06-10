# Paper B — FL(ℵ₀) as a Candidate Universal Substrate for Parallel Computation

**Status**: skeleton v0.1.
**Type**: Conceptual / foundational paper.
**Target venues**: LICS, FOCS, JACM, LMCS, ICALP. Also CACM / Bulletin of the EATCS as a perspective piece.
**Time-to-submit estimate**: 18–30 months.
**Owner**: TBD.
**Co-authors**: TBD; Nation co-authorship discussion open as paper approaches submission.
**Dependencies**: cites Paper Poly (categorical foundation), Paper A (recovery clause), Paper A0 (empirical witness).
**Prior-art floor**: `outputs/free-lattice-utm-parallel.md` (round-2 priority audit).

---

## 0. Working title alternatives

- *FL(ℵ₀) as a Candidate Universal Substrate for Parallel Computation*
- *Toward a Parallel Substrate: Free Lattices, Whitman's Procedure, and the CALM Demarcation*
- *Lattice-Substrate Parallelism: A Research Programme*

---

## 1. Headline claim (softened, suggestive)

We propose **FL(ℵ₀) + Whitman**, with **Poly-shaped propagators on lattice-valued cells** and a CALM-aligned scheduler, as a **candidate substrate** for parallel computation analogous to UTM's role for sequential computation.

We do not claim Church-Turing-thesis-shape equivalence. We develop the analogy as a research programme, with four pillars and one empirical witness.

## 2. Pillars

### Pillar 1 — Encoding chain (algebra)

TM ↪ rewriting ↪ FL.

- TM ↪ rewriting via Endrullis–Shallit–Smith 2017 Lemma 1 / REWRITE-POWER (citing Book–Otto 1993).
- The lift from rewriting to FL to be developed (with Nation guidance). Open question Q-B2.
- Algebraic backstop: Nation–Paolini I/II/III (FOTFL undecidable for κ ≥ 3, universal fragment decidable). Undecidability of full FOTFL is the model-theoretic shadow of "Turing computation can be encoded into the first-order theory of FL."

### Pillar 2 — Demarcation (CALM)

CALM characterizes the **monotone fragment** of distributed computation that lives natively on the substrate without coordination:

> A problem has a consistent, coordination-free distributed implementation if and only if it is monotonic. (Hellerstein-Alvaro 2020.)

CALM is a *partial demarcation theorem* — not a Church-Turing analog. The paper makes this explicit and addresses the framing-vulnerability up front.

### Pillar 3 — Recovery (LRP)

Paper A's Layered Recovery Principle is the **recovery clause**. Non-monotone computation that does not live natively on the CALM-monotone fragment is recovered by stratified composition with controlled inter-stratum transitions.

Together, pillars 2 + 3 give: **monotone fragment** (CALM-native) ∪ **stratified non-monotone** (LRP-recovered) = parallel computational power.

### Pillar 4 — Empirical witness (LHC)

The Logos Hyperlattice Compiler (Paper A0) is the operational witness:

- **Whitman 10/10**: across 4 lattice-structured semantic domains × all relevant relations × {ground, wider} sublattices, Whitman's condition holds in 10/10 combinations, with non-vacuous antecedent firing 83-99% on the type domain (per `2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION`).
- **The compiler is a network**: phase collapse (Paper A0 headline) demonstrates the substrate is general enough to host the entire compilation lifecycle as a single fixpoint.
- **Scheduler portability**: 4-5 schedulers, same fixpoint, demonstrates the substrate is order-independent under CALM-enforced architecture.

## 3. Substrate-vs-decider posture (preempting reviewers)

UTM is a substrate (machine + tape + program). FL(ℵ₀) is an algebraic structure. The comparable substrate object is:

> **(FL(ℵ₀), Whitman-decision-procedure, Poly-shaped propagators, BSP-style scheduler)**

…compared structurally to:

> **(tape, transition function, head, scheduler-trivial)**

The paper foregrounds this triple as the substrate object and addresses the substrate-vs-decider distinction explicitly. Hewitt-actor-style critiques are pre-empted by careful framing.

Open question Q-B1 commits to formalizing this distinction before paper writing begins.

## 4. Honest framing-softening (per 2026-05-08 conversation)

- **"Is the parallel UTM"** → "is a candidate substrate analogous to UTM."
- **"CALM is the parallel Church-Turing"** → "CALM is a partial demarcation theorem of the monotone fragment; together with LRP recovery, the pair characterizes parallel computational power on the substrate."
- **"Universality theorem"** → "universality conjecture, supported by encoding chain + CALM demarcation + LRP recovery + empirical witness."

The Church-Turing-shaped statement remains as a programmatic aspiration, not a paper claim. Owner: "more pieces in play before we can grapple with that claim."

## 5. Outline (TBD)

- §1 Introduction — the missing parallel substrate.
- §2 Background — UTM as substrate; what a parallel analog would need to satisfy; prior candidates (BSP, PRAM, dataflow, Petri, actors, LVars, BloomL).
- §3 The substrate object — (FL, Whitman, Poly-propagators, scheduler). Substrate-vs-decider distinction.
- §4 Pillar 1 — encoding chain.
- §5 Pillar 2 — CALM demarcation.
- §6 Pillar 3 — LRP recovery (cite Paper A).
- §7 Pillar 4 — empirical witness (cite Paper A0; reproduce Whitman 10/10 finding).
- §8 The universality conjecture — what we claim, what we don't.
- §9 Related work — Hewitt actors as universal-substrate precedent on different substrate; Kuper LVars as lattice-foundation-of-deterministic-parallelism precedent; BloomL as lattice-typed distributed substrate; BSP/PRAM/dataflow/Petri as alternative substrates.
- §10 Discussion — Church-Turing-shaped aspiration; what would close the gap.

## 6. Open questions blocking this paper

See `../open-questions.md`:
- Q-B1 (substrate-vs-decider formalization) — **required before paper writing**.
- Q-B2 (encoding-chain rigor; lift from rewriting to FL) — **Nation consultation track**.
- Q-B3 (Whitman-from-recursive-merge as theorem rather than empirical correlation) — **Nation consultation track**.
- Q-B4 (CALM-as-Church-Turing scope; what pieces enable the bolder statement).
- Q-B5 (Nation-Paolini III reduction shape).

## 7. Engineering anchors required

See `../engineering-anchors.md`:
- A1 (Whitman 10/10) — primary empirical pillar.
- A2 (scheduler portability) — secondary empirical pillar.
- All A0 anchors are inherited via citation.

## 8. Risk profile

**Medium-high.** Materially reduced by:
- Nation collaboration (de-risks the algebra).
- A0/Poly publishing first (carries the substrate object + categorical foundation independently).
- Paper A publishing in between (carries the LRP recovery clause independently).
- The empirical Whitman finding (independent corroboration of FL-relevance).

Remaining risk concentrated in:
- Substrate-vs-decider framing (Q-B1).
- The bridge from "FL is algebraically right" to "FL is *the* parallel substrate" (a programmatic step the paper acknowledges as conjecture, not theorem).

## 9. Provenance / source material

- `outputs/free-lattice-utm-parallel.md` (round-2 priority audit; programme floor).
- `outputs/free-lattice-utm-parallel.provenance.md`
- `outputs/.drafts/*` (round-1 + round-2 researcher passes).
- Nation-Paolini I/II/III + Freese-Ježek-Nation 1995.
- Hellerstein-Alvaro 2020 (CALM).
- Paper A0 (LHC system paper; not yet drafted).
- Paper Poly (categorical foundation; not yet drafted).
- Paper A (LRP recovery clause; not yet drafted).
