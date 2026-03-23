# Network Type Theory (NTT) — Syntax Design

**Stage**: 1 (Design Discussion)
**Date**: 2026-03-22
**Series**: NTT Research Document 2 / SRE Series
**Status**: Active design discussion. ~70-80% clarity. Known unknowns identified. Case studies pending at ~90%.

## 1. Purpose

This document captures the emerging syntax design for typing propagator
networks in Prologos surface syntax. It follows the established config
language pattern (keyword metadata on toplevel forms) and the Progressive
Disclosure principle (simple cases look simple; full categorical power
available when needed).

The design is informed by:
- Categorical Foundations (NTT Research Doc 1): polynomial functors, Grothendieck fibrations, Kan extensions
- SRE Research: structural decomposition as universal primitive
- Existing config language patterns: `spec`, `trait`, `property`, `functor`, `solver`, `strategy`
- Conversation insights on ergonomics, minimal syntax, and compositional config

**Design principles for NTT syntax**:
1. **Minimal syntax**: 80% use case requires no annotation. Safe defaults implicit.
2. **Block grouping**: Indentation replaces repeated keyword prefixes.
3. **Config compositionality**: `:extends` for inheritance, open keyword maps for extensibility.
4. **Derive-not-declare**: Structural decomposition derived from type definitions, not separately declared.
5. **Progressive disclosure**: Layer 1 users see lattices + propagators. Layer 4 users see full categorical specs.

## 2. Form Inventory

| Form | Level | Purpose | Status |
|------|-------|---------|--------|
| `trait Lattice` | 0 | Lattice as trait (existing machinery) | Refine |
| `propagator` | 2 | Propagator type declaration | New |
| `schema` (network) | 3 | Network interface type | New (extends existing `schema`) |
| `network` | 3 | Network implementation | New |
| `bridge` | 4 | Galois connection between domains | New |
| `stratification` | 5 | Declarative stratum configuration + solver config | New |
| `exchange` | 6 | Inter-stratum adjunction (Kan, Free/Forgetful, etc.) | New |

**Not a form**: `form` (SRE structural decomposition) — derived from type definitions automatically. See §8.

## 3. Level 0: Lattice Types

Lattices are expressed via the existing `trait`/`impl` machinery. No new
toplevel form needed.

```prologos
trait Lattice {L : Type}
  :where [Commutative join]
         [Associative join]
         [Idempotent join]
         [Identity join bot]
  spec join L L -> L
  spec bot -> L

trait BoundedLattice {L : Type}
  :extends [Lattice L]
  spec top -> L

trait Quantale {L : Type}
  :extends [Lattice L]
  spec tensor L L -> L
  :where [Associative tensor]
         [Distributes tensor join]
```

```prologos
type Color := red | green | blue | unknown | mixed

impl Lattice Color
  join
    | unknown x -> x
    | x unknown -> x
    | x x       -> x
    | _ _       -> mixed
  bot -> unknown
```

**Design notes**:
- `:where` constraints are property/law obligations. The compiler verifies
  for finite types (exhaustive case analysis) or requires proof terms.
- `Quantale` extends `Lattice` with a tensor operation. Bridges that
  preserve tensor structure are quantale morphisms (see §7 `:preserves`).
- `:where` uses block syntax: one keyword, indented constraints.

**Open question**: Should lattice laws use `property` groups (`:laws`)
or inline `:where` constraints? The `trait :laws` pattern references
a named `property` group. The inline `:where` is more compact. Both
should work; preference is a style question.

## 4. Level 2: Propagator Types

New toplevel form. Distinguished from `spec` because propagators carry
fundamentally different metadata (reads/writes cells, stratum assignment,
monotonicity class).

```prologos
propagator add-prop
  :reads  [Cell NatLattice] [Cell NatLattice]
  :writes [Cell NatLattice]
  :stratum S0
  [plus [read x] [read y]]
```

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `:reads` | `[Cell L ...]` | required | Input cells with lattice types |
| `:writes` | `[Cell L ...]` | required | Output cells with lattice types |
| `:stratum` | `Stratum` | none | Which stratum this fires in |
| `:non-monotone` | flag | monotone | Opt out of implicit Monotone (requires barrier stratum) |

