# PAR 4 · P0 input — most domain merges under tagged cells are not joins (M1); what D.2 should take from it

**Serves**: PAR 4, Pre-0 → **P0.5 (D.2)** of [`2026-10-12_PAR_4_D1_DESIGN.md`](2026-10-12_PAR_4_D1_DESIGN.md).
It bears on assumption **A-2** (S0 merges are joins), on the Q1 audit's §5.2 / §9
([`…_P0_Q1_MONOTONICITY_AUDIT_DRAFT.md`](2026-10-13_PAR_4_P0_Q1_MONOTONICITY_AUDIT_DRAFT.md)), on D.1 §6.1
(`'flat-tagged`), and on the P2 phase gate in [`…_P0_MEASUREMENTS.md`](2026-10-13_PAR_4_P0_MEASUREMENTS.md) §6.
**Status**: an input for D.2. Every proposal here is **unapplied**. The owner placed this work in
PAR 4 on 2026-10-13. **Written by** the DEFERRED-sweep session (branch `deferred-sweep-146-149`) at
`c53e1fb1`. Production code there is identical to `7a0116ec`, except `decision-cell.rkt` (DEFERRED 148,
`c62cd267`). Citations below are at `7a0116ec`, the Q1 audit's pin, unless marked.
**Not edited**: `LOG.md` and the D.1 doc. A concurrent PAR 4 session may hold them, so the
proposed LOG entry is in §8.

## 0. Result

Seven domain merges reach `make-tagged-merge` / `compound-tagged-merge` in production. **Two are
joins**: `mult-lattice-merge` and `merge-meta-solve-identity`. **Three are last-writer-wins bands**
(idempotent and associative, not commutative). **One** is an `equal?`-guarded monoid whose guard
breaks associativity. **`type-unify-or-top`** is a join on ground types, but one unsolved meta
breaks commutativity and associativity, and **the order in which writes arrive decides whether a type
contradiction is detected or erased**. The Q1 audit had already classified most of these statically.
M1 confirms them by execution and adds four findings (§2). Separately, SRE's property-inference machinery
declares the type domain ACI with a sample set that **cannot fail** (§3). That makes option E, "is a join" as a
checked property, partly built and fail-open.

**Why this belongs in PAR 4's early phases, not later:** the P2 gate is "full suite under DIRECT
K=1 green" (P0 §6). DIRECT changes arrival order, and these merges are order-sensitive by measurement.
Unless the merges are fixed or fenced first, P2's oracle will mix merge defects with design defects (§4).

## 1. How this came up

DEFERRED 148 made `tagged-cell-value` entries a *set* (`c62cd267`): the join is now idempotent,
and a write that carries no information returns the old value `eq?`. That closes the duplicate-entry half
of the Q1 audit's §5.2 row for `make-tagged-merge` (`decision-cell.rkt:480-493`). The
live site was `:492`; the `:453/:465` the entry cited have no production callers.

The PAR 4 heap baseline still grew, because its workload is an **ascending chain** at each
bitmask. A set of pairs bounds re-writes, not chains. Bounding a chain needs a bitmask-keyed map with
pointwise join, `(b·v₁) ⊔ (b·v₂) = (b·v₁⊔v₂)`. That form preserves the denotation

$$⟦t⟧(W) = \mathit{base} \sqcup \bigsqcup\{v \mid (b,v) \in t,\ b \subseteq W\}$$

**only if the domain merge ⊔ is ACI** (associative, commutative, idempotent). The proof is direct: the same bitmasks are visible in the same worldviews.
M1 checks that precondition.

## 2. What M1 measured

Record: `docs/tracking/2026-10-13_TAGGED_CELL_DOMAIN_MERGES_M1.md` on the branch
(`git show c53e1fb1:docs/tracking/2026-10-13_TAGGED_CELL_DOMAIN_MERGES_M1.md`; after merge it is
at [`../../../2026-10-13_TAGGED_CELL_DOMAIN_MERGES_M1.md`](../../../2026-10-13_TAGGED_CELL_DOMAIN_MERGES_M1.md)).
Its `decision-cell.rkt` line numbers are post-148: `scope-cell-merge` is `:938` there and `:887` at
`7a0116ec`. Probe: `aci-laws.rkt` in the `racket-performance-probing` skill's `scripts/`, run with N = 3000 per
law. The laws: I idempotence, C commutativity, A associativity, Abs absorption `x⊔(x⊔y)=x⊔y`, and ⊥ identity.
Equality is `equal?` (the fire-protocol diff), and modulo zonking solved metas for the type domain.

