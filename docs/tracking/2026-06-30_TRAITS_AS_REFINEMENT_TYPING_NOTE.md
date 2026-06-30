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

## References
- [`2026-06-30_NUMERICS_TRACK_CHARTER.md`](2026-06-30_NUMERICS_TRACK_CHARTER.md) (origin; v1 slice), [`2026-03-28_UCS_MASTER.md`](2026-03-28_UCS_MASTER.md) (home), [`WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS`](../research/2026-04-30_WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS.md).
- [`LANGUAGE_VISION.org:187,398`](principles/LANGUAGE_VISION.org), [`ERGONOMICS.org:306`](principles/ERGONOMICS.org) (`property` form).
- Grounding: `numerics-refinement-design` workflow (the GaloisConnection/Lattice/Sign/Interval trait machinery; `net-add-cross-domain-propagator` bridge).
