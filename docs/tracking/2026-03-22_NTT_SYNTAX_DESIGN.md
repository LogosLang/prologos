# Network Type Theory (NTT) — Syntax Design

**Stage**: 1 (Design Discussion)
**Date**: 2026-03-22
**Series**: NTT Research Document 2 / SRE Series
**Status**: Active design discussion. ~90% clarity. Architecture survey (7 systems) + 6 deep case studies completed. 11 cumulative gaps (3 resolved, 4 medium open, 4 low open). Round 4 refinements integrated.

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

### 5.3 Parameterized Networks (`functor`)

Our actual networks are ~0% fixed-topology. Every system creates
topology from data: the type checker's network depends on the AST,
PUnify's topology depends on which type constructors appear,
NF-Narrowing's depends on the definitional tree, session verification
depends on the protocol tree. Without `functor`, we can only describe
the *schema* of networks, not their *instantiation* from data.

```prologos
;; SRE structural decomposition, parameterized by type
functor StructuralDecomposition {T : Type} :where [Structural T]
  interface
    :inputs  [parent : Cell TypeLattice]
    :outputs [components : Cell TypeLattice ...]

;; NF-Narrowing network, parameterized by definitional tree
functor NarrowingNet {dt : DefTree}
  interface
    :inputs  [args : Cell TermValue ...]
    :outputs [result : Cell TermValue]

;; Instantiation via embed
network type-checker-s0 : TypeCheckerS0Interface
  embed pi-decomp : StructuralDecomposition Pi
        sigma-decomp : StructuralDecomposition Sigma
  ...
```

`functor` is essential — it makes NTT able to describe real
infrastructure, not just toy fixed-topology examples. The `functor`
parameter (`{T : Type}`, `{dt : DefTree}`) is what determines the
output cell count and topology. This is the polynomial functor's
data-dependent arity: how many output cells depends on the constructor
tag or definitional tree structure.

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
- **`:compose`**: Bridge composition. A→B and B→C compose to A→C:

```prologos
bridge TypeToEffect
  :compose [TypeToSession SessionToEffect]
  ;; α = session-to-effect-alpha ∘ type-to-session-alpha
  ;; γ = type-to-session-gamma ∘ session-to-effect-gamma
  ;; Adjunction verified from components
```

  This is operad composition — the output of one feeds the input of
  the next, with the intermediate lattice type as the "color" that must
  match at the junction. Polynomial functors generalize operads by
  supporting data-dependent fan-out (how many sub-cells depends on the
  constructor tag). And Galois connections add bidirectionality (both α
  and γ compose). The NTT type-checks all three: lattice colors match
  at junctions, fan-out matches polynomial summands, and composed
  adjunction laws hold.

  As long as all three bridges are well-typed, A→C is also expressible
  directly. `:compose` is optional sugar that gives the compiler
  structure for automatic verification.

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
| `:trace` | `Symbol` | `:none` | `:none`, `:count`, `:structural`, `:full` (cascade scoping) |
| `:speculation` | `Symbol` | none | `:atms` — enables TMS-based branching on this fiber |
| `:branch-on` | `[Symbol ...]` | `[]` | What triggers speculation branches |
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

**`:trace` cascade scoping**: `:trace` follows the same CSS-cascade
pattern as `:scheduler` — set at stratification level as default,
override per-fiber or per-cell:

```prologos
stratification ElabLoop
  :trace :structural              ;; default: record propagator + assumption
  :fiber S0
    :speculation :atms            ;; enable TMS branching
    :branch-on [union-types church-folds]
  :fiber S1
    :trace :none                  ;; override: readiness is cheap, don't trace
```

Trace modes (cost dial):
- `:none` — no history, just current value (zero overhead)
- `:count` — write count only (near-zero, enough for hotspot detection)
- `:structural` — propagator ID + assumption ID per write (moderate, enough for explanation)
- `:full` — complete history with values, timestamps, derivation chains (debugging)

Cell-level override for specific instrumentation:
```prologos
interface TypeNet
  :inputs  [expr-cell : Cell TypeLattice :trace :full]   ;; always traced
  :outputs [result : Cell TypeLattice]                    ;; inherits from fiber
```

**Speculation lives on `:fiber`**: The fiber declares that it supports
TMS-based branching. Cells within that fiber are automatically
TMS-tagged (entries carry assumption IDs). A cell outside a speculative
fiber doesn't get tagged — speculation is meaningless without the
branching infrastructure. No per-cell speculation annotation needed;
it's inherited from the fiber context.

