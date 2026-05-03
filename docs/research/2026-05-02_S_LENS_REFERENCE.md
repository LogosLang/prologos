# S-Lens Reference: Operational Supplement for Lattice Design

**Date**: 2026-05-02
**Stage**: 0/1 (operational distillation; pulled up alongside `structural-thinking.md` and `CRITIQUE_METHODOLOGY.org` during design reviews)
**Foundational note**: [Parallel Decomposition and Hasse Adjacency for Propagators](2026-05-02_PARALLEL_DECOMPOSITION_AND_HASSE_ADJACENCY_FOR_PROPAGATORS.md) — read for theory; this note is for active use.

**Purpose**: candidate extensions to the SRE lattice lens (`structural-thinking.md` Q1-Q6 + a candidate Q7) and the per-variety algorithmic-anchor lookup table — distilled for design-review use. Cite this from rules files instead of bloating them with the full survey.

**Status**: Stage 0/1 — *candidate* extensions, not yet committed to `structural-thinking.md`. A Stage 3 design track would land the candidate questions formally; this note captures them at conversation-ready precision.

---

## 1. The Four-Lens Framework (one-line summary)

When designing or reviewing a lattice-valued cell, ask through four nested lenses:

1. **Element lens** — what is a cell value? what's its canonical form? when are two values equal?
2. **Variety lens** — what algebraic identities hold? what variety V does this lattice live in?
3. **Module lens** — how does this cell interact with others? what's the propagator action? does Krull-Schmidt apply?
4. **Adjacency lens** — what's the Hasse diagram? what parallel-algorithm anchor does it parametrize?

The lenses nest: variety → element + adjacency; element → module; module realizes adjacency at substrate level. (See foundational note §5.2 for the diagram.)

---

## 2. Extended SRE Lattice Lens (Q1-Q6 + candidate Q7)

The current six questions in [`structural-thinking.md`](../../.claude/rules/structural-thinking.md) + [`CRITIQUE_METHODOLOGY.org`](../tracking/principles/CRITIQUE_METHODOLOGY.org), refined per this synthesis. Q7 is a candidate addition.

### Q1 — VALUE or STRUCTURAL? (unchanged)

Does the cell hold a single evolving value (VALUE — type, constraint, answer set) or a compound structure with independently-evolving components (STRUCTURAL — scope-cell, decisions-state, commitments-state)?

### Q2 — Algebraic properties + variety identification (refined)

What algebraic identities does the lattice satisfy? **And what variety V is that?**

The refinement: don't stop at property declarations (`commutative-join`, `associative-join`, `distributive`, `has-pseudo-complement`); identify the **variety** (Boolean / Heyting / distributive / modular / SD / free / quantale / continuous). Variety is the equational closure of the property cluster.

| Property cluster | Variety | What it unlocks |
|---|---|---|
| `comm-join` `assoc-join` `idem-join` | Lattice (free) | Whitman's algorithm; canonical form |
| `+ has-meet` | Bounded lattice | Galois connections to other lattices |
| `+ distributive` | Distributive | Birkhoff representation; DNF/CNF; Garg LLP parallelism |
| `+ has-pseudo-complement` | Heyting | Pseudo-complement-driven backward propagation; intuitionistic semantics |
| `+ has-complement` | Boolean | Hypercube algorithms; bitmask operations; SAT-style solving; ATMS |
| `+ multiplicative monoid distributing over joins` | Quantale | Resource-aware composition; tropical/probabilistic reasoning |
| `+ left/right adjoints to multiplication` | Residuated | Automatic backward propagation |
| `+ algebraic / continuous` | Algebraic / Continuous | Domain theory; way-below relation; lazy evaluation |

### Q3 — Bridges (Galois connections) (unchanged)

For each other lattice this domain interacts with, is the bridge a Galois connection (left adjoint preserves joins)? Composition of bridges = composition of Galois connections.

### Q4 — Composition / full bridge diagram (unchanged)

Draw the full bridge diagram for ALL lattices in the design. Composition must be type-correct (Galois connections compose).

### Q5 — Primary vs Derived (unchanged)

