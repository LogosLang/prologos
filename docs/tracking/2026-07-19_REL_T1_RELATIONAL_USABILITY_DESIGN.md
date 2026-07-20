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
| **A.2b** | Rule/recursive-generator NAF — **ROOT reframed (probe-verified): the body-local-var gap**, not tabling-flattens-worldviews (that is second-order = BSP-LE Track 3). Minimal slice = **adaptive-dispatch DFS-routing** (`reachable-has-body-local-rule?` in `use-propagator?`) | ✅ | `bcd02d6d`; `safe-twohop`→`{w}`, `safe-reach`→`{y,w}` via DFS (parity-verified); A.2-core fact-NAF stays on-network; +2 tests (`test-rel-t1-naf` 7); acceptance 8/8; suite 8929/0. **SCAFFOLDING** — retirement owner BSP-LE Track 3 (on-network body-local threading + SLG completion + worldview-preservation §9.6) |
| **A.3** | Safe/floundering — **static** range-restriction gate (PERMISSIVE / Prolog-mode) at **defr registration** (Site A) + top-level `solve(not G)` runners (Site B); **not** `install-conjunction` (home reframed by the A.3 audit) | ✅ | `74fa9df2`; `check-relation-floundering`; unsafe → clear error; residual (mode-dependent free-arg call) = standard Prolog `nil`, deferred; +3 tests; suite 8932/0 |
| **A.4** | Guard correctness — **DFS-routing** (`reachable-has-guard?` Check 4). On-network guards have 3 bugs (struct-resolution; single-bit per-binding collapse; S0 narrow re-projected); guards live in tabled rules → inherit the tabling seam. Route to DFS (correct); on-network mechanism prototyped + deferred to Track 3. | ✅ | `6b56397d`; `positive-edge`→`{(a,b,3),(c,d,5)}`; +2 tests (`test-rel-t1-naf` 12); acceptance 9/9; suite 8934/0. **SCAFFOLDING** — retire w/ BSP-LE Track 3 ([seed](2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md)) |
| **SC** | Solver config surface + WFS acceptance (owner-added, in scope): (a) **preparse gap FIXED** (`19d9f8ae`) — `process-string-ws` now uses `merge-preparse-and-tree-parser` like `process-file`, so `solver`/`solve-with named` work in the REPL/editor path; (b) wfle-acceptance runs **0-errors** (owner fixed the dotted `ns`); outputs verified correct **except** F2 guard (`positive-edge` leaks `w=0` — a **PRE-EXISTING on-network guard bug**, confirmed at `b0b88df2`, → **A.4**) | 🔄 SC.2 ✅ | 130 REPL/LSP/WS tests + full suite 8932/0 green. Remaining SC.1: F2 guard is A.4; optional `;;N=>` markers (blocked on A.4 for the guard rows); 2 stale `;;=>` comments (77 two-hop, 82 employees — outputs actually correct) |
| **B (Stage-3)** | Typed solution rows — design SETTLED (§6): `Κ′` keys · schema/facts/rules type-source · `#f`-dispatch+imperative-compute · shared kernel · 5th-refusal reachability | ✅ | panel `wf_e00d9318-3b6` + R-lens; owner co-design 2026-07-20 |
| **B0** | Shared ground/free **kernel** (§6.5) — keys-out, strip-isolated, partition-not-`set!`; refactor 3 goal-app row-build sites onto it | ✅ | `reduction.rkt`: `free-arg` + `query-var->champ-key` + `classify-goal-args`; `extract-query-info` delegates; 3 goal-app key-sites routed; exported for B1. Zero behavior change (probe byte-identical, acceptance 0-err); suite **8934/466/0** |
| **B1** | First typed slice — schema'd goal-app, ALL 5 arms: `solve-row-type`/`goal-app-schema-row` (typing-core, shared by qtt) build `expr-Record` (`Κ′` keys from B0, `schema-field-type->expr` types) + per-arm container + per-field arity-degrade; 5 solve structs registered `#f` (dispatch parity) | ✅ | `relations.rkt` require (cycle-free); **composition typed** `(solve-one q).w : Int`; containers CORRECTED to runtime (solve-one=bare, explain=`List<row \| _>` dyn, no Option/Answer); +7 tests `test-rel-t1-typed-rows.rkt`; `count-answers` helper fixed (counted type braces); suite **green** |
| **B2** | Codata: un-schema'd facts → join fact-literal types; rule-relation → loose row + runtime-at-the-end; first-class-static-codata → C.1 | ⬜ | F1b.6/D23 posture; presence-refinement → C.1 |
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
includes rule + recursive generators. A.2-core is scoped to fact generators.

