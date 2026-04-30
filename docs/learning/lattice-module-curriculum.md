---
title: "Lattice Fundamentals & Module Theory"
subtitle: "A Prologos-Integrated Curriculum"
author: "Prologos Learning Portfolio"
date: "Version 2.0"
geometry: margin=1in
fontsize: 11pt
mainfont: "DejaVu Serif"
sansfont: "DejaVu Sans"
monofont: "DejaVu Sans Mono"
header-includes:
  - \usepackage{amsmath,amssymb,amsthm}
  - \usepackage{tikz}
  - \usepackage{enumitem}
  - \usepackage{framed}
  - \usepackage{xcolor}
  - \definecolor{ink}{HTML}{1E2749}
  - \definecolor{gold}{HTML}{C89F3C}
  - \definecolor{teal}{HTML}{3D5A6C}
  - \newenvironment{prologos}{\begin{shaded}\color{ink}\textbf{Prologos Hook} \\}{\end{shaded}}
---

\newpage

# About this Curriculum

This document is a self-contained curriculum in lattice theory and the module theory that grows out of it, aimed at a math-literate audience (fluent in groups, rings, and linear algebra; new or rusty on lattices and module theory). It is designed as learning material for **The Prologos Project**, with three explicit goals:

1. Give readers the vocabulary and intuition to **work within** a lattice-theoretic view of computation and modules.
2. Give readers the tools to **explain** Prologos to collaborators whose background is classical module theory, abstract interpretation, or applied mathematics but not lattice theory proper.
3. Give readers a **codebase-level bridge** from the mathematics to the actual Prologos source files, so an afternoon of study produces a map of where each idea lives.

Version 2.0 (this version) is a substantial rebuild over Version 1.0. The original ten-module arc was a classical lattice-first treatment of module theory. This version carries that treatment (in full) and adds three threads that the Prologos Project cannot run without: **lattices for computation** (semilattices, CALM, fixpoints, Galois connections, Heyting/Boolean/hypercube), **quantales and annotation algebras** (the April 2026 research line), and the **Prologos-sense notion of a "module of lattices"** (collections of lattices held together by Galois-connection bridges on a propagator network). Where Version 1.0 had eleven "Prologos Hook" placeholders, Version 2.0 fills them all with content that references actual Prologos source files and `.claude/rules` documents.

## Five parts, eighteen modules

\textbf{Part I — Lattice Fundamentals.} Posets, lattices, special classes, morphisms. The base layer.

\textbf{Part II — Lattices for Computation.} Semilattices, CALM, Tarski and Gauss–Seidel fixpoints, Galois connections and abstract interpretation, Heyting and Boolean lattices, the hypercube $Q_n$. The working lattice theory of propagator networks.

\textbf{Part III — Quantales \& Annotation Algebras.} Semirings and their four gaps, quantales as their completion, residuation, bilattices, QTT multiplicities as a quantale-adjacent lattice. The annotation layer.

\textbf{Part IV — Module Theory: Classical and Prologos-Sense.} Full classical $R$-module theory through the submodule lattice $\mathrm{L}(M)$: modular law, correspondence, chain conditions, Jordan–Hölder, Krull–Schmidt. Then the Prologos-sense notion of "module of lattices" with its two realisation choices (bridges vs bitmask-tagged layers).

\textbf{Part V — Prologos Applications.} The Hyperlattice Conjecture in operational form, the SRE Lattice Lens as a design methodology, and a guided tour of the Prologos codebase by stratum.

## How to read this

Read Part I linearly. Parts II, III, IV can be read in any order after Part I, though each builds small reading-dependencies on Module 4 (Galois connections). Part V should be read last, once the vocabulary of all four earlier parts is in hand.

## Prerequisites

Undergraduate algebra: groups, rings, ideals, quotients, linear algebra, basic vector-space duality. No prior lattice exposure assumed. No prior programming-languages exposure assumed; the PL / type-theory content in Parts II and III is self-contained.

## Companion artefacts

- `lattice-module-hub.html` — interactive web version with navigable parts, dark-mode default, self-check reveals, and embedded SVG diagrams.
- `lattice-module-worksheet.pdf` — problem set and diagram workbook, nine parts tracking the curriculum.

\newpage

# Part I — Lattice Fundamentals

## Module 0 · Why Lattices for Prologos

The Prologos Project makes a bet. The bet is the **Hyperlattice Conjecture**: every computable function is expressible as a fixpoint computation on lattices, and the Hasse diagram of the lattice IS the optimal parallel decomposition of that computation. If the conjecture holds, then lattices are not a convenient abstraction for studying computation — they are the shape of computation.

Four traditions of mathematics converge on lattices from different directions:

1. **Order theory.** Posets, meets, joins, modular and distributive classes, Dedekind and Birkhoff. The classical provenance. This is Part I.

2. **Abstract interpretation and dataflow analysis.** Cousot's framework: sound approximation of programs as Galois connections between concrete and abstract lattices; Tarski and Kleene fixpoints as the engine; CALM as the correctness criterion for monotone distributed computation. This is Part II.

3. **Annotation algebras.** Semirings for provenance (Green/Karvounarakis/Tannen), linear and quantitative type theory (Atkey), session types, probabilistic and weighted logic. Quantales complete semirings into lattices. This is Part III.

4. **Classical module theory.** A module's submodule lattice $\mathrm{L}(M)$ is a compressed portrait of the module itself. Length, chain conditions, semisimplicity, decomposition, and the entire suite of isomorphism theorems are lattice-theoretic content in disguise. This is Part IV.

Prologos's bet is that these four traditions are the same thing viewed from four angles, and that an engineering project can exploit the identity. Part V delivers on the bet: Module 16 states the Hyperlattice Conjecture and the Design Mantra that operationalises it; Module 17 runs the six-question SRE Lattice Lens that every new cell must pass; Module 18 walks the Prologos codebase stratum by stratum.

A learner who is fluent in lattices can read Prologos arguments at speed.

### Learning targets

By the end of this curriculum, a reader should be able to:

- Draw and compute in a lattice comfortably (meets, joins, Hasse diagrams, modular/distributive/complemented checks).
- State the modular law in both algebraic and order-theoretic forms and recognise it inside module-theoretic proofs.
- Compute a simple fixpoint by Kleene iteration, and identify when monotonicity alone (CALM) buys coordination-free parallelism.
- Construct a Galois connection $\alpha \dashv \gamma$ between a concrete and an abstract domain, and reason about soundness of the abstract fixpoint.
- Recognise when a computational structure is a quantale, a bilattice, or merely a semiring, and know what algebraic closure is missing in the last case.
- Translate between module-theoretic and lattice-theoretic statements fluently.
- Apply the SRE Lattice Lens to a new Prologos cell: VALUE vs STRUCTURAL, algebraic properties, Galois-connection bridges, primary vs derived, Hasse diagram.
- Explain to a non-lattice-literate colleague why lattices carry the structural weight of both classical module theory and the engineering design of Prologos — with diagrams.

> **Prologos Hook — Module 0.** The Design Mantra, on every keyboard in the project, is:
> *"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."*
> It is the operational form of the Hyperlattice Conjecture. We earn the right to say it in Module 16; until then, every theorem we learn is a deposit against that account. The mantra appears in `.claude/rules/on-network.md`, `.claude/rules/structural-thinking.md`, and `.claude/rules/workflow.md` — it is evaluated at every design decision.

\newpage

## Module 1 · Posets — The Order Beneath Everything

**Goal.** Handle partially ordered sets, Hasse diagrams, and sup/inf without friction.

### 1.1 Partial orders

**Definition.** A *partially ordered set* $(P, \leq)$ is a set $P$ with a relation $\leq$ that is:

- reflexive ($a \leq a$),
- antisymmetric ($a \leq b$ and $b \leq a$ imply $a = b$),
- transitive ($a \leq b \leq c$ implies $a \leq c$).

**Running examples.**

- $(\mathbb{N}, \mid)$ under divisibility.
- $(\mathcal{P}(X), \subseteq)$, the power-set lattice of any set $X$.
- $(\mathrm{Sub}(G), \subseteq)$, subgroups of a group $G$.
- $(\mathrm{L}(M), \subseteq)$, submodules of an $R$-module $M$. **Starring through Part IV.**
- $Q_n = (\{0,1\}^n, \leq)$, the Boolean hypercube — bitstrings ordered component-wise. **Starring in Part II.** This is the lattice the BSP scheduler forks over.
- The opens of a topological space under $\subseteq$.

### 1.2 Hasse diagrams

The *covering* relation $a \lessdot b$ means $a < b$ with nothing strictly between. A Hasse diagram draws a poset by its covering relation only — edges upward from $a$ to $b$ when $a \lessdot b$, with transitive edges omitted.

You will draw many Hasse diagrams. Get comfortable with:

- Chains (totally ordered; linear diagrams).
- Antichains (no nontrivial comparisons; disconnected dots).
- The diamond $B_2 = \mathcal{P}(\{a, b\})$.
- The cube $B_3 = Q_3 = \mathcal{P}(\{a, b, c\})$.
- The divisor lattice of a small integer like 12 or 30.
- The pentagon $N_5$ and the diamond $M_3$ (Module 3).

### 1.3 Upper and lower bounds

**Definition.** For $S \subseteq P$:

- $u$ is an *upper bound* of $S$ if $s \leq u$ for all $s \in S$.
- The *supremum* $\sup S$ (or *join* $\bigvee S$) is the least upper bound, if it exists.
- Dually, *infimum* $\inf S$ or *meet* $\bigwedge S$.

Not every poset admits all meets and joins. A poset where every finite non-empty subset has both a meet and a join is called a **lattice** — Module 2.

### 1.4 Exercises

1. Draw the Hasse diagram of $(\{1, 2, 3, 4, 6, 12\}, \mid)$.
2. Draw $\mathcal{P}(\{a, b, c\})$ and identify the chains of maximal length.
3. Give a finite poset with no join for some pair of elements. Draw it.
4. Show that in any poset, a supremum, if it exists, is unique.
5. Draw $Q_3 = \{0,1\}^3$ with component-wise order. Confirm it is isomorphic to $\mathcal{P}(\{a, b, c\})$.

