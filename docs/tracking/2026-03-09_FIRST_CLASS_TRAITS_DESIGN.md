# First-Class Traits on the Propagator Network: Design Phases 2-3

Created: 2026-03-09
Source: Standup design discussion + codebase analysis

---

## 1. Executive Summary

Prologos traits are currently **first-class as types but not as computational entities**. `Eq Nat` is a type (inhabited by dictionaries), but `Eq` itself — the mapping from type to method signature — lives in Racket-side registries, invisible to the runtime. Trait dispatch is a compile-time pattern match against the impl registry, disconnected from the propagator network.

This document proposes **reifying trait dispatch as propagator cells**: finite-domain lattice elements that narrow monotonically as type information flows in, enabling bidirectional type-dispatch information flow. The primary near-term benefit is **narrowing through trait-dispatched operators** (Phase 2d of Surface Ergonomics), but the architecture enables a broader set of capabilities: conditional propagator activation, type-directed search, trait composition as constraint programming, and runtime trait introspection.

The key insight: **the impl registry is already a finite domain**. Each trait has a fixed set of registered implementations. A "trait-dispatch cell" starts at the full set and narrows as type constraints eliminate candidates — this is the same monotonic refinement pattern as every other propagator cell in the system.

---

## 2. Current Architecture

### 2.1 The Dictionary-Passing Transform

Traits in Prologos follow the GHC dictionary-passing model:

```
trait Eq {A}               →  deftype (Eq A) (A A -> Bool)
  eq? : A A -> Bool           Eq-eq? : {A :0 Type} -> Eq A -> A A -> Bool

impl Eq Nat                →  Nat--Eq--dict : Eq Nat := nat-eq
  defn eq? [...] [nat-eq ...]   (single-method: dict IS the function)

where (Eq A) in spec       →  Pi ($Eq-A :w (Eq A)) -> ...
  eq? x y in body             (Eq-eq? A $Eq-A x y)
```

**Key files and entry points:**
- Trait declaration: `process-trait` (macros.rkt:6222)
- Monomorphic impl: `process-monomorphic-impl` (macros.rkt:7000)
- Parametric impl: `process-parametric-impl` (macros.rkt:7082)
- Dict param detection: `is-dict-param-name?` (elaborator.rkt:116)
- Method resolution: `resolve-method-from-where` (elaborator.rkt:158)
- Trait resolution: `resolve-trait-constraints!` (trait-resolution.rkt:305)

### 2.2 Trait Constraint Tracking

The metavar store maintains three maps connecting traits to the propagator substrate:

| Map | Key → Value | Purpose |
|-----|-------------|---------|
| `current-trait-constraint-map` | dict-meta-id → `trait-constraint-info` | Links dict metavariable to its trait + type args |
| `current-trait-wakeup-map` | type-arg-meta-id → `(listof dict-meta-id)` | Reverse index: when a type arg solves, retry dependent constraints |
| `current-trait-cell-map` | dict-meta-id → `(listof cell-id)` | P3a: propagator cell IDs for cell-state-driven resolution |

**Current flow:**
1. Elaborator creates implicit dict param → allocates metavariable
2. Registers `trait-constraint-info` in constraint map
3. Builds wakeup index from type-arg metas
4. Type inference solves type-arg metas (via propagator network)
5. `resolve-trait-constraints!` walks constraint map post-inference
6. For each ground constraint: look up impl registry → solve dict meta

**The gap:** Steps 1-3 connect to the propagator network (via cell IDs). Step 4 IS the propagator network. But step 5 is a **batch post-processing pass** — not a propagator. The trait resolution doesn't feed information back into the network. It's unidirectional: types → dispatch. Never dispatch → types.

### 2.3 The Generic Operator Pipeline

Built-in numeric operators (`+`, `-`, `*`, `/`) follow a **separate path** from trait dispatch:

```
WS: .{a + b}
  → Reader: ($mixfix a + b)
  → Pratt parser: (+ a b)
  → Parser: surf-generic-add(a, b)                   [parser.rkt:1709]
  → Elaborator: expr-generic-add(ea, eb)              [elaborator.rkt:1184]
  → Type checker: numeric-join/warn!(ta, tb)          [typing-core.rkt:779]
  → Reduction: pattern-match on (expr-int a) etc.     [reduction.rkt:1313]
```

**Critical observation:** Generic operators never touch the trait system. They are typed via `numeric-join/warn!` and dispatched via pattern matching in reduction rules. The `Add`, `Sub`, `Mul` traits exist for user-defined dispatch (via `where (Add A)`) but are orthogonal to the built-in operator pipeline.

