# PReduce Track 4 Design — Cost-Guided Extraction (residuation on the e-class poset)

**Status**: DESIGN OPENING (2026-06-10, autonomy loop iteration 27).
**Inherits**: PPN 4C Phase 1B's tropical algebra (`tropical-fuel-primitives.rkt` —
NOTE per the Master's corrected wording: `tropical-left-residual` is a pure read-time
function with ZERO production consumers today; Track 4 is its FIRST consumer, and the
on-network residuation wrapping is GREENFIELD, not inheritance). Owner D7 (Q-polymorphic
cost; v1 real-number carrier) fixes the composition direction — §1 derives, it does not
re-decide. Module Theory §6 (e-graphs as quotient modules) is the realized frame.

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| D | Design through VAG | ✅ | iters 27-28; DESIGN COMPLETE |
| 1 | The Q interface + compositional cost cells (extraction-as-fixpoint) | ⬜ | §2 |
| 2 | Extraction read + the question-keyed rewrites store (SM6 §7.4 schema) | ⬜ | §3 |
| 3 | Residuation (budget-bounded extraction; 1B's first consumer) | ⬜ | §4 |
| 4 | The payoff A/B (the chartered curve-turn measurement) | ⬜ | §5 |

## §1 The composition decision (derived from owner D7 — not re-decided)

Cost composes as a QUANTALE: `class-cost = ⊕ over alts of (node-cost ⊗ children costs)`.
v1 instantiates Q = (ℝ≥0, ⊕=min, ⊗=+) — the tropical semiring PPN 4C 1B shipped.
The Q INTERFACE (D7's arrival point) is two functions + two constants:
`q-combine` (⊗), `q-better?` (the ⊕-induced order), `q-identity` (⊗-unit, 0),
`q-top` (unreachable, +inf.0). The e-class product's ':best component is ALREADY
Q-shape-agnostic (cost . form); extraction generalizes by parameterizing these four.
Multi-dimensional tropical cost (the owner's research line) = a Q instance later;
NO schema change (the research queue item stays queued).

## §2 Extraction IS a propagator fixpoint (the mantra showcase)

The classic e-graph extraction (saturate class costs bottom-up, then pick argmin
forms top-down) is EXACTLY a propagator quiescence on the existing substrate:

- **extraction-cost cells**: one per class — Q-valued, merge = q-better?-min
  (monotone DESCENT toward the optimum is monotone ASCENT in the min-lattice;
  CALM-safe). Today's ':best cost is the INTERN-time local cost; the extraction
  cell carries the COMPOSITIONAL cost (node ⊗ children).
- **cost propagators**: per e-node (parent), watching the children's extraction
  cells — when a child's cost drops, recompute `node-cost ⊗ Σchildren` and write
  the parent's cell. REFIREABLE (the precision contract; cascades descend).
  This is the congruence-watcher topology REUSED with a different payload —
  the parent-index machinery from iteration 12 is the same fan-in shape.
- **the extraction READ**: at quiescence, top-down argmin form selection is a
  pure read (each class's recorded best-alt-at-converged-cost). NO new stratum
  (the §SM4 admission test: extraction needs S0 quiescence, which run-to-
  quiescence already provides; semantic-NAC presence reads land HERE per the
  SM3 D1 lock — extraction-time is the congruence-correct NAC boundary).

## §3 The question-keyed rewrites store (SM6 §7.4 — the owner-registered schema, FIXED)

Key `(source-e-class-content-hash, cost-criterion-id, worldview-bitmask?)` →
value = chosen extraction + regime tag. Realized as a prn cell (hash, equal?-keyed;
dedup-or-update-if-better merge — the better-extraction-wins refinement is monotone
under q-better?). `cost-criterion-id` = the Q instance's identity (v1: 'tropical-v1).
The worldview slot stays RESERVED (schema frozen with it; ground-only day one per
the SM6 lock). This is the store the Cranelift finding predicts earns its keep first.

## §4 Residuation (Phase 3; 1B's first production consumer)

`tropical-left-residual` answers "given budget B at the parent, what budget remains
for a child once the op + siblings are paid" — the budget-bounded extraction read
(prune alts whose residual goes negative). Pure read-time composition over the
SAME cost cells; no new state. GREENFIELD wrapping (the Master's corrected wording);
the fuel-cell precedent (#:on-write-check) is the cell-layer idiom if budget
enforcement ever needs to be reactive rather than read-time.

## §5 The payoff A/B (Phase 4 — the chartered curve-turn measurement)

The Track 2 close verdict (+38% fresh-heavy / neutral large; flip NOT met) is the
baseline this track must move: extraction makes EVERY memoized class serve its
cost-best form at read time, so the ingestion hook's value proposition changes from
"memo equal results" to "memo + ALWAYS serve the cheapest known form." The A/B:
PREDUCE_INGEST ON+extraction vs OFF on the same three files + a NEW multi-command
acceptance section built to exercise repeated-reference workloads (the §15 corpus
caveat answered with a corpus, not an excuse). The flip decision re-opens HERE with
that data.

## §6 Design questions — RESOLVED (iter 28; 3-column adversarial)

**Q1 cost-cell allocation → LAZY (at extraction request, over the reachable
subgraph).** Catalogue: lazy skips cells for never-extracted classes; eager runs
the fixpoint incrementally during ingestion. Challenge: doesn't lazy burst-allocate
at read time? Yes — and the read is ALREADY a quiescence call (the burst is one
topology round); eager pays fixpoint cost for classes never asked about, on the
ingestion path the Track 2 A/B just showed is overhead-sensitive. Same resolution
shape as Track 2's lazy ingestion; same reversal path (extraction-frequency data).

**Q2 parent-index → DEDICATED cell.** Catalogue: the congruence sig-index maps
signatures→classes (a different projection); the cost propagator needs
(parent-class, child-classes, node-cost) triples = the intern-node DESCRIPTORS.
Challenge: reuse the sig-index? Mixing payloads on one component fails the
cohesion test ("separate cells for separate concerns") and couples extraction to
congruence's carrier shape. Resolution: a parent-descriptor index cell
(hash child-alloc → set of descriptors; hash-union-of-set-union — the iteration-12
merge reused), WRITTEN at intern-node (cheap monotone write), CONSUMED lazily by
extraction (Q1).

**Q3 the store contract → a CACHE LATTICE, named as such.** Catalogue:
better-wins merge is monotone under q-better?. Challenge: doesn't this break
append-only registry framing? It would — IF it were a registry. It is NOT: the
rules registry holds AUTHORITATIVE definitions (dedup-or-error); the extraction
store holds DERIVED optima (keep-better; recomputable from primary; eviction =
whole-cell reset at the SM6 invalidation boundaries). Primary/derived per the SRE
lens Q5 — different contracts, different modules (extraction-store.rkt), never
conflated.

## §7 Fine NTT (the cost-fixpoint layer)

```ntt
cell extraction-cost[k] : Q          ;; lazy-allocated per reachable class
  :lattice :value                    ;; min-lattice under q-better? (CALM descent)
  :merge   q-min-merge               ;; PROPOSED-NEW (extraction.rkt)

cell parent-descriptor-index : ParentIdx   ;; child-alloc → (set descriptor)
  :lattice :structural
  :merge   hash-union-of-set-union   ;; the iteration-12 merge, reused

propagator cost-recompute [descriptor]     ;; REFIREABLE (precision contract)
  :reads  (extraction-cost[child] ... parent-descriptor-index)
  :writes (extraction-cost[parent])
  :fire (write parent (q-combine node-cost (q-combine* children-costs)))

;; extraction READ: pure at quiescence — argmin alt per class, residual-pruned
;; (tropical-left-residual — 1B's first consumer); semantic-NAC presence reads
;; consult their presence cells HERE (the SM3 D1 boundary).
```

Correspondences: q-min-merge + extraction.rkt PROPOSED-NEW (Phase 1's two
surfaces); everything else reuses landed realizations (descriptors:
eclass-graph.rkt intern-node; the fan-in shape: iteration 12; quiescence:
run-to-quiescence; residual: tropical-fuel-primitives).

## §8 VAG (adversarial, 3-column — iter 28)

| Decision | Catalogue | Challenge |
|---|---|---|
| Extraction as propagator fixpoint | cells+propagators+quiescence ✓ | CHALLENGED: is the top-down argmin READ off-network imperative? It is a READ — reads are how consumers consume cells (the consuming-read pattern from Track 1); the COMPUTATION (cost fixpoint) is on-network. No hidden fixpoint in the read. |
| Lazy allocation | first-use, like Track 2 | CHALLENGED: "lazy" twice in a row — is this a creeping anti-mantra habit? No: both cases bind work to information that EXISTS (an extraction REQUEST is information); eager would manufacture work for absent questions. The mantra governs flow of present information, not speculative precomputation. |
| Dedicated parent-index | cohesion test ✓ | CHALLENGED: a third index cell (hashcons, sig-index, parent-index) — consolidation candidate? Each is a different PROJECTION of the node set with a different consumer + merge; consolidating couples consumers. Revisit only if Track 5 serialization wants one section. |
| Cache-lattice store | primary/derived named ✓ | CHALLENGED: "cache" historically masks bugs (belt-and-suspenders rule). This cache is RECOMPUTABLE-BY-CONSTRUCTION from primary cells with a DECLARED eviction boundary — the masked-bug shape requires a fallback path, which does not exist (a miss recomputes, full stop). |

**DESIGN COMPLETE** (iter 28). Phase 1 implements: the Q interface, q-min-merge,
the parent-descriptor index write at intern-node, lazy cost-cell allocation +
cost-recompute propagators, the extraction read; tests = the diamond graph
(cheap path wins through the fixpoint) + a two-level cost-drop cascade.
