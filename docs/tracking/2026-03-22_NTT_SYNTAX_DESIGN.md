# Network Type Theory (NTT) — Syntax Design

**Stage**: 1 (Design Discussion)
**Date**: 2026-03-22
**Series**: NTT Research Document 2 / SRE Series
**Status**: Active design discussion. ~85-90% clarity. Architecture survey completed, 5 gaps identified and resolved. Deep case study (NF-Narrowing) pending.

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
| `property` | 0 | Named reusable constraint groups | Designed (parsed) |
| `propagator` | 2 | Propagator type declaration (context-free, no stratum) | New |
| `interface` | 3 | Network interface type (polynomial functor) | New |
| `network` | 3 | Network implementation | New |
| `bridge` | 4 | Galois connection between domains (one-way or bidirectional) | New |
| `stratification` | 5 | Declarative config + solver + fixpoint modalities | New |
| `exchange` | 6 | Inter-stratum adjunction (Kan, Free/Forgetful, etc.) | New |
| `codata` | — | Coinductive type definition (observations, not constructors) | New |
| `newtype` | — | Zero-cost type wrapper (bilattice orderings, etc.) | New |

**Not a form**: SRE structural decomposition — derived from `data`/`codata`
type definitions (`:lattice :structural`) + NF-narrowing. See §9.
Dynamic propagator installation handled by SRE, not by individual propagators.

## 3. Level 0: Lattice Types

The architecture survey (NTT Doc 3) revealed a fundamental split: three
of seven systems have lattice merges that create sub-cells and install
propagators (TypeExpr, TermValue, SessionExpr). These are NOT pure
`join : L L -> L` functions — they're network transformations. The SRE
handles these automatically via structural decomposition.

This splits Level 0 into two kinds:

### 3.1 Value Lattices (pure join)

Simple lattices with pure merge functions: flat lattices, finite chains,
boolean lattices. These get `impl Lattice` with a normal join.

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
;; Value lattice — pure join
type MultExpr := mult-bot | m0 | m1 | mw | mult-top

impl Lattice MultExpr
  join
    | mult-bot x -> x
    | x mult-bot -> x
    | x x        -> x
    | _ _        -> mult-top
  bot -> mult-bot

impl Quantale MultExpr
  tensor [a b] [mult-times a b]

;; Value lattice — finite enumeration
type Color := red | green | blue | unknown | mixed

impl Lattice Color
  join
    | unknown x -> x
    | x unknown -> x
    | x x       -> x
    | _ _       -> mixed
  bot -> unknown
```

### 3.2 Structural Lattices (SRE-derived merge)

Types whose merge involves structural decomposition into sub-cells.
These DON'T get `impl Lattice` with a manual join. Instead, their
type definitions carry the structural information, and the SRE provides
merge as a network operation — automatically derived from constructors.

```prologos
;; Structural lattice — SRE handles merge
;; The constructors' fields ARE the polynomial summands
data TypeExpr
  := type-bot
   | type-top
   | expr-pi [domain : TypeExpr] [codomain : TypeExpr]
   | expr-sigma [fst : TypeExpr] [snd : TypeExpr]
   | expr-app [fn : TypeExpr] [arg : TypeExpr]
   | ...
  :lattice :structural
  :bot type-bot
  :top type-top
```

The `:lattice :structural` annotation says: "this type's merge semantics
are structural decomposition." The SRE knows: `Pi` decomposes into
`domain` and `codomain`; merging two `Pi` values means unifying their
sub-fields via sub-cells. Merging `Pi` with `Sigma` = `type-top`
(contradiction). Merging `type-bot` with anything = that thing.

**Three systems use structural lattices**: TypeExpr, TermValue,
SessionExpr. All three exhibit the same pattern — merge creates sub-cells
and installs propagators. The SRE handles all three uniformly.

**This eliminates three survey gaps**: Structural merge creating
propagators, dynamic propagator installation, and higher-order network
operations are all "the SRE doing its job." The NTT doesn't need
`:dynamic` flags or `propagator-template` — it types the SRE by
distinguishing structural from value lattices.

### 3.3 Bilattices (two orderings via `newtype`)

WF-LE needs two orderings (knowledge, truth) on the same carrier.
Resolved via `newtype` wrappers that give distinct types for each
ordering:

```prologos
type BilatticeValue := bl-bot | bl-true | bl-false | bl-unknown | bl-top

