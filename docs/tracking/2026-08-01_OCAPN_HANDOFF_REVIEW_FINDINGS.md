# OCapN handoff migration — adversarial review findings

**Written 2026-08-01 against `b998b18b`.** Four independent adversarial
reviews (security, correctness, architecture, doc-truth) of the third-party
handoff migration (`872e0641`, `4feb7cf2`, `38a4e523`). This document is the
durable record: the reviews themselves were transient, and without it the
findings would exist only in commit messages and code comments, neither of
which is a backlog.

**Status of the branch when this was written:** suite 10120/519, conformance
24/24, CI green.

Convergence is noted per item — a finding reached independently by two or
three reviewers is higher-confidence than one reviewer's, and the ones that
converged are all real.

---

## Fixed in this pass

| # | Finding | Where | Commit |
|---|---|---|---|
| 1 | **Claim-before-validate.** `enliven-claim` removed the parked enliven and the caller validated after, so any deliver to a reserved slot that was not a well-formed `['fulfill REF]` destroyed the handoff permanently and silently. (3 reviewers) | `ocapn-enliven-ffi.rkt` | `0bb8cb3f` |
| 2 | **Answer-namespace confusion.** Both gifter gates used `deliver-target` raw; its own docstring says to use `deliver-to-answer?`. `op:deliver-to-answer 5` ran the whole gifter role from a PEER-allocated namespace starting at 0. (2 reviewers) | `interop-driver.prologos` | `0bb8cb3f` |
| 3 | **Absent vs malformed.** `blob-nat` answered `0` for both, and `0` is the peer's BOOTSTRAP position — an unreadable blob sent a fulfill to the peer's bootstrap object. | `interop-driver.prologos` | `0bb8cb3f` |
| 4 | **Single-slot peer registry**, `hash-set!` last-write-wins, reintroducing the exact bug the server's `open-conns` was made list-valued to fix — and which its comment describes. (2 reviewers) | `ocapn-peer-ffi.rkt` | `0bb8cb3f` |
| 5 | **Single-slot give table.** A second give naming one exporter deleted the first; its gifter's deposit then sat at the exporter forever. | `ocapn-give-ffi.rkt` | `0bb8cb3f` |
| 6 | **`ocapn-peer-forget` had zero callers.** A stale entry made `reach-exporter` take its already-open branch, CLAIM the give, and write to a closed port — give destroyed, no dial. (2 reviewers) | server | `0bb8cb3f` |
| 7 | **Redeem had no identity binding** (CRITICAL). See "the one that matters most" below. | `interop-driver.prologos` | `9cfa0b16` |
| 8 | **Zero tests on ~700 lines** of protocol logic. (2 reviewers) | `tests/test-ocapn-handoff.rkt`, 19 cases | `0bb8cb3f` |
| 9 | **Ten dead functions** in the server, plus `eff-send-on` / `out-req-loc` / `reserve-export`, plus three comments asserting the pre-migration architecture. | server, `behavior`, `vat`, driver | `b998b18b` |
| 10 | **S1 + S2** — a signed receive was a bearer token, and the replay set died with the connection. See "S1 + S2, and a claim in this document that was wrong" below. (2 reviewers) | `captp-core.prologos`, `ocapn-handoff-ffi.rkt` (new), `ocapn-identity-ffi.rkt` | `d9b3bc2f` |

### The one that matters most, and its honest limit

A `desc:handoff-give` names its exporter by **location** — transport plus a
self-chosen designator — and **never by key**. The `my-location` signature in a
handshake proves only "this key asserted this string". So "the peer that opened
this session claims the exporter's designator" is not evidence of anything.

`withdraw-frames` fired on every `op:start-session`, including accepted ones,
and claimed by location alone. Any peer asserting exporter C's designator was
handed our signed `desc:handoff-receive` with the gifter's give inside it —
destroying the honest handoff (the claim removes) and, against an exporter that
does not bind a receive to its connection, yielding a replayable token.

**Fixed** by redeeming only over a connection we DIALLED, to an address taken
from the give itself (`ocapn-peer-mark-dialled`, set before the start-session is
stepped). **Not cryptographic**: a peer that can occupy the address the give
names is still the peer we talk to. Closing that needs the give to carry the
exporter's KEY — an upstream protocol question, recorded under Open #1.

**Attribution:** pre-existing. The deleted Racket code called
`redeem-gift-for-hello!` from the accept paths too. The migration was the moment
to notice and did not.

---

## S1 + S2, and a claim in this document that was wrong

**FIXED in `d9b3bc2f`.** Both, together, because neither is sound alone.

**S1 was:** the exporter never bound a `desc:handoff-receive` to the connection
it arrived on. `handoff-session-of` / `handoff-side-of` were read ONLY to build
the replay-identity string; neither was compared against anything. A signed
receive was a bearer token at our exporter. Upstream treats the session field as
the binding and asserts on it (`third_party_handoffs.py:123,159`).

