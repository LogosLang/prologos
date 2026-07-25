# Rel (un-named track) — Solve Typing + NAF Correctness (implementation note / Stage-3 seed)

**Date**: 2026-07-19 · **Series**: [Rel](2026-07-19_REL_MASTER.md) · **Status**:
SEED for a Stage-3 design doc/artifact — NOT a design. Captures two coupled
relational-language problems for the first Rel track, so the work is not lost and
a future Stage-3 co-design has a grounded starting point.

---

## Problem 1 — typed solution rows (charter, moved from CIU D25.3)

`solve` results carry NO type at HEAD (`expr-hole`); per-solution ROW types
(`List {unknown : T …}`) would make Path Selection over solution sets TYPED and
let solve output compose with the records/rows type system (project a field, feed
to a typed function). It reuses the F1 row carrier (now complete).

**Why hard (probe-confirmed, F1b.5 options-panel Q5-B)**: solution-row labels are
NOT statically derivable in general — query args are whnf'd before the ground/free
split (which var is *free* → a solution key is a runtime determination), and
anonymous `_` vars become gensym-named keys (`:_g4217`, no static name). So "read
the query-var names into a row type" doesn't work.

**Entry gates** (from the CIU D25.3 charter): (a) define the *typeable-goal
fragment* (registered relation, named args, no anonymous `_`; the rest fall back to
untyped, gate e); (b) ONE shared ground/free predicate consumed by BOTH reduction
AND typing (never a reproduced walk — the drift-bug class); (c) the two-context /
relation-registry audit (incl. relations from cached `.pnet` bodies); (d) reconcile
the TWO unbound representations (unresolved var → own-name fvar vs missing key →
`none`; presence-`'optional` / Option candidates; explain's reserved keys =
the first `'optional` clients — couples to the CIU explain-restructure entry);
(e) display posture vs D23 (untyped relations ⇒ rows of metas — must respect the
F1b.6 escape-boundary tightening).

## Problem 2 — NAF (`not`) correctness (found dogfooding foray.prologos :472–486)

**Grounded probe (2026-07-19, scratch copy of foray's vehicle/license/light-vehicle
clauses — foray is owner WIP, copied not modified):**

```
defr vehicle [?type]  || "bicycle" "automobile"
defr license [?v]     || "automobile"
defr light-vehicle [?v]  &> (vehicle v) (license v)   ;; intended: vehicle ∧ ¬license
```

| Query | Observed | Expected |
|---|---|---|
| `solve (not (license "bicycle"))` | `(solve (not (license "bicycle")))` — **echoed unevaluated** | SUCCEED (bicycle is not licensed) — ground NAF is well-defined |
| `solve (not (license "automobile"))` | echoed unevaluated | FAIL (automobile IS licensed) |
| `solve (not (license v))` (v unbound) | echoed unevaluated | UNSAFE negation (floundering) — should error clearly ("v unbound") |
| `solve (light-vehicle lv)` | `{:lv "automobile"}` — **the LICENSED vehicle (inverted)** | `{:lv "bicycle"}` (the unlicensed one) |
| `solve (light-vehicle "bicycle")` | `nil` — **FAILS** | SUCCEED (`light_vehicle(bicycle)`) |

**What's likely at play**: NAF machinery EXISTS (the **S1 NAF stratum**,
`relations.rkt` `process-naf-request`, per `.claude/rules/stratification.md` —
Fork + BSP + nogood evaluation of `not(G)`, "inverts provability", requires S0
quiescence). But: **(a)** the top-level `solve (not G)` SURFACE does not dispatch
to the NAF stratum — it returns the `not` term unevaluated (even for ground `G`,
where NAF is safe); and **(b)** ~~the `&>` guard operator (light-vehicle = vehicle ∧
¬license) produces the INVERTED result~~ — **REFUTED, see the correction below.**

> **⚠ CORRECTION (Rel T1 §4, landed at X.close 2026-07-25 — the fix this note's
> own §4 reserved).** `&>` is **NOT a guard operator and carries NO negation**:
> it is the rule-clause SEPARATOR, Prolog's `:-` (tokenized `$clause-sep`). So
> `defr light-vehicle &> (vehicle v) (license v)` is a plain positive
> conjunction and `{:lv "automobile"}` was the CORRECT answer to what was
> actually written; the intent was `¬license`, whose correct spelling is
> `&> (vehicle v) (not (license v))`. The instinct ("the negation here is
> wrong") was right; the LOCATION was wrong. Spelled correctly, it hits the
> REAL bug — the on-network NAF single-bit collapse (one naf-bit per
> conjunction, inherited by every enumerated binding ⇒ only {both} or
> {neither} is expressible) — which Aspect A fixed via per-binding belief
> narrowing (`cb0fb1e4`). This mislabel is *premise refutation #1* of the
> track's cascade and the reason "probe before locking a premise" became a
> standing discipline. Authoritative text: design doc §4.

**The track investigated**: the `solve (not …)` surface → NAF-stratum dispatch; the
`&>` clause-separator semantics (per the correction above); **safe-vs-unsafe negation** (ground
`G` runs NAF; unbound `G` floods → a clear "unsafe negation" error, not a silent
echo); and the stratification interaction (S1 NAF fires only after S0 quiesces).

## Coupling — why one track

Both problems are "the relational output/semantics correct AND typed." Typed rows
(Problem 1) presuppose *correct* solve semantics underneath — and NAF (Problem 2)
is load-bearing for trusting any solve result that involves negation or a guard.
Both feed **Path Selection over solution sets** and the **DEMO**. A single Rel
track that gets solve *right* (correct NAF + typed output) is the coherent unit.

## Entry gate for Stage-3

Grounding audit over the logic engine (the NAF stratum + `solve` surface + `&>`
desugaring + solution-row reduction + the two-context relation registry), then the
typed-rows Stage-3 design (entry gates a–e) co-designed with the NAF fix, then
implementation — before Path Selection opens.