newtype Knowledge := Knowledge BilatticeValue
newtype Truth := Truth BilatticeValue

impl Lattice Knowledge
  join [Knowledge a] [Knowledge b] -> Knowledge [knowledge-join a b]
  bot -> Knowledge bl-bot

impl Lattice Truth
  join [Truth a] [Truth b] -> Truth [truth-join a b]
  bot -> Truth bl-bot
```

`newtype` is zero-cost (erased at runtime) but gives distinct types.
The WF-LE solver works on `Cell Knowledge` and `Cell Truth` as separate
cells — which matches our implementation (lower cell + upper cell per
variable). The `:bilattice` keyword on `stratification` connects them.

### 3.4 Design Notes

- `:where` is the universal catch-all for constraints, laws, and
  property obligations. `property` is a *definition form* that names
  a reusable group:

```prologos
property Monoid {M : Type}
  :where [Associative op]
         [Identity op e]

trait Lattice {L : Type}
  :where [Monoid L join bot]
         [Idempotent join]
         [Commutative join]
  spec join L L -> L
  spec bot -> L
```

- `Quantale` extends `Lattice` with tensor. Bridges with
  `:preserves [Tensor]` are quantale morphisms.
- `:where` uses block syntax: one keyword, indented constraints.

## 4. Level 2: Propagator Types

New toplevel form. Distinguished from `spec` because propagators carry
fundamentally different metadata (reads/writes cells, monotonicity class).

```prologos
propagator add-prop
  :reads  [Cell NatLattice] [Cell NatLattice]
  :writes [Cell NatLattice]
  [plus [read x] [read y]]
```

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `:reads` | `[Cell L ...]` | required | Input cells with lattice types |
| `:writes` | `[Cell L ...]` | required | Output cells with lattice types |
| `:non-monotone` | flag | monotone | Opt out of implicit Monotone (requires barrier stratum) |

**Design decisions**:
- **Monotone is implicit**: All propagators default to Monotone. Only
  barrier-stratum propagators opt out with `:non-monotone`. Parallels
  QTT defaulting to `:ω`. The compiler enforces: `:non-monotone`
  propagators can only be assigned to barrier strata in `stratification`.
- **No `:stratum` on propagator**: A propagator's stratum is NOT inherent
  — the same propagator could fire in S0 in one stratification and S1 in
  another. Stratum assignment belongs to the `stratification` that embeds
  the propagator (via `:fiber` declarations). This keeps propagator
  definitions context-free and reusable.
- **Cross-stratum effects are cell-mediated**: A propagator that "fires
  into" another stratum doesn't reach across strata — it writes to cells
  that propagators in the other stratum watch. The `exchange` adjunction
  (§8) formalizes this cross-stratum mediation. The individual propagator
  doesn't need to know about strata at all.
- **`:reads` / `:writes`** not `:inputs` / `:outputs`: More honest about
  what propagators do (read cell values, write joins). Distinguishes from
  `interface :inputs :outputs` for network boundary declarations.
- **Body is the fire function**: The expression after the metadata is the
  fire function body. Propagator cells are bound positionally from
  `:reads` / `:writes` declarations.

**Resolved**: Structural decomposition propagators are SRE-derived from
type definitions (§3.2) — they don't need `propagator` declarations.
The `propagator` form is for user-defined, non-structural propagators
with explicit fire function bodies. Dynamic propagator installation
(PUnify, NF-Narrowing branch dispatch) is handled by the SRE, not by
individual propagators — no `:dynamic` flag needed.

## 5. Level 3: Network Types

### 5.1 Network Interface (`interface`)

Network interfaces use `interface` — a typed declaration of inputs and
outputs for a computational component. This is the polynomial functor
type. (`schema` is reserved for data object shapes — the structure of
maps and records.)

```prologos
interface AdderNet
  :inputs  [x : Cell NatLattice
            y : Cell NatLattice]
  :outputs [sum : Cell NatLattice]