> **Prologos Hook — Module 1.** The three posets to hold in your head from day one: $\mathrm{L}(M)$ (Part IV), $Q_n$ the worldview space (Part II), and the flat lattice $\{\bot < \text{flat elements} < \top\}$ underneath any "term" or "session type" cell (Part III). Each is a cell in the codebase: `L(M)` lives as the submodule-lattice pattern used by registries, `Q_n` is the per-propagator worldview bitmask in `propagator.rkt`, and the flat term lattice is `racket/prologos/term-lattice.rkt`.

\newpage

## Module 2 · Lattices — Meet and Join

**Goal.** Fluency with the two-ops view, the order view, and the passage between them.

### 2.1 The two definitions

**Order-theoretic.** A poset $(L, \leq)$ is a *lattice* if every pair $\{a, b\} \subseteq L$ has both a meet $a \wedge b = \inf\{a, b\}$ and a join $a \vee b = \sup\{a, b\}$.

**Algebraic.** A set $L$ with two binary operations $\wedge, \vee$ is a lattice if for all $a, b, c$:

- Commutativity: $a \wedge b = b \wedge a$, $a \vee b = b \vee a$.
- Associativity: $(a \wedge b) \wedge c = a \wedge (b \wedge c)$, similarly for $\vee$.
- Idempotence: $a \wedge a = a$, $a \vee a = a$.
- **Absorption**: $a \wedge (a \vee b) = a$, $a \vee (a \wedge b) = a$.

The two definitions agree via $a \leq b \iff a \wedge b = a \iff a \vee b = b$.

Absorption is the axiom that fixes the order: without it you have two disconnected semilattices (Part II).

### 2.2 Bounded and complete lattices

$L$ is *bounded* if it has $\top$ and $\bot$. $L$ is *complete* if *every* subset (not merely finite ones) has a meet and a join in $L$. Power-set lattices are complete; so are submodule lattices; so is $Q_n$ for any finite $n$.

**Theorem 2.1.** *The submodule lattice $\mathrm{L}(M)$ is complete, with $\bigwedge_i N_i = \bigcap_i N_i$ and $\bigvee_i N_i = \sum_i N_i$.*

*Proof sketch.* The intersection of any family of submodules is a submodule (closed under $R$-action and addition). The sum $\sum_i N_i$ is the smallest submodule containing each $N_i$, hence the join. $\square$

### 2.3 Canonical examples

| Lattice                          | Meet   | Join                       | $\bot$ / $\top$      |
|----------------------------------|--------|----------------------------|----------------------|
| $\mathcal{P}(X)$                 | $\cap$ | $\cup$                     | $\emptyset$ / $X$    |
| $\mathrm{Div}(n)$                | $\gcd$ | $\operatorname{lcm}$       | $1$ / $n$            |
| $\mathrm{Sub}(G)$                | $\cap$ | $\langle A \cup B \rangle$ | $\{e\}$ / $G$        |
| $\mathrm{L}(M)$                  | $\cap$ | $+$                        | $0$ / $M$            |
| Equivalence relations on $X$     | $\cap$ | smallest $\sim$ containing | identity / universal |
| $Q_n = \{0,1\}^n$                | AND    | OR                         | $0^n$ / $1^n$        |
| Flat lattice $\{\bot, a_1, \ldots, \top\}$ | same-or-$\bot$ | same-or-$\top$ | $\bot$ / $\top$ |

### 2.4 Exercises

1. Verify absorption in $\mathrm{Sub}(\mathbb{Z}/12\mathbb{Z})$ on two example pairs.
2. Show $\mathrm{Div}(30) \cong \mathcal{P}(\{2, 3, 5\})$ as lattices.
3. Prove: in any lattice, $a \leq b \iff a \wedge b = a$.
4. Give a poset that is a meet-semilattice but not a lattice.
5. Verify that the flat lattice $\{\bot, a, b, \top\}$ (with $a, b$ incomparable in the middle) is bounded, but not distributive. (Hint: you're drawing $M_2$ — a two-element "wide middle".)

> **Prologos Hook — Module 2.** Two concrete lattices in the Prologos codebase beyond $\mathrm{L}(M)$ anticipate later parts.
> (a) `racket/prologos/term-lattice.rkt` — a 4-element flat lattice $\{\bot, \mathrm{var}, \mathrm{ctor}(\ldots), \top\}$ with `var` and each constructor incomparable. Meet collapses distinct constructors to $\top$ (contradiction); join refines $\bot$ toward a constructor. This is the lattice inside every structural unification cell.
> (b) `racket/prologos/session-lattice.rkt` — session-type lattice with $\bot =$ "no commitment", $\top =$ "contradiction", and session-type constructors (send/receive/choice) in between. Its merge function `session-lattice-merge` is structural unification; its meet `session-lattice-meet` runs to $\top$ on incompatible sessions. We will see these again in Part II (as cells with monotone merge) and Part III (as inhabitants of a quantale-valued cell).

\newpage

## Module 3 · Special Lattice Classes

**Goal.** Recognise distributive, modular, and complemented lattices; know the forbidden-sublattice tests.

### 3.1 Distributive lattices

**Definition.** $L$ is *distributive* if for all $a, b, c$:

$$a \wedge (b \vee c) = (a \wedge b) \vee (a \wedge c).$$

By self-duality this implies the $\vee$-over-$\wedge$ version.

### 3.2 Modular lattices

**Definition.** $L$ is *modular* if for all $a, b, c$:

$$a \leq c \implies a \vee (b \wedge c) = (a \vee b) \wedge c.$$

Every distributive lattice is modular; the converse fails.

### 3.3 The forbidden sublattices

**Theorem 3.1 (Dedekind–Birkhoff).**

- $L$ is modular $\iff$ $L$ contains no sublattice isomorphic to $N_5$ (the pentagon).
- $L$ is distributive $\iff$ $L$ contains no sublattice isomorphic to $N_5$ or $M_3$ (the diamond).

**Shapes to memorise.**

- $M_3$: one top, one bottom, three pairwise-incomparable middle elements, each comparable with both top and bottom. Modular, not distributive.
- $N_5$: pentagon. Not modular.

### 3.4 The headline fact for modules

**Theorem 3.2.** *For any ring $R$ and $R$-module $M$, the lattice $\mathrm{L}(M)$ is modular.*

The proof is the modular law (Module 13).

Distributivity of $\mathrm{L}(M)$ is rare: it happens iff $M$ is a direct sum of pairwise non-isomorphic uniserial modules (for example, $\mathbb{Z}/p\mathbb{Z} \oplus \mathbb{Z}/q\mathbb{Z}$ with distinct primes). Most naturally occurring modules live in the "modular but not distributive" zone.

### 3.5 Complemented lattices

**Definition.** A bounded lattice $L$ is *complemented* if every $a$ has some $a'$ with $a \wedge a' = \bot$ and $a \vee a' = \top$.

In a distributive complemented lattice (a **Boolean algebra**), complements are unique. In a modular complemented lattice they need not be — which is exactly why direct-sum decompositions of modules need not be unique (and why Krull–Schmidt is a theorem, not a tautology).

### 3.6 Exercises

1. Draw $\mathrm{L}(\mathbb{Z}/6\mathbb{Z})$. Is it distributive?
2. Draw $\mathrm{L}((\mathbb{Z}/2\mathbb{Z})^2)$. Identify it as $M_3$.
3. Prove $M_3$ is modular by checking the definition.
4. Exhibit a non-modular lattice on 5 elements. (There is essentially only one.)
5. Prove: in a distributive lattice, every element has at most one complement.

> **Prologos Hook — Module 3.** Where Prologos lattices sit on this map:
> - The worldview lattice $Q_n$ (Module 8) is **Boolean** — distributive *and* complemented. This is why the BSP scheduler can prune subcubes for nogoods in $O(1)$: subcube-containment is a bitmask AND.
> - The session-type and term lattices (Module 2 hook) are **distributive but unbounded-complemented** (flat meets/joins over constructor generators).
> - $\mathrm{L}(M)$ and the submodule-of-lattice structure used in the compiler's self-hosted registries (Module 15) are **modular but not distributive**. This is why the elaborator must track per-branch assumptions with bitmask tags, not just set-membership: modular-only means tag collapse on bridges is a real failure mode (see `.claude/rules/structural-thinking.md` § "Direct Sum Has Two Realizations").

\newpage

## Module 4 · Morphisms, Congruences, Galois Connections

**Goal.** The morphisms of the category of lattices, plus the duality-manufacturing tool. This module is shallow on purpose — it sets the vocabulary used throughout Parts II, III, and IV. Module 7 develops Galois connections in depth for abstract interpretation.

### 4.1 Lattice homomorphisms

**Definition.** $f: L \to L'$ is a *lattice homomorphism* if $f(a \wedge b) = f(a) \wedge f(b)$ and $f(a \vee b) = f(a) \vee f(b)$.

An order-preserving (monotone) map need not be a lattice homomorphism. For example, $\mathrm{Sub}(G) \hookrightarrow \mathcal{P}(G)$ preserves $\cap$ but not $\vee$ (the join in $\mathrm{Sub}(G)$ is $\langle A \cup B \rangle$, not $A \cup B$).

### 4.2 Congruences and quotients

A *congruence* on $L$ is an equivalence relation compatible with $\wedge$ and $\vee$. $L/\theta$ is then a lattice; isomorphism theorems follow. In modular lattices the congruence lattice has especially clean structure — the abstract home of the module-theoretic isomorphism theorems.

### 4.3 Galois connections (preview)

**Definition.** A pair of monotone maps $f : P \to Q$, $g : Q \to P$ between posets is a *Galois connection* if

$$f(p) \leq q \iff p \leq g(q) \quad\text{for all } p \in P,\, q \in Q.$$

Every Galois connection manufactures a closure operator on each side and an induced lattice isomorphism between the "closed" elements on each side. Classical examples:

- Galois theory proper: subgroups of $\mathrm{Gal}(E/F)$ ↔ intermediate fields.
- Annihilator pairs: submodules of $M$ ↔ submodules of the dual $M^*$ for finite-dimensional $M$.
- Formal concept analysis: objects ↔ attributes.
- Abstract interpretation: abstract states $\alpha \dashv \gamma$ concrete states (Module 7).

### 4.4 Exercises

1. Show $\mathrm{Sub}(G) \hookrightarrow \mathcal{P}(G)$ preserves meets but not joins.
2. Define a Galois connection between subsets of $\mathbb{R}^n$ and subsets of $(\mathbb{R}^n)^*$ via "vanishing" and "zero set". Identify the closed elements.
3. Given any relation $R \subseteq X \times Y$, build its Galois connection between $\mathcal{P}(X)$ and $\mathcal{P}(Y)$.

> **Prologos Hook — Module 4.** Every "bridge" between Prologos cells is, at bottom, a Galois connection — and that is not a metaphor. The SRE Lattice Lens (Module 17) requires each bridge between cells to be a Galois connection: if you can't produce the pair $(f, g)$ with $f(x) \leq y \iff x \leq g(y)$, the bridge is not well-typed. Example: the projection from decision cells to the worldview cache IS a left adjoint (joins of committed bits) and the cache IS its right adjoint (the set of worldviews compatible with a commitment). We return to this in Module 7 with the full abstract-interpretation infrastructure.

\newpage

# Part II — Lattices for Computation

## Module 5 · Semilattices, Monotonicity, and the CALM Theorem

**Goal.** Meet the engineering payoff: every monotone computation on a join-semilattice is coordination-free.

### 5.1 Join-semilattices

A **join-semilattice** is a poset in which every pair has a join $\vee$. One-sided completeness is enough for distributed computation: cells accumulate information, never retract, and their merge is a join.

Propagator networks are built on join-semilattices. Every cell holds a value in some join-semilattice $L$; every propagator is a monotone map from input cells to output cells; when two writes arrive at the same cell, the merge is $\vee$. If the merge is a join (monotone in each argument, idempotent, associative, commutative) the cell's value grows along a chain — information can only refine or remain, never retract.

### 5.2 Monotone functions

$f : L \to L'$ is **monotone** if $a \leq b$ implies $f(a) \leq f(b)$. In a propagator network, a monotone propagator's output can only grow as its inputs grow. Composition of monotones is monotone.

### 5.3 The CALM theorem

**Theorem 5.1 (Consistency As Logical Monotonicity, Hellerstein 2010; Ameloot–Neven–Van den Bussche 2013).** *A distributed computation is computable without coordination if and only if it is expressible as a monotone function on a join-semilattice.*

The theorem is a two-way bridge. The "only if" direction says: if you want your distributed system to run without global coordination (no locks, no consensus, no barriers), your computation had better be monotone on a semilattice. The "if" direction says: if it *is* monotone on a semilattice, the lack of coordination is correct — you can run propagators in any order, on any partition of cells, and the fixpoint is the same.

### 5.4 What this buys a propagator network

If every cell holds a semilattice value and every propagator is monotone, the BSP scheduler can fire propagators in any order, across any partition, and the fixpoint is the same. That is the engineering payoff of insisting every cell's merge be monotone — it buys unconditional parallelism. When a non-monotone step is forced (negation-as-failure, retraction), it gets quarantined at a stratum boundary (Module 6, and Module 18's stratification tour).

