# First-Class Traits: Stage 3 Implementation Design

Created: 2026-03-09
Supersedes: `2026-03-09_FIRST_CLASS_TRAITS_DESIGN.md` (exploratory Stage 2 artifact)
Design Principle: **First-Class by Default** (DESIGN_PRINCIPLES.org)

---

## 1. Vision

Traits in Prologos are constraints on types — propositions witnessed by
dictionaries. Making them first-class means: traits can be stored, passed,
returned, abstracted over, and computed upon, just like types, multiplicities,
session protocols, and code. This creates a combinatorial surface for emergent
capabilities we cannot predict (the session types lesson: composable protocol
phases fell out of first-class-ness, not deliberate design).

The implementation follows three cumulative levels, each building on the prior:

| Level | What becomes first-class | Key capability |
|-------|--------------------------|----------------|
| **1** | Trait names as type constructors | Abstract over *which trait* at the type level |
| **2** | Trait dispatch as propagator cells | Bidirectional type↔dispatch; narrowing through operators |
| **3** | Traits as first-class propositions | Quantify over traits; method projection; relational domain constraints |

No level precludes the next. The design target is Level 3; the implementation
path goes through Levels 1 and 2. Level 2 is designed with Level 3 in mind
from the start.

### Progress Tracker

Implementation phases in suggested order:

| # | Phase | Deliverable | Level | Effort | Status |
|---|-------|-------------|-------|--------|--------|
| 1 | **Phase 1** | Trait names as type constructors | L1 | Small | ✅ Complete (`f6b540e`) |
| 2 | **Phase 2a** | Static generic operator resolution | L2 | Small | ✅ Complete (`44539b1`) |
| 3 | **Phase 2b** | `constraint-cell.rkt` module | L2 | Small | ✅ Complete (`dc98b9b`) |
| 4 | **Phase 3a** | HasMethod constraint + projection | L3 | Medium | ⬜ Not started |
| 5 | **Phase 2c** | Constraint propagators (P1–P4) | L2 | Medium | ✅ Complete (`2ca66d2`) |
| 6 | **Phase 2d** | ATMS multi-candidate search | L2 | Medium | ⬜ Not started |
| 7 | **Phase 3b** | Trait introspection (REPL + foreign) | L3 | Small | ⬜ Not started |
| 8 | **Phase 3c** | `?var:C1:C2` constraint chain syntax | L3 | Medium | ⬜ Not started |
| 9 | **Phase 3d** | Incremental trait resolution | L3 | Large | ⬜ Not started |

**Legend:** ⬜ Not started · 🔄 In progress · ✅ Complete · ⏸️ Blocked

---

## 2. Essential Operations (Theory-Grounded)

Three operations are *essential* — grounded in type theory, independent of any
particular language's approach:

1. **Trait abstraction** — Quantifying over *which property* is satisfied.
   Second-order universal quantification: `∀P. ∀A. P(A) → ...`. In dependent
   types: `Pi (P : Type → Type) → ...`. Every dependently-typed language with
   universe polymorphism has the substrate.

2. **Method projection** — Given evidence `d : P A` and knowledge that `P`
   has a method with a certain signature, extracting that method. This is
   *elimination* for record/existential types.

3. **Evidence construction** — Building a dictionary for a specific type,
   possibly from sub-evidence. This is what `impl` already does.

Everything else — HasMethod, row variables, trait universes, `project` — is
*mechanism* for expressing these operations. The mechanism is incidental; the
operations are essential.

### Why Not "Evidence Combination" as a Fourth Operation?

Languages with trait hierarchies (Haskell's `class Eq a => Ord a`, Rust's
supertraits) need a fourth operation: **evidence extraction** — given a
composite dictionary `d : Ord A`, extract the sub-dictionary `d' : Eq A`.
This is elimination for nested records.

