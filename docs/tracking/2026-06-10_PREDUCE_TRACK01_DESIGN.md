# PReduce Track 0.1 — Architectural Design (D.1)

**Created**: 2026-06-10
**Status**: Stage 3 in progress — sub-model 2 SETTLED (pending lock), sub-models 1/3/4/5/6 open
**Supersedes**: the Master's Track 0.1 row wording, per the 2026-06-10 owner agreement on closure
semantics: this doc's body is the **six sub-models settled as design decisions**, and 0.1 closes
with a **coarse NTT model + correspondence table as the exit gate** (every NTT keyword maps to an
existing Racket realization `file:line` or is tagged `PROPOSED-NEW` with the owning track).
Fine-grained NTT lands per-track in Tracks 1–4 design docs.
**Inputs**: [Track 0.1 sketch](../research/2026-05-02_PREDUCE_TRACK01_ARCHITECTURAL_SKETCH.md)
(Stage-1 research note, input-only); [engineering memo](../research/utm-fl/outputs/preduce-engineering-inputs-from-substrate-research.md);
2026-06-10 vision grounding audit + typing Network Reality Check (PASSES — cell-read authoritative,
driver.rkt:549); 2026-06-10 design-options panel (3 clusters × propose/critique + synthesis,
run `wf_118652c1-716`); owner decisions D2/D5/D7 (2026-06-10 session).

## Progress Tracker

| Sub-model | Description | Status | Notes |
|---|---|---|---|
| SM1 | AST PU compound cell layout (Layer 1 granularity) | ⬜ | Gates on SM2 lock (occurrence components reference e-class cells) |
| SM2 | E-class cell realization | ✅ | LOCKED 2026-06-10 — T5 census LOW risk (§2.10); corpus amendments in lock commit |
| SM3 | Unified rule registry cell | ⬜ | Inherits SM2's per-rule write-target datum (eager/saturate tag) + NAC field (memo) |
| SM4 | Strata (S0 + S(-1)) | ⬜ | Congruence placement RESOLVED into SM2 (S0 watchers); re-derive "two strata suffice" incl. rebuild + fuel |
| SM5 | Effect-stratum boundary marker | ⬜ | Owner-census #5 open: posture against COMMENT-ONLY Stratum 3 (effect-executor.rkt:53-54) |
| SM6 | Persistence regimes | ⬜ | Consumes SM2's content-address key decision (D3); couples to Track 0.3 schema (T7 open) |
| NTT exit gate | Coarse NTT model + correspondence table | ⬜ | After SM1–SM6; PROPOSED-NEW registry started in §2.8 |

---

## §2 Sub-model 2 — The E-class Cell (LOCKED 2026-06-10)

### §2.1 Decided design

**Domain home (owner decision D2)**: the e-class order lives as a **relation on the shared term
carrier domain** — `'eclass-refine` registered in the per-relation merge-registry
(sre-core.rkt:157-165 idiom: `equality → flat`, `subtype → subtype-ordering`,
**`eclass-refine → coarsening-join`**), NOT as a separate `'eclass` SRE domain. This eliminates
the term↔eclass bridge surface entirely (no cross-domain morphism for hashcons; no exposure to the
documented tag-collapse class under worldview coloring; per structural-thinking's
prefer-tagging-over-bridges). The term carrier domain itself is greenfield either way — the
verified census shows ZERO `'term` ctor-descs at HEAD (type 12 / data 9 / session 7), so the
domain-home choice decides where new code is homed, not how much is built.
**Falsification check before lock**: T5 census (consumers assuming equality-merge-is-flat on
shared carriers + the closed-relation-set touch surface at sre-core.rkt:2250/:2176-2186). If the
census shows pervasive flat-equality assumptions that `eclass-refine` coarsening would violate,
fall back to a separate domain + explicitly-designed Galois bridge, and re-record D2.

**Cell value**: ONE componentwise-ACI product (join-semilattice; **merge IS the order**, matching
sre-core.rkt:147-150 exactly — the declaration narrows to what the substrate is):

```
eclass-value := { best       : (Q-cost × form)   merge: argmin by Q-order, tie-break structural hash
                  alts       : e-node set          merge: set-union
                  canonical  : class-name          merge: min-join over allocation-order total order
                  provenance : support metadata    merge: monotone accumulation }
```

