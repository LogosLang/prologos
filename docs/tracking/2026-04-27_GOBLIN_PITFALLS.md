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

### #0 — [DELETED — out of scope: env limitation, not a Prologos issue]

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

### #2 — [DELETED — false claim: WS-mode wildcard match works correctly with a proper spec]

---

### #3 — [DELETED — false claim: function-typed `data` fields work with bracketed fn-type, e.g. `step : [Nat -> Nat]`]

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

### #6 — [DELETED — out of scope: WS-mode and sexp-mode `let` are two surface forms by design]

---

### #7 — [DELETED — followed from #2 which was false; wildcard fall-through obviates the noise]

---

### #8 — [DELETED — false claim: `Sigma` works in `data` ctor fields, e.g. `box1 : [Sigma [_ <Nat>] Bool]`]

---

### #9 — [DELETED — user error: `def` for values vs `defn` for functions is documented]

---

### #10 — [DELETED — out of scope: sandbox network limitation, not a Prologos issue]

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

### #15 — [DELETED — false claim: tested with `[fst p]`/`[snd p]` 3× on the same Sigma, no multiplicity error; the original failure was conflated with #14's destructure issue]

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

**Confirmed 2026-04-29.** During the syntax-idiom sweep
(commit `d65c6ac`) I converted `transport-eq?` to the multi-arity
form again (forgetting #18) and the full OCapN suite on Racket 9.1
caught it: 158/159, with the failure exactly at
`tests/test-ocapn-locator.rkt:80` — same call site
(`transport-eq? tr-loopback tr-tcp-testing-only` returns true).
Reverting the one function to the nested-match shape restored
159/159. The hazard is specific to clauses where BOTH positional
patterns are 0-arity constructors (e.g. `tr-loopback tr-loopback`)
across multiple alternatives — patterns where the second arg has
a constructor-with-fields (`| v [pst-unresolved _]`, `| state
[syrup-tagged tag p]`, `| [vat n acts proms q] m`) work correctly
in multi-arity form. The narrowing failure appears to be about
the pattern compiler treating leading bare 0-arity constructors as
variable bindings when they shadow nothing.

**Workaround crystallized.** Multi-arg cross-product over two
0-arity-ctor enums → write as nested `match`. Multi-arg with at
least one constructor-with-args pattern → multi-arity `defn` is
fine.

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

---

### #21 — Multi-line clause body silently produces `??__match-fail` holes (2026-04-29, real bug)

**Symptom.** A `defn` whose `match` clause body spans multiple
indented lines compiles without error but evaluates to
`??__match-fail : <return-type>`:

```prologos
defn encode [v]
  match v
    | syrup-null         -> "n"
    | syrup-bool b       ->
        match b
          | true  -> "t"
          | false -> "f"
    | syrup-string s     ->
        str::append [str::from-int [str::length s]]
                    [str::append "\"" s]    ;; 2-line body — BROKEN
    ...
```

`(eval (encode (syrup-string "hi")))` returns
`"??__match-fail : String"` even though the pattern clearly
matched.

**Cause.** Layout-rule interpretation of clause continuation. A
body that has its function head on one line and its argument
list on another is parsed as TWO separate forms, not one
application. The first becomes the body of the clause; the
second becomes some sort of layout-detached fragment that
elaborates to a hole.

**Workaround.** Either (a) collapse the body to a single line, or
(b) put the entire body on the line BELOW the `->`, indented
strictly past the `->`:

```prologos
;; (a) single line:
| syrup-string s -> str::append [str::from-int [str::length s]] [str::append "\"" s]

;; (b) body on its own line:
| syrup-string s ->
    str::append [str::from-int [str::length s]] [str::append "\"" s]
```

What does NOT work: head on `->` line, args on subsequent lines
at lesser indentation.

**Verdict.** Silent failure mode — no compile error, just a hole
masquerading as a value. The same hazard appears in the
clause-continuation example in `prologos-syntax.md` § "Multi-line
clause body" (which says the body must be indented past the `|`,
but that's necessary, not sufficient — multi-line continuation
of a multi-token application is the breaking case).

**Discovered.** Phase 1 of OCapN interop (commit `1ad3e60`) —
all encoder branches with multi-line bodies returned match-fail
sentinels. Took ~1 hour to diagnose because the symptom
(every branch falls through) hid the cause (layout
mis-parse of one specific body shape).

**Codify-it ask.** A diagnostic that flags "this clause body
elaborated to a hole" with a layout hint would close this gap.
The hole has the right type, so type-checking passes — only the
runtime sentinel reveals the bug.

---

### #22 — `Option Nat -> SyrupValue` parses as multi-arg Pi, not `(Option Nat) -> SyrupValue` (2026-04-29, real bug)

**Symptom.** A spec like

```prologos
spec opt-pos Option Nat -> SyrupValue
```

triggers `Type mismatch` at IMPORT time (not at elaboration of
the defining module), with no usable error context:

```
imports: Error loading module prologos::ocapn::captp-wire: Type mismatch
```

**Cause.** Without explicit brackets, `Option Nat -> SyrupValue`
is parsed as a 3-argument Pi `Option -> Nat -> SyrupValue`, not
as `[Option Nat] -> SyrupValue`. The mismatch surfaces only when
another module imports the function and tries to instantiate the
spec.

