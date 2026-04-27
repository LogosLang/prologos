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

### #0 — [DELETED — out of scope]

Originally documented "no Racket toolchain in the sandbox." That's
an environment limitation, not a Prologos issue. Number reserved.

---

### #1 — Eventual-receive is a Phase 0 no-op (OCapN-side, NOT a Prologos bug) (2026-04-27)

**Status.** This is a deferred-implementation note, not a Prologos
language bug. Number kept for catalogue continuity.

**Where this matters.** OCapN promises require a delivery semantics
where `(<- refr msg)` enqueues a message and returns a promise that
*eventually* settles to the actor's reply. In our Phase 0:

- *Local* promise resolution works (the FullFiller pattern emits
  `eff-resolve` and the vat applies it on the next turn).
- *Cross-vat* eventual receive — i.e. the protocol-level "deliver
  this message to a refr you got from a peer, and route the reply
  back over CapTP" — is NOT implemented. Pipelined messages on a
  promise are queued at the PromiseState level but the vat does
  not flush them across resolution (see pitfall #17 for the
  type-level reason: PromiseState's queue carries Syrup wire form,
  vat queue carries decoded VatMsg).

**Implication.** The `core.prologos` `ask` function returns a
promise id but the only way that promise gets settled is if some
local actor explicitly emits `eff-resolve` for it. There's no
remote-deliver path yet.

**Open path to Phase 1.** Wire the netlayer ↔ vat bridge so that
inbound CapTP `op:deliver` messages on a connection turn into
`enqueue-msg` calls on the local vat, AND outbound `eff-resolve`
on a promise that has a remote resolver triggers an outbound
`op:listen`-reply on the originating connection.

---

### #2 — [DELETED — false claim, recanted] (2026-04-27)

Originally claimed `match | _ -> body` on user data types fails
type inference. **Tested 2026-04-27 with a real Racket and the
claim is false.** With a proper `spec` and the WS-mode form:

```
spec is-a-wild Foo -> Bool
defn is-a-wild [x]
  match x
    | a-of _ -> true
    | _      -> false
```

elaborates and evaluates correctly (`is-a-wild (a-of zero) ⇒ true`,
`is-a-wild (b-of zero) ⇒ false`). See
`probe-p2-wildcard.prologos` in the test session.

**What the prologos::data::datum comment actually meant.** The
in-source note about "explicit exhaustive patterns" is real for
*type-inference inside a polymorphic context*, not a blanket
wildcard ban. We over-generalised it into pitfall #2, then hit
unrelated `match` issues that we mis-attributed to the wildcard.
The behavior modules in `lib/prologos/ocapn/behavior.prologos`
should be cleaned up (~250 LOC → ~70 LOC) by switching the
constructor-by-constructor enumerations to `| _ -> no-op state`.

Number reserved. Cleanup tracked separately.

---

### #3 — [DELETED — false claim, recanted] (2026-04-27)

Originally claimed function-typed fields in `data` constructors
were unverified, forcing the closed-`BehaviorTag` enum approach.
**Tested 2026-04-27 with a real Racket and the claim is false.**

```
data Step
  step : [Nat -> Nat]    ;; bracketed function type — required so the
                          ;; data-ctor parser doesn't read this as
                          ;; "two Nat args returning Step"
```

elaborates cleanly, accepts `[fn [n : Nat] n]` and closures with
captured state, and the stored function applies correctly under
`match | step f -> [f n]`. Evidence:

```
def add3-step : Step := [make-add 3N]   ;; closure captures k=3
[run-step add3-step 1N]   ⇒  4N
[run-step add3-step 2N]   ⇒  5N
```

See `probe-p3-fnfield.prologos` in the test session.

**Implication for the OCapN port.** `behavior.prologos` should be
restructured: `data Behavior beh : [SyrupValue -> SyrupValue ->
ActStep]` replaces `BehaviorTag` and `step-behavior`. Open-world
user-defined actors become possible. Cleanup tracked separately;
the architecture in this commit still uses the closed enum because
that's what the original (incorrect) pitfall steered us into.

Number reserved.

---

### #4 — `rec` session continuation is in the grammar but not in the elaborator (2026-04-27, real bug)

**Symptom.** `grammar.ebnf` §6 lines 1153–1187 promise both `Mu`
(the sexp form) and `rec [label]` (the WS form) for recursive
session types. Try them:

```
session Loop
  ! Nat
  rec
```

Elaboration fails with:
```
prologos-error "Unknown session type: rec"
```

The sexp form `(session Loop2 (Send Nat (Mu End)))` fails the same
way:
```
prologos-error "Unknown session type: rec"
```
(grammar admits both `Mu` and `rec`; both unimplemented.)

**Why this matters for OCapN.** The CapTP wire protocol is a
multiplexed full-duplex stream of `op:*` messages — peers
interleave `op:deliver`, `op:listen`, `op:gc-export`, etc. until
one sends `op:abort`. The natural session is recursive:
`μX. &> {deliver:X, listen:X, abort:end}`. Without `rec`, a
single `session CapTPConn` can't capture stream-level
well-typedness; we have to settle for per-exchange sub-protocols.

**Workaround in this port.** `captp-session.prologos` decomposes
CapTP into FIVE finite sub-protocols (Handshake, Deliver, Listen,
DeliverOnly, Gc), each its own `session` declaration. A real
driver re-instantiates the appropriate sub-protocol per
exchange. Per-exchange typing remains, but stream-level
well-typedness is unproven.

**Filed as a Prologos bug.** The grammar documents `rec`/`Mu`;
the elaborator should accept it. Pointing at `surface-syntax.rkt`
or wherever the session-type elaborator lives would close the
gap. Until then, `MixedProto` style finite alternations are the
documented ceiling.

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

