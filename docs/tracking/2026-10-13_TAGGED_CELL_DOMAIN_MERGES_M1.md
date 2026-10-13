# M1 — are the domain merges under tagged cells joins? (measured 2026-10-13)

**Serves**: the open decision on the `tagged-cell-value` lattice raised by DEFERRED 148
(options A–E in the sweep merge note §148: pair set / bitmask-keyed join / irredundant
generators / one reader semantics / "is a join" as a checked property). M1 is the measurement
that decides whether B, C and D are sound at all. **Not yet placed in a Series/Track** — tagged
cells are BSP-LE 2 Phase 4; the pressure comes from PAR 4. The owner decides the home; this
file is flat and trivially movable until then.

Written at `cc84ab59` + `74c11cd3` on `deferred-sweep-146-149` (code identical to main
`7a0116ec` apart from DEFERRED 148). Racket 9.3. Probe: `aci-laws.rkt` in the
`racket-performance-probing` skill's `scripts/` (raw output beside it as
`aci-laws.2026-10-13.out`). Rerun: `N=3000 ROOT=<racket/prologos> racket aci-laws.rkt`, about 20 s.

## Result

**Of the seven domain merges that reach `make-tagged-merge` / `compound-tagged-merge` in
production, two are joins (`mult-lattice-merge`, `merge-meta-solve-identity`). The other five
are not.** Three are last-writer-wins *bands* (idempotent and associative, not commutative), exactly
the signature semigroup theory predicts. One (`attribute-map-merge-fn`) is an `equal?`-guarded
monoid whose guard breaks associativity. The type merge (`type-unify-or-top`) is a join on
ground types and solved metas, but **one unsolved meta is enough to break commutativity and
associativity, and the order of arrival decides whether a type contradiction is detected or erased.**
The outer tagged merge inherits each domain's verdict on denotations, as the stated claim
predicts: clean for the two joins, failing for every non-join tested.

## 1. Method

The laws, checked on N = 3000 random triples per law per domain:

- **I**: x ⊔ x = x
- **C**: x ⊔ y = y ⊔ x
- **A**: (x ⊔ y) ⊔ z = x ⊔ (y ⊔ z)
- **Abs**: x ⊔ (x ⊔ y) = x ⊔ y. This follows from ACI, and it catches a guard that makes I hold by fiat.
- **B**: ⊥ is the identity.

Equality is `equal?`, the equality the fire-protocol diff uses (`propagator.rkt:2881`). For the
type domain I also report equality modulo zonking solved metas, so that "solved meta vs its
solution" is not counted as a violation. Alphabets are kept small so that collisions are frequent. Metas:
`?pm1` and `?pm2` are unsolved and `?pm3` is solved to `Nat`, through `current-lattice-meta-solution-fn`, the
same hook production installs. The outer check compares denotations ⟦t⟧(W) for every W ∈ 0..7
under the D.12 reader, with the domain merge passed in as `propagator.rkt:1616` does.

The seven domains were found by grepping every `make-tagged-merge` / `compound-tagged-merge`
call and every `promote-cell-to-tagged` target, excluding `tests/` and `benchmarks/`.

## 2. Results