**Design decisions**:
- **Monotone is implicit**: All propagators default to Monotone. Only
  barrier-stratum propagators opt out with `:non-monotone`. Parallels
  QTT defaulting to `:ω`. The compiler enforces: `:non-monotone`
  requires `:stratum` to be a barrier stratum.
- **`:reads` / `:writes`** not `:inputs` / `:outputs`: More honest about
  what propagators do (read cell values, write joins). Avoids collision
  with `schema :inputs :outputs` for network interfaces.
- **Body is the fire function**: The expression after the metadata is the
  fire function body. Propagator cells are bound positionally from
  `:reads` / `:writes` declarations.

**Open question**: Should the body be mandatory? Some propagators are
structural (SRE-derived from type definitions) and have no user-written
body. These may not need a `propagator` declaration at all — they're
auto-generated. See §8.

## 5. Level 3: Network Types

### 5.1 Network Interface (`schema`)

Network interfaces reuse the existing `schema` concept — a typed
description of inputs and outputs. This is the polynomial functor type.

```prologos
schema AdderNet
  :inputs  [x : Cell NatLattice, y : Cell NatLattice]
  :outputs [sum : Cell NatLattice]
```

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `:inputs` | `[name : Cell L ...]` | `[]` | Input interface (polynomial directions) |
| `:outputs` | `[name : Cell L ...]` | `[]` | Output interface (polynomial positions) |

**Design note**: The polynomial functor `p(y) = Σ_{i∈O} y^{deps(i)}`
is encoded by `:outputs` (positions O) and `:inputs` (directions).
Users don't see polynomial functors; they see inputs and outputs.

### 5.2 Network Implementation (`network`)

```prologos
network combined : CombinedNet
  embed adder1 : AdderNet
        adder2 : AdderNet
  connect a -> adder1.x
          b -> adder1.y
          adder1.sum -> adder2.x
          c -> adder2.y
          adder2.sum -> result
```

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `embed` | block: `name : Schema` | — | Instantiate sub-networks |
| `connect` | block: `cell -> cell` | — | Wire outputs to inputs (type-checked) |
| `bridge` | block: `name : Bridge` | — | Embed bridge instances (see §7) |

**Design decisions**:
- **Block syntax**: `embed` and `connect` use indentation grouping.
  Multiple embeds under one `embed` keyword, multiple connections under
  one `connect`.
