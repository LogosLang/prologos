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
| 4a | capability-constraint-info struct + registry (metavar-store.rkt) | done | `756aaa4` |
| 4b | current-capability-scope + find-capability-in-scope (macros.rkt) | done | `756aaa4` |
| 4c | Lambda scope tracking + insert-implicits resolution (elaborator.rkt) | done | `756aaa4` |
| 4d | Subtype-aware resolution (exact→solve, subtype→leave unsolved) | done | `756aaa4` |
| 4e | check-unresolved-capability-constraints (trait-resolution.rkt) | done | `756aaa4` |
| 4f | E2001 error in driver.rkt process-def paths | done | `756aaa4` |
| 4g | prelude-capability-registry in test-support.rkt | done | `756aaa4` |
| 4h | Tests: test-capability-04.rkt (12 tests, all pass) | done | `756aaa4` |

## Phase 5: Capability Inference

Initially used iterative fixed-point due to CHAMP trie scaling bug. CHAMP bug identified and
fixed (`a2dbea4`): `node-insert` used `equal-hash-code` during data-to-node promotion instead
of stored caller-provided hash — causing ~30% data loss with custom hash functions (like
`cell-id-hash`). Fix: store hash in data entries as 3-vectors `#(hash key val)`.

Migrated to propagator network (`6b9eb57`): each function → cell seeded with declared caps,
each call edge → propagator, `cap-set-join` as merge, `run-to-quiescence` computes transitive
closure. All 21 existing tests pass without modification.

| Sub-phase | Description | Status | Commit |
|---|---|---|---|
| 5a | CapabilitySet lattice (cap-set, join, subsumes?) | done | `7d651cb` |
| 5b | Expression analysis (extract-fvar-names, extract-capability-requirements) | done | `7d651cb` |
| 5c | Inference via propagator network (was iterative, migrated) | done | `6b9eb57` |
| 5d | Query API (capability-closure, capability-audit-trail) | done | `7d651cb` |
| 5e | REPL commands (cap-closure, cap-audit) in parser/elaborator/driver | done | `7d651cb` |
| 5f | Tests: test-capability-05.rkt (21 tests, all pass) | done | `7d651cb` |
| 5g | CHAMP trie fix: store hash in data entries | done | `a2dbea4` |
| 5h | ATMS provenance for capability audit trails (15 tests in test-capability-05b.rkt) | done | `44015d2` |
| 5i | Authority root verification + cap-verify REPL command (10 new tests, 24 total in 05b) | done | `1372178` |

## Phase 6: Foreign Function Capability Gating

| Sub-phase | Description | Status | Commit |
|---|---|---|---|
| 6a | `:requires` + `$brace-params` parsing in handle-foreign | done | `533928d` |
| 6b | Type extension: prepend `:0` Pi binders for capabilities | done | `533928d` |
| 6c | Integration with inference (automatic via existing Pi chain walking) | done | `533928d` |
| 6d | Tests: test-capability-06.rkt (15 tests, all pass) | done | `533928d` |
