# BSP-LE Track 2 D.2 — External Critique

**Date**: 2026-04-08
**Design**: [D.2](2026-04-07_BSP_LE_TRACK2_DESIGN.md) (1142 lines, post self-critique)
**Self-critique**: [P/R/M Analysis](2026-04-07_BSP_LE_TRACK2_SELF_CRITIQUE.md) (17 findings, all incorporated)
**Stage 1/2**: [Research + Audit](../research/2026-04-07_BSP_LE_TRACK2_STAGE1_AUDIT.md)
**Methodology**: [CRITIQUE_METHODOLOGY.org](principles/CRITIQUE_METHODOLOGY.org)

---

## Critique Findings (16 total: 2 Critical, 8 Major, 5 Minor, 1 Observation)

### Critical

**1.1: Decision domain lattice orientation vs infrastructure conventions** (§2.5a, §3.1)
The DecisionDomain uses reverse-ordered powerset (bot=full, top=empty, merge=intersection). This flips the standard lattice orientation. BSP's `bulk-merge-writes` and contradiction detection assume upward information flow. The existing `constraint-cell.rkt` already handles this exact pattern — the design should explicitly state it uses that convention.

**4.1: Filtered watcher cannot check "other assumptions committed"** (§2.5c, §3.3)
The `filtered-nogood-decision-watcher` NTT model checks `other-assumptions-committed?` — but its declared inputs are only `[nogoods]`. It can't read other groups' decision cells without declaring them as inputs. Without this, the watcher can't determine if a nogood is relevant (the other assumptions must be committed for narrowing to apply). Suggests per-nogood propagators (one per nogood, fan-in = |nogood|, typically 2-3).

### Major

**1.2: Consistency fan-in is a hidden global aggregation** (§2.6b, §3.3)
The `consistency-fan-in` propagator reads ALL decision cells — exactly the centralized worldview the design claims to eliminate. Fires on every decision cell narrowing. Suggests: remove the global consistency cell, use per-decision contradiction detection (already exists in Phase 3) as the consistency mechanism.

**1.3: Decision cells per-group vs per-branch ambiguity** (§2.5a, §2.6b)
"Decision cell" used in two senses: (a) per-amb-GROUP (shared, narrows) and (b) per-BRANCH (committed singleton). These are different. Suggests: make two-level structure explicit — one group-level cell on outer network, branch PUs read it but don't have their own "decision cell."

**3.1: Parallel-map accumulator merge under BSP** (§3.3, Phase 1)
N parallel-map propagators all writing to same accumulator in one superstep. Set-union is correct (ACI) but design should explicitly verify `bulk-merge-writes` handles multi-write-per-superstep.

**3.2: Parallel-map match-result monotonicity under arg refinement** (§3.3, Phase 6)
Set-union accumulation means match results only grow. But if arg cells are refined, previously-matching clauses might no longer match. Accumulator becomes stale. Suggests: precondition that arg cells must be stable (resolved) before parallel-map fires.

**5.1: Tropical solver bootstrapping** (§2.6e)
Self-referential solver: the outer solver is in a contradicted state, but the diagnostic solver uses the same infrastructure. If on the same network, diagnostic cells interact with outer nogood watchers. Must run on a SEPARATE fresh network. "Self-referential" is in the code (same functions), not the network (same cells).

**6.1: Five-phase dual-path for speculation migration** (Phase 4)
Phases 4-9 run with BOTH `current-speculation-stack` AND decision cells active. This is "Validated Is Not Deployed." Suggests: migrate and remove parameter in the same phase. Tier 1 with empty decision context = equivalent to `'()` stack.

**6.3: NAF inner-result cell scope under PU drops** (Phase 7, §3.3)
If NAF's inner goal is in a PU that gets dropped, the NAF propagator at S1 reads a nonexistent cell. Inner-result cell must be on the NAF's own network scope (outer), not inside any sub-PU.

**6.4: Tabling completion conflates network and table quiescence** (Phase 8)
"Table complete when accumulator quiesced" conflates with whole-network quiescence. A table might quiesce while other propagators are still active. Suggests per-table completion tracking.

### Minor

**2.2: `atms-consistent?` call sites need audit** (§2.6d) — synchronous callers must be restructured as propagator reactions.

**2.3: Counter cell max-merge under concurrent assumption creation** (§2.6a) — two concurrent creates produce same ID. Fix: assumption creation at topology stratum (already sequential).

**4.2: Scale analysis overstated** (§2.5c) — actual cost is O(|nogood|) per new nogood with per-nogood propagators, not O(decisions × |nogood|).

**5.2: Tropical cost deduplication** (§2.6e) — cost must count UNIQUE retractions via set-accumulator, not sum per-nogood counts.

**6.2: Duplicate NTT correspondence table** (§3.4/§3.8) — D.1 table not removed.

**6.5: Stratification barrier vs exchange inconsistency** (§3.6/§3.7) — barrier is unidirectional, exchange is bidirectional. Pick one.

