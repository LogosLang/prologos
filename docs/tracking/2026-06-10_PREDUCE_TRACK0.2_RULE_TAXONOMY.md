# PReduce Track 0.2 — Rule-Property Taxonomy (D.2)

**Created**: 2026-06-10 · **Status**: CLOSED 2026-06-10
**Inputs**: Track 0.1 D.1 (all locks binding); panel `wf_4d3d2df9-a4c` (propose + adversarial
critique + synthesis; grounded at main HEAD 533bfcab); owner decisions (partition + HVM2).
**Deliverables** (per Master Track 0.2 row): the 10-kind rule-property table; IN-fragment
promotion analysis; the Track-N partition.

## §1 Grounding corrections (all VERIFIED, file:line in panel record)

- **G0**: the Master's "~50 whnf match arms" is stale by ~9× — `whnf-impl/match`
  (reduction.rkt:1390-3027) has **461 top-level arms over 235 head constructors**.
  Taxonomy is by RULE FAMILY. (Master amendment in this commit.)
- **G1** β = ONE arm (:1393) — GENERIC/variable-binding; F-B applies directly.
- **G2** δ = ONE arm (:3013-3018) — single-resolution mnr cascade; substitution-free;
  multi-clause defns compile to ONE body (single-rule-per-name CONFIRMED). expr-meta
  unfolding (:3022-3024) is δ-like with elaboration-state input.
- **G3** ι: built-in eliminators + user expr-reduce. TWO verified overlap loci: dual Nat
  representation (:1401-1409) and user clause overlap (compiled to ordered first-match
  trees — clause ORDER is semantic). ι binds constructor FIELDS: field-drop deletes,
  natrec duplicates `step` (:1403-1404) — **the §6.2 effect-safety guard must cover ι
  instantiation, not only β**.
- **G4** structural decomposition: ZERO whnf arms — already propagator-native (28
  ctor-descs on the typing network).
- **G5** arithmetic = the bulk (~250 of 461 arms incl. ~100 collection ops); generic-op
  coercion overlap is confluent via type-tag JOIN (:1147-1153) — benign.
- **G6** trait dispatch: only on the narrowing path; `resolve-generic-narrowing-candidates`
  (constraint-propagators.rkt:199-215) returns a candidate LIST = **the first genuine
  SATURATE/+alts-shaped producer in the codebase** (scaffold ledger item 6 evidence).
  Red flag noted: find-fqn-for-local-name suffix scan (:218-230, polling-adjacent).
- **G7** NAF: zero whnf arms; routes to the EXISTING S1 stratum — zero new kinds confirmed.
- **G8** capability-aware: NOT a rewrite kind — a classification DIMENSION (SM5 §6.2).
- **G9** session-typed: zero whnf arms — a boundary protocol; checking is already
  propagator-native; execution routes per §6.3.
- **G10** FFI: one arm family (:1431-1442); the Racket proc runs INSIDE whnf (:1438) —
  F-A live; `effectful?`=pessimistic; pure-FFI annotation = named Track 7 upgrade.
- **11th-kind disposition**: reflective net/logic primitives (reduction.rkt:2606-2976)
  fold into Opaque/FFI routing (the lean; no 11th row).

## §2 The taxonomy table

| Kind | Enrichment | Axis-1 tag(s) | Guard exposure | Write-target | Stratum/tier | Regime | Tier | effectful? | nac-spec | Q8 |
|---|---|---|---|---|---|---|---|---|---|---|
| β | non-enriched IF binder-canonical | IN-fragment (CONDITIONAL) | **GENERIC** (F-B direct) | best | S0 r1 | ground-admissible | declarative shape; subst core | pure; guard MANDATORY first | none | **YES — primary carrier** |
| δ | non-enriched | IN-fragment | head-specific | best | S0 r1 | contextual-leaning (consumes module env; ground iff keyed by name×body-hash; ledger-16 upgrade) | tier-1 by instance | pure (inherits) | none | mild (expansive; exercises Q-argmin) |
| ι built-in | confl-by-constr EXCEPT dual-Nat pairs | Confl-by-constr + Adhesive-DPO (dual-rep) | head match, **generic BINDING** (field-drop; step-dup) | best | S0 r1-2 | ground | tier-2 | pure; guard covers field-drop/dup | none | partial |
| ι user | adhesive-DPO; ordered trees | Adhesive-DPO; clause order = registry datum | head match, generic bindings | best today; +alts iff order relaxed | S0 r2 (pairs by JOIN, F4) | ground | **tier-1** (arm bodies are AST data) | pure + guard | CONDITIONAL implicit-NAC (see §4) | yes via arm bodies |
| structural decomp | enriched; preserves + | Confl-by-constr | head-specific | best | S0 (already native) | ground | tier-2 (metadata-only) | pure | none | no |
| arithmetic (+collections) | non-enriched; coercion JOIN | IN-fragment | head-specific; ZERO binders | best | S0 r1 | **ground** (cleanest §7.2 admission) | literals describable; collections tier-2 | pure | none | no |
| trait-dispatched | resolution-dependent; residue = δ+β | contextual dispatch | head-specific post-resolution | best; narrowing multi-candidate = +alts-shaped | S0 + elaborator coupling | **contextual** (impl-set non-monotone in answer space) | tier-2 | pure | semantic-NAC candidate ("unique candidate" = extraction-boundary nac-spec) | no |
| NAF-aware | non-monotone inside solve | routes to EXISTING S1 | head-specific (expr-solve) | best (answer set) | S1 (solver net) — the only other-stratum-fixpoint kind | contextual | tier-2 | worldview-sensitive | NAF IS the negative semantics (solver-side) | no |
| capability-aware | classification dimension | effectful?=pessimistic | n/a (type-level) | n/a | SM5 floor (Track 1) | n/a | n/a | pessimistic + counter | none | no |
| session-typed | boundary protocol | Opaque | n/a | never hashconsed | boundary marker | add-only re-entry | tier-2 | effectful | none | no |
| FFI | Opaque | Opaque | head-specific | NEVER hashconsed — (epoch×path) keys | boundary (SM5 floor) | outside chain | tier-2, never serialized | **YES pessimistic** (runs inside whnf) | none | no |