This means **narrowing through mixfix operators fails** because:
1. The narrowing engine (`run-narrowing`, reduction.rkt:209) extracts `func-name` from `expr-fvar` or `expr-app` chains
2. `expr-generic-add` is neither — it's a special operator node
3. Pattern match returns `#f` → narrowing returns empty solutions

### 2.4 Bundle Composition

Bundles (`bundle Num := (Add Sub Mul Neg Eq Ord Abs FromInt)`) are **purely syntactic sugar**. They expand to multiple independent constraints at the call site. No runtime entity represents a bundle — it's conjunctive constraint shorthand.

The bundle model is correct and should be preserved: bundles are conjunctions of constraints (logical AND), not subtypes (IS-A). This compositional approach avoids the diamond problem, method resolution order, and linearization issues of inheritance hierarchies.

---

## 3. Design Space: Three Levels of First-Class Traits

### Level 1: Traits as Type Constructors (Low Cost, Moderate Benefit)

**What it means:** Allow trait names to appear as values of kind `Type → Type`.

```prologos
def my-eq : Type -> Type := Eq
;; my-eq Nat  ~  Eq Nat  ~  (Nat Nat -> Bool)
```

**Status:** Almost achievable today. Traits generate `deftype` declarations, and `expr-tycon` already handles type constructors like `PVec`, `Map`. Extending the type constructor table to include trait names would make `Eq` usable as a type-level function.

**Limitation:** You can abstract over **which trait** at the type level, but can't project methods from an unknown trait. Given `F : Type → Type` and `dict : F A`, you can't call `eq?` on `dict` because you don't know `F` has a method named `eq?`.

**Use cases:** Type-level programming, generic test harnesses, documentation generation.

### Level 2: Trait Dispatch as Propagator Cells (Medium Cost, High Benefit)

**What it means:** Model trait resolution as a finite-domain propagator cell in the network. The cell starts with all registered impls and narrows monotonically as type constraints eliminate candidates.

```
trait-dispatch-cell for Add:
  Domain: {Add Nat, Add Int, Add Rat, Add Posit8, ..., Add String}
  bot:    all impls possible (unconstrained)
  top:    no impl satisfies constraints (contradiction)
  join:   set intersection (add constraint → fewer candidates)
```

**This is the core proposal of this document.** It unifies trait resolution with the propagator network, enabling:
- **Bidirectional information flow:** type → dispatch (existing), dispatch → type (new)
- **Narrowing through trait-dispatched operators** (Phase 2d)
- **Conditional propagator activation** (dispatch cell resolves → install concrete propagators)
- **Type-directed search** (enumerate impls as branching points for ATMS)

### Level 3: Traits as First-Class Propositions (High Cost, Theoretical Benefit)

**What it means:** Full Curry-Howard reification. `Eq A` is a proposition ("A has decidable equality"). The dictionary is a proof. First-class traits means first-class propositions — quantifying over **which property** is satisfied.

```prologos
spec parametric-over-property :
  {P : Type -> Type} -> {A : Type} -> P A -> A -> Bool
```

**Limitation:** Without knowing `P`'s structure, you can't project methods from `P A`. This requires either:
- **Row polymorphism:** `{ eq? : A A -> Bool | r }` — structural method access
- **A universe of traits:** Reify trait structure as data for type-level computation
- **HasMethod constraints:** `where (HasMethod P "eq?" (A -> A -> Bool))` — trait-level row types

**Assessment:** Elegant but requires significant type system extensions. The ROI is unclear for current use cases. Defer to Phase 4+.

### Recommendation

**Implement Level 2** as the primary effort. It gives the most immediate benefit (narrowing through mixfix, which is Issue 5 of the Surface Ergonomics sprint) while establishing the foundation for Level 3 if needed later. Level 1 can be done opportunistically as a small addendum.

---

## 4. Core Design: Trait-Dispatch Propagator Cell

### 4.1 The Dispatch Lattice

A new lattice type: `dispatch-lattice.rkt`.

```
dispatch-bot   = all impls (unconstrained)
dispatch-set S = subset of impls (partially constrained)
dispatch-one e = single impl (fully resolved)
dispatch-top   = no valid impl (contradiction)
```

**Merge (join) semantics:** Set intersection. Adding a constraint reduces the candidate set.

```
dispatch-bot ⊔ dispatch-set S = dispatch-set S
dispatch-set S1 ⊔ dispatch-set S2 = dispatch-set (S1 ∩ S2)
dispatch-set {e} = dispatch-one e   (singleton optimization)
dispatch-set {} = dispatch-top       (empty = contradiction)
```

**Monotonicity:** The candidate set only shrinks (intersection). This guarantees termination.

