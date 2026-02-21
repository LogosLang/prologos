# Implicit Map Syntax

**Created**: 2026-02-21
**Status**: COMPLETE

## Goal

Add ergonomic implicit map syntax where indentation-based keyword-value blocks
desugar to map literals, similar to YAML but homoiconic:

```
def app-config
  :server
    :host "localhost"
    :port 8080
  :database
    :url "postgres://localhost/mydb"
```

desugars to:

```
def app-config {:server {:host "localhost" :port 8080} :database {:url "postgres://localhost/mydb"}}
```

## Design

- **No new AST nodes**: Implicit maps desugar entirely at preparse level to `$brace-params` sentinels
- **Reader already produces correct structure**: `def m\n  :name "Alice"` → `(def m (:name "Alice"))`
- **Detection rule**: A def/defn form with a tail of keyword-headed sublists triggers rewriting
- **Scope restriction**: Only fires for `def`/`defn` head forms (not arbitrary function calls)
- **Nested maps**: `(:key (:k2 v2) (:k3 v3))` → `:key ($brace-params :k2 v2 :k3 v3)`
- **Dash children**: `(:items (- (:k1 v1)) (- (:k2 v2)))` → `:items ($vec-literal ...)`
- **Ordering**: Runs before dot-access and infix operator rewrites in `preparse-expand-subforms`

## Implementation

Only `macros.rkt` changed (+ new test file + dep-graph entry). No changes to reader, parser, elaborator, syntax, or surface-syntax.

### New functions in macros.rkt (~80 lines):

1. `keyword-headed?` — list whose car starts with `:`
2. `dash-headed?` — list whose car is `-`
3. `all-keyword-or-dash-headed?` — all elements match
4. `has-keyword-tail?` — datum has non-empty keyword-headed suffix
5. `split-keyword-tail` — split into prefix + keyword tail
6. `process-implicit-map-child` — convert `(:key ...)` to key + processed value
7. `process-dash-child` — convert `(- ...)` to PVec element
8. `implicit-map-children->brace-params` — keyword children → `($brace-params ...)`
9. `rewrite-implicit-map` — top-level detection and rewriting

### Hook in preparse-expand-subforms:

Runs as first pass (before dot-access and infix) since it reshapes overall form structure.

## Tests

21 tests in `test-implicit-map.rkt`:
- 11 unit tests for `rewrite-implicit-map` function
- 2 sexp-mode E2E tests
- 8 WS-mode E2E tests (basic, nested, dot-access, type-annotated, inline vector, computed value, non-interference)

## Files Changed

| File | Changes |
|------|---------|
| `macros.rkt` | ~80 lines: `rewrite-implicit-map` + helpers, hook in `preparse-expand-subforms`, export |
| `tests/test-implicit-map.rkt` | New file, ~200 lines, 21 tests |
| `tools/dep-graph.rkt` | 1 new test entry |

## Verification

- 3081 tests pass (136 files), up from 3060
- Zero regressions
