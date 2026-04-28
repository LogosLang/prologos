# EtProp Pitfalls — Notes from the EigenTrust-on-Propagators Bring-Up

**Date**: 2026-04-28
**Context**: While implementing the EigenTrust-on-propagators example
(`racket/prologos/lib/examples/eigentrust{,-prop.rkt,.prologos}`), the work
surfaced several rough edges in Prologos and the surrounding Racket tooling.
This document captures them in one place so future similar work doesn't have
to rediscover them.

The list is **observation only** — these are bugs / friction in language
features and tooling, not in the EigenTrust example itself. They're filed
here because tracking them in commit messages alone made them invisible.

## What MUST stay on the Racket side (the irreducible core)

Across two passes of "minimise the Racket footprint", these four
responsibilities resisted every attempt to push them out into Prologos.
**Update 2026-04-28**: items 1 and 2 are no longer hard requirements —
the FFI marshaller now passes Prologos lambdas across the boundary as
live Racket procedures (see
[2026-04-28_FFI_LAMBDA_PASSING.md](2026-04-28_FFI_LAMBDA_PASSING.md)).
They are downgraded to "preferentially Racket for performance, but no
longer required."

  1. **Propagator fire functions.** [Downgraded — preferentially Racket
     for performance, no longer required.] Historically the fire-fn was a
     Racket closure invoked by the Racket-side BSP scheduler with the
     network as its argument, and Prologos lambdas could not cross the
     FFI boundary as live closures. With the FFI lambda passing track
     a Prologos lambda CAN now be passed across the FFI: a Racket harness
     propagator can adapt the Prologos lambda to the network's fire-fn
     protocol. The reason to keep fire-fns in Racket is now performance
     (each call drives a Prologos `nf` reduction), not capability.

  2. **Cell merge functions.** [Downgraded — preferentially Racket for
     performance, no longer required.] Same situation as item 1 above.
     The propagator network calls merge-fn during cell writes (and during
     BSP fold-merges); a Prologos lambda can supply the merge via FFI.

  3. **The cell-value carrier.** A gen-tagged immutable Racket vector. The
     gen tag has to interoperate with Racket's `equal?` for the cell's
     change detection, and the merge function has to be a Racket procedure
     that operates on whatever Racket data structure the cell holds.

  4. **FFI marshalling glue.** Walking Prologos cons/nil chains, extracting
     posit32 bit-patterns out of `expr-posit32` IR nodes, encoding rationals
     back into bit patterns. Pure Racket-side bookkeeping.

Everything else — matrix transpose, decay scaling, bias computation,
initial-zero-vector, the iteration driver, the entire EigenTrust update
rule's arithmetic decomposition — is in the .prologos source. The
Racket-side `net-add-prop` is purpose-AGNOSTIC: it implements the
generic affine combination

  out[j]  :=  bias[j]  +  Σ_i  weight[j][i] · in[i]

with no knowledge of EigenTrust, decay, transposition, or pretrust.

The four FFI primitives (`net-new`, `net-new-cell`, `net-add-prop`,
`net-run-read`) are the entire Racket-Prologos interface.

------------------------------------------------------------------

## 0. FFI-call AST caching — distinct calls collapse onto one side effect

The complement to pitfall #1: within a single `process-command`, the
per-command `whnf-cache` memoises identical ASTs. For a side-effecting
foreign function (e.g. `net-new-cell`), two calls with structurally equal
arguments hit the cache on the second call and the side effect runs only
once. The Prologos source *thinks* it allocated two cells; the Racket
side allocated one and returned the same id twice.

Repro shape:

    let c1 := et/net-new-cell h zeros
    let c2 := et/net-new-cell h zeros   ;; same AST → cache hit → c1 = c2

Observed during the eigentrust lambda-FFI refactor: the recursive driver
loop allocated K layer cells via `[et/net-new-cell h zeros]` each
iteration; with identical args, all K reduced to the same physical cell.
Layer 2's broadcast propagator's input *and* output both pointed to that
shared cell — a self-loop that ran to fixpoint regardless of K.

