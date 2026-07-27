# Partiality & Absence — the Design-Space Survey (Research Note)

**Date**: 2026-07-27 · **Status**: Stage-0 research artifact (owner conversation, this
session). **Engineering grounding only — never gating** (the D9 research-note posture).
**Trigger**: owner dissatisfaction with Maybe/Option ceremony + sympathy for tracked
nil + interest in Verse's `<decides>` effect + the search for "a corner not quite
expressed in languages heretofore."
**Method**: 6 primary-source research facets (Verse book chs. 07/08/13 + the ICFP'23
Verse Calculus; Mercury reference manual; Curry/WFLP'14; Icon/Tratt; Koka/Frank/
Swift/OCaml-effects; Liquid Haskell/Idris/gradual refinement; Clojure/Hickey "Maybe
Not"/Obj-C/SQL/Kotlin/Crystal/C#; effect-handler theory (Pretnar); why-not provenance
(Chapman & Jagadish, PUG, s(CASP), Whyline); Belnap/CL-restarts/Reiter) + an xhigh
synthesis. Workflow `wf_38453c98-332`. Verification status carried inline.
**Context at capture**: CIU T6 Path Selection mid-implementation (P2.b just ruled —
the two-tier principle: assertive access = loud counted miss; honest access =
`<V|Nil>`/Option). This survey evaluates the THIRD tier (logical/failure) and the
provenance corner. Related: design doc §5.10 round 7; `2026-07-26_CIU_T6_PATH_SELECTION_IMPL_handoff.md`.

---

# Partiality in Prologos — Research Synthesis (Decision Memo)

