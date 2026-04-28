# ZK-Prologos: Lattice-Native Zero-Knowledge Proofs for the Propagator Network

**Date**: 2026-04-28
**Series**: ZKP (new) — touch-points to PRN, PPN, SRE, BSP-LE, CIU, ATMS, PM
**Status**: Stage 0/1 — research + planning, no implementation yet
**Branch**: `claude/lattice-zk-research-2RAB7`

**Cross-references**:
- `docs/research/2026-03-28_MODULE_THEORY_LATTICES.md` — the algebraic substrate this design exploits
- `docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md` — Boolean lattice / hypercube structure of ATMS
- `docs/research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md` — Galois bridges between lattice domains
- `.claude/rules/on-network.md` — design mantra
- `.claude/rules/structural-thinking.md` — Hyperlattice Conjecture, SRE 6 questions
- `.claude/rules/stratification.md` — strata on the propagator base, termination guarantees

---

## 0. TL;DR

> **Revision note (post-review).** An earlier version of this section claimed a "structural
> identity" between Prologos's order-theoretic lattices and the geometric/algebraic lattices
> of Module-SIS-based ZK. That overclaim has been walked back. The two senses of "lattice" are
> distinct algebraic objects (idempotent commutative semilattice vs. abelian-group module);
> the bridge between them is an *encoding*, and the encoding is clean only for a subset of
> Prologos cell domains. The architecture below still stands under the more modest framing.
> See §2.5 and §6 for the honest accounting.

Prologos's runtime is a propagator network: cells with monotone-merge values, propagators that
fire under BSP scheduling, an execution trace that IS a sequence of cell-state snapshots.
Lattice-based zero-knowledge proof systems (LaBRADOR, Greyhound, LatticeFold/+, Lova, Hachi)
prove statements about modules over polynomial rings under Module-SIS. The two systems are not
the same algebraic object, but the propagator-network execution trace turns out to be a *good
witness shape* for lattice-friendly proofs — not because of a deep identity, but because of
several concrete structural features (monotonic updates as additive openings, order-independent
within-round writes, idempotent firings, hypercube-shaped worldview lattices, explicit
dependency DAG, clean stratum boundaries). Section 6 enumerates ten such shortcuts.

The standard recipe for verifiable computation — compile to a generic VM (RISC0, SP1, Jolt),
arithmetize the trace, prove the arithmetization — pays a triple tax: (1) every layer of
compilation is information loss, (2) the VM trace is sequential where the source is parallel,
(3) the algebraic structure that makes the source meaningful (monotonicity, idempotence, lattice
joins) is invisible to the prover and has to be reconstructed via brute-force constraints.

This document plans an alternative: **encode each Prologos cell as an Ajtai/Module-SIS
commitment to a vector in `R_q^k`, prove BSP rounds with LaBRADOR or LatticeFold+, fold across
rounds with Lova or LatticeFold+, and host the verifier itself as a stratum on the propagator
network.** For *Group A cells* (bit-vectors, char-vectors, finite-alphabet monotone-set, ATMS
worldviews) the encoding is monotone-homomorphic and joins become native algebraic operations
on the commitments — the witness IS the network's update trace, no extra arithmetization. For
*Group B cells* (type/scope/AST cells) the encoding is opaque-Merkle and joins are
arithmetized as R1CS — same costs as a generic prover would pay, but at least amortized at
the BSP-round granularity rather than per ISA step.

The deliverable here is a research plan that walks the claims back to falsifiable phases. The
strong "structural identity" framing is dropped; the weak "lattice ZK is a good fit for
Prologos's execution shape" framing is the operating thesis.

---

## 1. Why not RISC0 (or SP1, Jolt, Nova, …)

The default story for "make X verifiable" is:

1. Compile X to a deterministic ISA (RISC-V, MIPS, EVM bytecode).
2. Run the program on a generic ZK-VM that arithmetizes each ISA step (fetch, decode, ALU,
   memory access, branch) into R1CS or AIR constraints.
3. Generate a SNARK or STARK over the trace.

For Prologos this is feasible but structurally lossy in three specific ways:

### 1.1 The compilation tax

Prologos elaborates source programs *on the propagator network itself*. The compiler is, by
design, a propagator network solving a fixpoint over cells (PM Track 12 explicitly drives all
of this on-network). Compiling that to RISC-V means:

- Take a network of N cells with monotone merges
- Linearize it into a sequence of imperative instructions
- Re-prove monotonicity per-step inside the VM as ordinary integer comparisons
- Lose the BSP round structure, the worldview bitmasks, the Hasse-diagram traversal hints

Every one of these losses is recoverable in principle but adds prover work. The native
structure was already information; collapsing it and reconstructing it costs both proof size
and prover time.

### 1.2 The parallelism tax

Prologos's design mantra (`on-network.md`) demands *all-at-once, all-in-parallel* execution.
A BSP round fires all enabled propagators simultaneously. A generic VM trace is sequential by
construction: instruction k+1 depends on instruction k's PC. Modern folding schemes (Nova,
HyperNova, ProtoStar, LatticeFold+) recover *some* parallelism by independently proving and
folding chunks, but the chunk boundaries are arbitrary. The natural chunk boundary for
Prologos is the BSP round, which the VM has thrown away.

### 1.3 The algebraic-structure tax

The single most important property of a Prologos cell is that its merge function is monotone
and (for most cells) idempotent. This is the load-bearing fact behind CALM, behind the
S0-monotone stratum, behind the Hyperlattice Conjecture, behind every coordination-free claim
the system makes.

In a generic ZK-VM, this fact is encoded as an integer comparison between two memory regions.
The prover proves "memory[c] at step t+1 ≥ memory[c] at step t" by bit-decomposing both and
comparing — with no help from the algebraic structure that made the comparison true in the
first place.

In a lattice-based proof system, by contrast, "monotone update of a Module-SIS-committed cell"
is *exactly* "the new commitment differs from the old by a small-norm vector" — which is the
native statement type Module-SIS is built around. The proof obligation matches the algebraic
fact one-to-one.

### 1.4 What "directly leverage the lattices" can mean

Two reasonable interpretations:

- **Weak**: re-use cryptographic-lattice infrastructure (Module-SIS commitments, sumcheck-over-
  rings) as the proving backend, while still arithmetizing Prologos's logic into R1CS/CCS.
  This is achievable today using LaBRADOR + Greyhound + LatticeFold+. It buys post-quantum
  security and small recursion overhead.

- **Medium** (the operating thesis): exploit specific structural shortcuts that the
  propagator-network execution shape exposes to a lattice-friendly prover, on top of the
  weak baseline. These shortcuts are concrete and testable (catalogued in §6); they do not
  require a deep algebraic identity between the two senses of "lattice."

- **Strong** (overclaimed in earlier drafts; walked back): a *structural identity* between
  Prologos's order-theoretic lattices and the geometric/algebraic lattices of cryptography,
  such that the two share a substrate. §2.3 documents why this claim does not hold
  algebraically. The Galois-connection framing applies to Group A cells only.

The plan below pursues the medium interpretation. The weak interpretation is delivered as a
byproduct. The strong interpretation is *not* what the architecture rests on.

---

## 2. Two senses of "lattice" — bridging the gap

The word "lattice" carries two technically distinct meanings that must be reconciled before
the design can proceed.

### 2.1 Order-theoretic lattices (what Prologos uses)

A partially ordered set `(L, ≤)` in which every two elements have a least upper bound (join,
`⊔`) and a greatest lower bound (meet, `⊓`). Examples in Prologos:

- Type cells: `⊥` ≤ unsolved meta ≤ structural type ≤ `⊤`. Join = unification.
- Monotone-set cells (`infra-cell-sre-registrations.rkt`): power set under `⊆`. Join = union.
- Worldview / ATMS: Boolean lattice `2^n` of assumption combinations. Join = OR.
- Decision cells: domain-narrowing lattice — a downward narrowing of "viable choices."
- Hash-union cells (table registry, module registry): `(K → V, ≤)` with point-wise `V`-merge.
- Term lattice (FL narrowing): partial terms with `?` holes, ordered by refinement.

