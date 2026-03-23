# NTT Deep Case Study: The Type Checker

**Stage**: 1 (Case Study)
**Date**: 2026-03-22
**Purpose**: Full NTT specification of the type checker (System III).
Model every lattice, cell, propagator, bridge, and stratum. Identify
where the NTT model holds, where it breaks, and where our implementation
is still tied to imperative patterns.

**Method**: Specify the ideal architecture in NTT syntax, then annotate
each construct with its actual implementation status (network-native,
partially migrated, or imperative). The gap between ideal and actual IS
the remaining migration work.

---

## 1. Lattices

### 1.1 Type Lattice (Structural)

```prologos
data TypeExpr
  := type-bot
   | type-top
   | expr-pi [domain : TypeExpr] [codomain : TypeExpr]
   | expr-sigma [fst : TypeExpr] [snd : TypeExpr]
   | expr-app [fn : TypeExpr] [arg : TypeExpr]
   | expr-pvec [elem : TypeExpr]
   | expr-map [key : TypeExpr] [val : TypeExpr]
   | expr-set [elem : TypeExpr]
   | expr-union [members : [TypeExpr ...]]
   | expr-tycon [name : Symbol]
   | expr-meta [id : MetaId]           ;; unsolved metavariable
   | ...                                ;; 30+ more constructors
  :lattice :structural
  :bot type-bot
  :top type-top
```

**Implementation status**: PARTIALLY NETWORK-NATIVE.
- `type-lattice-merge` in `type-lattice.rkt` handles the merge
- Structural decomposition creates sub-cells via PUnify propagators
- But: merge calls `current-lattice-meta-solution-fn` (a callback) to
  follow solved metas. This callback reads from the imperative meta-info
  CHAMP, not from cells. A pure SRE-derived merge would read cell values
  directly via `net-cell-read`.
- `expr-meta` is the impedance mismatch: it's a lattice value that
  references network infrastructure (a meta ID that maps to a cell).
  In a fully network-native architecture, `expr-meta` wouldn't exist
  in cell values — the cell IS the meta.

**NTT gap: `expr-meta` in a structural lattice.** A structural lattice's
values should be structural (constructors with sub-values). `expr-meta`
is not structural — it's a reference to a cell. In the ideal architecture,
unsolved positions are `type-bot` in cells, and the cell itself represents
the meta. The distinction between "unsolved meta" and "bot-valued cell"
collapses.

### 1.2 Multiplicity Lattice (Value)

```prologos
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
```

**Implementation status**: FULLY NETWORK-NATIVE.
- `mult-lattice-merge` in `infra-cell.rkt` is a pure function
- Mult cells are propagator cells on the network
- Cross-domain bridge to type lattice via `type->mult-alpha` / `mult->type-gamma`
- No imperative state for multiplicities (Track 8 A3a tagged the CHAMP)

### 1.3 Level Lattice (Value)

```prologos
type LevelExpr := level-bot | lzero | lsuc LevelExpr | lmax LevelExpr LevelExpr | level-top

impl Lattice LevelExpr
  join [a b] [level-lattice-merge a b]
  bot -> level-bot
```

**Implementation status**: PARTIALLY NETWORK-NATIVE.
- Level metas stored in `current-level-meta-champ-box` (imperative)
- Track 8 A3b tagged with assumptions
- No bridge propagators for levels (resolved via imperative zonk)

### 1.4 Session Lattice (Structural)

```prologos
data SessionExpr
  := sess-bot
   | sess-send [payload : TypeExpr] [cont : SessionExpr]
   | sess-recv [payload : TypeExpr] [cont : SessionExpr]
   | sess-choice [branches : Map Symbol SessionExpr]
   | sess-offer [branches : Map Symbol SessionExpr]
   | sess-end
   | sess-top
  :lattice :structural
  :bot sess-bot
  :top sess-top
```

**Implementation status**: PARTIALLY NETWORK-NATIVE.
- `session-lattice-merge` handles structural decomposition
- Session propagators in `session-propagators.rkt` are network-native
- But: session metas stored in `current-sess-meta-champ-box` (imperative)
- Bridge to type lattice via `session-propagators.rkt`