### Observation

**2.1: Solver context IS correctly distinct from ATMS struct** — addresses hold cell-IDs (immutable metadata), not values (mutable state). Confirmed correct.

---

## Response (Grounded Pushback per CRITIQUE_METHODOLOGY.org §5)

### Critical Findings

**1.1 — Accept problem, accept solution.**
The critic is correct. The design uses reverse-ordered powerset but doesn't explicitly connect it to `constraint-cell.rkt`. Our codebase already has this exact pattern — the constraint domain lattice from Track 4B uses powerset under intersection with bot=unconstrained, top=empty. The resolution is to state that `DecisionDomain` follows `constraint-cell.rkt` conventions and verify merge compatibility with `bulk-merge-writes`. This is a documentation + verification issue, not an architectural one.

**4.1 — Accept problem, accept solution (Approach A).**
This is a genuine gap. The filtered watcher as designed can't check if other groups' assumptions are committed without reading their cells. The per-nogood propagator approach (Approach A) is the right fix: one propagator per nogood, fan-in = |nogood| (typically 2-3), fires only when its specific nogood becomes relevant. This is actually MORE aligned with propagator-mindspace — each nogood is its own information-flow unit, not a datum processed by a per-group scanner.

This replaces the per-decision watcher with per-nogood propagators. The watcher count changes from O(decisions) to O(nogoods), but each watcher has smaller fan-in and fires more precisely.

### Major Findings

**1.2 — Accept problem, accept solution.**
The consistency fan-in IS a hidden aggregation. The critic's resolution is correct: remove the global `consistent` cell, rely on per-decision contradiction detection (Phase 3) as the consistency mechanism. A branch is contradicted when ANY of its decision cells is empty — the contradiction detector already handles this. No global aggregation needed.

**1.3 — Accept problem, accept solution.**
The ambiguity is real. Resolution: ONE group-level decision cell on the outer network per `atms-amb`. Branch PUs don't have their own decision cells — they have a committed assumption that is either in the group's domain (alive) or not (pruned). The filtered per-nogood watcher narrows the GROUP cell. Clean.

**3.1 — Accept, note for implementation.**
Set-union IS ACI. `bulk-merge-writes` handles this correctly by design. But the explicit multi-write-per-superstep test is a good implementation-phase gate. No design change, but add to Phase 1 test coverage.

**3.2 — Accept problem, refine solution.**
The critic correctly identifies that set-union accumulation is non-monotone under arg refinement. But in our solver, arg cells ARE resolved once: the query's arguments are elaborated before the solver runs, and solver variables are cells that only gain information (never lose it). The precondition (args stable before parallel-map fires) is inherent in our architecture. But we should state it explicitly — and the readiness guard (fire only when all args are non-bot) should be in the design.

**5.1 — Accept problem, accept solution.**
The bootstrapping concern is valid. The diagnostic solver MUST run on a fresh network. The self-referential nature is in the code (same functions), not the network (same cells). This is operationally a nested solver invocation with the nogoods as data input. The design's framing was poetically misleading.

**6.1 — Accept problem, partially accept solution.**
The "Validated Is Not Deployed" criticism is valid per our own principles. However, we push back on "remove the parameter in Phase 4" — Phase 4 migrates the CONSUMERS, but the Tier 1→2 topology-stratum transition (Phase 9) is what makes decision cells the PRIMARY mechanism. The parameter can be removed immediately after Phase 9, not after a five-phase gap. Compress: Phase 4 migrates consumers to support both paths. Phase 9 establishes decision cells. Phase 9 sub-phase removes parameter. That's 4→9→remove, not 4→...→cleanup-someday.

**6.3 — Accept problem, accept solution.**
The NAF inner-result cell must be on the outer scope. Inner goal propagators write to it via cross-PU bridges (same as answer accumulator pattern). PU drops don't affect the cell. This is the correct resolution.

**6.4 — Accept problem, refine solution.**
The critic is right that whole-network quiescence ≠ per-table quiescence. But for non-recursive tabling (Track 2 scope), the condition is simpler: all producer propagators for the tabled relation have fired. This is a per-producer completion check, not a network-wide check. Add: table completion = all producers fired + no new answers in the last round. Per-table, not per-network.

### Minor Findings

**2.2** — Accept. Audit call sites in Phase 5 implementation. Retain `atms-consistent?` as synchronous query function for off-network use.

**2.3** — Accept. Assumption creation at topology stratum (already sequential). Document explicitly.

**4.2** — Accept. Correct the scale analysis: O(|nogood|) per new nogood with per-nogood propagators, not O(decisions × |nogood|).

**5.2** — Accept. Cost accumulator uses set-union on assumptions (deduplicates), cardinality for tropical cost. Not integer addition.

**6.2** — Accept. Remove duplicate table.

**6.5** — Accept. Use exchange model consistently (bidirectional). The fixpoint cycle (S0 → S(-1) → S0) is implicit in `:fixpoint :lfp` but should be explicit.
