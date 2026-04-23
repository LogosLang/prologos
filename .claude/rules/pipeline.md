# Pipeline Exhaustiveness Checklists

These checklists prevent the recurring class of bugs where a new construct is added but not handled in all pipeline stages. Missing one stage causes subtle failures — silent wrong results, performance regressions, or crashes in unrelated code paths.

## New AST Node

When adding a new AST node, the set of files to update depends on **whether the node has user-facing surface syntax** vs being internal-only (produced by elaboration or inference).

### Core pipeline — every AST node touches these

These are the always-touch files. No exceptions.

1. `syntax.rkt` — struct definition + `provide struct-out` + `expr?` predicate entry
2. `substitution.rkt` — `shift` and `subst` (identity case for atomic nodes; recursive for nodes with sub-exprs; binder-respecting for nodes with binders)
3. `zonk.rkt` — all three zonk functions (`zonk`, `zonk-at-depth`, `default-metas`)
4. `reduction.rkt` — `whnf` (at minimum, add to `trivially-whnf?` set for stuck/atomic nodes; add `nf` identity case). Check `definitely-not-map?` if the node could appear as a value.
5. `pretty-print.rkt` — `pp-expr` display + `uses-bvar0?` recursion
6. `pnet-serialize.rkt` — `reg0!` / `reg1!` / `regN!` for auto-cache serialization. **REQUIRED post-PM 10** — module caching depends on this. (Pre-PM-10 checklists missed this; don't.)
7. `typing-core.rkt` — `infer` / `check` / `is-type` / `infer-level` cases
8. `qtt.rkt` — `inferQ` / `checkQ` cases (must parallel typing-core)

### User-facing surface syntax — add these if the node has surface form

If users can write the construct directly in `.prologos` files, also update:

9. `surface-syntax.rkt` — surf-* struct + provides (surf-* structs carry `loc` field)
10. `parser.rkt` / `tree-parser.rkt` — parse rule (WS mode goes through tree-parser; sexp mode through parser)
11. `elaborator.rkt` — `elaborate` case (surf-* → expr-*)
12. If the construct desugars or has preparse rewrites: `macros.rkt`

### On-network typing — add this if the node needs typed propagator machinery

13. `typing-propagators.rkt` — `install-typing-network` case + fire-function factory. **Only needed if the node introduces new structural typing behavior not handled by SRE ctor-desc decomposition.** Most new AST nodes with `ctor-desc` registration in `ctor-registry.rkt` get automatic on-network typing via generic structural decomposition.

### Unification + FFI — add these if applicable

14. `unify.rkt` — `classify-whnf-problem` + `unify-whnf` dispatch. Required if the node participates in unification at the structural level (vs being handled by SRE).
15. `foreign.rkt` — only if the node represents a runtime interop concept (foreign values, opaque handles, etc.)

### Internal-only nodes — the shorter path

Nodes produced only by elaboration/inference (no user surface syntax, no user writability) typically need files 1-8 + maybe 14. Examples:
- `expr-Open` (PPN 4C T-2, 2026-04-23): 10 files actually touched (1-7, 8, 11, 14) — skipped surface-syntax, parser, macros, foreign, typing-propagators.
- `expr-meta` (inference placeholder): 1-8 + special handling in resolution
- `expr-error` (elaboration error): 1-5 + explicit error-propagation cases

### Post-addition verification

- Run `tools/check-parens.sh <file>` after every `.rkt` edit (instant, ~100ms, catches mismatched brackets before `raco make`)
- `raco make driver.rkt` — compiles ALL transitive dependents; resolves stale `.zo` issues
- Targeted tests for the module via `racket tools/run-affected-tests.rkt --tests tests/test-X.rkt` (uses scoped precompile to refresh test `.zo` linklets after production export changes)
- Probe file (if one exists for the current track) before AND after the change
- Full suite as regression gate (not for diagnostics)

## New Racket Parameter

When adding a new Racket parameter, immediately add entries in ALL applicable locations:

1. Definition site (the module that owns it)
2. `test-support.rkt` parameterize block
3. `batch-worker.rkt` save/restore list
4. `with-fresh-meta-env` if it's meta/constraint-related
5. `reset-meta-store!` / `reset-constraint-store!` if it needs reset
6. `save-meta-state` / `restore-meta-state!` if it must survive speculation rollback

Missing any one causes intermittent failures that are difficult to diagnose — batch worker isolation failures, speculation leaks, or test pollution.

### Two-Context Audit

When adding a new parameter, callback, or cell infrastructure, verify behavior in ALL execution contexts:

1. **Elaboration context** (inside `process-command`): network active, cells valid, callbacks installed
2. **Module-loading context** (outside `process-command`): no network, parameter-only, `register-*-cells!` not yet called
3. **`run-ns-last` test path**: minimal `parameterize`, no network factory — diverges from production `process-file`/`process-string`
4. **`batch-worker.rkt`**: snapshot/restore cycle — verify the parameter survives the save/restore round-trip

Every track from 3 through 8 has hit this boundary. Track 3: elaboration guards. Track 5: `run-ns-last` divergence. Track 6: net-box scoping. Track 7: module-load-time registration. Track 8/PUnify: callback scope spans both contexts. The elaboration/module-loading boundary is the permanent architectural seam — infrastructure that works in one context but not the other produces intermittent, hard-to-diagnose failures.

## New Struct Field

When adding a field to an existing struct:

1. Run `raco make driver.rkt` to recompile ALL transitive dependents (stale `.zo` caches cause "expected N fields" errors)
2. Grep for all pattern-matches on that struct — each must handle the new field
3. **Grep for `struct-copy` of that struct across the ENTIRE codebase** — not just the defining module. External files that `struct-copy` a struct with changed fields will fail silently (batch workers crash with zero test output). BSP-LE Track 0 discovered 4 external `struct-copy prop-network` sites (bilattice.rkt, elaborator-network.rkt, test-propagator-bsp.rkt, bench-alloc.rkt) that were missed by a module-scoped audit.
4. Check `trace-serialize.rkt` and any other reflection-based consumers
5. If the struct is in `prop-network` or `elab-network`, modules like `session-propagators.rkt` and `trace-serialize.rkt` that import by struct linklet will fail if not recompiled

## Known Coupling: Meta Resolution Pipeline

Any code path that solves a meta variable at the propagator cell level **must also call `solve-meta!`** to trigger the stratified resolution chain (trait resolution, hasmethod, constraint retries). The propagator network and the imperative resolution system are fundamentally coupled: cell-level solutions are invisible to the resolution loop until `solve-meta!` bridges them into the `meta-info` CHAMP.

PUnify Phase -1 (commit `7a90f6c`) discovered this when `punify-dispatch-sub/pi/binder` solved metas via structural-unify-propagators but never called `solve-meta!`, causing parametric trait constraints (e.g., `Seqable ?A` where `?A` = `List`) to go unresolved. The fix (`punify-bridge-cell-solves!`) detects cell-solved/CHAMP-unsolved metas after each dispatch + quiescence and bridges the gap.

**Rule**: Any alternative unification or solving path that writes to meta cells must ensure `solve-meta!` fires for each newly-solved meta. This coupling persists until Track 8 module restructuring decouples cell writes from resolution triggering.

## New Pattern Kind

When adding a new pattern kind to the pattern compiler:

1. Update `pattern-is-simple-flat?` — the fast-path classifier. Missing this causes ALL patterns to fall through to the slow `compile-match-tree` path (850s regression observed from missing `'wildcard`)
2. Update `compile-match-tree` — the full compiler
3. Update narrowing pattern handlers in `narrowing.rkt` if applicable
4. Update `narrow-match` and `narrow-subst-bvars` if the pattern contains sub-expressions