**Implementation:** A `dispatch-cell` wraps a set of `impl-key` symbols (e.g., `'Nat--Add`, `'Int--Add`). The set is stored as a Racket `seteq` for O(1) membership testing. An empty set is contradiction.

### 4.2 Bidirectional Propagators

Four propagator types connect dispatch cells to the type and value networks:

#### Propagator 1: Type → Dispatch

When a type cell refines, eliminate impls that don't match.

```
Input:  type-cell for ?A
Output: dispatch-cell for (Add ?A)

Fire:
  if type-cell = type-bot: no-op (residuate)
  if type-cell = Nat: write dispatch-set {Add Nat}
  if type-cell = (Union Nat Int): write dispatch-set {Add Nat, Add Int}
  if type-cell = type-top: write dispatch-top
```

This propagator already exists conceptually — it's what `resolve-trait-constraints!` does in batch mode. The difference: it's now a network-resident propagator that fires incrementally.

#### Propagator 2: Dispatch → Type

When the dispatch cell narrows, constrain the type cell.

```
Input:  dispatch-cell for (Add ?A)
Output: type-cell for ?A

Fire:
  if dispatch = dispatch-bot: no-op
  if dispatch = dispatch-set {Add Nat, Add Int}:
    write type-cell = Union(Nat, Int)
  if dispatch = dispatch-one (Add Nat):
    write type-cell = Nat
  if dispatch = dispatch-top:
    write type-cell = type-top
```

**This is new.** Today, types inform dispatch. With this propagator, dispatch also informs types. Bidirectionality.

#### Propagator 3: Dispatch → Method Body (Conditional Activation)

When a dispatch cell resolves to a single impl, instantiate the concrete function's propagators.

```
Input:  dispatch-cell for (Add ?A)
Output: narrowing propagators for the resolved impl's method body

Fire:
  if dispatch = dispatch-one (Add Nat):
    1. Look up Nat--Add--dict → Nat--Add--add
    2. Look up definitional tree for Nat--Add--add (or nat-add)
    3. Install narrowing propagators from the DT onto arg/result cells
  if dispatch ≠ dispatch-one: residuate (wait for full resolution)
```

This is **conditional propagator activation** — a propagator that creates other propagators. The pattern already exists in the narrowing engine (DFS branching installs propagators for each branch). Here, the "branching" is over impl candidates rather than constructor patterns.

#### Propagator 4: Result → Dispatch (Reverse Constraint)

When the result type/value is known, eliminate impls whose method signature is incompatible.

```
Input:  result-type cell (from = target)
Output: dispatch-cell

Fire:
  For each impl in dispatch set:
    Check if impl's method return type unifies with result-type
    Keep only compatible impls
  Write filtered dispatch-set
```

For `.{x + y} = 5N`, the result type is `Nat`. This eliminates `Add Int`, `Add Rat`, `Add String`, etc. — only `Add Nat` has return type `Nat` for `add : Nat Nat -> Nat`.

### 4.3 Integration with ATMS for Search

When a dispatch cell has multiple candidates and forward propagation can't eliminate any, the ATMS `amb` mechanism creates branching points:

```
dispatch-set {Add Nat, Add Int} → no further type info available

→ ATMS amb:
  Assumption A1: dispatch = Add Nat
  Assumption A2: dispatch = Add Int
  Nogood: {A1, A2}  (mutually exclusive)

For each worldview:
  Install Propagator 3 (conditional activation)
  Run forward checking
  Collect solutions or detect contradiction (nogood)
```

This maps directly onto the existing narrowing DFS architecture. The `narrow-function` loop in `narrowing.rkt` enumerates constructors from definitional trees. Here, the enumeration is over **impl entries** from the trait registry. The data structure is different (set of impls vs. definitional tree branches), but the search procedure is identical.

### 4.4 The Generic Operator Bridge

The critical missing piece: connecting `expr-generic-add` to the trait dispatch propagator.

**Current pipeline:**
```
.{x + y}  →  expr-generic-add(x, y)  →  reduction pattern match  →  concrete op
```

**Proposed pipeline for narrowing:**
```
.{x + y} = 5N
  →  expr-generic-add(x, y) recognized as trait-dispatched
  →  Create dispatch-cell for Add
  →  Install Type→Dispatch propagator (type of x → Add candidates)
  →  Install Result→Dispatch propagator (Nat from 5N → filter to Add Nat)
  →  Dispatch resolves to Add Nat
  →  Install Dispatch→Method propagator
  →  Narrowing proceeds through nat-add's definitional tree
```

**Implementation:** Extend `run-narrowing` (reduction.rkt:209) to handle `expr-generic-add/sub/mul/div`:

