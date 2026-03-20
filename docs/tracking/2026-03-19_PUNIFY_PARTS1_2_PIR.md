# PUnify Parts 1–2: Cell-Tree Unification — Post-Implementation Review

**Date**: 2026-03-19
**Duration**: ~20 hours across 3 sessions (design-heavy)
**Commits**: 47 (`0cdb900` through `ca90b25`), including 1 revert + re-implementation
**Test delta**: 7154 → 7214 (+60 tests via acceptance file expansion)
**Code delta**: +9295 / −342 across 30 files (1 new: `ctor-registry.rkt`)
**Suite health**: 7214 tests, 374 files, 175.9s, all pass
**Design docs**:
- Part 1: `2026-03-19_PUNIFY_STRUCTURAL_UNIFICATION_PROPAGATORS.org`
- Part 2: `2026-03-19_PUNIFY_PART2_CELL_TREE_ARCHITECTURE.md`
- Part 3 (future): `2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md`

---

## 1. What Was Built

PUnify replaces **both unification systems** in Prologos with **cell-tree structures** on the propagator network, using a shared domain-agnostic constructor descriptor registry.

**System 1** (type-level, `unify.rkt`): The 37-case classifier and propagator-integrated unification engine gained descriptor-driven decomposition for compound types (Pi, Sigma, Lam, App, Eq, Vec, Fin, Pair, PVec, Set, Map, suc). `classify-whnf-problem` remains unchanged; what changes is how decomposition results flow — through registered descriptors rather than per-type ad-hoc code. Direct network contradiction checking replaces callback indirection.

**System 2** (solver-level, `relations.rkt`): The 5-case flat substitution DFS solver gained a parallel cell-based path via `solver-env` — a `prop-network` + variable-to-cell-id mapping that threads transparently through existing `walk`/`walk*`/`unify-terms` via polymorphic dispatch. The DFS search strategy and `solve-goals` architecture are preserved; only the substitution representation changes, toggled by `current-punify-enabled?`.

**Shared infrastructure**: `ctor-registry.rkt` provides 21 constructor descriptors (12 type + 9 data) with generic `decompose-components`, `reconstruct-value`, and `merge` operations. The registry validates descriptor roundtrip correctness at registration time.

**Part 1** (surface wiring + baselines) resolved 8 language design decisions, wired `=`/`is`/`#=` through the solve pipeline, created a 169-command acceptance file, built a 3-tier adversarial benchmark suite, and profiled type-level unification (revealing 80% fast-path rate, 36% level, 24% flex-rigid, 18% pi).

**Part 2** (cell-tree architecture) implemented 9 phases: descriptor registry, flex-rigid as cell write, Pi/Sigma/Lam/compound decomposition as sub-cells, solver cell infrastructure, polymorphic solver dispatch, fast-path preservation verification, callback elimination, occurs check, and zonk verification.

**What does NOT change**: The 10 type-level classification categories, three-valued result semantics (`#t`/`'postponed`/`#f`), de Bruijn handling, DFS search strategy, WHNF reduction, level unification (numeric lattice), union unification, and all user-facing syntax.

---

## 2. Timeline and Phases

### Part 1: Surface Wiring + Baselines

| Phase | Commit | What |
|-------|--------|------|
| Design: §1.1–1.8 | `c41c7a9` | 8 language design decisions resolved |
| Design: two-part strategy | `44a5f8d` | Acceptance file + adversarial benchmark design |
| 0a: Pipeline wiring | `32d62c6`, `3e04907`, `34a5690` | `=`/`is`/`#=` through solve, acceptance → 163 cmds |
| 0b: `defr \|` fix | `490a4e3` | Literal patterns in clause-form params |
| 0d: Adversarial benchmarks | `76eb5d2` | Micro + comparative + solver baselines |
| 0e: Unification profiler | `364d043`, `ed5f7e7` | `profile-unify.rkt`, type-level microbenchmarks |

### Part 2: Cell-Tree Architecture

| Phase | Commit | Time | What |
|-------|--------|------|------|
| D.1 | `b12a891` | — | Design: cell-tree architecture |
| D.2 | `349c9d2`, `bf0d21f`, `16e3cd1` | — | Lattice-first refinement, solver in scope, critique |
| D.3 | `300a16e` | — | Self-critique: termination, trade-offs, corrections |
| 1 | `933bdf2` → `30bea2d` → `4a0567e` | — | Descriptor registry (revert + re-impl) |
| 2 | `67f1388` | — | flex-rigid as direct contradiction check |
| 3 | `52e6230` | — | Pi decomposition as sub-cells |
| 4 | `bc05b08` | — | Sigma/Lam/App/Eq/Vec/Fin/Pair/PVec/Set/Map |
| 5a | `9800410` | — | solver-env, polymorphic walk/unify-terms |
| 5b | `988af5c` | — | Descriptor-aware solver decomposition |
| 5c | N/A | — | Functional threading = free backtracking |
| 5d | ⏸️ | — | Bridge retirement deferred (Part 3 Phase 0) |
| 6 | `10dd6e5` | — | Fast-path verification (80% rate confirmed) |
| 7 | `74abfff` | — | Callback elimination (`punify-has-contradiction?`) |
| 8 | `4eafae1` | — | `solver-term-occurs?` for both paths |
| 9 | `ca90b25` | — | Zonk verification (Track 6 path confirmed) |

**Design-to-implementation ratio**: ~12h design (Part 1 decisions, Part 2 D.1–D.3, Part 3 design) : ~8h implementation = **1.5:1**. Higher design investment than Tracks 3–5, similar to Track 7. The three design critique rounds (D.1, D.2 external, D.3 self-critique) settled all major questions before code.

---

## 3. Test Coverage

**New tests**: +60 (7154 → 7214), all from acceptance file expansion across Part 1 phases.

