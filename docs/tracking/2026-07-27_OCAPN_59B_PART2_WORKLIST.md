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

17 is the ceiling in this environment; 24/24 additionally requires Tor.

### Diagnostic aid added

`tools/interop/run-ocapn-test-server.rkt` now dumps each inbound frame as
hex under `OCAPN_FRAME_HEX=1`. Capturing the REAL frame is what unblocked
the greeter: the previously-recorded probe used `desc:import-object 7`, but
the wire sends `1`, and the id collision that caused the bug only exists at
`1`. Guessing the frame hid the bug for two sessions.