```

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `:inputs` | `[name : Cell L ...]` | `[]` | Input interface (polynomial directions) |
| `:outputs` | `[name : Cell L ...]` | `[]` | Output interface (polynomial positions) |

**Design note**: The polynomial functor `p(y) = Σ_{i∈O} y^{deps(i)}`
is encoded by `:outputs` (positions O) and `:inputs` (directions).
Users don't see polynomial functors; they see inputs and outputs.

**Connection to actor model**: Propagator networks subsume the actor
model — an actor is a propagator with private cells and message-passing
via shared cells. But propagators are more general: multi-read (fan-in),
multi-write (fan-out), monotonic accumulation, and lattice merge. Milner's
π-calculus gives us channels as first-class values, parallel composition,
and restriction — in our framework: cells (first-class, scopable),
`embed` + `connect` (parallel composition), and cell scoping (restriction).
The `interface` declaration is the static type of a network's channel
topology.

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
| `embed` | block: `name : Interface` | — | Instantiate sub-networks |
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
- **Network lifetime**: `:lifetime :persistent` (survives across commands,
  e.g., registry network) vs `:lifetime :speculative` (scoped to
  speculation branch, TMS-aware entries). Default is `:speculative`.

```prologos
network registry-net : RegistryInterface
  :lifetime :persistent

network elab-net : ElaborationInterface
  :lifetime :speculative
  :tagged-by Assumption
```

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
| `:preserves` | `[Structure ...]` | `[]` | Additional structural conditions (quantale, trace) |

**Design decisions**:
- **Adjunction is implicit for bidirectional bridges**: When both `:alpha`
  and `:gamma` are provided, the compiler verifies adjunction laws
  automatically (α ∘ γ ∘ α = α, γ ∘ α ∘ γ = γ).
- **One-way is implicit from missing keyword**: If only `:alpha` is
  specified, the bridge is one-way from→to. If only `:gamma`, one-way
  to→from. No explicit `:one-way` flag needed — the structure speaks for
  itself. Minimal syntax.

```prologos
;; Bidirectional (full Galois connection, adjunction verified)
bridge TypeToMult
  :from TypeLattice
  :to   MultLattice
  :alpha type->mult
  :gamma mult->type

;; One-way projection (only alpha, no gamma)
bridge EffectToLog
  :from EffectLattice
  :to   LogLattice
  :alpha effect->log
```

- **`:preserves`**: Extensible structural conditions beyond adjunction.
  `[Tensor]` makes the bridge a quantale morphism. `[Trace]` preserves
  traced monoidal structure. Each condition adds a proof obligation.
  The concept is essential; the keyword name may evolve.
- **Bridges live in `stratification`**: A bridge declaration defines the
  bridge; its stratum assignment comes from the `stratification` that
  embeds it (via `:bridges` on `:fiber`). This keeps bridge definitions
  clean and orthogonal to orchestration.

## 7. Level 5: Stratification

Declarative stratum configuration. This is the most novel form and
subsumes the existing `solver` configuration.

### 7.1 Fixed Stratification

```prologos
stratification ElabLoop
  :strata [S-neg1 S0 S1 S2]
  :scheduler :bsp                       ;; default for all fibers
  :fiber S0
    :bridges [TypeToSession TypeToMult]
  :fiber S1
    :scheduler :gauss-seidel            ;; override for S1
  :barrier S2 -> S-neg1
    :commit resolve-and-retract
  :fuel 100
  :where [WellFounded ElabLoop]