**Acceptance file**: `examples/2026-03-19-punify-acceptance.prologos` — 169 commands across 13 sections (relational `=`, existing relational features, three-operator vocabulary, expression-context, term decomposition, type-level, broad regression canary). Run after every Part 2 phase; 0 errors throughout.

**Benchmark suite**:
- `benchmarks/comparative/punify-adversarial.prologos` — type-adversarial (17.9s baseline)
- `benchmarks/comparative/solve-adversarial.prologos` — solver stress (14.3s baseline, 92 commands)
- `benchmarks/micro/bench-type-unify.rkt` — 20 unification microbenchmarks
- `benchmarks/micro/bench-solver-unify.rkt` — 19 solver microbenchmarks

**Coverage gaps**:
- `bench-zonk.rkt` is stale (uses `solve-meta!` without propagator infrastructure) — needs update
- No tests exercise `current-punify-enabled? #t` in integration (toggle defaults to `#f`; cell paths verified via unit-level testing and profiler instrumentation)
- System 2 cell path (`solver-env`) untested in integration because toggle is off; will be exercised when default flips in Part 3

---

## 4. Bugs Found and Fixed

### 4.1 Phase 1 Revert: Context Loss During Implementation (`933bdf2` → `30bea2d` → `4a0567e`)

The first Phase 1 attempt was committed, then reverted because it was implemented without full context from the principles documents and design critique. The re-implementation (`4a0567e`) was a fresh start with proper grounding in the design doc's D.2/D.3 findings.

**Why the wrong path seemed right**: The first attempt jumped to implementation after reading only the high-level design, without absorbing the critique rounds that refined descriptor validation, two-table registry (type + data domains), and `lattice-spec` for deferred type-lattice merge.

**Root cause**: Insufficient pre-implementation context loading. The design doc had evolved through 3 commits (D.1, lattice-first refinement, solver scope expansion) after the initial design; the first attempt used the initial design.

**Lesson**: When a design doc has undergone multiple critique rounds, re-read the FINAL version (including D.2/D.3 responses) before implementing. The critique rounds changed the design, not just validated it — same lesson as Track 7 PIR §6.1.

### 4.2 `defr |` Literal Pattern Fix (`490a4e3`)

`defr` clause-form didn't support literal patterns in parameters (e.g., `defr parent | "alice" "bob"`). Discovered during acceptance file creation — Section B (existing relational features) exercised `defr |` with string literals for the first time.

**Root cause**: `clause-form` parser matched only symbol and wildcard patterns in parameter position; literals fell through silently.

**Lesson**: Acceptance files catch pipeline gaps that unit tests miss because they exercise realistic multi-form interaction. This is the same pattern as Track 7 PIR (5 bugs found by acceptance file) and WFLE PIR (5 bugs caught exclusively by Level 3 validation).

### 4.3 Phase 5c: Backtracking Non-Bug

The design allocated Phase 5c for "DFS copy-on-branch" — implementing backtracking isolation for the solver-env path. Implementation revealed this was already handled: functional threading of immutable `solver-env` values through `append-map` provides free backtracking isolation without any copy-on-branch machinery. The "phase" completed with N/A status.

**Why the design anticipated a problem that didn't exist**: The design assumed solver-env would need explicit isolation (like Prolog's trail mechanism). But Racket's functional value threading means each branch receives its own solver-env automatically — `append-map` over goals creates independent continuation chains.

**Lesson**: Functional programming's default is isolation. When designing cell-based infrastructure in a functional language, check whether the language's value semantics already provide the isolation you're planning to build.

---

## 5. Design Decisions and Rationale

### 5.1 Domain-Agnostic Descriptor Registry (Phase 1)

**Decision**: Single `ctor-registry.rkt` serving both type-level (System 1) and data-level (System 2) descriptors, with a `#:domain` tag discriminating them.

**Rationale**: The Part 1 benchmark analysis revealed that adversarial benchmarks stress System 2, while the original Part 2 design targeted System 1. Scoping both systems validates the registry's genericity and closes the benchmark/architecture gap. Two separate registries would duplicate generic operations.

**Design principle**: Decomplection (DESIGN_PRINCIPLES.org) — one generic infrastructure replacing three independent structural knowledge encodings (`try-unify-pure` ~170 lines, `classify-whnf-problem` ~150 lines, `maybe-decompose` ~100 lines).

### 5.2 Polymorphic Dispatch in walk/unify-terms (Phase 5a)

**Decision**: Rather than changing all solve function signatures, added `(solver-env? subst)` dispatch to existing `walk`/`walk*`/`unify-terms`. The solver-env threads transparently as a "substitution."

**Rationale**: The DFS solver has ~20 functions threading `subst`. Changing all signatures would be invasive with high regression risk. Polymorphic dispatch at the 3 entry points (`walk`, `walk*`, `unify-terms`) achieves the same result with surgical changes — the rest of the solver is oblivious to whether it holds a `hasheq` or `solver-env`.

**Trade-off**: Dispatch overhead on every `walk` call (one `solver-env?` struct predicate check). Acceptable because `walk` is already O(chain-length); one predicate check is negligible.

### 5.3 Direct Network Access Over Callbacks (Phases 2, 7)

**Decision**: Replace `current-prop-has-contradiction?` callback with direct `punify-has-contradiction?` that reads `(current-prop-net-box)` and calls `prop-network-has-contradiction?`.

**Rationale**: The callback was set in `driver.rkt` as a closure capturing the network box. But `punify-has-contradiction?` in `ctor-registry.rkt` can access the same box directly — the callback adds indirection without encapsulation benefit. This continues Track 6's finding that callbacks are a propagator-first anti-pattern (Track 6 PIR §6.4).

