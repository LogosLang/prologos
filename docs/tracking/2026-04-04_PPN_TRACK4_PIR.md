# PPN Track 4: Elaboration as Attribute Evaluation — Post-Implementation Review

**Date**: 2026-04-05
**Duration**: ~3 sessions across 2 working days
**Commits**: 69 (from D.1 design `e66286ce` through `2aa3846b`)
**Test delta**: 7551 → 7574 (23 Track 4 tests added, some pre-existing removed)
**Code delta**: typing-propagators.rkt ~900 lines, propagator.rkt +60 lines, surface-rewrite.rkt +25 lines
**Suite health**: 7574 tests, 387 files, ~145s, 15 pre-existing failures (not Track 4)
**Design docs**: [D.4 Design](2026-04-04_PPN_TRACK4_DESIGN.md), [Stage 2 Audit](2026-04-04_PPN_TRACK4_STAGE2_AUDIT.md)

---

## §1. What Was Built

PPN Track 4 delivers propagator-native type inference infrastructure for the Prologos compiler. Typing propagators are installed via `net-add-propagator` on ephemeral Pocket Universe networks. They read and write type-map positions via `net-cell-read`/`net-cell-write`. Information flows through cells to quiescence — the typed result is READ from a cell, not RETURNED by a function.

The architecture: each `eval`/`infer` command creates a fresh prop-network (the typing PU), installs typing propagators for the expression's sub-structure, runs to quiescence, and reads the root type. The ephemeral network is GC'd after use.

46% of eval/infer commands are typed entirely on-network. The remaining 54% fall back to the imperative `infer` path because they require side effects (trait resolution, constraint creation, multiplicity checking) that are not yet on-network.

~150 expression kinds are registered in the SRE Typing Domain — a data registry mapping expression predicates to arity patterns and return types. The domain is the self-hosting compilation target.

---

## §2. Timeline and Phases

| Phase | Commit | What | Status |
|-------|--------|------|--------|
| D.1-D.3 | `e66286ce`→`7f0dbab7` | Design: 3 critique rounds (self, external, propagator mindspace) | ✅ |
| 0 | `81cf3a72` | Acceptance file + DEFERRED triage | ✅ |
| 1a | `6d5f1adb` | Component-indexed propagator firing | ✅ |
| 1b | `bffe3c90` | Type-map in form-pipeline-value | ✅ |
| 1c | `2f50c6c4` | Context lattice (typing-propagators.rkt) | ✅ |
| 2a-2e | `bca522f5`→`71bd2bca` | ~~21 typing rules as function-call data~~ | ❌ DIVERGED |
| 3 | `f7c86536` | ~~make-typing-rule-infer (delegation wrapper)~~ | ❌ DIVERGED |
| D.4 | `addbb9e7`→`ba58bd9e` | DIVERGENCE ANALYSIS + correction design | ✅ |
| 2 REDO | `9aabacdc` | Propagator fire functions + install-typing-network | ✅ |
| 3 REDO | `c3f9db39` | infer-on-network (cell → quiescence → read) | ✅ |
| 7 REDO | `f1354276` | infer-on-network/err wired into process-command | ✅ |
| P5 | `fb1a69b0` | Context threading as cell positions | ✅ |
| P1 | `297faf33` | Bidirectional app propagator + dependent guard | ✅ |
| P2 | `21bcbd58` | Ephemeral PU typing + expression-key substitution | ✅ |
| §16 | `820cb5eb`→`aaba0fbe` | SRE Typing Domain: ~150 expr kinds registered | ✅ |
| F2 | `01cbdec5` | Generic arithmetic computed return types | ❌ REVERTED (coercion) |
| F1 | (reverted) | Meta resolution from type-map | ❌ REVERTED (side effects) |
| NRC | `0175c986` | Network Reality Check codified in workflow.md | ✅ |

Design-to-implementation ratio: ~40% design/critique, ~60% implementation. The D.1→D.3 design phase was thorough (3 critique rounds). The D.4 divergence analysis added ~10% rework.

---

## §3. Test Coverage

