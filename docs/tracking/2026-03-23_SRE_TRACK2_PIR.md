# SRE Track 2: Elaborator-on-SRE — Post-Implementation Review

**Date**: 2026-03-23 through 2026-03-24
**Duration**: ~4h (design: ~2.5h across 4 iterations; implementation: ~1.5h)
**Commits**: 6 (from `f97c9a9` Phase 0 through `c574889` tracker update)
**Test delta**: 7401 → 7401 (+0 new tests — migration, not new feature)
**Code delta**: ~85 lines added across 3 files (syntax.rkt, sessions.rkt, unify.rkt, ctor-registry.rkt)
**Suite health**: 7401 tests, 382 files, 234.6-241.5s (avg ~238s), all pass
**Design docs**: [Track 2 Design](2026-03-23_SRE_TRACK2_ELABORATOR_ON_SRE_DESIGN.md) (D.1→D.4: initial + benchmarks + external critique + e2e)
**Prior art**: [SRE Track 0 PIR](2026-03-22_SRE_TRACK0_PIR.md), [SRE Track 1 PIR](2026-03-23_SRE_TRACK1_PIR.md), [PM Track 8 PIR](2026-03-22_TRACK8_PIR.md)
**Cross-references**: [SRE Master](2026-03-22_SRE_MASTER.md), [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md), [Unified Infrastructure Roadmap](2026-03-22_PM_UNIFIED_INFRASTRUCTURE_ROADMAP.md)

---

## 1. What Was Built

The unification classifier (`classify-whnf-problem` in unify.rkt) was migrated
from hardcoded pattern matching to SRE ctor-desc dispatch. All 10 structural
cases (Pi, Sigma, lam, app, Eq, Vec, Fin, pair, suc + all registered types)
now dispatch through the SRE's O(1) `prop:ctor-desc-tag` property rather than
a 37-case `cond` chain.

This is an INTERNAL migration — no user-facing behavior change. The elaborator
works exactly as before, but structural knowledge lives in data (ctor-desc
registry) rather than code (pattern match cases). New AST nodes require only
a `register-ctor!` call; the classifier needs no modification.

Additionally, `prop:ctor-desc-tag` — a struct-type property on 19 AST structs
— delivers O(1) constructor tag lookup, replacing the linear recognizer scan
that was 4-200× slower than struct predicates.

## 2. Timeline and Phases

| Phase | Commit | Description | Wall time |
|-------|--------|-------------|-----------|
| Pre-0 | (benchmark files) | Micro-benchmark: linear scan 4-200× slower. e2e: extraction 3ns overhead. | ~30min |
| 0 | `f97c9a9`, `01ca400` | `prop:ctor-desc-tag` on 19 structs. `ctor-tag-for-value` property-first. | ~30min |
| 1 | `4d4fb80` | Non-binder structural cases (app, Eq, Vec, Fin, pair) → SRE. Rollback toggle. | ~15min |
| 2+3 | `50e95ba` | Binder cases (Pi, Sigma, lam) → SRE. Meta handling verified. | ~15min |
| 4 | — | No-op: already delivered by Track 1B Phase 2d (`structural-subtype-ground?`) | 0min |
| 5 | `c574889` | Verification: 7401 tests, 234.6-241.5s. Progress tracker updated. | ~15min |

**Design-to-implementation ratio**: ~2.5h design : ~1.5h implementation = **1.7:1**.
This is consistent with SRE Track 0 (2:1) and confirms the pattern: thorough
design with benchmarking leads to fast, clean implementation.

## 3. Test Coverage

**No new tests added.** This is a pure migration — behavior is identical.
The existing 7401 tests serve as the correctness oracle. The rollback toggle
(`current-sre-classify-enabled?`) allows A/B verification: toggle OFF
exercises the hardcoded fallback, toggle ON exercises the SRE path. Both
produce identical classifications (verified via smoke tests and full suite).

**Gap**: No dedicated test for the SRE classifier path independent of
the full unification suite. A `test-sre-classify.rkt` with targeted
classification tests would improve regression detection. Not blocking.

## 4. Bugs Found and Fixed