| domain merge | reaches tagged cells at | C | A | Abs | verdict | Q1 audit |
|---|---|---|---|---|---|---|
| `mult-lattice-merge` | mult universe (`elaborator-network.rkt:1061`) | 0 | 0 | 0 | **join** | — |
| `merge-meta-solve-identity` | level and session universes (`:1062-1063`) | 0 | 0 | 0 | **join** | — |
| `scope-cell-merge` (`decision-cell.rkt:887`) | relational scope cells (`relations.rkt:2014`, `:2958`) | 254 | 0 | 0 | band | §5.2 ✓ confirmed |
| `logic-var-merge` (`relations.rkt:1990`) | `cell-id` arguments promoted at `relations.rkt:2676`, `:2759` *when* they are logic-var cells (those sites promote any `cell-id?`; which merges they carry is unmeasured, so P0-8) | 659 | 0 | 0 | band | §5.2 ✓ (as S1 only) |
| `(λ (o n) n)` (`atms.rkt:644`) | the solver-state tagged cell | 2017 | 0 | 0 | band, and ⊥ is not an identity | **not listed** |
| `attribute-map-merge-fn` (`typing-propagators.rkt:447`) | `tm-cid` after promotion (`:1209`) | 146 | 25 | 149 | guarded monoid | §5.2 ✓ (as "not idempotent") |
| `type-unify-or-top` (`type-lattice.rkt:203`) | `elab-fresh-meta` (`elaborator-network.rkt:143`), type universe (`:1060`), the `:type` classifier | 257 | 58 | 1 | not a join once a meta is unsolved | §5.2 ✓ (as "non-commutative") |

The outer `make-tagged-merge(⊔)`, compared on denotations for every W, inherits each verdict: clean for the two joins
and failing for every non-join tested.

**What M1 adds to the audit:**

1. **`try-unify-pure`'s binder arms discard the unified body.** Pi in both branches (`type-lattice.rkt:459`,
   `:471`), Sigma (`:481`) and lam (`:502`) each compute the unified codomain or body, then return the
   *first argument's* original. The comment at `:468-470` says the two sides are "structurally equal after unification". That
   does not hold in pure mode, where metas are refined but never assigned. Evaluated:
   `Pi(Nat,?m) ⊔ Pi(Nat,Unit) = Pi(Nat,?m)`, while swapping the arguments gives `Pi(Nat,Unit)`. This defect is new. It is a
   local fix and a sequential correctness bug.
2. **The meta fallback (`type-lattice.rkt:215-218`) is not inflationary, and it can erase
   contradictions.** The audit calls it non-commutative. M1 shows it is non-associative and
   returns a value *below* one of its inputs:
   ```
   (Pi(Nat,?m) ⊔ Pi(Nat,Unit)) ⊔ Unit   = Unit       ;; contradiction erased
   Pi(Nat,?m) ⊔ (Pi(Nat,Unit) ⊔ Unit)   = type-top   ;; contradiction detected
   ```
   > ⚠ **CORRECTION (2026-10-13, after F3(a) `5ec697bf` on `deferred-sweep-146-149`).** **Withdrawn as a witness
   > for F3(b) alone.** This item presents it under the fallback, but it needs BOTH defects: the M1 record introduces
   > it with "Combined with (a)" (`2026-10-13_TAGGED_CELL_DOMAIN_MERGES_M1.md:121`), and this note dropped the
   > qualifier. F3(a) made the inner merge
   > return `Pi(Nat,?m)` (dropping the unified `Unit`), and the fallback then erased `Pi(Nat,?m) ⊔ Unit` to
   > `Unit`. With F3(a) fixed, the inner merge is `Pi(Nat,Unit)` and **both groupings give `type-top`**. F3(b)
   > is still real (D1c keeps 15/3000 A violations); a witness that needs only the fallback, evaluated at
   > `5ec697bf` under the probe's meta-solution function (`?pm3 := Nat`, `?m` unsolved):
   > ```
   > Bool ⊔ Pi(?m,Nat)                     = Bool       ;; rigid heads Bool vs Pi: no solution of ?m can unify them
   > (Bool ⊔ Pi(?m,Nat)) ⊔ Pi(Nat,?m)      = Bool       ;; contradiction erased
   > Bool ⊔ (Pi(?m,Nat) ⊔ Pi(Nat,?m))      = type-top   ;; contradiction detected
   > ```
   > The mechanism, read at `type-lattice.rkt:217-218` (`5ec697bf`, unchanged since `7a0116ec`): when
   > `try-unify-pure` fails and EITHER side contains an unsolved meta ANYWHERE, the merge keeps the side without
   > one, even when the heads already clash rigidly. The same fallback is duplicated in `type-lattice-merge` at
   > `:172-173`, so a D.2 decision on F3(b) covers both sites. With no solution function installed,
   > `has-unsolved-meta?` cannot see the meta and the same merge gives `type-top`, so the probe's environment
   > matters. Script: `f3b-witness.rkt` (racket-performance-probing `scripts/`).
   A merge that can go down is outside A-1 and A-2 altogether. Under DIRECT, whether a program
   gets a type error would depend on the schedule. Attribution: ground types and solved metas are
   clean (0/3000 on every law). One unsolved meta is enough to fail.
