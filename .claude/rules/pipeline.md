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
4. **Grep for direct constructor calls `(struct-name field1 field2 ...)` across the ENTIRE codebase** — not just `struct-copy`. PPN 4C S2.b-iv (2026-04-24) added `meta-ids` field to `constraint` struct and missed 4 direct constructor calls in 2 test files (test-infra-cell-constraint-01.rkt + test-readiness-propagator.rkt) that were caught at full-suite regression with "constraint: arity mismatch; expected 8 given 7". Both `struct-copy` AND direct constructor calls need updating; grep for both patterns.
5. Check `trace-serialize.rkt` and any other reflection-based consumers
6. If the struct is in `prop-network` or `elab-network`, modules like `session-propagators.rkt` and `trace-serialize.rkt` that import by struct linklet will fail if not recompiled

## Known Coupling: Meta Resolution Pipeline

Any code path that solves a meta variable at the propagator cell level **must also call `solve-meta!`** to trigger the stratified resolution chain (trait resolution, hasmethod, constraint retries). The propagator network and the imperative resolution system are fundamentally coupled: cell-level solutions are invisible to the resolution loop until `solve-meta!` bridges them into the `meta-info` CHAMP.

PUnify Phase -1 (commit `7a90f6c`) discovered this when `punify-dispatch-sub/pi/binder` solved metas via structural-unify-propagators but never called `solve-meta!`, causing parametric trait constraints (e.g., `Seqable ?A` where `?A` = `List`) to go unresolved. The fix (`punify-bridge-cell-solves!`) detects cell-solved/CHAMP-unsolved metas after each dispatch + quiescence and bridges the gap.

**Rule**: Any alternative unification or solving path that writes to meta cells must ensure `solve-meta!` fires for each newly-solved meta. This coupling persists until Track 8 module restructuring decouples cell writes from resolution triggering.

## New Pattern Kind

When adding a new pattern kind to the pattern compiler:

1. Update `pattern-is-simple-flat?` — the fast-path classifier. Missing this causes ALL patterns to fall through to the slow `compile-match-tree` path (850s regression observed from missing `'wildcard`)
2. Update `compile-match-tree` — the full compiler
3. Update narrowing pattern handlers in `narrowing.rkt` if applicable

## Per-Domain Universe Migration (PPN 4C Step 2 pattern)

When migrating a meta domain (type, mult, level, session) to compound universe-cell dispatch (S2.b-iii, S2.c-iv, future S2.d), the following sites MUST be co-migrated ATOMICALLY in the SAME commit. Missing any one causes a class of failures characterized by:
- `compound-tagged-merge "expects hasheq values"` errors when raw values hit compound merge (solve-X-meta! gap)
- `mult-meta-solved? = #f` for all solved metas (universe-active flag flip without storage migration, or vice versa)
- 4-minute infinite hangs with no clear error signal during testing (caught in S2.c-iv 2026-04-24 — diagnosis took ~30 min after the hang)

**Co-migration sites (checklist)**:

1. **`fresh-X-meta`** — universe-path branch: register meta-id as component of `(current-X-meta-universe-cell-id)` via `compound-cell-component-write`; record `meta-id → universe-cid` in id-map; SKIP per-meta cell allocation. Legacy per-meta path preserved for pre-init test contexts.

2. **`solve-X-meta!`** — universe-cid dispatch: when cell-id from id-map IS the universe-cid (`meta-universe-cell-id?` returns #t), use `compound-cell-component-write` at component=meta-id. Writing the raw value via legacy callback (`current-prop-X-cell-write`) under universe migration triggers `compound-tagged-merge "expects hasheq values"` error since the cell is now compound. **THIS IS THE MOST COMMONLY MISSED STEP** — both S2.b-iii (type) and S2.c-iv (mult) had to be diagnosed via runtime hang. Proactively check during mini-design.

3. **`'X-meta-info` table `'universe-active? = #t` flip** in `meta-domain-info` (metavar-store.rkt). The CORRECTNESS GATE codified per S2.c-iii §5.4: data-driven dispatch flag flips ATOMICALLY with storage migration. Pre-flip = legacy path; post-flip = universe path. Naive flip without storage migration → all solved metas appear unsolved (universe is empty). Naive storage migration without flip → reads still go through legacy CHAMP fallback (silent miss).

4. **Cross-domain bridge callback** (if applicable, e.g., `current-structural-mult-bridge` at driver.rkt:2658) — universe-aware install with `:a-component-paths (list (cons X-universe-cid X-meta-id))`. Per S2.precursor++ correct-by-construction contract, the primitive uses `compound-cell-component-{ref,write}/pnet` automatically when component-paths declared. If the γ direction is dead work (e.g., constant bot), pass `gamma-fn=#f` to skip the install.

5. **Retire dead γ closures** if applicable — e.g., `mult->type-gamma` was constant `type-bot` (dead work, retired in S2.c-iv). Check whether the domain's α/γ closures have meaningful work in both directions; retire dead ones.

**Verification procedure**:

- Targeted test set MUST include: `test-X-inference.rkt`, `test-X-propagator.rkt`, the bridge consumers (e.g., `test-tycon.rkt`, `test-trait-tycon-01.rkt` for type-related dispatch).
- Run probe (`examples/2026-04-22-1A-iii-probe.prologos`) — expect counter changes related to the domain (e.g., `cell_allocs` decrease as per-meta cells consolidate into the universe).
- Run acceptance file (`examples/2026-04-17-ppn-track4c.prologos`) — 0 errors.
- Full suite as final regression gate.

**If hung during testing** (4-minute timeout with no progress, dead workers): the most likely cause is a missed `solve-X-meta!` dispatch (#2 above). Diagnose by running a single targeted test in foreground and checking for `compound-tagged-merge "expects hasheq values"` error in the stderr. The fix: add the universe-cid dispatch to `solve-X-meta!` mirroring `solve-meta-core!`'s pattern (S2.b-iii type-domain template).

**Cross-cutting**: `'universe-active?` flip in `meta-domain-info` MUST be in the same commit as `fresh-X-meta` AND `solve-X-meta!` migrations. Splitting across commits leaves the codebase in an inconsistent state where dispatch + storage + writes don't agree.

Origin: PPN 4C S2.b-iii (type-domain migration, 2026-04-24) had the same gap shape; S2.c-iv (mult-domain migration, 2026-04-24) repeated it because the pattern wasn't codified. Codified here after S2.c-iv close so S2.d (level + session migrations) lands cleanly. 2 data points; codify proactively to prevent the 3rd.

See: D.3 §7.5.13.6.1 (S2.c-iii mini-audit findings) + §7.5.14.3 (S2.e cleanup notes from S2.c-iv adversarial VAG).
4. Update `narrow-match` and `narrow-subst-bvars` if the pattern contains sub-expressions
