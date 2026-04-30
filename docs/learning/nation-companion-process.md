# Nation Lattice Theory Companion — Process Notes

A companion project for J. B. Nation's *Notes on Lattice Theory* (University of Hawaii lecture notes, ongoing). Mirrors the established Călugăreanu companion process, adapted for Nation's different conventions and scope.

## Source

**J. B. Nation, *Notes on Lattice Theory***, University of Hawaii. Available as a free PDF at the author's site:
- `outside/UH Professor - JB Nation - Lattices, Publications/Nation-LatticeTheory.pdf` (in this workspace)

Nation's notes are the basis for a one-semester introduction to lattice theory. The book has 11 chapters + 3 appendices. Style: pedagogical, conversational, with literary epigraphs at chapter starts. Faster pace than Călugăreanu, broader scope (includes free lattices, varieties, geometric lattices), and a stronger connection to logic (compactness theorem appears in Chapter 1).

## Chapter inventory (Nation)

| # | Title | PDF pp. |
|---|-------|---------|
| 1 | Ordered Sets | 3–14 |
| 2 | Semilattices, Lattices and Complete Lattices | 15–29 |
| 3 | Algebraic Lattices | 30–41 |
| 4 | Representation by Equivalence Relations | 42–51 |
| 5 | Congruence Relations | 52–63 |
| 6 | Free Lattices | 64–76 |
| 7 | Varieties of Lattices | 77–90 |
| 8 | Distributive Lattices | 91–100 |
| 9 | Modular and Semimodular Lattices | 101–114 |
| 10 | Finite Lattices and their Congruence Lattices | 115–125 |
| 11 | Geometric Lattices | 126–132 |
| App 1 | Cardinals, Ordinals and Universal Algebra | 133–136 |
| App 2 | The Axiom of Choice | 137–139 |
| App 3 | Formal Concept Analysis | 140–143 |

## File layout

- `nation-companion-toc.html` — front door / table of contents
- `nation-companion-ch01.html` … `nation-companion-ch11.html` — chapter companions
- `nation-companion-app1.html`, etc. — appendix companions (TBD)
- `nation-companion-process.md` — this file

The Nation companion is **separate** from the Călugăreanu companion (different ToC, different file prefix). The two books cover overlapping foundational vocabulary but diverge sharply: Nation goes broader (free lattices, varieties, geometric lattices); Călugăreanu goes deeper into the module-theoretic side (radicals, supplemented, four dimensions). A reader interested in the full lattice landscape benefits from both companions.

## Notation differences from Călugăreanu

Nation uses several conventions that differ from Călugăreanu. Worth flagging in each chapter primer:

| Concept | Nation | Călugăreanu |
|---|---|---|
| Power set | $\mathfrak{P}(X)$ | $\mathcal{P}(M)$ |
| Submodule lattice | (not used; Nation focuses on lattices abstractly) | $S_R(M)$ |
| Subgroup lattice | **Sub** $\mathcal{G}$ | $L(G)$ |
| Principal ideal of $x$ | $\downarrow x = \{y : y \le x\}$ | $a/0 = \{x : x \le a\}$ |
| Principal filter of $x$ | $\uparrow x = \{y : y \ge x\}$ | (not as a single symbol) |
| Lattice of order ideals | $\mathcal{O}(\mathcal{P})$ | $I(L)$ |
| Cover relation | $a \prec b$ | $a \prec b$ (same) |
| Dual poset | $\mathcal{P}^d$ | $L^0$ |
| Width (of poset) | $w(\mathcal{P})$ | (not as a single symbol; see Goldie dim later) |
| Chain covering number | $c(\mathcal{P})$ | (not as a single symbol) |
| Order dimension | $d(\mathcal{P})$ | (not as a single symbol) |

## Stylistic differences

- **Nation has literary epigraphs** at chapter heads (Bob Dylan, "Harvey," Ricky Nelson). The companion preserves these in the chapter overview but doesn't lean on them stylistically.
- **Nation's proof style** is terser: more "this is straightforward," less spelled-out modular juggling. The companion expands.
- **Nation includes more set-theoretic preliminaries**: Theorem 1.5 (Axiom of Choice equivalents) and Theorem 1.6 (Compactness theorem from propositional logic) appear in Chapter 1. The Călugăreanu companion handles AoC quickly via a single mention; the Nation companion gives it the proper deep dive.
- **Nation's three invariants** $w, c, d$ for ordered sets recur throughout the book. The companion sets them up carefully in Chapter 1 and refers back.

## Process discipline (shared with Călugăreanu companion)

- Each chapter HTML follows the established template: head + sidebar + hero + overview + vocab primer (carried forward / new / deep dive) + parts A-E ish + 5 connection panels + glossary + worked exercises + Looking Ahead + footer + scripts.
- Theme tokens, box-callout vocabulary, math conventions, exercise pattern: all shared with the Călugăreanu companion.
- Validate each chapter via Python HTMLParser before considering it done.
- The companion's "third subsection" (Deep dive) is used liberally in Nation Ch 1 because the AoC / compactness theorem material warrants extended treatment.

## Workflow per Nation chapter

1. **Read** the chapter pages from the PDF.
2. **Plan**: scaffold sections, glossary terms, exercises to work, connection panels.
3. **Write** the chapter HTML following the template.
4. **Cross-link**: forward link from previous Nation chapter, update Nation ToC's progress dot + chapter card.
5. **Update** this process file with the chapter's term ledger.
6. **Verify** via Python HTMLParser.
7. **Reply** to the user with computer:// links + summary.

## Term ledger

### Nation Chapter 1 — Ordered Sets — terms introduced new

partially ordered set (poset) · binary relation · reflexivity / antisymmetry / transitivity · power set $\mathfrak{P}(X)$ · subgroup lattice $\mathbf{Sub}\,\mathcal{G}$ · chain (totally ordered) · antichain · cover relation $\prec$ · Hasse diagram · order-preserving map (= order morphism) · isomorphism · Cayley-style representation theorem · order ideal · $\mathcal{O}(\mathcal{P})$ (lattice of order ideals) · dual poset $\mathcal{P}^d$ · order filter · principal ideal $\downarrow x$ · principal filter $\uparrow x$ · maximum / maximal · minimum / minimal · descending chain condition (DCC) · ascending chain condition (ACC) · induction principle for DCC · width $w(\mathcal{P})$ · chain covering number $c(\mathcal{P})$ · upper bound · lower bound · least upper bound (LUB) · greatest lower bound (GLB) · well-ordering · sentence symbol · well-formed formula (wff) · truth assignment · satisfiable / finitely satisfiable · compactness theorem (propositional logic) · linear extension · realizer · order dimension $d(\mathcal{P})$ · quasiorder · partial map · Dushnik-Miller dimension.

### Nation Chapter 1 — terminology traps

"Order morphism" / "order-preserving map":
- Same concept; Nation uses "order-preserving map," Călugăreanu uses "order morphism." This companion uses both.

"Maximum" vs "maximal":
- Maximum: $\ge$ everything. Maximal: nothing strictly above. Maximum ⟹ maximal; converse fails. Same as in Călugăreanu Ch 1.

"$\mathfrak{P}(X)$" vs "$\mathcal{P}(M)$":
- Same concept (power set). Nation uses Fraktur P; Călugăreanu uses calligraphic P. Conventions vary.

"Cover relation" $\prec$:
- $a \prec b$ means $a < b$ AND no $c$ with $a < c < b$. Same in both books.

"Chain" overloads:
- Chain (poset sense, this chapter): totally ordered subset.
- Chain (lattice / module sense, Călugăreanu): also totally ordered, same concept.
- Chain (algebraic topology): formal sum of cells — completely different.

"Width" $w(\mathcal{P})$ vs Goldie dimension:
- $w(\mathcal{P})$: maximum size of an antichain in $\mathcal{P}$.
- Goldie dimension: max size of an independent set of uniforms in a modular lattice.
- Both are "max size of an incomparable family" in spirit, but they use different notions of incomparability.

"Dimension" $d(\mathcal{P})$ vs Krull dimension:
- $d(\mathcal{P})$ (Dushnik-Miller, this chapter): smallest cardinality of a realizer of total orders.
- Krull dimension (Gabriel-Rentschler): smallest ordinal of deviation; transfinite.
- Both are "dimensions" of ordered sets but answer different structural questions.

"Compactness theorem":
- Compactness theorem (propositional logic, Theorem 1.6): a set of WFFs is satisfiable iff every finite subset is.
- Compactness (lattice theory, Călugăreanu Ch 1-2): an element $c$ such that $c \le \bigvee S \Rightarrow c \le \bigvee F$ for finite $F$.
- The two are deeply related (both are "finitary witness" results; compactness in topology is the unifier) but are introduced separately in different traditions.

### Convention going forward

- New chapters of the Nation companion follow the same primer structure as Călugăreanu chapters: Carried forward / New / Deep dive.
- The "Carried forward" section for Nation Ch 2 onward will recap from Nation Ch 1 (not Călugăreanu chapters); the two companions are independent.
- When a result has counterparts in both books (e.g., Hasse diagrams, modular law), the Nation chapter notes the parallel briefly but does not depend on the Călugăreanu chapter.

### Nation Chapter 2 — Semilattices, Lattices and Complete Lattices — terms introduced new

semilattice (algebra (S, *) idempotent commutative associative) · meet semilattice / join semilattice · subsemilattice · semilattice homomorphism · lattice (algebra (L, ∧, ∨) with absorption) · distributive law (D) · $\mathcal{M}_3$ · $\mathcal{N}_5$ · sublattice / lattice morphism / lattice isomorphism · interval [b,a] = a/b · principal ideal $\downarrow a$ / principal filter $\uparrow a$ · upper bound set $A^u$ / lower bound set $A^\ell$ · complete lattice · complete meet semilattice · closure system · closure operator (extensive, monotone, idempotent) · closure rules ($x \in S$ or $Y \subseteq S \Rightarrow z \in S$) · subalgebra · Sg($B$) generated subalgebra · join irreducible · $J(\mathcal{L})$ · $J_0(\mathcal{L}) = J(\mathcal{L}) \cup \{0\}$ · completely join irreducible · $J^*(\mathcal{L})$ · lower cover $q_*$ · completion of an ordered set · join dense subset · order ideal completion $\mathcal{O}(\mathcal{P})$ · MacNeille completion $\mathcal{M}(\mathcal{P})$ (= normal completion = completion by cuts) · cut · $\mathcal{K}(\mathcal{P})$ lattice of all join-dense completions · $\text{Cl}(X)$ lattice of all closure operators · order on closure operators · Knaster-Tarski theorem · Davis converse · Galois connection · Morgan Ward generalised closure operator · cofinal subset.

### Nation Ch 2 — terms recapped from Ch 1

poset · $\le$ · R/A/T · order ideal · $\mathcal{O}(\mathcal{P})$ · $\downarrow x$ · $\uparrow x$ · DCC · ACC · $\mathfrak{P}(X)$ · Theorem 1.1 (Cayley-style) · Hasse diagram · $\mathfrak{R}$ · ordered set · order morphism · embedding.

### Nation Ch 2 — deep-dive additions