Now checked against this connection's `bs-peer-key` and our own identity. Two
properties, worth separating because they are not the same one:

- **side == this peer's side-id** — a leaked receive is useless to anybody but
  the peer that made it. This is what makes a leak a denial rather than a theft.
- **session == session-id(ours, theirs)** — the receive was aimed at US. Without
  it, a receive built for exporter X is equally good at exporter Y: both see the
  same receiver side-id, and only the session field tells them apart.

**S2 was:** the used-set lived on `BridgeState`, which dies with the connection.
Withdraw, reconnect, replay: double-spend. Now process-wide
(`ocapn-handoff-ffi.rkt`), and a single test-and-set rather than a check
followed by a mark — each connection has its own thread, so the gap between the
two was the same race in miniature.

### The claim in this document that was wrong

This section previously ended: *"Fixing S1 makes this sound; fixing S2 alone
does not."* The first half is **false**, and it mattered — believed, it would
have justified fixing S1 and closing S2 as consequential.

A session id is derived ONLY from the two side-ids
(`utils/captp.py:126-146`), which are key-derived. A peer that reconnects with
the SAME key gets the SAME session id, so the session check passes on the new
connection and the fresh used-set lets the replay through. What made this look
safe is that upstream generates a fresh keypair per session
(`utils/captp.py:49-50`) — so in the test suite reconnects really do change the
session id. An attacker is under no such obligation. **Both fixes are
independently required.**

### Order is load-bearing

The binding is checked BEFORE the identity is claimed. Claiming early means a
withdrawal refused further down (unauthenticated give) has still burned its
identity. That is safe — but only because a peer that reaches the claim has
already proven the identity is its own, so it can burn nothing but its own.
Reversed, it is a denial-of-service primitive against an honest receiver.

### `ocapn-identity-keypair`'s fallback is not a sentinel

Found while wiring this up, and it cost three conformance tests. The FFI takes a
fallback so that a missing identity is "visible at the call site instead of
turning into a signature made with keypair 0" — but `crypto-ffi` numbers handles
from 0 (`crypto-next-id`) and the server's identity is the FIRST keypair it
generates, so **0 is the real handle in production**. No call site can tell a
hit from a miss. Testing `handle == 0` read our own identity as absent and
refused every legitimate handoff, breaking as "unbound" with the key sitting
right there.

Added `ocapn-identity-present?`. Note the pre-existing consequence, unchanged:
every existing call site passes 0 as the fallback, so if the identity were ever
unset, `interop-driver` would sign with keypair 0 rather than fail — silently
the wrong key, which is exactly what the fallback was documented to prevent.

### Diagnostics

Breaking as one opaque `unbound-handoff` said nothing for twenty minutes;
splitting it four ways temporarily found the cause in about one. Shipped with
two reasons, not four: `no-identity` (OUR fault — nobody called
`ocapn-identity-set!`) versus `unbound-handoff` (the peer's). Conflating those
points an operator at the wrong party. The side-vs-session split is not
reported; it is pure diagnostic and belongs in a debug build.

---

## Open — security

**S3. Gift ids are a predictable sequential counter** (`ocapn-gift-id`,
`"prologos-gift-" ++ n` from 0), and `bs-add-gift` conses newest-first while
`bs-remove-gift` removes EVERY match. A peer can deposit `prologos-gift-3`
before the honest gifter does, shadowing the real entry so
`give-authentic-for-gift?` fails against the genuine give. The FFI header states
the uniqueness hazard; the counter does not meet it. **Mint from
`crypto-random-bytes`, and make `bs-add-gift` refuse a gid that already has a
`gk-gift` entry.**

**S4. Inbound gives are unauthenticated.** The only gate is "the give names our
public key as receiver", and our public key is broadcast in every
`op:start-session`. Any peer that completes a handshake can park a give, and
(post-fix) cause a dial. Parking is now queued rather than overwriting, so the
denial-of-service is bounded, but there is still no provenance check on who
handed us a give. Partly inherent — the receiver genuinely cannot verify a
give's signature — but the asymmetry deserves stating.

**S5. Unbounded, peer-driven growth in five tables** (`peers`, `gives`,
`counts`, `pending`, and now `used` from the S2 fix) plus the server's
`out-by-cid`. Only `peers`/`out-by-cid` are now pruned, on connection close.
The used-set is deliberately not capped: evicting an entry makes a replay
succeed again, which is the one thing that table exists to deny. Bounding it
needs an expiry tied to something meaningful (session lifetime, a handoff-count
watermark), not an LRU. Nothing expires a parked give or a pending
enliven. Separately, `run-dial` blocks in `read-frame` with **no timeout** and
`max-outstanding-dials` is 8, so eight peers pointing at a port that accepts and
never replies hold every dial slot permanently.

---

## Open — correctness

**C1. `reserve-export-id` lost update when `ecid == cid`.** It does
`conn-fetch` → `vat-spawn` → `conn-stash` on a connection; when the enlivened
sturdyref names the SAME connection, `run-step-emit` then stashes state derived
from the PRE-reservation snapshot. The reservation is silently overwritten and
`next-id` rolls back, so a later `fresh-promise` can alias an actor — the exact
hazard `seeded-vat`'s comment describes. (2 reviewers.)

**C2. The FFI headers claim a concurrency safety they do not provide.** Each
says its semaphore makes the table safe "because the server gives each
connection its own thread". True per call; the multi-call sequences (notably
`reserve-export-id`'s fetch/stash pair on ANOTHER connection's state) are safe
only because `validate-sema` serialises every `process-string` process-wide — an
unrelated lock in another file. Correct by accident. Any future parallel
evaluation, or any second embedder of these FFI modules, silently reintroduces
the race.