**Workaround**: take a "freshness tag" argument on the FFI side that's
ignored functionally but disambiguates the call AST. The eigentrust shim
does this for `net-new-cell : handle × tag × init-vec → cell-ref` — the
Prologos driver passes the previous layer's cell-ref (varies per
recursion) as the tag.

**Underlying language design call**: same as pitfall #1 — referential
transparency is the contract. There's no "force evaluation now" surface;
the FFI argument boundary IS the only forcing point. Anything memoised by
AST equality collides on identical input.

## 1. `def` is reference-transparent — side effects re-fire on every use

In Prologos a `def name := body` stores `body`'s **AST**, not its evaluated
value. Each subsequent reference to `name` substitutes the AST and re-reduces
it. For pure computations that's fine; for foreign calls with side effects
it's a footgun.

Repro:

    foreign racket "racket/base" [add1 : Nat -> Nat]

    foreign racket "lib/examples/eigentrust-prop.rkt" :as et
      net-new : Posit32 -> Posit32

    def h := et/net-new 1000000.0
    h
    h
    h     ;; -> three different handle ids

Each `h` re-evaluates `et/net-new`, allocating a fresh network. This breaks
multi-`def` imperative-style programming with foreign side effects. Note
that within a single `process-command` boundary the per-command `whnf-cache`
**does** memoise identical AST nodes, so a single top-level expression with
multiple syntactic occurrences of `h` after substitution does behave; but
`def`-bound names are unfolded across `def` boundaries.

**Workaround**: the entire algorithm runs as one expression — typically a
single `defn` body whose RHS chains `let := body` bindings. Within that one
expression all FFI calls evaluate exactly once.

**Underlying language design call**: this is consistent with definitional
equality in dependent type theory (defs are *transparent*), so it's not
strictly a bug — but the behaviour is surprising for anyone bringing in
side-effecting foreign code, and there is no warning surface.

## 2. Reduction is call-by-name — unused let-bound side effects are dropped

`let _ := side-effecting-call body` evaluates `body` without ever
substituting `_` (since `_` is a wildcard). The `side-effecting-call` is
therefore **never evaluated**. Same shape for any unreferenced binding:

    let _i := et/net-add-prop ...   ;; never fires
    let _r := et/net-run h          ;; never fires
      result-expr                    ;; only this is reduced

The eigentrust shim works around this by making every "side-effecting" FFI
call return a **meaningful** Posit32 (the cell-ref or the handle id) so the
caller is forced to thread it through a subsequent call. Sequencing via
`do` blocks doesn't help — `do` desugars to nested let.

A shim helper such as `seq : Unit -> A -> A` that pattern-matches on `unit`
also failed empirically; the match seems to be optimised through. Real
forcing only happens at the **FFI argument boundary** where `whnf` /
`nf` are used to marshal values.

**Implication for any FFI-via-foreign API**: every effectful call MUST
return a non-trivial value that the user is induced to consume. Returning
`Unit` is a trap.

## 3. `let x := value body` requires `body` strictly more indented than `let`

Prologos's WS-mode `let` macro merges consecutive bodyless `let`s into a
single binding group, with the trailing expression as the body. Surface
syntax requires the body to be indented past the `let` column:

    defn calc [n]
      let x := add1 n
        add1 x         ;; OK — body indented past `let`

If the body shares the `let`'s indent the parser silently drops the whole
defn (no error reported, the name registers as **unbound**):

    defn calc [n]
      let x := add1 n
      add1 x           ;; WRONG — defn never registered

This combines with pitfall #4 below to make defn-body errors particularly
hard to diagnose.

## 4. Defn-body errors swallow the whole defn

When `defn name body` has a malformed body (e.g. wrong indent, undefined
identifier in a particular position), the surface form is silently rejected
and `name` never registers. The first hint is a downstream
"Unbound variable: name" error from a later top-level expression. There is
no error from the defn itself.

Observed during eigentrust-prop bring-up: `defn pretrust-cells [...]` with
a stale forward reference compiled silently into nothing; the only signal
was the later `[pretrust-cells h pretrust]` failing.

