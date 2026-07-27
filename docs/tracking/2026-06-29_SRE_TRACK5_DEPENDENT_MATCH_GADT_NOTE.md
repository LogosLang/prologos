# SRE Track 5 — Dependent Match / GADTs: Grounding & Implementation Note

**Status**: Grounding note (pre-design). Captures verified machinery state so SRE Track 5 ("Pattern Compilation-on-SRE") can be designed without re-grounding. **Not** a design doc — no roadmap, no decisions beyond "deferred to a full SRE 5 track."
**Date**: 2026-06-29
**Linked from**: `2026-03-22_SRE_MASTER.md` (Track 5 row)
**Grounded at**: HEAD `73d3a13a` (two parallel HEAD-pinned agents + live `process-file` probes). Re-verify line numbers before trusting — they drift.

---

## §1 The question (already posed in our own docs)

`2026-03-22_SRE_MASTER.md:247` (Track 5, ⬜ not-started) asks: *"How much GADT expressivity do we already get from dependent types + spec annotations on constructors? (the '80% solution') And how much additional work would TMS-based branch refinement add?"* This note answers it with verified facts.

**One-line answer**: We already have the **existential half** (Σ) and the **equality substrate** (`Eq`/`refl`/`J`); the genuinely-missing, defining GADT feature is **index-refinement on pattern match** — and that is a real (but bounded) type-checker change, because `match`/`reduce` is **non-dependent** today.

## §2 What we already HAVE (verified at HEAD)

| Feature | Status | Evidence |
|---|---|---|
| Pi (Π, dependent function) | ✅ L3 | `expr-Pi` `syntax.rkt:383`; surface `<(x:A)->B>` |
| **Sigma (Σ, dependent pair = existential)** | ✅ type-checker; ⚠️ L3 `*`-type-syntax bug | `expr-Sigma` `syntax.rkt:386`; `[pair 3N true]:[Sigma Nat Bool]` (probe); L3 `*` unbound `track3-acceptance:333` |
| Universe hierarchy / levels | ✅ L3 | `expr-Type` `syntax.rkt:354`; `infer-level` |
| QTT multiplicities m0/m1/mw | ✅ L3 | `qtt.rkt`; `spec … {:1 A : Type}` in examples |
| **Identity type `Eq` + `refl` + `J`** | ✅ L3 (sexp form) | `expr-Eq`/`expr-refl`/`expr-J` `syntax.rkt:388,329,346`; `def p:(Eq Nat zero zero):=refl` (probe); `test-eliminator-typing.rkt` |
| Motive-carrying eliminators (`natrec`/`boolrec`/`J`) | ✅ | `syntax.rkt:339,371,346`; result type depends on target via motive |
| Built-in **indexed** families `Vec`/`Fin` + bespoke `vhead`/`vtail`/`vindex` | ✅ but hardcoded, NOT user-declarable | `expr-Vec` `syntax.rkt`; `typing-core.rkt:672-688`; user `data Vec … where` does NOT parse |
| User `data` parametric ADTs | ✅ L3 | `process-data` `macros.rkt:~7118` |

## §3 What GADTs ADD (given the above)

- **Existentials: substantially already present** via Σ. `data Showable = ∃a. Show a ⇒ MkShowable a` is `Σ(a:Type).(Show a)×a`. Value side works; only the `*`-type *surface* polish + a `:refines` sugar (`SPEC_FUNCTOR_AUDIT:232`, unimplemented) are missing.
- **The defining new capability = index-refinement on `match`.** Matching `e : Expr A` against `Lit : Int -> Expr Int` should make the checker *learn* `A = Int` locally in that branch. We have neither (a) indexed constructor returns nor (b) per-branch type-equality refinement.

## §4 The two gaps

### Gap-A — Formation (per-constructor indexed return types): 🟢 nearly free
`process-data` forces every ctor's result to the uniform `(TypeName params…)` (`macros.rkt:7193`); `{A}` are uniform *parameters*, never *indices*. **But** constructors are just opaque fvars with a declared type (`(def ctor : <ctor-type> …)` `macros.rkt:7202`), and the underlying machinery already accepts an arbitrary indexed codomain — **probe-verified**: `def my-vnil : <(A:(Type 0)) -> (Vec A zero)> := …` typechecks at HEAD. So GADT *formation* is "surface `data` syntax + `ctor-meta` carrying the index," not new type theory.

