# Călugăreanu Companion — Process Capture

A self-contained guide for building or extending the chapter-by-chapter prose companion to Grigore Călugăreanu's *Lattice Concepts of Module Theory* (Springer, 2000). Written so a fresh session can pick up the work without re-deriving the conventions.

## Project intent

The user (Z, zee.larson@gmail.com) is reading Călugăreanu's book side-by-side with this companion. The book is mathematically dense and notationally terse. The companion does three things:

1. **Faithful expansion in prose.** Each definition, lemma, proposition, and theorem in the book gets its own section in the companion, preserving the book's numbering as labels (Definition, Lemma 2.1, Proposition 3.3, Theorem 2.1, etc.). The book's compressed proofs are re-told in slower prose with the strategic intent named.
2. **Building intuition + connections.** Every result is followed by an "Intuition" callout when the book skips one, and outward connection panels at the end of each chapter map the chapter's vocabulary onto domain theory, universal algebra, topology, abstract interpretation, module theory, group theory, and the Prologos propagator network.
3. **Worked exercises.** All end-of-chapter exercises are worked in full as collapsible details/summary blocks with statement, hint, full solution, and commentary on what the exercise is teaching.

User feedback (latest): explain mathematical terminology more — *every* new term should be explained on first use, even ones that seem standard ("cover", "chain", "refinement", "isomorphic", "bounded"). Build up as a self-contained treatment. The user is mathematically literate but not assumed to remember dense terminology from prior reading.

## File layout

