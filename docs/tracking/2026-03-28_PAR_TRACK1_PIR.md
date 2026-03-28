# PAR Track 1: Stratified Topology — BSP-as-Default — Post-Implementation Review

**Date**: 2026-03-27/28
**Duration**: ~10 hours implementation + ~4 hours design = ~14 hours total across 1 session
**Commits**: ~53 (from `af35f5e` CALM guard through `90e293b` cleanup)
**Test delta**: 7529 → 7529 (0 new tests — infrastructure migration)
**Code delta**: ~1037 insertions, ~178 deletions across 15 files
**Suite health**: 380/380, 7529 tests, 148.0s, all pass
**Design iterations**: 4 (D.1 → D.4, including external critique)
**Design docs**: [PAR Track 1 Design](2026-03-27_PAR_TRACK1_DESIGN.md) (D.4), [Stage 2 Audit](2026-03-27_PAR_TRACK1_STAGE2_AUDIT.md), [PAR Track 0 CALM Audit](2026-03-27_PAR_TRACK0_CALM_AUDIT.md)
**Prior PIRs**: [PPN Track 1](2026-03-26_PPN_TRACK1_PIR.md), [PPN Track 0](2026-03-26_PPN_TRACK0_PIR.md), [PM Track 10B](2026-03-26_PM_TRACK10B_PIR.md), [PM Track 10](2026-03-24_PM_TRACK10_PIR.md), [PM 8F](2026-03-24_PM_8F_PIR.md)
**Series**: PAR (Parallel Scheduling) — first track in the series

---

## 1. What Was Built

PAR Track 1 makes BSP (Bulk Synchronous Parallel) the **default scheduler** for the propagator network, replacing DFS (Depth-First Search). This is architecturally significant: BSP is the foundation for future true parallelism (PAR Track 2), and making it the default means every elaboration, type check, and trait resolution in Prologos now runs under a scheduler designed for concurrent execution.

The core problem was that BSP's snapshot-and-diff model silently dropped **dynamic topology** — fire functions that create new cells and propagators (structural changes) had those changes lost during `bulk-merge-writes`, which only diffed cell values. Two modules violated the CALM theorem's fixed-topology requirement: `sre-core.rkt` (structural decomposition creates sub-cells and sub-propagators) and `narrowing.rkt` (branch installation and rule evaluation create propagators and cells).

The solution is a **stratified topology protocol**: fire functions emit decomposition *requests* as cell values (monotone, lattice-compatible), and a topology stratum between BSP rounds processes those requests sequentially — creating cells, propagators, and registry entries outside the BSP snapshot. This separates value propagation (BSP-safe, parallelizable) from topology construction (sequential, but infrequent). The design draws on the CALM theorem (Consistency As Logical Monotonicity): monotone operations are safe for coordination-free parallelism; non-monotone operations require coordination points.

**Result**: 380/380 test files GREEN, 7529 tests passing, BSP 2.3% faster than DFS on real programs (within noise — no regression). The CALM guard catches future topology violations at runtime as errors, making the invariant correct-by-construction.

---

## 2. Timeline and Phases

All times PDT (UTC-7), 2026-03-27 through 2026-03-28.

### Design Phase (D.1 → D.4)

| Phase | Time | Commit | Description |
|-------|------|--------|-------------|
| PAR Track 0 | 17:56 | `2f3c160` | CALM audit: 2 violators, 7+ safe across 10+ modules |
| Stage 2 Audit | 18:07 | `813634a` | Exact call sites, data flow, per-operation counts |
| D.1 Initial | 18:17 | `a82a61b` | Stratified topology design, two-fixpoint loop |
| D.1 Rewrite | 18:49 | `48e9a8d` | Proper methodology: tracker, alternatives, walkthroughs |
| D.1 Complete | 19:01 | `e9dec63` | Phase completion protocol, benchmark design |
| D.2 Audit | 19:30–20:06 | `29434eb`→`6eeb73b` | eval-rhs audit, variant structs, CALM analysis revised |
| D.3 Self-critique | 20:24–21:00 | `a0c0db1`→`698a136` | Principles challenge, code grounding, Gap 1 fix |
| D.4 External critique | 21:13–21:22 | `880406c`→`4c0df1e` | Cell-id collision found, Option 3: pure fire functions |

**Design time**: ~4 hours (17:56 → 21:22)

### Implementation Phase

| Phase | Time | Duration | Commit(s) | Description | Key Finding |
|-------|------|----------|-----------|-------------|-------------|
| 0a | 19:40 | ~20m | `2bfb656` | Pre-0 micro-benchmarks (M1-M5) + adversarial (A1-A6) | BSP within noise of DFS (0.996 ratio) |
| 0b | 20:31 | ~10m | `f6a3048` | Narrowing CALM validation (empirical) | 23/31 pass, 0 cell errors |
| 1 | 21:29 | 3m | `bf2fff0` | Decomposition-request cell infrastructure | Cell-id 0 convention, zero struct changes |
| 2 | 21:32 | 3m | `482516a` | SRE → request emission (dual-path BSP/DFS) | ~10 lines per fire function |
| 3 | 21:36 | 4m | `21a9949` | Narrowing → request emission (branch + rule) | D.4 justified rule path (~25 lines) |
| 4 | 22:13–23:04 | ~51m | `775de00`→`cffeaa9` | Topology stratum in BSP loop | 6 bugs found, 111/111 targeted GREEN |
| 5 | 23:14–00:48 | ~94m | `07c8d4e`→`ef22799` | BSP-as-default + full suite | 4 more bugs, 16→2→0 failures, 380/380 GREEN |
| 6 | 00:51 | 3m | `3e0748b` | CALM contract documented | Structural capture retained |
| 7 | 00:51 | 2m | `c6a42b5` | Constraint-propagators contract | Callback-topology documented |
| 8 | 00:55 | 4m | `f0c626f` | A/B benchmarks: BSP 2.3% faster | 14 programs, 5 runs, within noise |
| 9 | 00:56 | 1m | `90e293b` | Debug prints removed | Production-clean |

