# PM Track 10B — Stage 2 Audit

**Date**: 2026-03-25
**Prerequisites**: Track 10 ✅ (Phases 0-5, `.pnet` cache, fork model, #lang dropped)
**Purpose**: Ground the Track 10B design in concrete code measurements

## 1. Mutable State That May Leak Between Test Cases

### 1.1 Mutable Boxes (`set-box!`)

133 `set-box!` calls across production code:

| File | Count | Risk | Notes |
|------|-------|------|-------|
| metavar-store.rkt | 69 | **HIGH** | Core meta/constraint state. prop-net-box, id-map-box, meta-info-box. Already identified as leaky (Track 10 Phase 3d fix). |
| propagator.rkt | 12 | LOW | Internal to quiescence loop (mutable worklist drain). Scoped to run-to-quiescence. |
| elab-speculation-bridge.rkt | 9 | MEDIUM | Speculation stack manipulation. Should be scoped by command, but check. |
| champ.rkt | 7 | LOW | Owner-ID transient internals. Not exposed to callers. |
| performance-counters.rkt | 6 | LOW | Perf counters. Benign if leaked. |
| global-env.rkt | 5 | **HIGH** | Module-level env manipulation. May affect cross-test state. |
| unify.rkt | 3 | MEDIUM | Unification state. Should be per-command. |
| resolution.rkt | 3 | MEDIUM | Resolution cycle counter. Should reset per-command. |
| macros.rkt | 3 | MEDIUM | Registry mutation during elaboration. |
| warnings.rkt | 2 | LOW | Warning accumulation. Reset per-command. |
| subtype-predicate.rkt | 2 | LOW | Subtype check counter (instrumentation). |
| namespace.rkt | 2 | MEDIUM | Module registry mutation. Leaks if not parameterized. |

**HIGH-risk sites**: metavar-store.rkt (69 sites) and global-env.rkt (5 sites).
The Track 10 Phase 3d fix addressed `current-prop-net-box`. But there are
5 OTHER box parameters in metavar-store.rkt that may leak:
- `current-prop-id-map-box`
- `current-prop-meta-info-box`
- `current-level-meta-champ-box`
- `current-mult-meta-champ-box`
- `current-sess-meta-champ-box`

### 1.2 Mutable Hash Parameters

4 parameters use `make-hasheq` (mutable hash) as their default:
- `current-meta-store` (metavar-store.rkt:1229)
- `current-level-meta-store` (metavar-store.rkt:2054)
- `current-mult-meta-store` (metavar-store.rkt:2197)
- `current-sess-meta-store` (metavar-store.rkt:2337)

These are MUTABLE hashes set via `hash-set!`, not immutable hashes replaced
via `parameterize`. Mutations leak to ANY code sharing the same parameter scope.
`with-fresh-meta-env` creates fresh hashes (metavar-store.rkt:1572-1575), so
test-to-test isolation IS correct for these — as long as every test path goes
through `with-fresh-meta-env` or equivalent.

**Risk**: Code paths that DON'T go through `with-fresh-meta-env` (e.g., direct
`process-string` calls in some older tests) would see stale mutable hashes.

### 1.3 Summary: Leak Risk Assessment

| Category | Count | Status |
|----------|-------|--------|
| `set-box!` HIGH risk | 74 sites (2 files) | metavar-store partially fixed (prop-net-box). 5 other boxes need audit. |
| `set-box!` MEDIUM risk | 17 sites (4 files) | Need scoping verification |
| Mutable hash params | 4 params | Scoped by `with-fresh-meta-env` — OK for standard tests |
| `with-fresh-meta-env` sites | 277 | These ARE correctly scoped |

## 2. Remaining Dual-Path Sites (CHAMP Fallback)

### 2.1 CHAMP Box Parameters

6 box parameters provide the CHAMP fallback path:

| Parameter | Sites | Purpose |
|-----------|-------|---------|
| `current-prop-net-box` | throughout | Primary network access |
| `current-prop-id-map-box` | 4 sites (driver) + 14 (metavar-store) | Meta ID → cell ID mapping |
| `current-prop-meta-info-box` | 15 sites (metavar-store) + 1 (driver) | Meta type/constraint info |
| `current-level-meta-champ-box` | scoped to metavar-store | Level meta auxiliary CHAMP |
| `current-mult-meta-champ-box` | scoped to metavar-store | Mult meta auxiliary CHAMP |
| `current-sess-meta-champ-box` | scoped to metavar-store | Session meta auxiliary CHAMP |

**Total dual-path sites**: ~36 (where code checks `(and box (unbox box))` for
CHAMP fallback before falling through to cell reads).

### 2.2 The `meta-info-box` Pattern

The most common fallback pattern (15 sites in metavar-store.rkt):
```racket
(let ([b (current-prop-meta-info-box)]) (and b (unbox b)))
```
This reads the meta-info CHAMP when no cell is available. With `.pnet` cache,
cells are always available (deserialized from cache). The CHAMP fallback fires
only during module loading when `current-prop-meta-info-box` is `#f`.

**WS-A target**: After removing the expander (Track 10 Phase 5), module loading
goes through `load-module` which has `current-prop-net-box` set (Phase 1a).
The CHAMP fallback should never fire. Remove it and test.

## 3. Remaining Zonk Call Sites

### 3.1 Real Zonk Usage (excluding definitions and perf counters)