### 1.5 Constraint Status Lattice (Value)

```prologos
type ConstraintStatus := cs-pending | cs-retrying | cs-resolved | cs-failed

impl Lattice ConstraintStatus
  join
    | cs-pending x   -> x        ;; any progress supersedes pending
    | x cs-pending   -> x
    | cs-retrying x  -> x        ;; resolution supersedes retry
    | x cs-retrying  -> x
    | x x            -> x        ;; idempotent
    | _ _            -> cs-failed ;; contradiction
  bot -> cs-pending
```

**Implementation status**: FULLY NETWORK-NATIVE.
- `merge-constraint-status-map` in `infra-cell.rkt`
- Constraint status is a cell on the propagator network
- Status transitions are monotone (pending → retrying → resolved)

### 1.6 Readiness Lattice (Value)

```prologos
type Readiness := not-ready | ready

impl Lattice Readiness
  join
    | not-ready x -> x
    | x not-ready -> x
    | ready ready -> ready
  bot -> not-ready
```

**Implementation status**: FULLY NETWORK-NATIVE.
- Threshold cells in the propagator network (boolean, one-shot)
- Fan-in propagators write `ready` when any dependency is non-bot
- These drive the readiness gate pattern for trait/hasmethod resolution

---

## 2. Cells

### 2.1 Per-Meta Type Cells

```prologos
;; One cell per metavariable, holding a TypeExpr value
;; SRE structural lattice — merge via structural decomposition
cell meta-type-cell : Cell TypeExpr
  :lifetime :speculative
  :tagged-by Assumption
```

**Implementation status**: NETWORK-NATIVE.
- Created by `fresh-meta` → `current-prop-fresh-meta` callback
- Written by `solve-meta!` → `net-cell-write`
- Read by propagators during S0 quiescence
- Worldview-aware reads via `elab-cell-read-worldview`

**But**: the meta-info CHAMP *duplicates* solution information. The cell
holds the type value; the CHAMP holds `meta-info` with status + solution.
In the ideal architecture, only the cell exists. "Is this meta solved?"
= "Is this cell non-bot?"

### 2.2 Infrastructure Cells

```prologos
;; Constraint store — all postponed unification constraints
cell constraint-store : Cell [Map ConstraintId Constraint]
  :lifetime :speculative
  :merge merge-hasheq-union

;; Trait constraint registry
cell trait-constraints : Cell [Map DictMetaId TraitConstraintInfo]
  :lifetime :speculative
  :merge merge-hasheq-union

;; Wakeup registry — reverse index: meta → constraints depending on it
cell trait-wakeup : Cell [Map MetaId [List DictMetaId]]
  :lifetime :speculative
  :merge merge-hasheq-list-append

;; Ready-queue — actions for S2 execution
cell ready-queue : Cell [List Action]
  :lifetime :speculative
  :merge merge-list-append

;; Error descriptors — accumulated type errors
cell error-descriptors : Cell [Map MetaId ErrorInfo]
  :lifetime :speculative
  :merge merge-hasheq-union
```

**Implementation status**: ALL NETWORK-NATIVE.
- All infrastructure cells created by `register-*-cells!`
- Merged via pure merge functions in `infra-cell.rkt`
- These are Track 7's major achievement

### 2.3 Imperative State (Not Yet Cells)

```prologos
;; These SHOULD be cells but are currently Racket parameters/boxes:

;; Meta-info CHAMP — status, solution, context, type per meta
;; SHOULD BE: per-meta cells (solution in type cell, status derived)
parameter current-prop-meta-info-box   ;; 126 unbox/set-box! sites

;; Id-map — meta-id → cell-id mapping
;; SHOULD BE: unnecessary if metas ARE cells (no indirection)
parameter current-prop-id-map-box

;; Level/mult/session meta CHAMPs
;; SHOULD BE: cells on the network (like type metas already are)
parameter current-level-meta-champ-box
parameter current-mult-meta-champ-box
parameter current-sess-meta-champ-box

;; Impl registry, trait registry, param-impl registry
;; SHOULD BE: persistent cells on the registry network
parameter current-impl-registry        ;; Track 8D partially addressed
parameter current-trait-registry
parameter current-param-impl-registry
```

