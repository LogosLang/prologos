# Swappable-Backend Refactor — Post-Implementation Review

**Date**: 2026-05-04
**Duration**: ~5 hours wall-clock, single session (continuation of the morning's PReduce-lite + Hybrid Runtime PIR sessions)
**Commits**: 12 (from `0d80dfa` Phase 1 backend interface skeleton through `236e441` programs 9 + 10)
**Test delta**: +4 case test file (`test-preduce-hybrid-phase10b.rkt`) + 10 OCapN-shape end-to-end programs (`examples/ocapn/ocapn-hybrid-{1..10}.prologos`) + 5-workload benchmark (`tests/bench-ocapn-hybrid-vs-lite.rkt`); zero regressions in the existing 133-test gate
**Code delta**: +preduce-core.rkt (153 LOC), +preduce-backend-racket.rkt (~100 LOC), +preduce-backend-hybrid.rkt (~140 LOC), preduce-hybrid.rkt 407 → 66 LOC (−341), preduce.rkt rewritten through b-* shorthands (~133 mechanical edits across ~80 call sites; net LOC ~unchanged); kernel `format.zig` buffer 1024 → 8192 bytes; +pitfalls tracking doc (4 entries)
**Suite health**: 133 affected-file tests green pre-refactor and post-refactor at every phase boundary; the 13/13 three-way differential gate (`nf` ≡ `preduce` ≡ `preduce-hybrid`) preserved
**Branch**: `claude/prologos-layering-architecture-Pn8M9`
**Design doc**: [`2026-05-04_PREDUCE_BACKEND_REFACTOR_DESIGN.md`](2026-05-04_PREDUCE_BACKEND_REFACTOR_DESIGN.md)

---

<!-- 16-question PIR template — sections to be filled iteratively -->

## 1. What Was Built

A swappable-backend interface (`preduce-core.rkt`) that lets PReduce-lite's canonical `compile-expr` drive multiple propagator-network backends from one shared implementation. Two concrete backends — `backend-racket` (Racket-side `prop-network` struct) and `backend-hybrid` (Zig kernel via FFI) — each in their own module. `preduce.rkt` rewritten to use `b-*` accessor shorthands at every primitive call site; `preduce-hybrid.rkt` collapsed from 407 LOC of duplicated compile-expr-hybrid (Phase 8b coverage only) to a 66-LOC thin wrapper that delegates to the shared compile-expr.

Threading model: **functional throughout**. The `net` value is threaded through every primitive (`alloc-cell`, `read-cell`, `write-cell`, `install-fire-once`, `install-propagator`, `run-to-quiescence`). For `backend-racket`, `net` is the actual `prop-network` struct. For `backend-hybrid`, `net` is the sentinel symbol `'hybrid` (formal threading; kernel state mutates underneath). For a future `backend-native` (SH Track 9 endpoint), `net` becomes a cell-id pointing to the network value being built — at which point compile-expr itself runs as a propagator program over network-valued cells.

Native-op hint mechanism added during the refactor (commit `6ea73cc`) after a regression was found: backend-hybrid initially wrapped EVERY fire-fn as a Racket callback, including int-arith ops that the pre-refactor preduce-hybrid had routed to the kernel's built-in native fire-fns at tags 0-7. The fix added `#:native-op` (a symbolic operation name like `'int-add`, `'int-sub`, `'identity`) to the backend interface; backend-hybrid maps those symbols to native kernel tags via `NATIVE-OP-TAGS`, skipping `register-fire-fn!` for those installs. Restored ~14× kernel-side speedup on int-arith.

Validated by 10 OCapN-shape Prologos programs running end-to-end through the kernel via `process-file → preduce-hybrid → backend-hybrid → kernel BSP scheduler`. Coverage spans bare ctors, function calls, function defns, multi-arg match, cross-module Option dispatch, predicate sweeps, real `promise.prologos` state-transition predicates, mixed native+callback, recursion via natrec, and arity-4 CapTP message construction with 7-arm match dispatch.

A new pitfalls tracking doc (`docs/tracking/2026-05-04_PROLOGOS_LANGUAGE_PITFALLS.md`) was opened during the OCapN-on-kernel exploration to capture compiler-stack bugs surfaced by stress testing — distinct from the upstream OCapN goblin-pitfalls.md. Four entries to date.

## 2. Stated Objectives

From the design plan (`2026-05-04_PREDUCE_BACKEND_REFACTOR_DESIGN.md`) §1:

> Today there are **two separate reducer implementations** that share ~all of compile-expr's logic but duplicate the code because their backend primitives differ. The refactor: **factor compile-expr into a backend-agnostic core, parameterized by a backend interface.**

User direction during execution:
- *"a swappable backend seems like the right abstraction. plan the refactor"*
- *"which of the two threading models is appropriate to use both in and out of native?"* — forced the Option B → Option A flip (functional throughout, not side-effecting).
- *"revise for Option A, commit, then implement"*
- *"the goal of this refactor was to minimize the racket implementation specific to the hybrid kernel, whats the status there"* — forced the realization that I'd built a NEW path without deleting the OLD parallel implementation; led to the preduce-hybrid.rkt thin-wrapper rewrite.
- *"is there perhaps a bug preventing us from correctly measuring native ns?"* — surfaced the native-dispatch regression (the int-arith ops the new backend lost) and the `#:native-op` hint fix.

Implicit objectives:
1. Eliminate the ~407-LOC parallel `compile-expr-hybrid` in `preduce-hybrid.rkt` while preserving its existing Phase 8b coverage on the kernel.
2. Extend kernel coverage to all of preduce.rkt's Phase 1–10b AST surface for free (via Racket-callback dispatch through the unified compile-expr).
3. Pick a threading model that works in-and-out-of-native (i.e., when compile-expr eventually runs as a propagator program at SH Track 9). The functional model wins on this axis; side-effecting via `current-prop-net` parameter is a dead-end.
4. Validate by running real OCapN Prologos programs through the kernel — including programs the pre-refactor preduce-hybrid couldn't even attempt (Phase 10b user-ctor matches, recursion via natrec, arity-4 ctors, full CapTP messages).

## 3. What Was Actually Delivered

### Code

| File | LOC | Status |
|---|---|---|
| `racket/prologos/preduce-core.rkt` | 153 | NEW — `preduce-backend` struct (7 fields, all functionally threading `net` + `#:native-op` hint) + `b-*` accessor shorthands + `current-backend` parameter + `with-backend` macro |
| `racket/prologos/preduce-backend-racket.rkt` | ~100 | NEW — `backend-racket-with-lattice` constructor; wraps `propagator.rkt` primitives; `#:native-op` hint ignored (no native tags on Racket side) |
| `racket/prologos/preduce-backend-hybrid.rkt` | ~140 | NEW — `backend-hybrid` instance; wraps the Zig kernel FFI + handle-table marshaling + callback registration; owns `NATIVE-OP-TAGS` (the symbolic-op → kernel-tag map for native dispatch) |
| `racket/prologos/preduce.rkt` | 1509 → ~1480 | MODIFIED — ~133 mechanical primitive renames (`net-new-cell` → `b-alloc`, `net-add-fire-once-propagator` → `b-install-fire-once`, `net-cell-{read,write}` → `b-{read,write}`, `run-to-quiescence` → `b-run-to-quiescence`, `make-prop-network` → `b-fresh-net`); entry-point `preduce` parameterizes `current-backend = backend-racket-with-lattice ...`; `compile-expr` now exported |
| `racket/prologos/preduce-hybrid.rkt` | 407 → 66 | REWRITTEN — thin wrapper that parameterizes `current-backend = backend-hybrid` and delegates to `preduce.rkt`'s shared compile-expr. Net **−341 LOC**; AST coverage **Phase 8b → Phase 1-10b** (~6×). |
| `runtime/core/format.zig` | +1 (1024 → 8192) | MODIFIED — `FormatBuffer.buf` capacity increase to fix the silent profile-JSON truncation when `N_TAGS=256` produced > 1 KB output |
| `racket/prologos/tests/test-preduce-hybrid-phase10b.rkt` | ~110 | NEW — 4 cases validating Phase-10b user-ctor programs run through the kernel |
| `racket/prologos/tests/bench-ocapn-hybrid-vs-lite.rkt` | ~180 | NEW — 5-workload benchmark (W1-W5) measuring lite vs hybrid wall time + per-workload native-vs-callback breakdown |
| `racket/prologos/examples/ocapn/ocapn-hybrid-{1..10}.prologos` | ~250 total | NEW — 10 OCapN-shape Prologos programs of escalating ambition, each running end-to-end through the hybrid binary |
| `docs/tracking/2026-05-04_PREDUCE_BACKEND_REFACTOR_DESIGN.md` | ~300 | NEW — design plan with 9-phase rollout tracker |
| `docs/tracking/2026-05-04_PROLOGOS_LANGUAGE_PITFALLS.md` | ~150 | NEW — pitfalls tracking doc (4 entries to date: FQN nil, FormatBuffer truncation [fixed], prelude shadowing, identity-bridge native-op miss) |
| `racket/prologos/lib/prologos/ocapn/NOTES.md` | ~+80 | EXTENDED — parallel-branch coordination section + "Hybrid kernel test status" table (10 programs + factorial baseline) + "Reading the numbers" + "Known issues" subsections |
| `docs/tracking/2026-05-04_PREDUCE_LITE_PIR.md`, `2026-05-04_HYBRID_RUNTIME_PIR.md` | ~30 each | UPDATED — addendum blocks at top of each PIR documenting the refactor; §3, §15, §17, §23 updated |

## 4. Timeline and Phases

Single ~5-hour session, 12 commits.

| Phase | Commit | Wall time | Notes |
|---|---|---|---|
| Plan: design plan v1 (Option B — side-effecting unified) | `28465e3` | ~30min | Picked side-effecting backend interface to minimize hybrid-side scaffolding; user challenged the threading-model choice |
| Plan: revision to Option A (functional throughout) | `ae26bc5` | ~15min | Flipped recommendation after the in-and-out-of-native fit argument; SH Track 1 + 9 endpoints demand functional |
| Phase 1 — backend interface skeleton | `0d80dfa` | ~30min | `preduce-core.rkt` with `preduce-backend` struct + `b-*` shorthands + `current-backend` parameter; no instances yet |
| Phase 2 — primitive rewrite + backend-racket | `0ac9ba8` | ~1h | Python regex script applied 130 mechanical edits across preduce.rkt; 2 manual edits for parameterize-wrapped sites; backend-racket wraps net-* primitives; 117 tests stay green |
| Phase 4 — backend-hybrid + 4/4 probe | `2d6817f` | ~1h | preduce-backend-hybrid.rkt; 4-case probe (int arith, β, fst, boolrec) running on the kernel via the shared compile-expr |
| Phase 5+6 — Phase-10b workload + first kernel profile | `4ae1204` | ~30min | test-preduce-hybrid-phase10b.rkt: user-ctor matches running on the kernel; profile shows 5 callbacks, 18 µs |
| Phase 5 (real) — preduce-hybrid.rkt thin wrapper | `b5044a9` | ~30min | After the user pointed out the original parallel impl was still in tree. 407 → 66 LOC. The actual refactor goal cashed in. |
| Benchmark: 5 OCapN-shape workloads | `fab2cb0` | ~30min | tests/bench-ocapn-hybrid-vs-lite.rkt; W4 hybrid 2× faster than lite for user-ctor matches; W5 int-arith DEGRADED post-refactor (initial backend-hybrid wrapped int+ as callback) |
| Native-dispatch fix (regression closed) | `6ea73cc` | ~30min | User challenged: "is there perhaps a bug preventing us from correctly measuring native ns?" — diagnosis surfaced that backend-hybrid lost the kernel's tags 0-7 native dispatch. Fix: `#:native-op` symbolic hint mechanism. W5 went 5323 → 375 ns kernel time, 31% faster wall. |
| PIR addenda for PReduce-lite + Hybrid PIRs | `f00fdb7` | ~30min | Both 2026-05-04 PIRs updated with the refactor addendum + closure of the parallel-impl debt |
| OCapN-on-kernel: parallel-branch coord + first program | `e448970` | ~10min | NOTES.md extended; `examples/ocapn/ocapn-hybrid-1.prologos` runs end-to-end through the binary |
| OCapN-on-kernel: 5 programs + FormatBuffer fix | `0ae1230` | ~30min | Programs 1-5 + kernel buffer overflow fix discovered during profile dump |
| OCapN-on-kernel: 3 more programs + pitfalls doc | `d1d76a3` | ~30min | Programs 6-8 (multi-arg defn, promise.prologos, mixed native+callback); pitfalls tracking doc opened with 4 entries |
| OCapN-on-kernel: 2 most ambitious programs | `236e441` | ~15min | Programs 9 (recursive sum-to-n via natrec, 20 native fires) + 10 (full CapTP op-deliver with arity-4 ctor + 7-arm match) |

**Design-to-implementation ratio**: ~1:5 (45min plan iteration → ~4h implementation). Lower than typical because the design plan itself iterated quickly (the threading-model choice was the only architectural decision), and most of the implementation was mechanical (the 130 sed-style primitive renames in preduce.rkt + the per-program OCapN-on-kernel iteration).

## 5. What Was Deferred and Why

| Deferred | Why | Tracking |
|---|---|---|
| **Phase 2c**: move `compile-expr` + helpers + lattice + stuck-value structs from `preduce.rkt` into `preduce-core.rkt` | The architectural goal was achieved without it — `preduce.rkt`'s compile-expr is exported and reused by `preduce-hybrid.rkt`'s thin wrapper. preduce.rkt is functionally a "library file with a thin wrapper on top." Moving compile-expr to preduce-core would be cosmetic. | Future cleanup — landing it would let preduce.rkt become a thin wrapper too (matching the symmetry of the two backend modules), but no functional benefit. |
| **N-1 propagator install support in backend-hybrid** | `backend-hybrid.install-fire-once` errors on `n_inputs > 3`. None of the 10 OCapN programs hit it (Phase-10b user-ctor matches use 1-3 input fire-fns); container ops (Phase 11b) would need it eventually. | Add when a Phase-11b-on-kernel test surfaces, OR when an OCapN program with 4+ inputs to a single fire-fn appears. ~45 min. |
| **Pitfall #1 (FQN nil lookup) fix** | Workaround: avoid `[syrup-list nil]` in test programs; use direct `pst-fulfilled` ctor instead of `fresh` (pitfalls.md #1). | Pitfalls.md #1; ~30 min if dual-lookup pattern at the global-env-lookup-value site fixes it. |
| **Pitfall #3 (prelude-shadowing diagnostic) fix** | UX issue, not correctness. The fallback behavior is arguably correct; only the diagnostic is poor. | Pitfalls.md #3; ~1h to improve the elaborator's name-resolution + inference-error pretty-printing. |
| **Pitfall #4 (identity-bridge `#:native-op`) fix** | Easy ~5 LOC follow-up; would show up as additional native fires in the next benchmark. | Pitfalls.md #4. |
| **Phase 7 first profile-driven migration on real OCapN workload** | Architecturally validating but requires kernel-side work (implementing a Zig-native fire-fn for "match-on-user-ctor with N arms"). The 10 OCapN programs already validate the swappable-backend architecture; native migration of OCapN-shape callbacks is the next user-value step but separable. | Future track; the program-10 profile gives the targeting data. |
| **Phase 15c: extend differential generator to user-defined ctors** | Phase-10b's surface coverage rests on the 12-case test-preduce-phase10b.rkt + 4-case test-preduce-hybrid-phase10b.rkt + the differential gates ran 2000 cases of the (built-in-ctor) generator with zero mismatches. Extending to user-ctors would close the only known coverage gap. | ~30 min. |

All deferrals are tactical; the architectural goal (one compile-expr, multiple backends, kernel-validated on real programs) is delivered.

## 6. Test Coverage

**New tests**:
- `tests/test-preduce-hybrid-phase10b.rkt` — 4 cases validating user-ctor pattern matching runs end-to-end through the kernel via the shared compile-expr (vs hand-built ASTs in test-preduce-phase10b.rkt that exercised backend-racket only).
- `tests/bench-ocapn-hybrid-vs-lite.rkt` — 5-workload benchmark (W1 bare-null, W2 unary-app, W3 match-nullary, W4 match-unary-extract, W5 int-arith) measuring lite vs hybrid wall time per workload + per-workload native-vs-callback breakdown via `prologos_get_stat`.
- `examples/ocapn/ocapn-hybrid-{1..10}.prologos` — 10 OCapN-shape Prologos programs of escalating ambition. Each runs end-to-end through `dist/prologos-hybrid-bundle/bin/prologos --profile`. Tabulated in `racket/prologos/lib/prologos/ocapn/NOTES.md`'s "Hybrid kernel test status" section.

**Regression coverage** (preserved at every phase boundary):
- 100/100 preduce-lite phase tests (phase{1..6,10,10b,11b,14b}.rkt)
- 2/2 differential gates (phase15 + 15b, 2000 random terms vs `nf`)
- 15/15 OCapN tests (refr 6 + syrup 9)
- 12/12 + 13/13 + 4/4 hybrid tests (phase8b, differential, phase10b)
- = **133 tests** confirmed green at: post-Phase-2 commit, post-Phase-4 commit, post-thin-wrapper commit, post-native-dispatch fix commit, and final state.

**Coverage gaps acknowledged**:
- Differential generators don't emit user-defined-ctor terms (Phase 15c deferred).
- N-1 propagator install untested on hybrid (no workload triggers it; Phase 11b-on-kernel would).
- The 10 OCapN programs are smoke tests, not differential gates — they confirm the kernel produces a result equal to the Racket-side expected output, but only on those specific inputs.

## 7. Bugs Found and Fixed

**Bug 1: `try-decompose-user-ctor-app` returned multiple values; caller captured only the first.**
*Plausibility*: Drafted with `(values short-name field-args)` to mirror Racket's multi-return style in adjacent code. Racket multi-return is not a tuple; `(define x (multi-value-fn ...))` silently drops everything past the first value.
*Detection*: First compile after wiring the dispatch.
*Fix*: Changed helper to return a single `(cons short-name field-args)` cons-pair or `#f`. ~15s.
(Carried over from the prior PReduce-lite Phase 10b session; surfaced again here via the fresh helper signatures.)

**Bug 2: Native-dispatch regression — backend-hybrid wrapped int-arith as callbacks.**
*Plausibility*: The new backend-hybrid's `install-fire-once` allocated a fresh callback tag at `next-tag!` (starts at 8) and registered every fire-fn via `register-fire-fn!`. Tags 0-7 (the kernel's built-in native int-arith + identity) were unused. The pre-refactor preduce-hybrid had explicit `[(expr-int-add a b) (compile-int-binary a b env KERNEL-INT-ADD-TAG)]` dispatch; the unified compile-expr lost that.
*Detection*: User question "is there perhaps a bug preventing us from correctly measuring native ns?" prompted re-examination of the W5 int-arith profile, which showed 0 native fires + 5 callbacks where pre-refactor would have shown 5 native + 0 callbacks.
*Fix*: Added `#:native-op` symbolic hint to the backend interface. preduce.rkt's `compile-int-binary` passes the hint (`'int-add`, `'int-sub`, etc.); `backend-racket` ignores it; `backend-hybrid` looks it up in `NATIVE-OP-TAGS` and installs at the native tag. **W5 kernel time 5323 ns → 375 ns (~14× faster), wall time 37.6 µs → 25.7 µs (31% faster).** Preserves preduce.rkt's backend-agnostic stance — symbolic op names, not raw kernel tag numbers.