**Q-polymorphic cost (owner decision D7 — S1 commitment resolving Master Q5's direction)**: the
`best` component is parameterized over an arbitrary quantale Q from day one. The Q interface is
the SRE quantale property surface already shipped (tropical-fuel.rkt:98-124 property declarations +
`register-merge-fn!/lattice`); **tropical is the first instance**, not the hardcoded shape.
Consequences accepted by the owner: (i) the green slice must define the Q interface, not just
consume fixnum fuel; (ii) storage specialization (monotone-counter-style fast path) becomes
per-Q-instance and microbench-gated — the Phase 1V numbers do not port and were never claimed to
(Master:30 caveat); (iii) Track 4 decides product/tensor *composition* per the Q5 disposition —
D7 fixes polymorphism, not the composition.

**Three representatives separated (D3)**: the panel verified a circularity (cell-id = structural
hash of canonical representative is circular once classes merge — E_GRAPHS §7.1 + sketch §4.2).
Resolution: three distinct keys, never conflated —
1. **canonical class NAME** = allocation-order id (flip-minimizing min-join carrier);
2. **cost-best FORM** = `best` argmin (per-Q);
3. **content-address KEY** = structural hash (hashcons + `.pnet`; SM6 consumes this one).

**Execution regime = per-rule registry datum, not a cell-shape or scheduler commitment** (panel
cluster C option 4; preserves Cell/Propagator/Scheduler orthogonality structurally): a rule's
Axis-1 tag determines its **write-target** — EAGER kinds (IN-fragment, confluence-by-construction,
arithmetic) write `best` only; SATURATE kinds (genuinely non-confluent cost-differing rules) also
write `alts`. The singleton case is the structural fast path; widening is emergent, not moded.
`alts`-existence is justified-or-descoped by the SATURATE-rule existence trigger (scaffold ledger
item 6).

**Congruence closure = S0, structurally emergent** (panel cluster B): hashcons signature-set
watchers discover congruent pairs and emit unions as min-join writes; the congruence invariant is
a property of the S0 quiescent fixpoint, NOT a deferred-rebuild stratum (the egg-transplant option
was killed: stratification.md's admission test answers "S0" — congruence is monotone coarsening and
requires no prior quiescence; a performance-motivated stratum is the rejected Option-E shape).
Day-one watcher realization is MIXED broadcast+fire-once (VERIFIED: broadcast item lists are fixed
at install, propagator.rkt:2429-2462 — dynamic item growth does not exist; new signatures get
fire-once installs or per-round batch re-install at the topology tier).

**Binder posture**: α-equivalence is **canonicalization-layer** for Track 1 — de Bruijn canonical
form BEFORE structural hashing/hashcons (our existing de Bruijn + zonking infrastructure).
Relation-layer binder decomposition is deferred to the track that needs congruence UNDER binders
(Track 2 β at the latest). Grounds: the supposed "existing binder machinery" is verified absent —
`requires-binder-opening` consumption at sre-core.rkt ~2475/~2491 is a bail-out to PUnify;
`ctor-desc-binder-open-fn` has zero consumers; `sre-decompose-binder` is comment-ware. Moss 2025
remains the theory reference for the Track 2 step.

### §2.2 Carried decisions (designed here, not owner-gated)

**D1 — worldview semantics for DERIVED writes** (the panel's sharpest soundness finding, verified:
`tagged-cell-read` at decision-cell.rkt:409 discards contributing bitmasks; `net-cell-write` at
propagator.rkt:1989-2014 tags with the writer's worldview only — a shared congruence watcher either
cannot SEE speculative collisions or pollutes the base partition un-retractably). Disposition:
green slice runs at wv=0 (no exposure); BEFORE SM2.3 (worldview coloring), resolve T4 — whether
watcher item-fns can raw-read tag entries for explicit ATMS support-set plumbing (primary), with
per-(signature×worldview) Variant-C fire-once watchers as the fallback. This is a LOCK-BLOCKING
design obligation for SM2.3, not for the green slice.

**D4 — carrier split**: green slice uses **per-class cells**; universe consolidation
(partition/hashcons components on shared carriers) is a LATER cell-layer storage migration,
microbench-gated, executed under the per-domain-universe migration checklist (pipeline.md).
Grounds: R-lens T2 RESOLVED TRUE — intra-cell cross-component propagation is production-shipped
(typing-propagators.rkt:2488-2500: same compound cell as input AND output, component-paths reads,
different-component writes), so cluster A's "cost fixpoint degenerates into an interpreter"
kill-shot premise is REFUTED; what remains against early consolidation is the softer cohesion
argument ("compound cells for cohesive scopes" — e-classes are independent) plus migration risk.
Track-4 cost fixpoint propagators run BETWEEN per-class cells at green; consolidation may revisit.

**D6 — EAGER completeness contract** (cross-cluster soundness coupling): discarding dominated
forms is monotone in cost order but anti-complete in term-set order — a discarded form never
enters hashcons, so congruence over it silently never fires, and NO existing gate (Network Reality
Check, VAG, suite) catches it. Contract: the EAGER tag is a **rule-SET-relative** property — a
rule kind may be tagged EAGER only if no coexisting rule's LHS can match a form that EAGER
discarding makes unreachable. Acceptance artifact: a completeness statement in this doc at lock +
a test exercising an EAGER-discard/SATURATE-match interaction (new artifact class; required at
Track 1, not green slice).

**D5 (owner) — probe**: the redefined probe (injected candidate rule set — SRE Track 2D's 13 DPO
rules + arithmetic identities; measures applicable-rule overlap, reduction-chain lengths,
hashcons/sharing hit rates, rule-kind frequencies) runs IN PARALLEL with 0.1; calibration-only.
It may gate: Axis-1 default tags, Track 4/6 scope, storage-consolidation migration, install-churn
acceptance. It may NEVER gate: the cell shape. The original Artifact-1 falsification criterion is
VOID (verified tautology: whnf-impl at reduction.rkt:1390 is first-match-wins — exactly one rule
applies per site by construction; Cranelift's 1.13 was measured against a production optimization
ruleset we don't have).

**D8 — orphan assignments**: §7.8 (does fuel bound saturation depth structurally or only by
exhaustion?) → explicit Track 4 design obligation, recorded in SM4. The monotone-growth memory
model (never-delete hashcons + alts + provenance accumulation; only quiescence guarantee under
growth-rules is fuel exhaustion) → GC/compaction ledger owned by Track 5 design. E_GRAPHS:240's
"egg batched-rebuild matches our BSP-round semantics" overstatement → amended at lock (§2.7).

### §2.3 What Track 1 builds (scoped by this sub-model)

1. Term carrier domain registration + `'eclass-refine` relation in its merge-registry (the real
   cost center: term-domain structural machinery is absent at HEAD).
2. The product cell value + componentwise merges + SRE registration (consume the tropical-fuel
   min-merge precedent at propagator.rkt:1079-1096; `'total-order-min` registration alongside
   `'monotone-set` at infra-cell-sre-registrations.rkt:130-142) + declared-properties entries.
3. Hashcons keyed by content-address (de Bruijn canonical form → structural hash → cell).
4. Union-emitter propagator (symmetric min-joins; Shiloach-Vishkin shape). Write-time path
   compression is VIABLE (T1 resolved: fire-and-collect-writes catches undeclared writes —
   propagator.rkt:2850+ "undeclared-writes (below) catches any leaked writes") but sanctioning
   it as a pattern (vs leak-catch) is a Track 1 design call; pointer-doubling forwarding is the
   fallback (scaffold ledger item 2).
5. Congruence signature-set watchers (mixed realization, §2.1).
6. Q interface for `best` (SRE quantale property surface; tropical instance first).

### §2.4 Green slice (SM2.1 — first Network-Reality-Check-passing trace)

At wv=0, no congruence, no cost activation: register domain/relation + product merge; hashcons
cell creation by content-address key; ONE union-emitter propagator; acceptance = the literal trace
*cell creation → net-add-propagator → net-cell-write (min-join) → quiescence → net-cell-read of
canonical = find result* asserted in a test file, PLUS a racing `union(a,b) ∥ union(a,c)` case
proving merge-by-fixpoint. Explicitly OUT: congruence watchers, worldview tagging, cost
activation, GC, storage specialization. The slice is green under either D4 carrier answer.

### §2.5 Implied sub-phase partition (from panel synthesis, adopted)

SM2.0 decision lock (incl. §2.7 doc amendments, same commit) → SM2.1 green slice → SM2.2
congruence layer (+ Track-2 binder coupling) → SM2.3 worldview coloring (blocked on D1/T4) →
SM2.4 enrichment derivation + `.pnet` schema field (couples to Track 0.3; T7 open) → SM2.5 cost
activation (Track 4 contract; DAG-cost NP boundary stated in the cell contract — residuation
gives cost-PROVENANCE, not an NP-escaping DAG extractor). Redefined probe runs parallel from SM2.0.

### §2.6 Scaffold ledger (6 items; per workflow.md, each named with retirement trigger)

| # | Scaffold | Retirement trigger |
|---|---|---|
| 1 | Never-delete hashcons | Track 5 GC/compaction design (D8) |
| 2 | Pointer-doubling forwarding (if write-time path compression not sanctioned) | Track 1 design call on T1 pattern; else N/A |
| 3 | Mixed broadcast+fire-once watcher realization (day-one baseline) | Universe consolidation migration (D4 revisit) or topology-tier batch re-install design |
| 4 | Microbench-gated storage specialization deferred (per-Q under D7) | Microbench at Track 4 cost activation |
| 5 | Asserted-enrichment-before-validation (if 1b ships before derivation wiring) | Wire `resolve-domain-properties`-backed derivation + registration-time mismatch error, by Track 1 close (T8: inference machinery EXISTS — resolve = infer + derive-composite, sre-core.rkt:1935; enforcement wiring is the gap) |
| 6 | `alts` component existence | Justified by first SATURATE-tagged rule kind at Track 4 design or probe evidence; else descope to best-only + named retrofit plan |

### §2.7 Corpus amendments REQUIRED in the lock commit — ✅ DONE in the lock commit (items 1-3 amended: Master Layer-2, E_GRAPHS:240 + §7.1, sketch §4.2 superseded-banner; item 4 verified, see §2.9)

1. Master:73-75 + sketch §4.2: `:order :refinement` → the memo's `:enrichment :semilattice`
   pivot (+ Q-module slot, Q-polymorphic per D7) — the product cell REALIZES the standing
   amendment (memo:35,75).
2. E_GRAPHS_RESEARCH:240: soften "egg's batched-rebuild matches our BSP-round semantics" (the
   composed design does congruence in-round via S0 watchers; the analogy is loose).
3. Sketch §4.2 / E_GRAPHS §7.1 content-addressing circularity: amend to the D3 three-key
   separation.
4. Re-verify arXiv 2511.20782 ("Optimism in Equality Saturation") before it enters any doc
   (sweep flags it near-cutoff).

### §2.8 NTT correspondence-table entries seeded by SM2 (for the exit gate)

| NTT construct | Realization | Status |
|---|---|---|
| `:lattice :structural` (product cell) | compound-cell + componentwise merge (production pattern: attribute map, typing-propagators.rkt:2864) | EXISTS |
| merge-IS-order join-semilattice | sre-core.rkt:147-150 design note | EXISTS |
| `:enrichment <tag>` (derived annotation) | derivation over declared-properties via resolve-domain-properties (sre-core.rkt:1935) + pnet schema field | PROPOSED-NEW (Track 1 derivation; Track 0.3 schema; T7/T8 open) |
| `'eclass-refine` relation | per-relation merge-registry (sre-core.rkt:157-165) | PROPOSED-NEW (Track 1; T5 census pending) |
| `[:Q-module Q]` (polymorphic cost slot) | SRE quantale property surface (tropical-fuel.rkt:98-124) as interface; tropical first instance | PROPOSED-NEW (Track 1 interface + Track 4 composition) |
| min-join total-order merge | tropical-fuel min-merge precedent (propagator.rkt:1079-1096) | EXISTS (registration NEW) |
| S0 congruence watchers | set-latch + mixed broadcast/fire-once (propagator-design.md pattern; propagator.rkt:2429-2462) | EXISTS (instantiation NEW) |

### §2.9 Open R-lens targets carried past lock

- **T3** (SM2.3): tagged-OF-compound composition — `promote-cell-to-tagged` on a compound hasheq
  carrier has no verified production site; read decision-cell.rkt:529 merge path.
- **T4** (SM2.3 / D1): raw-read availability inside watcher item-fns for support-set plumbing.
- **T7** (SM2.4 / Track 0.3): pnet-serialize CELL-SCHEMA surface for enrichment annotation +
  compound values + provenance.
- **T6** (D5): scope the injected-rule probe variant (SRE Track 2D's 13 rules importable?).
- (§2.7 item 4 RESOLVED at lock: arXiv:2511.20782 "Optimism in Equality Saturation"
  WebSearch-verified — Arbore, Cheung, Willsey, Berkeley; v4 2026-04-16.)

### §2.10 T5 census result (LOCK CLEARED, 2026-06-10; HEAD `533bfcab`)

**Verdict: LOW risk — D2 confirmed.** The relation set is an OPEN, table-driven registry
(variance-maps at sre-core.rkt:2234-2245, propagator-ctor-table at :2837-2843, per-domain
merge-registry lambdas; no exhaustive case forms found). Adding `'eclass-refine` is an
8-edit touch surface: relation constant (~:2190), variance-maps entry, NEW
`sre-make-eclass-refine-propagator` factory, propagator-ctor-table entry, term-domain
registration with the `'eclass-refine` merge-registry case; type/tropical-fuel domains
verified unaffected.

**Structural refinement adopted into D2**: relations are PROPAGATOR kinds, not cell
properties. Cells bind ONE merge-fn at creation (`net-new-cell`, propagator.rkt:1330);
per-relation merge selection happens at propagator fire time via the relation-keyed
merge-registry lookup. Consequences for Track 1: (i) e-class cells bind the componentwise
PRODUCT merge at creation — racing unions therefore resolve by the CELL's min-join, which
is exactly the green-slice acceptance criterion; (ii) the `'eclass-refine` registry entry
serves relate-layer dispatch (which propagator fires), not cell-merge override;
(iii) FOOTNOTE for Track 1's decomposition path: `sre-identify-sub-cell` (sre-core.rkt:2280)
hardcodes the equality merge when creating decomposition sub-cells — term-structure
sub-cells do NOT inherit the e-class product merge, and must not be conflated with
e-class cells.