```

Note: `:mode monotone` is implicit (safe default). Only barrier strata
need explicit mode (`:mode retraction`, `:mode commit`).
`:scheduler` uses CSS-cascade scoping: outer scope sets default, inner
`:fiber` overrides for that stratum.

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

### 7.4 Fiber Network Composition

Networks embedded in a fiber are isolated unless connected by bridges:

```prologos
stratification TypeCheckWithSessions
  :extends ElabLoop
  :fiber S0
    :networks [type-net session-net mult-net effect-net]
    :bridges  [TypeToSession TypeToMult EffectToMult]
  :fiber S1
    :networks [readiness-net]
```

The egress of one network (type cells becoming ground) feeds via a
bridge's α into the ingress of another (constraint cells needing type
information). Without a bridge declaration, networks in the same fiber
share quiescence but not state. This IS polynomial functor composition:
`type-net ◁ bridge ◁ constraint-net`, where ◁ is Poly wiring.

### 7.5 Fixpoint Modalities

Stratifications specify their fixpoint character:

| Modality | Character | Example |
|----------|-----------|---------|
| `:lfp` | Least fixpoint — inductive, finite, well-founded | Type inference (default) |
| `:gfp` | Greatest fixpoint — coinductive, productive | Stream checking, session protocols |
| `:stratified` | Iterated lfp across strata | NAF-LE (each stratum lfp, overall iterated) |
| `:approximation` | Denecker's AFT — stable/well-founded semantics | WF-LE bilattice solver |
| `:metric` | Banach contraction — unique fixpoint by contractiveness | Tropical semiring optimization |
| `:mixed` | Alternating μν/νμ — parity games | Liveness + safety property checking |

```prologos
stratification TypeInference
  :fixpoint :lfp               ;; default for most strata
  :fuel 100

stratification StreamChecker
  :fixpoint :gfp               ;; coinductive: productive streams
  :where [Productive StreamChecker]

stratification WFSolver
  :fixpoint :approximation     ;; Denecker's AFT
  :bilattice [knowledge truth]
  :stable-operator wf-stable
```

`:lfp` is the implicit default (the common case). The first five are
lattice-theoretic (Knaster-Tarski foundation); `:metric` lives in
complete metric spaces but still has a propagator interpretation
(each iteration contracts distances, guaranteed to converge).

### 7.6 Keyword Reference

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
| `:fixpoint` | `Symbol` | `:lfp` | `lfp`, `gfp`, `stratified`, `approximation`, `metric`, `mixed` |
| `:bilattice` | `[Lattice Lattice]` | — | Knowledge + truth orderings (for `:approximation`) |
| `:where` | `[Constraint ...]` | `[]` | Well-foundedness, productivity, other constraints |

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

**Resolved**: `:scheduler` uses CSS-cascade scoping — declared at
stratification level as default, overrideable per-fiber. Inner scope
shadows outer scope. This gives both simplicity (one `:scheduler` for
the common case) and flexibility (per-fiber override when needed).
Same scoping principle applies to `:fixpoint` and other config keywords.

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
a proper right adjoint). Same resolution as bridges: if only `:left` is
specified, it's one-way. If both, adjunction verified.

## 9. The SRE: Structural Reasoning as First-Class Concept

The architecture survey (NTT Doc 3) promoted the SRE from a convenience
("derive decomposition from types") to a **load-bearing architectural
concept**: the SRE is HOW structural lattices operate. It's not a layer
on top of the propagator network — it IS the propagator network's
structural reasoning mechanism.

### 9.1 What the SRE Does

For any type annotated `:lattice :structural`:
1. **Derives merge semantics** from constructor fields (polynomial summands)
2. **Creates sub-cells** when structural values meet (decomposition)
3. **Installs unification propagators** between sub-cells (composition)
4. **Handles contradiction** when incompatible constructors meet (→ top)

This replaces three separate mechanisms: manual `impl Lattice` join,
explicit `propagator` declarations for decomposition, and dynamic
propagator installation flags.

### 9.2 What the SRE Doesn't Handle

- **Value lattice merge**: Pure functions, handled by `impl Lattice`
- **Cross-domain relationships**: Handled by `bridge` (α/γ)
- **Inter-stratum interaction**: Handled by `exchange`
- **Non-structural decomposition**: e.g., extracting `Indexed` from
  `List Int` for trait dispatch — this is a `bridge` concern

### 9.3 Additional Structural Sources

Beyond type definitions:
- **NF-Narrowing**: Reveals which constructors a function can produce
  in normal form (structural inference from definition)
- **Coinductive types** (`codata`): Structure from observations, dual
  to constructors (structural inference from usage/elimination)
- **Usage-based inference**: For untyped foreign interop, infer structure
  from access patterns (weakest form)

### 9.4 The SRE in the NTT Type Tower

The SRE sits between Level 0 (Lattice) and Level 2 (Propagator):
- Level 0 declares structural lattices via `:lattice :structural`
- The SRE derives Level 2 propagators from Level 0 type definitions
- Level 3 networks contain SRE-derived propagators alongside user-defined ones
- The SRE's form registry IS the polynomial functor's summand catalog

## 10. Coinductive Types and Foreign Type Structure

Inductive types define structure by *constructors* (how you build values).
Coinductive types define structure by *observations* (how you use values).

| | Inductive | Coinductive |
|---|----------|-------------|
| Defined by | Constructors (intro) | Observations/destructors (elim) |
| Values | Finite, well-founded | Potentially infinite, productive |
| Reasoning | Structural recursion | Guarded corecursion |
| SRE structure | Constructor tags → decomposition | Observation labels → projection |
| Fixpoint | `:lfp` | `:gfp` |

```prologos
;; Inductive: constructors define structure
data List {A : Type} := nil | cons [head : A] [tail : List A]