**Bug 3: `FormatBuffer` truncated profile JSON when N_TAGS=256.**
*Plausibility*: `runtime/core/format.zig` declared `FormatBuffer.buf: [1024]u8`. The full PNET-STATS object with 256 per-tag entries (both `by_tag` AND `ns_by_tag` arrays) is ~3000+ bytes. `putc` silently dropped writes past the buffer length — no overflow, no error, just truncation.
*Detection*: Python parser failed on unbalanced braces while parsing `--profile` output mid-OCapN-on-kernel exploration.
*Fix*: `buf: [8192]u8` (~4× headroom). Profile JSON now parses cleanly. `prologos_get_stat` (programmatic per-tag read via FFI) was unaffected and gave correct numbers — the benchmark's earlier readouts via that path were correct.

**Bug 4 (averted, not actually triggered): the original side-effecting backend interface (Option B in the design plan).**
The first version of the design plan recommended pushing preduce.rkt's `net` into a `(current-prop-net)` parameter to make both backends side-effecting. User question "which threading model is appropriate to use both in and out of native?" forced reconsideration. Functional threading wins because compile-expr eventually runs natively at SH Track 9, where `net` becomes a real cell-id flowing through cells; ambient state has no native analogue. Plan flipped to Option A (functional throughout) before any code was written.