## 5. `defn name | pat -> body` arity-1 list patterns produce a non-exhaustive match

This compiles cleanly but raises `??__match-fail` at run time:

    defn zeros-of
      | nil          -> nil
      | [cons _ rs]  -> [cons 0.0 [zeros-of rs]]

The fix is the explicit-`match` form, which works:

    defn zeros-of [xs]
      match xs
        | nil          -> nil
        | [cons _ rs]  -> [cons 0.0 [zeros-of rs]]

The two forms should be equivalent; the multi-arity dispatch path appears to
miss the `nil`-as-constructor pattern in arity-1 list matches.

## 6. Foreign type signatures must fit on ONE line

The foreign-block parser tokenises type tokens and then splits on `->`. If
the type is wrapped across lines:

    net-add-prop : Posit32 Posit32 Posit32
                   [List [List Posit32]] [List Posit32] Posit32 -> Posit32

`foreign-type-tokens->sexp` errors with "Cannot parse foreign type tokens".
The fix is a single (potentially long) line:

    net-add-prop : Posit32 Posit32 Posit32 [List [List Posit32]] [List Posit32] Posit32 -> Posit32

This is annoying for FFI declarations of broadcast propagators (which take
several list-typed arguments) but is currently mandatory.

## 7. Foreign FFI doesn't support Posit32 marshalling out of the box

`base-type-name` recognises `expr-Posit32` / `expr-Posit64` and returns the
symbol, but `marshal-prologos->racket` and `marshal-racket->prologos` had no
case for them: the foreign machinery would say "Unsupported marshal-in
type: Posit32". The previous handoff added Posit32/Posit64 marshalling
(see commit `f9a3d7c`); this is still the only marshalling path that
short-circuits the existing posit-impl.rkt arithmetic ops via FFI.

The carrier is the **bit-pattern integer** (matching posit-impl.rkt), so
`foreign racket "posit-impl.rkt" [posit32-add : Posit32 Posit32 -> Posit32]`
works directly.

## 8. Foreign data structure types are passed via `[List ...]` but only allowed
in specific positions

`[List Nat]`, `[List Posit32]`, and `[List [List Posit32]]` work in foreign
type signatures. They must be bracketed (the parser handles them as type
applications). Using bare `List Nat` would unfold into curried `List ->
Nat -> ...`, which is wrong.

## 9. Top-level `let` is forbidden, but inside `defn` bodies works fine

`let h := body` at the top level errors with
`let: 'let' is not allowed at top level. Use 'def' instead.`

There's no surface alternative for "give a name to an intermediate value at
the top level". `def` re-evaluates (pitfall #1). The only way to evaluate
something exactly once at top level is to inline the entire computation
into one expression.

## 10. `(zeros-of rs)` parens vs `[zeros-of rs]` brackets are NOT
interchangeable

In WS mode `(...)` is reserved for parser keywords (`match`, `def`, etc.) and
relational goals. Function application uses `[]`. Writing `(f x)` for an
ordinary application typically silently fails (the parser tries to find a
special form named `f` and either drops the form or fails very far away
from the source line).

## 11. `list-literal` quoting handles bare numeric literals correctly

Confirmed working: `'[0.5 0.25 0.125]` produces a `[List Posit32]` (the
posit literals retain their decimal-literal interpretation; bare `0.5` is
equivalent to `~0.5` per the grammar). Earlier confusion was that quoted
identifiers (`'[src1 src2]`) get reified as Datum symbols, not as variable
references — so list-literal sugar works for **constants** but not for
**values**.

## 12. Racket-9-only features + Ubuntu 24.04 ships Racket 8.10

`make-parallel-thread-fire-all` (`propagator.rkt:2592`) uses `(thread
#:pool 'own)` — a Racket 9 feature that's silently a runtime error on
Racket 8.x:

    application: procedure does not accept keyword arguments
      procedure: thread

The driver unconditionally installs this executor at module load
(`driver.rkt:434`). On Racket 8 the test suite errors out from any code
path that goes through `run-to-quiescence-bsp`. Workarounds tried:

  * `parameterize` to `sequential-fire-all` at the call site — works for
    your own entry points but doesn't help the driver's own
    `run-post-compilation-inference!` which is set up at module load.

  * Patch `propagator.rkt` to detect Racket version — invasive.