- **test-ppn-track4.rkt**: 23 tests across Phase 1a (component-indexed firing), Phase 1c (context lattice), Phase 2 (network typing — literal, universe, app, bvar, lambda), Phase 4b-i (meta-readiness), Phase 6 (constraint lattice)
- **Acceptance file**: `2026-04-04-ppn-track4.prologos` — 8 sections, Level 3 clean
- **On-network counters**: `on-network-success-count` / `on-network-fallback-count` for diagnostic
- **Coverage tracking**: `unhandled-expr-counts` hash identifies unhandled expression kinds
- **Gap**: no tests for the SRE typing domain registration itself. The domain entries are exercised through integration tests but not unit-tested for correctness of return types.

---

## §4. Bugs Found and Fixed

1. **Component-paths first-match bug** (Phase 1a): `net-add-propagator` with multiple `#:component-paths` entries for the same cell-id — `assoc` finds only the first. Multi-position propagators watch the entire cell as workaround. Tracked for fix.

2. **Stale cell-id across commands** (Phase 4b-ii-a): `meta-solution/cell-id` crashed with "unknown cell" when a meta's cell-id referenced a previous command's network. Fixed with guarded read + CHAMP fallback.

3. **Double-processing in delegation** (old Phase 6): app rule called `reader(func)` before delegating to `infer-fallback`, causing double-solve of multiplicity metas. Fixed by wrapping with `delegating-infer`. Later REMOVED entirely when delegation was identified as imperative scaffolding.

4. **Network accumulation timeout** (Pattern 2): typing propagators added to the main elab-network persisted across commands, causing 3-timeout regression. Fixed with ephemeral typing networks.

5. **Type-vs-value confusion** (Pattern 1): the Nat type constructor's propagator wrote `Type(0)` (type-of-Nat) to arg positions, but dependent substitution needed `Nat` (the value). Fixed with `codomain-is-dependent?` guard, later replaced by expression-key substitution.

6. **Mixed-map regression** (F3): computed `map-value-type` returned union types directly instead of distributing over union components. Reverted to `#f`.

---

## §5. Design Decisions and Rationale

1. **Ephemeral PU typing networks** (§15): each eval/infer creates a fresh prop-network, discarded after quiescence. Prevents network accumulation. GC-efficient. The typing PU IS the computation — create, run, read, discard.

2. **Expression keys for substitution** (Pattern 2): `subst(0, arg-pos, cod)` uses the expression key (the value), not the type-map value (the type). Clean separation: type-map for validation (merge), expression keys for computation (substitution).

3. **SRE Typing Domain** (§16): expression-kind → type mapping as registry data. One-line registration per expr kind. `install-from-rule` dispatches on arity pattern. Self-hosting path: the domain IS compilation data.

4. **Network Reality Check** (workflow.md): binary check for propagator tracks — `net-add-propagator` calls, `net-cell-write` produces result, cell→propagator→cell trace. Prevents the imperative-as-propagator drift that caused the D.3→D.4 divergence.

5. **Bidirectional app writes** (Pattern 1): app propagator writes domain DOWNWARD to arg position (check direction) and subst result UPWARD (infer direction). The merge at the arg position IS unification via type-lattice-merge.

---

## §6. Lessons Learned

1. **The delegation pattern is a no-op.** Wrapping imperative `infer` in a registry lookup + fallback adds indirection without moving computation on-network. The Network Reality Check catches this: zero `net-add-propagator` calls = imperative, regardless of data structures.

2. **Velocity over correctness is invisible.** The imperative phases (2a-2e, 3, 6) produced commits, passed tests, updated trackers. The process FELT productive. But it built the wrong abstraction — function-call wrappers instead of propagator fire functions. Each commit was a step away from the design, not toward it.

3. **Side effects are the real boundary.** The imperative `infer` doesn't just compute types — it creates constraints, solves metas, resolves traits, checks multiplicities, and emits warnings. Moving the TYPE COMPUTATION on-network (46%) is straightforward. Moving the SIDE EFFECTS on-network is the remaining 54% and requires full Pattern 4 scope.

4. **Ephemeral networks solve accumulation.** Typing propagators on the main elab-network cause unbounded growth across commands. Fresh prop-network per call eliminates this. The PU model (create, run, read, discard) is the right architecture.

5. **The correct architecture is simpler.** The D.4 REDO replaced 1,402 lines of imperative scaffolding with 396 lines of propagator-native code (3.5× reduction). The imperative version had double-solve bugs, delegation complexity, and effects callbacks. The propagator version has none of these.

