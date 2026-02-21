# Map Key Access Syntax (Dot-Access)

**Created**: 2026-02-21
**Status**: In Progress

## Goal

Add ergonomic surface syntax for map key access:
- `user.name` → `[map-get user :name]` (dot-access)
- `.:name user` → `[map-get user :name]` (dot-key prefix for piping)

## Prerequisite: Module Path Migration

Reclaiming `.` requires migrating module paths from `prologos.data.list` to `prologos::data::list`.

## Phases

### Phase A: Module Path Migration (`.` → `::`)
- [ ] A1: Core namespace logic (namespace.rkt)
- [ ] A2: dep-graph.rkt (303 occurrences)
- [ ] A3: Hardcoded FQNs in Racket source (~12)
- [ ] A4: Library .prologos files (91 files, 261 occurrences)
- [ ] A5: Test .rkt files (~81 files, ~1429 occurrences)
- [ ] A6: Example files
- [ ] A verification: full test suite + dep-graph check

### Phase B: Reader Changes
- [ ] B1: Remove `.` from `ident-continue?`
- [ ] B2: Extend dot tokenization (`.ident` → `'dot-access`, `.:kw` → `'dot-key`)
- [ ] B3: Add to `parse-inline-element`
- [ ] B5: Reader tests

### Phase C: Preparse Macro
- [ ] C1: `rewrite-dot-access` function in macros.rkt
- [ ] C2: Integrate before infix rewriting
- [ ] C3: End-to-end tests

### Phase D: Nil-Coalescing `#:` — DEFERRED
