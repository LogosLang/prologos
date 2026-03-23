# NTT Architecture Survey: Propagator Systems as Network Types

**Stage**: 1 (Case Study)
**Date**: 2026-03-22
**Purpose**: Model all seven propagator systems as NTT declarations.
Breadth-first survey to reveal common patterns, shared infrastructure,
interaction points, and syntax gaps.

**Method**: Each system gets a skeleton: `stratification`, `interface`,
key `bridge` declarations, `exchange` if applicable. Critical notes on
what fits vs. what doesn't fit the NTT syntax.

---

## 1. Type Checker (System III)

The central system. All other systems are bridges or sub-networks of this.

### Lattice

```prologos
;; Already exists as type-lattice-merge in type-lattice.rkt
;; Structural: unification-based ordering with subtyping
impl Lattice TypeExpr
  join [a b] [type-lattice-merge a b]   ;; unification + subtype closure
  bot -> type-bot                        ;; no information (fresh meta)

impl BoundedLattice TypeExpr
  top -> type-top                        ;; contradiction
```

**Observation**: This is not a simple flat or chain lattice. The join is
*unification* — a complex operation that decomposes structure, creates
sub-cells, and may fail (→ top). Can `trait Lattice` express this? The
join function calls into PUnify's structural decomposition machinery.
This means the lattice merge IS a propagator network operation, not a
pure function. **Gap**: `impl Lattice` assumes `join` is a pure function
`L L -> L`. But `type-lattice-merge` creates cells and installs
propagators as a side effect. This is a fundamental tension.

### Interface

```prologos
interface TypeCheckerNet
  :inputs  [expr : Cell ASTNode]
  :outputs [type-cell : Cell TypeExpr
            mult-cell : Cell MultExpr
            constraints : Cell ConstraintSet]
```

### Stratification

```prologos
stratification TypeCheckerLoop
  :strata [S-neg1 S0 S1 S2]
  :scheduler :gauss-seidel
  :fiber S0
    :bridges [TypeToMult TypeToSession EffectToMult]
    :networks [type-net punify-net]
  :fiber S1
    :networks [readiness-net]
  :barrier S2 -> S-neg1
    :commit resolve-and-retract
  :fuel 100
  :where [WellFounded TypeCheckerLoop]
```

### Bridges

```prologos
bridge TypeToMult
  :from TypeExpr
  :to   MultExpr
  :alpha type->mult-alpha     ;; extract multiplicity from Pi binder
  :gamma mult->type-gamma     ;; inject mult back into type context
  :preserves [Tensor]         ;; quantale morphism

bridge TypeToSession
  :from TypeExpr
  :to   SessionExpr
  :alpha type->session-alpha  ;; extract protocol from channel type
  :gamma session->type-gamma  ;; inject session constraints back
  :preserves [Trace]          ;; traced monoidal (recursion)
```

---

## 2. PUnify (Structural Unification)

Not a separate system — it's the SRE operating within System III's S0.

### Lattice

Same as Type Checker (TypeExpr). PUnify doesn't have its own lattice;
it's the structural decomposition mechanism ON the type lattice.

### Interface

```prologos
;; PUnify is not a network — it's a propagator factory
;; It creates propagators on the type network when called
;; This is interesting: it's a HIGHER-ORDER network operation
```

**Observation**: PUnify doesn't fit `network` or `interface`. It's a
*propagator factory* — given two cells, it creates structural decomposition
propagators between them. This is a **higher-order network operation**:
a function from (cell, cell) to network-with-new-propagators. The NTT
doesn't have syntax for this yet.

**Gap**: We need a way to express "a function that, given cells, installs
propagators on a network." This is the `functor` concept applied to
propagators — a parameterized propagator template that instantiates
into concrete propagators when given cell arguments.

### Key Propagators

```prologos
;; Structural decomposition — derived from type constructors
;; Pi: read cell, if Pi(A,B), create sub-cells for A and B
;; Sigma: same pattern
;; App: same pattern
;; These are exactly what SRE derives from type definitions
```