```racket
(define-values (func-name all-args)
  (let loop ([e func-expr] [extra-args '()])
    (match e
      [(expr-fvar name) (values name (append extra-args arg-exprs))]
      [(expr-app f a) (loop f (cons a extra-args))]
      ;; NEW: Generic operators → resolve via trait dispatch
      [(expr-generic-add a b) (values (resolve-generic-for-narrowing 'Add a b) (list a b))]
      [(expr-generic-sub a b) (values (resolve-generic-for-narrowing 'Sub a b) (list a b))]
      [(expr-generic-mul a b) (values (resolve-generic-for-narrowing 'Mul a b) (list a b))]
      [(expr-generic-div a b) (values (resolve-generic-for-narrowing 'Div a b) (list a b))]
      [_ (values #f '())])))
```

Where `resolve-generic-for-narrowing` uses type information from the arguments (especially ground arguments like `1N : Nat`) to resolve the concrete function name (e.g., `'nat-add`, `'int-add`). For the dispatch propagator architecture, this resolution happens inside the propagator network rather than as a preprocessing step.

---

## 5. Application: Phase 2 Ergonomics (Narrowing Through Mixfix)

### 5.1 The Current Gap (Issue 5)

From the Surface Ergonomics tracking doc:

> `.{1N + ?y} = 3N` → `nil`
>
> Root cause: `+` is a trait-dispatched generic. The narrowing engine expects `defn`-defined functions with definitional trees. It can't narrow through trait dispatch.

The chain breaks at `run-narrowing`:
1. `.{1N + ?y}` → Pratt parse → `(+ 1N ?y)` → parser → `surf-generic-add(1N, ?y)`
2. Elaborator → `expr-generic-add(expr-suc(expr-zero), expr-logic-var(y))`
3. `run-narrowing` tries to extract `func-name` → pattern match on `expr-generic-add` fails → returns `#f`
4. Narrowing returns `nil`

### 5.2 Solution with Trait Dispatch Propagator

**Step 1 (Immediate, Phase 2d):** Add pattern match cases for `expr-generic-*` in `run-narrowing`:

```racket
[(expr-generic-add a b)
 ;; Determine concrete type from ground arguments
 (define type (infer-ground-type a b))  ;; e.g., Nat from 1N
 (define func-name (dispatch-for-type 'Add type))  ;; e.g., 'nat-add
 (values func-name (list a b))]
```

This is the **minimal fix** — it resolves the dispatch statically from ground argument types. Works when at least one operand is ground (the common case for `1N + ?y`).

**Step 2 (Phase 3, full propagator integration):** When neither operand is ground (e.g., `?x + ?y = 5N`), use the dispatch propagator cell:

1. Create dispatch cell for `Add` with all registered impls
2. Result type is `Nat` (from `5N`) → Result→Dispatch propagator eliminates non-Nat impls
3. Dispatch resolves to `Add Nat`
4. Install narrowing propagators for `nat-add`'s definitional tree
5. Narrowing proceeds normally

### 5.3 Concrete Resolution Table

For the minimal fix, a static dispatch table mapping trait + type to concrete function:

| Trait | Type | Concrete Function | Has DT? |
|-------|------|-------------------|---------|
| `Add` | `Nat` | `add` (prologos::data::nat) | Yes |
| `Add` | `Int` | `int+` (foreign) | No |
| `Sub` | `Nat` | `sub` (prologos::data::nat) | Yes |
| `Mul` | `Nat` | `mult` (prologos::data::nat) | Yes |
| `Eq` | `Nat` | `nat-eq` (prologos::core::eq) | Yes |
| `Ord` | `Nat` | `nat-compare` (prologos::core::ord) | Yes |

**Only functions with definitional trees can be narrowed.** Foreign functions (`int+`, `rat+`, posit ops) are opaque — narrowing through them requires either:
- Inverse function knowledge (e.g., `int+ a b = c` → `a = c - b`)
- Interval constraint propagation (already available via `narrowing-abstract.rkt`)
- Enumeration within bounded intervals

### 5.4 Phase 2 Bound Variable Enrichment (Issues 1, 2a-2c)

The dispatch propagator also helps with **bound variable output enrichment** (Phase 2a-2b):

When narrowing through a trait-dispatched function, the `spec` of the concrete instance provides parameter names. After resolving `Add ?A` to `Add Nat` (dict = `Nat--Add--dict`, method = `Nat--Add--add`), look up the spec for `Nat--Add--add`:

```
spec Nat--Add--add : Nat Nat -> Nat
;; Generated from: defn add [x y] <Nat> ...
;; Parameter names: x, y
```

These parameter names (`x`, `y`) are exactly what Issue 2a needs for enriching narrowing output with bound variables suffixed by `_`.

---

## 6. Application: Broader Language Benefits

### 6.1 Conditional Propagator Activation

