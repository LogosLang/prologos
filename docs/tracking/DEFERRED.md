# Deferred Work

Single source of truth for all deferred work across the Prologos project.
Items are organized by topic. When work is deferred during implementation,
add an entry here immediately.

---

## String Library

### Phase 4a: Grapheme Cluster Operations
- `string-graphemes : String -> LSeq String` (each grapheme as a string)
- `string-grapheme-count : String -> Nat`
- Grapheme-aware `string-reverse`
- Requires UAX #29 state machine (~30KB Unicode tables, quarterly updates)
- **Mitigation**: FFI to Racket's `string-grapheme-span` or ICU library

### Phase 4b: Unicode Normalization
- `string-normalize : NormForm -> String -> String` (NFC/NFD/NFKC/NFKD)
- Bridge to Racket's `string-normalize-nfc` etc. via FFI
- Pure Prologos normalization unlikely to be needed

### Phase 4c: String Similarity & Diffing
- `string-jaro-distance : String -> String -> Rat` (0 to 1 similarity score)
- `string-common-prefix : String -> String -> String`
- `string-myers-difference : String -> String -> List (Pair Symbol String)` (edit script)
- Useful for "did you mean?" suggestions in error messages

### Phase 4d: Regex Integration
- Depends on a regex library (not yet designed)
- Pattern matching on strings via regex
- `string-match`, `string-find-all`, `string-replace-regex`

### Phase 4e: Rope / TextBuffer Type
- Separate type for large text processing (editors, compilers)
- B-tree rope with O(log n) concat/split
- Not a replacement for `String`; a complementary type

---

## Dot-Access Syntax

### Phase D: Nested Dot-Access
- `user.address.city` chained field access
- Deferred from dot-access syntax implementation (Phases A-C complete)
- See `docs/tracking/2026-02-21_1800_DOT_ACCESS_SYNTAX.md`

---

## Homoiconicity

### Phase IV: Advanced Macro System
- Hygiene, gensym, syntax-case equivalents
- Deferred from homoiconicity implementation (Phases I-III complete)
- See `docs/tracking/2026-02-19_HOMOICONICITY_ROADMAP.md`

---

## Core Data Structures

### Phase 2e+: Additional Collection Operations
- Deferred from core data structures (Phases 0-2d complete)
- See `docs/tracking/` and `core-ds-roadmap.md`

---

## Numerics Tower

### Phase 4: Advanced Numeric Features
- Deferred from numerics tower (Phases 1-3f complete)
- See `numerics-tower-roadmap.md`