**Gap analysis**: The meta-info CHAMP is the largest imperative holdout.
126 `unbox`/`set-box!` sites in `metavar-store.rkt` alone. The id-map
is pure indirection that exists because metas and cells are separate
concepts. In the ideal architecture, a meta IS a cell — no id-map needed.

---

## 3. Propagators

### 3.1 Structural Decomposition (SRE-Derived)

```prologos
;; These propagators are NOT manually declared — the SRE derives them
;; from the TypeExpr structural lattice definition.

;; When a type cell contains Pi(A, B):
;; - Create sub-cells for domain (A) and codomain (B)
;; - Install unification propagators between sub-cells and
;;   any other cells unified with this Pi

;; SRE-derived from: data TypeExpr := ... | expr-pi [domain] [codomain]
```

**Implementation status**: PARTIALLY SRE-NATIVE.
- `make-structural-unify-propagator` in `elaborator-network.rkt`
  creates decomposition propagators — this IS the SRE
- `punify-dispatch-sub` handles constructor dispatch
- `identify-sub-cell` and `get-or-create-sub-cells` manage sub-cell lifecycle
- But: dispatch is hardcoded per constructor, not derived from type defs
- The SRE form registry doesn't exist yet — dispatch is imperative case analysis

### 3.2 Type Inference Propagators

```prologos
;; Application: f applied to x
;; Creates: unify(type(f), Pi(type(x), result))
propagator app-infer
  :reads  [fn-type : Cell TypeExpr, arg-type : Cell TypeExpr]
  :writes [result-type : Cell TypeExpr]
  ;; SRE structural-relate: fn-type = Pi(arg-type, result-type)

;; Lambda: fn [x : A] body
;; Creates: result = Pi(A, type(body))
propagator lam-check
  :reads  [param-type : Cell TypeExpr, body-type : Cell TypeExpr]
  :writes [fn-type : Cell TypeExpr]
  ;; SRE structural-relate: fn-type = Pi(param-type, body-type)

;; Let: let x = e1 in e2
;; Creates: type(x) = type(e1), result = type(e2)
propagator let-infer
  :reads  [binding-type : Cell TypeExpr, body-type : Cell TypeExpr]
  :writes [result-type : Cell TypeExpr]
```

**Implementation status**: IMPERATIVE.
- `typing-core.rkt` `infer` and `check` functions manually create metas,
  install propagators, and wire cells
- Each case (app, lam, let, match, etc.) is 20-50 lines of imperative code
- In the SRE vision: each case becomes `structural-relate(cell, Form(sub-cells))`
- The elaborator would be a thin AST walker calling `structural-relate`

### 3.3 Readiness Gate Propagators

```prologos
;; Three-stage composition per trait/hasmethod constraint:

;; Stage 1: Fan-in — any dependency cell becomes non-bot
propagator fan-in-ready
  :reads  [dep1 : Cell TypeExpr, dep2 : Cell TypeExpr, ...]
  :writes [threshold : Cell Readiness]
  ;; When any dep is non-bot: write ready

;; Stage 2: Threshold — threshold triggers action enqueue
propagator threshold-enqueue
  :reads  [threshold : Cell Readiness]
  :writes [ready-queue : Cell [List Action]]
  ;; When threshold = ready: append action to queue
```

**Implementation status**: FULLY NETWORK-NATIVE.
- Created by `install-readiness-propagators` in `metavar-store.rkt`
- Threshold composition is a well-established pattern
- These fire during S0 quiescence

### 3.4 Bridge Fire Propagators

```prologos
;; Trait resolution bridge — fires in S0 when type-arg cells are ground
propagator trait-bridge
  :reads  [dep-cells : Cell TypeExpr ...]
  :writes [dict-cell : Cell TypeExpr]
  ;; Pure: read dep cell values, look up impl registry by key,
  ;; write dict solution to dict-cell

;; HasMethod resolution bridge — fires in S0
propagator hasmethod-bridge
  :reads  [type-cell : Cell TypeExpr]
  :writes [method-cell : Cell TypeExpr]
  ;; Pure: read type cell, project method from trait impl

;; Constraint retry bridge — fires in S0 when metas become ground
propagator constraint-retry-bridge
  :reads  [lhs-cell : Cell TypeExpr, rhs-cell : Cell TypeExpr]
  :writes []  ;; side effect: re-runs unification
```