Which lattice is PRIMARY (authoritative source) and which is DERIVED (projection / cache)? Derived lattices can be recomputed from primary; primary cannot be derived.

### Q6 — Hasse diagram + parallel-algorithm anchor (deepened)

What's the Hasse diagram? **And what parallel-algorithm anchor does it parametrize?**

The deepening: the Hasse diagram is not just a structural property — it parametrizes the optimal parallel decomposition (per Hyperlattice Conjecture). Identify the algorithmic anchor explicitly. See §3 below for the lookup table.

### Q7 (CANDIDATE) — Canonical form + equality decision

Which canonical-form algorithm applies in this variety? What's the equality decision procedure?

| Variety | Canonical form | Equality decidable via | Complexity |
|---|---|---|---|
| Boolean | Bitmask | Bitmask equality (single bitwise compare) | O(1) for n ≤ 64 |
| Distributive | DNF/CNF via Birkhoff | Structural equality on canonical forms | O(structural) |
| Heyting | Distributive canonical form | Structural equality | O(structural) |
| Modular | Dedekind / Freese | Heavier algorithm | O(structural, with overhead) |
| SD (finite) | Reading-Speyer-Thomas labeling | Structural equality on RST canonical | RST complexity |
| Free | Whitman canonical (FJN Ch XI Listing 11.12) | Whitman recursion | O(can(s) + can(t)) on canonical input |
| Continuous / Algebraic | Compact-element generation | Way-below relation | Domain-theoretic |
| Quantale (tropical) | Value itself (totally ordered) | Real-valued equality | O(1) |

Q7 is currently absorbed informally into Q1-Q6 via property declarations. Making canonical form explicit gives designers a direct hook for Q6's algorithmic anchor.

---

## 3. Per-Variety Algorithmic-Anchor Lookup Table

The load-bearing artifact. When you've identified the lattice variety (Q2), use this to determine the parallel-algorithm anchor (Q6) and canonical-form algorithm (Q7).

| Variety | Hasse profile | Algorithmic anchor (parallel) | Canonical form | Project domain examples |
|---|---|---|---|---|
| **Boolean (Q_n)** | Hypercube graph | Hypercube algorithms (Akl, Leighton, Bertsekas-Tsitsiklis): all-reduce in log_2 T rounds; Gray code Hamiltonian; bitmask subcube pruning O(1); butterfly embedding | Bitmask | ATMS worldview space; set cells (`merge-set-union` over powerset); decision cells |
| **Distributive** | Order-ideal poset of join-irreducibles (Birkhoff) | Garg LLP framework (SPAA 2020+): parallel detection along chains; Birkhoff-poset parallel traversal | DNF/CNF | Type lattice equality (Phase 3c); form cells equality merge (with pseudo-complement) |
| **Heyting** | Distributive Hasse + intuitionistic structure | Distributive parallelism + pseudo-complement-driven backward propagation | Distributive canonical | Type lattice subtype merge (Track 2H); form cells equality |
| **Modular (non-distributive)** | Modular geometry (subgroup lattice / projective geometry) | Modular-decomposition algorithms; less-developed parallel toolkit | Dedekind / Freese | (None currently registered; would model substructure relations) |
| **SD (finite)** | Convex-geometry-shaped | Reading-Speyer-Thomas canonical form; convex-geometry parallel algorithms | RST labeling | (Sweep targets: type×equality, session×equality post-Phase 3c) |
| **Free** | Breadth-4 bounded antichain width (Jónsson-Kiefer) | Whitman recursive parallelism; bounded-width fan-out | Whitman canonical | PUnify decomposition (structurally Whitman-shaped) |
| **Algebraic / Continuous** | Scott domain | Domain-theoretic parallelism; lazy evaluation; way-below traversal | Compact-element generation | (Module loading on infinite registry) |
| **Quantale (tropical)** | Totally ordered chain in [0, +∞] | Tropical Kleene-star (Bellman-Ford / Floyd-Warshall structurally); Litvinov-Maslov idempotent-analysis Perron-Frobenius eigenvalue | Value itself (totally ordered) | Tropical fuel cell (PPN 4C Phase 1B); future PReduce cost lattice |
| **Quantale (other)** | Domain-specific | Resource-aware parallel composition | Domain-specific | Multiplicity cells (m0/m1/mw); session lattice tensor |
| **Residuated** | Lattice with adjoint structure | Automatic backward propagation via residuation | Variety-dependent | Future: cost-bounded backward error explanation |