Prologos does not need this operation because **Prologos has no trait
hierarchies** (see DESIGN_PRINCIPLES.org § "No Trait Hierarchies — Bundles
Only"). Bundles are conjunctive sugar expanded at parse time:

```
where (Num A)
  ↓ expands to ↓
where (Add A) (Sub A) (Mul A) (Neg A) (Abs A) (FromInt A) (Eq A) (Ord A)
```

Each constraint produces an independent dictionary parameter. There is no
composite `Num` dictionary — the sub-evidence is already present as separate
dict params. Evidence extraction is unnecessary when evidence is never nested.

This is a direct consequence of the non-negotiable "No Trait Hierarchies"
principle. If a future design revisits this (which would require changing a
core principle), evidence combination would need to be added as a fourth
essential operation.

---

## 3. The Prologos Way: Surface Syntax

### 3.1 Principle: Pi Types as Implementation Detail

Complex type theory hides behind structured metadata on existing keywords.
`where (Ord A)` hides `Pi ($Ord-A :w (Ord A)) → ...`. The same applies to
trait abstraction: the second-order Pi is the substrate, not the surface.

### 3.2 Trait Abstraction via Spec Metadata

Extend the existing `spec` metadata system with new keys for trait
polymorphism. The metadata parser (`parse-spec-metadata` at macros.rkt:2505)
already supports extensible keyword-value pairs; unrecognized keys are stored
without error.

**New metadata keys:**

| Key | Meaning | Elaboration |
|-----|---------|-------------|
| `:over P` | Quantify over trait P (`P : Type → Type`) | Implicit Pi binder |
| `:method P eq? : A A -> Bool` | P must provide method `eq?` with this signature | HasMethod constraint + projection |
| `:has [eq? : A A -> Bool]` | Structural method requirement (no named trait) | Row-like constraint |

**Examples — progressive disclosure:**

```prologos
;; Level 0: concrete trait constraint (today)
spec sort {A : Type} where (Ord A) [List A] -> [List A]

;; Level 3: abstract over which trait
spec apply-method {A : Type} [P A] A A -> Bool
  :over P
  :method P eq? : A A -> Bool

;; Level 3: structural method requirement (no named P)
spec fold-with {A : Type} [D] [List A] A -> A
  :over D
  :has D [combine : A A -> A]
```

**Elaboration of `:over P`:**
```
spec apply-method {A : Type} [P A] A A -> Bool
  :over P
  :method P eq? : A A -> Bool

  ↓ elaborates to ↓

Pi {A :0 Type}
 → Pi {P :0 (Type → Type)}        ← from :over
 → Pi ($HasMethod-P-eq? :w          ← from :method
        (HasMethod P 'eq? (A → A → Bool)))
 → Pi (dict :w (P A))
 → A → A → Bool
```

The `P` binder is inferred from `:over`, not written in the signature. The
HasMethod constraint is inferred from `:method`, not written as `where`. The
surface reads as structured metadata; the elaboration is standard dependent
type theory.

### 3.3 Relational Constraint Chain: `?var:C1:C2:...:Cn`

**New syntax for constraining logic variables with types and traits:**

```prologos
?xs:Ord                       ;; trait constraint on type of ?xs
?n:PosInt                     ;; type constraint on value of ?n
?n:PosInt:Even                ;; type + predicate constraint
?n:Between[50 100]:Even       ;; parameterized constraint + predicate
?xs:Ord:NonEmpty              ;; trait + predicate conjunction
```

**Kind-directed disambiguation:**

| Constraint C | Kind of C | Meaning | Propagator cell type |
|--------------|-----------|---------|---------------------|
| `PosInt` | `Type` | Value inhabits PosInt | Type annotation |
| `Ord` | `Type → Type` | Type of variable satisfies Ord | Dispatch cell |
| `Even` | `Nat → Type` | Value satisfies Even predicate | Predicate constraint cell |
| `Between[50 100]` | `Nat → Type` (applied) | Value in range | Interval constraint cell |

The compiler determines which kind of constraint by looking up the kind of `C`
in the type environment. The elaborator already does kind-directed dispatch;
this extends the same mechanism.

**Parameterized constraints use `[]`** (functional application brackets):
```prologos
?n:Between[50 100]            ;; Between applied to 50, 100
?xs:SortedBy[compare]         ;; SortedBy applied to a comparison function
```

The `?` prefix signals relational variable. The `[]` signals functional
construction. The `:` signals conjunction (progressive domain narrowing).

**Elaboration:**
```prologos
defr sum-evens [?xs:Nat:Even ?total:Nat]
  (fold add zero ?xs ?total)

  ↓ elaborates to ↓

defr sum-evens [?xs ?total]
  :type ?xs Nat               ;; type annotation
  :constraint ?xs Even        ;; predicate constraint → cell
  :type ?total Nat            ;; type annotation
  (fold add zero ?xs ?total)
```

Each `:` constraint becomes a cell in the propagator network. Type constraints
become type annotations. Trait constraints become dispatch cells. Predicate
constraints become predicate constraint cells. All participate in the same
monotonic refinement.

**Unification with `where` in functional specs:**

```prologos
;; Functional: constraints on type parameters
spec sort {A : Type} where (Ord A) [List A] -> [List A]

;; Relational: constraints on logic variables
defr sorted [?xs:Ord ?ys:Ord]
  (permutation ?xs ?ys)
  (ascending ?ys)
```

Both create the same dispatch cell for `Ord`. Different surface for different
paradigms; same underlying propagator network.

### 3.4 Grammar Extension

New EBNF rules for logic variable constraints:

```ebnf
;; Extended mode-param with constraint chain
mode-param      = '?' , identifier , { ':' , constraint-ref }
                | '+' , identifier
                | '-' , identifier
                | identifier ;

constraint-ref  = identifier                       (* bare: Ord, PosInt, Even *)
                | identifier , '[' , expr , { expr } , ']'  (* parameterized: Between[50 100] *)
                ;
```

New EBNF rules for trait abstraction metadata:

```ebnf
;; New spec metadata keys
spec-meta-entry = ... (* existing *)
                | ':over' , identifier                       (* trait variable *)
                | ':method' , identifier , identifier ,
                  ':' , type-expr                            (* method requirement *)
                | ':has' , identifier ,
                  '[' , method-sig , { method-sig } , ']'   (* structural requirement *)
                ;

method-sig      = identifier , ':' , type-expr ;
```

---

## 4. Constraint Cell: The Generalized Dispatch Lattice

### 4.1 Why Generalize

The original design proposed `dispatch-lattice.rkt` specifically for trait impl
candidate sets. The relational constraint syntax reveals this is one instance of
a general pattern: **any finite-domain constraint on a variable is a cell in the
propagator network**.

| Cell type | Domain | Example |
|-----------|--------|---------|
| Dispatch cell | Set of trait impls | `{Add Nat, Add Int, Add Rat}` |
| Type membership | Set of types | `{Nat, Int}` (from union) |
| Predicate | Set of satisfying values | `{x : Even(x)}` |
| Interval | Numeric range | `[50, 100]` (from Between) |

All share: bot = unconstrained, join = intersection, top = contradiction,
monotonic narrowing.

### 4.2 The Constraint Cell Module: `constraint-cell.rkt`

**Lattice values:**

```
constraint-bot     = all values possible (unconstrained)
constraint-set S   = subset of candidates (partially constrained)
constraint-one e   = single candidate (fully resolved)
constraint-top     = no candidate satisfies (contradiction)
```

**Merge (join):** Set intersection.

```
constraint-bot ⊔ constraint-set S = constraint-set S
constraint-set S1 ⊔ constraint-set S2 = constraint-set (S1 ∩ S2)
constraint-set {e} = constraint-one e     (singleton optimization)
constraint-set {} = constraint-top        (empty = contradiction)
```

**Monotonicity:** Candidate set only shrinks. Guaranteed termination.

**Implementation reference:** Follow the pattern from `type-lattice.rkt`:
- `type-lattice-merge` (type-lattice.rkt:124-142) handles bot/top/concrete
- `type-lattice-contradicts?` (type-lattice.rkt:148) checks for top
- `net-new-cell` (propagator.rkt:162-178) takes `merge-fn` and `contradicts?`

The constraint cell registers its own merge function and contradiction
predicate when allocated, just as type cells do.

### 4.3 Bidirectional Propagators

Four propagator types connect constraint cells to the type and term networks:

**P1: Type → Constraint**
When a type cell refines, eliminate candidates that don't match.
```
type-cell for ?A = Nat  →  constraint-set {Add Nat}  (from {Add Nat, Add Int, Add Rat})
```

**Union type semantics:** When the type cell is a union (`?A = Nat | Int`), P1
retains impls for *every* member of the union: `constraint-set {Add Nat, Add Int}`.
This is conjunctive — the constraint requires that *all* types in the union
satisfy the trait, not just one. If any member lacks an impl (e.g., `Nat | Foo`
where `Foo` has no `Add` impl), the constraint cell excludes that member's
contribution, eventually reaching `constraint-top` (contradiction) if no common
impl exists. This matches the standard approach: `where (Add A)` with
`A = Nat | Int` means both `Add Nat` and `Add Int` must be available, because
the dispatched method must work for any value of type `A`.

**P2: Constraint → Type**
When the constraint cell narrows, constrain the type cell. *This is new* — today
resolution is unidirectional (types → dispatch; never dispatch → types).
```
constraint-set {Add Nat, Add Int}  →  type-cell for ?A = Union(Nat, Int)
```

**Duality note:** P1 and P2 operate in dual spaces. In *constraint space*,
adding a constraint computes an *intersection* (fewer candidates). In *type
space*, the remaining candidates map to a *union* of possible types. These are
two views of the same information: constraint intersection ↔ type union. The
constraint cell shrinks monotonically (intersection); the type cell reflects
the remaining possibilities (union). Neither contradicts the other — they are
duals under the Galois connection between constraint sets and type sets.

**P3: Constraint → Method (Conditional Activation)**
When a constraint cell resolves to a single candidate, install the concrete
function's propagators. This is conditional propagator activation — a propagator
that creates other propagators.
```
constraint-one (Add Nat)  →  install narrowing propagators for nat-add's DT
```

**Architecture note:** "Creates other propagators" is not mutation. In
Prologos's pure functional propagator network (`prop-network` struct,
propagator.rkt:78), adding a propagator returns a *new* network value with
structural sharing. This is the same mechanism used by the narrowing DFS
(`install-narrowing-propagators`, narrowing.rkt:163), which dynamically adds
propagators as it explores definitional tree branches. Pre-allocating all
possible method propagators would be wasteful when a trait has many impls (e.g.,
`Add` spans Nat, Int, Rat, Posit8-64, String, and user types). Dynamic
installation after resolution is both correct and efficient in this architecture.