---

## 3. NF-Narrowing

### Lattice

```prologos
;; 4-element term lattice (NOT the type lattice)
type TermValue
  := term-bot                         ;; no info (fresh variable)
   | term-var [id : Symbol]           ;; unbound logic variable
   | term-ctor [tag : Symbol]         ;; constructor (sub-cells separate)
               [sub-cells : [CellId]] ;; references to child cells
   | term-top                         ;; contradiction

impl Lattice TermValue
  join
    | term-bot x        -> x
    | x term-bot        -> x
    | [term-var _] x    -> x          ;; variable binds to anything
    | x [term-var _]    -> x
    | [term-ctor t1 _] [term-ctor t2 _]
      | [eq? t1 t2]    -> ...         ;; same ctor: unify sub-cells
      | _               -> term-top   ;; different ctors: contradiction
    | _ _               -> term-top
  bot -> term-bot
```

**Observation**: The `term-ctor` case's join involves sub-cell unification
— same issue as the type lattice. Join creates side effects (sub-cell
propagators). Also, `term-ctor` carries `[CellId]` which is a reference
to network infrastructure — the lattice value contains network pointers.
**Gap**: Same as System III — lattice merge isn't a pure function.

### Interface

```prologos
interface NarrowingNet
  :inputs  [goal : Cell TermValue
            definitions : Cell DefTree]  ;; definitional tree registry
  :outputs [result : Cell TermValue]
```

### Key Propagators

```prologos
;; Branch propagator: watches a cell, dispatches on constructor tag
propagator narrow-branch
  :reads  [scrutinee : Cell TermValue]
  :writes [result : Cell TermValue]
  ;; When scrutinee becomes term-ctor, match against definitional tree
  ;; branches. Install sub-propagators for matching branch.
  ;; If multiple branches match: create ATMS amb choices.

;; Rule propagator: all pattern bindings ground → evaluate RHS
propagator narrow-rule
  :reads  [bindings : Cell TermValue ...]  ;; one per pattern var
  :writes [result : Cell TermValue]
  ;; When all bindings are ground, evaluate rule body → write result

;; Residuation: if scrutinee is bot/var, do nothing (wait for info)
;; This is demand-driven — propagators only fire when they have enough
```

**Observation**: The branch propagator is a *dynamic propagator installer*
— when it fires, it creates new propagators. Same higher-order pattern
as PUnify. The NTT `propagator` form describes a static propagator with
fixed reads/writes. Dynamic installation needs the factory/template
concept.

### Stratification

```prologos
;; NF-Narrowing doesn't have explicit strata in our implementation.
;; It operates within S0 of the type checker's stratification.
;; But conceptually it has demand-driven evaluation order:
;; outer goals trigger inner narrowing (Right Kan).

stratification NarrowingEval
  :fixpoint :lfp
  :fiber S0
    :networks [narrowing-net]
  ;; No barriers — narrowing is monotone
  ;; Demand-driven activation (Right Kan) is implicit in
  ;; propagator dependency: branch prop only fires when
  ;; scrutinee cell has info
  :fuel 100
```

**Observation**: Narrowing is embedded in S0, not its own stratification.
The NTT should support *embedded sub-networks* that don't have their own
stratification but participate in a parent's. This is already what
`embed` does in `network`. Good.

### Bridge to Type Checker

```prologos
bridge NarrowingToType
  :from TermValue
  :to   TypeExpr
  :alpha term->type    ;; extract type info from narrowing result
  ;; One-way: narrowing results inform type inference
  ;; No gamma — type info doesn't flow back into narrowing
```

---

## 4. NAF-LE (Negation-as-Failure Logic Engine)

### Lattice

```prologos
;; Truth value lattice for logic programming
type TruthValue := tv-bot | tv-true | tv-false | tv-top

impl Lattice TruthValue
  join
    | tv-bot x -> x
    | x tv-bot -> x
    | x x      -> x        ;; same value
    | _ _      -> tv-top   ;; contradiction
  bot -> tv-bot
```