### #6 — [DELETED — out of scope]

WS-mode `let p := body` and sexp-mode `(let (p v) body)` are TWO
SURFACE FORMS by design (grammar.ebnf §7 line 1236). Mixing them
in a sexp test string is a user error, not a Prologos bug.
Number reserved.

---

### #7 — [DELETED — followed from #2 which was recanted] (2026-04-27)

This was a quantitative restatement of #2 ("constructor-by-
constructor enumerations are noisy"). With #2 recanted (wildcards
work), #7 also evaporates: the OCapN behavior modules can be
collapsed to wildcard-fallthrough form, dropping ~180 LOC.

Number reserved. Cleanup tracked separately.

---

### #8 — [DELETED — false claim, recanted] (2026-04-27)

Originally documented an avoidance: "we didn't put `Sigma` in
`data` ctor fields because we couldn't find a stdlib example."
**Tested 2026-04-27 with a real Racket and Sigma works fine in
data ctors:**

```
data Box1
  box1 : [Sigma [_ <Nat>] Bool]

data Table
  table : Nat -> [List [Sigma [_ <Nat>] Bool]]
```

both elaborate cleanly:
```
box1  : [Sigma Nat Bool] -> Box1
table : Nat [List [Sigma Nat Bool]] -> Table
```

See `probe-p8-sigma.prologos` in the test session.

**Implication for the port.** The named-struct `ActorEntry`/
`PromiseEntry` workaround in `vat.prologos` was unnecessary. Could
be simplified back to `[List [Sigma [_ <Nat>] Actor]]` and
`[List [Sigma [_ <Nat>] PromiseState]]`. Cleanup tracked
separately.

Number reserved.

---

### #9 — [DELETED — user error]

`def` is for value bindings, `defn` is for functions. The
distinction is documented (grammar.ebnf §3 lines 189–190 +
prologos-syntax rules). Mis-using `defn` for a 0-ary constant is
a usage error, not a Prologos bug. Number reserved.

---

### #10 — [DELETED — out of scope]

Originally noted "the sandbox can't reach codeberg / Racket
download mirrors." Network sandboxing is an environment
limitation, not a Prologos issue. Number reserved.

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

---

### #18 — Multi-arity `defn` with constructor patterns matches first arg only (2026-04-27)

**Symptom.** Wrote a 2-arg structural-equality function as

```
spec transport-eq? Transport Transport -> Bool
defn transport-eq?
  | tr-loopback         tr-loopback         -> true
  | tr-tcp-testing-only tr-tcp-testing-only -> true
  | tr-loopback         tr-tcp-testing-only -> false
  | tr-tcp-testing-only tr-loopback         -> false
```

`(transport-eq? tr-loopback tr-tcp-testing-only)` returned **true**.
The dispatcher matched only the FIRST argument's pattern (`tr-loopback`)
to the FIRST arm and then returned that arm's body, ignoring the
second argument.

**Cause.** Multi-arity `defn` (the `| pat -> body` shorthand without
explicit args) seems to dispatch on a single argument only. Stdlib
patterns reflect this — `is-zero` is the canonical 1-arg form;
nothing in stdlib's bool/etc. uses multi-pattern multi-arg `defn`.
Two-arg pattern functions are written as nested `match`:

```
defn transport-eq? [a b]
  match a
    | tr-loopback ->
        match b
          | tr-loopback         -> true
          | tr-tcp-testing-only -> false
    | tr-tcp-testing-only ->
        match b
          | tr-loopback         -> false
          | tr-tcp-testing-only -> true
```

**Verdict.** Likely a documented-but-easy-to-miss restriction. The
ergonomics of an Erlang-style multi-arg pattern dispatch would help
when porting. Not a blocking bug; recorded so the next person
doesn't step on it.

---

### #19 — TCP framing for testing-only is line-oriented (design pitfall)

**Symptom.** Endo's `tcp-test-only.js` does NOT define wire framing
itself — it streams raw bytes via `socket.write` and the higher
CapTP layer is responsible for length prefixing.

**Our choice.** For Phase 0 we use ONE-LINE-PER-MESSAGE framing in
`tcp-ffi.rkt`: each Syrup-encoded value is followed by `\n`; on
read, the receiver consumes one line via `read-line`. This keeps
the FFI minimal (no length-prefix code, no buffering ring needed).

**Limit.** Doesn't carry binary payloads — Syrup byte-strings could
contain `\n`. Phase 1 should swap line framing for length-prefixed
framing or for the canonical bytewise Syrup transport. Until then,
"tcp-testing-only" only carries the textual subset.

**Verdict.** Honest scope cut, named explicitly. Keeps the path to
Phase 1 short — only `tcp-ffi.rkt`'s `tcp-send-line`/`tcp-recv-line-ret`
need to change to length-prefixed primitives.

---

### #20 — `:requires (Cap)` annotation must be on same line as `foreign` (2026-04-27, ergonomics)

**Symptom.** Multi-line foreign declaration:

```
foreign racket "tcp-ffi.rkt"
  :requires (NetCap)
  [tcp-listen :as tcp-listen-raw : Nat -> Nat]
```

errors with:
```
foreign: Expected: (name [:as alias] : type), got: (:requires (NetCap))
```

**Cause.** The `foreign` parser expects keyword-tag pairs and
brackets on the *same line*. WS-mode line continuation isn't
applied here.

**Workaround.** Compress to one line per foreign:
```
foreign racket "tcp-ffi.rkt" :requires (NetCap) [tcp-listen :as tcp-listen-raw : Nat -> Nat]
```

**Verdict.** Cosmetic but annoying for libraries with long
type-signatures. Worth a parser fix to allow indented continuation
of a `foreign` form.