**P4: Result → Constraint (Reverse)**
When the result type/value is known, eliminate candidates whose method signature
is incompatible.
```
result = 5N (Nat)  →  eliminate Add Int, Add Rat, Add String from constraint
```

**Wiring via `net-add-propagator`** (propagator.rkt:234):
Each propagator is registered with input cell IDs and output cell IDs. The
network automatically enqueues dependent propagators when a cell changes.

### 4.4 Connection to Existing Lattice Hierarchy

After this work, the propagator network has six lattice types:

```
type-lattice        — Type expressions (Pi, Sigma, Union, ...)
mult-lattice        — QTT multiplicities (m0, m1, mw)
term-lattice        — Narrowing terms (bot, var, ctor, top)
session-lattice     — Session types (send, recv, choice, offer, ...)
interval-lattice    — Numeric intervals (existing Galois connection)
constraint-lattice  — Finite-domain constraint candidates  [NEW]
```

Cross-domain propagators:
- **type ↔ mult** (existing)
- **type ↔ term** (existing)
- **type ↔ constraint** (new: P1, P2)
- **constraint ↔ term** (new: P3 conditional activation)
- **term ↔ interval** (existing: Galois connection)
- **constraint ↔ interval** (new: parameterized constraints like Between)

The constraint lattice bridges type-level and term-level reasoning — it's the
"joint" between the type system and the evaluation/narrowing engine.

---

## 5. Level 1: Trait Names as Type Constructors

### 5.1 Scope

Allow trait names to appear as values of kind `Type → Type`.

```prologos
def my-eq : <Type -> Type> := Eq
;; my-eq Nat  ~  Eq Nat  ~  (Nat Nat -> Bool)
```

### 5.2 Implementation

**File: `syntax.rkt`**

Add trait names to `builtin-tycon-arity` (syntax.rkt:934). Currently:
```racket
(define builtin-tycon-arity
  (hasheq 'PVec 1  'Set 1  'Map 2  'List 1  'LSeq 1
          'Vec 2   'TVec 1 'TMap 2  'TSet 1))
```

Traits generate `deftype` declarations via `process-trait` (macros.rkt:6304-6348),
so they already exist as type constructors. The issue is that `builtin-tycon-arity`
is a static table. Instead:

**Option A (simple):** After `process-trait` registers the `deftype`, also register
the arity in a dynamic `tycon-arity` parameter. The elaborator consults this
parameter during type application elaboration.

**Option B (cleaner):** The `deftype` registration already implies a type constructor.
Ensure the elaborator's type application path (`elaborate-type-app`) handles
trait-generated `deftype` names the same as `PVec`/`Map`/etc.

**Arity:** Single-param traits (Eq, Ord, Add) have arity 1. Multi-param traits
(GaloisConnection) have arity 2+. The arity is the length of `trait-meta-params`.

### 5.3 Tests

```prologos
;; Store trait as type-level value
def my-eq : <Type -> Type> := Eq

;; Apply trait-as-tycon
def x : [my-eq Nat] := nat-eq

;; Pass trait to type-level function
spec apply-trait : {F : <Type -> Type>} {A : Type} [F A] -> Bool
```

### 5.4 Commit Boundary

Self-contained. No dependency on Level 2 or 3. Can be done in a single commit.

---

## 6. Level 2: Constraint Cells in the Propagator Network

### Phase 2a: Static Generic Operator Resolution (Immediate Fix)

**Goal:** Fix `.{1N + ?y} = 3N → nil` with minimal changes.