**`:trigger` block formalization** (for inductive stratification):

```prologos
:recurse
  :trigger
    :condition [negated-atom-unresolved]
    :witness [atom : Cell TruthValue]    ;; data produced by trigger
    :when [lfp-reached]                  ;; timing: only after stratum stabilizes
  :grows-by 1
  :halts-when [no-new-triggers]
```

The `:trigger` block has three parts: `:condition` (what pattern
triggers growth), `:witness` (what data the trigger produces for the
next stratum), and `:when` (timing constraint — typically after lfp).
This pattern is general: NAF-LE triggers on negation, WF-LE on
unfounded sets, tabling on new answer registration.

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

### 13.2 Resolved by Case Studies (Round 4)

| Gap | Resolution |
|-----|-----------|
| TracedCell provenance | §7: `:trace` with cascade scoping (stratification → fiber → cell) and 4 trace modes |
| Speculation dynamics | §7: `:speculation :atms` on `:fiber`; cells inherit TMS tagging from fiber context |
| NAF trigger formalization | §7: `:trigger` block with `:condition`, `:witness`, `:when` |
| Bridge composition | §6: `:compose` sugar with operad semantics; also A→C directly |
| `functor` for networks | §5.3: Essential for real infrastructure (0% fixed-topology) |

### 13.3 Remaining Known Unknowns

1. **Quantale morphism syntax**: `:preserves [Tensor]` captures the
   concept. The effect ordering case study confirmed it's load-bearing.
   Keyword may evolve but concept is settled.

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

5. **`functor` type checking**: `functor` networks with data-dependent
   topology need type checking rules. How does the compiler verify that
   a functor instantiation produces a well-typed network? The polynomial
   functor framework provides the theory, but the syntax for expressing
   instantiation constraints needs design.

6. **Free ⊣ Forgetful for trait derivation**: Can this adjunction be made
   first-class in the NTT? Would `impl Eq Color :derive` invoke the
   left adjoint (free construction)? How does this interact with the
   existing manual `impl` pattern?

7. **`:trace` across bridge crossings**: `:preserves [Trace]` on bridges
   means provenance chains extend across domain crossings. The α function
   carries not just the value but the derivation. Implementation details
   of cross-domain trace composition need formalization.

8. **SRE merge for coinductive types**: `:lattice :structural` on `data`
   derives merge from constructors. What does SRE merge mean for `codata`?
   Observation-based merge: two values merge if their observations merge
   pointwise? This needs formalization.

9. **SRE structural relations beyond equality** (from case studies): The
   SRE currently handles structural equality (unification). Session type
   duality requires structural *involution*. Subtyping requires structural
   *ordering*. Coercion requires structural *embedding*. Should the SRE
   be parameterized by relation type? See SRE Research Doc update.

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

## 15. Level 3b: Persistence Operations (from PM Track 10 case study)

Track 10 (Module Loading on Network) revealed two NTT gaps: the type
system had no way to express network persistence (serialization) or
network isolation (fork/structural sharing). Both are fundamental
operations for production systems.

### 15.1 `serialize` — Typed Network Persistence

Serialization snapshots a quiescent network's cell values to a persistent
format (`.pnet` files). It's a NETWORK-LEVEL operation with typed
preconditions and postconditions.

```prologos
serialize prelude-snapshot : Snapshot PreludeNet
  :format :pnet-v1
  :requires [Quiescent prelude]        ;; all propagators fired
  :requires [Ground prelude]           ;; no unsolved metas (or gensym-tagged)
  :excludes [Propagators]              ;; mechanism, not result
  :excludes [Closures]                 ;; re-link by reference
  :relinks  [ForeignProc PreparseExpander]
    :via dynamic-require               ;; (module-path . symbol) pairs
  :gensyms  :tagged                    ;; symbol$$N per-module table
  :source-hash :sha256                 ;; staleness check
```

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `:format` | `Symbol` | required | Serialization format identifier + version |
| `:requires` | `[Constraint ...]` | `[]` | Preconditions (quiescence, groundness) |
| `:excludes` | `[Category ...]` | `[Propagators]` | What's excluded from serialization |
| `:relinks` | `[Category ...]` block | `[]` | Opaque values re-linked by reference on deserialize |
| `:via` | `Symbol` | — | Re-linking mechanism (dynamic-require, namespace-lookup) |
| `:gensyms` | `Symbol` | `:tagged` | How uninterned symbols are handled |
| `:source-hash` | `Symbol` | `:sha256` | Hash algorithm for staleness check |