**Pattern:** A dispatch cell resolving to a specific impl triggers installation of propagators that only make sense for that impl.

**Use case beyond narrowing:** Speculative type checking. When elaborating `[add x y]` where `x : ?A`, the elaborator could:
1. Create a dispatch cell for `Add ?A`
2. For each remaining candidate impl, speculatively install type constraints
3. As type information flows in, candidates are eliminated
4. When dispatch resolves, only the correct constraints survive

This turns the current batch `resolve-trait-constraints!` pass into an incremental, network-resident process. Benefits:
- **Earlier error detection:** Trait resolution errors can be caught during type inference, not after
- **Better error messages:** The dispatch cell's history shows which candidates were eliminated and why
- **Interaction with other constraints:** Trait resolution participates in the same fixpoint as type unification

### 6.2 Multi-Dispatch Refinement

Today, multi-dispatch (`multi-dispatch.rkt`) is arity-based and compile-time. With dispatch cells, it could become **type-based and incremental**:

```prologos
defn process [x : Nat] -> Nat      ;; clause 1
defn process [x : String] -> String ;; clause 2

;; With dispatch cells:
;; Cell for "which process clause?": {clause-1, clause-2}
;; Type of x refines → eliminates clause-2 → dispatch-one clause-1
```

This is a natural extension: multi-dispatch is trait dispatch where the "trait" is the function's overload set.

### 6.3 Type-Directed Search

**For the relational/logic programming side:** When solving relational goals that involve trait-constrained functions, the narrowing engine can use dispatch cells to prune the search space:

```prologos
;; "Find all types A where add applied to A values can equal 10N"
solve [T] <type> .{(the <T T -> T> add) 3 ?y} = 10
;; Dispatch cell for Add: {Add Nat, Add Int, Add Rat, ...}
;; Result = 10 → Nat or Int (not Rat, not String)
;; Dispatch → {Add Nat, Add Int}
;; Narrow through each: Nat gives y=7N, Int gives y=7
```

This is **trait-polymorphic narrowing** — searching over both values AND types simultaneously. The dispatch cell is the type-level search variable; value cells are value-level search variables. The propagator network synchronizes them.

### 6.4 Runtime Trait Introspection

With dispatch cells as first-class entities, the REPL can offer trait-aware introspection:

```prologos
;; REPL commands
:instances Add        ;; → [Nat, Int, Rat, Posit8, ..., String]
:methods   Num        ;; → [add, sub, mul, neg, eq?, compare, abs, from-integer]
:dispatch  (Add Nat)  ;; → Nat--Add--dict : Eq Nat := nat-add
:satisfies Nat        ;; → [Eq, Ord, Add, Sub, Mul, Hashable, ...]
```

This requires only that the impl registry be queryable from the surface language — no deep type system changes.

### 6.5 Trait Composition as Constraint Programming

Bundles are conjunctions today. With dispatch cells, bundles could become **constraint programs**:

```prologos
bundle NumericRing := (Add, Mul, AdditiveIdentity, MultiplicativeIdentity)
  :laws
    - :name "distributive"
      :forall {x y z : A}
      :holds [eq? [mul x [add y z]] [add [mul x y] [mul x z]]]
```

The `:laws` annotations on traits (already present in `arithmetic.prologos`) could be compiled into **verification propagators**: after dispatch resolves, check that the resolved impls satisfy the documented laws via property-based testing or symbolic verification.

### 6.6 Interplay with Session Types

Session type checking already uses propagator cells (`session-lattice.rkt`). If a session protocol sends a value over a channel, and the receiving end requires `where (Eq A)`, the dispatch cell for that constraint participates in the same network as the session type cells. This enables:

```prologos
protocol P
  send A where (Eq A)
  recv Bool
  end

;; Session type checker + trait dispatch in same network:
;; Cell 1: session state (send/recv/end)
;; Cell 2: type of sent value (?A)
;; Cell 3: dispatch cell for Eq ?A
;; Propagators connect all three bidirectionally
```

---

## 7. Implementation Phases

### Phase 2a: Static Generic Operator Resolution for Narrowing (Immediate)

**Goal:** Fix Issue 5 (`.{1N + ?y} = 3N` → `nil`) with minimal changes.

**Scope:** Add pattern match cases for `expr-generic-*` in `run-narrowing`.

**Files:**
- `reduction.rkt`: Extend `run-narrowing` function extraction (line 215-220)
- `narrowing.rkt`: No changes (existing DT-guided search handles the resolved function)

**Approach:** When `run-narrowing` encounters `expr-generic-add(a, b)`:
1. Check if either `a` or `b` is ground (has a known type)
2. If so, look up the concrete function for that type (e.g., `nat-add` for `Nat`)
3. Check if that function has a definitional tree
4. If yes, narrow through it. If no (foreign function), use interval constraints.

