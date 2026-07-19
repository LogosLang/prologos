# Rel Track 1 — Relational Language Usability (Stage-3 Design)

**Series**: [Rel](2026-07-19_REL_MASTER.md) · **Track**: 1 — **Relational Language
Usability** · **Date opened**: 2026-07-19 · **Stage**: 3 (DESIGN) — Aspect-A core
**LOCKED**; B/C/D open.

> **Status banner**: The **Aspect-A NAF invalidation fork (Q-A2) is SETTLED** —
> **E-with-B** (belief-layer per-binding narrowing), locked after two grounding
> audits, an adversarial options-panel, and dynamic + structural probes; the
> mechanism is **verified safe** (§5 A.2). The NTT model, SRE lens, and adversarial
> challenge for Aspect A are finalized. Aspects **B/C/D + polish remain in design**.
> Implementation of Aspect A may begin (main-session + per-change gate). Per the
> objective-PIR gate, this track carries a mandatory `X.close` phase and gets a PIR.

---

## 1. Summary

The first Rel track works through **relational-language usability**, gated on one
**major correctness issue** (negation-as-failure leaks under open-variable
enumeration). Three aspects + polish, one held research item, one UCS deferral:

- **Aspect A — NAF/guard correctness** (PRIORITY): `solve (not G)` echoes
  unevaluated; the on-network NAF path leaks the wrong member under open-var
  enumeration; an on-network guard over an unresolved var crashes. Fix on the
  **on-network** path (owner ruling).
- **Aspect B — typed solution rows**: `solve` is currently untyped (`expr-hole`).
  Type rows from two first-class sources — **codata observation** and **schema
  projection** — keyed by field name.
- **Aspect C — schema-as-relational-facts + validation**: extend the already-
  realized a-priori fact typing (`defr R : Schema`) toward the relational "spec"
  vision (rule clauses, signature-as-typing-source).
