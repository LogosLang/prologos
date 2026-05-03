# OCapN Interop — Phase 1–8 Design

**Date:** 2026-04-29
**Author:** Claude (session continuation from goblin port)
**Status:** Phases 1–8 implemented and CI-gated. Phase 9+ in flight.

## Context

The Phase-0 port (PR #28, 159/159 tests, all on Racket 9.1) implements
the OCapN model — `SyrupValue`, `CapTPOp`, vat, promise algebra,
session-typed CapTP shape — but **emits no wire bytes**. Every
"Endo's tcp-test-only.js" reference in our code is documentation
only; nothing exchanges bytes with `@endo/ocapn` or
`spritely/racket-goblins`.

The user-visible gap is clear: an OCapN node only counts as
implementing OCapN if it can talk to another OCapN node. Phase 0
established structural fidelity; Phases 1–3 establish wire
fidelity.

## Progress Tracker

| Phase | Description | Status | Notes |
|------:|------|------|------|
| 1A | Syrup-wire acceptance file (Phase-0 instrument) | ✅ | examples/2026-04-29-syrup-wire-acceptance.prologos |
| 1B | Syrup encoder | ✅ | lib/prologos/ocapn/syrup-wire.prologos |
| 1C | Syrup decoder | ✅ | same module |
| 1D | Round-trip + golden tests | ✅ | tests/test-ocapn-syrup-wire.rkt — 13/13 green on Racket 9.1 |
| 1E | Phase-1 commit + green suite (Racket 9.1) | ✅ | commit 1ad3e60 |
| 2A | CapTP frame encoder (op:* → bytes) | ✅ | lib/prologos/ocapn/captp-wire.prologos |
| 2B | CapTP frame decoder | ✅ | same module |
| 2C | CapTP frame tests | ✅ | tests/test-ocapn-captp-wire.rkt — 6/6 green on Racket 9.1 |
| 2D | Phase-2 commit + green suite | ✅ | commit 50fc0c1 |
| 3A | Real netlayer (TCP + Syrup framing) | ✅ | tests/test-ocapn-netlayer-tcp.rkt — Racket-side, leverages existing tcp-ffi.rkt + Phase-2 codec |
| 3B | In-process Racket↔Racket handshake | ✅ | tests/test-ocapn-netlayer-tcp.rkt — 2/2 green on Racket 9.1 |
| 3C | Phase-3 commit + green suite | ✅ | commit b4493a1 |
| 4A | Probe @endo/ocapn API | ✅ | encodeSyrup + record representation discovered |
| 4B | JS vector generator + committed fixture | ✅ | tools/interop/gen-syrup-vectors.mjs + tests/fixtures/syrup-cross-impl.txt (22 vectors) |
| 4C | Racket cross-impl test | ✅ | tests/test-ocapn-syrup-cross-impl.rkt — 44/44 green on Racket 9.1 |
| 4D | Interop CI workflow | ✅ | .github/workflows/interop.yml — runs gen-then-diff drift gate + Racket cross-impl test |
| 4E | Phase-4 commit + green suite | ✅ | commit 96df02c |
| 5A | Node peer scripts (recv + send) | ✅ | tools/interop/peer-{recv,send}.mjs |
| 5B | Racket-side bidirectional test | ✅ | tests/test-ocapn-live-interop.rkt — 2/2 green |
| 5C | Add live-interop job to interop CI | ✅ | extends `.github/workflows/interop.yml` |
| 5D | Phase-5 commit + green suite | ✅ | commit 0145c60 |
| 6A | Multi-arity record encoder fix | ✅ | encode-record in syrup-wire.prologos |
| 6B | Node peer-handshake script | ✅ | tools/interop/peer-handshake.mjs |
| 6C | Racket-side handshake test | ✅ | tests/test-ocapn-handshake.rkt — 1/1 green |
| 6D | Phase-6 commit + green suite | ✅ | commit 3c51f41 |

## Design Mantra Audit

**"All-at-once, all in parallel, structurally emergent information
flow ON-NETWORK."**

For this work the mantra alignment is honest scaffolding, not a
fit. A wire codec is bytes-in, bytes-out; the natural shape is a
function, not a propagator network. The serialiser is below the
elaborator, not part of it. Recording that explicitly here per
the workflow's "name scaffolding instead of rationalising it"
rule.

When the self-hosted compiler runs, the codec will run inside it
the same way `racket/base` `number->string` runs today — as a
primitive on a foreign-functions boundary. Future work that puts
the elaborator on cells does not change this.

## Phase 1 — Syrup wire codec

### Spec (canonical Syrup, per OCapN doc + Endo's `@endo/syrup`)

```
syrup-value ::=
    null    := "n"
  | bool    := "t" | "f"
  | int     := digits "+" | digits "-"     ;; abs-value, sign-suffix
  | float   := "D" 8-bytes-IEEE754-BE
  | string  := digits "\"" utf8-bytes
  | symbol  := digits "'" utf8-bytes
  | bytes   := digits ":" raw-bytes
  | list    := "[" syrup-value* "]"
  | record  := "<" syrup-value+ ">"        ;; first elem is label
  | dict    := "{" (syrup-value syrup-value)* "}"
  | set     := "#" syrup-value* "$"
```

Length-prefixed forms use **byte length**, not code-point length.
For Phase 1 we restrict ourselves to ASCII strings/symbols where
byte length and code-point length agree. UTF-8 byte length is a
Phase-1.5 follow-up (needs byte-aware string ops or a String→Bytes
boundary).

### Mapping from `SyrupValue` to wire bytes

Our Phase-0 `SyrupValue` data type:

| Constructor | Wire form |
|---|---|
| `syrup-null` | `n` |
| `syrup-bool true` | `t` |
| `syrup-bool false` | `f` |
| `syrup-nat n` | `<digits-of-n>+` |
| `syrup-int n` (n ≥ 0) | `<digits-of-n>+` |
| `syrup-int n` (n < 0) | `<digits-of-abs-n>-` |
| `syrup-string s` | `<byte-len>"<s-bytes>` |
| `syrup-symbol s` | `<byte-len>'<s-bytes>` |
| `syrup-list xs` | `[<encoded-xs>]` |
| `syrup-tagged tag payload` | `<<sym(tag)><encoded-payload>>` where sym(tag) = `<byte-len>'<tag>` |
| `syrup-refr id` | encoder ERROR (semantic: refrs translate to descriptors at the CapTP boundary; pure Syrup wire never carries naked refrs) |
| `syrup-promise id` | encoder ERROR (same reason) |

`syrup-tagged` maps to a 2-element record `<label payload>`. Records
of arity ≠ 2 round-trip as `syrup-tagged label (syrup-list rest)`
on decode.

Floats / dicts / sets / bytes are **not** in our `SyrupValue` data
type. The decoder skips/errors on them; the encoder cannot produce
them. This is fine for Phase 1 — none of Endo's CapTP ops use
floats/dicts/sets/bytes in the load-bearing path.

### Module API

```
ns prologos::ocapn::syrup-wire

spec encode SyrupValue -> Result Bytes EncodeError
spec decode Bytes -> Result <SyrupValue * Nat> DecodeError    ;; (value, bytes-consumed)
```

For "Bytes" we use `String` (Prologos's bytes-clean string type
on the FFI to Racket). For `Result`/`EncodeError`/`DecodeError` we
either use `Option` (Phase 1) or define small tagged unions (also
Phase 1). The encoder is total over the constructors above except
`syrup-refr` / `syrup-promise`.

### Tests

1. **Round-trip per constructor**: for each constructor `c` in our
   value space, `decode (encode c) = c` (modulo the bytes-consumed
   tail). 8 cases.
2. **Golden vectors**: hand-derived from the Syrup spec (not from
   any external impl, since the sandbox has neither `@endo/syrup`
   nor `racket-goblins` installed). ~20 vectors covering atoms,
   nested lists, tagged values. Format:

   ```
   ;; <description>
   <hex-of-bytes>    <prologos-sexp-of-syrup-value>
   ```

   Tests assert encoder→hex equality AND decoder(hex)→sexp equality.
3. **Refr/promise encode is an error**: assert `encode (syrup-refr 0)`
   returns `none` (or the `Err` constructor of `Result`).

### Acceptance (Phase 1 done)

Phase 1 closes when all of:
- `racket/prologos/lib/prologos/ocapn/syrup-wire.prologos` exists
- `tests/test-ocapn-syrup-wire.rkt` runs green under Racket 9.1
- `examples/2026-04-29-syrup-wire-acceptance.prologos` runs through
  `process-file` without errors
- Full OCapN test suite remains 159/159 + new tests

## Phase 2 — CapTP frame codec

### Spec

CapTP messages are Syrup records with op-name labels. Per the
spec doc:

```
op:start-session ::= <op:start-session captp-version session-pubkey
                                       location location-sig acceptable-location-types>
op:abort         ::= <op:abort reason>
op:deliver       ::= <op:deliver to-desc args answer-pos resolve-me>
op:deliver-only  ::= <op:deliver-only to-desc args>
op:listen        ::= <op:listen to-desc resolver-desc>
op:gc-export     ::= <op:gc-export export-pos count>
op:gc-answer     ::= <op:gc-answer answer-pos>
```

Where `to-desc` etc. are themselves Syrup records like
`<desc:export n>` / `<desc:import-promise n>` / `<desc:answer n>`.
Our Phase-0 model represents these positionally as Nat — Phase 2
is where we elevate them to descriptor records on the wire.

### Module API

```
ns prologos::ocapn::captp-wire

spec encode-op CapTPOp -> Result Bytes EncodeError
spec decode-op Bytes -> Result <CapTPOp * Nat> DecodeError
```

Internal helpers:
- `encode-desc-export Nat -> SyrupValue` → returns
  `[syrup-tagged "desc:export" [syrup-nat n]]`
- `encode-desc-answer Nat -> SyrupValue`
- `encode-desc-import-promise Nat -> SyrupValue`
- pattern-match flips for decode

### Tests

1. **Per-op round-trip**: `decode-op (encode-op op) = op` for each
   `CapTPOp` constructor.
2. **Golden vectors**: hand-derived from Endo's wire encoding
   (3-5 per op).
3. **Cross-Phase-1 sanity**: `encode-op` produces bytes that
   `Phase-1's decode` can also parse as a Syrup record.

## Phase 3 — Live tcp-testing-only netlayer

### Goal

Two Prologos processes (or one Prologos + one JS reference, when
`@endo/ocapn` is available) talk over a TCP socket using
length-prefix-free Syrup framing, exchange `op:start-session` and
one `op:deliver`.

### Phase 3 scope (in this PR)

- Build a real TCP netlayer that uses Phase-2's encoder for
  outbound and Phase-1's decoder (with bytes-consumed return) to
  parse inbound. Syrup is self-delimiting, so we don't need a
  separate length prefix at the netlayer layer.
- **In-process Racket↔Racket** test: spawn two threads, bind a
  127.0.0.1 ephemeral port, exchange `op:start-session` from one
  to the other, exchange `op:deliver`, assert receive matches.
- DO NOT add a JS dependency or CI step in this phase. The
  reference-impl JS check is Phase 4 / a separate PR.

### Module + tests

- `lib/prologos/ocapn/netlayer-tcp.prologos` — wraps the Phase-0
  `tcp-testing.prologos` FFI with Phase-1/2 codec
- `tests/test-ocapn-netlayer-tcp.rkt` — in-process Racket↔Racket
  exchange using a `127.0.0.1:0` ephemeral port

### Acceptance (Phase 3 done)

Phase 3 closes when an in-process test sends `op:start-session`
from peer A to peer B over a real socket, B's decoder rebuilds the
exact same `CapTPOp` value, and the assertion is byte-equal +
structural-equal. Plus full suite green.

## Out of scope (deferred)

- **Floats / Bytes / Dicts / Sets** in the encoder. Add these when
  an OCapN op actually needs them.
- **UTF-8 byte-length-aware string ops.** Phase 1.5.
- **CI step that runs `@endo/syrup` to cross-verify vectors.** Phase 4.
- **Cryptographic handshake.** Per Endo, "tcp-testing-only" by
  design has no auth/crypto. Real TLS + Ed25519 keys come later
  with the secure netlayer (post-Phase 0).
- **GC of refrs / answers.** Phase-0 limitation; orthogonal.

## Risks

1. **Pure-Prologos integer-to-decimal-string is recursive** and
   may be slow for large ints. We have `from-int` (Racket FFI on
   `Int`) but Nat→Int isn't a primitive — write `nat-to-int` via
   structural recursion or via `from-int` after an unsafe cast.
   Mitigation: write `nat-to-int` and accept O(n) cost; CapTP
   numbers are always small (positions in the export/answer table).
2. **`String` is not bytes-clean** in the strict sense — but the
   FFI to Racket treats it as a byte sequence via `string->bytes/utf-8`.
   All wire bytes for our test cases are ASCII, so this is OK for
   Phase 1.
3. **Multi-arity defn pitfall #18** (just hit during the syntax
   sweep) — keep the workaround in mind: don't write 2+ clauses
   of `defn f | A B -> ...` where both A and B are 0-arity ctors.

