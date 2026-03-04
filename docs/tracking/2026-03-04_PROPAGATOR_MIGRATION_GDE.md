# Propagator Migration & GDE: Complete LE Subsystem Adoption

## Context

The user wants to "dial in propagator-based testing" and "build out the missing pieces
for full rich error testing with GDE failure explanations" before returning to session
work (S3+). E3 (provenance-rich type errors) is COMPLETE. The remaining work:

1. **P1-E3**: Constraint-retry as propagators (eliminate legacy dual path)
2. **P3**: Trait resolution as propagators (eliminate post-pass)
3. **P5**: QTT multiplicity cells (architectural unification)
4. **P1-G**: Unification as pure propagators (eliminate imperative `unify`, 123 call sites)
5. **GDE**: General Diagnostic Engine (multi-hypothesis conflict analysis, minimal diagnoses)

All 5 tracks must complete before S3 (session elaboration).

## Dependency Graph

```
P1-E3 (Constraint-Retry)
  |
  +---> P3 (Trait Resolution)  ----+
  |                                |
  +---> P5 (QTT Multiplicities)   |
  |                                |
  +---> P1-G (Pure Unification) ---+---> GDE (Diagnostic Engine)
```

---

## Track 1: P1-E3 — Constraint-Retry Propagators

**Goal**: Eliminate legacy `retry-constraints-for-meta!`. Constraint retry becomes
propagator fire functions within the elaboration network.

**Key files**: `metavar-store.rkt`, `elaborator-network.rkt`, `driver.rkt`, `unify.rkt`

**Key insight**: Constraint creation happens in ONE place: `solve-flex-app` in
`unify.rkt:476-493`. The Gauss-Seidel scheduler handles re-entrancy safely (new
propagators appended to worklist). Current `solve-meta!` (metavar-store.rkt:530-576)
already runs propagator quiescence then falls back to legacy retry.

### P1-E3a: Constraint-Retry Propagator (Shadow)

In `add-constraint!` (metavar-store.rkt:332-362), after existing propagator path that
adds unify propagators between meta cells, add a **constraint-retry propagator**:
- Fire function reads watched cells, zonks constraint LHS/RHS, calls `unify`
- Same logic as `current-retry-unify` callback (unify.rkt:604-614)
- Input cells: all cells for metas in LHS and RHS
- Legacy `retry-constraints-for-meta!` still runs as secondary

Add `elab-add-constraint-retry-propagator` to `elaborator-network.rkt`.
Install callback via `current-prop-add-constraint-retry` in `driver.rkt`.

**Tests**: NEW `tests/test-constraint-retry-propagator.rkt` (~15 tests)
**Verify**: `raco test tests/test-constraint-retry-propagator.rkt`

### P1-E3b: Shadow Validation

Add shadow comparison in `solve-meta!`: after both paths run, compare constraint
statuses. Log divergences to stderr as `CONSTRAINT-SHADOW-MISMATCH:`.
Add shadow counters to `provenance-counters`.

**Verify**: Full suite — zero shadow mismatches.

### P1-E3c: Switchover

Remove the `cond` branch in `solve-meta!` (lines 553-573). Propagator-driven path
becomes sole path. Remove `retry-constraints-for-meta!` call. Keep
`retry-trait-for-meta!` (migrated in P3).

**Verify**: Full suite green.

### P1-E3d: PIR + Cleanup

Remove shadow comparison code. Remove `current-prop-driven-wakeup?` parameter.
Make `retry-constraints-for-meta!` a no-op. Update DEFERRED.md.

**Verify**: Full suite green.

---

## Track 2: P3 — Trait Resolution as Propagators

**Goal**: Replace post-pass `resolve-trait-constraints!` (11 call sites in driver.rkt
and expander.rkt) with propagator-based incremental resolution.

**Key files**: `metavar-store.rkt`, `driver.rkt`, `expander.rkt`, `trait-resolution.rkt`

**Key insight**: Phase C wakeup callbacks (`retry-trait-for-meta!`) already handle
the "all args ground" case. The propagator formalization makes this explicit and
eliminates the post-pass entirely.

### P3a: Trait-Resolution Propagator (Shadow)

In `register-trait-constraint!` (metavar-store.rkt), add a trait-resolution propagator
watching all type-arg cells. Fire function:
1. Read all type-arg cells — if any is `type-bot`, return (not ready)
2. Zonk type-args, check `ground-expr?`
3. If all ground: try monomorphic → parametric resolution
4. On success: `solve-meta!` on dict-meta with dict-expr
5. On failure: leave unsolved (error reported later)