- **Aspect D — efficient fact representation + query optimization**: a deeper,
  possibly frontier research agenda. **Stage 0/1 (research + design artifact) is in
  scope this track**; implementation is picked up here or spun out as a separate
  track (owner's call).
- **Polish**: answer-set dedup, drop `_anon` wildcard keys, predicate-declaration-
  order keys.
- **Deferred to a later UCS track**: `?v:Type` as CLP(X) domain-constraint
  *resolution*. This track uses only the **static-typing** reading of type info.

---

## 2. Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| **S3** | This design doc — Aspect-A settled (E-with-B, NTT, SRE, challenge); B/C/D open | 🔄 | **A-core LOCKED** (Q-A2 = E-with-B); B/C/D design pending |
| **P0** | Acceptance file (`.prologos`) — covers all 3 NAF faces (`{both}` / `{neither}` / partial-drop) + ground-correct + body-local + recursive | 🔄 | `examples/2026-07-19-rel-t1-acceptance.prologos`; runs 0-errors; TARGET markers land as A.2 completes. **P0 refuted "recursion is correct"** |
| **A.1** | Top-level goal-dispatch (echo fix): the **`not` arm** in `run-solve-goal`/`-one`/`-explain` → `solve-single-goal` | ✅ | `reduction.rkt`; guard/cut/conjunction NOT reachable at top level (mini-audit); acceptance + `test-rel-t1-naf.rkt` (3); suite 8922/0 |
| **A.2** | NAF per-binding **belief-clear** (E-with-B) in `process-naf-request` — **FACT generators** | 🔄 core done | `naf-per-binding-mask`; `light-vehicle` `{both}`→`{bicycle}`; acceptance + `test-rel-t1-naf` (5); suite 8927/0 |
| **A.2b** | Rule/recursive-generator NAF — generator **under-tags** the scope cell → **DFS-defer** | ⬜ | `safe-twohop`/`safe-reach`; per-binding can't enumerate (probe: collapsed value); distinct larger change (design §5 A.2 boundary) |
| **A.3** | Safe/floundering — **static** range-restriction gate in `install-conjunction` | ⬜ | No check exists today; Phase-0 prereq |
| **A.4** | Guard: FFI-crash residuation + static floundering; (guard per-binding leak — scope TBD) | ⬜ | S0 fire-once shape ≠ NAF's S1 shape |
| **B.1** | Typed solution rows — codata-observation path | ⬜ | Untyped-relation fallback; first-class |
| **B.2** | Typed solution rows — schema-projection path + rename query-var → field name | ⬜ | Ties to Path-Selection `^` |
| **C.1** | schema-as-facts: rule-clause typing (facts already typed) | ⬜ | Extends `check-relation-schema-rows` |
| **C.2** | signature-schema activation as a logic-var typing source | ⬜ | Currently elaborated-but-dead |
| **D.0/1** | Efficient fact representation + query-opt — Stage 0/1 research + design artifact | ⬜ | Research-heavy; after A; impl pick-up-or-spin-out |
| **POL** | Polish: dedup · drop `_anon` keys · declaration-order keys | ⬜ | |
| **T** | `tests/test-rel-*.rkt` — dedicated test phase (mandatory, during impl) | ⬜ | Not a PIR follow-up |
| **X.close** | Bench matrix · DEFERRED triage · doc-truth sweep · memory fold · **Stage-5 PIR** | ⬜ | Objective-PIR gate |

*(Phase letters ≠ commitment to sequence yet — see §9 Phasing. Status emoji only.)*

---

## 3. Scope — deliverables, held, deferred

### In scope (this track)
- **A** NAF/guard correctness (the gating priority).
- **B** typed solution rows (codata + schema projection).
- **C** schema-as-relational-facts + validation (extend the realized fact typing).
- **D** efficient fact representation + query optimization — **Stage 0/1 (research
  + design artifact) in scope**; implementation pick-up-here-or-spin-out.
- **Polish**: answer-set dedup; drop `_anon` wildcard keys; declaration-order keys.

### Aspect D scope note (owner, 2026-07-19)
Efficient fact representation + query optimization is a **deeper, possibly frontier
research agenda** (best-of query-optimization + data representation for performative
fact queries). Originally marked "Held"; re-scoped by the owner as **Aspect D**:
the **Stage 0/1 research + design artifact IS in scope this track** (survey prior
art — standup conversation + the RPF-track adjacency + external query-opt/columnar/
worst-case-optimal-join literature — and produce the design). **Implementation** is
picked up here OR spun out as a separate design/impl track (owner's call at design
time). Grounds the eventual move of the off-network fact store (currently a
`make-parameter`, name-grained-replace merge) on-network. Sequenced AFTER the A
correctness core (do not front-run the priority).

### Deferred to a later UCS track
- **`?v:Type` as CLP(X) domain-constraint resolution** (FD/interval/set/bool value
  domains solved by arc-consistency propagators). This track uses ONLY the static-
  typing reading of `?v:Type` (if any), and designs Aspect B/C *with the CLP vision
  in mind* — but builds no runtime domain solving. (Prior art:
  `docs/research/2026-03-16_NEXT_GEN_LOGIC_PROGRAMMING.tex`.)

---

## 4. Grounding (verified — two audits, HEAD `b1e881c7`)

From `wf_7ad61165-85d` (relational surface) + `wf_1891cfd0-197` (NAF isolation),
each HEAD-pinned + main-session R-lens-verified. Load-bearing facts only:

### Premise correction (was in the seed / memory)
- **`&>` is the rule-clause separator** (Prolog `:-`, `$clause-sep`; parse-reader.rkt:1796/1974 → parser.rkt:5254), **not a guard/negation operator.** The seed's "Problem 2b — `&>` inversion" is a **stale label**: `defr light-vehicle &> (vehicle v) (license v)` is a plain positive conjunction, so `{:lv "automobile"}` is correct. The owner intended `¬license`; the correct spelling `&> (vehicle v) (not (license v))` hits the *real* bug (A.2 below). **This doc supersedes that label; the seed note + memory are to be corrected at X.close.**

### Aspect A grounding
- **A.1 (echo)**: `run-solve-goal`/`-one`/`-explain` dispatch only on `expr-goal-app?`/`expr-rel?`/`expr-unify-goal?`/`expr-is-goal?`, then `[else (expr-solve goal*)]` (reduction.rkt:517/611/636) echoes `not`/`guard`/`cut`/conjunction unevaluated.
- **A.2 (leak) — root confirmed to the bit**: (1) ONE naf-bit per conjunction, allocated in the `[(not)]` arm via `solver-assume` (relations.rkt:2021), inherited by every enumerated generator binding; (2) `process-naf-request` reads `v` ONCE (scope-cell-merge last-write-wins collapse) + evals the negation ONCE + clears the single bit (relations.rkt:118/146/239). A single Boolean bit over all bindings ⇒ only `{both leak}` or `{neither}`. Ground queries route to a *correct* DFS path (`solve-goal-propagator` `[(null? query-vars)]`, relations.rkt:2880/2907); only the **free-var Tier-2 ATMS path** leaks.
- **Substrate already isolates per-branch** — facts (per-row `solver-assume`+fact-bit, relations.rkt:2461/2491) + clauses (per-clause bit) = propagator-design.md **Variant C**. `vehicle(v)` already tags bicycle@fact0 / automobile@fact1.
- **A.3 (floundering)**: NO ground/floundering check exists anywhere (grep-confirmed). A never-bound negation var silently "succeeds."
- **A.4 (guard crash)**: `guard-fire` hands a **raw** `expr-logic-var` to `eval-fn` on bot (relations.rkt:2118/2140) → FFI marshal crash (foreign.rkt:91). Residuation prior art exists (discrimination's residuate-on-bot, relations.rkt:720; a no-op fire-once is not consumed, propagator.rkt:3384). Guard shares NAF's single-bit per-binding structure but evaluates at **S0** (fire-once), not the **S1** handler — different fix shape.

### Aspect B/C grounding
- `solve` is a bare `expr-hole` in BOTH checkers (typing-core.rkt:2930, qtt.rkt:2161) — typed rows start from nothing.
- Solution-row keys = **query-var names**, not schema field names (reduction.rkt:239-250) — a rename is required to project a schema onto rows.
- **No single ground/free predicate** — the walk is reproduced across 3 goal shapes + the row-build loop is copy-pasted 5×; the goal-app split is non-recursive (nested query-vars silently never become keys). Entry-gate-(b)'s "ONE predicate" must be **built**, not shared.
- **schema-as-facts is a-priori static** — `defr R : Schema` type-checks fact rows before registration, reusing the F1 primitives (`schema-field-type->expr`+`check`, driver.rkt:814-822). BUT only `||` facts, not `&>` rule clauses.
- Two unbound representations: unresolved var → own-name fvar; missing key → `(expr-fvar 'none)` (path-dependent vs `expr-error`). Anon `_` → `:_anon<gensym>` keys.

---

## 5. Aspect A — NAF/guard correctness (the priority core)

### A.1 — top-level dispatch (shallow)
Add `not`/`guard`/`cut`/conjunction arms to the three top-level goal runners so a
bare relational goal at top level is *run*, not echoed. **Design point**: decide
the full accepted top-level goal grammar once, applied uniformly to
`solve`/`solve-one`/`explain` (the critic flagged all three share the gap).

### A.2 — NAF per-binding isolation (the deep core) — **SETTLED: E-with-B (belief-layer per-binding narrowing)**

**Decision (locked after two grounding audits, an adversarial options-panel, and
dynamic + structural probes):** the S1 NAF handler `process-naf-request`
generalizes its **single-shared-bit belief-clear** (the `worldview-cache` AND-NOT
at relations.rkt:239-242) to a **per-binding belief-clear**: enumerate the
generator's tagged bindings, test the negation per binding, and AND-NOT the
**failing** bindings' own **fact-bits** out of the `worldview-cache`. This stays
in the **belief layer** (`decisions-state` untouched) — the layer a NAF
contradiction belongs to.

**The bug, restated (≥3 faces, one cause):** the current handler collapses the
generator var to ONE binding and clears ONE shared bit ⇒ **over-include `{both}`**
(collapse picks an unblocked binding → keep the bit), **over-exclude `{neither}`**
(picks a blocked binding → clear the bit), or **partial-drop** (a richer generator
set drops the wrong subset) — all three P0-acceptance-confirmed. Per-binding
belief-clear fixes every face at once. **Scope (corrected at P0):** NAF **forces**
the on-network path (`has-naf-or-guard?` ⇒ `use-propagator?`, stratified-eval.rkt:216),
so **all free-var NAF is on-network and buggy** — fact, body-local, **and recursive
alike** (the P0 acceptance refuted an earlier "recursion routes to DFS and is
correct" premise — that was a coincidental single-element test; `safe-reach` over
`reaches(x)={y,z,w}` drops `w`). Only **ground queries** (0 query-vars → DFS) and
**all-ground negated sub-goals** (the handler's existing DFS sub-case,
relations.rkt:177-206) are already correct.

**Why E-with-B and not the alternatives (the decision record):**
- The space factored into three axes — IDENTITY (reuse fact-bit / fresh
  `solver-amb` bit) × MECHANISM (belief-narrow the *derived* `worldview-cache` /
  existence-narrow the *primary* `decisions-state`) × DETECTION (per-binding /
  anti-join, §5.G). The invalidation fork is IDENTITY × MECHANISM.
- **IDENTITY = B (reuse the existing per-fact-row bit).** Verified: the only
  enumerating goal kind is `app` (facts + rules); facts and rules-over-facts tag
  each binding with a **distinct, non-zero** fact-bit (2^aid, relations.rkt:2491);
  there is **no enumerating builtin** (no `member`/`between`) → **the A-fallback is
  unneeded** for the current language. (A's dual-bit was *intrinsic* — the
  install-time naf-bit can't be skipped before binding-arity is known — so A was
  principle-dominated by B; keeping A "just in case" was the belt-and-suspenders
  red flag, avoided.)
- **MECHANISM = belief-narrow the derived cache (NOT existence-narrow the primary).**
  The "narrow the primary = purer" premise was **refuted by the code**: NAF *and*
  guard invalidation have *always* direct-written the derived `worldview-cache` and
  never touched `decisions-state` — the **established belief-narrowing idiom**, and
  exactly what lets NAF coexist with belief-subset row-enumeration. The codebase
  deliberately separates `decisions-state` (which assumptions **EXIST**) from
  `worldview-cache` (which are **BELIEVED** for reads, a possible subset —
  atms.rkt:583-596). A NAF contradiction is a per-branch **belief** statement, so
  belief-narrowing is its layer. Existence-narrowing (Option D: a new between-round
  `solver-retract` stratum) is a bigger, first-of-its-kind change whose projection
  re-fire would **clobber** belief-subset enumeration — a semantic overreach. (D's
  ordering-race, the earlier top concern, actually resolves *safely*; D was set
  aside for the belief/existence collision + minimality, not feasibility.)
- **Option C (compound nogood) RULED OUT** — nogoods are not projected into the
  worldview-cache (only decisions-state is), so a compound nogood leaves
  dissolution visibility unchanged.

**Verified safe (E-with-B holds under scrutiny):**
- The production free-var enumerator `dissolve-solver-pu` (relations.rkt:2964)
  **honors** the belief-clear: `bitmask-visible?` (relations.rkt:2764) gates every
  enumerated row against the E-narrowed `worldview-cache`, so a cleared binding
  vanishes.
- The **contingent clobber is unreachable**: the NAF handler is a **value-tier**
  handler; its sole main-net write is `worldview-cache` (a cell with **no**
  propagator-input dependents) → no worklist → no S0 restart → nothing narrows
  `decisions-state` after the clear → the projection never re-fires before
  dissolution reads (relations.rkt:239-242 / 2957 / 2964; propagator.rkt:3488-3495).
- The belief-subset enumerator `solver-state-solve-all` that *could* have collided
  is **dead code** (no production caller).

**The build (net-new machinery — not a one-liner):** `process-naf-request` today
computes ONE `inner-provable?` boolean and clears ONE `naf-bit-pos`
(relations.rkt:122/239). E-with-B adds: (1) enumerate the generator's tagged
bindings (`net-cell-read-raw` + `tagged-cell-value-entries`, the same primitive
dissolution uses at relations.rkt:2706); (2) per binding, test the negation under
that binding's worldview; (3) map each **failing** binding → its fact-bit (2^aid);
(4) AND-NOT those bits from `worldview-cache`. Lands at the **value-tier** NAF site
(relations.rkt:239-242) — **not** the guard's S0-tier clear (relations.rkt:2151,
clobber-exposed; its own safety is a separate item, §A.4).

**Two pre-existing scope boundaries E/B cannot paper over** (flagged, not
introduced by this track):
- **Body-local-generator NAF** — `p(x) :- q(x,y), not r(y)` where the NAF var `y`
  is a **body-local** intermediate. NAF *forces* the on-network path
  (`has-naf-or-guard?` ⇒ `use-propagator?`, stratified-eval.rkt:216, no threshold
  escape), but body-local `y` gets **no on-network cell** (clause-env = head params
  only; raw-symbol args silently skipped) → the bindings E would AND-NOT never
  materialize. **Fix path: extend the escape-valve the NAF handler already uses** —
  it DFS-defers the all-ground sub-case today (relations.rkt:177-206) — to also
  DFS-defer body-local-generator NAF (the DFS solver binds body-local vars via
  clause-var freshening and handles NAF correctly). This is *not* off-network
  scaffolding; it routes a structurally-unrepresentable-on-network shape to the
  engine that handles it, mirroring the existing all-ground precedent.
- **bm=0 gating-only success markers** cannot be belief-cleared (a bm=0 row is
  unconditionally visible, relations.rkt:2765). Fact-generator bindings are **safe**
  (non-zero bits); a narrow edge to note in the acceptance file.

**Implementation note (A.2 core, 2026-07-19) — the boundary is BROADER than
body-local NAF vars.** The A.2-core per-binding belief-clear (`naf-per-binding-mask`)
fires for **fact generators** (`light-vehicle`: `{both}`→`{bicycle}` ✓). But a
debug trace showed **rule/recursive generators under-tag even when the NAF var is a
head param**: `twohop` (rule with a body-local join) and `reaches` (recursive) do
NOT materialize the NAF var's per-branch tags on the shared scope cell — the var
resolves to a single collapsed value (or one entry), so `naf-per-binding-mask`
returns `#f` and falls back to the single-bit path (`safe-twohop` `{neither}`,
`safe-reach` partial-drop unchanged). So the boundary is not just "the NAF var is
body-local" but "the **generator** doesn't materialize per-branch tags," which
includes rule + recursive generators. **A.2b** = the DFS-defer for this class (route
the relation to the DFS solver, which handles NAF correctly — the all-ground-sub-case
precedent), OR deeper generator materialization. A.2-core is scoped to fact
generators; A.2b is a distinct, larger change.

### A.3 — safe / floundering negation (a **static** range-restriction gate)
No safety check exists anywhere today (grep-confirmed). Add a **static,
install-time** range-restriction check in `install-conjunction`'s existing gating
pre-scan (relations.rkt:2190): a variable appearing in a `not` (or `guard`) goal
must also appear in a **positive** body goal. This has the positive-bound-var set
in scope, fires **before** forking, and yields a clean compile-time error —
whereas a dynamic S1-handler seam (`inner-vars-final`) cannot distinguish a
safe-per-binding var from an unsafe floundering one (it lacks the positive-bound-var
set). Phase-0 prerequisite shared by every NAF option, and the hard gate for the
§5.G anti-join. Standard `\+` groundness discipline.

### A.4 — guard
- **FFI crash**: gate guard-fire on condition-var readiness — **residuate** when
  the var reads bot (reuse the discrimination residuate-on-bot substrate), and a
  **flounder terminal** at quiescence (residuation alone is unsound — a never-bound
  guard silently passes). Option "substitute like DFS" is a red herring (subst
  keeps unbound vars; DFS's safety is from goal *ordering*).
- **Per-binding leak**: guard shares NAF's single-bit structure but at S0
  (fire-once), so its per-binding fix differs. **Scope decision [OPEN]**: fix
  guard crash+floundering now (demo-adjacent), defer guard's per-binding leak.

### G (optional) — the anti-join detection reframe (a DETECTION-axis option, deferred)

`gen(v), not q(v)` is structurally a relational **anti-join** `gen ▷ q`. Instead of
the per-binding framing (N fork+quiesce evals), evaluate `q(v)` with `v` **free
once**, collect the kill-set `K = {v : q(v) provable}`, and set-difference the
generator's bindings against `K`. This is on the **DETECTION** axis — *orthogonal*
to the E-vs-D invalidation MECHANISM — and composes atop E-with-B: for fact-based
inner goals (the dominant case) it replaces N evals with **one**.

- **Feasible, MEDIUM cost**: the kill-set harvester **already exists**
  (`dissolve-solver-pu`, relations.rkt:2674 — read raw + tagged entries → rows),
  directly callable with `query-vars = (list inner-var)`. The delta: re-target the
  current `for/or` boolean collapse (must use raw+tagged — a plain read is
  last-write-wins → under-populates `K`); thread the generator var + its tagged
  scope cell into the NAF request `info` (today only `inner-goal/env/naf-bit-pos`);
  tag-promote the generator carrier.
- **Gated on the §A.3 static floundering gate** (free-`v` eval must be
  range-restricted). Behaviorally trivial for the demo case (`solve (license lv)`
  gives `K` finitely today).
- **DEFERRED** as an optimization layered on E-with-B — revisit if per-binding fork
  perf matters or if the anti-join's single-eval elegance is wanted for the
  fact-table path. Not on the Aspect-A critical path.

### NTT model (belief-layer per-binding narrowing in the S1 value-tier handler)

**Correction to the earlier sketches (recorded honestly):** sketch 1 was a nested
`for` (step-think); sketch 2 over-corrected to a **broadcast** — but that is a
*category error here*. The per-binding work is a nested fork + install +
run-to-quiescence living **inside a between-round value-tier stratum handler**,
where a **`for/fold` over the pending set is the canonical blessed shape** (every
stratum handler — `process-naf-request` / `process-resolution` / `process-retraction`
— is a `for/fold`); a nested scheduler run cannot be an S0 broadcast item-fn, and
the broadcast benchmark (light S0 items) does not transfer. Per Cell/Propagator/
**Scheduler** orthogonality (on-network.md), the `for/fold` is the blessed realization
**under the current scheduler**; the per-binding independence is real, so parallel
decomposition is a **deferred scheduler-layer** concern, not "off the table."

```
-- S1 NAF stage: a between-round VALUE-tier stratum handler (for/fold over pending)
stage naf : after S0, tier value {
  handler process-naf(pending) =
    for/fold over (aid, {inner, env, scope}) in pending:
      let bindings = tagged-entries(read-raw(scope))            -- [(bit_β . β)], no collapse
      let failing  = for/fold over (bit_β, β) in bindings:
                       with-worldview bit_β { provable = quiesce(fork, inner[v ↦ β]) }
                       if provable then accumulate bit_β         -- negation FAILS for β
      worldview-cache &= ~(OR failing)                          -- ONE belief-narrow write
}
```

**Mantra audit (corrected):**
- *All-at-once / all-in-parallel* — the per-binding checks are independent; the
  `for/fold` is the scheduler-blessed shape for nested-quiesce between-round work,
  parallel decomposition deferred to the scheduler layer (not step-think, per the
  orthogonality principle). ✔ (scheduler-layer deferral *named*)
- *Structurally emergent* — the enumeration falls out of the tagged-entry structure
  the generator already produced; the handler reads state, it does not dispatch
  control flow over events. ✔
- *Information flow* — negation results → failing-bit set → one `worldview-cache`
  belief-narrow write → dissolution filters. ✔
- *On-network* — every step is `net-cell-read-raw` / `net-cell-write` on cells. ✔
- *Belief layer (SRE, below)* — writes the **derived** `worldview-cache`, leaves the
  **primary** `decisions-state` untouched, so it coexists with belief-subset
  enumeration. ✔

**Full NTT model + Racket-correspondence table to be completed here alongside A.2
implementation** (propagator-track requirement).

### SRE lattice lens (belief vs existence — the corrected reading)
- **Two lattices, deliberately separated** (atms.rkt:583-596): `decisions-state`
  (which assumptions **EXIST**) is one lattice; `worldview-cache` (which are
  **BELIEVED** for reads, a possible **subset**) is another — derived-but-independently-
  writable. The earlier "worldview-cache is a pure derived projection, so narrow the
  primary" reading was **wrong**: the belief cache is a first-class layer the codebase
  writes directly (both NAF/guard invalidation *and* belief-subset enumeration do).
- **A NAF contradiction is a belief narrowing, not an existence retraction.** "In
  this branch, don't *believe* the negated goal's conclusion" narrows the *belief*
  lattice per-binding; it does not claim the binding ceased to *exist*. So the fix
  narrows the belief cache (E), not the existence lattice (D).
- **Why existence-narrowing (D) is the overreach**: narrowing `decisions-state`
  re-fires the projection (a replacement writer, propagator.rkt:955/975), which
  overwrites the belief cache with the full existence bitmask — clobbering any
  concurrent belief-subset. Belief coexists with belief; existence clobbers belief.
- **Monotone/CALM**: the per-binding failing-bit set accumulates monotonically
  within the handler; the belief-narrow is the non-monotone step, correctly isolated
  at the S1 value-tier stratum boundary (after S0 quiescence).
- **Between-round, value-tier**: the belief-narrow is a between-round atomic action
  (one write per handler pass), not a within-round threshold — consistent with S1
  running after S0 quiescence, and the reason the contingent clobber is unreachable.

### Adversarial principles challenge — **RESOLVED** (worked through)

The first-pass challenge + an independent options-panel + dynamic/structural probes
resolved the fork. Outcome, with the challenges that actually *moved* the decision:

| Decision | Catalogue | Challenge → resolution |
|---|---|---|
| **Fix on-network (not DFS)** | ✔ the leak lives on-network | NAF *forces* on-network anyway; DFS-defer is reserved **only** for the structurally-unrepresentable body-local-generator shape (the existing all-ground precedent), not as a quick fix. |
| **MECHANISM = belief-narrow (E) not existence-narrow (D)** | ✔ minimal; matches the established idiom | The "narrow the primary is purer" premise was **refuted by the code** (NAF/guard *always* belief-narrow); D's existence-narrow would **clobber** belief-subset enumeration. A NAF contradiction *is* a belief statement. **E chosen.** |
| **IDENTITY = B (reuse fact-bit)** | ✔ reuses existing per-branch isolation; minimal | The "silently under-isolates for rule generators" risk was **probed away**: rules-over-facts tag per-branch; no computed enumerating generator exists → **A-fallback unneeded** (a dual path was the red flag; avoided). |
| **The `retract`-call = imperative dispatch?** | (raised as the deepest mantra challenge) | **Moot under E**: E does a belief-narrow *write*, not a `solver-retract` call; the emergent-narrowing (original Option E) form needed new contradiction→belief wiring that doesn't exist, for no gain. |
| **Guard crash → residuate + flounder** | ✔ reuses residuate substrate | Residuation alone is unsound (silent pass) — the **static** floundering gate (§A.3) is the load-bearing pair, not optional. |

**Red-flag scan (clean)**: no dual path (A-fallback dropped, not kept-just-in-case);
no off-network scaffolding (DFS-defer is the *existing precedent* for an
unrepresentable shape, named); no belt-and-suspenders (single belief-narrow
mechanism); the belief/existence layer choice is *named and justified*, not
catalogued.

---

## 6. Aspect B — typed solution rows

`solve` starts from `expr-hole`. Two first-class typing sources (owner: codata as
first-class as schema'd):

- **B.1 codata-observation path** — for untyped relations, the row's value types
  are the *observed* literal types (final-coalgebra reading; the F1 `{:a 1}.a :
  Int` machinery, one layer up). Row keys stay query-var names.
- **B.2 schema-projection path** — for schema-typed relations, project the
  schema's field types onto the free positions and **rename query-var → field
  name** (owner nudge; ties to Path-Selection `^` dynamic key-rename). Bridge is
  positional (goal-arg i ↔ param i ↔ field i), threaded *before* the ground/free
  split collapses positions.

**Prerequisite**: build the **ONE shared ground/free predicate** consumed by BOTH
reduction and typing (entry-gate b) — do not reproduce the walk (the drift-bug
class). This is a foundation both A.2 (per-binding enumeration) and B need.

**Design points [OPEN]**: keying strategy (rename vs fresh positional Record);
reconciling the two unbound representations (codata: "unobserved" unifies them).

---

## 7. Aspect C — schema-as-relational-facts + validation

- **C.1** — extend the realized a-priori fact typing to **rule clauses** (`&>`),
  which currently register unchecked. This makes "the relational spec types both
  records AND relations" (demo framing) true for derived tuples, and grounds typed
  rows over rule-relations (Aspect B).
- **C.2** — activate the **signature schema** as a logic-var typing source. Today
  a relation's declared param types are elaborated but **dead** (never type the
  clause vars). Activating them is the no-new-syntax way to get "typing info
  present on the logic var" (owner Q3). An explicit `?v:Type` *static* surface is
  a stretch (token collision forces a spaced form).

---

## 8. Polish
- **Answer-set dedup** — `solve` returns one row per derivation path (diamonds →
  duplicate rows). Add distinct/answer-set semantics.
- **Drop `_anon` wildcard keys** — `_` gensym keys (`:_anon1655`) leak into result
  maps; drop anon vars from projection.
- **Declaration-order keys** (owner) — present row keys in predicate/fact
  declaration order, not hash order.

---

## 9. Phasing proposal **[OPEN — to confirm]**

Proposed order (A first, per owner priority):
1. **P0** acceptance file.
2. **A.1** echo dispatch (shallow, independent).
3. **A.2 + A.3** NAF per-binding isolation + floundering (the core; needs the
   ONE ground/free predicate foundation).
4. **A.4** guard crash + floundering (guard per-binding leak: scope TBD).
5. **B + C** typed rows + schema-as-facts (share the ground/free predicate + the
   rename machinery).
6. **Polish**.
7. **T** dedicated tests (interleaved, not deferred).
8. **X.close** bench + doc-truth + PIR.

---

## 10. Closing phase (`X.close`) — reserved (mandatory)
Bench matrix (NAF-path + records-path A/B; feature microbench for the delivered
surface) · DEFERRED triage · doc-truth sweep (correct the seed's `&>` label +
memory + Rel Master + Roadmap) · memory fold · **Stage-5 PIR** (16-question
checklist-first). The roadmap row does not flip ✅ until the PIR lands.

---

## 11. Open questions

**Resolved (Aspect A):**
- **Q-A2** invalidation fork — ✅ **RESOLVED: E-with-B** (belief-layer per-binding narrowing); verified safe (§5 A.2).
- **Q-round** placement — ✅ **RESOLVED: between-round value-tier** stratum handler (the current NAF site); a `for/fold` over the pending set (not a broadcast — category error corrected).
- **Q-name** — ✅ **RESOLVED: "Relational Language Usability."**

**Still open:**
- **Q-A4** guard scope: fix crash + static floundering now, defer guard's per-binding leak (S0 fire-once shape differs from NAF's S1)?
- **Q-body-local** — confirm the DFS-defer for body-local-generator NAF is the chosen boundary (vs on-network body-local cell allocation, a much larger change) at A.2 implementation.
- **Q-B** (Aspect B) keying: rename query-var → field, vs fresh positional Record.

---

## 12. References
- Grounding: `wf_7ad61165-85d` (surface), `wf_1891cfd0-197` (NAF isolation) — dailies `2026-07-19_dailies.md` LOG.
- Seed: [`2026-07-19_REL_SOLVE_TYPING_NOTE.md`](2026-07-19_REL_SOLVE_TYPING_NOTE.md) (its `&>` label superseded by §4).
- Rel Master: [`2026-07-19_REL_MASTER.md`](2026-07-19_REL_MASTER.md).
- Rules: `.claude/rules/propagator-design.md` (broadcast, set-latch, watcher/threshold variants), `.claude/rules/stratification.md` (S1 NAF), `.claude/rules/structural-thinking.md` (retraction as narrowing), `.claude/rules/on-network.md` (mantra).
- Path-Selection (downstream, `^` rename): `2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md`.
- `?v:Type` CLP prior art (deferred): `docs/research/2026-03-16_NEXT_GEN_LOGIC_PROGRAMMING.tex`.