### Interface

```prologos
interface NAFNet
  :inputs  [query : Cell TermValue
            facts : Cell FactDB
            rules : Cell RuleDB]
  :outputs [answer : Cell TruthValue
            bindings : Cell SubstitutionSet]
```

### Stratification

```prologos
stratification NAFSolver
  :fixpoint :stratified
  :base S0
    :networks [fact-net rule-net]
    :bridges [TermToTruth]
  :recurse
    :trigger negation-as-failure
    :halts-when [fixpoint]
  :fuel 50
  :where [WellFounded NAFSolver]
```

**Observation**: This is the cleanest fit for inductive stratification.
The `:recurse :trigger` pattern maps directly to NAF's semantics.

### Key Propagators

```prologos
;; SLD resolution: match goal against rule heads
propagator sld-resolve
  :reads  [goal : Cell TermValue] [rules : Cell RuleDB]
  :writes [subgoals : Cell TermValue ...] [bindings : Cell Substitution]

;; NAF check: negation-as-failure trigger
propagator naf-check
  :reads  [negated-goal : Cell TruthValue]
  :writes [result : Cell TruthValue]
  :non-monotone  ;; NAF is inherently non-monotone!
  ;; If negated-goal = tv-bot after lfp: result = tv-true (closed-world)
  ;; If negated-goal = tv-true: result = tv-false
```

**Observation**: `naf-check` is `:non-monotone` — it reads the ABSENCE
of information (tv-bot after fixpoint) and draws a conclusion. This is
the stratum transition: the non-monotone step happens between iterations
of the inductive stratification. The NTT handles this via `:recurse`
with the trigger being exactly this non-monotone step.

---

## 5. WF-LE (Well-Founded Logic Engine)

### Lattice

```prologos
;; Bilattice: two orderings on same carrier
;; Knowledge ordering: how much we know
;; Truth ordering: what we know
type BilatticeValue := bl-bot | bl-true | bl-false | bl-unknown | bl-top

impl Lattice BilatticeValue
  :ordering :knowledge       ;; which ordering is this impl for?
  join [a b] [knowledge-join a b]
  bot -> bl-bot

;; Second impl for truth ordering?
;; GAP: NTT doesn't currently support multiple lattice orderings
;; on the same carrier type. A bilattice IS two lattices on one set.
```

**Gap**: A bilattice has TWO orderings on the same carrier. The NTT
`trait Lattice` gives one ordering per type. To express a bilattice, we'd
need either:
- Two wrapper types: `Knowledge BilatticeValue` and `Truth BilatticeValue`
- A parameterized lattice: `impl Lattice (Ordered BilatticeValue :knowledge)`
- A new `bilattice` form that declares both orderings

This is a real gap. Bilattices are fundamental to WF-LE and AFT.

### Stratification

```prologos
stratification WFSolver
  :fixpoint :approximation
  :bilattice [knowledge truth]
  :stable-operator wf-stable
  :fuel 100
  :where [WellFounded WFSolver]
```

**Observation**: The `:bilattice` keyword was speculative — now we see it's
load-bearing. The WF-LE solver needs both orderings declared to verify
the AFT stable operator's correctness.

---

## 6. Session Types

### Lattice

```prologos
type SessionExpr
  := sess-bot
   | sess-send [payload : TypeExpr] [cont : SessionExpr]
   | sess-recv [payload : TypeExpr] [cont : SessionExpr]
   | sess-choice [branches : Map Symbol SessionExpr]
   | sess-offer [branches : Map Symbol SessionExpr]
   | sess-end
   | sess-top

impl Lattice SessionExpr
  join [a b] [session-lattice-merge a b]  ;; unification-based
  bot -> sess-bot
```

**Observation**: Same structural merge pattern as type lattice — join
decomposes session expressions into sub-cells. Third instance of
"lattice merge creates propagators." This is a pattern, not an exception.

### Interface

