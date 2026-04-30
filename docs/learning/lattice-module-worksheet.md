---
title: "Companion Worksheet"
subtitle: "Lattice Fundamentals & Module Theory — Prologos Learning Portfolio"
date: "Version 2.0"
geometry: margin=0.85in
fontsize: 11pt
mainfont: "DejaVu Serif"
sansfont: "DejaVu Sans"
monofont: "DejaVu Sans Mono"
header-includes:
  - \usepackage{amsmath,amssymb,amsthm}
  - \usepackage{enumitem}
---

\newpage

# How to use this worksheet

This workbook runs in parallel with the curriculum. Each part has three sub-parts:

1. **Concept checks** — quick sanity questions you should be able to answer in under a minute each.
2. **Diagram drills** — Hasse diagrams to draw. Use the blank grids (or graph paper).
3. **Proof warm-ups** — short computations and proofs.

The worksheet tracks the curriculum's 5-part, 18-module structure. Do one part per study session (or two, if the part is short). Answer keys for the concept checks are at the end.

**Part A** — Posets and Hasse diagrams (curriculum Module 1)

**Part B** — Lattices (curriculum Module 2)

**Part C** — Distributive, modular, complemented (curriculum Module 3)

**Part D** — Semilattices, CALM, and fixpoints (curriculum Modules 5, 6)

**Part E** — Galois connections and abstract interpretation (curriculum Modules 4, 7)

**Part F** — Hypercube, quantales, bilattices (curriculum Modules 8, 9, 10)

**Part G** — Modules and the submodule lattice (curriculum Modules 11, 12)

**Part H** — Modular law, chain conditions, decomposition (curriculum Modules 13, 14, 15)

**Part I** — Prologos applications: Hyperlattice Conjecture, SRE lens, codebase tour (curriculum Modules 16, 17, 18)

\vspace{6mm}

---

\newpage

# Part A · Posets and Hasse Diagrams

## A1. Concept checks

Mark each statement T or F. If false, repair it.

1. ______ Every finite poset is a lattice.
2. ______ In a Hasse diagram, transitive edges are drawn explicitly.
3. ______ A totally ordered set (chain) is a lattice.
4. ______ The power-set lattice $\mathcal{P}(\{a, b, c\})$ has height 4.
5. ______ Antisymmetry says $a \leq b$ implies $b \not\leq a$.
6. ______ The opens of $\mathbb{R}$ under $\subseteq$ form a lattice.
7. ______ In any poset, the least upper bound of a pair is unique whenever it exists.
8. ______ The Boolean hypercube $Q_n$ has $2^n$ elements and its Hasse diagram is the $n$-cube graph.

## A2. Diagram drills

**A2.1** Draw the Hasse diagram of $(\mathrm{Div}(12), \mid)$.

\vspace{50mm}

**A2.2** Draw $(\mathrm{Div}(30), \mid)$ and $\mathcal{P}(\{2, 3, 5\})$. Confirm they are isomorphic.

\vspace{55mm}

**A2.3** Draw a 5-element poset that is *not* a lattice, and circle the pair with no join.

\vspace{50mm}

**A2.4** Draw $Q_3$ labelling vertices by their bit-strings. Identify the two Hamiltonian paths.

\vspace{55mm}

## A3. Proof warm-ups

**A3.1** Prove: in any poset, if $\sup S$ exists, it is unique.

\vspace{25mm}

**A3.2** Prove: the intersection of any family of subsets of $X$ is the infimum of that family in $(\mathcal{P}(X), \subseteq)$.

\vspace{25mm}

\newpage

# Part B · Lattices

## B1. Concept checks

Complete the definition or identity.

1. A lattice is a poset in which every finite non-empty subset has both a __________________ and a __________________.
2. The absorption law says $a \wedge (a \vee b) = $ __________ and $a \vee (a \wedge b) = $ __________.
3. $a \leq b \iff a \wedge b = $ __________ $\iff a \vee b = $ __________.
4. A lattice is **complete** when __________________________________________________.
5. In $\mathrm{L}(M)$, the meet is __________ and the join is __________.
6. The correspondence theorem identifies the interval $[N, M]$ with __________________________.
7. A flat lattice on a set $\{a, b, c\}$ has __________ elements arranged as __________.

## B2. Diagram drills

**B2.1** Draw $\mathrm{L}(\mathbb{Z}/12\mathbb{Z})$ as a $\mathbb{Z}$-module. Label each node with a submodule.

\vspace{60mm}

