# Rel — Relational Language Series (Master)

**Founded**: 2026-07-19 (owner-directed, during CIU T6 F1b.close).
**Status**: **Track 1 COMPLETE** (PIR landed 2026-07-25). Track 1 delivered (all aspects + the POL polish roster + an
interleaved spin-out); its Stage-5 PIR is what flips the roadmap row ✅.
Track 2 ("The Fact Store") is chartered-in-seed, not opened.

## Thesis

Group work related to the **relational language** — the logic-programming layer
(`defr` / `solve` / `rel`, the logic engine, negation-as-failure, guards, tabling,
solution-set shapes, and the **typing of relational results**). This is Layer 2
(Relations) of the layered architecture (DESIGN_PRINCIPLES.org § Layered
Architecture). The series owns the relational *surface language + its ergonomics
+ correctness + typing* — as distinct from the constraint-solver *substrate*.

## Why a new series (vs UCS)

Considered **UCS** as the home (it mostly touches the relational language), but it
is not a thematic fit: UCS is about the *unified constraint-solver substrate*,
whereas Rel is about the relational *surface language* features, ergonomics, and
correctness. Keeping them distinct: **UCS = the solver substrate**, **Rel = the
relational language on top of it**, **CIU T6 F1 = the records/rows type layer** the
relational output flows into.

## Relationship to other series

- **CIU T6 F1 (records/rows) — the type substrate the output flows into.** `solve`
  returns a list of maps (rows); typing those rows REUSES the F1 row carrier +
  presence machinery (now COMPLETE). D25 (solve solution-set shape) + D25.3
  (typed-solution-rows charter) originated in CIU; **the typed-rows charter MOVES
  here** (its home was a CIU DEFERRED entry — now pointed at this series).
- **Path Selection (CIU, OPEN owner conversation) — a high-value consumer.** Typed
  solution rows are what make Path Selection over solution *sets* typed.
  **Sequencing (owner, 2026-07-19): solve ergonomics/typing lands BEFORE Path
  Selection** — Path Selection over solution sets needs typed rows, and it is a
  demo-relevant use case.
- **DEMO series (the through-line).** The dependency-resolver demo uses `solve` +
  relations; correct negation-as-failure + typed solve output are demo-relevant.

## Tracks

| # | Track | Description | Status | Artifact |
|---|---|---|---|---|
| 1 | Relational Language Usability | NAF/guard correctness · typed solution rows (schema projection + codata + RULE-relation rows) · typed logic vars + schema-as-facts · fact-representation research (Stage 0/1 + cheap wins) · the POL polish roster. **Deferred to UCS**: `?v:Type` CLP resolution (Track 6). | ✅ **COMPLETE** (PIR 2026-07-25). A ✅ (A.1·A.2·A.2b·A.3·A.4·SC) · B ✅ (B0·B1·B2) · C ✅ (C.a·C.b·C.c; C.d → UCS T6) · D ✅ (artifact + D.2 a–d) · B3 ✅ (rule-relation rows, the owner's headline aspect) · POL ✅ (.1–.10, incl. the POL.7/8/9 syntax cluster) · **SUB spin-out ✅** (a LIVE silent-wrong-answer bug in `shift`/`subst`, fixed by NbE open-the-binder). Scaffolding → BSP-LE Track 3 ([seed](2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md)). **[PIR](2026-07-25_REL_T1_PIR.md)** — 93 commits, +174 tests, ~13 bugs + 1 class, 45% of churn from unplanned work (POL + SUB). | [design](2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md) · [seed](2026-07-19_REL_SOLVE_TYPING_NOTE.md) · [SUB](2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md) |

> Note (2026-07-19): the seed's "`&>` inversion" framing is **superseded** — `&>`
> is the rule-clause separator, not a negation op; the real bug is the on-network
> NAF open-var leak. See the design doc §4.

## Sequencing (owner through-line, 2026-07-19)

solve ergonomics/typing (this series) → **Path Selection** (CIU) → return to
**DEMO** work. Solve typing is upstream of Path Selection because Path Selection
over solution sets is its highest-value consumer.

## When a track opens

Stage-3 discipline (DESIGN_METHODOLOGY.org): grounding audit over the logic engine
(`relations.rkt` NAF stratum, the `solve` surface, the `&>`/guard desugaring, the
solution-row reduction) → Stage-3 design doc (the typed-rows entry gates + the NAF
fix) → implementation. The un-named track's note is the seed for that Stage-3 doc.