**1. Over-aggressive `struct?` guard (Phase 0, `01ca400`).**
Added `[(struct? v) #f]` to short-circuit atom lookups. But extra-domain
test structs (test-pair, test-leaf from SRE Track 0's test suite) are
also Racket structs — the guard incorrectly returned `#f` for them,
bypassing the linear scan fallback. 4 test failures in test-sre-core.rkt.
Fix: removed the guard; non-property structs fall through to data + extra
domain scan. Performance cost: ~24ns (property check + struct? check +
data scan for type-domain atoms) vs theoretical ~8ns with guard. Acceptable.

**Root cause**: The guard assumed all non-property structs are type-domain
atoms. But the struct-type property is only on type-domain and session-domain
structs — extra domains (test, narrowing) don't have it and need the fallback.
This is the same class of error as Track 1B Phase 5's "wrong-side pre-populate":
an optimization that assumed one population (type-domain) but broke another
(extra domains).

## 5. Design Decisions and Rationale

**D1. O(1) dispatch via struct-type property (not frequency-sorted list).**
The benchmarks showed linear scan was the sole bottleneck (4-200× slower).
Four alternatives considered: (a) frequency-sorted list (still O(N) worst
case), (b) top-8 hardcoded + fallback (reintroduces hardcoded knowledge),
(c) jump table via struct-type descriptor (no public Racket API), (d)
struct-type property (O(1) vtable access). Only (d) satisfies all four
criteria: O(1) all cases, no hardcoding, data-oriented, complete. The
property carries `(cons domain-name tag)` for multi-domain disambiguation.

**D2. Rollback toggle (`current-sre-classify-enabled?`).**
Parallels `current-punify-enabled?`. Allows reverting to hardcoded classifier
without code revert. To be removed after PIR completion (this document).

**D3. Preserve current flex-app ordering.**
D.3 critique §7 flagged that `(app (meta ?F) arg)` could be misrouted
by SRE dispatch. Verified: the current classifier routes app-containing-meta
to `'sub` (structural decomposition), not `'flex-app`. The SRE dispatch
preserves this ordering because it checks same-tag before falling through
to flex-app. Current behavior = correct behavior.

**D4. Binder-depth filter for Phase 1, removed in Phase 2.**
Phase 1 filtered binder cases (`binder-depth > 0`) so the SRE only
handled non-binder structural cases. Phase 2 removed the filter and added
Pi-specific `'pi` tag and Sigma/lam `'binder` tag handling to
`sre-structural-classify`. Clean progression.

**D5. Polarity inference decoupled to Track 2B.**
External critique §6 correctly identified that polarity inference is a
new feature, not a migration. Separating it prevents coupling the
migration's completion criteria to new feature correctness.

**D6. Static dispatch vs dynamic reasoning boundary.**
The architectural insight that informed Phase 0: structural KNOWLEDGE
(form dispatch) is static configuration; structural REASONING (decomposition,
propagation) is dynamic computation on-network. This parallels NF-Narrowing's
definitional tree (static routing) vs narrowing computation (on-network).
The boundary is principled: provenance starts at decomposition, not dispatch.

## 6. What Went Well

**1. Benchmark-driven design iteration.** Pre-0 micro-benchmarks revealed
the linear scan bottleneck, changing the design from "might need optimization"
to "O(1) is a prerequisite." The e2e benchmark settled the extraction closure
concern (3ns overhead, not 20-40ns). Without benchmarking, we might have
built the classifier migration first and discovered the performance problem
after — a much more expensive fix.

**2. Tiny implementation for large architectural change.** ~85 lines across
4 files. The 37-case hardcoded classifier is superseded by ~30 lines of SRE
dispatch + 19 struct property annotations. The existing ctor-desc registry
(built in Track 0) carried all the structural knowledge; the classifier just
needed to read it.

**3. Performance improvement as a bonus.** Target was ≤0% regression. Actual:
~2.5% improvement (244.1s → ~238s). The O(1) property dispatch is faster than
the cond chain for ALL cases, including atoms and identical-value fast paths.

**4. Four design iterations caught real issues.** D.2 (benchmarks) changed the
architecture. D.3 (external critique) caught multi-domain tags, flex-app
ordering, and identified polarity inference coupling. D.4 (e2e benchmarks)
settled extraction cost. Each iteration improved the design substantively.

## 7. What Went Wrong

**1. Phase 0 `struct?` guard — premature optimization.** Added and immediately
had to remove a `struct?` short-circuit that broke extra-domain lookups. The
guard was added without checking all ctor-desc domains — type + session
structs have the property, but test + narrowing domain structs don't. Total
time lost: ~10 minutes. The lesson is minor but consistent with Track 1B
Phase 5: optimizations that assume one population break others.

**2. First test run showed phantom 5% regression (256s vs 244s).** This was
entirely compilation overhead from the syntax.rkt change — not a real
regression. The second run showed 234.6s (improvement). We should have
separated compilation from test timing. **New workflow rule added**: compile
separately before measuring suite wall time.

## 8. Where We Got Lucky

**1. Phase 4 was already done.** Track 1B Phase 2d already wired
`structural-subtype-ground?` into `subtype?`, which the conversion fallback
calls. What was designed as a Phase 4 deliverable required zero work. This
was fortunate alignment — we didn't plan Track 1B's scope with Track 2's
phases in mind.

**2. The e2e benchmark disproved the critique's main concern.** The D.3
critique's strongest point was "extraction closure overhead of 20-40ns."
The actual overhead was 0-3ns. If it had been 40ns, the SRE path would
have been slower for Pi-vs-Pi (the hottest case), requiring a redesign.

## 9. What Surprised Us

**1. The elaborator is already store-agnostic.** The initial assumption was
that Track 2 would need to modify typing-core.rkt (158 cases). The audit
revealed: 0 cases install propagators, 40+ delegate to `unify`. The
migration target was `unify.rkt`'s 37-case classifier, not typing-core.
This dramatically reduced scope and risk.

**2. Three cases were FASTER without O(1) dispatch.** The identical (0.57×),
meta (0.28×), and flex-app (0.25×) cases benefited purely from the SRE
path's cleaner ordering (fewer cond branches before the relevant check).
This was a free bonus from the migration itself.

**3. The migration was ~85 lines.** For an "Elaborator-on-SRE" track that
was expected to be high-risk and touch ~3000 lines of typing-core.rkt,
the actual implementation was minimal. The SRE infrastructure (Tracks 0+1)
carried all the weight; Track 2 was the thin wiring layer.

## 10. How Did the Architecture Hold Up?

The SRE architecture proved correct under full elaboration load. All 10
structural cases delegate to the same `sre-structural-classify` function,
which uses the same ctor-desc registry and extract functions that PUnify
uses for cell-tree decomposition. The two-layer architecture (SRE for
within-domain dispatch, Galois bridges for cross-domain) remains clean.

The `prop:ctor-desc-tag` struct-type property integrates cleanly with
Racket's struct system — no interference with `#:transparent`, pattern
matching, or serialization. The property is additive and invisible to
code that doesn't use it.

The rollback toggle (`current-sre-classify-enabled?`) confirms that the
hardcoded classifier and SRE dispatch produce identical results for all
7401 tests. The toggle can be removed.

## 11. What This Enables

- **SRE Track 2B (Polarity Inference)**: User-defined types get automatic
  structural subtyping via variance inference from type definitions.
- **SRE Track 3 (Trait Resolution-on-SRE)**: The SRE is proven under full
  elaboration load. Trait resolution can use the same dispatch.
- **PM 8F (Metas as Cells)**: The elaborator's meta handling is isolated
  to flex-rigid/flex-app cases. When metas become cells, only those change.
- **Zonk elimination**: PM 8F + SRE = zonk during elaboration disappears
  (cell reads replace substitution walks). ~1100 lines of zonk.rkt → ~200
  lines of freeze.rkt. This is the major code elimination milestone.

## 12. Technical Debt Accepted

- **Rollback toggle**: `current-sre-classify-enabled?` should be removed
  now that full verification is complete.
- **nat-val cross-representation cases**: Permanent exception — normalization
  + decomposition, not pure structural decomposition. Documented honestly.
  Track 6/PM 9 (reduction-on-SRE) scope.
- **Hardcoded fallback cases preserved**: The 37 hardcoded cases still exist
  as fallback for toggle OFF. They should be removed after toggle removal.
- **No dedicated SRE classifier tests**: The full suite validates behavior,
  but targeted classification tests would improve regression detection.

## 13. What Would We Do Differently?

**1. Benchmark BEFORE writing the initial design.** The Pre-0 benchmarks
changed the design fundamentally (adding Phase 0 for O(1) dispatch). If
we'd benchmarked first, D.1 would have included O(1) dispatch from the
start, saving one design iteration. This pattern recurs: SRE Track 1B
also discovered that benchmarking changes the approach.

**2. Separate compilation from test timing from the start.** The phantom
256s regression cost confusion time. A workflow rule now prevents this.

## 14. What Assumptions Were Wrong?

**1. "The elaborator installs propagators manually."** False. The elaborator
calls `unify`, which goes through PUnify/SRE. The migration target was the
unification classifier, not typing-core. This wrong assumption inflated the
perceived scope from "modify 158 infer/check cases" to "modify 1 function
in unify.rkt." The assumption came from the SRE Research Doc's "elaborator
becomes thin walker using structural-relate" framing — which is the VISION
but not the current architecture's reality.

**2. "Extraction closures would be 20-40ns overhead."** The D.3 external
critique's main concern. Actual: 0-3ns. Racket optimizes closures well.

**3. "Phase 4 (subtype fallback) would require work."** Already delivered
by Track 1B Phase 2d. Fortunate alignment, not planned.

## 15. What Did We Learn About the Problem?

**Structural dispatch is the thin layer, not the thick one.** The hardcoded
classifier had 37 cases and looked complex. But structurally, it does one
simple thing: determine which ctor-desc applies, then extract components.
The SRE replaces all 37 cases with one O(1) dispatch + one generic extract.
The complexity was in the ACCUMULATION of cases, not in any individual case's
logic.

This validates the SRE thesis: structural knowledge is DATA (ctor-descs),
not CODE (match patterns). Replacing code with data reduces complexity
even when the code was "working fine."

## 16. Is This Part of a Pattern?

**Yes: "Benchmark before building" is now a confirmed pattern (3 instances).**

| Track | What benchmarking revealed | Design change |
|-------|---------------------------|---------------|
| BSP-LE Track 0 | Transient CHAMP slower at N=2-3 | Reverted Phase 5 (later rehabilitated by CHAMP Performance) |
| SRE Track 1B | Cold-start allocation, not computation | Eliminated mini-network entirely for ground types |
| SRE Track 2 | Linear scan sole bottleneck; extraction fine | Added Phase 0 (O(1) dispatch) as prerequisite |

All three instances: the pre-implementation benchmark changed the design
fundamentally. This pattern is now codified in DESIGN_METHODOLOGY.org
§ Stage 3 ("Benchmark as design input").

**"Design:implementation ratio predicts smoothness" continues (24th data point).**
Track 2: 1.7:1 ratio, 1 bug (minor: struct? guard). Consistent with
SRE Track 0 (2:1, 0 bugs) and Track 8 Part A (0.5:1, ghost-meta bugs).

**"Data-oriented code extracts/migrates cleanly" confirmed (3rd instance).**
PUnify→SRE Track 0 was mechanical. Track 1 relation parameterization was
clean. Track 2 classifier→SRE was 85 lines. All three: the ctor-desc
registry carried the structural knowledge; migration was wiring, not rewriting.

## 17. Metrics

| Metric | Baseline | Final | Delta |
|--------|----------|-------|-------|
| Test count | 7401 | 7401 | +0 (migration) |
| Suite wall time | 244.1s | ~238s (avg) | **-2.5%** (improvement) |
| Commits | — | 6 | |
| Lines added | — | ~85 | |
| Files modified | — | 4 | syntax.rkt, sessions.rkt, ctor-registry.rkt, unify.rkt |
| Design iterations | — | 4 (D.1→D.4) | |
| Bugs | — | 1 (struct? guard) | |
| Design:impl ratio | — | 1.7:1 | |
| ctor-tag-for-value (Pi) | 357 ns | 34 ns | **10.5× faster** |
| ctor-tag-for-value (atom) | 825 ns | ~72 ns | **11.5× faster** |
| Structural cases via SRE | 0/10 | 10/10 | **100%** |
| Hardcoded structural cases | 10 | 0 (active); 10 (fallback) | |

## 18. Key Files

| File | Role |
|------|------|
| `syntax.rkt` | `prop:ctor-desc-tag` property definition + 12 type-domain struct annotations |
| `sessions.rkt` | 7 session-domain struct annotations |
| `ctor-registry.rkt` | `ctor-tag-for-value` updated: property-first + fallback |
| `unify.rkt` | `sre-structural-classify`, `current-sre-classify-enabled?`, `classify-whnf-problem` updated |
| `benchmarks/micro/bench-classify-vs-sre.rkt` | Pre-0 tag lookup micro-benchmark |
| `benchmarks/micro/bench-classify-e2e.rkt` | D.4 end-to-end classifier benchmark |

## 19. Lessons Distilled

| Lesson | Target Document | Status |
|--------|----------------|--------|
| "Benchmark before building" (3rd instance, confirmed) | DESIGN_METHODOLOGY.org § Stage 3 | Done (`eca77b4`) |
| "Separate compile from test timing" | testing.md | Done (this session) |
| "Store-agnostic elaborator — migration target is unify, not typing-core" | — | Note in SRE Master for future track scoping |
| "Data-oriented code migrates cleanly" (3rd instance) | DEVELOPMENT_LESSONS.org | Pending — needs codification |
