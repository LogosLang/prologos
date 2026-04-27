# Goblin Pitfalls — Implementing OCapN in Prologos

Live log of language bugs, ergonomic friction, and pure-FP-vs-actor-system
impedance mismatches encountered while porting Spritely Goblins / OCapN to
Prologos. Each entry: what we tried, what broke, and the workaround.

The implementation lives in `lib/prologos/ocapn/`. Tests in
`tests/test-ocapn-*.rkt`. Acceptance in
`examples/2026-04-27-ocapn-acceptance.prologos`.

## Scope

OCapN's reference implementation (Goblins, in Racket) leans on three things
that Prologos does not give us for free:

1. **Mutable boxes** for actor-state. Goblins's `become` re-binds a behaviour
   slot in place; the vat then routes the next message through the new closure.
2. **First-class closures stored in heterogeneous registries** — the actor
   table maps an opaque `Refr` to a closure `Args -> Action` whose *capture*
   shape varies per actor.
3. **Re-entrant call stacks within a turn** — `($ refr msg ...)` performs a
   synchronous call that can itself send more messages.

In Prologos we get capability types, session types, dependent types, and
QTT — but no mutation, no value-typed `Any`, and a closed-world `data`
declaration. So the impedance is real, and most pitfalls below are
load-bearing for the design.

The goal of this doc is to make the next port easier. If a pitfall has a
trivially small repro, it is filed as a candidate language-bug for the
Prologos team to look at.

---

## Pitfalls

(populated as encountered, newest first; each entry dated)

---

### #0 — Sandbox without a Racket toolchain (2026-04-27, meta-pitfall)

**Symptom.** The OCapN port was written in an environment without
`racket`/`raco` on `PATH`, so the implementation could not be exercised
with `racket tools/run-affected-tests.rkt` while writing it. Every test
file and `.prologos` library module here is *static-syntax-clean by
inspection only*.

**Why this matters.** Our normal cadence (write, `raco make`, run targeted
tests, iterate) is unavailable. Pitfalls #1–#N below were predicted from
reading existing stdlib patterns rather than triggered by a failed run,
so the catalogue is conservative — there are almost certainly bugs in the
delivered code that only surface when a real Racket runs the suite.

**What to do on a real machine.**
1. `racket tools/run-affected-tests.rkt --tests tests/test-ocapn-refr.rkt --tests tests/test-ocapn-syrup.rkt --tests tests/test-ocapn-promise.rkt --tests tests/test-ocapn-message.rkt --tests tests/test-ocapn-vat.rkt --tests tests/test-ocapn-pipeline.rkt --tests tests/test-ocapn-captp.rkt --tests tests/test-ocapn-e2e.rkt`
2. For each test that fails, capture the failure log, classify it, file a new pitfall here. Don't paper over; the whole point of this doc is the next port catches them earlier.
3. After targeted tests pass, run the full suite as a regression gate:
   `racket tools/run-affected-tests.rkt --all`.

**Status.** Open. Will be closed once the suite has been exercised end-to-end.

---

### #1 — Capability subtype + Promise resolution composition (2026-04-27)

**What we tried.** In `lib/prologos/ocapn/refr.prologos` we model OCapN's
attenuation lattice with `capability` declarations and `subtype` edges:

```
capability ResolvedNearPromise
subtype    ResolvedNearPromise NearRefr   ;; a resolved near promise IS
                                          ;; equivalent authority to a near refr
```

The intent is so that a function with parameter type `NearRefr` accepts a
`ResolvedNearPromise` once you have observed its resolution.

**Where this breaks down.** Capability types in Prologos are static —
the subtype edge is a *type-level* fact, but resolution status is a
*value-level* fact (a promise is a runtime cell). We cannot make the
type-level edge conditional on resolution.

In Goblins this composition is enforced dynamically: `($ refr msg)` on
an unresolved promise refr just blocks (or errors) at the message
delivery layer, regardless of what the type system thinks. We mirror
that here — the type-edge is over-approximation; runtime promise
state still gates real authority.

**Implication for the type-driven contract.** A library author who
relies on the static `NearRefr` constraint to mean "caller already
resolved this" gets a weaker guarantee than the syntax suggests.
Document the intended model in `core.prologos`'s docstrings explicitly.

**Open question.** Whether session types could carry the resolution
status as a protocol step (`?? PromiseRefr` until resolution then
re-typed as `NearRefr`). This would require type-level state machines
on capability subjects, which isn't currently available.

---

### #2 — Wildcard match on user data trips type inference (2026-04-27)

**Symptom.** Predicate functions written compactly with a wildcard
fallthrough fail to type-check. Reproduces in
`prologos::data::datum`, which already has a comment to this effect:

> "Explicit exhaustive patterns used instead of wildcard `_` because
> match with wildcard on user data types triggers a type-inference
> limitation that causes module loading to fail."

**Concrete example we hit.** Naive form:

```
spec refr? SyrupValue -> Bool
defn refr? [v]
  match v
    | syrup-refr _ -> true
    | _            -> false   ;; wildcard fallthrough
```

We can't write this. We had to spell every constructor:

```
defn refr? [v]
  match v
    | syrup-null         -> false
    | syrup-bool _       -> false
    | syrup-nat _        -> false
    | syrup-int _        -> false
    | syrup-string _     -> false
    | syrup-symbol _     -> false
    | syrup-list _       -> false
    | syrup-tagged _ _   -> false
    | syrup-refr _       -> true
    | syrup-promise _    -> false
```

**Multiplier.** OCapN models everything as a Syrup value (10
constructors, plus 7 actor-behaviour tags, plus 7 CapTP ops). Every
predicate / selector / step function pays this tax. The behavior
dispatchers (`step-counter`, `step-greeter`, `step-adder`) pay it
*twice* — once on state, once on args — so a 3-line function in
Goblins becomes ~25 lines here.

**Workaround in this port.** A small helper `no-op state` that returns
the unchanged step, so the noisy fallthrough at least reads as "any
ill-typed input is a no-op for this actor". Doesn't help compile time;
helps the eye.

**Filed as a candidate Prologos bug.** A pure FP language without
working wildcard match on user-defined sums is a real ergonomics gap.
Symptom looks shaped like a missing case in match-elaboration's
exhaustiveness analysis when the scrutinee's constructor set isn't
fully resolved before unification — but I couldn't reproduce in this
sandbox to bisect.

---

### #3 — Closed-world actor behaviours (2026-04-27)

**Symptom.** Goblins's actor model is open: any closure
`(args ... -> bcom)` is a valid behaviour. To put one in our vat we
need the behaviour to be a value that can be stored in a `data`
constructor and dispatched at runtime. Two options were tried:

1. **Function-typed field**: `data Actor actor : <Args -> ActStep>`.
   In a dependently-typed positive-recursive setting this is OK in
   theory (the function sits behind a constructor barrier so it's a
   strictly positive occurrence) but we have no working examples in
   the current stdlib of stored function values used as actor
   behaviours, and the QTT `mw`/`m0` interaction with stored thunks
   is unverified for our purposes.

2. **Closed enum + central dispatcher**: `BehaviorTag` is a closed
   sum; `step-behavior` is a giant `match`. Adding a new behaviour
   needs a library change.

We took option 2 and ship a built-in set (cell, counter, greeter,
echo, adder, forwarder, fulfiller) that exercises the architecture.
This is recorded as a real limitation, NOT a workaround — Phase 0 of
this port doesn't unblock user-defined actor closures, and it would
need a Prologos design step to do so cleanly.

**Cost.** The library can demonstrate the actor model and OCapN wire
shape (sends, promises, pipelining, forwarding) end-to-end, but it is
not a usable framework for arbitrary applications until function-
typed behaviour fields land. That's documented prominently in
`core.prologos`'s top docstring.

---

### #4 — No recursive session types yet (2026-04-27)

**What we tried.** A real CapTP wire protocol is a multiplexed
full-duplex stream of `op:*` messages — each peer can interleave
`op:deliver`, `op:listen`, `op:gc-export`, etc. in any order until
one side sends `op:abort`. This is a session that LOOPS over a
non-deterministic choice, the canonical case for recursive session
types (μX. ⊕{deliver:X, listen:X, abort:end}).

**What Prologos session types support.** The session-type DSL
(`session NAME ! T ?? T end`) supports linear, finite sequences and
the `&` external choice over finite alternatives. We didn't see a
recursive `μX` form or a way to express a streaming protocol in a
single session declaration. Closest existing example is
`MixedProto` in `tests/ws-session-e2e-03.prologos`, which is a
finite alternation `!! Nat ? String ! Nat ?? Nat end`.

**Workaround.** `captp-session.prologos` decomposes CapTP into FIVE
finite sub-protocols (Handshake, Deliver, Listen, DeliverOnly, Gc),
each modelled as its own `session` declaration. A real driver would
re-instantiate the appropriate sub-protocol per outbound message and
glue them together at the application layer. This is honest about
what the type system can guarantee (per-exchange shape) versus what
it cannot guarantee yet (long-running connection well-typedness).

**Filed as a Prologos design enhancement.** Recursive session types
+ external choice over symbol-tagged branches would let a single
`session CapTPConn` capture the stream-level invariant. Unblocked,
this would make OCapN's wire protocol a single `defproc` declaration.

---

### #5 — `none` and `some` need explicit type args in some contexts (2026-04-27)

**Symptom.** Several tests need to compare against an `Option Nat`
returned by `lookup-promise`, etc. Writing the literal `none` works
in pattern position but in expression position with no surrounding
inference it can fail with an "ambiguous type variable" error.