### 5.5 Exercises

1. Show: the power-set lattice $\mathcal{P}(X)$ with $\cup$ as join is a join-semilattice. Give a monotone function $f: \mathcal{P}(X) \to \mathcal{P}(X)$ that is not a lattice homomorphism.
2. Show: the function "reached nodes from source $s$ in graph $G$" is monotone on the lattice $\mathcal{P}(V)$ where $V$ is the vertex set.
3. Show: negation $\neg : \mathcal{P}(X) \to \mathcal{P}(X)$, $S \mapsto X \setminus S$, is *antitone* (order-reversing), not monotone. Explain why negation-as-failure cannot be a plain propagator.
4. Give a non-monotone merge that still satisfies commutativity and associativity. Explain why it breaks the CALM guarantee.

> **Prologos Hook — Module 5.** The Design Mantra in `.claude/rules/on-network.md` is the CALM theorem in operational form. "All in parallel" is CALM's "no coordination." "Structurally emergent information flow ON-NETWORK" is CALM's "monotone function on a join-semilattice." Every cell in Prologos ships with a `register-merge-fn!/lattice` call declaring its merge; the linter audits that all merges are monotone joins. Non-monotone work — retraction of assumptions, negation-as-failure — is explicitly quarantined at strata $S_{-1}$ and $S_1$ (`.claude/rules/stratification.md`), outside the CALM-safe zone $S_0$.

\newpage

## Module 6 · Fixpoints — Tarski, Gauss–Seidel, Well-Founded

**Goal.** Compute fixpoints of monotone maps; understand when Kleene iteration terminates; meet stratified fixpoints and well-founded semantics.

### 6.1 The Knaster–Tarski fixpoint theorem

**Theorem 6.1 (Knaster–Tarski).** *A monotone function $f : L \to L$ on a complete lattice has a least fixpoint $\mu f = \bigwedge \{x : f(x) \leq x\}$ and a greatest fixpoint $\nu f = \bigvee \{x : x \leq f(x)\}$.*

Least fixpoints correspond to inductive definitions: "the smallest set closed under the rules." Greatest fixpoints correspond to coinductive definitions: "the largest set consistent with the rules."

### 6.2 Kleene iteration

If $f$ is *$\omega$-continuous* (it preserves suprema of ascending chains), then $\mu f = \bigvee_{n \geq 0} f^n(\bot)$. This is the computational recipe: start at $\bot$, iterate $f$, join. For finite lattices every monotone map is trivially $\omega$-continuous and iteration terminates.

### 6.3 Gauss–Seidel fixpoints: stratification

When the lattice is a *product* $L_1 \times L_2 \times \cdots \times L_k$ and the dependencies between strata form a DAG (non-monotone operations flow downhill only), the fixpoint can be computed stratum by stratum: quiesce $L_1$, then $L_2$ using $L_1$'s final value, and so on. Each stratum is a Tarski fixpoint; the outer loop is Gauss–Seidel.

This is how Prologos runs. $S_0$ is the monotone value stratum (CALM-safe). $S_1$ handles negation-as-failure. $L_1$ is a readiness scan, $L_2$ is an action interpreter for non-monotone moves like trait instance commitment. Each stratum is ordered above its dependencies by the scheduler's outer loop.

### 6.4 Well-founded semantics

For programs with negation-as-failure, the well-founded semantics assigns each atom a truth value in $\{\mathtt{true}, \mathtt{false}, \mathtt{unknown}\}$ via a three-valued fixpoint on a *bilattice* (Module 10). The lower cell accumulates evidence FOR; the upper cell eliminates evidence AGAINST. The gap between them is the "unknown" region.

### 6.5 Worked example — Kleene iteration

Let $f : \mathcal{P}(\{1,2,3\}) \to \mathcal{P}(\{1,2,3\})$ be defined by $f(S) = \{1\} \cup \{k+1 : k \in S, k+1 \leq 3\}$. Then:

$$f^0(\emptyset) = \emptyset, \quad f^1(\emptyset) = \{1\}, \quad f^2(\emptyset) = \{1,2\}, \quad f^3(\emptyset) = \{1,2,3\}, \quad f^4(\emptyset) = \{1,2,3\}.$$

Fixpoint at $\{1,2,3\}$, reached in three steps. That is "reachable from seed 1 under the successor relation, bounded by 3."

### 6.6 Exercises

1. Compute the least fixpoint of $f(S) = \{0\} \cup \{n+2 : n \in S, n+2 \leq 10\}$ on $\mathcal{P}(\{0,1,\ldots,10\})$ by Kleene iteration.
2. Show that the greatest fixpoint of $g(S) = \{n \in \mathbb{N} : n+1 \in S\}$ on $\mathcal{P}(\mathbb{N})$ is $\mathbb{N}$ and the least is $\emptyset$. What do these correspond to operationally?
3. Give a monotone function on an infinite chain that is not $\omega$-continuous and whose least fixpoint is reached only at ordinal $\omega$ (or later).
4. Describe the Gauss–Seidel step-order to evaluate `p :- q, not r. q :- true. r :- false.` — identify the strata.

> **Prologos Hook — Module 6.** The file `.claude/rules/stratification.md` is Module 6 in compiled form. Prologos runs **five+ concrete strata** on one propagator network: $S_0$ (monotone value), $S_{-1}$ (non-monotone retraction — `run-retraction-stratum!` in `metavar-store.rkt`), $S_1$ NAF (negation-as-failure with fork+quiesce, via `register-stratum-handler!` in `relations.rkt`), $L_1$/$L_2$ (readiness scan → action interpreter), and Topology (mid-round structural mutation via `register-topology-handler!`). Each stratum accumulates requests in a dedicated cell with `hash-union` merge; the BSP outer loop runs the handler after lower strata quiesce. The well-founded bilattice is implemented in `racket/prologos/bilattice.rkt` — lower cell rises via join, upper cell falls via meet, the gap is the "unknown" witness. See `GÖDEL_COMPLETENESS.org` Table at §286 for termination proofs per stratum.

\newpage

## Module 7 · Galois Connections and Abstract Interpretation

**Goal.** Extend Module 4's preview into the working tool: sound program abstraction via $(\alpha, \gamma)$ pairs, and the soundness theorem that abstract fixpoints over-approximate concrete ones.

### 7.1 Galois connections, re-stated

Given posets $(C, \leq)$ and $(A, \sqsubseteq)$ with monotone maps $\alpha : C \to A$ and $\gamma : A \to C$, the pair is a **Galois connection** if $\alpha(c) \sqsubseteq a \iff c \leq \gamma(a)$. Equivalently, $\alpha$ is left adjoint to $\gamma$ ($\alpha \dashv \gamma$). Consequences, all automatic:

- $\alpha$ preserves arbitrary joins (left adjoints preserve colimits).
- $\gamma$ preserves arbitrary meets (right adjoints preserve limits).
- $\gamma \circ \alpha$ is a *closure operator* on $C$ (inflationary, monotone, idempotent).
- $\alpha \circ \gamma$ is a *kernel operator* on $A$ (deflationary, monotone, idempotent).
- The fixed points of $\gamma \circ \alpha$ on $C$ are lattice-isomorphic to the fixed points of $\alpha \circ \gamma$ on $A$.

