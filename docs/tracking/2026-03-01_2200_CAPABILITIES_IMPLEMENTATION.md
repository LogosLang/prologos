# Capabilities as Types: Implementation Tracking

**Design**: `docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md`
**Plan**: `.claude/plans/buzzing-launching-pascal.md`
**Started**: 2026-03-01

## Phase 1: Capability Declaration + Kind Marker

| Sub-phase | Description | Status | Commit |
|---|---|---|---|
| 1a | `surf-capability` struct in surface-syntax.rkt | pending | |
| 1b | `capability` keyword in parser.rkt | pending | |
| 1c | Capability registry in macros.rkt | pending | |
| 1d | `expand-top-level` pass-through | pending | |
| 1e | `process-capability-declaration` in elaborator.rkt | pending | |
| 1f | Driver dispatch for `capability` | pending | |
| 1g | Tests: test-capability-01.rkt | pending | |

## Phase 2: Multiplicity Defaulting + `:w` Warning

| Sub-phase | Description | Status | Commit |
|---|---|---|---|
| 2a | QTT defaulting for capability constraints | pending | |
| 2b | `:w` warning emission (W2001) | pending | |
| 2c | Tests: test-capability-02.rkt | pending | |

## Phase 3: Infix `<:` Syntax + Standard Hierarchy

| Sub-phase | Description | Status | Commit |
|---|---|---|---|
| 3a | `<:` infix operator in reader + preparse | pending | |
| 3b | Standard capability declarations (.prologos) | pending | |
| 3c | PRELUDE and dep-graph updates | pending | |
| 3d | Tests: test-capability-03.rkt | pending | |

## Phase 4: Lexical Capability Resolution

| Sub-phase | Description | Status | Commit |
|---|---|---|---|
| 4a | Separate resolution path | pending | |
| 4b | Integration into type checking | pending | |
| 4c | Subtype-aware resolution | pending | |
| 4d | Error messages (E2001, E2002) | pending | |
| 4e | Tests: test-capability-04.rkt | pending | |

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
