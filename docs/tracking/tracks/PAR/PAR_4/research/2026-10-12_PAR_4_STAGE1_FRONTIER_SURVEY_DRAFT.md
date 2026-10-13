# PAR 4 · Stage 1 (R3 addendum) — Frontier / primary-literature survey for Arena Executors — DRAFT

**Serves**: PAR 4 — Arena Executors. **Inputs**: `research/2026-10-12_PAR_4_STAGE1_CONTENTION_ANALYSIS.md`
(R3, measurements) and `2026-10-12_PAR_4_STAGE2_GAP_ANALYSIS.md` (Q1–Q7). **Status**: draft,
written 2026-10-12 against `7a0116ec`; no source changes. **Method**: every citation below was
looked up online during writing (search + page/PDF extraction); §4 lists what could not be
confirmed. Labels used throughout: **THEOREM** (statement + assumptions), **MEASUREMENT** (ours,
R3, or a paper's), **PRECEDENT** (what a system does), **CONJECTURE** (ours, testable),
**TASTE** (ours, not testable).

## 0. Summary

The two load-bearing claims of the Track-4 candidate design — (i) S0 can run without a barrier
under DIRECT (chaotic) iteration and reach the same fixpoint, (ii) the barrier belongs exactly at
the non-monotone stratum boundary — are both instances of theorems with stated assumptions, not
folklore. Asynchronous-iteration theory (Chazan–Miranker 1969 → Cousot 1977 → Bertsekas 1983 →
Üresin–Dubois 1990) gives the convergence conditions: a *monotone, inflationary* operator on a
product of lattices (the "box" condition), a start below the fixpoint, *finite chains* (ascending
chain condition) for termination in finitely many steps, and three schedule conditions —
causality of reads (A1), every component updated infinitely often (A2), no value used forever
(A3). DIRECT satisfies A1 structurally (release/acquire append-only records), A2/A3 by the
executor loop's fairness (to be made structural, Q7), and the box condition by cell-wise
ownership; what it does **not** get for free is that every S0 *propagator* is a monotone function
of its inputs — the merge being a join is necessary, not sufficient. That single audit is Q1
restated as a theorem precondition. CALM (Ameloot–Neven–Van den Bussche) proves monotone ⇔
coordination-free and simultaneously proves the negative: *detecting* the fixpoint is not
monotone, so quiescence detection at the stratum boundary is unavoidable coordination — it can be
cheap (a counter scheme, Mattern 1987) but not absent. LVars/LVish give the same architecture
from the PL side: lub-writes + threshold reads ⇒ determinism; `freeze` ⇒ quasi-determinism; our
stratum barrier is a global freeze. CRDT/δ-CRDT theory says owner-bucketed deltas are sound with
no extra condition beyond "every delta is joined at least once". Graph-parallel systems supply
the engineering precedents for Q4 (partitioning) and for async-vs-sync (no mode wins uniformly —
Xie et al. 2015), and Valiant's BSP cost model says exactly when a 1 µs barrier matters: when
per-round local work is of the same order, which R3 measured is the case today. Five things
change or confirm the design: (1) Q1 is a propagator-monotonicity audit, not only a visibility
audit; (2) `+` / `int-merge` cells (18 sites) are not join-semilattices and violate ACC — a
termination gap independent of parallelism; (3) quiescence detection replaces the S0 barrier and
needs its own Pre-0 benchmark; (4) in shared memory the edge-cut/vertex-cut question collapses
to *write locality* — the Pre-0 metric is the fraction of propagator outputs crossing the owner
cut; (5) the arena is a region in Tofte–Talpin's sense and inherits its exact trade (bulk free,
no intra-region reclamation), which is what makes Q2 (fork = copy) the real cost question.

## 1. Theorem table

