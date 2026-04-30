# Free Lattices Companion: Process Notes

## Source

**Free Lattices** by Ralph Freese, Jaroslav Ježek, and J. B. Nation. Mathematical Surveys and Monographs, vol. 42. American Mathematical Society, Providence, RI (1995). 293 pp. ISBN 0-8218-0389-1.

PDF source: `outside/UH Professor - JB Nation - Lattices, Publications/Free Lattices (Ralph Freese Nation).pdf`

This is a **research-level monograph**, not a textbook. It is the canonical synthesis of free-lattice theory — about 70 years of research, integrated coherently in 12 chapters. The companion treats it as such: deeper than the Nation textbook companion, more attention to recent results and open problems, more "computed examples" rather than pedagogical exercises.

## Chapter inventory

| # | Title | Book pp. | PDF pp. |
|---|---|---|---|
| Introduction | — | 1–6 | 10–15 |
| I | Whitman's Solution to the Word Problem | 7–25 | 16–34 |
| II | Bounded Homomorphisms and Related Concepts | 27–66 | 36–75 |
| III | Covers in Free Lattices | 67–90 | 76–99 |
| IV | Day's Theorem Revisited | 91–94 | 100–103 |
| V | Sublattices of Free Lattices and Projective Lattices | 95–134 | 104–143 |
| VI | Totally Atomic Elements | 135–149 | 144–158 |
| VII | Finite Intervals and Connected Components | 151–169 | 160–178 |
| VIII | Singular and Semisingular Elements | 171–177 | 180–186 |
| IX | Tschantz's Theorem and Maximal Chains | 179–187 | 188–196 |
| X | Infinite Intervals | 189–203 | 198–212 |
| XI | Computational Aspects of Lattice Theory | 205–253 | 214–262 |
| XII | Term Rewrite Systems and Varieties of Lattices | 255–278 | 264–287 |

Plus: Open Problems (book p. 279), Bibliography (p. 281), List of Symbols (p. 287), Index (p. 289).

## File layout

- `freelat-companion-toc.html` — front door / table of contents
- `freelat-companion-ch01.html` … `freelat-companion-ch12.html` — chapter companions (Roman numeral chapters mapped to two-digit decimal filenames `ch01`–`ch12` for filesystem ordering)
- `freelat-companion-process.md` — this file

This Free Lattices companion is **separate but cross-linked** to the Nation textbook companion. Chapter I of the monograph parallels Chapter 6 of Nation's *Notes on Lattice Theory* — but goes much deeper. Chapters II, V, and XI of the monograph have no direct counterpart in the textbook. We will cross-reference back to Nation textbook chapters where it helps the reader.

## Notation differences from Nation's textbook (that the monograph uses)

The monograph uses bold-roman for:
- **L**, **K**, **F** — lattices (e.g., `**L**` = lattice $\mathcal{L}$ in the textbook)
- **2** — the two-element lattice
- **FL**(X) — the free lattice on X
- **F**_𝒱(X) — the relatively free lattice in variety 𝒱

The monograph reserves **boldface** for lattice names and uses **italic** for elements. Where Nation's textbook uses $\mathcal{L}$ (calligraphic L), the monograph uses **L**. Where the textbook uses $\textbf{Con}\,\mathcal{L}$, the monograph uses **Con L**.

Other notation:
- **J(L)** = set of join-irreducibles of **L** (same as Nation textbook).
- **M(L)** = set of meet-irreducibles.
- $a \prec b$ — $a$ is covered by $b$ (same).
- $b/a$ — the interval $\{x : a \le x \le b\}$ (same).
- $\downarrow x$, $\uparrow x$ — principal ideal / filter (same).
- $A \ll B$ — **join refinement** ($\forall a \in A, \exists b \in B, a \le b$). Same as Nation textbook Ch 6 § 6.7.
- $A \gg B$ — **meet refinement** (dual).
- (W) — Whitman's condition.
- (W+) — variant useful for computation (Theorem 1.10 in monograph).
- (SD$_\vee$), (SD$_\wedge$) — semidistributive laws.
- $\underline{x}$, $\overline{x}$ — atoms ($\bigwedge(X-\{x\})$) and coatoms ($\bigvee(X-\{x\})$) of finitely generated **FL(X)**.

The monograph uses the term **rank** for what some authors call "length" of a term. Importantly, the rank of a term as defined here is the canonical-form-relevant measure — the canonical form is unique up to commutativity (NOT associativity), because the monograph's rank function gives preference to flat $x_1 \vee x_2 \vee x_3$ form (rank 4) over nested $(x_1 \vee x_2) \vee x_3$ form (rank 5).

## Stylistic differences from Nation's textbook

The monograph is denser and more research-oriented:
- More named theorems, lemmas, corollaries per page.
- Many open problems threaded throughout.
- Less pedagogical scaffolding; assumes lattice theory background.
- Heavy use of forward references (e.g., Chapter I Theorem 1.27 cites Chapter II §1).

The companion preserves these features. We do NOT add structure that isn't there — no literary epigraphs, no hand-holding for basics. Instead we offer: clear reformulation in plain English, marginal notes on historical context, computed examples that illustrate the abstract theorems concretely, and connection panels showing where each result connects to broader themes.

## Process discipline (shared with our other companions)

1. Read the chapter from the PDF directly (do not paraphrase second-hand).
2. Web search for historical/algebraic context relevant to specific theorems.
3. Build single chapter HTML file at `freelat-companion-chNN.html` matching the template (CSS theme tokens with light/dark mode, sidebar nav, hero, overview, vocab primer, parts following monograph sections, connection panels with P5 always Prologos, glossary, computed examples, looking ahead, footer + scripts).
4. Cross-link previous chapter forward in the chain.
5. Update ToC card from pending → available with topic-chip tooltips.
6. Update process notes term ledger.
7. Verify HTML well-formedness via Python parser.
8. Reply with `computer://` link and Sources section.

## Workflow per chapter

1. Read the chapter pages (`offset` and `pages` from the table above).
2. Identify the section structure (headings already visible in chapter ToC).
3. Identify named results: theorems, lemmas, corollaries, problems.
4. Web-search 2–3 historical context items (e.g., Whitman 1941, Skolem 1920, Galvin-Jónsson 1961, Day 1970, McKenzie 1972).
5. Draft the companion: hero + primer + parts mirroring sections + 5 connection panels + glossary + computed examples + looking ahead.
6. Wire up: forward link from previous chapter, update ToC card, extend term ledger.
7. Verify and report.

## Cross-references to the Nation textbook companion

The Nation textbook companion (`nation-companion-*.html`) covers the same field at the undergraduate level. Where helpful, point readers from the monograph companion back to the textbook companion for foundational material. Examples:
- Whitman's word-problem algorithm — Nation textbook **Chapter 6, Section 6.5** ↔ monograph **Chapter I, Section 2** (deeper treatment).
- Canonical form — Nation textbook **Chapter 6, Section 6.8** (Theorem 6.7) ↔ monograph **Chapter I, Section 3** (full treatment, with the rank-vs-commutativity-vs-associativity nuance).
- Semidistributivity — Nation textbook **Chapter 6, Section 6.9** ↔ monograph **Chapter I, Theorem 1.21** (Jónsson-Kiefer).
- Day's doubling — Nation textbook **Chapter 6, Section 6.4** ↔ monograph **Chapter I, Section 1** (Theorem 1.1).
- Sublattice characterizations — Nation textbook **Chapter 6, Theorem 6.9** (Nation 1982) ↔ monograph **Chapter V** (full treatment, with projective lattice connection).

## Term ledger

### Chapter I — Whitman's Solution to the Word Problem — terms introduced new

order relation (R, A, T) · ordered set (poset) · dual order · quasiorder · chain · antichain · length · width · upper bound, lower bound · least upper bound (supremum, join, $\bigvee$) · greatest lower bound (infimum, meet, $\bigwedge$) · lattice (algebra view: idempotent, commutative, associative, absorptive) · lattice (poset view) · join irreducible · completely join irreducible · join prime · completely join prime · meet irreducible · completely meet irreducible · meet prime · completely meet prime · least element 0 · greatest element 1 · J(**L**) · M(**L**) · cover relation $a \prec b$ · upper cover, lower cover · connected component of cover relation · interval $b/a$ · order ideal · order filter · ideal (closed under finite joins) · filter · convex set · pseudo-interval · lower pseudo-interval · upper pseudo-interval · Day's doubling construction $\mathbf{L}[C]$ · the natural epimorphism $\lambda : \mathbf{L}[C] \to \mathbf{L}$ · lattice term · variable · length, rank, complexity of a term · subterm · term over X · interpretation $t^\mathbf{L}$ in lattice **L** · n-ary operation $t^\mathbf{L}(a_1, \dots, a_n)$ · equation $s \approx t$ · freely generated · **FL**(X) · **FL**(n) · T(X) absolutely free term algebra · ~ relation on T(X) · representative of $w \in \mathbf{FL}(X)$ · variety · nontrivial variety · equational class · relatively free lattice $\mathbf{F}_\mathcal{V}(X)$ · the two-element lattice **2** · condition (†) (Lemma 1.2) · condition (‡) (Lemma 1.3) · condition (W) (Whitman's condition) · (W+) (variant of W, Theorem 1.10) · atom $\underline{x} = \bigwedge(X - \{x\})$ · coatom $\overline{x} = \bigvee(X - \{x\})$ · Whitman's algorithm (Theorem 1.11, 6 cases) · canonical form · equivalent under commutativity ($s \equiv t$) · join refinement $A \ll B$ · meet refinement $A \gg B$ · subelement of $w$ · canonical join representation, canonical join expression · canonical joinands, canonical meetands · minimal join representation · semidistributive lattice (SD$_\vee$, SD$_\wedge$) · up directed set · down directed set · upper continuous · lower continuous · continuous lattice · unary polynomial $f(x) = t^\mathbf{L}(x, c_1, \dots, c_n)$ · fixed point free polynomial · order polynomial complete lattice · locally complete lattice · slim polynomial (Example 3.40 reference) · ascending chain without least upper bound (Example 1.24) · breadth at most n.

### Chapter I — terms recapped from background lattice theory

The monograph assumes the reader knows: posets, chain conditions (ACC, DCC), lattice operations, sublattice, distributive law, modular law, partial order, Hasse diagram (these are reviewed in §1).

### Chapter I — deep-dive additions

Day's doubling construction (Alan Day 1970, *A simple solution of the word problem for lattices*, Canad. Math. Bull. 13, 253–254) treated more carefully than in textbooks: the monograph's formulation works on arbitrary convex subsets, not just intervals. The **Whitman algorithm** (Theorem 1.11) is presented with explicit complexity considerations forward-referenced to Chapter XI. The **Jónsson-Kiefer 1962** semidistributivity result is given as Theorem 1.21 of this chapter — its proof is one of the cleanest demonstrations of semidistributivity in any context. The **Galvin-Jónsson 1961** theorem (no uncountable chains in relatively free lattices) is given as Theorem 1.27 with a proof using automorphism orbits. **Whitman 1942** showed FL(3) contains FL(ω) as sublattice — Theorem 1.28, with the explicit construction using Whitman's six unary polynomials and their iterates.

### Chapter I — terminology traps

"Rank" vs "length":
- The monograph's *rank* is what some authors call *length* (= number of variables and parentheses pairs).
- The rank of $x \vee y \vee z$ is 4 (3 variables + 1 implicit outer set of parentheses), while $(x \vee y) \vee z$ has rank 5.
- The rank function PREFERS flat n-ary form, so canonical form is unique up to commutativity (without explicit associativity).

"Length" overloads:
- *Length of a poset* = supremum of cardinalities of chains (§1, p. 8).
- *Length of a term* = the rank just discussed (§2, p. 10).
- Two different uses of "length"; the monograph distinguishes by context.

"Complete join irreducible" vs "join irreducible":
- *Join irreducible*: $a = b \vee c \Rightarrow a = b$ or $a = c$.
- *Completely join irreducible*: $a = \bigvee S \Rightarrow a \in S$.
- Strict containment in general; equivalent under DCC.

"Convex" subset:
- $C \subseteq L$ convex if $a, b \in C, a \le c \le b \Rightarrow c \in C$.
- Day's doubling works on convex sets, not just intervals.

"Day's doubling" overloads:
- $\mathbf{L}[C]$ for convex $C$ — most general (§1).
- $\mathbf{L}[I]$ for interval $I = u/v$ — special case used in textbooks.

"Free lattice" vs "relatively free lattice":
- *Free lattice* **FL**(X) — free in the variety of all lattices.
- *Relatively free lattice* $\mathbf{F}_\mathcal{V}(X)$ — free in some specified variety 𝒱.
- The unmodified term "free lattice" always means **FL**(X); when relative-to-a-variety, the variety is named explicitly.

"FL(X) NOT complete":
- Theorem 1.22 says **FL**(X) is *continuous* (a directed-set property) — but Example 1.24 shows it is NOT *complete* unless $|X| \le 2$.
- Continuity ≠ completeness for incomplete lattices.