Sources: six primary-source research facets (Verse book + ICFP'23 calculus, Mercury reference manual, Curry/WFLP'14, Icon/Tratt, Koka/Frank/Swift/OCaml-effects, Liquid Haskell/Idris/gradual refinements, Clojure/Hickey/Obj-C/SQL/Kotlin/Crystal/C#, effect-handler theory, why-not provenance/s(CASP)/Whyline, Radul-Sussman propagators, Belnap/CL-restarts/Reiter). Verification status is carried inline; recall-grade items are flagged.

---

## 1. THE MAP — six positions in the partiality design space

### P1. Value-wrapping (Maybe/Option/Result)
**Who**: Haskell, ML, Rust; Swift is this position with maximal sugar (`if let`/`guard let`/`??`/`?.`).
**Mechanism**: absence reified as a sum-type value; every consumer unwraps.
**Buys**: absence is inescapable in the type; genuine **nesting** (`Some(None) ≠ None` — the one thing this position does that nothing else does); Swift proves consumption ceremony is mostly solvable with sugar.
**Frictions (documented)**: Hickey's breaking-change argument (verified from the Maybe Not transcript): relaxing an argument to `Maybe X` or strengthening a return from `Maybe Y` to `Y` — both *compatible* changes semantically — "break existing callers" both directions, because `T` and `Maybe T` are unrelated types. Option infects signatures transitively; `String??` from JSON decoding is notorious; Swift's `!` remains a crash-site culture. Sugar fixes reading, not evolution.
**Prologos occupancy**: the Option stdlib tier (`nth`, `kv-get -> Option V`). Note the C# timing lesson (verified): every month of stdlib surface written Option-first raises the cost of a later pivot. This is a *now* decision.

### P2. Typed nil-union + flow narrowing
**Who**: Kotlin `T?`, Crystal `T | Nil`, TypeScript strictNullChecks. The position Hickey explicitly endorses ("I have never used a type system where I have not desperately wanted this" — Dotty unions).
**Mechanism**: absence is a union member; control flow narrows it away; `V <: <V|Nil>` gives evolution-compatibility Maybe lacks.
**Buys**: near-zero ceremony + tracked safety + compatible evolution. Kotlin can *enumerate* its residual NPE sources (4: `!!`, explicit throw, init-order leaks, Java platform types) — the strongest safety claim any nullable language documents.
**Frictions (documented)**: every narrowing failure in the wild is a **mutation/aliasing** condition — Kotlin's stability table (var properties: never), Crystal's instance-variable cliff (#1 newcomer confusion since 2015), TS's callback/property-alias limits. And the **non-nesting collapse**: `T??` = `T?`, so "found nil vs not found" from a generic `find` is inexpressible — the one place Maybe genuinely earns its keep.
**Prologos occupancy**: `<V | Nil>` + `nil-safe-get` flow narrowing — this quadrant, already built. Prologos's differentiator, unclaimed: cells are monotone and narrowing can be a worldview-scoped fact, so the *entire* stability-table failure class is structurally absent. "Smart casts that survive aliasing" is a one-line positioning claim.

### P3. Effect-annotation (partiality on the arrow)
**Who**: Koka (`exn`/`div` in row types), Frank (ambient abilities, zero effect variables), Swift `throws`/`try`, Verse `<decides>`, Java checked exceptions (the cautionary corpse).
**Mechanism**: the success value stays **bare**; can-fail lives on the arrow/effect row, discharged by a handler or context.
**Buys**: no wrapping anywhere; the nesting problem dissolves *by construction* (failure isn't a value, so it can't nest — `exn` + stored `option` cleanly separates missing-key from stored-nothing); effects compose as row union, no transformer stacks.
**Frictions (documented)**: **coloring**. Hejlsberg's three arguments against checked exceptions (verified) transfer verbatim to declared effect rows: versioning (adding an effect breaks callers), aggregation blowup, and the workaround culture (`throws Exception` everywhere). Swift's answer: keep the bit **coarse** (untyped throws) and mark call sites (`try`); Frank's answer: no rows at all, the *ambient context* grants the ability; Koka's answer: infer everything. All three converge on: never enumerate causes in signatures.
**Prologos occupancy**: none explicitly — but two things are latent: (a) the two-tier ruling's assertive tier is exactly "untracked exn with a runtime ledger" (cause detail out-of-band in the error counter, signature carries nothing — which is Swift's split, minus the static bit); (b) Rel T1 POL.9's "goal-ness comes from context" is *literally Frank's ambient move* already ruled into the language. Prologos also has no vocabulary at all for Koka's `div` (a network that never quiesces) — a real gap, separate from absence.

### P4. Determinism/cardinality modes
**Who**: Mercury (`det`/`semidet`/`multi`/`nondet`/`failure`/`erroneous`, per **mode**, declared at module boundaries, **inferred** locally, checked against a documented partial order — all verified from the reference manual).
**Mechanism**: partiality = solution-cardinality of a relation. `semidet` = {0,1} — this is Verse's `<decides>` 25 years earlier, embedded in the full lattice Verse only ships a corner of. The stdlib carries a uniform doublet: `map.search` (semidet, fails) vs `map.lookup` (det, throws).
**Buys**: compiler-checked can-fail with no Option and no wrapper; exhaustive-match determinism falls out of switch detection; det compiles to straight-line code.
**Frictions (documented)**: the mode system underneath is the complexity sink — Mercury's own TODO admits partially-instantiated modes never shipped (the alias branch "has not been merged"); annotation burden multiplies with modes; the checker is syntactically conservative, so users contort code to please it.
**Prologos occupancy**: the runtime half exists in full — `solve` returns bags (nondet/multi), `solve-one` (semidet commit), zero rows IS failure, and QTT multiplicities are already a cardinality lattice *on binders*. What's missing is the static half — and Mercury's pain says: if you take it, take it **inferred** (its own rule: exported declare, local infer), not declared.

### P5. Failure-as-control (goal-directed evaluation)
**Who**: SNOBOL4 → Icon → [Tratt/Converge] → Prolog/Curry → Verse. Sixty years of continuous lineage, each generation adding structure.
**Mechanism**: every expression succeeds with value(s) or fails (produces *nothing* — not a value); conditionals branch on success; generators/choice supply alternatives.
**Buys**: zero-ceremony absence; search, filtering, and pattern-fallthrough unify; failure can't be stored or compared (nil's core sins structurally impossible).
**Frictions (documented, the richest regret record in the space)**: Icon's designers added implicit cuts at every statement end because unrestrained backtracking × side effects was "difficult for programmers to understand" (Griswold); Tratt, after building it and living with it, would keep only "generators and failure in if constructs" and drop the rest — and calls the reified fail object "fundamentally dangerous." Curry's own designers formally proposed ripping out `Success`/`=:=` ("some expressions were more equal than others"). The recurring sin across all of them: **silence** — failure vanishes without a trace.
**Prologos occupancy**: the deepest occupancy of any position — goals, `solve` bags, NAF (stratified, floundering-checked), guards, cut (clause-body-only), and *crucially* worldview speculation + nogood retraction, which is the transactionality Icon lacked and Verse had to build on STM.