**Implementation status**: PARTIALLY PURE.
- Trait and hasmethod bridges are pure fire functions (Track 8D)
- Read cells directly via `net-cell-read` — no box access
- But: constraint-retry bridge still calls imperative `retry-unify-constraint-pure`
  which reads from the meta-info CHAMP via box
- The "pure" functions still receive `pnet` and `enet-box` — the enet-box
  dependency is the remaining imperative seam

---

## 4. Network Interface

```prologos
interface TypeCheckerNet
  :inputs  [ast : ASTNode
            env : TypeEnv
            module-registry : ModuleRegistry]
  :outputs [typed-ast : TypedASTNode
            type : Cell TypeExpr
            constraints : Cell ConstraintSet
            errors : Cell ErrorSet]
```

**Implementation status**: IMPLICIT.
- No explicit interface declaration — the type checker's inputs/outputs
  are the arguments to `elaborate` and the return value of `process-command`
- The "network" is the elab-network struct + propagator network
- An NTT `interface` would make the boundary explicit and type-checkable

### 4.1 Sub-Networks

```prologos
network type-checker : TypeCheckerNet
  ;; The "master" network containing all sub-networks

  embed punify : PUnifyNet           ;; structural unification (SRE)
  embed session : SessionNet         ;; session type checking
  embed mult : MultNet               ;; multiplicity tracking
  embed readiness : ReadinessNet     ;; threshold gate composition
  embed resolution : ResolutionNet   ;; trait/hasmethod resolution

  ;; Bridges between sub-networks
  bridge TypeToMult
    :from TypeExpr
    :to   MultExpr
    :alpha type->mult-alpha
    :gamma mult->type-gamma
    :preserves [Tensor]

  bridge TypeToSession
    :from TypeExpr
    :to   SessionExpr
    :alpha type->session-alpha
    :gamma session->type-gamma
    :preserves [Trace]
```

**Implementation status**: IMPLICIT.
- Sub-networks are not explicitly composed — they share cells on the
  same propagator network
- Bridge installation happens in `driver.rkt` callbacks
- No type checking of bridge compatibility (lattice type mismatch would
  be a runtime error, not a compile-time error)

---

## 5. Stratification

```prologos
stratification TypeCheckerLoop
  :strata [S-neg1 S0 S1 S2]
  :fixpoint :lfp

  :fiber S-neg1
    :mode retraction
    :networks [retraction-net]

  :fiber S0
    :networks [type-checker]
    :bridges  [TypeToMult TypeToSession TraitResolution HasMethodResolution ConstraintRetry]

  :fiber S1
    :networks [readiness-net]

  :barrier S2 -> S-neg1
    :commit resolve-and-retract

  :exchange S0 <-> S1
    :left  partial-fixpoint -> readiness-check
    :right demand -> targeted-resolution

  :fuel 100
  :where [WellFounded TypeCheckerLoop]
```

**Implementation status**: PARTIALLY NATIVE.
- The stratified loop exists in `run-stratified-resolution-pure`
- S0 quiescence via `run-to-quiescence` is network-native
- S1 reads from the ready-queue cell (network-native)
- S2 executes resolution actions (partially pure — calls `solve-meta-core-pure`
  but still writes to the enet box)
- S(-1) is imperative (`run-retraction-stratum!` reads/writes box)
- The exchange between S0 and S1 is implicit — readiness propagators in S0
  populate the ready-queue, S1 reads it

**What's not captured by the NTT**:
- The `current-in-stratified-resolution?` guard prevents re-entrancy
  — this is an imperative control flow concern that the NTT doesn't model
- The progress check (`eq?` on enet identity) — the NTT doesn't model
  termination detection within a stratification, only across iterations
- The `solve-meta!` entry point — it's the bridge between the imperative
  elaboration world and the pure resolution loop. The NTT models the loop
  but not the entry point.