"(W) vs (W+)":
- (W): $v_1 \wedge \cdots \wedge v_r \le u_1 \vee \cdots \vee u_s$ implies one of the four trivial reasons.
- (W+): same with the variables on each side allowed to be from $X$ directly — this is the form best suited to actual computation.

### Chapter II — Bounded Homomorphisms and Related Concepts — terms introduced new

bounded homomorphism · lower bounded homomorphism · upper bounded homomorphism · $\beta_h$ / $\beta(a) = \min h^{-1}(1/a)$ · $\alpha_h$ / $\alpha(a) = \max h^{-1}(a/0)$ · lower bounded lattice (in McKenzie sense — finitely generated $\mathbf{L}$ with natural $\mathbf{FL}(X) \to \mathbf{L}$ lower bounded) · upper bounded lattice · bounded lattice (note: distinct from order-theoretic "has 0 and 1") · minimal join cover · nontrivial join cover · refinement of a join cover · minimal join cover refinement property · $\mathcal{M}(a)$ · $\mathcal{M}^*(a)$ (minimal covers of completely-join-irreducibles) · D relation $aDb$ · $D_k(\mathbf{L})$ · $\mathbf{D}(\mathbf{L}) = \bigcup_k D_k$ · D-rank $\rho(a)$ · D-sequence · D-cycle · join cover refinement property · E relation · E-cycle · E-sequence · D-closed set · E-closed set · J-closed set (modern term post-Theorem 2.51) · $\mathbf{J}(p)$ · $\mathbf{J}^*(p)$ · lower pseudo-interval · upper pseudo-interval · $K(a) = \{u : u \ge a_*, u \not\ge a\}$ · $\kappa_\mathbf{L}(a) = \bigvee K(a)$ (the κ-bijection) · $\kappa_\mathbf{L}^d$ (dual) · A relation $aAb$ on $\mathbf{J}(\mathbf{L})$ · B relation $aBb$ · C relation · C-sequence · C-cycle · $A^d, B^d, C^d$ duals on $\mathbf{M}(\mathbf{L})$ · critical pair (in subdirectly irreducible lattice with monolith $\mu$) · critical quotient · prime critical quotient · the variety $\mathbf{V}(\mathbf{L})$ generated by $\mathbf{L}$ · the lattice $\mathbf{\Lambda}$ of all lattice varieties · principal ideal $\mathcal{J}_{\mathbf{V}(\mathbf{L})}$ in $\mathbf{\Lambda}$ · conjugate equation $\beta_{n,f}(u) \le \alpha_{n,f}(v)$ · set of conjugate equations · splitting pair $\langle u, v\rangle$ · splitting lattice · conjugate variety $\mathcal{C}_\mathbf{L}$ · completely meet prime / completely join prime in $\mathbf{\Lambda}$ · $S_n = X^{(\wedge \vee)^{n+1}} = X^{(\vee \wedge)^n \vee}$ (Dean-McKinsey relatively-free finite sublattice) · weakly atomic lattice · join irredundant set · meet irredundant set · congruence variety · $\mathbf{Con}\,\mathbf{S}$ for a semilattice $\mathbf{S}$ · the coatom congruences $\psi_a$ on a semilattice · pseudovariety / quasivariety · subquasivariety lattice.

### Chapter II — terms recapped from background

The chapter assumes the reader knows: subdirectly irreducible algebra and monolith (universal-algebra background); congruence lattice $\mathbf{Con}\,\mathbf{L}$; variety, equational class, HSP theorem (Birkhoff 1935); Jónsson's lemma (1968 — distributivity of $\mathbf{\Lambda}$); inverse limit of lattices; relatively-free lattice in a variety; quasivariety. References: McKenzie-McNulty-Taylor *Algebras, Lattices, Varieties* Vol I (1987), Burris-Sankappanavar *A Course in Universal Algebra* (1981), Jipsen-Rose *Varieties of Lattices* (1992).

### Chapter II — deep-dive additions

**McKenzie 1972** *Equational Bases and Nonmodular Lattice Varieties* (Trans. AMS 174, 1–43) — the chapter's foundational paper, treated as both historical context and active material. **Day 1970** doubling construction (Canad. Math. Bull. 13) is the geometric primitive, whose connection to McKenzie's algebraic notion of bounded is given by Theorem 2.43. **Jónsson 1972** *Lattices of lattice homomorphisms* (Algebra universalis) is the parallel adjoint-functor treatment, complementary to McKenzie. **Day 1979** *Characterizations of finite lattices that are bounded-homomorphic images or sublattices of free lattices* (Canad. J. Math. 31) is the source for Theorem 2.64 (lower bounded SD-lattice = bounded iff meet semidistributive) and the weak-atomicity proof in §7. **Nation 1985** ("Bounded lattices") is the source of Lemma 2.63 (κ-duality between A and B).