3. **The attribute-map `equal?` guard (`typing-propagators.rkt:466`) hides non-idempotence from
   an idempotence test and breaks associativity.** `:usage` (`add-usage`, a sum) and `:warnings`
   (`append`) are monoids. The guard makes `x⊔x = x` true literally, and absorption exposes the gap:
   `(m1 m0) ⊔ ((m1 m0) ⊔ (m0 m1)) = (mw m1)`, but `(m1 m0) ⊔ (m0 m1) = (m1 m1)`. Re-delivering information
   the cell already holds changes its value. An I-only check passes. Abs is the law that catches it.
4. **`atms.rkt:644` is a band whose correctness rests on an invariant stated only in a comment** (`:631-641`:
   "within a single branch the SAME (assumption, value) pair is never written twice with different
   values"). If that invariant holds, the merge should *be* an identity-or-contradiction merge, like
   `merge-meta-solve-identity`. The invariant is then enforced by construction rather than asserted.
5. **The positive list is measured.** Of these seven, the mult, level and session universes satisfy A-2 for this
   domain. That is the first concrete input to the audit's §9 "narrower option" (DIRECT only for
   propagators whose output cells have a join merge).

## 3. Why SRE's property machinery did not catch it (fail-open)

`make-sre-domain` takes `#:declared-properties` (`sre-core.rkt:215`). `infer-domain-properties`
(`:1706`) sample-tests commutativity, associativity and idempotence, and joins any counterexample into `prop-contradicted`.
So option E already exists as infrastructure (SRE Track 2H). Three gaps:

- **The declared merge is not the installed merge.** `type-sre-domain` declares the three
  join properties `prop-confirmed` for `'equality` (`unify.rkt:105-109`), whose merge is
  `type-lattice-merge` (`unify.rkt:71`). The merge actually installed on tagged type cells is
  `type-unify-or-top` (`elaborator-network.rkt:143`, `:1060`; the classifier in
  `classify-inhabit.rkt`).
- **The confirming samples cannot fail.** `tests/test-sre-algebraic.rkt:111` samples six ground
  atoms with no meta-solution callback, so `has-unsolved-meta?` is `#f` unconditionally
  (`type-lattice.rkt:87`). Measured with `sre-power.rkt` (skill `scripts/`), exhaustive triples:

  | conditions | `type-lattice-merge` C / A | `type-unify-or-top` C / A |
  |---|---|---|
  | SRE test samples (6 ground atoms, no callback) | 0 / 0 | 0 / 0 |
  | + 2 unsolved metas and 2 binder types, callback installed | **36 / 6** | **36 / 6** |
  | same samples, no callback | 36 / 12 | 36 / 0 |

  Both merges fail under representative samples, and both pass under the test's samples. The declaration
  has never been in a position to fail.
- **Most S0-written domains declare nothing.** `register/minimal`
  (`phase1d-registrations.rkt:104`) registers `scope-cell` (`:131`), `attribute-map` (`:244`) and
  `mult` (`:278`), among about 25 others, with a merge and no declared properties.

