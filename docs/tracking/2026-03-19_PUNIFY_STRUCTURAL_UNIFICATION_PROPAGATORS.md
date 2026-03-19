- [Summary](#org54c8eb5)
- [Progress Tracker](#org9880745)
  - [Part 1: Surface Wiring + Baseline](#org62c1317)
  - [Part 2: Cell-Tree Architecture (separate session)](#org6e0cedb)
- [Non-Goals](#org948110a)
- [1. Language Design: The Unification Operator Family](#orgc20dd30)
  - [1.1 Three-Operator Vocabulary — DECIDED](#org0d7c712)
  - [1.2 The Quote-Controls-Evaluation Principle — DECIDED](#orge88ee6b)
  - [1.3 `=` Semantics by Context](#org8f18a93)
    - [1.3.1 Relational Context — DECIDED](#orga55d977)
    - [1.3.2 Expression Context — DECIDED](#orgc9e148e)
    - [1.3.3 Type-Level Context — DECIDED](#org8881cf6)
  - [1.4 `=` on Constructors vs Functions — DECIDED](#org359fdc1)
  - [1.5 Term Decomposition with `|` — DECIDED](#org26c10eb)
  - [1.6 Multi-Way Constraints — DECIDED](#org1c41d83)
  - [1.7 Error Reporting as Provenance Collection — DECIDED](#org207027a)
  - [1.8 Binding Scope — DECIDED](#orga0ad6e8)
  - [1.9 Open Design Questions](#orge0e9c55)
    - [Q1: Dynamic Relations — OPEN (leaning no)](#orgacea18a)
    - [Q2: Source Mapping and Cell Provenance — RESOLVED (scoped to PUnify)](#org2b4c6b6)
    - [Q3: `=` in Guard Position — OPEN](#org7c61252)
- [2. Architecture: Cell-Tree Unification](#org42c246c)
  - [2.1 Current Architecture](#org4ed67cf)
  - [2.2 Cell-Tree Representation](#org12a4f99)
  - [2.3 Unification as Tree Connection](#org01bb863)
  - [2.4 Shared Metas as Wires](#orgc7a9e46)
  - [2.5 Occurs Check as Cycle Detection](#org69ad7dd)
  - [2.6 Zonk Simplification](#org59f0ade)
  - [2.7 ground-expr? as Fan-In Readiness](#org00bbe21)
  - [2.8 Speculation and Cell-Trees](#orgfa02edb)
- [3. Two-Part Implementation Strategy](#org2b7a07e)
- [4. Acceptance File Design](#org2c6871a)
  - [4.1 Section A: Relational `=` — Prolog-Inspired (MUST WORK TODAY)](#org27d9734)
  - [4.2 Section B: Existing Relational Features (MUST WORK TODAY)](#org27754ae)
  - [4.3 Section C: Three-Operator Vocabulary (ASPIRATIONAL — commented)](#orgc7428bc)
  - [4.4 Section D: Expression-Context `=` (ASPIRATIONAL — commented)](#orgab4091c)
  - [4.5 Section E: Term Decomposition (ASPIRATIONAL — commented)](#org0213975)
  - [4.6 Section F: Type-Level `=` (ASPIRATIONAL — commented)](#orgbfb3c7c)
  - [4.7 Section G: Broad Regression Canary (MUST WORK TODAY)](#org4fe9bd2)
- [5. Adversarial Benchmark Design](#orgd0b9c95)
  - [5.1 Stress Patterns](#org904ae4d)
  - [5.2 Measurement](#orgfee8c5b)
  - [5.3 Performance Targets](#org2e9283f)
- [4. Microbenchmark Plan](#orged8fce0)
  - [5.4 Micro-Benchmarks (Part 2, Phase 8)](#org038890b)
  - [5.5 Unification Profile Instrumentation (Part 1, Phase 0c)](#orgeddc84f)
- [6. Migration Path (Part 2 scope)](#org3bfcd53)
  - [5.1 What Changes](#org20922e8)
  - [5.2 What Stays](#orgc3c2f1c)
  - [5.3 Coexistence Strategy](#org86a64fa)
- [7. Performance Budget (Part 2 scope)](#orga21ae02)
- [8. Risk Analysis (Part 2 scope)](#org1a4c113)
  - [High risk: Cell allocation overhead](#org2d31763)
  - [Medium risk: Fire function simplification may not materialize](#orgf0ef745)
  - [Medium risk: Error message quality regression](#orgbaa671c)
  - [Low risk: Speculation interaction](#orgafdf47d)
- [9. Dependencies and Ordering](#org996bfe8)
  - [Depends on (all complete)](#orgc5f31df)
  - [Does NOT depend on](#orga3ad2dc)
  - [Enables](#orgfb6cf79)
- [10. Open Questions (Part 2 scope)](#orgdda3037)
  - [Q1: Lazy vs Eager Tree Creation — OPEN](#orgaff2bb9)
  - [Q2: CHAMP Layout for Cell-Trees — OPEN](#orga422b5b)
  - [Q3: `=` in Guard Position — OPEN](#orgb1da644)



<a id="org54c8eb5"></a>

# Summary

PUnify replaces the current algorithmic unification (pattern-matching fire function inside bidirectional propagators) with *structural unification*: types are represented as trees of cells from the start, and unification is connecting two cell-trees at their roots, letting propagation flow through CHAMP-backed persistent data structures.

This is an independent track from Track 8 (imperative state migration). PUnify depends on Track 7's infrastructure (persistent cells, S(-1) retraction, pure resolution chain) but not on Track 8's other work.

The key bet: CHAMP structural sharing means comparing two cell-trees that share common subtrees is O(diff), not O(size). For real programs where most unifications involve types that share significant structure, this could be very efficient.


<a id="org9880745"></a>

# Progress Tracker

Two-part implementation (§3). Part 1 = surface wiring + baseline. Part 2 = cell-tree architecture (separate session).


<a id="org62c1317"></a>

## Part 1: Surface Wiring + Baseline

| Phase | Description                              | Status | Notes                                                     |
|----- |---------------------------------------- |------ |--------------------------------------------------------- |
| D.1   | Design document (this)                   | 🔄     | Language design resolved (§1), architecture sketched (§2) |
| D.2   | External critique                        | ⬜     |                                                           |
| D.3   | Self-critique                            | ⬜     |                                                           |
| 0b    | Acceptance file                          | ✅     | 163 commands, 13 sections A-M (commit `34a5690`)          |
| 0b.1  | Run acceptance, catalog failures         | ✅     | 7 gaps cataloged in DEFERRED.md (commit `86b7cfc`)        |
| 0a    | `=` pipeline wiring (driven by failures) | ✅     | `=`, `is`, `#=` wired (commits `32d62c6`–`34a5690`)      |
| 0d    | Adversarial benchmark                    | ✅     | 3-tier: micro (43 benchmarks) + comparative (92 commands) (commit `76eb5d2`) |
| 0c    | Baseline current unification             | ✅     | 14.3s median, 0.3% CV. Saved to `data/benchmarks/punify-solve-adversarial-baseline.json` |


<a id="org6e0cedb"></a>

## Part 2: Cell-Tree Architecture (separate session)

| Phase | Description                         | Status | Notes                                    |
|----- |----------------------------------- |------ |---------------------------------------- |
| D.1+  | Architecture design refinement      | ⬜     | Informed by Part 1 baseline data         |
| 1     | Cell-tree infrastructure            | ⬜     | cell-tree struct, allocation, traversal  |
| 2     | Cell-tree unification core          | ⬜     | connect, propagate, contradiction        |
| 3     | Occurs check as cycle detection     | ⬜     | Network topology check                   |
| 4     | Migration of decompose-pi/sigma/app | ⬜     | Lazy decomposition → cell-tree           |
| 5     | Zonk simplification                 | ⬜     | Tree traversal replaces recursive zonk   |
| 6     | ground-expr? as fan-in readiness    | ⬜     | Track 7 Phase 8a infrastructure          |
| 7     | Error message quality               | ⬜     | Tier 1 provenance (propagator srcloc)    |
| 8     | Performance comparison              | ⬜     | A/B: current vs cell-tree on adversarial |
| 9     | Performance validation + PIR        | ⬜     |                                          |


<a id="org948110a"></a>

# Non-Goals

-   Track 8 imperative state migration (meta-info TMS, callback elimination)
-   Layered scheduler (`run-to-layered-quiescence`)
-   Reduction as propagators
-   GDE / minimal diagnoses (Track 9)
-   LSP integration (Track 10)

&mdash;


<a id="orgc20dd30"></a>

# 1. Language Design: The Unification Operator Family


<a id="org0d7c712"></a>

## 1.1 Three-Operator Vocabulary — DECIDED

Prologos uses three operators for equality/matching/constraint, each operating at a distinct level:

| Operator | Level      | Semantics                   | Prolog analog |
|-------- |---------- |--------------------------- |------------- |
| `=`      | Syntactic  | Structural term unification | `=`           |
| `is`     | Semantic   | Evaluate-then-bind          | `is`          |
| `#=`     | Constraint | FL-narrowing (Curry-style)  | CLP(FD) `#=`  |

Each operator does exactly one thing. No context-sensitivity within a given operator — the operator name tells you the evaluation strategy.

`#=` is read as "is constrained to be equal to" (CLP(FD) lineage). It is visually distinct from `=` — the `#` prefix is bold and clearly signals "something different is here." `=.` was considered but rejected as too subtle (the dot is easy to miss in code review).

**WS reader note**: `#=` must be tokenized as a single two-character token, not `#` followed by `=`. Confirm no conflict with future `#`-prefixed reader macros (currently: `#t`, `#f` from Racket heritage, not user-facing in WS mode).


<a id="orge88ee6b"></a>

## 1.2 The Quote-Controls-Evaluation Principle — DECIDED

Quote (`'`) is the boundary between value-world and term-world, in any context. It is not the enclosing form that determines whether subexpressions are evaluated — it is the presence or absence of quote.

| Expression        | Relational context                  | Expression context                   |
|----------------- |----------------------------------- |------------------------------------ |
| `(= [f x y] ?r)`  | Term structure (relational default) | Evaluate `[f x y]`, bind result      |
| `(= '[f x y] ?r)` | Term structure (quote redundant)    | Term structure (quote prevents eval) |

Relational context (`solve`, `defr`) is *implicitly structural* — everything is already in term-world. Expression context is *implicitly evaluating* — quote is the opt-in to term-world.

This is consistent with how quote works in the Lisp tradition: it suspends evaluation. The `=` operator's meaning doesn't change; the evaluation strategy of its operands does.


<a id="org8f18a93"></a>

## 1.3 `=` Semantics by Context


<a id="orga55d977"></a>

### 1.3.1 Relational Context — DECIDED

Inside `solve` and `defr` blocks, `=` is pure structural term unification. Everything is a term, nothing evaluates. Variables prefixed with `?` are logic variables. Failure triggers backtracking.

All terms — constructors, function applications, lambdas — are treated as *syntactic structure* under bare `=`. A function application `[map inc ?xs]` is a 3-element term with head `map`, not a call.

```prologos
;; Structural unification — constructor
(solve [?X ?Y]
  (= [pair ?X ?Y] [pair 1 2]))
;; ?X = 1, ?Y = 2

;; Structural unification — function name is just a symbol
(solve [?result]
  (= [map inc ?xs] ?result))
;; ?result = '[map inc ?xs]  (the TERM, not evaluated)

;; Use `is` to evaluate in relational context
(solve [?result]
  (is ?result [map inc '[1 2 3]]))
;; ?result = '[2 3 4]  (evaluated)

;; Use `#=` to narrow through function definitions
(solve [?x]
  (#= [add ?x 3] 5))
;; ?x = 2  (narrowed: add must be invertible)
```


<a id="orgc9e148e"></a>

### 1.3.2 Expression Context — DECIDED

In expression context, `=` evaluates both sides, then unifies structurally. Bindings scope over the rest of the enclosing block (same as `let`).

```prologos
;; Evaluate-then-unify — destructuring
def result := [compute-pair 42]
(= [pair x y] result)
;; x and y now in scope, bound to pair components
[+ x y]

;; Quote overrides evaluation — structural binding
(= '[map inc ?xs] ?term)
;; ?term = '[map inc ?xs]  (the term, not evaluated)
;; Same behavior as relational context
```

**Failure is a hard type error** — if the structure doesn't match, it's a static error. `=` in expression context is an assertion ("these must be equal"), not a question. For speculative matching, use `match`.

**Bidirectional binding** is the unique capability vs `match`: both sides can have unknowns. `(= [pair ?x 2] [pair 1 ?y])` binds both `?x=1` and `?y=2`. Neither `match` nor `def` can do this. This is *experimental* — bidirectional pattern matching in functional contexts is underexplored in the literature. The acceptance file (§3.2) should exercise this heavily to determine whether it composes well in practice.


<a id="org8881cf6"></a>

### 1.3.3 Type-Level Context — DECIDED

In type positions (`spec`, angle brackets), `=` asserts type equality. Analogous to Haskell's `~` constraint or Coq's `eq`.

```prologos
;; Type equality constraint
spec coerce {A B : Type} (= A B) -> A -> B
defn coerce [x] x
```


<a id="org359fdc1"></a>

## 1.4 `=` on Constructors vs Functions — DECIDED

The constructor/function distinction determines `=` behavior:

| Head symbol  | Under `=`                                                   | Under `is`                        | Under `#=`                |
|------------ |----------------------------------------------------------- |--------------------------------- |------------------------- |
| Constructor  | Structural decomposition (cell-tree)                        | N/A (constructors don't evaluate) | Structural decomposition  |
| Function     | Term binding (relational) / evaluate-then-bind (expression) | Evaluate, bind result             | Narrow through definition |
| Trait method | Same as function                                            | Evaluate via dispatch             | Narrow via instances      |

This distinction is compile-time (constructors from `type` declarations, functions from `defn`). Cell-tree unification handles constructors natively (each argument is a cell). Function applications under bare `=` are opaque terms (relational) or evaluated (expression).


<a id="org26c10eb"></a>

## 1.5 Term Decomposition with `|` — DECIDED

Application terms can be decomposed using the `|` (head/rest) separator inside quoted forms. This is the same mechanism as list destructuring with `'[?head | ?tail]`, operating on application structure:

```prologos
;; List destructuring (existing design)
(= '[1 2 3] '[?h | ?t])           ;; ?h = 1, ?t = '[2 3]

;; Application term destructuring (same mechanism)
(= '[map inc ?xs] '[?f | ?args])  ;; ?f = map, ?args = '[inc ?xs]

;; Deeper decomposition
(= '[foo a b c] '[?f ?first | ?rest])  ;; ?f = foo, ?first = a, ?rest = '[b c]
```

The quote is required — `'[?f | ?args]` decomposes a quoted application term. Without quote, `[?f | ?args]` would be interpreted as function application (calling `?f`). This follows the quote-controls-evaluation principle: quote means "I'm working with term structure."

This subsumes Prolog's `=..` (univ) operator. Where Prolog needs a separate built-in (`foo(a,b) =.. [foo, a, b]`), Prologos handles it through regular `=` with quoted term patterns.

**Design note**: `|` in this position means head/rest (same connotation as list `[H|T]` in Prolog/Erlang). The three uses of `|` in Prologos are syntactically disjoint: union types (`<Int | String>`), multi-arity clauses (`defn foo | pat -> body`), and head/rest in quoted forms (`'[?h | ?t]`).


<a id="org1c41d83"></a>

## 1.6 Multi-Way Constraints — DECIDED

Under PUnify, multiple `=` constraints sharing variables propagate information in parallel through the cell-tree. The fixpoint solver runs all constraints to quiescence — sequential vs parallel ordering is irrelevant when the data structure (shared cells) handles it.

```prologos
;; Shared variables propagate through cell-tree
(= [triple ?a ?b ?c] [triple [f ?x] [g ?x ?y] [h ?y]])
(= [triple ?a ?b ?c] [triple [f 1]  [g 1 2]   [h ?z]])
;; Cell sharing: ?x is the SAME cell in [f ?x] and [g ?x ?y]
;; Solving ?x=1 from equation 2 propagates to equation 1 automatically
;; Result: ?a=[f 1], ?b=[g 1 2], ?c=[h 2], ?x=1, ?y=2, ?z=2
```

In both relational and expression context, PUnify's cell-sharing means information flows the instant it's available. No special sequencing logic.


<a id="org207027a"></a>

## 1.7 Error Reporting as Provenance Collection — DECIDED

In the propagator world, contradictions are data, not exceptions. When `=` fails (structural mismatch), the system does not throw immediately. Instead, it records the contradiction with full cell provenance (which constraint wrote what, from which source location) and continues collecting. All contradictions are surfaced together:

```
Type error: contradictory constraints
  Constraint 1 (line 5):  ?x = Int    (from: (= [pair ?x Bool] ...))
  Constraint 2 (line 8):  ?x = String (from: (= [pair ?x String] ...))
  Cell: meta-42 at position [0] in pair
```

This is strictly better than sequential error reporting — the user sees the full conflict, not just "expected X, got Y" from whichever constraint fired second. If a sequencing-dependent error surfaces, that signals an architectural unsoundness in the prop-network design, which is valuable diagnostic information (but not a user-facing concern).


<a id="orga0ad6e8"></a>

## 1.8 Binding Scope — DECIDED

`(= [pair x y] expr)` introduces `x` and `y` scoping over the rest of the enclosing block (same as `let`). Follows standard lexical shadowing. Unlike `let`, `=` can have unknowns on BOTH sides — `(= [pair ?x 2] [pair 1 ?y])` binds both `?x=1` and `?y=2`.


<a id="orge0e9c55"></a>

## 1.9 Open Design Questions


<a id="orgacea18a"></a>

### Q1: Dynamic Relations — OPEN (leaning no)

Prolog's `assert~/~retract` for runtime clause modification does not map naturally to Prologos. The functional-logic approach is data-as-arguments: relations query data structures, not mutable global clause databases.

```prologos
;; Instead of assert(parent(tom, bob)):
def parents := '{[pair "tom" "bob"] [pair "tom" "liz"]}

defr ancestor [?x ?y ?facts]
  | (member [pair ?x ?y] ?facts)
  | (member [pair ?x ?z] ?facts) (ancestor ?z ?y ?facts)
```

This is more functional, compositional, and testable. Different fact databases for different queries, no global mutable state.

Current leaning: do not support Prolog-style dynamic predicates. Revisit if a compelling use case emerges that data-as-arguments cannot serve.


<a id="org2b4c6b6"></a>

### Q2: Source Mapping and Cell Provenance — RESOLVED (scoped to PUnify)

Full provenance architecture is a Track 10 concern — see `docs/tracking/2026-03-19_TRACK10_DESIGN_NOTES.org` for the two-tier design (Tier 1: creation-time propagator srcloc, always-on; Tier 2: write-log for debug/proof/audit, toggled).

**PUnify's specific contribution**: cell-trees provide natural visual structure for constraint-graph debugging. Each cell-tree IS a type tree — the LSP debugger can render unification as two trees being overlaid, with contradictions highlighted at the mismatch point. This is richer than the current flat-cell model where type structure is implicit.

**PUnify implementation decision**: adopt Tier 1 (propagator-creation srcloc) from the start. When cell-tree unification creates sub-cell propagators during tree unfolding, each propagator records its source location. This costs one CHAMP entry per propagator — negligible, since we're already allocating the propagator. PUnify does NOT need Tier 2 (write logging) for its own correctness; Tier 2 is Track 10 scope.

**Cell-tree nodes stay lean**: no per-node source annotation. Provenance flows through propagator srclocs (Tier 1), not cell metadata. This keeps the hot-path cell operations (read, write, merge, CHAMP comparison) as fast as possible — aligned with the performance bet that PUnify must win.


<a id="org7c61252"></a>

### Q3: `=` in Guard Position — OPEN

Can `=` appear in pattern match guards?

```prologos
defn foo
  | x (= [pair a b] x) -> [+ a b]
  | x -> 0
```

Powerful but adds complexity to the pattern compiler. Defer to post-PUnify if needed.

&mdash;


<a id="org42c246c"></a>

# 2. Architecture: Cell-Tree Unification


<a id="org4ed67cf"></a>

## 2.1 Current Architecture

1.  `elab-add-unify-constraint` creates a bidirectional propagator between two cells
2.  The propagator's fire function calls the unification algorithm (pattern matching, structural decomposition)
3.  For compound types (Pi, Sigma, App), `decompose-pi/sigma/app` creates sub-cells and wires unify propagators between corresponding sub-cells
4.  123 call sites to `unify*` across 11 files

The decomposition already creates cell trees lazily. PUnify makes the tree primary rather than emergent.


<a id="org12a4f99"></a>

## 2.2 Cell-Tree Representation

A cell-tree is a persistent tree of cells where:

-   Each node is a cell (may be bot, ground value, or constructor-tagged with children)
-   The tree unfolds lazily as structure is learned
-   CHAMP structural sharing across trees means shared subtrees are pointer-equal

```
cell-tree for Pi(x : Nat, Vec Nat x):
  root: cell [tag: Pi]
  children:
    [0] domain: cell [value: Nat]     ;; ground leaf
    [1] mult:   cell [value: m1]      ;; ground leaf
    [2] codom:  cell [tag: Vec]       ;; subtree
      children:
        [0] elem: cell [value: Nat]
        [1] len:  cell [value: x]     ;; variable (meta cell)
```

A fresh meta `?A` starts as a single cell (tag unknown, no children). When `?A` is unified with `Pi(Nat, Vec Nat x)`, the cell learns its tag (Pi) and its children unfold.


<a id="org01bb863"></a>

## 2.3 Unification as Tree Connection

Unifying two cell-trees:

1.  Read both root cells
2.  If one is bot (unknown meta): write the other's value to it
3.  If both have the same constructor tag: recursively unify children
4.  If constructor tags differ: contradiction (type error)
5.  If one has a tag and the other is bot: write tag to bot, unfold children, recursively unify

This is the same algorithm as current unification, but the data structure IS the algorithm. No separate fire function with pattern matching — the tree structure guides decomposition naturally.


<a id="orgc7a9e46"></a>

## 2.4 Shared Metas as Wires

The Prolog "wires" pattern:

```
?- f(A, g(A, B), h(B, C)) = f(1, g(X, 2), h(Y, 3))
```

In cell-tree form:

```
Tree 1:                    Tree 2:
  f                          f
  ├── A-cell ─────────────── 1-cell        (A = 1)
  ├── g                      g
  │   ├── A-cell ─────────── X-cell        (A = X)
  │   └── B-cell ─────────── 2-cell        (B = 2)
  └── h                      h
      ├── B-cell ─────────── Y-cell        (B = Y)
      └── C-cell ─────────── 3-cell        (C = 3)
```

The critical insight: A-cell appears TWICE in Tree 1 (positions [0] and [1][0]). It's the SAME cell — not a copy. When A-cell is solved to 1 (from position [0]), the solution is immediately visible at position [1][0], which then propagates to X-cell. This is constraint propagation through shared variables — and it happens automatically through cell read/write, no special wiring needed.


<a id="org69ad7dd"></a>

## 2.5 Occurs Check as Cycle Detection

Current: recursive AST traversal checking if a meta-id appears in an expression.

Cell-tree: occurs check becomes cycle detection in the cell graph. `(= ?A [f ?A])` would attempt to make A-cell a child of itself (through the f-node). This creates a cycle: `A-cell → f-node → A-cell`.

Detection: when connecting cell-trees, check whether the target cell is an ancestor of the source in the tree. If so, occurs check fails.

**Design question**: How expensive is ancestry checking? For shallow trees (depth 2-3, typical for most types), it's trivial. For deep trees (the antagonist patterns), it could be O(depth). Worth measuring.


<a id="org59f0ade"></a>

## 2.6 Zonk Simplification

Current: 3 zonk functions (intermediate, final, level) that recursively traverse expressions, substituting solved metas.

Cell-tree: zonking is tree traversal — read each cell's value. If the cell has a constructor tag and children, recursively read children. If the cell is ground, return the value. If the cell is bot (unsolved meta), return the meta placeholder (intermediate zonk) or default (final zonk).

The distinction between intermediate and final zonk becomes a cell-read strategy:

-   **Intermediate**: read cell, return bot as-is (preserve unsolved metas)
-   **Final**: read cell, default bot to lzero/mw (apply defaults)

This may simplify the 3 zonk variants into 1 parameterized traversal.


<a id="org00bbe21"></a>

## 2.7 ground-expr? as Fan-In Readiness

Current: recursive AST traversal checking for unsolved metas.

Cell-tree: `ground-expr?` is "are all cells in this tree non-bot?" This is exactly the fan-in readiness check from Track 7 Phase 8a. A readiness propagator watching all cells in the tree fires when the tree is fully ground.

This means `ground-expr?` goes from an O(n) traversal per call to an O(1) cell read (the readiness cell). For hot-path functions that call `ground-expr?` thousands of times per command, this could be a significant win.


<a id="orgfa02edb"></a>

## 2.8 Speculation and Cell-Trees

TMS branching operates on individual cells. Cell-tree unification creates trees of cells. When a speculation branch creates new cells (tree unfolding under an assumption), those cells are tagged with the assumption.

On retraction:

-   TMS retraction handles value cells (meta solutions)
-   S(-1) retraction handles scoped cells (constraints, wakeups)
-   Cell-tree nodes created under speculation need either TMS or S(-1)

**Proposed**: Cell-tree nodes are value cells (they hold lattice values — bot, constructor tags, ground values). TMS retraction handles them naturally. No special cell-tree rollback needed — the same mechanism that handles meta cells handles tree cells.

&mdash;


<a id="org2b7a07e"></a>

# 3. Two-Part Implementation Strategy

This track is split into two discrete design/implementation sessions:

**Part 1: Surface wiring + baseline**

1.  Write acceptance file (Phase 0b — diagnostic instrument)
2.  Run it — catalog passes, failures, errors
3.  Wire/fix `=` pipeline based on failures
4.  Write adversarial benchmark (separate file, `bench-ab.rkt` compatible)
5.  Baseline current unification performance with statistical rigor

**Part 2: Cell-tree architecture** (separate session, after Part 1)

1.  Return to architecture design (§2, §9) informed by baseline data
2.  Implement cell-tree unification (Phases 1-7)
3.  A/B comparison: current vs cell-tree on same adversarial benchmarks
4.  Performance validation + PIR

The same tracking document holds context throughout both parts.

Rationale: the acceptance file is a diagnostic instrument — we WANT it to break, because the breaks tell us where to focus. Getting `=` fully wired and baselined before committing to cell-tree architecture gives us concrete data (not just intuition) to design against.


<a id="org2c6871a"></a>

# 4. Acceptance File Design

Location: `racket/prologos/examples/2026-03-19-punify-acceptance.prologos`

The acceptance file serves three purposes:

1.  Validate `=` wiring through the full pipeline (canary)
2.  Exercise resolved language design decisions (aspirational sections)
3.  Broad regression net for existing features

Conventions (same as prior tracks):

-   Uncommented = must pass today; regression if broken after any phase
-   Commented out = aspirational or known-broken (annotated with reason)
-   Each pattern in its own `solve` block for per-command verbose isolation


<a id="org27d9734"></a>

## 4.1 Section A: Relational `=` — Prolog-Inspired (MUST WORK TODAY)

Direct translations of Prolog structural unification examples into Prologos `solve` blocks. These exercise shared-variable constraint propagation — the core of what PUnify's cell-trees will handle.

Translated from examples in `docs/standups/standup-2026-03-18.org`:

| Pattern                                    | Prolog Source                                         | Tests                            |
|------------------------------------------ |----------------------------------------------------- |-------------------------------- |
| Constraint propagation through shared vars | `f(A,g(A,B),h(B,C),i(C,A))`                           | Shared vars act as wires         |
| Circular constraint chain                  | `p(A,B,C,D) = p(X,X,Y,Y)`                             | All vars collapse to same value  |
| Diamond pattern                            | `diamond(top(X),left(X,A),right(X,B),...)`            | Two paths must agree             |
| Nested sharing                             | `outer(inner(A,B),inner(B,C),inner(C,A))`             | Inner constrains outer           |
| Cross-referencing lists                    | `[pair(A,B),pair(B,C),pair(C,A)]`                     | List of structs with shared vars |
| Non-trivial propagation                    | Two separate `=` goals sharing vars                   | Two-equation system              |
| Structure copying                          | `copy(Original,Duplicate) = copy(tree(..),tree(L,R))` | Variable sharing = implicit copy |
| Mutual recursion structure                 | `even/odd` alternating nesting                        | Alternating pattern variables    |
| Graph edge constraints                     | `graph([edge(A,B),edge(B,C),edge(C,A)])`              | Cyclic graph consistency         |
| Substitution/env lookup                    | `subst(var(X),env(X,Val,_),Val)`                      | Self-hosting-relevant pattern    |
| Palindrome structure                       | `palindrome([A,B,C,B,A])`                             | Symmetry via shared vars         |
| Bidirectional list zipper                  | `zip([A,B,C],[X,Y,Z],Zipped)`                         | Three-way constraint             |
| Transpose constraint                       | `matrix(row(A,B),row(C,D))`                           | 2D structure constraints         |

Each pattern as a standalone `eval (solve ...)` with expected results in comments. Use type definitions (via `type`) for constructors where needed (pair, triple, tree, etc.).


<a id="org27754ae"></a>

## 4.2 Section B: Existing Relational Features (MUST WORK TODAY)

Exercises existing relational infrastructure that must not regress:

-   `defr` with fact blocks (`||`) and rule clauses (`&>`)
-   `solve` queries with multiple solutions
-   Recursive relations (transitive closure, like the course prereqs)
-   Unification goals `(= x y)` inside `solve~/~defr`
-   Negation-as-failure `(not (goal))`
-   Mode annotations (`?`, `+`, `-`)
-   Bidirectional querying (same relation, different bound vars)

These overlap with `relational-demo.prologos` but are self-contained here for regression detection.


<a id="orgc7428bc"></a>

## 4.3 Section C: Three-Operator Vocabulary (ASPIRATIONAL — commented)

Side-by-side examples showing `=` vs `is` vs `#=`:

```prologos
;; = : structural term (function name is just a symbol)
;; eval (solve [?r] (= [add 3 4] ?r))
;; Expected: ?r = '[add 3 4]  (the TERM, not evaluated)

;; is : evaluate-then-bind
;; eval (solve [?r] (is ?r [int+ 3 4]))
;; Expected: ?r = 7

;; #= : narrow through function definition
;; eval (solve [?x] (#= [int+ ?x 4] 7))
;; Expected: ?x = 3
```

Uncommented as each operator is wired. `is` may already partially work in relational context.


<a id="orgab4091c"></a>

## 4.4 Section D: Expression-Context `=` (ASPIRATIONAL — commented)

The evaluate-then-unify semantics, bidirectional binding, and quote override:

-   Simple destructuring: `(= [pair x y] some-pair-value)`
-   Bidirectional: `(= [pair ?x 2] [pair 1 ?y])` → `?x=1`, `?y=2`
-   Quote in expression context: `(= '[map inc xs] ?term)` — structural binding, not evaluation
-   Chained `=`: multiple assertions building up bindings sequentially
-   Failure case: structural mismatch → type error

All commented. Uncommented as expression-context `=` is wired.


<a id="org0213975"></a>

## 4.5 Section E: Term Decomposition (ASPIRATIONAL — commented)

The `'[?f | ?args]` syntax:

```prologos
;; List destructuring (existing design)
;; eval (solve [?h ?t] (= '[1 2 3] '[?h | ?t]))
;; Expected: ?h = 1, ?t = '[2 3]

;; Application term destructuring (same mechanism, quoted)
;; eval (solve [?f ?args] (= '[map inc xs] '[?f | ?args]))
;; Expected: ?f = map, ?args = '[inc xs]

;; Deeper decomposition
;; eval (solve [?f ?first ?rest] (= '[foo a b c] '[?f ?first | ?rest]))
;; Expected: ?f = foo, ?first = a, ?rest = '[b c]
```


<a id="orgbfb3c7c"></a>

## 4.6 Section F: Type-Level `=` (ASPIRATIONAL — commented)

Equality constraints in specs:

```prologos
;; spec coerce {A B : Type} (= A B) -> A -> B
;; defn coerce [x] x
```


<a id="org4fe9bd2"></a>

## 4.7 Section G: Broad Regression Canary (MUST WORK TODAY)

Standard Prologos features unrelated to `=` wiring, confirming no regressions from pipeline changes:

-   Prelude imports (`ns` with default prelude)
-   Pattern matching (`defn` with multi-arity dispatch)
-   Generic arithmetic (`+`, `-`, `*` via traits)
-   Pipeline (`|>`)
-   Closures (`fn`, partial application with `_`)
-   List/Option/Result operations
-   Trait definitions and instances
-   Map literals and dot-access
-   Module loading (at least one `use` statement)

These serve the same role as the "broad safety net" in prior acceptance files.


<a id="orgd0b9c95"></a>

# 5. Adversarial Benchmark Design — COMPLETE

Three-tier benchmark suite established, all baselines captured.

## 5.1 Benchmark Suite Structure

### Tier 1: Solver Micro-Benchmarks (`benchmarks/micro/bench-solver-unify.rkt`)
19 micro-benchmarks with statistical rigor (warmup, multi-sample, Tukey outlier detection):

| Section | Benchmarks | What It Measures |
|---------|-----------|-----------------|
| unify-terms decomposition | 5 | Deep (50 levels), wide (100 children), binary trees (511 nodes), late failure |
| walk/walk* traversal | 5 | Chain subst (100-500 vars), wide subst (100 keys), walk* deep nesting |
| normalize-ast-to-solver-term | 3 | Lambda, application, deeply nested expressions |
| Combined patterns | 6 | Growing subst, transitive chains, partial overlap |

**Key findings:**
- Deep unification (50 levels): **37ms** — linear in depth as expected
- Late failure = same cost as success: **38ms** — no early termination optimization exists
- Walk chain-500: **9.5ms** — O(n) linear traversal, no path compression
- Binary tree (511 nodes): **4ms** — efficient for tree structures
- Transitive chain (100 vars): **28ms** — substitution growth is the bottleneck

### Tier 2: Solve Pipeline Micro-Benchmarks (`benchmarks/micro/bench-solve-pipeline.rkt`)
24 micro-benchmarks for full solve pipeline with controlled relation stores:

| Section | Benchmarks | What It Measures |
|---------|-----------|-----------------|
| Fact-only relations | 4 | 10-1000 facts, linear scan cost |
| Clause chains | 3 | 5-50 depth, recursive clause resolution |
| Backtracking | 3 | First/last/fail search positions |
| Multi-hop joins | 4 | 2-5 hop joins × 5 facts each |
| Conjunction depth | 3 | 10-200 goals per clause |
| Diamond joins | 3 | 5-50× fan-out with convergence |
| Inline unify goals | 4 | `=` inside inline `rel` blocks |

**Key findings:**
- 5-hop × 5-way join: **236ms** — exponential DFS cost, no tabling
- Diamond 50×50: **27ms** — linear in fan-out
- Conjunction 200 goals: **27ms** — linear in conjunction length
- DFS solver **cannot handle recursive relations** (diverges even with ground queries)

### Tier 3: Comparative A/B Benchmark (`benchmarks/comparative/solve-adversarial.prologos`)
92 commands across 14 sections for `bench-ab.rkt` comparison:

| Section | Commands | Pattern |
|---------|----------|---------|
| S1 | 5 | Simple structural `=` |
| S2 | 4 | Deep constructor terms |
| S3 | 4 | Nat unification (Peano chains) |
| S4 | 3 | Fact-heavy defr (12 facts, backtracking) |
| S5 | 4 | Multi-goal conjunction (3-8 way) |
| S6 | 4 | `is` goals (evaluate-then-bind) |
| S7 | 5 | Prelude constructor unification |
| S8 | 20 | Many small solve blocks (per-command overhead) |
| S9 | 4 | Narrowing via `#=` |
| S10 | 4 | solve-one (first-answer cutoff) |
| S11 | 3 | Shared variables across goals |
| S12 | 10 | Repeated solve over same relation |
| S13 | 12 | Named defr with `&>` conjunction |
| S14 | 3 | Complex inline relations |

**Baseline: 14.3s median, 0.3% CV** (15 runs). Saved to `data/benchmarks/punify-solve-adversarial-baseline.json`.

## 5.2 Measurement

Run via `bench-ab.rkt` (flags before path):

```shell
racket tools/bench-ab.rkt --runs 15 benchmarks/comparative/solve-adversarial.prologos
```

Compare after changes with `--ref HEAD~N`. Per-command metrics available via `process-file #:verbose #t`.

## 5.3 Performance Targets

| Metric                    | Target                         |
|------------------------- |------------------------------ |
| PUnify on simple patterns | ≤ 1.5× current                 |
| PUnify on deep structural | ≤ 1.0× current (potential win) |
| PUnify on wide fan-out    | ≤ 1.0× current (CHAMP sharing) |
| Suite regression          | ≤ 10% (200s budget)            |

## 5.4 Key Learnings from Benchmarking

1. **Late failure = success cost**: The current solver has no early termination — a mismatch at the last position costs the same as full success. PUnify's cell-tree approach could improve this if contradiction detection short-circuits.

2. **Walk chains are O(n)**: No path compression in the current substitution walker. For PUnify, cell-tree sharing means walk is replaced by cell read (O(1) for ground cells).

3. **DFS solver diverges on recursive relations**: The flat solver (`relations.rkt`) has no tabling or cycle detection. Even ground queries against 3-element transitive closure diverge. The `defr`/`solve` pipeline uses stratification to avoid this, but the micro-benchmark API does not. PUnify should consider whether tabling is in scope.

4. **Multi-hop joins are exponential**: 5-hop × 5-way join = 236ms. This is inherent to DFS backtracking, not a unification issue. PUnify won't fix this (it's a search strategy problem, not a unification problem).

5. **`defr` with `|` clause form doesn't register relations** (HIGH PRIORITY): The WS wiring for `defr name [params] | pattern -> body` silently fails. Only `||` (facts) and `&>` (conjunction) forms work. This is captured in DEFERRED.md and the acceptance file §B6. **Fixing WS wiring gaps is the highest-priority pre-PUnify work** — a productive language requires working surface syntax.

6. **Per-command overhead dominates small benchmarks**: The 20 small `solve (= ?x N)` commands in S8 are individually sub-millisecond, but the per-command pipeline setup is the dominant cost. PUnify's persistent network should amortize this.

## 5.5 Micro-Benchmarks for Part 2 (Phase 8)

Use `bench-micro.rkt` for function-level A/B comparison:

-   Single unification: meta-vs-ground, 1 level, 3 levels, 5 levels
-   Occurs check: shallow (depth 1) vs deep (depth 10)
-   ground-expr? on ground tree vs partially-solved tree
-   Zonk traversal: current recursive vs cell-tree traversal

## 5.6 Unification Profile Instrumentation (future, if needed)

The micro-benchmarks in Tier 1+2 provide sufficient baseline data for PUnify design. Full instrumentation of `unify*` and `elab-add-unify-constraint` (call count, classification, decomposition depth, wall time breakdown) is deferred unless the micro-benchmarks prove insufficient for Part 2 design decisions.

&mdash;


<a id="org3bfcd53"></a>

# 6. Migration Path (Part 2 scope)


<a id="org20922e8"></a>

## 5.1 What Changes

| Component           | Current                                    | PUnify                               | Migration                                   |
|------------------- |------------------------------------------ |------------------------------------ |------------------------------------------- |
| Type representation | expr structs (AST)                         | Cell-trees (prop-network)            | Gradual — cell-trees coexist with AST       |
| Unification         | `make-unify-propagator` fire function      | Tree connection + propagation        | Replace fire function internals             |
| Decomposition       | `decompose-pi/sigma/app` (lazy, on-demand) | Tree unfolding (lazy, on cell write) | Migrate decompose functions                 |
| Occurs check        | Recursive AST traversal                    | Cycle detection in cell graph        | New implementation                          |
| Zonk                | 3 recursive functions                      | Tree traversal (read cells)          | Simplify to 1 parameterized traversal       |
| ground-expr?        | Recursive AST traversal                    | Fan-in readiness cell                | New implementation + Track 7 infrastructure |
| Error messages      | AST-based mismatch reporting               | Cell-position-based reporting        | New provenance wiring                       |


<a id="orgc3c2f1c"></a>

## 5.2 What Stays

-   `elab-add-unify-constraint` API (callers don't change)
-   TMS/S(-1) retraction (handles cell-tree nodes like any other cell)
-   Stratified resolution (constraints, traits, hasmethods — unchanged)
-   Persistent registry network (unchanged)
-   Pure resolution chain (unchanged — cell-tree is internal to S0)


<a id="org86a64fa"></a>

## 5.3 Coexistence Strategy

During implementation, both approaches coexist:

-   Belt-and-suspenders: run both, compare results
-   Toggle: `current-use-cell-tree-unify?` parameter
-   Gradual: migrate one type constructor at a time (Pi first, then Sigma, then App, &hellip;)

&mdash;


<a id="orga21ae02"></a>

# 7. Performance Budget (Part 2 scope)

| Metric                           | Current                  | Target                    | Rationale                                   |
|-------------------------------- |------------------------ |------------------------- |------------------------------------------- |
| Cells per meta                   | 1 (+ lazy decomposition) | ~3-5 (tree depth)         | Cell-tree unfolds on demand                 |
| Unify propagators per constraint | 1 (bidirectional)        | 1 per tree level          | More propagators but simpler fire functions |
| ground-expr? cost                | O(n) traversal           | O(1) cell read            | Fan-in readiness                            |
| Zonk cost                        | O(n) recursive           | O(n) tree traversal       | Similar asymptotic, different constant      |
| Occurs check cost                | O(n) AST traversal       | O(depth) ancestry check   | Better for shallow, similar for deep        |
| Suite time                       | 181.2s                   | ≤ 200s (≤ 10% regression) | Allow overhead for richer infrastructure    |

&mdash;


<a id="org1a4c113"></a>

# 8. Risk Analysis (Part 2 scope)


<a id="org2d31763"></a>

## High risk: Cell allocation overhead

Cell-trees create more cells than current approach. For 50 metas with average tree depth 3, that's ~150 cells vs ~50. CHAMP handles this (designed for hundreds of cells), but measure.

**Mitigation**: lazy unfolding — only create child cells when structure is learned. A meta that's unified with a ground value never unfolds.


<a id="orgf0ef745"></a>

## Medium risk: Fire function simplification may not materialize

The current fire function does pattern matching + decomposition. Cell-tree's "connect and propagate" still needs constructor tag comparison. The simplification may be more conceptual than practical.

**Mitigation**: microbenchmark the fire function overhead before and after.


<a id="orgbaa671c"></a>

## Medium risk: Error message quality regression

Current error messages reference AST positions directly. Cell-tree errors need cell-to-source mapping. If this mapping is lossy, error quality degrades.

**Mitigation**: cell-info metadata (already in elab-network) can carry source locations. Extend with tree-position information.


<a id="orgafdf47d"></a>

## High risk: WS wiring gaps block productive use

The `defr` with `|` clause form silently fails to register relations — only `||` and `&>` forms work. This means pattern-matching dispatch in relational definitions is broken at the surface level. Until WS wiring gaps are fixed, PUnify's improvements are invisible to users writing `.prologos` files. **Fix WS wiring before or in parallel with PUnify implementation.**


<a id="orgafdf47d"></a>

## Low risk: Speculation interaction

Cell-tree nodes are standard value cells. TMS retraction handles them. No special machinery needed.

**Mitigation**: the 55 Track 7 post-fix tests for retraction exercise the exact mechanisms.

&mdash;


<a id="org996bfe8"></a>

# 9. Dependencies and Ordering


<a id="orgc5f31df"></a>

## Depends on (all complete)

-   Track 7: persistent cells, S(-1) retraction, pure resolution chain
-   Track 7 post-fix: retraction correctness (net-cell-replace), identity preservation


<a id="orga3ad2dc"></a>

## Does NOT depend on

-   Track 8: meta-info TMS, callback elimination, mult/level/session migration
-   Track 9: GDE
-   Track 10: LSP


<a id="orgfb6cf79"></a>

## Enables

-   Track 8: cell-tree unification simplifies the id-map accessibility problem (cell-trees manage their own sub-cells; id-map is less central)
-   Track 9: cell-tree provenance provides natural GDE integration points
-   Track 10: cell-tree observation gives LSP per-position type information

&mdash;


<a id="orgdda3037"></a>

# 10. Open Questions (Part 2 scope)


<a id="orgaff2bb9"></a>

## Q1: Lazy vs Eager Tree Creation — OPEN

Should cell-trees be created eagerly (allocate full tree when type structure is known) or lazily (unfold on demand during unification)?

Lazy matches current behavior (decompose-on-demand). Eager enables fan-in readiness from the start. Measure the cell allocation cost to decide.


<a id="orga422b5b"></a>

## Q2: CHAMP Layout for Cell-Trees — OPEN

Option A: Constructor-tagged n-ary trees (mirrors AST). Option B: Path-indexed cells (paths as CHAMP keys).

Option A is more natural. Option B may compose better with CHAMP internals. Need microbenchmark data.


<a id="orgb1da644"></a>

## Q3: `=` in Guard Position — OPEN

Can `=` appear in pattern match guards?

```prologos
defn foo
  | x (= [pair a b] x) -> [+ a b]
  | x -> 0
```

This is powerful but adds complexity to the pattern compiler. Defer to post-PUnify if needed.