### A.2b — reframed + LANDED (minimal DFS-routing slice), 2026-07-19 (commit `bcd02d6d`)

> **This section supersedes the earlier "tabling worldview-preservation" framing.**
> A grounding-audit (`wf_c2f8bfa3-db2`) + options-panel (`wf_9c6eb408-522`) + two
> dynamic probes reframed the root cause: "tabling flattens per-branch worldviews"
> is **second-order** (owned by BSP-LE Track 3); the **first-order** defect is a
> value-correctness bug — the **body-local-var gap** — and the minimal correct fix
> is a routing refinement, not a tabling-infra rebuild.

**ROOT CAUSE (probe-verified, the reframe):** the on-network ATMS engine builds
`clause-env` from **head params only** (relations.rkt:2382-2385/2407-2410), and
`resolve-term` returns the **bare symbol** for a non-param var (:1950-1953, treated
as a ground atom). So a clause whose answer threads through a **body-local**
(non-param) join/recursion variable produces an **INCOMPLETE answer set on-network**
— *before* any worldview-tag question arises. Probe (forced on-network via a no-op
NAF): `twohop(a,c):-edge(a,b),edge(b,c)` → **`{}`** (the join var `b` never binds);
`reaches` (recursive) → **base case only `{y}`**. DFS baselines: `{z,w}` and
`{y,z,w}`. Fact generators and **param-passthrough** rules (`direct(a,c):-edge(a,c)`)
are **complete** on-network (probe-confirmed) — the defect is *specifically*
body-local-var rule clauses. This mechanically explains the A.2-core observations:
`safe-twohop→{neither}` because `twohop` is empty on-network; `safe-reach` drops
`w`/`z` because `reaches` never derives them. (6th premise-refutation of the arc.)

The earlier "tabling flattens worldviews" finding is **real but second-order**: even
once the answer set is *complete*, tabling's producer/consumer/merge would still flatten
the per-branch tags `naf-per-binding-mask` needs for the recursive-consumer seam. That
is the genuine A.2b.2/A.2b.3 work — and it requires completing the on-network rule
engine (body-local threading) + **SLG completion detection** — i.e. **BSP-LE Track 3**,
which is ⬜ unbuilt. PUnify Part 3 §9.6 (support-set-tagged table answers;
unconditional=∅ memoize across worlds, conditional worldview-filtered) is the citable
prior art for that layer (`2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md:612-620`,
designed-but-never-built).

**OWNER RULING (revised, 2026-07-19):** the earlier "DFS-defer REJECTED / all solvers
correct on-network *now*" ruling was made under the belief that on-network correctness
was cheap (a tag fix). Given the true premise — on-network correctness here **requires
building BSP-LE Track 3** — the owner's revised steer is: **take the minimal slice that
keeps things correct and does not set BSP-LE Track 3 off in the wrong direction.**

**THE LANDED FIX (A.2b minimal slice, `bcd02d6d`):** the real defect is the **adaptive
dispatcher mis-routing** — `use-propagator?` (stratified-eval.rkt) unconditionally sends
NAF/guard to the on-network path, but that path is incomplete for body-local-var rule
generators. Fix = a new **Check 3**: `reachable-has-body-local-rule?` (a reachability
walk via `transitive-pred-closure` + `collect-clause-vars` minus params) — any
would-be-on-network query whose reachable relation graph has a rule clause with a
body-local var routes to **DFS**, the **correct reference solver** (parity harness:
DFS gives `safe-twohop={w}`, `safe-reach={y,w}`; on-network gives `{}` / drops `w`).
Fact-NAF (A.2-core) and param-passthrough rules are on-network-complete and **stay**.
This is *not* off-network scaffolding bolted on — it corrects a bug in the existing
adaptive solver-selection (which already chooses DFS vs ATMS). It also fixes, for free,
the latent **threshold-forced** silent-wrong case (a 4+-clause body-local rule with no
NAF) — same predicate.