New callback `current-prop-add-trait-resolve` installed from `driver.rkt`.
Post-pass still runs as verification.

**Tests**: NEW `tests/test-trait-resolution-propagator.rkt` (~12 tests)
**Verify**: Targeted tests + full suite.

### P3b: Shadow Validation

After propagator path, still call `resolve-trait-constraints!`. Compare: any metas
solved by post-pass that propagator missed? Log divergences.

**Verify**: Full suite — zero divergences.

### P3c: Switchover

Remove `(time-phase! trait-resolve (resolve-trait-constraints!))` from 5 sites in
driver.rkt and 4 sites in expander.rkt. Keep `check-unresolved-trait-constraints`
(error reporting pass).

**Verify**: Full suite green.

### P3d: PIR + Cleanup

Remove shadow code. Make `retry-trait-for-meta!` in metavar-store.rkt a no-op.
Update DEFERRED.md.

---

## Track 3: P5 — QTT Multiplicity Cells

**Goal**: Multiplicity cells in elaboration network with cross-domain bridge.

**Key files**: `qtt.rkt`, `elaborator-network.rkt`, `metavar-store.rkt`, `driver.rkt`

**Key insight**: Tiny lattice (m0 < m1 < mw). Performance gain minimal. Value:
architectural unification + cross-domain bridge for session types.

### P5a: Multiplicity Lattice Module

NEW `mult-lattice.rkt` (~60 lines): `mult-bot`, `m0`, `m1`, `mw`, `mult-top`.
Merge = max in lattice ordering. Contradicts = `mult-top?`.

**Tests**: NEW `tests/test-mult-lattice.rkt` (~10 tests)

### P5b: Multiplicity Cells in Elaboration Network

Add `elab-fresh-mult-cell` to `elaborator-network.rkt`. In `fresh-mult-meta`
(metavar-store.rkt), allocate mult cell on network. In `solve-mult-meta!`, write
to mult cell.

**Tests**: NEW `tests/test-mult-propagator.rkt` (~10 tests)

### P5c: Cross-Domain Bridge (Type ↔ Multiplicity)

Add `elab-add-type-mult-bridge` to `elaborator-network.rkt`. Uses
`net-add-cross-domain-propagator` from propagator.rkt. Alpha: Pi type → extract
mult. Gamma: read-only (deferred).

**Tests**: Extend `test-mult-propagator.rkt` (~8 more tests)

### P5d: PIR

Benchmark. Verify fuel consumption doesn't explode from bridge propagators.
Update DEFERRED.md.

---

## Track 4: P1-G — Unification as Pure Propagators

**Goal**: Replace imperative `unify` (123 call sites across 11 files) with declarative
propagators: "these two cells must agree" rather than "solve this meta now."

**Key files**: `unify.rkt` (~600 LOC), `typing-core.rkt` (23 call sites),
`qtt.rkt` (6 sites), `elaborator-network.rkt`, `metavar-store.rkt`

**Risk**: VERY HIGH. Unification is the core of the type checker. Must use full
4-stage methodology with shadow validation.

### P1-G1: Design — Propagator Unification API

**Status: DONE** — design below.

#### Current Architecture (What Exists)

The system already has dual-path unification:
1. **Imperative path** (`unify` in `unify.rkt`): 3-valued return (`#t`/`'postponed`/`#f`),
   calls `solve-meta!` (side effect), `add-constraint!` for postponement.
2. **Propagator mirror** (`make-unify-propagator` in `elaborator-network.rkt`):
   Pure lattice merge via `type-lattice-merge` → `try-unify-pure`. Used for
   constraint retry after quiescence.

Key functions in imperative `unify`:
- `solve-flex-rigid(id, rhs, ctx)` — bare meta vs concrete → `solve-meta!`
- `solve-flex-app(flex-term, rhs, ctx)` — applied meta → Miller's pattern check → solve/postpone
- `invert-args(args, rhs)` — construct λ-abstraction for pattern unification
- `unify-mult(m1, m2)` / `unify-level(l1, l2)` — subsidiary unification

Call sites: ~23 in `typing-core.rkt`, ~6 in `qtt.rkt`, all via `(unify-ok? (unify ctx t1 t2))`.

#### Design Decision: Thin Wrapper Over Existing Infrastructure

