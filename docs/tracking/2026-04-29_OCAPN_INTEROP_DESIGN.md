# OCapN Interop — Phase 1/2/3 Design

**Date:** 2026-04-29
**Author:** Claude (session continuation from goblin port)
**Status:** Design committed; Phase 1 in flight

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
| 4E | Phase-4 commit + green suite | 🔄 | |

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