**SCAFFOLDING — retirement owner BSP-LE Track 3.** When Track 3 lands on-network
body-local threading + SLG completion (+ the §9.6 worldview-preserving table), delete
the Check-3 predicate and those shapes flow back on-network. Logged in `DEFERRED.md`.

**Verification:** acceptance 8/8 (`safe-twohop`→`{w}`, `reaches`→`{y,z,w}`,
`safe-reach`→`{y,w}`); `test-rel-t1-naf` +2 (join + recursion routing); demo
(`needs`/`risky-dep`) unchanged (already DFS); suite 8929/466/0.

### A.3 — safe / floundering negation (static range-restriction gate) — **LANDED** (`74fa9df2`)

A variable in a `not`/`guard` goal bound by **nothing** is unsafe (floundering);
NAF over it is ill-defined and silently mis-answers. A.3 rejects it **statically**
with a clear error. No safety check existed anywhere before (grep-confirmed).

**PERMISSIVE (Prolog `\+` mode discipline; owner ruling — Prolog-parity is the aim):**
a `not`/`guard` var is safe iff it has a positive binding occurrence — a **head
parameter** OR a positive body goal (an `app` arg, a `unify` side, or an `is` LHS —
**not** the `is` RHS, which is consumed). So `p(x) :- not q(x)` is **allowed** (x is
a param). **Residual (named, deferred):** an unsafe-mode call of such a clause
(`solve (p v)`, v free) yields the standard Prolog unsafe-`\+` result — `nil` (probe:
`solve (risky v)` → `nil`, *not* a fuel error) — **not** a floundering warning.
Catching that needs a runtime mode/groundness check (query-arg groundness × which
params occur only under `not`); deferred (WFS is available for stricter semantics later).

**Home reframed (the design's `install-conjunction` proposal was REFUTED by the
A.3 grounding audit `wf_e9ca4ffc-0b1`):** `install-conjunction` is ATMS-path-only
AND — self-inflicted — a floundering var is a *non-param `not` var*, exactly what
**A.2b's Check 3** treats as body-local → routes to DFS, **bypassing
`install-conjunction`**, so a gate there fires for essentially *none* of its target
population. Floundering-safety is a **static property of the clause text**, so the
home is **engine-independent clause construction**:
- **Site A** (clause-body `not`/`guard`): `check-relation-floundering` at **defr
  registration** (driver.rkt, mirroring `check-relation-schema-rows` → `prologos-error`),
  *before* any dispatch — covers the on-network + DFS + explain engines uniformly, and
  moots the `install-conjunction` Phase-T reconciliation (unsafe clauses error before
  Phase T runs).
