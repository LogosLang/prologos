# PM Track 10B — Post-Implementation Review

**Date**: 2026-03-26
**Duration**: ~8 hours across 1 session (March 25-26)
**Commits**: ~20 (from `aabb664` Pre-0 benchmarks through `47a4579` B7 verification)
**Test delta**: 7364 → 7364 (0 new tests — infrastructure track)
**Code delta**: ~100 lines added, ~30 removed (net +70). Session struct change, cell-id fast paths, tooling fixes.
**Suite health**: 376/376, 134.0s (≤134s target MET)
**Design docs**: [Design D.4](2026-03-25_PM_TRACK10B_DESIGN.md), [Stage 2 Audit](2026-03-25_PM_TRACK10B_STAGE2_AUDIT.md)

---

## 1. What Was Built

Track 10B was designed as the "foundation cleanup + zonk elimination" follow-on
to Track 10 (.pnet cache, 240s → 134s). Two workstreams: WS-A (architectural
cleanup) and WS-B (zonk elimination + scheduling).

**WS-A delivered**: Network-always architecture (every code path has a live
network), `freeze` rename signaling boundary operations, id-map external
callers eliminated, process-string scoping audit (no leaks), PUnify toggle
attempted (systemic regression, reverted). Tooling improvements: CWD-
independent scripts, dead-worker detection (30s vs 600s), stale .zo warning,
summary file, processor-count-based worker allocation, transitive .pnet
staleness.

**WS-B delivered partially**: Session meta cell-id infrastructure (B1a-d
complete). Session metas now carry cell-id, reads use fast path, speculation
and defaults verified.

**WS-B deferred**: Zonk elimination (55 sites) blocked on SRE Track 2C
(elaborator creates cell references, not expr-meta nodes). Per-test scheduling
deferred to PM Track 10C (Places infrastructure). Batch worker simplification
deferred (needs registries as cells).

## 2. Timeline and Phases

| Phase | Commit | Wall time | Key result |
|-------|--------|-----------|------------|
| A0 | `aabb664` | — | Pre-0 benchmarks: zonk-at-depth 350×, make-prop-network 11ns |
| A0b | `8e1495f` | ~30m | Acceptance file: 25 sections, 87/143 successes |
| A1 | `a767b50` | ~45m | Network-always: make-elaboration-network in with-fresh-meta-env. 135.5s |
| A2 | `d12eacf` | ~15m | freeze rename (15 sites). Cosmetic. |
| A3 | `cd0d708` | ~30m | id-map: 3 external callers → cell-id. hasmethod struct fix. 139.0s |
| A3b | `65a1f73` | ~20m | Scoping audit: 89 set-box! sites, NO LEAKS. |
| A4 | — | 5m | DEFERRED: batch worker needs registries as cells |
| A5 | `b904e76` | ~15m | PUnify toggle: systemic regression, reverted |
| A6-A7 | `86368ae` | ~15m | Benchmarks (no perf change) + verification. WS-A COMPLETE. |
| B0 | `9657f27` | ~15m | Zonk call counts: 14 per poly command (4.2ms). |
| B1a | `d966cdd` | ~30m | sess-meta cell-id + pattern updates (4 files, 7 test sites) |
| B1b | `92240cc` | ~15m | sess-meta-solution/cell-id fast path |
| B1c-d | `96b682e` | ~10m | Speculation + defaults verified (no code changes) |
| B2-B3 | `74183a6` | ~15m | BLOCKED: zonk elimination needs elaborator change (SRE 2C) |
| B4 | — | 5m | DEFERRED: file splitting marginal (largest=20.8s). Places needed. |
| B5-B7 | `47a4579` | ~10m | Benchmarks, cleanup, verification |
| Tooling | Various | ~60m | CWD fix, dead-worker, summary file, processor-count, .zo warning |
| Process | Various | ~30m | Dailies protocol, diagnostic protocol, phase completion protocol |

**Design-to-implementation ratio**: D.1→D.4 (4 iterations, ~3 hours) : implementation (~5 hours) = 3:5. More design iteration than previous tracks due to external critique integration.

## 3. Test Coverage

No new test files. Infrastructure track — all 376 existing test files served as the correctness oracle. Acceptance file (25 sections) exercises language features that depend on meta-variable resolution.

**Gaps**: No dedicated tests for: network-always behavior, cell-id fast path for session metas, or freeze vs zonk-final equivalence. These are implicitly tested by the full suite but would benefit from targeted tests.

