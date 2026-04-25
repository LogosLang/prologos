# EigenTrust Pitfalls — Observation Items (8, 9, 10, 16)

_Companion doc to `docs/tracking/2026-04-23_eigentrust_pitfalls.md` (when that
branch lands). The 2026-04-23 memo enumerated 16 pitfalls hit during the
EigenTrust implementation. Items 1–7 and 11–15 are language/elaboration
defects with their own fix PRs. This doc dispositions the four items that are
**observations** rather than Prologos defects, so no compiler code change is
required for them._

## Pitfall 8 — Exact-Rat arithmetic slows power iteration by orders of magnitude

**Disposition: not a defect; benchmark-scope guidance.**

The slowdown is intrinsic to exact rational arithmetic: each multiplication
can grow numerator and denominator by a small factor, so after *k* steps the
denominators can reach `≈ (10 · max-matrix-denom)^k`. The simplification pass
runs on every operation but cannot prevent growth when the iterates do not
share a common denominator. This is fundamental to choosing exact-Rat as the
numeric domain.

**Action**: continue using exact-Rat for *correctness* tests (golden-output
testing of small fixtures) and use Posit32 / Float variants for
*deep-iteration* benchmarks. The PVec+Posit32 EigenTrust variants in
`benchmarks/comparative/` already follow this split.

If iterate growth ever becomes a Rat-correctness blocker rather than a
performance one, two paths exist:
- Common-denominator normalization across the iterate vector after each
  step (gives bounded growth at the cost of `gcd`-per-step).
- Switch to a fixed-precision rational representation (rational with a
  capped denominator).

Neither is justified by current usage; revisit only if a real workload
demands it.

## Pitfall 9 — Posit32 literals survive nested list/PVec literals correctly

**Disposition: positive observation; no action.**

Where `'[0/1 1/2]` mis-types the Rat `0/1` as Int (pitfall #3, fixed under its
own PR), the Posit literal forms `'[~0.0 ~0.5]` and `@[~0.0 ~0.5]` both
preserve `Posit32` correctly. The reason: the `~` literal prefix has no
bare-Int alias, so the preparser cannot silently re-interpret it as a
different numeric type.

**Validation**: covered indirectly by the EigenTrust Posit benchmarks
(`benchmarks/comparative/eigentrust-pvec-posit.prologos`). Worth adding an
explicit test if pitfall #3's fix introduces any preparse changes that touch
the numeric-literal path; otherwise no work needed.

## Pitfall 10 — PVec `@[...]` literals preserve element types where `'[...]` does not

**Disposition: subsumed by pitfall #3 fix.**

This is the dual side of pitfall #3. `@[0/1 1/2]` correctly elaborates as
`PVec Rat`; `'[0/1 1/2]` mis-elaborates the `0/1` to Int. Pitfall #3's PR
brings the List path in line with the PVec path (or vice-versa, depending on
the chosen fix shape).

After pitfall #3 lands, both literal forms preserve element type uniformly.
No separate fix is needed for this pitfall — close as a duplicate of #3.

## Pitfall 16 — EigenTrust wants column-stochastic, not row-stochastic

**Disposition: algorithm/spec clarification, not a Prologos defect.**

The original 2003 paper defines `c_{ij}` as "peer i's normalized trust in
peer j", giving a row-stochastic `C`. The actual update step is
`t_{k+1} = C^T · t_k` — i.e. `C^T` is what gets multiplied by `t`, and
`C^T` is column-stochastic.

The first List+Rat implementation took row-stochastic `C` and computed
`(C^T · t)` internally via "sum of row-scaled rows" (a transpose-avoiding
trick). This worked but made the invariant awkward to state, and required
users to understand the implementation's trick to interpret the input.

**Action taken in the EigenTrust impl**: take the **column-stochastic** matrix
`M` directly as input. The update is plain matrix-vector multiply
`y[i] = dot(M[i], t)`. The invariant ("each column of M sums to 1") is
checkable via `col-stochastic?` in `O(n²)` and the `eigentrust` entry point
panics if it fails. The "ring fixture" (a column-stochastic permutation
matrix) is a cleaner slow-iteration benchmark than an asymmetric
row-stochastic matrix relying on the transpose trick for interesting dynamics.

This is captured in the EigenTrust implementation branch
(`claude/eigentrust-prologos-implementation-JGszt`) and is a benchmark/algorithm
shape choice. No Prologos compiler change is required.

## Cross-references

- Pitfall fixes (one PR per): #1, #2, #3 (subsumes #10), #4, #5, #6 (already
  landed as #4), #7, #11, #12, #13 (#5 PR), #14 (#6 PR), #15.
- This doc: #8, #9, #10, #16 (observations only).

When the 2026-04-23 eigentrust pitfalls doc lands on `main`, link this doc
from its "Status" or "Disposition" section.
