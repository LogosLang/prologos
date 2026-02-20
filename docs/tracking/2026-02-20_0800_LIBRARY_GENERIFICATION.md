# Prologos Whole-Library Generification

**Created**: 2026-02-20
**Plan file**: `.claude/plans/buzzing-launching-pascal.md`
**Purpose**: Rewrite library functions with most generic types; add trait instances for all collection types; expand prelude.

---

## Status Legend

- ✅ **Done** — implemented, tested, merged
- 🔧 **In Progress** — actively being worked on
- ⬜ **Not Started** — planned but no work yet

---

## Phase Summary

| Phase | Goal | Status | Tests |
|-------|------|--------|-------|
| 3a | Reduction stubs (map-keys, map-vals, set-to-list) | ✅ | 8 new |
| 3b | PVec trait instances + pvec-ops | ⬜ | — |
| 3c | Map/Set trait instances + ops | ⬜ | — |
| 3d | LSeq trait instances | ⬜ | — |
| 3e | Identity traits + generic numerics | ⬜ | — |
| 3f | Collection conversion functions | ⬜ | — |
| 3g | Prelude expansion | ⬜ | — |
| 3h | Syntax verification + docs | ⬜ | — |

---

## Key Design Decisions

1. **Identity traits**: `AdditiveIdentity` (zero) + `MultiplicativeIdentity` (one) added to Num bundle
2. **Map entries**: New `expr-map-entries` AST node for O(n) Map→List(Sigma K V)
3. **Naming**: Prefixed unqualified (`pvec-map`, `set-filter`) — no collisions with List ops
4. **Conversions**: Named functions `vec`, `seq`, `into-vec`, `into-list`, `into-set`
5. **LSeq as hub**: All collections convert to/from LSeq (spoke-and-hub model)

---

## Implementation Notes

### Phase 3a — Reduction Stubs (DONE)

- Added `racket-list->prologos-list` and `racket-pairs->prologos-pair-list` helpers to reduction.rkt
- Completed `map-keys`, `map-vals`, `set-to-list` reduction stubs (previously returned `e` unchanged)
- Fixed typing-core.rkt: `map-keys` → `List K`, `map-vals` → `List V`, `set-to-list` → `List A` (were returning `expr-error`)
- Fixed qtt.rkt: `set-to-list` QTT rule (was `tu-error`)
- 8 new tests across test-map.rkt (5) and test-set.rkt (3)
