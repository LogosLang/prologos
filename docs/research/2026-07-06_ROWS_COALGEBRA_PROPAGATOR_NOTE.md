# Research Note — Row-Typed Open Records, Final-Coalgebra Semantics, and Propagator-Fixpoint Inference

**Date**: 2026-07-06
**Status**: Brief grounding note (per CIU Track 6 D9). Serves engineering design; NOT a paper track; never gates the engineering phases.
**Origin**: Owner design conversation (`docs/standups/standup-2026-06-29.org` § "Maps<->Schema as co-data, anonymous records and row polymorphism") + 7-thread frontier research pass (2026-07-06, primary sources fetched). Engineering consequences live in `docs/tracking/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` §2a (D6–D9) + §3b.

## The sharpened question (owner, 2026-06-29)

> Can row-typed open records be given final-coalgebra semantics over an OSF-style feature lattice, with type inference realized as propagator fixpoint, such that the Map/schema pair is exactly the negative/positive polarity pair related by shifts?

## Verdict: plausible, and (verifiably, through mid-2026) unclaimed as a composition

Every ingredient is independently established; the composition appears nowhere. Three research threads ran targeted negative searches: no 2024–2026 work occupies "type inference on a propagator network" (nearest neighbors: Eqlog / egglog — Datalog-with-equality, eqsat fixpoint semantics); the OSF line is dormant since the 1990s; no rows-meets-coalgebras paper exists; all verified polarized-record systems have finite label sets.

### Established ingredients (citable)

| Ingredient | Source |
|---|---|
| Objects/records as coalgebras; new object = final-coalgebra element | Jacobs 1996 |
| Records as negative/codata, defined by projections (copatterns) | Abel–Pientka–Thibodeau–Setzer, POPL 2013 |
| Negative lazy records w/ width+depth subtyping, coinductive semantic typing; `&{}` = top of the negative layer | *Polarized Subtyping*, ESOP 2022 (arXiv 2201.10998) |
| Seal = **tabulation** (force all observations, fill-or-error, positive witness) | *Codata in Action*, ESOP 2019 |
| Residual check on exactly the unknown row remainder | AGT (POPL 2016) + Sekiyama–Igarashi gradual rows (arXiv 1910.08480; gradual guarantee/blame for *polymorphic* rows UNPROVEN) |
| OSF/ψ-terms: subsumption lattice, unification IS meet; confluent, inconsistency-complete normalization; residuation = readiness | Aït-Kaci 1986 lineage; LIFE TOPLAS 1994; restated Milanese–Pasi 2023/24 (arXiv 2307.14669) |
| Inference as monotone lattice fixpoint (bounds growth) | Simple-sub (Parreaux, ICFP 2020); rows variant: Marques et al. 2024 (arXiv 2407.06747, proofs pending) |
| Rows + type classes in ONE constraint solver (mechanized) | Toohey et al., POPL 2026 |

### The two-level fix to the question's phrasing

The lfp/gfp tension in the original phrasing dissolves by separating levels:

1. **Object space** = final coalgebra of `F(X) = Sort × (Feat ⇀ X)`; observations = projections; subsumption = simulation. (Finality lives here.)
2. **Description lattice** = row/OSF terms; unification = meet; the row tail denotes the unobserved remainder; a row-typed description denotes the set of coalgebra elements extending it.
3. **Inference** = LEAST fixpoint on the description lattice (Tarski), realized as CALM-monotone propagator saturation — positive fragment (presence facts, containment, fundep firing) in S0; non-monotone residue (closedness/seal, `Lacks`, Jones ambiguity check) stratified. Local confluence of the positive rule fragment ⇒ scheduler-independence.
4. **Map/schema** = the polarity pair: up-shift (schema→Map) = free width subsumption; seal (Map→schema) = tabulation + residual cast on the remainder.

lfp (description lattice) and finality (object space) live at different levels — coexistence is the point, not a conflation.

### Orientation caveat (wire once, correctly)

OSF's *generality* order runs opposite to Prologos's *information* order: OSF meet (unification) = information-JOIN in our cells. One global orientation flip; document at the carrier's merge.

### Known-hard edges (engineering guards, from the same research)

- Unconstrained principal simple typing of polymorphic record **merge** does not exist (Wand 1991; Palsberg–Zhao 2003 NP-complete w/ subtyping); the workaround is constraint residuation (design doc §5.9).
- OSF-theory unification against **recursive** sort/schema definitions is undecidable in general; the normalization system is confluent + inconsistency-complete — spec Map→schema checking accordingly.
- Closedness checking is the empirical perf trap at scale (CUE evalv3 rewrite) — seal-time only.
- QTT × rows is a literature void — fields pinned `mw` (D8).

### If it is ever worth writing up

The minimal validating artifact ≈ CIU T6 phases F1a.2 + a seal (row-carrier compound cells + projection-observation propagators + seal as a between-round consumer) + a critical-pair/confluence analysis of the positive rule fragment. The niche is empty as of mid-2026. Not current work; recorded so the context isn't lost.
