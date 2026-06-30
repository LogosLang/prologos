# Numerics Track — Stage-3 Design (D.1)

**Status**: Stage-3 design, consolidated from the design dialogue + two grounding/research workflows (2026-06-30). Ready for implementation (phases N0–N6).
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
| **N0** | Design-phase-1 verification: bridge-soundness check + 2 bounded audits (§8) | — | ⬜ (gate for N5) |
| **N1** | Exponent lexing (`1e10`, `1.5e-3`) — exact-at-source | — | ⬜ (cheap; unblocks DEMO P1 + exponent literals) |
| **N2** | Posit/Quire display fix (wire dead decoder) + shortest-round-tripping + Rat terminating-decimal display | — | ⬜ (cheap; the "inscrutable" fix) |
| **N3** | `Float` primitive (full compute, new rank family, `f`/`f32`/`f64` literals, `numeric-join` extension, Posit↔Float explicit conversion) | N1 (exponent literals) | ⬜ (the heavy AST-pipeline build) |
| **N4** | Context-typed polymorphic literal model (Q8 D): bare exact literals → type-from-context, unconstrained → exact Rat | N2 (Rat display), N3 (`f` marker) | ⬜ |
| **N5** | Refinement substrate: `refinement` meta-domain + type↔refinement Galois bridge + arithmetic transfer + subsumption + migrate the 5 refined types | N0 (verification) | ⬜ (the tower reconception) |
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

### §4.2 The Sign domain algebra (traits — already mostly built)

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

- **Subsumption** (Q5) at the single point [`typing-core.rkt:2419-2428`]: for numeric types, `T@d1 <: T@d2` iff `T` base-compatible (the *existing untouched* primitive path) **and** `d1 ⊑ d2` (⊆). `Int@Pos <: Int` (Pos ⊑ ⊤) ✓; `Int </: Int@Pos` (⊤ ⋢ Pos) — narrowing requires a runtime check.
- **Arithmetic** (Q4) in the generic-arith rules [`typing-core.rkt:789-833`]: result type = `numeric-join(base₁,base₂) @ transfer_op(d₁,d₂)` — **two parallel computations**: base via rank (unchanged), refinement via the domain transfer. Sibling separation; refinement never enters `numeric-join` or `subtype-lattice-merge`.
- **Narrowing** (`Int → Option (Int@Pos)`): the smart-constructor, **auto-derived from γ** (the predicate `n>0` *is* `γ(Pos)`); returns the same value statically refined (Q6 erasure) or `None`.

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

New rank family alongside exact + posit. AST-pipeline footprint (per `pipeline.md`; Posit32 is the template — ~16 files, typing-core ~47 / qtt ~39 / reduction ~58 clauses): type + value + ~14 op structs/width, `Float32`/`Float64`, `±Inf`/`NaN` special values, the `f` literals. **FFI** ([`foreign.rkt:192-290`]): Float arms in both marshal directions (Racket flonum ↔ Float struct) — the legit NaN/Inf round-trip point. **`numeric-join` extension (Q11):** `exact + Float → Float` (auto-absorb, min Float? — likely Float64), `Float32 <: Float64`; **Posit + Float → no join** (explicit `From`/`TryFrom` only, mirroring Rat↔Posit Phase 3f). A Float-named type already classifies `'approximate` via `typing-propagators.rkt:790-797` (live).