```prologos
interface SessionNet
  :inputs  [channel-type : Cell TypeExpr]
  :outputs [protocol : Cell SessionExpr
            dual : Cell SessionExpr
            ops-trace : Cell SessionOpTrace]
```

### Key Propagators

```prologos
;; Decomposition: session value → sub-cells
propagator session-decompose
  :reads  [session : Cell SessionExpr]
  :writes [payload : Cell TypeExpr] [cont : Cell SessionExpr]
  ;; When session becomes sess-send(A, S'), create sub-cells

;; Duality: check that client and server protocols are dual
propagator session-dual-check
  :reads  [client : Cell SessionExpr] [server : Cell SessionExpr]
  :writes []  ;; writes contradiction if not dual
```

### Bridge

```prologos
bridge TypeToSession
  :from TypeExpr
  :to   SessionExpr
  :alpha type->session-alpha
  :gamma session->type-gamma
  :preserves [Trace]         ;; traced monoidal (recursion via μ)
```

---

## 7. QTT (Multiplicity Tracking)

### Lattice

```prologos
;; Flat 4-element lattice (simplest of all systems)
type MultExpr := mult-bot | m0 | m1 | mw | mult-top

impl Lattice MultExpr
  join
    | mult-bot x -> x
    | x mult-bot -> x
    | x x        -> x
    | _ _        -> mult-top   ;; incompatible multiplicities
  bot -> mult-bot

impl Quantale MultExpr
  tensor [a b] [mult-times a b]  ;; m1·m1=m1, m1·mw=mw, m0·x=m0
```

**Observation**: QTT IS a quantale — the multiplication operation
(`mult-times`) distributes over join. The `:preserves [Tensor]` on the
TypeToMult bridge captures exactly this: the bridge preserves the
quantale structure.

### Interface

```prologos
interface MultNet
  :inputs  [type-cell : Cell TypeExpr]
  :outputs [mult-cell : Cell MultExpr]
```

### Bridge

```prologos
bridge TypeToMult
  :from TypeExpr
  :to   MultExpr
  :alpha type->mult-alpha
  :gamma mult->type-gamma
  :preserves [Tensor]
```

---

## Cross-Cutting Patterns

### Pattern 1: Structural Merge Creates Propagators

Three lattices (TypeExpr, TermValue, SessionExpr) have join operations
that create sub-cells and install propagators. This is NOT a pure
function `L L -> L`. It's a network operation: `L L Network -> (L, Network)`.

**Impact on NTT**: The `trait Lattice` with `spec join L L -> L` is
insufficient for these lattices. Options:
1. **`trait NetworkLattice`**: join takes a network context, returns
   modified network. `spec join L L Network -> [L Network]`
2. **SRE-native merge**: The SRE handles structural decomposition
   automatically from type definitions. Lattice merge for structural
   types IS structural decomposition — it should be derived, not
   declared. The `impl Lattice` for TypeExpr would simply say "use SRE
   structural merge" and the SRE handles cell creation.
3. **Propagator-as-merge**: The merge function IS a propagator. When two
   cells need to be merged, the network installs a merge propagator
   (which is a structural decomposition propagator).

Option 2 is most aligned with derive-not-declare. The SRE already knows
how to decompose Pi, Sigma, etc. The lattice merge for these types is
"call the SRE" — which is what `type-lattice-merge` already does.

### Pattern 2: Dynamic Propagator Installation (Higher-Order Networks)

PUnify, NF-Narrowing's branch propagators, and session decomposition
all dynamically install propagators when they fire. The NTT `propagator`
form assumes static reads/writes. We need a way to express "this
propagator, when it fires, may install new propagators."

**Proposed**: A `:dynamic` flag or a `propagator-factory` concept:

```prologos
;; A propagator that may install sub-propagators
propagator narrow-branch
  :reads  [scrutinee : Cell TermValue]
  :writes [result : Cell TermValue]
  :dynamic   ;; may install sub-propagators when fired
```

Or more precisely, a propagator template:

