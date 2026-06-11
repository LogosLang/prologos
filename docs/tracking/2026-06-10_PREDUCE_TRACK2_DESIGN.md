# PReduce Track 2 Design — IN-Fragment Rule Ladder (D.2 §5 partition)

**Status**: DESIGN OPENING (2026-06-10, autonomy loop iteration 17) — §1 awaits the
owner ruling; §2-§4 derive from already-owner-signed locks; §5 (fine NTT) and the
critique rounds follow. **Exit criterion (owner-bound, D.2)**: not done until the
guard passes AND guarded β fires AND the PRN §2 confirmation is recorded.

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| D | This design doc through critique rounds + fine NTT | 🔄 | opened iter 17 |
| 0 | RHS effect-safety dispatch guard (BLOCKING — D.1 §6.2 Option 2) | ⬜ | spec §2 |
| 1 | Arithmetic seed (~12-20 literal-fold rules) | ⬜ | §3 |
| 2 | δ (definition unfolding) | ⬜ | |
| 3 | Guarded β | ⬜ | the guard's first real exercise |

## §1 The HVM2 benchmark-posture decision — OWNER PACKAGE (the D.2 guard discharged)

Per the owner's 2026-06-10 deferral: "Track 2's design doc MUST open with the HVM2
benchmark-posture decision." The full design space, in prose:

**What HVM2 is, for this decision**: HVM2 (Higher-order Co.) is a standalone
massively-parallel runtime that compiles λ-terms to interaction combinators and
runs β-reduction with optimal-reduction-style sharing on CPU/GPU. It is the
strongest public existence proof that interaction-net evaluation scales in
practice. It is NOT a compiler-internal reducer: it owns its whole heap, has no
type checker in the loop, no elaboration interleaving, no effect system of our
shape, and measures THROUGHPUT of pure reduction — while PReduce's reducer runs
INSIDE elaboration on a propagator network, where the §5.8 phase-accounting
baseline says reduction is ~75% of in-driver phase time on reduction-heavy files.

**Posture A — benchmark target.** We declare HVM2 numbers (reductions/sec on
shared workloads like church-fold benchmarks) a comparison bar for Tracks 2-4.
What it buys: an external, un-gameable yardstick; prestige-grade evidence if we
ever approach it. What it costs: the comparison is apples-to-oranges TODAY in
both directions (they have no typing/elaboration overhead to carry; we have no
GPU lowering until SH/Zig work matures) — so early numbers would be
discouraging-by-construction and invite exactly the denominator confusion the
§5.8 reconciliation just untangled. Risk: the bar distorts design choices toward
HVM2's affine-sharing model, which conflicts with our QTT multiplicities and
worldview semantics in ways the D.2 census didn't price.

**Posture B — reference architecture.** We use HVM2 (and interaction-net
literature generally) as a NAMED design reference: the Track 2 ladder's rule
shapes get explicit correspondences (annihilation/commutation pairs ↔ our
relate-propagator pairs; duplication nodes ↔ e-class sharing via hashcons;
their redex queue ↔ our BSP worklist). What it buys: design discipline — every
ladder rule names its IN-theoretic role, which is cheap now and keeps the
"IN-fragment" claim honest; it also sets up the PRN §2 confirmation (reduction-
as-DPO) cleanly. What it costs: a correspondence section to maintain (~hours,
not days); the risk is cargo-culting IN idioms where the lattice substrate has
better-native answers (the SM2/SM4 locks are already non-IN in load-bearing
ways — merge-as-order has no IN analog).

**Posture C — defer again, with a concrete trigger.** No HVM2 commitments in
Track 2; re-open the decision when a named measurement exists. The natural
trigger: Track 8's retirement case (which already requires the measured
reduction-share improvement per the charter §5.8) — at that point we have OUR
numbers on OUR workloads, and an HVM2 comparison becomes interpretable rather
than aspirational. What it buys: zero distraction; no premature bar. What it
costs: the design loses the cheap discipline of posture B's correspondences,
and a third deferral of the same question starts to look like avoidance.

**Recommendation (loop)**: **B for design + C for benchmarking** — adopt the
reference-architecture correspondences in this doc (cheap, disciplines the
ladder, feeds PRN §2), and bind the BENCHMARK question to the Track 8 trigger
(where the §5.8 instruments make the comparison meaningful). Posture A alone is
premature on the evidence above. ⚠ OWNER — this is your deferred decision;
the loop proceeds on B+C as OWNER-PROVISIONAL (reversal path: the
correspondence subsection is additive prose; deleting it reverts B; A can be
adopted at any later point without rework).