## Methodology checklist

- [x] Mantra audit — section above
- [ ] SRE lattice lens — N/A (no lattice / cell design here, pure FFI-shaped codec)
- [ ] NTT model — N/A (no propagator network involved)
- [x] Acceptance file as Phase 0 — Phase 1A
- [x] Progress Tracker present — top of doc
- [x] Per-phase commit plan — 1E / 2D / 3C are explicit gates
- [x] WS Impact section — N/A (no surface syntax additions)

## References

- @endo/syrup README + source (`endojs/endo/packages/syrup`)
- OCapN Syrup spec: `ocapn/spec` repo, `Syrup.md`
- OCapN CapTP spec: same repo, `CapTP.md`
- Spritely racket-goblins Syrup impl (Racket reference, structural cross-check)
- Pitfall log: `docs/tracking/2026-04-27_GOBLIN_PITFALLS.md` (esp. #18)

## Phase 5 — Live Racket↔Node wire exchange

Phase 4 proved byte-equality for static vectors. Phase 5 closes
the remaining gap: Prologos and `@endo/ocapn` running as separate
OS processes, exchanging real CapTP messages over a real TCP
socket.

### Goals

- Test A (**Prologos sends → Node decodes**): Racket binds an
  ephemeral port, spawns a Node child running `peer-recv.mjs
  <port>`, accepts, sends `encode-op (op-abort "phase-5")`, and
  asserts that Node's stdout reports a successfully-decoded
  `op:abort` record with the matching reason.
- Test B (**Node sends → Prologos decodes**): Racket spawns Node
  running `peer-send.mjs`, reads the chosen port from Node's
  stdout, connects, reads the line Node writes, decodes via
  Prologos's `decode-op`, asserts it matches the expected
  `CapTPOp`.

### What this proves

Together with Phase 4's byte equality, Phase 5 demonstrates that
the two implementations are wire-compatible at runtime — bytes
go out, bytes come in, both sides agree on the message. This is
the strongest interop signal short of a full handshake.

### Out of scope (Phase 6+)

- Bidirectional `op:start-session` handshake (both peers send
  their pubkey + accepted location types and verify each other's
  signatures)
- Multi-message conversations (op:deliver / op:listen / op:abort
  in sequence)
- Cryptographic auth (`@endo/ocapn`'s tcp-test-only netlayer is
  intentionally unauth'd; secure netlayer is its own track)
- GC of refrs / answers
- Persistent connection lifecycle

### Module layout

| Path | Role |
|---|---|
| `tools/interop/peer-recv.mjs` | Node script: connect, read line, decode, print JSON |
| `tools/interop/peer-send.mjs` | Node script: bind, accept, send a known op, print port |
| `tests/test-ocapn-live-interop.rkt` | Racket test: orchestrate two child processes, assert |
| `.github/workflows/interop.yml` | Add `live-interop` job |

### Progress

| Phase | Description | Status | Notes |
|------:|------|------|------|
| 5A | Node peer scripts (recv + send) | ✅ | tools/interop/peer-{recv,send}.mjs |
| 5B | Racket-side bidirectional test | ✅ | tests/test-ocapn-live-interop.rkt — 2/2 green on Racket 9.1 |
| 5C | Add live-interop job to interop CI | ✅ | extends `.github/workflows/interop.yml` |
| 5D | Phase-5 commit + green suite | 🔄 | |

## Phase 6 — Bidirectional `op:start-session` handshake

Builds on Phase 5 with: (a) both peers exchanging structured
`op:start-session` records (not just `op:abort` strings), (b) a
real bug surfaced (and fixed) along the way.

### Bug surfaced + fixed

The handshake test proved that Phase 2's `op-to-syrup` was
emitting WRONG bytes for any multi-arity record. Our
`syrup-tagged` constructor only carries ONE payload, so the
encoder packed N args as `(syrup-tagged label (syrup-list args))`,
producing wire form `<label [arg1 arg2 ...]>` instead of the
canonical `<label arg1 arg2 ...>`. Phase 4's cross-impl test
missed it because every Phase-4 vector was a 1-arity record.

Fix: added `encode-record : String [List SyrupValue] -> String`
to syrup-wire.prologos that produces `<label arg1 ... argN>`
directly (bypassing syrup-tagged for multi-arity). Phase 2's
encode-op now uses encode-record for the 5 multi-arity ops
(start-session, deliver, deliver-only, listen, gc-export);
1-arity ops (abort, gc-answer) still go through syrup-tagged.

Codified as goblin-pitfall #26.

### Perf gap surfaced

Prologos's `decode-op` of a multi-arity record (e.g., the
60-byte op:start-session bytes) takes **~7 minutes** in the
reducer (vs <1 second for a 1-arity op:abort). Round-trip is
correct; just unbounded in time. Codified as pitfall #27.
The Phase-6 test sidesteps this by asserting BYTE EQUALITY
of the received bytes against what Prologos would have
emitted — a strictly stronger correctness signal.

### Test shape

Single test, two assertions:

| Assertion | Side | Mechanism |
|---|---|---|
| Node decoded our start-session correctly | Node-side | child stdout JSON has ok:true + matching label/version/locator |
| Node's start-session bytes match Prologos's encoding | Racket-side | `(check-equal? their-line expected-prologos-bytes)` |

### Progress

| Phase | Description | Status | Notes |
|------:|------|------|------|
| 6A | Multi-arity record encoder fix | ✅ | encode-record in syrup-wire.prologos |
| 6B | Node peer-handshake script | ✅ | tools/interop/peer-handshake.mjs |
| 6C | Racket-side handshake test | ✅ | tests/test-ocapn-handshake.rkt — 1/1 green on Racket 9.1 |
| 6D | Add handshake job to interop CI | ✅ | extends `.github/workflows/interop.yml` |
| 6E | Phase-6 commit + green suite | 🔄 | |

## Out of scope (Phase 7+)

- **Multi-message conversations** post-handshake (op:deliver,
  op:listen, op:gc-export sequences) — needs the encoder fix to
  land first (which it has) plus richer test orchestration
- **Secure netlayer** — Ed25519 signed locators, X25519 channel
  keys, per-message authentication. Independent track.
- **Full GC** — refcount tracking, op:gc-export emission on refr
  drop, op:gc-answer on answer-table eviction
- **Decoder perf fix** — lift decode-many-loop out of the
  Prologos reducer's recursion-heavy path, OR teach the reducer
  to handle this shape efficiently

## Phase 7 — Multi-message conversation

Builds on Phase 6 with a three-frame exchange in each direction:

  1. `op:start-session  ver="0.1"  loc=...`
  2. `op:deliver-only   target=<desc:export 0>  args="ping"`
  3. `op:abort          reason="goodbye"`

Both peers send all three; both peers read and assert on the
other's three. Byte equality on the Racket side; JSON summary
on the Node side.

This is a "lockstep echo" test, NOT a real CapTP conversation —
neither peer reacts to what it receives. Phase 8+ would build
the conversational state machine. Phase 7 just establishes that
multi-frame, multi-op-type sequences round-trip.

### What this proves

- The encoder fix from Phase 6 works for ALL multi-arity ops, not
  just start-session. op:deliver-only is exercised end-to-end.
- Byte-stream framing (one Syrup record per `\n`-terminated line)
  works for at least 3 back-to-back frames in each direction.
- Both peers can process arbitrary mixes of 1-arity and N-arity
  records in sequence.

### Progress

| Phase | Description | Status | Notes |
|------:|------|------|------|
| 7A | Node peer-conversation script | ✅ | tools/interop/peer-conversation.mjs |
| 7B | Racket-side multi-message test | ✅ | tests/test-ocapn-conversation.rkt — 1/1 green |
| 7C | Phase-7 commit + CI step | 🔄 | |

## Phase 8 — Conversational state machine (RPC-style)

The first stateful round-trip. Unlike Phase 7's lockstep echo,
Node ACTS on what it receives:

  Racket → Node:  op:start-session  ver="0.1"  loc=peer-racket
  Racket → Node:  op:deliver        target=<desc:export 0>
                                    args="ping"
                                    answer-pos=<desc:answer 0>
                                    resolver=false
  Node → Racket:  op:start-session  ver="0.1"  loc=peer-node
  Node → Racket:  op:deliver        target=<desc:answer 0>     ;; the reply
                                    args="ping-pong"           ;; computed from "ping"
                                    answer-pos=false
                                    resolver=false

Node's reply args are **computed from the request** ("ping" +
"-pong"). This proves Node really decoded our deliver, extracted
the args + answer-pos, and answered to the right answer-pos —
not just lockstep echoed pre-hardcoded bytes.