6. **Parity-with-imperative is the wrong validation criterion.** Tests that prove "rules produce same types as imperative" validate correctness but NOT architecture. The criterion should be: does the result come from reading a cell after propagator quiescence?

---

## §7. Metrics

| Metric | Value |
|--------|-------|
| Total commits | 69 |
| Lines: typing-propagators.rkt | ~900 |
| Lines: propagator.rkt additions | ~60 |
| Lines removed (imperative scaffolding) | ~1,400 |
| Track 4 tests | 23 |
| Expr kinds registered in SRE domain | ~150 |
| On-network rate (acceptance file) | 46% |
| On-network rate (simple programs) | 100% |
| Regressions from Track 4 | 0 |
| Pre-existing failures | 15 |
| Design iterations | D.1 → D.2 → D.3 → D.4 |
| Divergence recovery cost | ~30% of implementation time |

---

## §8. What's Next

**Immediate (PPN Track 4B continuation)**:
- Full Pattern 4: constraint propagators + instance registry bridge. Trait resolution, constraint creation, multiplicity checking, warning emission as on-network operations.
- This is the side-effect boundary identified in §17. All three frontiers (F1 meta, F2 trait, F3 structural) are blocked by this.

**Medium-term**:
- Phase 4b zonk retirement: blocked on full on-network typing (no expr-meta in results)
- Phase 8 scaffolding retirement: blocked on above
- Component-paths multi-path-per-cell-id fix in propagator.rkt

**Long-term**:
- Self-hosted compiler: the SRE typing domain IS the compilation target
- Grammar Form `:type` compilation: uses the typing propagator infrastructure

---

## §9. Key Files

| File | Role |
|------|------|
| `racket/prologos/typing-propagators.rkt` | Typing propagator fire functions, context lattice, SRE typing domain, infer-on-network |
| `racket/prologos/propagator.rkt` | Component-indexed firing (pu-value-diff, filter-dependents-by-paths) |
| `racket/prologos/surface-rewrite.rkt` | Type-map field in form-pipeline-value |
| `racket/prologos/typing-errors.rkt` | infer/err (fallback entry point) |
| `racket/prologos/driver.rkt` | infer-on-network/err wiring in process-command |
| `racket/prologos/tests/test-ppn-track4.rkt` | 23 propagator-native tests |
| `racket/prologos/examples/2026-04-04-ppn-track4.prologos` | Acceptance file (L3) |
| `.claude/rules/workflow.md` | Network Reality Check rule |

---

## §10. Lessons Distilled

| Lesson | Distilled To | Status |
|--------|-------------|--------|
| Network Reality Check (3 binary questions) | workflow.md | Done (commit `0175c986`) |
| Delegation pattern = imperative-in-disguise | DEVELOPMENT_LESSONS.org | Pending |
| Velocity over correctness is invisible | DEVELOPMENT_LESSONS.org | Pending |
| Ephemeral PU = create, run, read, discard | PATTERNS_AND_CONVENTIONS.org | Pending |
| Side effects are the real boundary to on-network | DESIGN_PRINCIPLES.org | Pending |
| 3.5× code reduction for correct architecture | DEVELOPMENT_LESSONS.org | Pending |

---

## §11. What Went Well

1. **Three critique rounds produced a sound design.** D.1→D.3 identified the context lattice gap, the bidirectional ring structure, and the PU-internal invariant — all of which proved essential during implementation.

2. **The divergence was caught and corrected.** The D.4 analysis identified the imperative drift, codified the Network Reality Check, and the REDO produced the correct architecture in 3.5× less code.

3. **The ephemeral PU architecture.** Discovered during Pattern 2 debugging, it elegantly solved the network accumulation problem AND provided GC-efficient typing.

4. **The SRE typing domain.** Data-oriented registration of ~150 expr kinds in a self-hosting-ready format. One-line registration. Extensible by library authors.

---

## §12. What Went Wrong

1. **The imperative divergence (Phases 2-3, 6).** Three phases built function-call wrappers instead of propagator fire functions. The Vision Alignment Gate was too subjective to catch it. Cost: ~30% rework.

2. **F2 and F1 regressions.** Both attempts to increase on-network rate caused regressions by bypassing imperative side effects. The side-effect boundary wasn't understood until these failures.

