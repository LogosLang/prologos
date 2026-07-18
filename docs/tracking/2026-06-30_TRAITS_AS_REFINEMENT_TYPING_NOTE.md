# Traits Are Refinement Typing — Design Note (toward UCS)

**Status**: Design note / generative thread (Stage 0). Future track work, **home = UCS series** ([`2026-03-28_UCS_MASTER.md`](2026-03-28_UCS_MASTER.md)); strong cross-references to **SRE** (relations / structural) and the Extended-Spec **`property`** form. NOT v1 — see §6 for what the Numerics track slices off now.
**Origin**: owner insight during the Numerics track Q7 design dialogue (2026-06-30) — "our `trait`s ARE refinement typing." Spawned from [`2026-06-30_NUMERICS_TRACK_CHARTER.md`](2026-06-30_NUMERICS_TRACK_CHARTER.md) §5 Q7.

---

## §1 The insight

A refinement type — `{x : Int | x > 0}`, i.e. `Int` narrowed by a predicate — is, structurally, a **type carrying a constraint**. Prologos already has a first-class mechanism for "a type carrying a constraint": the **`trait`**. So traits and refinement types are the same idea at different altitudes, and the refinement machinery should be *expressed through traits* rather than as a parallel system. The owner's chosen surface direction is **`Type @ named-property-or-refinement`** (e.g. `Int@pos`), where the attached thing is a named property/refinement backed by a trait-expressed algebraic domain.

## §2 The precise two-level analysis (what traits do and don't give us)

Splitting "is `trait` sufficient as a refinement substrate?" into **algebra** vs **type-system integration** is the load-bearing distinction:

- **The refinement *domain's algebra* = 100% traits, and mostly already built.** A domain `D` (Sign, Interval, …) is a bundle of trait instances: `impl Lattice D` (⊑/meet/join/⊤/⊥), `impl GaloisConnection Base D` (α/γ — and γ *is* the narrowing predicate "v ∈ γ(d)"), `impl Add D` / `impl Mul D` (the arithmetic transfer functions). **The sign-of-sum rule is literally an `Add` instance.** Traits are not merely sufficient here — they're the ideal carrier: declarative, composable (`bundle` = conjunction), user-extensible.
- **The type-system *integration* is NOT trait methods** — it's thin wiring that *consults* the trait algebra: carrying a domain element on a base type (`Int@d`), the subsumption rule (`Int@d1 <: Int@d2` iff `d1 ⊑ d2`), propagating `d` through `+`/`*` at check time, and erasure (refined value = base value).

**Why a `trait` alone can't *be* a refinement type today:** `trait C {A}` produces a **constraint** `C A` (a proposition, witnessed by a **dictionary** — a value), i.e. `trait : … → Constraint`. It is **not** a type-producer (`Type → Type`). A refinement type needs the *producer* step — turning "`Int` + a positivity predicate" into a refined type the checker carries/subsumes/erases. Traits give the predicate/algebra (the dictionary); the producer step is the thin type-system layer. **The full vision = make `trait` (or a sibling) a first-class type-producer.** That is the deep extension this note is about.

## §3 The surface direction: `Type @ named-property-or-refinement`