All files live in `/sessions/festive-dazzling-euler/mnt/learning/` (the user's mounted "learning" folder; persists between sessions; visible to the user).

| File | Role |
|---|---|
| `calugareanu-companion-toc.html` | Front-door landing page — links all available chapters with summaries. |
| `calugareanu-companion-hub.html` | Chapter 2 (this is the original filename; kept as-is for backward compat with any bookmarks the user has set). |
| `calugareanu-companion-ch03.html` | Chapter 3. |
| `calugareanu-companion-chNN.html` | Future chapters (NN = 04, 05, …). |
| `calugareanu-companion-process.md` | This file. |
| `lattice-module-hub.html` | The separate, structured Lattice Atlas curriculum (the v2.0 5-part / 18-module learning hub — *not* part of this companion; predates it). |
| `lattice-module-curriculum.md` / `.pdf` | Part of the Lattice Atlas curriculum. |
| `lattice-module-worksheet.md` / `.pdf` | Part of the Lattice Atlas curriculum. |

The companion lives in parallel with the Lattice Atlas. Atlas is structured curriculum (the user-built course); companion is reference reading paired to the textbook chapter-by-chapter. Both share the dark/light theme convention.

## Source of truth

The PDF is at `/sessions/festive-dazzling-euler/mnt/prologos/outside/Grigore Călugăreanu (auth.) - Lattice Concepts of Module Theory (2000, Springer).pdf`. To read a chapter, use the Read tool with `pages: "N-M"` (max 20 pages per request).

Page-to-chapter mapping (book page → PDF page):

| Chapter | Book pages | PDF pages |
|---|---|---|
| Chapter 1: Lattices | 1–14 | 13–28 |
| Chapter 2: Compactly generated lattices | 17–27 | 29–39 |
| Chapter 3: Composition series. Decompositions | 29–38 | 40–49 |
| Chapter 4 onward | continues sequentially | each chapter offsets by the same +12 from book page to PDF page |

(The +12 offset is the ToC + front matter.)

## Theme conventions (CSS)

Theme tokens, cell spacing, sidebar nav, MathJax, theme toggle — all match the existing Lattice Atlas hub and inherit its visual identity. Copy the `<style>` block from `lattice-module-hub.html` (lines 17–442 in the v2.0 file) for the base, then add companion-specific tweaks:

```css
/* Companion-specific extensions to the Lattice Atlas theme */
--box-conn-bg: #EFE7F2;        /* light mode: connection panel */
--box-conn-border: #C9B7D2;
/* dark mode: */
--box-conn-bg: #1B1726;
--box-conn-border: #3D2F4A;

/* Box label colors that don't appear in the Atlas */
.box.lemma .label { background: #6A4F1F; color: #E6C876; }
.box.prop  .label { background: #2B3560; color: #E6C876; }
.box.proof { background: var(--bg-muted); border-left: 3px solid var(--teal); }
.box.proof .label { background: var(--teal); color: #0E1420; }
.box.warning .label { background: #8B4A2B; color: #FBF0DD; }
.box.connection .label { background: #4A2F5A; color: #E6C876; }
:root[data-theme="dark"] .box.connection .label { background: #5A3F6E; color: #E6C876; }

/* Definition pill MUST use literal navy + gold (NOT var(--ink)) so it
   keeps its high-contrast appearance in both themes. This was a user-
   reported readability fix. */
.box.def .label { background: #1E2749; color: #E6C876; }
```

## Sidebar nav structure

Each chapter file has a left sidebar with the same brand block at top, then sections grouped under "Part 1", "Part 2", etc., then a "Connections" group, then a "Reference" group (Glossary, Worked Exercises, Looking Ahead). The brand block points to the ToC:

```html
<nav class="sidebar">
  <div class="brand">Călugăreanu Companion</div>
  <div class="sub">A prose, diagrammed, and connected reading of <em>Lattice Concepts of Module Theory</em>.</div>
  <div class="section-label">Navigation</div>
  <ul>
    <li><a href="calugareanu-companion-toc.html">← Companion ToC</a></li>
  </ul>
  <!-- then the chapter's own sections -->
</nav>
```

## Box-callout vocabulary

Used consistently across all companion files:

| Class | Purpose |
|---|---|
| `box def` | Formal definition — navy pill on gold (high contrast). |
| `box lemma` | Lemma statement. |
| `box prop` | Proposition statement. |
| `box thm` | Theorem statement. |
| `box proof` | Proof sketch (left-rule teal). |
| `box intuition` | Plain-English gist, "the reading," what to remember. |
| `box ex` | Worked example / illustrative case. |
| `box connection` | Mapping to a connected domain (used in connection panels and inline). |
| `box prologos` | Prologos-specific connection (gold border, cream background). |
| `box warning` | Terminology trap, common misreading, etc. |

## Section structure inside a chapter file

```
hero (title + lede + meta)
overview (the chapter's punchline in one paragraph + chapter arc)
[optional vocabulary primer if the chapter introduces many new terms]
part-header Part 1
  section.module #s1 ... #sN     (one per book result)
part-header Part 2
  section.module ...
[more parts as the chapter requires]
part-header Connections
  section.module #c1 ... #c5     (5 connection panels)
part-header Reference
  section.module #glossary
  section.module #exercises      (worked end-of-chapter exercises in <details>)
  section.module #ahead          (where this chapter sits in the book's arc)
footer
```

## Each book result gets its own section

Naming pattern: `id="s1"`, `id="s2"`, …, `id="cK"` for connections, then `id="glossary"`, `id="exercises"`, `id="ahead"`. Each section has:

```html
<section class="module" id="sN">
  <h2><span class="num">SECTION N</span> <result name></h2>
  <div class="tagline"><italic gist of what this section does></div>
  <p><prose explanation></p>
  <div class="box <type>">
    <span class="label"><Result kind> · <name></span>
    <p><formal statement, in math></p>
  </div>
  <div class="box proof">
    <span class="label">Why · <descriptor></span>
    <p><proof in prose></p>
  </div>
  <div class="box intuition">
    <span class="label">The reading</span>
    <p><what to remember></p>
  </div>
</section>
```

## SVG conventions

All diagrams are inline SVG. Theme adaptation is via CSS classes that the SVG references:

```css
.node { fill: #FBF8EC; stroke: #1E2749; }      /* default */
.node-hot { fill: #FBE9B5; stroke: #C89F3C; } /* highlighted */
.node-cool { fill: #DDE6EF; stroke: #3D5A6C; } /* secondary */
.edge { stroke: #3D5A6C; }                    /* default edges */
.edge-hot { stroke: #C89F3C; }                /* highlighted edges */
.lbl { fill: #1E2749; font-family: 'Source Serif Pro'; }
.cap { fill: #6B6B6B; font-family: 'Inter'; font-style: italic; font-size: 11–12px; }
```

The dark-mode adaptation is in the parent stylesheet (in `<head>`):

```css
:root[data-theme="dark"] figure svg .node { fill: var(--bg-warm) !important; stroke: var(--ink) !important; }
:root[data-theme="dark"] figure svg .node-hot { fill: #3A2E15 !important; stroke: var(--gold) !important; }
:root[data-theme="dark"] figure svg .node-cool { fill: #1A2236 !important; stroke: var(--teal) !important; }
:root[data-theme="dark"] figure svg .edge { stroke: var(--teal) !important; }
:root[data-theme="dark"] figure svg .edge-hot { stroke: var(--gold) !important; }
:root[data-theme="dark"] figure svg .lbl { fill: var(--ink) !important; }
:root[data-theme="dark"] figure svg .cap { fill: var(--text-dim) !important; }
```

So inside the `<svg>` you only need to set the local `<style>` for the LIGHT mode; dark mode automatically inverts via the page-level rules.

## Math conventions

- Uses MathJax 3.2 (loaded from cdnjs) with both `$...$` and `\(...\)` for inline; `$$...$$` and `\[...\]` for display.
- Blackboard letters: `\mathbb N`, `\mathbb Z`, `\mathbb Q`, `\mathbb R`. (Not `\mathbf` — Călugăreanu uses bold for some things but `\mathbb` reads better in our prose.)
- Powerset: `\mathcal P(M)`. Subalgebra lattice: `S(A,\Omega)`. Submodule lattice: `S_R(M)`.
- Joins/meets: `\bigvee`, `\bigwedge`, `\vee`, `\wedge`. Cover: `\prec`. Comparable: `\le`, `<`.
- Greek for indices over arbitrary sets: `\alpha, \beta, \gamma`. Latin (i, j, k, n) for natural-number indices.
- Modular law display: `a \le c \Rightarrow a \vee (b \wedge c) = (a \vee b) \wedge c`.

## Worked exercises pattern

```html
<details class="exercise" id="ex-N-K">
  <summary><span class="ex-tag">Ex. N.K</span> Short title</summary>
  <div class="body">
    <p class="ex-statement">Verbatim from book.</p>
    <h4>Solution</h4>
    <p>Step-by-step prose, splitting forward / reverse where applicable.</p>
    <h4>Commentary</h4>
    <p>What the exercise teaches; how it fits with the chapter's results.</p>
  </div>
</details>
```

## Connection panels — the five-panel pattern

Each chapter ends with five outward connections. The exact targets vary by chapter content, but at least one is always Prologos (using concrete source-file references from `racket/prologos/*.rkt` and `.claude/rules/*.md` — tied to the Hyperlattice Conjecture, the Design Mantra, the SRE Lattice Lens). Other panels typically include:

- **Domain theory / Scott domains** (when compactness, continuity, or fixpoints are involved)
- **Universal algebra / Birkhoff–Frink** (when subalgebra lattices are involved)
- **Topology / Stone duality** (when "compact," "open," or duality is involved)
- **Abstract interpretation** (when chain conditions, fixpoints, or termination are involved)
- **Module theory** (the running thread of the book)
- **Group theory / Jordan–Hölder** (when chains and refinement are involved)
- **Galois theory** (when intermediate-element lattices are involved)
- **Vector spaces / dimension** (when length is involved)
- **Abelian categories** (when decomposition is involved)
- **Quantum logic** (the lattice of closed Hilbert subspaces — comes up around modularity)
- **Domain decomposition / direct sums** (when irreducibles or coproduct decompositions are involved)

Pick the 5 most-resonant. Always include Prologos.

## Workflow checklist for a new chapter

1. Read the book chapter via `Read` with `pages: "N-M"` (the +12 offset rule).
2. Catalogue all named results: every Definition, Remark, Lemma, Proposition, Theorem, Corollary, Example. Each becomes a section.
3. Catalogue all newly-introduced terminology. Plan to explain each term on first use, with a callout if it's particularly subtle.
4. Plan parts. Group sections into 2–5 thematic parts with part-headers. Write a one-sentence lede for each part.
5. Plan diagrams. Aim for 3–6 SVGs per chapter. Common types: Hasse diagrams of small lattices, quotient-interval pictures, counterexample lattices ($N_5$, kite, etc.), step-refinement pictures.
6. Plan 5 connection panels. At least one is Prologos.
7. Plan exercises. Each exercise gets a `<details class="exercise">` with statement, full solution, and commentary.
8. Write the file. Use Write (one big initial pass) or Edit (incremental refinement).
9. Verify: HTML well-formedness, internal anchor resolution, exercise count, MathJax-friendly markup. Use the verifier:

```python
from html.parser import HTMLParser
class V(HTMLParser):
    def __init__(self):
        super().__init__()
        self.stack = []
        self.errors = []
        self.void = {'br','hr','img','input','meta','link','col','area','base','source','track','wbr',
                     'circle','line','rect','polyline','polygon','path','use','stop','ellipse'}
    def handle_starttag(self, tag, attrs):
        if tag in self.void: return
        self.stack.append((tag, self.getpos()))
    def handle_startendtag(self, tag, attrs): return
    def handle_endtag(self, tag):
        if tag in self.void: return
        if not self.stack:
            self.errors.append(f'Stray </{tag}> at {self.getpos()}'); return
        top, pos = self.stack[-1]
        if top != tag:
            self.errors.append(f'Mismatch: <{top}> at {pos}, </{tag}> at {self.getpos()}')
            for i in range(len(self.stack)-1, -1, -1):
                if self.stack[i][0] == tag:
                    self.stack = self.stack[:i]; return
            return
        self.stack.pop()
```

10. Update the ToC hub (`calugareanu-companion-toc.html`) — add a card for the new chapter and update the chapter-count meta.
11. Show the user via `[View …](computer:///sessions/…/mnt/learning/<file>)` link.

## User-feedback log

| Date | Feedback | Resolution |
|---|---|---|
| 2026-04-27 | Dark-mode Definition heading hard to read | Pinned `.box.def .label` to literal `#1E2749` / `#E6C876` so it stays high-contrast in both themes. |
| 2026-04-27 | Make companion separate from Lattice Atlas | Created `calugareanu-companion-hub.html` as a new file, dark-mode-default, same theme tokens. |
| 2026-04-27 | Explain terminology more — even "cover" was opaque on first encounter | Add a "First, the vocabulary you'll need" primer at the start of each chapter that has dense new terminology. Always explain a term on first use, even if it seems standard. Maintain a thorough glossary. |
| 2026-04-27 | Track terms across chapters; recap key ones rather than re-introducing all | Added the **term ledger** below. Each new chapter's primer recaps only the terms that are load-bearing for that specific chapter (with one-line refresher) and dedicates full term-cards to genuinely new terms. The ledger tracks what's introduced where so we can be deliberate about recap-vs-introduce. |
| 2026-04-27 | Missing term: "quotient" (module / lattice) — was reaching for it | Patched Ch 2 glossary with two entries: "quotient (the underlying idea)" and a fuller "quotient sublattice $b/a$ — the lattice of $b/a$" entry that spells out the correspondence theorem connection. |
| 2026-04-27 | Want intuition for left and right residuation | Built into Chapter 4's primer + connection panel C3. Pseudo-complementation in Călugăreanu's "maximal" sense vs. the "greatest" sense (Heyting implication / right residual of meet) is the natural hook. |

## Term ledger

Track, per chapter, which terms are <strong>introduced new</strong>, which are <strong>recapped</strong> (one-liner, no full term-card), and which warrant a <strong>deep dive</strong>. New chapters' primers should recap the most-load-bearing previously-introduced terms, fully introduce only the genuinely-new ones, and deep-dive when the term sits at a conceptual hinge.

### Chapter 1 — terms introduced (the foundational chapter, all "new")

binary relation · reflexive (R) / transitive (T) / antisymmetric (A) · preorder · partial order · poset · subposet · dual / self-dual · upper bound / lower bound · comparable / non-comparable ($\|$) · chain (totally ordered) · antichain · largest / smallest element · maximal / minimal element · join $\vee$ / meet $\wedge$ · sup / inf · noetherian (ACC) · artinian (DCC) · well-ordered (artinian + totally ordered) · Axiom of Choice / Zorn's Lemma / Hausdorff Principle / Zermelo's Theorem · transfinite sequence · cover relation $a \prec b$ · Hasse diagram · order morphism · strictly order morphism · order isomorphism · upper / lower directed · lattice · complete lattice · bounded lattice · sublattice · interval / quotient sublattice $b/a$ · simple interval · ideal · filter · $I(L)$ (lattice of ideals) · principal ideal $a/0$ · lattice morphism · lattice isomorphism · modular lattice · pentagon $N_5$ · diamond $M_5$ · second isomorphism theorem (lattice form) · semimodular / upper covering condition · distributive lattice · upper continuous · atom · atomic / strongly atomic · complement · direct sum $a \oplus a' = 1$ · complemented · relatively complemented.

### Chapter 1 — terms recapped from earlier chapters

None — Chapter 1 is the foundational chapter. The primer's "Carried forward" subsection notes conventions only (Călugăreanu's $b/a$ interval notation, the running module-theoretic motivation).

