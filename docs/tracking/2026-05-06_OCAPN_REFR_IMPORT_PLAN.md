# OCapN refr-import — design plan

**Date**: 2026-05-06
**Track**: OCapN Phase 34 (post-GC Phases 31-33)
**Status**: PLAN (no code yet)

## TL;DR

Currently when peer sends a `desc:export N` or `desc:answer N` in
args of an `op:deliver`, our decoder treats it as opaque
`syrup-tagged` data. The bridge has no concept of "we just
imported peer's refr." This plan adds:

1. **Refr ADT** — runtime value distinguishing the four cases
   (local/remote × export/answer)
2. **SyrupValue extension OR replacement of `syrup-refr`/`syrup-promise`**
   — wire encoding round-trip
3. **Imports-refcount table** in BridgeState — auto-increment on decode
4. **Refr-aware encode** — outbound args containing Refr serialize back
   to `desc:export N` etc.
5. **Decoder hook** — recognize `desc:export N` / `desc:answer N` in
   nested positions and inflate to typed Refr

The work unblocks:
- True bidirectional capability passing (peer hands us a refr, we
  invoke it via `connection-ask`, peer hands the refr to a third
  party, etc. — three-vat scenarios)
- Full GC: `imports-refcount` decrement → automatic `op:gc-export`
- Capability-typed Prologos surface (the `OCapNRefr → NearRefr`
  hierarchy in `refr.prologos` becomes runtime-checkable, not just
  type-system-only)

## Scope estimate

Roughly **1-2 days** of focused work. Bigger than Phases 31-33
combined because it touches:
- Codec (encode + decode)
- BridgeState (1-2 new fields)
- Test fixtures (need a new actor that emits a refr in its reply)
- Possibly cross-impl drift gate (are we still byte-equal with
  @endo/ocapn for refrs in args?)

## Background — the wire format

CapTP's "desc" descriptors all live in the same syrup-tagged
namespace:

```
<desc:export N>          ;; sender's POV: "my export N"; reader's POV: "remote refr to export-N"
<desc:import-object N>   ;; sender's POV: "peer's export N that I imported"
<desc:answer N>          ;; sender's POV: "my outbound-question N"; reader's POV: "remote promise"
<desc:sturdy ...>        ;; durable refr (for restoration after disconnect)
```

The from-whose-POV ambiguity means the SAME bytes mean different
things to sender and receiver. The receiver's bridge needs to flip
the perspective on decode.

For Phase 0 we'll handle the two common cases:

- **Inbound `desc:export N`**: peer is referring to their own export
  N. For us this is a **remote-export refr**. Track in
  `imports-refcount`.