**Mapping table** (hardcoded initially, registry-based later):

```racket
(define generic-to-concrete
  (hasheq
   'Add  (hasheq 'Nat 'add    'Int 'int-add)
   'Sub  (hasheq 'Nat 'sub    'Int 'int-sub)
   'Mul  (hasheq 'Nat 'mult   'Int 'int-mul)
   'Eq   (hasheq 'Nat 'nat-eq 'Bool 'bool-eq)
   'Ord  (hasheq 'Nat 'nat-compare)))
```

**Tests:** Extend `test-eq-let-surface-01.rkt` or create `test-trait-narrowing-01.rkt`:
- `.{1N + ?y} = 3N` → `'{:y 2N}`
- `.{?x * 2N} = 6N` → `'{:x 3N}`
- `.{?x + ?y} = 5N` → enumerate solutions

**Commit boundary:** This is a self-contained fix, independent of the full propagator integration.

### Phase 2b: Dispatch Lattice Module (Foundation)

**Goal:** Create the `dispatch-lattice.rkt` module with the finite-domain lattice for impl candidates.

**Deliverables:**
- `dispatch-bot`, `dispatch-set`, `dispatch-one`, `dispatch-top` value types
- `dispatch-merge` (set intersection) and `dispatch-contradicts?` functions
- `dispatch-from-trait` constructor: given a trait name, build initial dispatch-bot from all registered impls
- Unit tests

**Design note:** The dispatch lattice is **independent of the propagator network** — it's a pure value type. This makes it testable in isolation.

### Phase 2c: Trait Dispatch Propagators (Core)

**Goal:** Implement the four propagator types from Section 4.2.

**Files:**
- NEW: `trait-dispatch-propagators.rkt`
- Modified: `elaborator-network.rkt` (add dispatch cell creation)
- Modified: `metavar-store.rkt` (trait constraint → dispatch cell instead of wakeup map)

**Deliverables:**
- Type→Dispatch propagator
- Dispatch→Type propagator
- Dispatch→Method propagator (conditional activation)
- Result→Dispatch propagator
- Integration test: dispatch cell narrows as type information flows in

**Key decision:** Should dispatch cells live in the main elaboration network (`elab-network`) or in a separate narrowing network? Recommendation: **separate narrowing network**, to avoid polluting the compilation pipeline. Dispatch cells are created on-demand when narrowing is invoked, not during normal elaboration.

### Phase 2d: ATMS Integration for Multi-Dispatch Search

**Goal:** When a dispatch cell can't be resolved by forward propagation, use ATMS `amb` to enumerate candidates.

**Files:**
- Modified: `narrowing.rkt` (add dispatch-cell branching alongside DT branching)
- Modified: `atms.rkt` (no structural changes, just usage)

**Deliverables:**
- Narrowing DFS loop handles "dispatch demand" alongside "term demand"
- When a dispatch cell has multiple candidates, `amb` creates branches
- Each branch installs the conditional method propagators
- Solutions are collected across branches

### Phase 3a: Incremental Trait Resolution in Elaboration (Advanced)

**Goal:** Replace the batch `resolve-trait-constraints!` with incremental, network-resident resolution.

**Scope:** Large refactor. Move trait resolution from a post-inference batch pass to an in-network propagator that fires during inference.

**Benefits:**
- Earlier error detection (trait errors during inference, not after)
- Better error messages (dispatch cell shows elimination history)
- Bidirectional type-dispatch information flow during inference
- Removes `current-trait-wakeup-map` (propagator network handles wakeup)

**Risk:** Trait resolution during inference can cause cascading resolutions. Need careful handling of parametric impls (which trigger sub-constraints). The batch model's advantage is simplicity — all type inference completes before any dispatch is attempted.

**Mitigation:** Hybrid approach — install dispatch propagators during inference but mark them as "deferred." After inference completes, run the deferred propagators to quiescence. This preserves the batch ordering guarantee while enabling the propagator infrastructure.

### Phase 3b: Trait Registry as Queryable Data (Introspection)

**Goal:** Make the trait registry queryable from Prologos surface code.

**Deliverables:**
- `instances-of : Type -> List Symbol` — list all impl keys for a trait
- `methods-of : Type -> List (Pair Symbol Type)` — list methods and their types
- `satisfies? : Type -> Type -> Bool` — does a type have an impl for a trait?
- REPL commands: `:instances`, `:methods`, `:dispatch`, `:satisfies`

### Phase 3c: Level 1 — Trait Names as Type Constructors (Low-Hanging Fruit)