| # | Name | Statement (one or two lines) | Assumptions | Source (verified) | Relation to DIRECT / BSP |
|---|---|---|---|---|---|
| T1 | Knaster–Tarski (Tarski 1955, Thm 1) | In a complete lattice, a monotone f has a non-empty set of fixpoints forming a complete lattice; lfp f = ⨅{x : f(x) ≤ x}. | complete lattice; f monotone. No continuity, no finiteness. | msp.org/pjm/1955/5-2/pjm-v5-n2-p11-p.pdf | Existence/uniqueness of the S0 target. Says nothing about *reaching* it in finitely many steps. |
| T2 | Kleene iteration / ACC | For continuous f, lfp = ⨆ₙ fⁿ(⊥); if the lattice satisfies the ascending chain condition the chain stabilises after finitely many steps. | continuity (or monotone + ACC). | standard; see Cousot–Cousot 1977 POPL §9 for the ACC/widening discussion | BSP = synchronous Kleene iteration. ACC per cell × finite cells = "termination is structural". |
| T3 | Widening (Cousot–Cousot 1977 POPL §9.1.3) | Replacing joins on cycle arcs by a widening ∇ (an upper-bound operator whose chains stabilise) makes the iteration terminate on infinite-height lattices, at the cost of precision. | ∇ is an upper bound of both args; every ∇-chain is finite. | cs.nyu.edu/~pcousot/COUSOTpapers/POPL77.shtml ; DOI 10.1145/512950.512973 | Where a cell lattice lacks ACC (`+`, `int-merge`), a widening (to ⊤ / contradiction) is the only structural termination. |
| T4 | Chaotic relaxation (Chazan–Miranker 1969, main theorem §5) | For x = Bx + c, chaotic (asynchronous, bounded-delay) relaxation converges for every schedule iff ρ(\|B\|) < 1. | linear; delays bounded; every component updated infinitely often. | sciencedirect.com/science/article/pii/0024379569900287 ; DOI 10.1016/0024-3795(69)90028-7 | Historical origin; its *counter-examples* (sync converges, async diverges) are the warning for non-monotone strata. |
| T5 | Asynchronous iteration in a complete lattice (Cousot 1977, IMAG RR-88) | Asynchronous iterative methods (with or without memory) solve a fixpoint system of monotone equations in a complete lattice; "no additional hypotheses (such as continuity or chain conditions)". | complete lattice; monotone equations; asynchronous schedule (unsynchronised processes). | cs.nyu.edu/~pcousot/COUSOTpapers/IMAG-RR88.shtml (abstract; scanned body not extracted) | The lattice-level licence for DIRECT. Finite-step termination still needs ACC (T2). |
| T6 | Distributed asynchronous fixpoints (Bertsekas 1983, Assumption A+B, Prop. in §3; §4.3 monotone case) | If (A) every node computes and transmits infinitely often, and (B) there are sets Xᵏ with (a) sequences in Xᵏ converge to a fixpoint, (b) closed under single-node computation, (c) closed under communication, (d) a full synchronous step maps Xᵏ→Xᵏ⁺¹, then totally asynchronous execution converges. §4.3: for monotone f with x ≤ f(x) ≤ … ≤ x̄ the boxes Xᵏ = [fᵏ(x), fᵏ(x̄)] satisfy (a)–(d). | product (box) structure of Xᵏ; stale values allowed arbitrarily old but finite. | web.mit.edu/dimitrib/www/Distr_Comp_Fixed.pdf ; DOI 10.1007/BF02591967 | Our cells are the coordinates; ownership = per-coordinate update; delta buckets = "communication". Box condition holds because the state is a product of per-cell lattices. |
| T7 | Asynchronous Convergence Theorem (Bertsekas–Tsitsiklis 1989, ch. 6 §6.2) | Same shape as T6 in book form: Synchronous Convergence Condition + Box Condition + total asynchronism ⇒ every limit point is a fixpoint. | as T6. | athenasc.com/pdccontents.html (contents verified: ch.6 "totally asynchronous", §6.2 "general convergence theorem", §6.4 "monotone mappings"); theorem text not extracted | Same as T6. |
| T8 | ACO theorem (Üresin–Dubois 1990, Thm 1–3) | Under schedule conditions A1 (reads use past values), A2 (each component updated infinitely often), A3 (each generated value is used by only finitely many updates), an asynchronously contracting operator (nested boxes D(K) shrinking to a singleton) converges from any x(0)∈D(0) for every schedule (Thm 1); on finite domains ACO is also *necessary* (Thm 2/3). §4 gives poset sufficient conditions (monotone F, closed D(0), finite chains). | A1–A3; discrete data; boxes are Cartesian products. | dl.acm.org/doi/10.1145/79147.79162 (full text read); formalised and partly corrected in Agda: ITP 2018 DOI 10.1007/978-3-319-94821-8_37, JAR 2020 DOI 10.1007/s10817-019-09536-w | The precise checklist for DIRECT (§2.1). Note JAR 2020: two auxiliary UD results are wrong (counter-example given); the main theorem stands. |
| T9 | CALM (Ameloot–Neven–Van den Bussche, JACM 2013 Thm 13 in the arXiv numbering) | For a query Q: Q is distributedly computed by a coordination-free transducer ⇔ by an oblivious transducer ⇔ Q is monotone. | relational transducers; arbitrary horizontal partition of the input; fair asynchronous delivery; "coordination-free" = some partition reaches quiescence with only heartbeat (no-message) transitions. | arxiv.org/abs/1012.2858 ; DOI 10.1145/2450142.2450151 | Monotone S0 needs no barrier and any partition. Fixpoint *detection* is non-monotone ⇒ the stratum boundary is coordination by theorem. |
| T10 | LVars determinism (Kuper–Newton FHPC 2013, Thm 1) | If σ ↦* σ′ and σ ↦* σ″ and neither can step (except reflexively), then σ′ = σ″. | all writes are lub (`put`); reads are threshold reads whose threshold sets are pairwise incompatible (lub = ⊤). | users.soe.ucsc.edu/~lkuper/papers/lvars-fhpc13.pdf ; DOI 10.1145/2502323.2502326 | DIRECT is LVar-shaped if propagators are monotone; our reads are *not* threshold reads, so the burden moves to propagator monotonicity. |
| T11 | Quasi-determinism (Kuper–Turon–Krishnaswami–Newton POPL 2014, Thm 1) | With `freeze` and handlers: terminal configurations are equal up to location permutation, or one is `error`. | lub writes; freeze-after-write race ⇒ error; handler quiescence detected by the runtime. | users.soe.ucsc.edu/~lkuper/papers/lvish-popl14.pdf ; DOI 10.1145/2535838.2535842 | Stratum barrier = global freeze of S0 cells; a late S0 write after S1 starts is exactly the `error` case. |
| T12 | CvRDT convergence (Shapiro–Preguiça–Baquero–Zawirski 2011, Thm 1) | Assuming eventual delivery and termination, any state-based object with the monotonic-semilattice property (payload is a join-semilattice; merge = LUB; updates inflate) is Strongly Eventually Consistent. | join-semilattice; merge = ⊔; s ≤ s•u; eventual delivery. | lip6.fr/Marc.Shapiro/papers/2011/CRDTs_SSS-2011.pdf ; DOI 10.1007/978-3-642-24550-3_29 | Our cells are CvRDT payloads with one "replica" (the owner) plus delta producers. |
| T13 | δ-CRDT convergence (Almeida–Shoker–Baquero 2018, Prop. 5.1) | If every delta-mutation produced at a replica is joined (directly or in a delta-group) at least once with every other replica, all replicas become equal. Proof: join is ACI. | delta-mutators satisfy m(X) = X ⊔ mᵟ(X); inflationary mutators. | members.loria.fr/CIgnat/files/replication/Delta-CRDT.pdf ; DOI 10.1016/j.jpdc.2017.08.003 | Owner-bucketed dirty lists are delta-groups; "the dirty list IS the diff" is sound with no causal condition. |
| T14 | Kahn determinacy (Kahn 1974) | A network of processes that are continuous functions on channel histories (a CPO) has a unique minimal solution of its fixpoint system; the network is determinate. | processes continuous (hence monotone) on histories; blocking reads; no other communication. | perso.ensta.fr/~chapoutot/various/kahn_networks.pdf (reproduction of IFIP 74) | Same proof shape as ours with lattice cells in place of FIFO histories; our reads are non-consuming, which is *easier*. |
| T15 | GraphLab sequential consistency (Low et al. UAI 2010, Prop. 3.1) | Sequential consistency holds if (1) full consistency, or (2) edge consistency and update functions do not modify adjacent vertex data, or (3) vertex consistency and update functions only access their own vertex. | scoped locking of vertex/edge data. | arxiv.org/abs/1006.4990 | Our DIRECT needs none of these: joins commute, so no serialisability is required — a strictly weaker requirement than GraphLab's. |
| T16 | Random vertex-cut replication (Gonzalez et al. OSDI 2012, Thm 5.2) | A random vertex-cut on p machines has expected replication factor E[1/|V| Σ|A(v)|] = p/|V| Σ (1 − (1 − 1/p)^{D[v]}). | degree distribution D; edges placed uniformly. | usenix.org/system/files/conference/osdi12/osdi12-final-167.pdf | Not our regime (shared memory, no replication); the surviving analogue is "fraction of propagator edges crossing the owner cut" (Q4). |
| T17 | BSP cost (Valiant 1990) | A superstep costs local work w + g·h (h-relation at throughput ratio g) + the synchronisation periodicity L; total = Σ over supersteps. | router realises h-relations in g·h; barrier every L units. | dl.acm.org/doi/10.1145/79173.79181 ; DOI 10.1145/79173.79181 | Our L ≈ 0.8–1 µs (R3 §1); g·h is the delta volume; DIRECT removes L inside S0 and reduces the number of supersteps (15 → 10 measured). |
| T18 | Region soundness (Tofte–Talpin 1997) | Region inference translates a well-typed program into one with explicit `letregion`; evaluation of the target never accesses a deallocated region (soundness of the translation via a consistency relation between source and target stores). | ML-like language, value restriction; stack discipline of regions. | sciencedirect.com/science/article/pii/S0890540196926139 ; DOI 10.1006/inco.1996.2613 | The arena is a region whose lifetime is the network/query; bulk free is the guarantee, no intra-region reclamation is the price. |