| # | domain merge | where it reaches tagged cells | I | C | A | Abs | B | verdict |
|---|---|---|---|---|---|---|---|---|
| D1 | `type-unify-or-top` (`type-lattice.rkt:203`) | `elab-fresh-meta` (`elaborator-network.rkt:143`), type universe (`:1060`), `:type` classifier | 0 | **257** | **58** | 1 | 0 | not a join with unsolved metas |
| D2 | `mult-lattice-merge` (`mult-lattice.rkt:49`) | mult universe (`:1061`) | 0 | 0 | 0 | 0 | 0 | **join** ✓ |
| D3 | `merge-meta-solve-identity` (`elaborator-network.rkt:997`) | level and session universes (`:1062-1063`) | 0 | 0 | 0 | 0 | 0 | **join** ✓ |
| D4 | `scope-cell-merge` (`decision-cell.rkt:938`) | relations scope cells (`relations.rkt:2014`, `:2958`, promotions) | 0 | **254** | 0 | 0 | 0 | band (per-key LWW) |
| D5 | `logic-var-merge` (`relations.rkt:1990`) | `cell-id` args promoted at `relations.rkt:2676`, `:2759` *when* they are logic-var cells (those sites promote any `cell-id?` — inferred, not measured) | 0 | **659** | 0 | 0 | 0 | band (LWW) |
| D6 | `attribute-map-merge-fn` (`typing-propagators.rkt:447`) | the attribute map promoted at `typing-propagators.rkt:1209` | 0 | **146** | **25** | **149** | 0 | guarded monoid |
| D7 | `(λ (o n) n)` | `atms.rkt:644`; the promote default `propagator.rkt:1809` | 0 | **2017** | 0 | 0 | **1994** | band (LWW), no ⊥ |

The outer `make-tagged-merge(Dᵢ)` was compared on denotations. D2 and D3 had 0 violations on every
law. D1 had C 432 and A 55. D4 had C 616. D5 had C 1197. D6 and D7 were not run through the outer check.

**Attribution:**

| sub-case | C | A | Abs |
|---|---|---|---|
| D1a ground types only | 0 | 0 | 0 |
| D1b ground + solved meta (modulo zonk) | 0 | 0 | 0 |
| D1c ground + one unsolved meta (modulo zonk) | 74 | 22 | 0 |
| D1d ground + two unsolved metas (modulo zonk) | 251 | 27 | 0 |
| D6a `:type` facet only (ground) | 0 | 0 | 0 |
| D6b `:usage` facet only (`add-usage`) | 0 | **36** | **151** |
| D6c `:warnings` facet only (`append`) | **164** | **42** | **164** |

## 3. Findings