**Bug 5 (averted at user direction): the parallel-impl debt would have stayed.**
After Phase 4 landed, I had built a NEW path through compile-expr → backend-hybrid but not deleted the OLD parallel `compile-expr-hybrid` in `preduce-hybrid.rkt`. User challenge "the goal of this refactor was to minimize the racket implementation specific to the hybrid kernel, what's the status there" surfaced that the goal wasn't yet achieved. Led to the 407 → 66 LOC thin-wrapper rewrite.

## 8. Design Decisions and Rationale

**Decision 1: Functional threading throughout (Option A in the design plan).**
- *Rationale*: SH Track 1's deliverable is "`.pnet` network-as-value" — networks become first-class cell values that round-trip. SH Track 9 (compiler-in-Prologos) runs compile-expr as a propagator program over network-valued cells; native fire-fns can't side-effect networks they don't hold; they must take net as input and produce net' as output. Functional threading IS the dataflow edge in native execution. Side-effecting via `current-prop-net` would be a dead-end at the SH endpoint.
- *Cost*: backend-hybrid threads a unit sentinel (`'hybrid`); zero runtime cost.

**Decision 2: `#:native-op` symbolic hint, not raw kernel tag numbers.**
- *Rationale*: preduce.rkt must stay backend-agnostic — it can't import `KERNEL-INT-ADD-TAG` etc. from runtime-bridge.rkt (coupling violation). preduce.rkt names operations *symbolically* (`'int-add`, `'identity`); each backend owns its own name → backend-tag map. backend-racket ignores; backend-hybrid maps via `NATIVE-OP-TAGS`; future backend-native maps to its own native dispatch.
- *Phase 7 implication*: adding kernel-native fire-fns is now a 2-line change (kernel-side: implement the fire-fn; Racket-side: add a row to `NATIVE-OP-TAGS`). preduce.rkt unchanged.