**B2.2** Draw the lattice of subgroups of $S_3$. Is it modular? If not, circle the pentagon $N_5$ inside.

\vspace{60mm}

**B2.3** Draw the 4-element flat term lattice $\{\bot, \mathrm{var}, \mathrm{ctor}, \top\}$ from `term-lattice.rkt`. Identify what makes it flat.

\vspace{55mm}

## B3. Proof warm-ups

**B3.1** Prove the absorption law for $\mathrm{L}(M)$ directly: for submodules $N, P$ of $M$, show $N \cap (N + P) = N$.

\vspace{30mm}

**B3.2** Show $\mathrm{Div}(n) \cong \mathcal{P}(\{p_1, \ldots, p_k\})$ whenever $n$ is squarefree with distinct prime factors.

\vspace{30mm}

\newpage

# Part C · Distributive, Modular, Complemented

## C1. Forbidden sublattice drill

For each lattice, decide whether it is (a) distributive, (b) modular, (c) complemented. Write Yes / No in each cell.

| Lattice            | Distributive? | Modular? | Complemented? |
|--------------------|---------------|----------|---------------|
| Chain of 4 elements |              |          |               |
| $B_3 = \mathcal{P}(\{a,b,c\})$ |   |          |               |
| $M_3$ (diamond)    |               |          |               |
| $N_5$ (pentagon)   |               |          |               |
| $\mathrm{L}(\mathbb{Z}/12\mathbb{Z})$ |    |          |               |
| $\mathrm{L}((\mathbb{Z}/2\mathbb{Z})^2)$ |  |          |               |
| $Q_4$ (hypercube)  |               |          |               |
| Flat lattice $\{\bot, 0, 1, \omega, \top\}$ |   |          |         |

## C2. Diagram drills

**C2.1** Draw $M_3$ and $N_5$ side by side from memory.

\vspace{55mm}

**C2.2** Draw the lattice of ideals of $\mathbb{Z}/24\mathbb{Z}$. Highlight any $M_3$ or $N_5$ sublattice.

\vspace{60mm}

## C3. Proof warm-ups

**C3.1** Prove $M_3$ is modular. (Check the definition on all triples where $a \leq c$.)

\vspace{30mm}

**C3.2** Prove $N_5$ is not modular by exhibiting a triple $(a, b, c)$ with $a \leq c$ for which $a \vee (b \wedge c) \neq (a \vee b) \wedge c$.

\vspace{30mm}

**C3.3** Prove: in a distributive lattice, complements are unique.

\vspace{25mm}

\newpage

# Part D · Semilattices, CALM, and Fixpoints

## D1. Concept checks

Fill in the blank or answer in one sentence.

1. A **join-semilattice** is a poset in which every pair has a ______________.
2. A function $f : L \to L'$ is **monotone** if ___________________________________.
3. The **CALM theorem** says a distributed computation is coordination-free iff it is __________________ on a __________________.
4. The **Knaster–Tarski theorem** guarantees that any __________________ function on a __________________ lattice has a least fixpoint.
5. In Kleene iteration, $\mu f = \bigvee_{n \geq 0} f^n(\bot)$ is guaranteed to terminate in finitely many steps when $L$ is __________________.
6. A **Gauss–Seidel fixpoint** is a __________________ on a stack of strata, each of which is a Tarski fixpoint.
7. **Well-founded semantics** assigns each atom a value in the three-element set ________, ________, ________.

## D2. Compute

**D2.1** Let $f : \mathcal{P}(\{1,2,3,4\}) \to \mathcal{P}(\{1,2,3,4\})$ be $f(S) = \{1\} \cup \{k+1 : k \in S, k+1 \leq 4\}$. Compute $f^n(\emptyset)$ for $n = 0, 1, 2, 3, 4, 5$. Identify the least fixpoint.

\vspace{40mm}

**D2.2** Let $g : \mathcal{P}(\{0,1,\ldots,10\}) \to \mathcal{P}(\{0,1,\ldots,10\})$ be $g(S) = \{0\} \cup \{n+2 : n \in S, n+2 \leq 10\}$. Compute the least fixpoint by Kleene iteration. How many steps does it take?

\vspace{40mm}

## D3. Proof warm-ups

**D3.1** Show that negation $\neg : \mathcal{P}(X) \to \mathcal{P}(X)$, $S \mapsto X \setminus S$, is antitone (order-reversing), not monotone. Explain why this is why negation-as-failure must be quarantined at its own stratum.

\vspace{30mm}

