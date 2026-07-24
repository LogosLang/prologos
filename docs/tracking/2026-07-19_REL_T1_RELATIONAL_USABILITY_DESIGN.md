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
- **Aspect C — typed logic vars + schema validation** — **CLOSED (C.a+C.b+C.c,
  2026-07-21)**: the `type-pred` substrate (C.a), the fused `?x:Int`/`x:Int` reader in
  both readers + both languages (C.b), and the **schema ⟹ facts-only** blocking gate (C.c,
  the highest-motivation static validation on grounded facts). The runtime
  types-as-predicates reading (`?x:Int` = guard `Int(x)`, "C.d") is **deferred to UCS**
  ([`2026-07-21_UCS_TYPES_AS_PREDICATES_NOTE.md`](2026-07-21_UCS_TYPES_AS_PREDICATES_NOTE.md),
  UCS Track 6).
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
| **B2** | Codata: un-schema'd FACTS-ONLY → row typed by the JOIN of fact-literal types; heterogeneous column → **union** (owner); RULE-bearing → loose (runtime "at the end" / C.1) | ✅ | `relation-column-typer` (schema \| codata branches) + `observe-column-type` (dedup→`expr-union`); soundness boundary = facts-only (no clauses); refactored `goal-app-schema-row`→`goal-app-row`; +4 tests; suite **green** |
| **C** | Typed logic vars (`?x:Int` = Curry-Howard `Int(x)` = type) + schema validation — **CLOSED at C.a+C.b+C.c (2026-07-21)**. Static validation on grounded facts delivered; the runtime types-as-predicates reading (C.d) → UCS Track 6 | ✅ | C.a `b33474aa` · C.b.1 `6d793906` · C.b.2 `c6b8e81f` · C.c `357035d5`; C.d deferred ([UCS note](2026-07-21_UCS_TYPES_AS_PREDICATES_NOTE.md)) |
| **C.a** | Representation substrate: the `type-pred` value (type-EXPR + predicate-SET list slot, NO stub) + smart-constructor `param-info` field (8 prod sites untouched) | ✅ | `b33474aa`; `type-pred` + `param-info` `type` field via #:name-redirect smart-ctor (§7.8; naive `#:constructor-name` form fails to compile); store-only (0 consumers); +6 tests `test-rel-t1-typed-vars.rkt`; suite 8950/468/0 |
| **C.b.1** | Reader + parser — **RELATIONAL**, both readers: fused `?x:Int` in `parse-rel-params` (WS trailing colon-symbol + sexp glued-symbol split) → `(name mode type-name)` 3-list carrier → elaboration NAME→EXPR → relations `type-pred` wrap on `param-info`; chained reject; spaced diagnostic (fused-only) | ✅ | `6d793906`; parser-arm (tokenizer untouched, no sweep); fixes a pre-existing `?x:Int` mis-parse; +tests (parser-relational sexp + typed-vars store); suite 8959/468/0 (§7.9) |
| **C.b.2** | Reader + parser — **FUNCTIONAL**, both readers: route fused `x:Int` to the pre-existing `binder-info.type` typed-binder path (no type-pred); two arms in `parse-binder` (WS `(x :Int)` 2-elem + sexp glued split); chained reject; `:0/:1/:w/:m` mult excluded | ✅ | `c6b8e81f`; both readers funnel through `parse-binder` (tree-parser falls back — probed); fused types identically to spaced (`Int -> Int`); +4 tests; suite 8963/468/0 (§7.10) |
| **C.c** | **REDESIGNED (§7.4)**: schema ⟹ facts-only BLOCKING gate (driver sibling `check-relation-schema-facts-only`). Rejects `defr R : S &> …` at registration — the clause-conformance check was DROPPED (incomplete; the hole was a schema-on-rule category error) | ✅ | `357035d5`; complete+sound (reject ill-formed input, no typer guard); pre-check found no active schema'd-rule; +3 tests; suite 8966/468/0 (§7.11) |
| **C.d** | ~~C.2 activation — `type-pred` → `relation-column-typer` upper-bound~~ → **DEFERRED to UCS** | ⛔→UCS | `?x:Int` on a rule var is a GUARD `Int(x)` (runtime/UCS altitude), not a static contract → the static activation is UCS's domain-constraint work. Handoff note: [`2026-07-21_UCS_TYPES_AS_PREDICATES_NOTE.md`](2026-07-21_UCS_TYPES_AS_PREDICATES_NOTE.md) (UCS Track 6). C.b already STORES the type-preds — nothing lost. **Aspect C CLOSES at C.a+C.b+C.c.** |
| **B3** | **Typed solution rows for RULE-bearing relations (codata)** — the B2-deferred half, elevated by the owner (2026-07-24): *"one of the largest motivating usability aspects of all of this work"*. Today `relation-column-typer`'s rule-bearing branch yields `#f` → rule solves type as bare `_` (e.g. `solve (path x z) : _` vs facts' `List {:k Int …}`), so rule solutions cannot compose with the F1 records/row machinery (`.field`, validate, row polymorphism). Realization **SETTLED §6.10** (co-design 2026-07-24, grounding `wf_512dd7e3-5e8`): hybrid — static body-flow = the composition channel (D-B3.1), fixpoint recursion (D-B3.2), anon-rel in scope (D-B3.3), closed rows / hole-degrade (D-B3.6) | 🔄 | **B3.0 ✅** `67d96a0d` (POL.2 anon-key kernel filter, BOTH halves atomic — 6 runtime sites + static labels + key-policy consolidation; suite 470/0). **NEXT: B3.1** the static walker; then B3.2 display refinement |
| **D.0/1** | Efficient fact representation + query-opt — Stage 0/1 research + design artifact | ✅ | **Artifact landed** `0b428424`: [`2026-07-23_FACT_REPRESENTATION_QUERY_OPTIMIZATION.md`](../research/2026-07-23_FACT_REPRESENTATION_QUERY_OPTIMIZATION.md) — frame F1–F7 · measured cost structure · lattice verdicts · staging ladder · **Rel T2 "Fact Store" charter seed** (§11) + §14 D.2 addendum. **Q_A–Q_D parked** for the Rel T2 charter (owner, 2026-07-24) |
| **D.2** | Cheap-wins slice (artifact §7 NOW: N1–N6) | ✅ | D.2.a `296ac2d5` (dead tree −135 LoC + comment truth) · D.2.b `984601b9` (row-scan/col-compare counters + 2 latent fixes) · D.2.c `7ba24b2b` (fact-scale bench + corpus generator + 260-row standing E2E; **findings: Tier-2 unreachable for 1-variant fact tables; NO DFS↔Tier-2 crossover ≤1000 — Tier-2 enum ~480× slower @1000**) · D.2.d `feedc6ff` (registration-time INVERTED index on `variant-info.discrim`; Tier-2 point rows N+1→1, 0.78→0.17ms @1000). Suite 469/0 throughout; artifact §14 |
| **POL** | Polish — **ROSTER EXPANDED to POL.1–.9** (§8, 2026-07-24): owner hand-testing list from `standup-2026-07-19.org` § "Polish points for REL" folded in. Correctness: dedup (.1) · `_anon` keys (.2) · declaration-order keys (.3) · **arity-mismatch errors** (.4) · **def-on-solve multiplicity** (.5) · **defn fused-binder last mile** (.6). Syntax: single-line `\|` facts (.7) · implicit clause groups (.8) · implicit solve (.9, ⚠ design question — co-design first) | ⬜ | §8 sequencing note; POL.9 needs owner co-design before impl |
| *(tests)* | **Per-phase** — each behavioral phase brings its own test delta in its completion gate; the test file(s) `tests/test-rel-*.rkt` GROW per phase (NOT a dedicated end phase — see workflow.md "Tests are PER-PHASE") | — | e.g. `test-rel-t1-naf.rkt`, `test-rel-t1-typed-rows.rkt` (grown across B1/B2) |
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

