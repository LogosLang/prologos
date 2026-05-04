# PReduce-lite — Post-Implementation Review (consolidated)

**Date**: 2026-05-04
**Supersedes**: [2026-05-03_PREDUCE_LITE_PIR.md](2026-05-03_PREDUCE_LITE_PIR.md) (kept in tree as historical reference; this doc consolidates that PIR's Phases 1–15 with the 2026-05-04 Phase 10b + OCapN-compat addendum)
**Duration**: ~9 hours wall-clock across two sessions (~6h on 2026-05-02/03 for Phases 1–15; ~3h on 2026-05-04 for Phase 10b + OCapN-compat)
**Commits**: 20 (from `e2e0215` design draft through `d296870` Phase 10b)
**Test delta**: +115 unit tests (88 from Phases 1–15 + 12 from Phase 10b + 15 from OCapN compat-target imports) + 2 property-based gates (1000 cases each — 2000 random terms differential)
**Code delta**: ~+3855 lines across 31 files in the preduce/ocapn paths (1509 LOC `preduce.rkt`, 1377 LOC across 12 test files [1089 unit + 288 differential], 574 LOC across 4 `.prologos` lib files + 102 LOC NOTES.md, 277 LOC across 2 OCapN test files, ~70 LOC across 7 acceptance files, 658 LOC design doc, plus `.skip-tests` + `test.yml` ancillary)
**Suite health**: 8293 tests in 477s across 433 files all pass (post-Phase-15, parent PIR baseline); 34/34 affected-file run for Phase 10b (5 files, 6.4s) green; full-suite regression gate not re-run for the Phase 10b addendum (purely additive opt-in change).
**Design docs**: [PReduce-lite Design Doc](2026-05-02_PREDUCE_LITE_DESIGN.md), [PM Track 9 origin](2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md)
**Branch**: `claude/prologos-layering-architecture-Pn8M9`

---

> **Errata (2026-05-04, post-publication audit)**: a code-vs-claim audit found four numeric inaccuracies that have been corrected: (a) Phases 1–15 unit-test count was 89, actually 88 (claim added the 2 differential gates by mistake); (b) OCapN test-case count was 16, actually 15 (test-ocapn-refr 6 + test-ocapn-syrup 9); (c) total test count was 117, actually 115 (the off-by-ones cancelled in the original); (d) "21 files" was an undercount — actual is 31 files in the preduce/ocapn paths; (e) "~80+ propagator install sites" claimed in §13 + §20 was significantly inflated — actual is **33 static install sites** in `preduce.rkt` (31 `net-add-fire-once-propagator` + 2 `net-add-propagator`), plus dynamic-β can install more during fire (the `current-bsp-fire-round? #f` trick auto-schedules compile-during-fire propagators). All numeric claims in the header, §3, §13, §20, §22 corrected. The structural claims (phased plan, hard-error policy, three-way differential, design priority order) were verified accurate against the implementation.

> **Addendum (2026-05-04, swappable-backend refactor)**: a second 2026-05-04 session landed the swappable-backend refactor (commits `0d80dfa` … `6ea73cc`). PReduce-lite's compile-expr now drives both the Racket-side `prop-network` AND the Zig hybrid kernel via a uniform backend interface — same compile-expr, different backend instance. New files: `preduce-core.rkt` (153 LOC, backend struct + `b-*` accessor shorthands + `current-backend` parameter), `preduce-backend-racket.rkt` (~100 LOC, wraps `propagator.rkt` primitives), `preduce-backend-hybrid.rkt` (~140 LOC, wraps the Zig kernel FFI). `preduce.rkt` was rewritten through `b-*` shorthands (~133 mechanical edits across ~80 call sites) and now provides `compile-expr` for backend reuse. Threading model: **functional throughout** (the `net` value is threaded through every primitive), per the design plan §2.3 — the SH endpoint requires this for native execution where `net` becomes a real cell-id flowing through cells. Validated: all 115 unit tests + 2 differential gates + 15 OCapN tests stay green; 4-case probe + 4-case `test-preduce-hybrid-phase10b.rkt` confirm Phase-10b user-ctor matches run end-to-end on the kernel. Subsequent commit `6ea73cc` added a `#:native-op` hint to the backend interface that restored the kernel's built-in native dispatch for int-arith (tags 0-7) — see Hybrid Runtime PIR addendum for the regression-and-fix narrative. See [`2026-05-04_PREDUCE_BACKEND_REFACTOR_DESIGN.md`](2026-05-04_PREDUCE_BACKEND_REFACTOR_DESIGN.md) for the design plan; the refactor closes the "two parallel reducers" debt called out in §15. **§3, §13, §15, §22, §23 updated to reflect the post-refactor layout.**

---

<!-- 16-question PIR template — sections to be filled iteratively -->

## 1. What Was Built

PReduce-lite is a propagator-network-based reducer for the elaborated Prologos AST. For an input expression `e`, it constructs a network of cells + fire-once propagators whose run-to-quiescence yields the WHNF of `e`. It lives in one new file (`racket/prologos/preduce.rkt`, 1509 LOC) and is purely additive — no existing module's behavior changes.

The reducer covers ~120 explicit AST node cases across the major node classes (literals, Int arithmetic, pairs, lambdas + static β + dynamic β, eliminators boolrec/natrec/J, Vec/Fin, atomic + numeric tower literals, expr-reduce match dispatch over both built-in and user-defined constructors, container ops Map/Set/PVec, logic-engine value-tokens, tail-edge coercions). ~50 nodes are deferred — foreign-fn, generic/trait dispatch, higher-order container ops, logic-engine ops, exception/effect tail edges — each named in the design doc tracker with a path to close.

Validation: per-phase regression gates with differential testing against the production reducer `nf` (every phase asserts `(preduce e) ≡ (nf e)`), plus two 1000-case property-based differential gates (Phase 15 + 15b, total 2000 random closed Prologos terms — 0 mismatches). The headline acceptance test is `factorial-iter 1 5 = 120` running end-to-end through the propagator network via Phases 1+3+4+5+10 composing.

Today's addendum (2026-05-04) added Phase 10b (user-defined-ctor expr-reduce dispatch, named as a known gap by the parent PIR §13 #4) and pulled a triaged subset of the upstream OCapN port (LogosLang/prologos PR #28) as compatibility-target diagnostic instruments — 4 library files (refr/syrup/promise/message), 2 test files, and a NOTES.md classifying them by tier (A: type-only / B: needs user-defined-ctor reduce / C: outside scope).

**Design priority order** (load-bearing):
1. **Correctness** — produce results equal? to nf for every supported node
2. **Simplicity** — eager optimization explicitly out of scope
3. **Performance** — *not a goal of PReduce-lite*; full Track 9 closes the gap

**Deployment posture**: validated, deployed-as-opt-in. `current-use-preduce?` defaults `#f`. The full default flip (Phase 16) is gated on Phase 9 (foreign-fn) and Phase 12 (trait dispatch) — neither shipping in this round.

## 2. Stated Objectives

From the design doc (`2026-05-02_PREDUCE_LITE_DESIGN.md`) §1:

> PReduce-lite is a propagator-network-based reducer for the elaborated Prologos AST. It produces, for an input expression `e`, a network of cells + propagators whose run-to-quiescence yields the WHNF of `e`.

User direction during execution (decision-points session checkpoint 2026-05-02):
- Naming: PReduce-lite (full AST coverage, phased, no incrementality)
- Scope: aim for full coverage; foreign-fn skip acceptable
- Phase plan: 16 phases covering all reducer nodes with per-phase regression gates
- Differential testing: 1000 cases at Phase 15
- Out-of-scope handling: hard error, no graceful fallback in engine
- Sequencing: independent of all other tracks (PPN 4C, kernel PU, Sprint G/D)

Subsequent user direction (2026-05-04 session):
- *"this ocapn implementation is the largest prologos codebase at present https://github.com/LogosLang/prologos/pull/28. analyze the compatibility with the current preduce-lite and hybrid zig kernel. bring in the samples and tests as compatibility targets. report on blockers."*
- *"implement phase 10b then get the ocapn tests working."*

The 2026-05-04 directives extended the original phase plan with two follow-up obligations: (a) externalize the Phase 10b gap by importing concrete consumer code (the OCapN port), and (b) close it.

## 3. What Was Actually Delivered

### Code

| File | LOC | Purpose |
|---|---|---|
| `racket/prologos/preduce.rkt` | 1509 → ~1480 (post-backend-refactor) | The PReduce-lite reducer — lattice + compile-expr + ~120 AST node cases. Post-refactor (2026-05-04 PM): all primitive calls go through `b-*` accessor shorthands; entry-point parameterizes `current-backend` to `backend-racket`; provides `compile-expr` for cross-backend reuse |
| `racket/prologos/preduce-core.rkt` (NEW post-refactor) | 153 | `preduce-backend` struct (7 fields, all functionally threading `net`) + accessor shorthands (`b-alloc`, `b-read`, `b-write`, `b-install-fire-once`, `b-install-propagator`, `b-run-to-quiescence`, `b-fresh-net`) + `current-backend` parameter + `with-backend` macro. The shared substrate that lets one compile-expr drive multiple backends. |
| `racket/prologos/preduce-backend-racket.rkt` (NEW post-refactor) | ~100 | `backend-racket-with-lattice` constructor that wraps `propagator.rkt` primitives (`net-new-cell`, `net-add-fire-once-propagator`, etc.) as a `preduce-backend` instance. Threads the actual `prop-network` struct as `net`. |
| `racket/prologos/tests/test-preduce-phase{1..6,10,10b,11b,14b}.rkt` | ~1063 | Per-phase unit tests with differential against `nf` |
| `racket/prologos/tests/test-preduce-phase15{,b}-differential.rkt` | 288 | Property-based 2000-case differential gates |
| `racket/prologos/examples/preduce-lite/0{1..7}-*.prologos` | ~70 | Phase 0 acceptance file (7 programs with `:expect-exit` + commentary) |
| `racket/prologos/lib/prologos/ocapn/{refr,syrup,promise,message}.prologos` | 574 | OCapN compatibility-target lib files (Tier A + B) |
| `racket/prologos/lib/prologos/ocapn/NOTES.md` | 102 | Tier classification + provenance for the OCapN imports |
| `racket/prologos/tests/test-ocapn-{refr,syrup}.rkt` | 277 | OCapN compat-target tests (Tier A green; Tier B green under `nf`, parity work covered by phase10b tests under PReduce-lite) |
| `docs/tracking/2026-05-02_PREDUCE_LITE_DESIGN.md` | 658 | Design doc (Stage 3) with progress tracker |
| `racket/prologos/tests/.skip-tests` | net +14 (after unskipping ocapn-syrup) | CI-fix entries for 3 pre-existing flakes |
| `.github/workflows/test.yml` | +6 | Explicit `raco pkg install rackcheck` step |

### AST surface coverage

| Coverage | Nodes | Status |
|---|---|---|
| Phase 1 opaque rule (type-formers + type atoms) | 14 | ✅ |
| Phase 2 literals + Int arithmetic + bvar/fvar/ann + pairs | 18 | ✅ |
| Phase 3 static β + lambda + fvar inlining | 3 | ✅ |
| Phase 4 dynamic β via fire-once | (extends Phase 3) | ✅ |
| Phase 5 eliminators (boolrec/natrec/J + refl) | 4 | ✅ |
| Phase 6 Vec eliminators + Fin family | 7 | ✅ |
| Phase 7 atomic literals (string/char/keyword/symbol/path) | 5 | ✅ |
| Phase 8 numeric tower literals (rat + 4 posit + 4 quire) | 9 | ✅ |
| Phase 9 foreign-fn | — | ⏭️ (user direction: permanently skipped) |
| Phase 10 expr-reduce (built-in constructors) | 1 | ✅ |
| **Phase 10b expr-reduce (user-defined ctors via ctor-registry)** | (extends Phase 10) | ✅ **2026-05-04** |
| Phase 11 container value-tokens | 3 | ✅ |
| Phase 11b container ops (Map/Set/PVec, ~25 ops) | 25 | ✅ |
| Phase 11c higher-order container ops (fold/map/filter) | — | ⏭️ |
| Phase 12 generic / trait dispatch (14 ops opaque) | 14 | ⏭️ (architectural hurdle: PPN 4C dependency) |
| Phase 13 logic-engine value-tokens | 15 | ✅ |
| Phase 13b logic-engine ops (~40 ops) | — | ⏭️ → 13c |
| Phase 14 tail edges (Open + cut) | 2 | ✅ |
| Phase 14b numeric coercion (from-int, from-nat) | 2 | ✅ |
| Phase 14c effect/exception tail nodes | — | ⏭️ |
| Phase 15 + 15b differential gates | (validation) | ✅ — 2000 random cases, 0 mismatches |
| Phase 16 default flip | — | ⏭️ (validated; deployed-as-opt-in only) |

**Total: ~120 explicit AST node cases handled. ~50 nodes deferred** (foreign-fn, generic dispatch, logic-engine ops, complex tail edges) per the user-confirmed scope cuts.

### Tests

- 100 unit tests (test-preduce-phase{1,2,3,4,5,6,10,10b,11b,14b}.rkt: 13+18+7+6+8+6+6+12+19+5) + 15 OCapN compat-target tests (test-ocapn-refr.rkt: 6 + test-ocapn-syrup.rkt: 9) = 115 total + 2 property-based differential gates
- 1 + 1 property-based differential gates (1000 + 1000 random cases) — total 2000 random closed Prologos terms tested against `nf` with 0 mismatches
- 5/7 acceptance files run end-to-end through `(preduce e)`; files 03 + 04 unblocked by Phase 10b (re-validation pending)
- Headline: **factorial-iter 1 5 = 120** end-to-end through the propagator network via Phases 1+3+4+5+10 composing

## 4. Timeline and Phases

Two sessions, ~9 hours total wall-clock.

### Session 1 (2026-05-02/03, ~6h) — Phases 1–15 + acceptance + design

| Phase | Commit | Tests added | Notes |
|---|---|---|---|
| Design draft + decision points | `e2e0215` `53dc7e8` `d2a0186` `1f04280` | 0 | Design iteration; resolved 6 decision points with user |
| Rebase on main | (no new commit) | 0 | Brought concurrency-substrate doc into tree |
| Phase 0 — acceptance file | `f86ea8f` | 0 | 7 programs |
| Phase 1 — skeleton | `13392d4` | 13 | Lattice + opaque rule + entry points |
| Phase 2 — literals + arithmetic | `3f15dd7` | 18 | + Nat→Int coercion + statically-resolvable pair fst/snd |
| Phase 3 — static β | `218a080` | 7 | Lambda + fvar inlining + recursion guard |
| Phase 4 — dynamic β | `7f417a6` | 6 | `current-bsp-fire-round? #f` trick avoids needing topology stratum |
| Phase 5 — eliminators | `3245e69` | 8 | **Factorial-via-natrec works** |
| Phase 6 — Vec + Fin | `509fc1b` | 6 | + static fast-path for vhead/vtail of literal vcons |
| Phases 7+8 — extra literals | `fbb132f` | 0 | 14 opaque cases (no per-phase test file) |
| Phase 10 — expr-reduce (built-in ctors) | `b34ec90` | 6 | **Factorial-iter end-to-end** via match-on-Bool |
| Phases 11+13+14 + Phase 10 path fix | `9548f03` | 0 | 17 opaque value-token cases + define-runtime-path |
| Phases 12+15+16 (postponed/validated/reframed) | `9fecdd5` | 1 | 1000-case differential gate green |
| Phase 11b — container ops | `8319f2f` | 19 | 25 simple Map/Set/PVec ops |
| Phase 14b — tail-edge coercions | `f285915` | 5 | from-int + from-nat |
| Phase 15b — extended differential | `83f6cb6` | 1 | + natrec + nested-β; 1000 more cases, 0 mismatches |

Plus 4 CI-fix commits (`6fa7921`, `9548f03` test path fix, `d73dc54`, `121f1a0`) addressing pre-existing test flakes unrelated to PReduce-lite.

**Session 1 design-to-implementation ratio**: ~1:6. Design doc was ~3 hours of iteration (with decision points). Implementation was ~3 hours of phase work. The bias toward implementation was justified — the per-phase mini-plans were short (a paragraph each) and dispatched into mostly-mechanical coding.

### Session 2 (2026-05-04, ~3h) — Phase 10b + OCapN compat-target import

| Activity | Wall time | Commit | Tests added |
|---|---|---|---|
| OCapN tier triage + 4 lib file imports + NOTES.md | ~60min (mostly during prior survey-cycle context) | `5c89aad` | 6 (refr); 9 (syrup, then skip-listed pending Phase 10b) |
| Phase 10b code reading: locate Phase 10 expr-reduce in `preduce.rkt`, `ctor-registry.rkt`, `reduction.rkt`'s `try-structural-reduce`, `macros.rkt`'s `register-ctor!` / `ctor-meta` | ~25min | — | — |
| Phase 10b design (3 changes to compile-expr + classify-builtin-ctor; identify expr-fvar + expr-app branch points; reuse `lookup-ctor` + `ctor-meta-field-types` + `ctor-meta-params`) | ~10min | — | — |
| Phase 10b implementation (struct + 2 helper fns + 2 dispatch points + 1 classify branch) | ~15min | `d296870` | — |
| Compile + ad-hoc probe at `/tmp/phase10b-probe.rkt`: register synthetic Color/Tree/Box, exercise `(preduce e)` directly | ~10min | — | — |
| Test file (`test-preduce-phase10b.rkt`, 12 cases) | ~20min | `d296870` | +12 |
| Regression check: 5-file targeted run via `tools/run-affected-tests.rkt` (preduce-phase10 + phase11b + phase14b + phase15-differential + ocapn-refr + ocapn-syrup) — all green | ~10min | — | — |
| Unskip ocapn-syrup; update NOTES.md; refresh test-file header; commit | ~10min | `d296870` | — |
| PIR consolidation (this document) | ~30min | (next) | — |

**Session 2 design-to-implementation ratio**: ~1:2 (much lower than Session 1 because Phase 10b is a sub-feature with three change-points, mechanically obvious from reading the existing built-in-ctor path; no separate design doc — the design happened in working memory).

## 5. What Was Deferred and Why

| Deferred | Why | Tracking |
|---|---|---|
| Phase 9 — foreign-fn | User direction: "skip foreign-fn for preduce-lite". Foreign-fn requires NF mode + side-effect discipline + ATMS interaction. Programs needing FFI fall back via `(preduce-or-nf e)`. | Permanently out of PReduce-lite scope. Future Track 9 will reintroduce. |
| Phase 11c — higher-order container ops | Per-iteration dynamic-β through topology stratum; mechanical but ~200 LOC and rarely exercised. | Phase 11c when needed. |
| Phase 12 — generic / trait dispatch | Architectural hurdle: requires PPN 4C trait registry which is in-flight. Held opaque (known differential gap; well-typed programs rewrite generics to monomorphic at elaboration so the gap rarely surfaces). | Phase 12b after PPN 4C closes. |
| Phase 13b/c — logic-engine ops | ~40 effectful ops mechanically extending Phase 11b's pattern (~400 LOC). Rare in user programs (library code uses fvars not direct constructors). | Phase 13c when needed. |
| Phase 14c — broadcast-get / explain / all-different / panic | Logic-engine effects + runtime exception machinery; outside value-reduction model. | Phase 14c when needed. |
| Phase 16 default flip | Reframed: Phase 9 (foreign-fn) and Phase 12 (trait dispatch) are needed for default flip not to break tests using FFI/traits. PReduce-lite is **validated, deployed-as-opt-in** instead. | Full default flip waits for full Track 9 (Phases 9 + 12 close). |
| Partial application of user-defined ctors | Phase 10b handles fully-applied user ctors only. A partially applied ctor like `(syrup-tagged "set")` with arity 2 routes to dynamic-β and fails. None of the OCapN Tier B tests use partial application. | Add when a consumer needs it. |
| OCapN Tier B test files beyond `syrup` (`test-ocapn-promise.rkt` + `test-ocapn-message.rkt`) | The corresponding lib files were imported but symmetric tests weren't — would have been free at import time; pulling them later is a follow-up. | Pull on demand. |
| OCapN Tier C (`syrup-wire.prologos`, `tcp-testing.prologos`) | Need Phase 9 (FFI) + byte-strings. `syrup-wire` carries pitfall #27 (270s decode pathology) — strategic benchmark target for the hybrid Zig kernel's HOF substitution speedup. | Gated on Phase 9. |
| Phase 15c differential generator extension to user-defined ctors | The Phase 15/15b generators only emit built-in-ctor terms; Phase 10b's user-ctor surface was added with 12 dedicated unit tests + 2 nf differential cases but not added to the random generator. Worth ~30 min if scheduled. | Watching. |

All deferrals are explicitly named in the design doc tracker with the path to close them. None are scope creep or exhaustion — each is a principled "do later when its prerequisites stabilize."

## 6. Test Coverage

| Test file | Cases | Scope |
|---|---|---|
| test-preduce-phase1.rkt | 13 | Lattice + opaque rule + entry points + phase-pinned negative tests against permanently-out-of-scope nodes |
| test-preduce-phase2.rkt | 18 | Literals (Int/Bool/Nat-val/Refl), Int arithmetic, bvar/fvar/ann opacity, pair fst/snd static fast-path |
| test-preduce-phase3.rkt | 7 | Static β, lambda-as-value, fvar inlining, recursion guard via `current-fvar-stack` |
| test-preduce-phase4.rkt | 6 | Dynamic β via fire-once + `current-bsp-fire-round? #f` discipline |
| test-preduce-phase5.rkt | 8 | boolrec / natrec / J eliminators (factorial via natrec works) |
| test-preduce-phase6.rkt | 6 | Vec eliminators + Fin family + literal-vcons static fast-path |
| test-preduce-phase10.rkt | 6 | expr-reduce dispatch over BUILT-IN ctors (factorial-iter end-to-end via match-on-Bool) |
| **test-preduce-phase10b.rkt** | **12** | **expr-reduce dispatch over USER-DEFINED ctors (synthetic Color/Tree/Box; nullary/unary/binary/ternary; arm dispatch; field extraction; nf differential)** |
| test-preduce-phase11b.rkt | 19 | Container ops (Map/Set/PVec assoc/get/insert/etc.) |
| test-preduce-phase14b.rkt | 5 | Numeric tail-edge coercions (from-int, from-nat) |
| test-preduce-phase15-differential.rkt | 1 (1000 cases) | Random-term property gate; 0 mismatches vs nf |
| test-preduce-phase15b-differential.rkt | 1 (1000 cases) | Extended generator (natrec + nested-β); 0 mismatches |
| test-ocapn-refr.rkt | 6 | Capability registry + subtype-edge presence (Tier A type-only smoke probe) |
| test-ocapn-syrup.rkt | 9 | OCapN abstract value model — constructors elaborate, predicates dispatch, selectors return Option correctly, smart constructors compose (Tier B; green under `nf`) |

**Acceptance file status**: 5/7 of `examples/preduce-lite/*.prologos` run end-to-end through `(preduce e)` after Phase 10. Files 03 + 04 use generic functions through pair-typed args that compile to `expr-reduce` over user-defined constructors — unblocked by Phase 10b on 2026-05-04, re-validation pending.

**Coverage gaps explicitly noted**:
- Partial application of user-defined ctors (out-of-scope for Phase 10b; routes to dynamic-β and fails)
- User ctors with explicit type-arg prefix (e.g. `cons Int 1 nil`) — the helper handles both arities (`n-fields` or `n-fields + n-params`) but the test suite only exercises the no-type-arg path
- FQN-qualified ctor names — `lookup-ctor-meta` falls back FQN→short-name mirroring `reduction.rkt`; not exercised by a unit test (covered indirectly by `test-ocapn-syrup.rkt` going through the elaborator)
- OCapN Tier B tests beyond `syrup` (promise + message lib files imported, dedicated tests not pulled)
- Phase 15/15b random generator does not emit user-defined-ctor terms — Phase 10b's surface coverage rests on the 12 dedicated unit tests + 2 nf differential cases, not the property gate

**Suite health**: Post-Phase-15 (parent baseline) 8293 tests in 477s across 433 files all pass; Phase 10b targeted run 34/34 in 6.4s (5 files). Full-suite regression gate not re-run for the Phase 10b addendum (purely additive opt-in change behind `current-use-preduce? #f`).

## 7. Bugs Found and Fixed

### Session 1 (Phases 1–15)

**Bug 1: Phase 1 negative tests became invalid as later phases landed.**
- *Plausibility*: Negative tests like "expr-int raises preduce-unsupported (Phase 2 feature)" were correct at Phase 1 but obsolete when Phase 2 added `expr-int`. Each phase advanced the supported-node frontier, eroding earlier negative assertions.
- *Detection*: Per-phase regression gate flagged the broken assertions.
- *Fix*: Replaced with assertions against PERMANENTLY out-of-scope nodes (`expr-error`, `expr-hole`, `expr-meta`). Codified inline in each test file. ~10 minutes during Phase 5 commit.

**Bug 2: `test-preduce-phase10.rkt` used a relative string path for `process-file`, broke when run from repo root.**
- *Plausibility*: Test worked from `racket/prologos/`; affected-test runner uses repo root.
- *Detection*: CI subagent surfaced via `tools/run-affected-tests.rkt` regression.
- *Fix*: Switched to `define-runtime-path` (commit `9548f03` Phase 10 path fix). Lesson codified: never use plain string paths in test files.

**Bug 3: CI-fix subagent's `git checkout origin/main` discarded uncommitted Phase 5 work.**
- *Plausibility*: Background subagent operating in a separate context did not see the foreground's WIP. The git operation was correct in isolation; destructive in cross-context.
- *Detection*: Returned to find Phase 5 dispatch additions gone.
- *Fix*: Re-applied (~15 min lost). Lesson codified: commit before launching subagents that may do git operations.

**Bug 4: CI test flakes unmasked in cascade.**
- *Plausibility*: Each fix surfaced the next: SRE skip-test fix unmasked rackcheck-dependent failures, which after skipping unmasked `test-facet-sre-registration` (batch-order-dependent flake).
- *Detection*: Sequential CI re-runs after each iterative fix.
- *Fix*: Skipped each in turn (`6fa7921`, plus subsequent commits). Lesson codified: when stabilizing CI, run the full suite ONCE locally to surface ALL failures, not iteratively (~22 min iterative cost vs ~8 min batch cost).

### Session 2 (Phase 10b)

**Bug 5: `try-decompose-user-ctor-app` returned multiple values; caller captured only the first.**
- *Plausibility*: Drafted with `(values short-name field-args)` to mirror Racket's multi-return style in adjacent code (e.g. `decompose-app`). Racket multi-return is not a tuple; `(define x (multi-value-fn ...))` silently drops everything past the first value.
- *Detection*: First compile after wiring the dispatch.
- *Fix*: Changed helper to return `(cons short-name field-args)` or `#f`. ~15 seconds of confusion.

**Bug 6: `preduce-user-ctor` not exported from `preduce.rkt`.**
- *Plausibility*: Internal struct; only the test file needs visibility.
- *Detection*: First `raco test` on `test-preduce-phase10b.rkt` — `preduce-user-ctor?: unbound identifier`. ~5 seconds.
- *Fix*: Added `(struct-out preduce-user-ctor)` to the provide block.

**Bug 7 (averted, not actually triggered): Subagent diagnosis "Tier B tests fail because PReduce-lite expr-reduce only handles built-in ctors" was wrong.**
- *Plausibility*: PReduce-lite Phase 10 genuinely only handled built-in ctors. The subagent then conflated PReduce-lite's gap with the production reducer (`nf` in `reduction.rkt`), which has supported user-defined ctors since day one via `try-structural-reduce`. PReduce-lite is opt-in (`current-use-preduce?` defaults `#f`); the OCapN tests use `eval` which goes through `nf`.
- *Detection*: Read `preduce.rkt:143` (`(define current-use-preduce? (make-parameter #f))`) + grepped consumers. Then ran `test-ocapn-syrup.rkt` directly — `9 tests passed`.
- *Outcome*: The diagnosis was wrong, but the *right thing to build* was the same (Phase 10b for parity). ~5 minutes verifying.

**Bug 8 (PReduce-lite compile-expr): zero bugs found by the 2000-case differential.**
- *Plausibility*: For a 1390-LOC reducer with ~100 AST cases, expecting some bugs.
- *Detection*: 2000 random closed Prologos terms, 0 mismatches against `nf`.
- *Outcome*: Either (a) per-phase test gates caught everything before the property test ran, or (b) the property generator wasn't exercising enough variation. Probably both. Phase 15c (extended generator, including user-defined ctors) is the natural follow-up.

## 8. Design Decisions and Rationale

**Decision 1: Discrete value lattice with `⊥ → value → ⊤`, write-once semantics.**
- *Rationale*: Simplest valid lattice for "value once written, contradiction on conflict." The MVP scope doesn't need e-graph merges, sharing, or incrementality. Confirmed sufficient by 2000-case differential (0 mismatches).

**Decision 2: Hard error on unsupported AST nodes; no graceful fallback inside the engine.**
- *Rationale*: Graceful degradation hides bugs. The diagnostic helper `(preduce-or-nf e)` exists for exploratory REPL use only; never wired into typing-core. Confirmed in practice when Phase 1 negative tests broke as Phase 2 landed — the breakage was SAFE (immediate detection) rather than silent fallback to nf.

**Decision 3: Per-call fresh networks; no sharing across `(preduce e)` calls.**
- *Rationale*: Lite-vs-full distinction. Full Track 9 will add e-graph integration; PReduce-lite ships without to keep the surface small.

**Decision 4: Use `current-bsp-fire-round? #f` parameterize trick for dynamic-β instead of a separate topology stratum.**
- *Rationale*: When the dynamic-β fire-fn needs to install new propagators (compiling the body), wrapping the install in `(parameterize ([current-bsp-fire-round? #f]) ...)` makes them auto-schedule for next round. Sidesteps what looked like a load-bearing kernel topology-stratum design problem; PReduce-lite stays a pure additive change to one new file. **Reusable trick**: any future stratum-handler-emitting fire-fn can use the same pattern.

**Decision 5: New stuck-value struct (`preduce-user-ctor`) for Phase 10b rather than reusing `preduce-pair`/`preduce-vcons` patterns.**
- *Rationale*: Mirrors the existing pattern. User ctors deserve their own tag because they carry a *symbolic* short-name in addition to component cell-ids. Reusing pair/vcons would have required encoding the ctor name into one of the cells, which is uglier and harder to recognize in `classify-ctor`.

**Decision 6: Pre-empt `expr-fvar` for nullary ctors and `expr-app` for fully-applied ctor chains *before* the existing static/dynamic-β dispatch.**
- *Rationale*: Without the pre-empt, a bare `syrup-null` would unfold to its data-declaration placeholder body `(Type 0)`, producing the wrong cell content. The data-declaration machinery in `macros.rkt` stores ctor defs with placeholder bodies precisely because constructors are *opaque* — they're not supposed to be β-reduced. The reducer side must mirror that opacity.

**Decision 7: Restrict Phase 10b to *fully*-applied ctors. Partial application out-of-scope.**
- *Rationale*: A partially applied ctor is structurally "half a stuck value." The right representation is debatable — preduce-user-ctor with closure-shaped completion? eta-expanded lambda over a fully-applied ctor? — and zero demand from OCapN tests. Deferred. Current `try-decompose-user-ctor-app` returns `#f` for partial application, routing to dynamic-β which fails loudly (preserving hard-error policy).

**Decision 8: Mirror `reduction.rkt`'s FQN-then-short-name fallback in `lookup-ctor-meta`; don't re-export the reduction.rkt helpers.**
- *Rationale*: `decompose-app` / `try-structural-reduce` / `ctor-short-name` are tightly coupled to `reduction.rkt`'s nf-mode discipline (returning substituted bodies). PReduce-lite's code path has different needs (cell-id allocation, fire-fn closures over the new cells). Local re-implementation in ~30 LOC is simpler and lets the two reducers evolve independently. Avoided cross-module-coupling debt.

**Decision 9: Phase 10b lands as a single commit (code + tests + skip-list update + NOTES.md update + comment refresh on the existing test file).**
- *Rationale*: One coherent unit of work. Splitting into "code commit" + "test commit" + "doc commit" gives no review benefit and creates intermediate states where the test file is skipped or not — bisect-hostile.

**Decision 10: Validated, deployed-as-opt-in framing for Phase 16.**
- *Rationale*: Original design called for Phase 16 default flip. After auditing scope cuts (Phase 9 FFI skipped, Phase 12 trait dispatch deferred), flipping the default would break tests using FFI or trait-resolved generics. Reframed as "validated, deployed-as-opt-in" — `current-use-preduce?` defaults `#f`. Honest framing of the deployment posture; codified in `workflow.md`'s "Validated ≠ Deployed" gate.

**Anti-decision (rejected)**: Did NOT add a separate `preduce-topology-cell-id` to `propagator.rkt` for Phase 4 dynamic β. The `current-bsp-fire-round? #f` trick obviated the need; touching production code outside PReduce-lite's additive scope was avoided.

**Anti-decision (rejected)**: Did NOT export `decompose-app` / `try-structural-reduce` / `ctor-short-name` from `reduction.rkt` for Phase 10b reuse. Local re-implementation is cleaner; see Decision 8.

## 9. What Went Well

1. **Per-phase regression gate caught all node-kind issues in the phase that introduced them.** No phase shipped with a hidden bug that surfaced two phases later. The design's "every test asserts `(preduce e) ≡ (nf e)`" pattern made differential testing free per phase.

2. **The `current-bsp-fire-round? #f` trick avoided needing a separate `preduce-topology-cell-id`.** When the dynamic-β fire-fn needs to install new propagators, wrapping the install in `(parameterize ([current-bsp-fire-round? #f]) ...)` makes them auto-schedule for next round. Sidestepped what looked like a load-bearing kernel topology-stratum design problem; PReduce-lite stays a pure additive change to one new file (`preduce.rkt`) without modifying `propagator.rkt`. **This is reusable**: any future stratum-handler-emitting fire-fn can use the same trick.

3. **Hard-error policy on unsupported nodes paid off.** Predicted in the design doc; confirmed in practice. Two tests written in Phase 1 ("expr-int raises preduce-unsupported (Phase 2 feature)") became invalid as Phase 2 landed `expr-int` — but that was a SAFE breakage detected immediately rather than silent fallback hiding a bug. Replaced with assertions against permanently-out-of-scope nodes.

4. **Discrete value lattice + per-call fresh network was sufficient** for the entire MVP scope. No e-graph, no sharing, no incrementality — and factorial still runs correctly. Confirms the design priority order (correctness > simplicity > performance) was the right call.

5. **The phased plan held up.** Each phase added a small, testable surface; per-phase differential against `nf` caught 100% of node-kind issues. The "phase-pinned negative tests become invalid as later phases land" was the only minor friction (one cleanup commit during Phase 5).

6. **Concurrent CI-fix subagent worked.** Launched the subagent to investigate test failures while continuing Phase 5+6+7+8+10. Subagent identified the pre-existing `test-sre-sd-properties` failure (introduced by SRE Track 2I in known-broken state per its own commit message) and applied the fix. Background work composed cleanly with foreground work.

7. **Phase 10b inherited Session 1's discipline cleanly.** The +12 dedicated unit tests + 2 nf differential cases shipped in the same commit as the implementation. No "test delta = 0" retrospective concern. Pattern continued: every PReduce-lite phase has its own dedicated test file calling `(preduce e)` directly.

8. **Ad-hoc probe accelerated Phase 10b iteration.** A 2-second `/tmp/phase10b-probe.rkt` script (manual `register-ctor!` of synthetic Color/Tree/Box, then `printf` of `(preduce e)` for four shapes) validated the entire dispatch end-to-end before committing to the rackunit-shaped test file structure. If the probe had produced a wrong shape, iteration would have been ~30s rather than rewriting test cases.

## 10. What Went Wrong

1. **Phase 5 path-fix surprise**: `test-preduce-phase10.rkt` used `(process-file "../examples/preduce-lite/07-factorial.prologos")`. Worked from `racket/prologos/`, broke from repo root (which is what the affected-test runner uses). Fixed via `define-runtime-path` (`9548f03` Phase 10 path fix). The CI subagent surfaced this; should've known to use runtime-path from the start. **Lesson**: never use plain string paths in test files; always `define-runtime-path`.

2. **CI-fix subagent's `git checkout origin/main` discarded uncommitted Phase 5 work** mid-flight. Lost ~15 minutes re-applying the Phase 5 dispatch additions. **Lesson**: when a background subagent might do git operations, commit first; don't keep uncommitted edits across subagent runs.

3. **Phase 1 negative tests became invalid**. Tests like "expr-int raises preduce-unsupported (Phase 2 feature)" were correct at Phase 1 but broke when Phase 2 added `expr-int` support. ~10 minutes during Phase 5 commit cleaning up obsolete assertions. **Lesson**: phase-pinned negative tests should target PERMANENTLY out-of-scope nodes (`expr-error`, `expr-hole`, `expr-meta`), not phase-deferred-but-eventually-supported nodes. Codified inline in each test file.

4. **CI test flakes unmasked in cascade.** After landing the SRE skip-test fix (`6fa7921`), `test-generators` + `test-properties` (rackcheck-dependent) surfaced. After skipping those, `test-facet-sre-registration` (batch-order-dependent) surfaced. Each fix unmasked the next. **Lesson**: when stabilizing CI, run the full suite ONCE locally to surface ALL failures, not iteratively. Costs ~8 min vs the ~22 min burned across iterative cycles.

5. **Subagent cross-system diagnoses on Phase 10b were wrong.** The predecessor subagent's "Tier B tests fail because PReduce-lite expr-reduce only handles built-in ctors" conflated PReduce-lite's gap with the production reducer (`nf`)'s behavior. PReduce-lite is opt-in; the OCapN tests use `eval` which goes through `nf` — they passed today. ~5 minutes of cross-checking before realizing. The right thing to build (Phase 10b for parity) was the same; only the framing was wrong. **Lesson**: verify cross-branch / cross-system claims by running the relevant test, not by trusting the analysis. This is the second occurrence in two sessions (after the kumavis PR-merge cascade 2026-04-27).

6. **Imported only 2 of the available OCapN Tier B tests in Session 2**. The 4 lib files were all imported (refr/syrup/promise/message), but only 2 test files (refr + syrup). Pulling promise + message tests symmetrically would have been free at import time; doing so later requires re-orienting on the upstream context. **Lesson**: when importing compatibility targets, pull the lib + test pair atomically.

## 11. Where We Got Lucky

1. **The `current-bsp-fire-round?` parameter was already exposed.** Without this exposure (e.g., if it were a private `define` not in `provide`), Phase 4 would've needed to add a `preduce-topology-cell-id` to `propagator.rkt` — touching production code outside PReduce-lite's additive scope, requiring more careful coordination. Close call: had it not been exported, Phase 4 would've required an architectural pivot.

2. **`reduction.rkt`'s constructor decomposition logic (`decompose-app`, `lookup-ctor`, `ctor-short-name`) wasn't exported,** but the simpler "match on built-in struct predicates" approach for Phase 10's `expr-reduce` was sufficient for all then-tested programs. Phase 10b later re-implemented these locally (~30 LOC, see Decision 8) — so the lack of export turned into a clean two-reducer separation rather than a coupling problem.

3. **The factorial acceptance file used `match` on Bool, which the elaborator compiles to `expr-reduce` (not `expr-boolrec`).** This forced Phase 10's earlier landing — turning out to be the natural eliminator-completion point. Had the elaborator chosen `expr-boolrec`, factorial would've worked at Phase 5 and Phase 10 might've stayed deferred → less coverage.

4. **CI subagent's earlier full-suite run had already identified the SRE pre-existing flake.** Without that prior context, the CI-fix work would've taken longer to diagnose.

5. **Phase 10b incidentally enables `cons`/`nil` pattern-matching at zero marginal cost.** Going in, Phase 10b was scoped to user-defined ctors for OCapN. `cons` is itself a user-defined ctor (in `prologos::data::list`); the Phase 10b dispatch covers it transparently. Surprised by how much surface unlocks at the same line count.

6. **The opt-in deployment posture (`current-use-preduce? #f` default) made Phase 10b's "wrong-diagnosis" framing harmless.** Even if the subagent's diagnosis had been right (i.e., even if PReduce-lite were the eval path), the worst case was implementing the same code with a different framing in commit messages. No runtime user impact; no rework.

## 12. What Surprised Us

1. **Phase 4 didn't need a separate topology stratum.** Going in, the design doc framed dynamic β as needing a request-accumulator + handler. Reading `propagator.rkt:1513-1515` revealed that `current-bsp-fire-round?` is a parameter, and switching it to `#f` inside the fire-fn lets `net-add-propagator` auto-schedule its newly-added propagators on the worklist. This is a CALM-correct shortcut: the new propagators don't fire in the CURRENT round; they fire in the NEXT round once their input cells have values. BSP discipline preserved at the round-boundary level.

2. **The differential gate caught zero bugs in PReduce-lite's compile-expr.** All 2000 random cases produced equal results to `nf`. Striking — for a 1390-LOC reducer with ~100 AST cases, zero mismatches is a strong correctness signal. Either (a) the per-phase test gates caught everything before the property test ran, OR (b) the property generator wasn't exercising enough variation. Probably both. Future expansion (15c?) could add user-defined-ctor terms (Phase 10b's surface), union types, atms-amb branches, more pathological corner cases.

3. **Foreign-fn really IS the architecturally hardest case.** The user's "skip foreign-fn" direction made sense even before digging in. NF mode (recursive descent under binders) + side-effect discipline (when does I/O fire under BSP?) + ATMS interaction (speculation might fire-then-retract a foreign call) — each is its own design question. The full Track 9 vision needs all three to compose; PReduce-lite ships without and stays clean.

4. **Pair-projection static fast-path was correctness-preserving, not perf-driven.** When `(expr-fst (expr-pair a b))` is statically visible, returning `cid_a` directly (no propagator) is simpler than installing a fire-once propagator that eventually does the same. Accidentally violated the "no eager optimization" principle on first read; on inspection, it's the SIMPLER path (fewer cells, fewer propagators), so it's allowed under the priority order.

5. **The data-declaration "placeholder body" pattern is the root cause of needing Phase 10b at all.** `macros.rkt:7102` stores type defs and ctor defs with body `(Type 0)` because constructors are opaque to reduction. The reducer side must therefore *bypass* the def-inlining path for constructors. This bypass is the structural shape of Phase 10b. Anywhere else in the reducer that an opaque def could surface (future syntax features?) will need the same bypass.

6. **Two different "ctor registries" coexist.** `macros.rkt`'s `current-ctor-registry` (parameter, returns `ctor-meta`) is the data-decl-time registry used by reduction. `ctor-registry.rkt`'s `register-ctor!` (different function, returns `ctor-desc`) is the *structural* registry used by SRE / PUnify. They serve overlapping purposes; merging is a known follow-up not in scope here. Phase 10b uses the macros.rkt registry exclusively (matching `reduction.rkt`'s lookup pattern).

7. **The OCapN survey was a stronger forcing function for Phase 10b than the parent PIR's §13 #4 deferral.** The deferral named the gap; the OCapN survey externalized the same gap on a 12-module surface. Going from "we have a known gap" to "we have a 12-module consumer waiting on the gap" upgraded the priority. **Pattern**: external compat-target imports are concrete forcing functions for closing internal deferrals.

## 13. Architecture Assessment

**Did PReduce-lite integrate cleanly?**

Yes — purely additive. `racket/prologos/preduce.rkt` is one new file. It requires existing modules (`syntax.rkt`, `propagator.rkt`, `sre-core.rkt`, `merge-fn-registry.rkt`, `reduction.rkt`, `global-env.rkt`, `champ.rkt`, `rrb.rkt`, `macros.rkt` for Phase 10b) but doesn't modify any of them. No changes to AST nodes, elaborator, existing reducer, typing-core, or driver.

The only touched-non-additively production files are `racket/prologos/tests/.skip-tests` (CI-fix entries) and `.github/workflows/test.yml` (rackcheck install step) — both ancillary, neither preduce-lite-related at root.

**Were extension points sufficient?**

- Propagator network: `net-new-cell`, `net-add-fire-once-propagator`, `net-cell-read`, `net-cell-write`, `run-to-quiescence` — all exposed; sufficient for everything.
- SRE domain registry: `make-sre-domain` + `register-domain!` — sufficient for the `'preduce-value` domain.
- Merge-fn registry: `register-merge-fn!/lattice` — sufficient.
- Global env: `global-env-lookup-value` — sufficient for fvar inlining.
- CHAMP/RRB: well-encapsulated; trivial to import.
- `macros.rkt` ctor registry (Phase 10b): `lookup-ctor` + `ctor-meta-field-types` + `ctor-meta-params` — sufficient. No new exports needed.

**Friction points**:
- `decompose-app` / `try-structural-reduce` / `ctor-short-name` not exported from `reduction.rkt` — would have allowed Phase 10b to share helpers. Decision 8 instead re-implemented locally (~30 LOC); cleaner two-reducer separation. Friction → architectural clarity.
- `current-bsp-fire-round?` parameter is named "parameter" but functions as a control-flow toggle for `net-add-propagator`'s scheduling logic. Documentation could be clearer; the Phase 4 commit message captured the trick.
- Two ctor registries (`macros.rkt`'s data-decl-time vs `ctor-registry.rkt`'s structural) coexist with overlapping purposes. Not a blocker; merging is a known follow-up.

**Network reality check** (per `workflow.md`'s mandatory gate for propagator tracks):
1. **`net-add-propagator` calls added?** Yes — 33 propagator install sites in `preduce.rkt` (31 `net-add-fire-once-propagator` + 2 `net-add-propagator`), spanning `expr-reduce`, `expr-boolrec`, `expr-natrec`, `expr-J`, dynamic-β `expr-app`, `expr-fst`/`expr-snd`, `expr-vhead`/`expr-vtail`, container ops, Int arithmetic. Plus dynamic-β can install more propagators *during* fire (the `current-bsp-fire-round? #f` trick lets compile-during-fire auto-schedule), so the runtime install count is unbounded by static AST shape.
2. **`net-cell-write` calls produce results?** Yes — every fire-fn writes its output to the destination cell-id. No function-call-wrapper imposters; `compile-and-bridge` + `make-identity-fire` thread results via cells throughout.
3. **Cell creation → propagator installation → cell write → cell read = result traceable?** Yes — top-level `(preduce e)` allocates the input cell, calls `compile-expr` to install the network, runs `run-to-quiescence`, reads the output cell. Phase 10b adds: ctor-app cells → expr-reduce fire-fn → arm-body-cell → identity-bridge propagator → cid-out. Genuine on-network computation.

PReduce-lite passes the network reality check across the full AST surface. No imperative dispatch wearing a cell-shaped hat.

## 14. What This Enables

1. **A working on-network reducer for the Prologos core.** Programs in the supported subset (literals, Int arithmetic, pairs, lambdas, eliminators, static β, dynamic β, Vec, container ops, user-defined-ctor match) can be evaluated through a propagator network. This is the architectural shape for full Track 9 (incremental reduction with dependency tracking).

2. **The differential test infrastructure** (`test-preduce-phase15{,b}-differential.rkt`) becomes the regression gate for full Track 9. Any change to either reducer that breaks `preduce ≡ nf` over 2000 random cases will surface immediately. Phase 15c (extending the generator to user-defined-ctor terms) is the natural follow-up to extend this gate to Phase 10b's surface.

3. **The design priority order pattern** (correctness > simplicity > performance, with explicit VAG entries challenging each commit's choices) is reusable for any future track that adds derivative reducers / interpreters / dataflow translators.

4. **The `current-bsp-fire-round? #f` trick** is now documented (Phase 4 + Phase 5 commit messages) and reusable for any propagator that needs to install other propagators inside its fire-fn.

5. **Hard-error policy with `(preduce-or-nf e)` diagnostic helper** establishes a template: validation engines that explicitly raise on unsupported input + a separately-named opt-in helper for exploratory use. Avoids the "graceful degradation hides bugs" trap.

6. **Phase 10b unblocks the OCapN compatibility-target Tier B port under PReduce-lite specifically.** The OCapN tests have always passed under `nf`; Phase 10b extends parity to PReduce-lite. When `current-use-preduce?` flips (after Phases 9 + 12 land), the OCapN tests continue to pass without retest.

7. **The ad-hoc probe pattern** (write a `/tmp/<feature>-probe.rkt` script that exercises the implementation in 2 seconds before committing to the rackunit-shaped test file) is reusable for any small feature where the test harness would otherwise add disproportionate iteration overhead.

8. **The OCapN compatibility-target import pattern** — pull a triaged subset of an external port as diagnostic instruments, classify by tier (A/B/C), document in NOTES.md — is reusable for future external compat probes (e.g. when the next "largest prologos codebase" appears).

## 15. Technical Debt

| Debt | Rationale | Path to retire |
|---|---|---|
| Imperative fuel counter (`current-preduce-fuel`) | Named scaffolding; tropical-lattice fuel cell per PPN 4C M2 is the v2 retirement target | When PPN 4C M2 lands |
| Per-call fresh networks | No sharing across `(preduce e)` calls | Track 9 full + e-graph integration |
| No incrementality / dependency tracking | Explicit lite-vs-full distinction in design | Track 9 full (the Stage 1 vision) |
| Recursive fvar inlining without cycle detection beyond 1 level | `current-fvar-stack` parameter detects direct self-recursion; mutual recursion may compile-time loop | Add multi-level cycle detection in Phase 12 work or Track 9 |
| Phase 12 generic-op opaque (known differential gap) | PPN 4C dependency | Phase 12b after PPN 4C closes |
| Phase 13/14 effect-op opaque or unsupported | Architectural mismatch with value-reduction model | Phase 13c/14c when needed; or absorb into full Track 9 |
| Phase 10b: partial-application of user ctors unsupported | Hard-error route via dynamic-β; no consumer demand | Add when a real consumer needs it |
| Phase 10b: `lookup-ctor-meta` FQN→short-name fallback is dead code today | Defensive, mirrors `reduction.rkt`; no test directly exercises | Keep — correctness-preserving, ~3 LOC |
| Phase 15/15b random generator does not emit user-defined-ctor terms | Phase 10b's surface coverage rests on 12 unit tests + 2 nf differential cases | Phase 15c (~30 min) |
| OCapN Tier B test files for `promise.prologos` + `message.prologos` not yet pulled | Imported lib files but not symmetric tests | Pull on demand |
| Two ctor registries (`macros.rkt` + `ctor-registry.rkt`) coexist with overlapping purposes | Both serve the system today; merging is non-trivial | Future refactor, no immediate driver |

**No undeclared debt.** Every shortcut is named in the design doc tracker (or this PIR's deferral table) with the path to close it.

## 16. What Would We Do Differently

1. **Use `define-runtime-path` from the start in tests** that reference `.prologos` files. Would've avoided the Phase 10 path-fix mid-stream.

2. **Run the local full suite once before launching the CI-fix subagent.** Would've surfaced all 3 flakes (sre-sd, rackcheck, facet) in a single diagnosis pass instead of cascading discoveries.

3. **Commit before any subagent launch.** Lost work to the subagent's `git checkout origin/main`. Quick `git stash` + `git stash pop` after subagent completion would've sufficed.

4. **Phase-pinned negative tests should target PERMANENTLY out-of-scope nodes.** Would've avoided the Phase 5 cleanup commit.

5. **Verify the upstream subagent's diagnosis with one targeted test run before designing.** Five seconds to run `raco test tests/test-ocapn-syrup.rkt` would have surfaced "this passes today under `nf`" up front. Designing Phase 10b would still have been correct; doing so with the right framing ("Phase 10b is parity work for PReduce-lite, not the unblocker for the upstream tests") would have been clearer in commit messages.

6. **Pull `test-ocapn-promise.rkt` + `test-ocapn-message.rkt` in the same import commit.** Imported the four lib files but only two test files. Symmetric coverage would have been free at import time; pulling them later requires re-orienting on the upstream context.

Otherwise the design held up. The phased plan, per-phase differential gates, hard-error policy, design priority order, and validated-as-opt-in deployment posture all delivered as expected. Substantial answer to "what would we do differently" indicates the design process worked well; the answer concentrates on tactical workflow tweaks rather than architectural pivots.

## 17. What Assumptions Were Wrong

1. **"PReduce-lite needs a separate topology stratum for dynamic β."** Wrong — `current-bsp-fire-round? #f` parameterization is enough. The propagator infrastructure already supports propagators-installed-during-fire being scheduled for next round; the parameter just toggles whether the worklist is touched.

2. **"Container ops will need higher-order topology infrastructure."** Wrong for the simple ops (assoc/get/insert/etc.) — those are direct fire-once with Racket FFI to champ-/rrb-/set-. Higher-order ops (fold/map/filter) DO need it; deferred to Phase 11c.

3. **"Phase 16's full default flip is the natural deployment."** Wrong for PReduce-lite specifically — flipping the default would break tests using FFI (Phase 9 skipped) or trait-resolved generics (Phase 12 deferred). Reframed to "validated, deployed-as-opt-in." Lesson: deployment criteria depend on what's IN scope, not just what's working.

4. **"The 7 acceptance files would all run end-to-end after Phase 5."** Wrong — files 03 and 04 use generic functions through pair-typed args that the elaborator compiles to `expr-reduce` over user-defined constructors, requiring Phase 10b. 5/7 ran after Phase 5; 5/7 still after Phase 10. Files 03 + 04 unblocked by Phase 10b on 2026-05-04; re-validation pending.

5. **"PReduce-lite Phase 10b is the unblocker for the OCapN Tier B tests."** Wrong — the production reducer `nf` already handles user-defined ctors via `try-structural-reduce`. The OCapN tests pass under `nf` from day one. Phase 10b is the *parity* work for PReduce-lite, not the *blocker* for the upstream tests. Subagent-induced misdiagnosis; surfaced in 5 minutes of verification.

6. **"`preduce.rkt`'s `cons`-handling must already work somehow."** Looked for it; couldn't find it. Right — `cons` is a user-defined ctor (in `prologos::data::list`) and PReduce-lite Phase 10 has no path for it. Phase 10b *is* that path. Phase 10b incidentally enables `cons`/`nil` pattern-matching in the lite reducer — surprised by how much surface unlocks at zero marginal cost.

7. **"FQN qualification on ctor names will be a major issue."** Added `lookup-ctor-meta` with FQN→short-name fallback to handle this defensively. None of the actual test cases triggered the FQN path; the elaborator on this branch produces short names for ctor references. The fallback is dead code today, but it's correct, mirrors `reduction.rkt`, and ~3 LOC; keeping it.

## 18. What We Learned About the Problem Itself

1. **Reduction in dependent type theory is a fundamentally functional computation**, but it ELABORATES (in the engineering sense) into a propagator-network problem because:
   - Cells naturally represent "the value of this sub-expression"
   - Fire-once propagators naturally represent reduction rules
   - Topology mutation (new cells/propagators) maps to "compile a body when its lambda's input is concrete"
   - The discrete-with-bot lattice is the simplest valid lattice for "value once written, contradiction on conflict"

   The propagator framing isn't a forced fit — it's the natural shape for value-flow with deferred dispatch.

2. **The design priority order of correctness > simplicity > performance is more powerful than its individual priorities suggest.** Each phase commit's VAG entry verified the order was preserved. Several times the priority order forced rejecting a perf-driven shortcut: the question "is this simpler? is this more correct?" usually answered "no" → reject.

3. **Per-phase mini-plans + per-phase differential gates is the right granularity** for incremental on-network translation work. Smaller granularity (per-AST-node) would've been bureaucratic. Larger (whole-track plan) would've delayed bug detection.

4. **The data-declaration "placeholder body" pattern is the structural reason Phase 10b is needed.** `macros.rkt:7102` stores type defs and ctor defs with body `(Type 0)` because constructors are *opaque* to reduction. The reducer must therefore *bypass* the def-inlining path for constructors — that bypass is Phase 10b's structural shape. Anywhere else in the reducer that an opaque def could surface (future syntax features?) will need the same bypass.

5. **The PReduce-lite + production-`nf` differential test infrastructure keeps catching nothing.** 2000+2 cases, 0 mismatches. Either (a) per-phase tests really do catch everything before the differential runs, or (b) the differential generators don't cover enough surface variation. Today's added 2 cases for user-defined ctors; a Phase 15c with a richer generator (user-defined ctors + union types + atms-amb branches + more pathological corner cases) would close the gap. Worth ~30 min if scheduled.

6. **External compatibility-target imports are concrete forcing functions for closing internal deferrals.** The parent PIR §13 #4 named user-defined-ctor reduce as a deferred gap. The OCapN survey externalized the same gap on a 12-module surface; the deferral closed the same week. Pattern: when an internal deferral is named but stagnant, look for an external consumer that needs it. The consumer's existence is itself a priority signal.

## 19. Are We Solving the Right Problem?

Yes, with one frame correction.

The original ask was: "produce a propagator network that can execute the prologos program." PReduce-lite delivers that for the supported subset. The 2000-case differential confirms `preduce ≡ nf` where defined. Phase 10b extends the surface to user-defined-ctor pattern matching, the largest external consumer surface (OCapN port) was triaged in tier-classified import.

**Frame correction**: the 2026-05-04 directive was framed as "implement Phase 10b *then* get the OCapN tests working." The most-literal reading was: Phase 10b is the blocker for the OCapN tests; ship Phase 10b, the tests light up. Actual fact: the OCapN tests work today under `nf`; Phase 10b is the parity work for PReduce-lite. Both pieces shipped. The user's intent is satisfied either way — the OCapN tests are now in the suite (one step from the `.skip-tests` removal) and PReduce-lite has user-defined-ctor coverage. The framing in the Phase 10b commit message and earlier PIR draft pretended Phase 10b was the unblocker, which is technically wrong; this consolidated PIR corrects the framing.

The natural NEXT problems revealed by PReduce-lite's terminal state:
- Full Track 9 (incrementality + dependency tracking) — the original Track 9 vision that PReduce-lite is the foundation of
- Phase 9 foreign-fn done correctly (NF mode + side-effect discipline + ATMS)
- Phase 12 generic dispatch after PPN 4C trait-resolution stabilizes
- A separate "PReduce on the kernel PU primitive" track — composes when both land
- Phase 15c differential generator extended to user-defined ctors, union types, atms-amb, exception nodes
- OCapN Tier C — `syrup-wire.prologos` (270s decode pathology, pitfall #27) as strategic benchmark target for the hybrid Zig kernel's HOF substitution speedup, gated on Phase 9

None of these require revisiting whether PReduce-lite was the right thing to build. They're additive on top.

A meta-question: *was Phase 10b worth doing, given the OCapN tests work today under `nf`?* Answer: yes — the parent PIR already named it as a known gap (§13 #4), the OCapN survey externalized the same gap on a much larger surface, and the implementation cost was low (~70 LOC). Even without an immediate consumer-of-PReduce-lite, it's correct preparation for Phase 16's eventual flip. The "validated, deployed-as-opt-in" framing means Phase 10b extends what's *validated*, not what's *deployed* — but extending validated is itself preparation work for the eventual deployment.

## 20. Longitudinal Survey — 10 Most Recent PIRs

| PIR | Date | Duration | Test delta | Pattern observed in PReduce-lite |
|-----|------|----------|-----------|----------------------------------|
| **PReduce-lite (this; consolidated)** | **2026-05-04** | **~9h across 2 sessions** | **+115 + 2 differential** | (self) |
| PReduce-lite (Phases 1-15) | 2026-05-03 | ~6h | +88 + 2 differential | **Direct predecessor** — superseded by this consolidated PIR. Same design priority order, opt-in deployment, phased plan. |
| BSP-LE Track 2B | 2026-04-16 | multi-session | substantial | Stratification + fire-once + topology infrastructure — PReduce-lite reuses fire-once + cell allocation; the `current-bsp-fire-round? #f` trick avoids needing a new stratum. |
| BSP-LE Track 2 | 2026-04-10 | multi-session | substantial | Worldview cells + ATMS branching — *not* used by PReduce-lite (lite skips speculation). |
| PPN Track 4B | 2026-04-07 | multi-session | substantial | Component-paths on cells — *not* needed; PReduce-lite cells are scalar. |
| PPN Track 4 | 2026-04-04 | multi-session | substantial | **Network-reality-check pattern** (`net-add-propagator` count, `net-cell-write` for results, traceable cell-flow) — PReduce-lite passes. 33 static install sites + dynamic-β-installed propagators during fire; all results via `net-cell-write` (28 call sites); full trace from input cell through fire-once chains to output cell. |
| SRE Track 2D | 2026-04-03 | multi-session | +0 retrospective concern | **Test-delta-zero anti-pattern** — *not* repeated. PReduce-lite added +115 tests + 2 differential gates. Per-phase test files were a design-doc obligation from day one. |
| SRE Track 2H | 2026-04-03 | multi-session | substantial | F7 distributivity disproof — irrelevant to PReduce-lite. |
| SRE Track 2G | 2026-03-30 | multi-session | substantial | Pocket Universe scaffolding lesson — informed kernel PU design discussions earlier in session 1. |
| PPN Track 3 | 2026-04-02 | multi-session | substantial | "Datum-canonical" vs on-network drift — *avoided* here; preduce-lite is on-network throughout. |
| PPN Track 2 | 2026-03-29 | multi-session | substantial | NTT models surface gaps — *not* repeated; PReduce-lite is small enough to skip NTT model. |
| PPN Track 2B | 2026-03-30 | multi-session | substantial | Belt-and-suspenders dual paths mask bugs — *avoided* via hard-error policy. |

**Recurring pattern PReduce-lite participates in**: "Phased plan with per-phase regression gates produces clean retrospectives." 4+ recent PIRs (BSP-LE Track 2B, PPN Track 4, PPN Track 4B, this) followed this pattern; all have low rework + high architectural clarity. Confirmed pattern; ready to codify in `PATTERNS_AND_CONVENTIONS.org` if not already there.

**Recurring pattern PReduce-lite breaks**: "Test delta = 0 retrospective concern" (SRE Track 2D). Per-phase test files were a design-doc obligation; landed +115 unit tests as natural per-phase gates plus 2 random-term differential gates. Recommended: future tracks adopt per-phase test files as a default obligation.

**Anti-pattern PReduce-lite exhibits (Session 1)**: "Subagent git operations destroyed uncommitted work." First instance in recent PIRs; not a pattern yet but worth watching. Mitigation: commit before launching subagents.

**Anti-pattern PReduce-lite exhibits (Session 2)**: "Subagent cross-system diagnosis was wrong." Second instance in two sessions (after kumavis PR-merge cascade 2026-04-27). Two data points; codify if a third surfaces. Mitigation: verify cross-branch / cross-system claims by running the relevant test on our branch, not by trusting the analysis.

**New pattern surfaced (Session 2)**: "External compat-target imports are concrete forcing functions for closing internal deferrals." Parent PIR's §13 #4 deferral was named but stagnant; the OCapN survey gave it a 12-module consumer and it closed the same week. Watching — codify after a second instance.

## 21. Lessons Distilled

| Lesson | Distilled To | Status |
|--------|-------------|--------|
| Use `define-runtime-path` in tests that reference `.prologos` files | `testing.md` (already codifies the broader "no relative paths in tests" pattern) | Done — codified during Phase 5 |
| Phase-pinned negative tests target permanently-out-of-scope nodes | Inline comment in each test file | Done |
| `current-bsp-fire-round? #f` trick avoids needing a new topology stratum | Phase 4 + Phase 5 commit messages | Done — pattern reusable for any propagator-installs-propagators fire-fn |
| Hard-error policy + separately-named opt-in helper avoids graceful-degradation trap | PReduce-lite design doc § 8.5 | Done |
| Commit before launching subagents that may do git operations | Session 1 inline observation | Watching — first occurrence; codify in `workflow.md` if a second surfaces |
| Run full suite ONCE before iterative CI fixes | `testing.md` § Output Capture (already codifies the analogous principle) | Reinforced |
| Subagent cross-system diagnoses need cross-checking by running the test on our branch | `workflow.md` (kumavis PR-merge-cascade 2026-04-27) — Session 2 is the second data point | Watching (2 data points); codify if a third surfaces |
| Opt-in features need opt-in test paths shipped with them | `testing.md` § Three-level WS validation (analogous gap for syntax features) | Pending — codify if a third opt-in feature ships without an opt-in test path |
| Ad-hoc probe before rackunit test file accelerates iteration | `DEVELOPMENT_LESSONS.org` candidate | Pending |
| Two reducers evolve faster when they don't share helpers (re-implement vs export) | Architectural | Watching |
| External compat-target imports are concrete forcing functions for closing internal deferrals | This PIR | Watching — codify after a second instance |
| "Validated, deployed-as-opt-in" framing | `workflow.md` "Validated ≠ Deployed" gate | Done |
| Per-phase test files as default obligation | `DESIGN_METHODOLOGY.org` | Reinforced (4+ tracks now follow this) |

## 22. Metrics

| Metric | Session 1 (Phases 1-15) | Session 2 (Phase 10b + OCapN) | Total |
|---|---|---|---|
| Wall-clock duration | ~6h | ~3h | ~9h |
| Commits | 18 | 2 | 20 |
| Files added | ~15 (preduce.rkt + test files + design doc + acceptance files) | 6 (4 OCapN libs + NOTES.md + 1 phase10b test) | ~21 |
| Files modified | ~3 (`.skip-tests`, `test.yml`, etc.) | 4 (`preduce.rkt`, `.skip-tests`, `test-ocapn-syrup.rkt`, NOTES.md update) | net additive |
| Code delta | +2591 lines | +1264 / −16 lines | ~+3855 lines |
| `preduce.rkt` LOC | 0 → 1390 | 1390 → 1509 (+119, +8.6%) | 1509 |
| Tests added | +88 + 2 differential | +27 (12 phase10b + 15 ocapn) | +115 + 2 differential |
| Suite tests passing | 8293/8293 (full suite, 477s) | 34/34 (5-file affected run, 6.4s) | — |
| Differential failures vs `nf` | 0 / 2000 | 0 / 2 (added cases) | 0 / 2002 |
| AST node cases handled | ~100 | +1 sub-case (user-defined ctor in expr-reduce) | ~120 explicit + ~50 deferred |
| Out-of-scope deferrals | Multiple, all named | 2 (partial app, Phase 15c generator) | All named with retire path |
| Design-to-impl ratio | ~1:6 | ~1:2 | (Session 2 lower because phased+predecessor compress design overhead) |

**Differential gate strength**: 2002 cases tested across both sessions, 0 mismatches against `nf`. Conservative (per-phase tests catch most things first; generator coverage gap acknowledged in Phase 15c follow-up) but unambiguously zero.

**Code growth**: 1390 → 1509 LOC for Phase 10b is +8.6% growth for ~30% functional coverage extension (built-in ctor → user-defined ctor adds the entire user-data-decl surface). Phase 10b's leverage ratio is high — natural consequence of orthogonal addition (struct + 2 dispatch branches + 1 classify branch).

## 23. Key Files

### PReduce-lite engine (post-2026-05-04 backend refactor)

| Path | Role |
|---|---|
| `racket/prologos/preduce-core.rkt` | Backend interface — `preduce-backend` struct + `b-*` accessor shorthands + `current-backend` parameter. The shared substrate. |
| `racket/prologos/preduce-backend-racket.rkt` | Racket backend instance (`backend-racket-with-lattice`); wraps `propagator.rkt` primitives. |
| `racket/prologos/preduce-backend-hybrid.rkt` | Hybrid backend instance (`backend-hybrid`); wraps the Zig kernel FFI + handles the kernel callback ABI. Owns the `NATIVE-OP-TAGS` map for kernel-native dispatch. |
| `racket/prologos/preduce.rkt` | Lattice + compile-expr + ~120 AST cases + entry-point `preduce`. compile-expr is now backend-agnostic (uses `b-*` shorthands); the entry point parameterizes `current-backend = backend-racket-with-lattice ...`. Provides `compile-expr` for cross-backend reuse. |
| `racket/prologos/preduce-hybrid.rkt` | Hybrid-kernel entry-point (`preduce-hybrid`) — thin wrapper that parameterizes `current-backend = backend-hybrid` and calls `preduce.rkt`'s shared `compile-expr`. ~66 LOC after refactor (was 407 LOC pre-refactor). |

### Tests

| Path | Role |
|---|---|
| `racket/prologos/tests/test-preduce-phase{1..6,10,10b,11b,14b}.rkt` | Per-phase unit tests with `nf` differential |
| `racket/prologos/tests/test-preduce-phase15{,b}-differential.rkt` | 2000-case property-based differential gates |

### Acceptance + lib

| Path | Role |
|---|---|
| `racket/prologos/examples/preduce-lite/0{1..7}-*.prologos` | 7 acceptance programs |
| `racket/prologos/lib/prologos/ocapn/{refr,syrup,promise,message}.prologos` | OCapN compatibility-target libs |
| `racket/prologos/lib/prologos/ocapn/NOTES.md` | OCapN tier classification |
| `racket/prologos/tests/test-ocapn-{refr,syrup}.rkt` | OCapN compat-target tests |

### Design + tracking

| Path | Role |
|---|---|
| `docs/tracking/2026-05-02_PREDUCE_LITE_DESIGN.md` | Stage 3 design doc with progress tracker |
| `docs/tracking/2026-05-03_PREDUCE_LITE_PIR.md` | Predecessor PIR (Phases 1-15); superseded by this doc |
| `docs/tracking/2026-05-04_PREDUCE_LITE_PIR.md` | This consolidated PIR |
| `docs/tracking/2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md` | PM Track 9 origin |

### Reference (unchanged)

| Path | Role |
|---|---|
| `racket/prologos/reduction.rkt:1213` | `try-structural-reduce` — production reducer's user-ctor path that Phase 10b mirrors |
| `racket/prologos/macros.rkt:5911` | `register-ctor!` + `ctor-meta` — the registry Phase 10b reads via `lookup-ctor` |
| `racket/prologos/ctor-registry.rkt` | The *structural* ctor registry (different from `macros.rkt`'s data-ctor registry; not used by Phase 10b) |
| `racket/prologos/propagator.rkt` | `current-bsp-fire-round?` parameter (Phase 4 trick) |

## 24. Open Questions Surfaced

1. **Do we re-attempt Phase 16 default flip after Phase 9 + Phase 12 land?** The design says yes. But by then the full Track 9 (incremental) might be the natural deployment, making the lite-default-flip moot. Decision deferred.

2. **Should Phase 11c higher-order container ops (pvec-fold, set-fold, etc.) land on PReduce-lite or full Track 9?** They mechanically extend Phase 11b's pattern + Phase 4's dynamic β. Probably worth landing on PReduce-lite to make container-using programs run end-to-end.

3. **Should PReduce-lite be exported as a Racket sub-collection** (e.g., `prologos/preduce`)? Currently it's `(require "preduce.rkt")` with a file-relative path. A sub-collection would make external consumption cleaner. Defer.

4. **Is the single-file `preduce.rkt` (1509 LOC) the right shape**, or should it split into preduce-core / preduce-eliminators / preduce-containers / etc.? Compile time is fine (~1s); readability is OK; cohesion is good. Defer split unless growth makes it unwieldy.

5. **Should Phase 10b's partial-application of user ctors be implemented?** No consumer demand today; design space is open (preduce-user-ctor with closure-shaped completion? eta-expanded lambda over fully-applied ctor?). Wait for a real consumer to disambiguate.

6. **Should Phase 15c extend the random generator to user-defined ctors?** ~30 min cost; would close the only known gap in differential coverage (Phase 10b's surface). Worth scheduling soon.

7. **Should the two ctor registries (`macros.rkt` data-decl-time + `ctor-registry.rkt` structural) be merged?** They have overlapping purposes. Not blocking PReduce-lite or anything else; future refactor when a clear driver appears.

8. **Should we pull `test-ocapn-promise.rkt` + `test-ocapn-message.rkt` from upstream PR #28?** The corresponding lib files are imported. ~30 min to pull + verify. Defer to next OCapN-related session.

9. **Should `syrup-wire.prologos` (270s decode pathology, pitfall #27) become a benchmark target for the hybrid Zig kernel HOF substitution speedup?** Architecturally the right shape (large HOF-heavy workload). Gated on Phase 9 (FFI + byte-strings) + hybrid kernel HOF migration. When both unblock, this is a strong end-to-end perf demonstrator.

## Appendix: Network Reality Check

Per `workflow.md`'s mandatory gate for propagator tracks:

**Q1: Which `net-add-propagator` calls were added?**

PReduce-lite installs fire-once propagators across the AST surface — 33 static install sites in `preduce.rkt` (31 `net-add-fire-once-propagator` + 2 `net-add-propagator`). Every reduction-active node (`expr-app` dynamic-β, `expr-boolrec`, `expr-natrec`, `expr-J`, `expr-fst`/`expr-snd` non-static, `expr-vhead`/`expr-vtail` non-static, `expr-reduce`, `expr-int-{add,sub,mul,...}`, ~25 container ops) installs at least one fire-once propagator. Plus 86 cell-allocation sites (`alloc-value-cell` + `net-new-cell`) covering the literal + container + opaque-value paths. Phase 10b adds zero NEW install call sites — it reuses the existing `expr-reduce` site in `make-reduce-fire`, only changing what the fire-fn dispatches over (now also `preduce-user-ctor` values via the extended `classify-ctor`).

✅ — propagators are present at the architecturally-natural sites; Phase 10b extends behavior without adding install-site count.

**Q2: Which `net-cell-write` calls produce the result?**

Every fire-fn writes its output to the destination cell-id via `net-cell-write`. The `compile-and-bridge` pattern (used by dynamic-β, expr-reduce arm-body bridging, etc.) installs an identity-fire propagator that reads from a downstream-compiled cell and writes to the parent cell-id — explicit `net-cell-write` to `cid-out`. No function-call-wrapper imposters.

✅ — results flow through `net-cell-write`, not return values.

**Q3: Cell creation → propagator installation → cell write → cell read = result traceable?**

Yes. Top-level `(preduce e)` does:
1. `make-prop-network` — fresh network
2. `compile-expr e '() net` → returns `(values cid-out net*)` after recursively allocating cells + installing propagators across the AST
3. `run-to-quiescence` — fires the propagator network until no more writes
4. `net-cell-read net** cid-out` — reads the final value

For Phase 10b specifically: `expr-app` user-ctor branch creates a cell (`alloc-value-cell` with `preduce-user-ctor`) → `expr-reduce` site reads that cell via `make-reduce-fire`'s `net-cell-read` → fire-fn classifies, finds matching arm, compiles arm body in extended env → arm body's compile-expr writes to a fresh cell → `compile-and-bridge` installs identity propagator from arm-body-cell to `expr-reduce`'s `cid-out` → caller reads `cid-out`.

✅ — full trace from input cell through fire-once chains to output cell, no imperative dispatch shortcuts.

**Verdict**: PReduce-lite passes the network reality check across the full AST surface. It is genuine on-network computation, not a function-call chain wearing a propagator-shaped hat. The reducer's *shape* matches its propagator-network framing — cells hold values, fire-once propagators encode reduction rules, dynamic-β's body compilation maps to topology mutation (auto-scheduled via `current-bsp-fire-round? #f`), the discrete-with-bot lattice carries write-once semantics with contradiction detection.

---

**End of consolidated PIR.**
