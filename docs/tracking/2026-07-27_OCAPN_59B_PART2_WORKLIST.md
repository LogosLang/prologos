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
