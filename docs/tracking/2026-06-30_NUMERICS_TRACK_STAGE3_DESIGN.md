# Numerics Track — Stage-3 Design (D.1)

**Status**: **D.2** — independent P/R/M/S + completeness critique complete + owner-adjudicated (2026-06-30). **Read §15 (Critique Adjudication) — it SUPERSEDES the D.1 body where noted** (notably: N5 is function-level, not on-network; the Sign algebra is net-new; the census/tests are broadened; bare-integer polymorphism deferred). Then ready for implementation (N0–N6). **Session 2 (2026-06-30): post-implementation review → §16** — P0 NaN/Inf reducer crash + P1 warning-cell leak FIXED; §15 folded into the body; F2-isolation invariant locked (§4.3a); N3e mini-design written (§9a). **Session 3 (2026-06-30): N0 GATE RUN → §8a (PASS_WITH_FIXES, N5 not re-scoped); N4 mini-design → §9b (full Q8-D, `expr-num-lit`+type-meta, forks resolved); N5 mini-design → §9c (@d carrier = NOMINAL Sign-backed — REVISES §4.3a's positional model; positional `base@d` → UCS track).**
**Date**: 2026-06-30
**Series/Track**: Numerics track (resume + revise the [2026-02-19 Numerics Tower](2026-02-19_NUMERICS_TOWER_ROADMAP.md)). Charter: [`2026-06-30_NUMERICS_TRACK_CHARTER.md`](2026-06-30_NUMERICS_TRACK_CHARTER.md). Spawned from DEMO Track 1 (the dependency-resolver demo's JSON numbers).
**Grounding basis**: `numerics-grounding` + `numerics-refinement-design` + `decimal-literal-default-research` workflows (all HEAD-pinned / cited); the substrate code claims are R-lens-verified; pivot at `typing-core.rkt:166-178,186-207,2419-2428`, `subtype-predicate.rkt:130-142,352`.
**Methodology**: applies the Stage-3 gates proportionately (§13) — NTT model for the on-network parts (§5), SRE lattice lens (§6), WS Impact (§10); the P/R/M/S lenses were applied live via the `numerics-refinement-design` adversarial workflow.

---

## §1 Purpose & Scope

Add **`Float`** (full IEEE compute primitive, interop numeric), reconceive the **numeric tower as refinement-via-trait** (compositionally safe, replacing the user-refinement-layer subtyping), fix **Posit display**, clean a coherent **literal/display scheme**, and fix **exponent lexing** — all so the language's numerics are realistic for outside-world data and principled internally.

**In scope (N0–N6):** Float primitive; the refinement substrate (a `refinement` meta-domain valued in a Galois abstract domain, Sign built-in); refinement-preserving arithmetic; representation-erased refined values; the context-typed polymorphic literal model; round-tripping display; exponent lexing; ergonomics cleanup; vision/roadmap reconciliation.

**Deferred to named tracks (governance):**
- **Full refinement inference** (liquid-types-style, global fixpoint) → a future track, gated on richer abstract-interpretation + constraint-solving for decidability.
- **The general `Type@named-property` user surface + `trait`-as-type-producer + `property` unification** → **UCS Master track 5** ([note](2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md); cross-ref SRE). v1 ships a *fixed built-in set* of refinements.
- **Interval / user-defined Galois domains as refinements** → extension after Sign lands (the carrier is designed for it).

## §2 Progress Tracker

| Phase | Deliverable | Depends on | Status |
|---|---|---|---|
| **N0** | Design-phase-1 verification (§8) → **RUN 2026-06-30: PASS_WITH_FIXES** (§8a); 2 audits pass, N5 not re-scoped, bridge-gate dropped (§15) | — | ✅ (gate cleared; 3 fixes → §9c) |
| **N1** | Exponent lexing (`1e10`→Int, `1.5e-3`→Rat) — exact-at-source, **WS-only** | — | ✅ (dedicated `recognize-exp-literal`; sexp→N4; `tests/test-exp-literal.rkt`) |
| **N2** | Posit/Quire display fix (wire dead decoder) + shortest-round-tripping + Rat terminating-decimal display | — | ✅ (`08081c4d`; Q10: posit `~d` / float `<d>f`/`<d>f32` / Rat terminating-decimal; round-trip property tests; suite 8462) |
| **N3** | `Float` primitive — new rank family (sub-phases N3a–g; see §9) | N1 ✅ | 🔄 **N3a** ✅ + **N3b** ✅ (`db816e65`) + **N3c** literals ✅ (`d90a8245`) + **N3d** numeric-tower (numeric-join Float family + Float32<:Float64 + generic arith) ✅ (`41f8c385`; 4 files; `tests/test-float-tower.rkt`; suite 8437); **N3e-core** (Rat/Int→Float via Path B — the DEMO-P1 unblock) ✅ (`6cc47faf`; `tests/test-float-conversions.rkt`; suite 8442); **N3e-rest** (Float→Rat/Int TryFrom→None, Float64→Float32 narrow) ✅ (`803c75df`; 4 unary prim nodes; suite 8448); **N3f** (Float FFI marshal, flonum↔Float, NaN/Inf round-trip) ✅ (`3ab6beb8`; suite 8452); Posit↔Float/N3g pending |
| **N4** | Context-typed polymorphic literal (Q8 D) — **mini-design §9b** (`expr-num-lit`+type-meta+default; decimals/fractions/non-integral-exps polymorphic; integrals concrete) | N2 ✅, N3 ✅ | ⬜ (designed §9b) |
| **N5** | Refinement substrate (function-level) — **mini-design §9c** (@d carrier = NOMINAL Sign-backed; 8-elem Sign + transfer + decomposed subsumption; migrate 5 refined types) | N0 ✅ (gate cleared) | 🔄 N5a ✅ (`d73335d7`), **N5b ✅** (`b76045a7`); N5c–g pending |
| **N6** | Ergonomics cleanup (fold [2026-02-22 audit](2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org)) + vision/roadmap reconciliation (update `LANGUAGE_VISION.org`; close 2026-02-19 roadmap) | N3–N5 | ⬜ |

**DEMO P1 unblocks after N1 + N3.** N1/N2/N3 are largely independent (parallelizable). The order back to the demo is N1 → N3.

## §3 Locked decisions (from the dialogue)

| # | Decision |
|---|---|
| D-N1 | `Float` = **full compute primitive** (revises FFI-only vision + `LANGUAGE_VISION.org:152`) |
| D-N2 | Numeric tower → **refinement-via-trait** (not subtyping) |
| D-N5 | Substrate = **Galois/abstract-domain × disposition B** (keep primitive widening; trait-refine only the user layer), commit-now |
| Q1 | Refinement = an **attribute** on a type, concrete-or-meta (mirrors `type`) |
| Q2 | Domain = **Sign** built-in; carrier is "an element of *some* `GaloisConnection` domain" (extensible → Interval/user) |
| Q3 | **Local propagate-and-check** (full inference deferred) |
| Q4 | **8-element Sign lattice** internally; `Pos`/`Zero`/`Neg`/`NonZero` named; **preserve-or-⊤** transfer parallel to `numeric-join` |
| Q5 | Subsumption `T@d1 <: T@d2` iff base-compatible ∧ `d1 ⊑ d2`; refinement lattice is **F2-clean** (monotone finite lattice) |
| Q6 | Refined values **representation-identical to base, refinement erased** (coercion-to-base = identity) |
| Q7 | Surface **sliced**: v1 = fixed built-in refinements over an internal `base@d` carrier; general surface → UCS track 5 |
| Q8 | Bare literal = **context-typed (option D)**, unconstrained → exact Rat + terminating-decimal display |
| Q9 | Exponent literals exact-at-source under D |
| Q10 | **Shortest-round-tripping** display, printed as a re-readable marked literal (`~3.14`/`3.14f`); Rat → decimal if terminating |
| Q11 | Float = new **rank family**: exact auto-absorbs; **Posit↔Float explicit conversion only**; `3.14f` = Float64 |

## §4 The Design

### §4.1 The refinement model

A numeric type is `base @ d` where `base` ∈ {Nat, Int, Rat, PositN, FloatN} and `d` is a **refinement element** of a Galois abstract domain (Sign in v1). `d = ⊤` means "no refinement" (= plain base). The attribute is **erased at runtime** (Q6) — `Int@pos` *is* an `Int` value the checker knows is positive. The primitive within-family tower (`Nat<:Int<:Rat`, posit/float chains) is **untouched** (disposition B) — it stays rank-driven (`numeric-join`) + the hardcoded fast-path edges; only the *user-refinement layer* moves to `@d`.

### §4.2 The Sign domain algebra

> **⚠ §15 D1 correction (supersedes "already mostly built"):** the *real* `Sign` at HEAD is a **5-element flat** lattice — there is **NO** `impl Add/Mul/Neg Sign` and **NO** `GaloisConnection Int Sign` (only `Interval↔Sign`). The 8-element powerset lattice + the transfer instances + the `Int↔Sign` connection described below are **NET-NEW**. Decision: **replace** the 5-element `Sign` with the 8-element powerset (one canonical `Sign`); migrate the existing `GaloisConnection Interval Sign` consumers + tests intentionally; re-run the §6 SRE lens against the real delta.

The refinement domain's algebra is trait-expressed (`impl Lattice Sign`, `impl GaloisConnection Int Sign`, `impl Add Sign`/`impl Mul Sign`) — see [`core/lattice.prologos`](../../racket/prologos/lib/prologos/core/lattice.prologos), [`core/abstract-domains.prologos`](../../racket/prologos/lib/prologos/core/abstract-domains.prologos), [`interval-domain.rkt`](../../racket/prologos/interval-domain.rkt). v1 extends `Sign` to the **8-element powerset-of-signs lattice** (the standard abstract sign domain):

```
elements = ℘({neg, zero, pos})          ⊑ = ⊆        ⊥ = ∅      ⊤ = {neg,zero,pos}
named:  Pos={pos}  Zero={zero}  Neg={neg}  NonZero={neg,pos}
        (internal also: NonNeg={zero,pos}  NonPos={neg,zero}; named later)
```

**Galois connection** Int↔Sign: `α(n) = {sign(n)}`; `γ(S) = {n | sign(n) ∈ S}`. γ *is* the narrowing predicate (`n ∈ γ(Pos) ⟺ n>0`).

**Transfer functions** (lift the scalar sign rules pointwise over sets; sound; total; result = ⊤ when it can't narrow). Per Q4, **never reject — over-approximate to ⊤**:

| op | rule | preserves |
|---|---|---|
| `*` | sign-of-product, pointwise | total + precise |
| `negate` | flip each sign | total + precise |
| `abs` | → NonNeg (Zero→Zero) | total + precise |
| `+` | same-sign-set preserved; mixed → join (e.g. Pos+Neg=⊤, NonNeg+NonNeg=NonNeg) | partial |
| `-` | `add ∘ negate` | partial |
| `/` | sign-of-quotient; refined only if divisor ⊑ NonZero (else ⊤) | precise w/ NonZero divisor |

`Pos + Pos = Pos`; `Pos + Neg = ⊤`. Division-safety (`NonZero` divisor) is **opt-in** — supported when present, never mandated (non-breaking).

### §4.3 Subsumption + arithmetic wiring (the thin type-system layer)

- **Subsumption** (Q5) at the numeric subsumption point [`typing-core.rkt:2476-2485`] (the conversion-fallback `subtype?` call — the D.1 `:2419-2428` coordinate is **stale**): for numeric types, `T@d1 <: T@d2` iff `T` base-compatible (the *existing untouched* primitive path) **and** `d1 ⊑ d2` (⊆). `Int@Pos <: Int` (Pos ⊑ ⊤) ✓; `Int </: Int@Pos` (⊤ ⋢ Pos) — narrowing requires a runtime check.
- **Arithmetic** (Q4) in the generic-arith rules [`typing-core.rkt:789-833`]: result type = `numeric-join(base₁,base₂) @ transfer_op(d₁,d₂)` — **two parallel computations**: base via rank (unchanged), refinement via the domain transfer. Sibling separation; refinement never enters `numeric-join` or `subtype-lattice-merge`. **(§15 D12: define the `+` transfer pointwise `α∘op#∘(γ×γ)`, NOT join-of-operands — §4.2's `+` row is D.1-stale.)**
- **Narrowing** (`Int → Option (Int@Pos)`): the smart-constructor, **auto-derived from γ** (the predicate `n>0` *is* `γ(Pos)`); returns the same value statically refined (Q6 erasure) or `None`.

**§4.3a — F2-isolation representation invariant (LOCKED 2026-06-30; option (ii), owner-confirmed).** §15-D6's "refined types provably never reach `subtype-lattice-merge`" holds ONLY if `@d`'s representation keeps it out of the SRE structural-subtype walk. The walk recurses compound components RAW (`subtype-predicate.rkt:167,186`) into `subtype-lattice-merge` (`:354`, the F2 hazard) — so an embedded `@d` node inside `Option (Int@Pos)` (the narrowing type above) would leak. **Decision: `@d` is carried OUT-OF-BAND** — never a sub-node, field, or component of any type value that can reach `sre-constructor-tag` / `structural-subtype-ground?` / `subtype-lattice-merge`. This mirrors the QTT **mult-meta** precedent (a separate sibling domain, never ctor-registered ⇒ structurally unreachable from the type merge) and mult-on-`Pi` (a fenced field with variance `=`). **Invariant:** every type flowing into `subtype?` is the bare base, with `@d` stripped; subsumption *decomposes* — `T@d1 <: T@d2` ⟺ `subtype?(base,base) ∧ d1⊑d2`, computed separately; transfer runs *parallel* to `numeric-join`, never inside it. **One genuinely-new wiring site:** the subsumption point (`:2476-2485`) has no strip today (`numeric-join` already strips for the old registry-named refinements at `:185` — the arithmetic-side precedent). *N5 consideration:* a bare `Int` atom has no field to hang `@d` on, so `@d` is keyed to the inference-time type-*position* (threaded through `infer`/`check`); `Option (Int@Pos)` is the stress test (the recursed arg stays bare `Int`; the `@d` slot travels with the position). The general `Type@refinement` surface + trait-as-type-producer + full (liquid-typing) inference → a future **UCS Series track** (owner, 2026-06-30; note `2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md`); N5 ships ONLY the fixed built-in Sign slice numerics needs.

### §4.4 Representation + migration of the 5 refined types

Refined values are **representation-identical to base** (Q6): no wrapper, no boxing; coercion `Int@Pos → Int` = identity. Migrate `data PosInt = pos-int Int` + `subtype PosInt Int` + hand-written `to-pos-int` (×2 book/standalone copies) → `Pos`/`Zero`/`Neg`/`NonZero` refinements with auto-derived narrowing. Net deletion of hand-written refinement plumbing. (Disposition-B audit: the only numeric-specific consumer of the refined-name edges is `base-numeric-type` — §8.)

### §4.5 Literals & display

**Literal model (Q8 D — context-typed):** a bare exact literal (`3`, `3.14`, `3/7`, `1e10`) elaborates to its **exact value carried by a numeric-literal meta** that unifies with the expected type from context (→ `Float`/`Posit`/`Int`/…); an **unconstrained** literal defaults to **exact Rat** (Int when integral). Marked literals are concrete: `~3.14` = Posit32, `3.14f`/`3.14f32`/`3.14f64` = Float (default Float64). The marker scheme:

```
bare (context-typed, exact-at-source):  3 · 3.14 · 3/7 · 1e10   (unconstrained → Int/Rat)
~  = Posit (approximate, tapered):       ~3.14   (default Posit32; width via ascription)
f  = Float (approximate, IEEE):          3.14f / 3.14f32 / 3.14f64
N  = Nat                                 42N
```

*Open sub-point:* whether D applies to bare **integer** literals too (currently bare `3` = Int concrete) — recommend yes, for uniformity (a `3` in a Posit context = Posit 3), but it's a migration consideration (flagged for N4).

**Footgun-safety:** the Rat default applies *only* to unconstrained literals (REPL-ish), which are never in a typed hot loop (those are context-typed to Posit/Float) — so the Raku-style rational blowup cannot bite. This is why D dominates a fixed-Rat default.

**Display (Q10), invariant "display = a re-readable literal of the same value":**
- exact `Rat` → **decimal if it terminates** (denom = 2^a·5^b → `3.14`, `0.3`), else **fraction** (`1/3`); very-long terminating → fraction fallback.
- `Posit`/`Float` → **shortest round-tripping decimal**, marked: `~3.14` / `3.14f` (the decoded value's shortest decimal that re-encodes to the same bits — Ryū/Grisu-style, adapted).
- `Quire` → exact rational. `NaR`/NaN/±Inf → named.
- Invariant: **unmarked = exact, `~` = Posit, `f` = Float.**

### §4.6 Float primitive (N3)

New rank family alongside exact + posit. AST-pipeline footprint (per `pipeline.md`; Posit32 is the template — ~16 files, typing-core ~47 / qtt ~39 / reduction ~58 clauses): type + value + **10 op structs/width (20 total)**, `Float32`/`Float64`, `±Inf`/`NaN` (ordinary flonums — no special struct support needed), the `f` literals. **FFI** ([`foreign.rkt:192-290`]): Float arms in both marshal directions (Racket flonum ↔ Float struct) — the legit NaN/Inf round-trip point. **`numeric-join` extension (Q11):** `exact + Float → Float` (auto-absorb, **PRESERVING the Float operand's width** — landed N3d, NOT "min Float64"), `Float32 <: Float64`; **Posit + Float → no join** (explicit `From`/`TryFrom` only, mirroring Rat↔Posit Phase 3f). A Float-named type already classifies `'approximate` via `typing-propagators.rkt:790-797` (live).

## §5 NTT Model (on-network parts — N5) — ⚠ SUPERSEDED by §15

> **§15: N5 is FUNCTION-LEVEL, not on-network.** Numeric typing (`numeric-join`, generic-arith, subsumption) is plain imperative functions — there is **no** refinement meta-domain, **no** Galois bridge, **no** on-network N5. The NTT model below is the *rejected* on-network framing, kept for the record. On-network retirement of N5's (function-level) scaffolding = a future **PPN** track (`2026-06-30_NUMERICS_ON_NETWORK_PPN_NOTE.md`).

Only N5 touches the propagator network. The refinement substrate as NTT:

```
;; the refinement meta-domain (sibling to type/mult/level/session)
cell refinement-cell : Lattice Sign        ;; ⊑ = ⊆, merge = set-union (join-semilattice), bot = ∅

;; type↔refinement Galois bridge (reuse net-add-cross-domain-propagator, propagator.rkt:4414)
propagator type→refinement  :reads type-cell  :writes refinement-cell   fire = α    ;; type ↦ initial refinement
propagator refinement→type  :reads refinement-cell :writes type-cell    fire = γ-base ;; refinement ↦ base type
   ;; α/γ monotone (required); Sign is a clean finite lattice ⇒ trivially monotone (no F2 hazard)

;; arithmetic transfer (parallel to numeric-join, in the generic-arith typing rules)
propagator refine-add :reads d1-cell d2-cell :writes dr-cell   fire = (transfer-+ d1 d2)
   ;; (and refine-mul / refine-neg / refine-abs / refine-div)
```

**Correspondence (NTT ↔ Racket):** refinement-cell ↔ a `refinement` meta-domain in `metavar-store.rkt` (per the per-domain-universe-migration checklist in `pipeline.md`); the bridge ↔ a `net-add-cross-domain-propagator` install at driver init (mirroring `current-structural-mult-bridge`, `driver.rkt:3239`); the transfer propagators ↔ hooks in `typing-core.rkt:789-833` writing the result refinement. **Stratification:** all S0 (monotone) — refinement is a join-semilattice; no new stratum. The bridge's α-only vs bidirectional: γ may be α-only if the base is determined independently (decide in N5).

## §6 SRE Lattice Lens (the Sign refinement domain)

1. **VALUE or STRUCTURAL?** VALUE (a single evolving refinement element per numeric meta).
2. **Algebraic properties:** join-semilattice (powerset under ⊆) — Boolean lattice (℘ of 3 atoms = Q₃ cube!), distributive, complemented. CALM-safe (monotone join). 
3. **Bridges:** type↔refinement is a **Galois connection** (α preserves joins) — the one bridge; composes with nothing else (sibling domain, *not* merged into the type lattice — this is what de-risks it).
4. **Composition:** the only bridge; arithmetic transfer is endo on the refinement lattice.
5. **Primary/derived:** the refinement cell is PRIMARY for the user layer; `base-numeric-type`'s erasure is derived from it (replacing the subtype-registry lookup).
6. **Hasse diagram:** the 8-element lattice IS the Boolean cube **Q₃** (subsets of {neg,zero,pos}) — so Hasse primitives (bitmask subcube, ⊆-as-bitmask-AND) apply directly; refinement ⊑ is a 3-bit subset test. Elegant + efficient.

## §7 On-Network / Mantra Audit

- **All-at-once / parallel:** the bridge + transfer propagators fire on cell change; refinement of N operands computed in the same round as their base types (parallel to `numeric-join`). No `for/fold`.
- **Information flow / on-network:** refinement is a cell, bridged via α/γ; subsumption + arithmetic read/write cells. ✓
- **Structurally emergent:** subsumption + arithmetic results fall out of the lattice ⊑/transfer, not control flow. ✓
- N1/N2/N3/N4 are lexer/display/AST-pipeline/elaboration work — *not* new propagators (NTT N/A there). Only N5 is on-network.

## §8 Design-phase-1 Verification (run first in N0; gates N5)

1. **Bridge-soundness** (the commit-now fold-in): confirm a `type↔refinement` bridge composes with the type lattice + `subtype-lattice-merge` (`subtype-predicate.rkt:352`, has the F2 hazard). *Expectation:* largely de-risked — refinement is a sibling domain (not merged into the type lattice), and the `type↔mult` bridge (`driver.rkt:3239`) is the existence proof. Verify the mult bridge's interaction pattern + that Sign's α/γ are monotone (they are — finite lattice).
2. **Audit A — `subtype-pair?` consumer census** for the 5 refined names. ⚠ **RETRACTED by §8a (N0 run):** the "only numeric-specific consumer is `base-numeric-type`" claim is REFUTED (≥3 more — all already named in D3/§15). `base-numeric-type` is at **`typing-core.rkt:187-196`** (stale here: `:174,176`), sole caller `numeric-join` `:205`, refined-only via `expr-fvar`. Shared/must-preserve (confirmed): `capability-inference.rkt:154`, `elaborator.rkt:3287-3316`, `subtype-predicate.rkt:142`. See **§8a** for the bounded set + verdict.
3. **Audit B — zero residual edges:** confirm the primitive tower (`Nat<:Int<:Rat`, posit chain) needs no registry edges post-migration (it's rank-driven + hardcoded fast-path) — else B silently becomes two-mechanism.

## §8a N0 Gate Result — RUN 2026-06-30 (session 3): **PASS_WITH_FIXES**

Ran via the `numerics-n0-gate-and-n4n5-grounding` workflow (5 HEAD-pinned facets + adversarial completeness critic; HEAD `ac1811a1`). **Verdict: PASS_WITH_FIXES — N5 does NOT re-scope.** Per §15 the bridge-soundness gate (§8.1) is MOOT (N5 function-level, no bridge); N0 = the 2 broadened audits.

- **Audit A (census)** — PASSES once the doc is corrected. §8/line-166 headline is REFUTED as written, but D3 already broadens to the correct set: **{ `base-numeric-type` (`typing-core.rkt:187-196`, sole caller `numeric-join` :205, refined-only via `expr-fvar`) · type-family classifier (`typing-propagators.rkt:778-800`) · interval-domain `PosInt` hardcode (`:80,88`; FQN `prologos::data::nat::PosInt` = DEAD code) · abstract-domains circular require (`:9-10`) }**. Bounded at the decision layer — numeric `subtype-pair?` calls only at `typing-core.rkt:192,194`. Must-preserve (shared, confirmed generic): `reduction.rkt:909-942`, `macros.rkt:6065`, `capability-inference.rkt:154`, `elaborator.rkt:3287-3316`, `subtype-predicate.rkt:142`.
- **Audit B (zero residual edges)** — PASSES. Primitive tower decides via hardcoded `flat-subtype?` (`subtype-predicate.rkt:131-141`) BEFORE the registry fallback (`:142-144`); `numeric-join` rank-driven. **Honest caveat (doc states):** the registry still CONTAINS 10 duplicate primitive edges (`macros.rkt:6106-6114`), load-bearing as transitive-closure seed for refined types (`elaborator.rkt:3357`) — NOT deletable. "Zero residual edges" = true at the decision layer, false at the store layer.

**Three required N5 fixes** (folded into §9c sequencing): (1) retract line 166 [done]; (2) fix the type-family classifier (`typing-propagators.rkt:793-795`) — exact-name match or Sign-attribute derivation, NOT substring `string-contains?` (real fragility = substring over arbitrary names, e.g. `Grated`⊃`"Rat"`; the "NonZero⊃Zero bug" framing is mischaracterized — `NonZero` doesn't exist yet); (3) **EVACUATE the refined `Eq`/`Ord` instances (`abstract-domains.prologos:174-267` + `book/lattices.prologos:560-592`) BEFORE deleting the wrappers** — `namespace.rkt:826` `:refer-all` makes wrapper-deletion-first a WHOLE-SUITE compile break (highest-severity sequencing constraint; the census under-stated it, the completeness critic caught it).

**Coordinate corrections (capture-gap tax — even the facets drifted 1–2 lines):** `base-numeric-type` `:174,176`→**`:187-196`**; subsumption point `:2476-2485`/`:2419-2428`→**`:2500`** (in the `[(_ t-whnf)]` fallback `:2491-2500`); generic-arith `:789-833`→**`:817-849`**; interval-domain `:81/88/90`→**`:80,88`**; N4 chokepoint `parser.rkt:645`→ parse PRESERVES at **`:652-659`**, discard at **`elaborator.rkt:1897`**; **THREE** Sign copies (add `book/refined-numerics.prologos:265`).

## §9 Phased Roadmap (detail)

- **N0** verification (§8) — a day of targeted greps + a bridge probe. Gate: all three confirmed; else re-scope N5.
- **N1** exponent lexing — ✅ **DONE (WS-only)**. **Capture-gap correction** (grounding-audit, per the §15 meta-rule "re-ground every cheap/localized claim against grep"): the D.1 "localized to `recognize-decimal-literal`/`recognize-number` (260-303)" framing UNDER-COUNTED — a naive lexer edit yields Posit32, because (a) the parser's `$decimal-literal`→`surf-approx-literal` chokepoint (`parser.rkt:645-652`) discards the exact value for ANY dotted lexeme, and (b) the `number` value path lacked `#e` (→ inexact→Posit32 fallback at `parser.rkt:489`). **Implemented approach (cleaner than the 6-site enumeration the critic found):** a NEW dedicated `recognize-exp-literal` (priority 97, classified `number`) matching `[-]?digit+(.digit+)?[eE][+-]?digit+` — fires ONLY when an exponent is present (so plain numbers/decimals/`-> -0>` arrows fall through untouched), converts via `#e` to a **plain exact datum** → existing exact dispatcher (`parser.rkt:480-485`) → `1e10`→Int, `1.5e-3`→Rat, `-1.5e-3`→Rat. Bare `3.14`→Posit32 + the parser chokepoint UNCHANGED (that's N4). The two `number` value sites (`parse-reader.rkt:1591`, `:1772`) gain `#e` (idempotent for plain int/rat). Tests: `tests/test-exp-literal.rkt` (21 — token / WS round-trip / WS-string eval / L3 `process-file` + arrow non-regression). **Scope: WS-only** — the sexp reader delegates numbers to Racket (which collapses `1e10`/`3.14` to inexact), so distinguishing exponent→exact from decimal→Posit32 needs a *new* custom sexp number reader; deferred to N4 per D7 (divergence asserted in the test, not silent). *Unblocks DEMO P1's JSON exponents.*
- **N2** display — wire `posit-display` (`posit-impl.rkt:363`) into `pp-expr` (`pretty-print.rkt:224,245,266,287`); add the shortest-round-tripping algorithm; add Rat terminating-decimal display; Quire exact. Tests: L1/L2/L3 display-string asserts (none exist today — Q10 gap).
- **N3** Float primitive — 🔄 in progress. **Grounding-audit (HEAD `90d3d94c`)**: Float is native IEEE → `float-impl` delegates to Racket flonums (<100 lines vs posit-impl's actual **525**); the heavy cost is the AST pipeline (17 ops × full surf/parser/elab/expr/typing/reduction chain) **×2 widths** + **conversions** (`From`/`TryFrom` in `conversions.prologos`, each backed by a ~5-file prim-op; Q11's explicit Posit↔Float increases it). Design clause-counts under-counted ~30% (capture-gap). Clean fits: **Q11 no-Posit↔Float-join = the ABSENCE of a `numeric-join` arm** (→ type error); `Float32<:Float64` = +1 subtype edge. **Owner decisions**: *Float-complete-first* ordering; *exact+Float PRESERVES the Float operand's width* (Int+Float32→Float32, NOT the posit clamp-to-≥P32); *bare `3.14` STAYS Posit32* (additive; N4 reconciles). **Sub-phases**: **N3a** type+value core ✅ (12 files: syntax/substitution/zonk/reduction/pretty-print/pnet-serialize/typing-core/qtt/typing-propagators/surface-syntax/parser/elaborator; `test-float-core.rkt`) → **N3b** arithmetic ops (native-flonum delegation; NaN/Inf + `NaN≠NaN` eq; `float-impl.rkt`) ✅ (`db816e65`: 20 op AST nodes mirroring posit ×2 widths across ~13 files; per-width surface names `f32+`/`f64+`; `flsingle` single-rounding for f32; `tests/test-float-ops.rkt`; suite 8427) → **N3c** `f`/`f32`/`f64` literals ✅ (`d90a8245`: dedicated `recognize-float-literal` priority 98 → `$float-literal` value+width datum → `surf-float-lit` → flonum at elaborate, f32 via `flsingle`; mirrors the `$approx-literal` path NOT N1's number-path since `string->number "3.14f"`=#f; bare `3.14` stays Posit32; full L3 compute unblocked; `tests/test-float-literal.rkt`; suite 8431) → **N3d** numeric-tower ✅ (`41f8c385`: `numeric-join` Float rank family — exact+Float PRESERVES width, Float32+Float64 widen, Posit↔Float=#f→type-error; `Float32<:Float64` edge + `try-coerce-to-float`; generic `+ - * / negate abs`+compare over floats via BOTH join machineries (typing-core `numeric-join` + reduction `type-tag-join`/literal-trio) + ~22 same-type iota arms; `tests/test-float-tower.rkt`; suite 8437. Surfaced pre-existing warning-cell-not-reset leak) → **N3e** conversions + prim-ops (**Rat→Float = DEMO-P1-critical**) → **N3f** FFI flonum↔Float marshal (NaN/Inf round-trip) → **N3g** tests (mirror `test-posit32`) + cleanup. *Unblocks DEMO P1 after Rat→Float.*
- **N4** literal model — the numeric-literal meta + context unification + unconstrained→Rat default; the marker scheme; resolve the bare-integer sub-point. Tests: context-typing (`def x : Float64 := 3.14`), unconstrained→Rat + display, `~`/`f`. **Pre-0 note:** measure the polymorphic-literal elaboration cost (D's real cost) before/after.
- **N5** refinement substrate — N0 gates it; build the `refinement` meta-domain + bridge + transfer + subsumption; migrate the 5 refined types; auto-derive narrowing. Tests: `test-subtyping.rkt` parity (refined subsumption), refinement-preserving arithmetic (`Pos+Pos→Pos`, `Pos+Neg→⊤`), narrowing, erasure (refined value = base value at runtime).
- **N6** ergonomics + reconciliation — fold the audit's open items; update `LANGUAGE_VISION.org` (Float user-facing); close the 2026-02-19 roadmap into this track.

### §9a — N3e Mini-Design (conversions + prim-ops; the DEMO-P1 unblock)

Grounded via the Numerics-review N3e footprint agent (HEAD `94323129`). **Split N3e into N3e-core (DEMO-P1 unblock) and N3e-rest (deferrable).**

**Two conversion paths; N3e-core uses Path B (nearly free):**
- **Path A** — a dedicated per-target prim-op (the Posit `p32-from-rat` template): ONE conversion = a full AST node ≈ **12 files / ~23 sites** (the charter's "~5-file" is a ~2.4× undercount). Reserve for the lossy/guarded conversions.
- **Path B** — the EXISTING generic-dispatch nodes `expr-generic-from-rat` / `expr-generic-from-int` (surface `from-rational`/`from-integer`; full pipeline already wired) dispatch on the target TYPE. Adding a Float target = **+Float to `from-rat-target-type?`/`from-int-target-type?` (`typing-core.rkt:129,135`) + ~4 reduction arms (`reduction.rkt:2196`)** — no new AST node. The coercion math already exists (`rational->literal` f32/f64 cases, `:1119`).

**N3e-core (DEMO-P1-critical; ~2 files / ~6 sites + ~8 `conversions.prologos` instances):**

| Direction | From/TryFrom | via |
|---|---|---|
| **Rat→Float64/32** ★ | From (total; overflow→±Inf benign; f32 via `flsingle`) | Path B |
| **Int→Float64/32** | From (total; lossy ≥2⁵³ — silent, like all float math) | Path B |
| Float32→Float64 | From (widen, total) | **already done** (`try-coerce-to-float`; `Float32<:Float64` edge) |

**N3e-rest (deferrable to N3g / post-DEMO-P1):**

| Direction | From/TryFrom | NaN/Inf | via |
|---|---|---|---|
| Float64→Float32 | From (narrow, lossy; `flsingle`) | benign | new prim-op |
| **Float→Rat** | **TryFrom → `None` on NaN/±Inf** | **LANDMINE** | new prim-op + guard |
| Float→Int | TryFrom (truncate) → `None` on NaN/±Inf | LANDMINE | new prim-op + guard |
| Posit↔Float (Q11) | TryFrom both (Rat pivot) | inherits Float→Rat guard | **DEFER** |

**Float→Rat landmine (SAME root as the P0 `reduction.rkt` fix):** `inexact->exact` throws on NaN/±Inf. **Resolution: `TryFrom → Option Rat`, `None` when `(or (nan? v) (infinite? v))`, else `some [inexact->exact v]`** — the honest answer (NaN/±Inf have no exact rational rep), matching the `conversions.prologos` `TryFrom` convention and the `coerce-literal` precedent (`reduction.rkt:1138`, the P0 fix). Add `nan?`/`infinite?` guards. Do NOT route through a Quire/error path.

**DEMO-P1 note (review):** the demo's synthetic dataset has **zero JSON numbers** (all strings), so N3e-core is needed for JSON-parser *completeness* (a complete parser must handle `JFloat` decimals), not for the current acceptance line — add a numeric field when P1 lands to exercise the path at L3. Precision: Rat→Float64 = round-to-nearest-even (`exact->inexact`); big-Rat→Float overflow → ±Inf (benign).

### §9b — N4 Mini-Design (full Q8-D; forks resolved 2026-06-30 session 3)

Owner chose the **full polymorphic literal** (over the lighter Rat-default+coercion). Realization = **`expr-num-lit` + the EXISTING type-meta domain + a numeric-literal defaulting constraint** — NOT a new meta domain (avoids the Per-Domain-Universe-Migration checklist). Grounded (HEAD `ac1811a1`): `elaborate` is context-free (`elaborator.rkt:853`); `check` has ZERO literal-resolves-from-expected-type case today (`typing-core.rkt:2175/2179/2191`; `from-integer` is explicit-arg infer-mode, ruled out); the exact value survives parse (`surf-approx-literal` carries `157/50`) and is discarded at `elaborator.rkt:1897` (NOT `parser.rkt:645`).

**Polymorphic set** (carry exact value + resolve type from context; unconstrained → Int if integral, else Rat): bare **decimal** `3.14`, bare **fraction** `3/7`, **non-integral exponent** `1.5e-3`. **Concrete (unchanged):** bare integer `3` (D8), **INTEGRAL exponent** `1e10`→Int (**D8-consistent — refines Q9**: integrals absorb via `numeric-join`, never trapped, so only non-integrals need polymorphism), markers `~`/`f`/`N`.

**Pipeline:** (1) parse → `surf-num-lit(exact-val, integral?, loc)` at 4 routing sites — WS `parser.rkt:652-659` + `parse-reader.rkt` decimal/non-integral-exp recognizers; sexp `parser.rkt:494-495` (inexact) + `:489-490` (fraction). Bare-int `:485-486` + integral-exp path UNCHANGED; markers untouched (priority ladder already disjoint). *Sexp precision:* sexp `3.14`=flonum-precision vs WS `#e`-exact `157/50` — documented asymmetry (sexp = internal IR). (2) elaborate (context-free) → `expr-num-lit(exact-val, integral?, ?α)`, ?α = a type meta tagged numeric-literal-origin. (3) infer→?α; check vs expected `T` → solve `?α:=T` + validate representability (Posit/Float ok; Int integral; Nat integral+nonneg; non-numeric→error). (4) zonk-final `default-metas` (`zonk.rkt:962-997`): unsolved ?α → Int (integral) / Rat. (5) collapse: ?α known → `expr-rat`/`int`/`nat`/`posit32`(encode)/`float64`(`exact->inexact`); transient node (like `expr-meta`).

**Cost:** `expr-num-lit` = New AST Node (`pipeline.md` files 1–8) — transient (post-resolution concrete). Pretty-print ties to N2 (display exact value, marked per resolved type). **Tests:** context-typing (`def x : Float64 := 3.14`→Float64, `: Int := 3.14`→error), unconstrained→Rat/Int + display, marker preservation, sexp/WS precision, N1 exp reconciliation (only NON-integral exps re-route).

### §9c — N5 Mini-Design (function-level; @d carrier = NOMINAL Sign-backed; 2026-06-30 session 3)

**Carrier decision — REVISES §4.3a.** N5 realizes refinement **NOMINALLY**, not positionally. Refined types stay **atomic fvars** (`PosInt`/`NegInt`/`Zero`/`PosRat`/`NegRat` + new `NonZeroInt`/`NonZeroRat`); the `data` wrappers are DELETED (Q6 erasure); subsumption + arithmetic are re-backed by a **name→Sign side-table** (the 8-element powerset used INTERNALLY for the transfer + a `(base, Sign)→name` reverse map). Because refined types recurse as ATOMS via `flat-subtype?`, the §4.3a F2 hazard is **structurally sidestepped** — no `@d` compound ever reaches `subtype-predicate.rkt:167/186/354`. The positional/unified `base@d` attribute (general `Type@refinement`, `Option (Int@Pos)` nesting) → deferred to the **UCS track** (matches N5's fixed-slice scope). `base-numeric-type:187` (registry-strip) is the precedent the Sign-backing replaces. *(§4.3a's out-of-band positional model stands as the general-refinement design; N5 ships the nominal slice.)*

- **Sign algebra** (net-new, D1): 8-element powerset (Q₃ cube) across **3 copies** (`data/sign.prologos:20`, `book/lattices.prologos` impls, `book/refined-numerics.prologos:265`); `impl Lattice/HasTop Sign` (powerset) + NEW `impl Add/Mul/Neg/Abs Sign` (transfer, pointwise `α∘op#∘(γ×γ)`, D12) + NEW `GaloisConnection Int Sign`; migrate the `GaloisConnection Interval Sign` consumers + tests intentionally (`test-sign-galois` `α([0,10])`→NonNeg).
- **Subsumption** (`typing-core.rkt:2500`, decomposed): `subtype? R1 R2` for refined fvars → `subtype?(base(R1),base(R2)) ∧ Sign(R1)⊑Sign(R2)` (⊆), consulting name→Sign (replaces the subtype-registry lookups). `PosInt<:Int` ✓; `PosInt<:NonZeroInt` (`{pos}⊑{pos,neg}`) ✓.
- **Arithmetic** (`typing-core.rkt:817-849`, parallel to `numeric-join/warn!`): result = `numeric-join(base1,base2)` named by `(joined-base, transfer_op(Sign1,Sign2))` via the reverse map; ⊤-sign → bare base (no named type). Never rejects (D-widen). `PosInt+PosInt→PosInt`; `PosInt+NegInt→Int`.
- **Narrowing** (`Int → Option PosInt`): smart-ctor auto-derived from γ (`n∈γ(Pos)⟺n>0`); returns the same value refined (erased) or `None`.
- **Sequencing** (N0 fixes, in order): **✅ N5a (`d73335d7`)** evacuate the refined `Eq`/`Ord` instances → `prologos::data::refined-instances` (non-prelude), abstract-domains refined-free (§8a fix 3) → **✅ N5b (`b76045a7`)** 5-elem flat `Sign` → 8-elem powerset (Q₃ cube; join/leq via the 3-atom test) across 3 copies + `Lattice`/`HasTop`/`GaloisConnection Interval Sign` migration + test asserts → **N5c** transfer algebra (`Add`/`Mul`/`Neg`/`Abs Sign` + `GaloisConnection Int Sign` + name→Sign side-table + `(base,Sign)→name` reverse map) → **N5d** decomposed subsumption (`:2500`) + arith transfer (`:817-849`) → **N5e** migrate the 5 types (delete wrappers, re-back Sign) + auto-narrowing → **N5f** fix the classifier (§8a fix 2) → retract line 166 [done §8a].
- **Tests:** the 62-case refined regression set (D9); `PosInt+PosInt→PosInt` / `PosInt+NegInt→Int`; narrowing; erasure (refined value = base value at runtime); Sign-test migration to the powerset.

## §10 WS Impact

- New surface: `f`/`f32`/`f64` Float literals; exponent syntax; the (sliced) refinement names `Pos`/`Neg`/`Zero`/`NonZero` (as types). Preparse/reader: extend number tokenization (N1) + the `f` suffix; no new top-level form (refinements are types; the general `Type@property` form is deferred).
- Display changes are user-visible (posits now `~3.14`, refined types print `base@d` or the named alias).
- **3-level WS validation required** for each new literal/type surface (sexp / `process-string-ws` / `process-file`) — and **both pipelines** (merge + cell) per the standing two-context trap.

## §11 Test Strategy

Per-phase tests above. Cross-cutting: a Numerics regression set; the existing `test-subtyping.rkt` (44) / `test-numeric-traits.rkt` (36) / per-width posit tests must stay green (or migrate intentionally for N5). New: display-string tests (N2), Float pipeline (N3), literal-context-typing (N4), refinement subsumption + preserving-arithmetic + erasure (N5). Full suite as the regression gate per phase.

## §12 Open Questions / Deferred

- Bare-integer polymorphism → **DEFERRED out of v1** (§15 D8; `3`=Int; only decimals/exponents/fractions get context-typed D).
- `numeric-join` exact+Float target width → **RESOLVED: preserve the Float operand width** (landed N3d; §4.6). §4.6/Q11 "Float64?" text is D.1-stale.
- α-only vs bidirectional refinement bridge → **MOOT** (§15: N5 is function-level, no bridge).
- Very-long-terminating-decimal display threshold (N2).
- **Warning-cell re-home** (from the Numerics review; per-command reset landed `80aca978`): re-home the coercion/deprecation/capability warning cells from the persistent-registry net onto the per-command elab-network so `reset-warning-cells!` can be deleted (correct-by-construction). Crosses the elaboration-vs-module-load two-context boundary — its own scoped follow-up.
- **Deferred tracks:** full refinement inference / general `Type@refinement` surface + trait-as-type-producer + `property` unification + user Galois-domain refinements → **UCS Series track** (owner-confirmed 2026-06-30; note `2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md`); Interval refinements (extension); strict division-safety mode (future).

## §13 Proportionate Methodology

| Gate | Applies? |
|---|---|
| Progress tracker near top (§2) · phased roadmap · per-phase tests | ✅ |
| NTT model | ➖ **N/A** (§15: N5 is function-level, not on-network — §5 retired) |
| SRE lattice lens | ✅ (§6) — the Sign refinement lattice (= Q₃ cube) |
| On-network / Mantra audit | ➖ N/A (§15: N5 function-level) |
| WS Impact | ✅ (§10) — new literal/type surface |
| P/R/M/S adversarial self-critique | ✅ applied live via `numerics-refinement-design` workflow (substrate + disposition) |
| Pre-0 microbench | ◐ N4 (polymorphic-literal elaboration cost), N5 (refinement-erasure runtime win); N1/N2/N3 are feature-enabling |
| Parity test skeleton | ✅ N5 (refined-subsumption parity vs the retired subtype path) |

## §14 References

- Charter [`2026-06-30_NUMERICS_TRACK_CHARTER.md`](2026-06-30_NUMERICS_TRACK_CHARTER.md); prior art [`2026-02-19_NUMERICS_TOWER_ROADMAP.md`](2026-02-19_NUMERICS_TOWER_ROADMAP.md), [`2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org`](2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org).
- Deferred-surface note [`2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md`](2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md) (UCS track 5).
- Driver [`2026-06-28_DEPENDENCY_RESOLVER_DEMO_DESIGN.md`](2026-06-28_DEPENDENCY_RESOLVER_DEMO_DESIGN.md) (DEMO P1 consumer).
- Code pivots: `typing-core.rkt` (numeric-join / base-numeric-type / subsumption), `subtype-predicate.rkt`, `propagator.rkt:4414` (cross-domain bridge), `lib/prologos/core/{lattice,abstract-domains}.prologos`, `interval-domain.rkt`, `posit-impl.rkt`, `parse-reader.rkt`, `foreign.rkt`.

## §15 Critique Adjudication (D.1 → D.2) — SUPERSEDES the D.1 body where noted

Independent P/R/M/S + completeness critique (`numerics-stage3-critique`, 2026-06-30, HEAD `6f843f58`) → owner co-adjudication. Cheap spine (N1 lexing, N3 Float footprint — 47/39/58 clause counts confirmed) verified sound; risk was concentrated in N5/N4. **Accepted changes below override the D.1 body.**

- **N5 is FUNCTION-LEVEL, not on-network** *(supersedes §5 NTT, §7, §13's on-network-✅ for N5).* Numeric typing — `numeric-join`, generic-arith, subsumption — is plain imperative functions (`typing-core.rkt:186, 789-833, 2419-2428`), not propagators; the meta-domain + Galois-bridge framing solved a non-problem (and the cited mult-bridge "proof" was α-only / γ-dead). **Refinement = an erased inference-time *attribute* carried function-level**: subsumption **decomposes** (strip `@d`; check `d1⊑d2` separately; run `subtype?` on the *stripped* base ⇒ refined types **provably never reach `subtype-lattice-merge`** — the F2-isolation invariant, D6); transfer is a function parallel to `numeric-join`; narrowing is the smart-constructor. **No meta-domain, no bridge, no universe-migration, no N0 bridge-gate.** **This is SCAFFOLDING** (anything not fully on-network is) — retirement = a future **PPN** track that brings numeric typing *and* refinement on-network together: note [`2026-06-30_NUMERICS_ON_NETWORK_PPN_NOTE.md`](2026-06-30_NUMERICS_ON_NETWORK_PPN_NOTE.md).
- **§4.2/§6 Sign was OVERSTATED** *(D1, all 5 lenses, verified).* The real `Sign` is a **5-element flat** lattice (`neg⊔pos=⊤`); there is **no `Add/Mul/Neg Sign`** and **no `GaloisConnection Int Sign`** (only `Interval↔Sign`). The 8-element powerset lattice + transfer instances + the `Int↔Sign` connection are **NET-NEW**. **Decision (D1): REPLACE the 5-element `Sign` with the 8-element powerset** (one canonical `Sign`) — and migrate the existing `GaloisConnection Interval Sign` consumers + tests **intentionally** (`test-sign-galois` `α([0,10])`=⊤→`NonNeg`, abstract-interpretation tests). Re-run the SRE lens (§6) against the real delta.
- **§8 census broadened** *(D3, 4 lenses).* Audit ALL consumers of the 5 refined **names** (not just `subtype-pair?` edges): `typing-propagators.rkt:790` (**fix the `NonZero`⊃`Zero` classifier bug**), `interval-domain.rkt:81/88`, `macros.rkt:6065`, `reduction.rkt:909-942`; and **break the circular dependency** (`abstract-domains` *requires* `refined-int` = the wrappers being deleted).
- **N4 is a PARSE-TIME change** *(D7)* (bare `3.14`→Posit32 at `parser.rkt:645`), not elaboration-only; the sexp-vs-WS decimal defaults already diverge — reconcile; fix the test inventory (`test-numeric-traits.rkt (36)` does not exist — it's `-01`/`-02` @18 each).
- **D8 — bare-integer polymorphism DEFERRED out of v1.** Keep `3` = Int (concrete); only **decimals/exponents/fractions** get the context-typed D model. **Justification (principled, not inconsistent):** integers **already absorb** into Posit *and* Float via `numeric-join` (exact→approximate is automatic), so they're never *trapped*; decimals **are** trapped in Posit (Posit↔Float is non-automatic, Q11), so only decimals need D. The residual gap (a bare integer as a *standalone* non-Int value, e.g. `def x : Posit32 := 3`) → reserve a **targeted subsumption-level auto-conversion** (Int-literal → expected approximate via the existing `From` instance) as a gated sub-phase — *not* full literal-polymorphism over the ~1070-token / 44-file integer surface.
- **N2 split** *(D10)*: **N2a** wire the dead `posit-display` decoder (the genuine cheap win, ships) / **N2b** shortest-round-tripping algorithm + Rat terminating-decimal display (real work).
- **Tests** *(D9)*: add the **62-case refined regression set** (`test-refined-subtyping` 18 / `test-refined-int` 26 / `test-refined-rat` 18) + the Sign-test migration + **per-phase test-count deltas** to §11.
- **Minors → fold into the N5 mini-design**: D11 (`numeric-join` becomes a *partial* LUB once Float joins — document + Posit-vs-Float reach-for guidance; the 10 callers already handle `#f`→error), D12 (define `+` transfer **pointwise** `α∘op#∘(γ×γ)`, not join-of-operands), D13 (N0 fallback per failure mode), D14 (state the "context-typing resolves **base only**" invariant), D15 (set-level α; per-refinement narrowing predicate; ⊥/⊤ conventions; all **11** arith arms incl. Bool-returning comparisons).
- **REJECTED (push-back, grounded)**: "⊤-widening is a red flag" — no, it's sound over-approximation (⊤ = "no refinement"); the CALM-Boolean-irrelevance + α-as-scalar notes (cosmetic); Float-as-2nd-approximate-family scope creep (owner-locked, D-N1; only the join-degradation D11 + vision-reconciliation are live).
- **Meta-correction (4 lenses)**: re-ground every "reuse / already-built / cheap / only-consumer" claim against grep before N5 — the *capture-gap* failure mode (it recurred across D1/D3/D9).

**Net phase impact**: order unchanged (N0–N6); **N0 drops the bridge-gate** (keeps the 2 audits, broadened per D3); **N5 is much smaller** (function-level, no meta-domain/bridge); **N2→N2a/N2b**. DEMO P1 still unblocks after N1+N3.

## §16 Post-Implementation Review Fixes (2026-06-30, session 2)

An independent P/R/M/S + completeness review of D.2 + the committed N1/N3a–N3d (34 findings; blocking/major adversarially verified at HEAD `94323129`). Outcome:

- **P0 — fixed (`c6226555`).** Cross-family generic arithmetic crashed the reducer on NaN/±Inf (`literal->rational` → `inexact->exact` in `reduce-generic-binary`'s coercion branch); `[+ 3 [/ 1.0f64 0.0f64]]` threw instead of `+inf.0`. Fixed via NaN/Inf-safe `coerce-literal`/`literal->flonum`; regression test in `test-float-tower.rkt`.
- **P1 — fixed (`80aca978`).** The coercion-warning cell was mis-homed on the grows-forever persistent-registry net → leaked across commands/tests (a locked rule lost L2 coverage). Fixed via per-command `reset-warning-cells!` + reconciling the imperative `numeric-join/warn!` to warn on exact↔approximate (Posit OR Float), matching the on-network detector. Re-home to the elab-net = tracked follow-up (§12). Full suite green (8439).
- **P2 — this doc.** Folded §15's corrections into the body: §4.2 (`Sign` is 5-element flat; 8-element net-new), §4.3 (subsumption coordinate `:2476-2485`; §15-D12 transfer), §4.6 (10 ops/width; preserve-width; NaN/Inf ordinary flonums), §5/§13 (N5 function-level, not on-network).
- **P3 → §4.3a (LOCKED).** The F2-isolation representation invariant — `@d` carried out-of-band (option (ii); the mult-meta precedent), owner-confirmed; general `Type@refinement` → future UCS track.
- **P4 → §9a.** The N3e mini-design (Path B for the DEMO-P1-critical Rat/Int→Float; Float→Rat = TryFrom→None; N3e-core / N3e-rest split).

**N3e-core LANDED (`6cc47faf`, session 2):** Rat/Int→Float via Path B exactly per §9a — `from-{rat,int}-target-type?` accept Float, `generic-from-{rat,int}` Float arms, `FromInt`/`FromRat` Float instances (bundle participation, 0-error elaboration). `from-rational Float64 r` works L1+L2; the **DEMO-P1 JSON `Rat→JFloat` path is unblocked**. `test-float-conversions.rkt`; suite 8442.

**N3e-rest LANDED (`803c75df`, session 2):** the reverse Float conversions — Float→Rat/Int (`TryFrom→None` on NaN/±Inf, guarded by `float-finite?`) + Float64→Float32 narrow. 4 new unary prim nodes (`float-finite?`, `float-to-rat`, `float-to-int`, `float-to-float32`) mirroring the `p8-to-rat` pipeline; `float-to-rat/int` guard with `#:when (rational? v)` so NaN/±Inf get stuck (never the P0-class `inexact->exact` crash — regression-tested). `conversions.prologos` TryFrom Float instances. Suite 8448. **Posit↔Float (Q11) remains deferred.** Implemented in a worktree (mechanical `p8-to-rat` mirroring), diff applied + gated main-session.

**N3f LANDED (`3ab6beb8`, session 2):** Float FFI marshal — `foreign.rkt`'s `marshal-prologos->racket` / `marshal-racket->prologos` gain Float32/64 arms (`float32/64->flonum` extract, reject width-mismatch; `flonum->float32/64` wrap a Racket real, `flsingle` for f32). **NaN/±Inf marshal cleanly** (ordinary flonums — the legit FFI round-trip point, no exact-rational detour). `test-foreign-marshal-ext.rkt`; suite 8452.

**N2 LANDED (`08081c4d`, session 2):** Q10 round-tripping display. `pp-expr` prints re-readable marked literals: posit `~<shortest-decimal>` (was raw bits — the inscrutable fix), Float64 `<d>f` / Float32 `<d>f32` (shortest single-representable), Rat exact terminating-decimal (else fraction), NaR/non-finite named. `posit-impl.rkt`: `shortest-decimal` = fewest sig-digits whose formatted+re-parsed+re-encoded value equals the target (the re-encode check IS the correctness guarantee). Round-trip property tests (`test-numeric-display.rkt`, incl. all 256 posit8); ~24 format assertions updated; suite 8462. *Process note: the worktree agent was provisioned at a STALE base (pre-N3e-rest/N3f); recovered via 3-way merge + main-session reconciliation of the N3e-rest assertions (`1/2`→`0.5`, `2.5`→`2.5f32`).* Deferred: Quire has no `~`-reader-literal so its display is unchanged; terminating-Rat display is display-only (bare `0.5` re-parses as Posit32 pre-N4).

Verified SOUND by the review (unchanged): pipeline exhaustiveness for N3a–N3d; width-preservation consistent across both join machineries; Posit↔Float type-error clean; f32 single-rounding; D8 bare-int deferral.

---
*Stage-3 **D.2**, 2026-06-30. D.1 dialogue (Clusters 1–4 + foundation) + the §15 critique adjudication. Next: N0 (2 broadened audits, no bridge-gate) → N1 exponent-lex + N2a Posit-display (cheap wins; N1 on the DEMO-P1 path) → N3 Float → N4 literals → N5 function-level refinement → N6. On-network retirement of N5's scaffolding = the PPN note.*
