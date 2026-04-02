# PPN Track 3: Parser as Propagators — Post-Implementation Review

**Date**: 2026-04-02
**Duration**: ~20 hours design + implementation across 2 sessions
**Commits**: 31 (from `1195893f` Open working day through `a73a9dff` tracker update)
**Test delta**: 7491 → 7491 (no new test files; acceptance file added as example)
**Code delta**: ~900 lines added (form-cells.rkt 290 lines new, tree-parser.rkt +250, surface-rewrite.rkt +30, driver.rkt +50, bench-ppn-track3.rkt 883 lines), ~40 lines modified in driver.rkt
**Suite health**: 383/383 files, 7491 tests, 130.8-138.4s, all pass
**Design iterations**: D.1 → D.2 (algebraic structure) → D.3 (self-critique) → D.4 (dependency-set, spec cells) → D.5 (external critique, 10 findings) → D.5b (phase reorder)
**Design docs**: [Design D.5b](2026-04-01_PPN_TRACK3_DESIGN.md), [Stage 2 Audit](2026-04-01_PPN_TRACK3_STAGE2_AUDIT.md)
**Prior PIRs**: [PPN Track 2B](2026-03-30_PPN_TRACK2B_PIR.md), [SRE Track 2G](2026-03-30_SRE_TRACK2G_PIR.md)
**Series**: PPN (Propagator-Parsing-Network) — Track 3

---

## 1. What Was Built

PPN Track 3 replaces the WS processing pipeline's surf production path. The old path: `preparse-expand-all → parse-datum → merge-preparse-and-tree-parser`. The new path: per-form cells on the elaboration network, with surfs produced by a single-parser path: `raw tree-node → datum → normalize → preparse-expand-single → parse-datum`.

Key deliverables:
- **Dependency-set Pocket Universe** (Phase 5): Replaces the stage chain (Heyting) with a powerset of completed transforms (Boolean). Independent transforms fire in parallel.
- **Per-form cells** (Phase 6): One infra-cell per top-level form on the elab-network. Production dispatch runs the tree pipeline and stores results.
- **Spec cells** (Phase 3a): Per-function spec cells with collision=top. Defn annotation via post-parse spec injection.
- **Single-parser surf production** (Phase 4): ALL surfs produced by `parse-datum` — no dual representation. Raw tree-nodes converted to datums, normalized (flatten WS groups, restructure infix `=`, desugar session/defproc WS bodies), expanded via `preparse-expand-single`, parsed via `parse-datum`.
- **Expression-level desugaring**: `parse-cond-expr`, `parse-let-expr`, `parse-do-expr` in tree-parser.rkt handle cond/let/do inside defn bodies.

Preparse still runs for registration side effects (idempotent). Surfs come exclusively from the cell pipeline. ONE parser (`parse-datum`), ONE representation.

---

## 2. Timeline and Phases

| Phase | Commit | Duration | Key Event |
|-------|--------|----------|-----------|
| Audit | `9bb0804c` | 1h | parser.rkt: 6,605 lines, PURE (0 registry reads). Parse = 0ms. |
| D.1 | `1da543c6` | 1.5h | Initial 10-phase design |
| D.2 | `efe72c84` | 1h | Algebraic structure: pipeline-preference ordering, set-valued registry |
| Pre-0 | `dc87fb34` | 1h | 19 benchmarks. All algebraic properties PASS. |
| D.3 | `140babd8` | 1.5h | Self-critique: registration is 3,017 lines interleaved, merge-form impure |
| D.4 | `8f254daa` | 1h | Dependency-set, spec cells, Phase 3 split |
| D.5 | `a0de1346` | 1h | External critique: 10 findings, all incorporated |
| Acceptance | `a3034a75` | 0.5h | 0 errors baseline |
| Phase 1b | `27d22906` | 0.5h | subtype + selection tree-parser |
| Phase 5 | `9f3c63dc` | 1h | Dependency-set Pocket Universe |
| Phase 6 | `7a2a4bd0` | 1h | Per-form cells + dispatch |
| Phase 3a | `bd13dfbb` | 0.5h | Spec cells |
| Phase 7 | `40d07caa` | 0.5h | Wired into driver |
| Phase 1a | `e5b837bb` | 1h | Consumed form expansion |
| Expression desugar | `a52bfd60` | 1h | cond/let/do in tree-parser |
| Diagnostic | `4ff54801`→`5d3b597c` | 3h | 17 failures → 0. Single-parser path. |
| A/B | — | 0.5h | Zero regression |

