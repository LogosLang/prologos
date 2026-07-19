# Rel Track 1 — Relational Language Usability (Stage-3 Design)

**Series**: [Rel](2026-07-19_REL_MASTER.md) · **Track**: 1 (name provisional) ·
**Date opened**: 2026-07-19 · **Stage**: 3 (DESIGN) — **IN PROGRESS**.

> **Status banner**: This is a WORKING Stage-3 artifact. The scope is captured;
> the grounding is done + verified; the **design options are OPEN** and the
> **adversarial principles challenge is a FIRST PASS** to be worked through
> together. No implementation until the options are settled and this doc's
> Progress Tracker shows the design phases ✅. Per the objective-PIR gate, this
> track carries a mandatory `X.close` phase (reserved below) and gets a PIR.

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
- **Polish**: answer-set dedup, drop `_anon` wildcard keys, predicate-declaration-
  order keys.
- **Held (do NOT start until owner asks)**: efficient fact representation + query
  optimization — a deeper/frontier research agenda.
- **Deferred to a later UCS track**: `?v:Type` as CLP(X) domain-constraint
  *resolution*. This track uses only the **static-typing** reading of type info.

---

## 2. Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| **S3** | This design doc — scope, options, adversarial principles pass, NTT model, SRE lens | 🔄 | Options OPEN; challenge = first pass |
| **P0** | Acceptance file (`.prologos`) exercising the target relational surface (commented targets uncommented per phase) | ⬜ | Phase-0 discipline |
| **A.1** | Top-level goal-dispatch (echo fix): `solve`/`solve-one`/`explain` accept `not`/`guard`/`cut`/conjunction | ⬜ | Shallow; independent correctness patch |
| **A.2** | NAF per-binding isolation on the on-network path | ⬜ | The deep core; invalidation fork OPEN |
| **A.3** | Safe/floundering negation (groundness gate) | ⬜ | No check exists today |
| **A.4** | Guard: FFI-crash residuation + floundering; (per-binding leak — scope TBD) | ⬜ | S0 fire-once shape ≠ NAF's S1 shape |
| **B.1** | Typed solution rows — codata-observation path | ⬜ | Untyped-relation fallback; first-class |
| **B.2** | Typed solution rows — schema-projection path + rename query-var → field name | ⬜ | Ties to Path-Selection `^` |
| **C.1** | schema-as-facts: rule-clause typing (facts already typed) | ⬜ | Extends `check-relation-schema-rows` |
| **C.2** | signature-schema activation as a logic-var typing source | ⬜ | Currently elaborated-but-dead |
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
- **Polish**: answer-set dedup; drop `_anon` wildcard keys; declaration-order keys.

### Held — do NOT start until the owner explicitly asks
- **Efficient fact representation + query optimization.** A deeper, possibly
  frontier research agenda (query-opt + data representation for performative fact
  queries). Prior design conversation may exist in standups; adjacent to the RPF
  track. **Named here so it is not lost; not to be designed in this track.**

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

### A.2 — NAF per-binding isolation (the deep core) — INVALIDATION FORK **[OPEN]**

**Common to any fix**: the S1 stage must stop collapsing `v` to one binding and
instead operate over the generator's **enumerated tagged bindings** (the raw
`tagged-cell-value-entries`, the same structure dissolution reads at
relations.rkt:2706), evaluating the negation **per binding, each under its own
worldview**.

The fork is *how a failing binding is invalidated*:

- **Option B — reuse the existing per-fact-row assumption + `solver-retract`.**
  The generator already tags each binding with a distinct fact-row bit. For a
  binding whose negation *fails* (inner goal provable), retract that binding's
  fact-row aid → narrows its decisions-state component → the worldview-projection
  (decisions-state-bitmask ONLY, propagator.rkt:975) recomputes → that row's
  dissolution entry vanishes. No new bits. Requires threading `ctx` into the
  NAF-pending entry.
- **Option A — allocate per-binding NAF bits via `solver-amb`** (atms.rkt:397)
  over the enumerated bindings, invalidate those. General (works when the
  generator does NOT tag per-branch), but more machinery; the install-time
  naf-bit becomes partly vestigial.
