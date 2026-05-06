# OCapN GC — design plan (manual now, automatic later)

**Date**: 2026-05-06
**Track**: OCapN Phase 31+ (post-Phase 30)
**Status**: PLAN (no code yet)

## TL;DR

CapTP GC is **distributed reference counting**, not host-language
collection. The protocol mechanism (`op:gc-export`, `op:gc-answer`)
is just refcount-decrement messages over the wire. **No weakmaps or
finalization are required for protocol correctness** — the bookkeeping
is explicit refcount adjustments on each side.

What weakmaps/finalization buy you is **automatic detection of "user
dropped this Refr"** — without that hook, the user has to call
`release-*` explicitly. We can build manual first; layer automatic
on later if/when we want it.

Recommended sequencing:

| Phase | What | Mechanism |
|---|---|---|
| 31 | Refcount tables in BridgeState | Plain Nat hashes — no GC primitives |
| 32 | Outbound `release-*` API + wire bytes | Manual call from user code |
| 33 | Inbound `op:gc-*` dispatch | Refcount decrement + answer cleanup |
| 34 (deferred) | Automatic release on host GC | Racket weak hash + finalizer hook |

## Background — what we already have

Phases 11-29 give us:

- **Wire codec** for `op:gc-export` and `op:gc-answer` (encode + decode in `captp-wire.prologos`)
- **Inbound dispatch** records the GC op in `BridgeState`:
  - `bs-gc-exports : List GcExportReq` — peer's op:gc-export requests are appended
  - `bs-gc-answers : List Nat` — peer's op:gc-answer positions are appended
- **No actual refcount semantics** — neither side acts on the stored
  GC requests; they're purely audit-log.

What's missing for real GC:

1. **Refcounted exports table**. We currently don't track "how many references does peer hold to my export N." When peer sends `op:gc-export N k`, we have nowhere to decrement.

2. **Outbound `op:gc-*` emission**. When we're done with an imported refr (or with our outbound-question's answer slot), there's no API to say "release this — emit the GC bytes."

3. **Cleanup on receipt**. Receiving `op:gc-answer N` should remove the corresponding entry from `bs-questions`. Receiving `op:gc-export E k` should decrement our exports refcount and free the export when it reaches 0.

## Design — Phase 31: refcount tables

Extend BridgeState with two new fields:

- `exports-refcount : List ExportEntry` — `(export-pos, refcount)`
  - When we encode a refr as `desc:export N` in outbound args, increment refcount[N]
  - When peer sends `op:gc-export N k`, decrement by k. If 0, free.
- `imports-refcount : List ImportEntry` — `(remote-export-pos, our-refcount)`
  - When we decode a `desc:export M` from inbound args, increment refcount[M]
  - When user calls `release-import M k`, decrement by k. If 0, queue an
    `op:gc-export M k` outbound message.

Both are plain `(Nat → Nat)` association lists — same shape as the
existing `QEntry`. Reuse the `bs-lookup-question-loop` pattern.

The fields go on `BridgeState` (now 6 fields → 8 fields). Single-
constructor, so no issue #60.