**D3.2** Give a non-monotone function on a join-semilattice that is commutative and associative but breaks the CALM guarantee. (Hint: consider a "last-writer-wins" merge.)

\vspace{30mm}

**D3.3** Sketch the strata for evaluating `p :- q, not r. q :- true. r :- false.` Identify which stratum computes which atom.

\vspace{30mm}

\newpage

# Part E · Galois Connections and Abstract Interpretation

## E1. Concept checks

1. A pair $(\alpha, \gamma)$ of monotone maps is a **Galois connection** iff __________________________________.
2. In the adjunction $\alpha \dashv \gamma$, $\alpha$ preserves arbitrary __________ and $\gamma$ preserves arbitrary __________.
3. $\gamma \circ \alpha$ is always a __________________ operator.
4. $\alpha \circ \gamma$ is always a __________________ operator.
5. The **soundness of abstract fixpoints** says: if $(\alpha, \gamma, F, F^\sharp)$ is a sound abstraction, then $\alpha(\mu F) \sqsubseteq$ __________.
6. In the interval domain, $\alpha(S) =$ __________ if $S$ is nonempty.

## E2. Compute

**E2.1** Define $(\alpha, \gamma)$ for the sign domain $\{\bot, -, 0, +, \top\}$ abstracting $\mathcal{P}(\mathbb{Z})$. Verify the adjunction on a specific pair.

\vspace{45mm}

**E2.2** Compute the abstract addition $+^\sharp$ on the sign domain for $(+) +^\sharp (-)$. What is the sound over-approximation?

\vspace{25mm}

**E2.3** Compose two Galois connections $\alpha_1 \dashv \gamma_1 : C \to A$ and $\alpha_2 \dashv \gamma_2 : A \to B$. Write out the composed adjunction explicitly and verify it.

\vspace{35mm}

## E3. Proof warm-ups

**E3.1** Prove: in any Galois connection, $\alpha(\bot_C) = \bot_A$ and $\gamma(\top_A) = \top_C$.

\vspace{25mm}

**E3.2** Show that $\gamma \circ \alpha$ is idempotent (a closure operator). Show that $\alpha \circ \gamma$ is idempotent (a kernel operator).

\vspace{30mm}

**E3.3** Build the Galois connection associated with a relation $R \subseteq X \times Y$: $\alpha(S) = \{y : \forall x \in S, (x, y) \in R\}$, $\gamma(T) = \{x : \forall y \in T, (x, y) \in R\}$. Verify the adjunction.

\vspace{30mm}

\newpage

# Part F · Hypercube, Quantales, Bilattices

## F1. Concept checks

1. The Boolean hypercube $Q_n$ has __________ elements. Its Hasse diagram is the __________-dimensional __________ graph.
2. Subcube containment in $Q_n$ is an $O(1)$ check by __________________.
3. A **quantale** is a complete __________ equipped with an associative __________ distributing over arbitrary __________.
4. The four semiring gaps that a quantale closes are: __________, __________, __________, __________.
5. A **bilattice** is a set with two lattice orders: a __________ order and an __________ order.
6. FOUR's four elements are: $\mathtt{false}, \_\_\_\_, \mathtt{true}, \_\_\_\_$.
7. The QTT multiplicity lattice in `mult-lattice.rkt` has __________ elements: $\bot, \_\_, \_\_, \_\_, \top$.

## F2. Diagram drills

**F2.1** Draw $Q_3$ with a Gray-code Hamiltonian path highlighted. Label each vertex with its bitstring.

\vspace{60mm}

**F2.2** Draw FOUR with both orders overlaid: solid edges for $\leq_t$, dashed for $\leq_i$.

\vspace{55mm}

**F2.3** Draw the flat multiplicity lattice $\{\bot, 0, 1, \omega, \top\}$. Is there an $M_3$ inside? Circle it.

\vspace{50mm}

## F3. Compute

**F3.1** Given nogood $\{x_1 = 1, x_3 = 0\}$ over $n = 4$ bits, write the (mask, pattern) pair. Check containment of $1011$ and $0100$ by bitmask AND.

\vspace{30mm}

**F3.2** Compute $0 \sqcup 1$, $1 \sqcup \omega$, $0 \sqcup \omega$, $\omega \sqcup \omega$ in the QTT multiplicity lattice.

\vspace{25mm}

**F3.3** Verify: the power-set $(\mathcal{P}(X), \cup, \cap)$ is a commutative unital quantale. Identify the tensor and the unit.

\vspace{25mm}