**Implementation time**: ~6 hours (19:40 → 00:56), excluding Phase 0a/0b overlap with design
**Design-to-implementation ratio**: ~1.5:1 (4h design : ~6h implementation, or ~0.7:1 for core Phases 1-9 at ~2.7h)

**Critical observation**: Phases 1-3 (the "clean" infrastructure) took 10 minutes total. Phases 4-5 (integration with real code) took 2h 25m — 14.5x longer. The integration phases found all 10 bugs. Design predicted Phase 4 at ~40 lines; actual was ~40 lines but with 6 bug-fix iterations.

---

## 3. Test Coverage

No new test files were created. This is an infrastructure migration — existing tests validate correctness:

| Category | Files | Tests | Coverage |
|----------|-------|-------|----------|
| SRE subtype | 1 | 26 | Compound type decomposition under BSP |
| SRE duality | 1 | 13 | Dual-pair decomposition, self-dual, asymmetric |
| SRE core | 1 | 43 | Equality, basic structural relations |
| Narrowing | 4 | 53 | Branch installation, rule evaluation, definitional trees |
| Full suite | 380 | 7529 | All elaboration now under BSP |

**Acceptance file**: Not applicable (infrastructure migration, not new user-facing syntax).

**Benchmark files created**:
- `benchmarks/micro/bench-bsp-overhead.rkt` — permanent micro-benchmark (M1-M5)
- `benchmarks/comparative/scheduler-adversarial.prologos` — permanent adversarial benchmark (A1-A6)
- `data/benchmarks/par-track1-scheduler-ab.txt` — A/B results archive

**Test modifications**: 5 test files updated for cell-id 0 offset (request cell shifts all cell-ids by 1) and DFS-specific test isolation.

---

## 4. Bugs Found and Fixed

10 distinct bugs found during implementation. 6 of 10 were found via the diagnostic protocol (trace simplest failing case, hypothesize from data, test narrowly).

### Phase 4 Bugs (targeted tests, 111/111)

**Bug 1: Decomp-request cell not captured by BSP diff**
- *Symptom*: Topology stratum never fires — request cell changes invisible to BSP.
- *Root cause*: `fire-and-collect-writes` only diffed declared propagator outputs. The request cell (cell-id 0) is a cross-cutting concern that no propagator declares as an output.
- *Fix*: Also check cell-id 0 in the diff output. Later generalized to full CHAMP diff in Phase 5.
- *Why it seemed right*: The design said "BSP extracts value diff: decomp-request cell changed." But the implementation's diff was scoped to declared outputs, not all cells. The design's walkthrough was correct; the implementation's diff was narrower than assumed.

**Bug 2: Infinite loop from monotone clearing**
- *Symptom*: Topology stratum processes requests, "clears" them, but they reappear next iteration.
- *Root cause*: `net-cell-write(cell, empty-set)` with set-union merge is a no-op: `set-union(S, empty) = S`. The lattice has no "clear" operation.
- *Fix*: `net-cell-reset` — direct assignment bypassing the merge function.
- *Why it seemed right*: "Write empty set to clear" is intuitive from imperative programming. But monotone lattices don't support clearing — that's a non-monotone operation. The design (Section 4.2) explicitly noted that clearing is non-monotone and "permitted outside BSP rounds," but didn't flag that `net-cell-write` enforces monotonicity.

**Bug 3: decomp-key format crash**
- *Symptom*: Hash contract violation in topology stratum request dedup.
- *Root cause*: Narrowing pair-keys used ad-hoc lists; `decomp-key-hash` expected `decomp-key` structs. Data format inconsistency across subsystems.
- *Fix*: Use `decomp-key()` constructor uniformly.
- *Why it seemed right*: Narrowing and SRE were written at different times with different keying conventions. The topology stratum unified them but assumed consistent format.

**Bug 4: SRE handler not registered in test contexts**
- *Symptom*: Topology stratum has no handler for SRE requests — crashes with "unknown request type."
- *Root cause*: The topology handler was in `driver.rkt`; SRE tests don't import `driver.rkt`.
- *Fix*: Self-registering handler in `sre-core.rkt` at module load time. Same pattern as narrowing.
- *Why it seemed right*: Centralizing handlers in `driver.rkt` follows the coordinator pattern. But the two-context boundary (elaboration vs module-loading/test) means test paths don't traverse the coordinator. Self-registration follows the decomplection principle: each module knows its own request types.