**Design rationale**: Serialization has CONTRACTS. A network that isn't
quiescent has partial results — serializing it would capture intermediate
state. A network with unsolved metas has non-deterministic content (which
solution does the meta represent?). These preconditions are dependent type
constraints: `Quiescent : Network → Prop` and `Ground : Network → Prop`.

The `:excludes` list is also typed: propagators are the MECHANISM (how values
were computed), cell values are the RESULT. Serializing the result without
the mechanism is correct because the mechanism has already fired. This is
the same distinction as serializing a `.class` file (compiled bytecode)
without the Java compiler.

### 15.2 `deserialize` — Typed Network Restoration

```prologos
deserialize prelude-restore : PreludeNet
  :from prelude-snapshot
  :validates [FormatVersion SourceHash]
  :fallback elaborate-from-source     ;; if .pnet stale or corrupt
  :reconstructs [Gensyms]             ;; fresh gensyms from tagged table
  :relinks [ForeignProc PreparseExpander]
    :via dynamic-require
```

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `:from` | `Snapshot T` | required | The serialized snapshot to restore |
| `:validates` | `[Check ...]` | `[]` | Validation checks before accepting |
| `:fallback` | `Fn` | error | What to do if validation fails |
| `:reconstructs` | `[Category ...]` | `[]` | What's reconstructed (not direct copy) |
| `:relinks` | block | `[]` | Same as serialize — re-link by reference |

**The fallback clause is essential**: if the `.pnet` is stale (source changed),
corrupt (half-written), or incompatible (format version mismatch), the fallback
re-elaborates from source. This is the graceful degradation that makes `.pnet`
an optimization, not a correctness dependency.

### 15.3 `fork` — Typed Network Isolation

Fork creates a structurally-shared copy of a network with copy-on-write
isolation. Reads see the parent's values; writes create child-local copies.

```prologos
fork test-context : PreludeNet -> TestNet
  :shares   [cells propagators registries]
  :resets   [worklist fuel contradiction]
  :isolation :copy-on-write
  :lifetime  :ephemeral
```

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `:shares` | `[Component ...]` | `[cells propagators]` | What's structurally shared |
| `:resets` | `[Component ...]` | `[worklist fuel contradiction]` | What's freshly initialized |
| `:isolation` | `Symbol` | `:copy-on-write` | Isolation guarantee |
| `:lifetime` | `Symbol` | `:ephemeral` | How long the fork lives |

**Fork composes transitively**: prelude → file → command → speculation.
Each layer inherits from the parent and overlays its own state.

```prologos
;; Three-layer fork for test isolation
fork test-file : PreludeNet -> FileNet
  :shares [cells propagators registries]
  :resets [worklist fuel contradiction]
  :lifetime :per-file

fork test-case : FileNet -> CaseNet
  :shares [cells propagators registries]
  :resets [worklist fuel contradiction metas constraints]
  :lifetime :ephemeral
```

**Design insight from Track 10**: The fork operation is at Level 3 (Network
Types) because it operates on networks, not cells or propagators. The
polynomial functor characterization supports this: forking a polynomial
functor `p` creates a new functor `p'` that shares `p`'s fiber but has
its own state. Writes to `p'` don't affect `p` — structural sharing via
the CHAMP's persistent data structure semantics.

### 15.4 Findings from Track 10 NTT Modeling

Modeling Track 10's architecture in NTT revealed 5 findings:

1. **Serialization and fork are Level 3 operations** — they belong alongside
   `network`, `interface`, `embed`, `connect`. They're operations ON networks,
   not within them.

2. **Serialization has dependent type preconditions** — `Quiescent` and `Ground`
   are propositions about network state. NTT's dependent types can express these
   as `:requires` constraints, making serialization type-safe.

3. **Module re-loading is non-monotone** — `stale → loading` goes backward
   in the module status lattice. NTT's `:mode monotone` on fibers flags this.
   Resolution: re-elaboration is a barrier operation (separate stratum).

4. **Import wiring is data-dependent fan-out** — the number of cells wired
   depends on the module's export count. NTT's `functor` concept handles this:
   the import-wire propagator is a functor instantiated from module metadata.

5. **Closures in cells are an optimization cache** — the NTT-typed form of a
   preparse registry entry is `(module-path × symbol)`, not a closure. The
   closure is a derived, non-serializable cache. The serialized form IS the
   NTT-correct representation.

## 16. Level 0b: Parse Domain Lattices (from PPN Track 0)

Added from PPN Track 0 design (2026-03-26). These extend Level 0 with
parse-specific lattice kinds and Level 4 with parse bridges/exchanges.

