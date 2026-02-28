# Nil Type + Safe Navigation (`#.`/`#:`)

**Date**: 2026-02-27
**Status**: COMPLETE
**Plan**: `.claude/plans/buzzing-launching-pascal.md`
**Test count**: 4583 (38 new in `test-nil-type.rkt`)

---

## Summary

Added `Nil` type, overloaded `nil` value, nil-safe map access (`nil-safe-get`),
`#.`/`#:` WS-mode syntax, `A?` nilable type sugar, and `nil?` predicate.

Closes DEFERRED.md items:
- Mixed-Type Maps: `A?` nilable sugar
- Dot-Access Phase D: nil-safe navigation

---

## Phases

### Phase 1a: `expr-Nil` Type Node (14-file pipeline)
- New ground type at universe level 0, like `Unit` and `Bool`
- `(struct expr-Nil () #:transparent)` in syntax.rkt
- Type rule: `infer(expr-Nil) = Type(lzero)`
- Sort key: `"0:Nil"` in unify.rkt
- Added to `known-type-name?` in macros.rkt

### Phase 1b: `expr-nil` Value + Nil Overloading
- `nil` is a parser keyword: `(surf-nil loc)` instead of `(surf-var 'nil)`
- Overloading semantics:
  - `infer(nil)` → `List ?A` (backward compat, fresh meta)
  - `check(nil, Nil)` → OK, stays as `expr-nil`
  - `check(nil, List A)` → OK, elaborates to list's nil constructor
  - `check(nil, V | Nil)` → OK via existing union check
- Reduction updates: `racket-list->prologos-list`, `prologos-list->racket-list`,
  `try-as-list` in pretty-print, value recognition
- **Full suite passed after Phase 1b** — backward compat verified

### Phase 2: `expr-nil-safe-get` AST Node
- `nil-safe-get : (Map K V | Nil) -> K -> (V | Nil)`
- Type rule: Nil input → Nil; Map input → V|Nil; union → extract Map Vs + Nil
- Reduction: nil input → nil; CHAMP lookup → value or nil on miss; non-map → nil
- 10-file pipeline: syntax, surface-syntax, parser, elaborator, typing-core,
  qtt, reduction, substitution, zonk, pretty-print

### Phase 3: Reader `#.`/`#:` + Preparse Rewriting
- Reader `#` dispatch extended: `#.field` → nil-dot-access token, `#:key` → nil-dot-key token
- Sentinel production: `($nil-dot-access field)`, `($nil-dot-key :keyword)`
- Preparse rewrite: left-fold producing `nil-safe-get` calls (parallel to dot-access)
- Mixed access: `user#.address.city` → `(map-get (nil-safe-get user :address) :city)`

### Phase 4: `A?` Nilable Type Sugar
- Parser-level: `String?` → `(surf-union String Nil)` when uppercase + `?` suffix + known type
- No reader change needed: `?` is already `ident-continue?`
- No conflict with predicates: `empty?`, `nil?` are lowercase

### Phase 5: `nil?` Predicate
- `nil? : A -> Bool`
- Reduction: `nil → true`; ground values (zero, suc, int, rat, string, keyword,
  char, champ, hset, rrb, posit*, pair, fvar) → `false`; stuck otherwise
- 10-file pipeline

### Phase 6: Tests + Grammar + Docs
- `tests/test-nil-type.rkt`: 38 test-cases across sections A-K
- Grammar updates: `grammar.ebnf` (Nil type, nilable-type, nil-safe-get,
  #./#: reader tokens) + `grammar.org` (prose + examples)
- DEFERRED.md: Phase D and A? marked complete
- dep-graph.rkt: test entry added

---

## Files Modified

| File | Changes |
|------|---------|
| `syntax.rkt` | 4 new structs: `expr-Nil`, `expr-nil`, `expr-nil-safe-get`, `expr-nil-check` |
| `surface-syntax.rkt` | 4 new structs: `surf-nil-type`, `surf-nil`, `surf-nil-safe-get`, `surf-nil-check` |
| `parser.rkt` | 4 keywords + `A?` sugar in `parse-datum` |
| `elaborator.rkt` | 4 new cases |
| `typing-core.rkt` | Type rules for Nil type, nil overloading, nil-safe-get, nil-check |
| `qtt.rkt` | 4 new inferQ cases |
| `reduction.rkt` | Value recognition, list helpers, nil-safe-get CHAMP rules, nil-check |
| `substitution.rkt` | 4 pass-throughs (shift + subst) |
| `zonk.rkt` | 4 pass-throughs in 3 zonk functions |
| `pretty-print.rkt` | Display + try-as-list update + uses-bvar0? |
| `unify.rkt` | union-sort-key for Nil |
| `macros.rkt` | known-type-name + nil-dot predicates + rewrite-nil-dot-access |
| `reader.rkt` | `#` dispatch extension + sentinel production |
| `grammar.ebnf` | Nil type, nilable-type, nil-safe-get, #./#: tokens |
| `grammar.org` | Prose + examples for Nil, A?, #./#:, nil-safe-get |
| `tests/test-nil-type.rkt` | NEW — 38 tests |
| `tools/dep-graph.rkt` | test entry |
| `DEFERRED.md` | Mark Phase D + A? complete |

---

## Key Design Decisions

1. **Overloaded `nil`**: Single keyword, type inference disambiguates. Backward compat
   preserved because `infer(nil)` defaults to `List ?A` and `check(nil, List A)` works.

2. **`#.`/`#:` syntax (NOT `?.`)**: `?` suffix conflicts with predicate naming convention.
   `#` prefix is already used for `#{` set literals, extending naturally.

3. **`nil-safe-get` vs `map-get`**: Missing key returns `nil` (NOT error). Nil input
   short-circuits to `nil`. Return type is always `(V | Nil)`.

4. **`A?` sugar is parser-only**: No reader change needed since `?` is `ident-continue?`.
   Only applies to uppercase names that are `known-type-name?`.
