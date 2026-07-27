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

## CHECKUP 2026-07-27 — status audit after merging 700 commits of `main`

Re-audit of this log after merging `origin/main` (branch point `68f4564f`,
2026-05-02 → main tip `9bff07ff`, 2026-07-22) into the OCapN branch, on
Racket 9.0. Read this section before trusting any entry below.

### What `main` fixed: nothing in this log

Of the 11 load-bearing items checked against main's 700 commits: **zero
were addressed.** This is a structural fact, not a search gap — main spent
the quarter on typing and the record/collection layer (CIU Track 6, 115
commits), propagator internals (PPN 4C, 167), Numerics (70), Rel T1 (36).
The four subsystems every bug here lives in — **WS reader/layout,
match-lowering, the elaborator's inference for `data`, and reducer
performance** — received no attention. Issues #45/#58/#60/#61 remain OPEN.
`PReduce` (the reducer replacement) is **docs-only**: DESIGN COMPLETE
2026-06-10, Tracks 1–9 not started.

So every workaround documented below is still required.

### Status corrections — entries in this log are STALE

- **#31 and #27 (decode perf) are substantially FIXED — by our own branch,
  not main.** Commit `4f6b3f0c` (2026-05-06, *two days after* #31 was
  logged) added `racket/prologos/loose-bvar.rkt` — a `looseBVarRange`
  short-circuit on `shift`. Recorded effect (`b9718184`):
  `test-bridge-perf` **~150 s → 16.7 s**, `test-reduction-perf-02-01`
  51 s → 7.9 s, `test-ocapn-vat` 158 s → 22.4 s. Re-measured here on the
  post-merge toolchain: the #31 repro (50-byte 4-arity `op:deliver` with two
  nested sub-records) decodes in **~1 s**, down from the logged 150,321 ms.
  Both entries still read as open BLOCKERs; they are not. **Residual: still
  ~100× slower than a real decoder (<10 ms), so it remains a
  throughput ceiling — but not a wall.**
  This fix is the recommended fix for upstream issue **#58** (O(N²)
  substitution blow-up), which is still open — worth filing there.
- **#11 (Racket 9 `thread #:pool 'own`)**: upstream issue #53 was **closed
  with no code fix** — Racket 9.0 is now the declared floor (`info.rkt`,
  all three CI workflows). Our `with-handlers` fence in `driver.rkt` survived
  the merge and is the *only* fence; keep it only if Racket 8 still matters.

### New findings from this checkup

1. **`.pnet` module cache is UNSOUND — silent wrong results.** Reproduced
   A/B, same script, only the cache differing:
   - cold (no `.pnet`): `(encode-op (op-abort "bye"))` → `"<8'op:abort3\"bye>" : String`, 5017 ms — **correct**
   - warm (43 `.pnet` files): same expression → **stuck `[reduce ...]` term**, 1308 ms — **wrong, no error**

   The cache makes loads ~3.8× faster and silently non-reducing. Any OCapN
   client using cached module loads gets functions that don't fire.
   **ROOT CAUSE FOUND — see entry #43 below.** It is a general Prologos
   compiler bug, not OCapN-specific, and it subsumes finding 2 (the
   transitive-import `BehaviorTag` degradation) as the same defect.
   **Highest-severity new item; not previously logged.**
2. **Transitive-import mis-elaboration, with a sharp diagnosis.** Importing
   `captp-core` alone (letting deps auto-load) yields
   `Hole ??__match-fail : ActStep`. Mechanism, now pinned: in
   `step-behavior : BehaviorTag SyrupValue SyrupValue -> ActStep`, the first
   parameter is elaborated as **`String`**, not `BehaviorTag`, so every
   `beh-*` constructor arm fails to match. Type identity for the locally
   declared `data BehaviorTag` is lost across the module-load boundary —
   unifying #12 (ctor registry lost → arms don't fire) and #33 (type
   identity via `:refer-all`) into one mechanism. Workaround: import the
   whole dependency tree as explicit top-level `imports` in dependency
   order (see `tools/interop/run-ocapn-test-server.rkt`). Main reworked this
   substrate (module-network cascade, Phase 4A/4B) for the *value/type*
   half; the **ctor-metadata half is untouched** (`d-ctor` sites in
   `driver.rkt`: zero commits).
3. **The merge broke our test harness: `current-prelude-env` was retired.**
   Commit `9d166ce4` (2026-06-01) deleted `current-prelude-env`,
   `current-module-definitions-content`, `current-definition-cells-content`
   as part of params→cells; main swept its own tests, ours were never swept.
   **37 OCapN test files + `tools/interop` still referenced it** and failed
   at load with `unbound identifier` — `raco setup` could not compile them,
   which took the whole interop CI job down before it ran anything. This is
   pitfall #12/#40's fixture fragility recurring a **third** time, now as a
   hard break.

   **RESOLVED (commit `4ae90b3c`).** An earlier revision of this entry
   claimed the shared-fixture pattern had "no supported replacement" and
   that the suite would need a full OCapN module load per test case. That
   was **wrong, and worth recording as a diagnosis error**: it reasoned
   from `test-support.rkt`'s exports (only `run-ns-*`, which builds a fresh
   mnr per call) instead of from the type. `module-network-ref` is an
   **immutable struct** (`namespace.rkt`, `#:transparent`, `struct-copy`-based),
   so it caches exactly like the retired env did. Probe before migrating:
   capture `(current-file-module-network-ref)` after the preamble load,
   re-parameterize it per test → **4.7 s load once, then ~140 ms/call,
   correct values**. The migration is 3 mechanical edits per file:

   ```
   [current-prelude-env (hasheq)] + [current-module-definitions-content (hasheq)]
     -> [current-file-module-network-ref (make-module-network)]
   (values (current-prelude-env) ...)  -> (values (current-file-module-network-ref) ...)
   [current-prelude-env  shared-global-env] -> [current-file-module-network-ref shared-global-env]
   ```

   Verified green in CI: all 12 `@endo/ocapn` cross-impl phases plus the
   Phase 58.c/58.d upstream-suite gate pass on the migrated suite.

   **Lesson**: "the extension point I used was retired" is not the same
   claim as "no extension point exists." Check the replacement's *type*
   before concluding a pattern is dead — the answer here was one probe away.

### The cost of the workarounds, measured

In the 6,424-line OCapN implementation:

| Cost | Count | Caused by |
|---|---|---|
| `defn`s in `captp-core.prologos` (helper-chain factoring) | 153 | #30, #16, nested-`match` import failures |
| explicit `[nil T]` / `[none T]` type-arg sites | 92 | #5, #32, #33 |
| hand-written exhaustive 11-constructor `SyrupValue` matches | 38 | closed-world `data` + #26 |

`captp-core.prologos` is 2,128 lines for what Goblins expresses far more
compactly; the delta is mostly these three columns.

### The honest blocker taxonomy

**(a) Architectural — will not be "fixed", must be designed around.**
The `## Scope` items: no mutation, no value-typed `Any`, closed-world
`data`. Consequence: the actor table cannot be `Refr → (Args -> Action)`,
so it is a compile-time `BehaviorTag` enum — a Prologos OCapN node can only
host behaviours enumerated when the compiler ran, which is in tension with
what a capability protocol is for. Adding the 4 remaining test objects
(Car Factory, Promise resolver, Sturdyref enlivener) means extending that
enum and re-running the AST pipeline.

**(b) Correctness-critical language bugs — silent wrong answers.**
#42 (pattern var silently resolves to an in-scope constructor — in a
*gift-deposit* handler, i.e. a capability being substituted for the wrong
value), #18 (multi-arity dispatch ignores the 2nd arg for 0-arity ctor
patterns), #37 (phantom 2nd parameter; `spec` is documentation, inferred
type wins), #21/#36 (layout → holes / silent wrong arity), plus new
finding 1 (`.pnet`). Five of these compile clean and misbehave later.
**Single highest-leverage upstream fix: hard-error when a `defn`'s inferred
type disagrees with its `spec`, and when a body elaborates to a hole.**
That one gate catches #21, #36, and #37 at the definition site.

**(c) Expressiveness gaps that forfeit the reason to use Prologos.**
#4 — `rec`/`Mu` session types are in the grammar but not the elaborator, so
CapTP (`μX. &> {deliver:X, listen:X, abort:end}`) must be decomposed into
finite sub-protocols and stream-level well-typedness is unproven. Session-typed
protocol conformance is the strongest argument for writing OCapN in
Prologos rather than Racket, and it cannot currently be cashed in.
#32 — sum types don't survive a module boundary, so the protocol's natural
`op:*` tagged union becomes single-constructor god-structs (this is *why*
`BridgeState` has 9 fields), which #36 then punishes with unbreakable
long lines.
#16 — single-pass modules, no mutual recursion, forced
`extract-refrs-from-args ↔ extract-refrs-from-list` to be broken with
`shallow-refr`: **deeply nested capabilities are not registered.** That is a
correctness reduction in the capability-extraction path, not an
inconvenience.

**(d) Throughput.** #27/#31 as corrected above: ~1 s per 50-byte frame.
Fine for tests, not for a node.

### Verdict

Nothing in the language now makes a *working* OCapN client impossible
except (c)#16's truncated capability extraction and the (a) closed-world
behaviour registry. The blockers to a *correct* one are the (b) silent-wrong
class, led by the new `.pnet` finding. The blocker to an *efficient* one is
no longer the reducer wall it was in May — it is a ~100× constant factor.
The blocker to *shipping* was prosaic and immediate — the suite could not
run until the fixture came off the retired `current-prelude-env`; that is
done (`4ae90b3c`) and interop CI is green again.