- **Site B** (top-level `solve`/`solve-one`/`explain` `(not G)`, the seed's actual
  example): the three runner arms (reduction.rkt). **Loudness pivot (owner ruling,
  `393bbbbf`): Prolog-parity — WARN to stderr and return the standard unsafe-`\+`
  result (`nil`), NOT an error.** (Initial impl hard-errored via `expr-panic`; the
  owner preferred Prolog's run-and-return-`nil`. A `defr` clause with unsafe
  negation *does* still hard-error at Site A — that is an authoring bug, "Prolog
  flags singleton vars too"; a top-level query is a query.) Warnings may prove too
  noisy — full-silent is a one-line walk-back if wanted.

Shared checker (relations.rkt): `clause-floundering-msg` + `check-relation-floundering`.
Guard **is** covered (same rule, kind-specific var extractor); **A.4 owns** guard's
residuation + FFI-crash (the statically-safe-but-not-yet-ground case). **Scope:**
named-`defr` Site A + top-level Site B; inline anonymous-`rel` floundering deferred
(rare; shares Site B's eval-time channel). Tests: `test-rel-t1-naf` +3.

### A.4 — guard — **LANDED (DFS-routing, commit `6b56397d`)**

> **Reframed + resolved.** The A.4 grounding-audit (`wf_ab037f07-570`) + implementation
> found on-network guards have **three real bugs**, and that guards *always* live in
> tabled rule clauses — so the on-network guard path inherits Issue 1's tabling seam.
> The minimal reliable fix is DFS-routing (mirroring A.2b's Check 3); the on-network
> guard mechanism is prototyped + captured for BSP-LE Track 3.

**The three on-network guard bugs (each verified with valid probes):**
- **(a) Struct-condition resolution**: `resolve-condition-from-net` walked only
  `expr-app`/`pair`, not struct nodes like `expr-generic-gt`, so `[gt weight 0]` reached
  `eval-fn` with `weight` unresolved → `nf` stuck → `truthy? [else #t]` → the guard
  silently passed (never filtered). (The wfle "F2 crash" premise was wrong — `gt` goes
  stuck, it does not crash; a real FFI crash needs a `foreign` primitive + unbound var +
  `nf` eval-fn — a rare, doubly-gated mode, not F2.)
- **(b) Single-bit per-binding collapse**: `install-conjunction` tags every fact row with
  the ONE shared guard bit `G`, so a multi-fact generator can't be filtered per-row
  (order-dependent leak-all / lose-all). S0 analogue of A.2-core's NAF collapse.
- **(c) S0 belief-narrow doesn't persist**: `worldview-cache` is a derived projection of
  decisions-state (`install-worldview-projection`), so an S0 narrow is re-projected away.
  NAF's identical AND-NOT persists only because it runs between-round.

**Landed fix — Check 4 (SCAFFOLDING, retire w/ BSP-LE Track 3)**: `reachable-has-guard?`
in `stratified-eval.rkt` `use-propagator?` routes any would-be-on-network query whose
reachable relation graph contains a `guard` goal to **DFS**, which filters guards
correctly (ground + free-var, single + multi-fact). Symmetric with A.2b's Check 3.
Verified: wfle F2 `positive-edge` → `{(a,b,3),(c,d,5)}`, `positive-edge-nat` →
`{(a,b,3N),(c,d,5N)}`; Rel acceptance 9/9; `test-rel-t1-naf` +2; suite 8934/0.

**The on-network guard mechanism (prototyped + verified, deferred to Track 3)**: the full
on-network fix — struct-resolution + a per-binding guard belief-clear (the S0 analogue of
`naf-per-binding-mask`, pure `eval-fn(subst)`, no fork) + a **between-round handler**
(guard-pending cell + `process-guard-request` mirroring `process-naf-request`, because of
bug (c)) — was built and verified working for a generator that materializes on-network
(`f2-guard-probe` → `{3,5}`), then reverted for the simpler DFS-route. It deploys once
Track 3 lands worldview-preserving tabling. Full design +
[Track 3 seed](2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md) § Issue 2.

**Deferred (unchanged)**: guard's genuinely-never-ground residual is standard Prolog `nil`
(the A.3 static gate is the safety pair); a hard runtime flounder terminal is deferred.

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

## 6. Aspect B — typed solution rows — **SETTLED (Stage-3, 2026-07-20)**

`solve`/`solve-with`/`solve-one`/`explain`/`explain-with` all return a bare
`expr-hole` in both checkers (typing-core.rkt:2930-2942, qtt.rkt:2161-2183). Aspect
B gives them a **typed per-solution row** so solve output composes with the CIU-T6-F1
records/rows type system (project a field, feed a typed function). Settled after a
grounding-audit (`wf_ec53bc09-c31`) + an adversarially-critiqued design-options panel
(`wf_e00d9318-3b6`, Q1/Q2/Q4/Q5) + main-session R-lens verification + owner co-design.

### 6.0 Notation (owner, corrected 2026-07-20)
- **`Κ`** — the *definition-time* key-name: schema field-name **XOR** the `defr`
  predicate-argument name. Known at definition time for **every** relation (a `defr`
  always has predicate-arg names) — NOT schema-only.
- **`Κ′`** — the *query-var* (call-site) key-name (the `?x` the user writes).
- **`α`** — a field type.

### 6.1 The four decisions
| # | Decision | Resolution |
|---|---|---|
| **Q1 keying** | solution-row keys = `Κ` or `Κ′`? | **`Κ′` (query-var names), always** — Prolog-matching. Schema/facts supply field TYPES `α` only, never the keys. Any `Κ′→Κ` rename is owned by Path-Selection `^`, not baked into solve. |
| **Q2 type-source** | codata vs schema | **schema-projection + fact-observation** (the F1 schema/`Map` split, one layer up). See §6.2. |
| **Q4 where/posture** | propagator or infer rule; where | **Register the 5 solve structs `#f` (dispatch parity with records); compute the row in the imperative `infer`/`inferQ` arm** via a cycle-free `relations.rkt` import + `schema->row`. On-network *computation* is the deferred joint records+solve move (§6.7). |
| **Q5 predicate** | shallow vs deep shared ground/free | **Shallow goal-app parity-kernel, keys-out, strip-isolated** (§6.5); deep shapes (`is`/`not`/`unify`, `expr-rel`) stay untyped (gate e) for now. |

**Why `Κ′` (Q1):** it makes the static row keys *identical to the runtime champ keys
by construction* (CbC — nothing to hand-maintain across the 6 runtime row-build sites).
A `Κ′→Κ` rename was rejected: (a) a present-but-unground var renders as its OWN name
as the row *value* (`ground->prologos-expr`, reduction.rkt:262), so renaming only the
key yields `{:Κ  Κ′-value}` — an intra-row key/value desync; (b) the cache-hit gap
(§6.10) would give the SAME relation different keys by import path — self-refuting on
the very "schema consistency" axis a rename is chosen for; (c) it reverses D25's
just-landed echo-deletion (rows made query-var-only). One key convention; `^` owns rename.

### 6.2 The type-source split (Q2 — F1 schema/`Map`, one layer up)
The keys are always `Κ′`; the field type `α_i` at free position *i* comes from:

| Relation shape | `α_i` source | Soundness | Phase |
|---|---|---|---|
| **Schema'd** (`defr R : S`) | schema field type at position *i*, via `schema->row`/`schema-field-type->expr` (typing-core:3559/370) | static, sound (schema = upper bound for all runtime rows incl. rule-derived) | B1 |
| **Un-schema'd, facts-only** (`defr R \|\| …`) | **join** of the fact-literal types at position *i* (the literals are statically present in the source) | static, sound | B2 |
| **Un-schema'd, rule-bearing** (open) | loose static row (rows of metas / `Value`; F1b.6/D23 posture); **precise codata typing recovered at runtime "at the end"** from the actual solution-champ literals via F1's existing observe-the-value machinery | static loose + runtime precise | runtime; first-class-static → **C.1** |

This IS F1's split one layer up: a schema'd relation is *inductive/data* (precise
static, like a schema-sealed record); an un-schema'd relation is *codata/`Map`* (loose
static + precise runtime observation, like a bare `Map`). We NEVER do unsound static
observation of rule outputs — the runtime values carry that (owner: "if the solution
set has a literal value, we can get the codata/observed typing at the end"). Genuinely
first-class *static* codata for open/rule relations defers to **C.1 clause typing**.

**Positional bridge (universal):** goal-arg *i* ↔ `defr`-param/field *i* ↔ `Κ′_i`.
Because `Κ` (a param name) exists for every `defr`, the bridge is well-defined for all
relations. It carries the TYPE only (mismatch degrades to metas, never a type-lie). It
needs a `#params == #fields` guard — which does NOT exist today (the only registration
arity check is fact-row-length == #fields, driver.rkt:499-501); B1 adds it at the
`defr` branch beside `check-relation-schema-rows` (degrade to metas on mismatch).

### 6.3 Where + posture (Q4) — dispatch on-network, compute imperative
Records are typed by a `register-typing-rule! … #f` rule (map-assoc, typing-propagators
:2373) that DELEGATES the computation to the imperative fallback (`record-extend`); a
`#f` node is left at `⊥` and the driver's `(if (prologos-error? net-ty) (infer/err …)
net-ty)` gate (driver.rkt:656-659) runs the imperative checker. B matches this exactly:

1. **Register `expr-solve?`/`-with?`/`-one?`/`expr-explain?`/`-with?` with return-type
   `#f`** (5 one-line `register-typing-rule!` entries) — solve is now #f-*dispatched*
   like records, and drops out of `unhandled-expr-counts` (coverage hygiene).
2. **Compute the row in the imperative `infer`/`inferQ` solve arms** (replace the
   `expr-hole` at typing-core:2930-2942 + qtt:2161-2183) via a **cycle-free
   `relations.rkt` import** (R-lens-confirmed: typing-core→reduction→relations already;
   relations has no back-edge). `schema->row`/`lookup-schema-by-name`/`schema-field-type
   ->expr` are ALREADY in typing-core; only the relation→schema-name hop is new.

**Reachability — the composition case is covered (R-lens-verified, typing-core:3183-3211).**
`infer-on-network/err` falls back to the imperative checker not only when the *root* is
`⊥`, but when **any interior position is still `⊥` at quiescence** — the F1b.2/D26
"5th refusal check" (`untyped-interior-position`). So `solve(…)[0].Κ′` — solve nested
under a field-projection — leaves the solve subtree at `⊥`, the check fires, and the
WHOLE expression falls back to imperative, where the new solve arm types the row and
the composition typechecks. **B rides the exact mechanism records already ride.** No
computed on-network rule is needed for the MVP.

### 6.4 Container wrapping — **corrected to the RUNTIME shape at B1 (CbC)**
The row is the *element*; `Seq` is a comment, not a type — reuse `List`
(`(expr-app (list-type-fvar) <row>)`). Per-arm containers (corrected during B1
grounding to match what the runtime VALUE actually is — the type must not lie):
- **`solve`/`solve-with` → `List<row>`** (closed row).
- **`solve-one` → BARE `row`** (NOT `Option<row>`). The runtime is the D25.4-unwrapped
  bare champ (`run-solve-one-goal` returns `expr-champ` or `none`), and `expr-get` has
  no Option arm — so `Option<row>` would both type-lie and break the `[solve-one q].x`
  projection D25.4 exists to enable. The `none` (no-solution) case is the pre-existing
  optimistic gap (unchanged from the prior `expr-hole`).
- **`explain`/`explain-with` → `List<row>` with a `'dyn` tail** (NOT `List<Answer<row>>`).
  The runtime returns plain champs (`answer-result->prologos-expr`), NOT `Answer`-wrapped
  values — `expr-answer-type` is unused at runtime. The row carries a `'dyn` (open) tail
  so the conditional reserved metadata keys (`:certainty`/`:cycle`/`:provenance`, WFS/
  provenance modes) don't produce a closed-row type-lie.

The wrapper is a uniform mechanical step in `solve-row-type` (`'list` vs `'bare`;
`tail` = `'closed` for solve/solve-one, `'dyn` for explain).

### 6.5 The ONE shared ground/free kernel (Q5 — entry-gate b, CbC substrate)
Extract from `extract-query-info` (reduction.rkt:285) a single **pure classifier** that
emits the champ **KEYS** (not raw names) for goal-app free positions, and refactor the
3 goal-app runtime row-build sites onto it; the new typing arm calls the SAME function.
Returning the KEY (`(expr-keyword raw-logic-var-name)`, the exact key
`answers->prologos-expr` uses at reduction:247) is the parity lever — keyword-wrapping
+ the goal-app no-strip policy live INSIDE this one function, so neither consumer can
re-decide the key spelling and the type keys CANNOT drift from the runtime keys.

- **Home:** `reduction.rkt` (typing-core already requires it; one-directional, cycle-free).
- **Signature:** `(classify-goal-args whnfd-args) → (listof (or/c 'ground (free-desc)))`
  in canonical positional order, where `free-desc` carries **BOTH** the champ-key (typing
  parity) **AND** the raw name (runtime needs it for `hash-ref answer qv`, reduction:246).
  *(R-lens note: the panel's `(cons champ-key position)` DROPS the name — it must carry
  both, else "keys-out" degrades back to discipline.)*
- **Mantra (all-at-once):** rewrite as a partition/`map` over independent positions —
  NOT the current `set!`-accumulating loop (reduction:286-296). This is the all-at-once
  word applied at exactly the point the CbC guarantee rests on; not cosmetic.
- **is/not/unify + expr-rel:** stay outside the typeable fragment (deep idioms
  `collect-deep-logic-vars` ×5 / `expr-rel` all-params ×2 untouched) → gate e. Built
  keys-out so promotion to Q5-C (deep adapters) is a mechanical add-adapter later.

### 6.6 Unbound-rep default (presence-lattice refinement → C.1)
Row values carry two unbound reps: missing key → `(expr-fvar 'none)` (reduction:248);
present-but-unground → own-name fvar (:262). **MVP default:** free positions type as
`present` with their `α`/meta; a closed row. The presence-lattice refinement (missing
→ `optional`/Option; explain's reserved keys as the first `optional` clients) **defers
to C.1** (owner: "it can wait to C.1").

### 6.7 SRE lens · mantra · Network Reality Check (honest)
- **SRE:** the row type is a **STRUCTURAL** lattice — a product of per-field
  (`type × presence`) lattices indexed by the `Κ′` key-set. The shared-predicate parity
  is a **span / equalizer** (one classifier morphism, two post-composed projections
  sharing a key-domain), NOT an α/γ Galois adjunction — name it precisely, don't reach
  for decorative Galois vocabulary. PRIMARY = the runtime champ key-set (the row VALUES);
  the static Record type is DERIVED and shares the SAME index by construction.
- **Network Reality Check (honest):** the row COMPUTATION is off-network — 0
  `net-add-propagator`, 0 `net-cell-write` produces the row; it is the imperative `infer`
  return value. This is at **exact parity with F1 records** (which also compute
  imperatively), not new debt. The `#f`-DISPATCH is on-network, but that does NOT make
  the COMPUTATION on-network — keep the distinction sharp; no "on-network" vocabulary
  for the row build.
- **Scaffolding + retirement (NAMED):** the imperative computation is scaffolding whose
  retirement is the **joint records+solve on-network move** — flip both the map-assoc `#f`
  rule AND the new solve `#f` rules to *computed* rules writing the row into the `tm`
  cell — at the **BSP-LE Track 3 / PPN-native-typing** horizon. NOT a solve-only
  propagator (that would split the dispatch altitude — worse decomplection than honest
  `#f`-parity). Recorded so the static path is not left a permanent island.

### 6.8 Build partition + first-green slice
- **B0** (substrate; zero behavior change): build the §6.5 kernel (keys-out,
  strip-isolated, partition-not-`set!`), refactor the 3 goal-app runtime row-build sites
  onto it. Green = existing Aspect-A solve rows byte-identical. This is the Q1≡Q5
  substrate both later phases stand on.
- **B1** (first typed slice — schema'd goal-app): register the 5 solve structs `#f`;
  imperative arm builds `expr-Record` with `Κ′` keys (from B0) whose types `α` are
  `schema->row`-projected positionally; wrap per-arm; add the `#params==#fields` guard.
  **First-green slice = the composition probe:** `solve(person)[0].name : α` typechecks
  (transitively exercises all four decisions + re-confirms the 5th-refusal fallback).
- **B2** (codata): un-schema'd facts-relation → join fact-literal types; un-schema'd
  rule-relation → loose row + runtime "at the end"; first-class-static-codata-for-open
  named DEFERRED to C.1.

### 6.9 Deferred / out of scope (named, not silently inherited)
- **Cache-hit registry gap** (pre-existing, PM-Track-12-shaped): neither
  `current-relation-store` nor `current-schema-registry` is `.pnet`-serialized
  (pnet-serialize:544-614) nor restored on cache-hit (driver:2560-2673), so a relation
  imported from a cached module is invisible to static lookup AND errors at runtime
  ("Unknown relation", relations.rkt:3031). Breaks independent of B; DEFERRED, not B's bug.
- **Two-context empty-store fidelity:** `current-relation-store` is a `make-parameter`
  with an EMPTY default, absent from `test-support`/`batch-worker` (only driver:825
  populates it). Failure mode is *silently-empty store → solve untyped* in
  test/run-ns/batch contexts (NOT an unbound crash). B1 must decide: thread the store
  into `test-support`/`batch-worker` save-restore (pipeline.md New-Parameter + Two-Context)
  or accept the fidelity gap. **Recommend threading it** (the tests need typed solve).
- **Deep goal shapes** (`is`/`not`/`unify`, `expr-rel`): untyped (gate e) this track.
- **Reachability RESOLVED** (strike from any stale framing): the relation store IS
  reachable from typing-core (cycle-free `relations.rkt` import) — "unreachable" was a
  red herring; only the empty-store two-context gap above remains.

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
5. **B0 → B1 → B2** typed rows (§6.8): B0 shared kernel (zero behavior change) →
   B1 schema'd goal-app (first-green = `solve(person)[0].name : α`) → B2 codata.
6. **C** schema-as-facts (C.1 rule-clause typing + presence-lattice refinement + C.2
   signature-schema activation) — shares B's kernel + fact-typing.
7. **Polish**.
8. **T** dedicated tests (interleaved, not deferred).
9. **X.close** bench + doc-truth + PIR.

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
- **A.2b** rule/recursive-generator NAF — ✅ **RESOLVED (minimal slice landed, `bcd02d6d`): adaptive-dispatch DFS-routing** (§5 A.2b). Root reframed to the body-local-var gap (probe-verified); worldview-preservation + on-network body-local threading + SLG **deferred to BSP-LE Track 3** (scaffolding retirement owner). Owner's "no DFS-defer" revised given the true premise (on-network correctness here = build Track 3).

**Still open:**
- **A.3** — ✅ **RESOLVED (landed `74fa9df2`): static PERMISSIVE floundering gate** at defr registration (Site A) + top-level runners (Site B); `install-conjunction` home refuted (§5 A.3). Residual (mode-dependent free-arg call → standard Prolog `nil`) named + deferred.
- **A.4** — guard — ✅ **RESOLVED (landed `6b56397d`): DFS-routing** (`reachable-has-guard?` Check 4, §5 A.4). 3 on-network guard bugs found (struct-resolution; single-bit per-binding collapse; S0-narrow re-projected); the F2 "crash" premise was wrong (`gt` goes stuck, not crash). On-network guard mechanism prototyped + deferred to Track 3.
- **BSP-LE Track 3 (deferred, scaffolding retirement)** — retires BOTH the A.2b Check-3 (body-local-var rules) and A.4 Check-4 (guards) DFS-routing predicates. Work: on-network body-local-var threading + SLG completion + §9.6 worldview-preserving tabling + the prototyped on-network guard mechanism. Seed: [`2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md`](2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md) (both issues + prototyped designs); grounding/options in `wf_c2f8bfa3-db2` / `wf_9c6eb408-522` / `wf_ab037f07-570`.
- **Q-B** (Aspect B) — ✅ **RESOLVED (Stage-3, 2026-07-20, §6):** keys = **`Κ′` (query-var), always** (Prolog-parity; `^` owns rename); type-source = **schema-projection + fact-observation** (F1 schema/`Map` split, one layer up; rule-relation codata → runtime "at the end" / C.1); posture = **`#f`-dispatch + imperative compute** (5th-refusal reachability carries composition); shared **keys-out kernel** (§6.5); deep shapes + presence-lattice + cache-hit gap DEFERRED. Panel `wf_e00d9318-3b6` + R-lens + owner co-design.

---

## 12. References
- Grounding: `wf_7ad61165-85d` (surface), `wf_1891cfd0-197` (NAF isolation) — dailies `2026-07-19_dailies.md` LOG.
- Aspect-B (§6): grounding `wf_ec53bc09-c31` (solve-typing surfaces) + design-options panel `wf_e00d9318-3b6` (Q1/Q2/Q4/Q5; Q3-cluster failed, folded into §6.6) — dailies `2026-07-19_dailies.md` LOG (2026-07-20 entries).
- Seed: [`2026-07-19_REL_SOLVE_TYPING_NOTE.md`](2026-07-19_REL_SOLVE_TYPING_NOTE.md) (its `&>` label superseded by §4).
- Rel Master: [`2026-07-19_REL_MASTER.md`](2026-07-19_REL_MASTER.md).
- Rules: `.claude/rules/propagator-design.md` (broadcast, set-latch, watcher/threshold variants), `.claude/rules/stratification.md` (S1 NAF), `.claude/rules/structural-thinking.md` (retraction as narrowing), `.claude/rules/on-network.md` (mantra).
- Path-Selection (downstream, `^` rename): `2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md`.
- `?v:Type` CLP prior art (deferred): `docs/research/2026-03-16_NEXT_GEN_LOGIC_PROGRAMMING.tex`.