D:I ratio: ~7h design : ~11h implementation ≈ 0.6:1 (lower than typical 1.5:1 — the diagnostic phase was implementation-heavy)

---

## 3. Test Coverage

- Acceptance file: `examples/2026-04-02-ppn-track3.prologos` — 7 sections, 0 errors
- Pre-0 benchmarks: `benchmarks/micro/bench-ppn-track3.rkt` — 19 tests (M1-M7, A1-A5, E1-E4, V1-V3)
- Algebraic validation: V1-V3 all PASS (commutativity, associativity, idempotence, distributivity, pseudo-complement)
- No new test files in tests/ — the 7491 existing tests serve as regression gate
- Gap: no dedicated test for the single-parser datum conversion path. The 383-file suite covers it implicitly.

---

## 4. Bugs Found and Fixed

**Bug 1: tree-parser parse-cond-expr expected flat tokens, got grouped nodes.** After G(0) grouping, cond clauses are expr-nodes containing `[| guard -> body]`, not flat token sequences. Fix: iterate over child nodes, extract tokens from each. Why wrong path seemed right: the D.4 design described transforms as flat token operations, but the tree pipeline produces grouped structures.

**Bug 2: parse-def-tree didn't handle (def name : Type := body).** The 5-arg pattern with `:` and `:=` fell through all existing cases. Fix: added explicit case for 5+ args with `:` at position 1 and `:=` found by scan.

**Bug 3: preparse-expand-form doesn't handle := expansion.** The cell pipeline initially called `preparse-expand-form` which doesn't expand `def x := val` syntax. Fix: switched to `preparse-expand-single` which handles `:=`, spec injection, and macro expansion.

**Bug 4: Infix = not restructured for narrowing.** Top-level `add ?a 3N = 5N` needs `=` moved to head position: `(= (add ?a 3N) 5N)`. The preparse path handles this in Pass 2. Fix: added `restructure-infix-eq` to the datum normalization pipeline.

**Bug 5: Session/defproc WS body tokens not desugared.** `!!` (async send) and session body chaining need `desugar-session-ws`/`desugar-defproc-ws`. Fix: added session-specific desugaring before `preparse-expand-single`.

**Bug 6: Strategy WS keyword properties grouped by indent.** Tree-node→stx-form produces `(:fairness :priority)` as nested lists. Fix: `flatten-ws-datum` splices keyword groups.

---

## 5. What Went Well