One structural caveat on that green: CI checks out fresh and `.pnet` is
gitignored, so **every CI run takes the cold path.** CI is therefore
constitutionally blind to new finding 1 (cache unsoundness) — a green
interop run does not clear it. Any gate for that bug has to populate the
cache first and then re-run.

---

## Pitfalls

(populated as encountered, newest first; each entry dated)

**Status flags added 2026-07-27** — see the CHECKUP section above before
relying on any entry: **#27, #31 are substantially FIXED** (by
`4f6b3f0c`, not by main); **#11**'s upstream issue was closed wontfix.
All other entries verified STILL OPEN against main as of `9bff07ff`.

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

---

### #26 — `syrup-tagged` model carries one payload, but OCapN records are arity-N (2026-04-29, real bug)

**Symptom.** Encoding `op:start-session "0.1" "tcp-testing-only:peer-A"`
through Phase 2's `op-to-syrup` produced

```
<16'op:start-session[3"0.128"tcp-testing-only:peer-A]>
```

— a record with ONE child, a list of two strings — instead of the
canonical OCapN form

```
<16'op:start-session3"0.128"tcp-testing-only:peer-A>
```

— a record with TWO children. The Phase 4 cross-impl byte-equality
test missed it because every Phase-4 vector was a 1-arity record.
The Phase 6 handshake test caught it the moment a real `@endo/ocapn`
peer tried to extract version + locator from the record's children
and got `null` for both fields.

**Cause.** `data SyrupValue` declares
`syrup-tagged : String -> SyrupValue`, i.e. one label and ONE
payload. The Phase-2 encoder packed multi-arg ops as
`(syrup-tagged label (syrup-list args))` which round-trips
through the Prologos decoder fine (the decoder's `decode-record-with`
explicitly wraps arity ≥ 2 records back into `(syrup-tagged label
(syrup-list rest))`) but emits the wrong wire bytes.

**Workaround applied.** Added `encode-record : String [List
SyrupValue] -> String` to `syrup-wire.prologos`. It produces
`<` + symbol(label) + concat(encode each arg) + `>` directly,
bypassing the syrup-tagged constructor for multi-arity cases.
Phase 2's `encode-op` now uses `encode-record` for the 5
multi-arity ops (start-session, deliver, deliver-only, listen,
gc-export) and keeps `wire::encode (syrup-tagged ...)` only for
the 1-arity ops (abort, gc-answer).

**Verdict.** Real bug in the model abstraction. The fix is
asymmetric — encode goes through a special path; decode wraps in
syrup-list. A cleaner future fix is to extend `data SyrupValue`
with an N-arity record constructor, e.g.
`syrup-record : String -> [List SyrupValue]`, and treat the
1-arity case as a syntactic sugar.

**Discovered.** Phase 6 of OCapN interop.

---

### #27 — Prologos `decode-op` is catastrophically slow on multi-arity records (2026-04-29, perf bug)

**Symptom.** Decoding a 60-byte op:start-session record via
`decode-op` takes **~7 minutes** of reducer wall time. The function
returns the correct value — the round-trip is sound — but takes
unbounded time per decode.

```
warmup encode-op...                 cpu time: 317 ms
decode short start-session...       cpu time: 454,832 ms
```

**Likely cause.** The decoder's recursive structure
(`decode-many-loop` calls `decode-at` per element, which calls
`decode-many-loop` for nested records, which closes over many
SyrupValue cons cells) interacts badly with the Prologos reducer's
beta-reduction strategy. Each decode step accumulates large
substituted closures, producing exponential-ish work.

**Workaround in this port.** Phase 6's bidirectional handshake
test asserts byte-equality directly (`their-line ==
expected-prologos-bytes`) instead of decoding the received bytes
via Prologos. Byte equality is a strictly stronger correctness
signal anyway: if the bytes match, both decoders trivially recover
the same SyrupValue.

**Verdict.** Real perf bug in the Prologos reducer (or the way
the decoder's recursion compiles to it). A proper fix needs
either a less-recursive decoder shape or compiler-level changes.
Not a blocker for interop validation — byte equality is the
preferred signal — but it would block any Prologos OCapN node
running in production.

**Discovered.** Phase 6 of OCapN interop.
The 1-arity round-trip path used in Phase 5's
`test-ocapn-live-interop.rkt` (op:abort, op:gc-answer) doesn't
exhibit the issue — only multi-arity records do.

**Profile data (2026-05-01).** Decode of `<3'tag5"hello>`
(1-arity record, 13 bytes): **~28s** consistently across 5
iterations, with 538 reduce_steps × ~52 ms/step. Decode of
`<16'op:start-session3"0.110"loc-string>` (3-arity record,
~40 bytes): **~270s**, with 763 reduce_steps × ~354 ms/step.
Resetting `reset-meta-store!` and `reset-constraint-store!`
between calls did NOT change the timing (so the cost is NOT
accumulation across calls). The cost is intrinsic to each
decode and grows super-linearly with record arity.

The likely culprit is the HOF self-reference: `decode-many-loop`
takes `decode-at` as an argument; the closure-substitution path
in the Prologos reducer compounds across recursive calls.
Combined with the 10-constructor pattern-match per
SyrupValue match, each step is doing ~52-354ms of work.

**Three lines of attack** (option 4 SHIPPED 2026-05-01):
1. Inline `decode-many-loop` into `decode-at` (eliminate HOF
   passing). Smallest scope; tests Prologos's HOF-substitution
   cost specifically.
2. Move decoder to Racket FFI primitive (one big function).
   Loses self-hosting purity.
3. Fix the reducer's closure-substitution hot path.
   Most principled but largest scope.
4. **(SHIPPED Phase 13)** Combine two pure-Prologos rewrites
   in syrup-wire.prologos:
   - Tail-recursive accumulator + `reverse` for `decode-many-loop`
     (was non-tail-rec head-cons recursion holding deep substitution
     chains).
   - Inline destructure of `Decoded` / `DecodedMany` structs at
     match position (`some [decoded v end] ->`) instead of
     accessor calls (`d-value` / `d-consumed`), which were each
     a separate pattern match per access.

   Measured speedup vs the baseline above:
   - 1-arity record:  28s → **4.5s** (6.2× faster)
   - 3-arity record: 270s → **10.8s** (25× faster)
   - decoder-using round-trip tests now run in <1 min instead
     of timing out the runner.

The remaining cost is still substantial (4.5s per 1-arity decode
is far slower than a function call should be) but the decoder is
now usable for bridge tests. Options 1/2/3 are still candidates
for further work if production loads emerge.

The 1-arity round-trip Phase-5 tests already tolerated the cost
(<10s per decode); Phase 6+ tests originally sidestepped via byte
equality but could now use decode-and-compare if desired.

---

### #28 — `@endo/ocapn` rejects `null` as a record child; use `false` for "absent" (2026-04-29, real interop bug)

**Symptom.** Phase 8's RPC test sent

```
<op:deliver <desc:export 0> 4"ping" <desc:answer 0> n>
```

— a 4-arity record where the resolver field is the Syrup `n`
(null) atom representing `none`. `@endo/ocapn`'s `decodeSyrup`
errors out at the first byte:

```
SyrupAnyCodec: read failed at index 0 of <unknown>
```

When the Node side then tried to encode its own reply with
`null` in the same position, the *encoder* failed too:

```
SyrupAnyCodec: write failed at index 43 of <unknown>
```

**Cause.** `@endo/ocapn`'s `AnyCodec` (in
`src/syrup/js-representation.js`) doesn't include `null` in
either its read-type-hint or write-type table. The `n` atom is
a valid wire byte but not a valid record-child *value* in
Endo's JS representation. The OCapN spec uses `false` (the
single-byte `f` atom) for "absent" sentinel positions.

**Workaround applied.**
- `captp-wire.prologos`'s `opt-pos` now emits
  `(syrup-bool false)` for `none`, not `syrup-null`.
- `unwrap-opt-desc` accepts both `syrup-bool false` and
  `syrup-null` for `none` (forward compatibility — older
  Prologos peers may still emit `null`).

**Verdict.** Real interop bug. Phase 4-7 didn't surface it
because none of those vectors exercised the resolver/answer-pos
absence in a record sent TO `@endo/ocapn`. Phase 8 (RPC)
hit it on the very first deliver.

**Discovered.** Phase 8 of OCapN interop.

---

### #29 — `break` from `prologos::ocapn::promise` collides with `prologos::data::list::break-helper` in sexp-mode resolution (2026-05-01, ergonomics)

**Symptom.** Calling `(break (syrup-string "oops") fresh)` in
sexp-mode (a test fixture context) inside a function that
expects a `PromiseState` — the resulting expression doesn't
reduce. The pretty-print shows
`[prologos::data::list::break-helper ?meta ...]` instead of
`[prologos::ocapn::promise::pst-broken ...]`. The wrong `break`
got picked up.

**Cause.** `prologos::data::list` (transitively imported via
`prologos::ocapn::core`) provides a `break-helper` and exposes
`break` as well. The sexp-mode test imports `core :refer-all`
which surfaces both. Symbol resolution preferentially picks the
list one.

**Workaround.** Use the constructor directly when constructing
test data: `(pst-broken reason)` instead of `(break reason fresh)`.
The constructor is unambiguous; only the convenience wrapper
`break` collides.

**Verdict.** Real ergonomics issue. Renaming `break` in
`promise.prologos` to `mark-broken` would resolve it. Or
namespace-qualified imports. Or making sexp-mode resolution
prefer the most-recently-required module.

**Discovered.** Phase 17 of OCapN interop — first time we
exercised broken-promise bytes encoding.

---

### #30 — `match` inside a 7+ binding `let`-chain triggers elaborator inference failure (2026-05-04, real bug)

