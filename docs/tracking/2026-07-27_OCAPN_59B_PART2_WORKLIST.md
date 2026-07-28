# OCapN Phase 59b part 2 — the five bootstrap objects (work list)

**Status**: not started. Part 1 (the `fetch` bootstrap method + resolve-me
reply routing) landed in `1e23debd` and is verified to LOAD but not
verified end-to-end, because `fetch` can only return a reference to an
object that exists. These are the objects.

**Correction to an earlier claim.** Prior session notes described part 2 as
"blocked on `BehaviorTag` being a closed `data` enum." That is wrong and
should not be repeated. `BehaviorTag` is our own source
(`lib/prologos/ocapn/behavior.prologos:42`), and its own header documents the
extension recipe: *"Adding a new actor type means: (1) extending
`BehaviorTag`, (2) …"*. Nothing in the language prevents adding
constructors. Part 2 is unbuilt work, not a blocked dependency. The closed
enum is a real design limitation for *user-extensible* actors at runtime —
which is a separate, genuine issue — but it is not what stops these five.

## What upstream requires

From the `ocapn-test-suite` README. Every upstream test calls
`fetch_object` before doing anything else, so all of them are gated on
this. Swiss-nums are ASCII.

| Object | Swiss-num | Behaviour | Have? |
|---|---|---|---|
| Car Factory builder | `JadQ0++RzsD4M+40uLxTWVaVqM10DcBJ` | no args → returns a Car Factory object | no |
| Car Factory | (returned, not fetched) | takes a sequence of `(model, color)` symbol pairs; spawns one Car per item | no |
| Car | (returned, not fetched) | no args → `"Vroom! I'm a <color> <model> car!"` | no |
| Echo GC | `IO58l1laTyhcrgDKbEzFOO32MDd6zE5w` | any number of args → returns them in order; must NOT retain refs; GC after each call | **behaviour DONE** — see correction below; retention/GC unaddressed |
| Greeter | `VMDDd1voKWarCe2GvgLbxbVFysNzRPzx` | takes a refr; sends `"Hello"` to it as `op:deliver`; discards the promise, retains nothing | close — `beh-greeter` exists but *constructs* greetings rather than sending to a refr; the spec here is outbound-send, which is different |
| Promise resolver | `IokCxYmMj04nos2JN1TDoY1bT8dXh6Lr` | no args → returns (promise, resolver); resolver takes `break`\|`fulfill` + value | no |
| Sturdyref enlivener | `gi02I1qghIwPiKGKleCQAOhpy3ZtYRpB` | takes a sturdyref; connects to the peer, gets a live ref, returns it | no — needs OUTBOUND connections |

Note the swiss-num in our own test locator is the Car Factory builder's
(`JadQ0++…`); it is the peer designator AND a fetchable object.

## CORRECTION (2026-07-27, verified by execution — supersedes the table above)

A 14-agent audit at HEAD `20dd7a7b` measured this properly and disproved two
claims made in the first draft of this doc. Both corrections make the work
*differently* shaped, not merely bigger, so they matter before anyone starts.

**1. "beh-echo exists but it is single-arg" was WRONG.** `step-echo`
(`behavior.prologos:104-106`) is `defn step-echo [state args]` with body
`act-step state args nil` — it performs ZERO destructuring of `args` and
returns it verbatim. It is already shape-agnostic: an N-element syrup-list in
the args slot comes back as that same list. This was confirmed by driving the
upstream test's own payload through it, not by reading. **No behaviour change
is needed for Echo.** Do not "fix" step-echo; there is nothing to fix.

**2. The gap is SEVEN mechanisms, not "add an object".** To pass the single
Echo-only upstream test (`test_deliver_with_resolver`):

| # | Mechanism | Exists |
|---|---|---|
| 1 | Place an actor at a chosen export position | no (~20 lines; `actor-table-set` at `vat.prologos:160-162` is public) |
| 2 | Seed a per-connection ConnectionState from the server init path | no (~20 lines; `conn-state` ctor at `captp-core.prologos:1949-1950` is public) |
| 3 | Thread `rm` into the NON-fetch inbound deliver path | no — `rm` is dropped at `dispatch-deliver` (`:1291-1302`) |
| 4 | Allocate a local answer promise when `ap = none` | no — return value is discarded at `step-after-act` (`vat.prologos:346-354`) |
| 5 | Resolver table: local promise-id → peer resolver export position | no |
| 6 | Pump stage emitting notifications for settled promises NOT in `bs-questions` | no — `listener-bytes-for-pid` is only reachable via the inbound question table |
| 7 | Reusable fulfill-wrapping helper (value → `[syrup-list 'fulfill, value]`) | no |
| — | Tag-parameterized op:deliver emitter for reply bytes | **yes** |

Items 3-7 are the real work and are the half the first draft missed entirely:
upstream's Echo test replies via `resolve_me_desc` with
`answer_position=False`, and **the resolve-me reply path does not exist for
non-fetch delivers.** Phase 59b part 1 built it for `fetch` only.

**3. Routing needs no new code.** An earlier claim that "no export-position
allocator or position→actor table exists" OVERSTATES it: the export position
IS the actor-table key, so once an actor is seeded at a position, inbound
delivery to that position already routes.

**Consequence for sequencing.** Items 3-6 are one coherent piece of work — the
generalized resolve-me reply path — and every remaining object needs it, not
just Echo. Build that FIRST, not the objects. Three patches attempted the
object-shaped framing and all three honestly reported zero tests unblocked;
one was refuted outright for a false claim in its own comment.

## Ordering (REVISED per the correction above)

**0. The generalized resolve-me reply path (items 3-6) — BUILD THIS FIRST.**
Not an object. Every remaining object needs it, and no object can pass a test
without it. This supersedes the object-first ordering below, which was written
before the gap was measured.

Then, and only then, the objects:

1. **Echo GC** — the behaviour is DONE (see correction: `step-echo` needs no
   change). What remains is items 1-2 (seed an actor at a chosen position;
   seed the ConnectionState) plus the no-retention/GC audit. Unblocks the
   `op_deliver` echo tests, the largest single group.
