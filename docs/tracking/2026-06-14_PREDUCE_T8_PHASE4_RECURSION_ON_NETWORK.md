# PReduce Track 8 — Phase 4: Recursion (β/δ/ι) on-network

**Created**: 2026-06-14
**Status**: ✅ 4a DONE (`2bf9b5e`; suite 8678 all-pass; viz shows recursion as
union propagators for fib ≤ ~7). 4b/4c = documented research frontier (they add
per-step network work → worsen the perf wall on Racket; SH/Zig-era). See §8
Findings. Phase 5 owner-gated.
**Owner posture (2026-06-14)**: "for this prototype branch, you lead and approve
design. don't ask me for details. I will review after the implementation is
complete." → I make the design decisions here; the methodology gates (NTT model,
Network Reality Check, full-suite + acceptance) still apply.
**Plan**: `2026-06-14_PREDUCE_DEFAULT_AND_ONNETWORK_COMPUTE_PLAN.md` (Phase 4)
**Builds on**: Phase 2 (`2026-06-14_PREDUCE_T8_PHASE2_DISPATCH_AS_PROPAGATOR.md`)
— the dispatch stratum + the congruence-template realization.

## 1. The gap (grounded at HEAD)

The recursion path is `whnf`'s β / ι / δ arms (reduction.rkt:1534-1571), each of
which calls

```
(preduce-ingest-delta redex #:compute (lambda () (whnf <unfolded>)))
```

Two things are off-network here:

1. **The step RECORDING.** `preduce-ingest-delta` (reduction.rkt:1394-1408) on a
   miss runs `(compute)` and writes the result as the redex class's `:best` via a
   **direct `net-cell-write`** (cost 0). Unlike the arithmetic path (Phase 2:
   dispatch stratum → `apply-rule` → `eclass-union`, a propagator), the recursion
   STEP is recorded as a bare cell-write — so the viz shows a value change, not a
   propagator firing. ("aren't reductions performed by propagators?" — for
   recursion, today, no.)

2. **The step DRIVER.** The `#:compute` thunk is `(whnf <unfolded>)` — the
   recursive `whnf` call is the off-network control flow that drives recursion.

The viz goal — *show fib/factorial reducing via propagators* — is primarily
blocked by (1): each recursion step must become a propagator the viz can render.
(2) is the deeper "the network DRIVES the recursion" thesis endgame.

## 2. The gradient (why Phase 4 is not monolithic)

Making the recursion **rules** declarative (so the Phase-2 dispatch stratum fires
them) splits three ways by difficulty:

| Construct | Rewrite | Expressible as a declarative rule today? |
|---|---|---|
| **ι** (natrec) | `(natrec mot base step (suc n)) → (app (app step n) (natrec mot base step n))` | **Yes** — pure structural template (captures + re-assembly; no compute, no subst). Leaves (suc/pred/arith) are already rules. |
| **δ** (def unfold) | `(fvar f) → body(f)` | **Partly** — the body is FETCHED from the global env, not transformed; needs an env-lookup template op (or eager body interning). |
| **β** (app of lam) | `(app (lam body) arg) → subst(0, arg, body)` | **No** — de Bruijn substitution is a binder-aware operation the list-form template language cannot express. The genuine research core. |

Plus the rule path has a **form-representation mismatch**: arithmetic interns
LIST-forms (`(int+ (lit a) (lit b))`) that the LHS patterns match; the recursion
path interns the EXPR-STRUCT itself (`preduce-ingest-delta val`). A declarative
recursion rule needs either list-form interning of redexes or an expr-struct-aware
matcher. (Tracked for 4b.)

## 3. Decision — sub-phase Phase 4

I am sequencing Phase 4 to deliver the viz goal first, on the most principled and
tractable footing, and to be honest about the research frontier:

- **4a — recursion step as a UNION propagator (IMPLEMENT NOW).** Replace
  `preduce-ingest-delta`'s direct cell-write of the result with **intern-result +
  `eclass-union`** (the DPO model: the e-class becomes `{redex, result}` joined by
  a union propagator). This brings the recursion STEP recording on-network as a
  union propagator — UNIFORM across β/δ/ι, and identical in mechanism to the
  arithmetic path's `eclass-union`. The viz then shows the fib/factorial tree as a
  web of union propagators. The `#:compute` driver stays off-network (that's 4b).
  This is the high-value, principled, tractable core of Phase 4.

- **4b — ι driver on-network via the dispatch cascade (ASSESS after 4a).** Make
  the natrec unfold a declarative registry rule fired by the Phase-2 dispatch
  stratum, and generalize dispatch emission so the RHS result class itself
  requests dispatch (the cascade), driving ι recursion from the network rather
  than `whnf`. Requires: the form-representation fix (intern natrec redexes as
  list-forms), a weak-head cascade control (stop at WHNF, don't over-saturate),
  and fuel-bounding. Attempt for the ι fragment if 4a lands cleanly; this is the
  "network DRIVES recursion" demonstration.

- **4c — δ / β as declarative rules (RESEARCH FRONTIER, documented not built).**
  δ needs an env-lookup template op; β needs the template language to model
  binders + de Bruijn substitution. This is a substantial sub-design (template
  language extension) — framed here, deferred with an explicit reason, not
  rationalized as done. β-subst-on-network is the PReduce thesis's hardest claim.

## 4. NTT model (4a)

```
;; The recursion-step e-class IS {redex, result}, joined by a union propagator.
;; (Same shape as the arithmetic fold's eclass-union; the difference is only WHO
;;  computes the result — a native whnf step here, a dispatched rule for arith.)

cell eclass[redex]  : eclass-value          -- :best, :alts, :canonical (lattice)
cell eclass[result] : eclass-value

propagator union(redex, result) :              -- sre-structural-relate 'eclass-refine
  reads  eclass[redex].:canonical, eclass[result].:canonical
  writes eclass[redex], eclass[result]         -- joins: shared canonical, min-cost :best
  fire:  the join lands the cost-0 result as the class :best (monotone, CALM-safe)
```

| NTT construct | Racket (4a) |
|---|---|
| intern result class | `pr/eclass-intern net1 hc result #:cost 0` |
| union propagator | `pr/eclass-union cid result-cid` (installs sre-relate) |
| land the join | `run-to-quiescence` |
| memo (cross-cmd) | `pr/store-record-reduction` (unchanged) |

## 5. Network Reality Check (4a)

1. **`net-add-propagator` added?** YES — `eclass-union` installs an
   `sre-make-structural-relate-propagator` per recorded recursion step (replacing
   a bare `net-cell-write`).
2. **`net-cell-write` produces the result?** YES — the union propagator writes the
   joined `:best` (the cost-0 result) when it fires; the redex class reads it.
3. **Trace?** intern redex → `(compute)` → intern result → union propagator →
   `run-to-quiescence` → joined `:best` → caller reads. The compute (native whnf)
   is still off-network (4b), but the STEP is now a propagator. ✓

(Honest scope: 4a brings step RECORDING on-network, matching arithmetic and the
DPO model; the recursion DRIVER is 4b. This is exactly the on/off-network split
the branch directive recorded.)

## 6. Risks & gates (4a)

- **Perf**: each recursion step now interns a result class + installs a union
  propagator + a `run-to-quiescence` (vs one cell-write). fib(15) ≈ 2k steps →
  ~2k extra classes/props. Regression EXPECTED + ACCEPTED (plan §1, charter §5.8).
  Watch only for pathological blow-up (timeout), not slowdown.
- **Admissibility**: an inadmissible result must still return + skip the memo —
  preserve the existing `with-handlers` (eclass-intern of an inadmissible result
  raises → caught → return result unmemoized).
- **Memo semantics**: the join's `:best` must be `(cons 0 result)` so the next
  encounter is a cost-0 hit (existing `(zero? (car existing-best))` check). The
  redex is interned at cost 10, result at cost 0 → join picks cost-0. ✓
- **GATE**: full suite green (8674 baseline); acceptance file
  (`examples/2026-06-14-onnetwork-reduction.prologos`) 0 errors; the recursion
  steps visible as union propagators (viz/trace spot-check).

## 7. Implementation steps

- **4a**: edit `preduce-ingest-delta` miss path → intern result + `eclass-union` +
  `run-to-quiescence`, under the existing admissibility handler; keep store-record.
  Gate: targeted `test-preduce-ingest.rkt` + full suite + acceptance.
- **4a-T**: extend `test-preduce-ingest.rkt` — assert a β/δ/ι step records a UNION
  (the redex class and the result share a canonical / the redex class gains the
  union propagator), not just a value.
- **4b**: (separate sub-phase doc if pursued) ι rule + cascade emission + weak-head
  control + fuel.

## 8. Findings (post-4a, 2026-06-14) — the perf wall + the fib-naive answer

4a is correct (full suite 8678 all-pass) and **achieves the viz goal**: a small fib
exports with the recursion shown AS propagators. fib 6 (`/tmp/fib-6.prologos`):
172 rounds, 73 topologies, 0 errors, **up to 18 propagators firing in one round,
75 rounds with >1** — the union (eclass-refine relate) propagators are the
recursion steps (props with `inputs == outputs`, two e-class cells). Pre-4a the
viz showed "only one propagator [fib 15]"; 4a makes the recursion tree a web of
union propagators. ✓

**The perf wall (honest, expected — the PReduce verdict).** Larger fib is
impractical to reduce/export under 4a:

| n | reduce_ms (no observer) |
|---|---|
| fib 6 | 449 |
| fib 8 | 1344 (741 reduce_steps) |
| fib 10 | 4552 |
| fib 12 | 24052 |
| fib 15 | >120s (timeout) |

Super-linear → the recursion is **not memoized**, and each step now pays a union +
`run-to-quiescence` (vs a discarded cell-write pre-4a). The viz export is worse
still: the observer diffs cells O(cells) PER ROUND, and 4a turns each step into a
round → quadratic. fib 8 export times out; **fib ≤ 6–7 is the practical viz size**
on the Racket substrate.

**Why naive fib does NOT memo-collapse (this answers `fib-naive.prologos`'s own
question).** The example asks whether the hashcons shares identical `[fib k]`
subterms. It does **not** — because β reduces under **call-by-name**: the redex is
`(app <fib-lam> <unreduced-arg>)`, and `[fib 5]` reached via `[fib 6]`
(arg `(int- 6 1)`) vs `[fib 7]` (arg `(int- 7 2)`) has **different redex digests**
even though both denote `[fib 5]`. Different digests ⇒ no hashcons hit ⇒ no memo
⇒ the exponential tree is recomputed, not shared.

**The path to collapse (research frontier, not built):** normalize the β arg to a
canonical value BEFORE forming/interning the redex (call-by-value at the memo key),
so `(app <fib-lam> (int 5))` is shared. This is a reduction-STRATEGY change
(eager arg evaluation) with semantic implications (laziness) — it belongs to a
dedicated design, and the wall-clock payoff is the SH/Zig lowering the PReduce
verdict already routes perf through. The observer's per-round O(cells) diffing
should also become incremental (a viz-export optimization) before large traces.

**Decision (I lead/approve per owner posture):** 4a is the landed Phase 4
deliverable — recursion-step recording is on-network as union propagators, and the
viz shows recursion as propagators at tractable sizes. 4b (network-DRIVES-recursion
via the ι cascade) and 4c (β/δ as declarative rules; β needs list-form de Bruijn
subst) are the documented frontier: both ADD per-step network work, so they make
the perf wall worse, not better, on Racket — they are SH/Zig-era / dedicated
research, not landable improvements on this branch now. Phase 5 (bypass
`reduction.rkt`) remains the owner-gated terminal.
