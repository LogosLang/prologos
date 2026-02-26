# Type Inference on Logic Engine — Implementation Tracker

**Started**: 2026-02-26
**Design Document**: `docs/tracking/2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md`
**Design Critique**: 12 points reviewed; 4 accepted, 2 partially accepted, 7 rejected (commit `9847fe5`)

---

## Phase 0: Benchmarking Baseline — COMPLETE

- [x] 0a: Full instrumented baseline run (schema_version=3, 191 files, 4147 tests)
  - Heartbeats: 138 files instrumented (those using `process-string` via driver)
  - Phase timing: reduce 75%, type-check 15%, elaborate 8%, qtt 2%
  - Total wall: 324.0s (10 parallel jobs)
- [x] 0b: Copied to `data/benchmarks/baseline-system-a.jsonl`
- [x] 0c: Added `--output` flag to `bench-ab.rkt`
- [x] 0d: Comparative baseline (10 programs x 15 runs) → `data/benchmarks/baseline-comparative-a.json`
- [x] 0e: HTML report generated → `data/benchmarks/baseline-report.html`
- [x] 0f: Committed

## Phase 1: Type Lattice Module — COMPLETE

- [x] 1a: Created `type-lattice.rkt` (~230 lines)
  - `type-bot` / `type-top` sentinels
  - `type-lattice-merge` (commutative, associative, idempotent, bot identity)
  - `type-lattice-contradicts?`
  - `try-unify-pure` — pure structural unification without side effects
    - Handles: Pi, Sigma, suc, tycon, app, Eq, Vec, Fin, lam, pair, Type, union, PVec, Set, Map
    - Returns reconstructed result type (not #t/#f like `unify`)
    - Returns #f for metas, holes, flex-apps (can't solve without meta-store)
  - Duplicated union helpers from `unify.rkt` to avoid `metavar-store.rkt` dependency
- [x] 1b: Registered in `dep-graph.rkt` (source-deps)
- [x] 1c: Created `tests/test-type-lattice.rkt` (24 tests)
  - 6 lattice axiom tests
  - 8 structural unification via merge tests
  - 8 try-unify-pure direct tests
  - 2 PropNetwork integration tests
- [x] 1d: Registered test in `dep-graph.rkt` (test-deps)
- [x] 1e: Full suite passes (4202+ tests)
- [x] 1f: This tracking document created
- [x] 1g: Committed

### Key Decisions (Phase 1)
- **Duplicated union helpers** rather than importing from `unify.rkt`, to keep `type-lattice.rkt` free of `metavar-store.rkt` dependency (~30 lines duplicated, all pure functions)
- **`try-unify-pure` reconstructs result types** — unlike `unify` which returns #t/#f/'postponed, the pure version returns the unified type expression itself (needed for lattice merge semantics)
- **Multiplicity matching is structural** (`equal?`) — no mult-meta solving in pure mode
- **`whnf` dependency is acceptable for Phase 1**: `whnf` reads from meta-store but doesn't write; Phase 1 tests only use ground types (no metas). Phase 2+ may need `whnf-pure` that reads from propagator network.

## Phase 2: Parallel Infrastructure — NOT STARTED

## Phase 3: Elaborator Dual-Mode — NOT STARTED

## Phase 4: ATMS Integration for Speculation — NOT STARTED

## Phase 5: Full Switchover + Error Improvement — NOT STARTED

## Phase 6: Performance Optimization — NOT STARTED