**F1. The LWW domains (D4, D5, D7) are bands, and the measurement matches that signature exactly.**
Last-writer-wins, x ⊔ y = y, is the right-zero semigroup. Per-key last-writer-wins on maps is a
product of right-zero semigroups with ⊥ adjoined. Such a structure is idempotent and associative but not
commutative, and that is precisely what was measured: I, A and Abs hold, C fails. A semilattice
is a *commutative* band, so these three merges are one law short of a join. The consequence is concrete:
two different bindings of one variable under one worldview do not produce a contradiction. The
later write silently replaces the earlier one (`{y=b} ⊔ {y=a} = {y=a}`; `a ⊔ b = b`). The
comment at `atms.rkt:631-641` asserts that this case never arises ("within a single branch the SAME
(assumption, value) pair is never written twice with different values"). That is an invariant
claimed in prose. It has never been checked, so it needs M2's instrumentation, not a reading.
D7 additionally lacks ⊥ as an identity (`x ⊔ 'bot = 'bot`), because `make-tagged-merge` absorbs only `'infra-bot`.
By reading the six promote call sites, I found none that promotes a cell whose merge is
`'none`, so the `propagator.rkt:1809` default appears to be unreached.

**F2. The `equal?` guard in `attribute-map-merge-fn` (`typing-propagators.rkt:466`) makes
idempotence true by fiat and breaks associativity.** `:warnings` merges with `append` (a free
monoid) and `:usage` with `add-usage` (pointwise semiring addition, a commutative monoid). Neither is
idempotent. The guard `[(equal? old-val val) rec]` passes I only because I literally compares x
with x. It does not make the carrier idempotent, and absorption shows the gap:

```
(m1 m0) ⊔ (m0 m1)                = (m1 m1)
(m1 m0) ⊔ ((m1 m0) ⊔ (m0 m1))   = (mw m1)     ≠ (m1 m1)
```

So re-delivering information that is already present changes the value, and the result depends on
how arrivals are grouped. Whether `:usage` or `:warnings` are ever written to a promoted, tagged attribute map
is a question about how often this happens in production, so it belongs to M2. The algebraic fact stands
regardless: a sum cannot be the merge of a cell that can be re-written. The `add-usage` docstring
(`qtt.rkt:68-ff`) already separates the sequential *sum* from the alternation *join*. The
attribute map uses the sum.

**F3. `type-unify-or-top` has two separate defects, and the measurement shows both.**

- **(a) The binder arms of `try-unify-pure` discard the unified body.** Pi in both branches
  (`type-lattice.rkt:459`, `:471`), Sigma (`:481`), and lam (`:502`) each compute the unified
  codomain, second component, or body, then return **the first argument's** original. The comment at `:468-470` justifies this
  with "they're structurally equal after unification", but that is false in *pure* mode, where unification refines a
  meta instead of assigning it. Evaluated: `Pi(Nat,?pm1) ⊔ Pi(Nat,Unit) = Pi(Nat,?pm1)`. The `Unit` is
  lost, and swapping the arguments returns `Pi(Nat,Unit)`. Binder-free constructors go through
  `generic-merge` and keep the merged components, which matches D1a and D1b being clean.
- **(b) The "conservative meta handling" fallback (`type-lattice.rkt:215-218`) neither absorbs
  information nor is order-independent.** When unification fails and either side has an unsolved meta, it
  returns one input instead of `type-top`: the concrete side, or the second side if both have metas.
  This erases contradictions that no meta solution could repair: `Pi(Nat,?pm1) ⊔ (Nat ∪ ?pm1)`
  returns the union, and the swapped order returns the Pi. Combined with (a):

  ```
  (Pi(Nat,?pm1) ⊔ Pi(Nat,Unit)) ⊔ Unit   = Unit         ;; contradiction erased
  Pi(Nat,?pm1) ⊔ (Pi(Nat,Unit) ⊔ Unit)   = type-top     ;; contradiction detected
  ```

  > **After F3(a) (`5ec697bf`, 2026-10-13):** this combined witness no longer fails. Both groupings give
  > `type-top`, because the inner merge now keeps `Pi(Nat,Unit)`. A witness that needs only (b), evaluated at
  > `5ec697bf` under the probe's meta-solution function: `(Bool ⊔ Pi(?pm1,Nat)) ⊔ Pi(Nat,?pm1) = Bool`, but
  > `Bool ⊔ (Pi(?pm1,Nat) ⊔ Pi(Nat,?pm1)) = type-top`, since `Bool ⊔ Pi(?pm1,Nat) = Bool` despite the rigid head clash.
  > The fallback is duplicated in `type-lattice-merge` (`:172-173`). Script `f3b-witness.rkt`; record: the
  > sweep merge note § F3(a).

  The same three facts produce a type error or no type error depending on how they arrive.
  A merge that can return something *below* one of its inputs is not monotone, so this is outside
  what CALM covers, not just a commutativity wart. It came in with the PPN 4C T-3 Role B migration (`37aaba2b`)
  and was documented then as deliberate ("same as type-lattice-merge").

**F4. The outer tagged merge is exactly as sound as its domain merge.** This is a measurement on
these samples, consistent with the theorem in the analysis: ACI domain ⇒ denotation-preserving outer
merge, for the pair set and for the keyed and irredundant forms. Joins in (D2, D3), joins out.
Non-joins in, and the failures carry through.

## 4. What this does to options A–E

- **E is not hypothetical. It is the finding.** Five of seven production merges fail the property
  that CALM, the D.12 reader and any parallel executor assume. On today's sequential BSP the results are
  deterministic but depend on order. Under PAR 4, where order depends on the schedule, they become
  nondeterministic for D1, D4, D5 and D6 cells. **Deterministic is not the same as correct.**
- **B (keyed join on write)** is sound for D2 and D3 only. For the bands it reorders folds across keys
  and changes results. For D1 it moves the point where contradictions are detected or erased.
  Doing B before E is not justified.
- **D (one reader semantics)** is sound for the compound universes over D2 and D3 (mult, level,
  session). It is **not** sound for the type universe (D1) until F3 is fixed.
- **C (irredundant generators)** was already declined, and now there is a second reason: subsumption
  needs a correct ⊑, and D1's ⊔ cannot yet supply one.
- **A (the pair set, today's state)** is the only option that is sound for every domain. That is
  not a virtue: it is sound only because it postpones the non-join to read time, where order still decides the result.

Suggested order (a conjecture about sequencing; the owner decides): **fix F3(a)** first. It is local, and the defect is clear-cut. *Prediction, not yet checked:* the fix removes
the D1c and D1d A-law violations that come from the Pi arm, but not the ones from (b).
*Outcome (`5ec697bf`, 2026-10-13):* consistent but weak, since it predicted a decrease of unstated size: A went
22 → 15 (D1c) and 27 → 25 (D1d), with the remainder from (b). It did not address C, which ALSO fell (74 → 28,
251 → 187). The PAR 4 note's restatement had added "none of the C violations"; that claim is refuted and
corrected there. Then do **the design work on F3(b)**: what should a
meta-blocked unification produce? The principled answer is a residual, meaning a suspended constraint,
rather than picking one input. That is a lattice-design question, not a patch. Next, **F1 and F2 as one
decision**: a band merge must become a join with ⊤ (a conflicting binding means contradiction), or be
declared non-monotone at a stratum boundary. A monoid facet must move to a set (`:warnings`) or
out of cell-merge entirely (`:usage`). Then E as a registered, checked property. Only after that
do D and B.

## 5. Candidates for the owner's register (unnumbered; see the merge note on why)

1. `try-unify-pure` binder arms return the first argument's body instead of the unified one
   (`type-lattice.rkt:459, :471, :481, :502`). Fix shape: close the unified body back over the
   fresh fvar. No `close`/`abstract` helper exists by that name (grep), so the inverse of
   `open-expr` must be located or written. Regression: D1c and D1d, A-law cases.
2. `type-unify-or-top` meta fallback (`:215-218`) is non-inflationary and order-dependent and
   erases rigid contradictions. Design work: suspended unification as a lattice element.
3. LWW bands under tagged cells (D4, D5, D7): conflicting same-worldview bindings are overwritten,
   not detected. First step: an instrumented assertion of the `atms.rkt:631` invariant over the
   suite (M2).
4. `attribute-map-merge-fn` `equal?` guard over monoid facets (`typing-propagators.rkt:466`;
   `:warnings` append, `:usage` add-usage). Fix shape: `:warnings` as a set. Decide whether
   `:usage` belongs in a cell merge at all.
5. "Is a join" as a checked property of every merge handed to `make-tagged-merge` /
   `compound-tagged-merge`. Today it is rackcheck in a probe. The by-construction form is a
   declared algebraic-properties registration (the SRE lens Q2, made executable).

## 6. Limits of this measurement

- The inputs are synthetic. **Whether production ever presents these inputs** (two unsolved-meta
  types meeting in one cell, conflicting bindings under one worldview, `:usage` on a tagged map)
  is M2's question, and it is unmeasured. The algebraic facts do not depend on it. How urgent each
  fix is does depend on it.
- Not covered: the `:context` facet (`context-cell-merge`) and `:constraints` (`constraint-merge`),
  plus mult-metas inside `Pi` multiplicities, level terms, and the union arm beyond depth 1.
- 3000 samples per law is a test that can fail, and it failed where expected. It is not a proof.
  The "0 violations" rows for D2 and D3 are backed by the fact that both are flat lattices with ⊤,
  which are joins by construction. They are two-level arguments, not just two green rows.