Co-migration sites (per `pipeline.md`'s "New Struct Field" rule):
- `bridge-state` data def
- `bridge-state-empty`
- `bridge-state-with-our-session`
- 6 existing accessors (add 2 more wildcards each)
- 7 existing update functions (add 2 more wildcards each)
- 2 new accessors + ~4 new update fns
- All call sites in `captp-bridge.prologos` (~10 `bridge-state ...` constructors)

Mechanical. ~1 hour of work.

## Design — Phase 32: outbound release-* API

Two new user-facing functions in `captp-bridge.prologos`, parallel to
`connection-ask`:

```
;; Mark we're done with a peer's import. Increments outbound queue
;; with op:gc-export bytes if our import refcount reaches 0.
spec release-import Nat ConnectionState -> ConnRelease
defn release-import [remote-export-pos cs]
  ...

;; Mark we're done with our outbound question N. Sends op:gc-answer N
;; so peer can free its answer-table entry.
spec release-answer Nat ConnectionState -> ConnRelease
defn release-answer [our-q-pos cs]
  ...

data ConnRelease
  conn-release : ConnectionState -> List String
  ;; (cs', bytes-to-send-list)
```

Returns a list of bytes (could be empty if no message to emit, e.g.
import refcount > 0 after decrement).

Re-export from `core.prologos` as `captp-release-import` and
`captp-release-answer` for user-facing API.

## Design — Phase 33: inbound op:gc-* dispatch

Replace the current "append to audit log" no-op behavior with real
refcount semantics in `captp-incoming-with-state`:

```
| [op-gc-export pos cnt] v st ->
    bridge-step v [bs-decrement-export pos cnt st]
| [op-gc-answer pos] v st ->
    bridge-step v [bs-remove-question pos st]
```

Where:
- `bs-decrement-export`: subtract from `exports-refcount[pos]`. If
  reaches 0 (or below), free the export entry. Underflow = peer bug;
  log + cap at 0.
- `bs-remove-question`: remove the entry from `bs-questions` matching
  `pos` (peer's q-pos = the answer-pos it sent originally).

The `incoming-captp-op` (stateless) variant stays a no-op — these
require state.

## Design — Phase 34 (deferred): automatic release on host GC

Optional, build-on-top. Two parts:

### 34a: track imports via Racket weak hash

When we decode a `desc:export N` from peer's args into a Prologos-side
`Refr`, also register it in a Racket-side weak hash table:

```
weak-import-table : (weakly-keyed Refr → ImportInfo)
```

Where `ImportInfo` carries the BridgeState reference + remote-export-pos.

### 34b: finalizer hook

When the Racket GC reclaims a `Refr`, the finalizer queues a
`release-import` call against the BridgeState. The bridge's main
loop processes the release queue at the next `connection-step`.

**Why deferred**:
- Requires Racket-side glue (`make-weak-hash`, `register-finalizer`,
  thread-safe queue back to BridgeState).
- The boundary between Prologos-level `Refr` and Racket-level identity
  is currently fuzzy — we'd need to think through whether `Refr`
  values in user code are eq?-comparable, when their identity matters,
  etc.
- Manual release is sufficient for testing the protocol semantics;
  automatic release is an ergonomic / safety improvement on top.

## Why manual first

1. **Protocol correctness is testable manually.** Phase 32+33 give us
   complete wire-level GC semantics. Interop tests can drive
   `release-*` calls explicitly and verify peer reacts correctly.

2. **Refcount invariants are easier to reason about with manual
   release.** Bugs in finalizer-driven release surface as flaky tests
   (depending on GC timing); bugs in manual release fail
   deterministically.

3. **Automatic release has subtle semantics.** Even Goblins/CapTP
   implementations using weak refs + finalizers have to carefully
   handle:
   - Finalizer queue ordering (different from message order)
   - Reentrancy (finalizer firing during connection-step)
   - Connection lifetime (don't fire finalizers after `op:abort`)

   These are real concerns but separate from "does the protocol work."

4. **Layering is clean.** Manual release is the bottom-of-stack API.
   Automatic release is just a hook that calls manual release on a
   different schedule. Building automatic on top of manual is
   straightforward; the reverse is not.

## Outbound timing — when SHOULD we send op:gc-* manually?

For `op:gc-answer N` (we're done with our outbound-question):
- After `lookup-promise` returns `pst-fulfilled` or `pst-broken` AND
  user has consumed the value
- Manually triggered via `release-answer`

For `op:gc-export E k` (we dropped k references to peer's export):
- When user-code drops a `Refr` value of remote origin
- Manually triggered via `release-import`

In both cases, the BRIDGE doesn't unilaterally decide — the USER
signals "I'm done." This matches CapTP semantics: refcount decrement
is application-level, not protocol-level.

## Open questions (for the implementation phase)

1. **Should `release-answer` auto-fire when we observe `pst-fulfilled`?**
   That's a nice ergonomic default but couples GC timing to bridge
   internals. Probably no — keep it manual.

2. **Refcount underflow semantics**. If peer sends `op:gc-export N k`
   where our refcount is `<k`, what's correct? CapTP spec says
   underflow is a peer bug. Options: cap at 0, error, or terminate
   connection. Conservative: cap at 0 + log.

3. **Per-connection vs global refcounts.** Each `BridgeState` is
   per-connection. Refcounts naturally scope to the connection. If
   the same peer connects twice, each connection has its own
   counts. Matches CapTP semantics.

## Estimate

- Phase 31 (refcount tables): ~1 hour (mechanical field additions)
- Phase 32 (outbound release-* API): ~2 hours (new API + unit tests + interop test)
- Phase 33 (inbound dispatch): ~1 hour (replace no-op arms with refcount decrement)
- Phase 34 (deferred — automatic): ~1-2 days when needed

Total for manual GC (Phases 31-33): roughly half a day of focused work.

## Risk summary

- **Issue #60 / #32 (multi-constructor inference)**: Phase 32's
  `ConnRelease` is single-constructor → safe. Phases 31 and 33 don't
  introduce new sum types → safe.
- **Issue #61 / #33 (`:refer-all` chain type identity)**: re-exporting
  `release-*` from core requires the explicit `:refer [ConnRelease]`
  workaround we used in Phase 25.4.
- **Pitfall #18 (deep let-chain inference)**: Phase 31's accessors and
  Phase 32's release functions involve multi-arg helpers. Mitigation:
  define helpers in `captp-bridge.prologos` (in-module avoids the
  cross-module trigger of #60).

No new pitfall risk surface beyond what's already known.
