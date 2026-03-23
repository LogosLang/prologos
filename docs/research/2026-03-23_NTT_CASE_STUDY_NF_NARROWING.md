# NTT Deep Case Study: NF-Narrowing

**Stage**: 1 (Case Study)
**Date**: 2026-03-23
**Purpose**: Full NTT specification of the NF-Narrowing system. Test
structural lattice, SRE derivation, demand-driven evaluation, and
propagator dynamics. Compare against the Type Checker case study.

---

## 1. Lattices

### 1.1 Term Lattice (Structural)

```prologos
data TermValue
  := term-bot                                      ;; no information
   | term-var [id : CellId]                        ;; unbound logic variable
   | term-ctor [tag : Symbol] [sub-cells : [CellId ...]]  ;; constructor
   | term-top                                      ;; contradiction
  :lattice :structural
  :bot term-bot
  :top term-top
```

**Implementation status**: NETWORK-NATIVE.
- `term-merge` in `term-lattice.rkt` is the merge function
- Cells hold term values on the propagator network
- Merge is monotone: `bot → var → ctor → top` (one-way)
- Structural decomposition: `ctor(tag, sub-cells)` carries cell
  references for sub-terms — same pattern as TypeExpr

**NTT observation**: TermValue has the same `expr-meta`-like problem
as TypeExpr: `term-var [id : CellId]` and `term-ctor [sub-cells : [CellId ...]]`
contain network references (cell IDs) as lattice values. In the ideal
architecture, these would be sub-cells managed by the SRE, not explicit
IDs embedded in values.

However, there's an important difference: in narrowing, `term-var`
represents a *logic variable* (a cell that may be unified with a value
later), not a metavariable. The cell reference IS the semantics — a
logic variable IS a cell. This is more natural than TypeExpr's `expr-meta`,
which conflates "placeholder for inference" with "lattice value."

**Verdict**: The SRE structural lattice model applies, but `term-var`
as a cell reference may be legitimate (it IS a first-class reference
to another cell in the network). The NTT may need a concept of
"cell references as values" — a `Ref Cell L` type in the lattice.

### 1.2 Definitional Tree (Configuration Data, Not a Lattice)

```prologos
;; Definitional trees are NOT lattice values — they're pure data
;; extracted once at definition time, stored in a registry.

data DefTree
  := dt-rule [rhs : Expr]                         ;; leaf: rewrite rule
   | dt-branch [position : Nat]                    ;; interior: case split
               [type-name : Symbol]
               [children : Map Symbol DefTree]
   | dt-or [branches : [DefTree ...]]              ;; overlap: non-determinism
   | dt-exempt                                     ;; undefined (partial fn)
```

**Implementation status**: FULLY CONSTRUCTED.
- Extracted by `extract-definitional-tree` at definition time
- Stored in `current-def-tree-registry` (Racket parameter)
- Read-only during narrowing — never modified

**NTT observation**: The definitional tree is not a cell value — it's
configuration that determines WHICH propagators to install. It's closer
to a `network` template than a lattice. The DT is the "program" that
the narrowing evaluator runs by walking it and installing propagators.

In NTT terms: the DT is the data that parameterizes a `network` template.
A `functor` over DefTree that produces a NarrowingNet:

```prologos
functor NarrowingNetFor {dt : DefTree}
  interface
    :inputs  [args : Cell TermValue ...]
    :outputs [result : Cell TermValue]
```

---

## 2. Cells

### 2.1 Argument Cells

```prologos
;; One cell per function argument position
cell arg-cell : Cell TermValue
  :lifetime :speculative

;; When narrowing a call `[f x y z]`:
;; - Create arg-cells for x, y, z
;; - Write known argument values to cells
;; - Install narrowing propagators from f's definitional tree
;; - Result flows to result-cell via propagation
```

### 2.2 Result Cell

```prologos
cell result-cell : Cell TermValue
  :lifetime :speculative
```

### 2.3 Binding Cells (Pattern Variables)

```prologos
;; Each pattern variable in a definitional tree branch becomes a cell
;; Accumulated as the DT is walked, indexed by de Bruijn position
cell binding-cell : Cell TermValue
  :lifetime :speculative
```

**Implementation status**: ALL NETWORK-NATIVE.
- Created during DT walk (`install-narrowing-propagators`)
- Binding cells are the sub-cells of constructor decomposition
- No imperative state — bindings are a pure list of cell-ids
  threaded through the DT walk

