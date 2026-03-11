# WS-Mode Full-Language Audit Report

**Date**: 2026-03-10
**Scope**: All language features exercised in `.prologos` WS-mode files via `process-file`
**Method**: 12 audit files, ~300 expressions, classified by outcome

## Summary

| Code | Count | Meaning |
|------|-------|---------|
| **OK** | ~250 | Works correctly in WS-mode `.prologos` file |
| **CRASH** | 36 | Error or exception during execution |
| **WRONG** | 6 | Runs but produces incorrect result |
| **DESIGN** | 7 | Works as designed but design is limiting |
| **SEXP-ONLY** | 0 | (not encountered — all forms tested have WS syntax) |
| **DEFN-ONLY** | 0 | (not encountered separately from CRASH) |
| **MISSING** | 0 | (not encountered — features exist but may fail) |

**Key stat**: ~83% of expressions work correctly. The remaining ~17% cluster around a small number of root causes.

## Audit Files

All files at `racket/prologos/examples/audit/`:

| File | Area | Errors | Status |
|------|------|--------|--------|
| `audit-01-literals-types` | Literals & base types | 0 | Clean (1 WRONG, 1 CRASH commented) |
| `audit-02-def-spec-defn` | Definitions & signatures | 0 | Clean (2 CRASH commented) |
| `audit-03-data-constructors` | ADTs & constructors | 10 | Multiple ctor issues |
| `audit-04-match-if-cond` | Pattern matching & conditionals | 0 | Clean (1 WRONG annotated) |
| `audit-05-fn-let-do` | Lambdas, let, do | 0 | Clean (3 CRASH, 1 DESIGN commented) |
| `audit-06-traits-instances` | Traits & instances | 0 | Clean (3 CRASH commented) |
| `audit-07-collections` | Collections & operations | 13 | HOF/inference issues |
| `audit-08-narrowing-logic` | Narrowing & logic | 0 | 3 WRONG annotated |
| `audit-09-numerics` | Numeric tower | 0 | Fully clean |
| `audit-10-pipe-compose` | Pipe, compose, transducers | 6 | HOF/arity issues |
| `audit-11-modules-imports` | Module system | 4 | HOF/preparse issues |
| `audit-12-advanced` | Advanced features | 3 | Quote/quasiquote issues |

## Root Cause Clusters

### Cluster 1: Constructor-as-HOF-Argument (10 instances, HIGH priority)

**Symptom**: `[map suc '[1N 2N 3N]]` → "Unbound variable"
**Affected**: `suc`, nullary constructors (`North`, `South`), any constructor passed to `map`, `filter`, `pvec-map`, `set-map`, `lseq-map`, `map-map-vals`, block pipe steps.
**Root cause**: Data constructors are not first-class functions in the WS elaboration path. They work in pipe (`0N |> suc`) and direct application (`[suc 2N]`) but cannot be passed as arguments to higher-order functions.
**Instances**: audit-07 (x5), audit-10 (x2), audit-11 (x1), audit-03 (x2 for nullary ctors)
**Impact**: Users must wrap constructors in lambdas: `(fn [x : Nat] [suc x])` instead of bare `suc`.

### Cluster 2: Type Inference for Generic/Polymorphic Operations (8 instances, HIGH priority)

**Symptom**: "Could not infer type" for operations with trait constraints or complex polymorphism
**Affected operations**:
- `sort`, `dedup` — need Ord/Eq constraint, not resolved from list literal
- `opt::unwrap-or` — polymorphic option unwrap fails inference
- `set-singleton` — can't infer set type from bare value
- `into-vec`, `into-list` — collection conversion inference fails
**Root cause**: Top-level expressions with polymorphic functions that need trait resolution can't gather enough type information from the argument alone.
**Impact**: These operations may work inside `defn` bodies with spec annotations but fail at top level.

### Cluster 3: WS-Mode Preparse Gaps (8 instances, MEDIUM priority)

