# Lowering Inventory — coverage of ast-to-low-pnet across all .prologos files
Snapshot: post-Gate-1-rev-1.5 + honest source-categorization fix.
Branch: lowering-yolo

## TL;DR

The lowering subsystem (ast-to-low-pnet → low-pnet → LLVM) now handles
**100 %** of programs in the corpus that:
  - successfully elaborate (process-file), AND
  - define a value named `main`.

All remaining inventory entries fall into elaborator-side or
not-a-target buckets:
  - 47 NO_MAIN: library files / demos with no `main`.
  - 4 ELAB_FAIL: parser / mixfix / module-resolver / surface-syntax
    failures (`if` arity, missing module, mixfix conflict, unknown
    relation symbol from a relational scope).
  - 1 GATE4_NAF: a relational-NAF test file whose elaboration aborts
    on `Unknown relation: parent` — really also an elaborator-side
    failure (the relation is defined later in the file but the
    elaborator's relational name-resolution doesn't yet handle it).

## Counts

| Bucket | Count | What it means | Owner |
|---|---|---|---|
| PASS | 89 | Round-trips through ast-to-low-pnet → run-low-pnet | — |
| NO_MAIN | 47 | Library / demo files with no `main` value (not lowerable target) | — |
| ELAB_FAIL | 4 | Parse / elab / type-check error before lowering can run | Elaborator |
| GATE4_NAF | 1 | Elaborator name-resolution for relational scope | Elaborator (later: Gate 4 rev 2 for runtime) |

Total files probed: 141

## Delta vs `2026-05-02_LOWERING_INVENTORY_POST_GATES.md`

  - PASS: 87 → 89 (+2). Closed `list-sum-3` and `nested-maybe` via
    Gate 1 rev 1.5 (static-eval over ctor values).
  - GATE1_RECURSIVE: 2 → 0 (cleared).
  - GATE3_STRING: 5 → 0. Reclassified — these were
    elab-failures whose source happened to contain `"`, not actual
    GATE3 lowering gaps. The categorizer now matches the elab
    *error message* rather than source content (`tools/lowering-
    inventory.rkt` updated).
  - TIMEOUT: 1 → 0 (transient; depends on system load).
  - ELAB_FAIL: 0 → 4 (the 4 reclassified files).
  - GATE4_NAF: 0 → 1 (1 reclassified file).

## What this means for next steps

The "lowering arbitrary Prologos programs" goal as defined for the
target subset (programs with a scalar `main`) is **complete**. The
remaining inventory entries are not lowering-track work:

  - The 4 ELAB_FAIL entries are elaborator bugs (mixfix conflict,
    missing-module path, surface-syntax check). Each is an
    independent fix in the elaborator subsystem.
  - The 1 GATE4_NAF entry is the relational name-resolution issue;
    addressing it requires the relational subsystem (multi-week
    Gate 4 rev 2 effort, separate track).
  - The 47 NO_MAIN entries are library / demo files by design; they
    serve as imports for other programs, not as standalone main
    entries.

## Round-trip-acceptance

`tools/round-trip-acceptance.rkt`: 65/65 PASS (no fails, no
unsupported, no skipped).