## F4. Proof warm-ups

**F4.1** Prove: in any Heyting algebra, $a \wedge b \leq c \iff a \leq b \to c$.

\vspace{25mm}

**F4.2** Show that the tropical semiring $(\mathbb{R} \cup \{\infty\}, \min, +)$ is a quantale. Identify the join, the tensor, and the unit.

\vspace{25mm}

**F4.3** Give an example of a *non-commutative* quantale. (Hint: formal languages under concatenation.)

\vspace{25mm}

\newpage

# Part G · Modules and the Submodule Lattice

## G1. Concept checks

Match each module property (left) with its lattice counterpart (right). Draw a line.

| Module property | | Lattice counterpart |
|:--|:--:|:--|
| Simple | $\square$ | Complemented |
| Uniserial | $\square$ | ACC |
| Semisimple | $\square$ | Two-element lattice |
| Noetherian | $\square$ | DCC |
| Artinian | $\square$ | Chain |
| Finite length | $\square$ | Finite height |

## G2. Diagram drills

**G2.1** Draw $\mathrm{L}(\mathbb{Z}/p^3 \mathbb{Z})$. Identify it as a familiar small lattice.

\vspace{50mm}

**G2.2** Draw $\mathrm{L}(\mathbb{Z}/p\mathbb{Z} \oplus \mathbb{Z}/p\mathbb{Z})$ in full. Identify the $M_3$ sitting inside.

\vspace{60mm}

**G2.3** Let $M = k[x]/(x^3)$. Draw $\mathrm{L}(M)$. Identify the lattice type.

\vspace{50mm}

## G3. Proof warm-ups

**G3.1** Show: an $R$-module $M$ is simple iff $\mathrm{L}(M)$ has exactly two elements.

\vspace{25mm}

**G3.2** Show: $\mathbb{Z}/p\mathbb{Z}$ and $\mathbb{Z}/q\mathbb{Z}$ have isomorphic submodule lattices (for distinct primes $p, q$) but are not isomorphic as $\mathbb{Z}$-modules.

\vspace{30mm}

\newpage

# Part H · Modular Law, Chain Conditions, Decomposition

## H1. State and explain

**H1.1** Write the modular law in full, with hypothesis, in two lines.

\vspace{15mm}

**H1.2** In plain English, explain the meaning of the hypothesis $A \leq C$.

\vspace{15mm}

## H2. Compute

**H2.1** In $\mathbb{Z}^2$, let $A = \mathbb{Z}(1, 0)$, $B = \mathbb{Z}(0, 1)$, $C = \mathbb{Z}(1, 1)$. Verify that $A + (B \cap C) \neq (A + B) \cap C$. What hypothesis of the modular law fails?

\vspace{40mm}

**H2.2** Let $M = \mathbb{Z}/12\mathbb{Z}$, $A = 4\mathbb{Z}/12\mathbb{Z}$, $B = 6\mathbb{Z}/12\mathbb{Z}$, $C = 2\mathbb{Z}/12\mathbb{Z}$. Check $A \leq C$. Compute both sides of the modular law. They should agree.

\vspace{45mm}

## H3. Proof warm-ups

**H3.1** Derive the Second Isomorphism Theorem $(N + P)/N \cong P/(N \cap P)$ from the modular law plus the First Isomorphism Theorem.

\vspace{40mm}

**H3.2** Show: length additivity $\ell(N + P) + \ell(N \cap P) = \ell(N) + \ell(P)$ follows from the Second Isomorphism Theorem (finite-length case).

\vspace{30mm}

**H3.3** Prove: a Noetherian module need not be Artinian. ($\mathbb{Z}$ as a $\mathbb{Z}$-module is the standard example.)

\vspace{25mm}

**H3.4** Prove: if $M$ has finite length, then $M$ is both Noetherian and Artinian.

\vspace{25mm}

## H4. Prologos-sense modules

**H4.1** Given a feature that decomposes as $C_1 \oplus C_2$ and requires worldview-sensitive reads on a propagator network, list the two realisation choices (A and B) from curriculum Module 15. In one sentence each, explain when you would prefer each.

\vspace{45mm}

**H4.2** The clause-scope / query-scope refactor in Prologos took three design iterations before choosing Resolution B. In one paragraph, explain (a) what Realisation A looked like, (b) what "tag collapse" bug made it fail, (c) what Realisation B did differently.

\vspace{55mm}

\newpage

# Part I · Prologos Applications

## I1. The Hyperlattice Conjecture and Design Mantra