### P6. Domain-shrinking (make absence unrepresentable)
**Who**: Liquid Haskell (false-precondition totality: `patError :: {v|false} -> a` forces error paths to be provably dead), Idris `Fin n`/`Vect n`, parse-don't-validate (King), Dafny/F* in industry.
**Buys**: the partiality question vanishes at the access site. Liquid Haskell's numbers (verified, Haskell'14): 11.5 KLOC verified with ~17% spec overhead; Data.Map totality was "quite straightforward" *because the invariants were already in the types*.
**Frictions (documented)**: the same paper's HsColour case — contingent data invariants were "somewhat cumbersome to specify," and the authors **fell back to a dynamic check**. Idris's arithmetic-identity proof tax (`n+k` vs `k+n`) lands on users; `natToFin` reintroduces the Option at the boundary. Dafny's bottleneck is counterexample comprehension.
**Prologos occupancy**: closed rows (field-miss already static), the Map↔schema SEAL + `validate` (parse-don't-validate as a first-class op), dyn-tail (which *is* a gradual row-refinement `{known ∧ ?}` — Lehmann/Tanter's POPL'17 construct, shipped by accident). The empirical line this position draws is the design criterion: **shrink when the invariant is structural (row set, length-measure); handle at runtime when it's a contingent fact about data (key in a dynamic dict)**. Prologos's rulings already sit on the correct side of that line.

---

## 2. VERSE, POSITIONED HONESTLY

**What `<decides>` actually is** (verified from book ch. 07/08/13 + the ICFP'23 calculus): a cardinality effect declaring "this function may yield zero values." Callers must use square brackets (`Lookup[Key]`) and may do so only inside a **failure context** — if-conditions (bind-on-success, bindings scoped to then-branch), for-filters, `first`, another `<decides>` body, or `option{e}` which reifies failure into a value. Failure contexts are **transactional**: "if a condition fails, any effects performed while evaluating the condition are automatically rolled back" — even `defer` cleanup. In the calculus, failure is empty multiplicity in a *deterministic sequence* semantics; `one{e}` takes the first value, `all{e}` reifies all of them; `if` desugars through `one{}`.

**Genuinely novel vs the lineage**:
- vs **Icon**: transactional discharge. Icon's documented regret (effects not rolled back → implicit cuts everywhere) is precisely what Verse fixes. This is Verse's real contribution: *failable-condition-with-auto-rollback is the ergonomic payoff*.
- vs **Curry**: determinism-with-order, native encapsulation (`one`/`all` as "part of the foundational fabric" vs bolted-on set functions), one equality instead of `==`/`=:=`, native higher-order.
- vs **Mercury**: `semidet` re-derived as an effect discharged by *syntactic context* rather than a per-mode declaration — plus the `[]`-call marking (Swift's `try` as a delimiter).
- **Not novel**: failure-as-zero-values (Curry), one/all (FRESH 1985, unimplemented for 40 years), choice-floating (bubbling/pull-tabbing from the Curry literature). The paper credits all of this honestly.

**Verse's own admitted costs** (verified): the sequence commitment "pretty much rules out laziness … and parallel first-come first-returned search strategies"; the skew-confluence proof "is not yet complete"; the calculus is untyped (the type system perpetually "another paper"); the effect/reference story is "preliminary" (Appendix F); `<decides>` + `<suspends>` cannot combine; `<no_rollback>` ships as a deprecated escape hatch — evidence the rollback discipline fights real code.

**The hypothesis, evaluated**: *Verse's one/all ≈ solve-one/solve; a failable expression ≈ a goal; Prologos already owns the substrate.* — **Confirmed, with three precise caveats**:

1. `all{}` ≈ `solve` is exact, and Prologos's version is *stronger on Verse's own admitted weakness*: bags (Rel T1 POL.1, derivation-counted) are the CALM-monotone, parallel-friendly point in the same space where Verse pays sequences. But `one{}` ≈ `solve-one` is **inexact**: under bags, `solve-one` is a nondeterministic pick; Verse's `one{}` is deterministic-first. Any Verse-style if-desugaring through `one{}` would import an ordering commitment the BSP substrate deliberately refuses. If Prologos wants failure-driven `if`, it needs either a semideterminism argument (condition provably yields ≤1 row — Mercury's `semidet` check) or an honest committed-choice construct.
2. Failable expression ≈ goal — yes, and Prologos already made Frank's ambient move (goal-ness from context, POL.9). But Verse's failure contexts work in *ordinary functional code* (any if-condition), while Prologos goals are command-position-only, with expression-position goal-ness explicitly deferred as a purity question. Verse's evidence is that the win lives exactly there.
3. Verse's transactional failure context is the ATMS reinvented on STM, sequential, and formally unfinished. Prologos's worldview speculation + tagged writes + nogood retraction + S(-1) stratum *is* the operational semantics Appendix F is groping for — parallel, and formalizable. This is the strongest positioning fact in the entire survey: **Verse's hardest unfinished problem is Prologos's existing substrate.**

Conclusion: the question is genuinely only the SURFACE. What Verse contributes is not semantics Prologos lacks but *ergonomic discharge forms* — bind-on-success if, `or`-chaining, for-filtering, the call-site mark — over machinery Prologos already runs.

---

## 3. THE OWNER'S NIL INSTINCT, ADJUDICATED

**The steelman (Hickey, verified verbatim)**: (1) optionality changes are *compatible* changes that Maybe turns into breaking changes, while union-nil (`T <: T?`) does not — this is technically correct and is the strongest argument in the anti-Option corpus; (2) "nothing is inherently a Maybe string" — optionality belongs to the *usage context*, not the value's type (his schema/selection split: shape carries no requiredness; each context declares its own required-set); (3) Maybe/Either "are not actually the type system's or" — not associative, not commutative. All three arguments are arguments **for `<V|Nil>` unions and contextual requiredness** — which Prologos already has (nil-unions; rows are schema; a selection would be a row-polymorphic call-site constraint). The owner's instinct, steelmanned, lands on machinery already built.

**The precise safety line, from 60 years of practice**: nil is fine when it is (a) **tracked in the type** (Kotlin/Crystal/strict-TS — nobody serious now defends untracked null; Hoare's own words target the *unchecked* hole, not absence-as-value), (b) **narrowed soundly** (every documented narrowing failure is an aliasing/mutation condition Prologos's monotone cells dissolve), and (c) **coherent where it absorbs** — Clojure's nil-punning works exactly where the absorbing algebra is total (seq/map/conditional core) and rots exactly where it's partial (`str nil` → `""` but `trim nil` → NPE) or ambiguous (absent-key vs stored-nil). Obj-C is the terminal case: total absorption, and the platform owner abandoned it after 30 years for tracked Optionals, keeping absorption only as the *opt-in, type-visible* `?.` operator.

**Where the owner is right**: Option ceremony is a real cost with a real fix that isn't nil-anarchy — the union-typed quadrant is practice-validated, Hickey-endorsed, and evolution-compatible. Prologos should feel no purist guilt about `<V|Nil>` being the honest tier.

**Where the project's own history is the counter-evidence**: the P2.b episode — a silent error class hidden for months, made loud only recently — is Prologos's own instance of the universal failure mode of untracked absence: **NPE-at-a-distance / silent flow / detonation far from origin, with no provenance**. Clojure's documented worst bug class, Icon's documented worst property (Tratt: failures vanish untraceably), Obj-C's documented verdict ("failing silently like that is the worst option") — and Prologos lived it. The two-tier ruling's loud-counted assertive tier is the exact negation of that failure mode and should be treated as settled by evidence, not just by fiat.

**Two open rulings the survey forces**: (1) **the nesting question** — `<V|Nil>` where V may itself contain Nil collapses (Kotlin) or must box (Swift nests). Generic containers over nilable elements is where union-nil genuinely loses to Option; rule it eyes-open (forbid Nil-in-V by row/kind constraint, auto-box at the one seam, or document the sentinel idiom). (2) **absent-key vs stored-nil** in open maps: keep `kv-get -> Option` (or rule that map values exclude Nil) rather than punning — this is Clojure's documented ambiguity and SQL's original sin.

---

## 4. THE CANDIDATE CORNERS, RANKED

**#1 — ABSENCE WITH A WHY (why-not provenance as a first-class value).** Who has it: database research (Chapman & Jagadish SIGMOD'09; PUG, VLDB J. 2018) proved the semantics; s(CASP) ships justification trees for `not(G)` — but as *printed diagnostic output*, not values; Whyline (Ko & Myers) proved the payoff empirically (novices 2× faster than experts; ~8× on one task) but as a tool reconstructing causality from expensive whole-execution traces. **No language returns "why this was empty" as a typed value the program can compute with** — because in every other substrate it's a costly post-hoc analysis. Prologos's ATMS produces the raw material (nogoods, retracted guard/NAF branches, assumption sets) *as a byproduct of normal execution*. The corner is cheap here and expensive everywhere else — the defining property of a real corner. Concretely: the assertive tier's counted error carries a justification; an honest variant returns `<V | Absent(why)>`; `explain-not (goal)` returns a typed bag of failure-justification rows (Prologos already reserves `explain` as an adverb). What it takes: reifying existing ATMS data into typed rows — substrate mostly exists; the work is a value-level schema for justifications.

**#2 — CONTEXT-POLYMORPHIC ABSENCE (the owner's (a), evaluated).** Has any language unified goal/loud/typed-nil under one operation with the context choosing? **No.** The near-misses: Verse gets *two* modes (failable access legal-and-failing inside a failure context; *static error* outside — not a loud runtime tier) and its third mode (`option{}`) is an explicit reification, not contextual. Effect handlers (Pretnar's verified tutorial: the same `fail`/`decide` operation under six handlers = Option-with-default, commit, backtracking, all-solutions) unify N meanings but the chooser is a *dynamically-scoped handler*, not syntactic context, and none of them has a counted-error ledger tier. Mercury's per-mode determinism is the closest static precedent (the same `append` is det or semidet depending on instantiation context) — context-polymorphism by mode, not by syntax. Frank's ambient abilities are the right *mechanism* (context grants meaning, zero annotations) but research-scale. The three-way unification — `m.field` fails the enclosing choice in goal context, counts loudly in plain context, types as `<V|Nil>` at an honest boundary — is unexpressed anywhere, and Prologos has independently ruled the enabling move (meaning-from-context, POL.9). This is the strongest *language-design* corner; #1 is the strongest *semantics* corner; they compose (the failing/loud/typed absence all carry the same why).

**#3 — CARDINALITY AS INFERRED EFFECT (Mercury's lattice, Dialyzer's temperament, on-network).** Mercury proved the full lattice with a documented partial order but made it declared and rigid; Verse ships one point of it (`semidet`) with ceremony (brackets + effect specifier); Dialyzer proved the opposite temperament scales — optimistic, zero-annotation, "never wrong for defect detection," 20 years of adoption in an annotation-hostile community. Nobody has run cardinality inference as **monotone lattice propagation** — which is structurally what it is (compositional transfer functions over goal structure, a join-semilattice of cardinality intervals). On Prologos's substrate this is a stratum, not a type system: infer can-fail on-network, surface it only at `spec` boundaries and as "this assertive access provably always fails" static warnings. Gives `<decides>` without the annotation, and unifies with QTT (multiplicities in, cardinality out — the same algebra both sides of the arrow).

**#4 — FAILURE = NOGOOD (transactional failure contexts on a TMS).** The formal unification the owner's (c) points at, resolved better than the literature resolves it: Pretnar's handler-arity story (0 resumptions = abort, 1 = commit, N = bag) hits the multi-shot continuation wall in every sequential runtime (OCaml 5 deliberately one-shot; multi-shot is what backtracking needs). Worldview fan-out **is** multi-shot resumption without continuations — all branches live at once, per the mantra. "Failure = contradiction in a scoped worldview; discharge = worldview narrowing" as a *published semantics* would land the thing Verse's Appendix F leaves preliminary. This is a paper-and-positioning corner as much as a feature.

**#5 — THREE ABSENCES (bottom vs Nil vs Conflict).** SQL's disaster was conflating unknown/inapplicable/missing in one NULL; C#'s retrofit pain is materialized-empty-then-populated; Kotlin's residual holes are init-order. All dissolve if "not yet computed" is a **meta/⊥** (never Nil), "definitely absent" is Nil, and "contradictory support" is a third thing (the Belnap `Both` every cell already structurally has). No surface language separates these because none has a bottom. Prologos gets it from the substrate; the work is deciding how much to surface (at minimum: rule that construction-in-progress and foreign-interop unknowns are metas, not Nil — closing the gingerBill default-uninitialized hole structurally).

**Honorable mentions**: defeasible defaults (schema `:default` as a retractable Reiter-style assumption — distinguishable in provenance, auto-retracted when real data arrives); Hickey's schema/selection in a typed language (row-polymorphic per-context required-sets — his spec 2 never shipped it); Verse §7's unpublished throwaway "types can be represented by partial identity functions" (unifies is-type, refinement-via-trait, schema validate, and lookup partiality into one failable-coercion concept — long-range research track, resonant with SRE).

---

## 5. STEAL / REFUSE / INVENT

### STEAL (surface over existing substrate)

- **Verse's discharge forms as sugar over solve/goals**: bind-on-success if (`if (v := m.field?) ...` binding scoped to the success branch), `or`-chaining for defaults (shorter than any getOrElse chain), for-filtering. The semantics is worldview speculation Prologos already runs; the caveat is the deferred expression-position purity question (POL.9 scoped goal-ness to command position deliberately) — this is the design conversation to have, with Verse as evidence the win lives there. Also steal the **rigid-variable insight** structurally: "equations cannot float outside one/all" is the same shape as the existing NAF stratification; any failure-driven-if design should inherit it.
- **Swift's caller-chosen conversion operators**, generalized: demote (`try?` ≈ `m.field?` → `<V|Nil>`), assert (`try!` ≈ "I know it's there", trap = the existing loud tier), and — Prologos-only — reflect (failure ↔ empty bag). Libraries never pick the tier; call sites do. Pure surface.
- **Mercury's doublet discipline as convergent evidence** for the two-tier ruling (search/lookup, uniform across a 25-year stdlib) — and its inference rule: *exported declare, local infer* — if cardinality ever goes static.
- **Koka's exn/div split as vocabulary**: name non-quiescence as a distinct thing from failure. Costs nothing now; prevents conflation later.
- **Kotlin's enumerated-residual-holes documentation pattern**: Prologos should be able to state "a runtime absence error arises ONLY from assertive access outside a discharging context."

### REFUSE (with the documented reason)

- **Verse's ordering commitment** (sequences, deterministic `one{}`): its paper admits it kills parallel search and laziness; bags are the CALM-aligned point. Do not import `one{}`-shaped desugarings without a semideterminism story.
- **A third partiality channel / a Success-like type**: Curry's designers formally recanted (`Success`/`=:=` — "some expressions were more equal than others"); Verse quietly carries three channels (failure, `?t`, uncatchable `Err`). Prologos's two tiers + bags is already the right count; hold the line.
- **Enumerated failure causes in signatures**: Hejlsberg's versioning/aggregation arguments apply verbatim to typed effect rows. The bit stays coarse; the error ledger carries the story.
- **Continuation-based effect handlers**: OCaml's one-shot restriction exists precisely because multi-shot is expensive, and multi-shot is what logic search needs. The ATMS is a multi-shot machine without continuations; building handlers-as-control-flow would be paying for what the substrate gives free.
- **Ambient absorption** (Obj-C nil-messaging, Clojure-edge punning): the 30-year verdict is in. Absorption only as a tracked operator whose result type confesses (`?.`-style, result `<V|Nil>`).
- **`Vect n`-chasing for dynamic collections**: the Idris proof tax (n+k ≠ k+n judgmentally) lands on users; the shrink/handle line (structural measure vs contingent fact) already places dynamic indexing on the honest/relational side. (If ever revisited: the e-graph substrate, not users, should close arithmetic identities.)
- **Deferring the foreign-interop nullability ruling**: Kotlin's platform types are the permanent cost of deferring exactly this. `foreign.rkt` values need an explicit boundary decision while the surface is young.

### INVENT (ranked; substrate cost flagged)

1. **Why-not provenance values** — `explain-not`, absence-carrying-justification on both tiers. Substrate: exists (nogoods, assumption sets, retraction records); work = a typed reification schema + the query surface. The single strongest differentiator found; no language has it, and only this substrate makes it cheap.
2. **Context-polymorphic absence** — one partial-access operation; goal context → fails the enclosing choice; plain context → loud counted error; honest boundary → `<V|Nil>`. Substrate: exists (worldviews = failure contexts; POL.9 = the ambient mechanism); work = the elaboration/typing story for discharge contexts + the expression-position ruling. This *is* the two-tier principle completed with its missing third tier.
3. **Cardinality inference as a network stratum** — Mercury's lattice, Dialyzer's optimism, zero annotations, surfaced at `spec` boundaries and as always-fails static warnings. Substrate: new stratum, existing machinery (monotone propagation is what the network does).
4. **The nil/bottom/conflict ruling** — mostly a design document, not code: construction-in-progress and unknown-fields are metas, never Nil; decide whether Conflict ever surfaces in a type.
5. **Defeasible schema defaults** — `:default` as a retractable assumption with provenance. Substrate: exists; wiring work. Natural follow-on to (1).
6. **The paper**: "failure contexts as ATMS worldviews" — the formal semantics Verse's Appendix F lacks, with bags where Verse has sequences and parallel narrowing where Verse has sequential rollback. Positioning: Prologos occupies the Verse corner *minus its admitted sacrifices* (ordering, laziness, unfinished metatheory), because the substrate Verse is still engineering is the substrate Prologos started from.

**One-sentence position for the owner**: the owner's dissatisfaction with Option is vindicated by the survey, but the answer isn't nil — it's that Prologos already owns all six positions' machinery and is missing only (i) the discharge *surface* that lets ordinary functional code use goal-failure the way Verse does, and (ii) the one genuinely unexpressed corner, **explained absence** — and the project's own P2.b history says whatever ships must never be silent: quiet in the value plane, never unexplained.
---

## ✏ Addendum — round 2 (owner + Claude, 2026-07-27): KNOWN-ABSENCE, graded absence, and the UCS junction

**Owner contribution**: to the three-absences taxonomy (⊥/Nil/Conflict), add
**`known-absence`** — with the record-typing TAIL as the example. And: the ATMS
why-not machinery "may be able to feed greater confidence to known-absence or
plausible-absence, for potential recovery and protection of partiality"; constraint
solving mechanisms come to mind (UCS core-thesis territory).

**The refined taxonomy — a KNOWLEDGE-STATE LATTICE per key/location** (decomplected
from representation; Nil is NOT a row in this lattice — Nil/Option/failure/panic are
VALUE-PLANE representations a TIER chooses to carry one of these states across a
boundary):

| State | Evidence character | Existing machinery |
|---|---|---|
| **⊥ / unknown** | no evidence either way | metas (D19 "the meta IS the observation") · dyn tails · presence=`'unknown` (D24 dissoc marking) |
| **plausible-absence** | absence under DEFEASIBLE assumptions — retractable | NAF ("not provable from the store NOW") · dyn-row runtime miss · a `:default`-filled slot (assumes absence of real data) — each carries an ATMS label citing its assumptions |
| **known-absence** | absence with a MONOTONE-STABLE justification | the CLOSED tail (the λ⟨⟩-inexpressible negative fact, ours natively) · presence=`'absent` — **the reserved mark with ZERO producers today (survey M4(b)); this class IS its producer semantics** · static dissoc of a known field · a completeness declaration (Rel T1 C.c's schema⟹facts-only is one!) |
| **Conflict** | Has-evidence ∧ Lacks-evidence in one worldview | contradiction → nogood → narrowing (Belnap `Both`; structurally present in every cell) |

**The UCS junction (the owner's "general mechanism")**: D11 already names
`HasField`/`Lacks`/`Concat` as constraint kinds for the ONE solver. Graded absence =
**absence facts as first-class constraints with ATMS labels**: a closed tail is a
finite Has-set plus Lacks-everything-else; a `Lacks(r,l)` over a dyn tail RESIDUATES
until evidence arrives; Has∧Lacks = the Conflict row = nogood; **the why-not value is
exactly the LABEL of the Lacks fact**. The trait solver, row solver, and absence
reasoning share residuation + labels — one mechanism, which is the UCS thesis
applied to negation.

**Narrowing is the transition system**: D24's `has-key?` hook (`'unknown`→`'present`
on positive evidence, "where courtesy arrives soundly, as narrowing") has an exact
DUAL — `'unknown`→`'absent` on negative evidence (NAF over a declared-complete store;
a failed has-key?; a closed-scan). Both monotone, both CALM-safe. Known-absence is
worldview-independent (a proof); plausible-absence is assumption-tagged (the
tagged-cell-value machinery) and auto-retracts through the ATMS when contradicted —
**which is the "recovery" half**: dependents of a retracted absence re-fire without
any user-written invalidation.

**"Protection of partiality," concretely graded**:
- assertive `m.field` against **proven Lacks** → a static error WITH ITS JUSTIFICATION
  ("known absent: row closed at <srcloc>") — the existing closed-row-miss diagnostic,
  upgraded from implicit to labeled;
- against **plausible-absence** → the loud runtime miss CARRYING the why-not label
  (the P2.b panic, explained);
- against **⊥** → residuate (today's fresh meta / D23 escape-boundary discipline);
- **defaults become defeasible assumptions** (the survey's Reiter mention, now
  load-bearing): a `:default` may fill PLAUSIBLE absence and auto-retract when real
  data arrives — but **filling KNOWN-absence is a type error** (claiming a value for
  a slot proven empty): a genuinely novel type-system behavior that falls out of the
  grading.

**Disposition**: still Stage-0. The shape is now visibly track-charter-sized and
UCS-adjacent (the one-solver junction) with CIU-T6 touchpoints (presence marks, the
tail) and Rel touchpoints (NAF, completeness declarations). Chartering is the
owner's call.