**Tame congruence theory** (Hobby-McKenzie 1988, *The Structure of Finite Algebras*, AMS Contemporary Math 76) is the framework for Theorem 2.88 (Kearnes' theorem). The chapter's §8 application — congruence varieties of finite algebras in SD$_\wedge$ varieties are upper bounded — uses tame-congruence-theory inputs. **Adaricheva, Dziobiak, Gorbunov 1993** is the source of Theorem 2.90 (subquasivariety lattices).

The κ-bijection (Theorem 2.55) deserves special attention: it is the structural skeleton showing $|\mathbf{J}(\mathbf{L})| = |\mathbf{M}(\mathbf{L})|$ in semidistributive lattices, and provides a canonical bridge between join-side and meet-side combinatorial data. Reading-Speyer-Thomas 2019 (Adv. Math.) proved a "fundamental theorem of finite SD lattices" relating κ-orbits to congruence structure, building on this material.

### Chapter II — terminology traps

"Bounded" overloads:
- McKenzie's *bounded homomorphism* — has both least and greatest pre-images (β and α exist).
- McKenzie's *bounded lattice* — a finitely-generated lattice whose natural map from $\mathbf{FL}(X)$ is bounded.
- Order-theoretic *bounded lattice* — has 0 and 1.
- These are different! The monograph uses the McKenzie sense throughout Chapter II onward; readers familiar with the order-theoretic sense need to context-switch.

"Lower bounded" vs "upper bounded":
- Lower bounded: $\beta(a)$ exists (LEAST element of pre-image filter).
- Upper bounded: $\alpha(a)$ exists (GREATEST element of pre-image ideal).
- The "lower" / "upper" refers to which BOUND of the fiber; symmetric in algebra (each is the dual of the other), but asymmetric in the monograph's typical applications (lower-boundedness ↔ SD$_\vee$, upper-boundedness ↔ SD$_\wedge$).

"D" relation overloads:
- D as DEPENDENCY (the chapter's relation on lattice elements).
- $D_0(\mathbf{L}), D_k(\mathbf{L}), \mathbf{D}(\mathbf{L})$ — different sets defined recursively.
- D-cycle / D-sequence — finite cyclic / non-cyclic chains under D.
- $D^d$ — the dual relation.
- All from the same root letter; context disambiguates.

"D-closed" vs "J-closed":
- These are the SAME notion in lower-bounded lattices (Theorem 2.51).
- The monograph uses "D-closed" in early sections, then transitions to "J-closed" after Theorem 2.51 (book p. 49) once it's established that the closure operator $\mathbf{J}(p)$ unifies the two notions.
- We adopt "J-closed" in our companion's discussion of Chapter III onward, following the monograph's convention.

"Pseudo-interval":
- LOWER pseudo-interval = finite union of intervals with common BOTTOM.
- UPPER pseudo-interval = finite union of intervals with common TOP.
- Both are convex (Day's doubling applies). An interval is BOTH a lower and upper pseudo-interval (with $n = 1$).
- Theorem 2.43 vs Corollary 2.44 distinction: lower-bounded $\Leftrightarrow$ doubling lower pseudo-intervals; bounded $\Leftrightarrow$ doubling INTERVALS (the strictly stronger condition).

"Splitting" overloads:
- *Splitting pair* in $\mathbf{\Lambda}$ — the pair $\langle \mathbf{V}(\mathbf{L}), \mathcal{C}_\mathbf{L}\rangle$ that splits $\mathbf{\Lambda}$ into a principal ideal and filter.
- *Splitting lattice* — the finite, bounded, subdirectly-irreducible lattice $\mathbf{L}$ that determines such a pair.
- *Splitting equation* / *conjugate equation* — the equation that witnesses the splitting.
- All three concepts are distinct; the splitting LATTICE generates the splitting PAIR via a splitting EQUATION.

"κ" notation:
- $\kappa_\mathbf{L}$ (or just $\kappa$) is partially defined on $\mathbf{J}(\mathbf{L})$ in general, fully defined under Theorem 2.54's hypotheses.
- $\kappa^d$ is the dual map on $\mathbf{M}(\mathbf{L})$.
- Corollary 2.55: in semidistributive lattices satisfying both refinement properties, $\kappa$ and $\kappa^d$ are inverse bijections.

### Chapter III — Covers in Free Lattices — terms introduced new

cover relation $a \prec b$ specialised to $\mathbf{FL}(X)$ · lower cover $w_*$ for completely-join-irreducible $w$ · upper cover $w^*$ for completely-meet-irreducible $w$ · canonical-meetand-not-above $\kappa(w)$ in $\mathbf{FL}(X)$ (Theorem 3.1) · the κ-bijection $\mathbf{J}(\mathbf{FL}(X)) \leftrightarrow \mathbf{M}(\mathbf{FL}(X))$ (Theorem 3.3) · the bijection $\gamma$ between lower covers of $w$ and completely-join-irreducible canonical joinands (Theorem 3.5) · lower atomic / upper atomic element · coverless element · Dean's example $w = x \wedge (y \vee z)$ (1960, ad hoc) · $A^\vee$ for $A \subseteq L$ — the join-subsemilattice generated by $A$ · derived meet $\wedge'$ in $A^\vee$ · D-closed = J-closed sets (consistent terminology with Chapter II onward) · standard epimorphism $f : \mathbf{F} \to A^\vee$, $f(u) = \bigvee\{a \in A : a \le u\}$ · $\mathbf{L}^\vee(w) = \mathbf{J}(w)^\vee$ · $\mathbf{L}^\wedge(w) = \mathbf{M}(w)^\wedge$ · $w_\dagger = \bigvee\{u \in \mathbf{J}(w) : u < w\}$ (lower cover of $w$ in $\mathbf{L}^\vee(w)$) · $w^\dagger$ dual · the K-set $\mathbf{K}(w) = \{v \in \mathbf{J}(w) : w_\dagger \vee v \not\ge w\}$ · $k^\dagger = \bigwedge\{\kappa(v) : v \in \mathbf{J}(w) - \{w\}, \kappa(v) \ge \bigvee \mathbf{K}(w)\}$ · syntactic algorithm · subelement of $w$ · slim element (recap from Chapter I, classified in Example 3.40) · connected component of $a$ specialised: 5-element pentagon for a generator (Example 3.43); 11-element component for $0$ in $\mathbf{FL}(3)$ (Example 3.44); the bottom of $\mathbf{FL}(n)$ for $n \ge 4$ with $1 + n^2$ atom-region elements (Example 3.45).

### Chapter III — terms recapped

Chapter III is the operational realisation of Chapters I–II's structural theory. All vocabulary from Chapters I–II carries forward: canonical form, canonical joinands/meetands, $A \ll B$, semidistributivity, Whitman's condition (W) and its algorithm, Day's doubling, bounded homomorphisms with $\beta, \alpha$, the κ-bijection, J-closed sets, the D-relation and D-rank, splitting lattices and conjugate equations.

### Chapter III — deep-dive additions

**Freese-Nation 1985** *Covers in free lattices* (Trans. AMS 288, 1–42) is the chapter's near-complete source. The polynomial-time complexity of the algorithm is proved in **Chapter XI** of the monograph, using the concrete syntactic formula in Theorem 3.32. **Freese 1990** *Free lattice algorithms* (Order 7, 165–177) is the implementation-oriented companion paper, with notes on data structures and software design; the cover algorithm has been implemented in Freese's lattice-drawing program, producing Figure 3.3 and Figure 3.5 in this chapter.

**McKenzie 1972** is foundational to Theorem 3.25 (the congruence formula $\ker f = \psi(w, w_*) = \psi(\kappa(w)^*, \kappa(w))$). McKenzie was the first to show that in free lattices, the unique largest congruence separating a prime quotient is the kernel of a splitting-lattice quotient.

**Dean's 1960 ad hoc example** ($w = x \wedge (y \vee z)$ has no lower cover in $\mathbf{FL}(3)$) is referenced in Example 3.36. Dean was working on a different problem at the time (free lattices over partially ordered sets) and noticed the absence of a cover empirically. The structural reason ($\mathbf{L}^\vee(w)$ fails SD$_\wedge$) emerged 25 years later in Freese-Nation 1985.

**Dilworth's characterisation of lattice congruences** ([40] in the bibliography; see e.g. Crawley-Dilworth 1973) provides the theoretical underpinning for Theorem 3.25. For any prime quotient $u/v$ in any lattice, there exists a maximal congruence $\psi(u, v)$ separating $u$ from $v$.

**Tschantz's theorem (Chapter IX)** — every infinite interval in $\mathbf{FL}(X)$ contains a coverless element — is the structural counterpart to Day's weak-atomicity theorem. The two coexist: every nontrivial interval has covers (Day), but every infinite interval also has coverless elements (Tschantz). Example 3.39 explicitly constructs a coverless element by stacking Dean witnesses.

### Chapter III — terminology traps

"Lower cover $w_*$" vs "$w_\dagger$":
- $w_*$ is the lower cover of $w$ in $\mathbf{FL}(X)$ ITSELF (exists when $w$ is completely join irreducible).
- $w_\dagger$ is the lower cover of $w$ in $\mathbf{L}^\vee(w)$ (always exists when $w$ is join irreducible).
- These are DIFFERENT elements in general; $w_*$ is in $\mathbf{FL}(X)$, $w_\dagger$ is in $\mathbf{L}^\vee(w)$.
- Theorem 3.30: $w$ is completely join irreducible (so $w_*$ exists) iff every $u \in \mathbf{J}(w) - \{w\}$ is completely join irreducible AND $w \not\le \bigvee \mathbf{K}(w)$. The connection is: $\bigvee \mathbf{K}(w) \not\ge w$ iff $w_*$ exists in $\mathbf{FL}(X)$.

"D-closed" / "J-closed" terminology:
- The monograph uses "D-closed" in Chapter II §4 (when first defined), then transitions to "J-closed" after Theorem 2.51 establishes the closure-operator characterisation.
- Chapter III uses "J-closed" exclusively.
- We follow the monograph: J-closed in Chapter III onward, with "D-closed" used only when historical reference is needed.

"$A^\vee$" notation:
- $A^\vee$ is the JOIN-subsemilattice generated by $A$, with the JOIN inherited from $\mathbf{F}$ but the MEET DERIVED (defined by $a \wedge' b = \bigvee\{c \in A : c \le a \wedge b\}$).
- $A^\vee$ is NOT the sublattice generated by $A$ — it's smaller, since the meet is restricted to $A^\vee$.
- For finite J-closed $A \subseteq \mathbf{J}(\mathbf{F})$, $A^\vee$ is finite and lower bounded.

"Coverless" vs "no lower cover":
- A coverless element has NEITHER lower NOR upper covers.
- An element with no lower cover MAY still have upper covers (e.g., $w = x \wedge (y \vee z)$ has no lower cover but has 2 upper covers per Example 3.36).
- The interval Tschantz studies is "infinite" — not "coverless" — though every infinite interval contains coverless elements (Chapter IX).

"Slim" element:
- A slim element is one whose canonical form is a STRICT alternation of $\wedge$ and $\vee$ with NO repetitions in adjacent positions. Defined in Chapter I (Theorem 1.26 + Example 1.26), classified for covers in Example 3.40.
- Every generator is trivially slim (canonical form of length 1).
- Slim elements with lower covers are RARE: only generators and the specific even-length even-positions-equal pattern.

"Standard epimorphism" overloads:
- Theorem 3.15 defines the standard epimorphism $f : \mathbf{F} \to A^\vee$ for finite J-closed $A$.
- Corollary 3.18 specialises to $f : \mathbf{FL}(X) \to \mathbf{L}^\vee(w)$ when $A = \mathbf{J}(w)$.
- Theorem 3.19 considers a "secondary" standard epimorphism between two $A^\vee, B^\vee$ with $B \subseteq A$.
- All three are the "same" map in the sense that $f(u) = \bigvee\{a \in A : a \le u\}$, but the source and target lattices change.

### Chapter IV — Day's Theorem Revisited — terms introduced new

$q(u, v)$ — the completely-join-irreducible witness from Theorem 4.1's proof, satisfying $q \le u$, $v \le \kappa(q)$, $\rho(q) \le \rho^d(u) + \rho(v) - 1$ · the $s_m$ sequence ($s_0 = z$, $s_1 = x \wedge (y \vee z)$, $s_{2k} = z \wedge (y \vee s_{2k-1})$, $s_{2k+1} = x \wedge (y \vee s_{2k})$) · the $t_n$ sequence ($t_0 = x$, $t_1 = y \vee (z \wedge x)$, $t_{2k} = x \vee (z \wedge t_{2k-1})$, $t_{2k+1} = y \vee (z \wedge t_{2k})$) · "rank refinement" — the chapter's theme: Day's qualitative theorem upgraded to quantitative · "constructive vs non-constructive proof" — Chapter II §7's inverse-limit construction is non-constructive; Chapter IV §1's syntactic version is constructive · sharpness (Theorem 4.3) — the rank bound $m + n - 1$ is best possible, witnessed by the $s/t$ sequences.

### Chapter IV — terms recapped

Almost everything is recapped from Chapters I–III. The chapter introduces minimal new vocabulary — it is a refinement built from existing tools. Recapped: D-rank $\rho$ and dual D-rank $\rho^d$ (II.7), the structural form $\rho(u) = $ least $n$ with $u \in X^{\wedge(\vee\wedge)^n}$ (II.11), Day's doubling (I.1), Whitman's condition (I.8), bounded homomorphisms (II.1), the κ-bijection (II.54–II.55, III.3), J-closed sets (II.48, III.15), the standard epimorphism (III.15), $\mathbf{L}^\vee(w) = \mathbf{J}(w)^\vee$ (III.24), the 5-fold complete-join-irreducibility (III.26), splitting lattices (II.79, III.26).

### Chapter IV — deep-dive additions

**Freese-Nation 1985** (Trans. AMS 288, 1–42) is again the source — the same paper that supplied Chapter III. Theorem 5.3 of FN 1985 IS Theorem 4.1 here, with notation differences. The 1985 paper organised the material differently — the cover algorithm and the rank-refined Day's theorem appeared together; the monograph splits them across Chapters III and IV for pedagogical clarity.

**Day's 1979 paper** *Characterizations of finite lattices that are bounded-homomorphic images or sublattices of free lattices* (Canad. J. Math. 31, 69–78) is the source of the qualitative weak-atomicity theorem (Chapter II §7). Day 1970's *A simple solution to the word problem for lattices* (Canad. Math. Bull. 13, 253–254) introduced doubling. The chapter's title "Day's Theorem Revisited" alludes to revisiting Day's 1979 result with explicit rank control.

**Tschantz 1992** *Infinite intervals in free lattices* (Order 8, 273–290) uses Theorem 4.1 as a key technical input. Tschantz proved every infinite interval $u/v$ in $\mathbf{FL}(X)$ contains a sublattice isomorphic to $\mathbf{FL}(Y)$ for $|Y| \le |X| + \aleph_0$. The proof requires the rank-bounded version of Day's theorem (Chapter II §7's inverse-limit version is insufficient). Chapter IV is the structural prerequisite for Chapter IX.

The synthesis of Chapter II's doubling and Chapter III's standard-epimorphism machinery in Theorem 4.1's Case 3 proof is one of the most elegant constructions in the monograph. Day's doubling, originally applied to $\mathbf{FL}(X)$ to prove (W) (Theorem 1.8) and weak atomicity (Theorem 2.84), is here applied at the level of $\mathbf{L}^\vee$ — a finite bounded lattice — to construct an explicit canonical-form witness. The footnote on book p. 92: "Alternately, this whole proof could be recast in terms of the doubling construction, yielding something intermediate between this syntactic version and the one in Section 4 of Chapter II."

### Chapter IV — terminology traps

"Day's theorem" overloads (a frequent confusion):
- *Day's 1970 theorem*: word-problem solution for free lattices via doubling. Chapter I material.
- *Day's structural characterisation* (Theorem 2.43): finite lower-bounded lattices = built from $\mathbf{1}$ by iterated doubling of lower pseudo-intervals.
- *Day's 1979 weak-atomicity theorem* (Theorem 2.84, Corollary 2.85): finitely-generated free lattices are weakly atomic.
- *Day's theorem on bounded SD-lattices* (Theorem 2.64): finite lower-bounded SD-meet lattices are bounded.
- *Day's theorem revisited* (Theorem 4.1): rank-refined version of the 1979 theorem.
- All five are due to (or named after) Alan Day. Context disambiguates; this companion uses "Day 1979" for the weak-atomicity theorem and "the rank-refined Day's theorem" or "Theorem 4.1" for the Chapter IV version.

"$\rho$ and $\rho^d$":
- $\rho(u)$ is the D-rank in the JOIN direction — counts levels of meets-of-joins-of-meets-... starting from a meet at the top.
- $\rho^d(u)$ is the dual — counts levels starting from a JOIN at the top.
- For the SAME element $u$, $\rho(u)$ and $\rho^d(u)$ generally DIFFER — they measure complementary structural features.
- Theorem 4.1's bound is $\rho(q) \le \rho^d(u) + \rho(v) - 1$ — note the asymmetry: $\rho^d$ on the upper element $u$, $\rho$ on the lower element $v$. This reflects the construction (κ inverts join/meet structure between $q$ and $\kappa(q)$).

"Constructive vs non-constructive":
- Chapter II §7's proof of Day's weak-atomicity theorem is "non-constructive" in the sense that it gives an inverse limit of doublings — the witness lives in a categorical limit object, not directly in $\mathbf{FL}(X)$.
- Chapter IV §1's proof is "constructive" — the witness $q(u, v) \in \mathbf{FL}(X)$ is an EXPLICIT canonical-form term, computable from canonical forms of $u$ and $v$.
- Both proofs are "constructive" in the broader sense (no axiom of choice, etc.); the distinction is about producing an EXPLICIT WITNESS rather than a categorical limit.

"$s_m, t_n$ sequences":
- These are SPECIFIC canonical-form terms in $\mathbf{FL}(X)$ for $X = \{x, y, z, \ldots\}$, defined by recursion on $m, n$.
- $s_1 = x \wedge (y \vee z)$ is Dean's 1960 coverless element from Example 3.36 — the first historical instance of the "no lower cover" phenomenon.
- The sequences are designed to make Theorem 4.3's bound tight; they are not the unique witnesses, just the most natural ones.
- The constraint "$m$ even or $n$ odd" is intrinsic — when both parities are wrong, $s_m \le t_n$ trivially, and Theorem 4.3 doesn't apply.

### Chapter V — Sublattices of Free Lattices and Projective Lattices — terms introduced new

projective lattice (every epimorphism onto $\mathbf{L}$ has a homomorphism transversal) · transversal of a surjection ($g$ with $fg = \mathrm{id}$) · order-preserving / join-preserving / homomorphism transversals · retraction (homomorphism with a homomorphism transversal) · retract of a lattice · finitely separable lattice / ordered set · $\mathbf{FL}(\mathbf{P})$ — free lattice generated by an ordered set $\mathbf{P}$ · $\mathbf{FD}(\mathbf{P})$ — free distributive lattice over $\mathbf{P}$ · order dimension of an ordered set · S-lattice (finite SD + (W)) · the $A_1, A_2$ subdivision of $A$ relation: $A_1$ if $a \wedge \kappa(b) > b_*$, $A_2$ if $a \wedge \kappa(b) = b_*$ · the $B_1, B_2$ subdivision of $B$ relation: $B_1$ if $b_* \not\le a$, $B_2$ if $b_* < a$ · free star principle (used repeatedly in §3 proof) · B-type sequence (4 conditions B1-B4) · forbidden lattices $\mathbf{L}_1, \mathbf{L}_2, \ldots, \mathbf{L}_8$ (Figure 5.8) · primitive lattice (finite SI projective) · the four starter primitives $\mathbf{A}_1, \mathbf{A}_2, \mathbf{A}_3, \mathbf{A}_4$ · the six infinite-family representatives $\mathbf{B}_3, \mathbf{C}_3, \mathbf{D}_3, \mathbf{E}_3, \mathbf{F}_5, \mathbf{G}_4$ · perfect element / coperfect element · the five primitive-lattice constructions $\mathbf{R}, \mathbf{P}, \mathbf{P}^*, \mathbf{Q}, \mathbf{Q}^*$ · ordinal sum $\mathbf{L}_0 + \mathbf{L}_1$ · parallel sum · *-distributive ($\bigvee(a * B) = a \wedge \bigvee B$) · staircase distributive · the operation $a * \langle b_1, \ldots, b_n\rangle$ · countable cofinal chain / countable coinitial chain (used in Theorem 5.16) · countable union of antichains (Galvin-Jónsson) · 4-distributivity · $f_n$ = max cardinality of length-$n$ sublattice of FL · countable CC (countable chain condition).

### Chapter V — terms recapped

Carries forward EVERYTHING from Chapters I–IV. (W), canonical form, semidistributivity, bounded homomorphism, the κ-bijection, J-closed sets, the standard epimorphism, $\mathbf{L}^\vee(w)$, Day's theorem (multiple versions), Nation's congruence formula, the A/B/C relations on $\mathbf{J}(\mathbf{L})$, splitting lattices, conjugate equations, the rank-bounded weak atomicity (Chapter IV).

### Chapter V — deep-dive additions

**Nation 1982** *Finite sublattices of a free lattice* (Trans. AMS 269, 311–337) is the chapter's central source. The paper proved Jónsson's 1960s conjecture — left as unpublished notes — that finite SD + (W) suffices for sublattice-of-free embedding. The main innovation: the B-type sequence framework (Lemma 5.41 in our companion).

**Kostinsky 1972** *Projective lattices and bounded homomorphisms* (Pacific J. Math. 40, 111–119) is the chapter's other foundational paper — the first characterization of finitely-generated projective lattices as bounded + (W). Theorem 5.7 (Freese-Nation) generalizes to arbitrary cardinalities, with finite separability replacing "finitely generated".

**Davey-Poguntke-Rival** [21] proved Theorem 5.56 (6 forbidden sublattices for SD). Their result is the SD-side of the forbidden-lattice characterization.

**Antonius-Rival** [6] extended to Theorem 5.58 (8 forbidden sublattices for finite-sublattice-of-FL), adding $\mathbf{L}_7, \mathbf{L}_8$ as (W)-failure witnesses.

**Ježek-Slavík 1989** [76] classified all primitive lattices: every primitive lattice arises from the four starter primitives $\mathbf{A}_1, \mathbf{A}_2, \mathbf{A}_3, \mathbf{A}_4$ and the six infinite families $\mathbf{B}_n$ through $\mathbf{G}_n$ via the five constructions $\mathbf{R}, \mathbf{P}, \mathbf{P}^*, \mathbf{Q}, \mathbf{Q}^*$. They also independently proved Jónsson's conjecture for SUBDIRECTLY IRREDUCIBLE S-lattices (a special case of Theorem 5.55), via different methods.

**R.A. Dean** [34] originally studied $\mathbf{FL}(\mathbf{P})$, showing the word-problem algorithm (Theorem 5.19) extends to ordered-set generators.

**H.L. Rolf** [124] constructed diagrams of $\mathbf{FL}(\mathbf{2 + 2})$ and $\mathbf{FL}(\mathbf{1 + 4})$ (Figure 5.3); also proved the threshold theorem for $\mathbf{FL}(\mathbf{n_1 + n_2})$ containing $\mathbf{FL}(3)$.

**Galvin-Jónsson** [65] characterized distributive sublattices of free lattices: a distributive lattice embeds in some $\mathbf{FL}(X)$ iff it is a countable union of sublattices each isomorphic to a 1-element lattice, an 8-element Boolean algebra, or a direct product of a 2-element chain and a countable chain.

**Reinhold** [114] introduced *-distributivity (a strengthening of upper continuity), proving sublattices of free lattices are staircase and dually staircase distributive (Theorem 5.66, Corollary 5.67).

### Chapter V — terminology traps

"Projective" overloads:
- *Projective lattice* — the categorical definition (Theorem 5.1's universal property).
- *Projective in a variety* — sometimes used to mean "free in a variety", but the monograph uses the categorical sense throughout.
- For finite lattices, projective = sublattice of free (Corollary 5.11). For infinite, this is NOT TRUE in general — the chain $\omega$ is projective but not finitely generated.

"Retract" vs "sublattice":
- Every retract of $\mathbf{K}$ is a sublattice of $\mathbf{K}$ (the transversal $g$ is an embedding).
- The CONVERSE FAILS in general: a sublattice need not be a retract.
- For free lattices: "retract of $\mathbf{FL}(X)$" = projective lattice; "sublattice of $\mathbf{FL}(X)$" includes more (e.g., infinite distributive lattices in $\mathbf{FL}(\omega)$).

"Bounded" overloads (continued from Chapter II):
- McKenzie's *bounded homomorphism* — has both $\beta$ (least preimage) and $\alpha$ (greatest preimage).
- McKenzie's *bounded lattice* — a finitely-generated lattice with bounded $\mathbf{FL}(X) \to \mathbf{L}$.
- ORDER-THEORETIC *bounded lattice* — has 0 and 1.
- The chapter uses the McKenzie sense throughout.

"$\mathbf{FL}(\mathbf{P})$":
- $\mathbf{FL}(\mathbf{P})$ is the free lattice generated by an ordered set $\mathbf{P}$.
- When $\mathbf{P}$ is an antichain, $\mathbf{FL}(\mathbf{P}) = \mathbf{FL}(|P|)$ — the ordinary free lattice.
- For non-antichain $\mathbf{P}$, $\mathbf{FL}(\mathbf{P})$ is "smaller" than $\mathbf{FL}(|P|)$ — the order on generators imposes additional relations.
- Example: $\mathbf{FL}(\mathbf{2 + 2})$ is infinite, but Rolf showed it does NOT contain $\mathbf{FL}(3)$ as a sublattice — the structural threshold is exact at $n_1 n_2 = 5$.

"$A_1, A_2, B_1, B_2$" subdivisions (Chapter V §3 proof technical):
- These are subdivisions of the C-relation's $A$ and $B$ components introduced for Nation's proof.
- They are NOT used elsewhere in the monograph.
- The Figure 5.4 diagrams clarify the pictorial content of each case.
- The B-type sequence framework (Definition before Lemma 5.41) further generalizes by NOT requiring B-adjacency.

"S-lattice" vs "finite SI projective":
- "S-lattice" is the monograph's shorthand for "finite SD + (W)" — used in §3.
- "Primitive lattice" is "finite SI projective" — used in §5.
- By Lemma 5.35 + Theorem 5.55, every S-lattice is projective; by Theorem 5.61, primitive = finite SI sublattice of FL.
- So: S-lattice ⊋ primitive (S-lattices need not be SI; primitives are S-lattices that are also SI).

"Finitely separable":
- A condition on the LATTICE ITSELF (or ordered set), NOT on a homomorphism.
- It says: comparability $a \le b$ has a finite combinatorial witness $A(a) \cap B(b) \neq \emptyset$.
- Free lattices are finitely separable (Lemma 5.5).
- Countable lattices are automatically finitely separable.
- Used as Theorem 5.7's 4th condition for projectivity.

"*-distributive" vs "staircase distributive":
- *-distributive: $\bigvee(a * B) = a \wedge \bigvee B$ for ANY subset $B$ with existing $\bigvee B$.
- Staircase distributive: same, but only for FINITE subsets $B$.
- Free lattices are *-distributive (and dually); sublattices of free lattices are staircase distributive (and dually) but not necessarily *-distributive.
- *-distributivity strictly strengthens upper continuity.

"Forbidden lattices $\mathbf{L}_1, \ldots, \mathbf{L}_8$":
- Six lattices ($\mathbf{L}_1, \ldots, \mathbf{L}_6$) characterize SD failure.
- Eight lattices ($\mathbf{L}_1, \ldots, \mathbf{L}_8$) characterize finite-sublattice-of-FL failure.
- The numbering preserves the SD-side six; $\mathbf{L}_7, \mathbf{L}_8$ are added for the (W) condition.
- Figure 5.8 diagrams all eight.

### Chapter VI — Totally Atomic Elements — terms introduced new

totally atomic (= both lower atomic AND upper atomic) · subelement of $w$ (recap from Chapter I — a subterm in the canonical-form expression) · the σ-endomorphisms $\sigma_u(x) = x \vee u$ for all generators $x$ · the μ-endomorphisms $\mu_u(x) = x \wedge u$ · the set $G$ — smallest containing $X$ closed under $\sigma_x, \mu_x$ for fresh $x$ · "fresh generator" (one not occurring in the canonical representation of $w$) · meet-reducible / join-reducible totally atomic elements · the canonical-form expression $w = \mu_{p_{n+1}} \sigma_{s_n} \mu_{p_n} \cdots \sigma_{s_2} \mu_{p_2} \sigma_{s_1}(p_1)$ for totally atomic $w$ · Stirling numbers of the second kind $S(r, k)$ · the φ_t partial-composition notation in §2 · $B_t$, $A_{ti}$, $E$ — auxiliary κ-formula expressions · $\overline{\kappa}(w)$ — the recursive definition of $\kappa(w)$ for totally atomic $w$ · cover-witness (the unique canonical joinand $w_1$ of $w$ not below $a$, given a covering pair $w \succ a$) · the "no $v$ exists" technical theorem (Theorem 6.31) used in Chapter VIII.

### Chapter VI — terms recapped

Carries forward EVERYTHING from Chapters I–V. Crucially: the κ-bijection (II.54–II.55, III.3), completely (join/meet) irreducible elements, lower atomic / upper atomic from Chapter III, $\mathbf{L}^\vee(w)$ and $\mathbf{L}^\wedge(w)$ from Chapter III, the syntactic κ-formula (Theorem 3.32) which Theorem 6.21 transforms into canonical form, Theorem 3.4 (canonical-meetand uniqueness) used in Lemma 6.9.

### Chapter VI — deep-dive additions

The $G$ construction is the chapter's central technical device. Its bottom-up structure mirrors the Mason-Stallings-style "complement" construction in free groups, but adapted to lattices: a finite alphabet of generators, two unary operations (σ, μ), a freshness condition. The result: a finite set characterized recursively, providing FINITARY SPINE for an infinite lattice.

**Reinhold's *-distributivity** (Chapter V Theorem 5.66) and **Day's rank-bounded weak atomicity** (Chapter IV Theorem 4.1) are background used implicitly. Chapter VI doesn't introduce new structural-theorem machinery; it APPLIES Chapters I–V's machinery to derive a clean classification.

The **automorphism action of permutations of $X$** on $\mathbf{FL}(X)$ — from Corollary 1.6 of Chapter I — is heavily used in Chapter VI. Corollary 6.12 specifically uses automorphisms to simplify the analysis of canonical meetands of totally atomic elements.

The Stirling-number-2 connection is unusual in lattice theory. The closed-form count formula in Corollary 6.11 is one of the few cases in the monograph where a structural classification yields an EXPLICIT combinatorial expression — most other classifications give characterizations (like Nation's theorem) without exact counts.

### Chapter VI — terminology traps

"Lower atomic" vs "upper atomic" vs "totally atomic":
- *Lower atomic*: every $u < a$ has a cover-witness $v$ with $u \le v \prec a$.
- *Upper atomic*: every $b > a$ has a cover-witness $c$ with $a \prec c \le b$.
- *Totally atomic*: BOTH lower atomic AND upper atomic.
- These are different! Lower atomic = "covers from above are dense"; upper atomic = "covers from below are dense"; totally atomic = both.

"Subelement" overload:
- *Subelement of $w$* (Chapter VI usage, recapped from Chapter I): a subterm in the canonical-form representation of $w$.
- Sometimes confused with "sub-element" in the Hasse-diagram sense (an element $\le w$). The monograph uses "subelement" exclusively in the canonical-form sense.

"$\sigma_u, \mu_u$" notation:
- $\sigma_u$ and $\mu_u$ are ENDOMORPHISMS of $\mathbf{FL}(X)$, defined by their action on generators: $\sigma_u(x) = x \vee u$ and $\mu_u(x) = x \wedge u$.
- For an element $u$, $\sigma_u(w) = w \vee u$ and $\mu_u(w) = w \wedge u$ — but only after extending via the homomorphism property.
- Distinct from generic σ-meaning-arrow or σ-algebra notation.

"Freshness condition":
- In the $G$ construction: $x \in X$ is "fresh" with respect to $w$ if $x$ does not occur in the canonical representation of $w$.
- "Fresh" depends on $w$, not just on $X$.
- The same generator can be "fresh" with respect to one element and "not fresh" with respect to another.

"$G$" — overloaded letter, but fixed meaning here:
- In Chapter VI, $G$ denotes the chapter's specific recursive set (totally atomic elements).
- In other chapters / contexts, $G$ might denote something else (a Galois group, a graph, etc.).
- The chapter is self-contained: $G$'s meaning is fixed throughout.

"Cover-witness" (Theorem 6.24):
- For a covering pair $w \succ a$ with $w$ completely meet irreducible: the unique canonical joinand $w_1$ of $w$ such that $w_1 \not\le a$.
- Theorem 6.24 says: every cover-witness is totally atomic.
- The "unique" comes from Theorem 3.4 of Chapter III (canonical-meetand uniqueness — applied dually here for canonical joinands).

"Stirling number $S(r, k)$":
- The number of ways to partition an $r$-element set into $k$ NONEMPTY blocks.
- $S(0, 0) = 1$ (the empty partition of the empty set).
- $S(r, 0) = 0$ for $r > 0$.
- $S(r, k) = 0$ for $k > r$.
- Used in Corollary 6.11's count formula for totally atomic elements.

### Chapter VII — Finite Intervals and Connected Components — terms introduced new

chains of covers (a sequence $a_0 \prec a_1 \prec \cdots \prec a_n$); finite interval (a $w/u$ interval that is finite as a sublattice); 3-element interval; "maximal three-element chain in an interval"; the 6 finite-interval forms (Figure 7.3); singular element (foreshadowing Chapter VIII — completely join irreducible $v$ with $\kappa(v) = v_*$); labeled ordered set (poset with cover-pairs labeled 0 or 1); cover label 0 (induced-order cover but NOT a cover in $\mathbf{FL}(X)$, drawn dotted); cover label 1 (cover in $\mathbf{FL}(X)$, drawn solid); interpretation of a labeled ordered set in $\mathbf{FL}(X)$ (order isomorphism preserving cover-vs-non-cover distinction); $\overline{\mathbf{N}}_5$ (the labeled pentagon — covers labeled 1 except atom-to-coatom edge labeled 0); $\overline{\mathbf{N}}_5(k)$ ($k$ copies of $\overline{\mathbf{N}}_5$ identified at common bottom + middle); $\mathbf{C}(m, k)$ (chain bouquet — $m$ chains of length 2 + $k$ chains of length 1, top-identified, all labels 1); the Theorem 7.9 recipe for 3-element intervals; the slim-element-based infinite families (Examples 7.12, 7.13).

### Chapter VII — terms recapped

Carries forward EVERYTHING from Chapters I–VI. Crucially: connected component of an element (Chapter III §7), Examples 3.43-3.45 (specific connected components), totally atomic + Theorem 6.10 (Chapter VI), Theorems 6.24, 6.25, 6.27, 6.30, 6.31 (the structural-role theorems of Chapter VI), Theorem 3.4 (canonical-meetand uniqueness), Theorem 3.5 (cover bijection γ), Theorem 3.34 (canonical meetands of $w_*$).

### Chapter VII — deep-dive additions

The chapter has two distinct historical sources. **Freese-Nation 1985** ("Covers in free lattices", Trans. AMS 288, 1–42) provides §1-3: chains of covers, finite intervals, three-element intervals. The Freese-Nation paper organized the cover algorithm together with these structural results — chains-of-covers analysis was a natural continuation of the cover algorithm.

**Freese 1985** ("Connected components of the covering relation in free lattices", in <em>Universal Algebra and Lattice Theory</em>, Springer LNM 1149, pp. 82-93) provides §4. Freese's paper introduced the labeled-ordered-set framework specifically for the connected-component classification. The label-0/1 distinction (cover in free lattice vs. non-cover despite induced-order adjacency) is needed because connected components of $\mathbf{FL}(X)$ are partially-ordered ALSO by the cover-relation graph topology, not just by lattice order.

The **labeled-ordered-set framework** is a combinatorial novelty. A footnote on book p. 161 notes: "A better term might be a *covers labeled ordered set* since combinatorists use the term *labeled ordered set* to mean an ordered set whose elements are labeled." The chapter's terminology (labeling COVERS, not ELEMENTS) is specific to the lattice-theoretic application.

The **pentagon's recurrence** through the monograph: Example 3.43 (connected component of a generator = $\mathbf{N}_5$), Theorem 5.55 (Nation's theorem — $\mathbf{N}_5$ is a primitive lattice), Theorem 7.32 here (every non-(0/1)/non-Boolean connected component is built from $\overline{\mathbf{N}}_5$ or $\mathbf{C}(m, k)$). The pentagon is one of the "atoms" of the structural classification of $\mathbf{FL}(X)$.

### Chapter VII — terminology traps

"Chain of covers" vs "chain in the lattice":
- A *chain of covers* is a sequence $a_0 \prec a_1 \prec \cdots \prec a_n$ where each consecutive pair is a covering pair.
- A *chain in the lattice* is a sequence $a_0 < a_1 < \cdots < a_n$ — order-comparable but not necessarily cover-related.
- Theorem 7.2 bounds CHAIN-OF-COVERS length at 5 in $\mathbf{FL}(3)$, 4 in $\mathbf{FL}(n \ge 4)$. But chains-in-the-lattice can be much longer (even infinite — Theorem 1.27 says no uncountable chains, but countable infinite chains exist).

"Length" overloads:
- *Length of a chain of covers* = number of cover-relations = $n$ (in the chain $a_0 \prec a_1 \prec \cdots \prec a_n$).
- *Size of the chain* = number of elements = $n + 1$.
- The monograph uses both interchangeably; context distinguishes.

"Connected component" vs "connected component of an element":
- The *connected components* of a lattice's cover-relation graph are equivalence classes under "reachable via covers".
- The *connected component of an element $a$* is the equivalence class containing $a$.
- For a generic element of $\mathbf{FL}(X)$: connected component is small (often just the 4 forms of Theorem 7.32). For $0$ or $1$: large (e.g., 11 elements in $\mathbf{FL}(3)$).

"Labeled ordered set" — covers labeled, NOT elements:
- The chapter's "labeled" refers to COVERS (edges), not ELEMENTS (vertices).
- Combinatorists' standard "labeled poset" = poset with labeled elements.
- The chapter's footnote on book p. 161 acknowledges this conflict.

"Interpretation" specifically:
- An interpretation of $\mathbf{P}$ in $\mathbf{FL}(X)$ is an order-isomorphism onto a connected component PRESERVING the cover-label structure (label 1 ↔ cover in $\mathbf{FL}(X)$, label 0 ↔ non-cover).
- Without the cover-preserving condition, the order-isomorphism might exist but NOT be an "interpretation".

"$\mathbf{C}(m, k)$" notational convention:
- $m$ = number of length-2 chains.
- $k$ = number of length-1 chains.
- All chains share the SAME TOP (greatest element identified).
- All labels are 1 (every cover-pair is a cover in $\mathbf{FL}(X)$).
- $\mathbf{C}(0, 0)$ = the 1-element ordered set.
- $\mathbf{C}(1, 0), \mathbf{C}(2, 0)$ are EXCLUDED from Theorem 7.32 (Lemmas 7.30, 7.31 show they don't occur as connected components).

"Singular element" (Chapter VII §1 footnote, formal definition in Chapter VIII):
- A completely join irreducible element $v$ with $\kappa(v) = v_*$.
- Theorem 8.6 (forthcoming): singular elements occur only at the very top and bottom of $\mathbf{FL}(X)$.
- Used implicitly in Theorem 7.2's proof but NOT cited there (because Theorem 7.2 is needed in Theorem 8.6's proof — circular dependency avoided).

### Chapter VIII — Singular and Semisingular Elements — terms introduced new

singular element (completely-join-irreducible $w$ with $\kappa(w) = w_*$); singular cover (the cover $w_* \prec w$ when $w$ is singular — top is meet, bottom is join); semisingular element (completely-join-irreducible $w$ with $\kappa(w) \le w_i$ for some canonical meetand $w_i$); convention: when $w$ is semisingular, $w_1$ is the canonical meetand with $\kappa(w) \le w_1$; convention: $w_{i1}$ is the unique canonical joinand of $w_i$ such that $w_{ij} \not\le w_*$ (one per $i$, by Theorem 3.4); the "useful test" of Corollary 8.5; the 4-case proof structure with phantom cases ii and iii.

### Chapter VIII — terms recapped

Carries forward EVERYTHING from Chapters I–VII. Crucially: Theorem 6.30 (interval $\kappa(w)/w_*$ has no completely-join-irreducible if $\kappa(w)$ not totally atomic) — central to Case iv of Theorem 8.1's proof. Theorem 6.31 (the "no v" theorem) — finally finds its semantic motivation here in Cases ii and iii. Theorem 7.2 (chain-of-covers bound) — used in Theorem 8.6's proof. Theorem 7.6 (3-element-interval structural test) — used in Theorem 8.1's case-i reduction. Theorem 7.10 (3-element-interval classification) — used in Corollary 8.5's structural argument. Lemma 7.1 (canonical-joinand-of-meetand structure) — central to Theorem 8.6's location result.

### Chapter VIII — deep-dive additions

**Freese-Ježek-Nation-Slavík 1986** ("Singular covers in free lattices", Order 3, 39–46) is the chapter's foundational source — paper [58] in the monograph's bibliography. The paper introduced the term "singular cover" specifically for the situation where the top of a covering pair $w_* \prec w$ is a meet (i.e., $w$ completely-join-irreducible) AND the bottom is a join (i.e., $w_* = \kappa(w)$ completely-meet-irreducible). The paper's main result was Theorem 8.6.

The monograph's improvement over the 1986 paper: a cleaner proof using the totally-atomic-element machinery from Chapter VI (especially Theorem 6.30) and the chain-bound from Theorem 7.2. The cleaner proof is roughly 2 pages; the 1986 paper's proof was about 6 pages. This pattern — original paper provides the result, monograph synthesizes with cleaner proof — recurs throughout the monograph (e.g., Nation 1982's S-lattice proof in Chapter V, Day 1979's weak-atomicity in Chapter II §7).

The **circular-dependency pair** between Theorem 7.2 and Theorem 8.6 deserves special note. Theorem 7.2's proof (Case 2) needs to know singular elements are confined to the connected components of 0/1, but Theorem 8.6 (which proves this) uses Theorem 7.2 as input. The monograph organizes the proofs so Theorem 7.2 is proved WITHOUT explicit citation of Theorem 8.6 (using Lemma 7.1 + Theorems 6.24, 6.25 directly), then Theorem 8.6 follows USING Theorem 7.2. Chapter VIII §2 is the "completion" that closes the circular dependency in a one-way order.

The **phantom-case pattern** in Theorem 8.1's 4-case proof. Cases ii and iii would correspond to specific canonical-form configurations, but those configurations are forbidden by Theorem 6.31. So out of 4 cases, only 2 actually occur. This is the chapter's structural cleanness — a 2-fold dichotomy (singular OR 3-element-interval-middle) emerges from a 4-case analysis where 2 cases are "phantoms".

The **Tschantz preview**. Corollary 8.7 is "too easy not to include" as Chapter VIII's bridge to Chapter IX. The full Tschantz theorem (every infinite interval contains a copy of $\mathbf{FL}(\omega)$) requires Chapter VIII's tools (especially Corollary 8.5) used dozens of times in the construction.

### Chapter VIII — terminology traps

"Singular" overloads:
- *Singular cover*: a cover $a \succ b$ where $a$ is completely-join-irreducible (= meet structure on top) and $b = \kappa(a)$ is completely-meet-irreducible (= join structure on bottom).
- *Singular element*: the top $a$ of a singular cover. Equivalently: a completely-join-irreducible $w$ with $\kappa(w) = w_*$.
- These are essentially the same concept from two angles — singular cover IS the cover relation, singular element IS the top element. The monograph uses both terms.

"Semisingular" vs "singular":
- *Singular*: $\kappa(w) = w_*$ (κ-image IS lower cover).
- *Semisingular*: $\kappa(w) \le w_i$ for SOME canonical meetand (κ-image is below at least ONE canonical meetand).
- Singular ⟹ Semisingular (since $\kappa(w) = w_* \le w$ implies $\kappa(w) \le w_i$ for ALL canonical meetands).
- Semisingular ⟹ Singular OR 3-element-interval-middle (Theorem 8.1).

"$w_{i1}$" notation:
- For completely-join-irreducible $w = \bigwedge w_i$ canonically with each $w_i = \bigvee_j w_{ij}$ canonical, $w_{i1}$ is the unique canonical joinand of $w_i$ such that $w_{ij} \not\le w_*$.
- The "1" subscript is a CONVENTIONAL renumbering, not necessarily indicating the first joinand in some natural order.
- Distinct from the $w_1$ semisingular-convention (which renumbers the canonical meetand with $\kappa(w) \le w_1$).

"$\kappa(w)$" vs "$w_*$":
- For non-singular $w$: $\kappa(w) \neq w_*$ (these are two distinct elements).
- For singular $w$: $\kappa(w) = w_*$ (these are equal).
- Corollary 8.5's "if $\kappa(w) \neq w_*$" condition implicitly says "if $w$ is not singular".

"The phantom cases":
- Cases ii and iii of Theorem 8.1's proof don't actually occur — they're "phantoms" forbidden by Theorem 6.31.
- The proof STILL covers them via case analysis to derive contradictions. The "phantom" status is an after-the-fact conclusion.
- This is different from "skipping" cases: each phantom case is fully analyzed; the conclusion is "this case leads to a contradiction".

"Singular cover example":
- The example "the meet of two coatoms is a singular element" (book p. 171) refers to: in $\mathbf{FL}(X)$, the element $\overline{x_i} \wedge \overline{x_j}$ for $i \neq j$ is singular (completely join irreducible with $\kappa(w) = w_*$).
- The κ-image is the corresponding pairwise atom join $\underline{x_i} \vee \underline{x_j}$.
- This places these singular elements in the connected component of 1 (top) of $\mathbf{FL}(X)$ for $|X| \ge 3$.

### Chapter IX — Tschantz's Theorem and Maximal Chains — terms introduced new

$\mathbf{Q}(u, v)$ — the witness set $\{q$ completely-join-irreducible : $q \le u, v \le \kappa(q)\}$; $K$ — the obstruction set $\{q$ completely-join-irreducible : $q$ or $\kappa(q)$ totally atomic$\}$; κ-incomparable pair (a pair $q, q'$ with $q \le \kappa(q'), q' \le \kappa(q)$); κ-incomparable sequence (extended to infinite); coverless element (recapped formal definition from Example 3.39); dense maximal chain (a maximal chain with no covers); the lattice embedding notation $\sigma : \mathbf{FL}(X) \rightarrowtail \mathbf{FL}(Y)$; Tschantz's theorem (Theorem 9.10); Tschantz's coverless construction (Theorem 9.12 + the 11-generator witness $w$); the dense-maximal-chain construction (Theorem 9.15).

### Chapter IX — terms recapped

Carries forward EVERYTHING from Chapters I–VIII. Crucially: Day's theorem (Theorem 4.1, the rank-bounded version) — central. Theorem 5.59 (meet-SD lattice without infinite chains is finite) — used in Theorem 9.10's proof. Whitman's $\mathbf{FL}(\omega) \hookrightarrow \mathbf{FL}(3)$ (Theorem 1.28) — used to derive the FL(ω) embedding. Corollary 1.13 (3-element irredundant generation criterion) — used in Theorem 9.10's final step. Totally atomic + Theorem 6.10 + Corollary 6.11 (finiteness of $K$). <strong>Theorem 8.1, Theorem 8.6, Corollary 8.5</strong> from Chapter VIII — all heavily used. Continuity (Theorem 1.22) — used in §3 for the limit construction.

### Chapter IX — deep-dive additions

**Tschantz 1990** ("Infinite intervals in free lattices", Order 6, 367–388) is the chapter's central source. The paper introduced the result that every infinite interval $u/v$ in $\mathbf{FL}(X)$ contains a sublattice isomorphic to $\mathbf{FL}(Y)$ for $|Y| \le |X| + \aleph_0$. Tschantz's original proof was substantially longer than the monograph's version; the simplification uses Chapter VIII's Corollary 8.5 (the "useful test") as a structural shortcut.

The **historical sequence** that culminated in Tschantz's theorem: Day 1979 (qualitative weak atomicity, Chapter II §7); Freese-Nation 1985 (rank-bounded weak atomicity, Chapter IV; cover algorithm, Chapter III; chain-of-covers bound + finite-interval classification, Chapter VII §1-3); Freese 1985 (connected-component classification, Chapter VII §4); Freese-Ježek-Nation-Slavík 1986 (singular cover characterization, Chapter VIII); Tschantz 1990 (infinite-interval result, Chapter IX). Each result builds on the previous.

The **Q(u, v) framework** is Tschantz's central technical innovation. By reformulating Day's theorem as a set-theoretic statement about $\mathbf{Q}(u, v)$, Tschantz enabled COUNTING and MONOTONICITY arguments that would not be available with the original "exists $q$" formulation. The monotonicity $\mathbf{Q}(u', v') \subseteq \mathbf{Q}(u, v)$ for shrinking intervals is what supports the inductive constructions in Lemmas 9.4-9.6 + Theorems 9.5, 9.8, 9.9.

The **K-set as the obstruction**. The pattern "shrink the witness set to avoid K, then show infinite cardinality" is Tschantz's structural approach. The finiteness of $K$ (Corollary 6.11 of Chapter VI) is what makes this approach feasible: a finite obstruction set can be systematically avoided by tightening the comparison interval.

The **dense maximal chain construction (Theorem 9.15)** was unexpected. It shows that the structural intuition "maximal chains follow covers" — true in finite lattices — fails in $\mathbf{FL}(X)$ for sufficiently rich infinite intervals. The construction uses Theorem 9.12 (every infinite interval has coverless elements) as the building block: insert a coverless element at each step where a cover would otherwise force the chain through.

### Chapter IX — terminology traps

"$\mathbf{Q}(u, v)$" notational convention:
- $q \in \mathbf{Q}(u, v)$ requires THREE conditions: $q$ completely-join-irreducible, $q \le u$, AND $v \le \kappa(q)$.
- The κ-condition $v \le \kappa(q)$ is what makes $\mathbf{Q}(u, v)$ meaningful as a "witness set" for $u \not\le v$.
- Monotonicity: $\mathbf{Q}(u', v') \subseteq \mathbf{Q}(u, v)$ when $u' \le u$ AND $v' \ge v$ (note the OPPOSITE direction for $v$).

"$K$" overloads:
- In this chapter, $K$ specifically means the obstruction set $\{q$ completely-join-irreducible : $q$ or $\kappa(q)$ totally atomic$\}$.
- This is DIFFERENT from the $K(a)$ set used in Chapter II's κ-definition ($K(a) = \{u : u \ge a_*, u \not\ge a\}$ used to define $\kappa(a) = \bigvee K(a)$).
- And different from $\mathbf{K}(w)$ from Chapter III's syntactic algorithm ($\mathbf{K}(w) = \{v \in \mathbf{J}(w) : w_\dagger \vee v \not\ge w\}$).
- Context disambiguates; the chapter uses unadorned $K$ for the obstruction set.

"κ-incomparable":
- A pair $q, q'$ with $q \le \kappa(q')$ AND $q' \le \kappa(q)$.
- This does NOT mean $q$ and $q'$ are incomparable in the lattice order — they could be order-comparable.
- "κ-incomparable" specifically refers to the κ-image relationship: NEITHER's κ-image dominates the other.
- Theorem 9.8: such pairs exist in infinite $\mathbf{Q}(u, v)$.

"Coverless" specifically:
- An element with NO upper cover AND NO lower cover.
- Distinct from "no lower cover" alone (Dean's element in Example 3.36 has no lower cover but DOES have upper covers).
- Example 3.39 was the first historical instance; Theorem 9.12 makes the result systematic.

"Dense maximal chain":
- A maximal chain in $c/d$ where every element other than $c, d$ is coverless.
- "Dense" in the sense of "no gaps filled by covers" — the chain is structurally continuous in the sense that consecutive elements are not in cover-relation.
- Distinct from "dense in topology" — though there's a structural analogy.

"Tschantz's theorem" overloads:
- Theorem 9.10 (the FL(ω) result).
- Corollary 9.11 (the FL(Y) for |Y| ≤ |X| + ω generalisation).
- Sometimes referenced informally as "Tschantz" without specifying which.

The publication date of Tschantz's paper:
- Tschantz 1990 (Order 6, 367–388) is the correct citation.
- The chapter's bibliography lists [131] for this paper.
- I had previously stated "Tschantz 1992" in earlier chapters of the companion (Chapters IV, IX foreshadowing); the correct year is 1990.

### Chapter X — Infinite Intervals — terms introduced new

Tschantz triple ($a, c, b$ with $a < c < b$, intervals $c/a, b/c$ both infinite, $c$ comparable with everything in $b/a$); Tschantz element (a $c$ for which a Tschantz triple exists); non-canonical-joinand element (join-irreducible not appearing as canonical joinand of others); $a^\partial$ (the anti-automorphism dual of $a$); self-dual under κ ($\kappa(a) = a^\partial$); middle element (incomparable with own dual); upper element ($a \ge a^\partial$); lower element ($a \le a^\partial$); minimal middle / minimal upper / maximal lower elements; splitting decomposition $\mathbf{FL}(X) = Y \cup (1/a) \cup (b/0)$; the "new" decomposition (1) with $a = \bigwedge x^*, b = \bigvee x_*$; the canonical κ-self-dual elements $a_1, a_2, a_3, a_4$ in $\mathbf{FL}(\{x, y, z\})$ (computer-found via LISP); 5 open problems (10.17, 10.18, 10.22, 10.23, 10.25).

### Chapter X — terms recapped

Carries forward EVERYTHING from Chapters I–IX. Crucially: <strong>Theorem 10.1 uses every tool from Chapters I–IX</strong> in its 9-page proof. <strong>Theorem 10.20 uses Theorem 10.1 critically</strong> (reduction via Tschantz-triple absence). <strong>Theorem 10.21's classification</strong> generalizes Lemma 1.4(4) (the classical decomposition). <strong>Theorem 10.24 + 10.26</strong> use Theorem 8.6 + Theorem 7.10. <strong>Lemma 10.19</strong> uses Theorem 7.4 + Theorem 7.2. The chapter is structurally a "synthesis" — applications of the Chapters I–IX toolkit to specific structural questions about infinite intervals.

### Chapter X — deep-dive additions

The chapter has a different character from Chapters I–IX. Where earlier chapters built up structural tools systematically, Chapter X APPLIES the toolkit to answer three SEPARATE questions:
1. Are there Tschantz triples? (Theorem 10.1: NO)
2. Which join-irreducibles fail to be canonical joinands? (Theorem 10.20: only 3 types)
3. How does $\mathbf{FL}(X)$ decompose into generators + filter + ideal? (Theorem 10.21: full classification)

The chapter ends with FIVE open problems — the most of any chapter in the monograph. This reflects that the structural picture, while comprehensive, has frontiers.

**Tschantz's 1990 conjecture.** Theorem 10.1 confirms a conjecture from Tschantz's same paper that established Theorem 9.10. Tschantz proved the main theorem (every infinite interval contains $\mathbf{FL}(\omega)$) but conjectured the no-Tschantz-triple result without proof. The monograph supplies the proof.

**Computer-assisted discovery.** The four explicit examples $a_1, a_2, a_3, a_4$ of κ-self-dual elements in $\mathbf{FL}(3)$ were discovered using a LISP program. This is one of the few places in the monograph where computer assistance is acknowledged for STRUCTURAL discovery (as opposed to verification). Problem 10.22 — whether infinitely many such elements exist — is OPEN.

**The κ(a) = a^∂ phenomenon.** Two distinct duality structures (κ-bijection from Theorem 3.3, anti-automorphism from generator-symmetry) AGREE for some elements. This is structurally curious: in general, the two duals are distinct. The κ(a) = a^∂ elements occupy the boundary in the middle/upper/lower-element framework (Theorem 10.24: minimal middle elements ⟺ κ(a) = a^∂).

**The classical vs new decomposition.** Lemma 1.4(4) (Chapter I): $\mathbf{FL}(X) = (1/\bigwedge Y) \cup (\bigvee(X-Y)/0)$ for nonempty proper $Y \subseteq X$. The "new" decomposition (1) of Chapter X §3: $\mathbf{FL}(X) = X \cup (1/a) \cup (b/0)$ where $a = \bigwedge x^*, b = \bigvee x_*$. Theorem 10.21 unifies BOTH as special cases of a parametric family.

### Chapter X — terminology traps

"Tschantz triple" vs "Tschantz element":
- *Tschantz triple* is the triple $a, c, b$ with the three structural conditions.
- *Tschantz element* is an element $c$ for which a Tschantz triple exists.
- Theorem 10.1: no Tschantz triples (and hence no Tschantz elements) exist.

"$a^\partial$" notation:
- The anti-automorphism dual of $a$.
- Defined for ALL elements of $\mathbf{FL}(X)$, not just completely-(join/meet)-irreducibles.
- Distinct from the κ-image $\kappa(a)$ (which is only defined for completely-join-irreducibles via the κ-bijection).
- The two CAN agree for specific elements: $\kappa(a) = a^\partial$.

"Middle element" vs "upper" vs "lower":
- *Middle element*: $a$ INCOMPARABLE with $a^\partial$.
- *Upper element*: $a \ge a^\partial$.
- *Lower element*: $a \le a^\partial$.
- These are exhaustive: every element is exactly one of the three (or both upper AND lower if $a = a^\partial$).
- Generators are simultaneously minimal upper AND maximal lower (boundary case under standard convention).

"Minimal middle" vs "minimal upper":
- *Minimal middle element*: a middle element with no smaller middle elements below it.
- *Minimal upper element*: an upper element with no smaller upper elements below it.
- Theorem 10.24: minimal middle = completely-join-irreducible with $\kappa(a) = a^\partial$.
- Theorem 10.26: only generators are minimal upper elements (no others).

"Splitting decomposition":
- A decomposition $\mathbf{FL}(X) = Y \cup (1/a) \cup (b/0)$ — generator-set + principal filter + principal ideal.
- Equivalent to a homomorphism $\mathbf{FL}(X) \to \mathbf{2}$.
- Theorem 10.21 classifies ALL such decompositions.
- Distinct from "splitting" in the variety-of-lattices sense (Chapter II's splitting lattices).

"Canonical decomposition (1)":
- The specific decomposition $\mathbf{FL}(X) = X \cup (1/a) \cup (b/0)$ with $a = \bigwedge x^*, b = \bigvee x_*$.
- The element $a$ has the curious property $\kappa(a) = a^\partial$.
- Generalizes Lemma 1.4(4); Theorem 10.21 fits this into a parametric family.

## Hyperlattice / Prologos cross-references

Same sketch as the Nation textbook companion's process notes. The monograph's deeper treatment of canonical form (Theorem 1.17), Day's doubling (Theorem 1.1), Whitman's algorithm (Theorem 1.11), continuity (Theorem 1.22), semidistributivity (Theorem 1.21) — each maps directly to a Prologos design pattern (canonical IR, doubling for compound cells, structural unification, fan-in CALM-safety, and semidistributive type lattice respectively).

## Stylistic discipline

- Same as the other companions: prose over bullets, active voice, name the proof strategy at the top, MathJax-friendly markup, light italics for emphasis.
- For Free Lattices: NO literary epigraph (the monograph has none). Each chapter opens with the monograph's own scope paragraph (paraphrased) to set context.
- "Worked exercises" replaced with "Computed examples and vignettes" — concrete computations of canonical forms, Whitman algorithm runs, fixed-point-free polynomial verifications, sublattice generations, etc., since this is a research monograph without exercise sections.

### Chapter XI — Computational Aspects of Lattice Theory — terms introduced new

Cover-relation count $e_\prec$; $n^{3/2}$ structural bound (Theorem 11.4); $O(n)$ SD-lattice cover-count (Theorem 11.5); $O(n^{5/2})$ lattice test (Theorem 11.6); $O(n^2 \log_2 n)$ SD/lower-bounded/splitting tests (Theorem 11.8); $J(L), M(L), \mathrm{ucov}(p), \mathrm{lcov}(m)$ (representation primitives); dependency relation $D$ (Theorem 11.13: $\mathrm{Con}(L)$ in $O(n^2)$); $J$-$M$ context table; lower-bounded test (Theorem 11.14); splitting-lattice characterization (Theorem 11.16); Bogart-Magagnosc $O(n^{5/2})$ chain-partition / antichain-cover; Mirsky's dual ($O(n^2)$); König-Egerváry ⟹ Dilworth; Hopcroft-Karp $O(E\sqrt V)$ bipartite matching; term-DAG hashing (Listing 11.10); Whitman with memoization (Listing 11.12); canonical-form check (Listing 11.13); $|s| \cdot |t|$ memoized-triple bound (Theorem 11.22); $O(\mathrm{can}(s)+\mathrm{can}(t))$ on canonical input (Theorem 11.23); Example 11.24 — exponential blowup for $L_2 \le u_2$; partial lattice; finitely-presented lattice $\mathbf{FL}(P), \mathbf{FL}_X(R)$; Skolem 1920 (polytime word problem); Cosmadakis 1988 ($O(n^4)$); Freese refinement ($O(n^3)$ via Listing 11.17); Theorem 11.34 ($\mathbf{FL}(P) \cong \mathbf{FL}(Q)$ iff $P \cong Q$); force-directed lattice diagrams; level-by-level Hasse layouts.

### Chapter XI — terms recapped

Carries forward the entire monograph's structural toolkit, but reframed algorithmically:
- Whitman's condition (W), originally Theorem 1.11 → Listings 11.12, 11.13 (Whitman with memoization, canonical form check).
- Canonical form (Theorem 2.10) → Listing 11.11 (computing canonical form), Listing 11.17 (canonical form for $\mathbf{FL}(P)$).
- κ-bijection (Theorem 3.3) → not directly algorithmic in this chapter, but the dependency relation $D$ on $J(L)$ (used in Theorem 11.13) is the finite analogue.
- Day's reflections (Theorem 1.1) → not directly algorithmic, but lower-bounded test (Theorem 11.14) is the algorithmic counterpart.
- Semidistributivity (Theorem 1.21) → Theorem 11.5 ($e_\prec = O(n)$ in SD), Theorem 11.8 (SD test in $O(n^2 \log n)$).
- Free lattices over partial lattices (Chapter II) → §9 (finitely-presented lattices, $\mathbf{FL}(P)$).
- Splitting lattices (Chapter II) → Theorem 11.16 (algorithmic characterization).

### Chapter XI — deep-dive additions

**Bridge from theory to implementation.** The chapter is the monograph's algorithmic capstone. Every preceding chapter's structural theorem becomes an algorithmic specification: Whitman's condition becomes pseudocode, canonical form becomes a recursion, κ-bijection becomes a dependency table, Day's reflections become a polynomial-time predicate. The chapter is the implementation guide that makes the structural theory operationally tractable.

**The $n^{3/2}$ cover-count bound is load-bearing.** Theorem 11.4 — that any $n$-element semilattice has at most $n^{3/2}$ cover relations — is the structural input that gates ALL the $O(n^{5/2})$ algorithms in §3 and §7. The bound is tight (matched by truncated Boolean lattices). Without it, the chapter's complexity claims would collapse to $O(n^3)$.

**Whitman's exponential blowup.** Example 11.24 demonstrates that Whitman's algorithm (Listing 11.12) with memoization can produce exponentially many memoized triples on adversarial input ($L_2 \le u_2$, where $L_2, u_2$ are derived from a 2-generator scheme). This is the structural motivation for Cosmadakis's $O(n^4)$ algorithm: rather than running Whitman directly, first compute canonical form, then check the canonical-form-specific structural inclusion. The polynomial-time guarantee comes from canonization, NOT from Whitman.

**Skolem 1920.** Skolem proved decidability of the word problem for finitely-presented lattices in 1920 — over 70 years before this monograph. His proof was by elimination of variables and was intractable for practical computation. Whitman 1941 rediscovered the result. Cosmadakis 1988 nailed down the polynomial bound at $O(n^4)$. The monograph's Listing 11.17 (Freese refinement) brings it to $O(n^3)$ via canonical form for $\mathbf{FL}(P)$.

**Bogart-Magagnosc reduction to bipartite matching.** Theorem 11.7 (chain partition / antichain cover): the minimum chain partition of an $n$-element ordered set can be computed in $O(n^{5/2})$ via reduction to maximum bipartite matching. The matching itself is solved by Hopcroft-Karp's algorithm in $O(E \cdot \sqrt V)$. By Dilworth's theorem (= König-Egerváry on the bipartite reduction), this also gives the maximum antichain. Mirsky's dual (max chain = min antichain partition) is much easier — $O(n^2)$ by simple level-numbering. The algorithmic asymmetry between Dilworth (chain partition, hard) and Mirsky (antichain partition, easy) is structurally interesting.

**Computer-generated diagrams.** §10 covers the practical art of drawing Hasse diagrams: force-directed embedding, level-by-level layouts, edge-crossing minimization. The chapter acknowledges this is "art, not science" — diagrams from automated layout often need human cleanup. The monograph's own diagrams were drawn by hand for clarity.

### Chapter XI — terminology traps

"Cover relation count $e_\prec$":
- The number of pairs $(a, b)$ with $a \prec b$ (i.e., $b$ covers $a$).
- For an $n$-element semilattice: at most $n^{3/2}$ (Theorem 11.4).
- For an $n$-element SD lattice: $O(n)$ (Theorem 11.5).
- For a general $n$-element lattice: at most $n^2 / 2$ (trivial bound).

"Lower bounded" vs "splitting":
- *Lower bounded*: a finite lattice $L$ such that every homomorphism $\mathbf{FL}(X) \to L$ (with finite generators) has a lower bound. Equivalent to Day's condition: $L$ is in $\mathbf{D}_\omega$ for some $\omega$.
- *Splitting*: a finite lattice $L$ that splits the variety of lattices, i.e., there exists a complementary variety. Equivalent: $L$ is finite, subdirectly irreducible, lower-bounded, and bounded.
- Splitting ⟹ lower-bounded; converse fails.

"Whitman with memoization" vs "canonical form check":
- *Whitman with memoization* (Listing 11.12): general $s \le t$ test, may be exponential (Example 11.24).
- *Canonical form check* (Listing 11.13): assumes $s, t$ already in canonical form, runs in $O(\mathrm{can}(s) + \mathrm{can}(t))$ (Theorem 11.23).
- The polynomial-time guarantees use canonization first, then check.

"Partial lattice" vs "finitely-presented lattice $\mathbf{FL}(P)$":
- *Partial lattice* $P$: a poset with some — not necessarily all — joins and meets defined.
- *Finitely-presented lattice* $\mathbf{FL}(P)$: the free lattice generated by $P$, respecting the partial-lattice operations defined on $P$. Equivalently: $\mathbf{FL}_X(R)$ where $X$ is the underlying set of $P$ and $R$ is the relation table encoding $P$'s defined operations.

"Skolem-Cosmadakis-Freese":
- Skolem 1920: word problem decidable.
- Cosmadakis 1988: polytime, $O(n^4)$.
- Freese (this monograph): $O(n^3)$ via canonical form for $\mathbf{FL}(P)$ (Listing 11.17).
- All three results give POLYTIME word problem; the differences are exponent and algorithmic technique.

"Dilworth" vs "Mirsky":
- *Dilworth's theorem* (1950): in any finite poset, max antichain size = min chain cover size. Algorithmic: $O(n^{5/2})$ via bipartite matching (Bogart-Magagnosc).
- *Mirsky's theorem* (1971, dual to Dilworth): max chain length = min antichain partition size. Algorithmic: $O(n^2)$ via level-numbering.
- The dual problems have asymmetric algorithmic complexity.

### Chapter XI — historical citations introduced

[14] Bogart-Magagnosc 1988 — Order 5, 51-58. The $O(n^{5/2})$ chain-partition / antichain-cover algorithm via reduction to Hopcroft-Karp bipartite matching.

[28] Cosmadakis 1988 — STOC. The first polytime ($O(n^4)$) word-problem algorithm for finitely-presented lattices.

[42] Day 1979 — the doubling construction (also in Chapters I–II of the monograph). Day's reflections become Listing 11.16 (lower-bounded test) algorithmically.

[59] Freese (this monograph) — the $O(n^3)$ refinement of Cosmadakis via canonical form for $\mathbf{FL}(P)$ (Listing 11.17).

[68] Hopcroft-Karp 1973 — SIAM J. Comput. 2, 225-231. Maximum bipartite matching in $O(E \sqrt V)$. Foundational for Bogart-Magagnosc.

[83] König 1931 — equivalence of König's theorem and Egerváry's theorem on bipartite-matching duality. Reduces Dilworth to bipartite matching.

[94] Mirsky 1971 — Amer. Math. Monthly 78, 876-877. The dual of Dilworth's theorem (max chain = min antichain partition).

[121] Skolem 1920 — Videnskapsselskapets skrifter. The original decidability proof for the word problem of finitely-presented lattices, via elimination of variables. Predates modern complexity theory by 40 years; the polytime improvement came with Cosmadakis 1988.

[134] Whitman 1941 — Ann. of Math. 42, 325-330. Whitman's condition (W) and the original $s \le t$ algorithm without memoization. Listing 11.12 in the monograph adds the memoization layer.

## Closing reflection — Free Lattices companion (Chapters I–XI complete)

With Chapter XI complete, the companion now covers the entire structural-and-algorithmic span of Freese-Ježek-Nation. The remaining chapter (XII: Term Rewrite Systems and Varieties of Lattices) is more specialized and can be added as a follow-up.

The 11-chapter arc:
- **Chapters I–II** establish Whitman's foundation: condition (W), canonical form, Day's doubling.
- **Chapters III–IV** prove the κ-bijection and the totally-atomic-element classification.
- **Chapter V** develops semidistributivity and the structural lemmas for finite intervals.
- **Chapter VI** classifies covers and 3-element intervals.
- **Chapters VII–VIII** handle singular and semisingular elements.
- **Chapter IX** proves Tschantz's theorem (every infinite interval contains $\mathbf{FL}(\omega)$) and the coverless-element existence theorem.
- **Chapter X** proves no Tschantz triples exist, classifies non-canonical-joinand join-irreducibles, and gives the splitting-decomposition classification.
- **Chapter XI** turns the entire toolkit into algorithms: $O(n^{5/2})$ for being a lattice, $O(n^2)$ for $\mathrm{Con}(L)$, $O(n^3)$ for the word problem of finitely-presented lattices.

The companion's 5-panel connection structure (P1-P5 per chapter) provided 55 cross-references threading the structural-and-algorithmic narrative. The Prologos panel (P5 in each chapter) sketched how the monograph's abstract lattice-theoretic concepts map to the concrete on-network architectural patterns of the Prologos compiler.

### Chapter XII — Term Rewrite Systems and Varieties of Lattices — terms introduced new

Term rewrite system (TRS); substitution; one-step rewrite $r \to_R t$; terminating TRS; convergent TRS; normal form $\mathrm{nf}_R(s)$; equational TRS $(E_0, R)$; regular equation; AC TRS; $E_0$-subterm; AC-subterm; terminal element; modified terminal (§3 weakening); $\underline{x}_i = \bigwedge_{j \ne i} x_j$; Lemma 12.7's four normal-form patterns (4)-(7); Theorem 12.8 (no AC TRS for $\mathcal{L}$); the locally-finite variety $\mathcal{U}$ of footnote 3 (Theorem 12.8 proof's lattices); term equivalence problem (TEP); $A_X(\mathbf{L})$; the practical $\gamma$-map; $\delta_\gamma$; $V(\mathbf{L})$-canonical form; the lattice family $\mathbf{L}_n = \mathbf{L}^\vee(x \wedge (y_1 \vee \cdots \vee y_n))$; rules (9)-(29) of the V(L₂) AC TRS; Figure 12.1's Venn-diagram method; Alimov's representation theorem [5] / Alimov-inspired construction (Lemma 12.22); the measure $|\cdot|$ with parameter $p = 5$ for V(L₂); the function $f : \mathbb{N} \times \mathbb{N} \to \mathbb{N}$ (associative, commutative, $f(n+1, m) \ge p \cdot f(n, m)$); Theorem 12.28 (V(L^∨(⋀ᵢ ⋁ⱼ x_{ij})) has AC TRS); Problem 12.27 (V(N₅) AC TRS open).

### Chapter XII — terms recapped

Carries forward Chapter II's lower-bounded-lattice machinery in detail: $\beta_h$, $\beta_0$, $\beta_f$ (the "least preimage" maps); $\mathfrak{M}^*(a)$ (minimal nontrivial join covers); $D$-rank ρ; $\mathrm{J}(\mathbf{L})$; $J$-closed subsets; $V(\mathbf{L})$ (variety generated by L); subdirectly irreducible lattices; $\mathbf{L}^\vee(w)$, $\mathbf{L}^\wedge(w)$ (lattices of joinands/meetands of $w$); $\mathbf{F}_{V(\mathbf{L})}(X)$ (relatively-free lattice). Carries forward Chapter III's $\mathbf{N}_5$ structural results: subdirectly irreducibles in V(N₅) are exactly $\mathbf{2}$ and $\mathbf{N}_5$; $\mathbf{F}_{V(\mathbf{N}_5)}(3) = 99$ elements. Carries forward Chapter I's Whitman canonical form (Theorem 1.18) — used pervasively to verify candidate normal forms. Carries forward Chapter XI's TEP / co-NP / undecidability landscape (Theorem 11.6 vs Bloniarz-Hunt-Rosenkrantz vs Freese 1980).

### Chapter XII — deep-dive additions

**The chapter's character: epilogue, not capstone.** Where Chapter XI is the algorithmic capstone (proves polynomial-time bounds), Chapter XII is the equational-theoretic <em>epilogue</em> — addressing not "can we decide?" but "can we decide LOCALLY via rewriting?" The answer for $\mathcal{L}$ is no (Theorem 12.8), via diagonalization. The answer for an infinite family of subvarieties is yes (Theorems 12.25, 12.28), via Venn-diagram-driven rule construction. The closing line of the monograph — "This pretty much reaches the limit of the simple ideas developed in this section" — quietly acknowledges that the next phase belongs to a new generation of techniques.

**The diagonalization in Theorem 12.8 is structurally rare.** Most "no AC TRS" results (e.g., for commutative groupoids) follow the simpler pattern of producing infinite chains. Theorem 12.8 instead produces a SINGLE term to which no rule can apply — neither directly nor via AC equivalence. The argument is local (about one term) rather than global (about chains). This rarity is structurally interesting: a TRS's failure to be terminating-convergent normally diagnoses via infinite chains; lattice theory's failure is the rarer kind, where shorter substitution-images of candidate rules are ALREADY in normal form (via Lemma 12.7's four patterns), leaving no room for any rule to apply.

**Footnote 3's hidden generalization.** The casual-looking footnote on p. 274 is a substantial result: there is a locally-finite variety $\mathcal{U}$ — generated by all $\mathbf{L}^\vee(w)$ and $\mathbf{L}^\wedge(w)$ where $w$ appears in the proof of Theorem 12.8 — such that every variety $\mathcal{V}$ with $\mathcal{U} \le \mathcal{V} \le \mathcal{L}$ has NO AC TRS. The negative result is not unique to $\mathcal{L}$; an entire interval of varieties shares it. This shifts the question from "lattice theory" to "what is the maximal lower variety with an AC TRS?" — the answer to which would settle Problem 12.27 in many cases.

**The Venn-diagram method (Figure 12.1).** §5's rule-derivation procedure deserves study as a general technique. For each canonical-form-violating pattern, draw a Venn diagram of the variable sets, label each non-empty sector with a representative variable, and substitute into the appropriate rewrite skeleton. The most-general rule from this construction can be specialized via "set sectors to 1" to produce all degenerate forms. The chapter applies this to derive rules (18)-(23), (24)-(29). The technique is a generic "case analysis" pattern that could be applied to any structural-rule derivation problem.

**Alimov's representation theorem [5] inspiration.** Lemma 12.22's measure construction is motivated by N. G. Alimov's 1950 result on cancellative totally ordered semigroups embedding into ℝ. The chapter does NOT invoke Alimov's theorem directly; it uses Alimov's TECHNIQUE — define $r : \mathbb{N} \to \mathbb{Q}$ inductively with self-similar interval subdivision so that addition closes, then $f(i,j) = r^{-1}(r(i) + r(j))$. This produces an AC-respecting measure with multiplicative growth — exactly what's needed to prove termination of the V(L₂) AC TRS. The construction is a beautiful example of how universal-algebra theorems can inspire concrete computational tools.

**The triadic asymmetry: structural / algorithmic / equational.** Chapter XII completes the monograph's three planes. Whitman canonical form is structurally optimal (Chapter I). It is algorithmically tractable (Chapter XI: polynomial time, even for finitely-presented lattices). It does NOT correspond to a finite local rewrite system (Chapter XII: Theorem 12.8). The three planes do not align — structural beauty does not imply algorithmic locality, algorithmic decidability does not imply equational rewritability. The infinite positive family in Theorem 12.28 shows the asymmetry is not universal: there is an infinite family where all three planes DO align, but it does not include $\mathcal{L}$ or even $V(\mathbf{N}_5)$.

### Chapter XII — terminology traps

"Canonical form" vs "normal form":
- *Canonical form* in Chapter XII is reserved for Whitman's canonical form (the structural minimal-length representative).
- *Normal form* refers to the output of a TRS — a term with no rules applicable.
- The two are different in general. Theorem 12.8 says: lattice canonical form does NOT correspond to any AC TRS normal form.
- For $V(\mathbf{L}_2)$, the chapter constructs an AC TRS whose normal form IS the V(L₂)-canonical form (Whitman canonical of the largest A_X(L₂)-element below).

"Convergent TRS" vs "terminating TRS":
- *Terminating*: no infinite rewrite chains.
- *Convergent*: terminating + every chain from $s$ ends in the same final term.
- A terminating TRS need not be convergent; the chapter's "AC TRS" is implicitly required to be convergent (otherwise the question "does an AC TRS exist?" is trivially yes via degenerate constructions).

"$E_0$-subterm" vs "subterm":
- *Subterm*: standard tree-substructure of a single term.
- *$E_0$-subterm*: a subterm of any term in the $E_0$-equivalence class. For AC TRS, AC-subterm allows rewriting via subterms of AC-equivalent reorderings.

"Lower bounded" — same definition across chapters:
- Same as Chapter II's definition (every homomorphism $\mathbf{FL}(X) \to \mathbf{L}$ has a $\beta_h$).
- Subdirectly irreducible + lower bounded + bounded ≡ splitting. (Note: Theorem 12.13 uses lower bounded for sublattice characterization; Theorems 12.14-12.16 specialize to $\mathbf{L}^\vee(v)$.)

"Variety generated by $\mathbf{L}^\vee(w)$" vs "$\mathbf{L}^\vee(w)$ itself":
- $\mathbf{L}^\vee(w)$ is a SINGLE specific lattice (the join-irreducibles of an interval).
- $V(\mathbf{L}^\vee(w))$ is the variety it generates — a class of lattices closed under sublattice, homomorphic image, direct product.
- Theorem 12.28 produces an AC TRS for the VARIETY, not for the single lattice.

"$\gamma$-map" vs "$\beta_h$ vs $\beta_0$":
- $\gamma$ is a partial map $\mathrm{J}(\mathbf{L}) \to X^\wedge$ given as DATA (not derived from a homomorphism a priori).
- $\beta_0$ is $\beta_h|_{\mathbf{L}}$ for a known homomorphism $h$.
- $\beta_h$ is the "least preimage" map of the FULL homomorphism.
- Lemma 12.15: $\gamma$ comes from SOME $h$ iff conditions (1) + (2) hold.
- Theorem 12.19 weakens (2) to (2'): $p \le q \implies \gamma(p) \le \gamma(q)$ (just order-preservation).
- $\delta_\gamma$ is the inductive extension of $\gamma$ from join-primes to all of $\mathrm{J}(\mathbf{L})$.

### Chapter XII — historical citations introduced

[5] N. G. Alimov 1950 — *Izv. Akad. Nauk SSSR Ser. Mat.* 14, 569-576. Basic representation theorem on totally-ordered cancellative semigroups embedding into the additive group of real numbers. Inspires Lemma 12.22's measure construction.

[12] Bloniarz, Hunt, Rosenkrantz (date as cited) — co-NP completeness of TEP for distributive lattices and any finite, nontrivial lattice. Earlier referenced in Chapter XI's complexity discussion.

[17] Burris-Lawrence — AC TRSs for certain finite rings. Parallel inquiry in a related universal-algebra setting.

[37] Dershowitz-Jouannaud 1990 — *Theoretical Computer Science* 60, 51-99 (revised in *Handbook of Theoretical Computer Science* B, ch. 6). The general reference on term rewriting that the chapter recommends.

[38] Dershowitz-Jouannaud-Klop 1991 — "Open Problems in Rewriting." In *Rewriting Techniques and Applications (RTA-91)*, LNCS 488, pp. 445-456. Problem 32 asks whether lattice theory has a finite, convergent AC TRS — answered negatively by Theorem 12.8.

[44] Trevor Evans 1951 — *Proc. Camb. Phil. Soc.* 47, 637-649. "On multiplicative systems defined by generators and relations, I: Normal form theorems." The first convergent term rewrite system, for quasigroups.

[49] Freese 1980 — Equational theory of modular lattices is undecidable.

[57] Freese-Ježek-Nation (cited but undated) — the paper containing the chapter's first three sections, with referee acknowledgment.

[64] Fuchs (cited) — reference for Alimov's theorem (textbook treatment).

[75] Ježek — TRS-like systems for groupoids.

[80] Jónsson — Jónsson's lemma: subdirectly irreducible lattices in V(L) are contained in HS(L) for finite L.

[85] Jouannaud-Kirchner 1986 — additional TRS reference recommended.

[91] Knuth-Bendix 1970 — *Computational Problems in Abstract Algebra* (Leech ed., Pergamon), pp. 263-297. "Simple word problems in universal algebras." The famous completion algorithm.

[93] Lankford-Ballantyne 1977 — equational TRS introduction.

[98] McKenzie — equational theory finitely based for finite lattices.

[108] Nation 1985 — preservation properties (D-rank, M(u) bounds) used in Theorem 12.20.

[111] Peterson-Stickel 1981 — *J. ACM* 28, 233-264. "Complete sets of reductions for some equational theories." AC TRS extension; convergent AC TRSs for free commutative groups, commutative rings with unit, distributive lattices.

[131] Tschantz — referenced for Lemma 12.2 (canonical-joinand inequality, essentially Lemma 3.28).

## Closing reflection — Free Lattices companion (ALL 12 chapters complete)

With Chapter XII complete, the companion now covers the entire 12-chapter monograph. The structural-and-algorithmic span is complete; the equational-theoretic epilogue closes the volume.

The 12-chapter arc:
- **Chapters I–II** establish Whitman's foundation: condition (W), canonical form, Day's doubling.
- **Chapters III–IV** prove the κ-bijection and the totally-atomic-element classification.
- **Chapter V** develops semidistributivity and Nation's classification of finite sublattices.
- **Chapter VI** classifies covers and 3-element intervals.
- **Chapters VII–VIII** handle singular and semisingular elements.
- **Chapter IX** proves Tschantz's theorem (every infinite interval contains $\mathbf{FL}(\omega)$) and the coverless-element existence theorem.
- **Chapter X** proves no Tschantz triples exist, classifies non-canonical-joinand join-irreducibles, gives the splitting-decomposition classification.
- **Chapter XI** turns the entire toolkit into algorithms: $O(n^{5/2})$ for being a lattice, $O(n^2)$ for $\mathrm{Con}(L)$, $O(n^3)$ for the word problem of finitely-presented lattices.
- **Chapter XII** addresses the equational-theoretic question: does the variety of lattices have a finite, convergent AC TRS? No (Theorem 12.8). Does an infinite family of subvarieties? Yes (Theorem 12.28). Does $V(\mathbf{N}_5)$? Open (Problem 12.27).

The companion's 5-panel connection structure (P1-P5 per chapter) provided 60 cross-references threading the structural-and-algorithmic-and-equational narrative. The Prologos panel (P5 in each chapter) sketched how the monograph's abstract lattice-theoretic concepts map to the concrete on-network architectural patterns of the Prologos compiler — including, in Chapter XII, how "no AC TRS for $\mathcal{L}$" parallels the impossibility of expressing certain compiler computations purely in S0 (the monotone CALM-safe stratum) without higher-stratum strategies.

— end of Free Lattices process notes (ALL 12 chapters complete) —