- **Dot access for sub-network cells**: `adder1.sum` uses our existing
  dot-access syntax (maps to `map-get` at the expression level, but here
  it's network cell access — different semantics, same syntax).
- **Type checking on `connect`**: The compiler verifies that connected
  cells have compatible lattice types. Incompatible lattices = type error.

## 6. Level 4: Bridge Types

Bridges connect two lattice domains via a Galois connection (α/γ adjunction).

```prologos
bridge TypeToMult
  :from TypeLattice
  :to   MultLattice
  :alpha type->mult-alpha
  :gamma mult->type-gamma
```

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `:from` | `Lattice` | required | Source lattice domain |
| `:to` | `Lattice` | required | Target lattice domain |
| `:alpha` | `Fn : L -> M` | required | Abstraction (forward) |
| `:gamma` | `Fn : M -> L` | required | Concretization (backward) |
| `:preserves` | `[Structure ...]` | `[Adjunction]` | Structural conditions beyond adjunction |
| `:one-way` | flag | bidirectional | Projection-only bridge (no γ) |

**Design decisions**:
- **Adjunction is implicit**: Bridges default to full Galois connection.
  Compiler verifies adjunction laws automatically. Override with
  `:one-way` for projection-only bridges (α without γ).
- **`:preserves`**: Extensible structural conditions. `[Tensor]` makes
  the bridge a quantale morphism. `[Trace]` preserves traced monoidal
  structure. Each condition adds a proof obligation.
- **Bridges live in `stratification`**: A bridge declaration defines the
  bridge; its stratum assignment comes from the `stratification` that
  embeds it. This keeps bridge definitions clean and orthogonal to
  orchestration.

**Open question**: Is `:preserves` the right keyword? It's semantically
correct (the bridge preserves additional structure) but may not be
immediately intuitive. Alternatives: `:also`, `:structure`, `:maintains`.
The concept is important regardless of naming.

**Open question**: One-way bridges. If `:one-way` means "only α, no γ",
is this still a "bridge"? Or should one-way projections have a different
form? Currently keeping as a flag on `bridge` for simplicity.

## 7. Level 5: Stratification

Declarative stratum configuration. This is the most novel form and
subsumes the existing `solver` configuration.

### 7.1 Fixed Stratification

```prologos
stratification ElabLoop
  :strata [S-neg1 S0 S1 S2]
  :fiber S0
    :mode monotone
    :bridges [TypeToSession TypeToMult]
  :fiber S1
    :mode monotone
  :barrier S2 -> S-neg1
    :commit resolve-and-retract
  :fuel 100
  :where [WellFounded ElabLoop]
```

### 7.2 Inductive (Growing) Stratification

For NAF-LE style computation where strata grow dynamically:

```prologos
stratification NAFLoop
  :base S0
    :mode monotone
    :networks [fact-net rule-net]
  :recurse
    :trigger negation-as-failure
    :mode monotone
    :grows-by 1
    :halts-when [fixpoint]
  :fuel 100
  :where [WellFounded NAFLoop]
```

### 7.3 Composable Stratification

Stratifications can extend others, inheriting configuration and
overriding specific strata:

```prologos
stratification CustomElabLoop
  :extends ElabLoop
  :fiber S0
    :scheduler bsp              ;; override: BSP instead of Gauss-Seidel
    :bridges [TypeToSession TypeToMult EffectToMult]  ;; add a bridge
  :fuel 200                     ;; override fuel
```

### 7.4 Keyword Reference

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `:strata` | `[Stratum ...]` | required (fixed) | Ordered stratum list |
| `:base` | `Stratum` block | required (inductive) | Base stratum for growing stratification |
| `:recurse` | block | — | Inductive growth configuration |
| `:trigger` | `Symbol` | — | What causes stratum growth |
| `:grows-by` | `Nat` | `1` | Strata added per trigger |
| `:halts-when` | `[Condition]` | — | Natural termination condition |
| `:fiber` | `Stratum` block | — | Per-stratum configuration |
| `:mode` | `Symbol` | `monotone` | `monotone` / `retraction` / `commit` |
| `:bridges` | `[Bridge ...]` | `[]` | Bridges that fire in this stratum |
| `:networks` | `[Network ...]` | `[]` | Sub-networks in this stratum |
| `:barrier` | `S -> S` block | — | Non-monotone transition |
| `:commit` | `Fn` | — | Barrier action function |
| `:fuel` | `Nat` | required | Maximum iteration fuel |
| `:extends` | `Stratification` | none | Inherit + override from parent |
| `:scheduler` | `Symbol` | `:auto` | `bsp`, `gauss-seidel`, `:auto` |
| `:strategy` | `Symbol` | `:dfs` | Search strategy (for solver contexts) |
| `:where` | `[Constraint ...]` | `[]` | Well-foundedness, other constraints |

**Design decisions**:
- **Subsumes `solver` config**: `:scheduler`, `:fuel`, `:strategy` were
  previously on `solver`. They belong on `stratification` because different
  strata may need different scheduling. A `solver` becomes a named
  `stratification` instance.
- **`:extends` for compositionality**: Stratifications inherit from parents
  and override specific fields. This gives config compositionality — define
  a base ElabLoop, derive custom versions for testing, profiling, etc.
- **`:fixed` vs `:inductive`**: Presence of `:strata` = fixed. Presence of
  `:base` + `:recurse` = inductive. Mutually exclusive. The compiler
  infers which kind.
- **`:where [WellFounded]`**: Required. The compiler verifies termination:
  fixed stratifications terminate if fuel is finite; inductive
  stratifications terminate if `:halts-when` is well-founded AND fuel
  is finite.

**Open question**: Should `:scheduler` be per-stratum (on `:fiber`) or
per-stratification? Per-stratum is more flexible (BSP for heavy S0,
Gauss-Seidel for light S1) but adds complexity. Currently shown on
`:fiber` for maximum flexibility.

## 8. Level 6: Exchange (Inter-Stratum Adjunctions)

Inter-stratum adjunctions. Named `exchange` to capture the dynamic,
bidirectional nature of information flow between strata. Distinct from
`bridge` (value domains) because exchanges operate on computation states.

```prologos
exchange S0 <-> S1
  :left  partial-fixpoint -> approximate-result
  :right needed-cells -> targeted-thresholds
```

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `:left` | `Fn` | — | Left adjoint (speculative / free / suspension) |
| `:right` | `Fn` | — | Right adjoint (demand-driven / forgetful / loop) |
| `:kind` | `Symbol` | inferred | Documentation: `kan`, `free-forgetful`, `suspension-loop` |

**Design decisions**:
- **`:left` / `:right`** not `:speculative` / `:demand`: More general.
  Kan extensions have Lan (left) and Ran (right). Free/Forgetful has
  Free (left) and Forgetful (right). The left/right naming works for
  any adjunction.
- **`:kind` is documentation**: The compiler doesn't use it — the
  adjunction laws are verified from `:left` and `:right` regardless of
  kind. `:kind` helps humans understand what type of exchange this is.
- **Exchanges live in `stratification`**: Like bridges, exchanges are
  declared separately but embedded into stratifications:

```prologos
stratification ElabLoop
  :strata [S-neg1 S0 S1 S2]
  :fiber S0
    :mode monotone
    :bridges [TypeToSession TypeToMult]
  :exchange S0 <-> S1
    :left  partial-fixpoint -> early-readiness
    :right demand -> targeted-propagation
  :barrier S2 -> S-neg1
    :commit resolve-and-retract
  :fuel 100
```

**Open question**: Is Adjunction the right implicit default for exchanges?
Unlike bridges (where Adjunction is almost always correct), some
inter-stratum interactions may be weaker (e.g., one-way triggering without
a proper right adjoint). Should `:one-way` exist on exchanges too?

## 9. Structural Decomposition: Derived, Not Declared

A key insight from the design discussion: **SRE structural decomposition
should be derived from type definitions, not separately declared.**

When a user writes:
```prologos
data Pi := pi [domain : Type] [codomain : Type]
```

The SRE automatically knows:
- Pi decomposes into `domain` and `codomain`
- The polynomial summand is `y²` (two sub-cells)
- Decomposition propagators can be auto-generated

This means **no `form` toplevel is needed**. The SRE form registry is
populated automatically from `data`/`type` definitions. The polynomial
functor structure of the SRE is derived from the type system.

**Where explicit declaration may still be needed**:
- Cross-domain decomposition that isn't structural (e.g., extracting
  `Indexed` from `List Int` for trait dispatch) — but this is a `bridge`
  concern, not a `form` concern.