**Workaround.** Bracket the parametric type in the spec:

```prologos
spec opt-pos [Option Nat] -> SyrupValue
spec encode-safe SyrupValue -> [Option String]
spec decode-op String -> [Option CapTPOp]
```

This applies to ALL return / parameter positions where a type
constructor takes its own argument. `Option`, `List`, `Result`
etc. all need the brackets.

**Verdict.** Easy to miss because (a) the function elaborates
fine in its own module, (b) the import error message gives no
location or hint about which spec is wrong. Once you know the
fix it's mechanical, but the discovery cost is high.

**Discovered.** Phase 2 of OCapN interop (commit `50fc0c1`) —
six functions in `captp-wire.prologos` had unbracketed
`Option X` return types. The first failure narrowed the scope;
fixing them in one pass took 30 seconds.

**Codify-it ask.** A spec-level lint or just a less generic error
message ("Type mismatch in spec for `opt-pos`: parametric type
`Option` expected an argument; did you mean `[Option Nat]`?")
would eliminate this.

---

### #23 — Multi-token `defn` body on a single line needs outer `[…]` brackets (2026-04-29, real bug)

**Symptom.**

```prologos
defn desc-export [n] syrup-tagged "desc:export" [syrup-nat n]
```

triggers `Type mismatch` at import. The body `syrup-tagged "..." [syrup-nat n]`
is being parsed as something other than a 3-element application.

**Workaround.** Either (a) wrap the body in `[…]`:

```prologos
defn desc-export [n] [syrup-tagged "desc:export" [syrup-nat n]]
```

or (b) put the body on its own line, indented past the `[args]`
header:

```prologos
defn desc-export [n]
  syrup-tagged "desc:export" [syrup-nat n]
```

Both work. The single-line bare-juxtaposition form
`defn f [args] head a b c` does not.

**Cause.** Same family as #21 — WS-mode application is bracket-
delimited; bare juxtaposition needs an enclosing form to anchor
the parse.

**Verdict.** Silent error class — like #21 the failure is at
import (or evaluation), not at the `defn` itself.

**Discovered.** Phase 2 of OCapN interop (commit `50fc0c1`) —
multiple `desc-*` helpers in captp-wire.prologos had this shape.
Fixed by moving bodies to their own line.

---

### #24 — Phase-1 wire decoder asymmetry: `+` suffix produces `syrup-int`, never `syrup-nat` (2026-04-29, design choice)

**Context.** OCapN's Syrup wire format uses `<digits>"+"` for
non-negative integers and `<digits>"-"` for negatives. There is
no separate Nat wire form — Naturals are just non-negative
integers. So `(syrup-nat 5)` and `(syrup-int 5)` BOTH serialise
to `5+`.

**Symptom.** A round-trip `(decode (encode (syrup-nat 5)))`
returns `(syrup-int 5)`, not `(syrup-nat 5)`. Functions that
match on `syrup-nat` (via `get-nat`) fail to extract the value
from a decoded Nat-on-the-wire because the decoder always emits
`syrup-int`.

**Workaround.** Phase 2's `wire-nat` helper (in
`captp-wire.prologos`) accepts both `syrup-nat` and `syrup-int`
(when the int is ≥ 0) and bridges back to the model's Nat type
via a structural-recursion `int-to-nat` helper.

**Verdict.** Not a bug, but a subtle modelling tradeoff:
- pro: the wire is one-to-one with the byte sequence; encode is
  total over both Int and Nat
- con: round-tripping a `syrup-nat` doesn't preserve identity
- con: any decoder that wants Nat positions has to bridge

**Codify-it ask.** Either (a) drop `syrup-nat` from the value
type entirely (subsume into Int), or (b) make the decoder pick
syrup-nat for `+` suffix and syrup-int only for `-`. Either is
fine; the current asymmetry is just a minor wart.

**Discovered.** Phase 2 of OCapN interop (commit `50fc0c1`).

---

### #25 — Prologos `String` return values come back through the test fixture with print-escapes that need `read`-back (2026-04-29, ergonomics)

**Symptom.** A Phase 3 test that pulls the bytes of a Prologos
`encode-op` call into Racket-side TCP code got wire bytes with
literal `\"` instead of `"`:

```racket
(define wire-bytes (extract-value-bytes (run-last "(eval ...)")))
;; got: "<8'op:abort13\"phase-3-works>"   ;; 1 backslash + 1 quote
;; expected: "<8'op:abort13\"phase-3-works>"   ;; raw quote
```

**Cause.** The fixture's `run-last` returns the Prologos pretty-
printer output, which uses C-style escapes (`\"`, `\\`) for
String values. Naively stripping the `"..."` wrapper preserves
those escapes in the Racket string, so subsequent uses see
phantom backslashes.

**Workaround.** `read` the quoted form back as a Racket string
literal:

```racket
(define m (regexp-match #px"^(\".*\") : String$" s))
(read (open-input-string (cadr m)))   ;; round-trips the escapes
```

**Verdict.** Test-helper-level pitfall, not a Prologos bug —
the printer is doing the right thing (round-trippable output).
Worth codifying as a reusable helper in `test-support.rkt` if
more interop tests appear.

**Discovered.** Phase 3 of OCapN interop (commit `b4493a1`).
