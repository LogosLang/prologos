# Lattice Canonical-Form Theory and Decomposition Theorems — Research Survey

**Status**: Working draft (2026-05-02). Pure mathematical survey; no architectural synthesis. Will be folded into a larger research note that pairs this with parallel-algorithm theory.

**Scope**: Theorems and algorithms for canonical forms and decompositions across the variety hierarchy of lattices, plus dualities, decomposition theorems, and graph-theoretic profiles of Hasse diagrams.

**Conventions**: `≤` is lattice order; `∨` join; `∧` meet; `⊥`/`⊤` bottom/top; `≪` way-below; `T(X)` absolutely free term algebra over generators X; `FL(X)` free lattice on X; `J(L)` set of join-irreducibles of L; `M(L)` set of meet-irreducibles. Throughout, "finite" means finite cardinality.

---

## 1. Free Lattices (Whitman 1941; Freese-Ježek-Nation 1995)

### 1.1 Foundational construction

The free lattice `FL(X)` on a set X is constructed as `T(X)/∼` where `T(X)` is the absolutely free term algebra (binary operations `∨,∧` over generators X with no laws beyond the operations being binary) and `∼` is congruence by all lattice identities (associativity, commutativity, idempotence, absorption — but NOT distributivity, modularity, or any further law).

Equivalently, `FL(X)` is universal: for any lattice L and any function `f: X → L`, there is a unique lattice homomorphism `FL(X) → L` extending f. This makes free lattices the initial objects in the category of lattices over a set of generators.

Whitman's 1941 paper (Annals of Math. 42, 325–330) and 1942 sequel (43, 104–115) solved the *word problem*: given two terms `s, t ∈ T(X)`, decide whether `s = t` in `FL(X)`. The reduction is to deciding `s ≤ t` (since `s = t ⇔ s ≤ t ∧ t ≤ s`). The 1995 monograph "Free Lattices" by Freese, Ježek, and Nation (AMS Surveys 42, ISBN 0-8218-0389-1) is the canonical comprehensive treatment.

### 1.2 Whitman's algorithm — recursive cases for s ≤ t

The decision procedure for `s ≤ t` proceeds by structural recursion. The "Whitman cases" (the standard formulation has six branches; some sources present them as four W-conditions plus two trivial-comparison branches) are:

1. **(s, t generators)**: `s ≤ t` iff `s = t` (for x, y ∈ X distinct, `x ≤ y` is false in FL(X)).
2. **(s = a ∨ b)**: `a ∨ b ≤ t` iff `a ≤ t` and `b ≤ t`. (Lattice-universal.)
3. **(t = c ∧ d)**: `s ≤ c ∧ d` iff `s ≤ c` and `s ≤ d`. (Lattice-universal.)
4. **(s = a ∧ b, t generator x)**: `a ∧ b ≤ x` iff `a ≤ x` or `b ≤ x` (since x is meet-irreducible in FL(X)).
5. **(s generator y, t = c ∨ d)**: `y ≤ c ∨ d` iff `y ≤ c` or `y ≤ d` (since y is join-irreducible).
6. **(s = a ∧ b, t = c ∨ d) — Whitman's condition (W)**: `a ∧ b ≤ c ∨ d` iff `a ≤ c ∨ d` or `b ≤ c ∨ d` or `a ∧ b ≤ c` or `a ∧ b ≤ d`. The four "trivial" disjuncts are the only avenues — there are no nontrivial covers between meets and joins in `FL(X)`.

**Whitman's condition (W)**: a lattice L satisfies (W) iff for all `a, b, c, d ∈ L`, `a ∧ b ≤ c ∨ d` implies one of the four disjuncts. Free lattices satisfy (W); this is Whitman's characterization theorem (one of the four conditions characterizing free lattices).

### 1.3 Canonical form (Theorem 1.17, FJN)

Each element `w ∈ FL(X)` has a *unique* shortest-rank term representing it, called the canonical form, unique up to commutativity and associativity of `∨, ∧`. The rank function counts term complexity (depth or number of operation symbols).

**Theorem 1.17 (FJN)**: every element `w ∈ FL(X)` has a canonical form `t(w)`. Equivalent formulations exist: t(w) is the unique minimum-rank term representing w (modulo commutativity/associativity).

### 1.4 Four-condition characterization (Theorem 1.18)

**Theorem 1.18 (FJN)**: a term `t = t_1 ∨ ... ∨ t_n` (with n > 1, i.e., a proper join) is in canonical form iff:
1. each `t_i` is in canonical form;
2. the `t_i` are pairwise incomparable in `FL(X)` (no `t_i ≤ t_j` for i ≠ j) — no redundant joinands;
3. no `t_i` is itself a proper join (joinands are "join-prime");
4. the join representation `w = t_1 ∨ ... ∨ t_n` is *minimal* (in a refinement-theoretic sense — see §1.5).

A symmetric four-condition characterization holds for proper meets `t = t_1 ∧ ... ∧ t_n`. These conditions together with structural recursion on subterms yield the canonical form.

### 1.5 Minimal join representations and join-refinement (Theorem 1.19)

Define join-refinement: `S ≪ T` iff for every `t ∈ T` there exists `s ∈ S` with `s ≤ t`. A join representation `w = ⋁ S` is *minimal* if no proper sub-multiset refines to S.

**Theorem 1.19 (FJN)**: every `w ∈ FL(X)` has a unique minimal join representation `w = w_1 ∨ ... ∨ w_n` with `w_i` pairwise incomparable. The canonical form of `w` is exactly `t(w_1) ∨ ... ∨ t(w_n)` where each `t(w_i)` is in canonical form.

This is the key arithmetic property: canonical form *is* the minimal join refinement, and recursive structure gives the algorithm directly. Dual statement holds for meets.

### 1.6 Semidistributivity (Theorem 1.21; Jónsson-Kiefer 1962)

A lattice L is **join-semidistributive** (SD∨) if `a ∨ b = a ∨ c ⇒ a ∨ b = a ∨ (b ∧ c)`. Dually for meet (SD∧). L is **semidistributive** if both.

**Theorem 1.21 (Jónsson-Kiefer 1962)**: free lattices are semidistributive (Canad. J. Math. 14, 487–497).

Consequence: in `FL(X)`, the canonical join representation of an element is uniquely determined as a set, not just a multiset — no two distinct minimal join representations exist.

### 1.7 Breadth-4 bound (Corollary 1.31)

The **breadth** of a lattice is the largest n such that there are elements `a_1, ..., a_n` with `a_1 ∨ ... ∨ a_n > a_1 ∨ ... ∨ â_i ∨ ... ∨ a_n` for every i (the "irredundant" join width).