- **Option C — compound nogood `{naf-aid ∧ fact-aid}`: RULED OUT** — nogoods are
  NOT projected into the worldview-cache (only decisions-state is), so a compound
  nogood leaves dissolution visibility unchanged (grounding-verified).

**Deciding factor**: whether *non-fact* (rule/computed) generators also tag
per-branch. A one-shot probe answers it. If yes → B suffices; if no → B for
fact-generators + A for the rest, or A uniformly.

### A.3 — safe / floundering negation
Add the groundness gate: a negation var *bound by a generator* runs NAF
per-binding (safe); a var *never bound* → **clear floundering error**, not a
silent vacuous success. (Standard `\+` groundness discipline.)

### A.4 — guard
- **FFI crash**: gate guard-fire on condition-var readiness — **residuate** when
  the var reads bot (reuse the discrimination residuate-on-bot substrate), and a
  **flounder terminal** at quiescence (residuation alone is unsound — a never-bound
  guard silently passes). Option "substitute like DFS" is a red herring (subst
  keeps unbound vars; DFS's safety is from goal *ordering*).
- **Per-binding leak**: guard shares NAF's single-bit structure but at S0
  (fire-once), so its per-binding fix differs. **Scope decision [OPEN]**: fix
  guard crash+floundering now (demo-adjacent), defer guard's per-binding leak.

### NTT model (on-network — **broadcast, NOT step-think**)

The first sketch used a nested `for` over bindings — imperative iteration over
*independent* items, the `for/fold`-is-step-think smell. Corrected form: the
per-binding negation checks are **embarrassingly parallel** (binding i's result
is independent of binding j's) → **one broadcast propagator over the N bindings**,
and the invalidation *emerges structurally* from contradiction rather than an
imperative "if provable then retract."

```
-- S1 NAF stage, on-network form:
-- items = the enumerated tagged bindings of the negated goal's generator var
-- (each item is independent → broadcast, per propagator-design.md § Broadcast)

stage naf : after S0 {
  install for each pending not-goal:
    broadcast over bindings β ∈ raw-entries(scope-cell) {          -- ALL-AT-ONCE
      item β ⇒ with-worldview mask(β) {                            -- IN-PARALLEL, isolated
        install inner-goal[v ↦ β] on a per-β sub-view              -- structurally emergent
      }
    }
  -- contradiction (inner provable under β's worldview) STRUCTURALLY narrows
  -- β's own component via the existing contradiction→narrow→projection chain;
  -- no imperative "check-then-retract" — the narrowing EMERGES.  -- INFORMATION FLOW
}
```

**Mantra audit of this form** (the discipline that surfaced the step-think):
- *All-at-once* — one broadcast installs all N per-binding checks; not a loop. ✔
- *All-in-parallel* — broadcast-profile lets the scheduler decompose across
  threads; per-binding worldviews isolate. ✔
- *Structurally emergent* — invalidation falls out of contradiction under each
  binding's worldview, not a control-flow `if`. ✔ **(This is the deeper challenge
  to Option B's "call `solver-retract`": is the retract-call itself imperative
  dispatch, or the emergent-narrowing primitive? — carry to the challenge.)**
- *Information flow* — negation results flow through cells / decisions-state
  narrowing, not return values. ✔
- *On-network* — broadcast propagator + cell narrowing; between-vs-within-round
  placement is a design point (see §SRE / threshold-consumer variants). ⚠ OPEN

**Full NTT model + Racket-correspondence table to be completed here before A.2
implementation** (propagator-track requirement).

### SRE lattice lens
- **Retraction as lattice narrowing** (structural-thinking.md): `solver-retract`
  narrows the **primary** decisions-state lattice; the worldview-cache is the
  **derived** projection that recomputes; dissolution reads the narrowed result.
  Option B *is* this principle; Option A adds a parallel bit-mechanism beside it.
- **Primary/derived**: decisions-state = primary; worldview-cache = derived
  (propagator.rkt:975 projects one from the other). The fix must narrow the
  primary, never patch the derived (why compound-nogood is ruled out).
- **Monotone/CALM**: per-binding worldview isolation via `merge-set`-style tagged
  entries is monotone; narrowing is the S(-1)-style non-monotone step, correctly
  isolated at the stratum boundary.
- **Threshold-consumer variant** (propagator-design.md): the per-binding
  invalidation is a *between-round* (stratum-handler, atomic-per-round) action,
  not a *within-round* threshold — consistent with S1 NAF running after S0
  quiescence. **Confirm in the challenge.**

### Adversarial principles challenge — **FIRST PASS** (two-column; to be worked together)

| Decision | Column 1 — catalogue (passes?) | Column 2 — challenge (MORE aligned? risk?) |
|---|---|---|
| **Fix on-network (not DFS)** | ✔ mantra; the leak lives on-network; the correct engine | Is routing top-level NAF to DFS ever tempting as a "quick fix"? That's off-network scaffolding — name it rejected, not deferred. |
| **Option B (retract fact-bit)** | ✔ correct-by-construction (reuses existing isolation); ✔ SRE-native (retraction=narrowing); ✔ minimal | Hidden coupling: depends on the generator tagging per-branch — for a *rule* generator it may under-isolate **silently** (works for the fact test case, hides a bug). Belt-and-suspenders smell if we ship B *and* keep a fallback "just in case." Resolve with the probe, not a dual path. |
| **Option A (solver-amb bits)** | ✔ general | Two bit mechanisms (install-time naf-bit + per-binding amb bits); the naf-bit goes vestigial for open-var — dual-mechanism red flag. More machinery for the fact case where B is native. |
| **The `retract`-call itself** | ✔ uses the real primitive | Is "handler checks provable, then calls retract" imperative dispatch wearing a cell hat? The deeper form = contradiction under each binding's worldview *structurally* narrows. **Challenge whether the fix should install per-binding contradiction and let narrowing emerge, vs call retract.** |
| **Thread `ctx` into pending entry** | ✔ real dependency (retract needs decisions-cid) | Not scaffolding — but name the coupling; is there a cell that already carries it? |
| **Guard crash → residuate + flounder** | ✔ reuses existing residuate substrate; ✔ mantra (readiness-gated, emergent ordering) | Residuation alone is unsound (silent pass) — the flounder terminal is load-bearing, not optional. Don't ship residuation without it. |

**Red-flag scan**: "quick fix via DFS" (off-network scaffolding — reject), "keep a
fallback just in case" (belt-and-suspenders — resolve with the probe), "the
naf-bit stays around" (dual mechanism — retire it where vestigial or justify).

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

## 11. Open questions (for the co-design + adversarial rounds)
- **Q-A2** the invalidation fork: B (retract fact-bit) + probe, vs A (solver-amb), vs the deeper emergent-narrowing form (challenge the retract-call).
- **Q-A4** guard scope: crash+floundering now, per-binding leak deferred?
- **Q-round** placement — between-round stratum vs within-round threshold for the per-binding invalidation.
- **Q-B** keying: rename query-var→field vs fresh positional Record.
- **Q-name** the track name.

---

## 12. References
- Grounding: `wf_7ad61165-85d` (surface), `wf_1891cfd0-197` (NAF isolation) — dailies `2026-07-19_dailies.md` LOG.
- Seed: [`2026-07-19_REL_SOLVE_TYPING_NOTE.md`](2026-07-19_REL_SOLVE_TYPING_NOTE.md) (its `&>` label superseded by §4).
- Rel Master: [`2026-07-19_REL_MASTER.md`](2026-07-19_REL_MASTER.md).
- Rules: `.claude/rules/propagator-design.md` (broadcast, set-latch, watcher/threshold variants), `.claude/rules/stratification.md` (S1 NAF), `.claude/rules/structural-thinking.md` (retraction as narrowing), `.claude/rules/on-network.md` (mantra).
- Path-Selection (downstream, `^` rename): `2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md`.
- `?v:Type` CLP prior art (deferred): `docs/research/2026-03-16_NEXT_GEN_LOGIC_PROGRAMMING.tex`.