**File:** `reduction.rkt` — Extend `run-narrowing` (line 209):

```racket
;; Current: only handles expr-fvar and expr-app
;; New: add cases for expr-generic-*

[(expr-generic-add a b)
 (define type (infer-ground-type-from-args a b))
 (define fname (generic-dispatch-for-type 'Add type))
 (values fname (list a b))]
[(expr-generic-sub a b) ...]
[(expr-generic-mul a b) ...]
[(expr-generic-div a b) ...]
```

**Dispatch table** (initially hardcoded, registry-based in Phase 2c):

```racket
(define generic-dispatch-table
  (hasheq
   'Add  (hasheq 'Nat 'add    'Int 'int-add)
   'Sub  (hasheq 'Nat 'sub    'Int 'int-sub)
   'Mul  (hasheq 'Nat 'mult   'Int 'int-mul)
   'Eq   (hasheq 'Nat 'nat-eq 'Bool 'bool-eq)
   'Ord  (hasheq 'Nat 'nat-compare)))
```

**`infer-ground-type-from-args`:** Inspect arguments for ground type indicators:
- `expr-zero`, `expr-suc` → `'Nat`
- `expr-int` → `'Int`
- `expr-rat` → `'Rat`
- `expr-posit*` → corresponding posit type
- `expr-string` → `'String`

**Tests (new file: `test-trait-narrowing-01.rkt`):**
- `.{1N + ?y} = 3N` → `'{:y 2N}`
- `.{?x * 2N} = 6N` → `'{:x 3N}`
- `.{?x + ?y} = 5N` → enumerate solutions (Nat pairs summing to 5)
- `.{1N = 1N}` → `true` (already works via eq-check)

**Commit boundary:** Self-contained single commit. No new modules.

### Phase 2b: Constraint Cell Module (Foundation)

**Goal:** Create `constraint-cell.rkt` — pure lattice values, no network dependency.

**Deliverables:**
- `constraint-bot`, `constraint-set`, `constraint-one`, `constraint-top` structs
- `constraint-merge` function (set intersection semantics)
- `constraint-contradicts?` predicate
- `constraint-from-trait` constructor: given trait name, build initial set from
  all registered impls (queries `current-impl-registry`)
- `constraint-from-type-predicate` constructor: for type membership/predicate cells
- Unit tests for lattice properties (associativity, commutativity, monotonicity)

**Design for Level 3:** The cell is parameterized by a *trait identifier* that
is currently a symbol but could later become a type-level value. Use an
abstract `trait-ref` type, not raw symbols:

```racket
(struct trait-ref (name arity) #:transparent)
;; Later, Level 3 extends this to:
;; (struct trait-ref-computed (type-expr arity) #:transparent)
```

**Commit boundary:** Standalone module with unit tests.

### Phase 2c: Propagator Integration

**Goal:** Wire constraint cells into the propagator network.

**New file:** `constraint-propagators.rkt`
- `install-type→constraint-propagator` (P1)
- `install-constraint→type-propagator` (P2)
- `install-constraint→method-propagator` (P3)
- `install-result→constraint-propagator` (P4)

**Modified files:**
- `elaborator-network.rkt`: Add constraint cell allocation alongside type cells
- `metavar-store.rkt`: Trait constraint → constraint cell (replacing or
  augmenting `current-trait-cell-map`)

**Key decision:** Constraint cells live in a **narrowing network** (separate
from the main elaboration network), created on-demand when narrowing is invoked.
Normal type-checking pays no cost.

**Replace hardcoded dispatch table from Phase 2a:** The generic operator cases
in `run-narrowing` now create constraint cells instead of doing static lookup.
The propagator network resolves the dispatch.

**Commit boundary:** After integration tests pass (dispatch cell narrows as
type information flows in).

### Phase 2d: ATMS Integration for Multi-Candidate Search

**Goal:** When a constraint cell can't be resolved by forward propagation,
use ATMS `amb` to enumerate candidates.

**Modified files:**
- `narrowing.rkt`: Add constraint-cell branching alongside DT branching
- `atms.rkt`: No structural changes (existing `atms-amb` handles new cell type)

**Mechanism:** When the narrowing DFS encounters a stuck constraint cell
(multiple candidates, no further forward information):

```
constraint-set {Add Nat, Add Int} → no further type info

→ ATMS amb:
  Assumption A1: constraint = Add Nat
  Assumption A2: constraint = Add Int
  Nogood: {A1, A2}  (mutually exclusive)

For each worldview:
  Install P3 (conditional method activation)
  Run forward checking
  Collect solutions or detect contradiction (nogood)
```

**Commit boundary:** After ATMS branching tests pass.

---

## 7. Level 3: Traits as First-Class Propositions

### Phase 3a: HasMethod Constraint

**Goal:** Enable method projection from trait-polymorphic dictionaries.

**The blocker:** Given `dict : P A` where `P` is unknown, extracting methods
requires knowing P's structure. HasMethod is the minimal viable mechanism.

**New built-in constraint:**

```
HasMethod : (Type → Type) → Symbol → Type → Constraint
```

**Resolver** (new case in trait-resolution.rkt or new file):
1. When resolving `HasMethod P "eq?" T`:
2. If `P` is ground (e.g., `P = Eq`): look up `trait-meta` for `Eq`, find
   method `eq?`, unify method type with `T`
3. If `P` is a meta: residuate (wait for P to solve)
4. The trait registry (`current-trait-registry`, macros.rkt:5195) already stores
   `trait-method` structs with `name` and `type-datum` — this is a query
   against existing data

**Projection primitive:**

```racket
;; Given: dict : P A, method name, HasMethod evidence
;; Produce: the method function extracted from dict
(define (project-method dict-expr trait-meta method-name)
  ;; Single-method trait: dict IS the function → identity
  ;; Multi-method trait: Sigma projection by position
  (if (= 1 (length (trait-meta-methods trait-meta)))
      dict-expr
      (project-sigma dict-expr
                     (method-index trait-meta method-name))))
```

