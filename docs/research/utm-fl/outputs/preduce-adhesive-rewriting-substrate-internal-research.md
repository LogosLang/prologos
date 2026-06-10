# PReduce Adhesive-Rewriting Substrate — Internal Research Note

**Status**: 🔄 in progress (opened 2026-05-09, S0 spine work). Internal-research note per programme convention; co-evolves with PReduce engineering. Do not promote to external paper without an explicit decision in `paper-drafts/`.

**Owner**: Avanti.

**Programme home**: `docs/research/utm-fl/PROGRAMME.md` §3 (engineering ↔ research vector); `outputs/*-internal-research.md` pattern from §9.

**Companion engineering**: `docs/tracking/2026-05-02_PREDUCE_MASTER.md` (Tracks 0.1, 1, 4, 5, 6). This note is a *map*, not a deliverable; PReduce sub-track designs cite this note when the relevant section is mature.

---

## §0 What this note is for

A working architectural map for PReduce that **integrates** the four pillars already developed across the broader `docs/research/` corpus — adhesive-DPO hypergraph rewriting, e-graphs, tropical quantales, GoI — into a single picture and asks what design choices the picture forces (or frees) on PReduce Tracks 1, 4, 5, 6.

It is **not** a literature review (the four pillar notes already do that). It is **not** an external paper (those live in `paper-drafts/`). It is **not** a Track 0.1 architectural sketch (that exists at `docs/research/2026-05-02_PREDUCE_TRACK01_ARCHITECTURAL_SKETCH.md`). It *is* the integration step that turns the four pillars into one set of well-posed engineering questions.

The thesis it converges on (subject to this note's own findings):

> The Prologos parsing and elaboration substrate already runs as adhesive-DPO hypergraph rewriting on lattice-valued cells in a propagator network (PPN + SRE Track 2D). E-graphs are the adhesive subcase needed for term-rewriting equivalence classes. Tropical quantales annotate cells with multi-dimensional cost; quantale residuation drives backward search. GoI is the operational semantics of the rewriting fixpoint. PReduce extends the same substrate from parsing/elaboration to reduction. The engineering questions on PReduce Tracks 1, 4, 5, 6 are specializations inside this single picture, not independent design problems.

---

## §1 Methodology

The note grows in two passes. **Pass 1 (S0): spine grounding** — locate, read, stress-test, and external-cross-check the four load-bearing claims that the spine rests on. **Pass 2 (S1–S5): specialization** — for each engineering decision, work out what the spine forces / frees / leaves open.

### §1.1 Per-claim workflow (used through this whole note)

For every load-bearing claim — spine or specialization — apply five steps:

1. **Locate** in our corpus via `mempalace search` + `grep`. Note the exact file + section.
2. **Read** the corpus location directly (do not rely on the snippet).
3. **External probe** via `alpha` paper search + `web_search` + `alpha_get_paper`. Look for: (a) prior art that confirms; (b) prior art that complicates or contradicts; (c) post-2024 developments that change the claim's strength.
4. **Stress-test**: write down what would falsify the claim or constrain its scope.
5. **Memo entry** in the form below.

### §1.2 The 4-column memo format

Each load-bearing claim gets one row:

| Claim | Where defended in our corpus | External evidence | Strength + proof obligation |
|---|---|---|---|

Strength uses the discipline from `memory/prologos.quantale_proof_status`, with one addition specific to this note's substrate-first/theory-after posture (see §2.0):

- **Theorem** — cited and read; we trust the citation.
- **Engineered & tested** — we ship code or design that depends on this; PIRs/tests exist.
- **Structural conjecture** — the substrate suggests it; we haven't proved it; not yet for external claims.
- **Asserted** — in the corpus, no defense yet; needs work.
- **Speculative bridging** *(new for this note)* — drawn from adjacent mathematics or open frontiers; not yet formalized for our setting; useful as an engineering guide if it holds; honest about its un-grounded status. Citable internally; **not** citable externally as theorem.

When a claim is downgraded by external evidence, the row is amended in place and the change is noted in §10 (drift log). When a claim is upgraded by external corroboration, same. **Speculative-bridging entries are not drift when they remain unproved — they are tracked as durable open directions, not pending obligations.**

### §1.3 Mempalace cross-check discipline

Per `.claude/rules/mempalace.md`: mempalace is good for stable architectural concepts; never for "is X still true?" without checking the latest dailies. Every mempalace hit cited here gets a `Source: <file> @ <YYYY-MM-DD>` annotation; if the file is older than the most recent dailies that mention the claim's topic, the dailies win.

### §1.4 External tool posture

- `alpha_get_paper` works (verified 2026-05-09). Use for full-text retrieval of arXiv papers.
- `alpha_search` / `alpha_ask_paper` patched today (active next session) — until then, fallback through `web_search` for discovery and `alpha_get_paper` for retrieval.
- `web_search`: primary discovery for current literature; recencyFilter=year for active work.
- `fetch_content` for HTML; `document_parse` for local PDFs.

---

## §2 Pass 1: spine grounding (S0)

### §2.0 Posture — substrate-first, theory-after

The Prologos engineering effort has, as a project-level methodological norm, repeatedly built structures that did not yet have a closed categorical / algebraic theory. The categorical frame is found *afterward*, by recognizing the structure in adjacent mathematics. Owner-named precedent: **logical resolution on propagator networks** — no prior literature did this; enough adjacent suggestion existed (lattices + constraint solving + propagator datastructures) to attempt it; the structure ships and the theoretical recognition follows.

Two consequences for this note:

1. **The four spine claims do not all need to land as Theorem-status before PReduce engineering proceeds.** Many already-shipping parts of Prologos rely on Speculative-bridging-strength claims that are not yet closed. The pattern is normal here, not exceptional.
2. **We actively *welcome* the active-research frontier**, not just tolerate it. Where a frontier exists in the literature that has not yet absorbed our substrate's specifics, we are on the frontier by construction and should engage with it as collaborators-via-engineering rather than as consumers waiting for theorems. The frontier locations are themselves diagnostic: they tell us where adjacent mathematics will *next* shape our engineering, and where our engineering may shape it back.

With that posture in place, we still want to know what's grounded vs what's speculative — the labels matter for *internal* navigation. The 4-column memo and strength labels (§1.2) are the way we keep that distinction clear.

### Spine claims (worked in this order; each is a precondition for the next)

Four load-bearing claims:

- **C1**: e-graphs are adhesive (Biondo-Castelnovo-Gadducci CALCO 2025). *Establishes that PReduce's e-class subcase inherits the adhesive guarantees.*
- **C2**: adhesive ↔ CALM. *Tells us what the adhesive substrate actually buys us in our (lattice + propagator + monotone-merge) idiom — this is the structural reason "two strata is enough" in PReduce master.*
- **C3**: e-graphs as quotient modules; backward chaining as residuation. *Connects the adhesive picture to the quantale picture; gives us the math shape of cost-guided extraction.*
- **C4**: GoI execution formula = propagator network fixpoint; structural identity, not metaphor. *Tells us the runtime story is automatic, not an extra engineering effort.*

Each claim gets §2.C{n} below.

### §2.C1 — E-graphs are adhesive (paraphrased; **downgraded — they are M-adhesive**)

*Status entering this section*: cited as a flat "adhesive" theorem in three corpus locations (PReduce 0.1 §10.4, e-graphs note §3.1, hypergraph note §3.3) without engagement of the proof.

*Status after working through the paper*: **the corpus claim is paraphrased and overstates the result**. The actual theorem is M-adhesive for a *specific restricted* class M = T_Σ, and the EGG-rule format used in practice (egg, egglog) sits in a *left-linear* M-adhesive sub-setting that is **active research, not closed theory** — by the authors' own admission (§7 of the paper).

#### What the paper actually proves

The headline theorem is **Corollary 5.15**:

> **Corollary 5.15** (Biondo–Castelnovo–Gadducci, arXiv:2503.13678 v1, CALCO 2025). `EGG` is `T_Σ`-adhesive.

Unpacked:

- **`EGG`** is the category of *e-term graphs*: term graphs (acyclic hypergraphs labelled by an algebraic signature Σ, with `t_G` mono) equipped with an equivalence relation `q : V_G ↠ Q_G` on nodes, **closed under operator application** (Definition 5.1 + 5.10): if a ≡ b then f(a) ≡ f(b) for every signature operator f. This matches the egg/egglog implementation.
- **`T_Σ`** (definition before Prop 4.24, refined in §5.2) is the class of EGG morphisms (h_E, h_V, h_Q) whose components are all injective AND whose underlying square between V_G → V_H and Q_G → Q_H (under the quotient maps) is a *pullback*. This is a **strict subclass of the regular monos**.
- **`T_Σ`-adhesive** means: the M-adhesive axioms (Def 2.2) hold for `M = T_Σ`. M-adhesive (Ehrig-Golas-Habel-Lambers-Orejas 2012, 2014; Heindel 2009) restricts the van Kampen condition to a designated class M of monos rather than all monos. By Remark 2.3 of the paper, full adhesivity = strict `Mono(X)`-adhesivity, and quasiadhesivity = strict `Reg(X)`-adhesivity. **Neither holds for `EGG`.**

The paper itself notes the negative result one rung down (Remark 3.23): `TG_Σ` (term graphs without equivalence) **is not adhesive at all** — it lacks pushouts along all monos. It is only quasiadhesive (Corollary 3.27). Adding equivalences strengthens it back up to T_Σ-adhesive, but not to full adhesive.

#### Caveat from the paper's own §6 / §7 (the load-bearing one)

Reading §6 "Pros and cons of adhesive rewriting" makes a second restriction explicit — one our corpus does not mention:

> *"the structure of rules that is advanced in [13] is given as a span L ← L → R, where the first component is the identity, thus in Pb_Σ, while the second component may not belong to Pb_Σ."*

In other words, **the EGG rule format used in practice (egg, egglog, and what PReduce would build) is *left-linear* in the sense of [3] = Baldan-Castelnovo-Corradini-Gadducci, CONCUR 2024, *"Left-linear rewriting in adhesive categories"***. The left leg is the identity (trivially in M), but the right leg `L → R` is a regular mono that **may not be in M** (Pb_Σ). The paper's own §1 admits:

> *"If only the left-hand side belongs to M, the current theory is still under development, as witnessed e.g. by [3]."*

And the paper's own §7 (Conclusions) flags that even basic DPO transfer is *not* established for the EGG case:

> *"It still needs to be exploited how parallelism and causality, the key features for DPO rewriting on M-adhesive categories, can be exploited in the context of implementing the EGGs updates."*

So the strongest current state is:
- **EGG is T_Σ-adhesive.** ✅ (Theorem; cited correctly with this scope.)
- **EGG rewriting fits the left-linear M-adhesive frame.** ✅ (Stated by the authors.)
- **Standard DPO theorems on parallelism, causality, critical pairs transfer.** ⚠️ *Not yet established for the EGG-specific left-linear M-adhesive setting; explicitly flagged as open in §7 of the paper.*

#### What this means for our corpus claims (concrete drift)

| Our paraphrase | Actual position |
|---|---|
| *"E-graphs are adhesive"* (PReduce 0.1 §10.4, e-graphs note §3.1, hypergraph note §3.3) | **Overstated.** They are T_Σ-adhesive, a strictly weaker M-adhesivity. |
| *"DPO rewriting rules over e-graphs are well-behaved"* (e-graphs note §3.1) | **Half-true.** Rule application well-defined; *standard* DPO theorems (parallelism, causality, critical-pair) NOT yet ported to the EGG-specific left-linear M-adhesive case per the paper's own §7. |
| *"Equality saturation can be understood as iterated DPO rewriting"* (e-graphs note §3.1) | **Holds, with NACs (negative application conditions).** Paper §6 notes EGG rules need NACs to prevent endless reapplication; NAC theory for M-adhesive exists [Ehrig et al. 2012, 2014]. |
| *"Confluence and parallelism analysis tools for adhesive categories apply directly"* (e-graphs note §3.1) | **Premature.** "Apply directly" is too strong. The transfer is the open research direction the paper opens, not a result it closes. |
| *"The same theoretical machinery applies to PReduce's e-class cells and rewrite rules. We don't need a separate framework; the SRE foundations transfer."* (e-graphs note §3.1) | **Needs scope check.** SRE Track 2D's adhesive guarantees (per `2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md` §2) were proved on a *strict adhesive* category (parse trees as presheaves; toposes are adhesive per Lack-Sobocinski 2005, Ex 2.5 of this paper). **Strict-adhesive results do NOT automatically transfer to T_Σ-adhesive structures.** The transfer must be argued *for the specific theorem* being inherited — it can't be assumed wholesale. |

#### Implications for PReduce engineering decisions

0. **Reframing under §2.0 posture (substrate-first / theory-after)**: the M-adhesive frontier the Biondo paper opens is *exactly the kind of frontier our substrate already lives on*. The fact that the standard DPO transfer theorems are not yet ported to the EGG-specific left-linear M-adhesive setting does not block PReduce engineering — it identifies an active research direction we should engage with, citing Baldan et al. CONCUR 2024 and the engineering practice of egg/egglog as joint evidence. C1's downgrade is a vocabulary correction (don't say "adhesive" when you mean "M-adhesive") and a new requirement (NACs), not a structural blocker.