## §5 NTT Model (on-network parts — N5)

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
2. **Audit A — `subtype-pair?` consumer census** for the 5 refined names: confirmed (§4.4) the only numeric-specific consumer is `base-numeric-type` (`typing-core.rkt:174,176`); everything else (capability subtyping `capability-inference.rkt:154`, the `subtype` decl closure `elaborator.rkt:3287-3316`, `flat-subtype?` fallback `subtype-predicate.rkt:142`) is **shared, must-preserve**. Re-verify no missed reader.
3. **Audit B — zero residual edges:** confirm the primitive tower (`Nat<:Int<:Rat`, posit chain) needs no registry edges post-migration (it's rank-driven + hardcoded fast-path) — else B silently becomes two-mechanism.

## §9 Phased Roadmap (detail)

- **N0** verification (§8) — a day of targeted greps + a bridge probe. Gate: all three confirmed; else re-scope N5.
- **N1** exponent lexing — extend `recognize-decimal-literal`/`recognize-number` (`parse-reader.rkt:260-303`) to accept `[eE][+-]?digit+`; route to exact (`#e`). Tests: lexer + L1/L3 (`1e10`→Int, `1.5e-3`→Rat). *Unblocks DEMO P1's JSON exponents.*
- **N2** display — wire `posit-display` (`posit-impl.rkt:363`) into `pp-expr` (`pretty-print.rkt:224,245,266,287`); add the shortest-round-tripping algorithm; add Rat terminating-decimal display; Quire exact. Tests: L1/L2/L3 display-string asserts (none exist today — Q10 gap).
- **N3** Float primitive — the ~16-file pipeline (Posit32 template); FFI marshal; `f` literals; `numeric-join` Float arms; Posit↔Float `From`/`TryFrom`. Tests: per-width pipeline (mirror `test-posit32.rkt`), FFI round-trip incl NaN/Inf, conversion. *Unblocks DEMO P1.*
- **N4** literal model — the numeric-literal meta + context unification + unconstrained→Rat default; the marker scheme; resolve the bare-integer sub-point. Tests: context-typing (`def x : Float64 := 3.14`), unconstrained→Rat + display, `~`/`f`. **Pre-0 note:** measure the polymorphic-literal elaboration cost (D's real cost) before/after.
- **N5** refinement substrate — N0 gates it; build the `refinement` meta-domain + bridge + transfer + subsumption; migrate the 5 refined types; auto-derive narrowing. Tests: `test-subtyping.rkt` parity (refined subsumption), refinement-preserving arithmetic (`Pos+Pos→Pos`, `Pos+Neg→⊤`), narrowing, erasure (refined value = base value at runtime).
- **N6** ergonomics + reconciliation — fold the audit's open items; update `LANGUAGE_VISION.org` (Float user-facing); close the 2026-02-19 roadmap into this track.

## §10 WS Impact

- New surface: `f`/`f32`/`f64` Float literals; exponent syntax; the (sliced) refinement names `Pos`/`Neg`/`Zero`/`NonZero` (as types). Preparse/reader: extend number tokenization (N1) + the `f` suffix; no new top-level form (refinements are types; the general `Type@property` form is deferred).
- Display changes are user-visible (posits now `~3.14`, refined types print `base@d` or the named alias).
- **3-level WS validation required** for each new literal/type surface (sexp / `process-string-ws` / `process-file`) — and **both pipelines** (merge + cell) per the standing two-context trap.

## §11 Test Strategy

Per-phase tests above. Cross-cutting: a Numerics regression set; the existing `test-subtyping.rkt` (44) / `test-numeric-traits.rkt` (36) / per-width posit tests must stay green (or migrate intentionally for N5). New: display-string tests (N2), Float pipeline (N3), literal-context-typing (N4), refinement subsumption + preserving-arithmetic + erasure (N5). Full suite as the regression gate per phase.

## §12 Open Questions / Deferred

- Bare-integer polymorphism (N4 sub-point — recommend yes).
- α-only vs bidirectional refinement bridge (N5).
- `numeric-join` exact+Float target width (Float64 vs preserve) (N3).
- Very-long-terminating-decimal display threshold (N2).
- **Deferred tracks:** full refinement inference (future); general `Type@property` surface + trait-as-type-producer + `property` unification (UCS track 5); Interval/user Galois-domain refinements (extension); strict division-safety mode (future).

## §13 Proportionate Methodology

| Gate | Applies? |
|---|---|
| Progress tracker near top (§2) · phased roadmap · per-phase tests | ✅ |
| NTT model | ✅ **N5 only** (§5) — the sole on-network phase |
| SRE lattice lens | ✅ (§6) — the Sign refinement lattice (= Q₃ cube) |
| On-network / Mantra audit | ✅ N5 (§7) |
| WS Impact | ✅ (§10) — new literal/type surface |
| P/R/M/S adversarial self-critique | ✅ applied live via `numerics-refinement-design` workflow (substrate + disposition) |
| Pre-0 microbench | ◐ N4 (polymorphic-literal elaboration cost), N5 (refinement-erasure runtime win); N1/N2/N3 are feature-enabling |
| Parity test skeleton | ✅ N5 (refined-subsumption parity vs the retired subtype path) |

## §14 References

- Charter [`2026-06-30_NUMERICS_TRACK_CHARTER.md`](2026-06-30_NUMERICS_TRACK_CHARTER.md); prior art [`2026-02-19_NUMERICS_TOWER_ROADMAP.md`](2026-02-19_NUMERICS_TOWER_ROADMAP.md), [`2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org`](2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org).
- Deferred-surface note [`2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md`](2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md) (UCS track 5).
- Driver [`2026-06-28_DEPENDENCY_RESOLVER_DEMO_DESIGN.md`](2026-06-28_DEPENDENCY_RESOLVER_DEMO_DESIGN.md) (DEMO P1 consumer).
- Code pivots: `typing-core.rkt` (numeric-join / base-numeric-type / subsumption), `subtype-predicate.rkt`, `propagator.rkt:4414` (cross-domain bridge), `lib/prologos/core/{lattice,abstract-domains}.prologos`, `interval-domain.rkt`, `posit-impl.rkt`, `parse-reader.rkt`, `foreign.rkt`.

---
*Stage-3 D.1, 2026-06-30. Consolidates the full Numerics design dialogue (Clusters 1–4 + foundation). Next: N0 verification → N1/N2 (cheap wins; N1 on the DEMO-P1 path) → N3 Float → N4 literals → N5 refinement substrate → N6.*