## 4. Why this goes before P2, not after

The P2 gate is "full suite under P2 K=1 green" (P0 §6), and P0 §4.4 established that run as the
real DIRECT oracle. DIRECT changes the order in which writes arrive at a cell. Every merge in §2 except the
two joins produces different results for different orders, by measurement. So if P2 lands first, its oracle
failures will mix (i) defects in the H-S design with (ii) merges that were never
order-independent. P0 §4.4 already saw two failures of class (ii): the anti-monotone asc/desc case,
and readiness → `merge-list-append` duplicate. Fixing or fencing the merges first makes P2's gate
measure the design.

There is a second reason. The audit's §9 "narrower option" needs a predicate, *is this
output cell's merge a join?*, evaluated per cell. §3's machinery makes that predicate computable,
once the declarations are attached to the installed merges and the samples have the power to fail.

## 5. Proposals for D.2 (unapplied)

**P0-8 (new Pre-0 item), M2: the exposure census.** This is an env-flagged instrument in the `par4-p0` harness style,
behaviour-neutral, at the merge choke points: the `make-tagged-merge` lambda, the per-component
`compound-tagged-merge`, and the plain-cell merge call in `net-cell-write`. For each domain merge,
count:
- calls;
- calls whose *actual* arguments are order-sensitive (`x⊔y ≠ y⊔x`);
- calls whose result is below an input, i.e. not inflationary (checked as `r ⊔ x ≠ r`);
- same-worldview conflicting bindings, which checks the `atms.rkt:631` invariant;
- disagreements between the compat readers (`meta-universe.rkt:280`, `propagator.rkt:4367`,
  `metavar-store.rkt:504`, oldest match) and the D.12 reader (`propagator.rkt:1616`, join);
- per tagged cell at quiescence: entries, distinct bitmasks, antichain width.

Use the same corpus as P0, plus the forced-ATMS `atms-adversarial` run. This census decides **how urgent** each item
below is (the algebra is settled; whether production hits it is not), decides pair set vs keyed map,
and feeds the E sizing for `'flat-tagged` (§6.2).

