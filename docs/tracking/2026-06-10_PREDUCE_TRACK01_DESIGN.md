# PReduce Track 0.1 — Architectural Design (D.1)

**Created**: 2026-06-10
**Status**: Stage 3 in progress — SM2 ✅ SM3 ✅ LOCKED; SM1 SETTLED (§4, lock pending the 2′ assessment); SM4/SM5/SM6 open
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
| SM1 | AST PU compound cell layout (Layer 1 granularity) | 🔄 | Settled 2026-06-10 (§4); owner: extend attr-map / epoch-keyed / commission 2′; LOCK pending 2′ assessment |
| SM2 | E-class cell realization | ✅ | LOCKED 2026-06-10 — T5 census LOW risk (§2.10); corpus amendments in lock commit |
| SM3 | Unified rule registry cell | ✅ | LOCKED 2026-06-10 — tier census pinned (§3.7); naming scheme delivered (§3.4) |
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
**Backflow flag (added 2026-06-10 at SM3 settle)**: the SM3 congruence finding — congruence
closure creates pattern matches no rhs-template analysis predicts — plausibly weakens the
STRUCTURAL CHECKABILITY of this contract too (same reachability shape, same blind spot). Verify
before promising any registry-watcher enforcement mechanism for it; the contract itself stands.

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

## §3 Sub-model 3 — The Unified Rule Registry (LOCKED 2026-06-10)

Inputs: 2026-06-10 grounding sweep (registry landscape) + design-options panel run
`wf_f8b887ba-0ca` (3 clusters × propose/critique + synthesis) + owner decisions D1/D2/D4.

### §3.1 Decided design

**Storage (owner D4 — "4b")**: the registry is born CELL-FIRST as **one compound universe
cell on the persistent registry network** — components keyed by module-id, each holding that
module's rules — plus a **propagator-MAINTAINED tag-index component** (a propagator watches
rule components and derives the tag index; information flow, not registrar dual-write). The
parameter+cell-mirror shape is OFF the table (belt-and-suspenders; would mint a 17th parameter
into PM Track 12's drain pile, with the verified silent-skip guard as a built-in drift
mechanism). SRE registration: a `'rule-registry` domain. Persistence = serialize a module's own
component into its `.pnet` section (structural provenance — no annotation+filter). The
per-domain-universe migration checklist (pipeline.md) applies; this pioneers the universe
pattern on the persistent network (named cost).
**Bootstrap**: seed pour at prn-init projecting the Racket-side stores (ctor-registry tables +
sre-rewrite-registry) into property-tagged rule-data under a kernel/prelude pseudo-module
namespace. The Racket module-load hasheq accumulation necessarily predates any network — named
scaffolding-constant. **Prelude window verified non-blocking** (test-support.rkt:93 keeps
prn-box #f during prelude BY DESIGN; zero Prologos-surface rule registrations exist today, so
seed-pour-at-init suffices; re-sequencing is deferred with a Track 9 trigger: first prelude
module that defines a surface rule).

**Schema (SP1 — storage-independent; the `sre-rewrite-rule` spine extended)**: name,
lhs-pattern, interface-keys, rhs-template, apply-fn, directionality, cost, confluence-class —
PLUS: `enrichment-tag` (memo taxonomy: enrichment-preserving-or-not), `write-target` (SM2
datum: best-only vs +alts), `nac-spec` (semantic NACs only — see below), `tier`
(declarative | closure-resident), module-qualified `rule-id`, RESERVED `worldview-bitmask`
slot (schema frozen without it would force a full pipeline.md struct-field migration later),
and `stratum` KEPT as a separate pipeline-stage field (not conflated with enrichment-tag).
Ctor-descs absorb as property-tagged entries at the REGISTRY+ROUTING level only — the Master:79
"prop:ctor-desc-tag becomes a property" claim is real for routing, FAKE for payload (ctor-desc
is 4 closure fields with no declarative core); the doc says so.

**Two-tier registry (owner D2)**: tier 1 = declarative rules — serializable; what Track 0.3
honestly hands the LLVM collaborator. Tier 2 = closure-resident (~8 of 14 SRE rules with
`rhs-template=#f` + all ctor-descs) — registered as property-tagged metadata + named Racket
references, NEVER serialized (pnet-serialize stubs procedures as `'foreign-proc`). Tier 2 is
**absorbed in metadata only** — in those words; consumers (typing-propagators generic
decomposition) keep reading the legacy hasheqs until a named consumer-read migration track.
The declarative-core compiler (recursion schemes as data; ctor-desc behavior as derivable
meta-description) is OUT of SM3 — queued as a named future track aligned with self-hosting.

