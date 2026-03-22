# Track 8 Phase B0: Module Graph Analysis

**Date**: 2026-03-22
**Scope**: Map circular dependencies and design cell-ops extraction

---

## Module Dependency Graph

Direct `require` graph (no circular dependencies at file level):

```
metavar-store.rkt  ← (no direct deps on key modules)
  ↑
  ├── trait-resolution.rkt
  ├── elaborator.rkt
  ├── typing-core.rkt → reduction.rkt → metavar-store.rkt
  ├── reduction.rkt
  └── resolution.rkt → trait-resolution.rkt → metavar-store.rkt
```

The "circular dependency" is through **23 callback parameters** in `metavar-store.rkt`:
- `metavar-store.rkt` defines callback parameters (`current-prop-cell-read`, etc.)
- `driver.rkt` sets them to functions from `elaborator-network.rkt`
- This breaks the cycle: metavar-store → (callbacks) → elaborator-network → propagator.rkt

## The 23 Callback Parameters

### Cell Operations (core — highest call count)
| Parameter | Sites | Set to (in driver.rkt) |
|-----------|-------|----------------------|
| `current-prop-cell-read` | 48 | `elab-cell-read` |
| `current-prop-cell-write` | 15 | `elab-cell-write` |
| `current-prop-cell-replace` | 3 | `elab-cell-replace` |

### Network Infrastructure
| Parameter | Sites | Set to |
|-----------|-------|--------|
| `current-prop-net-box` | ~50 | `(box (make-elaboration-network))` |
| `current-prop-make-network` | 1 | `make-elaboration-network` |
| `current-prop-fresh-meta` | 1 | `elab-fresh-meta` |
| `current-prop-add-propagator` | 1 | `elab-add-propagator` |
| `current-prop-new-infra-cell` | 5 | `elab-new-infra-cell` |
| `current-prop-add-unify-constraint` | 1 | `elab-add-unify-constraint` |
| `current-prop-has-contradiction?` | 1 | `(removed Track 7)` |
| `current-prop-run-quiescence` | 2 | `run-to-quiescence` |
| `current-prop-unwrap-net` | 2 | `elab-network-prop-net` |
| `current-prop-rewrap-net` | 2 | wrapping function |

### Id-Map Access
| Parameter | Sites | Set to |
|-----------|-------|--------|
| `current-prop-id-map-read` | ~10 | `elab-network-id-map` |
| `current-prop-id-map-set` | ~5 | `elab-network-id-map-set` |
| `current-prop-id-map-box` | 1 | deprecated |

### Meta-Info Access
| Parameter | Sites | Set to |
|-----------|-------|--------|
| `current-prop-meta-info-read` | ~8 | `elab-network-meta-info` |
| `current-prop-meta-info-set` | ~5 | `elab-network-meta-info-set` |
| `current-prop-meta-info-box` | 2 | deprecated fallback |

### Domain Cells (mult/level/session)
| Parameter | Sites | Set to |
|-----------|-------|--------|
| `current-prop-fresh-mult-cell` | 1 | `elab-fresh-mult-cell` |
| `current-prop-mult-cell-write` | 1 | `elab-mult-cell-write` |
| `current-prop-fresh-level-cell` | 1 | `elab-fresh-level-cell` |
| `current-prop-fresh-sess-cell` | 1 | `elab-fresh-sess-cell` |

## Cell-Ops Extraction Design

### What `cell-ops.rkt` Provides

All operations that `metavar-store.rkt` currently accesses through callbacks:

1. **Worldview-aware reads** (the B1 architectural change):
   - `cell-read` — reads cell value, filters by ATMS worldview
   - `meta-info-read` — reads meta-info CHAMP entry, filters by worldview
   - `id-map-read` — reads id-map entry, filters by worldview

2. **Tagged writes** (tag with current speculation assumption):
   - `cell-write`, `cell-replace`
   - `meta-info-write`, `id-map-write`

3. **Network operations**:
   - `fresh-meta`, `add-propagator`, `new-infra-cell`, `add-unify-constraint`
   - `fresh-mult-cell`, `fresh-level-cell`, `fresh-sess-cell`
   - `run-quiescence`, `unwrap-net`, `rewrap-net`

### Import Structure

```
cell-ops.rkt
  requires: propagator.rkt, elab-network struct definitions, ATMS worldview
  provides: all cell operations (pure + boxed APIs)

metavar-store.rkt
  requires: cell-ops.rkt (direct, not through callbacks)
  no longer needs: 23 callback parameters

elaborator-network.rkt
  requires: propagator.rkt (unchanged)
  provides: struct definitions (elab-network, elab-cell-info)
  delegates: cell operations to cell-ops.rkt

driver.rkt
  no longer needs: install-prop-network-callbacks!
```

### Migration Strategy

1. Create `cell-ops.rkt` with all operations
2. Wire worldview-aware reads into cell-ops (B1's architectural change)
3. Replace callback calls in metavar-store.rkt with direct cell-ops imports (B2)
4. Remove callback parameter definitions and driver.rkt installation (B2c-d)