### 16.1 `:set-once` Lattice Kind

Some cells are written once and never merged. Tokens, core AST nodes,
and ground results have this property. The `:set-once` kind distinguishes
them from accumulatable (`:value`) and structural (`:structural`) cells.

### 16.1b `:embedded` Lattice Kind — The Pocket Universe Principle (D.6)

A cell whose value IS an entire lattice. The cell holds a persistent
data structure (CHAMP, PVec, Set) that is itself a lattice with its
own entries, merge, and change tracking. This is a "pocket universe" —
a complete lattice embedded inside a single cell of an outer lattice.

**Why this exists**: Some lattice domains have thousands of small
values (characters at positions, bracket depths at positions, source
locations at tokens). Creating individual propagator-network cells
for each is prohibitively expensive (~1.4 μs/cell × 4000 = 5.6 ms).
An embedded lattice stores them in one CHAMP cell (~0.01 ms) with
the same lattice semantics.

**The key property**: the embedded lattice provides a `:diff` function
that computes WHICH ENTRIES changed between the old and new value.
Dependent propagators receive the diff and fire only for affected
entries. Without `:diff`, any change re-fires all dependents. With
`:diff`, only propagators that read changed entries re-fire.

```prologos
;; A cell holding an entire character lattice (RRB persistent vector)
;; RRB chosen over CHAMP: 9× build, 3× sequential read (D.6 benchmark)
data CharacterDomain
  := char-domain [chars : PersistentVec Char]
  :lattice :embedded
  :inner   [PersistentVec Char]    ;; the embedded lattice type (RRB-backed)
  :merge   pvec-point-update       ;; merge = update specific entry
  :bot     (pvec-empty)
  :diff    pvec-structural-diff    ;; compute changed positions via path comparison

;; A cell holding bracket depths at all positions
data BracketDepthDomain
  := bracket-domain [depths : PersistentVec Int]
  :lattice :embedded
  :inner   [PersistentVec Int]
  :merge   pvec-point-update
  :bot     (pvec-empty)
  :diff    pvec-structural-diff
```

**Implementation note**: `PersistentVec` maps to our `rrb.rkt` (RRB-tree
with branching factor 32). For domains with SEQUENTIAL access (characters,
bracket depths), RRB outperforms CHAMP (3× read, 9× build). For domains
with ASSOCIATIVE access (registries, meta-info maps), CHAMP is preferred.
The `:embedded` kind works with either backing structure — the choice is
an optimization, not a semantic difference.

**Addressing in bridges**: A bridge between an `:embedded` domain and
a per-entry domain needs to address SPECIFIC ENTRIES:

```prologos
bridge CharToToken
  :from CharacterDomain
  :to   TokenValue
  :alpha char-span-to-token       ;; reads specific span from embedded
  :gamma token-to-char-context
  :addressing :positional          ;; bridge addresses entries by position
```

The `:addressing :positional` annotation says the bridge α/γ operate
on specific entries within the embedded lattice, not on the whole value.

**The Pocket Universe generalizes**: Any lattice can be embedded in a
cell. A cell holding a CHAMP of type expressions is a pocket universe
of types. A cell holding a Set of constraints is a pocket universe of
constraints. This is what our existing `parse-cell-value` (holding a
Set of derivation-nodes) already IS — a pocket universe of derivations.

The pattern: when a lattice domain has many entries with uniform
structure and set-once semantics, embed it in a CHAMP/PVec cell
instead of creating individual cells. The lattice semantics are
identical. The cost is amortized.

**Stratification connection**: A pocket universe cell can have its
OWN propagators operating within it. The outer network sees only
the cell's aggregate value. The inner propagators compute the
inner fixpoint. This is "stratification within a cell" — a fiber
operating on the entries of an embedded lattice.

```prologos
data TokenValue
  := token-bot
   | token [type : Symbol] [lexeme : String] [span : Span]
           [indent-level : Int] [indent-delta : IndentChange]
   | token-error
  :lattice :set-once
  :bot token-bot
  :top token-error
  ;; Network enforces: bot → value (one write). value → different = error.
```

The network enforces set-once semantics: writing to a cell that already
has a non-bot value is a contradiction (unless the new value is `equal?`
to the existing value — idempotent). ATMS branches for the rare case
where a cell legitimately has multiple possible values (ambiguous token).

### 16.2 Parse Derivation Lattice