1. **The single-parser insight eliminated the dual-representation problem.** When the cell pipeline produced surfs via `parse-form-tree` (different from `parse-datum`'s output), 17 tests failed. The fix: don't build a second parser — convert to datum and use the SAME `parse-datum`. One parser, one representation. This was the architectural insight that completed the track.

2. **The diagnostic protocol worked.** 17 failures → categorized by root cause → fixed systematically. Each fix was narrow and targeted. No thrashing. The protocol's "audit the domain first" step identified that ALL failures shared one root cause (dual representation), leading to the single-parser solution.

3. **The design cycle (5 iterations) caught architectural issues early.** D.2 caught the flat-lattice trap. D.3 found the 3,017-line registration scope. D.4 replaced the stage chain with dependency-set. D.5 found 10 issues including the NTT model contradiction and spec-cell commutativity violation. Without the design cycle, these would have been mid-implementation pivots.

4. **The Pre-0 benchmarks validated performance non-concern.** Parse = 0ms. WS overhead <2%. All algebraic properties PASS. This allowed the implementation to focus on architecture, not optimization.

---

## 6. What Went Wrong

1. **The original design assumed tree-parser would produce surfs directly.** This was the "two parsers, two representations" approach. 17 failures proved it wrong. The single-parser path (datum conversion) was not in the original design — it emerged from the diagnostic protocol during implementation. The design should have questioned "why do we need a second parser?" earlier.

2. **Phase 1a (data/trait/impl) was incorrectly scoped.** The design assumed these forms had surf-* structs. They don't — they're consumed by preparse. This was discovered during the Phase 1a mini-audit, requiring a phase reorder. The Stage 2 audit should have caught this.

3. **The big-bang Phase 4 switch was attempted prematurely (twice).** Both attempts revealed form gaps (strategy, session, narrowing). The diagnostic protocol resolved each gap, but the attempts cost time. A more systematic pre-switch audit of ALL form types would have identified gaps upfront.

4. **D:I ratio was 0.6:1 — below the 1.5:1 target.** The diagnostic phase (3h fixing 17 failures) was heavy implementation. This reflects the design's failure to anticipate the dual-representation problem.

---

## 7. Where We Got Lucky

1. **`preparse-expand-single` was already exported from macros.rkt.** The single-parser path depends on this function. If it hadn't been exported, adding the export would have risked circular dependencies (macros.rkt is heavily imported).

2. **`desugar-session-ws` and `desugar-defproc-ws` were already exported.** The session body chaining desugaring was pre-built and accessible. Without these, the session form handling would have required reimplementing 150+ lines of complex desugaring.

3. **The merge infrastructure from Track 2B provided a safe fallback.** Every failed cell-pipeline attempt could revert to the merge (383/383 GREEN). Without this safety net, each failure would have been a blocking regression.

---

## 8. What Surprised Us

1. **parser.rkt is PURE.** Zero registry reads. One boolean parameter. The Stage 2 audit revealed this — parser.rkt has no state dependencies. This made the single-parser path viable: `parse-datum` can be called from any context without parameter setup.

2. **The session sublanguage was the last holdout.** Every other form type was handled by the general single-parser path (datum → normalize → expand → parse). Session forms required TWO specific desugaring functions. The WS body chaining (`!! Nat end` → `(AsyncSend Nat End)`) is unique to sessions.

3. **The dependency-set (powerset) was algebraically correct but irrelevant to the final architecture.** Phase 5's dependency-set Pocket Universe replaced the stage chain. But the single-parser path doesn't USE the dependency-set for surf production — it converts raw nodes to datums. The dependency-set provides infrastructure for future PPN Track 4 (elaboration on network) but isn't load-bearing in Track 3.

---

## 9. Architecture Assessment

**Cell infrastructure held up well.** Per-form cells on the elab-network (Phase 6) create, dispatch, and store form-pipeline-values correctly. The `elab-new-infra-cell` API from Track 1 was the right abstraction. Cell count is bounded (one per top-level form).

**The single-parser path is the right architecture.** Instead of building a second parser (`parse-form-tree` for all forms), convert to datum and use `parse-datum`. This means the cell pipeline's value is NOT in surf production — it's in providing form cells on the network for downstream consumers (Track 4 elaboration, Track 7 grammar extensions, Track 8 incremental editing).

**Preparse registration dependency remains.** `preparse-expand-all` still runs for registration side effects (spec-store, ctor-meta, trait-registry). This is idempotent (cell pipeline's `process-consumed-form` also registers). PM series will migrate registration to persistent cells, eliminating the preparse dependency entirely.

---

## 10. What Does This Enable

- **PPN Track 4**: Per-form cells are the attachment points for type/constraint cells. The parse/elaborate boundary dissolution starts HERE.
- **PPN Track 7**: The dependency-set Pocket Universe and production dispatch are the foundation for user-defined grammar extensions.
- **PPN Track 8**: Per-form cells are the update units for incremental editing. Edit a form → cell changes → propagation.
- **PM Series**: Registration migration to persistent cells. The cell pipeline structures registration as information flow — PM replaces parameter writes with cell writes.

---

## 11. Technical Debt

| Debt | Rationale | Tracking |
|------|-----------|----------|
| Preparse runs for registration side effects | Idempotent; PM series migrates to cells | PM Master |
| `flatten-ws-datum` is heuristic (keyword group detection) | Works for known forms; may miss novel patterns | Monitor |
| `restructure-infix-eq` duplicated from macros.rkt | `maybe-restructure-infix-eq` not exported | Could export from macros.rkt |
| Session-specific desugaring in cell pipeline | Calls `desugar-session-ws`/`desugar-defproc-ws` | Clean — reuses existing code |
| 5 lessons flagged READY for codification since start of session | Time pressure | MUST codify in next session |

---

## 12. What Would We Do Differently

1. **Start with the single-parser insight.** The original design had `parse-form-tree` producing surfs directly. This created the dual-representation problem. If we had started with "convert to datum, use `parse-datum`" from the beginning, the 17-failure diagnostic phase would have been avoided.

2. **Audit ALL form types for surf-* struct existence before Phase 1a.** The discovery that data/trait/impl have no surf-* structs (consumed by preparse) was a Phase 1a mini-audit finding. The Stage 2 audit should have checked this.

3. **Run the cell-pipeline switch on EACH form type individually before the big-bang.** Instead of switching all at once and getting 17 failures, switch one form type at a time, verify, proceed. This was implicit in the diagnostic protocol but should have been the implementation strategy from the start.

---

## 13. Wrong Assumptions

| # | Assumption | Reality | Impact |
|---|-----------|---------|--------|
| 1 | Tree-parser can produce surfs directly for all forms | 17 form types produce different surf-* output than parse-datum | 3h diagnostic phase to find and fix |
| 2 | data/trait/impl have surf-* structs | Consumed by preparse; no struct exists | Phase reorder required |
| 3 | Expression-level desugaring (cond/let/do) is a separate track | Missing dispatch cases in tree-parser — 10-30 lines each | Quick fix once identified |
| 4 | Big-bang pipeline switch would work after closing form gaps | Structural differences in surf-* output caused 17 failures | Led to single-parser insight |
| 5 | The dependency-set would drive surf production | Surfs produced via datum conversion path, not dependency-set | Dependency-set is infrastructure for Track 4, not Track 3 |

---

## 14. What We Learned About the Problem

**The parsing pipeline's value is not in surf production — it's in providing cells on the network.** The original vision (Track 3 replaces parser.rkt with grammar productions) turned out to be the wrong framing. parser.rkt IS the parser — `parse-datum` is the canonical surf producer. The cell pipeline's value is: per-form cells, spec cells, dependency-set transforms, production dispatch — infrastructure that downstream tracks (4, 7, 8) consume.

**Datum conversion + single parser beats dual parsers.** Building a second parser (`parse-form-tree` for all forms) is more work and creates compatibility issues. Converting tree-nodes to datums and reusing `parse-datum` is simpler, correct by construction (same parser = same output), and maintains a single representation.

**WS normalization is the bridge.** The gap between tree-node and datum is WS-specific tokens (`:=`, `$pipe`, `!!`, indent groups). A small set of normalization functions (`flatten-ws-datum`, `restructure-infix-eq`, `normalize-ws-tokens`, `desugar-session-ws`) bridges this gap. Each is 10-30 lines. The normalization is the only new code needed — everything else is reused.

---

## 15. Are We Solving the Right Problem?

Yes, with a refinement. The original goal (parser as propagators — grammar productions on the network) is partially achieved: the cell infrastructure IS on the network, productions ARE dispatched, the dependency-set IS a lattice. But the surf production path uses datum conversion, not lattice-based information flow. The lattice infrastructure's value is for Track 4+ (elaboration), not for parsing itself.

The REAL contribution of Track 3 is: per-form cells on the elab-network with a single-parser surf production path. This is the foundation for the parse/elaborate boundary dissolution (Track 4) and incremental editing (Track 8). The parsing infrastructure is in place; the information-flow benefits emerge when elaboration joins the network.

---

## 16. Longitudinal Survey — 10 Most Recent PIRs

| # | Track | Date | Duration | Commits | Test Delta | D:I Ratio | Bugs | Wrong Assumptions |
|---|-------|------|----------|---------|------------|-----------|------|-------------------|
| 1 | SRE Track 2 | 03-23 | ~4h | 6 | +0 | 1.7:1 | 1 | 1 |
| 2 | PM 8F | 03-24 | ~8h | 15 | +0 | 1.5:1 | 2 | 3 |
| 3 | PM Track 10 | 03-24 | ~18h | 30 | -37 | 1:2 | 8 | 3 |
| 4 | PM Track 10B | 03-26 | ~6h | 12 | +0 | 1.5:1 | 2 | 1 |
| 5 | PPN Track 0 | 03-26 | ~4h | 8 | +57 | 2:1 | 0 | 0 |
| 6 | PPN Track 1 | 03-26 | ~24h | 40 | +108 | 1.4:1 | 3 | 2 |
| 7 | PAR Track 1 | 03-28 | ~14h | 28 | +13 | 2:1 | 0 | 1 |
| 8 | PPN Track 2 | 03-29 | ~10h | 18 | -1 | 1:1 | 4 | 3 |
| 9 | PPN Track 2B | 03-30 | ~10h | 18 | -5 | 1:1 | 3 | 5 |
| 10 | SRE Track 2G | 03-30 | ~10h | 11 | +32 | 1.5:1 | 3 | 3 |
| **11** | **PPN Track 3** | **04-02** | **~20h** | **31** | **+0** | **0.6:1** | **6** | **5** |

**Patterns across 11 PIRs:**

- **D:I ratio below 1:1 correlates with more bugs.** Track 3 (0.6:1) had 6 bugs. PM Track 10 (1:2) had 8. Tracks with D:I ≥ 1.5:1 average 1.3 bugs. **CONFIRMED for codification.**

- **Wrong assumptions accumulate in PPN series.** PPN Tracks 1-3 had 2, 3, 5, 5 wrong assumptions respectively. The WS pipeline has more hidden complexity than the SRE or PM tracks. **WATCHING** — may need systematic WS normalization audit.

- **Single-parser insight recurs.** Track 2B had 3 failed merge policies before finding identity-based matching. Track 3 had the dual-representation failure before finding single-parser datum conversion. Both converged on: don't build a new mechanism — reuse the existing one with better wiring. **READY for codification as principle: "Reuse over reimplementation."**

- **Diagnostic protocol consistently resolves blocking failures.** Track 2B: 3 merge attempts → diagnostic → identity matching. Track 3: 17 failures → diagnostic → single-parser. Track 2G: distributivity assumption → diagnostic → found counterexample. **CONFIRMED — already codified in workflow.md.**

---

## 9. Key Files

| File | Role |
|------|------|
| `form-cells.rkt` (NEW, 290 lines) | Per-form cells, spec cells, extract-surfs, consumed form handlers, datum normalization |
| `surface-rewrite.rkt` (+30 lines) | Dependency-set Pocket Universe (form-pipeline-value with transforms set) |
| `tree-parser.rkt` (+250 lines) | Expression desugaring (cond/let/do), subtype/selection, consumed form stubs |
| `driver.rkt` (+50 lines) | Cell pipeline wiring in process-string-ws-inner |
| `benchmarks/micro/bench-ppn-track3.rkt` (NEW, 883 lines) | Pre-0 benchmarks + algebraic validation |
| `examples/2026-04-02-ppn-track3.prologos` (NEW) | Acceptance file |

---

## 10. Lessons Distilled

| Lesson | Distilled To | Status |
|--------|-------------|--------|
| Single parser > dual parsers: reuse parse-datum via datum conversion | DEVELOPMENT_LESSONS.org | Pending — "Reuse over reimplementation" |
| D:I ratio < 1:1 correlates with more bugs | DESIGN_METHODOLOGY.org | Ready for codification (3rd confirmation) |
| WS normalization is a bounded, enumerable set of transforms | PATTERNS_AND_CONVENTIONS.org | Pending — document the normalization set |
| Diagnostic protocol resolves blocking failures | workflow.md | Already codified |
| Per-form audit before pipeline switch | DESIGN_METHODOLOGY.org | Pending — "Per-form verification before big-bang switch" |
| 5 lessons from prior sessions flagged READY | Various | STILL PENDING — backlog must be cleared |