`Int@pos`, `Rat@nonzero`, eventually `Int@(in-range 0 9)`. The attached element is a **named property/refinement** resolved against a trait-expressed Galois domain. Named properties and refinements are the same kind of thing (predicates over a type's values / over the type), so the surface should treat them uniformly. (Lexer note: `@` collides with PVec `@[…]` literals — the surface sigil is itself an open question.)

## §4 Unification with the `property` form

The Extended-Spec **`property`** form ([`LANGUAGE_VISION.org:187`](principles/LANGUAGE_VISION.org), [`ERGONOMICS.org:306`](principles/ERGONOMICS.org)) already envisions "named, composable proposition groups — propositions attached to types — with property-membership cells and composition propagators flowing property truths through trait and bundle composition." That is *exactly* a refinement layer:
- a `property` = a predicate on a type (= a refinement domain element / a trait constraint);
- "property-membership cells + composition propagators" = the on-network refinement carrier + the propagation through composition;
- "flow through trait and bundle composition" = the conjunctive meet of refinements.

So **`property`, `trait`, and refinement collapse into one spectrum** of "predicates on types/values, witnessed and composed on the network." The full design should unify them rather than ship three mechanisms.

## §5 UCS + SRE connections

- **UCS** is the home: a refinement is a **constraint over an algebraic domain**; refinement checking/propagation is constraint solving by algebraic class (the UCS thesis). The Sign/Interval domains' widening/narrowing connects directly to [`WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS`](../research/2026-04-30_WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS.md). The `#=` operator over a refinement domain *is* refinement inference. **Full refinement inference (the deferred Numerics Q3 track) is a UCS application.**
- **SRE**: refinement subsumption is a structural relation; whether refinement is expressible as an SRE relation (sibling to subtype/equality/duality/rewrite) is an open structural question (the workflow's prior-art facet flagged it).

## §6 The v1 slice (what the Numerics track ships NOW — this note defers the rest)

The Numerics track (charter D-N5) ships, **without** committing the general surface:
- **internal carrier** `base @ domain-element` (the Q1 attribute);
- a **fixed, built-in set** of numeric refinements over the **Sign** domain — `Pos` / `Zero` / `Neg` / `NonZero` — surfaced as **named types** (migrating the existing `PosInt`/… ), trait-expressed algebra, propagate-and-check, erased representation.

**Deferred to the UCS-homed refinement track (this note):** the general user-facing `Type@named-property` surface; arbitrary user-defined refinements/properties; `property`-form unification; `trait`-as-first-class-type-producer; full refinement inference; the `@`-sigil decision; user-defined Galois domains as refinements.

## §7 Open questions for the track

1. Make `trait` a type-producer, or add a sibling `property`/`refine` producer that *reuses* trait resolution? (Decomplection: probably the latter, consuming trait/`GaloisConnection` instances.)
2. The surface sigil (`@` collides with PVec) and whether `Type@p` is one syntactic form or property-application.
3. Refinement as an SRE relation vs a UCS constraint vs both.
4. How `property` composition (membership cells + propagators) realizes the conjunctive meet on-network.
5. The bridge to full refinement inference (`#=` over refinement domains) and its decidability story (widening/narrowing).

## §8 Known consumer gap: schema `:check`/`:default` trait resolution (CIU T6 F1b.7b, 2026-07-18)

A concrete, grounded consumer of "trait resolution as a reusable service" surfaced
during CIU T6 F1b hand-testing/stress-testing. It belongs to this track because
the fix is *general trait-dict resolution run in a non-standard context* — exactly
the machinery §7 Q1 contemplates (a `property`/`refine` producer *reusing* trait
resolution). Filed here to be picked up WITH this track.

**The gap.** A schema field's `:check` predicate and `:default` value are baked
`elaborate`-ONLY (elaborator.rkt, the `expr-validate` plan bake) — no `check` /
`resolve-trait-constraints!` / `zonk` pass. So a **genuine trait method** inside a
`:check`/`:default` (`eq?` on any `Eq` type, `div` (Div), a user-defined trait
predicate) never gets its dictionary and stays a stuck application. Grounding
(audit `wf_7cdee201`, HEAD `c375789b`): the resolution machinery ALL exists
(`resolve-trait-constraints!`, `solve-meta!`, wakeup registration, no module
cycle — only `driver.rkt` requires `elaborator.rkt`); the ONLY missing step is a
local typing pass on the baked pred/default that GROUNDS the accessor's type-var
meta from the field type `ft-expr` FIRST (resolve-trait-constraints! alone is a
no-op — it gates on ground type-args), then resolves, then zonks. This is the
audit's "candidate A" (~a bounded change at the bake, with meta-state hygiene +
the network-less door-seal/library-load two-context path to handle).

**Why deferred here (not fixed in F1b.7b).** F1b.7b shipped the CHEAP, high-value
half (owner-ruled 2026-07-18): the `?`-suffixed comparison family (`le?`/`lt?`/
`ge?`/`gt?`) are NOT trait methods (monomorphic `Nat Nat -> Bool`) — normalized to
dict-free `le`/`lt`/`ge`/`gt` keywords, so those idiomatic checks now work on
Int+Nat. What remains is genuine trait-method resolution, which is this track's
domain. Two disciplines make deferral safe: (1) a clean **workaround** exists — wrap
the predicate in a `spec`'d Bool function (`spec f T -> Bool` / `defn f [x] [eq? x
…]` → `:check (f _)` resolves, because the defn goes through the full typed
pipeline); (2) F1b.7a's guard makes the un-resolved inline form **fail loud** as
`check-unevaluable "(eq? _ 7)"` (never silently pass — the Correct-by-Construction
line held).

**The `:default` sibling (same mechanism).** A `:default` calling a trait method
has the identical elaborate-only gap. It is NOT a silent-unsoundness hole (unlike
the F1b.7a `:check` bug): the def-annotation route resolves it (full pipeline);
`validate` catches the stuck value (F1b.7b now names it `default-unevaluable`
rather than a misleading `type-mismatch`); an unbound default errors at the bake.
So Correct-by-Construction is satisfied and only the RESOLUTION is deferred (to
this track, with the `:check` case) — the diagnostic already landed in 7b.

**Entry gate.** Opens with this track (a general `check + resolve + zonk` service
invocable at the schema bake). Design doc `2026-07-06_CIU_T6_F1_STRUCTURAL_RECORDS_DESIGN.md`
§13.9 (F1b.7b) is the CIU-side record; the grounding is audit `wf_7cdee201`.

## References
- [`2026-06-30_NUMERICS_TRACK_CHARTER.md`](2026-06-30_NUMERICS_TRACK_CHARTER.md) (origin; v1 slice), [`2026-03-28_UCS_MASTER.md`](2026-03-28_UCS_MASTER.md) (home), [`WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS`](../research/2026-04-30_WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS.md).
- [`LANGUAGE_VISION.org:187,398`](principles/LANGUAGE_VISION.org), [`ERGONOMICS.org:306`](principles/ERGONOMICS.org) (`property` form).
- Grounding: `numerics-refinement-design` workflow (the GaloisConnection/Lattice/Sign/Interval trait machinery; `net-add-cross-domain-propagator` bridge).
