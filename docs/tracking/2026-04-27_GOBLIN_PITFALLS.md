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

**RESOLVED 2026-04-27.** A Racket 8.10 was installed via the system
package manager (Ubuntu universe), and the suite was exercised
end-to-end. All 117 OCapN tests pass — see entries below for the
non-trivial fixes triggered by the run, and pitfall #11 for the
v8/v9 compat fence we had to drop into `driver.rkt`.

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

---

### #11 — `thread #:pool 'own` requires Racket 9 (2026-04-27, real bug)

**Symptom.** On Racket 8.10:
```
application: procedure does not accept keyword arguments
  procedure: thread
  arguments...:
   #<procedure:...ogos/propagator.rkt:2593:20>
   #:pool 'own
```
Crashes during the very first `process-string` of any test fixture
because `driver.rkt:434` enables `(current-parallel-executor
(make-parallel-thread-fire-all))` unconditionally and that builds a
worker pool whose workers spawn via `thread #:pool 'own` — a Racket-9
feature.

**Workaround applied.** A try/catch fence in `driver.rkt`:

```
(when (with-handlers ([exn:fail? (lambda _ #f)])
        (define t (thread #:pool 'own (lambda () (void))))
        (thread-wait t)
        #t)
  (current-parallel-executor (make-parallel-thread-fire-all)))
```

If `thread #:pool 'own` raises (Racket 8.x), `current-parallel-executor`
stays `#f` and BSP falls back to `sequential-fire-all`. Tests run
single-threaded but correctly.

**Verdict.** This is a real Prologos infrastructure bug, not specific
to OCapN. Anyone who installs Prologos on Racket 8 hits it
immediately. Should be merged upstream (or the codebase should refuse
to load on < Racket 9 with a friendlier error).

---

### #12 — Test fixture loses `current-ctor-registry` and `current-type-meta` across calls (2026-04-27, real bug, **highest-impact**)

**Symptom.** Tests of the `vat/spawn` shape produced un-evaluated
output:

```
"Expected '[reduce [reduce ... | vat x y z a -> ...] | allocated x y -> x] | vat x y z a -> x] : Nat' to contain '1N'"
```

The expression has the right TYPE (`: Nat`) but the `reduce` (i.e.
`match` on a user data constructor) was never unfolded. So `1N` never
appears in the printed value.

**Cause.** The standard test-fixture pattern (copied from
`test-hashable-01.rkt`) captures `current-prelude-env`,
`current-trait-registry`, `current-impl-registry`,
`current-param-impl-registry`, and `current-module-registry` from the
preamble — but **not** `current-ctor-registry` or `current-type-meta`.

For built-in types (Nat, Bool, List, Option) this is fine because their
ctor info is set in the prelude module that's always loaded. But for
*user-defined* `data` types declared inside the preamble's imports —
in our case `Vat`, `Allocated`, `Actor`, `ActorEntry`, `PromiseEntry`,
`VatMsg`, `BehaviorTag`, `Effect`, `ActStep`, `SyrupValue`,
`PromiseState`, `CapTPOp` — the ctor info goes into the registry that
the fixture *captures into a parameter at setup time but does not
restore in `run`*. When the test then calls `(eval ...)`, the reducer
sees a fresh empty `current-ctor-registry`, treats `vat`, `allocated`
et al. as opaque applications, and refuses to fire any pattern arms
that use them.

**Why this hadn't surfaced before.** Existing tests that follow this
fixture pattern (`test-hashable-01.rkt`, `test-capability-01.rkt`,
…) only declare *traits* and *capabilities* in their preambles, not
new `data` types. The OCapN port appears to be the first stress test
of the fixture pattern with non-trivial new sums.

**Fix in tests.** Capture and restore the two extra parameters:

```racket
(define-values (...
                shared-ctor-reg
                shared-type-meta)
  (parameterize ([... (current-ctor-registry) ... (current-type-meta) ...])
    (process-string shared-preamble)
    (values ...
            (current-ctor-registry)
            (current-type-meta))))

(define (run s)
  (parameterize ([... 
                  [current-ctor-registry shared-ctor-reg]
                  [current-type-meta shared-type-meta]])
    (process-string s)))
```