**I1.1** State the Hyperlattice Conjecture in one sentence.

\vspace{20mm}

**I1.2** Write the Design Mantra from memory.

\vspace{20mm}

**I1.3** For each word of the mantra (all-at-once; all in parallel; structurally emergent; information flow; ON-NETWORK) write one sentence explaining what it challenges in a design.

\vspace{60mm}

## I2. The SRE Lattice Lens

Run the six questions on the cell of your choice. Choose one of:

(a) `term-lattice.rkt` (the 4-element flat term lattice).

(b) `bilattice.rkt`'s bilattice-variable (ascending/descending cell pair).

(c) `interval-domain.rkt`'s interval cell.

(d) `mult-lattice.rkt`'s QTT multiplicity lattice.

(e) The worldview cache (projection of decision cells onto $Q_n$).

**Q1.** Classification — VALUE or STRUCTURAL? Justify.

\vspace{20mm}

**Q2.** Algebraic properties — Boolean? Distributive? Heyting? Quantale? Join-semilattice?

\vspace{20mm}

**Q3.** Bridges to other lattices. For each bridge, give the Galois pair $(\alpha, \gamma)$ or explain why no such pair exists.

\vspace{25mm}

**Q4.** Full bridge diagram. Sketch all lattices and all bridges.

\vspace{35mm}

**Q5.** Primary vs derived. Which is authoritative and which is a projection/cache?

\vspace{15mm}

**Q6.** Hasse diagram. Draw it. Identify adjacency, diameter, and (if Boolean) subcube structure.

\vspace{40mm}

## I3. Codebase orientation

**I3.1** Open `bilattice.rkt`. Find `lattice-desc`. Identify bot, top, join, meet, leq for the `bool-lattice`.

\vspace{30mm}

**I3.2** Open `mult-lattice.rkt`. Find `mult-lattice-merge`. Predict the output of merging $0$ with $\omega$, and of merging $0$ with $1$. Verify by reading the code.

\vspace{30mm}

**I3.3** Open `.claude/rules/stratification.md`. List all five+ concrete strata and for each, name one file in the codebase where its handler (or equivalent) lives.

\vspace{40mm}

\newpage

# Part J · Self-Assessment and Explainer Kit

For each statement, rate yourself 1–5 on "can I explain this to a colleague in 60 seconds with a diagram?"

| Statement                                                                    | 1 · 2 · 3 · 4 · 5 |
|------------------------------------------------------------------------------|-------------------|
| "A module's submodule lattice is always modular."                            |                   |
| "The modular law is the second isomorphism theorem."                         |                   |
| "Semisimple = complemented lattice."                                         |                   |
| "Length = height of the submodule lattice."                                  |                   |
| "$M_3$ and $N_5$ are the forbidden sublattices."                             |                   |
| "Non-isomorphic modules can share a lattice."                                |                   |
| "The correspondence theorem identifies $[N, M]$ with $\mathrm{L}(M/N)$."     |                   |
| "CALM: monotone on a semilattice = coordination-free."                       |                   |
| "Knaster–Tarski + Kleene iteration computes fixpoints."                      |                   |
| "Every bridge between lattices is a Galois connection."                      |                   |
| "Abstract fixpoints over-approximate concrete fixpoints (soundness)."        |                   |
| "$Q_n$ is Boolean; subcube-containment is $O(1)$ bitmask AND."               |                   |
| "Quantales close four gaps in semirings as annotation algebras."             |                   |
| "A bilattice has two orders: truth and information."                         |                   |
| "Prologos cells are on-network; their merges are monotone joins."            |                   |
| "The Hyperlattice Conjecture: Hasse diagram IS the parallel decomposition."  |                   |
| "SRE lens: six questions for every cell."                                    |                   |

## J1. Explainer drafts

**J1.1** Draft a 150-word explainer titled *"Why we draw the submodule lattice first in Prologos."* Audience: linear algebra plus a little ring theory.

\vspace{60mm}

**J1.2** Draft a 150-word explainer titled *"What CALM buys the Prologos scheduler."* Audience: a PL / dataflow engineer new to the project.

\vspace{60mm}

**J1.3** Draft a 150-word explainer titled *"The Hyperlattice Conjecture in one paragraph."* Audience: a Prologos collaborator who has read the mantra but not unpacked it.

\vspace{60mm}

**J1.4** Draw the single diagram you would use to introduce the lattice perspective to a new Prologos collaborator.

\vspace{80mm}

\newpage