## 4. Bugs Found and Fixed

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| A1: test-unify-cell-driven failure | `make-prop-network` creates raw prop-network; `process-command` expects elab-network in box | Use `make-elaboration-network` in `with-fresh-meta-env` |
| A3: test-infra-cell-constraint arity | `hasmethod-constraint-info` struct gained 5th field; test constructed with 4 | Add `#f` to test constructors |
| A3: 0 tests/600s silent crash | Stale .zo after struct field change; batch workers crash silently | Dead-worker detection (30s first-result timeout) |
| A5: PUnify systemic regression | PUnify toggle ON causes cascading failures in prelude loading | Reverted; needs dedicated SRE track |
| B1a: sess-meta pattern matches | `sess-meta` gained cell-id field; 1-arg patterns broke | Update patterns to 2-arg across 4 files |
| Tooling: CWD sensitivity | Runner's project-root relative to CWD, not script location | Set `current-directory` to project-root at startup |
| Tooling: processor-count unbound | `processor-count` needs `racket/future` require | Add `(only-in racket/future processor-count)` |
| Tooling: completed-count undefined | Referenced before definition in bail handler | Use loop counter `count` instead |

## 5. Design Decisions and Rationale

1. **Network-always via make-elaboration-network** (not make-prop-network): process-command wraps the network in elab-network. The box must start with elab-network to match expectations. Principle: Correct-by-Construction (the type in the box matches what consumers expect).

2. **freeze = zonk-final (cosmetic rename)**: True freeze (single-pass cell read) requires SRE Track 2C. Current freeze is still zonk + defaults. The rename signals INTENT (boundary operation), not MECHANISM (still tree-walking). Principle: Progressive Disclosure (name communicates the target architecture).