**Symptom.** A driver expression in a test fixture that chains
~7 `let` bindings ending in a `match` expression fails to elaborate
with "Could not infer type" — every let-binding's parameter type
is held as an unsolved metavariable. Replacing the `match` with a
direct call (e.g., `unwrap-or default (nth zero list)`) makes
inference succeed; replacing with `length list` succeeds; replacing
the same shape with a top-level `defn` helper that wraps the
`match` succeeds. So the bug is specifically about an inline
`match` form sitting at the END of a deep let-chain, where the
outer binding types lack a forcing context.

**Repro.** This shape fails:

```
(eval (let (op1 (unwrap-or (op-abort \"d1\") (decode-op \"<10\\\"op:abort3\\\"bye>\")))
        (let (op2 (unwrap-or (op-abort \"d2\") (decode-op \"<10\\\"op:abort3\\\"bye>\")))
          (let (sa (vat-spawn-actor beh-echo syrup-null empty-vat))
            (let (cs0 (conn-state (alloc-vat sa) bridge-state-empty nil false))
              (let (step1 (connection-step op1 cs0))
                (let (step2 (connection-step op2 (conn-step-state step1)))
                  (let (all (append (conn-step-outbound step1) (conn-step-outbound step2)))
                    (match all                  ;; <-- elaborator can't solve metas
                      | nil       -> "NO-OUT"
                      | cons hd _ -> hd)))))))))
```

This same shape with `(length all)` instead of `match` succeeds.
This same shape with `(unwrap-or "NO" (nth zero all))` succeeds.

**Hypothesis.** The match form's type-checking goes through a
different inference path than ordinary function application. When
the surrounding context is a deep nested `let` (each binding
introduces a fresh metavariable), the match's type-driven
inference can't propagate downward to the outer let-bindings.
Function applications can — perhaps because they have a clearer
arg→result type relationship — so `unwrap-or` and `nth` succeed
where match fails.

**Workaround.** Two options:
1. Replace the `match` with a function call that has the same
   semantics — e.g., `unwrap-or default (nth zero list)` for
   "head with default."
2. Define a top-level `defn` that wraps the `match` and call it
   instead. The function's spec gives the type-checker an anchor
   it doesn't have for the inline match.

**Discovered.** Phase 24 of OCapN interop (bridge-driven responder
interop test). The driver expression initially used `match all |
nil -> default | cons hd _ -> hd` to extract the first outbound
byte string from a list of two `connection-step` calls. Replaced
with `unwrap-or default (nth zero ...)` and elaboration succeeded.

**Verdict.** Real Prologos elaborator bug. Workaround is cheap
(use a function instead of inline match in deep let-chains), but
the inference engine should handle this — match is supposed to be
a fundamental form. Worth filing a Prologos issue with this
specific repro. The shape generalizes beyond OCapN — any test
fixture using `process-string` to drive multi-step workflows could
hit this.

---

### #31 — `decode-op` on a 50-byte op:deliver takes ~150 SECONDS in `process-string` eval (2026-05-04, perf bug, MEASURED)

**MEASURED 2026-05-04**: `(eval (decode-op "<10'op:deliver<11'desc:export0+>5\"hello<11'desc:answer7+>f>"))`
in a `process-string` call took **150,321 ms (150 seconds)** for a
50-byte input. That's ~3ms per byte. A sane decoder for bytes-this-shaped
should complete in <10ms total. This is the underlying cause of all
"Phase 24 takes 8+ minutes" symptoms.

The result was correct:
~[some [op-deliver 0N "hello" [some Nat 7N] [none Nat]]]~ — i.e. the
decoder produces the right answer, just 1000x to 10000x slower than
expected. Diagnostic test: `tests/test-bridge-perf.rkt`.

**Symptom.** Phase 24's bridge-driven responder interop test
(`test-ocapn-bridge-interop.rkt`) drives the full bridge pipeline
on a Node-emitted `op:deliver` frame:

```
(let (op   (unwrap-or (op-abort "decode-failed") (decode-op <node-bytes>))
      sa   (vat-spawn-actor beh-echo syrup-null empty-vat)
      step (captp-incoming-with-state op (alloc-vat sa) bridge-state-empty)
      v2   (drain (suc^8 zero) (bridge-step-vat step))
      pr   (pump-outbound v2 (bridge-step-state step) nil))
  (unwrap-or "NO-OUTBOUND" (nth zero (pump-result-bytes pr))))
```

This expression evaluated via `process-string` exceeds **90s** of
Racket CPU time in the full elaboration + reduction loop. Existing
unit tests in `test-ocapn-bridge.rkt` that exercise the same chain
(e.g., "bridge/pump-outbound emits bytes when a question's promise
is fulfilled") with **hand-constructed** ops (not `decode-op`-
produced) complete in ~1s.

**Where the time goes** (now measured): the bottleneck is `decode-op`
itself, not the bridge. Confirmed by isolating each layer:
- `(eval (decode-op BYTES))` alone: ~150 seconds.
- `(eval (drive-echo-bridge-once <hand-coded-CapTPOp>))` (no decode):
  ~80 seconds in the first run with hand-coded ops.
- The combined chain `decode-op + bridge`: ≥ 8 minutes (killed at
  that point; never observed completing).

So decode-op contributes the lion's share of the cost. The bridge
itself (which involves comparable amounts of structural work — vat
event loop, question table, pump-outbound encoding) runs ~2× faster.

**Hypothesis on root cause** (unverified). `decode-op` is a
recursive parser in `lib/prologos/ocapn/captp-wire.prologos` that
calls `wire::decode-value` (defined in `syrup-wire.prologos`).
The parser uses position-threading via tuples, deep `match` chains,
and each parsed sub-value allocates a fresh `SyrupValue` ctor and
a position pair. Combined with the elaborator's reduction strategy
in `process-string`, that may produce O(n²) or worse reduction
behavior on the input string. The decoder's *output* is correct
(verified — produces the expected `op-deliver` shape); only its
*throughput* is broken.

**Investigation paths**:
1. Profile reduction inside `wire::decode-value` for inputs of
   length 10, 50, 100. If timing is super-linear in length, that
   confirms an algorithmic issue in the decoder's structural
   recursion under Prologos reduction.
2. Compare against `(eval (encode-op <hand-coded-op>))` timing.
   If encode is fast and decode is slow, the asymmetry is in how
   the elaborator handles parser combinators vs constructor
   applications.
3. Try a *flat* alternative decoder (e.g., a foreign Racket call
   that returns a `SyrupValue` directly), keeping `syrup-to-op`
   on the Prologos side. If that's fast, the problem is isolated
   to the byte-level parser, not the SyrupValue→CapTPOp conversion.

**Workaround for now.** Test stays in `.skip-tests`. Phase 24 ships
as scaffolding (Node peer + test skeleton + library helper +
diagnostic test + this pitfall). Live end-to-end gate deferred
to a Prologos decoder perf fix.

**Discovered.** Phase 24 of OCapN interop. The perf gap between
unit tests with hand-coded ops and a real interop test that decodes
Node-emitted bytes blocks the live bridge-driven test from being
the regression gate it could be.

**Verdict.** Real perf gap. Worth investigating because: (a) it
limits the interop test matrix; (b) once fixed, every protocol port
that uses `process-string`-driven test fixtures benefits; (c) the
gap signals something about how Prologos's reduction handles
decoder-produced expression trees that may matter for self-hosting.

---

### #32 — Multi-constructor `data` types break cross-module inference for callers using bound vars (2026-05-06, real bug)

**Symptom.** A `data` type with TWO OR MORE constructors (e.g.
`bridge-step` and `bridge-step-out`) compiles fine in its defining
module, BUT a caller in a DIFFERENT module that takes 2+ bound
arguments and passes them to a function returning that data type
fails to elaborate with "Could not infer type" — function-arg
types come back as `<_>` (uninferred metavars) even though the spec
declares them concretely.

**Repro skeleton.** Inside module `M1`:

```
data Step
  step     : Vat -> State            ;; ctor 1
  step-out : Vat -> State -> List String  ;; ctor 2

spec do-step Op Vat State -> Step
defn do-step | ... -> step v st       ;; or step-out v st bytes
```

Inside an importing module `M2`:

```
require [M1 :refer-all]

;; FAILS — "Could not infer type"
spec wrap Op Vat State -> Vat
defn wrap [op v st]
  let s := [do-step op v st]
    [step-vat s]
```

The 2-bound-arg form `wrap` cannot elaborate. Adding a typed let
(`let s : Step := ...`) doesn't help. Inlining doesn't help. Same
function inside `M1` itself works fine.

**Empirical evidence.** Discovered in OCapN Phase 25 (handshake
modelling, commit `4b92416`). I extended `BridgeStep` with a
second constructor `bridge-step-out` carrying immediate-outbound
bytes. The defining module `captp-bridge.prologos` continued to
compile cleanly — `connection-step` (which uses `bridge-step-vat`,
`bridge-step-state`, `bridge-step-immediate`) was fine. But the
importing module `bridge-interop-helpers.prologos` failed to define
EVERY multi-arg helper that called `captp-incoming-with-state` and
then unpacked the result — including 1-let-deep helpers, even with
explicit `: BridgeStep` annotations on the binding.

The probe matrix isolated it precisely:

| function shape                                            | defines? |
|-----------------------------------------------------------|----------|
| 1-arg + let + captp-call (constants for other args)       | yes      |
| 1-arg + let + captp-call (constant deps)                  | yes      |
| 2-arg + let + captp-call (1 bound + 1 constant)           | NO       |
| 3-arg + let + captp-call (3 bound)                        | NO       |
| 2-arg + INLINE + captp-call (no let, all bound)           | yes      |
| 2-arg + let + captp-call returning a SINGLE-ctor type     | yes (untested but consistent with reverting) |

