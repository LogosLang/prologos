# OCapN Phases 37 through 53.d — Post-Implementation Review

**Date**: 2026-05-18
**Duration**: ~3 weeks calendar (multi-session)
**Commits**: 26 (from `eb48102` Phase 37 through `c0991f9` Phase 52b CI wiring)
**Test delta**: 225 (baseline at PIR 2026-05-04) → 222+ across OCapN-touching files (≈140 bridge, 34 protocols, 9 interop, ~40 across pipelining/handshake/RPC/message)
**Code delta**: 6452 insertions / 800 deletions / 83 file-touches summed across commits (24 unique production+test files modified)
**Suite health**: 222 OCapN tests across 10 files green at HEAD; full suite has been green on every phase boundary
**Branch**: `claude/ocapn-prologos-implementation-auLxZ`
**Design docs**: extends [`2026-04-29_OCAPN_INTEROP_DESIGN.md`](2026-04-29_OCAPN_INTEROP_DESIGN.md); predecessor [`2026-05-04_OCAPN_INTEROP_PIR.md`](2026-05-04_OCAPN_INTEROP_PIR.md) closed Phases 0–21.

---

## 1. What Was Built

This PIR covers Phases 37–53.d of the OCapN port, extending the Phase-0–21 wire-and-vat foundation captured in the prior PIR with:

- **Pipelining state machine** (Phases 38–46): receiver-side `op:deliver` dispatch when the target is `<desc:answer N>` from one of OUR inbound questions, sender-side `bridge-send-question` + answer-resolution, wire-out forwarding when the pipelined promise resolves to `<desc:export K>` / `<desc:answer M>` / a local actor, **break-forwarding** (broken promise → error answer at peer's queued ap), and **plain-value-as-error** (resolution to a non-callable → "deliver-to-non-callable" error). The user's design principle "**we never drop a queue**" is now enforced across all 6 `PromiseState` shapes.
- **Bridge-side state lifecycle** (Phases 47, 50, 51): GC of `bs-pipelined-msgs` after pump emits forwarding bytes; declarative `connection-queue-release-import` that stages `op:gc-export` on `pending-out` for next-pump flush; late `op:listen` registration (one arriving after the target settles fires immediately rather than leaking a never-notified entry).
- **op:listen notification end-to-end** (Phase 48): registered listeners fire on resolution via `op:deliver` to peer's `<desc:export resolver>`, with one-shot GC and ordering pinned.
- **Gift-handoff foundation** (Phases 52 + 52b revised): `bs-gifts` table; `op:deliver`-to-bootstrap method dispatch (`deposit-gift` / `withdraw-gift`) matching `@endo/ocapn`'s canonical model; reply via standard `op:deliver-to-answer`. Wire-shape cross-impl gate validates `@endo` decodes our bytes correctly.
- **Session-type specifications** (Phase 53 + 53.a + 53.d): 8 OCapN protocols expressed as session types in `protocols.prologos` — `Handshake`, `QuestionAnswer`, `PipelinedQuestion`, `ListenProtocol`, `GcExport`, `GiftWithdraw`, `GiftDeposit`, `CapTPSession`. Payload type refined to `CapTPOp`. Broken-promise outcomes encoded via `:throws SyrupValue`.

Why it matters: Phase 0–21 shipped the wire codec + a single-deliver request/reply. Everything in this PIR builds on that to make the bridge handle the real OCapN protocol shapes (pipelining, listeners, GC, gift handoff). The wire-out closure of the pipelining loop is the highest-value piece: without it, queued pipelined messages on a resolved promise would have been silently dropped, which the user (correctly) called out as a violation of the never-drop-a-queue principle.

Code example — a peer pipelines a message on a Q we asked, we resolve to a refr, the bridge forwards:
```prologos
;; Pre: bs-questions has (peer-q-pos → local-pid).
;; Peer sends: op:deliver <desc:answer N> args ap rm
;; Phase 38 receives + Phase 41 forwards on resolve:
captp-incoming-with-state (op-deliver-to-answer N args ap rm) v st
  → dispatch-incoming-answer → if N ∈ bs-questions, queue args on local-pid
;; Later, local-pid resolves to <desc:export K>:
pump-outbound v' st emitted
  → for each (pid, pms) where pid resolved + not yet emitted:
    → outbound-from-resolution → resolution bytes for peer's q-pos
    → build-forward-effect:
      → for each PipeMsg with pid: emit forwarding bytes to <desc:export K>
```

## 2. Timeline and Phases

| Commit | Phase | What |
|---|---|---|
| `eb48102` | 37a | `desc:import-object` decode + encode (5th refr kind) |
| `e68af4e` | 37b | Cross-impl gate for desc:import-object |
| `2b0304b` | 38 | Wire-level promise pipelining (responder) |
| `3f1fb74` | 39 | Questioner-side pipelining (sender) |
| `a0c8620` | 40 | Pipelining cross-impl gate |
| `6dc1b23` | 41 | Wire-out closure — forward on `<desc:export K>` resolution |
| `1eca865` | 42 | Local-actor pipeline forwarding |
| `f134733` | 43 | Wire-out cross-impl + syrup-int decode fix |
| `42f6640` | 44 | Chained-answer pipelining (`<desc:answer M>` resolution) |
| `6f1120c` | 45 | Break-forwarding (broken promise → error answer at peer's ap) |
| `14c6d7e` | 46 | Plain-value-as-error (non-callable resolution → error answer) |
| `6fca1de` | 47 | GC pipelined-msgs after pump |
| `a990e2f` | 48 | op:listen notification on resolution |
| `532a1e4` | 49 | Break + plain-value cross-impl gates |
| `2e27be7` | docs | Pitfalls #36–#38 + syntax rule |
| `5df8334` | 50 | Declarative release-import via pending-out |
| `2f46e29` | 51 | Late op:listen + multi-listener ordering pinned |
| `ef8d9da` | 52 | Gift-table state scaffolding (BridgeState 9th → 10th field) |
| `c0efdd5` | 53 | OCapN protocols as session types — specification + duality |
| `8a103d6` | docs | Roadmap captures branch state + outstanding session-types work |
| `6d10c58` | 52b (non-canonical, later reverted) | Dedicated op:deposit-gift / op:withdraw-gift CapTPOp variants |
| `97ad93c` | 53.a | Session payload `String` → `CapTPOp` |
| `07d73d3` | docs | Phase 53.a commit hash in roadmap |
| `6d199a6` | docs | Flag 52b non-canonical |
| `c28f44e` | 53.d | `:throws SyrupValue` on broken-promise protocols |
| `1a67f23` | 52b revised | Gift handoff via bootstrap-method dispatch + cross-impl gate |
| `c0991f9` | CI | Phase 52b interop in CI workflow |

Design-to-implementation ratio: design happened conversationally in user turns (no long-running design doc), so the ratio is "near 1:1 — design and implementation interleaved per phase." This is appropriate for small phases (most were 1-3 hours each); larger phases (52b revert+rewrite, 53.d) would have benefited from a written design pass first.

## 3. Test Coverage

**Test files added during this arc**:
- `test-ocapn-pipelining-interop.rkt` — Phase 40 cross-impl
- `test-ocapn-pipeline-forwarding-interop.rkt` — Phase 43 cross-impl
- `test-ocapn-import-object-interop.rkt` — Phase 37 cross-impl
- `test-ocapn-break-plain-interop.rkt` — Phase 49 cross-impl (combined break + plain-value)
- `test-ocapn-protocols.rkt` — Phase 53 session-types specification
- `test-ocapn-bootstrap-gift-interop.rkt` — Phase 52b cross-impl

**Test files extended**:
- `test-ocapn-bridge.rkt` (140 → 149 cases): pipelining, GC, listeners, gift-table state + dispatch

**Test counts by category** (at HEAD):
- Bridge unit + dispatch: 149
- Protocol session-types: 34
- Pipelining: ~12
- Message + handshake + RPC + conversation + handshake + abort: ~30
- Promise: ~10
- Cross-impl interop: 5 test cases (across 5 files, each spawning a Node peer)

**Gaps acknowledged**:
- Three-vat handoff (54+): no test (multi-connection state not yet implemented)
- Real `@endo` gift handler interop (signed HandoffReceive envelopes): out of scope — wire-shape compatibility is what's tested
- Session-typed runtime: protocols are SPECIFICATIONS, not runtime witnesses (Phase 53.b–53.f deferred)

## 4. Bugs Found and Fixed

| Bug | Phase | Root cause | Fix |
|---|---|---|---|
| `op-deliver-to-answer` lost answer-pos for break-forward | Phase 44 | The ADT initially had `Nat -> SyrupValue` (just q-pos + args); Phase 45 needed ap+rm to know where to send error answers | Extended to `Nat -> SyrupValue -> [Option Nat] -> [Option Nat]`; updated 14 tests at the call surface |
| Stale `.pnet` caches across ADT changes | Phase 44–45 | After ADT shape changes, the on-disk pnet cache held outdated forms; tests passed individually, failed in batch | Manual `find data/cache -name '*.pnet' -delete` between phases; codified pattern as routine |
| Multi-line ctor application eaten by reader | Multiple phases (most visible in Phase 48) | Continuation line starting with a bare identifier is parsed as a sibling application, not as more args to the previous head | Inline positional args to one line; codified as pitfall #36 |
| Single-arg multi-arity `defn` infers phantom 2nd param | Phase 48 (`resolution-syrup-of-pst`) | `defn name | [pat1] -> ... | [pat2] -> ...` with single-pattern arms made the elaborator lift a free type-var into an extra Pi binder | Use `defn name [arg] match arg | ...` form; codified as pitfall #37 |
| Variable name shadows data constructor | Phase 52b (`refr`) | The `Refr` data type's `refr` ctor shadowed my pattern binding `refr`; runtime got the ctor function, not the bound value | Rename to `gift-refr`; codified as pitfall #42 with constructor-name avoid-list |
| `rackunit/check-true` strict for `#t` | Phase 53 | `(check-true (assq ...))` fails because `assq` returns a pair (truthy but not `#t`) | Use `(check-not-false ...)` or `(and ... #t)`; codified as pitfall #39 |
| Wire format invented before checking peer (52b non-canonical) | Phase 52b | Designed dedicated `op:deposit-gift`/`op:withdraw-gift` wire ops without checking that `@endo/ocapn` uses bootstrap-method dispatch. Mid-PIR, was logged as pitfall #43; user pointed out goblin-pitfalls is for Prologos language/tooling, not OCapN methodology — removed | Reverted the wire ops, re-implemented dispatch as bootstrap method-call recognition (target=0 + symbol-prefix args). Methodology lesson lives in this PIR's §6 instead |
| `@endo`'s syrup symbols carry `syrup:` namespace prefix | Phase 52b interop debug | `@endo/ocapn`'s syrup decoder prefixes decoded symbols with `syrup:` (`Symbol.description === 'syrup:deposit-gift'` rather than `'deposit-gift'`) | Peer's `isSymWithSuffix` accepts both forms — defensive but tested only once |

## 5. Design Decisions and Rationale

| Decision | Rationale |
|---|---|
| Bridge-side `bs-pipelined-msgs` queue separate from vat-side promise queue | Vat-side queue gets wiped on `resolve-promise` (it's for in-process pipelining). The bridge needs a separate queue that SURVIVES fulfillment so pump-outbound can emit forwarding bytes. Trade-off: extra storage; never-drop-a-queue requires it. |
| Plain-value-as-error returns `<Error "deliver-to-non-callable">` | OCapN spec is silent on what to do when a queued msg targets a resolution that isn't a callable. The user's correction (mid-Phase 46) was "we never drop a queue" — so we must produce SOMETHING. The synthesized reason is descriptive enough for debugging. |
| Multi-listener ordering: outermost `bs-add-listener` emits LAST | `cons`-at-head + walk-and-prepend gives newest-first emission. OCapN spec doesn't mandate; we pin THIS order as the regression check so future refactors don't silently flip it. |
| Phase 52: gift-table state ships BEFORE wire ops | The state machinery is independent of the wire shape. Shipping the table first kept that 10-field BridgeState surgery isolated; the wire dispatch (52b) was free to be revised without disturbing the table. (Vindicated by the 52b revert: 52 was unaffected.) |
| Phase 52b: dedicated wire ops → reverted to bootstrap-method dispatch | User correctly flagged the non-canonical wire ops would never interop. The simpler `op:deliver`-to-export-0 form matches `@endo/ocapn` and lets gift handoff piggyback on the existing pipelining/answer infrastructure. |
| Session types as SPECIFICATIONS only (Phase 53) | Wiring session types into the runtime as live witnesses (53.b) requires a refactor of the bridge's match-on-CapTPOp dispatch. Specifications-only ship the documentation + duality-check value without that refactor. Honest "validated ≠ deployed" naming in the roadmap. |
| `:throws SyrupValue` (53.d) on QuestionAnswer / PipelinedQuestion / ListenProtocol / GiftWithdraw | These four can produce broken-promise outcomes via the existing wire path. NOT applied to Handshake / GcExport / GiftDeposit / CapTPSession (no reply path for the first three; per-op outcomes already inside CapTPSession's offered branches). |
| Goblin-pitfalls = Prologos language/tooling only | User correction mid-PIR: OCapN-specific methodology lessons live elsewhere (this PIR's §6 + DEVELOPMENT_LESSONS.org). Pitfalls #43 (wire-format-invented-before-checking) was removed; constraint preserved going forward. |

## 6. Lessons Learned

### 6.1. "We never drop a queue" is a load-bearing protocol invariant

When Phase 46 first shipped, the plain-value resolution path silently dropped queued messages targeting a non-callable resolution. The user's pushback — *"we never drop a queue"* — reframed the question from "what's the most reasonable behavior?" to "what's the protocol invariant?" The principle is stronger: ANY queued msg that reaches its target MUST produce an outcome (success, error, or chain-forward). Dropping is a bug. Codify this for future protocol-bridge work.

### 6.2. Cross-impl gates are mandatory infrastructure, not optional

Phase 52b's first revision shipped 50 sites of `CapTPOp` extension based on a conceptual model of gift handoff (deposit / withdraw as named operations). The check against `@endo/ocapn`'s actual wire shape happened AFTER all the code was written — and revealed the entire wire surface was non-canonical. The workflow rule was clear:

> External cross-impl gates are mandatory test infrastructure for protocol ports. Pattern: write a generator script that runs inside the foreign implementation, commit its output as a fixture, add a CI step `git diff --exit-code` on the fixture. Hand-written wire vectors are a last-resort substitute.

I violated it. The cost was ~30 minutes implementing the wrong surface + ~10 minutes reverting + ~45 minutes re-implementing the canonical form. Cheaper-than-I-feared because the gift TABLE was correctly isolated from the wire dispatch and didn't need rework. Still: ~85 minutes of work I'd have skipped by doing the check first.

**Crystallised**: for ANY wire-extension phase, Phase 0 is "search the reference implementation for the OP code or feature and confirm the wire shape." If the reference uses a different model, that's the design input, not an after-the-fact correction.

### 6.3. Prologos compile-clean but runtime-wrong from constructor shadowing

Pitfall #42 (variable name shadows data constructor) is a Prologos-specific bug class with dangerous failure mode: code compiles clean, output type is correct, runtime silently passes the constructor function instead of the bound value. The downstream call against a SyrupValue-shaped `match` simply matches none of the arms and returns a default. No error. No warning. Was detected only by inspecting the elaborator's printed body.

**Crystallised**: when writing a new handler arm in OCapN, grep the imported module's constructors first and pick variable names that don't collide. Convention list in the pitfall entry covers the common offenders.

### 6.4. Session-elaborator works fine cross-module, contrary to expectation

I had expected Phase 53.a (refine payload from `String` to `CapTPOp`) to require infrastructure changes — session types referring to imported data types felt like it might need fresh elaborator support. It didn't. Just adding `require [prologos::ocapn::message :refer [CapTPOp]]` made the cross-module reference work cleanly. The elaborator already handles it. (My expectation was inherited from the pattern that `:no-prelude` modules have stricter import requirements; turned out not to matter here.)

**Crystallised**: don't assume infrastructure is missing without trying first. Prologos has more cross-module hygiene than I sometimes credit.

### 6.5. `:throws` desugaring wraps every step, not just the top

I expected `session S :throws E (Send T (Recv U End))` to wrap once at the outermost: `Offer((:ok Send T Recv U End)(:error Send E End))`. Actually each step is wrapped: `Offer((:ok Send T Offer((:ok Recv U End)(:error Send E End)))(:error Send E End))`. The protocol formally accepts a fault transition at every step — which matches OCapN reality (any op can fault). The wrap-per-step behavior is in `elaborator.rkt:3669` `maybe-wrap-throws`.

**Crystallised**: Phase 53.d's tests needed an `unwrap-ok` helper to peel each layer; tests for nested protocols (like PipelinedQuestion) had to unwrap both at the top and inside each branch.

### 6.6. WS-mode reader pitfalls cluster around multi-line continuations

Pitfalls #36 (multi-line ctor app), #38 (let X := EXPR can't span lines), and #21 (multi-line clause body becomes match-fail) are all variants of the same root: WS-mode layout-rule continuation. The lexer/parser treats indented continuation lines as sibling forms, not as more args to the previous head. Workaround is always the same: inline to one line.

**Crystallised**: prefer single-line constructor applications even when verbose. If a line is unavoidably long, factor a sub-expression to a separate `let` or top-level helper rather than splitting positional args.

### 6.7. Goblin-pitfalls vs PIR vs DEVELOPMENT_LESSONS — different audiences

Mid-PIR the user corrected me: goblin-pitfalls is for Prologos LANGUAGE AND TOOLING bugs, not OCapN methodology. The cross-impl-gate-before-coding lesson (logged briefly as pitfall #43) was wrong genre — it's a workflow methodology issue, not a language bug. The document boundaries are:

- **`2026-04-27_GOBLIN_PITFALLS.md`**: Prologos language quirks, elaborator/parser bugs, syntax footguns. Audience: anyone writing `.prologos` code in this codebase.
- **PIRs**: per-track narrative with §6 lessons. Audience: this track's continuation.
- **`DEVELOPMENT_LESSONS.org`** + **`PATTERNS_AND_CONVENTIONS.org`**: distilled cross-PIR longitudinal lessons. Audience: any future track.

§10 below distills which lessons go where.

### 6.8. Belt-and-suspenders / non-canonical surface is a workflow-rule red-flag

Phase 52b's first version was a "dedicated wire ops" approach that DUPLICATED what the existing op:deliver dispatch could have done with a bootstrap-method recognition. The workflow rule from `.claude/rules/workflow.md` explicitly bans this:

> Belt-and-suspenders is a blocking red flag.

I should have noticed: "I'm adding new wire ops for something that could be done as a method call on an existing target" is exactly the dual-mechanism pattern. The fact that I was inventing surface area for behavior the existing infrastructure could express should have triggered the red-flag check.

**Crystallised**: when designing a new wire op, ask "could this be a method call on an existing target?" If yes, use that path. New wire ops are reserved for truly new operations (not new methods on existing objects).

## 7. Metrics

| Metric | Value |
|---|---|
| Phases shipped | 26 (incl. doc-only commits) |
| Production code (insertions) | ~6450 |
| Test code (insertions) | ~1100 |
| New test files | 6 |
| OCapN tests at end of arc | 222+ across 10 files |
| Cross-impl gates | 5 (pipelining, pipeline-forwarding, break-plain, import-object, bootstrap-gift) |
| Pitfalls codified (Prologos lang/tooling) | 4 new (#39, #40, #41, #42) |
| Reverted phases | 1 (52b non-canonical → 52b canonical, 1 day round trip) |
| Adversarial findings during implementation | 1 (user's "never drop a queue" reframing) |
| Adversarial findings post-implementation | 1 (52b non-canonical wire shape) |

## 8. What's Next

### 8.1. Immediate (unblocked by this arc)
- **Phase 54 — multi-connection state**: A bridge today owns one `BridgeState` for one peer. Three-vat handoff requires routing between TWO peer connections. Need a connection registry keyed by locator. Design questions: shared vat? cross-connection refr scoping?
- **Phase 55 — outbound dial via netlayer-tcp**: `tcp-testing.prologos` has `dial`, but the bridge doesn't use it. Recipient must dial the exporter on receipt of `desc:import-object`.
- **Phase 56 — `desc:import-object` resolution**: when recipient gets a `desc:import-object N`, look up the gift's locator, dial the exporter, send `op:withdraw-gift`, await reply, register the resulting refr.

### 8.2. Session-types follow-ups (Phase 53.b–53.f)
- **53.b** — wire `CapTPSession` as runtime contract for `captp-incoming-with-state`. Replace ad-hoc match dispatch with a session-typed channel.
- **53.c** — session-typed Question/Answer + PipelinedQuestion runtime.
- **53.e** — cross-impl session-type verification (open question whether `@endo/ocapn` has any formal session-type spec to cross-check against).
- **53.f (deferred)** — replace `BridgeState` struct with cells on the propagator network.

### 8.3. Larger
- **Phase 57 — three-process interop test**: Three real processes (mix of Racket and Node) exchanging the full handoff message dance. The integration test.
- **Phase 58 — gift-handoff with signed HandoffReceive envelopes**: matches `@endo/ocapn`'s production handoff with crypto. Out of current scope but needed for full canonical compatibility.
- **PR creation**: this branch has 26+ commits and is ready for review.

## 9. Key Files

| File | Role | LOC delta |
|---|---|---|
| `racket/prologos/lib/prologos/ocapn/captp-bridge.prologos` | Bridge state machine, pump-outbound, gift dispatch | +1200 |
| `racket/prologos/lib/prologos/ocapn/message.prologos` | `CapTPOp` ADT + predicates + selectors | +20 |
| `racket/prologos/lib/prologos/ocapn/captp-wire.prologos` | Encoder + decoder | +50 |
| `racket/prologos/lib/prologos/ocapn/protocols.prologos` | Phase 53 session types | +200 (new file) |
| `racket/prologos/lib/prologos/ocapn/bridge-interop-helpers.prologos` | Test fixture helpers + gift-bytes builders | +80 |
| `racket/prologos/tests/test-ocapn-bridge.rkt` | Bridge unit + dispatch tests | +700 |
| `racket/prologos/tests/test-ocapn-protocols.rkt` | Session-types tests | +280 (new file) |
| `racket/prologos/tests/test-ocapn-bootstrap-gift-interop.rkt` | Phase 52b cross-impl gate | +180 (new file) |
| `racket/prologos/tests/test-ocapn-break-plain-interop.rkt` | Phase 49 cross-impl gate | +220 (new file) |
| `tools/interop/peer-bootstrap-gift.mjs` | Node peer for Phase 52b | +180 (new file) |
| `tools/interop/peer-break-forwarding.mjs` | Node peer for Phase 45 | +210 (new file) |
| `tools/interop/peer-plain-value-error.mjs` | Node peer for Phase 46 | +180 (new file) |
| `docs/tracking/2026-04-27_GOBLIN_PITFALLS.md` | New pitfalls #39–#42 | +250 |
| `docs/tracking/MASTER_ROADMAP.org` | Status updates | +45 |

## 10. Lessons Distilled

| Lesson (§6) | Distilled to | Status |
|---|---|---|
| §6.1 Never-drop-a-queue invariant | This PIR; possibly DEVELOPMENT_LESSONS.org § "Protocol Invariants" | **Pending** distillation to cross-track docs |
| §6.2 Cross-impl gates mandatory before designing wire surface | Existing workflow.md rule confirmed (no doc change needed); this PIR's §6 records the cost of violation | Done (rule was already codified; this is a confirmation data point) |
| §6.3 Constructor-name shadowing | Goblin pitfalls #42 + avoid-list of common ctor names | Done |
| §6.4 Cross-module session payloads work cleanly | This PIR; could go into `prologos-syntax.md` if it recurs | Watch for recurrence |
| §6.5 `:throws` wraps every step, not just top | This PIR; could go into existing session-type docs | Watch for recurrence |
| §6.6 Multi-line continuations are a recurring footgun | Already in goblin-pitfalls #21, #36, #38 + `prologos-syntax.md` § "Application style" | Done |
| §6.7 Goblin-pitfalls vs PIR audience boundary | This PIR; explicitly codified by removing #43 from goblin doc | Done (by removal) |
| §6.8 Belt-and-suspenders / non-canonical surface is a red-flag | Existing workflow.md rule confirmed (no doc change needed); this PIR's §6 records the cost of violation | Done |

## 11. Longitudinal survey of 10 most recent PIRs

| PIR | Date | Track | Wrong assumptions | Bugs fixed | Codification |
|---|---|---|---|---|---|
| **This PIR** | 2026-05-18 | OCapN 37–53.d | "Wire ops are independent design choice" (52b) | 7 (4 lang, 3 protocol) | 4 pitfalls (#39–#42); 8 lessons in §6 |
| `2026-05-04_OCAPN_INTEROP_PIR.md` | 2026-05-04 | OCapN 0–21 | Several about Prologos limitations; deferred Phases 22–23 | Many | Pitfalls #1–35 baseline |
| `2026-05-04_LOOSE_BVAR_RANGE_PIR.md` | 2026-05-04 | Performance | Fib regression cause was looseBVarRange not pattern compiler | 1 (perf) | Pattern compiler test |
| (Earlier PIRs not surveyed — only 3 recent PIRs available; per methodology should reach 10 but the repo only has 3 in the recent window — sample size limits longitudinal analysis here) | | | | | |

The recurring patterns across the OCapN PIRs (this + 2026-05-04):
- WS-mode reader continuation footguns (every track hits at least one)
- Multi-arg constructor shadowing or arity bugs (4+ pitfalls across the two PIRs)
- Cross-impl validation pays for itself the FIRST time it catches a non-canonical surface
- The "ship state-level scaffolding first, wire dispatch second" pattern (used twice — Phase 8 table registry; Phase 52 gift table)

## 12. What's Required Before This Branch Merges

1. Resolve the pending Phase 53.b–53.f session-types decision (keep deferred? schedule?)
2. Confirm the multi-connection state design (Phase 54) before starting code — it has open design questions
3. Drop the CI workflow's strict timeout for batch-worker contention if it bites again (currently 120s/file; bridge has occasionally timed out)
4. Final test-suite green check + visual review of the 26-commit diff