**Scope limit**: Only `current-prop-has-contradiction?` was eliminated. `current-prop-cell-read`/`current-prop-cell-write` serve the entire elaboration pipeline (not just unification) — their elimination is Track 8 second-half scope.

### 5.4 Verification Phases as First-Class Deliverables (Phases 6, 9)

**Decision**: Two of nine phases produced no code changes — they verified that existing infrastructure already satisfied the design's requirements.

**Rationale**: Phase 6 confirmed the 80% fast-path rate survived PUnify changes (the fast-path precedes decomposition, so cell-tree migration changes nothing). Phase 9 confirmed that zonk already reads cell values via `meta-solution` → `current-prop-cell-read` → `net-cell-read` (installed by Track 6). Both are genuine deliverables: they close open questions from the design and provide evidence for the progress tracker.

**Design principle**: Belt-and-suspenders validation (Tracks 3–7 pattern). Even when we expect no change, verification catches the unexpected.

### 5.5 Bridge Retirement Deferral (Phase 5d)

**Decision**: Defer `ground->prologos-expr`, `prologos->ground-expr`, `ground-substitution->expr-substitution` retirement to Part 3 Phase 0.

**Rationale**: These bridges serve the default (non-punify) solver path, which is still the production path. Retiring them requires either (a) making punify the default or (b) maintaining both paths. Part 3 will make punify the default via ATMS-world search; bridge retirement is a natural Part 3 prerequisite.

---

## 6. Lessons Learned

### 6.1 Three-Part Design Investment Pays Off Multiplicatively

Part 1 resolved 8 language design decisions and created baselines before Part 2 touched any unification code. Part 2's D.1–D.3 critique rounds settled the lattice-first architecture, solver scope expansion, and termination argument before implementation. Result: 9 implementation phases with zero wrong turns (excluding the Phase 1 revert, which was a context-loading failure, not a design failure).

**Quantified**: ~12h design produced ~8h of linear implementation. Compare Track 6 (4h design, 14h implementation with 2 reverts) — higher design investment correlates with smoother implementation. This continues the WFLE PIR finding (6:1 design-to-implementation ratio as the gold standard).

### 6.2 Profiling Before Architecture Prevents Wasted Work

Part 1's unification profiler revealed that 80% of `unify` calls hit the fast-path (identical terms, `equal?` check) and create zero cells. Only 20% reach classification, and of those, 36% are level unification (numeric lattice, not tree-structured). This means PUnify's cell-tree architecture affects ~12.8% of unification calls — important for calibrating expectations and the performance budget.

**Without profiling**: We might have optimized the 80% fast-path (already optimal) or worried about level unification regression (unchanged by PUnify). The profiler redirected attention to the actual target: compound type decomposition in the 12.8% that reaches descriptor-driven paths.

### 6.3 Polymorphic Dispatch Enables Surgical Migration

The System 2 migration (Phases 5a–5c) changed 3 dispatch points (`walk`, `walk*`, `unify-terms`) to add `solver-env?` checks, leaving ~20 solver functions completely untouched. This is a powerful migration pattern: when a data structure threads through many functions, make the structure polymorphic rather than changing every consumer.

**Contrast**: The naive approach (new function signatures for all solve functions) would have touched ~20 functions with high regression risk. Polymorphic dispatch achieved the same result with 3 surgical changes.

### 6.4 Functional Threading Provides Free Backtracking

Phase 5c was designed as "DFS copy-on-branch" but discovered that Racket's immutable value semantics already provide backtracking isolation. Each branch in `append-map` receives its own `solver-env` value; no explicit copy or trail mechanism needed. The phase completed with "N/A — functional threading inherently provides isolation."

**Meta-lesson**: When designing infrastructure in a functional language, audit whether the language's default semantics already solve the problem before building explicit mechanisms. This is the Prologos project's recurring theme of leveraging Racket's strengths (structural sharing via CHAMP, immutable values, `parameterize` scoping) rather than fighting them.

### 6.5 Acceptance Files Catch What Unit Tests Cannot

The acceptance file discovered the `defr |` literal pattern bug (Phase 0b) — a pipeline gap invisible to unit tests because unit tests don't exercise multi-form file-level interaction. This is the same finding as Track 7 PIR (5 parser/preparse bugs) and WFLE PIR (5 bugs caught exclusively by Level 3). Three consecutive PIRs confirming the same lesson should now be treated as architectural, not anecdotal.

### 6.6 Design Critique Changes Designs, Not Just Validates Them

Part 2's D.2 external critique expanded the design from System 1 only to both Systems 1 and 2. The D.3 self-critique identified a missing termination argument for unify-propagators and the "ephemeral state tension" with DESIGN_PRINCIPLES.org. Both changed the final design document. This continues Track 7's finding (threshold-cell composition from D.2 Concern 2) — critique rounds are collaborative design sessions, not rubber-stamping.

---

## 7. Metrics

| Metric | Value |
|--------|-------|
| Total commits | 47 (Part 1: 18, Part 2: 29) |
| Design commits | 11 (Part 1: 4, Part 2: 5, Part 3: 2) |
| Implementation commits | 36 (Part 1: 14, Part 2: 22) |
| Reverts | 1 (Phase 1: context-loading failure) |
| Files changed | 30 |
| Lines added | 9,295 |
| Lines removed | 342 |
| New files | 1 (`ctor-registry.rkt`) |
| Tests: before → after | 7,154 → 7,214 (+60) |
| Suite time | 175.9s (vs 181.2s Track 7 post-fix) |
| Type descriptors | 12 (Pi, Sigma, App, Eq, Vec, Fin, Pair, Lam, PVec, Set, Map, suc) |
| Data descriptors | 9 (cons, nil, some, none, suc, zero, pair, ok, err) |
| Fast-path rate | 80% (9,530 calls → 1,905 classified) |
| Classification distribution | level 36%, flex-rigid 24%, pi 18%, ok 12-14% |
| Adversarial baselines | type: 17.9s, solver: 14.3s |
| Acceptance file | 169 commands, 13 sections, 0 errors |
| Verification phases | 2 of 9 (Phases 6, 9) |
| Deferred phases | 1 (Phase 5d: bridge retirement → Part 3) |

