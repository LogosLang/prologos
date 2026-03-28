# PAR Track 0: CALM Topology Audit

**Date**: 2026-03-27
**Scope**: All fire function closures across the propagator codebase
**Method**: Trace all `net-new-cell` and `net-add-propagator` calls reachable from fire function execution paths
**Guard**: `current-bsp-fire-round?` parameter enforces the invariant at runtime (`af35f5e`)

---

## Summary

| Classification | Count | Files |
|----------------|-------|-------|
| **VIOLATOR** | 2 | sre-core.rkt, narrowing.rkt |
| **UNKNOWN** | 1 | constraint-propagators.rkt (callback-dependent) |
| **SAFE** | 7+ | elaborator-network.rkt, session-propagators.rkt, effect-bridge.rkt, cap-type-bridge.rkt, metavar-store.rkt, global-constraints.rkt, elab-speculation.rkt |

---

## VIOLATOR 1: sre-core.rkt — Structural Decomposition

**Fire functions affected**: `sre-make-equality-propagator`, `sre-make-subtype-propagator`, `sre-make-duality-propagator`

**Violation path**:
```
fire function lambda
  → sre-maybe-decompose (line 456)
    → sre-decompose-generic (line 384)
      → sre-get-or-create-sub-cells → sre-identify-sub-cell
        → net-new-cell (lines 288, 291, 294)  ← TOPOLOGY CHANGE
      → net-add-propagator (lines 424-427)     ← TOPOLOGY CHANGE (sub-propagators)
      → net-add-propagator (lines 432-435)     ← TOPOLOGY CHANGE (reconstructors)
```

**What it does**: When a fire function discovers two compound types with the same tag (e.g., `PVec Int` vs `PVec Nat`), it decomposes them into component cells and installs sub-propagators to relate the components. This is the lazy/demand-driven decomposition strategy.

**Impact**: Under BSP, the sub-cells and sub-propagators are created in the returned `result-net` but discarded by `fire-and-collect-writes` (which only diffs cell values). The decomposition never materializes. Wrong results (silent).

**Fix direction**: Decomposition requests as cell values. The fire function writes a `(decompose tag cell-a cell-b relation)` request to a decomposition-request cell. A topology stratum reads requests and calls `sre-decompose-generic`.

---

## VIOLATOR 2: narrowing.rkt — Narrowing Propagator Installation

**Fire functions affected**: `make-branch-fire-fn`, `make-rule-fire-fn`

**Violation path (branch)**:
```
make-branch-fire-fn lambda
  → install-narrowing-propagators (line 163)
    → net-add-propagator (lines 169, 188, 204)  ← TOPOLOGY CHANGE
    → recursive install-narrowing-propagators     ← MORE TOPOLOGY
```

**Violation path (rule)**:
```
make-rule-fire-fn lambda
  → eval-rhs (line 304)
    → net-new-cell (lines 323, 338)  ← TOPOLOGY CHANGE
```

**What it does**: When a narrowing propagator fires and discovers the top-level term is a constructor, it branches: for each definitional tree rule, it creates sub-cells and installs narrowing propagators for the rule body. This is demand-driven narrowing — rules are only explored when the term is sufficiently instantiated.

**Impact**: Same as SRE — topology changes lost under BSP.

**Fix direction**: Same pattern — narrowing requests as cell values, topology stratum processes them.

---

## UNKNOWN: constraint-propagators.rkt — install-fn callback

**Fire function affected**: `install-constraint->method-propagator` (line 267)

The fire function calls `install-fn` (a parameter), which could create topology depending on the caller. Need to document the contract: `install-fn` must NOT call `net-new-cell` or `net-add-propagator`.

**Action**: Add contract documentation + runtime assertion via `current-bsp-fire-round?` (already covered by the guard).

---

## SAFE Files (Confirmed)

| File | Fire Functions | Why Safe |
|------|---------------|----------|
| elaborator-network.rkt | 12 reconstructors, structural-unify-propagator | All read cells, write parent. No topology. |
| session-propagators.rkt | Continuation, branch, fork, duality propagators | All read/write only. Duality inherits SRE violation. |
| effect-bridge.rkt | Effect position propagator | Reads sess-cell, writes effect-cell. |
| cap-type-bridge.rkt | Capability propagator | Reads callee-cap, writes caller-cap. |
| metavar-store.rkt | Threshold, readiness, retry propagators | All read-only or cell-write-only. |
| global-constraints.rkt | No fire functions | Cell creation at init time only. |
| elab-speculation.rkt | No propagator usage | Safe. |

---

## LKan/RKan Stratum Crossing Analysis

**Question**: Do Left Kan / Right Kan extension mechanisms preserve CALM across stratum boundaries?

**Analysis**: Kan extensions in our architecture operate on VALUES flowing between strata:
- **LKan** (speculative supply): writes speculative values into the next stratum's existing cells
- **RKan** (demand-driven): writes demand signals into the previous stratum's existing cells

Neither creates new cells or propagators. The stratum boundary is defined by pre-existing cells. Values flow through these cells; topology is fixed at stratum construction time.

**Verdict**: LKan/RKan are CALM-safe. They are value operations on fixed topology, not topology operations.

**Caveat**: If a demand signal triggers decomposition (e.g., RKan demand on a compound type → SRE decomposition), that decomposition is a topology change and must be handled by the topology stratum, not inline. The demand signal is a VALUE; the response (topology change) is in a different stratum.

---

## Dynamic Topology as NAF Analog

Both CALM violators follow the same pattern as negation-as-failure:
- **NAF**: "if P is not derivable at quiescence, conclude ¬P" — non-monotone, requires its own stratum (S(-1))
- **Decomposition**: "if compound type detected at quiescence, build sub-structure" — topology change, requires its own stratum

The existing stratification infrastructure (S(-1) retraction) already handles non-monotone operations between strata. Dynamic topology is the same class of operation — it should use the same mechanism.

---

## Architectural Recommendation

**Two-fixpoint architecture with topology strata**:

```
Repeat until stable:
  1. Topology stratum (sequential):
     - Read decomposition-request cells
     - Create sub-cells and sub-propagators
     - Clear processed requests
  2. Value stratum (BSP-safe, parallelizable):
     - Fire all propagators on fixed topology
     - Converge to fixpoint
     - Propagators may write decomposition REQUESTS (values)
       but never create topology
```

**Scope of refactoring**:
- sre-core.rkt: Factor `sre-decompose-generic` into request emission (fire function) + topology construction (stratum handler). Estimated: ~100 lines changed.
- narrowing.rkt: Factor `install-narrowing-propagators` and `eval-rhs` into request emission + topology construction. Estimated: ~80 lines changed.
- propagator.rkt: Add topology stratum to `run-to-quiescence-bsp` loop (check decomposition-request cells between BSP rounds). Estimated: ~40 lines.
- constraint-propagators.rkt: Document `install-fn` contract (value-only).

**Total estimated scope**: ~220 lines of refactoring. No new modules. No API changes for consumers.