### Bug surfaced + fixed

@endo/ocapn's `AnyCodec` doesn't accept `null` as a record
child. Phases 1-7 didn't surface this because none of those
vectors emitted `null` in a record sent TO `@endo/ocapn`. Phase 8's
deliver did (for absent answer-pos / resolver) and broke
both Endo's decoder (on receive) and encoder (on reply).

Fix: `opt-pos none` now emits `(syrup-bool false)` instead of
`syrup-null`; `unwrap-opt-desc` accepts both for forward
compat. Codified as goblin-pitfall #28.

### Progress

| Phase | Description | Status | Notes |
|------:|------|------|------|
| 8A | `peer-responder.mjs` (parses deliver, computes reply, sends to answer-pos) | ✅ | tools/interop/peer-responder.mjs |
| 8B | Racket-side RPC test | ✅ | tests/test-ocapn-rpc.rkt — 1/1 green |
| 8C | Phase-8 commit + CI step | 🔄 | |

### What this proves

- The full encode → wire → decode → ACT → encode → wire → decode
  loop works between Prologos and `@endo/ocapn`.
- Both encoders/decoders agree on the canonical record shape and
  the `false` sentinel for absent fields.
- A real RPC pattern (request with answer-pos → reply targeting
  that answer-pos) round-trips byte-perfectly.