The propagator version of `unify` does NOT rewrite the unification algorithm. Instead,
it wraps the existing `unify` to:
1. Ensure meta solutions are written to propagator cells (already done by P5b's `solve-meta!` writes)
2. Ensure constraint postponement registers propagator-level constraints (already done by `add-constraint!`)
3. After each `unify` call, run the propagator network to quiescence

The new API:
```
unify*(ctx, t1, t2) → #t | 'postponed | #f
```
Same signature as `unify`. Internally:
1. Call `(unify ctx t1 t2)` — side effects write to cells
2. Run propagator network to quiescence (transitive propagation)
3. Scan for contradictions → if contradiction, return `#f`
4. Return original `unify` result (with possible upgrade from `'postponed` to `#t`
   if quiescence solved the constraint)

**Why this works:** The propagator network is already wired (P1-E3, P3, P5b).
`solve-meta!` writes to cells. `retry-constraints-via-cells!` replays postponed
constraints when cells change. The missing piece is running quiescence explicitly
after each `unify` call in `typing-core.rkt` to enable transitive propagation.

#### Phase G2-G3 Strategy

- **G2 (structural)**: Add `unify*` wrapper that runs quiescence after `unify`.
  Test with structural-only cases (no metas). Verify that the propagator network
  correctly records type unifications.

- **G3 (meta-bearing)**: Extend `unify*` to check whether quiescence resolved
  previously-postponed constraints. If a meta was solved by quiescence (cell went
  from `type-bot` to concrete), return `#t` instead of `'postponed`.

#### Risk Analysis

The main risk is **double-solving**: `unify` calls `solve-meta!` which writes to
the cell, then quiescence fires propagators which might re-unify. Guard: propagator
fire functions use `type-lattice-merge` which is idempotent (x ⊔ x = x).

No code changes — design only.

### P1-G2: Structural Unification Propagator (no metas)

Implement `make-structural-unify-propagator` for terms without metavariables:
- Decompose `(Pi a1 b1)` vs `(Pi a2 b2)` → child propagators for `a1=a2`, `b1=b2`
- Handle all AST head constructors (expr-Pi, expr-Sigma, expr-app, etc.)
- This is the safe subset — no meta solving, no side effects

**Tests**: ~15 tests for structural decomposition.

### P1-G3: Meta-Bearing Unification Propagator

Extend to handle `expr-meta` in either position:
- Meta vs concrete: write concrete value to meta's cell (same as `solve-meta!`)
- Meta vs meta: add bidirectional unify propagator between cells
- Applied meta: Miller's pattern check → solve or postpone
- This replaces the `solve-flex-rigid` and `solve-flex-app` functions in `unify.rkt`

**Tests**: ~20 tests covering flex-rigid, flex-flex, applied metas, pattern check.

### P1-G4: Shadow Validation

Run BOTH imperative `unify` and propagator `unify*` in parallel within `typing-core.rkt`.
Compare results. Log divergences. Full suite must show zero mismatches.

Wrapper: `unify-shadow(ctx, t1, t2)` calls both, compares, returns imperative result.
Replace all 23 call sites in `typing-core.rkt` with `unify-shadow`.

**Verify**: Full suite — zero divergences.

### P1-G5: Benchmark Baseline

Capture before-switchover performance:
- `bench-ab.rkt` with 10 benchmark programs × 15 runs
- Record to `data/benchmarks/baseline-unify-propagator.jsonl`
- Key metrics: `unify-steps`, `cell-merge-count`, wall time

### P1-G6: Switchover

Replace `unify-shadow` with `unify*` (propagator version) at all call sites.
Remove `unify-shadow`. The old `unify` function stays but is no longer called
from the main pipeline.

Update `qtt.rkt` (6 sites), test files that call `unify` directly.

**Verify**: Full suite green. Benchmark comparison within 15% of baseline.

### P1-G7: Remove Imperative Unification

Remove old `unify` function body (keep as alias to `unify*` for backward compat).
Remove `solve-flex-rigid`, `solve-flex-app` — their logic is now in propagator
fire functions. Clean up `unify.rkt` exports.

**Verify**: Full suite green.

### P1-G8: PIR

Write `docs/tracking/YYYY-MM-DD_UNIFICATION_PROPAGATOR_PIR.md`.
Gap analysis, performance comparison, lessons learned.

---

## Track 5: GDE — General Diagnostic Engine

**Goal**: Multi-hypothesis conflict analysis for type errors. When an error occurs,
trace ALL ATMS assumptions to find minimal conflict set. Show which declarations/
constraints led to the failure.

**Key files**: `atms.rkt`, `elab-speculation-bridge.rkt`, `elaborator.rkt`,
`typing-core.rkt`, `typing-errors.rkt`, `errors.rkt`

**Depends on**: P1-E3 (clean constraint path), P3 (trait ATMS assumptions), P1-G
(unification ATMS assumptions — richer data)

### GDE-1: Widen ATMS Assumption Coverage

Create ATMS assumptions at MORE sites (not just speculation):
- **`elaborator.rkt`**: For `(def x : T body)`, `spec f : T`, `(check e : T)` —
  create assumption carrying annotation expr + source location
- **`typing-core.rkt`**: At `check`/`infer` boundaries, create assumptions for
  user-provided types from spec/def annotations
- **`elab-speculation-bridge.rkt`**: Accept optional "context assumptions" list
  added to nogood set on failure

**Tests**: Extend `test-provenance-errors.rkt` (~8 new tests)

### GDE-2: Multi-Hypothesis Nogoods + Minimal Diagnosis

- **`elab-speculation-bridge.rkt`**: Redesign nogood recording. Collect active
  context assumptions into support set. Nogoods become multi-hypothesis:
  `(hasheq hyp-id #t context-aid-1 #t context-aid-2 #t ...)`.
- **`atms.rkt`**: Add `atms-minimal-diagnoses` — hitting-set algorithm
  (de Kleer & Williams 1987). Given violated nogoods, find minimal set of
  assumptions whose retraction resolves all conflicts.
  Phase 0: greedy approach — for each nogood, pick assumption in most nogoods.
- **`atms.rkt`**: Add `atms-conflict-graph` — returns assumptions that participate
  in any nogood, with their nogood memberships.

**Tests**: Extend `test-atms.rkt` (~10 tests for minimal diagnoses)

### GDE-3: Rich Error Formatting with Derivation Trees

- **`typing-errors.rkt`**: Extend `build-derivation-chain` to call
  `atms-minimal-diagnoses`. Format each assumption in the diagnosis as a
  "because:" line with datum (annotation text, source location).
- **`errors.rkt`**: Add `diagnosis` field to `type-mismatch-error` and
  `conflicting-constraints-error`. Default `'()` for backward compat.
  Update `format-error` to render diagnosis when non-empty:
  ```
  Error at foo.prologos:5
    Type mismatch: expected Nat, got Bool
    because:
      - user annotated x : Nat at foo.prologos:3
      - function body returns Bool at foo.prologos:5
    minimal fix: change annotation at :3 OR change body at :5
  ```

**Tests**: Extend `test-provenance-errors.rkt` (~10 tests)

### GDE-4: Structured Error Testing Infrastructure

- **`test-support.rkt`**: Add helpers:
  - `check-error-has-provenance` — structured assertion on error struct fields
  - `check-error-diagnosis-count` — verify diagnosis entry count
  - `extract-provenance-json` — parse PROVENANCE-STATS from stderr
- **NEW `tests/test-gde-errors.rkt`** (~25 tests): Single-def mismatches,
  multi-def conflicts, trait failures with ATMS, union exhaustion with diagnosis,
  regression (success programs have no false positive ATMS).
- **`performance-counters.rkt`**: Add `gde-diagnosis-count` counter.

**Verify**: All new tests + full suite green.

---

## Execution Order

| # | Phase | Est. Tests | Key Risk | Commit Pattern |
|---|-------|-----------|----------|----------------|
| 1 | P1-E3a | 15 | Medium (re-entrancy) | Shadow alongside legacy |
| 2 | P1-E3b | 2 | Low | Validation only |
| 3 | P1-E3c | 0 | Medium | Switchover |
| 4 | P1-E3d | 0 | Low | Cleanup |
| 5 | P3a | 12 | Low | Shadow alongside post-pass |
| 6 | P3b | 1 | Low | Validation only |
| 7 | P3c | 0 | Low | Switchover |
| 8 | P3d | 0 | Low | Cleanup |
| 9 | P5a | 10 | Low | New module |
| 10 | P5b | 10 | Low | Additive |
| 11 | P5c | 8 | Low | Additive |
| 12 | P5d | 0 | Low | PIR |
| 13 | P1-G1 | 0 | — | Design doc only |
| 14 | P1-G2 | 15 | Medium | Structural subset |
| 15 | P1-G3 | 20 | High | Meta-bearing |
| 16 | P1-G4 | 0 | Medium | Shadow validation |
| 17 | P1-G5 | 0 | — | Benchmark only |
| 18 | P1-G6 | 0 | Very High | Switchover |
| 19 | P1-G7 | 0 | Medium | Dead code removal |
| 20 | P1-G8 | 0 | — | PIR doc |
| 21 | GDE-1 | 8 | Low-Medium | Widen assumptions |
| 22 | GDE-2 | 10 | Medium | New algorithm |
| 23 | GDE-3 | 10 | Low | Formatting |
| 24 | GDE-4 | 25 | Low | Test infra |
| | **Total** | **~146** | | **24 commits** |

## Verification Strategy

- After each sub-phase: targeted test file (`raco test tests/test-<name>.rkt`)
- After each track completion: full suite (`racket tools/run-affected-tests.rkt --all`)
- After P1-G6 (highest risk): `bench-ab.rkt` comparison vs P1-G5 baseline
- After all tracks: `racket tools/update-deps.rkt --write && --check`
- Final: full benchmark report (`racket tools/benchmark-tests.rkt --report`)

## Files Summary

| File | Tracks | Nature of Change |
|------|--------|-----------------|
| `metavar-store.rkt` | P1-E3, P3, P5 | Constraint retry → propagator, trait → propagator, mult cells |
| `elaborator-network.rkt` | P1-E3, P5, P1-G | +constraint-retry prop, +mult cells, +unify propagators |
| `unify.rkt` | P1-G | Replace imperative unify with propagator-based |
| `typing-core.rkt` | P1-G, GDE-1 | Replace unify calls, add ATMS assumptions |
| `qtt.rkt` | P1-G | Replace unify calls |
| `driver.rkt` | P1-E3, P3, P5 | Install new callbacks, remove post-pass calls |
| `expander.rkt` | P3 | Remove post-pass calls |
| `trait-resolution.rkt` | P3 | Keep but deprecate post-pass |
| `atms.rkt` | GDE-2 | +minimal-diagnoses, +conflict-graph |
| `elab-speculation-bridge.rkt` | GDE-1, GDE-2 | Multi-hypothesis nogoods |
| `elaborator.rkt` | GDE-1 | ATMS assumptions for annotations |
| `typing-errors.rkt` | GDE-3 | Derivation trees with diagnoses |
| `errors.rkt` | GDE-3 | +diagnosis field on error structs |
| `performance-counters.rkt` | P1-E3, GDE-4 | Shadow counters, GDE counter |
| `test-support.rkt` | GDE-4 | Structured error assertion helpers |
| NEW `mult-lattice.rkt` | P5 | Multiplicity lattice |
| NEW test files (6) | All | ~146 new tests |

---

## Progress Log

_Living section — updated as work progresses._

| Phase | Status | Commit | Notes |
|-------|--------|--------|-------|
| P1-E3a | DONE | d2ef419 | cell-ids on constraints, retry-constraints-via-cells!, 16 tests |
| P1-E3b | DONE | 29cdf0f | Shadow validation: zero mismatches across 5092 tests |
| P1-E3c | DONE | b5ba62b | Switchover: cell-state-driven retry is sole production path |
| P1-E3d | DONE | 2de330f | Remove current-prop-driven-wakeup?, cleanup |
| P3a | DONE | ccdd042 | cell-ids on trait constraints, retry-traits-via-cells!, 11 tests |
| P3b | DONE | 73fe021 | Shadow validation: zero mismatches across 5103 tests |
| P3c | DONE | 10b8022 | Switchover: removed resolve-trait-constraints! from 5 driver sites |
| P3d | DONE | 478a82b | Cleanup: removed shadow wrapper, cleaned comments |
| P5a | DONE | 9317e1e | mult-lattice.rkt: 5-element flat lattice, 9 tests |
| P5b | DONE | 2ad5c18 | Mult cells in elab network, callbacks in metavar-store, 6 tests |
| P5c | DONE | 6b69901 | type↔mult cross-domain bridge, 8 bridge unit tests |
| P5d | DONE | (this) | PIR: no regressions, slight improvements across board |
| P1-G1 | PENDING | | |
| P1-G2 | PENDING | | |
| P1-G3 | PENDING | | |
| P1-G4 | PENDING | | |
| P1-G5 | PENDING | | |
| P1-G6 | PENDING | | |
| P1-G7 | PENDING | | |
| P1-G8 | PENDING | | |
| GDE-1 | PENDING | | |
| GDE-2 | PENDING | | |
| GDE-3 | PENDING | | |
| GDE-4 | PENDING | | |