1. **Master's PReduce-extends-Track-2D inheritance claim needs softening.** The PReduce Master §"Cross-series connections" says "SRE Track 2D delivered 13 concrete DPO rewrite rules + adhesive guarantees; PReduce extends the rule registry to term reduction, generalizing the SRE form-registry pattern." The *registry* generalization is fine; the *adhesive guarantees* claim needs to be restated as: "PReduce's e-class subsystem operates in a different M-adhesive variant; per-theorem inheritance must be checked."

2. **Track 2 (β-reduction as IN-fragment) is unaffected by this drift.** IN-fragment confluence (Lafont 1990) does not route through M-adhesive theory. The strong-confluence-by-binary-principal-port argument is independent. Lattice cell merge + IN-fragment property tag is a clean stratum-S0 commitment.

3. **Track 3 (ι-reduction as adhesive-DPO with critical pairs) is the one that lives directly in the M-adhesive frontier.** The critical-pair-analysis-as-runtime claim depends on the parallelism/causality theorems that the paper itself flags as not-yet-ported. Two paths forward:
   - **(a) Stay in the strict-adhesive variant** by representing case selection on parse-tree-presheaves (SRE Track 2D's home) rather than on EGG. Loses the equivalence-class identification that e-graphs give us.
   - **(b) Stay in EGG and accept the left-linear M-adhesive frontier risk.** Cite Baldan-Castelnovo-Corradini-Gadducci CONCUR 2024 [3] as the active state-of-the-art; flag in PReduce design that critical-pair theorems are *empirically* supported (egg/egglog ship working implementations) but *not yet* fully formalized in the Biondo-et-al. setting.

4. **Track 4 (cost-guided extraction via residuation) is essentially independent.** Extraction is a separate optimization on top of the e-class structure; its correctness reduces to monotonicity of the cost function on the e-class poset, not to DPO confluence. Multi-dim cost considerations (S1-S5) proceed unaffected by this finding.

5. **Track 5 (persistence) is essentially independent.** Schlatt-2026-style content-addressing operates on the e-class graph as a data structure; doesn't route through M-adhesivity.

6. **The "adhesive ↔ CALM" claim (C2 below) needs C1's downgrade folded in.** The CALM-adhesive unification developed in `2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md` §5 was argued in the strict-adhesive setting. Its transfer to T_Σ-adhesive needs to be checked theorem-by-theorem when we work C2.

#### 4-column memo entry

| Claim | Where defended in our corpus | External evidence | Strength + proof obligation |
|---|---|---|---|
| **C1.a**: There is a categorical framework in which EGGs (e-term graphs in the egg/egglog sense) are an instance of M-adhesive categories. | e-graphs note §3.1; hypergraph note §3.3; PReduce 0.1 §10.4. Paraphrase as "adhesive" omitting M qualifier. | arXiv:2503.13678 (CALCO 2025) Cor 5.15: EGG is T_Σ-adhesive (M-adhesive for M=T_Σ). | **Theorem.** Cite as **T_Σ-adhesive**, not adhesive. Already corrected in this note's vocabulary; corpus locations to be amended in next pass. |
| **C1.b**: The standard DPO transfer (parallelism, causality, critical-pair analysis) carries from adhesive theory to PReduce's e-class rewriting. | e-graphs note §3.1: "confluence and parallelism analysis tools...apply directly." | arXiv:2503.13678 §7 (open research direction). Baldan-Castelnovo-Corradini-Gadducci, *Left-linear rewriting in adhesive categories*, CONCUR 2024 (LIPIcs 311, 11:1–11:24) is the active SOTA. | **Structural conjecture (under investigation).** Engineering may proceed empirically (egg/egglog ship); formal claim must cite [3] explicitly. |
| **C1.c**: SRE Track 2D's adhesive guarantees inherit to PReduce's e-class rewriting via shared substrate. | PReduce Master, Cross-series connections; e-graphs note §3.1 closing paragraph. | SRE Track 2D was proved in **strict** adhesive (parse-tree presheaf category). EGG is **T_Σ-adhesive**. Different M; results don't auto-transfer. | **Asserted, not yet defended.** Theorem-by-theorem audit required. Most useful form is: "the registry / property-tag pattern transfers; per-theorem adhesive consequences must be re-derived in the M-adhesive setting where applicable." Engineering work for Track 0.1 follow-up. |
| **C1.d**: EGG rewrites need NACs (negative application conditions) to prevent endless reapplication; NAC theory in M-adhesive is established. | Not currently in our corpus. | arXiv:2503.13678 §6 explicitly. NAC theory: Ehrig-Golas-Habel-Lambers-Orejas, *M-adhesive transformation systems with nested application conditions* (Parts 1+2), MSCS 2014 + Fund. Inform. 2012 [refs 15, 16 of the Biondo paper]. | **Theorem (load-bearing for engineering).** New engineering input: PReduce rule format must support NACs from day one. Track 0.2 rule-property taxonomy + Track 0.3 `.pnet` schema both touched. |

---

### §2.C2 — adhesive ↔ CALM (paraphrased; **sharpened under GBT into a structural identity at the enrichment level**)

*Status entering this section*: corpus claim defended at length in `docs/research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md` §5 + §7, labeled by the author as "a genuine extension of CALM theory from set operations to graph rewriting operations" and explicitly flagged as **a conjecture** — i.e., already approximately at *Speculative bridging* strength in our new label scheme. Independent supporting corpus location: `2026-03-28_UNIVERSAL_CONSTRAINT_SOLVING.md` §6 ties CALM to monotone fixpoint computation as a hierarchical principle ("stratification = CALM boundary").

*Status after working through the GBT frame + external CALM literature*: **the claim sharpens substantially**. What was "a boundary agreement" or "a conjecture" under the Biondo (adhesive-only) lens becomes a **structural identity at the enrichment level** under GBT, because BloomL's monotone-merge axioms and GBT's semilattice-enrichment axioms are *literally the same axiomatic content*.

#### What CALM actually proves (precise statement)

CALM has been a *theorem*, not a conjecture, since 2013:

> **Theorem (Ameloot, Ketsman, Neven, Zinn 2013, JACM).** A query (in the relational-transducer model) has a coordination-free execution strategy if and only if it is expressible in monotone relational logic (Datalog without negation/aggregation).

This proved the Hellerstein 2010 CIDR conjecture in one specific computational model. Subsequent refinements: Zinn (TODS 2016) gives finer-grained weaker-monotonicity variants; Ameloot et al. (Theory of Computing Systems 2015) proves confluence is *decidable* for a fragment of relational-transducer networks. The CACM 2020 article "Keeping CALM" by Hellerstein and Alvaro is the expository update.

Our corpus's CALM defense (e.g., `2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md` §5) refers to CALM as a "theorem," which is correct. The corpus locations are using CALM in its established, theorem-status sense.

#### The BloomL generalization — the connecting axiomatic claim

The paper that does the heavy categorical work for our purposes is Conway, Marczak, Alvaro, Hellerstein, Maier (SoCC 2012), *"Logic and Lattices for Distributed Programming"* — BloomL. Quoting directly:

> *"BloomL programs can be defined over arbitrary types—not just sets—as long as they have commutative, associative, and idempotent merge functions ('least upper bound') for pairs of items. Such a merge function defines a partial order."*

Three axioms: **commutative + associative + idempotent merge**. This is *the definition of a semilattice* (Birkhoff). BloomL's contribution is generalizing CALM from set-union to *any* commutative-associative-idempotent merge — i.e., extending CALM's coordination-free guarantee from one semilattice (`(Set, ∪)`) to all semilattices.

#### The structural identity: GBT enrichment IS BloomL monotone-merge

Now compare to GBT's semilattice-enrichment axioms (Tiurin–Barrett–Ghica–Hu, arXiv:2406.15882 Definition 2.5, Figure 3) on hom-sets `(C(A, B), +)`:

```
f + g = g + f               (commutativity)
f + f = f                   (idempotence)
+ is n-ary associative       (associativity)
f; (g + h) = f;g + f;h      (distributivity over composition, left)
(f + g); h = f;h + g;h      (distributivity over composition, right)
f ⊗ (g + h) = f⊗g + f⊗h     (distributivity over tensor, left)
(f + g) ⊗ h = f⊗h + g⊗h     (distributivity over tensor, right)
```

The first three are **exactly** BloomL's three axioms on merge functions. The other four extend the axiomatic content to *composition* and *tensor* — i.e., the categorical operations of sequential and parallel combination distribute over the join `+`.

The structural identity is therefore:

> **C2 reformulated under GBT.** An e-graph rewriting program is BloomL-style monotone (and hence CALM-coordination-free) iff its morphisms live in the semilattice-enriched fragment of an SMC. The four distributivity axioms (composition + tensor over `+`) lift BloomL's monotone-merge requirement to *morphism level*, encoding the additional requirement that sequential and parallel composition preserve the coordination-free property.

This is no longer a metaphor or a boundary-agreement table. The semilattice enrichment IS the categorical witness of BloomL/CALM monotone-merge, with the categorical extension of the merge condition to the composition and tensor operations of the underlying SMC.

#### What changes for the corpus claim

The corpus's `2026-04-03` note framed its result as: "a monotone propagator that implements a DPO rewrite rule without critical pairs is both CALM-compliant AND adhesive-certified." Under GBT, this becomes:

> **C2 under GBT, sharpened version of the corpus claim.** A rewrite rule lies in a semilattice-enriched SMC iff:
> - its hom-set carries a well-defined join `+` (commutative, associative, idempotent), AND
> - composition and tensor distribute over `+`.
> 
> Such rules are exactly the CALM-coordination-free, BloomL-mergeable, parallelism-safe ones — with the e-graph's *equivalence-class structure* and the propagator network's *coordination-free fragment* being the same algebraic object (the `+` operation in the enrichment).

The "no critical pairs" condition specializes naturally: critical pairs are exactly the locations where two parallel rule applications cannot be combined via `+` because the EDPOI rewriting framework's boundary complement (Definition 5.2 of GBT) is not satisfied. The framework cleanly identifies these (and they are the locations where retraction-stratum coordination is required).

#### The Cartesian vs general-monoidal distinction

GBT's full equivalence (Theorem 6.5) is `SMT⁺(Σ, E) ≃ MEHypI(Σ)/S, E` for symmetric monoidal theories. The Cartesian case (where the SMT has natural copy/delete maps, modeling ordinary algebraic terms with unrestricted sharing) is the standard term-rewriting setting and is what most of PReduce's work needs. The general monoidal case (no Cartesian structure) opens to non-Cartesian computational models (linear types, separation logic, ZX-calculus). PReduce can start in the Cartesian fragment and extend to monoidal as the substrate's linear-type features mature.

**Important for the substrate-first/theory-after posture**: Prologos already supports QTT (Quantitative Type Theory) with linear, affine, and unrestricted multiplicities. This means our cell substrate is *not* purely Cartesian — the multiplicity discipline restricts copy/delete. The GBT monoidal-not-just-Cartesian extension is therefore not optional decoration; it's the right level for our setting once QTT integrates with the e-class subsystem. (Track 9 / NTT-typed rules.)

#### Retraction (S(−1)) as enrichment failure, parameterized by ATMS worldviews

What does retraction look like under GBT? The S(−1) stratum is where the enrichment fails. Specifically:

- **Idempotence breaks** when retraction means "undo" is needed: `f + (¬f)` doesn't reduce to anything meaningful in a semilattice (semilattices have no inverses; there is no `¬f` whose join with `f` cancels). This matches CALM's identification of non-monotone operations as requiring coordination.
- **Associativity / commutativity** can hold even under retraction (e.g., set-difference is commutative), so the *kind* of enrichment failure matters — it's specifically the join `+` that breaks, not the whole monoidal structure.
- **The cleanest categorical characterization**: S0 = the semilattice-enriched fragment; S(−1) = the fragment with commutative-monoid enrichment but **without idempotence** (CRDT-style with reconciliation rather than pure-monotone). LVish (Kuper-Newton 2014) and the broader CRDT literature live here.
- **The missing coordination protocol — ATMS**: the categorical characterization above is *structurally* clean but operationally incomplete. Retracting `f` requires invalidating exactly the derivations that depended on `f` and leaving everything else intact — that's a *book-keeping* problem the enrichment axioms do not solve on their own. The **ATMS (Assumption-based Truth Maintenance System)** is exactly the coordination protocol that makes S(−1) tractable. Each derivation carries an assumption-label set; retraction of an assumption invalidates exactly the label-dependent derivations; non-dependent derivations survive untouched.
- **Combined characterization (S(−1) under GBT + ATMS)**: S(−1) consists of morphisms living in a *worldview-parameterized* commutative-monoid-without-idempotence enrichment. The "merge" in S(−1) is conditional on the worldview the ATMS is currently maintaining. Different worldviews give different enrichments — they are different specializations of the underlying non-idempotent monoid. **Parallel speculative evaluation = parallel exploration of cost-optimized worldviews**: each ATMS branch maintains its own enrichment specialization; tropical-quantale residuation chooses the cost-optimal worldview at extraction time. This is the categorical witness for the PReduce master's Track 6 (cost-bounded speculative reduction consuming BSP-LE 2B hypercube infrastructure).

This gives the PReduce master's "two strata is enough" decision a concrete categorical justification: the two strata correspond to the two natural enrichment regimes (semilattice vs ATMS-worldview-parameterized commutative-monoid-without-idempotence). And it integrates the speculative-evaluation infrastructure (BSP-LE 2B's ATMS hypercube) with the categorical frame as the *coordination protocol* for S(−1), not as a separate engineering concern. 

