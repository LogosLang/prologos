# Rel — Relational Language Series (Master)

**Founded**: 2026-07-19 (owner-directed, during CIU T6 F1b.close).
**Status**: newly opened; no tracks locked. First artifact = the un-named
solve-typing/NAF track's implementation note (a Stage-3 seed):
[`2026-07-19_REL_SOLVE_TYPING_NOTE.md`](2026-07-19_REL_SOLVE_TYPING_NOTE.md).

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
| (un-named) | Solve typing + NAF correctness | typed solution rows (D25.3 charter, moved from CIU) + the `not` / `&>` negation-as-failure correctness gaps (found dogfooding `foray.prologos`) | ⬜ SEED | [note](2026-07-19_REL_SOLVE_TYPING_NOTE.md) |

## Sequencing (owner through-line, 2026-07-19)

solve ergonomics/typing (this series) → **Path Selection** (CIU) → return to
**DEMO** work. Solve typing is upstream of Path Selection because Path Selection
over solution sets is its highest-value consumer.

## When a track opens

Stage-3 discipline (DESIGN_METHODOLOGY.org): grounding audit over the logic engine
(`relations.rkt` NAF stratum, the `solve` surface, the `&>`/guard desugaring, the
solution-row reduction) → Stage-3 design doc (the typed-rows entry gates + the NAF
fix) → implementation. The un-named track's note is the seed for that Stage-3 doc.