**Goal:** Allow `Eq`, `Ord`, `Add` to be used as type-level values of kind `Type → Type`.

**Implementation:** Add trait names to the `builtin-tycon-arity` table (syntax.rkt:934) and handle them in `normalize-for-resolution`.

**Tests:**
- `(def my-eq : (Type -> Type) Eq)` — trait as type constructor value
- `(def x : (my-eq Nat) nat-eq)` — apply trait-as-tycon to get dict type

---

## 8. Connection to the Propagator Network Architecture

### 8.1 Why This Fits

The propagator network is designed for **monotonic refinement of partial information**. Trait dispatch is exactly this:

| Propagator Concept | Trait Dispatch Analog |
|--------------------|-----------------------|
| Cell with lattice value | Dispatch cell with impl candidate set |
| bot (no information) | All impls possible |
| top (contradiction) | No impl satisfies constraints |
| Merge (join) | Set intersection of compatible impls |
| Propagator | Type→Dispatch, Dispatch→Type, etc. |
| Quiescence | Dispatch resolved (single impl) or stuck |
| ATMS branching | Enumerate remaining candidates |

The CALM theorem guarantees that this converges: the candidate set only shrinks (intersection is monotonic), and the set is finite (bounded by registered impls). No widening needed.

### 8.2 Pure Value Semantics

Following the existing architecture, dispatch cells are immutable values in the network. All propagator operations return new networks (structural sharing via CHAMP). No mutation. This enables:
- **Speculative resolution:** Try a dispatch, backtrack if it leads to contradiction
- **Parallel search:** Each ATMS worldview has its own dispatch cell values
- **Deterministic replay:** Same inputs → same dispatch → same results

### 8.3 The Lattice Hierarchy

After this work, the propagator network will have five lattice types:

```
type-lattice        — Type expressions (Pi, Sigma, Union, ...)
mult-lattice        — QTT multiplicities (m0, m1, mw)
term-lattice        — Narrowing terms (bot, var, ctor, top)
session-lattice     — Session types (send, recv, choice, offer, ...)
dispatch-lattice    — Trait impl candidates (set of impl-keys)  [NEW]
```

Cross-domain propagators connect them:
- **type ↔ mult** (existing Phase 5c)
- **type ↔ term** (existing Phase 2a cross-domain)
- **type ↔ dispatch** (new: Type→Dispatch, Dispatch→Type)
- **dispatch ↔ term** (new: Dispatch→Method conditional activation)
- **term ↔ interval** (existing: Galois connection)

The dispatch lattice bridges type-level and term-level reasoning — it's the "joint" between the type system and the evaluation/narrowing engine.

---

## 9. Risks and Mitigations

### Risk 1: Dispatch Cell Creation Overhead

**Concern:** Creating dispatch cells for every trait constraint adds allocations to the hot path.

**Mitigation:** Only create dispatch cells when narrowing is invoked (demand-driven). Normal elaboration and type-checking use the existing batch resolution path. The dispatch cell is a narrowing-time construct, not an inference-time one (until Phase 3a).

### Risk 2: Cascading Resolution in Parametric Impls

**Concern:** `impl Eq (List A) where (Eq A)` → resolving `Eq (List Nat)` triggers resolving `Eq Nat` → recursive dispatch cell creation.

**Mitigation:** Parametric impl resolution is already recursive in the batch model. The propagator version handles this via sub-constraint dispatch cells: resolving `Eq (List Nat)` creates a dispatch cell for `Eq Nat`, installs a Result→Dispatch propagator from the sub-constraint, and lets the network resolve it. If `Eq Nat` is already resolved (singleton dispatch cell), no further work.

### Risk 3: Search Space Explosion

**Concern:** When multiple trait constraints interact (e.g., `where (Add A) (Eq A) (Ord A)`), the Cartesian product of dispatch cells could be large.

**Mitigation:**
- Forward propagation eliminates most candidates before search begins
- Dispatch cells for the same type variable are **correlated** — resolving one (e.g., `Add Nat`) immediately constrains others (e.g., `Eq Nat`)
- The ATMS nogood mechanism prunes inconsistent combinations
- In practice, type information usually resolves dispatch cells to singletons without search

### Risk 4: Foreign Function Narrowing

**Concern:** Resolved impls may delegate to foreign (Racket) functions without definitional trees.

**Mitigation:**
- For foreign numeric functions: use interval constraint propagation (existing infrastructure)
- For foreign predicate functions: treat as opaque constraints (residuate)
- Document which trait impls are narrowable (have DTs) vs opaque (foreign)
- Phase 2a already handles this distinction via the mapping table

---

## 10. Summary: What First-Class Traits Get Us