**Early sequential fix (in P0.5's defect-landing list, beside DEFERRED 150):** F3(a), the four binder arms. Close the
unified body back over the fresh fvar; the inverse of `open-expr` must be located (no helper with an
obvious name exists, by grep) or written. The regression tests come from the `aci-laws.rkt` D1c/D1d cases.
*Prediction, not yet checked*: this removes the Pi-arm share of D1's A violations but none of the C
violations, which come from the fallback.

> ⚠ **CORRECTION (2026-10-13): the prediction is REFUTED; F3(a) landed as `5ec697bf`.** ~~none of the C
> violations~~: the fix removed C violations as well. `aci-laws.rkt` at N = 3000, same seeds, before → after:
>
> | family | C | A |
> |---|---|---|
> | D1 (elaborator-fresh metas, `:type` classifier) | 257 → **216** | 58 → 49 |
> | D1c (one unsolved meta) | 74 → **28** | 22 → 15 |
> | D1d (two unsolved metas) | 251 → **187** | 27 → 25 |
> | tagged(D1), outer merge over W ∈ 0..7 | 432 → **366** | 55 → 38 |
>
> D1a/D1b stay 0/0; the other outer-merge rows (616 and 1197 C) are unchanged.
>
> The cause of the error is in the defect itself: `Pi(Nat,?m) ⊔ Pi(Nat,Unit) = Pi(Nat,?m)` against the swapped
> `Pi(Nat,Unit)` IS a commutativity violation, produced by the binder arm, not the fallback. The prediction
> attributed every C violation to the fallback without checking. What remains (28/187/366 C) is the fallback's
> share plus anything else non-commutative; F3(b)'s first witness also had to be replaced (§2 item 2). Record:
> the sweep merge note § F3(a).

**Design items for D.2, each needing a decision:**

| item | the question | lean (taste/conjecture) | agreement |
|---|---|---|---|
| F3(b) meta fallback | what does a meta-blocked unification produce? | a residual: a suspended-unification element (an `unify(?m, T)` constraint carried in the lattice) instead of picking one input; ⊤ when the heads are rigid and distinct (Pi vs union) | — |
| F1 bands (scope, logic-var, atms) | conflicting binding under one worldview | join with ⊤: conflict means contradiction; `atms.rkt:644` becomes identity-or-contradiction | the audit's §9 follow-up ("detect conflict instead of new wins") |
| F2 facets | `:usage`, `:warnings` under a cell merge | `:usage` → pointwise join (`qtt.rkt:68`); `:warnings` → set | the audit's §9 (`:usage`) |
| E | "is a join" as the DIRECT-eligibility predicate | declare properties on every merge installed on an S0-written cell, with samples that have power (metas, binders, conflicts); DIRECT only where the declared and inferred values agree | the audit's §9 "narrower option" |
| B keyed map | `'flat-tagged` lattice: pairs vs bitmask-keyed join | decide at P4 (H-F already waits on BSP-LE 3); sound only for domains where E holds | — |

**D.1 text corrections, adding to the audit's list:** §6.1 `'flat-tagged` row: "closes the `:453,465`
non-dedup" should read: closed on the heap tier by DEFERRED 148 at the live site `:492` (`c62cd267`).
The flat record's dedup on append is pair-dedup, which bounds re-writes but **not ascending chains**,
so E sizing must use chain length or the keyed form.

## 6. Candidates for the register (unnumbered)

The main register's NEXT FREE has moved under concurrent sessions (LOG: 157 after `f3d7f5e3`), so
numbering is the owner's to do:

1. `try-unify-pure` binder arms (F3(a)).
2. The `type-unify-or-top` / `type-lattice-merge` meta fallback (F3(b)).
3. Band merges under tagged cells (F1, with the `atms.rkt:631` invariant).
4. The `equal?` guard over monoid facets (F2).
5. SRE declared properties attached to a merge other than the installed one, confirmed by samples that cannot fail (§3). This is
   an instance of `workflow.md`'s "Fail-Open" lesson.

## 7. Limits

- Synthetic inputs. **Whether production presents them is unmeasured**, and that is P0-8.
- Not covered: the `:context` and `:constraints` facets, mult-metas in Pi multiplicities, level terms, and the
  non-tagged S0 merges the audit lists (cell-1, cell-14, cell-15, cell-19, `meta-solution-merge`).
  Their verdicts are the audit's static ones.
- 3000 samples per law is a test that can fail, and it failed where expected. It is not a proof. The two "join"
  verdicts also rest on structure: both are flat lattices with ⊤.

## 7a. A second correction, from DEFERRED 146 (added the same day, `69f64caf` on the sweep branch)

The Stage-1 record's "`champ-lookup` allocates 64 B per read"
(`research/…_STAGE1_CONTENTION_ANALYSIS.md:95, :184`; used as an argument in
`research/…_STAGE1_RESEARCH_SYNTHESIS.md:100` and `…_PRIOR_ART_SYNTHESIS_DRAFT.md:189`) **does not
hold for production reads.** The census probe looked up a *freshly constructed* `(cell-id k)`. That key is
`equal?` to the stored key but not `eq?`, so the probe measured Racket CS's `equal?` on two records: 64 B
per top-level call, from `rumble/equal.ss`'s `deeper-context` box plus a recursion closure. The descent
allocates 0 B. In an instrumented run over `benchmarks/comparative`, 76 % of CHAMP's data-entry
comparisons were `eq?` hits (0 B). The real cost was on **insert of a new key** (20 %, carrying
85 % of the `equal?` bytes), and comparing the stored hash first now removes it. In proportion,
all `equal?` bytes inside CHAMP are 0.04–0.25 % of a run's allocation.

**What this does to the synthesis row:** "persistence buys thread-safe reads at the price of an
allocation per read" should drop the read half. Reads are free. The write half stands: a path copy
costs 492–1147 B per new-key insert at N = 256–65536 (measured after the fix), and that is the real
argument for owner-held records on the hot write path. A text correction is proposed for the
synthesis of record and left unapplied, since that file is owner-owned. The other half of the Stage-1 figure
"~10 % of a light fire's bytes" also needs re-deriving. The corpus-wide census has 95 % of *lookups*
hitting `eq?` (208,437 of 219,651), which suggests lookups inside a fire cost about 0 B. That is an inference from
an aggregate, not a per-fire measurement. Re-measure with the corrected `census.rkt`, which now prints
stored-key and fresh-key rows side by side.

## 7b. Fire context as ambient state has a measured price (DEFERRED 147, same day)

Re-attributing the BSP light fire on the sweep branch (merge note §147) showed that its largest remaining
item is the two `parameterize` forms per fire. `fire-and-collect-writes :2863` binds
`current-bsp-fire-round?` and `current-cell-id-namespace`; `fire-propagator :374` binds
`current-source-loc`. Together they cost **about 496 B of the remaining 928 B** of a read-only fire. That fire
was 1 386 B on main and is 928 B after 147's local fixes: dedup set, `output-set`, dependent folds.
Measured alternatives, per fire:

| fire-context mechanism | B |
|---|---|
| today: 2 bindings, then a nested 1 | 496 |
| one `parameterize` with 3 bindings | 448 |
| one composite parameter (a 3-field struct) | 144 |
| a continuation mark | 0 |
| the context as a field of the network or record passed to the fire | the cost of a struct copy (96 B for the spine today), or 0 if it is part of the executor's record |

These are the parameters the Q1 audit's §6 lists as ambient state read by S0 fires, and Racket threads
inherit them from their creator. So H-S faces one decision with both a correctness side (§6) and a cost
side (this table): **how does fire context reach a fire?** The sweep deliberately did not change it.

## 7c. The compile-limit trap: main's timings from 10-12 20:24 to 10-13 02:55 ran an interpreted compiler (DEFERRED 159; remedied)

DEFERRED 149 turned out not to be a 9.3 regression. At the 9.0→9.3 switch, main's `compiled/` was
rebuilt by a `raco make` without `PLT_CS_COMPILE_LIMIT`, and the compiler's giant `match` modules
(`reduction`, `typing-core`, `elaborator`, `macros`, `qtt`, `zonk`, `substitution`, `parser`, … 15 in all) ran
in the Chez fallback (interpreted outer layer). The runner's `putenv` does not repair this, because up-to-date
`.zo`s never recompile. **Remedied in main at ~02:55** (owner-authorized): rebuilt with the limit; main's suite
went 69.5 → 56.5 s under the same runner. Record: DEFERRED 149 and 159 in main's `DEFERRED.md`; full analysis in the
sweep merge note § 149 (branch `deferred-sweep-146-149` @ `8322459b`).

What it means for PAR 4:

| item | status |
|---|---|
| **`par4-p0` worktree** | **clean now**: 8/8 reference modules match a limited build (same source), `.zo`s written 10-13 02:17. Anything measured there *before* 02:17 cannot be verified after the fact. |
| **timings taken in main's tree** between 10-12 20:24 and 10-13 02:55 | inflated wherever they exercise elaboration or reduction (suite 1.23–1.28×, per-file median 1.15×, worst 25×). The prime suspect by name is `data/par4-p0/parallel-demos-main-7a0116ec-r93.json`. |
| **propagator / scheduler path** | probably unaffected: small nested lambdas stay compiled in the fallback, and 147's per-fire census on main's `propagator` equals a limited build's within 3 B. That is bytes, not wall; re-time anything a decision rests on. |
| **within-run A/Bs** (e.g. DEFERRED 150's threshold 256 vs `#f`; the whale-sharding 110.5 → 68 s) | direction holds; ratios may shift. |
| **the P2 gate** ("full suite under DIRECT at K=1 is green") | two new gate defects bear on it. **DEFERRED 160**: suite-only failures, 2 of 3 full runs at `fd2986cc`, each file passing alone (`test-cond-01`, `test-error-messages`); conjecture: cross-file state in a batch worker, exposed by the LPT dispatch fix. **DEFERRED 161**: a file that ran 0 tests was counted as a pass (`test-generators`, first suite after a cold rebuild). Until both are addressed, a green suite is weaker evidence than it reads, and a red one may not be DIRECT's fault. |

**Before pinning the PAR 4 baseline**: confirm the tree you measure in is a limited build (compare
`compiled/reduction_rkt.zo` with 302 215 B at this source, or time `raco test tests/test-transducer-01.rkt`:
≈ 4.5 s limited vs ≈ 6.1 s not). Then re-run the baseline rows that were taken in main's tree before 02:55.

## 7d. `par4-p0` now has main merged in: `a456c370` (2026-10-13, owner-authorized from the sweep session)

**Why.** Until it had `b45bbf44`, a runner start in `par4-p0` pkilled every batch worker on the machine
(DEFERRED 163), including other sessions' suites. The owner asked the sweep session to bring it up to
main rather than relay the request.

**What was checked before touching it.** The tree was clean (0 dirty lines). It was idle: no process had
its cwd there, and nothing had been modified since 02:22. PAR 4 is between P0 (complete) and D.2. The merge
was made in a throwaway worktree. The one textual overlap, `propagator.rkt`, came out as main's file plus
exactly `par4-p0`'s six hunks (changed lines identical; 147's markers intact). The merged tree was built with
the compile limit. Full suite, BSP: **10 298 tests / 493 files, all pass.** File-by-file against main plus
F3(a): `+9 test-arena-parity.rkt`, with `test-type-lattice` −7 and `test-substitution` −4 (F3(a)'s tests,
which are not on main yet), and nothing else. Then `par4-p0` was fast-forwarded, rebuilt with the limit
(`reduction` / `typing-core` / `macros` `.zo` = 302 215 / 289 697 / 439 415 B, matching a limited build),
and its own `test-arena-parity` passes in place (9/9).