- Performance-critical decomposition where the auto-derived propagator
  isn't optimal — an `:optimize` hint on the type definition, not a
  separate form.

**This is a research question for SRE Track 0**: Can all structural
decomposition be derived? What are the edge cases? The design should
support the derive-by-default path while allowing escape hatches.

## 10. Design Unknowns

### 10.1 Known Unknowns

1. **Quantale morphism syntax**: `:preserves [Tensor]` captures the
   concept but the keyword may not be intuitive. Need to explore how
   the effect ordering system's quantale morphisms map into bridge
   declarations specifically.

2. **Solver ↔ Stratification unification**: If `stratification` subsumes
   `solver`, what happens to existing `solver` declarations? Migration
   path? Or keep both with `solver` as sugar for a simple stratification?

3. **Exchange adjunction verification**: For Kan extensions, the adjunction
   laws Lan ⊣ Ran are non-trivial to verify automatically. What level of
   automated verification is feasible? What proof obligations fall to the
   user?

4. **Inductive stratification termination**: `:halts-when [fixpoint]` is
   conceptually clear but the compiler needs to verify that the fixpoint
   condition is actually reachable. For NAF-LE this is well-understood;
   for user-defined inductive stratifications, it may be undecidable.

5. **Network template instantiation**: Higher-order networks (parameterized
   by lattice type via `functor`) need an instantiation syntax. `embed`
   in `network` handles this, but the type checking of parameterized
   instantiation needs design.