3. **PUnify revert after systemic regression**: The 5 "known parity bugs" are actually systemic — cascading failures in prelude module loading. A dedicated SRE track with its own design cycle is appropriate. Principle: Completeness (don't half-attempt what needs full investigation).

4. **B2 DEFERRED to SRE Track 2C**: Zonk does SUBSTITUTION (walking expression trees, replacing expr-meta with solutions). Cell reads give you the VALUE but don't put it INTO the tree. Eliminating substitution requires eliminating the NEED for substitution — changing how the elaborator constructs expressions. Principle: Completeness (solve at the right level of abstraction).

5. **Phase completion protocol (4 steps)**: Commit → tracker → dailies → move on. Dailies updates were consistently deferred; making them part of the phase definition prevents this.

## 6. Lessons Learned

### What Went Well

1. **Pre-0 benchmarks validated the design without changing it.** The data confirmed: WS-A is architectural, WS-B is performance. No redesign needed.

2. **The diagnostic protocol (workflow rule) worked on first application.** B1a's stale .zo was detected by dead-worker detection in 30s (not 600s).

3. **D.3 self-critique found real code issues.** `hasmethod-constraint-info` bare meta ID (line 625) and `(not (current-prop-net-box))` sentinels — both confirmed by grep.

### What Went Wrong

1. **B2 scoped wrong.** "Replace 55 zonk calls with cell reads" sounded mechanical. But zonk does substitution, not reading — fundamentally different. The scope should have been: "analyze what zonk does and whether cell reads can replace it." The audit would have found: no, not without changing expression construction.

2. **Phase A1 forgot the elab-network distinction.** The design said "create make-prop-network" but process-command expects elab-network. This was caught by tests (not design). The design should have specified: what TYPE does the box expect?

3. **Batch worker simplification overestimated.** 11→4 values claimed. Actual: 11→6 at best, AND the macros snapshot (19 params) can't be forked because they're Racket parameters, not network cells. The fork model's isolation boundary is the NETWORK — Racket parameters are outside it.

### What Surprised Us

1. **Session metas were ALREADY partially on-network.** Track 4 Phase 3 added cell allocation. The B1 "migration" was really just adding cell-id to the struct and making reads use it. The infrastructure was further along than the audit suggested.

2. **The acceptance file found 6 syntax gaps** (char literals, cond WS, let/do binding, :where on user specs, `>` in identifiers, list-of-maps). These are language gaps unrelated to Track 10B but valuable future work items.

3. **test-stdlib was already split.** The B4 file-splitting plan assumed test-stdlib was 285 tests / 132s. It's been split into multiple files; the current largest is 20.8s (test-reducible, 26 tests). Diminishing returns.

## 7. Metrics

| Metric | Before Track 10B | After Track 10B | Change |
|--------|-----------------|----------------|--------|
| Suite wall time | 133.5s | 134.0s | ≤134s target MET |
| CHAMP fallback sites | 36 | 36 (removal deferred) | Sentinel checks removed |
| id-map external callers | 3 | 0 | -3 (internal only) |
| sess-meta cell-id | #f | populated | Infrastructure ready |
| Dead-worker detection | 600s | 30s | 20× faster feedback |
| PUnify toggle | untested | TESTED (systemic regression) | Data acquired |
| Acceptance file | n/a | 87/143 successes | 6 syntax gaps found |
| Wrong assumptions in design | 5 (D.1) | 0 (D.4) | All corrected by data |

## 8. What's Next

**Immediate**:
- PM Track 10C: Per-test scheduling via Places (own design cycle)
- SRE Track 2C: Cell references in expressions (enables zonk elimination)
- SRE Track PUnify: Systemic parity investigation

**Medium-term**:
- PRN (Propagator-Rewriting-Network): Hypergraph rewriting as the unifying substrate for SRE, parsing, reduction, and zonk elimination
- SRE Track 2B: Polarity inference (user-defined structural subtyping)
- SRE Track 3: Trait resolution on SRE

**Long-term**:
- Self-describing serialization (PPN/PRN Track 0): Grammar-based .pnet format
- Self-hosting compiler via NTT-typed PRN

## 9. Key Files

| File | Role in Track 10B |
|------|------------------|
| `metavar-store.rkt` | with-fresh-meta-env network-always, sess-meta cell-id, freeze |
| `driver.rkt` | Sentinel removal, freeze rename (15 sites), id-map caller |
| `sessions.rkt` | sess-meta struct: added cell-id + gen:equal+hash |
| `session-lattice.rkt` | Pattern match updates for 2-field sess-meta |
| `typing-sessions.rkt` | Pattern match updates (4 sites) |
| `ctor-registry.rkt` | PUnify toggle (attempted, reverted) |
| `tools/run-affected-tests.rkt` | CWD fix, dead-worker detection, summary file, processor-count |
| `tools/pnet-compile.rkt` | CWD-independent cache dir |
| `tools/bench-lib.rkt` | Absolute driver-path for precompile |
| `pnet-serialize.rkt` | Transitive staleness (.zo timestamp check) |
| `zonk.rkt` | freeze alias, call-count instrumentation |

## 10. Lessons Distilled

| Lesson | Target | Status |
|--------|--------|--------|
| "Data at Rest, Closures Derived on Demand" | DEVELOPMENT_LESSONS.org | Done (`7feca8c`) — from Track 10 |
| Diagnostic protocol (audit → hypothesize → test → challenge → reframe) | workflow.md | Done (`65a1f73`) |
| Phase completion protocol (commit → tracker → dailies → next) | Design doc | Done (`9a6b860`) |
| "Vision contaminates audit" — 6th instance | DESIGN_METHODOLOGY.org | Pending — may be ready for codification (6 instances across Track 8, SRE 2, PM 8F, PM 10, PM 10B) |
| Fork boundary = network boundary (Racket params are outside) | — | 1st instance, watching |
| Zonk does substitution, not reading — different operation | — | 1st instance, fundamental insight for SRE 2C design |

## 11. What Would We Do Differently

1. **Separate Stage 2 audit from Stage 3 design.** The combined format contributed to wrong estimates (55→0 eliminable zonk sites, 11→6 batch worker params). A standalone audit with concrete code measurements — THEN a design based on audit data — would have caught these earlier.

2. **Verify what zonk DOES before designing its elimination.** The design said "replace zonk with cell reads." But zonk does SUBSTITUTION (tree walk + replace), not READING (get value). Understanding the operation before designing its removal would have correctly scoped B2 as SRE Track 2C from the start.

3. **Test PUnify toggle earlier.** The toggle was deferred for weeks as "5 known parity bugs." Testing it took 5 minutes and revealed it's not 5 bugs — it's systemic regression. Earlier testing would have correctly scoped the PUnify track sooner.

## 12. Cross-PIR Longitudinal Patterns

Scanning 8 recent PIRs (Track 8 through Track 10B):

### Pattern: Wrong assumptions increase with infrastructure depth

| PIR | Wrong assumptions |
|-----|-------------------|
| BSP-LE Track 0 | 2 |
| CHAMP Performance | 1 |
| SRE Track 0 | 0 |
| Track 8 | 1 |
| SRE Track 1 | 2 |
| SRE Track 2 | 2 |
| PM 8F | 4 |
| PM Track 10 | 5 |
| PM Track 10B | 5+ |

Infrastructure tracks that modify core meta-variable, network, or module
loading paths consistently have MORE wrong assumptions than feature tracks.
The reason: infrastructure touches implicit contracts (what type does the box
hold? what does zonk DO? how many registries exist?) that aren't documented
as explicit invariants.

**Recommendation**: Infrastructure track designs should include an "Implicit
Contracts" section that lists assumptions about the behavior of systems being
modified, verified by concrete code inspection (not memory).

### Pattern: Benchmark-before-building prevents wrong designs

| PIR | Pre-0 changed design? |
|-----|-----------------------|
| BSP-LE Track 0 | YES (transient CHAMP rejected) |
| SRE Track 1B | YES (110× failure path, direct recursive check) |
| SRE Track 2 | YES (O(1) dispatch required before migration) |
| PM 8F | YES (meta-solution already reads from cells) |
| PM Track 10 | YES (parameterize is NOT the bottleneck) |
| PM Track 10B | Confirmed design (no change needed) |

6 consecutive tracks where Pre-0 benchmarks either changed the design or
confirmed it was correct. This is now a reliable methodology — codified in
DESIGN_METHODOLOGY.org as a Stage 3 practice.

### Pattern: "Pre-existing issue" → process smell → eventual fix

| Instance | What | How long deferred | Resolution |
|----------|------|-------------------|------------|
| PUnify parity bugs | 5 known bugs | ~2 weeks | Track 10B A5: tested, systemic, dedicated track created |
| REPL hang | process-string hangs in REPL | ~1 week | Track 10 Phase 3d: 10-line fix, 2+ hours of workarounds |
| Stale .zo | Silent 0-test crash | Recurring | Track 10B: dead-worker detection (30s), stale .zo warning |

Every "pre-existing issue" that was deferred eventually cost more in
workarounds than the fix. The diagnostic protocol and "process smell"
workflow rule address this — but the REPL hang was the catalyzing instance.

### Are we learning from our PIRs?

**YES** — with caveats. The wrong-assumption pattern is IDENTIFIED (6 instances
documented) but NOT YET PREVENTED. Each track still discovers its own wrong
assumptions rather than anticipating them. The "Implicit Contracts" recommendation
above is an attempt to break the cycle.

The benchmark-before-building pattern IS being learned and applied — it's now
a codified Stage 3 practice, and Track 10B's Pre-0 confirmed the design
without changes (the first time Pre-0 didn't change the design).

## 13. What Assumptions Were Wrong

1. **"55 zonk sites can be replaced with cell reads"**: Zonk does substitution (tree walk + replace), not reading (get value). Different operation. Correctly scoped as SRE Track 2C.

2. **"Batch worker can be simplified 11→4 with fork"**: Fork helps network cells. Racket parameters (19 macros registries) are outside the fork boundary. Actual: 11→6 at best.

3. **"test-stdlib is the tail bottleneck"**: Already split. Largest file is 20.8s. File splitting gives ~3-5s marginal.

4. **"PUnify has 5 isolated parity bugs"**: Systemic regression affecting prelude module loading. Not 5 bugs — cascading failures.

5. **"Session meta migration is significant new infrastructure"**: Session metas were already partially on-network (Track 4). B1 was struct change + pattern updates, not deep migration.

## 14. What Did We Learn About the Problem

Zonk is the last ARCHITECTURAL barrier to the all-propagator vision. It exists
because expressions carry `expr-meta` placeholders instead of cell references.
Eliminating zonk requires changing how the ELABORATOR constructs expressions —
not how the meta store is accessed.

This reframing connects PM, SRE, and PRN into one coherent story: the elaborator
(SRE Track 2C) creates expressions with cell references; the PRN substrate
provides the rewriting engine; zonk becomes a matchless rewrite rule (no expr-meta
nodes to substitute). The problem is architectural, not incremental.

## 15. Are We Solving the Right Problem

Yes — but Track 10B's scope was too broad. The WS-A cleanup phases were correctly
scoped and delivered. The WS-B zonk elimination was incorrectly scoped as a Track
10B deliverable — it's an SRE Track 2C deliverable that requires changing
expression construction.

The right problem at this stage: finish the infrastructure foundation (Track 10/10B),
then build the SRE elaborator (Track 2C) that makes zonk unnecessary. Track 10B
correctly identified the GOAL (zonk elimination) but placed it in the wrong TRACK
(PM instead of SRE).

## 16. Is This Isolated or Part of a Pattern

The "wrong track for the deliverable" pattern has appeared before:
- Track 8 B5 was transferred to CIU Track 3 (content, not infrastructure)
- Track 10B B2 deferred to SRE Track 2C (elaborator, not meta store)

Both cases: a deliverable was scoped in an infrastructure track but actually
requires a SYSTEM migration track. The lesson: infrastructure tracks (PM series)
deliver the SUBSTRATE. System migration tracks (SRE series) deliver the
BEHAVIOR CHANGE. Zonk elimination is a behavior change (how expressions are
constructed), not a substrate change (where metas are stored).