**What it means for PAR 4.** The records citing `4097b1c8` and `fbd5a322` stay valid as records: it was a
merge, not a rebase. Measurements taken on `par4-p0` from now on include, on the measured path:
- 146 (`champ.rkt`);
- 147 (`propagator.rkt`: read-only fire 1 386 → 928 B, read+write 2 819 → 2 232 B, §7b);
- 148 (`decision-cell.rkt`);
- the runner fixes 162–164 (effective LPT dispatch, parent-scoped cleanup, INCOMPLETE on missing results).

`fbd5a322` versus `a456c370` is therefore the natural "as-is / defect-fixed" pair of baselines for P2. F3(a)
(`5ec697bf`) and the suite queue reach `par4-p0` at the next checkpoint merge. The merge commit's message
carries this summary for whoever resumes on the branch.

**Second bring-up, same day: `par4-p0` → `3643f56e`**, a merge of main at checkpoint 2, `01ef2542`. It brings F3(a), which
is on P1's measured path, along with the machine-wide suite queue and the honest gate (DEFERRED 161, 164, 165). A suite
started here now WAITS for any other suite instead of contending with it. Gate on the merged tree: **10 339 tests /
495 files, all pass.** File by file, it equals checkpoint 2's delta plus `+9 test-arena-parity`, and nothing else.
Rebuilt with the limit; `test-arena-parity` and `test-suite-lock` pass in place (19 tests). For P2 baselines:
`a456c370` → `3643f56e` adds F3(a). Name the pair if a merge-law measurement spans it.

