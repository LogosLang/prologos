# Capabilities as Types: Implementation Tracking

**Design**: `docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md`
**Plan**: `.claude/plans/buzzing-launching-pascal.md`
**Started**: 2026-03-01

## Phase 1: Capability Declaration + Kind Marker

| Sub-phase | Description | Status | Commit |
|---|---|---|---|
| 1a | `surf-capability` struct in surface-syntax.rkt | done | `0fd0470` |
| 1b | `capability` keyword in parser.rkt | done | `0fd0470` |
| 1c | Capability registry in macros.rkt | done | `0fd0470` |
| 1d | `expand-top-level` pass-through | done | `0fd0470` |
| 1e | `process-capability-declaration` in elaborator.rkt | done | `0fd0470` |
| 1f | Driver dispatch for `capability` | done | `0fd0470` |
| 1g | Tests: test-capability-01.rkt (11 tests, all pass) | done | `0fd0470` |

## Phase 2: Multiplicity Defaulting + `:w` Warning

| Sub-phase | Description | Status | Commit |
|---|---|---|---|
| 2a | QTT defaulting for capability constraints | done | `f2bf6ad` |
| 2b | `:w` warning emission (W2001) | done | `f2bf6ad` |
| 2c | Tests: test-capability-02.rkt (13 tests, all pass) | done | `f2bf6ad` |

## Phase 3: Infix `<:` Syntax + Standard Hierarchy

| Sub-phase | Description | Status | Commit |
|---|---|---|---|
| 3a | Capability-aware subtype (skip coercion) + module loading | done | `641f015` |
| 3b | Standard capability library (capabilities.prologos) | done | `641f015` |
| 3c | PRELUDE, dep-graph, namespace.rkt updates | done | `641f015` |
| 3d | Tests: test-capability-03.rkt (11 tests, all pass) | done | `641f015` |
| — | `<:` infix syntax deferred (sugar, not blocking) | deferred | |

## Phase 4: Lexical Capability Resolution

| Sub-phase | Description | Status | Commit |
|---|---|---|---|
| 4a | capability-constraint-info struct + registry (metavar-store.rkt) | done | |
| 4b | current-capability-scope + find-capability-in-scope (macros.rkt) | done | |
| 4c | Lambda scope tracking + insert-implicits resolution (elaborator.rkt) | done | |
| 4d | Subtype-aware resolution (exact→solve, subtype→leave unsolved) | done | |
| 4e | check-unresolved-capability-constraints (trait-resolution.rkt) | done | |
| 4f | E2001 error in driver.rkt process-def paths | done | |
| 4g | prelude-capability-registry in test-support.rkt | done | |
| 4h | Tests: test-capability-04.rkt (12 tests, all pass) | done | |

## Phase 5: Capability Inference via Propagator Network

| Sub-phase | Description | Status | Commit |
|---|---|---|---|
| 5a | CapabilitySet lattice | pending | |
| 5b | Network construction | pending | |
| 5c | Call-edge propagators | pending | |
| 5d | Run to quiescence | pending | |
| 5e | ATMS provenance | pending | |
| 5f | Authority root verification | pending | |
| 5g | REPL commands | pending | |
| 5h | Tests: test-capability-05.rkt | pending | |

## Phase 6: Foreign Function Capability Gating

| Sub-phase | Description | Status | Commit |
|---|---|---|---|
| 6a | Foreign capability annotation syntax | pending | |
| 6b | Elaboration of foreign capabilities | pending | |
| 6c | Integration with inference network | pending | |
| 6d | Tests: test-capability-06.rkt | pending | |