#### What's actually established vs speculative-bridging

| Sub-claim | Strength | Notes |
|---|---|---|
| **C2.a**: GBT semilattice-enrichment axioms include BloomL's three merge axioms (commutativity, associativity, idempotence). | **Theorem** (trivial; direct comparison of axioms). | Lifts immediately. |
| **C2.b**: Semilattice-enriched morphisms are CALM-monotone (in the BloomL-extended sense). | **Theorem** (modulo lifting BloomL's lattice-level claim to morphism level via the distributivity axioms). | The lift is the genuinely-new content. |
| **C2.c**: CALM-monotone programs admit a semilattice-enriched categorical model. | **Speculative bridging**. | Plausible (any CALM-monotone program is built from monotone merge ops, which form semilattices); not formally proved in the literature for the rewriting setting. |
| **C2.d**: The S0 / S(−1) PReduce stratum decomposition corresponds to enriched-vs-not-enriched. | **Structural conjecture**. | Clean structural fit; PReduce engineering can adopt this characterization. SRE Track 2D's 13 rules / 0 critical pairs is the **Engineered & tested** anchor on the parsing/elaboration side. |
| **C2.e**: Critical-pair absence in EDPOI = join `+` well-defined on parallel morphisms. | **Structural conjecture**. | Falsifiable; first place to look in proof obligation. |
| **C2.f**: Under GBT, the SRE Track 2D adhesive guarantees DO transfer (per-theorem) to PReduce's e-class subsystem, because both live in the same enrichment paradigm — unlike the Biondo route where they lived in different M-adhesive variants. | **Resolves C1.c**. | Track 2D presheaf category is semilattice-enriched (trivially; the join in hom-sets is union of rule-application results); PReduce's e-class subsystem is too. **Unifies what was a per-theorem audit obligation under C1 into a single shared enrichment audit.** |

The most important shift: **C2.f resolves a C1 open item.** Under Biondo M-adhesive, we had to audit SRE Track 2D's guarantees theorem-by-theorem for transfer to PReduce. Under GBT, both Track 2D and PReduce live in the same semilattice-enriched setting; the transfer is unified.

#### 4-column memo entry

| Claim | Where defended in our corpus | External evidence | Strength + proof obligation |
|---|---|---|---|
| **C2.a**: GBT's semilattice-enrichment axioms include BloomL's commutative-associative-idempotent merge axioms verbatim. | New observation in this note (§2.C2 above). | Definitionally direct: GBT §2.5 (axioms first three) vs BloomL paper text quoted above. | **Theorem.** |
| **C2.b**: A morphism in a GBT semilattice-enriched SMC is CALM-monotone (BloomL-extended). | This note §2.C2 (new). | BloomL paper for the lattice claim; GBT §2.5 distributivity axioms lift the claim to composition + tensor. | **Theorem** in the BloomL-extended sense; formal proof in the relational-transducer model adapts Ameloot et al. 2013. |
| **C2.c**: Converse — CALM-monotone programs in the rewriting setting admit a semilattice-enriched model. | This note (new). | Plausible by construction (assemble the model from monotone merge ops); not yet a published theorem for the rewriting setting. | **Speculative bridging.** Honest open direction; engineering does not block on this. |
| **C2.d**: PReduce's S0 / S(−1) two-stratum decomposition = semilattice-enrichment / commutative-monoid-without-idempotence enrichment. | `2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md` §7 "Stratification" row; PReduce master Axis 1; this note §2.C2 above. | LVish (Kuper-Newton 2014); CRDT reconciliation literature; BSP-LE 2B retraction stratum design. | **Structural conjecture** with **Engineered & tested** anchor on the parsing side (Track 2D 13 rules / 0 critical pairs). |
| **C2.e**: EDPOI critical-pair-absence ↔ join `+` well-defined on parallel morphisms. | This note (new). | Bonchi et al. III (MSCS 2022) on DPOI confluence decidability; GBT §5 EDPOI rewriting + boundary complement (Def 5.2). | **Structural conjecture.** First proof obligation; cleanest empirical falsification target. |
| **C2.f**: SRE Track 2D's strict-adhesive guarantees transfer to PReduce's e-class subsystem through *shared semilattice enrichment*, not through shared adhesivity. | This note (new); resolves C1.c. | GBT enrichment unifies both subsystems' categorical home. | **Structural conjecture (load-bearing for engineering); resolves C1.c.** |

---

### §2.C3 — E-graphs as quotient modules; backward chaining as residuation (paraphrased; **GBT Thm 6.5 IS the quotient structure made categorical**)

*Status entering this section*: corpus defense in `docs/research/2026-03-28_MODULE_THEORY_LATTICES.md` §5 (residuation as narrowing) + §6 (e-graphs as quotient modules), distilled into `docs/research/2026-05-02_E_GRAPHS_RESEARCH.md` §3.2. The framing has been load-bearing for the engineering for ~2 months — PPN 4C Phase 1B's tropical-fuel residuation operator is the engineering realization. Strength entering: **Engineered & tested** for the tropical (1-dim) case; **Structural conjecture** for multi-dim and the category-level claim.

*Status after working through GBT + Russo Q-module theory*: **the categorical claim sharpens substantially**. What was a useful semantic interpretation ("the e-graph is *like* a quotient module") becomes a direct identification with GBT's full equivalence theorem.

#### The corpus claim, precisely

From `2026-03-28_MODULE_THEORY_LATTICES.md` §6:

> An e-graph is the quotient module M/N where N is the equivalence relation generated by rewrite rules. Quotient map π : M → M/N sends each term to its e-class. Section s : M/N → M picks a representative. **Extraction = finding the section that minimizes cost (tropical semiring).**

From §5 of the same note:

> Residuated lattice axiom: a · b ≤ c ⇔ a ≤ c / b ⇔ b ≤ a \ c. **Backward chaining IS residuation. `solve(goal)` computes the residual of the forward derivation at `goal`.**

From `2026-05-02_E_GRAPHS_RESEARCH.md` §3.2:

> Cost-guided extraction = residuation in the tropical quantale. **`extraction = cost \ e-class`** where `\` is the tropical residual.

The corpus framing is structurally right but operationally underspecified — *which* category of modules, *which* quotient functor, *which* algebra of residuation.

#### What GBT supplies that the corpus didn't have

**GBT Theorem 6.5** (Tiurin–Barrett–Ghica–Hu, arXiv:2406.15882):

> SMT⁺(Σ, E) ≃ MEHypI(Σ)/S, E.

This is *literally* a quotient construction. The right-hand side is the e-hypergraph category modulo the EDPOI rewrites generated by S (the structural semilattice equations) and E (the user-given equational theory). The left-hand side is the symmetric-monoidal-theory-with-equations modulo congruence. They are *equivalent as categories*, not just isomorphic in some weaker sense.

Compared to the corpus's `M/N` framing:

- **M** (free module of terms over a signature) ↔ `MEHypI(Σ)` (e-hypergraph category with interfaces over signature Σ).
- **N** (equivalence relation generated by rewrite rules) ↔ `S, E` (the union of structural semilattice equations + user equations).
- **Quotient M/N** ↔ `MEHypI(Σ)/S, E`.
- **The quotient is well-defined** ↔ GBT §6 establishes soundness; §7 establishes full completeness. The category equivalence is *the* well-definedness theorem.

This is the C1→C2 pattern again: GBT collapses what was a separate algebraic frame (quotient modules) into a structural identity with the categorical equivalence. The Russo 2010 Q-module structure is **inhabited by** the GBT enrichment, not a parallel structure we have to relate.

#### Russo Q-modules supply the residuation API

**Russo 2010** (arXiv:1002.0968) *Quantale Modules and their Operators*: a (left) Q-module M is a sup-lattice with a scalar action `* : Q × M → M` satisfying the usual associativity-distributivity axioms. The category Q-Mod has Q-modules as objects and sup- and action-preserving maps as morphisms.

Residuation in Q-Mod (Russo 2010 §3): for any Q-module morphism `f : M → N`, there exists a unique right adjoint `f* : N → M` (the residual) characterized by `f(a) ≤ b ⇔ a ≤ f*(b)`. This is the **residual map** that solves "given target output b, what is the greatest input that produces something ≤ b?"

For our setting, the relevant Q-modules are:

- **For the tropical (1-dim) case**: hom-sets `C(A, B)` of the semilattice-enriched SMC are sup-lattices under `+`; the cost quantale `T_min = ([0,∞], min, +)` acts via cost-scaling. Each hom-set is a `T_min`-module. The residual operator is exactly the cost-extraction algorithm.
- **For the multi-dim case** (Candidate D from §2.C1.alt): the cost quantale is a product/tensor `Q₁ ⊗ Q₂ ⊗ ...` of component quantales. Hom-sets are `Q₁⊗Q₂⊗...`-modules. The residual operates componentwise (or via Pareto-dominance, depending on the tensor structure). Russo's structure theory gives the right shape.

#### The corpus's "key formula" gets a precise type

`2026-05-02_E_GRAPHS_RESEARCH.md` §3.2 stated:

> Key formula: extraction = `cost \ e-class` where `\` is the tropical residual.

Under GBT + Russo, this has a precise type:

```
\_Q : Q × EquivClass → Morphism
```

where `Q` is the cost quantale, `EquivClass` is an e-class (= an element of the hom-set `C(A, B)`/E, i.e., an equivalence class of morphisms in the quotient category), and the output `Morphism` is the cost-optimal section of the quotient map at that e-class. **The Q-module structure of the hom-set makes the residual well-defined; the GBT quotient makes the e-class well-defined; the composition is the extraction operator.**

For multi-dim cost (Candidate D):

```
\_(Q₁⊗Q₂⊗…) : (Q₁ × Q₂ × ...) × EquivClass → Morphism  (or PowerSet(Morphism) for Pareto)
```

This is the **residual operator API** that Track 0.1 §7.7 asked for. The signature is now type-explicit; the implementation is the residuation algorithm (greedy for confluent rules; ILP / heuristic / Pareto-frontier for non-confluent).

#### Backward chaining gets the same residual

The corpus's claim **"backward chaining IS residuation"** (§5 of Module Theory note) is direct: in the residuated-lattice axiom `a · b ≤ c ⇔ b ≤ a \ c`, the right-hand side is exactly *backward chaining* — given a desired goal `c` and a known forward derivation `a`, the residual `a \ c` is the *demand* on the remaining input that must be satisfied. The Logic Engine's `solve(goal)` operation IS this residual computation.

Under GBT + Russo, this is no longer a metaphor or a structural conjecture: backward chaining and cost-guided extraction are **the same operation read against different Q-modules**:

- **Cost-guided extraction**: residual against the cost-Q-module. The "divisor" is the cost-criterion; the "goal" is the e-class.
- **Backward chaining**: residual against the propagator-Q-module. The "divisor" is the partial forward derivation; the "goal" is the logical query.

Both are instances of `\_Q : Q × M → M` for different (Q, M) pairs. **One residuation API serves both engineering subsystems.** That's the unification.

#### Saturation IS the lattice fixpoint of forward propagation

The corpus has this right (Module Theory §6, last subsection): e-graph saturation is a monotone fixpoint on the lattice of e-class sets; CALM-compliant; parallelizable under BSP. Under GBT + Russo, this is direct:

- The hom-sets `C(A, B)` are sup-lattices under the semilattice enrichment.
- The quotient action of S (structural rewrites) + E (theory equations) is a monotone Q-module endomorphism on the sup-lattice.
- Saturation = the least fixpoint of this endomorphism (Knaster–Tarski on the sup-lattice).
- Under CALM (per §2.C2), the fixpoint is order-invariant and coordination-free — the BSP scheduler can fire rewrites in any order.

#### What's actually established vs speculative-bridging

| Sub-claim | Strength | Notes |
|---|---|---|
| **C3.a**: E-graphs are quotient modules in a quantale-module framework. | **Theorem under GBT + Russo** | GBT Thm 6.5 supplies the categorical equivalence; Russo 2010 supplies the Q-module structure. The corpus framing was directionally right; the categorical foundation is now precise. |
| **C3.b**: Cost-guided extraction = residuation in the cost-Q-module. | **Theorem** for 1-dim (tropical); **Structural conjecture** for multi-dim. | Tropical case: Cuninghame-Green-Zimmermann residuation algorithms; egg's CostFunction + Extractor is a concrete implementation. Multi-dim: shape established (Russo); per-Q algorithm depends on the specific composite. |
| **C3.c**: Backward chaining IS the same residual operation, read against a different Q-module. | **Theorem (algebraic structure)** | Residuated lattice axiom is direct; corpus framing was correct. |
| **C3.d**: The residual operator API (Track 0.1 §7.7) has signature `\_Q : Q × M → M` for an appropriate (Q, M) pair, with M = `C(A, B)` for hom-sets in the semilattice-enriched SMC. | **Theorem** for tropical; **Engineered & tested** via PPN 4C Phase 1B. | Resolves Track 0.1 §7.7's open question with a concrete type signature. |
| **C3.e**: One residual API unifies cost-extraction and backward-chaining at the engineering level. | **Structural conjecture (load-bearing for engineering)**. | If true, the Logic Engine's backward-chaining and PReduce's extraction share an implementation. Falsification target: a concrete operation that's semantically backward-chaining but doesn't fit the Q-module residual signature. |
| **C3.f**: Saturation IS the least fixpoint of the Q-module action's monotone endomorphism on the sup-lattice. | **Theorem (Knaster–Tarski applied)**. | Corpus had this; GBT supplies the precise lattice structure. |

#### Implications for PReduce engineering

1. **Track 0.1 §7.7 resolved**: residual operator's API has explicit type signature `\_Q : Q × M → M` (or `\_Q : C(A,B) × Q → C(A,B)` if we write the residual against the cost criterion).
2. **Track 4 implementation**: residuation algorithm; the tropical case (PPN 4C Phase 1B already shipping) is the warm-up; multi-dim (Candidate D / S1) requires Russo-shape generalization.
3. **C3.e — the engineering unification**: the Logic Engine's backward-chaining propagators and PReduce's cost-extraction can share a residuation operator implementation. **Concrete merge target for the propagator infrastructure**.
4. **Track 1 cell declaration extends**: when the cost quantale is in scope, the e-class cell's NTT declaration becomes `:lattice :structural :enrichment :semilattice :Q-module`. The Q-module action is the cost-scaling propagator.
5. **The corpus claim's load-bearing parts survive intact**: "saturation is a CALM-compliant monotone fixpoint" and "extraction = `cost \ e-class`" both hold and are now categorically witnessed.
6. **S1 (cost-space commitment) and S2 (residual operator API) have a math foundation**. The remaining S1 question is which `Q` shape we commit to (product / tensor / lex). The S2 question is fully answered by C3.d at the API level; concrete algorithms remain per-Q-shape.

#### 4-column memo entry

| Claim | Where defended in our corpus | External evidence | Strength + proof obligation |
|---|---|---|---|
| **C3.a**: E-graph = quotient in the GBT category equivalent to a Q-module quotient. | `2026-03-28_MODULE_THEORY_LATTICES.md` §6; this note §2.C3. | GBT Thm 6.5 (TBGH LICS 2025); Russo 2010 §2 Q-module category. | **Theorem** (categorical equivalence). |
| **C3.b**: Cost-guided extraction = residuation in the cost-Q-module. | `2026-05-02_E_GRAPHS_RESEARCH.md` §3.2 (1-dim); this note §2.C3. | egg `Extractor` + `CostFunction` (Rust docs, concrete impl); Cuninghame-Green-Zimmermann tropical residuation algorithms; Russo 2010 §3 residual maps. | **Theorem** for tropical; **Structural conjecture** for multi-dim. |
| **C3.c**: Backward chaining IS residuation in a propagator-Q-module. | `2026-03-28_MODULE_THEORY_LATTICES.md` §5. | Residuated lattice axiom (nLab; Galatos-Jónsson-Kowalski-Ono 2007). | **Theorem (algebraic structure)**. |
| **C3.d**: Residual operator API has type `\_Q : Q × M → M` for `M = C(A, B)` hom-sets in the enriched SMC. | This note §2.C3. | Russo 2010 §3 (Q-module residuals). | **Theorem** (tropical); **Engineered & tested** (PPN 4C Phase 1B). Resolves Track 0.1 §7.7. |
| **C3.e**: One residual API unifies cost-extraction and backward-chaining implementations. | This note §2.C3 (new). | Russo §3; the algebraic shape is identical. | **Structural conjecture (load-bearing)**. Falsification: find an operation that's semantically backward-chaining but doesn't fit the signature. |
| **C3.f**: Saturation is the least fixpoint of the Q-module action. | `2026-03-28_MODULE_THEORY_LATTICES.md` §6 ("saturation-as-fixpoint connection"). | Knaster–Tarski; Russo 2010 Q-module sup-lattice structure. | **Theorem**. |

---

### §2.C4 — GoI execution formula = propagator network fixpoint (paraphrased; **the geometric series IS the Kleene star in a traced semilattice-enriched SMC**)

*Status entering this section*: corpus defense in `docs/research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md` §10.3, also recorded in `docs/research/standups/standup-2026-03-22.md`. The corpus claims the identification "structurally identical, not metaphor" but the defense is *informal* — a one-paragraph observation that the GoI geometric series `I + σπ + (σπ)² + ...` looks like a fixpoint iteration. Strength entering: **Asserted**.

*Status after working through GBT + Kleene algebra + categorical GoI literature*: **the identification holds and tightens substantially**. The geometric series IS the Kleene star in semiring/quantale terms; Kleene star is well-defined in our (complete idempotent semiring = quantale) setting per the existing corpus tropical-quantale work; the abstract categorical home is *traced semilattice-enriched SMCs* and Haghverdi-Scott (ICALP 2004) formalize this category-theoretic identification.

#### The corpus claim, precisely

From `2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md` §10.3:

> The GoI execution formula `EX(σ) = (1 - σπ)^{-1} · σ · (1-π)` is a fixpoint computation — and fixpoint computation is what propagator networks do (run-to-quiescence). … propagation to quiescence IS the GoI iteration `I + σπ + (σπ)² + ...`. The categorical home for this is the traced monoidal category, which our session type domain already inhabits.

The load-bearing facts the corpus asserts:

1. GoI `EX(σ)` is a fixpoint computation.
2. `I + σπ + (σπ)² + ...` is run-to-quiescence on the propagator network.
3. The categorical home is a traced monoidal category.
4. Session-types domain (which our substrate handles) inhabits a traced SMC.

All four are individually defensible; the corpus didn't *connect* them through a precise categorical theorem.

#### The geometric series IS the Kleene star

In the original Girard formulation, `(1 - σπ)^{-1}` is interpreted via formal-power-series expansion: `Σ_{n≥0} (σπ)ⁿ = I + σπ + (σπ)² + ...`. The "inverse of (1 - σπ)" never literally exists; subtraction isn't part of the semiring/quantale structure. What exists is the **sup of the partial sums**, which is the Kleene star.

In `2026-04-21_TROPICAL_QUANTALE_RESEARCH.md` §2.4, our corpus already grounded Kleene star:

> A Kleene algebra `(K, ⊕, ⊗, *, 0, 1)` is an idempotent semiring equipped with a unary star operation satisfying `a* = 1 ⊕ a ⊕ a² ⊕ a³ ⊕ ...`.

And §2.6:

> A complete idempotent semiring = a quantale (Fujii 2019). The tropical semiring is complete; therefore it is a quantale.

Putting these together: **the GoI execution formula in semiring/quantale terms is**

$$EX(\sigma) = (\sigma\pi)^{*} \cdot \sigma \cdot (1-\pi)$$

where `(σπ)*` is the Kleene star of `σπ` in the underlying quantale. The `(1 - π)` factor is also interpreted compositionally (it's the "output filter" that extracts only the externally-visible outcomes).

This isn't novel — it's the standard semiring-categorical reformulation of GoI in the categorical-GoI literature (Haghverdi-Scott 2004, *A categorical model for the geometry of interaction*; Haghverdi 2000 thesis on unique decomposition categories). But the corpus didn't connect to this literature explicitly; the standup remark was made by analogy.

#### The categorical home: traced semilattice-enriched SMCs

Following **Joyal-Street-Verity 1996** (traced monoidal categories) and **Haghverdi-Scott 2004** (categorical model of GoI):

- A **traced symmetric monoidal category** is an SMC equipped with a *trace operator* `Tr^A_{X,Y} : C(X ⊗ A, Y ⊗ A) → C(X, Y)` satisfying the trace axioms (naturality, dinaturality, yanking, superposing).
- The trace operator captures **feedback/recursion/iteration** categorically. In categories where hom-sets are sup-lattices and composition is sup-preserving, `Tr` *computes the Kleene star fixpoint*.
- **Unique decomposition categories** (Haghverdi 2000) are SMCs whose hom-sets are matrices over a semiring; in this setting, the trace is literally `(I - σ)^{-1}` interpreted as the matrix Kleene star.

**Our setting (GBT semilattice-enriched SMC, with Russo Q-module enrichment for cost) is exactly this shape**:

- Hom-sets `C(A, B)` are sup-lattices under the semilattice enrichment (§2.C1.alt Candidate B).
- Composition `;` and tensor `⊗` distribute over arbitrary joins (GBT Definition 2.5 distributivity axioms).
- Hom-sets are Q-modules under the Russo enrichment (§2.C3); residuals exist; Kleene star is well-defined.
- Therefore the SMC supports a **trace operator** computing the Kleene-star fixpoint. (Conjecturally; needs explicit construction. Haghverdi-Scott give it for the general unique-decomposition-category case; the semilattice-enriched specialization should follow standard constructions but is not literally in the literature.)

#### The propagator-runtime correspondence

With the categorical home settled, the corpus's correspondence becomes precise:

| GoI side | Propagator-network side |
|---|---|
| Linear-logic proof / lambda term | Compiled propagator network (the `.pnet`) |
| Translation to a graph of transducers | Cell allocation + propagator installation |
| Token passing (Mackie GoI machine; Danos-Regnier) | Cell-update propagation (LVar-style) |
| Geometric series `I + σπ + (σπ)² + ...` | BSP rounds firing all applicable propagators |
| Convergence (no more token motion) | Quiescence (no more cell changes) |
| Output value at the "output port" | Final cell value at a designated output cell |
| Trace operator `Tr` | The propagator scheduler's run-to-quiescence |
| Kleene star `(σπ)*` | The least fixpoint of the propagator dependency graph |

The correspondence isn't a metaphor: at the categorical level, both sides are computing the *same* trace/Kleene-star fixpoint in a (traced) semilattice-enriched SMC. The propagator scheduler IS the GoI machine, structurally; we just write the cells in our notation rather than as transducer-token states.

#### DGoIM as the close engineering precedent

**Muroya-Ghica Dynamic GoI Machine** (CSL 2017 / LMCS, arXiv:1703.10027) interleaves token-passing with graph rewriting to amortize repeated work. Architecturally, this is **strikingly close to our propagator + e-graph integration**:

- DGoIM tokens ↔ our active propagators (the BSP frontier).
- DGoIM graph rewriting ↔ our PReduce rule firing (per Track 2/3 of PReduce Master).
- DGoIM's space-time trade-off knob ↔ our cost-bounded speculative reduction (Track 6 + S6 stub).
- DGoIM's call-by-need strategy ↔ our retraction-stratum-aware reduction.

And Ghica is one of the GBT authors (he's the *G* in TBGH). The same author lineage that gave us the categorical e-graph foundation (GBT, LICS 2025) also gave us the operationally-close GoI runtime (DGoIM, CSL 2017). **This is not coincidence**: the line of work systematically connects semilattice-enriched / e-hypergraph rewriting on one side with token-passing GoI runtime on the other. Our substrate sits in this exact line.

#### HVM2 and Lévy-optimality

**HVM2** (HigherOrderCO) is the production instantiation of this picture: a massively parallel interaction-combinator runtime with near-optimal sharing. Interaction combinators are the **IN-fragment of GBT-enriched SMCs** — rules with binary principal ports + strong confluence (Lafont 1990, 1997). Per Lévy 1980 / 1988, the IN-fragment supports **Lévy-optimal sharing**: each shared subterm reduces at most once.

**Conjectural transfer** (speculative bridging): the IN-fragment subcategory of our GBT-enriched SMC inherits HVM2-style massive parallelism and Lévy-optimal sharing automatically. PReduce Track 2 (β-reduction tagged as IN-fragment per PReduce Master Axis 1) is the engineering site that would realize this. **If true, HVM2's empirical performance (74,000 MIPS on RTX 4090) is an upper-bound proof-of-concept for the propagator network's IN-fragment performance.**

#### What's actually established vs speculative-bridging

| Sub-claim | Strength |
|---|---|
| **C4.a**: GoI execution formula factor `(1-σπ)^{-1}` = Kleene star `(σπ)*` in semiring/quantale terms. | **Theorem** (Haghverdi-Scott 2004, standard categorical-GoI). |
| **C4.b**: Kleene star is well-defined in our semilattice-enriched / Q-module setting. | **Theorem** (Russo 2010 Q-module sup-lattices + `2026-04-21_TROPICAL_QUANTALE_RESEARCH.md` §2.4/§2.6 + Knaster–Tarski). |
| **C4.c**: Propagator-network run-to-quiescence IS the Kleene-star/trace computation in the enriched SMC. | **Theorem** (algebraic correspondence at the abstract level); **Engineered & tested** (our concrete sequential + BSP schedulers compute the least fixpoint). |
| **C4.d**: The semilattice-enriched SMC supports a full trace operator inhabiting the Joyal-Street-Verity / Haghverdi-Scott traced-SMC framework. | **Structural conjecture** — the construction should follow standard categorical-GoI, but isn't literally in the published literature for the semilattice-enriched specialization. First proof obligation. |
| **C4.e**: The IN-fragment of our enriched SMC inherits HVM2-style massive parallelism + Lévy-optimal sharing automatically. | **Speculative bridging** — the algebraic shape matches (interaction combinators are IN-fragment); empirical transfer requires implementation. PReduce Track 2 is the engineering site. |
| **C4.f**: Phase collapse (compile-time = runtime, per A0 paper) is operationally witnessed by the *same* Kleene-star/trace operator firing on different cell contents (typing cells vs reduction cells). | **Structural conjecture (load-bearing for Paper A0)** — if true, this is the categorical witness for the A0 phase-collapse headline. |

#### Implications for PReduce engineering

1. **The runtime story is automatic, not separate engineering.** Run-to-quiescence on the propagator network IS the GoI execution. There is no separate "GoI interpreter" to build; the propagator scheduler IS the GoI machine at the categorical level. This explains why the Zig PoC scheduler ran the reduction work *as* propagation without category-shift.
2. **Kleene-star algorithms transfer wholesale.** Per `2026-04-21_TROPICAL_QUANTALE_RESEARCH.md` §2.5 + §9.6, Floyd-Warshall, Bellman-Ford, Dijkstra are all instances of Kleene-star in different semirings. For PReduce: fuel-cost propagation, all-pairs reduction-cost computation, critical-path analysis are all Kleene-star instances. The algorithmic library is decades old and well-formalized (NICTA 2009 Isabelle/HOL formalization).
3. **Trace = feedback semantics**: session-types and recursive types both inhabit the trace operator. PReduce's recursive-reduction rules get their semantic foundation here, not as a separate construction.
4. **HVM2 is the production benchmark.** If C4.e holds, HVM2's performance on the IN-fragment is the empirical upper bound our Track 2 β-reduction implementation should approach. Concrete benchmark target.
5. **The Phase Collapse claim (Paper A0) gets a categorical witness.** Same Kleene-star/trace operator fires on different cell contents — typing cells at "compile time," reduction cells at "run time." The algorithm is invariant; only the cells differ. **This is C4.f**, and if it holds it's the load-bearing categorical fact behind the A0 H2 headline (phase collapse).
6. **DGoIM is a close engineering precedent.** Worth retrieving and reading for the design of the token-passing/rule-firing interleaving in Track 6 (speculative reduction).

#### 4-column memo entry

| Claim | Where defended in our corpus | External evidence | Strength + proof obligation |
|---|---|---|---|
| **C4.a**: GoI `(1-σπ)^{-1} = (σπ)*` in semiring/quantale. | This note §2.C4 (new). | Haghverdi-Scott ICALP 2004; Haghverdi 2000 thesis on unique decomposition categories; standard categorical GoI. | **Theorem**. |
| **C4.b**: Kleene star well-defined in our enriched setting. | `2026-04-21_TROPICAL_QUANTALE_RESEARCH.md` §2.4 + §2.6 + §9.5–9.6. | Russo 2010; Fujii 2019 (complete idempotent semiring = quantale). | **Theorem**. |
| **C4.c**: Propagator run-to-quiescence = Kleene-star/trace computation. | Cat-foundations §10.3; `standup-2026-03-22`; this note §2.C4. | Haghverdi-Scott 2004; algorithm formalizations (NICTA 2009). | **Theorem** (algebraic); **Engineered & tested** (our schedulers). |
| **C4.d**: Semilattice-enriched SMC has a trace operator inhabiting the full traced-SMC framework. | This note (new). | Joyal-Street-Verity 1996; Haghverdi-Scott 2004 for the general construction. | **Structural conjecture**. First proof obligation. |
| **C4.e**: IN-fragment of GBT-enriched SMC inherits HVM2-style parallelism + Lévy-optimal sharing. | This note (new). | Lafont 1990, 1997 interaction combinators; Lévy 1980/1988 optimality; HVM2 production system. | **Speculative bridging**. PReduce Track 2 implementation is the engineering test. |
| **C4.f**: Phase collapse (A0 H2) = same Kleene-star/trace operator on different cell contents. | This note (new); preview of A0 paper claim. | C4.c + the existing cross-phase use of the propagator scheduler in `racket/prologos/propagator.rkt`. | **Structural conjecture (load-bearing for Paper A0)**. |

---

### §2.C1.alt — Alternative formalizations of e-graphs (detour 2026-05-09)

*Trigger*: §2.C1's M-adhesive finding identified the Biondo route as sitting on an active-research frontier. The user's pull toward e-graphs as the leading reduction approach plus the §2.0 substrate-first/theory-after posture together motivate checking the alternative formalizations before locking in.

Four candidate formal frames evaluated against substrate fit (lattice-valued cells, propagator-network monotone merge, tropical-quantale cost annotation, polynomial-functor lens, bindings, multi-dim cost). Strength labels follow §1.2.

#### Candidate A — Biondo–Castelnovo–Gadducci M-adhesive (arXiv:2503.13678)

Already worked through in §2.C1. Set-bound; T_Σ-adhesive (left-linear M-adhesive); standard DPO transfer theorems open per the paper's own §7. Strength of supporting theory: **Theorem (with scope caveats)** for the existence claim; **Structural conjecture** for the engineering transfer.

#### Candidate B — Tiurin–Barrett–Ghica–Hu semilattice-enriched (arXiv:2406.15882, **LICS 2025**)

Updated title in v2 (May 2025) and conference version: *"Equivalence Hypergraphs: DPO Rewriting for Monoidal E-Graphs."* Retrieved v1 end-to-end via `alpha_get_paper`. Headline theorem is structurally different from Biondo:

> **Theorem 6.5 (Full completeness, GBT v1).** SMT⁺(Σ, E) ≃ MEHypI(Σ)/S, E.

Unpacked:

- **Categorical primitive is *enrichment***, not adhesivity. E-graphs are morphisms in **Cartesian categories enriched over the category of semilattices** (or, more generally, in semilattice-enriched symmetric monoidal categories — PROP⁺ in the paper's notation).
- The semilattice structure is *intrinsic*: hom-sets `C(A, B)` are semilattices `(C(A, B), +)`; `f + g : A → B` *is* the e-class "f or g".
- **Combinatorial representation**: e-hypergraphs with hierarchical "e-box" edges (`l(e) = ⊥`) modeling equivalence classes; rewriting via **EDPOI** (Extended Double-Pushout with Interfaces).
- The theorem is a **full equivalence of categories** — the syntax/semantics pair is closed, not active research. Standard DPO transfer for the Cartesian case (which is what term-rewriting needs) is in hand.
- **Bindings** are handled by the direct extension Moss–Tiurin 2025 (arXiv:2505.00807) which lifts the framework to **closed** symmetric monoidal categories — the same enrichment-based machinery extends to λ-binders without rebuilding.
- Strength: **Theorem** for the equivalence; **Engineered & tested** for the rewriting framework (Bonchi et al.'s string-diagram rewrite theory I/II/III, 2022, ship the supporting infrastructure).

#### Candidate C — Polynomial-functor / Poly-internal (speculative bridging)

Following the Programme's Paper-Poly direction (`outputs/poly-as-propagator-internal-research.md`). Identification: a PROP **is** a polynomial functor over the natural-numbers category. PROP⁺ (semilattice-enriched PROP, used by GBT) **is** a polynomial functor enriched over semilattices. Spivak's `Poly` book has multiple monoidal structures (×, ⊗, ◦, +) that interact with enrichment.

If we develop the identification: *Prologos's cells live in a (semilattice- or quantale-) enriched PROP; rewrite rules are arrows; e-class merge is the join in the enriched hom-set; cost annotation is a further enrichment.* This **unifies** the parsing / typing / reduction / cost story at the polynomial-functor level. Strongly aligned with Programme objective.

Strength: **Speculative bridging** (drawn from `Poly` programme + GBT's PROP-enriched setting; no published paper has done the identification at this granularity, but the structural fit is sharp). This is *exactly* the kind of frame the substrate-first/theory-after pattern calls for.

#### Candidate D — Quantale-enriched (speculative bridging — our cost story's natural home)

GBT uses **semilattice** enrichment (join only, no monoidal product on hom-sets). Our cost story needs a **quantale**: join `∨` *and* a monoidal product `⊗` (often `+`) with `⊗-over-∨` distributivity. Quantale-enriched categories (Lawvere 1973 generalised metric spaces; Russo 2010 quantale modules; Bacci–Mardare–Panangaden–Plotkin 2023; Kupke et al. STACS 2024 *"Expressive Quantale-Valued Logics for Coalgebras"*; Forster et al. ICALP 2024 *"Graded Semantics and Graded Logics for Eilenberg–Moore Coalgebras"*) generalize the semilattice case.

A **quantale-enriched PROP** would (conjecturally):
- Carry both equivalence-class structure (the join) AND cost annotation (the monoidal product) in one algebraic object.
- Make multi-dim cost a direct structural extension: product/tensor of quantales → product/tensor of enrichments.
- Resolve the residual operator question (§7.7 of Track 0.1) by inheriting it from quantale residuation — the operator's API is `\ : Q → Q → Q`.

Strength: **Speculative bridging** (math machinery exists in adjacent literature; identification with the e-graph story is not yet written down). Closest external precedents are Kupke 2024 and Forster 2024 — both already in our corpus's bibliography but not yet used for e-graphs. **High-leverage next-research direction if we commit to the GBT track.**

#### Comparison table

| Axis | A: Biondo M-adhesive | B: GBT semilattice-enriched | C: Poly polynomial-functor | D: Quantale-enriched |
|---|---|---|---|---|
| Categorical primitive | Adhesivity of EGG | Enrichment of SMC over SLatt | Polynomial functor + enrichment | Enrichment over Q (quantale) |
| Universe | Set-bound | Set or any SMC | Cat(ℕ) and its enrichments | Q-enriched SMC |
| Status | T_Σ-adhesive theorem; DPO transfer **open** | **Full equivalence** (Thm 6.5, closed) | No published identification (speculative) | Math machinery published; e-graph identification speculative |
| Substrate fit | Modest — our cells aren't in Set | **Direct** — our cells *are* semilattices | **Direct** — Programme already commits to Poly lens | **Direct** — our cost annotation *is* quantale-valued |
| Bindings | Separate extension | **Same framework** (Moss–Tiurin 2025, [arXiv:2505.00807](https://arxiv.org/abs/2505.00807)) | TBD | TBD |
| Multi-dim cost (S1) | Separate machinery | Possible via further enrichment | Natural via Poly's multiple monoidal structures | **Direct** — product/tensor of quantales |
| Parallelism / causality | Open per Biondo §7 | DPO transfer in hand for Cartesian | Inherited from Poly | Inherited from Q-enriched theory |
| Citation imprimatur | "EGGs are adhesive" (slogan) | Equivalence of categories (mathematically deeper) | Programme-aligned | Adjacent literature |
| Strength of our use | Structural conjecture | **Theorem** | Speculative bridging | Speculative bridging |

#### Recommendation for the spine

**Adopt Candidate B (GBT semilattice-enriched) as the primary frame, with Candidates C and D as the natural extensions for the Programme's Poly direction and the multi-dim cost story (S1) respectively.**

Reasoning:

1. **Substrate fit is direct, not approximate.** Our lattice-valued cells *are* semilattices. The enrichment GBT prescribes already exists in our substrate; we don't add machinery, we *recognize* what we have.
2. **The theory is closed for the case we need.** Cartesian SMC + semilattice enrichment + EDPOI rewriting has a full equivalence of categories. The Biondo frontier-risk (parallelism/causality open per their §7) does not transfer.
3. **Bindings come for free.** Moss–Tiurin 2025 (already in our bibliography) extends GBT — not Biondo — to closed SMCs for λ-binders. Going GBT means bindings are the same framework.
4. **The Poly programme alignment is structural.** PROP⁺ (semilattice-enriched PROP) lives natively in `Poly`'s neighborhood. Our Poly internal-research note can point at this paper without a category-shift.
5. **The multi-dim cost story (S1) has a natural home.** Quantale-enrichment extends semilattice-enrichment. Tropical-quantale + multi-dim composition = product/tensor of Q's, with residuation inherited (S2; §7.7 of Track 0.1).

**The drift from corpus is that we've been citing Moss–Tiurin 2025 (the binding extension) without citing the foundational paper it extends (arXiv:2406.15882).** Our `2026-05-02_ARCHITECTURE_NOVELTY_SURVEY.md` cites Moss–Tiurin verbatim but not GBT. The drift log records this as a corpus gap.

**Engineering implications updated** (supersedes §2.C1's engineering implications where they overlap):

- Track 1 (e-class cell substrate): the cell's NTT declaration is **`:lattice :structural :enrichment :semilattice`** (more specific than Track 0.1's current `:lattice :structural :order :refinement`). The semilattice IS the merge function; e-class membership IS the join.
- Track 2 (β-reduction): IN-fragment story unchanged. β sits in the *non-enriched* PROP fragment (no `+` in its hom-sets unless multiple reduction strategies are e-class'd together); enrichment kicks in when we want to share with alternative reductions.
- Track 3 (ι-reduction critical-pair analysis): now sits in the **closed** EDPOI rewriting framework, not the open M-adhesive frontier. Critical-pair analysis is well-defined for hypergraph DPOI rewriting (Bonchi et al. III, 2022, **decidable** for terminating DPOI systems).
- Track 4 (cost-guided extraction via residuation): the cost annotation is a *further enrichment* over the semilattice one. Residuation operator is the **quantale residual** in the cost-enriched setting (Candidate D, S2).
- Track 5 (persistence): unchanged by this choice; persistence is data-structure-level.
- Track 0.2 (rule-property taxonomy): rule properties become *enrichment-preserving-or-not* tags. Cleaner taxonomy than the per-axis approach.
- Track 0.3 (`.pnet` schema): serialize the enriched morphisms; the semilattice structure becomes part of the cell schema.
- **NAC requirement still stands** — EGG rewriting needs NACs in *any* of these formalizations.

---

## §3 Pass 2: specialization (S1–S5)

Formal opening waits for C3, C4 to close. Stubs below capture engineering-side considerations the owner has registered as the spine work proceeds, so they don't get lost when we re-enter §3.

- **§3.S1** Cost-space commitment (Q5 of PReduce Master).
- **§3.S2** Residual operator API (§7.7 of PReduce Track 0.1).
- **§3.S3** GoI invariance vs cost-aware GoI.
- **§3.S4** Reduction-kind partition under the spine (extends Track 0.2).
- **§3.S5** Persistence regime per cost component (Schlatt-2026 application). **See §3.S5 stub below for owner-registered refinement: persistent registry of *optimal rewrites*, not just persistent e-graph.**
- **§3.S6** *(new)* Speculative reduction + ATMS worldview management (Track 6 of PReduce Master). **See §3.S6 stub below.**

### §3.S5 stub — persistent registry of optimal rewrites

*Owner consideration registered 2026-05-09; full subsection to be written when §3 opens.*

The corpus's current framing of Track 5 persistence is Schlatt 2026 *"E-Graphs as a Persistent Compiler Abstraction"* realized on our substrate with regime-tagged cache discipline. Owner refinement: **the load-bearing object is not the persistent e-graph but the persistent registry of optimal rewrites discovered through cost-extraction.** Schema sketch:

- **Cache key**: `(source-e-class-content-hash, cost-criterion-id, worldview-bitmask?)`
  - `source-e-class-content-hash`: CHAMP-derived structural hash of the input e-class (or the residuated module, in Candidate D quantale terms).
  - `cost-criterion-id`: which cost quantale / multi-dim cost specification was applied (S1 commitment determines the shape).
  - `worldview-bitmask`: optional ATMS-worldview tag for entries valid only under specific assumption sets.
- **Cache value**: the chosen extraction (the cost-optimal residuation result).
- **Persistence regime tag** (from Track 0.1 / PReduce Master Axis 2): ground / contextual / retraction-eligible / opaque, determining cache key composition.

**Why this is richer than Schlatt 2026**: Schlatt persists the *residuation domain* (the e-graph). This proposal persists the *residuation results* (cost-optimal choices) keyed by the residuation problem. It's content-addressed by the question, not just the solution-space. Adjacent prior art: IPVM content-addressed computation; egg's persistence work; LLM-guided extraction work (Koehler-Trinder-Steuwer 2022, referenced in Tiurin–Barrett–Ghica–Hu §1.5).

**Engineering hook**: this is potentially the *only* component of Track 5 that needs custom design beyond Schlatt 2026's pattern. The e-graph persistence can adopt Schlatt; the optimal-rewrite registry is our specific contribution.

**Publishable design point candidate**: if the registry's key/value/regime structure works cleanly across the four persistence regimes, this is an externalizable contribution under the broader paper-A0 (LHC system) or paper-Poly story.

### §3.S6 stub — speculative reduction via ATMS worldview management

*Owner consideration registered 2026-05-09; full subsection to be written when §3 opens.*

PReduce Master Track 6 already specifies: cost-bounded ATMS branching for non-confluent rule cases, consuming BSP-LE 2B hypercube infrastructure, realizing the 4-level optimization strategy (ATMS + Left Kan + Right Kan + tropical). Under GBT + the ATMS connection from §2.C2 (retraction subsection above), the categorical picture is now:

- Each ATMS branch corresponds to a **specialization of the S(−1) non-idempotent monoid enrichment** — one specific worldview maintaining a particular set of assumptions.
- **Parallel exploration of branches = parallel maintenance of competing enrichment specializations**. BSP-LE 2B's hypercube worldview is the data structure; the GBT enrichment is the categorical content of each cell of the hypercube.
- **Cost-bounded pruning of branches = tropical-quantale residuation across worldviews**. The cost annotation (S1/Candidate D) gives a quantale; the residual `Q \ Q` selects the lowest-cost-residual worldview; high-cost worldviews are pruned.
- **Reconvergence** (when multiple worldviews collapse to the same e-class) is the *limit* of the worldview-parameterized enrichment family back to the unparameterized semilattice S0.

**Open questions to resolve when §3.S6 is written**:

- (S6-Q1) Does the ATMS label discipline lift cleanly to enrichment-parameterization, or do we need a quasi-enrichment notion? *Speculative bridging*; first proof obligation.
- (S6-Q2) What's the relation to **colored e-graphs** (Singher-Itzhaky 2023, conditional rewriting; referenced in Tiurin–Barrett–Ghica–Hu §1.5)? Colored e-graphs handle context-conditional equivalences; ATMS-worldview-parameterized enrichment generalizes the same idea categorically. Strong candidate for direct comparison.
- (S6-Q3) How does the speculative-evaluation cost budget compose with the multi-dim cost space (S1)? Per-branch cost vs aggregate-branch cost vs Pareto-frontier-over-branches.
- (S6-Q4) Where does this leave Track 9 (NTT-typed rules)? Type-level information could constrain the ATMS branch space, but the design is open.

---

## §10 Drift log

Append-only. Entries when an earlier claim's strength changes mid-stream.

### 2026-05-09 (sixth entry) — C4 grounded: spine closes; phase-collapse gets a categorical witness candidate

**Headline**: §2.C4 (GoI execution formula = propagator network fixpoint) reframed under GBT + the corpus's existing tropical-quantale Kleene-algebra work becomes **a structural identity at the trace/Kleene-star level in a traced semilattice-enriched SMC**. The corpus's "structural identity not metaphor" assertion is upgraded from **Asserted** to **Theorem** for the algebraic correspondence (C4.a, C4.b, C4.c) and **Structural conjecture** for the full traced-SMC extension (C4.d).

**Three pieces converge**:

1. **The geometric series IS the Kleene star** (standard categorical-GoI; Haghverdi-Scott 2004): `(1 - σπ)^{-1}` is interpreted in semirings/quantales as `(σπ)*`, the Kleene star.
2. **Kleene star is well-defined in our setting** (existing corpus, `2026-04-21_TROPICAL_QUANTALE_RESEARCH.md` §2.4 + §2.6 + §9.5–9.6): complete idempotent semirings = quantales; Kleene star = sup of the partial sums.
3. **The traced SMC framework hosts both sides** (Joyal-Street-Verity 1996; Haghverdi-Scott 2004): trace operator computes the Kleene-star fixpoint in unique decomposition categories. Our GBT semilattice-enriched SMC is structurally one of these (modulo explicit trace construction).

**Phase-collapse witness candidate (C4.f)**: same Kleene-star/trace operator on different cell contents — typing cells at "compile time," reduction cells at "run time." The algorithm is invariant; only the cells differ. **This is load-bearing for Paper A0's H2 headline.** Structural conjecture pending implementation discipline.

**Engineering implications (concrete)**:

- **The runtime story is automatic**: there is no separate "GoI interpreter" to build; the propagator scheduler IS the GoI machine at the categorical level.
- **Algorithmic library transfers wholesale**: Floyd-Warshall, Bellman-Ford, Dijkstra are all Kleene-star instances in different semirings (`2026-04-21_TROPICAL_QUANTALE_RESEARCH.md` §9.6 already pins this; NICTA 2009 has Isabelle/HOL formalization). PReduce inherits.
- **HVM2 is the production benchmark for the IN-fragment** (C4.e speculative bridging). Track 2 (β-reduction tagged IN-fragment) is the engineering test site.
- **DGoIM (Muroya-Ghica 2017) is a close engineering precedent** — same author lineage as GBT (Ghica is the *G* in TBGH). Worth retrieving for Track 6 (speculative reduction) design input.

**External references added**:

- Haghverdi, E., Scott, P. *A categorical model for the geometry of interaction.* ICALP 2004; expanded version in TCS. The standard categorical-GoI reference; supplies C4.a.
- Haghverdi, E. *A Categorical Approach to Linear Logic, Geometry of Proofs and Full Completeness.* PhD thesis, University of Ottawa, 2000. Unique decomposition categories; semiring-matrix interpretation.
- Joyal, A., Street, R., Verity, D. *Traced monoidal categories.* Math. Proc. Cambridge Phil. Soc. 119, 1996, 447–468. Canonical traced-SMC reference.
- Muroya, K., Ghica, D. R. *The Dynamic Geometry of Interaction Machine: A Call-by-Need Graph Rewriter.* CSL 2017 / LMCS ([arXiv:1703.10027](https://arxiv.org/abs/1703.10027)). Close engineering precedent; same author lineage as GBT.
- HVM2 (HigherOrderCO) — production interaction-combinator runtime ([github.com/HigherOrderCO/HVM2](https://github.com/HigherOrderCO/HVM2)). Performance reference for C4.e.
- Beckert-Lange NICTA 2009 *Dijkstra, Floyd, Warshall Meet Kleene* (already in `2026-04-21_TROPICAL_QUANTALE_RESEARCH.md` §9.6) — promoted as direct algorithmic library for PReduce.

**Spine closes**: C1→C2→C3→C4 all worked through under GBT. Pattern repeated four times: GBT collapses what was a separate algebraic frame in the corpus into a structural identity at the categorical level. Notes section now has 220+ lines of detailed proof obligations + memo entries across the four claims.

### 2026-05-09 (fifth entry) — C3 grounded: GBT Thm 6.5 + Russo Q-modules supply the categorical foundation for the residuation API

**Headline**: §2.C3 (e-graphs as quotient modules; backward chaining as residuation) reframed under GBT becomes a direct categorical identification, not a useful-semantic-frame claim. GBT Thm 6.5 (SMT⁺(Σ, E) ≃ MEHypI(Σ)/S, E) **IS** the quotient module construction; Russo 2010 Q-module theory supplies the residuation API. The corpus's load-bearing claims (extraction = cost \ e-class; backward chaining = residuation; saturation = monotone fixpoint) all survive intact with sharper categorical foundations.

**Concrete resolutions**:

- **Track 0.1 §7.7 (residual operator API) resolved**: explicit type signature `\_Q : Q × M → M` for `M = C(A, B)` hom-sets in the semilattice-enriched SMC. PPN 4C Phase 1B's tropical-fuel operator is the 1-dim instance.
- **C3.e (load-bearing engineering claim)**: cost-extraction and backward-chaining are the *same residual operation* read against different Q-modules. Implementation can be shared between the Logic Engine and PReduce — a concrete merge target for the propagator infrastructure.
- **S1 and S2 specializations now have a math foundation**: S1 remains a choice of Q shape (product / tensor / lex); S2's API is C3.d.
- **Track 1 cell declaration extends**: e-class cell's NTT declaration becomes `:lattice :structural :enrichment :semilattice :Q-module` when the cost quantale is in scope. The Q-module action is the cost-scaling propagator.

**External corroboration**:

- **Russo 2010** (arXiv:1002.0968) *Quantale Modules and their Operators*: canonical Q-module theory; defines the category Q-Mod and the residual maps.
- **Russo 2009** (arXiv:0909.4493) *Quantale Modules with Applications*: earlier broader study, including image-processing and logic applications.
- **egg's CostFunction + Extractor** (Rust docs, [docs.rs/egg](https://docs.rs/egg/latest/egg/)): production-grade concrete implementation of `cost \ e-class` in the tropical quantale; validates the corpus framing of "greedy extraction = tropical residuation".
- **Cuninghame-Green-Zimmermann tropical residuation algorithms** (cited in Univ. Angers, *Weak dual residuations applied to tropical linear equations*, 2020): established algorithmic literature for tropical residuation.
- **Residuated lattice** (nLab): canonical algebraic definition `(a·b ≤ c) ⇔ (b ≤ a\c) ⇔ (a ≤ c/b)`.

**Pattern repeated across C1→C2→C3**: at each spine claim, GBT collapses what was a separate algebraic frame (adhesivity in C1; CALM in C2; quotient modules in C3) into a structural identity with the categorical equivalence theorem. This is the substrate-first/theory-after pattern paying off — we built engineering that needed multiple algebraic frames to describe, and now one frame describes all of them at the appropriate categorical level.

**Open at the structural-conjecture level**:

- C3.b multi-dim case (Russo gives shape; per-Q algorithm depends on specific composite).
- C3.e load-bearing claim: needs implementation discipline to confirm the shared-residual-API is operationally clean.
- The Cartesian/monoidal distinction (§2.C2's QTT note) interacts with the Q-module structure when multiplicities aren't unrestricted; this is Track 9 territory.

**Bibliography additions** (running):

- Russo, C. *Quantale Modules with Applications to Logic and Image Processing.* [arXiv:0909.4493](https://arxiv.org/abs/0909.4493), 2009.
- Russo, C. *Quantale Modules and their Operators, with Applications.* [arXiv:1002.0968](https://arxiv.org/abs/1002.0968), 2010. **Load-bearing for C3 residuation API.**
- Galatos, N., Jónsson, P., Kowalski, T., Ono, H. *Residuated Lattices: An Algebraic Glimpse at Substructural Logics.* Elsevier, 2007. Canonical residuated-lattice reference. Cited but not yet retrieved.
- Willsey, M., et al. *egg: Fast and Extensible Equality Saturation.* POPL 2021 ([arXiv:2004.03082](https://arxiv.org/abs/2004.03082)); plus the Rust crate docs as concrete implementation reference for `Extractor` and `CostFunction`.

### 2026-05-09 (fourth entry) — ATMS as S(−1) coordination protocol + persistent-registry refinement registered

Owner registered two engineering-side considerations against the spine work:

1. **ATMS connects to C2's S(−1) characterization as the missing coordination protocol.** The C2 (third entry) characterization of S(−1) as "commutative-monoid enrichment without idempotence" is structurally clean but operationally incomplete — retracting `f` requires invalidating only the `f`-dependent derivations. The ATMS supplies exactly this protocol via assumption-label sets. Updated §2.C2 retraction subsection to add the **combined characterization**: S(−1) consists of morphisms in a *worldview-parameterized* non-idempotent monoid enrichment, where each ATMS branch is one enrichment specialization. **This is a substantive completion of C2, not an aside.**

2. **Persistent registry of *optimal rewrites* (not just persistent e-graph) is the load-bearing Track 5 object.** Schlatt 2026 persists the residuation *domain* (e-graph); the owner's refinement persists the residuation *results* (cost-optimal choices) keyed by `(source-e-class-hash, cost-criterion, optional-worldview-bitmask)`. Stub registered as §3.S5 in advance of full §3 opening. **Publishable design point candidate** for the A0 or Poly external papers.

Also opened **§3.S6 stub** (speculative reduction + ATMS worldview management) since the topic became cross-cutting: BSP-LE 2B's hypercube + ATMS + cost-bounded pruning + GBT enrichment-parameterization form an integrated picture that PReduce Track 6 will consume.

**Cross-references for the engineering side**:

- BSP-LE 2B PIR (`docs/tracking/2026-04-16_BSP_LE_TRACK2B_PIR.md`) is the hypercube + ATMS substrate Track 6 inherits.
- Singher-Itzhaky 2023, *colored e-graphs* (referenced in TBGH §1.5) is the closest published precedent for conditional / worldview-conditional rewriting on e-graphs. Direct comparison target.
- The PReduce Master open question Q5 (cost lattice composition) lands in S1; Q6 (retraction-bit consultation) lands in S5; the combined retraction picture is now categorically explicit via §2.C2 + §3.S6.

### 2026-05-09 (third entry) — C2 grounded under GBT; structural identity established

**Headline**: C2 (adhesive ↔ CALM) reframed under GBT becomes a structural identity at the enrichment level. The semilattice-enrichment axioms on hom-sets (GBT Definition 2.5, Figure 3) are *literally* BloomL's monotone-merge axioms (commutative + associative + idempotent), with additional distributivity over composition and tensor that lifts the lattice-level monotone-merge to morphism level.

**Concrete shift in claim strength**:

- C2.a (axiom inclusion) and C2.b (semilattice-enriched ⇒ CALM-monotone) move from *conjecture* (per `2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md`) to **Theorem** (direct axiom comparison).
- C2.c (converse) remains **Speculative bridging**.
- C2.d (S0 / S(−1) = enriched / non-idempotent-monoid) is **Structural conjecture** with engineered-and-tested anchor on the parsing side.
- C2.e (critical-pair = join-well-definedness) is **Structural conjecture**; cleanest falsification target.
- **C2.f (Track 2D guarantees transfer via shared enrichment) resolves C1.c.** The per-theorem audit obligation we registered under C1 collapses into a single shared-enrichment audit. **Engineering load reduced.**

**External corroboration found**:

- **Ameloot-Ketsman-Neven-Zinn 2013, JACM**: CALM has been an *iff theorem* in the relational-transducer model since 2013. Our corpus referred to CALM as a theorem; the reference was accurate.
- **BloomL (Conway-Marczak-Alvaro-Hellerstein-Maier, SoCC 2012)**: extends CALM to arbitrary commutative-associative-idempotent merge functions. These axioms = semilattice axioms = GBT's first three enrichment axioms. *This is the previously-missing bridge.*
- **Semilattice tensor products** (Bonifaci's blog at rntz.net; nLab on "semilattice object"): the math machinery for Candidate D's multi-dim cost story (S1) is well-tooled and unifies LVars, BloomL, CvRDTs, Sussman propagators.
- **"Enriched categorical semantics for distributed calculi"** (MaRDI portal entry) and **imperative-categories paper** (arXiv:2507.18238) both develop poset-/lattice-enriched categories for distributed/imperative semantics. Adjacent prior art; flagged for follow-up retrieval.

**Engineering implications**:

- **S0 stratum becomes precise**: S0 = morphisms in the semilattice-enriched fragment. The cell-level NTT declaration `:lattice :structural :enrichment :semilattice` (per §2.C1.alt) is the runtime witness.
- **S(−1) stratum becomes precise**: S(−1) = morphisms in a *weaker* enrichment (commutative monoid without idempotence) where retraction is allowed. LVish (Kuper-Newton 2014) and CRDT reconciliation literature inhabits this.
- **The "two strata is enough" decision is now categorically witnessed**, not just empirically argued. Two strata correspond to the two natural enrichment regimes.
- **QTT integration matters**: GBT's Cartesian-vs-monoidal distinction maps onto Prologos's QTT multiplicity discipline. Linear/affine multiplicities push us into the non-Cartesian monoidal case, which GBT supports natively (Cor 5.15 in Biondo terms; Thm 6.5 in GBT). PReduce can start Cartesian (default term-rewriting) and extend to monoidal (QTT-aware rewriting) as Track 9 / NTT matures.

**New external references for bibliography**:

- Ameloot, T. J., Ketsman, B., Neven, F., Zinn, D. *Weaker Forms of Monotonicity for Declarative Networking: A More Fine-Grained Answer to the CALM-Conjecture.* TODS 40(4), 2016. Refines the 2013 CALM iff theorem.
- Ameloot, T. J., et al. *Deciding Confluence for a Simple Class of Relational Transducer Networks.* Theory of Computing Systems 57(4), 2015. Decidability result for CALM-fragment confluence.
- Hellerstein, J. M., Alvaro, P. *Keeping CALM: When Distributed Consistency is Easy.* CACM 63(9), 2020. Already in our corpus's direct-lineage list.
- Conway, N., Marczak, W. R., Alvaro, P., Hellerstein, J. M., Maier, D. *Logic and Lattices for Distributed Programming.* SoCC 2012. Already in our corpus's direct-lineage list; **promoted** as the load-bearing axiomatic bridge for C2.
- *Enriched Categorical Semantics for Distributed Calculi* (MaRDI portal entry, exact authorship pending retrieval). Flagged for follow-up.

### 2026-05-09 (later) — C1.alt detour: GBT semilattice-enriched as primary frame

**Trigger**: user-approved detour to evaluate alternative formalizations of e-graphs against our substrate.

**Headline**: Tiurin–Barrett–Ghica (–Hu in v2) semilattice-enriched framing (arXiv:2406.15882, LICS 2025) is a strictly better fit for our substrate than the Biondo M-adhesive framing. Recommendation adopted in §2.C1.alt: **GBT as primary frame; Candidates C (Poly) and D (quantale-enriched) as the natural extensions for Paper Poly and the multi-dim cost specialization respectively.**

**Corpus gap discovered** (✅ amended 2026-05-09 in housekeeping pass): `2026-05-02_ARCHITECTURE_NOVELTY_SURVEY.md` cited Moss–Tiurin 2025 (arXiv:2505.00807, *E-Graphs With Bindings*) but **not the foundational paper it builds on** (GBT, arXiv:2406.15882). Moss–Tiurin's abstract literally says *"Building on recent work interpreting e-graphs categorically as morphisms in semilattice-enriched symmetric monoidal categories."* The foundational TBGH entry has been added to the novelty survey, with Moss-Tiurin re-described as the direct extension of TBGH (not Biondo).

**Engineering re-direction**: Tracks 1, 3, 4, 0.2 all shift from M-adhesive vocabulary to enrichment vocabulary. Most concrete change: the e-class cell's NTT declaration moves from `:lattice :structural :order :refinement` to `:lattice :structural :enrichment :semilattice`. The merge function *is* the semilattice join; e-class membership *is* the join's existence.

**Speculative bridges flagged for follow-up** (per §2.0 posture):

- Candidate C: Poly polynomial-functor identification with GBT's PROP⁺ setting. Feeds the Paper-Poly internal-research note directly.
- Candidate D: Quantale-enrichment as the multi-dim cost story's home. Kupke et al. (STACS 2024) and Forster et al. (ICALP 2024) are the closest external precedents — both in our corpus's bibliography but not yet engaged for e-graphs. This is where S1 (cost-space commitment) will likely land.

**New references to bibliography**:

- Tiurin, A., Barrett, C., Ghica, D. R., Hu, N. *Equivalence Hypergraphs: DPO Rewriting for Monoidal E-Graphs.* LICS 2025, IEEE 209–222. [arXiv:2406.15882](https://arxiv.org/abs/2406.15882) v1 (Jun 2024) read end-to-end; v2 (May 2025) is the conference version.
- Bonchi, F., Gadducci, F., Kissinger, A., Sobociński, P., Zanasi, F. *String diagram rewrite theory* I, II, III (JACM 2022, MSCS 2022, MSCS 2022). The rewriting infrastructure GBT builds on.
- Kupke et al. *Expressive Quantale-Valued Logics for Coalgebras*, STACS 2024. Already in our corpus; flagged for quantale-enrichment bridge (Candidate D).
- Forster et al. *Graded Semantics and Graded Logics for Eilenberg–Moore Coalgebras*, ICALP 2024. Already in our corpus; same flag.

### 2026-05-09 — C1 corpus drift identified

**Source of drift**: corpus paraphrase of Biondo-Castelnovo-Gadducci's CALCO 2025 result as "e-graphs are adhesive" omitted the **M-adhesive** qualifier the paper actually proves.

**Corpus locations affected** (✅ all amended 2026-05-09 in the housekeeping pass, see CHANGELOG):

- ✅ `docs/research/2026-05-02_E_GRAPHS_RESEARCH.md` §3.1 — amended to two-frame picture (Frame A Biondo M-adhesive + Frame B TBGH semilattice-enriched); Frame B flagged as primary for our substrate.
- ✅ `docs/research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md` §3.3 — same correction.
- ✅ `docs/research/2026-05-02_PREDUCE_TRACK01_ARCHITECTURAL_SKETCH.md` §10.4 — reorganized: primary categorical frame (TBGH + Moss-Tiurin + Russo + Bonchi I/II/III); alternative/comparison frame (Biondo + Baldan + Ehrig-Golas); foundational + production/runtime sub-categories added.
- ✅ `docs/tracking/2026-05-02_PREDUCE_MASTER.md` Cross-series-connections — softened the SRE Track 2D adhesive-guarantees claim per C2.f resolution; open Q4 reframed to cite TBGH + Bonchi III decidability; two new `Source documents` entries link the internal note + engineering memo into the series.

**Engineering impact**:

- New input for Track 0.2 / Track 0.3: PReduce rules need NAC (negative-application-condition) support from day one. Was not previously in our requirements list.
- Track 3 (ι-reduction as DPO + critical pairs) is the track whose formal grounding sits at the active-research frontier (left-linear M-adhesive theory, Baldan et al. CONCUR 2024). Two paths (strict-adhesive on presheaves vs M-adhesive on EGG) tabled for design discussion.
- Track 2 (β-reduction as IN-fragment), Track 4 (cost-guided extraction), Track 5 (persistence) are not affected by the drift.

**External references added to running bibliography (§11)**:

- arXiv:2503.13678 — Biondo, Castelnovo, Gadducci, *EGGs are adhesive!*, CALCO 2025 (LIPIcs 342). Read end-to-end including appendix proofs.
- Baldan, Castelnovo, Corradini, Gadducci, *Left-linear rewriting in adhesive categories*, CONCUR 2024, LIPIcs 311, 11:1–11:24. Cited but not yet retrieved; flagged as the active-research-frontier reference for Track 3.
- Ehrig-Golas-Habel-Lambers-Orejas, *M-adhesive transformation systems with nested application conditions* Parts 1+2 (Fund. Inform. 2012, MSCS 2014). Cited but not yet retrieved; flagged for Track 0.2/0.3 NAC-support requirement.

---

## §11 References (running)

### Read end-to-end

- **Biondo, R., Castelnovo, D., Gadducci, F.** *EGGs are adhesive!* CALCO 2025, LIPIcs vol. 342 (Schloss Dagstuhl). [arXiv:2503.13678](https://arxiv.org/abs/2503.13678) v1 17 Mar 2025; v2 27 May 2025. Retrieved 2026-05-09 via `alpha_get_paper`. Used in §2.C1.

### Cited but not yet retrieved (flagged for follow-up retrieval)

- **Baldan, P., Castelnovo, D., Corradini, A., Gadducci, F.** *Left-linear rewriting in adhesive categories.* CONCUR 2024, LIPIcs 311, 11:1–11:24. Active-research-frontier reference for Track 3 ι-reduction critical-pair theory (if we had stayed on Candidate A).
- **Ehrig, H., Golas, U., Habel, A., Lambers, L., Orejas, F.** *M-adhesive transformation systems with nested application conditions. Part 1: Parallelism, concurrency and amalgamation.* Math. Struct. Comp. Sci. 24(4), 2014.
- **Ehrig, H., Golas, U., Habel, A., Lambers, L., Orejas, F.** *M-adhesive transformation systems with nested application conditions. Part 2: Embedding, critical pairs and local confluence.* Fundamenta Informaticae 118(1-2), 2012, 35–63. Pair: NAC theory for M-adhesive that Track 0.2/0.3 needs. *Note*: NAC theory exists for both M-adhesive and semilattice-enriched DPOI; carrying these citations forward for completeness.
- **Tiurin, A., Barrett, C., Ghica, D. R., Hu, N.** *Equivalence Hypergraphs: DPO Rewriting for Monoidal E-Graphs.* LICS 2025 (IEEE 209–222). [arXiv:2406.15882](https://arxiv.org/abs/2406.15882) v1 17 Jun 2024 (read end-to-end via `alpha_get_paper`); v2 20 May 2025 is the conference version (not yet retrieved). **Primary categorical frame for PReduce per §2.C1.alt.**
- **Moss, S., Tiurin, A.** *E-Graphs With Bindings.* [arXiv:2505.00807](https://arxiv.org/abs/2505.00807) 2025. Already in our corpus's `2026-05-02_ARCHITECTURE_NOVELTY_SURVEY.md`; flagged for the binding extension of Candidate B.
- **Bonchi, F., Gadducci, F., Kissinger, A., Sobociński, P., Zanasi, F.** *String diagram rewrite theory I: Rewriting with Frobenius structure.* JACM 69(2), 2022.
- **Bonchi, F., Gadducci, F., Kissinger, A., Sobociński, P., Zanasi, F.** *String diagram rewrite theory II: Rewriting with symmetric monoidal structure.* MSCS 32(4), 2022, 511–541.
- **Bonchi, F., Gadducci, F., Kissinger, A., Sobociński, P., Zanasi, F.** *String diagram rewrite theory III: Confluence with and without Frobenius.* MSCS 2022. **DPOI confluence is decidable for terminating systems** — directly applicable to our Track 3 critical-pair work.
- **Kupke, C. et al.** *Expressive Quantale-Valued Logics for Coalgebras.* STACS 2024. Already in our corpus (`2026-03-13_LAYERED_RECOVERY_CATEGORICAL_ANALYSIS.md`); flagged for Candidate D quantale-enrichment bridge.
- **Forster, J. et al.** *Graded Semantics and Graded Logics for Eilenberg–Moore Coalgebras.* ICALP 2024. Same.