---

## 3. Propagators

### 3.1 Branch Propagator (SRE-Like Dynamic Installation)

```prologos
;; Watches an argument cell at a DT branch position.
;; When the cell value becomes a constructor, dispatches on the tag
;; and installs sub-propagators for the matching child subtree.

propagator narrow-branch
  :reads  [scrutinee : Cell TermValue]
  :writes [result : Cell TermValue]
  ;; DYNAMIC: when fired, may install additional propagators
  ;; from the matched DT child subtree
```

**Implementation**: `make-branch-fire-fn` in `narrowing.rkt`
- Reads scrutinee cell value
- If `term-bot` or `term-var`: **residuate** (return net unchanged)
- If `term-ctor(tag, sub-cells)`: look up `tag` in DT children,
  install propagators for child subtree with sub-cells as new bindings
- If `term-top`: propagate contradiction

**NTT observation**: This is the dynamic propagator installation pattern
from the architecture survey. The branch propagator creates new
propagators when fired — it's a **propagator factory** at runtime.

The SRE resolves this partially: structural decomposition of `term-ctor`
into sub-cells is SRE-native. But the DT dispatch (which child subtree
to walk) is NOT structural decomposition — it's program-specific logic
that reads from the DT configuration data.

**Verdict**: Branch propagators are partially SRE-native (constructor
decomposition) and partially user-logic (DT dispatch). The NTT needs
to express: "this propagator decomposes structurally, then dispatches
on external data." This is the `functor`-parameterized propagator pattern
— the DT is the functor parameter.

### 3.2 Rule Propagator (Pure Evaluation)

```prologos
;; Watches all binding cells for a rule.
;; When all bindings are ground (non-bot), evaluates RHS and writes result.

propagator narrow-rule
  :reads  [bindings : Cell TermValue ...]
  :writes [result : Cell TermValue]
  ;; Guard: all bindings must be non-bot
  ;; Body: evaluate RHS expression using binding values
```

**Implementation**: `make-rule-fire-fn` in `narrowing.rkt`
- Reads all binding cell values
- If any is `term-bot`: **residuate** (return net unchanged)
- If all non-bot: evaluate RHS (`eval-rhs`) → write to result cell
- RHS evaluation: constructor application, variable lookup by de Bruijn index

**NTT observation**: This is a clean, non-dynamic propagator. Static
reads/writes, guarded by a groundness precondition on all inputs.
The NTT `propagator` form handles this directly.

The guard condition ("all bindings non-bot") is a `:where` on the
propagator — or more precisely, it's inherent in the lattice: the
propagator is a monotone function that maps `(bot, ...) → no change`
and `(ground, ..., ground) → result`. The monotonicity contract handles
the guard automatically.

### 3.3 Structural Unify Propagator (Shared with Type Checker)

```prologos
;; Reused from elaborator-network.rkt
;; Bidirectional: reads both cells, computes merge, writes back

propagator structural-unify
  :reads  [a : Cell TermValue, b : Cell TermValue]
  :writes [a : Cell TermValue, b : Cell TermValue]
  ;; Merge: term-merge(read(a), read(b)) → write to both
```

**Implementation**: `make-structural-unify-propagator` from PUnify
- Same propagator used for both type unification and term unification
- Only difference: lattice merge function (type-lattice-merge vs term-merge)
- Parameterized by merge function — **this IS the SRE in action**

**NTT observation**: The structural unify propagator is parameterized
by lattice type. It works on any structural lattice. This is the SRE's
universal structural decomposition primitive — it handles TypeExpr,
TermValue, and SessionExpr uniformly. The NTT types this as a
polymorphic propagator over `{L : Lattice :structural}`.

---

## 4. Network

```prologos
interface NarrowingNet
  :inputs  [args : Cell TermValue ...
            def-tree : DefTree]         ;; configuration, not a cell
  :outputs [result : Cell TermValue]

network narrowing-eval : NarrowingNet
  ;; Dynamically constructed by walking the definitional tree
  ;; Each DT node installs propagators:
  ;;   dt-branch → branch propagator + recursive walk
  ;;   dt-rule → rule propagator
  ;;   dt-or → ATMS amb choices (speculation)
  ;;   dt-exempt → no propagator (partial function gap)
```

