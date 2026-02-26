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

## Phase 2: Parallel Infrastructure — COMPLETE

- [x] 2a: Created `elaborator-network.rkt` (~180 lines)
  - `elab-network` wrapper struct (prop-net + cell-info CHAMP + next-meta-id counter)
  - `elab-cell-info` struct (ctx, type, source) — replaces `meta-info` locally
  - `make-elaboration-network` wraps `make-prop-network`
  - `elab-fresh-meta` allocates cell at `type-bot` with `type-lattice-merge`/`type-lattice-contradicts?`
  - `elab-cell-read` / `elab-cell-write` / `elab-cell-info-ref`
- [x] 2b: Unification propagator
  - `make-unify-propagator` — bidirectional fire-fn (both cells are inputs AND outputs)
  - Handles: bot-bot no-op, bot-T propagation, T-T idempotent, T1-T2 contradiction
  - Termination: guaranteed by `net-cell-write`'s no-change guard
  - `elab-add-unify-constraint` wraps `net-add-propagator`
- [x] 2c: Solve + contradiction extraction
  - `elab-solve` runs to quiescence, returns `(values 'ok enet*)` or `(values 'error contradiction-info)`
  - `contradiction-info` struct (cell-id, cell-meta, value)
- [x] 2d: Helper queries
  - `elab-cell-solved?`, `elab-cell-read-or`, `elab-all-cells`, `elab-unsolved-cells`, `elab-contradicted-cells`
- [x] 2e: Registered in `dep-graph.rkt` (source-deps + test-deps)
- [x] 2f: Created `tests/test-elaborator-network.rkt` (22 tests)
  - 3 network creation tests
  - 4 cell operation tests
  - 7 unification propagator tests (including transitive chain A=B=C)
  - 3 elab-solve tests
  - 3 helper query tests
  - 2 structural propagation tests (Pi, app)
- [x] 2g: Full suite passes
- [x] 2h: Committed