**D6 set-check**: the ten kinds as a SET satisfy the EAGER completeness contract today —
all S0 kinds are best-only writers and the seed is head-specific; the contract re-checks
when β (generic) and any SATURATE rule coexist (Track 2 Phase 3 obligation).

## §3 Promotion analysis (what the IN tag BUYS under the locked substrate)

The substrate already gives sharing (e-class cells + hashcons), S0 broadcast dispatch,
best-only routing. The tag ADDS exactly four things: (1) singleton-by-construction
classes (composes with ledger-6 descope); (2) strong confluence by binary principal port
— no critical-pair obligation, D6 trivially satisfied; (3) the lowering-layer parallelism
CERTIFICATE (Track 0.3's reader) — on Racket BSP a future-scheduler dividend, NOT a
day-one speedup; (4) Lévy-optimality certification (sharing is delivered by the
substrate; the tag certifies the rule won't break it). Per-candidate: **arithmetic
unconditional**; **δ** conditional on content-keying for regime admission; **β**
conditional on the guard + binder canonicalization + Q8 (which it CARRIES, not
resolves); **ι NOT IN** (two overlap loci) → first adhesive-DPO kind, as the Master
predicts; structural decomposition moot (already native).

## §4 The implicit-NAC finding (CONDITIONAL — do not act unverified)

Default/else arms in compiled first-match trees are implicit NACs ("no earlier ctor
matched") IF catch-alls survive compile-match-tree into expr-reduce arms AND Track 3
ingests at arm granularity. The critique downgraded the proposal's "revisit trigger
FIRES" claim: **BLOCKING VERIFICATION commissioned at Track 3 opening** — trace one
wildcard multi-clause defn through compile-match-tree; only if catch-alls survive does
the pattern-completion-vs-nac-spec choice exist (and only then does SM3 D1's recorded
revisit clause fire).

## §5 The partition (owner-decided: Option B + corrections + structural binding)

**Track 2 = the IN-fragment track, interior LADDERED**: Phase 0 = effect-safety guard
(BLOCKING, ledger 18) → Phase 1 = NAMED arithmetic seed (~12-20 int+nat literal binary
ops; explicit exclusions: generic-* coercion family second with its own row split;
collection ops later) → Phase 2 = δ → Phase 3 = guarded β.
**STRUCTURAL EXIT CRITERION (tracker-row wording, owner-bound)**: Track 2 is not done
until the guard passes AND guarded β fires on the substrate AND the PRN §2 confirmation
is recorded. **Track 3 = ι/DPO** (dual-Nat-rep pairs + user expr-reduce; the §4
verification opens it). Rationale: honors both owner locks literally;
one-novel-mechanism-per-phase; Track 1's e-class cells get a production consumer
(Network-Reality-Check-passing arithmetic rule) before the binder/Q8 front opens.

## §6 HVM2 (owner: DEFERRED whole — with a guard)

The owner deferred the benchmark-posture question to Track 2 design time. Deferral
guard (so the memo's "before Track 2" intent survives): **Track 2's design doc MUST
open with the benchmark-posture decision as its first item.** Material recorded for
that decision: a wall-clock gate vs HVM2 is 5-6 orders of magnitude of substrate
difference (meaningless for Racket BSP); the panel's honest middle is
**interaction-count characterization** (β-firing/sharing-hit counts vs HVM2 interaction
counts — tests the Lévy claim independently of wall-clock), with wall-clock deferred to
the LLVM-lowering consumer.

## §7 Master amendments (this commit)

1. Implementation-references row: "~50 cases" → 461 whnf arms / 235 head constructors.
2. Track 2 row: interior laddered per D.2 §5; β remains the confirmation deliverable +
   exit criterion; guard Phase 0.
3. Track 3 row: ι/DPO confirmed; opens with the §4 blocking verification.
4. Track 0.2 row → ✅ CLOSED with D.2 linked.