## 2. Per-topic survey

### 2.1 Asynchronous / chaotic iteration (T4, T5, T6, T7, T8)

**The precise result.** Üresin–Dubois' model is the one that matches shared memory: a global
vector x, update sets α(k) (which components are rewritten at step k) and read times β(k) (which
past value of each input the step saw). Three schedule conditions: **A1** βᵢ(k) < k (a read sees
only values already written); **A2** every component is in infinitely many α(k) (nothing is
abandoned); **A3** every generated value is read by only finitely many later updates (staleness
is finite, not bounded). A schedule satisfying A2+A3 is "pseudoperiodic": there is a sequence
φ(K) such that in each pseudocycle every component is updated at least once using inputs from the
previous pseudocycle or later. The operator F is an ACO if there are boxes D(0) ⊇ D(1) ⊇ …
(each a Cartesian product) with F(D(K)) ⊆ D(K+1) and D(M) a singleton. Theorem 1: ACO ⇒
convergence for every pseudoperiodic schedule in ≤ M pseudocycles. Theorem 2: on finite domains
ACO is also necessary. §4 gives poset sufficient conditions: F monotone on a partial order,
D(0) closed under F, start point below (or above) its image, and finite chains ⇒ ACO (the exact
proposition text contains equations that the PDF extraction lost; see §4). Bertsekas 1983 is the
same theorem in message-passing form; its monotone instance (§4.3) is the lattice case
exactly: x ≤ f(x), f monotone, chain bounded above ⇒ boxes [fᵏ(x), fᵏ(x̄)]. Cousot's RR-88 is the
strongest statement: complete lattice, monotone equations, no chain condition — but then
"convergence" is transfinite, i.e. a theorem about the limit, not about termination.

**Mapping to DIRECT (the checklist).**

| condition | DIRECT today (R3 §5) | status | test |
|---|---|---|---|
| state is a product of lattices (box) | one record per cell, per-cell merge | holds structurally | — |
| per-cell operator inflationary: x ⊑ x ⊔ y | join is the merge for the 4 flat lattices | holds for `max`, `flat`, `or`, tagged-set | audit the 61 inline lambdas and `+`/`int-merge` (§2.2) |
| **propagator monotone in its inputs** | not checked by the prototype (it used max and set-union propagators) | **open = Q1** | static audit + adversarial parity run under DIRECT |
| A1 causality | entry words → release → count; reader count → acquire → entries | holds (a reader sees a prefix = a valid lattice element because records are append-only) | litmus test under TSAN-like stress at K=16 |
| A2 every dirty cell re-fired | owner-bucketed dirty lists | holds if no executor parks with a non-empty bucket | Q7 park/unpark protocol must drain |
| A3 finite staleness | fires re-read canonical records | holds if no fire caches an input across fires | grep for memoised reads in propagator bodies |
| ACC (finite chains) | finite entries per cell, bounded bitmask | holds for flat tier; see §2.2 for `+` | per-lattice height table |

**What the theorem does not give.** (a) Determinism of *intermediate* states — none; the
theorem is about the limit. Any S0 code that reads a cell and acts on its *absence* of content
(a "not yet" test) is reading an intermediate state as if it were final; that is negation and
belongs at S1. (b) Convergence *speed* — pseudocycle count M is a bound on rounds, not time;
R3's 15 → 10 rounds is consistent with the theory (asynchrony cannot increase M) but is a
measurement, not a theorem. (c) Anything for non-monotone operators: Chazan–Miranker's own
counter-examples show a schedule-dependent divergence where the synchronous scheme converges.
For S(−1) retraction (a *decreasing* operator) and S1 NAF (non-monotone) the theory offers the
synchronous (Gauss–Seidel-at-the-boundary) scheme only — which is what the stratification rule
already prescribes.

**Assessment.** *What it makes possible here*: S0 without a barrier is a theorem instance, not an
experiment, once propagator monotonicity is established; the prototype's "same fixpoint at every
K" is the predicted outcome. *What it would take to land it*: the Q1 audit becomes "every S0
propagator is a monotone function of its input cells under the worldview fixed for the solve",
plus a structural fairness guarantee in the executor loop (A2/A3) that survives parking (Q7).

### 2.2 Tarski, Kleene, ACC, widening (T1, T2, T3)

Tarski (verified text): complete lattice + monotone f ⇒ fixpoints form a complete lattice; lfp is
the meet of pre-fixpoints. The iteration fⁿ(⊥) reaches it in finitely many steps only under a
chain condition. The project's "termination is structural" (`stratification.md` §Termination
guarantees: "finite lattice, monotone joins") is therefore two claims: per-cell ACC, and finitely
many cells per solve (dynamic topology stratified — Q5 is what keeps the second one true).

