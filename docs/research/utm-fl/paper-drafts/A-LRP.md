# Paper A — The Layered Recovery Principle

**Status**: skeleton v0.1.
**Type**: Theory paper.
**Target venues**: POPL, ICFP, OOPSLA, LMCS, JFP.
**Time-to-submit estimate**: 12–18 months.
**Owner**: TBD.
**Co-authors**: TBD.
**Dependency**: cites Poly paper for inter-stratum machinery (LKan/RKan, Galois bridges).

---

## 0. Working title alternatives

- *The Layered Recovery Principle: Stratified Recovery of Non-Monotone Computation on CALM-Safe Substrates*
- *Recovering Non-Monotonicity on Lattice-Based Propagator Networks*
- *Stratification Beyond Negation: A General Recovery Principle*

---

## 1. Headline claim

Over a propagator network in the sense of [Poly], any non-monotone computation expressible across heterogeneous lattice domains recovers as a finite stratified composition of CALM-safe monotone fixpoints, with controlled non-monotone transitions at stratum boundaries. We exhibit this for six instances drawn from a working compiler and conjecture universality.

## 2. The Layered Recovery Principle (informal)

Given a non-monotone computation N over heterogeneous lattices L₁,…,L_k, there exists:

1. A finite stratification N = N₀ → N₁ → … → N_n where each N_i is a CALM-safe monotone fixpoint over a sub-network of cells.
2. Inter-stratum transitions T_{i→i+1} that are *controlled* — characterized by Galois bridges between heterogeneous lattices and Kan extensions for inter-stratum composition.
3. A correctness theorem: the stratified composition computes N's intended fixpoint.

## 3. Instances (six; expected to grow)

1. **NAF-LE** — stratified negation-as-failure. Per `2026-03-21_CATEGORICAL_STRUCTURE_FIVE_SYSTEMS` §2: not a strict opfibration; precise structure is an indexed family of monotone fixpoints over a well-ordered base.
2. **WF-LE** — well-founded semantics. Per `2026-03-21_...` §3: AFT (approximation fixpoint theory) connection; quasi-monotone alternation.
3. **Type system stratified quiescence** — Per `2026-03-21_...` §4: this *is* an opfibration with caveats. The cleanest instance.
4. **Effect system (QTT + sessions)** — Per `2026-03-21_...` §5: quantale-enriched fibers; Galois connection currently aspirational rather than implemented (limitation to acknowledge).
5. **Stratified retraction (S(−1))** — Per `2026-03-21_...` §6: not a standalone system but a dual to forward strata.
6. **Topology-strata** — PPN-series finding: dynamic topology changes break CALM, recovered via stratification. Newest instance; per owner note (2026-05-08).

## 4. Inter-stratum machinery

Cited from Paper Poly:
- **LKan (left Kan extension)** — partial-information propagation upward across strata.
- **RKan (right Kan extension)** — demand-driven propagation downward across strata.
- **Galois bridges** — connections between heterogeneous lattices, allowing cross-domain composition while preserving monotone-fixpoint semantics within each stratum.

## 5. Honesty caveats (preempting reviewers)

Per `2026-03-21_CATEGORICAL_STRUCTURE_FIVE_SYSTEMS` honest assessment:

- The "uniform bifibration" framing of `2026-03-13_LAYERED_RECOVERY_CATEGORICAL_ANALYSIS` does not hold across all instances.
- The **right structural claim** is heterogeneous: a *stratified poset of monotone-fixpoint cells* with inter-stratum Galois bridges and Kan extensions, where each stratum's category may differ.
- This honesty is itself a contribution: classical stratified-Datalog literature assumes uniformity; LRP allows heterogeneity.

## 6. Novelty against classical stratified semantics

**Pre-paper requirement**: Q-A1 novelty-positioning audit (see `../open-questions.md`).

Tentative novelty claims to defend in the audit:
- Classical stratified-Datalog stratifies *negation* on a fixed Herbrand base. LRP stratifies *general non-monotone computation* across heterogeneous lattices.
- Galois bridges between heterogeneous lattices are not in the stratified-Datalog tradition.
- Kan extensions for inter-stratum composition are not in the stratified-Datalog tradition.
- The unification across NAF + WF + type-stratification + effect-stratification + retraction + topology under one structural framework is, conjecturally, novel.

## 7. Outline (TBD)

- §1 Introduction — non-monotone computation on monotone substrates.
- §2 Background — propagator networks and Poly (cite Paper Poly), CALM, stratified-Datalog history.
- §3 The Layered Recovery Principle — definition, stratification, inter-stratum transitions.
- §4 Six instances — NAF, WF, type, effect, retraction, topology.
- §5 The recovery theorem — stratified composition correctness.
- §6 Universality conjecture — what is the right scope (FOTFL? lattice-valued? all Turing-computable?).
- §7 Related work — stratified-Datalog (Apt-Blair-Walker, Przymusinski, Van Gelder-Ross-Schlipf, Gelfond-Lifschitz); CALM and BloomL; AFT (Denecker-Marek-Truszczyński); abstract interpretation (Cousot-Cousot).
- §8 Limitations — Galois connections aspirational in some instances; universality is a conjecture.

## 8. Open questions blocking this paper

See `../open-questions.md`:
- Q-A1 (novelty positioning) — **required before substantive Paper A work begins**.
- Q-A2 (instance set freeze).
- Q-A3 (right uniform structural claim).
- Q-A4 (universality conjecture aggressiveness).

## 9. Engineering anchors required

See `../engineering-anchors.md`:
- A5 (LRP instances inventory) — six instances + PPN-series scan for more.

## 10. Provenance / source material

- `2026-03-13_LAYERED_RECOVERY_CATEGORICAL_ANALYSIS.md` — original categorical analysis (now known to be too uniform).
- `2026-03-21_CATEGORICAL_STRUCTURE_FIVE_SYSTEMS.md` — honest per-instance assessment.
- PPN series PIRs (topology-strata + others).
- BSP-LE Track 2B PIR (speculation strata).
