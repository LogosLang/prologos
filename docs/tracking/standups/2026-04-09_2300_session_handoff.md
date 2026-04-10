# Session Handoff: BSP-LE Track 2 (2026-04-09)

## Session Scope

Phases 4–10 of BSP-LE Track 2 implemented. Propagator-native solver built end-to-end.

## What's Done (Phases 0–10)

| Phase | What | Key Commits |
|---|---|---|
| 0 | Benchmarks + acceptance file | baseline |
| 1 | Decision cell + broadcast propagator | `4df2a4d8`, `fb0650a3` |
| 2 | PU-per-branch lifecycle | `0a78069a` |
| 3 | Per-nogood propagators | `a38baefb` |
| 4 | Bitmask-tagged cell values (TMS replacement) | `72394146`, `eb03d060` |
| 5 | ATMS dissolution → compound cells + solver-context | 19 commits |
| 6+7 | Propagator-native solver (concurrent multi-clause, all goal types, Gray code, tabling migration) | ~15 commits |
| 8 | On-network tabling (compound scope cells, registry cell, producer/consumer) | 4 commits |
| 9 | Strategy dispatch + partial parameter migration | `97d8048d`–`04b7060c` |
| 10 | Solver config wiring (:execution, :tabling, :timeout) | `6fe6679c` |

## What's Deferred to Phase 11

### TMS/tagged-cell-value merge gap (CRITICAL)

Union type `<Nat | Bool>` regression when TMS `parameterize` removed from typing-propagators. Root cause: tagged-cell-value merge semantics for nested attribute-map speculation don't replicate TMS tree isolation. The TMS tree provides per-branch isolation via ordered stack navigation. The tagged-cell-value model uses unordered bitmask tags — works for propagator-native solver branches but NOT for nested elaboration speculation on the attribute-map cell.

Investigation needed: what specific merge operation produces different results under TMS vs tagged-cell-value? Is it the per-key merge in the attribute-map (nested hasheq), or the tagged-cell-value entry ordering, or the bitmask subset check?

### `current-speculation-stack` full retirement

2/5 consumers migrated to worldview-bitmask-first (metavar-store, cell-ops). 3/5 retain dual-write (elab-speculation-bridge, typing-propagators, propagator.rkt TMS fallback). Gated on merge gap resolution.

### Inert-dependent checkpoint

Review `perf-inc-inert-dependent-skip!` counter data from parity benchmarks. How many inert entries per cell? Is S(-1) lattice-narrowing cleanup warranted?

### DFS ↔ propagator parity

`:auto` stays DFS because propagator solver doesn't match DFS for all cases. Specifically: stratified negation, recursive clauses with full substitution threading, the `is` goal with substitution-aware expression evaluation. Each needs investigation.

### S(-1) lattice-narrowing cleanup

Retraction as lattice narrowing on metadata (dependents, provenance, trace entries). Deferred pending instrumentation data.

## Key Architectural Discoveries (This Session)

### Per-propagator worldview bitmask

`current-worldview-bitmask` parameter enables concurrent propagators on the SAME network with distinct worldviews. Each propagator's fire function sets its bitmask via `wrap-with-worldview`. `net-cell-write` tags writes, `net-cell-read` filters reads. BSP fires all concurrently.

CRITICAL FIX: `fire-and-collect-writes` must use `net-cell-read-raw` for snapshot/result diffing. `net-cell-read` applies worldview filtering, making tagged entries invisible to the diff.

### Compound scope cells

One `scope-cell` per clause scope instead of one cell per variable. Reduces M×K cells to M cells. The scope cell IS a substitution — variables are components, unification writes to components, merge handles per-variable composition. Table entries ARE scope cells.

### Table registry as on-network cell

`solver-context-table-registry-cid` holds a hash-union cell mapping relation-name → table-cell-id. This pioneers the pattern for ALL compiler registries (module, relation, trait) migrating to cells. Self-hosting path.

### promote-cell-to-tagged must update merge function

Not just the value. Without updating the merge function, the original merge (e.g., `logic-var-merge`) doesn't understand tagged-cell-value structure and destroys entries during merge.

### Tagged-cell-value entry ordering

`make-tagged-merge` and `tagged-cell-merge`: NEW entries must be prepended (not appended). `tagged-cell-read` uses strict `>` on popcount — first match at max specificity wins. New-first ordering ensures latest writes are returned.

## Process Documents Created

- `.claude/rules/propagator-design.md` — fire-once, broadcast, component-indexing, worldview bitmask, cell allocation
- `.claude/rules/on-network.md` — self-hosting mandate, migration checklist, red flags
- `.claude/rules/structural-thinking.md` — SRE lattice lens, Hasse diagrams, module theory, Hyperlattice Conjecture, retraction as narrowing
- `.claude/rules/testing.md` — updated with trigger-level diagnostic protocol

## Process Lessons

1. **Full suite is NOT a diagnostic tool**: 5+ instances this session. The trigger "N FAILURES" must immediately redirect to reading failure logs, not re-running.
2. **Stale .zo**: precompile-modules! now compiles test files (bench-lib.rkt fix). Eliminates the linklet mismatch class of false failures.
3. **Phase completion checklist is BLOCKING**: Vision Alignment Gate + Network Reality Check before marking a phase complete. Architecture tests, not just behavioral parity.
4. **"Validated Is Not Deployed"**: infrastructure exists alongside old path is NOT completion. Deployment = old path removed or honestly labeled as scaffolding with retirement plan.

## File Index (Hot-Load for Next Session)

- Design doc: `docs/tracking/2026-04-07_BSP_LE_TRACK2_DESIGN.md` (D.12)
- Dailies: `docs/tracking/standups/2026-04-09_dailies.md`
- Propagator solver: `racket/prologos/relations.rkt` (install-goal-propagator, install-clause-propagators, solve-goal-propagator)
- Compound cells: `racket/prologos/decision-cell.rkt` (decisions-state, commitments-state, scope-cell)
- Solver context: `racket/prologos/atms.rkt` (solver-context, solver-state, table operations)
- Propagator core: `racket/prologos/propagator.rkt` (worldview cache, fire-once, broadcast, promote-cell-to-tagged)
- Tests: `racket/prologos/tests/test-propagator-solver.rkt`, `test-solver-context.rkt`