**NTT observation**: The network is NOT statically declared — it's
**dynamically constructed** by walking the DT. This is a key difference
from the type checker, which has a static network topology (fixed strata,
fixed bridges). The narrowing network's topology depends on the DT
structure AND the runtime values of argument cells (branch propagators
install sub-propagators based on cell values).

This is the fundamental challenge: **the network topology is data-dependent.**
The DT determines the potential topology; runtime cell values determine
which parts are actually instantiated.

In polynomial functor terms: the NarrowingNet is a **mode-dependent**
polynomial functor — the number and types of sub-cells depend on which
DT branches are taken, which depends on constructor tags in cells.
This IS the "dependent polynomial functor" open question from the
Categorical Foundations document (§9.1).

**Gap**: The NTT `network` form assumes static topology (embed, connect).
NF-Narrowing requires dynamic topology. This is a genuine gap — we need
either:
1. A `dynamic-network` form that describes potential topology (from DT)
2. The SRE's structural decomposition handling dynamic installation
3. A `functor` that produces networks from DT configuration data

Option 3 is most aligned with derive-not-declare: the DT IS the spec,
the SRE derives the network from it.

---

## 5. Stratification

```prologos
;; NF-Narrowing operates within S0 of the type checker's stratification.
;; It does NOT have its own stratification — it's an embedded sub-network.

;; In NTT terms:
stratification TypeCheckerLoop
  :fiber S0
    :networks [type-net narrowing-net session-net mult-net]
    ;; narrowing-net is embedded alongside type-net
    ;; They share S0 quiescence
```

**Implementation status**: CORRECT.
- Narrowing propagators fire during S0 quiescence alongside type propagators
- No separate stratification needed — narrowing is monotone within S0
- The type checker's S0 → S1 → S2 loop handles trait resolution for
  narrowed types

**NTT observation**: Narrowing as an embedded sub-network in S0 is clean.
The `embed` mechanism in `network` handles this. No special syntax needed.

---

## 6. Demand-Driven Evaluation (Residuation)

The core evaluation model:

```
When a branch propagator fires on scrutinee:
  term-bot  → residuate (no-op, wait for info)
  term-var  → residuate (no-op, wait for binding)
  term-ctor → dispatch on tag, install child propagators

When a rule propagator fires on bindings:
  any bot   → residuate (no-op, wait for all bindings)
  all ground → evaluate RHS, write result
```

**NTT observation**: Residuation is NOT a special mechanism — it's a
natural consequence of monotone propagators on a lattice with `bot`.
A propagator that reads `bot` and returns the network unchanged IS
residuating. The demand-driven semantics fall out of the lattice order.

This is beautiful: **residuation is free.** No explicit suspension/
resumption mechanism needed. The propagator simply doesn't fire when
its preconditions aren't met (because `bot` → no change is monotone).
The next write to the input cell re-enqueues the propagator.

The NTT captures this implicitly: a propagator on a structural lattice
with `:bot` naturally residuates on incomplete inputs.

---

## 7. Bridges

### 7.1 Narrowing → Type Inference

```prologos
;; When narrowing produces a ground result, the type checker uses it.
;; This is currently implicit — narrowing cells feed into type cells
;; via reduction (reduce calls narrow, narrow returns a value,
;; reduce writes it to a type cell).

bridge NarrowingToType
  :from TermValue
  :to   TypeExpr
  :alpha term->type   ;; extract type from narrowing result
  ;; One-way: narrowing results inform type inference
```

**Implementation status**: IMPLICIT.
- No explicit bridge declaration
- Narrowing and type inference share cells via reduction
- `reduce` in `reduction.rkt` calls narrowing search, converts result
  to type expression, writes to type cell
- This is a procedural bridge, not a declarative one

**NTT gap**: The narrowing→type bridge is procedural (called from
`reduce`), not declarative (a bridge declaration with α). Making it
declarative would require:
1. Separate narrowing cells from type cells (currently they share)
2. An α function that maps TermValue → TypeExpr
3. The bridge fires when narrowing cells become ground

This is an instance of the "everything in S0" pattern — narrowing and
type inference share the same network and cells, so there's no explicit
bridge. The bridge is implicit in cell sharing.

---

## 8. Comparison: NF-Narrowing vs Type Checker

