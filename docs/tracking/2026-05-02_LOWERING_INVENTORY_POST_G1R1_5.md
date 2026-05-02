# Lowering Inventory — coverage of ast-to-low-pnet across all .prologos files
Snapshot: post-Gate-1-rev-1.5 (static-eval over ctor values)
Branch: lowering-yolo

Delta vs previous snapshot (`2026-05-02_LOWERING_INVENTORY_POST_GATES.md`):
  PASS: 87 → 89 (+2). Closed `list-sum-3` and `nested-maybe`.
  GATE1_RECURSIVE: 2 → 0 (cleared).
  All other buckets unchanged.

Remaining buckets are out of lowering scope:
  - NO_MAIN: library / demo files with no `main` value.
  - TIMEOUT: probe exceeded per-file budget (elaboration loops).
  - GATE3_STRING: programs whose result depends on runtime string
    operations (deferred to Gate 3 rev 2 — native string heap).

Total files probed: 141

## Bucket summary

| Bucket | Count | What it means | Gate |
|---|---|---|---|
| PASS | 89 | Round-trips through ast-to-low-pnet → run-low-pnet | — |
| NO_MAIN | 46 | Library file or no `main` value (not lowerable target) | — |
| TIMEOUT | 1 | Probe exceeded per-file timeout (likely infinite loop in elab/lowering) | — |
| GATE3_STRING | 5 | Strings, bytes, chars (heuristic: source matches str:: / char-at / etc.) | Gate 3 |