### Gap-B — Use (index-refining dependent `match`): 🔴 the real work, absent
`expr-reduce` carries `(scrutinee arms structural?)` — **no motive field** (`syntax.rkt:962`). `check-reduce-structural` pushes the **same** `expected-type` to every arm and instantiates the ctor with the **scrutinee's** indices (same for all arms) — the matched ctor's own index is **never unified back** (`typing-core.rkt:2522-2544`). Probe: a dependent `match` → *Type mismatch*, while the equivalent `natrec` *with a motive* typechecks.

**The tell**: we hand-write `vhead`/`vtail`/`vindex` (one eliminator per indexed type, `typing-core.rkt:672-688`) precisely *because* `match` can't refine. GADTs would let those be **derived**.

## §5 Implementation strategies + smallest path

Two strategies for Gap-B (both are *checker* work; the equality/unify substrate already exists):
- **(a) ADT + equality constraints** *(lower risk — recommended starting point)*: each ctor carries `Eq(Index,…)` constraints; matching introduces the equation and `J`-rewrites the goal. Leverages the already-built, already-tested `Eq`/`refl`/`J` kit.
- **(b) Native dependent match**: bake index-unification directly into `check-reduce`, mirroring how `natrec`/`vhead` already thread indices through their rules.

**Smallest principled path** (a phased SRE 5):
1. **Phase 1 — Formation** (Gap-A, cheap): `data` index telescope + per-ctor return type; `ctor-meta` carries indices. AST-pipeline checklist applies.
2. **Phase 2 — Dependent match** (Gap-B, the real work): make `check-reduce` refine — per arm, unify the ctor's index pattern against the scrutinee's index, extend the arm context with the equation (or reject impossible arms, e.g. unreachable `vnil`). Strategy (a) or (b).
3. **Phase 3 — Exhaustiveness over indices** (claimed by SRE Master to fall out of NF-Narrowing; verify).

**Substrate already present** (lowers Phase 2 cost): meta-unification (`unify.rkt`); `Eq`/`refl`/`J` (`syntax.rkt`); `Vec`/`Fin` already GADT-shaped; TMS/speculation + per-branch worldview bitmasks (the SRE Track 5 thesis: branch-refinement = a speculation scope installing local type equalities as propagators).

## §6 Caveat — a stale claim to NOT anchor on

`2026-02-27_2300_SPEC_FUNCTOR_AUDIT.md:263` claims *"Inductive families … `data Vec : Nat -> Type` works today."* **Verified FALSE at HEAD** — indexed `data … where` does not parse; `process-data` builds only uniform parametric returns. Do not design against this line.

## §7 Decision (2026-06-29)

GADTs are **not a blocker** — the DEMO's `data Json` is a plain (non-indexed) sum and works. The **value is concentrated in Gap-B** (dependent match); **Gap-A alone would be a half-feature** (you could declare + construct indexed types but not usefully match on them — the same "looks like it works but doesn't" trap as DEMO gap #3). Therefore: **do not ship a partial formation-only step; defer to a full SRE Track 5 design cycle** (Phases 1-3 above), for which this note is the grounding. Optionally, GADTs could become the DEMO's *next dogfooding forcing function* (e.g. a well-typed query/schema AST) — but even then it's the full treatment, demo-driven.

## §8 Key files

`macros.rkt` (process-data ~7118-7221; ctor-meta ~5929; parse-data-param-list ~6839; build-arrow-type ~7038) · `syntax.rkt` (expr-reduce 962; expr-Eq 388; expr-refl 329; expr-J 346; expr-natrec 339; expr-Vec/vnil/vcons/vhead ~397-411) · `typing-core.rkt` (**check-reduce 2489-2544 — the non-dependent rule**; J 654-668; natrec 629-641; vhead/vtail/vindex 672-688; Eq formation 2592-2599) · `elaborator.rkt` (surf-reduce ~2911; Eq/J/refl 887/1144/1190) · `unify.rkt` · `narrowing.rkt` (runtime FL narrowing — NOT type-level). Prior art: `2026-03-22_SRE_MASTER.md:55,229-247`; `2026-04-04_PPN_TRACK4_DESIGN.md:618-633` (typed eliminators on-network); `2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md:238` (existential caps via Σ).

## §9 Verified vs inferred

**Verified** (read + probed at HEAD `73d3a13a`): every "✅"/"probe" claim above; the non-dependent `check-reduce` rule; the formation-half probe; `Eq`/`refl`/`J` presence + L3 use; Σ presence; the stale SPEC_FUNCTOR_AUDIT line is false. **Inferred** (design-relevant, not built): that unification + `Eq` are the natural substrate to *implement* Phase 2 (capability exists; not wired into `match`); that NF-Narrowing yields exhaustiveness (SRE Master claim, unverified).