The single-ctor-type case was the workaround. Reverting the
multi-constructor extension and putting the "immediate outbound"
field on the SINGLE-CONSTRUCTOR `BridgeState` instead made every
caller compile. So the multi-constructor return type, NOT the let
or the call shape, is the trigger.

**Hypothesis.** The elaborator's bidirectional inference for
function applications can't pin down the return type of a function
returning a multi-constructor data type when the call's arguments
include 2+ unsolved metavariables (the function-arg vars whose
types haven't been propagated from the spec yet). With a
single-constructor return type, the constructor's signature
uniquely determines the type, but with N constructors the
elaborator may delay the choice in a way that fails to back-propagate
through the let.

**Workaround.** Avoid multi-constructor data types when the
constructor's primary use is "value with optional extra payload."
Two options:

1. **Single constructor with all fields (some optional).** Add a
   `[List X]` or `[Option X]` field that's `nil` / `none` for the
   bare case. Trade-off: every caller now matches an extra field,
   but it's a wildcard. This is what `BridgeState`'s `pending-out`
   field does.

2. **Wrap the optional payload in a separate function.** Instead of
   "constructor with X" + "constructor without X," have a single
   constructor + a separate accumulator (e.g. a list field or a
   queue) that the producing function appends to.

**Discovered.** OCapN Phase 25, commit `4b92416`. Initial design
added `bridge-step-out v st [List String]` as a second constructor
to BridgeStep so the dispatch could carry "immediate outbound bytes."
Cost about 1 hour of probing the elaborator with shrinking test
cases before realizing the multi-constructor extension was the root.

**Verdict.** Real Prologos elaborator bug. The single-constructor
workaround (move the optional payload into the existing
single-constructor type as a list/option field) is uniformly
applicable and clean. Filed as [issue #60](https://github.com/LogosLang/prologos/issues/60)
because: (a) the catastrophic failure mode (cross-module callers
can't compile) is far enough from the surface cause (data type
definition in a DIFFERENT module) that it's hard to diagnose;
(b) multi-constructor data types are fundamental — it's a real
expressivity gap until fixed; (c) the workaround works but adds
field plumbing to every accessor and update function.

---

### #33 — `:refer-all` chains don't establish type identity for spec-level type-name resolution (2026-05-06, real bug)

**Symptom.** Module `M3` imports `M2` with `:refer-all`; `M2`
imports `M1` with `:refer-all`; `M1` defines a type `T`. When `M3`
writes a function spec mentioning `T`, then calls a function from
`M1` (or `M2`) whose return type is also `T`, the elaborator
reports a `Type mismatch [Pi … T]` against `[Pi … M1::T]` — same
type, different name resolution.

**Repro.** In OCapN Phase 25.4 (commit
[`f633e5a`](https://github.com/LogosLang/prologos/commit/f633e5a)).
`promise.prologos` defines `PromiseState`. `captp-bridge.prologos`
does `require [prologos::ocapn::promise :refer-all]` (so it can
use `PromiseState` and the `pst-*` constructors internally).
`bridge-interop-helpers.prologos` does `require
[prologos::ocapn::captp-bridge :refer-all]` (transitive).

```
spec lookup-after-step BridgeStep Nat -> [Option PromiseState]
defn lookup-after-step [step pid]
  lookup-promise pid [bridge-step-vat step]
```

`lookup-promise`'s spec is `Nat Vat -> Option PromiseState`. The
return-type annotation in the spec resolves `PromiseState`
(unqualified) via the `:refer-all` chain. The body's actual return
type comes from `lookup-promise` (defined in `vat.prologos`, also
`:refer-all`'d via captp-bridge), and its `PromiseState` resolves
to the fully-qualified `prologos::ocapn::promise::PromiseState`.

The elaborator says:

```
Type mismatch
  expected: [Pi [x BridgeStep] [Pi [y Nat] [Option PromiseState]]]
  got:      [Pi [x BridgeStep] [Pi [y Nat]
              [Option prologos::ocapn::promise::PromiseState]]]
```

Same type. Different name. Treated as distinct.

**Workaround.** Add an explicit re-import in the using module:

```
require [prologos::ocapn::promise
         :refer [PromiseState pst-unresolved pst-fulfilled pst-broken]]
```

With the explicit `:refer [PromiseState …]`, the spec's `PromiseState`
resolves to the same fully-qualified name as the body's, and the
type-equality check passes. The transitive `:refer-all` chain
doesn't establish this binding for the spec-level resolver.

**Hypothesis.** The `:refer-all` import re-exports terms but doesn't
re-establish bindings in the new module's "type-name resolution
table" for spec parsing. Specs are processed earlier than function
bodies and may use a different name-lookup scope. The transitive
case (`M1 :refer-all` chained through `M2 :refer-all`) compounds
the issue: `M3`'s spec parser doesn't see `T` until an explicit
`:refer [T]` is added.

**Discovered.** Phase 25.4, while wiring `verify-questioner-reply`
in bridge-interop-helpers.prologos. The original report was issue
[#60](https://github.com/LogosLang/prologos/issues/60) (multi-
constructor inference); this is a separate symptom that surfaced
during the workaround. Adding the explicit `:refer [PromiseState …]`
unblocked the function definition in <1 minute once diagnosed.

**Verdict.** Real, but lower-impact than #60 because the workaround
is a 1-line import addition. Filed as
[issue #61](https://github.com/LogosLang/prologos/issues/61) because:
(a) the error message ("Type mismatch [Pi T] vs [Pi qualified::T]")
is confusing — the names look identical at first glance;
(b) `:refer-all` chains are a common shortcut in Prologos library
modules, and any downstream user pattern-matching or returning a
parametric type from a chained module will hit this; (c) fixing it
would let `:refer-all` Just Work as expected.

---

### #34 — `data` constructor signatures have IMPLICIT return type (2026-05-06, real ergonomics bug)

**Symptom.** A user writes the natural-looking `data` declaration:

```
data Refr
  refr : Nat -> Nat -> Refr        ;; "takes 2 Nats, returns Refr"
```

…intending the type signature to be the FULL function type. The
elaborator silently treats this as a 3-ARGUMENT constructor:
`(Nat, Nat, Refr) -> Refr`. Smart constructors that try to apply
`refr` to two Nats then fail with a confusing error message.

**Repro.** From OCapN Phase 34a (commit `3d8c069`'s pre-fix state).
With the over-specified `refr : Nat -> Nat -> Refr`, this smart
constructor:

```
spec refr-local-export Nat -> Refr
defn refr-local-export [n]
  refr refr-kind-local-export n
```

Failed with:

```
Type mismatch
  expected: [Pi [x <Nat>] Refr]
  got:      [Pi [x <Nat>] Refr -> Refr]
```

The "got" type reveals the elaborator inferred the body's return
type as `Refr -> Refr` — i.e., applying `refr` to two Nats returned
something that needs ANOTHER Refr argument.

**Root cause.** Prologos's `data` constructor signatures use the
syntax `ctor : T1 -> T2 -> ... -> Tn`, where the FINAL return type
(the data type itself) is **implicit**. The Tn slot is always the
LAST ARGUMENT, not the return type. Existing examples in the
codebase follow this convention:

```
;; Listener carries (target, resolver-pos), 2 Nat args:
data Listener
  listener : Nat -> Nat               ;; takes 2 Nats, returns Listener

;; QEntry carries (key, value), 2 Nat args:
data QEntry
  q-entry : Nat -> Nat                ;; takes 2 Nats, returns QEntry
```

If you want `refr` to take 2 Nats, write `refr : Nat -> Nat`. The
return type `Refr` is implicit.

**Fix.** Drop the trailing `-> ResultType`:

```
data Refr
  refr : Nat -> Nat                   ;; CORRECT: 2 Nat args, returns Refr
```

**Workaround value.** A single-line edit fixes the data def. The
hard part is recognizing the symptom — the "Pi … -> Refr -> Refr"
error doesn't say "you over-specified the return type."

**Discovered.** OCapN Phase 34a (2026-05-06). Cost ~15 minutes
of debugging when the smart constructors all failed with the
"Type mismatch" error. Diagnosed by comparing my data def to
existing data types in the same file (`Listener`, `QEntry`) which
follow the implicit-return convention.

**Verdict.** Real ergonomic bug — the syntax is misleading. In
many ML/Haskell-family languages, `ctor : T1 -> T2 -> Result` IS
the full type. Prologos diverges. Either (a) accept the explicit
form (e.g., parse `refr : Nat -> Nat -> Refr` correctly); or
(b) better error message ("data constructor signature should not
include the data type as the last argument; the return type is
implicit"). For now, document the convention and follow existing
code patterns.

---

### #35 — Function names containing `->` silently fail to compile (2026-05-06, real bug)

**Symptom.** A function definition with `->` in its name (e.g.
`refr->syrup`, mimicking common ML/Lisp naming convention) is
silently **dropped** by the elaborator. No error message, no
"defined" message in the elaboration output — the binding just
doesn't exist. Callers get an "Unbound variable" error.

**Repro.** From OCapN Phase 34d (commit `7c797e6`'s pre-fix state):

```
spec refr->syrup Refr -> SyrupValue
defn refr->syrup [r]
  match [refr-export-kind? r]
    | true  -> [syrup-tagged "desc:export" [syrup-nat [refr-id r]]]
    | false -> [syrup-tagged "desc:answer" [syrup-nat [refr-id r]]]
```

Looks fine. Compile-and-list-defs output shows `refr-export-kind?`
defined right before, then jumps to `bridge-state-empty` after.
`refr->syrup` is silently absent. Callers in test code get:

```
Unbound variable: 'refr->syrup
```

**Root cause.** Prologos's WS-mode reader parses `->` as the
function-arrow type operator. When `->` appears INSIDE an
identifier, the reader splits the identifier at the arrow.
`refr->syrup` is read as `refr -> syrup` — a malformed type
expression in identifier position. The `spec` and `defn` forms
then can't bind anything sensible and silently drop.

**Fix.** Don't use `->` in identifiers. Use `to`, `_to_`, or just
a hyphen:

```
spec refr-to-syrup Refr -> SyrupValue       ;; CORRECT
spec refr-to-bytes Refr -> String
spec refr-from-syrup SyrupValue -> Option Refr
```

The `to` convention is what the rest of this codebase uses (e.g.
`syrup-to-op`, `op-to-syrup`).

**Workaround value.** Trivial rename. Hard part is diagnosis: no
error message, just "Unbound variable" downstream.

**Discovered.** OCapN Phase 34d (2026-05-06). Cost ~15 minutes —
diagnosed by:
1. Verifying spec/defn syntax was correct (it was).
2. Verifying the function name didn't collide with an existing
   binding (it didn't).
3. Wondering if special characters in names were the issue.
4. Renaming to `refr-to-syrup` — Just Worked.

**Verdict.** Real Prologos reader/elaborator bug. The silent-drop
behavior is the worst part — even a generic "syntax error in
identifier" warning would have caught this in 30 seconds. Reader
should either: (a) accept `->` in identifiers (treat `refr->syrup`
as one symbol); or (b) raise a syntax error pointing at the
offending identifier.

For now: codebase convention is to never use `->` in identifiers.
Use `-to-` or similar. The Common Lisp / Scheme convention of
`x->y` for converters is incompatible with Prologos's reader.

---

### Recurrences during Phase 34 (2026-05-06, no new pitfall — confirms existing entries)

For the record, Phase 34 hit several PRE-EXISTING pitfalls multiple
times. Each occurrence confirmed the entry is still correct and
the workaround still works:

- **Pitfall #18** (multi-arity defn with constructor patterns).
  Hit again on `defn add | zero b -> b | suc a b -> ...`. The
  `suc a b` parses ambiguously; brackets fix it: `[suc a] b -> ...`.
  Codified the bracket convention more strongly in commit messages.

- **Pitfall #21** (multi-line clause body silently produces
  `??__match-fail`). Hit on `defn extract-refrs-from-list |
  [cons hd tl] ->\n      [append ...]`. Worked around with the
  bracketed-arg + inline `match` form (`defn name [xs] (match xs
  | nil -> ... | cons hd tl -> body)`), which is the same shape
  as `data/list`'s `concat`.

- **Pitfall #16** (forward references / mutual recursion). Hit on
  `extract-refrs-from-args ↔ extract-refrs-from-list`. Worked
  around by making the inner walker call only `shallow-refr`
  (non-recursive) so the recursion is one-way. Trade-off: one
  level of list walking instead of full tree.

- **Issue #60** (multi-constructor cross-module inference). Hit
  on multi-arg helpers calling `captp-incoming-with-state`. Worked
  around by pulling helpers down to 2-3 args via `BridgeStep`.

---

### #36 — Multi-line constructor / function application: continuation args eaten as inner application (2026-05-08, real bug)

**Symptom.** Calling a constructor or function with N args, where
the args are split across multiple lines, parses the *continuation*
args as a single nested application instead of N separate args:

```prologos
;; 9-field BridgeState constructor split across two lines
defn bs-gc-listeners-by-notified
  | notified [bridge-state ls es as qs p oqs ir er pm] ->
      bridge-state [list-filter-listeners-by-notified ls notified]
                   es as qs p oqs ir er pm                  ;; ← BROKEN
```

The body call gets parsed as `bridge-state` applied to TWO args:
the first `[list-filter-listeners-by-notified ls notified]`, and
the second `[es as qs p oqs ir er pm]` (an APPLICATION
of `es` to seven args). `defn` then defines `bs-gc-listeners-by-
notified` with the wrong arity, and downstream callers report
`Unbound variable: bs-gc-listeners-by-notified` (because the def
silently failed to bind anything sensible).

The same pattern bit Phase 41 with the 9-field `bridge-state`
reconstruction in `bs-add-pipeline-msg` — solved at the time by
putting `er` and `pm` on separate lines, which happens to work,
but the load-bearing constraint is "all positional args on the
SAME line as the function head."

**Workaround.** Inline ALL positional args of a multi-arg call onto
the same line as the function head:

```prologos
defn bs-gc-listeners-by-notified
  | notified [bridge-state ls es as qs p oqs ir er pm] ->
      bridge-state [list-filter-listeners-by-notified ls notified] es as qs p oqs ir er pm
```

If the line is too long, break BEFORE a non-positional sub-application
(the bracketed call) instead of mid-positional-list. The pre-existing
`bs-gc-pipelined-msgs-by-emitted` works because the bracketed sub-call
appears LAST and the trailing arg is the only continuation:

```prologos
defn bs-gc-pipelined-msgs-by-emitted
  | emitted [bridge-state ls es as qs p oqs ir er pm] ->
      bridge-state ls es as qs p oqs ir er
        [list-filter-pipe-by-emitted pm emitted]                 ;; OK — the sub-call is the last arg
```

What does NOT work: a continuation line whose first token is a
plain identifier (like `es as qs p oqs ir er pm` above) — it gets
read as a fresh application.

**Cause.** Layout-rule interpretation of multi-arg application.
The reader treats the continuation line as a fresh expression
because layout indent groups it as a sibling form, not a
continuation of the parent argument list. Possibly fixable by
having WS-mode require explicit `\` continuation or by detecting
"line starts at greater indent than the function head" and
treating it as continuation — neither is currently the rule.

**Diagnosis.** Silent until you hit "Unbound variable" downstream
or a runtime arity mismatch ("Too many arguments to X" with the
wrong count, e.g. "given 4, expected 3"). The failure cascades:
the broken `defn` doesn't bind, so every caller — including in
test files — reports the function as unbound.

**Discovered.** OCapN Phase 48 (2026-05-08, commit `a990e2f`).
~10 minutes diagnosis after seeing repeated `Unbound variable:
bs-gc-listeners-by-notified` errors despite the spec/defn pair
being syntactically well-formed. Cleared by inspecting the elaborated
body in `process-file` debug output: `[bridge-state [filter] [es as qs ...]]`
— two args, not nine, made the bug visible.

**Verdict.** Real WS-mode reader/parser bug. The silent-drop
behavior is the worst part. Recommended fix: a "continuation lines
must start at less-than-or-equal indent" rule, or a syntax error
when a `defn` body produces a malformed term.

For now: any multi-arg constructor/function call must inline all
positional args onto the function-head line. If the line gets long,
break BEFORE a bracketed sub-application (the last arg), not
mid-args.

---

### #37 — Single-arg multi-arity `defn` over `data` patterns sometimes infers a phantom 2nd parameter (2026-05-08, real bug)

**Symptom.** Defined a 1-arg helper that destructures a single
`PromiseState`:

```prologos
spec resolution-syrup-of-pst PromiseState -> [Option SyrupValue]
defn resolution-syrup-of-pst
  | [pst-unresolved _] -> none
  | [pst-broken     r] -> some [wrap-error r]
  | [pst-fulfilled  v] -> some v
```

The elaboration trace reported the inferred type as

```
resolution-syrup-of-pst : PromiseState SyrupValue -> [Option SyrupValue]
```

i.e. **two** args, not one — the spec annotation was apparently
ignored. Callers that pass one arg got "Unbound variable" downstream
because the elaborator's view of the function arity didn't match
the call sites.

The IDENTICAL surface shape works in `outbound-from-resolution`
(in the same module) — the difference is that `outbound-from-resolution`
has TWO patterns per clause, so the multi-arity dispatcher isn't
reduced to "one pattern per clause":

```prologos
spec outbound-from-resolution Nat PromiseState -> [Option String]
defn outbound-from-resolution
  | _   [pst-unresolved _] -> none                       ;; OK — 2 patterns
  | pid [pst-broken     r] -> some [outbound-deliver-bytes pid [wrap-error r]]
  | pid [pst-fulfilled  v] -> some [outbound-deliver-bytes pid v]
```

**Workaround.** Switch to the explicit-bound + `match` form. Same
semantics, correct inferred type:

```prologos
spec resolution-syrup-of-pst PromiseState -> [Option SyrupValue]
defn resolution-syrup-of-pst [pst]
  match pst
    | pst-unresolved _ -> none
    | pst-broken     r -> some [wrap-error r]
    | pst-fulfilled  v -> some v
```

This pinned the inferred type to `PromiseState -> [Option SyrupValue]`
(matching the spec). The trace's body-form differs too: the working
`match` form produces `[fn [x ...] [reduce x ...]]`; the broken
multi-arity form produced an extra `fn` wrapper that picked up an
extra inferred parameter from the body.

**Cause.** Speculative — narrowing-style multi-arity `defn` with
exactly one pattern per clause (and the patterns being 1-arg `data`
constructors) seems to cause the elaborator to lift one of the body
expressions' free-floating type parameters into an additional pi
binder. The first clause's `none` (which has type `Option a` with
unsolved `a`) appears related: when `a` doesn't get pinned by a
bracketed type annotation (`[none SyrupValue]` is what the existing
`outbound-from-resolution` uses on bare-`none`-style clauses, but
through `some [outbound-deliver-bytes ...]` with a String result),
the elaborator may be solving `a` against the wrong context.

**Confirmed isolation.** Tried `[none SyrupValue]` (the explicit
type-annotated form) in the multi-arity `resolution-syrup-of-pst`
body: same phantom-arg result. Only switching to `defn name [pst]
match pst | ...` cleared it. So the bug is specifically in the
multi-arity-with-one-pattern shape, not in `none`'s type inference.

**Discovered.** OCapN Phase 48 (2026-05-08, commit `a990e2f`).
~5 minutes diagnosis. Cost-bearing because the cascading "Unbound
variable" errors were misleading — the helper *was* defined, just
with the wrong arity, so callers like `pump-one` couldn't link.

**Verdict.** Real elaborator bug. Workaround is mechanical (switch
to `match` form), but the silent-bad-arity behavior is the dangerous
part. Recommended: when a `defn`'s inferred type doesn't match its
spec annotation, raise a hard error. Currently the spec is treated
as documentation; the inferred type wins.

For now: when writing a 1-arg `defn` that destructures a `data`
type with multiple constructors, prefer the `defn name [arg] match
arg | ...` form over `defn name | [pat1] -> ... | [pat2] -> ...`.
For 2+ args, the multi-arity form is fine (per #18 caveats).

---

### #38 — `let X := EXPR` body can't span multiple lines (2026-05-08, real bug)

**Symptom.** A `let` binding whose value expression spans multiple
lines silently fails parsing. The error is specifically:

```
let: let :=: missing value after := for step2
```

even though there IS a value — it just continues onto the next line:

```prologos
;; BROKEN:
let step1 := [captp-incoming-with-state op1 [alloc-vat sa]
               [bridge-state-with-our-session our-ver our-loc]]
  let step2 := ...
```

The reader sees `step1 :=` then a layout-detached fragment
starting with `[captp-incoming-with-state ...]` whose continuation
on the next line `[bridge-state-with-our-session ...]` it parses
as a SIBLING let-binding rather than a continuation of step1's
value. By the time it gets to `let step2 :=`, the parser is in
a state where it's expecting a value for step2 and sees nothing.

The error message is misleading because the line that "lacks a
value" (step2) is fine — the actual broken line is step1, the
continuation of which has been misclassified.

**Workaround.** Inline the value onto a single line per `let`
binding. If the value is too long, factor a sub-expression into a
nested `let` or a top-level helper:

```prologos
;; OK:
let step1 := [captp-incoming-with-state op1 [alloc-vat sa] [bridge-state-with-our-session our-ver our-loc]]
  let step2 := [captp-incoming-with-state op2 [bridge-step-vat step1] [bridge-step-state step1]]
    ...
```

What does NOT work: a `let X := [foo arg1` on one line, `arg2]`
on the next, even if the second line is indented past the `:=`.

**Relation to #21.** Same root cause shape as #21 (multi-line
clause body produces match-fail) — both are about WS-mode layout
not propagating multi-arg application across lines. Different
binding form (`let` vs `defn` clause body), same fix (collapse to
one line). Worth recording as a separate entry because the error
message is different (a hard error here, a silent runtime hole in
#21) and the workarounds are slightly different (you can split a
clause body by putting the body on the LINE BELOW the `->`; with
`let X := EXPR` the binder and value share a line and you can't
break in between).

**Discovered.** OCapN Phase 49 (2026-05-08, commit `532a1e4`),
adding `drive-break-with-two-ops` to bridge-interop-helpers.
~5 minutes diagnosis after the misleading "missing value after :="
error pointed at the wrong line. Realised the previous let's value
was multi-line and inlined it; problem cleared.

**Verdict.** Real WS-mode reader bug, of the same family as #21
and #36. Continuation lines for multi-arg applications don't
work in any of the binding contexts (clause body, `let` value,
multi-arg ctor application). Workaround is mechanical (one line)
but ergonomically poor for verbose function calls.

For now: `let X := EXPR` value must fit on one line; if it
doesn't, factor a sub-expression to a separate `let` or top-level
helper.

---

### Recurrences during Phase 47-49 (2026-05-08, no new pitfall — confirms existing entries)

For the record, the Phase 47/48/49 OCapN work hit two PRE-EXISTING
pitfalls multiple times:

- **Pitfall #16** (forward references). Hit when adding
  `list-filter-pipe-by-emitted` near the bridge's GC helpers — it
  used `member-nat?` defined later in the same file. The GC helpers
  had to be moved to AFTER `member-nat?`'s definition. Standard
  one-pass FP language convention; entry already has it correctly.

- **Pitfall #36 ↔ #38** the multi-line continuation hazards
  recurred multiple times across Phase 47 (`bs-gc-pipelined-msgs-
  by-emitted` initially split fields; collapsed before commit) and
  Phase 49 (`drive-break-with-two-ops` initial form had multi-line
  `let` values). Both classes of bug have the same workaround:
  inline to one line.

---

### #39 — `rackunit`'s `check-true` is strict for `#t`, NOT truthy (2026-05-18, real ergonomics gotcha)

**Symptom.** Wrote tests like

```racket
(check-true (assq ':pipeline branches) "Choice has :pipeline branch")
```

This fails with `FAILURE: params: (list (cons ':pipeline ...))` even
though `assq` clearly returned the matching pair `(:pipeline . send...)`,
which is a truthy value in Racket.

**Root cause.** `rackunit/check-true` requires the value to be exactly
`#t`. A non-`#f` value that isn't `#t` (e.g., a pair, a string, a
struct) is treated as a failure. The standard Racket idiom of relying
on truthy/falsy doesn't apply.

**Workaround.** Either use `check-not-false`, or coerce to bool:

```racket
;; (a) preferred — semantically clear:
(check-not-false (assq ':pipeline branches) "Choice has :pipeline branch")

;; (b) coerce — works but obscures intent:
(check-true (and (assq ':pipeline branches) #t) "Choice has :pipeline branch")
```

**Diagnosis.** The failure report shows `params: <the-value>` which
*looks* like the value should be truthy. A reader who doesn't know
rackunit's strictness assumes the value is somehow #f and goes
searching for a bug in the code under test. The bug is in the test
infrastructure choice.

**Discovered.** OCapN protocols (Phase 53, 2026-05-18). Cost
~5 minutes after staring at the params display thinking the assq
itself was returning a malformed list. Resolved by switching to
`(and (assq ...) #t)` pattern (matches existing `test-io-session-02`
and `test-session-throws-01` conventions in this repo).

**Verdict.** This is documented rackunit behaviour, not a Racket /
Prologos bug. Recording it here because it's surprising for anyone
coming from a check-truthy framework. Pattern to remember: when
your `check-true` fails with the params display showing a clearly-
truthy value, switch to `check-not-false`.

---

### #40 — `prelude-module-registry` + `current-multi-defn-registry` aren't auto-exported with `test-support.rkt` (2026-05-18, real ergonomics)

**Symptom.** Wrote a new test file modelled after existing fixture
patterns. Got two cascading errors:

```
prelude-module-registry: unbound identifier
;; ... add (require "test-support.rkt") ...
current-multi-defn-registry: unbound identifier
```

Even with `(require "test-support.rkt")`, `current-multi-defn-registry`
wasn't found. Both identifiers are needed by the canonical
`parameterize`-everything fixture pattern that
`test-ocapn-bridge.rkt`, `test-ocapn-pipeline-forwarding-interop.rkt`,
etc. use.

**Root cause.** `prelude-module-registry` IS exported by
`test-support.rkt`. `current-multi-defn-registry` is exported by
`multi-dispatch.rkt`. They live in different modules and you have
to require both. Failing to require either gives the unbound-
identifier message.

**Workaround.** Always include both requires:

```racket
(require rackunit
         racket/list
         "test-support.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../sessions.rkt"
         "../macros.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt"
         "../multi-dispatch.rkt")   ;; ← easy to miss
```

The existing fixture pattern (test-ocapn-bridge.rkt and friends)
imports both; copying the require block as-is from a known-good test
sidesteps this.

**Discovered.** OCapN protocols (Phase 53, 2026-05-18). Cost
~3 minutes following the cascade of "unbound identifier" errors.

**Verdict.** Not a bug per se, but a discoverability gap.
`test-support.rkt` could re-export `current-multi-defn-registry`
to make the import list shorter, OR there could be a
`tests/test-fixture.rkt` umbrella that re-exports the entire
canonical fixture surface so new test files just need one import.
Filed as ergonomic improvement, low priority.

---

### #41 — WS-mode session bodies need `! T -> end` chained right, not parenthesised (2026-05-18, ergonomics)

**Observation.** WS-mode session syntax (`! T -> ? T -> end`)
desugars left-to-right via `->`:

```
! String -> ? String -> end
;; parses as (Send String (Recv String End)), which is correct.
```

This works perfectly for linear sessions. But for nested choice
branches each branch body is also a `->`-chain:

```prologos
+>
  | :read-all  -> ? String -> end
  | :read-line -> ? String -> rec
  | :close     -> end
```

The first `->` is the label-to-body separator; subsequent `->`s
are session chaining within the body. This works because the parser
treats `:label ->` specially.

What can go wrong: putting EXTRA spaces inside a branch line to
align labels visually (`| :pipeline  -> ! ...` vs
`| :await    -> ? ...`) — this is fine and parses identically.
The extra whitespace is purely cosmetic.

What canNOT work: trying to use parens to group a branch body
explicitly (`| :foo -> (! T -> end)`) — Prologos sessions don't
support parenthesised inner expressions; the `->` chain is implicit.

**Verdict.** Not a bug. Documenting because the syntax is
unfamiliar to those coming from `pi-calculus`-style ASCII session
notation. The full grammar is in `racket/prologos/macros.rkt`
around line 1306+ (`parse-session-body`).

---

### #43 — `.pnet` cache-hit restore writes parameters but not cells, so every restored registry is invisible (2026-07-27, real bug, **most severe in this log**)

**Symptom range**, all from one defect, depending on which modules in the
tree are cache hits vs fresh elaborations:

1. silent stuck term — `(encode-op (op-abort "bye"))` returns
   `[reduce [op-abort "bye"] | op-start-session x y -> ...]` instead of
   `"<8'op:abort3\"bye>"`. Type-checks fine.
2. silent WRONG ANSWER — a cross-module `match` collapses so a non-first
   arm is unreachable: `[tag-name t1]` and `[tag-name t2]` **both** return
   `"one"`.
3. hard failure — with a partially-populated cache,
   `imports: Error loading module prologos::ocapn::syrup-wire: Type mismatch`.

**Cause — a two-writer inconsistency.** Registry *readers* were migrated to
cell-primary (`macros.rkt:6300`):

```racket
(define (read-ctor-registry)
  (or (macros-cell-read-safe (current-ctor-registry-cell-id)) (current-ctor-registry)))
```

The parameter is consulted ONLY when no cell exists. The normal elaboration
writer dual-writes (`macros.rkt:6294` `register-ctor!` → param + `macros-cell-write!`).
The `.pnet` cache-hit restore (`driver.rkt:2637-2642`, and the same shape for
every registry through `:2705`) writes **only the parameter** — no
`macros-cell-write!` anywhere in that branch. So restored entries are
invisible to every reader.

The `.pnet` file is fine: `pnet-serialize.rkt:557-574` serializes correctly and
`deserialize-module-state` (`:616`) returns the registries intact. Nothing is
lost in serialization — **the restore writes to the wrong place.**

Timeline shows it was *demoted*, not written wrong:
`macros.rkt:6300` cell-primary readers = `7fec3751` (2026-03-18);
`driver.rkt:2637` merge = `2ef600ba` (2026-03-24) — written against the
parameter API **six days after** the readers stopped reading parameters.
The sibling propagation path in the same file got it right
(`driver.rkt:2969-2976` sets the param **and** calls `macros-cell-write!`).

**Why a stuck `reduce`**: `try-structural-reduce` (`reduction.rkt:1294-1298`)
does `(lookup-ctor head-name)` → `read-ctor-registry` → cell → `#f`, returns
`#f`, and `whnf` leaves the `expr-reduce` node in place. Specs come from
`module-info-specs`, a different channel, so the type checker is unaffected —
hence a well-typed stuck term.

**Why symptom 2** (this is finding 2 / the `BehaviorTag` bug, same cause):
`known-name?` (`macros.rkt:9205`) and `normalize-pattern` (`:9495-9510`) both
consult the same cell-primary registries at *elaboration* time. A miss means
a declared type name is not "known" (→ auto-implicit free type variable, i.e.
a phantom leading parameter) and constructor patterns degenerate to
catch-all **variable** patterns, so the first arm swallows everything:

```
cold:    [fn [x <minirepro::tag::Tag>] [reduce x | t1 -> "one" | t2 -> "two"]]
depwarm: [fn [x :0 <[Type 0]>] [fn [y <x>] "one"]]
```

**Precondition** (why it is not always broken): the registry cells must
already exist when the merge runs. `init-macros-cells!` (`macros.rkt:581`)
snapshots params→cells, but `process-file-inner` runs preparse (which is where
all module loading happens, `macros.rkt:2666-2687`) at `driver.rkt:2471/2479`
and only calls `init-macros-cells!` afterwards at `:2489`. So the FIRST
`process-file` in a fresh process is safe (cell-ids still `#f` → param
fallback); every later `process-file`, and every `process-string` /
`process-string-ws` (which never init the cells), is exposed.

**Scope: general, not OCapN-specific.** 8-line repro, one `data` + one
`defn`, no `foreign`/imports/prelude. **14 of the 17 registries** merged on
that path are silently dropped — every one with a cell-primary reader
(preparse, ctor, type-meta, subtype, coercion, capability, trait, impl,
param-impl, specialization, bundle, trait-laws, property, functor). So trait
and impl restoration are dropped identically; `data` + `reduce` is just the
loudest consequence.

**Why upstream `main` is green — three independent accidents, not correctness:**
1. `tools/pnet-compile.rkt:90` only generates `.pnet` for what `(ns pnet-gen)`
   pulls in — prelude modules only; `prologos::ocapn::*` never gets one in CI.
2. `tools/batch-worker.rkt:69` sets `(current-pnet-write-enabled? #f)`, so
   test runs never create the missing ones either.
3. For the prelude subset that IS a cache hit, `tests/test-support.rkt:110-115`
   re-runs `init-persistent-registry-network!` + `init-macros-cells!` AFTER the
   prelude load, re-snapshotting params into cells and healing exactly those
   entries.

And the one test that does exercise a cache hit,
`tests/test-record-pnet-cache.rkt`, uses only `def` with map literals — no
`data`, no `match`, no trait — so it asserts run-1 ≡ run-2 over precisely the
surface that happens to be unaffected. Local dev hits the bug because
`raco test tests/test-ocapn-*.rkt` run directly (not via batch-worker) has
`.pnet` writes ENABLED, so run 1 populates the cache and every later run is warm.

Silence is aggravated by `driver.rkt:2590` wrapping deserialization in
`with-handlers ([exn? (lambda (_) #f)])`, and preparse Pass -1 wrapping
`process-ns-declaration` / `process-imports` in `with-handlers ([exn:fail? void])`
(`macros.rkt:2681`, `:2686`).

**Refuted hypothesis** (recorded so it is not re-chased): the unserialized
`imports` field on `module-network-ref` is NOT the cause. Name resolution
across the cache boundary works — the stuck term carries the fully-resolved
FQN `prologos::ocapn::message::op-abort`. Syncing only the ctor cell fixes the
symptom while `imports` stays unserialized.

**Fix A (validated, minimal)** — dual-write each merged registry to its cell at
`driver.rkt:2634-2705`, mirroring what `:2971` already does for the spec store:
`(macros-cell-write! (current-ctor-registry-cell-id) d-ctor)`. 14 additions.
`macros-cell-write!` is already exported (`macros.rkt:369`) and no-ops when the
cell-id or net-box is `#f`, so pre-init / module-loading contexts are
unaffected. Validated out-of-band: forcing the param→cell sync flips
`[reduce ...]` STUCK → `"R" : String`. Tradeoff: preserves the two-writer
duplication, so it must be paired with a `pipeline.md` checklist entry
("new cell-backed registry ⇒ add to the `.pnet` restore dual-write") or the
15th registry regresses.

**Fix B** — route the merge through the `register-*!` helpers (which already
dual-write). Removes the duplication; larger change, since not every registry
has a per-entry registrar with matching semantics.

**Fix C** — retire the parameter fallback so cells are the single source of
truth (the `cells over parameters` / PM Track 12 direction). Only option that
kills the bug *class*. Requires the registry cells to exist before any module
load, i.e. moving `init-macros-cells!` ahead of preparse and giving
`process-string`/`process-string-ws` the same init.

**Regression coverage is mandatory with any fix**: extend
`test-record-pnet-cache.rkt` with (a) a `data` + `match` module asserting
run-1 ≡ run-2 including a NON-FIRST arm, and (b) a two-module case with the
dependency cached and the dependent fresh. Both must arrange for the cells to
exist before the cache hit — `run-ns-*` does that naturally; the existing
test's bespoke `parameterize` does not.

**Adjacent, worth filing separately**: `pnet-stale?` (`pnet-serialize.rkt:511-517`)
keys freshness on `"~a:~a"` of source path + mtime with no transitive-dependency
hashing (the comment admits it), so a module's `.pnet` stays "fresh" when a
*dependency*'s source changes. That is what generates the mixed fresh/stale
cache states which turn this bug from latent into active.

---

### #42 — Variable name in pattern silently shadows a data constructor (2026-05-18, real bug, **dangerous**)

**Symptom.** Wrote a match arm that takes a `SyrupValue` and binds
it as `refr`:

```
| [op-deposit-gift gid refr] v st ->
    handle-deposit-gift gid refr v st
```

Looked fine. Compiled without error. Function got "defined." But at
runtime, `handle-deposit-gift` always received `prologos::ocapn::captp-bridge::refr`
(the data constructor itself, not the bound value).

**Root cause.** `refr` is the constructor of the `Refr` data type
(defined elsewhere in the same module). In Prologos's pattern
elaborator, when a name is in scope as a constructor, using it in
PATTERN position resolves to the constructor — NOT as a fresh
variable binding. The result for `[op-deposit-gift gid refr]`
is a NESTED pattern: op-deposit-gift's 2nd field is matched
against `refr`-the-constructor's shape, with no fields bound.

The elaborator output for the broken arm:
```
| op-deposit-gift a b -> [reduce b | refr c d -> [...]]
```

i.e., it took the 2nd field and pattern-matched against
`refr c d` (the 2-arg Refr constructor). The body then referenced
`prologos::ocapn::captp-bridge::refr` because the symbol `refr` in
the BODY resolves to the constructor too (no fresh binding from
the broken pattern).

**Diagnosis is hard:**
- Compile succeeds.
- Runtime call doesn't error — `handle-deposit-gift` just receives
  the constructor function value as its 2nd argument.
- Downstream call to `syrup-as-export-target refr` matches NONE of
  the `syrup-*` arms (constructor is not a SyrupValue) and either
  errors weirdly OR silently produces the wrong path.

**Workaround.** RENAME the pattern variable to anything that
doesn't collide with a constructor:

```
| [op-deposit-gift gid gift-refr] v st ->
    handle-deposit-gift gid gift-refr v st
```

The convention in the codebase already avoids `refr` as a
parameter name in this module — body parameters use `r` (short),
`tgt-refr`, etc. New code should follow.

**Why this hadn't been hit earlier.** The `refr` constructor was
introduced in Phase 34a (single-constructor wrapping refr-kind +
id). Until Phase 52b, no handler pattern needed to bind a
SyrupValue field named `refr` — most CapTPOp variants use `args`,
`tgt`, `payload`, `pos`, etc.

**Discovered.** OCapN Phase 52b (2026-05-18). Cost ~10 minutes
diagnosing via elaborator-output trace inspection (the printed
`[reduce b | refr c d -> ...]` was the smoking gun).

**Verdict.** Real elaborator behaviour, possibly bug. The shadow
direction is arguably backwards — patterns SHOULD bind fresh
names by default and require explicit syntactic marker to invoke
a constructor (e.g., uppercase, or sigil). Languages that do
this right include Standard ML (variable names that happen to be
constructors silently bind — same hazard) vs Haskell (constructor
names MUST start with uppercase — disambiguates). Prologos's
choice to resolve names as constructors-when-available is a
silent footgun.

**Suggested mitigation.** Elaborator could WARN when a pattern
variable matches a constructor name in scope; the user explicitly
suppresses with a sigil or by uppercasing.

**Codify-it ask.** Any new handler arm should grep for existing
constructor names in the module(s) it imports and pick variable
names that don't collide. For OCapN: avoid `refr`, `listener`,
`q-entry`, `pipe-msg`, `bridge-state`, `bridge-step`, `conn-state`,
`conn-step`, `conn-ask`, `conn-release`, `pump-result`,
`gc-export-req`, `forward-effect`. Use `r`, `r-syrup`, `l`,
`q`, `pm`, `bs`, `cs`, `cr`, `pr`, etc.







### #44 — A bare Int literal where `Nat` is expected fails with "Unbound variable" (2026-07-27, real bug, **misleading diagnostic**)

**Symptom.** A module fails to import with

```
imports: Error loading module prologos::ocapn::captp-core: Unbound variable
```

and no identifier name, no source location, no line number. Nothing in
the module is actually unbound. The real fault is a numeric literal
whose type doesn't match its spec.

**Minimal reproduction** (bisected 2026-07-27 down from a 132-line
block to three lines; each variant differs only in the marked token):

```
;; FAILS — "Unbound variable"
spec probe String -> [Option Nat]
defn probe [s]
  [some 1]

;; LOADS FINE
spec probe String -> [Option Nat]
defn probe [s]
  [some 1N]
```

Controls run in the same harness, same module, same session:

| Variant | Result |
|---|---|
| `[some 1]` with spec `-> [Option Nat]` | `Unbound variable` |
| `[some 1N]` with spec `-> [Option Nat]` | loads |
| `[none Nat]` (type as term-level arg) | loads |
| `[str::eq s "x"]` alone | loads |

So it is neither `none`-with-a-type-argument nor the qualified foreign
call — it is specifically the bare `1` against a `Nat`-typed position.

**Root cause — the real bug is the module loader's error class, not the
literal.** Bare integer literals are `Int`, not `Nat`; that part is
documented (`.claude/rules/prologos-syntax.md` § Lists and literals) and
is arguably working as designed. The BUG is that the *same source* is
reported as two different error classes depending on which path
elaborates it.

Byte-identical body, two entry points:

```
;; examples/tmp-some1.prologos
ns tmp-some1
require [prologos::data::option :refer [Option some none]]
spec probe String -> [Option Nat]
defn probe [s]
  [some 1]
```

via `process-file` — correct, fully actionable:

```
(type-mismatch-error (srcloc "<unknown>" 0 0 0) "Type mismatch"
  "[Pi [x <String>] [prologos::data::option::Option Nat]]"
  "[Pi [x <String>] [prologos::data::option::Option Int]]"
  "[fn [x <String>] [prologos::data::option::some Int 1]]" '())
```

The same code reached through a module `imports`:

```
imports: Error loading module prologos::ocapn::captp-core: Unbound variable
```

A `type-mismatch-error` carrying both expected and actual types is
converted into an `Unbound variable` report — the wrong error CLASS, not
merely a truncated one. Nothing is unbound.

This is not a general lack of error detail. The error structs do carry
identity and position: a genuine unbound reference in the same
`process-file` path reports
`(unbound-variable-error (srcloc "<file>" 9 1 9) "Unbound variable" 'qe)`
— symbol AND srcloc. Both the name and the type information exist and
are discarded at the module-import boundary.

**Cost when hit.** This ate two CI round-trips and a revert
(`366f85ff` → `0070f1e0` → `b62288c4`). Because the message says
"Unbound variable", the whole investigation went into import/ordering
territory — first pitfall #16 (definition order, which WAS also
genuinely wrong in that block and needed fixing, so the reorder
"looked" like progress while the error stayed identical), then a
missing `[prologos::data::string :as str :refer []]` require (also
genuinely missing). Three independent bugs, one indistinguishable
error message for all three. Each fix appeared not to work because the
next bug produced the identical output.

**Workaround — and the cheap instrument.** Suffix `N` on every integer
literal in a `Nat` position: `0N`, `1N`, `5N`.

The general technique matters more than this one fix. When a module
fails to import with a bare `Unbound variable`, do NOT trust the error
class. **Re-elaborate the same code through `process-file` instead** —
that path reports the true error (here, the full type mismatch with
expected and actual types). A one-file `examples/tmp-*.prologos`
reproduction is a ~1 min instrument that turns an unnamed
`Unbound variable` into a named, located, correctly-classified error.
That single step would have replaced this entire bisect.

If the fault only appears in module context, bisect by deleting
definitions until it loads, then probe the survivor token by token. A
3-line probe inserted into the real module loads in ~2 min, versus ~30
min for a full local build and ~6 min per CI round-trip. Do this
locally; do not bisect through CI.

**Codify-it ask.** In priority order:

1. **The module loader must not reclassify errors.** A
   `type-mismatch-error` with both types in hand must not surface as
   `Unbound variable`. This is the actual defect and it is a pure
   error-propagation bug at the `imports` boundary — the structured
   error already exists upstream of the point where it is flattened.
   Fixing only this would have reduced today's cost from hours to
   minutes, and it protects every future module-level failure, not just
   numeric-literal ones. Highest-leverage diagnostic fix found in this
   log: the message does not merely lack detail, it names the wrong
   problem class and actively misdirects.
2. **Consider elaborating the literal.** `Nat` vs `Int` differing only
   by a suffix, with no coercion or defaulting, is a sharp edge in a
   language that otherwise leans hard on inference. A bare non-negative
   literal in a known-`Nat` position could reasonably elaborate to
   `Nat`. Lower priority than (1) and a genuine design question, not an
   obvious bug — but (1) is a bug regardless of how (2) is decided.

### #45 — A module function's BEHAVIOUR depends on what the CALLER's namespace imports (2026-07-27, real bug, **severe**)

**Symptom.** The same function, called with byte-identical arguments in the
same sequence, returns different results depending on which *unrelated*
modules the calling namespace has imported. No error, no warning — just a
different answer.

**Minimal reproduction.** Two runs, identical frames, identical call
sequence, fresh connection id each, differing ONLY in the preamble:

```
;; preamble A (minimal)
(ns pmin)
(imports (prologos::ocapn::interop-driver :refer-all))
(imports (prologos::data::string :as str :refer ()))

;; preamble B (larger) — adds captp-core, message, syrup,
;; core::collections, option
```

Then, in both, the same three calls:

```
(eval (init-connection N))
(eval (str::length (step-connection N "<fetch frame hex>")))
(eval (str::length (step-connection N "<deliver frame hex>")))
```

Result:

| Preamble | fetch call | deliver call |
|---|---|---|
| A (minimal) | 71 | **0** |
| B (larger)  | 71 | **41** |

`step-connection` is defined in `prologos::ocapn::interop-driver`, which
BOTH preambles import identically. The extra imports in B are not used by
the probe at all. Yet B gets bytes and A gets none.

**Confirmed not:** nondeterminism (three separate processes agree per
configuration), reduction fuel (100× makes no difference), argument shape,
connection id, or ordering within the process. Each was tested and
eliminated.

**Why this is severe.** It breaks the basic guarantee that a module's
exported function means the same thing to every caller. Any test that
passes with a rich preamble can fail in production with a lean one, and the
failure is SILENT — the caller gets a well-typed empty result rather than
an error. Debugging from the call site is nearly impossible, because
nothing at the call site is wrong.

**Relationship to issue #78.** The signature matches: "cached module loads
give you functions that don't fire." #78 was the `.pnet` cache-hit restore
writing parameters but not cells; that fix landed today. This may be a
second instance of the same class — registry/cell state that depends on
which modules were loaded and in what order — or the remaining half of the
same defect. Worth investigating together.

**Caveat, stated because it matters.** Adding the two modules that differed
(`prologos::ocapn::syrup`, `prologos::core::collections`) to the OCapN test
server's preamble did NOT fix the server, which still fails the same way.
So the import set is *a* lever on the behaviour but is not the whole story;
the minimal repro above is solid and reproducible, the general rule is not
yet characterised. Do not assume "import more modules" is the fix — that
change was reverted rather than landed.

**Codify-it ask.** Two things:
1. A function's behaviour must not depend on the caller's import set. If
   resolution genuinely needs more context, that is a load-order bug to
   fix, not a property to document.
2. Until then, when a Prologos function silently returns an empty/default
   result and the call site looks correct, **vary the caller's preamble**
   as a diagnostic. It is not an obvious thing to try, and here it was the
   only variable that moved the outcome after twelve other hypotheses had
   been eliminated.