### Chapter 1 — deep-dive additions

Why the modular law matters (lattice abstraction of submodule modular law, necessary condition for being a submodule lattice) · $N_5$ and $M_5$ as Dedekind 1900 obstruction theorems (analogous to Kuratowski's $K_5$/$K_{3,3}$ for planarity; structural archetype for later $\mathbf{D}$-obstruction in Ch 13) · Hasse diagram conventions used throughout the book · Axiom of Choice and its lattice-theoretic uses (Zorn for maximal essential extensions, maximal independent sets, maximal critical-element families).

### Chapter 1 — terminology traps

"Maximal vs largest":
1. Largest: $\ge$ everything in the set.
2. Maximal: nothing strictly above.
3. Largest ⟹ maximal; converse fails (Ex 1.2: a poset can have many maximals but no largest). The book uses both consistently and the distinction is load-bearing in Ch 7 (radical = meet of maximals, well-defined despite non-uniqueness) and Ch 11 (local lattice asks for unique LARGEST, strictly stronger than unique maximal).

"$N_5$ vs $M_5$" naming convention:
- Călugăreanu's $N_5$ = the pentagon = smallest non-modular lattice (5 elements; $0 &lt; a &lt; c &lt; 1$, $0 &lt; b &lt; 1$, $b \| a, b \| c$).
- Călugăreanu's $M_5$ = the diamond = smallest modular non-distributive lattice (5 elements: $0$, three atoms $a, b, c$, top $1$).
- Modern texts often call the diamond $M_3$ (three atoms) reserving $M_5$ for a different lattice. The book's $M_5$ is most texts' $M_3$. This trap recurs in standard reference texts (Birkhoff, Grätzer); conventions vary.

"Modular" vs "distributive":
- Modular: $a \le c \Rightarrow a \vee (b \wedge c) = (a \vee b) \wedge c$ (one variable comparable).
- Distributive: $(a \vee b) \wedge c = (a \wedge c) \vee (b \wedge c)$ (no comparability).
- Distributive ⟹ modular (Ex 1.25); converse fails ($M_5$ is modular non-distributive).
- Submodule lattices $S_R(M)$ are always modular; not always distributive (typically not).

"Quotient sublattice" $b/a$:
- Călugăreanu writes $b/a$ for $\{x : a \le x \le b\}$ — the closed interval.
- Modern texts almost universally write $[a, b]$ for the same.
- Confusingly, $b/a$ is NOT a quotient in any algebraic sense — it's an interval. The naming is a quirk of older lattice-theory tradition (Birkhoff used it; the book preserves).
- Doubly confusing: $a/0 = \{x : x \le a\}$ is also called the "principal ideal" — same notation, additional name.

"Complement" overloads:
- Lattice complement (this chapter): $a \wedge a' = 0$ AND $a \vee a' = 1$.
- Pseudo-complement (Ch 4): largest $a^*$ with $a \wedge a^* = 0$.
- Supplement (Ch 12): minimal $a'$ with $a \vee a' = 1$.
The three are distinct. Lemma 12.1 says: in bounded modular, every complement is a supplement (but not necessarily a pseudo-complement, which is also unique when it exists).

"$I(L)$" overloads:
- $I(L)$ in Ch 1 (this chapter): lattice of ideals of $L$.
- $I_0(L)$ in Ch 13: lattice of NON-ZERO ideals of $L$ (sublattice of $I(L)$).
The two are introduced separately; the Ch 13 introduction of $I_0(L)$ recapitulates the Ch 1 definition of $I(L)$.

### Chapter 2 — terms introduced new

compact element · S-compact element · compactly generated lattice (= algebraic) · compact lattice · upper continuous lattice · noetherian (lattice) · H-noetherian · weakly atomic · atom · covering relation $a \prec b$ · ideal / principal ideal · finitely generated subalgebra · universal algebra $(A, \Omega)$ · upper directed subset · complete lattice · ascending chain condition (ACC) · join inaccessible · Krull's lemma · second isomorphism theorem (lattice form) · $N_5$ · Birkhoff–Frink theorem.

### Chapter 2 — terms recapped from Chapter 1

modular lattice · distributive lattice · lattice / poset / Hasse diagram · meet / join · top / bottom $0, 1$.

### Chapter 2 — deep-dive additions (post-publish patches)

quotient (concept + module) · quotient sublattice $b/a$ — the lattice of $b/a$ (added 2026-04-27 in response to user feedback).

### Chapter 3 — terms introduced new

contains (notation) · chain · interval $b/a$ · similar intervals · projective intervals · equivalent chains · refinement · composition chain · length $\ell$ · finite length · artinian / DCC · simple (interval / lattice / module) · semimodular / lower covering condition (LCC) · submodular inequality · bounded · meet irreducible (= "irreducible" = "hollow") · join irreducible · irredundant meet · irreducible decomposition · condition (B) · inductive lattice · locally finite length · Jordan–Dedekind condition · Schreier · Jordan–Hölder · Kuros–Ore.

### Chapter 3 — terms recapped from Chapter 2

cover (both senses, with explicit warning card) · noetherian · ACC · modular · ideal · interval / quotient sublattice (already had a slash explanation, now upgraded).

### Chapter 4 — terms introduced new

essential element · essential extension · essentially closed · pseudo-complement (Călugăreanu's "maximal" sense) · pseudo-complemented lattice · relative pseudo-complemented lattice · mutually pseudo-complements · sufficient pseudo-complements · maximal essential extension · injective hull (only by name, in connection panel) · neat element (forward reference to Chapter 9).

### Chapter 4 — terms recapped from Chapter 2-3

complete lattice · bounded · modular · complement (full recap — first time it gets a card in this companion) · condition (B) · inductive lattice · upper continuous · noetherian (recap) · ACC.

### Chapter 4 — deep-dive additions

quotient (re-introduced as recap-and-deepen, since Ch 2 patch happened after Ch 3's primer) · left and right residuation (the conceptual hinge between Călugăreanu's two senses of "pseudo-complement") · Heyting algebra · residuated lattice · double-negation $\neg\neg$ as a closure operator.

### Chapter 5 — terms introduced new

socle $s(L)$ · dual atom · atom generated · torsion lattice · torsion-free lattice · semiartinian · Loewy series · Loewy length · torsion element · $T(L)$ · torsion part $t(L)$ · radical property · RSC (restricted socle condition) · K-essential / K-socle · torsion-free element (different from "torsion-free lattice"!) · cycle / cyclic · locally cyclic group.

### Chapter 5 — terms recapped from Ch 2-4

atom · compactly generated · upper continuous · complement · essential element · pseudo-complement · noetherian / artinian / ACC / DCC · distributive lattice.

### Chapter 5 — deep-dive additions

socle in module theory (sum of simple submodules) · torsion in module theory vs lattice torsion (related but not identical — the deep dive disentangles) · Loewy's primary decomposition motivation (Alfred Loewy 1905, finite-dimensional representations).

### Chapter 5 — terminology traps codified

Chapter 5 has TWO terminology traps that the primer flags explicitly:
1. "Torsion" vs "module torsion": different concepts; lattice torsion = "every upper interval has atoms"; module torsion = "every element has finite order under ring action."
2. "Torsion-free lattice" vs "torsion-free element": completely different concepts despite the shared prefix. Lattice = every $a/0$ infinite. Element = no element covers $a$.
Going forward, when chapters re-use terms with overload risk, flag them explicitly with a "warning" callout in the primer.

### Chapter 6 — terms introduced new

independent subset · direct sum $\bigoplus_i a_i$ · maximal independent · weakly independent · join independent (Stenström) · Stanley independence (independent collections) · uniform element · Goldie (uniform) dimension · indecomposable element · indecomposable direct decomposition · projective in pairs · completely irreducible (recap-deepen) · semiatomic · atom generated / atomistic.

### Chapter 6 — terms recapped from Ch 1-5

modular · complement / complemented · atom / atomic · compactly generated · upper continuous / inductive · essential · pseudo-complement · noetherian / artinian / finite length · socle $s(L)$ · semimodular · irreducible · decomposition · projective intervals.

### Chapter 6 — deep-dive additions

linear independence in vector spaces lifted to lattices (clean special-case demonstration) · Goldie dimension and Goldie's theorem on semiprime rings · Krull–Schmidt theorem in its various algebraic forms (groups, modules, abelian categories, derived categories, AR theory) · matroids and Whitney's exchange axioms (the combinatorial face of independence).

### Chapter 6 — terminology traps codified

Chapter 6 introduces FOUR distinct senses of "independence" — the chapter's primer flags this with a prominent warning at the top:
1. Independent (Călugăreanu's main, used Sections A1-A8): $a_i \wedge \bigvee_{j \ne i} a_j = 0$.
2. Weakly independent (Crawley-Dilworth [15], same defining equation, used to highlight a single-element-at-a-time check).
3. Join independent (Stenström [18], [34]: independent on every finite subset, used to avoid upper continuity hypothesis).
4. Stanley independence ([21]: $(\bigvee X) \wedge (\bigvee Y) = \bigvee(X \cap Y)$ for finite subsets — distributivity-flavoured).
The four notions agree in well-behaved (modular, upper continuous) settings; diverge in pathological cases.

### Chapter 7 — terms introduced new

superfluous element (= small) · radical $r(L)$ · Frattini subalgebra · Jacobson radical (recap-deepen) · fully invariant element · FI-extending lattice · supplement (forward to Ch 12) · cocyclic group · meet infinitely distributive · characteristic subgroup · verbal subgroup · Wedderburn–Artin theorem · Bass's characterisation.

### Chapter 7 — terms recapped from Ch 1-6

modular · complemented · compactly generated · compact lattice · upper continuous · noetherian / artinian / finite length · essential · pseudo-complement · torsion lattice · atom · socle · independent · direct sum · atom generated · semiatomic · indecomposable.

### Chapter 7 — deep-dive additions

Frattini subgroup and Frattini's 1885 theorem (intersection of maximals = non-generators) · Jacobson radical of a ring/module (with Nakayama's lemma, Wedderburn–Artin, Krull intersection theorem) · fully invariant vs characteristic vs normal subgroups in group theory (three increasingly strong notions).

### Chapter 7 — terminology traps

The "radical" word is overloaded across algebra: nilradical (commutative algebra), Jacobson radical (ring/module theory), Frattini subgroup/subalgebra (group/algebra theory), prime radical, etc. All are special cases of $r(L)$ for the appropriate lattice. The chapter uses just "radical $r(L)$" for the lattice abstraction; the connection panels explain how each algebraic version recovers as a special case.

Also: "fully invariant" (Călugăreanu's, lattice) ≠ "fully invariant subgroup" (group theory) in general — but they agree in submodule / subgroup lattices of abelian groups. For non-abelian groups, the lattice notion is structurally more general.

### Chapter 8 — terms introduced new

uniform / co-irreducible · finite uniform (Goldie) dimension $\dim L$ · ACC⊕ (ACC for finite direct sums) · CS lattice (= extending) · completely CS · essentially compact · indecomposable injective module (forward concept) · quasi-injective module · continuous module · Osofsky-Smith theorem.

### Chapter 8 — terms recapped from Ch 1-7

modular · upper continuous · compactly generated · noetherian / artinian / finite length · essential / pseudo-complement / essentially closed · socle · RSC · independent / direct sum · indecomposable · H-noetherian · irreducible (meet-irreducible) · radical $r(L)$.

### Chapter 8 — deep-dive additions

Uniform modules in module theory (concrete examples in abelian groups: cocyclic, rank-1 torsion-free, mixed) · Goldie dimension theory in modern non-commutative algebra (Goldie's theorem on semiprime rings, applications) · CS modules and the Osofsky-Smith theorem (1991, recent extensions by Albu, Crivei et al.).

### Chapter 8 — terminology traps

The CS hierarchy in module theory: Injective ⟹ Quasi-injective ⟹ Continuous ⟹ Quasi-continuous ⟹ CS. Each adds an extension axiom; the lattice version "completely CS" recovers the strong "CS-everywhere" property used in Osofsky-Smith.

Also: "uniform" overloads with "uniform space" in topology (different concept) and "uniform convergence" in analysis (also different). In lattice / module theory, "uniform" specifically means "every non-zero element is essential."

### Chapter 9 — terms introduced new

pure element (T. Head 1972) · neat element (Honda 1956) · sectionally / principally complemented · basis (independent + ⋁ = 1) · R1 (restricted socle condition 1) · R2 (restricted socle condition 2) · absolutely complemented · Prüfer pure subgroup · Honda neat subgroup · cocyclic group (recap) · $t(0)$ (recap from Ch 5).

### Chapter 9 — terms recapped from Ch 1-8

modular · upper continuous · compactly generated · complemented · compact element · essential / pseudo-complement / essentially closed / maximal essential extension · socle / atom / atomic / atom generated · torsion-free element · independent / direct sum / semiatomic · H-noetherian / fully invariant.

### Chapter 9 — deep-dive additions

Prüfer pure subgroups in abelian group theory (1923, Kulikoff 1941) · Honda neat subgroups (1956) and the historical "rein"/"pure"/"neat" terminology confusion · the hierarchy: complemented ⟹ pure ⟹ neat (in upper continuous modular) · Cohn's pure submodules and pure exact sequences (1959) · the closed / essentially closed connection.

### Chapter 9 — terminology traps

"Pure" overloads multiple times in algebra:
1. Prüfer pure subgroup (abelian groups, 1923): $nA = A \cap nB$ for all $n$.
2. Honda's "rein" (1956) = neat: $pA = A \cap pB$ for primes $p$ only.
3. Cohn pure submodule (modules over rings, 1959): tensor-product condition.
4. Călugăreanu/Head pure element (lattice, 1972): complemented in every compact upper interval.
All are related but distinct; the lattice version recovers the others as special cases.

Also: "neat" is a 1950s-1970s term that has fallen out of common use in current algebra. Modern abelian group theory often uses "essentially closed" or simply "closed" for what Honda called "rein"/"neat." Călugăreanu uses "neat" consistently throughout — beware when reading other texts.

### Chapter 10 — terms introduced new

coatomic lattice · reduced lattice (lattice notion, distinct from "reduced abelian group") · divisible element · condition (#) · condition (D) · sufficient complements · local lattice · elementary abelian group (in example) · nearly divisible abelian group (in exercises) · Bass B-object (= coatomic module) · perfect ring · Prüfer $p$-group $\mathbb Z(p^\infty)$ · $p$-adic integers $J_p$ / $p$-adic numbers $\mathbb Q_p$.

### Chapter 10 — terms recapped from Ch 1-9

modular · upper continuous · compactly generated · complemented · compact / Krull's lemma · essential / pseudo-complement · socle / atom / atomic / atom generated / semiatomic · torsion / RSC · superfluous / radical $r(L)$.

### Chapter 10 — deep-dive additions

Bass's B-objects and the 1960 paper on perfect rings · divisible and reduced abelian groups (classical structure theory, Kulikov's decomposition) · local lattices and local rings (the algebraic-geometric connection: stalks of structure sheaves) · nearly divisible abelian groups (the chapter's exercise classification: cyclic prime-power + pure dense in $J_p$).

### Chapter 10 — terminology traps

"Reduced" overloads:
1. Reduced lattice (this chapter): every $a \ne 0$ has maximal elements in $a/0$.
2. Reduced abelian group: no non-trivial divisible subgroup (= zero divisible part).
3. Reduced ring (commutative algebra): no non-zero nilpotent elements.
All three are different concepts. Călugăreanu uses (1); the deep dive on divisibility uses (2) for context.

Also: "local" overloads:
1. Local lattice (this chapter): $L - \{1\}$ has a largest element.
2. Local ring: unique maximal ideal.
3. "Locally" qualifiers in topology / algebraic geometry (e.g., "locally cyclic," "locally finite," "locally noetherian") — different from "local" alone.
The chapter's "local" is rare in the lattice literature; modern usage may differ.

### Chapter 11 — terms introduced new

co-compact element · co-compact lattice (= dual compact lattice) · finitely cogenerated module (Stenström, [34]) · dual compact element (NOT the same as co-compact element — see traps) · linearly compact module (Onodera 1973, deep dive) · QF (quasi-Frobenius) ring (deep dive, P4) · Morita duality (deep dive, P4).

### Chapter 11 — terms recapped from Ch 1-10

compact / Krull's lemma · compactly generated · modular · semiatomic / atomic · socle / radical $r(L)$ · essential / superfluous · artinian · noetherian · upper continuous / inductive · finite direct sums.

### Chapter 11 — deep-dive additions

Order duality as a structural principle (compact ↔ co-compact, ACC ↔ DCC, atomic ↔ coatomic, essential ↔ superfluous, socle ↔ radical) — the chapter is the first systematic exercise of this duality at the lattice-theoretic level · Bass-Goldie machinery: artinian + noetherian behavior on dimension · QF (quasi-Frobenius) rings as the algebraic context where finitely cogenerated coincides with finitely generated · Morita duality and the symmetry between left and right module categories · Onodera 1973: finitely cogenerated $\Leftrightarrow$ linearly compact with essential socle.

### Chapter 11 — terminology traps

"Co-compact" overloads / near-misses:
1. Co-compact element (this chapter, lattice-theoretic): the dualisation of compact.
2. "Co-compact" in topology (a different sense): a subspace $A \subseteq X$ is co-compact when $X \setminus A$ is compact. Unrelated.
3. **Co-compact ≠ Coatomic** — Chapter 10's coatomic is "every $\ne 1$ has a maximal above"; Chapter 11's co-compact is "every meet-cover has a finite sub-meet-cover." Different concepts. Co-compact lattices need not be coatomic; coatomic lattices need not be co-compact (though there are partial implications under modular + compactly generated).
4. **Co-compact element ≠ Dual compact element** — "Dual compact element" is the stronger relative-interval version (Proposition 11.5). The chapter uses both terms; the deliberate notation asymmetry is "co-compact lattice = dual compact lattice but co-compact element ≠ dual compact element."

"Finitely cogenerated" vs "finitely generated":
- Finitely generated module: there is a finite subset whose generated submodule is the whole module.
- Finitely cogenerated module: every family of submodules with zero intersection has a finite subfamily with zero intersection. Equivalent (Vámos 1968): essential socle that is finitely generated.
The two are NOT each other's negation; both can hold (e.g., simple modules), neither can hold, or one without the other.

### Convention going forward

Each new chapter primer has three subsections in this order: (1) "Carried forward" — terms recapped with one-line refresher; (2) "New in this chapter" — full term-cards; (3) "Deep dive" — extended explainers for terms at conceptual hinges or terms the user has flagged. The third subsection is optional; use it when the term-card form is insufficient.

### Chapter 12 — terms introduced new

supplement (minimal $c$ with $b \vee c = 1$; order-dual to pseudo-complement) · supplemented lattice (every element has a supplement) · hollow lattice (every $\ne 1$ is superfluous) · local lattice ($L \setminus \{1\}$ has a largest element; cf. Ch 10/11 local-of-quotient) · divisible lattice (definitional sketch: $r(L) = 1$, equivalently every compact element superfluous — unifies with Ch 10's divisible element) · locally artinian lattice (every compact element is artinian) · cyclically generated lattice (each element is a join of cyclic elements; strengthens compactly generated) · sufficient (or ample) supplements · condition (U) (each supplemented sublattice is torsion) · Wisbauer's [41] reference (Foundations of Module and Ring Theory, Gordon &amp; Breach 1991, the canonical reference for supplemented modules) · semiperfect modules (deep-dive context — Cor 12.2 IS the lattice form of the semiperfect structure theorem) · Krull-Schmidt-Azumaya (deep-dive context for hollow modules with local endomorphism rings).

### Chapter 12 — terms recapped from Ch 1-11

compact element / lattice · compactly generated · pseudo-complement · superfluous element · radical $r(L)$ · modular · atomic / semiatomic · complemented · maximal element · indecomposable (= no $a \oplus b$ decomposition with $a, b \ne 1$) · upper continuous · noetherian · artinian · torsion / RSC · H-noetherian · socle / atom · cyclic element (Ch 5/8: $c/0$ noetherian + distributive) · co-compact (Ch 11, used in the order-duality table).

### Chapter 12 — deep-dive additions

Why supplement $\ne$ complement (despite Lemma 12.1 making complements supplements in bounded modular) — the converse fails as soon as $r(L) \ne 0$, with Prop 12.2(3) giving $b \wedge c = r(c/0)$ as the witness · Hollow $\Rightarrow$ indecomposable but not conversely; the Prüfer $p$-group as canonical hollow-not-local · Wisbauer's exercise context: the four-way (a)$\iff$(b)$\iff$(c)$\iff$(d) for Z-modules (locally artinian / DCC cyclic / essential socle / torsion), with the (a)$\Rightarrow$(b) direction left as "far from obvious" in the lattice generalisation · the "Order duality theme" connection table cross-references Ch 4 (pseudo-complement / supplement), Ch 5 (atom / coatom, socle / radical), Ch 7 (essential / superfluous), Ch 8 (uniform / hollow, cocyclic / local), Ch 10 (atomic / coatomic), Ch 11 (compact / co-compact), and the Goldie / hollow dimension pairing.

### Chapter 12 — terminology traps

"Local" overloads (extending Ch 10's trap):
1. Local lattice (Ch 12, this chapter): $L \setminus \{1\}$ has a largest element.
2. Local element (Ch 10/11 sense, often used in proofs): an element $a$ such that $a/0$ is a local lattice.
3. Local ring: unique maximal ideal.
4. Locally cyclic / locally finite / locally artinian: "every finitely-generated sublattice has property X" — different from "local."
The chapter's Cor 12.2(d) "$1$ is an irredundant join of local elements" uses sense (2).

"Hollow" vs "indecomposable":
- Hollow: every $\ne 1$ is superfluous.
- Indecomposable: $1 = a \oplus b$ implies $a = 1$ or $b = 1$.
Hollow $\Rightarrow$ indecomposable in any lattice; converse fails. In compactly generated modular, Prop 12.4(1) gives "hollow ⟺ every $1/a$ ($a \ne 1$) is indecomposable" — the equivalence is at the QUOTIENT-INDECOMPOSABLE level, not the indecomposable-as-a-whole level.

"Supplement" vs "complement":
- Complement: $a \vee b = 1$ AND $a \wedge b = 0$.
- Supplement: $b$ minimal with $a \vee b = 1$ (no zero-meet condition).
- Pseudo-complement: $b$ maximal with $a \wedge b = 0$ (no top-join condition).
The three are distinct in general; coincide pairwise in special settings (Lemma 12.1: every complement is a supplement in bounded modular; Lemma 4.X: similarly for pseudo-complements). The order-dual table:
| In $L$ | In $L^0$ |
|---|---|
| supplement | pseudo-complement |
| complement | complement |
| pseudo-complement | supplement |

"Divisible" overloads (extending Ch 10's trap):
1. Divisible element (Ch 10): $a$ such that for each $a' < a$, ...
2. Divisible lattice (Ch 12, suggested): $r(L) = 1$, equivalently every compact element superfluous.
3. Divisible abelian group: $nA = A$ for all $n \ge 1$ — pure abelian-group concept.
4. Divisible module: similar generalisation to module category.
The Ch 12 sense (2) is given as a "could define" rather than as a definition the chapter formally adopts.

"Cyclic" overloads (cross-chapter):
1. Cyclic element (Ch 5/8/12): $c/0$ noetherian and distributive (lattice-theoretic).
2. Cyclic module: generated by a single element.
3. Cyclic group: generated by a single element.
4. Cocyclic module: dual, has essential simple socle.
The lattice sense (1) is the "right" generalisation of "cyclic module": for the submodule lattice, cyclic-as-element coincides with cyclic-as-module.

### Chapter 13 — terms introduced new

dual Goldie (hollow) dimension $h$-dim$(L) = $ dim$(L^0)$ · meet independent · DCC$_\oplus$ · ideal of a lattice · $I(L)$ / $I_0(L)$ (lattice of all ideals / non-zero ideals) · principal ideal $a/0$ · u-basis (max independent + uniform) · deviation / Krull dimension (Gabriel-Rentschler-Hart, transfinite ordinal-valued) · trivial poset ($\mathcal{D}_{-1}$) · convex subset · dyadic numbers $\mathbf{D}$ (Lemmonier obstruction) · $\alpha$-critical (Hart) · critical lattice · Gabriel dimension $g$-dim$(L)$ · $\alpha$-simple (Gabriel) · semi-hollow (Rangaswamy, Ex 13.4: each compact superfluous).

### Chapter 13 — terms recapped from Ch 1-12

uniform / Goldie dimension (Ch 8) · hollow / local (Ch 12) · independent / meet independent (dual to Ch 6) · compact / compactly generated (Ch 1) · noetherian / artinian (Ch 1) · torsion lattice (Ch 5) · upper continuous (Ch 1) · modular (Ch 1) · essential / superfluous (Ch 4 / Ch 7) · pseudo-complement / supplement (Ch 4 / Ch 12) · radical $r(L)$ (Ch 7) · socle $s(L)$ / atom (Ch 5) · supplemented (Ch 12) · semiatomic (Ch 6).

### Chapter 13 — deep-dive additions

The deviation construction — what each ordinal level captures: dev $= -1$ (trivial), $0$ (artinian-and-nontrivial), $1$ ($\mathbf{Z}$), $2$ ($\mathbf{Z}^2$ lex), $\omega$ (limit-ordinal), no-deviation ($\mathbf{R}, \mathbf{Q}, \mathbf{D}$) · Why four dimensions, not one — each catches a different structural axis with no redundancy · The Gabriel-Rentschler-Hart story (Gabriel 1962 thesis; Rentschler 1967 with Gabriel; Hart 1971 lattice-theoretic; Stenström 1975 textbook consolidation; Krause 1972 comparison theorems) · The closing equation $g$-dim $= k$-dim $+ 1$ for noetherian (Theorem 13.10) and the $\mathbf{D}$-obstruction characterisation (Theorem 13.6 — Lemmonier, the universal obstacle to having Krull dim, structural analogue of $N_5$ for non-modularity).

### Chapter 13 — terminology traps

"Krull dimension" overloads:
1. Classical Krull dim (commutative algebra, 1928): supremum of prime ideal chain lengths in a commutative ring. Finite for noetherian rings.
2. Gabriel-Rentschler Krull dim (1967, this chapter): deviation of the lattice of left ideals (or submodules). Transfinite ordinal-valued; agrees with classical Krull dim for commutative noetherian rings.
3. Hart's lattice version (1971): deviation of an arbitrary modular lattice. Does NOT need to be a submodule lattice.
The chapter uses sense (3); module-side recovers sense (2); commutative-algebra-side recovers sense (1) for noetherian commutative rings.

"Gabriel dimension" lineage:
1. Gabriel (1962, thesis): ordinal-valued dimension on Grothendieck categories via transfinite localizing-subcategory filtration. Categorical / Grothendieck-categorical setting.
2. Lattice-theoretic Gabriel dim (this chapter): the shadow of (1) on the submodule lattice. $\alpha$-simple elements correspond to Gabriel's $\alpha$-simple objects in the categorical setting.
The chapter develops sense (2) without categorical machinery; the comparison theorem (Theorem 13.9 — Krause) ties it to Krull dim.

"u-basis" vs. linear algebra basis:
- Vector space basis $B$ of $V_K$: linearly independent + spans $V$.
- u-basis of $S_K(V)$: max independent + uniform in the lattice.
- Ex 13.5: $B$ basis ⟺ $\{bK\}$ is u-basis. The lattice version is structurally weaker: in non-vector-space lattices, a u-basis exists when "every non-zero element contains a uniform" (Theorem 13.5 ($\alpha$)) — strictly weaker than spanning.

"$\alpha$-simple" (Gabriel) vs "$\alpha$-critical" (Hart):
- $\alpha$-simple: $g$-dim$(a/0) \not\le \alpha$ for $a \ne 0$ AND $g$-dim$(1/a) &lt; \alpha$ for $a \ne 1$.
- $\alpha$-critical: $k$-dim$(L) = \alpha$ AND $k$-dim$(1/a) &lt; \alpha$ for $a \ne 0$.
Different! The duality direction differs: $\alpha$-simple is "non-trivially $\alpha$ from below + trivially below from above"; $\alpha$-critical is "$\alpha$ from below + trivially below from above." The $1$-simple = atom; $0$-critical = atom. The two notions agree at level $0$/$1$ (atoms) but diverge for higher ordinals.

"Convex" in poset theory vs. lattice theory:
- Convex subset of a poset (this chapter): $b'/b \subseteq B$ for all $b, b' \in B$.
- Convex sublattice in lattice theory: usually has the additional requirement of closure under meets and joins (intervals are sublattices).
The chapter uses sense (1).

"Trivial poset" (this chapter):
- Trivial = antichain (only equality relation). $\mathcal{D}_{-1}$ in the deviation hierarchy.
- NOT trivial = single-element poset (which IS in $\mathcal{D}_{-1}$).
The naming is confusing: a single-element poset is "trivial" in both senses (antichain of one element), and an empty poset is also $\mathcal{D}_{-1}$.

## Hyperlattice / Prologos cross-references for the connection panels

When writing the Prologos connection panel, the relevant source files (verified to exist in the repo):

| Concept | Prologos source |
|---|---|
| Bilattice (FOUR) | `racket/prologos/bilattice.rkt` |
| Multiplicity lattice ($m_0, m_1, m_\omega$) | `racket/prologos/mult-lattice.rkt` |
| Term lattice | `racket/prologos/term-lattice.rkt` |
| Type lattice | `racket/prologos/type-lattice.rkt` |
| Session lattice | `racket/prologos/session-lattice.rkt` |
| Interval domain | `racket/prologos/interval-domain.rkt` |
| QTT | `racket/prologos/qtt.rkt` |
| Design mantra | `.claude/rules/on-network.md` |
| Propagator design (set-latch, broadcast, fan-in) | `.claude/rules/propagator-design.md` |
| Stratification | `.claude/rules/stratification.md` |
| SRE lattice lens (6 questions) | `.claude/rules/structural-thinking.md` |
| Pipeline checklists | `.claude/rules/pipeline.md` |

The Hyperlattice Conjecture: every computable function is expressible as a fixpoint computation on lattices, and the Hasse diagram of the lattice IS the optimal parallel decomposition. Use this when explaining how a chapter's vocabulary maps onto the on-network architecture.

## Stylistic discipline

- **Prose over bullets.** Bullet lists are for enumerations only (e.g., a definition with several conjuncts, or a list of examples). The connecting tissue is paragraphs.
- **Active voice; avoid "we" pile-up.** "The proof shows…" rather than "We will show…"
- **Name the strategy at the top of each proof.** "Why · induction on $|F|$" or "Why · Zorn's Lemma in disguise" — gives the reader the punchline before the details.
- **Avoid "clearly" and "obviously."** If a step is obvious, it doesn't need a hedge; if it isn't, the hedge is dishonest.
- **MathJax-friendly markup.** Use `\le` not `≤` in math; use `<` and `>` in math (HTML-escape them in prose: `&lt;` is fine, but better to rephrase).
- **Light italics for emphasis.** Bold for the names of newly-introduced terms.
- **Section taglines.** The italic one-line that follows each section h2 — write it as the gist a teacher would say while pointing at the result on a chalkboard.

## Tracking

Use `TaskCreate`/`TaskUpdate` to track per-chapter work. Suggested task list per chapter:

- Vocabulary primer
- Part 1 / Part 2 / Part 3 (named per chapter content)
- Connection panels
- SVG diagrams
- Glossary + worked exercises
- Verification + ToC update

## What survives compaction

Read this file first when resuming work. It contains:
- Project intent and user feedback log
- File layout
- All design conventions (theme, boxes, sidebar, SVG, math, exercises)
- The verification snippet
- The workflow checklist

The chapter HTML files themselves are large (~130KB each, ~1800 lines) — use `Read` with `offset` and `limit` to spot-check sections, not to re-read the whole file.

— end of process capture —