For single-method traits (the majority in Prologos), projection is identity —
the dict IS the function. For multi-method traits (Sigma products), projection
is positional access.

**Surface syntax (from §3.2):**

```prologos
spec apply-method {A : Type} [P A] A A -> Bool
  :over P
  :method P eq? : A A -> Bool
```

The `:method` key elaborates to a `HasMethod` constraint. The projection is
generated automatically when `eq?` is used in the function body with a
trait-polymorphic dictionary.

**Commit boundary:** After HasMethod resolution + projection tests pass.

### Phase 3b: Trait Introspection

**Goal:** Make the trait registry queryable from Prologos surface code.

**Deliverables:**
- `instances-of : <Type -> Type> -> [List Symbol]`
- `methods-of : <Type -> Type> -> [List [Pair Symbol Type]]`
- `satisfies? : Type -> <Type -> Type> -> Bool`
- REPL commands: `:instances`, `:methods`, `:dispatch`, `:satisfies`

**Implementation:** These are foreign functions that query the Racket-side
registries. `instances-of` queries `current-impl-registry`. `methods-of`
queries `current-trait-registry` and extracts `trait-meta-methods`.
`satisfies?` attempts trait resolution and returns success/failure.

**Commit boundary:** Self-contained (foreign function + REPL command additions).

### Phase 3c: Relational Constraint Chain Syntax

**Goal:** Implement `?var:C1:C2:...:Cn` constraint chain for logic variables.

**Reader changes** (`reader.rkt` or ws-reader):
- When reading a `?`-prefixed identifier, check for `:` separators
- Parse `?n:PosInt:Even` as a compound token:
  `(logic-var n :constraints (PosInt Even))`
- Parse `?n:Between[50 100]:Even` as:
  `(logic-var n :constraints ((Between 50 100) Even))`

**Parser changes** (`parser.rkt`):
- Extend `extract-mode-annotation` (parser.rkt:4737) to handle constraint
  chains
- Each constraint is resolved by kind:
  - `Type` → type annotation on the variable
  - `Type → Type` → dispatch cell (trait constraint)
  - `A → Type` → predicate constraint cell

**Elaborator changes:**
- For each constraint in the chain, create the appropriate constraint cell
  in the narrowing network
- Wire bidirectional propagators between the variable's type cell and each
  constraint cell

**Grammar changes** (grammar.ebnf): See §3.4 above.

**Tests:**
```prologos
defr sum-evens [?xs:Nat:Even ?total:Nat]
  (fold add zero ?xs ?total)

;; ?n:Between[50 100] constrains domain
solve [?n:Nat:Even] .{?n * ?n} = 64N
  ;; → ?n = 8N
```

**Commit boundary:** Reader + parser + elaborator changes. May split into
sub-phases (3c-i: reader, 3c-ii: parser, 3c-iii: elaborator integration).

### Phase 3d: Incremental Trait Resolution (Advanced)

**Goal:** Replace batch `resolve-trait-constraints!` with incremental,
network-resident resolution.

**Current:** `resolve-trait-constraints!` (trait-resolution.rkt:305) iterates
the constraint map post-inference.

**Proposed:** Install constraint cells during elaboration. As type information
flows in via the propagator network, constraint cells narrow automatically.
When a cell reaches `constraint-one`, the dict meta is solved immediately —
no batch pass needed.

**Hybrid approach (risk mitigation):** Install constraint propagators during
inference but mark as "deferred." After inference completes, run deferred
propagators to quiescence. This preserves the batch ordering guarantee while
enabling the infrastructure.

**Benefits:**
- Earlier error detection (trait errors during inference, not after)
- Better error messages (constraint cell shows elimination history)
- Bidirectional type↔dispatch during inference
- Removes `current-trait-wakeup-map` (network handles wakeup natively)

**Risk:** Cascading resolution for parametric impls. Mitigated by sub-constraint
cells: resolving `Eq (List Nat)` creates a sub-cell for `Eq Nat`.

**Commit boundary:** Large refactor. Should be its own sub-phase series.

---

## 8. The Unified Constraint Vision

### 8.1 Every Line Is a Type (The Relational Insight)

In Prolog, every clause is a constraint on the space of possibilities. Each
conjunction narrows the venn diagram. The programmer sculpts a shape in
possibility space.

With propagator networks + constraint cells + first-class traits, this becomes
*literal*:

- Each constraint is a cell in the network
- Narrowing is genuinely order-independent (bidirectional propagation)
- "Most constrained first" emerges from propagation dynamics, not programmer
  discipline
- Traits-as-constraints span both paradigms (functional `where` and relational
  `?var:Trait`)

### 8.2 Traits as Domain Constraints in CLP

The constraint cell for a trait IS a CLP(FD) domain variable:

```
;; The impl registry for Add is a finite domain:
{Add Nat, Add Int, Add Rat, Add Posit8, ..., Add String}

;; A constraint cell starts at this domain and narrows:
?T:Add  →  domain(?T) = {Nat, Int, Rat, Posit8, ..., String}

;; Further constraints narrow:
?T:Add:Ord  →  domain(?T) = {Nat, Int, Rat, Posit8, ...}  (String has no Ord)

;; Value constraint narrows further:
.{?x + ?y} = 5N  →  result is Nat  →  domain(?T) = {Nat}
```

This is CLP over type-theoretic domains. The domain isn't a numeric range —
it's the set of types satisfying a constraint conjunction. The propagator
network computes the intersection monotonically.

### 8.3 Homoiconicity: Traits as Quotable Data

Prologos's homoiconicity invariant (LANGUAGE_DESIGN.org § "Homoiconicity: The
Strong Invariant") guarantees every syntactic form has a canonical s-expression
representation. Trait declarations are no exception:

```prologos
;; Trait declaration is quotable as Datum
$[trait Eq {A} eq? : A A -> Bool]
;; → ($trait Eq ($brace-params A) (eq? : (-> A A Bool)))

;; Impl declaration is quotable too
$[impl Eq Nat defn eq? [x y] [nat-eq x y]]
;; → ($impl Eq Nat (defn eq? (x y) (nat-eq x y)))
```