When designing a new domain or pattern, **find the row** that matches the lattice variety, and the algorithmic anchor + canonical form are determined.

---

## 4. Design-Review Checklist Additions

When reviewing a propagator-network design or new SRE-domain registration, add these questions to the existing checklists:

### Pre-design

- [ ] **Variety identification**: have we identified which lattice variety V this domain lives in? (Q2 refinement)
- [ ] **Algorithmic anchor**: have we identified which parallel-algorithm anchor applies, given the variety? (Q6 deepening)
- [ ] **Canonical form**: have we identified which canonical-form algorithm applies? Is it implementable at our scale? (Q7 candidate)
- [ ] **Adjacency profile**: what's the Hasse diagram's graph profile (width, diameter, treewidth)? Does it suggest sub-variety constraints (e.g., breadth-4 if free)?

### Mid-design

- [ ] **Algorithmic-anchor consistency**: does the proposed propagator pattern match the algorithmic anchor for this variety? E.g., for a Boolean cell, are we using bitmask + hypercube traversal, or something off-pattern?
- [ ] **Canonical-form scope**: does the proposed merge produce values in canonical form, or canonical-up-to-merge? Equality across BSP rounds — structural or canonical-form-based?
- [ ] **Module-decomposition opportunity**: does Krull-Schmidt direct-sum decomposition apply? Are independent components computed in parallel?

### Post-design

- [ ] **Hyperlattice grading**: which graded form of the conjecture does this design rest on? Boolean (textbook), distributive (Garg), SD (RST), or apparent-novelty regime?
- [ ] **Falsifiability**: if this design relies on the universal-form Hyperlattice Conjecture, is the dependency named explicitly?

---

## 5. Code-Review Sniff Tests (Red Flags)

Patterns that suggest a variety mismatch or missing algorithmic anchor:

### Variety mismatch

- **Distributivity property declared but not exploited**: cell declared `distributive` but merge / equality logic doesn't use Birkhoff representation or DNF canonical form.
- **Boolean variety not exploited as bitmask**: Boolean lattice with set / hash representation when n ≤ 64 (bitmask is O(1) for set ops; hashes are O(structural)).
- **Heyting pseudo-complement declared but no backward-propagation propagator**: declaring the algebraic structure without using it operationally.

### Algorithmic-anchor mismatch

- **Hypercube algorithms not used for Boolean lattice**: ATMS-style Boolean cell using flat (non-Gray-code) traversal; broadcast not exploited for log_2 T rounds.
- **Sequential traversal where parallel applies**: distributive lattice traversed by `for/fold` instead of Birkhoff-parallel order-ideal walk.
- **Tropical merge without Kleene-star**: tropical-quantale cell with cost composition done imperatively rather than via Bellman-Ford / Floyd-Warshall structural pattern.
- **Per-cell PUs where shared e-class cells preserve sharing**: per-AST-node PUs that don't share state for equal subterms break Lévy optimality (per [`PREDUCE_MASTER`](../tracking/2026-05-02_PREDUCE_MASTER.md) three-layer architecture).

### Canonical form mismatch

- **Equality via `equal?` on non-canonical values**: structural equality on values not in canonical form produces "logically-equal-but-structurally-different" bugs. Should canonicalize at merge time.
- **No hash-cons on canonicalizable values**: missing structure-sharing opportunity; CHAMP could share canonical representatives.

### Mantra red flags (existing, kept for cross-reference)

- `make-parameter` with hasheq value → should be a cell
- `for/fold` threading network through independent operations → should be all-at-once
- Off-network state with no retirement plan → debt against self-hosting

---

## 6. When to Pull This Reference Up

This supplement is designed for **active use** during:

1. **New SRE-domain registration** — running through Q1-Q7 + the algorithmic-anchor lookup before committing the registration.
2. **Propagator-pattern design review** — checking the proposed pattern against the algorithmic anchor for the relevant variety.
3. **Code review on lattice-valued cells** — sniff tests in §5 catch common mismatches.
4. **Variety status flips** — if Track 2I Phase 3 sweep flips a domain's variety status (e.g., the type×equality flip from non-distributive to distributive), the algorithmic-anchor implications need to be revisited per this table.
5. **PReduce e-class design** — the four-lens framework directly applies to e-class cells.
6. **Cost-extraction design** — tropical-quantale row gives the algorithmic anchor.

---

## 7. Cross-References

### Project rules
- [`structural-thinking.md`](../../.claude/rules/structural-thinking.md) — the foundational SRE lattice lens (Q1-Q6) + Hyperlattice Conjecture statement
- [`on-network.md`](../../.claude/rules/on-network.md) — design mantra (this lens applies in service of the mantra)
- [`stratification.md`](../../.claude/rules/stratification.md) — strata as fixpoint composition; algorithmic anchors per stratum
- [`CRITIQUE_METHODOLOGY.org`](../tracking/principles/CRITIQUE_METHODOLOGY.org) — adversarial framing; SRE lattice lens application

### Sister research notes
- [`LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE`](2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md) — element-level theory; FL_V(X)
- [`LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS`](2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md) — per-variety operational catalog
- [`MODULE_THEORY_LATTICES`](2026-03-28_MODULE_THEORY_LATTICES.md) — module-theoretic backbone (Krull-Schmidt; quantale modules)
- [`HYPERCUBE_BSP_LE_DESIGN_ADDENDUM`](2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — Boolean variety design consumer

### This batch
- [`PARALLEL_DECOMPOSITION_AND_HASSE_ADJACENCY_FOR_PROPAGATORS`](2026-05-02_PARALLEL_DECOMPOSITION_AND_HASSE_ADJACENCY_FOR_PROPAGATORS.md) — foundational synthesis; theory grounding for this supplement
- [`PARALLEL_ALGORITHMS_SURVEY`](2026-05-02_PARALLEL_ALGORITHMS_SURVEY.md) — deep survey of algorithmic-thinking mind-space (782 lines)
- [`LATTICE_CANONICAL_FORMS_SURVEY`](2026-05-02_LATTICE_CANONICAL_FORMS_SURVEY.md) — deep survey of lattice canonical forms (697 lines)
- [`ARCHITECTURE_NOVELTY_SURVEY`](2026-05-02_ARCHITECTURE_NOVELTY_SURVEY.md) — novelty assessment with falsifiability questions (582 lines)

### Application series consumers
- [`SRE_TRACK2I_SD_CHECKS_DESIGN`](../tracking/2026-04-30_SRE_TRACK2I_SD_CHECKS_DESIGN.md) — variety identification in flight; Phase 3c worked example
- [`PREDUCE_MASTER`](../tracking/2026-05-02_PREDUCE_MASTER.md) — PReduce series; e-class cell variety identification + cost-extraction algorithmic anchor
- [`SH_MASTER`](../tracking/2026-04-30_SH_MASTER.md) — SH series; Hyperlattice optimality grades the super-optimization claim

---

## Status

**Stage 0/1 supplement** — candidate extensions to the SRE lattice lens. Not yet committed to `structural-thinking.md`. Pulled up alongside the rules files during design reviews; cited from this path.

**Promotion path**: a Stage 3 design track would land Q7 (canonical form) in the SRE lattice lens formally and codify the per-variety algorithmic-anchor table as part of the SRE-domain registration discipline. That decision is downstream; gating on Track 2I Phase 3 sweep closure + cross-track input from PReduce and SH.

**Living artifact**: as more variety identifications happen and more algorithmic anchors get explicit, the §3 table grows. Expected updates:
- Track 2I Phase 3 sweep results (full domain inventory by variety)
- PReduce Track 0 outputs (e-class cell variety + extraction algorithmic anchor)
- Future Hasse-driven scheduler design (would canonicalize the Q6 algorithmic-anchor dispatch)