# Answer Key (for self-grading)

## A1
1. F (antichains with > 2 elements are not lattices — pairs have no join/meet). 2. F (transitive edges are omitted). 3. T. 4. T (layers of 0, 1, 2, 3 elements). 5. F (antisymmetry says $a \leq b$ *and* $b \leq a$ imply $a = b$; nothing excluded otherwise). 6. F (the opens form a *frame*: a complete lattice where finite meets distribute over arbitrary joins). 7. T. 8. T.

## B1
1. Meet; join. 2. $a$; $a$. 3. $a$; $b$. 4. Every subset has both a meet and a join. 5. $\cap$; $+$. 6. $\mathrm{L}(M/N)$. 7. 5 elements; bottom, three incomparable middle nodes, top — a flat lattice with three middle generators.

## C1

| Lattice | Distributive? | Modular? | Complemented? |
|---------|:--:|:--:|:--:|
| Chain of 4            | yes | yes | no (only $\top$ and $\bot$) |
| $B_3$                 | yes | yes | yes |
| $M_3$                 | no  | yes | yes |
| $N_5$                 | no  | no  | yes |
| $\mathrm{L}(\mathbb{Z}/12)$ | yes | yes | no |
| $\mathrm{L}((\mathbb{Z}/2)^2)$ | no | yes | yes |
| $Q_4$                 | yes | yes | yes |
| Flat $\{\bot, 0, 1, \omega, \top\}$ | no (contains $M_3$) | yes | yes |

## D1
1. Join. 2. $a \leq b$ implies $f(a) \leq f(b)$. 3. Monotone; join-semilattice. 4. Monotone; complete. 5. Finite (or more generally, the iteration $f^n(\bot)$ stabilises in finitely many steps). 6. Fixpoint. 7. True; false; unknown.

## E1
1. $\alpha(p) \sqsubseteq q \iff p \leq \gamma(q)$. 2. Joins; meets. 3. Closure. 4. Kernel. 5. $\mu F^\sharp$. 6. $[\min S, \max S]$.

## F1
1. $2^n$; $n$; hypercube. 2. Bitmask AND. 3. Sup-lattice; tensor product; joins. 4. Idempotency; contradiction element; completeness; induced order. 5. Truth; information. 6. Unknown; contradict. 7. 5 elements; $0$, $1$, $\omega$.

## G1
Simple ↔ Two-element lattice. Uniserial ↔ Chain. Semisimple ↔ Complemented. Noetherian ↔ ACC. Artinian ↔ DCC. Finite length ↔ Finite height.

## H2.1
All three of $A, B, C$ are rank-1 subgroups of $\mathbb{Z}^2$; $A \not\leq C$ so the modular-law hypothesis fails. $A + (B \cap C) = A + 0 = A$ but $(A + B) \cap C = \mathbb{Z}^2 \cap C = C \neq A$.

## H3.1
Apply the first isomorphism theorem to the composition $P \hookrightarrow N + P \twoheadrightarrow (N + P)/N$. The kernel is $P \cap N$. Modularity ensures the image is all of $(N + P)/N$, giving $(N + P)/N \cong P/(N \cap P)$.

## H4.1
**Realisation A (separate cells with bridge morphisms):** each $C_i$ is its own cell, bridges propagate values between them. Prefer when $C_i$ carry genuinely different types or live at different strata. **Realisation B (bitmask-tagged layers on a shared carrier cell):** one cell holds all components, each component identified by a bitmask tag. Prefer for value-level decomposition with worldview semantics — eliminates the tag-collapse bug class.

## I1.2
"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."

## I3.2
Merging $0$ with $\omega$ gives $\omega$ (their join in the flat lattice; $\omega$ dominates). Merging $0$ with $1$ gives $\top$ (contradiction: a binder cannot be both erased and used once). Verified by reading `mult-lattice-merge` and `mult-lattice-contradicts?` in `mult-lattice.rkt`.

## D3.1
$\neg$ is antitone: if $S \subseteq T$ then $X \setminus T \subseteq X \setminus S$, so $\neg T \leq \neg S$ (order reverses). CALM requires monotone functions; antitone moves cannot fire in $S_0$. In Prologos, negation-as-failure is quarantined at $S_1$ with a fork + quiesce protocol (`relations.rkt`'s `process-naf-request`).

\vspace{15mm}

---

*End of worksheet. Accumulate your drawn diagrams. The best Prologos explainer you will ever write is the one where you have twenty lattice pictures in front of you, and you can point at them.*
