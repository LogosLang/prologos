- [1. Introduction](#org75c6247)
  - [1.1 The Quantum Probability Revolution in Social Science](#orged0c4de)
  - [1.2 Why Hilbert Space?](#org06094be)
  - [1.3 Historical Overview](#org754e2d8)
  - [1.4 Connection to Prologos](#orga83750a)
- [2. Foundations: Quantum Probability vs. Classical Probability](#orgf34d949)
  - [2.1 Kolmogorov Probability and Its Limitations](#org69ba9d6)
  - [2.2 Hilbert Space Probability](#org816afbc)
  - [2.3 Interference and Superposition](#orgbc2e9e6)
  - [2.4 Entanglement and Non-Separability](#orgb6fa4d5)
  - [2.5 Open Quantum Systems and Decoherence](#orgb5273af)
  - [2.6 Contextuality](#org5fd8cfa)
- [3. Quantum Decision Theory](#org4d19be0)
  - [3.1 The Yukalov-Sornette Framework](#org7450375)
  - [3.2 Classical Decision Paradoxes Resolved](#org0f919e2)
  - [3.3 Quantum Prospect Theory](#orge31863d)
  - [3.4 Order Effects in Judgments](#org398a0bd)
- [4. Quantum Cognition](#org5ae1a55)
  - [4.1 Similarity Judgments](#orgc16869d)
  - [4.2 Conceptual Combination](#org3559244)
  - [4.3 Memory and Perception](#org7fcbd95)
  - [4.4 Causal Reasoning](#org3611b1d)
  - [4.5 The Open Systems Approach](#org88e8eb9)
- [5. Quantum Game Theory](#org6fb3b45)
  - [5.1 The EWL Protocol](#org8aa1af0)
  - [5.2 Quantum Prisoner's Dilemma](#org78b049d)
  - [5.3 Quantum Auctions and Mechanism Design](#orgbab5c8c)
  - [5.4 Evolutionary Quantum Game Theory](#org20267b3)
- [6. Quantum Finance and Economics](#org43b5532)
  - [6.1 The Schrödinger-Black-Scholes Connection](#org1c6527a)
  - [6.2 Open Quantum Systems in Markets](#org1f00b1e)
  - [6.3 Portfolio Optimization](#org30788d9)
  - [6.4 Quantum-Like Models of Market Behavior](#orge1d2059)
- [7. Quantum Social Dynamics](#org63ad6ba)
  - [7.1 Opinion Dynamics and Polarization](#orgc778404)
  - [7.2 Information Diffusion via Quantum Walks](#orga61b091)
  - [7.3 Voting Behavior](#orgce541a4)
  - [7.4 Social Choice and Contextuality](#org9e69931)
- [8. Categorical and Compositional Approaches](#org94277bc)
  - [8.1 Categorical Quantum Mechanics (CQM)](#orgbb99a9b)
  - [8.2 DisCoCat and Quantum NLP](#org9f2dc5f)
  - [8.3 Sheaf-Theoretic Contextuality](#orgd0d0fb5)
  - [8.4 Connection to Prologos's Categorical Architecture](#org40c866b)
- [9. Modeling with Tensor-Aware Propagators: Opportunities](#org8cfebda)
  - [9.1 Decision Modeling](#org404b4a5)
  - [9.2 Game-Theoretic Modeling](#orgc2318e4)
  - [9.3 Financial Modeling](#org93ca904)
  - [9.4 Social Network Modeling](#org72d34dd)
  - [9.5 Survey and Polling Models](#org22ca803)
- [10. Open Problems and Future Directions](#org206c3e2)
  - [10.1 Empirical Validation Challenges](#orgc99fdde)
  - [10.2 The Parameter Explosion Problem](#org9a3b5cb)
  - [10.3 Non-Markovian Extensions](#org6fa24c4)
  - [10.4 Connecting Quantum-Like to Actual Quantum Computing](#org9690799)
  - [10.5 Contextuality as the Key Resource](#orgce0be3f)
  - [10.6 Cross-Domain Compositional Models](#orgdb72587)
- [11. References](#orgbd81b5f)
  - [Quantum Decision Theory](#orged686c3)
  - [Quantum Cognition](#org1f972f0)
  - [Quantum Game Theory](#orgdc9ac04)
  - [Quantum Finance](#org0e0a9f2)
  - [Open Quantum Systems in Cognition](#org659c15b)
  - [Contextuality](#orga3aef28)
  - [Quantum Walks and Social Networks](#org13e0a7e)
  - [Categorical and Compositional](#orgddec220)
  - [Prologos Internal Documents](#org2c1b28e)



<a id="org75c6247"></a>

# 1. Introduction


<a id="orged0c4de"></a>

## 1.1 The Quantum Probability Revolution in Social Science

Over the past three decades, a growing community of researchers has discovered that the mathematical formalism of quantum mechanics &#x2014; Hilbert spaces, superposition, interference, entanglement, and projective measurement &#x2014; provides a more natural framework than classical (Kolmogorovian) probability for modeling human decision-making, cognition, social dynamics, and economic behavior. This is not a claim about quantum physics in the brain. It is a claim about mathematics: quantum probability theory is the *next-simplest* probability theory after classical probability, and it naturally accommodates phenomena &#x2014; contextuality, order effects, interference &#x2014; that classical probability cannot represent.

The field has reached institutional maturity. A dedicated journal, *Quantum Economics and Finance* (SAGE, in collaboration with the Center for Quantum Social and Cognitive Science), publishes peer-reviewed research. Special issues in *Quantum Reports* (MDPI), *Frontiers in Physics*, and *Topics in Cognitive Science* have collected major contributions. Comprehensive references include Busemeyer & Bruza's *Quantum Models of Cognition and Decision* (2012), Haven & Khrennikov's *Quantum Social Science* (2013), and the *Palgrave Handbook of Quantum Models in Social Science*. A 2026 systematic review (Jammal et al.) documents steady publication growth, with over 60 articles in 2024 alone.


<a id="org06094be"></a>

## 1.2 Why Hilbert Space?

Classical probability (Kolmogorov, 1933) assigns probabilities to events as elements of a Boolean algebra. The key properties: probabilities are real and non-negative; they add for disjoint events; the total is 1. This framework assumes:

-   **Commutativity:** P(A and B) = P(B and A).
-   **The law of total probability:** P(A) = P(A|B)P(B) + P(A|¬B)P(¬B).
-   **Single sample space:** All events can be jointly represented.

Human cognition and social behavior routinely violate all three. The order in which questions are asked changes the answers (non-commutativity). The disjunction effect violates the law of total probability. Preferences cannot always be represented in a single consistent framework (contextuality).

Quantum probability (von Neumann, 1932) replaces the Boolean algebra with a Hilbert space. Events are subspaces; probabilities are squared magnitudes of projections. This framework accommodates:

-   **Non-commutativity:** Projecting onto subspace A then B differs from B then A.
-   **Interference:** |a+b|² ≠ |a|² + |b|² when cross-terms are nonzero.
-   **Contextuality:** Different measurement contexts yield incompatible probability spaces.

The crucial point: these are *mathematical* properties of Hilbert spaces, not *physical* properties of quantum mechanics. Any system exhibiting contextuality, order effects, or interference &#x2014; whether it is a photon, a human decision-maker, or a financial market &#x2014; is more naturally described by quantum probability than by classical probability.


<a id="org754e2d8"></a>

## 1.3 Historical Overview

The idea of applying quantum formalism to cognition emerged independently from several sources in the 1990s:

-   **Aerts and collaborators** (Brussels) developed a quantum-like model of concept combination, showing that the "pet-fish" problem (a guppy is a good example of "pet fish" but a poor example of either "pet" or "fish") requires a state space richer than classical probability.
-   **Khrennikov** (Linnaeus University) developed a contextual probability framework, pointing out that violations of the formula of total probability can serve as a quantitative measure of non-classicality.
-   **Bordley** applied quantum probability to decision-making, showing that interference effects explain preference reversals.

The field accelerated in the 2000s with:

-   **Busemeyer and collaborators** (Indiana University) developing formal quantum models of specific cognitive phenomena: the conjunction fallacy, the disjunction effect, order effects in judgments.
-   **Haven and Khrennikov** connecting quantum formalism to financial markets and economics.
-   **Yukalov and Sornette** (ETH Zurich) developing Quantum Decision Theory as a comprehensive mathematical framework.

The 2010s saw consolidation into textbooks and institutional infrastructure. The 2020s have brought empirical validation at scale (the QQ equality tested on 70+ national surveys), practical applications (quantum computing for portfolio optimization), and new theoretical developments (quantum-like Bayesian networks, open quantum systems for cognitive dynamics).


<a id="orga83750a"></a>

## 1.4 Connection to Prologos

A companion document ("Tensor-Aware Propagator Networks with Unitary Evolution") describes how Prologos's propagator network can be extended with TensorCells (joint amplitude distributions over multiple variables) and unitary evolution (reversible transformations of quantum-like states). This background document provides the domain knowledge for what such a system could model.

The connection is direct: every quantum-like model in the literature requires (1) a state space (Hilbert space), (2) evolution operators (unitaries), and (3) measurement (projection + Born rule). In Prologos, these map to (1) TensorCells, (2) unitary propagators, and (3) the measurement stratum with ATMS integration. The dependent type system provides compile-time dimensional correctness; the propagator network provides the computational engine; the Layered Recovery Principle ensures that unitary evolution and measurement are correctly stratified.


<a id="orgf34d949"></a>

# 2. Foundations: Quantum Probability vs. Classical Probability


<a id="org69ba9d6"></a>

## 2.1 Kolmogorov Probability and Its Limitations

Classical probability theory (Kolmogorov, 1933) rests on a probability space (Ω, F, P) where Ω is a sample space, F is a σ-algebra of events, and P is a probability measure. For finite spaces, this reduces to:

-   A set of outcomes {ω₁, &#x2026;, ωₙ}.
-   Probabilities p(ωᵢ) ≥ 0 with Σᵢ p(ωᵢ) = 1.
-   P(A) = Σ<sub>ωᵢ∈A</sub> p(ωᵢ) for any event A ⊆ Ω.

The law of total probability follows: P(A) = P(A|B)P(B) + P(A|B<sup>c</sup>)P(B<sup>c</sup>), expressing P(A) as a weighted sum over a partition. This is the foundation of Bayesian reasoning.

**Limitations in cognitive science:**

The law of total probability is empirically violated in human judgment. Tversky and Shafir (1992) demonstrated the **disjunction effect**: in a two-stage gamble, participants who knew they won the first stage chose to play again (67%); participants who knew they lost also chose to play again (59%); but participants who did *not* know the outcome of the first stage chose to play again at a lower rate (36%). Under classical probability, not knowing the outcome should produce a probability between 59% and 67%, not below both. This is a direct violation of the law of total probability.


<a id="org816afbc"></a>

## 2.2 Hilbert Space Probability

Quantum probability replaces the classical framework with:

-   A Hilbert space H (a complex vector space with inner product).
-   A state |ψ⟩ ∈ H with ||ψ|| = 1 (a unit vector).
-   Observables as projection operators P<sub>A</sub> (self-adjoint, P² = P).
-   Probability of event A: p(A) = ||P<sub>A</sub>|ψ⟩||² = ⟨ψ|P<sub>A</sub>|ψ⟩.
-   State update after observing A: |ψ'⟩ = P<sub>A</sub>|ψ⟩ / ||P<sub>A</sub>|ψ⟩|| (Lüders' rule).

**Key differences from classical probability:**

1.  **Non-commutativity.** If P<sub>A</sub> P<sub>B</sub> ≠ P<sub>B</sub> P<sub>A</sub>, then the probability of "A then B" differs from "B then A": p(A then B) = ||P<sub>B</sub> P<sub>A</sub>|ψ⟩||² ≠ ||P<sub>A</sub> P<sub>B</sub>|ψ⟩||² = p(B then A). This models order effects in survey questions.

2.  **Interference.** If |ψ⟩ = α|a⟩ + β|b⟩, then: p(c) = |⟨c|ψ⟩|² = |α⟨c|a⟩ + β⟨c|b⟩|² = |α|²|⟨c|a⟩|² + |β|²|⟨c|b⟩|² + 2Re(α\*β⟨c|a⟩\*⟨c|b⟩) The last term is the *interference term*, absent in classical probability.

3.  **Incompatibility.** Two observables A, B are incompatible if their projection operators do not commute. Measuring A disturbs the state with respect to B. There is no joint probability distribution for incompatible observables.


<a id="orgbc2e9e6"></a>

## 2.3 Interference and Superposition

The interference term is the key mechanism by which quantum-like models produce non-classical predictions. Consider a decision between options C (cooperate) and D (defect):

-   Classical: p(C) = p(C|know<sub>win</sub>)p(know<sub>win</sub>) + p(C|know<sub>lose</sub>)p(know<sub>lose</sub>) = 0.67 × 0.5 + 0.59 × 0.5 = 0.63.
-   Quantum: |ψ⟩ = α|win⟩ + β|lose⟩. After interference: p(C) = |α|²p(C|win) + |β|²p(C|lose) + 2Re(α\*β × interference) The interference term can be *negative*, reducing p(C) below both conditional probabilities. This explains the disjunction effect.

The double-slit analogy is useful: when a particle passes through two slits simultaneously (superposition), the probability pattern at the detector shows interference fringes. When a decision-maker considers two possible states of the world simultaneously (uncertainty), the choice probability shows "interference fringes" &#x2014; deviations from the weighted average of the conditional probabilities.


<a id="orgb6fa4d5"></a>

## 2.4 Entanglement and Non-Separability

Two systems A and B are **entangled** when their joint state cannot be factored:

|                  |                 |                              |                |                |
|----------------- |---------------- |----------------------------- |--------------- |--------------- |
| ψ<sub>AB</sub>⟩ ≠ | ψ<sub>A</sub>⟩ ⊗ | ψ<sub>B</sub>⟩ for any states | ψ<sub>A</sub>⟩, | ψ<sub>B</sub>⟩. |

The Bell state (|00⟩ + |11⟩)/√2 is the canonical example: if A is measured and found to be 0, then B is guaranteed to be 0 as well, even though neither had a definite value before measurement. The correlations are stronger than any classical probabilistic model can produce (Bell's theorem).

In social science, entanglement models non-separable preferences and correlated beliefs:

-   **Voter preferences:** A voter's preference for president and senator cannot always be factored into independent presidential and senatorial preferences. "Ticket splitting" (different parties for different races) may violate classical separability.
-   **Agent interactions:** Two traders whose strategies are correlated through shared information or social influence may have entangled strategy states.
-   **Concept combination:** The concept "pet fish" (well-modeled by a guppy) cannot be derived from independent concepts "pet" (well-modeled by a dog) and "fish" (well-modeled by a trout). Aerts showed this requires entangled concept states.


<a id="orgb5273af"></a>

## 2.5 Open Quantum Systems and Decoherence

Real quantum systems interact with their environments, causing decoherence &#x2014; the loss of quantum coherence (interference capability). The GKSL (Gorini-Kossakowski- Sudarshan-Lindblad) master equation governs this evolution:

```
dρ/dt = -i[H, ρ] + Σ_k (L_k ρ L_k† - ½{L_k†L_k, ρ})
```

where ρ is the density matrix (mixed state), H is the Hamiltonian (unitary dynamics), and L<sub>k</sub> are Lindblad operators (environmental interaction). The first term drives unitary evolution (rotation); the second term drives decoherence (decay of off-diagonal elements).

In cognitive modeling (Asano, Khrennikov et al.), this models decision-making:

-   The initial state ρ₀ is a superposition of choices (indecision).
-   The Hamiltonian H encodes the decision-maker's preferences and information.
-   The Lindblad operators L<sub>k</sub> model interaction with the "mental environment" (memory, emotions, social pressure).
-   The stationary state ρ\_∞ is the final decision &#x2014; a classical mixture (diagonal density matrix) with no remaining quantum coherence.

The **diffidence** (classical entropy minus quantum entropy) tracks the decision process: it starts high (quantum uncertainty exceeds classical) and decays to zero as decoherence eliminates quantum effects, leaving a classical choice.


<a id="org5fd8cfa"></a>

## 2.6 Contextuality

**Contextuality** is the property that the outcome of a measurement depends on what other measurements are performed alongside it. In classical probability, outcomes are context-independent: the probability of "heads" on a coin does not depend on whether a die is also rolled. In quantum mechanics, the probability of a spin measurement outcome depends on which axis is measured simultaneously.

Dzhafarov and Kujala developed the **Contextuality-by-Default (CbD)** framework, which extends contextuality analysis to "inconsistently connected" systems &#x2014; those where marginal distributions change across contexts (a common feature of behavioral data). The CbD framework distinguishes between:

-   **Direct influences:** Changes in marginal distributions due to context changes.
-   **True contextuality:** Correlations that cannot be explained by any classical coupling, even after accounting for direct influences.

The "Snow Queen" experiment (Cervantes & Dzhafarov) provided the first unequivocal empirical evidence of true contextuality in human behavior. A 2025 study found true contextuality in global investment decisions, demonstrating that the phenomenon extends beyond laboratory settings to real-world economic behavior.


<a id="org4d19be0"></a>

# 3. Quantum Decision Theory


<a id="org7450375"></a>

## 3.1 The Yukalov-Sornette Framework

Quantum Decision Theory (QDT), developed by Vyacheslav Yukalov and Didier Sornette (ETH Zurich), is a comprehensive mathematical framework that decomposes behavioral probability into classical and quantum components.

**Mathematical formulation.** The probability of choosing a prospect πⱼ is:

```
p(πⱼ) = f(πⱼ) + q(πⱼ)
```

where:

-   f(πⱼ) is the **utility factor** &#x2014; the classical probability derived from expected utility or other rational choice models. It satisfies all classical probability axioms: f(πⱼ) ≥ 0, Σⱼ f(πⱼ) = 1.
-   q(πⱼ) is the **attraction factor** &#x2014; the quantum interference term capturing emotional, irrational, and bias-driven components. It satisfies Σⱼ q(πⱼ) = 0 (the interference terms sum to zero, preserving total probability).

The attraction factor arises from the entanglement between the decision-maker's strategic state and the prospects being evaluated. When prospects are composite (involving multiple attributes or stages), the probability operator decomposes into products of sub-operators, and cross-terms appear due to entanglement.

**The Quarter Law.** QDT predicts that the average magnitude of the attraction factor is:

```
⟨|q|⟩ = 1/4
```

This is not merely an empirical finding but is derivable as the non-informative prior over several families of distributions (uniform, beta, Gaussian). The Quarter Law provides a parameter-free quantitative prediction: the quantum deviation from classical expected utility averages 25% of the choice probability.

**Empirical validation.** The Quarter Law has been tested on simple risky choices (lottery pairs) and group-level data strongly support it (Yukalov & Sornette, 2016).


<a id="org0f919e2"></a>

## 3.2 Classical Decision Paradoxes Resolved

QDT resolves the major anomalies of classical decision theory as natural consequences of quantum interference:

**Allais paradox.** People prefer a certain $1M to an 89% chance of $1M + 10% chance of $5M + 1% chance of $0, yet simultaneously prefer a 10% chance of $5M to an 11% chance of $1M. This violates expected utility's independence axiom. In QDT, the interference term is positive for the certain option (reinforcing certainty preference) and negative for the mixed gamble (suppressing risk tolerance), producing the observed pattern.

**Ellsberg paradox.** People prefer betting on a known 50-50 urn to an urn with unknown composition, even when the expected values are identical. Classical probability requires ambiguity-neutral behavior. In QDT, ambiguity generates a negative attraction factor (ambiguity aversion), reducing the probability of choosing the ambiguous option below its utility factor.

**Disjunction effect.** As described in §2.1: knowing the outcome of a first stage leads to playing again regardless, but not knowing leads to refusing. The interference between the "won" and "lost" branches is destructive, reducing the play-again probability below both conditional probabilities.

**Conjunction fallacy.** People judge P(feminist ∧ bank teller) > P(bank teller), violating the conjunction rule. In QDT, the conjunction is not a classical intersection but a sequential projection. The "feminist" projection rotates the state into a subspace where "bank teller" has higher probability than it does from the initial state.


<a id="orge31863d"></a>

## 3.3 Quantum Prospect Theory

Quantum Prospect Theory augments Kahneman and Tversky's Cumulative Prospect Theory (CPT) with quantum interference effects. The key formula adds an interference term to the CPT value function:

```
V_quantum(prospect) = V_CPT(prospect) + interference(prospect)
```

The interference term captures conflicting interests, ambiguity, and emotions arising during deliberation. Two estimation methods exist:

-   The **interference alternation method**: estimates the sign and magnitude of interference from the structure of the prospect.
-   The **interference quarter law**: uses the QDT quarter law as a default magnitude.

Empirical comparisons show that at the aggregate level, CPT-based QDT outperforms pure CPT. At the individual level, RDU-based (Rank-Dependent Utility) QDT best captures heterogeneity across subjects.


<a id="org398a0bd"></a>

## 3.4 Order Effects in Judgments

Wang and Busemeyer (2013) derived a parameter-free prediction from quantum probability: the **QQ equality**.

For two binary yes/no questions A and B:

```
p(Ay,By) + p(An,Bn) - p(By,Ay) - p(Bn,An) = 0
```

where p(Ay,By) is the probability of answering "yes" to A and then "yes" to B.

**Derivation.** The QQ equality follows from the law of reciprocity for Hilbert space inner products: |⟨ψ<sub>B</sub>|ψ<sub>A</sub>⟩|² = |⟨ψ<sub>A</sub>|ψ<sub>B</sub>⟩|². The real part of the inner product is independent of projection order, yielding the equality.

**Empirical validation.** Wang et al. (2014) tested the QQ equality on **70 national representative surveys** (most with >1000 participants each, conducted by Gallup and Pew Research) plus two laboratory experiments. The QQ equality was strongly upheld &#x2014; a remarkable result given that it is a parameter-free, a priori prediction derived purely from the mathematical structure of Hilbert space.

Neither Bayesian models nor Markov models generally satisfy the QQ equality. Its empirical success is one of the strongest pieces of evidence for the quantum probability framework in cognitive science.


<a id="org5ae1a55"></a>

# 4. Quantum Cognition


<a id="orgc16869d"></a>

## 4.1 Similarity Judgments

The **Quantum Similarity Model** (QSM), developed by Pothos and Busemeyer, models concepts as subspaces of a Hilbert space (not as points, as in classical geometric models). The key innovation: similarity between two concepts is computed as the probability of a sequential projection.

**Formal structure:**

-   A concept C is associated with a subspace H<sub>C</sub> of the Hilbert space.
-   The mental state is a vector |ψ⟩.
-   Similarity of A to B is: sim(A,B) = ||P<sub>B</sub> P<sub>A</sub>|ψ⟩||² (project onto A, then B).

**Key advantages:**

-   **Asymmetry.** sim(A,B) ≠ sim(B,A) because P<sub>B</sub> P<sub>A</sub> ≠ P<sub>A</sub> P<sub>B</sub> in general. This captures Tversky's (1977) finding that similarity judgments are asymmetric: North Korea is more similar to China than China is to North Korea.
-   **Diagnosticity.** Context (prior projections) changes similarity judgments. After seeing several fruits, an apple is similar to an orange; after seeing several round objects, an apple is similar to a ball.
-   **Unification.** The QSM uses the same mathematical framework as the conjunction fallacy model, the order effects model, and the disjunction effect model. All are instances of projection in Hilbert space.


<a id="org3559244"></a>

## 4.2 Conceptual Combination

The conjunction fallacy (§3.2) is a special case of conceptual combination. More broadly, quantum models address the general problem of how concepts combine:

**The guppy problem.** A guppy is a good example of "pet fish" but a poor example of either "pet" or "fish." Classical fuzzy set theory (Osherson & Smith, 1981) predicts that membership in A∧B should be at most min(membership in A, membership in B). The guppy violates this: membership in "pet fish" exceeds membership in both components.

Aerts (2009) showed that this requires an *entangled* state in the tensor product of the "pet" and "fish" Hilbert spaces. The concept "pet fish" is not the intersection of "pet" and "fish" but a projection onto a subspace of the composite space that has no product-state representation.

**Overextension.** When combining concepts, people sometimes extend the category beyond what either component warrants. "Stone lion" is judged as a better predator than "stone" warrants and a better decorative object than "lion" warrants. This "emergence of new meaning" in conceptual conjunction maps to the quantum phenomenon of measurement outcomes that differ from what either subsystem alone would produce.


<a id="org7fcbd95"></a>

## 4.3 Memory and Perception

Quantum models have been applied to:

-   **Memory retrieval:** The order in which memory items are recalled affects subsequent retrieval probabilities, modeled as sequential projections.
-   **Perception:** Ambiguous stimuli (Necker cube, duck-rabbit) are modeled as superpositions that collapse upon "measurement" (conscious perception). The dynamics of perceptual switching are modeled by unitary evolution.
-   **Categorization:** Categorization decisions under uncertainty exhibit interference effects analogous to the disjunction effect.


<a id="org3611b1d"></a>

## 4.4 Causal Reasoning

Trueblood and Busemeyer (2011, 2012) developed **quantum-like Bayesian networks** (QLBNs) by replacing classical probabilities with quantum probability amplitudes.

**Framework:**

-   Any classical Bayesian network can be generalized to a quantum Bayesian network by replacing conditional probability tables with conditional amplitude tables.
-   A **similarity heuristic** automatically fits parameters through vector similarities, addressing the exponential growth of quantum parameters.

**Key results:**

-   QLBNs account for **order effects in causal judgments**: judging whether A causes C and then whether B causes C gives different results than the reverse order. Classical Bayesian networks, which satisfy the local Markov condition, cannot produce order effects.
-   **Anti-discounting:** In classical causal reasoning, learning about an alternative cause should reduce belief in the original cause (discounting). Humans sometimes do the opposite (anti-discounting). QLBNs model this via constructive interference between causal pathways.
-   **Reciprocity:** Observing that A causes B increases belief that B causes A, even when there is no causal mechanism. This arises naturally from the symmetry of Hilbert space inner products.


<a id="org88e8eb9"></a>

## 4.5 The Open Systems Approach

Asano, Ohya, Tanaka, Basieva, and Khrennikov developed a comprehensive model of cognitive dynamics using the GKSL master equation (§2.5).

**Core model:**

1.  The decision-maker's mental state is a density matrix ρ on a Hilbert space whose basis elements correspond to choices.
2.  The Hamiltonian H encodes preferences and information dynamics.
3.  Lindblad operators L<sub>k</sub> model interaction with the mental environment: memory retrieval, emotional processing, social pressure.
4.  The master equation dρ/dt = -i[H,ρ] + Σ<sub>k</sub>(L<sub>k</sub> ρ L<sub>k</sub>† - ½{L<sub>k</sub>†L<sub>k</sub>, ρ}) drives the mental state toward a stationary state ρ\_∞.
5.  The stationary state is a classical mixture (diagonal) representing the final decision.

**Applications:**

-   **Disjunction effect in Prisoner's Dilemma:** The Shafir-Tversky experiments are explained by decoherence: knowing the opponent's move collapses the superposition, while not knowing preserves it, and interference between the "opponent cooperated" and "opponent defected" branches reduces the cooperation probability.
-   **US political decision-making:** Voters' superposition of Republican/Democrat preferences decoheres through exposure to campaign information.
-   **Biological applications:** The same formalism models E. coli glucose-lactose metabolism and epigenetic evolution.

**Non-Markovian extensions** are an active frontier. The GKSL equation assumes Markovian (memoryless) dynamics, but human cognition has strong memory effects. Non-Markovian quantum dynamics (Nakajima-Zwanzig equations, time-convolutionless approaches) are under development.


<a id="org6fb3b45"></a>

# 5. Quantum Game Theory


<a id="org8aa1af0"></a>

## 5.1 The EWL Protocol

Eisert, Wilkens, and Lewenstein (1999) proposed the first formal framework for quantum game theory, using entangled quantum strategies.

**Mathematical formulation:**

1.  Classical strategies are mapped to qubit states: Cooperate = |0⟩, Defect = |1⟩.

2.  An **entangling gate** creates initial correlations: J(γ) = exp(iγ σ<sub>x</sub> ⊗ σ<sub>x</sub> / 2) where γ ∈ [0, π/2] controls the entanglement degree and σ<sub>x</sub> is the Pauli-X matrix.

3.  The initial state is: |ψ<sub>in</sub>⟩ = J(γ)|00⟩.

4.  Each player applies a unitary strategy U ∈ SU(2), parameterized as: U(θ, φ) = [[e<sup>iφ</sup>cos(θ/2), sin(θ/2)], [-sin(θ/2), e<sup>-iφ</sup>cos(θ/2)]] With I = U(0,0) = Cooperate and σ<sub>x</sub> = U(π,0) = Defect as classical strategies.

5.  The final state is: |ψ<sub>out</sub>⟩ = J†(γ) · (U<sub>A</sub> ⊗ U<sub>B</sub>) · J(γ)|00⟩.

6.  Payoffs are computed from measurement probabilities: P<sub>σ,τ</sub> = |⟨σ,τ|ψ<sub>out</sub>⟩|² for σ,τ ∈ {0,1} Expected payoff = Σ<sub>σ,τ</sub> P<sub>σ,τ</sub> × payoff(σ,τ).

**Key special strategy:** Q = U(0, π/2) &#x2014; a quantum strategy with no classical analogue. It commutes with J(γ) and has the property that Q against any classical strategy yields at least the cooperative payoff.


<a id="org78b049d"></a>

## 5.2 Quantum Prisoner's Dilemma

In the classical Prisoner's Dilemma, the unique Nash equilibrium (Defect, Defect) is Pareto-dominated by (Cooperate, Cooperate). Rational self-interest leads to a collectively worse outcome.

The quantum version resolves this:

**Three entanglement regimes:**

-   γ = 0 (no entanglement): Classical game recovered exactly. J(0) = I, so the entangling gate is trivial. The unique NE is (D, D).
-   0 < γ < π/2 (partial entanglement): Intermediate regime. The classical NE may still exist but with modified payoffs.
-   γ = π/2 (maximum entanglement): The strategy pair (Q, Q) is a Nash equilibrium *and* Pareto-optimal. Neither player can improve their payoff by unilateral deviation. The dilemma is resolved.

**The mechanism:** At maximum entanglement, the initial state J(π/2)|00⟩ creates quantum correlations between the players. The quantum strategy Q exploits these correlations: Q ⊗ Q against the entangled initial state produces the cooperative outcome with certainty. Any unilateral deviation from Q reduces the deviator's payoff (Nash equilibrium property) while no outcome Pareto-dominates Q ⊗ Q.

**Critiques:** Benjamin and Hayden noted that the two-parameter restriction U(θ,φ) is not the most general SU(2) strategy. With the full three-parameter SU(2), Nash equilibria may not exist. The robustness of quantum game-theoretic advantages under noise and decoherence is an active research area.


<a id="orgbab5c8c"></a>

## 5.3 Quantum Auctions and Mechanism Design

Quantum information theory has implications for economic mechanism design:

**Circumventing impossibility results.** Classical mechanism design is constrained by impossibility theorems (Arrow, Gibbard-Satterthwaite). Agents with access to quantum mechanisms can, under certain conditions, circumvent these constraints: quantum entanglement provides correlation resources unavailable classically.

**Quantum economies.** Players producing and consuming "quantum goods" with entangled strategies yield economic equilibria with distinctive properties. These models "shed new light on theories of mechanism design, auction and contract in the quantum era."

**Practical quantum auctions.** Economic applications relying on quantum information aspects (not computational speedup) are viable with just a few qubits. This suggests potential early applications of near-term quantum technology in auction design.

**Quantum Condorcet Voting.** Quantum Condorcet Voting has been used to disprove Arrow's Impossibility Theorem in the quantum setting: for small readout amplitudes, quantum outcomes track the classical scheme, but beyond a modest noise level, they converge to non-classical distributions that satisfy the conditions Arrow showed to be classically impossible.


<a id="org20267b3"></a>

## 5.4 Evolutionary Quantum Game Theory

Quantum game theory extends to evolutionary settings where strategies evolve over time under selection pressure:

-   **Quantum replicator dynamics:** The classical replicator equation is generalized to track evolution of quantum strategy parameters. Quantum strategies can invade classical populations under certain conditions.
-   **Biological applications:** Quantum game models have been applied to evolutionary biology, where the "entanglement" is reinterpreted as genetic correlation between related organisms.
-   A 2025 review in *Quantum Information Processing* maps the intersection of quantum and evolutionary game theory comprehensively.


<a id="org43b5532"></a>

# 6. Quantum Finance and Economics


<a id="org1c6527a"></a>

## 6.1 The Schrödinger-Black-Scholes Connection

Emmanuel Haven demonstrated that the Black-Scholes-Merton equation for option pricing is a special case of the Schrödinger equation when markets are perfectly efficient. The derivation introduces a parameter ℏ (by analogy with Planck's constant) that measures the degree of market inefficiency &#x2014; the amount of arbitrage arising from non-instantaneous price changes, information asymmetry, and unequal trader wealth.

When ℏ → 0 (perfect efficiency), the equation reduces to classical Black-Scholes. When ℏ > 0, quantum-like effects emerge: interference between trading strategies, non-commutative observables for price and momentum, and wave-like propagation of market information. The Black-Scholes equation is equivalent to the imaginary-time Schrödinger equation of a free particle &#x2014; a connection that brings the full apparatus of quantum mechanics into financial modeling.

The "financial Hamiltonian" (analogous to the energy operator in physics) is determined by the rate of return. Born's rule, interference of probabilities, and non-commutative operators all emerge from the organization of production and investment processes.


<a id="org1f00b1e"></a>

## 6.2 Open Quantum Systems in Markets

Market dynamics are naturally modeled as *open* quantum systems &#x2014; systems interacting with an environment. The GKSL master equation (§2.5) governs the evolution of market states:

-   The density matrix ρ represents the distribution over market configurations.
-   The Hamiltonian H encodes fundamental valuations and market microstructure.
-   Lindblad operators L<sub>k</sub> model information arrival, regulatory intervention, and trader behavioral noise.
-   Decoherence (decay of off-diagonal elements) corresponds to the market "resolving" uncertainty &#x2014; the transition from quantum-like superposition of prices to a definite traded price.

Khrennikov developed a contextual probability framework using agents to model this: each trader operates in a context (their information set, risk tolerance, time horizon), and the incompatibility of different agents' contexts produces non-classical aggregate behavior.


<a id="org30788d9"></a>

## 6.3 Portfolio Optimization

Quantum computing is finding practical application in portfolio optimization:

**IBM + Vanguard (2024-2025):** Used 109 qubits on the IBM Quantum Heron r1 processor (133 available) with circuits containing up to 4,200 gates. On simplified ETF portfolio construction, the hybrid quantum-classical workflow performed on par with and sometimes surpassed state-of-the-art classical solvers as problem size increased.

**Citi + Classiq:** Applied the Quantum Approximate Optimization Algorithm (QAOA) to portfolio optimization problems.

**Fidelity + IonQ:** Developed quantum models for synthetic financial data generation.

Classical portfolio optimization becomes intractable when adding realistic constraints (lot sizes, maximum positions, sector limits). Quantum computers encode exponentially many portfolio configurations as superpositions, exploring the solution space more efficiently and potentially avoiding local minima.

McKinsey estimates $400-600 billion in potential value from quantum computing in financial services by 2035. The CFA Institute (2025) recommends starting with Monte Carlo methods for pricing/risk, then moving to discrete optimization as quantum hardware matures.


<a id="orge1d2059"></a>

## 6.4 Quantum-Like Models of Market Behavior

Beyond formal quantum computing, quantum-like models explain market phenomena that classical models struggle with:

-   **Interference in trading decisions:** A trader considering two information sources simultaneously may make different decisions than if they processed each source sequentially. The interference term captures "cognitive momentum" in trading.
-   **Non-commutative observables:** Asking "what is the fair price?" and "what is the market sentiment?" in different orders yields different answers &#x2014; the act of assessing price changes one's sentiment assessment, and vice versa.
-   **Contextuality in markets:** The same asset has different risk profiles depending on what else is in the portfolio &#x2014; a form of quantum contextuality.


<a id="org63ad6ba"></a>

# 7. Quantum Social Dynamics


<a id="orgc778404"></a>

## 7.1 Opinion Dynamics and Polarization

Recent models (2024-2025) apply quantum formalism to opinion dynamics:

**Beliefs as quantized energy levels.** A 2024 model represents political beliefs as energy levels in a quantum system. Polarization corresponds to the formation of energy bands and interband gaps when like-minded individuals interact. Transitions between polarized groups require significant "energy" (effort, information, social pressure), explaining the persistence of political polarization.

**Hamiltonian framework (2025).** A novel model provides: (1) complete probabilistic formulation with memory effects, (2) parameterized interaction potentials for social hierarchy and network topology, and (3) explicit consensus emergence mechanisms. Unlike classical opinion dynamics models (DeGroot, bounded confidence), the quantum model naturally produces oscillatory behavior, tunneling between opinion clusters, and interference between information pathways.

**Quantum simulations on quantum hardware (2025).** Models of opinion dynamics have been implemented on IBM Quantum devices, using superposition for opinion uncertainty, measurement-induced collapse for opinion commitment, and entanglement for social correlations.


<a id="orga61b091"></a>

## 7.2 Information Diffusion via Quantum Walks

Quantum walks &#x2014; the quantum analog of classical random walks &#x2014; model information propagation through social networks:

**Continuous-Time Quantum Walk Information Propagation Model (CTQW-IPM).** Ranks crucial individuals in social networks for information spread. Overcomes limitations of classical simulation models (extensive iteration, multiple control parameters) by using the quantum walk's natural spreading behavior.

**Asymmetry-resolving quantum walk.** A key innovation addresses the problem that quantum walk Hamiltonians are Hermitian (symmetric transitions), but social influence is inherently asymmetric. The model lifts the social network state into a higher-dimensional space and applies controlled operators to recover asymmetric influence.

**Quantum Walk Neural Networks.** Learn a graph-dependent diffusion operation that can *direct* information flow (unlike classical random walks in GCN/DCNN that diffuse uniformly). The "coin operators" controlling quantum walk behavior are learned from data.

**Graph Quantum Walk Transformer (GQWformer, 2024).** Developed by Zhejiang Lab, this architecture embeds quantum walks into graph transformers, capturing both global and local structure. Validated on 5 benchmark datasets across biological, chemical, and social domains, outperforming 11 baseline models.


<a id="orgce541a4"></a>

## 7.3 Voting Behavior

Quantum-like models have been applied extensively to voting:

**Nonseparability of voter preferences.** "Ticket splitting" &#x2014; voting for different parties in executive vs. legislative races &#x2014; demonstrates non-separable preferences that violate classical Kolmogorovian probability through inconsistent Bayesian updating. The quantum formalism naturally accommodates this via entangled preference states in the tensor product of the presidential and senatorial Hilbert spaces.

**Quantum interference in political preferences.** Election contexts modeled with quantum probability produce an interference term for contextuality. Some reconstructed decision eigenvectors produce "hyperbolic interference" (magnitude exceeding 1), indicating strong non-classicality.

**Coalition formation (Bagarello, 2015).** Quantum field theory formalism derives dynamical equations for the evolution of parties' coalition preferences, incorporating voter behavior impact.

**Quantum Condorcet Voting and Arrow's Theorem.** Quantum Condorcet Voting has been used to disprove Arrow's Impossibility Theorem in the quantum setting. For small readout amplitudes, quantum outcomes track the classical scheme; beyond a modest noise level, they converge to non-classical distributions that satisfy conditions Arrow showed to be classically impossible.

**Density operator models (Dubois).** Density operators relative to candidate families model voting intention, with proportionality hypotheses between density matrix coefficients and vote probabilities. Applied to the French 2012 presidential election with promising results.


<a id="org9e69931"></a>

## 7.4 Social Choice and Contextuality

The deepest connection between quantum theory and social science may be through contextuality:

**Topological connection (Baryshnikov).** "The Topology of Quantum Theory and Social Choice" identifies topological singularities encoding the difference between classical and quantum probability, establishing that a resolution to the social choice problem is equivalent to a resolution to the violation of unicity in quantum measurement frameworks.

**Contextuality-by-Default in economics (2025).** True contextuality has been found in global investment decisions, demonstrating that quantum-like contextuality extends beyond cognitive experiments to real-world economic behavior.

**Intransitivity and contextuality.** The relationship between intransitive preferences (A ≻ B ≻ C ≻ A) and Type II contextuality (considered sine qua non of quantum mechanics) has been observed in human decision-making experiments.


<a id="org94277bc"></a>

# 8. Categorical and Compositional Approaches


<a id="orgbb99a9b"></a>

## 8.1 Categorical Quantum Mechanics (CQM)

Categorical Quantum Mechanics, developed primarily by Bob Coecke, Samson Abramsky, Chris Heunen, and Jamie Vicary at Oxford, provides the mathematical foundation for the tensor-aware propagator network design described in the companion document.

The framework axiomatizes quantum processes in terms of:

-   **Monoidal categories:** Sequential (∘) and parallel (⊗) composition of processes.
-   **Dagger categories:** Every process f has an adjoint f†, giving time-reversal.
-   **Compact closed categories:** Duality between objects enables wire-bending in string diagrams, corresponding to bidirectional constraint propagation.
-   **Frobenius algebras:** Merge and copy operations at nodes, with the spider theorem ensuring topology-independence.

The graphical calculus (string diagrams) provides a complete reasoning language: any equation between quantum processes that holds in finite-dimensional Hilbert spaces can be proved by diagram manipulation alone.


<a id="org9f2dc5f"></a>

## 8.2 DisCoCat and Quantum NLP

The most developed social-science-adjacent application of CQM is **DisCoCat** (Categorical Compositional Distributional Semantics), introduced by Coecke, Sadrzadeh, and Clark:

-   **Key insight:** Pregroup grammars and quantum processes both form rigid monoidal categories. A monoidal functor maps grammatical structure to vector space semantics, composing word meanings into sentence meanings via the same algebra that composes quantum states.
-   **Verbs as unitary operations:** A transitive verb is a linear map S ⊗ O → S (where S = subject space, O = object space, S = sentence space). This is structurally identical to a unitary operator on a tensor product.
-   **Extensions:** Density matrices for lexical ambiguity (Piedeleu et al.), convex relations for cognitive modeling (Bolt et al., 2016), and games for dialogue and Wittgenstein's language games (Hedges & Lewis, 2018).

This connects to Prologos through the quantale-enriched categorical framework: the same string diagram calculus that describes quantum NLP describes propagation through TensorCells.


<a id="orgd0d0fb5"></a>

## 8.3 Sheaf-Theoretic Contextuality

Abramsky and Brandenburger developed a sheaf-theoretic framework for contextuality that is *theory-independent* &#x2014; it applies to any situation with locally consistent but globally inconsistent empirical data:

-   Local sections over a measurement context describe the outcomes observable in that context.
-   The sheaf condition checks whether local sections glue to a global section.
-   Failure of the sheaf condition = contextuality = no single classical probability model accounts for all the data.

This connects directly to Prologos's sheaf-theoretic distributed reasoning (Beyond Prolog §8.3): the same mathematical structure that checks for quantum contextuality checks for consistency of distributed knowledge bases.


<a id="org40c866b"></a>

## 8.4 Connection to Prologos's Categorical Architecture

The categorical structures described in this section align precisely with Prologos's existing and planned architecture:

| CQM Structure            | Prologos Realization                       |
|------------------------ |------------------------------------------ |
| Monoidal category        | Propagator network (sequential + parallel) |
| Dagger                   | Adjoint/reverse propagation                |
| Compact closure          | Bidirectional constraints                  |
| Frobenius algebra        | Cell merge/broadcast operations            |
| Quantale enrichment      | Information-graded morphisms               |
| Sheaf condition          | Distributed consistency checking           |
| Tensor product           | TensorCell (joint state spaces)            |
| Completely positive maps | DensityCell propagators (measurement)      |

The vision: a single computational framework &#x2014; the quantale-enriched propagator network &#x2014; that simultaneously supports type inference, session type checking, relational logic, probabilistic reasoning, and quantum-like modeling. Each domain is an instantiation of the same enriched-categorical machinery.


<a id="org8cfebda"></a>

# 9. Modeling with Tensor-Aware Propagators: Opportunities


<a id="org404b4a5"></a>

## 9.1 Decision Modeling

The Yukalov-Sornette QDT framework maps to propagator constraints:

-   Each prospect is a basis element in an `AmplitudeCell`.
-   The decision-maker's state |ψ⟩ is a superposition of prospects.
-   The attraction factor q(π) emerges from the interference term when amplitudes are squared: p(π) = |⟨π|ψ⟩|² = f(π) + q(π).
-   The Quarter Law (⟨|q|⟩ = 1/4) becomes a testable propagator constraint.
-   Deliberation (time evolution of preference) is a unitary rotation of |ψ⟩.


<a id="orgc2318e4"></a>

## 9.2 Game-Theoretic Modeling

The EWL protocol encodes directly:

-   Two-player strategy space = `TensorCell [Strategy Strategy]`.
-   Entangling gate J(γ) = unitary propagator on the joint TensorCell.
-   Individual strategies = unitary propagators on subsystems.
-   Payoff computation = measurement + classical propagation.
-   Nash equilibrium = propagation to quiescence under payoff constraints.

The quantum Prisoner's Dilemma, where entangled strategies produce Pareto-optimal Nash equilibria, is expressible as a tensor-aware propagator network.


<a id="org93ca904"></a>

## 9.3 Financial Modeling

Haven's Schrödinger-Black-Scholes connection:

-   Market states as `AmplitudeCell` values in superposition.
-   The arbitrage parameter ℏ controls the degree of quantum-like behavior.
-   Unitary evolution encodes fundamental price dynamics.
-   Measurement = trade execution (collapse to definite price).
-   The GKSL equation via `DensityCell` models market decoherence.


<a id="org72d34dd"></a>

## 9.4 Social Network Modeling

Quantum walk propagators for opinion dynamics:

-   Each agent's belief is an `AmplitudeCell` over opinion options.
-   Social influence = unitary rotation toward neighbor's state.
-   Network topology determines propagator wiring.
-   Entanglement between agents = correlated belief updates via `TensorCell`.
-   Consensus = decoherence to classical mixture via Lindblad operators.


<a id="org22ca803"></a>

## 9.5 Survey and Polling Models

The QQ equality as a propagator constraint:

-   The Wang-Busemeyer QQ equality is automatically satisfied by any quantum probability model implemented on AmplitudeCells.
-   Violation detection becomes a constraint-propagation problem.
-   Order effects in survey questions are modeled by non-commutative projections.
-   The propagator network can optimize question ordering to minimize bias.


<a id="org206c3e2"></a>

# 10. Open Problems and Future Directions


<a id="orgc99fdde"></a>

## 10.1 Empirical Validation Challenges

While the QQ equality has strong empirical support (70+ national surveys), many quantum-like models have limited validation beyond explaining known anomalies post hoc. Prologos's modeling capabilities could help by making it easier to generate quantitative predictions from quantum-like models and test them against data.


<a id="org9a3b5cb"></a>

## 10.2 The Parameter Explosion Problem

Quantum Bayesian networks suffer from exponential growth of parameters with the number of variables. The similarity heuristic (Moreira & Wichert) helps, but principled dimensionality reduction for quantum-like social models remains open. Tensor network contraction methods may provide a path.


<a id="org6fa24c4"></a>

## 10.3 Non-Markovian Extensions

The GKSL master equation assumes Markovian (memoryless) dynamics, but human cognition has strong memory effects. Non-Markovian quantum dynamics (Nakajima-Zwanzig equations, time-convolutionless approaches) are an active frontier. Prologos's persistent (immutable) propagator network naturally preserves historical states, which could be exploited for memory kernels.


<a id="org9690799"></a>

## 10.4 Connecting Quantum-Like to Actual Quantum Computing

As quantum hardware matures (IBM Heron, IonQ), practical applications in finance are demonstrating near-parity with classical methods. The question arises: can quantum-like cognitive/social models be run on actual quantum hardware for speedup? The answer is nuanced &#x2014; the models use quantum math but typically involve classical simulation of small quantum systems. Quantum advantage would emerge for large-scale social simulations (many agents, entangled beliefs).


<a id="orgce0be3f"></a>

## 10.5 Contextuality as the Key Resource

The CbD framework (Dzhafarov & Kujala) provides a theory-independent way to detect and measure contextuality in behavioral data. Contextuality may be the key "resource" that quantum-like models provide &#x2014; analogous to how entanglement is a resource in quantum computing. Understanding when and why social/economic systems are contextual would guide where quantum-like models are most valuable.


<a id="orgdb72587"></a>

## 10.6 Cross-Domain Compositional Models

The categorical framework (CQM, DisCoCat) suggests the possibility of *compositional* quantum-like models that span domains: a model of voter cognition (quantum decision theory) composed with a model of social influence (quantum walks) composed with a model of media dynamics (open quantum systems). Prologos's propagator network, with its natural compositional structure, is well-suited to this vision.


<a id="orgbd81b5f"></a>

# 11. References


<a id="orged686c3"></a>

## Quantum Decision Theory

-   Yukalov, V.I. & Sornette, D. (2010). Mathematical structure of quantum decision theory. *Advances in Complex Systems* 13, 659-698.
-   Yukalov, V.I. & Sornette, D. (2011). Decision theory with prospect interference and entanglement. *Theory and Decision* 70, 283-328.
-   Yukalov, V.I. & Sornette, D. (2014). Conditions for quantum interference in cognitive sciences. *Topics in Cognitive Science* 6, 79-90.
-   Yukalov, V.I. & Sornette, D. (2016). Quantum probabilities as behavioral probabilities. *Entropy* 19, 112.


<a id="org1f972f0"></a>

## Quantum Cognition

-   Busemeyer, J.R. & Bruza, P.D. (2012). *Quantum Models of Cognition and Decision*. Cambridge UP.
-   Pothos, E.M. & Busemeyer, J.R. (2013). Can quantum probability provide a new direction for cognitive modeling? *Behavioral and Brain Sciences* 36, 255-274.
-   Wang, Z. & Busemeyer, J.R. (2013). A quantum question order model supported by empirical tests of an a priori and target prediction. *Topics in Cognitive Science* 5, 689-710.
-   Wang, Z. et al. (2014). Context effects produced by question orders reveal quantum nature of human judgments. *PNAS* 111, 9431-9436.


<a id="orgdc9ac04"></a>

## Quantum Game Theory

-   Eisert, J., Wilkens, M. & Lewenstein, M. (1999). Quantum games and quantum strategies. *Physical Review Letters* 83, 3077.
-   Benjamin, S.C. & Hayden, P.M. (2001). Multiplayer quantum games. *Physical Review A* 64, 030301.
-   Bagarello, F. (2015). Quantum dynamics for classical systems. *Springer*.


<a id="org0e0a9f2"></a>

## Quantum Finance

-   Haven, E. & Khrennikov, A. (2013). *Quantum Social Science*. Cambridge UP.
-   Haven, E. (2002). A discussion on embedding the Black-Scholes option pricing model in a quantum physics setting. *Physica A* 304, 507-524.
-   Rao, A., Yang, S. & Zakerinia, S. (2025). Using quantum game theory to model competition. *SSRN*.


<a id="org659c15b"></a>

## Open Quantum Systems in Cognition

-   Asano, M. et al. (2011). Quantum-like model of brain's functioning. *Journal of Theoretical Biology* 281, 56-64.
-   Asano, M. et al. (2011). Quantum-like dynamics of decision-making. *Physica A* 391, 2083-2099.
-   Khrennikov, A. (2023). Open systems, quantum probability, and logic for quantum-like modeling. *Entropy* 25, 886.


<a id="orga3aef28"></a>

## Contextuality

-   Dzhafarov, E.N. & Kujala, J.V. (2016). Context-content systems of random variables. *Philosophical Transactions A* 374, 20150235.
-   Cervantes, V.H. & Dzhafarov, E.N. (2018). Snow queen is evil and beautiful. *Decision* 5, 193-214.
-   Baryshnikov, Y. (2022). The topology of quantum theory and social choice. *Quantum Reports* 4, 14.


<a id="org13e0a7e"></a>

## Quantum Walks and Social Networks

-   Li, X. et al. (2022). CTQW information propagation model. *Neural Computing and Applications*.
-   Dernbach, S. et al. (2019). Quantum walk neural networks. *Applied Network Science*.


<a id="orgddec220"></a>

## Categorical and Compositional

-   Coecke, B., Sadrzadeh, M. & Clark, S. (2010). Mathematical foundations for a compositional distributional model of meaning. *Linguistic Analysis* 36, 345-384.
-   Abramsky, S. & Brandenburger, A. (2011). The sheaf-theoretic structure of non-locality and contextuality. *New Journal of Physics* 13, 113036.


<a id="org2c1b28e"></a>

## Prologos Internal Documents

-   Beyond Prolog: Frontiers for the Prologos Relational Language (2026-03-16).
-   Tensor-Aware Propagator Networks with Unitary Evolution (companion, 2026-03-16).
-   Logic Engine Design: Comprehensive Implementation Guide (2026-02-24).
-   Towards a General Logic Engine on Propagators (2026-02-24).