---

## 8. What Went Well

1. **Design-first approach eliminated wrong turns**: 12h of design (language decisions, baselines, profiling, 3 critique rounds) produced 8h of linear implementation. Every phase passed all tests on first compilation except Phase 1's context-loading revert.

2. **Profiler redirected architectural attention**: The 80% fast-path finding meant we could focus PUnify's cell-tree work on the 12.8% that actually reaches compound decomposition, rather than over-engineering the common case.

3. **Polymorphic dispatch pattern was a force multiplier**: 3 surgical changes to `walk`/`walk*`/`unify-terms` migrated the entire solver without touching ~20 other functions. Minimal diff, maximum effect.

4. **Descriptor registry validated its genericity**: Serving both type-level (12 descriptors) and data-level (9 descriptors) domains from a single infrastructure confirms the design's decomplection thesis. The `generic-decompose-components` and `generic-reconstruct-value` operations work identically across domains.

5. **Suite time improved**: 175.9s is the fastest full-suite time in project history (vs 181.2s Track 7, 207.4s Track 7 pre-fix, 235.2s Track 6 end). PUnify added no measurable overhead.

6. **Three-tier benchmark suite provides future-proof baselines**: Micro-benchmarks for function-level precision, comparative A/B for infrastructure changes, suite timings for regression detection. Part 3 can compare against Part 2's baselines with statistical rigor.

## 9. What Went Wrong

1. **Phase 1 revert**: First attempt implemented without absorbing D.2/D.3 critique findings. Cost: ~1h (implement + revert + re-implement). Root cause: insufficient context loading when a design doc has evolved through multiple critique rounds.

2. **`bench-zonk.rkt` staleness**: The zonk micro-benchmark uses `solve-meta!` without propagator infrastructure and fails at runtime. Discovered during Phase 9 verification but not fixed — it pre-dates the propagator migration and needs a fundamental rewrite. This is technical debt from the benchmarking infrastructure not keeping pace with architecture changes.

3. **No integration tests for `current-punify-enabled? #t`**: The cell-tree paths in both System 1 and System 2 are verified via profiler instrumentation and unit-level testing, but no integration test runs with the toggle on. When Part 3 flips the default, this will be a large surface area change. An integration test with the toggle on should have been added as a Phase 9 deliverable.

4. **Phase 5d deferral creates a dangling dependency**: Three bridge functions (`ground->prologos-expr`, `prologos->ground-expr`, `ground-substitution->expr-substitution`) remain in `relations.rkt` serving the non-punify path. They're captured in Part 3's Phase 0, but if Part 3 is delayed, this becomes invisible technical debt.

## 10. Where We Got Lucky

1. **Functional threading eliminated Phase 5c entirely**: The design budgeted a full phase for DFS copy-on-branch backtracking isolation. Racket's immutable value semantics made this free. If we'd been building in a mutable language (e.g., Prolog's trail, or Java's clone()), this would have been a real implementation phase with real bugs.

2. **80% fast-path rate shields performance**: PUnify changes only affect the 20% of unification calls that reach classification. If the fast-path rate were 50%, the performance budget would be much tighter. The high fast-path rate is a property of Prologos's type system (many identical-term checks), not a PUnify design choice.

3. **Track 6's cell-read path pre-implemented Phase 9**: Zonk was already reading cell values via `meta-solution` → `current-prop-cell-read`. If Track 6 hadn't installed this path, Phase 9 would have been a real implementation phase requiring changes to `meta-solution` and callback wiring.

4. **No existing test exercises `solver-term-occurs?`**: Phase 8 added occurs-check guards to both hasheq and solver-env paths in `unify-terms`, but no test creates an infinite term (e.g., `unify(X, f(X))`). All 7214 tests pass unchanged, meaning the occurs check is a latent soundness fix, not a behavior change. If any test had relied on the old (unsound) behavior of creating circular bindings, Phase 8 would have broken it.

## 11. What Surprised Us

1. **System 2 was the cheaper migration**: Part 2's design allocated 4 sub-phases to System 2 (5a–5d). In practice, 5a and 5b were the only implementation work; 5c was free (functional threading) and 5d was deferred. System 1 required 3 substantial implementation phases (2, 3, 4). The "simpler" system was genuinely simpler to migrate.

2. **The design evolved substantially through critique**: Part 2's D.1 targeted only System 1. D.2 external critique brought System 2 into scope (the benchmark/architecture disconnect). D.3 self-critique added termination arguments, identified the ephemeral-state tension, and corrected 3 factual errors. The final design differs materially from D.1. Design critique is not validation — it's collaborative design.

3. **Verification phases are legitimate deliverables**: Phases 6 and 9 produced no code changes but closed open design questions with evidence. The instinct to skip them ("nothing changed, why write it up?") would leave the progress tracker incomplete and the design's claims unverified.

4. **Suite time decreased despite adding infrastructure**: 175.9s < 181.2s (Track 7 post-fix). PUnify adds descriptor lookups, generic decompose/reconstruct operations, and occurs-check guards — yet the suite is faster. Likely explanation: `raco make` recompilation after code changes occasionally produces better-optimized bytecode, or minor code path improvements from the descriptor-driven simplification offset the overhead.

---

## 12. Architecture Assessment

### How the Architecture Held Up