2. **Greeter** — needs an outbound `op:deliver` from a behaviour, i.e. the
   `Effect` path, not just a return value. First object requiring the vat to
   *originate* traffic; expect this to surface real gaps.
3. **Car Factory builder → Car Factory → Car** — three chained behaviours and
   the first case where a behaviour *spawns* actors and returns references to
   them. Car itself is trivial (string interpolation) once spawning works.
4. **Promise resolver** — returns TWO values (promise + resolver) and needs a
   resolver actor whose message mutates a promise. Exercises the
   `pst-unresolved`/`fulfill`/`break` machinery from the responder side.
5. **Sturdyref enlivener** — LAST. Requires making outbound connections to a
   third party, which is a netlayer capability we do not have; it is a
   different order of work from the other four.

## Known coupling to part 1

`swiss-num-export` in `captp-core.prologos` currently maps the five
swiss-nums to export positions 1N–5N as a **closed function**, which is
scaffolding and is labelled as such in `1e23debd`'s message. It maps names
to positions but guarantees nothing about an actor existing at those
positions. Part 2 must either (a) spawn actors at those fixed positions at
server startup, or (b) — the on-network answer — replace the function with a
hash-union cell keyed by swiss-num, populated as objects are registered.
Prefer (b); (a) will strand the registry off-network and needs retiring
later anyway.

## Gate

`tools/interop/ocapn-run-tests.py`'s `SELECTED` allow-list is the honest
progress meter; extend it as objects land, and raise `EXPECTED_PASS` in
`tools/interop/run-ocapn-test-suite.sh` (currently 4) in the same commit.
Do not raise it speculatively.

## CORRECTION 2 (2026-07-27, later — I was wrong about "phantom")

Commit `20e959eb` claimed **two of the seven mechanisms were phantom**
because the op:listen machinery already provided them. That was half right
and half wrong, and the wrong half is load-bearing.

- **Mechanism 5 (resolver table) — genuinely phantom.** `bs-add-listener`
  records pid → resolver export position. Confirmed by use.
- **Mechanism 6 (emit for settled promises NOT in the inbound question
  table) — REAL. The audit was right; I was wrong to dismiss it.**

Why: `pump-outbound` → `pump-loop` walks `[bs-questions st]`
(`captp-core.prologos:1913`) and reaches `listener-bytes-for-pid` only
*inside* that walk, per QEntry (`:1882`). So a listener is only ever
consulted for a promise that ALSO has a question-table entry.
`deliver-resolve-me` allocates an answer promise and registers a listener
but adds no question entry — so the pump never visits that pid, the promise
settles silently, and zero bytes go out.

**Observed exactly this**, driving the real upstream suite:

```
conn 1 frame 2 (103 in / 71 out bytes)   <- fetch reply: WORKS
conn 1 frame 3 ( 81 in /  0 out bytes)   <- echo deliver: silent
```

The fetch path works because `do-fetch` bypasses the pump entirely — it
stages its reply directly onto pending-out. The deliver path cannot, because
the reply value only exists after the vat runs the actor.

**So the remaining work is one thing**, and it is mechanism 6 as originally
written: a pump stage that emits `listener-notify-bytes` for settled
promises carrying a listener but no question entry. Do NOT try to fake a
question entry to reuse the existing walk — a QEntry means "the peer asked
via answer-position", and the pump would emit an answer-position resolution
the peer never requested.

**Method note.** Both corrections in this doc came from *running the thing*,
not from reading it — the 14-agent audit, and then me, both got this wrong
by inspection. The `71 out` vs `0 out` line in a server log settled in one
run what two rounds of code-reading argued about.

## The one blocker for 3 of the 5 objects: behaviours cannot SEND (design note)

Verified state after this session: 5 of 24 upstream tests pass. The next
three objects (Greeter, Car Factory, promise resolver) all need the same
missing capability, so this is one piece of work, not three.

**What is missing.** A behaviour can do exactly four things (`ActStep` +
`Effect`, `behavior.prologos:59-74`): become a new state, return a value,
`eff-send-only` to a **vat-local actor id**, or settle a promise. There is
no way to send an `op:deliver` to a **peer export position**. Upstream's
Greeter test requires exactly that:

```python
greeter_refr = self.remote.fetch_object(b"VMDDd1vo...")
deliver_only_op = OpDeliver(greeter_refr, [object_to_greet], False, False)
self.remote.send_message(deliver_only_op)
response = self.remote.expect_message_to(object_to_greet.to_desc_export())
self.assertEqual(response.args, ["Hello"])
```

i.e. the Greeter must ORIGINATE a frame to a descriptor the peer supplied.

**Why it is not a one-liner — the layer crossing.** The vat is deliberately
wire-agnostic; `apply-effect` (`vat.prologos:318-322`) maps Effects onto vat
operations only. Outbound frames live in `BridgeState`'s pending-out, which
the vat cannot reach. So a new Effect variant needs somewhere to land:

  Option A — add an outbound-request queue field to `Vat`. `apply-effect`
  appends to it; `connection-step` drains it after `run-vat` and appends
  `listener-notify-bytes`-style frames to pending-out. Clean separation
  preserved (the vat still never touches bytes), but it is a **struct field
  addition**, which per `.claude/rules/pipeline.md` § "New Struct Field"
  means: `raco make driver.rkt`, then grep for EVERY `struct-copy` AND every
  direct `(vat ...)` constructor call tree-wide — `empty-vat`
  (`vat.prologos:211`), `seeded-vat` (`interop-driver.prologos`), and any
  test fixture. That checklist exists because this class of change has
  silently broken things before; budget for it.

  Option B — have the behaviour return the send request as part of its
  return VALUE and let captp-core interpret it. Cheaper, no struct change,
  but it overloads the return value with control information and every
  caller of `step-behavior` must learn the convention. Rejected on the
  mantra (information should flow structurally, not by convention), but
  recorded because it is the tempting shortcut.

Prefer A. Do it as its own phase with its own tests, not bundled with an
object.

**Then, and only then**, the objects: Greeter is ~10 lines once sending
exists; Car Factory additionally needs a behaviour to SPAWN (a second
missing Effect, same layer-crossing question, so design both at once); the
promise resolver needs to return two references.