Applied to all 8 OCapN test files via a Python sed — each gets a
`shared-ctor-reg` and `shared-type-meta` added to the `define-values`
list, captured at preamble time, restored in `run`.

**Verdict.** This is a real Prologos test-infrastructure bug. The
canonical fixture skeleton in `test-hashable-01.rkt` needs to grow
the two extra parameters; otherwise the next person who declares a
new `data` type in their preamble hits the same wall and the
diagnostic — "match form printed without reducing" — is genuinely
mysterious to anyone who hasn't seen it before.

Recommended fix: bake `current-ctor-registry`/`current-type-meta`
capture into `tests/test-support.rkt` so that all fixtures get it for
free (or document the requirement loudly in CLAUDE.md's testing
rules).

---

### #13 — `spawn` is a reserved syntactic form (2026-04-27)

**Symptom.** A user-defined function named `spawn` parses but fails
to elaborate calls to it:
```
"Cannot elaborate: #(struct:surf-spawn ...)"
```

**Cause.** `macros.rkt` reserves `spawn` (and `spawn-with`) at the
preparse layer:
```racket
[(and (pair? datum) (eq? head 'spawn))  ...]
```
so `(spawn ...)` is dispatched to the actor-spawn surface form, not
treated as application of a user-bound `spawn` function. Our
`vat.prologos` originally exported a `spawn` function — the test
parser silently rewrote every call site to `surf-spawn` and then
elaboration choked because the surface form expects a different
shape.

**Fix in this port.** Rename `spawn` → `vat-spawn` and `spawn-actor`
→ `vat-spawn-actor` everywhere (library + tests + acceptance file).