The unifying claim of Prologos is that *every* cell's value lattice is a join-semilattice
(usually with `⊥`), and merges are monotone. The CALM theorem then guarantees coordination-
free distributed evaluation; Tarski guarantees fixpoint convergence (`stratification.md`,
table at §"Termination guarantees").

### 2.2 Geometric / algebraic lattices (what cryptography uses)

A discrete additive subgroup `Λ ⊂ R^n` of full rank. Equivalently, `Λ = { ∑_i a_i b_i : a_i ∈
Z }` for some basis `b_1,…,b_n ∈ R^n`. The hard problems are about *short* vectors:

- **SIS** (Short Integer Solution): given random `A ∈ Z_q^{n×m}`, find short nonzero `z` with
  `Az ≡ 0 mod q`.
- **Ring-SIS / Module-SIS**: same problem, but `A` and `z` live in `R_q^{·}` where `R_q =
  Z_q[X] / (X^d + 1)` (a power-of-two cyclotomic ring). Module-SIS works over `R_q`-modules of
  small dimension, balancing structure (efficiency) and conservatism (security).
- **LWE / Module-LWE**: the decisional sibling — distinguish `(A, As+e)` from uniform.

The cryptographic lattice is a *Z*-module (or *R_q*-module). Hardness comes from the
combinatorial sparsity of "short" vectors and the geometry of bases.

### 2.3 They are not the same algebraic object

**Earlier drafts of this section overclaimed.** The two senses of "lattice" are not instances
of the same algebraic shape. Concretely:

| | Prologos's `(L, ⊔, ⊥)` | Module-SIS's `R_q^k` |
|---|---|---|
| Operation | join `⊔` | addition `+` mod `q` |
| Idempotent? | yes (`v ⊔ v = v`) | no (`v + v = 2v`) |
| Inverse? | no | yes |
| Algebraic class | idempotent commutative monoid | abelian group |
| Order from? | lattice order intrinsic | norm (extrinsic) |

An idempotent commutative monoid is *not* a Z-module. There is no canonical functor between
these categories; the word "module" in `MODULE_THEORY_LATTICES.md` refers to the propagator
network being a module over its endomorphism ring (where module addition is `⊔`), and that
algebraic structure is fundamentally different from `R_q^k` (where module addition is `+`).

So the bridge is *not* an algebraic isomorphism. It is an *encoding* — a function `enc : L →
R_q^k` that preserves enough structure to be useful, but that loses the idempotence on the
target side. We compensate for the loss with a norm budget: encoded values live in a bounded
region of `R_q^k`, and joins are realized by algebraic operations (coordinate-wise OR / max /
addition + norm clip) chosen specifically to mimic the source-side idempotence within that
region.

This works cleanly for some cell domains and badly for others. The split is the load-bearing
distinction in the rest of the document.

### 2.4 Group A — cells with native algebraic encoding

A cell domain is "Group A" if its lattice admits a monotone homomorphism `enc: L → R_q^k`
where:
- `enc(v ⊔ w)` equals an algebraic operation on `enc(v), enc(w)` in `R_q^k`
- `‖enc(v)‖` is bounded by a quantity polynomial in `|L|` or in the cell's parameters
- `enc` is injective (no two source values collide)

The known Group A domains in Prologos:

| Domain | `enc` | Algebraic join | Norm bound |
|---|---|---|---|
| ATMS worldview bitmask (`HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`) | identity | bit-OR | `n` |
| `monotone-set` over finite alphabet `Σ` | char vector ∈ `{0,1}^|Σ|` | coord-wise OR | `|Σ|` |
| Multiplicity (m0/m1/mw) | 2-bit code | bit-OR | 2 |
| Decision narrowing over fixed finite domain | char vector | coord-wise AND (narrowing) | `|D|` |
| Numeric interval `[lo, hi]` | `(lo, hi) ∈ R_q^2` | `(min, max)` | depends on range |

For Group A cells the bridge is genuine: the SRE Galois-connection framing
(`STRUCTURAL_REASONING_ENGINE.md` lines 183–194) applies, the encoding is a monotone
homomorphism, and the cryptographic-side join IS an algebraic operation that mirrors the
source-side join under `enc`. Concrete payoff: monotone updates become Module-SIS additive
deltas (Shortcut 1 in §6), with no R1CS circuit for the merge itself.

### 2.5 Group B — cells with opaque-commit encoding only

A cell domain is "Group B" if no such `enc` exists with reasonable norm bound. The lattice
join is a complex computation on structured values (typically AST), not an algebraic operation
in `R_q^k`. The known Group B domains in Prologos:

- **Type cells**: `expr-Pi`, `expr-Sigma`, `expr-Lam`, dependent type expressions of unbounded
  recursive depth. Join = SRE structural unification — a non-trivial computation involving
  constructor-head matching, recursion on sub-expressions, fresh-meta allocation.
- **Scope cells / substitutions**: maps from meta-ids to AST values.
- **Constraint cells**: pending obligations whose structure references AST.
- **Trait dispatch tables**: keys to method-body ASTs.

For Group B, the bridge is "Merkle-commit the canonical-form serialization." The cell's
commitment is a hash of its serialized AST. The "join" is not an algebraic operation; it is
a computation that must be arithmetized as an R1CS instance, exactly as a generic VM would do.
The Module-SIS commitment is used here only as a cryptographic primitive — there is no
structural reuse of the lattice ordering on the prover side.

**The Galois-connection framing does not apply to Group B.** The α/γ pair on Group B is
"serialize / deserialize," which is bijective on individual values but not a lattice morphism
in any nontrivial sense.

### 2.6 The asymmetric architecture

The split implies an asymmetric architecture. For each cell `c`:

- If `c`'s domain is Group A: install bridge propagators α/γ as ordinary on-network
  Galois-bridge propagators (`structural-thinking.md` §"Bridges to Other Lattices"). Updates
  produce zero-cost (algebraic) proof obligations.

- If `c`'s domain is Group B: commit via canonical-form Merkle hash. Updates produce R1CS
  circuit obligations (size proportional to merge function complexity, bounded by cell-value
  depth).

A typical Prologos compilation involves *both* groups concurrently. Type-cell traffic
(elaboration phase) is Group B-heavy; worldview / decision / fact-accumulation traffic
(runtime phase) is Group A-heavy. The benefits of the lattice substrate are concentrated
where Group A dominates; Group B pays roughly the same cost a generic VM would.

---

## 3. State of the art in lattice-based ZK (early 2026)

This section catalogs the cryptographic infrastructure we can build on. All citations are to
peer-reviewed venues (CRYPTO, EUROCRYPT, ASIACRYPT, CCS) or `eprint.iacr.org` preprints.

### 3.1 Foundational primitives

