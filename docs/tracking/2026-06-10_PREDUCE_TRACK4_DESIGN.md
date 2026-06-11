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
| D | Design through VAG | 🔄 | opened iter 27 |
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

## §6 Open design questions (for the critique round)

1. Cost-cell allocation: eager per class at intern, or lazy at first extraction
   read? (The D5-shaped question again — lazy default per the Track 2 precedent
   unless the fixpoint's fan-in makes eager cheaper.)
2. Where does the parent-index for cost propagators live — reuse the congruence
   sig-index entries (they already map parents) or a dedicated index? (Cohesion
   test: same fan-in, different payload — 3-column it at implementation.)
3. The store's "update-if-better" merge vs dedup-or-error: better-wins is monotone
   under q-better? but breaks the registry's append-only framing — justify or
   reshape (likely: the store is NOT a registry; it is a CACHE lattice — different
   contract, named explicitly).