**Verdict.** This is a footgun, not a bug — the surface-syntax keyword
isn't documented as reserved in any user-facing place. A reserved-
words list in CLAUDE.md (or a clearer error message — "you cannot
declare a function with the reserved name `spawn`") would have saved
the diagnostic round.

Other names reserved by the same mechanism in `macros.rkt`:
`spawn`, `spawn-with`. Names *not* reserved but worth being
careful with: `send`, `receive`, `become` — they're session-types
keywords (`!`, `?`) under different surface forms but the symbol-
name `send` is currently free. We use it.

---

### #14 — `match | pair a b -> ...` on a `Sigma` returning a `Sigma` (2026-04-27)

**Symptom.** With this body:

```
spec send Nat SyrupValue Vat -> [Sigma [_ <Vat>] Nat]
defn send [target args v]
  match [fresh-promise v]
    | pair v1 pid ->
        pair [enqueue-msg [vmsg-deliver target args [some Nat pid]] v1] pid
```

elaboration emits `Type mismatch / could not infer` even though every
sub-expression has a clear type (or so it seems). Replacing the
result construction with a `the [Sigma [_ <Vat>] Nat] [pair ...]`
ascription does not fix it. Rewriting via `[fst r]` / `[snd r]`
(used twice on the same Sigma) trips QTT multiplicity.

**Workaround.** Replace the `Sigma Vat Nat` return type with a
named struct:

```
data Allocated
  allocated : Vat -> Nat

spec alloc-vat Allocated -> Vat
spec alloc-id  Allocated -> Nat
```

`spawn`, `fresh-promise`, and `send` all return `Allocated`. The
elaborator handles the named type without complaint.

**Diagnosis.** I'm not entirely sure where the inference fails — the
elaborated body printed by the error `<could not infer>` shows the
right shape with `[some Nat b]` (after we provided the type arg
explicitly). My best guess is that the implicit pair-of-Sigma
introduces a meta the elaborator can't pin down because the Sigma
is non-dependent (`[_ <T>]`) and the constructor doesn't carry
enough info from the use-site. Stdlib `defn split-at [n xs] pair
[take n xs] [drop n xs]` works, so it's not "Sigma in result
position is broken" — something specific to the *destructure-then-
reconstruct* shape we hit here.

**Verdict.** Probably worth a small repro for the Prologos team. Our
`Allocated` workaround is clean and what users would write anyway,
but the failure mode is silent and the error message ("could not
infer") doesn't point at the line.

---

### #15 — QTT linearity on `[fst p]` / `[snd p]` repeated (2026-04-27)

**Symptom.**

```
defn send [target args v]
  let r := [fresh-promise v]
    pair [enqueue-msg [vmsg-deliver target args [some Nat [snd r]]] [fst r]] [snd r]
```

raises a multiplicity-error: `r` is used three times (once each in
`[snd r]`, `[fst r]`, `[snd r]`).

**Why this is surprising.** Stdlib's `swap` does:
```
defn swap [p]
  pair [snd p] [fst p]
```
which uses `p` twice. So projection-twice clearly works in stdlib.
The third use is what breaks ours.

**Workaround.** Same as pitfall #14 — switch to a named struct and
use a `match | allocated x y -> ...` destructure that consumes once.

**Verdict.** Probably correct QTT behaviour given how `let r := ...`
binds at multiplicity 1, but composes badly with
"return both halves of a Sigma plus a derived value". A documented
multiplicity-aware `unpair p (fn v1 pid ...)` combinator in stdlib
would soften this — we ended up writing an actor-allocation-shaped
struct rather than fight inference.

---

### #16 — Forward references inside a `.prologos` module (2026-04-27)

**Symptom.** First version of `vat.prologos` had:
```
spec apply-effect Effect Vat -> Vat
defn apply-effect [e v]
  match e
    | eff-resolve pid val -> resolve-promise pid val v   ;; ← forward ref
    | ...

spec resolve-promise Nat SyrupValue Vat -> Vat   ;; ← defined later
defn resolve-promise [pid val v]
  ...
```

Loading the module reported `Unbound variable: resolve-promise` in
`apply-effect`'s body, then the same cascade for every later
function that references it.

**Cause.** Module elaboration is single-pass top-to-bottom; each
`defn` requires its callees to be already in scope. (Same as Prolog,
Standard ML core, etc. Not the same as Haskell or Racket.)

**Fix.** Reorder: `resolve-promise` and `break-promise` come before
`apply-effect` and `apply-effects`; `step-after-act` before
`deliver-msg`; `list-length-helper` before `queue-length`.

**Verdict.** Standard FP-language convention; documented here only
because the error message doesn't suggest "did you mean to define
this lower in the file?" and a beginner can spend a few minutes
checking imports before realising the dependency order is wrong.

---

### #17 — Promise-queue ↔ Vat-queue type mismatch (design pitfall, not a bug) (2026-04-27)

**Symptom.** First version of `vat.prologos`'s `resolve-promise`
flushed pipelined messages from the promise back to the vat queue:

```
[vat n acts proms-after [append q [take-queue s]]]
```

But `take-queue : PromiseState -> List SyrupValue` and the vat
queue is `List VatMsg`. The elaborator inserts `append`'s implicit
type arg as `VatMsg`, then balks because the second argument has
type `List SyrupValue`. Reported as a `Type mismatch / could not
infer` of the whole `resolve-promise` definition.

**Root cause.** Conceptual confusion: `pst-unresolved` carries the
*wire-level* representation of pipelined messages (Syrup values, what
a peer would send over the wire), but the local vat's queue holds
already-decoded `VatMsg` records. They are not interchangeable —
flushing requires re-encoding, which Phase 0 doesn't do.

**Fix.** Drop the flush. `resolve-promise` and `break-promise` no
longer try to migrate queued messages; they only update the promise
state. Pipelining still works for the FullFiller pattern (where the
actor itself emits an `eff-resolve` effect that the vat applies
directly). True over-the-wire pipelining is deferred to Phase 1.

**Verdict.** Honest scope cut. Documented in
`vat.prologos:resolve-promise` and the `core.prologos` top docstring.