| Capability | Phase | Effort | Impact |
|-----------|-------|--------|--------|
| Narrowing through mixfix operators (`+`, `-`, `*`) | 2a | Small | High (unblocks Phase 2d ergonomics) |
| Dispatch lattice as reusable module | 2b | Small | Medium (foundation for later phases) |
| Bidirectional type↔dispatch propagation | 2c | Medium | High (enables type-directed search) |
| ATMS-based multi-impl search | 2d | Medium | High (full trait-polymorphic narrowing) |
| Incremental trait resolution | 3a | Large | High (better errors, earlier detection) |
| Trait introspection at REPL | 3b | Small | Medium (developer experience) |
| Trait names as type constructors | 3c | Small | Low (type-level programming) |

The most immediate practical benefit is **Phase 2a**: a small, targeted fix that makes `.{1N + ?y} = 3N` work by resolving generic operators to concrete functions before entering the narrowing engine. This can be done in a single commit without any new modules.

The architectural benefit is **Phases 2b-2c**: establishing trait dispatch as a propagator cell type, which unifies trait resolution with the same monotonic refinement framework used for types, multiplicities, session types, and narrowing terms. This is the foundation that makes trait dispatch **natively integrated** into the propagator network rather than bolted on as a post-processing pass.

The long-term vision is **Phase 3a**: incremental trait resolution during inference, where trait constraints participate in the same fixpoint computation as type unification. This completes the transition from "traits as a compile-time side table" to "traits as first-class participants in the constraint network."

---

## Appendix A: Relevant Code Locations

| Component | File | Lines | Key Functions/Structs |
|-----------|------|-------|-----------------------|
| Trait declaration | macros.rkt | 6222-6400 | `process-trait`, `trait-meta`, `trait-method` |
| Monomorphic impl | macros.rkt | 7000-7076 | `process-monomorphic-impl`, `impl-entry` |
| Parametric impl | macros.rkt | 7082-7320 | `process-parametric-impl`, `param-impl-entry` |
| Bundle expansion | macros.rkt | 5431-5645 | `process-bundle`, `expand-bundle-constraints` |
| Trait constraint map | metavar-store.rkt | 203-253 | `trait-constraint-info`, wakeup/cell maps |
| Dict param handling | elaborator.rkt | 116-193 | `is-dict-param-name?`, `resolve-method-from-where` |
| Trait resolution | trait-resolution.rkt | 128-317 | `try-monomorphic-resolve`, `try-parametric-resolve` |
| Generic operators | parser.rkt | 1709-1784 | `surf-generic-add/sub/mul/div` |
| Generic elaboration | elaborator.rkt | 1184-1231 | `expr-generic-add/sub/mul/div` |
| Generic reduction | reduction.rkt | 1313-1318 | Pattern-match dispatch |
| Narrowing entry | reduction.rkt | 209-233 | `run-narrowing` (func extraction gap) |
| Propagator network | propagator.rkt | 76-122 | `prop-network`, `net-cell-write`, `net-add-propagator` |
| Elaboration network | elaborator-network.rkt | 69-250 | `elab-network`, `elab-fresh-meta` |
| Term lattice | term-lattice.rkt | 61-145 | `term-bot/var/ctor/top`, `term-merge` |
| ATMS | atms.rkt | 61-397 | `atms-amb`, `atms-solve-all` |
| Narrowing search | narrowing.rkt | 163-440 | `install-narrowing-propagators`, `run-narrowing-search` |
| Interval domain | narrowing-abstract.rkt | 41-139 | `compute-arg-intervals` |
| Lattice traits | lib/prologos/core/lattice.prologos | 24-343 | `Lattice`, `Widenable`, `GaloisConnection` |
| Arithmetic traits | lib/prologos/core/arithmetic.prologos | 13-289 | `Add`, `Sub`, `Mul`, `Div`, `Neg`, `Abs` |

## Appendix B: Design Principles Applied

1. **Compositional, not hierarchical:** Dispatch cells compose via set intersection (monotonic). No inheritance, no method resolution order. Consistent with the bundle model.

2. **Propagator-native:** Dispatch is a lattice element in the network, not an external lookup. Same CALM guarantees, same quiescence semantics, same ATMS integration.

3. **Demand-driven:** Dispatch cells are created only when needed (narrowing, speculative checking). Normal compilation pays no cost.

4. **Bidirectional:** Types inform dispatch AND dispatch informs types. The propagator architecture makes this natural — every cell is both readable and writable.

5. **Pure:** All dispatch operations are pure (return new networks). No mutation. Enables speculative resolution and backtracking.

6. **Incremental:** Each piece can be deployed independently. Phase 2a is a self-contained fix. Phase 2b is a standalone module. Phase 2c integrates them. No "big bang" required.