**Sturdyref enlivener stays last and is a different order of work** — it
requires outbound connections to a third party, a netlayer capability that
does not exist at all.


## Greeter E2E: REPRODUCED OFFLINE (2026-07-27) — start here next session

The greeter is implemented and the machinery is verified, but it does not
reply end-to-end. The important result is that **the failure now
reproduces offline in ~2 minutes**, so nobody needs to debug it through
the live server again.

**The reproduction.** Write hex-encoded frames into a `.prologos` file and
call the server's own entry points:

```
ns tmp-stash
require [prologos::ocapn::interop-driver :refer-all]

[init-connection 10N]
[step-connection 10N "<hex of the 62-byte deliver frame>"]
```

The two frames, byte-for-byte what upstream sends (lengths 103 and 62
match the server log exactly):

```
fetch:   <10'op:deliver<11'desc:export0+>[5'fetch32:VMDDd1voKWarCe2GvgLbxbVFysNzRPzx]f<18'desc:import-object3+>>
deliver: <10'op:deliver<11'desc:export1+>[<18'desc:import-object7+>]ff>
```

Result: fetch returns the correct fulfill reply; the deliver returns `""`.
Same as the live server (`62 in / 0 out`).

**What is RULED OUT** (each verified, do not re-test):

| Hypothesis | Verdict |
|---|---|
| `decode-op` rejects the frame | NO — round-trips fine, `RAW-OK` and `VIAHEX-OK` |
| `hex-to-bytes` corrupts it | NO — decodes identically raw vs via-hex |
| Logic is wrong | NO — `connection-step dop seeded-connection` emits correct bytes |
| Post-fetch state is the problem | NO — `connection-step dop [conn-step-state step1]` also emits correctly |
| Fuel | NO — drain-fuel is 20 (was 5, #46) |
| Greeter can't read the descriptor | FIXED — handles `syrup-refr` AND tagged `desc:import-object`/`desc:export` |

So: **`connection-step` works, `step-connection` does not.** The gap is
between them — `run-step cid op [conn-fetch cid]`.

**Prime suspect.** `ocapn-conn-fetch` is `(hash-ref conn-table conn-id #f)`
— it returns `#f`, not a ConnectionState, on a miss. If the Nat key does
not round-trip through the FFI boundary as an `equal?`-consistent Racket
value, every fetch misses and the greeter has no actor at 1N. Note that
**fetch succeeding proves nothing about the stash** — `maybe-fetch` is a
pure swiss-num lookup that needs no actor, which is exactly why the fetch
frame replies correctly while the deliver does not.

**Next probe** (untested, ~2 min): decode the frame and print
`op-deliver`'s args to see how the descriptor is represented after
decoding, then compare against the hand-built `dop` that works. If they
differ, the greeter's arm does not match the decoded shape. My attempt at
this failed on an unrelated unbound `SyrupValue` import — import
`prologos::ocapn::syrup` explicitly rather than relying on
`captp-wire :refer-all`.


## CORRECTION 3 (2026-07-27, later still) — the FFI-stash suspect is REFUTED

The "prime suspect" recorded above (ocapn-conn-fetch returning #f on a key
miss) is **WRONG**. Do not chase it.

Decisive test — both objects driven through the SAME `step-connection`
path, same session, only the target differing:

```
[init-connection 20N]
[step-connection 20N "<hex of echo deliver, 65 bytes>"]
  -> "<10'op:deliver<11'desc:export3+>[7'fulfill[2\"hi]]ff>"   ECHO WORKS

[init-connection 21N]
[step-connection 21N "<hex of greeter deliver, 62 bytes>"]
  -> ""                                                        GREETER FAILS
```

Echo finds its actor at 2N through the stash, so the stash, the FFI key
round-trip, and `conn-fetch` are all FINE.

Seeding is also fine, verified directly:

```
def v := [seeded-vat 2N 1N]
[length [vat-actors v]]                     -> 2N
actor-table-get 1N -> ACTOR-AT-1 ; 2N -> ACTOR-AT-2
```

**So the remaining difference is the FRAME SHAPE, not the plumbing.**
The echo frame carries a resolve-me descriptor
(`f<18'desc:import-object3+>`); the greeter frame has `ff` — NO answer
position and NO resolve-me. That is the one axis left that distinguishes
a working call from a failing one, and it is where the next session should
start: trace `dispatch-deliver`'s `ap = none` arm through to whether the
pump's drain stage is actually reached when there is neither a question
nor a listener to pump.

Note this sits awkwardly against the earlier finding that
`connection-step dop seeded-connection` DOES emit correct bytes for the
same frame shape. Both observations are recorded as made; reconciling them
is the first job, and one of the two probes must differ from what I
believed it did.

## Secondary finding — a top-level `match` over `Option` fails to infer

While probing, this failed to elaborate:

```
match [decode-op [hex-to-bytes "…"]]
  | none   -> syrup-null
  | some op -> args-of op
```

with `Could not infer type` on the whole `reduce` form. Binding through a
`def` with an explicit `[Option CapTPOp]` annotation elaborates, but then
leaves a STUCK `[reduce decoded | none -> … | some x -> …]` term rather
than reducing.

This matters beyond the probe: **it is the same failure signature as the
four failing OCapN suite files** (`test-ocapn-{vat,bridge,e2e,pipeline}`),
which all fail with `Could not infer type` on expressions of the shape
`fulfilled? (unwrap-or fresh (lookup-promise …))`. Those tests are sexp
mode via `run-last`; the same logic in a WS `.prologos` file through
`process-file` returns `true`. A shared root cause in Option-returning
calls under sexp/eval is the strongest available lead for making
`test.yml` green.

---

## RESOLVED (2026-07-27) — the shared root cause was a compiler bug, not an OCapN one

The lead above was right that the four failing suite files and the
`decode-op` probe shared a root cause, and wrong about what it was. It is
not "Option-returning calls under sexp/eval". Full write-up in
goblin-pitfalls **#48**; the short version:

`infer-on-network/full` (`typing-propagators.rkt`) runs the on-network
typing pass under a deliberately small budget, `TYPING-FUEL-LIMIT = 200`.
Exhausting it makes the fuel cell record a **contradiction** on the
network. The bounded run restored the fuel *value* afterwards but not the
contradiction *marker* — and `unify`'s top-level wrapper downgrades **any**
successful unification to `#f` while the network carries a contradiction.
So one over-budget typing run made every later unification in the same
command fail. Instrumented: `unify Vat Vat` → core returns `#t`, wrapper
returns `#f`; `check e ⇐ T` failing while `infer e` returned exactly `T`.

The budget is crossed by ordinary code — measured, one `let` binding of
list operations costs ~74 fuel, four cost ~211 — so this fired constantly.

**Fixed** by saving/restoring the contradiction marker on the same boundary
as the fuel value (only when the marker is the fuel cell, so a genuine
contradiction still propagates). Audited: `fork-prop-network` already
builds a fresh warm with `contradiction = #f`, so fork-based bounded runs
were never affected; the in-place typing run was the only leak site.

**Result**: `test-ocapn-pipeline`, `test-ocapn-e2e`, `test-ocapn-bridge`,
`test-ocapn-vat` all pass — 183 tests. Regression test
`tests/test-typing-fuel-scoping.rkt` (7 tests; 4 fail without the fix,
verified by A/B stash).

### Two things this did NOT fix

1. **Inline `match` in infer position never type-checks.** A bare
   `(match (cons 1 nil) | nil -> 0 | cons hd _ -> hd)` — no `let`, 34 of 200
   fuel — fails identically. It needs a checking context;
   `(the Int (match …))` works. This is what goblin-pitfalls #30 actually
   hit, and #30's "7+ binding let-chain" framing was wrong on both counts
   (correction appended to that entry).
2. **The stuck `[reduce …]` term.** Annotating through a `def` gets past
   elaboration but leaves an unreduced `reduce`. That is a reduction-side
   question, separate from the typing budget, and is still open.

---

## MEASURED STATUS (2026-07-27, after the greeter fix)

Upstream is 24 tests. Seven of them (`third_party_handoffs`) need the Tor
onion netlayer and therefore `stem`, which is out of scope here — upstream's
own `test_runner.py` cannot even be imported without it, which is why this
repo carries its own selective loader.

Running **all 17 non-Tor tests** against the server (scratch runner built
from `tools/interop/ocapn-run-tests.py` with every non-handoff test listed):

```
Ran 17 tests in 211.169s
FAILED (errors=11)     ok: 6   ERROR: 11   FAIL: 0
```

So: **6 of 24 overall; 6 of the 17 reachable ones.**

| Test | State | Gated on |
|---|---|---|
| `op_start_session` × 3 (version, invalid version, invalid signature) | PASS | — |
| `op_abort` `test_abort_before_setup` | PASS | — |
| `op_deliver` `test_deliver_with_resolver` | PASS | — |
| `op_deliver` `test_send_deliver_no_answer_or_response` (greeter) | PASS **NEW** | — |
| `op_listen` × 3 | ERROR | **the promise-resolver object** (swiss-num `IokCxYmMj04nos2JN1TDoY1bT8dXh6Lr`) |
| `op_deliver` promise pipelining × 2 | timeout | **the Car Factory chain** (builder → factory → car) |
| `op_gc` × 4 | ERROR | **emitting `op:gc-export`** — we never send one |
| `op_start_session` crossed-hellos × 2 | timeout | **outbound connections** (we are responder-only) |
| `third_party_handoffs` × 7 | not run | Tor / `stem` |

### The cheapest remaining win: op:listen (3 tests), and it does NOT need a spawn effect

All three `op_listen` tests call `make_promise_resolver_pair()` **exactly
once per connection**, and each test opens its own connection
(`self.netlayer.connect`). Verified by reading the upstream source, not
assumed. So the pair does not have to be created dynamically — it can be
**pre-seeded at `init-connection`**, exactly the way Echo and the Greeter
already are:

1. register `IokCxYmMj04nos2JN1TDoY1bT8dXh6Lr` in `swiss-num-export`;
2. at connection init, allocate a promise at a reserved id and place a
   resolver actor at another reserved id (`seeded-vat` already reserves ids
   this way and sets `next-id` above them);
3. `beh-promise-resolver`: called with no args, resolve the caller's
   resolve-me promise with `syrup-list [<promise-desc>, <resolver-desc>]`;
4. `beh-resolver`: called with a value, emit `eff-resolve <promise-id> value`.

This is the "pre-allocated ids" option from the earlier plan, done
STATICALLY — the ids are reserved at connection setup rather than mid-turn,
so `step-behavior` needs no new parameter and the seven `step-*` helpers are
untouched. Honest limitation to document when it lands: one pair per
connection. That is sufficient for every upstream test that asks for one,
and the dynamic version (a real `eff-spawn`) is only forced by the Car
Factory chain, which must return a reference to something it spawns.

### Revised sequencing

1. **Promise resolver, statically pre-seeded** → unlocks `op_listen` × 3
   (6 → 9). No signature change.
2. **`op:gc-export` emission** → unlocks `op_gc` × 4 (9 → 13). Independent
   of 1; needs reference counting on the export table, not new vat
   machinery.
3. **`eff-spawn` + pre-allocated ids** → Car Factory chain → promise
   pipelining × 2 (13 → 15). This is where the signature change is actually
   forced.
4. **Outbound connections** → crossed-hellos × 2 (15 → 17). Separate track;
   `mk-handshake-bytes` is reusable as initiator; what is missing is the
   netlayer connect plus questioner-side bridge state.
5. **Tor handoffs × 7** — out of scope by owner instruction.

**CORRECTION (same day, after reading the handoff tests): 17 is NOT the
ceiling — 24 is.** See "All 24 are reachable over TCP" below.

### Diagnostic aid added

`tools/interop/run-ocapn-test-server.rkt` now dumps each inbound frame as
hex under `OCAPN_FRAME_HEX=1`. Capturing the REAL frame is what unblocked
the greeter: the previously-recorded probe used `desc:import-object 7`, but
the wire sends `1`, and the id collision that caused the bug only exists at
`1`. Guessing the frame hid the bug for two sessions.

---

## CORRECTION 4 (2026-07-27) — all 24 are reachable over TCP; Tor is not required

The status section above says the 7 `third_party_handoffs` tests "need the
Tor onion netlayer" and that 17 is the ceiling here. **Both claims are
wrong**, and the error was inferring the requirement from a symptom instead
of reading the tests.

The symptom: upstream's `test_runner.py` does `from netlayers.onion import
OnionNetlayer` **unconditionally**, so the module fails to import without
`stem` — regardless of which netlayer you actually intend to use. That is a
property of the RUNNER, not of the handoff tests.

The tests themselves:

- `tests/third_party_handoffs.py` contains **zero** references to onion,
  Tor, or `stem` (verified by grep).
- `HandoffTestCase._create_new_netlayer` is `type(self.netlayer)()` — it
  clones whatever netlayer class is in use. It is netlayer-AGNOSTIC by
  construction.
- `TestingOnlyTCPNetlayer()` constructs with no arguments (binds
  `127.0.0.1:0`, i.e. a kernel-assigned port), and exposes everything the
  handoff tests use: `.location` (an `OCapNPeer` with `tcp-testing-only`
  transport plus host/port hints), `.connect()`, and `.accept()`.

So a second TCP netlayer instance stands in for the third party, and the
whole handoff suite runs over plain local TCP. This repo's own selective
loader (`tools/interop/ocapn-run-tests.py`) already sidesteps the onion
import, so no upstream patch is needed either.

### Real blocker map — all 24 tests

| Capability | Unlocks | Needs outbound? |
|---|---|---|
| *(shipped)* | 6 | — |
| **Exporter-side gift handling** | 4 (`HandoffRemoteAsExporter`) | **No** |
| **Promise-resolver object** (statically pre-seeded) | 3 (`op_listen`) | **No** |
| **`op:gc-export` emission** | 4 (`op_gc`) | **No** |
| **Car Factory chain** (`eff-spawn`) | 2 (pipelining) | **No** |
| **Sturdyref enlivener** | 1 (`HandoffRemoteAsGifter`) | sends on an EXISTING inbound session |
| **Outbound connections** | 4 (2 crossed-hellos + 2 `HandoffRemoteAsReciever`) | **Yes** |

**11 of the 18 remaining tests need no outbound-connection capability at
all.** That was the single thing I had been treating as the big gate; it is
worth 4 tests, and it is the LAST thing to build, not the first.

### `HandoffRemoteAsExporter` — full spec (4 tests, all inbound)

Both sessions are the suite dialling US (`self.netlayer.connect` +
`self.other_netlayer.connect`). Required behaviour on the bootstrap object:

- `['deposit-gift' <gift-id> <gift-refr>]` — record the gift.
- `['withdraw-gift' <signed-handoff-receive>]` — reply on the caller's
  **resolve-me** descriptor with `['fulfill <desc:import-object>]`, or
  `['break' …]` when rejected.

Four concrete gaps against what is shipped:

1. **Gift ids are BYTE STRINGS** (`b"my-gift"`), not Nats.
   `dispatch-deposit-gift-rest` runs `wire-nat` on the id and silently
   bridges through unchanged when it returns none, so no gift is ever
   recorded. `bs-add-gift` / `bs-lookup-gift` are `Nat`-keyed and must key
   on the id bytes. `syrup-bytes : String` already carries them.
2. **`withdraw-gift`'s argument is a `desc:sig-envelope`** wrapping a
   `desc:handoff-receive` (which itself wraps the signed
   `desc:handoff-give` that carries the gift id) — NOT a bare gift id.
   `dispatch-withdraw-gift-rest` currently runs `wire-nat` straight on that
   envelope.
3. **The reply channel is resolve-me, not answer-pos.** Upstream sends
   `answer_position=False, resolve_me_desc=…` and awaits
   `expect_promise_resolution`. `withdraw-with-gid` replies via `ap` and
   drops the message when `ap` is none — which is always. The Phase 59b
   `fetch` path already builds exactly the right reply shape; reuse it.
4. **Rejection cases must reply `break`**, not stay silent: a replayed
   handoff-count and a bad signature each expect
   `args[0] == Symbol("break")`. That needs per-(receiving-session,
   side-id) handoff-count tracking and Ed25519 verification — we already
   sign the handshake via `crypto-ffi`, so the verify primitive is at hand.

Plus `test_valid_handoff_wait_deposit_gift` withdraws BEFORE the deposit
arrives, so a withdrawal for an unknown gift id must be PARKED and answered
when the deposit lands — not dropped.

---

## HandoffRemoteAsExporter — ATTEMPTED, REVERTED, with the real blocker found

Verified first that the handoff tests run over plain TCP (correction 4 above):
all 7 execute, no `ModuleNotFoundError`, no Tor. They fail on protocol
behaviour. So the netlayer question is settled.

Implemented the four gaps listed above — gift table re-keyed to the id BYTES
(`data GiftEntry { gift-entry : String -> Nat }`), `deposit-gift` reading the
id via a new `syrup-bytes-of` instead of `wire-nat`, `withdraw-gift` moved off
the answer-pos gateway onto the resolve-me one where `rm` is in scope, the
five-level descent through
`sig-envelope → handoff-receive → sig-envelope → handoff-give → gift-id`, and
`fulfill` / `break` reply builders. It compiled and the greeter/e2e probes
stayed green.

**It still produced 0 bytes**, and the reason is upstream of all of it.

### The blocker: `decode-op` rejects the signed handoff descriptors

The withdraw frame is 716 bytes. Fed to `decode-op` directly:

```
def d  : [Option CapTPOp] := [decode-op [hex-to-bytes "<the 716-byte frame>"]]
def tgt : Nat := match d | none -> 99N | some op -> [unwrap-or 98N [deliver-target op]]
   -> 99N          ;; i.e. decode-op returned NONE
```

So nothing downstream of the decoder can matter yet. The server log agrees:
`conn 7 frame 2 (716 in / 0 out bytes)` — and with the handler in place it did
not even emit the `break` it would have emitted on a parse failure of its own,
because `step-connection` bails at `decode-op` returning none before any
handler runs.

What the frame contains that the smaller ones do not:

- `desc:sig-envelope` wrapping another record, twice, nested;
- a gcrypt-style s-expression signature
  `[sig-val [eddsa [r <32 bytes>] [s <32 bytes>]]]` — nested LISTS of symbols
  and bytestrings, not a record;
- `desc:handoff-give` carrying a `CapTPPublicKey` record and an `OCapNPeer`
  location record as its first two fields;
- `desc:handoff-receive` carrying a nested signed give as its fourth.

Which of those the decoder chokes on is not yet isolated — the next step is to
bisect by feeding `decode-op` progressively larger sub-records, or to add a
decode trace. That is the whole remaining gate for these 4 tests: the handler
side is understood and was written once already.

### Why the implementation was REVERTED rather than landed

`bs-add-gift` / `bs-lookup-gift` changing from `Nat` to `String` keys breaks
~20 assertions in `test-ocapn-bridge.rkt` that deposit Nat gift ids, and moving
`withdraw-gift` off the answer-pos channel breaks the ones that assert a reply
arrives there. Those tests encode the OLD (wrong) contract — upstream never
sends an answer-pos for `withdraw-gift`, and gift ids are bytes — so they would
have to be rewritten, not patched.

Rewriting 20 assertions to unlock 0 tests, while the decoder still blocks all
4, would leave the gift table half-migrated for no gain. That is the same
"don't leave the tree half-migrated" call made earlier for the Vat struct.
Reverted; the analysis above is the deliverable, and the implementation is a
short redo once the decoder parses the frame.

**Order for the next attempt**: fix `decode-op` FIRST, confirm the 716-byte
frame decodes and the target/resolve-me come out right, and only then redo the
handler + rewrite the bridge tests to the byte-id / resolve-me contract in the
same commit.

---

## `decode-op` on the handoff frames — ROOT CAUSE FOUND: no Syrup DICTIONARY support

Rendered, the 716-byte withdraw frame is:

```
<10'op:deliver<11'desc:export0+>[13'withdraw-gift
  <17'desc:sig-envelope
    <20'desc:handoff-receive
       32:<recv-session>  32:<recv-side>  0+
       <17'desc:sig-envelope
         <17'desc:handoff-give
            [10'public-key[3'ecc[5'curve7'Ed25519][5'flags5'eddsa][1'q32:…]]]
            <10'ocapn-peer16'tcp-testing-only32"JadQ0++…
               {4"host9"127.0.0.14"port5"22116}>        ;; <-- HERE
            32:<session>  32:<gifter-side>  7:my-gift>
         [7'sig-val[5'eddsa[1'r32:…][1's32:…]]]>>
    [7'sig-val[5'eddsa[1'r32:…][1's32:…]]]>]
  f<18'desc:import-object0+>>
```

The `ocapn-peer` location carries its hints as a Syrup **DICTIONARY** —
`{4"host9"127.0.0.14"port5"22116}`. `decode-at` (syrup-wire.prologos:379)
dispatches on:

| byte | code | form |
|---|---|---|
| `n` | 110 | null |
| `t` | 116 | true |
| `f` | 102 | false |
| `[` | 91 | list |
| `<` | 60 | record |
| digit | — | int / string / symbol / bytes |

and falls to `none` on anything else. `{` is 123 — unhandled. The file's own
header says so outright: *"Floats / dicts / sets / bytes are deferred"* (bytes
have since landed; dicts have not). So the frame dies at the first `{`, and
`decode-op` returns none — which is exactly what the probe showed.

Nothing about `desc:sig-envelope`, the nested envelopes, or the gcrypt
signature s-expressions is a problem: those are all records and lists, which
decode fine. **The single missing feature is the dictionary.**

### Scope of the fix

1. `syrup.prologos` — a `syrup-dict` variant on `SyrupValue`.
2. `syrup-wire.prologos` — the `{` (123) decode case, and the encode case.
3. **41 exhaustive `SyrupValue` matches** across 5 files
   (behavior 11, syrup 11, captp-wire 9, captp-core 7, syrup-wire 3) each need
   one more arm.

Point 3 is the bulk, but it is mechanical AND it fails LOUDLY: Prologos's
exhaustive matches produce `Hole ??__match-fail` on a missing arm (observed
this session in test-ocapn-bridge), so an omission is detected, not silent.
For nearly every one of these sites — predicates and shape-readers — the
correct answer for a dict is the same as the one already given for
`syrup-promise`: "not that shape". So the migration can be driven off the
existing `syrup-promise` arm, with the handful of genuinely-different sites
(the encoder, the pretty-printer) written by hand.

### Why this is worth doing beyond the 4 exporter tests

`OCapNPeer.hints` is how EVERY netlayer location is expressed on the wire, so
dict support is a prerequisite for anything that carries a location: the
sturdyref enlivener (1 test), and both `HandoffRemoteAsReciever` tests, which
send us a location to connect out to. It is not exporter-specific plumbing.

---

## Exporter handoff, second attempt — the handler WORKS; the remaining blocker is a CROSS-CONNECTION gift table

With dict support landed, `decode-op` parses the withdraw frame, so the
handler could be redone and actually exercised. Result: **1 of 4 passing, and
the other three fail for one reason.**

What now works, verified:

- the frame decodes (target `0N`, resolve-me `0N`);
- the five-level descent returns the right id — probed directly on the real
  716-byte frame, `withdraw-gift-id` yields `"my-gift"`;
- we REPLY: the server log shows `conn 1 frame 2 (716 in / 59 out bytes)`,
  where it was `716 in / 0 out` before;
- the whole class went from a 258s timeout to 13s;
- `test_handoff_receive_invalid_signature` PASSES.

The other three assert `fulfill` and get `break` — specifically
`no-such-gift`. The reason is structural, and visible in the server log:

```
ocapn-test-server: conn 0 frame 3 (79 in / 0 out bytes)     <- deposit-gift
ocapn-test-server: conn 1 frame 2 (716 in / 59 out bytes)   <- withdraw-gift
```

**The deposit arrives on conn 0 and the withdraw on conn 1.** Upstream's
`HandoffRemoteAsExporter` opens two sessions to us — `g2e_session` via
`self.netlayer` and `r2e_session` via `self.other_netlayer` — because the
gifter and the receiver ARE different peers. That is the entire point of a
third-party handoff.

Our gift table lives in `BridgeState`, which `ocapn-conn-ffi.rkt` stashes
PER CONNECTION. So the deposit lands in conn 0's table and the withdraw looks
up conn 1's, finds nothing, and correctly reports `no-such-gift`.

### The fix (next piece, well-scoped)

The gift table is EXPORTER-GLOBAL state, not session state — it is keyed by
gift-id precisely so a different session can withdraw. It has to move out of
`BridgeState` into a process-level store, in the same shape as
`ocapn-conn-ffi.rkt`'s connection stash: an FFI-backed table keyed by gift-id
bytes.

Everything else for these 4 tests is done. Note the invalid-signature test
currently passes for the wrong reason (we break on everything), so it will
need a real Ed25519 verification once withdrawals start succeeding — the
`crypto-ffi` primitives are already in use for handshake signing.

Also attempted while here, and REVERTED: splitting `test-ocapn-bridge.rkt`
(147 test-cases), which was the one file timing out at the runner's 120s
per-file limit on CI.

**The split made CI worse — 1 timeout became 2, with BOTH halves over the
limit.**

My first explanation was "the dominant cost is per FILE, so splitting paid it
twice". **That is wrong**, and it went into a commit message, `.skip-tests`
and this doc before I checked the arithmetic. Measured afterwards: the shared
fixture costs **8.8s** (same preamble, one trivial test) and each test ~**0.40s**
— so splitting added ~9s to a >300s file, under 3%. The model checks out
exactly against the local split (8.8×2 + 59 = 77s; measured 38+39 = 77s).

Both halves timed out for a much duller reason: half of >300s is still over
the 120s limit. No large fixed cost is needed to explain it, and the local
numbers actively argue against one. I asserted a mechanism when all I had was
a correlation.

The real lever already existed and was merely unreachable: `batch-worker.rkt`
has always supported `--file-timeout`, but `run-affected-tests.rkt` never
passed it through, so the 120s default could not be raised from CI. Plumbed it
through and set `--file-timeout 300` in `test.yml`. That default dates from
when "slowest normal tests ~17s"; these tests are legitimately heavier.

`.claude/rules/testing.md`'s ~20-cases/~30s guidance stays right in general.
Splitting just cannot help when the file is 4x over budget — it divides the
variable cost but not the overrun.

### What is actually slow, as far as it has been established

The disproportion is in PER-TEST cost on CI. The suite overall runs 2.3x
slower there (942s vs 402s local) while this file runs >4.4x slower (>300s vs
68s) — about 1.9s/test against 0.40s here.

Ruled out locally, each measured, none of them reproducing it:

| hypothesis | result |
|---|---|
| CPU contention (3 burners / 4 cores) | 68.7s vs 67.5s idle — no effect |
| Oversubscription (7 burners / 4 cores) | 67.7s — no effect |
| Cold `.pnet` caches (all 15 deleted) | 63.3s — no effect |
| Fixture dominance | 8.8s of 68s — not dominant |

Remaining candidate: runner resources. Peak RSS is **497 MB** for one run, so
4 concurrent batch workers want ~2 GB — comfortable on this 16-core-GB box,
much less so on a smaller runner, where GC pressure would fall hardest on
allocation-heavy propagator-network tests. That is a HYPOTHESIS. Confirming it
means instrumenting the CI job itself (log peak RSS and core count there);
more local runs cannot settle it, which is the lesson from the three rows
above.

### Cross-connection gift store — design note (next piece)

The mechanism is easy; the LAYERING is the decision. `ocapn-conn-ffi.rkt` is
the template: a Racket-side `make-hash` exposed through `foreign racket`, 38
lines total.

The wrinkle: `withdraw-known-gid` lives in `captp-core.prologos`, which is a
PURE library module — it threads `BridgeState` through and performs no effects.
Having it call an FFI store directly would put I/O in the pure core, which is
the wrong layer and would make every bridge test depend on process-global
state.

Preferred shape — keep `captp-core` pure, put the global in the driver:

1. `ocapn-gift-ffi.rkt` — `gift-put : String -> Nat -> Bool`,
   `gift-all : ... -> [List GiftEntry]` (passthrough of the opaque list, the
   same trick the ConnectionState stash uses).
2. `interop-driver.prologos`, in `step-connection`, around the existing
   `connection-step` call:
   - BEFORE: seed the fetched `ConnectionState`'s gift table from the global
     store, so a withdraw on conn 1 sees a deposit made on conn 0;
   - AFTER: publish any gift the step ADDED back to the global store.

That is the same in-then-out shape `run-step` already uses for the
ConnectionState itself, so it needs no new concept — and `captp-core` stays a
pure function of its inputs, which is what keeps the 147 bridge tests
meaningful.

Rejected alternative: threading a store handle through `captp-incoming-with-
state`. It would touch every caller and put the global in the type of every
bridge operation, to no benefit — the gift table is the ONLY exporter-global
state in the protocol.

---

## Where the time actually goes (profiled 2026-07-28)

The interop tests are slow because of TWO fixed per-command costs, neither of
which is protocol work. The OCapN server runs one `process-string` per wire
frame, so both are paid per frame.

### 1. The memory report forced two major GCs per command — FIXED

`measure-memory-before` / `measure-memory-after` each called
`(collect-garbage 'major)`, unconditionally, at all three driver call sites.
Measured on `test-ocapn-bridge.rkt` (147 cases, each a `process-string`):
**64.1s with, 28.1s without — 2.3x**, all of it instrumentation. Now gated
behind `PROLOGOS_MEM_STATS_GC` (off by default; `bench-ab.rkt` opts in).

### 2. Whole-program capability inference re-runs on EVERY command — OPEN

Profiling one `step-connection` (117ms):

| | share of total |
|---|---|
| `run-post-compilation-inference!` | **76%** |
| ⤷ `run-capability-inference` | 96% of that |
| `process-command` (the actual protocol work) | **19%** |
| `module-network-from-snapshot` (fixture) | 6% |

`run-capability-inference` (capability-inference.rkt:255) does, from scratch,
per command:

1. builds the full call graph over the entire global env;
2. allocates a propagator network with **one cell per function in the whole
   program**;
3. installs a propagator per call edge;
4. runs it to fixpoint.

Then `run-post-compilation-inference!` additionally iterates every entry of
`(global-env-snapshot)` to re-check authority roots.

The trigger is just `(not (hash-empty? (current-capability-registry)))` — 18
entries here, coming from `prologos::core::capabilities`, which the OCapN
modules import. **So any program that merely imports that module pays
whole-program re-analysis on every single command**, including commands that
define nothing.

That last point is the lever: `step-connection` is an `(eval …)`. It adds no
definitions, so it cannot change the call graph, so the analysis result cannot
change. The obvious fixes, cheapest first:

- **skip when the command defined nothing** — an eval-only command can't alter
  the call graph;
- **cache on an env generation counter** — recompute only when the global env
  actually changed;
- **make it incremental** — it is already a propagator network, so this is the
  on-network-shaped answer, but it is much more work than the first two.

Expect the first option alone to take `step-connection` from ~117ms to ~25ms,
which would turn the 13s exporter-handoff run into roughly 3s.

### `test_valid_handoff_wait_deposit_gift` — the path that avoids a cross-connection push

The obvious reading is that this test needs the server to write bytes to a
connection it is not currently stepping, which it cannot do: the withdraw
arrives on `r2e_session` (conn B), the deposit on `g2e_session` (conn A), and
the answer must reach conn B. Our server writes only the bytes a step returns
for the connection it stepped.

But the test explicitly permits answering with a PROMISE:

```python
initial_response = self.r2e_session.expect_message_to(withdraw_gift_msg.exported_resolve_me_desc)
self.assertEqual(initial_response.args[0], Symbol("fulfill"))
# Clients may return a promise, or the actual object
if isinstance(initial_response.args[1], captp_types.DescImportPromise):
    listen_on_vow_msg = captp_types.OpListen(initial_response.args[1].to_desc_export(), ...)
    self.r2e_session.send_message(listen_on_vow_msg)
    second_response = self.r2e_session.expect_promise_resolution(...)
```

That gives a flow with no cross-connection write at all:

1. **withdraw on conn B, gift absent** — do NOT break. Allocate a promise `P`,
   reply immediately with `['fulfill <desc:import-promise P>]` (conn B is the
   connection being stepped, so this is an ordinary reply), and park
   `P -> gift-id` in the exporter-global store.
2. **deposit on conn A** — records the gift globally, as it already does. No
   push needed, and nothing has to reach conn B yet.
3. **`op:listen` on P, on conn B** — this is a STEP ON CONN B, and by the time
   it arrives the deposit has landed (the test sends the deposit before it
   waits). Resolve `P` from the parked gift-id against the now-populated global
   table, and the EXISTING late-fire path
   (`bs-handle-listen-with-late-fire`) delivers the notification, because it
   already answers immediately when the promise is settled.

So the missing pieces are bounded and need no new architecture:

- reply with `desc:import-promise` instead of `break` when the gift is absent
  but the receive is otherwise valid;
- a park map `promise-id -> gift-id`, alongside the gifts in the global store
  (it will want its own namespace — see the "used:" prefix tradeoff above,
  which is now at two overloads and should become a proper record before it
  reaches three);
- on `op:listen` for a parked promise, consult the global gift table and settle.

The one thing to verify early: that our reply actually encodes as
`desc:import-promise` and not `desc:import-object`, since the test branches on
that and the non-promise branch would then assert against a promise.

### `invalid_signature` — blocked on a LOSSY record round-trip, measured

Verifying the signed handoff-receive means re-encoding the inner
`<desc:handoff-receive …>` and checking the signature over those bytes. So the
first question is whether we can reproduce the peer's bytes at all. **We
cannot, today** — measured on the real 716-byte withdraw frame:

```
decode-value then encode:   851 -> 863 bytes,  byte-identical? false
```

Exactly +12, and the mechanism is confirmed: the frame has 9 records, of which
**6 are MULTI-ARG** (op:deliver, sig-envelope ×2, handoff-receive,
handoff-give, ocapn-peer). 6 × 2 = 12.

The cause is the known encoder asymmetry that `encode-record` exists to work
around. The DECODER turns `<label a b c>` into
`syrup-tagged label (syrup-list (a b c))`, but `encode` renders a tagged value
as `<` label payload `>` — so the list payload comes back with its `[` `]`
intact, as `<label [a b c]>`. Single-arg records are unaffected, which is why
only 6 of the 9 shifted.

This is FUNDAMENTALLY LOSSY, not just a missing case: after decoding,
`<tag [a b]>` and `<tag a b>` are the same value, so no encoder can restore
both. For signature verification specifically that does not matter — every
record in a handoff is multi-arg — but it means the fix is a SEPARATE
"re-encode as decoded" walker that splices a tagged value's list payload,
NOT a change to `encode` (which would corrupt outbound frames that legitimately
carry a single list argument).

So `invalid_signature` needs, in order:

1. a splicing re-encoder, with a round-trip test against this exact frame as
   its gate (`decode |> re-encode == original bytes`);
2. the receiver key out of the gcrypt s-expression nested in the handoff-give
   — `[public-key [ecc [curve Ed25519] [flags eddsa] [q 32:…]]]`, so the `q`
   bytes;
3. the signature out of the envelope's `[sig-val [eddsa [r 32:…] [s 32:…]]]`,
   as r ++ s;
4. `crypto-verify` (already in crypto-ffi.rkt) over those three.

Step 1 is the gate and must be verified FIRST. Without it every signature check
fails, and it fails as "bad signature" rather than as an error — which would
look like working rejection while actually rejecting everything, including the
three exporter tests that currently pass.