Resolution chosen here: build Racket 9 from source. The download host
(`download.racket-lang.org`) is on a curl allowlist, so source must be
pulled from `https://github.com/racket/racket/archive/refs/tags/v9.1.tar.gz`
and built with `make CPUS=4 PKGS=""`. `rackunit` then has to be
hand-installed by copying `pkgs/rackunit/rackunit-lib/rackunit` and
`pkgs/compiler-lib/raco/testing.rkt` into the Racket collects tree —
`raco pkg install` fails because the catalog server is also on the allowlist.

## 13. Prologos's parser drops files using `prologos::core::abs-trait`

`racket/prologos/lib/examples/foreign.prologos` `require`s
`prologos::core::abs-trait` which no longer exists (renamed/merged into
`prologos::core::arithmetic`). Running this example now errors:

    imports: Cannot find module: prologos::core::abs-trait

This is unrelated to the eigentrust work but came up while sanity-checking
the FFI surface.

## 14. `tools/check-parens.sh` hardcodes a Mac-style Racket path

The pre-commit paren checker shells out to
`/Applications/Racket v9.0/bin/racket` (line 21), which is a Mac dev
machine artifact. On Linux + the project's expected path
(`/usr/local/bin/racket`) this fails open with a confusing
"FAIL: ... No such file or directory" message even when the file's parens
are balanced.

Workaround used here: a small standalone `parencheck.rkt` script that
parses files with `read-syntax`. Either a `command -v racket` lookup or a
configurable path setting in `check-parens.sh` would close this.

## 15. Default Posit32 conversions use exact rationals and are slow at scale

Encoding a Racket rational into a Posit32 bit pattern (`posit32-encode`) and
decoding it back (`posit32-to-rational`) goes through the exact-rational
posit format. For our 4-peer × 20-iteration EigenTrust this is unproblematic,
but the propagator network's reduction phase reports ~55 seconds in
`reduce_ms` even though the actual fixpoint runtime is sub-second. The
overhead is in the elaboration / type-checking of the recursive `drive`
loop and the FFI marshalling, not the propagator firing itself. Future
work: a `Posit32` instance of `Num` and operator desugaring would let the
.prologos source operate on posits directly (without going through Rat),
which would also let the FFI shim drop its rational pre-computation step.

## 16. FFI-callback overhead per fire dominates scaling K

Once the FFI lambda passing track landed (item-1/-2 of "what stays
Racket" downgraded), the eigentrust shim moved its per-row affine
combination out into a Prologos lambda. Each propagator fire now invokes
the kernel via the marshaller's wrapper, which:

  1. Marshals each Racket arg back to Prologos IR.
  2. Builds an `expr-app` chain.
  3. Runs `nf` on it (full normal form reduction).
  4. Marshals the result back to Racket.

For a 4-peer 4-element dot product, one fire ≈ 4 kernel calls × ~50
reduction steps each ≈ 200 reductions per fire. At Racket-9.1 reduction
speed that's a fraction of a second per fire — tolerable for small K but
linear in K because each layer is a separate broadcast propagator.

For the test we use K=4 power iterations, which lands within ~6e-3 of
the steady-state eigenvector and finishes in ~16s wall — under the
test runner's 30s "first result" guard. K=20 (full convergence) takes
several minutes and exceeds the runner's death-detection threshold.

This is **expected scaffolding cost** of the off-network FFI bridge —
see `2026-04-28_FFI_LAMBDA_PASSING.md` § Mantra-alignment retirement
plan. Future propagator-native callbacks (cell subscription instead of
procedure-shaped foreign callbacks) would replace the per-fire `nf`
reduction with a structurally-emergent activation.

------------------------------------------------------------------

## Tracking

These observations are not tracked in any specific PIR or design doc;
they're cross-cutting friction discovered during the bring-up. If any of
them blocks future work, file a tracking doc per `.claude/rules/workflow.md`
and link back here.
