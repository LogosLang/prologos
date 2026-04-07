# PPN Track 4B: Elaboration as Attribute Evaluation — Post-Implementation Review

**Date**: 2026-04-07
**Duration**: ~3 sessions across 3 working days (Apr 5-7)
**Commits**: 47 (from `246e4fb3` Phase 0a through `f4be1b38` Phase T)
**Test delta**: 7578 → 7609 (+31 tests in 4 new files, +27 in existing test-ppn-track4.rkt)
**Code delta**: 2117 insertions, 281 deletions across 13 .rkt files
**Suite health**: 391/391 files, 7609 tests, 134.1s, all pass
**Design docs**: [Track 4B Design (D.2)](2026-04-05_PPN_TRACK4B_DESIGN.md), [Track 4 PIR (predecessor)](2026-04-04_PPN_TRACK4_PIR.md), [Attribute Grammar Research](../research/2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md), [Track 4C Design Note](../research/2026-04-07_PPN_TRACK4C_DESIGN_NOTE.md)
**Prior PIRs**: [PPN Track 4](2026-04-04_PPN_TRACK4_PIR.md), [SRE Track 2D](2026-04-03_SRE_TRACK2D_PIR.md), [SRE Track 2H](2026-04-03_SRE_TRACK2H_PIR.md)
**Series**: PPN (Propagator-Parsing-Network) — Track 4B

---

## §1. What Was Built

Track 4B completes the attribute evaluation architecture for propagator-native type inference. Where Track 4 (predecessor) built typing propagators on ephemeral Pocket Universe networks achieving 46% on-network coverage, Track 4B extends to all 5 attribute domains, runs on the main elaboration network, and achieves ~90% on-network coverage as the PRIMARY typing path.

The architecture: a single attribute-map cell holds a nested hasheq (position → facet → value) for 5 facets — :type, :context, :constraints, :usage, :warnings. Propagators at three strata (S0 monotone, S1 readiness-triggered, S2 commitment) install themselves for each sub-expression and fire to quiescence. The typed, constrained, usage-tracked, warning-collected result EMERGES from cell reads after quiescence.

Key deliverables:
1. **Attribute Record PU** (Phase 1): 5-facet nested hasheq with `that-read`/`that-write` API, facet-aware merge, compound component-paths for targeted propagator firing
2. **Constraint attribute propagators** (Phase 2): Reuse of existing constraint-cell.rkt powerset lattice (Heyting algebra). Cross-facet :type→:constraints bridge.
3. **Meta-feedback + trait resolution** (Phase 3): Simple meta-feedback (domain IS meta → write arg type), structural meta-feedback (compound types → parallel-walk), Option C (skip downward write for meta positions)
4. **Usage tracking propagators** (Phase 4): 7 usage fire-fn kinds (zero, single, bvar, app binary, lam/pi structural, SRE arity-keyed generic)
5. **On-main-network typing** (Phase 6): Eliminated ephemeral PU. Typing runs on the main elaboration network. P1 initial writes, P3 per-command cleanup.
6. **Warning propagators** (Phase 7): S2 usage-validation + warning-collection. Warning output cell. All 5 attribute domains active.
7. **SRE expression coverage** (Phase 9): Custom fire functions for ann, tycon, reduce, pair, from-int/from-rat. Generic arithmetic via `numeric-join`. Coercion detection. Contradiction propagation.
8. **Dedicated test files** (Phase T): 31 tests across 4 files covering attribute records, propagator patterns, SRE coverage, meta-feedback.

## §2. Timeline and Phases