**Decision 3: Build a NEW compile-expr-hybrid path BEFORE deleting the old.**
- *Rationale*: validates the architecture (Phase 4's 4/4 probe) before incurring the deletion risk. Found two issues this way: (a) handle-table marshaling correctness; (b) callback ABI bridging.
- *Cost*: at the validation point, the codebase had BOTH paths — 627 LOC of hybrid-specific Racket vs 488 pre-refactor. User challenged ("the goal was to minimize..."), forcing the deletion phase. Without that nudge, the old code would have lingered.

**Decision 4: Keep preduce.rkt's `compile-expr` in preduce.rkt, not migrate it to preduce-core.rkt.**
- *Rationale*: the architectural goal (shared compile-expr across backends) is achieved by exporting it from preduce.rkt. Moving the body to preduce-core.rkt would be cosmetic. preduce.rkt is now functionally a "library + thin wrapper" — slightly inelegant but works.
- *Anti-decision rejected*: Phase 2c (the move) was in the plan but skipped. Future cleanup if the asymmetry becomes a problem.

**Decision 5: Programs run via `dist/prologos-hybrid-bundle/bin/prologos --profile`, not via test-suite integration.**
- *Rationale*: each OCapN-on-kernel program is a smoke test, not a regression gate. Running them by hand confirms end-to-end functionality + captures profile data. Wiring them into `raco test` would require harness work; deferred until a real failure mode demands it.

**Anti-decision (rejected)**: Make backend-hybrid's `install-fire-once` accept ANY fire-fn that knows how to run native (e.g., a tag annotation on the closure). Too coupled to the kernel's specific tag layout. Symbolic hint is cleaner.

**Anti-decision (rejected)**: Inline backend-racket and backend-hybrid into preduce-core.rkt. Tempting (smaller file count) but loses the per-backend modularity. Each backend's bridging code (FFI marshaling, etc.) is non-trivial and deserves its own module.

## 9. What Went Well

1. **Threading-model decision flipped at design-doc stage, not implementation stage.** User challenge on "in-and-out-of-native fit" forced reconsideration before any code was written. Avoided the much-more-invasive "rewrite preduce.rkt's ~80 net-threading sites to side-effecting" path that Option B would have demanded.

2. **Mechanical rewrite of preduce.rkt via Python regex script.** ~130 sed-style edits (`net-new-cell` → `b-alloc` with arg-order swap, `net-add-fire-once-propagator` → `b-install-fire-once`, etc.) applied in one pass; 2 manual edits for parameterize-wrapped sites. 117 tests stay green on first compile after the rewrite.

3. **Functional threading "for free" in hybrid backend.** Using `'hybrid` as a unit sentinel preserved threading discipline at zero runtime cost (single value passed + returned per primitive call; Racket-CS multi-value return is fast). The functional shape works AND maps directly to future native execution.

4. **Existing test infrastructure caught regressions immediately.** The 13/13 three-way differential gate (`nf` ≡ `preduce` ≡ `preduce-hybrid`) was a tight regression net — every refactor commit ran the gate. The native-dispatch regression was caught not by the gate (the gate only checks RESULT correctness, not perf) but by the benchmark, which was a complementary regression net.

5. **`#:native-op` symbolic hint mechanism is cleanly extensible.** Adding new native ops at Phase 7 will be a 2-line change: implement the kernel-side fire-fn + add a row to `NATIVE-OP-TAGS`. preduce.rkt unchanged. Validates the architecture's "pluggable native dispatch" claim.

6. **10 OCapN programs of escalating ambition all ran end-to-end.** The escalation path validated coverage: bare ctors → smart-ctor + selector → defn → multi-arg match → cross-module Option dispatch → predicate sweep → real promise.prologos → mixed native+callback → recursion → arity-4 CapTP messages. No need to bisect a particular failure — the architecture held all the way to program 10.

7. **Pitfalls doc opened proactively, not reactively.** Discovered the FQN nil bug, opened a tracking doc with a clear format, immediately added 4 entries (1 reactively for the bug, 1 for the FormatBuffer fix during the same session, and 2 forward-looking placeholders). Future bugs land in a structured place rather than scattered across commit messages.

8. **The user-driven course corrections were ALL correct.** Three challenges shaped the final architecture:
   - "which threading model fits in-and-out-of-native?" → Option A
   - "the goal was to minimize hybrid-specific Racket code, what's the status?" → preduce-hybrid.rkt thin wrapper
   - "is there a bug preventing us from correctly measuring native ns?" → `#:native-op` hint
   Each was caught by external review, not by my own VAG. **My internal validation gates missed all three architectural drift points.**

## 10. What Went Wrong

1. **Initial design plan recommended Option B (side-effecting); had to be flipped.** I picked Option B because it minimized hybrid-side scaffolding, optimizing for the wrong axis (today's code vs. SH-endpoint fit). User had to challenge before the plan committed. **Lesson**: when a design decision affects future-state architecture, explicitly evaluate against the target endpoint, not just the immediate cost.

2. **Built the new compile-expr-hybrid path without deleting the old preduce-hybrid.rkt.** After Phase 4, the codebase had BOTH the new shared path AND the old 407-LOC parallel impl — *worse* than where we started (627 LOC hybrid-specific vs. 488 pre-refactor). Only the user's "what's the status" challenge surfaced this. **Lesson**: when a refactor's stated goal is "remove duplication," verify the OLD impl is gone before declaring victory; "I built a new path" ≠ "the duplication is gone."

3. **Native-dispatch regression hidden by the differential gate.** The 13/13 three-way differential confirmed correctness but didn't catch perf regressions. The benchmark caught it, but only AFTER the user's explicit prompt to investigate. **Lesson**: regression nets must include perf, not just correctness. The benchmark should run automatically, not on demand.

4. **FormatBuffer truncation hid for several runs.** I read profile output via `--profile` for 4-5 programs before the truncation became visible (when Python parsing failed on unbalanced braces). The earlier benchmark numbers from `prologos_get_stat` were correct, but the text dumps were corrupted silently. **Lesson**: silent buffer truncation is the worst class of bug — no error, valid-looking partial output, downstream parsers crash. Future kernel print code should error on overflow, not silently drop writes.

5. **Three pitfalls surfaced, only one fixed.** FQN nil (open), prelude shadowing (open), identity-bridge native-op (worked-around). Each is a small fix but I deferred them. **Tension**: the "let it bake" instinct vs. the "fix while context is fresh" instinct. Pitfalls.md is the right compromise — captured, prioritized, deferred without being lost.

6. **No incremental commits between Phase 2's mechanical rewrite and the Phase 3 test pass.** A 130-edit sed-style rewrite landed in one commit. If tests had failed mid-rewrite, bisect granularity would have been "rewrite-everything" vs "before." **Lesson**: even mechanical rewrites benefit from per-section commits when the section count > ~5.

## 11. Where We Got Lucky

1. **The pre-refactor preduce.rkt's `make-X-fire` factories were already net-threaded.** They already took `(net) → net'` and used `net-cell-read` / `net-cell-write` internally. Renaming those to `b-read` / `b-write` made them *backend-agnostic for free*. If they had been written as pure-value-in/value-out fire-fns, the refactor would have required a much-larger restructuring at fire-fn-site granularity, not just primitive-rename granularity.

2. **The kernel callback ABI matched the Racket fire-fn shape closely.** `(boxed-input1 ... boxed-inputN) → boxed-output` mapped naturally to a wrapper that reads inputs, invokes the Racket fire-fn under the backend, returns the (already-written) output cell value. Zero ABI redesign needed.

3. **The Python regex script for the primitive rename worked on the first try.** Pattern-matched `(define-values (NET CID) (net-new-cell SRC ...))` correctly across 28 sites with the variable swap; only 2 manual edits needed (the parameterize-wrapped sites). If the call-site shapes had been more varied, the script would have needed iteration.

4. **The kernel's tags 0-7 native fire-fns were already implemented and reachable.** The pre-refactor preduce-hybrid had wired them up; after the regression, restoring the wiring just needed the `#:native-op` hint plumbing. If the kernel's native tags hadn't existed yet, the regression fix would have required kernel-side work.

5. **The OCapN escalation path didn't surface a genuine architectural bug.** Programs 1-10 each added new stress, and each one ran end-to-end. The only failures were Pitfall #1 (FQN nil — pre-existing, worked-around) and Pitfall #3 (prelude shadowing — user error). The architecture held across all 10 programs without modification.

6. **External challenges came at the right cadence.** The user's three corrections (threading model, parallel-impl debt, native ns) each hit *before* the wrong path had landed too deeply to back out. Slight differences in timing — a challenge after the next commit, or after another design draft — would have made each fix more expensive.

## 12. What Surprised Us

1. **The mechanical primitive rewrite was simpler than expected.** I budgeted 2h for Phase 2 (the ~80-call-site rewrite); actual was ~1h, mostly Python script + retest. The shape of the rewrite — uniform substitution of one signature for another — turned out to be perfect for a regex pass. The signed surprise is that I'd planned a more-elaborate per-site review.

2. **The hybrid kernel runs OCapN programs FASTER than Racket-only PReduce-lite for non-trivial workloads.** W4 (the headline OCapN-shape match-on-unary-ctor) ran 2× faster on the hybrid kernel even with 100% Racket-callback dispatch. The kernel's Zig BSP scheduler beats Racket's `run-to-quiescence` once the program has ~5 propagators. Crossover point is below the size of any non-trivial OCapN program.

3. **Native ns = 0 for ALL OCapN programs (1, 2, 3, 4, 5, 6, 7, 10) except those with explicit int arithmetic (8, 9).** OCapN-shape workloads are pure user-ctor pattern matching; they don't touch int-arith. Phase 7 migration is needed to extend native dispatch to user-ctor match. The numbers concretely show how big that lever is: program 10's 44 callback fires at 4.5 µs each = 200 µs; if each became native at ~50-65 ns, the kernel time would drop to ~3 µs — a 60× speedup.

4. **The native-dispatch regression was invisible until the user asked about it.** I'd written a benchmark, captured numbers, presented them — and the "0 native fires across all workloads" was framed as "no native equivalents today." The actual story (the refactor LOST the native dispatch) only surfaced when the user explicitly prompted "is there a bug." **Implication**: "everything checks out" framings need adversarial framing.

5. **The pitfalls doc filled up faster than expected.** I opened it with one entry; by end-of-session it had four. Each new program surfaced something. The "stress test as bug-finder" pattern is much more productive than "code review as bug-finder" for compiler-stack work.

6. **`preduce-hybrid.rkt` collapsing 407 → 66 LOC was MORE satisfying than the new files compiling.** The new files (preduce-core, backend-racket, backend-hybrid) are infrastructure; the deletion of 341 LOC of duplicated compile-expr-hybrid is the user-visible refactor outcome. Cycles of "build new while old still exists" are common; the deletion phase is what proves the refactor.

7. **`'hybrid` sentinel as net = unit value works perfectly.** I expected this to need some massaging — special-casing in `b-read` / `b-write` for "the net is a sentinel, ignore it." Actual: backend-hybrid's read/write don't reference the net argument at all (the kernel state is global); the sentinel just flows through formally. Zero fragility.

## 13. Architecture Assessment

**Did the refactor integrate cleanly?**

Yes — purely additive at the new files (`preduce-core.rkt`, `preduce-backend-racket.rkt`, `preduce-backend-hybrid.rkt`) and via mechanical rewrite at the existing files (`preduce.rkt`, `preduce-hybrid.rkt`). No existing test or downstream consumer needed source changes — `preduce.rkt`'s public API (the `preduce` entry point, `preduce-user-ctor`, `preduce-bot`, `current-use-preduce?`, etc.) is preserved; `preduce-hybrid.rkt` still provides `preduce-hybrid` and `preduce-hybrid-supported?`.

**Were extension points sufficient?**

- **`preduce-backend` struct** (7 fields, all functionally threading `net`): sufficient for both backends. The `#:native-op` keyword arg added during the regression fix didn't require a struct schema change — the field's lambda value can have any signature that the b-* shorthand passes through.
- **`b-*` accessor shorthands**: clean call-site syntax (`(b-alloc net v)` vs `((preduce-backend-alloc-cell (current-backend)) net v)`). Worth the 7 extra one-liner definitions.
- **`current-backend` parameter**: the threading-discipline link. Set by entry points (`preduce`, `preduce-hybrid`); read by `b-*` shorthands. Standard Racket parameterize discipline; nothing exotic.
- **`NATIVE-OP-TAGS`** (in backend-hybrid): symbol → tag map for native dispatch. New native ops at Phase 7 just add rows here.

**Friction points**:
- Two thin sentinel constructors in each backend (`backend-racket-error-sentinel` + `backend-hybrid-error-sentinel`) for cases where the lattice isn't yet bound. Defensive but never actually used in normal flow. Keep — they're cheap.
- preduce.rkt's `compile-expr` is exported but its body lives in preduce.rkt, not preduce-core.rkt. Asymmetric with backend-{racket,hybrid}.rkt being separate. Cosmetic; future cleanup.

**Network reality check** (per `workflow.md` mandatory gate for propagator tracks):
1. **`net-add-propagator` calls added?** Yes — at the same 33 sites in preduce.rkt that pre-refactor invoked `net-add-fire-once-propagator` directly. The b-* indirection didn't reduce the install-site count; it added a backend-dispatch layer between the caller and the primitive.
2. **`net-cell-write` calls produce results?** Yes — fire-fn closures (which the refactor preserved unchanged) still call `b-write` (which routes through the backend's write-cell to either `net-cell-write` or `prologos_cell_write`).
3. **Cell creation → propagator install → cell write → cell read = result traceable?** Yes through both backends. The hybrid path additionally crosses the FFI boundary at install-time (`prologos_propagator_install_*`) and at fire-time (the kernel invokes the Racket callback via `function-ptr`).

✅ Network reality check passes. The refactor preserves the on-network shape; only the substrate (Racket prop-network vs. Zig kernel) varies by backend.

**Mantra alignment** ("All-at-once, all in parallel, structurally emergent information flow ON-NETWORK"): the refactor preserves all five words. The shared compile-expr produces the same propagator network shape; only the substrate varies. The functional threading discipline is the bridge to native execution, where the network IS information that flows through cells.

## 14. What This Enables

1. **OCapN-on-kernel as a benchmark workload class.** 10 OCapN programs validated; each is a profile target for Phase 7. The "kernel ns" + "native vs callback fires" data is captured for each.

2. **Trivially extending kernel coverage to new AST nodes.** Any new Phase 11+ AST case that lands in `preduce.rkt`'s compile-expr is automatically available to the hybrid kernel via Racket-callback dispatch — no per-AST-case porting work.

3. **Phase 7 native migration as a 2-line change per op.** Implement the kernel-side fire-fn + add a row to `NATIVE-OP-TAGS`. Done. The migration loop (read profile → pick hot tag → port to Zig → measure) is now mechanical.

4. **A future `backend-native` for SH Track 9.** The `net` value becomes a cell-id; `b-alloc` becomes a propagator; compile-expr itself becomes a propagator program over network-valued cells. The functional threading discipline drop-in works.

5. **The pitfalls doc as a stress-testing artifact.** Each ambitious program is a probe; surfaced bugs land in a tracked place. The "stress-test as bug-finder" loop has its own home now.

6. **A pattern for future refactors with similar shape.** "Two parallel implementations sharing N% of logic" is a common Prologos pattern (see runtime/core/ for the analogous Zig-side factoring debt). The swappable-backend pattern is now a worked-example template.

## 15. Technical Debt

| Debt | Rationale | Path to retire |
|---|---|---|
| `compile-expr` body lives in `preduce.rkt` not `preduce-core.rkt` | Cosmetic asymmetry; works fine | Future cleanup; ~30 min |
| N-1 propagator install in backend-hybrid errors on `n_inputs > 3` | Not triggered by any Phase-1-10b workload | Add when needed; ~45 min |
| Pitfall #1 (FQN nil lookup) | Workaround in test programs | ~30 min if dual-lookup pattern fixes it |
| Pitfall #3 (prelude-shadowing diagnostic) | UX issue, not correctness | ~1h in the elaborator |
| Pitfall #4 (identity-bridge `#:native-op`) | Easy 5-LOC fix; missed optimization on some paths | ~5 min |
| Phase 15c differential generator extension | The only known coverage gap (no random user-ctor terms) | ~30 min |
| The 10 OCapN programs are smoke tests, not regression gates | Run by hand via `dist/.../bin/prologos --profile`; not in `raco test` | Wire in if a regression surfaces |
| Native dispatch limited to int-arith + identity (tags 0-7) | Phase 7 territory; OCapN-shape workloads have no native equivalent today | Phase 7 migration loop |
| Two parallel reducers in two languages (preduce-lite Racket-only via backend-racket vs hybrid via backend-hybrid + Zig kernel) | Different consumers, different deployment targets | Long-term: SH Track 9 unifies both into native compile-expr; until then, both stay |

**No undeclared debt.** Every shortcut is named here or in pitfalls.md with the path to close it.

## 16. What Would We Do Differently

1. **Pick the threading model against the SH-endpoint fit FROM THE START.** I picked Option B (side-effecting) for "minimum hybrid-side scaffolding," optimizing for today's code instead of where the architecture is going. User had to challenge before any code committed. Future refactor design plans should explicitly ask: "what's this look like at the SH endpoint?"

2. **Don't declare a refactor "done" until the OLD code is deleted.** After Phase 4 the codebase had BOTH the new shared path AND the 407-LOC parallel impl. I would have moved on to Phase 7 if the user hadn't checked. Future refactors: "have I deleted the thing this is supposed to replace?" goes on the phase-close checklist.

3. **Add a perf regression net to the test suite, not just correctness.** The native-dispatch regression slid through the differential gate because the gate only checks RESULT correctness. Should run the benchmark on every refactor commit; should fail the commit if any workload regresses by more than X%.

4. **Open the pitfalls doc proactively, not after the first bug.** I opened it after Pitfall #1; the FormatBuffer bug (Pitfall #2) had already happened by then and got back-filled. If I'd opened it at start-of-session, the discovery cadence would've been more disciplined — each pitfall logged as it surfaced.

5. **Commit the per-section primitive rewrite incrementally.** Phase 2 was one commit applying ~133 edits. Bisect granularity is "rewrite-everything." Future mechanical rewrites: split into per-AST-case-region commits, or at least pre-edit / mid-edit / post-edit, even if all green.

6. **Write the benchmark BEFORE the refactor, run it on every commit.** I wrote it after Phase 6 (post-refactor), so the first benchmark numbers were post-fact. Pre-refactor baseline numbers would have made the regression discovery faster (instead of "let's see what the numbers look like" → "wait, native ns is 0?").

Otherwise the design held. The phased plan, functional-threading commitment (post-flip), pitfalls discipline, mechanical-rewrite tactic all delivered.

## 17. What Assumptions Were Wrong

1. **"Side-effecting backend interface is simpler."** Wrong for in-and-out-of-native fit. Functional threading is BOTH simpler today (preserves preduce.rkt's existing shape; backend-hybrid threads a unit sentinel with zero cost) AND right for the SH endpoint. The "simpler" framing was about today's code; the architecture demanded a different optimization axis.

2. **"After Phase 4, the refactor is architecturally done."** Wrong. The OLD parallel impl was still in tree. I'd built a new path without deleting the old; declaring victory was premature.

3. **"The differential gate is sufficient regression coverage."** Wrong for perf. The gate caught zero regressions (great for correctness) but masked the native-dispatch loss because both backends produced equal results — just at different speeds. Need a perf regression net.

4. **"OCapN programs will surface a flood of bugs."** Wrong — only 4 distinct pitfalls across 10 programs of escalating ambition. The architecture held remarkably well. Most "bugs" surfaced were elaborator/lookup issues that affect ALL backends, not refactor-specific.

5. **"The hybrid kernel will be slower than Racket for small workloads."** Half-wrong. W1 (bare alloc) is slower; W2 (1-prop) is parity; W3 (2-prop) is slightly slower; W4+ (5+ props) is FASTER. Crossover happens at ~5 propagators per program — much lower than I expected. Real OCapN programs (8-44 propagators each) are all on the fast side.

6. **"Phase 7 migration is the next big lever."** Half-right. It IS the next big lever for OCapN programs (where 100% of fires are callbacks), but smaller than the lever the refactor itself unlocked: extending Phase 1-10b coverage to the kernel for free via callback dispatch. The architecture's payoff is bigger than its next step.

7. **"`'hybrid` sentinel will need special-casing."** Wrong. backend-hybrid's read/write don't reference `net` at all — kernel state is global; the sentinel just flows through formally. Zero special-casing needed.

## 18. What We Learned About the Problem Itself

1. **Functional threading IS the dataflow edge in native execution.** The `net` parameter that looks like an implementation detail today (Racket-only PReduce-lite) is what becomes a real cell-id when compile-expr runs natively. Side-effecting via a parameter would break this. The architectural invariant: compile-expr is a `pure-ish` function from AST to network value (modulo backend-side cell allocation, which can be modeled as the pure cell-allocation monad). This invariant IS the bridge to self-hosting.

2. **The "two parallel implementations" pattern is recurring in Prologos.** Already paid down at the Zig layer (runtime/core/ shared by two kernels — though scheduler stayed unfactored, see Hybrid PIR §15). Now paid down at the Racket layer (preduce-core/ shared by two backends — though compile-expr-body stayed in preduce.rkt, future cleanup). The pattern: factor at the SECOND-instance, not the first. Two consumers is enough signal that a third will arrive.

3. **Symbolic operation names + per-backend tag-maps is the right abstraction for native dispatch.** preduce.rkt names operations (`'int-add`, `'identity`); backends own translation. Mirrors how compilers handle target-specific intrinsics. Phase 7 migration becomes "add a kernel fire-fn + add a row to the map."

4. **External adversarial review caught all 3 architectural drift points.** None of my internal validation gates caught: (a) wrong threading model, (b) parallel impl not deleted, (c) native dispatch lost. **The pattern**: when the implementer decides the architecture is "done," they're WRONG; user review is load-bearing. This is a longitudinal pattern across multiple PIRs now (see hybrid PIR §17 #9 + this one's bug 4 + 5).

5. **Kernel-shipped programs make the architecture visible.** Synthetic benchmarks (W1-W5) gave per-call wall time, but "10 OCapN programs of escalating ambition all run on the kernel" is a much stronger claim. Each program is concrete evidence of coverage; the `--profile` per-program is concrete evidence of the kernel's actual behavior on real workloads.

6. **Silent buffer truncation is the worst class of kernel bug.** No error, valid-looking partial output, downstream parsers crash. Kernel-side print code MUST error on overflow. The `FormatBuffer.putc`'s `if (self.len < self.buf.len)` is exactly the pattern to ban — a no-op silent drop.

## 19. Are We Solving the Right Problem?

Yes.

The user's stated arc was clear: "I want to run a non-trivial Prologos program on the kernel and see how time is spent." The refactor delivers that — 10 programs of escalating ambition all run end-to-end through the kernel via the unified compile-expr; per-program profile shows native vs callback breakdown; pitfalls captured for future work.

The architectural payoff is bigger than the user-stated arc:
- preduce-hybrid.rkt (the parallel-impl debt called out in the Hybrid PIR's §15) collapsed from 407 → 66 LOC.
- Kernel coverage extended from Phase 8b (~20 nodes) to Phase 1-10b (~120 nodes) — 6× larger AST surface — at zero per-AST-case porting cost.
- Phase 7 native migration becomes a 2-line change per op.
- The functional-threading discipline + symbolic-op-hints architecture is the bridge to SH Track 9 (compiler-in-Prologos).

Frame check: was the threading-model flip the right call? Yes — Option A delivers everything Option B would have delivered (unified compile-expr, kernel-validated) PLUS in-and-out-of-native fit at zero cost. Option B's "minimum hybrid-side scaffolding" framing was optimizing for today's code at the expense of tomorrow's architecture.

Frame check 2: should Phase 7 (native migration on real workloads) have been part of THIS refactor, not deferred? No — Phase 7 is orthogonal. The refactor ships an extensibility mechanism (`#:native-op`); Phase 7 USES it. Bundling them would have made the refactor harder to validate (architectural correctness vs perf regression) and harder to bisect.

A meta-question: was the refactor justified, given that pre-refactor preduce-hybrid.rkt worked (Phase 8b coverage)? Yes — the cost of the duplicated 407-LOC parallel impl was already paid every time a new Phase landed in preduce.rkt without porting to preduce-hybrid (Phase 10b had this gap). The refactor pre-pays for all future phases.

## 20. Longitudinal Survey — 10 Most Recent PIRs

| PIR | Date | Pattern observed in this work |
|-----|------|-------------------------------|
| **Backend Refactor (this)** | **2026-05-04 PM** | (self) |
| Hybrid Runtime PIR | 2026-05-04 AM | **Direct successor** — this refactor closed the "two parallel reducers" debt called out in §15 + §17 #9 of that PIR. The "phase-close should compare delivered scope against design plan" lesson surfaced for the THIRD time (1: BSP scheduler scope drift in Hybrid PIR; 2: parallel-impl debt in this refactor's Phase 4; 3: native-dispatch loss in this refactor's first benchmark). Pattern is now confirmed load-bearing. |
| PReduce-lite PIR (consolidated) | 2026-05-04 AM | Direct upstream — this refactor consumes preduce.rkt's compile-expr via the new backend interface. PIR addendum updated with the refactor narrative. |
| BSP-LE Track 2B | 2026-04-16 | Stratification + topology — refactor reuses fire-once + cell allocation; threading-model flip avoided needing new strata. |
| BSP-LE Track 2 | 2026-04-10 | Worldview cells + ATMS — not used (lite skips speculation; backend-hybrid inherits). |
| PPN Track 4B | 2026-04-07 | Component-paths — not needed; cells are scalar. |
| PPN Track 4 | 2026-04-04 | **Network reality check** — refactor passes: 33 install sites preserved, results via `b-write`, full trace from input cell through fire-once chains to output cell across both backends. |
| SRE Track 2D | 2026-04-03 | Test-delta-zero anti-pattern — *not* repeated. +4 hybrid-phase10b tests + 10 OCapN programs landed in the same commits as the refactor. |
| SRE Track 2H | 2026-04-03 | F7 disproof — irrelevant. |
| SRE Track 2G | 2026-03-30 | Pocket Universe scaffolding — kernel-PU consumes the hybrid backend (open question). |
| PPN Track 3 | 2026-04-02 | "Datum-canonical" drift — *avoided*; refactor is on-network throughout. |

**Recurring pattern this refactor participates in**: "Phased plan with per-phase regression gates produces clean retrospectives." 5+ recent PIRs follow this; this refactor adds another data point.

**Recurring pattern this refactor breaks**: "Refactor declared done with parallel impl still in tree." Both the Hybrid PIR (BSP scheduler not in core) and this refactor's initial Phase 4 (preduce-hybrid.rkt not yet thin) had this. Codified as "phase-close must verify the OLD impl is gone."

**Pattern strongly reinforced**: **External adversarial review catches what internal VAG misses.** Three corrections from the user (threading model, parallel impl, native ns) shaped the final architecture. The implementer's "this is done" is WRONG by default until challenged. Two prior PIRs (Hybrid PIR + PReduce-lite consolidated PIR) had similar instances. **Three data points; codify in `workflow.md` as "the implementer cannot grade their own work."**

**Pattern this refactor newly exhibits**: "Stress-test as bug-finder beats code-review as bug-finder for compiler-stack work." 10 OCapN programs of escalating ambition surfaced 4 pitfalls (1 new bug, 1 fixed in passing, 2 UX/optimization gaps); equivalent code-review effort would not have found them. Codified in pitfalls.md format.

## 21. Lessons Distilled

| Lesson | Distilled To | Status |
|--------|-------------|--------|
| Threading model: pick against SH-endpoint fit, not today's code | `DESIGN_METHODOLOGY.org` candidate addition | Pending |
| Refactor not done until OLD impl is deleted; "I built a new path" ≠ "duplication is gone" | `workflow.md` candidate; phase-close checklist | Pending — codify after this PIR + Hybrid PIR §17 #9 establish the pattern |
| Perf regression net needed alongside correctness regression net | `testing.md` candidate addition | Pending |
| External adversarial review catches what internal VAG misses (3 instances now) | `workflow.md` candidate; "the implementer cannot grade their own work" | Pending — codify after a 4th instance? Or ship now since 3 is enough? |
| Symbolic op names + per-backend tag maps for native dispatch | This PIR; reusable for any future backend that has native dispatch | Done — the `#:native-op` mechanism is the codification |
| Open pitfalls.md proactively at start of stress-testing work | Dailies / workflow | Pending |
| `'<sentinel>` as net = unit value works perfectly for side-effecting backends | This PIR | Done — pattern codified by example |
| Silent buffer truncation in kernel print code is the worst class of bug | `propagator-design.md` adjacent | Pending — codify as "kernel print code MUST error on overflow" |
| Mechanical rewrites benefit from per-section commits even when all green | `workflow.md` candidate | Pending |
| Stress-test as bug-finder for compiler-stack work | This PIR + pitfalls.md | Done — pattern codified by the OCapN escalation |

## 22. Metrics

| Metric | Value |
|---|---|
| Wall-clock duration | ~5h |
| Commits | 12 |
| Files added | 7 (preduce-core + 2 backends + phase10b test + benchmark + design doc + pitfalls doc) |
| Files modified | ~6 (preduce.rkt, preduce-hybrid.rkt, format.zig, NOTES.md, both 2026-05-04 PIRs) |
| OCapN programs run end-to-end on kernel | 10 |
| Code delta | ~+2000 (new files) − 341 (preduce-hybrid.rkt thin) + 1 (FormatBuffer) ~ +1660 net |
| Pre-refactor preduce-hybrid.rkt LOC | 407 (Phase 8b coverage) |
| Post-refactor preduce-hybrid.rkt LOC | 66 (Phase 1-10b coverage) |
| AST coverage on kernel | Phase 8b → Phase 1-10b (~6× larger) |
| Bugs caught by user adversarial review | 3 (threading model, parallel impl, native ns) |
| Bugs caught by internal validation | 2 (multi-value capture, FormatBuffer) |
| Pitfalls discovered | 4 (1 fixed, 1 worked-around, 2 open) |
| Test count delta | +4 hybrid-phase10b + 10 OCapN end-to-end programs + 5-workload benchmark |
| Suite regression | 0 (133 affected-file tests stay green at every phase boundary) |
| Differential gate | 13/13 three-way preserved |
| Headline benchmark | W4 (OCapN-shape) hybrid 2× faster than lite; W5 (int-arith) post-fix 31% faster wall + 14× faster kernel-side |

## 23. Key Files

### New (post-refactor architecture)

| Path | Role |
|---|---|
| `racket/prologos/preduce-core.rkt` | Backend interface — `preduce-backend` struct + `b-*` shorthands + `current-backend` parameter |
| `racket/prologos/preduce-backend-racket.rkt` | Racket backend instance; wraps `propagator.rkt` primitives |
| `racket/prologos/preduce-backend-hybrid.rkt` | Hybrid backend instance; wraps the Zig kernel FFI + owns `NATIVE-OP-TAGS` |

### Modified (mechanical rewrite)

| Path | Role |
|---|---|
| `racket/prologos/preduce.rkt` | Lattice + compile-expr + ~120 AST cases; rewritten through `b-*` shorthands; entry-point parameterizes `current-backend = backend-racket-with-lattice ...` |
| `racket/prologos/preduce-hybrid.rkt` | Thin 66-LOC wrapper; parameterizes `current-backend = backend-hybrid` |
| `runtime/core/format.zig` | `FormatBuffer.buf: [8192]u8` (bumped from 1024 to fix profile-JSON truncation) |

### Tests + benchmarks + examples

| Path | Role |
|---|---|
| `racket/prologos/tests/test-preduce-hybrid-phase10b.rkt` | 4 cases — Phase-10b user-ctor on kernel |
| `racket/prologos/tests/bench-ocapn-hybrid-vs-lite.rkt` | 5-workload benchmark (W1-W5) |
| `racket/prologos/examples/ocapn/ocapn-hybrid-{1..10}.prologos` | 10 OCapN programs of escalating ambition |

### Docs

| Path | Role |
|---|---|
| `docs/tracking/2026-05-04_PREDUCE_BACKEND_REFACTOR_DESIGN.md` | Design plan with phased rollout |
| `docs/tracking/2026-05-04_BACKEND_REFACTOR_PIR.md` | This PIR |
| `docs/tracking/2026-05-04_PROLOGOS_LANGUAGE_PITFALLS.md` | Pitfalls tracking doc (4 entries) |
| `racket/prologos/lib/prologos/ocapn/NOTES.md` | OCapN compatibility-target notes; "Hybrid kernel test status" table |
| `docs/tracking/2026-05-04_PREDUCE_LITE_PIR.md` | PReduce-lite PIR with refactor addendum |
| `docs/tracking/2026-05-04_HYBRID_RUNTIME_PIR.md` | Hybrid Runtime PIR with refactor addendum (debt closure) |

## 24. Open Questions Surfaced

1. **When does Phase 7 (native migration on OCapN-shape callbacks) happen?** Profile data is captured for all 10 programs; targeting is ready. Implementing a kernel-native fire-fn for "match-on-user-ctor with N arms" is the obvious first target. ~1.5 h. Gating: when does kernel-native user-ctor support become user-value-positive? Today the architecture is validated; kernel speedup is incremental.

2. **Does the parallel-impl debt at the Zig layer (BSP scheduler not in core) need its own refactor?** The pattern is the same shape as this refactor — two kernels (original LLVM-target + hybrid) sharing data structures but not the scheduler. Hybrid PIR §15 has the debt entry. Same "factor at second-instance" reasoning applies. ~1 day.

3. **Should the pitfalls.md format extend to the upstream OCapN goblin-pitfalls.md?** Today: separate docs for separate pitfall classes (compiler stack vs OCapN design). Could converge if the format is genuinely good for both.

4. **Is the differential gate sufficient regression coverage post-refactor?** It caught zero refactor-introduced regressions but missed the perf regression. Need a perf differential gate (run benchmark on every commit, fail if any workload regresses by >X%).

5. **When should `compile-expr` migrate from `preduce.rkt` to `preduce-core.rkt` for symmetry with the two backend modules?** Cosmetic asymmetry; functional behavior unchanged. Defer until growth makes preduce.rkt unwieldy.

6. **Should the OCapN-on-kernel programs be wired into `raco test` as a regression gate?** They're smoke tests today (run by hand via `dist/.../bin/prologos --profile`). Wiring them in would catch refactor-introduced semantic regressions on real programs. Cost: harness work to invoke the binary + parse the result + assert equality.

7. **Does the "external adversarial review catches what internal VAG misses" pattern need codification in `workflow.md` after THIS PIR (3 instances), or wait for a 4th?** I'd codify now — three independent recent occurrences is enough signal.