### Key Decisions (Phase 2)
- **`elab-network` wrapper struct** — design doc shows bare `prop-network`, but we need per-cell metadata (ctx, type, source). Wrapper keeps metadata co-located as a single pure value without polluting the general-purpose propagator API
- **No `metavar-store.rkt` dependency** — `elab-cell-info` replaces `meta-info` locally; `source` field accepts any (strings, srclocs, or Phase 3's `meta-source-info`)
- **Level/mult metas deferred** — trivially flat domains (3-value for mults, small finite for levels), almost always solved immediately or defaulted. Adds scope without validating core approach. Trivial to add later.
- **Applied metas use "idle until ground" pattern** — propagator fires, reads bot, returns unchanged. When cell gets solved from another direction, propagator re-fires with concrete values. No special propagator type needed.

## Phase 3: Shadow Network Validation — COMPLETE

- [x] 3a: Shadow hooks in `metavar-store.rkt` (~15 lines)
  - Three callback parameters: `current-shadow-fresh-hook`, `current-shadow-solve-hook`, `current-shadow-constraint-hook`
  - Default `#f` = zero overhead when shadow off (one `#f` check per call ~1ns)
  - Hook call sites: after `fresh-meta` registration, after `solve-meta!` retry, after `add-constraint!` wakeup registration
- [x] 3b: Created `elab-shadow.rkt` (~155 lines)
  - `shadow-report` struct: total-metas, total-solved, shadow-solved, contradictions, mismatches, constraints-added, ok?
  - Mutable state: `current-shadow-network` (boxed elab-network), `current-shadow-id-map` (hasheq meta-id → cell-id)
  - `shadow-init!` / `shadow-teardown!` lifecycle
  - `shadow-on-fresh-meta` — mirrors meta creation to shadow cell
  - `shadow-on-solve-meta` — writes solution to shadow cell
  - `shadow-on-constraint` — adds unification propagators between meta cells referenced by lhs/rhs
  - `extract-shallow-meta-ids` — shallow meta walker (doesn't follow solved metas, unlike `collect-meta-ids`)
  - `shadow-validate!` — runs network to quiescence, compares with meta-store, reports mismatches
  - `shadow-log-report!` — stderr output
- [x] 3c: Wired into `driver.rkt` (~20 lines)
  - `current-shadow-mode?` parameter (default `#f`)
  - `maybe-shadow-validate!` helper — validates + logs + tears down
  - Called after trait resolution succeeds in: eval path, infer path, defr path, type-inferred def path, annotated def path
  - `shadow-init!` called at start of `process-command` when shadow mode active
- [x] 3d: Created `tests/test-elab-shadow.rkt` (18 tests)
  - 3 hook installation tests
  - 4 meta mirroring tests (fresh, solve, multiple, ground match)
  - 3 constraint mirroring tests (two metas, unknown meta safety, nested expressions)
  - 4 validation tests (all-ground ok, contradiction detected, consistent chain, unsolved not errors)
  - 4 driver integration tests (def, infer, eval in sexp mode + prelude implicit args)
- [x] 3e: Registered in `dep-graph.rkt` (source-deps + test-deps)
- [x] 3f: Full suite passes (4266 tests, 197 files)
- [x] 3g: Committed

### Key Decisions (Phase 3)
- **Mirror-and-validate, not dual elaboration** — design doc's `elaborate-dual` requires reimplementing ~40 call sites. Shadow hooks achieve validation with ~15 lines of changes to existing code. Validates the same core properties.
- **Mutable box for shadow network** — hooks are called from imperative meta-store ops, so shadow state must be mutable. Box wraps the immutable elab-network (CHAMP-backed structural sharing preserved).
- **Constraint hook adds propagators** — when `add-constraint!` fires, we add unification propagators between shadow cells referenced by lhs/rhs metas. This validates the propagator network handles postponed constraints.
- **Advisory only** — shadow mismatches log to stderr, never affect program behavior. Existing system's result is always returned.
- **`run-to-quiescence` directly** — `elab-solve` discards network on contradiction (returns `contradiction-info`). Shadow validation needs the post-quiescence network to inspect cell values, so it calls `run-to-quiescence` directly.

## Phase 4: ATMS-Backed Speculation — COMPLETE

- [x] 4a: Created `elab-speculation.rkt` (~155 lines)
  - `speculation` struct: ATMS + base elab-network + branches + counter
  - `branch` struct: hypothesis-id, forked enet, status, contradiction, label
  - `speculation-result` struct: status, winning enet, winner-index, nogoods, ATMS
  - `nogood-info` struct: branch-index, label, contradiction, hypothesis-id
  - `speculation-begin` — create speculation context with ATMS amb (mutual exclusion)
  - `speculation-try-branch` — fork network, apply try-fn, run to quiescence, detect contradictions
  - `speculation-commit` — select first OK branch, collect nogoods from failures
  - `speculate-first-success` — convenience short-circuiting wrapper
  - Uses `run-to-quiescence` directly (same pattern as shadow-validate!) to preserve post-quiescence network even on contradiction
- [x] 4b: Created `tests/test-elab-speculation.rkt` (18 tests)
  - 3 construction tests (2-way, 3-way with mutual exclusion, fork from same base)
  - 4 binary speculation tests (both succeed, left-fails, both-fail, short-circuit)
  - 3 map widening pattern tests (fits, doesn't fit, contradiction info preserved)
  - 2 multi-way tests (3-way 1-succeeds, 3-way all-fail)
  - 3 nested speculation tests (inner within outer, inner failure doesn't invalidate outer, independent ATMS)
  - 3 persistence/error reporting tests (base unchanged, nogood labels/indices, contradiction cell details)
- [x] 4c: Registered in `dep-graph.rkt` (source-deps + test-deps)
- [x] 4d: Full suite passes (4284 tests, 198 files)
- [x] 4e: Committed

### Key Decisions (Phase 4)
- **Separate module, not elaborator-network.rkt extensions** — speculation is a higher-level concept built on top of the base network. Same layering as elab-shadow.rkt.
- **ATMS for hypothesis tracking, elab-network forking for state** — ATMS tracks nogoods/mutual exclusion. Actual type state lives in forked elab-networks (persistent, O(1) fork). ATMS used only for hypothesis/nogood management.
- **`try-fn` callback pattern** — `speculation-try-branch` takes `(elab-network → elab-network)`. Keeps module free of typing-core dependencies. Phase 5 calls with real type-checking functions.
- **No metavar-store dependency** — purely functional module. Operates on elab-networks without touching imperative meta-store. Phase 5 bridges both.
- **`run-to-quiescence` directly** — same lesson from Phase 3: `elab-solve` discards network on contradiction. Speculation needs the post-quiescence network for `extract-contradiction-info`.

## Phase 5: Full Switchover + Error Improvement — NOT STARTED

## Phase 6: Performance Optimization — NOT STARTED