**Ajtai commitments** (Ajtai 1996; Baum-Damgård-Lyubashevsky-Oechsner 2018,
[eprint 2016/997](https://eprint.iacr.org/2016/997)). Commitment to a vector `m ∈ R_q^k` is
`c = A · r + B · m` for short `r`, with `A, B ∈ R_q^{n×·}` public. *Additively homomorphic*:
`Com(m_1) + Com(m_2) = Com(m_1 + m_2)` — but the resulting opening's norm grows, so the
homomorphism is only valid within a norm budget. Binding reduces to Module-SIS.

**Sumcheck over rings** ([Hachi, eprint 2026/156](https://eprint.iacr.org/2026/156); ring-
switching of Huang-Mao-Zhang 2025). Standard sumcheck assumes a field; over `R_q` the
verifier must do ring multiplications, which dominates cost. Ring-switching reduces verifier
work to scalar (sub-ring) multiplications, making sumcheck-style protocols practical over
cyclotomic rings.

**Functional commitments from SIS** (Wee-Wu, [Peikert et al.](https://web.eecs.umich.edu/~cpeikert/pubs/func-com.pdf)). Commit
to a function `f` and later open `f(x)` for any `x` with a short proof. This is the
infrastructure for committing to a *propagator's fire function* and later proving its
input/output behavior.

### 3.2 Argument systems

**LaBRADOR** ([Beullens-Seiler, CRYPTO 2023](https://link.springer.com/chapter/10.1007/978-3-031-38554-4_17)). Recursive amortized
argument for R1CS over `Z_{2^64+1}`. Concrete: 58 KB proof for `2^20` constraints at 128-bit
security, plausibly post-quantum, Module-SIS-based. The recursive structure is naturally
suited to BSP rounds: each round's R1CS is folded into a running aggregate.

**Greyhound** ([Nguyen-Seiler, CRYPTO 2024](https://link.springer.com/chapter/10.1007/978-3-031-68403-6_8); [eprint 2024/1293](https://eprint.iacr.org/2024/1293)).
Polynomial commitment from Module-SIS. Linear prover, `O(√N)` verifier, polylog proof size
(`53 KB` for degree `2^30`). Composes with LaBRADOR for succinct end-to-end arguments.

**SLAP** ([Albrecht-Fenzi-Lapiha-Nguyen, EUROCRYPT 2024](https://eprint.iacr.org/2023/1469)). FRI-style
tree-commitment polynomial commitment from Module-SIS. Polylog proof and verification time.
Greyhound dominates concretely at scale, but SLAP's tree structure is conceptually cleaner
and may be more natural for incremental commitments (one tree per BSP round).

**Hachi** ([eprint 2026/156](https://eprint.iacr.org/2026/156)). Multilinear polynomial
commitment with `√N` verifier, ~55 KB proofs, ring-switching trick. Asymptotically improves on
Greyhound.

**LaZer library** ([Albrecht et al., CCS 2024](https://eprint.iacr.org/2024/1846)).
Production-oriented toolkit: declare a lattice relation and norm bound, get an automatically
synthesized proof system. The DSL-from-relation philosophy maps cleanly onto Prologos's
"cells declare their value lattice" discipline.

### 3.3 Folding schemes (recursive composition)

**LatticeFold** ([Boneh-Chen, ASIACRYPT 2025; eprint 2024/257](https://eprint.iacr.org/2024/257)). First
Module-SIS-based folding scheme. Folds R1CS and CCS instances. Operates over 64-bit fields,
performance comparable to HyperNova. Naturally PCD-capable.

**LatticeFold+** ([Boneh-Chen, CRYPTO 2025; eprint 2025/247](https://eprint.iacr.org/2025/247)). 5–10×
faster prover, simpler verifier, shorter proofs vs. LatticeFold via better range proof
(replaces bit-decomposition). The current best lattice folding scheme as of 2026.

**Lova** ([Fenzi-Pham-Nguyen, ASIACRYPT 2024; eprint 2024/1964](https://eprint.iacr.org/2024/1964)). Folding
from *unstructured* SIS — no NTT, no sumcheck. Linear-algebra only (matrix-matrix multiplies
with bounded-norm entries). Power-of-two moduli, no field arithmetic. Spectacularly easy to
parallelize. Prover/verifier cost is higher than LatticeFold+ but the implementation
simplicity is significant for an experimental track.

**Neo** ([eprint 2025/294](https://eprint.iacr.org/2025/294)). Lattice-based folding for CCS over small fields. Newer,
benchmarks pending; included for completeness.

### 3.4 What's missing (the opportunity)

A literature pass turned up *no* existing system that natively proves dataflow / propagator-
network / Petri-net / monotone-fixpoint computation. Every known ZK system assumes an R1CS,
CCS, AIR, or sequential-VM trace as its native statement type. Sumcheck protocols sum over a
hypercube but don't compose with monotone *joins*; they compose with *additive* accumulation.

This is the gap ZK-Prologos can fill. Concretely, two openings:

1. **A "joincheck" protocol**: the analog of sumcheck where the aggregate operation is a
   lattice join (associative, commutative, idempotent, monotone) rather than addition.
   Idempotence `v ⊔ v = v` collapses repeated terms, which is a structural property absent
   from sumcheck — meaning the protocol may be *shorter* than sumcheck for monotone-set
   accumulation.

2. **Native fixpoint certificates**: a proof of the form "the network reached quiescence" —
   i.e., one BSP round more would add no new information. This is *equality* of consecutive
   commitments, which is `c_{k+1} − c_k = 0` in the additive-homomorphism setting and reduces
   to a single Module-SIS opening of zero. Quiescence is an `O(1)` proof obligation, not an
   `O(N)` re-execution check.

Both of these are research opens. Section 6 lays out the falsification path for each.

---

## 4. Architecture: ZK-Prologos in six layers

The architecture is layered from cryptographic primitives at the bottom to user-facing
language features at the top. Each layer is a *propagator stratum* on the same network — there
is no separate "ZK subsystem." Bridges between layers are α/γ Galois pairs (§2.4).

```
┌─────────────────────────────────────────────────────────────────┐
│ L5  Self-verifying compiler — proofs travel with .pnet caches   │
├─────────────────────────────────────────────────────────────────┤
│ L4  Verifier-as-stratum — verification is a propagator          │
├─────────────────────────────────────────────────────────────────┤
│ L3  Folding stratum — Lova / LatticeFold+ across BSP rounds     │
├─────────────────────────────────────────────────────────────────┤
│ L2  Per-round prover — LaBRADOR over each BSP round's deltas    │
├─────────────────────────────────────────────────────────────────┤
│ L1  Cell-encoding bridges — α/γ propagators source ↔ R_q^k      │
├─────────────────────────────────────────────────────────────────┤
│ L0  Module-SIS substrate — R_q, Ajtai commitments, NTT          │
└─────────────────────────────────────────────────────────────────┘
```

### 4.1 L0 — Cryptographic substrate

- **Ring**: `R_q = Z_q[X] / (X^d + 1)` with `d ∈ {64, 128, 256}` (a power of two) and `q` a
  ~64-bit prime split for NTT (e.g., the LaBRADOR/LatticeFold+ choice of `q = 2^64 + 1` minus
  small variants). Selection trades security against NTT efficiency.
- **Hardness**: Module-SIS at 128-bit post-quantum security. Parameters tracked in a single
  configuration cell so that all bridges share them coherently.
- **Operations**: NTT/INTT, Ajtai commitment `Com(m; r) = A·r + B·m`, norm check
  `‖z‖_∞ ≤ β`, and the LaBRADOR/LatticeFold+/Lova back-end of choice.
- **Implementation strategy**: wrap an existing Rust library (`latticefold` from Nethermind,
  `lazer` from IBM/AIT, or `lova` from `lattirust`) as a Racket FFI shim. Phase 0 implements
  no crypto in Racket; we only orchestrate.

### 4.2 L1 — Cell-encoding bridges

For each Prologos cell domain `D` we need:
- `enc_D : D → R_q^{k_D}` — monotone encoding into a free module
- `commit_D : R_q^{k_D} × R → R_q^n` — Ajtai commitment with randomness
- `bridge_D` — propagator pair `(α, γ)` between source-domain cells and commitment cells

Concretely (one cell per domain class for the prototype):

| Domain | `enc` | Join law in `R_q` | Norm growth per merge |
|--------|-------|-------------------|----------------------|
| Boolean / monotone-set | char vector ∈ `{0,1}^k` | coord-wise OR | bounded by `k` |
| Worldview bitmask | identity into bit-vector | OR | bounded by `k` |
| Hash-union `(K → V)` | per-key `enc_V`, concatenate | per-key join | `|K|` × per-V growth |
| Numeric interval | `(lo, hi)` ∈ `R_q^2` | (min, max) | bounded by domain |
| Term / type lattice | depth-bounded tree-as-vector | structural unification | depth-bounded |

The bridge propagators α/γ are *ordinary on-network propagators*, subject to the same fire-
once / broadcast / set-latch design checklist as any other (`propagator-design.md`). They run
in their own stratum (Section 4.6) so that proof generation is sequenced after the source-
network round it is committing to.

**Crucial property**: the bridge is *lossless on the source side*. `γ(α(v)) = v` for every
source value the cell can take. This is required because Prologos must be able to read back
its own state from a committed proof (e.g., for incremental compilation).

### 4.3 L2 — Per-round prover

A BSP round is the atomic unit of proof. Inputs to a round: the snapshot of all cells at the
start. Outputs: cells at the end of the round, which differ from the start by the writes
emitted by fired propagators.

For each fired propagator `p` with reads `R_p`, writes `W_p`, and fire function `f_p`, the
proof obligation is:

> `f_p(snapshot[R_p]) = delta`, and `delta` is correctly merged into `W_p` by each cell's
> merge function.

In commitment form (writing `C[c]` for the Module-SIS commitment to cell `c`):

- Inputs: openings of `C[c]` for `c ∈ R_p` at the round's start
- Witness: short-norm randomness for `delta` and the new cell values
- Constraints: an R1CS or CCS encoding of `f_p` plus a per-cell merge constraint:
  `enc(c_{t+1}) = merge_c(enc(c_t), delta)` with the appropriate norm bound
- Output commitment: `C[c]` at the round's end

All propagators fired in round `k` produce a *single* aggregated R1CS/CCS instance, which is
proven by **LaBRADOR** (or **LatticeFold+** if we want folding-friendly per-round proofs from
the start). The round's proof is a cell value — committed back into the network for downstream
folding.

The fire function `f_p` is small. Most Prologos propagators are `O(1)` or `O(k)` in the size
of one cell value; even the largest (e.g., SRE structural-unification propagators) are
bounded by the depth of the type expression. This gives reasonable per-propagator R1CS
sizes — an upper bound of ~`2^14` constraints per propagator is realistic, with most being
much smaller.

### 4.4 L3 — Folding stratum

For a program running `T` BSP rounds, each round produces an R1CS/CCS instance. Folding
combines two instances into one with constant size growth:

```
proof_aggregate = fold(proof_aggregate, proof_round_k)
```

Two candidates:

- **LatticeFold+** (Module-SIS, sumcheck-based, faster prover, simpler verifier circuit). The
  preferred choice for production.
- **Lova** (unstructured SIS, linear algebra only, easier to implement, easier to parallelize
  on commodity hardware). The preferred choice for the prototype.

After `T` rounds and a final compression step (e.g., LaBRADOR over the folded accumulator),
the program produces a *single succinct proof of size polylog(T)* with sub-linear verifier
runtime.

The folding stratum is itself a propagator stratum: it watches the per-round proof cell and
fires when a new round's proof appears, folding it into the aggregate. By construction, the
folding pass is sequential across rounds — but *within* a round, all propagator proofs can be
generated in parallel (broadcast pattern, `propagator-design.md` §"Broadcast Propagators").

### 4.5 L4 — Verifier-as-stratum

The verifier is a propagator. Inputs: a folded proof in some cell `proof-cell`, the public
input commitments in their respective cells, a parameter cell holding the public verifier
key. Output: a Boolean cell `verified?-cell`.

```
:propagator verify-zk-proof
  :reads  [proof-cell public-input-cells … vk-cell]
  :writes [verified?-cell]
  :kind   :map
  :stratum verifier-stratum
```

This is significant for two reasons:

1. **No separate verification tool**: Prologos programs that consume external proofs are just
   programs that read a `proof-cell` and write a `verified?-cell`. The verifier is library
   code, not infrastructure.
2. **Self-verification**: a Prologos program `P` can carry its own proof, and the *same*
   propagator network that runs `P` can verify the proof of `P`'s prior execution.

The verifier stratum is non-monotone in its result (the cell becomes `false` if verification
fails — this is a one-shot definite answer, not a lattice value). We model it as an S(+1)
stratum (one above S0) so that downstream propagators can react to verification outcomes,
analogously to S1 NAF reacting to S0 quiescence.

### 4.6 L5 — Self-verifying compiler

Prologos's compiler is itself a Prologos-like propagator network (the self-hosting story is
explicit in PM Track 12: "Cells over parameters" puts compilation state on-network). When
the compiler is invoked with proof generation enabled:

- Each elaboration BSP round produces an L2 proof.
- L3 folding produces a single proof of "the elaborator network reached quiescence on this
  source program with this output."
- The output `.pnet` cache carries the proof alongside the compiled module.

A consumer of the `.pnet` can then either:
- Trust the cache (current behavior)
- Run the L4 verifier to confirm the cache was produced by a correct execution of the
  compiler (no need to re-run elaboration)

This is the killer application. **Compilation becomes verifiable.** The semantics of
`.pnet`-as-cache becomes `.pnet`-as-certificate.

It also unlocks a second user story: *Prologos as a backend for ZK applications*. A user
writes a normal Prologos program. The compiler produces a binary plus a proof that the binary
correctly implements the source's denotational semantics. The user submits the binary + proof
to a verifier (e.g., a blockchain L1 with lattice-friendly verification). The dependent type
system gives correctness guarantees that classical ZK pipelines can't express, while the
lattice substrate gives post-quantum security.

---

## 5. Mantra alignment

The architecture is designed against the design mantra (`on-network.md`), word by word.

**All-at-once.** Per-round proof generation is one aggregated R1CS/CCS instance per BSP round,
not one proof per propagator. All fired propagators in the round contribute simultaneously to
the same aggregated witness. This is structurally identical to the broadcast pattern
(`propagator-design.md` §"Broadcast Propagators"): one prover invocation, N items, one merged
output.

**All in parallel.** Within a round, propagator constraints are independent; they can be
arithmetized and assembled in parallel without coordination. Lova's unstructured-SIS
construction is explicitly chosen because its prover is matrix-matrix multiplication with
bounded-norm entries — embarrassingly parallel and free of global synchronization beyond what
the folding step requires.

**Structurally emergent.** The proof topology mirrors the network topology. A propagator that
reads cells `R` and writes `W` produces constraints over `R ∪ W` — the constraint adjacency is
the propagator-cell adjacency. The Hasse diagram of the cell lattice IS the dependency
structure of the proof DAG. There is no "compile a flat sequence and arithmetize" step;
arithmetization is a Galois bridge installed at each cell domain.

**Information flow.** Proofs live in cells. The output of L2 is a `proof-of-round-k` cell;
the input of L3 is that cell; the output of L3 is a `proof-aggregate` cell; the input of L4
is that cell. All commitments are cell values with monotone merges (commitments accumulate
under set-union; folded accumulators replace under a `last-write-wins` merge that is
stratum-controlled, not racy).

**ON-NETWORK.** No off-network state. The verifier is a propagator. The folding scheduler is a
stratum (`stratification.md` §"Request-Accumulator Pattern"). The encoded R_q^k commitments
are cell values with their own merge function (additive Module-SIS commitment under norm
bound). There is no "verifier program" external to the propagator network; verification is a
sub-network of the same network.

The non-trivial alignment check: **does the proof structure naturally match the Hasse-diagram
optimality claim of the Hyperlattice Conjecture** (`structural-thinking.md` §"The Hyperlattice
Conjecture")? Tentatively yes, with two caveats. If the conjecture is right, the optimal
parallel decomposition of a Prologos computation is the Hasse diagram of its lattice state
space. The proof structure above commits one R1CS/CCS instance per BSP round, where one BSP
round corresponds to one *level* in the diagram. After folding, the proof size is `polylog(T)`
where `T` is the diagram's depth (BSP-round count, equivalently lattice height). If the
conjecture holds, we expect `T = O(log N)` for naturally-parallel programs, giving
`polylog(log N)` proof sizes — empirically near-constant.

Caveat one: the Hyperlattice Conjecture is a claim about *order-theoretic* lattices, not
cryptographic ones. The bridge above (Group A native encoding, Group B opaque-Merkle) does
not import the conjecture's optimality into the cryptographic side wholesale. The
optimality applies to *which* propagators fire in what order; the proof system still pays
its own cost per round.

Caveat two: the `polylog(T)` claim depends on Lova/LatticeFold+ folding being shaped along
the Hasse diagram (Shortcut 6.6). With sequential folding, the proof grows as `O(log T)` ×
constant per fold, which is good but not Hasse-optimal. Hasse-shaped folding is itself a
research item, not a direct deliverable from any current scheme.

Both caveats are testable on the existing benchmark suite once L2 is implemented.

---

## 6. Concrete shortcuts the lattice substrate enables

The architecture's value proposition reduces to a list of *specific algorithmic shortcuts* the
lattice ZK stack can apply when the witness comes from a propagator network rather than from
an arbitrary VM trace. This section is the operative answer to "what does leveraging the
lattice actually buy?"

Shortcuts are listed in rough order of cumulative impact. Each names what is exploited, how
it manifests in the proof, and the dependency (Group A vs. universal).

### 6.1 Monotone update = native additive opening *(Group A)*

Group A cells have `enc(v ⊔ δ) = enc(v) ⊕ enc(δ)` where `⊕` is coord-wise OR/max in `R_q^k`.
Ajtai commitments are additively homomorphic. Therefore:

> "Cell `c` was monotonically updated by `δ` in round `k`"
> ≡ `C_{k+1}[c] − C_k[c] = A·enc(δ) + B·r_δ`, with `‖δ‖ + ‖r_δ‖ ≤ β`

A single Module-SIS algebraic identity. **No R1CS circuit for the merge.** A generic VM
proves "memory was monotonically updated" via integer-comparison circuits per word per step.
Here it is the native statement type Module-SIS is built around.

### 6.2 Within-round writes commute — witness is a *set*, not a *sequence* *(universal)*

BSP fires all enabled propagators simultaneously. Joins are commutative + associative +
idempotent. Witness for round `k` is the multiset of `(destination, delta)` pairs — no
ordering bits.

Quantitative: `M` writes per round in a generic VM commit `O(M log M)` ordering bits; here
`0`. Over `T` rounds with average `M̄` writes, `T·M̄·log M̄` bits removed from the witness.

### 6.3 Idempotence collapses repeated firings *(universal)*

If propagator `p` fires `N` times during execution and writes the same value each time, the
witness collapses to a single "p produced this value, ≥ once" entry. A trace-based proof
would have `N` rows. The cell's *content* is the witness regardless of how many firings
produced it — the structural reason fixpoint engines beat re-execution carries directly into
the proof system.

### 6.4 Quiescence as a single zero-opening *(universal, Group A optimal)*

Proof of "the network reached fixpoint at round `T`":

```
prove: C_T - C_{T+1} = 0          -- single Ajtai zero-opening
plus:  fired-set_T = enabled-set_T -- bitmask equality (Group A)
```

Both checks are `O(1)` in cell count. A generic VM proves quiescence by showing `R` more
no-op rounds at `R · trace-width` constraints. Here it is a constant.

This is the **single most important qualitative shortcut**: termination is detectable
algebraically, not by exhaustion.

### 6.5 Independent sub-networks fold in parallel *(universal)*

Lova/LatticeFold+ fold sequentially by default. Connected components in the propagator DAG
are *independent* (no cells crossing) — their proofs fold in any order, which means a round
splitting into `K` independent sub-networks folds in `log K` parallel steps instead of `K`
sequential ones.

A generic VM trace cannot expose this — the topology was discarded by linearization. Prologos
component structure is explicit and free.

### 6.6 Hasse-diagram-shaped folding *(universal, theoretical)*

The Hyperlattice Conjecture's optimality claim: the Hasse diagram IS the optimal parallel
decomposition. Operationally, shape the folding tree along the diagram's adjacency (Gray-code
traversal, hypercube all-reduce for worldviews). For Boolean lattices, this is `n` rounds of
folding instead of `2^n` — exponential on worldview-heavy proofs.

**Risk**: this is the strongest claim and the riskiest empirical one. It depends on whether a
real program's BSP-round count `T` actually equals the Hasse height of its lattice state
space. Phase 4 benchmarks would resolve it.

### 6.7 Worldview / nogood checks are O(1) bitmask ops *(Group A)*

ATMS worldviews are bit-vectors; nogoods are bit-vectors; subcube containment `(w AND ng) ==
ng` is one AND + one EQ. Proof of "this propagator firing was viable under worldview `w`":
vector equality check across committed nogoods, `O(log #nogoods)` via SIS vector commitments.

Generic VM: hash-set membership query, Merkle-path proofs per check.

### 6.8 Universe-cell compound commitments *(Group A + B, structural fit)*

Prologos already aggregates per-meta values into universe cells indexed by meta-id (PPN 4C
S2). This matches SIS-based vector commitments exactly: one commitment to the universe cell
with `N` components, per-component opening in `O(log N)` via functional commitments (Wee,
Peikert).

A generic VM tracking `N` metas tracks `N` separate memory regions with `N` Merkle paths.
The architectural alignment is striking — Prologos's universe-cell migration *predates* the
cryptographic motivation, suggesting the underlying design pattern is the same in both
worlds.

### 6.9 Stratum boundaries as natural recursion checkpoints *(universal)*

S0, S1 NAF, S(-1) retraction, topology — each stratum is its own BSP fixpoint with its own
proof obligation. Compose with folding. The stratum graph IS the recursion structure.

Saving: in a generic VM, stratum semantics are erased; the prover must rediscover natural
chunk boundaries (or accept arbitrary ones). Here they are given by the language design.

### 6.10 CALM ⇒ proof-time parallelism for free *(universal)*

CALM theorem: monotone computations are coordination-free. Therefore: independent provers on
different machines can each prove a sub-slice of the network and the slices fold consistently.
Large compilations parallel-prove without coordinating on shared trace state.

Generic-VM proofs can be split, but only along arbitrary trace chunks, requiring inter-prover
handshakes for boundary state. CALM gives Prologos the strong guarantee: any monotone slicing
produces consistent proofs.

### 6.11 What is *not* a shortcut

For honest accounting:

- **Group B cells (type / scope / AST)**: no algebraic-correspondence saving. Joins are
  R1CS circuits whose constraint count scales with cell-value depth. We pay roughly the same
  per-fire-function cost a generic VM would pay per-instruction — except that we amortize at
  BSP-round granularity rather than per-instruction.
- **Non-monotone strata (S(-1), S1 NAF)**: no monotone-update shortcut. They use the standard
  "open + recompute + recommit" or OR-proof patterns at full cost.
- **Fire functions themselves**: arbitrary computations on cell values; have to be arithmetized
  even for Group A cells. The shortcut is on the *merge* (free), not the *compute* (full cost).
- **Final proof size**: the `R_q^k` substrate gives ~50-100 KB final proofs regardless of how
  cleanly the witness was generated. No lattice shortcut beats that without a non-PQ wrap.

### 6.12 Compounding cost picture

Per round, the cost decomposition:

```
generic VM trace cost per round
  ≈ (instructions × trace-width) + (memory-access × Merkle-depth) + ordering-bits

Prologos lattice-friendly cost per round
  ≈ Σ_p R1CS(f_p)              -- fire-function arithmetization (compute)
  + Σ_c[Group A] O(1)          -- monotone-update zero-cost (Shortcut 6.1)
  + Σ_c[Group B] R1CS(merge_c) -- per-circuit merge for Group B
  + 0                          -- ordering bits (Shortcut 6.2)
```

The win is concentrated where Group A cells dominate. The more lattice-runtime-shaped the
program (decision narrowing, fact accumulation, worldview reasoning), the larger the
shortcut. Heavy-elaboration programs (lots of dependent-type unification) get less benefit.

Quiescence (Shortcut 6.4) is the only `O(1)`-vs-`O(N)` *qualitative* shortcut. The rest are
constant factors that compound over `T` rounds — meaningful but not asymptotic. Hasse-diagram
folding (Shortcut 6.6) is asymptotic if the conjecture holds.

---

## 7. RISC0 feature-parity gap

Treating RISC0 as a reference checklist, what would lattice-ZK schemes need to provide to
substitute for it (independent of the Prologos-specific shortcuts above)?

### 7.1 What RISC0 delivers

1. Universal arithmetization (RISC-V trace → AIR, given for free)
2. Sequential-trace soundness (PC, register file, memory transitions)
3. Merkleized RAM with succinct read/write proofs
4. Recursion (STARK-of-STARK, eventually Groth16-wrapped)
5. Sub-KB final proofs after the EC wrap
6. Production toolchain
7. Public/private I/O segregation, deterministic execution

### 7.2 Lattice-ZK's coverage

| RISC0 deliverable | Lattice-ZK status |
|---|---|
| Arithmetization given (1) | **Missing.** No lattice-ZK-VM ships an ISA-trace → R1CS frontend. The constraint-system prover (LaBRADOR) exists; the VM frontend doesn't. |
| Sequential-trace IOP (2) | **Building blocks present.** Hachi + ring-switching gives sumcheck-over-rings; Brakedown-over-Galois-rings gives AIR-style. Not yet packaged as a STARK-equivalent. |
| Merkleized RAM (3) | **Substrate available.** SIS-based vector commitments (Wee, Peikert) provide succinct random-access opening natively — arguably better than Merkle. Not packaged into a memory model. |
| Recursion (4) | **Solved.** LatticeFold+ and Lova give folding with constant per-fold overhead. |
| Sub-KB proofs (5) | **Not achievable post-quantum.** Lattice-ZK proofs are 50-100 KB. RISC0's 200-byte size comes from a final Groth16 wrap (EC crypto). Wrapping a lattice proof in Groth16 kills PQ security at that hop. |
| Toolchain (6) | **Research-grade.** Out of scope for this document. |
| ZK + I/O segregation (7) | **Standard.** All listed schemes are NIZK in ROM via Fiat-Shamir. |

### 7.3 Three engineering gaps and two research gaps

**Engineering** (no theoretical obstacle):

- **G1. Lattice ZK-VM frontend.** ISA trace → R1CS-over-`R_q`, fed to LaBRADOR/LatticeFold+.
  Plausible direct port of Jolt's lookup-arg style.
- **G2. AIR-over-rings backend.** Wrap Hachi + ring-switching as an AIR prover.
- **G3. Memory-commitment standard.** Pick: Merkle-over-Poseidon vs. SIS vector commitments.

**Research** (open):

- **R1. Sub-KB post-quantum proofs.** Open problem. Either accept 50-100 KB or accept a
  non-PQ final wrap. No middle ground today.
- **R2. Lattice-friendly *small-state* recursive verifier.** LatticeFold+ improved this
  materially; whether it is small enough for "verifier-as-a-propagator-on-the-network"
  (ZK-Prologos's L4) is an empirical open question — no published benchmark fits this use
  case yet.

### 7.4 Implication for ZK-Prologos

ZK-Prologos *does not need* G1-G3 closed, because it does not compile to a generic ZK-VM. It
arithmetizes the propagator network's execution shape directly (L2 layer of the architecture).
The shortcut catalogue (§6) lists what that direct-arithmetization saves over going through a
generic VM.

R1 affects ZK-Prologos like everyone else: ~50-100 KB final proofs. Acceptable for the
application domain.

R2 is the load-bearing open question for the L4 verifier-as-stratum vision. If the verifier
circuit is too large to fit in a propagator, "verifier-as-stratum" downgrades to
"verifier-as-FFI-call" — still on-network in spirit but losing the elegance.

---

## 8. Open questions and falsification paths

This section enumerates what could break the design. Each item names the risk, the
falsification test, and a fallback if it fails.

### 8.1 The encoding for term / type lattices may not be norm-bounded

**Risk**: Prologos type cells hold structural type expressions of unbounded depth (recursive
types, dependent types). Encoding into `R_q^k` with `k` fixed forces a depth bound; encoding
with `k` variable defeats Module-SIS norm bounds because norms grow with depth.

**Falsification**: implement L1 for one non-trivial type lattice (e.g., the type-cell lattice
that holds `expr-Pi` / `expr-Sigma` / `expr-Open` heads). Measure norm of `enc(t)` for the
`examples/` corpus's typical types. If norms exceed the LaBRADOR norm budget on the existing
acceptance file (`examples/2026-04-17-ppn-track4c.prologos`), the encoding is wrong.

**Fallback**: encode types as *Merkle commitments to ASTs* rather than as direct vectors.
This loses additive homomorphism on type joins (we'd commit to the unified type, not derive
its commitment from operands), but it scales to unbounded type expressions. The proof
becomes "I know AST `t_1`, AST `t_2`, and AST `t_3` such that `t_3 = unify(t_1, t_2)`" — still
proven via LaBRADOR but with the unification logic explicit in the circuit.

### 8.2 Non-monotone strata may not arithmetize cleanly

**Risk**: S(-1) retraction (`stratification.md` §"S(-1) retraction") and S1 NAF are non-
monotone. Their natural statement is "the cell value *decreased* on the lattice" or "no
fork succeeded under accumulated constraints." Module-SIS commitments are additively
homomorphic but the additive operation only reaches *higher* lattice elements (norms grow,
the lattice climbs). Going *down* requires a different proof structure.

**Falsification path for S(-1)**: model retraction as `c_{after} = c_{before} ⊓ viable-set`.
The meet operation is *not* the additive commitment operation. Try: prove via *opening* the
old commitment, computing the meet in plaintext, and *re-committing*. This is a fresh
commitment, not an incremental update — it costs a full LaBRADOR proof per retraction event.

**Falsification path for S1 NAF**: model NAF as a *disjunctive proof* — "for each forked
branch, here is a proof that the branch reached contradiction." This is the standard ZK
trick (an OR-proof; CDS protocol). Sums to one `LaBRADOR proof per branch + 1 OR-aggregator`.

**Fallback**: if neither path is concretely efficient, restrict the verifiable subset of
Prologos to S0-only (monotone) computations. This still covers a huge fraction of useful
programs (anything that doesn't use NAF or assumption retraction), and lets the architecture
ship while research continues on the non-monotone strata.

### 8.3 The "joincheck" protocol may not exist

**Speculation in §3.4**: a sumcheck-analog where the aggregate is `⊔` (idempotent) rather than
`+`. The structural property that makes this potentially shorter than sumcheck is that
`⊔_{x ∈ S} f(x) = ⊔_{x ∈ S'} f(x)` whenever `f(S) = f(S')` as sets — repeated terms collapse.

**Falsification**: try to construct a single-round joincheck for monotone-set lattices. If
the soundness reduction goes through (probably to MSIS via a Schwartz-Zippel-over-rings
argument), the protocol exists; if not, we use sumcheck on the characteristic-vector
encoding and pay an `O(log |S|)` factor we hoped to avoid.

**Fallback**: standard sumcheck on the bit-vector encoding works correctly even if joincheck
fails. The cost is a constant factor on per-round prover time, not a fundamental obstacle.

### 8.4 Quiescence as `O(1)` proof obligation

**Speculation in §3.4**: prove "the network reached fixpoint" by showing
`commitment_{round k+1} − commitment_{round k} = 0` for the canonical aggregate cell. The
additive homomorphism makes this a single zero-opening — `O(1)` proof.

**Risk**: this proves "no commitment changed" but not "no propagator *would* fire." If the
scheduler missed scheduling a propagator (a bug), the cell wouldn't change but the network
isn't truly quiescent. We need the proof to also assert that *all enabled propagators were
fired*.

**Falsification**: instrument the scheduler to emit a "fired set" for each round (already
trivially available via the worklist). The quiescence proof becomes `commitment_diff = 0
AND fired-set = enabled-propagators-set`. The latter is a set-equality check — also `O(k)`
where `k` is the number of propagators, fully arithmetizable.

### 8.5 Concrete proof sizes may not be competitive

**Risk**: lattice-based proofs are ~50-100 KB. Groth16 is ~200 bytes. Many production ZK use
cases want sub-1KB proofs. ZK-Prologos is post-quantum but loses on size.

**Mitigation**: this is a known and accepted trade-off in the lattice-ZK community. The
prototype targets correctness and the structural-identity claim, not size optimization.
Production tuning (smaller `q`, custom NTT, hardware acceleration) is downstream work.

**Crucial check**: ensure the *recursion* / folding overhead doesn't blow up. Lova's per-fold
size growth must be measured on real round counts (a typical Prologos elaboration does
`O(100)`-`O(1000)` BSP rounds). LatticeFold+ benchmarks suggest we should land in the 50-200
KB range for the final aggregate, which is acceptable for the application domain.

### 8.6 Random-oracle / Fiat-Shamir model assumptions

**Risk**: most lattice-based SNARKs (LaBRADOR, LatticeFold+, Greyhound, Lova) are non-
interactive in the random oracle model via Fiat-Shamir. Recent work (e.g., the "weak
Fiat-Shamir" attacks) suggests careful instantiation with cryptographic hash functions.
Prologos must specify the hash function (SHA-3 or similar) and document the soundness
boundary clearly.

**Mitigation**: document the assumption explicitly. Allow the hash to be a swappable cell-
indexed parameter so that future post-quantum hash standards can be plugged in.

### 8.7 Implementation realism

**Risk**: this is a research-grade undertaking. A naïve estimate of effort: 6-12 months for a
research prototype, multi-year for a production-grade system. The Prologos team is small; a
realistic plan must phase the work to deliver value at each step rather than gating on the
full architecture.

**Mitigation**: the phasing in §9 below ships incremental value:
- Phase 1: any single cell domain encoded → proof of concept
- Phase 2: per-fire arithmetization → already enables non-aggregated proofs
- Phase 3: BSP-round prover → first useful artifact (a "verifiable Prologos run")
- Phase 4: folding → succinctness
- Phase 5: non-monotone → completeness
- Phase 6: verifier-stratum → self-hosting

Each phase produces something demoable. We can stop at any point and have a working result.

---

## 9. Phased plan

The plan is phased so each phase delivers a runnable artifact and a falsifiable claim. Phase
ordering follows the architecture-layer ordering (L0 → L5).

### Phase 0 — Foundations (research, no code)

**Goal**: select substrate, lock parameters, draft the encoding catalogue.

- Choose `R_q` parameters: `(q, d)` for ~128-bit post-quantum security. Track the
  LatticeFold+ choice as the default; document deviation.
- Choose backend library: evaluate `latticefold` (Nethermind, Rust), `lova` (lattirust, Rust),
  `lazer` (IBM, C). Decision criteria: license, build complexity, FFI surface, active
  maintenance.
- Draft `encoding-catalogue.md`: for each Prologos cell domain, specify `enc`, `commit`,
  `merge-in-R_q`, and norm growth. Mark each entry "trivial / hard / open."
- Acceptance: a written spec that lets Phase 1 begin without further upstream research.

**Falsifies**: nothing — pure design.

### Phase 1 — L0 substrate + L1 first bridge (proof of concept)

**Goal**: one Prologos cell domain encoded into Module-SIS commitments, end-to-end.

- Implement Racket FFI to the chosen backend (e.g., `latticefold-rs` via Racket FFI).
- Pick the simplest domain: monotone-set with bitmask backing (worldview cells). Implement
  `enc`, `commit`, the bridge propagators α/γ.
- Acceptance file: a `.prologos` program that allocates a worldview cell, accumulates
  `{a, b, c}` into it across BSP rounds, and produces a Module-SIS commitment to `{a,b,c}`
  that round-trips through γ.
- Test: the existing test fixture pattern (`test-support.rkt`) plus a new
  `tests/test-zk-bool-bridge.rkt`.

**Falsifies**: §8.1 for the simplest case (Boolean lattice). If even bitmasks don't fit, the
whole approach fails.

### Phase 2 — L2 per-fire arithmetization

**Goal**: prove a single propagator's fire function via LaBRADOR.

- Pick three representative fire functions: `copy-value`, `set-union-merge`, `threshold-fire`.
- Express each as an R1CS instance over `R_q`.
- Generate per-fire LaBRADOR proof; verify it.
- Document: per-fire R1CS sizes, prover time, proof size.

**Falsifies**: the implicit assumption that fire functions are "small enough" to arithmetize
without absurd circuit blow-up. Concrete budgets: ≤2^14 R1CS constraints per fire function.

### Phase 3 — L2 per-round prover

**Goal**: a single LaBRADOR proof for an entire BSP round.

- Aggregate all per-fire constraints fired in one round.
- Prove the aggregated R1CS instance.
- Verify the proof.
- Acceptance file: a `.prologos` program that runs N BSP rounds and produces N proofs (one
  per round, no folding yet).

**Falsifies**: assumption that aggregation doesn't blow up the constraint count
super-linearly. Budget: ≤2^20 R1CS constraints per round for typical programs.

### Phase 4 — L3 folding stratum

**Goal**: succinct proof across many rounds.

- Integrate Lova first (simpler, parallelizable, no NTT). Then optionally LatticeFold+ for
  production.
- Implement the folding stratum as a `register-stratum-handler!` registration
  (`stratification.md` §"Request-Accumulator Pattern").
- Acceptance file: a `.prologos` program that runs `T = 100` BSP rounds and produces a single
  folded proof of size `polylog(T)`.

**Falsifies**: the polylog claim. If the folded proof is `O(T)`, folding has degenerated and
we're back to per-round proofs.

### Phase 5 — Non-monotone strata

**Goal**: extend coverage to S(-1) retraction and S1 NAF.

- Implement the "open + recompute + re-commit" path for retraction.
- Implement OR-proofs (CDS-style) for NAF disjunctive cases.
- Acceptance file: a `.prologos` program exercising NAF (e.g., `not p(X) :- ...`).

**Falsifies**: §8.2's fallback path. If even open-recommit-recommit is infeasible for typical
retractions, we may need to restrict the verifiable subset.

### Phase 6 — L4 verifier stratum

**Goal**: verification is a propagator on the network.

- Implement `verify-zk-proof` propagator.
- Test: a Prologos program that consumes its own proof and writes `verified? := true`.
- Document the API: how user code installs verifier propagators on its own cells.

**Falsifies**: the on-network claim. If the verifier can't fit in a propagator (e.g., needs
external state), the architecture has a leak.

### Phase 7 — L5 self-verifying compiler (long horizon)

**Goal**: `.pnet` caches carry proofs of compilation correctness.

- Wire L3 folded proofs into the `.pnet` serialization format
  (`pnet-serialize.rkt`).
- On `.pnet` load, optionally run L4 verification before trusting the cache.
- Acceptance: the standard library compiles with proofs; consumers can verify before linking.

**Falsifies**: the "no compilation tax" claim end-to-end. We need the compiler-with-proofs
runtime to be at most ~10× the no-proof runtime; if it's 1000×, the practical story
collapses (the architecture is still sound, but the deployment value drops).

### Cross-cutting deliverables

- **Microbenchmarks** at each phase: proof size, prover time, verifier time, on the existing
  `benchmarks/comparative/` corpus.
- **Mantra audit** at each phase boundary (`workflow.md` §"VAG / principles gate / mantra
  audit MUST be ADVERSARIAL"). Document column 1 (catalogue) and column 2 (challenge) for
  every architectural decision.
- **NTT model** of the new propagators (`workflow.md` §"NTT model REQUIRED for propagator
  designs"). Each new bridge propagator must be expressible in NTT speculative syntax with
  `:reads` / `:writes` / `:component-paths` declarations.
- **Test discipline**: every phase has a `test-zk-{phase}.rkt` file using the shared fixture
  pattern. No phase ships without tests (`workflow.md` §"Dedicated test phase is MANDATORY").

---

## 10. What this enables (vision)

If even Phase 4 lands successfully, the language acquires capabilities that classical ZK
pipelines cannot match:

### 10.1 Verifiable elaboration

A Prologos type-check is a fixpoint computation on the propagator network. Today, the
compiler produces a `.pnet` cache and a downstream consumer must trust that the cache was
produced by a correct execution. With ZK-Prologos, the cache carries a proof: *the elaborator
produced this output starting from this source program, and the proof is sub-linear in the
elaboration's BSP-round count.*

This means: dependent type checking becomes a *delegatable* computation. A user can elaborate
a large program on a powerful server and ship the result + proof to a constrained client; the
client verifies in `polylog(T)` time and trusts the result without re-running elaboration.
This is novel — current dependent-type pipelines (Coq, Agda, Lean, Idris) require the
verifier to re-run the type-checker.

### 10.2 ZK applications with dependent types

Classical ZK SNARK pipelines (Circom, Noir, Cairo) use weakly-typed circuit DSLs. Bugs
are common; whole subfields exist to find them ([eprint 2025/916](https://eprint.iacr.org/2025/916)
on automated verification of ZK circuit consistency). Prologos's dependent type system
already gives correctness guarantees beyond what those DSLs can express. With ZK-Prologos as
the proof backend, *the type system and the proof system are the same artifact*. A program's
type is its specification; the proof certifies that the program meets the specification *and*
ran correctly. This collapses the "spec / impl / proof" three-step into one.

### 10.3 Proof-carrying code, natively

The `.pnet` cache becomes proof-carrying code in the precise [Necula 1997] sense: a binary
artifact paired with a proof of safety properties. Because the proof is succinct and the
verifier is a propagator, *any Prologos installation can verify any other's outputs* with no
additional infrastructure. Module distribution becomes trustless.

### 10.4 Lattice-on-lattice (qualified)

The Hyperlattice Conjecture (`structural-thinking.md`) claims lattices are the right
substrate for *all* computation. ZK-Prologos pairs:

- The computational lattice (cells with `⊔`-merges) driving execution.
- The cryptographic lattice (Module-SIS over `R_q`-modules) driving verification.
- For Group A cells, an honest Galois bridge connecting the two.
- For Group B cells, an opaque-Merkle commitment with no algebraic correspondence.

This is a *partial* realization of "lattice-on-lattice." The structural overlap is real
where it exists (Group A) and absent where it does not (Group B). The architecture stakes a
working system on the conjecture's *operational* claim (BSP rounds = Hasse-diagram levels)
without claiming to *prove* the conjecture or to algebraically unify the two senses of
lattice. Earlier drafts of this document overstated this; the corrected framing is more
modest but still substantial.

### 10.5 Post-quantum from the ground up

Module-SIS is conjectured to be post-quantum hard (no known quantum algorithm beats classical
for SIS). RISC0 and other elliptic-curve-based ZK systems are not. For long-horizon
infrastructure (cryptocurrency, archival proofs, multi-decade contracts), this matters.
Prologos has so far made no commitment about cryptographic security; ZK-Prologos closes that
gap by inheriting Module-SIS's post-quantum security uniformly across the stack.

---

## 11. References

### Lattice-based ZK proof systems

- Beullens, Seiler. *LaBRADOR: Compact Proofs for R1CS from Module-SIS*. CRYPTO 2023.
  [Springer link](https://link.springer.com/chapter/10.1007/978-3-031-38554-4_17)
- Nguyen, Seiler. *Greyhound: Fast Polynomial Commitments from Lattices*. CRYPTO 2024.
  [eprint 2024/1293](https://eprint.iacr.org/2024/1293)
- Albrecht, Fenzi, Lapiha, Nguyen. *SLAP: Succinct Lattice-Based Polynomial Commitments from
  Standard Assumptions*. EUROCRYPT 2024. [eprint 2023/1469](https://eprint.iacr.org/2023/1469)
- Boneh, Chen. *LatticeFold: A Lattice-based Folding Scheme*. ASIACRYPT 2025.
  [eprint 2024/257](https://eprint.iacr.org/2024/257)
- Boneh, Chen. *LatticeFold+: Faster, Simpler, Shorter Lattice-Based Folding for Succinct
  Proof Systems*. CRYPTO 2025. [eprint 2025/247](https://eprint.iacr.org/2025/247)
- Fenzi, Pham, Nguyen. *Lova: Lattice-Based Folding Scheme from Unstructured Lattices*.
  ASIACRYPT 2024. [eprint 2024/1964](https://eprint.iacr.org/2024/1964)
- *Hachi: Efficient Lattice-Based Multilinear Polynomial Commitments over Extension Fields*.
  [eprint 2026/156](https://eprint.iacr.org/2026/156)
- *Neo: Lattice-based folding scheme for CCS over small fields*.
  [eprint 2025/294](https://eprint.iacr.org/2025/294)
- Albrecht et al. *The LaZer Library: Lattice-Based Zero Knowledge and Succinct Proofs for
  Quantum-Safe Privacy*. CCS 2024. [eprint 2024/1846](https://eprint.iacr.org/2024/1846)

### Foundational primitives

- Baum, Damgård, Lyubashevsky, Oechsner. *More Efficient Commitments from Structured Lattice
  Assumptions*. [eprint 2016/997](https://eprint.iacr.org/2016/997)
- Wee, Wu. *Succinct Vector, Polynomial, and Functional Commitments from Lattices*.
  [NTT Research preprint](https://ntt-research.com/wp-content/uploads/2023/01/Succinct-Vector-Polynomial-and-Functional-Commitments-from-Lattices.pdf)
- Peikert, Pepin, Sharp. *Functional Commitments for All Functions, with Transparent Setup
  and from SIS*. [PDF](https://web.eecs.umich.edu/~cpeikert/pubs/func-com.pdf)

### Implementations

- `latticefold` (Nethermind, Rust) — [GitHub](https://github.com/NethermindEth/latticefold)
- `lova` (lattirust, Rust) — [GitHub](https://github.com/lattirust/lova)
- LaZer library (IBM) — [Research page](https://research.ibm.com/publications/the-lazer-library-lattice-based-zero-knowledge-and-succinct-proofs-for-quantum-safe-privacy)

### Verification of ZK circuits

- *Automated Verification of Consistency in Zero-Knowledge Proof Circuits*.
  [eprint 2025/916](https://eprint.iacr.org/2025/916)

### Prologos internal documents

- `docs/research/2026-03-28_MODULE_THEORY_LATTICES.md` — propagator network as l-module over
  endomorphism ring (`§2`), four sub-rings (`§3`), Krull-Schmidt uniqueness.
- `docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md` — Boolean lattice = hypercube
  Hasse diagram; bitmask-tagged worldviews.
- `docs/research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md` — Galois bridges between lattices.
- `docs/research/2026-03-28_PROPAGATOR_TAXONOMY.md` — propagator kinds, set-latch.
- `docs/research/2026-03-21_CATEGORICAL_STRUCTURE_FIVE_SYSTEMS.md` — bifibrations over
  stratification poset.
- `.claude/rules/on-network.md`, `propagator-design.md`, `stratification.md`,
  `structural-thinking.md` — operational discipline.
- `docs/tracking/principles/GÖDEL_COMPLETENESS.org` — termination guarantees per stratum.

---

## 12. Decision points needing user input

Before Phase 0 begins, the following choices need to be made by the project lead:

1. **Backend selection**: `latticefold` vs `lova` vs `lazer`. Tradeoff: LatticeFold+ is
   strongest concretely, Lova is simplest to implement, LaZer is most production-oriented.
   Recommendation: **start with Lova** for the prototype (Phase 1-3), migrate to
   **LatticeFold+** for Phase 4 onward when folding becomes critical.

2. **Scope of verifiable subset**: do we target full Prologos (including NAF, retraction,
   topology mutation) from day one, or restrict to S0-monotone programs initially? The
   restricted subset still covers most of the standard library and all type-checking;
   non-monotone work is Phase 5.
   Recommendation: **S0-monotone first**, expand later.

3. **Encoding granularity**: per-cell commitments (one Module-SIS commitment per Prologos
   cell) vs per-domain (one commitment per cell *domain*, with components keyed by cell-id).
   Tradeoff: per-cell is simpler conceptually; per-domain matches the existing universe-cell
   compound-cell architecture (`pipeline.md` §"Per-Domain Universe Migration").
   Recommendation: **per-domain**, integrating with the existing universe-cell migration.

4. **Self-verification depth**: do we aim for full self-hosting (the Phase 0 compiler verifies
   its own elaboration) or stop at Phase 4 (programs verifiable, compiler not yet)?
   Recommendation: **stop at Phase 4 initially**; Phase 7 is multi-year and gates on
   Phase 5-6 lessons.

These choices are explicitly *deferred* — not made in this document. They are the natural
checkpoints at which the project lead's judgment is required.

---

*End of document.*