### 7.2 Abstract interpretation (Cousot–Cousot 1977)

Let $C$ be a "concrete" semantic domain (states, sets of states, traces). Let $A$ be an "abstract" domain (intervals, signs, types). Let $F : C \to C$ be the concrete program semantics (next-state, or reach). A **sound abstraction** is a Galois connection $(\alpha, \gamma)$ together with an abstract semantics $F^\sharp : A \to A$ such that $\alpha \circ F \sqsubseteq F^\sharp \circ \alpha$ — one step in the abstract over-approximates one step in the concrete.

**Theorem 7.1 (Soundness of abstract fixpoints).** *If $(\alpha, \gamma, F, F^\sharp)$ is a sound abstraction, then $\mu F^\sharp$ (the least fixpoint of $F^\sharp$ in $A$) over-approximates $\alpha(\mu F)$.* That is, $\alpha(\mu F) \sqsubseteq \mu F^\sharp$, so $\mu F \leq \gamma(\mu F^\sharp)$.

The engineering payoff: running the abstract fixpoint is cheap and gives a sound over-approximation of the concrete fixpoint. Type inference, shape analysis, escape analysis, interval analysis are all instances.

### 7.3 The interval domain

Concrete: $\mathcal{P}(\mathbb{Z})$ with $\subseteq$. Abstract: intervals $[a, b] \cup \{\top, \bot\}$ under inclusion of contained integers. $\alpha(S) = [\min S, \max S]$ if $S$ nonempty, else $\bot$. $\gamma([a, b]) = \{a, a+1, \ldots, b\}$. Addition lifts to intervals as $[a,b] +^\sharp [c,d] = [a+c, b+d]$; this is sound. Multiplication is subtler (sign considerations) but also sound when carefully defined.

### 7.4 Exercises

1. Verify that $(\alpha, \gamma)$ for the interval domain is a Galois connection.
2. Show that the sign domain $\{\bot, -, 0, +, \top\}$ admits a Galois connection with $\mathcal{P}(\mathbb{Z})$. Define $\alpha, \gamma$ and verify soundness of $+^\sharp$.
3. Compose two Galois connections $(\alpha_1 \dashv \gamma_1 : C \to A)$ and $(\alpha_2 \dashv \gamma_2 : A \to B)$ to produce one $(\alpha_2 \circ \alpha_1 \dashv \gamma_1 \circ \gamma_2 : C \to B)$. Verify the adjoint law.
4. Prove: in any Galois connection, $\alpha(\bot_C) = \bot_A$ and $\gamma(\top_A) = \top_C$.

> **Prologos Hook — Module 7.** The SRE Lattice Lens (Q3) is a Galois-connection discipline. From `.claude/rules/structural-thinking.md`: "Every bridge between lattices is a Galois connection (left adjoint preserves joins). If you can't produce the pair, the bridge is not well-typed." Concrete bridges in Prologos:
> (a) **decision cells → worldview cache**: left adjoint $\alpha$ is OR of committed bits; right adjoint $\gamma$ is "set of worldviews compatible with a commitment."
> (b) **table cell → consumer query**: $\alpha$ filters by ground arguments and projects free ones; $\gamma$ expands a query pattern to the set of matching entries.
> (c) **scope cell → table entry**: identity adjunction (scope IS the answer for a ground query).
> The abstract interpretation infrastructure is realised in `racket/prologos/interval-domain.rkt` — an interval cell with the meet = intersection merge function, plus constraint propagators for $x+y=z$, $x-y=z$, $x*y=z$. Module 17 runs the full six-question lens; this module gives the definition it runs on.

\newpage

## Module 8 · Heyting, Boolean, Hypercube — The $Q_n$ Lattice

**Goal.** Meet the three most important special lattices for programming-languages work, and see why the Boolean hypercube $Q_n$ is the lattice Prologos's BSP scheduler computes on.

### 8.1 Heyting algebras

A **Heyting algebra** is a bounded lattice $H$ with a binary operation $\to$ (implication / relative pseudocomplement) satisfying the adjunction

$$a \wedge b \leq c \iff a \leq b \to c.$$

In other words, $\wedge$ is residuated by $\to$. Heyting algebras are the algebraic models of intuitionistic propositional logic. Every Heyting algebra is distributive. Every finite distributive lattice is a Heyting algebra (the adjoint of $\wedge b$ always exists by Knaster–Tarski).

### 8.2 Boolean lattices

A **Boolean lattice** is a complemented distributive lattice. Equivalently: a Heyting algebra in which $\neg \neg a = a$ for all $a$, where $\neg a = a \to \bot$. Boolean algebras model classical propositional logic. The canonical example is $\mathcal{P}(X)$ with $\wedge = \cap, \vee = \cup, \neg = $ complement.

### 8.3 The hypercube $Q_n$

$Q_n = (\{0,1\}^n, \leq)$ where $\leq$ is component-wise. Meet is bitwise AND, join is bitwise OR, complement is bitwise NOT. As a lattice, $Q_n \cong \mathcal{P}(\{1, 2, \ldots, n\})$. Its Hasse diagram is the $n$-dimensional hypercube graph: vertices at distance 1 differ in exactly one bit (Hamming distance).

**Structural properties of $Q_n$ that matter for Prologos.**

- **Boolean** (distributive and complemented). Subcube containment is bitmask AND in $O(1)$.
- **Hasse diameter** is $n$. A longest chain traverses exactly $n$ covers.
- **Gray code traversal**: a Hamiltonian path on the hypercube graph visiting every vertex by flipping exactly one bit per step. Optimal for CHAMP (persistent hash-map) sharing — consecutive worldviews share all but one cell.
- **Subcube pruning**: a nogood — a forbidden partial assignment — identifies a subcube (all worldviews extending the forbidden prefix). Containment is $O(1)$ bitmask AND.
- **Hypercube all-reduce**: optimal BSP barrier on $n$ dimensions in $\log_2 N$ rounds.

### 8.4 $Q_n$ is the Prologos worldview lattice

Each worldview in the BSP scheduler is an element of $Q_n$ where $n$ is the number of active speculative assumptions. The per-propagator worldview bitmask is that propagator's pointer into $Q_n$. Nogoods are subcube exclusions. Speculation is movement along a path in the Hasse diagram. The hypercube structure is **not a convenience choice** for storing worldviews; by the Hyperlattice Conjecture (Module 16), it is the optimal parallel decomposition of the worldview-exploration computation.

### 8.5 Exercises

1. Compute a Gray code traversal of $Q_3$. Verify each step is a single-bit flip.
2. Given a nogood $\{x_1 = 1, x_3 = 0\}$ over $n = 4$ bits, identify the excluded subcube as a pair (mask, pattern) and check subcube-containment of $1011$ and $0100$ via bitmask AND.
3. Show that $Q_n$'s complementation coincides with the intuitive set-complement when $Q_n \cong \mathcal{P}(\{1,\ldots,n\})$.
4. Prove: the Hasse diameter of $Q_n$ is $n$ (by counting cover-edges on a maximal chain).

> **Prologos Hook — Module 8.** $Q_n$ **IS** the Prologos worldview. From `.claude/rules/structural-thinking.md`: "The ATMS worldview space IS the Boolean lattice $Q_n$, whose Hasse diagram IS the hypercube graph." The per-propagator worldview bitmask described in `.claude/rules/propagator-design.md` § "Per-Propagator Worldview" is each propagator's pointer into $Q_n$. Nogoods are subcube exclusions checked in $O(1)$. Speculation is movement along a Hamiltonian path. This module is the math; Module 16 is the conjecture that says this math IS the computation.

\newpage

# Part III — Quantales & Annotation Algebras

## Module 9 · Semirings → Quantales

**Goal.** See where semirings break as program-annotation algebras, and meet quantales as the completion that fixes them.

### 9.1 Semirings — the annotation workhorse

A **semiring** $(S, \oplus, \otimes, 0, 1)$ is a set with two associative operations: $\oplus$ (additive) commutative with identity $0$, and $\otimes$ (multiplicative) with identity $1$, distributing over $\oplus$. No requirement of negatives or inverses. Examples: $(\mathbb{N}, +, \times, 0, 1)$, the Boolean semiring $(\{0,1\}, \vee, \wedge, 0, 1)$, the tropical semiring $(\mathbb{R} \cup \{\infty\}, \min, +, \infty, 0)$, provenance semirings (Green–Karvounarakis–Tannen 2007).