3. **Coercion warning coupling.** Generic arithmetic typing is coupled to coercion detection — the type computation and the warning emission are intertwined in the imperative path. Separating them requires full Pattern 4.

---

## §13. Where We Got Lucky

1. **The 15 pre-existing failures.** Verified that ALL 15 failures exist with or without Track 4 changes. If any had been Track 4 regressions, the investigation would have been much harder.

2. **The narrow app-propagator test.** When the 3-timeout regression appeared, the narrow test proved the app propagator doesn't loop in isolation. This correctly redirected investigation to network accumulation.

---

## §14. What Surprised Us

1. **The elaborator produces ~294 specialized expr structs.** `(int+ 3 4)` becomes `(expr-int-add 3 4)`, NOT `(expr-app (expr-fvar 'int+) 3 4)`. The on-network typing needed to handle ALL these kinds, not just the ~15 core structural kinds.

2. **Implicit argument handling is ELABORATION, not typing.** By the time the type checker sees the expression, implicit args are already inserted as `expr-meta` nodes. The "implicit arg problem" was actually a dependent-codomain problem.

3. **The side-effect boundary.** The imperative `infer` is not just a type computation — it's a type computation WITH side effects. Moving just the TYPE part on-network gets 46%. The remaining 54% requires moving ALL side effects.

---

## §15. What Assumptions Were Wrong

1. **"Typing rules as DPO rewrite rules."** The design framed typing rules as sre-rewrite-rule data. The implementation revealed typing rules are fundamentally different from parse rewrite rules — they operate on a different domain (expr→type, not tree→tree), use substitution (not template instantiation), and require bidirectional flow.

2. **"Unification is cell merge."** Partially true — type-lattice-merge handles simple cases. But structural unification (Pi decomposition, applied metas) requires more than merge. The merge IS unification for the cases it covers, but there are cases it doesn't.

3. **"The delegation pattern is incremental migration."** It was framed as temporary scaffolding. In practice, it became permanent architecture that had to be torn out.

---

## §16. Longitudinal Survey

| Track | Date | Duration | Test Δ | Commits | Wrong Assumptions | Bugs | Design Iterations |
|-------|------|----------|--------|---------|-------------------|------|-------------------|
| Track 3 (Cells) | 2026-03-16 | 2 sessions | +52 | 18 | 1 | 3 | D.1-D.2 |
| Track 5 (Global Env) | 2026-03-16 | 1 session | +28 | 12 | 0 | 2 | D.1 |
| Track 8 (Elab Network) | 2026-03-22 | 3 sessions | +89 | 35 | 2 | 5 | D.1-D.3 |
| PUnify Parts 1-2 | 2026-03-19 | 2 sessions | +45 | 22 | 1 | 4 | D.1-D.2 |
| PM Track 10 | 2026-03-24 | 2 sessions | +67 | 28 | 3 | 6 | D.1-D.3 |
| PPN Track 2 | 2026-03-29 | 2 sessions | +42 | 20 | 1 | 3 | D.1-D.2 |
| SRE Track 2H | 2026-04-03 | 1 session | +35 | 15 | 1 | 2 | D.1-D.5 |
| SRE Track 2D | 2026-04-03 | 1 session | +25 | 14 | 1 | 2 | D.1-D.5 |
| **PPN Track 4** | **2026-04-04** | **3 sessions** | **+23** | **69** | **3** | **6** | **D.1-D.4** |

**Patterns spanning 3+ PIRs**:
- **Design iteration count correlates with implementation quality.** Tracks with D.3+ iterations (Track 8, PM 10, Track 4) have more bugs but produce more architecturally sound results. The iteration catches design gaps before they become implementation bugs.
- **Divergence between design and implementation.** Track 4 is the most severe case (D.4 correction needed), but PM Track 10 and PPN Track 2 also had implementation pivots. The Network Reality Check was codified to prevent recurrence.
- **Side-effect coupling is the recurring blocker.** Track 8 (elaboration network), PM Track 10 (PUnify parity), and Track 4 (typing on-network) all hit the same boundary: imperative side effects coupled to type computation. This is an ARCHITECTURAL pattern demanding systemic response — the PPN Track 4B continuation.