### 6.10 B3 — rule-relation codata rows — **SETTLED (co-design 2026-07-24)**

Grounding: `wf_512dd7e3-5e8` (4 HEAD-pinned facets + critic, @ `a3e5716f`) +
main-session R-lens (UX repro: a rule solve types `_`; `.field` on it is a HARD
`expr-error` via map-get's catch-all; and `def rows := solve (rule…)` fails at the
`def` itself — "Expression is not a valid type"). The gap is ONE conjunct
(`(not has-clauses?)`, typing-core.rkt:3617-3621, relation-global); the fix seam
is `relation-column-typer`/`goal-app-row`, which feeds all 5 solve forms × both
checkers × the on-network `#f`-dispatch (10 sites) at once.

**The owner's frame (load-bearing)**: `Map` is the CODATA/coinductive shape;
`schema` is the INDUCTIVE side; B3 is the interplay. **The division of labor is
PHASE-FORCED, not chosen**: the checker runs before reduction (verified: type
stored pre-eval; `expr-champ` infers `expr-error` by F1b retired-loud posture),
so only the static/inductive side can serve composition (`.field`, `def`-binding,
validate); at-the-end observation — the coinductive side — is display/runtime
truth. Both are built; neither pretends to be the other.

**Decisions:**
- **D-B3.1 — HYBRID**: (i) static body-goal dataflow = the composition channel —
  an UPPER-BOUND derivation through the rule body's generators (never output
  observation, per the §6.2 soundness ruling); (ii) at-the-end observation =
  display-time refinement at the driver echo seam — fills/sharpens hole fields
  in the DISPLAYED type from the actual result rows (exact for the result set;
  display-only; never feeds static typing). (ii) ships as **B3.2**, after B3.1.
- **D-B3.2 — recursion = type-level FIXPOINT** over the existing SCC machinery
  (leaves-first; within-SCC iterate from ⊥ with union-join to stability;
  terminates over the finite type alphabet of the program). Rationale:
  transitive-closure-shaped rules (reachability/ancestry — the demo's core
  queries) are exactly the recursive case; bail-to-hole would leave them
  untyped. (Owner: shared the lean once TC was explained.)