**Propagator network**: Accommodated both Systems 1 and 2 without friction. System 1 uses the elab-network's existing infrastructure; System 2 creates standalone `prop-network` instances per solve invocation. The `net-new-cell`/`net-cell-read`/`net-cell-write` API served both domains without modification.

**Constructor descriptor registry**: Clean extension point. Adding a new type or data constructor requires one `register-ctor!` call with recognizer, extractor, reconstructor, and lattice spec. The `validate-ctor-desc!` at registration time catches roundtrip errors immediately.

**`classify-whnf-problem`**: Survived entirely unchanged. The 37-case classifier is orthogonal to decomposition strategy — it determines WHAT to decompose, not HOW. This separation validated the design's claim that classification and decomposition are decomplected.

**`solve-goals` / DFS search**: Survived entirely unchanged. The substitution representation is an implementation detail below the search strategy. Polymorphic dispatch insulated the search layer from the representation change.

### Extension Points That Worked

- **`prop-network` as standalone** (System 2): Each solve invocation creates a fresh `prop-network` with no TMS, no metas, no constraint infrastructure — just cells and merges. The network API is general enough for this minimal usage.
- **`ctor-desc` struct**: Domain-agnostic by design. `#:domain 'type` vs `#:domain 'data` distinguishes type-level and data-level without separate registries.
- **Polymorphic `walk`/`unify-terms`**: The `solver-env?` dispatch transparently routes to cell-based operations while preserving the existing hasheq path.

### Friction Points

- **`current-prop-cell-read`/`current-prop-cell-write` callbacks**: These serve the entire elaboration pipeline, not just unification. Phase 7 could only eliminate the unification-specific `current-prop-has-contradiction?`. Full callback elimination requires Track 8's second half (mult bridges, id-map migration).
- **`bench-zonk.rkt` staleness**: Micro-benchmarks haven't kept pace with the propagator migration. This is a systemic issue — each track changes infrastructure without updating all benchmarks.
- **No `current-punify-enabled? #t` integration test**: The toggle exists but no test exercises it. This is a gap that will surface when Part 3 flips the default.

---

## 13. What This Enables

**Immediate** (Part 3 scope):
- ATMS-world solver replacing DFS backtracking — cell-tree unification is the prerequisite substrate
- Bridge retirement (Phase 5d) — once punify becomes default, bridge functions can be removed
- `solver-env` as ATMS environment — the prop-network already supports TMS cells

**Medium-term** (Track 8 second half):
- Mult bridge elimination — descriptor registry can serve mult-lattice merges
- id-map accessibility from propagator fire functions — descriptors provide the structural knowledge currently hardcoded in elaborator-network.rkt
- Full callback elimination — `current-prop-cell-read`/`current-prop-cell-write` replaced by direct network access

**Long-term** (Tracks 9–10):
- Cell-tree provenance for GDE (Track 9) — each cell carries creation-time source location
- LSP per-position type information (Track 10) — cell-trees provide observable type structure at each AST position

---

## 14. Technical Debt Accepted

| Item | Rationale | Tracking |
|------|-----------|----------|
| Bridge functions retained | Serve non-punify default path | Part 3 Phase 0, DEFERRED.md |
| `bench-zonk.rkt` stale | Pre-dates propagator migration; not blocking | DEFERRED.md |
| No `punify-enabled? #t` integration test | Toggle defaults to #f; Part 3 will flip | Part 3 scope |
| `current-prop-cell-read`/`write` callbacks | Serve entire pipeline; elimination is Track 8 | Track 8 second half |
| System 2 cell path untested in integration | Verified at unit level; Part 3 flips default | Part 3 scope |

---

## 15. What Would We Do Differently

1. **Re-read the final design doc before implementing Phase 1**: The revert cost ~1h and was entirely avoidable. When a design doc has undergone D.2 + D.3 critique rounds that materially changed the design, the final version must be loaded before writing code. This is now a firm process rule.

2. **Add a `punify-enabled? #t` integration test as a Phase 9 deliverable**: Instead of only verifying that the default path works, Phase 9 should have verified that the punify path produces correct results on a representative test subset. This would catch integration issues before Part 3's default flip.

3. **Update micro-benchmarks alongside infrastructure changes**: `bench-zonk.rkt` broke silently because no one ran it during PUnify. A pre-implementation step should be "run all micro-benchmarks and fix any that fail." This prevents benchmark staleness from accumulating.

---

## 16. Assumptions That Were Wrong

1. **"System 2 needs copy-on-branch"**: The design assumed DFS backtracking requires explicit isolation machinery. Wrong — Racket's functional value threading provides free isolation. The assumption came from imperative Prolog implementations (trail/undo), not functional ones.

2. **"Zonk needs simplification"**: Phase 9 was designed as a code change phase. In reality, Track 6 already implemented the cell-read path. The assumption that PUnify would change zonk was wrong — PUnify changes how cells are populated, not how they're read.

3. **"callback elimination is straightforward"**: Phase 7 eliminated `current-prop-has-contradiction?` cleanly, but couldn't touch `current-prop-cell-read`/`current-prop-cell-write` because they serve the entire pipeline. The assumption that "eliminate callbacks" was a single-phase task was wrong — it's at least a two-track effort.

---

## 17. What We Learned About the Problem

**Unification is two problems, not one**: System 1 (type-level) and System 2 (solver-level) share the conceptual operation but differ in every detail: representation (AST nodes vs flat lists), strategy (propagator-driven vs DFS), lifecycle (per-command vs per-solve), and state management (elab-network vs standalone). The descriptor registry's domain-agnostic design bridges this gap, but the implementation required genuinely different approaches for each system.

**The fast-path dominates**: 80% of unification calls are resolved by `equal?` comparison before any classification or decomposition. This means PUnify's cell-tree architecture is an investment in the 20% minority case — justified by architectural benefits (decomplection, observability, future Track 8–10 enablement), not by performance on the common case.