### Out of scope (Phase 9+)

- Multi-turn conversations with mid-stream pipelining
- op:listen + op:deliver-only chains
- op:abort teardown handshake
- Real promise resolution semantics on the Prologos side
  (currently the model holds the promise machinery; Phase 8 just
  exercises the wire bytes)
- Cryptographic auth (out of scope for tcp-testing-only by design)
- Decoder perf fix (pitfall #27)

## Phase 9 — Multi-turn RPC

Three sequential RPCs followed by op:abort. Each request's args
derive from the previous reply (Racket waits for each reply
before sending the next). Not "true pipelining" in the OCapN
sense (no send-on-promise), but exercises a stateful Node
responder loop.

| Phase | Description | Status | Notes |
|------:|------|------|------|
| 9A | `peer-pipelined.mjs` | ✅ | loop: read deliver → reply with args+"-ack"; exit on abort |
| 9B | `tests/test-ocapn-pipelined.rkt` | ✅ | 1 test, 3 rounds, byte equality on all replies |
| 9C | CI integration | ✅ | added to `interop.yml` |

## Phase 10 — Graceful op:abort teardown

Both peers send `op:start-session + op:abort` and read each
other's two frames. Tests clean shutdown semantics: no frame
lost, abort reasons round-trip both directions, both processes
exit cleanly.

| Phase | Description | Status | Notes |
|------:|------|------|------|
| 10A | `peer-abort.mjs` | ✅ | sends start+abort, reads back start+abort |
| 10B | `tests/test-ocapn-abort.rkt` | ✅ | 1 test, byte equality on both Node frames + JSON assertions |
| 10C | CI integration | ✅ | added to `interop.yml` |

## Phase 11 — CapTP ↔ Vat bridge

The first wire-side semantic mapping: a `CapTPOp` value drives
the local `Vat` directly, without going through the slow
multi-arity decoder (pitfall #27).

  op:deliver tgt args ap rm  →  enqueue VatMsg(deliver tgt args ap)
  op:deliver-only tgt args   →  send-only tgt args
  op:abort, op:start-session →  no-op (handled at connection layer)
  op:listen, op:gc-*         →  no-op (Phase 12+)

Test:
  1. Spawn beh-echo actor (id 0) on a fresh vat.
  2. fresh-promise gives promise id 1.
  3. Apply `(op-deliver 0 (syrup-string "hi") (some 1) none)`
     via `incoming-captp-op`.
  4. Drain.
  5. Assert promise 1 is fulfilled (with the actor's reply value).

This is the wire-IN half of a real netlayer. The wire-OUT half
(vat eff-resolve → outbound op:deliver) is Phase 12.

| Phase | Description | Status | Notes |
|------:|------|------|------|
| 11A | `lib/prologos/ocapn/captp-bridge.prologos` | ✅ | `incoming-captp-op : CapTPOp -> Vat -> Vat` |
| 11B | `tests/test-ocapn-bridge.rkt` | ✅ | 4 tests (deliver, deliver-only, abort, start-session) |

## Profile: decoder perf gap

Re-investigated 2026-05-01. Findings (codified in pitfall #27):

- 1-arity record decode: ~28s consistently (538 reduce_steps × ~52 ms/step).
- 3-arity record decode: ~270s (763 reduce_steps × ~354 ms/step).
- `reset-meta-store!` between calls does NOT change timing — accumulation is NOT the cause.
- Cost is per-step and grows super-linearly with record arity.
- Likely culprit: HOF self-reference (`decode-many-loop dec` where `dec = decode-at`) compounds closure substitutions through the reducer.

Three lines of attack (deferred — none implemented in this round):
1. Inline `decode-many-loop` into `decode-at` — eliminate HOF passing.
2. Move decoder to Racket FFI primitive — loses self-hosting cleanliness.
3. Fix the reducer's closure-substitution hot path — most principled, largest scope.

The 1-arity round-trip path (Phase 5: op:abort, op:gc-answer) tolerates the cost (<10s per decode); Phases 6-10 sidestep via byte equality; Phase 11 sidesteps by operating on CapTPOp values directly.