```prologos
;; Surface (parse) lattice — derivation-only (lfp)
;; Track 5 adds: newtype ParseElimination := ParseElimination (Set AssumptionId)
data ParseValue
  := parse-bot
   | parse-cell [derivations : Set DerivationNode]
   | parse-error
  :lattice :value
  :bot parse-bot
  :top parse-error
  :join set-union

data DerivationNode
  := derivation-node
       [item       : ParseItem]
       [children   : List DerivationNode]   ;; provenance / trace
       [assumption : Option AssumptionId]    ;; ATMS tag
       [cost       : Rational]              ;; tropical enrichment
```

### 16.3 Demand Lattice

```prologos
data DemandValue
  := demand-bot
   | demands [set : Set Demand]
  :lattice :value
  :bot demand-bot
  :join set-union

data Demand
  := demand
       [target-domain  : Symbol]     ;; open, extensible
       [position       : Any]        ;; domain-specific
       [specificity    : Symbol]     ;; open, not enum
       [source-stratum : Symbol]
       [priority       : Int]        ;; 0 = highest (tropical)
```

### 16.4 Parse Bridges (within-stratum)

```prologos
bridge TokenToSurface
  :from TokenValue
  :to   ParseValue
  :alpha token-to-parse-scan
  :gamma parse-context-to-token-disambiguate

bridge SurfaceToCore
  :from ParseValue
  :to   TypeExpr
  :alpha parse-to-ast-construct
  :gamma core-error-to-atms-retract
  ;; D.4: backward flow is ATMS-mediated, NOT classical Galois γ.
  ;; core-error-to-atms-retract returns an assumption-id to retract,
  ;; not a lattice value to merge.

;; SurfaceToType: α only (backward via ATMS, not bridge γ)
bridge SurfaceToType
  :from ParseValue
  :to   TypeExpr
  :alpha parse-to-type-constraints
  ;; No :gamma — backward flow is ATMS assumption retraction
```

### 16.5 Parse Exchanges (cross-strata)

```prologos
;; Right Kan: elaborate demands from parse
exchange S-elaborate -> S-parse
  :right demand-from-elaboration -> targeted-parse

;; Left Kan: parse forwards partial results to elaborate
exchange S-parse -> S-elaborate
  :left  partial-parse -> early-elaboration
```

### 16.6 One-way Projection (fibration)

```prologos
;; SurfaceToNarrowing: α only, no backward flow
bridge SurfaceToNarrowing
  :from ParseValue
  :to   NarrowingRequest
  :alpha parse-to-narrowing-trigger
  ;; One-way: results flow back via TypeToSurface ATMS retraction
```

### 16.7 Parse Stratification (options)

```prologos
;; OPTION A: Separate strata (with exchanges)
stratification ParseLoop
  :strata [S-retract S-parse S-elaborate S-commit]
  :fiber S-parse
    :bridges [TokenToSurface]
  :fiber S-elaborate
    :bridges [SurfaceToCore SurfaceToType]
  :exchange S-elaborate -> S-parse
    :right demand-from-elaboration -> targeted-parse
  :exchange S-parse -> S-elaborate
    :left  partial-parse -> early-elaboration
  :barrier S-retract
    :commit retract-assumptions
  :fuel :cost-bounded

;; OPTION B: Same stratum (immediate bidirectional flow)
stratification UnifiedLoop
  :strata [S-retract S0 S-commit]
  :fiber S0
    :bridges [TokenToSurface SurfaceToCore SurfaceToType]
    ;; No exchanges needed — all domains propagate together
  :barrier S-retract
    :commit retract-assumptions
  :fuel :cost-bounded

;; Decision between A and B is Track 3-4, not Track 0.
```

---

## 17. Next Steps

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

## 18. Source Documents

| Document | Relationship |
|----------|-------------|
| [Categorical Foundations (NTT Doc 1)](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) | Provides categorical grounding for each level |
| [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) | Informs derive-not-declare principle (§9) |
| [Toplevel Forms Reference](TOPLEVEL_FORMS_REFERENCE.org) | Config language patterns and keyword conventions |
| [Master Roadmap](MASTER_ROADMAP.org) | NTT Series tracking, SRE Series tracking |
| [Unified Infrastructure Roadmap](2026-03-22_PM_UNIFIED_INFRASTRUCTURE_ROADMAP.md) | On-network / off-network boundary analysis |
| [PM Track 10 Design](2026-03-24_PM_TRACK10_DESIGN.md) | Discovered serialize/fork gaps; NTT case study §15.4 |
| [PM Track 10 Stage 2 Audit](2026-03-24_PM_TRACK10_STAGE2_AUDIT.md) | Module loading infrastructure analysis |