## §2 Phase 0 — the RHS effect-safety dispatch guard (owner-signed; D.1 §6.2 Option 2)

The lock: the rule-application core — the SINGLE choke point that instantiates
any RHS — enforces that an RHS may not DELETE, DUPLICATE, or REORDER a captured
subterm whose class is effect-bearing. BLOCKING: must exist and pass before β
(the first generic rule) ever fires; β is its first real exercise.

Realization sketch (to be hardened in the critique rounds):
- The choke point is NEW code (Track 2 builds rule application; there is no
  legacy RHS instantiator to retrofit) — `apply-rule` in a new
  `rule-dispatch.rkt`: match LHS pattern → bind captured vars to child classes
  → instantiate RHS → intern + union result with the matched class.
- The guard runs INSIDE apply-rule, between bind and instantiate: for each
  captured variable, count its occurrences in LHS vs RHS templates (statically
  derivable per rule at REGISTRATION — compute once, store on the registry
  entry as a derived `capture-profile`); at APPLY time, consult the bound
  class's effect-bearing status (the :opaque facet / the effectful-occurrence
  provenance from iteration 13's floor). RHS-count < LHS-count = DELETE;
  > 1 = DUPLICATE; order changes among effectful captures = REORDER. Any of
  the three on an effect-bearing class → the rule does NOT fire for that match
  (structural skip + a counted diagnostic; NOT an error — pure rules on pure
  matches proceed).
- Tier-2 rules (apply-fn closures, no RHS template): the capture-profile is
  underivable — PESSIMISTIC: closure-resident rules do not fire on matches
  containing effect-bearing captures at all (same pessimism+counter mechanism
  as the head classification; the named upgrade is per-rule declared profiles).
- Tests precede the seed: a synthetic effectful class + a deleting rule + a
  duplicating rule + a reordering rule — all three skip; pure equivalents fire.

## §3 Phase 1 — the arithmetic seed (D.2: ~12-20 ops, all head-specific tier-1)

Candidate enumeration (literal folds; LHS = head op with literal-class children;
RHS = computed literal; all `'forward`, `'literal-fold` confluence class,
write-target `'best+alts`, stratum `'s0`):
int+ int- int* int/ int-mod (5) · int comparisons lt/le/gt/ge/eq (5) ·
bool and/or/not folds (3) · nat suc/pred folds on literals (2) · generic-op
folds where both children are same-family literals (defer cross-family to the
coercion-aware round — the numeric-join precedent applies) (≤5).
Each registers into the SM3 registry under the kernel pseudo-module via the
SAME register-rule path the seed pour uses; dispatch reads rules-for-tag.

## §4 Dispatch — broadcast-over-tag-matched-rules (owner D6, carried)

Ingestion (a term position elaborates → intern via eclass-graph; the position's
:eclass-link facet written) → the class's head tag looks up `rules-for-tag` →
the matched rule set fires as ONE broadcast per (class × stratum) with
result-merge = the SM2 write-target semantics (ACI merge-as-answer;
order-independent under critical pairs by construction — the lock's semantic
argument; NO perf claim attaches, so no microbench obligation here). Per-rule
installs remain the heterogeneous fallback.

## §5 Fine-grained NTT model — TO WRITE in the design rounds (PIR §15 default)

Cells (registry universe, e-class product, attr-map facets), lattice
declarations (all six locked merges), the dispatch propagator skeleton, and the
Phase-0 guard's place in the fire path — expressed in NTT speculative syntax
with the correspondence table extended from D.1 §8. Owed BEFORE Phase 1 lands.

## §6 Open questions for the critique rounds

1. Ingestion timing: intern at elaboration (every typed position) vs at first
   rule match (lazy)? The D5 singleton-fraction data (probe still queued) would
   answer this empirically; without it, lazy is the conservative default.
2. The seed's literal representation: expr-int values are PCE-encodable today;
   nat literals as suc-chains explode class counts — fold to expr-int-backed
   canonical forms first?
3. Guard diagnostics surface: counted skips need an observability home
   (PERF-COUNTERS line vs a :warnings facet entry).
