# PM Track 12 Implementation Note — Registry Read-Path: Retiring the Parameter Fallback

**Created**: 2026-07-27
**Status**: Design input for PM Track 12 (not yet scheduled). Captured ahead of implementation.
**Origin**: Surfaced while repairing the `.pnet` cache-hit registry-restore defect (GitHub issue #78, PM Track 10 post-PIR defect). Grounded by a 5-facet `grounding-audit` + adversarial completeness critic (`wf_d304af81-82b`) + main-session R-lens verification, HEAD `3f828bc9` (2026-07-27). Repair design: [`2026-07-27_PM_T10_PNET_REGISTRY_RESTORE_DEFECT_DESIGN.md`](2026-07-27_PM_T10_PNET_REGISTRY_RESTORE_DEFECT_DESIGN.md).
**Linked from**: PM Series Master [`2026-03-13_PROPAGATOR_MIGRATION_MASTER.md`](2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) § Track 12.
**Sibling notes**: [`2026-06-03_PM_TRACK12_SPEC_DEFN_NAME_ORDERING_NOTE.md`](2026-06-03_PM_TRACK12_SPEC_DEFN_NAME_ORDERING_NOTE.md) (name-level free-ordering) · [`2026-05-20_PM_TRACK13_IMPLEMENTATION_NOTE.md`](2026-05-20_PM_TRACK13_IMPLEMENTATION_NOTE.md) (mnr↔elab unification).

---

## §1 The consideration (one paragraph)

Registry state today has **two writers and one-and-a-half readers**. Every `register-X!` writes a Racket parameter *and* a cell; the 24 read functions consult the cell first and the parameter only as an `or` fallback. Because an empty `hasheq` is truthy in Racket, that fallback is **unreachable once the cells exist** — it is live only in the pre-init window. This is a classic cells-over-parameters half-migration (PM Track 7 moved registry *contents* to cells; the parameters were never retired), and it produced a **silent wrong-answer defect** (#78): one restore path wrote parameters only, and every reader silently saw nothing. The structural cure — make cells the single source of truth and delete the parameter fallback — is PM Track 12's stated direction. This note captures *why it could not be done in the #78 repair* and the *grounded pickup facts* so PM 12 can act on it cold.

## §2 Why the #78 repair could NOT take this path (4 blockers)

1. **The parameter fallback is genuinely load-bearing today, in a window that cannot yet be eliminated.** `macros-cell-read-safe` (`macros.rkt:531-536`) returns `#f` when the cell-id *or* the persistent-registry net-box is `#f` — the real state during module loading and before `init-macros-cells!` runs. Module loading happens **inside preparse** (`macros.rkt:2687`, `:2813`, both inside `preparse-expand-all` at `:2666`), and `process-file-inner` runs preparse at `driver.rkt:2647` but only calls `init-macros-cells!` afterwards at `:2664-2670`. So in a genuinely fresh process, the first file's entire module-load pass runs with cell-ids `#f` and the parameter *is* the registry. Retiring the fallback requires moving init ahead of preparse **and** giving `process-string` / `process-string-ws` the same initialization (they never init cells at all).

2. **The accidental healing is currently load-bearing — removing it WIDENS the defect.** `init-macros-cells!` has no once-guard (despite its own comment at `macros.rkt:577` claiming "Called ONCE") and **re-seeds** all 24 cells from the then-current parameters on *every* `process-file` (`macros.rkt:585-638`). That re-seed is exactly what masks the `process-file` shape of #78. A naive once-guard, or moving init earlier without the replacement invariant in place, would remove the healing and **widen** #78's blast radius before the cure lands. Any PM 12 ordering change must therefore land *with* the read-path change, not before it.

3. **There is a SECOND cell-primary reader family with no parameter fallback at all.** `read-persistent-registry-cell` (`resolution.rkt:408-413`) returns `(hasheq)` unconditionally when the cid is `#f` — it does not fall back to any parameter. Any statement of the read-path invariant, and any retirement plan, must cover **both** families (the 24 `(or (macros-cell-read-safe …) (current-X))` readers in `macros.rkt` and this one), not just the `macros.rkt` family.

4. **An adjacent latent defect blocks naive reordering.** Both pure resolution bridge factories capture registry cell-ids **eagerly at `driver.rkt` module-instantiation time** (`resolution.rkt:460-462`, `:552-555`; installed at `driver.rkt:3623-3624`, column 0), when those cell-ids are still `#f` — permanently, for the life of the process. Combined with blocker 3, the pure trait/hasmethod bridges read an **empty impl registry in every process**. Fixing the read path without fixing this capture would change which of the two wrong answers you get. Filed separately; it is a *prerequisite* for this slice, not a consequence.

## §3 The good news — the scoping semantics are already coherent

A retirement is not blocked by semantic confusion about what the two stores *mean*. Verified:

- `load-module` **parameterizes every registry parameter** (`driver.rkt:2912-2933`) but **not** the persistent-registry net-box. So the parameter is the **module-scoped** view (inherit-and-extend, popped on exit) and the cell is the **global accumulated** view (writes escape the parameterize).
- That split is not accidental and is currently *relied upon*: `serialize-module-state` reads the **parameters** (`pnet-serialize.rkt:606-623`), which is **correct** — a per-module `.pnet` must capture the module-scoped registry, not the globally accumulated one. Reading the cell there would serialize every other module's contributions into every module's cache file.

**Implication for PM 12 — this is the load-bearing design constraint**: "cells as single source of truth" cannot mean "delete the parameter and read the global cell everywhere." The parameter is doing **two** jobs: (a) a pre-init fallback (retire this — it is the bug class), and (b) **module-scoped accumulation** (this job is real and must survive, in some form). The structural answer to (b) is **submodule-scope** — already the PM 12 design input from PPN 4C Phase 1e-α (see the Master § Track 12: "Each module gets its own cell-space … scope resolution for registry reads walks the scope chain"). So this slice is **not** independent of the submodule-scope work: it is the same work seen from the read side. Retiring the fallback *without* submodule-scope would force a choice between losing module scoping and keeping the parameter.

## §4 What PM Track 12 should design (the pickup)

- **Order init before module loading**: `init-persistent-registry-network!` + `init-macros-cells!` must run *before* `preparse-expand-all` in `process-file-inner`, and `process-string` / `process-string-ws` must gain the same initialization. Land this **together with** the read-path change (§2.2), never before.
- **Give the cells the parameter's scoping job** via submodule-scope, so `load-module`'s parameterize can be dropped rather than silently losing module-scoped accumulation (§3).
- **Retire the `or (current-X)` fallback in all 24 readers** (`macros.rkt`) once the pre-init window is gone; unify with the `resolution.rkt` reader family so there is ONE read discipline (§2.3).
- **Fix the eager cell-id capture** in the resolution bridge factories first (§2.4) — defer the capture into the lambda, or read the cid at fire time.
- **Re-point serialization**: with submodule-scope, `serialize-module-state` reads the module's own scope rather than the parameter (§3).
- **Delete the `.pnet` restore dual-write** introduced by the #78 repair — it becomes a single cell write, and the `pipeline.md` checklist entry it needs can be deleted with it. *This is the concrete "when is the scaffolding retired" answer the #78 design owes.*

## §5 Bug-class evidence this slice would eliminate

The half-migration has now produced defects **in both directions**, which is the strongest argument for finishing it:

| Direction | Defect | Where |
|---|---|---|
| Write to parameter, read from cell | `.pnet` cache-hit restore — silent stuck terms, silent wrong answers, durable cache poisoning | GitHub #78 / `driver.rkt:2812-2883` |
| Read from cell whose id was captured while `#f` | Pure trait/hasmethod bridges read an empty impl registry in every process | `resolution.rkt:460-462`, `:552-555` |

Both are **silent**. Neither is caught by the suite. The invariant "there is exactly one place registry state lives" would make both unrepresentable.

## §6 Cross-references

- **The #78 repair design** (what was fixed, and the explicit Option-C deferral): [`2026-07-27_PM_T10_PNET_REGISTRY_RESTORE_DEFECT_DESIGN.md`](2026-07-27_PM_T10_PNET_REGISTRY_RESTORE_DEFECT_DESIGN.md) §3.1, §5.1.
- **PM Track 12 § submodule-scope** (the scoping mechanism §3 depends on): PM Master § Track 12 "Design input from PPN 4C Phase 1e-α"; PPN 4C [`2026-04-17_PPN_TRACK4C_DESIGN.md`](2026-04-17_PPN_TRACK4C_DESIGN.md) §6.14.2.
- **The 32 pre-identified migration-candidate sites** (23 `macros.rkt` registry sites among them): PM Master § Track 12.
- **`merge-hasheq-replace` → `merge-hasheq-identity`** substitution, unlocked by submodule-scope: PM Master § Track 12.
- **A3 parameter-leakage lint** — the tactical safety net this slice obsoletes: `.claude/rules/testing.md` § Parameter-leakage lint.