## 8. Proposed LOG entry (for whoever holds `LOG.md`)

> ### P0 input from the DEFERRED sweep: 2 of 7 tagged-cell domain merges are joins; SRE's type-domain ACI declaration is fail-open — no commit on main (2026-10-13)
> - **Why / decision**: DEFERRED 148 (set semantics for tagged entries, `c62cd267` on
>   `deferred-sweep-146-149`) raised the keyed-map question, whose precondition is an ACI domain
>   merge. M1 measured that precondition. The owner placed F3 and M2 in PAR 4's early phases. Note:
>   [`2026-10-13_PAR_4_P0_DOMAIN_MERGE_LAWS_NOTE.md`](2026-10-13_PAR_4_P0_DOMAIN_MERGE_LAWS_NOTE.md).
> - **Surprise / correction**: `type-unify-or-top`'s meta fallback can *erase* a contradiction
>   depending on arrival order, which is stronger than the audit's "non-commutative". `try-unify-pure`'s binder arms drop
>   the unified body. The SRE type-domain ACI declaration targets `type-lattice-merge`, not the installed merge, and
>   is confirmed by six ground atoms that cannot fail. D.1 §6.1's "closes `:453,465`" is stale (148 closed it at `:492`).
> - **Next**: D.2 decides P0-8 (M2), F3(a) in the P0.5 defect list, and F3(b)/F1/F2/E as design
>   items, before P2.