Trait *declarations* are first-class `Datum` values, manipulable by macros and
the quote/quasiquote system. This enables metaprogramming over traits: macros
that generate trait declarations, derive instances, or inspect structure at
expansion time.

The impl *registry* (Racket-side `current-impl-registry`, `current-trait-registry`)
is not directly quotable today. Phase 3b (Trait Introspection) bridges this gap
with foreign functions (`instances-of`, `methods-of`, `satisfies?`) that query
the registry from Prologos surface code. Full registry reification as first-class
data (enabling runtime trait queries as relational goals) is a future direction
that builds on Phase 3b + the relational constraint chain syntax (Phase 3c).

### 8.4 Emergent Capabilities (Speculative)

Following the session types precedent — capabilities that may emerge from
first-class traits but cannot be predicted:

1. **Trait-session duality** — Protocols where each step requires specific
   trait evidence. Composable temporal trait requirements.

2. **Computed trait constraints** — Type-level functions producing trait
   requirements. Bundles become dynamic computation, not static sugar.

3. **Trait-polymorphic modules** — Modules parameterized over which trait to
   provide. Different orderings via different Ord instances.

4. **Evidence-passing as programming pattern** — Users choosing between
   implicit resolution and explicit dictionary passing.

5. **Relational trait queries** — "Find all types satisfying (Eq, Ord, Add)"
   as a logic query over the trait registry.

6. **Trait-parametric propagators** — Propagator cells parameterized over
   *which trait constraint* they track, where the trait is a variable.

---

## 9. Implementation Roadmap

### Phase Overview

| Phase | Deliverable | Effort | Dependencies |
|-------|-------------|--------|-------------|
| **1** | Trait names as type constructors | Small | None |
| **2a** | Static generic operator resolution | Small | None |
| **2b** | `constraint-cell.rkt` module | Small | None |
| **2c** | Constraint propagators (P1-P4) | Medium | 2b |
| **2d** | ATMS multi-candidate search | Medium | 2c |
| **3a** | HasMethod constraint + projection | Medium | 1 |
| **3b** | Trait introspection (REPL + foreign) | Small | 1 |
| **3c** | `?var:C1:C2` constraint chain syntax | Medium | 2b, 2c |
| **3d** | Incremental trait resolution | Large | 2c, 3a |

### Dependency Graph

```
Phase 1 ─────────────────────────────┐
                                     ├─→ Phase 3a (HasMethod)
Phase 2a (static dispatch) ─────┐    │      │
                                │    │      ├─→ Phase 3d (incremental resolution)
Phase 2b (constraint cell) ─────┤    │      │
      │                         │    │      │
      └─→ Phase 2c (propagators)┤    │      │
             │                  │    │      │
             ├─→ Phase 2d (ATMS)│    │      │
             │                  │    │      │
             └──────────────────┼────┼──→ Phase 3c (constraint chain syntax)
                                │    │
                                └────┴──→ Phase 3b (introspection)
```

**Parallel tracks:**
- Phases 1, 2a, 2b can all proceed in parallel (no dependencies)
- Phase 3a (HasMethod) depends only on Phase 1
- Phase 3c (constraint chain) depends on 2b + 2c (needs constraint cells
  in the network)
- Phase 3d (incremental resolution) depends on 2c + 3a

### Suggested Implementation Order

1. **Phase 1** — nearly free, establishes foundation
2. **Phase 2a** — immediate win (fixes narrowing through mixfix)
3. **Phase 2b** — standalone module with unit tests
4. **Phase 3a** — HasMethod while constraint cell is fresh
5. **Phase 2c** — wire constraint cells into propagator network
6. **Phase 2d** — ATMS branching over constraint cells
7. **Phase 3b** — introspection (reward, developer experience)
8. **Phase 3c** — relational constraint syntax
9. **Phase 3d** — incremental resolution (large, careful)

---

## 10. Risks and Mitigations

### Risk 1: Constraint Cell Allocation Overhead

**Concern:** Creating constraint cells for every trait constraint adds
allocations.

**Mitigation:** Demand-driven. Only create cells when narrowing is invoked
(Phase 2c) or during incremental resolution (Phase 3d). Normal type-checking
pays no cost until Phase 3d.

### Risk 2: Cascading Resolution (Parametric Impls)

**Concern:** `impl Eq (List A) where (Eq A)` → resolving `Eq (List Nat)`
triggers sub-constraint for `Eq Nat`.

**Mitigation:** Sub-constraint cells: resolving `Eq (List Nat)` creates a
constraint cell for `Eq Nat`. If already resolved (singleton), no further work.
Propagator network handles dependency naturally.

### Risk 3: Search Space Explosion (Multi-Trait Interaction)

**Concern:** `where (Add A) (Eq A) (Ord A)` → Cartesian product of cells.

**Mitigation:**
- Dispatch cells for same type variable are **correlated** — resolving
  `Add Nat` immediately constrains `Eq Nat`, `Ord Nat`
- Forward propagation eliminates most candidates before search
- ATMS nogoods prune inconsistent combinations
- In practice, type info resolves to singletons without search

### Risk 4: Two-Network Synchronization

**Concern:** Constraint cells in a separate narrowing network may drift from the
elaboration network's type information.

**Mitigation:** The narrowing network is a *consumer* of type information, not a
*producer*. It is created on-demand during `run-narrowing`, reads type info from
the elaboration network (one-way), and is discarded after narrowing completes.
There is no bidirectional synchronization — the narrowing network is ephemeral.

Phase 3d (incremental trait resolution) would unify both into a single network,
eliminating the separation entirely. Until then, the read-only relationship is
a deliberate simplification that avoids interference with the established
type-checking pipeline.

### Risk 5: Reader Complexity for Constraint Chain

**Concern:** `?n:Between[50 100]:Even` is syntactically complex to parse.

**Mitigation:** Phase 3c reader changes are isolated to the `?`-prefix handler.
The constraint chain is greedily parsed: after reading the identifier, consume
`:` + constraint-ref pairs until the next whitespace or non-constraint token.
Parameterized constraints use standard `[]` brackets which the reader already
handles.