| Aspect | Type Checker | NF-Narrowing |
|--------|-------------|-------------|
| **Lattice** | TypeExpr (structural, complex) | TermValue (structural, simple) |
| **Network topology** | Static (fixed strata, fixed bridges) | Dynamic (DT-dependent) |
| **Propagator types** | Inference + readiness + bridge | Branch + rule + unify |
| **Stratification** | Own (S-neg1 to S2) | Embedded in Type Checker S0 |
| **Demand model** | Eager (infer everything) | Lazy (residuate on bot) |
| **Fixpoint** | lfp via quiescence | lfp via quiescence (same) |
| **Imperative debt** | HIGH (126 box sites) | LOW (minimal, mostly network-native) |
| **SRE applicability** | HIGH (structural decomposition) | HIGHEST (DT IS the structural spec) |
| **Dynamic installation** | PUnify (structural decomp) | Branch propagators (DT walk) |
| **Bridge to other systems** | Explicit (TypeToMult, etc.) | Implicit (cell sharing) |

---

## 9. What the Case Study Reveals

### 9.1 NF-Narrowing is the Most Network-Native System

Unlike the type checker (126 imperative box sites), NF-Narrowing has
almost zero imperative state. Cells, propagators, and the DT structure
are all pure/network-native. The binding list is purely functional
threading. This makes narrowing the closest existing system to the
NTT ideal.

### 9.2 Dynamic Network Topology is a Real Gap

The type checker has static topology (strata, bridges, sub-networks
known at design time). NF-Narrowing has data-dependent topology
(which propagators exist depends on which DT branches are taken,
which depends on runtime cell values). The NTT `network` form
assumes static topology.

Resolution options:
1. **DT as `functor` parameter**: The NTT types the POTENTIAL topology
   (all possible DT paths) and the runtime instantiates a subset.
   This is the polynomial functor's mode-dependency.
2. **SRE handles it**: Branch propagators ARE structural decomposition
   of function definitions — the SRE derives them from the DT just as
   it derives type decomposition from `data` definitions.
3. **Accept dynamic as inherent**: Some networks are inherently dynamic.
   The NTT types the fixed parts (lattice, merge, monotonicity) and
   leaves topology to runtime.

Option 2 is most aligned: the DT IS the structural specification, just
as `data TypeExpr := ...` is the structural specification for types.
The SRE derives narrowing propagators from DTs just as it derives
unification propagators from type definitions. This would extend the
SRE from "structural forms derived from type definitions" to
"structural forms derived from type AND function definitions."

### 9.3 Residuation as Free Consequence

The case study confirms: demand-driven evaluation doesn't need explicit
suspension/resumption. Residuation falls out of monotone propagators on
lattices with `bot`. This is a powerful validation of the
propagator-first approach — a key evaluation strategy is structurally
guaranteed, not programmed.

### 9.4 Cell References as Lattice Values

`term-var [id : CellId]` in TermValue is a cell reference embedded in
a lattice value. Unlike `expr-meta` in TypeExpr (which is an impedance
mismatch), `term-var` is semantically meaningful — a logic variable IS
a reference to a cell. The NTT may need a `Ref Cell L` concept for
lattice values that legitimately reference other cells.

### 9.5 The SRE's Scope Expands

The Type Checker case study showed the SRE handling type lattice merge.
The NF-Narrowing case study shows the SRE potentially handling function
definition decomposition. The SRE's scope is: **any structural
specification** (type definitions, function definitions, session
protocols) that can be decomposed into sub-cells.

This means the SRE form registry should include:
- Type constructors (from `data` definitions)
- Function patterns (from definitional trees)
- Session protocol steps (from session type definitions)
- Coinductive observations (from `codata` definitions)

All four are "polynomial summands" — structural forms that decompose
into sub-cells. The SRE handles them uniformly.

---

## 10. Source Documents

| Document | Relationship |
|----------|-------------|
| [NTT Syntax Design](../tracking/2026-03-22_NTT_SYNTAX_DESIGN.md) | Syntax being validated |
| [Architecture Survey](2026-03-22_NTT_ARCHITECTURE_SURVEY.md) | Breadth-first survey |
| [Type Checker Case Study](2026-03-22_NTT_CASE_STUDY_TYPE_CHECKER.md) | Companion deep case study |
| [SRE Research](2026-03-22_STRUCTURAL_REASONING_ENGINE.md) | SRE scope expansion |
| [Categorical Foundations](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) | Mode-dependent polynomials (§9.1) |