```prologos
;; A template that instantiates propagators given cells
propagator-template structural-unify
  :params [a : Cell TypeExpr, b : Cell TypeExpr]
  :installs [decomposition propagators based on cell values]
```

This needs more thought. It's the "Curry ⊣ Eval" adjunction from the
extended catalog — higher-order propagators that take network templates
as arguments.

### Pattern 3: Embedded Sub-Networks

NF-Narrowing operates within the type checker's S0. It's not an
independent stratification — it's an embedded sub-network. The NTT
handles this via `embed` in `network` and `:networks` in `:fiber`.
This pattern works.

### Pattern 4: One-Way Bridges

NarrowingToType is one-way (narrowing → type, no reverse). TypeToMult
and TypeToSession are bidirectional. The one-way/bidirectional
distinction is captured by having/missing `:gamma`. Works.

### Pattern 5: Non-Monotone Steps as Stratum Transitions

NAF's non-monotone `naf-check` lives at the stratum boundary, not within
a monotone stratum. The NTT captures this with `:non-monotone` on the
propagator and `:barrier` on the stratification. Works.

### Pattern 6: Bilattice as Two Orderings

WF-LE's bilattice needs two orderings on the same carrier. Current NTT
doesn't handle this. Needs either wrapper types, parameterized orderings,
or a `bilattice` form. This is a **real gap** requiring design work.

---

## Gaps Identified

| Gap | Severity | Systems Affected | Proposed Resolution |
|-----|----------|-----------------|-------------------|
| Structural merge creates propagators | HIGH | TypeExpr, TermValue, SessionExpr | SRE-native merge (derive from type defs) |
| Dynamic propagator installation | HIGH | PUnify, NF-Narrowing, Sessions | `:dynamic` flag or `propagator-template` |
| Bilattice (two orderings on one carrier) | MEDIUM | WF-LE | `bilattice` form or parameterized ordering |
| Higher-order network operations | MEDIUM | PUnify (factory pattern) | `propagator-template` or `functor` over networks |
| Persistent vs speculative networks | LOW | All (registry vs elaboration) | `:persistent` flag on `network` |

---

## Common Infrastructure

```prologos
;; Shared lattices (used by multiple systems)
;; TypeExpr — Systems 1, 2, 6 (type, PUnify, sessions)
;; MultExpr — System 7 (QTT)
;; TermValue — Systems 3, 4 (narrowing, NAF)
;; TruthValue — Systems 4, 5 (NAF, WF-LE)
;; SessionExpr — System 6

;; Shared bridges
;; TypeToMult — connects type checker to QTT
;; TypeToSession — connects type checker to session checker
;; NarrowingToType — connects narrowing results to type inference

;; Shared stratification (the "master" loop)
stratification ElabLoop
  :strata [S-neg1 S0 S1 S2]
  :fiber S0
    :networks [type-net punify-net narrowing-net session-net mult-net]
    :bridges  [TypeToMult TypeToSession NarrowingToType]
  :exchange S0 <-> S1
    :left  partial-fixpoint -> readiness-check
    :right demand -> targeted-resolution
  :barrier S2 -> S-neg1
    :commit resolve-and-retract
  :fuel 100
```

**Key insight**: Most systems are sub-networks embedded in S0 of one
master stratification. The `ElabLoop` above is the actual architecture
— everything operates in S0, connected by bridges. NAF-LE and WF-LE
have their OWN stratifications (inductive and approximation respectively)
that are invoked as sub-computations from within the logic engine.

---

## Source Documents

| Document | Relationship |
|----------|-------------|
| [NTT Syntax Design](../tracking/2026-03-22_NTT_SYNTAX_DESIGN.md) | Syntax being validated |
| [Categorical Foundations](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) | Categorical grounding |
| [SRE Research](2026-03-22_STRUCTURAL_REASONING_ENGINE.md) | Structural decomposition |
| [Unified Infrastructure Roadmap](../tracking/2026-03-22_PM_UNIFIED_INFRASTRUCTURE_ROADMAP.md) | On-network boundary |