**Symptom**: Various preparse/parse errors for valid language forms
**Affected forms**:
- `def- x := val` — "def requires: ..." (private def not recognized)
- `let x := val` at top level — "missing value after :="
- `def x := (fn ...)` — "Could not infer type" (fn as def value)
- Multi-clause `defn f | pat -> body` — "spec is single-arity but defn has multiple clauses"
- `defn` inside `impl` block — "defn requires: ..."
- `with-transient` multi-step macro — "expected 2 args"
- `def x := suc` — constructor as def value
**Root cause**: Preparse (`macros.rkt:preparse-expand-all`) doesn't handle all WS-mode form variants. The preparse works at the sexp level but WS-mode indentation grouping produces different AST shapes.

### Cluster 4: User-Defined Data Constructors (5 instances, HIGH priority)

**Symptom**: `data` definitions produce broken constructors
**Issues**:
- Nullary constructors (`North`, `South`) defined as function type `Direction -> Direction` instead of value
- Multi-field constructors (`Rect : Nat Nat -> Shape`) — "Expression is not a valid type"
- Polymorphic constructors (`MkBox`) — "Unbound variable" after definition
- `deftype` as type synonym — "deftype requires: ..."
**Root cause**: `data` form in WS mode has fundamental issues with constructor generation — only single-field constructors of non-polymorphic types work.

### Cluster 5: Reader-Level Syntax Conflicts (5 instances, MEDIUM priority)

**Symptom**: Certain syntax forms conflict with the WS reader
**Affected**:
- `'a'` char literals conflict with `'` quote/list-literal prefix (audit-01)
- `'foo` quote conflicts with list-literal prefix in WS mode (audit-12)
- `'(a b c)` quote of s-expression fails (audit-12)
- `` `(hello ,x world) `` quasiquote fails (audit-12)
- `.{3N = 3N}` — `=` inside mixfix conflicts with narrowing rewrite (audit-06)
**Root cause**: The WS reader repurposes `'` for list literals, which prevents standard quote syntax. The `=` operator has special handling in the narrowing/equality rewrite pass.

### Cluster 6: Narrowing Correctness (4 instances, MEDIUM priority)

**Symptom**: Narrowing returns wrong or empty results
**Issues**:
- `my-double ?x = 6N` → over-generates `[{:x 6N} {:x 5N} {:x 4N} {:x 3N}]` — only x=3 is valid (audit-08)
- `[suc ?n] = 3N` → `nil` — should find n=2N (audit-08)
- `[suc [suc ?n]] = 5N` → `nil` — should find n=3N (audit-08)
- `my-and ?a ?b = true` → `nil` — boolean narrowing through `if` returns empty (audit-08)
**Root cause**: Narrowing search doesn't fully propagate equality constraints (over-generation), and constructor-based narrowing (`suc`) doesn't work with the equality operator.

### Cluster 7: Spec/Constraint Interaction (1 instance, LOW priority)

**Symptom**: `spec f {A : Type} (Eq A) A A -> Bool` with `defn f [a b]` → "type has 1 type parameters but defn has 2 params"
**Root cause**: `inject-spec-into-defn` miscounts arity when trait constraints like `(Eq A)` are present.

### Cluster 8: Arity/Name Collisions (4 instances, LOW priority)

**Symptom**: Wrong arity or wrong function called
**Issues**:
- `[range 1N 5N]` — "Too many arguments" (range takes different args)
- `[into-list A B xf coll]` — "Too many arguments" (transducer into-list clashes with collection into-list)
- `5/1` parsed as Int `5` not Rat (audit-01) — reader simplifies
**Root cause**: Prelude imports create name collisions between modules (transducer `into-list` vs collection `into-list`), and some function signatures differ from expected ergonomic form.

## What Works Well

These areas are **fully functional** in WS-mode `.prologos` files:

1. **All literal types**: Nat, Int, Rat, Posit, Bool, String, Keyword, Unit
2. **Basic definitions**: `def`, `spec`/`defn`, `spec-`/`defn-` (private)
3. **Pattern matching**: `match` on Nat/Bool/List/Option/Result — correct in defn bodies
4. **Conditionals**: `if` (in defn), `cond` — work correctly in function bodies
5. **Sequential `let` in defn**: scopes correctly with chaining
6. **Lambda with explicit types**: `(fn [x : Nat] body)` in map/filter
7. **All numeric operations**: Nat, Int, Rat, Posit32 arithmetic and comparison
8. **Prelude trait dispatch**: `eq-check`, `ord-compare`, `.{+ - * < <=}` operators
9. **Pipe and compose**: `|>` binary pipe, `>>` compose
10. **Narrowing**: Basic `add ?x ?y = 5N`, mixfix `.{?x + 3N} = 7N`, equality mode
11. **Collection primitives**: Map creation/access/mutation, PVec filter/fold, LSeq creation/conversion
12. **Postfix indexing**: `xs[0]`, `m[:key]`, `nested[:db][:port]`, `m.field`
13. **Module system**: FQN access, `ns` with prelude, qualified aliases
14. **check/infer/eval/the**: All meta-programming forms work
15. **Dependent types**: Polymorphic `{A : Type}` specs, dep-id function
16. **User-defined traits**: `trait` definition works (but `impl` blocks fail)

## Prioritized Repair Backlog

### Priority 1: CRASH — Blocks Basic Usage

| # | Issue | Cluster | Effort | Files |
|---|-------|---------|--------|-------|
| 1a | Constructor-as-HOF (suc in map/filter) | C1 | M | elaborator, typing-core |
| 1b | User data constructors (nullary/multi-field/poly) | C4 | L | parser, elaborator |
| 1c | defn inside impl block | C3 | M | macros.rkt (preparse) |
| 1d | spec + constraint arity mismatch | C7 | S | macros.rkt:inject-spec-into-defn |
| 1e | def with fn value fails | C3 | S | macros.rkt or elaborator |
| 1f | Top-level let | C3 | M | macros.rkt (preparse) |

### Priority 2: WRONG — Incorrect Results

| # | Issue | Cluster | Effort | Files |
|---|-------|---------|--------|-------|
| 2a | Narrowing over-generates (my-double) | C6 | M | reduction.rkt (narrowing) |
| 2b | suc/bool narrowing returns nil | C6 | M | reduction.rkt (narrowing) |
| 2c | Top-level if type is `_` | — | S | typing-core.rkt |
| 2d | 5/1 parsed as Int 5 | C8 | S | reader.rkt |

### Priority 3: CRASH — Advanced Features

| # | Issue | Cluster | Effort | Files |
|---|-------|---------|--------|-------|
| 3a | Type inference for sort/dedup/unwrap-or etc. | C2 | L | typing-core, trait resolution |
| 3b | Quote/quasiquote reader conflict | C5 | M | reader.rkt |
| 3c | = inside mixfix | C5 | S | macros.rkt (rewrite pass) |
| 3d | def- in WS mode | C3 | S | macros.rkt (preparse) |
| 3e | with-transient macro in WS mode | C3 | S | macros.rkt |
| 3f | Multi-clause defn syntax | C3 | M | macros.rkt |
| 3g | Char literal reader conflict | C5 | M | reader.rkt |
| 3h | Transducer into-list name collision | C8 | S | namespace.rkt (prelude) |

### Effort Legend
- **S** (Small): 1-2 hours, localized fix
- **M** (Medium): 2-4 hours, may touch multiple files
- **L** (Large): 4+ hours, architectural consideration needed

### Suggested Repair Sprint Order

1. **Quick wins** (1d, 1e, 2c, 2d, 3c, 3d, 3e, 3h) — 8 small fixes, ~1 day
2. **Constructor-as-HOF** (1a) — single systemic fix, unblocks ~10 expressions
3. **Preparse gaps** (1c, 1f, 3f) — grouped preparse work, ~1 day
4. **Data constructors** (1b) — significant work, unblocks user-defined types
5. **Narrowing correctness** (2a, 2b) — narrowing search improvements
6. **Type inference** (3a) — complex, may need bidirectional inference improvements
7. **Reader conflicts** (3b, 3g) — reader architecture changes

---

## Commits

- `41d6711` — audit-01 + run-file.rkt tool
- `e0e0a03` — audit-02
- `8a92675` — audit-03 + audit-04
- `d7d2c0b` — audit-05 + audit-06
- `2ce0e75` — audit-07 through audit-12