| Phase | Description | Commit | Notes |
|-------|-------------|--------|-------|
| 0a+0d | Multi-path component firing + BSP hardening | `246e4fb3` | Fixed `assoc` first-match → list-based multi-path |
| 0b | Constraint domain lattice design | — | CLP-inspired. Powerset lattice. Heyting algebra. Design only. |
| 0 | Stage 2 audit + attribute grammar specification | — | AG research, 5 domains, 12 node kinds, stratification |
| 1 | Attribute Record PU | `90e4979e` | Nested 5-facet structure. that-read/that-write API. |
| 2 | Constraint attribute propagators (S0) | `b900f04f` | Reuses constraint-cell.rkt. Cross-facet bridge. |
| 3 | Trait resolution + meta-feedback (S1) | `74f79506` | Option C, structural feedback, output bridge. 17→0 failures. |
| 4 | Usage tracking propagators (S0+S2) | `603663c6` | 7 fire-fn kinds. SRE arity-keyed generic. |
| 5 | Structural decomposition verification | `87a04bba` | Single-cell PU subsumes separate cells. APP bidirectional writes = unification. |
| 6 | On-main-network + meta-bridge output cell | `a8b597de` | Eliminated ephemeral PU. 20% time increase. |
| 6b | P1 initial writes + P3 cleanup | `6df6e7cc` | Recovered performance: 142.5s (from 164.8s). |
| 0c | Global attribute-map cell on persistent network | `b5ccd5dc` | §9 design: persistent cell survives across commands. |
| P2 | Fire-once self-cleaning propagators | `86d1bf30` | ~1.4% overhead. net-remove-propagator-from-dependents. |
| 7 | Warning attribute propagators (S2) | `cc4bad36` | All 5 domains active. Warning output cell. |
| 8 | ATMS integration (blocked) | — | ⏸️ Blocked on BSP-LE Track 1.5 (Cell-Based TMS) |
| 9 | SRE expression coverage + on-network primary | `9358b18d`→`6f112854` | 12 sub-commits. ann, tycon, reduce, pair, generics, contradiction. |
| 10 | Zonk measurement | `933a3aff` | freeze makes 1-21 substitutions/call. Not yet retirable. |
| T | Dedicated test files | `f4be1b38` | 31 tests in 4 files. Fixed generic op on-network typing. |

Design-to-implementation ratio: ~40% design / 60% implementation (AG research + D.2 design doc substantial).

## §3. Test Coverage

**New test files (Phase T)**:
| File | Tests | Coverage |
|------|-------|----------|
| test-attribute-record.rkt | 10 | facet-bot, facet-merge, that-read/that-write, nested records, constraint intersection |
| test-propagator-patterns.rkt | 5 | P1 initial write, P2 fire-once (fires + no-op guard), P3 net-clear-dependents |
| test-sre-coverage.rkt | 9 | ann, tycon, pair, generic-add (same + cross family), generic-lt, generic-negate, reduce, contradiction |
| test-meta-feedback.rkt | 7 | Simple meta-feedback, Option C, type-family, coercion-detection (cross + same family) |

**Existing file updates**: test-ppn-track4.rkt grew from 23 to 27 tests during earlier phases.

**Gaps**: Phase 4 usage tracking has minimal dedicated testing (tested indirectly through full-suite integration). Phase 8 (ATMS) blocked.

**Acceptance file**: Runs via `process-file` at Level 3. Track 4B expressions exercise all expression kinds through the on-network path.

## §4. Bugs Found and Fixed

1. **Multi-path assoc first-match bug** (Phase 0a): `net-add-propagator` used `assoc` which finds only the first matching cell-id in component-paths. Nested attribute-map structures produce multiple paths for the same cell-id. Fixed by collecting ALL matching paths into a list. Root cause: the original code assumed one path per cell-id — violated by the nested attribute structure.

2. **Context bot conflation** (Phase 3): `context-empty-value` was used as both the facet-bot AND a valid context. Context-extension propagator fired on empty context (interpreting bot as "ready"). Fixed by changing facet-bot for :context to `#f`, distinguishing "not yet written" from "valid empty context." This is a classical lattice design error: ⊥ must be distinguishable from every legitimate value.