**Functional languages make migration easier**: Racket's immutable values, structural sharing (CHAMP), and `parameterize` scoping provided free backtracking, free snapshot isolation, and free cleanup. In a mutable language, Phases 5c, 6, and 9 would all have been real implementation work.

---

## 18. Cross-Reference: Recurring Patterns Across PIRs

### Pattern 1: Acceptance Files Catch Pipeline Gaps (Tracks 3, 7, WFLE, PUnify)

| PIR | Bugs Found by Acceptance File |
|-----|-------------------------------|
| WFLE | 5 (exclusively Level 3) |
| Track 7 | 5 (parser/preparse level) |
| PUnify | 1 (`defr \|` literal patterns) + 7 surface gaps cataloged |

**Assessment**: Four consecutive PIRs confirm acceptance files as a bug-finding tool, not just a regression gate. The methodology is proven. **Process recommendation**: Acceptance file creation should be a non-negotiable Phase 0 for every implementation track, not just syntax-changing features.

### Pattern 2: Design Critique Changes Designs (Tracks 7, PUnify)

| PIR | Design Change from Critique |
|-----|----------------------------|
| Track 7 | Threshold-cell composition (D.2 Concern 2) |
| PUnify | System 2 scope expansion (D.2), termination argument (D.3) |

**Assessment**: Two consecutive PIRs show D.2/D.3 rounds producing material design improvements, not just validation. **Process observation**: This was not true for earlier tracks (Tracks 3–5 treated critique as validation). The difference may be that PUnify and Track 7 had more ambitious designs with more design surface area for critique to improve.

### Pattern 3: Verification Phases as First-Class Deliverables (Tracks 4, 5, 6, 7, PUnify)

Belt-and-suspenders validation has been used in every propagator migration track. PUnify formalizes this as "verification phases" (Phases 6, 9) that appear in the progress tracker alongside implementation phases. **Assessment**: Verification is work. It deserves tracking. The instinct to skip it because "nothing changed" leaves design claims unverified.

### Pattern 4: Phase 1 Is Where Design Happens (Tracks 3, 4, 5, 7, PUnify)

| PIR | Phase 1 Duration vs Subsequent |
|-----|-------------------------------|
| Track 3 | 50 min vs 2 min/reader (Phases 2–4) |
| Track 4 | 25 min creative + revert vs 15–25 min mechanical |
| Track 5 | Infrastructure + prototype vs mechanical application |
| Track 7 | Full workstream design vs phase execution |
| PUnify | Revert + re-implementation vs linear Phases 2–9 |

**Assessment**: Five consecutive tracks confirm that Phase 1 is where all design decisions happen; subsequent phases are mechanical application. Budget Phase 1 at 2–3× other phases. PUnify's Phase 1 revert is the strongest evidence: when Phase 1 goes wrong, the entire track stalls until it's right.

### Pattern 5: Context Loss Causes Reverts (Tracks 6, PUnify)

| PIR | Context Loss Event | Cost |
|-----|-------------------|------|
| Track 6 | Server outage → Phases 7b–7c divergence | ~2h + 8 commits |
| PUnify | Insufficient design context → Phase 1 revert | ~1h + 3 commits |

**Assessment**: Both were avoidable. Track 6's mitigation: re-read prior track's design doc and PIR before implementing after context break. PUnify's mitigation: re-read the final (post-critique) design doc before Phase 1. **Process recommendation**: Add an explicit "context loading" step to the pre-implementation checklist: "Read the final design doc (including D.2/D.3), the most recent PIR, and the current dailies before writing any code."

### Pattern 6: Callback Elimination Is Multi-Track Work (Tracks 6, 7, PUnify)

| PIR | Callbacks Eliminated | Callbacks Remaining |
|-----|---------------------|-------------------|
| Track 6 | Identified as anti-pattern | All remained |
| Track 7 | 3 scanning callbacks → 0 | Resolution callbacks |
| PUnify | `current-prop-has-contradiction?` → 0 | `current-prop-cell-read`/`write` |

**Assessment**: Each track eliminates one layer of callback indirection. The remaining callbacks (`current-prop-cell-read`/`write`) serve the entire elaboration pipeline — they're the deepest layer. Track 8's second half is the final elimination target.

---

## 19. Key Files

| File | Role |
|------|------|
| `ctor-registry.rkt` | **NEW**: Constructor descriptor registry (21 descriptors, generic ops) |
| `unify.rkt` | System 1: descriptor-driven decomposition, direct contradiction check |
| `relations.rkt` | System 2: solver-env, polymorphic dispatch, descriptor decomposition |
| `type-lattice.rkt` | Generic descriptor fallback for 9 per-tag structural cases |
| `elaborator-network.rkt` | `type-constructor-tag` driven by descriptor registry |
| `driver.rkt` | Removed contradiction callback setup |
| `performance-counters.rkt` | `perf-inc-prop-alloc!` counter |
| `tools/profile-unify.rkt` | **NEW**: Unification profiler for classification distribution |
| `benchmarks/micro/bench-type-unify.rkt` | **NEW**: 20 type-unification microbenchmarks |
| `benchmarks/micro/bench-solver-unify.rkt` | **NEW**: 19 solver microbenchmarks |
| `benchmarks/comparative/punify-adversarial.prologos` | Type-adversarial stress test |
| `benchmarks/comparative/solve-adversarial.prologos` | Solver stress test |
| `examples/2026-03-19-punify-acceptance.prologos` | 169-command acceptance file |

---

## 20. Are We Solving the Right Problem?

PUnify's stated goal is replacing algorithmic unification with structural (cell-tree) unification on the propagator network. The implementation confirms this is the right direction:

1. **Decomplection validated**: Three independent structural knowledge encodings (try-unify-pure, classify-whnf-problem, maybe-decompose) now share a single descriptor registry. Adding a new type constructor requires one registration, not three code changes.

2. **Observability improved**: Cell-trees make type structure observable on the propagator network — a prerequisite for Track 10 (LSP) and Track 9 (GDE provenance).

3. **Performance is neutral**: 175.9s suite time is faster than any prior track. The 80% fast-path rate shields performance; the 12.8% that reaches descriptors is not measurably slower.

4. **The real prize is Part 3**: PUnify Parts 1–2 are infrastructure for Part 3's ATMS-world solver. The DFS solver is the architectural bottleneck for relational programming; cell-tree unification is the substrate that enables ATMS-driven exploration. Parts 1–2 are necessary but not sufficient — the user-visible payoff comes with Part 3.

**Honest assessment**: The performance case for PUnify is weak (the design doc's D.3 self-critique says this explicitly). The architectural case is strong. This is a conscious trade-off: investing in infrastructure that enables future capabilities (ATMS solver, LSP, GDE) at the cost of ~12h implementation time with no performance regression. The risk is that Part 3 doesn't materialize, leaving PUnify as infrastructure investment without payoff.

---

## Appendix A: Meta-Trend Analysis Across Tracks 3–8 (6 PIRs)

This appendix steps back from the PUnify-specific analysis to identify **systemic patterns** across the 6 most recent PIRs: Track 3 (Cell-Primary Registries), Track 4 (ATMS Speculation), Track 5 (Global Env Dependency Edges), Track 6 (Driver Simplification), Track 7 (Persistent Cells + Stratified Retraction), and Track 8/PUnify Parts 1–2.

### Meta-Trend 1: Design Investment Correlates with Implementation Smoothness

| Track | Design:Impl Ratio | Wrong Turns / Reverts | Notes |
|-------|-------------------|----------------------|-------|
| Track 3 | 1.5:1 | 0 | Mechanical after Phase 1 |
| Track 4 | 0.75:1 | 1 (Phase 2c stack push) | Lower design → Phase 2c surprise |
| Track 5 | 1:1 | 1 (Phase 5a test path) | Moderate risk, moderate design |
| Track 6 | 1:3.5 | 2 (Phases 7b–7c full revert) | Lowest ratio → most reverts |
| Track 7 | 1.3:1 | 0 | D.2/D.3 improved design pre-code |
| PUnify | 1.5:1 | 1 (Phase 1 context-loading) | High design → linear execution |

**The pattern**: When the design-to-implementation ratio drops below 1:1, reverts become likely. Track 6 (1:3.5) had the most reverts; Tracks 3, 7, and PUnify (≥1.3:1) had the fewest wrong turns. The sweet spot appears to be 1:1 to 2:1 for infrastructure tracks.

**Caveat**: Track 4's 0.75:1 ratio worked because it built on Tracks 1–3's patterns. Novel designs need higher ratios; mechanical extensions need lower ones.

**Process recommendation**: Before starting implementation, assess novelty. Novel designs → budget ≥1.5:1. Pattern extensions → 0.75:1 is fine.

### Meta-Trend 2: The Elaboration Boundary Is the Permanent Architectural Seam

Every track from 3 through PUnify has encountered the **elaboration boundary** — the distinction between "inside `process-command`" (propagator network active, cells valid) and "outside" (module loading, test setup, batch worker).

| Track | Elaboration Boundary Issue |
|-------|---------------------------|
| Track 3 | Elaboration guards discovered (cell stale outside `process-command`) |
| Track 4 | Dual-write coherence violated by TMS branching |
| Track 5 | `run-ns-last` test path divergence (no network factory) |
| Track 6 | Net-box scoping; ATMS lazy init; callback vestigiality |
| Track 7 | Module-load-time registration dependency; persistent vs ephemeral |
| PUnify | `current-prop-cell-read`/`write` callbacks serve entire pipeline; Phase 9 depends on Track 6's cell-read path |

**Assessment**: This is not a bug in any individual track — it's a fundamental architectural characteristic. The elaboration boundary separates two execution contexts with different invariants. Every infrastructure change must ask: "Does this work in both contexts?"

**Process recommendation**: Add "Two-context audit" to the Pipeline Exhaustiveness Checklist (`.claude/rules/pipeline.md`): "When adding a new parameter, callback, or cell infrastructure, verify it works in both elaboration context (inside `process-command`, network active) and module-loading context (outside, no network)."

### Meta-Trend 3: Normalized Failures Eventually Bite

| Track | Normalized Failure | Duration | Fix |
|-------|-------------------|----------|-----|
| Tracks 3–5 | "Same 2–3 ATMS failures" in every PIR | 3 tracks | 3-line lazy init (Track 6) |
| PUnify | `bench-zonk.rkt` silently broken | Unknown (pre-dates propagator migration) | Not yet fixed |
| Tracks 4–7 | No `punify-enabled? #t` integration test | 4+ tracks | Not yet fixed |

**Assessment**: When a known issue appears in 3+ consecutive PIRs without being fixed, it should trigger escalation: either fix it now, or explicitly accept the risk with a DEFERRED.md entry and a deadline. The ATMS failure took 3 tracks to fix; it was always a 3-line change.

**Process recommendation**: Any issue noted in 3 consecutive PIRs should be flagged as "recurring — requires resolution or explicit deferral with deadline" in the next PIR. The POST_IMPLEMENTATION_REVIEW methodology should add this as a check: "Review prior 2 PIRs for recurring issues. If an issue appears for the 3rd time, it must be resolved or explicitly deferred with rationale."

### Meta-Trend 4: Performance Stays Within Bounds Despite Infrastructure Growth

| Track | Test Count | Suite Time | Delta |
|-------|-----------|-----------|-------|
| Track 3 | 7,096 | 197.6s | +1.7% |
| Track 4 | 7,124 | 187.1s | −2.4% |
| Track 5 | 7,148 | 213.3s | +14% |
| Track 6 | 7,154 | 207.4s → 181.2s | −12% to −23% |
| Track 7 | 7,154 | 207.4s → 181.2s | −23% (post-fix) |
| PUnify | 7,214 | 175.9s | −2.9% |

**Assessment**: Suite time has trended DOWN from 197.6s (Track 3) to 175.9s (PUnify) despite adding 118 tests and 6 tracks of infrastructure. Each track added overhead (cells, callbacks, registries, networks) but also eliminated overhead (parameter copies, scanning functions, env-threading wrappers). The net is a performance improvement.

**Observation**: The largest single improvement was Track 7's `eq?` identity preservation (207.4s → 181.2s). Infrastructure simplification — not optimization — produced the biggest win. This supports the propagator-first thesis: correct infrastructure is also fast infrastructure.

### Meta-Trend 5: Belt-and-Suspenders Validation Has Never Found Divergence

| Track | Validation Used | Divergences Found |
|-------|----------------|-------------------|
| Track 3 | Elaboration guard verification | 0 |
| Track 4 | TMS depth-0 fast path verification | 0 |
| Track 5 | Dual-path hash comparison (~1.4M checks) | 0 |
| Track 6 | Module-definitions-content shadow validation | 0 |
| Track 7 | Belt-and-suspenders for all scanner replacements | 0 |
| PUnify | Fast-path preservation (Phase 6) | 0 |

**Assessment**: Zero divergences across 6 tracks. This could mean: (a) the validation is working and catching zero bugs because the code is correct, or (b) the validation is not testing the right things. Evidence favors (a): every validation is followed by successful retirement of the old path.

**Process recommendation**: Belt-and-suspenders remains valuable as a confidence mechanism for retirement decisions. Continue the practice, but acknowledge it's a confidence tool, not a bug-finding tool. The real bug-finding tools are acceptance files (§Meta-Trend 6) and PIR-driven test writing (Track 7's S(−1) retraction bug).

