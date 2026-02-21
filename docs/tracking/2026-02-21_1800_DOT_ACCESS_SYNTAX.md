# Map Key Access Syntax (Dot-Access)

**Created**: 2026-02-21
**Status**: COMPLETE (Phases A-C)

## Goal

Add ergonomic surface syntax for map key access:
- `user.name` → `[map-get user :name]` (dot-access)
- `.:name user` → `[map-get user :name]` (dot-key prefix for piping)

## Prerequisite: Module Path Migration

Reclaiming `.` required migrating module paths from `prologos.data.list` to `prologos::data::list`.

## Phases

### Phase A: Module Path Migration (`.` → `::`) — DONE
- [x] A1: Core namespace logic (namespace.rkt) — split-qualified-name, ns->path-segments, prelude-requires
- [x] A2: dep-graph.rkt (303 occurrences) — symbols, regexes, string-split
- [x] A3: Hardcoded FQNs in Racket source (~12) — typing-core, elaborator, reduction, etc.
- [x] A4: Library .prologos files (91 files, 261 occurrences)
- [x] A5: Test .rkt files (~99 files, ~1429 occurrences)
- [x] A6: Example files (3 files) + run-affected-tests.rkt + update-deps.rkt
- [x] A verification: 3039 tests pass, dep-graph clean
- Commit: `04a7732`

### Phase B: Reader Changes — DONE
- [x] B1: Remove `.` from `ident-continue?`
- [x] B2: Extend dot tokenization (`.ident` → `'dot-access`, `.:kw` → `'dot-key`)
- [x] B3: Add `'dot-access` and `'dot-key` to `parse-inline-element`
- [x] B5: 3039 tests pass, reader correctly splits `user.name` into two tokens
- Commit: `a3f4b13`

### Phase C: Preparse Macro — DONE
- [x] C1: `rewrite-dot-access` function in macros.rkt
- [x] C2: Integrate before infix rewriting in `preparse-expand-subforms`
- [x] C3: End-to-end tests in `test-dot-access.rkt` (21 tests: 7 unit, 7 reader, 3 sexp E2E, 4 WS E2E)
- 3060 tests pass (135 files)

### Phase D: Nil-Coalescing `#:` — DEFERRED

## Key Design Decisions

- **No new AST nodes**: dot-access desugars entirely at preparse level to `map-get` calls
- **Sentinel pattern**: Reader emits `($dot-access field)` and `($dot-key :keyword)` sentinels, preparse macro rewrites them
- **Ordering**: Dot-access rewrites run before infix operators (`|>`, `>>`) so `user.name |> f` works
- **Standalone `.:kw`**: Produces `(fn ($x : _) (map-get $x :kw))` for use in map/pipe expressions
- **Module separator**: `::` (already supported for qualified names) replaces `.` for hierarchy

## Files Changed

| File | Changes |
|------|---------|
| `namespace.rkt` | split-qualified-name uses LAST `::`, ns->path-segments splits on `::`, ~40 prelude entries |
| `dep-graph.rkt` | 303 symbol entries, scanner regexes, string-split |
| `typing-core.rkt` | 6 FQN strings |
| `elaborator.rkt` | 1 FQN string |
| `reduction.rkt` | 2 FQN strings |
| `trait-resolution.rkt` | 1 FQN string |
| `pretty-print.rkt` | 1 FQN string |
| `macros.rkt` | 1 FQN string + `rewrite-dot-access` function + integration |
| `reader.rkt` | `ident-continue?`, dot handler, `parse-inline-element` |
| `run-affected-tests.rkt` | path construction |
| `update-deps.rkt` | module name construction |
| `lib/**/*.prologos` | 91 files |
| `tests/*.rkt` | 99 files + new `test-dot-access.rkt` |
| `examples/*.prologos` | 3 files |
