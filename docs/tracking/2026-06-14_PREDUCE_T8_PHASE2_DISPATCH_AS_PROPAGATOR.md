# PReduce Track 8 — Phase 2: Rule application as propagator firing

**Created**: 2026-06-14
**Status**: ✅ IMPLEMENTED (arithmetic path) — `656a294` core + `edeff08` 2T +
`ac65fad` cell-count test bumps. Suite 8674 all-pass; acceptance file 0 errors.
The realization is exactly the congruence template (S0 emitter → request cell →
topology stratum). Scope narrowed to the arithmetic/dispatch path per the
grounding finding below; the recursion path (β/δ/ι) is Phase 4. Owner chose
"Pursue the goal (P2→P4)" 2026-06-14.

**Implementation note (vs §7 steps)**: the dispatch request is emitted by an S0
emitter installed in `preduce-ingest-int` (the arithmetic caller), NOT from
`eclass-intern`'s new-class branch (§7 step 2b). Reason: `eclass-intern` is a
generic primitive used by every path (incl. β/δ/ι and apply-rule's RHS interns);
emitting from there would request dispatch on every interned class globally,
coupling the primitive to the rule system and risking unintended saturation.
Caller-emission keeps Phase 2 strictly scoped to arithmetic. A direct
request-write would not work: `run-to-quiescence-inner`/`-drain` (and the BSP
Tier-1 fast path) only run strata when the worklist is non-empty — so the
request must be emitted by a PROPAGATOR FIRE (the emitter), which creates the
worklist activity, exactly as the congruence watcher does. The emitter WATCHES
the redex class (non-empty inputs) so it is not Tier-1-fast-path eligible (Tier-1
skips strata).

## ⚠ GROUNDING FINDING (2026-06-14, before cutting core code) — scope narrows

Reading `preduce-ingest-int` vs `preduce-ingest-delta` revealed the substrate has
TWO unlike reduction paths:

- **int-fold path** (`preduce-ingest-int`, reduction.rkt:1330): `dispatch-rules`
  → `apply-rule` → `instantiate-template` compute + `eclass-intern` RHS +
  `eclass-union`. The union IS a propagator; only DISPATCH (match) is imperative.
  Phase 2 ("dispatch as propagator firing") applies cleanly HERE.
- **β/δ/ι path** (`preduce-ingest-delta`, reduction.rkt:1350): interns the redex,
  consults memo/store, on miss runs `(compute)` (the native step) and writes the
  result as the class `:best` via a **direct `net-cell-write`** (reduction.rkt:
  1402). NO rule, NO union, NO propagator — it is compute-and-cache.

**Consequence**: "rule application IS propagator firing" applies cleanly ONLY to
the arithmetic/dispatch path. The recursion path (β/δ/ι — the interesting part
for fib) has no "rule application" to convert into firing; it is a memoized
native compute. Making IT propagator-native is the deeper **Phase 4** (turn the
compute-and-cache into rule-based propagator firing) — a substrate redesign, the
PReduce thesis endgame, genuinely research-grade (the project itself deferred it
and routed the perf case to SH/Zig).

Two further frictions even for the narrow (arithmetic) Phase 2: `apply-rule` runs
its OWN `run-to-quiescence` (so wrapping dispatch in a propagator fire risks
nested/re-entrant quiescence), and reactive dispatch means installing the union
propagator DURING a fire (topology-change-mid-quiescence — doable via the
topology stratum, as congruence does, but real risk).

**Decision deferred to owner (charter §8: design didn't lock as assumed —
surface).** See the checkpoint in the session.

---

## (original design below — realization template still valid for the arithmetic path)

**Plan**: `2026-06-14_PREDUCE_DEFAULT_AND_ONNETWORK_COMPUTE_PLAN.md` (Phase 2)
**Roadmap basis**: PReduce Master thesis — *"rule application IS propagator
firing"*; everything-on-network mantra. Owner (2026-06-14): substrate change is
acceptable **as long as it's on the PReduce / everything-on-network roadmap**.

## 1. The gap (grounded at HEAD)

After Phase 1, reduction is on-network as an e-graph, BUT the rewrite control
flow is still imperative: `preduce-ingest-int`/`-delta` (reduction.rkt) interns
the redex and then **calls `dispatch-rules` synchronously** (`reduction.rkt:1334`)
to match a rule's LHS and instantiate its RHS. `union` (`eclass-union`) and
`congruence` (`process-congruence-requests`) are ALREADY propagators / stratum
handlers; only **dispatch** is an imperative function call.

So "rule application IS propagator firing" = make dispatch reactive: the rewrite
fires from the network (during quiescence), not from an imperative call.

## 2. Scoping correction (owner-relevant)

The plan's **Phase 3 ("compute as propagators": a standalone `int+` propagator
reading operand cells, writing the sum) is OFF-roadmap** and is folded into
Phase 2 / dropped. Rationale: the PReduce e-graph **evaluates primitives
functionally inside a rule** (`instantiate-template`'s `(apply op args)`); that
is the e-graph design, not an incomplete version of it. "Everything-on-network"
is satisfied when **rule application is propagator/stratum firing** — the `+`
runs *inside* the rule-dispatch fire, which reads e-class cells and writes the
result cell (that is exactly what a propagator fire does). A separate
compute-propagator would be the *direct-compute-propagator* substrate we
explicitly chose NOT to build (it gives up the e-graph's structural sharing).
On-roadmap order is therefore **Phase 2 (dispatch firing) → Phase 4 (recursion
driver on-network)**.

## 3. Realization — mirror the congruence engine

Congruence (the template, `eclass-graph.rkt`): watcher propagators on e-class
`:canonical` components write `congruence-request-cell-id`; `register-stratum-
handler!` runs `process-congruence-requests` between rounds. Dispatch mirrors it:

- **`dispatch-request-cell-id`** (reserved well-known cell; hash-union merge):
  `cid → #t` for each newly-interned e-class that should be checked against the
  rule registry.
- **Request emission**: `eclass-intern`, on creating a NEW class (the `[else]`
  branch), writes `(hash cid #t)` to the dispatch-request cell — instead of the
  caller imperatively calling `dispatch-rules`.
- **`process-dispatch-requests` stratum handler** `(net × pending) → net`: for
  each requested `cid`, run the existing `dispatch-rules` (LHS-match +
  `apply-rule` → `instantiate-template` + `eclass-intern` RHS + `eclass-union`).
  Registered via `register-stratum-handler! dispatch-request-cell-id …`. The
  handler runs DURING the `run-to-quiescence` the caller already drives.
- **Caller change**: `preduce-ingest-int`/`-delta` stop calling `dispatch-rules`
  directly; they intern (which now emits the request) and `run-to-quiescence`
  (which fires the dispatch stratum → applies rules), then read `:best`. The
  read-after-quiescence contract is unchanged; only WHO triggers dispatch moves
  from imperative-call to stratum-firing.

## 4. NTT model (sketch + correspondence)

```
cell dispatch-requests : { eclass-id ↦ unit }      -- hash-union merge, bot {}
  reads:  (eclass-intern writes here on new-class)
  writes: (process-dispatch-requests clears per round via #:reset)

stratum dispatch : (net, pending:{eclass-id}) -> net
  for cid in pending:
    rules = rules-for-head(registry, head(best(cid)))
    for r in rules: apply-rule(net, r, cid)   -- RHS instantiate + intern + union
  -- runs between S0 rounds, like congruence; non-monotone (adds nodes)
```

| NTT construct | Racket |
|---|---|
| `dispatch-requests` cell | `dispatch-request-cell-id` (hash-union; `propagator.rkt` reserved id) |
| request emission | `eclass-intern` new-class branch → `net-cell-write … (hash cid #t)` |
| `dispatch` stratum | `process-dispatch-requests` + `register-stratum-handler!` |
| `apply-rule` | unchanged (`rule-dispatch.rkt`) |

## 5. Network Reality Check (the 3 questions — must hold post-impl)

1. **`net-add-propagator` / stratum added?** YES — `register-stratum-handler!
   dispatch-request-cell-id process-dispatch-requests` (the dispatch firing).
2. **`net-cell-write` produces the result?** YES — `apply-rule`'s `eclass-union`
   writes the joined `:best`; the dispatch is *triggered* by the request-cell
   write, not an imperative call.
3. **Trace cell→stratum→cell?** intern writes request-cell → stratum handler
   reads pending → applies rules → writes result e-class cell → caller reads
   `:best`. YES.

## 6. Risks & gates

- **Synchrony**: dispatch now runs in the stratum (between rounds) inside the
  caller's `run-to-quiescence`; the caller reads `:best` AFTER quiescence —
  same contract. Risk: a class that needs dispatch but whose request lands after
  the last round → run an extra quiescence pass (the stratum loop already
  re-runs while requests pending, like congruence). VERIFY.
- **Infinite dispatch**: a rule whose RHS re-requests dispatch on the same class
  → the hashcons makes re-intern a hit (no new request); the request cell is
  reset per round. VERIFY no loop (fuel as backstop).
- **Recursion (whnf) still drives** — Phase 4. This phase only moves DISPATCH
  on-network; `whnf` still calls `preduce-ingest`. That's expected; not a
  regression.
- **GATE**: full suite green (8671 baseline); the acceptance file
  (`examples/2026-06-14-onnetwork-reduction.prologos`) exports with dispatch
  propagators/stratum visible; parity (same reduced values).

## 7. Implementation steps (incremental commits)

- **2a**: reserve `dispatch-request-cell-id` + preallocate (hash-union) in
  `make-prop-network`; define `process-dispatch-requests` + register it.
- **2b**: emit dispatch-requests from `eclass-intern` (new-class branch).
- **2c**: switch `preduce-ingest-int`/`-delta` from the imperative
  `dispatch-rules` call to intern-emits-request + quiescence; delete the
  imperative call. Gate: full suite + acceptance parity.
- **2T**: extend `test-preduce-ingest.rkt` — assert a dispatch-request fires the
  rewrite (the rewrite happens via the stratum, not the direct call).

STOP-and-surface if 2a–2c won't lock cleanly (synchrony or loop issues that
need a deeper stratum-ordering design).