6. **Free ⊣ Forgetful for trait derivation**: Can this adjunction be made
   first-class in the NTT? Would `impl Eq Color :derive` invoke the
   left adjoint (free construction)? How does this interact with the
   existing manual `impl` pattern?

7. **Traced monoidal provenance**: Making domains traced monoidal would
   formalize provenance collection. But adding trace structure to every
   domain has overhead. Should trace be opt-in (`:preserves [Trace]` on
   bridges) or domain-level (on lattice declarations)?

### 10.2 Unknown Unknowns (Areas Where Surprises May Emerge)

1. **Interaction between multiple enrichments**: A cell that is
   lattice-enriched (correctness), tropical-enriched (cost optimization),
   AND trace-enriched (provenance) — do these compose cleanly?

2. **Mode-dependent polynomial fan-out**: When a propagator's output
   count depends on runtime values (not just constructor tags), the
   polynomial functor becomes mode-dependent. How does this interact
   with static type checking?

3. **Self-referential typing**: The NTT types the propagator network.
   The type checker IS a propagator network. When the NTT types itself,
   what happens? Bootstrapping is the expected resolution, but edge
   cases may surprise.

4. **Composing stratifications**: `:extends` handles single inheritance.
   What about composing two independent stratifications (e.g., combining
   a type-checking stratification with an effect-checking stratification)?
   Is this a product in the category of stratifications?

## 11. Progressive Disclosure Summary

| Layer | What the user writes | Categorical content (invisible) |
|-------|---------------------|-------------------------------|
| 1 | `trait Lattice`, `impl Lattice Color`, `propagator add-prop` | Lattice theory, polynomial summands, monotonicity |
| 2 | `schema AdderNet`, `network combined`, `embed`, `connect` | Polynomial functor composition, typed wiring |
| 3 | `bridge TypeToMult`, `stratification ElabLoop`, `exchange` | Galois connections, Grothendieck fibrations, Kan extensions |
| 4 | `:preserves [Tensor Trace]`, `:where [WellFounded]`, full specs | Quantale morphisms, traced monoidal structure, proof terms |

## 12. Next Steps

1. **Continue design iteration**: Address open questions through discussion.
   Target ~90% clarity before case studies.

2. **Case studies** (at ~90%): Map our actual implementations onto the
   NTT syntax:
   - The type checker's S0→S1→S2 loop as a `stratification`
   - The session-type bridge as a `bridge` declaration
   - The NAF-LE as an inductive `stratification`
   - A PUnify structural decomposition as derived-from-type

3. **Grammar integration**: Add NTT forms to `grammar.ebnf` and
   `grammar.org` once syntax stabilizes.

4. **Toplevel Forms Reference update**: Add finalized NTT forms to
   `TOPLEVEL_FORMS_REFERENCE.org`.

## 13. Source Documents

| Document | Relationship |
|----------|-------------|
| [Categorical Foundations (NTT Doc 1)](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) | Provides categorical grounding for each level |
| [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) | Informs derive-not-declare principle (§9) |
| [Toplevel Forms Reference](TOPLEVEL_FORMS_REFERENCE.org) | Config language patterns and keyword conventions |
| [Master Roadmap](MASTER_ROADMAP.org) | NTT Series tracking, SRE Series tracking |
| [Unified Infrastructure Roadmap](2026-03-22_PM_UNIFIED_INFRASTRUCTURE_ROADMAP.md) | On-network / off-network boundary analysis |