**C3. Residual TOCTOU on the registry.** `peer-side-id` here and the
`peer-lookup` inside `do-send-on` are two reads; a close between them yields a
receive signed over an empty side-id. A compound read does NOT fix it — the send
resolves the cid again later — so the real fix threads the cid through `OutReq`
and every producer. Named in the code at `withdraw-over-open-session`.

**C4. Two divergent readers of one descriptor.** `nat-of-payload`'s list
fallback accepts `<desc:export [N]>`, which captp-wire's `unwrap-target-tagged`
rejects. Theme C of the gaps doc records collapsing exactly that
`<tag [a b]>` / `<tag a b>` conflation as a FIX; this reintroduces it on the
read side, looser.

**C5. `peer-location-key` is duplicated across the language boundary and
already divergent.** The Prologos version returns `none` when the location does
not parse as `ocapn-peer`; the server's `location-key` falls back to raw
location bytes **and registers under that**. So such a peer is registered under
a key the driver can never construct. The driver's own comment says "the two
must agree" and nothing enforces it.

**C6. `sig-val-bytes` slices unguarded** (`str::slice sig 0 32` / `32 64`).
Safe only because `crypto-sign` always returns 64 bytes; a short return becomes
a raised step and an empty reply rather than a diagnosable error.

**C7. `drive-init!` drains neither the dial nor the send queue.** Currently
unreachable (a start-session produces no out-reqs) — but the redeem now emits
from that very step, so it is one addition away from a frame that queues work
nothing drains until the next inbound frame arrives.

---

## Open — architecture