### Risk 6: HasMethod Circular Dependencies

**Concern:** Resolving `HasMethod P "eq?" T` requires looking up `trait-meta`
for `P`, but `P` might not be resolved yet.

**Mitigation:** Standard constraint postponement. If `P` is an unsolved meta,
the HasMethod constraint is stored in the postponement queue
(`constraint-postponement.rkt`). When `P` solves, the wakeup mechanism retries
HasMethod resolution. This is the same pattern used for all deferred constraints
in the type checker (trait constraints, universe level constraints, QTT
multiplicity constraints) — no new mechanism required.

### Risk 7: HasMethod for Multi-Method Traits

**Concern:** Positional Sigma projection for multi-method traits is fragile if
methods are reordered.

**Mitigation:** Currently, all Prologos traits are single-method (bundles
expand to multiple single-method constraints). For single-method traits —
which is everything in the language today — projection is identity (the
dictionary IS the function). Multi-method Sigma projection is needed only for
future multi-method traits. If multi-method traits are added, named projection
(by method name, not position) should be used to avoid ordering fragility. The
Sigma projection machinery already exists in the type checker and can be
extended with named field access.

### Trait Coherence

Prologos enforces trait coherence: at most one `impl` per type per trait.
Overlapping instances are a compile-time error, checked by
`check-for-duplicate-impl` in `process-monomorphic-impl` (macros.rkt). This
guarantee is essential for constraint cells — if a trait had multiple impls for
the same type, the dispatch cell could not narrow to a unique resolution.

Coherence is preserved across all three levels:
- **Level 1:** Trait names as type constructors don't affect coherence.
- **Level 2:** Constraint cells assume unique resolution per type; coherence
  guarantees this.
- **Level 3:** HasMethod queries the trait registry, which enforces coherence
  at registration time.

Orphan instance rules (preventing impls in modules that own neither the trait
nor the type) are not yet enforced but are planned for post-Phase 0 module
system hardening.

---

## 11. Error Message Design

Excellent error messages are a core value of Prologos (see ERGONOMICS.org).
Constraint cells introduce new failure modes that require dedicated error codes
and rich diagnostic output. Every error should tell the user *what* went wrong,
*why* it went wrong (the elimination trace), and *how* to fix it.

### 11.1 Error Codes

Following the existing error code conventions (E1xxx = type inference,
E2xxx = capabilities):

| Code | Category | Trigger |
|------|----------|---------|
| **E3001** | Constraint contradiction | All candidates eliminated from a constraint cell |
| **E3002** | Ambiguous constraint | Multiple candidates remain, no further info available |
| **E3003** | Kind mismatch in constraint chain | `?n:Foo` where `Foo` has unexpected kind |
| **E3004** | No impl for union member | `where (Add A)` with `A = Nat \| Foo`, `Foo` has no `Add` |
| **E3005** | HasMethod projection failure | `P` lacks method with required name/signature |
| **E3006** | Constraint chain parse error | Malformed `?var:C1:C2` syntax |

### 11.2 E3001: Constraint Contradiction (Primary Error)

This is the most important error — it fires when all candidates are eliminated.

**Format:**

```
error[E3001]: no trait implementation satisfies all constraints

  ┌─ src/example.prologos:12:5
  │
12│   .{?x + ?y} = "hello"
  │   ^^^^^^^^^^^^^^^^ constraint contradiction
  │
  = candidates for Add:
    - Add Nat      eliminated: result type Nat ≠ String  (via P4, line 12)
    - Add Int      eliminated: result type Int ≠ String  (via P4, line 12)
    - Add Rat      eliminated: result type Rat ≠ String  (via P4, line 12)
    - Add String   eliminated: argument ?x : String, but ?x + ?y used as numeric
                              (via P1, line 10)
  = hint: the result "hello" : String is incompatible with numeric addition.
          Did you mean to use string concatenation (concat)?
```

**Key features:**
- Shows the full candidate set and why each was eliminated
- Traces elimination to specific propagators (P1, P2, P4) and source locations
- Provides an actionable hint

**Implementation:** The constraint cell tracks an *elimination log* — a list of
`(candidate, reason, propagator-id, source-location)` tuples. When the cell
reaches `constraint-top`, the log is formatted into the diagnostic.

### 11.3 E3002: Ambiguous Constraint

Fires when type inference completes but a constraint cell has multiple
candidates and no further information can resolve it.

**Format:**

```
error[E3002]: ambiguous trait dispatch — multiple implementations match

  ┌─ src/example.prologos:8:3
  │
 8│   add ?x ?y
  │   ^^^ ambiguous: Add Nat or Add Int
  │
  = remaining candidates:
    - Add Nat   (if ?x : Nat, ?y : Nat)
    - Add Int   (if ?x : Int, ?y : Int)
  = hint: add a type annotation to disambiguate:
          add (?x:Nat) (?y:Nat)     — for natural number addition
          add (the Int ?x) (the Int ?y) — for integer addition
```

**Key features:**
- Lists remaining candidates with conditions
- Suggests concrete type annotations to disambiguate
- The hint shows *both* possible fixes, not just one

### 11.4 E3003: Kind Mismatch in Constraint Chain

```
error[E3003]: kind mismatch in constraint chain

  ┌─ src/example.prologos:5:10
  │
 5│   defr foo [?n:List:Even]
  │               ^^^^ expected kind (Type → Type) or (A → Type),
  │                    but List has kind (Type → Type) and is a type constructor,
  │                    not a predicate constraint
  │
  = note: List is a type constructor. Did you mean:
          ?n:List[Nat]   — constrain ?n to be a List of Nat
          ?ns:Ord        — constrain elements of ?ns to satisfy Ord
```

### 11.5 E3004: No Impl for Union Member

```
error[E3004]: union type member lacks required trait implementation

  ┌─ src/example.prologos:10:5
  │
10│   spec foo {A : Type} where (Ord A) [A] -> [A]
  │                              ^^^^^ Ord required
  │
  = type A was inferred as: Nat | MyCustomType
  = Ord Nat            — found (prologos::core::ord)
  = Ord MyCustomType   — NOT FOUND
  = hint: add an Ord implementation for MyCustomType:
          impl Ord MyCustomType
            defn compare [x y] ...
```