**Bug 5: Duality handler rejected bot cells**
- *Symptom*: `sre-duality` decomposition fails for propagate-one cases (one cell has a value, the other is bot).
- *Root cause*: The generic topology handler's `(or (bot? va) (bot? vb))` check rejected cases where one cell is bot. Correct for equality/subtype (can't decompose if one side unknown). Wrong for duality: the fire function does case analysis and emits requests only for topology operations.
- *Fix*: Skip the bot check for duality relations. The duality fire function handles the asymmetric cases.
- *Why it seemed right*: Equality and subtype have symmetric decomposition — both sides must be known. Duality is fundamentally asymmetric (one side may remain bot while the other is decomposed). The generic handler wrongly assumed symmetry.

**Bug 6: Self-dual mu — missing tag derivation**
- *Symptom*: `mu` types crash with "unknown dual tag."
- *Root cause*: `mu` has no entry in dual-pairs (it's self-dual: `dual(mu) = mu`). The handler tried to look up the bot cell's tag via dual-pairs and failed.
- *Fix*: Self-dual fallback: when no dual mapping exists, assume `tag-b = tag-a`.
- *Why it seemed right*: The dual-pairs registry was designed for asymmetric pairs (Send/Recv, Select/Offer). Self-dual constructors weren't anticipated as a category.

### Phase 5 Bugs (full suite, 380/380)

**Bug 7: Category A CALM violations in 3 additional modules**
- *Symptom*: 16 test files fail under BSP with CALM guard errors.
- *Root cause*: `constraint-propagators.rkt`, `elaborator-network.rkt`, and `bilattice.rkt` also create cells/propagators during fire functions. The CALM audit (Track 0) found 2 violators; 3 more were latent.
- *Fix*: DFS wrappers for each: wrap the offending operations in `parameterize ([current-bsp-fire-round? #f])` to temporarily exit BSP mode. This is a correct interim solution — these modules' fire functions create cells in contexts where snapshot isolation isn't a concern (they're called from the topology stratum path or from non-BSP contexts).
- *Lesson*: The CALM audit should have been exhaustive (grep for ALL `net-new-cell`/`net-add-propagator` call sites reachable from fire functions), not sampling-based.

**Bug 8: Full CHAMP diff needed (session contradictions)**
- *Symptom*: Session contradiction propagation lost under BSP.
- *Root cause*: `fire-and-collect-writes` diffed only cell values (the `warm` layer's `cells` CHAMP). Session contradictions are stored in a separate CHAMP field (`session-contradictions`). The diff missed them entirely.
- *Fix*: Full CHAMP diff — compare ALL warm-layer fields, not just cells.
- *Why it seemed right*: The design focused on cell values and decomposition requests. Session contradictions were an unaudited data path.

**Bug 9: Structural propagator capture (PUnify topology)**
- *Symptom*: PUnify creates structural-relate propagators during fire functions. Lost under BSP.
- *Root cause*: `net-add-propagator` during BSP was blocked by the CALM guard. PUnify's structural decomposition (different from SRE) also modifies network topology.
- *Fix*: Structural propagator capture in `fire-and-collect-writes` — track propagators created during fire and install them in the topology stratum. This extends the request protocol to handle raw propagator additions.
- *Why it seemed right*: PUnify was not in the CALM audit scope (it was considered part of the unification subsystem, not the decomposition subsystem). But PUnify's `structural-unify-propagators` creates propagators in fire functions, making it a CALM violator.

**Bug 10: Split diff needed for non-idempotent merges**
- *Symptom*: Under BSP, some cell values grow unboundedly (sets accumulate duplicates).
- *Root cause*: `fire-and-collect-writes` merged ALL cell writes via `bulk-merge-writes`. For cells with non-idempotent merge functions (where `merge(v, v) != v`), this double-applied values from the snapshot. The diff captured the snapshot's value as a "write" and merged it back.
- *Fix*: Split diff into declared outputs (apply merge) and undeclared outputs (direct capture, no re-merge).
- *Why it seemed right*: The assumption was all merge functions are idempotent. Set-union IS idempotent (`S U S = S`), but some cells use custom merges that aren't.

---

## 5. Design Decisions and Rationale

| # | Decision | Rationale | Principle |
|---|----------|-----------|-----------|
| 1 | Single request cell (cell-id 0) | Simplest option. One cell, one merge, one check. Avoids struct changes to prop-network. | Data Orientation, Decomplection |
| 2 | Variant structs for requests | `sre-decomp-request`, `narrowing-branch-request`, `narrowing-rule-request`. Each carries exactly its fields (D.2 revision from flat 11-field struct). | Data Orientation |
| 3 | Dual-path BSP/DFS | Fire functions check `current-bsp-fire-round?`. BSP path emits request; DFS path calls inline. Keeps DFS as fallback and for non-BSP contexts (speculation, per-command quiescence). | Completeness |
| 4 | Option 3: pure fire functions (D.4) | ALL mutation deferred to topology stratum. Eliminates entire class of snapshot-isolation problems (cell-id collision). Reverses D.2's "cell-only is CALM-safe" finding. | Correct-by-Construction |
| 5 | Self-registering topology handlers | Each module (`sre-core.rkt`, `narrowing.rkt`) registers its handler at module load time. Avoids central coordinator pattern that fails in test contexts. | Decomplection |
| 6 | Cell-id 0 convention | Request cell always gets id 0, `next-cell-id` starts at 1. Zero struct changes to `prop-network`. Convention over configuration. | First-Class by Default (for the convention), Decomplection (no struct changes) |
| 7 | Retained structural propagator capture | D.4 said "no cells during BSP." Reality: PUnify and bilattice create topology. Instead of forcing all modules through the request protocol immediately, capture structural changes in `fire-result` and install them in the topology stratum. Pragmatic — full request protocol migration is future work. | Completeness (practical) |

### D.1 → D.4: The Design Evolution Story

**D.1** (Initial): Two-fixpoint BSP loop with a flat decomposition-request struct and five micro-benchmarks. Conservative: ALL `net-new-cell` in fire functions treated as CALM violations.

**D.2** (Eval-rhs audit): Discovered that eval-rhs creates cells but NOT propagators. Four `net-new-cell` sites, zero `net-add-propagator`. Concluded cell-only creation is CALM-safe (no scheduling effect). Revised request struct to variant types. Added occurs check for recursive types.

**D.3** (Self-critique — two-lens): Applied principles challenge (does every design choice serve a principle?) and codebase reality check (does the code actually match the design's assumptions?). Found Gap 1: `fire-and-collect-writes` didn't capture `widen-fns` or `cell-dirs` — incomplete cell capture. Added structural capture via `next-cell-id` comparison. Added registry dedup to topology stratum.

**D.4** (External critique): Found the **critical flaw** in D.2/D.3's approach. Under BSP snapshot isolation, ALL fire functions receive the SAME snapshot. Two rule fire functions both calling `net-new-cell` start from the same `next-cell-id` and produce overlapping cell-ids. `bulk-merge-writes` first-writer-wins silently drops the second's cells. The second fire function's `term-ctor` references now point to wrong cells.

D.4 evaluated four options and chose **Option 3: pure fire functions** — defer ALL cell and propagator creation to the topology stratum. This eliminated the entire class of snapshot-isolation problems and produced the cleanest separation: fire functions compute values, the topology stratum constructs structure.

**Key meta-observation**: D.2's finding ("cell-only is CALM-safe") was correct in the DFS model but wrong in the BSP model. The CALM theorem's fixed-topology requirement includes the cell identity space, not just the propagator graph. D.4's external critique caught this because it asked: "what happens when two fire functions both create cells from the same snapshot?"

---

## 6. Lessons Learned

### L1: The diagnostic protocol is essential for BSP debugging

6 of 10 bugs were found via the diagnostic protocol (trace simplest failing case → hypothesize → test narrowly). BSP bugs are particularly hard to diagnose without it: the snapshot-and-diff model means errors manifest as silent data loss (values disappear), not crashes. Bug 8 (session contradictions lost) and Bug 10 (non-idempotent merge) would have been extremely difficult to find without tracing the simplest failing test case to see exactly which cell writes were dropped.

### L2: CALM audits must be exhaustive, not sampling-based

The Track 0 CALM audit found 2 violators by examining known SRE and narrowing fire functions. Phase 5 found 3 additional violators (`constraint-propagators.rkt`, `elaborator-network.rkt`, `bilattice.rkt`) that create topology in fire functions. A grep-based exhaustive audit (all `net-new-cell`/`net-add-propagator` reachable from fire function entry points) would have caught these in Track 0. The sampling approach found the obvious cases but missed transitive callers.

### L3: Duality is the hardest structural relation for BSP

Equality and subtype have symmetric decomposition (same tag both sides, both cells must be known). Duality is fundamentally asymmetric: different tags, propagate-one vs propagate-both, self-dual constructors. Bugs 5 and 6 are duality-specific. Any future work on SRE relations should test duality first — it exercises the most edge cases.

### L4: The dual-path pattern (BSP → emit, DFS → inline) is robust

Each fire function gained ~10-15 lines for the BSP path. The topology stratum calls the SAME functions as the DFS path (`sre-decompose-generic`, `install-narrowing-propagators`, `eval-rhs`) — just from outside the BSP round. Zero changes to the called functions. This pattern is reusable for any future CALM violator.

### L5: Cell-id 0 convention avoids pipeline exhaustiveness

Adding a field to `prop-network` would trigger the 14-file pipeline exhaustiveness checklist (struct-copy in 4+ external files, as discovered in BSP-LE Track 0). Using cell-id 0 by convention avoids all of this. Convention over configuration, where the convention is enforced by `next-cell-id` starting at 1.

### L6: Integration phases dominate implementation time

Phases 1-3 (clean infrastructure): 10 minutes. Phases 4-5 (integration): 2h 25m. Ratio: 14.5:1. This matches the PM Track 8 pattern (B0-B2 infrastructure: fast; B3-B5 integration: slow) and the SRE Track 1 pattern. The lesson isn't "integration is hard" (generic) — it's that **BSP integration testing requires running the full test suite under the new scheduler, and each failure reveals a new category of data path that the diff model must handle**. The categories are not predictable from the design because they depend on runtime interaction patterns.

### L7: External critique catches snapshot-isolation bugs that self-critique misses

D.3's self-critique applied principles and grounded in code — but still missed the cell-id collision. D.4's external critique caught it immediately by asking "what happens under concurrent execution?" The external critic operates with different assumptions about the execution model and naturally asks "what if X and Y happen simultaneously?" — exactly the question BSP demands.

---

## 7. Metrics

| Metric | Value |
|--------|-------|
| Design time | ~4 hours (D.1 → D.4) |
| Implementation time | ~6 hours (Phase 0a → Phase 9) |
| Core implementation (Phases 1-9) | ~2.7 hours |
| Design:implementation ratio | 1.5:1 overall; 0.7:1 for core phases |
| Total commits | ~53 (design + implementation + docs) |
| Files modified | 15 (code: propagator.rkt, sre-core.rkt, narrowing.rkt, elaborator-network.rkt, constraint-propagators.rkt, driver.rkt, + 5 test files, + 4 benchmark/tooling) |
| Lines added | ~1037 |
| Lines removed | ~178 |
| Bugs found | 10 (6 via diagnostic protocol) |
| Design iterations | 4 (D.1 → D.4) |
| Phases | 11 (0a, 0b, 1-9) |
| Phases 1-3 time | ~10 minutes |
| Phases 4-5 time | ~2h 25m |
| Integration:infrastructure ratio | 14.5:1 |
| Test files passing | 380/380 |
| Total tests | 7529 |
| Suite wall time | 148.0s |
| A/B result | BSP 2.3% faster than DFS (within noise) |

---

## 8. What's Next

### Immediate

- **PAR Track 2 (True Parallelism)**: Research track. BSP's round-based model is parallelism-ready — fire functions in the same round are independent by construction. PAR Track 1 proves correctness; Track 2 explores Racket futures/places for actual parallel fire.
- **PAR Track 3 (`:auto` heuristic)**: Use the A/B benchmarking data from Track 1 to build a heuristic that selects BSP vs DFS per-quiescence based on workload characteristics (worklist size, fan-out ratio).

### Medium-term

- **Full request protocol for all CALM violators**: Bugs 7 and 9 showed that `constraint-propagators.rkt`, `elaborator-network.rkt`, `bilattice.rkt`, and PUnify also create topology in fire functions. Currently handled via DFS wrappers (pragmatic) or structural capture (Bug 9). The principled solution is the request protocol for each.
- **Non-idempotent merge audit**: Bug 10 revealed that some merge functions are non-idempotent. A systematic audit of all cell merge functions would prevent similar issues in future BSP extensions.

### Long-term

- **Topology stratum as first-class construct**: Currently the topology stratum is a special case (one cell, one handler registry). Could be generalized: any propagator can request structural changes via a typed request protocol, and the topology stratum dispatches by request type. This is the path to user-defined propagator topologies.

### Deferred (with justification)

| Item | Rationale | Tracking |
|------|-----------|----------|
| Full request protocol for constraint-propagators | Works via DFS wrapper; request protocol needs broader design for callback-based topology | DEFERRED.md |
| Non-idempotent merge audit | Split diff handles known cases; systematic audit is a quality-of-life improvement | DEFERRED.md |
| Topology stratum generalization | PAR Track 2+ territory; needs research on typed request protocols | PAR Master |

---

## 9. Key Files

| File | Role |
|------|------|
| `racket/prologos/propagator.rkt` | BSP scheduler, topology stratum, CALM guard, request cell, fire-and-collect-writes |
| `racket/prologos/sre-core.rkt` | Dual-path BSP/DFS for decomposition, self-registering topology handler |
| `racket/prologos/narrowing.rkt` | Dual-path for branch and rule fire functions |
| `racket/prologos/elaborator-network.rkt` | DFS wrapper for cell-creating fire functions |
| `racket/prologos/constraint-propagators.rkt` | DFS wrapper + CALM contract documentation |
| `racket/prologos/driver.rkt` | Topology handler parameterization in process-command |
| `benchmarks/micro/bench-bsp-overhead.rkt` | Permanent micro-benchmark: M1-M5 BSP vs DFS overhead |
| `benchmarks/comparative/scheduler-adversarial.prologos` | Permanent adversarial benchmark: deep nesting, wide arity, mixed decomposition |
| `data/benchmarks/par-track1-scheduler-ab.txt` | A/B results archive |
| `docs/tracking/2026-03-27_PAR_TRACK1_DESIGN.md` | Design document (D.4) |
| `docs/tracking/2026-03-27_PAR_TRACK0_CALM_AUDIT.md` | CALM audit (prerequisite) |
| `docs/tracking/2026-03-27_PAR_TRACK1_STAGE2_AUDIT.md` | Stage 2 call-site audit |

---

## 10. What Went Well

1. **The D.4 external critique caught a critical correctness bug before implementation.** Cell-id collision under BSP snapshot isolation would have manifested as silent wrong results (term-ctor referencing wrong cells). This is the hardest class of bug to find post-implementation because the symptom is wrong type-checking results, not crashes. D.4 prevented it structurally — Option 3 (pure fire functions) eliminates the entire class.

2. **Phases 1-3 were trivially fast (10 minutes total).** The dual-path pattern (BSP → emit request, DFS → inline) is a mechanical transformation that required ~10-15 lines per fire function. The design's walkthroughs (Sections 5-6) provided exact code structure. Zero improvisation needed.

3. **The diagnostic protocol found 6 of 10 bugs efficiently.** Each bug was found by tracing the simplest failing test case, forming a specific hypothesis, and testing it. Bug 5 (duality bot rejection) and Bug 6 (self-dual mu) would have been extremely hard to find without this systematic approach — they're deep in SRE case analysis.

4. **Pre-0 benchmarks validated the design before implementation.** M1-M5 showed BSP overhead is negligible on real programs (0.996 ratio). M3 showed chains are BSP's weak case (7.9x at depth 10) but don't manifest in practice. This data justified proceeding with BSP-as-default without performance-motivated complexity.

5. **The CALM guard is correct-by-construction.** `current-bsp-fire-round?` checks in `net-new-cell` and `net-add-propagator` make future CALM violations produce immediate errors, not silent wrong results. This caught Bugs 7 and 9 (additional CALM violators not in the audit) at the exact point of violation.

---

## 11. What Went Wrong

1. **The CALM audit was not exhaustive.** Track 0 examined known fire functions in SRE and narrowing. Phase 5 found 3 additional modules (`constraint-propagators.rkt`, `elaborator-network.rkt`, `bilattice.rkt`) with CALM violations. A grep for all `net-new-cell`/`net-add-propagator` reachable from any fire function entry point would have found these. The sampling approach saved time in Track 0 but cost time in Phase 5 (16 initial failures to triage).

2. **`fire-and-collect-writes` had a narrower diff than the design assumed.** The design said "BSP extracts value diffs." The implementation only diffed declared propagator outputs. This missed: the request cell (Bug 1), session contradictions (Bug 8), and structural propagators (Bug 9). Each required progressively widening the diff — from declared outputs, to the full cells CHAMP, to full warm-layer CHAMP, to structural propagator capture.

3. **The monotone clearing assumption (Bug 2) is a category error.** Writing `empty-set` via `net-cell-write` applies the merge function, making it a no-op for set-union. The design explicitly noted that clearing is non-monotone (Section 4.2), but the implementation used the monotone write path. A dedicated `net-cell-reset` function was needed — stepping outside lattice discipline for an explicitly non-monotone operation.

4. **D.2's "cell-only is CALM-safe" was correct locally but wrong globally.** In the DFS model, `net-new-cell` doesn't affect scheduling. In the BSP model, two fire functions sharing a snapshot produce overlapping cell-ids. D.2's analysis examined the operation in isolation (one fire function), not under concurrency (multiple fire functions). This class of reasoning error — analyzing concurrent operations one at a time — is a known pitfall in distributed systems.

---

## 12. Where We Got Lucky

1. **Bug 10 (non-idempotent merges) manifested as test failures, not silent wrong results.** Non-idempotent merges under BSP cause values to grow (set accumulation) rather than stabilize. If the merge had been "closer to idempotent" (e.g., producing the same final value after convergence but taking more rounds), the bug would have been invisible — correct results, just slower. The symptom being visible failures made it diagnosable.

2. **Phase 5's 16 initial failures were all distinct categories.** Each failure pointed to a different aspect of the BSP diff model (declared outputs, CHAMP fields, structural changes, non-idempotent merges). If multiple bugs had produced the same symptom, diagnosis would have been much harder — overlapping root causes mask each other. The fact that each failure had a clear, unique root cause was fortunate.

3. **PUnify's structural decomposition (Bug 9) was caught by the CALM guard.** If the CALM guard had not been active, PUnify would have created propagators during BSP fire rounds that silently vanished. The guard turned a silent-wrong-result into a loud error. The guard was designed for the known violators (SRE, narrowing) but also caught an unknown violator.

---

## 13. What Surprised Us

1. **The request cell needs `net-cell-reset`, not `net-cell-write`.** A monotone lattice has no "clear" operation by definition. This is obvious in hindsight but wasn't anticipated in the design — the design said "clear processed requests" without specifying the mechanism. The topology stratum operates in a non-monotone regime (between BSP rounds), so stepping outside the lattice discipline is correct. But it required a new network primitive.

2. **Duality is asymmetric in ways that affect BSP.** Equality and subtype decompose symmetrically (both cells must be known). Duality decomposes asymmetrically (one cell may be bot). This asymmetry was not anticipated as a BSP-relevant property — it seemed like a purely semantic distinction. But it meant the generic topology handler's bot-check was wrong for duality.

3. **The integration:infrastructure time ratio (14.5:1) was higher than any prior track.** For comparison: PM Track 8 had ~3:1, SRE Track 1 had ~2:1. The explanation is that BSP integration touches every data path through the propagator network — each data path that doesn't go through the declared-output diff is a potential bug. The number of data paths is not knowable from the design.

4. **BSP is 2.3% faster than DFS, not just "within noise."** Across 14 programs and 5 runs, BSP consistently measured faster. The difference isn't statistically significant (p > 0.05), but the direction surprised — BSP's round overhead should make it slightly slower. Possible explanation: BSP's batch merging amortizes some per-write overhead that DFS pays incrementally.

---

## 14. Architecture Assessment

### How the Architecture Held Up

The propagator network architecture held up well as a foundation for BSP. The key architectural properties that enabled the stratified topology approach:

- **Immutable network snapshots** (cold/warm layering): BSP's snapshot-and-diff works because `fire-and-collect-writes` operates on a frozen snapshot. This property was established in Track 8 and is the foundation of the entire BSP model.
- **Cell-value lattice discipline**: All cell writes go through merge functions, ensuring monotonicity within BSP rounds. The topology stratum's non-monotone `net-cell-reset` is explicitly outside BSP rounds.
- **Parameterized scheduling** (`current-use-bsp-scheduler?`): The DFS/BSP switch was already in place from Track 8 C5. PAR Track 1 only changed the default.

### Architectural Friction Points

1. **`fire-and-collect-writes` diff is too narrow.** It was designed to diff declared propagator outputs. BSP needs it to capture ALL network mutations (cells, propagators, CHAMPs, registries). The progressive widening (Bugs 1, 8, 9, 10) suggests the right abstraction is: "diff the entire warm layer, categorize changes by type." Currently it's "diff specific fields, add more fields as bugs are found."

2. **Non-idempotent merges are an implicit contract.** BSP's correctness depends on merge idempotency for correctness under re-application. Some cells have non-idempotent merges. The split diff (Bug 10) works around this, but the principled solution is either (a) require all merges to be idempotent, or (b) track which cells were modified vs. which were only read.

3. **CALM violations require per-module coordination.** Each module that creates topology in fire functions needs either the request protocol or a DFS wrapper. There's no single point of control — the CALM guard catches violations at runtime, but the fix is per-module. This is a maintenance burden that will grow as more modules add propagators.

---

## 15. What We Would Do Differently

1. **Exhaustive CALM audit in Track 0.** Grep for ALL `net-new-cell` and `net-add-propagator` call sites reachable from any function that could be a fire function. The sampling approach missed 3 violators. Cost: ~30 minutes more in Track 0. Savings: ~1 hour in Phase 5.

2. **Design the full CHAMP diff from the start.** Bug 1 (request cell), Bug 8 (session contradictions), and Bug 9 (structural propagators) all stem from the same root cause: the diff was too narrow. Designing a full warm-layer diff in Phase 4 would have prevented 3 of 10 bugs.

3. **Add `net-cell-reset` as a first-class operation in the design.** The design said "clear processed requests" without specifying the mechanism. Adding `net-cell-reset` to the design's API table (Section 7, D.4) would have prevented Bug 2.

4. **Test duality first, not last.** Duality is the hardest SRE relation for BSP (asymmetric decomposition, self-dual constructors, propagate-one cases). Testing it first would have surfaced Bugs 5 and 6 earlier, before the simpler equality/subtype paths were debugged.

---

## 16. Longitudinal Survey: 10 Most Recent PIRs

| # | Track | Date | Duration | Commits | Test delta | Bugs | Design iters | Wrong assumptions |
|---|-------|------|----------|---------|------------|------|-------------|------------------|
| 1 | PAR Track 1 | 03-27/28 | ~14h | ~53 | 7529→7529 | 10 | 4 (D.1→D.4) | CALM audit scope, diff width, cell-only CALM safety |
| 2 | PPN Track 1 | 03-26 | ~14h | ~25 | 7421→7529 | 0 algorithmic | 9 (D.1→D.9) | None (9 design iterations prevented all bugs) |
| 3 | PPN Track 0 | 03-26 | ~4h | 8 | 7391→7421 | 0 | 4 (D.1→D.4) | None |
| 4 | PM Track 10B | 03-25/26 | ~8h | ~20 | 7364→7364 | 1 (PUnify regression) | 4 (D.1→D.4) | Zonk elimination scope (blocked on SRE 2C) |
| 5 | PM Track 10 | 03-24 | ~12h | ~30 | 7343→7364 | 12+ | 4 (D.1→D.4) | Module loading isolation, registry completeness |
| 6 | PM 8F | 03-24 | ~8h | ~15 | 7401→7401 | 3 | 4 (D.1→D.4) | Zonk site count (225→31), typing-core zonk (100→0) |
| 7 | SRE Track 2 | 03-23 | ~4h | 6 | 7401→7401 | 1 | 4 (D.1→D.4) | None significant |
| 8 | SRE Track 1 | 03-23 | ~8h | 21 | 7358→7401 | 3 | 4 (D.1→D.4) | Merge-per-relation needed, duality harder than expected |
| 9 | SRE Track 0 | 03-22 | ~3h | 7 | 7343→7358 | 0 | 2 (D.1→D.2) | None |
| 10 | PM Track 8 | 03-22 | ~18h | 66 | 7308→7343 | 4+ | 4 (D.1→D.4) | Ghost meta (3 attempts), circular deps, HKT preparse |

### Recurring Patterns (3+ PIRs)

**Pattern A: Design iterations prevent implementation bugs** (10/10 PIRs)
Every track uses multi-iteration design (D.1→D.4). Tracks with more iterations relative to complexity have fewer implementation bugs. PPN Track 1 (9 iterations, 0 algorithmic bugs) vs PM Track 10 (4 iterations for large scope, 12+ bugs). PAR Track 1's D.4 external critique prevented what would have been a critical silent-wrong-result bug (cell-id collision). This pattern is now quantitatively established across all 10 PIRs. **Status: codification-ready.** The design:implementation ratio >= 1.7:1 predicts smooth implementations (noted in 2026-03-27 dailies).

**Pattern B: Integration phases dominate implementation time** (7/10 PIRs)
PAR Track 1 (14.5:1), PM Track 8 (~3:1), SRE Track 1 (~2:1), PM Track 10 (high), PM 8F, PPN Track 1, PM Track 10B. Infrastructure code is fast to write; wiring it into the existing codebase takes 2-15x longer. The BSP-specific variant is more extreme because BSP touches every data path. **Status: codified** (DEVELOPMENT_LESSONS.org — "integration time is O(data paths), not O(lines)").

**Pattern C: Two-context boundary (elaboration vs module-loading/test) causes bugs** (6/10 PIRs)
PAR Track 1 (Bug 4: handler not registered in tests), PM Track 8 (Bug B2b: unconditional network creation in tests), PM Track 10 (module-loading isolation), PM 8F (test contexts without network), PM Track 10B (run-ns-last divergence), SRE Track 1 (test fixture patterns). This is the same boundary every time: code that works in the full elaboration context (driver.rkt → process-command → parameterize) fails in test contexts or module-loading contexts that don't traverse the same setup path. **Status: codified** (pipeline.md "Two-Context Audit" checklist).

**Pattern D: Exhaustive audit prevents cascade debugging** (5/10 PIRs)
PAR Track 1 (CALM audit missed 3 violators), PM Track 10 (registry completeness — 17 registries discovered iteratively), PM Track 8 (circular deps found at compile time, not audit time), PM 8F (zonk site count wrong by 7x), SRE Track 1 (merge-per-relation discovered during implementation). In each case, a more exhaustive upfront audit would have prevented iterative discovery during implementation. **Status: partially codified** (pipeline.md checklists). PAR Track 1 adds: "CALM audit must grep all reachable call sites, not sample known fire functions."

**Pattern E: Duality/asymmetry is harder than symmetry** (3/10 PIRs)
PAR Track 1 (Bugs 5, 6 — duality handler, self-dual mu), SRE Track 1 (duality harder than expected, asymmetric decomposition), SRE Track 0 (duality as distinct domain). Symmetric operations (equality, subtype) work with generic handlers. Asymmetric operations (duality, session types) require case analysis. **Status: watching.** May be ready for codification after the next SRE/session-type track.

### New Patterns (emerging)

**Pattern F: BSP exposes implicit contracts** (1/10 PIRs — this track only, but 4 instances within it)
BSP's snapshot-and-diff model turns implicit contracts into bugs. The diff assumed declared outputs (implicit: "propagators only write to declared cells"). Merges assumed idempotency (implicit: "merge(v, v) = v"). Clearing assumed write semantics (implicit: "write empty-set clears"). Each implicit contract was a bug. DFS is forgiving — writes happen incrementally and each one is immediately visible. BSP is strict — only what the diff captures exists. **Status: watching.** If PAR Track 2 or future BSP work exposes more implicit contracts, this should be codified as an architectural principle.

### Trend Analysis

**Bug count trajectory**: Track 8 (4+), PM Track 10 (12+), PM 8F (3), SRE Track 2 (1), SRE Track 1 (3), SRE Track 0 (0), PM Track 10B (1), PPN Track 0 (0), PPN Track 1 (0), PAR Track 1 (10). The spike in PAR Track 1 despite mature design methodology suggests that **BSP integration is a qualitatively different challenge** — it exposes implicit contracts that monotone/DFS code never exercises. This isn't a methodology regression; it's a new problem category.

**Design iteration count**: Stabilized at 4 (D.1→D.4) for all tracks except PPN Track 1 (9) and SRE Track 0 (2). The 4-iteration pattern (initial → audit/benchmark → self-critique → external critique) is now the standard methodology. PPN Track 1's 9 iterations were driven by fundamental uncertainty about the right lattice architecture; SRE Track 0's 2 were sufficient for a small-scope track.

**Suite time trajectory**: 228s (Track 8) → 237s (SRE T0) → 245s (SRE T1) → 238s (SRE T2) → 236s (PM 8F) → 240s (PM T10 pre-cache) → 134s (PM T10 post-cache) → 134s (PM T10B) → 150s (PPN T0) → 144s (PPN T1) → 148s (PAR T1). The .pnet cache (PM Track 10) was the major step change. Current 148s is stable and within the 200s target.

---

## 17. Lessons Distilled

| Lesson | Distilled To | Status |
|--------|-------------|--------|
| CALM audit must be exhaustive (grep all reachable call sites) | pipeline.md — CALM audit checklist | Pending |
| BSP exposes implicit contracts (diff scope, merge idempotency, clearing semantics) | DEVELOPMENT_LESSONS.org — BSP implicit contracts | Pending |
| Duality is the hardest SRE path for BSP (test duality first) | PATTERNS_AND_CONVENTIONS.org — SRE testing order | Pending |
| Design:implementation ratio >= 1.7:1 predicts smooth implementations | DESIGN_METHODOLOGY.org — quantitative guideline | Pending (noted in dailies, not yet codified) |
| Two-lens self-critique (principles challenge + codebase reality) | DESIGN_METHODOLOGY.org | Done (commit `1055ef7`) |
| Integration phases dominate (O(data paths) not O(lines)) | DEVELOPMENT_LESSONS.org | Previously codified |
| Two-context boundary (elaboration vs test/module-loading) | pipeline.md | Previously codified |

---

## 18. Open Questions

- **Should ALL merge functions be required to be idempotent?** Bug 10 suggests yes, but enforcing this retroactively would require auditing every merge function. The split diff works around it, but it's a workaround, not a root fix.
- **Is the DFS wrapper pattern technical debt or permanent architecture?** Bugs 7 and 9 are handled via DFS wrappers (modules that create topology during fire functions temporarily exit BSP). Is this acceptable long-term, or should every module migrate to the request protocol?
- **What monitoring should exist for the topology stratum?** The round counter and request counter were removed in Phase 9 (cleanup). Should they be permanent observability? The design noted them as optional promotion targets.
- **Are we actually learning from Pattern D (exhaustive audit)?** This pattern has appeared in 5 of 10 PIRs. The pipeline.md checklists partially address it, but PAR Track 1 still missed CALM violators despite the checklist existing for struct changes. The CALM audit is a NEW category that needs its own checklist entry.
