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
| Echo GC | `IO58l1laTyhcrgDKbEzFOO32MDd6zE5w` | any number of args → returns them in order; must NOT retain refs; GC after each call | close — `beh-echo` exists, but it is single-arg and retention/GC is unaddressed |
| Greeter | `VMDDd1voKWarCe2GvgLbxbVFysNzRPzx` | takes a refr; sends `"Hello"` to it as `op:deliver`; discards the promise, retains nothing | close — `beh-greeter` exists but *constructs* greetings rather than sending to a refr; the spec here is outbound-send, which is different |
| Promise resolver | `IokCxYmMj04nos2JN1TDoY1bT8dXh6Lr` | no args → returns (promise, resolver); resolver takes `break`\|`fulfill` + value | no |
| Sturdyref enlivener | `gi02I1qghIwPiKGKleCQAOhpy3ZtYRpB` | takes a sturdyref; connects to the peer, gets a live ref, returns it | no — needs OUTBOUND connections |

Note the swiss-num in our own test locator is the Car Factory builder's
(`JadQ0++…`); it is the peer designator AND a fetchable object.

## Ordering (cheapest first, and why)

1. **Echo GC** — `beh-echo` exists. Needs multi-arg and a
   no-retention audit. Unblocks the `op_deliver` echo tests, which are the
   largest single group.
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
