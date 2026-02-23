# Mixfix Syntax `.{...}` Implementation

**Date:** 2026-02-23
**Branch:** `feature/mixfix-syntax`
**Status:** COMPLETE (4 phases)
**Design doc:** [2026-02-23_MIXFIX_SYNTAX_DESIGN.org](2026-02-23_MIXFIX_SYNTAX_DESIGN.org)

## Summary

Delimited infix mode for Prologos: `.{a + b * c}` desugars to `[add a [mul b c]]`. Named precedence groups form a partial-order DAG (Swift/Rhombus model). User-definable via `precedence-group` and `:mixfix` spec metadata.

## Motivation

Heavily nested prefix arithmetic is hard on the eyes even for experienced Lispers. Inspired by Tcl's `expr` sublanguage — a scoped infix mode that preserves homoiconicity (all `.{...}` forms have canonical sexp `($mixfix ...)` equivalents).

## Phases

### Phase 1: Core Reader + Pratt Parser (commit `025443f`)

**Reader changes** (`reader.rkt`):
- Tokenizer: `.{` produces `dot-lbrace` token, increments bracket depth
- WS tree builder: `parse-mixfix-form` reads elements until `}`, wraps with `$mixfix` sentinel
- `parse-mixfix-element`: Intercepts `<`, `>`, `<=`, `>=`, `::` inside `.{...}` as operator symbols (not type annotation delimiters)
- Sexp readtable (`sexp-readtable.rkt`): `.{...}` convenience in sexp mode

**Pratt parser** (`macros.rkt`):
- `$mixfix` registered as a preparse procedural macro
- Standard precedence DAG with 9 groups:

```
pipe < logical-or < logical-and < comparison < additive < multiplicative < exponential < unary-prefix < composition
                                              < cons (right)
```

- 20 built-in operators: `+`, `-`, `*`, `/`, `%`, `**`, `==`, `!=`, `<`, `<=`, `>`, `>=`, `&&`, `||`, `::`, `++`, `|>`, `>>`
- `>` and `>=` use argument swapping: `.{a > b}` → `(lt b a)` — avoids needing `gt`/`ge` parser keywords
- Wildcards pass through: `.{_ + 1}` creates a partial application via existing placeholder machinery

**Tests:** 36

### Phase 2: User-Defined Precedence Groups (commit `67f3922`)

- `precedence-group` top-level form: declares name, associativity, tighter-than relationships
- `:mixfix` key on `spec`: `{:symbol op :group group-name}` auto-registers operators
- `effective-operator-table` / `effective-precedence-groups`: merge builtin + user-defined at Pratt parse time
- Dynamic binding power recomputation when user groups extend the DAG

**Tests:** 46 (+10)

### Phase 3: Chained Comparisons + Diagnostics (commit `825bf37`)

- Chained comparisons: `.{a < b <= c}` → `(and (lt a b) (le b c))`
  - Middle operands shared via `last-chain-rhs` tracking in Pratt loop
  - Supports mixed chains: `.{a < b > c}` → `(and (lt a b) (lt c b))`
- Incomparable-group detection: `.{a :: b + c}` errors with "no defined precedence relationship — use [] for explicit grouping"
- Better error messages with source location

**Tests:** 58 (+12)

### Phase 4: Pattern Matching in `.{...}` (commit `6a9920e`)

- Pattern flattening in `parse-reduce-arm` (`parser.rkt`): `$mixfix` expansion produces `((cons h t))` in match arms; flattener detects single-element wrapper and unwraps to `(cons h t)` for correct ctor-name + bindings extraction
- **Bug fix:** bracket-depth double-increment in `parse-mixfix-form` — tokenizer already increments on `.{` and decrements on `}`, so manual increment left depth=1 after `}`, breaking WS pipe-arm splitting for subsequent `|` match arms
- E2E tests for both sexp `($mixfix h :: t)` and WS `.{h :: t}` match patterns

**Tests:** 65 (+7)

## Files Modified

| File | Changes |
|------|---------|
| `reader.rkt` | `.{` tokenizer, `parse-mixfix-form`, `parse-mixfix-element`, bracket-depth fix |
| `sexp-readtable.rkt` | `.{...}` sexp reader extension |
| `macros.rkt` | Pratt parser, precedence DAG, `$mixfix` macro, `:mixfix` metadata, `precedence-group` form |
| `parser.rkt` | Pattern flattening in `parse-reduce-arm` |
| `elaborator.rkt` | `neq` keyword support |
| `tests/test-mixfix.rkt` | 65 tests across all phases |
| `tools/dep-graph.rkt` | Test dependency entry |

## Operator Table

| Operator | Function | Group | Assoc | Notes |
|----------|----------|-------|-------|-------|
| `+` | `add` | additive | left | |
| `-` | `sub` | additive | left | |
| `*` | `mul` | multiplicative | left | |
| `/` | `divide` | multiplicative | left | |
| `%` | `mod` | multiplicative | left | |
| `**` | `pow` | exponential | right | |
| `==` | `eq` | comparison | none | Chainable |
| `!=` | `neq` | comparison | none | Chainable |
| `<` | `lt` | comparison | none | Chainable |
| `<=` | `le` | comparison | none | Chainable |
| `>` | `lt` (swap) | comparison | none | Chainable |
| `>=` | `le` (swap) | comparison | none | Chainable |
| `&&` | `and` | logical-and | right | |
| `\|\|` | `or` | logical-or | right | |
| `::` | `cons` | cons | right | |
| `++` | `append` | additive | left | |
| `\|>` | `$pipe-gt` | pipe | left | |
| `>>` | `$compose` | composition | right | |

## Key Design Decisions

1. **Named precedence groups (DAG)** over numeric levels — prevents the "magic number" problem and catches ambiguity between unrelated operators at compile time
2. **Swap-based `>`/`>=`** — reuses existing `lt`/`le` parser keywords via argument swap, avoiding 5-file pipeline changes for new keywords
3. **Chained comparisons** with shared operands — `.{a < b <= c}` is mathematically natural and avoids redundant `&&` conjunctions
4. **Incomparable groups error** — `cons` and `additive` have no precedence relationship, forcing explicit grouping rather than surprising defaults
5. **`$mixfix` as preparse macro** — fits existing macro infrastructure, sexp mode `($mixfix ...)` works identically to WS `.{...}`

## Deferred

- **Statement-like forms** in `.{...}` (e.g., assignment) — keep purely expression-oriented
- **`do` notation** inside `.{...}` — prefer `do` blocks for monadic code
- **`functor :compose` auto-registration** — adds coupling between functors and mixfix
- **Extended pattern matching** (e.g., `.{n + 1}` → `suc n`) — possible future enhancement

## Test Suite Impact

- **65 new tests** in `test-mixfix.rkt`
- **2871 total tests** across 132 files, all passing
- No regressions in existing test suite