**NAC semantics (owner D1 — resolves owner-census point 1)**: termination-guard NACs (the
memo's `x → (+ x 0)` motivating case) **DISSOLVE** — they are the e-class cell's ACI
absorption law restated; zero build, no field. Semantic NACs mean **"absent at the
extraction-time fixpoint"** — checked when Track 4 extraction selects forms, AFTER all
congruence closure (the only congruence-correct boundary: the verified finding is that
congruence merges create NAC-pattern matches no rhs-template analysis predicts, so
firing-round checks are structurally under-approximate and "absent forever" is unrealizable
monotonically). Realization substrate: **monotone presence cells** (one Boolean ⊥→⊤ cell per
distinct NAC pattern, maintained by an S0 match propagator; consumers READ presence instead of
scanning). The firing-round arm is NOT built (revisit only if Track 0.2's kind census finds a
rule genuinely needing pre-extraction absence). Absent-forever is a named-not-built escalation
with recorded preconditions: e-class un-splitting (no precedent), transitive write-tag
provenance (verified non-inheriting), assumption-bit recycling (none found).

**Merge contract (D5, carried)**: module-qualified keyspace; per-namespace **dedup-or-error**
join (NOT table-registry's per-key new-wins; today's sre-rewrite list-append is verifiably not
ACI — re-registration duplicates); kernel/prelude pseudo-module owns the seed; F5 append-only
restated per-namespace.

**Dispatch (D6, carried)**: `'eclass-refine` enters the propagator-ctor-table as the relation
ENTRY (Option-1-as-entry only — its fire-time rule-pull firing realization is killed: it is
today's `for/or` first-match loop relocated into a fire-fn, registration-order-dependent the
moment Track 9 critical pairs arrive). Firing realization = **broadcast-over-tag-matched-rules
per (cell × stratum)** with result-merge = the SM2 write-target semantics. Argued on
SEMANTICS — ACI merge-as-answer is order-independent by construction where first-match-wins
breaks CALM under critical pairs — and explicitly NOT on the A/B 2.3×–75.6× numbers (category
error: those discriminate broadcast-vs-N-propagators; both candidate shapes are one sequential
loop per fire today, propagator.rkt:2446-2447; no perf claim is load-bearing here, so no
microbench obligation attaches). Per-rule installs remain the heterogeneous fallback variant.

**Dynamism (D7, carried)**: rule-set growth machinery (4b delta-installs via topology watcher
vs the critic's `#:items-from` items-from-cell broadcast extension) is DEFERRED to a named
mini-design with a Track 9 trigger — all current registration is module-load-time; the dynamic
path would fire zero times until a mid-session registration consumer exists.

### §3.2 Slices (composing with §2.5)

SP1 schema lock (this section) → SP2 registry-cell green slice — **independent of the e-class
substrate**: cell-first birth + locked merge + batched seed pour + derived tag-index +
rules-by-tag/by-id lookup probe + shared-fixture test file + acceptance file via process-file +
suite green; exercises all four execution contexts → SP3 dispatch (gated on SM2 substrate code
existing) → SP4 NAC presence cells + extraction filter (Track 4 deployment gate, tracker row)
→ SP5 persistence (per-module component serialization, tier 1 only; couples Track 0.3) → SP6
dynamism (Track 9 gate).

### §3.3 Scaffold/deferral ledger additions (items 7-9, extending §2.6)

| # | Scaffold / deferral | Retirement / deployment trigger |
|---|---|---|
| 7 | Bootstrap seed pour from Racket module-load hasheqs | Self-hosted module loading; or declarative-core compiler track |
| 8 | Tier-2 metadata-only absorption (consumers still read legacy hasheqs imperatively) | Named consumer-read migration work-list + deletion commit |
| 9 | Validated-not-deployed stack: NAC extraction filter (Track 4), dynamism (Track 9), worldview serialization (e-class serialization design) | Each gets a tracker row + acceptance probe per the Validated≠Deployed rule — no silent stacking |

### §3.4 Naming hygiene (DELIVERED at lock)

Four colliding names, canonical PReduce vocabulary fixed here — PReduce docs and code never
say bare "ctor registry" or bare "tag index":

| Canonical name | Refers to | NOT to be confused with |
|---|---|---|
| **ctor-desc registry** | ctor-registry.rkt domain→tag→ctor-desc tables (structural decomposition) | the ctor-META parameter |
| **ctor-meta parameter** | macros.rkt `current-ctor-registry` (zero/suc/true/false/unit metadata; pnet entry 8) | the ctor-desc registry |
| **rule-tag-index** | the propagator-maintained tag-index COMPONENT of the rule-registry universe cell (SM3 dispatch) | the carrier root index |
| **carrier-root-index** | the SM2 term-carrier root-tag/hashcons index (e-matching; presence-cell component-paths) | the rule-tag-index |

The carrier-root-index requirement is FED BACK to SM1/SM2 as load-bearing (without it,
absence-adjacent watchers degrade to global carrier watches).

### §3.5 Lock-blocking items — RESOLVED at lock (2026-06-10)

- **Tier census**: ✅ pinned by direct enumeration (§3.7). Counts: 13 SRE rules (5 tier-1 /
  8 tier-2); 28 true `register-ctor!` calls (type 11 / data 8 / session 9); 17 serialized
  registries (pnet indices 7-23). Census header said "14 rules" while enumerating 13 — pinned
  to the enumerated table; the SP2 seed pour enumerates programmatically and is the final
  arbiter.
- **Dormant `make-rewrite-propagator-fn`**: ✅ excavated — it is the Phase-7 per-rule bridge
  (wraps `apply-sre-rewrite-rule` into the propagator fire protocol, `value | #f`); never
  activated. SP3's broadcast-over-rules supersedes the per-RULE shape; disposition: rework as
  the broadcast ITEM-FN's inner application (the rule-application core is exactly what the
  item-fn needs) — do not delete blindly, do not install as-is. Carried to SP3.
- **Broadcast write shape vs SM2 product merge** — still open, carried to SP3 (verify the
  broadcast fold's contribution shape composes with the componentwise e-class merge, or design
  a product-aware write variant).

### §3.7 Tier census (PINNED 2026-06-10, HEAD `533bfcab`, direct enumeration)

**SRE rewrite rules — 13 total, 5 tier-1 / 8 tier-2:**

| Rule | Tier | | Rule | Tier |
|---|---|---|---|---|
| expand-if-3 | 1 | | expand-list-literal-fold | 2 |
| expand-if-4 | 1 | | expand-lseq-literal-fold | 2 |
| expand-when | 1 | | expand-do-fold | 2 |
| expand-let-assign | 1 | | expand-pipe-gt-fold | 2 |
| expand-let-bracket | 1 | | expand-compose-fold | 2 |
| | | | expand-cond-fold | 2 |
| | | | expand-quasiquote-tree | 2 |
| | | | expand-mixfix-pu (surface-rewrite.rkt:1786) | 2 |

**Ctor-desc registrations**: 28 true `register-ctor!` calls — 'type 11 / 'data 8 / 'session 9.
All 28 are tier-2 (closure-resident; no declarative core). **pnet-serialize**: 17 parameter
registries (indices 7-23). Seed-pour total: 41 entries (13 rules + 28 ctor-descs), of which
5 are tier-1 serializable today.

### §3.6 NTT correspondence-table entries seeded by SM3

| NTT construct | Realization | Status |
|---|---|---|
| Rule-registry universe cell (module-keyed components) | per-domain universe pattern (pipeline.md checklist; meta-universe precedent) on prn | PROPOSED-NEW (SP2; pioneers universe-on-prn) |
| Propagator-maintained tag-index component | derived-index propagator (information flow) | PROPOSED-NEW (SP2) |
| Dedup-or-error namespace join | new merge fn + SRE 'rule-registry domain registration | PROPOSED-NEW (SP2) |
| Broadcast-over-rules firing | net-add-broadcast-propagator (propagator.rkt:2429-2462) | EXISTS (instantiation NEW at SP3) |
| NAC presence cells | monotone Boolean cells + S0 match propagators | PROPOSED-NEW (SP4 / Track 4) |
| Per-module `.pnet` rule sections (tier 1) | pnet-serialize extension | PROPOSED-NEW (SP5 / Track 0.3) |


## §4 Sub-model 1 — AST PU Compound Layout / Layer 1 (SETTLED 2026-06-10)

Inputs: 2026-06-10 grounding sweep (attribute map / M-type / reduction state / index prior
art) + design-options panel run `wf_01c38ba0-ab4` + main-session R-lens verifications +
owner decisions (carrier home, identity regime, 2′ posture).

### §4.1 Decided design

**Carrier home (owner)**: reduction occurrence-state EXTENDS the production typed attribute
map — the persistent compound cell at typing-propagators.rkt:2845-2865, same eq?-identity
positions, same two-level pointwise merge. **Regrounded justification** (per the
justification-by-slogan guard): the phase-collapse thesis constrains Layer 2 + same-scheduler
and is satisfied by a separate cell too — it cannot adjudicate this choice; the operative
arguments are (a) the Realization-B / prefer-tagging-over-bridges lesson with its carve-outs
VERIFIABLY ABSENT (same positions, same record shape, both S0), and (b) the production-proven
intra-cell cross-component precedent. New facets: `:eclass-link` (holds the **content-address
KEY uniformly — never a cell-id, never the canonical NAME**; cross-cluster consensus + D3),
`:reduction-status` (small monotone chain), `:cost-in-context` (Q-order min-join; direction —
derived-monotone vs cache-invalidate — DECLARED when the facet lands, per-facet lattice
discipline), `:reduction-provenance` (**set-union/deduped, NOT append** — the verified
`:warnings` append-duplication hazard must not be copied).

**Granularity + storage population**: per-(position × facet) — the proven shape; Master Q1 is
RESOLVED by adoption, not invention. Lazy-on-first-write is the VERIFIED default of
attribute-map-merge-fn — build nothing. **SM1.1 substrate commit** (ONE commit + full typing
regression + acceptance): explicit facet-merge/bot/bot? cases for the new facets; harden the
`[else new-v]` merge default (typing-propagators.rkt:412) to ERROR; the TWO-site bot-filter
fix (:449-450 wholesale fresh-position insert + :457-458 facet clause order); the that-read
arity-2 expose-or-filter decision; update the "5 facets preserved" invariant comment.

**Identity regime (owner)**: the widening/occurrence-set ranges over **epoch-keyed live-parse
occurrences** — sets keyed by parse/command epoch; triggers count within-epoch only; old
epochs go INERT without deletion (monotone-compatible; no retraction). The epoch mechanism
itself is a named design obligation inside the 2′ assessment. Grounds: positions are
eq?-ephemeral while the registry is persistent — un-epoched counting fires from cross-parse
history noise and silently decays lazy into eager.

**Materialization posture (owner)**: the registry-resident-embryo variant ("2′") is
COMMISSIONED for its own adversarial assessment before anything locks on it — it was
critic-invented and never vetted, it sits on the now-CONFIRMED O(all-keys) diff-cost ceiling,
and it front-runs D4's microbench-gated universe deferral. SM1.4 (widening + congruence
coverage) is BLOCKED on that assessment. The green slice proceeds meanwhile (singleton-only
probe — per-class cell and embryo coincide there; D4's green wording covers it).

**Scaffolding named**: (i) the carrier's `make-parameter` cell-id discovery
(typing-propagators.rkt:2833) + per-command fallback dual path (:2856-2865) become SHARED
load-bearing plumbing for two subsystems — named with the PM Track 12 (parameters→cells)
retirement story; (ii) the imperative analog = FOUR reduction.rkt parameters
(current-nat-value-cache :875, current-whnf-cache :1310, current-reduction-fuel :1313,
current-nf-cache :3035) — Track 8 retirement scope; whether current-reduction-fuel maps to
the tropical-fuel cell discipline instead is a Track 4 question.

### §4.2 Carried decisions and rules

- **Forcing-boundary rule (codified from PPN 4C §18.21.25's G1 failure)**: every lazy posture
  must declare what FORCES materialization for whole-tree consumers. Rule: NAC presence
  checks and cost extraction may only consume **ingestion-complete scopes** — "absent" must
  be checked-empty, never never-demanded. Applies to SP4 and Track 4.
- **Dispatch attachment** (open, answer BEFORE any watcher code, SM1.2/SP3): is rule dispatch
  Layer-2-only under SM3's locked broadcast-per-(cell × stratum), with Layer-1 watchers only
  for bridge/provenance facets? Determines what "reduction propagators install on tm-cid"
  even means.
- **Link-facet population** (lock at SM1.2 with the ingestion realization): the `:eclass-link`
  facet is DERIVED (recomputable by re-hashing) — population is memoization policy. The
  single-facet eager pour re-ships the killed transcription cost (changed-set × dependent-fold
  tax); lazy-memo is the working lean. The ingestion realization (depth-wavefront broadcast vs
  one-fold-per-root) must be LOCKED explicitly — choosing the fold while citing the wavefront's
  Hasse story would be vocabulary without structure.
- **Speculation probe (SM1.5, gates SM2.3)**: targeted base-exclusion test — wv=0 reduction
  write + active typing fork + branch-wv read on the session-promoted shared carrier
  (tagged-cell-read excludes base when a branch entry matches, decision-cell.rkt:420-434) —
  BEFORE any cross-facet consumer. Subsumes T3's remainder.

### §4.3 Substrate facts verified this round (load-bearing)

- **Diff-cost ceiling CONFIRMED**: `pu-value-diff` diffs old against the FULL merged value
  (propagator.rkt:1647+, :2054-2060) and `net-cell-write` takes no changed-path hint — every
  write to a session-global compound carrier pays O(all-keys). Any fix MUST be cell-layer
  (write supplies its changed paths) — a BSP-round piggyback would reproduce the rejected
  tropical-fuel "Option E" shape. This is D4's microbench content and 2′'s entry fee.
- **".pnet cache populates it" is FICTION** (typing-propagators.rkt:2844 comment vs zero
  attribute handling in pnet-serialize.rkt): the attribute map is SESSION-persistent only;
  cross-session persistence remains Layer-2/SM6 business. Fix the comment at SM1.1.
- The Master's "AST is one PU / M-type in one cell / 5 PUs" is design-lore: the parse tree IS
  the M-type (parse-reader.rkt:1104-1114); "PU" in code is the pattern (discrimination cell,
  fact-row PU); no AST-topology-as-one-cell exists. Layer 1's honest realization is
  "parse-tree M-type + attribute-map pattern".

### §4.4 Slices

SM1.0 docs+locks (Master amendments §4.6; boundary + forcing rules) → SM1.1 production merge
substrate (ONE commit, full regression) → SM1.2 identity green slice (registry cell +
reservations + ':root-index/':parents derived components + locked ingestion realization +
the CONSUMING READ — without an in-track read the slice is write-only ceremony; D5 counters
wired) → SM1.3 first rewrite end-to-end (ONE declarative SM3 seed rule on a probe term,
Level-3 acceptance) → SM1.4 widening + congruence coverage (BLOCKED on 2′ assessment) →
SM1.5 speculation probe (gates SM2.3).

### §4.5 Scaffold ledger additions (items 10-12, extending §2.6/§3.3)

| # | Scaffold / deferral | Retirement / trigger |
|---|---|---|
| 10 | Shared make-parameter cell-id + per-command fallback (now two-subsystem load-bearing) | PM Track 12 parameters→cells |
| 11 | Reduction memo caches (4 parameters) coexist as authoritative until conversion checking reads :eclass-link | Track 8 parity + retirement |
| 12 | Trigger-(ii) SATURATE widening arm (designed, dormant) | Track 4 deployment gate + ledger row |

### §4.6 Corpus amendments at SM1 lock

1. Master §Layer-1: "components reference Layer 2 **by cell-id**" → by content-address KEY;
   add the realization-or-pivot sentence (Layer 1 realized as parse-tree M-type +
   attribute-map pattern; the one-PU-per-AST claim retired as design-lore). (§Layer-2's
   circularity phrase was already amended at the SM2 lock.)
2. SM2 §2.1 NAME-at-reservation amendment — owner-gated, PENDING the 2′ assessment (which
   decides reservation semantics); flagged, not yet applied.
3. Code comment typing-propagators.rkt:2844 (".pnet cache populates it") — fix at SM1.1.

### §4.7 NTT correspondence-table entries seeded by SM1

| NTT construct | Realization | Status |
|---|---|---|
| Occurrence record (position → facet product) | attribute map + facet-merge (typing-propagators.rkt:393-463) | EXISTS (4 new facet cases at SM1.1) |
| `:eclass-link` KEY-valued facet | content-address KEY per D3 | PROPOSED-NEW (SM1.1) |
| Hashcons registry cell + ':root-index/':parents derived components | discrimination-cell + cell-decomps precedents | PROPOSED-NEW (SM1.2; carrier-root-index home) |
| Epoch-keyed occurrence-sets | none — undesigned | PROPOSED-NEW (2′ assessment deliverable) |
| Cell-layer delta-notify (changed-path hint on write) | none — confirmed absent | PROPOSED-NEW (2′ assessment entry fee; D4 microbench content) |