**Critique.** The merge census (gap analysis §1) contains `+` (13 sites) and `int-merge` (5
sites). `+` is not idempotent, so a cell under `+` is not a join-semilattice at all: re-delivery
of a delta changes the value (δ-CRDT's Prop. 5.1 explicitly relies on idempotence), and
ℤ under ≤ has no ACC. These 18 sites are outside T1/T5/T8 regardless of K; under DIRECT the
non-idempotence is worse because a dirty entry re-joined after a spurious wake would double-count.
Either they are counters with a structural upper bound (then a widening to ⊤ at the bound is
the termination argument, T3), or they must become set-cardinality reads over a set lattice
(idempotent by construction). This is a finding independent of parallelism.

**Assessment.** *Possible*: a per-lattice height table makes "termination is structural" a
checked property. *To land*: audit the 66 merge functions for (ACI, inflationary, ACC); convert
or bound the 18 `+`/`int-merge` sites; record the bound as the cell's widening.

### 2.3 CALM (T9)

Hellerstein 2010 states Conjecture 1 verbatim: "A program has an eventually consistent,
coordination-free execution strategy if and only if it is expressible in (monotonic) Datalog."
Ameloot–Neven–Van den Bussche prove it in the relational-transducer model: nodes hold a
horizontal partition of the input, exchange messages under fair asynchronous delivery, and a
transducer is *coordination-free* if for every input there is some partition on which quiescence
is reached using only heartbeat transitions. Their Theorem 12: every query computed by a
coordination-free transducer is monotone; combined with the oblivious-transducer construction:
coordination-free ⇔ oblivious ⇔ monotone. Hellerstein–Alvaro 2020 restate it as Theorem 1:
"A program has a consistent, coordination-free distributed implementation if and only if it is
expressible in monotonic logic", with consistency defined as confluence of *outputs*.

**What it licenses for S0.** Exactly what T5/T8 license from the lattice side, with the useful
addition that the *partition is arbitrary*: any ownership cut (Q4) yields the same S0 output, so
the cut is purely a cost choice. **What it does not license.** The "only if" direction is the
important one for us: anything that depends on the *absence* of a fact — NAF, guard failure,
"no more retractions", and *detecting that S0 has quiesced* — is non-monotone and therefore
requires coordination. So "the barrier IS the stratum boundary" is the CALM negative result
read constructively: the boundary is where coordination is unavoidable, and the design's job is
to make that coordination cheap (§2.9), not to argue it away. Model caveat: CALM is stated for
monotone *logic* over sets; our cells are general lattices with user merge functions. The
lattice generalisation (monotone functions over join-semilattices) is the folklore extension used
by LVars and Bloom^L; it is not in the JACM proof itself.

**Assessment.** *Possible*: Q4's partition is free semantically; only cost remains. *To land*:
state the S0 monotonicity contract as a checked property of propagators (same audit as §2.1) and
make the stratum boundary the only place where "quiescent" is observable.

### 2.4 LVars / LVish (T10, T11)

FHPC 2013: LVars are lattice-valued locations; `put` is lub; `get` takes a *threshold set* of
pairwise-incompatible elements and blocks until the value reaches one of them, returning that
element — so a read can never observe an intermediate state that a different schedule would
not also pass through. Theorem 1 (Determinism) follows by a diamond lemma. POPL 2014 adds
`freeze` (after which further `put`s are errors) and event handlers; Theorem 1
(Quasi-Determinism): terminal configurations agree up to location renaming or one is `error`.
The paper is explicit that handler quiescence is "a transient, negative property" that can be
used "to tell that a fixpoint has been reached" — i.e. the same non-monotone boundary as CALM's.
Kuper's 2015 dissertation collects both (PDF verified).

**Critique against our design.** Our propagators read cells directly (not threshold reads).
LVars put the determinism burden on the *read discipline*; we put it on *propagator
monotonicity*. These are equivalent in power — a monotone propagator applied to a lower bound
of the final value produces a lower bound of its final output, which is harmless under join —
but ours is a global proof obligation (Q1) where theirs is local and type-enforced. Our stratum
barrier is a *global* freeze of all S0 cells at once, which is simpler than per-LVar freeze
and avoids the freeze/put race entirely (no `error` case) provided no S0 fire is in flight when
S1 starts — that is precisely what quiescence detection must certify. The LVish runtime detects
handler quiescence with a counter of outstanding callbacks per handler pool — the shared-memory
termination-detection pattern of §2.9.

**Assessment.** *Possible*: a per-cell "frozen" flag (one bit in the flat record) turns the
stratum boundary into a structural check — a late S0 write to a frozen cell is a classified
error, not silent corruption. *To land*: add the flag to the flat record; set it in the barrier;
check it in the owner-write path (cost: one load on the fire path, measurable in Pre-0).

### 2.5 CRDTs and δ-state CRDTs (T12, T13)

SSS 2011 Definition 4 + Theorem 1 (verbatim above): join-semilattice payload, merge = LUB,
updates inflate, eventual delivery ⇒ SEC. δ-CRDTs (2018): a delta-mutator mᵟ returns a small
state with m(X) = X ⊔ mᵟ(X); delta-groups are joins of deltas; Proposition 5.1: convergence if
every delta is joined at least once at every replica — proof "trivial, given associativity,
commutativity, and idempotence". The *causal delta-merging condition* and delta-intervals are
needed only for causal consistency, not for convergence.

**Critique.** Our owner-bucketed dirty list is a delta-group addressed to the single replica that
matters (the owner's canonical record). Two consequences: (a) the join phase of BSP mode and the
cross-partition path of DIRECT are sound with *no* ordering condition on deltas; (b) idempotence
is load-bearing — the `+` sites of §2.2 fail it. What CRDT theory adds that R3 did not state: a
delta may be joined *more than once* (duplicate dirty entries are harmless), so the dirty list
needs no dedup for correctness, only for cost. What our setting removes: there is one authoritative
copy per cell, so "replica divergence" is only reader staleness (UD's A3), never a merge of two
canonical histories.

**Assessment.** *Possible*: the dirty-list protocol needs no sequence numbers or acks. *To
land*: nothing beyond keeping merges ACI; Pre-0 should count duplicate dirty entries to size the
cost (not correctness) of dedup.

### 2.6 Fork/join with merge functions; Kahn networks (T14; Concurrent Revisions = PRECEDENT)

Concurrent Revisions (Burckhardt–Baldassin–Leijen, OOPSLA 2010, DOI 10.1145/1869459.1869515):
fork creates a revision with a private snapshot; join merges per *isolation type* with a
declared merge function; the outcome is determined by the revision diagram, not by scheduling.
(Existence verified via ACM listing; the body could not be fetched during writing — §4.) Kahn
1974 (verified reproduction): processes are continuous functions on histories; the network's
fixpoint system "admits a unique minimal solution" — determinacy without any scheduling
assumption beyond blocking reads.

**Critique / Q2.** Our `fork-prop-network` (5 call sites: S1 NAF, fork-on-union) is a revision
fork whose join is a single bit (nogood / provability) under `or-merge`: the cheapest possible
merge function. So the *semantics* of fork is settled; Q2 is entirely a cost question: CHAMP fork
(232 ns, 1.2 KB, measured) vs arena copy (estimated 100–300 µs at C=16K, E=12). Revisions'
answer to the cost is copy-on-write at page/object granularity; the arena equivalent is
partition-granular COW (copy only partitions the fork writes), which is implementable because
ownership already partitions the arena. Kahn's relevance is structural: our network is a
Kahn-like dataflow with non-consuming reads, and the same unique-minimal-solution argument applies
with lattices in place of histories.

**Assessment.** *Possible*: fork stays O(1) semantically; the storage tier decides the constant.
*To land*: Pre-0 Q2 — forks per query on `benchmarks/comparative/`; if > ~10 per query, implement
partition-granular COW (an owner-side "copied" bit per partition) before the flat tier ships.

### 2.7 Graph-parallel systems (T15, T16; Pregel, Ligra, Galois, Xie et al. = PRECEDENT)

| system | consistency / mode | ownership & cut | termination | what it says to us |
|---|---|---|---|---|
| Pregel (SIGMOD 2010) | BSP supersteps; messages visible next superstep | hash partition of vertices; edges with their source | "every vertex voting to halt" + no messages in flight | our BSP mode exactly; the vote-to-halt is a global AND evaluated at the barrier |
| GraphLab (UAI 2010 / VLDB 2012) | async; vertex / edge / full consistency; Prop. 3.1 | edge-cut with *ghosts* (cached neighbour copies) | distributed consensus (Misra 1983 markers) | serialisability is a stronger requirement than we need; ghosts are what shared memory makes unnecessary |
| PowerGraph (OSDI 2012) | GAS; sync and async engines | vertex-cut with mirrors; Thm 5.2 on replication | per-engine; async uses distributed locking | vertex-cut matters when degree is power-law and edges must be stored once; our "edges" are propagators (hyperedges) |
| Ligra (PPoPP 2013) | shared memory, frontier-based, sparse/dense `edgeMap` switching | none needed (shared memory) | frontier empty | the closest machine model to ours; frontier = dirty list; dense/sparse switch = R3's "dense per-executor delta made join O(K·C)" lesson |
| Galois / "tao" (PLDI 2011) | operator formulation; amorphous data-parallelism; unordered vs ordered algorithms; cautious operators | none (shared memory, speculative) | worklist empty | S0 under DIRECT is an *unordered* algorithm with commutative operators — the easiest class in their taxonomy; no speculation needed |
| Xie et al. (PPoPP 2015) | sync vs async: "no single mode consistently outperforms the other"; Hsync switches adaptively | PowerGraph's | — | async wins when work per round is small/skewed; sync wins when rounds are dense; the switch is an empirical policy |

**Q4 in shared memory.** The edge-cut/vertex-cut distinction is about *where replicas live*. With
one address space there are no replicas; a non-owner read is an acquire-load of the owner's
record (a cache-line transfer, ~60 ns measured) and a non-owner write is a delta entry. The cut
therefore has one cost term: the fraction of propagator *outputs* that cross the owner boundary
(writes become deltas) and a second-order term for input locality (reads bounce lines). Since a
propagator is a hyperedge (inputs ∪ outputs), the natural statement is a hypergraph partition
minimising cut outputs — METIS-style balanced partition at topology-stratum time (GraphLab 2012
uses METIS for its atoms). Round-robin is the baseline Pre-0 measures against.

**Assessment.** *Possible*: Ligra-style frontier execution and Galois' unordered-operator class
describe DIRECT S0 precisely; GraphLab's consistency machinery is unnecessary because joins
commute. *To land*: Pre-0 Q4 — on real networks, fraction of declared output edges crossing the
cut for round-robin vs connected-component vs balanced partition; the gain must exceed partition
cost at the topology stratum.

### 2.8 Parallel Datalog and timely dataflow (PRECEDENT)

Soufflé (CAV 2016, DOI 10.1007/978-3-319-41540-6_23; CC 2016, DOI 10.1145/2892208.2892226):
semi-naïve evaluation compiled to C++ with OpenMP parallel loops over partitioned relation scans;
"with this partitioning of relations [into stable and delta parts] the fixed-point will converge
faster"; parallel inserts into concurrent B-trees. Semi-naïve = "fire only on the delta" = our
dirty list; Soufflé stays *synchronous* per stratum (each iteration is a barrier) because its
relations are sets under union — it never needed asynchrony for correctness, it chose barriers for
simplicity of the generated loops. Naiad (SOSP 2013) keeps per-pointstamp *occurrence counts* and
*precursor counts*; a pointstamp with zero precursors is in the frontier and its notifications
may be delivered — quiescence of an epoch/iteration is detected without a global barrier, by a
distributed count protocol (every worker broadcasts count deltas). Differential dataflow (CIDR
2013) is the same on partially ordered timestamps with deltas. Note: Naiad's progress tracking is
itself coordination (counts must be globally consistent) — it is CALM's negative result
implemented efficiently, which is exactly what the stratum boundary needs.

**Assessment.** *Possible*: stratum-boundary detection as a count protocol rather than a
barrier (§2.9). *To land*: the counts must be exact under DIRECT, which means every dirty entry
produced must be matched by one consumed — the dirty-list protocol has to be accounted, not just
fair.

### 2.9 Quiescence detection without a barrier (PRECEDENT + CONJECTURE)

Dijkstra–Scholten (EWD687a, IPL 1980): for a *diffusing* computation (single initiator) maintain a
spanning tree of engagement; each message is matched by a later signal; a node signals its parent
when it is idle and has received signals for all messages it sent; the root detects termination
when its deficit is zero. Mattern 1987 (abstract verified): algorithms "all based on the idea of
message counting" with time-cut consistency arguments for non-FIFO asynchronous channels. Chandy–
Misra's knowledge-based treatment ("How processes learn", DOI 10.1007/BF01843569) and Misra's 1983
marker algorithm (used by GraphLab) are the other classical family.

**Which fits K spinning executors on shared memory.** The channels are dirty-list buckets with
release/acquire visibility; there is no message loss and no FIFO problem, so Mattern's counting
degenerates to: each executor keeps (produced, consumed) counters in its own padded line; the
orchestrator scans the K lines; Σproduced = Σconsumed on two consecutive scans with no executor
having changed state between them ⇒ quiescent (the double scan is the "consistent cut" in
shared-memory clothing). Cost: K line reads per scan ≈ K × 60 ns = 1 µs at K=16 — the same order
as the barrier it replaces (R3: 0.8 µs at K=8). A single atomic in-flight counter is the
alternative: one CAS per delta (~60 ns cross-core when contended) — cheaper to detect, dearer to
produce. Dijkstra–Scholten's tree is unnecessary: the scheduler is a known single initiator and
all K are its children, so the "tree" has depth one.

**Assessment.** *Possible*: removing the S0 barrier does not remove the detection cost; it
amortises it (scans happen only when an executor's bucket drains). *To land*: Pre-0 benchmark —
double-scan detection vs barrier vs atomic counter at K ∈ {4, 8, 16}, with the detection latency
(time from true quiescence to detection) reported alongside throughput.

### 2.10 BSP cost model (T17)

Valiant's superstep cost is w + g·h + L: local work, communication at throughput ratio g for an
h-relation, periodicity L. Our terms, measured (R3): L ≈ 0.8–1 µs (K-way dispatch + barrier via
boxes + fences); w ≈ 1 µs per fire today (943 ns at K=1 in the arena prototype; 1.5 µs in the
current CHAMP protocol); h = delta volume per executor per round. The model says the barrier is
costly exactly when w per round is comparable to L — i.e. when a round holds few fires per
executor, which is the tail of every solve (the last rounds of a quiescence test are nearly
empty; R3's 15 rounds vs 10 under DIRECT is that tail). It also says what DIRECT changes:
fewer supersteps *and* no L inside S0, but g·h is unchanged (deltas still cross the cut) unless
Q4 reduces h.

**Assessment.** *Possible*: a per-query cost estimate from (rounds, fires/round, cut deltas)
instead of end-to-end wall only. *To land*: instrument rounds and fires/round per query on the
comparative corpus (Pre-0 cheap instrumentation); the model then predicts the DIRECT gain
before the tier ships.

### 2.11 Memory management for the arena tier (T18; Chez allocator = MEASUREMENT + source)

Tofte–Talpin: the store is a stack of regions; `letregion` allocates and bulk-frees; region
inference is proved sound (no access to a deallocated region). The guarantee an arena gives is
exactly this — no dangling, O(1) bulk free — and the price is exactly this — nothing inside a
live region is reclaimed until the region dies. For us: the partition arena's region is the
network (persistent cells) or the query (query-scoped cells); the latent quadratic of R3 §8.3
(entries never deduplicated) becomes *memory* growth inside a live region rather than GC churn,
so compaction (gap analysis §7 item 5: overflow side table) is the intra-region reclamation we
must build by hand. Chez: each thread context carries its own allocation pointer / end (`AP(tc)`,
`EAP(tc)`); refill goes through `S_get_more_room_help`, which calls `alloc_mutex_acquire()`
(verified in `racket/ChezScheme` master `c/alloc.c`; also `S_find_more_gc_room`,
`S_record_new_dirty_card`, `S_scan_remembered_set`). So Chez already has a thread-local
allocation buffer; the ceiling R3 measured is the refill mutex plus the shared collector. A flat
arena that never allocates on the fire path sidesteps both — which is the mechanism behind the
"~0 B per fire" rows.

**Assessment.** *Possible*: fire-path allocation of 0 B is a region discipline, not a trick.
*To land*: define the region lifetimes (network vs query vs fork) explicitly in D.1, and give
each a bulk-free point and a compaction policy; measure region growth per query in Pre-0.

### 2.12 Hardware: coherence, false sharing, Apple M-series (MEASUREMENT; references partly unverified)

False sharing — two cores writing distinct words of one cache line and bouncing it — is the
standard coherence pathology (Hennessy & Patterson, *Computer Architecture: A Quantitative
Approach*, thread-level-parallelism chapter; book verified to exist, chapter text not checked
here). R3 measured it directly: K consecutively allocated `box` counters shared a line and padding
took K=8 from 2.9× to 5.8×. Cross-core cache-line transfer on Apple silicon: the
`hydroo/macos-core-to-core-latency` benchmark (verified repo) publishes heat-maps for M4/M5
families but as images, with a code comment mentioning ~100 ns on M Ultra; AnandTech's M1
core-to-core article exists but could not be extracted. R3's ~60 ns one-way hop is consistent
with the general range for same-die clusters but **no independent numeric source for M5 Max was
verified in this survey** — it stands as our measurement.

**Assessment.** *Possible*: a 60 ns transfer bounds the cost of every cross-partition read, so
read locality (Q4) has a known unit price. *To land*: run the hydroo benchmark on the owner's
M5 Max once and record the matrix next to R3's pingpong number; pad every per-executor object
(already a rule from R3).

### 2.13 Propagator networks (Radul & Sussman 2009; Radul 2009 thesis)

The thesis (verified, MIT-CSAIL-TR-2009-053) states the scheduler contract explicitly:
"Propagators are run in an arbitrary, unpredictable order … Every propagator that is queued will
eventually run … Every execution of every propagator, including every read and every write of
every cell, is atomic. This is an accident of the scheduler's being single-threaded". On
parallelism it defers: "give the performance gurus free rein to optimize, parallelize, distribute"
and §6.4 "Scheduling can be Smarter" leaves resource allocation "open to future work" with one
suggestion — "run the most informative first". On merge: "the key idea of propagating mergeable,
partial information" with "the merging mechanism generic"; the thesis does not require
idempotence or commutativity of merge in general and proves no determinism theorem — it relies on
the merge being well-behaved per cell. The TR version (MIT-CSAIL-TR-2009-002, "The Art of the
Propagator") was located on DSpace but not extracted.

**Critique.** The original contract is the *sequential* special case of UD's schedule (A2 is
"every queued propagator eventually runs"; A1/A3 are trivial single-threaded; atomicity is "an
accident"). Our design replaces "atomic read/write" by "append-only records with release/acquire"
and must therefore prove what the original got from single-threading: that a reader sees a lattice
element. It does (prefix of an append-only set is a set), which is why the tagged-cell prototype
works — but only for lattices whose flat encoding has that prefix property; a structured value
whose merge rewrites in place (type-merge, session-lattice-merge) does not, and must stay on the
heap tier with a pointer swap (one word, atomic) as its publication step.

**Assessment.** *Possible*: the propagator model's own contract is satisfiable in parallel with
nothing stronger than lattice reads. *To land*: for each flat lattice, the encoding must be
prefix-closed (every published prefix is a valid element); for heap-tier cells, publication is a
single pointer store under release.

## 3. Assumptions Track 4's design rests on, each with its test (feeds Pre-0)

| # | assumption | kind | test / measurement | maps to |
|---|---|---|---|---|
| A-1 | every S0 propagator is a monotone function of its input cells (worldview fixed per solve) | THEOREM precondition (T5/T8/T10) | static audit of `net-add-propagator` sites (103) + parity suite under DIRECT at K=16 with randomised executor delays | Q1 |
| A-2 | every S0 merge is ACI and inflationary; `+` / `int-merge` (18 sites) are bounded or converted | THEOREM precondition (T12/T13) | merge census with a per-lattice (ACI? ACC? height) table; property tests on each merge | §2.2 (new) |
| A-3 | no S0 code observes absence ("not yet written") — all negative tests live at S1 | THEOREM (CALM only-if) | grep for reads followed by emptiness checks inside S0 fires; worldview sites (186) audit | Q1 |
| A-4 | reads under DIRECT see a valid lattice element (prefix-closed flat encodings) | design invariant | per-lattice encoding review; stress test with torn-read detector at K=16 | §2.13 |
| A-5 | executors are fair: no executor parks with a non-empty bucket; no fire caches inputs across fires | THEOREM precondition (UD A2/A3) | park/unpark protocol with a drain check; grep for memoised reads | Q7 |
| A-6 | quiescence detection is exact: every dirty entry produced is consumed once | correctness of boundary | counter invariants asserted in debug builds; Pre-0 detection benchmark (double scan vs barrier vs atomic) | §2.9 (new Pre-0) |
| A-7 | forks per query are rare enough for arena copy, or partition-granular COW is built | MEASUREMENT | count `fork-prop-network` per query on `benchmarks/comparative/` | Q2 |
| A-8 | the owner cut reduces cross-partition writes enough to pay for partitioning | MEASUREMENT | fraction of declared output edges crossing the cut: round-robin vs CC vs balanced | Q4 |
| A-9 | per-round work is small enough that L ≈ 1 µs matters (otherwise DIRECT's gain is only the round count) | MEASUREMENT (T17 terms) | rounds and fires/round per query on the corpus | §2.10 |
| A-10 | region lifetimes (network / query / fork) are explicit and growth inside a live region is bounded by compaction | design + MEASUREMENT (T18) | region bytes per query; entries per cell distribution | Q5, Q6 |
| A-11 | cross-core transfer ≈ 60 ns on the target machine | MEASUREMENT | hydroo benchmark run on M5 Max, recorded next to `pingpong.rkt` | §2.12 |
| A-12 | heap-tier cells (53 %) publish by a single pointer store; their merge allocation bounds scaling by the intensity law | MEASUREMENT (R3 §2) | bytes/µs of elaborator fires on a real file | Q3 |

## 4. Citations that could NOT be fully verified

- Üresin & Dubois 1990 §4 Propositions 3–6 (poset sufficient conditions): paper verified and read,
  but the proposition bodies are equations lost in extraction; the monotone/finite-chain condition
  is stated here from the §4 prose and the Agda restatements (ITP 2018 / JAR 2020), not verbatim.
- Bertsekas & Tsitsiklis 1989, Prop. 6.2.1 (Asynchronous Convergence Theorem): only the table of
  contents was verified; the theorem text is taken from Bertsekas 1983 (read) which it reprints.
- Cousot 1977 IMAG RR-88: abstract verified on the author's page; the scanned body was not read.
- Burckhardt, Baldassin, Leijen 2010 (Concurrent Revisions): ACM listing verified (DOI
  10.1145/1869459.1869515); body fetch timed out — the description is from the abstract/knowledge.
- Chandy & Misra, "How processes learn" (DOI 10.1007/BF01843569) and Misra 1983 "Detecting
  termination of distributed computations using markers" (PODC): DOI / citation located, bodies
  not read.
- Dijkstra, Feijen, van Gasteren 1983 (IPL 16(5), ring token): ScienceDirect listing found, not read.
- Hennessy & Patterson: book existence verified; the false-sharing definition is from the
  coherence chapter by knowledge, not re-read.
- AnandTech M1 core-to-core latency article: extraction redirected to the forums; no numbers
  verified. chipsandcheese: only a generic core-to-core/locks article was found, no Apple-specific
  numbers. hydroo repo: verified, numbers in images only.
- Radul & Sussman 2009 "The Art of the Propagator" (MIT-CSAIL-TR-2009-002): DSpace record located
  (handle 1721.1/44215), not extracted; the thesis (TR-2009-053) was read instead.
- Bloom^L / "CALM for lattices" (Conway et al. 2012): mentioned in §2.3 as folklore extension; not
  searched or verified in this draft.

## 5. Bibliography (verified URLs / DOIs)

- Tarski, A. (1955). A lattice-theoretical fixpoint theorem and its applications. *Pacific J. Math.* 5(2):285–309. https://msp.org/pjm/1955/5-2/pjm-v5-n2-p11-p.pdf
- Chazan, D.; Miranker, W. (1969). Chaotic relaxation. *Linear Algebra Appl.* 2:199–222. DOI 10.1016/0024-3795(69)90028-7. https://www.sciencedirect.com/science/article/pii/0024379569900287
- Cousot, P. (1977). Asynchronous iterative methods for solving a fixed point system of monotone equations in a complete lattice. Res. Rep. R.R. 88, IMAG Grenoble. https://cs.nyu.edu/~pcousot/COUSOTpapers/IMAG-RR88.shtml
- Cousot, P.; Cousot, R. (1977). Abstract interpretation: a unified lattice model for static analysis of programs by construction or approximation of fixpoints. POPL 1977. DOI 10.1145/512950.512973. https://cs.nyu.edu/~pcousot/COUSOTpapers/POPL77.shtml
- Bertsekas, D. P. (1983). Distributed asynchronous computation of fixed points. *Math. Programming* 27:107–120. DOI 10.1007/BF02591967. http://web.mit.edu/dimitrib/www/Distr_Comp_Fixed.pdf
- Bertsekas, D. P.; Tsitsiklis, J. N. (1989). *Parallel and Distributed Computation: Numerical Methods*. Prentice-Hall (Athena reprint). Contents: http://www.athenasc.com/pdccontents.html
- Üresin, A.; Dubois, M. (1990). Parallel asynchronous algorithms for discrete data. *J. ACM* 37(3):588–606. DOI 10.1145/79147.79162. https://dl.acm.org/doi/10.1145/79147.79162
- Zmigrod, R.; Daggitt, M. L.; Griffin, T. G. (2018). An Agda formalization of Üresin & Dubois' asynchronous fixed-point theory. ITP 2018. DOI 10.1007/978-3-319-94821-8_37. — and (2020) A relaxation of Üresin and Dubois' asynchronous fixed-point theory in Agda. *J. Autom. Reasoning* 64:857–877. DOI 10.1007/s10817-019-09536-w
- Hellerstein, J. M. (2010). The declarative imperative: experiences and conjectures in distributed logic. *SIGMOD Record* 39(1). https://db.cs.berkeley.edu/papers/sigrec10-declimperative.pdf
- Ameloot, T. J.; Neven, F.; Van den Bussche, J. (2013). Relational transducers for declarative networking. *J. ACM* 60(2). DOI 10.1145/2450142.2450151. arXiv: https://arxiv.org/abs/1012.2858
- Hellerstein, J. M.; Alvaro, P. (2020). Keeping CALM: when distributed consistency is easy. *CACM* 63(9). DOI 10.1145/3369736. https://arxiv.org/abs/1901.01930
- Kuper, L.; Newton, R. R. (2013). LVars: lattice-based data structures for deterministic parallelism. FHPC 2013. DOI 10.1145/2502323.2502326. https://users.soe.ucsc.edu/~lkuper/papers/lvars-fhpc13.pdf
- Kuper, L.; Turon, A.; Krishnaswami, N. R.; Newton, R. R. (2014). Freeze after writing: quasi-deterministic parallel programming with LVars. POPL 2014. DOI 10.1145/2535838.2535842. https://users.soe.ucsc.edu/~lkuper/papers/lvish-popl14.pdf
- Kuper, L. (2015). *Lattice-based data structures for deterministic parallel and distributed programming*. PhD thesis, Indiana University. https://users.soe.ucsc.edu/~lkuper/papers/lindsey-kuper-dissertation.pdf
- Shapiro, M.; Preguiça, N.; Baquero, C.; Zawirski, M. (2011). Conflict-free replicated data types. SSS 2011, LNCS 6976. DOI 10.1007/978-3-642-24550-3_29. https://www.lip6.fr/Marc.Shapiro/papers/2011/CRDTs_SSS-2011.pdf
- Almeida, P. S.; Shoker, A.; Baquero, C. (2018). Delta state replicated data types. *J. Parallel Distrib. Comput.* 111:162–173. DOI 10.1016/j.jpdc.2017.08.003
- Burckhardt, S.; Baldassin, A.; Leijen, D. (2010). Concurrent programming with revisions and isolation types. OOPSLA 2010. DOI 10.1145/1869459.1869515
- Kahn, G. (1974). The semantics of a simple language for parallel programming. IFIP Congress 74. Reproduction: https://perso.ensta.fr/~chapoutot/various/kahn_networks.pdf
- Malewicz, G. et al. (2010). Pregel: a system for large-scale graph processing. SIGMOD 2010. DOI 10.1145/1807167.1807184. https://www.cs.albany.edu/~jhh/courses/readings/malewicz.sigmod10.pregel.pdf
- Low, Y. et al. (2010). GraphLab: a new framework for parallel machine learning. UAI 2010. https://arxiv.org/abs/1006.4990
- Low, Y. et al. (2012). Distributed GraphLab: a framework for machine learning and data mining in the cloud. *PVLDB* 5(8). DOI 10.14778/2212351.2212354. http://vldb.org/pvldb/vol5/p716_yuchenglow_vldb2012.pdf
- Gonzalez, J. E. et al. (2012). PowerGraph: distributed graph-parallel computation on natural graphs. OSDI 2012. https://www.usenix.org/system/files/conference/osdi12/osdi12-final-167.pdf
- Shun, J.; Blelloch, G. E. (2013). Ligra: a lightweight graph processing framework for shared memory. PPoPP 2013. DOI 10.1145/2442516.2442530. https://www.cs.cmu.edu/~blelloch/papers/SB13.pdf
- Pingali, K. et al. (2011). The tao of parallelism in algorithms. PLDI 2011. DOI 10.1145/1993498.1993501. https://iss.oden.utexas.edu/Publications/Papers/pingali11.pdf
- Xie, C.; Chen, R.; Guan, H.; Zang, B.; Chen, H. (2015). SYNC or ASYNC: time to fuse for distributed graph-parallel computation. PPoPP 2015. https://ipads.se.sjtu.edu.cn/projects/powerswitch/powerswitch-ppopp15.pdf
- Jordan, H.; Scholz, B.; Subotić, P. (2016). Soufflé: on synthesis of program analyzers. CAV 2016. DOI 10.1007/978-3-319-41540-6_23. https://souffle-lang.github.io/cav-paper
- Scholz, B.; Jordan, H.; Subotić, P.; Westmann, T. (2016). On fast large-scale program analysis in Datalog. CC 2016. DOI 10.1145/2892208.2892226. https://souffle-lang.github.io/pdf/cc.pdf
- Murray, D. G. et al. (2013). Naiad: a timely dataflow system. SOSP 2013. DOI 10.1145/2517349.2522738. https://www.cs.princeton.edu/courses/archive/fall22/cos418/papers/naiad.pdf
- McSherry, F.; Murray, D. G.; Isaacs, R.; Isard, M. (2013). Differential dataflow. CIDR 2013. https://www.cidrdb.org/cidr2013/Papers/CIDR13_Paper111.pdf
- Dijkstra, E. W.; Scholten, C. S. (1980). Termination detection for diffusing computations. *Inf. Proc. Letters* 11(1):1–4. EWD687a: https://www.cs.utexas.edu/~EWD/transcriptions/EWD06xx/EWD687a.html
- Mattern, F. (1987). Algorithms for distributed termination detection. *Distributed Computing* 2(3):161–175. DOI 10.1007/BF01782776
- Chandy, K. M.; Misra, J. (1986). How processes learn. *Distributed Computing* 1. DOI 10.1007/BF01843569
- Valiant, L. G. (1990). A bridging model for parallel computation. *CACM* 33(8):103–111. DOI 10.1145/79173.79181
- Tofte, M.; Talpin, J.-P. (1997). Region-based memory management. *Information and Computation* 132(2):109–176. DOI 10.1006/inco.1996.2613
- Chez Scheme (Racket fork), `c/alloc.c`: https://raw.githubusercontent.com/racket/ChezScheme/master/c/alloc.c (`S_get_more_room_help`, `S_find_more_gc_room` under `alloc_mutex_acquire`)
- hydroo, macOS core-to-core latency benchmark: https://github.com/hydroo/macos-core-to-core-latency
- Radul, A. (2009). *Propagation Networks: A Flexible and Expressive Substrate for Computation*. PhD thesis, MIT (MIT-CSAIL-TR-2009-053). https://dspace.mit.edu/handle/1721.1/49525
- Radul, A.; Sussman, G. J. (2009). The art of the propagator. MIT-CSAIL-TR-2009-002. https://dspace.mit.edu/handle/1721.1/44215