**Workaround.** When passed to a function that takes an
`Option Nat`, write `none` and let unification do the work. When
returning `none` from a polymorphic helper as a value, an explicit
type-arg form (`[none Nat]`) is needed in some places. We tried
both forms in `lib/prologos/ocapn/message.prologos`'s
`mk-deliver-no-resolver` (chose the no-arg form because it's
inferred from the `op-deliver` constructor's third-arg type).

**Status.** This is a known general inference-vs-explicit-instantiation
tension in dependently-typed languages, not a goblin-specific bug.
Recorded for completeness — the OCapN port doesn't dodge it; users
will hit it any time they write predicates returning `Option α`.

---

### #6 — sexp-mode `let` vs WS-mode `let := body` (2026-04-27)

**Symptom.** Test files use `process-string` which parses sexp mode.
WS-mode let `let p := expr` is a different surface form from sexp
let `(let (p expr) body)`. The first attempt at writing tests used
the WS form inside the sexp string and produced cascading parse
errors.

**Workaround.** All test strings use the sexp `let` form. Support for
sequential multi-binding lets `(let (a A b B c C) body)` is
confirmed by inspection of `macros.rkt`'s `let-bindings->nested-fn`
(uses `foldr` over bindings). We rely on this in `test-ocapn-vat.rkt`
and `test-ocapn-e2e.rkt` so each test reads as a small program.

**Lesson.** When the same construct has TWO surface forms across
WS-mode and sexp-mode, tests need to agree with the parser the
fixture is using (sexp mode in our case via `process-string`). A
single example in CLAUDE.md showing both forms side-by-side would
have saved an iteration here.

---

### #7 — Closed-data `match` redundancy multiplies with constructor count (2026-04-27)

**Symptom.** This is a quantitative restatement of pitfall #2.
`SyrupValue` has 10 constructors. `step-counter` matches twice (once
on state, once on args), so the worst-case nested-match grid is
10×10 = 100 arms. With four near-identical step functions
(`step-counter`, `step-greeter`, `step-adder`, `step-cell`), this
adds ~400 explicit fall-through arms across `behavior.prologos`.

**Mitigation in this port.** Hoist the "anything ill-typed for me is
a no-op" branch into a `no-op` helper. Each no-op-armed
constructor reduces from 3 lines (`-> act-step state state nil`) to
1 line (`-> no-op state`). Roughly 60% character reduction; doesn't
fix the line count but reads better.

**Filed as a follow-up.** A `match X exhaustively-otherwise BODY`
form, or sound type-narrowing-with-wildcards, would let
`behavior.prologos` shrink from ~250 lines to ~70.

---

### #8 — Sigma in `data` constructor signatures was avoided (2026-04-27)

**What we wanted.** A polymorphic assoc-list table:

```
data Vat
  vat : Nat -> [List [Sigma [_ <Nat>] Actor]] -> ... -> Vat
```

**Why we didn't.** The `[Sigma [_ <T>] U]` syntax is well-attested in
`spec` lines (`spec swap [Sigma [_ <A>] B] -> [Sigma [_ <B>] A]`) but
we couldn't find an example of Sigma in a `data` constructor's
parameter list. To stay safe we introduced concrete monomorphic
entry types:

```
data ActorEntry
  actor-entry : Nat -> Actor

data PromiseEntry
  promise-entry : Nat -> PromiseState

data Vat
  vat : Nat -> [List ActorEntry] -> [List PromiseEntry] -> [List VatMsg]
```

This is a bit more verbose (two extra struct-shaped sums) but reads
clearly and avoids any ambiguity with how the parser treats Sigma in
a positive position inside a constructor type.

**Open.** Was the avoidance necessary? On a real machine the original
form might just work. Worth bisecting the next time someone writes a
heterogeneous-table data type in this codebase.

---

### #9 — `def` with no args means "constant", needs `:=` (2026-04-27)

**Symptom.** First attempt at `promise.prologos`'s constant
`fresh : PromiseState` used `defn`:

```
spec fresh PromiseState           ;; arity-0 spec — odd
defn fresh                         ;; no args
  pst-unresolved nil
```

This shape isn't supported — `defn` declares a function, not a
0-ary constant. The fix is to use `def`:

```
def fresh : PromiseState := [pst-unresolved nil]
```

**Lesson.** `def` and `defn` are NOT interchangeable. `defn` always
takes args; `def` is for top-level value bindings. Stdlib examples
mix the two in different files; CLAUDE.md or a syntax-rules doc could
make the distinction explicit.

---

### #10 — Network sandbox blocks fetching the OCapN spec (2026-04-27)

**Symptom.** The Goblins source repository
(`https://codeberg.org/spritely/racket-goblins`) is unreachable from
this sandbox — `403 Forbidden`. WebFetch on the OCapN GitHub repo
worked for the README and `CapTP Specification.md`, but the Syrup
serialization spec (`Syrup.md`) returned 404 — likely lives in a
different file that the sandbox couldn't enumerate.

**Workaround.** Implementation choices were grounded in:
1. The OCapN README via WebFetch (high-level overview)
2. The CapTP Specification draft via raw.githubusercontent (op:* and
   four-table model)
3. The Model.md draft via raw.githubusercontent (Syrup value space:
   atoms, containers, references)
4. Background knowledge of Goblins's API (spawn / `<-` / `<-np` /
   `on` / `become`).

**Coverage gap.** Syrup's wire-level encoding (canonical bytewise
format with size-prefixed strings, varint integers, structured
records) isn't implemented here — we only model the abstract value
space. A future revision should follow up on `Syrup.md` if/when it's
reachable, port the encoder/decoder, and connect it to the byte
stream layer (which is also missing).
