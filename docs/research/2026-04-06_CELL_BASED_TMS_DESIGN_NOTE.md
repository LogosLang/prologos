# Design Note: Cell-Based TMS (Truth Maintenance on Network)

**Date**: 2026-04-06
**Series**: BSP-LE (Logic Engine on Propagators)
**Origin**: PPN Track 4B Phase 8 design conversation
**Status**: Design note — ready for Stage 2/3 design when scheduled

---

## Problem

The current TMS (Truth Maintenance System) uses `current-speculation-stack` — a Racket parameter (ambient state) — to determine which branch a cell read/write operates under. This is OFF-NETWORK state influencing on-network computation.

- `net-cell-write` reads `current-speculation-stack` to determine the TMS branch for wrapping
- `net-cell-read` reads `current-speculation-stack` to navigate the TMS tree
- Propagators that operate under speculation have their behavior changed by ambient state, not by cell inputs

This violates the Propagator-First principle: propagators should be pure functions (`net → net`) whose behavior is determined by cell inputs, not by parameters.

## The Principled Architecture: Worldview as a Cell

The branch identity (which assumption we're under) should be a **cell value**. A propagator reads the worldview cell as an input. The TMS mechanism uses the worldview from the cell, not from a parameter.

```
worldview-cell: holds (listof assumption-id) — current branch path
propagator inputs: [attribute-map-cell, worldview-cell, ...]
propagator reads: tms-read(attribute-map, worldview) → branch-specific values
propagator writes: tms-write(attribute-map, worldview, new-value) → branch-specific write
```

The worldview IS information flowing through cells. Branching IS propagator structure:
- Two propagators, each reading a different worldview cell → evaluate concurrently
- TMS keeps branch values separate within the shared attribute-map cell
- Contradiction in one branch → retract (TMS removes branch values)
- Survivor → commit (TMS promotes branch values to base)

## What Changes

### propagator.rkt — Core TMS Integration

1. **`net-cell-write`**: Currently reads `(current-speculation-stack)`. Change to accept worldview as an explicit parameter, or read it from a designated cell.

2. **`net-cell-read`**: Currently reads `(current-speculation-stack)`. Same change — worldview from explicit source, not parameter.

3. **`fire-and-collect-writes`**: BSP fire round needs to pass the worldview to each propagator's fire function, or the propagator reads it from its input cells.

4. **`tms-write` / `tms-read`**: Pure functions (take stack as argument). No change needed — they already take the stack as a parameter.

### Propagator Fire Functions

No change to fire function signatures (`net → net`). The worldview is read FROM A CELL inside the fire function:

```racket
(define (make-branch-aware-fire-fn inner-fn worldview-cid)
  (lambda (net)
    (define worldview (net-cell-read net worldview-cid))
    (parameterize ([current-speculation-stack worldview])
      (inner-fn net))))
```

The `parameterize` is LOCAL to the fire function (not ambient). The worldview comes from a cell (on-network). The fire function is pure: same `net` input → same output.

### Migration Path

1. **Phase A**: Add worldview-cell infrastructure. Create worldview cells alongside attribute-map cells. Propagators installed with worldview-cell as additional input.

2. **Phase B**: Modify `net-cell-write` / `net-cell-read` to support explicit worldview argument (optional, backward-compatible). Existing parameter-based code continues to work.

3. **Phase C**: Migrate speculation users (elab-speculation-bridge, union type checking) to cell-based worldview. Remove parameter-based fallback.

4. **Phase D**: `current-speculation-stack` parameter removed. TMS is fully on-network.

## Interaction with PPN Track 4B Phase 8

Phase 8 (ATMS union type branching in the attribute PU) DEPENDS on this rearchitecture for the principled implementation:

- **Option D** (concurrent branching): Two sets of propagators, each reading a different worldview cell. Both evaluate concurrently in the same BSP quiescence. TMS keeps branch values separate. Fully on-network.

- **Without cell-based TMS**: Option D requires closure-captured assumptions (functionally pure but architecturally impure) or sequential evaluation (Option C — imperative branching loop).

## Scope Estimate

- propagator.rkt changes: ~100 lines (net-cell-write, net-cell-read, fire-and-collect-writes)
- Migration of existing users: ~200 lines across 5-6 files
- New tests: ~150 lines (worldview cell creation, branching, commit/retract)
- Total: ~450 lines, medium complexity, high impact (touches core infrastructure)

## Cross-References

- PPN Track 4B Phase 8: union type branching (blocked on this)
- BSP-LE Track 3: ATMS solver (uses TMS extensively)
- Track 6 Phases 2-4: elab-speculation-bridge (primary TMS consumer)
- PPN Track 4B §5a: ATMS consideration for single-cell model
- PPN Track 4B §6a: propagator patterns (P1/P2/P3) — worldview cell is a new pattern

## Principles Alignment

- **Propagator-First**: Worldview flows through cells, not parameters ✓
- **Data Orientation**: Branch identity is data (cell value), not control flow ✓
- **Correct-by-Construction**: Branch isolation is structural (TMS tree), not maintained by discipline ✓
- **Decomplection**: Worldview separated from computation — propagators don't need to know about speculation ✓
