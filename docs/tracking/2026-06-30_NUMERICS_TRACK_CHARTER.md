# Numerics Track — Charter (resume + revise the Numerics Tower)

**Status**: Charter / Stage-1 framing (2026-06-30). Spawned from **DEMO Track 1** (the dependency-resolver demo's need for resilient, realistic JSON numbers — owner: "do further language design"). A dedicated track, RPF-style governance (the demo drives it; the track owns + deploys the fixes).
**Owns**: a `Float` primitive (full compute), the numeric-tower reconception (refinement-via-`trait`), the Posit display fix, numerics ergonomics, and exponent lexing.
**Resumes + revises**: [`2026-02-19_NUMERICS_TOWER_ROADMAP.md`](2026-02-19_NUMERICS_TOWER_ROADMAP.md) — Phases 1–3f ✅ (posits, Int/Rat, traits, within-family subtyping, cross-family conversions); **Phase 4 (Float) ⬜**. This charter revises *two completed decisions* (Float scope, tower model), so it supersedes parts of the roadmap rather than merely continuing it.
**Reconciles**: [`2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org`](2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org) (6 problems / 8 gaps / 4 decisions), `2026-02-22_NUMERIC_COERCION.md`, `2026-02-27_1400_REFINED_NUMERIC_SUBTYPING.md`, `2026-03-11_GENERIC_NUMERICS_AUDIT.md`, [`LANGUAGE_VISION.org:148-152`](principles/LANGUAGE_VISION.org).
**Grounded by**: the `numerics-grounding` workflow (5 HEAD-pinned facets + completeness critic + design-options synthesis, run `wf_101bbb50-419`, base HEAD `f44133e9`), all code claims R-lens-verified.

---

## §1 Why now

1. **DEMO P1 (JSON parser) blocks on Float** (owner decision 2026-06-30). JSON decimals must be real IEEE floats, not `Rat`. The grounding showed `Rat` is precision-exact (`0.1`=`1/10`), so the JSON motivation is **identity + outside-world fidelity**, not precision — but the owner wants real `Float` for outside-world data regardless.
2. **Float is a desired feature, planned since 2026-02-19** (Phase 4) — but as *FFI-only*. The owner revises it to a **full compute primitive**, user-facing alongside Posit.
3. **The numeric tower should be reviewed generally**: reconceive as **refinement typing via `trait`** (`trait : Type -> Type` adding constraints) = compositionally safe, instead of subtyping. Lesson: *subtyping ≅ logical-implication, which is fragile under arbitrary composition* — the same lesson behind "no trait hierarchies, use `bundle`."
4. **Posit display is inscrutable**, and **numerics ergonomics** need cleanup (an audit already exists).

## §2 Grounded current state (HEAD `f44133e9`)

- **Tower = 9 hardcoded subtype edges**: `Nat<:Int<:Rat` + `Posit8<:Posit16<:Posit32<:Posit64` ([`subtype-predicate.rkt:130-138`](../../racket/prologos/subtype-predicate.rkt)), re-registered at [`macros.rkt:6106-6115`](../../racket/prologos/macros.rkt). Cross-family is **not** subtyping but `numeric-join` LUB (posit dominates exact, min Posit32) at [`typing-core.rkt:186-207`](../../racket/prologos/typing-core.rkt).
- **`subtype?`** ([`subtype-predicate.rkt:113`](../../racket/prologos/subtype-predicate.rkt)) is enforced at **exactly one** subsumption point — the check-mode conversion fallback [`typing-core.rkt:2419-2428`](../../racket/prologos/typing-core.rkt) — and is also on-network as `subtype-lattice-merge` ([`subtype-predicate.rkt:352`](../../racket/prologos/subtype-predicate.rkt)). **This point is load-bearing for ALL subtyping (compound/structural too), not just numerics.**
- **Refinement types** (PosInt/NegInt/Zero `<:` Int; PosRat/NegRat `<:` Rat) are **library data-wrappers + `subtype` decls + runtime-checked smart constructors returning `Option`** ([`data/refined-int.prologos`](../../racket/prologos/lib/prologos/data/refined-int.prologos)). Refinement is **lossy through arithmetic** — `base-numeric-type` ([`typing-core.rkt:166-178`](../../racket/prologos/typing-core.rkt)) erases to base before any op. (refined-int/rat exist in **two parallel copies** — book + standalone.)
- **Arithmetic = 6 single-method traits** (Add/Sub/Mul/Div/Neg/Abs) + Eq/Ord + From/TryFrom/Into; composed via **`bundle`** (Num, Fractional). **But generic `+ - * /` do NOT dispatch through the trait dicts** — they take the keyword→`numeric-join`→primitive path ([`typing-core.rkt:789-833`](../../racket/prologos/typing-core.rkt)), disjoint from the dict path. (Numerics ergonomics audit Decision 1 — generic trait-dispatched operators — is only partly realized.)
- **Posit = default approximate.** Bare `3.14` → **Posit32** ([`elaborator.rkt:1822-1823`](../../racket/prologos/elaborator.rkt); per ergonomics-audit Decision 4 — *the roadmap's "3.14 is Rat" is stale*). **No Float/Real/Complex/BigInt type exists.**
- **Posit display is the dead decoder**: `posit-display` exists ([`posit-impl.rkt:363-369`](../../racket/prologos/posit-impl.rkt)) but `pp-expr` never calls it — Posits print as raw bits `[positN <int>]` ([`pretty-print.rkt:224,245,266,287`](../../racket/prologos/pretty-print.rkt)). Fix = wire the decoder (~1 require + 4 lines); also auto-fixes `NaR`.
- **Exponent notation `1e10` does not tokenize** ([`parse-reader.rkt:260-303`](../../racket/prologos/parse-reader.rkt) accepts only `digit+`, `digit+N`, `digit+/digit+`, `digit+.digit+`). Racket's `#e1e10`→`10000000000` works, so admitting the syntax gives exact conversion for free. Needed for Float literals AND JSON.

## §3 Decisions locked (owner, 2026-06-30)

| # | Decision | Revises |
|---|---|---|
| **D-N1** | `Float` = **full compute primitive** (arithmetic, literals, its own tower position) — user-facing alongside Posit | roadmap Phase 4 "FFI-only"; `LANGUAGE_VISION.org:152` (must update) |
| **D-N2** | Numeric tower → **refinement-via-`trait`** (compositionally safe), not subtyping | completed Phases 3e/3f (subtyping tower) |
| **D-N3** | DEMO P1 (JSON) **blocks on Float**; JSON decimals → `JFloat Float` | DEMO doc D1/§4.3 (was `JNum Rat`) |
| **D-N4** | A **dedicated Numerics track** (this charter), RPF-style governance | DEMO §11 "filed against owning series" |

## §4 Scope + provisional phases (Stage-3 cycle will refine)

| Phase | Work | Notes |
|---|---|---|
| **N0** | Stage-1/2: re-read the prior roadmap + audits + `base-numeric-type` region; pin the verified-vs-inferred ledger | grounding workflow done; the synthesis flagged a full read of `typing-core.rkt:166-178` as the design pivot |
| **N1** | Exponent lexing (`1e10`, `1.5e-3`) | low-risk; Racket `#e` converts; unblocks Float literals + JSON; **decide literal type** (Int/Rat/context) |
| **N2** | Posit display fix (wire `posit-display` into `pp-expr`) + a Level-1/2/3 display test (none exists today) | ship-now; **fidelity fork**: naive `exact->inexact` (`3.14`→`3.1400000005960464`) vs shortest-round-tripping decimal; extend to Quire? |
| **N3** | **`Float` primitive** (full compute) — ~16-file AST pipeline (Posit32 is the template: typing-core ~47, qtt ~39, reduction ~58 clauses), `foreign.rkt` marshalling (the legit NaN/Inf round-trip point), **new literal form** (`3.14` is taken), Float32/64, conversions, trait instances | the heavy build; reuses the roadmap's Phase-4 spec as the mechanical plan |
| **N4** | **Tower reconception** — refinement-via-`trait` | the re-architecture; high-risk (see §6); substrate fork (§5) |
| **N5** | Ergonomics cleanup — fold in the 2026-02-22 audit (generic operators, posit identities, type-join, etc.), reconciled with what's since landed | audit is the backlog |
| **N6** | Vision + roadmap reconciliation: update `LANGUAGE_VISION.org` (Float user-facing) + close the 2026-02-19 roadmap into this track | governance |

DEMO P1 unblocks after **N1 + N3** (exponent lexing + a usable Float with a literal form). N4/N5 can follow without blocking the demo.

## §5 Open design questions (for the Stage-3 cycle — NOT decided here)

1. **Tower disposition under refinement-via-trait**: retire numeric subtyping *entirely* (all 9 edges → traits), keep *posit* subtyping but trait-refine the exact family, or *layer* trait-refinement on top of subtyping? (`numeric-join` is the highest-risk consumer either way.)
2. **Refinement substrate** (3 candidates the codebase already ships): (i) extend `bundle` to carry base+predicate (closest to the framing; bundles compose *traits* today, not *type-refinements*); (ii) reuse the **Galois/abstract-domain** machinery ([`lattice.prologos`](../../racket/prologos/lib/prologos/core/lattice.prologos) + Sign/Parity/Interval domains model refinement as *lattice elements* — but it's analysis-wired, not elaboration-wired); (iii) net-new **predicate/liquid** refinement (most powerful; no machinery today; QTT has only m0/m1/mw, no predicate hooks).
3. **Refinement-preserving arithmetic** — do we want it? Today `PosInt+PosInt→Int` (base erasure). True refinement requires replacing `base-numeric-type` erasure AND unifying the two `+` dispatch paths. Or accept lossy (refinement = a constructor/checking concern)?
4. **Float literal syntax** — `3.14`/`~3.14` are Posit; `(the Float64 3.14)` does NOT re-width (verified: no check-mode literal re-encode). A Float literal needs a new form (`3.14f`? annotation-driven elaboration? a distinct sigil?).
5. **Exponent literal type** — when `1e10` is admitted, is it Int, Rat, or context-dependent?
6. **Posit display fidelity** — naive vs shortest-round-tripping; Quire too.
7. **Float depth vs vision** — full-compute (locked D-N1) means `LANGUAGE_VISION.org` must be rewritten; how do Float and Posit coexist as two approximate-ish families (subtype? join? user guidance on which to reach for)?

## §6 Risks (named explicitly)

- **`numeric-join` depends on the subtype tower** ([`typing-core.rkt:186-207`](../../racket/prologos/typing-core.rkt)) — retiring `Nat<:Int<:Rat` forces every generic-arith result type to be recomputed. Highest-risk consumer.
- **The single subsumption point** ([`typing-core.rkt:2419-2428`](../../racket/prologos/typing-core.rkt)) carries ALL subtyping (compound/structural via SRE flows through the same `subtype?`). Retiring numeric edges must not break structural subtyping.
- **The `subtype` surface decl** is user-facing for *all* user subtypes — cannot be removed wholesale.
- **Re-architecting completed work** (Phases 3e/3f, ~92 tests) — regression surface is large; the tower reconception conflicts with the existing tower unless it's retired or reframed.
- **No prior art for numerics-as-traits** — genuinely novel; the substrate choice (§5.2) has order-of-magnitude cost differences.

## §7 References

- Prior numerics design: [`2026-02-19_NUMERICS_TOWER_ROADMAP.md`](2026-02-19_NUMERICS_TOWER_ROADMAP.md), [`2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org`](2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org), `2026-02-22_NUMERIC_COERCION.md`, `2026-02-27_1400_REFINED_NUMERIC_SUBTYPING.md`, `2026-03-11_GENERIC_NUMERICS_AUDIT.md`.
- Lesson grounding: [`DESIGN_PRINCIPLES.org`](principles/DESIGN_PRINCIPLES.org) (no trait hierarchies / bundle), [`DEVELOPMENT_LESSONS.org`](principles/DEVELOPMENT_LESSONS.org) (SRE subtype-merge fragility), [`FIRST_CLASS_TRAITS_DESIGN.md`](2026-03-09_FIRST_CLASS_TRAITS_STAGE3_DESIGN.md).
- Driver: [`2026-06-28_DEPENDENCY_RESOLVER_DEMO_DESIGN.md`](2026-06-28_DEPENDENCY_RESOLVER_DEMO_DESIGN.md) (DEMO P1 is the consumer).
- Vision to update: [`LANGUAGE_VISION.org:148-152`](principles/LANGUAGE_VISION.org).

---
*Charter 2026-06-30. Spawned from DEMO Track 1; grounded by the `numerics-grounding` workflow. Next: the track's Stage-2/3 design cycle (start with the §5 forks + the `base-numeric-type` pivot read). DEMO P1 resumes after N1+N3.*
