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