| File | Function | Count | Purpose | WS-A or WS-B? |
|------|----------|-------|---------|---------------|
| driver.rkt | `zonk-final` | 7 | Command boundary finalization | WS-A (→ `freeze`) |
| unify.rkt | `zonk-at-depth 0` | 2 | Pre-comparison normalization | WS-B (cell reads) |
| unify.rkt | `zonk-at-depth 1` | 4 | Binder codomain opening | WS-B (cell reads) |
| resolution.rkt | `zonk-at-depth 0` | 4 | Constraint key extraction | WS-B (cell reads) |
| typing-sessions.rkt | `zonk-session` | 9 | Session protocol normalization | WS-B (session cell reads) |
| metavar-store.rkt | `zonk-level` | 2 | Level meta normalization | WS-B (level cell reads) |
| metavar-store.rkt | `zonk-mult` | 2 | Mult meta normalization | WS-B (mult cell reads) |
| metavar-store.rkt | `zonk-level-default` | 4 | Level default application | WS-A (default-metas) |
| metavar-store.rkt | `zonk-mult-default` | 4 | Mult default application | WS-A (default-metas) |
| metavar-store.rkt | `zonk-session-default` | 9 | Session default application | WS-A (default-metas) |

**Total**: 47 real zonk call sites.
- **WS-A (boundary/defaults)**: 24 sites — `zonk-final` (7) + defaults (17)
- **WS-B (elaboration-time)**: 23 sites — unify (6) + resolution (4) + sessions (9) + meta normalization (4)

### 3.2 zonk.rkt Size

| Component | Lines | Elimination target |
|-----------|-------|--------------------|
| `zonk` (intermediate) | ~300 | WS-B: replace with cell reads |
| `zonk-final` | ~100 | WS-A: already partially → `freeze` |
| `zonk-at-depth` | ~300 | WS-B: replace with cell reads |
| `zonk-level/mult/session` | ~200 | WS-B: replace with domain cell reads |
| `default-metas` | ~100 | WS-A: move to solve-time |
| Support functions | ~300 | Depends on above |
| **Total** | **~1300** | **Full elimination possible** |

## 4. Batch Worker State Save/Restore

### 4.1 Current Save/Restore

11 values saved at module level (after prelude load):
- `ready-macros-snapshot` (19 registries as one vector)
- `ready-module-registry`
- `ready-ns-context`
- `ready-lib-paths`
- `ready-loading-set`
- `ready-module-loader`
- `ready-spec-propagation-handler`
- `ready-foreign-handler`
- `ready-global-env`
- `ready-module-defs-content`
- `ready-persistent-registry-net-contents`

9 values restored per-test-file via `parameterize`.

### 4.2 Simplification with .pnet + Fork

With `.pnet` cache and `fork-prop-network`:
- `ready-macros-snapshot` (19 registries) → cells in forked prelude network
- `ready-persistent-registry-net-contents` → cells in forked prelude network
- `ready-global-env` → definitions in forked prelude network
- `ready-module-defs-content` → definitions in forked prelude network

Remaining (Racket-intrinsic, can't be cells):
- `ready-module-loader` (callback)
- `ready-spec-propagation-handler` (callback)
- `ready-foreign-handler` (callback)
- `ready-ns-context` (namespace metadata)
- `ready-lib-paths` (filesystem paths)
- `ready-loading-set` (cycle detection set)

**Target**: 11 → 6 saved values. 9 → 6 parameterized values.

## 5. id-map Usage (Elimination Target)

18 sites across 2 files:
- metavar-store.rkt: 14 (id→cell-id lookups, registration)
- driver.rkt: 4 (setup, registration)

With `cell-id` embedded in `expr-meta` (PM 8F), the id-map lookup is
bypassed for most reads. The id-map persists for:
1. Metas created without a network (module-loading context) — need
   CHAMP-based id storage
2. `prop-meta-id->cell-id` — called from metavar-store when cell-id
   isn't available on the expr-meta struct

**WS-A target**: Verify all `prop-meta-id->cell-id` callers have access
to `expr-meta.cell-id`. If yes, the id-map can be eliminated. If some
callers only have the meta ID (not the expr-meta struct), the id-map
must persist for those callers.

## 6. Summary: WS-A vs WS-B Scope

### WS-A (Foundation Cleanup) — bounded, mechanical

| Item | Sites | Effort | Impact |
|------|-------|--------|--------|
| CHAMP fallback removal | ~36 | Medium | Eliminates dual-path |
| id-map elimination | 18 | Low | Simplifies meta reads |
| `zonk-final` → `freeze` | 7 | Low | Already partially done in Track 10 |
| `default-metas` at solve-time | 17 | Medium | Moves defaults earlier |
| `.pnet` version header | 1 | Low | Forward compatibility |
| Batch worker simplification | 11→6 | Low | Less state to manage |
| **Total** | **~90 sites** | | **~400 lines removed** |

### WS-B (Performance + Zonk Elimination) — deeper architectural

| Item | Sites | Effort | Impact |
|------|-------|--------|--------|
| Remaining zonk (elaboration-time) | 23 | HIGH | Replaces tree-walking with cell reads |
| `with-fresh-meta-env` audit | 277 | Medium | Verifies scoping correctness |
| Test-granular scheduling | New infra | HIGH | <150s target (Places) |
| process-string leak audit | ~74 high-risk sites | Medium | Prevents Track 10 Phase 3d class of bugs |
| **Total** | **~374 sites** | | **~1300 lines removed (zonk.rkt)** |

### Recommended Order

1. WS-A first (bounded, mechanical, delivers value immediately)
2. process-string leak audit (prevents WS-B from exposing latent bugs)
3. WS-B zonk elimination (highest code reduction)
4. WS-B test-granular scheduling (highest performance lever)