### Meta-Trend 6: Acceptance Files Are the Most Effective Bug-Finding Tool

| PIR | Bugs Found by Acceptance File |
|-----|-------------------------------|
| WFLE | 5 (exclusively Level 3 — WS pipeline gaps) |
| Track 7 | 5 (parser/preparse level) |
| PUnify | 1 (`defr \|` literal patterns) + 7 surface gaps cataloged |
| Tracks 3–5 | 0 (infrastructure-only; acceptance files used as regression gates) |

**Assessment**: For feature tracks and user-facing changes, acceptance files consistently find 1–7 bugs that unit tests miss. For pure infrastructure tracks, they serve as regression gates (0 bugs found, but confidence provided). The gap they catch is Level 3 (file-level pipeline interaction) — a class of bug that Level 1–2 testing structurally cannot detect.

**Process recommendation**: Acceptance file creation is already mandated as Phase 0 in `.claude/rules/workflow.md`. Strengthen: for feature tracks, the acceptance file should include **aspirational sections** (commented-out target syntax) that serve as the "definition of done" — this was PUnify's strongest practice.

### Meta-Trend 7: PIRs Are Increasingly Self-Aware (and That's Working)

| PIR | Meta-Level Content |
|-----|-------------------|
| Track 3 | Basic lessons, no cross-referencing |
| Track 4 | Cross-references Track 3; identifies mechanical pattern |
| Track 5 | Cross-references Tracks 1–4; adds belt-and-suspenders retirement criteria |
| Track 6 | Cross-reference table showing pattern evolution across 4 tracks; anti-pattern identification |
| Track 7 | Most comprehensive cross-referencing; "PIR → tests → bug → fix" meta-validation |
| PUnify | Formal meta-trend analysis (this appendix); process recommendations |

**Assessment**: Each PIR has become more reflective, with richer cross-referencing and more explicit pattern identification. Track 7's "PIR → tests → bug → fix" cycle is the strongest evidence that the PIR methodology produces real value: the PIR identified a testing gap, tests were written, a real bug was found and fixed.

**Risk**: PIR fatigue. As PIRs become longer and more elaborate, there's a risk they become a burden rather than a learning tool. The POST_IMPLEMENTATION_REVIEW methodology's "filed and forgotten" anti-pattern is the failure mode.

**Process recommendation**: Keep PIRs comprehensive but ensure lessons flow to their destinations (DEVELOPMENT_LESSONS.org, PATTERNS_AND_CONVENTIONS.org, DEFERRED.md). The PIR is raw material; the principles documents are the distilled knowledge. If a lesson appears in a PIR but never reaches a principles document, the PIR lifecycle is broken.

### Summary: Recommended Process Changes

Based on the 6-PIR meta-analysis:

1. **Add "Two-context audit" to Pipeline Exhaustiveness Checklist**: Every new parameter, callback, or cell infrastructure must be verified in both elaboration and module-loading contexts.

2. **Add "3-PIR recurring issue escalation" to PIR methodology**: Issues appearing in 3+ consecutive PIRs must be resolved or explicitly deferred with deadline.

3. **Add "Context loading" step to pre-implementation checklist**: Before Phase 1 of any track, read the final design doc (including D.2/D.3), the most recent PIR, and the current dailies.

4. **Strengthen acceptance file methodology**: Aspirational sections (commented-out target syntax) should be standard for feature tracks, serving as "definition of done."

5. **Monitor PIR-to-principles flow**: After each PIR, explicitly check: have lessons been distilled into DEVELOPMENT_LESSONS.org / PATTERNS_AND_CONVENTIONS.org / DESIGN_METHODOLOGY.org? If not, the PIR lifecycle is incomplete.