Semirings are the standard algebra for program annotations: QTT multiplicities (how many times is $x$ used?), provenance (which facts contributed?), weights (what's the cost?).

### 9.2 Four gaps of the semiring framework

Four structural limitations of semirings block them as annotation algebras for propagator-network languages. From the April 13, 2026 research brief `research/quantale research/outputs/quantale-propagator-annotations.md`:

**Gap 1: idempotency.** $\oplus$ idempotent ($a \oplus a = a$) says "two identical proofs = one proof." Standard semirings do not require this. Without idempotency, merging two cell writes is ambiguous.

**Gap 2: contradiction element.** A semiring has an identity $0$ and a unit $1$ but no distinguished "top" representing contradiction. Propagator networks need $\top$ (two incompatible annotations arriving at the same cell $\Rightarrow$ $\top$), which a semiring cannot provide without extension.

**Gap 3: completeness.** Cells hold arbitrary (possibly infinite) merges. A semiring supports finite $\oplus$; it does not guarantee arbitrary joins exist.

**Gap 4: induced order.** A semiring has no intrinsic order. Monotone propagators need one. You have to bolt order on externally (e.g., "$a \leq b$ iff $\exists c. a \oplus c = b$") and the bolt-on may not be a lattice order.

### 9.3 Quantales — semirings made lattices

**Definition.** A **quantale** is a complete sup-lattice $(Q, \bigvee)$ equipped with an associative tensor product $\otimes : Q \times Q \to Q$ that distributes over arbitrary joins on both sides: $a \otimes \bigvee_i b_i = \bigvee_i (a \otimes b_i)$ and $(\bigvee_i a_i) \otimes b = \bigvee_i (a_i \otimes b)$. A **unital** quantale has a unit $1$ for $\otimes$. A **commutative** quantale has $a \otimes b = b \otimes a$.

A quantale closes every gap:

1. **Idempotency**: the lattice join $\vee$ *is* idempotent by lattice axioms.
2. **Contradiction**: the lattice has $\top = \bigvee Q$, the absorbing element for any merge with an incompatible argument.
3. **Completeness**: quantales are complete sup-lattices by definition.
4. **Induced order**: the lattice order IS the semantic order; monotonicity is built in.

And there is a bonus:

**Theorem 9.1 (Residuation, adjoint-functor theorem).** *In any quantale $(Q, \otimes)$, the map $a \otimes (-) : Q \to Q$ preserves arbitrary joins, hence has a right adjoint $a \backslash (-)$. Dually $(-) \otimes b$ has a right adjoint $(-) / b$.* The residuations $a \backslash b$ and $b / a$ satisfy

$$a \otimes x \leq b \iff x \leq a \backslash b, \qquad x \otimes a \leq b \iff x \leq b / a.$$

In a non-commutative quantale, left and right residuations differ — and this is the feature, not a bug: ordered resources (send then receive on a session) require non-commutative tensor.

### 9.4 The zero-sum hypothesis

From the April 2026 research brief: Prologos's QTT multiplicities, session types, and future weighted/probabilistic annotations all appear to factor through a common **non-commutative unital quantale** acting on cells. The hypothesis is that one quantale — not a semiring, not a semi-quantale, not a lattice-ordered monoid — unifies the annotation layer. The open research question is whether the hypothesis holds at full generality or whether session types and QTT need distinct quantales that compose externally.

### 9.5 Exercises

1. Verify that $(\mathcal{P}(X), \cup, \cap)$ (where tensor is intersection) is a commutative unital quantale. Identify the unit.
2. Show that the Boolean semiring $(\{0, 1\}, \vee, \wedge)$ is a commutative unital quantale (degenerate case).
3. Show that the tropical semiring $(\mathbb{R} \cup \{\infty\}, \min, +)$ is a quantale (with $\min$ as join; identify the tensor and unit).
4. Give an example of a non-commutative quantale. (Hint: languages over an alphabet with concatenation as tensor and union as join.)
5. Compute the left residuation $a \backslash b$ for the power-set quantale.

> **Prologos Hook — Module 9.** This module distils the April 13, 2026 research brief `research/quantale research/outputs/quantale-propagator-annotations.md`. Findings: quantales are the natural annotation algebra for propagator-network languages, closing all four semiring gaps simultaneously. The conjecture (still open at the time of this writing) is that QTT multiplicities, session types, and potential future weighted/probabilistic annotations all factor through a common non-commutative unital quantale acting on cells. The non-commutativity matters: ordered resources (send-then-receive on a session) cannot be modelled by a commutative semiring. See Module 10 for residuation and bilattices; see Module 18 for where this lands in the codebase.

\newpage

## Module 10 · Residuated Lattices, Bilattices, QTT Annotations

**Goal.** Three lattice structures that live *between* quantales and the specific algebra of a programming language's type system: residuated lattices, bilattices, and QTT's multiplicity lattice.

### 10.1 Residuated lattices

A **residuated lattice** is a lattice $(L, \wedge, \vee)$ with an associative binary operation $\otimes$ that has right and left residuations $\backslash$ and $/$ satisfying the Galois adjunctions

$$a \otimes x \leq b \iff x \leq a \backslash b, \qquad x \otimes a \leq b \iff x \leq b / a.$$

Every quantale is a residuated complete lattice (Module 9). The converse fails: residuated lattices need not be complete.

Residuated lattices are the right home for many substructural logics (linear logic, relevance logic, BCK-logic). They also give us the algebraic form of the "$\otimes$ and $-\!\!\circ$" pair in linear type theory.

### 10.2 Bilattices — Fitting's double order

A **bilattice** is a set with *two* lattice orders: a **truth order** $\leq_t$ with $\wedge_t, \vee_t$, and an **information order** $\leq_i$ with $\wedge_i, \vee_i$. The canonical example is **FOUR** $= \{\mathtt{false}, \mathtt{unknown}, \mathtt{true}, \mathtt{contradict}\}$ where

- truth: $\mathtt{false} \leq_t \mathtt{unknown}, \mathtt{contradict} \leq_t \mathtt{true}$,
- information: $\mathtt{unknown} \leq_i \mathtt{false}, \mathtt{true} \leq_i \mathtt{contradict}$.

Bilattices are the algebraic setting for *three-valued* and *four-valued* logics — and they are the setting in which well-founded semantics becomes a fixpoint computation. In Prologos's `bilattice.rkt`, each bilattice-variable is a pair $(ell, ell^\#)$ of cells: $ell$ ascends under the truth order (evidence FOR), $ell^\#$ descends under the truth order (lack of evidence AGAINST). The meet in the information order is the "unknown" witness: when $ell < ell^\#$, the atom is currently unknown.

### 10.3 QTT multiplicities as a lattice

Quantitative Type Theory (Atkey 2018) tags each binder with a **multiplicity** $\{0, 1, \omega\}$ from a semiring where $0$ = "erased", $1$ = "used exactly once", $\omega$ = "used without restriction". The semiring is a standard QTT multiplicity semiring.

Prologos lifts this semiring to a lattice by adding $\bot$ and $\top$: $\{\bot, 0, 1, \omega, \top\}$ with $\bot \leq 0, 1, \omega \leq \top$ and $0, 1, \omega$ pairwise incomparable in the middle. This is a flat lattice on the multiplicity generators. The merge of $0$ and $1$ is $\top$ (contradiction — a binder cannot be both erased and used). The merge of $1$ and $1$ is $1$ (idempotent join). The merge of $1$ and $\omega$ is $\omega$ (use-at-most-once plus use-without-restriction = use-without-restriction).

The move from semiring to lattice is exactly the completion Module 9 described: the lattice view adds the partial order and contradiction element the semiring lacks, making the multiplicity a cell value with a monotone merge.

### 10.4 Exercises

1. Check that FOUR is a bilattice by verifying the Hasse diagrams for $\leq_t$ and $\leq_i$. Draw the combined "doubled" diagram.
2. Compute $a \wedge_t b$ for each pair of FOUR's elements. Do the same for $\wedge_i, \vee_t, \vee_i$.
3. Show: if $(L, \wedge, \vee, \otimes, 1)$ is a commutative residuated lattice, then $\otimes$ distributes over $\vee$ on both sides. (This is a piece of the quantale story.)
4. Verify that Prologos's multiplicity lattice $\{\bot, 0, 1, \omega, \top\}$ is modular but not distributive. (Hint: is there an $M_3$ inside?)
5. Describe, informally, how a bilattice-variable in `bilattice.rkt` computes the three-valued fixpoint for `p :- not q. q :- not p.` (odd cycle). Where does "unknown" arise?

> **Prologos Hook — Module 10.** Three concrete Prologos cells realise this module:
> (a) `racket/prologos/mult-lattice.rkt` — the QTT multiplicity lattice, flat, $\bot$ to $\top$ through $\{0, 1, \omega\}$. Its merge function `mult-lattice-merge` and predicate `mult-lattice-contradicts?` detect the collision $0 \sqcup 1 = \top$.
> (b) `racket/prologos/bilattice.rkt` — the bilattice-variable infrastructure (pairs of ascending lower + descending upper cells per variable), the engine for well-founded semantics. `bool-lattice` is the degenerate case $\{\bot, \mathtt{false}, \mathtt{true}, \top\}$.
> (c) `racket/prologos/qtt.rkt` — uses `mult-lattice` as the merge for `mult-meta` cells (registered via `register-merge-fn!/lattice`), binding Module 10 content to the type checker's `inferQ` and `checkQ` functions.
> The open research (from the April 13, 2026 quantale brief) is whether these three lattices can be unified under a single quantale-valued cell type.

\newpage

# Part IV — Module Theory: Classical and Prologos-Sense

## Module 11 · Modules Over Rings — A Working Refresher

**Goal.** Establish the module-theoretic background so Modules 12–15 feel like review with a new lens.

### 11.1 Definition and examples

**Definition.** Let $R$ be an associative ring with identity. A *left $R$-module* is an abelian group $(M, +)$ together with a map $R \times M \to M$, $(r, m) \mapsto rm$, satisfying:

- $1 m = m$,
- $r(m + n) = rm + rn$,
- $(r + s) m = rm + sm$,
- $(rs) m = r(sm)$.

**Core examples.**

- $R = \mathbb{Z}$: $\mathbb{Z}$-modules *are* abelian groups.
- $R = k$ a field: $k$-modules are $k$-vector spaces.
- $R = R$: the regular module. Its submodules are the left ideals of $R$.
- $R = k[x]$: a $k[x]$-module is a $k$-vector space together with a choice of endomorphism $T$, via $x \cdot v = T v$.
- $R$ the group algebra of a group $G$: $R$-modules are representations of $G$.

### 11.2 Submodules, quotients, homomorphisms

A submodule $N \leq M$ is an additive subgroup closed under the $R$-action. The quotient $M/N$ is an $R$-module. An $R$-homomorphism $f: M \to M'$ satisfies $f(rm + sn) = r f(m) + s f(n)$.

### 11.3 Isomorphism theorems

**Theorem 11.1 (Three iso theorems).**

1. $M/\ker f \cong \operatorname{im}(f)$.
2. For $N, P \leq M$: $(N + P)/P \cong N/(N \cap P)$.
3. For $P \leq N \leq M$: $(M/P)/(N/P) \cong M/N$.

Each is the module-flavoured trace of a *lattice* isomorphism inside $\mathrm{L}(M)$. The second one *is* the modular law — see Module 13. The third is the correspondence theorem (Module 12).

### 11.4 Exercises

1. List submodules of $\mathbb{Z}/12\mathbb{Z}$ and draw the Hasse diagram.
2. For $M = k^2$ as a $k[x]$-module with $x$ acting as $\begin{pmatrix}0 & 1 \\ 0 & 0\end{pmatrix}$: list all submodules and draw $\mathrm{L}(M)$.
3. Give a module whose submodule lattice is a chain of length 3. Give one where the lattice is an antichain above the trivial submodule.

\newpage

## Module 12 · The Submodule Lattice $\mathrm{L}(M)$

**Goal.** Read module properties directly from lattice shape.

### 12.1 Definition and basic structure

$\mathrm{L}(M)$ is the poset of submodules of $M$ under inclusion, with $N \wedge P = N \cap P$, $N \vee P = N + P$, $\bot = 0$, $\top = M$. It is complete (Theorem 2.1) and modular (Theorem 3.2).

### 12.2 The correspondence theorem

**Theorem 12.1.** *For any submodule $N \leq M$, the interval $[N, M]$ in $\mathrm{L}(M)$ is lattice-isomorphic to $\mathrm{L}(M/N)$ via $P \mapsto P/N$.*

This is the fundamental "zoom" tool: to study submodules above $N$, study $M/N$; to study submodules inside $N$, study $N$.

### 12.3 The translation table

| Module-theoretic property of $M$ | Lattice-theoretic property of $\mathrm{L}(M)$ |
|----------------------------------|-----------------------------------------------|
| Simple                           | Two-element lattice                           |
| Uniserial                        | Chain                                         |
| Semisimple                       | Complemented (and modular, automatically)     |
| Finite length                    | Finite height                                 |
| Noetherian                       | ACC                                           |
| Artinian                         | DCC                                           |
| Indecomposable                   | Only $\{0, M\}$ are mutual complements        |
| Cyclic                           | Single join-irreducible generator             |

### 12.4 Exercises

1. Draw $\mathrm{L}(\mathbb{Z}/p^3\mathbb{Z})$. Identify it as a specific small lattice.
2. For $M = \mathbb{Z}/p\mathbb{Z} \oplus \mathbb{Z}/p\mathbb{Z}$: draw $\mathrm{L}(M)$, identify it as $M_3$ (plus top and bottom already present).
3. Sketch $\mathrm{L}(\mathbb{Z})$ as a $\mathbb{Z}$-module. (It is infinite but well-organised.)

> **Prologos Hook — Module 12.** The self-hosted compiler's registries form a "module of lattices" in Prologos's sense. Each registry (module registry, relation registry, trait dispatch table) is a cell whose value is a lattice; the collection of all registries forms the product lattice, and bridges between them are Galois connections. The "correspondence theorem" for this Prologos module is: the interval in the product lattice above a fixed module's cell state is isomorphic to the product lattice of *only the cells that module affects*. This lets the self-hosted compiler reason about incremental compilation by intervals — exactly the Module 12 pattern, applied one meta-level up. Module 15 formalises this.

\newpage

## Module 13 · The Modular Law — The Translation Key

**Goal.** Master the one identity that makes the whole classical enterprise run.

### 13.1 Statement and proof

**Theorem 13.1 (Modular law for modules).** *Let $M$ be an $R$-module and let $A, B, C \leq M$ with $A \leq C$. Then*

$$A + (B \cap C) = (A + B) \cap C.$$

*Proof.*

($\subseteq$) $A \leq C$ and $B \cap C \leq C$ give $A + (B \cap C) \leq C$. Also $A \leq A + B$ and $B \cap C \leq A + B$, so $A + (B \cap C) \leq A + B$. Together, $A + (B \cap C) \leq (A + B) \cap C$.

($\supseteq$) Take $x \in (A + B) \cap C$. Write $x = a + b$ with $a \in A, b \in B$. Since $x \in C$ and $a \in A \leq C$, we get $b = x - a \in C$, so $b \in B \cap C$. Therefore $x = a + b \in A + (B \cap C)$. $\square$

### 13.2 The meaning

You can "distribute" a sum over an intersection *when one summand is already inside the enveloping term*. That is exactly the reason submodules slide past each other cleanly, like subspaces of a vector space. The failure mode — non-modularity — only shows up when you try to do this move without the hypothesis $A \leq C$; and in subgroup lattices of non-abelian groups the non-modularity is visible as a sublattice $N_5$.

### 13.3 What it buys

**Corollary (Diamond / Second Iso Theorem).** $(N + P)/N \cong P/(N \cap P)$.

**Corollary (Length additivity).** For finite-length modules, $\ell(N + P) + \ell(N \cap P) = \ell(N) + \ell(P)$.

**Corollary (Jordan–Hölder).** Composition series exist in the finite-length case and any two have the same length and the same multiset of simple factors. The proof is a lattice-theoretic refinement argument (Schreier) that uses modularity essentially.

### 13.4 Exercises

1. Derive the second isomorphism theorem from the modular law.
2. Find submodules $A, B, C$ of $\mathbb{Z}^2$ with $A \not\leq C$ such that $A + (B \cap C) \neq (A + B) \cap C$.
3. Explain why $\mathrm{Sub}(S_3)$ is not modular. (Find the pentagon.)
4. Prove length additivity from the modular law.

> **Prologos Hook — Module 13.** The 30-second modular-law pitch for a Prologos collaborator with linear-algebra intuition: "Submodules of a module sit inside each other like subspaces inside a vector space — you can freely commute sums with intersections *when one summand is nested*. Non-abelian subgroup lattices don't have this freedom, which is exactly why module theory is cleaner than group theory. The Prologos compiler's submodule-of-lattice registries inherit this algebraic cleanliness: intervals slide past each other, incremental recompilation stays well-typed."

\newpage

## Module 14 · Chain Conditions and Length

### 14.1 Definitions

A poset satisfies *ACC* if every ascending chain $a_1 \leq a_2 \leq \cdots$ eventually stabilises; *DCC* dually. $M$ is *Noetherian* (resp. *Artinian*) if $\mathrm{L}(M)$ satisfies ACC (resp. DCC). $M$ has *finite length* if $\mathrm{L}(M)$ has finite height, equivalently both ACC and DCC.

### 14.2 Jordan–Hölder

**Theorem 14.1.** *If $M$ has finite length, any two composition series of $M$ have the same length and the same multiset of simple composition factors (up to isomorphism).*

Proof via Schreier's refinement lemma: any two subnormal series have equivalent refinements. The refinement construction uses the modular law at each step.

### 14.3 Exercises

1. Give a module that is Noetherian but not Artinian, and vice versa.
2. Compute the length of $\mathbb{Z}/p^n\mathbb{Z}$.
3. Prove: if $0 \to N \to M \to P \to 0$ is exact, then $\ell(M) = \ell(N) + \ell(P)$ (whenever lengths are finite).

> **Prologos Hook — Module 14.** Both chain conditions are load-bearing in Prologos but at different strata. The value stratum $S_0$ uses Noetherian reasoning — cell contents grow monotonically under a join, and the fixpoint is reached when no propagator can fire (ACC). The retraction stratum $S_{-1}$ (from `metavar-store.rkt`'s `run-retraction-stratum!`) uses Artinian reasoning — the set of assumptions can only shrink, so the narrowing computation terminates by DCC. The combined system has both chain conditions by design; termination is guaranteed per stratum (`GÖDEL_COMPLETENESS.org` Tables).

\newpage

## Module 15 · Decomposition and Modules of Lattices

**Goal.** Classical Krull–Schmidt in the first half, then the Prologos-sense "module of lattices" with its two realisation choices.

### 15.1 Semisimple modules (classical)

**Theorem 15.1.** *TFAE for an $R$-module $M$:*

1. *$M$ is a direct sum of simple submodules.*
2. *$M$ is a sum of simple submodules.*
3. *Every submodule of $M$ has a direct complement.*
4. *$\mathrm{L}(M)$ is complemented.*

The equivalence of (4) with the rest is the lattice-theoretic reformulation of semisimplicity.

### 15.2 Krull–Schmidt (classical)

**Theorem 15.2.** *Every module of finite length decomposes as a direct sum of indecomposables, and the decomposition is unique up to order and isomorphism of summands.*

The lattice-theoretic witness: two decompositions correspond to two maximal "independent" families in $\mathrm{L}(M)$ that can be matched via a common refinement — modularity doing the work again.

### 15.3 Where the classical lattice loses information

$\mathrm{L}(M)$ sees *which* submodules exist and *how* they sit. It does not see the ring action. Two modules can share a lattice without being isomorphic — for instance $\mathbb{Z}/p\mathbb{Z}$ and $\mathbb{Z}/q\mathbb{Z}$ for distinct primes both have the two-point lattice. Up to this well-understood blind spot, the lattice is a fully adequate invariant for structural questions.

### 15.4 The Prologos-sense "module of lattices"

A **module of lattices** in the Prologos sense is a collection of lattices $\{L_1, L_2, \ldots, L_k\}$ together with bridges between them that are Galois connections. The collection is held together by the product lattice $L_1 \times L_2 \times \cdots \times L_k$, on which the bridges specify the dependencies.

This is the structure that every Prologos registry inhabits. The propagator network's cells are its lattices; the propagators' fire functions realise the Galois-connection bridges; the product lattice is the cell-state space of the network. Fixpoint on the product lattice IS the network's fixpoint.

### 15.5 Direct sum has two realisations

The algebraic fact $R = C_1 \oplus C_2 \oplus \cdots \oplus C_n$ admits two realisations on the propagator network. The choice between them is a load-bearing engineering decision.

**Realisation A — separate cells with bridge morphisms.** Each $C_i$ is its own cell. Bridges propagate values between cells via monotone morphisms. Under speculative worldview semantics (multiple branches sharing the network), worldview-filtered reads on the bridge *collapse* tagged entries — the bridge sees only the merged value at the current worldview, losing per-branch identity. This is a real failure mode, diagnosed in BSP-LE Track 2B Phase 2a (three design iterations: D.9 probe, D.10 bitmask, D.11 stratified, before recognising bridges were the root cause).

**Realisation B — bitmask-tagged layers on a shared carrier cell.** One cell holds all components; each component's identity is a bitmask tag on the value's tagged entries. Reconciliation is automatic through the cell's merge function. No bridges, no tag collapse.

**Heuristic.** For value-level decomposition with worldview semantics, Realisation B is structurally simpler and eliminates the tag-collapse bug class. Bridges are the right answer only when the $C_i$ carry genuinely different types or live at different strata.

### 15.6 Exercises

1. Prove that a finite-dimensional vector space has $\mathrm{L}(M)$ a complemented modular lattice.
2. For $M = \mathbb{Z}/p\mathbb{Z} \oplus \mathbb{Z}/p\mathbb{Z}$, list all complements of a fixed simple submodule. How many are there?
3. Draw the lattice of $\mathbb{Z}/p^2\mathbb{Z}$ as a $\mathbb{Z}$-module and check that it is *not* complemented.
4. Design problem: given a Prologos feature that decomposes as $C_1 \oplus C_2$ and requires worldview-sensitive reads, choose between Realisation A and B and justify.

> **Prologos Hook — Module 15.** Concrete case: the clause-scope / query-scope refactor. Originally each clause was given its own scope cell, bridged to the query scope (Realisation A). Three design iterations fought the tag-collapse bug before recognising the bridge as the root cause. "Resolution B" has all clause variables as bitmask-tagged layers on the shared query-scope carrier cell (Realisation B). See `.claude/rules/structural-thinking.md` § "Direct Sum Has Two Realizations" for the full exposition; see BSP-LE Track 2B PIR §6.3, §12.2, §16.4 for the post-implementation review. This is Module 15 content taught in a PIR.

\newpage

# Part V — Prologos Applications

## Module 16 · The Hyperlattice Conjecture and the Design Mantra

**Goal.** State the conjecture that organises Prologos, and its operational form — the Design Mantra.

### 16.1 The Hyperlattice Conjecture

**Every computable function is expressible as a fixpoint computation on lattices. The Hasse diagram of the lattice IS the optimal parallel decomposition of that computation.**

Two claims:

1. **Universality.** Every computation can be expressed as a fixpoint on lattices. This is the mandate for putting everything on-network — every piece of state, every registry, every control flow — and is the source of the rule in `.claude/rules/on-network.md`: "Off-network state is debt against self-hosting."

2. **Optimality.** The Hasse diagram provides the optimal parallel structure. The hypercube research (Module 8) gives the strongest evidence: $Q_n$ as the worldview space has a Hasse diagram equal to the $n$-dimensional hypercube graph, whose adjacency structure directly gives Gray code traversal (optimal CHAMP sharing), subcube pruning ($O(1)$ nogood containment), and hypercube all-reduce (optimal BSP barriers). The parallel decomposition of worldview exploration IS the Hasse diagram.

### 16.2 The Design Mantra

> **"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."**

The mantra is the operational form of the conjecture. Each word is a challenge applied at every design decision:

- **All-at-once.** Are independent items being processed sequentially? If so, use broadcast propagators or parallel installation — not `for/fold`.
- **All in parallel.** Is there imposed ordering? BSP fires everything in a round simultaneously. Ordering must emerge from dataflow, not from installation sequence.
- **Structurally emergent.** Does the computation's shape fall out of the lattice topology, or is imperative control flow deciding what happens when?
- **Information flow.** Do values move through cells via propagators, or through return values and parameters?
- **ON-NETWORK.** Is this a cell with a monotone merge, or off-network state (a `make-parameter`, a struct field, a threaded hash)?

### 16.3 Exercises

1. Pick any algorithm you know — BFS on a graph, a type checker, a constraint solver — and sketch (informally) its Hasse-diagram parallel decomposition.
2. Run the Design Mantra over a piece of your own code. Identify one place where the mantra would demand restructuring.
3. Is the conjecture falsifiable? Sketch the shape of a counterexample (a computation not expressible as a lattice fixpoint, OR a fixpoint computation whose Hasse diagram is *not* the optimal parallel decomposition).

\newpage

## Module 17 · The SRE Lattice Lens — Six Questions for Every Cell

**Goal.** Run the discipline. Every cell, every merge, every bridge gets six questions before it ships.

The SRE (Structural Reasoning Engine) Lattice Lens is codified in `CRITIQUE_METHODOLOGY.org` and enforced at every design decision. Summarised from `.claude/rules/structural-thinking.md`:

### Q1 — Classification: VALUE or STRUCTURAL?

- **VALUE lattice**: the cell holds a single evolving value (a type, a constraint, an answer set). Information refines monotonically.
- **STRUCTURAL lattice**: the cell holds a compound structure where components evolve independently (scope-cell, decisions-state, commitments-state). The lattice is a product of component lattices.

### Q2 — Algebraic properties

What algebraic structure does the lattice have? Boolean (complementable)? Distributive (composition well-behaved)? Heyting (residuated)? Join-semilattice (CALM-safe)? Quantale (annotation algebra)? Most Prologos lattices are join-semilattices by design.

### Q3 — Bridges to other lattices

Every bridge is a Galois connection. If you can't produce the pair $(\alpha, \gamma)$, the bridge is not well-typed.

### Q4 — Composition: full bridge diagram

Draw *all* lattices in the design and *all* bridges between them. Composition must be type-correct (Galois connections compose).

### Q5 — Primary vs derived

Which lattice is primary (authoritative source) and which is derived (projection/cache)? Derived lattices can be recomputed from primary.

### Q6 — Hasse diagram: the optimality argument

**What is the Hasse diagram of this lattice?** This is the most important question. The Hasse diagram reveals: adjacency metric (optimal traversal order, e.g. Gray code), recursive decomposition (parallel structure), diameter (fixpoint depth), and subcube structure (for Boolean lattices, nogoods identify subcubes).

### 17.1 Worked example — running the lens on the worldview cache

**Q1.** Derived. The worldview cache is a projection of the decision cells.

**Q2.** Boolean. The worldview space is $Q_n$.

**Q3.** Two bridges: decision cells $\to$ cache ($\alpha$ = OR of committed bits), cache $\to$ decision cells ($\gamma$ = set of worldviews compatible with a commitment).

**Q4.** The full diagram has decision cells at the bottom, worldview cache above, and nogood set as a derived filter on the cache.

**Q5.** Decision cells primary; cache derived. The cache can be recomputed by re-running $\alpha$ over the current decision cells.

**Q6.** Hypercube $Q_n$. Adjacency is Hamming distance 1. Diameter is $n$. Subcubes correspond to partial assignments; nogoods are excluded subcubes with $O(1)$ containment check.

### 17.2 Exercises

1. Run the six-question lens on `bilattice.rkt`'s bilattice-variable structure (pairs of ascending/descending cells).
2. Run the lens on `interval-domain.rkt`'s interval cell. What is its Hasse diagram?
3. Pick a cell from `metavar-store.rkt` (your choice) and run the lens. Identify whether it's VALUE or STRUCTURAL, and what its Hasse diagram is.
4. Attempt Q3 on a bridge between `mult-lattice` and `bilattice` — can you produce the Galois pair? If not, what is the obstruction?

> **Prologos Hook — Module 17.** From `.claude/rules/workflow.md`: "SRE lattice lens REQUIRED for all lattice design decisions — any design that introduces or references a lattice MUST analyze it through the SRE lens." From the same file: "BSP-LE Track 2 discovered that the worldview lattice was treated as primary when decision cells are actually primary — invisible without the SRE lens." The lens is tooling discipline; the codebase has it running continuously through `.claude/rules/structural-thinking.md` as a tripwire at each decision point.

\newpage

## Module 18 · Reading the Prologos Codebase

**Goal.** Stratum-by-stratum tour of where the curriculum's content lives in the Prologos source.

### 18.1 The solver network

- **Core infrastructure**: `racket/prologos/propagator.rkt` — cells, propagators, BSP scheduler. Note `register-stratum-handler!` and the stratum-handlers box.
- **$S_0$ — monotone value propagator firing**: the BSP outer loop. All cells with monotone merges live here.
- **Topology stratum**: structural changes between BSP rounds — new cells, new propagators. `register-topology-handler!` (legacy box, pre-unification).
- **$S_1$ NAF**: `racket/prologos/relations.rkt` — `process-naf-request`. Non-monotone worldview validation via fork + BSP + nogood evaluation. Inverts provability.
- **$S_0$ Guard**: embedded in $S_0$ via worldview bitmask — guard goals become worldview assumptions; false guard triggers a nogood.

### 18.2 The elaborator network

- **$S_{-1}$ retraction**: `racket/prologos/metavar-store.rkt`'s `run-retraction-stratum!`. Non-monotone narrowing of scoped cell entries for retracted assumptions.
- **$L_1$ readiness**: `collect-ready-constraints-via-cells` — pure scan identifying constraints whose dependencies are now ground.
- **$L_2$ resolution**: action interpreter (trait lookup, instance commitment, unification retry).
- **Stratum 3 (verification)**: referenced in `effect-executor.rkt:54`, not fully realised.

### 18.3 Cells as lattices

- `racket/prologos/term-lattice.rkt` — 4-element flat term lattice $\{\bot, \mathrm{var}, \mathrm{ctor}(\ldots), \top\}$. Structural unification cells.
- `racket/prologos/session-lattice.rkt` — session-type lattice with session-unification merge.
- `racket/prologos/bilattice.rkt` — bilattice-variable infrastructure (ascending lower + descending upper cells). Engine for well-founded semantics. Degenerate case `bool-lattice = {⊥, false, true, ⊤}`.
- `racket/prologos/mult-lattice.rkt` — QTT multiplicity lattice $\{\bot, 0, 1, \omega, \top\}$. Flat.
- `racket/prologos/qtt.rkt` — type checker's quantitative rules; uses `mult-lattice` via `register-merge-fn!/lattice` on `mult-meta` cells.
- `racket/prologos/interval-domain.rkt` — abstract-interpretation interval domain with arithmetic constraint propagators.
- `racket/prologos/type-lattice.rkt` — type lattice used by the type checker.

### 18.4 Rules and methodology

- `.claude/rules/on-network.md` — the Design Mantra, the ON-NETWORK discipline.
- `.claude/rules/structural-thinking.md` — the SRE Lattice Lens, the Hyperlattice Conjecture, the two direct-sum realisations.
- `.claude/rules/propagator-design.md` — fire-once, broadcast, component-indexing, per-propagator worldview, cell allocation efficiency.
- `.claude/rules/stratification.md` — the stratum pattern, the request-accumulator protocol.
- `.claude/rules/workflow.md` — daily discipline, principles gates, design methodology.

### 18.5 Exercises

1. Open `bilattice.rkt`. Find `lattice-desc`. Identify bot, top, join, meet, leq. Is this a bilattice or a single lattice? (Hint: look at the ascending/descending cell pattern.)
2. Open `mult-lattice.rkt`. Find `mult-lattice-merge`. Predict the output of merging $0$ with $\omega$. Predict the output of merging $0$ with $1$. Verify by reading the code.
3. Open `interval-domain.rkt`. Identify the merge function. Is it a join or a meet? Why does that matter?
4. Open `.claude/rules/stratification.md`. List all five+ strata and match each to a file in the codebase.

> **Prologos Hook — Module 18.** The three-sentence pitch for a new Prologos collaborator after a weekend with this curriculum:
> (1) "Prologos runs every piece of state — registries, type information, constraint solutions, worldview assumptions — as a cell on a propagator network, where each cell holds a lattice value with a monotone merge."
> (2) "The BSP scheduler is running a Gauss–Seidel fixpoint on a stack of strata: a CALM-safe monotone $S_0$, a non-monotone retraction $S_{-1}$, a negation-as-failure $S_1$, plus topology and elaborator strata — each stratum's handler processes requests from the lower strata once they have quiesced."
> (3) "The Hyperlattice Conjecture says this is not an accident of convenience: every computation IS a fixpoint on lattices, and the Hasse diagram of the lattice IS the optimal parallel decomposition — which is why the worldview's hypercube gives Gray codes, subcube pruning, and hypercube all-reduce for free."

\newpage

# Communication Kit

## The three-slide explainer template

| Slide | For a module theorist | For a PL / dataflow person | For a Prologos collaborator |
|-------|-----------------------|----------------------------|-----------------------------|
| 1 — Setup | Module $M$, its submodule lattice $\mathrm{L}(M)$, Hasse diagram | Cell with monotone merge, semilattice value, fixpoint | Propagator network, stratum stack, the mantra |
| 2 — Claim | Structural property encoded as lattice shape | CALM-safe monotonicity; abstract-interpretation soundness | The Hyperlattice Conjecture + SRE lens |
| 3 — Evidence | Modular law, length, Jordan–Hölder, Krull–Schmidt | Tarski/Kleene fixpoint; Galois bridge; $Q_n$ hypercube | Concrete cells in `*-lattice.rkt`; stratification; Resolution B |

## Four sentences to know by heart

1. A module's submodule lattice is always modular — the algebraic fingerprint of the isomorphism theorems.
2. CALM theorem: a computation is coordination-free iff it is monotone on a join-semilattice.
3. Every bridge between lattices is a Galois connection — if you can't produce $(\alpha, \gamma)$, the bridge is not well-typed.
4. The Hasse diagram of the lattice IS the optimal parallel decomposition of the computation.

## Glossary crosswalk

| Module language        | Lattice language                        | Prologos-specific |
|------------------------|-----------------------------------------|-------------------|
| Submodule              | Element                                 | Cell value |
| Intersection $\cap$    | Meet $\wedge$                           | Lattice meet; `session-lattice-meet` |
| Sum $+$                | Join $\vee$                             | Merge function |
| Simple module          | Atom (covers $\bot$)                    | Smallest non-bottom cell value |
| Maximal submodule      | Coatom (covered by $\top$)              | Largest consistent cell value |
| Direct summand         | Complemented element                    | (in Boolean-lattice cells) |
| Composition series     | Maximal chain                           | Fixpoint trace |
| Length of $M$          | Height of $\mathrm{L}(M)$               | Tarski-fixpoint depth |
| Noetherian             | ACC                                     | $S_0$ monotone growth |
| Artinian               | DCC                                     | $S_{-1}$ retraction narrowing |
| 2nd iso theorem        | Modular law                             | — |
| Correspondence theorem | Interval $[N, M] \cong \mathrm{L}(M/N)$ | Registry interval = cells affected by one module |
| —                      | Galois connection $\alpha \dashv \gamma$ | Every bridge between cells |
| —                      | Tarski least fixpoint                   | $S_0$ propagator quiescence |
| —                      | Gauss–Seidel fixpoint                   | Stratum stack |
| —                      | Boolean lattice $Q_n$                   | Worldview space |
| —                      | Quantale                                | Candidate annotation algebra |
| —                      | Bilattice                               | `bilattice.rkt` |

\newpage

# Further Reading

## Classical lattice and module theory

- **G. Călugăreanu**, *Lattice Concepts of Module Theory*, Kluwer, 2000. Directly mirrors Part IV's structure; the definitive reference for the lattice view of modules.
- **G. Grätzer**, *General Lattice Theory*, 2nd ed., Birkhäuser, 1998. Canonical lattice reference.
- **J. B. Nation**, *Notes on Lattice Theory*, free PDF (University of Hawaii). Clean exposition, superb for quick lookup.
- **T. Y. Lam**, *A First Course in Noncommutative Rings*, 2nd ed., Springer, 2001. Chain conditions, Jordan–Hölder, module-theoretic style.

## Lattices for computation

- **J. M. Hellerstein, P. Alvaro**, "Keeping CALM: When Distributed Consistency Is Easy," *CACM* 63(9), 2020.
- **T. J. Ameloot, F. Neven, J. Van den Bussche**, "Relational transducers for declarative networking," *JACM* 60(2), 2013. The CALM theorem's original proof.
- **P. Cousot, R. Cousot**, "Abstract Interpretation: A Unified Lattice Model," POPL 1977. The founding paper.
- **G. Winskel**, *The Formal Semantics of Programming Languages*, MIT Press, 1993. Tarski and Kleene fixpoints, abstract machines.

## Quantales and annotation algebras

- **K. Rosenthal**, *Quantales and Their Applications*, Longman, 1990.
- **R. Atkey**, "Syntax and Semantics of Quantitative Type Theory," LICS 2018. QTT's foundation paper.
- **M. Fitting**, "Bilattices and the semantics of logic programming," *JLP* 11, 1991. The bilattice setting for three-valued logic.
- **T. J. Green, G. Karvounarakis, V. Tannen**, "Provenance semirings," PODS 2007. Provenance as semiring computation.
- **The Prologos quantale brief**: `research/quantale research/outputs/quantale-propagator-annotations.md` (April 13, 2026).

## Prologos rules and methodology

- `.claude/rules/on-network.md` — the Design Mantra and ON-NETWORK discipline.
- `.claude/rules/structural-thinking.md` — the SRE Lattice Lens and Hyperlattice Conjecture.
- `.claude/rules/propagator-design.md` — propagator-design checklists.
- `.claude/rules/stratification.md` — the stratum pattern.
- `.claude/rules/workflow.md` — daily workflow, principles gates.
- `.claude/rules/testing.md` — testing discipline.
- `.claude/rules/pipeline.md` — pipeline exhaustiveness checklists.

\newpage

# Appendix A — Suggested 16-Session Schedule

| Session | Topic | Reading | Exercises |
|---------|-------|---------|-----------|
| 1 | Orientation + posets | Modules 0, 1 | 1.4.1–5 |
| 2 | Lattices | Module 2 | 2.4.1–5 |
| 3 | Special classes | Module 3 | 3.6.1–5 |
| 4 | Morphisms, Galois preview | Module 4 | 4.4.1–3 |
| 5 | Semilattices + CALM | Module 5 | 5.5.1–4 |
| 6 | Fixpoints | Module 6 | 6.6.1–4 |
| 7 | Galois & abstract interpretation | Module 7 | 7.4.1–4 |
| 8 | Heyting, Boolean, hypercube | Module 8 | 8.5.1–4 |
| 9 | Semirings → quantales | Module 9 | 9.5.1–5 |
| 10 | Residuated, bilattices, QTT | Module 10 | 10.4.1–5 |
| 11 | Modules refresher | Module 11 | 11.4.1–3 |
| 12 | Submodule lattice + modular law | Modules 12, 13 | 12.4.1–3, 13.4.1–4 |
| 13 | Chain conditions, decomposition | Modules 14, 15 | 14.3.1–3, 15.6.1–4 |
| 14 | Hyperlattice Conjecture + Mantra | Module 16 | 16.3.1–3 |
| 15 | SRE Lattice Lens | Module 17 | 17.2.1–4 |
| 16 | Codebase tour + Communication Kit | Module 18 + Kit | 18.5.1–4 |

Each session should end with one diagram drawn on paper. Accumulate a stack.

\newpage

# Appendix B — Five Prologos Cells, Five Diagrams

A quick-reference visual cheat sheet of the five most important lattices in the Prologos codebase:

1. **`term-lattice.rkt`** — Four-element flat lattice $\{\bot, \mathrm{var}, \mathrm{ctor}(\ldots), \top\}$. Hasse: bottom, two incomparable middle nodes ($\mathrm{var}$ and the constructor family), top.

2. **`mult-lattice.rkt`** — Five-element flat lattice $\{\bot, 0, 1, \omega, \top\}$. Hasse: bottom, three incomparable middle nodes $0, 1, \omega$, top. $M_3$-like with three atoms.

3. **`bilattice.rkt` (boolean case)** — Four-element $\{\bot, \mathtt{false}, \mathtt{true}, \top\}$ under two orders. Truth order: $\bot \to \{\mathtt{false}, \mathtt{true}\} \to \top$. Information order: pair of ascending/descending cells, the gap encodes "unknown."

4. **$Q_n$ (worldview)** — Boolean hypercube. Hasse: $n$-dimensional hypercube graph.

5. **`interval-domain.rkt`** — Interval lattice with meet = intersection. Hasse: infinite; $\bot$ (empty interval) at bottom, a layer of single-integer intervals, a layer of two-integer intervals, and so on upward to $\top = (-\infty, \infty)$.

*End of curriculum. Accumulate your drawn diagrams. The best Prologos explainer you will ever write is the one where you have twenty lattice pictures in front of you, and you can point at them.*