---

## 6. Speculation

```prologos
;; Speculation uses the ATMS worldview mechanism

;; Each speculative branch:
;; 1. Creates an ATMS hypothesis (assumption)
;; 2. All cell writes during the branch are tagged with the assumption
;; 3. On success: commit (promote to depth-0)
;; 4. On failure: retract (entries become invisible to worldview-aware reads)

;; In NTT terms, speculation is a TMS-tagged sub-network:
network speculative-branch : TypeCheckerNet
  :lifetime :speculative
  :tagged-by [assumption-id]

;; The worldview is the speculation stack:
;; Entries from sibling branches are invisible
;; Entries from parent branches are visible
;; Entries from own branch are visible
```

**Implementation status**: NETWORK-NATIVE (Track 8 B1).
- `with-speculative-rollback` creates ATMS hypotheses
- Cell writes are tagged via `current-speculation-assumption`
- Worldview-aware reads (`worldview-visible?`) filter by stack
- `restore-meta-state!` is RETIRED — worldview filtering replaces it
- Retraction (S(-1)) is deferred GC, not correctness mechanism

**NTT modeling challenge**: Speculation is not a static network
declaration — it's a dynamic mechanism that creates sub-worldviews at
runtime. The NTT can describe the STRUCTURE (tagged cells, worldview
filtering) but not the DYNAMICS (when speculation starts/ends, which
branches are tried). This may need a `speculation` form or a compositional
mechanism for worldview scoping.

---

## 7. Imperative → Network-Native Migration Map

### 7.1 What's Already Network-Native

| Component | Mechanism | Track |
|-----------|-----------|-------|
| Per-meta type cells | Propagator cells | Track 7 |
| Infrastructure cells (9 types) | Cells with typed merge | Track 7 |
| Readiness gates | Threshold propagators | Track 7 |
| Worldview-aware reads | TMS tagging + stack filter | Track 8 B1 |
| Trait/hasmethod bridge fire | Pure (pnet → pnet) | Track 8 D |
| Speculation commit/retract | ATMS hypothesis management | Track 8 B1 |
| Constraint status tracking | Monotone status cell | Track 7 |
| Error descriptors | Accumulation cell | Track 7 |

### 7.2 What's Still Imperative

| Component | Current State | Ideal NTT State | Blocker |
|-----------|--------------|-----------------|---------|
| Meta-info CHAMP | Box (126 sites) | Per-meta cells | PM Track 8F |
| Id-map | Box (CHAMP) | Eliminated (meta IS cell) | PM Track 10 |
| Level/mult/sess meta CHAMPs | Boxes | Per-domain cells | PM Track 8E |
| Impl/trait/param-impl registries | Parameters | Persistent cells | PM Track 8E |
| S(-1) retraction | Imperative loop | Pure GC pass | PM Track 8E |
| solve-meta! entry point | Box read/write wrapper | Network event | PM Track 10 |
| Constraint retry bridge | Calls imperative zonk | Cell-native reads | PM Track 8F |
| Module loading | Parameters (no network) | Network-first init | PM Track 10 |

### 7.3 The expr-meta Problem

The deepest impedance mismatch: `expr-meta id` appears as a value in
type cells. But in the ideal architecture, unsolved metas don't exist
as values — an unsolved position is a `type-bot` cell. The cell IS the
meta.

Current: `Cell contains: expr-pi (expr-meta ?A) (expr-meta ?B)`
Ideal: `Cell contains: expr-pi, with sub-cells A (bot) and B (bot)`

The SRE resolves this: structural decomposition creates sub-cells for
Pi's domain and codomain. The sub-cells start at `type-bot` (unsolved).
When information arrives, the sub-cells' values grow in the lattice.
No `expr-meta` wrapper needed — the cell's bot/non-bot state IS the
solved/unsolved distinction.

**Migration path**: This is the convergence point of SRE + PM Track 10.
When the SRE is the elaborator's structural reasoning mechanism AND
meta-info is eliminated (metas ARE cells), `expr-meta` disappears from
the type lattice. TypeExpr's constructors are purely structural.