- **Inbound `desc:answer N`**: peer is referring to their own
  outbound question N. For us this is a **remote-answer refr**
  (we hold a promise to peer's eventual answer). Already partially
  modeled — peer's reply to our question is `op:deliver
  <desc:answer OUR-QPOS>`. The new case: peer puts a desc:answer
  in args (passing a promise around).

Outbound: when WE put a refr in args, we encode it as `desc:export
N` (one of OUR exports — for peer, this becomes a remote import)
or `desc:answer N` (one of OUR outbound questions — for peer, this
becomes a remote promise).

## Design — Part 1: Refr ADT

Two options. Pick based on issue #60 risk.

### Option A: 4-constructor sum type (most natural)

```
data Refr
  refr-local-export   : Nat -> Refr
  refr-remote-export  : Nat -> Refr
  refr-local-answer   : Nat -> Refr
  refr-remote-answer  : Nat -> Refr
```

Reads naturally; one constructor per case. Pattern-matching on
Refr discriminates cleanly.

**Risk**: pitfall #32 / issue #60 — multi-constructor types break
cross-module inference for callers using bound vars. Mitigated by:
a) defining all Refr-using helpers in `captp-bridge.prologos`
   (in-module avoids the cross-module trigger);
b) explicit `:refer [Refr refr-local-export ...]` imports in
   downstream modules (the workaround used in Phase 25.4).

### Option B: 1-constructor with kind tag

```
data Refr
  refr : Nat -> Nat -> Refr  ;; (kind, id) where kind ∈ {0,1,2,3}

;; Smart constructors
spec refr-local-export Nat -> Refr
defn refr-local-export [n] [refr zero n]

spec refr-remote-export Nat -> Refr
defn refr-remote-export [n] [refr (suc zero) n]

;; ... etc for local-answer (suc (suc zero)), remote-answer (suc (suc (suc zero)))

;; Predicates
spec refr-local-export? Refr -> Bool
defn refr-local-export?
  | refr k _ -> nat-eq? k zero
```

Single-constructor → no pitfall #60. Slightly less ergonomic
(can't pattern-match in `match` — must use predicate cascade) but
safe across modules.

**Recommendation**: Option B for safety. The "less ergonomic"
downside is small for runtime values that mostly flow through
bridge functions; user code rarely pattern-matches on Refr kinds.

## Design — Part 2: SyrupValue integration

The wire decoder produces `syrup-tagged "desc:export" (syrup-nat
N)` in any nested position currently. To inflate this into Refr:

### Option A: Extend SyrupValue

Add a new arm:
```
data SyrupValue
  ;; ... existing arms ...
  syrup-refr-typed : Refr     ;; NEW
```

Decoder, when scanning args, replaces any nested `syrup-tagged
"desc:*"` with `syrup-refr-typed (refr-remote-* N)` if the tag is
recognized. Encoder sees `syrup-refr-typed r` and emits `desc:*`
based on `r`'s kind.

**Risk**: SyrupValue already has many constructors. Adding one more
risks pitfall #60 in callers that pattern-match on SyrupValue
(there are many).

### Option B: Reuse existing `syrup-refr` and `syrup-promise`

These already exist (`syrup-refr : Nat`, `syrup-promise : Nat`)
but are CURRENTLY UNUSED in the decoder. Reinterpret them as:
- `syrup-refr N` = "remote export" (semantics from receiver's POV)
- `syrup-promise N` = "remote answer"

Decoder: when seeing `syrup-tagged "desc:export" (syrup-nat N)`,
output `syrup-refr N`. When seeing `syrup-tagged "desc:answer"
(syrup-nat N)`, output `syrup-promise N`.

Encoder: see `syrup-refr N`, emit `<desc:export N>`. See
`syrup-promise N`, emit `<desc:answer N>`.

**Risk**: changes semantics of existing arms. Audit needed:
who currently constructs `syrup-refr N` or `syrup-promise N`?
If nobody uses them, we can repurpose freely.

**Decision tradeoff**: Option B is cleaner (reuses existing arms)
IF nobody currently emits them. A grep reveals usage patterns.

### Option C: Decode-time sidetable

Don't change SyrupValue. Decoder maintains a separate "refr-map"
during decoding: `[List (Pair SyrupPath Refr)]`. The bridge can
inspect this to know which positions in args contain refrs.

**Pros**: zero SyrupValue change.
**Cons**: every consumer of args needs to consult two structures.
Not ergonomic.

**Recommendation**: Option B IF usage audit shows `syrup-refr`/
`syrup-promise` are unused. Otherwise Option A.

## Design — Part 3: Imports-refcount table

Add to BridgeState (going from 6 to 7 fields):

```
imports-refcount : List QEntry
```

Where `q-entry export-id refcount` represents "we currently hold
`refcount` references to peer's export `export-id`."

Updates:

- **On decode** of a remote-export refr in args: `bs-incr-import
  N st` increments by 1.
- **On `release-import N k cs`**: `bs-decr-import N k st` decrements
  by k. Returns `op:gc-export N k` bytes via `release-import` (Phase
  32). If refcount reaches 0, the entry can be removed entirely.

Add helpers in `captp-bridge.prologos`:

```
spec bs-imports-refcount BridgeState -> List QEntry
spec bs-lookup-import-ref Nat BridgeState -> Option Nat
spec bs-incr-import BridgeState Nat -> BridgeState   ;; +1
spec bs-decr-import BridgeState Nat Nat -> BridgeState  ;; by k; never below 0
```

The increment-by-1 form is what auto-fires from the decoder.
The decrement form is called from `release-import`.

## Design — Part 4: Decoder hook

Currently `dispatch-deliver-args` extracts the target and a few
top-level fields, but doesn't deeply traverse args for refrs. Add
a deep-walk pass:

```
spec extract-refrs-from-args SyrupValue -> List Refr
defn extract-refrs-from-args
  | syrup-tagged "desc:export" (syrup-nat N) -> [cons (refr-remote-export N) nil]
  | syrup-tagged "desc:answer" (syrup-nat N) -> [cons (refr-remote-answer N) nil]
  | syrup-list xs -> [concat-map extract-refrs-from-args xs]
  | _ -> nil
```

The list of imported refrs is then used to bulk-increment
imports-refcount in one pass:

```
spec bs-incr-imports List Refr BridgeState -> BridgeState
defn bs-incr-imports
  | nil st -> st
  | [cons r rest] st -> bs-incr-imports rest [bs-incr-import-by-refr r st]
```

Wired into `captp-incoming-with-state`'s `op-deliver` arm:

```
| [op-deliver tgt args ap _rm] v st ->
    let imported := [extract-refrs-from-args args]
      let st-with-incs := [bs-incr-imports imported st]
        dispatch-deliver tgt args ap v st-with-incs
```

(Identical pattern for `op-deliver-only`.)

## Design — Part 5: Encoder updates

Outbound: when our actor's reply contains a Refr value,
serialize it back to `desc:export N` (for our exports) or
`desc:answer N` (for our outbound-questions).

If we use Option B for SyrupValue (repurpose existing arms), the
encoder change is small: `wire::encode` already emits a syrup-
tagged form for `syrup-refr N`. Just change the tag from `"refr"`
(or whatever current) to `"desc:export"`.

Audit: what does `syrup-refr` currently encode to in
`syrup-wire.prologos`?

## Design — Part 6: Tests

### Unit tests
- Refr constructors + predicates
- bs-incr-import / bs-decr-import behavior at refcount=0
- Decoder extracts a Refr from `op:deliver target=... args=<desc:export 5>`
- Encoder round-trips Refr through args

### Interop tests
- New peer that PUTS a refr in its question's args: e.g., Node
  sends `op:deliver tgt=desc:export 0 args=<list "ping" <desc:export 7>>`.
  The "<desc:export 7>" represents Node's export 7 — a third-party
  reference Node is sharing with Racket.
- Racket bridge:
  - Decodes the args, recognizes `<desc:export 7>` as a refr
  - Increments `imports-refcount[7] = 1`
  - Routes the args (with inflated Refr) to the echo actor
- Racket then calls `release-import 7 1 cs` to release
- Racket sends `<op:gc-export 7 1>` to Node
- Node verifies it received the GC message

This is a 4-frame round-trip. Probably ~150 lines of new test
code + ~50 lines of new peer JS.

## Open questions

1. **Identity semantics for Refr.** Is `refr-remote-export 5` ==
   `refr-remote-export 5` (eq?-comparable)? In Racket terms: should
   the same N produce the same Racket struct instance?
   
   Probably yes for value-level semantics, but the bridge state
   needs to dedupe on (kind, id) regardless. The increment-on-decode
   should NOT double-count duplicate refrs in the same args list
   (CapTP semantics: each WIRE occurrence increments, not each
   distinct id).

2. **`desc:answer` as a refr in args.** Less common than
   `desc:export` but legal. Treat symmetrically:
   `imports-refcount` should track answers too, OR have a separate
   `imported-promises-refcount`. Probably one combined table
   (kind+id keys).

3. **`desc:import-object` and `desc:import-promise`.** These
   originate from the THIRD party in three-vat scenarios — peer is
   handing us back a refr they got from a different vat. Phase 0 of
   refr-import skips these; full three-vat support is its own track.

4. **Sturdy refrs.** Cross-session capability: encode as `<desc:sturdy
   locator-bytes>`. Phase 0 skips (transient sessions only).

5. **Pretty-printing.** For test diagnostics, refr values should
   pretty-print clearly. Add `Show` impl or similar.

6. **Refr equality across messages.** If peer sends desc:export 5
   in op:deliver #1 and desc:export 5 in op:deliver #2 (sequential),
   that's two SEPARATE wire occurrences → refcount = 2. The bridge
   currently has no notion of "which message" — increments are
   per-decode. Need to verify CapTP semantics here.

## Phasing

| Phase | What | Estimate |
|---|---|---|
| 34a | Refr ADT (Option B: kind+id) + predicates + smart constructors | 2 hours |
| 34b | Decoder hook: extract-refrs-from-args + bridge wiring | 3 hours |
| 34c | imports-refcount field in BridgeState + accessors/updaters | 1 hour |
| 34d | Encoder updates (if Option B for SyrupValue) | 2 hours |
| 34e | Wire `release-import` to actually decrement (currently constant k) | 1 hour |
| 34f | Interop test (new peer + new test file) | 2-3 hours |

Total: roughly 1.5 days of work.

Phase 34a and 34c are independent — could parallelize.
Phase 34b depends on 34a.
Phase 34d depends on 34a (and on the SyrupValue audit).

## Risk summary

- **Issue #60 / pitfall #32**: Refr ADT avoided by Option B (single
  constructor + Nat tag). Imports-refcount field is existing
  pattern (see PendingOut, OutboundQuestions); no new sum types.
- **Issue #61 / pitfall #33**: Re-exports across `core.prologos →
  captp-bridge → user code` need explicit `:refer [Refr ...]`
  workarounds.
- **Pitfall #18 (deep let-chain)**: extract-refrs-from-args is a
  recursive walk over SyrupValue. Mitigation: factor into helpers
  per-arm (already standard for SyrupValue match in this codebase).
- **SyrupValue audit risk**: if Option B is taken (reuse syrup-refr
  / syrup-promise) and these arms turn out to be in use elsewhere,
  back-out cost is low (revert to Option A: new arm).

## When to do this

Refr-import is unblocked NOW (Phases 31-33 complete). Reasonable
to schedule when:
- We have a use case that wants to pass refrs (e.g., "Node hands
  Racket a callback refr; Racket invokes it via captp-ask")
- We want to close the GC loop fully (currently `release-import`
  takes the count from the caller; with refr-import + automatic
  refcount, the count is internally tracked)
- We start a three-vat / capability-passing experiment

If none of those are queued, refr-import can wait. The current
state has a usable CapTP peer with manual GC; adding refr-import
is "filling out the model."

## Cross-references

- GC plan: `docs/tracking/2026-05-06_OCAPN_GC_PLAN.md`
- Pitfall #32 / issue #60 (multi-constructor inference)
- Pitfall #33 / issue #61 (refer-all type identity)
- Existing typing-side capability hierarchy: `lib/prologos/ocapn/refr.prologos`
- SyrupValue definition: `lib/prologos/ocapn/syrup.prologos`
- Wire codec: `lib/prologos/ocapn/captp-wire.prologos`
- Bridge dispatch: `lib/prologos/ocapn/captp-bridge.prologos`