;; Coinductive: observations define structure
codata Stream {A : Type}
  head -> A
  tail -> Stream A
```

For the SRE, coinductive structure is just as derivable as inductive —
but from observations rather than constructors. The polynomial functor
summand is the same shape (`y²` for a stream's two observations), but
the direction is flipped.

**Foreign types**: When we can't see constructors (opaque Racket FFI
types), we CAN define observations:

```prologos
foreign codata RacketPort
  read-byte -> Option Byte
  peek-byte -> Option Byte
  port-open? -> Bool
```

The foreign type's structure is defined by what you can observe, not by
how it's constructed. The SRE decomposes `RacketPort` into its
observation interface. This gives structural reasoning about foreign
types without needing their internal representation.

**Connection to fixpoint modalities**: Inductive types pair with `:lfp`
stratifications (well-founded recursion). Coinductive types pair with
`:gfp` stratifications (productive corecursion). The `stratification`
form's `:fixpoint` keyword directly reflects this duality.

## 11. Additional Sources of Structural Information

Beyond type definitions, two other systems provide structural knowledge
that the SRE can ingest:

### 11.1 NF-Narrowing

NF-narrowing analysis reveals what constructors a function can produce
in normal form. If `f : Nat -> List Nat` always produces `cons` (never
`nil`), the SRE knows:
- Decomposing the output of `f` into head/tail is always safe
- The `nil` branch of a match on `[f n]` is dead code
- The output type is refined: `NonEmptyList Nat`

This is structural inference from definition — dual to the coinductive
approach (structural inference from usage/observation).

### 11.2 Usage-Based Inference

For types without explicit structure (foreign types without `codata`
declarations), the compiler can infer structure from usage patterns:
if code always accesses `foo.bar` and `foo.baz`, the type has at least
those two observations. This is the weakest form of structural
information but provides a safety net for untyped foreign interop.

## 12. Vision: First-Class Networks and Phase Unification

### 12.1 First-Class Networks

The polynomial functor `interface` type makes networks safe to treat
as first-class values:
- **Pass**: A function taking `Network AdderNet` as argument
- **Compose**: `connect` wires outputs to inputs with type checking
- **Share**: Send a network over a session channel:
  `Send [Network SolverNet] ; S`
- **Distribute**: Networks on different machines propagate via distributed
  cells. Lattice merge is commutative and associative — order of arrival
  doesn't matter (CALM theorem: monotone = coordination-free)

Our session types (`proc` language) and first-class propagator networks
together enable distributed computing paradigms where networks are shared,
composed, and computed over. The combinatorial richness — first-class
channels × types × sessions × prop-nets — is precisely what the NTT type
discipline controls. Without types, that explosion is chaos. With types,
it's composable power.

### 12.2 Compile-Time / Runtime Unification

Propagators dissolve the hard phase distinction between compilation and
execution:
- **At compile time**: Cells hold partial information (metas, constraints).
  Propagation infers types and resolves traits.
- **At runtime**: Cells hold ground values. Propagation computes results.
- **Same mechanism**: Both are propagation to fixpoint on a lattice. The
  difference is the lattice (type vs value) and information availability.

This means gradual typing is natural (cells on the partial→ground
spectrum), runtime type checking is just propagation (`(the Int x)`
installs a type propagator), and AOT guarantees compose monotonically
with runtime flexibility. The propagator paradigm doesn't bridge static
and dynamic — it makes them the same thing at different points on the
information lattice.

## 13. Design Unknowns

### 13.1 Resolved by Architecture Survey

| Gap | Resolution |
|-----|-----------|
| Structural merge creates propagators | §3.2: `:lattice :structural` — SRE-derived merge |
| Dynamic propagator installation | §9: SRE handles it; no `:dynamic` flag needed |
| Higher-order network operations | §9: PUnify IS the SRE; `propagator-template` unnecessary |
| Bilattice two orderings | §3.3: `newtype` wrappers + separate `impl Lattice` each |
| Persistent vs speculative networks | §5: `:lifetime :persistent` / `:speculative` on `network` |

### 13.2 Remaining Known Unknowns

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

8. **SRE merge for coinductive types**: `:lattice :structural` on `data`
   derives merge from constructors. What does SRE merge mean for `codata`?
   Observation-based merge: two values merge if their observations merge
   pointwise? This needs formalization.

### 13.3 Unknown Unknowns (Areas Where Surprises May Emerge)

1. **Interaction between multiple enrichments**: A cell that is
   lattice-enriched (correctness), tropical-enriched (cost optimization),
   AND trace-enriched (provenance) — do these compose cleanly?

2. **Self-referential typing**: The NTT types the propagator network.
   The type checker IS a propagator network. When the NTT types itself,
   what happens? Bootstrapping is the expected resolution, but edge
   cases may surprise.

3. **Composing stratifications**: `:extends` handles single inheritance.
   What about composing two independent stratifications (e.g., combining
   a type-checking stratification with an effect-checking stratification)?
   Is this a product in the category of stratifications?

## 14. Progressive Disclosure Summary

| Layer | What the user writes | Categorical content (invisible) |
|-------|---------------------|-------------------------------|
| 1 | `trait Lattice`, `impl Lattice Color`, `propagator add-prop` | Lattice theory, polynomial summands, monotonicity |
| 2 | `interface AdderNet`, `network combined`, `embed`, `connect` | Polynomial functor composition, typed wiring |
| 3 | `bridge TypeToMult`, `stratification ElabLoop`, `exchange`, `codata` | Galois connections, Grothendieck fibrations, Kan extensions, M-types |
| 4 | `:preserves [Tensor Trace]`, `:fixpoint :gfp`, `:where [WellFounded]` | Quantale morphisms, coinductive types, traced monoidal structure |

## 15. Next Steps

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

## 16. Source Documents

| Document | Relationship |
|----------|-------------|
| [Categorical Foundations (NTT Doc 1)](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) | Provides categorical grounding for each level |
| [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) | Informs derive-not-declare principle (§9) |
| [Toplevel Forms Reference](TOPLEVEL_FORMS_REFERENCE.org) | Config language patterns and keyword conventions |
| [Master Roadmap](MASTER_ROADMAP.org) | NTT Series tracking, SRE Series tracking |
| [Unified Infrastructure Roadmap](2026-03-22_PM_UNIFIED_INFRASTRUCTURE_ROADMAP.md) | On-network / off-network boundary analysis |