- **D-B3.3 — anonymous `rel` IN SCOPE** (owner: "observational results really
  should share common mechanisms") — the same walker runs over the inline
  `expr-rel` body; solve-row-type gains the expr-rel arm.
- **D-B3.4 — POL.2 FIRST/JOINTLY**: the anon-`_` key drop lands at the B0
  kernel level (one atomic change) BEFORE B3 mints static labels, so the
  CbC static/runtime key agreement never breaks.
- **D-B3.5 — `?x:Int` type-preds EXCLUDED** until UCS enforcement exists
  (owner: "pretending they statically mean something when there is no
  enforcement would be dishonest and confusing").
- **D-B3.6 — rows are always CLOSED with Κ′ keys** (keys are statically known
  for every relation kind — the B0 kernel); underivable field TYPES degrade
  to hole, never lie; mixed facts+clauses relations JOIN the fact
  contribution (today the relation-global gate discards it); ground queries
  keep the existing loose posture.
- **D-B3.7 — imperative-compute preserved** (Aspect B Q4); derivation cached
  (registration-time per the D.2.d precedent, or store-version-keyed per the
  strata precedent — measured choice at implementation); scheduler-
  independent; zero propagator-arm changes (BSP-LE Track 3 seam untouched).

**Walker spec (per goal kind — A.3's binder classification reused):**
`'app`: symbol args take the callee's column type at that position (schema →
B1 projection; facts-only → B2 observation; rule → SCC/fixpoint). `'unify`:
var↔var links join both ways; var↔term infers the term. `'is`: LHS var gets
the RHS expr's inferred type under the accumulated per-clause var-type env.
`'not`/`'guard`/`'cut`: testing-only — contribute nothing. Per-head-param
join across clauses × variants × fact rows → union via the B2
`observe-column-type` kernel. **Substrate**: prefer the zonked AST twin
(global-env, stored at defr) — the goal-desc form deep-normalizes `'unify`
AST away; the inline AST serves the anonymous-rel arm directly.

**Expected side effect**: the `def := solve(rule)` "not a valid type" failure
dissolves (a real row type is bindable); POL.5's multiplicity violation on the
facts-relation case remains a separate defect at the same seam.

**Phasing**: **B3.0** POL.2 kernel fix (anon keys; own commit + tests) +
acceptance targets → **B3.1** the static walker + rule branch + fixpoint +
anonymous-rel arm + cache + flip the B2 `: _` test + stale-C.1-pointer
cleanup (§6.2/§6.4 rows here + typing-core.rkt:3598) → **B3.2** display-time
coinductive refinement (echo seam; scoped after B3.1 lands).

---

## 7. Aspect C — typed logic vars + schema-as-facts — **SETTLED (Stage-3, 2026-07-21)**

Typed logic variables via the Curry-Howard reading, plus rule-clause typing.
Settled after a grounding-audit (`wf_8083a27e-2a9`) + an adversarially-critiqued
design-options panel (`wf_09b5988d-e72`, Q-C1/Q-C2/Q-C3) + main-session R-lens +
owner co-design. **C.1** = type-check rule clauses (`&>`, currently unchecked);
**C.2** = activate declared param types (named schema AND inline `?x:Int`) as a
logic-var typing source.

### 7.0 The vision (owner, Curry-Howard) — load-bearing
`?x:Int` is sugar for the predicate/clause **`Int(x)`** ("x satisfies Int"). By
Curry-Howard (predicates ARE types), that clause-constraint IS the type `x:Int`.
ONE surface, three altitudes:
- **static type** — `x:Int` (THIS track);
- **runtime domain-constraint** — `Int(x)` as a goal that prunes the search (the
  existing dead-in-WS narrowing reading + future CLP) — **DEFERRED to UCS**;
- **refinement** — `Int@pos` (a refined predicate) — **DEFERRED** (`@` isn't a token yet).

**First slice = (A)-in-(B)'s-shape** (owner-confirmed): parse into a SINGLE
type-predicate representation (the same *general* object the runtime `Int(x)` will
lower FROM), but evaluate ONLY its static reading now. **Owner-confirmed
interpretation**: "one *general* type-EXPR carrier, the runtime symbol-bound node is
its down-projection" satisfies the lock (NOT literal node-identity) — this is *more*
Curry-Howard-faithful (the type IS the predicate at full generality) and is what
keeps UCS un-cornered. HARD CONSTRAINT: don't design into a corner that makes the
UCS/CLP work harder or foregone.

**The reveal (grounding)**: the `?x:Type` surface is ALREADY half-built — the
`?var:C1:C2` narrowing constraint-chain (`?x:Nat:Even` → `type-guard` domain
constraints via a base-name→type side-table; parser.rkt:6348-6404 / elaborator.rkt
:3276-3283 / narrowing.rkt:638-647) IS the runtime altitude. But it is **DEAD-IN-WS**
(verified: `solve (num ?x:Even)` over facts 1,2,3 → `nil`, because WS splits
`?x:Even` into `?x` + keyword `:Even` → 2-arg call to a 1-arg rel; works only in
sexp where `:` is non-special). So Aspect C's static reading has a clean WS surface;
the surface is the CLP-vision unification point.

### 7.1 The composed spine (Q-C2 → Q-C1 → Q-C3)
1. **Reader/parser** (Q-C2) delivers a generic **`(name, type-NAME)` pair** in BOTH
   readers / BOTH languages and STOPS there — the reader must NOT emit a distinguished
   type-predicate datum (Decomplection). **Corrected at C.b.1 (§7.9)**: the parser
   cannot produce an `expr?` (parser.rkt imports neither typing-core nor elaborate), so
   the reader carries a type-**NAME symbol** (e.g. `Int`), not a type-EXPR; the
   symbol→EXPR conversion is elaboration's job (it owns `schema-field-type->expr`).
2. **Elaboration** (Q-C1) converts the type-NAME → a **type-EXPR** (via
   `schema-field-type->expr`); the **`type-pred` value** — the type-EXPR in a
   **predicate-SET (list) slot**, **NO stub lowering fn** — is wrapped at
   relation-info construction (relations.rkt, which owns `type-pred`) and stored on
   `param-info`. (The reader→param-info carrier is the opaque `params` list, enriched
   to a `(name mode type)` 3-list at C.b.1.)
3. **Checker** (Q-C3) consumes that object via a **driver-level third sibling check**
   (beside `check-relation-schema-rows` / `check-relation-floundering`, driver.rkt
   :817), leaving the generic `expr-logic-var` infer arm (typing-core.rkt:2897 +
   qtt.rkt:2109) **UNTOUCHED**; C.2 feeds the same object to `relation-column-typer`.

### 7.2 The type-predicate representation (Q-C1 → Option 2′)
A small first-class `type-pred` value carrying a **type-EXPR in a predicate-SET
(list) slot**. Two load-bearing bits (the four-way panel collapsed to these):
- **type-EXPR, not a symbol** — the Galois corner-check (R-lens-verified): a
  type-expr projects DOWN to the type-name symbol the runtime consumer wants
  (`value-matches-type?`, global-constraints.rkt:475, is symbol-bound), but a stored
  *symbol* can NEVER project UP to recover `Int@pos`. This kills the two literal-reuse
  options (desugar-to-goal; share the narrow-var side-table) — both store symbols and
  corner refinement.
- **a LIST (predicate-set) slot** — matches the runtime side-table's existing
  list-per-var for conjunction (`Int(x) ∧ Even(x)`), so future goals lower without
  re-derivation AND without inventing intersection types (which don't exist).
- **NO stub lowering fn** — a stubbed `type-pred->clp-goal` no-op is the
  speculative-scaffolding red flag; the lowering is written WHEN UCS consumes it.

Stored on `param-info` (C.a grounding-audit `wf_af338130-cf0`, honest frame: **8
production construction sites** (all `relations.rkt`), **15 files / 78 call-occurrences
total, ALL 2-arg, ZERO `match`/destructure sites, ZERO `struct-copy` sites** — the
earlier "~56 over-counted" gloss was backwards, 56 is the grep-LINE count and it
*under*-counts the 78 occurrences; but every site is 2-arg so a smart-constructor
positional default covers 100%). Add the field via a **smart-constructor default** so
existing sites stay untouched — see §7.8 for the exact (compile-verified) idiom, which
is NOT the naive `#:constructor-name` same-name form (that fails to compile).

### 7.3 The fused `?x:Int` / `x:Int` syntax (Q-C2) — both languages, additive
- The reader produces a generic `(name, type-NAME)` pair. **Additive**: spaced
  `[x : T]` / `def x : T` keep working.
- **SPIKE VERDICT (C.b.1, instrument-confirmed — see §7.9): PARSER ARM, tokenizer
  UNTOUCHED, NO test-suite sweep.** The earlier "`x:Int` grabs `:Int` as a keyword"
  framing was HALF-RIGHT and is corrected: the WS reader splits `?x:Int` into `?x` +
  a **colon-prefixed SYMBOL** `:Int` (NOT a Racket keyword — `keyword? = #f`,
  `symbol? = #t`); the sexp reader GLUES it into one symbol `?x:Int`. Both shapes
  reach `parse-rel-params` intact; C.b.1 converges there (WS: consume the trailing
  colon-symbol; sexp: split the glued symbol after mode extraction). Both readers, one
  function.
- **Both readers**: WS delivers the base symbol + a trailing colon-symbol; sexp
  delivers one glued symbol → parse-rel-params handles BOTH (there IS a WS-vs-sexp
  shape divergence — the same hazard that made the `?var:C1:C2` narrowing chain
  dead-in-WS; C.b.1's split/fuse is reader-symmetric).
- **Type slot**: single-token fused (`?x:Int`); compound/union/refinement stay
  spaced+grouped (`[x : <List Int>]`) — a fused ident-run stops at `<`/`@`.
- **Required NEW work**: `parse-rel-params` (parser.rkt:5219-5232) has NO `:` branch
  — the relational companion is genuinely new (the "reuse binder machinery unchanged"
  claim is verified-FALSE for the relational path).
- **Chained `?x:C1:C2`**: REJECT with a diagnostic — reserve the surface for UCS.

### 7.4 C.c — schema ⟹ facts-only (BLOCKING well-formedness gate) — **REDESIGNED 2026-07-21**
**Superseded (do NOT implement): a "clause-conformance check."** The original C.1 was to
type-check `&>` clause bodies against the schema/param-types and reject a clause binding a
head param to a violating value (mechanism-B walk + `check ctx-empty` over clause subterms +
a param-type-pred check). **DROPPED** after owner co-design. The grounding-audit
(`wf_2f21daa9-252`) that scoped it is still valid for the code facts (hook site, precedent,
the hole); only the *design conclusion* changed.

**The redesign (owner semantic clarification — load-bearing).** A **schema** is only ever a
checked contract on **fact relations** (fully-ground, table-like data). A **`?x:Int` on a
rule's logic-var is NOT a static output-contract** — it is a **guard / unary constraint
`Int(x)`** (the runtime domain-constraint altitude, DEFERRED to UCS). So there is nothing for
C.c to statically check on rule clauses. The "Aspect-B soundness hole" only ever arose from a
**schema sitting on a RULE relation** (`defr R : S &> …`) — under this model that is a
**category error**, not a case to be made sound by clause-checking.

**C.c = enforce the schema branch's own silent precondition: schema ⟹ facts-only.** A
BLOCKING registration check rejects `defr R : S &> <clauses>`. This is **complete, sound, and
trivial**, and it closes the hole COMPLETELY: a schema'd rule relation can never register →
`relation-column-typer`'s schema branch (typing-core.rkt:3603-3610) only ever types
facts-only schema'd relations, whose rows ARE checked by `check-relation-schema-rows`.
**Rejecting the ill-formed input is STRONGER than guarding the typer** (the bad relation
never exists, vs existing-but-typed-loose) → **no `has-clauses?` guard is added to the
typer** (that would be belt-and-suspenders).

**Refuted premise (add to the cascade): "a blocking literal-clause check closes the Aspect-B
hole" — REFUTED.** A literal clause-conformance check is **INCOMPLETE**: it misses transitive
bindings (`(= x y) (= y "str")`), `(is x …)` goals, and compound-term bindings — all produce
`{:x <non-Int>}` at runtime while the static type says `{:x Int}`. Only full clause-output
typing (huge) or a runtime guard would *truly* close it — both moot once the true
precondition (facts-only) is enforced. (A/B-axis footnote: mechanism A `&> (R lit)` is
call-site arg-checking of goal args — a different axis, not the hole; its example
self-recurses and diverges. Not part of C.c.)

**Hook** = a driver-level sibling `check-relation-schema-facts-only rel-info` beside
`check-relation-schema-rows` / `check-relation-floundering`, returning #f (well-formed) or an
error string; wired as a new arm in the registration `cond` (BLOCKING — registration runs
only in the `[else]` arm). Fires iff `(relation-info-schema rel-info)` is non-#f AND some
variant has clauses.

**Acceptance.** `schema S :x Int` + `defr R : S &> (= x 5)` (ANY clause) → **REGISTRATION
`prologos-error`** naming the facts-only rule. `defr R : S || <rows>` (facts only) → unchanged
(still schema-checked + schema-typed). `defr R [?a] &> …` (un-schema'd rule) → unchanged. (NB:
solve on an unregistered relation ERRORS `"Unknown relation"` — assert the REGISTRATION error,
not solve behavior.)

### 7.5 C.2 — activation (Q-C3 → Option A)
The `type-pred` object feeds `relation-column-typer`'s un-schema'd (else) branch as a
**third positional source** (a declared-type UPPER BOUND), making un-schema'd rule
relations typeable and feeding Aspect B's typed solve rows. Two gaps closed by the
spine: inline `[?x:Int]` doesn't parse today (§7.3's `parse-rel-params` work); and
`expr-logic-var` infers to a hole ignoring ctx (typing-core.rkt:2897) — **Option A
sidesteps this by never touching the arm** (a dedicated driver-level check reading the
object), uniquely avoiding the pipeline.md `qtt.rkt:2109` double-patch.

**REFRAMED (2026-07-21, gates C.d — confirm with owner before opening C.d).** The C.c
redesign (§7.4) reframes `?x:Int` on a **rule** var as a **guard / unary constraint
`Int(x)`** (runtime/UCS altitude), NOT a static output-contract. So C.2/C.d's "feed the
declared param type as a static UPPER BOUND to type un-schema'd rule relations" is really
the guard's **static projection** — sound only once the guard prunes at runtime (UCS).

**RESOLVED (2026-07-21, owner — Aspect C CLOSES here).** The static validation on grounded
fact relationships (the C.c facts-only gate + the existing schema fact-row checking) was the
**highest-motivation** work and is delivered. Types-as-predicates (`?x:Int` as a runtime
domain-constraint `Int(x)`) is **larger design work DEFERRED to a UCS track** — captured in
the handoff note [`2026-07-21_UCS_TYPES_AS_PREDICATES_NOTE.md`](2026-07-21_UCS_TYPES_AS_PREDICATES_NOTE.md)
(UCS Track 6). So **C.d is DEFERRED to UCS, not a Rel T1 deliverable**; Aspect C = C.a + C.b
+ C.c. C.b already STORES the type-preds (0 consumers) — the UCS track inherits them, nothing
is lost. The old C.c → C.d "soundness-parasitic" ordering DISSOLVED: the facts-only gate
stands alone (it does not secure any C.d upper-bound feed).

### 7.6 Build partition (soundness-atomic)
- **C.a** — REPRESENTATION SUBSTRATE: the `type-pred` value (type-EXPR + predicate-SET
  slot, NO stub) + the smart-constructor `param-info` field. Pure substrate, no behavior.
- **C.b** — READER + PARSER: fused `?x:Int` / `x:Int` (both readers, both languages,
  after the spike) + the `parse-rel-params` `:` branch (populates C.a) + the functional
  binder path + the sexp symbol-split + the chained-colon diagnostic. **First
  end-user-visible green**: `?x:Int`/`x:Int` parses in both readers/languages, parse-
  and-store only, NO typing. Level-3 testable.
- **C.c** — **REDESIGNED (§7.4)**: schema ⟹ facts-only BLOCKING well-formedness gate
  (driver-level sibling). NOT the superseded clause-conformance check. Complete + sound.
- **C.d** — **DEFERRED to UCS (§7.5 RESOLVED, 2026-07-21)**. `?x:Int` on a rule var is a
  guard `Int(x)` (runtime domain-constraint), not a static contract → the static activation is
  UCS's work (UCS Track 6, handoff note
  [`2026-07-21_UCS_TYPES_AS_PREDICATES_NOTE.md`](2026-07-21_UCS_TYPES_AS_PREDICATES_NOTE.md)).
  **Aspect C = C.a + C.b + C.c** (closes here). The old C.c → C.d "soundness-parasitic"
  ordering DISSOLVED — the facts-only gate stands alone.
- **Tests are PER-PHASE** — C.a/C.b/C.c/C.d each bring their own test delta in their
  completion gate (the test file grows per phase); there is NO standalone C.T phase
  (see workflow.md "Tests are PER-PHASE"). C.b brings the parse-and-store tests (incl.
  the three-level WS validation); C.c brings the clause-typing tests **incl. the
  Aspect-B-hole-closed regression** (§7.4 Acceptance); C.d brings the un-schema'd
  rule-relation typed-row tests. **C.close** — folds into `X.close`.

### 7.7 Deferred (named) + watchouts
- **Deferred to UCS/CLP**: the runtime domain-constraint reading (lower the SAME
  `type-pred` object to the `Int(x)`/`type-guard` goal — the rejected-as-static shape,
  correctly relocated as the future RUNTIME LOWERING TARGET) + refinement types (`Int@pos`).
- **Scaffolding (name ONCE, track-level)**: the imperative registration-time clause
  typing is off-network (0 propagators, 0 cell-writes) at Aspect-B parity; retirement
  owner = on-network clause typing (PPN-successor / UCS era).
- **Non-monotone cap (name now, so UCS isn't cornered)**: the column type =
  join-of-positional-contributions CAPPED by the declared type (a MEET / narrowing,
  non-monotone) → the deferred on-network reading belongs at a **RETRACTION stratum
  S(-1)**, NOT S0 monotone (else CALM is violated).

### 7.8 C.a — grounding + implemented mechanism (LANDED)
Grounding-audit `wf_af338130-cf0` (4 HEAD-pinned facets + completeness critic, HEAD
`247efefa`) + main-session R-lens (empirical scratch verification). Load-bearing
outcomes:

- **`type-pred` shape (D-C.a-1)**: `(struct type-pred (preds) #:transparent)` with
  `preds : (listof expr?)` — **ONE list slot** (the predicate SET); `?x:Int` →
  `(type-pred (list (expr-Int)))`. Mirrors the runtime narrow-var side-table's
  list-per-var (`global-constraints.rkt:73`), lifted symbol→expr (down-projects to the
  symbol `value-matches-type?` `global-constraints.rkt:475` wants; up-holds a refinement
  a bare symbol never could). No stub lowering fn, no separate "primary type" slot.
- **Home (D-C.a-2)**: `relations.rkt`, beside `param-info` — cycle-free (relations
  already requires `syntax.rkt` for `expr?`; C.a never calls typing-core's
  `schema-field-type->expr`, which is what emits the `(expr-Int)`/`(expr-fvar …)`
  type-EXPRs C.b will store).
- **`type-pred` is NOT an AST node** → only pipeline.md **New-Struct-Field** applies,
  **not** New-AST-node: `param-info`/`relation-info` never flow through
  zonk/subst/reduction/pretty-print, and the relation store is **not** pnet-serialized
  (`serialize-module-state` omits it) → no `.pnet` "impostor-vector" obligation. (The
  AST-side type carrier a *later* sub-phase might add WOULD hit that — C.a does not.)
- **Smart-constructor (D-C.a-3), compile-verified** — the naive form in §7.2/§7.6
  (`#:constructor-name make-param-info` + a same-name wrapper) **FAILS TO COMPILE**
  (`identifier already defined: param-info`). The working idiom:
  ```racket
  (struct param-info (name mode type)
    #:transparent #:name param-info-desc #:constructor-name make-param-info-raw)
  (define (param-info name mode [type #f]) (make-param-info-raw name mode type))
  ```
  Accessors stay `param-info-name` / `-mode` / `-type`; predicate `param-info?`;
  transformer binding (for `match`/`struct-out`) is `param-info-desc`. It **forces two
  provide-surface edits** at `relations.rkt:38`: `(struct-out param-info)` →
  `(struct-out param-info-desc)` **plus** an explicit `param-info` (struct-out does not
  re-export the wrapper). `#:auto #:auto-value #f` is the tempting shortcut —
  **rejected**: it forbids positional construction (mutation-only), conflicting with the
  "positional default" + immutable-value intent.
- **`param-info` type field (D-C.a-4)**: `type` (default `#f`) holds a `type-pred` or
  `#f`; **per-variant-per-position** (the field, not a relation+position side-table —
  a relation carries multiple variants each with its own params, so a side-table's
  position collides across arities). Store-only in C.a (**0 `param-info-type`
  consumers**, verified); consumer = C.c/C.d.
- **Verification**: `raco make driver.rkt` clean; the 3 benchmark files that construct
  `param-info` (`benchmarks/micro/bench-{track2b-overhead,track2b-solver,solve-pipeline}`,
  NOT exercised by the suite) compile clean; Rel acceptance 0-errors; +6 unit tests
  `tests/test-rel-t1-typed-vars.rkt` (2-arg default, 3-arg typed, accessors, predicate,
  `equal?`, `type-pred` round-trip); **full suite 8950/468/0**.

### 7.9 C.b.1 — reader/parser (relational, both readers) — LANDED
Grounding-audit `wf_c8b8c25b-207` (5 facets + critic, HEAD `47049154`) + a **main-session
instrumented spike** (a temporary `eprintf` in `parse-rel-params` on the real
`process-file` path). Sub-phased per owner: **C.b.1 = relational both-readers** (this);
**C.b.2 = functional both-readers** (deferred — the functional binder reuses the
pre-existing `binder-info.type`, no type-pred).

- **The corrected reader model (spike + instrument)**: WS SPLITS `?x:Int` → `?x` + a
  colon-prefixed **SYMBOL** `:Int` (`keyword? = #f`); sexp GLUES → one symbol `?x:Int`.
  (An initial end-to-end arity inference wrongly suggested "glued in both" — the engine
  is **arity-lenient**, masking a leaked `:Int` param; the instrument settled it. Lesson:
  instrument the parse, don't infer reader shape from arity.) The pre-C.b.1 baseline was
  a **2×2 of four different wrong behaviors** (WS-rel: arity inflation; sexp-rel: name
  corrupted to `x:Int`; WS-fn: parse-error/two-binders; sexp-fn: binder named `x:Int`).
  C.b.1 fixes the two relational cells — a **pre-existing latent bug** (any `defr R
  [?x:Int]` silently mis-parsed).
- **Convergence = the PARSER ARM** (`parse-rel-params`), tokenizer **untouched**, **no
  test-suite sweep** (the design's preferred outcome). A `colon-symbol?` helper + a
  lookahead loop handle both shapes: WS consumes the trailing colon-symbol; sexp splits
  the glued symbol *after* `extract-mode-annotation` (mode strip must precede the split);
  `::` module paths are NOT type splits (empty-segment guard); chained `?x:C1:C2` →
  reject; spaced `[?x : Int]` (bare `:`) → a guiding "use fused" diagnostic (fused-only,
  per owner).
- **The carrier**: the per-param element grows from a `(name . mode)` cons to a
  `(name mode type-name)` **3-list** (untyped → type `#f`; literals stay
  `(#:literal . value)`). This is a **New-Struct-Field-in-spirit sweep over opaque list
  data** — the ~6 consumers reading `(cdr p)` for mode were updated to read slot 2
  defensively (`list?`-guarded, so schema-typed 2-cons synth-params still work):
  elaborator `surf-defr-variant` (literal-rebuild → 3-list, type-name→EXPR conversion,
  rel-env mode) + `surf-rel` (params converted, mode), relations `expr-rel->relation-info`
  + `expr-variant->variant-info` (type-pred wrap), and test-parser-relational's 6 param-
  shape assertions. `reduction.rkt` reads `(car p)` only — safe. `expr-logic-var` stays
  2-field (design-mandated).
- **Decomplection realized**: parser emits the type-NAME symbol (no type-pred datum);
  elaboration converts NAME→EXPR (`schema-field-type->expr`); relations wraps `type-pred`.
  Each layer does its own job; no layer imports another's (relations has no typing-core
  edge — that would be a cycle).
- **Verification**: `raco make driver.rkt` clean; WS probes (arity/multi/mode/mixed +
  name-clean connection `{:q 1}` where pre-C.b.1 was `nil` + chained/spaced rejects);
  Rel acceptance 0-errors; tests grown — `test-parser-relational.rkt` (sexp parse-level:
  fused split, mode+type, untyped, chained-reject; +6 sweep-fixes) and
  `test-rel-t1-typed-vars.rkt` (direct-pipeline store proof `parse→elaborate→
  expr-variant->variant-info` since the process-file store is module-scoped; +WS
  name-clean + chained via output-capture); **full suite 8959/468/0**.
- **Scaffolding / off-network**: C.b.1 is reader/parser + imperative registration-time
  storage (0 propagators, 0 cell-writes) at Aspect-B/C.a parity — inherent to a front-end
  phase; retirement = the on-network-typing horizon (§7.7).

### 7.10 C.b.2 — reader/parser (functional, both readers) — LANDED
The functional companion to C.b.1, reusing the C.b grounding-audit (`wf_c8b8c25b-207`
facet-3 + critic) + main-session probes. **No new grounding-audit** — facet-3 already
ground the functional surfaces; the one open item (the critic's "which binder parser
runs") was **empirical**, resolved by probing.

- **Path resolution (the critic's flagged unknown)**: for a functional lambda
  `[fn [x:Int] x]`, BOTH WS contexts probed (top-level application AND `def :=` RHS) AND
  sexp funnel through **`parse-binder` (parser.rkt:3689)** via the datum path — the WS
  tree-parser `parse-fn-tree` (which calls `parse-binder-bracket`) **falls back** to the
  datum path for these forms (same as defr/rel). So C.b.2 is **one function, two arms**;
  the tree-parser `parse-binder-bracket` is NOT on the fn path — adding a fused arm there
  would be speculative (unreached). *(If a future fn context is found to route through the
  tree-parser, that arm becomes evidence-driven follow-up — named, not silently skipped.)*
- **The functional side needs NO type-pred** — `binder-info` (surface-syntax.rkt:432)
  already has a `type` slot the elaborator's `surf-lam`/`surf-pi` arms already elaborate
  (elaborator.rkt:1108/1138/1180). So C.b.2 just ROUTES the fused form to produce the same
  `(binder-info name #f <type-surf>)` the spaced `[x : T]` arm produces — and the fused
  form types **identically** (verified: `[fn [x:Int] x]` → `Int -> Int` in both readers,
  same as `[fn [x : Int] x]`; the declared type is enforced).
- **Two arms in `parse-binder`**: WS delivers `(x :Int)` (2 elems, `:Int` a colon-SYMBOL)
  → a new 2-elem arm keyed on a colon-symbol that is NOT a mult (`:0`/`:1`/`:w`/`:m`
  excluded, so multiplicity annotations are untouched — `[fn [x :0 Int] x]` still parses
  as m0); sexp glues `x:Int` into ONE symbol → the length-1 arm splits it on `:` (`::`
  module paths excluded via the empty-segment guard). Chained `x:Int:Even` rejected in
  both (WS 3-elem colon-symbol arm + sexp >2-segment split). The type-surf is built via
  `parse-datum` on the type name (yields e.g. `surf-int-type` for `Int`) — identical to
  the spaced arm.
- **`:m`/`:w` collision (design named)**: WS `:w`/`:m`/`:0`/`:1` tokenize as
  colon-annotations (multiplicity), never keyword — the fused-type arm excludes them, so
  a type literally named `w`/`m`/`0`/`1` cannot be fused (use spaced). Sexp has no such
  tokenizer reservation (a glued `x:w` splits to type `w`). The pre-existing `:m`
  tree-parser/tokenizer asymmetry is orthogonal and left as-is.
- **Verification**: `raco make driver.rkt` clean; WS + sexp probes (fused → `Int -> Int`,
  type enforced, chained rejected, `:0` mult preserved); Rel acceptance 0-errors; tests —
  `test-parser-relational` (sexp parse-level: fused `(fn (x:Int) x)` → binder type
  `surf-int-type`, bare → `surf-hole`, chained → error) + `test-rel-t1-typed-vars` (WS
  `[fn [x:Int] x]` → `Int -> Int` end-to-end); **full suite 8963/468/0**.

### 7.11 C.c — schema ⟹ facts-only gate — LANDED
Implemented the REDESIGN (§7.4), not the superseded clause-conformance check. Owner
co-design in a side chat superseded the grounding-audit-driven design; the audit
(`wf_2f21daa9-252`) stays valid for code facts.

- **What landed**: a driver-level sibling `check-relation-schema-facts-only rel-info`
  (driver.rkt, beside `check-relation-schema-rows`) that returns an error string iff the
  relation has a schema AND some variant has clauses; wired FIRST in the registration `cond`
  (before schema-rows/floundering), BLOCKING (registration runs only in `[else]`). ~20 lines,
  0 typer edits, 0 clause-walk.
- **Why this is better than the superseded check (the VAG win)**: rejecting the ill-formed
  input is **complete** — a schema'd rule can never register, so the schema branch only ever
  types facts-only schema'd relations (rows checked by check-relation-schema-rows). The
  literal clause-check was **incomplete** (misses transitive/`is`/compound bindings). No
  `has-clauses?` typer guard (belt-and-suspenders avoided).
- **Pre-check (Relay Note discipline)**: grepped examples/lib/tests for a schema'd relation
  with `&>` — **none active** (`edge:Edge`/`movies:VHS`/`package:Package` are facts-only;
  `ruler`/`ready-to-watch`/`depends` are un-schema'd rules; the punify-p3 schema'd-rule
  examples are all commented). So the gate breaks nothing.
- **Verification**: `raco make` clean; probe (`defr sf : S || …` registers + solves
  `[{:a 5}{:a 7}] : [List {:a Int}]`; `defr sr : S &> (= x 5)` → registration error
  "must be facts-only"); Rel acceptance 0-errors; `test-defr-schema` (pre-existing schema'd
  FACT tests) still green; +3 tests `test-rel-t1-typed-vars.rkt` (reject / facts-only-ok /
  un-schema'd-rule-unaffected); **full suite 8966/468/0**.
- **Refuted premise added to the cascade**: "a blocking literal-clause check closes the
  Aspect-B hole" — REFUTED (incomplete). See §7.4.

---

## 8. Polish — the POL aspect roster

**Expanded 2026-07-24** with the owner's hand-testing list (developed in
`foray.prologos` via interactive eval; source of record:
`docs/standups/standup-2026-07-19.org` § "Polish points for REL" — READ-ONLY).
Ten aspects in two clusters. Each syntax aspect (POL.7–9) carries the full
three-level WS validation + WS-Impact obligations (workflow.md).

### Correctness / UX-error cluster

- **POL.1 — Answer-set dedup** *(pre-existing)* — `solve` returns one row per
  derivation path (diamonds → duplicate rows). Add distinct/answer-set
  semantics. ⚠ Interacts with POL.4: dedup semantics also decide whether a
  DFS first-hit short-circuit for ground goals is observable (D.2 deferred
  exactly this — artifact §14).
- **POL.2 — Drop `_anon` wildcard keys** *(pre-existing + owner repro)* —
  `_` gensym keys leak into result maps:
  `solve (truths b1 b2 b3 _)` → `'[{:b3 1, :_anon241999 1, :b2 1, :b1 1} …]`;
  should be `'[{:b3 1, :b2 1, :b1 1} …]`. Anon vars must not be projected into
  the solution set. (B0's key-kernel + the `:_anon<gensym>` convention are the
  known surfaces — grounding §4.)
- **POL.3 — Declaration-order keys** *(pre-existing, owner)* — present row keys
  in predicate/fact declaration order, not hash order.
- **POL.4 — Arity mismatch must ERROR** *(owner, two repros — unifies standup
  points 2+3)* — the engine is arity-LENIENT today and both directions
  misbehave: **under-application** `solve (truths ?b)` on 4-ary `truths` →
  silent `nil`; **over-application** `solve (light-vehicle v1 v2)` →
  unbound-echo rows `'[{:v1 "golf-cart", :v2 v2} …]`, `solve (truths b1 b2 b3
  b4 b5)` → `nil`. Target: a Prolog-style error naming the available arities
  (`Unknown procedure truths/1 — however, there are definitions for:
  truths/4`). ⚠ Watchouts: (a) multi-arity relations are first-class
  (`relation-info-arity = #f`); (b) the INTERNAL `goal-args = '()` convention
  means "enumerate via param names" (bench/tests + tier-1 rely on it) — the
  arity gate belongs at the SURFACE goal sites, not inside `solve-goal`;
  (c) this is the D.2.c "arity-lenient nil trap" (artifact §14 finding 3) —
  the corpus-generator test is the standing regression gate for the fix.
- **POL.5 — `def` on a `solve` result: multiplicity violation** *(owner
  repro)* — `def needs-rewind := solve (movies false title year)` →
  `ERROR: Multiplicity violation`. Diagnosis needed: likely the QTT reading
  of the solve form / row value under `def`'s binding multiplicity (Aspect B
  registered the 5 solve structs `#f`-dispatch + imperative-compute; the qtt
  arm may be the unwired half). Probe first; fix at the checker seam.
- **POL.6 — Fused `x:Int` in `defn` params: the last mile** *(owner repro;
  adjacent to Rel but C-arc-owned)* —
  `defn my-square [x:Int] : Int  * x x` → "cannot infer the type of an
  unannotated parameter". C.b.2 (`c6b8e81f`) wired fused binders through
  `parse-binder` (fn-binders, both readers); the `defn` param-list path
  evidently does not route through it. Wire `defn` (and multi-arity clause
  heads) to the same fused-binder arm.

### Syntax / ergonomics cluster (WS reader/parser features)

- **POL.7 — Single-line facts with `|` separators** *(owner)* —
  `defr digits [?d]` + `|| 0 | 1 | 2 | … | 9` on one line. Today fact rows
  are newline-separated only (and a one-line multi-row literal silently
  mis-parses as ONE wrong-arity row — dailies Watching 3; this aspect
  RETIRES that trap by making the intent expressible). ⚠ WS Impact: `|` is
  tokenized as `$pipe` (ADT literals + multi-arity `defn` clause separator)
  — the fact-block arm must scope its `$pipe` handling to the `||` group.
- **POL.8 — Implicit rule-clause groups in `defr`** *(owner)* — drop the
  delimiting parens around rule-clause goals, layout-based like the
  functional language:
  `&> fruit-color fruit "blue"` ≡ `&> (fruit-color fruit "blue")`;
  continuation lines indent past the `&>`; nesting by deeper indent
  (`not` ⤷ `= color not-color`). Both spellings remain legal (additive).
  ⚠ WS Impact: tree-parser layout rules; interacts with POL.9's grammar.
- **POL.9 — Implicit `solve` at top level** *(owner; ⚠ DESIGN QUESTION —
  needs co-design before implementation)* — a bare relational clause outside
  `defr` carries an implicit `solve` (mirroring the functional language's
  implicit `eval`): `fruit-not-of-color f "red"` ≡ `solve (…)`; anonymous
  `rel [fruit] &> …` likewise. **The open question is grammar ambiguity**:
  a bare `foo a b` at top level currently reads as function application —
  disambiguation plausibly = relation-registry lookup at elaboration
  (relations are registered before use), but forward references, shadowing,
  and error-message quality under a miss all need settling. Co-design with
  the owner first; then the WS-Impact analysis.

### B3 — rule-relation codata rows (tracked as its own aspect row)

The owner (2026-07-24) elevated the B2-deferred rule-bearing typing to an
aspect of its own — see the **B3** tracker row. It is the largest usability
item in this phase: rule solutions currently type as `_` and cannot compose
with the F1 records/row-polymorphism machinery. Sequenced ahead of the POL
items below (owner: "one of the most important facets").

### Sequencing note (proposed, owner confirms)

**B3 first** (grounding → co-design → implement), then the correctness
cluster (POL.2 → POL.4 → POL.5/POL.6 diagnosis-led), then POL.1 + POL.3
(both touch row assembly — share a slice), then syntax cluster POL.7 →
POL.8, with POL.9 opened as a design conversation in parallel. Per-phase
tests per workflow.md; acceptance file grows a POL section.

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
6. **C.a → C.b → C.c → C.d** typed logic vars + schema-as-facts (§7.6): substrate →
   reader/parser (first green) → BLOCKING C.1 → C.2 activation (C.c with-or-before C.d).
7. **Polish**.
8. *(tests are per-phase — no standalone test phase; see workflow.md "Tests are PER-PHASE")*.
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
- **Q-C** (Aspect C) — ✅ **RESOLVED (Stage-3, 2026-07-21, §7):** `?x:Int` = Curry-Howard `Int(x)` = type (owner vision); first slice = **(A)-in-(B)** with a **general type-EXPR carrier** (owner-confirmed: not literal node-reuse; runtime down-projects). Spine: reader→`(name,type-EXPR)` (both readers/langs, additive; STOP there) → elaboration builds the ONE `type-pred` value (type-EXPR + predicate-SET list slot, NO stub; Q-C1 Option 2′) → **BLOCKING** driver-level C.1 (arm untouched; Q-C3 Option A) + C.2 upper-bound feed. C.1 closes the already-shipped Aspect-B schema-branch soundness hole (soundness-parasitic); C.c with-or-before C.d. Fused-reader convergence (tokenizer vs parser-arm) gated on ONE implementation-time spike. Runtime domain-constraint + refinement DEFERRED to UCS (the same object lowers down). Panel `wf_09b5988d-e72` + R-lens + owner co-design.
- **Q-B** (Aspect B) — ✅ **RESOLVED (Stage-3, 2026-07-20, §6):** keys = **`Κ′` (query-var), always** (Prolog-parity; `^` owns rename); type-source = **schema-projection + fact-observation** (F1 schema/`Map` split, one layer up; rule-relation codata → runtime "at the end" / C.1); posture = **`#f`-dispatch + imperative compute** (5th-refusal reachability carries composition); shared **keys-out kernel** (§6.5); deep shapes + presence-lattice + cache-hit gap DEFERRED. Panel `wf_e00d9318-3b6` + R-lens + owner co-design.

---

## 12. References
- Grounding: `wf_7ad61165-85d` (surface), `wf_1891cfd0-197` (NAF isolation) — dailies `2026-07-19_dailies.md` LOG.
- Aspect-B (§6): grounding `wf_ec53bc09-c31` (solve-typing surfaces) + design-options panel `wf_e00d9318-3b6` (Q1/Q2/Q4/Q5; Q3-cluster failed, folded into §6.6) — dailies `2026-07-19_dailies.md` LOG (2026-07-20 entries).
- Aspect-C (§7): grounding `wf_8083a27e-2a9` (tokenizer + C.1/C.2 surfaces) + design-options panel `wf_09b5988d-e72` (Q-C1/Q-C2/Q-C3) — dailies `2026-07-19_dailies.md` LOG (2026-07-20/21 entries). `?x:Type` CLP prior art: `docs/research/2026-03-16_NEXT_GEN_LOGIC_PROGRAMMING.tex`; refinement=traits through-line: `docs/tracking/2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md`.
- Seed: [`2026-07-19_REL_SOLVE_TYPING_NOTE.md`](2026-07-19_REL_SOLVE_TYPING_NOTE.md) (its `&>` label superseded by §4).
- Rel Master: [`2026-07-19_REL_MASTER.md`](2026-07-19_REL_MASTER.md).
- Rules: `.claude/rules/propagator-design.md` (broadcast, set-latch, watcher/threshold variants), `.claude/rules/stratification.md` (S1 NAF), `.claude/rules/structural-thinking.md` (retraction as narrowing), `.claude/rules/on-network.md` (mantra).
- Path-Selection (downstream, `^` rename): `2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md`.
- `?v:Type` CLP prior art (deferred): `docs/research/2026-03-16_NEXT_GEN_LOGIC_PROGRAMMING.tex`.