**A1. The roles are in the driver; the exporter half of the same protocol is in
`captp-core.prologos`.** The justification given ("not an application object,
therefore the driver") proves the first clause and not the second. The third
option — a `captp-handoff.prologos` sibling to captp-core — was never argued
against because it was never considered. Three roles of one protocol still live
in two places; the migration changed the asymmetry from Racket-vs-Prologos to
driver-vs-core rather than removing it.

**A2. The driver is ~1100 lines holding five concerns**: bootstrap seeding,
export allocation, two protocol roles, ~10 wire-frame builders, four FFI
declaration blocks, the effect drain, and the frame entry point. Proposed
decomposition, in the repo's own layer vocabulary:

- `captp-handoff.prologos` — the roles as pure functions over a decoded
  `CapTPOp` plus an explicit context, returning `[List OutReq]`. **Zero FFI
  declarations.**
- `captp-frames.prologos` — the byte builders. Each is a two-line golden test.
- `interop-driver.prologos` — FFI decls, seeding, drain, `step-connection`.
  Target ~250 lines.

A2 is also the mechanism by which the remaining test debt gets paid: the roles
become testable without a server.

**A3. The per-connection vat is the root cause of three of the four global
tables.** Each connection gets its own `seeded-vat` with its own actor table and
`next-id`; real OCapN is one vat, many sessions. Every one of the four tables is
justified by a comment of the form "arrives on one connection and is spent on
another" — under one vat they are vat FIELDS. It has already produced one
recorded id-collision bug ("connection A's park on its promise 8 and connection
B's promise 8 the same key … no attacker needed, just two sessions"), one
recorded feature limit ("one pair per connection"), and the cross-vat reach-in
behind C1. Fixing it *removes* code. **This should be a tracked design task,
not a code comment.**

**A4. Force-by-match has two identical-arm sites.** The file sequences FFI side
effects by matching on a `Bool` so lazy reduction cannot drop them, and its own
comment at `emit-after-stash` notes that identical arms are something "any
arm-collapsing rewrite is entitled to fold away". Two sites have identical arms
anyway: `publish-gifts`, and — load-bearing — `run-step`, which guards
`drain-dials`, i.e. **every outbound dial and send in the system**. A future
match-compilation optimisation deletes the outbound path with a green suite.
Not hypothetical in a repo whose CIU track is actively rewriting match
compilation. Principled fix: extend `OutReq` to a `StateReq` so stash/park/
publish drain like sends do, rather than depending on seven hand-maintained
matches.

**A5. `syrup-text-of` reimplements two helpers the driver already imports** —
`syrup-bytes-of` (bytes + string) and `syrup-symbol-name`.

---

## Open — upstream / main-side

**U1. The LET grouping regression.** A `let` whose value sits on a continuation
line mis-groups: the body line is absorbed into the value's argument list. Two
sites in this tree were fixed by re-indenting (`38a4e523`); the compiler defect
is not. `classify-let-block` (`parse-reader.rkt:2771`) must not accept a head
binding ending in `:=`. **A regression test must run through `imports`**, not
`process-string` — the failure is on the module-load path.

**U2. `build-tree-from-domains` (`parse-reader.rkt:1676`) is ~N^2.17 in file
size** and 71% of self-time loading captp-core: 3921 lines → 61s. Pre-existing;
the merge made it ~1.6× worse. Contained, mechanical fix: a line-start vector
with binary search, a precomputed pos→(line,col) index, and one bucketing pass
instead of lines×lines. Worth ~50× on that file.

**U3. `driver.rkt:3150` formats only `prologos-error-message`**, discarding the
error struct's `name` field AND the srcloc. That single line is why a two-line
source problem presented as a bare "Type mismatch" with no file or line, and why
U1 cost a day.

**U4. The bracket-column skew.** A bracket group's `syntax-column` is the column
of its first inner token, not of the `[`, so any layout rule built on it is
off-by-the-delimiter and visually-aligned lines land in different column
buckets. Latent trap for every future layout rule, not just `let`.

---

## Open — pre-existing OCapN

**P1. `dispatch-answer-target`** (resolution to `<desc:answer M>`) still
forwards without a reply channel. Explicitly not covered by the §1.2 M3 fix.

**P2. One keypair per process**, where upstream mints one per session
(`utils/captp.py:49-50`). Makes `session-id-of` depend only on the peer's
side-id, so a peer reusing a session key across two connections gets the same
session id twice and the replay guard refuses its legitimate second handoff.

Sharper since `d9b3bc2f`: the replay set is now process-wide, so that refusal
survives the reconnect instead of being forgotten with the connection. It is
the correct refusal — reusing all three identity components IS a replay by
definition — but it means a peer that reuses its key AND restarts its handoff
count from 0 is locked out permanently rather than per-connection. Our own
receiver role is unaffected: `ocapn-handoff-count` is monotonic per session id
and process-wide, so our second handoff over a reconnected session draws count
1, not 0.

**P3. No retry when the exporter connection does not exist at enliven time.**
`begin-handoff` returns none; the enliven is dropped. Matches the old Racket
behaviour; a known limit rather than a decision.

**P4. `:requires (CryptoCap)` on FFI bindings** needs a root-capability
introduction form in the language first. Dissolved as an OCapN finding, live as
a language one, with a characterization test.

---

## Open — process / infrastructure

**X1. No microbench at the handoff boundary.** `testing.md` requires one from
Phase 1 for protocol stacks. `gives-in-op` and `gifter-out-reqs` run per op, and
`withdraw-bytes` recomputes `our-side-id` twice (4 SHA rounds + 4 FFI calls per
withdraw).

**X2. `test-error-messages.rkt` is an order-dependent batch flake.** Main's
test; passes 44/44 in isolation; passed in one full-suite run and failed in two
others with no code change. Our branch adds 37 test files, changing batch
composition.

Fourth data point, 2026-08-02 during the S1+S2 work: failed at [80/519] in one
full run, passed in the next with the same tree. Verified isolated at both HEAD
and the working tree, and the failing assertion
(`[fn [x <_>] [reduce x | zero -> 1 | suc y -> 2]]` losing its Nat) has no
connection to anything OCapN touches. Four sightings is past the codification
threshold; this needs diagnosing rather than re-observing.

**X3. The conformance gate is an allow-list of 24 hand-named upstream tests**,
not the upstream suite — §0.1 of the gaps doc classifies this as MEDIUM debt and
it remains the primary evidence for the whole handoff surface.

---

## Suggested order

1. ~~**S1 + S2 together**~~ — DONE, `d9b3bc2f`. They are one bug, and the
   reason given here for pairing them was itself wrong; see the section above.
2. **S3** — small, self-contained, and closes a shadowing attack.
3. **C1** — small, and the aliasing it causes is hard to debug later.
4. **A2** — the decomposition, which unblocks the rest of the test debt.
5. **U1–U3 upstream**, which are main's to take but ours to report.
6. **A3** — the design task. Large, but it deletes more than it adds.