3. **Kind vs solution conflict — Option C** (Phase 3): APP downward write put `Type(0)` (the domain's kind) at a meta position, conflicting with the meta's solution (e.g., `Nat`). The type lattice merge of `Type(0)` and `Nat` → `type-top` (contradiction). Fixed by skipping the downward write when the argument position is a meta. This is the correct approach because meta positions receive their type through feedback, not through domain propagation.

4. **Global cell 178 failures** (Phase 0c): `reset-meta-store!` creates a fresh elab-network each command, resetting cell-id counters. The persistent registry network (which survives across commands) kept old cell references. Fixed by creating the attribute-map cell on the persistent network, not the per-command network.

5. **Fire-once + context-extension interaction** (P2): Flag-guard set `fired?=true` prematurely because context-extension propagator fired on `context-empty-value` (bot was indistinguishable from valid empty context). This was the same root cause as bug #2 — the context-bot fix resolved both.

6. **Generic ops returning type-bot** (Phase T): Generic arithmetic/comparison/unary ops were registered with `#f` return type, causing `install-from-rule` to skip them entirely — no children installed, no propagator. Fixed by: (a) extending `install-from-rule` to pass ALL child types to computed return-type functions, (b) registering binary arithmetic with `numeric-join`, comparisons with `Bool`, unary with identity.

7. **Contradiction not propagating** (Phase 9): APP with arg `type-top` didn't propagate to result type. Result stayed at `type-bot` despite argument contradiction. Fixed by checking arg-after-merge for `type-top` in the APP propagator.

8. **Ann shape check missing** (Phase 9): `(the Nat (fn [x] x))` — annotating a lambda with a non-Pi type. Lambda's domain was at `type-bot` (never written), so lambda propagator never fired. Fixed by detecting non-Pi annotation on lambda → immediate `type-top`.

9. **Batch-worker isolation** (Phase 3): 12 constraint cell-id parameters missing from batch-worker's parameterize block. Added all 12 + `current-attribute-map-cell-id`.

## §5. Design Decisions and Rationale

1. **Single attribute-map cell** (vs separate cells per position): All 5 facets for all positions in ONE cell. Principle: Decomplection — fewer cells, simpler topology, one merge function. Enables compound component-paths for precise propagator targeting.

2. **Three-stratum BSP** (S0/S1/S2): S0 monotone (typing, constraints, usage), S1 readiness-triggered (trait resolution), S2 commitment (defaulting, validation, warnings). Principle: Correct-by-Construction — stratification prevents non-monotone operations from racing with monotone convergence.

3. **On-main-network** (not ephemeral PU): Initially used ephemeral PU per command. Phase 6 moved to main network. Principle: Propagator-First — typing information on the same network as all other elaboration data enables cross-concern propagators without bridging.

4. **Option C for meta positions**: Skip downward domain write when arg is a meta. Principle: Correct-by-Construction — prevents kind/solution conflict structurally rather than through runtime checks.

5. **P1/P2/P3 propagator patterns**: P1 (initial writes for constants), P2 (fire-once with flag guard), P3 (per-command cleanup). Principle: Data Orientation — topology management as data (flags, cleanup operations), not imperative control flow.

6. **numeric-join for generic ops** (not trait dispatch): Return type computed purely from operand types. Principle: Completeness — handles cross-family arithmetic correctly (Int + Posit32 → Posit32) without trait infrastructure.

## §6. What Went Well

1. **Attribute grammar framing proved architecturally clean.** The 5-facet structure with stratified evaluation maps directly onto the AG literature. The implementation matched the formal model with minimal impedance mismatch.

2. **Single-cell PU eliminated 80% of expected infrastructure.** Track 4B Phase 5 discovered that the single attribute-map cell with bidirectional APP writes already provides "structural unification" — no separate decomposition cells needed. The compound component-path mechanism makes this efficient.

3. **17 pre-existing failures → 0 through systematic Phase 3 diagnosis.** Rather than working around these failures, meta-feedback + Option C + structural feedback resolved ALL of them. The root cause (imperative trait resolution fires before type metas solved) was a single architectural issue with a single fix.

4. **Performance recovery after on-main-network move.** Phase 6 caused 20% regression (164.8s). P1 + P3 + global cell fully recovered (131-133s, actually BELOW baseline). The three propagator patterns are generally applicable optimizations.

5. **Design critique caught the fire-once flag-guard pattern** before it became a production issue. The P2 self-cleaning propagator was designed, benchmarked (~1.4% overhead), and validated as worthwhile.

## §7. What Went Wrong

1. **Phase 9 required 12 sub-commits** due to inadequate SRE coverage analysis. The first attempt (`42bb7d07`: "NOT READY") revealed the gap — generic ops, pairs, reduce, ann, tycon were all unhandled. Should have done a comprehensive expression vocabulary audit BEFORE Phase 9.

2. **Generic ops registered with `#f` as a deferral** that was never resolved until Phase T testing. The comment "stay at #f until return-type computation accounts for coercion" was a rationalization — `numeric-join` was the correct approach from the start. 4 of the test failures were caused by this gap.

3. **`install-from-rule` only passed first child type** to computed return-type functions. Binary ops need all children. This single-argument convention was designed when only unary computed types existed — it wasn't forward-looking enough.

4. **Phase 8 (ATMS) blocked by off-network TMS.** The discovery that cell-based TMS is needed was correct but late. This should have been flagged during the D.2 design phase, not discovered at implementation time.

## §8. Where We Got Lucky

1. **Context-bot fix resolved TWO bugs simultaneously** (context-extension false-firing AND P2 premature flag-set). If these had manifested as separate issues, diagnosis would have been much harder. The single root cause was identified because both symptoms appeared in the same test.

2. **Existing constraint-cell.rkt lattice was directly reusable.** Phase 2 constraint propagators reused the entire powerset lattice infrastructure without modification. If the lattice had been coupled to the imperative resolution loop, Phase 2 would have required significant refactoring.

3. **`numeric-join` already existed in typing-core.rkt** and was directly importable without circular dependencies. If it had been entangled with the imperative `infer` pipeline, extracting it would have been a multi-file refactor.

## §9. What Surprised Us

1. **Phase 5 was a verification phase, not implementation.** Expected to build structural decomposition cells; discovered the single-cell PU model already handles it through bidirectional APP writes. The attribute-map merge function + compound component-paths = structural unification.

2. **The persistent registry network was the right host** for the global attribute-map cell, not the per-command elab-network. The elab-network is recreated each command; the registry network persists. CHAMP structural sharing makes this efficient.

3. **Generic ops needed a fundamentally different return-type convention.** The `install-from-rule` procedure path was designed for unary computed types (first-child → result). Binary `numeric-join` required passing ALL child types, which is a better general convention anyway.

## §10. How Did the Architecture Hold Up?

The propagator network + BSP scheduler + cell infrastructure held up well. Extension points:
- **net-add-propagator**: used as intended for all new propagators
- **compound component-paths**: enabled precise facet-targeting (new capability from Phase 0a)
- **net-clear-dependents**: new primitive (P3) that was simple to implement and immediately useful
- **net-remove-propagator-from-dependents**: new primitive (P2) for fire-once cleanup

**Friction points**:
- The `solve-meta!` bridge remains imperative. Cell-level solutions are invisible to the resolution loop until bridged. This is the principal remaining architectural impurity.
- Fire-once propagators are a common pattern but require manual flag management. A built-in `net-add-fire-once-propagator` wrapper was needed.
- The 6 imperative bridges documented in [Track 4C design note](../research/2026-04-07_PPN_TRACK4C_DESIGN_NOTE.md) are the boundary of what's achievable without deeper architectural changes.

## §11. What Does This Enable?

1. **Track 4C**: Dissolve the 6 remaining imperative bridges (solve-meta!, resolve-trait-constraints!, unsolved-dict, freeze, checkQ, emit-coercion-warning!)
2. **BSP-LE Track 1.5**: Cell-based TMS enables Phase 8 (ATMS union branching)
3. **Cross-concern propagators**: With all 5 facets on the same network, propagators that bridge concerns (e.g., :constraints → :warnings) are natural
4. **Per-command profiling**: The propagator infrastructure supports counting firings, cell writes, etc. — already used in micro-benchmarks
5. **Future: incremental re-checking**: If a module is edited, only affected attribute positions need re-evaluation (CHAMP diff)

## §12. Technical Debt Accepted

1. **6 imperative bridges** (documented in Track 4C design note): solve-meta!, resolve-trait-constraints!, freeze-substitution, checkQ, emit-coercion-warning!, unsolved-dict fallback. Each has a root cause and resolution path.
2. **Phase 8 blocked**: Union type checking via ATMS requires cell-based TMS (BSP-LE Track 1.5).
3. **Phase 10 deferred**: Zonk still makes 1-21 substitutions per call. Not retirable until cell-refs replace expr-meta.
4. **Phase 11 deferred**: Scaffolding from Tracks 2H + 2D not yet retired.
5. **Usage tracking minimally tested**: Phase 4 usage propagators tested only through integration.

## §13. What Would We Do Differently?

1. **Comprehensive expression vocabulary audit before Phase 9.** The first Phase 9 attempt failed because generic ops, pairs, reduce, and several other expression kinds weren't handled. A complete enumeration of expression kinds vs. handled kinds should precede any "coverage expansion" phase.

2. **Register generic ops with proper computed types from the start** instead of `#f`. The comment about "waiting for coercion rules" was unnecessary — `numeric-join` handles coercion correctly.

3. **Flag Phase 8 (ATMS) blocking dependency during D.2 design**, not during implementation. The design should have explicitly stated "ATMS requires cell-based TMS which doesn't exist."

4. **Build test files during implementation** (not as a follow-up Phase T). Three consecutive tracks (PPN 3, SRE 2H, SRE 2D) had the same pattern — Phase T adds tests that catch bugs the implementation missed. The solution is codified in the workflow rules but still not practiced consistently.

## §14. Wrong Assumptions

1. **"Context-empty-value can be the context facet bot."** Wrong — ⊥ must be distinguishable from every legitimate value. `context-empty-value` IS a legitimate context (empty binding list), not "no context yet."

2. **"Generic ops need #f because coercion is complex."** Wrong — `numeric-join` handles the complexity correctly and was already implemented.

3. **"`install-from-rule` only needs first-child type."** Wrong — binary computed return types need all children. The single-argument convention was a premature optimization of the API.

4. **"Ephemeral PU is the right hosting model."** Wrong for this use case — typing on the main network enables cross-concern propagators and persistent attribute accumulation. Ephemeral PU was appropriate for Track 4's isolated experiment but not for production integration.

## §15. What Did We Learn About the Problem?

1. **Attribute evaluation IS type inference.** The AG framing isn't a metaphor — it's a literal description. The 5-facet structure maps directly to the 5 concerns a type system must track. The stratification maps to the dependency ordering of those concerns.

2. **The boundary between on-network and off-network is the `solve-meta!` bridge.** Everything else can be propagator-native. The meta-store CHAMP is the last imperative bastion, and it exists because the resolution loop (trait dispatch, constraint retry) was designed before the propagator network.

3. **Fire-once is a pervasive pattern** in typing propagators. Constants, context extension, usage zero writes, constraint creation — all fire once and should never re-fire. The P2 pattern with flag guard is the right abstraction but needs language-level support (not manual flag management).

4. **Performance is recoverable.** Moving to the main network caused 20% regression; three propagator patterns (P1/P2/P3) fully recovered it. This suggests that propagator-native approaches can be competitive with imperative code if the right patterns are applied.

## §16. Are We Solving the Right Problem?

Yes. Track 4B advances the core vision: all computation as attribute evaluation on the propagator network. The 90% on-network achievement validates the architecture. The remaining 10% (ATMS, auto-implicits, narrowing) are genuine gaps that require specific infrastructure (cell-based TMS, kind-facet separation) — not architectural problems.

The Track 4C design note identifies 6 bridges with clear dissolution paths. None require rethinking the approach — they require building missing infrastructure.

## §17. Longitudinal Survey (10 Most Recent PIRs)

| Track | Date | Duration | Test Δ | Commits | Wrong Assumptions | Bugs | Design Iterations |
|-------|------|----------|--------|---------|-------------------|------|-------------------|
| PPN Track 4 | Apr 4 | ~3 sessions | +23 | 69 | Ephemeral PU sufficient; side effects = separate concern | 15 pre-existing | D.1→D.4 (4) |
| SRE Track 2D | Apr 3 | ~11h | +25 | 18 | Rewrite = relation (actually span) | 0 | D.1→D.5 (5) |
| SRE Track 2H | Apr 3 | ~14h | +35 | 30 | Type lattice is Heyting (it's not under equality merge) | 0 | D.1→D.5 (5) |
| PPN Track 3 | Apr 2 | ~30h | +0 | 70+ | Datum-canonical (should be tree-canonical); §11 pivot | 0 | D.1→D.5b+§11 (7) |
| SRE Track 2G | Mar 30 | ~10h | +32 | 11 | Heyting consumer works (lattice not Heyting) | 0 | D.1→D.3+NTT (4) |
| PPN Track 2B | Mar 30 | ~10h | -5 | 18 | Feature flag = safety net (actually gap) | 0 | D.1→D.3b (6+) |
| PPN Track 2 | Mar 29 | ~8.5h | +0 | 68 | Reader replacement straightforward (3258 insertions) | 0 | D.1→D.3 (6) |
| PAR Track 1 | Mar 28 | ~14h | +0 | 53 | BSP handles dynamic topology (it doesn't — CALM violation) | 0 | D.1→D.4 (4) |
| PPN Track 1 | Mar 26 | ~14h | +108 | 25 | 5-cell architecture from Track 0 maps cleanly | 0 | D.1→D.9 (9) |
| PPN Track 0 | Mar 26 | ~4h | +30 | 8 | Lattice domains are independent (bridges needed) | 0 | D.1→D.4 (4) |
| **Track 4B** | **Apr 7** | **~3 sessions** | **+31** | **47** | **Context-bot = empty; generic ops need #f** | **9** | **D.1→D.2** |

**Patterns across 11 PIRs**:

1. **Test delta = 0 is a red flag** (3/11 PIRs). PPN Track 3, PPN Track 2, PAR Track 1 all had +0 test delta. Two of those required follow-up test additions. Track 4B explicitly added Phase T to break this pattern — and Phase T immediately caught 2 production bugs (generic ops typing, export issues).

2. **Wrong assumptions cluster around lattice/algebraic properties** (5/11). SRE 2H (Heyting), SRE 2G (Heyting consumer), PPN Track 4 (ephemeral sufficient), PAR Track 1 (CALM), Track 4B (context-bot). The lattice is the most assumption-laden part of the architecture.

3. **Design iterations average 5.0 rounds** across 11 tracks. The 2-round Track 4B (D.1→D.2) is an outlier — it benefited from the extensive Track 4 design cycle (D.1→D.4) that preceded it. Tracks with fewer design rounds tend to have more implementation surprises.

4. **Infrastructure tracks produce the most commits** (PPN Track 3: 70+, PPN Track 2: 68, Track 4: 69, Track 4B: 47). Design tracks produce fewer (SRE 2G: 11, PPN Track 0: 8).

5. **Duration is bimodal**: ~4-10h for focused tracks, ~14-30h for infrastructure tracks. Track 4B at ~3 sessions is in the infrastructure range.

## §18. Metrics

| Metric | Value |
|--------|-------|
| Phases completed | 12 of 14 (8 blocked, 10+11 deferred) |
| Commits | 47 |
| Code delta | +2117 / -281 lines across 13 files |
| typing-propagators.rkt | ~1800 lines (from ~300) |
| Test delta | +31 (4 new files) + 27 (existing updates) |
| Suite files | 387 → 391 |
| Suite tests | 7578 → 7609 |
| Suite time | 134.1s (below 145s baseline) |
| Propagator patterns added | 3 (P1 initial write, P2 fire-once, P3 cleanup) |
| Expression kinds covered | 30+ (12 node kinds × 5 facets) |
| On-network coverage | ~90% (up from 46% in Track 4) |
| Imperative bridges remaining | 6 (documented in Track 4C) |

## §19. What's Next

**Immediate**:
- **Track 4C design cycle**: Dissolve the 6 imperative bridges. Design note captured at `docs/research/2026-04-07_PPN_TRACK4C_DESIGN_NOTE.md`.
- **BSP-LE Track 1.5**: Cell-based TMS unblocks Phase 8 (ATMS union branching).

**Medium-term**:
- Phase 10 (zonk retirement): Requires cell-refs replacing expr-meta.
- Phase 11 (scaffolding retirement): 8 items from Tracks 2H + 2D.
- Usage tracking test coverage: Phase 4 needs dedicated tests.

**Long-term**:
- Full 100% on-network elaboration (Track 4C + BSP-LE 1.5 + Phase 10).
- Incremental re-checking via CHAMP diffs.
- Language-level fire-once propagator support (NTT syntax).

## §20. Key Files

| File | Role | Lines |
|------|------|-------|
| typing-propagators.rkt | ALL attribute evaluation: 5 facets, propagator fire fns, install-typing-network, infer-on-network | ~1800 |
| propagator.rkt | Network infrastructure: compound paths, net-clear-dependents, P2 removal | +121 |
| driver.rkt | 4 call sites: on-network primary, diagnostic fallback | +28 |
| batch-worker.rkt | 12 constraint cell-id resets + attribute-map cell | +21 |
| test-attribute-record.rkt | Phase 1 tests: facet-bot, merge, that-read/that-write | 89 |
| test-propagator-patterns.rkt | P1/P2/P3 pattern tests | 90 |
| test-sre-coverage.rkt | Phase 9 expression kind tests | 108 |
| test-meta-feedback.rkt | Phase 3 meta-feedback + coercion tests | 123 |
| bench-typing-propagators.rkt | Micro-benchmarks: timing, memory, network size | 176 |

## §21. Lessons Distilled

| Lesson | Distilled To | Status |
|--------|-------------|--------|
| ⊥ must be distinguishable from every legitimate value | DEVELOPMENT_LESSONS.org | Pending |
| `#f` registration = invisible deferral; compute or flag | DEVELOPMENT_LESSONS.org | Pending |
| Test files during implementation, not after | workflow.md (already codified) | Done |
| Comprehensive vocabulary audit before coverage expansion | DEVELOPMENT_LESSONS.org | Pending |
| P1/P2/P3 propagator patterns | PATTERNS_AND_CONVENTIONS.org | Pending |
| install-from-rule should accept all-children from the start | — | Applied in code |