**Corollary 1.31 (FJN)**: every finite sublattice of `FL(X)` (equivalently: every finite lattice satisfying Whitman's condition (W)) has breadth at most 4. A finite lattice of breadth ≥ 5 cannot be embedded in any free lattice.

This bounds the parallelism budget at any element of `FL(X)`: at most 4 incomparable "components" jointly contribute to a join.

### 1.8 Continuity and incompleteness (Theorems 1.22–1.26)

**Theorem 1.22 (FJN)**: `FL(X)` for `|X| ≥ 3` is *not* a complete lattice — arbitrary subsets do not have suprema in general.

**Theorem 1.26 (continuity)**: `FL(X)` is *continuous* in a precise sense: it has no infinite ascending or descending chains over finitely-generated bounded intervals, modulo certain finiteness conditions. Restated: `FL(X)` is "approximately algebraic" — finite intervals are well-behaved even though the global lattice is not complete.

The combination — semidistributive + (W) + breadth-4 + continuous + non-complete — characterizes the structural profile of free lattices distinctively from free distributive or free modular lattices.

### 1.9 Algorithmic capstone (Chapter XI)

**Listing 11.12 (FJN)**: implementation of Whitman's algorithm with selective memoization. The algorithm decides `s ≤ t` by structural recursion through the six cases, caching subproblems via a hash table indexed by `(subterm-of-s, subterm-of-t)`.

**Lemma 11.36**: any node visited twice during the recursion can be answered in O(1) via the cache, since the answer was computed (or is in progress with memoized partial state) on first visit. This bounds repeated work.

**Theorem 11.23**: the canonical-form algorithm runs in time `O(can(s) + can(t))` where `can(·)` denotes canonical-form size. On *canonical input*, the comparison `s ≤ t` is linear. Naive Whitman without memoization is exponential in the worst case; the FJN selective-memoization algorithm is polynomial.

Reference: §11 of Freese-Nation "Free lattice algorithms" (Order 1, 1985); Chapter 11 of FJN 1995.

### 1.10 Cross-connections

- §1.2 Whitman cases enumerate the *only* nontrivial reductions; absent (W), the decision problem is harder (modular, distributive cases use additional rewriting).
- §1.6 Semidistributivity is the structural property that enables canonical forms to be unique-as-sets — this is generalized in §2 (Reading-Speyer-Thomas).
- §1.7 Breadth-4 bound is the parallelism constraint inherent to free-lattice computation.

---

## 2. Reading-Speyer-Thomas (2019/2021) — Fundamental Theorem of Finite Semidistributive Lattices

### 2.1 Foundational result

Reading, Speyer, and Thomas, "The fundamental theorem of finite semidistributive lattices" (Selecta Mathematica, New Ser. 27, 59 (2021); arXiv:1907.08050) construct a Birkhoff-style canonical form for *all* finite semidistributive lattices, generalizing both Birkhoff's representation theorem for finite distributive lattices and the canonical-form structure isolated by Freese-Nation in free lattices.

### 2.2 Statement of FTFSDL

**Fundamental Theorem of Finite Semidistributive Lattices (FTFSDL)**: a finite poset L is a finite semidistributive lattice if and only if there exists a set Sha(L) equipped with additional combinatorial structure (a "factorization system" / "torsion-pair-like" structure) such that L is isomorphic to the poset of *admissible subsets* of Sha(L), ordered by inclusion. Sha(L) and its structure are uniquely determined by L up to isomorphism.

The set Sha(L) corresponds to *labels of cover relations* in L. Cover relations `x ⋖ y` are labeled by pairs `(j_*, m^*)` where j is a join-irreducible (the canonical joinand by which y differs from x) and m is the corresponding meet-irreducible. The "labels" are pairs (J, M) of subsets of join- and meet-irreducibles that arise as such cover-relation labels; the additional structure encodes which subsets are *admissible*.

### 2.3 Generalization of Birkhoff and Freese-Nation

The theorem unifies and generalizes:

- **Birkhoff (§3 below)**: finite distributive lattice ↔ poset of join-irreducibles → lattice of order ideals. In the SD case, replace order-ideal admissibility with a richer admissibility predicate from the factorization data.
- **Freese-Nation canonical join representation**: in any finite SD lattice, every element has a unique canonical join representation as a join of a "canonical joinand" antichain. The FTFSDL recovers this as a corollary.

Specifically, every finite SD lattice has canonical join representations (that's a characterization of SD: a finite lattice is SD∨ iff every element admits a canonical join representation). The R-S-T construction packages all canonical join representations into the structure on Sha.

### 2.4 Algorithmic complexity

The construction is polynomial in `|L|`. Computing Sha(L) and its structure requires enumerating cover relations and their canonical labels — `O(|L|^2)` time on an explicit lattice representation. The reverse direction (recovering L from Sha) reads off admissible subsets — also polynomial.

For lattices given by generators (e.g., free SD presentations), the complexity is open in general; for finite lattices given as a Hasse diagram, it is polynomial.

### 2.5 Connection to convex geometries and torsion classes

The "additional structure" on Sha is a *combinatorial abstraction of torsion pairs* from representation theory. Specifically, for posets of regions of real hyperplane arrangements (which are SD), the structure has direct geometric meaning: shards (codimension-1 facets) of the arrangement.

For *meet-distributive* lattices (which are SD∨), the canonical join complex CJC(L) is a simplicial complex on join-irreducibles whose faces are canonical join representations; the FTFSDL shows this complex is the face poset of L when L is meet-distributive. Convex geometries (§9) are exactly the meet-distributive case.

### 2.6 Canonical forms

Every element `w` in a finite SD lattice L has:
- a unique **canonical join representation** `w = ⋁ J(w)` where J(w) is the *canonical joinand set* (an antichain of join-irreducibles);
- dually, a unique **canonical meet representation** `w = ⋀ M(w)`.

These pair up via the FTFSDL labels: the canonical joinands of `w` correspond exactly to the join-irreducibles that label cover relations *into* `w`.

### 2.7 Cross-connections

- §1: Free lattices are semidistributive (Theorem 1.21), but infinite. The Freese-Nation canonical form is the analogous arithmetic on `FL(X)`; FTFSDL extends to *all* finite SD lattices (which are not free).
- §3: FTFSDL generalizes Birkhoff (distributive ⊂ SD).
- §9: Convex geometries are the meet-distributive (a strengthening of SD∨) case.

---

## 3. Birkhoff Representation Theorem (1933/1937)

### 3.1 Foundational result

**Birkhoff's representation theorem (Birkhoff, 1937)**: every finite distributive lattice L is isomorphic to the lattice of order ideals (lower sets) `O(P)` of a finite poset P, where P is the subposet of `J(L)` (the set of join-irreducible elements of L) inherited from L. Conversely, for every finite poset P, the lattice `O(P)` of order ideals is a finite distributive lattice. The correspondence is bijective on isomorphism classes: distributive lattices ↔ posets of their join-irreducibles.

The isomorphism is concrete: each element `x ∈ L` corresponds to the order ideal `{j ∈ J(L) : j ≤ x}`. Lattice operations correspond to set operations: join ↔ union, meet ↔ intersection.

### 3.2 Algorithmic implications

- **Canonical form**: each `x ∈ L` is uniquely encoded by the antichain of *maximal* join-irreducibles below it (or equivalently, the order ideal it generates). This is the analog of disjunctive normal form.
- **Decision problem**: equality and order-comparison reduce to set comparisons — O(|J(L)|).
- **Boolean specialization**: when L is a finite *Boolean* lattice `2^n`, P is an antichain of n elements, and `O(P) = 2^n` recovers the powerset; canonical form is uniquely the set of generators below x — DNF/CNF dichotomy on Boolean polynomials.
- **DNF/CNF**: a Boolean function corresponds to its support (set of true assignments) — Birkhoff representation makes this canonical-form structure explicit.

### 3.3 Generalization to algebraic lattices (Hofmann-Mislove-Stralka 1974)

Every algebraic distributive lattice L (every element is the directed-join of compact elements below it; cf. §8) is isomorphic to the lattice of *Scott-open filters* of its compact elements, which generalizes the Birkhoff bijection to the infinite algebraic case. Hofmann-Mislove-Stralka, "Application of duality to lattice theory" (Springer LNM 396, 1974) provides the topological-algebraic framework: compact 0-dimensional semilattices are dual to discrete semilattices (Pontryagin-style duality), generalizing Birkhoff's combinatorial bijection.

### 3.4 Recent extensions

Caspard et al. (arXiv:2303.04267, 2023): a non-finite distributive lattice that is *locally finite* and has a bottom is isomorphic to the lattice of *finite* order ideals of its join-irreducibles. Locally-finite extension (arXiv:2603.05841) extends further. The infinite case requires topology; the finite-locally-finite case retains a purely combinatorial flavor.

### 3.5 Cross-connections

- §2 (FTFSDL) generalizes Birkhoff from distributive to semidistributive.
- §4 (Stone) generalizes to topological setting; Birkhoff is the discrete (purely combinatorial) facet of Stone duality.
- §9 (convex geometries / meet-distributive lattices, Edelman): meet-distributive lattices are the SD∨ analog of Birkhoff representation, where order ideals are replaced by *closed sets* of an antimatroid.

---

## 4. Stone Duality (1936/1938) and refinements

### 4.1 Stone duality for Boolean algebras (Stone 1936)

**Stone (1936) "The theory of representations for Boolean algebras"** (Trans. AMS 40): the category of Boolean algebras is dually equivalent to the category of *Stone spaces* (compact, Hausdorff, totally disconnected topological spaces, equivalently profinite spaces). The functors:
- `Spec`: Boolean algebra B ↦ space of ultrafilters of B with topology generated by sets `{U : b ∈ U}` for each `b ∈ B`.
- `Clop`: Stone space X ↦ Boolean algebra of clopen subsets of X.

The unit and counit of the adjunction are isomorphisms — full duality.

**Computational implication**: Boolean algebras decompose as products of "atomic" (point-like) factors precisely as their Stone space decomposes topologically. For finite Boolean algebras, the Stone space is a finite discrete set of points (cardinality = number of atoms = log₂ |B|); the duality recovers the powerset/atom dichotomy. Boolean polynomial canonical form (DNF) is precisely the join over a subset of atoms.

### 4.2 Priestley duality for distributive lattices (Priestley 1970)

**Priestley (1970) "Representation of distributive lattices by means of ordered Stone spaces"** (Bull. London Math. Soc. 2): bounded distributive lattices are dually equivalent to *Priestley spaces* — compact, totally order-disconnected ordered topological spaces (an ordered Stone space is Priestley iff: for any `x ≰ y`, there is a clopen up-set containing x but not y).

The functors:
- `Spec`: D ↦ space of prime filters of D with topology and the inclusion order.
- `ClopUp`: Priestley space → Boolean lattice of clopen upper sets.

For finite distributive lattices, the Priestley space is a finite poset (with discrete topology) — and we recover Birkhoff's theorem (§3): finite distributive ↔ finite poset.

**Computational implication**: distributive-lattice algorithms factor through the Priestley/poset side; for finite cases, this is exactly Birkhoff. For infinite cases, the topology is essential (compact + order-disconnected provides the constructive content).

### 4.3 Esakia duality for Heyting algebras (Esakia 1974)

**Esakia (1974) "Topological Kripke models"** (Soviet Math. Doklady 15): Heyting algebras (distributive lattices with relative pseudocomplement, i.e., implications `a → b`) are dually equivalent to *Esakia spaces* — Priestley spaces where the down-set of every clopen set is again clopen.

Equivalently, Esakia spaces are those Priestley spaces where the inclusion-order is "image-closed" under the topology. The algebraic operation `→` corresponds to the Esakia map `(↓X)^c` operation on the dual space.

**Computational implication**: intuitionistic logic (which Heyting algebras model) reduces to combinatorics on Esakia spaces. Decidability of intuitionistic propositional logic via finite-model property derives from the duality.

### 4.4 Spectral spaces and pairwise Stone (unifying framework)

Three categories are equivalent (or dually so) to bounded distributive lattices:
- **Spectral spaces** (Hochster 1969): topological space arising as spec of a commutative ring; Priestley spaces correspond to the *patch topology*.
- **Pairwise Stone spaces** (bitopological setting): a pair of Stone topologies (`τ_+, τ_−`) on a single set, jointly Hausdorff.
- **Priestley spaces**: ordered Stone spaces.

These three views unify Stone duality (Boolean), Priestley (distributive), and Esakia (Heyting) under a common framework. Generalizations (Gehrke et al., 2010s) extend to canonical extensions for arbitrary lattices.

### 4.5 Cross-connections

- §3 (Birkhoff): finite case of Priestley.
- §1 (free lattices): the Stone dual of `FL(X)` is more delicate — it requires moving outside Priestley (free lattices are not distributive).
- §6 (varieties): each variety has its own duality theory; Boolean is to Stone as distributive is to Priestley as Heyting is to Esakia.

---

## 5. Krull-Schmidt for Lattices

### 5.1 Foundational result

**Krull-Schmidt theorem (Krull 1925, Schmidt 1929; Remak 1911 in groups; Ore 1936 in lattices)**: in an "appropriate" algebraic structure (group, module, lattice with finite chain conditions), if an object `M` decomposes as a direct sum/product of indecomposable factors `M = M_1 ⊕ ... ⊕ M_n`, then any other such decomposition `M = N_1 ⊕ ... ⊕ N_m` has `n = m` and there is a permutation `π` with `M_i ≅ N_{π(i)}`.

For lattices, the relevant decomposition is into a *direct product* (`L_1 × L_2 × ...`) when L is a *direct factor* lattice, or, in the modular case, into "irreducibles" via the Kuros-Ore type theorems.

### 5.2 Lattice version (Ore 1936; Kuros-Ore)

**Ore's theorem (1936)**: in a modular lattice with both ascending and descending chain conditions, the Krull-Schmidt theorem holds: any two decompositions of an element as an irredundant meet of meet-irreducibles have the same number of factors, and corresponding factors are projective in the modular sense (up to a refinement permutation).

**Kuros-Ore replacement property**: in a modular lattice, if `a = a_1 ∧ ... ∧ a_m = b_1 ∧ ... ∧ b_n` are two irredundant meet decompositions into meet-irreducibles, then `m = n` and for each `a_i`, there is a `b_j` with `a = a_1 ∧ ... ∧ â_i ∧ ... ∧ a_m ∧ b_j` (the j-th factor "replaces" the i-th). In *distributive* lattices the replacement property strengthens to actual uniqueness up to permutation of the decomposition.

### 5.3 Goldie dimension as parallelism budget

**Goldie dimension (uniform dimension)** of a module M: the supremum of n such that there are n submodules `U_1, ..., U_n` whose sum is direct and each `U_i` is uniform. The lattice analog: in a complemented modular lattice, Goldie dimension is the maximal number of pairwise-complementary independent atoms summing to ⊤.

**Krull-Schmidt-Goldie connection**: in a modular lattice with finite Goldie dimension, the Krull-Schmidt theorem applies to the decomposition into uniform components. The Goldie dimension *is* the number of indecomposable factors — the "parallelism budget" of the structure.

### 5.4 Modern treatment (Călugăreanu 2000)

Călugăreanu, "Lattice Concepts of Module Theory" (Kluwer 2000, Texts in the Math. Sciences vol. 22) develops the lattice-theoretic version of module decomposition. Key chapters cover:
- Goldie dimension on modular lattices
- Uniform and biuniform elements
- Krull dimension via deviation
- Decomposition results parallel to module theory but stated entirely lattice-theoretically.

The book is the standard reference for the lattice → module dictionary in decomposition theory.

### 5.5 Recent extensions

- Failure mode: serial modules — Krull-Schmidt fails (Facchini, Springer 1998), with decomposition unique only up to *two* permutations.
- Couniserial dimension (Sahebi, Bull. Math. Sci. 2014, arXiv:1408.0056): characterizes when a refined K-S applies.
- Krull-Schmidt categories (Wikipedia entry "Krull–Schmidt category"): categorical formulation in additive categories with idempotent-completeness.

### 5.6 Cross-connections

- §7 (modular lattices): Krull-Schmidt is most natural in the modular setting.
- §6 (variety theory): Krull-Schmidt is a *structural* (not equational) property — definable in a quasivariety language but not a variety.
- §10 (Hasse profiles): Goldie dimension corresponds to the maximum antichain of independent atoms — bounds the "branching factor" of the Hasse diagram at the bottom.

---

## 6. Variety Theory of Lattices

### 6.1 Birkhoff HSP theorem (1935)

**Birkhoff (1935) "On the structure of abstract algebras"** (Proc. Cambridge Phil. Soc. 31): a class of algebras of a given signature is a *variety* (equationally definable class) if and only if it is closed under H (homomorphic images), S (subalgebras), and P (direct products). Varieties are exactly the equational classes.

### 6.2 Lattice of all lattice-varieties (Λ)

The collection of all varieties of lattices forms a *complete* lattice `Λ` ordered by inclusion. The lattice `Λ` is dual to the lattice of equational theories. Key elements:

- **Trivial** variety `T`: only one-element lattices. Bottom of `Λ`.
- **Distributive** variety `D` = `M_2`-free (no diamond) = `N_5`-free (no pentagon). Defined by `x ∧ (y ∨ z) = (x ∧ y) ∨ (x ∧ z)`. The next element above T.
- **Modular** variety `M`: defined by `x ≤ z ⇒ x ∨ (y ∧ z) = (x ∨ y) ∧ z`. Properly contains `D`.
- **Boolean** algebras `B`: distributive + complemented; not a *lattice* variety per se (signature includes `¬`), but Boolean lattices form an equational subclass.
- **All lattices** `L`: top of `Λ`.

There are countably many "atoms" of `Λ` near the bottom (covers of `T`); higher up `Λ` has cardinality `2^ℵ₀` (McKenzie 1972; Jónsson 1968).

### 6.3 Free lattices in subvarieties

For each variety V and set X, there is a relatively free lattice `FL_V(X)` — universal in V. Key facts:

- `FL_{T}(X)` is the one-element lattice.
- `FL_{D}(X)` (free distributive on n): finite for all n; size 2, 5, 19, 167, 7580, ... — the *Dedekind numbers* are |FL_D(n)| (or rather, a closely-related count of monotone Boolean functions). Computing |FL_D(n)| for n ≥ 9 is open.
- `FL_{M}(3)`: 28 elements (Dedekind 1900).
- `FL_{M}(4)`: infinite (Birkhoff 1935; word problem solvable for n=3, undecidable for n ≥ 5 — Freese 1980, Hutchinson 1973).
- `FL(X)` = free in `L`: infinite already for `|X| ≥ 3`.

### 6.4 Semidistributive — quasi-variety, not a variety

**Important**: SD∨ (and SD as the conjunction) is *not* a variety. SD is defined by an *implication* (`a ∨ b = a ∨ c ⇒ a ∨ b = a ∨ (b ∧ c)`), not an equation. Implications define *quasi-varieties*.

Per Jónsson 1995 (and earlier work), SD∨ is the quasi-variety generated by the closure lattices of finite convex geometries. The lattice of subquasivarieties is itself dually-algebraic and SD∨ — a self-referential observation.

### 6.5 Jónsson's lemma (1967)

**Jónsson's lemma**: if V is a congruence-distributive variety generated by a class K of finite algebras, then every subdirectly irreducible algebra of V is in `HSPu(K)` where `Pu` is ultraproducts. For varieties of *lattices* specifically, V is congruence-distributive (lattice congruences form a distributive lattice — automatic for any lattice variety).

Consequence: subdirectly-irreducible lattices in a finitely-generated variety form a finite set (up to isomorphism) — this gives strong structural control.

### 6.6 Whitman's variety theorem

**Whitman**: the variety `L` of all lattices is generated by `FL(X)` for any infinite X. Equivalently, lattice identities are exactly those satisfied by all free lattices, which Whitman's algorithm decides — making the equational theory of `L` decidable.

### 6.7 Finite axiomatizability

- `D` (distributive): finitely axiomatized (one identity).
- `M` (modular): finitely axiomatized (one identity).
- `L`: axiomatized by associativity, commutativity, idempotence, absorption — finite.
- McKenzie's theorem (1996): there exist finitely-generated lattice varieties that are *not* finitely based (no finite axiomatization exists).

Reference: Jipsen-Rose, "Varieties of Lattices" (Lecture Notes in Math. 1533, Springer 1992); Schmidt-Schweigert lectures.

### 6.8 Cross-connections

- §1 free lattice ↔ variety `L`.
- §7 modular lattices ↔ variety `M`.
- §9 (convex geometries) ↔ subclass of SD∨ (quasi-variety).

---

## 7. Modular Lattice Decomposition

### 7.1 Foundational result

**Modular law** (Dedekind): `a ≤ c ⇒ a ∨ (b ∧ c) = (a ∨ b) ∧ c`. Modular lattices generalize subspace lattices, normal-subgroup lattices, submodule lattices.

**Free modular lattice on n generators (FM(n))**:
- FM(1) = chain of length 1 (1 elt; or 2 with 0,1).
- FM(2) = chain of length ... (small).
- FM(3) = 28 elements (Dedekind 1900) — finite!
- FM(4) = infinite (Birkhoff 1935).
- FM(n) for n ≥ 4: infinite, with word problem decidable for n=3, *undecidable* for n ≥ 4 (Hutchinson 1973) or n ≥ 5 (Freese 1980, refined by Herrmann to n ≥ 4).

### 7.2 Word problem for FM (Freese 1980)

**Freese (1980) "Free modular lattices"** (Trans. AMS 261, 81–91): the word problem for `FM(5)` is recursively unsolvable. Subsequently refined to `FM(4)` by Herrmann (1983).

This contrasts sharply with FL (free lattice): *FL(X) for any X has decidable word problem (Whitman).* Adding modularity makes the problem worse, not better — modularity is restrictive enough to exclude (W) reductions but not restrictive enough to give canonical forms.

### 7.3 Canonical-form algorithms in modular lattices

For *finite* modular lattices, every element has a canonical join representation (like the SD case via FTFSDL — but modular lattices are *not* in general SD; they overlap with SD only at distributive). The relevant decomposition is:

**Dedekind's chain-refinement theorem (Jordan-Hölder-Dedekind)**: in a modular lattice of finite length, any two maximal chains between the same endpoints have the same length. Any two chains have isomorphic refinements (Schreier refinement theorem).

This is the *length* canonical form: all chains have a common length, and the length function is a rank function on the lattice. For `FM(3)` the structure is computable; for higher FM(n) length is unbounded.

### 7.4 Jordan-Hölder-Dedekind for chains

**Jordan-Hölder-Dedekind**: in a modular lattice of finite length:
- (Schreier) any two finite chains `c_1 < c_2 < ... < c_n` and `d_1 < d_2 < ... < d_m` between fixed endpoints have isomorphic refinements (refinements with the same multiset of factor "intervals").
- (Equal length) maximal chains have the same length.
- (Composition factors) the multiset of "covering quotients" `c_{i+1}/c_i` is uniquely determined.

For groups (whose subgroup lattice is modular), this is the Jordan-Hölder theorem.

### 7.5 Cross-connections

- §1: FL is *not* modular (FL contains a copy of FM(n) only via embedding, which fails: FM(4) is not embeddable in FL).
- §5 (Krull-Schmidt): modular + chain conditions ⇒ Krull-Schmidt. Decomposition into irreducibles is the substance.
- §10: in modular lattices, Hasse-diagram length is well-defined (rank).

---

## 8. Algebraic and Continuous Lattices (Scott 1972)

### 8.1 Foundational definitions

**Scott (1972) "Continuous lattices"** (Springer LNM 274): formalized the framework of continuous lattices for denotational semantics.

- **Way-below relation `≪`**: `a ≪ b` iff for every directed set D with `b ≤ ⋁ D`, there is `d ∈ D` with `a ≤ d`.
- **Compact element `c`**: `c ≪ c`.
- **Continuous lattice**: complete lattice L where `x = ⋁{a : a ≪ x}` for all `x ∈ L`.
- **Algebraic lattice**: continuous lattice where every element is a directed-join of compact elements (compact elements form a join-dense set).
- **Dcpo (directed-complete partial order)**: poset where every directed set has a supremum.

### 8.2 Representation for algebraic lattices

**Theorem**: every algebraic lattice L is isomorphic to the lattice of *ideals* (down-directed lower sets, or equivalently, ideals in the lattice-theoretic sense) of its compact elements `K(L)`. The compact elements form a sub-(meet)-semilattice of L; the lattice is recovered as ideals of this semilattice.

Equivalently: `L ≅ Sub(A)` for some algebra A (Birkhoff-Frink theorem). Conversely, every `Sub(A)` is algebraic.

### 8.3 Computability and continuity

Continuity (`x = ⋁{a : a ≪ x}`) is the lattice-theoretic counterpart of *computability*: the way-below relation captures "approximation." The Scott topology (`U` open iff `U` is up-closed and inaccessible by directed joins outside) makes continuous lattices into computable structures — Scott-continuous functions are exactly the ones computable in the limit-of-approximations sense.

Domain theory (Abramsky-Jung 1994; GHKLMS 2003) develops this for denotational semantics: `λ`-calculus models are continuous-lattice fixed points.

### 8.4 Stone-style duality for continuous lattices

- **Hofmann-Lawson 1979**: a compact 0-dimensional semilattice (Lawson semilattice) is dual to a discrete algebraic lattice.
- **Gierz-Hofmann-Keimel-Lawson-Mislove-Scott (2003) "Continuous Lattices and Domains"** (Cambridge Encyclopedia of Math. 93): comprehensive treatment.

These dualities generalize Birkhoff (finite distributive) and Stone (Boolean) into the continuous setting. For computable structures, the algebraic lattice = Stone-dual presentation; continuity adds the topology of approximation.

### 8.5 Recent extensions

- L-domains, stable Stone duality (Chen 1997, Goubault-Larrecq 2007+).
- Representations of continuous domains via formal contexts (arXiv:1809.05049).
- Bc-hulls and Clat-hulls (Goubault-Larrecq).

### 8.6 Cross-connections

- §3 (Birkhoff): finite case of algebraic-lattice representation; compact elements are the join-irreducibles in the finite distributive case.
- §4 (Stone): topological framework; continuous lattices generalize the algebraic case.
- §7 (modular): modular continuous lattices arise in von Neumann's continuous geometries (1937).

---

## 9. Convex Geometries (Edelman-Jamison 1985)

### 9.1 Foundational result

**Edelman-Jamison (1985) "The theory of convex geometries"** (Geometriae Dedicata 19, 247–270): a *convex geometry* is a closure system `(X, cl)` on a finite set X satisfying the **anti-exchange property**: if `y, z ∉ cl(A)` and `z ∈ cl(A ∪ {y})`, then `y ∉ cl(A ∪ {z})`.

Convex geometries are *combinatorial abstractions of convexity*: closed sets correspond to "convex hulls," and the anti-exchange property captures the geometric fact that convex hull is "anti-Steinitz."

The closed sets of a convex geometry, ordered by inclusion, form a *meet-distributive* lattice (a special kind of join-semidistributive lattice).

### 9.2 Equivalence with antimatroids

Convex geometries are dual to *antimatroids* (combinatorial structures where the closure operator is "anti-greedoid"). Specifically:
- An antimatroid is a family of sets (the "feasible sets") closed under union and satisfying an exchange axiom.
- The closure system of complements of feasible sets is a convex geometry.

Antimatroids and convex geometries are two sides of the same coin (one is the closure-of-complements of the other).

### 9.3 Lattice characterization

**Theorem (Edelman; Dilworth's earlier work on closure lattices)**: a finite lattice L is meet-distributive (every interval `[x, y]` has a unique maximal chain) iff L is the closure lattice of some convex geometry. In Birkhoff's spirit, this is the "distributive analog" for closure systems with anti-exchange.

The hierarchy:
- Distributive lattice = closure lattice of an order (lower-set system).
- Meet-distributive lattice = closure lattice of a convex geometry.
- Join-semidistributive lattice = closure lattice of a more general "AD-lattice" (Adaricheva-Gorbunov-Tumanov).

### 9.4 Adaricheva-Gorbunov-Tumanov 2003 — algebraic counterpart

**Adaricheva, Gorbunov, Tumanov (2003) "Join-semidistributive lattices and convex geometries"** (Adv. Math. 173, 1–49): every finite join-semidistributive lattice can be embedded into a lattice of *algebraic subsets* of a suitable algebraic lattice; the algebraic-subset lattice is itself a convex geometry. This is the "Birkhoff-style" representation for SD∨ — the closure-system viewpoint.

### 9.5 Adaricheva-Nation 2017 survey

Adaricheva-Nation, "Convex Geometries" in *Lattice Theory: Special Topics and Applications* (Birkhäuser 2016, ed. Grätzer-Wehrung), is the standard recent survey. Key points:
- Representation of convex geometries by points/circles/ellipses in the plane (cf. arXiv:1609.00092).
- Embedding theorems for finite SD∨ lattices.
- Convex dimension bounds (arXiv:1502.01941).
- Optimum-basis algorithms (Discr. Appl. Math. 2017).

### 9.6 Recent extensions (2020–2026)

- Adaricheva et al. (arXiv:2206.05636): convex geometries by colors and ellipses.
- Avann-style coordinatization extended to join-distributive lattices.
- Bridges to the FTFSDL (§2): meet-distributive lattices are exactly those finite SD lattices whose CJC is the face poset of L.

### 9.7 Cross-connections

- §2 (FTFSDL): meet-distributive lattices are a strengthening of SD; convex geometries are their closure-system view.
- §3 (Birkhoff): convex-geometry lattices generalize order-ideal lattices (where the geometry is an order).
- §6 (varieties): SD∨ is the quasi-variety generated by closure lattices of finite convex geometries.

---

## 10. Hasse Diagram Graph-Theoretic Properties

### 10.1 Foundational graph parameters

Let H(L) denote the Hasse diagram (cover graph) of a finite lattice L.

- **Width** `w(L)` (Dilworth 1950): largest antichain. Dilworth's theorem: `w(L) = min{number of chains in any chain decomposition of L}`. The width is the "horizontal parallelism" of L.
- **Height** (length of longest chain): for modular lattices = rank; bounds depth of any computation.
- **Mirsky's theorem**: dual of Dilworth — height = minimum number of antichains in an antichain decomposition.
- **Order dimension** (Dushnik-Miller 1941): minimum number of linear extensions whose intersection is the order.
- **Treewidth**: of the cover graph; controls MSO-decidability.
- **Diameter**: max graph distance between any two points.
- **Planarity**: whether H(L) is drawable without crossings.

### 10.2 Planarity (Platt 1976)

**Platt (1976) "Planar lattices and planar graphs"** (J. Comb. Theory B 21, 30–39): a finite lattice L is planar (its Hasse diagram drawable without crossings) iff the graph obtained by adding an edge from `⊥` to `⊤` is a planar graph in the graph-theoretic sense.

**Related**: a finite lattice has order dimension ≤ 2 iff its Hasse diagram is *st-planar* (planar with single source `⊥` and single sink `⊤` on the outer face).

Planar lattices are well-studied; they admit linear-time algorithms for many lattice operations.

### 10.3 Treewidth and Courcelle's theorem

**Courcelle's theorem (1990)**: every graph property expressible in monadic second-order logic (MSO) can be decided in linear time on graphs of bounded treewidth. Applied to lattices: if `tw(H(L)) ≤ k` is bounded, then MSO-definable lattice properties are decidable in linear time in `|L|`.

Joret et al. (Combinatorica 2014, arXiv:1301.5271) proved: the *order dimension* of a finite poset is bounded in terms of its height and the treewidth of its cover graph. So treewidth bounds dimension; bounded-treewidth lattices have bounded dimension and admit efficient algorithms.

### 10.4 Per-variety graph-theoretic profiles

| Variety | Characteristic Hasse-diagram profile |
|---|---|
| **Trivial (T)** | Single point. |
| **Boolean B (= 2^n)** | Hypercube graph `Q_n`: cover graph is `n`-dimensional hypercube. Width `C(n, ⌊n/2⌋)` (Sperner). Height n. Diameter n. Planar only for n ≤ 2. Treewidth `Θ(n / sqrt(n))` (Chandran-Subramanian). Hypercube is a *spectral expander* with second eigenvalue `n−2` (out of n). |
| **Distributive D** | Order-ideal lattice of poset P. Width = `w(P)` extended; height = |P|. Treewidth bounded by structural properties of P. By Birkhoff: H(L) is the "filter-extension" graph of P. |
| **Modular M** | Rank function exists (J-H-D); height = rank. Width: no general bound. Many natural examples: subspace lattices `L(V)` (projective geometry). |
| **Semidistributive (SD, quasi-variety)** | Canonical join representation gives bounded fan-in (no general width bound). Free lattices ⊂ SD: breadth ≤ 4 (Cor. 1.31). |
| **Free (FL)** | Within FL: breadth-4 bound (per Cor 1.31). FL is not finite, so global graph parameters are not all defined; finite intervals satisfy SD + breadth ≤ 4. |
| **Convex geometries / meet-distributive** | Closure lattices; linearly extendable to permutations (Avann coordinatization). Width = number of "atoms" of the closure system; closely tied to convex dimension. |
| **All lattices L** | No constraint; arbitrary cover graphs that are "lattice-like" (bounded, every two elements have unique meet/join). |

### 10.5 Hypercube as expander (Boolean lattice)

The Boolean lattice `B_n = 2^n` has cover graph `Q_n` (hypercube), which is a celebrated combinatorial expander. The eigenvalues of `Q_n`'s adjacency matrix are `{n − 2k : k = 0, ..., n}` with multiplicity `C(n, k)`. Spectral gap = `2`, which (after normalization) gives expansion factor `Θ(1/n)`. While not a "constant-degree expander," `Q_n` admits high-dimensional expander variants (Dikstein et al., Combinatorica 2024).

The expander structure underlies:
- Boolean function analysis (Fourier on `Q_n`).
- Hamilton decomposition of `Q_n` (Ringel; every `Q_n` admits a Hamilton decomposition).
- Gray code (Hamiltonian path on `Q_n`).

### 10.6 Width-as-Goldie-dimension

For modular lattices, *Goldie dimension* (§5) is the supremum of n such that there are n independent atoms summing to ⊤. This is the "atom-level width" — bounded by the lattice width but more structural (it counts independence, not arbitrary antichains).

For complemented modular lattices (e.g., subspace lattices), Goldie dimension = lattice rank = vector-space dimension. This is the canonical "parallelism budget."

### 10.7 Cross-connections

- §1 breadth-4 bound is a Hasse-diagram statement about FL.
- §3 (Birkhoff): for distributive lattices, the cover graph mirrors the underlying poset's cover graph in a structural way.
- §5 (Krull-Schmidt): width / Goldie dimension bound the parallel decomposition.

---

## Synthesis: Variety Hierarchy with Per-Level Capabilities

```
                         L (all lattices)
                        / |  Whitman's algo: word problem decidable
                       /  |  Free FL: SD + breadth-4 + (W) + non-complete
                      /   |  Continuity (Th. 1.26): finite intervals well-behaved
                     /    |
                    /  SD (quasi-variety; not a variety)
                   /   |    Canonical join repr (R-S-T 2019)
                  /    |    FTFSDL: Sha(L) determines L
                 /     |    Free lattices ⊂ SD
                /      |
               /     SD∧ ∩ SD∨ = SD (semidistributive)
              /      / 
             /      /
            /    SD∨ (join-SD): closure lattices of convex geometries (A-G-T)
           /     |
          /      meet-distributive (= closure of convex geometry; Edelman 1985)
         /       |   Convex geometries (Edelman-Jamison)
        /        |   Birkhoff-style canonical: closed-set representation
       /         |
      M (modular)|
      | Free FM(3)=28; FM(4)=∞; word problem undecidable for n≥4
      | Krull-Schmidt + Jordan-Hölder-Dedekind: chains of equal length
      | Goldie dimension = atom-level parallelism
      |
     D (distributive)
     | Birkhoff representation: O(P) for poset P of join-irreducibles
     | DNF/CNF canonical form
     | Free FD(n) = Dedekind numbers (finite)
     |
    B (Boolean) — distributive + complemented
    | Stone duality (compact Hausdorff totally disconnected)
    | Hypercube Q_n; Gray code; expansion structure
    | DNF unique up to permutation
    |
   T (trivial)
```

**Per-level capability summary**:

| Variety | Canonical-form algorithm | Decomposition | Word problem | Hasse profile |
|---|---|---|---|---|
| `T` | Trivial | Trivial | Trivial | Point |
| `B` (Boolean) | DNF unique up to ordering | Stone dual = atoms; product = disjoint union of Stone spaces | Linear (truth table) | Hypercube `Q_n`, expander |
| `D` (distributive) | Order ideal of `J(L)` (Birkhoff) | Sub-direct: irreducibles via Jónsson's lemma | Polynomial | Determined by poset of join-irreducibles |
| `M` (modular) | Length / rank function via J-H-D | Krull-Schmidt-Goldie (modular + chain) | Decidable for FM(3); UNDECIDABLE for FM(n≥4) | Rank function exists; chains equal length |
| `SD` (semidistributive) | Canonical join repr (R-S-T 2019); polynomial in `|L|` | FTFSDL via Sha(L) | Open in general; decidable for finite | Bounded fan-in via canonical joinands |
| `SD∨` meet-distributive | Closed-set representation (Edelman) | Convex geometry / antimatroid | Polynomial | Closure-system poset |
| `L` (all lattices) | Whitman's algorithm via canonical form (FJN Listing 11.12); polynomial w/ memoization | Free lattice arithmetic; canonical join repr | Decidable (Whitman) | Free lattice has breadth ≤ 4 (Cor 1.31) on finite sublattices |

---

## Canonical-Form Algorithms — Comparison Table

| Variety | Canonical Form | Algorithm | Complexity | Key Reference |
|---|---|---|---|---|
| Boolean (B) | Disjunctive normal form (set of true minterms) | Truth-table evaluation | `O(2^n)` for n vars; `O(|f|)` on ROBDD | Stone 1936 |
| Distributive (D) | Order ideal of join-irreducibles | Birkhoff bijection: enumerate maximal join-irreducibles below each element | `O(|J(L)| × |L|)` | Birkhoff 1937 |
| Free distributive | Monotone Boolean function | Dedekind enumeration | Open for n ≥ 9 | Dedekind 1897; Wiedemann 1991 |
| Modular (M, finite) | Chain length + composition factors | Refinement to maximal chain | Polynomial in `|L|` | Jordan-Hölder-Dedekind |
| Free modular FM(n) | (None for n ≥ 4) | Word problem undecidable | UNDECIDABLE for n ≥ 4 | Freese 1980; Hutchinson 1973 |
| Finite SD lattice | Canonical join representation `J(w)` | FTFSDL: cover-relation labels → Sha → admissible subsets | `O(|L|^2)` | Reading-Speyer-Thomas 2019/2021 |
| Convex geometry | Closed set / antichain in poset of "extreme points" | Closure operator | Polynomial in ground set | Edelman-Jamison 1985 |
| Free lattice FL | Minimum-rank term (FJN Theorem 1.17) | Whitman's algorithm with selective memoization (Listing 11.12) | `O(can(s) + can(t))` on canonical input; polynomial overall | Whitman 1941; FJN 1995 |
| Algebraic lattices (continuous) | Directed-join of compacts | Compact-element ideal representation | Topological / non-uniform | Scott 1972; GHKLMS 2003 |

---

## Algorithmic Highlights and Complexity Summary

1. **Whitman's algorithm** (free lattice): polynomial via memoization (FJN Listing 11.12, Theorem 11.23 — `O(can(s)+can(t))` on canonical input). Naive recursive Whitman is exponential.

2. **Birkhoff representation** (distributive): linear in `|L|` once `J(L)` is computed; `J(L)` itself is `O(|L|^2)` (find join-irreducibles).

3. **FTFSDL construction** (finite SD): polynomial in `|L|`. Cover relations `O(|L|^2)`; canonical labels `O(|L|^2)`; admissibility check `O(|L|^2)` per element.

4. **Stone-Priestley-Esakia dualities**: not algorithmic per se; provide combinatorial vs. topological canonical forms. For finite lattices, reduce to Birkhoff (distributive case), atom-set (Boolean case), or Esakia poset (Heyting case).

5. **Krull-Schmidt-Goldie**: `n log n` for modular finite-length once indecomposables are identified (sorting by isomorphism type).

6. **Jordan-Hölder-Dedekind chain refinement**: computing rank is `O(|L|)` BFS on Hasse diagram in modular lattice; chain refinement is polynomial in chain length.

7. **Convex-geometry closure system**: closure operator is `O(|X|^2)` per call; canonical form of a closed set is the closure itself.

8. **Modular lattice word problem**: undecidable for FM(n ≥ 4). The contrast with FL — where Whitman gives decidability — is structurally significant: imposing modularity removes the (W) reductions but does not give canonical join refinements.

---

## References

### Books
- **Birkhoff, G.** (1967). *Lattice Theory*, 3rd ed. AMS Colloquium Publications 25.
- **Călugăreanu, G.** (2000). *Lattice Concepts of Module Theory*. Kluwer, Texts in the Math. Sciences vol. 22.
- **Davey, B.A. & Priestley, H.A.** (2002). *Introduction to Lattices and Order*, 2nd ed. Cambridge.
- **Edelman, P.H. & Jamison, R.E.** (1985). "The theory of convex geometries." *Geom. Dedicata* 19, 247–270.
- **Freese, R., Ježek, J., Nation, J.B.** (1995). *Free Lattices*. AMS Mathematical Surveys and Monographs 42. ISBN 0-8218-0389-1.
- **Gierz, G., Hofmann, K.H., Keimel, K., Lawson, J.D., Mislove, M.W., Scott, D.S.** (2003). *Continuous Lattices and Domains*. Cambridge Encyclopedia of Mathematics 93.
- **Grätzer, G. & Wehrung, F. (eds.)** (2016). *Lattice Theory: Special Topics and Applications*, vol. 2. Birkhäuser. (Includes Adaricheva-Nation "Convex Geometries.")
- **Jipsen, P. & Rose, H.** (1992). *Varieties of Lattices*. Lecture Notes in Math. 1533, Springer.
- **McKenzie, R., McNulty, G., Taylor, W.** (1987). *Algebras, Lattices, Varieties* vol. I. Wadsworth.
- **Nation, J.B.** *Notes on Lattice Theory*. Lecture notes, Univ. of Hawaii.

### Foundational papers
- **Birkhoff, G.** (1933). "On the combination of subalgebras." *Proc. Cambridge Phil. Soc.* 29.
- **Birkhoff, G.** (1935). "On the structure of abstract algebras." *Proc. Cambridge Phil. Soc.* 31. (HSP theorem.)
- **Birkhoff, G.** (1937). "Rings of sets." *Duke Math. J.* 3. (Representation theorem.)
- **Dedekind, R.** (1900). "Über die von drei Moduln erzeugte Dualgruppe." *Math. Ann.* 53, 371–403. (FM(3) = 28.)
- **Dilworth, R.P.** (1950). "A decomposition theorem for partially ordered sets." *Annals of Math.* 51, 161–166.
- **Esakia, L.** (1974). "Topological Kripke models." *Soviet Math. Doklady* 15.
- **Freese, R.** (1980). "Free modular lattices." *Trans. AMS* 261, 81–91.
- **Freese, R. & Nation, J.B.** (1985). "Free lattice algorithms." *Order* 1, 331–350.
- **Hofmann, K.H., Mislove, M., Stralka, A.** (1974). *The Pontryagin Duality of Compact 0-Dimensional Semilattices and its Applications*. Springer LNM 396.
- **Hutchinson, G.** (1973). Word problem for FM(n), n ≥ 4. *Algebra Universalis* 3.
- **Jónsson, B. & Kiefer, J.E.** (1962). "Finite sublattices of a free lattice." *Canadian J. Math.* 14, 487–497.
- **Krull, W.** (1925) / **Schmidt, O.** (1929) / **Ore, O.** (1936). Krull-Schmidt theorem (various venues).
- **Platt, C.R.** (1976). "Planar lattices and planar graphs." *J. Comb. Theory B* 21, 30–39.
- **Priestley, H.A.** (1970). "Representation of distributive lattices by means of ordered Stone spaces." *Bull. London Math. Soc.* 2, 186–190.
- **Reading, N., Speyer, D.E., Thomas, H.** (2021). "The fundamental theorem of finite semidistributive lattices." *Selecta Math.* (N.S.) 27, 59. arXiv:1907.08050.
- **Scott, D.** (1972). *Continuous Lattices*. Springer Lecture Notes in Math. 274.
- **Stone, M.H.** (1936). "The theory of representations for Boolean algebras." *Trans. AMS* 40, 37–111.
- **Whitman, P.M.** (1941). "Free lattices." *Annals of Math.* 42, 325–330.
- **Whitman, P.M.** (1942). "Free lattices II." *Annals of Math.* 43, 104–115.

### Recent extensions (2020–2026)
- **Adaricheva, K., Gorbunov, V.A., Tumanov, V.I.** (2003). "Join-semidistributive lattices and convex geometries." *Adv. Math.* 173, 1–49.
- **Adaricheva, K. & Nation, J.B.** (2016). "Convex geometries." Chapter in Grätzer-Wehrung (eds.).
- **Caspard, N., et al.** (2023). "An extension of Birkhoff's representation theorem to infinite distributive lattices." arXiv:2303.04267.
- **Dikstein, Y., et al.** (2024). "Boolean function analysis on high-dimensional expanders." *Combinatorica*.
- **Gehrke, M.** (2014). "Canonical extensions, Esakia spaces, and universal models." In *Leo Esakia on Duality in Modal and Intuitionistic Logics* (Springer).
- **Joret, G., et al.** (2014). "Tree-width and dimension." *Combinatorica* 34. arXiv:1301.5271.
- **Albertin, D. & Pilaud, V.** (2021). "The canonical complex of the weak order." arXiv:2111.11553.

### Lecture notes / surveys
- **Freese, R.** "Algorithms for finite, finitely presented and free lattices." Univ. of Hawaii preprint.
- **Nation, J.B.** "Notes on join-semidistributive lattices." Math. Hawaii preprint.
- **Jipsen, P.** "Mathematical structures: Lattices." Chapman University, online.

---

## Open questions and active research directions (2026)

1. **Word problem for finite SD lattices given by generators**: open in general; FTFSDL gives canonical form for finite SD lattices given as Hasse diagrams, but not as presentations.
2. **Dedekind numbers**: |FD(9)| and beyond — open. (Dedekind numbers count monotone Boolean functions; recent progress: |FD(9)| computed in 2023 via parallel computation.)
3. **Convex dimension of finite SD∨ lattices**: bounds (arXiv:1502.01941) but exact computation hard.
4. **Decidability boundaries**: free modular FM(4), free distributive lattices over relations, free Heyting algebras — varying decidability profiles.
5. **Algorithmic FTFSDL**: efficient computation of Sha(L) for large finite SD lattices; structural shortcuts beyond `O(|L|^2)`.
6. **Quasi-variety lattice of SD**: structure of subquasivarieties of SD; itself a SD∨ lattice (self-referential).

---

## Notes on sources and gaps

- Several theorem numbers (1.17, 1.18, 1.19, 1.21, 1.31) referenced from the FJN 1995 monograph could not be verified verbatim from text-extractable sources during this survey (the math.hawaii.edu PDFs render as binary in WebFetch). The statements above are reconstructed from secondary literature, the FJN Chapter 1 preprint (math.hawaii.edu/~ralph/Classes/649M/FreeLatChap.pdf), and corroborated lecture notes (Nation, J.B. *Notes on Lattice Theory* §6 "Free Lattices"). Direct consultation of FJN 1995 is recommended for verbatim statements when integrating this survey.
- The "Listing 11.12" reference is to Chapter XI of FJN 1995. Some sources cite Listing 11.16 as the implementation; the difference is edition-dependent. Reference the FJN book directly.
- Esakia 1974: original Russian text; standard secondary references (Bezhanishvili, Gehrke 2014) suffice for citation.
- Modern syntheses of Stone/Priestley/Esakia: Gehrke "Canonical extensions" (2014) is the unifying recent reference.