---

## 8. Zonk: The Imperative-Network Bridge

Zonk is the function that substitutes solved meta solutions into
expressions. In the current architecture:

```
zonk(expr-meta id) =
  lookup meta-info[id] → if solved, zonk(solution)
                       → if unsolved, return expr-meta id
```

**Why zonk exists**: Because `expr-meta` values in cells don't
automatically update when the meta is solved. The meta IS the value
(not a cell reference), so solving the meta doesn't change existing
cells that contain `expr-meta id`. Zonk walks the expression tree
and substitutes.

**In the ideal architecture**: Zonk is unnecessary during elaboration.
If metas are cells (not values), solving a meta means writing to the
cell. Propagators watching that cell automatically fire and update
dependent cells. No explicit tree walk needed.

**Zonk survives as "freeze"**: At command boundaries, the propagator
network must produce a ground expression for storage in the global env.
This "freeze" operation reads all cell values and constructs a concrete
expression. It's a single-pass read, not a recursive substitution —
and it's O(output size), not O(expression tree × meta count).

**NTT modeling**: Zonk has no NTT analog. It's an artifact of the
imperative-network boundary. In a fully network-native architecture,
there's no zonk — just propagation during elaboration and freeze at
boundaries.

---

## 9. What the Case Study Reveals

### 9.1 NTT Syntax Validates Well

The type checker's architecture maps cleanly to NTT forms:
- TypeExpr as `:lattice :structural` ✓
- MultExpr as value lattice with `impl Quantale` ✓
- Infrastructure cells with typed merges ✓
- Readiness gate propagators ✓
- Bridge declarations with `:preserves` ✓
- Stratification with 4 strata + exchange ✓

### 9.2 NTT Reveals Imperative Debt

Modeling in NTT makes the imperative holdouts explicit:
- meta-info CHAMP (should be cells)
- id-map (should be eliminated)
- solve-meta! entry point (should be a network event)
- zonk (should be unnecessary during elaboration)
- S(-1) retraction (should be pure)

These aren't new findings — they're documented in the Unified
Infrastructure Roadmap. But the NTT specification makes them
structurally visible as places where the model breaks.

### 9.3 The expr-meta Problem is the Deepest Gap

`expr-meta` as a lattice value is the fundamental impedance mismatch.
It conflates "a value in the type lattice" with "a reference to network
infrastructure." The SRE's structural lattice concept resolves this by
making sub-cells explicit — but only when `:lattice :structural` types
don't contain self-referential network pointers (meta IDs).

Eliminating `expr-meta` from TypeExpr is the architectural endpoint of
the PM series. Everything else (meta-info cells, id-map elimination,
zonk removal) follows from it.

### 9.4 Speculation Needs NTT Extension

The NTT can describe tagged cells and worldview filtering, but not the
dynamics of speculation (when branches start/end, how they compose,
what triggers commit/retract). This is a genuine design gap — we may
need a `speculation` form or integrate speculation semantics into
`stratification`.

### 9.5 The SRE is More Central Than Expected

The case study confirms: the SRE is not just "structural decomposition."
It's the mechanism by which:
- Type lattice merge works (structural decomposition IS unification)
- The elaborator installs type constraints (structural-relate, not manual propagators)
- Metas become cells (SRE sub-cells replace expr-meta values)
- Zonk disappears (propagation replaces substitution)

The SRE is the bridge between the current architecture and the ideal
network-native architecture.

---

## 10. Source Documents

| Document | Relationship |
|----------|-------------|
| [NTT Syntax Design](../tracking/2026-03-22_NTT_SYNTAX_DESIGN.md) | Syntax being validated |
| [Architecture Survey](2026-03-22_NTT_ARCHITECTURE_SURVEY.md) | Breadth-first survey |
| [Unified Infrastructure Roadmap](../tracking/2026-03-22_PM_UNIFIED_INFRASTRUCTURE_ROADMAP.md) | Migration plan |
| [SRE Research](2026-03-22_STRUCTURAL_REASONING_ENGINE.md) | SRE as universal primitive |
| [Categorical Foundations](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) | Categorical grounding |