### 11.6 E3005: HasMethod Projection Failure

```
error[E3005]: trait does not provide required method

  ┌─ src/example.prologos:15:3
  │
15│   spec apply {A : Type} [P A] A A -> Bool
  │     :over P
  │     :method P eq? : A A -> Bool
  │                ^^^ method "eq?" not found in trait
  │
  = P was resolved to: Add
  = Add provides: [add : A A -> A]
  = hint: did you mean Eq? Eq provides eq? : A A -> Bool
```

### 11.7 Implementation: Elimination Log

Each constraint cell carries an elimination log alongside its candidate set:

```racket
(struct constraint-cell
  (candidates         ;; seteq of impl-keys (current live set)
   elimination-log    ;; (listof elimination-entry)
   trait-ref          ;; trait-ref struct (name + arity)
   source-location)   ;; srcloc from the triggering expression
  #:transparent)

(struct elimination-entry
  (candidate          ;; impl-key symbol
   reason             ;; string describing why eliminated
   propagator-id      ;; which propagator fired (P1/P2/P3/P4)
   source-location)   ;; srcloc of the constraining expression
  #:transparent)
```

The elimination log is append-only (monotonic, like everything else in the
network). When the cell reaches `constraint-top`, the log is complete and
provides the full derivation chain for the error diagnostic.

For E3002 (ambiguity), the log shows which candidates were eliminated (partial
progress), helping the user understand why the remaining ones couldn't be
disambiguated.

---

## 12. Future Directions (Beyond Level 3)


### Row Types (Separate Design Track)

Full row polymorphism: extensible records, polymorphic variants, modular
effects. Useful far beyond traits. Worth its own design method session.

With row types, HasMethod becomes a derived constraint: `HasMethod P m T` is
provable from `P A <: { m : T | r }` (row subtyping). The two mechanisms
compose naturally.

### Trait Universe / Reflection

Reify trait structure as type-level data for computation. Would enable
deriving instances via type-level programs, verifying trait laws symbolically,
and computed bundles.

Prerequisite: type-level computation via NbE is partially available. The
question is open type families (extensible by each `trait` declaration).

### Trait-Session Integration

First-class traits + first-class session types = temporal trait requirements.
Protocols where each communication step carries trait evidence. The
propagator network connects session cells and constraint cells bidirectionally.

---

## Appendix A: Code Locations

| Component | File | Lines | Key Items |
|-----------|------|-------|-----------|
| `trait-meta` struct | macros.rkt | 5192 | name, params, methods, metadata |
| `trait-method` struct | macros.rkt | 5188 | name, type-datum |
| `bundle-entry` struct | macros.rkt | 5383 | name, params, constraints, metadata |
| `process-trait` | macros.rkt | 6222-6348 | Trait declaration → deftype generation |
| `process-bundle` | macros.rkt | 5431-5500 | Bundle expansion |
| Trait registry | macros.rkt | 5195 | `current-trait-registry` parameter |
| Spec metadata parser | macros.rkt | 2505-2631 | `parse-spec-metadata` |
| `trait-constraint-info` | metavar-store.rkt | 203-206 | trait-name, type-arg-exprs |
| Trait constraint map | metavar-store.rkt | 212 | `current-trait-constraint-map` |
| Trait wakeup map | metavar-store.rkt | 217 | `current-trait-wakeup-map` |
| Trait cell map | metavar-store.rkt | 230 | `current-trait-cell-map` |
| `resolve-trait-constraints!` | trait-resolution.rkt | 305-317 | Batch post-inference resolution |
| `try-monomorphic-resolve` | trait-resolution.rkt | 130-136 | Concrete type → impl key lookup |
| `try-parametric-resolve` | trait-resolution.rkt | 270-295 | Pattern match → sub-constraint resolution |
| `is-dict-param-name?` | elaborator.rkt | 116-119 | `$`-prefix detection |
| `resolve-method-from-where` | elaborator.rkt | 161-193 | Build accessor expression |
| `builtin-tycon-arity` | syntax.rkt | 934-943 | Type constructor arity table |
| `run-narrowing` | reduction.rkt | 209-233 | Function extraction (gap: no generic support) |
| `extract-mode-annotation` | parser.rkt | 4737-4747 | `?`/`+`/`-` prefix stripping |
| Propagator network | propagator.rkt | 78-258 | Cells, propagators, network API |
| Elaboration network | elaborator-network.rkt | 69-115 | Meta allocation, cell info |
| Type lattice | type-lattice.rkt | 124-142 | Merge function (reference pattern) |

## Appendix B: Design Principles Applied

1. **First-Class by Default** — Traits are made first-class at all three levels.
   Emergent capabilities are expected but not predicted.

2. **Pi Types as Implementation Detail** — `:over`, `:method`, `:has` metadata
   hides second-order quantification. The surface reads as structured metadata.

3. **Compositional, not hierarchical** — Constraint cells compose via set
   intersection. Bundles remain conjunctive sugar. No inheritance.

4. **Propagator-native** — Constraint cells are lattice elements in the network.
   Same CALM guarantees, same ATMS integration, same pure value semantics.

5. **Layered architecture** — Level 1 → 2 → 3, each independently useful,
   each building on the prior. No level precludes the next.

6. **Progressive disclosure** — `?n` (bare), `?n:Nat` (typed),
   `?n:Nat:Even` (constrained), `?n:Between[50 100]:Even` (parameterized).
   Precision added when needed.

7. **Paradigm unification** — Functional `where (Ord A)` and relational
   `?xs:Ord` create the same constraint cell. Different surface, same network.

8. **Demand-driven** — Constraint cells created only when needed. Normal
   compilation pays no cost.

9. **Design for Level 3 from the start** — Phase 2 uses abstract `trait-ref`
   types, not raw symbols. Phase 3 extends without rework.