The closure trinity (system / operator / rules — three faces of one idea, with a corresponding-correspondences table) · The MacNeille completion as the "smallest" completion (Dedekind 1872 → MacNeille 1937 genealogy; preserves all existing meets and joins; comparison with order-ideal completion) · The Knaster-Tarski-Davis fixed-point theorem (Knaster 1928 → Tarski 1955 → Davis 1955; uses in denotational semantics, abstract interpretation, game theory; why Davis's converse matters structurally).

### Nation Ch 2 — terminology traps

"Subsemilattice" vs "subset that's a semilattice under inherited order":
- Subsemilattice: closed under the parent's $*$ operation.
- Subset-with-inherited-order-being-a-semilattice: weaker — operation may differ from parent.
- Footnote in Nation: $\{1,2\}, \{1,3\}, \emptyset$ in $(\mathfrak{P}(\{1,2,3\}), \cap)$ are NOT a subsemilattice (parent $\cap$ gives $\{1\}$, not $\emptyset$) but ARE a 3-element semilattice in their own right under the inherited order.

"Join irreducible" naming convention:
- Nation's convention: $0 \notin J(\mathcal{L})$ since $0 = \bigvee \emptyset$.
- Some authors include 0: define join-irreducible by "$q = r \vee s$ ⟹ $q = r$ or $q = s$" (equivalent for nonzero, but includes 0).
- Use $J_0(\mathcal{L}) = J(\mathcal{L}) \cup \{0\}$ when needed.

"Completely join irreducible" vs "join irreducible":
- Join irreducible: $q = \bigvee F$ for FINITE $F$ ⟹ $q \in F$.
- Completely join irreducible: $q = \bigvee X$ for ARBITRARY (possibly infinite) $X$ ⟹ $q \in X$.
- Strict containment: $J^*(\mathcal{L}) \subseteq J(\mathcal{L})$ in general; equality under ACC.

"Closure operator" overloads:
- On a set (this chapter): $\Gamma : \mathfrak{P}(X) \to \mathfrak{P}(X)$ extensive, monotone, idempotent.
- On a complete lattice (Morgan Ward, Ex 13): $f : L \to L$ with the same three axioms but on lattice elements, not subsets.
- On a topological space: $A \mapsto \overline{A}$ — the topological closure. A specific instance.

"Complete meet semilattice" vs "complete lattice":
- Complete meet semilattice: top element + every nonempty subset has glb. Convention: $\bigwedge \emptyset = 1$.
- Complete lattice: every subset (including empty) has glb and lub. Stronger.
- Theorem 2.5: complete meet semilattices are automatically complete lattices.

"Completion" overloads:
- Completion of an ordered set: complete lattice + order embedding (this chapter).
- Cauchy completion (real analysis, metric spaces): closure under Cauchy sequences. Different concept.
- Algebraic completion (field theory): closure under algebraic operations. Different.

"MacNeille completion" naming:
- Also called: Dedekind-MacNeille completion, normal completion, completion by cuts.
- Generalises Dedekind cuts (1872) to arbitrary partial orders (MacNeille 1937).
- For $\mathbb{Q}$: recovers $\mathbb{R} \cup \{-\infty, +\infty\}$.

"$\mathcal{O}$" overloads:
- $\mathcal{O}(\mathcal{P})$ in Ch 1: lattice of order ideals.
- $\mathcal{O}(A)$ in Ch 2: order-ideal closure of $A$ (the order ideal generated by $A$). Same object viewed as closure operator.

### Nation Chapter 3 — Algebraic Lattices — terms introduced new

algebraic closure operator ($\Gamma(B) = \bigcup\{\Gamma(F) : F$ finite$\}$) · finitary closure rule · up-directed set · compact element · $\mathcal{L}^c$ (set of compact elements) · algebraic lattice (= compactly generated) · ideal of join semilattice · $\mathcal{I}(\mathcal{S})$ · $\mathcal{I}(\mathcal{L})$ · filter (dual of ideal) · filter lattice $\mathcal{F}(\mathcal{L})$ · Birkhoff-Frink theorem · Hanf's theorem · weakly atomic · upper continuous · lower continuous · atom · coatom · completely meet irreducible · $M^*(\mathcal{L})$ · upper cover $q^*$ · decomposition · irredundant decomposition · strongly atomic · Crawley's theorem · spatial lattice (in exercises) · subalgebra · Sg($B$) · congruence lattice $\text{Con}\,\mathcal{A}$ · cyclic element · Galois connection generalisation (Ex 3.9) · Morgan Ward semimodular characterisation (Ex 3.10) · Keith Kearnes strongly irredundant (Ex 3.11).

### Nation Ch 3 — terms recapped from Chs 1-2

closure operator · closure rules · closure system $\mathcal{C}_\Gamma$ · complete lattice · subalgebra · $\text{Sub}\,\mathcal{A}$ · order ideal · $\mathcal{O}(\mathcal{P})$ · principal ideal $\downarrow x$ · join semilattice · Theorem 2.6 (closure trinity) · Theorem 2.7 (every complete lattice IS a closure system) · Theorem 2.10 (join-dense completion ↔ closure operator) · MacNeille completion · Lemma 2.8 (DCC ⟹ finite join of join-irreducibles) · join irreducible · $J(\mathcal{L})$ · poset · DCC · ACC.

### Nation Ch 3 — deep-dive additions

The Birkhoff-Frink correspondence (algebra ↔ closure ↔ lattice — three perspectives on the same structural object, with a comparison table) · Compactness across lattice / topology / logic / domain theory / algebraic geometry (with a unified table; Stone duality as bridge) · The Birkhoff-Frink algebra construction (explicit operations $f_{G, x}$ realising closure rules; the cardinality issue and Hanf's reduction).

### Nation Ch 3 — terminology traps

"Compact element" overloads:
- Compact element (this chapter, lattice theory): $x \le \bigvee A$ ⟹ $x \le \bigvee F$ for finite $F$. Lattice analogue of "finitely generated."
- Compact in topology: every open cover has finite subcover.
- Compact in domain theory (Scott domains): $x \sqsubseteq \bigsqcup A$ for directed $A$ ⟹ $x \sqsubseteq a$ for some $a$. Slightly different (directed instead of arbitrary).
- All three are bridged by Stone duality and its extensions.

"Algebraic lattice" naming:
- Nation: "algebraic" or "compactly generated" — synonyms.
- Călugăreanu: "compactly generated" only.
- Some authors reserve "algebraic" for ALGEBRAIC LATTICES IN UNIVERSAL ALGEBRA SENSE (subalgebra lattices) and use "compactly generated" for the abstract lattice property. Birkhoff-Frink's theorem unifies them.

"$\mathcal{L}^c$" notation:
- Nation: superscript $c$ for compact elements.
- Some texts use $K(\mathcal{L})$ or $\text{Cpt}(\mathcal{L})$.

"Theorem 3.4 vs Theorem 3.5":
- Theorem 3.4 (Birkhoff-Frink): EXISTENCE of algebra realising $\Gamma$ — wasteful, may have $|X|$ operations.
- Theorem 3.5 (Hanf): EFFICIENT existence — countably many operations or even one binary operation, when the lattice is countable.

"Algebraic closure operator" vs "topological closure":
- Algebraic: closure determined by finite witnesses (this chapter).
- Topological: depends on infinite sequences (limits of convergent sequences).
- Topology is NOT algebraic in this sense.
- Both are closure operators (extensive, monotone, idempotent), but the algebraic restriction is strict.

"Decomposition" vs "irredundant decomposition":
- Decomposition: $a = \bigwedge Q$ for $Q \subseteq M^*$. Always exists in algebraic lattices (Theorem 3.10).
- Irredundant: additionally $a < \bigwedge(Q - \{q\})$ for every $q$. May NOT exist (Nation gives counterexample).
- Strongly atomic algebraic lattices have irredundant decompositions (Crawley, Theorem 3.11).
- Distributive case: unique (Theorem 3.12).

"Spatial lattice" (in Exercises 15-17):
- Spatial: every element is a join of completely join irreducibles.
- Generalises Theorem 2.9. In upper continuous lattices: completely join irreducible ⟺ join irreducible AND compact (Ex 3.15).
- Algebraic + DCC ⟹ spatial (Ex 3.17).
- In topos theory and frame theory: "spatial frame" means "frame of opens of some topological space" — analogous structural property.

"Strongly atomic" vs "weakly atomic" vs "atomic":
- Atomic: each $a/0$ contains an atom.
- Weakly atomic: $a > b$ ⟹ $\exists u, v$ with $a \ge u \succ v \ge b$ (somewhere in the interval).
- Strongly atomic: $a > b$ ⟹ $\exists u$ with $a \ge u \succ b$ (immediately above $b$).
- Strict ordering: strongly atomic ⟹ weakly atomic ⟹ atomic (the last in lattices with 0). Converses fail.

### Nation Chapter 4 — Representation by Equivalence Relations — terms introduced new

equivalence relation (R, S, T) · partition · equivalence class · kernel $\ker f$ · congruence relation · $\textbf{Eq}\,X$ — partition lattice (algebraic, strongly atomic, semimodular, relatively complemented, simple) · relative product $R \circ S$ · permuting / commuting equivalence relations · representation $(X, F)$ by equivalence relations · type 1, type 2, type 3 representation · weak representation · Sublemma 1 (extension by 3 new points) · Sublemma 2 (limit-ordinal continuity) · Whitman's theorem (Theorem 4.1) · Pudlák-Tůma theorem (Theorem 4.2, 1980) · modular law $(M)$ · equivalent form $(M')$ · distributive law $(D)$ · pentagon $\mathcal{N}_5$ · Arguesian law $(A)$ · Arguesian inclusion $(A')$ · Desargues' Law (projective geometry) · Schützenberger 1945 · Freese-Jónsson 1976 (congruence modularity ⟹ Arguesian) · Haiman 1987, 1991 (Arguesian ⟹ type 1 fails) · Pálfy-Szabó 1995 (abelian subgroup identity).

### Nation Ch 4 — terms recapped from Chs 1-3

lattice · lattice morphism / embedding · algebraic lattice · subalgebra · $\textbf{Sub}\,\mathcal{A}$ · Cayley-style representation theorems · binary relation · $\mathfrak{P}(X)$ · $\mathfrak{P}(X^2)$ · finitary closure rules · Birkhoff-Frink theorem (preview Ch 3) · normal subgroup lattice · ideal lattice.

### Nation Ch 4 — deep-dive additions

Whitman's proof technique (the transfinite-recursion paradigm in lattice theory: successor step + limit step + outer iteration) · Dedekind's modular law (1890s) and module theory (Dedekind 1892, 1897, 1900; lattices of normal subgroups, submodules, ideals, subspaces — all modular) · The Arguesian / Desargues / projective-geometry connection (Desargues 1648 → Schützenberger 1945 → Jónsson 1953 → Haiman 1987/1991; subspace lattices of Desarguesian projective spaces are Arguesian).

### Nation Ch 4 — terminology traps

"Equivalence relation" vs "congruence":
- Equivalence relation: just R, S, T on a set — no algebra structure.
- Congruence: equivalence relation on an ALGEBRA preserved by all operations.
- Congruences are equivalence relations; the converse may fail (some equivalences don't preserve operations).
- $\textbf{Eq}\,X \supseteq \text{Con}\,\mathcal{A}$ for any algebra $\mathcal{A}$ on $X$.

"Type 1 / 2 / 3" representations:
- Type 1: $F(x) \vee F(y) = F(x) \circ F(y)$ — joins via 1 step in relative product.
- Type 2: $F(x) \circ F(y) \circ F(x)$ — 3 steps (length-3 expression).
- Type 3: $F(x) \circ F(y) \circ F(x) \circ F(y)$ — 4 steps.
- Implication: type 1 ⟹ type 2 ⟹ type 3.
- Existence: type 3 always exists (Whitman), type 2 ⟺ modular (Jónsson), type 1 ⟹ Arguesian (Schützenberger / Jónsson).

"Modular" vs "distributive" vs "Arguesian":
- Modular $(M)$: $x \ge y$ ⟹ $x \wedge (y \vee z) = y \vee (x \wedge z)$.
- Distributive $(D)$: $x \wedge (y \vee z) = (x \wedge y) \vee (x \wedge z)$.
- Arguesian $(A)$: a 6-variable identity stronger than modular, weaker than distributive.
- Strict containment: distributive ⊊ Arguesian ⊊ modular.

"Permuting" / "commuting" equivalence relations:
- $R, S$ permute if $R \circ S = S \circ R$.
- Equivalent (Ex 4.4): $R \vee S = R \circ S$ (= type 1 join).
- Normal subgroups always permute (cosets); arbitrary subgroups may not.

"Whitman" — two different theorems:
- This chapter (Theorem 4.1): every lattice embeds in $\textbf{Eq}\,X$ via type 3 representation.
- Whitman's W condition (Nation Ch 6): condition characterising free lattices. Different theorem; same author (Philip M. Whitman 1941, 1946).

"Pudlák-Tůma 1980":
- Famous result: every FINITE lattice embeds in a FINITE partition lattice.
- Difficult proof; modern improvements give "tight" embeddings.
- Distinct from Theorem 4.1 (Whitman/Jónsson), which gives infinite representations.

"Subgroup lattice" vs "normal subgroup lattice":
- Subgroup lattice $\textbf{Sub}\,\mathcal{G}$: all subgroups, modular only when $\mathcal{G}$ is "nice" (e.g., abelian).
- Normal subgroup lattice $\mathcal{N}(\mathcal{G})$: only normal subgroups, ALWAYS modular and Arguesian.
- The lattice of subgroups of an abelian group is in $\mathcal{N}(\mathcal{G})$ (everything normal), and satisfies Pálfy-Szabó's stronger identity.

### Nation Chapter 5 — Congruence Relations — terms introduced new

congruence relation $\theta$ on a lattice $\mathcal{L}$ · the substitution property (preservation by $\vee$ and $\wedge$) · quotient lattice $\mathcal{L}/\theta$ · congruence class $[a]_\theta$ · natural projection $\pi_\theta : \mathcal{L} \to \mathcal{L}/\theta$ · First Isomorphism Theorem (Theorem 5.1) · Theorem 5.2 (quotient is a lattice; $\pi_\theta$ is a homomorphism) · congruence lattice $\textbf{Con}\,\mathcal{L}$ · principal congruence $\text{con}(a, b)$ · Theorem 5.3 (Con $\mathcal{L}$ is algebraic; principal congruences are compact) · Second Isomorphism Theorem / Correspondence Theorem (Theorem 5.4) · subdirect product · subdirect embedding · subdirectly irreducible (SI) algebra · monolith $\mu$ · subdirect representation Theorems 5.5, 5.6, 5.7 (Birkhoff 1944) · Funayama–Nakayama Theorem 5.8 (1942) · majority polynomial $m(x, y, z) = (x \wedge y) \vee (x \wedge z) \vee (y \wedge z)$ · Pixley's term · weaving polynomial · alternating chain $\vee, \wedge, \vee, \wedge, \ldots$ · Theorem 5.9 (characterisation of $\text{con}(a,b)$ via weaving sequences) · completely join prime · join prime · Theorems 5.10, 5.11, 5.12 (in finite distributive lattices: completely join prime ⟺ join prime ⟺ join irreducible) · congruence lattice problem (CLP) · Dilworth's question · Wehrung 2007 · Růžička 2008 ($\aleph_2$ counterexample).

### Nation Ch 5 — terms recapped from Chs 1-4

lattice · lattice homomorphism · kernel of a function · equivalence relation (R, S, T) · partition · $\textbf{Eq}\,X$ partition lattice · relative product $R \circ S$ · permuting equivalence relations · algebraic lattice · compact element · Theorem 3.4 (Birkhoff-Frink) · finitely generated subalgebra · join irreducible · $J(\mathcal{L})$ · distributive lattice · modular lattice · pentagon $\mathcal{N}_5$ · diamond $\mathcal{M}_3$ · normal subgroup lattice · ideal lattice · sublattice · principal ideal $\downarrow x$ · order ideal completion $\mathcal{O}(\mathcal{P})$.

### Nation Ch 5 — deep-dive additions

Funayama–Nakayama Theorem (1942) and the surprise of congruence-distributivity (the meta-lattice of congruences is always distributive even when $\mathcal{L}$ itself is the wildest non-modular lattice; proof via Pixley's majority polynomial — historical lineage Pixley 1963 → Mal'cev → Jónsson 1967 lemma) · Birkhoff's Subdirect Representation Theorem (1944, *Bull. AMS* 50) and its role as a foundational structure theorem of universal algebra (every algebra factors through its SI quotients; the variety of subdirectly irreducibles characterises the variety) · The Congruence Lattice Problem (Dilworth 1940s → Schmidt 1968 → Pudlák 1985 → Wehrung 2007 → Růžička 2008): which distributive algebraic lattices arise as $\textbf{Con}\,\mathcal{L}$ for some lattice $\mathcal{L}$? Answer: not all — Wehrung's counterexample disproved Dilworth's conjecture.

### Nation Ch 5 — terminology traps

"Congruence" vs "equivalence relation":
- Equivalence relation on a set: R, S, T (Ch 4).
- Congruence on an algebra: equivalence relation that ALSO preserves all operations (the substitution property).
- $\textbf{Con}\,\mathcal{L} \subseteq \textbf{Eq}\,L$ — strict containment in general (most equivalence relations on $L$ are not congruences).
- Theorem 5.3: $\textbf{Con}\,\mathcal{L}$ is itself an algebraic lattice (sometimes a complete sublattice of $\textbf{Eq}\,L$, sometimes not — the join in Con may differ from the join in Eq when relative products fail to be congruences).

"$\text{con}(a, b)$" — three readings:
- Smallest congruence with $a \, \theta \, b$ (the principal one).
- Compact element of $\textbf{Con}\,\mathcal{L}$ (Theorem 5.3).
- The image of the kernel of the map collapsing $a$ to $b$.
- All three are the same; perspective shifts depending on context.

"Subdirectly irreducible (SI)":
- Trivial algebras (1-element) are conventionally SI.
- A non-trivial algebra is SI ⟺ $\textbf{Con}\,\mathcal{A}$ has a smallest non-zero element (the monolith $\mu$).
- For lattices: SI ⟺ there exist $a < b$ such that every non-trivial congruence collapses $a$ and $b$.
- $\mathcal{M}_3$ and $\mathcal{N}_5$ are SI; products of two SIs are usually not.

"Subdirect product" vs "direct product":
- Direct product: full product $\prod A_i$.
- Subdirect product: subalgebra of $\prod A_i$ such that EVERY projection is surjective.
- Subdirect ⟹ each factor is "fully realised," but the subalgebra may not be the whole product.
- Theorem 5.6: every algebra is subdirectly embedded in the product of its SI quotients.

"Distributive" — two layers:
- Distributive $\mathcal{L}$: the lattice itself satisfies $(D)$.
- Distributive $\textbf{Con}\,\mathcal{L}$: the lattice of congruences on $\mathcal{L}$ satisfies $(D)$.
- Funayama–Nakayama (Theorem 5.8): the SECOND ALWAYS HOLDS, regardless of whether $\mathcal{L}$ is distributive. Subtle.
- Vocabulary trap: "$\mathcal{L}$ has a distributive congruence lattice" or "$\mathcal{L}$ is congruence-distributive" both refer to the second layer.

"Majority polynomial" / "Pixley term":
- Majority term: $m(x, y, z)$ such that $m(x, x, y) = m(x, y, x) = m(y, x, x) = x$.
- Pixley's term in lattices: $m(x, y, z) = (x \wedge y) \vee (x \wedge z) \vee (y \wedge z)$.
- Theorem (Jónsson 1967): variety has a majority term ⟹ congruence distributive.
- The proof of Theorem 5.8 uses Pixley's term explicitly.

"Weaving polynomial":
- Polynomial built by alternating $\vee$ and $\wedge$ on a sequence of arguments.
- Used in Theorem 5.9 to characterise $\text{con}(a, b)$ — two elements $u, v$ are in $\text{con}(a, b)$ iff there's a weaving polynomial connecting them.
- The proof technique generalises beyond lattices to any congruence-permutable variety.

"Completely join prime" vs "join prime" vs "join irreducible":
- Join irreducible (Ch 2): $q = r \vee s \Rightarrow q = r$ or $q = s$.
- Join prime: $q \le r \vee s \Rightarrow q \le r$ or $q \le s$.
- Completely join prime: same with arbitrary joins.
- In general: completely join prime ⟹ join prime ⟹ join irreducible.
- In FINITE DISTRIBUTIVE lattices (Theorems 5.10–5.12): all three coincide (and are also the elements of the dual poset of the Birkhoff representation).

"CLP — congruence lattice problem":
- Question (Dilworth 1940s): is every distributive algebraic lattice isomorphic to $\textbf{Con}\,\mathcal{L}$ for some $\mathcal{L}$?
- Pudlák 1985: yes for countable.
- Wehrung 2005-2007: NO in general — counterexample of cardinality $\aleph_{\omega+1}$.
- Růžička 2008: optimal counterexample of cardinality $\aleph_2$.
- Major resolution of a 60-year open problem.

### Nation Chapter 6 — Free Lattices — terms introduced new

generation $\text{Sg}(X) = \mathcal{L}$ · freely generated by $X$ (conditions I, II, III) · free lattice $\text{FL}(X)$ · $\text{FL}(n)$ for $|X| = n$ · word algebra $W(X)$ (absolutely free algebra) · $\Lambda$ (lattice-yielding congruences on $W(X)$) · $\lambda = \bigwedge \Lambda$ · the three Basic Principles of universal algebra (First Iso, lifting lemma, subdirect product) · variety / equational class / nontrivial variety · Birkhoff's HSP theorem (1935) · Whitman's condition $(W)$ · Theorem 6.2 (six conditions characterising $\text{FL}(X)$, Whitman 1941) · Skolem 1920 priority · Day's interval doubling construction $\mathcal{L}[I]$ (Alan Day 1970) · the natural map $\kappa : \mathcal{L}[I] \twoheadrightarrow \mathcal{L}$ · word problem · word-problem algorithm · Whitman's recursive reduction · Theorem 6.3 (free generation characterisation: generated by $X$ + $(W)$ + completely join/meet prime) · refinement $A \ll B$ · dual refinement $C \gg D$ · Lemma 6.4 (minimal-length term properties) · Lemma 6.5 (refinement quasiorder) · Lemma 6.6 (refinement chain) · Theorem 6.7 (canonical form unique up to associativity/commutativity) · canonical form · canonical joinands · canonical meetands · semidistributive laws $(\text{SD}_\vee)$ and $(\text{SD}_\wedge)$ · Theorem 6.8 (Jónsson 1961: free lattices are semidistributive) · Theorem 6.9 (Nation 1982: finite lattice embeds in free lattice $\iff$ $(W)$ + $\text{SD}_\vee$ + $\text{SD}_\wedge$) · Jónsson's conjecture · Theorem 6.10 (countable posets in $\text{FL}(3)$, Crawley-Dean 1959; chains countable, Jónsson 1961; dimension bound, Nation-Schmerl 1990) · Theorem 6.11 ($\text{FL}(X)$ weakly atomic for finite $X$) · splitting lattices · bounded homomorphic image · congruence normality · Free Lattices monograph (Freese-Ježek-Nation 1995, AMS Surveys 42) · finitely-presented lattices · projective lattices.

### Nation Ch 6 — terms recapped from Chs 1-5

lattice · $\vee$, $\wedge$ · sublattice · proper sublattice · subalgebra closure operator $\text{Sg}$ (Ch 3) · lattice morphism · embedding · 2-element lattice $\mathbf{2}$ · $\mathcal{N}_5$, $\mathcal{M}_3$ · modular lattice · distributive lattice · congruence relation · $\textbf{Con}\,\mathcal{A}$ · principal congruence · First Isomorphism Theorem (Theorem 5.1) · Second Iso / Correspondence Theorem (Theorem 5.4) · subdirect representation Theorem 5.5 · subdirectly irreducible · Birkhoff subdirect 1944 · interval $u/v$ · cover relation $\prec$ · weakly atomic · strongly atomic · join irreducible · $J(\mathcal{L})$ · meet irreducible · $M(\mathcal{L})$ · completely join prime · join prime · meet prime · partition lattice $\textbf{Eq}\,X$ · Whitman's representation theorem (Theorem 4.1, embedding into $\textbf{Eq}\,X$).

### Nation Ch 6 — deep-dive additions

The Skolem 1920 priority and the late-1980s rediscovery (Cosmadakis, Freese, Burris): Skolem solved the word problem for free lattices and finitely-presented lattices in his 1920 paper on the Löwenheim-Skolem theorem; the solution was forgotten by the time lattice theory awoke in the 1930s; Cosmadakis and (independently) Freese rediscovered the polynomial-time algorithm in the late 1980s; Burris's 1995 paper documented the rediscovery and proved efficiency. Day's doubling construction lineage (1970-2017+): from the original interval doubling for proving $(W)$, through splitting-lattice work (1977), bounded-homomorphic-image characterisation (1979), convex-set doubling for generalised semidistributivity (1989), congruence normality (1994), to all-or-nothing inflation (Adaricheva-Nation 2017). The semidistributive-lattice modern theory: convex geometries (Edelman-Jamison 1980), Adaricheva-Gorbunov-Tumanov 2003 (SD lattices = quasi-varieties of convex geometries), Cambrian lattices (Reading 2007), the fundamental theorem of finite semidistributive lattices (Reading-Speyer-Thomas 2019).

### Nation Ch 6 — terminology traps

"Generation" vs "free generation":
- Generation: $\text{Sg}(X) = \mathcal{L}$, i.e., no proper sublattice contains $X$.
- Free generation: condition (III) demanding extension property — every $h_0 : X \to L$ extends to a homomorphism. Strictly stronger.
- A lattice can be generated by a small set without being freely generated. The free lattice on $X$ is the "biggest" lattice generated by $X$ in the variety of all lattices.

"Word algebra" $W(X)$ vs "free lattice" $\text{FL}(X)$:
- $W(X)$ is the absolutely free algebra: no equations imposed, two terms equal iff identical strings.
- $\text{FL}(X) = W(X)/\lambda$ where $\lambda$ identifies pairs that all lattices identify.
- $W(X)$ is huge and unstructured; $\text{FL}(X)$ is the universal lattice quotient.

"$(W)$" vs Whitman's representation theorem:
- $(W)$ — Whitman's condition (this chapter, Theorem 6.2(6)): $p_1 \wedge p_2 \le q_1 \vee q_2$ implies one of four trivial cases.
- Whitman's representation theorem (Ch 4, Theorem 4.1): every lattice embeds in $\textbf{Eq}\,X$.
- Same author (Philip M. Whitman, 1941 + 1946); different theorems.

"Doubling" overloads:
- Interval doubling $\mathcal{L}[I]$ (this chapter): $I = u/v$ replaced by $I \times \mathbf{2}$.
- Doubling of convex sets (Day's later work): generalisation to convex subsets of $\mathcal{L}$.
- All-or-nothing inflation (Adaricheva-Nation): generalisation along arbitrary subsets.
- All preserve lattice axioms outside the doubled region; differ in how they handle boundaries.

"Refinement" $A \ll B$ vs subset:
- $A \ll B$: every $a \in A$ has $b \in B$ with $a \le b$.
- $A \subseteq B$: every $a \in A$ is in $B$.
- $A \subseteq B \Rightarrow A \ll B$ (Lemma 6.5(3)). Converse fails: $\{1\} \ll \{2\}$ in the chain $1 < 2$, but $\{1\} \not\subseteq \{2\}$.
- Note: $A \ll B$ and $B \gg A$ are NOT the same (the quantifier $\le$ vs $\ge$ direction differs).

"Canonical form" — three meanings in the chapter:
- Of a term in $W(X)$: the minimal-length representative.
- Of an element $w \in \text{FL}(X)$: the canonical form of any term representing $w$.
- Of a join/meet decomposition: $w = \bigvee w_i$ canonically, where the $w_i$ are the canonical joinands.
- All three are unique up to associativity and commutativity (Theorem 6.7).

"$\text{SD}_\vee$" vs "distributive":
- $\text{SD}_\vee$: $a \vee b = a \vee c = u \Rightarrow u = a \vee (b \wedge c)$. A QUASI-IDENTITY (implication of equations).
- Distributive: $a \vee (b \wedge c) = (a \vee b) \wedge (a \vee c)$. An IDENTITY (equation).
- Distributive ⟹ $\text{SD}_\vee$ (just specialise to $b \vee a = c \vee a$). Strict containment: $\mathcal{N}_5$, $\mathcal{M}_3$ both fail $\text{SD}_\vee$, but distributivity fails much more often.
- Free lattices: satisfy $\text{SD}_\vee$, $\text{SD}_\wedge$ — but NOT distributive (they contain non-distributive sublattices).

"Variety" vs "equational class":
- Same concept. Variety = the class of all algebras of fixed signature satisfying a fixed set of equations.
- Birkhoff's HSP theorem (1935): variety ⟺ closed under homomorphic images, subalgebras, products.
- Lattices form a variety; modular lattices form a sub-variety; distributive lattices form a sub-sub-variety. Heyting algebras and Boolean algebras are sub-varieties of distributive lattices with extra operations.

"Whitman 1941" vs "Skolem 1920":
- Skolem 1920 solved the word problem for free lattices (and finitely-presented lattices) as part of his Löwenheim-Skolem paper. Forgotten.
- Whitman 1941 (Annals of Math 42, 325–330) gave the modern reference solution: six conditions characterising $\text{FL}(X)$, including $(W)$. The standard citation.
- The two are independent solutions; Skolem's was first but unrecognised.

"FL(2) vs FL(3)":
- $\text{FL}(2)$: 4 elements. The diamond shape minus center.
- $\text{FL}(3)$: INFINITE. Has elements like $x \vee (y \wedge z)$, $(x \vee y) \wedge z$, etc., all distinct.
- Phase transition at $n = 3$: jump from finite to infinite.

### Nation Chapter 7 — Varieties of Lattices — terms introduced new

lattice equation $p \approx q$ · $\mathcal{L}$ satisfies $\Sigma$ · variety / equational class · the variety $\mathbf{L}$ of all lattices · the variety $\mathbf{M}$ of modular lattices · the variety $\mathbf{D}$ of distributive lattices · the trivial variety $\mathbf{T}$ · $\mathbf{K}$-freely generated · $\mathcal{F}_\mathbf{K}(X)$ relatively-free lattice in $\mathbf{K}$ on $X$ · relatively free · $\mathcal{F}_\mathbf{D}(X) = 2^{2^X}$ · Dedekind 1900 · $\mathcal{F}_\mathbf{M}(3) = $ 28 elements · Birkhoff's HSP theorem (Theorem 7.1, 1935) · Sublemma · Freese 1980 (word problem for $\mathcal{F}_\mathbf{M}(5)$ unsolvable) · Christian Herrmann 1982 ($\mathcal{F}_\mathbf{M}(4)$) · endomorphism · semigroup $\textbf{End}\,\mathcal{L}$ · fully invariant congruence · Theorem 7.2 (relatively free quotient $\iff$ fully invariant) · the lattice $\Lambda$ of all lattice varieties · Theorem 7.3 ($\Lambda$ dually isomorphic to fully invariant congruences on $\text{FL}(\omega)$; dually algebraic; finitely-based varieties = dually compact) · finitely based variety · HSP closure operator · the operators $H, S, P$ (with composition rules $PS \subseteq SP$, $PH \subseteq HP$, $SH \subseteq HS$) · variety generated by a class · Lemma 7.4 (varieties determined by SIs) · filter (dual ideal) · principal filter $\uparrow x$ · nonprincipal filter · cofinite filter · ultrafilter · maximal proper filter · congruence $\equiv_F$ · Lemma 7.5 (5 properties of filters / ultrafilters) · reduced product · ultraproduct $\prod \mathcal{L}_i / \equiv_U$ · first-order language for lattices · alphabet $X$, equations, AND/OR/NOT, quantifiers $\forall \exists$ · well-formed formula (wff) · models · $(\mathcal{L}, h) \models \varphi$ · variables that occur freely · first-order sentence · NOT first-order: finite, ACC, finite width, subdirectly irreducible · Theorem 7.6 · Łoś 1955 · the operator $P_u$ · $P_u(\mathbf{K})$ ultraproduct class · $\text{HSP}_u(\mathbf{K})$ · Theorem 7.7 (Jónsson's Lemma 1967) · Lemma 7.8 (filter restriction) · Theorem 7.9 (SI in HSP of finite-collection-of-finite-lattices is in HS) · Theorem 7.10 (McKenzie 1970, finite lattice generates finitely-based variety) · Baker 1977 (congruence-distributive umbrella theorem) · Oates-Powell 1964 (groups) · Kruse 1973 (rings) · Theorem 7.11 ($(\mathbf{V} \vee \mathbf{W})_{si} = \mathbf{V}_{si} \cup \mathbf{W}_{si}$) · corollary ($\Lambda$ distributive) · the ideal lattice $\mathcal{I}(\mathcal{L})$ · Birkhoff 1934 ($\mathcal{I}(\mathcal{L}) \in \text{HSP}(\mathcal{L})$) · Theorem 7.12 (Baker-Hales 1974: $\mathcal{I}(\mathcal{L}) \in \text{HSP}_u(\mathcal{L})$) · Jipsen-Rose <em>Varieties of Lattices</em> (LNM 1533, 1991) · McNulty 1985 · Willard 2004.

### Nation Ch 7 — terms recapped from Chs 1-6

lattice · sublattice · lattice morphism · embedding · 2-element lattice $\mathbf{2}$ · $\mathcal{N}_5$ · $\mathcal{M}_3$ · $\mathcal{M}_5$ · modular law · distributive law · congruence · $\textbf{Con}\,\mathcal{L}$ · principal congruence · First Isomorphism Theorem · Second Iso · Birkhoff subdirect representation (Theorem 5.5) · subdirectly irreducible (SI) · monolith · congruence distributive · Funayama-Nakayama theorem ($\textbf{Con}\,\mathcal{L}$ always distributive, Ch 5) · algebraic lattice · compact element · partition lattice $\textbf{Eq}\,X$ · word algebra $W(X)$ · free lattice $\text{FL}(X)$ · $\text{FL}(\omega)$ countably-generated free lattice · Whitman's condition $(W)$ · semidistributive laws $\text{SD}_\vee$, $\text{SD}_\wedge$ · canonical form · refinement $\ll$ · ideal · ACC · width · weakly atomic · strongly atomic · atom · coatom.

### Nation Ch 7 — deep-dive additions

The lattice $\Lambda$ of all lattice varieties (uncountably infinite, distributive, dually algebraic; with sublattice structure mapped by Jónsson, McKenzie, Rose, Jipsen; standard reference: Jipsen-Rose, <em>Varieties of Lattices</em>, LNM 1533, Springer 1991). Łoś's theorem and its model-theoretic descendants (compactness, Keisler-Shelah ultrapower characterisation, nonstandard analysis, Frayne-Morel-Scott reduced products 1962). The undecidability story for free modular lattices (Dedekind 1900 → Freese 1980 → Herrmann 1982 → ongoing): contrast with the polynomial-time word problem for $\text{FL}(X)$ (Skolem 1920 / Whitman 1941). The finite-basis theorem lineage (Oates-Powell 1964 → McKenzie 1970 → Kruse 1973 → Baker 1977 → McKenzie 1987 → McNulty 1985 counter-examples → Willard 2004 survey): pattern is "congruence-distributive ⟹ finite-basis," and lattices are always congruence-distributive (Funayama-Nakayama).

### Nation Ch 7 — terminology traps

"Variety" vs "equational class" vs "quasi-variety":
- Variety = equational class. Same concept. Defined by equations.
- Quasi-variety: defined by quasi-equations (universal conjunction of equations $\Rightarrow$ equation). Closed under H, S, $P_u$ (NOT P).
- Universal class: defined by universal sentences. Closed under S, $P_u$.
- Hierarchy: variety ⊂ quasi-variety ⊂ universal class ⊂ axiomatisable class.

"Theorem 7.1 vs Birkhoff's HSP theorem":
- Same theorem, lattice version vs general version.
- Birkhoff 1935 proved it for arbitrary algebras of any signature.
- Lattices are a special case where the signature is $\{\vee, \wedge\}$.

"Fully invariant" vs "characteristic":
- Fully invariant congruence: stable under all endomorphisms.
- "Characteristic" subgroup (group theory): stable under all automorphisms.
- For groups, these differ: characteristic is weaker than fully invariant.
- For lattices, only "fully invariant" is in standard use.

"$\Lambda$ dually algebraic":
- $\Lambda$ is dually algebraic, NOT algebraic. The duality matters.
- Dually algebraic: every element is a meet of completely-meet-irreducibles (= dually compact).
- Algebraic: every element is a join of compact elements.
- $\Lambda$'s structure: small at top ($\mathbf{L}$), with finite chains of subvarieties below; structure dualised to congruence lattices.

"Reduced product" vs "ultraproduct":
- Reduced product $\prod \mathcal{L}_i / \equiv_F$ for filter $F$.
- Ultraproduct $\prod \mathcal{L}_i / \equiv_U$ for ultrafilter $U$ — special case where $F$ is maximal.
- The reduced product is a subdirect product of ultraproducts (Exercise 7.5).
- Ultraproducts are model-theoretically well-behaved (Łoś); reduced products in general are not.

"First-order vs higher-order":
- First-order: quantification over individual lattice elements ($\forall x \in L$).
- Higher-order: quantification over subsets, congruences, homomorphisms.
- "Subdirectly irreducible" (need to talk about congruences) is NOT first-order.
- "Has $\le 7$ elements" IS first-order (just enumerate the cases).
- The boundary is sharp: anything finitistic is first-order; anything genuinely infinitary is not.

"Łoś's theorem and AC":
- Łoś's theorem assumes the existence of nonprincipal ultrafilters on infinite sets.
- This requires the axiom of choice (Zorn's Lemma).
- In ZF without choice: Łoś's theorem may fail.
- In ZFC: Łoś's theorem is straightforward and the foundation of model theory.

"Jónsson's Lemma" vs "Birkhoff's HSP":
- Birkhoff: variety = HSP of generators.
- Jónsson: SUBDIRECTLY IRREDUCIBLE in variety = inside HSP_u of generators.
- Jónsson is a sharper localisation: from arbitrary products to ultraproducts.
- Crucially uses congruence-distributivity.

"Finitely based" vs "finitely generated":
- Finitely based: variety presented by finitely many equations.
- Finitely generated: variety = HSP(K) for finite K.
- McKenzie 1970: finite lattice ⟹ finitely generated ⟹ finitely based (lattices are nice).
- For groups (Oates-Powell), rings (Kruse), all congruence-distributive (Baker): same picture.
- For pathological algebras: finitely generated but NOT finitely based (McNulty 1985).

"Word problem for free modular lattices":
- $\mathcal{F}_M(3)$ has 28 elements (Dedekind 1900) — finite, decidable.
- $\mathcal{F}_M(4)$ unsolvable (Herrmann 1982).
- $\mathcal{F}_M(5)$ unsolvable (Freese 1980).
- Contrast with $\text{FL}(X)$: word problem polynomial-time (Skolem / Whitman / Cosmadakis-Freese / Burris).
- Adding the modular law breaks decidability beyond 3 generators.

### Nation Chapter 8 — Distributive Lattices — terms introduced new

locally finite variety · Theorem 8.1 (HSP of finite is locally finite, $|\mathcal{F}_\mathbf{V}(n)| \le |L|^{|L|^n}$) · Lemma 8.2 (three equivalent forms of distributivity, including the self-dual median identity (3)) · the median identity / median element · proper ideal · proper filter · Lemma 8.3 (homs to $\mathbf{2}$ ↔ ideal/filter partition) · prime ideal · prime filter · complement (of ideal) · the equivalence "ideal complement is filter ⟺ ideal prime ⟺ filter prime" · Theorem 8.4 (Birkhoff Prime Ideal Theorem) · Zorn's-Lemma maximality argument · the four-way distributive expansion $(x \wedge m) \vee (y \wedge n) = (x \vee y) \wedge (x \vee n) \wedge (m \vee y) \wedge (m \vee n)$ · corollary: $\mathbf{2}$ is the only SI distributive lattice · $\mathbf{D} = \text{HSP}(\mathbf{2})$ · corollary: $\mathbf{D}$ is locally finite · Theorem 8.5 (set representation $\mathcal{D} \hookrightarrow \mathfrak{P}(S)$) · prime-filter representation · join prime element · Theorem 8.6 (Birkhoff finite representation, 1933: $\mathcal{D} \cong \mathcal{O}(J(\mathcal{D}))$) · the duality "finite distributive lattices ⟺ finite posets" · order-ideal lattice $\mathcal{O}(\mathcal{P})$ · unique irredundant join decomposition · free distributive lattice $\mathcal{F}_\mathbf{D}(n)$ · construction of $\mathcal{F}_\mathbf{D}(X)$ as $\mathcal{O}$ of the antichain-poset on subsets · Dedekind 1900 ($|\mathcal{F}_\mathbf{D}(3)| = 18$, $|\mathcal{F}_\mathbf{D}(4)| = 166$) · Dedekind's problem · Dedekind number $M(n)$ · Church 1940 (M(5)) · Ward 1946 (M(6)) · Wiedemann 1991 (M(8)) · Christian Jäkel 2023 (M(9), TU Dresden, GPU) · Van Hirtum-De Causmaecker-Goemaere-Kenter-Riebler-Lass-Plessl 2023 (M(9), Paderborn FPGA) · Kleitman 1969 asymptotic $\log_2 M(n) \sim \binom{n}{\lfloor n/2 \rfloor}$ · completely join prime · Theorem 8.7 (Tarski-Papert 1959) · counter-example $[0, 1] \subseteq \mathbb{R}$ · complement (of element) · complemented lattice · Boolean algebra · the lattice $\mathfrak{P}(X)$ · finite Boolean = $\mathfrak{P}(\text{atoms})$ · free Boolean algebra $\text{FBA}(X)$ · $|\text{FBA}(X)| = 2^{2^{|X|}}$ for finite $X$ · $\text{FBA}(\aleph_0)$ unique countable atomless Boolean algebra · clopen subsets · Stone topology · Theorem 8.8 (Stone Representation 1936) · Sublemma A · Sublemma B · Stone space (compact, Hausdorff, totally disconnected) · Hilary Priestley duality (1970) · ordered Stone spaces · Esakia duality (1974) · Davey-Priestley book · Peirce 1880 · Huntington 1904 · Huntington's conjecture · Theorem 8.9 (Birkhoff-Ward 1939) · uniquely complemented lattice · Bandelt-Padmanabhan 1979 (weak atomicity) · Bandelt 1981 / Salii 1972, 1979 (upper continuity) · Salii's monograph · Dilworth 1945 (every lattice embeds in a uniquely complemented one) · Lakser 1968 simplification · Adams 1990 · Grätzer 2007 · Balbes-Dwinger 1974 monograph.

### Nation Ch 8 — terms recapped from Chs 1-7

posets · $\mathcal{O}(\mathcal{P})$ order ideals (Ch 1) · principal ideal $\downarrow x$ · principal filter $\uparrow x$ · lattice · sublattice · embedding · the 2-element lattice $\mathbf{2}$ · distributive law · modular law · $\mathcal{N}_5$ · $\mathcal{M}_3$ · congruence · $\textbf{Con}\,\mathcal{D}$ · subdirectly irreducible (SI) · Birkhoff subdirect representation (Theorem 5.5) · Funayama-Nakayama Theorem 5.8 · join irreducible · $J(\mathcal{L})$ · meet irreducible · $M(\mathcal{L})$ · free lattice $\text{FL}(X)$ · variety · $\mathbf{D}$ as variety of distributive lattices · $\Lambda$ · HSP closure · Łoś's theorem · Jónsson's Lemma · McKenzie's finite-basis theorem · McKenzie 1970 · filter · ultrafilter · principal filter · cofinite filter · $\textbf{End}\,\mathcal{L}$ · $\mathcal{F}_\mathbf{V}(X)$ relatively free · Birkhoff HSP theorem (Theorem 7.1) · Birkhoff 1934 · the operator $H, S, P$ · ideal lattice $\mathcal{I}(\mathcal{L})$ · complete lattice · algebraic lattice · compact element · upper continuous · weakly atomic · strongly atomic · atom · coatom.

### Nation Ch 8 — deep-dive additions

Birkhoff's representation duality and its descendants (Stone 1936 for Boolean, Priestley 1970 for distributive, Esakia 1974 for Heyting). The 126-year saga of Dedekind's problem: Dedekind 1897 ($M(0)$ through $M(4)$); Church 1940 ($M(5)$), Ward 1946 ($M(6)$), Church 1965 ($M(7)$), Wiedemann 1991 ($M(8)$); Jäkel 2023 (5311 GPU-hours on Nvidia A100s) and independently Van Hirtum et al. (FPGAs at Paderborn's Noctua 2 supercomputer) computed $M(9) = 286{,}386{,}577{,}668{,}298{,}411{,}128{,}469{,}151{,}667{,}598{,}498{,}812{,}366$. Korshunov 1981 closed-form asymptotic; Kleitman 1969 logarithmic asymptotic. Huntington's conjecture and Dilworth 1945's stunning disproof: Peirce 1880 → Huntington 1904 → Birkhoff-Ward 1939 (atomic case) → Dilworth 1945 (every lattice embeds in a uniquely complemented one) → subsequent finiteness conditions (Bandelt-Padmanabhan, Salii) that DO force distributivity. The structural moral: algebraic uniqueness ≠ structural rigidity without completeness conditions. Grätzer 2007 names this one of "two problems that shaped a century of lattice theory."

### Nation Ch 8 — terminology traps

"Distributive" — three equivalent forms (Lemma 8.2):
- (1) $x \wedge (y \vee z) = (x \wedge y) \vee (x \wedge z)$ — the standard left-distributive form.
- (2) $x \vee (y \wedge z) = (x \vee y) \wedge (x \vee z)$ — the dual right-distributive form.
- (3) $(x \vee y) \wedge (x \vee z) \wedge (y \vee z) = (x \wedge y) \vee (x \wedge z) \vee (y \wedge z)$ — the self-dual median identity.
- All three are equivalent. Most textbooks introduce only (1); Nation's choice to make (3) prominent reveals the median structure.

"Prime ideal" vs "maximal ideal":
- Prime: $x \wedge y \in I \Rightarrow x \in I$ or $y \in I$.
- Maximal: no proper ideal strictly contains $I$.
- In distributive lattices: every maximal ideal is prime (Exercise 8.2(a)).
- In Boolean algebras: prime = maximal = atom-supported.
- In general lattices: distinct concepts.

"Join prime" vs "join irreducible":
- Join prime: $p \le x \vee y \Rightarrow p \le x$ or $p \le y$.
- Join irreducible: $p = r \vee s \Rightarrow p = r$ or $p = s$.
- In distributive lattices: equivalent (Theorem 8.6(1)).
- In general: join-prime ⟹ join-irreducible (strict in $\mathcal{N}_5$, $\mathcal{M}_3$).

"Completely join prime" vs "join prime":
- Join prime: works for FINITE joins.
- Completely join prime: works for arbitrary (infinite) joins.
- Theorem 8.7 (Tarski-Papert) requires completely-join-prime separation.
- In $[0, 1] \subseteq \mathbb{R}$: every element $p$ has $p = \sup\{q < p\}$ but $p \not\le q$ for any single $q$ — fails complete-join-primeness.

"Complement" — element vs ideal:
- Element complement: $a \wedge b = 0$ AND $a \vee b = 1$ (in lattice with 0, 1).
- Ideal complement: set-theoretic $L - I$. Becomes a filter iff $I$ is prime.
- Different meanings; context determines.

"Boolean algebra" — three formulations:
- Complemented distributive lattice (with 0, 1).
- Algebra $\langle B, \wedge, \vee, 0, 1, ^c \rangle$ in the variety of Boolean algebras.
- $\mathfrak{P}(X)$ for finite $X$ (atomic case); clopen sets of Stone space (general case).
- All three are equivalent; perspective shifts depending on context.

"Stone duality" — categorical:
- $\textbf{BoolAlg}^{\text{op}} \simeq \textbf{Stone}$.
- Boolean algebra $B$ ↔ Stone space $S(B)$ = ultrafilters with the Stone topology.
- Element $b \in B$ ↔ clopen set $V_b = \{F \in S(B) : b \in F\}$.
- Generalises to Priestley duality (distributive lattices), Esakia duality (Heyting algebras), spectral duality (commutative rings).

"Uniquely complemented" vs "Boolean":
- Uniquely complemented: every element has exactly one complement.
- Boolean: complemented + distributive.
- Boolean ⟹ uniquely complemented (in distributive case, complement is unique).
- Reverse implication: Huntington's conjecture (1904) — DISPROVED by Dilworth 1945.
- Theorem 8.9: uniquely complemented + complete + atomic ⟹ Boolean.

"Free Boolean FBA(X)":
- Finite X: $|\text{FBA}(X)| = 2^{2^{|X|}}$ with $2^{|X|}$ atoms (the minterms).
- Infinite X: FBA(X) has NO atoms.
- $\text{FBA}(\aleph_0)$: unique countable atomless Boolean algebra (its Stone dual is the Cantor set).

"Dedekind's problem":
- The problem: count $|\mathcal{F}_\mathbf{D}(n)|$ — equivalently, antichains in $\{0,1\}^n$, or monotone Boolean functions on $n$ vars.
- Sequence M(n) (OEIS A000372): 2, 3, 6, 20, 168, 7581, 7,828,354, 2,414,682,040,998, 56,130,437,228,687,557,907,788, 286,386,577,668,298,411,128,469,151,667,598,498,812,366, ...
- $M(9)$ computed in April 2023 by Jäkel (TU Dresden) and independently Van Hirtum et al. (KU Leuven/Paderborn).
- $M(10)$ remains computationally infeasible.
- Asymptotic: $\log_2 M(n) \sim \binom{n}{\lfloor n/2 \rfloor}$ (Kleitman 1969).

### Nation Chapter 9 — Modular and Semimodular Lattices — terms introduced new

modular law (recap from Ch 4) · the pentagon $\mathcal{N}_5$ · the diamond $\mathcal{M}_3$ · Theorem 9.1 (Dedekind 1900: modular iff no $\mathcal{N}_5$ sublattice) · Theorem 9.2 (Birkhoff: modular distributive iff no $\mathcal{M}_3$ sublattice) · forbidden-sublattice characterisation of distributivity · the bottom of the variety lattice $\Lambda$ · cover counts in $\Lambda$ · Grätzer-Jónsson 1966-68 (HSP($\mathcal{M}_3$) has 2 additional covers) · Jónsson-Rival 1979 (HSP($\mathcal{N}_5$) has exactly 15 other covers) · Nation 1996 finite height counterexample · the natural maps $\mu_a$ (meet with $a$) and $\nu_b$ (join with $b$) · the transposed intervals $(a \vee b)/b$ and $a/(a \wedge b)$ · Theorem 9.3 (Dedekind transposition isomorphism in modular lattice) · the cover-preservation corollary ($a \succ a \wedge b$ iff $a \vee b \succ b$ in modular) · semimodular (= upper semimodular) lattice · lower semimodular lattice · Crawley-Dilworth Theorem 3.7 (strongly atomic algebraic + both ⟹ modular) · Theorem 9.4 (Dedekind-style chain-length theorem for semimodular) · the dimension function $\delta$ · Theorem 9.5 (semimodular dimension properties (1)-(4) + converse) · the submodular inequality $\delta(x \vee y) + \delta(x \wedge y) \le \delta(x) + \delta(y)$ · Theorem 9.6 (modular case: equality, drop (3)) · semimodular construction trick (collapse upper portion of finite-dim modular) · quotient transposition (a/b transposes up/down to c/d) · projectivity (smallest equivalence relation containing transposes) · Theorem 9.7 (Grätzer-Nation 2011, Algebra Universalis 64: maximal chains in finite-length semimodular have projective prime intervals via permutation) · chief series (maximal chain in $\mathcal{N}(\mathcal{G})$) · subnormal subgroup $H \triangleleft\triangleleft \mathcal{G}$ · the lattice $\mathcal{SN}(\mathcal{G})$ of subnormal subgroups · Theorem 9.8 (Wielandt 1939, Math. Zeit. 45: $\mathcal{SN}(\mathcal{G})$ lower semimodular sublattice of Sub G) · composition series (maximal chain in $\mathcal{SN}(\mathcal{G})$) · the corollary: Jordan-Hölder theorem for groups · Jordan 1870 · Hölder 1889 · Schreier 1928 · Zassenhaus 1934 · Wielandt 1939 · Burnside · Grätzer-Nation 2011 · Czedli-Schmidt 2011 (uniqueness) · the Stern monograph 1999 · finite decomposition · irredundant decomposition · Theorem 9.9 (Kurosh-Ore Replacement Theorem in modular) · Theorem 9.10 (simultaneous exchange) · Theorem 9.11 (algebraic modular case with completely meet-irreducibles) · Crawley-Dilworth 1973 · McKenzie-McNulty-Taylor congruence-modular varieties · $J_k(\mathcal{L})$ (elements covering exactly $k$) · $M_k(\mathcal{L})$ (elements covered by exactly $k$) · Theorem 9.12 (Dilworth 1954, Ann. of Math. 60: $|J_k| = |M_k|$ in finite modular) · Joseph Kung 1985 (matchings and Radon transforms) · Reuter 1987 · the explicit Kung-Reuter bijection $m : J(\mathcal{L}) \cup \{0\} \to M(\mathcal{L}) \cup \{1\}$ with $x \le m(x)$.

### Nation Ch 9 — terms recapped from Chs 1-8

posets · cover relation $\prec$ · chain · finite-length lattice (Ch 1) · lattice · sublattice · embedding · the modular law · the distributive law · $\mathcal{N}_5$ pentagon · $\mathcal{M}_3$ diamond (Ch 2) · algebraic lattice · compactness · weakly atomic · strongly atomic (Ch 3) · equivalence-relation lattice $\textbf{Eq}\,X$ — semimodular but nonmodular for $|X| \ge 4$ (Ch 4) · congruence · $\textbf{Con}\,\mathcal{L}$ · principal congruence · subdirectly irreducible (SI) · Birkhoff subdirect representation (Theorem 5.5) · Funayama-Nakayama theorem ($\textbf{Con}\,\mathcal{L}$ always distributive, Ch 5) · join irreducible $J(\mathcal{L})$ · meet irreducible $M(\mathcal{L})$ · free lattice $\text{FL}(X)$ · free modular lattice $\mathcal{F}_M(X)$ · $|\mathcal{F}_M(3)| = 28$ (Dedekind 1900) · word problem unsolvable for $\mathcal{F}_M(n), n \ge 4$ (Freese 1980, Herrmann 1982) · Whitman's $(W)$ · canonical form (Ch 6) · variety $\mathbf{M}$ of modular lattices · $\Lambda$ · variety $\mathbf{D}$ of distributive lattices · HSP closure operator · Jónsson's Lemma · McKenzie's finite-basis theorem · subdirectly irreducible analysis (Ch 7) · distributive lattice = HSP(2) · Birkhoff finite representation $\mathcal{D} \cong \mathcal{O}(J(\mathcal{D}))$ · Stone duality (Ch 8) · normal subgroup lattice $\mathcal{N}(\mathcal{G})$ — modular for any group · the 2-element chain $\mathbf{2}$.

### Nation Ch 9 — deep-dive additions

The Jordan-Hölder theorem lineage (Jordan 1870 → Hölder 1889 → Dedekind 1900 → Schreier 1928 → Zassenhaus 1934 → Wielandt 1939 → Burnside, Birkhoff (1963 ed.) → Grätzer-Nation 2011 → Czedli-Schmidt 2011): the 141-year arc of one of group theory's foundational structural results, with the lattice-theoretic abstraction repeatedly clarifying the algebraic content. Theorem 9.7 (Grätzer-Nation 2011) is the modern "projectivity" formulation; Czedli-Schmidt 2011 added uniqueness — there is a UNIQUE bijection between prime intervals (not just "exists permutation"). The bottom of the variety lattice $\Lambda$ — covers and the cover-counting program (Grätzer-Jónsson 1966-68; Jónsson-Rival 1979 with the celebrated EXACTLY 15 other covers of HSP($\mathcal{N}_5$); Nation 1996 finite height counterexample). The Kurosh-Ore Replacement Theorem (Theorem 9.9) and its descendants: simultaneous exchange (Theorem 9.10, Crawley-Dilworth 1973), algebraic case (Theorem 9.11), and Dilworth's 1954 covering bijection (Theorem 9.12) — strengthened to the Kung-Reuter bijection (Kung 1985, Reuter 1987) of explicit $m : J(\mathcal{L}) \cup \{0\} \to M(\mathcal{L}) \cup \{1\}$ with $x \le m(x)$. Standard reference: Manfred Stern, <em>Semimodular Lattices: Theory and Applications</em> (CUP 1999).

### Nation Ch 9 — terminology traps

"Modular" vs "semimodular":
- Modular law: $x \ge y \Rightarrow x \wedge (y \vee z) = y \vee (x \wedge z)$. EQUATIONAL (variety condition).
- Semimodular (upper): $a \succ a \wedge b \Rightarrow a \vee b \succ b$. NOT equational (uses cover relation, not first-order in the lattice signature without atoms).
- Strict containment: modular ⟹ semimodular (and lower semimodular). Converse fails ($\textbf{Eq}\,X$ for $|X| \ge 4$).
- Strongly atomic algebraic + both upper AND lower semimodular ⟹ modular (Crawley-Dilworth 3.7).

"Pentagon $\mathcal{N}_5$" vs "diamond $\mathcal{M}_3$":
- $\mathcal{N}_5$: 5 elements, non-modular, $0 < y < x, z, x \vee z = 1$ with $x \wedge z = 0$.
- $\mathcal{M}_3$: 5 elements, modular non-distributive, $0 < a, b, c < 1$ pairwise meets 0, pairwise joins 1.
- Both 5-element. Both subdirectly irreducible.
- Theorem 9.1: modular iff no $\mathcal{N}_5$.
- Theorem 9.2: modular + no $\mathcal{M}_3$ ⟺ distributive.

"$\mu_a$, $\nu_b$" — the natural maps:
- $\mu_a : (a \vee b)/b \to a/(a \wedge b)$, $\mu_a(x) = x \wedge a$.
- $\nu_b : a/(a \wedge b) \to (a \vee b)/b$, $\nu_b(x) = x \vee b$.
- Both order-preserving in any lattice.
- In modular lattice: mutually inverse isomorphisms (Theorem 9.3).
- In semimodular lattice: $\nu_b$ is a join embedding (Exercise 9.6) but not necessarily a meet embedding.

"Transposition" vs "perspectivity" vs "projectivity":
- Transposition (this chapter): $a/b$ transposes up to $c/d$ if $a \vee d = c$ and $a \wedge d = b$.
- Perspectivity (some textbooks): same concept, different name.
- Projectivity (this chapter): smallest equivalence relation containing all transposed pairs.
- "$a/b$ projective to $c/d$" means there's a finite chain of transpositions linking them.

"Chief series" vs "composition series":
- Chief series: maximal chain in $\mathcal{N}(\mathcal{G})$ (normal subgroups).
- Composition series: maximal chain in $\mathcal{SN}(\mathcal{G})$ (subnormal subgroups).
- Both apply Theorem 9.4 (chain-length theorem) since both lattices are modular / lower semimodular.
- Composition series is finer: contains chief series as a subchain.

"Subnormal" vs "normal":
- Normal: $H \triangleleft \mathcal{G}$ — single step.
- Subnormal: $H \triangleleft\triangleleft \mathcal{G}$ — finite chain $H = H_0 \triangleleft H_1 \triangleleft \cdots \triangleleft \mathcal{G}$.
- For finite groups, subnormal subgroups form a lattice (Wielandt 1939); normal subgroups always do (lattice $\mathcal{N}(\mathcal{G})$).

"Kurosh-Ore" vs "Steinitz":
- Steinitz exchange (vector spaces): two bases of finite-dim space have same cardinality, with replacement.
- Kurosh-Ore (modular lattices): two irredundant decompositions of an element have same cardinality, with replacement.
- Both are "exchange theorems" — modular structure abstracts the linear-algebra exchange.

"$|J_k| = |M_k|$" — Dilworth 1954:
- $J_k(\mathcal{L})$ = elements covering exactly $k$ elements.
- $M_k(\mathcal{L})$ = elements covered by exactly $k$ elements.
- For finite modular: $|J_k| = |M_k|$ for every $k \ge 0$.
- $k = 1$: $|J_1| = |M_1|$ — number of join-irreducibles equals number of meet-irreducibles.
- Strengthened by Kung-Reuter to explicit bijection $m : J(\mathcal{L}) \cup \{0\} \to M(\mathcal{L}) \cup \{1\}$ with $x \le m(x)$.

"Variety lattice $\Lambda$ at the bottom":
- $\mathbf{T} \prec \mathbf{D}$ is unique (only one variety covers the trivial).
- $\mathbf{D} \prec \{\text{HSP}(\mathcal{N}_5), \text{HSP}(\mathcal{M}_3)\}$ — exactly two covers.
- HSP($\mathcal{M}_3$) covered by 2+1 = 3 varieties (Grätzer-Jónsson + the join with $\mathcal{N}_5$).
- HSP($\mathcal{N}_5$) covered by 15+1 = 16 varieties (Jónsson-Rival + the join).
- Beyond: structurally intractable (Nation 1996).

### Nation Chapter 10 — Finite Lattices and their Congruence Lattices — terms introduced new

principally chain finite (PCF) lattice (every $\downarrow x$ satisfies ACC + DCC) · the closure-operator approach to congruence theory (McKenzie-Jónsson-Day-Freese-Nation lineage) · refinement $\ll$ on subsets of $L$ (recap: quasiorder, Ch 6) · $q_*$ (unique element with $q \succ q_*$ for completely-join-irreducible $q$) · join expression $a = \bigvee B$ · minimal join expression · join cover $p \le \bigvee A$ · minimal join cover · the binary relation $\underline{D}$ on $J(\mathcal{L})$ (reflexive: $p \,\underline{D}\, p$) · $D$ relation (irreflexive variant) · Lemma 10.1 (3 properties: separation by join-irreducibles, refinement to minimal, $\underline{D}$ via minimal join cover) · the closure operator $\Gamma$ on $J(\mathcal{L})$ ($\Gamma(S) = \{p : p \le \bigvee F$ for finite $F \subseteq S\}$) · $\Gamma$-closed subset · compact $\Gamma$-closed sets · Theorem 10.2 (PCF $\mathcal{L}$ ≅ compact $\Gamma$-closed subsets of $J(\mathcal{L})$) · Theorem 10.3 ($\Gamma$-closed iff order ideal + closed under minimal join covers) · the $\sigma$ map ($\sigma(\theta) = \{p \in J : p \,\theta\, p_*\}$) · Theorem 10.4 ($\sigma$ one-to-one complete lattice homomorphism) · Theorem 10.5 (range characterised by closure under reverse $\underline{D}$) · standard homomorphism · the $\trianglelefteq$ quasiorder (transitive closure of $\underline{D}$) · the $\equiv$ equivalence relation · $Q_\mathcal{L} = (J(\mathcal{L})/\equiv, \trianglelefteq)$ · Corollary: $\textbf{Con}\,\mathcal{L} \cong \mathcal{O}(Q_\mathcal{L})$ · Corollary: SI iff $Q_\mathcal{L}$ has least element · Wehrung 2007 negative for $\aleph_2$+ (recap from Ch 5) · Lemma 10.6 (3 equivalent characterisations of $\mathcal{D} \cong \mathcal{O}(\mathcal{P})$) · completely-join-prime element · Theorem 10.7 (principal congruences $\text{con}(p, p_*)$ are join-irreducible compacts) · Theorem 10.8 (Dilworth 1940s, Grätzer-Schmidt 1962: every $\mathcal{D} \cong \mathcal{O}(\mathcal{P})$ is $\textbf{Con}\,\mathcal{L}$ for some PCF $\mathcal{L}$) · the $J = P^0 \cup P^1$ doubling construction · relatively complemented lattice · Theorem 10.9 (modular OR relatively complemented PCF ⟹ $\underline{D}$ symmetric, $\textbf{Con}\,\mathcal{L}$ Boolean) · simple lattice · direct sum $\sum \mathcal{L}_i$ · Theorem 10.10 (Dilworth 1950, Ann. of Math. 51: relatively complemented PCF = direct sum of simple) · lower bounded homomorphism (McKenzie 1972) · upper bounded homomorphism · $\beta : \mathcal{K} \to \mathcal{L}$ partial map · the McKenzie-Day-Freese-Nation lineage of bounded-homomorphism techniques · Raney 1952 (completely distributive complete lattices) · the completely distributive identity · Tischendorf join-of-atoms embedding · Khalib Benabdallah (compact subgroups of torsion abelian groups).

### Nation Ch 10 — terms recapped from Chs 1-9

posets · ACC, DCC · order ideals $\mathcal{O}(\mathcal{P})$ · principal ideals $\downarrow x$ (Ch 1) · lattices · sublattices · embeddings · distributive law · modular law · $\mathcal{N}_5$, $\mathcal{M}_3$ (Ch 2) · algebraic closure operator · compact element · algebraic lattice (Ch 3) · partition lattice $\textbf{Eq}\,X$ (Ch 4) · congruences · $\textbf{Con}\,\mathcal{L}$ · principal congruence $\text{con}(a, b)$ · subdirectly irreducible · monolith · Birkhoff subdirect representation · Funayama-Nakayama theorem · the congruence lattice problem (CLP) — Dilworth → Wehrung 2007 → Růžička 2008 (Ch 5) · join irreducible $J(\mathcal{L})$ · meet irreducible $M(\mathcal{L})$ · completely join irreducible · refinement $\ll$ (Ch 6) · free lattice $\text{FL}(X)$ · canonical form (Ch 6) · varieties · $\Lambda$ · McKenzie's finite-basis theorem (Ch 7) · finite distributive $\mathcal{D} \cong \mathcal{O}(J(\mathcal{D}))$ Birkhoff representation · Stone duality (Ch 8) · modular lattices · semimodular · Kurosh-Ore replacement · Dilworth 1954 covering bijection (Ch 9) · normal subgroup lattice $\mathcal{N}(\mathcal{G})$ — modular for any group · the 2-element lattice $\mathbf{2}$.

### Nation Ch 10 — deep-dive additions

The closure-operator approach to congruence theory (50-year lineage: Grätzer-Schmidt 1962 → McKenzie 1972 → Jónsson-Nation 1977 → Day 1979 → Freese-Nation 1985 → Nation 1986 → Freese 1989 → Nation 1990 → Freese-Ježek-Nation 1995 monograph). Dilworth's congruence lattice problem (CLP) — the 60-year arc: Dilworth 1944 (oral, finite case positive) → Grätzer-Schmidt 1962 (published proof, finite case) → Pudlák 1985 (countable case positive) → Wehrung 2007 (negative for $\aleph_{\omega+1}$) → Růžička 2008 (optimal $\aleph_2$). Raney 1952 completely distributive lattices and order-ideal characterisation (precursor to Lemma 10.6). McKenzie 1972 introduction of bounded homomorphisms — foundational for the lattice variety analysis program. Standard reference: George Grätzer, <em>The Congruences of a Finite Lattice: A Proof-by-Picture Approach</em> (Birkhäuser, 3rd ed. 2023, arXiv:2104.06539) for finite-CLP techniques; Freese-Ježek-Nation, <em>Free Lattices</em> (AMS Surveys 42, 1995) for the full closure-operator machinery.

### Nation Ch 10 — terminology traps

"PCF" (principally chain finite):
- Definition: every principal ideal $\downarrow x$ satisfies both ACC and DCC.
- Equivalently: every $\downarrow x$ contains no infinite chain.
- All finite lattices are PCF.
- Many infinite lattices too: e.g., compact subgroups of torsion abelian groups (Ex 10.12).
- Generalises "finite" for the closure-operator representation theory.

"Join expression" vs "join cover":
- Join expression of $a$: finite $B$ with $a = \bigvee B$ (equality).
- Join cover of $p$: finite $A$ with $p \le \bigvee A$ (inequality).
- "Minimal" — same condition: irredundant + cannot be properly refined.
- Distinct concepts: a join expression is "exactly $a$"; a join cover is "above $p$."

"$\underline{D}$" vs "$D$":
- $\underline{D}$ (reflexive): $p \,\underline{D}\, p$ for all $p \in J(\mathcal{L})$.
- $D$ (irreflexive variant): defined identically except requiring $p \neq q$.
- Both important; $\underline{D}$ is preferred for describing congruences (where reflexivity is convenient).

"Closure operator $\Gamma$" vs "closure operator on a set":
- $\Gamma$ on $J(\mathcal{L})$: specific to PCF lattices, defined by minimal join covers.
- Generic closure operator on a set $X$ (Ch 3): extensive, monotone, idempotent.
- $\Gamma$ is an algebraic closure operator (finitary) on $J(\mathcal{L})$ — a special case of the Ch 3 framework.

"Theorem 10.2 vs Theorem 8.6 (Birkhoff)":
- Theorem 8.6 (Birkhoff 1933 for finite distributive): $\mathcal{D} \cong \mathcal{O}(J(\mathcal{D}))$.
- Theorem 10.2 (this chapter, for PCF): $\mathcal{L} \cong $ compact $\Gamma$-closed subsets of $J(\mathcal{L})$.
- Generalisation: PCF subsumes finite distributive; $\Gamma$ encodes the additional structure (which join-irreducibles depend on others) lost in moving from distributive to general PCF.

"$Q_\mathcal{L}$":
- Defined as $(J(\mathcal{L})/\equiv, \trianglelefteq)$.
- $\trianglelefteq$ = transitive closure of $\underline{D}$.
- $\equiv$ = "$\trianglelefteq$ both ways."
- $Q_\mathcal{L}$ is the canonical "small" representation of the congruence-lattice structure on $J(\mathcal{L})$.

"Congruence Lattice Problem (CLP)":
- Question (Dilworth 1944): which distributive algebraic lattices arise as $\textbf{Con}\,\mathcal{L}$?
- Finite case (Theorem 10.8): all of them. Positive answer.
- General infinite case: NEGATIVE (Wehrung 2007, Růžička 2008 optimal $\aleph_2$).
- Lemma 10.6 characterises the "nice" subclass that Theorem 10.8 covers — including all finite distributive.

"Lower bounded" vs "upper bounded" homomorphism:
- Lower bounded $f : \mathcal{L} \to \mathcal{K}$: each $\{x : f(x) \ge a\}$ has a least element $\beta(a)$.
- Upper bounded: dual (each $\{x : f(x) \le a\}$ has a greatest element).
- McKenzie 1972: foundational.
- Bounded = both lower and upper bounded.
- $\text{FL}(3) \twoheadrightarrow \mathcal{N}_5$ is bounded (Exercise 10.15).

"Relatively complemented" vs "complemented":
- Complemented: lattice with 0, 1 where every element has a complement.
- Relatively complemented: $a < x < b$ ⟹ $x$ has a relative complement in $b/a$.
- Relatively complemented + 0, 1 = complemented.
- Without 0, 1: relatively complemented may not be complemented.

"Direct sum $\sum \mathcal{L}_i$" vs "direct product $\prod \mathcal{L}_i$":
- Direct product: full product, all coordinates.
- Direct sum: sublattice with only finitely-many non-zero coordinates.
- For finite index set: direct sum = direct product.
- For infinite: strict containment.
- Theorem 10.10 uses direct sum to decompose relatively complemented PCF lattices.

### Nation Chapter 11 — Geometric Lattices — terms introduced new

geometry as incidence structure (axioms 1-4) · the geometry/measurement distinction · geometric lattice (algebraic semimodular atomistic) · atomistic · geometric dimension vs lattice dimension ($\delta - 1$) · Birkhoff 1930s development · Karl Menger, Franz Alt, Otto Schreiber 1936 (concurrent foundations) · Theorem 11.1 (3 equivalent characterisations: geometric ⟺ upper-continuous atomistic semimodular ⟺ ideal lattice of atomistic semimodular PCF) · the "little argument" (Steinitz exchange in lattice form) · the exchange property of closure operator $\Gamma$ ($y \in \Gamma(B \cup \{x\}), y \notin \Gamma(B) \Rightarrow x \in \Gamma(B \cup \{y\})$) · linear span as exchange closure · geometric (affine) closure as exchange closure · transcendence-degree closure (Mac Lane's 1938 motivation) · Theorem 11.2 (Mac Lane 1938, Duke Math. J. 4: geometric ⟺ closed sets of algebraic closure operator with exchange) · Hassler Whitney 1935 (matroids — Amer. J. Math. 57) · Garrett Birkhoff 1935 (lattice perspective on matroids — Amer. J. Math. 57) · matroid theory · matroid = atomistic semimodular finite lattice = closure operator with exchange · Theorem 11.3 (every geometric lattice is relatively complemented) · Lemma 11.4 ($\mathcal{I}(\sum \mathbf{K}_i) \cong \prod \mathcal{I}(\mathbf{K}_i)$) · Theorem 11.5 (Dilworth 1950 finite-dim, Hashimoto 1957 extension: geometric = direct product of SI; finite-dim = direct product of simple) · Hashimoto best version (complete weakly atomic relatively complemented = direct product of SI) · Libkin 1995 (atomistic algebraic = direct product of directly indecomposable) · Whitney numbers $w_k = |\{x : \delta(x) = k\}|$ · the unimodal conjecture (Rota ~1971) · Basterfield-Kelly 1968 ($w_1 \le w_k$ for $1 \le k < n$, Proc. Camb. Phil. Soc. 64) · Greene 1970 (rank inequality, J. Comb. Theory 9) · Hsieh-Kleitman 1973 (normalized matching, Stud. Appl. Math. 52) · Harper 1974 (morphology of partially ordered sets, J. Comb. Theory Ser. A 17) · Dowling-Wilson 1975 (Whitney number inequalities, Proc. AMS 47) · Adiprasito-Huh-Katz 2018 (Hodge theory for combinatorial geometries, Annals of Math 188 — log-concavity / unimodal RESOLVED) · June Huh 2022 Fields Medal · Brändén-Huh 2020 (Lorentzian polynomials, Annals 192) · the anti-exchange property ($y \in \Gamma(B \cup \{x\}), y \notin \Gamma(B) \Rightarrow x \notin \Gamma(B \cup \{y\})$) · convex geometries · convex hull as anti-exchange closure · Edelman-Jamison 1985 (convex geometries, Geometriae Dedicata 19) · Adaricheva-Gorbunov-Tumanov 2003 (Adv. Math. 173) · the matroid / convex-geometry dichotomy · independent set / basis (Exercise 11.7) · matroid Steinitz exchange (bases same cardinality) · edge lattice of a graph (graphic matroid, Exercise 11.4) · Hilbert's plane geometry incidence axioms (Exercise 11.6) · Veblen-Young theorem (projective geometry coordinatisation by skew field) · Pappus's theorem · Desargues's theorem · O. Ore 1942 ($\textbf{Eq}\,X$ relatively complemented and simple, Duke Math. J. 9, Exercise 11.10).

### Nation Ch 11 — terms recapped from Chs 1-10

posets · dimension function $\delta$ · atoms · atomistic (Chs 1, 2) · algebraic closure operator $\Gamma$ · algebraic lattice · compactness (Ch 3) · partition lattice $\textbf{Eq}\,X$ — semimodular but nonmodular for $|X| \ge 4$ (Ch 4) · congruences · $\textbf{Con}\,\mathcal{L}$ · subdirectly irreducible (SI) (Ch 5) · free lattices (Ch 6) · variety lattice $\Lambda$ (Ch 7) · distributive lattices · Birkhoff representation (Ch 8) · modular lattices · semimodular · Theorems 9.4-9.6 (chain length, dimension) · Dilworth covering bijection (Ch 9) · PCF lattices · closure-operator approach to congruences · relatively complemented · Theorem 10.10 (Dilworth 1950 direct sum) (Ch 10) · the 2-element lattice $\mathbf{2}$ · simple lattice · Funayama-Nakayama theorem.

### Nation Ch 11 — deep-dive additions

The Whitney-Birkhoff-Mac Lane unification (1935-1938: matroids ↔ atomistic semimodular lattices ↔ closure operators with exchange — three perspectives, one structure). The Adiprasito-Huh-Katz 2018 Hodge-theoretic resolution of the unimodal / log-concavity conjecture for matroids (Annals of Math 188): a major mathematical breakthrough using algebraic-geometric tools (Hodge theory, Chow rings of matroids, Bergman fans, Kähler package) to resolve a purely combinatorial problem; June Huh received the 2022 Fields Medal partially for this work. The matroid / convex-geometry dichotomy: exchange property → matroids → semimodular geometric lattices; anti-exchange property → convex geometries → join-semidistributive lattices (dually). Standard reference for matroids: James Oxley, <em>Matroid Theory</em> (OUP 2nd ed. 2011); for convex geometries: Adaricheva-Gorbunov-Tumanov 2003.

### Nation Ch 11 — terminology traps

"Geometric lattice":
- Definition: algebraic semimodular atomistic.
- Equivalently (Theorem 11.1): upper continuous atomistic semimodular.
- Equivalently: ideal lattice of atomistic semimodular PCF.
- Equivalently (Theorem 11.2): closed sets of closure operator with exchange.
- Generalises traditional "finite-dimensional" geometric lattices to infinite-dimensional case.

"Geometric dimension" vs "lattice dimension":
- Geometric dimension = lattice dimension - 1.
- Atoms (points): geometric dim 0, lattice dim 1.
- Lines: geometric dim 1, lattice dim 2.
- Planes: geometric dim 2, lattice dim 3.
- Discrepancy because lattice's bottom element 0 corresponds to "empty set of points."

"Exchange property" vs "anti-exchange":
- Exchange: $y \in \Gamma(B \cup \{x\}), y \notin \Gamma(B) \Rightarrow x \in \Gamma(B \cup \{y\})$. Symmetric.
- Anti-exchange: same antecedents $\Rightarrow x \notin \Gamma(B \cup \{y\})$. Asymmetric.
- Exchange = matroid theory (linear span, etc.).
- Anti-exchange = convex geometry (convex hull, etc.).
- The two are mutually exclusive (cannot both hold non-trivially) and complementary (cover most "natural" closure operators).

"Matroid" vs "geometric lattice":
- Whitney 1935 introduced matroids; Birkhoff 1935 showed they correspond to atomistic semimodular lattices.
- Modern matroid theory uses both perspectives interchangeably.
- Combinatorial: matroid = (set, independence axioms). Lattice: matroid = atomistic semimodular finite lattice. Closure: matroid = closure with exchange.

"Whitney numbers $w_k$":
- $w_k = |\{x \in L : \delta(x) = k\}|$ for finite geometric lattice.
- $w_0 = w_n = 1$.
- Examples: Stirling numbers (Eq n), Gaussian binomials (Sub(F_q^n)).
- Different from "Whitney number inequalities" (Dowling-Wilson 1975) which describes specific inequalities among the $w_k$.

"Unimodal conjecture" — status update:
- Originally (Rota ~1971): conjecture about Whitney numbers' shape.
- Open for ~50 years with many partial results.
- RESOLVED in 2018 by Adiprasito-Huh-Katz (Annals of Math 188) in the stronger LOG-CONCAVITY form.
- Nation's textbook (written before 2018) says "a long way off"; the resolution post-dates the text.
- June Huh: 2022 Fields Medal partially for this work.

"Convex geometry" vs "convex set":
- Convex SET (in $\mathbb{R}^n$): set closed under convex combinations.
- Convex GEOMETRY (Edelman-Jamison 1985): closure operator with anti-exchange. Generalises convex hull.
- Lattice characterisation: convex geometry ↔ finite join-semidistributive lattice (dually).

## Hyperlattice / Prologos cross-references

Same as the Călugăreanu companion — see `calugareanu-companion-process.md`'s table of source files.

## Stylistic discipline

- Same as Călugăreanu companion: prose over bullets, active voice, name proof strategy at the top, MathJax-friendly markup, light italics for emphasis.
- For Nation: preserve the literary epigraph at each chapter's overview (Nation's authorial voice).

— end of Nation process notes (Phase 1: Chapter 1 only) —
